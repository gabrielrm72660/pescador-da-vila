extends SceneTree
# Farol a noite: feixe visivel de longe, de perto e sobre o mar
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
	var pf: Vector2 = jogo.ilha.pos_farol
	var topo := Vector3(pf.x, jogo.ilha._altura_local(pf.x - jogo.ilha.centro.x, pf.y - jogo.ilha.centro.z) + 14.0, pf.y)
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 22.0; jogo.clima.atualizar(); jogo.atualizar_interface()
		jogo.interface.esconder_hud = true
		print("farol em ", topo, " noite=", jogo.ilha._farol_noite, " feixe=", jogo.ilha._farol_feixe != null)
	if q == 6: cam(topo + Vector3(-90, -6, 130), topo)
	if q == 10: foto("f_longe1")
	if q == 40: foto("f_longe2")
	if q == 70: foto("f_longe3")
	if q == 71: cam(topo + Vector3(-25, -2, 38), topo + Vector3(0, 0, -40))
	if q == 76: foto("f_perto")
	if q == 77:
		var b: Vector3 = jogo.barco.global_position
		cam(b + Vector3(0, 6, 14), topo)
	if q == 82: foto("f_do_barco")
	if q == 83:
		S.apagar()
		return true
	return false
