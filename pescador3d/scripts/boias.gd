extends Node3D
## Boias de sinalização náutica na entrada da baía (balizamento IALA-B, o do Brasil):
## entrando no porto, a vermelha (cone) fica a boreste, a verde (cilindro) a bombordo.
## Há também uma marca de águas seguras (esfera listrada) e uma amarela (cruz) no recife.
## Boiam nas ondas e, à noite, piscam com luz própria, visível de longe.
const Mesclador = preload("res://scripts/mesclador.gd")

const ESCALA := 1.45             # tamanho em relação a uma boia "de verdade": precisa ser vista do barco
const DISTANCIA_PERTO := 420.0   # m: só as boias perto da câmera acompanham cada onda
const TIPOS := {
    "boreste": {"cor": Color(0.78, 0.13, 0.10), "luz": Color(1.0, 0.16, 0.10), "periodo": 4.0, "aceso": 0.9},
    "bombordo": {"cor": Color(0.07, 0.50, 0.24), "luz": Color(0.12, 1.0, 0.34), "periodo": 4.0, "aceso": 0.9},
    "seguro": {"cor": Color(0.80, 0.14, 0.11), "luz": Color(1.0, 0.97, 0.86), "periodo": 8.0, "aceso": 4.0},
    "especial": {"cor": Color(0.92, 0.72, 0.10), "luz": Color(1.0, 0.80, 0.12), "periodo": 5.0, "aceso": 0.9},
}

var dados_radar: Array = []      # {mundo: Vector2, cor: Color}: o radar do HUD desenha pontinhos
var _boias: Array = []
var _oceano: Node = null
var _material_corpo: StandardMaterial3D
var _halo: Texture2D
var _tempo: float = 0.0
var _noite: float = 0.0
var _acumulado: float = 0.0

func configurar(ilhas: Array, oceano: Node) -> void:
    _oceano = oceano
    for no in get_children():
        no.queue_free()
    _boias.clear()
    dados_radar.clear()
    _material_corpo = StandardMaterial3D.new()
    _material_corpo.vertex_color_use_as_albedo = true
    _material_corpo.roughness = 0.82
    _halo = _criar_halo()
    var contador: int = 0
    for ilha in ilhas:
        if not ilha.has_method("posicoes_boias"):
            continue
        for item in ilha.posicoes_boias():
            _nova_boia(String(item["tipo"]), item["pos"], contador)
            contador += 1

func _nova_boia(tipo: String, pos: Vector3, indice: int) -> void:
    var d: Dictionary = TIPOS[tipo]
    var raiz := Node3D.new()
    raiz.name = "Boia_" + tipo
    raiz.position = pos
    add_child(raiz)
    var corpo := MeshInstance3D.new()
    corpo.name = "Corpo"
    corpo.mesh = _malha(tipo)
    corpo.material_override = _material_corpo
    corpo.scale = Vector3.ONE * ESCALA
    corpo.visibility_range_end = 1100.0
    corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    raiz.add_child(corpo)
    var material_luz := StandardMaterial3D.new()
    material_luz.albedo_color = d["luz"]
    material_luz.emission_enabled = true
    material_luz.emission = d["luz"]
    material_luz.emission_energy_multiplier = 0.0
    material_luz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var lanterna := MeshInstance3D.new()
    lanterna.name = "Lanterna"
    var esfera := SphereMesh.new()
    esfera.radius = 0.2
    esfera.height = 0.4
    esfera.radial_segments = 8
    esfera.rings = 4
    lanterna.mesh = esfera
    lanterna.material_override = material_luz
    lanterna.position = Vector3(0.0, 4.2 * ESCALA, 0.0)
    lanterna.scale = Vector3.ONE * ESCALA
    lanterna.visibility_range_end = 1100.0
    lanterna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    raiz.add_child(lanterna)
    var brilho := Sprite3D.new()
    brilho.name = "Brilho"
    brilho.texture = _halo
    brilho.shaded = false
    brilho.no_depth_test = false
    brilho.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    brilho.modulate = Color(d["luz"], 0.0)
    brilho.position = Vector3(0.0, 4.2 * ESCALA, 0.0)
    brilho.pixel_size = 0.05
    brilho.visible = false
    raiz.add_child(brilho)
    _boias.append({"no": raiz, "tipo": tipo, "luz": material_luz, "brilho": brilho, "periodo": float(d["periodo"]),
            "aceso": float(d["aceso"]), "fase": fmod(float(indice) * 1.37, float(d["periodo"])), "y": 0.0, "rx": 0.0, "rz": 0.0})
    dados_radar.append({"mundo": Vector2(pos.x, pos.z), "cor": Color(d["luz"]) if tipo != "seguro" else Color(0.95, 0.92, 0.85)})
    _acomodar(_boias[_boias.size() - 1], 0.0)

## À noite (0 a 1) as luzes passam a piscar.
func acender(noite: float) -> void:
    _noite = clampf(noite, 0.0, 1.0)
    if _noite <= 0.02:
        for b in _boias:
            (b["luz"] as StandardMaterial3D).emission_energy_multiplier = 0.0
            (b["brilho"] as Sprite3D).visible = false

func _process(delta: float) -> void:
    _tempo += delta
    _acumulado += delta
    var camera: Camera3D = get_viewport().get_camera_3d()
    var olho: Vector3 = camera.global_position if camera != null else Vector3.ZERO
    var pisca: bool = _acumulado >= 0.1
    for b in _boias:
        var no: Node3D = b["no"]
        var dist: float = no.global_position.distance_to(olho)
        if dist < DISTANCIA_PERTO:
            _acomodar(b, delta)
        if pisca and _noite > 0.02:
            var ligada: bool = fmod(_tempo + float(b["fase"]), float(b["periodo"])) < float(b["aceso"])
            (b["luz"] as StandardMaterial3D).emission_energy_multiplier = (8.0 * _noite) if ligada else 0.0
            var halo: Sprite3D = b["brilho"]
            halo.visible = ligada
            if ligada:
                halo.pixel_size = clampf(dist * 0.00033, 0.022, 0.095)
                halo.modulate.a = 0.9 * _noite
    if pisca:
        _acumulado = 0.0

## Sobe e desce com a onda e se inclina com a inclinação dela (duas amostras por eixo).
func _acomodar(b: Dictionary, dt: float) -> void:
    var no: Node3D = b["no"]
    var p: Vector3 = no.global_position
    var h0: float = _altura_agua(p)
    var hx1: float = _altura_agua(p + Vector3(1.4, 0.0, 0.0))
    var hx0: float = _altura_agua(p - Vector3(1.4, 0.0, 0.0))
    var hz1: float = _altura_agua(p + Vector3(0.0, 0.0, 1.4))
    var hz0: float = _altura_agua(p - Vector3(0.0, 0.0, 1.4))
    var alvo_rz: float = clampf(atan2(hx1 - hx0, 2.8) * 0.85, -0.45, 0.45)
    var alvo_rx: float = clampf(atan2(hz0 - hz1, 2.8) * 0.85, -0.45, 0.45)
    var k: float = 1.0 if dt <= 0.0 else 1.0 - exp(-6.0 * minf(dt, 0.25))
    b["y"] = lerpf(float(b["y"]), h0, k) if dt > 0.0 else h0
    b["rx"] = lerpf(float(b["rx"]), alvo_rx, k) if dt > 0.0 else alvo_rx
    b["rz"] = lerpf(float(b["rz"]), alvo_rz, k) if dt > 0.0 else alvo_rz
    no.position.y = float(b["y"]) - 0.1
    no.rotation = Vector3(float(b["rx"]), no.rotation.y, float(b["rz"]))

func _altura_agua(p: Vector3) -> float:
    if _oceano != null and _oceano.has_method("altura_em"):
        return _oceano.altura_em(p)
    return 0.0

# ------------------------------------------------------------------ desenho

func _criar_halo() -> Texture2D:
    const TAMANHO: int = 64
    var imagem: Image = Image.create(TAMANHO, TAMANHO, false, Image.FORMAT_RGBA8)
    for y in TAMANHO:
        for x in TAMANHO:
            var dx: float = (float(x) + 0.5 - TAMANHO * 0.5) / (TAMANHO * 0.5)
            var dy: float = (float(y) + 0.5 - TAMANHO * 0.5) / (TAMANHO * 0.5)
            var r: float = sqrt(dx * dx + dy * dy)
            var nucleo: float = 1.0 - smoothstep(0.0, 0.22, r)
            var borda: float = (1.0 - smoothstep(0.15, 1.0, r)) * 0.38
            imagem.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(nucleo + borda, 0.0, 1.0)))
    return ImageTexture.create_from_image(imagem)

## Uma malha só por boia, com as cores nos vértices (uma chamada de desenho).
func _malha(tipo: String) -> ArrayMesh:
    var cor: Color = TIPOS[tipo]["cor"]
    var escuro := Color(0.15, 0.16, 0.18)
    var branco := Color(0.92, 0.90, 0.84)
    var pecas: Array = []
    if tipo == "seguro":
        var esfera := SphereMesh.new()
        esfera.radius = 0.95
        esfera.height = 1.9
        esfera.radial_segments = 16
        esfera.rings = 8
        var casco: Array = _peca(esfera, Transform3D(Basis(), Vector3(0.0, 0.3, 0.0)), branco)
        var cores: PackedColorArray = casco[0][Mesh.ARRAY_COLOR]
        var vs: PackedVector3Array = casco[0][Mesh.ARRAY_VERTEX]
        for i in vs.size():                       # oito gomos, vermelho e branco alternados
            var gomo: int = int(floor((atan2(vs[i].z, vs[i].x) + PI) / (TAU / 8.0))) % 2
            cores[i] = cor if gomo == 0 else branco
        casco[0][Mesh.ARRAY_COLOR] = cores
        pecas.append(casco)
    else:
        var base := CylinderMesh.new()            # quilha escura, meio mergulhada
        base.top_radius = 0.55
        base.bottom_radius = 0.22
        base.height = 0.95
        base.radial_segments = 14
        pecas.append(_peca(base, Transform3D(Basis(), Vector3(0.0, -0.3, 0.0)), escuro))
        var corpo := CylinderMesh.new()
        corpo.top_radius = 0.58
        corpo.bottom_radius = 0.72
        corpo.height = 1.35
        corpo.radial_segments = 14
        pecas.append(_peca(corpo, Transform3D(Basis(), Vector3(0.0, 0.55, 0.0)), cor))
        var faixa := CylinderMesh.new()
        faixa.top_radius = 0.66
        faixa.bottom_radius = 0.67
        faixa.height = 0.16
        faixa.radial_segments = 14
        pecas.append(_peca(faixa, Transform3D(Basis(), Vector3(0.0, 0.45, 0.0)), branco if tipo != "especial" else escuro))
        var anel := CylinderMesh.new()            # tampo
        anel.top_radius = 0.50
        anel.bottom_radius = 0.58
        anel.height = 0.10
        anel.radial_segments = 14
        pecas.append(_peca(anel, Transform3D(Basis(), Vector3(0.0, 1.27, 0.0)), escuro))
    var mastro := CylinderMesh.new()
    mastro.top_radius = 0.06
    mastro.bottom_radius = 0.09
    mastro.height = 2.2
    mastro.radial_segments = 6
    pecas.append(_peca(mastro, Transform3D(Basis(), Vector3(0.0, 2.35, 0.0)), escuro))
    # sinal de topo, que diz o lado do canal: lata verde, cone vermelho, esfera (águas seguras), cruz amarela
    match tipo:
        "bombordo":
            var lata := CylinderMesh.new()
            lata.top_radius = 0.34
            lata.bottom_radius = 0.34
            lata.height = 0.62
            lata.radial_segments = 12
            pecas.append(_peca(lata, Transform3D(Basis(), Vector3(0.0, 3.55, 0.0)), cor))
        "boreste":
            var cone := CylinderMesh.new()
            cone.top_radius = 0.0
            cone.bottom_radius = 0.42
            cone.height = 0.66
            cone.radial_segments = 12
            pecas.append(_peca(cone, Transform3D(Basis(), Vector3(0.0, 3.56, 0.0)), cor))
        "seguro":
            var bola := SphereMesh.new()
            bola.radius = 0.32
            bola.height = 0.64
            bola.radial_segments = 10
            bola.rings = 5
            pecas.append(_peca(bola, Transform3D(Basis(), Vector3(0.0, 3.5, 0.0)), Color(0.80, 0.14, 0.11)))
        "especial":
            for sinal in [-1.0, 1.0]:
                var barra := BoxMesh.new()
                barra.size = Vector3(0.95, 0.13, 0.13)
                pecas.append(_peca(barra, Transform3D(Basis(Vector3.BACK, deg_to_rad(45.0 * float(sinal))), Vector3(0.0, 3.55, 0.0)), cor))
    return Mesclador._juntar(pecas)

## [vértices, transformação, nó] com a cor gravada nos vértices (formato que Mesclador._juntar espera).
func _peca(malha: Mesh, t: Transform3D, cor: Color) -> Array:
    var matriz: Array = malha.get_mesh_arrays()
    var n: int = (matriz[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
    var cores := PackedColorArray()
    cores.resize(n)
    cores.fill(cor)
    matriz[Mesh.ARRAY_COLOR] = cores
    return [matriz, t, null]
