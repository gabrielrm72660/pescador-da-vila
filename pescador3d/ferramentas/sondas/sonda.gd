extends SceneTree
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
	var C: Vector3 = ilha.centro
	var dir: Vector3 = (ilha.cais_ponta - ilha.cais_inicio).normalized()
	var lado := Vector3(-dir.z, 0, dir.x)
	var farol: Vector2 = ilha.pos_farol
	if q == 2:
		foto("g_menu")
		print("barco em ", jogo.barco.global_position, " ilha.centro ", C, " cais ", ilha.cais_inicio, " -> ", ilha.cais_ponta, " farol ", farol)
		print("ilhas: ", jogo.ilhas.size(), " pontos_interesse: ", ilha.pontos_interesse.size())
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 15.5; jogo.clima.atualizar()
	if q == 12:
		foto("g_inicio_hud")
		jogo.interface.esconder_hud = true
	if q == 14: foto("g_inicio")
	# ilha vista do mar, de frente para o cais
	if q == 15: cam(ilha.cais_ponta + dir * 60 + Vector3(0, 14, 0), ilha.cais_inicio + Vector3(0, 6, 0))
	if q == 22: foto("g_ilha_frente")
	# cais de perto
	if q == 23: cam(ilha.cais_ponta + dir * 12 + lado * 4 + Vector3(0, 5, 0), ilha.cais_inicio - dir * 20 + Vector3(0, 3, 0))
	if q == 30: foto("g_cais")
	# vista aerea da ilha
	if q == 31: cam(C + Vector3(0, 330, 90), C)
	if q == 38: foto("g_ilha_cima")
	# farol
	if q == 39: cam(Vector3(farol.x, 0, farol.y) + Vector3(70, 55, 70), Vector3(farol.x, 50, farol.y))
	if q == 46: foto("g_farol")
	# vila de frente por cima do cais
	if q == 47: cam(ilha.cais_inicio - dir * 10 + Vector3(0, 28, 0) + lado * 20, ilha.cais_inicio - dir * 45 + Vector3(0, 4, 0))
	if q == 54: foto("g_vila")
	# noite
	if q == 55:
		jogo.clima.hora = 21.5; jogo.clima.atualizar(); jogo.atualizar_interface()
		cam(ilha.cais_ponta + dir * 60 + Vector3(0, 14, 0), ilha.cais_inicio + Vector3(0, 12, 0))
	if q == 64: foto("g_noite")
	if q == 65: cam(Vector3(farol.x, 0, farol.y) + Vector3(90, 40, 90), Vector3(farol.x, 55, farol.y))
	if q == 72: foto("g_farol_noite")
	# ilha rata e conchas
	if q == 73:
		jogo.clima.hora = 15.5; jogo.clima.atualizar()
		var r = jogo.ilhas[1]
		cam(r.centro + Vector3(120, 30, 150), r.centro + Vector3(0, 4, 0))
	if q == 80: foto("g_rata")
	if q == 81:
		var r = jogo.ilhas[2]
		cam(r.centro + Vector3(100, 28, 130), r.centro + Vector3(0, 4, 0))
	if q == 88: foto("g_conchas")
	# mar aberto
	if q == 89:
		var b: Vector3 = jogo.barco.global_position
		cam(b + Vector3(0, 6, 22), b + Vector3(0, 1, 0))
	if q == 95: foto("g_barco")
	# mapa
	if q == 96:
		jogo.interface.esconder_hud = false
		jogo.interface.alternar_mapa()
	if q == 104: foto("g_mapa")
	if q == 105:
		jogo.interface.alternar_mapa()
	if q == 112:
		foto("g_final"); S.apagar()
		return true
	return false
