extends HSlider
## Controle deslizante pintado: trilho de nanquim, faixa de pigmento até o valor e uma bolinha de tinta.
## O arrasto continua sendo do HSlider; só o desenho é trocado.
const Aq = preload("res://scripts/aquarela.gd")

var cor_faixa: Color = Color(0.20, 0.62, 0.62)
var cor_trilho: Color = Color(0.09, 0.12, 0.19, 0.45)
var cor_bolinha: Color = Color(0.035, 0.13, 0.22, 0.88)

func _init() -> void:
    var vazio := StyleBoxEmpty.new()
    add_theme_stylebox_override("slider", vazio)
    add_theme_stylebox_override("grabber_area", vazio)
    add_theme_stylebox_override("grabber_area_highlight", vazio)
    var ponto := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
    for i in ["grabber", "grabber_highlight", "grabber_disabled"]:
        add_theme_icon_override(i, ponto)
    focus_mode = Control.FOCUS_NONE
    custom_minimum_size = Vector2(160, 26)

func _draw() -> void:
    var largura := size.x - 16.0
    var y := size.y * 0.5
    var f := 0.0 if max_value <= min_value else (value - min_value) / (max_value - min_value)
    var x0 := 8.0
    var x1 := x0 + largura * f
    var pts := PackedVector2Array()
    var n := maxi(8, int(largura / 10.0))
    for i in n + 1:                                                # trilho: traço irregular
        pts.append(Vector2(x0 + largura * i / n, y + sin(i * 1.7 + size.x) * 0.9))
    draw_polyline(pts, cor_trilho, 3.5, true)
    if f > 0.01:
        var faixa := PackedVector2Array()
        var m := maxi(2, int(largura * f / 8.0))
        for i in m + 1:
            faixa.append(Vector2(x0 + (x1 - x0) * i / m, y + sin(i * 2.3 + 1.0) * 1.1))
        draw_polyline(faixa, Color(cor_faixa, 0.55), 9.0, true)       # camada larga e clara
        draw_polyline(faixa, Color(cor_faixa.darkened(0.15), 0.85), 5.0, true)
    draw_circle(Vector2(x1, y), 9.5, cor_bolinha)
    draw_circle(Vector2(x1, y), 7.0, cor_faixa.lightened(0.15))
    draw_arc(Vector2(x1, y), 9.5, 0.0, TAU, 20, Color(Aq.CREME, 0.55), 1.5, true)
