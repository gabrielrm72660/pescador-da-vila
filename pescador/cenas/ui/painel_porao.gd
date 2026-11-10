extends PanelContainer
## Lista do porão (spec 6, tecla I): cada exemplar com tamanho, classe, litros e valor, e um botão para soltar.
## Montado por código a partir do que recebe em mostrar(); quem solta de verdade é o Mundo, pelo sinal.

const Especies = preload("res://logica/especies.gd")

signal soltar(indice: int)
signal fechar

var _titulo := ""
var _pendente := ""
var _vazio := ""
var _linhas: Array = []
var _botoes: Dictionary = {}     # índice do porão -> Button


func mostrar(itens: Array, especies: Array, usado: float, capacidade: float, pendente: Dictionary) -> void:
	for f in get_children():
		remove_child(f)
		f.queue_free()
	_linhas.clear()
	_botoes.clear()
	_titulo = "Porão %d/%d L" % [roundi(usado), roundi(capacidade)]
	_pendente = "" if pendente.is_empty() else "Na mão: %s — solte um peixe para guardar" % _texto(pendente, especies)
	_vazio = "O porão está vazio" if itens.is_empty() else ""
	custom_minimum_size = Vector2(900, 0)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.07, 0.11, 0.17, 0.96)
	fundo.border_color = Color(0.85, 0.65, 0.3)
	fundo.set_border_width_all(3)
	fundo.set_corner_radius_all(10)
	fundo.set_content_margin_all(24)
	add_theme_stylebox_override("panel", fundo)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 10)
	add_child(caixa)
	caixa.add_child(_rotulo(_titulo, 40))
	if _pendente != "":
		var p := _rotulo(_pendente, 28)
		p.modulate = Color(1, 0.85, 0.4)
		caixa.add_child(p)
	if _vazio != "":
		caixa.add_child(_rotulo(_vazio, 28))
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(0, 460)
	caixa.add_child(rolagem)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(lista)
	for i in itens.size():
		var it: Dictionary = itens[i]
		var linha := HBoxContainer.new()
		lista.add_child(linha)
		var texto := _texto(it, especies)
		_linhas.append(texto)
		var r := _rotulo(texto, 26)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(r)
		if not it.get("carga", false):
			var b := Button.new()
			b.text = "Soltar"
			b.add_theme_font_size_override("font_size", 24)
			b.pressed.connect(func(): soltar.emit(i))
			linha.add_child(b)
			_botoes[i] = b
	var sair := Button.new()
	sair.text = "Fechar  [I]" if pendente.is_empty() else "Fechar e devolver o peixe ao mar  [I]"
	sair.add_theme_font_size_override("font_size", 26)
	sair.pressed.connect(func(): fechar.emit())
	caixa.add_child(sair)


static func _texto(it: Dictionary, especies: Array) -> String:
	if it.get("carga", false):
		return ("%s — carga de missão — %.1f L" % [it.get("nome", "Carga"), float(it.volume)]).replace(".", ",")
	var esp := Especies.por_id(especies, str(it.get("especie", "")))
	return "%s — %d cm (%s) — %s L — R$ %d" % [esp.get("nome", it.get("especie", "?")), roundi(float(it.get("tam", 0))),
			it.get("classe", "?"), ("%.1f" % float(it.get("volume", 0.0))).replace(".", ","), int(it.get("valor", 0))]


func _rotulo(texto: String, tam: int) -> Label:
	var r := Label.new()
	r.text = texto
	r.add_theme_font_size_override("font_size", tam)
	return r


func titulo() -> String:
	return _titulo


func texto_pendente() -> String:
	return _pendente


func texto_vazio() -> String:
	return _vazio


func linhas() -> Array:
	return _linhas


func botoes_soltar() -> int:
	return _botoes.size()


func apertar_soltar(indice: int) -> void:
	if _botoes.has(indice):
		_botoes[indice].pressed.emit()
