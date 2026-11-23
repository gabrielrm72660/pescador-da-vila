extends Control
## v0.7.0: o cartão do final da história: tela escurecendo, título, o texto e um botão.

signal fechou

const Aq = preload("res://scripts/aquarela.gd")
const T = preload("res://scripts/idioma.gd")

var _fundo: ColorRect
var _coluna: VBoxContainer
var _botao: Button
var _t := 0.0

func mostrar(ui: Node, titulo: String, texto: String, rotulo_botao: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_fundo = ColorRect.new()
	_fundo.color = Color(0.01, 0.02, 0.04, 0.0)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	_coluna = VBoxContainer.new()
	_coluna.custom_minimum_size = Vector2(760, 0)
	_coluna.add_theme_constant_override("separation", 22)
	_coluna.modulate.a = 0.0
	centro.add_child(_coluna)
	var t: Label = ui._nova_label(titulo, 64, Color(0.96, 0.80, 0.42), false, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coluna.add_child(t)
	var corpo: Label = ui._nova_label(texto, 26, Color(0.93, 0.91, 0.84), true)
	corpo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corpo.custom_minimum_size = Vector2(760, 0)
	_coluna.add_child(corpo)
	var fim: Label = ui._nova_label(T.t("~  FIM  ~"), 30, Color(0.80, 0.82, 0.86, 0.8), false, true)
	fim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coluna.add_child(fim)
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	_coluna.add_child(linha)
	_botao = ui._botao_aq(rotulo_botao, "ouro", 99.0, Aq.NANQUIM, 26, Vector2(320, 54))
	_botao.pressed.connect(_fechar)
	linha.add_child(_botao)
	_botao.disabled = true

func _process(delta: float) -> void:
	_t += delta
	if _fundo != null:
		_fundo.color.a = minf(0.94, _t / 2.0)
		_coluna.modulate.a = clampf((_t - 1.2) / 1.6, 0.0, 1.0)
		if _t > 3.5 and _botao.disabled:
			_botao.disabled = false
			_botao.grab_focus()

func _input(event: InputEvent) -> void:
	if _botao == null or _botao.disabled:
		return
	if (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_F, KEY_ENTER, KEY_SPACE, KEY_E]) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
		get_viewport().set_input_as_handled()
		_fechar()

func _fechar() -> void:
	if _botao.disabled:
		return
	_botao.disabled = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): fechou.emit())
