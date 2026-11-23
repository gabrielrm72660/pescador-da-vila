extends CanvasLayer
## v0.7.0: suporte a controle (Xbox / PlayStation / genérico, pelo mapeamento padrão do Godot).
## O jogo foi feito para teclado: aqui o controle vira teclas virtuais (o resto do código não muda) e, nos menus,
## os botões ganham foco para o direcional andar entre eles, com um contorno dourado mostrando qual está escolhido.
##
## No mar:  analógico esq. ou RT/LT = leme e motor   ·  A = pescar / atracar   ·  RB = freio
##          X = porão   ·  Y = caderno de peixes   ·  Select/View = diário   ·  Start = menu
##          direcional: cima = carta, baixo = técnica, esq. = isca, dir. = profundidade   ·  LB = lanterna
##          analógico dir. = girar a câmera, R3 = recentrar, L3 = modo da câmera   ·  B = fecha o painel aberto
## Menus, cais e opções: direcional/analógico escolhe, A confirma, B volta (no cais, B zarpa).
## Diálogo, caderno e cartão do final tratam o controle eles mesmos.

var jogo: Node
var usando_controle := false
var _segurando: Dictionary = {}        # tecla virtual -> apertada
var _contorno: Control
var _relogio := 0.0
var _foco_espera := 0.0
var _eixo_caderno := 0.0

const ZONA_MORTA := 0.3

func construir(jogo_: Node) -> void:
	jogo = jogo_
	name = "Controle"
	layer = 120
	_contorno = Control.new()
	_contorno.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_contorno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contorno.draw.connect(_desenhar_contorno)
	add_child(_contorno)
	_preparar_acoes()

## Ações próprias do barco (o barco não usa mais ui_up/ui_left: o direcional fica livre para os atalhos).
static func _preparar_acoes() -> void:
	var acoes := {
		"barco_acelerar": [KEY_UP, [JOY_AXIS_LEFT_Y, -1.0], [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
		"barco_re": [KEY_DOWN, [JOY_AXIS_LEFT_Y, 1.0], [JOY_AXIS_TRIGGER_LEFT, 1.0]],
		"barco_esquerda": [KEY_LEFT, [JOY_AXIS_LEFT_X, -1.0]],
		"barco_direita": [KEY_RIGHT, [JOY_AXIS_LEFT_X, 1.0]],
	}
	for nome in acoes:
		if InputMap.has_action(nome):
			continue
		InputMap.add_action(nome, ZONA_MORTA)
		for e in acoes[nome]:
			if typeof(e) == TYPE_INT:
				var k := InputEventKey.new()
				k.physical_keycode = e
				InputMap.action_add_event(nome, k)
			else:
				var m := InputEventJoypadMotion.new()
				m.axis = e[0]
				m.axis_value = e[1]
				InputMap.action_add_event(nome, m)
	# A confirma o botão em foco nos menus (o padrão do Godot só tem Enter/Espaço)
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	if not InputMap.action_has_event("ui_accept", a):
		InputMap.action_add_event("ui_accept", a)

func _tecla(k: Key, apertada: bool = true) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = apertada
	Input.parse_input_event(e)

func _toque(k: Key) -> void:
	_tecla(k, true)
	_tecla(k, false)

func _segurar(k: Key, apertada: bool) -> void:
	if bool(_segurando.get(k, false)) == apertada:
		return
	_segurando[k] = apertada
	_tecla(k, apertada)

# ---------------------------------------------------------------- contexto

func _ui() -> Node:
	return jogo.interface

func _em_menu() -> bool:
	var ui := _ui()
	return ui.menu.visible or (ui.tela_inicial != null and ui.tela_inicial.visible) or (jogo.atracado and ui.porto.visible)

func _raiz_do_menu() -> Control:
	var ui := _ui()
	if ui.menu.visible:
		return ui.menu
	if ui.tela_inicial != null and ui.tela_inicial.visible:
		return ui.tela_inicial
	return ui.porto

func _cuida_sozinho() -> bool:
	var ui := _ui()
	return ui.dialogo_ativo() or ui.final_ativo or ui.caderno_aberto() or (jogo.graficos != null and jogo.graficos.esta_aberto())

# ---------------------------------------------------------------- entrada

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		if not usando_controle:
			usando_controle = true
			_foco_espera = 0.0
	elif (event is InputEventMouseMotion and event.relative.length() > 3.0) or event is InputEventMouseButton:
		if usando_controle:
			usando_controle = false
			get_viewport().gui_release_focus()
	if not (event is InputEventJoypadButton) or not event.pressed or jogo == null:
		return
	var b: int = event.button_index
	if _cuida_sozinho():
		return
	if _em_menu():
		match b:
			JOY_BUTTON_B, JOY_BUTTON_START: _toque(KEY_ESCAPE)
		return
	if _ui().mapa_aberto():
		match b:
			JOY_BUTTON_B, JOY_BUTTON_DPAD_UP, JOY_BUTTON_START: _toque(KEY_M)
		return
	if not jogo.iniciado:
		return
	var painel: String = _ui().hud.painel_aberto
	match b:
		JOY_BUTTON_A: _toque(KEY_F)
		JOY_BUTTON_B:
			if painel != "":
				_toque(KEY_ESCAPE)
		JOY_BUTTON_X: _toque(KEY_I)
		JOY_BUTTON_Y:
			if painel == "porao" and jogo.porao != null:
				jogo.porao.arrumar()                         # no porão aberto, Y arruma os peixes
			else:
				_toque(KEY_P)
		JOY_BUTTON_BACK: _toque(KEY_TAB)
		JOY_BUTTON_START: _toque(KEY_ESCAPE)
		JOY_BUTTON_DPAD_UP: _toque(KEY_M)
		JOY_BUTTON_DPAD_DOWN: _toque(KEY_J)
		JOY_BUTTON_DPAD_LEFT: _toque(KEY_B)
		JOY_BUTTON_DPAD_RIGHT: _toque(KEY_N)
		JOY_BUTTON_LEFT_SHOULDER: _toque(KEY_L)
		JOY_BUTTON_RIGHT_STICK: _toque(KEY_V)
		JOY_BUTTON_LEFT_STICK: _toque(KEY_C)

func _process(delta: float) -> void:
	if jogo == null:
		return
	_relogio += delta
	var ui := _ui()
	# freio no RB, segurado
	var no_mar: bool = jogo.iniciado and not _em_menu() and not _cuida_sozinho()
	_segurar(KEY_SPACE, no_mar and Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER))
	# câmera no analógico direito
	if no_mar and jogo.camera_barco != null and jogo.camera_barco.is_processing():
		var rx: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		var ry: float = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		if absf(rx) > 0.2 or absf(ry) > 0.2:
			jogo.camera_barco.girar(-rx * 2.2 * delta, ry * 1.2 * delta)
	# caderno aberto: o analógico também vira as páginas
	if ui.caderno_aberto():
		var lx: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		if absf(lx) > 0.6 and absf(_eixo_caderno) <= 0.6:
			ui.caderno.virar(1 if lx > 0.0 else -1)
		_eixo_caderno = lx
	# menus: os botões ganham foco enquanto o controle está em uso
	if usando_controle and _em_menu() and not _cuida_sozinho():
		_foco_espera -= delta
		if _foco_espera <= 0.0:
			_foco_espera = 0.4
			_garantir_foco(_raiz_do_menu())
	_contorno.queue_redraw()

func _garantir_foco(raiz: Control) -> void:
	var focaveis: Array = []
	_juntar(raiz, focaveis)
	var atual: Control = get_viewport().gui_get_focus_owner()
	if atual != null and atual.is_visible_in_tree() and focaveis.has(atual):
		return
	if not focaveis.is_empty():
		(focaveis[0] as Control).grab_focus()

func _juntar(no: Node, saida: Array) -> void:
	if no is Control and not (no as Control).is_visible_in_tree():
		return
	if (no is BaseButton and not (no as BaseButton).disabled) or no is Range:
		(no as Control).focus_mode = Control.FOCUS_ALL
		saida.append(no)
	for f in no.get_children():
		_juntar(f, saida)

func _desenhar_contorno() -> void:
	if not usando_controle or not _em_menu() or _cuida_sozinho():
		return
	var c: Control = get_viewport().gui_get_focus_owner()
	if c == null or not c.is_visible_in_tree():
		return
	var r: Rect2 = c.get_global_rect().grow(5.0)
	var a: float = 0.65 + 0.35 * sin(_relogio * 5.0)
	_contorno.draw_rect(r, Color(1.0, 0.82, 0.36, a), false, 3.0)
	_contorno.draw_rect(r.grow(3.0), Color(1.0, 0.82, 0.36, a * 0.35), false, 2.0)
