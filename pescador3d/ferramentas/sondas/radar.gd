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
func _process(_d: float) -> bool:
	q += 1
	var ilha = jogo.ilha
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 15.5; jogo.clima.atualizar()
	if q == 8: foto("r_cais")
	if q == 9:
		jogo.barco.global_position = ilha.centro + Vector3(-90, 0, 130)
		jogo.barco.rotation.y = 0.6
	if q == 14: foto("r_costa")
	if q == 15:
		jogo.barco.global_position = ilha.centro + Vector3(0, 0, 190)
		jogo.barco.rotation.y = 3.3
	if q == 20: foto("r_sul")
	if q == 21:
		S.apagar()
		return true
	return false
