extends Control
## HUD pintado: tudo desenhado por código (sem imagens), no layout da arte de interface do jogo.
## Placa do barco e motor, bússola em fita, missão, radar, velocímetro, aviso e barra de botões.
## Só mostra o que o jogo realmente tem; quem preenche os dados é scripts/interface.gd.

signal botao(nome: String)
signal devolveu(item: Dictionary)      # o jogador jogou um peixe do porão de volta ao mar

const Cardumes = preload("res://scripts/cardumes.gd")
const Aq = preload("res://scripts/aquarela.gd")
const T = preload("res://scripts/idioma.gd")
const TINTA := Color(0.075, 0.125, 0.19, 0.90)        # azul-marinho das pinceladas
const CREME := Color(0.96, 0.93, 0.84)
const DOURADO := Color(0.98, 0.76, 0.33)
const VERDE := Color(0.33, 0.83, 0.66)
const LARANJA := Color(0.96, 0.62, 0.24)
const APAGADO := Color(0.55, 0.62, 0.66, 0.55)
const BOTOES := ["pescar", "porao", "caderno", "diario"]           # a pausa saiu da barra: é o ESC
const DICA := {"pescar": "Pescar  [F]", "porao": "Porão  [I]", "diario": "Livro do Pescador  [TAB]", "caderno": "Peixes  [P]"}
const TAM_BOTAO := 74.0
const PONTOS := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]

## Tamanho da interface: 1.0 é o desenho original (grande); 0.62 deixa a tela livre para o mar.
## Cada bloco encolhe em direção ao seu canto.
@export_range(0.4, 1.2, 0.01) var escala: float = 0.62

var nome_barco := "Estrela d'Alva"
var rumo := 0.0                 # graus, 0 = norte
var nos := 0.0
var fracao_motor := 0.0         # 0..1: quanto do motor está em uso (velocímetro)
var saude := 100.0              # saúde do casco (0..100): a barra da placa do barco
var distancia := 0.0
var missao_titulo := "Primeira Missão"
var missao_texto := "Pescaria inaugural (0/3)"
var missao_feita := false
var estado_pesca := ""
var pesca_ativa := false        # linha na água ou peixe fisgado: o anzol acende
var aviso_texto := ""
var aviso_tempo := 0.0          # segundos que o aviso ainda fica na tela
var dinheiro := 0
var hora := ""                   # "14:30", ao lado do dinheiro
var noite := 0.0                # 0 dia ... 1 noite: troca o sol pela lua no relógio
var cais_rel := Vector2.INF     # posição do cais em relação ao barco (m a boreste, m à frente); INF = sem cais
var cais_dist := 0.0
var dica := ""                  # texto fixo acima dos botões (ex.: "E: atracar no cais")
var combustivel := 1.0          # 0..1 do tanque
var litros := 0.0
var especies_destaque: Array = []   # v0.6.0: espécies que a missão atual pede: piscam no radar
var radar_alvos: Array = []     # {pos: Vector2(m a boreste, m à frente), mundo: Vector2(x, z), grande: bool}
var barco_ref: Node3D = null     # o radar lê a posição e o rumo do barco a cada quadro (gira sem engasgar)
var radar_ilhas: Array = []     # por ilha: {centro, raio, raso, linha, alto: contornos no mundo, cais: [inicio, ponta]}
var cais_mundo := Vector2.INF   # ponta do cais mais próximo (x, z no mundo)
var destino_mundo := Vector2.INF   # v0.8.2: destino marcado na carta (x, z no mundo); INF = sem rota
var radar_boias: Array = []     # boias de sinalização: {mundo: Vector2(x, z), cor: Color}
var alcance_radar: float = 150.0    # metros até a borda do radar
var instavel: float = 0.0       # v0.6.0: 0..1, bruma longe das ilhas: a bússola oscila e o radar chia
var assombro: float = 0.0       # v0.8.7: o medo (scripts/assombro.gd): a lamparina escurece e a chama esverdeia
var sombra_radar: float = 0.0   # v0.8.7: s em que a coisa de baixo aparece no radar
var _tex_lamparina: Texture2D
var _tex_coisa: Texture2D
var _sprites_aberrantes: Dictionary = {}
var painel_aberto := ""         # "", "porao" ou "diario"
var linhas_painel: Array = []
var titulo_painel := ""
var porao: Node = null           # scripts/porao.gd: a grade do painel do porão
var _na_mao: Dictionary = {}     # peixe do porão que o jogador pegou para mudar de lugar
var _rot_mao: int = 0
var _mouse := Vector2.ZERO
const CASA := 50.0               # lado de uma casa da grade (px, antes de encolher)
var pesca: Node = null           # scripts/pesca.gd: o anel do minijogo é lido direto dele, a cada quadro

var _fonte: Font
var _fonte_titulo: Font
var _lav: Array = []                # lavagens de aquarela (ColorRect atrás do desenho): uma por cartão, reaproveitadas a cada quadro
var _lav_sig: Array = []
var _lav_n := 0
var _orig := Vector2.ZERO           # transformação de desenho atual (ver _ancorar): para pôr as lavagens no lugar certo da tela
var _esc := 1.0
var _sprites_peixes: Dictionary = {}
var _pop_texto: String = ""       # "PERFEITO!", "BOM!", "ERROU": sobe e some acima do anel
var _pop_tempo: float = 0.0
var _pop_cor: Color = Color.WHITE
var _brilho_antes: float = 0.0
var _trava_antes: float = 0.0
var _textura_madeira: Texture2D = null
var _textura_casa: Texture2D = null
var _sobre := ""                # botão sob o mouse

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_PASS
    _fonte = Aq.FONTE_TEXTO
    _fonte_titulo = Aq.FONTE_TITULO
    var dir_sprites := "res://assets/texturas/peixes/porao/"
    for especie in Cardumes.ESPECIES:
        var arquivo: String = dir_sprites + Cardumes.slug(especie) + ".png"
        if ResourceLoader.exists(arquivo):
            _sprites_peixes[especie] = load(arquivo)
    for especie in Cardumes.ESPECIES:                     # v0.8.7: a versão aberrante de cada peixe
        var arq_ab: String = "res://assets/texturas/peixes/aberrante/" + Cardumes.slug(especie) + ".png"
        if ResourceLoader.exists(arq_ab):
            _sprites_aberrantes[especie] = load(arq_ab)
    if ResourceLoader.exists("res://assets/texturas/bruma/lamparina.png"):
        _tex_lamparina = load("res://assets/texturas/bruma/lamparina.png")
    if ResourceLoader.exists("res://assets/texturas/bruma/coisa.png"):
        _tex_coisa = load("res://assets/texturas/bruma/coisa.png")
    _textura_madeira = load("res://assets/texturas/inventario/forro_madeira.png")
    _textura_casa = load("res://assets/texturas/inventario/casa_porao.png")

func _process(delta: float) -> void:
    aviso_tempo = maxf(0.0, aviso_tempo - delta)
    _pop_tempo = maxf(0.0, _pop_tempo - delta)
    if pesca != null:
        if pesca.brilho > _brilho_antes + 0.2:                 # acabou de acertar
            _pop_texto = T.t("PERFEITO!") if pesca.ultimo_perfeito else T.t("BOM!")
            _pop_cor = DOURADO if pesca.ultimo_perfeito else VERDE.lightened(0.35)
            _pop_tempo = 0.9
        elif pesca.trava > _trava_antes + 0.2:                 # acabou de errar
            _pop_texto = T.t("ERROU")
            _pop_cor = Color(0.95, 0.40, 0.32)
            _pop_tempo = 0.7
        _brilho_antes = pesca.brilho
        _trava_antes = pesca.trava
    queue_redraw()

# ------------------------------------------------------------------ botões

## Encolhe o que for desenhado a seguir em direção a um ponto da tela (0,0 = canto de cima à esquerda;
## 0.5,1 = meio da borda de baixo; 1,1 = canto de baixo à direita).
func _ancorar(ax: float, ay: float, fator: float = -1.0) -> void:
    var e := escala if fator < 0.0 else fator
    _orig = Vector2(size.x * ax, size.y * ay) * (1.0 - e)
    _esc = e
    draw_set_transform(_orig, 0.0, Vector2(e, e))

## Onde o botão está na tela de verdade (depois de encolhido), para o clique acertar.
func ret_botao_na_tela(indice: int) -> Rect2:
    var r := ret_botao(indice)
    var origem := Vector2(size.x * 0.5, size.y) * (1.0 - escala)
    return Rect2(origem + r.position * escala, r.size * escala)

func ret_botao(indice: int) -> Rect2:
    var largura := BOTOES.size() * TAM_BOTAO + (BOTOES.size() - 1) * 26.0
    var x := size.x / 2.0 - largura / 2.0 + indice * (TAM_BOTAO + 26.0)
    return Rect2(x, size.y - 34.0 - TAM_BOTAO, TAM_BOTAO, TAM_BOTAO)

func _botao_em(p: Vector2) -> String:
    for i in BOTOES.size():
        if ret_botao_na_tela(i).has_point(p):
            return BOTOES[i]
    return ""

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        _sobre = _botao_em(event.position)
        _mouse = event.position
    elif painel_aberto == "porao" and event is InputEventMouseButton and event.pressed and _clique_no_porao(event):
        accept_event()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var nome := _botao_em(event.position)
        if nome != "":
            apertar(nome)
            accept_event()

func apertar(nome: String) -> void:
    botao.emit(nome)

# ------------------------------------------------------------------ desenho

func _draw() -> void:
    _lav_n = 0
    _ancorar(0.0, 0.0)
    _placa_barco()
    _ancorar(0.5, 0.0)
    _bussola()
    _ancorar(1.0, 0.0)
    _missao()
    _ancorar(0.0, 1.0)
    _radar()
    _ancorar(1.0, 1.0)
    _velocimetro()
    _ancorar(0.5, 1.0)
    _barra_botoes()
    _aviso()
    _ancorar(0.0, 0.5, minf(1.0, escala + 0.22))
    _anel_de_pesca()
    _ancorar(0.5, 0.5, minf(1.0, escala + 0.2))
    _painel()
    draw_set_transform(Vector2.ZERO)
    _orig = Vector2.ZERO
    _esc = 1.0
    for i in range(_lav_n, _lav.size()):
        _lav[i].visible = false

## Cartão de aquarela: uma lavagem de pigmento com borda que escorre, mancha e grão de papel (shaders/aquarela.gdshader).
## "cor" só dá a transparência (alfa); a cor vem do esquema ("pigmento", "mar", "ouro"...). À noite clareia e ganha um fio de luz.
func _pincelada(r: Rect2, semente: int, cor: Color = TINTA, nome_esquema: String = "pigmento", raio: float = -1.0, ajuste: Dictionary = {}) -> void:
    var esq: Dictionary = Aq.esquema(nome_esquema)
    var c1: Color = esq["cor"]
    var c2: Color = esq["cor2"]
    var extra: Dictionary = (esq["extra"] as Dictionary).duplicate()
    var alfa_base: float = float(extra.get("alfa", 0.9))
    extra["alfa"] = minf(1.0, alfa_base * cor.a / 0.9)
    if noite > 0.0:                                    # à noite o cartão clareia um pouco e ganha fio: senão some no mar escuro
        c1 = c1.lerp(Color(0.13, 0.21, 0.31), 0.75 * noite)
        c2 = c2.lerp(Color(0.10, 0.17, 0.26), 0.75 * noite)
        extra["alfa"] = lerpf(float(extra["alfa"]), maxf(float(extra["alfa"]), 0.94), noite)
        extra["tinta"] = Color(CREME, 0.5 * noite)
    if raio >= 0.0:
        extra["raio"] = raio
    for k in ajuste:
        extra[k] = ajuste[k]
    _lavagem(r, semente, c1, c2, extra)

func _lavagem(r: Rect2, semente: int, c1: Color, c2: Color, extra: Dictionary) -> void:
    var tela := Rect2(_orig + r.position * _esc, r.size * _esc)
    if _lav_n >= _lav.size():
        var novo := ColorRect.new()
        novo.show_behind_parent = true                 # a lavagem fica por baixo de tudo o que o HUD desenha
        novo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        novo.material = Aq.material(c1, c2, 1.0)
        add_child(novo)
        _lav.append(novo)
        _lav_sig.append(null)
    var no: ColorRect = _lav[_lav_n]
    var sig: Array = [tela, semente, c1, c2, extra, _esc]
    if _lav_sig[_lav_n] != sig:
        _lav_sig[_lav_n] = sig
        var folga := 22.0
        Aq.ajustar(no, tela, folga)
        var m: ShaderMaterial = no.material
        m.set_shader_parameter("cor", c1)
        m.set_shader_parameter("cor2", c2)
        m.set_shader_parameter("semente", float(semente) * 0.173)
        for k in extra:
            var v = extra[k]
            if k == "irregular" or k == "largura_borda" or k == "raio":
                v = float(v) * _esc
            m.set_shader_parameter(k, v)
    no.visible = true
    _lav_n += 1

func _texto(pos: Vector2, texto: String, tam: int, cor: Color = CREME, alinhar: int = HORIZONTAL_ALIGNMENT_LEFT, largura: float = -1.0, titulo: bool = false) -> void:
    var fonte: Font = _fonte_titulo if titulo else _fonte
    draw_string(fonte, pos + Vector2(1.6, 1.8), texto, alinhar, largura, tam, Color(0.02, 0.05, 0.09, 0.62 * cor.a))
    draw_string(fonte, pos, texto, alinhar, largura, tam, cor)

## Um traço de pincel horizontal: as bordas tremem de leve e as pontas são redondas.
func _traco(a: Vector2, b: Vector2, espessura: float, cor: Color, semente: float) -> void:
    var comp := a.distance_to(b)
    if comp < 1.0:
        return
    var n := maxi(6, int(comp / 8.0))
    var cima := PackedVector2Array()
    var baixo := PackedVector2Array()
    var meia := espessura * 0.5
    for i in n + 1:
        var t := float(i) / float(n)
        var ponta := clampf(minf(t, 1.0 - t) * comp / meia, 0.0, 1.0)
        var w := meia * (0.90 + 0.14 * sin(t * 11.0 + semente) + 0.06 * sin(t * 27.0 + semente * 2.0)) * sqrt(1.0 - (1.0 - ponta) * (1.0 - ponta))
        var p := a.lerp(b, t)
        cima.append(p + Vector2(0.0, -w))
        baixo.append(p + Vector2(0.0, w))
    baixo.reverse()
    cima.append_array(baixo)
    draw_colored_polygon(cima, cor)

func _barra(r: Rect2, fracao: float, cor: Color) -> void:
    var meia := r.size.y / 2.0
    var y := r.position.y + meia
    var x0 := r.position.x + meia
    var x1 := r.end.x - meia
    var sem := r.position.x * 0.13 + r.position.y * 0.07
    _traco(Vector2(x0 - meia * 0.6, y), Vector2(x1 + meia * 0.6, y), r.size.y + 3.0, Color(0.02, 0.05, 0.08, 0.62), sem)      # trilho: tinta escura
    _traco(Vector2(x0 - meia * 0.6, y), Vector2(x1 + meia * 0.6, y), r.size.y + 3.0, Color(CREME, 0.10), sem + 2.0)
    var f := clampf(fracao, 0.0, 1.0)
    if f > 0.01:
        var fim := x0 + (x1 - x0) * f
        _traco(Vector2(x0 - meia * 0.4, y), Vector2(fim + meia * 0.4, y), r.size.y - 2.0, cor, sem + 5.0)
        _traco(Vector2(x0, y - meia * 0.28), Vector2(maxf(x0 + 2.0, fim - meia * 0.3), y - meia * 0.28), maxf(2.0, r.size.y * 0.24), Color(1, 1, 1, 0.26), sem + 9.0)   # reflexo: papel aparecendo

func _placa_barco() -> void:
    _pincelada(Rect2(46, 30, 380, 58), 11)
    _pincelada(Rect2(46, 96, 300, 44), 12)
    _icone_barco(Vector2(118, 66), 1.0, CREME)
    _texto(Vector2(196, 77), T.t(nome_barco), 34, CREME, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
    # saúde do casco: boia salva-vidas, barra que vai do verde ao vermelho e o número
    var cor_saude: Color = VERDE if saude >= 60.0 else (DOURADO if saude >= 30.0 else Color(0.95, 0.36, 0.28))
    var pisca: bool = saude < 30.0 and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5
    _icone_boia(Vector2(88, 118), 12.5, Color(0.95, 0.36, 0.28) if pisca else CREME)
    _barra(Rect2(116, 108, 168, 20), saude / 100.0, cor_saude)
    _texto(Vector2(290, 127), "%d%%" % floori(saude), 22, cor_saude, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
    _pincelada(Rect2(46, 148, 190, 40), 13)
    _texto(Vector2(64, 179), "R$ %d" % dinheiro, 32, DOURADO, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
    if hora != "":                                             # relógio: sol de dia, lua à noite
        _pincelada(Rect2(46, 196, 150, 38), 14)
        var c := Vector2(72, 215)
        if noite > 0.5:
            draw_circle(c, 9.0, CREME)
            draw_circle(c + Vector2(5, -3), 8.0, TINTA.lightened(0.05))
        else:
            draw_circle(c, 6.5, DOURADO)
            for i in 8:
                var d := Vector2.from_angle(TAU * i / 8.0)
                draw_line(c + d * 9.0, c + d * 12.5, DOURADO, 2.0)
        _texto(Vector2(94, 225), hora, 26, CREME)
        if noite > 0.2 or assombro > 0.02:
            _lamparina(Vector2(222, 214))

## v0.8.7: a lamparina do medo. Calma: chama amarela e vidro claro. Com o Assombro subindo, a chama encolhe e esverdeia,
## o vidro escurece e, no fim, ela treme. Sem número: é para sentir, não para calcular.
func _lamparina(c: Vector2) -> void:
    var a: float = clampf(assombro, 0.0, 1.0)
    var t: float = Time.get_ticks_msec() / 1000.0
    var treme: float = (sin(t * 23.0) * 0.5 + sin(t * 37.0) * 0.5) * smoothstep(0.6, 1.0, a)
    var chama_cor: Color = Color(1.0, 0.78, 0.35).lerp(Color(0.45, 1.0, 0.78), smoothstep(0.25, 0.85, a))
    var chama: float = lerpf(1.0, 0.35, a) * (0.9 + 0.1 * sin(t * 9.0) + 0.25 * treme)
    var halo: float = lerpf(0.55, 0.18, a)
    draw_circle(c + Vector2(0, 2), 26.0 * chama + 6.0, Color(chama_cor, 0.18 * halo))
    if _tex_lamparina != null:
        var alt: float = 54.0
        var larg: float = alt * float(_tex_lamparina.get_width()) / float(_tex_lamparina.get_height())
        var escurece: float = lerpf(1.0, 0.55, a)
        draw_texture_rect(_tex_lamparina, Rect2(c - Vector2(larg * 0.5, alt * 0.56) + Vector2(treme * 1.5, 0), Vector2(larg, alt)), false, Color(escurece, escurece * 1.02, escurece * 1.05))
    else:
        draw_rect(Rect2(c + Vector2(-9, -16), Vector2(18, 26)), Color(CREME, 0.25))
        draw_rect(Rect2(c + Vector2(-9, -16), Vector2(18, 26)), CREME, false, 2.0)
        draw_line(c + Vector2(-6, -16), c + Vector2(0, -24), CREME, 2.0)
        draw_line(c + Vector2(6, -16), c + Vector2(0, -24), CREME, 2.0)
    # a chama, por cima do vidro
    var base := c + Vector2(treme * 1.5, 2.0)
    draw_colored_polygon(PackedVector2Array([base + Vector2(-4.0, 0) * chama, base + Vector2(0, -13.0) * chama, base + Vector2(4.0, 0) * chama, base + Vector2(0, 3.0) * chama]), Color(chama_cor, 0.9))
    draw_circle(base + Vector2(0, -2.0) * chama, 2.2 * chama, Color(1, 1, 0.92, 0.9))

## Erro da agulha na bruma, em graus (até ~11): três oscilações lentas somadas, nunca o mesmo valor por muito tempo.
func _tremor_bussola() -> float:
    var t: float = Time.get_ticks_msec() / 1000.0
    return 6.0 * sin(t * 0.8) + 3.5 * sin(t * 1.9 + 1.3) + 1.8 * sin(t * 4.7 + 0.4)

func _bussola() -> void:
    var cx := size.x / 2.0
    var meia := 226.0
    var y := 54.0
    _pincelada(Rect2(cx - meia, y - 16.0, meia * 2.0, 34.0), 21, Color(TINTA, 0.62))
    _pincelada(Rect2(cx - 42.0, 8.0, 84.0, 34.0), 22)
    var rumo_vis: float = rumo + instavel * _tremor_bussola()     # na bruma a agulha balança
    var cor_graus: Color = CREME if instavel < 0.3 else Color(CREME, 0.62 + 0.38 * sin(Time.get_ticks_msec() / 1000.0 * 7.0))
    _texto(Vector2(cx - 42.0, 36.0), "%03d°" % (posmod(int(round(rumo_vis)), 360)), 32, cor_graus, HORIZONTAL_ALIGNMENT_CENTER, 84.0, true)
    var px_por_grau := meia * 2.0 / 135.0                      # a fita mostra 135 graus
    draw_line(Vector2(cx - meia + 10.0, y + 14.0), Vector2(cx + meia - 10.0, y + 14.0), Color(CREME, 0.7), 1.5)
    var primeiro := int(floor((rumo_vis - 75.0) / 15.0)) * 15
    for g in range(primeiro, primeiro + 180, 15):
        var x := cx + (float(g) - rumo_vis) * px_por_grau
        if x < cx - meia + 14.0 or x > cx + meia - 14.0:
            continue
        var grau := posmod(g, 360)
        var apagar := clampf((meia - absf(x - cx)) / 70.0, 0.0, 1.0)   # some nas pontas da fita
        if grau % 45 == 0:
            draw_line(Vector2(x, y + 6.0), Vector2(x, y + 16.0), Color(CREME, apagar), 2.0)
            _texto(Vector2(x - 30.0, y + 6.0), T.t(PONTOS[grau / 45]), 21, Color(DOURADO if grau == 0 else CREME, apagar), HORIZONTAL_ALIGNMENT_CENTER, 60.0, true)
        else:
            draw_line(Vector2(x, y + 10.0), Vector2(x, y + 16.0), Color(CREME, apagar * 0.75), 1.5)
    draw_colored_polygon(PackedVector2Array([Vector2(cx, y + 4.0), Vector2(cx + 7.0, y + 14.0), Vector2(cx, y + 24.0), Vector2(cx - 7.0, y + 14.0)]), DOURADO)

func _missao() -> void:
    var x := size.x - 372.0
    var largura_util := 290.0
    # A linha de estado da pesca e longa ("PUXANDO · Equilibrada · tensao 0% · [J] tecnica"): se nao cabe, quebra em duas.
    var linhas: Array = _quebrar_para_caber(estado_pesca, 17, largura_util) if estado_pesca != "" else []
    var extra := 18.0 if linhas.size() > 1 else 0.0
    _pincelada(Rect2(x, 30, 326, 50), 31)
    _pincelada(Rect2(x, 86, 326, 62 + extra), 32)
    _icone_prancheta(Vector2(x + 30.0, 55.0), CREME)
    _texto(Vector2(x + 62.0, 66.0), missao_titulo, 30, DOURADO, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
    var caixa := Rect2(x + 22.0, 98.0, 16.0, 16.0)
    draw_rect(caixa, CREME, false, 2.0)
    if missao_feita:
        draw_polyline(PackedVector2Array([caixa.position + Vector2(3, 8), caixa.position + Vector2(7, 13), caixa.position + Vector2(15, 1)]), VERDE, 3.0)
    var tam_texto := 20
    while tam_texto > 12 and _fonte.get_string_size(missao_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam_texto).x > largura_util - 28.0:
        tam_texto -= 1
    _texto(Vector2(x + 50.0, 113.0), missao_texto, tam_texto, VERDE if missao_feita else CREME)
    for i in linhas.size():
        _texto(Vector2(x + 22.0, 138.0 + 18.0 * i), linhas[i], 16 if linhas.size() > 1 else 17, DOURADO if pesca_ativa else Color(CREME, 0.8))

## Quebra um texto de uma linha em ate duas, no separador (" · " ou " — ") mais perto do meio, e reduz a fonte
## se ainda assim nao couber. Devolve as linhas.
func _quebrar_para_caber(texto: String, tam: int, largura: float) -> Array:
    if _fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= largura:
        return [texto]
    var melhor := -1
    var melhor_dist := 9999
    for sep in [" · ", " — "]:
        var i := texto.find(sep)
        while i != -1:
            var d := absi(i - texto.length() / 2)
            if d < melhor_dist:
                melhor_dist = d
                melhor = i + sep.length()
            i = texto.find(sep, i + 1)
    if melhor == -1:
        return [texto]
    var a := texto.substr(0, melhor).rstrip(" ·—")
    var b := texto.substr(melhor).strip_edges()
    return [a, b]

## Metros (x a boreste, y à frente) de um ponto do mundo em relação ao barco.
func _rel_barco(mundo: Vector2) -> Vector2:
    var base: Basis = barco_ref.global_transform.basis
    var d := mundo - Vector2(barco_ref.global_position.x, barco_ref.global_position.z)
    return Vector2(d.dot(Vector2(base.x.x, base.x.z)), d.dot(Vector2(-base.z.x, -base.z.z)))

## v0.8.2: a rota marcada na carta, no radar: tracejado do barco até o destino (o mesmo vermelho da carta, mais
## claro para ler sobre o mar). Destino dentro do alcance: um X; fora: o traço vai até a borda e termina numa seta.
func _rota_radar(c: Vector2, raio: float) -> void:
    var cor := Color(0.96, 0.46, 0.32, 0.95)
    var rel := _rel_barco(destino_mundo)
    var p := Vector2(rel.x, -rel.y) / alcance_radar * raio
    var dentro: bool = p.length() <= raio - 12.0
    var fim: Vector2 = p if dentro else p.normalized() * (raio - 14.0)
    if fim.length() > 4.0:
        draw_dashed_line(c, c + fim, Color(TINTA, 0.7), 4.6, 9.0, true)
        draw_dashed_line(c, c + fim, cor, 2.4, 9.0, true)
    if dentro:
        for s in [-1.0, 1.0]:
            draw_line(c + p + Vector2(-6, -6 * s), c + p + Vector2(6, 6 * s), Color(TINTA, 0.8), 5.0)
            draw_line(c + p + Vector2(-6, -6 * s), c + p + Vector2(6, 6 * s), cor, 3.0)
    else:
        var d := p.normalized()
        var lat := Vector2(-d.y, d.x)
        var ponta := c + d * (raio - 4.0)
        draw_colored_polygon(PackedVector2Array([ponta, ponta - d * 12.0 + lat * 7.0, ponta - d * 12.0 - lat * 7.0]), cor)

## Contorno do mundo -> pixels do radar (proa para cima), cortado pelo círculo do radar.
func _poligono_radar(contorno: PackedVector2Array, c: Vector2, raio: float, disco: PackedVector2Array) -> Array:
    var pontos := PackedVector2Array()
    for pt in contorno:
        var r := _rel_barco(pt)
        pontos.append(c + Vector2(r.x, -r.y) / alcance_radar * raio)
    return Geometry2D.intersect_polygons(pontos, disco)

func _radar() -> void:
    var c := Vector2(150.0, size.y - 148.0)
    var raio := 104.0
    _pincelada(Rect2(c - Vector2(raio + 11.0, raio + 11.0), Vector2(raio + 11.0, raio + 11.0) * 2.0), 41, Color(TINTA, 0.9), "pigmento", raio + 11.0, {"irregular": 2.6, "seco": 0.0, "respingos": 0.35})
    _pincelada(Rect2(c - Vector2(raio + 1.5, raio + 1.5), Vector2(raio + 1.5, raio + 1.5) * 2.0), 42, Color(TINTA, 0.9), "mar", raio + 1.5, {"irregular": 1.0, "seco": 0.0, "respingos": 0.0, "tinta": Color(0, 0, 0, 0)})
    # Minimapa: águas rasas, praia e mata das ilhas ao alcance, no lugar certo e girando com a proa.
    if barco_ref != null and not radar_ilhas.is_empty():
        var disco := PackedVector2Array()
        for i in 64:
            disco.append(c + Vector2.from_angle(TAU * float(i) / 64.0) * (raio - 0.5))
        var pos_barco := Vector2(barco_ref.global_position.x, barco_ref.global_position.z)
        for ilha in radar_ilhas:
            if pos_barco.distance_to(ilha.centro) - float(ilha.raio) * 1.8 > alcance_radar:
                continue
            for camada in [["raso", Color(0.16, 0.58, 0.60, 0.80)], ["linha", Color(0.84, 0.75, 0.50, 1.0)], ["alto", Color(0.40, 0.58, 0.30, 1.0)]]:
                for poligono in _poligono_radar(ilha[camada[0]], c, raio, disco):
                    if poligono.size() >= 3:
                        draw_colored_polygon(poligono, camada[1])
                        if camada[0] == "linha":
                            draw_polyline(poligono + PackedVector2Array([poligono[0]]), Color(CREME, 0.85), 1.5, true)
            if (ilha.cais as Array).size() >= 2:
                var cais_a := _rel_barco(ilha.cais[0])
                var cais_b := _rel_barco(ilha.cais[1])
                var pa := c + Vector2(cais_a.x, -cais_a.y) / alcance_radar * raio
                var pb := c + Vector2(cais_b.x, -cais_b.y) / alcance_radar * raio
                if pa.distance_to(c) < raio - 2.0 and pb.distance_to(c) < raio - 2.0:
                    draw_line(pa, pb, Color(0.55, 0.38, 0.22), 3.0)
    if barco_ref != null:
        for boia in radar_boias:                               # boias: pontinhos vermelho/verde/branco/amarelo
            var rb := _rel_barco(boia.mundo)
            var pb_boia := c + Vector2(rb.x, -rb.y) / alcance_radar * raio
            if pb_boia.distance_to(c) < raio - 5.0:
                draw_circle(pb_boia, 4.2, Color(TINTA, 0.95))
                draw_circle(pb_boia, 2.9, boia.cor)
    if barco_ref != null and destino_mundo != Vector2.INF:      # v0.8.2: rota da carta — traço até o destino
        _rota_radar(c, raio)
    if sombra_radar > 0.0:                                     # v0.8.7: a coisa de baixo, passando por baixo do barco
        var a_s: float = clampf(sombra_radar / 1.5, 0.0, 1.0) * clampf((7.0 - sombra_radar) / 1.5, 0.0, 1.0)
        var giro_s: float = Time.get_ticks_msec() / 1000.0 * 0.25
        if _tex_coisa != null:
            draw_set_transform(c, giro_s, Vector2.ONE)
            var alt_s: float = raio * 1.7                       # cabe no círculo mesmo girando
            var larg_s: float = alt_s * float(_tex_coisa.get_width()) / float(_tex_coisa.get_height())
            draw_texture_rect(_tex_coisa, Rect2(-larg_s * 0.5, -alt_s * 0.5, larg_s, alt_s), false, Color(1, 1, 1, 0.85 * a_s))
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
        else:
            var pts := PackedVector2Array()
            for k in 24:
                var ang: float = TAU * k / 24.0
                pts.append(c + Vector2(cos(ang) * raio * 0.75, sin(ang) * raio * 0.32).rotated(giro_s))
            draw_colored_polygon(pts, Color(0.01, 0.03, 0.05, 0.8 * a_s))
    draw_arc(c, raio, 0.0, TAU, 72, CREME, 2.5, true)
    for i in 28:                                               # círculo tracejado: metade do alcance
        if i % 2 == 0:
            draw_arc(c, raio * 0.5, TAU * i / 28.0, TAU * (i + 1) / 28.0, 4, Color(CREME, 0.40), 1.5, true)
    # o radar gira com o barco: a proa aponta sempre para cima, e o N dá a volta na borda
    var norte := Vector2.UP.rotated(deg_to_rad(-rumo))
    if barco_ref != null:
        var ang: float = barco_ref.rotation.y                  # sem arredondar: gira suave
        norte = Vector2.UP.rotated(ang)
    if instavel > 0.01:
        norte = norte.rotated(deg_to_rad(instavel * _tremor_bussola()))
    var pn := c + norte * (raio + 1.0)
    draw_circle(pn, 13.0, Color(TINTA, 1.0))
    _texto(pn + Vector2(-13.0, 6.0), T.t("N"), 16, DOURADO, HORIZONTAL_ALIGNMENT_CENTER, 26.0)
    if instavel > 0.05:                                        # chiado: pontinhos que mudam cinco vezes por segundo
        var chiado := RandomNumberGenerator.new()
        chiado.seed = int(Time.get_ticks_msec() / 200)
        for i in int(18.0 * instavel):
            var ponto := Vector2.from_angle(chiado.randf() * TAU) * sqrt(chiado.randf()) * (raio - 6.0)
            draw_circle(c + ponto, 1.3, Color(CREME, 0.20 * instavel))
    var n_alvo: int = 0
    for alvo in radar_alvos:                                   # cardumes: peixinho no lugar; fora do alcance, um traço na borda
        n_alvo += 1
        var rel: Vector2 = alvo.pos
        if barco_ref != null and alvo.has("mundo"):
            rel = _rel_barco(alvo.mundo)
        if instavel > 0.05:                                    # na bruma o eco também tremula
            var tt: float = Time.get_ticks_msec() / 1000.0
            rel += Vector2(sin(tt * 3.1 + n_alvo * 1.7), cos(tt * 2.6 + n_alvo * 2.3)) * (6.0 * instavel)
        var p := Vector2(rel.x, -rel.y) / alcance_radar * raio
        var destaque: bool = not alvo.has("fantasma") and especies_destaque.has(String(alvo.get("especie", "")))
        var pisca: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 1.5) if destaque else 0.0
        if p.length() > raio - 14.0:
            var dir := p.normalized()
            if destaque:                                       # fora do alcance: o traço da borda pisca em dourado e é maior
                draw_line(c + dir * (raio - 16.0), c + dir * (raio - 2.0), Color(DOURADO.lerp(Color.WHITE, pisca * 0.5), 0.55 + 0.45 * pisca), 5.0)
            else:
                draw_line(c + dir * (raio - 11.0), c + dir * (raio - 3.0), Color(CREME, 0.6), 3.0)
        else:
            var dir_tela := Vector2.RIGHT
            if barco_ref != null and alvo.has("mundo") and alvo.has("rumo"):
                var adiante: Vector2 = _rel_barco(alvo.mundo + Vector2.from_angle(float(alvo.rumo))) - rel
                dir_tela = Vector2(adiante.x, -adiante.y)
            var veu: float = 1.0
            if alvo.has("fantasma"):                           # miragem: igual a um cardume, só que pisca e se apaga
                veu = float(alvo.fantasma) * (0.40 + 0.60 * absf(sin(Time.get_ticks_msec() / 1000.0 * 2.3 + float(alvo.get("fase", 0.0)) * 9.0)))
            if destaque:                                       # peixe da missão: anel dourado que pisca em volta do eco
                draw_arc(c + p, 13.0 + 2.0 * pisca, 0.0, TAU, 28, Color(DOURADO.lerp(Color.WHITE, pisca * 0.6), 0.35 + 0.6 * pisca), 2.6, true)
            _peixe_radar(c + p, dir_tela, bool(alvo.get("grande", false)), int(alvo.get("restantes", 1)), float(alvo.get("fase", 0.0)), veu, pisca)
    if cais_rel != Vector2.INF:                                # o cais: âncora dourada; longe, uma seta na borda
        var rel_cais: Vector2 = cais_rel
        if barco_ref != null and cais_mundo != Vector2.INF:
            rel_cais = _rel_barco(cais_mundo)
        var pc := Vector2(rel_cais.x, -rel_cais.y) / alcance_radar * raio
        if pc.length() > raio - 16.0:
            var dc := pc.normalized()
            var ponta := c + dc * (raio - 4.0)
            var lat := Vector2(-dc.y, dc.x)
            draw_colored_polygon(PackedVector2Array([ponta, ponta - dc * 14.0 + lat * 8.0, ponta - dc * 14.0 - lat * 8.0]), DOURADO)
        else:
            _icone_ancora(c + pc, DOURADO)
    draw_colored_polygon(PackedVector2Array([c + Vector2(0, -15), c + Vector2(9, 12), c + Vector2(0, 6), c + Vector2(-9, 12)]), CREME)
    var rodape := T.t("Percorrido: %d m") % int(distancia) if cais_rel == Vector2.INF else T.t("Cais a %d m") % int(cais_dist)
    var larg_rodape := _fonte.get_string_size(rodape, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 34.0
    _pincelada(Rect2(c.x - larg_rodape / 2.0, c.y + raio + 8.0, larg_rodape, 34.0), 29, Color(TINTA, 0.86))   # sobre o mar claro o texto sumia
    _texto(Vector2(c.x - raio, c.y + raio + 31.0), rodape, 21, CREME, HORIZONTAL_ALIGNMENT_CENTER, raio * 2.0)

func _velocimetro() -> void:
    var x := size.x - 262.0
    var y := size.y - 182.0
    _pincelada(Rect2(x, y, 216, 86), 51)
    _pincelada(Rect2(x + 8.0, y + 92.0, 208, 44), 52)
    var baixo := combustivel < 0.2
    var cor_tanque := (Color(0.93, 0.30, 0.22) if baixo else LARANJA)
    if baixo and combustivel > 0.0 and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.5:
        cor_tanque = cor_tanque.lightened(0.35)                    # pisca quando está acabando
    _icone_bomba(Vector2(x + 34.0, y + 114.0), cor_tanque if baixo else DOURADO)
    _barra(Rect2(x + 60.0, y + 105.0, 104.0, 18.0), combustivel, cor_tanque)
    _texto(Vector2(x + 170.0, y + 122.0), "%d L" % roundi(litros), 19, CREME)
    var c := Vector2(x + 40.0, y + 40.0)
    draw_arc(c, 24.0, 0.0, TAU, 48, DOURADO, 3.0, true)
    for i in 7:
        var a := PI * 0.75 + PI * 1.5 * i / 6.0
        draw_line(c + Vector2.from_angle(a) * 17.0, c + Vector2.from_angle(a) * 21.0, DOURADO, 2.0)
    var ponteiro := PI * 0.75 + PI * 1.5 * clampf(fracao_motor, 0.0, 1.0)
    draw_line(c, c + Vector2.from_angle(ponteiro) * 17.0, CREME, 3.0)
    draw_circle(c, 3.5, CREME)
    _texto(Vector2(x + 78.0, y + 50.0), ("%.1f" % nos).replace(".", ","), 42, CREME, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
    var larg := _fonte_titulo.get_string_size(("%.1f" % nos), HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
    _texto(Vector2(x + 86.0 + larg, y + 48.0), T.t("nós"), 24, CREME)
    _barra(Rect2(x + 76.0, y + 60.0, 128.0, 12.0), fracao_motor, VERDE)

func _barra_botoes() -> void:
    var a := ret_botao(0)
    var b := ret_botao(BOTOES.size() - 1)
    var meio_y := a.position.y + TAM_BOTAO / 2.0
    draw_line(Vector2(a.position.x - 110.0, meio_y), Vector2(a.position.x - 8.0, meio_y), Color(CREME, 0.5), 1.5)
    draw_line(Vector2(b.end.x + 8.0, meio_y), Vector2(b.end.x + 110.0, meio_y), Color(CREME, 0.5), 1.5)
    for i in BOTOES.size():
        var nome: String = BOTOES[i]
        var r := ret_botao(i)
        var aceso := (nome == "pescar" and pesca_ativa) or nome == painel_aberto
        var destaque := aceso or nome == _sobre
        _pincelada(r.grow(2.0), 90 + i, Color(TINTA, 0.95), "ouro" if destaque else "mar", r.size.x * 0.5 + 2.0, {"irregular": 3.2, "seco": 0.0, "respingos": 0.4})
        var cor := Aq.NANQUIM if destaque else CREME
        var c := r.position + r.size / 2.0
        match nome:
            "pescar": _icone_anzol(c, cor)
            "porao": _icone_caixa(c, cor)
            "diario": _icone_livro(c, cor)
            "caderno": _icone_caderno(c, cor)
        if nome == _sobre:
            _texto(Vector2(r.position.x - 60.0, r.position.y - 14.0), T.t(DICA[nome]), 18, CREME, HORIZONTAL_ALIGNMENT_CENTER, TAM_BOTAO + 120.0)

func _aviso() -> void:
    if dica != "" and painel_aberto == "":                     # dica fixa, em dourado, logo acima dos botões
        var ld := _fonte.get_string_size(dica, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 70.0
        var rd := Rect2(size.x / 2.0 - ld / 2.0, size.y - 168.0, ld, 42.0)
        _pincelada(rd, 62, Color(TINTA, 0.92))
        draw_string(_fonte, Vector2(rd.position.x, rd.position.y + 30.0), dica, HORIZONTAL_ALIGNMENT_CENTER, ld, 24, DOURADO)
    if aviso_tempo <= 0.0 or aviso_texto == "" or painel_aberto != "":
        return
    var alfa := clampf(aviso_tempo / 0.6, 0.0, 1.0)
    var larg := minf(_fonte.get_string_size(aviso_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x + 70.0, 780.0)
    var r := Rect2(size.x / 2.0 - larg / 2.0, size.y - (246.0 if dica != "" else 196.0), larg, 40.0)
    _pincelada(r, 61, Color(TINTA, 0.88 * alfa))
    draw_string(_fonte, Vector2(r.position.x, r.position.y + 28.0), aviso_texto, HORIZONTAL_ALIGNMENT_CENTER, larg, 21, Color(CREME, alfa))

func _painel() -> void:
    if painel_aberto == "":
        return
    if painel_aberto == "porao" and porao != null:
        _painel_porao()
        return
    # O diário quebra as linhas longas em vez de cortá-las; a folha cresce com o texto e, se não couber, só ficam as mais recentes.
    var larg_folha := 540.0
    var larg_texto := larg_folha - 64.0
    var quebra := TextServer.BREAK_WORD_BOUND | TextServer.BREAK_MANDATORY
    var util := minf(size.y - 90.0, 560.0) - 96.0 - 30.0
    var blocos: Array = []
    var alturas: Array = []
    var usado := 0.0
    for i in range(linhas_painel.size() - 1, -1, -1):
        var t := str(linhas_painel[i])
        var h := _fonte.get_multiline_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, larg_texto, 19, -1, quebra).y + 9.0
        if usado + h > util and not blocos.is_empty():
            break
        usado += h
        blocos.push_front(t)
        alturas.push_front(h)
    var altura := maxf(300.0, 96.0 + usado + 30.0)
    var r := Rect2(size.x / 2.0 - larg_folha / 2.0, size.y / 2.0 - 20.0 - altura / 2.0, larg_folha, altura)
    _pincelada(r, 71, Color(TINTA, 0.97), "papel")
    _texto(Vector2(r.position.x + 32.0, r.position.y + 50.0), titulo_painel, 36, Color(0.55, 0.22, 0.14), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
    _fio_de_tinta(Vector2(r.position.x + 32.0, r.position.y + 62.0), Vector2(r.end.x - 32.0, r.position.y + 62.0), Color(Aq.NANQUIM, 0.5))
    var y := r.position.y + 96.0
    for k in blocos.size():
        draw_multiline_string(_fonte, Vector2(r.position.x + 32.0, y), str(blocos[k]), HORIZONTAL_ALIGNMENT_LEFT, larg_texto, 19, -1, Aq.NANQUIM, quebra)
        y += float(alturas[k])
    if blocos.is_empty():
        draw_string(_fonte, Vector2(r.position.x + 32.0, y), T.t("Nada anotado ainda."), HORIZONTAL_ALIGNMENT_LEFT, larg_texto, 19, Color(Aq.NANQUIM, 0.6))

## Linha de nanquim tremida, como feita à mão.
func _fio_de_tinta(a: Vector2, b: Vector2, cor: Color, espessura: float = 2.0) -> void:
    var n := maxi(4, int(a.distance_to(b) / 14.0))
    var pts := PackedVector2Array()
    for i in n + 1:
        var t := float(i) / float(n)
        pts.append(a.lerp(b, t) + Vector2(0.0, sin(t * 17.0 + a.x * 0.1) * 0.9))
    draw_polyline(pts, cor, espessura, true)

## Minijogo de pesca: anel com faixas verdes, ponteiro girando e a barra do peixe subindo.
func _anel_de_pesca() -> void:
    if pesca == null or pesca.estado == pesca.Estado.PRONTO or painel_aberto != "":
        return
    var c := Vector2(196.0, size.y / 2.0 - 6.0)
    var tensao_anel: float = clampf(float(pesca.tensao) / maxf(0.1, float(pesca.limite_linha)), 0.0, 1.0)
    if tensao_anel > 0.72:                                     # linha esticada: o anel treme
        c += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * (tensao_anel - 0.72) * 16.0
    var raio := 92.0
    var grossura := 20.0
    _pincelada(Rect2(c.x - 138.0, c.y - 200.0, 276.0, 74.0), 81)
    _pincelada(Rect2(c.x - 128.0, c.y + 122.0, 256.0, 78.0), 82)
    var especie: String = pesca.alvo.get("especie", "")
    _texto(Vector2(c.x - 138.0, c.y - 164.0), T.t(especie), 36, DOURADO, HORIZONTAL_ALIGNMENT_CENTER, 276.0, true)
    # v0.6.0: o jeito de lutar da espécie (ícone, nome e a cor do anel)
    var info: Dictionary = pesca.INFO_COMPORTAMENTO[pesca.comportamento]
    var cor_comp: Color = info.cor
    var nome_comp: String = T.t(String(info.nome))
    var larg_nome: float = _fonte.get_string_size(nome_comp, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
    _icone_comportamento(pesca.comportamento, Vector2(c.x - larg_nome * 0.5 - 16.0, c.y - 140.0), cor_comp)
    _texto(Vector2(c.x - larg_nome * 0.5 + 4.0, c.y - 133.0), nome_comp, 20, cor_comp)
    # o anel
    var r_ext := raio + grossura / 2.0 + 10.0
    _pincelada(Rect2(c - Vector2(r_ext, r_ext), Vector2(r_ext, r_ext) * 2.0), 83, Color(TINTA, 0.92), "pigmento", r_ext, {"irregular": 2.8, "seco": 0.0, "respingos": 0.4})
    var r_int := raio - grossura / 2.0 - 2.0
    _pincelada(Rect2(c - Vector2(r_int, r_int), Vector2(r_int, r_int) * 2.0), 84, Color(TINTA, 0.95), "mar", r_int, {"irregular": 1.4, "seco": 0.0, "respingos": 0.0, "tinta": Color(0, 0, 0, 0)})
    draw_arc(c, raio, 0.0, TAU, 96, Color(0.02, 0.06, 0.09, 0.95), grossura, true)
    draw_arc(c, raio + grossura / 2.0 + 2.0, 0.0, TAU, 96, Color(cor_comp.lerp(CREME, 0.30), 0.92), 3.0, true)
    draw_arc(c, raio - grossura / 2.0 - 2.0, 0.0, TAU, 96, Color(CREME, 0.45), 1.5, true)
    var sob: int = pesca.faixa_sob_ponteiro()
    for i in pesca.faixas.size():
        var f: Dictionary = pesca.faixas[i]
        if float(f.usada) > 0.0:
            continue
        var a0: float = float(f.centro) - float(f.largura) / 2.0 - PI / 2.0       # 0 = topo
        var a1: float = a0 + float(f.largura)
        draw_arc(c, raio, a0, a1, 20, VERDE.lightened(0.25) if i == sob else VERDE, grossura - 4.0, true)
        var meio: float = float(f.largura) * pesca.parte_dourada / 2.0
        draw_arc(c, raio, float(f.centro) - meio - PI / 2.0, float(f.centro) + meio - PI / 2.0, 8, DOURADO, grossura - 4.0, true)
    # o peixe no meio: sobe (e cresce) conforme a barra enche
    var p: float = clampf(pesca.progresso, 0.0, 1.0)
    for i in 3:
        draw_arc(c + Vector2(0, 30), 18.0 + i * 15.0, PI * 1.15, PI * 1.85, 10, Color(CREME, 0.10 + 0.05 * i), 1.5, true)
    var treme := Vector2(sin(Time.get_ticks_msec() * 0.012) * 2.0, 0.0)
    var pos_peixe := c + Vector2(-4.0, lerpf(26.0, -8.0, p)) + treme
    var desenho: Texture2D = _sprites_peixes.get(especie)
    if desenho != null:                                        # o peixe de verdade (SpriteCook), crescendo com a barra
        var larg := lerpf(2.6, 4.2, p) * 26.0
        var alt := larg * float(desenho.get_height()) / float(desenho.get_width())
        draw_texture_rect(desenho, Rect2(pos_peixe - Vector2(larg, alt) * 0.5, Vector2(larg, alt)), false, Color(1, 1, 1, 1.0 if pesca.trava <= 0.0 else 0.5))
    else:
        _icone_peixe(pos_peixe, lerpf(2.6, 4.2, p), Color(0.80, 0.94, 0.95) if pesca.trava <= 0.0 else Color(0.80, 0.94, 0.95, 0.5))
    # o ponteiro
    var d := Vector2.from_angle(pesca.angulo - PI / 2.0)
    var cor_ponteiro := CREME
    if pesca.trava > 0.0:
        cor_ponteiro = Color(0.95, 0.35, 0.28)
    elif pesca.brilho > 0.0:
        cor_ponteiro = DOURADO if pesca.ultimo_perfeito else VERDE.lightened(0.4)
    draw_line(c + d * (raio - grossura / 2.0 - 12.0), c + d * (raio + grossura / 2.0 + 6.0), Color(0.02, 0.05, 0.08, 0.9), 9.0)
    draw_line(c + d * (raio - grossura / 2.0 - 11.0), c + d * (raio + grossura / 2.0 + 5.0), cor_ponteiro, 5.0)
    var lat := Vector2(-d.y, d.x)
    var ponta := c + d * (raio - grossura / 2.0 - 16.0)
    draw_colored_polygon(PackedVector2Array([ponta, ponta + d * 12.0 + lat * 7.0, ponta + d * 12.0 - lat * 7.0]), cor_ponteiro)
    if pesca.salto_estado != 0:                                # o agulhão salta: ESPERE... e depois AGORA!
        var ms: float = float(Time.get_ticks_msec())
        if pesca.salto_estado == 1:
            draw_arc(c, raio, 0.0, TAU, 96, Color(0.55, 0.75, 1.0, 0.40 + 0.25 * sin(ms * 0.02)), grossura, true)
            _texto(Vector2(c.x - 100.0, c.y + 14.0), T.t("ESPERE..."), 34, Color(0.78, 0.90, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 200.0, true)
        else:
            var piscar: bool = int(ms / 90.0) % 2 == 0
            draw_arc(c, raio, 0.0, TAU, 96, Color(DOURADO if piscar else Color(1.0, 0.42, 0.22), 0.9), grossura, true)
            _texto(Vector2(c.x - 100.0, c.y + 18.0), T.t("AGORA!"), 46, CREME, HORIZONTAL_ALIGNMENT_CENTER, 200.0, true)
    if _pop_tempo > 0.0:                                       # PERFEITO! / BOM! / ERROU sobem e somem
        var vida: float = _pop_tempo / 0.9
        _texto(Vector2(c.x + raio + grossura / 2.0 + 22.0, c.y - 4.0 - (1.0 - vida) * 26.0), _pop_texto, 38, Color(_pop_cor, clampf(vida * 1.8, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
    if pesca.brilho > 0.0:                                     # clarão do acerto
        draw_arc(c, raio, 0.0, TAU, 96, Color(DOURADO if pesca.ultimo_perfeito else VERDE, pesca.brilho * 1.6), 3.0 + (0.35 - pesca.brilho) * 40.0, true)
    # embaixo: barra do peixe, cardume e a tecla
    _barra(Rect2(c.x - 106.0, c.y + 132.0, 212.0, 18.0), p, DOURADO if p > 0.8 else VERDE)
    _texto(Vector2(c.x - 106.0, c.y + 176.0), T.t("Cardume: %s") % T.t(pesca.estoque()), 19, CREME)
    # Indicador de tensão: vermelho próximo do limite da linha.
    var tensao_atual: float = tensao_anel
    var alerta_piscando: bool = tensao_atual > 0.72 and int(Time.get_ticks_msec() / 140.0) % 2 == 0
    _barra(Rect2(c.x - 106.0, c.y + 183.0, 212.0, 8.0), tensao_atual,
        (Color(1.0, 0.55, 0.45) if alerta_piscando else Color(0.94, 0.28, 0.20)) if tensao_atual > 0.72 else Color(0.90, 0.66, 0.28))
    var tecla := Rect2(c.x + 30.0, c.y + 157.0, 24.0, 24.0)
    _caixa_arredondada(tecla, CREME if pesca.trava <= 0.0 else Color(CREME, 0.4))
    draw_string(_fonte, Vector2(tecla.position.x, tecla.position.y + 18.0), "F", HORIZONTAL_ALIGNMENT_CENTER, 24.0, 16, Color(0.06, 0.10, 0.15))
    _texto(Vector2(tecla.end.x + 8.0, c.y + 177.0), T.t("Puxar"), 19, CREME)

# ------------------------------------------------------------------ porão em grade

func _escala_painel() -> float:
    return minf(1.0, escala + 0.2)

## Ponto da tela -> ponto no desenho do painel (que é encolhido em direção ao centro).
func _para_painel(p: Vector2) -> Vector2:
    var e := _escala_painel()
    return (p - size * 0.5 * (1.0 - e)) / e

func _ret_painel_porao() -> Rect2:
    var larg := maxf(560.0, porao.colunas * CASA + 280.0)
    var alt := maxf(330.0, porao.linhas * CASA + 130.0)
    return Rect2(size.x / 2.0 - larg / 2.0, size.y / 2.0 - alt / 2.0 - 20.0, larg, alt)

func _origem_grade() -> Vector2:
    return _ret_painel_porao().position + Vector2(30.0, 76.0)

func _casa_em(p: Vector2) -> Vector2i:
    var q := (_para_painel(p) - _origem_grade()) / CASA
    return Vector2i(floori(q.x), floori(q.y))

func _ret_arrumar() -> Rect2:
    var r := _ret_painel_porao()
    return Rect2(r.end.x - 226.0, r.end.y - 62.0, 196.0, 38.0)

## Devolve à grade o peixe que estava na mão (fechou o painel sem soltar).
func soltar_peixe() -> void:
    _na_mao = {}

## Casa onde fica o canto do peixe na mão, para o meio dele seguir o mouse.
func _canto_da_mao() -> Vector2i:
    var maior := Vector2i.ZERO
    for c in porao.casas(_na_mao.especie, _rot_mao):
        maior = Vector2i(maxi(maior.x, c.x), maxi(maior.y, c.y))
    var q := (_para_painel(_mouse) - _origem_grade()) / CASA - Vector2(maior) / 2.0
    return Vector2i(floori(q.x), floori(q.y))

func _clique_no_porao(event: InputEventMouseButton) -> bool:
    _mouse = event.position
    var p := _para_painel(event.position)
    if not _ret_painel_porao().grow(20.0).has_point(p):
        return false
    if event.button_index == MOUSE_BUTTON_RIGHT:
        if not _na_mao.is_empty():
            _rot_mao = (_rot_mao + 1) % 4
        return true
    if event.button_index != MOUSE_BUTTON_LEFT:
        return true
    if _na_mao.is_empty():
        if _ret_arrumar().has_point(p):
            porao.arrumar()
            return true
        var item: Dictionary = porao.item_em(_casa_em(event.position))
        if not item.is_empty():
            _na_mao = item
            _rot_mao = item.rot
        return true
    if _ret_arrumar().has_point(p):                            # com peixe na mão o botão vira "devolver ao mar"
        var fora := _na_mao
        _na_mao = {}
        porao.retirar(fora)
        devolveu.emit(fora)
        return true
    var canto := _canto_da_mao()
    if porao.mover(_na_mao, canto.x, canto.y, _rot_mao):
        _na_mao = {}
    return true

func _input(event: InputEvent) -> void:
    if painel_aberto == "porao" and not _na_mao.is_empty() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
        _rot_mao = (_rot_mao + 1) % 4                          # R gira o peixe (e não reinicia a viagem)
        get_viewport().set_input_as_handled()

## Um peixe na grade: as casas dele pintadas, com contorno só por fora, e a silhueta por cima.
func _peixe_na_grade(especie: String, casas: Array, origem: Vector2, cor: Color, alfa: float = 1.0, aberrante: bool = false) -> void:
    if casas.is_empty():
        return
    var centro := Vector2.ZERO
    var maior := Vector2i(-99, -99)
    var menor := Vector2i(99, 99)
    for c in casas:
        menor = Vector2i(mini(menor.x, c.x), mini(menor.y, c.y))
        maior = Vector2i(maxi(maior.x, c.x), maxi(maior.y, c.y))
        var r := Rect2(origem + Vector2(c) * CASA, Vector2(CASA, CASA))
        draw_rect(r.grow(-3), Color(cor.darkened(0.48), 0.67 * alfa))
        centro += r.get_center()
        for lado in [[Vector2i(0, -1), r.position, Vector2(r.end.x, r.position.y)],
                [Vector2i(0, 1), Vector2(r.position.x, r.end.y), r.end],
                [Vector2i(-1, 0), r.position, Vector2(r.position.x, r.end.y)],
                [Vector2i(1, 0), Vector2(r.end.x, r.position.y), r.end]]:
            if not (c + lado[0]) in casas:
                draw_line(lado[1], lado[2], Color(cor.lightened(0.2), alfa), 2.5)
    centro /= casas.size()
    var comprimento: float = float(maxi(maior.x - menor.x, maior.y - menor.y) + 1) * CASA - 8.0
    var espessura: float = float(mini(maior.x - menor.x, maior.y - menor.y) + 1) * CASA - 9.0
    var girado: bool = maior.y - menor.y > maior.x - menor.x
    var textura: Texture2D = _sprites_aberrantes.get(especie) if aberrante else _sprites_peixes.get(especie)
    if textura == null:
        textura = _sprites_peixes.get(especie)
    if textura != null:
        var tam_img := textura.get_size()
        var ajuste := minf(comprimento / tam_img.x, espessura / tam_img.y)     # cabe nas casas sem esticar o desenho
        var largura_img := tam_img.x * ajuste
        var altura_img := tam_img.y * ajuste
        var fator := minf(1.0, escala + 0.2)
        var ponto_tela := size * 0.5 * (1.0 - fator) + centro * fator
        draw_set_transform(ponto_tela, PI * 0.5 if girado else 0.0, Vector2(fator, fator))
        draw_texture_rect(textura, Rect2(-largura_img * 0.5, -altura_img * 0.5, largura_img, altura_img), false, Color(1.0, 1.0, 1.0, alfa))
        _ancorar(0.5, 0.5, fator)
    elif porao != null and porao.eh_carga(especie):
        _icone_caixa(centro, Color(cor, alfa))
    else:
        _icone_peixe(centro, maxf(1.1, comprimento / 22.0), Color(cor, alfa))

func _painel_porao() -> void:
    var r := _ret_painel_porao()
    _pincelada(r, 71, Color(TINTA, 0.97), "papel")
    _icone_caixa(Vector2(r.position.x + 46.0, r.position.y + 42.0), Color(0.55, 0.22, 0.14))
    _texto(Vector2(r.position.x + 80.0, r.position.y + 52.0), T.t("Porão"), 38, Color(0.55, 0.22, 0.14), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
    draw_string(_fonte, Vector2(r.position.x + 190.0, r.position.y + 50.0), T.t("%d de %d casas") % [porao.casas_ocupadas(), porao.colunas * porao.linhas], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Aq.NANQUIM_CLARO)
    _fio_de_tinta(Vector2(r.position.x + 30.0, r.position.y + 64.0), Vector2(r.end.x - 30.0, r.position.y + 64.0), Color(Aq.NANQUIM, 0.5))
    var o := _origem_grade()
    var grade := Rect2(o, Vector2(porao.colunas, porao.linhas) * CASA)
    _pincelada(grade.grow(7.0), 72, Color(TINTA, 0.97), "mar", 8.0, {"irregular": 2.2, "seco": 0.0, "respingos": 0.0})
    for j in porao.linhas:
        for i in porao.colunas:
            var casa_rect := Rect2(o + Vector2(i, j) * CASA, Vector2(CASA, CASA))
            draw_rect(casa_rect.grow(-1.0), Color(0.01, 0.05, 0.09, 0.28), true)
            draw_rect(casa_rect.grow(-1.5), Color(Aq.CREME, 0.17), false, 1.2)
    var sob: Dictionary = porao.item_em(_casa_em(_mouse)) if _na_mao.is_empty() else _na_mao
    for item in porao.itens:
        if is_same(item, _na_mao):
            continue
        var cor: Color = porao.CORES.get(item.especie, CREME)
        _peixe_na_grade(item.especie, porao.casas_do_item(item), o, cor.lightened(0.2) if is_same(item, sob) else cor, 1.0, String(item.get("qualidade", "")) == "Aberrante")
    if not _na_mao.is_empty():                                 # o peixe na mão: verde onde cabe, vermelho onde não
        var canto := _canto_da_mao()
        var casas: Array = []
        for c in porao.casas(_na_mao.especie, _rot_mao):
            casas.append(c + canto)
        var cabe: bool = porao.cabe_em(_na_mao.especie, canto.x, canto.y, _rot_mao, _na_mao)
        _peixe_na_grade(_na_mao.especie, casas, o, VERDE if cabe else Color(0.93, 0.34, 0.26), 0.85, String(_na_mao.get("qualidade", "")) == "Aberrante")
    # à direita: o peixe apontado, os totais e as instruções
    var x: float = o.x + porao.colunas * CASA + 26.0
    var y := r.position.y + 96.0
    if not sob.is_empty():
        _texto(Vector2(x, y), T.t(String(sob.especie)), 32, Color(porao.CORES.get(sob.especie, CREME)).darkened(0.45), HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
        draw_string(_fonte, Vector2(x, y + 28.0), "%s kg  •  %s" % [("%.1f" % sob.peso).replace(".", ","), T.t(String(sob.get("qualidade", "Regular")))], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Aq.NANQUIM)
    else:
        _texto(Vector2(x, y), T.t("%d peixe(s)") % porao.n_peixes(), 32, Aq.NANQUIM, HORIZONTAL_ALIGNMENT_LEFT, -1.0, true)
        draw_string(_fonte, Vector2(x, y + 28.0), "%s kg  •  R$ %d" % [("%.1f" % porao.peso_total()).replace(".", ","), porao.valor_total()], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Aq.NANQUIM)
    var dicas := [T.t("Clique num peixe para pegar."), T.t("Clique numa casa para soltar."), T.t("R ou botão direito: girar.")] if not porao.itens.is_empty() \
            else [T.t("Vazio. Pare perto de um"), T.t("cardume e pesque com F."), T.t("Peixe grande ocupa mais casas.")]
    for i in dicas.size():
        draw_string(_fonte, Vector2(x, y + 68.0 + i * 24.0), dicas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Aq.NANQUIM_CLARO)
    var b := _ret_arrumar()
    var sobre_botao := b.has_point(_para_painel(_mouse))
    var devolver := not _na_mao.is_empty()
    _pincelada(b, 73, Color(TINTA, 0.97), "terracota" if devolver else ("ouro" if sobre_botao else "turquesa"), 10.0, {"irregular": 2.5, "seco": 0.0, "respingos": 0.0})
    draw_string(_fonte, Vector2(b.position.x, b.position.y + 26.0), T.t("Devolver ao mar") if devolver else T.t("Arrumar o porão"), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 21, CREME if (devolver or not sobre_botao) else Aq.NANQUIM)

# ------------------------------------------------------------------ ícones

func _caixa_arredondada(r: Rect2, cor: Color) -> void:
    var e := StyleBoxFlat.new()
    e.bg_color = cor
    e.set_corner_radius_all(10)
    draw_style_box(e, r)

func _contorno_arredondado(r: Rect2, cor: Color, espessura: float) -> void:
    var e := StyleBoxFlat.new()
    e.draw_center = false
    e.border_color = cor
    e.set_border_width_all(int(round(espessura)))
    e.set_corner_radius_all(10)
    draw_style_box(e, r)

func _icone_ancora(c: Vector2, cor: Color) -> void:
    draw_arc(c + Vector2(0, -9), 3.0, 0.0, TAU, 12, cor, 2.0, true)
    draw_line(c + Vector2(0, -6), c + Vector2(0, 9), cor, 2.5)
    draw_line(c + Vector2(-5, -2), c + Vector2(5, -2), cor, 2.5)
    draw_arc(c + Vector2(0, 2), 8.0, 0.15, PI - 0.15, 12, cor, 2.5, true)

func _icone_bomba(c: Vector2, cor: Color) -> void:
    draw_rect(Rect2(c + Vector2(-11, -13), Vector2(15, 26)), cor, false, 2.5)
    draw_rect(Rect2(c + Vector2(-8, -10), Vector2(9, 8)), cor)
    draw_line(c + Vector2(-14, 13), c + Vector2(7, 13), cor, 2.5)
    draw_polyline(PackedVector2Array([c + Vector2(4, -4), c + Vector2(11, -4), c + Vector2(11, 8), c + Vector2(14, 8), c + Vector2(14, -8), c + Vector2(10, -13)]), cor, 2.0)

func _icone_peixe(c: Vector2, escala: float, cor: Color) -> void:
    var s := escala
    draw_colored_polygon(PackedVector2Array([c + Vector2(-9, 0) * s, c + Vector2(-3, -4.5) * s, c + Vector2(5, -3) * s,
            c + Vector2(8, 0) * s, c + Vector2(5, 3) * s, c + Vector2(-3, 4.5) * s]), cor)
    draw_colored_polygon(PackedVector2Array([c + Vector2(7, 0) * s, c + Vector2(13, -5) * s, c + Vector2(13, 5) * s]), cor)

## Peixe do radar (v0.5.7): silhueta vista de cima apontando para onde o cardume nada, com cauda em forquilha,
## nadadeiras, olho e contorno de tinta; pulso de sonar em volta. Dourado = peixe grande; cardume farto leva dois companheiros.
func _peixe_radar(c: Vector2, dir: Vector2, grande: bool, restantes: int, fase: float, veu: float = 1.0, pisca: float = 0.0) -> void:
    var t: float = fmod(Time.get_ticks_msec() / 1000.0 * 0.55 + fase, 1.0)
    var cor: Color = Color(0.98, 0.80, 0.40) if grande else Color(0.60, 0.93, 0.95)
    cor = cor.lerp(Color(1.0, 0.97, 0.82), pisca * 0.7)      # peixe da missão: clareia no ritmo do pisca
    cor.a = veu
    draw_arc(c, 7.0 + 15.0 * t, 0.0, TAU, 24, Color(cor, 0.42 * (1.0 - t) * veu), 2.0, true)
    var f: Vector2 = dir.normalized() if dir.length() > 0.001 else Vector2.RIGHT
    if restantes >= 4:
        var lado := f.orthogonal()
        _silhueta_peixe(c - f * 11.0 + lado * 8.0, f, 0.55, cor.darkened(0.12), veu)
        _silhueta_peixe(c - f * 9.0 - lado * 9.0, f, 0.50, cor.darkened(0.18), veu)
    _silhueta_peixe(c, f, 1.3 if grande else 1.0, cor, veu)

func _silhueta_peixe(c: Vector2, f: Vector2, s: float, cor: Color, veu: float = 1.0) -> void:
    var lado := f.orthogonal()
    var comp := 8.0 * s
    var larg := 3.6 * s
    var corpo := PackedVector2Array()
    for i in 16:
        var a := TAU * float(i) / 16.0
        var afina: float = 0.70 + 0.30 * cos(a)                 # mais gordo na frente, fino no pedúnculo
        corpo.append(c + f * cos(a) * comp + lado * sin(a) * larg * afina)
    var base := c - f * comp * 0.82
    var cauda := PackedVector2Array([base + lado * larg * 0.25, c - f * comp * 1.55 + lado * larg * 1.05,
            c - f * comp * 1.22, c - f * comp * 1.55 - lado * larg * 1.05, base - lado * larg * 0.25])
    var escuro := Color(0.03, 0.08, 0.12, 0.85 * veu)
    # sombra/contorno: o mesmo desenho um pouco maior, em tinta escura
    var contorno := PackedVector2Array()
    for q in corpo:
        contorno.append(c + (q - c) * 1.22)
    draw_colored_polygon(contorno, escuro)
    draw_colored_polygon(cauda, escuro)
    draw_colored_polygon(cauda, cor.darkened(0.15))
    draw_colored_polygon(corpo, cor)
    # nadadeiras peitorais e o dorso mais claro
    for sinal in [-1.0, 1.0]:
        draw_colored_polygon(PackedVector2Array([c + f * comp * 0.25 + lado * larg * 0.75 * sinal,
                c - f * comp * 0.15 + lado * larg * 1.55 * sinal, c - f * comp * 0.05 + lado * larg * 0.7 * sinal]), cor.darkened(0.2))
    draw_line(c - f * comp * 0.55, c + f * comp * 0.55, cor.lightened(0.45), maxf(1.0, 1.3 * s), true)
    draw_circle(c + f * comp * 0.58 + lado * larg * 0.38, maxf(0.9, 1.1 * s), escuro)

func _icone_barco(c: Vector2, escala: float, cor: Color) -> void:
    var s := escala
    draw_colored_polygon(PackedVector2Array([c + Vector2(-44, 4) * s, c + Vector2(48, 4) * s, c + Vector2(36, 22) * s, c + Vector2(-34, 22) * s]), cor)
    draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -12) * s, c + Vector2(26, -12) * s, c + Vector2(26, 2) * s, c + Vector2(-6, 2) * s]), cor)
    draw_line(c + Vector2(-16, 2) * s, c + Vector2(-16, -34) * s, cor, 2.5)
    draw_line(c + Vector2(-16, -30) * s, c + Vector2(-40, 2) * s, cor, 1.5)
    draw_line(c + Vector2(-16, -30) * s, c + Vector2(10, -12) * s, cor, 1.5)
    draw_rect(Rect2(c + Vector2(0, -8) * s, Vector2(7, 6) * s), TINTA)
    draw_rect(Rect2(c + Vector2(12, -8) * s, Vector2(7, 6) * s), TINTA)

## Boia salva-vidas: anel creme com quatro faixas vermelhas (a saúde do casco).
func _icone_boia(c: Vector2, raio: float, cor: Color) -> void:
    draw_arc(c, raio * 0.72, 0.0, TAU, 28, cor, raio * 0.52, true)
    for i in 4:
        var a0: float = TAU * float(i) / 4.0 + PI * 0.25 - 0.28
        draw_arc(c, raio * 0.72, a0, a0 + 0.56, 6, Color(0.88, 0.30, 0.22), raio * 0.54, true)

func _icone_engrenagem(c: Vector2, raio: float, cor: Color) -> void:
    for i in 8:
        var d := Vector2.from_angle(TAU * i / 8.0)
        draw_line(c + d * raio * 0.7, c + d * raio * 1.25, cor, raio * 0.42)
    draw_arc(c, raio * 0.72, 0.0, TAU, 32, cor, raio * 0.42, true)

func _icone_prancheta(c: Vector2, cor: Color) -> void:
    draw_rect(Rect2(c + Vector2(-12, -14), Vector2(24, 30)), cor, false, 2.5)
    draw_rect(Rect2(c + Vector2(-6, -19), Vector2(12, 7)), cor)
    for i in 3:
        draw_line(c + Vector2(-7, -5 + i * 7), c + Vector2(7, -5 + i * 7), cor, 2.0)

func _icone_anzol(c: Vector2, cor: Color) -> void:
    draw_arc(c + Vector2(0, -19), 4.0, 0.0, TAU, 16, cor, 2.5, true)
    draw_line(c + Vector2(0, -15), c + Vector2(0, 8), cor, 3.5)
    draw_arc(c + Vector2(-9, 8), 9.0, 0.0, PI, 20, cor, 3.5, true)
    draw_line(c + Vector2(-18, 8), c + Vector2(-18, 0), cor, 3.5)
    draw_line(c + Vector2(-18, 0), c + Vector2(-12, 6), cor, 3.0)

func _icone_caixa(c: Vector2, cor: Color) -> void:
    var topo := PackedVector2Array([c + Vector2(0, -20), c + Vector2(20, -10), c + Vector2(0, 0), c + Vector2(-20, -10), c + Vector2(0, -20)])
    draw_polyline(topo, cor, 3.0)
    draw_polyline(PackedVector2Array([c + Vector2(-20, -10), c + Vector2(-20, 10), c + Vector2(0, 20), c + Vector2(20, 10), c + Vector2(20, -10)]), cor, 3.0)
    draw_line(c + Vector2(0, 0), c + Vector2(0, 20), cor, 3.0)

## v0.6.0: ícone do jeito de lutar (cabe em ~22 px).
func _icone_comportamento(tipo: String, c: Vector2, cor: Color) -> void:
    match tipo:
        "bando":
            for p in [Vector2(-7, 4), Vector2(7, 4), Vector2(0, -6)]:
                draw_circle(c + p, 3.6, cor)
        "corredor":
            for dx in [-7.0, 2.0]:
                draw_polyline(PackedVector2Array([c + Vector2(dx, -8), c + Vector2(dx + 8, 0), c + Vector2(dx, 8)]), cor, 3.0)
        "pesado":
            draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -9), c + Vector2(6, -9), c + Vector2(11, 9), c + Vector2(-11, 9)]), cor)
            draw_arc(c + Vector2(0, -11), 4.0, PI, TAU, 8, cor, 2.4, true)
        "arisco":
            draw_polyline(PackedVector2Array([c + Vector2(-11, 6), c + Vector2(-5, -7), c + Vector2(1, 6), c + Vector2(7, -7), c + Vector2(12, 3)]), cor, 3.0)
        "escorregadio":
            var pts := PackedVector2Array()
            for i in 13:
                pts.append(c + Vector2(-12.0 + i * 2.0, sin(i * 0.9) * 6.0))
            draw_polyline(pts, cor, 3.0, true)
        "saltador":
            var arco := PackedVector2Array()
            for i in 11:
                var t: float = float(i) / 10.0
                arco.append(c + Vector2(lerpf(-12.0, 12.0, t), 8.0 - 20.0 * 4.0 * t * (1.0 - t)))
            draw_polyline(arco, cor, 3.0, true)
            draw_circle(arco[arco.size() - 1], 3.0, cor)
        "colosso":
            draw_arc(c, 10.0, 0.0, TAU, 20, cor, 3.0, true)
            draw_arc(c, 4.5, 0.0, TAU, 12, cor, 2.4, true)

## v0.7.0: botão do caderno de peixes: um peixinho de perfil.
func _icone_caderno(c: Vector2, cor: Color) -> void:
    var corpo := PackedVector2Array()
    for i in 18:
        var a := TAU * float(i) / 18.0
        corpo.append(c + Vector2(cos(a) * 15.0 - 3.0, sin(a) * 8.5 * (0.75 + 0.25 * cos(a))))
    draw_colored_polygon(corpo, cor)
    draw_colored_polygon(PackedVector2Array([c + Vector2(9.0, 0.0), c + Vector2(21.0, -10.0), c + Vector2(18.0, 0.0), c + Vector2(21.0, 10.0)]), cor)
    draw_circle(c + Vector2(-11.0, -2.0), 2.2, Color(TINTA, 0.9))

func _icone_livro(c: Vector2, cor: Color) -> void:
    draw_polyline(PackedVector2Array([c + Vector2(-17, -18), c + Vector2(15, -18), c + Vector2(15, 12), c + Vector2(-11, 12)]), cor, 3.0)
    draw_arc(c + Vector2(-11, 16), 4.0, PI * 0.5, PI * 1.5, 8, cor, 3.0, true)
    draw_line(c + Vector2(-17, -18), c + Vector2(-17, 16), cor, 3.0)
    draw_line(c + Vector2(-11, 20), c + Vector2(15, 20), cor, 3.0)
    draw_line(c + Vector2(15, 12), c + Vector2(15, 20), cor, 3.0)
    draw_line(c + Vector2(-7, -9), c + Vector2(7, -9), cor, 2.0)
