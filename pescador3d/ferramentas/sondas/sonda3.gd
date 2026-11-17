extends SceneTree
# Cardumes de dia e de noite, de perto e de longe (a camera segue o barco, que nasce no cais)
var jogo
var q := 0
const S = preload("res://scripts/salvamento.gd")
var cs := []
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
	var b: Vector3 = jogo.barco.global_position
	var f: Vector3 = -jogo.barco.global_transform.basis.z
	var r: Vector3 = jogo.barco.global_transform.basis.x
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 12.0; jogo.clima.atualizar()
		jogo.interface.esconder_hud = true
		jogo.cardumes.limpar()
		cs.append(jogo.cardumes.criar(b + f * 55 + r * 20, "Atum"))
		cs.append(jogo.cardumes.criar(b + f * 40 - r * 30, "Dourado"))
		cs.append(jogo.cardumes.criar(b + f * 75 + r * 5, "Sardinha"))
		cs.append(jogo.cardumes.criar(b + f * 120 - r * 40, "Tainha"))
	if q == 8:
		# vista normal do jogo (camera padrao atras do barco)
		var c: Camera3D = jogo.get_node("Camera")
		c.set_process(true); c.set_physics_process(true)
	if q == 14: foto("h_dia_jogo")
	if q == 15: cam(cs[0].centro + Vector3(0, 14, 6), cs[0].centro)
	if q == 19: foto("h_atum_cima")
	if q == 20: cam(cs[1].centro + Vector3(0, 8, 14), cs[1].centro)
	if q == 24: foto("h_dourado_obliquo")
	if q == 25:
		jogo.clima.hora = 22.0; jogo.clima.atualizar(); jogo.atualizar_interface()
		cam(cs[0].centro + Vector3(0, 14, 6), cs[0].centro)
	if q == 31: foto("h_atum_noite")
	if q == 32:
		S.apagar()
		return true
	return false
