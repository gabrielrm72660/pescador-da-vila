extends SceneTree
# Fotos do mar: emendas do clipmap em calmaria e em temporal, em Alta e Baixa
var jogo
var q := 0
const S = preload("res://scripts/salvamento.gd")
func _initialize() -> void:
	S.apagar()
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func foto(n) -> void:
	root.get_texture().get_image().save_png("res://_%s.png" % n)
func cam(pos: Vector3, alvo: Vector3) -> void:
	var c: Camera3D = jogo.get_node("Camera")
	c.set_process(false); c.set_physics_process(false)
	c.global_position = pos
	c.look_at(alvo)
func _process(_d: float) -> bool:
	q += 1
	var b: Vector3 = jogo.barco.global_position
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 15.5; jogo.clima.atualizar()
		jogo.interface.esconder_hud = true
		jogo.graficos.qualidade = 2; jogo.graficos.aplicar()
		jogo.oceano.agitacao = 0.9
	if q == 6: cam(b + Vector3(0, 45, 40), b + Vector3(0, 0, -200))
	if q == 10: foto("m_alta_alto")
	if q == 11: cam(b + Vector3(0, 6, 22), b + Vector3(0, 1, 0))
	if q == 15: foto("m_alta_barco")
	if q == 16:
		jogo.graficos.qualidade = 0; jogo.graficos.aplicar()
		cam(b + Vector3(0, 45, 40), b + Vector3(0, 0, -200))
	if q == 21: foto("m_baixa_alto")
	if q == 22:
		jogo.graficos.qualidade = 1; jogo.graficos.aplicar()
		jogo.oceano.testar_tempestade()
		cam(b + Vector3(0, 30, 30), b + Vector3(0, 0, -150))
	if q == 30: foto("m_media_temporal")
	if q == 31:
		S.apagar()
		return true
	return false
