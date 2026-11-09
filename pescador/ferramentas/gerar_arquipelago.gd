extends SceneTree
## Gera o mapa do arquipélago a partir de dados/mundo.json (spec 9).
## Rode com:  python gerar_mapa.py [caminho_do_godot]
## Cria arte/provisorio/tiles.res (tiles coloridos provisórios) e cenas/Mapa.tscn. Depois dá para retocar no editor.

const Mapa = preload("res://logica/mapa.gd")
const Mercado = preload("res://logica/mercado.gd")
const CAMINHO_TILES := "res://arte/provisorio/tiles.res"
const CAMINHO_CENA := "res://cenas/Mapa.tscn"
const TAM := 128
## Ordem dos tiles no atlas: rasa, profunda, abissal, terra.
const CORES := [Color("#3ec1c9"), Color("#1f4e8c"), Color("#0b1526"), Color("#c9b27a")]
const ZONAS := [0, 1, 2, -1]


func _init() -> void:
	var mundo: Dictionary = Mercado.carregar_dados().mundo
	var ts := criar_tileset()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://arte/provisorio"))
	var erro := ResourceSaver.save(ts, CAMINHO_TILES, ResourceSaver.FLAG_COMPRESS)
	if erro != OK:
		push_error("não salvou %s (%d)" % [CAMINHO_TILES, erro])
		quit(1)
		return
	var camada := TileMapLayer.new()
	camada.name = "Mapa"
	camada.tile_set = load(CAMINHO_TILES)
	var n := int(mundo.mapa.limite) / int(mundo.mapa.celula)
	pintar(camada, mundo, Rect2i(-n, -n, 2 * n, 2 * n))
	_borda(camada, float(mundo.mapa.limite))
	var cena := PackedScene.new()
	cena.pack(camada)
	erro = ResourceSaver.save(cena, CAMINHO_CENA)
	camada.free()
	if erro != OK:
		push_error("não salvou %s (%d)" % [CAMINHO_CENA, erro])
		quit(1)
		return
	print("Mapa gerado: %d×%d células em %s" % [2 * n, 2 * n, CAMINHO_CENA])
	quit(0)


static func criar_tileset() -> TileSet:
	var img := Image.create(TAM * 4, TAM, false, Image.FORMAT_RGBA8)
	for i in 4:
		img.fill_rect(Rect2i(i * TAM, 0, TAM, TAM), CORES[i])
		# bordinha mais escura para ver a grade de perto
		img.fill_rect(Rect2i(i * TAM, TAM - 2, TAM, 2), CORES[i].darkened(0.08))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TAM, TAM)
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "zona")
	ts.set_custom_data_layer_type(0, TYPE_INT)
	ts.add_physics_layer()
	var fonte := TileSetAtlasSource.new()
	fonte.texture = ImageTexture.create_from_image(img)
	fonte.texture_region_size = Vector2i(TAM, TAM)
	ts.add_source(fonte, 0)
	var meio := TAM / 2.0
	for i in 4:
		fonte.create_tile(Vector2i(i, 0))
		var td := fonte.get_tile_data(Vector2i(i, 0), 0)
		td.set_custom_data("zona", ZONAS[i])
		if ZONAS[i] == Mapa.TERRA:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-meio, -meio), Vector2(meio, -meio), Vector2(meio, meio), Vector2(-meio, meio)]))
	return ts


static func pintar(camada: TileMapLayer, mundo: Dictionary, regiao: Rect2i) -> void:
	var cel := float(camada.tile_set.tile_size.x)
	for y in range(regiao.position.y, regiao.end.y):
		for x in range(regiao.position.x, regiao.end.x):
			var z := Mapa.zona_em(mundo, Vector2(x * cel + cel / 2.0, y * cel + cel / 2.0))
			camada.set_cell(Vector2i(x, y), 0, Vector2i(ZONAS.find(z), 0))


static func _borda(camada: TileMapLayer, limite: float) -> void:
	var corpo := StaticBody2D.new()
	corpo.name = "Borda"
	camada.add_child(corpo)
	corpo.owner = camada
	var esp := 400.0
	var lado := 2.0 * limite + 2.0 * esp
	var partes := [
		[Vector2(0, -limite - esp / 2.0), Vector2(lado, esp)], [Vector2(0, limite + esp / 2.0), Vector2(lado, esp)],
		[Vector2(-limite - esp / 2.0, 0), Vector2(esp, lado)], [Vector2(limite + esp / 2.0, 0), Vector2(esp, lado)]]
	for i in partes.size():
		var forma := CollisionShape2D.new()
		forma.name = "Lado%d" % i
		var r := RectangleShape2D.new()
		r.size = partes[i][1]
		forma.shape = r
		forma.position = partes[i][0]
		corpo.add_child(forma)
		forma.owner = camada
