extends SceneTree
# Capturas de palmeiras, árvores e arbustos com as texturas de folhagem
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
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 14.0; jogo.clima.atualizar()
		jogo.fauna_costeira.set_process(false)
		jogo.interface.esconder_hud = true
	if q == 6: cam(ilha.cais_ponta + dir * 60 + Vector3(0, 14, 0), ilha.cais_inicio + Vector3(0, 6, 0))
	if q == 12: foto("f_ilha_frente")
	if q == 13: cam(ilha.cais_ponta + dir * 12 + lado * 4 + Vector3(0, 5, 0), ilha.cais_inicio - dir * 20 + Vector3(0, 3, 0))
	if q == 19: foto("f_perto")
	if q == 20: cam(ilha.cais_inicio - dir * 10 + Vector3(0, 28, 0) + lado * 20, ilha.cais_inicio - dir * 45 + Vector3(0, 4, 0))
	if q == 26: foto("f_vila")
	if q == 27:
		var farol: Vector2 = ilha.pos_farol
		cam(Vector3(farol.x, 0, farol.y) + Vector3(70, 30, 70), Vector3(farol.x, 18, farol.y))
	if q == 33: foto("f_mata")
	if q == 34:
		S.apagar()
		return true
	return false
