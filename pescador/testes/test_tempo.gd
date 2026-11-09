extends "res://testes/caso_teste.gd"
const T = preload("res://logica/tempo.gd")

func test_fase_tem_amanhecer_e_meio_dia():
	perto(T.fase_do_dia(0.0), 0.0, 1e-9, "meia-noite")
	perto(T.fase_do_dia(75.0), 0.5, 1e-9, "meio-dia")
	afirmar(T.fase_do_dia(37.5) > 0.25, "o dia se alonga: às 37,5 s o sol já nasceu")

func test_brilho_e_noite():
	perto(T.brilho(T.tempo_da_fase(0.5)), 1.0, 1e-6, "meio-dia claro")
	perto(T.brilho(0.0), 0.12, 1e-6, "meia-noite escura")
	afirmar(T.eh_noite(0.0), "meia-noite é noite"); afirmar(not T.eh_noite(75.0), "meio-dia não é")
	perto(T.noite(75.0), 0.0, 1e-6, "noite zero ao meio-dia")

func test_dia_conta_ciclos():
	igual(T.dia_de(0.0), 1, "dia 1"); igual(T.dia_de(150.0), 2, "dia 2"); igual(T.dia_de(449.0), 3, "dia 3")

func test_hora_texto():
	igual(T.hora_texto(0.0), "00:00", "meia-noite")
	igual(T.hora_texto(T.tempo_da_fase(0.25)), "06:00", "amanhecer")

func test_t_inicial_e_manha():
	perto(T.fase_do_dia(T.t_inicial()), 0.3, 1e-3, "começo da manhã")
	afirmar(not T.eh_noite(T.t_inicial()), "não é noite")
