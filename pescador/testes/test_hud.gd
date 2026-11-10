extends "res://testes/caso_teste.gd"

func _dados() -> Dictionary:
	return {"marcha": 3, "vela": true, "combustivel": 62.4, "tanque": 100.0, "zona_nome": "Profundas", "dia": 2,
		"hora": "18:30", "destino_nome": "Vila das Arraias", "rumo_destino": 0.7, "milhas": 35.2, "rumo_farol": 2.0,
		"dist_farol": 5000.0, "farol_visivel": true, "zona_segura": false, "atracado": false, "aviso": "", "aviso_id": 0}

func _hud():
	return load("res://cenas/ui/HUD.tscn").instantiate()

func test_hud_mostra_os_valores():
	var h = _hud(); h.atualizar(_dados())
	afirmar(h.get_node("Painel/Marcha").text.contains("½"), "marcha: %s" % h.get_node("Painel/Marcha").text)
	afirmar(h.get_node("Painel/Vela").text.contains("aberta"), "vela")
	igual(h.get_node("Painel/Combustivel/Texto").text, "62 / 100", "combustível")
	perto(h.get_node("Painel/Combustivel").value, 62.4, 1e-6, "barra"); perto(h.get_node("Painel/Combustivel").max_value, 100.0, 1e-6, "máximo")
	igual(h.get_node("Painel/Zona").text, "Profundas", "zona")
	igual(h.get_node("Painel/Relogio").text, "Dia 2 — 18:30", "relógio")
	igual(h.get_node("Bussola/Destino").text, "Vila das Arraias — 35 mi", "bússola")
	perto(h.get_node("Bussola/Seta").rotation, 0.7, 1e-6, "seta")
	h.free()

func test_indicador_do_farol():
	var h = _hud(); var d := _dados()
	h.atualizar(d); afirmar(h.get_node("IndicadorFarol").visible, "noite e longe: aparece")
	d.farol_visivel = false; h.atualizar(d); afirmar(not h.get_node("IndicadorFarol").visible, "de dia some")
	d.farol_visivel = true; d.dist_farol = 300.0; h.atualizar(d); afirmar(not h.get_node("IndicadorFarol").visible, "farol na tela: some")
	h.free()

func test_aviso_aparece_e_some():
	var h = _hud(); var d := _dados()
	d.aviso = "Atracado em Porto do Farol"; d.aviso_id = 1; h.atualizar(d)
	afirmar(h.get_node("Aviso").visible, "aparece"); igual(h.get_node("Aviso").text, d.aviso, "texto")
	h._process(3.0); afirmar(not h.get_node("Aviso").visible, "some depois de 2,5 s")
	h.atualizar(d); afirmar(not h.get_node("Aviso").visible, "mesmo aviso não volta")
	h.free()
