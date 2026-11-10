extends PanelContainer
## Mercado de peixe de uma cidade (spec 7.2, 7.3 e 8): abas Vender, Missões, Balcão e, onde há, Doca seca.
## Montada por código. Cada botão chama o Estado e a tela se refaz; não guarda regra nenhuma.

const Mercado = preload("res://logica/mercado.gd")
const Missoes = preload("res://logica/missoes.gd")
const Especies = preload("res://logica/especies.gd")

signal fechar
signal mudou

const NOME_ABA := {"vender": "Vender", "missoes": "Missões", "balcao": "Balcão", "doca": "Doca seca"}
const NOME_ITEM := {"vara_profunda": "Vara profunda (rasas e profundas)", "vara_abissal": "Vara abissal (todas as águas)",
	"rede": "Rede (sardinha e peixe-lanterna)", "agua": "Água", "tabua": "Tábua", "corda": "Corda",
	"conserto_lanterna": "Conserto da lanterna", "isca_abissal": "Isca abissal"}
const ORDEM_BALCAO := ["combustivel", "agua", "tabua", "corda", "vara_profunda", "vara_abissal", "rede", "isca_abissal",
	"conserto_lanterna"]
const RESULTADO := {"sem_dinheiro": "Dinheiro insuficiente", "ja_tem": "Você já tem", "indisponivel": "Não está à venda aqui",
	"maximo": "Já está no nível máximo", "sem_doca": "Esta cidade não tem doca seca", "limite": "Você já tem 3 missões ativas",
	"sem_espaco": "A carga não cabe no porão", "vencida": "O prazo venceu", "incompleta": "Ainda falta cumprir a missão",
	"cidade_errada": "Entregue na cidade certa"}

var estado
var dados: Dictionary
var especies: Array
var rng: RandomNumberGenerator
var aba := "vender"
var _botoes: Dictionary = {}
var _textos: Array = []
var _titulo := ""
var _mensagem := ""


func abrir(p_estado, p_dados: Dictionary, p_especies: Array, p_rng: RandomNumberGenerator) -> void:
	estado = p_estado
	dados = p_dados
	especies = p_especies
	rng = p_rng
	aba = "vender"
	_mensagem = ""
	visible = true
	_refazer()


func mostrar_aba(nome: String) -> void:
	aba = nome
	_refazer()


func tem(chave: String) -> bool:
	return _botoes.has(chave)


func apertar(chave: String) -> void:
	if _botoes.has(chave):
		_botoes[chave].pressed.emit()


func textos() -> Array:
	return _textos


func titulo() -> String:
	return _titulo


func mensagem() -> String:
	return _mensagem


func _cidade() -> Dictionary:
	return Mercado.cidade(dados, estado.cidade)


func _refazer() -> void:
	for f in get_children():
		remove_child(f)
		f.queue_free()
	_botoes.clear()
	_textos.clear()
	var cid := _cidade()
	_titulo = "Mercado de %s — R$ %d" % [cid.get("nome", estado.cidade), estado.dinheiro]
	custom_minimum_size = Vector2(1300, 820)
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.07, 0.11, 0.17, 0.97)
	fundo.border_color = Color(0.85, 0.65, 0.3)
	fundo.set_border_width_all(3)
	fundo.set_corner_radius_all(10)
	fundo.set_content_margin_all(26)
	add_theme_stylebox_override("panel", fundo)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 12)
	add_child(caixa)
	caixa.add_child(_rotulo(_titulo, 40))
	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 10)
	caixa.add_child(abas)
	var nomes := ["vender", "missoes", "balcao"]
	if cid.get("tem_doca", false):
		nomes.append("doca")
	elif aba == "doca":
		aba = "vender"
	for n in nomes:
		var b := _botao("aba:" + n, NOME_ABA[n], func(): _mensagem = ""; mostrar_aba(n))
		b.disabled = n == aba
		abas.add_child(b)
	var msg := _rotulo(_mensagem, 28)
	msg.modulate = Color(1, 0.88, 0.5)
	msg.custom_minimum_size = Vector2(0, 40)
	caixa.add_child(msg)
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caixa.add_child(rolagem)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 8)
	rolagem.add_child(lista)
	match aba:
		"vender": _aba_vender(lista)
		"missoes": _aba_missoes(lista)
		"balcao": _aba_balcao(lista)
		"doca": _aba_doca(lista)
	caixa.add_child(_botao("fechar", "Fechar  [M]", func(): fechar.emit()))


func _feito(texto: String) -> void:
	_mensagem = texto
	_refazer()
	mudou.emit()


func _linha(lista: VBoxContainer, texto: String, chave := "", rotulo_botao := "", acao := Callable()) -> void:
	_textos.append(texto)
	var linha := HBoxContainer.new()
	lista.add_child(linha)
	var r := _rotulo(texto, 26)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	linha.add_child(r)
	if chave != "":
		linha.add_child(_botao(chave, rotulo_botao, acao))


func _aba_vender(lista: VBoxContainer) -> void:
	var total := 0
	var peixes := 0
	for i in estado.porao.itens.size():
		var it: Dictionary = estado.porao.itens[i]
		if it.get("carga", false):
			_linha(lista, "Carga de missão — %d L (não se vende)" % roundi(float(it.volume)))
			continue
		var esp := Especies.por_id(especies, it.especie)
		var preco: int = estado.preco_de(dados, especies, i)
		total += preco
		peixes += 1
		_linha(lista, "%s — %d cm (%s) — R$ %d" % [esp.get("nome", it.especie), roundi(float(it.tam)), it.classe, preco],
				"vender:%d" % i, "Vender", func(): _feito("Vendido por R$ %d" % estado.vender(dados, especies, [i])))
	if peixes == 0:
		_linha(lista, "Nenhum peixe no porão. Vá pescar e volte!")
	else:
		_linha(lista, "Tudo: %d peixes por R$ %d" % [peixes, total], "vender_tudo", "Vender tudo",
				func(): _feito("Vendeu tudo por R$ %d" % estado.vender_tudo(dados, especies)))


func _aba_missoes(lista: VBoxContainer) -> void:
	lista.add_child(_rotulo("Suas missões (%d de %d)" % [estado.missoes.ativas.size(), int(Missoes.config().get("max_ativas", 3))], 30))
	if estado.missoes.ativas.is_empty():
		_linha(lista, "Nenhuma missão ativa.")
	for m in estado.missoes.ativas.duplicate():
		var texto := "%s\n%s" % [Missoes.descricao(m, especies, dados), Missoes.texto_progresso(m, estado.porao, Vector2.INF, estado.dia)]
		var pronta: bool = Missoes.progresso(m, estado.porao, Vector2.INF, estado.dia).pronta and m.cidade == estado.cidade
		if pronta:
			_linha(lista, texto, "entregar:" + str(m.id), "Entregar", func():
				var r: Dictionary = estado.entregar_missao(dados, especies, m.id)
				_feito("Missão cumprida: R$ %d e %d XP" % [r.reais, r.xp] if r.ok else RESULTADO.get(r.motivo, "Não deu")))
		else:
			_linha(lista, texto)
	lista.add_child(_rotulo("Ofertas de hoje", 30))
	var ofertas: Array = estado.ofertas_de(dados, especies, rng)
	if ofertas.is_empty():
		_linha(lista, "Sem ofertas por hoje. Volte amanhã.")
	for m in ofertas.duplicate():
		_linha(lista, "%s\n%s" % [Missoes.descricao(m, especies, dados), Missoes.texto_prazo(m, estado.dia)],
				"aceitar:" + str(m.id), "Aceitar", func():
					var r: String = estado.aceitar_missao(dados, m.id)
					_feito("Missão aceita" if r == "ok" else RESULTADO.get(r, "Não deu")))


func _aba_balcao(lista: VBoxContainer) -> void:
	for item in ORDEM_BALCAO:
		if not Mercado.item_disponivel(dados, item, estado.cidade):
			continue
		var preco := int(dados.loja.balcao[item])
		if item == "combustivel":
			var falta := int(floor(estado.tanque() - estado.combustivel))
			if falta <= 0:
				_linha(lista, "Combustível — tanque cheio (%d)" % roundi(estado.tanque()))
			else:
				_linha(lista, "Encher o tanque — %d un. — R$ %d (R$ %d cada)" % [falta, falta * preco, preco],
						"comprar:combustivel", "Abastecer", func(): _comprar("combustivel", falta))
			continue
		if item.begins_with("vara_") and item.trim_prefix("vara_") in estado.varas:
			_linha(lista, "%s — você já tem" % NOME_ITEM[item])
			continue
		if item == "rede" and int(estado.melhorias.get("rede", 0)) > 0:
			_linha(lista, "%s — você já tem" % NOME_ITEM[item])
			continue
		if item == "conserto_lanterna" and not estado.lanterna_quebrada:
			continue
		var tem := ""
		if item in Mercado.SUPRIMENTOS:
			tem = " (você tem %d)" % int(estado.suprimentos.get(item, 0))
		_linha(lista, "%s — R$ %d%s" % [NOME_ITEM.get(item, item), preco, tem], "comprar:" + item, "Comprar",
				func(): _comprar(item, 1))


func _comprar(item: String, qtd: int) -> void:
	var r: String = estado.comprar(dados, item, qtd)
	_feito("Comprado" if r == "ok" else RESULTADO.get(r, "Não deu"))


func _aba_doca(lista: VBoxContainer) -> void:
	for id in dados.loja.melhorias:
		var m: Dictionary = dados.loja.melhorias[id]
		var nivel := int(estado.melhorias.get(id, 0))
		var preco := Mercado.preco_melhoria(dados, id, nivel)
		if preco < 0:
			_linha(lista, "%s — no máximo" % m.nome)
			continue
		var prox = m.niveis[nivel + 1]
		var detalhe := "nível %d" % (nivel + 2)
		if id == "porao":
			detalhe = "%d L" % int(prox)
		elif id == "tanque":
			detalhe = "%d de combustível" % int(prox)
		elif id == "motor":
			detalhe = "nível %d" % int(prox)
		elif m.niveis.size() == 2:
			detalhe = "instalar"
		_linha(lista, "%s → %s — R$ %d" % [m.nome, detalhe, preco], "melhorar:" + id, "Melhorar", func():
			var r: String = estado.melhorar(dados, id)
			_feito("%s melhorado" % m.nome if r == "ok" else RESULTADO.get(r, "Não deu")))
	var reparo: int = estado.preco_reparo(dados)
	if reparo > 0:
		_linha(lista, "Reparo completo do casco (%d%%) — R$ %d" % [roundi(estado.casco), reparo], "reparar", "Reparar", func():
			var r: String = estado.reparar_casco(dados)
			_feito("Casco reparado" if r == "ok" else RESULTADO.get(r, "Não deu")))
	else:
		_linha(lista, "Casco inteiro (100%)")


func _rotulo(texto: String, tam: int) -> Label:
	var r := Label.new()
	r.text = texto
	r.add_theme_font_size_override("font_size", tam)
	return r


func _botao(chave: String, texto: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(170, 48)
	b.pressed.connect(acao)
	_botoes[chave] = b
	return b
