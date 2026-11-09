extends "res://testes/caso_teste.gd"
const M = preload("res://logica/mapa.gd")
const MK = preload("res://logica/mercado.gd")

var d; var mundo
func _init(): d = MK.carregar_dados(); mundo = d.mundo

func _v(a) -> Vector2: return Vector2(a[0], a[1])

func test_zonas_em_pontos_conhecidos():
	igual(M.zona_em(mundo, Vector2.ZERO), M.TERRA, "porto é terra")
	igual(M.zona_em(mundo, _v(mundo.farol.pos)), M.TERRA, "farol é terra")
	igual(M.zona_em(mundo, Vector2(0, 1500)), 0, "rasas do porto")
	igual(M.zona_em(mundo, Vector2(0, 4000)), 1, "profundas")
	igual(M.zona_em(mundo, Vector2(-12500, 7000)), 2, "fossa negra")
	igual(M.zona_em(mundo, Vector2(15000 + 2390, -12000)), 2, "borda da fossa norte")
	igual(M.zona_em(mundo, Vector2(15000 + 2450, -12000)), 1, "logo fora")
	igual(M.zona_em(mundo, Vector2(7500, 1500)), M.TERRA, "miolo da ilhota grande")
	igual(M.zona_em(mundo, Vector2(7500 + 960, 1500)), 0, "recife da ilhota grande")

func test_fossa_girada():
	# Fossa Negra gira 20°: o ponto no eixo maior girado está dentro; o mesmo afastamento no eixo x puro, perto da borda
	var dentro := Vector2(-12500, 7000) + Vector2.from_angle(deg_to_rad(20)) * 2400
	igual(M.zona_em(mundo, dentro), 2, "eixo maior girado")
	var fora := Vector2(-12500, 7000) + Vector2.from_angle(deg_to_rad(20) + PI / 2) * 1500
	igual(M.zona_em(mundo, fora), 1, "além do eixo menor")

func test_cais_ficam_na_agua_e_perto_da_cidade():
	for c in mundo.cidades:
		afirmar(M.zona_em(mundo, _v(c.cais)) != M.TERRA, "%s: cais na água" % c.id)
		igual(M.cais_proximo(mundo, _v(c.cais)).get("id", ""), c.id, "%s: cais próximo" % c.id)
		igual(M.cais_proximo(mundo, _v(c.cais) + Vector2(200, 0)), {}, "%s: longe do cais" % c.id)

func test_zona_segura():
	var f := _v(mundo.farol.pos)
	afirmar(M.na_zona_segura(mundo, f + Vector2(2499, 0)), "dentro"); afirmar(not M.na_zona_segura(mundo, f + Vector2(2501, 0)), "fora")

func test_destinos_ciclam():
	var l = M.destinos(mundo)
	igual(l.size(), 3, "3 cidades")
	igual(M.proximo_destino(l, "porto_farol"), "vila_arraias", "1"); igual(M.proximo_destino(l, "vila_arraias"), "ponta_negra", "2")
	igual(M.proximo_destino(l, "ponta_negra"), "porto_farol", "volta"); igual(M.proximo_destino(l, "xyz"), "porto_farol", "inválido")
	var com_extra = M.destinos(mundo, [{"id": "alvo", "nome": "Alvo", "pos": Vector2(1, 1)}])
	igual(M.proximo_destino(com_extra, "ponta_negra"), "alvo", "extra depois das cidades")
	afirmar(com_extra[0].pos is Vector2, "pos como Vector2")

func test_rumo_e_milhas():
	perto(M.rumo(Vector2.ZERO, Vector2(0, -100)), -PI / 2, 1e-6, "norte")
	perto(M.distancia_milhas(Vector2.ZERO, Vector2(2000, 0)), 10.0, 1e-6, "10 mi")

func test_validar_dados_aponta_cais_em_terra():
	var ruim: Dictionary = d.duplicate(true)
	ruim.mundo.cidades[0].cais = [0, 0]
	afirmar(str(MK.validar_dados(ruim)).contains("porto_farol"), "erro cita o porto: %s" % str(MK.validar_dados(ruim)))
	igual(MK.validar_dados(d), [], "dados reais válidos")
