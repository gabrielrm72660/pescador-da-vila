extends CanvasLayer
## v0.7.0: controles de toque para celular e tablet. Só aparece em aparelho móvel (ou com PESCADOR_TOQUE=1, para testar).
## Como no controle (scripts/controle.gd), os toques viram teclas virtuais e o resto do jogo não muda:
##  - à esquerda, um manche que aparece onde o dedo encosta: para cima acelera, para baixo dá ré, para os lados vira;
##  - à direita, PESCAR (F) grande, FREAR (espaço, segurado) e botões menores: carta (M), isca (B), fundo (N),
##    técnica (J), lanterna (L) e menu (Esc);
##  - arrastar o dedo no resto da tela gira a câmera.
## Porão, caderno, diário, cais, menus e diálogos já funcionam com o toque, que o Godot entrega como clique de mouse.

const Aq = preload("res://scripts/aquarela.gd")
const T = preload("res://scripts/idioma.gd")

var jogo: Node
var _tela: Control
var _manche_dedo := -1
var _manche_centro := Vector2.ZERO
var _manche_ponta := Vector2.ZERO
var _camera_dedo := -1
var _botao_dedo: Dictionary = {}       # dedo -> id do botão
var _segurando: Dictionary = {}
var _relogio := 0.0

const RAIO_MANCHE := 78.0
const BOTOES := [
	{"id": "pescar", "tecla": KEY_F, "rotulo": "Pescar", "pos": Vector2(-120, -250), "raio": 62.0, "segura": false},
	{"id": "frear", "tecla": KEY_SPACE, "rotulo": "Frear", "pos": Vector2(-250, -200), "raio": 46.0, "segura": true},
	{"id": "mapa", "tecla": KEY_M, "rotulo": "Carta", "pos": Vector2(-60, -470), "raio": 32.0, "segura": false},
	{"id": "isca", "tecla": KEY_B, "rotulo": "Isca", "pos": Vector2(-140, -410), "raio": 32.0, "segura": false},
	{"id": "fundo", "tecla": KEY_N, "rotulo": "Fundo", "pos": Vector2(-230, -380), "raio": 32.0, "segura": false},
	{"id": "tecnica", "tecla": KEY_J, "rotulo": "Técnica", "pos": Vector2(-310, -320), "raio": 32.0, "segura": false},
	{"id": "luz", "tecla": KEY_L, "rotulo": "Luz", "pos": Vector2(-60, -390), "raio": 28.0, "segura": false},
	{"id": "menu", "tecla": KEY_ESCAPE, "rotulo": "Menu", "pos": Vector2(-60, 0), "raio": 28.0, "segura": false},
]

static func ligado() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.get_environment("PESCADOR_TOQUE") == "1"

func construir(jogo_: Node) -> void:
	jogo = jogo_
	name = "Toque"
	layer = 110
	_tela = Control.new()
	_tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tela.draw.connect(_desenhar)
	add_child(_tela)

## Só no mar: menus, cais, diálogos, carta, caderno e cartões tratam o toque sozinhos.
func _no_mar() -> bool:
	var ui = jogo.interface
	return jogo.iniciado and not jogo.no_titulo and not jogo.em_pausa and not jogo.atracado and not ui.menu.visible \
			and not ui.dialogo_ativo() and not ui.final_ativo and not ui.caderno_aberto() and not ui.mapa_aberto() \
			and ui.hud.painel_aberto == ""

## Com a carta aberta, só o botão da carta fica (para fechá-la).
func _so_carta() -> bool:
	var ui = jogo.interface
	return jogo.iniciado and ui.mapa_aberto() and not ui.menu.visible and not ui.dialogo_ativo()

func _botoes_visiveis() -> Array:
	if _so_carta():
		return BOTOES.filter(func(b): return b.id == "mapa")
	return BOTOES if _no_mar() else []

func _pos_botao(b: Dictionary) -> Vector2:
	var s: Vector2 = _tela.size
	var p: Vector2 = b.pos
	if b.id == "menu":
		return Vector2(s.x - 60.0, 150.0)
	return Vector2(s.x + p.x, s.y + p.y)

func _tecla(k: Key, apertada: bool) -> void:
	if bool(_segurando.get(k, false)) == apertada and apertada:
		return
	_segurando[k] = apertada
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = apertada
	Input.parse_input_event(e)

func _input(event: InputEvent) -> void:
	if jogo == null:
		return
	var mar: bool = _no_mar()
	if not mar and not _so_carta():
		if _manche_dedo != -1 or _camera_dedo != -1 or not _botao_dedo.is_empty():
			_soltar_tudo()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			for b in _botoes_visiveis():
				if event.position.distance_to(_pos_botao(b)) <= float(b.raio) + 10.0:
					_botao_dedo[event.index] = b.id
					_tecla(b.tecla, true)
					if not b.segura:
						_tecla(b.tecla, false)
					get_viewport().set_input_as_handled()
					return
			if not mar or _por_cima_do_hud(event.position):
				return
			if event.position.x < _tela.size.x * 0.42 and _manche_dedo == -1:
				_manche_dedo = event.index
				_manche_centro = event.position
				_manche_ponta = event.position
				get_viewport().set_input_as_handled()
			elif _camera_dedo == -1:
				_camera_dedo = event.index
		else:
			if _botao_dedo.has(event.index):
				for b in BOTOES:
					if b.id == _botao_dedo[event.index] and b.segura:
						_tecla(b.tecla, false)
				_botao_dedo.erase(event.index)
			if event.index == _manche_dedo:
				_manche_dedo = -1
				_aplicar_manche(Vector2.ZERO)
			if event.index == _camera_dedo:
				_camera_dedo = -1
	elif event is InputEventScreenDrag:
		if event.index == _manche_dedo:
			var v: Vector2 = event.position - _manche_centro
			if v.length() > RAIO_MANCHE:
				_manche_centro = event.position - v.normalized() * RAIO_MANCHE      # o manche acompanha o dedo
				v = v.normalized() * RAIO_MANCHE
			_manche_ponta = _manche_centro + v
			_aplicar_manche(v / RAIO_MANCHE)
			get_viewport().set_input_as_handled()
		elif event.index == _camera_dedo and jogo.camera_barco != null:
			jogo.camera_barco.girar(-event.relative.x * 0.006, event.relative.y * 0.004)

## Os botões do HUD (pescar, porão, caderno, diário) ficam embaixo, no meio: o toque ali é deles.
func _por_cima_do_hud(p: Vector2) -> bool:
	var s: Vector2 = _tela.size
	return p.y > s.y - 130.0 and absf(p.x - s.x / 2.0) < 230.0

func _aplicar_manche(v: Vector2) -> void:
	_tecla(KEY_W, v.y < -0.35)
	_tecla(KEY_S, v.y > 0.45)
	_tecla(KEY_A, v.x < -0.35)
	_tecla(KEY_D, v.x > 0.35)

func _soltar_tudo() -> void:
	_manche_dedo = -1
	_camera_dedo = -1
	_botao_dedo.clear()
	for k in _segurando.keys():
		if _segurando[k]:
			_tecla(k, false)

func _process(delta: float) -> void:
	_relogio += delta
	_tela.visible = jogo != null and (_no_mar() or _so_carta())
	_tela.queue_redraw()

func _desenhar() -> void:
	if _so_carta():
		for b in _botoes_visiveis():
			_botao(b)
		return
	# manche: um aro claro e o pino; parado, só a dica de onde encostar
	if _manche_dedo != -1:
		_tela.draw_circle(_manche_centro, RAIO_MANCHE, Color(0.02, 0.06, 0.10, 0.35))
		_tela.draw_arc(_manche_centro, RAIO_MANCHE, 0.0, TAU, 48, Color(Aq.CREME, 0.55), 3.0, true)
		_tela.draw_circle(_manche_ponta, 32.0, Color(Aq.CREME, 0.55))
	else:
		var c := Vector2(150.0, _tela.size.y - 330.0)
		_tela.draw_arc(c, RAIO_MANCHE, 0.0, TAU, 48, Color(Aq.CREME, 0.22 + 0.06 * sin(_relogio * 2.0)), 2.5, true)
		_centrar(T.t("Leme"), c + Vector2(0, 7), 20, Color(Aq.CREME, 0.45))
	for b in BOTOES:
		_botao(b)

func _botao(b: Dictionary) -> void:
	if true:
		var p: Vector2 = _pos_botao(b)
		var aceso: bool = _botao_dedo.values().has(b.id)
		var cor: Color = Color(Aq.OURO, 0.85) if aceso else Color(0.04, 0.12, 0.18, 0.62)
		if b.id == "pescar":
			cor = Color(Aq.TURQUESA, 0.80) if not aceso else Color(Aq.OURO, 0.9)
		_tela.draw_circle(p, float(b.raio), cor)
		_tela.draw_arc(p, float(b.raio), 0.0, TAU, 40, Color(Aq.CREME, 0.7), 2.0, true)
		var tam: int = 22 if float(b.raio) > 40.0 else 15
		_centrar(T.t(String(b.rotulo)), p + Vector2(0, tam * 0.35), tam, Aq.CREME if not aceso else Aq.NANQUIM)

func _centrar(t: String, c: Vector2, tam: int, cor: Color) -> void:
	var l: float = Aq.FONTE_TITULO.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_tela.draw_string(Aq.FONTE_TITULO, Vector2(c.x - l / 2.0, c.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)
