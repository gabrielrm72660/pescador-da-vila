extends SceneTree
const C = preload("res://scripts/cardumes.gd")
func _initialize() -> void:
	var c = C.new()
	var cenarios := [
		["dia, costa 100 m, costeiro", false, 100.0, "costeiro", false],
		["dia, costa 250 m", false, 250.0, "costeiro", false],
		["dia, recife", false, 90.0, "recife", false],
		["dia, banco", false, 200.0, "banco", false],
		["noite, recife", true, 90.0, "recife", false],
		["dia, alto-mar", false, 420.0, "costeiro", true],
		["noite, alto-mar", true, 420.0, "costeiro", true],
	]
	for cen in cenarios:
		c.noite = cen[1]; c._distancia_costeira = cen[2]; c._zona_local = cen[3]; c._alto_mar = cen[4]
		var cont := {}
		for i in 6000:
			var e: String = c._sortear_especie()
			cont[e] = int(cont.get(e, 0)) + 1
		var linhas: Array = []
		var chaves := cont.keys()
		chaves.sort_custom(func(a, b): return cont[a] > cont[b])
		for k in chaves:
			linhas.append("%s %.1f%%" % [k, cont[k] / 60.0])
		print(cen[0], " -> ", ", ".join(linhas))
	# valor médio por peixe e por cardume
	var tot := 0
	for e in C.ESPECIES:
		var d: Dictionary = C.ESPECIES[e]
		var media: float = float(d.peso[0]) + (float(d.peso[1]) - float(d.peso[0])) / 2.7
		var por_peixe: float = media * float(d.preco)
		var casas: int = preload("res://scripts/porao.gd").FORMAS[e].size()
		print("%-14s peso médio %.1f kg  R$ %.0f/peixe  R$ %.0f por casa  capturas %s" % [e, media, por_peixe, por_peixe / casas, str(d.capturas)])
	c.free()
	quit()
