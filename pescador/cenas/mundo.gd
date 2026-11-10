extends Node2D
## O arquipélago em jogo (spec 7.4, 9, 10): tempo, vento, farol, cidades, atracar e bússola.
## Liga o Barco à lógica; o HUD só lê dados_hud().

const Tempo = preload("res://logica/tempo.gd")
const Navegacao = preload("res://logica/navegacao.gd")
const Mapa = preload("res://logica/mapa.gd")
const Mercado = preload("res://logica/mercado.gd")
const Pesca = preload("res://logica/pesca.gd")
const Especies = preload("res://logica/especies.gd")
const Porao = preload("res://logica/porao.gd")
const Catalogo = preload("res://logica/catalogo.gd")
const CenaCardume = preload("res://cenas/Cardume.tscn")
const VEL_MAX_ATRACAR := 40.0
const MAX_CARDUMES := 5
const R_NASCE_MIN := 1100.0       ## px: nascem fora da tela
const R_NASCE_MAX := 1700.0
const R_SOME := 2600.0            ## px: além disso o cardume é esquecido
const INTERVALO_NASCE := 1.5      ## s entre nascimentos
const NOME_VARA := {"rasa": "Rasa", "profunda": "Profunda", "abissal": "Abissal"}

signal porao_cheio
signal porao_mudou
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
var _na_borda := false

## Pesca. Preenchidos pelo Estado quando ele existe; os padrões servem para os testes.
var especies: Array = []
var porao = Porao.new()
var catalogo = Catalogo.new()
var varas: Array = ["rasa"]
var vara := "rasa"
var tem_rede := false
var nivel_pescador := 0
var cardumes: Array = []
var fisgada: Dictionary = {}      ## {cardume, prep, t} enquanto o medidor está aberto
var pendente: Dictionary = {}     ## exemplar fisgado esperando espaço no porão
var espera_pesca := 0.0
var recarga_rede := 0.0
var _t_nasce := 0.0


func _ready() -> void:
	iniciar()


func iniciar() -> void:
	if _iniciado:
		return
	_iniciado = true
	mundo = Mercado.carregar_dados().mundo
	especies = Especies.carregar()
	barco = $Barco
	_rng.randomize()
	vento = Navegacao.Vento.new(_rng)
	corrente_ang = _rng.randf_range(0.0, TAU)
	t = Tempo.t_inicial()
	$Farol.position = Mapa._v(mundo.farol.pos)
	_montar_cidades()
	_ler_estado()
	barco.combustivel_acabou.connect(func(): _avisar("Sem combustível! Abra a vela (V) e use o vento"))
	var cam := barco.get_node_or_null("Camera2D") as Camera2D
	if cam:                                  # a câmera para na borda: não mostra o vazio além do mapa
		var lim := int(mundo.mapa.limite)
		cam.limit_left = -lim
		cam.limit_top = -lim
		cam.limit_right = lim
		cam.limit_bottom = lim
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
	porao = e.porao
	catalogo = e.catalogo
	varas = e.varas
	vara = Pesca.vara_valida(varas, e.vara)
	tem_rede = int(e.melhorias.get("rede", 0)) > 0
	nivel_pescador = int(e.habilidades.get("pescador", 0))


func _gravar_estado() -> void:
	var e := _estado()
	if e == null:
		return
	e.combustivel = barco.combustivel
	e.dia = dia
	e.destino = destino_id
	e.vara = vara
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
	if Input.is_action_just_pressed("pescar") and not _painel_aberto():
		acao_pescar()
	if Input.is_action_just_pressed("trocar_vara"):
		trocar_vara()
	atualizar_cardumes(dt)
	if Input.is_action_just_pressed("tela_cheia"):
		var tela := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if tela == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN)


func avancar_tempo(dt: float) -> void:
	t += dt
	var hud := get_node_or_null("HUD")
	if hud and _iniciado and dt > 0.0:
		hud.atualizar(dados_hud())
	vento.atualizar(dt, _rng)
	_avancar_pesca(dt)
	barco.vento_ang = vento.ang
	barco.forca_vento = forca_vento
	barco.corrente_ang = corrente_ang
	var novo_dia := dia_base + Tempo.dia_de(t) - 1
	if novo_dia != dia:
		dia = novo_dia
		_gravar_estado()
	var borda: bool = not barco.atracado and Mapa.perto_da_borda(mundo, barco.position)
	if borda and not _na_borda:
		_avisar("Fim das águas conhecidas — dê meia-volta")
	_na_borda = borda
	var b := Tempo.brilho(t)
	$Luz.color = NOITE.lerp(Color.WHITE, (b - 0.12) / 0.88)
	var noite := Tempo.eh_noite(t)
	$Farol.aceso = noite
	var lanterna := barco.get_node_or_null("Lanterna") as PointLight2D
	if lanterna:
		lanterna.energy = 0.9 * clampf((Tempo.noite(t) - 0.3) / 0.4, 0.0, 1.0)


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
	var z := Mapa.zona_da_celula(mundo, pos)
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
		"vara": vara,
		"porao_usado": porao.usado(),
		"porao_cap": porao.capacidade,
		"pode_pescar": fisgada.is_empty() and pendente.is_empty() and not barco.atracado and _perto_de_cardume(),
		"medidor": _dados_medidor(),
		"pendente": pendente,
	}


# ------------------------------------------------------------------ pesca (spec 4.4, 5 e 6)

func _painel_aberto() -> bool:
	var hud := get_node_or_null("HUD")
	return hud != null and hud.has_method("painel_aberto") and hud.painel_aberto()


func adicionar_cardume(dados: Dictionary) -> Node2D:
	var c := CenaCardume.instantiate()
	c.configurar(dados)
	$Cardumes.add_child(c)
	cardumes.append(c)
	return c


## Mantém até MAX_CARDUMES em volta do barco: esquece os dispersos e os distantes e faz nascer outros fora da tela.
func atualizar_cardumes(dt: float) -> void:
	for c in cardumes.duplicate():
		if not is_instance_valid(c) or c.disperso:
			cardumes.erase(c)
		elif c.position.distance_to(barco.position) > R_SOME:
			cardumes.erase(c)
			c.queue_free()
	_t_nasce -= dt
	if cardumes.size() < MAX_CARDUMES and _t_nasce <= 0.0:
		_t_nasce = INTERVALO_NASCE
		var p := Pesca.ponto_de_nascimento(mundo, barco.position, _rng, R_NASCE_MIN, R_NASCE_MAX)
		if p == Vector2.INF:
			return
		var esp := Especies.sortear_especie(especies, Mapa.zona_da_celula(mundo, p), Tempo.eh_noite(t), "limpo", _rng)
		if not esp.is_empty():
			adicionar_cardume(Pesca.novo_cardume(esp, p, _rng))


func cardume_proximo() -> Node2D:
	var melhor: Node2D = null
	for c in cardumes:
		if is_instance_valid(c) and not c.disperso and (melhor == null
				or c.position.distance_squared_to(barco.position) < melhor.position.distance_squared_to(barco.position)):
			melhor = c
	return melhor


func _perto_de_cardume() -> bool:
	var c := cardume_proximo()
	return c != null and c.position.distance_to(barco.position) <= Pesca.DIST_PESCA


func _dados_medidor() -> Dictionary:
	if fisgada.is_empty():
		return {}
	var med = fisgada.prep.medidor
	return {"pos": med.posicao(fisgada.t), "verde": med.verde, "dourada": med.dourada, "centro": med.centro}


func _avancar_pesca(dt: float) -> void:
	espera_pesca = maxf(0.0, espera_pesca - dt)
	recarga_rede = maxf(0.0, recarga_rede - dt)
	if fisgada.is_empty():
		return
	fisgada.t += dt
	var c = fisgada.cardume
	if not is_instance_valid(c) or c.disperso or c.position.distance_to(barco.position) > Pesca.DIST_PESCA * 1.6:
		fisgada = {}
		_avisar("O cardume escapou do alcance")


## A tecla PESCAR: abre o medidor, para o ponteiro ou lança a rede. Devolve o que aconteceu:
## "medidor", "fisgou", "errou", "rede", "espera", "cheio", "atracado", "longe", "rapido" ou "vara".
func acao_pescar() -> String:
	if not pendente.is_empty():
		_avisar("Porão cheio: solte um peixe (I) para guardar o que você fisgou")
		porao_cheio.emit()
		return "cheio"
	if not fisgada.is_empty():
		return _parar_medidor()
	if barco.atracado:
		_avisar("Desatraque (E) para pescar")
		return "atracado"
	if espera_pesca > 0.0:
		return "espera"
	var c := cardume_proximo()
	var dist := c.position.distance_to(barco.position) if c != null else INF
	var motivo := Pesca.motivo_bloqueio(dist, barco.vel, Navegacao.vel_motor(barco.nivel_motor), vara,
			c.zona() if c != null else 0)
	if motivo != "":
		_avisar(Pesca.texto_bloqueio(motivo))
		return motivo
	var esp := Especies.por_id(especies, c.especie())
	if Pesca.usa_rede(tem_rede, c.estilo()):
		if recarga_rede > 0.0:
			_avisar("Rede recarregando (%d s)" % ceili(recarga_rede))
			return "espera"
		_lancar_rede(esp, c)
		return "rede"
	fisgada = {"cardume": c, "prep": Pesca.preparar(esp, _rng, nivel_pescador), "t": 0.0}
	return "medidor"


func _parar_medidor() -> String:
	var c = fisgada.cardume
	var prep: Dictionary = fisgada.prep
	var resultado: String = prep.medidor.resultado(fisgada.t)
	fisgada = {}
	var esp := Especies.por_id(especies, c.especie())
	var ex := Pesca.concluir(esp, prep, resultado, _rng)
	if ex.is_empty():
		espera_pesca = Pesca.ESPERA_ERRO
		var sobra: int = c.gastar_tentativa()
		_avisar("Escapou! O cardume se dispersou" if sobra == 0 else
				"Escapou! %s" % ("Resta 1 tentativa" if sobra == 1 else "Restam %d tentativas" % sobra))
		return "errou"
	c.dispersar()
	return "fisgou" if _guardar(ex, esp) else "cheio"


func _lancar_rede(esp: Dictionary, c) -> void:
	recarga_rede = Pesca.RECARGA_REDE
	var guardados := 0
	var perdidos := 0
	for ex in Especies.sortear_rede(esp, _rng):
		if porao.adicionar(ex):
			catalogo.registrar(ex)
			guardados += 1
		else:
			perdidos += 1
	c.dispersar()
	var texto := "Rede: %d × %s" % [guardados, esp.nome]
	if perdidos > 0:
		texto += " — porão cheio, %s" % ("1 voltou ao mar" if perdidos == 1 else "%d voltaram ao mar" % perdidos)
	_avisar(texto)
	_porao_mudou()


func _texto_exemplar(ex: Dictionary) -> String:
	var esp := Especies.por_id(especies, ex.especie)
	return "%s %d cm (%s)" % [esp.get("nome", ex.especie), roundi(ex.tam), ex.classe]


## Põe o exemplar no porão e no catálogo; se não couber, ele fica pendente até soltar um peixe ou desistir.
func _guardar(ex: Dictionary, _esp: Dictionary) -> bool:
	if not porao.adicionar(ex):
		pendente = ex
		_avisar("Porão cheio: solte um peixe para guardar %s" % _texto_exemplar(ex))
		porao_cheio.emit()
		return false
	var reg: Dictionary = catalogo.registrar(ex)
	var extra := " — espécie nova!" if reg.nova else (" — novo recorde!" if reg.recorde else "")
	_avisar("Pescou: %s%s" % [_texto_exemplar(ex), extra])
	_porao_mudou()
	return true


func _porao_mudou() -> void:
	porao_mudou.emit()
	var e := _estado()
	if e != null and e.has_signal("porao_mudou"):
		e.porao_mudou.emit()


func soltar_do_porao(indice: int) -> void:
	var solto: Dictionary = porao.soltar(indice)
	if solto.is_empty():
		return
	_porao_mudou()
	if not pendente.is_empty() and float(pendente.volume) <= porao.livre() + 1e-6:
		var ex := pendente
		pendente = {}
		_guardar(ex, {})
	elif solto.has("especie"):
		_avisar("Soltou: %s" % _texto_exemplar(solto))


func desistir_pendente() -> void:
	if pendente.is_empty():
		return
	_avisar("%s voltou ao mar" % _texto_exemplar(pendente))
	pendente = {}


func trocar_vara() -> void:
	if not fisgada.is_empty():
		_avisar("Termine a fisgada antes de trocar de vara")
		return
	var nova := Pesca.proxima_vara(varas, vara)
	if nova == vara:
		_avisar("Você só tem a vara %s" % NOME_VARA.get(vara, vara))
		return
	vara = nova
	_gravar_estado()
	_avisar("Vara: %s" % NOME_VARA.get(vara, vara))
