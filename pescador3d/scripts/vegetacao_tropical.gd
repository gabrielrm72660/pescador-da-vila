extends RefCounted
## v0.8.5: árvores de Noronha no lugar dos pinheiros (a categoria continua "pinheiros" no mundo salvo e no Construtor). Mesmo jeito das outras malhas de vegetação
## (scripts/vegetacao_malhas.gd): triângulos facetados, cor por vértice, textura de folhagem em guache no material.
##   castanhola - copa em andares horizontais (guarda-chuvas empilhados), algumas folhas vermelhas;
##   gameleira  - a grande: tronco grosso com raízes de apoio, copa redonda e cheia;
##   mulungu    - média, copa aberta, cachos de flor laranja-avermelhada no alto;
##   leucena    - arvoreta/arbusto de vários caules finos, folhagem clara: enche as encostas.
## nível 0 = Baixa/Média (lóbulos de 20 faces, menos peças), 1 = Alta, 2 = Ultra (mais lóbulos e mais subdivisão).

const V = preload("res://scripts/vegetacao_malhas.gd")

static func criar(chave: String, nivel: int) -> ArrayMesh:
	match chave:
		"castanhola": return castanhola(nivel)
		"gameleira": return gameleira(nivel)
		"mulungu": return mulungu(nivel)
		"leucena": return leucena(nivel)
	return null

const CASCA := Color(0.33, 0.25, 0.18)

## Galho: um tronco fino do ponto a ao ponto b (o _tronco só sabe subir, então este é um cilindro torto à mão).
static func _galho(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, cor: Color, lados: int = 5) -> void:
	var eixo: Vector3 = (b - a).normalized()
	var x: Vector3 = eixo.cross(Vector3.UP if absf(eixo.y) < 0.95 else Vector3.RIGHT).normalized()
	var z: Vector3 = eixo.cross(x)
	for k in lados:
		var a0: float = TAU * float(k) / float(lados)
		var a1: float = TAU * float(k + 1) / float(lados)
		var d0: Vector3 = x * cos(a0) + z * sin(a0)
		var d1: Vector3 = x * cos(a1) + z * sin(a1)
		var c: Color = cor if k % 2 == 0 else cor.darkened(0.12)
		V._tri(st, a + d0 * r0, b + d0 * r1, a + d1 * r0, c, c, c)
		V._tri(st, a + d1 * r0, b + d0 * r1, b + d1 * r1, c, c, c)

## Castanhola: tronco reto e 3 andares de copa achatada, cada andar feito de 4 a 6 lóbulos em roda.
static func castanhola(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ruido := V._ruido(41, 0.9)
	var leve: bool = nivel <= 0
	V._tronco(st, Vector3(0, -0.2, 0), 6.6, 0.30, 0.12, Vector2(0.2, 0.1), 6 if not leve else 4, 3 if not leve else 2, CASCA)
	var verde := [Color(0.25, 0.46, 0.22), Color(0.30, 0.50, 0.23), Color(0.22, 0.41, 0.21)]
	var andares := [[3.9, 3.7, 0.85], [5.1, 2.9, 0.80], [6.2, 2.0, 0.75]]       # altura, raio, espessura
	var n_lob: int = [1, 4, 5][clampi(nivel, 0, 2)]
	var rf := RandomNumberGenerator.new()
	rf.seed = 4
	var i := 0
	for a in andares:
		var y: float = a[0]
		var r: float = a[1]
		var e: float = a[2]
		# miolo do andar (o lóbulo grande) + lóbulos menores em roda, que quebram o contorno
		V._lobulo(st, Vector3(0, y + 0.1, 0), Vector3(r * 0.72, e, r * 0.72), verde[i % 3], 0 if leve else 1, ruido, 0.20)
		for k in n_lob:
			var ang: float = TAU * float(k) / float(n_lob) + 0.7 * float(i)
			var c := Vector3(cos(ang), 0, sin(ang)) * r * 0.55 + Vector3.UP * y
			if not leve and k % 2 == 0:
				_galho(st, Vector3(0, y - 0.35, 0), c + Vector3.UP * -0.1, 0.07, 0.03, CASCA, 4)
			V._lobulo(st, c, Vector3(r * 0.5, e * 0.85, r * 0.48), verde[(k + i) % verde.size()], 2 if nivel >= 2 and k == 0 else 0, ruido, 0.26)
			i += 1
		# folhas velhas vermelhas: manchinhas por cima de cada andar (a castanhola avermelha antes de cair)
		if not leve:
			for k in 2:
				var ang2: float = rf.randf_range(0.0, TAU)
				var p := Vector3(cos(ang2), 0, sin(ang2)) * r * rf.randf_range(0.45, 0.8) + Vector3.UP * (y + e * 0.6)
				V._lobulo(st, p, Vector3(rf.randf_range(0.35, 0.55), 0.18, rf.randf_range(0.3, 0.5)), Color(0.72, 0.34, 0.18).lerp(Color(0.80, 0.55, 0.22), rf.randf()), 0, ruido, 0.3)
	st.generate_normals()
	return st.commit()

## Gameleira: a maior. Tronco grosso, raízes de apoio em leque, galhos abertos e copa redonda de muitos lóbulos.
static func gameleira(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ruido := V._ruido(53, 0.7)
	var casca := Color(0.42, 0.38, 0.32)                     # figueira: casca acinzentada
	var sub: int = 0 if nivel <= 0 else 1
	V._tronco(st, Vector3(0, -0.3, 0), 5.4, 0.85, 0.48, Vector2(0.2, 0.0), 9 if nivel > 0 else 6, 4 if nivel > 0 else 2, casca)
	for k in (6 if nivel > 0 else 0):                         # raízes de apoio
		var ang: float = TAU * float(k) / 6.0 + 0.3
		var fora := Vector3(cos(ang), 0, sin(ang))
		_galho(st, fora * 0.5 + Vector3.UP * 1.8, fora * 2.1 + Vector3.DOWN * 0.3, 0.22, 0.10, casca.darkened(0.08))
	for k in (5 if nivel > 0 else 0):                         # galhos grossos que abrem
		var ang: float = TAU * float(k) / 5.0
		var fora := Vector3(cos(ang), 0, sin(ang))
		_galho(st, Vector3(0, 4.6, 0), fora * 3.6 + Vector3.UP * 7.4, 0.32, 0.12, casca)
	var verdes := [Color(0.18, 0.37, 0.20), Color(0.22, 0.42, 0.22), Color(0.16, 0.33, 0.19), Color(0.25, 0.45, 0.23)]
	var lob: Array = [
		[Vector3(0, 9.6, 0), Vector3(3.6, 2.4, 3.6)],
		[Vector3(3.4, 8.3, 0.8), Vector3(2.6, 2.0, 2.5)], [Vector3(-3.3, 8.5, -0.6), Vector3(2.6, 2.0, 2.5)],
		[Vector3(0.6, 8.2, 3.4), Vector3(2.5, 1.9, 2.4)], [Vector3(-0.8, 8.4, -3.3), Vector3(2.5, 1.9, 2.4)],
		[Vector3(2.4, 10.4, -2.2), Vector3(2.1, 1.7, 2.0)], [Vector3(-2.3, 10.5, 2.1), Vector3(2.1, 1.7, 2.0)],
		[Vector3(2.6, 7.4, 2.8), Vector3(1.9, 1.5, 1.8)], [Vector3(-2.8, 7.5, -2.5), Vector3(1.9, 1.5, 1.8)],
	]
	if nivel >= 2:
		lob.append([Vector3(2.9, 7.6, -2.6), Vector3(1.8, 1.4, 1.7)])
		lob.append([Vector3(-2.6, 7.7, 2.7), Vector3(1.8, 1.4, 1.7)])
	if nivel <= 0:
		lob = lob.slice(0, 5)
	for i in lob.size():
		V._lobulo(st, lob[i][0], lob[i][1], verdes[i % verdes.size()], 2 if (nivel >= 2 and i == 0) else sub, ruido, 0.17)
	st.generate_normals()
	return st.commit()

## Mulungu: tronco que bifurca, copa aberta e mais clara, cachos de flor laranja-avermelhada por cima.
static func mulungu(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ruido := V._ruido(67, 1.0)
	var casca := Color(0.45, 0.38, 0.30)
	var sub: int = 0 if nivel <= 0 else 1
	V._tronco(st, Vector3(0, -0.2, 0), 2.6, 0.30, 0.20, Vector2(0.1, 0.0), 7 if nivel > 0 else 5, 3 if nivel > 0 else 2, casca)
	_galho(st, Vector3(0, 2.3, 0), Vector3(1.4, 4.6, 0.4), 0.18, 0.08, casca)
	if nivel > 0:
		_galho(st, Vector3(0, 2.3, 0), Vector3(-1.3, 4.8, -0.3), 0.18, 0.08, casca)
		_galho(st, Vector3(0, 2.4, 0), Vector3(0.2, 5.0, -1.3), 0.15, 0.07, casca)
	var verdes := [Color(0.36, 0.52, 0.25), Color(0.40, 0.56, 0.27), Color(0.32, 0.48, 0.24)]
	var lob: Array = [
		[Vector3(1.5, 5.0, 0.4), Vector3(1.6, 1.0, 1.5)], [Vector3(-1.4, 5.2, -0.3), Vector3(1.6, 1.0, 1.5)],
		[Vector3(0.2, 5.4, -1.4), Vector3(1.4, 0.9, 1.4)], [Vector3(0.0, 5.7, 0.9), Vector3(1.3, 0.9, 1.3)],
		[Vector3(0.1, 6.1, 0.0), Vector3(1.2, 0.8, 1.2)],
	]
	var flor := Color(0.90, 0.36, 0.14)
	var n_flor: int = [3, 12, 18][clampi(nivel, 0, 2)]
	if nivel <= 0:
		lob = lob.slice(0, 3)
	for i in lob.size():
		V._lobulo(st, lob[i][0], lob[i][1], verdes[i % verdes.size()], sub, ruido, 0.22)
	var rf := RandomNumberGenerator.new()
	rf.seed = 9
	for k in n_flor:
		var l: Array = lob[k % lob.size()]
		var d := Vector3(rf.randf_range(-1, 1), rf.randf_range(0.15, 1.0), rf.randf_range(-1, 1)).normalized()
		var p: Vector3 = l[0] + Vector3(d.x * l[1].x, d.y * l[1].y, d.z * l[1].z) * 0.86
		# cacho de flor: mancha achatada e irregular (pincelada), não bolinha
		V._lobulo(st, p, Vector3(rf.randf_range(0.45, 0.7), 0.22, rf.randf_range(0.4, 0.6)), flor.lerp(Color(0.80, 0.22, 0.12), rf.randf() * 0.6), 0, ruido, 0.35)
	st.generate_normals()
	return st.commit()

## Leucena: 3 caules finos e uma copa clara de lóbulos pequenos (2,5 a 4 m). Faz o papel de "mato" das encostas.
static func leucena(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ruido := V._ruido(83, 1.3)
	var casca := Color(0.42, 0.36, 0.28)
	var sub: int = 0 if nivel <= 0 else 1
	for k in (3 if nivel > 0 else 2):
		var ang: float = TAU * float(k) / 3.0
		var topo := Vector3(cos(ang) * 0.7, 2.6 + 0.3 * float(k), sin(ang) * 0.7)
		_galho(st, Vector3(cos(ang) * 0.12, -0.2, sin(ang) * 0.12), topo, 0.07, 0.04, casca)
	var verdes := [Color(0.38, 0.55, 0.26), Color(0.43, 0.58, 0.28), Color(0.34, 0.50, 0.24)]
	var lob: Array = [
		[Vector3(0.0, 3.1, 0.0), Vector3(1.3, 0.8, 1.3)], [Vector3(0.8, 2.6, 0.4), Vector3(1.0, 0.75, 1.0)],
		[Vector3(-0.7, 2.7, -0.5), Vector3(1.0, 0.75, 0.95)], [Vector3(0.2, 2.4, -0.9), Vector3(0.9, 0.7, 0.9)],
	]
	if nivel >= 2:
		lob.append([Vector3(-0.4, 2.3, 0.9), Vector3(0.85, 0.65, 0.85)])
	if nivel <= 0:
		lob = lob.slice(0, 2)
	for i in lob.size():
		V._lobulo(st, lob[i][0], lob[i][1], verdes[i % verdes.size()], sub if i == 0 else 0, ruido, 0.24)
	st.generate_normals()
	return st.commit()
