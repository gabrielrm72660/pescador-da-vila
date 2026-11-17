extends SceneTree
const C = preload("res://scripts/cardumes.gd")
const NOVAS := ["Baiacu", "Peixe-voador", "Budião", "Robalo", "Peixe-anjo", "Moreia", "Arabaiana", "Namorado", "Agulhão-vela"]
func valor_cardume(e: String) -> float:
	var d: Dictionary = C.ESPECIES[e]
	var media: float = float(d.peso[0]) + (float(d.peso[1]) - float(d.peso[0])) / 2.7
	return media * float(d.preco) * (float(d.capturas[0]) + float(d.capturas[1])) / 2.0
func _initialize() -> void:
	var c = C.new()
	var cenarios := [
		["dia costa 100", false, 100.0, "costeiro", false], ["dia 250", false, 250.0, "costeiro", false],
		["dia recife", false, 90.0, "recife", false], ["dia banco", false, 200.0, "banco", false],
		["noite recife", true, 90.0, "recife", false], ["dia alto-mar", false, 420.0, "costeiro", true], ["noite alto-mar", true, 420.0, "costeiro", true]]
	for cen in cenarios:
		c.noite = cen[1]; c._distancia_costeira = cen[2]; c._zona_local = cen[3]; c._alto_mar = cen[4]
		var ev_tudo := 0.0; var ev_velhas := 0.0; var soma_tudo := 0.0; var soma_velhas := 0.0
		for e in C.ESPECIES:
			var w: float = float(c._chance(e))
			ev_tudo += w * valor_cardume(e); soma_tudo += w
			if not (e in NOVAS):
				ev_velhas += w * valor_cardume(e); soma_velhas += w
		print("%-16s R$/cardume: só antigas %.0f  | com novas %.0f  (%+.0f%%)" % [cen[0], ev_velhas / soma_velhas, ev_tudo / soma_tudo, (ev_tudo / soma_tudo / (ev_velhas / soma_velhas) - 1.0) * 100.0])
	c.free(); quit()
