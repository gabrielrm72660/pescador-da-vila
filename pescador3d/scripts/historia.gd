extends Node
## v0.7.0: a história final — o compadre Bento, dono do Estrela d'Alva antes de você, sumiu numa noite de bruma.
## As missões 22 a 24 (scripts/missoes.gd) contam a história pelos NPCs. Aqui fica o que acontece no mar:
##  - "pagina": nas noites de bruma, chegar perto de um vulto o desfaz e deixa uma página molhada do diário (5 ao todo);
##  - "sino": numa noite de bruma, a oeste de São Pedro, toca um sino de verdade (som 3D: dá para segui-lo de ouvido) e
##    há um barco parado com a lanterna acesa. Perto dele, a conversa com o Bento e a escolha:
##      0 = levar a lanterna ao farol: a bruma "amansa" para sempre (sem vultos, sem bússola louca), a viagem continua;
##      1 = ficar na bruma: a viagem acaba e recomeça com outro pescador; nas próximas, o Estrela d'Alva vira um dos vultos.

const SINO_POS := Vector3(-1750.0, 0.0, 160.0)       # a oeste do arquipélago de São Pedro, fora da carta
const DIST_ENCONTRO := 30.0
const ARQ_LEGADO := "user://bruma_legado.cfg"
const Final = preload("res://scripts/final.gd")
const T = preload("res://scripts/idioma.gd")

const PAGINAS := [
    "Terceira noite de bruma. A bússola girou sozinha e o radar mostrou um cardume enorme. Joguei a rede: não tinha nada. A bruma mente.",
    "Os vultos não são barcos. Chamei um deles, e ele respondeu com a voz do Zeca, que se perdeu faz dez anos. Não chamei mais.",
    "Pesquei um peixe-lua. Ele só sobe quando a bruma chama. Tem uma luz fraca por dentro, como lamparina.",
    "Ouvi o sino de novo. Vem do oeste de São Pedro, onde a carta não mostra nada. Quem toca sino no meio do mar?",
    "Vou atrás do sino. Se eu não voltar, Jacinto, cuide do Estrela d'Alva. E diga ao Abílio para nunca apagar o farol.",
]
const FALAS_BENTO := [
    "Então foi você que ficou com o meu Estrela d'Alva. Está bem cuidada.",
    "Eu segui o sino até aqui, três anos atrás. Agora quem toca sou eu: alguém precisa avisar os barcos.",
    "Os vultos que você viu são os que se perderam. Só querem achar o caminho de volta.",
    "Esta lanterna me prende aqui. Se alguém a levar a um farol, a bruma solta todos nós.",
    "Ou você pode ficar. O mar daqui é calmo, e ninguém tem pressa.",
]
const OPCOES := ["Levar a lanterna ao farol", "Ficar na bruma com o Bento"]

var jogo: Node
var paginas: int = 0                 # páginas do diário já achadas (0..5)
var final: String = ""               # "", "luz" ou "bruma"
var legado: bool = false             # um final "bruma" já aconteceu neste computador
var _barco_bento: Node3D
var _sino: AudioStreamPlayer3D
var _prox_sino: float = 0.0
var _encontro := false
var _noite_avisada: int = -1
var _legado_avisado: int = -1

func construir(jogo_: Node) -> void:
    jogo = jogo_
    name = "Historia"
    var cfg := ConfigFile.new()
    if cfg.load(ARQ_LEGADO) == OK:
        legado = bool(cfg.get_value("legado", "estrela_na_bruma", false))
    jogo.fantasmas.desfeito.connect(_ao_desfazer)
    jogo.fantasmas.vulto_nasceu.connect(_ao_nascer_vulto)
    jogo.interface.dialogo.escolheu.connect(_ao_escolher)

func zerar() -> void:
    paginas = 0
    final = ""
    _encontro = false
    _sumir_bento()
    aplicar_final()

## O que o final "luz" muda no mundo (também ao carregar a viagem).
func aplicar_final() -> void:
    var mansa: bool = final == "luz"
    jogo.clima.bruma_mansa = mansa
    jogo.fantasmas.desligados = mansa
    if mansa:
        jogo.fantasmas.limpar()

func _missao(tipo: String) -> bool:
    var m: Dictionary = jogo.missoes.atual()
    return not m.is_empty() and String(m.tipo) == tipo and jogo.missoes.oferecidas.has(jogo.missoes.indice)

# ---------------------------------------------------------------- páginas do diário

func _ao_desfazer(tipo: String) -> void:
    if tipo != "vulto" or not _missao("pagina") or paginas >= PAGINAS.size():
        return
    var texto: String = PAGINAS[paginas]
    paginas += 1
    jogo.interface.caderno.paginas_bento = paginas
    jogo.missoes.evento("pagina")
    jogo.interface.aviso(T.t("Página do diário do Bento: %d de %d.") % [paginas, PAGINAS.size()])
    jogo.abrir_falas([{"npc": "diario", "texto": T.t(texto), "chave": texto}])
    jogo.salvar()

func _ao_nascer_vulto() -> void:
    if legado and _legado_avisado != jogo.clima.dias:
        _legado_avisado = jogo.clima.dias
        jogo.interface.aviso(T.t("Um vulto passa na bruma. No casco, mal dá para ler: ESTRELA D'ALVA."))

# ---------------------------------------------------------------- o sino e o Bento

func _process(delta: float) -> void:
    if jogo == null or not jogo.iniciado or jogo.no_titulo:
        return
    var ativo: bool = _missao("sino") and float(jogo.clima.bruma) > 0.55 and final == ""
    jogo.som.sino_ambiente = not ativo
    if not ativo:
        if _barco_bento != null and float(jogo.clima.bruma) < 0.3:
            _sumir_bento()
        return
    if _noite_avisada != jogo.clima.dias:
        _noite_avisada = jogo.clima.dias
        jogo.interface.aviso(T.t("Na bruma, um sino toca longe, a oeste de São Pedro."))
    if _barco_bento == null:
        _criar_bento()
    var p: Vector3 = jogo.barco.global_position
    var d: float = Vector2(p.x - SINO_POS.x, p.z - SINO_POS.z).length()
    # o barco parado, com a lanterna: aparece de perto, como os vultos, mas não se desfaz
    var mat: StandardMaterial3D = _barco_bento.get_meta("material")
    var visivel: float = 1.0 - smoothstep(110.0, 260.0, d)
    mat.albedo_color = Color(Color(0.02, 0.04, 0.06).lerp(Color(0.27, 0.35, 0.37), smoothstep(30.0, 200.0, d) * 0.8), 0.9 * visivel)
    var lm: StandardMaterial3D = _barco_bento.get_node("Lampada").material_override
    lm.albedo_color = Color(1.0, 0.86, 0.55, (0.95 if d < 420.0 else 0.0) * (0.85 + 0.15 * sin(Time.get_ticks_msec() / 260.0)))
    _barco_bento.position.y = 0.05 + 0.12 * sin(Time.get_ticks_msec() / 1300.0)
    # o sino bate a cada poucos segundos; é som 3D, então dá para saber de que lado vem
    _prox_sino -= delta
    if _prox_sino <= 0.0 and d < 1600.0:
        _prox_sino = randf_range(4.5, 6.5)
        _sino.pitch_scale = randf_range(0.96, 1.03)
        _sino.play()
    if d < DIST_ENCONTRO and not _encontro and not jogo.interface.dialogo_ativo():
        _encontro = true
        jogo.barco.velocidade = 0.0
        var falas: Array = []
        for k in FALAS_BENTO.size():
            var f: Dictionary = {"npc": "bento", "texto": T.t(FALAS_BENTO[k]), "chave": FALAS_BENTO[k]}
            if k == FALAS_BENTO.size() - 1:
                f["opcoes"] = OPCOES
            falas.append(f)
        jogo.abrir_falas(falas)

func _criar_bento() -> void:
    _barco_bento = jogo.fantasmas._construir_barco_fantasma()
    _barco_bento.name = "BarcoDoBento"
    _barco_bento.position = SINO_POS
    _barco_bento.rotation.y = 1.2
    var lamp: Node3D = _barco_bento.get_node("Lampada")
    lamp.scale = Vector3.ONE * 1.7
    jogo.add_child(_barco_bento)
    _sino = AudioStreamPlayer3D.new()
    _sino.stream = load("res://assets/sons/sino_bruma.ogg")
    _sino.bus = "Sino" if AudioServer.get_bus_index("Sino") != -1 else "Master"
    _sino.unit_size = 70.0
    _sino.max_distance = 1700.0
    _sino.volume_db = 2.0
    _sino.position = Vector3(0.0, 6.0, 0.0)
    _barco_bento.add_child(_sino)
    _prox_sino = 1.0

func _sumir_bento() -> void:
    if _barco_bento != null:
        _barco_bento.queue_free()
        _barco_bento = null
        _sino = null

## Fim da conversa sem escolher (ESC não pula a escolha, mas a conversa pode cair): deixa tentar de novo ao se afastar.
func _physics_process(_delta: float) -> void:
    if _encontro and final == "" and not jogo.interface.dialogo_ativo() and jogo.barco != null:
        var p: Vector3 = jogo.barco.global_position
        if Vector2(p.x - SINO_POS.x, p.z - SINO_POS.z).length() > DIST_ENCONTRO + 25.0:
            _encontro = false

# ---------------------------------------------------------------- os dois finais

func _ao_escolher(k: int) -> void:
    if not _encontro or final != "":
        return
    if k == 0:
        final = "luz"
        _sumir_bento()
        jogo.missoes.evento("sino")
        aplicar_final()
        jogo.salvar()
        _cartao("A LUZ DO FAROL",
                "Você levou a lanterna do Bento até São Pedro. Naquela noite o farol brilhou como nunca, e de manhã a bruma tinha ido embora.\n\nAinda sobe neblina do mar de vez em quando, mas a bússola não gira mais e os vultos não voltaram. Seu Abílio jura que, nas noites mais escuras, o sino ainda toca baixinho, longe, como quem se despede.\n\nO Estrela d'Alva é seu. O mar também.",
                "Continuar a viagem", func(): pass)
    else:
        final = "bruma"
        _sumir_bento()
        legado = true
        var cfg := ConfigFile.new()
        cfg.load(ARQ_LEGADO)
        cfg.set_value("legado", "estrela_na_bruma", true)
        cfg.save(ARQ_LEGADO)
        _cartao("O SINO",
                "Você desligou o motor e ficou. O mar ali era calmo, e ninguém tinha pressa.\n\nNa manhã seguinte, no cais da Vila do Porto, Seu Jacinto entregou as chaves de um barco a um rapaz recém-chegado.\n\nNas noites de bruma, os pescadores juram ver passar um vulto com o nome ESTRELA D'ALVA no casco. E, ao longe, um sino.",
                "Recomeçar", func(): jogo.reiniciar())

func _cartao(titulo: String, texto: String, botao: String, depois: Callable) -> void:
    var c: Control = Final.new()
    jogo.interface.raiz.add_child(c)
    jogo.interface.final_ativo = true
    c.mostrar(jogo.interface, T.t(titulo), T.t(texto), T.t(botao))
    c.fechou.connect(func():
        jogo.interface.final_ativo = false
        c.queue_free()
        depois.call())
