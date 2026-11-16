extends Node3D
## Cardumes no mar: sombras de peixes nadando em roda logo abaixo da superfície.
## Mantém alguns cardumes em volta do barco; a pesca só funciona perto de um deles, e a espécie
## pescada é a do cardume. O radar da interface mostra onde eles estão.

signal cardume_dispersou(especie: String)

## peso em kg (mín, máx), quantos peixes aparecem, tamanho da sombra (m), chance de nascer,
## quantas capturas o cardume aguenta, quanto demora puxar sem acertar nada (s), o preço no cais (R$ por kg)
## e a dificuldade do anel de pesca: velocidade do ponteiro (voltas/s), nº de faixas verdes, largura delas
## (graus) e quantos acertos trazem o peixe
const ESPECIES := {
    "Sardinha": {"preco": 6, "peso": [0.1, 0.4], "peixes": 18, "tam": 0.34, "chance": 30, "capturas": [4, 6], "espera": [2.5, 4.5], "ponteiro": 0.42, "faixas": 3, "largura": 46, "acertos": 2, "so_dia": true},
    "Tainha": {"preco": 9, "peso": [0.6, 2.6], "peixes": 11, "tam": 0.55, "chance": 26, "capturas": [3, 5], "espera": [3.0, 6.0], "ponteiro": 0.50, "faixas": 3, "largura": 40, "acertos": 3},
    "Xaréu": {"preco": 12, "peso": [1.5, 6.0], "peixes": 8, "tam": 0.75, "chance": 20, "capturas": [3, 4], "espera": [3.5, 6.5], "ponteiro": 0.58, "faixas": 3, "largura": 34, "acertos": 3},
    "Cavala": {"preco": 15, "peso": [2.0, 9.0], "peixes": 6, "tam": 0.95, "chance": 15, "capturas": [2, 4], "espera": [4.0, 7.0], "ponteiro": 0.68, "faixas": 2, "largura": 32, "acertos": 4},
    "Olho-de-cão": {"preco": 22, "peso": [0.4, 1.6], "peixes": 9, "tam": 0.5, "chance": 34, "capturas": [3, 5], "espera": [3.0, 6.0], "ponteiro": 0.62, "faixas": 3, "largura": 32, "acertos": 3, "so_noite": true},
    "Garoupa": {"preco": 24, "peso": [3.0, 14.0], "peixes": 3, "tam": 1.25, "chance": 9, "capturas": [2, 3], "espera": [5.0, 8.0], "ponteiro": 0.78, "faixas": 2, "largura": 27, "acertos": 5, "vezes_noite": 2},
}
const MAXIMO := 5
const NASCE_MIN := 70.0        # m do barco
const NASCE_MAX := 170.0
const SOME := 290.0            # m: além disso o cardume é esquecido
const ALCANCE := 17.0          # m do centro do cardume até onde a linha alcança
const VISUAL := 2.2            # as sombras são desenhadas maiores que o peixe, para se verem do barco
const INTERVALO := 2.0         # s entre nascimentos

var lista: Array = []
var noite: bool = false        # quem avisa é scripts/jogo.gd; algumas espécies só aparecem no escuro
var _barco: Node3D
var _oceano: Node
var _malha: ArrayMesh
var _material: StandardMaterial3D
var _relogio: float = 0.0
var _tempo: float = 0.0

func _ready() -> void:
    _barco = get_node_or_null("../Barco")
    _oceano = get_node_or_null("../Oceano")
    _malha = _criar_malha_peixe()
    _material = StandardMaterial3D.new()
    _material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material.albedo_color = Color(0.01, 0.045, 0.07, 0.72)
    _material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _material.vertex_color_use_as_albedo = false

## Silhueta de peixe vista de cima, deitada no plano da água, com a cabeça em -Z e 1 m de comprimento.
func _criar_malha_peixe() -> ArrayMesh:
    var contorno := PackedVector2Array([Vector2(0, -0.5), Vector2(0.11, -0.3), Vector2(0.14, -0.08), Vector2(0.09, 0.18),
            Vector2(0.03, 0.32), Vector2(0.13, 0.5), Vector2(0, 0.43), Vector2(-0.13, 0.5), Vector2(-0.03, 0.32),
            Vector2(-0.09, 0.18), Vector2(-0.14, -0.08), Vector2(-0.11, -0.3)])
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for tri in Geometry2D.triangulate_polygon(contorno):
        st.set_normal(Vector3.UP)
        st.add_vertex(Vector3(contorno[tri].x, 0.0, contorno[tri].y))
    return st.commit()

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
    return int(d.chance) * (int(d.get("vezes_noite", 1)) if noite else 1)

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
    inst.material_override = _material.duplicate()
    inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    inst.extra_cull_margin = 30.0
    add_child(inst)
    var fases := PackedFloat32Array()
    for i in n:
        fases.append(randf())
    var c := {"especie": especie, "centro": Vector3(centro.x, 0.0, centro.z), "raio": 2.2 + 0.55 * sqrt(n) * float(dados.tam) * VISUAL,
            "restantes": randi_range(int(dados.capturas[0]), int(dados.capturas[1])), "no": inst, "fases": fases,
            "rumo": randf_range(0.0, TAU), "sentido": 1.0 if randf() < 0.5 else -1.0, "some": -1.0}
    lista.append(c)
    return c

func limpar() -> void:
    for c in lista:
        if is_instance_valid(c.no):
            c.no.queue_free()
    lista.clear()
    _relogio = 0.0

## Começa a partida com cardumes já no mar, um deles perto, para o jogador ver logo como é.
func semear() -> void:
    limpar()
    if _barco == null:
        return
    var frente: Vector3 = -_barco.global_transform.basis.z
    criar(_barco.global_position + frente.rotated(Vector3.UP, 0.5) * 55.0)
    for i in 3:
        _nascer()

func _nascer() -> void:
    var ang := randf_range(0.0, TAU)
    var dist := randf_range(NASCE_MIN, NASCE_MAX)
    var p := _barco.global_position + Vector3(cos(ang), 0.0, sin(ang)) * dist
    var ilha := get_node_or_null("../Ilha")
    if ilha != null and ilha.altura_em(p) > -5.0:     # não nasce em terra nem na beira da praia
        return
    for c in lista:                                   # não nasce em cima de outro
        if c.centro.distance_to(p) < 45.0:
            return
    criar(p)

func _process(delta: float) -> void:
    _tempo += delta
    if _barco == null:
        return
    var pos_barco := _barco.global_position
    for c in lista.duplicate():
        if c.some >= 0.0:                             # dispersando: some aos poucos
            c.some -= delta
            c.no.material_override.albedo_color.a = 0.72 * clampf(c.some / 1.5, 0.0, 1.0)
            c.raio += delta * 2.5
            if c.some <= 0.0:
                c.no.queue_free()
                lista.erase(c)
                continue
        elif Vector2(c.centro.x - pos_barco.x, c.centro.z - pos_barco.z).length() > SOME:
            c.no.queue_free()
            lista.erase(c)
            continue
        c.rumo += sin(_tempo * 0.21 + c.fases[0] * 9.0) * 0.12 * delta      # o cardume vagueia devagar
        c.centro += Vector3(cos(c.rumo), 0.0, sin(c.rumo)) * 0.7 * delta
        _posicionar(c)
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

func _posicionar(c: Dictionary) -> void:
    var dados: Dictionary = ESPECIES[c.especie]
    var tam: float = dados.tam
    var mm: MultiMesh = c.no.multimesh
    for i in mm.instance_count:
        var f: float = c.fases[i]
        var anel: float = c.raio * (0.35 + 0.65 * fposmod(f * 7.13, 1.0))
        var giro: float = (0.55 + 0.5 * fposmod(f * 3.7, 1.0)) / maxf(anel, 0.8) * 1.6
        var ang: float = f * TAU + _tempo * giro * c.sentido
        var p: Vector3 = c.centro + Vector3(cos(ang), 0.0, sin(ang)) * anel
        p.y = (_oceano.altura_em(p) if _oceano != null else 0.0) + 0.13
        var rumo_peixe: float = -ang - PI / 2.0 * c.sentido + sin(_tempo * 5.0 + f * 20.0) * 0.18    # nada na tangente, abanando
        var escala: float = tam * VISUAL * (0.8 + 0.4 * fposmod(f * 11.9, 1.0))
        mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rumo_peixe + PI / 2.0 * (1.0 - c.sentido)).scaled(Vector3(escala, 1.0, escala)), p))

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
        saida.append({"pos": Vector2(d.dot(direita), d.dot(frente)), "especie": c.especie, "grande": float(ESPECIES[c.especie].tam) > 0.8})
    return saida


## Quanto o cais paga por um peixe (R$).
func valor(especie: String, peso: float) -> int:
    return roundi(float(ESPECIES.get(especie, {}).get("preco", 5)) * peso)
