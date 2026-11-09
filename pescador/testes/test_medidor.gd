extends "res://testes/caso_teste.gd"
const M = preload("res://logica/medidor.gd")
const V = preload("res://logica/varas.gd")

func test_posicao_triangular():
	var m = M.new(2.0, 0.3, 0.075)
	perto(m.posicao(0.0), 0.0, 1e-6, "início"); perto(m.posicao(1.0), 1.0, 1e-6, "meio")
	perto(m.posicao(0.5), 0.5, 1e-6, "subindo"); perto(m.posicao(1.5), 0.5, 1e-6, "descendo")
	perto(m.posicao(2.5), 0.5, 1e-6, "repete")

func test_resultado_por_faixa():
	var m = M.new(2.0, 0.3, 0.075)      # verde 0.35–0.65, dourada 0.4625–0.5375
	igual(m.resultado(0.5), "dourada", "no centro")      # posição 0.5
	igual(m.resultado(0.4), "verde", "dentro da verde")  # posição 0.4
	igual(m.resultado(0.2), "erro", "fora")              # posição 0.2
	igual(m.resultado(0.35), "verde", "borda inclusa")   # posição 0.35

func test_centro_deslocado():
	var m = M.new(2.0, 0.2, 0.05, 0.8)
	igual(m.resultado(0.8), "dourada", "centro 0.8"); igual(m.resultado(0.5), "erro", "0.5 fora")

func test_parametros_da_spec():
	perto(M.periodo_de("comum"), 1.6, 1e-6, "comum"); perto(M.periodo_de("lendaria"), 0.8, 1e-6, "lendária")
	perto(M.largura_verde("comum", 0.0, 0), 0.30, 1e-6, "base")
	perto(M.largura_verde("lendaria", 1.0, 0), 0.30 * 0.45 * 0.65, 1e-6, "lendária grande")
	perto(M.largura_verde("comum", 0.0, 5), 0.30 * 1.4, 1e-6, "Pescador 5")

func test_varas():
	afirmar(V.alcanca("rasa", 0) and not V.alcanca("rasa", 1), "rasa")
	afirmar(V.alcanca("profunda", 1) and not V.alcanca("profunda", 2), "profunda")
	afirmar(V.alcanca("abissal", 2) and V.alcanca("abissal", 0), "abissal")
	igual(V.melhor(["rasa", "abissal", "profunda"]), "abissal", "melhor vara")
	afirmar(not V.alcanca("inexistente", 0), "vara desconhecida não alcança nada")
