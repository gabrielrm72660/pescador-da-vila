extends Control
## v0.7.0: Caderno de Peixes (tecla P), no espírito da enciclopédia do DREDGE: um caderno aberto, uma espécie por página.
## Antes da primeira captura a espécie aparece só como silhueta, com a zona e o horário como pista; depois de pescada
## ganha nome, desenho, descrição, preço, recorde de peso e quantas já foram pescadas.
## Virar página: A/D, setas, Q/E, roda do mouse, as setas na tela ou, no controle, o direcional e LB/RB.
## As marcas à esquerda pulam para a zona. P, ESC ou B (controle) fecham.

const Aq = preload("res://scripts/aquarela.gd")
const T = preload("res://scripts/idioma.gd")
const Cardumes = preload("res://scripts/cardumes.gd")
const Pesca = preload("res://scripts/pesca.gd")
const Historia = preload("res://scripts/historia.gd")

signal fechou

const ZONAS := [
	{"id": "costa", "nome": "Costa", "cor": Color(0.30, 0.42, 0.66), "onde": "Águas rasas perto das praias e das baías."},
	{"id": "recife", "nome": "Recife", "cor": Color(0.62, 0.30, 0.36), "onde": "Pedras e recifes perto da costa."},
	{"id": "aberto", "nome": "Mar aberto", "cor": Color(0.18, 0.50, 0.52), "onde": "Mar aberto, longe da arrebentação, e nos bancos de areia."},
	{"id": "alto", "nome": "Alto-mar", "cor": Color(0.12, 0.30, 0.50), "onde": "Alto-mar, a mais de 300 m da terra."},
	{"id": "sao_pedro", "nome": "São Pedro", "cor": Color(0.70, 0.46, 0.16), "onde": "Só em volta do arquipélago de São Pedro."},
	{"id": "bruma", "nome": "Bruma", "cor": Color(0.42, 0.44, 0.52), "onde": "Alto-mar, só nas noites de bruma."},
]

## ordem das páginas: zona por zona
const FICHAS := [
	["Sardinha", "costa", "Pequena e prateada, nada em cardumes enormes perto da praia. Isca de muita gente e almoço de outro tanto."],
	["Tainha", "costa", "Resistente, vive em águas rasas de areia e lama e aguenta até água salobra. Pula fora d'água quando se assusta."],
	["Robalo", "costa", "Desconfiado, ronda as pedras e a boca das baías. Dá trabalho para fisgar e é disputado na feira."],
	["Baiacu", "costa", "Infla como uma bola quando ameaçado. Melhor não comer sem saber limpar: é venenoso."],
	["Garoupa", "recife", "Pesada e paciente, mora em tocas nas pedras do recife. Quando puxa, puxa para o fundo."],
	["Olho-de-cão", "recife", "Vermelho e de olhos enormes, só sai das locas do recife depois que escurece."],
	["Budião", "recife", "Tem bico de papagaio e rói o coral; boa parte da areia branca das praias já passou por ele."],
	["Peixe-anjo", "recife", "Azul e amarelo como um vitral. Raro, arisco e caro: os aquários pagam bem."],
	["Moreia", "recife", "Comprida e escorregadia, espreita das frestas do recife à noite. Morde quem mete a mão."],
	["Namorado", "recife", "Peixe de fundo, de carne branca e firme. Vive no cascalho perto das pedras."],
	["Cavala", "aberto", "Rápida e listrada, caça sardinha em mar aberto. Briga com força e corre de repente."],
	["Barracuda", "aberto", "Dentes à mostra e arrancadas curtas. Gosta de água clara e só caça de dia."],
	["Xaréu", "aberto", "Musculoso, anda em bando e ronda os bancos de areia. Puxa a linha em zigue-zague."],
	["Arabaiana", "aberto", "Parente grande do xaréu, cruza o mar aberto em grupos pequenos. Cansa o braço de qualquer um."],
	["Peixe-voador", "aberto", "Abre as nadadeiras como asas e plana dezenas de metros sobre as ondas para fugir dos predadores."],
	["Dourado", "alto", "Verde e ouro quando sai da água, perde a cor em minutos. Segue troncos e destroços no alto-mar."],
	["Atum", "alto", "Nadador incansável do alto-mar. O mais valioso do cais, e o que mais rompe linha."],
	["Agulhão-vela", "alto", "O mais rápido do oceano. Ergue a vela e salta fora d'água para se livrar do anzol."],
	["Cioba", "sao_pedro", "Vermelha e de carne nobre, vive nas pedras de São Pedro. No cais de lá pagam mais por ela."],
	["Olho-de-boi", "sao_pedro", "Grande e forte, com uma faixa escura no olho. Ronda as águas fundas em volta de São Pedro."],
	["Peixe-lua", "bruma", "O maior peixe ósseo do mar. Só sobe à superfície nas noites de bruma, e ninguém sabe dizer por quê."],
]

var colecao: Dictionary = {}        # especie -> {"n": int, "maior": float}  (vem de scripts/jogo.gd)
var paginas_bento: int = 0          # páginas do diário do Bento já achadas (scripts/historia.gd)
var pagina: int = 0                 # índice da página da esquerda (sempre par)
var _texturas: Dictionary = {}
var _rel: float = 0.0
var _zonas_ret: Array = []          # [Rect2, índice da primeira ficha]
var _seta_esq: Rect2
var _seta_dir: Rect2
var _fechar_ret: Rect2

const PAPEL := Color(0.93, 0.88, 0.76)
const PAPEL_SOMBRA := Color(0.80, 0.74, 0.60)
const CAPA := Color(0.30, 0.17, 0.11)
const TINTA := Color(0.16, 0.13, 0.10)
const TINTA_SUAVE := Color(0.36, 0.31, 0.25)
const OURO := Color(0.90, 0.68, 0.26)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	for f in FICHAS:
		var arq := "res://assets/texturas/peixes/porao/%s.png" % Cardumes.slug(String(f[0]))
		if ResourceLoader.exists(arq):
			_texturas[f[0]] = load(arq)

func aberto() -> bool:
	return visible

func abrir() -> void:
	visible = true
	queue_redraw()

func fechar() -> void:
	if visible:
		visible = false
		fechou.emit()

func alternar() -> bool:
	if visible:
		fechar()
	else:
		abrir()
	return visible

func descobertos() -> int:
	var n := 0
	for f in FICHAS:
		if int(colecao.get(f[0], {}).get("n", 0)) > 0:
			n += 1
	return n

func paginas() -> int:
	return int(ceil(FICHAS.size() / 2.0))

func virar(passo: int) -> void:
	pagina = clampi(pagina + passo * 2, 0, (paginas() - 1) * 2)
	queue_redraw()

func ir_para_zona(id_zona: String) -> void:
	for i in FICHAS.size():
		if FICHAS[i][1] == id_zona:
			pagina = i - (i % 2)
			break
	queue_redraw()

func ir_para_especie(especie: String) -> void:
	for i in FICHAS.size():
		if FICHAS[i][0] == especie:
			pagina = i - (i % 2)
			break
	queue_redraw()

func _process(delta: float) -> void:
	if visible:
		_rel += delta
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:                      # v0.7.4: seta dourada sobre o que dá para clicar
		var p: Vector2 = event.position
		var clicavel: bool = (_seta_esq.has_point(p) and pagina > 0) or (_seta_dir.has_point(p) and pagina + 2 < FICHAS.size()) or _fechar_ret.has_point(p)
		for z in _zonas_ret:
			clicavel = clicavel or Rect2(z[0]).has_point(p)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clicavel else Control.CURSOR_ARROW
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: virar(-1)
			MOUSE_BUTTON_WHEEL_DOWN: virar(1)
			MOUSE_BUTTON_LEFT:
				var p: Vector2 = event.position
				if _seta_esq.has_point(p): virar(-1)
				elif _seta_dir.has_point(p): virar(1)
				elif _fechar_ret.has_point(p): fechar()
				else:
					for z in _zonas_ret:
						if Rect2(z[0]).has_point(p):
							pagina = int(z[1]) - int(z[1]) % 2
							break
		accept_event()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_A, KEY_LEFT, KEY_Q, KEY_B: virar(-1)
			KEY_D, KEY_RIGHT, KEY_E, KEY_N: virar(1)
			KEY_W, KEY_UP: _zona_vizinha(-1)
			KEY_S, KEY_DOWN: _zona_vizinha(1)
			KEY_P, KEY_ESCAPE: fechar()
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT: virar(-1)
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT: virar(1)
			JOY_BUTTON_DPAD_UP: _zona_vizinha(-1)
			JOY_BUTTON_DPAD_DOWN: _zona_vizinha(1)
			JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_START: fechar()
			_: return
		get_viewport().set_input_as_handled()

func _zona_vizinha(passo: int) -> void:
	var atual: String = FICHAS[pagina][1]
	var iz := 0
	for i in ZONAS.size():
		if ZONAS[i].id == atual:
			iz = i
	ir_para_zona(String(ZONAS[clampi(iz + passo, 0, ZONAS.size() - 1)].id))

func _zona(id: String) -> Dictionary:
	for z in ZONAS:
		if z.id == id:
			return z
	return ZONAS[0]

# ------------------------------------------------------------------ desenho

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.07, 0.72))
	var esc: float = minf(size.x / 1280.0, size.y / 720.0)
	var larg: float = 1080.0 * esc
	var alt: float = 600.0 * esc
	var livro := Rect2(size.x / 2.0 - larg / 2.0 + 40.0 * esc, size.y / 2.0 - alt / 2.0 + 22.0 * esc, larg, alt)
	# capa e as duas folhas
	draw_rect(livro.grow(14.0 * esc), CAPA)
	draw_rect(livro.grow(14.0 * esc), Color(0.0, 0.0, 0.0, 0.35), false, 3.0)
	var meio: float = livro.position.x + livro.size.x / 2.0
	var esq := Rect2(livro.position, Vector2(livro.size.x / 2.0 - 4.0 * esc, livro.size.y))
	var dir := Rect2(Vector2(meio + 4.0 * esc, livro.position.y), Vector2(livro.size.x / 2.0 - 4.0 * esc, livro.size.y))
	for folha in [esq, dir]:
		draw_rect(folha, PAPEL)
		for k in 5:                                         # papel velho: as bordas um pouco mais escuras
			draw_rect(folha.grow(-k * 3.0 * esc), Color(PAPEL_SOMBRA, 0.16 - k * 0.03), false, 3.0 * esc)
	for k in 10:                                            # sombra da dobra
		var a: float = 0.22 * (1.0 - k / 10.0)
		draw_line(Vector2(meio - k * 2.0 * esc, livro.position.y), Vector2(meio - k * 2.0 * esc, livro.end.y), Color(0, 0, 0, a), 2.0 * esc)
		draw_line(Vector2(meio + k * 2.0 * esc, livro.position.y), Vector2(meio + k * 2.0 * esc, livro.end.y), Color(0, 0, 0, a), 2.0 * esc)
	# cabeçalho
	var topo := Vector2(livro.position.x, livro.position.y - 34.0 * esc)
	_rotulo(Rect2(topo + Vector2(30.0 * esc, -26.0 * esc), Vector2(250.0 * esc, 44.0 * esc)), T.t("Caderno de peixes"), CAPA.lightened(0.15), 26, esc, true)
	var info := T.t("Página %d/%d") % [pagina / 2 + 1, paginas()] + "     " + T.t("Descobertos: %d/%d") % [descobertos(), FICHAS.size()]
	_rotulo(Rect2(topo + Vector2(300.0 * esc, -26.0 * esc), Vector2(440.0 * esc, 44.0 * esc)), info, Color(0.08, 0.08, 0.10, 0.92), 22, esc, false)
	_fechar_ret = Rect2(Vector2(livro.end.x - 34.0 * esc, livro.position.y - 60.0 * esc), Vector2(44.0 * esc, 44.0 * esc))
	draw_circle(_fechar_ret.get_center(), 20.0 * esc, Color(0.08, 0.08, 0.10, 0.9))
	var cx: Vector2 = _fechar_ret.get_center()
	draw_line(cx + Vector2(-7, -7) * esc, cx + Vector2(7, 7) * esc, Aq.CREME, 3.0 * esc)
	draw_line(cx + Vector2(7, -7) * esc, cx + Vector2(-7, 7) * esc, Aq.CREME, 3.0 * esc)
	# marcas das zonas, à esquerda
	_zonas_ret.clear()
	var zona_atual: String = FICHAS[pagina][1]
	for i in ZONAS.size():
		var z: Dictionary = ZONAS[i]
		var largura_marca: float = 150.0 * esc
		var r := Rect2(Vector2(livro.position.x - 14.0 * esc - largura_marca, livro.position.y + 30.0 * esc + i * 54.0 * esc), Vector2(largura_marca, 44.0 * esc))
		if z.id == zona_atual:
			r = r.grow_side(SIDE_LEFT, 14.0 * esc)
		draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x + 10.0 * esc, r.get_center().y)]), Color(z.cor).darkened(0.0 if z.id == zona_atual else 0.25))
		_centrar(T.t(String(z.nome)).to_upper(), r.get_center() + Vector2(4.0 * esc, 8.0 * esc), 20, Aq.CREME, esc, true)
		var primeira := 0
		for k in FICHAS.size():
			if FICHAS[k][1] == z.id:
				primeira = k
				break
		_zonas_ret.append([r, primeira])
	# as duas páginas
	_pagina(esq.grow(-22.0 * esc), pagina, esc)
	if pagina + 1 < FICHAS.size():
		_pagina(dir.grow(-22.0 * esc), pagina + 1, esc)
	else:
		_pagina_bento(dir.grow(-22.0 * esc), esc)
	# setas de virar
	_seta_esq = Rect2(Vector2(livro.position.x + 6.0 * esc, livro.end.y - 50.0 * esc), Vector2(44.0 * esc, 40.0 * esc))
	_seta_dir = Rect2(Vector2(livro.end.x - 50.0 * esc, livro.end.y - 50.0 * esc), Vector2(44.0 * esc, 40.0 * esc))
	if pagina > 0:
		_seta(_seta_esq, -1.0, esc)
	if pagina + 2 < FICHAS.size():
		_seta(_seta_dir, 1.0, esc)
	_centrar(T.t("A/D: virar página  ·  W/S: zona  ·  P ou ESC: fechar"), Vector2(esq.get_center().x, livro.end.y - 16.0 * esc), 16, Color(TINTA_SUAVE, 0.9), esc, false)

func _pagina(r: Rect2, i: int, esc: float) -> void:
	var nome: String = FICHAS[i][0]
	var z: Dictionary = _zona(FICHAS[i][1])
	var dados: Dictionary = colecao.get(nome, {})
	var n: int = int(dados.get("n", 0))
	var conhecido: bool = n > 0
	var titulo: String = ("#%d  " % (i + 1)) + (T.t(nome) if conhecido else "???")
	_centrar(titulo, Vector2(r.get_center().x, r.position.y + 30.0 * esc), 32, TINTA, esc, true)
	var lt: float = Aq.FONTE_TITULO.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * esc)).x
	draw_line(Vector2(r.get_center().x - lt / 2.0, r.position.y + 40.0 * esc), Vector2(r.get_center().x + lt / 2.0, r.position.y + 40.0 * esc), Color(TINTA, 0.7), 2.0)
	# moldura do desenho
	var quadro := Rect2(r.position + Vector2(0, 56.0 * esc), Vector2(r.size.x, 190.0 * esc))
	draw_rect(quadro, Color(PAPEL_SOMBRA, 0.45))
	draw_rect(quadro, Color(TINTA, 0.25), false, 1.5)
	var tex: Texture2D = _texturas.get(nome)
	if tex != null:
		var caixa := quadro.grow(-16.0 * esc)
		var k: float = minf(caixa.size.x / tex.get_width(), caixa.size.y / tex.get_height())
		var tam := Vector2(tex.get_width(), tex.get_height()) * k
		var pos := caixa.get_center() - tam / 2.0
		if conhecido:
			draw_texture_rect(tex, Rect2(pos, tam), false)
		else:
			draw_texture_rect(tex, Rect2(pos + Vector2(4, 5) * esc, tam), false, Color(0, 0, 0, 0.18))
			draw_texture_rect(tex, Rect2(pos, tam), false, Color(0.14, 0.12, 0.10, 0.92))
	# faixa da zona + contagem
	var faixa := Rect2(Vector2(r.position.x, quadro.end.y + 12.0 * esc), Vector2(r.size.x, 40.0 * esc))
	draw_rect(Rect2(faixa.position, Vector2(faixa.size.x * 0.5, faixa.size.y)), z.cor)
	_centrar(T.t(String(z.nome)).to_upper(), Vector2(faixa.position.x + faixa.size.x * 0.25, faixa.get_center().y + 9.0 * esc), 24, Aq.CREME, esc, true)
	var cont := ("• " + T.t("Pescados: %d") % n) if conhecido else ("• " + T.t("Ainda não pescado"))
	_centrar(cont, Vector2(faixa.position.x + faixa.size.x * 0.75, faixa.get_center().y + 8.0 * esc), 21, TINTA, esc, true)
	# descrição
	var desc_r := Rect2(Vector2(r.position.x, faixa.end.y), Vector2(r.size.x, 66.0 * esc))
	draw_rect(desc_r, Color(z.cor).darkened(0.15))
	var desc: String = T.t(String(FICHAS[i][2])) if conhecido else T.t("Pesque um destes para descobrir mais.")
	draw_multiline_string(Aq.FONTE_TEXTO, desc_r.position + Vector2(12.0 * esc, 24.0 * esc), desc, HORIZONTAL_ALIGNMENT_LEFT, desc_r.size.x - 24.0 * esc, int(18 * esc), 3, Aq.CREME, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY)
	# fichas: onde, horário, preço, recorde, luta
	var y: float = desc_r.end.y + 26.0 * esc
	var x0: float = r.position.x + 4.0 * esc
	var x1: float = r.position.x + r.size.x * 0.52
	_linha(Vector2(x0, y), T.t("Onde"), T.t(String(z.onde)), esc, r.size.x - 8.0 * esc)
	y += 46.0 * esc
	var esp: Dictionary = Cardumes.ESPECIES.get(nome, {})
	var dia: bool = not esp.get("so_noite", false)
	var noite: bool = not esp.get("so_dia", false)
	_escrever(T.t("Horário"), Vector2(x0, y), 16, TINTA_SUAVE, esc, false)
	_sol(Vector2(x0 + 92.0 * esc, y - 6.0 * esc), esc, dia)
	_lua(Vector2(x0 + 128.0 * esc, y - 6.0 * esc), esc, noite)
	_escrever(T.t("Preço"), Vector2(x1, y), 16, TINTA_SUAVE, esc, false)
	_escrever(("R$ %d/kg" % int(esp.get("preco", 0))) if conhecido else "?", Vector2(x1 + 70.0 * esc, y), 20, TINTA, esc, true)
	y += 34.0 * esc
	_escrever(T.t("Recorde"), Vector2(x0, y), 16, TINTA_SUAVE, esc, false)
	_escrever((("%.1f" % float(dados.get("maior", 0.0))).replace(".", ",") + " kg") if conhecido else "?", Vector2(x0 + 92.0 * esc, y), 20, TINTA, esc, true)
	_escrever(T.t("Luta"), Vector2(x1, y), 16, TINTA_SUAVE, esc, false)
	var comp: String = String(Pesca.COMPORTAMENTO.get(nome, "bando"))
	_escrever(T.t(String(Pesca.INFO_COMPORTAMENTO[comp].nome)) if conhecido else "?", Vector2(x1 + 70.0 * esc, y), 20, TINTA, esc, true)

## A última folha: as páginas molhadas do diário do Bento, coladas no caderno conforme aparecem na bruma.
func _pagina_bento(r: Rect2, esc: float) -> void:
	if paginas_bento <= 0:
		_centrar(T.t("Fim do caderno."), r.get_center(), 22, TINTA_SUAVE, esc, false)
		return
	_centrar(T.t("Diário do Bento"), Vector2(r.get_center().x, r.position.y + 30.0 * esc), 32, TINTA, esc, true)
	_centrar(T.t("Páginas achadas: %d de %d") % [paginas_bento, Historia.PAGINAS.size()], Vector2(r.get_center().x, r.position.y + 62.0 * esc), 18, TINTA_SUAVE, esc, false)
	var y: float = r.position.y + 96.0 * esc
	var quebra := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY
	for k in Historia.PAGINAS.size():
		var t: String = ("%d.  " % (k + 1)) + (T.t(String(Historia.PAGINAS[k])) if k < paginas_bento else "· · ·")
		var tam: int = int(16 * esc)
		var h: float = Aq.FONTE_TEXTO.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, tam, -1, quebra).y
		draw_multiline_string(Aq.FONTE_TEXTO, Vector2(r.position.x, y), t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x, tam, -1, Color(0.20, 0.22, 0.36) if k < paginas_bento else Color(TINTA, 0.35), quebra)
		y += h + 10.0 * esc

func _linha(p: Vector2, rotulo: String, valor: String, esc: float, largura: float) -> void:
	_escrever(rotulo, p, 16, TINTA_SUAVE, esc, false)
	draw_multiline_string(Aq.FONTE_TEXTO, p + Vector2(92.0 * esc, 0), valor, HORIZONTAL_ALIGNMENT_LEFT, largura - 92.0 * esc, int(18 * esc), 2, TINTA, TextServer.BREAK_WORD_BOUND)

func _sol(c: Vector2, esc: float, aceso: bool) -> void:
	var cor := Color(0.86, 0.55, 0.12) if aceso else Color(TINTA, 0.2)
	draw_circle(c, 7.0 * esc, cor)
	for k in 8:
		var a := TAU * k / 8.0
		draw_line(c + Vector2.from_angle(a) * 10.0 * esc, c + Vector2.from_angle(a) * 14.0 * esc, cor, 2.0)

func _lua(c: Vector2, esc: float, aceso: bool) -> void:
	var cor := Color(0.24, 0.30, 0.52) if aceso else Color(TINTA, 0.2)
	draw_circle(c, 10.0 * esc, cor)
	draw_circle(c + Vector2(5.0, -3.0) * esc, 8.5 * esc, PAPEL)

func _seta(r: Rect2, sentido: float, esc: float) -> void:
	var c := r.get_center()
	var pulso: float = 1.0 + 0.08 * sin(_rel * 4.0)
	draw_colored_polygon(PackedVector2Array([c + Vector2(16.0 * sentido, 0) * esc * pulso, c + Vector2(-10.0 * sentido, -14.0) * esc * pulso, c + Vector2(-10.0 * sentido, 14.0) * esc * pulso]), CAPA)

func _rotulo(r: Rect2, texto: String, cor: Color, tam: int, esc: float, titulo: bool) -> void:
	draw_rect(r, cor)
	_centrar(texto, r.get_center() + Vector2(0, tam * esc * 0.34), tam, Aq.CREME, esc, titulo)

func _escrever(t: String, p: Vector2, tam: int, cor: Color, esc: float, titulo: bool) -> void:
	draw_string(Aq.FONTE_TITULO if titulo else Aq.FONTE_TEXTO, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam * esc), cor)

func _centrar(t: String, c: Vector2, tam: int, cor: Color, esc: float, titulo: bool) -> void:
	var f: Font = Aq.FONTE_TITULO if titulo else Aq.FONTE_TEXTO
	var l: float = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam * esc)).x
	draw_string(f, Vector2(c.x - l / 2.0, c.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(tam * esc), cor)
