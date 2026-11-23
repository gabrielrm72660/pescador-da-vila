extends Control
## v0.6.0: tela inicial. O jogo abre aqui (câmera passeando em volta da vila, na hora dourada) e só depois
## de escolher vai para o barco. Nome e ícone do jogo vêm de scripts/marca.gd.

signal continuar
signal novo_jogo
signal opcoes
signal sair

const T = preload("res://scripts/idioma.gd")
const Marca = preload("res://scripts/marca.gd")
const Aq = preload("res://scripts/aquarela.gd")

var ui: Node                       # scripts/interface.gd (usa os botões de aquarela dela)
var _botao_continuar: Button
var _botao_novo: Button
var _titulo: Label
var _subtitulo: Label
var _cortina: ColorRect
var _confirmar: float = -100.0
var _tem_salva: bool = false
var em_transicao: bool = false

func construir(interface_: Node) -> void:
	ui = interface_
	name = "TelaInicial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# sombra à esquerda (onde fica o texto) e no pé da tela, para ler sobre o cenário
	var sombra := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.05, 0.08, 0.80))
	grad.set_color(1, Color(0.02, 0.05, 0.08, 0.0))
	grad.add_point(0.42, Color(0.02, 0.05, 0.08, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.width = 256
	tex.height = 4
	sombra.texture = tex
	sombra.stretch_mode = TextureRect.STRETCH_SCALE
	sombra.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	sombra.anchor_right = 0.62
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)

	var col := VBoxContainer.new()
	col.position = Vector2(96, 120)
	col.add_theme_constant_override("separation", 12)
	add_child(col)

	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 22)
	col.add_child(topo)
	var icone := TextureRect.new()
	if ResourceLoader.exists(Marca.ICONE):
		icone.texture = load(Marca.ICONE)
	icone.custom_minimum_size = Vector2(124, 124)
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	topo.add_child(icone)
	var nomes := VBoxContainer.new()
	nomes.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_child(nomes)
	_titulo = ui._nova_label(Marca.NOME, 96, Color(0.97, 0.93, 0.84), false, true)
	_titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	_titulo.add_theme_constant_override("shadow_offset_x", 3)
	_titulo.add_theme_constant_override("shadow_offset_y", 4)
	nomes.add_child(_titulo)
	_subtitulo = ui._nova_label("", 24, Color(0.86, 0.88, 0.84), false)
	ui._t(_subtitulo, "Uma vida de pescador no Atlântico brasileiro.")
	nomes.add_child(_subtitulo)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 46)
	col.add_child(espaco)

	_botao_continuar = ui._botao_aq("", "turquesa", 41.0, Aq.NANQUIM, 28, Vector2(420, 56))
	_botao_continuar.pressed.connect(func(): continuar.emit())
	col.add_child(_botao_continuar)
	_botao_novo = ui._botao_aq("", "mar", 42.0, Aq.CREME, 25, Vector2(420, 50))
	_botao_novo.pressed.connect(_clicar_novo)
	col.add_child(_botao_novo)
	col.add_child(ui._t(ui._botao_aq("", "mar", 43.0, Aq.CREME, 25, Vector2(420, 50)), "OPÇÕES", func(): opcoes.emit()))
	col.add_child(ui._t(ui._botao_aq("", "terracota", 44.0, Aq.CREME, 25, Vector2(420, 50)), "SAIR DO JOGO", func(): sair.emit()))

	var pe: Label = ui._nova_label("", 18, Color(0.80, 0.83, 0.80), true)
	ui._t(pe, "W A S D  navegar   •   F  pescar e atracar   •   I  porão   •   TAB  diário   •   M  carta   •   ESC  menu")
	pe.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	pe.position = Vector2(96, 0)
	pe.anchor_top = 1.0
	pe.anchor_bottom = 1.0
	pe.offset_top = -64
	pe.offset_bottom = -30
	pe.offset_left = 96
	pe.offset_right = 1100
	add_child(pe)
	var versao: Label = ui._nova_label(Marca.VERSAO, 16, Color(0.75, 0.78, 0.76), false)
	versao.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	versao.offset_left = -140
	versao.offset_top = -46
	versao.offset_right = -28
	versao.offset_bottom = -20
	versao.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(versao)

	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 1)
	_cortina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cortina)
	var abrir := create_tween()
	abrir.tween_property(_cortina, "color:a", 0.0, 1.6)

func mostrar(tem_salva: bool) -> void:
	_tem_salva = tem_salva
	visible = true
	atualizar_textos()

func atualizar_textos() -> void:
	_titulo.text = Marca.NOME
	_botao_continuar.text = T.t("CONTINUAR A VIAGEM") if _tem_salva else T.t("COMEÇAR A VIAGEM")
	_botao_novo.visible = _tem_salva
	_botao_novo.text = T.t("NOVO JOGO")
	if _botao_novo.has_method("marcar"):
		_botao_novo.marcar(false)

## Com uma viagem salva, "Novo jogo" pede confirmação no primeiro clique.
func _clicar_novo() -> void:
	var agora := Time.get_ticks_msec() / 1000.0
	if agora - _confirmar > 4.0:
		_confirmar = agora
		_botao_novo.text = T.t("CONFIRMAR: APAGAR A VIAGEM SALVA?")
		if _botao_novo.has_method("marcar"):
			_botao_novo.marcar(true)
		return
	_confirmar = -100.0
	novo_jogo.emit()

## Escurece, chama "depois" (que troca a câmera para o barco) e clareia de novo.
func sair_com_cortina(depois: Callable) -> void:
	if em_transicao:
		return
	em_transicao = true
	_cortina.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_cortina, "color:a", 1.0, 0.45)
	t.tween_callback(func():
		depois.call()
		for filho in get_children():
			if filho != _cortina:
				filho.visible = false)
	t.tween_property(_cortina, "color:a", 0.0, 0.7)
	t.tween_callback(func():
		visible = false
		em_transicao = false
		_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for filho in get_children():
			filho.visible = true)
