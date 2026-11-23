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

func caderno_aberto() -> bool:
    return caderno != null and caderno.aberto()

func mapa_aberto() -> bool:
    return mapa != null and mapa.has_method("aberto") and mapa.aberto()

func _ao_apertar_botao(nome: String) -> void:
    match nome:
        "pescar":
            pescar_pressed.emit()
        "porao", "diario":
            alternar_painel(nome)
        "caderno":
            alternar_caderno()

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
    _t(atalhos, "W A S D  navegar   •   ESPAÇO  frear\nF  pescar e atracar no cais   •   I  inventário (porão)\nTAB  diário de bordo   •   M  carta náutica   •   ESC  menu")
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
    if porto_rotulo_loja != null:
        porto_rotulo_loja.text = T.t("MELHORIAS DO BARCO")
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
    var lig := T.t("ligado")
    var des := T.t("desligado")
    _botao_auto.text = T.t("Ajuste automático (abaixa a qualidade se travar)") + ": " + (lig if graficos.automatica else des)
    _botao_auto.marcar(graficos.automatica)
    _botao_vsync.text = "V-Sync: " + (lig if graficos.vsync else des)
    _botao_vsync.marcar(graficos.vsync)
    _botao_fps_tela.text = T.t("Mostrar FPS (F3)") + ": " + (lig if graficos.mostrar_fps else des)
    _botao_fps_tela.marcar(graficos.mostrar_fps)

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
    cartao.custom_minimum_size = Vector2(700, 0)
    _cartao_papel(cartao, 7.0)
    central.add_child(cartao)
    _encaixar(cartao)
    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 30)
    margem.add_theme_constant_override("margin_right", 30)
    margem.add_theme_constant_override("margin_top", 20)
    margem.add_theme_constant_override("margin_bottom", 22)
    cartao.add_child(margem)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 5)
    margem.add_child(col)
    porto_titulo = _nova_label("Cais", 46, COR_TITULO, false, true)
    col.add_child(porto_titulo)
    col.add_child(_ornamento(10.0))
    porto_texto = _nova_label("", 18, COR_TEXTO, true)
    col.add_child(porto_texto)
    # Vender e Abastecer lado a lado; iscas e linha também: o painel inteiro cabe nos 720 px da janela.
    var fila_a := HBoxContainer.new()
    fila_a.add_theme_constant_override("separation", 10)
    col.add_child(fila_a)
    porto_vender = _botao_aq("Vender", "turquesa", 13.0, Aq.NANQUIM, 21, Vector2(300, 44))
    porto_vender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    porto_vender.pressed.connect(func(): vender_pressed.emit())
    fila_a.add_child(porto_vender)
    porto_abastecer = _botao_aq("Abastecer", "ouro", 17.0, Aq.NANQUIM, 21, Vector2(300, 44))
    porto_abastecer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    porto_abastecer.pressed.connect(func(): abastecer_pressed.emit())
    fila_a.add_child(porto_abastecer)
    var fila_b := HBoxContainer.new()
    fila_b.add_theme_constant_override("separation", 10)
    col.add_child(fila_b)
    porto_iscas = _botao_aq("Comprar iscas [Q]", "mar", 19.0, Aq.CREME, 17, Vector2(300, 38))
    porto_iscas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    porto_iscas.clip_text = true
    porto_iscas.pressed.connect(func(): comprar_iscas_pressed.emit())
    fila_b.add_child(porto_iscas)
    porto_linha = _botao_aq("Reforçar linha [U]", "mar", 23.0, Aq.CREME, 17, Vector2(300, 38))
    porto_linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    porto_linha.clip_text = true
    porto_linha.pressed.connect(func(): melhorar_linha_pressed.emit())
    fila_b.add_child(porto_linha)
    porto_consertar = _botao_aq("", "ocre", 25.0, Aq.CREME, 19, Vector2(600, 40))
    porto_consertar.clip_text = true
    porto_consertar.pressed.connect(func(): consertar_pressed.emit())
    col.add_child(porto_consertar)
    porto_rotulo_loja = _nova_label(T.t("MELHORIAS DO BARCO"), 20, COR_SECAO, false, true)
    col.add_child(porto_rotulo_loja)
    var grade_oficina := GridContainer.new()
    grade_oficina.columns = 2
    grade_oficina.add_theme_constant_override("h_separation", 10)
    grade_oficina.add_theme_constant_override("v_separation", 7)
    col.add_child(grade_oficina)
    var n_loja: float = 0.0
    for id in ["motor", "tanque", "porao", "vara", "casco", "leme", "helice", "radar"]:
        n_loja += 1.0
        var b := _botao_aq(id, "mar", 30.0 + n_loja * 3.7, Aq.CREME, 17, Vector2(300, 50))    # duas linhas: nome da melhoria e "antes -> depois · preço"
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.clip_text = true
        b.pressed.connect(func(): melhoria_pressed.emit(id))
        grade_oficina.add_child(b)
        porto_loja[id] = b
    porto_npcs = HBoxContainer.new()
    porto_npcs.add_theme_constant_override("separation", 10)
    porto_npcs.visible = false
    col.add_child(porto_npcs)
    porto_sair = _botao_aq(T.t("Zarpar   [F]"), "terracota", 41.0, Aq.CREME, 22, Vector2(300, 44))
    porto_sair.pressed.connect(func(): zarpar_pressed.emit())
    col.add_child(porto_sair)

## Abre (ou atualiza) o painel do cais. dados: nome, dinheiro, peixes, peso, valor, falta_litros, preco_litro, litros_possiveis
func mostrar_porto(d: Dictionary) -> void:
    _ultimo_porto = d
    porto.visible = true
    _atualizar_npcs_do_porto(d.get("npcs", []))
    porto_titulo.text = T.t("Cais de %s") % T.t(String(d.nome))
    porto_rotulo_loja.visible = not d.get("loja", []).is_empty()
    for id in porto_loja:
        porto_loja[id].visible = porto_rotulo_loja.visible
    var saude: float = float(d.get("saude", 100.0))
    porto_texto.text = T.t("Carteira: R$ %d   ·   Porão: %d peixe(s), %s kg   ·   Tanque: %d de %d L   ·   Casco: %d%%") % [d.dinheiro, d.peixes,
            ("%.1f" % d.peso).replace(".", ","), roundi(d.litros), roundi(d.tanque), floori(saude)] + "\n%s%s" % [d.get("contrato", ""), d.get("nota", "")]
    porto_iscas.text = T.t("Iscas: %s · kit R$ 25 [Q]") % d.get("iscas", "")
    porto_iscas.disabled = not bool(d.get("pode_comprar_iscas", false))
    var preco_linha: int = int(d.get("preco_linha", -1))
    porto_linha.visible = bool(d.get("tem_oficina", false))
    porto_linha.disabled = preco_linha < 0 or int(d.dinheiro) < preco_linha
    porto_linha.text = T.t("Linha reforçada (máximo)") if preco_linha < 0 else T.t("Reforçar linha [U] · nível %d/4 · R$ %d") % [int(d.get("nivel_linha", 0)) + 1, preco_linha]
    porto_vender.text = T.t("Vender tudo por R$ %d  [1]") % d.valor if d.peixes > 0 else T.t("Nada para vender")
    porto_vender.disabled = d.peixes == 0
    # conserto do casco: R$ por ponto; se o dinheiro não der, conserta o que der
    var preco_ponto: int = int(d.get("preco_reparo", 3))
    var falta: float = ceilf(100.0 - saude - 0.001)
    var pontos_possiveis: float = minf(falta, floorf(float(d.dinheiro) / float(preco_ponto)))
    if falta < 1.0:
        porto_consertar.text = T.t("Casco em ordem (100%)")
        porto_consertar.disabled = true
    elif pontos_possiveis < 1.0:
        porto_consertar.text = T.t("Conserto do casco: R$ %d por ponto — sem dinheiro") % preco_ponto
        porto_consertar.disabled = true
    else:
        porto_consertar.text = T.t("Consertar casco: %d%% → %d%% · R$ %d  [R]") % [floori(saude), mini(100, floori(saude + pontos_possiveis + 0.001)), roundi(pontos_possiveis) * preco_ponto]
        porto_consertar.disabled = false
    if d.falta_litros < 1.0:
        porto_abastecer.text = T.t("Tanque cheio")
        porto_abastecer.disabled = true
    elif d.litros_possiveis < 1.0:
        porto_abastecer.text = T.t("Diesel R$ %d/L — sem dinheiro") % d.preco_litro
        porto_abastecer.disabled = true
    else:
        porto_abastecer.text = T.t("Abastecer %d L · R$ %d  [2]") % [roundi(d.litros_possiveis), roundi(d.litros_possiveis * d.preco_litro)]
        porto_abastecer.disabled = false
    for linha in d.get("loja", []):
        var b: Button = porto_loja.get(linha.id)
        if b != null:
            b.text = linha.texto
            b.tooltip_text = linha.texto
            b.disabled = not linha.pode

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
            var novo := _botao_aq("", "ocre", 70.0 + i * 3.1, Aq.CREME, 17, Vector2(300, 38))
            novo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            novo.clip_text = true
            porto_npcs.add_child(novo)
            _botoes_npc.append(novo)
        var b: Button = _botoes_npc[i]
        var id: String = lista[i]
        for conexao in b.pressed.get_connections():
            b.pressed.disconnect(conexao.callable)
        b.pressed.connect(func(): conversar_pressed.emit(id))
        b.text = T.t("Conversar com %s") % T.t(Npcs.DADOS[id].nome) + ("  [T]" if i == 0 else "")
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
