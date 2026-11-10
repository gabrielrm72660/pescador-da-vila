extends PanelContainer
## Catálogo de espécies (spec 12, tecla C): um espaço por espécie; "?" até a primeira captura.

signal fechar

const NOME_ZONA := ["Rasas", "Profundas", "Abissais"]

var _titulo := ""
var _celulas: Array = []
var _textos: Dictionary = {}


func mostrar(especies: Array, entradas: Dictionary) -> void:
	for f in get_children():
		remove_child(f)
		f.queue_free()
	_celulas.clear()
	_textos.clear()
	var conhecidas := 0
	for e in especies:
		if int(entradas.get(e.id, {}).get("qtd", 0)) > 0:
			conhecidas += 1
	_titulo = "Catálogo — %d de %d espécies" % [conhecidas, especies.size()]
	var caixa := VBoxContainer.new()
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.07, 0.11, 0.17, 0.96)
	fundo.border_color = Color(0.85, 0.65, 0.3)
	fundo.set_border_width_all(3)
	fundo.set_corner_radius_all(10)
	fundo.set_content_margin_all(24)
	add_theme_stylebox_override("panel", fundo)
	caixa.add_theme_constant_override("separation", 12)
	add_child(caixa)
	var t := Label.new()
	t.text = _titulo
	t.add_theme_font_size_override("font_size", 40)
	caixa.add_child(t)
	var grade := GridContainer.new()
	grade.columns = 6
	grade.add_theme_constant_override("h_separation", 12)
	grade.add_theme_constant_override("v_separation", 12)
	caixa.add_child(grade)
	for e in especies:
		var ent: Dictionary = entradas.get(e.id, {})
		var texto := "?\n%s" % NOME_ZONA[clampi(int(e.zona), 0, 2)]
		if int(ent.get("qtd", 0)) > 0:
			texto = "%s\n× %d\nrecorde %d cm" % [e.nome, int(ent.qtd), roundi(float(ent.get("recorde_cm", 0.0)))]
		if ent.get("titulo", false):
			texto += "\n★ troféu"
		var cel := Label.new()
		cel.text = texto
		cel.custom_minimum_size = Vector2(250, 150)
		cel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cel.add_theme_font_size_override("font_size", 24)
		if int(ent.get("qtd", 0)) == 0:
			cel.modulate = Color(1, 1, 1, 0.45)
		var moldura := PanelContainer.new()
		moldura.add_child(cel)
		grade.add_child(moldura)
		_celulas.append(cel)
		_textos[e.id] = texto
	var sair := Button.new()
	sair.text = "Fechar  [C]"
	sair.add_theme_font_size_override("font_size", 26)
	sair.pressed.connect(func(): fechar.emit())
	caixa.add_child(sair)


func titulo() -> String:
	return _titulo


func celulas() -> Array:
	return _celulas


func textos_por_id() -> Dictionary:
	return _textos
