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
func cam_livre() -> void:
	var c: Camera3D = jogo.get_node("Camera")
	c.set_process(true); c.set_physics_process(true)
func info(rot: String) -> void:
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var ob := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	print("INFO %s draws=%d prims=%d objs=%d nos=%d proc_ms=%.1f" % [rot, dc, pr, ob, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
func _process(_d: float) -> bool:
	q += 1
	var b: Vector3 = jogo.barco.global_position
	var ilha = jogo.ilha
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 15.5; jogo.clima.atualizar()
	if q == 6:
		info("inicio")
		print("cardumes semeados: ", jogo.cardumes.lista.size(), " especies: ", jogo.cardumes.lista.map(func(c): return c.especie))
	if q == 7:
		var offs := [Vector3(-22, 0, -34), Vector3(-6, 0, -40), Vector3(12, 0, -36), Vector3(28, 0, -42), Vector3(2, 0, -56)]
		var esp := ["Atum", "Garoupa", "Dourado", "Sardinha", "Tainha"]
		for i in 5:
			jogo.cardumes.criar(b + offs[i], esp[i])
		jogo.interface.esconder_hud = true
		cam(b + Vector3(0, 22, 12), b + Vector3(2, 0, -42))
	if q == 12:
		foto("g_cardumes")
		info("com_cardumes")
	if q == 13:
		cam_livre()
		jogo.interface.esconder_hud = false
		var c = jogo.cardumes.criar(b + Vector3(3, 0, -5), "Tainha")
		jogo.barco.velocidade = 0.0
	if q == 15:
		jogo.pesca.acao()
		print("estado pesca: ", jogo.pesca.estado, " alvo: ", jogo.pesca.alvo.get("especie", "-"))
	if q == 18: foto("g_pescando")
	if q >= 19 and q <= 40 and q % 2 == 1 and jogo.pesca.estado == jogo.pesca.Estado.PUXANDO:
		if not jogo.pesca.faixas.is_empty():
			jogo.pesca.angulo = float(jogo.pesca.faixas[0].centro)
			jogo.pesca.trava = 0.0
		jogo.pesca.acao()
	if q == 41:
		print("pos-pesca: peixes=", jogo.pesca.num_peixes, " itens porao=", jogo.porao.itens.size(), " tensao=", snapped(jogo.pesca.tensao, 0.01), " linha=", jogo.pesca.estado_linha())
		jogo.porao.guardar("Atum", 14.2, "Excepcional")
		jogo.porao.guardar("Garoupa", 8.0, "Boa")
		jogo.porao.guardar("Dourado", 7.5, "Regular")
		jogo.porao.guardar("Sardinha", 0.3, "Regular")
		jogo.porao.guardar("Cavala", 4.0, "Boa")
		jogo.porao.guardar("Barracuda", 3.0, "Regular")
		jogo.porao.guardar("Olho-de-cão", 1.0, "Regular")
		jogo.porao.guardar("Xaréu", 3.0, "Regular")
		jogo.interface.alternar_painel("porao")
		jogo.atualizar_interface()
	if q == 46: foto("g_porao")
	if q == 47:
		jogo.interface.alternar_painel("porao")
		jogo.barco.global_position = ilha.cais_ponta + (ilha.cais_ponta - ilha.cais_inicio).normalized() * 4.0
		jogo.barco.velocidade = 0.0
	if q == 50:
		print("pode atracar: ", jogo.pode_atracar(), " distancia cais: ", ilha.distancia_do_cais(jogo.barco.global_position))
		jogo.atracar()
		print("atracado: ", jogo.atracado)
	if q == 54: foto("g_porto")
	if q == 55:
		var antes: int = jogo.dinheiro
		jogo.vender()
		print("venda: ", antes, " -> ", jogo.dinheiro, " contratos: ", jogo.economia.contratos_concluidos)
		jogo.dinheiro += 300
		jogo.melhorar_linha()
		jogo.comprar_iscas()
		jogo.abastecer()
		jogo.comprar("motor")
		print("apos compras dinheiro=", jogo.dinheiro, " linha=", jogo.pesca.estado_linha(), " iscas=", jogo.pesca.iscas_camarao, "/", jogo.pesca.iscas_lula)
	if q == 58: foto("g_porto2")
	if q == 59:
		jogo.zarpar()
		var ok: bool = S.salvar(jogo)
		print("salvou: ", ok, " existe: ", S.existe())
		var f := FileAccess.open("user://pescador_viagem.json", FileAccess.READ)
		if f: print("save: ", f.get_as_text().substr(0, 900))
	if q == 61:
		jogo.graficos.alternar()
	if q == 64:
		foto("g_opcoes")
		jogo.graficos.alternar()
		jogo.graficos.alternar_fps()
		jogo.graficos.qualidade = 0
		jogo.graficos.aplicar()
	if q == 68:
		foto("g_baixa")
		info("qualidade_baixa")
		jogo.graficos.qualidade = 2
		jogo.graficos.aplicar()
		jogo.graficos.alternar_fps()
	if q == 69:
		jogo.barco.global_position = Vector3(0, 0, 500)
		jogo.barco.velocidade = 0.0
		print(jogo.baleias.testar_avistamento())
		print(jogo.oceano.testar_tempestade())
	if q == 80:
		foto("g_tempestade")
		info("tempestade")
	if q == 81:
		jogo.interface.mapa.marcador = Vector2(300, -400)
		jogo.interface.mapa.tem_marcador = true
		jogo.atualizar_interface()
		jogo.interface.alternar_mapa()
	if q == 86:
		foto("g_mapa_destino")
		jogo.interface.alternar_mapa()
	if q == 90:
		# diagnostico F4
		jogo._diagnostico_navegacao()
		S.apagar()
		return true
	return false
