extends Node3D
## Estrela d'Alva (antes PE-3476): navegação com inércia lateral, resposta ao swell e amortecimento do casco.
## O modelo GLB original veio com Z para cima e eixo longitudinal X.
## A cena o gira para Y-cima e proa voltada a -Z.

@export var velocidade_maxima: float = 5.7  # m/s ≈ 11 nós
@export var velocidade_re: float = 1.65
@export var aceleracao: float = 1.15
@export var desaceleracao: float = 0.90
@export var giro_maximo: float = 0.38  # radianos por segundo
@export var estabilidade: float = 1.0     # 1.0 original; diminui com estabilizadores
@export var tanque: float = 60.0               # litros de diesel
@export var consumo_maximo: float = 0.085      # litros por segundo a todo o motor (60 L = ~12 min)
@export var consumo_parado: float = 0.004      # motor em marcha lenta
@export var velocidade_reserva: float = 1.0    # m/s (~2 nós) sem combustível: só o resto de embalo e a corrente

signal encalhou                                # bateu na costa ou no cais
signal bateu_em_barco(intensidade: float)      # outro barco bateu no seu (0..1)
signal combustivel_baixo                       # passou para menos de 20%
signal combustivel_acabou
const VELOCIDADE_PORTO: float = 2.57          # m/s = 5 nós: o mínimo que o raso do porto deixa andar
signal casco_avariado(perda: float, motivo: String)   # motivo: "tempestade", "costa" ou "barco"; perda em pontos de 0..100

## Saúde do casco (0 a 100). Tempestade desgasta devagar; batidas na costa e em outros barcos tiram mais.
## Abaixo de 50 o barco perde força; em 0 ele faz água e só se arrasta, até ser consertado no cais.
const DANO_TEMPESTADE := 0.085         # pontos por segundo no auge do temporal em mar aberto (2 min de temporal: ~6 perto das ilhas, ~10 longe)
var saude: float = 100.0
var _dano_acumulado: float = 0.0

var combustivel: float = 60.0
var _avisou_baixo: bool = false
var _recarga_batida: float = 0.0

var ativo: bool = false
var velocidade: float = 0.0
var distancia_percorrida: float = 0.0
var tempo_animacao: float = 0.0
var leme: float = 0.0
var _giro_atual: float = 0.0
var _velocidade_vertical: float = 0.0
var _velocidade_arfagem: float = 0.0
var _velocidade_adernamento: float = 0.0
var _ultimo_nivel_onda: float = 0.0
var _deriva_lateral: float = 0.0
var _impacto_proa: float = 0.0
var _acelerador_suave: float = 0.0
var impacto_proa: float = 0.0 # 0..1; usado na espuma da proa e nos respingos

@onready var balanceio: Node3D = $Balanceio
@onready var oceano: Node = get_node_or_null("../Oceano")
@onready var respingo: CPUParticles3D = get_node_or_null("Respingo")
var _respingo_boreste: CPUParticles3D
var _respingo_bombordo: CPUParticles3D

const MEIO_COMPRIMENTO: float = 3.2   # m do centro até onde se mede a onda na proa e na popa
const MEIA_BOCA: float = 1.2          # m do centro até cada bordo

var obstaculo: Node = null                     # quem sabe onde há terra (a ilha); precisa de bloqueado(pos)
var helice: Node3D
var pa_leme: Node3D

func _ready() -> void:
    _refinar_materiais(self)
    helice = find_child("Helice", true, false) as Node3D      # peças soltas do modelo
    pa_leme = find_child("Leme", true, false) as Node3D
    if respingo != null:
        # As emissões nascem na altura e inclinação efetivas do casco, não no pivô de navegação.
        respingo.reparent(balanceio, false)
        # Espuma separada nos bordos: acompanha o balanço da proa e não fica presa no centro.
        _respingo_boreste = _criar_respingos_bordo("RespingoBoreste", 1.0)
        _respingo_bombordo = _criar_respingos_bordo("RespingoBombordo", -1.0)

func _criar_respingos_bordo(nome: String, sinal: float) -> CPUParticles3D:
    var efeito := respingo.duplicate() as CPUParticles3D
    efeito.name = nome
    efeito.position = Vector3(sinal * 1.0, 0.0, -3.1)
    efeito.amount = 24
    efeito.lifetime = 0.55
    efeito.emitting = false
    efeito.emission_box_extents = Vector3(0.22, 0.07, 0.65)
    efeito.direction = Vector3(sinal * 0.9, 0.65, 0.22).normalized()
    efeito.spread = 28.0
    efeito.initial_velocity_min = 0.95
    efeito.initial_velocity_max = 2.7
    balanceio.add_child(efeito)
    return efeito

## v0.5.7: o barco do jogador é um pesqueiro USADO. As peças com textura ganham shaders/barco_usado.gdshader por cima da
## pintura do modelo (desbotado, lascas, ferrugem escorrendo, limo na linha d'água, sal). Vidro, luzes e bandeira ficam
## como estão (só o vidro escurece um pouco). A placa de nome vira "Estrela d'Alva".
const SHADER_USADO := preload("res://shaders/barco_usado.gdshader")
const PLACA_NOME := "res://assets/barco/estrela_dalva_nome.png"
const TIPO_DESGASTE := {
    "casco_vermelho": 0, "casco_branco": 0, "pintura_azul": 0, "pintura_creme": 0, "pintura_laranja": 0, "pintura_amarela": 0,
    "pintura_vermelha": 0, "madeira_escura": 1, "conves": 1, "metal": 2, "preto": 2, "corda": 3, "rede": 3, "lona": 3,
    "plastico_branco": 4, "plastico_azul": 4, "boia_laranja": 4}
@export var desgaste: float = 1.0          # 0 = barco novo, 1 = usado

func _refinar_materiais(no: Node) -> void:
    for filho in no.get_children():
        _refinar_materiais(filho)
    var malha := no as MeshInstance3D
    if malha == null or malha.mesh == null:
        return
    for i in malha.mesh.get_surface_count():
        var original := malha.mesh.surface_get_material(i) as BaseMaterial3D
        if original == null:
            continue
        var nome: String = original.resource_name
        if TIPO_DESGASTE.has(nome) and desgaste > 0.0:
            var sm := ShaderMaterial.new()
            sm.shader = SHADER_USADO
            sm.set_shader_parameter("cor", original.albedo_color)
            sm.set_shader_parameter("tem_textura", original.albedo_texture != null)
            if original.albedo_texture != null:
                sm.set_shader_parameter("tex_albedo", original.albedo_texture)
            sm.set_shader_parameter("tem_normal", original.normal_enabled and original.normal_texture != null)
            if original.normal_texture != null:
                sm.set_shader_parameter("tex_normal", original.normal_texture)
            sm.set_shader_parameter("tipo", float(TIPO_DESGASTE[nome]))
            sm.set_shader_parameter("desgaste", desgaste)
            sm.set_shader_parameter("semente", float(i) * 1.37)
            malha.set_surface_override_material(i, sm)
            continue
        var mat: BaseMaterial3D = original.duplicate()
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        mat.roughness = 0.96                       # tinta fosca, como pintura
        mat.metallic_specular = 0.12
        mat.normal_scale = 0.6
        mat.rim_enabled = true
        mat.rim = 0.12
        mat.rim_tint = 0.55
        if nome == "matricula" and ResourceLoader.exists(PLACA_NOME):
            mat.albedo_texture = load(PLACA_NOME)
        elif nome == "vidro":
            mat.albedo_color = mat.albedo_color.darkened(0.25 * desgaste)      # vidro encardido de sal
            mat.roughness = 0.6
        malha.set_surface_override_material(i, mat)

func _physics_process(delta: float) -> void:
    tempo_animacao += delta
    _recarga_batida = maxf(0.0, _recarga_batida - delta)
    if ativo:
        var acelerador: float = Input.get_action_strength("ui_up")
        var re: float = Input.get_action_strength("ui_down")
        # Teclas físicas são independentes do layout do teclado (W/S).
        if Input.is_physical_key_pressed(KEY_W):
            acelerador = 1.0
        if Input.is_physical_key_pressed(KEY_S):
            re = 1.0

        var meta_velocidade: float = 0.0
        if acelerador > 0.0:
            meta_velocidade = velocidade_maxima
        elif re > 0.0:
            meta_velocidade = -velocidade_re
        # combustível: gasta conforme o motor trabalha; vazio, o barco só se arrasta
        var esforco: float = absf(meta_velocidade) / velocidade_maxima
        if combustivel > 0.0:
            combustivel = maxf(0.0, combustivel - (consumo_parado + consumo_maximo * pow(esforco, 1.4)) * delta)
            if combustivel <= 0.0:
                combustivel_acabou.emit()
            elif not _avisou_baixo and combustivel < tanque * 0.2:
                _avisou_baixo = true
                combustivel_baixo.emit()
        else:
            meta_velocidade = clampf(meta_velocidade, -velocidade_reserva * 0.6, velocidade_reserva)
        # casco avariado: perde força abaixo de 50; arrombado (0), só se arrasta
        if saude <= 0.0:
            meta_velocidade = clampf(meta_velocidade, -velocidade_reserva * 0.6, velocidade_reserva)
        else:
            meta_velocidade *= fator_avaria()
        # tempestade: as ondas castigam o casco aos poucos (menos com estabilizadores e em águas abrigadas)
        if oceano != null and float(oceano.tempestade_nivel) > 0.05:
            var exposto: float = lerpf(0.45, 1.0, clampf(oceano.intensidade_em(global_position) / 0.6, 0.0, 1.0))
            _dano_acumulado += DANO_TEMPESTADE * pow(float(oceano.tempestade_nivel), 1.5) * exposto * lerpf(1.0, estabilidade, 0.7) * delta
            if _dano_acumulado >= 1.0:
                danificar(_dano_acumulado, "tempestade")
                _dano_acumulado = 0.0
        # Aproximação de recifes e praias reduz a velocidade admissível para evitar encalhe.
        if obstaculo != null and obstaculo.has_method("altura_terra"):
            var fundo: float = float(obstaculo.altura_terra(global_position))
            var profundidade_atual: float = maxf(0.0, -fundo)
            if profundidade_atual < 5.0 and meta_velocidade > 0.0:
                # v0.5.8: no raso do porto (depois da boia) o barco ainda anda a 5 nós; antes caía para ~3
                var teto: float = lerpf(VELOCIDADE_PORTO, velocidade_maxima, clampf(inverse_lerp(0.9, 5.0, profundidade_atual), 0.0, 1.0))
                meta_velocidade = minf(meta_velocidade, teto)
        var taxa: float = aceleracao if meta_velocidade != 0.0 else desaceleracao
        if Input.is_physical_key_pressed(KEY_SPACE):
            meta_velocidade = 0.0
            taxa = 4.2
        # Um motor diesel ganha torque progressivamente. Evita que o barco
        # salte de 0 para 12-14 nós em poucos segundos após a partida.
        var comando_motor: float = 1.0 if (acelerador > 0.0 or re > 0.0) else 0.0
        _acelerador_suave = move_toward(_acelerador_suave, comando_motor, (0.85 if comando_motor > 0.0 else 1.8) * delta)
        if meta_velocidade != 0.0 and not Input.is_physical_key_pressed(KEY_SPACE):
            taxa *= lerpf(0.35, 1.0, _acelerador_suave)
        # A água impõe resistência gradativa (maior com mar de proa/agitado).
        var resistencia_mar: float = 0.0
        if oceano != null and oceano.has_method("intensidade_em"):
            resistencia_mar = oceano.intensidade_em(global_position)
        # Velejar contra as ondas consome parte do impulso de avanço; com mar de popa, menos.
        if oceano != null and meta_velocidade > 0.0:
            var rumo_proa: Vector3 = -global_transform.basis.z
            var contra_mar: float = maxf(0.0, -Vector2(rumo_proa.x, rumo_proa.z).dot(oceano.direcao_vento))
            meta_velocidade *= 1.0 - 0.11 * contra_mar * resistencia_mar
        velocidade = move_toward(velocidade, meta_velocidade, taxa * delta * (1.0 - resistencia_mar * 0.18))
        velocidade *= exp(-0.018 * resistencia_mar * delta)

        leme = 0.0
        if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
            leme += 1.0
        if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
            leme -= 1.0
        var fator_giro: float = clampf(absf(velocidade) / 2.3, 0.0, 1.0)
        var giro_desejado: float = leme * giro_maximo * fator_giro * signf(velocidade)
        _giro_atual = lerpf(_giro_atual, giro_desejado, 1.0 - exp(-2.9 * delta))
        rotate_y(_giro_atual * delta)

        var frente: Vector3 = -global_transform.basis.z
        var direita: Vector3 = global_transform.basis.x
        # A água não permite mudanças instantâneas de rumo. A popa escorrega suavemente
        # em curvas fechadas e o vento produz uma deriva lateral limitada.
        var vento_lateral: float = 0.0
        if oceano != null and oceano.has_method("intensidade_em"):
            vento_lateral = oceano.direcao_vento.dot(Vector2(direita.x, direita.z)) * resistencia_mar
        var alvo_deriva: float = clampf(-_giro_atual * velocidade * 0.37 + vento_lateral * 0.17, -0.95, 0.95)
        _deriva_lateral = lerpf(_deriva_lateral, alvo_deriva, 1.0 - exp(-1.55 * delta))
        var movimento: Vector3 = (frente * velocidade + direita * _deriva_lateral) * delta
        # Uma corrente fraca desloca o casco mesmo sem motor; a colisao com a costa
        # tambem e checada quando a corrente e a unica fonte de movimento.
        if oceano != null and oceano.has_method("corrente_em"):
            movimento += oceano.corrente_em(global_position) * delta
        # Colisão com quatro extremidades do casco, não só com a proa.
        # A posição já encalhada pode ser abandonada de ré: só impedimos novos contatos.
        var bloqueou: bool = false
        var proximo: Vector3 = global_position + movimento
        if obstaculo != null and movimento.length_squared() > 0.00000001:
            for offset in [Vector3.ZERO, frente * 3.6 + direita * 1.1,
                    frente * 3.6 - direita * 1.1, -frente * 2.8 + direita * 1.1,
                    -frente * 2.8 - direita * 1.1]:
                var atual: Vector3 = global_position + offset
                var candidato: Vector3 = proximo + offset
                if obstaculo.bloqueado(candidato) and not obstaculo.bloqueado(atual):
                    bloqueou = true
                    break
        if bloqueou:
            if absf(velocidade) > 1.2:
                danificar(2.0 + 6.0 * clampf((absf(velocidade) - 1.2) / 4.5, 0.0, 1.0), "costa")
                encalhou.emit()
            # Para o avanço mas não projeta a embarcação para dentro da margem.
            velocidade *= -0.08
            _deriva_lateral *= 0.15
        else:
            global_position = proximo
            distancia_percorrida += movimento.length()
    else:
        velocidade = move_toward(velocidade, 0.0, desaceleracao * delta)
        leme = 0.0
        _giro_atual = lerpf(_giro_atual, 0.0, 1.0 - exp(-4.0 * delta))
        _deriva_lateral = lerpf(_deriva_lateral, 0.0, 1.0 - exp(-3.0 * delta))
        _acelerador_suave = move_toward(_acelerador_suave, 0.0, delta * 1.8)

    _seguir_ondas(delta)
    if helice != null:                                        # a hélice gira com o motor
        helice.rotate_object_local(Vector3.BACK, velocidade / velocidade_maxima * 28.0 * delta)
    if pa_leme != null:                                       # a pá do leme acompanha o comando
        pa_leme.rotation.y = lerp_angle(pa_leme.rotation.y, deg_to_rad(-leme * 32.0), 1.0 - exp(-8.0 * delta))
    if respingo != null:
        var fracao_motor: float = clampf(absf(velocidade) / maxf(velocidade_maxima, 0.1), 0.0, 1.0)
        var borrifo: bool = ativo and velocidade > 1.60 and (fracao_motor > 0.38 or impacto_proa > 0.50)
        respingo.emitting = borrifo
        respingo.initial_velocity_max = lerpf(2.0, 3.25, impacto_proa)
        if _respingo_boreste != null:
            _respingo_boreste.emitting = borrifo and (impacto_proa > 0.17 or fracao_motor > 0.51)
        if _respingo_bombordo != null:
            _respingo_bombordo.emitting = borrifo and (impacto_proa > 0.17 or fracao_motor > 0.51)

## O casco sobe, desce e inclina com a água embaixo dele: mede a onda no centro, na proa, na popa
## e nos dois bordos (a mesma função do shader do mar). Não é hidrodinâmica, mas o barco deixa de
## balançar "no ar" enquanto a onda passa por baixo.
func _seguir_ondas(delta: float) -> void:
    var altura_alvo: float = 0.0
    var arfagem_alvo: float = 0.0
    var adernar_alvo: float = 0.0
    var intensidade_mar: float = 0.0
    if oceano != null and oceano.has_method("altura_em"):
        var frente: Vector3 = -global_transform.basis.z
        var lado: Vector3 = global_transform.basis.x
        # 9 pontos de amostragem produzem sustentação mais estável em ondas cruzadas.
        var centro: float = oceano.altura_em(global_position)
        var proa: float = oceano.altura_em(global_position + frente * MEIO_COMPRIMENTO)
        var popa: float = oceano.altura_em(global_position - frente * MEIO_COMPRIMENTO)
        var boreste: float = oceano.altura_em(global_position + lado * MEIA_BOCA)
        var bombordo: float = oceano.altura_em(global_position - lado * MEIA_BOCA)
        var lateral_proa: float = oceano.altura_em(global_position + frente * MEIO_COMPRIMENTO * 0.65 + lado * MEIA_BOCA)
        var lateral_popa: float = oceano.altura_em(global_position - frente * MEIO_COMPRIMENTO * 0.65 + lado * MEIA_BOCA)
        var outra_proa: float = oceano.altura_em(global_position + frente * MEIO_COMPRIMENTO * 0.65 - lado * MEIA_BOCA)
        var outra_popa: float = oceano.altura_em(global_position - frente * MEIO_COMPRIMENTO * 0.65 - lado * MEIA_BOCA)
        # Sustentação do casco. Durante uma crista alta, o barco deve acompanhar
        # a onda dos bordos/proa e não ficar submerso por atraso da mola.
        var media_apoios: float = (centro * 3.0 + proa + popa + boreste + bombordo + lateral_proa + lateral_popa + outra_proa + outra_popa) / 11.0
        var maior_apoio: float = maxf(centro, maxf(proa, maxf(popa, maxf(boreste, maxf(bombordo, maxf(lateral_proa, maxf(lateral_popa, maxf(outra_proa, outra_popa))))))))
        altura_alvo = media_apoios + 0.43 * maxf(0.0, maior_apoio - media_apoios)
        arfagem_alvo = atan2(proa - popa, MEIO_COMPRIMENTO * 2.0)
        adernar_alvo = atan2(boreste - bombordo, MEIA_BOCA * 2.0)
        # Comparação entre velocidade de subida da onda e a do casco: impacto na proa.
        # A espuma pode crescer sem fazer o barco saltar de forma artificial.
        if oceano.has_method("velocidade_vertical_em"):
            var onda_subindo: float = oceano.velocidade_vertical_em(global_position + frente * MEIO_COMPRIMENTO)
            var encontro: float = absf(onda_subindo - _velocidade_vertical)
            _impacto_proa = clampf((encontro - 0.15) * 0.44 + maxf(velocidade, 0.0) * 0.034, 0.0, 1.0)
        if oceano.has_method("intensidade_em"):
            intensidade_mar = oceano.intensidade_em(global_position)
        else:
            intensidade_mar = oceano.intensidade()
        # Vento lateral forma banda de deriva; efeito visual suavizado pela estabilidade.
        var vento_mundo: Vector2 = oceano.direcao_vento
        adernar_alvo += deg_to_rad(2.5) * intensidade_mar * vento_mundo.dot(Vector2(lado.x, lado.z))
    else:
        altura_alvo = sin(tempo_animacao * 1.22) * 0.09
        _impacto_proa = 0.0
    impacto_proa = lerpf(impacto_proa, _impacto_proa, 1.0 - exp(-3.7 * delta))
    var fracao: float = clampf(absf(velocidade) / maxf(velocidade_maxima, 0.1), 0.0, 1.0)
    arfagem_alvo += deg_to_rad(1.6) * fracao * signf(velocidade)
    adernar_alvo += deg_to_rad(leme * minf(absf(velocidade), 5.0) * 0.65)
    adernar_alvo += deg_to_rad(clampf(_deriva_lateral * 1.8, -1.5, 1.5))
    arfagem_alvo = clampf(arfagem_alvo * estabilidade, deg_to_rad(-13.0), deg_to_rad(13.0))
    adernar_alvo = clampf(adernar_alvo * estabilidade, deg_to_rad(-17.0), deg_to_rad(17.0))
    # Flutuabilidade criticamente amortecida. A mola anterior era lenta demais:
    # num temporal, a onda subia vários metros antes de o casco reagir.
    # Frequência um pouco maior quando o mar sobe em direção à proa.
    var frequencia: float = lerpf(4.6, 5.9, intensidade_mar)
    var sobe: bool = altura_alvo > balanceio.position.y
    if sobe:
        frequencia *= 1.14
    var erro_vertical: float = altura_alvo - balanceio.position.y
    var aceleracao_vertical: float = frequencia * frequencia * erro_vertical - 2.0 * frequencia * _velocidade_vertical
    _velocidade_vertical += aceleracao_vertical * delta
    _velocidade_vertical = clampf(_velocidade_vertical, -5.5, 7.5)
    balanceio.position.y += _velocidade_vertical * delta
    # Reserva de flutuabilidade nas cristas; mantém um mínimo de borda livre.
    # Não afeta a física horizontal nem a posição do ponto de navegação.
    if oceano != null and oceano.has_method("altura_em"):
        var nivel_agua: float = oceano.altura_em(global_position)
        var limite: float = nivel_agua - lerpf(0.42, 0.30, intensidade_mar)
        if balanceio.position.y < limite:
            balanceio.position.y = lerpf(balanceio.position.y, limite, 1.0 - exp(-10.0 * delta))
            _velocidade_vertical = maxf(_velocidade_vertical, 0.0)
    var mola_angular: float = lerpf(13.0, 9.0, intensidade_mar)
    var amortecimento_angular: float = lerpf(5.8, 4.5, intensidade_mar)
    _velocidade_arfagem += wrapf(arfagem_alvo - balanceio.rotation.x, -PI, PI) * mola_angular * delta
    _velocidade_arfagem *= exp(-amortecimento_angular * delta)
    _velocidade_adernamento += wrapf(adernar_alvo - balanceio.rotation.z, -PI, PI) * mola_angular * delta
    _velocidade_adernamento *= exp(-amortecimento_angular * delta)
    balanceio.rotation.x += _velocidade_arfagem * delta
    balanceio.rotation.z += _velocidade_adernamento * delta
    balanceio.rotation.x = clampf(balanceio.rotation.x, deg_to_rad(-15.0), deg_to_rad(15.0))
    balanceio.rotation.z = clampf(balanceio.rotation.z, deg_to_rad(-19.0), deg_to_rad(19.0))
    _ultimo_nivel_onda = altura_alvo


## Velocidade no mundo (m/s): proa + deriva lateral. É o que os barcos NPC usam para prever a aproximação.
func velocidade_mundo() -> Vector3:
    return -global_transform.basis.z * velocidade + global_transform.basis.x * _deriva_lateral

## Outro barco bateu: a variação de velocidade dv (m/s, no plano) aplicada no ponto de contato (mundo) muda sua
## marcha, sua deriva e o giro (pelo braço do impulso), e o casco adernará com o tranco.
func receber_batida(dv: Vector3, ponto: Vector3, intensidade: float) -> void:
    var frente: Vector3 = -global_transform.basis.z
    var direita: Vector3 = global_transform.basis.x
    velocidade += dv.dot(frente)
    _deriva_lateral = clampf(_deriva_lateral + dv.dot(direita), -2.2, 2.2)
    var braco: Vector3 = ponto - global_position
    var torque: float = braco.z * dv.x - braco.x * dv.z          # componente Y de braço x impulso
    _giro_atual = clampf(_giro_atual + torque / 6.0, -0.9, 0.9)
    _velocidade_adernamento += dv.dot(direita) * 0.30
    _velocidade_arfagem += dv.dot(frente) * 0.08
    if intensidade > 0.12 and _recarga_batida <= 0.0:
        _recarga_batida = 0.6
        danificar(1.5 + 7.0 * clampf(intensidade, 0.0, 1.0), "barco")
        bateu_em_barco.emit(intensidade)

## Correção de posição da batida (separação dos cascos); não deixa a batida empurrar o barco para a terra.
func afastar(corrigir: Vector3) -> void:
    corrigir.y = 0.0
    if obstaculo != null:
        for offset in [Vector3.ZERO, -global_transform.basis.z * 3.6, global_transform.basis.z * 2.8]:
            if obstaculo.bloqueado(global_position + corrigir + offset):
                return
    global_position += corrigir

func nos() -> float:
    return abs(velocidade) * 1.943844

func rumo() -> int:
    # 0° aponta para o norte (-Z), como em cartas de navegação.
    return posmod(int(round(-rad_to_deg(rotation.y))), 360)

## Tira pontos do casco (0..100).
func danificar(perda: float, motivo: String) -> void:
    if perda <= 0.0 or saude <= 0.0:
        return
    var antes := saude
    saude = maxf(0.0, saude - perda)
    casco_avariado.emit(antes - saude, motivo)

## Conserta até "pontos"; devolve quantos entraram.
func consertar(pontos: float) -> float:
    var entra: float = clampf(pontos, 0.0, 100.0 - saude)
    saude += entra
    return entra

## Força que sobra no motor: 100% até metade da saúde, caindo para 60% perto de zero.
func fator_avaria() -> float:
    return 1.0 if saude >= 50.0 else lerpf(0.6, 1.0, saude / 50.0)

func zerar() -> void:
    saude = 100.0
    _dano_acumulado = 0.0
    combustivel = tanque
    _avisou_baixo = false
    ativo = false
    velocidade = 0.0
    distancia_percorrida = 0.0
    leme = 0.0
    _giro_atual = 0.0
    _acelerador_suave = 0.0
    _velocidade_vertical = 0.0
    _deriva_lateral = 0.0
    _impacto_proa = 0.0
    impacto_proa = 0.0
    _velocidade_arfagem = 0.0
    _velocidade_adernamento = 0.0
    tempo_animacao = 0.0
    global_position = Vector3.ZERO
    rotation = Vector3.ZERO
    balanceio.position = Vector3.ZERO
    balanceio.rotation = Vector3.ZERO


## Põe combustível no tanque; devolve quantos litros entraram.
func abastecer(litros: float) -> float:
    var entra: float = clampf(litros, 0.0, tanque - combustivel)
    combustivel += entra
    if combustivel >= tanque * 0.2:
        _avisou_baixo = false
    return entra
