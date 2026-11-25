extends CanvasLayer
## v0.8.7: painel do desenvolvedor (F8). Para testar sem esperar: teletransporte, hora e clima, barco, o horror da
## noite (medo, canto da Mãe-d'água, coisa de baixo, vultos), peixes, fauna, missões, a história do Bento e os
## cartões finais. Nada aqui é salvo à parte: o que muda no jogo é salvo como sempre.
## (A baleia de teste, que antes ficava no F8, agora é o botão "Baleia".)

var jogo: Node
var _caixa: PanelContainer
var _status: Label
var _relogio: float = 0.0

func construir(jogo_: Node) -> void:
	jogo = jogo_
	name = "PainelDev"
	layer = 70
	visible = false
	_caixa = PanelContainer.new()
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.03, 0.06, 0.09, 0.90)
	fundo.border_color = Color(0.45, 0.85, 0.72, 0.8)
	fundo.set_border_width_all(2)
	fundo.set_corner_radius_all(8)
	fundo.content_margin_left = 12
	fundo.content_margin_right = 12
	fundo.content_margin_top = 10
	fundo.content_margin_bottom = 10
	_caixa.add_theme_stylebox_override("panel", fundo)
	_caixa.position = Vector2(12, 12)
	_caixa.custom_minimum_size = Vector2(470, 0)
	add_child(_caixa)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_caixa.add_child(col)
	var topo := HBoxContainer.new()
	var tit := Label.new()
	tit.text = "PAINEL DO DESENVOLVEDOR  ( ; )"
	tit.add_theme_color_override("font_color", Color(0.55, 1.0, 0.85))
	tit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(tit)
	var fechar := Button.new()
	fechar.text = "×"
	fechar.pressed.connect(alternar)
	topo.add_child(fechar)
	col.add_child(topo)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(0.85, 0.88, 0.9))
	col.add_child(_status)
	var rolagem := ScrollContainer.new()
	rolagem.custom_minimum_size = Vector2(0, 560)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(rolagem)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 4)
	rolagem.add_child(lista)
	_montar(lista)

func aberto() -> bool:
	return visible

func alternar() -> void:
	visible = not visible

func _secao(lista: VBoxContainer, titulo: String) -> GridContainer:
	var l := Label.new()
	l.text = titulo
	l.add_theme_color_override("font_color", Color(0.98, 0.76, 0.33))
	lista.add_child(l)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	lista.add_child(g)
	return g

func _botao(g: GridContainer, texto: String, acao: Callable) -> void:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(146, 30)
	b.add_theme_font_size_override("font_size", 13)
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	b.pressed.connect(func():
		acao.call()
		jogo.atualizar_interface())
	g.add_child(b)

func _aviso(t: String) -> void:
	jogo.interface.aviso("[DEV] " + t)

# ------------------------------------------------------------------ os botões

func _montar(lista: VBoxContainer) -> void:
	var g := _secao(lista, "Teletransporte")
	for il in jogo.ilhas:
		var ilha_alvo = il
		_botao(g, "→ " + String(il.nome), func(): _ir_para_ilha(ilha_alvo))
	_botao(g, "→ Sino do Bento", func(): _ir(Vector3(-1680.0, 0.0, 160.0), "o sino do Bento (a oeste de São Pedro)"))
	_botao(g, "→ Marcador da carta", _ir_marcador)
	_botao(g, "→ Mar aberto (+500 m)", func():
		var b: Vector3 = jogo.barco.global_position
		var fora: Vector3 = (b - jogo.ilha.centro)
		fora.y = 0.0
		_ir(b + fora.normalized() * 500.0, "mar aberto"))

	g = _secao(lista, "Hora e clima")
	for h in [6.0, 12.0, 18.0, 22.0, 2.0]:
		var hora: float = h
		_botao(g, "%02d:00" % int(hora), func(): _hora(hora))
	_botao(g, "+1 hora", func(): jogo.clima.avancar(1.0))
	_botao(g, "Noite de bruma", _noite_de_bruma)
	_botao(g, "Clima: próximo", func(): _aviso("Clima: " + String(jogo.clima.alternar_clima())))
	_botao(g, "Clima: automático", func(): jogo.clima.definir_clima(0))
	_botao(g, "Tempestade", func(): _aviso(String(jogo.oceano.testar_tempestade())))
	_botao(g, "Mar: próximo", func(): _aviso("Mar: " + String(jogo.oceano.alternar_estado())))

	g = _secao(lista, "Barco")
	_botao(g, "+ R$ 1000", func(): jogo.dinheiro += 1000)
	_botao(g, "Tanque cheio", func(): jogo.barco.combustivel = jogo.barco.tanque)
	_botao(g, "Casco 100%", func(): jogo.barco.saude = 100.0)
	_botao(g, "Casco 20%", func(): jogo.barco.saude = 20.0)
	_botao(g, "Óleo cheio", func(): jogo.assombro.oleo = 1.0)
	_botao(g, "Esvaziar porão", func(): jogo.porao.esvaziar_peixes())
	_botao(g, "Melhorias no máximo", _melhorias_max)
	_botao(g, "Atracar aqui", func(): jogo.atracar())
	_botao(g, "Salvar agora", func(): jogo.salvar(); _aviso("salvo"))

	g = _secao(lista, "Horror da noite")
	for v in [0.0, 0.3, 0.5, 0.7, 0.95]:
		var valor: float = v
		_botao(g, "Medo %d%%" % roundi(valor * 100.0), func(): jogo.assombro.valor = valor)
	_botao(g, "Desmaio (100%)", func(): jogo.assombro.valor = 1.0)
	_botao(g, "Canto da Mãe-d'água", func(): jogo.assombro._prox["canto"] = 0.0; jogo.assombro.valor = maxf(jogo.assombro.valor, 0.5))
	_botao(g, "Coisa de baixo", func(): jogo.assombro._prox["coisa"] = 0.0; jogo.assombro.valor = maxf(jogo.assombro.valor, 0.65))
	_botao(g, "Batida no casco", func(): jogo.assombro._prox["batida"] = 0.0; jogo.assombro.valor = maxf(jogo.assombro.valor, 0.45))
	_botao(g, "Lanterna falha", func(): jogo.assombro.luz_falhando = 3.0)
	_botao(g, "Vulto", func(): jogo.fantasmas._nascer_vulto())
	_botao(g, "Miragem no radar", func(): jogo.fantasmas._nascer_miragem())
	_botao(g, "Dar sino e patuá", func(): jogo.assombro.sino = true; jogo.assombro.patua = true)
	_botao(g, "Vela acesa", func(): jogo.assombro.vela = true)

	g = _secao(lista, "Peixes e fauna")
	_botao(g, "Peixe aleatório", func(): _peixe(false))
	_botao(g, "Peixe aberrante", func(): _peixe(true))
	_botao(g, "Todos no livro", _livro_completo)
	_botao(g, "Baleia", func():
		if jogo.baleias != null:
			_aviso(String(jogo.baleias.testar_avistamento())))
	_botao(g, "Golfinhos", _golfinhos)
	_botao(g, "Cardumes de novo", func(): jogo.cardumes.semear())

	g = _secao(lista, "Missões e história")
	_botao(g, "Cumprir missão", _cumprir_missao)
	_botao(g, "Página do diário", _pagina_diario)
	_botao(g, "Encontro com o Bento", _encontro_bento)
	_botao(g, "Cartão: a luz", func(): jogo.historia._cartao("A LUZ DO FAROL", "(prévia do cartão final \"luz\" — nada mudou na viagem)", "Fechar", func(): pass))
	_botao(g, "Cartão: o sino", func(): jogo.historia._cartao("O SINO", "(prévia do cartão final \"bruma\" — nada mudou na viagem)", "Fechar", func(): pass))
	_botao(g, "Diagnóstico (F4)", func(): jogo._diagnostico_navegacao())

# ------------------------------------------------------------------ ações

func _ir(p: Vector3, nome: String) -> void:
	if jogo.atracado:
		jogo.zarpar()
	var b: Node3D = jogo.barco
	b.global_position = Vector3(p.x, b.global_position.y, p.z)
	b.velocidade = 0.0
	if jogo.fantasmas != null:
		jogo.fantasmas.limpar()
	_aviso("teletransporte: " + nome)

func _ir_para_ilha(il: Node3D) -> void:
	var cais: Vector3 = il.cais_ponta if "cais_ponta" in il else il.centro
	var fora: Vector3 = (cais - il.centro)
	fora.y = 0.0
	if fora.length() < 1.0:
		fora = Vector3(1, 0, 0)
	var p: Vector3 = cais + fora.normalized() * 28.0
	if not bool(il.get("tem_cais")):
		p = il.centro + fora.normalized() * (float(il.raio) + 70.0)
	_ir(p, String(il.nome))
	var b: Node3D = jogo.barco
	b.look_at(Vector3(cais.x, b.global_position.y, cais.z))

func _ir_marcador() -> void:
	var mapa = jogo.interface.mapa
	if not mapa.tem_marcador:
		_aviso("nenhum destino marcado na carta (M)")
		return
	_ir(Vector3(mapa.marcador.x, 0.0, mapa.marcador.y), "marcador da carta")

func _hora(h: float) -> void:
	var c: Node = jogo.clima
	var faltam: float = fposmod(h - float(c.hora), 24.0)
	if faltam > 0.01:
		c.avancar(faltam)
	if c.has_method("pular_transicoes"):
		c.pular_transicoes()

func _noite_de_bruma() -> void:
	var c: Node = jogo.clima
	_hora(22.0)
	while not c.noite_de_bruma():
		c.dias += 1
	c.definir_clima(0)
	if c.has_method("pular_transicoes"):
		c.pular_transicoes()
	_aviso("noite de bruma (dia %d)" % int(c.dias))

func _melhorias_max() -> void:
	var m: Node = jogo.melhorias
	m.motor_30_liberado = true
	for id in m.ORDEM:
		while not m.no_maximo(id):
			m.subir(id)
	m.aplicar(jogo.barco, jogo.porao, jogo.pesca, jogo.interface.hud)

func _peixe(aberrante: bool) -> void:
	var especies: Array = jogo.cardumes.ESPECIES.keys()
	var e: String = especies[randi() % especies.size()]
	var faixa: Array = jogo.cardumes.ESPECIES[e].peso
	var peso: float = snappedf(randf_range(float(faixa[0]), float(faixa[1])), 0.1)
	if aberrante:
		if jogo.porao.guardar(e, peso, "Aberrante"):
			_aviso("aberrante: " + e)
		else:
			_aviso("porão cheio")
	else:
		jogo._ao_pescar(e, peso)

func _livro_completo() -> void:
	for e in jogo.cardumes.ESPECIES:
		if not jogo.colecao.has(e):
			jogo.colecao[e] = {"n": 1, "maior": float(jogo.cardumes.ESPECIES[e].peso[1])}
	jogo.interface.caderno.colecao = jogo.colecao

func _golfinhos() -> void:
	var fc: Node = jogo.fauna_costeira
	var g: Node = fc.get("_golfinhos") if fc != null else null
	if g == null:
		return
	g._presente = false
	g._relogio = 0.0
	_aviso("golfinhos chegando (perto do barco, em mar aberto)")

func _cumprir_missao() -> void:
	var ms: Node = jogo.missoes
	if ms.terminou():
		_aviso("não há mais missões")
		return
	var m: Dictionary = ms.atual()
	ms.fim_pendentes.append(ms.indice)
	ms.indice += 1
	ms.progresso = 0
	ms.cumprida.emit(m)

func _pagina_diario() -> void:
	var h: Node = jogo.historia
	if h.paginas >= h.PAGINAS.size():
		_aviso("todas as páginas já achadas")
		return
	h.paginas += 1
	jogo.interface.caderno.paginas_bento = h.paginas
	_aviso("página %d do diário do Bento (livro, TAB > Diário)" % h.paginas)

func _encontro_bento() -> void:
	var ms: Node = jogo.missoes
	for i in ms.LISTA.size():
		if String(ms.LISTA[i].tipo) == "sino":
			ms.indice = i
			ms.progresso = 0
			ms.oferecidas[i] = true
			break
	jogo.historia.final = ""
	_noite_de_bruma()
	jogo.clima.bruma = 1.0
	_ir(Vector3(-1750.0 + 110.0, 0.0, 160.0), "perto do sino (siga o som para oeste)")

func _process(delta: float) -> void:
	if not visible or jogo == null:
		return
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = 0.25
	var b: Vector3 = jogo.barco.global_position
	_status.text = "pos (%.0f, %.0f) · %s · dia %d%s · medo %d%% · óleo %d%% · FPS %d" % [b.x, b.z, jogo.clima.texto_hora(), int(jogo.clima.dias),
			" · bruma" if jogo.clima.noite_de_bruma() else "", roundi(float(jogo.assombro.valor) * 100.0), roundi(float(jogo.assombro.oleo) * 100.0),
			Engine.get_frames_per_second()]
