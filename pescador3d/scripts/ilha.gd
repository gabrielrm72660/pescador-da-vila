extends Node3D
## A ilha: terreno gerado por código (praia, mato, rocha, um pico de pedra e dois rochedos no mar),
## coqueiros, moitas, pedras, uma vila com capela, farol e um cais de madeira. Responde onde há terra (para o barco não atravessar) e onde é o cais.

## Tudo abaixo pode ser mudado antes de a ilha entrar na cena (scripts/jogo.gd cria as ilhas).
var centro := Vector3(150.0, 0.0, -290.0)      # onde a ilha fica no mundo
var raio := 105.0                              # tamanho aproximado (m)
var semente := 3476                            # muda o desenho da costa e do relevo
var pico := [-26.0, 14.0, 58.0, 13.0]          # o morro de pedra: x, z (locais), altura, largura
var morro := [38.0, -30.0, 20.0, 24.0]         # um morro menor, de mato
var com_vila := true                           # falso: só um posto de pesca ao pé do cais
var coqueiros := 85
var bonus_venda := 1.0                         # quanto o cais paga pelo peixe (1.3 = 30% a mais)
var preco_diesel := 4                          # R$ por litro
var tem_loja := true                           # vende melhorias do barco?
const LADO := 300.0                            # lado da malha do terreno (m)
const DIVISOES := 150
const CALADO := 0.9                            # o barco encalha onde a água tem menos que isso (m)
const COMPRIMENTO_CAIS := 38.0
const LARGURA_CAIS := 3.4
const ALCANCE_CAIS := 15.0                     # m da ponta do cais até onde dá para atracar
const FAIXA_COSTA := Vector2(-12.0, 4.0)       # alturas (m) que viram 0 e 1 no mapa enviado ao mar
## Dois rochedos altos no mar, ao lado da ilha (posição local x, z; altura; largura)
var rochedos := [[96.0, 78.0, 26.0, 7.5], [113.0, 60.0, 19.0, 6.5]]

var nome := "Vila do Porto"
var cais_inicio: Vector3                       # onde o cais sai da praia
var cais_ponta: Vector3                        # a ponta no mar
var _ruido := FastNoiseLite.new()

func _ready() -> void:
    _ruido.seed = semente
    _ruido.frequency = 0.012
    _ruido.fractal_octaves = 4
    position = centro
    _criar_terreno()
    _criar_cais()
    _criar_vila()
    _criar_coqueiros()
    _criar_pedras_e_moitas()

## Altura do terreno (m) num ponto do MUNDO. Negativa = fundo do mar.
func altura_em(pos: Vector3) -> float:
    return _altura_local(pos.x - centro.x, pos.z - centro.z)

func _altura_local(x: float, z: float) -> float:
    var d := Vector2(x, z).length()
    if d > LADO * 0.5:
        return -30.0
    var ang := atan2(z, x)
    # a costa não é um círculo: enseadas e pontas
    var contorno := 1.0 + 0.20 * _ruido.get_noise_2d(cos(ang) * 90.0, sin(ang) * 90.0) + 0.10 * sin(ang * 3.0 + 0.8)
    var r := d / (raio * contorno)
    var h := 15.0 * pow(maxf(0.0, 1.0 - r * r), 1.3) - 1.6 * smoothstep(0.75, 1.5, r) * 6.0 + 0.9
    h += _ruido.get_noise_2d(x * 2.2, z * 2.2) * 3.2 * clampf(1.0 - r, 0.0, 1.0)
    # o pico de pedra (o marco da ilha) e um morro menor
    var quebra := 1.0 + 0.30 * _ruido.get_noise_2d(x * 4.5 + 40.0, z * 4.5) + 0.12 * _ruido.get_noise_2d(x * 13.0, z * 13.0 + 90.0)   # paredões e ressaltos
    h += float(pico[2]) * exp(-Vector2((x - float(pico[0])) * 1.15, z - float(pico[1])).length_squared() / (2.0 * float(pico[3]) * float(pico[3]))) * quebra
    h += float(morro[2]) * exp(-Vector2(x - float(morro[0]), z - float(morro[1])).length_squared() / (2.0 * float(morro[3]) * float(morro[3])))
    if r > 1.0:
        h = minf(h, lerpf(h, -9.0, smoothstep(1.0, 1.6, r)))
    for rc in rochedos:                                              # os rochedos saem do mar, fora da praia
        var dr := Vector2((x - float(rc[0])) * 1.35, z - float(rc[1])).length()      # alongados, não redondos
        dr *= 1.0 + 0.35 * _ruido.get_noise_2d(x * 5.0 + 11.0, z * 5.0)
        var corpo := exp(-pow(dr / float(rc[3]), 2.2))
        h = maxf(h, -9.0 + (float(rc[2]) + 9.0) * corpo * (1.0 + 0.22 * _ruido.get_noise_2d(x * 14.0, z * 14.0 + 30.0)))
    return h

func _criar_terreno() -> void:
    var passo := LADO / DIVISOES
    var alturas := PackedFloat32Array()
    alturas.resize((DIVISOES + 1) * (DIVISOES + 1))
    for j in DIVISOES + 1:
        for i in DIVISOES + 1:
            alturas[j * (DIVISOES + 1) + i] = _altura_local(-LADO / 2.0 + i * passo, -LADO / 2.0 + j * passo)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in DIVISOES + 1:
        for i in DIVISOES + 1:
            var h := alturas[j * (DIVISOES + 1) + i]
            var he := alturas[j * (DIVISOES + 1) + maxi(i - 1, 0)]
            var hd := alturas[j * (DIVISOES + 1) + mini(i + 1, DIVISOES)]
            var hc := alturas[maxi(j - 1, 0) * (DIVISOES + 1) + i]
            var hb := alturas[mini(j + 1, DIVISOES) * (DIVISOES + 1) + i]
            var normal := Vector3(he - hd, 2.0 * passo, hc - hb).normalized()
            st.set_normal(normal)
            st.add_vertex(Vector3(-LADO / 2.0 + i * passo, h, -LADO / 2.0 + j * passo))
    for j in DIVISOES:
        for i in DIVISOES:
            var a := j * (DIVISOES + 1) + i
            var b := a + 1
            var c := a + DIVISOES + 1
            var d := c + 1
            if maxf(maxf(alturas[a], alturas[b]), maxf(alturas[c], alturas[d])) < -6.0:
                continue                                     # fundo que nunca aparece
            st.add_index(a); st.add_index(b); st.add_index(c)
            st.add_index(b); st.add_index(d); st.add_index(c)
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/terreno_pintado.gdshader")
    for par in [["tex_areia", "ilha/areia"], ["tex_grama", "ilha/grama"], ["tex_rocha", "ilha/rocha"], ["tex_manchas", "mar/pigmento"]]:
        var arquivo: String = "res://assets/texturas/%s.png" % par[1]
        if ResourceLoader.exists(arquivo):
            mat.set_shader_parameter(par[0], load(arquivo))
        else:
            push_warning("Textura da ilha não encontrada: " + arquivo)
    var malha := MeshInstance3D.new()
    malha.name = "Terreno"
    malha.mesh = st.commit()
    malha.material_override = mat
    add_child(malha)

func _material(cor: Color, textura: String = "", repeticao: float = 0.5, relevo: String = "") -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = cor
    m.roughness = 1.0                                  # fosco, como pintura: a forma vem da cor, não do brilho
    m.metallic_specular = 0.08
    if textura != "" and ResourceLoader.exists(textura):
        m.albedo_texture = load(textura)
        m.uv1_triplanar = true
        m.uv1_scale = Vector3(repeticao, repeticao, repeticao)
        if relevo != "" and ResourceLoader.exists(relevo):
            m.normal_enabled = true
            m.normal_texture = load(relevo)
    return m

func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, giro_y: float = 0.0) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = tam
    m.mesh = b
    m.material_override = mat
    m.position = pos
    m.rotation.y = giro_y
    pai.add_child(m)
    return m

func _cilindro(pai: Node3D, raio_base: float, raio_topo: float, altura: float, pos: Vector3, mat: Material) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var c := CylinderMesh.new()
    c.bottom_radius = raio_base
    c.top_radius = raio_topo
    c.height = altura
    c.radial_segments = 10
    m.mesh = c
    m.material_override = mat
    m.position = pos + Vector3(0, altura / 2.0, 0)
    pai.add_child(m)
    return m

## O cais sai da praia na direção de onde o barco começa (a origem do mundo).
func _criar_cais() -> void:
    var dir := Vector2(-centro.x, -centro.z).normalized()            # da ilha para o ponto de partida
    var d := 20.0
    while d < LADO * 0.5 and _altura_local(dir.x * d, dir.y * d) > 0.6:
        d += 0.5                                                     # anda até a beira da água
    var inicio := Vector2(dir.x, dir.y) * (d - 5.0)
    var ponta := inicio + dir * COMPRIMENTO_CAIS
    cais_inicio = centro + Vector3(inicio.x, 0.0, inicio.y)
    cais_ponta = centro + Vector3(ponta.x, 0.0, ponta.y)
    var cais := Node3D.new()
    cais.name = "Cais"
    add_child(cais)
    var madeira := _material(Color(1.0, 0.95, 0.88), "res://assets/texturas/ilha/madeira.png")
    var escura := _material(Color(0.55, 0.45, 0.38), "res://assets/texturas/ilha/madeira.png")
    var giro := -atan2(dir.y, dir.x)
    var meio := (inicio + ponta) / 2.0
    _caixa(cais, Vector3(COMPRIMENTO_CAIS, 0.22, LARGURA_CAIS), Vector3(meio.x, 1.15, meio.y), madeira, giro)
    var lado := Vector2(-dir.y, dir.x)
    var n := int(COMPRIMENTO_CAIS / 4.5)
    for i in n + 1:
        var p := inicio + dir * (COMPRIMENTO_CAIS * i / n)
        for s in [-1.0, 1.0]:
            var q: Vector2 = p + lado * s * (LARGURA_CAIS / 2.0 - 0.15)
            _cilindro(cais, 0.17, 0.15, 4.6, Vector3(q.x, -2.6, q.y), escura)
    # na ponta: bomba de diesel, caixas e um poste com lanterna
    var cabeca := ponta - dir * 2.2
    _caixa(cais, Vector3(0.7, 1.3, 0.5), Vector3(cabeca.x + lado.x * 1.0, 1.9, cabeca.y + lado.y * 1.0), _material(Color(0.80, 0.22, 0.16)), giro)
    _caixa(cais, Vector3(0.9, 0.7, 0.9), Vector3(cabeca.x - lado.x * 1.0 - dir.x * 2.0, 1.6, cabeca.y - lado.y * 1.0 - dir.y * 2.0), _material(Color(0.86, 0.66, 0.2)), giro + 0.3)
    _cilindro(cais, 0.07, 0.06, 3.2, Vector3(ponta.x - dir.x * 0.4, 1.2, ponta.y - dir.y * 0.4), escura)
    var luz := _material(Color(1.0, 0.85, 0.5))
    luz.emission_enabled = true
    luz.emission = Color(1.0, 0.75, 0.35)
    luz.emission_energy_multiplier = 2.0
    _caixa(cais, Vector3(0.3, 0.36, 0.3), Vector3(ponta.x - dir.x * 0.4, 4.5, ponta.y - dir.y * 0.4), luz)
    _luz(cais, Vector3(ponta.x - dir.x * 0.4, 4.6, ponta.y - dir.y * 0.4), 3.0, 22.0)

## Uma casa: paredes caiadas (tingidas), rodapé, porta e janelas de madeira pintada e telhado de barro de
## duas águas. A frente (porta) fica em +X local; "giro" vira a casa para o mar.
func _casa(pai: Node3D, pos: Vector3, giro: float, tam: Vector3, cor: Color, cor_madeira: Color) -> Node3D:
    var casa := Node3D.new()
    casa.position = pos + Vector3(0, -0.4, 0)                        # um pouco enterrada: assenta em chão torto
    casa.rotation.y = giro
    pai.add_child(casa)
    var parede := _material(cor, "res://assets/texturas/ilha/reboco.png", 0.22, "res://assets/texturas/ilha/reboco_normal.png")
    _caixa(casa, tam, Vector3(0, tam.y / 2.0, 0), parede)
    _caixa(casa, Vector3(tam.x + 0.10, 0.75, tam.z + 0.10), Vector3(0, 0.375, 0), _material(cor.darkened(0.42)))
    var madeira := _material(cor_madeira)
    if _vidro == null:
        _vidro = _material(Color(0.10, 0.14, 0.18))
        _vidro.roughness = 0.25
        _vidro.emission_enabled = true
        _vidro.emission = Color(1.0, 0.72, 0.36)
        _vidro.emission_energy_multiplier = 0.0
    var vidro := _vidro
    var fx := tam.x / 2.0
    _caixa(casa, Vector3(0.10, 2.0, 1.0), Vector3(fx, 1.4, -tam.z * 0.18), madeira)                 # porta
    _caixa(casa, Vector3(0.16, 0.12, 1.3), Vector3(fx, 2.46, -tam.z * 0.18), madeira.duplicate())
    for jan in [Vector3(fx, 1.95, tam.z * 0.24), Vector3(-fx, 1.95, 0.0)]:                         # janelas na frente e atrás
        _caixa(casa, Vector3(0.08, 0.95, 0.95), jan, vidro)
        for s in [-1.0, 1.0]:
            _caixa(casa, Vector3(0.14, 1.0, 0.36), jan + Vector3(0, 0, s * 0.62), madeira)       # folhas abertas
    for s in [-1.0, 1.0]:                                                                          # e uma em cada lado
        var jl := Vector3(tam.x * 0.12, 1.95, s * tam.z / 2.0)
        _caixa(casa, Vector3(0.95, 0.95, 0.08), jl, vidro)
        _caixa(casa, Vector3(1.15, 0.12, 0.16), jl + Vector3(0, -0.54, 0), madeira)
    _telhado(casa, tam, 1.7, parede)
    return casa

## Telhado de duas águas com a cumeeira ao longo de Z, beiral sobrando, e os dois oitões de parede.
func _telhado(casa: Node3D, tam: Vector3, subida: float, parede: Material) -> void:
    var a := tam.x / 2.0 + 0.55
    var b := tam.z / 2.0 + 0.45
    var y0 := tam.y - 0.12
    var rampa := Vector2(a, subida).length()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for s in [1.0, -1.0]:
        var cantos := [Vector3(0, y0 + subida, -b), Vector3(0, y0 + subida, b), Vector3(s * a, y0, b), Vector3(s * a, y0, -b)]
        var uvs := [Vector2(-b, 0), Vector2(b, 0), Vector2(b, rampa), Vector2(-b, rampa)]
        for k in [0, 1, 2, 0, 2, 3]:
            st.set_normal(Vector3(s * subida, a, 0).normalized())
            st.set_tangent(Plane(0, 0, 1, 1))
            st.set_uv(uvs[k] / 3.6)
            st.add_vertex(cantos[k])
    var telhas := StandardMaterial3D.new()
    telhas.albedo_texture = load("res://assets/texturas/ilha/telhas.png")
    telhas.normal_enabled = true
    telhas.normal_texture = load("res://assets/texturas/ilha/telhas_normal.png")
    telhas.roughness = 1.0
    telhas.metallic_specular = 0.08
    telhas.normal_scale = 0.5
    telhas.cull_mode = BaseMaterial3D.CULL_DISABLED
    var m := MeshInstance3D.new()
    m.mesh = st.commit()
    m.material_override = telhas
    casa.add_child(m)
    var oitao := SurfaceTool.new()                                    # o triângulo de parede sob cada ponta
    oitao.begin(Mesh.PRIMITIVE_TRIANGLES)
    var meia := tam.x / 2.0
    var topo := subida * meia / a
    for s in [1.0, -1.0]:
        for v in [Vector3(-meia, tam.y, s * tam.z / 2.0), Vector3(meia, tam.y, s * tam.z / 2.0), Vector3(0, tam.y + topo, s * tam.z / 2.0)]:
            oitao.set_normal(Vector3(0, 0, s))
            oitao.add_vertex(v)
    var mo := MeshInstance3D.new()
    mo.mesh = oitao.commit()
    var mat_oitao: StandardMaterial3D = parede.duplicate()
    mat_oitao.cull_mode = BaseMaterial3D.CULL_DISABLED
    mo.material_override = mat_oitao
    casa.add_child(mo)

var _vidro: StandardMaterial3D        # um só para todas as janelas: acendem juntas à noite
var _luzes: Array = []                # luzes do farol e do cais
var _ocupado: Array = []          # (x, z, raio) do que já foi construído: árvores e pedras ficam fora

func _criar_vila() -> void:
    var vila := Node3D.new()
    vila.name = "Vila"
    add_child(vila)
    var dir := Vector2(-centro.x, -centro.z).normalized()
    var lado := Vector2(-dir.y, dir.x)
    var pe_do_cais := Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    _ocupado.append(Vector3(pe_do_cais.x, pe_do_cais.y, 9.0))
    var base := pe_do_cais - dir * 15.0
    var cores := [Color(0.97, 0.95, 0.88), Color(0.95, 0.80, 0.52), Color(0.66, 0.84, 0.90), Color(0.96, 0.90, 0.66),
            Color(0.93, 0.66, 0.58), Color(0.97, 0.95, 0.88), Color(0.74, 0.88, 0.72), Color(0.95, 0.80, 0.52)]
    var madeiras := [Color(0.16, 0.36, 0.50), Color(0.52, 0.20, 0.14), Color(0.18, 0.40, 0.28), Color(0.30, 0.22, 0.16)]
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    var virada := -atan2(dir.y, dir.x)                                # +X da casa olhando para o mar
    var n := 0
    for fila in 2:                                                    # duas fileiras de casas viradas para o cais
        for i in 5:
            var p := base + lado * ((i - 2) * 10.5 + fila * 5.0) - dir * (fila * 13.0 + rng.randf_range(0.0, 3.5))
            var h := _altura_local(p.x, p.y)
            if h < 1.6 or absf(_altura_local(p.x + 3.0, p.y) - _altura_local(p.x - 3.0, p.y)) > 2.6 \
                    or absf(_altura_local(p.x, p.y + 3.0) - _altura_local(p.x, p.y - 3.0)) > 2.6:
                continue                                              # na água ou em barranco: sem casa
            if not com_vila and not (fila == 0 and i == 1):
                continue                                              # ilha deserta: só o posto de pesca
            if i == 2 and fila == 0:
                continue                                              # o largo em frente ao cais fica livre
            var tam := Vector3(rng.randf_range(5.0, 6.2), rng.randf_range(3.0, 3.6), rng.randf_range(5.6, 7.4))
            _casa(vila, Vector3(p.x, h, p.y), virada + rng.randf_range(-0.16, 0.16), tam, cores[n % cores.size()], madeiras[rng.randi() % madeiras.size()])
            _ocupado.append(Vector3(p.x, p.y, 6.5))
            n += 1
    # a capela, no fim do largo: nave branca e uma torre com cruz
    var pc := base - dir * 30.0
    var hc := _altura_local(pc.x, pc.y)
    if hc > 1.6 and com_vila:
        var nave := _casa(vila, Vector3(pc.x, hc, pc.y), virada, Vector3(9.0, 4.6, 5.6), Color(0.98, 0.97, 0.93), Color(0.16, 0.36, 0.50))
        var branca := _material(Color(0.98, 0.97, 0.93), "res://assets/texturas/ilha/reboco.png", 0.22)
        _caixa(nave, Vector3(2.5, 9.0, 2.5), Vector3(4.6, 4.5, 3.3), branca)
        var ponta := MeshInstance3D.new()
        var piramide := CylinderMesh.new()
        piramide.top_radius = 0.0
        piramide.bottom_radius = 2.0
        piramide.height = 2.4
        piramide.radial_segments = 4
        ponta.mesh = piramide
        ponta.material_override = _material(Color(0.70, 0.32, 0.18))
        ponta.position = Vector3(4.6, 10.2, 3.3)
        ponta.rotation.y = PI / 4.0
        nave.add_child(ponta)
        var escuro := _material(Color(0.20, 0.15, 0.12))
        _caixa(nave, Vector3(0.14, 1.5, 0.14), Vector3(4.6, 12.1, 3.3), escuro)
        _caixa(nave, Vector3(0.14, 0.14, 0.8), Vector3(4.6, 12.4, 3.3), escuro)
        _caixa(nave, Vector3(0.10, 1.2, 0.8), Vector3(5.86, 6.6, 3.3), _material(Color(0.10, 0.14, 0.18)))   # sineira
        _ocupado.append(Vector3(pc.x, pc.y, 9.0))
    # farol numa ponta da ilha
    var melhor := Vector2.ZERO
    var mais_longe := -INF
    for k in 72:                                      # a ponta de terra mais afastada para um dos lados do cais
        var a := TAU * k / 72.0
        var p := Vector2(cos(a), sin(a)) * raio * 0.86
        if _altura_local(p.x, p.y) > 2.0 and p.dot(lado) > mais_longe:
            mais_longe = p.dot(lado)
            melhor = p
    var hf := _altura_local(melhor.x, melhor.y)
    _ocupado.append(Vector3(melhor.x, melhor.y, 5.0))
    var vermelho := _material(Color(0.74, 0.18, 0.14))
    _cilindro(vila, 2.3, 2.1, 1.2, Vector3(melhor.x, hf - 0.6, melhor.y), _material(Color(0.62, 0.60, 0.56), "res://assets/texturas/ilha/rocha.png", 0.3))
    _cilindro(vila, 1.7, 1.2, 11.0, Vector3(melhor.x, hf - 0.4, melhor.y), _material(Color(0.96, 0.95, 0.90), "res://assets/texturas/ilha/reboco.png", 0.25))
    _cilindro(vila, 1.62, 1.48, 2.0, Vector3(melhor.x, hf + 2.2, melhor.y), vermelho)                    # faixas vermelhas
    _cilindro(vila, 1.42, 1.30, 2.0, Vector3(melhor.x, hf + 6.4, melhor.y), vermelho)
    _cilindro(vila, 1.6, 1.6, 0.4, Vector3(melhor.x, hf + 10.6, melhor.y), _material(Color(0.20, 0.18, 0.17)))
    var lanterna := _material(Color(1.0, 0.9, 0.6))
    lanterna.emission_enabled = true
    lanterna.emission = Color(1.0, 0.8, 0.4)
    lanterna.emission_energy_multiplier = 2.5
    _cilindro(vila, 1.0, 1.0, 1.5, Vector3(melhor.x, hf + 11.0, melhor.y), lanterna)
    _cilindro(vila, 1.4, 0.1, 1.2, Vector3(melhor.x, hf + 12.5, melhor.y), vermelho)
    _luz(vila, Vector3(melhor.x, hf + 11.8, melhor.y), 6.0, 60.0)

func _livre(p: Vector2, folga: float = 0.0) -> bool:
    for o in _ocupado:
        if Vector2(o.x, o.y).distance_to(p) < o.z + folga:
            return false
    return true

## Um coqueiro inteiro numa malha só: tronco curvo com anéis e folhas compridas que caem nas pontas.
func _malha_coqueiro() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var altura := 6.0
    var aneis := 7
    var lados := 6
    var pontos: Array = []
    for j in aneis + 1:                                               # tronco: sobe fazendo uma curva
        var t := float(j) / aneis
        var centro := Vector3(1.5 * t * t, altura * t, 0.0)
        var raio := lerpf(0.26, 0.13, t) * (1.25 if j == 0 else 1.0)
        var cor := Color(0.50, 0.41, 0.31) if j % 2 == 0 else Color(0.38, 0.30, 0.23)
        for k in lados:
            var a := TAU * k / lados
            pontos.append([centro + Vector3(cos(a), 0.0, sin(a)) * raio, cor])
    for j in aneis:
        for k in lados:
            var a0 := j * lados + k
            var a1 := j * lados + (k + 1) % lados
            for idx in [a0, a0 + lados, a1, a1, a0 + lados, a1 + lados]:
                st.set_color(pontos[idx][1])
                st.add_vertex(pontos[idx][0])
    var topo := Vector3(1.5, altura - 0.05, 0.0)
    var rng := RandomNumberGenerator.new()
    rng.seed = 99
    var folhas := 11
    for f in folhas:                                                  # folhas: uma espinha e duas abas em V
        var ang := TAU * f / folhas + rng.randf_range(-0.2, 0.2)
        var dir := Vector3(cos(ang), 0.0, sin(ang))
        var lat := Vector3(-dir.z, 0.0, dir.x)
        var comp := rng.randf_range(2.9, 3.8)
        var sobe := rng.randf_range(0.15, 0.75)                       # umas mais em pé, outras caídas
        var verde := Color(0.20, 0.42, 0.18).lerp(Color(0.42, 0.56, 0.22), rng.randf())
        var seg := 6
        var espinha: Array = []
        var largura: Array = []
        for j in seg + 1:
            var u := float(j) / seg
            espinha.append(topo + dir * (comp * u) + Vector3.UP * comp * (sobe * u - (0.55 + sobe) * u * u))
            largura.append(0.62 * sin(PI * clampf(u * 0.88 + 0.10, 0.0, 1.0)))
        for j in seg:
            for s in [-1.0, 1.0]:
                var e0: Vector3 = espinha[j]
                var e1: Vector3 = espinha[j + 1]
                var b0: Vector3 = e0 + lat * s * float(largura[j]) - Vector3.UP * float(largura[j]) * 0.45
                var b1: Vector3 = e1 + lat * s * float(largura[j + 1]) - Vector3.UP * float(largura[j + 1]) * 0.45
                for par in [[e0, verde.darkened(0.25)], [e1, verde.darkened(0.25)], [b0, verde], [b0, verde], [e1, verde.darkened(0.25)], [b1, verde.lightened(0.12)]]:
                    st.set_color(par[1])
                    st.add_vertex(par[0])
    st.generate_normals()
    return st.commit()

func _criar_coqueiros() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 21
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = _malha_coqueiro()
    var lugares: Array = []
    for k in 1400:
        var p := Vector2(rng.randf_range(-raio, raio), rng.randf_range(-raio, raio))
        var h := _altura_local(p.x, p.y)
        if h > 1.5 and h < 12.0 and _livre(p, 1.5) and absf(_altura_local(p.x + 2.0, p.y) - h) < 1.6 and rng.randf() < (1.0 if h < 4.5 else 0.45):
            lugares.append(Vector3(p.x, h - 0.2, p.y))                # mais coqueiro perto da praia
        if lugares.size() >= coqueiros:
            break
    mm.instance_count = lugares.size()
    for i in lugares.size():
        var e := rng.randf_range(0.75, 1.3)
        var base := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(e, e * rng.randf_range(0.85, 1.2), e))
        mm.set_instance_transform(i, Transform3D(base, lugares[i]))
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.85
    var inst := MultiMeshInstance3D.new()
    inst.name = "Coqueiros"
    inst.multimesh = mm
    inst.material_override = mat
    add_child(inst)

## Pedras soltas na beira da água e nas encostas, e moitas no mato.
func _criar_pedras_e_moitas() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 33
    var pedra := SphereMesh.new()
    pedra.radius = 1.0
    pedra.height = 1.5
    pedra.radial_segments = 7
    pedra.rings = 4
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = pedra
    var lugares: Array = []
    for k in 4000:
        var p := Vector2(rng.randf_range(-LADO * 0.46, LADO * 0.46), rng.randf_range(-LADO * 0.46, LADO * 0.46))
        var h := _altura_local(p.x, p.y)
        var na_beira := h > -1.6 and h < 0.9
        var na_encosta := h > 6.0 and absf(_altura_local(p.x + 2.0, p.y) - h) + absf(_altura_local(p.x, p.y + 2.0) - h) > 2.4
        if (na_beira and rng.randf() < 0.5 or na_encosta and rng.randf() < 0.25) and _livre(p, 3.0) and _dist_cais(centro + Vector3(p.x, 0, p.y)) > 9.0:
            lugares.append(Vector3(p.x, h, p.y))
        if lugares.size() >= 110:
            break
    mm.instance_count = lugares.size()
    for i in lugares.size():
        var e := rng.randf_range(0.5, 1.9) * (1.5 if rng.randf() < 0.12 else 1.0)
        var base := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, TAU), rng.randf_range(-0.5, 0.5))).scaled(Vector3(e * rng.randf_range(0.8, 1.5), e * rng.randf_range(0.55, 1.0), e))
        mm.set_instance_transform(i, Transform3D(base, lugares[i] + Vector3(0, e * 0.1, 0)))
    var mat := _material(Color(0.95, 0.93, 0.90), "res://assets/texturas/ilha/rocha.png", 0.22, "res://assets/texturas/ilha/rocha_normal.png")
    mat.uv1_world_triplanar = true
    var inst := MultiMeshInstance3D.new()
    inst.name = "Pedras"
    inst.multimesh = mm
    inst.material_override = mat
    add_child(inst)

    var moita := SphereMesh.new()
    moita.radius = 1.0
    moita.height = 1.3
    moita.radial_segments = 6
    moita.rings = 3
    var mb := MultiMesh.new()
    mb.transform_format = MultiMesh.TRANSFORM_3D
    mb.use_colors = true
    mb.mesh = moita
    var pontos: Array = []
    for k in 3000:
        var p := Vector2(rng.randf_range(-raio, raio), rng.randf_range(-raio, raio))
        var h := _altura_local(p.x, p.y)
        if h > 2.6 and h < 26.0 and _livre(p, 1.0) and absf(_altura_local(p.x + 2.0, p.y) - h) < 1.5:
            pontos.append(Vector3(p.x, h, p.y))
        if pontos.size() >= 170:
            break
    mb.instance_count = pontos.size()
    for i in pontos.size():
        var e := rng.randf_range(0.7, 1.8)
        mb.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(e * rng.randf_range(1.0, 1.6), e * 0.75, e)), pontos[i] + Vector3(0, e * 0.15, 0)))
        mb.set_instance_color(i, Color(0.16, 0.34, 0.15).lerp(Color(0.38, 0.50, 0.20), rng.randf()))
    var verde := StandardMaterial3D.new()
    verde.vertex_color_use_as_albedo = true
    verde.roughness = 0.95
    var moitas := MultiMeshInstance3D.new()
    moitas.name = "Moitas"
    moitas.multimesh = mb
    moitas.material_override = verde
    add_child(moitas)

## À noite (0 a 1) as janelas, o farol e a lanterna do cais acendem.
func acender(noite: float) -> void:
    if _vidro != null:
        _vidro.emission_energy_multiplier = 2.2 * noite
    for luz in _luzes:
        luz.light_energy = float(luz.get_meta("forca")) * noite

func _luz(pai: Node3D, pos: Vector3, forca: float, alcance: float) -> void:
    var luz := OmniLight3D.new()
    luz.light_color = Color(1.0, 0.80, 0.50)
    luz.omni_range = alcance
    luz.light_energy = 0.0
    luz.position = pos
    luz.set_meta("forca", forca)
    pai.add_child(luz)
    _luzes.append(luz)

## O desenho do fundo em volta da ilha, para o mar ficar raso e claro perto da praia e a espuma quebrar
## na areia (shaders/oceano_pintado.gdshader). "numero" é 1 ou 2: o mar aceita duas ilhas.
func ligar_ao_mar(oceano: MeshInstance3D, numero: int = 1) -> void:
    var mat := oceano.mesh.surface_get_material(0) as ShaderMaterial
    if mat == null:
        return
    var n := 192
    var img := Image.create(n, n, false, Image.FORMAT_L8)
    for j in n:
        for i in n:
            var h := _altura_local((float(i) + 0.5) / n * LADO - LADO / 2.0, (float(j) + 0.5) / n * LADO - LADO / 2.0)
            var v := clampf(inverse_lerp(FAIXA_COSTA.x, FAIXA_COSTA.y, h), 0.0, 1.0)
            img.set_pixel(i, j, Color(v, v, v))
    var sufixo := "" if numero == 1 else "2"
    mat.set_shader_parameter("tex_costa" + sufixo, ImageTexture.create_from_image(img))
    mat.set_shader_parameter("costa_centro" + sufixo, Vector2(centro.x, centro.z))
    mat.set_shader_parameter("costa_lado" + sufixo, LADO)
    mat.set_shader_parameter("costa_faixa", FAIXA_COSTA)

## O barco não pode estar aqui? (terra, água rasa demais ou o cais)
func bloqueado(pos: Vector3) -> bool:
    if altura_em(pos) > -CALADO:
        return true
    return _dist_cais(pos) < LARGURA_CAIS / 2.0 + 1.3

## Distância (m) do ponto até o segmento do cais.
func _dist_cais(pos: Vector3) -> float:
    var a := Vector2(cais_inicio.x, cais_inicio.z)
    var b := Vector2(cais_ponta.x, cais_ponta.z)
    var p := Vector2(pos.x, pos.z)
    var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
    return p.distance_to(a + (b - a) * t)

func distancia_do_cais(pos: Vector3) -> float:
    return Vector2(pos.x - cais_ponta.x, pos.z - cais_ponta.z).length()

func pode_atracar(pos: Vector3) -> bool:
    return distancia_do_cais(pos) <= ALCANCE_CAIS
