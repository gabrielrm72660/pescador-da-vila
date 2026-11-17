extends SceneTree
var jogo
var q := 0
func _initialize() -> void:
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
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 13.0; jogo.clima.atualizar()
		jogo.interface.esconder_hud = true
	if q == 5:
		var pe: Vector3 = ilha.cais_inicio - dir * 24
		cam(pe + Vector3(0, 14, 10), pe - dir * 12)
	if q == 9: foto("t_alfa")
	if q == 10:
		for no in ilha.find_children("*", "MeshInstance3D", true, false):
			var m := no as MeshInstance3D
			if m.material_override is StandardMaterial3D and m.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				m.material_override.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				m.material_override.vertex_color_use_as_albedo = false
	if q == 14: foto("t_opaco")
	if q == 15: return true
	return false
