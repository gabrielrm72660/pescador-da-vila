extends Node3D
## v0.8.0: grupo de golfinhos-rotadores (o golfinho de Noronha). Malha feita da pintura de lado do SpriteCook
## (ferramentas/cetaceos.py), corpo ondulando no shader (shaders/cetaceo.gdshader).
##  - nadam em grupo (um puxa, os outros seguem em formação solta), rápidos, rompendo a superfície em arcos curtos;
##  - de tempos em tempos um salta para fora d'água; às vezes é o salto do rotador: gira 2 a 4 voltas no ar;
##  - se o barco do jogador passa perto e rápido, o grupo vem surfar na onda da proa por um tempo.
## Quem liga/desliga é fauna_costeira.gd (simulando) e reiniciar().

const FaunaMalha = preload("res://scripts/fauna_malha.gd")
const QUANTOS := 4
const VEL_CRUZEIRO := 4.2          # m/s
const GRAVIDADE := 9.8

var simulando: bool = false
var _barco: Node3D
var _oceano: Node
var _mundo: Node
var _bichos: Array = []            # {no, mat, deslocado, prof, vy, no_ar, giro, voltas, fase, prox_salto, pos}
var _lider := Vector3.ZERO
var _rumo := Vector2(1, 0)
var _rumo_alvo := 0.0
var _proxima_curva := 8.0
var _surfando := 0.0              # s que ainda vão ficar na proa do barco
var _tempo := 0.0
var _respingo: CPUParticles3D

func construir(barco: Node3D, oceano: Node, mundo: Node) -> void:
	_barco = barco
	_oceano = oceano
	_mundo = mundo
	for k in QUANTOS:
		var no := Node3D.new()
		no.name = "Golfinho%d" % k
		add_child(no)
		var corpo: MeshInstance3D = FaunaMalha.instancia("golfinho")
		corpo.visibility_range_end = 420.0
		no.add_child(corpo)
		var esc: float = randf_range(0.88, 1.08)
		_bichos.append({"no": no, "mat": corpo.material_override, "esc": esc,
			"forma": Vector2(randf_range(-4.0, 4.0), randf_range(1.5, 9.0)) if k > 0 else Vector2.ZERO,
			"pos": Vector3.ZERO, "vy": 0.0, "no_ar": false, "giro": 0.0, "voltas": 0.0, "fase": randf() * TAU,
			"prox_salto": randf_range(3.0, 12.0), "rumo": Vector2(1, 0), "arf": 0.0, "v_salto": 0.0})
	_respingo = CPUParticles3D.new()
	_respingo.name = "Respingo"
	_respingo.amount = 28
	_respingo.lifetime = 0.9
	_respingo.one_shot = true
	_respingo.explosiveness = 0.9
	_respingo.emitting = false
	_respingo.top_level = true
	_respingo.direction = Vector3.UP
	_respingo.spread = 45.0
	_respingo.gravity = Vector3(0, -9.0, 0)
	_respingo.initial_velocity_min = 2.0
	_respingo.initial_velocity_max = 4.5
	_respingo.scale_amount_min = 0.5
	_respingo.scale_amount_max = 1.1
	var gota := SphereMesh.new()
	gota.radius = 0.05
	gota.height = 0.1
	gota.radial_segments = 5
	gota.rings = 3
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(0.92, 0.97, 1.0, 0.7)
	gota.material = gm
	_respingo.mesh = gota
	add_child(_respingo)
	reiniciar()

func reiniciar() -> void:
	if _barco == null:
		return
	_lider = _posicao_segura(70.0, 170.0)
	_rumo = Vector2.from_angle(randf_range(0.0, TAU))
	_rumo_alvo = _rumo.angle()
	_surfando = 0.0
	for b in _bichos:
		b.pos = _lider + Vector3(b.forma.x, 0.0, b.forma.y)
		b.no_ar = false
		b.giro = 0.0
		b.rumo = _rumo

func _posicao_segura(dmin: float, dmax: float) -> Vector3:
	var origem: Vector3 = _barco.global_position
	for _k in 16:
		var ang: float = randf_range(0.0, TAU)
		var dist: float = randf_range(dmin, dmax)
		var p: Vector3 = origem + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		if _mundo != null and _mundo.has_method("altura_terra") and float(_mundo.altura_terra(p)) > -4.5:
			continue
		return p
	return origem + Vector3(120, 0, 40)

func _agua(p: Vector3) -> float:
	return float(_oceano.altura_em(p)) if _oceano != null else 0.0

func _respingar(p: Vector3) -> void:
	_respingo.global_position = Vector3(p.x, _agua(p) + 0.05, p.z)
	_respingo.restart()
	_respingo.emitting = true

func _process(delta: float) -> void:
	if not simulando or _barco == null or _bichos.is_empty():
		return
	var dt: float = minf(delta, 0.05)
	_tempo += dt
	# ---- líder: passeia, foge da costa; se o barco passa rápido e perto, vem para a proa dele
	var barco_pos: Vector3 = _barco.global_position
	var dist: float = Vector2(_lider.x - barco_pos.x, _lider.z - barco_pos.z).length()
	if dist > 300.0:
		reiniciar()
		return
	var vel_barco: float = float(_barco.velocidade) if "velocidade" in _barco else 0.0
	if _surfando <= 0.0 and absf(vel_barco) > 4.0 and dist < 70.0 and randf() < dt * 0.4:
		_surfando = randf_range(18.0, 35.0)
	var vel: float = VEL_CRUZEIRO
	if _surfando > 0.0:
		_surfando -= dt
		var frente: Vector3 = -_barco.global_transform.basis.z
		frente.y = 0.0
		frente = frente.normalized()
		var alvo: Vector3 = barco_pos + frente * 9.0
		var para: Vector2 = Vector2(alvo.x - _lider.x, alvo.z - _lider.z)
		_rumo_alvo = para.angle()
		vel = clampf(absf(vel_barco) + para.length() * 0.6, 2.0, 12.0)
	else:
		_proxima_curva -= dt
		if _proxima_curva <= 0.0:
			_proxima_curva = randf_range(6.0, 14.0)
			_rumo_alvo = _rumo.angle() + randf_range(-0.9, 0.9)
		var adiante: Vector3 = _lider + Vector3(_rumo.x, 0.0, _rumo.y) * 25.0
		if _mundo != null and _mundo.has_method("altura_terra") and float(_mundo.altura_terra(adiante)) > -4.0:
			_rumo_alvo = _rumo.angle() + 1.4
	_rumo = Vector2.from_angle(lerp_angle(_rumo.angle(), _rumo_alvo, clampf(dt * 0.9, 0.0, 0.2)))
	_lider += Vector3(_rumo.x, 0.0, _rumo.y) * vel * dt
	var lado := Vector3(-_rumo.y, 0.0, _rumo.x)
	var tras := Vector3(-_rumo.x, 0.0, -_rumo.y)
	# ---- cada golfinho
	for b in _bichos:
		var alvo_b: Vector3 = _lider + lado * float(b.forma.x) + tras * float(b.forma.y)
		alvo_b += lado * sin(_tempo * 0.7 + float(b.fase)) * 1.2
		var no: Node3D = b.no
		var p: Vector3 = b.pos
		var agua: float = _agua(p)
		if not b.no_ar:
			var para_b := Vector2(alvo_b.x - p.x, alvo_b.z - p.z)
			var v_h: float = clampf(vel + para_b.length() * 0.8, 1.5, 14.0)
			var dir_b: Vector2 = para_b.normalized() if para_b.length() > 0.3 else _rumo
			b.rumo = Vector2(b.rumo).lerp(dir_b, clampf(dt * 3.0, 0.0, 1.0)).normalized()
			p.x += b.rumo.x * v_h * dt
			p.z += b.rumo.y * v_h * dt
			# nado: rompe a superfície em arcos (o dorso e a dorsal saem a cada ~2 s)
			var arco: float = sin(_tempo * 2.9 + float(b.fase))
			p.y = agua - 0.55 + 0.42 * maxf(arco, -0.4)
			b.arf = 0.22 * cos(_tempo * 2.9 + float(b.fase))
			b.giro = lerpf(float(b.giro), 0.0, clampf(dt * 4.0, 0.0, 1.0))
			b.prox_salto = float(b.prox_salto) - dt
			if b.prox_salto <= 0.0 and arco > 0.6:
				b.no_ar = true
				b.vy = randf_range(4.8, 6.6)
				b.voltas = float(randi_range(2, 4)) if randf() < 0.45 else 0.0
				b.giro = 0.0
				b.v_salto = v_h
				b.prox_salto = randf_range(5.0, 16.0)
				_respingar(p)
		else:
			# no ar: balística; a arfagem segue a trajetória; o rotador gira em volta do próprio eixo
			b.vy = float(b.vy) - GRAVIDADE * dt
			p.x += b.rumo.x * float(b.v_salto) * dt
			p.z += b.rumo.y * float(b.v_salto) * dt
			p.y += float(b.vy) * dt
			b.arf = atan2(float(b.vy), float(b.v_salto))
			if float(b.voltas) > 0.0:
				var tempo_ar: float = 2.0 * 6.0 / GRAVIDADE
				b.giro = float(b.giro) + TAU * float(b.voltas) / tempo_ar * dt
			if p.y < agua - 0.3 and float(b.vy) < 0.0:
				b.no_ar = false
				b.giro = fposmod(float(b.giro), TAU)
				if b.giro > PI:
					b.giro -= TAU
				_respingar(p)
		b.pos = p
		var horiz := Vector3(b.rumo.x, 0.0, b.rumo.y)
		var arf: float = clampf(float(b.arf), -1.2, 1.2)
		var frente_b: Vector3 = horiz * cos(arf) + Vector3.UP * sin(arf)
		var base := Basis.looking_at(frente_b, Vector3.UP) * Basis(Vector3.BACK, float(b.giro))
		no.global_transform = Transform3D(base.scaled(Vector3.ONE * float(b.esc)), p)
		var mat: ShaderMaterial = b.mat
		b.fase = float(b.fase) + dt * (7.5 if not b.no_ar else 2.0)
		mat.set_shader_parameter("fase", float(b.fase))
		mat.set_shader_parameter("amplitude", 0.07 if not b.no_ar else 0.03)
		mat.set_shader_parameter("remada", 0.4)
		mat.set_shader_parameter("fase_remada", float(b.fase) * 0.5)
