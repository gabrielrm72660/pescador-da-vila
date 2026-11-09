extends "res://testes/caso_teste.gd"
const M = preload("res://logica/mapa.gd")

func _mundo():
	var m = load("res://cenas/Mundo.tscn").instantiate()
	m.iniciar()
	return m

func _cais(m, id: String) -> Vector2:
	for c in m.mundo.cidades:
		if c.id == id: return Vector2(c.cais[0], c.cais[1])
	return Vector2.INF

func test_mundo_instancia_com_os_nos():
	var m = _mundo()
	for n in ["Mapa", "Barco", "Farol", "Luz", "Cidades"]:
		afirmar(m.get_node_or_null(n) != null, "tem %s" % n)
	igual(m.get_node("Cidades").get_child_count(), 3, "3 cidades")
	afirmar(m.get_node_or_null("Barco/Camera2D") != null, "câmera no barco")
	m.free()

func test_comeca_atracado_no_porto():
	var m = _mundo()
	afirmar(m.barco.atracado, "atracado")
	perto(m.barco.position.distance_to(_cais(m, "porto_farol")), 0.0, 1e-3, "no cais do porto")
	m.free()

func test_atracar_so_perto_e_devagar():
	var m = _mundo(); var b = m.barco
	b.atracado = false
	b.position = _cais(m, "porto_farol") + Vector2(0, 600)
	afirmar(not m.tentar_atracar(), "longe"); afirmar(m.aviso.contains("cais"), "aviso fala do cais: %s" % m.aviso)
	b.position = _cais(m, "porto_farol") + Vector2(0, 50); b.vel = 100.0
	afirmar(not m.tentar_atracar(), "rápido"); afirmar(m.aviso.contains("devagar"), "aviso pede devagar: %s" % m.aviso)
	b.vel = 0.0
	afirmar(m.tentar_atracar(), "atracou"); afirmar(b.atracado, "barco atracado")
	igual(m.cidade_atual, "porto_farol", "cidade atual")
	m.free()

func test_destino_cicla_com_b():
	var m = _mundo()
	igual(m.destino_id, "porto_farol", "padrão")
	for i in 3: m.trocar_destino()
	igual(m.destino_id, "porto_farol", "deu a volta")
	m.free()

func test_dados_hud_tem_as_chaves():
	var m = _mundo(); var d: Dictionary = m.dados_hud()
	for k in ["marcha", "vela", "combustivel", "tanque", "zona_nome", "dia", "hora", "destino_nome", "rumo_destino",
			"milhas", "rumo_farol", "farol_visivel", "aviso", "aviso_id"]:
		afirmar(d.has(k), "chave %s" % k)
	afirmar(d.zona_nome in M.NOMES_ZONA or d.zona_nome == "Terra", "zona: %s" % d.zona_nome)
	m.free()

func test_noite_acende_o_farol():
	var m = _mundo()
	m.avancar_tempo(0.0); afirmar(not m.get_node("Farol").aceso, "de manhã apagado")
	m.t = 0.0; m.avancar_tempo(0.0); afirmar(m.get_node("Farol").aceso, "à meia-noite aceso")
	m.free()
