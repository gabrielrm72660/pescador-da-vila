extends RefCounted
## v0.7.8: o Estrela d'Alva vira o "Pesqueiro de Alto-Mar" (escolhido pelo Gabriel entre 4 propostas).
##  - reformar(): mexe na malha do modelo PE3476 uma vez, ao carregar —
##      · cabine 15 cm mais baixa (paredes encolhem, teto e o que está em cima descem juntos);
##      · retranca e vela enrolada mais curtas: antes a ponta entrava por baixo do beiral do teto da cabine;
##      · a porta antiga (pintada, sem relevo) recua para dentro da cabine; uma porta nova a substitui.
##  - equipar(): relevos e equipamentos — molduras e peitoris nas 8 janelas, porta com almofadas (textura + mapa de
##    normais), escotilha e maçaneta de latão, radar, antenas, holofotes, balsa salva-vidas, toldo na popa, tampa do
##    porão de gelo na proa.
##  - PINTURA: casco azul-marinho, cabine de tábuas brancas, teto cinza-claro, frisos brancos (texturas do SpriteCook
##    em assets/barco/altomar/, refeitas por ferramentas/barco_altomar.py).
## Coordenadas no espaço do Balanceio (= do modelo): proa em -Z, popa em +Z, convés em y = 0,5.

const BAIXA := 0.15                    # quanto a cabine desce
const Y_BASE := 0.52                   # rodapé da cabine (não se mexe)
const Y_TETO := 2.20                   # onde a parede encontra o teto (original)
const K := (Y_TETO - BAIXA - Y_BASE) / (Y_TETO - Y_BASE)
const PEGADA_X := 1.05                 # planta da cabine com o beiral do teto
const PEGADA_Z := Vector2(0.50, 3.30)
const RETRANCA_PE := -0.86             # pé da retranca, no mastro
const RETRANCA_PONTA := 0.30           # nova ponta (antes 0,80; o beiral começa em 0,55)
const TETO_EM_CIMA := Y_TETO + 0.20 - BAIXA
const DIR := "res://assets/barco/altomar/"
const RIGIDOS := ["plastico_branco", "plastico_azul", "boia_laranja", "metal", "luz_quente", "luz_verde", "luz_vermelha",
		"preto", "pintura_amarela", "pintura_vermelha", "rede"]

const PINTURA := {
	"casco_branco": ["casco", Color(1.0, 1.0, 1.0)],
	"pintura_creme": ["cabine", Color(1.02, 1.02, 1.02)],
	"pintura_laranja": ["teto", Color(1.0, 1.0, 1.0)],
	"pintura_azul": ["teto", Color(1.08, 1.08, 1.08)],    # frisos e amurada brancos
}
const DESGASTE := 0.38

static func y_cabine(y: float) -> float:
	if y <= Y_BASE:
		return y
	if y >= Y_TETO:
		return y - BAIXA
	return Y_BASE + (y - Y_BASE) * K

static func _na_pegada(p: Vector3) -> bool:
	return absf(p.x) <= PEGADA_X and p.z >= PEGADA_Z.x and p.z <= PEGADA_Z.y and p.y > Y_BASE

## --------------------------------------------------------------------------------------------- malha

static func reformar(casco: MeshInstance3D) -> void:
	var velha: Mesh = casco.mesh
	if velha == null or velha.has_meta("altomar"):
		return
	var nova := ArrayMesh.new()
	for i in velha.get_surface_count():
		var arr: Array = velha.surface_get_arrays(i)
		var mat: Material = velha.surface_get_material(i)
		var nome: String = mat.resource_name if mat != null else ""
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		# 1) retranca, vela enrolada e os nós que a prendem: encurtam em direção ao mastro
		if nome in ["lona", "corda", "madeira_escura"]:
			for k in v.size():
				var p: Vector3 = v[k]
				var na_retranca: bool = absf(p.x) <= 0.15 and p.y >= 1.74 and p.y <= 2.26 and p.z > RETRANCA_PE + 0.07 and p.z <= 0.82
				if na_retranca and (nome != "corda" or p.z > -0.70):
					p.z = RETRANCA_PE + (p.z - RETRANCA_PE) * (RETRANCA_PONTA - RETRANCA_PE) / (0.80 - RETRANCA_PE)
					v[k] = p
		# 2) a porta antiga (folha, vidro, moldura e maçaneta) recua para dentro da cabine
		if nome in ["pintura_azul", "vidro", "metal", "madeira_escura"]:
			for k in v.size():
				var p: Vector3 = v[k]
				if p.z > 2.97 and p.z < 3.15 and p.x >= -0.60 and p.x <= 0.15 and p.y > 0.5 and p.y < 1.97:
					p.z -= 0.18
					v[k] = p
		# 3) cabine mais baixa: peças pequenas descem inteiras (boias, luzes, chaminé), paredes encolhem
		if nome in RIGIDOS:
			var ilhas: Array = _ilhas(v, idx)
			for ilha in ilhas:
				var c := Vector3.ZERO
				for k in ilha:
					c += v[k]
				c /= float(ilha.size())
				if not _na_pegada(c):
					continue
				var dy: float = y_cabine(c.y) - c.y
				for k in ilha:
					v[k] = v[k] + Vector3(0.0, dy, 0.0)
		else:
			for k in v.size():
				var p: Vector3 = v[k]
				if _na_pegada(p):
					p.y = y_cabine(p.y)
					v[k] = p
		arr[Mesh.ARRAY_VERTEX] = v
		nova.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		nova.surface_set_material(nova.get_surface_count() - 1, mat)
	nova.set_meta("altomar", true)
	casco.mesh = nova

## Grupos de vértices ligados (pelos triângulos ou por estarem no mesmo lugar).
static func _ilhas(v: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var pai := PackedInt32Array()
	pai.resize(v.size())
	for k in v.size():
		pai[k] = k
	var achar := func(x: int) -> int:
		while pai[x] != x:
			pai[x] = pai[pai[x]]
			x = pai[x]
		return x
	var mesmo := {}
	for k in v.size():
		var ch := Vector3i((v[k] * 1000.0).round())
		if mesmo.has(ch):
			pai[achar.call(k)] = achar.call(mesmo[ch])
		else:
			mesmo[ch] = k
	if idx.is_empty():
		for t in range(0, v.size() - 2, 3):
			pai[achar.call(t + 1)] = achar.call(t)
			pai[achar.call(t + 2)] = achar.call(t)
	else:
		for t in range(0, idx.size() - 2, 3):
			pai[achar.call(idx[t + 1])] = achar.call(idx[t])
			pai[achar.call(idx[t + 2])] = achar.call(idx[t])
	var grupos := {}
	for k in v.size():
		var r: int = achar.call(k)
		if not grupos.has(r):
			grupos[r] = []
		grupos[r].append(k)
	return grupos.values()

## --------------------------------------------------------------------------------------------- pintura

## Textura e cor do Alto-Mar para uma peça do modelo (ou [] se a peça fica como está).
static func pintura(nome: String) -> Array:
	if not PINTURA.has(nome):
		return []
	var arq: String = DIR + String(PINTURA[nome][0]) + ".png"
	if not ResourceLoader.exists(arq):
		return []
	var normal: String = DIR + String(PINTURA[nome][0]) + "_normal.png"
	return [load(arq), load(normal) if ResourceLoader.exists(normal) else null, PINTURA[nome][1]]

## --------------------------------------------------------------------------------------------- relevos e equipamentos

static func _mat(cor: Color, rugoso := 0.85, metal := 0.0, brilho := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugoso
	m.metallic = metal
	m.metallic_specular = 0.25
	if brilho > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = brilho
	return m

static func _caixa(pai: Node3D, centro: Vector3, tam: Vector3, mat: Material, base := Basis()) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = tam
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.transform = Transform3D(base, centro)
	pai.add_child(mi)
	return mi

static func _haste(pai: Node3D, a: Vector3, b: Vector3, raio: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = raio
	c.bottom_radius = raio
	c.height = a.distance_to(b)
	c.radial_segments = 10
	c.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	var y := (b - a).normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	pai.add_child(mi)

## Moldura em relevo (4 réguas + peitoril) em volta de um retângulo na parede.
## centro: meio da abertura na face da parede; dir: para a direita na parede; fora: normal da parede.
static func _moldura(pai: Node3D, centro: Vector3, dir: Vector3, fora: Vector3, larg: float, alt: float, mat: Material,
		regua := 0.055, saliencia := 0.05) -> void:
	var cima := fora.cross(dir).normalized()
	if cima.y < 0.0:
		cima = -cima
	var base := Basis(dir, cima, fora)
	var c0: Vector3 = centro + fora * (saliencia * 0.5 - 0.004)
	_caixa(pai, c0 + cima * (alt * 0.5 + regua * 0.5), Vector3(larg + regua * 2.0 + 0.04, regua * 1.2, saliencia * 1.3), mat, base)  # verga
	_caixa(pai, c0 - cima * (alt * 0.5 + regua * 0.5), Vector3(larg + regua * 2.0, regua, saliencia), mat, base)
	_caixa(pai, c0 + dir * (larg * 0.5 + regua * 0.5), Vector3(regua, alt, saliencia), mat, base)
	_caixa(pai, c0 - dir * (larg * 0.5 + regua * 0.5), Vector3(regua, alt, saliencia), mat, base)
	# peitoril: sai mais da parede e é um pouco mais largo
	_caixa(pai, centro + fora * 0.045 - cima * (alt * 0.5 + regua + 0.018), Vector3(larg + regua * 2.0 + 0.10, 0.035, 0.09), mat, base)

static func equipar(bal: Node3D) -> void:
	if bal.get_node_or_null("AltoMar") != null:
		return
	var raiz := Node3D.new()
	raiz.name = "AltoMar"
	bal.add_child(raiz)
	var marinho := _mat(Color(0.13, 0.19, 0.36))
	var branco := _mat(Color(0.90, 0.90, 0.88))
	var cinza := _mat(Color(0.34, 0.35, 0.37), 0.55, 0.3)
	var latao := _mat(Color(0.80, 0.62, 0.28), 0.38, 0.75)
	var vidro := _mat(Color(0.08, 0.14, 0.22), 0.15, 0.2)
	var lona := _mat(Color(0.16, 0.30, 0.55), 0.95)
	var y0: float = y_cabine(1.38)
	var y1: float = y_cabine(1.80)
	# janelas da frente (parede em z = 0,85, virada para a proa)
	for x in [-0.50, 0.0, 0.50]:
		_moldura(raiz, Vector3(x, (y0 + y1) * 0.5, 0.85), Vector3.LEFT, Vector3.FORWARD, 0.36, y1 - y0, marinho)
	# janelas dos lados (x = ±0,84)
	var s0: float = y_cabine(1.39)
	var s1: float = y_cabine(1.79)
	for lado in [-1.0, 1.0]:
		for z in [1.47, 2.37]:
			_moldura(raiz, Vector3(0.84 * lado, (s0 + s1) * 0.5, z), Vector3(0, 0, -lado), Vector3(lado, 0, 0), 0.46, s1 - s0, marinho)
	# janela de trás, ao lado da porta (z = 3,05, virada para a popa)
	var t0: float = y_cabine(1.41)
	var t1: float = y_cabine(1.77)
	_moldura(raiz, Vector3(0.46, (t0 + t1) * 0.5, 3.05), Vector3.RIGHT, Vector3.BACK, 0.30, t1 - t0, marinho)
	_porta(raiz, marinho, latao, vidro)
	# --- equipamentos do Alto-Mar, em cima do teto (que agora está em TETO_EM_CIMA)
	var r: float = TETO_EM_CIMA
	_haste(raiz, Vector3(0.38, r, 1.85), Vector3(0.38, r + 0.32, 1.85), 0.05, cinza)            # radar: coluna
	var radar := Node3D.new()                     # v0.7.9: a antena do radar gira (barco.gd gira o nó "Radar")
	radar.name = "Radar"
	radar.position = Vector3(0.38, r + 0.36, 1.85)
	radar.rotation.y = 0.5
	raiz.add_child(radar)
	_caixa(radar, Vector3.ZERO, Vector3(1.05, 0.07, 0.15), branco)
	_caixa(radar, Vector3(0.0, -0.02, 0.0), Vector3(0.16, 0.06, 0.16), cinza)
	for x in [-0.72, 0.72]:                                                                     # antenas
		_caixa(raiz, Vector3(x, r + 0.05, 2.95), Vector3(0.10, 0.10, 0.10), cinza)
		_haste(raiz, Vector3(x, r + 0.1, 2.95), Vector3(x, r + 2.2, 2.98), 0.016, branco)
	var lente := _mat(Color(1.0, 0.95, 0.82), 0.3, 0.0, 0.0)          # v0.7.9: acende com a lanterna (barco.definir_holofotes)
	lente.emission_enabled = true
	lente.emission = Color(1.0, 0.92, 0.75)
	lente.resource_name = "lente_holofote"
	for x in [-0.55, 0.55]:                                                                     # holofotes
		_caixa(raiz, Vector3(x, r + 0.05, 0.66), Vector3(0.06, 0.10, 0.06), cinza)
		_caixa(raiz, Vector3(x, r + 0.14, 0.62), Vector3(0.24, 0.16, 0.14), cinza)
		_caixa(raiz, Vector3(x, r + 0.14, 0.548), Vector3(0.19, 0.11, 0.01), lente)
		var foco := SpotLight3D.new()
		foco.name = "Holofote"
		foco.light_color = Color(1.0, 0.93, 0.78)
		foco.light_energy = 0.0
		foco.spot_range = 60.0
		foco.spot_angle = 22.0
		foco.spot_attenuation = 0.9
		foco.shadow_enabled = false
		foco.position = Vector3(x, r + 0.14, 0.53)
		foco.rotation.x = deg_to_rad(-7.0)                   # aponta para a proa (-Z), um pouco para baixo
		foco.set_meta("lente", lente)
		raiz.add_child(foco)
	var balsa := CylinderMesh.new()                                                             # balsa salva-vidas
	balsa.top_radius = 0.21
	balsa.bottom_radius = 0.21
	balsa.height = 0.72
	var mb := MeshInstance3D.new()
	mb.mesh = balsa
	mb.material_override = branco
	mb.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-0.42, r + 0.21, 1.72))
	raiz.add_child(mb)
	var cinta := CylinderMesh.new()                                                             # cintas da balsa
	cinta.top_radius = 0.218
	cinta.bottom_radius = 0.218
	cinta.height = 0.04
	for dz in [-0.2, 0.2]:
		var mc := MeshInstance3D.new()
		mc.mesh = cinta
		mc.material_override = marinho
		mc.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(-0.42, r + 0.21, 1.72 + dz))
		raiz.add_child(mc)
	# toldo na popa, preso ao beiral do teto
	# (sem colunas até o convés: elas atravessavam a amurada; mãos-francesas saem da parede de trás da cabine)
	for x in [-0.80, 0.80]:
		_haste(raiz, Vector3(x, y_cabine(1.55), 3.06), Vector3(x * 1.12, r - 0.12, 3.74), 0.022, branco)
		_haste(raiz, Vector3(x * 1.12, r - 0.12, 3.74), Vector3(x * 1.12, r - 0.12, 3.30), 0.022, branco)
	_caixa(raiz, Vector3(0.0, r - 0.10, 3.50), Vector3(2.28, 0.035, 0.56), lona)
	# tampa do porão de gelo na proa
	_caixa(raiz, Vector3(0.0, 0.66, -3.0), Vector3(1.15, 0.26, 0.85), branco)
	for dz in [-0.25, 0.25]:
		_haste(raiz, Vector3(-0.25, 0.81, -3.0 + dz), Vector3(0.25, 0.81, -3.0 + dz), 0.018, cinza)

## Porta nova na parede de trás: folha pintada (textura do SpriteCook com almofadas no mapa de normais), batente em
## relevo, escotilha redonda de latão saltada e maçaneta de alavanca.
static func _porta(raiz: Node3D, marinho: Material, latao: Material, vidro: Material) -> void:
	var x0 := -0.55
	var x1 := 0.11
	var alt: float = y_cabine(1.94) - Y_BASE
	var larg: float = x1 - x0
	var cx: float = (x0 + x1) * 0.5
	var cy: float = Y_BASE + alt * 0.5
	var z: float = 3.05
	_caixa(raiz, Vector3(cx, cy, z + 0.012), Vector3(larg - 0.02, alt - 0.02, 0.024), _mat(Color(0.88, 0.88, 0.85)))
	var folha := QuadMesh.new()
	folha.size = Vector2(larg - 0.02, alt - 0.02)
	var mf := StandardMaterial3D.new()
	mf.roughness = 0.85
	if ResourceLoader.exists(DIR + "porta.png"):
		mf.albedo_texture = load(DIR + "porta.png")
		mf.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if ResourceLoader.exists(DIR + "porta_normal.png"):
			mf.normal_enabled = true
			mf.normal_texture = load(DIR + "porta_normal.png")
			mf.normal_scale = 1.0
	else:
		mf.albedo_color = Color(0.9, 0.9, 0.87)
	var mi := MeshInstance3D.new()
	mi.mesh = folha
	mi.material_override = mf
	mi.position = Vector3(cx, cy, z + 0.027)
	raiz.add_child(mi)
	# batente
	var b := 0.06
	var dz := 0.035
	_caixa(raiz, Vector3(cx, Y_BASE + alt + b * 0.5, z + dz), Vector3(larg + b * 2.0 + 0.04, b * 1.2, 0.07), marinho)
	_caixa(raiz, Vector3(x0 - b * 0.5, cy, z + dz), Vector3(b, alt, 0.07), marinho)
	_caixa(raiz, Vector3(x1 + b * 0.5, cy, z + dz), Vector3(b, alt, 0.07), marinho)
	# escotilha: na textura o centro está em (0,496; 0,238) da folha e o aro tem ~42% da largura
	var u := func(f: float) -> float: return cx - (larg - 0.02) * 0.5 + (larg - 0.02) * f
	var v := func(f: float) -> float: return cy + (alt - 0.02) * 0.5 - (alt - 0.02) * f
	var aro := TorusMesh.new()
	aro.inner_radius = 0.092
	aro.outer_radius = 0.138
	aro.rings = 24
	aro.ring_segments = 10
	var ma := MeshInstance3D.new()
	ma.mesh = aro
	ma.material_override = latao
	ma.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(u.call(0.496), v.call(0.238), z + 0.04))
	raiz.add_child(ma)
	var disco := CylinderMesh.new()
	disco.top_radius = 0.095
	disco.bottom_radius = 0.095
	disco.height = 0.01
	var md := MeshInstance3D.new()
	md.mesh = disco
	md.material_override = vidro
	md.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(u.call(0.496), v.call(0.238), z + 0.03))
	raiz.add_child(md)
	# maçaneta de alavanca (espelho + haste apontando para o meio da porta)
	var hx: float = u.call(0.865)
	var hy: float = v.call(0.505)
	_caixa(raiz, Vector3(hx, hy, z + 0.035), Vector3(0.045, 0.11, 0.016), latao)
	_haste(raiz, Vector3(hx, hy, z + 0.04), Vector3(hx, hy, z + 0.085), 0.012, latao)
	_haste(raiz, Vector3(hx, hy, z + 0.085), Vector3(hx - 0.11, hy - 0.008, z + 0.085), 0.011, latao)
