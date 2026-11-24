extends RefCounted
## v0.8.0: carrega as malhas dos cetáceos geradas por ferramentas/cetaceos.py (assets/fauna/<bicho>.json + _pele.png)
## e monta um MeshInstance3D com o shader de ondulação (shaders/cetaceo.gdshader).

const SHADER := preload("res://shaders/cetaceo.gdshader")
static var _malhas: Dictionary = {}
static var _dados: Dictionary = {}

static func dados(bicho: String) -> Dictionary:
	if not _dados.has(bicho):
		var f := FileAccess.open("res://assets/fauna/%s.json" % bicho, FileAccess.READ)
		_dados[bicho] = JSON.parse_string(f.get_as_text()) if f != null else {}
	return _dados[bicho]

static func malha(bicho: String) -> ArrayMesh:
	if _malhas.has(bicho):
		return _malhas[bicho]
	var d: Dictionary = dados(bicho)
	if d.is_empty():
		return null
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var c := PackedColorArray()
	var fv: Array = d["v"]
	var fn: Array = d["n"]
	var fu: Array = d["uv"]
	var fc: Array = d["c"]
	for k in range(fv.size() / 3):
		v.append(Vector3(fv[k * 3], fv[k * 3 + 1], fv[k * 3 + 2]))
		n.append(Vector3(fn[k * 3], fn[k * 3 + 1], fn[k * 3 + 2]))
		uv.append(Vector2(fu[k * 2], fu[k * 2 + 1]))
		c.append(Color(fc[k * 4], fc[k * 4 + 1], fc[k * 4 + 2], fc[k * 4 + 3]))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array(d["i"])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_malhas[bicho] = am
	return am

## Material próprio de cada animal (cada um tem sua fase de nado).
static func material(bicho: String) -> ShaderMaterial:
	var d: Dictionary = dados(bicho)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("pele", load("res://assets/fauna/%s_pele.png" % bicho))
	m.set_shader_parameter("z_cabeca", float(d.get("z_cabeca", -1.0)))
	m.set_shader_parameter("comprimento", float(d.get("comprimento", 2.0)))
	return m

static func instancia(bicho: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "Corpo"
	mi.mesh = malha(bicho)
	mi.material_override = material(bicho)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a malha ondula no shader: a caixa de corte precisa de folga para não sumir na borda da tela
	mi.extra_cull_margin = 2.0
	return mi
