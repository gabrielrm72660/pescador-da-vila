extends RefCounted
## Base dos testes: cada arquivo testes/test_*.gd estende este e usa as asserções abaixo.

var falhas: Array[String] = []


func afirmar(cond: bool, msg: String) -> void:
	if not cond:
		falhas.append(msg)


func igual(obtido, esperado, msg: String) -> void:
	if typeof(obtido) != typeof(esperado) and not (_numero(obtido) and _numero(esperado)):
		falhas.append("%s: esperado %s, obtido %s" % [msg, str(esperado), str(obtido)])
	elif obtido != esperado:
		falhas.append("%s: esperado %s, obtido %s" % [msg, str(esperado), str(obtido)])


func perto(obtido: float, esperado: float, tol: float, msg: String) -> void:
	if absf(obtido - esperado) > tol:
		falhas.append("%s: esperado %s ± %s, obtido %s" % [msg, esperado, tol, obtido])


func _numero(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
