extends SceneTree
var jogo
var q := 0
func _initialize() -> void:
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func _tris_mesh(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		var a = m.surface_get_arrays(s)
		var idx = a[Mesh.ARRAY_INDEX]
		t += (idx.size() if idx != null else a[Mesh.ARRAY_VERTEX].size()) / 3
	return t
func _process(_d: float) -> bool:
	q += 1
	if q == 5:
		jogo.iniciar_ou_retomar()
		var lista := []
		for il in jogo.ilhas:
			for n in il.find_children("*", "GeometryInstance3D", true, false):
				var tris := 0
				if n is MeshInstance3D and n.mesh != null:
					tris = _tris_mesh(n.mesh)
				elif n is MultiMeshInstance3D and n.multimesh != null and n.multimesh.mesh != null:
					tris = _tris_mesh(n.multimesh.mesh) * n.multimesh.instance_count
				lista.append([tris, il.name + "/" + str(n.name), n.get_class()])
		lista.sort_custom(func(a, b): return a[0] > b[0])
		var soma := 0
		for e in lista: soma += e[0]
		print("TOTAL ilhas tris=", soma, " nos=", lista.size())
		for k in 14:
			print("  ", lista[k])
		return true
	return false
