extends "res://testes/caso_teste.gd"
const E = preload("res://logica/especies.gd")
const PP = preload("res://cenas/ui/painel_porao.gd")
const PC = preload("res://cenas/ui/painel_catalogo.gd")
const MU = preload("res://cenas/ui/medidor_ui.gd")

var l
func _init(): l = E.carregar()

func _itens() -> Array:
	return [E.exemplar_com_f(E.por_id(l, "tainha"), 0.5), E.exemplar_com_f(E.por_id(l, "sardinha"), 0.1),
		{"carga": true, "missao": "m1", "nome": "Caixa de gelo", "volume": 20.0}]

func test_porao_lista_os_exemplares():
	var p = PP.new(); p.mostrar(_itens(), l, 63.2, 100.0, {})
	igual(p.titulo(), "Porão 63/100 L", "título")
	var linhas: Array = p.linhas()
	igual(linhas.size(), 3, "3 linhas")
	afirmar(linhas[0].contains("Tainha") and linhas[0].contains("55 cm") and linhas[0].contains("(M)"), linhas[0])
	afirmar(linhas[0].contains(" L") and linhas[0].contains("R$"), "litros e valor: %s" % linhas[0])
	afirmar(linhas[2].contains("Caixa de gelo") and linhas[2].contains("carga"), linhas[2])
	igual(p.botoes_soltar(), 2, "carga de missão não tem botão de soltar")
	p.free()

func test_porao_emite_soltar_e_mostra_pendente():
	var p = PP.new(); var pend := E.exemplar_com_f(E.por_id(l, "robalo"), 0.8)
	p.mostrar(_itens(), l, 99.0, 100.0, pend)
	afirmar(p.texto_pendente().contains("Robalo"), "mostra o peixe na mão: %s" % p.texto_pendente())
	var recebido := []
	p.soltar.connect(func(i): recebido.append(i))
	p.apertar_soltar(1)
	igual(recebido, [1], "emitiu o índice do porão")
	var vazio = PP.new(); vazio.mostrar([], l, 0.0, 100.0, {})
	afirmar(vazio.texto_vazio().contains("vazio"), "porão vazio avisa"); igual(vazio.texto_pendente(), "", "sem pendente")
	p.free(); vazio.free()

func test_catalogo_tem_18_espacos():
	var c = PC.new()
	c.mostrar(l, {"tainha": {"qtd": 3, "recorde_cm": 61.4, "classe": "M", "titulo": false},
			"mero": {"qtd": 1, "recorde_cm": 240.0, "classe": "Recorde", "titulo": true}})
	igual(c.celulas().size(), 18, "18 espaços")
	igual(c.titulo(), "Catálogo — 2 de 18 espécies", "título")
	var por_id: Dictionary = c.textos_por_id()
	afirmar(por_id.sardinha.contains("?") and not por_id.sardinha.contains("Sardinha"), "desconhecida: %s" % por_id.sardinha)
	afirmar(por_id.tainha.contains("Tainha") and por_id.tainha.contains("3") and por_id.tainha.contains("61 cm"), por_id.tainha)
	afirmar(por_id.mero.contains("★"), "título de troféu: %s" % por_id.mero)
	c.free()

func test_medidor_posiciona_ponteiro_e_faixas():
	var m = MU.new(); m.size = Vector2(600, 40)
	m.definir({"pos": 0.25, "verde": 0.30, "dourada": 0.075, "centro": 0.5})
	perto(m.x_ponteiro(), 150.0, 1e-3, "ponteiro a 25%")
	perto(m.faixa("verde").x, 210.0, 1e-3, "verde começa em 35%"); perto(m.faixa("verde").y, 390.0, 1e-3, "e acaba em 65%")
	perto(m.faixa("dourada").x, 277.5, 1e-3, "dourada no meio")
	afirmar(m.visible, "visível durante a fisgada")
	m.definir({}); afirmar(not m.visible, "some sem fisgada")
	m.free()
