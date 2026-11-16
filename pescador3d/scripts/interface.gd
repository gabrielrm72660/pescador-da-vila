extends CanvasLayer
## Interface criada por código para permanecer independente de fontes externas.
## Cores marítimas, escrita em português e layout 16:9 responsivo.

signal iniciar_pressed
signal reiniciar_pressed
signal pescar_pressed
signal pausa_pressed
signal vender_pressed
signal abastecer_pressed
signal zarpar_pressed
signal melhoria_pressed(id: String)
signal volume_mudou(grupo: String, valor: float)
signal mudo_pressed

const HudPintado = preload("res://scripts/hud.gd")

var raiz: Control
var menu: ColorRect
var titulo_menu: Label
var subtitulo_menu: Label
var botao_principal: Button
var hud: Control
var controles_volume: Dictionary = {}     # grupo -> {barra: HSlider, valor: Label}
var botao_mudo: Button
var porto: ColorRect
var porto_titulo: Label
var porto_texto: Label
var porto_vender: Button
var porto_abastecer: Button
var porto_loja: Dictionary = {}           # id da melhoria -> botão
var diario: Array = []          # histórico das mensagens (botão do livro)
var porao: Node = null          # scripts/porao.gd
var capturas: Array:            # os peixes a bordo: {especie, peso, x, y, rot}
    get:
        return porao.itens if porao != null else []
var _peso: float = 0.0

const COR_TEXTO := Color(0.94, 0.96, 0.92, 1.0)
const COR_TURQUESA := Color(0.43, 0.89, 0.84, 1.0)
const COR_CREME := Color(0.97, 0.88, 0.69, 1.0)

func _ready() -> void:
    raiz = Control.new()
    raiz.name = "InterfaceRaiz"
    raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(raiz)
    _construir_hud()
    _construir_porto()
    _construir_menu()

func _estilo_painel() -> StyleBoxFlat:
    var estilo := StyleBoxFlat.new()
    estilo.bg_color = Color(0.023, 0.105, 0.16, 0.88)
    estilo.border_color = Color(0.35, 0.68, 0.68, 0.43)
    estilo.border_width_top = 1
    estilo.border_width_bottom = 1
    estilo.border_width_left = 1
    estilo.border_width_right = 1
    estilo.corner_radius_top_left = 12
    estilo.corner_radius_top_right = 12
    estilo.corner_radius_bottom_left = 12
    estilo.corner_radius_bottom_right = 12
    return estilo

func _nova_label(texto: String, tamanho: int, cor: Color, quebra: bool = false) -> Label:
    var item := Label.new()
    item.text = texto
    item.add_theme_font_size_override("font_size", tamanho)
    item.add_theme_color_override("font_color", cor)
    if quebra:
        item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return item

func _novo_painel() -> PanelContainer:
    var painel := PanelContainer.new()
    painel.add_theme_stylebox_override("panel", _estilo_painel())
    painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    raiz.add_child(painel)
    return painel

func _coluna_em(painel: PanelContainer) -> VBoxContainer:
    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 17)
    margem.add_theme_constant_override("margin_right", 17)
    margem.add_theme_constant_override("margin_top", 12)
    margem.add_theme_constant_override("margin_bottom", 12)
    painel.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 5)
    margem.add_child(coluna)
    return coluna

func _construir_hud() -> void:
    hud = HudPintado.new()
    hud.name = "Hud"
    raiz.add_child(hud)
    hud.botao.connect(_ao_apertar_botao)

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
    var estava: bool = hud.painel_aberto != ""
    hud.soltar_peixe()
    hud.painel_aberto = ""
    return estava

func _preencher_painel() -> void:
    if hud.painel_aberto == "porao":
        hud.titulo_painel = "Porão"                           # a grade é desenhada por scripts/hud.gd
    elif hud.painel_aberto == "diario":
        hud.titulo_painel = "Diário de bordo"
        hud.linhas_painel = diario.slice(maxi(0, diario.size() - 9))

func _estilo_botao(cor: Color) -> StyleBoxFlat:
    var e := StyleBoxFlat.new()
    e.bg_color = cor
    e.corner_radius_top_left = 9
    e.corner_radius_top_right = 9
    e.corner_radius_bottom_left = 9
    e.corner_radius_bottom_right = 9
    e.content_margin_left = 14.0
    e.content_margin_right = 14.0
    e.content_margin_top = 11.0
    e.content_margin_bottom = 11.0
    return e

func _construir_menu() -> void:
    menu = ColorRect.new()
    menu.color = Color(0.017, 0.061, 0.09, 0.77)
    menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.mouse_filter = Control.MOUSE_FILTER_STOP
    raiz.add_child(menu)

    var central := CenterContainer.new()
    central.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    menu.add_child(central)

    var cartao := PanelContainer.new()
    cartao.custom_minimum_size = Vector2(530, 398)
    cartao.add_theme_stylebox_override("panel", _estilo_painel())
    central.add_child(cartao)

    var margem := MarginContainer.new()
    margem.add_theme_constant_override("margin_left", 40)
    margem.add_theme_constant_override("margin_right", 40)
    margem.add_theme_constant_override("margin_top", 32)
    margem.add_theme_constant_override("margin_bottom", 32)
    cartao.add_child(margem)

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 12)
    margem.add_child(col)

    titulo_menu = _nova_label("PESCADOR", 46, COR_TEXTO)
    titulo_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(titulo_menu)

    subtitulo_menu = _nova_label("Uma aventura de pesca no Atlântico brasileiro.\nAssuma o comando do PE-3476.", 19, COR_CREME, true)
    subtitulo_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(subtitulo_menu)

    botao_principal = Button.new()
    botao_principal.text = "COMEÇAR A VIAGEM"
    botao_principal.custom_minimum_size = Vector2(395, 50)
    botao_principal.add_theme_font_size_override("font_size", 20)
    botao_principal.add_theme_color_override("font_color", Color(0.03, 0.13, 0.17, 1.0))
    botao_principal.add_theme_stylebox_override("normal", _estilo_botao(Color(0.49, 0.89, 0.82, 1.0)))
    botao_principal.add_theme_stylebox_override("hover", _estilo_botao(Color(0.77, 0.96, 0.89, 1.0)))
    botao_principal.add_theme_stylebox_override("pressed", _estilo_botao(Color(0.31, 0.73, 0.68, 1.0)))
    botao_principal.pressed.connect(_clicar_iniciar)
    col.add_child(botao_principal)

    var botao_reiniciar := Button.new()
    botao_reiniciar.text = "REINICIAR PARTIDA"
    botao_reiniciar.custom_minimum_size = Vector2(395, 43)
    botao_reiniciar.add_theme_font_size_override("font_size", 16)
    botao_reiniciar.add_theme_stylebox_override("normal", _estilo_botao(Color(0.14, 0.34, 0.39, 1.0)))
    botao_reiniciar.add_theme_stylebox_override("hover", _estilo_botao(Color(0.23, 0.46, 0.48, 1.0)))
    botao_reiniciar.pressed.connect(_clicar_reiniciar)
    col.add_child(botao_reiniciar)

    _construir_volume(col)

    var dica := _nova_label("WASD navegar  •  ESPAÇO frear  •  F pescar  •  E atracar\nBotão direito do mouse gira a câmera  •  roda aproxima  •  V recentra\nC câmera  •  T hora do dia  •  M som  •  R reiniciar  •  ESC pausa", 14, Color(0.77, 0.87, 0.84, 1.0))
    dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(dica)

func _construir_porto() -> void:
    porto = ColorRect.new()
    porto.color = Color(0.017, 0.061, 0.09, 0.45)
    porto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    porto.mouse_filter = Control.MOUSE_FILTER_STOP
    porto.visible = false
    raiz.add_child(porto)
    var central := CenterContainer.new()
    central.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    porto.add_child(central)
    var cartao := PanelContainer.new()
    cartao.custom_minimum_size = Vector2(470, 0)
    cartao.add_theme_stylebox_override("panel", _estilo_painel())
    central.add_child(cartao)
    var margem := MarginContainer.new()
    for lado in ["left", "right", "top", "bottom"]:
        margem.add_theme_constant_override("margin_" + lado, 22)
    cartao.add_child(margem)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 9)
    margem.add_child(col)
    porto_titulo = _nova_label("Cais", 30, COR_CREME)
    col.add_child(porto_titulo)
    porto_texto = _nova_label("", 17, COR_TEXTO, true)
    col.add_child(porto_texto)
    porto_vender = _botao_porto("Vender", Color(0.49, 0.89, 0.82, 1.0), Color(0.03, 0.13, 0.17, 1.0))
    porto_vender.pressed.connect(func(): vender_pressed.emit())
    col.add_child(porto_vender)
    porto_abastecer = _botao_porto("Abastecer", Color(0.96, 0.62, 0.24, 1.0), Color(0.15, 0.07, 0.02, 1.0))
    porto_abastecer.pressed.connect(func(): abastecer_pressed.emit())
    col.add_child(porto_abastecer)
    col.add_child(_nova_label("MELHORIAS DO BARCO", 14, COR_TURQUESA))
    for id in ["motor", "tanque", "porao", "vara"]:
        var b := _botao_porto(id, Color(0.16, 0.30, 0.42, 1.0), COR_TEXTO)
        b.custom_minimum_size = Vector2(470, 36)
        b.add_theme_font_size_override("font_size", 15)
        b.pressed.connect(func(): melhoria_pressed.emit(id))
        col.add_child(b)
        porto_loja[id] = b
    var sair := _botao_porto("Zarpar   [E]", Color(0.14, 0.34, 0.39, 1.0), COR_TEXTO)
    sair.pressed.connect(func(): zarpar_pressed.emit())
    col.add_child(sair)

func _botao_porto(texto: String, cor: Color, cor_texto: Color) -> Button:
    var b := Button.new()
    b.text = texto
    b.custom_minimum_size = Vector2(410, 46)
    b.add_theme_font_size_override("font_size", 18)
    b.add_theme_color_override("font_color", cor_texto)
    b.add_theme_color_override("font_hover_color", cor_texto)
    b.add_theme_color_override("font_disabled_color", Color(cor_texto, 0.45))
    b.add_theme_stylebox_override("normal", _estilo_botao(cor))
    b.add_theme_stylebox_override("hover", _estilo_botao(cor.lightened(0.18)))
    b.add_theme_stylebox_override("pressed", _estilo_botao(cor.darkened(0.15)))
    b.add_theme_stylebox_override("disabled", _estilo_botao(Color(cor, 0.3)))
    return b

## Abre (ou atualiza) o painel do cais. dados: nome, dinheiro, peixes, peso, valor, falta_litros, preco_litro, litros_possiveis
func mostrar_porto(d: Dictionary) -> void:
    porto.visible = true
    porto_titulo.text = "Cais de %s" % d.nome
    porto_texto.text = "Carteira: R$ %d\nPorão: %d peixe(s), %s kg\nTanque: %d de %d L" % [d.dinheiro, d.peixes,
            ("%.1f" % d.peso).replace(".", ","), roundi(d.litros), roundi(d.tanque)]
    porto_vender.text = "Vender os peixes por R$ %d   [1]" % d.valor if d.peixes > 0 else "Nada para vender"
    porto_vender.disabled = d.peixes == 0
    if d.falta_litros < 1.0:
        porto_abastecer.text = "Tanque cheio"
        porto_abastecer.disabled = true
    elif d.litros_possiveis < 1.0:
        porto_abastecer.text = "Diesel a R$ %d o litro — sem dinheiro" % d.preco_litro
        porto_abastecer.disabled = true
    else:
        porto_abastecer.text = "Abastecer %d L por R$ %d   [2]" % [roundi(d.litros_possiveis), roundi(d.litros_possiveis * d.preco_litro)]
        porto_abastecer.disabled = false
    for linha in d.get("loja", []):
        var b: Button = porto_loja.get(linha.id)
        if b != null:
            b.text = linha.texto
            b.disabled = not linha.pode

func esconder_porto() -> void:
    porto.visible = false

## Menu de volume: quatro controles deslizantes e o botão de silenciar. Quem aplica é scripts/som.gd.
func _construir_volume(col: VBoxContainer) -> void:
    var titulo := _nova_label("SOM", 15, COR_TURQUESA)
    col.add_child(titulo)
    var grade := GridContainer.new()
    grade.columns = 3
    grade.add_theme_constant_override("h_separation", 14)
    grade.add_theme_constant_override("v_separation", 8)
    col.add_child(grade)
    var nomes := {"geral": "Geral", "ambiente": "Mar e vento", "barco": "Motor e casco", "efeitos": "Efeitos"}
    for grupo in ["geral", "ambiente", "barco", "efeitos"]:
        var rotulo := _nova_label(nomes[grupo], 15, COR_TEXTO)
        rotulo.custom_minimum_size = Vector2(120, 0)
        grade.add_child(rotulo)
        var barra := HSlider.new()
        barra.min_value = 0.0
        barra.max_value = 100.0
        barra.step = 5.0
        barra.value = 80.0
        barra.custom_minimum_size = Vector2(220, 22)
        barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        grade.add_child(barra)
        var valor := _nova_label("80%", 15, COR_CREME)
        valor.custom_minimum_size = Vector2(46, 0)
        valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        grade.add_child(valor)
        controles_volume[grupo] = {"barra": barra, "valor": valor}
        barra.value_changed.connect(func(v: float):
            valor.text = "%d%%" % roundi(v)
            volume_mudou.emit(grupo, v / 100.0))
    botao_mudo = Button.new()
    botao_mudo.text = "Silenciar tudo   [M]"
    botao_mudo.custom_minimum_size = Vector2(395, 34)
    botao_mudo.add_theme_font_size_override("font_size", 14)
    botao_mudo.add_theme_stylebox_override("normal", _estilo_botao(Color(0.10, 0.24, 0.29, 1.0)))
    botao_mudo.add_theme_stylebox_override("hover", _estilo_botao(Color(0.17, 0.36, 0.40, 1.0)))
    botao_mudo.pressed.connect(func(): mudo_pressed.emit())
    col.add_child(botao_mudo)

## Põe os controles nos valores guardados (0 a 1), sem disparar o sinal de mudança.
func mostrar_volumes(volumes: Dictionary, mudo: bool) -> void:
    for grupo in controles_volume:
        if volumes.has(grupo):
            var c: Dictionary = controles_volume[grupo]
            c.barra.set_value_no_signal(float(volumes[grupo]) * 100.0)
            c.valor.text = "%d%%" % roundi(float(volumes[grupo]) * 100.0)
    botao_mudo.text = "Som desligado — ligar   [M]" if mudo else "Silenciar tudo   [M]"

func _clicar_iniciar() -> void:
    iniciar_pressed.emit()

func _clicar_reiniciar() -> void:
    reiniciar_pressed.emit()

func mostrar_inicio() -> void:
    titulo_menu.text = "PESCADOR"
    subtitulo_menu.text = "Uma aventura de pesca no Atlântico brasileiro.\nAssuma o comando do PE-3476."
    botao_principal.text = "COMEÇAR A VIAGEM"
    menu.visible = true

func mostrar_pausa() -> void:
    titulo_menu.text = "PAUSA"
    subtitulo_menu.text = "O oceano continua esperando por você."
    botao_principal.text = "RETOMAR VIAGEM"
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

func atualizar(nos: float, rumo: int, distancia: float, peixes: int, peso: float, pesca_status: String, venceu: bool, fracao_motor: float = 0.0, pesca_ativa: bool = false) -> void:
    _peso = peso
    hud.nos = nos
    hud.rumo = float(rumo)
    hud.distancia = distancia
    hud.fracao_motor = fracao_motor
    if hud.missao_titulo == "Segunda Missão":
        hud.missao_texto = "Vender os peixes no cais"
        hud.missao_feita = false
    elif hud.missao_titulo == "Viagem livre":
        hud.missao_texto = "Pescar, vender e abastecer"
        hud.missao_feita = true
    else:
        hud.missao_texto = "Pescaria inaugural (%d/3)" % mini(peixes, 3)
        hud.missao_feita = venceu
    hud.estado_pesca = pesca_status
    hud.pesca_ativa = pesca_ativa
    hud.visible = not menu.visible
    if hud.painel_aberto != "":
        _preencher_painel()
