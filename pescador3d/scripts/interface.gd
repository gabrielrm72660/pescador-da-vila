extends CanvasLayer
## Interface criada por código para permanecer independente de fontes externas.
## Cores marítimas, escrita em português e layout 16:9 responsivo.

signal iniciar_pressed
signal reiniciar_pressed
signal construtor_pressed
signal pescar_pressed
signal pausa_pressed
signal vender_pressed
signal abastecer_pressed
signal zarpar_pressed
signal melhoria_pressed(id: String)
signal volume_mudou(grupo: String, valor: float)
signal mudo_pressed
signal comprar_iscas_pressed
signal melhorar_linha_pressed
signal sair_pressed
signal consertar_pressed
signal idioma_mudou
signal conversar_pressed(id: String)    # v0.6.0: botão "Conversar" do cais
signal dialogo_terminou                 # v0.6.0: acabou a conversa com o NPC do cais
signal noite_pressed(o_que: String)     # v0.8.7: aba Noite do cais: "oleo", "vela", "patua", "sino", "aberrantes"

const HudPintado = preload("res://scripts/hud.gd")
const CartaMapa = preload("res://scripts/mapa_cartografico.gd")
const Caderno = preload("res://scripts/caderno.gd")
const Aq = preload("res://scripts/aquarela.gd")
const BotaoAq = preload("res://scripts/botao_aquarela.gd")
const DeslizanteAq = preload("res://scripts/deslizante_aquarela.gd")
const VEU = preload("res://shaders/veu_aquarela.gdshader")
const T = preload("res://scripts/idioma.gd")
const TelaInicial = preload("res://scripts/tela_inicial.gd")
const Marca = preload("res://scripts/marca.gd")
const Dialogo = preload("res://scripts/dialogo.gd")
const Npcs = preload("res://scripts/npcs.gd")

var raiz: Control
var menu: ColorRect
var titulo_menu: Label
var subtitulo_menu: Label
var botao_principal: Button
var botao_reiniciar: Button
var hud: Control
var mapa: Control
var caderno: Control             # v0.7.0: caderno de peixes (P)
var final_ativo := false         # v0.7.0: o cartão do final da história está na tela
var controles_volume: Dictionary = {}     # grupo -> {barra: HSlider, valor: Label}
var botao_mudo: Button
var porto: ColorRect
var porto_titulo: Label
var porto_texto: Label
var porto_vender: Button
var porto_abastecer: Button
var porto_iscas: Button
var porto_linha: Button
var porto_rotulo_loja: Label
var porto_loja: Dictionary = {}           # id da melhoria -> botão
var diario: Array = []          # histórico das mensagens (botão do livro)
var esconder_hud: bool = false   # para tirar fotos do jogo sem a interface
var porao: Node = null          # scripts/porao.gd
var capturas: Array:            # os peixes a bordo: {especie, peso, x, y, rot}
    get:
        return porao.itens if porao != null else []
var _peso: float = 0.0
var graficos: Node = null        # scripts/opcoes_graficas.gd (Opções > Gráficos mexe nele)
var paginas: Dictionary = {}     # nome -> VBoxContainer
var pagina_atual := "principal"
var _textos: Array = []          # [Control, texto em português]: trocados quando o idioma muda
var _pausa := false
var _tem_salva := false
var _confirmar_novo := -100.0
var _mudo := false
var _botoes_idioma: Dictionary = {}
var _botoes_qualidade: Array = []
var _botoes_fps: Array = []
var _botoes_fsr: Array = []          # v0.9.2: FSR 2 (Desligado, Qualidade, Equilibrado, Desempenho)
var _placa_graficos: Label
var _botoes_tela: Array = []
var _botao_auto: Button
var _botao_vsync: Button
var _botao_fps_tela: Button
var _dica_graficos: Label
var porto_consertar: Button
var porto_sair: Button
var _ultimo_porto: Dictionary = {}
var _voltar_do_avancado := false
var tela_inicial: Control             # v0.6.0: o jogo abre nela
var dialogo: Control                  # v0.6.0: caixa de diálogo dos NPCs (scripts/dialogo.gd)
var porto_npcs: HBoxContainer         # v0.6.0: botões "Conversar com ..."
var _botoes_npc: Array = []
var no_titulo := false

const COR_TEXTO := Aq.NANQUIM                       # tinta dos textos sobre o papel
const COR_SECAO := Color(0.08, 0.40, 0.42)         # títulos de seção: verde-azulado
const COR_TITULO := Color(0.58, 0.24, 0.15)        # terracota: nomes e títulos
const COR_SUAVE := Aq.NANQUIM_CLARO

func _ready() -> void:
    Aq.preparar_fontes()
    raiz = Control.new()
    raiz.name = "InterfaceRaiz"
    raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(raiz)
    _construir_hud()
    _construir_mapa()
    caderno = Caderno.new()
    caderno.name = "CadernoPeixes"
    raiz.add_child(caderno)
    _construir_porto()
    dialogo = Dialogo.new()
    raiz.add_child(dialogo)
    dialogo.construir(self)
    dialogo.terminou.connect(func(): dialogo_terminou.emit())
    tela_inicial = TelaInicial.new()
    raiz.add_child(tela_inicial)
    tela_inicial.construir(self)
    tela_inicial.visible = false
    tela_inicial.continuar.connect(func(): iniciar_pressed.emit())
    tela_inicial.novo_jogo.connect(func(): reiniciar_pressed.emit())
    tela_inicial.sair.connect(func(): sair_pressed.emit())
    tela_inicial.opcoes.connect(func():
        menu.visible = true
        _ir_para("opcoes"))
    _construir_menu()

func _nova_label(texto: String, tamanho: int, cor: Color, quebra: bool = false, titulo: bool = false) -> Label:
    var item := Label.new()
    item.text = texto
    item.add_theme_font_override("font", Aq.FONTE_TITULO if titulo else Aq.FONTE_TEXTO)
    item.add_theme_font_size_override("font_size", tamanho)
    item.add_theme_color_override("font_color", cor)
    if quebra:
        item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return item

## Cartão de papel de aquarela: o PanelContainer perde o fundo liso e ganha a lavagem por baixo.
func _cartao_papel(cartao: PanelContainer, semente: float) -> void:
    var vazio := StyleBoxEmpty.new()
    cartao.add_theme_stylebox_override("panel", vazio)
    var esq: Dictionary = Aq.esquema("papel")
    Aq.fundo(cartao, esq["cor"], esq["cor2"], semente, esq["extra"], 12.0)

## Se a folha for mais alta que a tela, encolhe de leve em vez de cortar o rodapé (vale para qualquer resolução e texto).
var _ajustes: Array = []
func _encaixar(cartao: Control) -> void:
    var ajustar := func():
        if not cartao.is_inside_tree() or cartao.size.y < 1.0:
            return
        var area := cartao.get_viewport_rect().size
        var f := minf(1.0, minf((area.y - 20.0) / cartao.size.y, (area.x - 20.0) / cartao.size.x))
        cartao.pivot_offset = cartao.size * 0.5
        if f < 0.999:
            # v0.5.8: cartão mais alto que a tela: o CenterContainer o encosta no topo (não centraliza),
            # então o pivô é calculado para o cartão encolhido ficar centrado de verdade (antes o pé saía da tela).
            var alvo_topo: float = (area.y - cartao.size.y * f) * 0.5
            cartao.pivot_offset.y = clampf((alvo_topo - cartao.position.y) / (1.0 - f), 0.0, cartao.size.y)
        cartao.scale = Vector2(f, f)
    cartao.resized.connect(func(): ajustar.call_deferred())          # depois do CenterContainer reposicionar
    cartao.visibility_changed.connect(func(): ajustar.call_deferred())
    ajustar.call_deferred()
    _ajustes.append(ajustar)

## v0.5.8: depois de trocar de página o cartão muda de altura no quadro seguinte; reencaixa quando o layout assentar.
func _reencaixar() -> void:
    for k in 2:
        await get_tree().process_frame
        for a in _ajustes:
            a.call()

func _botao_aq(texto: String, nome_esquema: String, semente: float, cor_texto: Color, tamanho: int, minimo: Vector2) -> Button:
    var b := BotaoAq.new()
    b.text = texto
    b.custom_minimum_size = minimo
    b.configurar(nome_esquema, semente, cor_texto, tamanho)
    return b

## Fio de nanquim ondulado entre seções (um Control que se desenha sozinho).
func _ornamento(altura: float = 14.0, cor: Color = Color(Aq.NANQUIM, 0.5)) -> Control:
    var o := Control.new()
    o.custom_minimum_size = Vector2(0, altura)
    o.mouse_filter = Control.MOUSE_FILTER_IGNORE
    o.draw.connect(func():
        var w := o.size.x
        var pts := PackedVector2Array()
        var n := maxi(6, int(w / 12.0))
        for i in n + 1:
            var t := float(i) / float(n)
            pts.append(Vector2(w * 0.04 + w * 0.92 * t, altura * 0.5 + sin(t * 23.0) * 1.3 + sin(t * 7.0) * 1.6))
        o.draw_polyline(pts, cor, 2.0, true))
    return o

func _construir_hud() -> void:
    hud = HudPintado.new()
    hud.name = "Hud"
    raiz.add_child(hud)
    hud.botao.connect(_ao_apertar_botao)


func _construir_mapa() -> void:
    mapa = CartaMapa.new()
    mapa.name = "MapaCartografico"
    raiz.add_child(mapa)

func conectar_mapa(barco: Node3D, ilhas: Array) -> void:
    if mapa != null and mapa.has_method("configurar"):
        mapa.configurar(barco, ilhas)

func alternar_mapa() -> bool:
    if mapa == null or not mapa.has_method("alternar"):
        return false
    hud.soltar_peixe()
    hud.painel_aberto = ""
    return mapa.alternar()

func alternar_caderno() -> bool:
    hud.soltar_peixe()
    hud.painel_aberto = ""
    if mapa_aberto():
        mapa.fechar()
    return caderno.alternar()

## v0.8.4: o Livro do Pescador (manual + peixes + diário de bordo). secao: "" = onde parou, "peixes", "manual", "diario".
func alternar_livro(secao: String = "") -> bool:
    if caderno.aberto():
        caderno.fechar()
        return false
    caderno.diario = diario
    if secao == "peixes":
        if caderno._secao(caderno.pagina) in ["manual", "diario"]:
            caderno.ir_para_zona("costa")
    elif secao != "":
        caderno.ir_para_zona(secao)
    return alternar_caderno()

func caderno_aberto() -> bool:
    return caderno != null and caderno.aberto()

func mapa_aberto() -> bool:
    return mapa != null and mapa.has_method("aberto") and mapa.aberto()

func _ao_apertar_botao(nome: String) -> void:
    match nome:
        "pescar":
            pescar_pressed.emit()
        "porao":
            alternar_painel(nome)
        "diario":
            alternar_livro()
        "caderno":
            alternar_livro("peixes")

## Abre ou fecha o painel do porão (peixes pescados) ou do diário (últimas mensagens).
func alternar_painel(nome: String) -> void:
    hud.soltar_peixe()
    hud.painel_aberto = "" if hud.painel_aberto == nome else nome
    _preencher_painel()

func fechar_painel() -> bool:
    var estava: bool = hud.painel_aberto != "" or mapa_aberto() or caderno_aberto()
    hud.soltar_peixe()
    hud.painel_aberto = ""
    if mapa_aberto():
        mapa.fechar()
    if caderno_aberto():
        caderno.fechar()
    return estava

func _preencher_painel() -> void:
    if hud.painel_aberto == "porao":
        hud.titulo_painel = T.t("Porão")                      # a grade é desenhada por scripts/hud.gd
    elif hud.painel_aberto == "diario":
        hud.titulo_painel = T.t("Diário de bordo")
        hud.linhas_painel = diario.slice(maxi(0, diario.size() - 9))

func _construir_menu() -> void:
    menu = ColorRect.new()
    menu.color = Color.WHITE
    var veu := ShaderMaterial.new()
    veu.shader = VEU
    menu.material = veu
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.mouse_filter = Control.MOUSE_FILTER_STOP
    raiz.add_child(menu)

    var central := CenterContainer.new()
    central.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.add_child(central)

    var cartao := PanelContainer.new()
    cartao.custom_minimum_size = Vector2(600, 0)
    _cartao_papel(cartao, 3.0)
    central.add_child(cartao)
    _encaixar(cartao)

    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 46)
    margem.add_theme_constant_override("margin_right", 46)
    margem.add_theme_constant_override("margin_top", 18)
    margem.add_theme_constant_override("margin_bottom", 24)
    cartao.add_child(margem)

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 8)
    margem.add_child(col)

    titulo_menu = _nova_label("BRUMA", 78, Color(0.10, 0.27, 0.36), false, true)
    titulo_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(titulo_menu)
    col.add_child(_ornamento(14.0))

    subtitulo_menu = _nova_label("", 23, COR_TEXTO, true)
    subtitulo_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(subtitulo_menu)

    # ---- página principal: Voltar a navegar, Novo jogo, Opções, Sair do jogo
    var principal := _nova_pagina(col, "principal")
    botao_principal = _botao_aq("", "turquesa", 5.0, Aq.NANQUIM, 28, Vector2(440, 54))
    botao_principal.pressed.connect(_clicar_iniciar)
    principal.add_child(botao_principal)
    botao_reiniciar = _botao_aq("", "mar", 8.0, Aq.CREME, 23, Vector2(440, 46))
    botao_reiniciar.pressed.connect(_clicar_reiniciar)
    principal.add_child(botao_reiniciar)
    principal.add_child(_t(_botao_aq("", "mar", 9.5, Aq.CREME, 23, Vector2(440, 46)), "OPÇÕES", func(): _ir_para("opcoes")))
    principal.add_child(_t(_botao_aq("", "terracota", 11.0, Aq.CREME, 23, Vector2(440, 46)), "SAIR DO JOGO", func(): sair_pressed.emit()))
    principal.add_child(_ornamento(12.0, Color(Aq.NANQUIM, 0.35)))
    var atalhos := _nova_label("", 18, COR_SUAVE, true)
    atalhos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _t(atalhos, "W A S D  navegar   •   ESPAÇO  frear\nF  pescar e atracar no cais   •   I  inventário (porão)\nTAB  livro do pescador   •   M  carta náutica   •   ESC  menu")
    principal.add_child(atalhos)

    # ---- Opções
    var opcoes := _nova_pagina(col, "opcoes")
    opcoes.add_child(_t(_botao_aq("", "mar", 13.0, Aq.CREME, 24, Vector2(440, 50)), "GERAL", func(): _ir_para("geral")))
    opcoes.add_child(_t(_botao_aq("", "mar", 14.0, Aq.CREME, 24, Vector2(440, 50)), "ÁUDIO", func(): _ir_para("audio")))
    opcoes.add_child(_t(_botao_aq("", "mar", 15.0, Aq.CREME, 24, Vector2(440, 50)), "GRÁFICOS", func(): _ir_para("graficos")))
    opcoes.add_child(_t(_botao_aq("", "terracota", 16.0, Aq.CREME, 23, Vector2(440, 46)), "VOLTAR AO MENU", func(): _ir_para("principal")))

    # ---- Geral: idioma
    var geral := _nova_pagina(col, "geral")
    geral.add_child(_t(_nova_label("", 26, COR_SECAO, false, true), "IDIOMA"))
    var linha_idioma := HBoxContainer.new()
    linha_idioma.add_theme_constant_override("separation", 10)
    geral.add_child(linha_idioma)
    var n_id := 0.0
    for codigo in T.IDIOMAS:
        n_id += 1.0
        var bi := _botao_aq(T.NOME_IDIOMA[codigo], "mar", 20.0 + n_id, Aq.CREME, 22, Vector2(140, 48))
        bi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        bi.pressed.connect(func(): definir_idioma(codigo))
        linha_idioma.add_child(bi)
        _botoes_idioma[codigo] = bi
    var nota := _nova_label("", 17, COR_SUAVE, true)
    _t(nota, "Menus, painéis, missões e conversas mudam na hora.")
    geral.add_child(nota)
    geral.add_child(_t(_botao_aq("", "terracota", 24.0, Aq.CREME, 23, Vector2(440, 46)), "VOLTAR", func(): _ir_para("opcoes")))

    # ---- Áudio
    var audio := _nova_pagina(col, "audio")
    _construir_volume(audio)
    audio.add_child(_t(_botao_aq("", "terracota", 27.0, Aq.CREME, 23, Vector2(440, 46)), "VOLTAR", func(): _ir_para("opcoes")))

    # ---- Gráficos (o mesmo do F10) e o botão Avançado (o painel do F11)
    var graf := _nova_pagina(col, "graficos")
    _construir_graficos(graf)
    graf.add_child(_t(_botao_aq("", "terracota", 33.0, Aq.CREME, 23, Vector2(440, 46)), "VOLTAR", func(): _ir_para("opcoes")))

    _ir_para("principal")
    _aplicar_idioma()

## Uma página do menu: só uma fica visível por vez (ver _ir_para).
func _nova_pagina(col: VBoxContainer, nome: String) -> VBoxContainer:
    var p := VBoxContainer.new()
    p.name = "Pagina_" + nome
    p.add_theme_constant_override("separation", 8)
    col.add_child(p)
    paginas[nome] = p
    return p

## Registra o texto (em português, a chave) para trocar de idioma; se vier "acao", liga ao clique do botão.
func _t(controle: Control, chave: String, acao: Callable = Callable()) -> Control:
    _textos.append([controle, chave])
    controle.set("text", T.t(chave))
    if acao.is_valid() and controle is BaseButton:
        (controle as BaseButton).pressed.connect(acao)
    return controle

func _ir_para(nome: String) -> void:
    pagina_atual = nome
    if nome == "principal" and no_titulo and menu != null and menu.visible:
        menu.visible = false                   # nas opções vindas da tela inicial, "voltar" volta para ela
        return
    for k in paginas:
        paginas[k].visible = k == nome
    _confirmar_novo = -100.0
    _atualizar_cabecalho()
    if nome == "graficos":
        _atualizar_graficos()
    _reencaixar()

## Título e subtítulo conforme a página e o estado (início ou pausa).
func _atualizar_cabecalho() -> void:
    match pagina_atual:
        "principal":
            titulo_menu.text = T.t("PAUSA") if _pausa else Marca.NOME.to_upper()
            subtitulo_menu.text = T.t("O oceano continua esperando por você.") if _pausa else T.t("Uma aventura de pesca no Atlântico brasileiro.\nAssuma o comando do Estrela d'Alva.")
            if _pausa:
                botao_principal.text = T.t("VOLTAR A NAVEGAR")
            else:
                botao_principal.text = T.t("CONTINUAR A VIAGEM") if _tem_salva else T.t("COMEÇAR A VIAGEM")
            botao_reiniciar.text = T.t("NOVO JOGO")
        "opcoes":
            titulo_menu.text = T.t("OPÇÕES")
            subtitulo_menu.text = T.t("Ajuste o jogo do seu jeito.")
        "geral":
            titulo_menu.text = T.t("GERAL")
            subtitulo_menu.text = T.t("Idioma do jogo.")
        "audio":
            titulo_menu.text = T.t("ÁUDIO")
            subtitulo_menu.text = T.t("Cada som tem o seu volume.")
        "graficos":
            titulo_menu.text = T.t("GRÁFICOS")
            subtitulo_menu.text = T.t("Qualidade e desempenho (o mesmo do F10).")

## ESC dentro de uma subpágina volta um nível (em vez de fechar a pausa).
func _unhandled_input(event: InputEvent) -> void:
    if menu == null or not menu.visible or pagina_atual == "principal":
        return
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
        _ir_para("principal" if pagina_atual == "opcoes" else "opcoes")
        get_viewport().set_input_as_handled()

func definir_idioma(codigo: String) -> void:
    T.definir(codigo)
    _aplicar_idioma()
    idioma_mudou.emit()

func _aplicar_idioma() -> void:
    if tela_inicial != null and tela_inicial.has_method("atualizar_textos") and tela_inicial._titulo != null:
        tela_inicial.atualizar_textos()
    if dialogo != null:
        dialogo.atualizar_textos()
    for par in _textos:
        if is_instance_valid(par[0]):
            par[0].set("text", T.t(par[1]))
    for codigo in _botoes_idioma:
        _botoes_idioma[codigo].marcar(codigo == T.lingua)
    for grupo in controles_volume:
        controles_volume[grupo].rotulo.text = T.t(NOMES_VOLUME[grupo])
    if botao_mudo != null:
        botao_mudo.text = T.t("Som desligado — ligar") if _mudo else T.t("Silenciar tudo")
    _atualizar_cabecalho()
    _atualizar_graficos()
    if porto != null and porto.visible and not _ultimo_porto.is_empty():
        mostrar_porto(_ultimo_porto)
    pass
    if porto_sair != null:
        porto_sair.text = T.t("Zarpar   [F]")
    _preencher_painel()

# ------------------------------------------------------------------ Opções > Gráficos

func _construir_graficos(pag: VBoxContainer) -> void:
    pag.add_child(_t(_nova_label("", 22, COR_SECAO, false, true), "QUALIDADE"))
    var fila_q := HBoxContainer.new()
    fila_q.add_theme_constant_override("separation", 8)
    pag.add_child(fila_q)
    for i in 4:
        var b := _botao_aq("", "mar", 40.0 + float(i), Aq.CREME, 20, Vector2(100, 42))
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _t(b, ["Baixa", "Média", "Alta", "Ultra"][i], _graf.bind("qualidade", i))
        fila_q.add_child(b)
        _botoes_qualidade.append(b)
    _dica_graficos = _nova_label("", 16, COR_SUAVE, true)
    _dica_graficos.custom_minimum_size = Vector2(500, 0)
    pag.add_child(_dica_graficos)
    # v0.9.2: o que a detecção da placa escolheu, e o botão para refazer a escolha
    _placa_graficos = _nova_label("", 15, COR_SUAVE, true)
    _placa_graficos.custom_minimum_size = Vector2(500, 0)
    pag.add_child(_placa_graficos)
    pag.add_child(_t(_botao_aq("", "mar", 39.0, Aq.CREME, 19, Vector2(440, 40)), "Escolher pela minha placa de vídeo", _graf.bind("placa", 0)))
    # v0.9.2: FSR 2
    pag.add_child(_t(_nova_label("", 22, COR_SECAO, false, true), "FSR 2  (mais FPS, imagem reconstruída)"))
    var fila_s := HBoxContainer.new()
    fila_s.add_theme_constant_override("separation", 8)
    pag.add_child(fila_s)
    for i in 4:
        var bs := _botao_aq("", "mar", 60.0 + float(i), Aq.CREME, 19, Vector2(100, 42))
        bs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _t(bs, ["Desligado", "Qualidade", "Equilibrado", "Desempenho"][i], _graf.bind("fsr", i))
        fila_s.add_child(bs)
        _botoes_fsr.append(bs)
    # v0.5.8: modo de tela
    pag.add_child(_t(_nova_label("", 22, COR_SECAO, false, true), "TELA"))
    var fila_j := HBoxContainer.new()
    fila_j.add_theme_constant_override("separation", 8)
    pag.add_child(fila_j)
    for i in 2:
        var bj := _botao_aq("", "mar", 46.0 + float(i), Aq.CREME, 20, Vector2(200, 42))
        bj.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _t(bj, ["Janela", "Tela cheia  (Alt+Enter)"][i], _graf.bind("tela", i))
        fila_j.add_child(bj)
        _botoes_tela.append(bj)
    _botao_auto = _botao_aq("", "mar", 45.0, Aq.CREME, 19, Vector2(440, 40))
    _botao_auto.pressed.connect(_graf.bind("auto", 0))
    pag.add_child(_botao_auto)
    pag.add_child(_t(_nova_label("", 22, COR_SECAO, false, true), "LIMITE DE QUADROS"))
    var fila_f := HBoxContainer.new()
    fila_f.add_theme_constant_override("separation", 8)
    pag.add_child(fila_f)
    for i in 4:
        var b := _botao_aq("", "mar", 50.0 + float(i), Aq.CREME, 20, Vector2(100, 42))
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _t(b, ["30 FPS", "60 FPS", "120 FPS", "Sem limite"][i], _graf.bind("fps", i))
        fila_f.add_child(b)
        _botoes_fps.append(b)
    var fila_t := HBoxContainer.new()
    fila_t.add_theme_constant_override("separation", 8)
    pag.add_child(fila_t)
    _botao_vsync = _botao_aq("", "mar", 55.0, Aq.CREME, 19, Vector2(200, 40))
    _botao_vsync.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _botao_vsync.pressed.connect(_graf.bind("vsync", 0))
    fila_t.add_child(_botao_vsync)
    _botao_fps_tela = _botao_aq("", "mar", 56.0, Aq.CREME, 19, Vector2(200, 40))
    _botao_fps_tela.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _botao_fps_tela.pressed.connect(_graf.bind("mostrar_fps", 0))
    fila_t.add_child(_botao_fps_tela)
    pag.add_child(_t(_botao_aq("", "ocre", 58.0, Aq.CREME, 24, Vector2(440, 48)), "AVANÇADO  (luz, névoa, reflexos, pintura)  [F11]", _graf.bind("avancado", 0)))
    pag.add_child(_t(_botao_aq("", "mar", 59.0, Aq.CREME, 18, Vector2(440, 38)), "Teste de desempenho da GPU (≈2 min)  [F2]", _graf.bind("bancada", 0)))

func _graf(o_que: String, n: int) -> void:
    if graficos == null:
        return
    match o_que:
        "qualidade": graficos.definir_qualidade(n)
        "auto": graficos.definir_automatica(not graficos.automatica)
        "fps": graficos.definir_limite_fps(n)
        "vsync": graficos.definir_vsync(not graficos.vsync)
        "fsr": graficos.definir_fsr(n)
        "placa": graficos.escolher_pela_placa()
        "tela": graficos.definir_tela_cheia(n == 1)
        "mostrar_fps": graficos.alternar_fps()
        "avancado":                                  # o menu sai da frente para ver a cena; volta quando o painel fechar
            graficos.abrir_avancado()
            menu.visible = false
            _voltar_do_avancado = true
        "bancada":
            esconder_menu()
            graficos.iniciar_bancada()
    _atualizar_graficos()

func _atualizar_graficos() -> void:
    if graficos == null or _dica_graficos == null:
        return
    for i in _botoes_qualidade.size():
        _botoes_qualidade[i].marcar(i == int(graficos.qualidade))
    for i in _botoes_fps.size():
        _botoes_fps[i].marcar(i == int(graficos.fps_indice))
    for i in _botoes_tela.size():
        _botoes_tela[i].marcar(i == (1 if graficos.tela_cheia else 0))
    _dica_graficos.text = T.t(graficos.texto_dica())
    var fplus: bool = graficos.e_forward_plus()
    for i in _botoes_fsr.size():
        _botoes_fsr[i].marcar(i == int(graficos.fsr) and fplus)
        _botoes_fsr[i].disabled = not fplus
    var linhas: Array = []
    if String(graficos.placa_detectada) != "":
        linhas.append(T.t("Escolhido pela placa") + " — " + String(graficos.placa_detectada))
    else:
        linhas.append(T.t("Placa de vídeo") + ": " + RenderingServer.get_video_adapter_name())
    if not fplus:
        linhas.append(T.t("FSR 2 só funciona no renderizador Forward+ (Vulkan)."))
    _placa_graficos.text = "\n".join(linhas)
    var lig := T.t("ligado")
    var des := T.t("desligado")
    _botao_auto.text = T.t("Ajuste automático (abaixa a qualidade se travar)") + ": " + (lig if graficos.automatica else des)
    _botao_auto.marcar(graficos.automatica)
    _botao_vsync.text = "V-Sync: " + (lig if graficos.vsync else des)
    _botao_vsync.marcar(graficos.vsync)
    _botao_fps_tela.text = T.t("Mostrar FPS (F3)") + ": " + (lig if graficos.mostrar_fps else des)
    _botao_fps_tela.marcar(graficos.mostrar_fps)

## v0.8.4: painel do cais reorganizado. Em cima, quatro mostradores (carteira, porão, tanque, casco) e a encomenda numa
## fita; no meio, duas abas: Serviços (uma linha por serviço: situação à esquerda, ação à direita; o que não tem nada a
## fazer vira um "ok" discreto) e Oficina do barco (as melhorias em duas colunas: agora → depois, nível e preço);
## embaixo, quem mora no cais (com retrato) e o Zarpar. Os atalhos de teclado continuam os mesmos.
var porto_aba := "servicos"
var _porto_abas: Dictionary = {}           # "servicos"/"oficina" -> botão
var _porto_conteudo: Dictionary = {}       # "servicos"/"oficina" -> Control
var _porto_mostr: Dictionary = {}          # "carteira"/"porao"/"tanque"/"casco" -> {valor: Label, barra: Control}
var _porto_linhas: Dictionary = {}         # "peixe"/"diesel"/"casco"/"iscas"/"linha" -> {raiz, sit: Label, botao: Button}
var _porto_cel: Dictionary = {}            # id da melhoria -> {pontos: Label, sit: RichTextLabel, nome: Label}
var _porto_fita: PanelContainer
var _porto_fita_texto: Label
var _porto_linha_abas: HBoxContainer
const COR_OK := Color(0.16, 0.46, 0.34)

func _fio_porto(alfa: float = 0.16) -> Control:
    var r := ColorRect.new()
    r.color = Color(Aq.NANQUIM, alfa)
    r.custom_minimum_size = Vector2(0, 1.5)
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return r

func _mostrador_porto(id: String, legenda: String, com_barra: bool) -> Control:
    var v := VBoxContainer.new()
    v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    v.add_theme_constant_override("separation", -4)
    var a := _nova_label(T.t(legenda).to_upper(), 14, COR_SUAVE)
    a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(a)
    a.set_meta("legenda", legenda)
    var b := _nova_label("", 30, COR_TEXTO, false, true)
    b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    v.add_child(b)
    var barra := Control.new()
    barra.custom_minimum_size = Vector2(0, 10)
    barra.set_meta("fracao", -1.0)
    barra.set_meta("cor", Aq.TURQUESA)
    barra.draw.connect(func():
        var f: float = float(barra.get_meta("fracao"))
        if f < 0.0:
            return
        var w: float = barra.size.x * 0.62
        var x0: float = (barra.size.x - w) * 0.5
        barra.draw_rect(Rect2(x0, 3, w, 5), Color(Aq.NANQUIM, 0.15))
        barra.draw_rect(Rect2(x0, 3, w * clampf(f, 0.0, 1.0), 5), barra.get_meta("cor")))
    v.add_child(barra)
    _porto_mostr[id] = {"valor": b, "barra": barra if com_barra else null, "legenda": a}
    return v

func _barra_porto(id: String, fracao: float, cor: Color) -> void:
    var barra: Control = _porto_mostr[id]["barra"]
    if barra == null:
        return
    barra.set_meta("fracao", fracao)
    barra.set_meta("cor", cor)
    barra.queue_redraw()

func _linha_porto(id: String, nome: String, esquema: String, semente: float, acao: Callable, icone: String = "") -> Control:
    var h := HBoxContainer.new()
    h.custom_minimum_size = Vector2(0, 46)
    h.add_theme_constant_override("separation", 14)
    if icone != "" and ResourceLoader.exists(icone):            # v0.8.7: ícone pintado (aba Noite)
        var ic := TextureRect.new()
        ic.texture = load(icone)
        ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        ic.custom_minimum_size = Vector2(30, 40)
        h.add_child(ic)
    var n := _nova_label(T.t(nome), 26, COR_TITULO, false, true)
    n.custom_minimum_size = Vector2(118 if icone == "" else 96, 0)
    n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _textos.append([n, nome])
    h.add_child(n)
    var sit := _nova_label("", 19, COR_TEXTO)
    sit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    sit.clip_text = true
    h.add_child(sit)
    var cor_txt: Color = Aq.NANQUIM if esquema in ["ouro", "turquesa"] else Aq.CREME
    var b := _botao_aq("", esquema, semente, cor_txt, 18, Vector2(236, 40))
    b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    b.clip_text = true
    b.pressed.connect(acao)
    h.add_child(b)
    _porto_linhas[id] = {"raiz": h, "sit": sit, "botao": b}
    return h

## Ajusta uma linha de serviço: botao_texto vazio = nada a fazer (o botão some e a situação fica verde se ok).
func _porto_situacao(id: String, situacao: String, botao_texto: String, pode: bool, ok: bool = false) -> void:
    var l: Dictionary = _porto_linhas[id]
    (l.sit as Label).text = situacao
    (l.sit as Label).add_theme_color_override("font_color", COR_OK if ok else COR_TEXTO)
    (l.botao as Button).visible = botao_texto != ""
    (l.botao as Button).text = botao_texto
    (l.botao as Button).disabled = not pode

func _celula_oficina(id: String, semente: float) -> Control:
    var h := HBoxContainer.new()
    h.custom_minimum_size = Vector2(0, 62)
    h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_theme_constant_override("separation", 8)
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", -4)
    col.alignment = BoxContainer.ALIGNMENT_CENTER
    var l1 := HBoxContainer.new()
    l1.add_theme_constant_override("separation", 8)
    var nome := _nova_label("", 23, COR_TITULO, false, true)
    l1.add_child(nome)
    var pontos := _nova_label("", 12, COR_SECAO)
    pontos.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l1.add_child(pontos)
    col.add_child(l1)
    var sit := RichTextLabel.new()
    sit.bbcode_enabled = true
    sit.fit_content = true
    sit.scroll_active = false
    sit.autowrap_mode = TextServer.AUTOWRAP_OFF
    sit.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sit.add_theme_font_override("normal_font", Aq.FONTE_TEXTO)
    sit.add_theme_font_override("bold_font", Aq.FONTE_TEXTO)
    sit.add_theme_font_size_override("normal_font_size", 17)
    sit.add_theme_font_size_override("bold_font_size", 17)
    sit.add_theme_color_override("default_color", COR_TEXTO)
    col.add_child(sit)
    h.add_child(col)
    var b := _botao_aq("", "turquesa", semente, Aq.NANQUIM, 17, Vector2(118, 38))
    b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    b.pressed.connect(func(): melhoria_pressed.emit(id))
    h.add_child(b)
    porto_loja[id] = b
    _porto_cel[id] = {"nome": nome, "pontos": pontos, "sit": sit}
    return h

## Troca a tinta de um botão de aquarela já montado (compra possível = turquesa; sem dinheiro = azul-mar apagado).
func _tingir(b: BotaoAq, esquema: String, cor_texto: Color) -> void:
    if b.lavagem == null:
        return
    var esq: Dictionary = Aq.esquema(esquema)
    var m: ShaderMaterial = b.lavagem.material
    m.set_shader_parameter("cor", esq["cor"])
    m.set_shader_parameter("cor2", esq["cor2"])
    for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
        b.add_theme_color_override(c, cor_texto)
    b.add_theme_color_override("font_disabled_color", Color(cor_texto, 0.55))

func _preencher_noite(n: Dictionary) -> void:
    if n.is_empty():
        return
    var dinheiro: int = int(n.get("dinheiro", 0))
    var precos: Dictionary = n.get("precos", {})
    var oleo: float = float(n.get("oleo", 1.0))
    var p_oleo: int = int(n.get("preco_oleo", 0))
    if oleo >= 0.99:
        _porto_situacao("oleo", "✓  " + T.t("Lanterna cheia de óleo"), "", false, true)
    else:
        _porto_situacao("oleo", T.t("Lanterna com %d%% de óleo · acende a noite toda cheia") % roundi(oleo * 100.0),
                T.t("Encher · R$ %d") % p_oleo, dinheiro >= p_oleo)
    if bool(n.get("vela", false)):
        _porto_situacao("vela", "✓  " + T.t("Vela acesa: a próxima noite pesa menos"), "", false, true)
    elif bool(n.get("tem_capela", false)):
        _porto_situacao("vela", T.t("Uma vela na capela, para São Pedro: o medo sobe mais devagar por uma noite"),
                T.t("Acender · R$ %d") % int(precos.get("vela", 5)), dinheiro >= int(precos.get("vela", 5)))
    else:
        _porto_situacao("vela", T.t("Não há capela aqui (Vila do Porto ou São Pedro)"), "", false)
    if bool(n.get("patua", false)):
        _porto_situacao("patua", "✓  " + T.t("Patuá no painel: o medo sobe 25% mais devagar"), "", false, true)
    elif bool(n.get("vende_patua", false)):
        _porto_situacao("patua", T.t("A Maíra faz: protege o barco para sempre"),
                T.t("Comprar · R$ %d") % int(precos.get("patua", 150)), dinheiro >= int(precos.get("patua", 150)))
    else:
        _porto_situacao("patua", T.t("Quem faz patuá é a Maíra, em São Pedro"), "", false)
    if bool(n.get("sino", false)):
        _porto_situacao("sino", "✓  " + T.t("Sino a bordo: [G] espanta os vultos e acalma"), "", false, true)
    elif bool(n.get("vende_sino", false)):
        _porto_situacao("sino", T.t("Sino de bronze: [G] espanta vultos (a cada 90 s)"),
                T.t("Instalar · R$ %d") % int(precos.get("sino", 260)), dinheiro >= int(precos.get("sino", 260)))
    else:
        _porto_situacao("sino", T.t("O sino de bronze se compra na Vila do Porto"), "", false)
    var n_ab: int = int(n.get("aberrantes", 0))
    if bool(n.get("comprador", false)):
        if n_ab > 0:
            _porto_situacao("aberrantes", T.t("O homem da capa está no cais. %d aberrante(s) a bordo") % n_ab,
                    T.t("Vender · R$ %d") % int(n.get("valor_aberrantes", 0)), true)
        else:
            _porto_situacao("aberrantes", T.t("O homem da capa espera no fim do cais. Você não tem o que ele quer."), "", false)
    else:
        _porto_situacao("aberrantes", (T.t("%d aberrante(s) a bordo. ") % n_ab if n_ab > 0 else "") + T.t("Dizem que alguém compra, de noite, na Vila do Porto"), "", false)

func mostrar_aba_porto(nome: String) -> void:
    if nome == "oficina" and not (_porto_abas["oficina"] as Control).visible:
        nome = "servicos"
    porto_aba = nome
    for k in _porto_abas:
        (_porto_abas[k] as BotaoAq).marcar(k == nome)
        (_porto_conteudo[k] as Control).visible = k == nome

func _construir_porto() -> void:
    porto = ColorRect.new()
    porto.color = Color(0.017, 0.061, 0.09, 0.40)
    porto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    porto.mouse_filter = Control.MOUSE_FILTER_STOP
    porto.visible = false
    raiz.add_child(porto)
    var central := CenterContainer.new()
    central.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    porto.add_child(central)
    var cartao := PanelContainer.new()
    cartao.custom_minimum_size = Vector2(760, 0)
    _cartao_papel(cartao, 7.0)
    central.add_child(cartao)
    _encaixar(cartao)
    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 34)
    margem.add_theme_constant_override("margin_right", 34)
    margem.add_theme_constant_override("margin_top", 18)
    margem.add_theme_constant_override("margin_bottom", 22)
    cartao.add_child(margem)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 8)
    margem.add_child(col)
    porto_titulo = _nova_label("Cais", 44, COR_TITULO, false, true)
    col.add_child(porto_titulo)
    # mostradores
    var faixa := HBoxContainer.new()
    faixa.add_theme_constant_override("separation", 0)
    var ids := [["carteira", "Carteira", false], ["porao", "Porão", true], ["tanque", "Tanque", true], ["casco", "Casco", true]]
    for i in ids.size():
        if i > 0:
            var v := ColorRect.new()
            v.color = Color(Aq.NANQUIM, 0.18)
            v.custom_minimum_size = Vector2(1.5, 0)
            faixa.add_child(v)
        faixa.add_child(_mostrador_porto(ids[i][0], ids[i][1], ids[i][2]))
    col.add_child(faixa)
    # fita da encomenda (e do bônus do posto)
    _porto_fita = PanelContainer.new()
    _porto_fita.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
    var eo: Dictionary = Aq.esquema("ouro")
    var ex: Dictionary = eo["extra"].duplicate()
    ex["alfa"] = 0.35
    Aq.fundo(_porto_fita, eo["cor"], eo["cor2"], 3.0, ex, 6.0)
    var fm := MarginContainer.new()
    fm.add_theme_constant_override("margin_left", 14)
    fm.add_theme_constant_override("margin_right", 10)
    fm.add_theme_constant_override("margin_top", 2)
    fm.add_theme_constant_override("margin_bottom", 2)
    _porto_fita.add_child(fm)
    _porto_fita_texto = _nova_label("", 19, COR_TEXTO)
    _porto_fita_texto.clip_text = true
    fm.add_child(_porto_fita_texto)
    col.add_child(_porto_fita)
    # abas
    _porto_linha_abas = HBoxContainer.new()
    _porto_linha_abas.add_theme_constant_override("separation", 10)
    for par in [["servicos", "Serviços"], ["oficina", "Oficina do barco"], ["noite", "Noite"]]:
        var aba: String = par[0]
        var b := _botao_aq(T.t(par[1]), "mar", 50.0 + aba.length(), Aq.CREME, 20, Vector2(210 if aba != "noite" else 150, 40))
        _textos.append([b, par[1]])
        b.pressed.connect(func(): mostrar_aba_porto(aba))
        _porto_abas[aba] = b
        _porto_linha_abas.add_child(b)
    col.add_child(_porto_linha_abas)
    col.add_child(_fio_porto(0.3))
    # aba Serviços
    var servicos := VBoxContainer.new()
    servicos.add_theme_constant_override("separation", 2)
    servicos.custom_minimum_size = Vector2(0, 280)
    servicos.add_child(_linha_porto("peixe", "Peixe", "turquesa", 13.0, func(): vender_pressed.emit()))
    servicos.add_child(_fio_porto())
    servicos.add_child(_linha_porto("diesel", "Diesel", "ouro", 17.0, func(): abastecer_pressed.emit()))
    servicos.add_child(_fio_porto())
    servicos.add_child(_linha_porto("casco", "Casco", "ocre", 25.0, func(): consertar_pressed.emit()))
    servicos.add_child(_fio_porto())
    servicos.add_child(_linha_porto("iscas", "Iscas", "mar", 19.0, func(): comprar_iscas_pressed.emit()))
    var fio_linha := _fio_porto()
    servicos.add_child(fio_linha)
    servicos.add_child(_linha_porto("linha", "Linha", "mar", 23.0, func(): melhorar_linha_pressed.emit()))
    _porto_linhas["linha"]["fio"] = fio_linha
    porto_vender = _porto_linhas["peixe"]["botao"]
    porto_abastecer = _porto_linhas["diesel"]["botao"]
    porto_consertar = _porto_linhas["casco"]["botao"]
    porto_iscas = _porto_linhas["iscas"]["botao"]
    porto_linha = _porto_linhas["linha"]["botao"]
    col.add_child(servicos)
    _porto_conteudo["servicos"] = servicos
    # aba Oficina: esquerda motor, tanque, porão, vara; direita estabilizadores, leme, hélice, radar
    var oficina := VBoxContainer.new()
    oficina.add_theme_constant_override("separation", 2)
    oficina.custom_minimum_size = Vector2(0, 280)
    var grade := GridContainer.new()
    grade.columns = 3
    grade.add_theme_constant_override("h_separation", 14)
    grade.add_theme_constant_override("v_separation", 0)
    oficina.add_child(grade)
    var ordem := ["motor", "tanque", "porao", "vara", "casco", "leme", "helice", "radar"]
    for i in ordem.size():
        var id: String = ordem[(i % 2) * 4 + i / 2]
        if i % 2 == 1:
            var v := ColorRect.new()
            v.color = Color(Aq.NANQUIM, 0.14)
            v.custom_minimum_size = Vector2(1.5, 0)
            grade.add_child(v)
        grade.add_child(_celula_oficina(id, 30.0 + i * 3.7))
    var nota := _nova_label(T.t("● comprado · ○ por comprar · atalho: a tecla entre colchetes"), 15, COR_SUAVE)
    nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    oficina.add_child(nota)
    col.add_child(oficina)
    _porto_conteudo["oficina"] = oficina
    # v0.8.7: aba Noite — o que protege do medo, e o homem da capa
    var noite := VBoxContainer.new()
    noite.add_theme_constant_override("separation", 2)
    noite.custom_minimum_size = Vector2(0, 280)
    var DIR_IC := "res://assets/texturas/bruma/icone_%s.png"
    noite.add_child(_linha_porto("oleo", "Óleo", "ouro", 61.0, func(): noite_pressed.emit("oleo"), DIR_IC % "oleo"))
    noite.add_child(_fio_porto())
    noite.add_child(_linha_porto("vela", "Vela", "ocre", 63.0, func(): noite_pressed.emit("vela"), DIR_IC % "vela"))
    noite.add_child(_fio_porto())
    noite.add_child(_linha_porto("patua", "Patuá", "terracota", 65.0, func(): noite_pressed.emit("patua"), DIR_IC % "patua"))
    noite.add_child(_fio_porto())
    noite.add_child(_linha_porto("sino", "Sino", "ouro", 67.0, func(): noite_pressed.emit("sino"), DIR_IC % "sino"))
    noite.add_child(_fio_porto())
    noite.add_child(_linha_porto("aberrantes", "Aberrantes", "turquesa", 69.0, func(): noite_pressed.emit("aberrantes")))
    col.add_child(noite)
    _porto_conteudo["noite"] = noite
    porto_rotulo_loja = _nova_label("", 1, COR_SECAO)      # compatibilidade (o título da loja virou a aba)
    porto_rotulo_loja.visible = false
    col.add_child(_fio_porto(0.3))
    # rodapé: moradores do cais + zarpar
    var pe := HBoxContainer.new()
    pe.add_theme_constant_override("separation", 12)
    porto_npcs = HBoxContainer.new()
    porto_npcs.add_theme_constant_override("separation", 12)
    porto_npcs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pe.add_child(porto_npcs)
    porto_sair = _botao_aq(T.t("Zarpar   [F]"), "terracota", 41.0, Aq.CREME, 24, Vector2(210, 52))
    porto_sair.pressed.connect(func(): zarpar_pressed.emit())
    pe.add_child(porto_sair)
    col.add_child(pe)
    mostrar_aba_porto("servicos")

## Abre (ou atualiza) o painel do cais. dados: nome, dinheiro, peixes, peso, valor, falta_litros, preco_litro, litros_possiveis...
func mostrar_porto(d: Dictionary) -> void:
    var abrindo: bool = not porto.visible
    _ultimo_porto = d
    porto.visible = true
    _atualizar_npcs_do_porto(d.get("npcs", []))
    porto_titulo.text = T.t("Cais de %s") % T.t(String(d.nome))
    var saude: float = float(d.get("saude", 100.0))
    # mostradores
    for k in _porto_mostr:
        var lg: Label = _porto_mostr[k]["legenda"]
        lg.text = T.t(String(lg.get_meta("legenda"))).to_upper()
    (_porto_mostr["carteira"]["valor"] as Label).text = "R$ %d" % int(d.dinheiro)
    (_porto_mostr["porao"]["valor"] as Label).text = (T.t("%d peixes") % int(d.peixes)) if int(d.peixes) != 1 else T.t("1 peixe")
    _barra_porto("porao", float(d.get("ocupado", 0.0)), Aq.OCRE)
    (_porto_mostr["tanque"]["valor"] as Label).text = "%d / %d L" % [roundi(d.litros), roundi(d.tanque)]
    _barra_porto("tanque", float(d.litros) / maxf(1.0, float(d.tanque)), Aq.OURO)
    (_porto_mostr["casco"]["valor"] as Label).text = "%d%%" % floori(saude)
    _barra_porto("casco", saude / 100.0, Aq.VERDE if saude > 60.0 else Aq.TERRACOTA)
    var fita: String = String(d.get("contrato", ""))
    var nota: String = String(d.get("nota", "")).strip_edges()
    if nota != "":
        fita = (fita + "   ·   " + nota) if fita != "" else nota
    _porto_fita.visible = fita != ""
    _porto_fita_texto.text = fita
    # Serviços
    var n_ab: int = int(d.get("noite", {}).get("aberrantes", 0))
    var comuns: int = int(d.peixes) - n_ab
    if comuns > 0:
        _porto_situacao("peixe", T.t("%d peixe(s) · %s kg") % [comuns, ("%.1f" % d.peso).replace(".", ",")] + ((T.t("  ·  %d aberrante(s) ficam") % n_ab) if n_ab > 0 else ""),
                T.t("Vender por R$ %d   [1]") % int(d.valor), true)
    elif n_ab > 0:
        _porto_situacao("peixe", T.t("Só aberrantes a bordo: ninguém daqui compra (aba Noite)"), "", false)
    else:
        _porto_situacao("peixe", T.t("Porão vazio"), "", false)
    if d.falta_litros < 1.0:
        _porto_situacao("diesel", "✓  " + T.t("Tanque cheio"), "", false, true)
    elif d.litros_possiveis < 1.0:
        _porto_situacao("diesel", T.t("faltam %d L · R$ %d o litro") % [roundi(d.falta_litros), int(d.preco_litro)], T.t("Sem dinheiro"), false)
    else:
        var tudo: bool = d.litros_possiveis >= d.falta_litros - 0.5
        _porto_situacao("diesel", T.t("faltam %d L · R$ %d o litro") % [roundi(d.falta_litros), int(d.preco_litro)],
                (T.t("Encher · R$ %d   [2]") % roundi(d.litros_possiveis * d.preco_litro)) if tudo else (T.t("Pôr %d L · R$ %d   [2]") % [roundi(d.litros_possiveis), roundi(d.litros_possiveis * d.preco_litro)]), true)
    var preco_ponto: int = int(d.get("preco_reparo", 3))
    var falta: float = ceilf(100.0 - saude - 0.001)
    var pontos_possiveis: float = minf(falta, floorf(float(d.dinheiro) / float(preco_ponto)))
    if falta < 1.0:
        _porto_situacao("casco", "✓  " + T.t("Em ordem"), "", false, true)
    elif pontos_possiveis < 1.0:
        _porto_situacao("casco", T.t("%d%% → 100%% · R$ %d por ponto") % [floori(saude), preco_ponto], T.t("Sem dinheiro"), false)
    else:
        _porto_situacao("casco", T.t("%d%% → %d%% · R$ %d por ponto") % [floori(saude), mini(100, floori(saude + pontos_possiveis + 0.001)), preco_ponto],
                T.t("Consertar · R$ %d   [R]") % (roundi(pontos_possiveis) * preco_ponto), true)
    _porto_situacao("iscas", String(d.get("iscas", "")) + "   " + T.t("(veja o livro, TAB)"),
            T.t("Kit · R$ 25   [Q]"), bool(d.get("pode_comprar_iscas", false)))
    var tem_oficina: bool = bool(d.get("tem_oficina", false))
    (_porto_linhas["linha"]["raiz"] as Control).visible = tem_oficina
    (_porto_linhas["linha"]["fio"] as Control).visible = tem_oficina
    var preco_linha: int = int(d.get("preco_linha", -1))
    if preco_linha < 0:
        _porto_situacao("linha", "✓  " + T.t("Linha reforçada (máximo)"), "", false, true)
    else:
        _porto_situacao("linha", T.t("nível %d de 4 · aguenta peixe maior") % (int(d.get("nivel_linha", 0)) + 1),
                T.t("Reforçar · R$ %d   [U]") % preco_linha, int(d.dinheiro) >= preco_linha)
    # Oficina
    var loja: Array = d.get("loja", [])
    (_porto_abas["oficina"] as Control).visible = not loja.is_empty()
    _preencher_noite(d.get("noite", {}))
    for linha in loja:
        var b: Button = porto_loja.get(linha.id)
        var cel: Dictionary = _porto_cel.get(linha.id, {})
        if b == null or cel.is_empty():
            continue
        (cel.nome as Label).text = String(linha.get("nome", linha.id))
        var n: int = int(linha.get("nivel", 0))
        var total: int = int(linha.get("total", 3))
        (cel.pontos as Label).text = "●".repeat(n + 1) + "○".repeat(maxi(0, total - n - 1))
        var preco: int = int(linha.get("preco", -1))
        if bool(linha.get("trancado", false)):
            (cel.sit as RichTextLabel).text = "[b]%s[/b] · [color=#5a6473]%s[/color]" % [linha.agora, T.t("30 nós depois de São Pedro")]
            b.text = T.t("trancado")
        elif preco < 0:
            (cel.sit as RichTextLabel).text = "[b]%s[/b] · [color=#2a7556]%s[/color]" % [linha.agora, T.t("máximo")]
            b.text = "✓"
        else:
            (cel.sit as RichTextLabel).text = "[color=#5a6473]%s[/color]  →  [b]%s[/b]" % [linha.agora, linha.depois]
            b.text = "R$ %d  [%d]" % [preco, int(linha.tecla)]
        b.tooltip_text = String(linha.get("texto", ""))
        b.disabled = not bool(linha.pode)
        if bool(linha.pode):
            _tingir(b as BotaoAq, "turquesa", Aq.NANQUIM)
        else:
            _tingir(b as BotaoAq, "mar", Aq.CREME)
        b.visible = true
    if abrindo:
        mostrar_aba_porto("servicos")
    elif loja.is_empty() and porto_aba == "oficina":
        mostrar_aba_porto("servicos")

func esconder_porto() -> void:
    porto.visible = false

## v0.6.0: a conversa com os NPCs do cais.
func abrir_dialogo(falas: Array) -> void:
    dialogo.abrir(falas)

func dialogo_ativo() -> bool:
    return dialogo != null and (dialogo.ativo or dialogo.visible)

func _atualizar_npcs_do_porto(lista: Array) -> void:
    for b in _botoes_npc:
        b.visible = false
    for i in lista.size():
        if i >= _botoes_npc.size():
            var novo := _botao_aq("", "ocre", 70.0 + i * 3.1, Aq.CREME, 17, Vector2(176, 52))    # v0.8.4: com o retrato
            novo.expand_icon = true
            novo.add_theme_constant_override("icon_max_width", 40)
            novo.clip_text = true
            porto_npcs.add_child(novo)
            _botoes_npc.append(novo)
        var b: Button = _botoes_npc[i]
        var id: String = lista[i]
        for conexao in b.pressed.get_connections():
            b.pressed.disconnect(conexao.callable)
        b.pressed.connect(func(): conversar_pressed.emit(id))
        b.text = " " + T.t(Npcs.DADOS[id].nome) + ("  [T]" if i == 0 else "")
        b.icon = Npcs.retrato(id)
        b.tooltip_text = T.t("Conversar com %s") % T.t(Npcs.DADOS[id].nome)
        b.visible = true
    porto_npcs.visible = not lista.is_empty()

## Volumes: um controle por canal (scripts/som.gd aplica e guarda) e o botão de silenciar.
const NOMES_VOLUME := {"geral": "Geral", "musica": "Música", "mar": "Mar e ondas", "vento": "Vento", "chuva": "Chuva e trovões", "barco": "Motor e casco", "efeitos": "Efeitos"}
func _construir_volume(col: VBoxContainer) -> void:
    var grade := GridContainer.new()
    grade.columns = 3
    grade.add_theme_constant_override("h_separation", 14)
    grade.add_theme_constant_override("v_separation", 8)
    col.add_child(grade)
    for grupo in ["geral", "musica", "mar", "vento", "chuva", "barco", "efeitos"]:
        var rotulo := _nova_label(T.t(NOMES_VOLUME[grupo]), 21, COR_TEXTO)
        rotulo.custom_minimum_size = Vector2(170, 0)
        grade.add_child(rotulo)
        var barra := DeslizanteAq.new()
        barra.min_value = 0.0
        barra.max_value = 100.0
        barra.step = 5.0
        barra.value = 80.0
        barra.custom_minimum_size = Vector2(220, 30)
        barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        grade.add_child(barra)
        var valor := _nova_label("80%", 21, COR_TITULO)
        valor.custom_minimum_size = Vector2(56, 0)
        valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        grade.add_child(valor)
        controles_volume[grupo] = {"barra": barra, "valor": valor, "rotulo": rotulo}
        barra.value_changed.connect(func(v: float):
            valor.text = "%d%%" % roundi(v)
            volume_mudou.emit(grupo, v / 100.0))
    botao_mudo = _botao_aq(T.t("Silenciar tudo"), "mar", 17.0, Aq.CREME, 19, Vector2(440, 40))
    botao_mudo.pressed.connect(func(): mudo_pressed.emit())
    col.add_child(botao_mudo)

## Põe os controles nos valores guardados (0 a 1), sem disparar o sinal de mudança.
func mostrar_volumes(volumes: Dictionary, mudo: bool) -> void:
    _mudo = mudo
    for grupo in controles_volume:
        if volumes.has(grupo):
            var c: Dictionary = controles_volume[grupo]
            c.barra.set_value_no_signal(float(volumes[grupo]) * 100.0)
            c.valor.text = "%d%%" % roundi(float(volumes[grupo]) * 100.0)
    botao_mudo.text = T.t("Som desligado — ligar") if mudo else T.t("Silenciar tudo")
    botao_mudo.marcar(mudo)

func _clicar_iniciar() -> void:
    iniciar_pressed.emit()

## Novo jogo apaga a viagem salva: com algo a perder, o primeiro clique só pede confirmação.
func _clicar_reiniciar() -> void:
    var agora := Time.get_ticks_msec() / 1000.0
    if (_tem_salva or _pausa) and agora - _confirmar_novo > 4.0:
        _confirmar_novo = agora
        botao_reiniciar.text = T.t("CONFIRMAR: APAGAR A VIAGEM SALVA?")
        botao_reiniciar.marcar(true)
        get_tree().create_timer(4.0).timeout.connect(func():
            if botao_reiniciar.marcado:
                botao_reiniciar.marcar(false)
                _atualizar_cabecalho())
        return
    botao_reiniciar.marcar(false)
    _confirmar_novo = -100.0
    reiniciar_pressed.emit()

func mostrar_inicio(tem_viagem_salva: bool = false) -> void:
    _pausa = false
    _tem_salva = tem_viagem_salva
    no_titulo = true
    menu.visible = false
    pagina_atual = "principal"
    tela_inicial.mostrar(tem_viagem_salva)

## Saindo da tela inicial (o jogo começou): some com ela, a não ser que a cortina ainda esteja fechando.
func fechar_titulo() -> void:
    no_titulo = false
    if tela_inicial != null and not tela_inicial.em_transicao:
        tela_inicial.visible = false

func mostrar_pausa() -> void:
    _pausa = true
    _tem_salva = true
    menu.visible = true
    _ir_para("principal")

func _process(_delta: float) -> void:
    if _voltar_do_avancado and graficos != null and not graficos.cinema.esta_aberto():
        _voltar_do_avancado = false
        menu.visible = true
        _ir_para("graficos")

func esconder_menu() -> void:
    _voltar_do_avancado = false
    menu.visible = false
    botao_reiniciar.marcar(false)

func aviso(texto: String) -> void:
    hud.aviso_texto = texto
    hud.aviso_tempo = 6.0
    diario.append(texto)
    if diario.size() > 40:
        diario.pop_front()
    if hud.painel_aberto == "diario":
        _preencher_painel()

func limpar_partida() -> void:
    diario.clear()
    hud.painel_aberto = ""
    if mapa_aberto():
        mapa.fechar()

func atualizar(nos: float, rumo: int, distancia: float, peixes: int, peso: float, pesca_status: String, venceu: bool, fracao_motor: float = 0.0, pesca_ativa: bool = false) -> void:
    _peso = peso
    hud.nos = nos
    hud.rumo = float(rumo)
    hud.distancia = distancia
    hud.fracao_motor = fracao_motor
    hud.estado_pesca = pesca_status
    hud.pesca_ativa = pesca_ativa
    hud.visible = not menu.visible and not esconder_hud and not mapa_aberto() and not (tela_inicial != null and tela_inicial.visible) and not dialogo_ativo() and not final_ativo and not caderno_aberto()
    if hud.painel_aberto != "":
        _preencher_painel()
