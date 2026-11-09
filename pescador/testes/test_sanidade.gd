extends "res://testes/caso_teste.gd"

func test_asercoes_basicas():
	afirmar(true, "afirmar verdadeiro")
	igual(2 + 2, 4, "soma")
	perto(0.1 + 0.2, 0.3, 0.0001, "ponto flutuante")
