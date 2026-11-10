extends Node2D
## Um cardume no mar (spec 4.4). O visual é provisório: silhuetas coloridas desenhadas por código,
## uma "família" de movimento por estilo. Os dados vêm de Pesca.novo_cardume().

const MAX_SILHUETAS := 28
const FAMILIAS := ["bola", "grupo", "unico", "fundo", "luzes"]
## cor da silhueta, família de movimento e tamanho (px) de cada estilo da spec
const VISUAL := {
	"bola": {"cor": Color(0.80, 0.86, 0.92), "familia": "bola", "tam": 9.0},
	"grupo": {"cor": Color(0.55, 0.66, 0.72), "familia": "grupo", "tam": 16.0},
	"grupo_pequeno": {"cor": Color(0.62, 0.70, 0.55), "familia": "grupo", "tam": 20.0},
	"rapido": {"cor": Color(0.35, 0.55, 0.80), "familia": "grupo", "tam": 24.0},
	"planando": {"cor": Color(0.30, 0.32, 0.38), "familia": "unico", "tam": 60.0},
	"fundo": {"cor": Color(0.80, 0.45, 0.30), "familia": "fundo", "tam": 10.0},
	"fundo_lento": {"cor": Color(0.70, 0.35, 0.30), "familia": "fundo", "tam": 26.0},
	"linha": {"cor": Color(0.40, 0.48, 0.70), "familia": "unico", "tam": 46.0},
	"saltos": {"cor": Color(0.25, 0.40, 0.85), "familia": "unico", "tam": 50.0},
	"gigante": {"cor": Color(0.28, 0.24, 0.20), "familia": "unico", "tam": 80.0},
	"luzes_nuvem": {"cor": Color(0.45, 1.00, 0.85), "familia": "luzes", "tam": 3.0},
	"luzes_sozinho": {"cor": Color(0.55, 0.85, 1.00), "familia": "luzes", "tam": 4.0},
	"isca_luz": {"cor": Color(1.00, 0.90, 0.50), "familia": "luzes", "tam": 5.0},
	"tentaculos_luz": {"cor": Color(1.00, 0.45, 0.60), "familia": "luzes", "tam": 5.0},
	"silhueta_palida": {"cor": Color(0.88, 0.90, 0.86), "familia": "unico", "tam": 120.0},
}
const TOM_ZONA := [Color(1, 1, 1), Color(0.62, 0.72, 0.90), Color(0.38, 0.46, 0.75)]
const VEL_DERIVA := 14.0

var dados: Dictionary = {}
var disperso := false
var _t := 0.0
var _rumo := 0.0
var _sementes: PackedFloat32Array = []
var _visual: Dictionary = VISUAL.grupo


func configurar(p_dados: Dictionary) -> void:
	dados = p_dados
	position = dados.pos
	_visual = VISUAL.get(dados.estilo, VISUAL.grupo)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(dados.pos) + str(dados.especie))
	_rumo = rng.randf_range(0.0, TAU)
	var n := 1 if _visual.familia == "unico" else clampi(int(dados.qtd), 1, MAX_SILHUETAS)
	_sementes.resize(n)
	for i in n:
		_sementes[i] = rng.randf()
	if _visual.familia == "luzes":                      # pontos bioluminescentes: não escurecem com a noite
		var m := CanvasItemMaterial.new()
		m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = m
		modulate = Color.WHITE.lerp(TOM_ZONA[clampi(zona(), 0, 2)], 0.3)
	else:
		material = null
		modulate = TOM_ZONA[clampi(zona(), 0, 2)]
	z_index = -1


func especie() -> String:
	return dados.get("especie", "")


func zona() -> int:
	return int(dados.get("zona", 0))


func estilo() -> String:
	return dados.get("estilo", "grupo")


func tentativas() -> int:
	return int(dados.get("tentativas", 0))


func silhuetas() -> int:
	return _sementes.size()


## Gasta uma tentativa e devolve quantas sobram; na última o cardume se dispersa.
func gastar_tentativa() -> int:
	dados.tentativas = maxi(0, tentativas() - 1)
	if dados.tentativas == 0:
		dispersar()
	return dados.tentativas


func dispersar() -> void:
	if disperso:
		return
	disperso = true
	if is_inside_tree():
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.8)
		tw.tween_callback(queue_free)


func _process(dt: float) -> void:
	_t += dt
	position += Vector2.from_angle(_rumo) * VEL_DERIVA * dt * (0.4 if _visual.familia == "fundo" else 1.0)
	_rumo += sin(_t * 0.3) * 0.2 * dt
	queue_redraw()


func _draw() -> void:
	var cor: Color = _visual.cor
	var tam: float = _visual.tam
	var n := _sementes.size()
	match _visual.familia:
		"bola":                                                 # dezenas girando em volta do centro
			for i in n:
				var s := _sementes[i]
				var a := s * TAU + _t * (0.9 + s)
				_peixe(Vector2.from_angle(a) * (14.0 + 38.0 * fposmod(s * 7.0, 1.0)), a + PI / 2.0, tam, cor)
		"grupo":                                                # grupo solto nadando para o mesmo lado
			for i in n:
				var s := _sementes[i]
				var base := Vector2(fposmod(s * 13.0, 1.0) - 0.5, fposmod(s * 29.0, 1.0) - 0.5) * (40.0 + 5.0 * n)
				_peixe(base + Vector2(sin(_t * 1.6 + s * 9.0) * 6.0, 0).rotated(_rumo + PI / 2.0), _rumo, tam, cor)
		"unico":                                                # um só, sombra grande
			var salto := 1.0
			if estilo() == "saltos":
				salto = 1.0 + 0.5 * maxf(0.0, sin(_t * 0.9)) ** 8
			draw_set_transform(Vector2.ZERO, _rumo, Vector2(1.0, 0.5 if estilo() != "planando" else 0.9) * salto)
			draw_circle(Vector2.ZERO, tam, Color(cor, 0.75))
			draw_colored_polygon(PackedVector2Array([Vector2(-tam, 0), Vector2(-tam * 1.6, -tam * 0.5),
					Vector2(-tam * 1.6, tam * 0.5)]), Color(cor, 0.75))
			draw_set_transform(Vector2.ZERO)
		"fundo":                                                # no fundo, andando de lado
			for i in n:
				var s := _sementes[i]
				var base := Vector2(fposmod(s * 13.0, 1.0) - 0.5, fposmod(s * 29.0, 1.0) - 0.5) * (50.0 + 4.0 * n)
				var p := base + Vector2(sin(_t * 0.8 + s * 20.0) * 10.0, 0)
				draw_circle(p, tam, Color(cor, 0.7))
				draw_line(p + Vector2(-tam * 1.5, -tam * 0.6), p + Vector2(tam * 1.5, -tam * 0.6), Color(cor, 0.7), 2.0)
				draw_line(p + Vector2(-tam * 1.5, tam * 0.6), p + Vector2(tam * 1.5, tam * 0.6), Color(cor, 0.7), 2.0)
		"luzes":                                                # só pontos de luz piscando
			for i in n:
				var s := _sementes[i]
				var base := Vector2(fposmod(s * 13.0, 1.0) - 0.5, fposmod(s * 29.0, 1.0) - 0.5) * (30.0 + 4.0 * n)
				var brilho := 0.35 + 0.65 * absf(sin(_t * (1.0 + s) + s * 30.0))
				draw_circle(base, tam * 2.6, Color(cor, 0.16 * brilho))
				draw_circle(base, tam, Color(cor, brilho))


func _peixe(p: Vector2, ang: float, tam: float, cor: Color) -> void:
	draw_set_transform(p, ang)
	draw_colored_polygon(PackedVector2Array([Vector2(tam, 0), Vector2(0, -tam * 0.38), Vector2(-tam * 0.6, 0),
			Vector2(-tam, -tam * 0.35), Vector2(-tam, tam * 0.35), Vector2(-tam * 0.6, 0), Vector2(0, tam * 0.38)]),
			Color(cor, 0.85))
	draw_set_transform(Vector2.ZERO)
