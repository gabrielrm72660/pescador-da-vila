extends SceneTree
func _initialize() -> void:
	var m: Node3D = load("res://assets/barco/PE3476_v4.glb").instantiate()
	root.add_child(m)
	var total := 0
	var tris := 0
	_ver(m, 0)
	for n in m.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		total += mi.mesh.get_surface_count()
		for i in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX].size() / 3
	print("SUPERFICIES ", total, " triangulos ", tris)
	var ab := AABB()
	for n in m.find_children("*", "MeshInstance3D", true, false):
		ab = ab.merge((n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb())
	print("AABB ", ab)
	quit()
func _ver(n: Node, d: int) -> void:
	var s := ""
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i) as BaseMaterial3D
			var tex := ""
			if mat != null and mat.albedo_texture != null:
				tex = mat.albedo_texture.resource_path.get_file()
			s += " [%s col=%s tex=%s]" % [mat.resource_name if mat != null else "-", mat.albedo_color.to_html(false) if mat != null else "-", tex]
	print("  ".repeat(d), n.name, " (", n.get_class(), ")", s)
	for c in n.get_children():
		_ver(c, d + 1)
