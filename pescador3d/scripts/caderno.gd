extends Control
## v0.8.4: Livro do Pescador (TAB; P abre direto nos peixes). Junta o antigo diário de bordo e o caderno de peixes:
##   MANUAL  - como pescar, iscas e anzol, quem come o quê, técnica e linha, jeitos de lutar, qualidade e dicas do mar;
##   PEIXES  - uma espécie por página, por zona (agora com a isca e o anzol que cada uma prefere);
##   DIÁRIO  - as páginas do Bento e o diário de bordo (as últimas mensagens da viagem).
## v0.7.0: Caderno de Peixes, no espírito da enciclopédia do DREDGE: um caderno aberto, uma espécie por página.
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
const MARCA_MANUAL := {"id": "manual", "nome": "Manual", "cor": Color(0.55, 0.20, 0.13)}
const MARCA_DIARIO := {"id": "diario", "nome": "Diário", "cor": Color(0.22, 0.22, 0.34)}

## Páginas do manual: título + parágrafos ("-" no começo vira um tópico). "anel", "tabela" e "lutas" são desenhos especiais.
const MANUAL := [
	{"titulo": "Como pescar", "extra": "anel", "texto": [
		"- Ache um cardume no radar e chegue devagar: acima de 2 nós o peixe foge.",
		"- F lança a linha. Um ponteiro gira no anel: aperte F quando ele passar por uma faixa verde. O miolo dourado vale o dobro.",
		"- Apertar fora da faixa solta linha e trava o anzol por um instante.",
		"- Sem acertar nada o peixe vem sozinho, só que bem devagar.",
		"- Acelerou o barco ou o cardume foi embora: peixe perdido."]},
	{"titulo": "Iscas e anzol", "texto": [
		"- B troca a isca. A Comum é de graça e não acaba. Camarão e Lula vêm no kit do cais (R$ 25: 6 camarões e 3 lulas); cada lance gasta uma.",
		"- N muda o anzol: Superfície, Meia-água ou Fundo.",
		"- Isca que o peixe gosta: +24%. As faixas verdes ficam mais largas e ele sobe mais depressa.",
		"- Cada camada de anzol errada: -18%.",
		"- Só com a isca certa, no anzol certo e sem esticar a linha sai peixe Excepcional.",
		"- A lista de quem come o quê está na página ao lado, e cada peixe repete a dele na sua página."]},
	{"titulo": "Quem come o quê", "extra": "tabela", "texto": []},
	{"titulo": "Técnica e linha", "texto": [
		"- J troca a técnica. Suave: estica pouco a linha, mas puxa menos. Equilibrada: o meio-termo. Firme: cada acerto puxa 22% a mais, só que a linha sofre.",
		"- Cada acerto estica a linha (a tensão). Passou do limite, ela arrebenta e o peixe vai embora. Um apito avisa quando está perto.",
		"- A linha se gasta a cada luta e o limite cai. Reforçar no cais (U) aumenta o limite e zera o desgaste.",
		"- Peixe pesado puxa a tensão para cima sozinho: use a técnica Suave."]},
	{"titulo": "Jeitos de lutar", "extra": "lutas", "texto": []},
	{"titulo": "Qualidade e dicas do mar", "texto": [
		"- Qualidade: Excepcional vale 28% a mais, Boa 12% a mais, Regular o preço da tabela.",
		"- Sardinha, barracuda e peixe-voador só aparecem de dia; olho-de-cão e moreia só de noite. A garoupa sai mais à noite.",
		"- O posto da Ilha das Rocas paga 30% a mais pelo peixe. Em São Pedro, a cioba vale mais.",
		"- Encomenda cumprida na venda rende o bônus junto.",
		"- No radar, o peixe da missão pisca em dourado.",
		"- O peixe-lua só sobe nas noites de bruma."]},
	{"titulo": "A noite e a bruma", "extra": "noite", "texto": [
		"- A lamparina ao lado do relógio mostra o medo. Ele sobe de noite longe da terra, mais na bruma e perto dos vultos; desce com luz, perto da terra, no farol e ao amanhecer.",
		"- Lanterna acesa (L) segura o medo pela metade, mas gasta óleo. Vela na capela vale por uma noite; o patuá da Dona Rosa, para sempre. O sino (G) espanta os vultos.",
		"- Se ouvir um canto vindo da água, segure o leme: ele puxa sozinho.",
		"- Medo demais: batidas no casco, motor que engasga, peixe que some. No fim, você apaga e acorda longe.",
		"- O que sobe de noite às vezes não é peixe direito. Só um homem compra, de madrugada, no cais da Vila do Porto."]},
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
var pagina: int = 0                 # índice da folha da esquerda (sempre par)
var diario: Array = []              # mensagens da viagem (scripts/interface.gd)
var _folhas: Array = []             # o livro inteiro: {"tipo": "manual"|"peixe"|"bento"|"diario"|"branco", "i": int}
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
	for k in MANUAL.size():
		_folhas.append({"tipo": "manual", "i": k})
	if _folhas.size() % 2 == 1:
		_folhas.append({"tipo": "branco", "i": 0})
	for k in FICHAS.size():
		_folhas.append({"tipo": "peixe", "i": k})
	if _folhas.size() % 2 == 1:
		_folhas.append({"tipo": "colecao", "i": 0})
	_folhas.append({"tipo": "diario", "i": 0})
	_folhas.append({"tipo": "bento", "i": 0})
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
	return int(ceil(_folhas.size() / 2.0))

func virar(passo: int) -> void:
	pagina = clampi(pagina + passo * 2, 0, (paginas() - 1) * 2)
	queue_redraw()

func _primeira(tipo: String, i := -1) -> int:
	for k in _folhas.size():
		if _folhas[k].tipo == tipo and (i < 0 or int(_folhas[k].i) == i):
			return k
	return 0

## "manual", "diario" ou o id de uma zona de peixes.
func ir_para_zona(id_zona: String) -> void:
	var k := 0
	if id_zona == "manual":
		k = 0
	elif id_zona == "diario":
		k = _primeira("diario")
	else:
		for i in FICHAS.size():
			if FICHAS[i][1] == id_zona:
				k = _primeira("peixe", i)
				break
	pagina = k - (k % 2)
	queue_redraw()

func ir_para_especie(especie: String) -> void:
	for i in FICHAS.size():
		if FICHAS[i][0] == especie:
			var k := _primeira("peixe", i)
			pagina = k - (k % 2)
			break
	queue_redraw()

## A seção da folha (para a marca acesa e para W/S).
func _secao(k: int) -> String:
	var f: Dictionary = _folhas[clampi(k, 0, _folhas.size() - 1)]
	match String(f.tipo):
		"manual": return "manual"
		"peixe": return String(FICHAS[int(f.i)][1])
		"diario", "bento": return "diario"
		"colecao": return "bruma"
	return "manual" if k < _primeira("peixe") else "diario"

func _marcas() -> Array:
	var lista: Array = [MARCA_MANUAL]
	lista.append_array(ZONAS)
	lista.append(MARCA_DIARIO)
	return lista

func _process(delta: float) -> void:
	if visible:
		_rel += delta
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:                      # v0.7.4: seta dourada sobre o que dá para clicar
		var p: Vector2 = event.position
		var clicavel: bool = (_seta_esq.has_point(p) and pagina > 0) or (_seta_dir.has_point(p) and pagina + 2 < _folhas.size()) or _fechar_ret.has_point(p)
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
							ir_para_zona(String(z[1]))
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
			KEY_P, KEY_ESCAPE, KEY_TAB: fechar()
			_: return
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT: virar(-1)
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT: virar(1)
			JOY_BUTTON_DPAD_UP: _zona_vizinha(-1)
			JOY_BUTTON_DPAD_DOWN: _zona_vizinha(1)
			JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_BACK: fechar()
			_: return
		get_viewport().set_input_as_handled()

func _zona_vizinha(passo: int) -> void:
	var lista := _marcas()
	var atual: String = _secao(pagina)
	var iz := 0
	for i in lista.size():
		if lista[i].id == atual:
			iz = i
	ir_para_zona(String(lista[clampi(iz + passo, 0, lista.size() - 1)].id))

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
	_rotulo(Rect2(topo + Vector2(30.0 * esc, -26.0 * esc), Vector2(250.0 * esc, 44.0 * esc)), T.t("Livro do Pescador"), CAPA.lightened(0.15), 26, esc, true)
	var info := T.t("Página %d/%d") % [pagina / 2 + 1, paginas()] + "     " + T.t("Peixes descobertos: %d/%d") % [descobertos(), FICHAS.size()]
	_rotulo(Rect2(topo + Vector2(300.0 * esc, -26.0 * esc), Vector2(440.0 * esc, 44.0 * esc)), info, Color(0.08, 0.08, 0.10, 0.92), 22, esc, false)
	_fechar_ret = Rect2(Vector2(livro.end.x - 34.0 * esc, livro.position.y - 60.0 * esc), Vector2(44.0 * esc, 44.0 * esc))
	draw_circle(_fechar_ret.get_center(), 20.0 * esc, Color(0.08, 0.08, 0.10, 0.9))
	var cx: Vector2 = _fechar_ret.get_center()
	draw_line(cx + Vector2(-7, -7) * esc, cx + Vector2(7, 7) * esc, Aq.CREME, 3.0 * esc)
	draw_line(cx + Vector2(7, -7) * esc, cx + Vector2(-7, 7) * esc, Aq.CREME, 3.0 * esc)
	# marcas à esquerda: manual, as zonas dos peixes e o diário
	_zonas_ret.clear()
	var secao_atual: String = _secao(pagina)
	var marcas := _marcas()
	for i in marcas.size():
		var z: Dictionary = marcas[i]
		var largura_marca: float = 150.0 * esc
		var r := Rect2(Vector2(livro.position.x - 14.0 * esc - largura_marca, livro.position.y + 18.0 * esc + i * 52.0 * esc), Vector2(largura_marca, 44.0 * esc))
		if z.id == secao_atual:
			r = r.grow_side(SIDE_LEFT, 14.0 * esc)
		draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), Vector2(r.position.x + 10.0 * esc, r.get_center().y)]), Color(z.cor).darkened(0.0 if z.id == secao_atual else 0.25))
		_centrar(T.t(String(z.nome)).to_upper(), r.get_center() + Vector2(4.0 * esc, 8.0 * esc), 20, Aq.CREME, esc, true)
		_zonas_ret.append([r, z.id])
	# as duas folhas
	_folha(esq.grow(-22.0 * esc), pagina, esc)
	if pagina + 1 < _folhas.size():
		_folha(dir.grow(-22.0 * esc), pagina + 1, esc)
	# setas de virar
	_seta_esq = Rect2(Vector2(livro.position.x + 6.0 * esc, livro.end.y - 50.0 * esc), Vector2(44.0 * esc, 40.0 * esc))
	_seta_dir = Rect2(Vector2(livro.end.x - 50.0 * esc, livro.end.y - 50.0 * esc), Vector2(44.0 * esc, 40.0 * esc))
	if pagina > 0:
		_seta(_seta_esq, -1.0, esc)
	if pagina + 2 < _folhas.size():
		_seta(_seta_dir, 1.0, esc)
	_centrar(T.t("A/D: virar página  ·  W/S: seção  ·  TAB ou ESC: fechar"), Vector2(esq.get_center().x, livro.end.y - 16.0 * esc), 16, Color(TINTA_SUAVE, 0.9), esc, false)

func _folha(r: Rect2, k: int, esc: float) -> void:
	var f: Dictionary = _folhas[k]
	match String(f.tipo):
		"manual": _pagina_manual(r, int(f.i), esc)
		"peixe": _pagina(r, int(f.i), esc)
		"bento": _pagina_bento(r, esc)
		"diario": _pagina_diario(r, int(f.i), esc)
		"colecao": _pagina_colecao(r, esc)

const QUEBRA := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY

## Escreve um parágrafo e devolve a altura usada.
func _paragrafo(t: String, p: Vector2, largura: float, tam: int, cor: Color, esc: float) -> float:
	var px: int = int(tam * esc)
	var h: float = Aq.FONTE_TEXTO.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, largura, px, -1, QUEBRA).y
	draw_multiline_string(Aq.FONTE_TEXTO, p, t, HORIZONTAL_ALIGNMENT_LEFT, largura, px, -1, cor, QUEBRA)
	return h

func _titulo_pagina(r: Rect2, titulo: String, esc: float, sub: String = "") -> float:
	_centrar(titulo, Vector2(r.get_center().x, r.position.y + 30.0 * esc), 32, TINTA, esc, true)
	var lt: float = Aq.FONTE_TITULO.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, int(32 * esc)).x
	draw_line(Vector2(r.get_center().x - lt / 2.0, r.position.y + 40.0 * esc), Vector2(r.get_center().x + lt / 2.0, r.position.y + 40.0 * esc), Color(TINTA, 0.7), 2.0)
	if sub != "":
		_centrar(sub, Vector2(r.get_center().x, r.position.y + 64.0 * esc), 17, TINTA_SUAVE, esc, false)
		return r.position.y + 92.0 * esc
	return r.position.y + 74.0 * esc

func _pagina_manual(r: Rect2, k: int, esc: float) -> void:
	var m: Dictionary = MANUAL[k]
	var y: float = _titulo_pagina(r, T.t(String(m.titulo)), esc)
	var extra: String = String(m.get("extra", ""))
	if extra == "anel":
		y = _desenho_anel(Vector2(r.get_center().x, y + 62.0 * esc), esc) + 18.0 * esc
	for linha in m.texto:
		var t: String = T.t(String(linha))
		var topico: bool = t.begins_with("- ")
		var x: float = r.position.x + (18.0 * esc if topico else 0.0)
		if topico:
			t = t.substr(2)
			draw_circle(Vector2(r.position.x + 6.0 * esc, y - 6.0 * esc), 3.0 * esc, Color(CAPA, 0.85))
		y += _paragrafo(t, Vector2(x, y), r.end.x - x, 18, TINTA, esc) + 9.0 * esc
	if extra == "tabela":
		_tabela_iscas(r, y, esc)
	elif extra == "lutas":
		_tabela_lutas(r, y, esc)
	elif extra == "noite":
		_vinheta_noite(r, y, esc)

## O anel do minijogo, desenhado no papel: faixa verde, miolo dourado e o ponteiro.
func _desenho_anel(c: Vector2, esc: float) -> float:
	var raio: float = 52.0 * esc
	draw_arc(c, raio, 0.0, TAU, 64, Color(TINTA, 0.55), 7.0 * esc, true)
	for faixa in [[-0.9, 0.62], [1.5, 0.5], [3.4, 0.55]]:
		var a0: float = float(faixa[0]) - float(faixa[1]) / 2.0
		draw_arc(c, raio, a0, a0 + float(faixa[1]), 16, Color(0.30, 0.66, 0.36), 9.0 * esc, true)
		var d: float = float(faixa[1]) * 0.3
		draw_arc(c, raio, float(faixa[0]) - d / 2.0, float(faixa[0]) + d / 2.0, 8, Color(0.90, 0.68, 0.20), 9.0 * esc, true)
	var ang: float = -0.95 + sin(_rel * 1.3) * 0.25
	draw_line(c, c + Vector2.from_angle(ang) * (raio + 10.0 * esc), CAPA, 3.0 * esc, true)
	draw_circle(c, 5.0 * esc, CAPA)
	_escrever(T.t("faixa verde"), c + Vector2(raio + 18.0 * esc, -24.0 * esc), 15, Color(0.22, 0.48, 0.26), esc, false)
	_escrever(T.t("miolo dourado: vale o dobro"), c + Vector2(raio + 18.0 * esc, -4.0 * esc), 15, Color(0.62, 0.44, 0.10), esc, false)
	_escrever(T.t("ponteiro"), c + Vector2(-raio - 92.0 * esc, -30.0 * esc), 15, TINTA_SUAVE, esc, false)
	return c.y + raio + 10.0 * esc

const COR_ISCA := [Color(0.40, 0.36, 0.30), Color(0.80, 0.38, 0.24), Color(0.42, 0.30, 0.62)]

## Duas colunas: quem prefere camarão e quem prefere lula, com o anzol de cada um.
func _tabela_iscas(r: Rect2, y: float, esc: float) -> void:
	var meio: float = r.position.x + r.size.x / 2.0
	for col in 2:
		var isca: int = col + 1
		var x: float = r.position.x + (0.0 if col == 0 else r.size.x / 2.0 + 10.0 * esc)
		var cab := Rect2(Vector2(x, y), Vector2(r.size.x / 2.0 - 10.0 * esc, 34.0 * esc))
		draw_rect(cab, COR_ISCA[isca])
		_centrar(T.t(String(Pesca.ISCAS[isca])).to_upper(), cab.get_center() + Vector2(0, 8.0 * esc), 22, Aq.CREME, esc, true)
		var yy: float = cab.end.y + 24.0 * esc
		for f in FICHAS:
			var perfil: Dictionary = Pesca.PERFIL.get(String(f[0]), {})
			if int(perfil.get("isca", 0)) != isca:
				continue
			_escrever(T.t(String(f[0])), Vector2(x + 6.0 * esc, yy), 18, TINTA, esc, false)
			var prof: String = T.t(String(Pesca.PROFUNDIDADES[int(perfil.get("prof", 1))])).to_lower()
			var lp: float = Aq.FONTE_TEXTO.get_string_size(prof, HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * esc)).x
			_escrever(prof, Vector2(cab.end.x - lp - 4.0 * esc, yy), 15, TINTA_SUAVE, esc, false)
			yy += 27.0 * esc
	draw_line(Vector2(meio, y + 40.0 * esc), Vector2(meio, r.end.y - 30.0 * esc), Color(TINTA, 0.15), 1.5)

## v0.8.7: os quatro amparos da noite, pintados, numa fileira no pé da página.
var _icones_noite: Array = []
func _vinheta_noite(r: Rect2, y: float, esc: float) -> void:
	if _icones_noite.is_empty():
		for n in ["oleo", "vela", "patua", "sino"]:
			var arq := "res://assets/texturas/bruma/icone_%s.png" % n
			if ResourceLoader.exists(arq):
				_icones_noite.append(load(arq))
	var alt: float = 64.0 * esc
	var x: float = r.get_center().x - (_icones_noite.size() * 70.0 * esc) * 0.5
	for t in _icones_noite:
		var tex: Texture2D = t
		var larg: float = alt * float(tex.get_width()) / float(tex.get_height())
		draw_texture_rect(tex, Rect2(Vector2(x + (60.0 * esc - larg) * 0.5, minf(y + 6.0 * esc, r.end.y - alt - 30.0 * esc)), Vector2(larg, alt)), false)
		x += 70.0 * esc

## Os sete jeitos de lutar, com a cor do anel de cada um.
func _tabela_lutas(r: Rect2, y: float, esc: float) -> void:
	for id in ["bando", "corredor", "pesado", "arisco", "escorregadio", "saltador", "colosso"]:
		var info: Dictionary = Pesca.INFO_COMPORTAMENTO[id]
		draw_circle(Vector2(r.position.x + 10.0 * esc, y - 6.0 * esc), 8.0 * esc, info.cor)
		draw_arc(Vector2(r.position.x + 10.0 * esc, y - 6.0 * esc), 8.0 * esc, 0.0, TAU, 16, Color(TINTA, 0.5), 1.5, true)
		var t: String = T.t(String(info.dica))
		y += _paragrafo(t, Vector2(r.position.x + 28.0 * esc, y), r.size.x - 28.0 * esc, 17, TINTA, esc) + 10.0 * esc

## Diário de bordo: as mensagens da viagem, a mais nova primeiro. Folha 0 = as mais novas; folha 1 = as anteriores.
func _pagina_diario(r: Rect2, lado: int, esc: float) -> void:
	var y: float
	if lado == 0:
		y = _titulo_pagina(r, T.t("Diário de bordo"), esc, T.t("O que aconteceu na viagem, do mais novo ao mais antigo.")) + 14.0 * esc
	else:
		y = r.position.y + 26.0 * esc
	var lista: Array = diario.duplicate()
	lista.reverse()
	if lista.is_empty():
		if lado == 0:
			_centrar(T.t("Nada anotado ainda."), Vector2(r.get_center().x, y + 30.0 * esc), 18, TINTA_SUAVE, esc, false)
		return
	# a folha da direita continua de onde a da esquerda parou
	var inicio := 0
	if lado == 1:
		inicio = _cabem_no_diario(r, lista, r.position.y + 92.0 * esc, esc)
	for k in range(inicio, lista.size()):
		var t: String = String(lista[k])
		var h: float = Aq.FONTE_TEXTO.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0 * esc, int(17 * esc), -1, QUEBRA).y
		if y + h > r.end.y - 30.0 * esc:
			break
		draw_circle(Vector2(r.position.x + 5.0 * esc, y - 6.0 * esc), 2.5 * esc, Color(TINTA, 0.5 if k > 0 else 0.9))
		_paragrafo(t, Vector2(r.position.x + 16.0 * esc, y), r.size.x - 20.0 * esc, 17, TINTA if k < 3 else TINTA_SUAVE, esc)
		y += h + 8.0 * esc

## Depois do último peixe: a coleção inteira numa folha (quantos, recorde), "???" para o que falta pescar.
func _pagina_colecao(r: Rect2, esc: float) -> void:
	var y: float = _titulo_pagina(r, T.t("Sua coleção"), esc, T.t("Peixes descobertos: %d/%d") % [descobertos(), FICHAS.size()])
	var x_n: float = r.position.x + r.size.x * 0.58
	var x_r: float = r.position.x + r.size.x * 0.78
	_escrever(T.t("Pescados"), Vector2(x_n, y), 14, TINTA_SUAVE, esc, false)
	_escrever(T.t("Recorde"), Vector2(x_r, y), 14, TINTA_SUAVE, esc, false)
	y += 22.0 * esc
	for f in FICHAS:
		var d: Dictionary = colecao.get(String(f[0]), {})
		var n: int = int(d.get("n", 0))
		var cor := TINTA if n > 0 else Color(TINTA, 0.35)
		draw_rect(Rect2(Vector2(r.position.x, y - 12.0 * esc), Vector2(8.0 * esc, 8.0 * esc)), Color(_zona(String(f[1])).cor, 0.9 if n > 0 else 0.3))
		_escrever(T.t(String(f[0])) if n > 0 else "???", Vector2(r.position.x + 16.0 * esc, y), 17, cor, esc, false)
		if n > 0:
			_escrever(str(n), Vector2(x_n, y), 17, cor, esc, false)
			_escrever(("%.1f" % float(d.get("maior", 0.0))).replace(".", ",") + " kg", Vector2(x_r, y), 17, cor, esc, false)
		y += 21.5 * esc

func _cabem_no_diario(r: Rect2, lista: Array, y: float, esc: float) -> int:
	var n := 0
	for t in lista:
		var h: float = Aq.FONTE_TEXTO.get_multiline_string_size(String(t), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0 * esc, int(17 * esc), -1, QUEBRA).y
		if y + h > r.end.y - 30.0 * esc:
			break
		y += h + 8.0 * esc
		n += 1
	return n

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
	var quadro := Rect2(r.position + Vector2(0, 56.0 * esc), Vector2(r.size.x, 166.0 * esc))
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
	# v0.8.4: a isca e o anzol que a espécie prefere (o que todo pescador do cais sabe, mesmo antes da primeira)
	y += 34.0 * esc
	var perfil: Dictionary = Pesca.PERFIL.get(nome, {"prof": 1, "isca": 0})
	var isca: int = int(perfil.isca)
	_escrever(T.t("Isca"), Vector2(x0, y), 16, TINTA_SUAVE, esc, false)
	var nome_isca: String = T.t(String(Pesca.ISCAS[isca]))
	var li: float = Aq.FONTE_TITULO.get_string_size(nome_isca, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * esc)).x
	draw_rect(Rect2(Vector2(x0 + 88.0 * esc, y - 20.0 * esc), Vector2(li + 12.0 * esc, 26.0 * esc)), Color(COR_ISCA[isca], 0.85))
	_escrever(nome_isca, Vector2(x0 + 94.0 * esc, y), 20, Aq.CREME, esc, true)
	_escrever(T.t("Anzol"), Vector2(x1, y), 16, TINTA_SUAVE, esc, false)
	_escrever(T.t(String(Pesca.PROFUNDIDADES[int(perfil.prof)])), Vector2(x1 + 70.0 * esc, y), 20, TINTA, esc, true)

## A última folha: as páginas molhadas do diário do Bento, coladas no caderno conforme aparecem na bruma.
func _pagina_bento(r: Rect2, esc: float) -> void:
	if paginas_bento <= 0:
		_titulo_pagina(r, T.t("Páginas soltas"), esc)
		_centrar(T.t("Nada colado aqui... ainda."), r.get_center(), 20, TINTA_SUAVE, esc, false)
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
