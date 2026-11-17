extends Node3D
## Cardumes com vizinhança local: seguem uma direção coletiva, mas cada peixe evita os outros.
## Mantém alguns cardumes em volta do barco; a pesca só funciona perto de um deles, e a espécie
## pescada é a do cardume. O radar da interface mostra onde eles estão.

signal cardume_dispersou(especie: String)

## peso em kg (mín, máx), quantos peixes aparecem, tamanho da sombra (m), chance de nascer,
## quantas capturas o cardume aguenta, quanto demora puxar sem acertar nada (s), o preço no cais (R$ por kg)
## e a dificuldade do anel de pesca: velocidade do ponteiro (voltas/s), nº de faixas verdes, largura delas
## (graus) e quantos acertos trazem o peixe
const ESPECIES := {
    "Sardinha": {"preco": 8, "peso": [0.1, 0.4], "peixes": 18, "tam": 0.34, "chance": 30, "capturas": [4, 6], "espera": [2.5, 4.5], "ponteiro": 0.42, "faixas": 3, "largura": 46, "acertos": 2, "so_dia": true},
    "Tainha": {"preco": 9, "peso": [0.6, 2.6], "peixes": 11, "tam": 0.55, "chance": 26, "capturas": [3, 5], "espera": [3.0, 6.0], "ponteiro": 0.50, "faixas": 3, "largura": 40, "acertos": 3},
    "Xaréu": {"preco": 11, "peso": [1.5, 6.0], "peixes": 8, "tam": 0.75, "chance": 20, "capturas": [3, 4], "espera": [3.5, 6.5], "ponteiro": 0.58, "faixas": 3, "largura": 34, "acertos": 3},
    "Cavala": {"preco": 12, "peso": [2.0, 9.0], "peixes": 6, "tam": 0.95, "chance": 15, "capturas": [2, 4], "espera": [4.0, 7.0], "ponteiro": 0.68, "faixas": 2, "largura": 32, "acertos": 4},
    "Barracuda": {"preco": 12, "peso": [1.5, 7.0], "peixes": 5, "tam": 1.05, "chance": 12, "capturas": [2, 4], "espera": [4.0, 7.0], "ponteiro": 0.72, "faixas": 3, "largura": 28, "acertos": 4, "so_dia": true},
    "Dourado": {"preco": 15, "peso": [3.0, 12.0], "peixes": 4, "tam": 1.1, "chance": 10, "capturas": [2, 3], "espera": [4.5, 7.5], "ponteiro": 0.80, "faixas": 2, "largura": 30, "acertos": 4, "alto_mar": true},
    "Atum": {"preco": 13, "peso": [8.0, 30.0], "peixes": 4, "tam": 1.4, "chance": 9, "capturas": [1, 2], "espera": [6.0, 9.0], "ponteiro": 0.90, "faixas": 2, "largura": 24, "acertos": 6, "alto_mar": true},
    "Olho-de-cão": {"preco": 20, "peso": [0.4, 1.6], "peixes": 9, "tam": 0.5, "chance": 34, "capturas": [3, 5], "espera": [3.0, 6.0], "ponteiro": 0.62, "faixas": 3, "largura": 32, "acertos": 3, "so_noite": true},
    "Garoupa": {"preco": 14, "peso": [3.0, 14.0], "peixes": 3, "tam": 1.25, "chance": 9, "capturas": [2, 3], "espera": [5.0, 8.0], "ponteiro": 0.78, "faixas": 2, "largura": 27, "acertos": 5, "vezes_noite": 2},
}
const MAXIMO := 7
const NASCE_MIN := 58.0        # m do barco
const NASCE_MAX := 225.0
const SOME := 340.0            # m: além disso o cardume é esquecido
const ALTO_MAR := 300.0         # m da costa mais próxima a partir de onde aparecem os peixes de alto-mar
const ALCANCE := 17.0          # m do centro do cardume até onde a linha alcança
const VISUAL := 2.05           # legíveis do barco, sem virar círculos gigantes sobre a água
const COR_DIA := Color(0.03, 0.15, 0.21, 0.88)       # de dia: silhueta escura sobre a água clara
const COR_NOITE := Color(0.54, 0.72, 0.78, 0.64)     # à noite: silhueta clara sobre a água escura
const INTERVALO := 4.5         # s entre nascimentos
const DIST_FUGA_BARCO: float = 27.0
const RECUPERACAO_FUGA: float = 8.0
# Valores de locomocao: estilos proprios, independentes dos atributos da pesca.
const NADO := {
    "Sardinha": {"vel": 1.2, "grupo": 1.35, "separa": 0.75, "muda": 0.28},
    "Tainha": {"vel": 1.0, "grupo": 1.1, "separa": 1.15, "muda": 0.23},
    "Xaréu": {"vel": 1.7, "grupo": 0.85, "separa": 1.45, "muda": 0.17},
    "Cavala": {"vel": 2.0, "grupo": 0.75, "separa": 1.55, "muda": 0.15},
    "Barracuda": {"vel": 1.6, "grupo": 0.50, "separa": 2.4, "muda": 0.12},
    "Dourado": {"vel": 1.85, "grupo": 0.75, "separa": 1.8, "muda": 0.18},
    "Atum": {"vel": 2.65, "grupo": 1.20, "separa": 1.9, "muda": 0.10},
    "Olho-de-cão": {"vel": 0.85, "grupo": 1.25, "separa": 0.9, "muda": 0.24},
    "Garoupa": {"vel": 0.65, "grupo": 0.45, "separa": 2.2, "muda": 0.10},
}

var lista: Array = []
var _alto_mar: bool = false     # o cardume que está nascendo fica longe das ilhas?
var _distancia_costeira: float = 9999.0
var _zona_local: String = "costeiro"
var _areas_descanso: Array = []  # regiões já pescadas/envelhecidas só voltam após a recuperação
var noite: bool = false:         # quem avisa é scripts/jogo.gd; algumas espécies só aparecem no escuro
    set(valor):
        if valor != noite:
            noite = valor
            for c in lista:
                _colorir(c)
var _barco: Node3D
var _oceano: Node
var _malha: ArrayMesh
var _material_base: StandardMaterial3D
var _materiais: Dictionary = {}
var _relogio: float = 0.0
var _tempo: float = 0.0
var simulando: bool = false  # controlado pelo jogo, evita nascimentos enquanto pausado

func _ready() -> void:
    _barco = get_node_or_null("../Barco")
    _oceano = get_node_or_null("../Oceano")
    _malha = _criar_malha_peixe()
    _material_base = StandardMaterial3D.new()
    _material_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material_base.albedo_color = Color(0.62, 0.80, 0.90, 0.72)
    _material_base.cull_mode = BaseMaterial3D.CULL_DISABLED
    _material_base.vertex_color_use_as_albedo = false
    _material_base.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED

## Silhueta de peixe vista de cima, deitada no plano da água, com a cabeça em -Z e 1 m de comprimento.
func _criar_malha_peixe() -> ArrayMesh:
    var contorno := PackedVector2Array([Vector2(0, -0.5), Vector2(0.11, -0.3), Vector2(0.14, -0.08), Vector2(0.09, 0.18),
            Vector2(0.03, 0.32), Vector2(0.13, 0.5), Vector2(0, 0.43), Vector2(-0.13, 0.5), Vector2(-0.03, 0.32),
            Vector2(-0.09, 0.18), Vector2(-0.14, -0.08), Vector2(-0.11, -0.3)])
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for tri in Geometry2D.triangulate_polygon(contorno):
        var p2: Vector2 = contorno[tri]
        st.set_normal(Vector3.UP)
        st.set_uv(Vector2(0.5 + p2.x / 0.34, p2.y + 0.5))
        st.add_vertex(Vector3(p2.x, 0.0, p2.y))
    return st.commit()

func _arquivo_textura(especie: String) -> String:
    var nome := especie.to_lower().replace("-", "_").replace("ã", "a").replace("á", "a").replace("â", "a").replace("é", "e").replace("ê", "e").replace("í", "i").replace("ó", "o").replace("ô", "o").replace("õ", "o").replace("ú", "u").replace("ç", "c")
    return "res://assets/texturas/peixes/cardumes/%s.png" % nome

func _material_da_especie(especie: String) -> Material:
    if _materiais.has(especie):
        return _materiais[especie]
    var m: StandardMaterial3D = _material_base.duplicate()
    var arquivo := _arquivo_textura(especie)
    if ResourceLoader.exists(arquivo):
        m.albedo_texture = load(arquivo)
        m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
        m.albedo_color = COR_NOITE
    else:
        m.albedo_color = Color(0.05, 0.11, 0.16, 0.72)
    _materiais[especie] = m
    return m

func _sortear_especie() -> String:
    var total := 0
    for nome in ESPECIES:
        total += _chance(nome)
    var r := randi_range(1, total)
    for nome in ESPECIES:
        r -= _chance(nome)
        if r <= 0:
            return nome
    return "Sardinha"

## Chance de a espécie nascer agora: "so_noite" só no escuro; "so_dia" só no claro.
func _chance(nome: String) -> int:
    var d: Dictionary = ESPECIES[nome]
    if (d.get("so_noite", false) and not noite) or (d.get("so_dia", false) and noite):
        return 0
    if d.get("alto_mar", false):
        return int(d.chance) * 3 if _alto_mar else 0
    var peso: float = float(d.chance)
    if nome in ["Sardinha", "Tainha"]:
        peso *= 1.8 if _distancia_costeira < 180.0 else 0.65
    elif nome in ["Garoupa", "Olho-de-cão"]:
        peso *= 1.6 if _distancia_costeira < 150.0 else 0.4
    elif nome in ["Cavala", "Barracuda", "Xaréu"]:
        peso *= 1.5 if _distancia_costeira > 110.0 else 0.7
    if _zona_local == "recife":
        peso *= 3.0 if nome in ["Garoupa", "Xaréu", "Olho-de-cão"] else 0.65
    elif _zona_local == "banco":
        peso *= 2.6 if nome in ["Cavala", "Xaréu", "Tainha"] else 0.75
    return maxi(1, roundi(peso) * (int(d.get("vezes_noite", 1)) if noite else 1))

func criar(centro: Vector3, especie: String = "") -> Dictionary:
    if especie == "":
        especie = _sortear_especie()
    var dados: Dictionary = ESPECIES[especie]
    var n := int(dados.peixes)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = _malha
    mm.instance_count = n
    var inst := MultiMeshInstance3D.new()
    inst.multimesh = mm
    inst.material_override = _material_da_especie(especie).duplicate()
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    inst.extra_cull_margin = 30.0
    add_child(inst)
    var fases := PackedFloat32Array()
    for i in n:
        fases.append(randf())
    var estilo: Dictionary = NADO.get(especie, NADO["Tainha"])
    var raio_grupo: float = 2.4 + sqrt(float(n)) * float(dados.tam) * float(estilo["separa"]) * 1.7
    var angulo := randf_range(0.0, TAU)
    var direcao := Vector2.from_angle(angulo)
    var velocidades: Array = []
    var posicoes: Array = []
    for i in n:
        var ang: float = TAU * float(i) / maxf(1.0, float(n)) + randf_range(-0.32, 0.32)
        var separacao_inicial: float = sqrt(randf_range(0.1, 1.0)) * raio_grupo * 0.65
        var offset := Vector2.from_angle(ang) * separacao_inicial
        posicoes.append(Vector2(centro.x, centro.z) + offset)
        velocidades.append(direcao.rotated(randf_range(-0.23, 0.23)) * float(estilo["vel"]))
    var c := {"especie": especie, "centro": Vector3(centro.x, 0.0, centro.z), "raio": raio_grupo,
            "restantes": randi_range(int(dados.capturas[0]), int(dados.capturas[1])), "no": inst, "fases": fases,
            "rumo": angulo, "sentido": 1.0, "some": -1.0, "posicoes": posicoes, "velocidades": velocidades,
            "idade": 0.0, "vida_max": randf_range(150.0, 240.0), "fuga": 0.0, "rumo_alvo": angulo,
            "perigo_ultimo": 0.0, "profundidades": [], "tempo_migracao": randf_range(11.0, 29.0)}
    for i in n:
        c.profundidades.append(randf_range(0.04, 0.15))
    lista.append(c)
    _colorir(c)
    _nadar_cardume(c, 0.016)
    return c

func _colorir(c: Dictionary) -> void:
    if not is_instance_valid(c.no):
        return
    var mat := c.no.material_override as StandardMaterial3D
    if mat != null and mat.albedo_texture != null:
        mat.albedo_color = COR_NOITE if noite else COR_DIA

func _liberar(c: Dictionary) -> void:
    if is_instance_valid(c.no):
        c.no.queue_free()

func limpar() -> void:
    for c in lista:
        _liberar(c)
    lista.clear()
    _areas_descanso.clear()
    _relogio = 0.0

## Começa a partida com cardumes já no mar, um deles perto, para o jogador ver logo como é.
func semear() -> void:
    limpar()
    if _barco == null:
        return
    var frente: Vector3 = -_barco.global_transform.basis.z
    _alto_mar = false
    # O primeiro cardume nasce a boa distancia do barco, mas so onde ha fundo (o barco parte do cais, perto da ilha).
    var mundo := get_parent()
    var primeiro: Vector3 = _barco.global_position + frente.rotated(Vector3.UP, 0.5) * 55.0
    for dist in [55.0, 70.0, 90.0, 115.0, 145.0]:
        var achou := false
        for ang in [0.5, -0.5, 0.0, 1.0, -1.0, 1.6, -1.6]:
            var p: Vector3 = _barco.global_position + frente.rotated(Vector3.UP, float(ang)) * float(dist)
            if mundo == null or not mundo.has_method("altura_terra") or mundo.altura_terra(p) < -8.0:
                primeiro = p
                achou = true
                break
        if achou:
            break
    criar(primeiro)
    for i in 3:
        _nascer()

func _registrar_descanso(pos: Vector3) -> void:
    _areas_descanso.append({"p": Vector2(pos.x, pos.z), "restante": randf_range(45.0, 95.0)})
    if _areas_descanso.size() > 32:
        _areas_descanso.pop_front()

func _atualizar_descanso(delta: float) -> void:
    for reg in _areas_descanso.duplicate():
        reg.restante -= delta
        if float(reg.restante) <= 0.0:
            _areas_descanso.erase(reg)

## As tentativas percorrem locais distintos; nenhum peixe aparece em terra,
## encalhado ou imediatamente no mesmo trecho já esgotado.
func _nascer() -> void:
    if _barco == null:
        return
    var mundo := get_parent()
    for tentativa in 16:
        var ang: float = randf_range(0.0, TAU)
        var dist: float = randf_range(NASCE_MIN, NASCE_MAX)
        var p: Vector3 = _barco.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
        _alto_mar = true
        _distancia_costeira = 9999.0
        if mundo != null and mundo.has_method("altura_terra"):
            if mundo.altura_terra(p) > -7.0:
                continue
            _distancia_costeira = mundo.distancia_da_costa(p)
            _alto_mar = _distancia_costeira > ALTO_MAR
            _zona_local = mundo.zona_ecologica(p) if mundo.has_method("zona_ecologica") else "costeiro"
        var ocupado := false
        for c in lista:
            if c.centro.distance_to(p) < 47.0:
                ocupado = true
                break
        if ocupado:
            continue
        for reg in _areas_descanso:
            if Vector2(p.x, p.z).distance_to(reg.p) < 49.0:
                ocupado = true
                break
        if ocupado:
            continue
        criar(p)
        return

func _process(delta: float) -> void:
    if not simulando:
        return
    _tempo += delta
    _atualizar_descanso(delta)
    if _barco == null:
        return
    var pos_barco := _barco.global_position
    for c in lista.duplicate():
        if float(c.some) >= 0.0:                             # dispersando: some aos poucos
            c.some -= delta
            var fundo_alfa: float = clampf(c.some / 1.5, 0.0, 1.0)
            c.no.material_override.albedo_color.a = (COR_NOITE.a if noite else COR_DIA.a) * fundo_alfa
            c.raio += delta * 2.5
            if c.some <= 0.0:
                _registrar_descanso(c.centro)
                _liberar(c)
                lista.erase(c)
                continue
        elif Vector2(c.centro.x - pos_barco.x, c.centro.z - pos_barco.z).length() > SOME:
            _registrar_descanso(c.centro)
            _liberar(c)
            lista.erase(c)
            continue
        elif c.some < 0.0:
            c.idade += delta
            if float(c.idade) >= float(c.vida_max) and c.centro.distance_to(pos_barco) > 30.0:
                c.some = 1.5
                continue
        var dt: float = minf(delta, 0.050)
        c.fuga = maxf(0.0, float(c.fuga) - dt)
        c.tempo_migracao = float(c.tempo_migracao) - dt
        var direcao_grupo: Vector2 = Vector2.from_angle(float(c.rumo))
        var frente_peixes: Vector3 = c.centro + Vector3(direcao_grupo.x, 0.0, direcao_grupo.y) * 20.0
        var mundo: Node = get_parent()
        var candidato: float = float(c.rumo_alvo)
        if mundo != null and mundo.has_method("altura_terra") and mundo.altura_terra(frente_peixes) > -6.0:
            # O grupo escolhe uma curva que o afasta do litoral antes de encalhar.
            var curva_segura: float = 1.0 if sin(_tempo * 0.35 + float(c.fases[0]) * TAU) >= 0.0 else -1.0
            candidato = float(c.rumo) + curva_segura * 0.90
        elif float(c.tempo_migracao) <= 0.0:
            # Pequenas migracoes de cardumes, sem curvas sincronizadas ou guinadas instantaneas.
            c.tempo_migracao = randf_range(13.0, 32.0)
            candidato = float(c.rumo) + randf_range(-0.55, 0.55)
        else:
            candidato += sin(_tempo * 0.13 + float(c.fases[0]) * TAU) * 0.012 * dt
        var fuga: Vector2 = Vector2(c.centro.x - pos_barco.x, c.centro.z - pos_barco.z)
        var raio_fuga: float = DIST_FUGA_BARCO + clampf(absf(float(_barco.velocidade)) * 3.0, 0.0, 14.0)
        if fuga.length() < raio_fuga:
            c.fuga = RECUPERACAO_FUGA
            if fuga.length() > 0.01:
                candidato = lerp_angle(candidato, fuga.angle(), clampf(dt * 1.5, 0.0, 0.2))
        c.rumo_alvo = candidato
        c.rumo = lerp_angle(float(c.rumo), candidato, clampf(dt * 0.65, 0.0, 0.09))
        direcao_grupo = Vector2.from_angle(float(c.rumo))
        var velocidade_grupo: float = 0.48 + float(NADO[c.especie]["vel"]) * 0.18
        if float(c.fuga) > 0.0:
            velocidade_grupo *= 1.35
        c.centro += Vector3(direcao_grupo.x, 0.0, direcao_grupo.y) * velocidade_grupo * dt
        _nadar_cardume(c, dt)
    _relogio += delta
    if _relogio >= INTERVALO:
        _relogio = 0.0
        if _vivos() < MAXIMO:
            _nascer()

func _vivos() -> int:
    var n := 0
    for c in lista:
        if c.some < 0.0:
            n += 1
    return n

## Boids leve: alinhamento + coesão + separação. Não há órbitas sincronizadas.
## Usamos cópia das posições, para a ordem de atualização não puxar os últimos peixes.
func _nadar_cardume(c: Dictionary, delta: float) -> void:
    var dados: Dictionary = ESPECIES[c.especie]
    var estilo: Dictionary = NADO[c.especie]
    var mm: MultiMesh = c.no.multimesh
    var anteriores: Array = c.posicoes
    var antigas_vel: Array = c.velocidades
    var novas_pos: Array = []
    var novas_vel: Array = []
    var raio_sep: float = 0.70 + float(dados.tam) * float(estilo["separa"])
    var raio_vizinhos: float = raio_sep * 3.6
    var speed: float = float(estilo["vel"]) * (1.75 if float(c.fuga) > 0.0 else 1.0)
    var central: Vector2 = Vector2(c.centro.x, c.centro.z)
    var orientacao: Vector2 = Vector2.from_angle(float(c.rumo))
    var barco_pos: Vector2 = Vector2(_barco.global_position.x, _barco.global_position.z) if _barco != null else Vector2.INF
    for i in mm.instance_count:
        var pos: Vector2 = anteriores[i]
        var vel: Vector2 = antigas_vel[i]
        var alinhamento: Vector2 = Vector2.ZERO
        var separacao: Vector2 = Vector2.ZERO
        var coesao: Vector2 = Vector2.ZERO
        var vizinhos: int = 0
        for j in mm.instance_count:
            if i == j:
                continue
            var entre: Vector2 = anteriores[j] - pos
            var dist_individuos: float = entre.length()
            if dist_individuos < 0.005 or dist_individuos > raio_vizinhos:
                continue
            vizinhos += 1
            alinhamento += antigas_vel[j].normalized()
            coesao += anteriores[j]
            if dist_individuos < raio_sep:
                separacao -= entre.normalized() * pow(raio_sep / maxf(dist_individuos, 0.05), 1.15)
        var alvo: Vector2 = orientacao * 1.25
        if vizinhos > 0:
            alvo += (alinhamento / float(vizinhos)).normalized() * 0.95
            alvo += ((coesao / float(vizinhos)) - pos).normalized() * 0.40 * float(estilo["grupo"])
        if separacao.length() > 0.01:
            alvo += separacao.normalized() * minf(separacao.length(), 3.0) * 1.5
        var ao_centro: Vector2 = central - pos
        if ao_centro.length() > float(c.raio) * 0.55:
            alvo += ao_centro.normalized() * 0.95 * float(estilo["grupo"])
        var distancia_barco: float = pos.distance_to(barco_pos)
        if distancia_barco < DIST_FUGA_BARCO and distancia_barco > 0.01:
            alvo += (pos - barco_pos).normalized() * (2.5 + (1.0 - distancia_barco / DIST_FUGA_BARCO) * 2.4)
        # O peixe preserva o rumo mas tem pequenas correcoes, em ritmos distintos.
        var fase: float = float(c.fases[i])
        var oscilacao: float = sin(_tempo * (0.64 + float(estilo["muda"])) + fase * TAU) * 0.055
        alvo = alvo.rotated(oscilacao)
        var velocidade_desejada: Vector2 = alvo.normalized() * speed * (0.91 + fase * 0.18)
        var nova_v: Vector2 = vel.lerp(velocidade_desejada, clampf(delta * (1.6 if float(c.fuga) <= 0.0 else 3.0), 0.0, 0.26))
        var nova_p: Vector2 = pos + nova_v * delta
        novas_pos.append(nova_p)
        novas_vel.append(nova_v)
        var pos_mundo := Vector3(nova_p.x, 0.0, nova_p.y)
        # As texturas sao vistas de cima; manter proximo da superficie para permanecerem legiveis.
        var afundamento: float = float(c.profundidades[i])
        var profundidade_visual: float = afundamento + 0.04 * sin(_tempo * (1.05 + fase * 0.3) + fase * TAU)
        pos_mundo.y = (_oceano.altura_em(pos_mundo) if _oceano != null else 0.0) - profundidade_visual + 0.16
        var yaw: float = atan2(-nova_v.x, -nova_v.y)
        var tamanho: float = float(dados.tam) * VISUAL * (0.86 + 0.16 * fase)
        var base_peixe := Basis(Vector3.UP, yaw).scaled(Vector3(tamanho, 1.0, tamanho))
        mm.set_instance_transform(i, Transform3D(base_peixe, pos_mundo))
    c.posicoes = novas_pos
    c.velocidades = novas_vel

## Baleias assustam cardumes pequenos ao respirar na superficie, sem pescar por eles.
func assustar_por_baleia(pos: Vector3) -> void:
    var p: Vector2 = Vector2(pos.x, pos.z)
    for c in lista:
        if float(c.some) >= 0.0:
            continue
        var origem: Vector2 = Vector2(c.centro.x, c.centro.z)
        var afastar: Vector2 = origem - p
        if afastar.length() < 72.0 and afastar.length() > 0.1:
            c.fuga = maxf(float(c.fuga), RECUPERACAO_FUGA * 1.25)
            c.rumo_alvo = afastar.angle()

## O cardume vivo mais próximo do ponto, ou {}.
func mais_proximo(pos: Vector3) -> Dictionary:
    var melhor := {}
    var menor := INF
    for c in lista:
        if c.some >= 0.0:
            continue
        var d := Vector2(c.centro.x - pos.x, c.centro.z - pos.z).length()
        if d < menor:
            menor = d
            melhor = c
    return melhor

func distancia(c: Dictionary, pos: Vector3) -> float:
    return Vector2(c.centro.x - pos.x, c.centro.z - pos.z).length()

## O cardume ao alcance da linha, ou {}.
func ao_alcance(pos: Vector3) -> Dictionary:
    var c := mais_proximo(pos)
    if c.is_empty() or distancia(c, pos) > ALCANCE + float(c.raio):
        return {}
    return c

func vivo(c: Dictionary) -> bool:
    return not c.is_empty() and c in lista and c.some < 0.0

## Sorteia o peso (kg) de um peixe da espécie: os pequenos são mais comuns.
func sortear_peso(especie: String) -> float:
    var faixa: Array = ESPECIES[especie].peso
    return snappedf(lerpf(faixa[0], faixa[1], pow(randf(), 1.7)), 0.1)

func espera_de(especie: String) -> float:
    var faixa: Array = ESPECIES[especie].espera
    return randf_range(faixa[0], faixa[1])

## Um peixe saiu do cardume; no último, o cardume se dispersa. Devolve quantos restam.
func consumir(c: Dictionary) -> int:
    if not vivo(c):
        return 0
    c.restantes -= 1
    if c.restantes <= 0:
        c.some = 1.5
        c.fuga = RECUPERACAO_FUGA
        cardume_dispersou.emit(c.especie)
    return maxi(0, c.restantes)

## Posição de cada cardume em relação ao barco, para o radar: x = metros a boreste, y = metros à frente.
func relativos(barco: Node3D) -> Array:
    var frente: Vector3 = -barco.global_transform.basis.z
    var direita: Vector3 = barco.global_transform.basis.x
    var saida: Array = []
    for c in lista:
        if c.some >= 0.0:
            continue
        var d: Vector3 = c.centro - barco.global_position
        saida.append({"pos": Vector2(d.dot(direita), d.dot(frente)), "mundo": Vector2(c.centro.x, c.centro.z), "especie": c.especie, "grande": float(ESPECIES[c.especie].tam) > 0.8})
    return saida


## Quanto o cais paga por um peixe (R$).
func valor(especie: String, peso: float) -> int:
    return roundi(float(ESPECIES.get(especie, {}).get("preco", 5)) * peso)
