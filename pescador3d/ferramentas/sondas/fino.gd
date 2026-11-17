extends SceneTree
var jogo
var q := 0
const S = preload("res://scripts/salvamento.gd")
func _initialize() -> void:
	S.apagar()
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func _process(_d: float) -> bool:
	q += 1
	if q == 4:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 12.0; jogo.clima.atualizar(); jogo.atualizar_interface()
	if q == 8:
		for n in jogo.find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if not g.is_visible_in_tree(): continue
			var ab: AABB = g.global_transform * g.get_aabb()
			if ab.size.y > 40.0 and ab.size.x < 12.0 and ab.size.z < 12.0:
				print("FINO ", g.get_path(), " ", ab)
		for n in jogo.find_children("*", "CPUParticles3D", true, false):
			var c := n as CPUParticles3D
			print("PART ", c.get_path(), " emitting=", c.emitting, " vis=", c.is_visible_in_tree())
		S.apagar()
		return true
	return false
