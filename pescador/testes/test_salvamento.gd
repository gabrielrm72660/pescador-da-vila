extends "res://testes/caso_teste.gd"
const EST = preload("res://autoload/Estado.gd")
const SAL = preload("res://autoload/Salvamento.gd")
const TESTE = "user://teste_save.json"

func _limpar():
	for c in [TESTE, TESTE + ".bak", TESTE + ".tmp"]:
		if FileAccess.file_exists(c): DirAccess.remove_absolute(ProjectSettings.globalize_path(c))

func test_novo_jogo():
	var e = EST.new(); e.novo_jogo()
	igual(e.dinheiro, 50, "carteira inicial"); igual(e.varas, ["rasa"], "vara rasa")
	perto(e.porao.capacidade, 100.0, 1e-6, "porão 100 L"); igual(e.cidade, "porto_farol", "começa no porto")
	e.free()

func test_ida_e_volta():
	_limpar(); var e = EST.new(); e.novo_jogo(); var s = SAL.new()
	e.dinheiro = 777; e.porao.adicionar({"especie": "atum", "tam": 150.0, "f": 0.5, "classe": "M",
			"peso": 50.0, "volume": 25.0, "valor": 150})
	e.catalogo.registrar({"especie": "atum", "tam": 150.0, "classe": "M"})
	afirmar(s.salvar(e.para_dict(), TESTE), "salvou")
	var e2 = EST.new(); e2.de_dict(s.carregar(TESTE))
	igual(e2.dinheiro, 777, "dinheiro"); igual(e2.porao.peixes().size(), 1, "porão")
	igual(e2.catalogo.entradas.atum.qtd, 1, "catálogo")
	e.free(); e2.free(); s.free(); _limpar()

func test_arquivo_inexistente():
	_limpar(); var s = SAL.new(); igual(s.carregar(TESTE), {}, "vazio"); s.free()

func test_corrompido_vira_bak():
	_limpar(); var f = FileAccess.open(TESTE, FileAccess.WRITE); f.store_string("{isto não é json"); f.close()
	var s = SAL.new(); igual(s.carregar(TESTE), {}, "começa do zero")
	afirmar(FileAccess.file_exists(TESTE + ".bak"), "guardou .bak"); s.free(); _limpar()

func test_versao_futura_vira_bak():
	_limpar(); var s = SAL.new(); s.salvar({"versao": 99}, TESTE)
	igual(s.carregar(TESTE), {}, "não abre versão futura")
	afirmar(FileAccess.file_exists(TESTE + ".bak"), "guardou .bak"); s.free(); _limpar()

func test_campos_ausentes_usam_padrao():
	var e = EST.new(); e.de_dict({"versao": 1, "dinheiro": 5})
	igual(e.dinheiro, 5, "lido"); igual(e.vara, "rasa", "padrão"); e.free()
