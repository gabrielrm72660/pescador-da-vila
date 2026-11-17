extends RefCounted
## Malhas procedurais de pinheiro, árvore nativa, pedra e moita em níveis de detalhe.
##   nível 1 = detalhado (Alta), nível 2 = ultra. O nível 0 (leve, Baixa e Média) continua sendo o de ilha.gd.
## Tudo em triângulos separados (sombreamento facetado, o estilo pintado do jogo) com cor por vértice:
## o material do grupo usa a cor do vértice junto da textura de folhagem/rocha em triplanar.

static func criar(chave: String, nivel: int) -> ArrayMesh:
    match chave:
        "pinheiro": return pinheiro(nivel)
        "arvore": return arvore(nivel)
        "pedra": return pedra(nivel)
        "moita": return moita(nivel)
    return null

# ---------------------------------------------------------------------------------------------------------------
# apoio
# ---------------------------------------------------------------------------------------------------------------

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
    st.set_color(ca)
    st.add_vertex(a)
    st.set_color(cb)
    st.add_vertex(b)
    st.set_color(cc)
    st.add_vertex(c)

## Icosfera subdividida: devolve {"v": PackedVector3Array (raio 1), "f": Array de [i, j, k]}.
static func _icosfera(subdivisoes: int) -> Dictionary:
    var t: float = (1.0 + sqrt(5.0)) * 0.5
    var v := PackedVector3Array([
        Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
        Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
        Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
    for i in v.size():
        v[i] = v[i].normalized()
    var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
        [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
    for s in subdivisoes:
        var cache: Dictionary = {}
        var novos: Array = []
        for tri in f:
            var m: Array = []
            for par in [[tri[0], tri[1]], [tri[1], tri[2]], [tri[2], tri[0]]]:
                var chave: int = mini(par[0], par[1]) * 100000 + maxi(par[0], par[1])
                if not cache.has(chave):
                    v.append(((v[par[0]] + v[par[1]]) * 0.5).normalized())
                    cache[chave] = v.size() - 1
                m.append(cache[chave])
            novos.append([tri[0], m[0], m[2]])
            novos.append([tri[1], m[1], m[0]])
            novos.append([tri[2], m[2], m[1]])
            novos.append([m[0], m[1], m[2]])
        f = novos
    return {"v": v, "f": f}

static func _ruido(semente: int, frequencia: float) -> FastNoiseLite:
    var n := FastNoiseLite.new()
    n.noise_type = FastNoiseLite.TYPE_SIMPLEX
    n.seed = semente
    n.frequency = frequencia
    return n

## Lóbulo de copa: icosfera deformada (esticada em "ext"), com sombra por baixo e luz por cima.
static func _lobulo(st: SurfaceTool, centro: Vector3, ext: Vector3, base: Color, subdivisoes: int, ruido: FastNoiseLite, aspereza: float) -> void:
    var ico: Dictionary = _icosfera(subdivisoes)
    var v: PackedVector3Array = ico["v"]
    var p := PackedVector3Array()
    var c: Array = []
    for i in v.size():
        var d: Vector3 = v[i]
        var q: float = 1.0 + aspereza * ruido.get_noise_3d(d.x * 2.2 + centro.x, d.y * 2.2 + centro.y, d.z * 2.2 + centro.z)
        p.append(centro + Vector3(d.x * ext.x, d.y * ext.y, d.z * ext.z) * q)
        var luz: float = clampf(0.5 + 0.5 * d.y, 0.0, 1.0)
        var sol: Color = base.lerp(Color(0.78, 0.86, 0.34), 0.20 * smoothstep(0.35, 1.0, d.y))      # pontas douradas no alto
        c.append(base.darkened(0.42).lerp(sol, pow(luz, 0.8)))
    for tri in ico["f"]:
        _tri(st, p[tri[0]], p[tri[2]], p[tri[1]], c[tri[0]], c[tri[2]], c[tri[1]])

## Tronco que afina de baixo para cima, com raiz alargada e curva suave. "curva" desloca o topo em X.
static func _tronco(st: SurfaceTool, base: Vector3, altura: float, raio_base: float, raio_topo: float, curva: Vector2, lados: int, aneis: int, cor: Color) -> void:
    var pts: Array = []
    for j in aneis + 1:
        var t: float = float(j) / float(aneis)
        var cc: Vector3 = base + Vector3(curva.x * t * t, altura * t, curva.y * t * t)
        var rr: float = lerpf(raio_base, raio_topo, t) * (1.0 + 0.55 * pow(1.0 - t, 6.0))        # raiz alargada
        var ring: Array = []
        for k in lados:
            var a: float = TAU * float(k) / float(lados)
            ring.append(cc + Vector3(cos(a), 0.0, sin(a)) * rr)
        pts.append(ring)
    for j in aneis:
        var claro: float = float(j) / float(aneis)
        var c0: Color = cor.lightened(0.10 * claro) if j % 2 == 0 else cor.darkened(0.10)
        for k in lados:
            var k1: int = (k + 1) % lados
            _tri(st, pts[j][k], pts[j + 1][k], pts[j][k1], c0, c0, c0)
            _tri(st, pts[j][k1], pts[j + 1][k], pts[j + 1][k1], c0, c0, c0)

# ---------------------------------------------------------------------------------------------------------------
# pinheiro
# ---------------------------------------------------------------------------------------------------------------

## Copa em camadas de saia com a borda em dentes irregulares e caída, cada camada com um cone interno (dá volume),
## tronco com raiz alargada. Nível 1: 7 camadas de 10 dentes. Nível 2: 9 camadas de 14 dentes.
static func pinheiro(nivel: int) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var camadas: int = 7 if nivel <= 1 else 9
    var dentes: int = 10 if nivel <= 1 else 14
    var ruido := _ruido(7, 0.9)
    _tronco(st, Vector3(0, -0.3, 0), 6.4, 0.34, 0.14, Vector2(0.10, 0.04), 8, 5, Color(0.30, 0.21, 0.14))
    for i in camadas:
        var t: float = float(i) / float(camadas - 1)
        var y0: float = lerpf(1.5, 9.3, t)
        var raio_c: float = lerpf(3.0, 0.62, pow(t, 0.92))
        var alt: float = lerpf(3.6, 2.5, t)
        var ponta := Vector3(0.0, y0 + alt, 0.0)
        var sombra := Color(0.05, 0.16, 0.11).lerp(Color(0.08, 0.22, 0.15), t)
        var luz := Color(0.14, 0.33, 0.19).lerp(Color(0.20, 0.41, 0.23), t)
        var externos: Array = []
        var internos: Array = []
        for k in dentes:
            var a: float = TAU * float(k) / float(dentes) + 0.31 * float(i)
            var ruim: float = 1.0 + 0.20 * ruido.get_noise_3d(cos(a) * 2.0, float(i) * 1.7, sin(a) * 2.0)
            var bico: float = 1.0 if k % 2 == 0 else 0.72                       # dentes longos e curtos, alternados
            var r: float = raio_c * ruim * bico
            var queda: float = 0.0 if k % 2 == 0 else 0.34                         # os curtos caem mais
            externos.append(Vector3(cos(a) * r, y0 - queda - 0.35 * (1.0 - t), sin(a) * r))
            internos.append(Vector3(cos(a) * raio_c * 0.42, y0 + alt * 0.34, sin(a) * raio_c * 0.42))
        for k in dentes:
            var k1: int = (k + 1) % dentes
            var tom: float = 0.5 + 0.5 * ruido.get_noise_3d(float(k) * 0.7, float(i) * 2.3, 3.0)
            var cb: Color = sombra.lerp(luz, 0.15 + 0.2 * tom)
            var cm: Color = sombra.lerp(luz, 0.55)
            var ct: Color = luz.lerp(Color(0.30, 0.50, 0.26), 0.35 * t)
            # saia: da borda para o anel interno
            _tri(st, externos[k], externos[k1], internos[k], cb, cb, cm)
            _tri(st, internos[k], externos[k1], internos[k1], cm, cb, cm)
            # cone interno até a ponta
            _tri(st, internos[k], internos[k1], ponta, cm, cm, ct)
    st.generate_normals()
    return st.commit()

# ---------------------------------------------------------------------------------------------------------------
# árvore nativa
# ---------------------------------------------------------------------------------------------------------------

## Tronco bifurcado e copa de vários lóbulos amassados (cada um uma icosfera deformada).
## Nível 1: 7 lóbulos. Nível 2: 9 lóbulos, os maiores com mais subdivisão.
static func arvore(nivel: int) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var casca := Color(0.31, 0.24, 0.17)
    _tronco(st, Vector3(0, -0.2, 0), 3.6, 0.34, 0.17, Vector2(0.35, 0.0), 8, 4, casca)
    _tronco(st, Vector3(0.30, 3.1, 0.0), 2.0, 0.15, 0.08, Vector2(1.3, 0.5), 6, 3, casca)
    _tronco(st, Vector3(0.30, 3.2, 0.0), 1.9, 0.14, 0.07, Vector2(-1.6, -0.3), 6, 3, casca)
    var ruido := _ruido(31, 0.8)
    var verdes := [Color(0.27, 0.46, 0.26), Color(0.34, 0.52, 0.28), Color(0.23, 0.40, 0.25), Color(0.31, 0.50, 0.24)]
    var lobulos: Array = [
        [Vector3(0.1, 5.1, 0.0), Vector3(2.0, 1.55, 1.9), 2],
        [Vector3(1.6, 4.5, 0.6), Vector3(1.55, 1.2, 1.45), 1],
        [Vector3(-1.5, 4.7, -0.4), Vector3(1.5, 1.2, 1.4), 1],
        [Vector3(0.5, 4.3, -1.5), Vector3(1.35, 1.05, 1.3), 1],
        [Vector3(-0.3, 4.3, 1.5), Vector3(1.35, 1.0, 1.3), 1],
        [Vector3(1.1, 6.0, -0.5), Vector3(1.25, 1.0, 1.2), 1],
        [Vector3(-1.0, 6.0, 0.6), Vector3(1.2, 0.95, 1.15), 1],
    ]
    if nivel >= 2:
        lobulos.append([Vector3(2.4, 5.0, -0.9), Vector3(1.0, 0.85, 1.0), 1])
        lobulos.append([Vector3(-2.3, 5.2, 0.5), Vector3(1.0, 0.85, 1.0), 1])
    for i in lobulos.size():
        var l: Array = lobulos[i]
        var sub: int = 1 if nivel <= 1 else int(l[2])
        _lobulo(st, l[0], l[1], verdes[i % verdes.size()], sub, ruido, 0.16)
    st.generate_normals()
    return st.commit()

# ---------------------------------------------------------------------------------------------------------------
# pedra
# ---------------------------------------------------------------------------------------------------------------

## Pedra facetada: icosfera achatada e amassada, base reta, musgo e luz no topo e sombra embaixo.
## Raio 1 e altura ~1,3 (mesmo porte da esfera antiga). Nível 1: 80 faces. Nível 2: 320 faces.
static func pedra(nivel: int) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var ico: Dictionary = _icosfera(1 if nivel <= 1 else 2)
    var v: PackedVector3Array = ico["v"]
    var grosso := _ruido(5, 0.9)
    var fino := _ruido(9, 2.6)
    var p := PackedVector3Array()
    var c: Array = []
    for i in v.size():
        var d: Vector3 = v[i]
        var q: float = 1.0 + 0.30 * grosso.get_noise_3d(d.x * 1.6, d.y * 1.6, d.z * 1.6) + (0.07 * fino.get_noise_3d(d.x, d.y, d.z) if nivel >= 2 else 0.0)
        var pos := Vector3(d.x * 1.12, d.y * 0.72, d.z) * q
        if pos.y < -0.18:
            pos.y = -0.18 + (pos.y + 0.18) * 0.12                            # base achatada: a pedra "senta" no chão
        p.append(pos)
        var cima: float = clampf(d.y, 0.0, 1.0)
        var musgo: float = smoothstep(0.55, 0.95, d.y + 0.25 * fino.get_noise_3d(d.x * 3.0, d.y * 3.0, d.z * 3.0))
        var cor := Color(0.98, 0.95, 0.90).lerp(Color(1.0, 1.0, 0.97), 0.5 * cima)
        cor = cor.lerp(Color(0.60, 0.74, 0.40), 0.50 * musgo)
        cor = cor.darkened(0.22 * clampf(-d.y, 0.0, 1.0))
        c.append(cor)
    for tri in ico["f"]:
        _tri(st, p[tri[0]], p[tri[2]], p[tri[1]], c[tri[0]], c[tri[2]], c[tri[1]])
    st.generate_normals()
    return st.commit()

# ---------------------------------------------------------------------------------------------------------------
# moita
# ---------------------------------------------------------------------------------------------------------------

## Moita volumosa: três lóbulos amassados juntos, escura por dentro e clara por cima. A cor da instância tinge tudo.
## Raio 1 e altura ~1,3. Nível 1: 3 lóbulos de 80 faces. Nível 2: 4 lóbulos (o principal com 320 faces, os outros com 80).
static func moita(nivel: int) -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var ruido := _ruido(77, 1.1)
    var base := Color(0.92, 0.97, 0.88)
    var lobulos: Array = [
        [Vector3(0.0, 0.40, 0.0), Vector3(0.85, 0.62, 0.85)],
        [Vector3(0.50, 0.28, 0.25), Vector3(0.58, 0.44, 0.58)],
        [Vector3(-0.42, 0.30, -0.22), Vector3(0.55, 0.42, 0.55)],
    ]
    if nivel >= 2:
        lobulos.append([Vector3(0.05, 0.30, -0.55), Vector3(0.5, 0.38, 0.5)])
    for i in lobulos.size():
        var l: Array = lobulos[i]
        _lobulo(st, l[0], l[1], base.darkened(0.04 * float(i)), 2 if (nivel >= 2 and i == 0) else 1, ruido, 0.20)     # só o lóbulo principal é refinado no Ultra
    st.generate_normals()
    return st.commit()
