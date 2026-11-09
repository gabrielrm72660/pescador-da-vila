extends "res://testes/caso_teste.gd"
const MK = preload("res://logica/mercado.gd")
const E = preload("res://logica/especies.gd")
const P = preload("res://logica/porao.gd")

var d; var l
func _init(): d = MK.carregar_dados(); l = E.carregar()
func _estado(din := 1000) -> Dictionary:
	return {"dinheiro": din, "varas": ["rasa"], "suprimentos": {"agua": 0, "tabua": 0, "corda": 0},
			"combustivel": 90, "tanque": 100, "melhorias": {}}

func test_tres_cidades_e_doca_so_no_porto():
	igual(d.mundo.cidades.size(), 3, "cidades")
	afirmar(MK.cidade(d, "porto_farol").tem_doca, "porto tem doca")
	afirmar(not MK.cidade(d, "vila_arraias").tem_doca and not MK.cidade(d, "ponta_negra").tem_doca, "outras não")

func test_preco_por_cidade():
	var esp = E.por_id(l, "arraia_pintada"); var ex = E.exemplar_com_f(esp, 0.5)
	igual(MK.preco_venda(ex, esp, MK.cidade(d, "porto_farol")), ex.valor, "normal")
	igual(MK.preco_venda(ex, esp, MK.cidade(d, "vila_arraias")), roundi(ex.valor * 1.4), "+40% arraia")
	var atum = E.por_id(l, "atum"); var ea = E.exemplar_com_f(atum, 0.5)
	igual(MK.preco_venda(ea, atum, MK.cidade(d, "ponta_negra")), roundi(ea.valor * 1.5), "+50% profunda")

func test_vender_tudo_preserva_carga():
	var p = P.new(100.0); var esp = E.por_id(l, "tainha")
	p.adicionar(E.exemplar_com_f(esp, 0.5)); p.adicionar({"carga": true, "missao": "m1", "volume": 20.0})
	var total = MK.vender_tudo(p, l, MK.cidade(d, "porto_farol"))
	afirmar(total > 0, "recebeu"); igual(p.itens.size(), 1, "carga ficou")

func test_comprar_regras():
	var e = _estado(500)
	igual(MK.comprar(d, "vara_profunda", 1, "porto_farol", e), "sem_dinheiro", "600 > 500")
	e.dinheiro = 5000
	igual(MK.comprar(d, "vara_abissal", 1, "porto_farol", e), "indisponivel", "abissal só em Ponta Negra")
	igual(MK.comprar(d, "vara_abissal", 1, "ponta_negra", e), "ok", "comprou"); igual(e.dinheiro, 1000, "pagou")
	igual(MK.comprar(d, "vara_abissal", 1, "ponta_negra", e), "ja_tem", "não compra de novo")
	igual(MK.comprar(d, "combustivel", 50, "porto_farol", e), "ok", "combustível")
	igual(e.combustivel, 100, "não passa do tanque"); igual(e.dinheiro, 1000 - 20, "paga só os 10 que couberam")

func test_doca_seca():
	var e = _estado(10000)
	igual(MK.melhorar(d, "porao", "vila_arraias", e), "sem_doca", "só no Porto do Farol")
	igual(MK.preco_melhoria(d, "porao", 0), 400, "porão nível 1")
	for i in 3: igual(MK.melhorar(d, "porao", "porto_farol", e), "ok", "nível %d" % (i + 1))
	igual(MK.melhorar(d, "porao", "porto_farol", e), "maximo", "800 L é o máximo")
	igual(e.dinheiro, 10000 - 400 - 1500 - 5000, "pagou os três")
	igual(MK.preco_reparo(d, 20), 60, "R$ 3 por ponto")
