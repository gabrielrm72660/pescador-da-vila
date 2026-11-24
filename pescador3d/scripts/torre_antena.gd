extends Node3D
## v0.8.3: torre de telecomunicações treliçada (vermelha e branca) da Ilha das Rocas.
## Tudo numa malha só com cor por vértice (sem textura), mais as luzes de balizamento vermelhas.
## Base no (0,0,0) local: quem cria posiciona no chão.

const Estilos = preload("res://scripts/barcos_npc_estilos.gd")

const ALTURA_TRELICA := 18.0       # m, parte quadrada treliçada
const FAIXAS_TRELICA := 7
const ALTURA_MASTRO := 6.0         # m, mastro fino em cima da plataforma
const FAIXAS_MASTRO := 4
const PARA_RAIOS := 2.6
const MEIA_BASE := 1.65            # m, meia largura da base
const MEIA_TOPO := 0.62

const VERMELHO := Color(0.78, 0.16, 0.12)
const BRANCO := Color(0.93, 0.92, 0.89)
const CINZA := Color(0.62, 0.63, 0.64)
const CINZA_ESCURO := Color(0.30, 0.31, 0.33)
const CONCRETO := Color(0.70, 0.68, 0.63)

var _balizas: Array = []           # MeshInstance3D das luzes vermelhas (piscam)
var _mat_baliza: StandardMaterial3D
var _mat_halo: StandardMaterial3D
var _tempo := 0.0

func _ready() -> void:
	var m := Estilos.Montador.new()
	_base(m)
	_trelica(m)
	_plataforma(m)
	_mastro(m)
	_antenas(m)
	var corpo := MeshInstance3D.new()
	corpo.name = "Torre"
	corpo.mesh = m.malha()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.78
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	corpo.material_override = mat
	add_child(corpo)
	_criar_balizas()

func _meia(y: float) -> float:
	return lerpf(MEIA_BASE, MEIA_TOPO, clampf(y / ALTURA_TRELICA, 0.0, 1.0))

func _canto(k: int, y: float) -> Vector3:
	var h := _meia(y)
	var sx: float = [1.0, -1.0, -1.0, 1.0][k]
	var sz: float = [1.0, 1.0, -1.0, -1.0][k]
	return Vector3(sx * h, y, sz * h)

func _faixa(i: int) -> Color:
	return VERMELHO if i % 2 == 0 else BRANCO

## Altura do chão (relativa à base da torre) num ponto local; quem cria pode passar "chao" para assentar no morro.
var chao: Callable = Callable()

func _h(x: float, z: float) -> float:
	return float(chao.call(x, z)) if chao.is_valid() else 0.0

## Bloco de concreto do chão (mais fundo onde o terreno desce) até a cota "topo".
func _sapata(m, cx: float, cz: float, meia: Vector2, topo: float, cor: Color) -> void:
	var fundo := topo
	for o in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2.ZERO]:
		fundo = minf(fundo, _h(cx + o.x * meia.x, cz + o.y * meia.y))
	fundo -= 0.4
	m.caixa(Vector3(cx, (topo + fundo) * 0.5, cz), Vector3(meia.x * 2.0, topo - fundo, meia.y * 2.0), cor)

func _base(m) -> void:
	_sapata(m, 0.0, 0.0, Vector2(2.6, 2.6), 0.1, CONCRETO)
	for k in 4:
		var p := _canto(k, 0.0)
		m.caixa(Vector3(p.x, 0.35, p.z), Vector3(0.55, 0.5, 0.55), CONCRETO.darkened(0.08))
	# abrigo dos equipamentos (sobre um radier) + ar-condicionado
	_sapata(m, 4.6, 0.3, Vector2(1.5, 1.8), 0.1, CONCRETO.darkened(0.04))
	m.caixa(Vector3(4.6, 1.35, 0.3), Vector3(2.6, 2.5, 3.2), Color(0.86, 0.86, 0.83))
	m.caixa(Vector3(4.6, 2.68, 0.3), Vector3(2.8, 0.16, 3.4), CINZA)
	m.caixa(Vector3(4.6, 1.15, -1.32), Vector3(0.9, 1.9, 0.06), CINZA_ESCURO)       # porta
	m.caixa(Vector3(5.98, 1.7, 0.6), Vector3(0.3, 0.7, 0.9), CINZA)                  # ar-condicionado
	# esteira de cabos do abrigo até a torre
	m.caixa(Vector3(2.4, 2.3, 0.3), Vector3(2.0, 0.08, 0.35), CINZA)
	# alambrado em volta (torre + abrigo): cada mourão no chão, as fiadas acompanham o terreno
	var cs := [Vector3(-3.4, 0, -3.4), Vector3(6.9, 0, -3.4), Vector3(6.9, 0, 3.4), Vector3(-3.4, 0, 3.4)]
	for k in 4:
		var a: Vector3 = cs[k]
		var b: Vector3 = cs[(k + 1) % 4]
		var vaos := int(ceil(a.distance_to(b) / 2.0))
		var ant := Vector3.ZERO
		for t in vaos + 1:
			var p: Vector3 = a.lerp(b, float(t) / float(vaos))
			p.y = _h(p.x, p.z)
			if t < vaos:
				m.haste(p + Vector3.DOWN * 0.4, p + Vector3.UP * 1.9, 0.035, CINZA)
			if t > 0:
				for alt in [0.15, 1.0, 1.85]:
					m.haste(ant + Vector3.UP * alt, p + Vector3.UP * alt, 0.018, CINZA)
			ant = p

func _trelica(m) -> void:
	var seg := ALTURA_TRELICA / float(FAIXAS_TRELICA)
	for i in FAIXAS_TRELICA:
		var y0 := seg * float(i)
		var y1 := y0 + seg
		var cor := _faixa(i)
		for k in 4:
			var a0 := _canto(k, y0)
			var a1 := _canto(k, y1)
			var b0 := _canto((k + 1) % 4, y0)
			var b1 := _canto((k + 1) % 4, y1)
			m.haste(a0, a1, 0.075, cor)                      # perna
			m.haste(a1, b1, 0.045, cor)                      # anel
			m.haste(a0, b1, 0.035, cor)                      # X
			m.haste(b0, a1, 0.035, cor)
			# travessa no meio da faixa (cara de treliça de verdade)
			var am := _canto(k, (y0 + y1) * 0.5)
			var bm := _canto((k + 1) % 4, (y0 + y1) * 0.5)
			m.haste(am, bm, 0.025, cor)
	# escada / esteira de cabos numa face
	var f0 := Vector3(0.0, 0.6, _meia(0.3) + 0.12)
	var f1 := Vector3(0.0, ALTURA_TRELICA, _meia(ALTURA_TRELICA) + 0.12)
	for s in [-0.2, 0.2]:
		m.haste(f0 + Vector3(s, 0, 0), f1 + Vector3(s, 0, 0), 0.02, CINZA)
	var degraus := int(ALTURA_TRELICA / 0.6)
	for d in degraus:
		var p := f0.lerp(f1, float(d) / float(degraus))
		m.haste(p + Vector3(-0.2, 0, 0), p + Vector3(0.2, 0, 0), 0.012, CINZA)

func _plataforma(m) -> void:
	var y := ALTURA_TRELICA
	var h := 1.25
	m.caixa(Vector3(0, y + 0.05, 0), Vector3(h * 2.0, 0.1, h * 2.0), CINZA)
	var cs := [Vector3(h, 0, h), Vector3(-h, 0, h), Vector3(-h, 0, -h), Vector3(h, 0, -h)]
	for k in 4:
		var a: Vector3 = cs[k] + Vector3.UP * y
		var b: Vector3 = cs[(k + 1) % 4] + Vector3.UP * y
		m.haste(a, a + Vector3.UP * 1.05, 0.03, CINZA)
		m.haste(a.lerp(b, 0.5), a.lerp(b, 0.5) + Vector3.UP * 1.05, 0.025, CINZA)
		m.haste(a + Vector3.UP * 1.05, b + Vector3.UP * 1.05, 0.03, CINZA)
		m.haste(a + Vector3.UP * 0.55, b + Vector3.UP * 0.55, 0.02, CINZA)
		m.haste(_canto(k, y - 1.2), a + Vector3.UP * 0.05, 0.035, CINZA)      # mão-francesa

func _mastro(m) -> void:
	var y0 := ALTURA_TRELICA
	var seg := ALTURA_MASTRO / float(FAIXAS_MASTRO)
	for i in FAIXAS_MASTRO:
		# a faixa de cima do mastro termina vermelha
		var cor := BRANCO if i % 2 == 0 else VERMELHO
		m.haste(Vector3(0, y0 + seg * i, 0), Vector3(0, y0 + seg * (i + 1), 0), 0.2 - 0.02 * i, cor)
	var topo := y0 + ALTURA_MASTRO
	m.caixa(Vector3(0, topo + 0.05, 0), Vector3(0.5, 0.1, 0.5), CINZA)
	m.haste(Vector3(0, topo, 0), Vector3(0, topo + PARA_RAIOS, 0), 0.03, CINZA)
	m.esfera(Vector3(0, topo + PARA_RAIOS, 0), 0.06, CINZA)

## Painéis setoriais (3 setores), RRUs e os tambores de micro-ondas.
func _antenas(m) -> void:
	# setores grandes na altura da plataforma
	for s in 3:
		var ang := TAU * float(s) / 3.0 + 0.3
		var dir := Vector3(cos(ang), 0, sin(ang))
		var r := _meia(ALTURA_TRELICA) + 0.95
		var c := dir * r + Vector3.UP * (ALTURA_TRELICA + 1.25)
		m.haste(dir * (r - 0.15) + Vector3.UP * (ALTURA_TRELICA - 0.3), dir * (r - 0.15) + Vector3.UP * (ALTURA_TRELICA + 2.3), 0.04, CINZA)
		for lado in [-0.42, 0.42]:
			var off: Vector3 = Vector3(-dir.z, 0, dir.x) * float(lado)
			_painel(m, c + off, dir, Vector3(0.34, 1.6, 0.13))
			_painel(m, c + off - dir * 0.32 + Vector3.DOWN * 0.95, dir, Vector3(0.28, 0.42, 0.18), CINZA)   # RRU
	# setores menores no mastro
	for s in 3:
		var ang := TAU * float(s) / 3.0 + 0.3 + PI / 3.0
		var dir := Vector3(cos(ang), 0, sin(ang))
		var c := dir * 0.55 + Vector3.UP * (ALTURA_TRELICA + 4.2)
		m.haste(Vector3.UP * (ALTURA_TRELICA + 4.2), c - dir * 0.08, 0.03, CINZA)
		_painel(m, c, dir, Vector3(0.26, 1.15, 0.1))
	# tambores de micro-ondas (radome branco), presos nas pernas
	var tambores := [[12.4, 0.0, 0.62], [12.4, PI * 0.5, 0.5], [9.6, PI * 1.25, 0.5], [15.2, PI * 1.6, 0.42]]
	for t in tambores:
		var y: float = float(t[0])
		var dir := Vector3(cos(float(t[1])), 0, sin(float(t[1])))
		var raio: float = t[2]
		var centro := dir * (_meia(y) * 1.3 + 0.45) + Vector3.UP * y
		m.haste(centro - dir * 0.18, centro + dir * 0.22, raio, BRANCO)
		m.haste(centro - dir * 0.18, centro - dir * 0.36, raio * 0.55, CINZA_ESCURO)
		m.haste(centro - dir * 0.36, dir * _meia(y) * 0.95 + Vector3.UP * y, 0.04, CINZA)

func _painel(m, centro: Vector3, dir: Vector3, tam: Vector3, cor := BRANCO) -> void:
	# caixa virada para fora (frente = dir); o Montador só tem caixa alinhada, então aproxima com hastes finas e largas
	var lado := Vector3(-dir.z, 0, dir.x)
	var meio := tam.y * 0.5
	var x := lado * tam.x * 0.5
	# duas "lâminas" que formam um painel retangular
	m.haste(centro + Vector3.DOWN * meio, centro + Vector3.UP * meio, tam.z * 0.6, cor)
	m.haste(centro + x * 0.55 + Vector3.DOWN * meio, centro + x * 0.55 + Vector3.UP * meio, tam.z * 0.6, cor)
	m.haste(centro - x * 0.55 + Vector3.DOWN * meio, centro - x * 0.55 + Vector3.UP * meio, tam.z * 0.6, cor)

func _criar_balizas() -> void:
	_mat_baliza = StandardMaterial3D.new()
	_mat_baliza.albedo_color = Color(0.9, 0.08, 0.05)
	_mat_baliza.emission_enabled = true
	_mat_baliza.emission = Color(1.0, 0.1, 0.05)
	_mat_baliza.emission_energy_multiplier = 3.0
	var esf := SphereMesh.new()
	esf.radius = 0.14
	esf.height = 0.28
	esf.radial_segments = 8
	esf.rings = 4
	var pontos := [Vector3(0, ALTURA_TRELICA + ALTURA_MASTRO + 0.22, 0)]
	for k in 4:
		var c := _canto(k, ALTURA_TRELICA)
		pontos.append(Vector3(c.x * 2.0, ALTURA_TRELICA + 1.15, c.z * 2.0))
		var c2 := _canto(k, ALTURA_TRELICA * 0.5)
		pontos.append(c2 * Vector3(1.08, 1.0, 1.08) + Vector3.UP * 0.1)
	# halo: brilho em volta da lâmpada que aparece de longe à noite (atravessa a névoa)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.35, 0.25, 1.0))
	grad.set_color(1, Color(1.0, 0.05, 0.02, 0.0))
	grad.add_point(0.18, Color(1.0, 0.2, 0.12, 0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_mat_halo = StandardMaterial3D.new()
	_mat_halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat_halo.albedo_texture = tex
	_mat_halo.disable_fog = true
	_mat_halo.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2(2.2, 2.2)
	for i in pontos.size():
		var p: Vector3 = pontos[i]
		var b := MeshInstance3D.new()
		b.mesh = esf
		b.material_override = _mat_baliza
		b.position = p
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var h := MeshInstance3D.new()
		h.name = "Halo"
		h.mesh = quad
		h.material_override = _mat_halo
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.scale = Vector3.ONE * (1.6 if i == 0 else 1.0)
		h.visible = false
		b.add_child(h)
		add_child(b)
		_balizas.append(b)
	var luz := OmniLight3D.new()
	luz.name = "LuzBaliza"
	luz.light_color = Color(1.0, 0.15, 0.08)
	luz.omni_range = 9.0
	luz.light_energy = 1.5
	luz.position = pontos[0]
	add_child(luz)

## noite: 0..1 (o jogo passa a escuridão). De dia a baliza fica apagada; à noite pisca devagar.
func definir_noite(noite: float) -> void:
	_mat_baliza.emission_energy_multiplier = lerpf(0.4, 4.0, noite)
	($LuzBaliza as OmniLight3D).visible = noite > 0.3
	_mat_halo.albedo_color = Color(1, 1, 1, clampf((noite - 0.2) / 0.6, 0.0, 1.0))
	for b in _balizas:
		(b.get_node("Halo") as Node3D).visible = noite > 0.2

func _process(delta: float) -> void:
	_tempo += delta
	var aceso: bool = fmod(_tempo, 1.6) < 0.9
	for b in _balizas:
		(b as MeshInstance3D).visible = aceso
