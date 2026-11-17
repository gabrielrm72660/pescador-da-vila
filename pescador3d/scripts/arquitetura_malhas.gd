extends RefCounted
## Arquitetura da vila em malhas detalhadas: casas, capela, armazém, mercado (e, mais abaixo, farol e cais).
## Tudo é gerado por código. Cada peça é um ArrayMesh de UMA superfície, para o Mesclador poder juntá-las.
## A cor vem dos vértices; o material (em ilha.gd) decide a textura e o tom geral.
##   parede  = reboco triplanar x cor da casa x tom do vértice (umidade no pé, manchas)
##   telhado = telha com UV e tangente (relevo da telha-canal feito na geometria)
##   acab    = acabamento de cor chapada (molduras, peitoris, cumeeira, chaminé, degraus)
##   mad     = madeira pintada (textura de madeira x cor do vértice)
##   vid     = vidro (um material só, que acende à noite)

const SINAL_FACE := 1.0            # +1: a face da frente é a de sentido horário (padrão do Godot). Se saírem do avesso, troque para -1.
const TERRACOTA := Color(0.74, 0.36, 0.22)
const PEDRA := Color(0.64, 0.62, 0.57)


class Malha:
    var v := PackedVector3Array()
    var n := PackedVector3Array()
    var c := PackedColorArray()
    var u := PackedVector2Array()
    var t := PackedFloat32Array()
    var ind := PackedInt32Array()
    var uv_ativo := false
    var tangente := Vector3(0, 0, 1)

    func ponto(p: Vector3, nor: Vector3, cor: Color, uv: Vector2 = Vector2.ZERO) -> int:
        v.append(p)
        n.append(nor)
        c.append(cor)
        u.append(uv)
        if uv_ativo:
            t.append(tangente.x)
            t.append(tangente.y)
            t.append(tangente.z)
            t.append(1.0)
        return v.size() - 1

    ## Triângulo ligado à normal dos vértices: confere o sentido da face pela normal média.
    func tri(a: int, b: int, d: int) -> void:
        var g: Vector3 = (v[b] - v[a]).cross(v[d] - v[a])
        var nm: Vector3 = n[a] + n[b] + n[d]
        if g.dot(nm) * SINAL_FACE > 0.0:
            ind.append(a)
            ind.append(d)
            ind.append(b)
        else:
            ind.append(a)
            ind.append(b)
            ind.append(d)

    func quad(a: int, b: int, cc: int, d: int) -> void:
        tri(a, b, d)
        tri(b, cc, d)

    ## Caixa com faces chapadas. "rot" gira em torno do centro; cor_topo (se tiver alfa) pinta só a face de cima.
    func caixa(centro: Vector3, tam: Vector3, cor: Color, rot: Basis = Basis.IDENTITY, cor_topo: Color = Color(0, 0, 0, 0)) -> void:
        var h: Vector3 = tam * 0.5
        var eixos: Array = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
        for i in 3:
            var j: int = (i + 1) % 3
            var k: int = (i + 2) % 3
            for s in [-1.0, 1.0]:
                var nl: Vector3 = (eixos[i] as Vector3) * float(s)
                var ej: Vector3 = (eixos[j] as Vector3) * h[j]
                var ek: Vector3 = (eixos[k] as Vector3) * h[k]
                var c0: Vector3 = nl * h[i]
                var nw: Vector3 = (rot * nl).normalized()
                var col: Color = cor
                if cor_topo.a > 0.0 and i == 1 and s > 0.0:
                    col = cor_topo
                var p0: int = ponto(centro + rot * (c0 - ej - ek), nw, col)
                var p1: int = ponto(centro + rot * (c0 + ej - ek), nw, col)
                var p2: int = ponto(centro + rot * (c0 + ej + ek), nw, col)
                var p3: int = ponto(centro + rot * (c0 - ej + ek), nw, col)
                quad(p0, p1, p2, p3)

    ## Tronco de cone de lados lisos (torre, poste, lanterna). "cor_fn(t, ang)" opcional; t vai de 0 (base) a 1 (topo).
    func tronco(base: Vector3, r0: float, r1: float, alt: float, lados: int, cor0: Color, cor1: Color, tampa: bool = true, cor_fn: Callable = Callable(), seg_y: int = 1, ang0: float = 0.0) -> void:
        var inclina: float = (r0 - r1) / maxf(alt, 0.001)
        var primeiro: int = v.size()
        for j in seg_y + 1:
            var tt: float = float(j) / float(seg_y)
            var rr: float = lerpf(r0, r1, tt)
            for i in lados + 1:
                var ang: float = ang0 + TAU * float(i) / float(lados)
                var dir := Vector3(cos(ang), 0.0, sin(ang))
                var cor: Color = cor0.lerp(cor1, tt)
                if cor_fn.is_valid():
                    cor = cor_fn.call(tt, ang)
                ponto(base + dir * rr + Vector3(0, alt * tt, 0), Vector3(dir.x, inclina, dir.z).normalized(), cor)
        for j in seg_y:
            for i in lados:
                var a: int = primeiro + j * (lados + 1) + i
                quad(a, a + 1, a + lados + 2, a + lados + 1)
        if tampa:
            var topo: Vector3 = base + Vector3(0, alt, 0)
            var centro: int = ponto(topo, Vector3.UP, cor1)
            var anel: int = v.size()
            for i in lados + 1:
                var ang: float = ang0 + TAU * float(i) / float(lados)
                ponto(topo + Vector3(cos(ang) * r1, 0, sin(ang) * r1), Vector3.UP, cor1)
            for i in lados:
                tri(centro, anel + i, anel + i + 1)

    ## Superfície paramétrica f(u, v) -> posição (u, v em 0..1). Normais por diferença finita (já com o relevo);
    ## "orient" é um ponto "de dentro": a normal sempre aponta para longe dele.
    func superficie(f: Callable, nu: int, nv: int, cor_fn: Callable, uv_fn: Callable, orient: Vector3, cor_fixa: Color = Color.WHITE, inverter: bool = false) -> void:
        var e: float = 0.25 / float(maxi(nu, nv))
        var primeiro: int = v.size()
        for j in nv + 1:
            for i in nu + 1:
                var uu: float = float(i) / float(nu)
                var vv: float = float(j) / float(nv)
                var p: Vector3 = f.call(uu, vv)
                var du: Vector3 = (f.call(minf(uu + e, 1.0), vv) as Vector3) - (f.call(maxf(uu - e, 0.0), vv) as Vector3)
                var dv: Vector3 = (f.call(uu, minf(vv + e, 1.0)) as Vector3) - (f.call(uu, maxf(vv - e, 0.0)) as Vector3)
                var nr: Vector3 = du.cross(dv)
                nr = nr.normalized() if nr.length_squared() > 1e-14 else Vector3.UP
                if nr.dot(p - orient) < 0.0:
                    nr = -nr
                if inverter:
                    nr = -nr
                var cor: Color = cor_fixa
                if cor_fn.is_valid():
                    cor = cor_fn.call(uu, vv, p)
                var uv: Vector2 = Vector2.ZERO
                if uv_fn.is_valid():
                    uv = uv_fn.call(uu, vv, p)
                ponto(p, nr, cor, uv)
        for j in nv:
            for i in nu:
                var a: int = primeiro + j * (nu + 1) + i
                quad(a, a + 1, a + nu + 2, a + nu + 1)

    ## Triângulo avulso de normal chapada (pontas de pirâmide, etc.), com UV.
    func tri_plano(p0: Vector3, p1: Vector3, p2: Vector3, cor: Color, uv0: Vector2 = Vector2.ZERO, uv1: Vector2 = Vector2.ZERO, uv2: Vector2 = Vector2.ZERO, fora: Vector3 = Vector3.ZERO) -> void:
        var nr: Vector3 = (p1 - p0).cross(p2 - p0).normalized()
        if fora != Vector3.ZERO and nr.dot(fora) < 0.0:
            nr = -nr
        var a: int = ponto(p0, nr, cor, uv0)
        var b: int = ponto(p1, nr, cor, uv1)
        var d: int = ponto(p2, nr, cor, uv2)
        tri(a, b, d)

    func malha() -> ArrayMesh:
        var m := ArrayMesh.new()
        if v.is_empty():
            return m
        var a: Array = []
        a.resize(Mesh.ARRAY_MAX)
        a[Mesh.ARRAY_VERTEX] = v
        a[Mesh.ARRAY_NORMAL] = n
        a[Mesh.ARRAY_COLOR] = c
        if uv_ativo:
            a[Mesh.ARRAY_TEX_UV] = u
            a[Mesh.ARRAY_TANGENT] = t
        a[Mesh.ARRAY_INDEX] = ind
        m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
        return m

    func triangulos() -> int:
        return ind.size() / 3


## ---- utilidades ---------------------------------------------------------------------------------------------------

## Ruído suave -1..1 (somas de senos): serve para "mão de pedreiro" nas paredes e manchas de tinta.
static func _onda(x: float, y: float, z: float, ph: float) -> float:
    return sin(x * 1.7 + ph) * cos(z * 2.3 + ph * 1.3) * 0.6 + sin((x + z) * 3.9 + y * 2.1 + ph * 0.7) * 0.4


static func _loc(c: Vector3, b: Basis, x: float, y: float, z: float) -> Vector3:
    return c + b * Vector3(x, y, z)


static func _cor_trim(cor: Color) -> Color:
    # moldura clara em parede colorida; creme-acinzentado quando a parede já é quase branca
    var lum: float = cor.r * 0.3 + cor.g * 0.59 + cor.b * 0.11
    if lum > 0.90:
        return Color(0.84, 0.80, 0.70)
    return Color(0.98, 0.96, 0.90)


## ---- janela, porta ------------------------------------------------------------------------------------------------

## Janela de madeira: vidro, caixilho em cruz, vergas, peitoril e (opcional) venezianas entreabertas.
## "c" é o centro na parede; "nrm" (±X ou ±Z) aponta para fora; "aberta" é o ângulo das folhas em relação à parede.
static func _janela(mad: Malha, acab: Malha, vid: Malha, c: Vector3, nrm: Vector3, larg: float, alt: float, cor_mad: Color, cor_trim: Color, veneziana: bool, aberta: float) -> void:
    var lado: Vector3 = Vector3.UP.cross(nrm)
    var b := Basis(lado, Vector3.UP, nrm)
    vid.caixa(c, Vector3(larg, alt, 0.05), Color.WHITE, b)
    mad.caixa(_loc(c, b, 0, 0, 0.03), Vector3(0.045, alt, 0.05), cor_mad, b)                       # caixilho em cruz
    mad.caixa(_loc(c, b, 0, 0.10, 0.03), Vector3(larg, 0.045, 0.05), cor_mad, b)
    for s in [-1.0, 1.0]:
        acab.caixa(_loc(c, b, float(s) * (larg * 0.5 + 0.045), 0, 0.06), Vector3(0.09, alt + 0.14, 0.12), cor_trim, b)
    acab.caixa(_loc(c, b, 0, alt * 0.5 + 0.10, 0.07), Vector3(larg + 0.34, 0.10, 0.15), cor_trim, b)     # verga
    acab.caixa(_loc(c, b, 0, alt * 0.5 + 0.185, 0.09), Vector3(larg + 0.46, 0.05, 0.20), cor_trim, b)    # pingadeira
    acab.caixa(_loc(c, b, 0, -(alt * 0.5 + 0.06), 0.11), Vector3(larg + 0.34, 0.07, 0.24), cor_trim, b)  # peitoril
    acab.caixa(_loc(c, b, 0, -(alt * 0.5 + 0.12), 0.07), Vector3(larg + 0.10, 0.06, 0.14), cor_trim.darkened(0.1), b)
    if not veneziana:
        return
    var w: float = larg * 0.5 + 0.02
    for s in [-1.0, 1.0]:
        var dir := Vector3(float(s) * cos(aberta), 0.0, sin(aberta))
        var charneira := Vector3(float(s) * (larg * 0.5 + 0.10), 0.0, 0.08)
        var bb: Basis = b * Basis(Vector3.UP, atan2(-dir.z, dir.x))
        var centro_folha: Vector3 = _loc(c, b, charneira.x, 0, charneira.z) + b * (dir * (w * 0.5))
        mad.caixa(centro_folha, Vector3(w, alt, 0.035), cor_mad, bb)
        for k in 6:
            var yy: float = -alt * 0.5 + (float(k) + 0.5) * alt / 6.0
            mad.caixa(centro_folha + bb * Vector3(0, yy, 0.025), Vector3(w - 0.05, 0.035, 0.05), cor_mad.darkened(0.14), bb)


## Porta de duas almofadas com batente, cornija, maçaneta e degrau de pedra. Base em y = "base".
static func _porta(mad: Malha, acab: Malha, c: Vector3, nrm: Vector3, larg: float, alt: float, cor_mad: Color, cor_trim: Color, degrau: bool = true) -> void:
    var lado: Vector3 = Vector3.UP.cross(nrm)
    var b := Basis(lado, Vector3.UP, nrm)
    var meio: Vector3 = c + Vector3(0, alt * 0.5, 0)
    mad.caixa(_loc(meio, b, 0, 0, 0.02), Vector3(larg, alt, 0.07), cor_mad, b)
    var painel: Color = cor_mad.darkened(0.16)
    for s in [-1.0, 1.0]:
        mad.caixa(_loc(meio, b, float(s) * larg * 0.24, alt * 0.22, 0.06), Vector3(larg * 0.36, alt * 0.46, 0.03), painel, b)
        mad.caixa(_loc(meio, b, float(s) * larg * 0.24, -alt * 0.26, 0.06), Vector3(larg * 0.36, alt * 0.30, 0.03), painel, b)
    acab.caixa(_loc(meio, b, larg * 0.36, -alt * 0.04, 0.09), Vector3(0.05, 0.05, 0.08), Color(0.20, 0.17, 0.12), b)      # maçaneta
    for s in [-1.0, 1.0]:
        acab.caixa(_loc(meio, b, float(s) * (larg * 0.5 + 0.06), 0.06, 0.07), Vector3(0.12, alt + 0.12, 0.14), cor_trim, b)
    acab.caixa(_loc(meio, b, 0, alt * 0.5 + 0.10, 0.08), Vector3(larg + 0.36, 0.14, 0.16), cor_trim, b)
    acab.caixa(_loc(meio, b, 0, alt * 0.5 + 0.21, 0.11), Vector3(larg + 0.50, 0.07, 0.24), cor_trim, b)
    if degrau:
        acab.caixa(_loc(c, b, 0, 0.0, 0.34), Vector3(larg + 0.7, 0.20, 0.56), Color(0.62, 0.60, 0.55), b)
        acab.caixa(_loc(c, b, 0, -0.08, 0.60), Vector3(larg + 0.9, 0.16, 0.30), Color(0.56, 0.54, 0.50), b)


## ---- paredes e telhado --------------------------------------------------------------------------------------------

static func _paredes(m: Malha, tam: Vector3, subida: float, a: float, y0: float, ph: float) -> void:
    var fx: float = tam.x * 0.5
    var hz: float = tam.z * 0.5
    var centro := Vector3(0, tam.y * 0.5, 0)
    var tom := func(u: float, v: float, p: Vector3) -> Color:
        var umid: float = 1.0 - smoothstep(0.0, 1.2, p.y)
        var sob: float = smoothstep(tam.y - 0.45, tam.y, p.y)
        var t: float = 0.97 + 0.045 * _onda(p.x * 1.4, p.y, p.z * 1.4, ph) - 0.17 * umid - 0.05 * sob
        return Color(t * (1.0 - 0.05 * umid), t, t * (1.0 - 0.11 * umid))
    for s in [-1.0, 1.0]:
        var sd: float = float(s)
        var f_x := func(u: float, v: float) -> Vector3:                              # lados longos (±X)
            var z: float = lerpf(-hz, hz, u)
            var y: float = v * tam.y
            return Vector3(sd * (fx + 0.016 * _onda(z, y, sd, ph)), y, z)
        m.superficie(f_x, 10, 6, tom, Callable(), centro)
        var f_z := func(u: float, v: float) -> Vector3:                              # empenas (±Z): retângulo + triângulo
            var x: float = lerpf(-fx, fx, u)
            var topo: float = y0 + subida * (1.0 - absf(x) / a) - 0.05
            var y: float = v * topo
            return Vector3(x, y, sd * (hz + 0.014 * _onda(x, y, sd * 3.0, ph)))
        m.superficie(f_z, 10, 8, tom, Callable(), centro)
    m.caixa(Vector3(0, 0.375, 0), Vector3(tam.x + 0.10, 0.75, tam.z + 0.10), Color(0.70, 0.72, 0.68))          # rodapé
    m.caixa(Vector3(0, 0.76, 0), Vector3(tam.x + 0.13, 0.06, tam.z + 0.13), Color(0.86, 0.86, 0.82))          # filete do rodapé


## Telhado de duas águas com telha-canal em relevo, beiral, cumeeira, tacaniça de madeira e caibros à vista.
static func _telhado(tel: Malha, acab: Malha, mad: Malha, tam: Vector3, subida: float, a: float, b: float, y0: float, ph: float, cor_mad: Color) -> void:
    var rampa: float = Vector2(a, subida).length()
    var passo: float = 0.115
    var nu: int = maxi(8, ceili(2.0 * b / passo))
    for s in [-1.0, 1.0]:
        var sd: float = float(s)
        var n0 := Vector3(sd * subida, a, 0).normalized()
        var f := func(u: float, v: float) -> Vector3:
            var z: float = lerpf(-b, b, u)
            var corrida: float = v * a
            var onda: float = 0.036 * sin(z * TAU / 0.23) + 0.045 * sin(u * PI) * sin(v * PI) * -1.0 + 0.012 * _onda(z, corrida, sd, ph)
            return Vector3(sd * corrida, y0 + subida * (1.0 - v), z) + n0 * onda
        var uv := func(u: float, v: float, p: Vector3) -> Vector2:
            return Vector2(lerpf(-b, b, u) / 3.6, v * rampa / 3.6)
        tel.superficie(f, nu, 6, Callable(), uv, Vector3(0, y0 - 6.0, 0))
    # tacaniça (madeira que emoldura a empena) e beiral (frontal)
    var ang: float = atan2(subida, a)
    for s in [-1.0, 1.0]:
        var sd: float = float(s)
        mad.caixa(Vector3(sd * a, y0 - 0.03, 0), Vector3(0.07, 0.17, 2.0 * b + 0.04), cor_mad.lightened(0.1))
        for zz in [-1.0, 1.0]:
            var rot: Basis = Basis(Vector3.BACK, atan2(-subida, sd * a))
            mad.caixa(Vector3(sd * a * 0.5, y0 + subida * 0.5 - 0.02, float(zz) * b), Vector3(rampa, 0.15, 0.05), cor_mad.lightened(0.1), rot)
    # caibros à vista sob o beiral
    var n_cb: int = maxi(4, int(tam.z / 0.7))
    for i in n_cb + 1:
        var zz: float = lerpf(-tam.z * 0.5 + 0.2, tam.z * 0.5 - 0.2, float(i) / float(n_cb))
        for s in [-1.0, 1.0]:
            mad.caixa(Vector3(float(s) * (tam.x * 0.5 + 0.26), y0 - 0.15, zz), Vector3(0.56, 0.08, 0.09), cor_mad.darkened(0.25))
    # cumeeira: duas telhas-capa inclinadas, em V invertido
    for s in [-1.0, 1.0]:
        var sd: float = float(s)
        acab.caixa(Vector3(sd * 0.13, y0 + subida + 0.015, 0), Vector3(0.30, 0.07, 2.0 * b + 0.06), TERRACOTA.darkened(0.04), Basis(Vector3.BACK, -sd * ang))
    acab.caixa(Vector3(0, y0 + subida + 0.05, 0), Vector3(0.10, 0.09, 2.0 * b + 0.10), TERRACOTA.darkened(0.12))


## ---- edifício -----------------------------------------------------------------------------------------------------

## tipo: "casa", "armazem", "mercado" ou "capela". Devolve {"parede", "telhado", "acab", "mad", "vidro"} (ArrayMesh) e "tris".
static func edificio(tipo: String, tam: Vector3, cor: Color, cor_madeira: Color, semente: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = absi(semente) * 7919 + 17
    var ph: float = rng.randf() * TAU
    var par := Malha.new()
    var tel := Malha.new()
    tel.uv_ativo = true
    var acab := Malha.new()
    var mad := Malha.new()
    var vid := Malha.new()
    var fx: float = tam.x * 0.5
    var hz: float = tam.z * 0.5
    var a: float = fx + 0.55
    var b: float = hz + 0.45
    var subida: float = a * 0.54
    var y0: float = tam.y - 0.12
    var trim: Color = _cor_trim(cor)
    var variante: int = absi(semente) % 4
    var tem_varanda: bool = tipo == "casa" and (variante == 1 or variante == 3)
    var tem_chamine: bool = tipo == "casa" and variante >= 2
    var porta_z: float = -tam.z * 0.18
    var base_y: float = 0.40                                  # a casa nasce 0,4 m abaixo do piso: o chão fica em y = 0,4

    _paredes(par, tam, subida, a, y0, ph)
    _telhado(tel, acab, mad, tam, subida, a, b, y0, ph, cor_madeira)

    if tipo == "capela":
        _capela(par, tel, acab, mad, vid, tam, cor_madeira, trim, ph)
    else:
        if tipo == "armazem":
            _portao_armazem(mad, acab, tam, cor_madeira, trim)
        else:
            _porta(mad, acab, Vector3(fx, base_y, porta_z), Vector3.RIGHT, 1.0, 2.0, cor_madeira, trim)
            # lampião ao lado da porta
            acab.caixa(Vector3(fx + 0.05, 2.35, porta_z + 0.95), Vector3(0.05, 0.18, 0.10), Color(0.18, 0.16, 0.14))
            vid.caixa(Vector3(fx + 0.16, 2.30, porta_z + 0.95), Vector3(0.16, 0.20, 0.16), Color.WHITE)
        # janelas: duas na frente/atrás, uma em cada empena
        var alt_j: float = 1.0 if tipo != "armazem" else 0.55
        var larg_j: float = 0.95 if tipo != "armazem" else 0.75
        var y_j: float = 1.95 if tipo != "armazem" else 2.7
        if tipo != "armazem":
            _janela(mad, acab, vid, Vector3(fx, y_j, tam.z * 0.24), Vector3.RIGHT, larg_j, alt_j, cor_madeira, trim, true, 0.42)
            _janela(mad, acab, vid, Vector3(-fx, y_j, 0.0), Vector3.LEFT, larg_j, alt_j, cor_madeira, trim, false, 0.0)
        for s in [-1.0, 1.0]:
            _janela(mad, acab, vid, Vector3(tam.x * 0.12, y_j, float(s) * hz), Vector3.BACK * float(s), larg_j, alt_j, cor_madeira, trim, tipo != "armazem", 0.55 if s > 0.0 else 0.30)
        if tipo == "mercado":
            _toldo_mercado(acab, mad, tam, cor_madeira, rng)

    if tem_varanda:
        _varanda(tel, acab, mad, tam, porta_z, cor_madeira, trim)
    if tem_chamine:
        var cx: float = -fx * 0.40
        var cz: float = -hz * 0.35
        var base_c: float = y0 + subida * (1.0 - absf(cx) / a) - 0.25
        var topo_c: float = y0 + subida + 0.78
        acab.caixa(Vector3(cx, (base_c + topo_c) * 0.5, cz), Vector3(0.60, topo_c - base_c, 0.60), Color(0.93, 0.89, 0.80))
        acab.caixa(Vector3(cx, topo_c + 0.05, cz), Vector3(0.80, 0.11, 0.80), Color(0.46, 0.43, 0.40))
        acab.caixa(Vector3(cx, topo_c + 0.115, cz), Vector3(0.40, 0.03, 0.40), Color(0.10, 0.09, 0.08))
    if tipo == "casa" and rng.randf() < 0.65:
        # jardineira de flores sob a janela da frente
        var zj: float = tam.z * 0.24
        mad.caixa(Vector3(fx + 0.16, 1.95 - 0.64, zj), Vector3(0.24, 0.17, 1.15), cor_madeira.darkened(0.1))
        for k in 6:
            var zk: float = zj - 0.48 + 0.19 * float(k)
            var verde: Color = Color(0.22 + 0.06 * rng.randf(), 0.46 + 0.10 * rng.randf(), 0.20)
            acab.caixa(Vector3(fx + 0.16, 1.95 - 0.50, zk), Vector3(0.20, 0.14, 0.16), verde)
            if k % 2 == 0:
                var flor: Color = [Color(0.88, 0.22, 0.20), Color(0.97, 0.80, 0.22), Color(0.92, 0.45, 0.62)][rng.randi() % 3]
                acab.caixa(Vector3(fx + 0.16, 1.95 - 0.41, zk), Vector3(0.10, 0.07, 0.10), flor)

    var tris: int = par.triangulos() + tel.triangulos() + acab.triangulos() + mad.triangulos() + vid.triangulos()
    return {"parede": par.malha(), "telhado": tel.malha(), "acab": acab.malha(), "mad": mad.malha(), "vidro": vid.malha(), "tris": tris}


## Varanda de frente: piso de tábuas, três pilares, guarda-corpo e um puxadinho de telha.
static func _varanda(tel: Malha, acab: Malha, mad: Malha, tam: Vector3, porta_z: float, cor_mad: Color, trim: Color) -> void:
    var fx: float = tam.x * 0.5
    var hzp: float = tam.z * 0.43
    var prof: float = 1.7
    mad.caixa(Vector3(fx + prof * 0.5 - 0.05, 0.50, 0), Vector3(prof, 0.18, hzp * 2.0 + 0.4), Color(0.78, 0.66, 0.50))
    for i in 9:                                                       # juntas das tábuas
        var xx: float = fx + 0.15 + float(i) * 0.19
        mad.caixa(Vector3(xx, 0.595, 0), Vector3(0.025, 0.012, hzp * 2.0 + 0.4), Color(0.30, 0.22, 0.15))
    var topo_p: float = tam.y - 0.52
    for zz in [-hzp, 0.0, hzp]:
        mad.caixa(Vector3(fx + prof - 0.16, (0.55 + topo_p) * 0.5, float(zz)), Vector3(0.13, topo_p - 0.55, 0.13), cor_mad.lightened(0.15))
    mad.caixa(Vector3(fx + prof - 0.16, topo_p + 0.06, 0), Vector3(0.12, 0.12, hzp * 2.0 + 0.3), cor_mad.lightened(0.15))   # viga
    # guarda-corpo: só onde não atrapalha a porta (de z = 0 a +hzp) e nas pontas
    for k in 4:
        var zz: float = lerpf(0.0, hzp, float(k) / 3.0)
        mad.caixa(Vector3(fx + prof - 0.16, 1.05, zz), Vector3(0.05, 0.85, 0.05), trim)
    mad.caixa(Vector3(fx + prof - 0.16, 1.50, hzp * 0.5), Vector3(0.07, 0.06, hzp), trim)
    for s in [-1.0, 1.0]:
        mad.caixa(Vector3(fx + prof * 0.5, 1.05, float(s) * hzp), Vector3(prof - 0.4, 0.05, 0.05), trim)
        mad.caixa(Vector3(fx + prof * 0.5, 1.50, float(s) * hzp), Vector3(prof - 0.3, 0.06, 0.07), trim)
    # puxadinho de telha, logo abaixo do beiral
    var y_p: float = tam.y - 0.10
    var f := func(u: float, v: float) -> Vector3:
        var z: float = lerpf(-hzp - 0.25, hzp + 0.25, u)
        return Vector3(fx + 0.40 + v * (prof - 0.05), y_p - v * 0.52 + 0.03 * sin(z * TAU / 0.23), z)
    var uv := func(u: float, v: float, p: Vector3) -> Vector2:
        return Vector2(p.z / 3.6, v * (prof + 0.2) / 3.6)
    tel.superficie(f, ceili((hzp * 2.0 + 0.5) / 0.115), 3, Callable(), uv, Vector3(fx, y_p - 6.0, 0))


## Portão de correr do armazém: duas folhas de tábua com mão-francesa em X e viga de içamento.
static func _portao_armazem(mad: Malha, acab: Malha, tam: Vector3, cor_mad: Color, trim: Color) -> void:
    var fx: float = tam.x * 0.5
    var larg: float = 2.9
    var alt: float = 2.7
    var b0 := Basis(Vector3.UP.cross(Vector3.RIGHT), Vector3.UP, Vector3.RIGHT)
    for s in [-1.0, 1.0]:
        var zc: float = float(s) * larg * 0.25
        mad.caixa(Vector3(fx + 0.04, 0.40 + alt * 0.5, zc), Vector3(0.07, alt, larg * 0.5 - 0.03), cor_mad)
        var ang: float = atan2(alt, larg * 0.5)
        for sg in [-1.0, 1.0]:
            mad.caixa(Vector3(fx + 0.09, 0.40 + alt * 0.5, zc), Vector3(0.05, Vector2(alt, larg * 0.5).length() - 0.2, 0.12), cor_mad.darkened(0.22), Basis(Vector3.RIGHT, float(sg) * ang))
    acab.caixa(Vector3(fx + 0.12, 0.40 + alt + 0.12, 0), Vector3(0.20, 0.24, larg + 0.5), trim)
    for s in [-1.0, 1.0]:
        acab.caixa(Vector3(fx + 0.12, 0.40 + alt * 0.5 + 0.06, float(s) * (larg * 0.5 + 0.16)), Vector3(0.22, alt + 0.12, 0.24), trim)
    # viga de içamento com roldana
    mad.caixa(Vector3(fx + 0.55, tam.y - 0.30, 0), Vector3(1.20, 0.20, 0.22), cor_mad.darkened(0.3))
    acab.caixa(Vector3(fx + 1.08, tam.y - 0.55, 0), Vector3(0.05, 0.50, 0.05), Color(0.18, 0.16, 0.14))
    acab.caixa(Vector3(fx + 1.08, tam.y - 0.82, 0), Vector3(0.20, 0.14, 0.12), Color(0.22, 0.20, 0.18))
    acab.caixa(Vector3(fx + 0.30, 0.52, larg * 0.5 + 0.9), Vector3(0.9, 0.26, 0.9), Color(0.62, 0.60, 0.55))


## Toldo listrado do mercado, com balcão e caixas de fruta.
static func _toldo_mercado(acab: Malha, mad: Malha, tam: Vector3, cor_mad: Color, rng: RandomNumberGenerator) -> void:
    var fx: float = tam.x * 0.5
    var larg: float = tam.z * 0.86
    var y_p: float = tam.y - 0.55
    var lis := func(u: float, v: float, p: Vector3) -> Color:
        return Color(0.97, 0.94, 0.86) if int(floor(u * 12.0)) % 2 == 0 else Color(0.22, 0.52, 0.55)
    var f := func(u: float, v: float) -> Vector3:
        return Vector3(fx + 0.1 + v * 2.2, y_p - v * 0.55, lerpf(-larg * 0.5, larg * 0.5, u))
    acab.superficie(f, 12, 2, lis, Callable(), Vector3(fx, y_p - 5.0, 0))
    var f2 := func(u: float, v: float) -> Vector3:
        return Vector3(fx + 0.1 + v * 2.2, y_p - v * 0.55 - 0.02, lerpf(-larg * 0.5, larg * 0.5, u))
    acab.superficie(f2, 12, 2, Callable(), Callable(), Vector3(fx, y_p + 5.0, 0), Color(0.80, 0.76, 0.68))
    acab.caixa(Vector3(fx + 2.3, y_p - 0.58, 0), Vector3(0.05, 0.22, larg), Color(0.97, 0.94, 0.86))                # babado
    for s in [-1.0, 1.0]:
        mad.caixa(Vector3(fx + 2.15, (0.40 + y_p - 0.5) * 0.5, float(s) * (larg * 0.5 - 0.1)), Vector3(0.10, y_p - 0.90, 0.10), cor_mad.lightened(0.1))
    mad.caixa(Vector3(fx + 1.35, 0.95, 1.7), Vector3(0.75, 0.80, 2.6), cor_mad.lightened(0.2))                         # balcão
    mad.caixa(Vector3(fx + 1.35, 1.38, 1.7), Vector3(0.85, 0.06, 2.75), Color(0.80, 0.70, 0.55))
    for k in 5:
        var cor_f: Color = [Color(0.90, 0.55, 0.15), Color(0.82, 0.18, 0.15), Color(0.45, 0.68, 0.25), Color(0.95, 0.80, 0.20)][rng.randi() % 4]
        acab.caixa(Vector3(fx + 1.30 + 0.10 * rng.randf(), 1.47, 0.55 + 0.52 * float(k)), Vector3(0.34, 0.14, 0.34), cor_f)


## Capela: torre sineira na fachada, óculo, porta dupla e cruz.
static func _capela(par: Malha, tel: Malha, acab: Malha, mad: Malha, vid: Malha, tam: Vector3, cor_mad: Color, trim: Color, ph: float) -> void:
    var fx: float = tam.x * 0.5
    var tx: float = fx + 0.5                       # centro da torre
    var lado: float = 2.4
    var alt_t: float = 7.6
    var branco: Color = Color(0.99, 0.98, 0.94)
    par.caixa(Vector3(tx, alt_t * 0.5, 0), Vector3(lado, alt_t, lado), branco)
    par.caixa(Vector3(tx, 0.40, 0), Vector3(lado + 0.14, 0.80, lado + 0.14), Color(0.68, 0.70, 0.66))
    acab.caixa(Vector3(tx, alt_t - 1.9, 0), Vector3(lado + 0.26, 0.16, lado + 0.26), trim)                    # cornija abaixo do sino
    acab.caixa(Vector3(tx, alt_t + 0.08, 0), Vector3(lado + 0.36, 0.20, lado + 0.36), trim)                   # cornija de cima
    # vãos do sino nas quatro faces
    for d in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
        var lat: Vector3 = Vector3.UP.cross(d)
        var bb := Basis(lat, Vector3.UP, d)
        var cc: Vector3 = Vector3(tx, alt_t - 1.0, 0) + d * (lado * 0.5)
        acab.caixa(cc + bb * Vector3(0, 0, 0.0), Vector3(0.80, 1.30, 0.06), Color(0.10, 0.09, 0.09), bb)
        acab.caixa(cc + bb * Vector3(0, 0.74, 0.03), Vector3(1.06, 0.14, 0.14), trim, bb)
        for s in [-1.0, 1.0]:
            acab.caixa(cc + bb * Vector3(float(s) * 0.50, 0, 0.03), Vector3(0.14, 1.40, 0.14), trim, bb)
        acab.caixa(cc + bb * Vector3(0, -0.72, 0.05), Vector3(1.06, 0.10, 0.20), trim, bb)
    mad.caixa(Vector3(tx, alt_t - 1.2, 0), Vector3(0.10, 0.10, 1.6), Color(0.28, 0.20, 0.14))                  # eixo do sino
    acab.tronco(Vector3(tx, alt_t - 1.75, 0), 0.34, 0.12, 0.60, 8, Color(0.72, 0.54, 0.22), Color(0.72, 0.54, 0.22))   # sino
    # pirâmide de telha e cruz
    var base_r: float = lado * 0.5 + 0.38
    var topo: Vector3 = Vector3(tx, alt_t + 1.95, 0)
    var cantos: Array = [Vector3(tx - base_r, alt_t + 0.18, -base_r), Vector3(tx + base_r, alt_t + 0.18, -base_r),
            Vector3(tx + base_r, alt_t + 0.18, base_r), Vector3(tx - base_r, alt_t + 0.18, base_r)]
    var centro := Vector3(tx, alt_t, 0)
    for i in 4:
        var p0: Vector3 = cantos[i]
        var p1: Vector3 = cantos[(i + 1) % 4]
        var fora_dir: Vector3 = ((p0 + p1) * 0.5 - centro).normalized() + Vector3(0, 0.6, 0)
        tel.tri_plano(p0, p1, topo, Color.WHITE, Vector2(0, 0), Vector2(base_r * 2.0 / 3.6, 0), Vector2(base_r / 3.6, 2.4 / 3.6), fora_dir)
    mad.caixa(Vector3(tx, alt_t + 2.65, 0), Vector3(0.12, 1.10, 0.12), Color(0.30, 0.22, 0.17))
    mad.caixa(Vector3(tx, alt_t + 2.90, 0), Vector3(0.12, 0.12, 0.72), Color(0.30, 0.22, 0.17))
    # porta dupla na torre e óculo
    var fr: float = tx + lado * 0.5
    _porta(mad, acab, Vector3(fr, 0.40, 0), Vector3.RIGHT, 1.35, 2.35, cor_mad, trim)
    var bo := Basis(Vector3.UP.cross(Vector3.RIGHT), Vector3.UP, Vector3.RIGHT)
    vid.caixa(Vector3(fr, 4.1, 0), Vector3(0.80, 0.80, 0.05), Color.WHITE, bo)
    for s in [-1.0, 1.0]:
        acab.caixa(Vector3(fr + 0.04, 4.1 + float(s) * 0.46, 0), Vector3(0.10, 0.10, 1.00), trim)
        acab.caixa(Vector3(fr + 0.04, 4.1, float(s) * 0.46), Vector3(0.10, 1.00, 0.10), trim)
    # janelas altas da nave (fachada da rua não, que é a torre: nas empenas)
    for s in [-1.0, 1.0]:
        _janela(mad, acab, vid, Vector3(-tam.x * 0.28, 2.4, 0.0) + Vector3(0, 0, float(s) * tam.z * 0.5), Vector3.BACK * float(s), 0.80, 1.55, cor_mad, trim, false, 0.0)
        _janela(mad, acab, vid, Vector3(tam.x * 0.28, 2.4, 0.0) + Vector3(0, 0, float(s) * tam.z * 0.5), Vector3.BACK * float(s), 0.80, 1.55, cor_mad, trim, false, 0.0)


## ---- farol --------------------------------------------------------------------------------------------------------

## Farol da serra, com y = 0 no cume. Devolve {"pedra", "torre", "acab", "vidro"}. A lanterna (vidro) fica em y = 13,15..14,75,
## onde o jogo põe a luz, o feixe e o brilho; o resto cresce em volta dela.
static func farol(ph: float = 1.7) -> Dictionary:
    var ped := Malha.new()
    var tor := Malha.new()
    var acab := Malha.new()
    var vid := Malha.new()
    var branco := Color(0.97, 0.96, 0.92)
    var vermelho := Color(0.78, 0.17, 0.13)
    var ferro := Color(0.16, 0.15, 0.15)
    # embasamento de pedra irregular e o anel que o liga à torre
    var f_ped := func(u: float, v: float) -> Vector3:
        var ang: float = u * TAU
        var y: float = -0.75 + v * 1.5
        var r: float = lerpf(3.25, 2.65, v) * (1.0 + 0.07 * _onda(cos(ang) * 2.2, y, sin(ang) * 2.2, ph))
        return Vector3(cos(ang) * r, y, sin(ang) * r)
    var c_ped := func(u: float, v: float, p: Vector3) -> Color:
        var t: float = 0.80 + 0.16 * _onda(p.x * 0.9, p.y * 2.0, p.z * 0.9, ph + 1.0) + 0.06 * v
        return Color(t, t * 0.98, t * 0.94)
    ped.superficie(f_ped, 20, 5, c_ped, Callable(), Vector3(0, 0, 0))
    var f_topo := func(u: float, v: float) -> Vector3:
        var ang: float = u * TAU
        var r: float = lerpf(2.65, 1.70, v) * (1.0 + 0.07 * _onda(cos(ang) * 2.2, 0.75, sin(ang) * 2.2, ph) * (1.0 - v))
        return Vector3(cos(ang) * r, 0.75, sin(ang) * r)
    ped.superficie(f_topo, 20, 2, Callable(), Callable(), Vector3(0, -6, 0), Color(0.78, 0.76, 0.71))
    ped.caixa(Vector3(2.15, 0.84, 0), Vector3(0.9, 0.18, 1.7), Color(0.76, 0.74, 0.70))                          # degraus da porta
    ped.caixa(Vector3(2.55, 0.70, 0), Vector3(0.8, 0.16, 1.9), Color(0.70, 0.68, 0.64))
    # torre afunilada, em cinco trechos: branco, faixa vermelha, branco, faixa vermelha, branco
    var cortes: Array = [-0.35, 2.65, 4.65, 7.15, 9.15, 12.65]
    for k in 5:
        var y_a: float = cortes[k]
        var y_b: float = cortes[k + 1]
        var cor_k: Color = vermelho if k % 2 == 1 else branco
        var r_a: float = lerpf(1.75, 1.20, (y_a + 0.35) / 13.0)
        var r_b: float = lerpf(1.75, 1.20, (y_b + 0.35) / 13.0)
        var mancha := func(t: float, ang: float) -> Color:
            var y: float = lerpf(y_a, y_b, t)
            var m: float = 0.045 * _onda(cos(ang) * 2.0, y * 0.7, sin(ang) * 2.0, ph) + 0.12 * (1.0 - smoothstep(-0.35, 2.4, y))
            return Color(cor_k.r - m, cor_k.g - m, cor_k.b - m * 0.7)
        tor.tronco(Vector3(0, y_a, 0), r_a, r_b, y_b - y_a, 16, cor_k, cor_k, false, mancha, 3)
    # porta e frestas de janela em espiral
    _porta(acab, acab, Vector3(1.66, 0.75, 0), Vector3.RIGHT, 1.05, 2.0, Color(0.50, 0.12, 0.10), Color(0.97, 0.95, 0.90), false)
    var alturas: Array = [3.65, 6.0, 8.15, 10.45]
    for k in alturas.size():
        var y: float = alturas[k]
        var ang: float = deg_to_rad(90.0 + 120.0 * float(k))
        var dir := Vector3(cos(ang), 0, sin(ang))
        var r: float = lerpf(1.75, 1.20, (y + 0.35) / 13.0)
        var bb := Basis(Vector3.UP.cross(dir), Vector3.UP, dir)
        var c: Vector3 = dir * (r - 0.01) + Vector3(0, y, 0)
        acab.caixa(c, Vector3(0.32, 0.64, 0.07), Color(0.09, 0.10, 0.13), bb)
        acab.caixa(c + bb * Vector3(0, 0.38, 0.03), Vector3(0.52, 0.09, 0.14), Color(0.96, 0.94, 0.88), bb)
        acab.caixa(c + bb * Vector3(0, -0.38, 0.05), Vector3(0.52, 0.08, 0.18), Color(0.96, 0.94, 0.88), bb)
        for s in [-1.0, 1.0]:
            acab.caixa(c + bb * Vector3(float(s) * 0.21, 0, 0.03), Vector3(0.08, 0.72, 0.12), Color(0.96, 0.94, 0.88), bb)
    # galeria: mísulas em cone, laje e guarda-corpo circular
    var concreto := Color(0.38, 0.37, 0.36)
    acab.tronco(Vector3(0, 11.95, 0), 1.25, 2.0, 0.67, 18, concreto.darkened(0.15), concreto, false)
    acab.tronco(Vector3(0, 12.62, 0), 2.12, 2.12, 0.50, 18, concreto, concreto.lightened(0.12))
    var n_p: int = 20
    var raio_g: float = 2.0
    var pontos: Array = []
    for i in n_p:
        var ang: float = TAU * float(i) / float(n_p)
        pontos.append(Vector3(cos(ang) * raio_g, 0, sin(ang) * raio_g))
    for i in n_p:
        var p0: Vector3 = pontos[i]
        var p1: Vector3 = pontos[(i + 1) % n_p]
        acab.caixa(p0 + Vector3(0, 13.12 + 0.48, 0), Vector3(0.07, 0.96, 0.07), ferro)
        var dx: float = p1.x - p0.x
        var dz: float = p1.z - p0.z
        var rot := Basis(Vector3.UP, atan2(-dz, dx))
        var meio: Vector3 = (p0 + p1) * 0.5
        acab.caixa(meio + Vector3(0, 14.10, 0), Vector3(Vector2(dx, dz).length() + 0.02, 0.06, 0.06), ferro, rot)
        acab.caixa(meio + Vector3(0, 13.62, 0), Vector3(Vector2(dx, dz).length() + 0.02, 0.04, 0.04), ferro, rot)
    # lanterna: vidro em oito faces, montantes de ferro e anéis
    vid.tronco(Vector3(0, 13.15, 0), 1.12, 1.12, 1.6, 8, Color.WHITE, Color.WHITE, false)
    for i in 8:
        var ang: float = TAU * float(i) / 8.0
        acab.caixa(Vector3(cos(ang) * 1.13, 13.95, sin(ang) * 1.13), Vector3(0.08, 1.62, 0.08), ferro)
    acab.tronco(Vector3(0, 13.12, 0), 1.22, 1.22, 0.14, 8, ferro, ferro)
    acab.tronco(Vector3(0, 14.74, 0), 1.24, 1.24, 0.12, 8, ferro, ferro)
    # cúpula vermelha, beiral, remate e catavento
    acab.tronco(Vector3(0, 14.84, 0), 1.72, 1.55, 0.14, 16, vermelho.darkened(0.25), vermelho.darkened(0.15))
    acab.tronco(Vector3(0, 14.98, 0), 1.55, 0.22, 1.05, 16, vermelho, vermelho.lightened(0.12), true, Callable(), 3)
    acab.tronco(Vector3(0, 16.03, 0), 0.24, 0.10, 0.22, 8, ferro, ferro)
    acab.tronco(Vector3(0, 16.25, 0), 0.025, 0.025, 0.95, 6, ferro, ferro)
    acab.caixa(Vector3(0, 17.0, 0), Vector3(0.55, 0.05, 0.03), ferro)
    return {"pedra": ped.malha(), "torre": tor.malha(), "acab": acab.malha(), "vidro": vid.malha(),
            "tris": ped.triangulos() + tor.triangulos() + acab.triangulos() + vid.triangulos()}


## ---- cais ---------------------------------------------------------------------------------------------------------

## Piso de tábuas soltas (com folga, altura e tom levemente diferentes), faixa de borda e guarda-corpo do passadiço.
## Sistema local do cais: x ao longo (0 = praia), z de lado, y como no jogo (topo do piso em 1,26).
static func cais(comp: float, larg: float, cab_c: float, cab_l: float, semente: int = 7) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = semente
    var tab := Malha.new()
    var acab := Malha.new()
    var corpo: float = comp - cab_c
    var n: int = int(round(comp / 0.33))
    var passo: float = comp / float(n)
    for i in n:
        var x: float = (float(i) + 0.5) * passo
        var larg_i: float = cab_l if x > corpo else larg
        var comprimento: float = larg_i - 0.05 + rng.randf_range(-0.06, 0.06)
        var tom: float = rng.randf_range(0.84, 1.0)
        if rng.randf() < 0.12:
            tom *= 0.76
        var cor := Color(tom, tom * 0.97, tom * 0.93)
        tab.caixa(Vector3(x, 1.20 + rng.randf_range(-0.012, 0.012), rng.randf_range(-0.03, 0.03)), Vector3(passo - 0.032, 0.12, comprimento), cor, Basis.IDENTITY, cor.lightened(0.06))
    var madeira := Color(0.78, 0.70, 0.60)
    for s in [-1.0, 1.0]:
        tab.caixa(Vector3(corpo * 0.5, 1.13, float(s) * (larg * 0.5 + 0.02)), Vector3(corpo, 0.16, 0.07), madeira.darkened(0.12))
        tab.caixa(Vector3(corpo + cab_c * 0.5, 1.13, float(s) * (cab_l * 0.5 + 0.02)), Vector3(cab_c, 0.16, 0.07), madeira.darkened(0.12))
    tab.caixa(Vector3(comp + 0.02, 1.13, 0), Vector3(0.07, 0.16, cab_l + 0.1), madeira.darkened(0.12))
    # guarda-corpo do passadiço: mourões de 3 em 3 m, corrimão e travessa
    var x_ini: float = 2.0
    var x_fim: float = corpo - 1.0
    var n_m: int = int((x_fim - x_ini) / 3.0)
    var x_ult: float = x_ini + 3.0 * float(n_m)
    for s in [-1.0, 1.0]:
        var zz: float = float(s) * (larg * 0.5 - 0.1)
        for k in n_m + 1:
            var xm: float = x_ini + 3.0 * float(k)
            tab.caixa(Vector3(xm, 1.74, zz), Vector3(0.11, 0.96, 0.11), madeira.darkened(0.2), Basis.IDENTITY, madeira.darkened(0.1))
            tab.caixa(Vector3(xm, 2.24, zz), Vector3(0.16, 0.04, 0.16), madeira.darkened(0.3))
        tab.caixa(Vector3((x_ini + x_ult) * 0.5, 2.12, zz), Vector3(x_ult - x_ini + 0.1, 0.07, 0.10), madeira.darkened(0.12))
        tab.caixa(Vector3((x_ini + x_ult) * 0.5, 1.66, zz), Vector3(x_ult - x_ini + 0.1, 0.05, 0.06), madeira.darkened(0.25))
    return {"tabuas": tab.malha(), "acab": acab.malha(), "tris": tab.triangulos() + acab.triangulos()}


## ---- adereços -----------------------------------------------------------------------------------------------------

## Canoa de pescador: casco de seção arredondada com proa e popa levantadas, faixa clara na borda,
## interior de madeira, borda fechada e três bancos. Origem na linha d'água da borda, comprimento em X.
static func canoa(cor: Color) -> ArrayMesh:
    var m := Malha.new()
    var comp: float = 2.9
    var largura := func(s: float) -> float:
        return 0.68 * pow(maxf(1.0 - s * s, 0.0), 0.55)
    var levanta := func(s: float) -> float:
        return 0.17 * s * s
    var ponto_casco := func(u: float, theta: float, folga: float) -> Vector3:
        var s: float = u * 2.0 - 1.0
        var b: float = maxf(largura.call(s) - folga, 0.0)
        var d: float = (0.36 - folga) * (1.0 - 0.35 * s * s)
        return Vector3(s * comp, -d * cos(theta) + levanta.call(s), b * sin(theta))
    var f_ext := func(u: float, v: float) -> Vector3:
        return ponto_casco.call(u, lerpf(-PI * 0.5, PI * 0.5, v), 0.0)
    var f_int := func(u: float, v: float) -> Vector3:
        return ponto_casco.call(u, lerpf(-PI * 0.5, PI * 0.5, v), 0.05)
    var cor_ext := func(u: float, v: float, p: Vector3) -> Color:
        if v < 0.10 or v > 0.90:
            return Color(0.95, 0.92, 0.84)                        # faixa clara da borda
        if v > 0.36 and v < 0.64:
            return cor.darkened(0.30)                             # fundo mais escuro
        return cor
    var centro := Vector3(0, 0.3, 0)
    m.superficie(f_ext, 24, 8, cor_ext, Callable(), centro)
    m.superficie(f_int, 24, 8, Callable(), Callable(), centro, Color(0.62, 0.47, 0.31), true)
    for lado in [0.0, 1.0]:                                        # borda: fita entre o casco e o interior
        var th: float = -PI * 0.5 if lado < 0.5 else PI * 0.5
        var f_borda := func(u: float, v: float) -> Vector3:
            return (ponto_casco.call(u, th, 0.0) as Vector3).lerp(ponto_casco.call(u, th, 0.05), v)
        m.superficie(f_borda, 24, 1, Callable(), Callable(), Vector3(0, -6, 0), Color(0.80, 0.70, 0.55))
    for xb in [-1.1, 0.1, 1.2]:
        var s: float = float(xb) / comp
        var meia: float = (largura.call(s) as float) - 0.04
        m.caixa(Vector3(float(xb), -0.02 + (levanta.call(s) as float), 0), Vector3(0.22, 0.05, meia * 2.0), Color(0.58, 0.42, 0.27))
    return m.malha()


## Barril de duelas, bojudo, com quatro arcos de ferro e tampa.
static func barril(cor_duela: Color) -> ArrayMesh:
    var m := Malha.new()
    var alt: float = 0.95
    var raio := func(y: float) -> float:
        return 0.30 + 0.065 * sin(clampf(y / alt, 0.0, 1.0) * PI)
    var f := func(u: float, v: float) -> Vector3:
        var ang: float = u * TAU
        var y: float = v * alt
        var r: float = raio.call(y)
        return Vector3(cos(ang) * r, y, sin(ang) * r)
    var cf := func(u: float, v: float, p: Vector3) -> Color:
        var duela: int = int(floor(u * 14.0))
        var t: float = 0.86 + 0.14 * float((duela * 7) % 5) / 4.0
        return Color(cor_duela.r * t, cor_duela.g * t, cor_duela.b * t)
    m.superficie(f, 28, 6, cf, Callable(), Vector3(0, alt * 0.5, 0))
    m.tronco(Vector3(0, alt - 0.02, 0), 0.30, 0.30, 0.02, 20, cor_duela.lightened(0.1), cor_duela.lightened(0.1))
    var ferro := Color(0.16, 0.15, 0.14)
    for y in [0.13, 0.33, 0.62, 0.82]:
        var r: float = (raio.call(float(y)) as float) + 0.012
        m.tronco(Vector3(0, float(y) - 0.025, 0), r, r, 0.05, 24, ferro, ferro, false)
    return m.malha()


## Poste de rua: mastro afunilado de madeira, base, mão-francesa e lampião de vidro com chapéu. O vidro fica em y = 4,3
## (onde o jogo põe a luz). Devolve {"acab", "vidro"}.
static func poste() -> Dictionary:
    var a := Malha.new()
    var v := Malha.new()
    var madeira := Color(0.40, 0.28, 0.18)
    var ferro := Color(0.14, 0.14, 0.13)
    a.tronco(Vector3(0, -0.10, 0), 0.20, 0.15, 0.55, 10, madeira.darkened(0.15), madeira, false)           # base mais grossa
    a.tronco(Vector3(0, 0.40, 0), 0.14, 0.095, 3.65, 10, madeira, madeira.lightened(0.08), false, Callable(), 3)
    a.tronco(Vector3(0, 4.03, 0), 0.20, 0.20, 0.05, 10, ferro, ferro)                                          # prato do lampião
    for s in [-1.0, 1.0]:                                                                                      # mãos-francesas em cruz
        a.caixa(Vector3(float(s) * 0.17, 3.78, 0), Vector3(0.50, 0.06, 0.06), madeira.darkened(0.1), Basis(Vector3.BACK, float(s) * 0.7))
        a.caixa(Vector3(0, 3.78, float(s) * 0.17), Vector3(0.06, 0.06, 0.50), madeira.darkened(0.1), Basis(Vector3.RIGHT, -float(s) * 0.7))
    v.caixa(Vector3(0, 4.30, 0), Vector3(0.34, 0.42, 0.34), Color.WHITE)
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            a.caixa(Vector3(float(sx) * 0.18, 4.30, float(sz) * 0.18), Vector3(0.04, 0.46, 0.04), ferro)
    a.tronco(Vector3(0, 4.52, 0), 0.34, 0.05, 0.26, 4, ferro, ferro.lightened(0.1), true, Callable(), 1, PI * 0.25)    # chapéu piramidal
    a.tronco(Vector3(0, 4.78, 0), 0.04, 0.04, 0.10, 6, ferro, ferro)
    return {"acab": a.malha(), "vidro": v.malha()}
