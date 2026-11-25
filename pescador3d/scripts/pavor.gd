extends Node
## v0.8.8: o pavor — o horror que se vê e se ouve, em vez de ser avisado.
## O Assombro (scripts/assombro.gd) diz QUANTO medo; aqui está O QUE acontece no mundo:
##   - escuridão: de noite a névoa fica preta e fecha em volta da lanterna (mais com o medo)
##   - silêncio: a música some, o mar e o vento quase calam (scripts/som.gd)
##   - olhos: pares de olhos brilhando na borda da luz; olhou direto, somem
##   - a sombra: uma coisa enorme passa por baixo do barco, vista através da água (shader do mar)
##   - o dorso: algo rompe a superfície por um instante, na beira da luz
##   - o passageiro: a lanterna pisca e, num clarão, tem alguém sentado na popa; no próximo, não tem
##   - a caçada: com o medo no máximo, a coisa ronda e ergue o barco; só a luz (farol, costa, cais, amanhecer) salva
## Nada disso aparece em texto na hora. O que aconteceu fica anotado no diário (Livro, TAB) e o cais lembra disso.

const T = preload("res://scripts/idioma.gd")

var jogo: Node
var assombro: Node

var escuro: float = 0.0
var cacando: bool = false
var _tempo: float = 0.0
var _anotou: int = 0                       # quantas coisas foram para o diário desde o último cais
var _estava_atracado: bool = true

# ---- olhos
var _olhos: Array = []                     # {no, alfa, sumindo, raio, ang, alt, piscar}
var _mat_olho: StandardMaterial3D
var _prox_olhos: float = 6.0

# ---- a sombra (o corpo da coisa sob a água)
var sombra_ativa: bool = false
var _s_pos := Vector2.ZERO
var _s_dir := Vector2(0, 1)
var _s_vel: float = 7.0
var _s_forca: float = 0.0
var _s_modo: String = ""                   # "passar", "rondar", "investir", "afundar"
var _s_t: float = 0.0
var _s_ang: float = 0.0
var _s_ergueu: bool = false
var _prox_sombra: float = 70.0

# ---- o dorso que rompe a superfície
const MODELO_CORPO := "res://assets/modelos/coisa/coisa_corpo.glb"     # Hunyuan3D a partir da arte do Gabriel
const MODELO_ATAQUE := "res://assets/modelos/coisa/coisa_ataque.glb"   # TRELLIS (MIT), a partir da arte do ataque
const ESCALA_CORPO := 10.0          # a malha tem 2 de comprimento: 20 m
const ESCALA_ATAQUE := 8.5          # 0,82 de altura: ~7 m
const COSTAS_DUR := 6.0
var _corpo: Node3D = null
var _boca: Node3D = null
var _costas_t: float = -1.0
var _costas_ini := Vector3.ZERO
var _costas_dir := Vector3.FORWARD
var _prox_dorso: float = 45.0
var _boca_t: float = -1.0
var _boca_base := Vector3.ZERO
var _boca_bateu: bool = false
var luz_extra: float = 1.0          # jogo.gd multiplica a lanterna (a lanterna balança e pega a coisa em cheio)
var _arrasto_lado := Vector3.ZERO
var _arrasto_giro: float = 1.0

# ---- o barco erguido
var _erguer_t: float = -1.0
var _erguer_alt: float = 2.6
var _erguer_lado: float = 1.0

# ---- lanterna e passageiro
var _seq_luz: Array = []                   # [[duração, luz acesa?, passageiro visível?], ...]
var _luz_apagada: bool = false
var _passageiro: Node3D = null
var _prox_passageiro: float = 100.0

func construir(o_jogo: Node, o_assombro: Node) -> void:
	jogo = o_jogo
	assombro = o_assombro
	_mat_olho = StandardMaterial3D.new()
	_mat_olho.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_olho.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_olho.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_olho.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat_olho.disable_fog = true
	_mat_olho.no_depth_test = false
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.16, 0.40, 1.0])
	g.colors = PackedColorArray([Color(1.0, 1.0, 0.9, 1.0), Color(0.98, 0.90, 0.45, 0.95), Color(0.65, 0.80, 0.30, 0.25), Color(0.4, 0.6, 0.2, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_mat_olho.albedo_texture = tex
	_montar_coisa()
	_passageiro = _montar_passageiro()
	_passageiro.visible = false
	jogo.barco.balanceio.add_child(_passageiro)

func zerar() -> void:
	cacando = false
	_limpar_olhos()
	_s_forca = 0.0
	sombra_ativa = false
	_s_modo = ""
	_esconder_coisa()
	_seq_luz.clear()
	_luz_apagada = false
	if _passageiro != null:
		_passageiro.visible = false
	_erguer_t = -1.0
	if jogo != null and jogo.barco != null:
		jogo.barco.erguer = 0.0
		jogo.barco.erguer_inclina = Vector2.ZERO
	_aplicar_sombra()

## A lanterna pode estar "ligada" e mesmo assim apagada por um instante (o pisca do passageiro, a pancada).
func luz_apagada() -> bool:
	return _luz_apagada

# ------------------------------------------------------------------ o quadro

func atualizar(delta: float, navegando: bool) -> void:
	_tempo += delta
	var clima: Node = jogo.clima
	var n: float = clima.noite()
	var v: float = assombro.valor
	var atracado: bool = jogo.atracado
	# escuridão e silêncio
	var alvo_escuro: float = 0.0
	var alvo_silencio: float = 0.0
	if navegando and not atracado:
		alvo_escuro = n * (0.45 + 0.55 * smoothstep(0.15, 0.75, v))
		alvo_silencio = n * smoothstep(0.30, 0.75, v)
		if cacando:
			alvo_silencio = 1.0
	escuro = move_toward(escuro, alvo_escuro, delta / 6.0)
	clima.pavor_escuro = escuro
	jogo.som.silencio = move_toward(float(jogo.som.silencio), alvo_silencio, delta / (4.0 if alvo_silencio > jogo.som.silencio else 2.0))
	# o cais lembra
	if atracado and not _estava_atracado and _anotou > 0:
		jogo.interface.aviso(T.t("Você anotou no Livro (TAB, Diário) o que aconteceu no mar. Escrito em terra, parece menos real."))
		_anotou = 0
	_estava_atracado = atracado
	if atracado or not navegando:
		if cacando:
			_fim_da_cacada()
		_mover_olhos(delta, false)
		_mover_sombra(delta)
		_mover_costas(delta)
		_mover_boca(delta)
		_passo_luz(delta)
		_passo_erguer(delta)
		return
	var noite_funda: bool = n > 0.5
	# olhos
	_prox_olhos -= delta
	if noite_funda and v >= 0.30 and _prox_olhos <= 0.0:
		_prox_olhos = randf_range(20.0, 40.0) * (1.4 - v)
		if _olhos.is_empty():
			nascer_olhos()
	_mover_olhos(delta, noite_funda and v >= 0.25)
	# o dorso
	_prox_dorso -= delta
	if noite_funda and v >= 0.45 and _prox_dorso <= 0.0 and _costas_t < 0.0 and not cacando:
		_prox_dorso = randf_range(50.0, 100.0)
		mostrar_costas()
	# a sombra passa
	_prox_sombra -= delta
	if noite_funda and v >= 0.60 and _prox_sombra <= 0.0 and not sombra_ativa and not cacando:
		_prox_sombra = randf_range(55.0, 100.0)
		passar_sombra()
	# o passageiro
	_prox_passageiro -= delta
	if noite_funda and v >= 0.50 and _prox_passageiro <= 0.0 and assombro.lanterna_acesa() and _seq_luz.is_empty():
		_prox_passageiro = randf_range(110.0, 200.0)
		piscar_lanterna(true)
	# a caçada
	if not cacando and v >= 0.95:
		comecar_cacada()
	if cacando:
		assombro.valor = maxf(assombro.valor, 0.95)
		var farol: float = 0.0
		for i in jogo.ilhas:
			farol = maxf(farol, float(i.clareio_do_farol(jogo.barco.global_position)))
		if farol > 0.3 or float(jogo.distancia_da_costa(jogo.barco.global_position)) < 150.0 or n < 0.3:
			_fim_da_cacada()
	_mover_sombra(delta)
	_mover_costas(delta)
	_mover_boca(delta)
	_passo_luz(delta)
	_passo_erguer(delta)

func _anotar(texto: String) -> void:
	jogo.interface.anotar("%s — %s" % [jogo.clima.texto_hora(), texto])
	_anotou += 1

func _cam() -> Camera3D:
	return jogo.get_viewport().get_camera_3d()

# ------------------------------------------------------------------ olhos

func nascer_olhos() -> void:
	var cam := _cam()
	var b: Vector3 = jogo.barco.global_position
	var frente_cam: Vector3 = -cam.global_transform.basis.z
	frente_cam.y = 0.0
	frente_cam = frente_cam.normalized()
	# de preferência pelos lados ou por trás de onde se está olhando: vistos de canto de olho
	var ang_cam: float = atan2(frente_cam.x, frente_cam.z)
	var ang: float = ang_cam + (1.0 if randf() < 0.5 else -1.0) * randf_range(0.45, 1.6)
	var raio: float = randf_range(21.0, 30.0)
	var no := Node3D.new()
	no.name = "Olhos"
	var alt: float = randf_range(0.25, 0.9)
	for lado in [-1.0, 1.0]:
		for reflexo in [false, true]:
			# o olho e, embaixo, o reflexo dele na água (esticado e fraco)
			var m := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(0.7, 0.7) if not reflexo else Vector2(0.5, 1.4)
			m.mesh = q
			m.material_override = _mat_olho.duplicate()
			m.position = Vector3(lado * 0.22, 0.0 if not reflexo else -alt * 2.0, 0.0)
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			m.set_meta("reflexo", reflexo)
			no.add_child(m)
	jogo.add_child(no)
	var o := {"no": no, "alfa": 0.0, "sumindo": false, "raio": raio, "ang": ang, "alt": alt, "piscar": randf_range(1.5, 4.0), "fechado": 0.0}
	_olhos.append(o)
	_posicionar_olhos(o)

func _posicionar_olhos(o: Dictionary) -> void:
	var b: Vector3 = jogo.barco.global_position
	var p: Vector3 = b + Vector3(sin(float(o.ang)), 0.0, cos(float(o.ang))) * float(o.raio)
	var no: Node3D = o.no
	no.global_position = Vector3(p.x, float(o.alt) + 0.08 * sin(_tempo * 0.9 + float(o.ang)), p.z)

func _mover_olhos(delta: float, pode: bool) -> void:
	if _olhos.is_empty():
		return
	var cam := _cam()
	var frente: Vector3 = -cam.global_transform.basis.z
	for o in _olhos.duplicate():
		var no: Node3D = o.no
		# chegam devagar
		o.raio = maxf(14.0, float(o.raio) - delta * 0.35)
		_posicionar_olhos(o)
		var para: Vector3 = (no.global_position - cam.global_position).normalized()
		var olhando: bool = frente.dot(para) > cos(deg_to_rad(13.0))
		if olhando or not pode or float(o.raio) <= 14.5:
			o.sumindo = true
		o.alfa = move_toward(float(o.alfa), 0.0 if o.sumindo else 1.0, delta / (0.22 if o.sumindo else 2.5))
		# piscam
		o.piscar = float(o.piscar) - delta
		if float(o.piscar) <= 0.0:
			o.piscar = randf_range(2.0, 5.5)
			o.fechado = 0.14
		o.fechado = maxf(0.0, float(o.fechado) - delta)
		var dist: float = cam.global_position.distance_to(no.global_position)
		var a: float = float(o.alfa) * (0.0 if float(o.fechado) > 0.0 else 1.0) * clampf(1.25 - dist / 60.0, 0.25, 1.0)
		for m in no.get_children():
			var r: bool = bool(m.get_meta("reflexo", false))
			((m as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(1, 1, 1, a * (0.28 if r else 1.0))
		if o.sumindo and float(o.alfa) <= 0.0:
			no.queue_free()
			_olhos.erase(o)

func _limpar_olhos() -> void:
	for o in _olhos:
		(o.no as Node).queue_free()
	_olhos.clear()

# ------------------------------------------------------------------ a sombra sob a água

## Uma passagem: vem de longe, cruza por baixo do barco e vai embora afundando.
func passar_sombra() -> void:
	var barco: Node3D = jogo.barco
	var b := Vector2(barco.global_position.x, barco.global_position.z)
	var ang: float = randf() * TAU
	var de := Vector2(sin(ang), cos(ang))
	_s_pos = b + de * 75.0 + Vector2(-de.y, de.x) * randf_range(-6.0, 6.0)
	_s_dir = -de
	_s_vel = 7.5
	_s_modo = "passar"
	_s_t = 0.0
	_s_ergueu = false
	sombra_ativa = true

func comecar_cacada() -> void:
	if cacando:
		return
	cacando = true
	var barco: Node3D = jogo.barco
	var b := Vector2(barco.global_position.x, barco.global_position.z)
	if not sombra_ativa:
		_s_ang = randf() * TAU
		_s_pos = b + Vector2(sin(_s_ang), cos(_s_ang)) * 70.0
		_s_forca = 0.0
	_s_modo = "rondar"
	_s_t = randf_range(7.0, 11.0)
	sombra_ativa = true
	_anotar(T.t("Alguma coisa enorme começou a rondar o barco. Só pensei em correr para a luz."))

func _fim_da_cacada() -> void:
	cacando = false
	if sombra_ativa:
		_s_modo = "afundar"
		_s_t = 0.0
	assombro.valor = minf(assombro.valor, 0.6)
	_anotar(T.t("A coisa ficou para trás quando cheguei perto da luz."))

func _mover_sombra(delta: float) -> void:
	if not sombra_ativa:
		return
	var barco: Node3D = jogo.barco
	var b := Vector2(barco.global_position.x, barco.global_position.z)
	match _s_modo:
		"passar":
			_s_pos += _s_dir * _s_vel * delta
			var d: float = _s_pos.distance_to(b)
			_s_forca = move_toward(_s_forca, 1.0 if d < 55.0 else 0.0, delta / 2.0)
			if d < 9.0 and not _s_ergueu:
				_s_ergueu = true
				_erguer(0.9, 6.0, 0.0)
				jogo.som.tocar_em("grave", barco.global_position + Vector3(0, -6, 0), 2.0, 0.85, 20.0)
				_anotar(T.t("O barco subiu numa onda sem vento. Embaixo, a água ficou preta."))
			if (_s_pos - b).dot(_s_dir) > 45.0:
				_s_modo = "afundar"
				_s_t = 0.0
		"rondar":
			_s_ang += delta * 0.22
			var alvo: Vector2 = b + Vector2(sin(_s_ang), cos(_s_ang)) * 34.0
			var para: Vector2 = alvo - _s_pos
			if para.length() > 0.1:
				_s_dir = _s_dir.lerp(para.normalized(), 1.0 - exp(-2.0 * delta)).normalized()
			_s_pos += _s_dir * minf(para.length() * 1.5, 9.0) * delta
			_s_forca = move_toward(_s_forca, 0.9, delta / 3.0)
			_s_t -= delta
			if _s_t <= 0.0:
				# ela pega o barco por baixo e arrasta de lado, girando; o casco range
				_s_modo = "arrastar"
				_s_t = 3.2
				var fr: Vector3 = -barco.global_transform.basis.z
				_arrasto_lado = Vector3(-fr.z, 0.0, fr.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
				_arrasto_giro = 1.0 if randf() < 0.5 else -1.0
				jogo.som.tocar_em("grave", barco.global_position + Vector3(0, -6.0, 0), 4.0, 0.65, 30.0)
				jogo.som.tocar_em("batida", barco.global_position + Vector3(0, -1.0, 0), 0.0, 0.5, 8.0)
		"arrastar":
			_s_pos = _s_pos.lerp(b, 1.0 - exp(-3.0 * delta))
			_s_forca = move_toward(_s_forca, 0.8, delta)
			var forca_arrasto: float = smoothstep(0.0, 0.8, 3.2 - _s_t) * (1.0 - smoothstep(2.6, 3.2, 3.2 - _s_t))
			barco.global_position += _arrasto_lado * 1.8 * forca_arrasto * delta
			barco.rotate_y(0.28 * _arrasto_giro * forca_arrasto * delta)
			if jogo.camera_barco != null and "tremor" in jogo.camera_barco:
				jogo.camera_barco.tremor = maxf(jogo.camera_barco.tremor, 0.25 * forca_arrasto)
			_s_t -= delta
			if _s_t <= 0.0:
				irromper()
				_s_modo = "afastar"
				_s_t = randf_range(12.0, 18.0)
		"afastar":
			var longe_pos: Vector2 = b + (_s_pos - b).normalized() * 40.0 if _s_pos.distance_to(b) > 0.5 else b + Vector2(40, 0)
			_s_pos = _s_pos.lerp(longe_pos, 1.0 - exp(-0.5 * delta))
			_s_forca = move_toward(_s_forca, 0.4, delta / 2.0)
			_s_t -= delta
			if _s_t <= 0.0:
				_s_modo = "rondar" if cacando else "afundar"
				_s_t = randf_range(8.0, 12.0)
		"afundar":
			_s_pos += _s_dir * 5.0 * delta
			_s_forca = move_toward(_s_forca, 0.0, delta / 3.0)
			if _s_forca <= 0.0:
				sombra_ativa = false
				_s_modo = ""
	# o radar também vê
	if _s_pos.distance_to(b) < 70.0 and _s_forca > 0.2:
		assombro.sombra_radar = maxf(assombro.sombra_radar, 0.5)
	_aplicar_sombra()

func _aplicar_sombra(tam: Vector2 = Vector2(32.0, 11.0)) -> void:
	var mar: Node = jogo.get_node_or_null("Oceano")
	if mar == null or not ("_material" in mar) or mar._material == null:
		return
	var m: ShaderMaterial = mar._material
	m.set_shader_parameter("sombra_pos", _s_pos)
	m.set_shader_parameter("sombra_dir", _s_dir)
	m.set_shader_parameter("sombra_tam", tam)
	m.set_shader_parameter("sombra_forca", _s_forca if sombra_ativa else 0.0)

## A pancada: a coisa bate o corpo contra o costado. O barco adorna e balança (não pula), a câmera treme,
## o casco racha, a lanterna apaga.
func _impacto() -> void:
	var barco: Node3D = jogo.barco
	_erguer(0.6, 11.0, 0.85)
	barco.danificar(randf_range(11.0, 18.0), "bruma")
	jogo.som.tocar_em("batida", barco.global_position + Vector3(0, -1.0, 0), 8.0, 0.7, 12.0)
	jogo.som.tocar_em("grave", barco.global_position + Vector3(0, -3, 0), 6.0, 0.6, 25.0)
	_seq_luz = [[0.55, false, false], [0.05, true, false], [0.35, false, false], [0.08, true, false], [0.4, false, false]]
	_anotar(T.t("Ela saiu da água do lado do barco, de boca aberta, e bateu no costado. O casco rachou."))
	if barco.saude <= 0.0 and assombro.has_method("_comecar_desmaio"):
		cacando = false
		assombro._comecar_desmaio()

func _erguer(altura: float, graus: float, tremor: float) -> void:
	_erguer_t = 0.0
	_erguer_alt = altura
	_erguer_lado = (1.0 if randf() < 0.5 else -1.0) * deg_to_rad(graus)
	if tremor > 0.0 and jogo.camera_barco != null and "tremor" in jogo.camera_barco:
		jogo.camera_barco.tremor = tremor
	if jogo.barco.has_method("sacudir"):
		jogo.barco.sacudir(1.0 + altura)

func _passo_erguer(delta: float) -> void:
	if _erguer_t < 0.0:
		return
	_erguer_t += delta
	var t: float = _erguer_t
	# adorna depressa (0,3 s) e volta balançando devagar (1,6 s)
	var k: float = smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.3, 1.9, t)) * (1.0 + 0.35 * sin(t * 9.0) * (1.0 - smoothstep(0.3, 1.9, t)))
	var barco: Node3D = jogo.barco
	barco.erguer = _erguer_alt * k
	barco.erguer_inclina = Vector2(-0.25 * absf(_erguer_lado), _erguer_lado) * k
	if t >= 1.9:
		_erguer_t = -1.0
		barco.erguer = 0.0
		barco.erguer_inclina = Vector2.ZERO

# ------------------------------------------------------------------ a Coisa de Baixo (modelos de assets/modelos/coisa)

func _montar_coisa() -> void:
	if ResourceLoader.exists(MODELO_CORPO):
		_corpo = (load(MODELO_CORPO) as PackedScene).instantiate()
		var mat := ShaderMaterial.new()
		mat.shader = load("res://assets/modelos/coisa/coisa_corpo.gdshader")
		mat.set_shader_parameter("arte", load("res://assets/modelos/coisa/corpo_arte.png"))
		mat.set_shader_parameter("relevo", load("res://assets/modelos/coisa/corpo_relevo.png"))
		mat.set_shader_parameter("molhado", 0.9)
		mat.set_shader_parameter("claridade", 1.25)
		for mi in _corpo.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_corpo.name = "CoisaCorpo"
		_corpo.visible = false
		jogo.add_child(_corpo)
	if ResourceLoader.exists(MODELO_ATAQUE):
		_boca = (load(MODELO_ATAQUE) as PackedScene).instantiate()
		var pele := ShaderMaterial.new()
		pele.shader = load("res://assets/modelos/coisa/coisa_boca.gdshader")
		pele.set_shader_parameter("cor", load("res://assets/modelos/coisa/ataque_cor.png"))
		pele.set_shader_parameter("relevo", load("res://assets/modelos/coisa/ataque_relevo.png"))
		for mi in _boca.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = pele
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_boca.name = "CoisaBoca"
		_boca.visible = false
		jogo.add_child(_boca)

func _esconder_coisa() -> void:
	_costas_t = -1.0
	_boca_t = -1.0
	if _corpo != null:
		_corpo.visible = false
	if _boca != null:
		_boca.visible = false
	if _s_modo == "costas":
		_s_modo = ""
		sombra_ativa = false
		_s_forca = 0.0
		_aplicar_sombra()

## Põe um nó da coisa num lugar, olhando para "frente" (a malha do corpo tem a cabeça em -X; a da boca olha para +Z).
func _orientar(no: Node3D, pos: Vector3, frente: Vector3, escala: float, cabeca_em_menos_x: bool) -> void:
	frente.y = 0.0
	frente = frente.normalized()
	var x_eixo: Vector3
	var z_eixo: Vector3
	if cabeca_em_menos_x:
		x_eixo = -frente
		z_eixo = x_eixo.cross(Vector3.UP)
	else:
		z_eixo = frente
		x_eixo = Vector3.UP.cross(z_eixo)
	no.global_transform = Transform3D(Basis(x_eixo, Vector3.UP, z_eixo).scaled(Vector3.ONE * escala), pos)

## As costas da coisa passam rente à superfície, ao lado do barco, na beira da luz: só a crista e as cracas saem da água.
func mostrar_costas() -> void:
	if _corpo == null or _costas_t >= 0.0:
		return
	var barco: Node3D = jogo.barco
	var frente: Vector3 = -barco.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var lado: Vector3 = Vector3(-frente.z, 0.0, frente.x) * (1.0 if randf() < 0.5 else -1.0)
	var para_frente: bool = randf() < 0.5
	_costas_dir = frente if para_frente else -frente
	_costas_ini = barco.global_position + lado * randf_range(5.0, 6.5) - _costas_dir * 15.0
	_costas_ini.y = 0.0
	_costas_t = 0.0
	_corpo.visible = true
	jogo.som.tocar_em("grave", _costas_ini, 0.0, 0.8, 20.0)
	_anotar(T.t("Umas costas enormes passaram rente à água, do lado do barco. Tinha cracas. E rede."))

func _mover_costas(delta: float) -> void:
	if _costas_t < 0.0 or _corpo == null:
		return
	_costas_t += delta
	var u: float = _costas_t / COSTAS_DUR
	# sobe até a crista romper a água, passa, e afunda de novo
	var fundo: float = lerpf(-5.0, -1.9, smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.72, 1.0, u)))
	var pos: Vector3 = _costas_ini + _costas_dir * (u * 30.0) + Vector3(0, fundo, 0)
	var ginga: Vector3 = _costas_dir.rotated(Vector3.UP, 0.06 * sin(_tempo * 1.3))
	_orientar(_corpo, pos, ginga, ESCALA_CORPO, true)
	if not sombra_ativa or _s_modo == "costas":
		_s_modo = "costas"
		sombra_ativa = true
		_s_pos = Vector2(pos.x, pos.z)
		_s_dir = Vector2(_costas_dir.x, _costas_dir.z)
		_s_forca = 0.7 * sin(clampf(u, 0.0, 1.0) * PI)
		_aplicar_sombra(Vector2(20.0, 6.0))
	luz_extra = 1.0 + 1.0 * sin(clampf(u, 0.0, 1.0) * PI)
	if u >= 0.3 and not _corpo.has_meta("espirrou"):
		_corpo.set_meta("espirrou", true)
		_espirrar(pos * Vector3(1, 0, 1), 0.5)
	if u >= 1.0:
		_corpo.remove_meta("espirrou")
		_esconder_coisa()
		luz_extra = 1.0

## O ataque: a cabeça sai da água na vertical, ao lado do barco, de boca aberta, iluminada só pela lanterna;
## se inclina sobre o barco, bate o corpo no costado e afunda. Uma vez, rápido.
func irromper() -> void:
	if _boca == null or _boca_t >= 0.0:
		return
	var barco: Node3D = jogo.barco
	var frente: Vector3 = -barco.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var lado: Vector3 = Vector3(-frente.z, 0.0, frente.x) * (1.0 if randf() < 0.5 else -1.0)
	_boca_base = barco.global_position + lado * 6.5 + frente * randf_range(-3.5, 0.5)
	_boca_base.y = 0.0
	_boca_t = 0.0
	_boca_bateu = false
	_boca.visible = true
	_seq_luz.clear()
	_espirrar(_boca_base, 1.3)
	jogo.som.tocar_em("grave", _boca_base, 6.0, 0.75, 25.0)

func _mover_boca(delta: float) -> void:
	if _boca_t < 0.0 or _boca == null:
		return
	_boca_t += delta
	var t: float = _boca_t
	var barco: Node3D = jogo.barco
	var para_barco: Vector3 = barco.global_position - _boca_base
	para_barco.y = 0.0
	var dir: Vector3 = para_barco.normalized()
	var y: float
	var inclina: float = 0.0
	var avanco: float = 0.0
	if t < 0.6:                                   # sobe: rápido no começo, freia no alto
		var k: float = 1.0 - pow(1.0 - t / 0.6, 3.0)
		y = lerpf(-10.0, 2.0, k)
	elif t < 1.5:                                 # fica lá em cima, de boca aberta, tremendo, e vai pendendo para o barco
		var k2: float = (t - 0.6) / 0.9
		y = 2.0 + 0.15 * sin(t * 23.0) * (1.0 - k2)
		inclina = deg_to_rad(18.0) * k2 * k2
	else:                                         # despenca em cima do costado e afunda
		var k3: float = clampf((t - 1.5) / 0.8, 0.0, 1.0)
		y = lerpf(2.0, -11.0, k3 * k3)
		inclina = deg_to_rad(18.0 + 40.0 * k3)
		avanco = 2.5 * k3
		if not _boca_bateu and t >= 1.7:
			_boca_bateu = true
			_espirrar(barco.global_position - dir * 2.5, 1.6)     # no costado que ela bateu
			_impacto()
	luz_extra = 1.0 + 1.8 * clampf((y + 4.0) / 6.0, 0.0, 1.0)
	_orientar(_boca, _boca_base + dir * avanco + Vector3(0, y, 0), dir, ESCALA_ATAQUE, false)
	_boca.rotate_object_local(Vector3.RIGHT, inclina)
	if t >= 2.4:
		_boca_t = -1.0
		_boca.visible = false
		luz_extra = 1.0

func _espirrar(pos: Vector3, forca: float) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(90 * forca)
	p.lifetime = 1.3
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 3.0 * forca
	p.initial_velocity_max = 7.5 * forca
	p.gravity = Vector3(0, -9.8, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.6
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.8
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.38)                     # gota esticada, não bolinha
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	mat.metallic_specular = 0.9
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.62, 0.66, 0.75))
	g.set_color(1, Color(0.45, 0.55, 0.6, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	mat.albedo_texture = tex
	q.material = mat
	p.mesh = q
	jogo.add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)

# ------------------------------------------------------------------ a lanterna e o passageiro

## A lanterna pisca. Com passageiro: num dos clarões tem alguém sentado na popa; no seguinte, não tem mais.
func piscar_lanterna(com_passageiro: bool) -> void:
	if com_passageiro:
		_seq_luz = [[0.10, false, false], [0.12, true, false], [0.35, false, false], [0.09, true, false],
				[1.1, false, false], [0.55, true, true], [0.9, false, false], [0.12, true, false], [0.4, false, false]]
		_anotar(T.t("A lanterna piscou. Num dos clarões tinha alguém em pé na popa, de chapéu, de cabeça baixa. No outro, não tinha ninguém."))
	else:
		_seq_luz = [[0.08, false, false], [0.1, true, false], [0.25, false, false], [0.06, true, false], [randf_range(1.2, 2.5), false, false]]

func _passo_luz(delta: float) -> void:
	if _seq_luz.is_empty():
		_luz_apagada = false
		if _passageiro != null:
			_passageiro.visible = false
		return
	var passo: Array = _seq_luz[0]
	_luz_apagada = not bool(passo[1])
	if _passageiro != null:
		_passageiro.visible = bool(passo[2])
	passo[0] = float(passo[0]) - delta
	if float(passo[0]) <= 0.0:
		_seq_luz.pop_front()

## Um homem sentado na borda da popa, de chapéu de palha velho, curvado, os braços nos joelhos. Só silhueta.
func _montar_passageiro() -> Node3D:
	var no := Node3D.new()
	no.name = "Passageiro"
	var pano := StandardMaterial3D.new()
	pano.albedo_color = Color(0.028, 0.03, 0.032)
	pano.roughness = 0.55
	pano.metallic_specular = 0.6
	var rosto := StandardMaterial3D.new()
	rosto.albedo_color = Color(0.62, 0.64, 0.58)        # pele de afogado
	rosto.roughness = 0.45
	rosto.emission_enabled = true
	rosto.emission = Color(0.55, 0.60, 0.55)
	rosto.emission_energy_multiplier = 0.12
	var buraco := StandardMaterial3D.new()
	buraco.albedo_color = Color(0, 0, 0)
	buraco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var palha := StandardMaterial3D.new()
	palha.albedo_color = Color(0.09, 0.08, 0.06)
	palha.roughness = 0.9
	# em pé na popa, alto e magro demais, de cabeça baixa, os braços caídos (origem nos pés, no convés)
	var partes := [
		# [malha, posição, rotação (graus), escala, material]
		["perna", Vector3(-0.10, 0.47, 0.0), Vector3.ZERO, Vector3.ONE, pano],
		["perna", Vector3(0.10, 0.47, 0.0), Vector3.ZERO, Vector3.ONE, pano],
		["capsula", Vector3(0, 1.30, 0.04), Vector3(-9, 0, 0), Vector3(0.92, 1.0, 0.75), pano],       # tronco, um pouco curvado
		["braco", Vector3(-0.27, 1.17, 0.06), Vector3(-4, 0, 5), Vector3.ONE, pano],
		["braco", Vector3(0.27, 1.17, 0.06), Vector3(-4, 0, -5), Vector3.ONE, pano],
		["esfera", Vector3(0, 1.80, 0.11), Vector3(-25, 0, 0), Vector3(0.95, 1.08, 1.0), rosto],      # cabeça baixa
		["olho", Vector3(-0.045, 1.80, 0.22), Vector3.ZERO, Vector3.ONE, buraco],
		["olho", Vector3(0.045, 1.80, 0.22), Vector3.ZERO, Vector3.ONE, buraco],
		["aba", Vector3(0, 1.91, 0.12), Vector3(-16, 0, 0), Vector3.ONE, palha],
		["copa", Vector3(0, 1.98, 0.10), Vector3(-16, 0, 0), Vector3.ONE, palha],
	]
	for p in partes:
		var m := MeshInstance3D.new()
		match String(p[0]):
			"capsula":
				var c := CapsuleMesh.new(); c.radius = 0.2; c.height = 0.78; m.mesh = c
			"esfera":
				var e := SphereMesh.new(); e.radius = 0.12; e.height = 0.26; m.mesh = e
			"olho":
				var ol := SphereMesh.new(); ol.radius = 0.028; ol.height = 0.05; m.mesh = ol
			"aba":
				var a := CylinderMesh.new(); a.top_radius = 0.30; a.bottom_radius = 0.32; a.height = 0.025; m.mesh = a
			"copa":
				var cp := CylinderMesh.new(); cp.top_radius = 0.11; cp.bottom_radius = 0.14; cp.height = 0.14; m.mesh = cp
			"coxa":
				var cx := CapsuleMesh.new(); cx.radius = 0.085; cx.height = 0.48; m.mesh = cx
			"canela":
				var cn := CapsuleMesh.new(); cn.radius = 0.07; cn.height = 0.5; m.mesh = cn
			"braco":
				var br := CapsuleMesh.new(); br.radius = 0.055; br.height = 0.78; m.mesh = br
			"perna":
				var pr := CapsuleMesh.new(); pr.radius = 0.08; pr.height = 0.95; m.mesh = pr
		m.position = p[1]
		m.rotation_degrees = p[2]
		m.scale = p[3]
		m.material_override = p[4]
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		no.add_child(m)
	# o clarão da lanterna bate nele (só existe enquanto ele está lá)
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.80, 0.55)
	luz.light_energy = 1.6
	luz.omni_range = 3.2
	luz.position = Vector3(0.0, 2.4, -0.9)
	no.add_child(luz)
	var frente := OmniLight3D.new()
	frente.light_color = Color(0.75, 0.82, 0.9)
	frente.light_energy = 0.5
	frente.omni_range = 2.5
	frente.position = Vector3(0.0, 1.9, 1.3)
	no.add_child(frente)
	# em pé no fundo da popa, de frente para quem olha de trás do barco
	no.position = Vector3(0.0, 0.62, 3.95)
	return no
