extends Button
## Botão com lavagem de aquarela por baixo: o estado (normal, sobre, apertado, desligado) muda o brilho e a transparência.
## Uso: var b := BotaoAquarela.new(); b.configurar("turquesa", semente, cor_texto, tamanho_fonte)
const Aq = preload("res://scripts/aquarela.gd")

var lavagem: ColorRect
var _estado_antes: int = -1
var _esquema: String = ""
var _cor_texto: Color = Color.WHITE
var marcado: bool = false

func configurar(nome_esquema: String, semente: float, cor_texto: Color, tamanho: int = 18) -> void:
    var esq: Dictionary = Aq.esquema(nome_esquema)
    _esquema = nome_esquema
    _cor_texto = cor_texto
    flat = false
    focus_mode = Control.FOCUS_NONE
    var vazio := StyleBoxEmpty.new()
    vazio.content_margin_left = 14.0
    vazio.content_margin_right = 14.0
    vazio.content_margin_top = 8.0
    vazio.content_margin_bottom = 8.0
    for est in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
        add_theme_stylebox_override(est, vazio)
    add_theme_font_override("font", Aq.FONTE_TEXTO)
    add_theme_font_size_override("font_size", tamanho)
    for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
        add_theme_color_override(c, cor_texto)
    add_theme_color_override("font_disabled_color", Color(cor_texto, 0.5))
    lavagem = Aq.fundo(self, esq["cor"], esq["cor2"], semente, esq["extra"], 9.0)

func _notification(what: int) -> void:
    if what != NOTIFICATION_DRAW or lavagem == null:
        return
    var modo := get_draw_mode()
    if modo == _estado_antes:
        return
    _estado_antes = modo
    var m: ShaderMaterial = lavagem.material
    match modo:
        DRAW_HOVER, DRAW_HOVER_PRESSED:
            m.set_shader_parameter("brilho", 0.9)
        DRAW_PRESSED:
            m.set_shader_parameter("brilho", -0.4)
        DRAW_DISABLED:
            m.set_shader_parameter("brilho", -0.3)
        _:
            m.set_shader_parameter("brilho", 0.0)
    lavagem.modulate = Color(1, 1, 1, 0.45) if modo == DRAW_DISABLED else Color.WHITE

## Para escolhas (idioma, qualidade...): o marcado vira ouro com tinta escura; os outros voltam ao esquema de origem.
func marcar(sim: bool) -> void:
    marcado = sim
    if lavagem == null:
        return
    var esq: Dictionary = Aq.esquema("ouro" if sim else _esquema)
    var m: ShaderMaterial = lavagem.material
    m.set_shader_parameter("cor", esq["cor"])
    m.set_shader_parameter("cor2", esq["cor2"])
    var cor: Color = Aq.NANQUIM if sim else _cor_texto
    for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
        add_theme_color_override(c, cor)
