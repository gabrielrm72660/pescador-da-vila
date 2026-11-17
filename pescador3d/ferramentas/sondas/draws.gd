extends SceneTree
# Conta objetos por tipo/material para achar onde vão os draw calls
var jogo
var q := 0
func _initialize() -> void:
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func _process(_d: float) -> bool:
	q += 1
	if q == 3:
		jogo.iniciar_ou_retomar()
	if q == 8:
		var por_pai := {}
		var por_mat := {}
		var total := 0
		for no in jogo.find_children("*", "MeshInstance3D", true, false):
			var m := no as MeshInstance3D
			if m.mesh == null or not m.is_visible_in_tree(): continue
			total += 1
			var pai: String = str(m.get_parent().name)
			if m.get_parent().get_parent() != jogo and m.get_parent().get_parent() != null:
				pai = str(m.get_parent().get_parent().name) + "/" + pai
			por_pai[pai] = por_pai.get(pai, 0) + 1
			var mat = m.get_active_material(0)
			var mn: String = "-"
			if mat != null: mn = mat.resource_path.get_file() if mat.resource_path != "" else (str(mat.get_class()) + ":" + str(mat.resource_name))
			por_mat[mn] = por_mat.get(mn, 0) + 1
		print("MESHINSTANCES visiveis: ", total)
		var ks := por_pai.keys(); ks.sort_custom(func(a, b): return por_pai[a] > por_pai[b])
		for k in ks.slice(0, 18): print("  PAI ", k, " = ", por_pai[k])
		var ms := por_mat.keys(); ms.sort_custom(func(a, b): return por_mat[a] > por_mat[b])
		for k in ms.slice(0, 14): print("  MAT ", k, " = ", por_mat[k])
		var rest := {}
		for no in jogo.ilha.find_children("*", "MeshInstance3D", true, false):
			var m := no as MeshInstance3D
			var mat = m.material_override
			var k: String = m.mesh.get_class() + " emi=" + (str(mat.emission_enabled) if mat is StandardMaterial3D else "?") + " tr=" + (str(mat.transparency) if mat is StandardMaterial3D else "?") + " filhos=" + str(m.get_child_count()) + " sc=" + str(m.get_script() != null) + " verts=" + str((m.mesh.surface_get_arrays(0)[0] as PackedVector3Array).size() if m.mesh.get_surface_count() > 0 else 0)
			rest[k] = rest.get(k, 0) + 1
		for k in rest: print("  RESTO ", k, " = ", rest[k])
		var mm := 0
		for no in jogo.find_children("*", "MultiMeshInstance3D", true, false): mm += 1
		print("MULTIMESH: ", mm)
		return true
	return false
