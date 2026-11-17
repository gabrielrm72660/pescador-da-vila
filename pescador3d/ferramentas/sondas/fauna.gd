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
	c.look_at(alvo, Vector3.UP)
func _process(_d: float) -> bool:
	q += 1
	var fc = jogo.fauna_costeira
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 12.0; jogo.clima.atualizar(); jogo.atualizar_interface()
		jogo.interface.esconder_hud = true
		fc.set_process(false)
	var o := Vector3(-60, 0, -60)
	if q == 9: cam(o + Vector3(0, 4, 0), o + Vector3(0, 1.0, -10))
	if q >= 9 and q <= 30:
		for i in fc._animais.size():
			var a = fc._animais[i]
			a.no.visible = (i == 0 and q < 16) or (i == 1 and q >= 16 and q < 23)
			a.no.position = o + Vector3(0, 1.4, -9)
			a.no.rotation = Vector3(0, 0.9, 0)
	if q == 15: foto("n_golfinho")
	if q == 22: foto("n_tartaruga")
	if q == 31:
		S.apagar()
		return true
	return false
