extends SceneTree
# Profundidade do mar: vista rasante na costa e mar aberto
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
	c.look_at(alvo, Vector3.UP)
func _process(_d: float) -> bool:
	q += 1
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 12.0; jogo.clima.atualizar(); jogo.atualizar_interface()
		jogo.interface.esconder_hud = true
	var ic: Vector3 = jogo.ilha.centro
	var ponta: Vector3 = jogo.ilha.cais_ponta
	if q == 6: cam(ponta + Vector3(0, 40, 0) + (ponta - ic).normalized() * 160.0, ic + Vector3(0, 0, 0))
	if q == 12: foto("d_costa_alto")
	if q == 13: cam(Vector3(-200, 22, 100), Vector3(60, 0, -260))
	if q == 19: foto("d_aberto")
	if q == 20: cam(ponta + Vector3(0, 8, 0) + (ponta - ic).normalized() * 55.0, ponta + Vector3(0, 0, 0))
	if q == 26: foto("d_baia")
	if q == 27:
		S.apagar()
		return true
	return false
