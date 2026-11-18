extends Node3D
## Baleias ocasionais: trajetos suaves, respiracoes, mergulho e ondulacao de superficie.
## Nao sao alvo de pesca e nunca bloqueiam o jogador.
## Geometria local leve, sem dependências externas nem novas cenas.

const PRIMEIRA_APARICAO := Vector2(75.0, 120.0)
const INTERVALO := Vector2(195.0, 320.0)
const VIDA := 64.0
const DIST_MIN := 115.0
const DIST_MAX := 220.0

var simulando: bool = false
var _barco: Node3D
var _oceano: Node
var _mundo: Node
var _cardumes: Node3D
var _corpo: Node3D
var _cauda: Node3D
var _borrifo: CPUParticles3D
var _ativo: bool = false
var _contagem: float = 110.0
var _tempo_vida: float = 0.0
var _nadando: Vector2 = Vector2(0.0, 1.0)
var _soprou: bool = false
var _proximo_sopro: float = 14.5
var _sopros: int = 0
var _proxima_curva: float = 15.0
var _rumo_alvo: float = 0.0
var _velocidade_nado: float = 1.6
var _anel: MeshInstance3D
var _material_anel: StandardMaterial3D
var _anel_tempo: float = -1.0
var _audio_sopro: AudioStreamPlayer3D

func _ready() -> void:
    _barco = get_node_or_null("../Barco")
    _oceano = get_node_or_null("../Oceano")
    _mundo = get_parent()
    _cardumes = get_node_or_null("../Cardumes")
    _criar_modelo()
    reiniciar()

func reiniciar() -> void:
    _ativo = false
    _contagem = randf_range(PRIMEIRA_APARICAO.x, PRIMEIRA_APARICAO.y)
    _tempo_vida = 0.0
    _soprou = false
    _sopros = 0
    _proximo_sopro = 14.5
    _anel_tempo = -1.0
    if _anel != null:
        _anel.visible = false
    if _corpo != null:
        _corpo.visible = false

func _material(cor: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = cor
    m.roughness = 0.82
    m.metallic_specular = 0.12
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _oval(pai: Node3D, nome: String, pos: Vector3, escala: Vector3, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = nome
    var esfera := SphereMesh.new()
    esfera.radius = 1.0
    esfera.height = 2.0
    esfera.radial_segments = 16
    esfera.rings = 9
    node.mesh = esfera
    node.material_override = mat
    node.position = pos
    node.scale = escala
    pai.add_child(node)
    return node

func _asa(pai: Node3D, nome: String, pontos: Array, mat: Material) -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for tri in [[0, 1, 2], [0, 2, 3]]:
        for index in tri:
            st.set_normal(Vector3.UP)
            st.add_vertex(pontos[index])
    var malha := MeshInstance3D.new()
    malha.name = nome
    malha.mesh = st.commit()
    malha.material_override = mat
    pai.add_child(malha)

func _criar_modelo() -> void:
    _corpo = Node3D.new()
    _corpo.name = "BaleiaAzul"
    _corpo.visible = false
    add_child(_corpo)
    var dorsal := _material(Color(0.13, 0.26, 0.32))
    var dorso := _material(Color(0.20, 0.37, 0.43))
    var ventre := _material(Color(0.41, 0.51, 0.53))
    var olhos := _material(Color(0.025, 0.07, 0.09))

    _oval(_corpo, "Costas", Vector3(0.0, 0.0, -0.7), Vector3(1.65, 0.90, 4.10), dorso)
    _oval(_corpo, "Barriga", Vector3(0.0, -0.46, -0.9), Vector3(1.28, 0.53, 3.35), ventre)
    _oval(_corpo, "Cabeca", Vector3(0.0, -0.05, -3.3), Vector3(1.5, 0.72, 1.70), dorso)
    _oval(_corpo, "Pedunculo", Vector3(0.0, -0.01, 3.55), Vector3(0.53, 0.32, 2.40), dorso)
    for lado in [-1.0, 1.0]:
        _oval(_corpo, "Olho", Vector3(lado * 1.38, 0.10, -3.65), Vector3(0.095, 0.085, 0.11), olhos)
        _asa(_corpo, "Nadadeira", [Vector3(lado * 1.1, -0.18, -1.7),
                Vector3(lado * 3.5, -0.52, 0.4), Vector3(lado * 3.2, -0.50, 0.9),
                Vector3(lado * 1.0, -0.27, 0.2)], dorsal)
    var dorsal_fin := _oval(_corpo, "Dorsal", Vector3(0.0, 0.73, 2.1), Vector3(0.22, 0.48, 0.58), dorsal)
    dorsal_fin.rotation.x = -0.25

    _cauda = Node3D.new()
    _cauda.name = "Cauda"
    _cauda.position = Vector3(0.0, -0.02, 5.25)
    _corpo.add_child(_cauda)
    _asa(_cauda, "NadadeiraCaudal", [Vector3(-3.1, 0.0, 1.0), Vector3(-0.4, 0.0, 0.1),
            Vector3(0.4, 0.0, 0.1), Vector3(3.1, 0.0, 1.0)], dorsal)
    _oval(_cauda, "CentroCauda", Vector3.ZERO, Vector3(0.48, 0.19, 0.53), dorso)

    _borrifo = CPUParticles3D.new()
    _borrifo.name = "Borrifo"
    _borrifo.amount = 36
    _borrifo.lifetime = 1.9
    _borrifo.one_shot = true
    _borrifo.explosiveness = 0.76
    _borrifo.emitting = false
    _borrifo.direction = Vector3(0.0, 1.0, 0.0)
    _borrifo.spread = 18.0
    _borrifo.gravity = Vector3(0.0, -3.8, 0.0)
    _borrifo.initial_velocity_min = 4.0
    _borrifo.initial_velocity_max = 7.0
    _borrifo.scale_amount_min = 0.18
    _borrifo.scale_amount_max = 0.48
    _borrifo.color = Color(0.87, 0.95, 0.97, 0.64)
    var gota := SphereMesh.new()
    gota.radius = 0.07
    gota.height = 0.14
    gota.radial_segments = 5
    gota.rings = 3
    var gota_mat := StandardMaterial3D.new()
    gota_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    gota_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    gota_mat.albedo_color = Color(0.90, 0.97, 1.0, 0.66)
    gota.material = gota_mat
    _borrifo.mesh = gota
    _borrifo.position = Vector3(0.0, 0.85, -3.3)
    _corpo.add_child(_borrifo)

    # Anel discreto de agua no ponto onde a baleia respira.
    _anel = MeshInstance3D.new()
    _anel.name = "MarolaDaBaleia"
    var torus := TorusMesh.new()
    torus.inner_radius = 0.92
    torus.outer_radius = 1.08
    torus.rings = 20
    torus.ring_segments = 48
    _anel.mesh = torus
    _material_anel = StandardMaterial3D.new()
    _material_anel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material_anel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material_anel.albedo_color = Color(0.85, 0.95, 0.96, 0.0)
    _material_anel.cull_mode = BaseMaterial3D.CULL_DISABLED
    _anel.material_override = _material_anel
    _anel.visible = false
    add_child(_anel)

    _audio_sopro = AudioStreamPlayer3D.new()
    _audio_sopro.name = "RespiracaoBaleia"
    _audio_sopro.bus = "Mar"            # sopro das baleias: junto do mar
    _audio_sopro.volume_db = -10.0
    _audio_sopro.unit_size = 45.0
    _audio_sopro.max_distance = 280.0
    var caminho_audio := "res://assets/sons/baleia_sopro.wav"
    if ResourceLoader.exists(caminho_audio):
        _audio_sopro.stream = load(caminho_audio)
    _corpo.add_child(_audio_sopro)

func _tentar_aparecer(teste: bool = false) -> bool:
    if _barco == null or _mundo == null:
        return false
    if not teste and _oceano != null and float(_oceano.tempestade_nivel) > 0.45:
        return false
    var origem := _barco.global_position
    for _i in 24:
        var ang: float = randf_range(0.0, TAU)
        var distancia_aleatoria: float = randf_range(90.0, 155.0) if teste else randf_range(DIST_MIN, DIST_MAX)
        var candidato := origem + Vector3(cos(ang) * distancia_aleatoria, 0.0, sin(ang) * distancia_aleatoria)
        if _mundo.has_method("distancia_da_costa") and _mundo.distancia_da_costa(candidato) < (105.0 if teste else 155.0):
            continue
        if _mundo.has_method("altura_terra") and _mundo.altura_terra(candidato) > -12.0:
            continue
        _corpo.global_position = candidato + Vector3.DOWN * 9.0
        var direcao: Vector2 = Vector2.from_angle(randf_range(0.0, TAU))
        _nadando = direcao
        _rumo_alvo = direcao.angle()
        _corpo.rotation.y = atan2(-direcao.x, -direcao.y)
        _velocidade_nado = randf_range(1.15, 1.95)
        _corpo.scale = Vector3.ONE * randf_range(0.86, 1.15)
        _tempo_vida = 0.0
        _soprou = false
        _sopros = 0
        _proximo_sopro = randf_range(13.5, 17.5)
        _proxima_curva = randf_range(12.0, 23.0)
        _anel_tempo = -1.0
        _anel.visible = false
        _ativo = true
        _corpo.visible = true
        return true
    return false

## Atalho de desenvolvimento: permite conferir a animacao sem aguardar minutos.
func testar_avistamento() -> String:
    if _ativo:
        return "Uma baleia já está nadando nesta região."
    if _tentar_aparecer(true):
        _tempo_vida = 8.0
        _contagem = randf_range(INTERVALO.x, INTERVALO.y)
        return "Avistamento! Baleia se aproximando da superfície."
    return "Baleias precisam de mar profundo. Afaste-se da costa e tente novamente."

func _emitir_sopro(posicao: Vector3) -> void:
    _borrifo.restart()
    _borrifo.emitting = true
    if _audio_sopro != null and _audio_sopro.stream != null:
        _audio_sopro.pitch_scale = randf_range(0.91, 1.08)
        _audio_sopro.play()
    if _cardumes != null and _cardumes.has_method("assustar_por_baleia"):
        _cardumes.assustar_por_baleia(posicao)
    if _anel != null:
        _anel_tempo = 0.0
        _anel.global_position = Vector3(posicao.x, (_oceano.altura_em(posicao) if _oceano != null else 0.0) + 0.12, posicao.z)
        _anel.visible = true
        _anel.scale = Vector3.ONE

func _atualizar_anel(delta: float) -> void:
    if _anel_tempo < 0.0 or _anel == null:
        return
    _anel_tempo += delta
    var f: float = clampf(_anel_tempo / 4.0, 0.0, 1.0)
    _anel.scale = Vector3.ONE * lerpf(0.75, 4.5, f)
    _material_anel.albedo_color = Color(0.85, 0.95, 0.96, 0.32 * (1.0 - f))
    if _oceano != null:
        var p: Vector3 = _anel.global_position
        p.y = _oceano.altura_em(p) + 0.12
        _anel.global_position = p
    if f >= 1.0:
        _anel_tempo = -1.0
        _anel.visible = false

func _process(delta: float) -> void:
    if not simulando:
        return
    _atualizar_anel(delta)
    if not _ativo:
        _contagem -= delta
        if _contagem <= 0.0:
            _contagem = randf_range(45.0, 85.0) if not _tentar_aparecer() else randf_range(INTERVALO.x, INTERVALO.y)
        return

    var dt: float = minf(delta, 0.08)
    _tempo_vida += dt
    var t: float = _tempo_vida
    _proxima_curva -= dt
    var posicao: Vector3 = _corpo.global_position
    # Mudancas de direcao esparsas com interpolacao, nao nado em linha perfeitamente reta.
    if _proxima_curva <= 0.0:
        _proxima_curva = randf_range(13.0, 27.0)
        _rumo_alvo = _nadando.angle() + randf_range(-0.32, 0.32)
    var pos_projetada: Vector3 = posicao + Vector3(_nadando.x, 0.0, _nadando.y) * 60.0
    if _mundo != null and _mundo.has_method("distancia_da_costa"):
        var distancia_margem: float = _mundo.distancia_da_costa(pos_projetada)
        if distancia_margem < 135.0:
            _rumo_alvo = _nadando.angle() + 0.65
    if _barco != null:
        var para_fora: Vector2 = Vector2(posicao.x - _barco.global_position.x, posicao.z - _barco.global_position.z)
        if para_fora.length() < 45.0 and para_fora.length() > 0.1:
            _rumo_alvo = para_fora.angle()
            if para_fora.length() < 25.0 and t < 43.0:
                _tempo_vida = 43.0   # mergulha em vez de atravessar o barco
    var rumo_atual: float = _nadando.angle()
    rumo_atual = lerp_angle(rumo_atual, _rumo_alvo, clampf(dt * 0.20, 0.0, 0.08))
    _nadando = Vector2.from_angle(rumo_atual)
    posicao.x += _nadando.x * _velocidade_nado * dt
    posicao.z += _nadando.y * _velocidade_nado * dt
    var altura_mar: float = _oceano.altura_em(posicao) if _oceano != null else 0.0
    var profundidade: float = -10.0
    var arfagem: float = 0.0
    if t < 13.0:
        var f_subida: float = smoothstep(0.0, 13.0, t)
        profundidade = lerpf(-9.0, 0.12, f_subida)
        arfagem = 0.18 * sin(PI * f_subida)
    elif t < 43.0:
        profundidade = 0.12 + 0.14 * sin(t * 0.29)
        arfagem = 0.025 * sin(t * 0.40)
    else:
        var f_mergulho: float = smoothstep(43.0, VIDA, t)
        profundidade = lerpf(0.12, -13.0, f_mergulho)
        arfagem = -0.25 * sin(PI * f_mergulho)
    posicao.y = altura_mar + profundidade
    _corpo.global_position = posicao
    _corpo.rotation.y = lerp_angle(_corpo.rotation.y, atan2(-_nadando.x, -_nadando.y), clampf(dt * 1.8, 0.0, 0.25))
    _corpo.rotation.x = arfagem + 0.025 * sin(t * 0.8)
    _corpo.rotation.z = 0.035 * sin(t * 0.23)
    # As barbatanas caudais batem para cima e para baixo, nao lateralmente.
    _cauda.rotation.x = 0.19 * sin(t * 1.55)
    _cauda.rotation.z = 0.035 * sin(t * 0.6)

    if t >= _proximo_sopro and t < 39.0 and _sopros < 3:
        _emitir_sopro(posicao)
        _sopros += 1
        _proximo_sopro = t + randf_range(9.0, 13.0)
    if t >= VIDA:
        _ativo = false
        _corpo.visible = false
