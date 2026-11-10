extends Node2D
## Farol da ilha principal (spec 7.4): à noite um facho gira e é visto de longe.

const VEL_GIRO := 0.8          ## rad/s
const ALCANCE := 8000.0        ## px
const TAM_TEXTURA := 512

var aceso := false:
	set(v):
		aceso = v
		var facho := get_node_or_null("Facho") as PointLight2D
		var brilho := get_node_or_null("Brilho") as PointLight2D
		if facho:
			facho.enabled = v
		if brilho:
			brilho.enabled = v


func _ready() -> void:
	var facho := $Facho as PointLight2D
	facho.texture = textura_cone()
	facho.texture_scale = ALCANCE * 2.0 / TAM_TEXTURA
	aceso = aceso


func _process(dt: float) -> void:
	if aceso:
		$Facho.rotation += VEL_GIRO * dt


## Cone de luz apontando para +x, mais fraco nas bordas e na distância.
static func textura_cone() -> ImageTexture:
	var img := Image.create(TAM_TEXTURA, TAM_TEXTURA, false, Image.FORMAT_RGBA8)
	var c := Vector2(TAM_TEXTURA, TAM_TEXTURA) / 2.0
	var abertura := deg_to_rad(11.0)
	for y in TAM_TEXTURA:
		for x in TAM_TEXTURA:
			var d := Vector2(x, y) - c
			var r := d.length() / c.x
			var a := absf(d.angle())
			var v := 0.0
			if r <= 1.0 and a < abertura:
				v = (1.0 - a / abertura) * (1.0 - r) * 1.2
			img.set_pixel(x, y, Color(1.0, 0.95, 0.75, clampf(v, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
