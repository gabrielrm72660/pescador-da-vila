extends SceneTree
# Quem custa o que: esconde um grupo de cada vez e mede draws/triangulos (qualidade Alta)
var jogo
var q := 0
var passos := ["tudo", "sem_npc", "sem_boias", "sem_fauna", "sem_farol_feixe", "sem_ilhas"]
var i := 0
func _initialize() -> void:
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func _process(_d: float) -> bool:
	q += 1
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 15.5; jogo.clima.atualizar()
		jogo.interface.esconder_hud = true
		jogo.graficos.qualidade = 2
		jogo.graficos.aplicar()
	if q >= 8 and (q - 8) % 6 == 0:
		var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		print("PERF2 ", passos[i], " draws=", dc, " tris=", pr)
		i += 1
		if i >= passos.size():
			return true
		match passos[i]:
			"sem_npc": jogo.vida_portuaria.visible = false
			"sem_boias": jogo.boias.visible = false
			"sem_fauna": jogo.fauna_costeira.visible = false
			"sem_farol_feixe": jogo.ilha._farol_feixe.visible = false
			"sem_ilhas":
				for il in jogo.ilhas: il.visible = false
	return false
