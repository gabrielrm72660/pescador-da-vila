extends Node
## Salvamento em JSON (spec 12). Registrado como autoload "Salvamento".

const CAMINHO := "user://save.json"
const VERSAO := 1


func salvar(dados: Dictionary, caminho := CAMINHO) -> bool:
	var tmp := caminho + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Não consegui gravar %s" % tmp)
		return false
	f.store_string(JSON.stringify(dados, "\t"))
	f.close()
	var destino := ProjectSettings.globalize_path(caminho)
	if FileAccess.file_exists(caminho):
		DirAccess.remove_absolute(destino)
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), destino) == OK


func carregar(caminho := CAMINHO) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var leitor := JSON.new()
	var d = null
	if leitor.parse(FileAccess.get_file_as_string(caminho)) == OK:
		d = leitor.data
	if typeof(d) != TYPE_DICTIONARY or int(d.get("versao", 0)) > VERSAO:
		_guardar_bak(caminho)
		return {}
	return d


func _guardar_bak(caminho: String) -> void:
	var bak := ProjectSettings.globalize_path(caminho + ".bak")
	if FileAccess.file_exists(caminho + ".bak"):
		DirAccess.remove_absolute(bak)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho), bak)
