extends Control
## Carta náutica (tecla M), v0.5.8 no espírito do mapa do DREDGE: uma folha de papel com dobras nos cantos, grade verde
## com letras embaixo (colunas) e números à esquerda (linhas, 1 embaixo), ilhas cheias em tom de terra com contorno de
## tinta e uma linha clara por dentro, linhas de profundidade em volta e marcas de cais, recifes e bancos.
## Escala fixa do mundo inteiro; roda = zoom em volta do mouse, botão direito arrasta, clique marca destino.

const Aq = preload("res://scripts/aquarela.gd")
const T = preload("res://scripts/idioma.gd")

var barco: Node3D = null
var ilhas: Array = []
var pontos_extras: Array = []
var marcador: Vector2 = Vector2.ZERO
var tem_marcador: bool = false

var _fundo: Control                 # v0.7.2: fundo escuro + folha, desenhados por trás do mar
var _mar: ColorRect                 # v0.7.2: o mar da carta pintado igual ao do minimapa (aquarela "mar")
var _contornos: Array = []          # por ilha: {ilha, costa, dentro, alto, raso, fundo}
var _mundo: Node = null
var _zoom: float = 1.0
var _mpp_base: float = 1.0
var _centro_carta: Vector2 = Vector2.ZERO
var _deslocamento: Vector2 = Vector2.ZERO
var _arrastando: bool = false
var _mouse_anterior: Vector2 = Vector2.ZERO
var _relogio: float = 0.0
var _grade_m: float = 100.0         # lado da casa da grade (m)
var _grade_origem: Vector2 = Vector2.ZERO   # canto noroeste (x mínimo, z mínimo) da grade
var _grade_n: Vector2i = Vector2i(20, 12)   # colunas, linhas

const PAPEL := Color(0.86, 0.81, 0.69)
const PAPEL_CLARO := Color(0.90, 0.86, 0.75)
const PAPEL_ESCURO := Color(0.74, 0.68, 0.55)
const MAR_PAPEL := Color(0.84, 0.80, 0.67)
const GRADE := Color(0.33, 0.53, 0.42)
const FAIXA := Color(0.40, 0.57, 0.46)
const TERRA := Color(0.58, 0.53, 0.43)
const TERRA_ALTA := Color(0.52, 0.47, 0.38)
const NANQUIM := Color(0.20, 0.17, 0.13)
const TINTA_SUAVE := Color(0.33, 0.29, 0.22)
const CONTORNO_MAR := Color(0.42, 0.50, 0.42, 0.55)
const LARGURA_FAIXA := 46.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	# camadas por trás do desenho da carta: 1) fundo escuro e a folha de papel; 2) o mar em aquarela, como no minimapa
	_fundo = Control.new()
	_fundo.show_behind_parent = true
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.draw.connect(_desenhar_fundo)
	add_child(_fundo)
	var esq: Dictionary = Aq.esquema("mar")
	var extra: Dictionary = (esq["extra"] as Dictionary).duplicate()
	extra["alfa"] = 1.0
	extra["irregular"] = 1.0
	extra["raio"] = 2.0
	extra["borda"] = 0.25
	extra["seco"] = 0.0
	extra["papel"] = 0.8          # numa área grande as manchas claras viravam camuflagem: aqui ficam só uma variação de tom
	_mar = ColorRect.new()
	_mar.show_behind_parent = true
	_mar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mar.material = Aq.material(esq["cor"], esq["cor2"], 7.3, extra)
	add_child(_mar)

func configurar(p_barco: Node3D, p_ilhas: Array) -> void:
	barco = p_barco
	ilhas = p_ilhas.duplicate()
	_contornos.clear()
	for ilha in ilhas:
		_contornos.append({"ilha": ilha, "costa": _contorno(ilha, 0.0), "dentro": _contorno(ilha, 1.6),
				"alto": _contorno(ilha, 9.0), "raso": _contorno(ilha, -2.5), "fundo": _contorno(ilha, -6.5)})
	_reconstruir()

func configurar_batimetria(mundo: Node) -> void:
	_mundo = mundo

func configurar_extras(pontos: Array) -> void:
	pontos_extras = pontos.duplicate(true)
	_reconstruir()

func distancia_ate_destino() -> float:
	if barco == null or not tem_marcador:
		return -1.0
	return Vector2(barco.global_position.x, barco.global_position.z).distance_to(marcador)

func alternar() -> bool:
	visible = not visible
	if visible:
		_reconstruir()
		_zoom = 1.8                                         # abre perto do barco; roda para trás mostra o mundo todo
		_deslocamento = Vector2.ZERO
		if barco != null:
			_deslocamento = Vector2(barco.global_position.x, barco.global_position.z) - _centro_carta
		_limitar()
		queue_redraw()
	return visible

func fechar() -> void:
	visible = false
	_arrastando = false

func aberto() -> bool:
	return visible

func _process(delta: float) -> void:
	if not visible:
		return
	_relogio += delta
	if _relogio > 0.12:
		_relogio = 0.0
		queue_redraw()

# ------------------------------------------------------------------ escala e grade

## Encaixa o mundo inteiro (ilhas, recifes e o barco) na área, com casas da grade de tamanho redondo.
func _reconstruir() -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for ilha in ilhas:
		var c := Vector2(ilha.centro.x, ilha.centro.z)
		var r: float = float(ilha.raio) * 1.35
		mn = mn.min(c - Vector2(r, r))
		mx = mx.max(c + Vector2(r, r))
	for ponto in pontos_extras:
		var pe: Vector2 = ponto.get("pos", Vector2.ZERO)
		var re: float = float(ponto.get("raio", 25.0)) + 30.0
		mn = mn.min(pe - Vector2(re, re))
		mx = mx.max(pe + Vector2(re, re))
	if mn.x == INF:
		mn = Vector2(-500, -500)
		mx = Vector2(500, 500)
	mn -= Vector2(140, 140)
	mx += Vector2(140, 140)
	var vao: float = maxf(mx.x - mn.x, mx.y - mn.y)
	_grade_m = 100.0
	for cand in [50.0, 100.0, 150.0, 200.0, 250.0, 500.0]:
		_grade_m = float(cand)
		if (mx.x - mn.x) / float(cand) <= 22.0:
			break
	_grade_origem = Vector2(floorf(mn.x / _grade_m) * _grade_m, floorf(mn.y / _grade_m) * _grade_m)
	var fim := Vector2(ceilf(mx.x / _grade_m) * _grade_m, ceilf(mx.y / _grade_m) * _grade_m)
	_grade_n = Vector2i(int(round((fim.x - _grade_origem.x) / _grade_m)), int(round((fim.y - _grade_origem.y) / _grade_m)))
	_centro_carta = (_grade_origem + fim) * 0.5
	var area: Rect2 = _quadro()
	_mpp_base = maxf((fim.x - _grade_origem.x) / maxf(area.size.x, 1.0), (fim.y - _grade_origem.y) / maxf(area.size.y, 1.0))
	_mpp_base = maxf(_mpp_base, 0.3)
	if vao <= 0.0:
		_mpp_base = 1.0
	# a grade cobre a carta inteira (não só o retângulo das ilhas): casas a mais nas bordas
	var meia: Vector2 = area.size * 0.5 * _mpp_base
	# casas de tamanho redondo, umas 19 na largura (como no DREDGE); a coluna A começa na borda esquerda da carta
	for cand2 in [100.0, 125.0, 150.0, 200.0, 250.0, 500.0]:
		_grade_m = float(cand2)
		if meia.x * 2.0 / float(cand2) <= 19.5:
			break
	_grade_origem = _centro_carta - meia
	var canto: Vector2 = _centro_carta + meia
	_grade_n = Vector2i(int(ceil((canto.x - _grade_origem.x) / _grade_m)), int(ceil((canto.y - _grade_origem.y) / _grade_m)))

## Onde a carta (o mar com a grade) fica na tela: a folha tem margem, faixa de números à esquerda e de letras embaixo.
func _folha() -> Rect2:
	var m := Vector2(maxf(30.0, size.x * 0.06), 26.0)
	return Rect2(m, size - m * 2.0 - Vector2(0, 56.0))

func _quadro() -> Rect2:
	var f: Rect2 = _folha()
	var dentro: Rect2 = f.grow(-30.0)
	dentro.position.y += 46.0                                # cabeçalho
	dentro.size.y -= 46.0
	return Rect2(dentro.position + Vector2(LARGURA_FAIXA, 0.0), dentro.size - Vector2(LARGURA_FAIXA, LARGURA_FAIXA))

func _metros_por_pixel() -> float:
	return _mpp_base / _zoom

func _posicao(p: Vector2, area: Rect2) -> Vector2:
	return area.get_center() + (p - _centro_carta - _deslocamento) / _metros_por_pixel()

func _mundo_do_pixel(pixel: Vector2, area: Rect2) -> Vector2:
	return _centro_carta + _deslocamento + (pixel - area.get_center()) * _metros_por_pixel()

## "A", "B" ... "Z", "AA"...
static func _letra(i: int) -> String:
	var s := ""
	var n := i
	while true:
		s = String.chr(65 + n % 26) + s
		n = n / 26 - 1
		if n < 0:
			break
	return s

## Casa da grade de um ponto do mundo: "J-8" (coluna letra, linha número, 1 embaixo).
func referencia(p: Vector2) -> String:
	var col: int = int(floor((p.x - _grade_origem.x) / _grade_m))
	var lin: int = _grade_n.y - int(floor((p.y - _grade_origem.y) / _grade_m))
	return "%s-%d" % [_letra(maxi(col, 0)), lin]

# ------------------------------------------------------------------ entrada

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var area: Rect2 = _quadro()
	if event is InputEventMouseButton:
		if (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and event.pressed:
			var antes: Vector2 = _mundo_do_pixel(event.position, area)
			_zoom = clampf(_zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 1.0, 8.0)
			var depois: Vector2 = _mundo_do_pixel(event.position, area)
			_deslocamento += antes - depois                     # o ponto sob o mouse fica parado
			_limitar()
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_arrastando = event.pressed
			_mouse_anterior = event.position
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
			_deslocamento = Vector2.ZERO
			_zoom = 1.0
			queue_redraw()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if area.has_point(event.position):
				if event.shift_pressed:
					tem_marcador = false
				else:
					marcador = _mundo_do_pixel(event.position, area)
					tem_marcador = true
				queue_redraw()
				accept_event()
	elif event is InputEventMouseMotion and _arrastando:
		_deslocamento -= (event.position - _mouse_anterior) * _metros_por_pixel()
		_mouse_anterior = event.position
		_limitar()
		queue_redraw()
		accept_event()

## Não deixa a carta sair da folha: com zoom 1 ela fica centrada; com zoom, só anda até a borda do mundo.
func _limitar() -> void:
	var meia_tela: Vector2 = _quadro().size * 0.5 * _metros_por_pixel()
	var meio_mundo := Vector2(_grade_n.x, _grade_n.y) * _grade_m * 0.5
	var folga: Vector2 = (meio_mundo - meia_tela).max(Vector2.ZERO)
	_deslocamento = _deslocamento.clamp(-folga, folga)

# ------------------------------------------------------------------ geometria

func _contorno(ilha: Node3D, nivel: float) -> PackedVector2Array:
	var resultado := PackedVector2Array()
	for k in 96:
		var angulo: float = TAU * float(k) / 96.0
		var dir: Vector2 = Vector2(cos(angulo), sin(angulo))
		var inicio: float = 0.0
		var fim: float = float(ilha.raio) * 1.8
		if float(ilha.altura_em(Vector3(ilha.centro.x, 0.0, ilha.centro.z))) <= nivel:
			resultado.append(Vector2(ilha.centro.x, ilha.centro.z))
			continue
		for j in 12:
			var meio: float = (inicio + fim) * 0.5
			var ponto: Vector3 = Vector3(ilha.centro.x + meio * dir.x, 0.0, ilha.centro.z + meio * dir.y)
			if float(ilha.altura_em(ponto)) > nivel:
				inicio = meio
			else:
				fim = meio
		resultado.append(Vector2(ilha.centro.x, ilha.centro.z) + dir * inicio)
	return resultado

func _na_tela(pontos: PackedVector2Array, area: Rect2) -> PackedVector2Array:
	var saida := PackedVector2Array()
	for p in pontos:
		saida.append(_posicao(p, area))
	return saida

func _fechar(pontos: PackedVector2Array) -> PackedVector2Array:
	var l := PackedVector2Array(pontos)
	if l.size() > 0:
		l.append(pontos[0])
	return l

## Polígono que não se cruza (contornos com pontos repetidos no centro dão erro na triangulação).
func _limpo(pontos: PackedVector2Array) -> PackedVector2Array:
	var saida := PackedVector2Array()
	for p in pontos:
		if saida.is_empty() or saida[saida.size() - 1].distance_to(p) > 0.6:
			saida.append(p)
	return saida

# ------------------------------------------------------------------ texto

func _escrever(t: String, p: Vector2, tam: int, cor: Color = NANQUIM, titulo: bool = false, contorno: bool = false) -> void:
	var f: Font = Aq.FONTE_TITULO if titulo else Aq.FONTE_TEXTO
	if contorno:
		draw_string_outline(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, 5, Color(PAPEL_CLARO, 0.9))
	draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)

## Escreve o texto no tamanho pedido, ou menor (até 11) se não couber na largura dada.
func _escrever_cabendo(t: String, p: Vector2, tam: int, cor: Color, largura: float) -> void:
	var f: Font = Aq.FONTE_TEXTO
	var t_tam: int = tam
	while t_tam > 11 and f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, t_tam).x > largura:
		t_tam -= 1
	_escrever(t, p, t_tam, cor)

func _centrar(t: String, c: Vector2, tam: int, cor: Color = NANQUIM, titulo: bool = false, contorno: bool = false) -> void:
	var f: Font = Aq.FONTE_TITULO if titulo else Aq.FONTE_TEXTO
	var larg: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
	_escrever(t, c - Vector2(larg * 0.5, -tam * 0.35), tam, cor, titulo, contorno)

# ------------------------------------------------------------------ desenho

func _draw() -> void:
	if not visible or size.x < 420.0 or size.y < 350.0:
		return
	var area: Rect2 = _quadro()
	var folha: Rect2 = _folha()
	_fundo.queue_redraw()
	Aq.ajustar(_mar, area, 0.0)
	_profundidades(area)
	_grade(area)
	for item in _contornos:
		_ilha(item, area)
	_pontos(area)
	_arquipelagos(area)
	for item in _contornos:
		_rotulo_ilha(item, area)
	_rota(area)
	_barco(area)
	_rosa(area.end - Vector2(62.0, 70.0))
	_margens(folha, area)
	_papel_detalhes(folha)
	_faixas(area)
	_cabecalho(folha)
	_rodape(folha, area)

func _desenhar_fundo() -> void:
	if not visible or size.x < 420.0 or size.y < 350.0:
		return
	_fundo.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.05, 0.07, 0.86), true)
	_papel_base(_folha())

## A folha: papel com borda levemente rasgada e manchas de umidade.
func _papel_base(f: Rect2) -> void:
	var borda := PackedVector2Array()
	var n := 64
	for k in n:
		var t: float = float(k) / float(n)
		borda.append(f.position + Vector2(f.size.x * t, sin(t * 47.0) * 1.6 + sin(t * 13.0) * 1.2))
	for k in n:
		var t: float = float(k) / float(n)
		borda.append(f.position + Vector2(f.size.x + sin(t * 31.0) * 1.5, f.size.y * t))
	for k in n:
		var t: float = float(k) / float(n)
		borda.append(f.end - Vector2(f.size.x * t, sin(t * 29.0) * 1.4))
	for k in n:
		var t: float = float(k) / float(n)
		borda.append(Vector2(f.position.x + sin(t * 41.0) * 1.8, f.end.y - f.size.y * t))
	_fundo.draw_colored_polygon(borda, PAPEL)
	# manchas largas e dobras (uma vertical e uma horizontal, como papel guardado dobrado)
	_fundo.draw_rect(Rect2(f.position + Vector2(f.size.x * 0.62, 0), Vector2(f.size.x * 0.38, f.size.y)), Color(PAPEL_ESCURO, 0.10), true)
	_fundo.draw_rect(Rect2(f.position + Vector2(0, f.size.y * 0.55), Vector2(f.size.x * 0.4, f.size.y * 0.45)), Color(PAPEL_ESCURO, 0.08), true)

## Por cima de tudo: as dobras do papel (passam sobre a carta), os cantos virados e a moldura (como no DREDGE).
func _papel_detalhes(f: Rect2) -> void:
	draw_rect(Rect2(f.position + Vector2(f.size.x * 0.5, 0), Vector2(f.size.x * 0.5, f.size.y)), Color(PAPEL_ESCURO, 0.06), true)
	draw_line(Vector2(f.get_center().x, f.position.y), Vector2(f.get_center().x, f.end.y), Color(PAPEL_ESCURO, 0.35), 2.0)
	draw_line(Vector2(f.get_center().x + 2.0, f.position.y), Vector2(f.get_center().x + 2.0, f.end.y), Color(PAPEL_CLARO, 0.5), 1.0)
	draw_line(Vector2(f.position.x, f.get_center().y), Vector2(f.end.x, f.get_center().y), Color(PAPEL_ESCURO, 0.30), 2.0)
	# cantos virados: triângulo claro (o verso do papel) com sombra
	var c := 26.0
	for canto in [[f.position, Vector2(1, 1)], [Vector2(f.end.x, f.position.y), Vector2(-1, 1)], [f.end, Vector2(-1, -1)], [Vector2(f.position.x, f.end.y), Vector2(1, -1)]]:
		var o: Vector2 = canto[0]
		var d: Vector2 = canto[1]
		draw_colored_polygon(PackedVector2Array([o, o + Vector2(d.x * c, 0), o + Vector2(0, d.y * c)]), Color(0.02, 0.05, 0.07, 1.0))
		draw_colored_polygon(PackedVector2Array([o + Vector2(d.x * c, 0), o + Vector2(0, d.y * c), o + Vector2(d.x * c, d.y * c) * 0.92]), PAPEL_CLARO)
		draw_line(o + Vector2(d.x * c, 0), o + Vector2(0, d.y * c), Color(PAPEL_ESCURO, 0.9), 1.5)
	# moldura dupla em volta da carta
	var moldura: Rect2 = _quadro().grow_individual(LARGURA_FAIXA + 8.0, 8.0, 8.0, LARGURA_FAIXA + 8.0)
	draw_rect(moldura, Color(NANQUIM, 0.85), false, 2.5)
	draw_rect(moldura.grow(5.0), Color(GRADE, 0.55), false, 1.5)

## Linhas de profundidade: duas curvas em volta de cada ilha, tracejadas e claras, como numa carta antiga.
func _profundidades(area: Rect2) -> void:
	for item in _contornos:
		for chave in ["fundo", "raso"]:
			var tela: PackedVector2Array = _na_tela(item[chave], area)
			if tela.size() < 3:
				continue
			draw_polyline(_fechar(tela), CONTORNO_MAR if chave == "raso" else Color(CONTORNO_MAR, 0.32), 1.6 if chave == "raso" else 1.2, true)

func _grade(area: Rect2) -> void:
	for i in _grade_n.x + 1:
		var x: float = _posicao(Vector2(_grade_origem.x + float(i) * _grade_m, 0.0), area).x
		if x >= area.position.x - 1.0 and x <= area.end.x + 1.0:
			draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), Color(GRADE, 0.75), 2.0)
	for j in _grade_n.y + 1:
		var y: float = _posicao(Vector2(0.0, _grade_origem.y + float(j) * _grade_m), area).y
		if y >= area.position.y - 1.0 and y <= area.end.y + 1.0:
			draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(GRADE, 0.75), 2.0)

func _ilha(item: Dictionary, area: Rect2) -> void:
	var costa: PackedVector2Array = _limpo(_na_tela(item["costa"], area))
	if costa.size() < 3:
		return
	# sombra de tinta deslocada (dá volume, como as ilhas do DREDGE)
	var sombra := PackedVector2Array()
	for p in costa:
		sombra.append(p + Vector2(2.0, 2.5))
	draw_colored_polygon(sombra, Color(NANQUIM, 0.22))
	draw_colored_polygon(costa, TERRA)
	var alto: PackedVector2Array = _limpo(_na_tela(item["alto"], area))
	if alto.size() >= 3:
		draw_colored_polygon(alto, TERRA_ALTA)
	draw_polyline(_fechar(costa), NANQUIM, 2.6, true)
	var dentro: PackedVector2Array = _limpo(_na_tela(item["dentro"], area))
	if dentro.size() >= 3:
		draw_polyline(_fechar(dentro), Color(PAPEL_CLARO, 0.85), 1.6, true)
	if alto.size() >= 3:
		draw_polyline(_fechar(alto), Color(NANQUIM, 0.30), 1.0, true)
	var ilha: Node3D = item["ilha"]
	if ilha.tem_cais:
		var cais: Vector2 = _posicao(Vector2(ilha.cais_ponta.x, ilha.cais_ponta.z), area)
		var raiz: Vector2 = _posicao(Vector2(ilha.cais_inicio.x, ilha.cais_inicio.z), area)
		draw_line(raiz, cais, NANQUIM, 2.5)
		draw_circle(cais, 6.5, PAPEL_CLARO)
		draw_circle(cais, 4.5, NANQUIM)
	# casinhas da vila: quadradinhos de tinta
	for c in ilha.mundo.get("casas", []):
		var pc: Vector2 = _posicao(Vector2(ilha.centro.x + float(c["x"]), ilha.centro.z + float(c["z"])), area)
		var lado_px: float = clampf(5.0 / _metros_por_pixel(), 2.0, 7.0)
		draw_rect(Rect2(pc - Vector2.ONE * lado_px * 0.5, Vector2.ONE * lado_px), Color(NANQUIM, 0.75), true)
	if ilha.tem_farol and ilha.pos_farol != Vector2.ZERO:
		var pf: Vector2 = _posicao(ilha.pos_farol, area)
		draw_colored_polygon(PackedVector2Array([pf + Vector2(0, -9), pf + Vector2(4, 4), pf + Vector2(-4, 4)]), Color(0.66, 0.20, 0.15))
		draw_polyline(PackedVector2Array([pf + Vector2(0, -9), pf + Vector2(4, 4), pf + Vector2(-4, 4), pf + Vector2(0, -9)]), NANQUIM, 1.2)

func _rotulo_ilha(item: Dictionary, area: Rect2) -> void:
	var ilha: Node3D = item["ilha"]
	var c := Vector2(ilha.centro.x, ilha.centro.z)
	var pequena: bool = float(ilha.raio) < 40.0
	if pequena and _zoom < 1.7:
		pass                                                   # ilhota sem nome de longe (como no DREDGE); aparece com zoom
	else:
		var tam: int = 26 if float(ilha.raio) > 80.0 else (21 if not pequena else 16)
		var abaixo: float = float(ilha.raio) * 1.15 / _metros_por_pixel() + float(tam) * 0.8
		var p: Vector2 = _posicao(c, area) + Vector2(0, abaixo)
		if area.grow(-8.0).has_point(p):
			_centrar(T.t(String(ilha.nome)), p, tam, NANQUIM, true, true)
	if ilha.tem_cais:
		var pc: Vector2 = _posicao(Vector2(ilha.cais_ponta.x, ilha.cais_ponta.z), area)
		if _zoom >= 1.6 and area.grow(-8.0).has_point(pc):
			_escrever(T.t("Cais"), pc + Vector2(9, -6), 15, TINTA_SUAVE, false, true)

## Nome do arquipélago em letras espaçadas e tinta clara, acima do grupo de ilhas (como os nomes de região do DREDGE).
func _arquipelagos(area: Rect2) -> void:
	var grupos: Dictionary = {}
	for ilha in ilhas:
		var a: String = str(ilha.arquipelago)
		if a == "":
			continue
		if not grupos.has(a):
			grupos[a] = [Vector2(INF, INF), Vector2(-INF, -INF)]
		var c := Vector2(ilha.centro.x, ilha.centro.z)
		grupos[a][0] = (grupos[a][0] as Vector2).min(c - Vector2.ONE * float(ilha.raio))
		grupos[a][1] = (grupos[a][1] as Vector2).max(c + Vector2.ONE * float(ilha.raio))
	for nome in grupos:
		var mn: Vector2 = grupos[nome][0]
		var mx: Vector2 = grupos[nome][1]
		var p: Vector2 = _posicao(Vector2((mn.x + mx.x) * 0.5, mn.y), area) - Vector2(0, 30.0)
		var texto: String = " ".join(T.t(nome).to_upper().split(""))
		if area.grow(-10.0).has_point(p):
			_centrar(texto, p, 22 if _zoom < 2.0 else 28, Color(0.30, 0.40, 0.36, 0.75), true, true)

func _pontos(area: Rect2) -> void:
	for item in pontos_extras:
		var c: Vector2 = item.get("pos", Vector2.ZERO)
		var p: Vector2 = _posicao(c, area)
		if not area.grow(-6.0).has_point(p):
			continue
		var raio_px: float = clampf(float(item.get("raio", 20.0)) / _metros_por_pixel(), 5.0, 60.0)
		var banco: bool = String(item.get("tipo", "recife")) == "banco"
		var cor: Color = Color(0.25, 0.42, 0.40, 0.85)
		var seg: int = 28
		for k in seg:                                            # círculo tracejado
			if k % 2 == 0:
				draw_arc(p, raio_px, TAU * float(k) / float(seg), TAU * float(k + 1) / float(seg), 3, cor, 1.6, true)
		if banco:
			for k2 in 3:                                         # banco de areia: pontinhos
				draw_circle(p + Vector2.from_angle(float(k2) * 2.1) * raio_px * 0.4, 1.8, cor)
		else:
			for k3 in 4:                                         # recife: cruzinhas
				var q: Vector2 = p + Vector2.from_angle(float(k3) * 1.57 + 0.4) * raio_px * 0.45
				draw_line(q - Vector2(3, 3), q + Vector2(3, 3), cor, 1.4)
				draw_line(q - Vector2(3, -3), q + Vector2(3, -3), cor, 1.4)
		_escrever(T.t(String(item.get("nome", ""))), p + Vector2(raio_px + 6.0, 5.0), 15, Color(0.20, 0.33, 0.31), false, true)

func _rota(area: Rect2) -> void:
	if not tem_marcador:
		return
	var destino: Vector2 = _posicao(marcador, area)
	if barco != null:
		var origem: Vector2 = _posicao(Vector2(barco.global_position.x, barco.global_position.z), area)
		draw_dashed_line(origem, destino, Color(0.62, 0.20, 0.13, 0.9), 2.2, 10.0, true)
	if area.grow(-6.0).has_point(destino):
		for s in [-1.0, 1.0]:
			draw_line(destino + Vector2(-8, -8 * s), destino + Vector2(8, 8 * s), Color(0.62, 0.20, 0.13), 3.5)
		_escrever(T.t("Destino") + "  " + referencia(marcador), destino + Vector2(12, -8), 16, Color(0.55, 0.18, 0.12), false, true)

func _barco(area: Rect2) -> void:
	if barco == null:
		return
	var p: Vector2 = _posicao(Vector2(barco.global_position.x, barco.global_position.z), area)
	if not area.grow(-6.0).has_point(p):
		return
	var f3: Vector3 = -barco.global_transform.basis.z
	var f: Vector2 = Vector2(f3.x, f3.z).normalized()
	var l: Vector2 = f.orthogonal()
	var pulso: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 3.0)
	draw_arc(p, 13.0 + 5.0 * pulso, 0.0, TAU, 32, Color(0.85, 0.32, 0.18, 0.55 * (1.0 - pulso) + 0.2), 2.0, true)
	var tri := PackedVector2Array([p + f * 12.0, p - f * 7.0 + l * 7.0, p - f * 3.0, p - f * 7.0 - l * 7.0])
	draw_colored_polygon(tri, Color(0.82, 0.28, 0.16))
	draw_polyline(_fechar(tri), NANQUIM, 1.6, true)
	_escrever("Estrela d'Alva", p + Vector2(15, -12), 15, NANQUIM, false, true)

func _rosa(c: Vector2) -> void:
	draw_circle(c, 40.0, Color(PAPEL_CLARO, 0.92))
	draw_arc(c, 40.0, 0.0, TAU, 48, NANQUIM, 1.6, true)
	draw_arc(c, 34.0, 0.0, TAU, 48, Color(NANQUIM, 0.5), 1.0, true)
	for k in 8:
		var a: float = TAU * float(k) / 8.0 - PI * 0.5
		var comp: float = 32.0 if k % 2 == 0 else 18.0
		var d := Vector2.from_angle(a)
		var o := d.orthogonal() * (6.0 if k % 2 == 0 else 4.0)
		var cor: Color = Color(0.66, 0.20, 0.15) if k == 0 else (NANQUIM if k % 2 == 0 else Color(NANQUIM, 0.6))
		draw_colored_polygon(PackedVector2Array([c + d * comp, c + o, c - o]), cor)
	draw_circle(c, 3.5, PAPEL_CLARO)
	_centrar("N", c + Vector2(0, -50), 18, NANQUIM, true, true)

## Cobre o que passou da carta (ilhas e linhas com zoom) com o papel: é o "recorte" da carta.
func _margens(f: Rect2, area: Rect2) -> void:
	var ext: Rect2 = f
	draw_rect(Rect2(ext.position, Vector2(ext.size.x, area.position.y - ext.position.y)), PAPEL, true)
	draw_rect(Rect2(Vector2(ext.position.x, area.end.y), Vector2(ext.size.x, ext.end.y - area.end.y)), PAPEL, true)
	draw_rect(Rect2(Vector2(ext.position.x, area.position.y), Vector2(area.position.x - ext.position.x, area.size.y)), PAPEL, true)
	draw_rect(Rect2(Vector2(area.end.x, area.position.y), Vector2(ext.end.x - area.end.x, area.size.y)), PAPEL, true)
	# fundo escuro de novo fora da folha
	var fora := Color(0.02, 0.05, 0.07, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, f.position.y - 2.0)), fora, true)
	draw_rect(Rect2(Vector2(0, f.end.y + 2.0), Vector2(size.x, size.y - f.end.y)), fora, true)
	draw_rect(Rect2(Vector2(0, 0), Vector2(f.position.x - 2.0, size.y)), fora, true)
	draw_rect(Rect2(Vector2(f.end.x + 2.0, 0), Vector2(size.x - f.end.x, size.y)), fora, true)
	draw_rect(area, Color(NANQUIM, 0.9), false, 2.0)

## Faixas verdes com os números das linhas (1 embaixo) e as letras das colunas, como no DREDGE.
func _faixas(area: Rect2) -> void:
	var esq := Rect2(Vector2(area.position.x - LARGURA_FAIXA, area.position.y), Vector2(LARGURA_FAIXA - 4.0, area.size.y))
	var baixo := Rect2(Vector2(area.position.x, area.end.y + 4.0), Vector2(area.size.x, LARGURA_FAIXA - 4.0))
	draw_rect(esq, FAIXA, true)
	draw_rect(baixo, FAIXA, true)
	for j in _grade_n.y:
		var y0: float = _posicao(Vector2(0, _grade_origem.y + float(j) * _grade_m), area).y
		var y1: float = _posicao(Vector2(0, _grade_origem.y + float(j + 1) * _grade_m), area).y
		var ym: float = (y0 + y1) * 0.5
		if ym > area.position.y + 6.0 and ym < area.end.y - 6.0:
			_centrar(str(_grade_n.y - j), Vector2(esq.get_center().x, ym), 22, Color(0.96, 0.93, 0.84), true)
	for i in _grade_n.x:
		var x0: float = _posicao(Vector2(_grade_origem.x + float(i) * _grade_m, 0), area).x
		var x1: float = _posicao(Vector2(_grade_origem.x + float(i + 1) * _grade_m, 0), area).x
		var xm: float = (x0 + x1) * 0.5
		if xm > area.position.x + 6.0 and xm < area.end.x - 6.0:
			_centrar(_letra(i), Vector2(xm, baixo.get_center().y), 22, Color(0.96, 0.93, 0.84), true)

func _cabecalho(f: Rect2) -> void:
	_escrever(T.t("Carta náutica"), f.position + Vector2(40, 58), 38, NANQUIM, true)
	_escrever(T.t("Arquipélagos de São Paulo e São Pedro"), f.position + Vector2(300, 54), 18, TINTA_SUAVE)
	# legenda à direita do cabeçalho: o espaçamento segue a largura de cada texto (inglês e chinês não cabem no passo do português)
	var itens: Array = [["cais", T.t("Cais")], ["farol", T.t("Farol")], ["recife", T.t("Recife / banco")], ["casa", T.t("Casas")], ["voce", T.t("Você")]]
	var fonte: Font = Aq.FONTE_TEXTO
	var total: float = 0.0
	for it in itens:
		total += 20.0 + fonte.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20.0
	var x: float = f.end.x - 56.0 - total + 20.0
	var y: float = f.position.y + 50.0
	for it in itens:
		match String(it[0]):
			"cais":
				draw_circle(Vector2(x + 5, y - 6), 5.0, PAPEL_CLARO)
				draw_circle(Vector2(x + 5, y - 6), 3.5, NANQUIM)
			"farol":
				draw_colored_polygon(PackedVector2Array([Vector2(x + 5, y - 13), Vector2(x + 9, y), Vector2(x + 1, y)]), Color(0.66, 0.20, 0.15))
			"recife":
				draw_arc(Vector2(x + 6, y - 6), 6.0, 0.0, TAU, 12, Color(0.25, 0.42, 0.40), 1.5)
			"casa":
				draw_rect(Rect2(Vector2(x + 2, y - 10), Vector2(6, 6)), NANQUIM, true)
			"voce":
				draw_colored_polygon(PackedVector2Array([Vector2(x + 12, y - 6), Vector2(x, y - 1), Vector2(x, y - 11)]), Color(0.82, 0.28, 0.16))
		_escrever(String(it[1]), Vector2(x + 20, y), 16, TINTA_SUAVE)
		x += 20.0 + fonte.get_string_size(String(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 20.0

func _rodape(f: Rect2, area: Rect2) -> void:
	var y: float = f.end.y + 34.0
	var cor := Color(0.93, 0.90, 0.80)
	if barco != null:
		var p := Vector2(barco.global_position.x, barco.global_position.z)
		var texto: String = T.t("Posição %s   ·   E %+d m   N %+d m   ·   rumo %03d°") % [referencia(p), roundi(p.x), roundi(-p.y), int(barco.rumo())]
		_escrever(texto, Vector2(f.position.x + 6.0, y), 19, cor)
	# escala (calculada antes: o texto de ajuda encolhe para não bater nela)
	var metros: float = _grade_m
	var px: float = metros / _metros_por_pixel()
	var base := Vector2(f.end.x - 20.0 - px, y - 6.0)
	var d: float = distancia_ate_destino()
	var x_ajuda: float = f.position.x + 470.0
	var largura_ajuda: float = base.x - 18.0 - x_ajuda
	if d >= 0.0:
		_escrever_cabendo(T.t("Destino a %d m (linha reta)") % roundi(d), Vector2(x_ajuda, y), 19, Color(0.98, 0.72, 0.55), largura_ajuda)
	else:
		_escrever_cabendo(T.t("M fecha · roda: zoom · botão direito: arrastar · clique: destino · Shift+clique: limpa"), Vector2(x_ajuda, y), 17, Color(0.75, 0.80, 0.78), largura_ajuda)
	draw_line(base, base + Vector2(px, 0), cor, 3.0)
	draw_line(base + Vector2(0, -6), base + Vector2(0, 6), cor, 2.0)
	draw_line(base + Vector2(px, -6), base + Vector2(px, 6), cor, 2.0)
	_centrar(T.t("casa da grade: %d m") % int(metros), base + Vector2(px * 0.5, -14.0), 16, cor)
