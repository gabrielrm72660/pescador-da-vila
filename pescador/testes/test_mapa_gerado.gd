extends "res://testes/caso_teste.gd"
const G = preload("res://ferramentas/gerar_arquipelago.gd")
const M = preload("res://logica/mapa.gd")
const MK = preload("res://logica/mercado.gd")

var mundo
func _init(): mundo = MK.carregar_dados().mundo

func _zona(camada: TileMapLayer, c: Vector2i):
	var td := camada.get_cell_tile_data(c)
	return td.get_custom_data("zona") if td else null

func test_tileset_tem_zonas_e_colisao():
	var ts: TileSet = G.criar_tileset()
	var fonte: TileSetAtlasSource = ts.get_source(0)
	igual(fonte.get_tiles_count(), 4, "4 tiles")
	var esperado := [0, 1, 2, M.TERRA]
	for i in 4:
		var td := fonte.get_tile_data(Vector2i(i, 0), 0)
		igual(td.get_custom_data("zona"), esperado[i], "zona do tile %d" % i)
		igual(td.get_collision_polygons_count(0), 1 if i == 3 else 0, "colisão do tile %d" % i)

func test_pintar_regiao_pequena():
	var camada := TileMapLayer.new(); camada.tile_set = G.criar_tileset()
	G.pintar(camada, mundo, Rect2i(-8, -8, 16, 16))
	igual(_zona(camada, Vector2i(0, 0)), M.TERRA, "centro do porto")
	igual(_zona(camada, Vector2i(0, 12)), null, "fora da região fica vazia")
	igual(_zona(camada, Vector2i(0, 7)), M.zona_em(mundo, Vector2(64, 7 * 128 + 64)), "bate com a lógica")
	camada.free()

func test_mapa_gerado_bate_com_a_logica():
	var cena: Node = load("res://cenas/Mapa.tscn").instantiate()
	var camada := cena as TileMapLayer
	afirmar(camada != null and cena.name == "Mapa", "raiz é a TileMapLayer Mapa")
	var cel := int(mundo.mapa.celula); var n := int(mundo.mapa.limite) / cel
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var erradas := 0
	for i in 400:
		var c := Vector2i(rng.randi_range(-n, n - 1), rng.randi_range(-n, n - 1))
		if _zona(camada, c) != M.zona_em(mundo, Vector2(c) * cel + Vector2(cel, cel) / 2.0):
			erradas += 1
	igual(erradas, 0, "células que não batem")
	var borda := cena.get_node_or_null("Borda")
	afirmar(borda != null and borda.get_child_count() == 4, "moldura com 4 formas")
	cena.free()
