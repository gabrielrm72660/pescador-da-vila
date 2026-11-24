extends Node3D
## Baleias ocasionais (v0.8.0: jubarte). Nao sao alvo de pesca e nunca bloqueiam o jogador.
## Modelo: malha feita da pintura de lado do SpriteCook (ferramentas/cetaceos.py), com o corpo inteiro ondulando no
## shader (shaders/cetaceo.gdshader). Comportamento de uma aparicao (~64 s):
##   sobe do fundo -> nada na superficie soprando (3 sopros) -> mergulha mostrando a cauda (a cauda sobe fora d'agua).
##   (desligado em v0.8.1, SALTA = false) Em ~40% das aparicoes ela SALTA no meio: afunda, vira de bico para cima, sai quase inteira da agua, gira de lado
##   e cai com um estouro de espuma.

const FaunaMalha = preload("res://scripts/fauna_malha.gd")
const PRIMEIRA_APARICAO := Vector2(75.0, 120.0)
const INTERVALO := Vector2(195.0, 320.0)
const VIDA := 64.0
const T_MERGULHO := 43.0
const T_SALTO := 24.0
const DURACAO_SALTO := 8.0
const DIST_MIN := 115.0
const DIST_MAX := 220.0
const SALTA := false                # v0.8.1: o Gabriel prefere a baleia só nadando (o salto fica pronto, desligado)
const PROF_SUPERFICIE := -0.70      # centro do corpo abaixo da agua: so o dorso (~0,6 m) fica de fora

var simulando: bool = false
var _barco: Node3D
var _oceano: Node
var _mundo: Node
var _cardumes: Node3D
var _corpo: Node3D
var _malha: MeshInstance3D
var _mat: ShaderMaterial
var _borrifo: CPUParticles3D
var _espirro: CPUParticles3D        # estouro de agua do salto
var _ativo: bool = false
var _contagem: float = 110.0
var _tempo_vida: float = 0.0
var _nadando: Vector2 = Vector2(0.0, 1.0)
var _rumo_visto: Vector2 = Vector2(0.0, 1.0)
var _soprou: bool = false
var _proximo_sopro: float = 14.5
var _sopros: int = 0
var _proxima_curva: float = 15.0
var _rumo_alvo: float = 0.0
var _velocidade_nado: float = 1.6
var _escala: float = 1.0
var _vai_saltar: bool = false
var _espirros_feitos: int = 0
var _fase: float = 0.0
var _fase_remada: float = 0.0
var _anel: MeshInstance3D
var _material_anel: StandardMaterial3D
var _anel_tempo: float = -1.0
var _anel_tamanho: float = 4.5
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

func _particulas(nome: String, quantidade: int, vida: float, vel: Vector2, tam: Vector2, espalha: float, cor: Color) -> CPUParticles3D:
    var p := CPUParticles3D.new()
    p.name = nome
    p.amount = quantidade
    p.lifetime = vida
    p.one_shot = true
    p.explosiveness = 0.8
    p.emitting = false
    p.direction = Vector3(0.0, 1.0, 0.0)
    p.spread = espalha
    p.gravity = Vector3(0.0, -6.5, 0.0)
    p.initial_velocity_min = vel.x
    p.initial_velocity_max = vel.y
    p.scale_amount_min = tam.x
    p.scale_amount_max = tam.y
    p.color = cor
    var gota := SphereMesh.new()
    gota.radius = 0.07
    gota.height = 0.14
    gota.radial_segments = 5
    gota.rings = 3
    var gota_mat := StandardMaterial3D.new()
    gota_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    gota_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    gota_mat.albedo_color = Color(0.90, 0.97, 1.0, 0.66)
    gota_mat.vertex_color_use_as_albedo = true
    gota.material = gota_mat
    p.mesh = gota
    return p

func _criar_modelo() -> void:
    _corpo = Node3D.new()
    _corpo.name = "Jubarte"
    _corpo.visible = false
    add_child(_corpo)
    _malha = FaunaMalha.instancia("jubarte")
    _malha.extra_cull_margin = 8.0
    _malha.visibility_range_end = 900.0
    _corpo.add_child(_malha)
    _mat = _malha.material_override as ShaderMaterial

    _borrifo = _particulas("Borrifo", 40, 1.9, Vector2(4.5, 7.5), Vector2(0.20, 0.52), 16.0, Color(0.87, 0.95, 0.97, 0.64))
    _borrifo.gravity = Vector3(0.0, -3.8, 0.0)
    _borrifo.position = Vector3(0.0, 1.2, -3.0)            # espiráculo, atrás da cabeça
    _corpo.add_child(_borrifo)

    _espirro = _particulas("Espirro", 140, 2.4, Vector2(5.0, 12.0), Vector2(0.35, 1.0), 62.0, Color(0.92, 0.97, 0.98, 0.75))
    _espirro.top_level = true                               # fica onde a água estourou, não segue a baleia
    _espirro.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    _espirro.emission_sphere_radius = 2.5
    add_child(_espirro)

    # Anel discreto de agua no ponto onde a baleia respira (e grande, onde ela cai depois do salto).
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
        _rumo_visto = direcao
        _rumo_alvo = direcao.angle()
        _velocidade_nado = randf_range(1.15, 1.95)
        _escala = randf_range(0.86, 1.12)
        _tempo_vida = 0.0
        _soprou = false
        _sopros = 0
        _proximo_sopro = randf_range(13.5, 17.5)
        _proxima_curva = randf_range(12.0, 23.0)
        _vai_saltar = SALTA and (teste or randf() < 0.4)
        _espirros_feitos = 0
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
    _abrir_anel(posicao, 4.5)

func _abrir_anel(posicao: Vector3, tamanho: float) -> void:
    if _anel == null:
        return
    _anel_tempo = 0.0
    _anel_tamanho = tamanho
    _anel.global_position = Vector3(posicao.x, (_oceano.altura_em(posicao) if _oceano != null else 0.0) + 0.12, posicao.z)
    _anel.visible = true
    _anel.scale = Vector3.ONE

func _estourar(posicao: Vector3, forte: bool) -> void:
    var p := Vector3(posicao.x, (_oceano.altura_em(posicao) if _oceano != null else 0.0) + 0.3, posicao.z)
    _espirro.global_position = p
    _espirro.initial_velocity_max = 13.0 if forte else 8.0
    _espirro.amount = 160 if forte else 90
    _espirro.restart()
    _espirro.emitting = true
    _abrir_anel(p, 9.0 if forte else 6.0)
    if _audio_sopro != null and _audio_sopro.stream != null:
        _audio_sopro.pitch_scale = 0.55 if forte else 0.7      # o mesmo som, bem grave, vira o baque na água
        _audio_sopro.play()
    if _cardumes != null and _cardumes.has_method("assustar_por_baleia"):
        _cardumes.assustar_por_baleia(posicao)

func _atualizar_anel(delta: float) -> void:
    if _anel_tempo < 0.0 or _anel == null:
        return
    _anel_tempo += delta
    var f: float = clampf(_anel_tempo / 4.0, 0.0, 1.0)
    _anel.scale = Vector3.ONE * lerpf(0.75, _anel_tamanho, f)
    _material_anel.albedo_color = Color(0.85, 0.95, 0.96, 0.32 * (1.0 - f))
    if _oceano != null:
        var p: Vector3 = _anel.global_position
        p.y = _oceano.altura_em(p) + 0.12
        _anel.global_position = p
    if f >= 1.0:
        _anel_tempo = -1.0
        _anel.visible = false

static func _faixa(t: float, a: float, b: float) -> float:
    return smoothstep(a, b, t)

## Pose da baleia no tempo t: x = profundidade do centro (m, relativa à água), y = arfagem (+ bico para cima),
## z = rolagem; w = quanto ela "força" o nado (0 calma, 1 salto) para a ondulação e as nadadeiras.
func _pose(t: float) -> Vector4:
    var prof: float = PROF_SUPERFICIE
    var arf: float = 0.0
    var rol: float = 0.0
    var forca: float = 0.25
    if t < 13.0:
        var f: float = smoothstep(0.0, 13.0, t)
        prof = lerpf(-9.0, PROF_SUPERFICIE, f)
        arf = 0.16 * sin(PI * f)
        forca = 0.5
    elif t < T_MERGULHO:
        prof = PROF_SUPERFICIE + 0.12 * sin(t * 0.29)
        arf = 0.025 * sin(t * 0.40)
        rol = 0.04 * sin(t * 0.23)
        if _vai_saltar and t >= T_SALTO and t < T_SALTO + DURACAO_SALTO:
            var u: float = (t - T_SALTO) / DURACAO_SALTO
            # afunda e embica (0..0,3), vira de bico para cima lá embaixo (0,3..0,45), dispara para fora (0,45..0,68),
            # tomba de lado e cai (0,68..0,9), volta a nadar (0,9..1)
            prof = lerpf(PROF_SUPERFICIE, -9.0, _faixa(u, 0.0, 0.30))
            arf = lerpf(0.0, -0.5, _faixa(u, 0.0, 0.25))
            arf = lerpf(arf, 1.25, _faixa(u, 0.28, 0.45))
            prof = lerpf(prof, 4.5, _faixa(u, 0.45, 0.68))
            rol = lerpf(0.0, 0.8, _faixa(u, 0.48, 0.68))
            prof = lerpf(prof, -3.2, _faixa(u, 0.68, 0.90))
            arf = lerpf(arf, 0.15, _faixa(u, 0.68, 0.90))
            rol = lerpf(rol, 1.6, _faixa(u, 0.68, 0.90))
            prof = lerpf(prof, PROF_SUPERFICIE, _faixa(u, 0.90, 1.0))
            arf = lerpf(arf, 0.0, _faixa(u, 0.90, 1.0))
            rol = lerpf(rol, 0.0, _faixa(u, 0.88, 1.0))
            forca = 0.6 + 0.4 * sin(PI * clampf(u * 1.2, 0.0, 1.0))
    else:
        # mergulho de cauda: arqueia o dorso, embica e a cauda sobe para fora d'água antes de sumir
        var f: float = clampf((t - T_MERGULHO) / (VIDA - T_MERGULHO), 0.0, 1.0)
        prof = lerpf(PROF_SUPERFICIE, -1.4, _faixa(f, 0.0, 0.25))
        arf = lerpf(0.0, -0.32, _faixa(f, 0.0, 0.25))
        arf = lerpf(arf, -1.22, _faixa(f, 0.22, 0.52))
        prof = lerpf(prof, -3.1, _faixa(f, 0.22, 0.52))
        prof = lerpf(prof, -17.0, _faixa(f, 0.55, 1.0))
        forca = 0.45
    return Vector4(prof, arf, rol, forca)

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
            var no_salto: bool = _vai_saltar and t >= T_SALTO and t < T_SALTO + DURACAO_SALTO
            if para_fora.length() < 25.0 and t < T_MERGULHO and not no_salto:
                _tempo_vida = T_MERGULHO   # mergulha em vez de atravessar o barco
    var rumo_atual: float = _nadando.angle()
    rumo_atual = lerp_angle(rumo_atual, _rumo_alvo, clampf(dt * 0.20, 0.0, 0.08))
    _nadando = Vector2.from_angle(rumo_atual)
    var pose: Vector4 = _pose(t)
    var avanco: float = _velocidade_nado * (1.0 + 1.4 * maxf(0.0, pose.w - 0.5))
    posicao.x += _nadando.x * avanco * dt
    posicao.z += _nadando.y * avanco * dt
    var altura_mar: float = _oceano.altura_em(posicao) if _oceano != null else 0.0
    posicao.y = altura_mar + pose.x * _escala
    # orientação: o bico (-Z do modelo) aponta para o rumo, inclinado pela arfagem; depois rola em torno do próprio eixo
    _rumo_visto = _rumo_visto.lerp(_nadando, clampf(dt * 1.8, 0.0, 0.25)).normalized()
    var horiz := Vector3(_rumo_visto.x, 0.0, _rumo_visto.y)
    var arf: float = pose.y + 0.025 * sin(t * 0.8)
    var frente: Vector3 = horiz * cos(arf) + Vector3.UP * sin(arf)
    var base := Basis.looking_at(frente, Vector3.UP if absf(arf) < 1.45 else horiz)
    base = base * Basis(Vector3.BACK, pose.z)
    _corpo.global_transform = Transform3D(base.scaled(Vector3.ONE * _escala), posicao)
    # nado: a fase anda mais rápido quando ela força (salto, subida)
    _fase += dt * lerpf(0.85, 2.6, pose.w)
    _fase_remada += dt * lerpf(0.6, 2.0, pose.w)
    _mat.set_shader_parameter("fase", _fase)
    _mat.set_shader_parameter("amplitude", lerpf(0.22, 0.65, pose.w))
    _mat.set_shader_parameter("remada", lerpf(0.25, 1.0, pose.w))
    _mat.set_shader_parameter("fase_remada", _fase_remada)

    if _vai_saltar and t >= T_SALTO:
        var u: float = (t - T_SALTO) / DURACAO_SALTO
        if _espirros_feitos == 0 and u >= 0.50:
            _espirros_feitos = 1
            _estourar(posicao, false)          # saindo da água
        elif _espirros_feitos == 1 and u >= 0.84:
            _espirros_feitos = 2
            _estourar(posicao + horiz * 3.0, true)   # caindo de lado
    if t >= _proximo_sopro and t < 39.0 and _sopros < 3:
        var no_salto2: bool = _vai_saltar and t >= T_SALTO - 2.0 and t < T_SALTO + DURACAO_SALTO + 2.0
        if not no_salto2:
            _emitir_sopro(posicao)
            _sopros += 1
        _proximo_sopro = t + randf_range(9.0, 13.0)
    if t >= VIDA:
        _ativo = false
        _corpo.visible = false
