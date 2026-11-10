extends "res://testes/caso_teste.gd"
## Testes das correções da revisão final da fase 1.
const E = preload("res://logica/especies.gd")
const MK = preload("res://logica/mercado.gd")
const MI = preload("res://logica/missoes.gd")
const P = preload("res://logica/porao.gd")
const C = preload("res://logica/catalogo.gd")

var d; var l
func _init(): d = MK.carregar_dados(); l = E.carregar()


# Importante 1 — dados inválidos são apontados pelo próprio jogo
func test_validar_especies_aponta_erros():
	var boa: Dictionary = E.por_id(l, "atum").duplicate()
	var invertida := boa.duplicate(); invertida.id = "x1"; invertida.tam_min = 50.0; invertida.tam_max = 10.0
	var sem_zona := boa.duplicate(); sem_zona.id = "x2"; sem_zona.erase("zona")
	var zona_ruim := boa.duplicate(); zona_ruim.id = "x3"; zona_ruim.zona = 5
	var erros = E.validar([boa, invertida, sem_zona, zona_ruim])
	igual(erros.size(), 3, "três erros: %s" % str(erros))
	afirmar(str(erros).contains("x1") and str(erros).contains("x2") and str(erros).contains("x3"), "nomeia a espécie")

func test_validar_cidades_e_missoes():
	var ruim: Dictionary = d.duplicate(true)
	ruim.cidades.cidades[0].mult_zona = [1.0, 1.0]
	ruim.cidades.cidades[1].zonas_pedidos = [3]
	afirmar(MK.validar_dados(ruim).size() >= 2, "mult_zona curto e zona pedida inválida")
	igual(MK.validar_dados(d), [], "dados reais válidos")
	var cfg: Dictionary = MI.config().duplicate(true)
	cfg.encomenda.qtd = [5, 2]
	afirmar(not MI.validar_config(cfg).is_empty(), "faixa invertida")
	igual(MI.validar_config(MI.config()), [], "config real válida")


# Importante 2 — recompensa usa o preço de venda da cidade
func test_encomenda_paga_sobre_o_preco_da_cidade():
	var p = P.new(400.0); var atum = E.por_id(l, "atum")
	var a = E.exemplar_com_f(atum, 0.5); var b = E.exemplar_com_f(atum, 0.5)
	p.adicionar(a); p.adicionar(b)
	var m = {"id": "pn", "tipo": "encomenda", "cidade": "ponta_negra", "especie": "atum", "qtd": 2,
			"classe_min": "P", "prazo_dia": 5, "recompensa_xp": 20}
	var r = MI.entregar(d, m, p, l, "ponta_negra", 1, C.new())
	var venda = MK.preco_venda(a, atum, MK.cidade(d, "ponta_negra")) * 2
	igual(r.reais, roundi(1.5 * venda), "1,5× a venda em Ponta Negra")
	afirmar(r.reais > venda, "vale mais que vender")


# Importante 3 — ciclo de vida das missões
func test_nao_aceita_repetida_nem_vencida():
	var p = P.new(100.0); var ativas := []
	var ex = {"id": "x-1-0", "tipo": "exploracao", "cidade": "porto_farol", "pos": [0, 0], "recompensa": 150,
			"prazo_dia": -1, "recompensa_xp": 25}
	afirmar(MI.aceitar(d, ativas, ex, p, 1), "aceita a primeira")
	afirmar(not MI.aceitar(d, ativas, ex.duplicate(), p, 1), "recusa a mesma de novo")
	var velha = {"id": "v", "tipo": "trofeu", "cidade": "porto_farol", "especie": "robalo", "tam_min": 90.0,
			"prazo_dia": 2, "recompensa_xp": 40}
	afirmar(not MI.aceitar(d, ativas, velha, p, 3), "recusa oferta vencida")
	igual(ativas.size(), 1, "só uma ativa")

func test_expirar_remove_missao_e_carga():
	var p = P.new(100.0); var ativas := []
	var ent = {"id": "e1", "tipo": "entrega", "cidade": "ponta_negra", "destino": "ponta_negra", "volume": 30.0,
			"recompensa": 840, "prazo_dia": 2, "recompensa_xp": 15}
	MI.aceitar(d, ativas, ent, p, 1)
	var removidas = MI.expirar(ativas, p, 3)
	igual(removidas.size(), 1, "uma removida"); igual(ativas.size(), 0, "vaga liberada")
	perto(p.usado(), 0.0, 1e-6, "carga saiu do porão")


# Importante 4 — nenhum peixe vale R$ 0
func test_peixe_minimo_vale_um_real():
	igual(E.exemplar_com_f(E.por_id(l, "peixe_lanterna"), 0.0).valor, 1, "lanterna pequeno vale R$ 1")


# ---- Revisão final da fase 2 ----
const NV = preload("res://logica/navegacao.gd")
const MP = preload("res://logica/mapa.gd")

func _mundo2():
	var m = load("res://cenas/Mundo.tscn").instantiate()
	m.iniciar()
	return m

# Importante 1 — o barco não fica preso na costa: só perde embalo o que vai CONTRA a parede
func test_freio_de_colisao_so_contra_a_parede():
	var frente := Vector2.RIGHT
	perto(NV.freio_colisao(100.0, frente, Vector2.LEFT), 60.0, 1e-6, "de frente perde 40%")
	perto(NV.freio_colisao(100.0, frente, Vector2.UP), 100.0, 1e-6, "raspando de lado não perde")
	perto(NV.freio_colisao(-30.0, frente, Vector2.LEFT), -30.0, 1e-6, "de ré, saindo da parede, não perde")
	perto(NV.freio_colisao(-30.0, frente, Vector2.RIGHT), -18.0, 1e-6, "de ré contra a parede perde")
	var meio := NV.freio_colisao(100.0, frente, Vector2(-1, -1).normalized())
	afirmar(meio > 60.0 and meio < 100.0, "em ângulo perde só uma parte: %f" % meio)

# Importante 2 — acabar o combustível avisa e manda abrir a vela
func test_sem_combustivel_avisa():
	var m = _mundo2(); var b = m.barco
	b.atracado = false; b.marcha = 4; b.combustivel = 0.05
	var antes: int = m.aviso_id
	for i in 5:
		b.passo(0.1, {}, 0.0, 1.0, 0.0)
	igual(b.combustivel, 0.0, "acabou")
	afirmar(m.aviso_id == antes + 1, "avisou uma vez só: %d" % (m.aviso_id - antes))
	afirmar(m.aviso.to_lower().contains("combustível") and m.aviso.contains("vela"), "aviso: %s" % m.aviso)
	m.free()

# Importante 3 — a borda do mundo avisa e a câmera não mostra o vazio
func test_borda_do_mundo_avisa_e_limita_a_camera():
	var m = _mundo2(); var b = m.barco
	var lim := float(m.mundo.mapa.limite)
	afirmar(not MP.perto_da_borda(m.mundo, Vector2.ZERO), "o centro não é borda")
	afirmar(MP.perto_da_borda(m.mundo, Vector2(lim - 100, 0)), "leste")
	afirmar(MP.perto_da_borda(m.mundo, Vector2(0, -lim + 100)), "norte")
	var cam: Camera2D = b.get_node("Camera2D")
	igual(cam.limit_right, int(lim), "limite da câmera à direita")
	igual(cam.limit_top, -int(lim), "limite da câmera em cima")
	b.atracado = false; b.position = Vector2(lim - 100, 0)
	var antes: int = m.aviso_id
	m.avancar_tempo(0.1); m.avancar_tempo(0.1)
	igual(m.aviso_id, antes + 1, "avisa ao chegar, não a cada quadro")
	afirmar(m.aviso.contains("águas conhecidas"), "aviso: %s" % m.aviso)
	b.position = Vector2.ZERO; m.avancar_tempo(0.1)
	b.position = Vector2(lim - 100, 0); m.avancar_tempo(0.1)
	igual(m.aviso_id, antes + 2, "avisa de novo se voltar à borda")
	m.free()

# Menor — a zona do painel segue os tiles (célula inteira), não o ponto exato
func test_zona_da_celula_bate_com_o_tile():
	var mundo: Dictionary = MK.carregar_dados().mundo
	var cel := float(mundo.mapa.celula)
	for p in [Vector2(2238, -7266), Vector2(10, 10), Vector2(-3500, -3000), Vector2(3000.5, 3000.5)]:
		var centro := Vector2(floorf(p.x / cel) * cel + cel / 2.0, floorf(p.y / cel) * cel + cel / 2.0)
		igual(MP.zona_da_celula(mundo, p), MP.zona_em(mundo, centro), "ponto %s" % str(p))
	igual(MP.zona_em(mundo, Vector2(2238, -7266)), MP.TERRA, "o ponto exato cai no círculo de terra")
	afirmar(MP.zona_da_celula(mundo, Vector2(2238, -7266)) != MP.TERRA, "mas o tile ali é água, e o painel segue o tile")
