extends "res://testes/caso_teste.gd"
const N = preload("res://logica/navegacao.gd")

func test_vel_motor_por_nivel():
	igual(N.vel_motor(1), 150.0, "n1"); igual(N.vel_motor(2), 185.0, "n2"); igual(N.vel_motor(3), 220.0, "n3")
	igual(N.vel_motor(0), 150.0, "abaixo"); igual(N.vel_motor(9), 220.0, "acima")

func test_marcha_maxima_sem_vela():
	perto(N.velocidade_alvo(4, 2, true, false, false, 1.0, 0.0, 0.0), 185.0, 1e-6, "máx n2")

func test_vela_a_favor_e_contra():
	perto(N.vel_vela(false, 1.0, 0.0, 0.0), 95.0, 1e-6, "a favor")
	perto(N.vel_vela(false, 1.0, 0.0, PI), 9.5, 1e-6, "contra")
	perto(N.vel_vela(true, 1.0, 0.0, 0.0), 123.5, 1e-6, "vela grande")

func test_motor_e_vela_somam_ate_o_teto():
	perto(N.velocidade_alvo(3, 1, true, true, false, 1.0, 0.0, 0.0), 150.0, 1e-6, "teto do motor")
	perto(N.velocidade_alvo(2, 1, true, true, false, 1.0, 0.0, PI), 37.5 + 9.5, 1e-6, "¼ + vela contra")

func test_sem_combustivel_so_vela():
	perto(N.velocidade_alvo(4, 1, false, false, false, 1.0, 0.0, 0.0), 0.0, 1e-6, "parado")
	perto(N.velocidade_alvo(4, 1, false, true, false, 1.0, 0.0, 0.0), 95.0, 1e-6, "só vela")

func test_re_nao_soma_vela():
	perto(N.velocidade_alvo(0, 1, true, true, false, 1.0, 0.0, 0.0), -30.0, 1e-6, "ré lenta")

func test_consumo_proporcional():
	perto(N.consumo(4, 1.0), 0.8, 1e-9, "máx"); perto(N.consumo(3, 1.0), 0.4, 1e-9, "½")
	perto(N.consumo(1, 1.0), 0.0, 1e-9, "parado"); perto(N.consumo(4, 1.0, 2), 0.688, 1e-9, "motorista 2")
	perto(N.consumo(0, 1.0), 0.16, 1e-9, "ré gasta pouco")

func test_acelerar_aproxima():
	perto(N.acelerar(0.0, 100.0, 0.5), 65.0, 1e-9, "meio segundo")
	perto(N.acelerar(0.0, 100.0, 5.0), 100.0, 1e-9, "não passa do alvo")

func test_giro_e_deriva():
	igual(N.taxa_giro(false), 1.6, "leme base"); igual(N.taxa_giro(true), 2.0, "leme melhor")
	var d: Vector2 = N.deriva(0.0, 0.0, 1.0)
	perto(d.x, 16.0, 1e-6, "corrente 10 + vento 6"); perto(d.y, 0.0, 1e-6, "sem lateral")

func test_vento_gira_devagar():
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var v = N.Vento.new(rng); var a0: float = v.ang
	for i in 100:
		v.atualizar(0.1, rng)
		afirmar(v.tm > 0.0 and v.tm <= 12.0, "tm na faixa")
	afirmar(absf(v.ang - a0) <= 0.9 + 1e-9, "giro limitado: %f" % absf(v.ang - a0))
