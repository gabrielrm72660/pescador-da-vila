extends "res://testes/caso_teste.gd"
const E = preload("res://logica/especies.gd")
const P = preload("res://logica/pesca.gd")

var l
func _init(): l = E.carregar()

func _mundo():
	var m = load("res://cenas/Mundo.tscn").instantiate()
	m.iniciar()
	return m

func _cais(m, id: String) -> Vector2:
	for c in m.mundo.cidades:
		if c.id == id: return Vector2(c.cais[0], c.cais[1])
	return Vector2.INF

func test_mundo_tem_estado_proprio_sem_autoload():
	var m = _mundo()
	afirmar(m.est != null, "tem estado"); igual(m.est.dinheiro, 50, "novo jogo: R$ 50")
	afirmar(m.porao == m.est.porao and m.catalogo == m.est.catalogo, "porão e catálogo são os do estado")
	afirmar(m.dados_hud().has("dinheiro") and m.dados_hud().has("missoes"), "o HUD recebe dinheiro e missões")
	m.free()

func test_comeca_atracado_com_o_mercado_fechado_e_m_abre():
	var m = _mundo(); var h = m.get_node("HUD")
	afirmar(m.barco.atracado and not h.mercado_aberto(), "início: atracado, mercado fechado")
	m.alternar_mercado(); afirmar(h.mercado_aberto(), "M abre")
	afirmar(h.get_node("TelaMercado").titulo().contains("Porto do Farol"), "mercado da cidade certa")
	m.alternar_mercado(); afirmar(not h.mercado_aberto(), "M fecha")
	m.alternar_atracar(); m.alternar_mercado()
	afirmar(not h.mercado_aberto() and m.aviso.contains("Atraque"), "no mar não abre: %s" % m.aviso)
	m.free()

func test_atracar_abre_o_mercado_da_cidade():
	var m = _mundo(); var h = m.get_node("HUD")
	m.alternar_atracar(); m.barco.position = _cais(m, "vila_arraias") + Vector2(0, 40); m.barco.vel = 0.0
	afirmar(m.tentar_atracar(), "atracou"); afirmar(h.mercado_aberto(), "abriu o mercado")
	igual(m.est.cidade, "vila_arraias", "o estado sabe a cidade")
	afirmar(h.get_node("TelaMercado").titulo().contains("Vila das Arraias"), h.get_node("TelaMercado").titulo())
	afirmar(not h.get_node("TelaMercado").tem("aba:doca"), "sem doca aqui")
	m.free()

func test_mercado_aberto_para_o_tempo_e_trava_o_cais():
	var m = _mundo()
	m.alternar_mercado(); var t0: float = m.t
	m.quadro(1.0); perto(m.t, t0, 1e-6, "tempo parado com o mercado aberto")
	afirmar(not m.alternar_atracar() and m.barco.atracado, "não zarpa com o mercado aberto")
	m.alternar_mercado(); m.quadro(1.0); afirmar(m.t > t0, "fechou: o tempo anda")
	m.free()

func test_vender_e_melhorar_valem_no_barco():
	var m = _mundo(); var h = m.get_node("HUD"); var t = h.get_node("TelaMercado")
	m.porao.adicionar(E.exemplar_com_f(E.por_id(l, "robalo"), 0.9))
	m.alternar_mercado(); t.apertar("vender_tudo")
	afirmar(m.est.dinheiro > 50 and m.porao.itens.is_empty(), "vendeu")
	igual(m.dados_hud().dinheiro, m.est.dinheiro, "painel acompanha")
	m.est.dinheiro = 5000; t.mostrar_aba("doca")
	t.apertar("melhorar:motor"); igual(m.barco.nivel_motor, 2, "motor nível 2 no barco")
	t.apertar("melhorar:tanque"); perto(m.barco.tanque, 160.0, 1e-6, "tanque maior no barco")
	t.apertar("melhorar:porao"); perto(m.porao.capacidade, 200.0, 1e-6, "porão maior")
	t.mostrar_aba("balcao"); t.apertar("comprar:combustivel"); perto(m.barco.combustivel, 160.0, 1e-6, "abasteceu o barco")
	t.apertar("comprar:vara_profunda"); t.apertar("comprar:rede")
	afirmar("profunda" in m.varas and m.tem_rede, "vara e rede valem na pesca")
	m.free()

func test_combustivel_gasto_no_mar_chega_ao_mercado():
	var m = _mundo()
	m.alternar_atracar(); m.barco.combustivel = 30.0
	m.barco.position = _cais(m, "porto_farol"); m.barco.vel = 0.0; m.tentar_atracar()
	perto(m.est.combustivel, 30.0, 1e-6, "o estado recebe o que sobrou")
	afirmar(m.get_node("HUD/TelaMercado").textos().size() >= 0, "tela montada")
	m.get_node("HUD/TelaMercado").mostrar_aba("balcao")
	afirmar(m.get_node("HUD/TelaMercado").textos().any(func(s): return s.contains("70 un.")), "oferece os 70 que faltam")
	m.free()

func test_missao_vence_na_virada_do_dia():
	var m = _mundo(); m.alternar_atracar()
	m.est.missoes.ativas = [{"id": "c1", "tipo": "entrega", "cidade": "ponta_negra", "destino": "ponta_negra",
			"volume": 30.0, "recompensa": 300, "recompensa_xp": 15, "prazo_dia": 1}]
	m.porao.adicionar({"carga": true, "missao": "c1", "volume": 30.0})
	m.avancar_tempo(160.0)
	igual(m.dia, 2, "virou o dia"); afirmar(m.est.missoes.ativas.is_empty() and m.porao.itens.is_empty(), "missão e carga saíram")
	afirmar(m.aviso.contains("venceu"), m.aviso)
	m.free()

func test_exploracao_e_achada_no_mar_e_entra_na_bussola():
	var m = _mundo(); m.alternar_atracar()
	m.est.missoes.ativas = [{"id": "x1", "tipo": "exploracao", "cidade": "porto_farol", "alvo": "naufragio_distante",
			"nome_alvo": "Naufrágio Distante", "pos": [11000, 6000], "recompensa": 150, "recompensa_xp": 25, "prazo_dia": -1}]
	var achou := false
	for i in 4:
		m.trocar_destino()
		if m.dados_hud().destino_nome == "Naufrágio Distante": achou = true; break
	afirmar(achou, "B passa pelo alvo da missão")
	perto(m.dados_hud().milhas, Vector2(11000, 6000).distance_to(m.barco.position) / 200.0, 0.5, "distância até o alvo")
	m.barco.position = Vector2(10900, 6000); m.avancar_tempo(0.1)
	afirmar(m.aviso.contains("Naufrágio Distante") and m.aviso.contains("Porto do Farol"), m.aviso)
	afirmar(m.dados_hud().destino_nome != "Naufrágio Distante", "achado: sai da bússola")
	m.free()

func test_j_abre_as_missoes():
	var m = _mundo(); var h = m.get_node("HUD")
	m.alternar_missoes(); afirmar(h.missoes_abertas(), "J abre")
	afirmar(h.get_node("PainelMissoes").textos()[0].contains("Nenhuma"), "vazio")
	m.alternar_missoes(); afirmar(not h.missoes_abertas(), "J fecha")
	m.free()

func test_pescar_continua_usando_o_estado():
	var m = _mundo(); m.alternar_atracar(); m.barco.position = Vector2(3000, 3000)
	for c in m.cardumes.duplicate(): c.free()
	m.cardumes.clear()
	var r := RandomNumberGenerator.new(); r.seed = 1
	m.adicionar_cardume(P.novo_cardume(E.por_id(l, "tainha"), m.barco.position + Vector2(40, 0), r))
	m.acao_pescar(); m.fisgada.t = m.fisgada.prep.medidor.periodo / 4.0; m.acao_pescar()
	igual(m.est.porao.itens.size(), 1, "o peixe está no porão do estado"); igual(int(m.est.catalogo.entradas.tainha.qtd), 1, "e no catálogo")
	m.free()
