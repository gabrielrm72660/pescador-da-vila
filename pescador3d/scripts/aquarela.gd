extends RefCounted
## Ferramentas da interface em aquarela (v0.5.5): paleta de pigmentos, fontes manuscritas, lavagens (shaders/aquarela.gdshader),
## botão e controle de volume pintados à mão. Tudo é código; as únicas imagens são as duas fontes (licença OFL, em assets/fontes).

const SHADER := preload("res://shaders/aquarela.gdshader")
const FONTE_TITULO: Font = preload("res://assets/fontes/CaveatBrush-Regular.ttf")     # letra de pincel: títulos e números grandes
const FONTE_TEXTO: Font = preload("res://assets/fontes/PatrickHand-Regular.ttf")      # letra de mão legível: o resto

## v0.6.0: as duas fontes manuscritas não têm ideogramas. A Noto Sans CJK (OFL), recortada só com os caracteres do jogo,
## entra como reserva: só é usada para o que as fontes pintadas não desenham, então português, espanhol e inglês não mudam.
const FONTE_ZH_TEXTO := "res://assets/fontes/NotoSansSC-Regular-subset.otf"
const FONTE_ZH_TITULO := "res://assets/fontes/NotoSansSC-Bold-subset.otf"
static var _reserva_ligada: bool = false

static func preparar_fontes() -> void:
    if _reserva_ligada:
        return
    _reserva_ligada = true
    for par in [[FONTE_TEXTO, FONTE_ZH_TEXTO], [FONTE_TITULO, FONTE_ZH_TITULO]]:
        var reserva: Font = null
        if ResourceLoader.exists(par[1]):
            reserva = load(par[1]) as Font
        if reserva == null and FileAccess.file_exists(par[1]):          # sem importar (testes): lê o arquivo direto
            var ff := FontFile.new()
            ff.load_dynamic_font(par[1])
            reserva = ff
        if reserva != null:
            (par[0] as Font).fallbacks = [reserva]

# pigmentos
const AZUL_MAR := Color(0.07, 0.25, 0.33)          # lavagem principal dos cartões do jogo
const AZUL_FUNDO := Color(0.035, 0.13, 0.22)       # o segundo tom dela
const TURQUESA := Color(0.20, 0.62, 0.62)
const VERDE := Color(0.33, 0.83, 0.66)
const OURO := Color(0.98, 0.76, 0.33)
const OCRE := Color(0.76, 0.52, 0.18)
const TERRACOTA := Color(0.62, 0.26, 0.17)
const CREME := Color(0.97, 0.93, 0.82)
const PAPEL := Color(0.95, 0.90, 0.77)             # folha de papel
const PAPEL_2 := Color(0.90, 0.83, 0.66)
const NANQUIM := Color(0.09, 0.12, 0.19)           # tinta dos textos sobre o papel
const NANQUIM_CLARO := Color(0.25, 0.30, 0.38)

## Material de lavagem. Quem usa só precisa dizer as cores; o tamanho entra depois (ver ajustar).
static func material(cor: Color, cor2: Color, semente: float = 1.0, extra: Dictionary = {}) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = SHADER
    m.set_shader_parameter("cor", cor)
    m.set_shader_parameter("cor2", cor2)
    m.set_shader_parameter("semente", semente)
    for k in extra:
        m.set_shader_parameter(k, extra[k])
    return m

## Cria a lavagem como filho de "pai", atrás dele. Em PanelContainer ela se encaixa sozinha; em Button, ocupa tudo.
## "margem": folga dentro do retângulo onde a tinta pode escorrer.
static func fundo(pai: Control, cor: Color, cor2: Color, semente: float = 1.0, extra: Dictionary = {}, margem: float = 10.0) -> ColorRect:
    var r := ColorRect.new()
    r.name = "Aquarela"
    r.show_behind_parent = true
    r.mouse_filter = Control.MOUSE_FILTER_IGNORE
    r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    r.material = material(cor, cor2, semente, extra)
    r.material.set_shader_parameter("margem", margem)
    r.resized.connect(func(): r.material.set_shader_parameter("tam", r.size))
    pai.add_child(r)
    r.material.set_shader_parameter("tam", r.size)
    return r

## Lavagem solta: posiciona o ColorRect de modo que a forma pintada caia exatamente em "ret" (coordenadas do pai).
static func ajustar(r: ColorRect, ret: Rect2, margem: float = 22.0) -> void:
    r.position = ret.position - Vector2(margem, margem)
    r.size = ret.size + Vector2(margem, margem) * 2.0
    r.material.set_shader_parameter("tam", r.size)
    r.material.set_shader_parameter("margem", margem)

## Esquemas prontos (cor, cor2, parâmetros do shader).
static func esquema(nome: String) -> Dictionary:
    match nome:
        "papel":      # folha de caderno: clara, quase opaca, nanquim fino na borda
            return {"cor": PAPEL, "cor2": PAPEL_2, "extra": {"alfa": 0.97, "papel": 1.0, "borda": 0.30, "largura_borda": 12.0, "grao": 0.10,
                    "irregular": 4.0, "seco": 0.0, "respingos": 0.0, "tinta": Color(NANQUIM, 0.38), "raio": 10.0}}
        "ouro":
            return {"cor": OURO, "cor2": Color(0.86, 0.58, 0.20), "extra": {"alfa": 0.97, "borda": 0.45, "grao": 0.14, "irregular": 3.5, "seco": 0.25, "respingos": 0.25, "raio": 12.0}}
        "turquesa":
            return {"cor": Color(0.30, 0.76, 0.72), "cor2": Color(0.14, 0.52, 0.55), "extra": {"alfa": 0.97, "borda": 0.42, "grao": 0.14, "irregular": 3.5, "seco": 0.25, "respingos": 0.25, "raio": 12.0}}
        "ocre":
            return {"cor": Color(0.74, 0.56, 0.22), "cor2": Color(0.55, 0.36, 0.13), "extra": {"alfa": 0.97, "borda": 0.42, "grao": 0.14, "irregular": 3.5, "seco": 0.25, "respingos": 0.2, "raio": 12.0}}
        "terracota":
            return {"cor": Color(0.74, 0.34, 0.22), "cor2": Color(0.52, 0.20, 0.14), "extra": {"alfa": 0.97, "borda": 0.42, "grao": 0.14, "irregular": 3.5, "seco": 0.25, "respingos": 0.2, "raio": 12.0}}
        "mar":
            return {"cor": Color(0.12, 0.34, 0.42), "cor2": Color(0.06, 0.20, 0.30), "extra": {"alfa": 0.95, "borda": 0.40, "grao": 0.15, "irregular": 3.5, "seco": 0.15, "respingos": 0.0, "raio": 12.0}}
        _:            # "pigmento": azul-marinho translúcido dos cartões do HUD
            return {"cor": AZUL_MAR, "cor2": AZUL_FUNDO, "extra": {"alfa": 0.90, "borda": 0.42, "grao": 0.17, "irregular": 5.0, "seco": 0.55, "respingos": 0.45, "raio": 14.0}}
