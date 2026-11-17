extends Control
## HUD pintado: tudo desenhado por código (sem imagens), no layout da arte de interface do jogo.
## Placa do barco e motor, bússola em fita, missão, radar, velocímetro, aviso e barra de botões.
## Só mostra o que o jogo realmente tem; quem preenche os dados é scripts/interface.gd.

signal botao(nome: String)
signal devolveu(item: Dictionary)      # o jogador jogou um peixe do porão de volta ao mar

const Cardumes = preload("res://scripts/cardumes.gd")
const TINTA := Color(0.075, 0.125, 0.19, 0.90)        # azul-marinho das pinceladas
const CREME := Color(0.96, 0.93, 0.84)
const DOURADO := Color(0.98, 0.76, 0.33)
const VERDE := Color(0.33, 0.83, 0.66)
const LARANJA := Color(0.96, 0.62, 0.24)
const APAGADO := Color(0.55, 0.62, 0.66, 0.55)
const BOTOES := ["pescar", "porao", "diario", "config"]
const DICA := {"pescar": "Pescar  [F]", "porao": "Porão", "diario": "Diário de bordo", "config": "Pausa  [ESC]"}
const TAM_BOTAO := 74.0
const PONTOS := ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]

## Tamanho da interface: 1.0 é o desenho original (grande); 0.62 deixa a tela livre para o mar.
## Cada bloco encolhe em direção ao seu canto.
@export_range(0.4, 1.2, 0.01) var escala: float = 0.62

var nome_barco := "PE-3476"
var rumo := 0.0                 # graus, 0 = norte
var nos := 0.0
var fracao_motor := 0.0         # 0..1: quanto do motor está em uso
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
var radar_alvos: Array = []     # {pos: Vector2(m a boreste, m à frente), mundo: Vector2(x, z), grande: bool}
var barco_ref: Node3D = null     # o radar lê a posição e o rumo do barco a cada quadro (gira sem engasgar)
var radar_ilhas: Array = []     # por ilha: {centro, raio, raso, linha, alto: contornos no mundo, cais: [inicio, ponta]}
var cais_mundo := Vector2.INF   # ponta do cais mais próximo (x, z no mundo)
var radar_boias: Array = []     # boias de sinalização: {mundo: Vector2(x, z), cor: Color}
var alcance_radar: float = 150.0    # metros até a borda do radar
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
var _sprites_peixes: Dictionary = {}
var _textura_madeira: Texture2D = null
var _textura_casa: Texture2D = null
var _sobre := ""                # botão sob o mouse

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_PASS
    _fonte = ThemeDB.fallback_font
    var dir_sprites := "res://assets/texturas/peixes/porao/"
    for especie in Cardumes.ESPECIES:
        var arquivo: String = dir_sprites + Cardumes.slug(especie) + ".png"
        if ResourceLoader.exists(arquivo):
            _sprites_peixes[especie] = load(arquivo)
    _textura_madeira = load("res://assets/texturas/inventario/forro_madeira.png")
    _textura_casa = load("res://assets/texturas/inventario/casa_porao.png")

func _process(delta: float) -> void:
    aviso_tempo = maxf(0.0, aviso_tempo - delta)
    queue_redraw()

# ------------------------------------------------------------------ botões

## Encolhe o que for desenhado a seguir em direção a um ponto da tela (0,0 = canto de cima à esquerda;
## 0.5,1 = meio da borda de baixo; 1,1 = canto de baixo à direita).
func _ancorar(ax: float, ay: float, fator: float = -1.0) -> void:
    var e := escala if fator < 0.0 else fator
    draw_set_transform(Vector2(size.x * ax, size.y * ay) * (1.0 - e), 0.0, Vector2(e, e))

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

## Mancha de tinta: retângulo com as pontas rasgadas, como uma pincelada larga e seca.
func _pincelada(r: Rect2, semente: int, cor: Color = TINTA) -> void:
    if noite > 0.0:                                    # à noite a placa clareia um pouco e ganha fio: senão some no mar escuro
        cor = Color(cor.lerp(Color(0.13, 0.21, 0.31), 0.75 * noite), lerpf(cor.a, maxf(cor.a, 0.94), noite))
    var rng := RandomNumberGenerator.new()
    rng.seed = semente
    var faixas := maxi(3, int(r.size.y / 13.0))
    var esq := PackedVector2Array()
    var dir := PackedVector2Array()
    for i in faixas + 1:
        var y := r.position.y + r.size.y * float(i) / faixas
        esq.append(Vector2(r.position.x - rng.randf_range(0.0, 20.0), y))
        dir.append(Vector2(r.end.x + rng.randf_range(0.0, 24.0), y))
    for i in faixas:                                   # cada faixa é um trapézio (sempre desenhável)
        draw_colored_polygon(PackedVector2Array([esq[i], dir[i], dir[i + 1], esq[i + 1]]), cor)
    if noite > 0.0:
        draw_line(esq[0], dir[0], Color(CREME, 0.30 * noite), 1.5)
        draw_line(esq[faixas], dir[faixas], Color(CREME, 0.30 * noite), 1.5)
    for i in 3:                                        # fios soltos nas pontas
        var y := r.position.y + rng.randf_range(4.0, r.size.y - 4.0)
        draw_line(Vector2(r.end.x + 6.0, y), Vector2(r.end.x + rng.randf_range(26.0, 44.0), y), Color(cor, cor.a * 0.55), 2.0)
        draw_line(Vector2(r.position.x - 6.0, y + 5.0), Vector2(r.position.x - rng.randf_range(24.0, 38.0), y + 5.0), Color(cor, cor.a * 0.55), 2.0)

func _texto(pos: Vector2, texto: String, tam: int, cor: Color = CREME, alinhar: int = HORIZONTAL_ALIGNMENT_LEFT, largura: float = -1.0) -> void:
    draw_string_outline(_fonte, pos, texto, alinhar, largura, tam, 4, Color(0.03, 0.06, 0.1, 0.55))
    draw_string(_fonte, pos, texto, alinhar, largura, tam, cor)

func _barra(r: Rect2, fracao: float, cor: Color) -> void:
    var raio := r.size.y / 2.0
    draw_line(Vector2(r.position.x + raio, r.position.y + raio), Vector2(r.end.x - raio, r.position.y + raio), Color(0.02, 0.05, 0.08, 0.85), r.size.y)
    draw_circle(Vector2(r.position.x + raio, r.position.y + raio), raio, Color(0.02, 0.05, 0.08, 0.85))
    draw_circle(Vector2(r.end.x - raio, r.position.y + raio), raio, Color(0.02, 0.05, 0.08, 0.85))
    var f := clampf(fracao, 0.0, 1.0)
    if f > 0.01:
        var fim := r.position.x + raio + (r.size.x - r.size.y) * f
        draw_line(Vector2(r.position.x + raio, r.position.y + raio), Vector2(fim, r.position.y + raio), cor, r.size.y - 5.0)
        draw_circle(Vector2(r.position.x + raio, r.position.y + raio), raio - 2.5, cor)
        draw_circle(Vector2(fim, r.position.y + raio), raio - 2.5, cor)

func _placa_barco() -> void:
    _pincelada(Rect2(46, 30, 330, 58), 11)
    _pincelada(Rect2(46, 96, 300, 44), 12)
    _icone_barco(Vector2(118, 66), 1.0, CREME)
    _texto(Vector2(206, 74), nome_barco, 30, CREME)
    _icone_engrenagem(Vector2(88, 118), 12.0, CREME)
    _barra(Rect2(116, 108, 218, 20), fracao_motor, VERDE)
    _pincelada(Rect2(46, 148, 190, 40), 13)
    _texto(Vector2(64, 176), "R$ %d" % dinheiro, 24, DOURADO)
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
        _texto(Vector2(94, 223), hora, 22, CREME)

func _bussola() -> void:
    var cx := size.x / 2.0
    var meia := 226.0
    var y := 54.0
    _pincelada(Rect2(cx - meia, y - 16.0, meia * 2.0, 34.0), 21, Color(TINTA, 0.62))
    _pincelada(Rect2(cx - 42.0, 8.0, 84.0, 34.0), 22)
    _texto(Vector2(cx - 42.0, 34.0), "%03d°" % (int(round(rumo)) % 360), 24, CREME, HORIZONTAL_ALIGNMENT_CENTER, 84.0)
    var px_por_grau := meia * 2.0 / 135.0                      # a fita mostra 135 graus
    draw_line(Vector2(cx - meia + 10.0, y + 14.0), Vector2(cx + meia - 10.0, y + 14.0), Color(CREME, 0.7), 1.5)
    var primeiro := int(floor((rumo - 75.0) / 15.0)) * 15
    for g in range(primeiro, primeiro + 180, 15):
        var x := cx + (float(g) - rumo) * px_por_grau
        if x < cx - meia + 14.0 or x > cx + meia - 14.0:
            continue
        var grau := posmod(g, 360)
        var apagar := clampf((meia - absf(x - cx)) / 70.0, 0.0, 1.0)   # some nas pontas da fita
        if grau % 45 == 0:
            draw_line(Vector2(x, y + 6.0), Vector2(x, y + 16.0), Color(CREME, apagar), 2.0)
            _texto(Vector2(x - 30.0, y + 6.0), PONTOS[grau / 45], 17, Color(DOURADO if grau == 0 else CREME, apagar), HORIZONTAL_ALIGNMENT_CENTER, 60.0)
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
    _texto(Vector2(x + 62.0, 64.0), missao_titulo, 22, DOURADO)
    var caixa := Rect2(x + 22.0, 98.0, 16.0, 16.0)
    draw_rect(caixa, CREME, false, 2.0)
    if missao_feita:
        draw_polyline(PackedVector2Array([caixa.position + Vector2(3, 8), caixa.position + Vector2(7, 13), caixa.position + Vector2(15, 1)]), VERDE, 3.0)
    var tam_texto := 18
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
    draw_circle(c, raio + 7.0, Color(TINTA, 0.85))
    draw_circle(c, raio, Color(0.06, 0.28, 0.36, 0.88))
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
    draw_arc(c, raio, 0.0, TAU, 72, CREME, 2.5, true)
    for i in 28:                                               # círculo tracejado: metade do alcance
        if i % 2 == 0:
            draw_arc(c, raio * 0.5, TAU * i / 28.0, TAU * (i + 1) / 28.0, 4, Color(CREME, 0.40), 1.5, true)
    # o radar gira com o barco: a proa aponta sempre para cima, e o N dá a volta na borda
    var norte := Vector2.UP.rotated(deg_to_rad(-rumo))
    if barco_ref != null:
        var ang: float = barco_ref.rotation.y                  # sem arredondar: gira suave
        norte = Vector2.UP.rotated(ang)
    var pn := c + norte * (raio + 1.0)
    draw_circle(pn, 13.0, Color(TINTA, 1.0))
    _texto(pn + Vector2(-13.0, 6.0), "N", 16, DOURADO, HORIZONTAL_ALIGNMENT_CENTER, 26.0)
    for alvo in radar_alvos:                                   # cardumes: peixinho no lugar; fora do alcance, um traço na borda
        var rel: Vector2 = alvo.pos
        if barco_ref != null and alvo.has("mundo"):
            rel = _rel_barco(alvo.mundo)
        var p := Vector2(rel.x, -rel.y) / alcance_radar * raio
        if p.length() > raio - 14.0:
            var dir := p.normalized()
            draw_line(c + dir * (raio - 11.0), c + dir * (raio - 3.0), Color(CREME, 0.6), 3.0)
        else:
            _icone_peixe(c + p, 1.35 if alvo.get("grande", false) else 1.0, Color(0.75, 0.93, 0.95))
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
    var rodape := "Percorrido: %d m" % int(distancia) if cais_rel == Vector2.INF else "Cais a %d m" % int(cais_dist)
    _texto(Vector2(c.x - raio, c.y + raio + 26.0), rodape, 18, CREME, HORIZONTAL_ALIGNMENT_CENTER, raio * 2.0)

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
    _texto(Vector2(x + 170.0, y + 121.0), "%d L" % roundi(litros), 16, CREME)
    var c := Vector2(x + 40.0, y + 40.0)
    draw_arc(c, 24.0, 0.0, TAU, 48, DOURADO, 3.0, true)
    for i in 7:
        var a := PI * 0.75 + PI * 1.5 * i / 6.0
        draw_line(c + Vector2.from_angle(a) * 17.0, c + Vector2.from_angle(a) * 21.0, DOURADO, 2.0)
    var ponteiro := PI * 0.75 + PI * 1.5 * clampf(fracao_motor, 0.0, 1.0)
    draw_line(c, c + Vector2.from_angle(ponteiro) * 17.0, CREME, 3.0)
    draw_circle(c, 3.5, CREME)
    _texto(Vector2(x + 78.0, y + 46.0), ("%.1f" % nos).replace(".", ","), 32, CREME)
    var larg := _fonte.get_string_size(("%.1f" % nos), HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x
    _texto(Vector2(x + 86.0 + larg, y + 46.0), "nós", 20, CREME)
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
        var cor := DOURADO if (aceso or nome == _sobre) else CREME
        _caixa_arredondada(r, Color(0.10, 0.17, 0.25, 0.92))
        _contorno_arredondado(r, cor if aceso else Color(cor, 0.55), 3.5 if aceso else 2.0)
        var c := r.position + r.size / 2.0
        match nome:
            "pescar": _icone_anzol(c, cor)
            "porao": _icone_caixa(c, cor)
            "diario": _icone_livro(c, cor)
            "config": _icone_engrenagem(c, 17.0, cor)
        if nome == _sobre:
            _texto(Vector2(r.position.x - 60.0, r.position.y - 12.0), DICA[nome], 14, CREME, HORIZONTAL_ALIGNMENT_CENTER, TAM_BOTAO + 120.0)

func _aviso() -> void:
    if dica != "" and painel_aberto == "":                     # dica fixa, em dourado, logo acima dos botões
        var ld := _fonte.get_string_size(dica, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 60.0
        var rd := Rect2(size.x / 2.0 - ld / 2.0, size.y - 168.0, ld, 42.0)
        _pincelada(rd, 62, Color(TINTA, 0.92))
        draw_string(_fonte, Vector2(rd.position.x, rd.position.y + 29.0), dica, HORIZONTAL_ALIGNMENT_CENTER, ld, 20, DOURADO)
    if aviso_tempo <= 0.0 or aviso_texto == "" or painel_aberto != "":
        return
    var alfa := clampf(aviso_tempo / 0.6, 0.0, 1.0)
    var larg := minf(_fonte.get_string_size(aviso_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 60.0, 760.0)
    var r := Rect2(size.x / 2.0 - larg / 2.0, size.y - (246.0 if dica != "" else 196.0), larg, 40.0)
    _pincelada(r, 61, Color(TINTA, 0.88 * alfa))
    draw_string(_fonte, Vector2(r.position.x, r.position.y + 27.0), aviso_texto, HORIZONTAL_ALIGNMENT_CENTER, larg, 18, Color(CREME, alfa))

func _painel() -> void:
    if painel_aberto == "":
        return
    if painel_aberto == "porao" and porao != null:
        _painel_porao()
        return
    var r := Rect2(size.x / 2.0 - 250.0, size.y / 2.0 - 190.0, 500.0, 340.0)
    _pincelada(r, 71, Color(TINTA, 0.95))
    _texto(Vector2(r.position.x + 28.0, r.position.y + 44.0), titulo_painel, 24, DOURADO)
    draw_line(Vector2(r.position.x + 28.0, r.position.y + 56.0), Vector2(r.end.x - 28.0, r.position.y + 56.0), Color(CREME, 0.4), 1.5)
    var y := r.position.y + 88.0
    for linha in linhas_painel:
        draw_string(_fonte, Vector2(r.position.x + 28.0, y), str(linha), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56.0, 16, CREME)
        y += 26.0

## Minijogo de pesca: anel com faixas verdes, ponteiro girando e a barra do peixe subindo.
func _anel_de_pesca() -> void:
    if pesca == null or pesca.estado == pesca.Estado.PRONTO or painel_aberto != "":
        return
    var c := Vector2(196.0, size.y / 2.0 - 6.0)
    var raio := 92.0
    var grossura := 20.0
    _pincelada(Rect2(c.x - 138.0, c.y - 176.0, 276.0, 50.0), 81)
    _pincelada(Rect2(c.x - 128.0, c.y + 122.0, 256.0, 78.0), 82)
    var especie: String = pesca.alvo.get("especie", "")
    _texto(Vector2(c.x - 138.0, c.y - 142.0), especie.to_upper(), 24, DOURADO, HORIZONTAL_ALIGNMENT_CENTER, 276.0)
    # o anel
    draw_circle(c, raio + grossura / 2.0 + 9.0, Color(TINTA, 0.90))
    draw_circle(c, raio - grossura / 2.0 - 3.0, Color(0.06, 0.28, 0.36, 0.92))
    draw_arc(c, raio, 0.0, TAU, 96, Color(0.02, 0.06, 0.09, 0.95), grossura, true)
    draw_arc(c, raio + grossura / 2.0 + 2.0, 0.0, TAU, 96, Color(CREME, 0.85), 2.0, true)
    draw_arc(c, raio - grossura / 2.0 - 2.0, 0.0, TAU, 96, Color(CREME, 0.45), 1.5, true)
    var sob: int = pesca.faixa_sob_ponteiro()
    for i in pesca.faixas.size():
        var f: Dictionary = pesca.faixas[i]
        if float(f.usada) > 0.0:
            continue
        var a0: float = float(f.centro) - float(f.largura) / 2.0 - PI / 2.0       # 0 = topo
        var a1: float = a0 + float(f.largura)
        draw_arc(c, raio, a0, a1, 20, VERDE.lightened(0.25) if i == sob else VERDE, grossura - 4.0, true)
        var meio: float = float(f.largura) * pesca.PARTE_DOURADA / 2.0
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
    if pesca.brilho > 0.0:                                     # clarão do acerto
        draw_arc(c, raio, 0.0, TAU, 96, Color(DOURADO if pesca.ultimo_perfeito else VERDE, pesca.brilho * 1.6), 3.0 + (0.35 - pesca.brilho) * 40.0, true)
    # embaixo: barra do peixe, cardume e a tecla
    _barra(Rect2(c.x - 106.0, c.y + 132.0, 212.0, 18.0), p, DOURADO if p > 0.8 else VERDE)
    _texto(Vector2(c.x - 106.0, c.y + 174.0), "Cardume: %s" % pesca.estoque(), 16, CREME)
    # Indicador de tensão: vermelho próximo do limite da linha.
    var tensao_atual: float = clampf(float(pesca.tensao) / maxf(0.1, float(pesca.limite_linha)), 0.0, 1.0)
    _barra(Rect2(c.x - 106.0, c.y + 183.0, 212.0, 8.0), tensao_atual,
        Color(0.94, 0.28, 0.20) if tensao_atual > 0.72 else Color(0.90, 0.66, 0.28))
    var tecla := Rect2(c.x + 30.0, c.y + 157.0, 24.0, 24.0)
    _caixa_arredondada(tecla, CREME if pesca.trava <= 0.0 else Color(CREME, 0.4))
    draw_string(_fonte, Vector2(tecla.position.x, tecla.position.y + 18.0), "F", HORIZONTAL_ALIGNMENT_CENTER, 24.0, 16, Color(0.06, 0.10, 0.15))
    _texto(Vector2(tecla.end.x + 8.0, c.y + 175.0), "Puxar", 16, CREME)

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
func _peixe_na_grade(especie: String, casas: Array, origem: Vector2, cor: Color, alfa: float = 1.0) -> void:
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
    var textura: Texture2D = _sprites_peixes.get(especie)
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
    else:
        _icone_peixe(centro, maxf(1.1, comprimento / 22.0), Color(cor, alfa))

func _painel_porao() -> void:
    var r := _ret_painel_porao()
    _pincelada(r, 71, Color(TINTA, 0.96))
    if _textura_madeira != null:
        draw_texture_rect(_textura_madeira, r.grow(-5.0), false, Color(0.85, 0.93, 0.94, 0.62))
    draw_rect(r.grow(-5.0), Color(0.02, 0.06, 0.10, 0.18), false, 3.0)
    _icone_caixa(Vector2(r.position.x + 44.0, r.position.y + 40.0), DOURADO)
    _texto(Vector2(r.position.x + 76.0, r.position.y + 46.0), "Porão", 26, DOURADO)
    _texto(Vector2(r.position.x + 160.0, r.position.y + 46.0), "%d de %d casas" % [porao.casas_ocupadas(), porao.colunas * porao.linhas], 16, Color(CREME, 0.8))
    draw_line(Vector2(r.position.x + 28.0, r.position.y + 58.0), Vector2(r.end.x - 28.0, r.position.y + 58.0), Color(CREME, 0.4), 1.5)
    var o := _origem_grade()
    draw_rect(Rect2(o, Vector2(porao.colunas, porao.linhas) * CASA), Color(0.015, 0.045, 0.07, 0.95))
    for j in porao.linhas:
        for i in porao.colunas:
            var casa_rect := Rect2(o + Vector2(i, j) * CASA, Vector2(CASA, CASA))
            if _textura_casa != null:
                draw_texture_rect(_textura_casa, casa_rect, false, Color(1, 1, 1, 0.94))
            else:
                draw_rect(casa_rect.grow(-1), Color(0.10, 0.18, 0.22, 0.95), true)
    var sob: Dictionary = porao.item_em(_casa_em(_mouse)) if _na_mao.is_empty() else _na_mao
    for item in porao.itens:
        if is_same(item, _na_mao):
            continue
        var cor: Color = porao.CORES.get(item.especie, CREME)
        _peixe_na_grade(item.especie, porao.casas_do_item(item), o, cor.lightened(0.2) if is_same(item, sob) else cor)
    if not _na_mao.is_empty():                                 # o peixe na mão: verde onde cabe, vermelho onde não
        var canto := _canto_da_mao()
        var casas: Array = []
        for c in porao.casas(_na_mao.especie, _rot_mao):
            casas.append(c + canto)
        var cabe: bool = porao.cabe_em(_na_mao.especie, canto.x, canto.y, _rot_mao, _na_mao)
        _peixe_na_grade(_na_mao.especie, casas, o, VERDE if cabe else Color(0.93, 0.34, 0.26), 0.85)
    # à direita: o peixe apontado, os totais e as instruções
    var x: float = o.x + porao.colunas * CASA + 26.0
    var y := r.position.y + 96.0
    if not sob.is_empty():
        _texto(Vector2(x, y), sob.especie, 22, porao.CORES.get(sob.especie, CREME))
        _texto(Vector2(x, y + 26.0), "%s kg  •  %s" % [("%.1f" % sob.peso).replace(".", ","), String(sob.get("qualidade", "Regular"))], 16, CREME)
    else:
        _texto(Vector2(x, y), "%d peixe(s)" % porao.itens.size(), 22, CREME)
        _texto(Vector2(x, y + 26.0), "%s kg  •  R$ %d" % [("%.1f" % porao.peso_total()).replace(".", ","), porao.valor_total()], 16, CREME)
    var dicas := ["Clique num peixe para pegar.", "Clique numa casa para soltar.", "R ou botão direito: girar."] if not porao.itens.is_empty() \
            else ["Vazio. Pare perto de um", "cardume e pesque com F.", "Peixe grande ocupa mais casas."]
    for i in dicas.size():
        draw_string(_fonte, Vector2(x, y + 66.0 + i * 22.0), dicas[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(CREME, 0.75))
    var b := _ret_arrumar()
    var sobre_botao := b.has_point(_para_painel(_mouse))
    var devolver := not _na_mao.is_empty()
    _caixa_arredondada(b, Color(0.50, 0.16, 0.12, 0.95) if devolver else Color(0.10, 0.17, 0.25, 0.95))
    _contorno_arredondado(b, DOURADO if sobre_botao else Color(CREME, 0.55), 2.0)
    draw_string(_fonte, Vector2(b.position.x, b.position.y + 25.0), "Devolver ao mar" if devolver else "Arrumar o porão", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 16, CREME)

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

func _icone_barco(c: Vector2, escala: float, cor: Color) -> void:
    var s := escala
    draw_colored_polygon(PackedVector2Array([c + Vector2(-44, 4) * s, c + Vector2(48, 4) * s, c + Vector2(36, 22) * s, c + Vector2(-34, 22) * s]), cor)
    draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -12) * s, c + Vector2(26, -12) * s, c + Vector2(26, 2) * s, c + Vector2(-6, 2) * s]), cor)
    draw_line(c + Vector2(-16, 2) * s, c + Vector2(-16, -34) * s, cor, 2.5)
    draw_line(c + Vector2(-16, -30) * s, c + Vector2(-40, 2) * s, cor, 1.5)
    draw_line(c + Vector2(-16, -30) * s, c + Vector2(10, -12) * s, cor, 1.5)
    draw_rect(Rect2(c + Vector2(0, -8) * s, Vector2(7, 6) * s), TINTA)
    draw_rect(Rect2(c + Vector2(12, -8) * s, Vector2(7, 6) * s), TINTA)

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

func _icone_livro(c: Vector2, cor: Color) -> void:
    draw_polyline(PackedVector2Array([c + Vector2(-17, -18), c + Vector2(15, -18), c + Vector2(15, 12), c + Vector2(-11, 12)]), cor, 3.0)
    draw_arc(c + Vector2(-11, 16), 4.0, PI * 0.5, PI * 1.5, 8, cor, 3.0, true)
    draw_line(c + Vector2(-17, -18), c + Vector2(-17, 16), cor, 3.0)
    draw_line(c + Vector2(-11, 20), c + Vector2(15, 20), cor, 3.0)
    draw_line(c + Vector2(15, 12), c + Vector2(15, 20), cor, 3.0)
    draw_line(c + Vector2(-7, -9), c + Vector2(7, -9), cor, 2.0)
