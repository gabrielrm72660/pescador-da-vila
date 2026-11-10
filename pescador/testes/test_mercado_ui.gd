extends "res://testes/caso_teste.gd"
const E = preload("res://logica/especies.gd")
const MK = preload("res://logica/mercado.gd")
const TM = preload("res://cenas/ui/tela_mercado.gd")
const PM = preload("res://cenas/ui/painel_missoes.gd")

var d; var l
func _init(): d = MK.carregar_dados(); l = E.carregar()

func _abrir(cidade := "porto_farol", dinheiro := 5000):
	var e = load("res://autoload/Estado.gd").new(); e.novo_jogo(); e.cidade = cidade; e.dinheiro = dinheiro
	var r := RandomNumberGenerator.new(); r.seed = 2
	var t = TM.new(); t.abrir(e, d, l, r)
	return [t, e]

func _fim(par): par[0].free(); par[1].free()

func test_abas_e_doca_so_no_porto():
	var p = _abrir(); var t = p[0]
	afirmar(t.titulo().contains("Porto do Farol") and t.titulo().contains("R$ 5000"), t.titulo())
	for k in ["aba:vender", "aba:missoes", "aba:balcao", "aba:doca", "fechar"]: afirmar(t.tem(k), "botão %s" % k)
	_fim(p)
	var q = _abrir("vila_arraias"); afirmar(not q[0].tem("aba:doca"), "sem doca na Vila das Arraias"); _fim(q)

func test_vender_um_e_tudo():
	var p = _abrir("porto_farol", 0); var t = p[0]; var e = p[1]
	var a := E.exemplar_com_f(E.por_id(l, "tainha"), 0.5); var b := E.exemplar_com_f(E.por_id(l, "robalo"), 0.5)
	e.porao.adicionar(a); e.porao.adicionar(b); e.porao.adicionar({"carga": true, "missao": "x", "volume": 5.0})
	t.mostrar_aba("vender")
	afirmar(t.textos().any(func(s): return s.contains("Tainha") and s.contains("R$ %d" % a.valor)), "lista com preço: %s" % str(t.textos()))
	afirmar(t.tem("vender:0") and t.tem("vender:1") and not t.tem("vender:2"), "carga de missão não tem botão de vender")
	t.apertar("vender:0")
	igual(e.dinheiro, int(a.valor), "vendeu a tainha"); afirmar(t.mensagem().contains("R$"), t.mensagem())
	afirmar(t.titulo().contains("R$ %d" % a.valor), "o título acompanha a carteira")
	t.apertar("vender_tudo")
	igual(e.dinheiro, int(a.valor) + int(b.valor), "vendeu o resto"); igual(e.porao.itens.size(), 1, "sobrou a carga")
	afirmar(not t.tem("vender_tudo"), "sem peixe não há o que vender")
	_fim(p)

func test_balcao():
	var p = _abrir("porto_farol", 700); var t = p[0]; var e = p[1]
	t.mostrar_aba("balcao")
	afirmar(t.tem("comprar:vara_profunda") and t.tem("comprar:agua") and not t.tem("comprar:vara_abissal"), "itens da cidade")
	afirmar(not t.tem("comprar:conserto_lanterna"), "lanterna inteira: sem conserto à venda")
	t.apertar("comprar:vara_profunda"); afirmar("profunda" in e.varas, "comprou a vara"); igual(e.dinheiro, 100, "pagou")
	afirmar(not t.tem("comprar:vara_profunda"), "vara comprada sai da lista")
	t.apertar("comprar:rede"); afirmar(t.mensagem().contains("insuficiente"), t.mensagem()); igual(e.dinheiro, 100, "não cobrou")
	e.combustivel = 80.0; t.mostrar_aba("balcao")
	afirmar(t.textos().any(func(s): return s.contains("Encher o tanque") and s.contains("R$ 40")), "preço de encher: %s" % str(t.textos()))
	t.apertar("comprar:combustivel"); perto(e.combustivel, 100.0, 1e-6, "tanque cheio"); igual(e.dinheiro, 60, "20 × R$ 2")
	_fim(p)
	var q = _abrir("ponta_negra"); q[0].mostrar_aba("balcao")
	afirmar(q[0].tem("comprar:vara_abissal"), "vara abissal só em Ponta Negra"); _fim(q)

func test_doca_seca():
	var p = _abrir("porto_farol", 500); var t = p[0]; var e = p[1]
	t.mostrar_aba("doca")
	afirmar(t.textos().any(func(s): return s.contains("Porão") and s.contains("200") and s.contains("R$ 400")), "próximo nível e preço: %s" % str(t.textos()))
	t.apertar("melhorar:porao"); perto(e.porao.capacidade, 200.0, 1e-6, "porão maior"); igual(e.dinheiro, 100, "pagou")
	t.apertar("melhorar:motor"); afirmar(t.mensagem().contains("insuficiente"), t.mensagem())
	afirmar(not t.tem("reparar"), "casco inteiro: nada a reparar")
	e.casco = 90.0; t.mostrar_aba("doca"); t.apertar("reparar"); perto(e.casco, 100.0, 1e-6, "reparou"); igual(e.dinheiro, 70, "10 × R$ 3")
	e.dinheiro = 9999; e.melhorias["tanque"] = 1; t.mostrar_aba("doca")
	afirmar(not t.tem("melhorar:tanque") and t.textos().any(func(s): return s.contains("Tanque") and s.contains("máximo")), "no máximo não tem botão")
	_fim(p)

func test_missoes_aceitar_e_entregar():
	var p = _abrir(); var t = p[0]; var e = p[1]
	e.missoes.ofertas["porto_farol"] = {"dia": 1, "lista": [{"id": "t1", "tipo": "encomenda", "cidade": "porto_farol",
			"especie": "tainha", "qtd": 1, "classe_min": "P", "prazo_dia": 3, "recompensa_xp": 20}]}
	t.mostrar_aba("missoes")
	afirmar(t.tem("aceitar:t1") and t.textos().any(func(s): return s.contains("Tainha")), "oferta na lista")
	t.apertar("aceitar:t1"); igual(e.missoes.ativas.size(), 1, "aceitou"); afirmar(not t.tem("aceitar:t1"), "saiu das ofertas")
	afirmar(not t.tem("entregar:t1"), "sem o peixe não dá para entregar")
	e.porao.adicionar(E.exemplar_com_f(E.por_id(l, "tainha"), 0.5)); t.mostrar_aba("missoes")
	var antes: int = e.dinheiro
	t.apertar("entregar:t1"); afirmar(e.dinheiro > antes and e.missoes.ativas.is_empty(), "entregou e recebeu")
	afirmar(t.mensagem().contains("R$") and t.mensagem().contains("XP"), t.mensagem())
	_fim(p)

func test_fechar_emite_sinal():
	var p = _abrir(); var ouviu := [0]
	p[0].fechar.connect(func(): ouviu[0] += 1)
	p[0].apertar("fechar"); igual(ouviu[0], 1, "sinal fechar")
	_fim(p)

func test_painel_de_missoes_ativas():
	var e = load("res://autoload/Estado.gd").new(); e.novo_jogo()
	var pm = PM.new(); pm.mostrar(e, d, l, Vector2.ZERO)
	afirmar(pm.textos()[0].contains("Nenhuma missão"), "vazio: %s" % str(pm.textos()))
	e.missoes.ativas = [{"id": "t1", "tipo": "encomenda", "cidade": "porto_farol", "especie": "tainha", "qtd": 3,
			"classe_min": "P", "prazo_dia": 2, "recompensa_xp": 20}]
	e.porao.adicionar(E.exemplar_com_f(E.por_id(l, "tainha"), 0.5))
	pm.mostrar(e, d, l, Vector2.ZERO)
	igual(pm.titulo(), "Missões — 1 de 3", "título")
	afirmar(pm.textos()[0].contains("Tainha") and pm.textos()[0].contains("1/3") and pm.textos()[0].contains("1 dia"), pm.textos()[0])
	pm.free(); e.free()
