extends "res://testes/caso_teste.gd"
const P = preload("res://logica/pesca.gd")
const E = preload("res://logica/especies.gd")
const M = preload("res://logica/mapa.gd")
const MK = preload("res://logica/mercado.gd")
const MD = preload("res://logica/medidor.gd")

var l; var mundo
func _init(): l = E.carregar(); mundo = MK.carregar_dados().mundo

func _rng(s := 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_motivo_bloqueio():
	igual(P.motivo_bloqueio(50.0, 10.0, 150.0, "rasa", 0), "", "pode")
	igual(P.motivo_bloqueio(91.0, 10.0, 150.0, "rasa", 0), "longe", "mais de 90 px")
	igual(P.motivo_bloqueio(50.0, 45.0, 150.0, "rasa", 0), "rapido", "30% da máxima")
	igual(P.motivo_bloqueio(50.0, -45.0, 150.0, "rasa", 0), "rapido", "de ré também conta")
	igual(P.motivo_bloqueio(50.0, 10.0, 150.0, "rasa", 1), "vara", "vara rasa em profunda")
	igual(P.motivo_bloqueio(50.0, 10.0, 150.0, "abissal", 2), "", "vara abissal alcança tudo")
	afirmar(P.texto_bloqueio("vara").contains("Vara fraca"), "texto da spec")
	afirmar(P.texto_bloqueio("rapido") != "" and P.texto_bloqueio("longe") != "", "os outros têm texto")

func test_preparar_monta_o_medidor():
	var atum := E.por_id(l, "atum"); var mero := E.por_id(l, "mero")
	var p: Dictionary = P.preparar(atum, _rng(), 0)
	afirmar(p.f >= 0.0 and p.f <= 1.0, "f previsto: %f" % p.f)
	perto(p.medidor.periodo, 1.6, 1e-6, "período de comum")
	perto(p.medidor.verde, MD.largura_verde("comum", p.f, 0), 1e-6, "verde pela fórmula")
	perto(p.medidor.dourada, p.medidor.verde * 0.25, 1e-6, "dourada = 25% da verde")
	var q: Dictionary = P.preparar(mero, _rng(), 0)
	perto(q.medidor.periodo, 0.8, 1e-6, "lendária é mais rápida")
	afirmar(q.medidor.verde < p.medidor.verde, "lendária tem verde menor")
	var r: Dictionary = P.preparar(atum, _rng(), 5)
	afirmar(r.medidor.verde > p.medidor.verde, "Pescador alarga a verde")

func test_concluir():
	var atum := E.por_id(l, "atum")
	var p: Dictionary = P.preparar(atum, _rng(3), 0)
	igual(P.concluir(atum, p, "erro", _rng()), {}, "errou: nada")
	var v: Dictionary = P.concluir(atum, p, "verde", _rng())
	igual(v.especie, "atum", "espécie"); perto(v.f, p.f, 1e-9, "verde usa o previsto")
	for s in 20:
		var d: Dictionary = P.concluir(atum, p, "dourada", _rng(s))
		afirmar(d.f >= p.f - 1e-9, "dourada nunca piora (semente %d)" % s)

func test_novo_cardume():
	var sard := E.por_id(l, "sardinha")
	var c: Dictionary = P.novo_cardume(sard, Vector2(10, 20), _rng())
	igual(c.especie, "sardinha", "espécie"); igual(c.tentativas, 3, "3 tentativas")
	igual(c.zona, 0, "zona"); igual(c.estilo, "bola", "estilo"); igual(c.pos, Vector2(10, 20), "posição")
	afirmar(c.qtd >= 20 and c.qtd <= 40, "qtd: %d" % c.qtd)

func test_ponto_de_nascimento_na_agua():
	var r := _rng(11); var lim := float(mundo.mapa.limite)
	for centro in [Vector2(0, 680), Vector2(3000, 2500), Vector2(lim - 200, lim - 200), Vector2(-9900, 9220)]:
		for i in 40:
			var p: Vector2 = P.ponto_de_nascimento(mundo, centro, r, 1100.0, 1700.0)
			if p == Vector2.INF: continue
			afirmar(M.zona_da_celula(mundo, p) != M.TERRA, "na água: %s" % str(p))
			afirmar(absf(p.x) < lim - 300 and absf(p.y) < lim - 300, "dentro do mapa: %s" % str(p))
			var d := p.distance_to(centro)
			afirmar(d >= 1100.0 - 1e-3 and d <= 1700.0 + 1e-3, "entre os raios: %f" % d)
	var so_terra := {"cidades": [{"id": "x", "pos": [0, 0], "raio_ilha": 99999}], "mapa": {"celula": 128, "limite": 20480}}
	igual(P.ponto_de_nascimento(so_terra, Vector2.ZERO, r, 100.0, 200.0), Vector2.INF, "sem água: INF")

func test_usa_rede():
	afirmar(P.usa_rede(true, "bola") and P.usa_rede(true, "luzes_nuvem"), "estilos de rede")
	afirmar(not P.usa_rede(false, "bola"), "sem rede comprada")
	afirmar(not P.usa_rede(true, "grupo"), "outros estilos usam vara")

func test_proxima_vara():
	igual(P.proxima_vara(["rasa"], "rasa"), "rasa", "só uma")
	igual(P.proxima_vara(["rasa", "profunda"], "rasa"), "profunda", "avança")
	igual(P.proxima_vara(["rasa", "profunda"], "profunda"), "rasa", "dá a volta")
	igual(P.proxima_vara(["profunda", "rasa", "abissal"], "abissal"), "rasa", "ordem: rasa, profunda, abissal")
	igual(P.vara_valida(["rasa", "profunda"], "abissal"), "profunda", "equipada que não tem: volta para a melhor")
	igual(P.vara_valida(["rasa"], "rasa"), "rasa", "válida fica")
	igual(P.vara_valida([], "x"), "rasa", "sem nada: rasa")
