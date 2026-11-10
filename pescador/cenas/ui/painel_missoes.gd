extends PanelContainer
## Missões ativas (spec 8, tecla J): o que falta em cada uma e o prazo.

const Missoes = preload("res://logica/missoes.gd")

signal fechar

var _titulo := ""
var _textos: Array = []


func mostrar(estado, dados: Dictionary, especies: Array, pos: Vector2) -> void:
	for f in get_children():
		remove_child(f)
		f.queue_free()
	_textos.clear()
	_titulo = "Missões — %d de %d" % [estado.missoes.ativas.size(), int(Missoes.config().get("max_ativas", 3))]
	custom_minimum_size = Vector2(1000, 0)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.07, 0.11, 0.17, 0.96)
	fundo.border_color = Color(0.85, 0.65, 0.3)
	fundo.set_border_width_all(3)
	fundo.set_corner_radius_all(10)
	fundo.set_content_margin_all(24)
	add_theme_stylebox_override("panel", fundo)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 14)
	add_child(caixa)
	caixa.add_child(_rotulo(_titulo, 40))
	if estado.missoes.ativas.is_empty():
		_textos.append("Nenhuma missão ativa. Aceite uma no mercado de qualquer cidade.")
	for m in estado.missoes.ativas:
		_textos.append("%s\n%s" % [Missoes.descricao(m, especies, dados), Missoes.texto_progresso(m, estado.porao, pos, estado.dia)])
	for t in _textos:
		var r := _rotulo(t, 26)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caixa.add_child(r)
	var sair := Button.new()
	sair.text = "Fechar  [J]"
	sair.add_theme_font_size_override("font_size", 26)
	sair.pressed.connect(func(): fechar.emit())
	caixa.add_child(sair)


func _rotulo(texto: String, tam: int) -> Label:
	var r := Label.new()
	r.text = texto
	r.add_theme_font_size_override("font_size", tam)
	return r


func titulo() -> String:
	return _titulo


func textos() -> Array:
	return _textos
