extends SceneTree
# Cais novo, barco na partida, trilhas e calçada
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
	var ilha = jogo.ilha
	var dir: Vector3 = (ilha.cais_ponta - ilha.cais_inicio).normalized()
	var lado := Vector3(-dir.z, 0, dir.x)
	var b: Vector3 = jogo.barco.global_position
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 15.5; jogo.clima.atualizar()
		jogo.interface.esconder_hud = true
		print("BARCO ", b, " giro=", snapped(jogo.barco.rotation.y, 0.01), " fundo=", snapped(ilha.altura_em(b), 0.1), " dist_cais=", snapped(ilha.distancia_do_cais(b), 0.1), " pode_atracar=", jogo.pode_atracar(), " cardumes=", jogo.cardumes.lista.size())
		for c in jogo.cardumes.lista: print("  cardume ", c.especie, " a ", snapped(c.centro.distance_to(b), 1), " m, fundo ", snapped(ilha.altura_em(c.centro), 0.1))
	if q == 6: foto("c_partida")
	if q == 7: cam(ilha.cais_ponta + dir * 22 + lado * 12 + Vector3(0, 9, 0), ilha.cais_ponta - dir * 6 + Vector3(0, 1, 0))
	if q == 12: foto("c_cais_mar")
	if q == 13: cam(ilha.cais_ponta - dir * 14 + lado * 7 + Vector3(0, 6, 0), ilha.cais_ponta + Vector3(0, 1, 0))
	if q == 18: foto("c_cais_ponta")
	if q == 19: cam(ilha.cais_inicio - dir * 8 + lado * 6 + Vector3(0, 7, 0), ilha.cais_ponta - dir * 16 + Vector3(0, 1, 0))
	if q == 24: foto("c_cais_corpo")
	if q == 25:
		var pe: Vector3 = ilha.cais_inicio - dir * 24
		cam(pe + Vector3(0, 40, 24), pe - dir * 25)
	if q == 30: foto("c_vila_cima")
	if q == 31:
		jogo.clima.hora = 21.5; jogo.clima.atualizar()
		cam(ilha.cais_ponta + dir * 20 + lado * 10 + Vector3(0, 7, 0), ilha.cais_ponta - dir * 6 + Vector3(0, 1, 0))
	if q == 38: foto("c_cais_noite")
	if q == 39:
		jogo.clima.hora = 12.0; jogo.clima.atualizar()
		jogo.barco.global_position = b + Vector3(50, 0, 40)
		jogo.reiniciar()
	if q == 43:
		var b2: Vector3 = jogo.barco.global_position
		print("REINICIO barco ", b2, " giro=", snapped(jogo.barco.rotation.y, 0.01), " dist_cais=", snapped(ilha.distancia_do_cais(b2), 0.1), " cardumes=", jogo.cardumes.lista.size())
		for c in jogo.cardumes.lista: print("  cardume ", c.especie, " a ", snapped(c.centro.distance_to(b2), 1), " m, fundo ", snapped(ilha.altura_em(c.centro), 0.1))
		jogo.interface.esconder_hud = true
	if q == 46: foto("c_reinicio")
	if q == 47:
		S.apagar()
		return true
	return false
