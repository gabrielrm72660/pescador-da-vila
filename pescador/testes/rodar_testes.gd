extends SceneTree
## Executor dos testes: godot --headless --path pescador --script res://testes/rodar_testes.gd


func _init() -> void:
	var pasta := "res://testes/"
	var arquivos: Array[String] = []
	for nome in DirAccess.get_files_at(pasta):
		if nome.begins_with("test_") and nome.ends_with(".gd"):
			arquivos.append(nome)
	arquivos.sort()
	var total := 0
	var falhas := 0
	for nome in arquivos:
		var script: GDScript = load(pasta + nome)
		if script == null:
			print("FALHA %s: não foi possível carregar" % nome)
			falhas += 1
			total += 1
			continue
		var caso = script.new()
		for m in script.get_script_method_list():
			var metodo: String = m.name
			if not metodo.begins_with("test_"):
				continue
			total += 1
			caso.falhas = [] as Array[String]
			caso.call(metodo)
			if caso.falhas.is_empty():
				print("OK %s::%s" % [nome, metodo])
			else:
				falhas += 1
				print("FALHA %s::%s: %s" % [nome, metodo, "; ".join(caso.falhas)])
	print("%d testes, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 or total == 0 else 0)
