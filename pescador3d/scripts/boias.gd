extends Node3D
## Boias de sinalização náutica na entrada da baía (balizamento IALA-B, o do Brasil):
## entrando no porto, a vermelha (cone) fica a boreste, a verde (cilindro) a bombordo.
## Há também uma marca de águas seguras (esfera listrada) e uma amarela (cruz) no recife.
## Boiam nas ondas e, à noite, piscam com luz própria, visível de longe.
## v0.5.11: modelo novo (flutuador com defensa de borracha, torre treliçada com faixa de sinalização, painéis solares,
## lanterna com cesto, sinal de topo e número pintado) e material procedural de aço pintado gasto (shaders/boia.gdshader).
const Mesclador = preload("res://scripts/mesclador.gd")

const ESCALA := 1.45             # tamanho em relação a uma boia "de verdade": precisa ser vista do barco
const DISTANCIA_PERTO := 420.0   # m: só as boias perto da câmera acompanham cada onda
const ALTURA_LUZ := 3.18         # altura da lanterna no modelo (antes de ESCALA)
const SHADER_BOIA := preload("res://shaders/boia.gdshader")
# alfa da cor do vértice = material (ver shaders/boia.gdshader)
const PINTADO := 1.0
const BORRACHA := 0.75
const GALVANIZADO := 0.5
const PAINEL := 0.25
const TIPOS := {
    "boreste": {"cor": Color(0.78, 0.13, 0.10), "luz": Color(1.0, 0.16, 0.10), "periodo": 4.0, "aceso": 0.9},
    "bombordo": {"cor": Color(0.07, 0.50, 0.24), "luz": Color(0.12, 1.0, 0.34), "periodo": 4.0, "aceso": 0.9},
    "seguro": {"cor": Color(0.80, 0.14, 0.11), "luz": Color(1.0, 0.97, 0.86), "periodo": 8.0, "aceso": 4.0},
    "especial": {"cor": Color(0.92, 0.72, 0.10), "luz": Color(1.0, 0.80, 0.12), "periodo": 5.0, "aceso": 0.9},
}

var dados_radar: Array = []      # {mundo: Vector2, cor: Color}: o radar do HUD desenha pontinhos
var _boias: Array = []
var _oceano: Node = null
var _numeros: Dictionary = {"boreste": 0, "bombordo": -1, "seguro": 0, "especial": 0}
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
    _numeros = {"boreste": 0, "bombordo": -1, "seguro": 0, "especial": 0}
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
    var material := ShaderMaterial.new()
    material.shader = SHADER_BOIA
    material.set_shader_parameter("semente", float(indice) * 3.17 + 0.5)
    corpo.material_override = material
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
    material_luz.albedo_color = d["luz"].darkened(0.35)
    material_luz.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    material_luz.roughness = 0.12
    esfera.radius = 0.13
    esfera.height = 0.30
    esfera.is_hemisphere = false
    lanterna.position = Vector3(0.0, ALTURA_LUZ * ESCALA, 0.0)
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
    brilho.position = Vector3(0.0, ALTURA_LUZ * ESCALA, 0.0)
    brilho.pixel_size = 0.05
    brilho.visible = false
    raiz.add_child(brilho)
    _pintar_numero(raiz, tipo)
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

## Número pintado no flutuador (balizamento: vermelhas pares, verdes ímpares), dos dois lados.
func _pintar_numero(raiz: Node3D, tipo: String) -> void:
    if tipo != "boreste" and tipo != "bombordo":
        return
    _numeros[tipo] = int(_numeros[tipo]) + 2
    var texto: String = str(_numeros[tipo])
    for lado in [0.0, PI]:
        var rotulo := Label3D.new()
        rotulo.text = texto
        rotulo.font_size = 96
        rotulo.outline_size = 0
        rotulo.modulate = Color(0.93, 0.92, 0.86)
        rotulo.pixel_size = 0.0031 * ESCALA
        rotulo.double_sided = false
        rotulo.shaded = true
        rotulo.no_depth_test = false
        rotulo.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
        rotulo.visibility_range_end = 160.0
        rotulo.rotation = Vector3(0.0, lado, 0.0)
        rotulo.position = Vector3(sin(lado), 0.0, cos(lado)) * (1.0 * ESCALA) + Vector3(0.0, 0.5 * ESCALA, 0.0)
        raiz.get_node("Corpo").add_child(rotulo)
        # o rótulo é filho do corpo (que tem escala), então desfaz a escala na posição e no tamanho
        rotulo.position /= ESCALA
        rotulo.pixel_size /= ESCALA

## Uma malha só por boia, com as cores e o material nos vértices (uma chamada de desenho).
## Medidas em metros antes de ESCALA: flutuador de 2 m de diâmetro, luz a ~3,2 m, sinal de topo a ~4 m.
func _malha(tipo: String) -> ArrayMesh:
    var cor: Color = TIPOS[tipo]["cor"]
    var escuro := Color(0.12, 0.12, 0.13)
    var branco := Color(0.90, 0.89, 0.84)
    var pecas: Array = []
    # contrapeso e cauda (quase toda submersa)
    var cauda := CylinderMesh.new()
    cauda.top_radius = 0.30
    cauda.bottom_radius = 0.16
    cauda.height = 1.2
    cauda.radial_segments = 12
    pecas.append(_peca(cauda, Transform3D(Basis(), Vector3(0.0, -0.85, 0.0)), escuro, PINTADO))
    # flutuador
    if tipo == "seguro":
        var esfera := SphereMesh.new()
        esfera.radius = 1.0
        esfera.height = 1.7
        esfera.radial_segments = 24
        esfera.rings = 12
        var casco: Array = _peca(esfera, Transform3D(Basis(), Vector3(0.0, 0.2, 0.0)), branco, PINTADO)
        var cores: PackedColorArray = casco[0][Mesh.ARRAY_COLOR]
        var vs: PackedVector3Array = casco[0][Mesh.ARRAY_VERTEX]
        for i in vs.size():                       # gomos verticais vermelhos e brancos
            var gomo: int = int(floor((atan2(vs[i].z, vs[i].x) + PI) / (TAU / 8.0))) % 2
            cores[i] = Color(cor, PINTADO) if gomo == 0 else Color(branco, PINTADO)
        casco[0][Mesh.ARRAY_COLOR] = cores
        pecas.append(casco)
    else:
        var flut := CylinderMesh.new()
        flut.top_radius = 1.0
        flut.bottom_radius = 0.92
        flut.height = 0.92
        flut.radial_segments = 28
        pecas.append(_peca(flut, Transform3D(Basis(), Vector3(0.0, 0.14, 0.0)), cor, PINTADO))
        var chanfro := CylinderMesh.new()
        chanfro.top_radius = 0.86
        chanfro.bottom_radius = 1.0
        chanfro.height = 0.12
        chanfro.radial_segments = 28
        pecas.append(_peca(chanfro, Transform3D(Basis(), Vector3(0.0, 0.66, 0.0)), cor, PINTADO))
        var fundo := CylinderMesh.new()
        fundo.top_radius = 0.92
        fundo.bottom_radius = 0.55
        fundo.height = 0.25
        fundo.radial_segments = 28
        pecas.append(_peca(fundo, Transform3D(Basis(), Vector3(0.0, -0.445, 0.0)), cor, PINTADO))
    # defensa de borracha em volta, logo acima da linha d'água
    var defensa := TorusMesh.new()
    defensa.inner_radius = 0.93 if tipo != "seguro" else 0.92
    defensa.outer_radius = 1.13
    defensa.rings = 32
    defensa.ring_segments = 8
    pecas.append(_peca(defensa, Transform3D(Basis().scaled(Vector3(1.0, 0.75, 1.0)), Vector3(0.0, 0.30, 0.0)), escuro, BORRACHA))
    # convés galvanizado e olhais de amarração
    var conves := CylinderMesh.new()
    conves.top_radius = 0.80
    conves.bottom_radius = 0.84
    conves.height = 0.05
    conves.radial_segments = 24
    pecas.append(_peca(conves, Transform3D(Basis(), Vector3(0.0, 0.745, 0.0)), escuro, GALVANIZADO))
    for k in 3:
        var a: float = TAU * float(k) / 3.0 + 0.5
        var olhal := TorusMesh.new()
        olhal.inner_radius = 0.035
        olhal.outer_radius = 0.07
        olhal.rings = 10
        olhal.ring_segments = 6
        pecas.append(_peca(olhal, Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, -a), Vector3(cos(a) * 0.72, 0.80, sin(a) * 0.72)), escuro, PINTADO))
    # torre treliçada: 4 pernas inclinadas, aros e diagonais
    var base_r: float = 0.62
    var topo_r: float = 0.26
    var y0: float = 0.76
    var y1: float = 2.86
    for k in 4:
        var a: float = TAU * float(k) / 4.0 + PI * 0.25
        var pa := Vector3(cos(a) * base_r, y0, sin(a) * base_r)
        var pb := Vector3(cos(a) * topo_r, y1, sin(a) * topo_r)
        pecas.append(_barra(pa, pb, 0.045, cor, PINTADO))
        var a2: float = a + TAU / 4.0
        for nivel in [[y0, 1.55], [1.55, 2.3]]:
            var r0: float = lerpf(base_r, topo_r, (nivel[0] - y0) / (y1 - y0))
            var r1: float = lerpf(base_r, topo_r, (nivel[1] - y0) / (y1 - y0))
            pecas.append(_barra(Vector3(cos(a) * r0, nivel[0], sin(a) * r0), Vector3(cos(a2) * r1, nivel[1], sin(a2) * r1), 0.025, cor, PINTADO))
    for nivel in [1.55, 2.3]:
        var r: float = lerpf(base_r, topo_r, (nivel - y0) / (y1 - y0))
        var aro := TorusMesh.new()
        aro.inner_radius = r - 0.03
        aro.outer_radius = r + 0.03
        aro.rings = 16
        aro.ring_segments = 5
        pecas.append(_peca(aro, Transform3D(Basis(), Vector3(0.0, nivel, 0.0)), cor, PINTADO))
    # faixa de sinalização (chapas cheias que dão a cor de longe)
    var faixa := CylinderMesh.new()
    faixa.top_radius = lerpf(base_r, topo_r, (2.2 - y0) / (y1 - y0)) + 0.02
    faixa.bottom_radius = lerpf(base_r, topo_r, (1.35 - y0) / (y1 - y0)) + 0.02
    faixa.height = 0.85
    faixa.radial_segments = 20
    pecas.append(_peca(faixa, Transform3D(Basis(), Vector3(0.0, 1.775, 0.0)), cor if tipo != "seguro" else branco, PINTADO))
    if tipo == "especial":
        var listra := CylinderMesh.new()
        listra.top_radius = faixa.top_radius + 0.005
        listra.bottom_radius = faixa.bottom_radius + 0.005
        listra.height = 0.12
        listra.radial_segments = 20
        pecas.append(_peca(listra, Transform3D(Basis(), Vector3(0.0, 1.775, 0.0)), escuro, PINTADO))
    # painéis solares inclinados, virados para fora
    for k in 3:
        var a: float = TAU * float(k) / 3.0
        var painel := BoxMesh.new()
        painel.size = Vector3(0.42, 0.03, 0.34)
        var dir := Vector3(cos(a), 0.0, sin(a))
        var b := Basis(Vector3.UP, -a + PI * 0.5) * Basis(Vector3.RIGHT, deg_to_rad(-52.0))
        pecas.append(_peca(painel, Transform3D(b, dir * 0.36 + Vector3(0.0, 2.62, 0.0)), escuro, PAINEL))
    # plataforma da lanterna, cesto e tampa
    var plat := CylinderMesh.new()
    plat.top_radius = 0.32
    plat.bottom_radius = 0.30
    plat.height = 0.05
    plat.radial_segments = 16
    pecas.append(_peca(plat, Transform3D(Basis(), Vector3(0.0, 2.9, 0.0)), escuro, GALVANIZADO))
    for k in 4:
        var a: float = TAU * float(k) / 4.0
        pecas.append(_barra(Vector3(cos(a) * 0.2, 2.92, sin(a) * 0.2), Vector3(cos(a) * 0.2, 3.42, sin(a) * 0.2), 0.018, escuro, GALVANIZADO))
    var base_luz := CylinderMesh.new()
    base_luz.top_radius = 0.12
    base_luz.bottom_radius = 0.14
    base_luz.height = 0.12
    base_luz.radial_segments = 12
    pecas.append(_peca(base_luz, Transform3D(Basis(), Vector3(0.0, 2.99, 0.0)), escuro, GALVANIZADO))
    var tampa := CylinderMesh.new()
    tampa.top_radius = 0.16
    tampa.bottom_radius = 0.24
    tampa.height = 0.06
    tampa.radial_segments = 12
    pecas.append(_peca(tampa, Transform3D(Basis(), Vector3(0.0, 3.45, 0.0)), escuro, GALVANIZADO))
    # mastro do sinal de topo
    pecas.append(_barra(Vector3(0.0, 3.47, 0.0), Vector3(0.0, 3.72, 0.0), 0.035, escuro, GALVANIZADO))
    # sinal de topo: lata verde, cone vermelho, esfera (águas seguras), cruz amarela
    match tipo:
        "bombordo":
            var lata := CylinderMesh.new()
            lata.top_radius = 0.26
            lata.bottom_radius = 0.26
            lata.height = 0.46
            lata.radial_segments = 16
            pecas.append(_peca(lata, Transform3D(Basis(), Vector3(0.0, 3.95, 0.0)), cor, PINTADO))
        "boreste":
            var cone := CylinderMesh.new()
            cone.top_radius = 0.0
            cone.bottom_radius = 0.32
            cone.height = 0.52
            cone.radial_segments = 16
            pecas.append(_peca(cone, Transform3D(Basis(), Vector3(0.0, 3.98, 0.0)), cor, PINTADO))
        "seguro":
            var bola := SphereMesh.new()
            bola.radius = 0.24
            bola.height = 0.48
            bola.radial_segments = 12
            bola.rings = 6
            pecas.append(_peca(bola, Transform3D(Basis(), Vector3(0.0, 3.95, 0.0)), Color(0.80, 0.14, 0.11), PINTADO))
        "especial":
            for sinal in [-1.0, 1.0]:
                var barra := BoxMesh.new()
                barra.size = Vector3(0.7, 0.1, 0.1)
                pecas.append(_peca(barra, Transform3D(Basis(Vector3.BACK, deg_to_rad(45.0 * float(sinal))), Vector3(0.0, 3.95, 0.0)), cor, PINTADO))
    return Mesclador._juntar(pecas)

## Barra cilíndrica de pa até pb.
func _barra(pa: Vector3, pb: Vector3, raio: float, cor: Color, material: float) -> Array:
    var cil := CylinderMesh.new()
    cil.top_radius = raio
    cil.bottom_radius = raio
    cil.height = pa.distance_to(pb)
    cil.radial_segments = 6
    cil.rings = 1
    var dir: Vector3 = (pb - pa).normalized()
    var b := Basis(Quaternion(Vector3.UP, dir))
    return _peca(cil, Transform3D(b, (pa + pb) * 0.5), cor, material)

## [vértices, transformação, nó] com a cor gravada nos vértices (formato que Mesclador._juntar espera).
func _peca(malha: Mesh, t: Transform3D, cor: Color, material: float = PINTADO) -> Array:
    var matriz: Array = malha.get_mesh_arrays()
    var n: int = (matriz[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
    var cores := PackedColorArray()
    cores.resize(n)
    cores.fill(Color(cor, material))
    matriz[Mesh.ARRAY_COLOR] = cores
    return [matriz, t, null]
