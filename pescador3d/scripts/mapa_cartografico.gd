extends Control
## Carta náutica 2D desenhada em Canvas: escala uniforme, grade legível,
## ilhas e costa, coordenadas locais em metros, interação por rolagem/arrasto.

var barco: Node3D = null
var ilhas: Array = []
var _contornos: Array = []
var pontos_extras: Array = []
var _zoom: float = 1.0
var _mpp_base: float = 1.0
var _centro_carta: Vector2 = Vector2(-100.0, -240.0)
var _deslocamento: Vector2 = Vector2.ZERO
var _arrastando: bool = false
var _mouse_anterior: Vector2 = Vector2.ZERO
var _relogio: float = 0.0
# Navegação por ponto marcado (coordenadas locais, não GPS real).
var marcador: Vector2 = Vector2.ZERO
var tem_marcador: bool = false
var _mundo: Node = null
var _cores_profundidade: Array = []
var _batimetria_suja: bool = true
const BATH_COLS: int = 32
const BATH_ROWS: int = 18

const TINTA := Color(0.18, 0.27, 0.28)
const SEPIA := Color(0.32, 0.28, 0.21)
const AREIA := Color(0.87, 0.81, 0.67)
const MAR := Color(0.70, 0.82, 0.82)
const MARGEM_LATERAL := 52.0

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false

func configurar(p_barco: Node3D, p_ilhas: Array) -> void:
    barco = p_barco
    ilhas = p_ilhas.duplicate()
    _reconstruir()

func configurar_batimetria(mundo: Node) -> void:
    _mundo = mundo
    _batimetria_suja = true

func distancia_ate_destino() -> float:
    if barco == null or not tem_marcador:
        return -1.0
    return Vector2(barco.global_position.x, barco.global_position.z).distance_to(marcador)

func configurar_extras(pontos: Array) -> void:
    pontos_extras = pontos.duplicate(true)
    _reconstruir()

func alternar() -> bool:
    visible = not visible
    if visible:
        _zoom = 1.0
        _deslocamento = Vector2.ZERO
        _reconstruir()
        _batimetria_suja = true
        queue_redraw()
    return visible

func fechar() -> void:
    visible = false
    _arrastando = false

func aberto() -> bool:
    return visible

func _process(delta: float) -> void:
    if not visible:
        return
    _relogio += delta
    if _relogio > 0.15:
        _relogio = 0.0
        queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            _zoom = minf(3.6, _zoom * 1.2)
            _batimetria_suja = true
            queue_redraw()
            accept_event()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            _zoom = maxf(0.65, _zoom / 1.2)
            _batimetria_suja = true
            queue_redraw()
            accept_event()
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _arrastando = event.pressed
            _mouse_anterior = event.position
            accept_event()
        elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and event.double_click:
            _deslocamento = Vector2.ZERO
            _zoom = 1.0
            _batimetria_suja = true
            queue_redraw()
            accept_event()
        elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
            var quadro: Rect2 = _quadro()
            if quadro.has_point(event.position):
                if event.shift_pressed:
                    tem_marcador = false
                else:
                    marcador = _mundo_do_pixel(event.position, quadro)
                    tem_marcador = true
                queue_redraw()
                accept_event()
    elif event is InputEventMouseMotion and _arrastando:
        _deslocamento -= (event.position - _mouse_anterior) * _metros_por_pixel()
        _batimetria_suja = true
        _mouse_anterior = event.position
        queue_redraw()
        accept_event()

func _quadro() -> Rect2:
    return Rect2(Vector2(MARGEM_LATERAL, 108.0), Vector2(maxf(160.0, size.x - MARGEM_LATERAL * 2.0), maxf(160.0, size.y - 210.0)))

func _metros_por_pixel() -> float:
    return _mpp_base / _zoom

func _posicao(p: Vector2, area: Rect2) -> Vector2:
    return area.get_center() + (p - _centro_carta - _deslocamento) / _metros_por_pixel()

func _mundo_do_pixel(pixel: Vector2, area: Rect2) -> Vector2:
    return _centro_carta + _deslocamento + (pixel - area.get_center()) * _metros_por_pixel()

func _batimetria(area: Rect2) -> void:
    if _mundo == null:
        return
    var largura: float = area.size.x / float(BATH_COLS)
    var altura: float = area.size.y / float(BATH_ROWS)
    if _batimetria_suja or _cores_profundidade.size() != BATH_COLS * BATH_ROWS:
        _cores_profundidade.clear()
        for y in BATH_ROWS:
            for x in BATH_COLS:
                var ponto: Vector2 = area.position + Vector2((float(x) + 0.5) * largura, (float(y) + 0.5) * altura)
                var amostra: Vector2 = _mundo_do_pixel(ponto, area)
                var fundo: float = float(_mundo.altura_terra(Vector3(amostra.x, 0.0, amostra.y)))
                var cor: Color = Color(0.23, 0.44, 0.58, 0.24)
                if fundo > -3.0:
                    cor = Color(0.60, 0.78, 0.69, 0.32)
                elif fundo > -10.0:
                    cor = Color(0.40, 0.70, 0.72, 0.26)
                elif fundo > -25.0:
                    cor = Color(0.31, 0.60, 0.68, 0.23)
                _cores_profundidade.append(cor)
        _batimetria_suja = false
    for y in BATH_ROWS:
        for x in BATH_COLS:
            var r := Rect2(area.position + Vector2(float(x) * largura, float(y) * altura), Vector2(largura + 0.3, altura + 0.3))
            draw_rect(r, _cores_profundidade[y * BATH_COLS + x], true)

func _marcador_rota(area: Rect2) -> void:
    if not tem_marcador:
        return
    var destino: Vector2 = _posicao(marcador, area)
    if barco != null:
        var origem: Vector2 = _posicao(Vector2(barco.global_position.x, barco.global_position.z), area)
        # Segmento direto, não é um piloto automático: o jogador deve evitar terra e recifes.
        draw_dashed_line(origem, destino, Color(0.68, 0.27, 0.18, 0.88), 2.4, 9.0, true)
    if _dentro(area, destino, 12.0):
        draw_circle(destino, 10.0, Color(0.96, 0.88, 0.67))
        draw_arc(destino, 8.0, 0.0, TAU, 24, Color(0.72, 0.24, 0.14), 2.0)
        _centrar("DESTINO", destino + Vector2(0, -15), 12, Color(0.42, 0.22, 0.16))

func _reconstruir() -> void:
    _contornos.clear()
    var minimo := Vector2(-70.0, -80.0)
    var maximo := Vector2(70.0, 80.0)
    if barco != null:
        var navio: Vector2 = Vector2(barco.global_position.x, barco.global_position.z)
        minimo.x = minf(minimo.x, navio.x - 100.0)
        minimo.y = minf(minimo.y, navio.y - 100.0)
        maximo.x = maxf(maximo.x, navio.x + 100.0)
        maximo.y = maxf(maximo.y, navio.y + 100.0)
    for ilha in ilhas:
        var c: Vector2 = Vector2(ilha.centro.x, ilha.centro.z)
        var r: float = float(ilha.raio) + 85.0
        minimo.x = minf(minimo.x, c.x - r)
        minimo.y = minf(minimo.y, c.y - r)
        maximo.x = maxf(maximo.x, c.x + r)
        maximo.y = maxf(maximo.y, c.y + r)
        _contornos.append({"ilha": ilha, "linha": _contorno(ilha, 0.0), "alto": _contorno(ilha, 9.0)})
    for ponto in pontos_extras:
        var c_extra: Vector2 = ponto.get("pos", Vector2.ZERO)
        var raio_extra: float = float(ponto.get("raio", 25.0)) + 70.0
        minimo.x = minf(minimo.x, c_extra.x - raio_extra)
        minimo.y = minf(minimo.y, c_extra.y - raio_extra)
        maximo.x = maxf(maximo.x, c_extra.x + raio_extra)
        maximo.y = maxf(maximo.y, c_extra.y + raio_extra)
    _centro_carta = (minimo + maximo) * 0.5
    _batimetria_suja = true
    var area: Rect2 = _quadro()
    _mpp_base = maxf(maxf((maximo.x - minimo.x) / maxf(area.size.x, 1.0), (maximo.y - minimo.y) / maxf(area.size.y, 1.0)), 0.4)

func _contorno(ilha: Node3D, nivel: float) -> PackedVector2Array:
    var resultado := PackedVector2Array()
    for k in 96:
        var angulo: float = TAU * float(k) / 96.0
        var dir: Vector2 = Vector2(cos(angulo), sin(angulo))
        var inicio: float = 0.0
        var fim: float = float(ilha.raio) * 1.8
        for j in 12:
            var meio: float = (inicio + fim) * 0.5
            var ponto: Vector3 = Vector3(ilha.centro.x + meio * dir.x, 0.0, ilha.centro.z + meio * dir.y)
            if float(ilha.altura_em(ponto)) > nivel:
                inicio = meio
            else:
                fim = meio
        resultado.append(Vector2(ilha.centro.x, ilha.centro.z) + dir * inicio)
    return resultado

func _escrever(mensagem: String, p: Vector2, tam: int, cor: Color = TINTA) -> void:
    var fonte: Font = ThemeDB.fallback_font
    if fonte == null:
        return
    draw_string(fonte, p, mensagem, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, cor)

func _centrar(mensagem: String, centro: Vector2, tam: int, cor: Color = TINTA) -> void:
    var fonte: Font = ThemeDB.fallback_font
    if fonte == null:
        return
    var largura: float = fonte.get_string_size(mensagem, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
    _escrever(mensagem, centro - Vector2(largura * 0.5, 0.0), tam, cor)

func _dentro(area: Rect2, p: Vector2, margem: float = 0.0) -> bool:
    return area.grow(-margem).has_point(p)

func _linha_fechada(pontos: PackedVector2Array, cor: Color, espessura: float = 1.0) -> void:
    if pontos.size() < 3:
        return
    var linha := PackedVector2Array(pontos)
    linha.append(pontos[0])
    draw_polyline(linha, cor, espessura, true)

func _bussola(c: Vector2) -> void:
    draw_circle(c, 36.0, Color(0.94, 0.90, 0.78, 0.90))
    draw_arc(c, 34.0, 0.0, TAU, 56, Color(0.28, 0.40, 0.42), 1.7, true)
    draw_line(c - Vector2(27.0, 0.0), c + Vector2(27.0, 0.0), Color(0.38, 0.45, 0.43), 1.0)
    draw_line(c - Vector2(0.0, 27.0), c + Vector2(0.0, 27.0), Color(0.38, 0.45, 0.43), 1.0)
    draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -28.0), c + Vector2(-8.0, 8.0), c]), Color(0.71, 0.25, 0.19))
    draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -28.0), c + Vector2(8.0, 8.0), c]), Color(0.31, 0.42, 0.45))
    _centrar("N", c + Vector2(0.0, -40.0), 14)
    _centrar("S", c + Vector2(0.0, 50.0), 12)
    _centrar("O", c + Vector2(-44.0, 4.0), 12)
    _centrar("L", c + Vector2(44.0, 4.0), 12)

func _grade(area: Rect2) -> void:
    var mpp: float = _metros_por_pixel()
    var salto: float = 100.0
    for proximo in [50.0, 100.0, 200.0, 250.0, 500.0, 1000.0, 2000.0]:
        if float(proximo) / mpp >= 110.0:
            salto = float(proximo)
            break
        salto = float(proximo)
    var a: Vector2 = _centro_carta + _deslocamento - area.size * 0.5 * mpp
    var b: Vector2 = _centro_carta + _deslocamento + area.size * 0.5 * mpp
    var x: float = ceilf(a.x / salto) * salto
    while x <= b.x:
        var px: float = _posicao(Vector2(x, 0.0), area).x
        draw_line(Vector2(px, area.position.y), Vector2(px, area.end.y), Color(0.28, 0.50, 0.54, 0.18), 1.0, true)
        _centrar("%+d E" % int(x), Vector2(px, area.position.y + 18.0), 11, Color(0.27, 0.42, 0.43))
        x += salto
    var z: float = ceilf(a.y / salto) * salto
    while z <= b.y:
        var py: float = _posicao(Vector2(0.0, z), area).y
        draw_line(Vector2(area.position.x, py), Vector2(area.end.x, py), Color(0.28, 0.50, 0.54, 0.18), 1.0, true)
        _escrever("%+d N" % int(-z), Vector2(area.position.x + 9.0, py - 6.0), 11, Color(0.27, 0.42, 0.43))
        z += salto

func _ilha(item: Dictionary, area: Rect2) -> void:
    var ilha: Node3D = item.ilha
    var centro: Vector2 = Vector2(ilha.centro.x, ilha.centro.z)
    var tela := PackedVector2Array()
    var sulco := PackedVector2Array()
    for p in item.linha:
        tela.append(_posicao(p, area))
    for p in item.alto:
        sulco.append(_posicao(p, area))
    if tela.size() < 3:
        return
    # Rasos ao redor da linha de costa, representados como uma banda verde-azulada.
    var rasa := PackedVector2Array()
    for p in item.linha:
        rasa.append(_posicao(centro + (p - centro) * 1.18, area))
    draw_colored_polygon(rasa, Color(0.47, 0.73, 0.74, 0.40))
    _linha_fechada(rasa, Color(0.32, 0.58, 0.62, 0.48), 1.3)
    draw_colored_polygon(tela, Color(0.75, 0.76, 0.56))
    _linha_fechada(tela, Color(0.25, 0.34, 0.24), 2.5)
    if sulco.size() >= 3:
        _linha_fechada(sulco, Color(0.53, 0.58, 0.39, 0.72), 1.3)
    var pnome: Vector2 = _posicao(centro, area)
    if _dentro(area, pnome, 30.0):
        var nome: String = String(ilha.nome).to_upper()
        var fonte: Font = ThemeDB.fallback_font
        var largura: float = fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
        var etiqueta := Rect2(pnome.x - largura * 0.5 - 10.0, pnome.y - 6.0, largura + 20.0, 24.0)
        draw_rect(etiqueta, Color(0.93, 0.89, 0.75, 0.83), true)
        draw_rect(etiqueta, Color(0.51, 0.49, 0.35, 0.50), false, 1.0)
        _centrar(nome, pnome + Vector2(0.0, 12.0), 15, Color(0.22, 0.25, 0.17))
    var cais: Vector2 = _posicao(Vector2(ilha.cais_ponta.x, ilha.cais_ponta.z), area)
    if _dentro(area, cais, 10.0):
        draw_circle(cais, 7.0, Color(0.98, 0.90, 0.73, 0.95))
        draw_rect(Rect2(cais - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), Color(0.59, 0.31, 0.20), true)
        _escrever("Cais", cais + Vector2(12.0, 5.0), 13, Color(0.26, 0.25, 0.18))
    # Pontos turísticos: círculos discretos, sem sobrepor a identificação da vila.
    for entrada in ilha.pontos_interesse:
        var interesse: Dictionary = entrada
        var pos_mundo: Vector2 = interesse.get("pos", Vector2.ZERO)
        var p: Vector2 = _posicao(pos_mundo, area)
        if not _dentro(area, p, 12.0):
            continue
        var is_recife: bool = String(interesse.get("tipo", "")) == "recife"
        var tinta: Color = Color(0.18, 0.48, 0.49) if is_recife else Color(0.44, 0.31, 0.17)
        draw_circle(p, 8.0, Color(0.94, 0.89, 0.74, 0.84))
        draw_arc(p, 6.5, 0.0, TAU, 16, tinta, 1.8, true)
        draw_circle(p, 2.1, tinta)
        if _zoom >= 1.35:
            _escrever(String(interesse.get("nome", "")), p + Vector2(12.0, -8.0), 11, tinta)

func _pontos_exploracao(area: Rect2) -> void:
    for item in pontos_extras:
        var c: Vector2 = item.get("pos", Vector2.ZERO)
        var p: Vector2 = _posicao(c, area)
        if not _dentro(area, p, 15.0):
            continue
        var raio_m: float = float(item.get("raio", 20.0))
        var raio_tela: float = clampf(raio_m / _metros_por_pixel(), 4.0, 45.0)
        var banco: bool = String(item.get("tipo", "recife")) == "banco"
        var cor: Color = Color(0.40, 0.62, 0.60, 0.72) if banco else Color(0.29, 0.51, 0.48, 0.84)
        draw_arc(p, raio_tela, 0.0, TAU, 48, cor, 2.0, true)
        draw_circle(p, 4.0, cor)
        _escrever(String(item.get("nome", "")), p + Vector2(raio_tela + 7.0, -5.0), 12, TINTA)

func _barco(area: Rect2) -> void:
    if barco == null:
        return
    var p: Vector2 = _posicao(Vector2(barco.global_position.x, barco.global_position.z), area)
    if not _dentro(area, p, 15.0):
        return
    var frente3: Vector3 = -barco.global_transform.basis.z
    var rumo: Vector2 = Vector2(frente3.x, frente3.z).normalized()
    var lado: Vector2 = Vector2(-rumo.y, rumo.x)
    var tri := PackedVector2Array([p + rumo * 13.0, p - rumo * 7.0 + lado * 7.0, p - rumo * 7.0 - lado * 7.0])
    draw_circle(p, 18.0, Color(0.95, 0.85, 0.68, 0.65))
    draw_colored_polygon(tri, Color(0.82, 0.27, 0.18))
    _linha_fechada(tri, Color(0.35, 0.18, 0.15), 1.4)
    _escrever("PE-3476", p + Vector2(15.0, -13.0), 13, Color(0.18, 0.24, 0.28))

func _draw() -> void:
    if not visible or size.x < 420.0 or size.y < 350.0:
        return
    var quadro: Rect2 = _quadro()
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.05, 0.07, 0.86), true)
    var folha: Rect2 = Rect2(Vector2(14.0, 12.0), size - Vector2(28.0, 24.0))
    draw_rect(folha, Color(0.93, 0.88, 0.75), true)
    draw_rect(folha.grow(-5.0), Color(0.50, 0.40, 0.28, 0.75), false, 1.6)
    # Cabeçalho completamente separado da área da grade.
    draw_rect(Rect2(Vector2(22.0, 20.0), Vector2(size.x - 44.0, 66.0)), Color(0.94, 0.90, 0.78), true)
    _escrever("CARTA NÁUTICA", Vector2(49.0, 56.0), 27, Color(0.23, 0.27, 0.26))
    _escrever("REGIÃO DA VILA DO PORTO  /  coordenadas locais em metros", Vector2(52.0, 76.0), 12, SEPIA)
    _escrever("M fechar • Roda zoom • Arrastar direito mover • Clique marcar • Shift+clique limpar", Vector2(maxf(430.0, size.x - 770.0), 72.0), 12, SEPIA)
    draw_rect(quadro, MAR, true)
    _batimetria(quadro)
    draw_rect(quadro, Color(0.28, 0.42, 0.43), false, 2.0)
    _grade(quadro)
    for i in _contornos:
        _ilha(i, quadro)
    _pontos_exploracao(quadro)
    _barco(quadro)
    _marcador_rota(quadro)
    _bussola(quadro.position + Vector2(quadro.size.x - 65.0, 60.0))
    # Rodapé de navegação: conteúdo fora dos eixos, sem textos sobrepostos.
    var rodape_y: float = quadro.end.y + 26.0
    draw_line(Vector2(48.0, rodape_y - 10.0), Vector2(size.x - 48.0, rodape_y - 10.0), Color(0.54, 0.48, 0.33, 0.67), 1.5)
    var coordenadas := "POSIÇÃO  —  sem sinal de GPS"
    var rumo_graus: int = 0
    if barco != null:
        var p: Vector3 = barco.global_position
        coordenadas = "POSIÇÃO  E %+d m   |   N %+d m" % [roundi(p.x), roundi(-p.z)]
        rumo_graus = int(barco.rumo())
    _escrever(coordenadas, Vector2(52.0, rodape_y + 15.0), 15, TINTA)
    var distancia_destino: float = distancia_ate_destino()
    var sufixo: String = "  •  Destino %.0f m (linha direta)" % distancia_destino if distancia_destino >= 0.0 else "  •  Sem destino"
    _escrever("RUMO %03d°  •  %.1f m/px%s" % [rumo_graus, _metros_por_pixel(), sufixo], Vector2(52.0, rodape_y + 36.0), 12, SEPIA)
    var legenda_x: float = size.x - 560.0
    draw_circle(Vector2(legenda_x, rodape_y + 13.0), 6.0, Color(0.82, 0.27, 0.18))
    _escrever("Barco", Vector2(legenda_x + 13.0, rodape_y + 17.0), 13, TINTA)
    draw_rect(Rect2(Vector2(legenda_x + 92.0, rodape_y + 7.0), Vector2(11.0, 11.0)), Color(0.59, 0.31, 0.20), true)
    _escrever("Cais", Vector2(legenda_x + 110.0, rodape_y + 17.0), 13, TINTA)
    var escala_metros: float = 100.0
    var melhor_erro: float = INF
    for candidato in [25.0, 50.0, 100.0, 200.0, 500.0, 1000.0]:
        var erro: float = absf(float(candidato) / _metros_por_pixel() - 130.0)
        if erro < melhor_erro:
            escala_metros = float(candidato)
            melhor_erro = erro
    var escala_px: float = escala_metros / _metros_por_pixel()
    var base: Vector2 = Vector2(size.x - 85.0 - escala_px, rodape_y + 30.0)
    draw_line(base, base + Vector2(escala_px, 0.0), SEPIA, 3.0)
    draw_line(base - Vector2(0.0, 7.0), base + Vector2(0.0, 7.0), SEPIA, 2.0)
    draw_line(base + Vector2(escala_px, -7.0), base + Vector2(escala_px, 7.0), SEPIA, 2.0)
    _centrar("%d m" % int(escala_metros), base + Vector2(escala_px * 0.5, -9.0), 12, SEPIA)
