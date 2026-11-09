extends RefCounted
## Catálogo de espécies e recordes (spec 12).

var entradas: Dictionary = {}   # id -> {qtd, recorde_cm, classe, titulo}


func registrar(ex: Dictionary) -> Dictionary:
	var id: String = ex.especie
	var tam := float(ex.tam)
	if not entradas.has(id):
		entradas[id] = {"qtd": 1, "recorde_cm": tam, "classe": ex.get("classe", ""), "titulo": false}
		return {"nova": true, "recorde": true}
	var e: Dictionary = entradas[id]
	e.qtd = int(e.qtd) + 1
	if tam > float(e.recorde_cm):
		e.recorde_cm = tam
		e.classe = ex.get("classe", e.classe)
		return {"nova": false, "recorde": true}
	return {"nova": false, "recorde": false}


func dar_titulo(especie_id: String) -> void:
	if not entradas.has(especie_id):
		entradas[especie_id] = {"qtd": 0, "recorde_cm": 0.0, "classe": "", "titulo": true}
	else:
		entradas[especie_id].titulo = true


func conhecidas() -> int:
	var n := 0
	for e in entradas.values():
		if int(e.qtd) > 0:
			n += 1
	return n


func para_dict() -> Dictionary:
	return entradas.duplicate(true)


func carregar_dict(d: Dictionary) -> void:
	entradas.clear()
	for id in d:
		var e = d[id]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		entradas[id] = {
			"qtd": int(e.get("qtd", 0)),
			"recorde_cm": float(e.get("recorde_cm", 0.0)),
			"classe": str(e.get("classe", "")),
			"titulo": bool(e.get("titulo", false)),
		}
