extends Node2D
## O arquipélago em jogo (spec 7.4, 9, 10): tempo, vento, farol, cidades, atracar e bússola.
## Liga o Barco à lógica; o HUD só lê dados_hud().

const Tempo = preload("res://logica/tempo.gd")
const Navegacao = preload("res://logica/navegacao.gd")
const Mapa = preload("res://logica/mapa.gd")
const Mercado = preload("res://logica/mercado.gd")
const VEL_MAX_ATRACAR := 40.0
const NOITE := Color(0.22, 0.27, 0.45)

var mundo: Dictionary
var barco
var t := 0.0
var dia := 1
var dia_base := 1
var vento
var forca_vento := 1.0
var corrente_ang := 0.0
var destino_id := "porto_farol"
var cidade_atual := ""
var aviso := ""
var aviso_id := 0
var _rng := RandomNumberGenerator.new()
var _iniciado := false


func _ready() -> void:
	iniciar()


func iniciar() -> void:
	if _iniciado:
		return
	_iniciado = true
	mundo = Mercado.carregar_dados().mundo
	barco = $Barco
	_rng.randomize()
	vento = Navegacao.Vento.new(_rng)
	corrente_ang = _rng.randf_range(0.0, TAU)
	t = Tempo.t_inicial()
	$Farol.position = Mapa._v(mundo.farol.pos)
	_montar_cidades()
	_ler_estado()
	_atracar_em(_cidade(cidade_atual if cidade_atual != "" else "porto_farol"))
	avancar_tempo(0.0)


func _estado() -> Node:
	return get_node_or_null("/root/Estado") if is_inside_tree() else null


func _ler_estado() -> void:
	var e := _estado()
	if e == null:
		return
	barco.nivel_motor = int(e.melhorias.get("motor", 0)) + 1
	barco.vela_grande = int(e.melhorias.get("vela", 0)) > 0
	barco.leme_melhorado = int(e.melhorias.get("leme", 0)) > 0
	barco.tanque = e.tanque()
	barco.combustivel = minf(e.combustivel, barco.tanque)
	cidade_atual = e.cidade
	destino_id = e.destino
	dia_base = e.dia


func _gravar_estado() -> void:
	var e := _estado()
	if e == null:
		return
	e.combustivel = barco.combustivel
	e.dia = dia
	e.destino = destino_id
	if cidade_atual != "":
		e.cidade = cidade_atual


func _cidade(id: String) -> Dictionary:
	for c in mundo.cidades:
		if c.id == id:
			return c
	return mundo.cidades[0]


func _montar_cidades() -> void:
	var raiz := $Cidades
	for c in mundo.cidades:
		var no := Node2D.new()
		no.name = c.id
		no.position = Mapa._v(c.pos)
		raiz.add_child(no)
		var cais := Mapa._v(c.cais) - no.position
		var ponte := Line2D.new()
		ponte.points = PackedVector2Array([cais.normalized() * float(c.raio_ilha) * 0.8, cais])
		ponte.width = 26.0
		ponte.default_color = Color(0.45, 0.3, 0.18)
		no.add_child(ponte)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(c.id)
		for i in 7:
			var casa := Polygon2D.new()
			var p := Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(60, float(c.raio_ilha) * 0.6)
			casa.polygon = PackedVector2Array([p + Vector2(-34, -26), p + Vector2(34, -26), p + Vector2(34, 26), p + Vector2(-34, 26)])
			casa.color = Color.from_hsv(rng.randf_range(0.0, 0.12), 0.55, 0.8)
			no.add_child(casa)
		var nome := Label.new()
		nome.text = c.nome
		nome.add_theme_font_size_override("font_size", 64)
		nome.position = Vector2(-220, -float(c.raio_ilha) - 110)
		no.add_child(nome)


func _process(dt: float) -> void:
	avancar_tempo(dt)
	if Input.is_action_just_pressed("atracar"):
		alternar_atracar()
	if Input.is_action_just_pressed("destino"):
		trocar_destino()
	if Input.is_action_just_pressed("tela_cheia"):
		var tela := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if tela == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN)


func avancar_tempo(dt: float) -> void:
	t += dt
	vento.atualizar(dt, _rng)
	barco.vento_ang = vento.ang
	barco.forca_vento = forca_vento
	barco.corrente_ang = corrente_ang
	var novo_dia := dia_base + Tempo.dia_de(t) - 1
	if novo_dia != dia:
		dia = novo_dia
		_gravar_estado()
	var b := Tempo.brilho(t)
	$Luz.color = NOITE.lerp(Color.WHITE, (b - 0.12) / 0.88)
	var noite := Tempo.eh_noite(t)
	$Farol.aceso = noite
	var lanterna := barco.get_node_or_null("Lanterna") as PointLight2D
	if lanterna:
		lanterna.energy = 1.1 * Tempo.noite(t)


func _avisar(texto: String) -> void:
	aviso = texto
	aviso_id += 1


func alternar_atracar() -> bool:
	if barco.atracado:
		barco.atracado = false
		_avisar("Desatracou de %s" % _cidade(cidade_atual).nome)
		cidade_atual = ""
		return true
	return tentar_atracar()


func tentar_atracar() -> bool:
	var c := Mapa.cais_proximo(mundo, barco.position)
	if c.is_empty():
		_avisar("Chegue mais perto de um cais para atracar")
		return false
	if absf(barco.vel) >= VEL_MAX_ATRACAR:
		_avisar("Vá mais devagar para atracar")
		return false
	_atracar_em(c)
	_avisar("Atracado em %s" % c.nome)
	return true


func _atracar_em(c: Dictionary) -> void:
	var cais := Mapa._v(c.cais)
	barco.position = cais
	barco.rotation = (cais - Mapa._v(c.pos)).angle()
	barco.vel = 0.0
	barco.velocity = Vector2.ZERO
	barco.marcha = Navegacao.MARCHA_PARADO
	barco.atracado = true
	cidade_atual = c.id
	_gravar_estado()


func trocar_destino() -> void:
	destino_id = Mapa.proximo_destino(Mapa.destinos(mundo), destino_id)
	_avisar("Bússola: %s" % _destino().nome)


func _destino() -> Dictionary:
	for d in Mapa.destinos(mundo):
		if d.id == destino_id:
			return d
	return Mapa.destinos(mundo)[0]


func dados_hud() -> Dictionary:
	var pos: Vector2 = barco.position
	var z := Mapa.zona_em(mundo, pos)
	var dst := _destino()
	var farol := Mapa._v(mundo.farol.pos)
	return {
		"marcha": barco.marcha,
		"vela": barco.vela_aberta,
		"combustivel": barco.combustivel,
		"tanque": barco.tanque,
		"zona_nome": "Terra" if z == Mapa.TERRA else Mapa.NOMES_ZONA[z],
		"dia": dia,
		"hora": Tempo.hora_texto(t),
		"destino_nome": dst.nome,
		"rumo_destino": Mapa.rumo(pos, dst.pos),
		"milhas": Mapa.distancia_milhas(pos, dst.pos),
		"rumo_farol": Mapa.rumo(pos, farol),
		"dist_farol": pos.distance_to(farol),
		"farol_visivel": Tempo.eh_noite(t) and pos.distance_to(farol) <= float(mundo.farol.alcance_luz),
		"zona_segura": Mapa.na_zona_segura(mundo, pos),
		"atracado": barco.atracado,
		"aviso": aviso,
		"aviso_id": aviso_id,
	}
