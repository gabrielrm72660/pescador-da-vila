extends SceneTree
## Executor dos testes: godot --headless --path pescador --script res://testes/rodar_testes.gd
## Roda um passo por quadro: se um teste der erro de execução (que interrompe a função),
## o quadro seguinte o registra como FALHA e segue, em vez de travar o executor.

const PASTA := "res://testes/"

var _fila: Array = []        # passos: ["arquivo", nome, script] ou ["teste", nome, caso, metodo]
var _em_andamento: Array = []
var _total := 0
var _falhas := 0


func _init() -> void:
	var arquivos: Array[String] = []
	for nome in DirAccess.get_files_at(PASTA):
		if nome.begins_with("test_") and nome.ends_with(".gd"):
			arquivos.append(nome)
	arquivos.sort()
	for nome in arquivos:
		_fila.append(["arquivo", nome])


func _process(_delta: float) -> bool:
	if not _em_andamento.is_empty():
		_registrar_falha(_em_andamento, "erro de execução (veja o SCRIPT ERROR acima)")
		_em_andamento = []
	if _fila.is_empty():
		print("%d testes, %d falhas" % [_total, _falhas])
		quit(1 if _falhas > 0 or _total == 0 else 0)
		return true
	var passo: Array = _fila.pop_front()
	_em_andamento = passo
	if passo[0] == "arquivo":
		_abrir_arquivo(passo[1])
	else:
		_rodar_teste(passo[1], passo[2], passo[3])
	_em_andamento = []
	return false


func _abrir_arquivo(nome: String) -> void:
	var script = load(PASTA + nome)
	if script == null or not script.can_instantiate():
		_registrar_falha(["arquivo", nome], "não foi possível carregar (erro de sintaxe ou preload ausente)")
		return
	var caso = script.new()
	var novos: Array = []
	for m in script.get_script_method_list():
		if String(m.name).begins_with("test_"):
			novos.append(["teste", nome, caso, String(m.name)])
	_fila = novos + _fila


func _rodar_teste(nome: String, caso, metodo: String) -> void:
	_total += 1
	caso.falhas = [] as Array[String]
	caso.call(metodo)
	if caso.falhas.is_empty():
		print("OK %s::%s" % [nome, metodo])
	else:
		_falhas += 1
		print("FALHA %s::%s: %s" % [nome, metodo, "; ".join(caso.falhas)])


func _registrar_falha(passo: Array, motivo: String) -> void:
	if passo[0] == "arquivo":
		_total += 1
		_falhas += 1
		print("FALHA %s: %s" % [passo[1], motivo])
	else:
		_falhas += 1
		print("FALHA %s::%s: %s" % [passo[1], passo[3], motivo])
