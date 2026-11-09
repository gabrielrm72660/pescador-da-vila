extends CharacterBody2D
## Pesqueiro a motor e vela (spec 10). As regras ficam em logica/navegacao.gd; aqui só se aplica a entrada
## e se move o corpo. Configurado por propriedades (o Mundo lê o Estado e preenche), para funcionar nos testes.

const Navegacao = preload("res://logica/navegacao.gd")

signal combustivel_mudou(valor: float)

@export var nivel_motor := 1
@export var vela_grande := false
@export var leme_melhorado := false
@export var tanque := 100.0
@export var combustivel := 100.0
@export var nivel_motorista := 0

var marcha := Navegacao.MARCHA_PARADO
var vela_aberta := false
var vel := 0.0
var atracado := false

## Preenchidos pelo Mundo a cada quadro; padrões servem para rodar o barco sozinho.
var vento_ang := 0.0
var forca_vento := 1.0
var corrente_ang := 0.0


func passo(dt: float, entrada: Dictionary, p_vento_ang: float, p_forca_vento: float, p_corrente_ang: float) -> void:
	if entrada.get("vela", false):
		vela_aberta = not vela_aberta
	if atracado:
		vel = 0.0
		velocity = Vector2.ZERO
		_visual()
		return
	if entrada.get("subir", false):
		marcha = mini(marcha + 1, Navegacao.MARCHAS.size() - 1)
	if entrada.get("descer", false):
		marcha = maxi(marcha - 1, 0)
	rotation += float(entrada.get("virar", 0.0)) * Navegacao.taxa_giro(leme_melhorado) * dt
	var alvo := Navegacao.velocidade_alvo(marcha, nivel_motor, combustivel > 0.0, vela_aberta, vela_grande,
			p_forca_vento, rotation, p_vento_ang)
	vel = Navegacao.acelerar(vel, alvo, dt)
	if combustivel > 0.0:
		var gasto := Navegacao.consumo(marcha, dt, nivel_motorista)
		if gasto > 0.0:
			combustivel = maxf(0.0, combustivel - gasto)
			combustivel_mudou.emit(combustivel)
	velocity = Vector2.from_angle(rotation) * vel + Navegacao.deriva(p_corrente_ang, p_vento_ang, p_forca_vento)
	_visual()


func _physics_process(dt: float) -> void:
	var entrada := {
		"subir": Input.is_action_just_pressed("motor_subir"),
		"descer": Input.is_action_just_pressed("motor_descer"),
		"virar": Input.get_axis("virar_esq", "virar_dir"),
		"vela": Input.is_action_just_pressed("vela"),
	}
	passo(dt, entrada, vento_ang, forca_vento, corrente_ang)
	move_and_slide()
	# bateu de frente na costa: perde o embalo em vez de empurrar a ilha para sempre
	if get_slide_collision_count() > 0:
		vel *= 0.6


func _visual() -> void:
	var vela_no := get_node_or_null("Vela")
	if vela_no:
		vela_no.visible = vela_aberta
		vela_no.global_rotation = vento_ang
	var esteira := get_node_or_null("Esteira")
	if esteira:
		esteira.emitting = absf(vel) > 20.0
