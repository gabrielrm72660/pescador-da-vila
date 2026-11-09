extends "res://testes/caso_teste.gd"
const P = preload("res://logica/porao.gd")
const E = preload("res://logica/especies.gd")

func _ex(id: String, vol: float) -> Dictionary:
	return {"especie": id, "tam": 10.0, "f": 0.1, "classe": "P", "peso": 1.0, "volume": vol, "valor": 1}

func test_cabe_ate_o_limite():
	var p = P.new(100.0)
	afirmar(p.adicionar(_ex("atum", 60.0)), "60 cabe"); afirmar(p.adicionar(_ex("atum", 40.0)), "exato cabe")
	afirmar(not p.adicionar(_ex("sardinha", 0.1)), "cheio recusa"); perto(p.livre(), 0.0, 1e-6, "livre 0")

func test_maior_que_o_porao():
	var p = P.new(100.0)
	afirmar(not p.adicionar(_ex("mero", 128.0)), "mero recorde não cabe no porão inicial")
	igual(p.itens.size(), 0, "nada entrou")

func test_soltar_e_indice_invalido():
	var p = P.new(100.0); p.adicionar(_ex("tainha", 2.0))
	igual(p.soltar(5), {}, "índice inválido"); igual(p.soltar(-1), {}, "negativo")
	igual(p.soltar(0).especie, "tainha", "soltou"); igual(p.itens.size(), 0, "vazio")

func test_menores_ignora_carga():
	var p = P.new(200.0)
	p.adicionar(_ex("atum", 30.0)); p.adicionar({"carga": true, "missao": "m1", "volume": 1.0}); p.adicionar(_ex("tainha", 2.0))
	igual(p.menores(1), [2], "menor peixe é a tainha")

func test_comer_o_comum_menor():
	var l = E.carregar(); var p = P.new(100.0)
	p.adicionar(_ex("robalo", 1.0)); p.adicionar(_ex("tainha", 3.0)); p.adicionar(_ex("sardinha", 0.2))
	igual(p.comer(l).especie, "sardinha", "come a sardinha (comum, menor)")
	igual(p.comer(l).especie, "tainha", "depois a tainha; robalo é raro")
	igual(p.comer(l), {}, "não come o raro")

func test_carga_e_lista():
	var p = P.new(100.0); p.adicionar({"carga": true, "missao": "m7", "volume": 40.0}); p.adicionar(_ex("atum", 10.0))
	afirmar(p.remover_carga("m7"), "removeu carga"); afirmar(not p.remover_carga("m7"), "já não existe")
	var q = P.new(100.0); q.carregar_lista(p.para_lista()); igual(q.peixes().size(), 1, "ida e volta")
