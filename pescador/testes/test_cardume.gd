extends "res://testes/caso_teste.gd"
const P = preload("res://logica/pesca.gd")
const E = preload("res://logica/especies.gd")
const C = preload("res://cenas/cardume.gd")

var l
func _init(): l = E.carregar()

func _cardume(id: String):
	var r := RandomNumberGenerator.new(); r.seed = 5
	var c = load("res://cenas/Cardume.tscn").instantiate()
	c.configurar(P.novo_cardume(E.por_id(l, id), Vector2(100, 200), r))
	return c

func test_instancia_com_os_dados():
	var c = _cardume("sardinha")
	igual(c.position, Vector2(100, 200), "posição"); igual(c.especie(), "sardinha", "espécie")
	igual(c.zona(), 0, "zona"); igual(c.tentativas(), 3, "tentativas")
	afirmar(c.silhuetas() >= 1 and c.silhuetas() <= C.MAX_SILHUETAS, "silhuetas: %d" % c.silhuetas())
	c.free()

func test_todos_os_estilos_tem_visual():
	var vistos := {}
	for e in l:
		vistos[e.estilo] = true
		afirmar(C.VISUAL.has(e.estilo), "estilo sem visual provisório: %s" % e.estilo)
	igual(vistos.size(), 15, "15 estilos nos dados")
	for estilo in C.VISUAL:
		var v: Dictionary = C.VISUAL[estilo]
		afirmar(v.familia in C.FAMILIAS, "%s: família %s" % [estilo, v.familia])
		afirmar(v.cor is Color and float(v.tam) > 0.0, "%s: cor e tamanho" % estilo)

func test_tentativas_ate_dispersar():
	var c = _cardume("tainha")
	afirmar(not c.disperso, "começa inteiro")
	igual(c.gastar_tentativa(), 2, "sobra 2"); igual(c.gastar_tentativa(), 1, "sobra 1")
	afirmar(not c.disperso, "ainda não")
	igual(c.gastar_tentativa(), 0, "acabou"); afirmar(c.disperso, "dispersou")
	var d = _cardume("tainha"); d.dispersar(); afirmar(d.disperso, "dispersar() direto")
	c.free(); d.free()

func test_mais_fundo_mais_escuro():
	var rasa = _cardume("tainha"); var prof = _cardume("atum"); var abis = _cardume("caranguejo_aranha")
	afirmar(rasa.modulate.v > prof.modulate.v and prof.modulate.v > abis.modulate.v,
			"brilho: %f %f %f" % [rasa.modulate.v, prof.modulate.v, abis.modulate.v])
	afirmar(abis.modulate.b > abis.modulate.r, "fundo fica azulado")
	rasa.free(); prof.free(); abis.free()

func test_luzes_brilham_no_escuro():
	var luz = _cardume("peixe_lanterna"); var comum = _cardume("tainha")
	afirmar(luz.material != null, "bioluminescente ignora a escuridão da noite")
	afirmar(comum.material == null, "os outros escurecem com a noite")
	luz.free(); comum.free()

func test_silhueta_do_peixe_e_desenhavel():
	for tam in [3.0, 9.0, 24.0]:
		var formas: Array = C.forma_peixe(tam)
		afirmar(formas.size() >= 2, "corpo e cauda")
		for f in formas:
			afirmar(not Geometry2D.triangulate_polygon(f).is_empty(), "polígono triangulável (tam %s)" % tam)
