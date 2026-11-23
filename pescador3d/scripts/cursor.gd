extends Node
## v0.7.4: o cursor do mouse do Bruma e quando ele aparece.
##  - A seta do Windows dá lugar a uma seta em aquarela turquesa (assets/cursor/seta.png); sobre o que dá para clicar
##    (botões, os botões do HUD, as marcas do caderno) ela fica dourada (seta_sobre.png).
##  - Navegando, o cursor some e o mouse fica preso na janela: mexer o mouse gira a câmera (sem segurar botão).
##  - Ele volta sozinho quando há algo para clicar: tela de título, menu, cais, conversas, porão, diário, caderno,
##    carta, cartão do final, opções gráficas, Modo Construtor. Segurar Alt mostra o cursor no mar (para os botões do HUD).
##  - Com controle o cursor fica escondido; no celular o sistema é outro (toque) e nada disso vale.

const SETA := preload("res://assets/cursor/seta.png")
const SETA_SOBRE := preload("res://assets/cursor/seta_sobre.png")
const PONTA := Vector2(2, 2)
const T = preload("res://scripts/idioma.gd")

var jogo: Node
var _modo := -1
var _janela_ativa := true
var _avisou := false

func construir(jogo_: Node) -> void:
	jogo = jogo_
	name = "Cursor"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _celular():
		return
	Input.set_custom_mouse_cursor(SETA, Input.CURSOR_ARROW, PONTA)
	Input.set_custom_mouse_cursor(SETA_SOBRE, Input.CURSOR_POINTING_HAND, PONTA)
	Input.set_custom_mouse_cursor(SETA, Input.CURSOR_IBEAM, PONTA)
	# todo botão (os que já existem e os que forem criados) mostra a seta dourada
	_marcar_botoes(get_tree().root)
	get_tree().node_added.connect(func(n: Node):
		if n is BaseButton or n is Range:
			(n as Control).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND)

static func _celular() -> bool:
	return OS.has_feature("mobile") or OS.get_environment("PESCADOR_TOQUE") == "1"

func _marcar_botoes(no: Node) -> void:
	if no is BaseButton or no is Range:
		(no as Control).mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for f in no.get_children():
		_marcar_botoes(f)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_janela_ativa = false
			_aplicar(Input.MOUSE_MODE_VISIBLE)
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_janela_ativa = true

## Há algo na tela que pede o mouse?
func precisa_cursor() -> bool:
	var ui = jogo.interface
	if not jogo.iniciado or jogo.no_titulo or jogo.em_pausa or jogo.atracado:
		return true
	if ui.menu.visible or (ui.tela_inicial != null and ui.tela_inicial.visible):
		return true
	if ui.dialogo_ativo() or ui.final_ativo or ui.caderno_aberto() or ui.mapa_aberto() or ui.hud.painel_aberto != "":
		return true
	if jogo.graficos != null and jogo.graficos.esta_aberto():
		return true
	if jogo.construtor != null and jogo.construtor.ativo:
		return true
	return Input.is_physical_key_pressed(KEY_ALT)

func _process(_delta: float) -> void:
	if jogo == null or _celular():
		return
	var controle: Node = jogo.get_node_or_null("Controle")
	var modo: int
	if not _janela_ativa:
		modo = Input.MOUSE_MODE_VISIBLE
	elif precisa_cursor():
		modo = Input.MOUSE_MODE_HIDDEN if (controle != null and controle.usando_controle) else Input.MOUSE_MODE_VISIBLE
	else:
		modo = Input.MOUSE_MODE_CAPTURED
	_aplicar(modo)
	if jogo.camera_barco != null:
		jogo.camera_barco.mouse_livre = modo == Input.MOUSE_MODE_CAPTURED
	# botões desenhados à mão (HUD e caderno): seta dourada quando o mouse está em cima de um deles
	var hud = jogo.interface.hud
	hud.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if String(hud._sobre) != "" else Control.CURSOR_ARROW

func _aplicar(modo: int) -> void:
	if modo == _modo:
		return
	if modo == Input.MOUSE_MODE_CAPTURED and jogo != null:
		jogo.interface.hud._sobre = ""                     # o mouse sumiu: nenhum botão do HUD fica aceso
		if not _avisou:                                    # a primeira vez na sessão, explica
			_avisou = true
			jogo.interface.aviso(T.t("Mexa o mouse para olhar em volta. Segure Alt para usar o cursor."))
	_modo = modo
	Input.mouse_mode = modo
