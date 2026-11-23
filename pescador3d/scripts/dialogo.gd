extends Control
## v0.6.0: caixa de diálogo dos NPCs do cais, no estilo de DREDGE: retrato grande ao centro, caixa de texto
## embaixo (nome e ofício do personagem, texto que vai aparecendo) e o botão "Continuar".
## abrir([{npc: id, texto: "..."}]) mostra as falas em sequência; terminou() sai quando acabam (ou com ESC).

signal terminou

const T = preload("res://scripts/idioma.gd")
const Aq = preload("res://scripts/aquarela.gd")
const Npcs = preload("res://scripts/npcs.gd")

const VEL_TEXTO := 52.0                       # letras por segundo
const CREME := Color(0.96, 0.93, 0.84)

var ui: Node
var ativo := false
var _linhas: Array = []
var _i := 0
var _npc := ""
var _dim: ColorRect
var _retrato: TextureRect
var _caixa: PanelContainer
var _nome: Label
var _papel: Label
var _texto: Label
var _botao: Button
var _dica: Label
var _letras := 0.0
var _total := 0
var _entrada := 0.0
var _liberado := 0.0
var _relogio := 0.0
var _saindo := false

func construir(interface_: Node) -> void:
	ui = interface_
	name = "Dialogo"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	resized.connect(_ajustar)

	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.03, 0.05, 0.0)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_retrato = TextureRect.new()
	_retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_retrato.stretch_mode = TextureRect.STRETCH_SCALE
	_retrato.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_retrato)

	_caixa = PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.050, 0.085, 0.135, 0.95)
	estilo.border_color = Color(0.86, 0.78, 0.58, 0.60)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(10)
	estilo.shadow_color = Color(0, 0, 0, 0.45)
	estilo.shadow_size = 14
	estilo.content_margin_left = 34
	estilo.content_margin_right = 34
	estilo.content_margin_top = 18
	estilo.content_margin_bottom = 16
	_caixa.add_theme_stylebox_override("panel", estilo)
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caixa)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caixa.add_child(col)

	var cabeca := HBoxContainer.new()
	cabeca.add_theme_constant_override("separation", 16)
	cabeca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cabeca)
	_nome = ui._nova_label("", 40, Color(0.96, 0.78, 0.38), false, true)
	cabeca.add_child(_nome)
	_papel = ui._nova_label("", 22, Color(0.80, 0.84, 0.82, 0.85), false)
	_papel.size_flags_vertical = Control.SIZE_SHRINK_END
	cabeca.add_child(_papel)

	_texto = ui._nova_label("", 30, CREME, true)
	_texto.custom_minimum_size = Vector2(0, 104)
	_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_texto)

	var pe := HBoxContainer.new()
	pe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pe)
	_dica = ui._nova_label("", 17, Color(0.72, 0.78, 0.78, 0.8), false)
	_dica.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dica.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pe.add_child(_dica)
	_botao = ui._botao_aq("", "turquesa", 61.0, Aq.NANQUIM, 24, Vector2(200, 42))
	_botao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pe.add_child(_botao)
	atualizar_textos()

func atualizar_textos() -> void:
	_botao.text = T.t("Continuar") + "  ▸"
	_dica.text = T.t("F ou clique: continuar   •   ESC: pular")
	if ativo and _npc != "":
		_nome.text = T.t(Npcs.DADOS[_npc].nome)
		_papel.text = T.t(Npcs.DADOS[_npc].papel)
	if ativo and _i < _linhas.size():                 # a fala na tela também troca de idioma
		var vis: int = _texto.visible_characters
		_texto.text = _texto_da(_linhas[_i])
		_total = _texto.text.length()
		if vis >= 0:
			_letras = minf(_letras, float(_total))
			_texto.visible_characters = mini(vis, _total)

## O texto da fala no idioma atual: retraduz pela chave em português quando ela vem junto.
func _texto_da(fala: Dictionary) -> String:
	if not fala.has("chave"):
		return String(fala.texto)
	var t: String = T.t(String(fala.chave))
	if fala.has("arg"):
		t = t % T.t(String(fala.arg))
	return t

## Falas: [{npc: "zefa", texto: "..."}]. O texto já vem traduzido.
func abrir(linhas: Array) -> void:
	if linhas.is_empty():
		terminou.emit()
		return
	_linhas = linhas
	_i = 0
	_npc = ""
	ativo = true
	_saindo = false
	visible = true
	_entrada = 0.0
	_liberado = 0.45
	_ajustar()
	_mostrar()

func _mostrar() -> void:
	var fala: Dictionary = _linhas[_i]
	var id: String = fala.npc
	if id != _npc:
		_npc = id
		var dados: Dictionary = Npcs.DADOS[id]
		_retrato.texture = Npcs.retrato(id)
		_nome.text = T.t(dados.nome)
		_nome.add_theme_color_override("font_color", Color(dados.cor).lightened(0.25))
		_papel.text = T.t(dados.papel)
		_ajustar()
		if _entrada >= 1.0:
			_entrada = 0.55                       # troca de interlocutor: o retrato entra de novo
	_texto.text = _texto_da(fala)
	_total = _texto.text.length()
	_letras = 0.0
	_texto.visible_characters = 0

func _ajustar() -> void:
	if _caixa == null:
		return
	var tela := size
	var larg := clampf(tela.x * 0.66, 620.0, 1180.0)
	var alt := 232.0
	_caixa.size = Vector2(larg, alt)
	_caixa.position = Vector2((tela.x - larg) * 0.5, tela.y - alt - 38.0)
	var tex: Texture2D = _retrato.texture
	if tex != null:
		var h := minf(tela.y * 0.80, _caixa.position.y + 78.0)
		var w := h * float(tex.get_width()) / float(tex.get_height())
		_retrato.size = Vector2(w, h)
		_retrato.pivot_offset = Vector2(w * 0.5, h)
		_retrato.position = Vector2(tela.x * 0.5 - w * 0.5 - larg * 0.15, _caixa.position.y + 78.0 - h)

func _process(delta: float) -> void:
	if not ativo and not _saindo:
		return
	_relogio += delta
	if ativo:
		_entrada = minf(1.0, _entrada + delta / 0.38)
		_liberado = maxf(0.0, _liberado - delta)
		if _total > 0 and _texto.visible_characters != -1:
			_letras += delta * VEL_TEXTO
			if _letras >= float(_total):
				_texto.visible_characters = -1
			else:
				_texto.visible_characters = int(_letras)
	var e := ease(_entrada, 0.4)
	if not _saindo:
		_dim.color.a = 0.58 * e
		_caixa.modulate.a = e
		_caixa.position.y = size.y - _caixa.size.y - 38.0 + (1.0 - e) * 36.0
		_retrato.modulate.a = e
		var respira := 1.0 + 0.007 * sin(_relogio * 1.5)
		_retrato.scale = Vector2(1.0, respira)
		var base := size.x * 0.5 - _retrato.size.x * 0.5 - _caixa.size.x * 0.15
		_retrato.position.x = base - (1.0 - e) * 70.0
	_botao.modulate.a = 0.78 + 0.22 * sin(_relogio * 4.0) if _texto.visible_characters == -1 else 0.35

func _input(event: InputEvent) -> void:
	if not ativo:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F, KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_avancar()
			KEY_ESCAPE:
				_encerrar()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_avancar()
		get_viewport().set_input_as_handled()

func _avancar() -> void:
	if _liberado > 0.0:
		return
	if _texto.visible_characters != -1:                     # primeiro toque: mostra a fala inteira
		_texto.visible_characters = -1
		return
	_i += 1
	if _i >= _linhas.size():
		_encerrar()
		return
	_mostrar()

func _encerrar() -> void:
	if not ativo:
		return
	ativo = false
	_saindo = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "color:a", 0.0, 0.20)
	tween.tween_property(_caixa, "modulate:a", 0.0, 0.20)
	tween.tween_property(_retrato, "modulate:a", 0.0, 0.20)
	tween.chain().tween_callback(func():
		_saindo = false
		visible = false
		terminou.emit())
