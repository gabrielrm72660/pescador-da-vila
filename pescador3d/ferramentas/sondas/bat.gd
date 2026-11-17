extends SceneTree
var jogo
var q := 0
func _initialize() -> void:
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func _process(_d: float) -> bool:
	q += 1
	if q == 4:
		for ilha in jogo.ilhas:
			var dir: Vector3 = (ilha.cais_ponta - ilha.cais_inicio).normalized()
			var lado := Vector3(-dir.z, 0, dir.x)
			print("ILHA ", ilha.nome, " ponta ", ilha.cais_ponta, " dir ", dir)
			for a in [-10, 0, 4, 8, 12, 16, 20, 30, 40, 60]:
				var linha := ""
				for c in [-12, -8, -4, 0, 4, 8, 12]:
					var p: Vector3 = ilha.cais_ponta + dir * a + lado * c
					linha += "%6.1f" % ilha.altura_em(p)
				print("  a=%3d: %s" % [a, linha])
		return true
	return false
