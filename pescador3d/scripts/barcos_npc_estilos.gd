extends RefCounted
## v0.7.9: os modelos que não foram escolhidos para o barco do jogador (o Estrela d'Alva antigo, o Saveiro Nordestino,
## o Lagosteiro de Noronha e o Velho de Madeira) viram barcos dos pescadores NPC, ao lado dos três esquemas antigos.
## Cada estilo = cores por papel (para shaders/pintura_npc.gdshader) + equipamento numa malha só, com as cores nos
## vértices (uma chamada de desenho por barco). Coordenadas do modelo PE3476: proa em -Z, convés em y = 0,5.

const ESTILOS := [
	{"nome": "antigo", "fundo": Color(0.55, 0.16, 0.12), "faixa": Color(0.17, 0.36, 0.56), "teto": Color(0.83, 0.40, 0.18),
		"costado": Color(0.90, 0.87, 0.80), "cabine": Color(0.90, 0.85, 0.72)},
	{"nome": "saveiro", "fundo": Color(0.92, 0.92, 0.90), "faixa": Color(0.85, 0.18, 0.13), "teto": Color(0.22, 0.38, 0.75),
		"costado": Color(0.22, 0.66, 0.70), "cabine": Color(0.93, 0.78, 0.30)},
	{"nome": "lagosteiro", "fundo": Color(0.55, 0.16, 0.12), "faixa": Color(0.92, 0.72, 0.20), "teto": Color(0.70, 0.18, 0.13),
		"costado": Color(0.16, 0.40, 0.28), "cabine": Color(0.93, 0.93, 0.90)},
	{"nome": "madeira", "fundo": Color(0.30, 0.45, 0.36), "faixa": Color(0.17, 0.40, 0.29), "teto": Color(0.52, 0.44, 0.38),
		"costado": Color(0.62, 0.42, 0.24), "cabine": Color(0.55, 0.70, 0.78)},
	# os três esquemas que já existiam (v0.5.x)
	{"nome": "verde", "fundo": Color(0.10, 0.38, 0.28), "faixa": Color(0.90, 0.74, 0.22), "teto": Color(0.08, 0.40, 0.38),
		"costado": Color(0.84, 0.93, 0.87), "cabine": Color(0.84, 0.93, 0.87)},
	{"nome": "marinho", "fundo": Color(0.12, 0.25, 0.50), "faixa": Color(0.82, 0.22, 0.16), "teto": Color(0.92, 0.80, 0.38),
		"costado": Color(0.78, 0.87, 0.95), "cabine": Color(0.78, 0.87, 0.95)},
	{"nome": "ocre", "fundo": Color(0.80, 0.62, 0.16), "faixa": Color(0.14, 0.52, 0.58), "teto": Color(0.66, 0.22, 0.16),
		"costado": Color(0.96, 0.90, 0.74), "cabine": Color(0.96, 0.90, 0.74)},
]

static var _cache: Dictionary = {}

## Malha do equipamento do estilo (ou null se ele não tem nada a mais).
static func equipamento(indice: int) -> ArrayMesh:
	var nome: String = ESTILOS[indice]["nome"]
	if _cache.has(nome):
		return _cache[nome]
	var m := Montador.new()
	match nome:
		"saveiro":
			_pneus(m, [-2.2, -0.6, 1.6])
			m.esfera(Vector3(0.95, 2.05, 0.62), 0.09, Color(1.0, 0.78, 0.40))
			var cores := [Color(0.95, 0.25, 0.2), Color(1.0, 0.85, 0.2), Color(0.2, 0.6, 0.95), Color(0.3, 0.8, 0.4)]
			var a := Vector3(-0.2, 3.7, -0.8)
			var b := Vector3(0.0, 1.5, -4.4)
			m.haste(a, b, 0.008, Color(0.9, 0.9, 0.85))
			for k in 9:
				var p: Vector3 = a.lerp(b, (k + 0.5) / 9.0) + Vector3(0, -0.12, 0)
				m.bandeirola(p, Vector2(0.22, 0.24), cores[k % 4])
		"lagosteiro":
			var madeira := Color(0.42, 0.28, 0.16)
			var cabo := Color(0.75, 0.70, 0.60)
			for lado in [-1.0, 1.0]:
				var base := Vector3(lado * 0.35, 1.6, -0.9)
				var ponta: Vector3 = base + Vector3(lado * 3.6, 3.4, 0.3)
				m.haste(base, ponta, 0.06, madeira)
				m.haste(ponta, Vector3(-0.2, 3.75, -0.8), 0.012, cabo)
				m.haste(ponta, Vector3(lado * 1.2, 1.4, -2.8), 0.012, cabo)
			for i in 3:
				for j in 2:
					m.caixa(Vector3(-0.33 + j * 0.66, 0.72 + (0.38 if i == 2 else 0.0), -2.55 + (i % 2) * 0.6 + (0.3 if i == 2 else 0.0)),
						Vector3(0.6, 0.36, 0.5), Color(0.28, 0.22, 0.14))
			for z in [-2.0, 2.0]:
				m.esfera(Vector3(0.75, 0.75, z), 0.16, Color(1.0, 0.45, 0.1))
				m.haste(Vector3(0.75, 0.8, z), Vector3(0.75, 2.0, z), 0.012, Color(0.3, 0.3, 0.3))
				m.caixa(Vector3(0.75, 1.9, z + 0.12), Vector3(0.02, 0.18, 0.24), Color(0.95, 0.2, 0.15))
			_pneus(m, [-1.0, 1.2])
		"madeira":
			_pneus(m, [-2.4, -0.8, 1.0, 2.6])
			m.esfera(Vector3(-0.95, 2.05, 0.62), 0.09, Color(1.0, 0.78, 0.40))
			m.esfera(Vector3(0.0, 3.2, -0.95), 0.09, Color(1.0, 0.78, 0.40))
			m.esfera(Vector3(-0.2, 0.75, -3.0), 0.5, Color(0.15, 0.32, 0.38), Vector3(1.4, 0.35, 1.0))
			m.haste(Vector3(0.9, 1.5, -3.6), Vector3(0.9, 1.5, -0.6), 0.035, Color(0.55, 0.38, 0.2))
			m.caixa(Vector3(0.9, 1.5, -3.75), Vector3(0.02, 0.1, 0.4), Color(0.55, 0.38, 0.2))
	_cache[nome] = m.malha()
	return _cache[nome]

static func _pneus(m: Montador, zs: Array) -> void:
	for z in zs:
		for lado in [-1.0, 1.0]:
			m.pneu(Vector3(lado * 1.4, 0.95, z))
			m.haste(Vector3(lado * 1.38, 1.15, z), Vector3(lado * 1.3, 1.42, z), 0.015, Color(0.55, 0.42, 0.25))

## Junta primitivas numa malha só com cor por vértice.
class Montador:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	func _juntar(malha: PrimitiveMesh, xf: Transform3D, cor: Color) -> void:
		var arr: Array = malha.get_mesh_arrays()
		var vv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var base: int = v.size()
		var bn := xf.basis.inverse().transposed()
		for k in vv.size():
			v.append(xf * vv[k])
			n.append((bn * nn[k]).normalized())
			c.append(cor)
		for k in ii:
			idx.append(base + k)

	func caixa(centro: Vector3, tam: Vector3, cor: Color) -> void:
		var b := BoxMesh.new()
		b.size = tam
		_juntar(b, Transform3D(Basis(), centro), cor)

	func esfera(centro: Vector3, raio: float, cor: Color, esc := Vector3.ONE) -> void:
		var s := SphereMesh.new()
		s.radius = raio
		s.height = raio * 2.0
		s.radial_segments = 10
		s.rings = 6
		_juntar(s, Transform3D(Basis().scaled(esc), centro), cor)

	func haste(a: Vector3, b: Vector3, raio: float, cor: Color) -> void:
		var cil := CylinderMesh.new()
		cil.top_radius = raio
		cil.bottom_radius = raio
		cil.height = a.distance_to(b)
		cil.radial_segments = 6
		cil.rings = 1
		var y := (b - a).normalized()
		var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		_juntar(cil, Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5), cor)

	func pneu(centro: Vector3) -> void:
		var t := TorusMesh.new()
		t.inner_radius = 0.11
		t.outer_radius = 0.23
		t.rings = 12
		t.ring_segments = 6
		_juntar(t, Transform3D(Basis(Vector3.BACK, PI / 2), centro), Color(0.07, 0.07, 0.07))

	func bandeirola(centro: Vector3, tam: Vector2, cor: Color) -> void:
		var p := PrismMesh.new()
		p.size = Vector3(tam.x, tam.y, 0.01)
		_juntar(p, Transform3D(Basis(Vector3.RIGHT, PI), centro), cor)

	func malha() -> ArrayMesh:
		if v.is_empty():
			return null
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return am
