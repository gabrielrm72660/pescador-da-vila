extends RefCounted
## v0.8.5: árvores de Noronha no lugar dos pinheiros (a categoria continua "pinheiros" no mundo salvo e no Construtor). Mesmo jeito das outras malhas de vegetação
## (scripts/vegetacao_malhas.gd): triângulos facetados, cor por vértice, textura de folhagem em guache no material.
##   castanhola - copa em andares horizontais (guarda-chuvas empilhados), algumas folhas vermelhas;
##   gameleira  - a grande: tronco grosso com raízes de apoio, copa redonda e cheia;
##   mulungu    - média, copa aberta, cachos de flor laranja-avermelhada no alto;
##   leucena    - arvoreta/arbusto de vários caules finos, folhagem clara: enche as encostas.
## nível 0 = Baixa/Média (lóbulos de 20 faces, menos peças), 1 = Alta, 2 = Ultra (mais lóbulos e mais subdivisão).
## v0.9.3: a copa deixou de ser só lóbulos lisos (pareciam cartolina). Cada malha tem agora DUAS superfícies:
##   0 = tronco, galhos e o miolo da copa (lóbulos menores e mais escuros, que tapam o buraco entre as folhas);
##   1 = cartas de folha: quadrados com cachos de folha pintados (atlas do SpriteCook, recortados pela transparência),
##       espalhados pela casca de cada lóbulo, virados para fora. Material: shaders/folhas_cartas.gdshader (ilha.gd).
## Atlas assets/texturas/ilha/folhas.png: 4 colunas x 5 linhas, uma linha por espécie e a última com folha vermelha
## (colunas 0-1) e flor de mulungu (2-3).

const V = preload("res://scripts/vegetacao_malhas.gd")

static func criar(chave: String, nivel: int) -> ArrayMesh:
	match chave:
		"castanhola": return castanhola(nivel)
		"gameleira": return gameleira(nivel)
		"mulungu": return mulungu(nivel)
		"leucena": return leucena(nivel)
		"arvore": return arvore_nativa(nivel)
		"moita": return moita(nivel)
	return null

const CASCA := Color(0.33, 0.25, 0.18)
const ATLAS_COLUNAS := 4
const ATLAS_LINHAS := 5
const LINHA := {"castanhola": 0, "gameleira": 1, "mulungu": 2, "leucena": 3, "destaque": 4}
const MIOLO := 0.58          # o lóbulo vira miolo: encolhe e escurece, as cartas fazem o contorno
const BRANCO := Color(1, 1, 1)

## Cartas por lóbulo em cada nível (Baixa/Média, Alta, Ultra).
static func _por_lobulo(nivel: int, base: int) -> int:
	return maxi(3, roundi(float(base) * [0.45, 1.0, 1.45][clampi(nivel, 0, 2)]))

## Uma carta de folha: quadrado de lado `tam` em `p`, com a frente virada para `n` (girada `giro` em volta de n).
## A normal dos 4 cantos é `normal_luz` (a direção do centro da copa para fora): a copa inteira sombreia como uma bola.
static func _carta(sf: SurfaceTool, p: Vector3, n: Vector3, tam: float, giro: float, celula: Vector2i, cor: Color, normal_luz: Vector3) -> void:
	var a: Vector3 = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var b: Vector3 = n.cross(a).normalized()
	var x: Vector3 = (a * cos(giro) + b * sin(giro)) * tam * 0.5
	var y: Vector3 = (b * cos(giro) - a * sin(giro)) * tam * 0.5
	var du: float = 1.0 / float(ATLAS_COLUNAS)
	var dv: float = 1.0 / float(ATLAS_LINHAS)
	var u0: float = float(celula.x) * du + 0.004
	var v0: float = float(celula.y) * dv + 0.004
	var u1: float = u0 + du - 0.008
	var v1: float = v0 + dv - 0.008
	var cantos := [p - x + y, p + x + y, p + x - y, p - x - y]
	var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)]
	for i in [0, 1, 2, 0, 2, 3]:
		sf.set_normal(normal_luz)
		sf.set_color(cor)
		sf.set_uv(uvs[i])
		sf.add_vertex(cantos[i])

## Espalha `n` cartas pela casca de um lóbulo (centro, raios). As de cima ficam mais claras, as de baixo mais escuras,
## e cada uma puxa uma das 4 células da linha da espécie. `centro_copa` dá a direção da normal (para fora da copa).
static func _cartas(sf: SurfaceTool, rf: RandomNumberGenerator, centro: Vector3, ext: Vector3, n: int, cor: Color, linha: int, centro_copa: Vector3, tam_rel: float = 1.0) -> void:
	var raio_medio: float = (ext.x + ext.y + ext.z) / 3.0
	for k in n:
		# direção na esfera, com mais cartas em cima e nos lados do que embaixo
		var d := Vector3(rf.randf_range(-1, 1), rf.randf_range(-0.55, 1.0), rf.randf_range(-1, 1))
		if d.length() < 0.05:
			d = Vector3.UP
		d = d.normalized()
		var p: Vector3 = centro + Vector3(d.x * ext.x, d.y * ext.y, d.z * ext.z) * rf.randf_range(0.70, 1.05)
		var fora: Vector3 = (p - centro_copa).normalized()
		var frente: Vector3 = (d + Vector3(rf.randf_range(-0.5, 0.5), rf.randf_range(-0.3, 0.5), rf.randf_range(-0.5, 0.5))).normalized()
		var luz: float = clampf(0.5 + 0.5 * d.y, 0.0, 1.0)
		var c: Color = cor.darkened(0.30).lerp(cor.lerp(Color(0.80, 0.86, 0.40), 0.12), pow(luz, 0.8))
		c = c.lightened(rf.randf_range(-0.05, 0.08))
		var tam: float = raio_medio * tam_rel * rf.randf_range(0.85, 1.25)
		_carta(sf, p, frente, tam, rf.randf_range(0.0, TAU), Vector2i(rf.randi_range(0, 3), linha), c, (fora + d * 0.5).normalized())

## Cartas de destaque (folha vermelha da castanhola, flor do mulungu): cor do atlas, vértice branco.
static func _destaques(sf: SurfaceTool, rf: RandomNumberGenerator, centro: Vector3, ext: Vector3, n: int, colunas: Vector2i, centro_copa: Vector3, tam: float) -> void:
	for k in n:
		var d := Vector3(rf.randf_range(-1, 1), rf.randf_range(0.25, 1.0), rf.randf_range(-1, 1)).normalized()
		var p: Vector3 = centro + Vector3(d.x * ext.x, d.y * ext.y, d.z * ext.z) * rf.randf_range(0.92, 1.08)
		var fora: Vector3 = (p - centro_copa).normalized()
		_carta(sf, p, (d + Vector3.UP * 0.4).normalized(), tam * rf.randf_range(0.8, 1.15), rf.randf_range(0.0, TAU),
				Vector2i(rf.randi_range(colunas.x, colunas.y), LINHA["destaque"]), BRANCO.darkened(rf.randf_range(0.0, 0.12)), fora)

## Junta as duas superfícies numa malha só (a das cartas só entra se tiver alguma carta).
static func _fechar(st: SurfaceTool, sf: SurfaceTool, cartas: int) -> ArrayMesh:
	st.generate_normals()
	var malha: ArrayMesh = st.commit()
	if cartas > 0:
		sf.commit(malha)
	return malha

static func _nova_superficie() -> SurfaceTool:
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	return sf

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
	var sf := _nova_superficie()
	var cartas := 0
	var ruido := V._ruido(41, 0.9)
	var leve: bool = nivel <= 0
	V._tronco(st, Vector3(0, -0.2, 0), 6.6, 0.30, 0.12, Vector2(0.2, 0.1), 6 if not leve else 4, 3 if not leve else 2, CASCA)
	var verde := [Color(0.25, 0.46, 0.22), Color(0.30, 0.50, 0.23), Color(0.22, 0.41, 0.21)]
	var andares := [[3.9, 3.7, 0.85], [5.1, 2.9, 0.80], [6.2, 2.0, 0.75]]       # altura, raio, espessura
	var n_lob: int = [3, 4, 5][clampi(nivel, 0, 2)]
	var rf := RandomNumberGenerator.new()
	rf.seed = 4
	var rc := RandomNumberGenerator.new()
	rc.seed = 104
	var i := 0
	for a in andares:
		var y: float = a[0]
		var r: float = a[1]
		var e: float = a[2]
		var meio := Vector3(0, y + 0.1, 0)
		# miolo do andar + lóbulos em roda; as cartas de folha (rosetas largas) cobrem tudo e fazem o contorno recortado
		var ext0 := Vector3(r * 0.72, e, r * 0.72)
		V._lobulo(st, meio, ext0 * MIOLO, (verde[i % 3] as Color).darkened(0.15), 0 if leve else 1, ruido, 0.20)
		var n0: int = _por_lobulo(nivel, 18)
		_cartas(sf, rc, meio, ext0, n0, verde[i % 3], LINHA["castanhola"], meio + Vector3.DOWN * 0.6, 0.75)
		cartas += n0
		for k in n_lob:
			var ang: float = TAU * float(k) / float(n_lob) + 0.7 * float(i)
			var c := Vector3(cos(ang), 0, sin(ang)) * r * 0.55 + Vector3.UP * y
			if not leve and k % 2 == 0:
				_galho(st, Vector3(0, y - 0.35, 0), c + Vector3.UP * -0.1, 0.07, 0.03, CASCA, 4)
			var ext := Vector3(r * 0.5, e * 0.85, r * 0.48)
			var cor: Color = verde[(k + i) % verde.size()]
			V._lobulo(st, c, ext * MIOLO, cor.darkened(0.15), 0, ruido, 0.26)
			var nk: int = _por_lobulo(nivel, 12)
			_cartas(sf, rc, c, ext, nk, cor, LINHA["castanhola"], meio + Vector3.DOWN * 0.6, 1.0)
			cartas += nk
			i += 1
		# folhas velhas vermelhas por cima de cada andar (a castanhola avermelha antes de cair)
		var nv: int = [1, 3, 4][clampi(nivel, 0, 2)]
		_destaques(sf, rf, meio, Vector3(r * 0.8, e * 0.9, r * 0.8), nv, Vector2i(0, 1), meio, 0.95)
		cartas += nv
	return _fechar(st, sf, cartas)

## Gameleira: a maior. Tronco grosso, raízes de apoio em leque, galhos abertos e copa redonda de muitos lóbulos.
static func gameleira(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sf := _nova_superficie()
	var cartas := 0
	var rc := RandomNumberGenerator.new()
	rc.seed = 153
	var ruido := V._ruido(53, 0.7)
	var casca := Color(0.42, 0.38, 0.32)                     # figueira: casca acinzentada
	var sub: int = 0 if nivel <= 0 else 1
	V._tronco(st, Vector3(0, -0.3, 0), 5.4, 0.85, 0.48, Vector2(0.2, 0.0), 9 if nivel > 0 else 6, 4 if nivel > 0 else 2, casca)
	for k in (6 if nivel > 0 else 0):                         # raízes de apoio
		var ang: float = TAU * float(k) / 6.0 + 0.3
		var fora := Vector3(cos(ang), 0, sin(ang))
		_galho(st, fora * 0.5 + Vector3.UP * 1.8, fora * 2.1 + Vector3.DOWN * 0.3, 0.22, 0.10, casca.darkened(0.08))
	for k in (5 if nivel > 0 else 3):                         # galhos grossos que abrem
		var ang: float = TAU * float(k) / float(5 if nivel > 0 else 3)
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
		lob = lob.slice(0, 7)
	var centro_copa := Vector3(0, 8.4, 0)
	for i in lob.size():
		var cor: Color = verdes[i % verdes.size()]
		V._lobulo(st, lob[i][0], lob[i][1] * MIOLO, cor.darkened(0.15), 2 if (nivel >= 2 and i == 0) else sub, ruido, 0.17)
		var n: int = _por_lobulo(nivel, 34 if i == 0 else 20)
		_cartas(sf, rc, lob[i][0], lob[i][1], n, cor, LINHA["gameleira"], centro_copa, 0.85)
		cartas += n
	return _fechar(st, sf, cartas)

## Mulungu: tronco que bifurca, copa aberta e mais clara, cachos de flor laranja-avermelhada por cima.
static func mulungu(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sf := _nova_superficie()
	var cartas := 0
	var rc := RandomNumberGenerator.new()
	rc.seed = 167
	var ruido := V._ruido(67, 1.0)
	var casca := Color(0.45, 0.38, 0.30)
	var sub: int = 0 if nivel <= 0 else 1
	V._tronco(st, Vector3(0, -0.2, 0), 2.6, 0.30, 0.20, Vector2(0.1, 0.0), 7 if nivel > 0 else 5, 3 if nivel > 0 else 2, casca)
	_galho(st, Vector3(0, 2.3, 0), Vector3(1.4, 4.6, 0.4), 0.18, 0.08, casca)
	_galho(st, Vector3(0, 2.3, 0), Vector3(-1.3, 4.8, -0.3), 0.18, 0.08, casca)
	if nivel > 0:
		_galho(st, Vector3(0, 2.4, 0), Vector3(0.2, 5.0, -1.3), 0.15, 0.07, casca)
	var verdes := [Color(0.36, 0.52, 0.25), Color(0.40, 0.56, 0.27), Color(0.32, 0.48, 0.24)]
	var lob: Array = [
		[Vector3(1.5, 5.0, 0.4), Vector3(1.6, 1.0, 1.5)], [Vector3(-1.4, 5.2, -0.3), Vector3(1.6, 1.0, 1.5)],
		[Vector3(0.2, 5.4, -1.4), Vector3(1.4, 0.9, 1.4)], [Vector3(0.0, 5.7, 0.9), Vector3(1.3, 0.9, 1.3)],
		[Vector3(0.1, 6.1, 0.0), Vector3(1.2, 0.8, 1.2)],
	]
	if nivel <= 0:
		lob = lob.slice(0, 4)
	var centro_copa := Vector3(0, 5.0, 0)
	for i in lob.size():
		var cor: Color = verdes[i % verdes.size()]
		V._lobulo(st, lob[i][0], lob[i][1] * MIOLO, cor.darkened(0.12), sub, ruido, 0.22)
		var n: int = _por_lobulo(nivel, 15)
		_cartas(sf, rc, lob[i][0], lob[i][1], n, cor, LINHA["mulungu"], centro_copa, 1.1)
		cartas += n
	# cachos de flor por cima (cartas coloridas do atlas)
	var rf := RandomNumberGenerator.new()
	rf.seed = 9
	var n_flor: int = [4, 10, 14][clampi(nivel, 0, 2)]
	for k in n_flor:
		var l: Array = lob[k % lob.size()]
		_destaques(sf, rf, l[0], l[1], 1, Vector2i(2, 3), centro_copa, 0.75)
	cartas += n_flor
	return _fechar(st, sf, cartas)

## Leucena: 3 caules finos e uma copa clara de lóbulos pequenos (2,5 a 4 m). Faz o papel de "mato" das encostas.
static func leucena(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sf := _nova_superficie()
	var cartas := 0
	var rc := RandomNumberGenerator.new()
	rc.seed = 183
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
		lob = lob.slice(0, 3)
	var centro_copa := Vector3(0, 2.4, 0)
	for i in lob.size():
		var cor: Color = verdes[i % verdes.size()]
		V._lobulo(st, lob[i][0], lob[i][1] * MIOLO, cor.darkened(0.12), sub if i == 0 else 0, ruido, 0.24)
		var n: int = _por_lobulo(nivel, 13)
		_cartas(sf, rc, lob[i][0], lob[i][1], n, cor, LINHA["leucena"], centro_copa, 1.15)
		cartas += n
	return _fechar(st, sf, cartas)

## v0.9.3: a árvore nativa da vila e as moitas (antes em vegetacao_malhas.gd, só lóbulos lisos) também ganham folhas.
## Mesmos lóbulos de antes; as cartas usam a linha da gameleira (folhinha oval), na moita a da leucena misturada.
static func arvore_nativa(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sf := _nova_superficie()
	var cartas := 0
	var rc := RandomNumberGenerator.new()
	rc.seed = 131
	var casca := Color(0.31, 0.24, 0.17)
	V._tronco(st, Vector3(0, -0.2, 0), 3.6, 0.34, 0.17, Vector2(0.35, 0.0), 8, 4, casca)
	V._tronco(st, Vector3(0.30, 3.1, 0.0), 2.0, 0.15, 0.08, Vector2(1.3, 0.5), 6, 3, casca)
	V._tronco(st, Vector3(0.30, 3.2, 0.0), 1.9, 0.14, 0.07, Vector2(-1.6, -0.3), 6, 3, casca)
	var ruido := V._ruido(31, 0.8)
	var verdes := [Color(0.27, 0.46, 0.26), Color(0.34, 0.52, 0.28), Color(0.23, 0.40, 0.25), Color(0.31, 0.50, 0.24)]
	var lobulos: Array = [
		[Vector3(0.1, 5.1, 0.0), Vector3(2.0, 1.55, 1.9)],
		[Vector3(1.6, 4.5, 0.6), Vector3(1.55, 1.2, 1.45)], [Vector3(-1.5, 4.7, -0.4), Vector3(1.5, 1.2, 1.4)],
		[Vector3(0.5, 4.3, -1.5), Vector3(1.35, 1.05, 1.3)], [Vector3(-0.3, 4.3, 1.5), Vector3(1.35, 1.0, 1.3)],
		[Vector3(1.1, 6.0, -0.5), Vector3(1.25, 1.0, 1.2)], [Vector3(-1.0, 6.0, 0.6), Vector3(1.2, 0.95, 1.15)],
	]
	if nivel >= 2:
		lobulos.append([Vector3(2.4, 5.0, -0.9), Vector3(1.0, 0.85, 1.0)])
		lobulos.append([Vector3(-2.3, 5.2, 0.5), Vector3(1.0, 0.85, 1.0)])
	var centro_copa := Vector3(0, 4.9, 0)
	for i in lobulos.size():
		var cor: Color = verdes[i % verdes.size()]
		V._lobulo(st, lobulos[i][0], lobulos[i][1] * MIOLO, cor.darkened(0.15), 1, ruido, 0.16)
		var n: int = _por_lobulo(nivel, 22 if i == 0 else 14)
		_cartas(sf, rc, lobulos[i][0], lobulos[i][1], n, cor, LINHA["gameleira"], centro_copa, 0.85)
		cartas += n
	return _fechar(st, sf, cartas)

static func moita(nivel: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sf := _nova_superficie()
	var cartas := 0
	var rc := RandomNumberGenerator.new()
	rc.seed = 177
	var ruido := V._ruido(77, 1.1)
	var base := Color(0.92, 0.97, 0.88)               # quase branco: a cor de cada moita vem da instância (ilha.gd)
	var lobulos: Array = [
		[Vector3(0.0, 0.40, 0.0), Vector3(0.85, 0.62, 0.85)],
		[Vector3(0.50, 0.28, 0.25), Vector3(0.58, 0.44, 0.58)],
		[Vector3(-0.42, 0.30, -0.22), Vector3(0.55, 0.42, 0.55)],
	]
	if nivel >= 2:
		lobulos.append([Vector3(0.05, 0.30, -0.55), Vector3(0.5, 0.38, 0.5)])
	var centro_copa := Vector3(0, 0.2, 0)
	for i in lobulos.size():
		var cor: Color = base.darkened(0.04 * float(i))
		V._lobulo(st, lobulos[i][0], lobulos[i][1] * 0.7, cor.darkened(0.18), 1, ruido, 0.20)
		var n: int = _por_lobulo(nivel, 12 if i == 0 else 8)
		_cartas(sf, rc, lobulos[i][0], lobulos[i][1], n, cor, LINHA["gameleira"] if i % 2 == 0 else LINHA["mulungu"], centro_copa, 1.1)
		cartas += n
	return _fechar(st, sf, cartas)
