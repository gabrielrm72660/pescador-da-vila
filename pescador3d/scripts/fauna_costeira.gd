extends Node3D
## Fauna leve: golfinhos, tartarugas e aves. Não participa da captura.
var simulando: bool = false
var _barco: Node3D
var _oceano: Node3D
var _mundo: Node
var _animais: Array = []
var _acumulado: float = 0.0
var _tempo: float = 0.0

func _ready() -> void:
    _barco = get_node_or_null("../Barco") as Node3D
    _oceano = get_node_or_null("../Oceano") as Node3D
    _mundo = get_parent()
    for especie in ["tartaruga", "ave", "ave", "ave"]:     # v0.8.0: os golfinhos agora são um grupo à parte (golfinhos.gd)
        var modelo: Node3D = _modelo(especie)
        add_child(modelo)
        _animais.append({"especie": especie, "no": modelo, "rumo": randf_range(0.0, TAU), "vel": randf_range(0.7, 1.7), "fase": randf() * TAU})
    _golfinhos = Golfinhos.new()
    _golfinhos.name = "Golfinhos"
    add_child(_golfinhos)
    _golfinhos.construir(_barco, _oceano, _mundo)
    reiniciar()

const Golfinhos = preload("res://scripts/golfinhos.gd")
var _golfinhos: Node3D

const Mesclador = preload("res://scripts/mesclador.gd")
const Arq = preload("res://scripts/arquitetura_malhas.gd")

## Todos os bichos usam um material só, com a cor gravada nos vértices; cada um é uma malha (a ave tem as asas à parte, que batem).
var _material_bicho: StandardMaterial3D

func _malha_no(pai: Node3D, nome: String, pecas: Array, posicao: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    if _material_bicho == null:
        _material_bicho = StandardMaterial3D.new()
        _material_bicho.vertex_color_use_as_albedo = true
        _material_bicho.roughness = 0.82
    var mesh := MeshInstance3D.new()
    mesh.name = nome
    mesh.mesh = Mesclador._juntar(pecas)
    mesh.material_override = _material_bicho
    mesh.position = posicao
    mesh.visibility_range_end = 420.0
    mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pai.add_child(mesh)
    return mesh

func _modelo(especie: String) -> Node3D:
    var grupo := Node3D.new()
    grupo.name = especie.capitalize()
    if especie == "golfinho":                                      # v0.5.7: malha por seções (scripts/arquitetura_malhas.gd)
        if _material_bicho == null:
            _material_bicho = StandardMaterial3D.new()
            _material_bicho.vertex_color_use_as_albedo = true
            _material_bicho.roughness = 0.82
        var corpo := MeshInstance3D.new()
        corpo.name = "Corpo"
        corpo.mesh = Arq.golfinho()
        corpo.material_override = _material_bicho
        corpo.visibility_range_end = 420.0
        corpo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        grupo.add_child(corpo)
    elif especie == "tartaruga":
        var casco := Color(0.28, 0.38, 0.21)
        var placas := Color(0.42, 0.51, 0.27)
        var pele := Color(0.52, 0.60, 0.39)
        _malha_no(grupo, "Casco", [
            Mesclador.elipsoide(Vector3(0, 0, 0), Vector3(0.85, 0.28, 1.15), casco),
            Mesclador.elipsoide(Vector3(0, 0.13, -0.02), Vector3(0.62, 0.20, 0.86), placas),           # escudo claro no alto
            Mesclador.elipsoide(Vector3(0, -0.13, 0.0), Vector3(0.72, 0.12, 1.0), Color(0.78, 0.72, 0.50)),   # plastrão
            Mesclador.elipsoide(Vector3(0, 0.02, -1.25), Vector3(0.26, 0.22, 0.40), pele),            # cabeça
            Mesclador.elipsoide(Vector3(-1.0, -0.04, -0.55), Vector3(0.62, 0.07, 0.22), pele, Vector3(0, -28, 0)),   # nadadeiras da frente
            Mesclador.elipsoide(Vector3(1.0, -0.04, -0.55), Vector3(0.62, 0.07, 0.22), pele, Vector3(0, 28, 0)),
            Mesclador.elipsoide(Vector3(-0.62, -0.04, 0.95), Vector3(0.28, 0.06, 0.20), pele, Vector3(0, 20, 0)),    # de trás
            Mesclador.elipsoide(Vector3(0.62, -0.04, 0.95), Vector3(0.28, 0.06, 0.20), pele, Vector3(0, -20, 0)),
        ])
    else:
        # v0.8.2: atobá pintado (SpriteCook, visto de cima): corpo e as duas asas são cartões recortados pelo alfa;
        # cada asa gira na raiz para bater. Envergadura ~1,7 m.
        _cartao_ave(grupo, "Tronco", Rect2(925, 34, 198, 1083), Vector2(1024, 600))
        for lado in [-1.0, 1.0]:
            var asa := Node3D.new()
            asa.name = "AsaEsquerda" if lado < 0.0 else "AsaDireita"
            var raiz_px: float = 925.0 if lado < 0.0 else 1123.0
            asa.position = Vector3((raiz_px - 1024.0) * ESCALA_AVE, 0.0, 0.0)
            grupo.add_child(asa)
            var faixa := Rect2(19, 330, 906, 430) if lado < 0.0 else Rect2(1123, 330, 907, 430)
            _cartao_ave(asa, "Pena", faixa, Vector2(raiz_px, 600))
    return grupo

const ESCALA_AVE := 1.7 / 2010.0          # m por pixel da pintura do atobá (2010 px de ponta a ponta das asas)
const RECORTE_AVE := Rect2(19, 34, 2011, 1084)   # parte da pintura original que está em assets/fauna/atoba.png
var _material_ave: StandardMaterial3D

## Cartão horizontal com um pedaço da pintura do atobá (px da pintura original); "origem" = px que fica no ponto 0
## do nó (para as asas, a raiz). Bico para -Z.
func _cartao_ave(pai: Node3D, nome: String, px: Rect2, origem: Vector2) -> void:
    if _material_ave == null:
        _material_ave = StandardMaterial3D.new()
        _material_ave.albedo_texture = load("res://assets/fauna/atoba.png")
        _material_ave.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        _material_ave.alpha_scissor_threshold = 0.5
        _material_ave.cull_mode = BaseMaterial3D.CULL_DISABLED
        _material_ave.roughness = 0.9
        _material_ave.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    var v := PackedVector3Array()
    var uv := PackedVector2Array()
    var cantos := [px.position, Vector2(px.end.x, px.position.y), px.end, Vector2(px.position.x, px.end.y)]
    for q in cantos:
        v.append(Vector3((q.x - origem.x) * ESCALA_AVE, 0.0, (q.y - origem.y) * ESCALA_AVE))
        uv.append((q - RECORTE_AVE.position) / RECORTE_AVE.size)
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = v
    arr[Mesh.ARRAY_TEX_UV] = uv
    arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
    arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var mi := MeshInstance3D.new()
    mi.name = nome
    mi.mesh = am
    mi.material_override = _material_ave
    mi.visibility_range_end = 420.0
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pai.add_child(mi)

func _posicao_segura(dist_min: float, dist_max: float) -> Vector3:
    if _barco == null:
        return Vector3.ZERO
    var origem: Vector3 = _barco.global_position
    for _k in 14:
        var ang: float = randf_range(0.0, TAU)
        var dist: float = randf_range(dist_min, dist_max)
        var pos: Vector3 = origem + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
        if _mundo != null and _mundo.has_method("altura_terra") and float(_mundo.altura_terra(pos)) > -4.5:
            continue
        return pos
    return origem + Vector3(120, 0, 40)

func reiniciar() -> void:
    if _golfinhos != null:
        _golfinhos.reiniciar()
    for animal in _animais:
        var no: Node3D = animal.no
        var pos: Vector3 = _posicao_segura(65.0, 175.0)
        var especie: String = String(animal.especie)
        pos.y = 8.0 if especie == "ave" else -0.5
        no.position = pos
        animal.rumo = randf_range(0.0, TAU)
        animal.fase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
    if _golfinhos != null:
        _golfinhos.simulando = simulando
    if not simulando or _barco == null:
        return
    _tempo += delta
    _acumulado += delta
    if _acumulado < 0.065:
        return
    var dt: float = minf(_acumulado, 0.15)
    _acumulado = 0.0
    for animal in _animais:
        var no: Node3D = animal.no
        var especie: String = String(animal.especie)
        var dist: float = Vector2(no.position.x - _barco.position.x, no.position.z - _barco.position.z).length()
        if dist > 270.0:
            var nova: Vector3 = _posicao_segura(100.0, 180.0)
            no.position = nova
            animal.rumo = randf_range(0.0, TAU)
        animal.rumo = float(animal.rumo) + sin(_tempo * 0.18 + float(animal.fase)) * dt * 0.12
        var direcao := Vector3(sin(float(animal.rumo)), 0.0, -cos(float(animal.rumo)))
        var passo: Vector3 = direcao * float(animal.vel) * dt * (2.0 if especie == "golfinho" else 1.0)
        var candidato: Vector3 = no.position + passo
        if especie != "ave" and _mundo != null and _mundo.has_method("altura_terra") and float(_mundo.altura_terra(candidato)) > -3.5:
            animal.rumo = float(animal.rumo) + PI * 0.65
        else:
            no.position = candidato
        var nivel: float = float(_oceano.altura_em(no.position)) if _oceano != null else 0.0
        var fase: float = _tempo * (1.5 if especie == "tartaruga" else 2.3) + float(animal.fase)
        if especie == "golfinho":
            var salto: float = pow(maxf(0.0, sin(fase * 0.5)), 3.0) * 2.1
            no.position.y = nivel - 0.75 + salto
            no.rotation.x = sin(fase * 0.5) * 0.16
        elif especie == "tartaruga":
            no.position.y = nivel - 0.42 + 0.12 * sin(fase)
        else:
            no.position.y = nivel + 6.0 + 1.6 * sin(fase * 0.30)
            var asa_esquerda: Node3D = no.get_node("AsaEsquerda")
            var asa_direita: Node3D = no.get_node("AsaDireita")
            # atobá: bate as asas umas vezes e plana; planando, asas quase retas, só balançando com o vento
            var plana: float = smoothstep(0.2, 0.6, sin(fase * 0.22))
            var batida: float = sin(fase * 2.6) * 0.42 * (1.0 - plana) + (0.06 + 0.03 * sin(fase * 0.9)) * plana
            asa_esquerda.rotation.z = batida
            asa_direita.rotation.z = -batida
            no.rotation.z = 0.10 * sin(float(animal.rumo) * 3.0 + fase * 0.2)      # inclina nas curvas
        # v0.8.2: o modelo olha para -Z; com rotation.y = rumo ele andava de lado (para frente é -rumo)
        no.rotation.y = -float(animal.rumo)
