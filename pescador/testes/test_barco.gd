extends "res://testes/caso_teste.gd"
const N = preload("res://logica/navegacao.gd")

func _barco():
	return load("res://cenas/Barco.tscn").instantiate()

func _nada() -> Dictionary: return {"subir": false, "descer": false, "virar": 0.0, "vela": false}

func _passos(b, n: int, entrada := {}) -> void:
	for i in n:
		var e := _nada(); e.merge(entrada, true)
		b.passo(0.1, e, 0.0, 1.0, 0.0)

func test_marchas_sobem_e_descem_no_limite():
	var b = _barco()
	igual(b.marcha, N.MARCHA_PARADO, "começa parado")
	_passos(b, 4, {"subir": true}); igual(b.marcha, 4, "máxima")
	_passos(b, 1, {"subir": true}); igual(b.marcha, 4, "não passa da máxima")
	_passos(b, 5, {"descer": true}); igual(b.marcha, 0, "ré")
	b.free()

func test_passo_gasta_combustivel_e_acelera():
	var b = _barco(); b.marcha = 4
	_passos(b, 10)
	perto(b.combustivel, 99.2, 0.01, "0,8 por segundo na máxima")
	afirmar(b.vel > 0.0, "acelerou")
	afirmar(b.velocity.x > b.vel * 0.9, "anda para a frente (proa em +x) com a deriva: %s" % str(b.velocity))
	b.free()

func test_sem_combustivel_o_motor_para():
	var b = _barco(); b.marcha = 4; b.combustivel = 0.05; b.vel = 100.0
	_passos(b, 10)
	igual(b.combustivel, 0.0, "nunca negativo")
	afirmar(b.vel < 100.0, "perdeu velocidade: %f" % b.vel)
	b.free()

func test_atracado_nao_se_move():
	var b = _barco(); b.atracado = true; b.marcha = 4
	_passos(b, 10, {"subir": true})
	igual(b.velocity, Vector2.ZERO, "parado no cais"); igual(b.combustivel, 100.0, "não gastou")
	b.free()

func test_vela_alterna():
	var b = _barco()
	_passos(b, 1, {"vela": true}); afirmar(b.vela_aberta, "abriu")
	_passos(b, 1, {"vela": true}); afirmar(not b.vela_aberta, "fechou")
	b.free()

func test_vira_com_o_leme():
	var b = _barco()
	_passos(b, 10, {"virar": 1.0})
	perto(b.rotation, 1.6, 1e-6, "1,6 rad/s com o leme base")
	b.free()
