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
    for especie in ["golfinho", "tartaruga", "ave", "ave", "ave"]:
        var modelo: Node3D = _modelo(especie)
        add_child(modelo)
        _animais.append({"especie": especie, "no": modelo, "rumo": randf_range(0.0, TAU), "vel": randf_range(0.7, 1.7), "fase": randf() * TAU})
    reiniciar()

const Mesclador = preload("res://scripts/mesclador.gd")

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
    if especie == "golfinho":
        var cinza := Color(0.38, 0.53, 0.60)
        var claro := Color(0.80, 0.86, 0.87)
        _malha_no(grupo, "Corpo", [
            Mesclador.elipsoide(Vector3(0, 0, 0), Vector3(0.62, 0.42, 1.75), cinza),
            Mesclador.elipsoide(Vector3(0, -0.16, 0.05), Vector3(0.55, 0.30, 1.55), claro),
            Mesclador.elipsoide(Vector3(0, -0.06, -1.72), Vector3(0.17, 0.14, 0.62), cinza),          # rostro
            Mesclador.elipsoide(Vector3(0, 0.10, -1.30), Vector3(0.30, 0.26, 0.42), cinza),           # testa
            Mesclador.elipsoide(Vector3(0, 0.46, 0.15), Vector3(0.08, 0.40, 0.30), cinza, Vector3(26, 0, 0)),   # dorsal inclinada para trás
            Mesclador.elipsoide(Vector3(-0.50, -0.20, -0.55), Vector3(0.38, 0.05, 0.18), cinza, Vector3(0, 0, 30)),   # peitorais
            Mesclador.elipsoide(Vector3(0.50, -0.20, -0.55), Vector3(0.38, 0.05, 0.18), cinza, Vector3(0, 0, -30)),
            Mesclador.elipsoide(Vector3(0, 0.02, 1.55), Vector3(0.20, 0.20, 0.65), cinza),            # pedúnculo da cauda
            Mesclador.elipsoide(Vector3(0, 0.03, 2.22), Vector3(0.78, 0.055, 0.25), cinza),           # nadadeira caudal
        ])
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
        var branco := Color(0.93, 0.92, 0.86)
        var ponta := Color(0.36, 0.38, 0.42)
        _malha_no(grupo, "Tronco", [
            Mesclador.elipsoide(Vector3(0, 0, 0), Vector3(0.17, 0.15, 0.50), branco),
            Mesclador.elipsoide(Vector3(0, 0.05, -0.50), Vector3(0.11, 0.11, 0.12), branco),          # cabeça
            Mesclador.elipsoide(Vector3(0, 0.03, -0.66), Vector3(0.035, 0.035, 0.12), Color(0.95, 0.68, 0.18)),   # bico
            Mesclador.elipsoide(Vector3(0, 0.0, 0.52), Vector3(0.12, 0.03, 0.22), branco),            # cauda
        ])
        for lado in [-1.0, 1.0]:
            var asa := Node3D.new()
            asa.name = "AsaEsquerda" if lado < 0.0 else "AsaDireita"
            asa.position = Vector3(float(lado) * 0.1, 0.02, 0.0)
            grupo.add_child(asa)
            _malha_no(asa, "Pena", [
                Mesclador.elipsoide(Vector3(float(lado) * 0.34, 0, 0), Vector3(0.36, 0.05, 0.17), branco),
                Mesclador.elipsoide(Vector3(float(lado) * 0.74, 0, 0.02), Vector3(0.30, 0.045, 0.14), ponta),
            ])
    return grupo

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
    for animal in _animais:
        var no: Node3D = animal.no
        var pos: Vector3 = _posicao_segura(65.0, 175.0)
        var especie: String = String(animal.especie)
        pos.y = 8.0 if especie == "ave" else -0.5
        no.position = pos
        animal.rumo = randf_range(0.0, TAU)
        animal.fase = randf_range(0.0, TAU)

func _process(delta: float) -> void:
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
            asa_esquerda.rotation.z = sin(fase * 2.0) * 0.32
            asa_direita.rotation.z = -sin(fase * 2.0) * 0.32
        no.rotation.y = float(animal.rumo)
