extends SceneTree
# Boias de sinalizacao e barcos NPC: dia (do barco, de cima) e noite
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
		jogo.clima.hora = 11.0; jogo.clima.atualizar(); jogo.atualizar_interface()
		jogo.interface.esconder_hud = true
		for b in jogo.boias._boias:
			print("boia ", b.tipo, " ", b.no.global_position, " fundo=", jogo.ilha.altura_em(b.no.global_position))
		for b in jogo.vida_portuaria._barcos:
			print("npc ", b.no.global_position, " raio=", b.raio)
	if q == 6:
		var bs: Array = jogo.boias._boias
		var p0: Vector3 = bs[0].no.global_position
		var p1: Vector3 = bs[1].no.global_position
		var meio := (p0 + p1) * 0.5
		var f: Vector3 = (jogo.barco.global_position - meio); f.y = 0
		f = f.normalized()
		cam(meio + f * 55.0 + Vector3(0, 7, 0), meio + Vector3(0, 3, 0))
	if q == 12: foto("b_portao_dia")
	if q == 13:
		var b: Vector3 = jogo.vida_portuaria._barcos[0].no.global_position
		cam(b + Vector3(18, 7, 18), b + Vector3(0, 1.5, 0))
	if q == 19: foto("b_npc1")
	if q == 20:
		var b: Vector3 = jogo.vida_portuaria._barcos[1].no.global_position
		cam(b + Vector3(-14, 5, -16), b + Vector3(0, 1.5, 0))
	if q == 26: foto("b_npc2")
	if q == 27:
		jogo.clima.hora = 22.0; jogo.clima.atualizar(); jogo.atualizar_interface()
		var bs: Array = jogo.boias._boias
		var p0: Vector3 = bs[0].no.global_position
		var f: Vector3 = (jogo.barco.global_position - p0); f.y = 0
		f = f.normalized()
		cam(p0 + f * 60.0 + Vector3(0, 6, 0), p0 + Vector3(0, 3, 0))
	if q == 36: foto("b_noite_a")
	if q == 44: foto("b_noite_b")
	if q == 45:
		var c: Camera3D = jogo.get_node("Camera")
		c.set_process(true); c.set_physics_process(true)
		jogo.clima.hora = 12.0; jogo.clima.atualizar(); jogo.atualizar_interface()
		jogo.interface.esconder_hud = false
	if q == 56: foto("b_jogo_hud")
	if q == 57:
		S.apagar()
		return true
	return false
