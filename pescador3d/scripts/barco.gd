extends Node3D
## PE-3476: navegação arcade, com inércia, leme e balanço visual.
## O modelo GLB original veio com Z para cima e eixo longitudinal X.
## A cena o gira para Y-cima e proa voltada a -Z.

@export var velocidade_maxima: float = 5.7  # m/s ≈ 11 nós
@export var velocidade_re: float = 1.65
@export var aceleracao: float = 1.8
@export var desaceleracao: float = 1.05
@export var giro_maximo: float = 0.38  # radianos por segundo
@export var tanque: float = 60.0               # litros de diesel
@export var consumo_maximo: float = 0.085      # litros por segundo a todo o motor (60 L = ~12 min)
@export var consumo_parado: float = 0.004      # motor em marcha lenta
@export var velocidade_reserva: float = 1.0    # m/s (~2 nós) sem combustível: só o resto de embalo e a corrente

signal encalhou                                # bateu na costa ou no cais
signal combustivel_baixo                       # passou para menos de 20%
signal combustivel_acabou

var combustivel: float = 60.0
var _avisou_baixo: bool = false

var ativo: bool = false
var velocidade: float = 0.0
var distancia_percorrida: float = 0.0
var tempo_animacao: float = 0.0
var leme: float = 0.0

@onready var balanceio: Node3D = $Balanceio
@onready var oceano: Node = get_node_or_null("../Oceano")
@onready var respingo: CPUParticles3D = get_node_or_null("Respingo")

const MEIO_COMPRIMENTO: float = 3.2   # m do centro até onde se mede a onda na proa e na popa
const MEIA_BOCA: float = 1.2          # m do centro até cada bordo

var obstaculo: Node = null                     # quem sabe onde há terra (a ilha); precisa de bloqueado(pos)
var helice: Node3D
var pa_leme: Node3D

func _ready() -> void:
    _refinar_materiais(self)
    helice = find_child("Helice", true, false) as Node3D      # peças soltas do modelo
    pa_leme = find_child("Leme", true, false) as Node3D

## Acabamento da pintura do barco: textura nítida em ângulo rasante e um leve contorno de luz
## nas bordas, que ajuda o casco a se destacar da água.
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
        var mat: BaseMaterial3D = original.duplicate()
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        mat.roughness = 0.82
        mat.metallic_specular = 0.35
        mat.rim_enabled = true
        mat.rim = 0.12
        mat.rim_tint = 0.55
        malha.set_surface_override_material(i, mat)

func _physics_process(delta: float) -> void:
    tempo_animacao += delta
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
        var taxa: float = aceleracao if meta_velocidade != 0.0 else desaceleracao
        if Input.is_physical_key_pressed(KEY_SPACE):
            meta_velocidade = 0.0
            taxa = 4.2
        velocidade = move_toward(velocidade, meta_velocidade, taxa * delta)

        leme = 0.0
        if Input.is_physical_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
            leme += 1.0
        if Input.is_physical_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
            leme -= 1.0
        var fator_giro: float = clampf(absf(velocidade) / 2.3, 0.0, 1.0)
        rotate_y(leme * giro_maximo * fator_giro * delta * sign(velocidade))

        var frente: Vector3 = -global_transform.basis.z
        var movimento: Vector3 = frente * velocidade * delta
        # costa e cais: confere a ponta do barco que vai na frente; se não passa, o barco para e recua um pouco
        var ponta: Vector3 = global_position + movimento + frente * 4.2 * signf(velocidade)
        if obstaculo != null and velocidade != 0.0 and (obstaculo.bloqueado(ponta) or obstaculo.bloqueado(global_position + movimento)):
            if absf(velocidade) > 1.2:
                encalhou.emit()
            velocidade = -velocidade * 0.25
        else:
            global_position += movimento
            distancia_percorrida += movimento.length()
    else:
        velocidade = move_toward(velocidade, 0.0, desaceleracao * delta)
        leme = 0.0

    _seguir_ondas(delta)
    if helice != null:                                        # a hélice gira com o motor
        helice.rotate_object_local(Vector3.BACK, velocidade / velocidade_maxima * 28.0 * delta)
    if pa_leme != null:                                       # a pá do leme acompanha o comando
        pa_leme.rotation.y = lerp_angle(pa_leme.rotation.y, deg_to_rad(-leme * 32.0), 1.0 - exp(-8.0 * delta))
    if respingo != null:
        respingo.emitting = ativo and velocidade > 2.4

## O casco sobe, desce e inclina com a água embaixo dele: mede a onda no centro, na proa, na popa
## e nos dois bordos (a mesma função do shader do mar). Não é hidrodinâmica, mas o barco deixa de
## balançar "no ar" enquanto a onda passa por baixo.
func _seguir_ondas(delta: float) -> void:
    var altura: float = 0.0
    var arfagem: float = 0.0
    var adernar: float = 0.0
    if oceano != null and oceano.has_method("altura_em"):
        var frente: Vector3 = -global_transform.basis.z
        var lado: Vector3 = global_transform.basis.x
        var centro: float = oceano.altura_em(global_position)
        var proa: float = oceano.altura_em(global_position + frente * MEIO_COMPRIMENTO)
        var popa: float = oceano.altura_em(global_position - frente * MEIO_COMPRIMENTO)
        var boreste: float = oceano.altura_em(global_position + lado * MEIA_BOCA)
        var bombordo: float = oceano.altura_em(global_position - lado * MEIA_BOCA)
        altura = (centro * 2.0 + proa + popa + boreste + bombordo) / 6.0
        arfagem = atan2(proa - popa, MEIO_COMPRIMENTO * 2.0)
        adernar = atan2(boreste - bombordo, MEIA_BOCA * 2.0)
    else:
        altura = sin(tempo_animacao * 1.22) * 0.095
    var fracao: float = clampf(absf(velocidade) / velocidade_maxima, 0.0, 1.0)
    arfagem += deg_to_rad(2.2) * fracao * signf(velocidade)               # a proa levanta ao acelerar
    arfagem += deg_to_rad(sin(tempo_animacao * 1.28 + 0.32) * 0.45)       # vida própria, bem leve
    adernar += deg_to_rad(sin(tempo_animacao * 0.93) * 0.7 + leme * minf(absf(velocidade), 4.0) * 0.55)
    var suave: float = 1.0 - exp(-5.0 * delta)                           # o casco tem peso: não acompanha no ato
    balanceio.position.y = lerpf(balanceio.position.y, altura, suave)
    balanceio.rotation.x = lerp_angle(balanceio.rotation.x, arfagem, suave)
    balanceio.rotation.z = lerp_angle(balanceio.rotation.z, adernar, suave)

func nos() -> float:
    return abs(velocidade) * 1.943844

func rumo() -> int:
    # 0° aponta para o norte (-Z), como em cartas de navegação.
    return posmod(int(round(-rad_to_deg(rotation.y))), 360)

func zerar() -> void:
    combustivel = tanque
    _avisou_baixo = false
    ativo = false
    velocidade = 0.0
    distancia_percorrida = 0.0
    leme = 0.0
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
