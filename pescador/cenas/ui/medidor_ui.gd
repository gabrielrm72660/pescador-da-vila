extends Control
## Barra do medidor de fisgada (spec 5.1): faixa verde, dourada no meio e o ponteiro. Só desenha o que recebe.

var _d: Dictionary = {}


func definir(d: Dictionary) -> void:
	_d = d
	visible = not d.is_empty()
	queue_redraw()


func x_ponteiro() -> float:
	return float(_d.get("pos", 0.0)) * size.x


## (início, fim) em px da faixa "verde" ou "dourada".
func faixa(nome: String) -> Vector2:
	var centro := float(_d.get("centro", 0.5))
	var meia := float(_d.get(nome, 0.0)) / 2.0
	return Vector2(clampf(centro - meia, 0.0, 1.0), clampf(centro + meia, 0.0, 1.0)) * size.x


func _draw() -> void:
	if _d.is_empty():
		return
	draw_rect(Rect2(Vector2(-6, -6), size + Vector2(12, 12)), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.16, 0.22, 0.30))
	var v := faixa("verde")
	draw_rect(Rect2(v.x, 0, v.y - v.x, size.y), Color(0.30, 0.78, 0.36))
	var o := faixa("dourada")
	draw_rect(Rect2(o.x, 0, o.y - o.x, size.y), Color(1.0, 0.82, 0.25))
	var x := x_ponteiro()
	draw_rect(Rect2(x - 4, -10, 8, size.y + 20), Color.WHITE)
	draw_rect(Rect2(x - 4, -10, 8, size.y + 20), Color.BLACK, false, 2.0)
