extends "res://testes/caso_teste.gd"
const E = preload("res://logica/especies.gd")
const MK = preload("res://logica/mercado.gd")
const MI = preload("res://logica/missoes.gd")

var d; var l
func _init(): d = MK.carregar_dados(); l = E.carregar()

func _est():
	var e = load("res://autoload/Estado.gd").new(); e.novo_jogo(); return e
func _rng(s := 4) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_comprar_usa_o_estado_de_verdade():
	var e = _est(); e.dinheiro = 1000
	igual(e.comprar(d, "vara_profunda", 1), "ok", "comprou"); afirmar("profunda" in e.varas, "tem a vara"); igual(e.dinheiro, 400, "pagou 600")
	igual(e.comprar(d, "vara_profunda", 1), "ja_tem", "não compra duas vezes")
	igual(e.comprar(d, "agua", 3), "ok", "água"); igual(int(e.suprimentos.agua), 5, "2 + 3"); igual(e.dinheiro, 385, "3 × R$ 5")
	e.combustivel = 40.0
	igual(e.comprar(d, "combustivel", 999), "ok", "enche o tanque"); perto(e.combustivel, 100.0, 1e-6, "cheio"); igual(e.dinheiro, 265, "60 × R$ 2")
	igual(e.comprar(d, "rede", 1), "sem_dinheiro", "rede custa 800"); igual(e.dinheiro, 265, "não cobrou")
	igual(e.comprar(d, "vara_abissal", 1), "indisponivel", "abissal só em Ponta Negra")
	e.free()

func test_item_sem_tratamento_nao_cobra():
	var e = _est(); e.dinheiro = 1000
	var dd: Dictionary = d.duplicate(true); dd.loja.balcao["bugiganga"] = 10
	igual(e.comprar(dd, "bugiganga", 1), "indisponivel", "item desconhecido é recusado"); igual(e.dinheiro, 1000, "sem cobrar")
	e.free()

func test_melhorar_porao_atualiza_a_capacidade():
	var e = _est(); e.dinheiro = 2000
	perto(e.porao.capacidade, 100.0, 1e-6, "começa com 100 L")
	igual(e.melhorar(d, "porao"), "ok", "melhorou"); perto(e.porao.capacidade, 200.0, 1e-6, "200 L na hora"); igual(e.dinheiro, 1600, "pagou 400")
	igual(e.melhorar(d, "tanque"), "ok", "tanque"); perto(e.tanque(), 160.0, 1e-6, "tanque maior")
	igual(e.melhorar(d, "tanque"), "maximo", "já no máximo")
	igual(e.melhorar(d, "motor"), "ok", "motor"); igual(e.melhorar(d, "motor"), "sem_dinheiro", "nível 3 custa 3500")
	e.cidade = "vila_arraias"; igual(e.melhorar(d, "leme"), "sem_doca", "doca só no Porto do Farol")
	e.free()

func test_reparar_casco():
	var e = _est(); e.dinheiro = 100; e.casco = 80.0
	igual(e.preco_reparo(d), 60, "20 pontos × R$ 3")
	igual(e.reparar_casco(d), "ok", "reparou"); perto(e.casco, 100.0, 1e-6, "inteiro"); igual(e.dinheiro, 40, "pagou")
	igual(e.reparar_casco(d), "ja_tem", "nada a reparar")
	e.casco = 50.0; igual(e.reparar_casco(d), "sem_dinheiro", "150 > 40")
	e.free()

func test_vender():
	var e = _est()
	var a := E.exemplar_com_f(E.por_id(l, "tainha"), 0.5); var b := E.exemplar_com_f(E.por_id(l, "siri_azul"), 0.5)
	e.porao.adicionar(a); e.porao.adicionar(b); e.porao.adicionar({"carga": true, "missao": "x", "volume": 10.0})
	var antes: int = e.dinheiro
	igual(e.preco_de(d, l, 1), int(b.valor), "preço normal no Porto do Farol")
	e.cidade = "vila_arraias"; igual(e.preco_de(d, l, 1), roundi(b.valor * 1.4), "+40% por crustáceo na Vila das Arraias")
	var ganho: int = e.vender(d, l, [0])
	igual(ganho, int(a.valor), "vendeu a tainha"); igual(e.dinheiro, antes + ganho, "entrou na carteira"); igual(e.porao.itens.size(), 2, "saiu do porão")
	e.vender_tudo(d, l)
	igual(e.porao.itens.size(), 1, "a carga de missão não é vendida"); afirmar(e.porao.itens[0].get("carga", false), "carga fica")
	e.free()

func test_ofertas_por_cidade_e_por_dia():
	var e = _est()
	var o1: Array = e.ofertas_de(d, l, _rng())
	igual(o1.size(), 3, "3 ofertas")
	var o2: Array = e.ofertas_de(d, l, _rng(99))
	igual(o2.map(func(m): return m.id), o1.map(func(m): return m.id), "no mesmo dia são as mesmas")
	e.dia = 2
	afirmar(e.ofertas_de(d, l, _rng())[0].id != o1[0].id, "no dia seguinte renovam")
	e.cidade = "ponta_negra"
	afirmar(e.ofertas_de(d, l, _rng())[0].id.begins_with("ponta_negra"), "cada cidade tem as suas")
	e.free()

func test_aceitar_e_entregar_encomenda():
	var e = _est()
	var m := {"id": "t1", "tipo": "encomenda", "cidade": "porto_farol", "especie": "tainha", "qtd": 2, "classe_min": "P",
			"prazo_dia": 3, "recompensa_xp": 20}
	e.missoes.ofertas["porto_farol"] = {"dia": 1, "lista": [m]}
	igual(e.aceitar_missao(d, "t1"), "ok", "aceitou"); igual(e.missoes.ativas.size(), 1, "ativa")
	igual(e.ofertas_de(d, l, _rng()).size(), 0, "saiu das ofertas")
	igual(e.entregar_missao(d, l, "t1").motivo, "incompleta", "ainda sem peixe")
	e.porao.adicionar(E.exemplar_com_f(E.por_id(l, "tainha"), 0.5)); e.porao.adicionar(E.exemplar_com_f(E.por_id(l, "tainha"), 0.6))
	var antes: int = e.dinheiro
	var r: Dictionary = e.entregar_missao(d, l, "t1")
	afirmar(r.ok and r.reais > 0, "entregou: %s" % str(r)); igual(e.dinheiro, antes + int(r.reais), "pagou"); igual(e.xp, 20, "XP")
	igual(e.missoes.ativas.size(), 0, "saiu das ativas"); igual(e.porao.itens.size(), 0, "peixes entregues")
	igual(e.aceitar_missao(d, "nao_existe"), "indisponivel", "oferta inexistente")
	e.free()

func test_limite_de_ativas_e_entrega_sem_espaco():
	var e = _est(); var lista := []
	for i in 4: lista.append({"id": "e%d" % i, "tipo": "exploracao", "cidade": "porto_farol", "alvo": "x", "nome_alvo": "X",
			"pos": [9000, 9000], "recompensa": 150, "recompensa_xp": 25, "prazo_dia": -1})
	lista.append({"id": "c1", "tipo": "entrega", "cidade": "ponta_negra", "destino": "ponta_negra", "volume": 500.0,
			"recompensa": 300, "recompensa_xp": 15, "prazo_dia": 3})
	e.missoes.ofertas["porto_farol"] = {"dia": 1, "lista": lista}
	igual(e.aceitar_missao(d, "c1"), "sem_espaco", "a carga não cabe no porão")
	for i in 3: igual(e.aceitar_missao(d, "e%d" % i), "ok", "aceita até 3")
	igual(e.aceitar_missao(d, "e3"), "limite", "quarta é recusada")
	e.free()

func test_exploracao_e_vencimento():
	var e = _est()
	e.missoes.ativas = [{"id": "x1", "tipo": "exploracao", "cidade": "porto_farol", "alvo": "n", "nome_alvo": "Naufrágio",
			"pos": [5000, 5000], "recompensa": 150, "recompensa_xp": 25, "prazo_dia": -1},
		{"id": "c1", "tipo": "entrega", "cidade": "ponta_negra", "destino": "ponta_negra", "volume": 30.0, "recompensa": 300,
			"recompensa_xp": 15, "prazo_dia": 2}]
	e.porao.adicionar({"carga": true, "missao": "c1", "volume": 30.0})
	igual(e.marcar_exploracao(Vector2(0, 0)), [], "longe: nada")
	igual(e.marcar_exploracao(Vector2(5100, 5000)).size(), 1, "achou"); afirmar("n" in e.pontos_achados, "ponto marcado")
	igual(e.marcar_exploracao(Vector2(5100, 5000)), [], "só avisa uma vez")
	e.dia = 3
	var venc: Array = e.expirar_missoes()
	igual(venc.size(), 1, "a entrega venceu"); igual(e.porao.itens.size(), 0, "a carga saiu do porão"); igual(e.missoes.ativas.size(), 1, "a exploração fica")
	afirmar(e.entregar_missao(d, l, "x1").ok, "exploração achada é paga na cidade")
	e.free()

func test_textos_das_missoes():
	var enc := {"id": "a", "tipo": "encomenda", "cidade": "porto_farol", "especie": "tainha", "qtd": 3, "classe_min": "M", "prazo_dia": 4}
	var t: String = MI.descricao(enc, l, d)
	afirmar(t.contains("3") and t.contains("Tainha") and t.contains("M"), t)
	var tro := {"id": "b", "tipo": "trofeu", "cidade": "porto_farol", "especie": "robalo", "tam_min": 90.4, "prazo_dia": 4}
	afirmar(MI.descricao(tro, l, d).contains("Robalo") and MI.descricao(tro, l, d).contains("90 cm"), MI.descricao(tro, l, d))
	var ent := {"id": "c", "tipo": "entrega", "cidade": "ponta_negra", "destino": "ponta_negra", "volume": 40.0, "recompensa": 500, "prazo_dia": 2}
	afirmar(MI.descricao(ent, l, d).contains("Ponta Negra") and MI.descricao(ent, l, d).contains("40 L"), MI.descricao(ent, l, d))
	var ex := {"id": "e", "tipo": "exploracao", "cidade": "porto_farol", "nome_alvo": "Naufrágio Distante", "pos": [1, 1], "recompensa": 150, "prazo_dia": -1}
	afirmar(MI.descricao(ex, l, d).contains("Naufrágio Distante"), MI.descricao(ex, l, d))
	var p = load("res://logica/porao.gd").new(100.0); p.adicionar(E.exemplar_com_f(E.por_id(l, "tainha"), 0.5))
	var tp: String = MI.texto_progresso(enc, p, Vector2.ZERO, 3)
	afirmar(tp.contains("1/3") and tp.contains("1 dia"), tp)
	afirmar(MI.texto_progresso(ex, p, Vector2.ZERO, 3).contains("sem prazo"), "exploração não tem prazo")
	afirmar(MI.texto_progresso(enc, p, Vector2.ZERO, 5).contains("vencida"), "vencida")
