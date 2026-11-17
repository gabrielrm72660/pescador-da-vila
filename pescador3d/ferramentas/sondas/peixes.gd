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
	c.look_at(alvo, Vector3.UP if absf((alvo - pos).normalized().y) < 0.99 else Vector3(0, 0, -1))
func cam_livre() -> void:
	var c: Camera3D = jogo.get_node("Camera")
	c.set_process(true); c.set_physics_process(true)
func encher(lista: Array) -> void:
	jogo.porao.itens.clear()
	for e in lista:
		if not jogo.porao.guardar(e, 2.0, "Boa"):
			print("NAO CABE: ", e)
func _process(_d: float) -> bool:
	q += 1
	var b: Vector3 = jogo.barco.global_position
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 12.0; jogo.clima.atualizar()
		jogo.fauna_costeira.set_process(false)
		jogo.porao.colunas = 7
		jogo.porao.linhas = 5
	if q == 5:
		encher(["Atum", "Garoupa", "Cavala", "Barracuda", "Dourado", "Olho-de-cão", "Xaréu", "Tainha", "Sardinha"])
		jogo.interface.alternar_painel("porao")
	if q == 9: foto("p_porao1")
	if q == 10:
		encher(["Agulhão-vela", "Arabaiana", "Namorado", "Moreia", "Budião", "Robalo", "Peixe-voador", "Baiacu", "Peixe-anjo"])
	if q == 14: foto("p_porao2")
	if q == 15:
		jogo.interface.alternar_painel("porao")
		jogo.interface.esconder_hud = true
		jogo.porao.itens.clear()
		var fr: Vector3 = -jogo.barco.global_transform.basis.z
		var lado := Vector3(-fr.z, 0, fr.x)
		var esp := ["Atum", "Peixe-voador", "Moreia", "Baiacu", "Budião", "Agulhão-vela", "Peixe-anjo", "Barracuda"]
		var centro := b + fr * 80.0
		for i in esp.size():
			var p := centro + lado * (-45.0 + (i % 4) * 30.0) + fr * (-10.0 + (i / 4) * 28.0)
			jogo.cardumes.criar(p, esp[i])
		cam(centro + lado * (-15.0) + Vector3(0, 46, 0), centro + lado * (-15.0) + fr * 8.0)
	if q == 22: foto("p_cima_dia")
	if q == 23:
		jogo.clima.hora = 23.0; jogo.clima.atualizar()
		jogo.cardumes.noite = true
	if q == 30: foto("p_cima_noite")
	if q == 31:
		jogo.clima.hora = 13.0; jogo.clima.atualizar()
		jogo.cardumes.noite = false
		jogo.cardumes.limpar()
		cam_livre()
		jogo.interface.esconder_hud = false
		jogo.barco.velocidade = 0.0
		jogo.cardumes.criar(b + Vector3(3, 0, -5), "Agulhão-vela")
	if q == 33:
		jogo.pesca.acao()
		print("estado pesca: ", jogo.pesca.estado, " alvo: ", jogo.pesca.alvo.get("especie", "-"))
	if q == 36:
		jogo.pesca.progresso = 0.55
		foto("p_anel_vela")
	if q == 37:
		jogo.pesca.soltar() if jogo.pesca.has_method("soltar") else null
		jogo.cardumes.limpar()
		jogo.cardumes.criar(b + Vector3(3, 0, -5), "Moreia")
	if q == 39: jogo.pesca.acao()
	if q == 42:
		jogo.pesca.progresso = 0.25
		foto("p_anel_moreia")
	if q == 43:
		S.apagar()
		return true
	return false
