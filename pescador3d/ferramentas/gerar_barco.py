"""Gera o modelo 3D do pesqueiro PE-3476 (assets/barco/PE3476_v4.glb) com as texturas pintadas.

Uso:  python ferramentas/gerar_texturas.py   (uma vez, cria as texturas)
      python ferramentas/gerar_barco.py
Convenção do Godot: Y para cima, proa em -Z, boreste em +X, medidas em metros, origem na linha d'água.
Nós do arquivo: Casco (tudo que é fixo), Helice e Leme (soltos, para o jogo girar).
Precisa de numpy, scipy e opencv-python (só para gerar; o jogo não usa Python).
"""
import json
import os
import struct
import numpy as np
import cv2
from scipy.spatial import ConvexHull

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(RAIZ, "assets", "texturas", "barco")
SAIDA = os.path.join(RAIZ, "assets", "barco", "PE3476_v4.glb")

# material -> textura (ou None), cor, aspereza, e extras
MATERIAIS = {
    "casco_branco": dict(tex="casco_branco", aspereza=0.78),
    "casco_vermelho": dict(tex="casco_vermelho", aspereza=0.88),
    "pintura_azul": dict(tex="pintura_azul", aspereza=0.72),
    "pintura_laranja": dict(tex="pintura_laranja", aspereza=0.76),
    "pintura_creme": dict(tex="pintura_creme", aspereza=0.78),
    "pintura_amarela": dict(tex="pintura_amarela", aspereza=0.76),
    "pintura_vermelha": dict(tex="casco_vermelho", aspereza=0.78, cor=(1.25, 1.0, 1.0)),
    "conves": dict(tex="conves", aspereza=0.86),
    "madeira_escura": dict(tex="madeira_escura", aspereza=0.82),
    "metal": dict(tex="metal", aspereza=0.55, metalico=0.35),
    "corda": dict(tex="corda", aspereza=0.95),
    "rede": dict(tex="rede", aspereza=0.95, normal=False),
    "bandeira": dict(tex="bandeira", aspereza=0.9, normal=False, dupla=True, repetir=False),
    "matricula": dict(tex="matricula", aspereza=0.8, normal=False, alfa=True, repetir=False),
    "vidro": dict(cor=(0.05, 0.09, 0.13), aspereza=0.18),
    "lona": dict(cor=(0.84, 0.78, 0.63), aspereza=1.0),
    "boia_laranja": dict(cor=(0.90, 0.36, 0.10), aspereza=0.6),
    "plastico_branco": dict(cor=(0.92, 0.91, 0.86), aspereza=0.55),
    "plastico_azul": dict(cor=(0.13, 0.30, 0.52), aspereza=0.55),
    "preto": dict(cor=(0.08, 0.08, 0.09), aspereza=0.7),
    "luz_vermelha": dict(cor=(0.75, 0.08, 0.06), aspereza=0.3, emissao=(0.9, 0.08, 0.05)),
    "luz_verde": dict(cor=(0.08, 0.6, 0.2), aspereza=0.3, emissao=(0.05, 0.8, 0.2)),
    "luz_quente": dict(cor=(1.0, 0.85, 0.5), aspereza=0.3, emissao=(1.0, 0.75, 0.35)),
}


class Parte:
    """Um nó do arquivo: junta triângulos por material."""

    def __init__(self, nome, pivo=(0.0, 0.0, 0.0)):
        self.nome = nome
        self.pivo = np.array(pivo, float)
        self.mats = {}

    def juntar(self, mat, P, N, UV, I):
        m = self.mats.setdefault(mat, dict(P=[], N=[], UV=[], I=[], n=0))
        m["P"].append(np.asarray(P, float) - self.pivo)
        m["N"].append(np.asarray(N, float))
        m["UV"].append(np.asarray(UV, float))
        m["I"].append(np.asarray(I, int) + m["n"])
        m["n"] += len(P)

    # ---- superfície em grade, com normais suaves
    def grade(self, mat, P, UV, virar=False):
        nl, nc = P.shape[:2]
        idx = np.arange(nl * nc).reshape(nl, nc)
        a, b, c, d = idx[:-1, :-1].ravel(), idx[1:, :-1].ravel(), idx[1:, 1:].ravel(), idx[:-1, 1:].ravel()
        I = np.concatenate([np.column_stack([a, b, c]), np.column_stack([a, c, d])])
        if virar:
            I = I[:, ::-1]
        V = P.reshape(-1, 3)
        fn = np.cross(V[I[:, 1]] - V[I[:, 0]], V[I[:, 2]] - V[I[:, 0]])
        N = np.zeros_like(V)
        for k in range(3):
            np.add.at(N, I[:, k], fn)
        comp = np.linalg.norm(N, axis=1, keepdims=True)
        N = np.where(comp > 1e-12, N / np.maximum(comp, 1e-12), np.array([0.0, 1.0, 0.0]))
        self.juntar(mat, V, N, UV.reshape(-1, 2), I)

    # ---- sólido convexo de faces planas, com UV em metros por projeção de caixa
    def convexo(self, mat, pontos, uv_escala=1.0, uv_desloc=(0.0, 0.0)):
        pontos = np.asarray(pontos, float)
        casca = ConvexHull(pontos)
        P, N, UV, I = [], [], [], []
        for simplice, eq in zip(casca.simplices, casca.equations):
            tri = pontos[simplice]
            n = np.cross(tri[1] - tri[0], tri[2] - tri[0])
            if np.dot(n, eq[:3]) < 0:
                tri = tri[::-1]
            n = eq[:3] / np.linalg.norm(eq[:3])
            eixo = int(np.argmax(np.abs(n)))
            if eixo == 0:
                uv = tri[:, [2, 1]]                      # lado: tábuas ao longo do comprimento
            elif eixo == 1:
                uv = tri[:, [2, 0]]                      # topo: tábuas ao longo do comprimento
            else:
                uv = tri[:, [0, 1]]                      # frente e trás
            base = len(P)
            P.extend(tri)
            N.extend([n] * 3)
            UV.extend(uv * uv_escala + np.array(uv_desloc))
            I.append([base, base + 1, base + 2])
        UV = np.array(UV)
        UV[:, 1] = -UV[:, 1]                              # a imagem cresce para baixo
        self.juntar(mat, P, N, UV, I)

    def caixa(self, mat, centro, tam, chanfro=0.015, giro_y=0.0, **kw):
        h = np.array(tam, float) / 2.0
        c = min(chanfro, h.min() * 0.45)
        pts = []
        for eixo in range(3):
            outros = [e for e in range(3) if e != eixo]
            for s in (-1, 1):
                for sa in (-1, 1):
                    for sb in (-1, 1):
                        p = np.zeros(3)
                        p[eixo] = s * h[eixo]
                        p[outros[0]] = sa * (h[outros[0]] - c)
                        p[outros[1]] = sb * (h[outros[1]] - c)
                        pts.append(p)
        pts = np.array(pts)
        if giro_y:
            co, se = np.cos(giro_y), np.sin(giro_y)
            pts = pts @ np.array([[co, 0, -se], [0, 1, 0], [se, 0, co]])
        self.convexo(mat, pts + np.array(centro, float), **kw)

    def cilindro(self, mat, p0, p1, r0, r1=None, seg=14, tampas=True, mat_tampa=None, uv_voltas=None):
        p0, p1 = np.array(p0, float), np.array(p1, float)
        r1 = r0 if r1 is None else r1
        eixo = p1 - p0
        comp = np.linalg.norm(eixo)
        w = eixo / comp
        ref = np.array([0.0, 1.0, 0.0]) if abs(w[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
        u = np.cross(w, ref)
        u /= np.linalg.norm(u)
        v = np.cross(w, u)
        ang = np.linspace(0, 2 * np.pi, seg + 1)
        anel = np.cos(ang)[:, None] * u + np.sin(ang)[:, None] * v
        P = np.stack([p0 + anel * r0, p1 + anel * r1])            # (2, seg+1, 3)
        voltas = uv_voltas if uv_voltas is not None else max(1.0, round(2 * np.pi * max(r0, r1)))
        UV = np.stack([np.column_stack([ang / (2 * np.pi) * voltas, np.zeros(seg + 1)]),
                       np.column_stack([ang / (2 * np.pi) * voltas, np.full(seg + 1, -comp)])])
        self.grade(mat, P, UV, virar=True)
        if tampas:
            mt = mat_tampa or mat
            for centro, raio, lado in ((p0, r0, -1), (p1, r1, 1)):
                if raio <= 1e-6:
                    continue
                borda = centro + anel[:-1] * raio
                P2 = np.vstack([centro, borda])
                I = [[0, 1 + i, 1 + (i + 1) % seg] if lado > 0 else [0, 1 + (i + 1) % seg, 1 + i] for i in range(seg)]
                UV2 = np.vstack([[0.5, 0.5], 0.5 + 0.5 * np.column_stack([np.cos(ang[:-1]), np.sin(ang[:-1])])]) * raio * 2
                self.juntar(mt, P2, np.tile(w * lado, (len(P2), 1)), UV2, I)

    def toro(self, mat, centro, R, r, eixo=(0, 1, 0), seg=22, seg2=9, inicio=0.0, fim=2 * np.pi):
        w = np.array(eixo, float)
        w /= np.linalg.norm(w)
        ref = np.array([0.0, 1.0, 0.0]) if abs(w[1]) < 0.9 else np.array([1.0, 0.0, 0.0])
        u = np.cross(w, ref)
        u /= np.linalg.norm(u)
        v = np.cross(w, u)
        a = np.linspace(inicio, fim, seg + 1)[:, None]
        b = np.linspace(0, 2 * np.pi, seg2 + 1)[None, :]
        radial = np.cos(a)[..., None] * u + np.sin(a)[..., None] * v          # (seg+1, 1, 3)
        P = np.array(centro, float) + radial * (R + r * np.cos(b)[..., None]) + w * (r * np.sin(b)[..., None])
        UV = np.dstack([np.broadcast_to(a * R * 4, (seg + 1, seg2 + 1)), np.broadcast_to(b / (2 * np.pi), (seg + 1, seg2 + 1))])
        self.grade(mat, P, UV, virar=False)

    def elipsoide(self, mat, centro, raios, seg=14, seg2=8, uv_escala=2.0):
        a = np.linspace(0, 2 * np.pi, seg + 1)[None, :]
        b = np.linspace(-np.pi / 2, np.pi / 2, seg2 + 1)[:, None]
        P = np.dstack([np.cos(b) * np.cos(a) * raios[0], np.sin(b) * np.ones_like(a) * raios[1], np.cos(b) * np.sin(a) * raios[2]])
        UV = np.dstack([np.broadcast_to(a / (2 * np.pi) * uv_escala, P.shape[:2]), np.broadcast_to(b / np.pi * uv_escala, P.shape[:2])])
        self.grade(mat, P + np.array(centro, float), UV, virar=False)

    def quad(self, mat, pts, uvs):
        pts = np.array(pts, float)
        n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        n /= np.linalg.norm(n)
        self.juntar(mat, pts, np.tile(n, (4, 1)), uvs, [[0, 1, 2], [0, 2, 3]])


# ------------------------------------------------------------------ forma do casco

Z_POPA, Z_PROA = 4.0, -4.05
Y_CONVES = 0.40
ESPESSURA = 0.07


def degrau(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def boca(t):
    """Meia largura na borda (m): popa quadrada, mais largo a 1/3, afinando até a roda de proa."""
    atras = 1.02 + 0.28 * degrau(0.0, 0.36, t)
    frente = 1.30 * np.clip(1 - np.clip((t - 0.36) / 0.64, 0, 1) ** 2.3, 0, 1) ** 0.58
    return np.maximum(np.where(t < 0.36, atras, frente), 0.035)


def borda(t):
    """Altura da borda (m): o tosamento sobe bastante para a proa."""
    return 0.80 + 0.58 * t ** 2.4 + 0.10 * (1 - t) ** 3


def calado(t):
    return 0.64 * (1 - 0.86 * t ** 5) * (1 - 0.14 * (1 - t) ** 3)


def casco(t, u):
    """Ponto do casco: t = 0 popa ... 1 proa; u = 0 quilha ... 1 borda. Devolve (x, y, z) de boreste."""
    t, u = np.broadcast_arrays(np.asarray(t, float), np.asarray(u, float))
    B, S, D = boca(t), borda(t), calado(t)
    teta = u * np.pi / 2
    x = B * np.sin(teta) ** (0.72 + 0.75 * t ** 3)                  # fundo redondo; na proa vira um V
    y = -D + (S + D) * (1 - np.cos(teta)) ** 1.12
    alto = (y + D) / (S + D)
    z = Z_POPA + (Z_PROA - Z_POPA) * t
    z = z - 0.52 * degrau(0.68, 1.0, t) * alto ** 1.4               # roda de proa lançada para a frente
    z = z + 0.16 * (1 - t) ** 5 * alto                              # espelho de popa levemente inclinado
    return np.stack([x, y, z], axis=-1)


def u_na_altura(t, y_alvo):
    """u em que o casco passa pela altura y_alvo (por bisseção)."""
    lo = np.zeros_like(np.asarray(t, float))
    hi = np.ones_like(lo)
    for _ in range(40):
        meio = (lo + hi) / 2
        acima = casco(t, meio)[..., 1] > y_alvo
        hi = np.where(acima, meio, hi)
        lo = np.where(acima, lo, meio)
    return (lo + hi) / 2


def faixa_do_casco(parte, mat, ts, u0, u1, linhas, desloc=0.0, virar_dentro=False, encolher=0.0):
    """Uma faixa do costado entre duas alturas (u0(t)..u1(t)), nos dois bordos."""
    f = np.linspace(0, 1, linhas)[:, None]
    U = u0[None, :] + (u1 - u0)[None, :] * f
    T = np.broadcast_to(ts[None, :], U.shape)
    P = casco(T, U)
    if encolher:
        P[..., 0] = np.maximum(P[..., 0] - encolher, 0.0)
    comp = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(casco(ts, np.full_like(ts, 0.8)), axis=0), axis=1))])
    cinta = np.concatenate([np.zeros((1, len(ts))), np.cumsum(np.linalg.norm(np.diff(P, axis=0), axis=2), axis=0)])
    base = np.linalg.norm(casco(ts, u0) - casco(ts, np.zeros_like(ts)), axis=1) if desloc is None else desloc
    UV = np.dstack([np.broadcast_to(comp[None, :], U.shape), -(cinta + base)]) * 0.6      # uma textura a cada 1,7 m
    for lado in (1, -1):
        Q = P.copy()
        Q[..., 0] *= lado
        parte.grade(mat, Q, UV * np.array([lado, 1.0]), virar=(lado > 0) != virar_dentro)
    return P


def construir():
    fixo = Parte("Casco")
    helice = Parte("Helice", pivo=(0.0, -0.66, 3.50))
    leme = Parte("Leme", pivo=(0.0, -0.10, 3.72))

    ts = np.linspace(0, 1, 49)
    zero, um = np.zeros_like(ts), np.ones_like(ts)
    u_agua = u_na_altura(ts, 0.03)                       # a tinta vermelha sobe 3 cm acima da linha d'água
    u_faixa = u_na_altura(ts, borda(ts) - 0.16)          # faixa azul de 16 cm junto da borda
    u_conves = u_na_altura(ts, Y_CONVES)

    # ---- costado: vermelho abaixo d'água, branco, faixa azul
    faixa_do_casco(fixo, "casco_vermelho", ts, zero, u_agua, 9, desloc=0.0)
    faixa_do_casco(fixo, "casco_branco", ts, u_agua, u_faixa, 8, desloc=0.0)
    faixa_do_casco(fixo, "pintura_azul", ts, u_faixa, um, 3, desloc=0.0)
    # ---- borda falsa por dentro e convés
    faixa_do_casco(fixo, "casco_branco", ts, u_conves, um, 4, desloc=0.3, virar_dentro=True, encolher=ESPESSURA)
    xd = np.maximum(casco(ts, u_conves)[:, 0] - ESPESSURA, 0.0)
    zd = casco(ts, u_conves)[:, 2]
    f = np.linspace(-1, 1, 9)[:, None]
    X = f * xd[None, :]
    Yc = Y_CONVES + 0.035 * (1 - f ** 2) * np.ones_like(X)                # convés levemente abaulado
    Pc = np.dstack([X, Yc, np.broadcast_to(zd[None, :], X.shape)])
    fixo.grade("conves", Pc, np.dstack([Pc[..., 2], Pc[..., 0]]), virar=False)

    # ---- espelho de popa (fecha a popa) e roda de proa (fecha a proa)
    for mat, ua, ub, n in (("casco_vermelho", zero[0], u_agua[0], 7), ("casco_branco", u_agua[0], u_faixa[0], 7),
                           ("pintura_azul", u_faixa[0], 1.0, 3)):
        us = np.linspace(ua, ub, n)
        lado_b = casco(np.zeros(n), us)
        lado_e = lado_b * np.array([-1, 1, 1])
        P = np.stack([lado_e, lado_b], axis=1)
        fixo.grade(mat, P, np.dstack([P[..., 0], -P[..., 1]]) * 0.6, virar=True)
    us = np.linspace(0, 1, 24)
    proa_b = casco(np.ones(24), us)
    P = np.stack([proa_b, proa_b * np.array([-1, 1, 1])], axis=1)
    fixo.grade("pintura_azul", P, np.dstack([P[..., 0], -P[..., 1]]), virar=True)

    # ---- alcatrate (tampa da borda), nos dois bordos
    topo = casco(ts, um)
    comp = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(topo, axis=0), axis=1))])
    for lado in (1, -1):
        perfil = [(-0.11, 0.0), (-0.11, 0.055), (0.045, 0.055), (0.045, -0.02)]      # (dx, dy) em volta da borda
        linhas = []
        for dx, dy in perfil:
            q = topo.copy()
            q[:, 0] = np.maximum(q[:, 0] + dx, 0.0) * lado
            q[:, 1] += dy
            linhas.append(q)
        for i in range(3):
            P = np.stack([linhas[i], linhas[i + 1]])
            UV = np.stack([np.column_stack([comp, np.full(len(ts), i * 0.12)]), np.column_stack([comp, np.full(len(ts), i * 0.12 + 0.11)])])
            fixo.grade("pintura_azul", P, UV, virar=lado < 0)

    # ---- quilha, hélice e leme
    fixo.convexo("casco_vermelho", [(x, y, z) for x in (-0.045, 0.045) for y, z in
                                    ((-0.50, 3.62), (-0.82, 3.30), (-0.80, -0.6), (-0.52, -2.0))])
    helice.cilindro("metal", (0, -0.66, 3.36), (0, -0.66, 3.56), 0.045, 0.03, seg=10)
    for k in range(3):
        a = k * 2 * np.pi / 3
        rad = np.array([np.cos(a), np.sin(a), 0.0])
        tang = np.array([-np.sin(a), np.cos(a), 0.0])
        pts = []
        for r, larg in ((0.04, 0.035), (0.11, 0.075), (0.17, 0.06), (0.20, 0.02)):
            for s in (-1, 1):
                for e in (-0.006, 0.006):
                    pts.append(np.array([0, -0.66, 3.46]) + rad * r + tang * s * larg + np.array([0, 0, s * larg * 0.55 + e]))
        helice.convexo("metal", pts)
    leme.convexo("casco_vermelho", [(x, y, z) for x in (-0.03, 0.03) for y, z in
                                    ((-0.10, 3.72), (-0.10, 4.10), (-0.84, 4.16), (-0.84, 3.74))])
    leme.cilindro("metal", (0, -0.86, 3.72), (0, 0.10, 3.72), 0.03, seg=8)

    # ---- matrícula nas duas amuras, acompanhando a curva do casco
    tm = np.linspace(0.735, 0.90, 12)
    for lado in (1, -1):
        linhas = []
        for frac in np.linspace(0.0, 1.0, 5):
            alto = borda(tm) - 0.22 - 0.26 * (1 - frac)
            p = casco(tm, u_na_altura(tm, alto)).copy()
            p[:, 0] = (p[:, 0] + 0.008) * lado
            linhas.append(p)
        P = np.stack(linhas)
        uu = np.linspace(1, 0, len(tm)) if lado < 0 else np.linspace(0, 1, len(tm))
        UV = np.dstack([np.broadcast_to(uu[None, :], P.shape[:2]), np.broadcast_to(np.linspace(1, 0, 5)[:, None], P.shape[:2])])
        fixo.grade("matricula", P, UV, virar=lado > 0)

    # ---- cabine, a ré: paredes inclinadas para dentro, cantoneiras, janelas, porta e teto abaulado
    zc, mc, hc = 1.95, 1.10, 1.78                                   # centro z, meio comprimento, altura
    lc = 0.84                                                       # meia largura na base
    yb, yt = Y_CONVES + 0.02, Y_CONVES + 0.02 + hc
    incl = 0.045                                                    # quanto cada parede entra no topo

    def canto(sx, sz, alto):
        k = incl * alto
        return (sx * (lc - k), yb + hc * alto, zc + sz * (mc - k))

    fixo.convexo("pintura_creme", [canto(sx, sz, a) for sx in (-1, 1) for sz in (-1, 1) for a in (0, 1)])
    for sx in (-1, 1):
        for sz in (-1, 1):                                          # cantoneiras de madeira
            b, c = np.array(canto(sx, sz, 0)), np.array(canto(sx, sz, 1))
            fora = np.array([sx, 0, sz]) * 0.012
            fixo.cilindro("madeira_escura", b + fora, c + fora, 0.035, seg=6)
    fixo.caixa("madeira_escura", (0, yb + 0.05, zc), (2 * lc + 0.06, 0.10, 2 * mc + 0.06), chanfro=0.02)   # soleira

    def janela(centro, larg, alt, normal, mat_moldura="pintura_azul"):
        n = np.array(normal, float)
        lado = np.cross([0, 1, 0], n)
        c = np.array(centro, float)
        fixo.convexo(mat_moldura, [c + lado * sa * (larg / 2 + 0.045) + np.array([0, sb * (alt / 2 + 0.045), 0]) + n * e
                                   for sa in (-1, 1) for sb in (-1, 1) for e in (-0.03, 0.022)])
        g = c + n * 0.026
        fixo.quad("vidro", [g - lado * larg / 2 - [0, alt / 2, 0], g + lado * larg / 2 - [0, alt / 2, 0],
                            g + lado * larg / 2 + [0, alt / 2, 0], g - lado * larg / 2 + [0, alt / 2, 0]],
                  [[0, 0], [1, 0], [1, 1], [0, 1]])

    yj = yb + hc * 0.66
    kj = incl * 0.66
    for xj in (-0.50, 0.0, 0.50):                                   # três janelas viradas para a proa
        janela((xj, yj, zc - mc + kj), 0.36, 0.42, (0, 0, -1))
    for sx in (-1, 1):                                              # duas em cada lado
        for zj in (-0.48, 0.42):
            janela((sx * (lc - kj), yj, zc + zj), 0.46, 0.40, (sx, 0, 0))
    # porta a ré, com vigia
    kp = incl * 0.45
    fixo.convexo("pintura_azul", [(sx * 0.33 - 0.22, yb + 0.10 + a * 1.42, zc + mc - incl * ((0.10 + a * 1.42) / hc) + e)
                                  for sx in (-1, 1) for a in (0, 1) for e in (-0.02, 0.035)])
    janela((-0.22, yb + 1.16, zc + mc - incl * 0.66 + 0.02), 0.26, 0.26, (0, 0, 1), "madeira_escura")
    fixo.caixa("metal", (0.02, yb + 0.80, zc + mc + 0.03), (0.03, 0.14, 0.05), chanfro=0.008)           # maçaneta
    janela((0.46, yj, zc + mc - kj), 0.30, 0.36, (0, 0, 1))

    # teto: laje abaulada com beiral
    bx, bz, esp = lc + 0.16, mc + 0.20, 0.07
    pts = []
    for z in (zc - bz - 0.10, zc + bz):                             # o beiral avança mais sobre as janelas da frente
        for x in np.linspace(-bx, bx, 9):
            arco = 0.13 * (1 - (x / bx) ** 2)
            pts.append((x, yt + esp + arco, z))
            pts.append((x * 0.985, yt + arco * 0.25, z))
    fixo.convexo("pintura_laranja", pts)
    y_teto = yt + esp + 0.13
    # em cima do teto: farol de busca, luzes de navegação, chaminé do motor e lanterna
    fixo.caixa("metal", (0.0, y_teto - 0.02, zc - 0.75), (0.16, 0.10, 0.16))
    fixo.cilindro("metal", (0.0, y_teto + 0.10, zc - 0.70), (0.0, y_teto + 0.10, zc - 0.92), 0.10, 0.12, seg=12, tampas=False)
    fixo.cilindro("luz_quente", (0.0, y_teto + 0.10, zc - 0.90), (0.0, y_teto + 0.10, zc - 0.921), 0.115, seg=12)
    fixo.cilindro("metal", (0.0, y_teto + 0.10, zc - 0.70), (0.0, y_teto + 0.10, zc - 0.69), 0.10, seg=12)
    fixo.caixa("luz_verde", (bx - 0.10, y_teto - 0.08, zc - 0.55), (0.10, 0.10, 0.16), chanfro=0.02)
    fixo.caixa("luz_vermelha", (-bx + 0.10, y_teto - 0.08, zc - 0.55), (0.10, 0.10, 0.16), chanfro=0.02)
    fixo.cilindro("metal", (0.48, y_teto - 0.10, zc + 0.70), (0.48, y_teto + 0.62, zc + 0.74), 0.065, seg=10)
    fixo.cilindro("preto", (0.48, y_teto + 0.62, zc + 0.74), (0.48, y_teto + 0.70, zc + 0.745), 0.085, seg=10)
    fixo.cilindro("metal", (-0.45, y_teto - 0.06, zc + 0.3), (-0.45, y_teto + 0.05, zc + 0.3), 0.07, seg=10)
    fixo.cilindro("luz_quente", (-0.45, y_teto + 0.05, zc + 0.3), (-0.45, y_teto + 0.20, zc + 0.3), 0.055, seg=10)
    fixo.cilindro("metal", (-0.45, y_teto + 0.20, zc + 0.3), (-0.45, y_teto + 0.24, zc + 0.3), 0.075, 0.02, seg=10)
    # boia salva-vidas na parede de bombordo... de boreste da cabine (laranja com quatro faixas brancas)
    cb = (lc - incl * 0.42 + 0.07, yb + hc * 0.40, zc + 0.02)
    for i in range(4):                                              # quatro trechos laranja e quatro faixas brancas
        a0 = i * np.pi / 2
        fixo.toro("boia_laranja", cb, 0.24, 0.062, eixo=(1, 0, 0), seg=7, seg2=8, inicio=a0, fim=a0 + np.pi / 2 - 0.36)
        fixo.toro("plastico_branco", cb, 0.24, 0.066, eixo=(1, 0, 0), seg=3, seg2=8, inicio=a0 + np.pi / 2 - 0.36, fim=a0 + np.pi / 2)

    # ---- mastro, retranca com a vela enrolada e estais
    zm = -0.95
    pe, tope = np.array([0, Y_CONVES, zm]), np.array([0, Y_CONVES + 3.35, zm + 0.10])
    fixo.cilindro("madeira_escura", pe, tope, 0.075, 0.048, seg=10)
    fixo.caixa("madeira_escura", (0, Y_CONVES + 0.10, zm), (0.34, 0.20, 0.34), chanfro=0.03)
    fixo.cilindro("metal", tope, tope + [0, 0.05, 0], 0.06, 0.02, seg=8)
    fixo.cilindro("luz_quente", tope + [0, 0.05, 0], tope + [0, 0.16, 0], 0.04, seg=8)
    r0, r1 = np.array([0, Y_CONVES + 1.42, zm + 0.10]), np.array([0, Y_CONVES + 1.62, zm + 1.75])
    fixo.cilindro("madeira_escura", r0, r1, 0.05, 0.04, seg=8)
    v0, v1 = r0 + (r1 - r0) * 0.06 + [0, 0.13, 0], r0 + (r1 - r0) * 0.94 + [0, 0.13, 0]
    fixo.cilindro("lona", v0, v1, 0.115, 0.095, seg=10)
    for f in np.linspace(0.08, 0.92, 6):                            # amarras da vela
        c = v0 + (v1 - v0) * f
        fixo.toro("corda", c - [0, 0.04, 0], 0.125, 0.014, eixo=(v1 - v0), seg=10, seg2=5)
    proa_topo = casco(1.0, 1.0)
    for alvo in (proa_topo + [0, 0.02, 0.05], casco(0.50, 1.0), casco(0.50, 1.0) * [-1, 1, 1], np.array([0, y_teto - 0.02, zc - bz])):
        fixo.cilindro("corda", tope - [0, 0.12, 0], np.array(alvo, float), 0.011, seg=5, tampas=False, uv_voltas=1)

    # ---- convés: escotilha do porão, guincho, caixas, tambor, caixa térmica, cabo e rede
    fixo.caixa("madeira_escura", (0, Y_CONVES + 0.08, 0.20), (1.00, 0.16, 0.86), chanfro=0.02)
    fixo.caixa("conves", (0, Y_CONVES + 0.17, 0.20), (0.90, 0.05, 0.76), chanfro=0.015, uv_escala=1.6)
    fixo.caixa("metal", (0.30, Y_CONVES + 0.20, 0.20), (0.05, 0.03, 0.16), chanfro=0.008)
    zg = -2.25                                                      # guincho de proa
    fixo.caixa("pintura_azul", (0, Y_CONVES + 0.06, zg), (0.66, 0.10, 0.44), chanfro=0.02)
    for sx in (-1, 1):
        fixo.caixa("pintura_azul", (sx * 0.27, Y_CONVES + 0.27, zg), (0.05, 0.36, 0.26), chanfro=0.015)
        fixo.cilindro("pintura_azul", (sx * 0.20, Y_CONVES + 0.34, zg), (sx * 0.24, Y_CONVES + 0.34, zg), 0.21, seg=14)
    fixo.cilindro("corda", (-0.20, Y_CONVES + 0.34, zg), (0.20, Y_CONVES + 0.34, zg), 0.145, seg=14, tampas=False, uv_voltas=2)
    fixo.cilindro("metal", (0.24, Y_CONVES + 0.34, zg), (0.40, Y_CONVES + 0.34, zg), 0.025, seg=6)
    fixo.cilindro("metal", (0.40, Y_CONVES + 0.34, zg), (0.40, Y_CONVES + 0.52, zg), 0.02, seg=6)
    fixo.caixa("pintura_amarela", (0.55, Y_CONVES + 0.25, -0.20), (0.50, 0.46, 0.60), chanfro=0.02, giro_y=0.12)
    fixo.caixa("pintura_vermelha", (0.60, Y_CONVES + 0.19, 0.50), (0.42, 0.34, 0.42), chanfro=0.02, giro_y=-0.2)
    fixo.caixa("pintura_amarela", (0.56, Y_CONVES + 0.62, -0.22), (0.38, 0.28, 0.40), chanfro=0.02, giro_y=0.5)
    fixo.caixa("plastico_branco", (-0.62, Y_CONVES + 0.20, 0.55), (0.42, 0.36, 0.62), chanfro=0.04)
    fixo.caixa("plastico_azul", (-0.62, Y_CONVES + 0.41, 0.55), (0.44, 0.07, 0.64), chanfro=0.03)
    ct = np.array([-0.60, Y_CONVES + 0.02, -0.25])                  # tambor azul
    fixo.cilindro("plastico_azul", ct, ct + [0, 0.74, 0], 0.24, seg=16)
    for h in (0.20, 0.54):
        fixo.toro("plastico_azul", ct + [0, h, 0], 0.243, 0.022, seg=16, seg2=5)
    for i, (R, r) in enumerate(((0.25, 0.04), (0.21, 0.04), (0.25, 0.04))):   # cabo aduchado
        fixo.toro("corda", (0.20, Y_CONVES + 0.07 + i * 0.07, -1.75), R, r, seg=18, seg2=6)
    fixo.elipsoide("rede", (-0.38, Y_CONVES + 0.13, -1.85), (0.50, 0.20, 0.42), uv_escala=3.0)
    rng = np.random.default_rng(3)
    for _ in range(6):                                              # flutuadores da rede
        a = rng.uniform(0, 2 * np.pi)
        fixo.elipsoide("boia_laranja", (-0.38 + 0.36 * np.cos(a), Y_CONVES + 0.24 + rng.uniform(0, 0.06), -1.85 + 0.30 * np.sin(a)),
                       (0.06, 0.05, 0.06), seg=8, seg2=5)

    # ---- defensas penduradas no costado (três por bordo)
    for sx in (-1, 1):
        for t in (0.22, 0.42, 0.60):
            b = casco(t, 1.0) * [sx, 1, 1]
            x = b[0] + sx * 0.15
            alto = b[1] - 0.20
            fixo.cilindro("corda", (b[0] + sx * 0.02, b[1] + 0.05, b[2]), (x, alto, b[2]), 0.012, seg=5, tampas=False, uv_voltas=1)
            fixo.cilindro("plastico_branco", (x, alto, b[2]), (x, alto - 0.05, b[2]), 0.03, 0.105, seg=12, tampas=False)
            fixo.cilindro("plastico_branco", (x, alto - 0.05, b[2]), (x, alto - 0.22, b[2]), 0.105, seg=12, tampas=False)
            fixo.cilindro("plastico_azul", (x, alto - 0.22, b[2]), (x, alto - 0.34, b[2]), 0.108, seg=12, tampas=False)
            fixo.cilindro("plastico_branco", (x, alto - 0.34, b[2]), (x, alto - 0.50, b[2]), 0.105, seg=12, tampas=False)
            fixo.cilindro("plastico_branco", (x, alto - 0.50, b[2]), (x, alto - 0.56, b[2]), 0.105, 0.03, seg=12, tampas=False)

    # ---- bandeira na popa, com o pano ondulado
    pm = np.array([-0.80, borda(0.0) + 0.04, 3.86])
    fixo.cilindro("metal", pm, pm + [0, 1.35, 0], 0.018, seg=6)
    a = np.linspace(0, 1, 10)[None, :]
    b = np.linspace(0, 1, 4)[:, None]
    onda = 0.045 * np.sin(a * 7.0) * a
    Pb = np.dstack([pm[0] + onda + 0 * b, pm[1] + 1.32 - b * 0.40 - 0.03 * a + 0 * a, pm[2] + 0.02 + a * 0.60 + 0 * b])
    fixo.grade("bandeira", Pb, np.dstack([np.broadcast_to(1 - a, Pb.shape[:2]), np.broadcast_to(b, Pb.shape[:2])]), virar=False)
    return [fixo, helice, leme]


# ------------------------------------------------------------------ gravação do .glb

def gravar(partes, caminho):
    bin_ = bytearray()
    vistas, acessores, malhas, nos = [], [], [], []
    imagens, texturas, materiais, indice_mat, indice_tex = [], [], [], {}, {}

    def vista(dados, alvo=None):
        while len(bin_) % 4:
            bin_.append(0)
        v = {"buffer": 0, "byteOffset": len(bin_), "byteLength": len(dados)}
        if alvo:
            v["target"] = alvo
        bin_.extend(dados)
        vistas.append(v)
        return len(vistas) - 1

    def textura(arquivo, tamanho, repetir):
        chave = (arquivo, tamanho, repetir)
        if chave not in indice_tex:
            img = cv2.imread(os.path.join(TEX, arquivo), cv2.IMREAD_UNCHANGED)
            if img is None:
                raise SystemExit("Falta a textura %s. Rode antes: python ferramentas/gerar_texturas.py" % arquivo)
            if tamanho and img.shape[1] > tamanho:
                img = cv2.resize(img, (tamanho, int(img.shape[0] * tamanho / img.shape[1])), interpolation=cv2.INTER_AREA)
            ok, png = cv2.imencode(".png", img)
            imagens.append({"bufferView": vista(png.tobytes()), "mimeType": "image/png", "name": arquivo[:-4]})
            texturas.append({"source": len(imagens) - 1, "sampler": 0 if repetir else 1})
            indice_tex[chave] = len(texturas) - 1
        return indice_tex[chave]

    def material(nome):
        if nome not in indice_mat:
            d = MATERIAIS[nome]
            pbr = {"roughnessFactor": d.get("aspereza", 0.8), "metallicFactor": d.get("metalico", 0.0),
                   "baseColorFactor": list(d.get("cor", (1.0, 1.0, 1.0))) + [1.0]}
            m = {"name": nome, "pbrMetallicRoughness": pbr}
            if d.get("tex"):
                pbr["baseColorTexture"] = {"index": textura(d["tex"] + ".png", 1024, d.get("repetir", True))}
                if d.get("normal", True):
                    m["normalTexture"] = {"index": textura(d["tex"] + "_normal.png", 512, True), "scale": 0.9}
            if d.get("dupla"):
                m["doubleSided"] = True
            if d.get("alfa"):
                m["alphaMode"] = "BLEND"
            if d.get("emissao"):
                m["emissiveFactor"] = list(d["emissao"])
            materiais.append(m)
            indice_mat[nome] = len(materiais) - 1
        return indice_mat[nome]

    total = 0
    for parte in partes:
        prims = []
        for nome, m in parte.mats.items():
            P = np.vstack(m["P"]).astype("<f4")
            N = np.vstack(m["N"]).astype("<f4")
            UV = np.vstack(m["UV"]).astype("<f4")
            I = np.vstack(m["I"]).astype("<u4")
            total += len(I)
            a0 = len(acessores)
            acessores.append({"bufferView": vista(P.tobytes(), 34962), "componentType": 5126, "count": len(P), "type": "VEC3",
                              "min": P.min(0).tolist(), "max": P.max(0).tolist()})
            acessores.append({"bufferView": vista(N.tobytes(), 34962), "componentType": 5126, "count": len(N), "type": "VEC3"})
            acessores.append({"bufferView": vista(UV.tobytes(), 34962), "componentType": 5126, "count": len(UV), "type": "VEC2"})
            acessores.append({"bufferView": vista(I.tobytes(), 34963), "componentType": 5125, "count": I.size, "type": "SCALAR"})
            prims.append({"attributes": {"POSITION": a0, "NORMAL": a0 + 1, "TEXCOORD_0": a0 + 2}, "indices": a0 + 3,
                          "material": material(nome)})
        malhas.append({"name": parte.nome, "primitives": prims})
        nos.append({"name": parte.nome, "mesh": len(malhas) - 1, "translation": parte.pivo.tolist()})
    nos.append({"name": "Barco_PE3476", "children": list(range(len(partes)))})
    gltf = {"asset": {"version": "2.0", "generator": "MAR ABERTO ferramentas/gerar_barco.py"},
            "scene": 0, "scenes": [{"nodes": [len(nos) - 1]}], "nodes": nos, "meshes": malhas, "materials": materiais,
            "textures": texturas, "images": imagens,
            "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497},
                         {"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}],
            "accessors": acessores, "bufferViews": vistas, "buffers": [{"byteLength": len(bin_)}]}
    while len(bin_) % 4:
        bin_.append(0)
    gltf["buffers"][0]["byteLength"] = len(bin_)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(bin_)))
        f.write(struct.pack("<I4s", len(js), b"JSON") + js)
        f.write(struct.pack("<I4s", len(bin_), b"BIN\x00") + bytes(bin_))
    return total


if __name__ == "__main__":
    partes = construir()
    tri = gravar(partes, SAIDA)
    todos = np.vstack([np.vstack(m["P"]) + p.pivo for p in partes for m in p.mats.values()])
    print("%s: %d triângulos, %.1f MB" % (os.path.relpath(SAIDA, RAIZ), tri, os.path.getsize(SAIDA) / 1e6))
    print("tamanho (m): comprimento %.2f, boca %.2f, altura %.2f" % (np.ptp(todos[:, 2]), np.ptp(todos[:, 0]), np.ptp(todos[:, 1])))
