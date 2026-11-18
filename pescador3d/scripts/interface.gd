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

const HudPintado = preload("res://scripts/hud.gd")
const CartaMapa = preload("res://scripts/mapa_cartografico.gd")
const Aq = preload("res://scripts/aquarela.gd")
const BotaoAq = preload("res://scripts/botao_aquarela.gd")
const DeslizanteAq = preload("res://scripts/deslizante_aquarela.gd")
const VEU = preload("res://shaders/veu_aquarela.gdshader")

var raiz: Control
var menu: ColorRect
var titulo_menu: Label
var subtitulo_menu: Label
var botao_principal: Button
var botao_reiniciar: Button
var hud: Control
var mapa: Control
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

const COR_TEXTO := Aq.NANQUIM                       # tinta dos textos sobre o papel
const COR_SECAO := Color(0.08, 0.40, 0.42)         # títulos de seção: verde-azulado
const COR_TITULO := Color(0.58, 0.24, 0.15)        # terracota: nomes e títulos
const COR_SUAVE := Aq.NANQUIM_CLARO

func _ready() -> void:
    raiz = Control.new()
    raiz.name = "InterfaceRaiz"
    raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(raiz)
    _construir_hud()
    _construir_mapa()
    _construir_porto()
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
func _encaixar(cartao: Control) -> void:
    var ajustar := func():
        if not cartao.is_inside_tree() or cartao.size.y < 1.0:
            return
        var area := cartao.get_viewport_rect().size
        var f := minf(1.0, minf((area.y - 20.0) / cartao.size.y, (area.x - 20.0) / cartao.size.x))
        cartao.pivot_offset = cartao.size * 0.5
        cartao.scale = Vector2(f, f)
    cartao.resized.connect(ajustar)
    cartao.visibility_changed.connect(ajustar)
    ajustar.call_deferred()

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

func mapa_aberto() -> bool:
    return mapa != null and mapa.has_method("aberto") and mapa.aberto()

func _ao_apertar_botao(nome: String) -> void:
    match nome:
        "pescar":
            pescar_pressed.emit()
        "config":
            pausa_pressed.emit()
        "porao", "diario":
            alternar_painel(nome)

## Abre ou fecha o painel do porão (peixes pescados) ou do diário (últimas mensagens).
func alternar_painel(nome: String) -> void:
    hud.soltar_peixe()
    hud.painel_aberto = "" if hud.painel_aberto == nome else nome
    _preencher_painel()

func fechar_painel() -> bool:
    var estava: bool = hud.painel_aberto != "" or mapa_aberto()
    hud.soltar_peixe()
    hud.painel_aberto = ""
    if mapa_aberto():
        mapa.fechar()
    return estava

func _preencher_painel() -> void:
    if hud.painel_aberto == "porao":
        hud.titulo_painel = "Porão"                           # a grade é desenhada por scripts/hud.gd
    elif hud.painel_aberto == "diario":
        hud.titulo_painel = "Diário de bordo"
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
    cartao.custom_minimum_size = Vector2(580, 0)
    _cartao_papel(cartao, 3.0)
    central.add_child(cartao)
    _encaixar(cartao)

    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 46)
    margem.add_theme_constant_override("margin_right", 46)
    margem.add_theme_constant_override("margin_top", 18)
    margem.add_theme_constant_override("margin_bottom", 22)
    cartao.add_child(margem)

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 6)
    margem.add_child(col)

    titulo_menu = _nova_label("PESCADOR", 78, Color(0.10, 0.27, 0.36), false, true)
    titulo_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(titulo_menu)
    col.add_child(_ornamento(14.0))

    subtitulo_menu = _nova_label("Uma aventura de pesca no Atlântico brasileiro.\nAssuma o comando do PE-3476.", 23, COR_TEXTO, true)
    subtitulo_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(subtitulo_menu)

    botao_principal = _botao_aq("COMEÇAR A VIAGEM", "turquesa", 5.0, Aq.NANQUIM, 28, Vector2(430, 52))
    botao_principal.pressed.connect(_clicar_iniciar)
    col.add_child(botao_principal)

    botao_reiniciar = _botao_aq("REINICIAR PARTIDA", "mar", 8.0, Aq.CREME, 21, Vector2(430, 40))
    botao_reiniciar.pressed.connect(_clicar_reiniciar)
    col.add_child(botao_reiniciar)

    var botao_construtor := _botao_aq("MODO CONSTRUTOR  (Tab)", "ocre", 11.0, Aq.CREME, 21, Vector2(430, 40))
    botao_construtor.pressed.connect(func(): construtor_pressed.emit())
    col.add_child(botao_construtor)

    _construir_volume(col)

    col.add_child(_ornamento(12.0, Color(Aq.NANQUIM, 0.35)))
    var dica := _nova_label("WASD navegar  •  ESPAÇO frear  •  F pescar  •  E atracar\nMouse direito: câmera  •  Roda: aproxima  •  V: recentra\nB isca  •  N profundidade  •  J técnica  •  M mapa\nK clima  •  L luz  •  F3 FPS  •  F4 diagnóstico  •  F10 gráficos  •  TAB construtor", 17, COR_SUAVE, true)
    dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(dica)

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
    porto_rotulo_loja = _nova_label("MELHORIAS DO BARCO", 20, COR_SECAO, false, true)
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
    var sair := _botao_aq("Zarpar   [E]", "terracota", 41.0, Aq.CREME, 22, Vector2(300, 44))
    sair.pressed.connect(func(): zarpar_pressed.emit())
    col.add_child(sair)

## Abre (ou atualiza) o painel do cais. dados: nome, dinheiro, peixes, peso, valor, falta_litros, preco_litro, litros_possiveis
func mostrar_porto(d: Dictionary) -> void:
    porto.visible = true
    porto_titulo.text = "Cais de %s" % d.nome
    porto_rotulo_loja.visible = not d.get("loja", []).is_empty()
    for id in porto_loja:
        porto_loja[id].visible = porto_rotulo_loja.visible
    porto_texto.text = "Carteira: R$ %d   ·   Porão: %d peixe(s), %s kg   ·   Tanque: %d de %d L\n%s%s" % [d.dinheiro, d.peixes,
            ("%.1f" % d.peso).replace(".", ","), roundi(d.litros), roundi(d.tanque), d.get("contrato", ""), d.get("nota", "")]
    porto_iscas.text = "Iscas: %s · kit R$ 25 [Q]" % d.get("iscas", "")
    porto_iscas.disabled = not bool(d.get("pode_comprar_iscas", false))
    var preco_linha: int = int(d.get("preco_linha", -1))
    porto_linha.visible = bool(d.get("tem_oficina", false))
    porto_linha.disabled = preco_linha < 0 or int(d.dinheiro) < preco_linha
    porto_linha.text = "Linha reforçada (máximo)" if preco_linha < 0 else "Reforçar linha [U] · nível %d/4 · R$ %d" % [int(d.get("nivel_linha", 0)) + 1, preco_linha]
    porto_vender.text = "Vender tudo por R$ %d  [1]" % d.valor if d.peixes > 0 else "Nada para vender"
    porto_vender.disabled = d.peixes == 0
    if d.falta_litros < 1.0:
        porto_abastecer.text = "Tanque cheio"
        porto_abastecer.disabled = true
    elif d.litros_possiveis < 1.0:
        porto_abastecer.text = "Diesel R$ %d/L — sem dinheiro" % d.preco_litro
        porto_abastecer.disabled = true
    else:
        porto_abastecer.text = "Abastecer %d L · R$ %d  [2]" % [roundi(d.litros_possiveis), roundi(d.litros_possiveis * d.preco_litro)]
        porto_abastecer.disabled = false
    for linha in d.get("loja", []):
        var b: Button = porto_loja.get(linha.id)
        if b != null:
            b.text = linha.texto
            b.tooltip_text = linha.texto
            b.disabled = not linha.pode

func esconder_porto() -> void:
    porto.visible = false

## Menu de volume: quatro controles deslizantes e o botão de silenciar. Quem aplica é scripts/som.gd.
func _construir_volume(col: VBoxContainer) -> void:
    var titulo := _nova_label("SOM", 24, COR_SECAO, false, true)
    col.add_child(titulo)
    var grade := GridContainer.new()
    grade.columns = 3
    grade.add_theme_constant_override("h_separation", 14)
    grade.add_theme_constant_override("v_separation", 4)
    col.add_child(grade)
    var nomes := {"geral": "Geral", "ambiente": "Mar e vento", "barco": "Motor e casco", "efeitos": "Efeitos"}
    for grupo in ["geral", "ambiente", "barco", "efeitos"]:
        var rotulo := _nova_label(nomes[grupo], 19, COR_TEXTO)
        rotulo.custom_minimum_size = Vector2(140, 0)
        grade.add_child(rotulo)
        var barra := DeslizanteAq.new()
        barra.min_value = 0.0
        barra.max_value = 100.0
        barra.step = 5.0
        barra.value = 80.0
        barra.custom_minimum_size = Vector2(220, 26)
        barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        grade.add_child(barra)
        var valor := _nova_label("80%", 19, COR_TITULO)
        valor.custom_minimum_size = Vector2(52, 0)
        valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        grade.add_child(valor)
        controles_volume[grupo] = {"barra": barra, "valor": valor}
        barra.value_changed.connect(func(v: float):
            valor.text = "%d%%" % roundi(v)
            volume_mudou.emit(grupo, v / 100.0))
    botao_mudo = _botao_aq("Silenciar tudo", "mar", 17.0, Aq.CREME, 17, Vector2(430, 36))
    botao_mudo.pressed.connect(func(): mudo_pressed.emit())
    col.add_child(botao_mudo)

## Põe os controles nos valores guardados (0 a 1), sem disparar o sinal de mudança.
func mostrar_volumes(volumes: Dictionary, mudo: bool) -> void:
    for grupo in controles_volume:
        if volumes.has(grupo):
            var c: Dictionary = controles_volume[grupo]
            c.barra.set_value_no_signal(float(volumes[grupo]) * 100.0)
            c.valor.text = "%d%%" % roundi(float(volumes[grupo]) * 100.0)
    botao_mudo.text = "Som desligado — ligar" if mudo else "Silenciar tudo"

func _clicar_iniciar() -> void:
    iniciar_pressed.emit()

func _clicar_reiniciar() -> void:
    reiniciar_pressed.emit()

func mostrar_inicio(tem_viagem_salva: bool = false) -> void:
    titulo_menu.text = "PESCADOR"
    subtitulo_menu.text = "Uma aventura de pesca no Atlântico brasileiro.\nAssuma o comando do PE-3476."
    botao_principal.text = "CONTINUAR A VIAGEM" if tem_viagem_salva else "COMEÇAR A VIAGEM"
    botao_reiniciar.text = "NOVA VIAGEM (apaga a salva)" if tem_viagem_salva else "REINICIAR PARTIDA"
    menu.visible = true

func mostrar_pausa() -> void:
    titulo_menu.text = "PAUSA"
    subtitulo_menu.text = "O oceano continua esperando por você."
    botao_principal.text = "RETOMAR VIAGEM"
    botao_reiniciar.text = "REINICIAR PARTIDA (apaga a salva)"
    menu.visible = true

func esconder_menu() -> void:
    menu.visible = false

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
    hud.visible = not menu.visible and not esconder_hud and not mapa_aberto()
    if hud.painel_aberto != "":
        _preencher_painel()
