extends "res://testes/caso_teste.gd"
const P = preload("res://logica/pesca.gd")
const E = preload("res://logica/especies.gd")
const M = preload("res://logica/mapa.gd")

var l
func _init(): l = E.carregar()

func _mundo():
	var m = load("res://cenas/Mundo.tscn").instantiate()
	m.iniciar()
	m.barco.atracado = false
	m.barco.position = Vector2(3000, 3000)        # mar aberto
	for c in m.cardumes.duplicate(): c.free()
	m.cardumes.clear()
	return m

func _por(m, id: String, desloc := Vector2(40, 0)):
	var r := RandomNumberGenerator.new(); r.seed = 9
	return m.adicionar_cardume(P.novo_cardume(E.por_id(l, id), m.barco.position + desloc, r))

func _parar_em(m, onde: String) -> String:
	var med = m.fisgada.prep.medidor
	var pos := {"dourada": 0.5, "verde": 0.5 + med.dourada / 2.0 + (med.verde - med.dourada) / 4.0, "erro": 0.02}
	m.fisgada.t = float(pos[onde]) * med.periodo / 2.0
	return m.acao_pescar()

func test_mundo_mantem_cardumes_em_volta():
	var m = _mundo()
	for i in 200: m.atualizar_cardumes(0.5)
	afirmar(m.cardumes.size() >= 3 and m.cardumes.size() <= m.MAX_CARDUMES, "cardumes: %d" % m.cardumes.size())
	for c in m.cardumes:
		afirmar(M.zona_da_celula(m.mundo, c.position) != M.TERRA, "na água")
		afirmar(c.get_parent() == m.get_node("Cardumes"), "filho de Cardumes")
	var longe = m.cardumes[0]; longe.position = m.barco.position + Vector2(m.R_SOME + 500, 0)
	m.atualizar_cardumes(0.1)
	afirmar(not longe in m.cardumes, "o que ficou longe saiu da lista")
	m.free()

func test_bloqueios_avisam_e_nao_abrem_medidor():
	var m = _mundo()
	igual(m.acao_pescar(), "longe", "sem cardume"); afirmar(m.aviso.contains("perto"), m.aviso)
	_por(m, "tainha", Vector2(400, 0))
	igual(m.acao_pescar(), "longe", "cardume longe")
	var c = _por(m, "tainha")
	m.barco.vel = 100.0
	igual(m.acao_pescar(), "rapido", "rápido"); afirmar(m.aviso.contains("velocidade"), m.aviso)
	m.barco.vel = 0.0; c.free(); m.cardumes.clear()
	_por(m, "atum")
	igual(m.acao_pescar(), "vara", "vara rasa em cardume profundo"); afirmar(m.aviso.contains("Vara fraca"), m.aviso)
	afirmar(m.fisgada.is_empty(), "medidor fechado")
	m.barco.atracado = true
	igual(m.acao_pescar(), "atracado", "atracado não pesca")
	m.free()

func test_fisgar_na_verde_guarda_e_registra():
	var m = _mundo(); var c = _por(m, "tainha")
	igual(m.acao_pescar(), "medidor", "abriu o medidor"); afirmar(not m.fisgada.is_empty(), "fisgada em curso")
	afirmar(not m.dados_hud().medidor.is_empty(), "o HUD recebe o medidor")
	igual(_parar_em(m, "verde"), "fisgou", "fisgou")
	igual(m.porao.itens.size(), 1, "no porão"); igual(m.porao.itens[0].especie, "tainha", "tainha")
	igual(int(m.catalogo.entradas.tainha.qtd), 1, "no catálogo")
	afirmar(c.disperso, "o cardume se dispersa depois da fisgada")
	afirmar(m.aviso.contains("Tainha") and m.aviso.contains("cm"), "aviso: %s" % m.aviso)
	afirmar(m.fisgada.is_empty() and m.dados_hud().medidor.is_empty(), "medidor fechou")
	m.free()

func test_dourada_tambem_fisga():
	var m = _mundo(); _por(m, "tainha")
	m.acao_pescar(); igual(_parar_em(m, "dourada"), "fisgou", "dourada")
	igual(m.porao.itens.size(), 1, "guardou")
	m.free()

func test_errar_gasta_tentativa_e_espera():
	var m = _mundo(); var c = _por(m, "tainha")
	m.acao_pescar(); igual(_parar_em(m, "erro"), "errou", "errou")
	igual(c.tentativas(), 2, "gastou uma"); igual(m.porao.itens.size(), 0, "nada no porão")
	igual(m.acao_pescar(), "espera", "2 s de espera")
	m.avancar_tempo(P.ESPERA_ERRO + 0.1)
	igual(m.acao_pescar(), "medidor", "depois da espera abre de novo")
	_parar_em(m, "erro"); m.avancar_tempo(2.1); m.acao_pescar(); _parar_em(m, "erro")
	afirmar(c.disperso, "três erros dispersam"); afirmar(m.aviso.contains("dispersou"), m.aviso)
	m.free()

func test_cardume_que_se_afasta_cancela_a_fisgada():
	var m = _mundo(); var c = _por(m, "tainha")
	m.acao_pescar()
	c.position = m.barco.position + Vector2(400, 0)
	m.avancar_tempo(0.1)
	afirmar(m.fisgada.is_empty(), "cancelou"); igual(c.tentativas(), 3, "sem gastar tentativa")
	afirmar(m.aviso.contains("escapou"), m.aviso)
	m.free()

func test_rede_em_cardume_bola():
	var m = _mundo(); m.tem_rede = true
	var c = _por(m, "sardinha")
	igual(m.acao_pescar(), "rede", "lançou a rede")
	afirmar(m.porao.itens.size() >= 3 and m.porao.itens.size() <= 6, "3 a 6: %d" % m.porao.itens.size())
	for it in m.porao.itens: afirmar(float(it.f) <= 0.5, "pequenos")
	afirmar(c.disperso and m.fisgada.is_empty(), "sem medidor, cardume dispersa")
	_por(m, "sardinha", Vector2(0, 40))
	igual(m.acao_pescar(), "espera", "6 s de recarga"); afirmar(m.aviso.contains("Rede"), m.aviso)
	m.avancar_tempo(P.RECARGA_REDE + 0.1)
	igual(m.acao_pescar(), "rede", "recarregou")
	m.tem_rede = false; _por(m, "sardinha", Vector2(0, -40))
	igual(m.acao_pescar(), "medidor", "sem rede usa a vara")
	m.free()

func test_rede_com_porao_quase_cheio_guarda_o_que_cabe():
	var m = _mundo(); m.tem_rede = true
	m.porao.capacidade = 0.25
	_por(m, "sardinha")
	igual(m.acao_pescar(), "rede", "lançou")
	afirmar(m.porao.usado() <= 0.25 + 1e-6, "não estoura o porão"); afirmar(m.pendente.is_empty(), "rede não deixa pendente")
	afirmar(m.aviso.contains("voltaram ao mar") or m.aviso.contains("voltou ao mar"), m.aviso)
	m.free()

func test_porao_cheio_deixa_o_peixe_pendente():
	var m = _mundo()
	m.porao.adicionar({"especie": "sardinha", "tam": 15.0, "classe": "P", "volume": m.porao.capacidade - 0.01, "valor": 1})
	_por(m, "tainha"); m.acao_pescar()
	igual(_parar_em(m, "verde"), "cheio", "não coube")
	afirmar(not m.pendente.is_empty(), "peixe na mão"); igual(m.porao.itens.size(), 1, "porão igual")
	afirmar(not m.catalogo.entradas.has("tainha"), "só registra quando guarda")
	_por(m, "tainha", Vector2(0, 40))
	igual(m.acao_pescar(), "cheio", "com peixe na mão não pesca outro")
	m.soltar_do_porao(0)
	afirmar(m.pendente.is_empty(), "entrou"); igual(m.porao.itens[0].especie, "tainha", "tainha guardada")
	igual(int(m.catalogo.entradas.tainha.qtd), 1, "registrou")
	m.free()

func test_desistir_devolve_ao_mar():
	var m = _mundo()
	m.porao.adicionar({"especie": "sardinha", "tam": 15.0, "classe": "P", "volume": m.porao.capacidade, "valor": 1})
	_por(m, "tainha"); m.acao_pescar(); _parar_em(m, "verde")
	m.desistir_pendente()
	afirmar(m.pendente.is_empty(), "soltou"); igual(m.porao.itens.size(), 1, "porão igual")
	afirmar(m.aviso.contains("mar"), m.aviso)
	m.free()

func test_trocar_vara():
	var m = _mundo()
	m.trocar_vara(); igual(m.vara, "rasa", "só tem a rasa"); afirmar(m.aviso.contains("só tem"), m.aviso)
	m.varas = ["rasa", "profunda"]
	m.trocar_vara(); igual(m.vara, "profunda", "trocou"); afirmar(m.aviso.contains("Profunda"), m.aviso)
	igual(m.dados_hud().vara, "profunda", "o HUD recebe a vara")
	_por(m, "atum"); igual(m.acao_pescar(), "medidor", "agora alcança")
	m.trocar_vara(); igual(m.vara, "profunda", "não troca com o medidor aberto")
	m.free()

func test_dados_hud_da_pesca():
	var m = _mundo(); var d: Dictionary = m.dados_hud()
	for k in ["vara", "porao_usado", "porao_cap", "pode_pescar", "medidor", "pendente"]:
		afirmar(d.has(k), "chave %s" % k)
	afirmar(not d.pode_pescar, "sem cardume perto")
	_por(m, "tainha"); afirmar(m.dados_hud().pode_pescar, "com cardume perto")
	m.free()

func test_de_noite_nas_abissais_so_nasce_quem_pode():
	var m = _mundo()
	var fossa: Dictionary = m.mundo.fossas[0]
	m.barco.position = Vector2(fossa.centro[0], fossa.centro[1])
	m.t = 0.0                                     # meia-noite
	for i in 300: m.atualizar_cardumes(0.5)
	afirmar(m.cardumes.size() > 0, "nasceram cardumes na fossa")
	for c in m.cardumes:
		var esp := E.por_id(l, c.especie())
		igual(int(esp.zona), M.zona_da_celula(m.mundo, c.dados.pos), "espécie da zona onde nasceu: %s" % esp.id)
		afirmar(esp.clima != "tempestade", "sem tempestade não nasce %s" % esp.id)
	m.free()
