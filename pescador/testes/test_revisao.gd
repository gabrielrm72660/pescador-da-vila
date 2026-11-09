extends "res://testes/caso_teste.gd"
## Testes das correções da revisão final da fase 1.
const E = preload("res://logica/especies.gd")
const MK = preload("res://logica/mercado.gd")
const MI = preload("res://logica/missoes.gd")
const P = preload("res://logica/porao.gd")
const C = preload("res://logica/catalogo.gd")

var d; var l
func _init(): d = MK.carregar_dados(); l = E.carregar()


# Importante 1 — dados inválidos são apontados pelo próprio jogo
func test_validar_especies_aponta_erros():
	var boa: Dictionary = E.por_id(l, "atum").duplicate()
	var invertida := boa.duplicate(); invertida.id = "x1"; invertida.tam_min = 50.0; invertida.tam_max = 10.0
	var sem_zona := boa.duplicate(); sem_zona.id = "x2"; sem_zona.erase("zona")
	var zona_ruim := boa.duplicate(); zona_ruim.id = "x3"; zona_ruim.zona = 5
	var erros = E.validar([boa, invertida, sem_zona, zona_ruim])
	igual(erros.size(), 3, "três erros: %s" % str(erros))
	afirmar(str(erros).contains("x1") and str(erros).contains("x2") and str(erros).contains("x3"), "nomeia a espécie")

func test_validar_cidades_e_missoes():
	var ruim: Dictionary = d.duplicate(true)
	ruim.cidades.cidades[0].mult_zona = [1.0, 1.0]
	ruim.cidades.cidades[1].zonas_pedidos = [3]
	afirmar(MK.validar_dados(ruim).size() >= 2, "mult_zona curto e zona pedida inválida")
	igual(MK.validar_dados(d), [], "dados reais válidos")
	var cfg: Dictionary = MI.config().duplicate(true)
	cfg.encomenda.qtd = [5, 2]
	afirmar(not MI.validar_config(cfg).is_empty(), "faixa invertida")
	igual(MI.validar_config(MI.config()), [], "config real válida")


# Importante 2 — recompensa usa o preço de venda da cidade
func test_encomenda_paga_sobre_o_preco_da_cidade():
	var p = P.new(400.0); var atum = E.por_id(l, "atum")
	var a = E.exemplar_com_f(atum, 0.5); var b = E.exemplar_com_f(atum, 0.5)
	p.adicionar(a); p.adicionar(b)
	var m = {"id": "pn", "tipo": "encomenda", "cidade": "ponta_negra", "especie": "atum", "qtd": 2,
			"classe_min": "P", "prazo_dia": 5, "recompensa_xp": 20}
	var r = MI.entregar(d, m, p, l, "ponta_negra", 1, C.new())
	var venda = MK.preco_venda(a, atum, MK.cidade(d, "ponta_negra")) * 2
	igual(r.reais, roundi(1.5 * venda), "1,5× a venda em Ponta Negra")
	afirmar(r.reais > venda, "vale mais que vender")


# Importante 3 — ciclo de vida das missões
func test_nao_aceita_repetida_nem_vencida():
	var p = P.new(100.0); var ativas := []
	var ex = {"id": "x-1-0", "tipo": "exploracao", "cidade": "porto_farol", "pos": [0, 0], "recompensa": 150,
			"prazo_dia": -1, "recompensa_xp": 25}
	afirmar(MI.aceitar(d, ativas, ex, p, 1), "aceita a primeira")
	afirmar(not MI.aceitar(d, ativas, ex.duplicate(), p, 1), "recusa a mesma de novo")
	var velha = {"id": "v", "tipo": "trofeu", "cidade": "porto_farol", "especie": "robalo", "tam_min": 90.0,
			"prazo_dia": 2, "recompensa_xp": 40}
	afirmar(not MI.aceitar(d, ativas, velha, p, 3), "recusa oferta vencida")
	igual(ativas.size(), 1, "só uma ativa")

func test_expirar_remove_missao_e_carga():
	var p = P.new(100.0); var ativas := []
	var ent = {"id": "e1", "tipo": "entrega", "cidade": "ponta_negra", "destino": "ponta_negra", "volume": 30.0,
			"recompensa": 840, "prazo_dia": 2, "recompensa_xp": 15}
	MI.aceitar(d, ativas, ent, p, 1)
	var removidas = MI.expirar(ativas, p, 3)
	igual(removidas.size(), 1, "uma removida"); igual(ativas.size(), 0, "vaga liberada")
	perto(p.usado(), 0.0, 1e-6, "carga saiu do porão")


# Importante 4 — nenhum peixe vale R$ 0
func test_peixe_minimo_vale_um_real():
	igual(E.exemplar_com_f(E.por_id(l, "peixe_lanterna"), 0.0).valor, 1, "lanterna pequeno vale R$ 1")
