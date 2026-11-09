extends "res://testes/caso_teste.gd"
const MI = preload("res://logica/missoes.gd")
const MK = preload("res://logica/mercado.gd")
const E = preload("res://logica/especies.gd")
const P = preload("res://logica/porao.gd")
const C = preload("res://logica/catalogo.gd")

var d; var l
func _init(): d = MK.carregar_dados(); l = E.carregar()
func _rng(s := 11):
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_gerar_respeita_progresso():
	var r = _rng()
	for dia in 30:
		var of = MI.gerar(d, l, "ponta_negra", dia, 0, r)
		igual(of.size(), 3, "três ofertas")
		for m in of:
			if m.has("especie"): afirmar(E.por_id(l, m.especie).zona <= 1, "no máximo uma zona acima da vara rasa")

func test_porto_so_pede_rasas():
	for m in MI.gerar(d, l, "porto_farol", 1, 2, _rng()):
		if m.has("especie"): igual(E.por_id(l, m.especie).zona, 0, "rasas")

func test_maximo_de_ativas_e_carga():
	var p = P.new(100.0); var ativas := []
	var ent = {"id": "x-1-0", "tipo": "entrega", "cidade": "ponta_negra", "destino": "ponta_negra", "volume": 40.0,
			"recompensa": 840, "prazo_dia": 3, "recompensa_xp": 15}
	afirmar(MI.aceitar(d, ativas, ent, p, 1), "aceitou"); perto(p.usado(), 40.0, 1e-6, "carga no porão")
	for i in 2: ativas.append({"id": "e%d" % i, "tipo": "exploracao"})
	afirmar(not MI.aceitar(d, ativas, {"id": "z", "tipo": "exploracao"}, p, 1), "4ª recusada")

func test_encomenda_completa_e_paga():
	var p = P.new(100.0); var tainha = E.por_id(l, "tainha"); var c = C.new()
	for f in [0.5, 0.6, 0.1]: p.adicionar(E.exemplar_com_f(tainha, f))
	var m = {"id": "m", "tipo": "encomenda", "cidade": "porto_farol", "especie": "tainha", "qtd": 2,
			"classe_min": "M", "prazo_dia": 5, "recompensa_xp": 20}
	igual(MI.progresso(m, p, Vector2.ZERO, 1).feito, 2, "duas M servem; a P não")
	igual(MI.entregar(d, m, p, l, "vila_arraias", 1, c).motivo, "cidade_errada", "cidade errada")
	var r = MI.entregar(d, m, p, l, "porto_farol", 1, c)
	afirmar(r.ok, "entregou"); igual(p.peixes().size(), 1, "sobrou a P")
	igual(r.reais, roundi(1.5 * (E.exemplar_com_f(tainha, 0.5).valor + E.exemplar_com_f(tainha, 0.6).valor)), "1,5×")

func test_prazo_vencido():
	var m = {"id": "m", "tipo": "trofeu", "cidade": "porto_farol", "especie": "robalo", "tam_min": 90.0,
			"prazo_dia": 2, "recompensa_xp": 40}
	afirmar(MI.progresso(m, P.new(), Vector2.ZERO, 3).vencida, "venceu")
	igual(MI.entregar(d, m, P.new(), l, "porto_farol", 3, C.new()).motivo, "vencida", "não entrega")
	igual(MI.vencidas([m], 3).size(), 1, "listada como vencida")

func test_trofeu_lendario_da_titulo():
	var p = P.new(800.0); var mero = E.por_id(l, "mero"); var c = C.new()
	p.adicionar(E.exemplar_com_f(mero, 0.9))
	var m = {"id": "t", "tipo": "trofeu", "cidade": "porto_farol", "especie": "mero", "tam_min": 200.0,
			"prazo_dia": -1, "recompensa_xp": 40}
	c.registrar(p.peixes()[0])
	afirmar(MI.entregar(d, m, p, l, "porto_farol", 9, c).ok, "entregou"); afirmar(c.entradas.mero.titulo, "título")

func test_exploracao_por_distancia():
	var m = {"id": "x", "tipo": "exploracao", "cidade": "vila_arraias", "alvo": "naufragio_leste",
			"pos": [9000, -5200], "recompensa": 150, "prazo_dia": -1, "recompensa_xp": 25}
	afirmar(not MI.progresso(m, P.new(), Vector2(8000, -5200), 1).pronta, "longe")
	afirmar(MI.progresso(m, P.new(), Vector2(8750, -5200), 1).pronta, "a 250 px")
