extends "res://testes/caso_teste.gd"
const E = preload("res://logica/especies.gd")
const MK = preload("res://logica/mercado.gd")

const CAMPOS = ["id", "nome", "zona", "categoria", "raridade", "tam_min", "tam_max", "k_peso", "vol_medio",
		"preco_base", "horario", "clima", "estilo", "qtd", "sprite"]

func test_especies_validas():
	var ids := {}
	for e in E.carregar():
		for c in CAMPOS: afirmar(e.has(c), "%s sem %s" % [e.get("id", "?"), c])
		afirmar(e.zona in [0, 1, 2], "%s zona" % e.id)
		afirmar(e.tam_min > 0 and e.tam_min < e.tam_max, "%s tamanho" % e.id)
		afirmar(e.raridade in ["comum", "incomum", "rara", "lendaria"], "%s raridade" % e.id)
		afirmar(e.horario in ["qualquer", "noite_mais", "so_noite"] and e.clima in ["qualquer", "tempestade"], "%s horário/clima" % e.id)
		afirmar(e.qtd[0] >= 1 and e.qtd[0] <= e.qtd[1], "%s qtd" % e.id)
		afirmar(not ids.has(e.id), "%s repetido" % e.id); ids[e.id] = true
	for z in 3:
		var l = E.carregar().filter(func(x): return x.zona == z)
		igual(l.filter(func(x): return x.raridade == "rara").size(), 1, "uma rara na zona %d" % z)
		igual(l.filter(func(x): return x.raridade == "lendaria").size(), 1, "uma lendária na zona %d" % z)

func test_mundo_e_loja_coerentes():
	var d = MK.carregar_dados()
	for c in d.mundo.cidades: afirmar(MK.cidade(d, c.id).has("tem_doca"), "%s sem economia" % c.id)
	igual(d.mundo.fossas.size(), 4, "4 fossas"); igual(d.mundo.ilhotas.size(), 5, "5 ilhotas")
	igual(d.mundo.naufragios.size(), 3, "3 naufrágios")
	for m in d.loja.melhorias.values(): igual(m.niveis.size(), m.precos.size(), "níveis e preços")
	for f in d.mundo.fossas:
		var dist = Vector2(f.centro[0], f.centro[1]).length()
		afirmar(dist >= 9000 and dist <= 22000, "%s entre 9.000 e 22.000" % f.id)
