#!/usr/bin/env python3
"""v0.8.0: modelos 3D da jubarte e do golfinho-rotador a partir das pinturas de lado do SpriteCook.

Originais em arte_original/spritecook/v080/:
  jubarte_lado.png, jubarte_cauda.png (cauda vista de baixo), jubarte_nadadeira.png, golfinho_lado.png

Como o modelo nasce do desenho (assim a pintura encaixa sem esticar):
  - o contorno de cima e de baixo de cada coluna da imagem de lado vira uma seção elíptica do corpo (largura = altura x
    uma proporção que muda ao longo do bicho: cabeça larga, pedúnculo da cauda achatado de lado);
  - a nadadeira dorsal é "tirada" do contorno do corpo (o dorso é interpolado por baixo dela) e volta como um cartão
    vertical no plano do meio, recortado pelo alfa da própria pintura;
  - a cauda (que de lado aparece de quina) vira um cartão horizontal: na jubarte com a pintura da cauda vista de
    baixo; no golfinho, um crescente desenhado aqui, pintado com o cinza do dorso;
  - as nadadeiras peitorais: na jubarte, cartões com a pintura da nadadeira (longas, brancas); no golfinho, pequenas.
  - UV do corpo e da dorsal = projeção de lado (os dois lados mostram a mesma pintura, espelhada).
Saída: assets/fauna/<bicho>.json (vértices, normais, UV, cor-por-vértice, índices) e assets/fauna/<bicho>_pele.png
(atlas). A cor por vértice diz ao shader (shaders/cetaceo.gdshader) o que é cada peça:
  r = 0 corpo · 0,5 dorsal · 0,75 cauda · 1 nadadeira peitoral;  g = distância da raiz da nadadeira (0..1);
  b = lado (0 esquerdo, 1 direito).
Uso: python3 ferramentas/cetaceos.py"""
import json
import pathlib
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORIG = RAIZ / "arte_original" / "spritecook" / "v080"
DEST = RAIZ / "assets" / "fauna"

BICHOS = {
    "jubarte": {
        "comprimento": 13.0,           # m, do focinho à ponta da cauda
        "dorsal": (1150, 1425),        # colunas (px) onde fica a nadadeira dorsal na pintura
        "fim_corpo": 1790,             # depois disso a pintura mostra só a cauda de quina
        "largura": [(0.0, 0.78), (0.12, 0.95), (0.45, 1.00), (0.70, 0.78), (0.86, 0.55), (1.0, 0.42)],
        "aneis": 90, "lados": 28,
        "cauda_envergadura": 4.4, "cauda_comprimento": 1.9,
        "peitoral": {"raiz": 0.30, "altura": -0.55, "comprimento": 4.2, "largura": 0.95,
                     "abertura": 52.0, "queda": 16.0, "recuo": 36.0},
    },
    "golfinho": {
        "comprimento": 2.2,
        "dorsal": (840, 1185),
        "fim_corpo": 1745,
        "largura": [(0.0, 1.0), (0.10, 0.85), (0.25, 0.78), (0.50, 0.80), (0.75, 0.55), (0.90, 0.42), (1.0, 0.40)],
        "aneis": 80, "lados": 22,
        "cauda_envergadura": 0.55, "cauda_comprimento": 0.22,
        "peitoral": {"raiz": 0.27, "altura": -0.45, "comprimento": 0.30, "largura": 0.11,
                     "abertura": 40.0, "queda": 30.0, "recuo": 45.0},
    },
}


def mascara(img):
    return np.array(img)[..., 3] > 128


def sangrar(img: Image.Image) -> Image.Image:
    """Pinta o fundo transparente com a cor do pixel opaco mais próximo (sem franja nas bordas), mantendo o alfa."""
    a = np.array(img.convert("RGBA"))
    opaco = a[..., 3] > 128
    _, (iy, ix) = ndimage.distance_transform_edt(~opaco, return_indices=True)
    rgb = a[..., :3][iy, ix]
    return Image.fromarray(np.dstack([rgb, a[..., 3]]), "RGBA")


def largura_em(tab, s):
    xs = [p[0] for p in tab]
    ys = [p[1] for p in tab]
    return float(np.interp(s, xs, ys))


def suave(v, n=5):
    k = np.ones(n) / n
    p = np.pad(v, n // 2, mode="edge")
    return np.convolve(p, k, "valid")


class Malha:
    def __init__(self):
        self.v, self.uv, self.c, self.i = [], [], [], []

    def ponto(self, p, uv, cor):
        self.v.append(p); self.uv.append(uv); self.c.append(cor)
        return len(self.v) - 1

    def tri(self, a, b, c):
        self.i += [a, b, c]

    def normais(self):
        v = np.array(self.v, np.float64)
        n = np.zeros_like(v)
        idx = np.array(self.i).reshape(-1, 3)
        f = np.cross(v[idx[:, 1]] - v[idx[:, 0]], v[idx[:, 2]] - v[idx[:, 0]])
        for k in range(3):
            np.add.at(n, idx[:, k], f)
        n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-9)
        return n

    def cartao(self, cantos, uvs, cor, divisoes=(8, 4), cor_fn=None):
        """Quadrilátero subdividido (para ondular junto com o corpo). cantos/uvs: 4 pontos em ordem (00,10,11,01)."""
        nx, ny = divisoes
        base = len(self.v)
        for j in range(ny + 1):
            for k in range(nx + 1):
                u, w = k / nx, j / ny
                p = (cantos[0] * (1 - u) * (1 - w) + cantos[1] * u * (1 - w) + cantos[2] * u * w + cantos[3] * (1 - u) * w)
                t = (uvs[0] * (1 - u) * (1 - w) + uvs[1] * u * (1 - w) + uvs[2] * u * w + uvs[3] * (1 - u) * w)
                self.ponto(p.tolist(), t.tolist(), cor_fn(u, w) if cor_fn else cor)
        for j in range(ny):
            for k in range(nx):
                a = base + j * (nx + 1) + k
                self.tri(a, a + 1, a + nx + 2)
                self.tri(a, a + nx + 2, a + nx + 1)


def construir(nome, cfg):
    lado_img = Image.open(ORIG / (nome + "_lado.png")).convert("RGBA")
    m = mascara(lado_img)
    cols = np.where(m.any(0))[0]
    x0, x1 = int(cols.min()), int(cols.max())
    ys_all = np.where(m.any(1))[0]
    y0, y1 = int(ys_all.min()), int(ys_all.max())
    esc = cfg["comprimento"] / (x1 - x0)          # m por pixel
    # ---- atlas: pintura de lado em cima (2048 de largura); embaixo, cauda e nadadeira (só a jubarte)
    corte = sangrar(lado_img.crop((x0 - 6, y0 - 6, x1 + 7, y1 + 7)))
    larg_atlas = 2048
    k_lado = larg_atlas / corte.width
    alt_lado = int(round(corte.height * k_lado))
    tem_extra = nome == "jubarte"
    alt_atlas = 1024 if tem_extra else 512
    while alt_atlas < alt_lado:
        alt_atlas *= 2
    atlas = Image.new("RGBA", (larg_atlas, alt_atlas), (0, 0, 0, 0))
    atlas.paste(corte.resize((larg_atlas, alt_lado), Image.LANCZOS), (0, 0))

    def uv_lado(px, py):                       # pixel da imagem original -> UV do atlas
        return [((px - (x0 - 6)) * k_lado) / larg_atlas, ((py - (y0 - 6)) * k_lado) / alt_atlas]

    regioes = {}
    if tem_extra:
        y_livre = alt_lado + 8
        for parte, larg in (("cauda", 1000), ("nadadeira", 1000)):
            im = Image.open(ORIG / (nome + "_" + parte + ".png")).convert("RGBA")
            caixa = Image.fromarray((mascara(im) * 255).astype(np.uint8)).getbbox()
            im = sangrar(im.crop(caixa))
            alt = int(round(im.height * larg / im.width))
            x_at = 0 if parte == "cauda" else 1024
            atlas.paste(im.resize((larg, alt), Image.LANCZOS), (x_at, y_livre))
            regioes[parte] = (x_at / larg_atlas, y_livre / alt_atlas, (x_at + larg) / larg_atlas, (y_livre + alt) / alt_atlas)
        # o resto do atlas (vazio) recebe a cor do dorso, para os mipmaps não puxarem preto
    a_np = np.array(atlas)
    vazio = a_np[..., 3] == 0
    dorso = np.array(lado_img)[y0 + (y1 - y0) // 3, (x0 + x1) // 2, :3]
    a_np[vazio, :3] = dorso
    Image.fromarray(a_np, "RGBA").save(DEST / (nome + "_pele.png"), optimize=True)

    # ---- contorno do corpo, coluna a coluna
    xs = np.arange(x0, cfg["fim_corpo"] + 1)
    topo = np.array([np.where(m[:, x])[0].min() for x in xs], float)
    base = np.array([np.where(m[:, x])[0].max() for x in xs], float)
    d0, d1 = cfg["dorsal"]
    i0, i1 = d0 - x0, d1 - x0
    # dorso por baixo da dorsal: curva suave (Hermite) ligando as duas pontas com as inclinações de fora
    t0, t1 = topo[i0], topo[i1]
    s0 = topo[i0] - topo[i0 - 12]
    s1 = topo[i1 + 12] - topo[i1]
    n = i1 - i0
    for k in range(n + 1):
        u = k / n
        h00, h10, h01, h11 = 2*u**3 - 3*u**2 + 1, u**3 - 2*u**2 + u, -2*u**3 + 3*u**2, u**3 - u**2
        topo[i0 + k] = h00 * t0 + h10 * s0 / 12 * n + h01 * t1 + h11 * s1 / 12 * n
    topo = suave(topo, 7)
    base = suave(base, 7)
    x_meio = (x0 + x1) / 2.0
    imax = int(np.argmax(base - topo))
    y_eixo = (topo[imax] + base[imax]) / 2.0

    def z_de(px):
        return (px - x_meio) * esc

    def y_de(py):
        return -(py - y_eixo) * esc

    malha = Malha()
    corpo = (0.0, 0.0, 0.0, 1.0)
    # anéis: mais densos na cabeça e na cauda
    t = np.linspace(0, 1, cfg["aneis"])
    t = 0.5 - 0.5 * np.cos(np.pi * t)
    colunas = (t * (len(xs) - 1)).round().astype(int)
    colunas = np.unique(colunas)
    L = cfg["lados"]
    aneis = []
    for ci in colunas:
        px = xs[ci]
        s = (px - x0) / (x1 - x0)
        tp, bs = topo[ci] + 2.5, base[ci] - 2.5            # 2,5 px para dentro: o UV nunca pega o fundo
        h = max((bs - tp) / 2.0, 0.6)
        yc = (tp + bs) / 2.0
        w = h * largura_em(cfg["largura"], s)
        anel = []
        for j in range(L):
            a = 2 * np.pi * j / L
            py = yc - h * np.cos(a)                      # j=0 em cima, L/2 embaixo
            x = w * np.sin(a) * esc
            p = [x, y_de(py), z_de(px)]
            anel.append(malha.ponto(p, uv_lado(px, py), corpo))
        aneis.append(anel)
    for r in range(len(aneis) - 1):
        for j in range(L):
            a, b = aneis[r][j], aneis[r][(j + 1) % L]
            c, d = aneis[r + 1][(j + 1) % L], aneis[r + 1][j]
            malha.tri(a, d, c)
            malha.tri(a, c, b)
    for qual, sentido in ((0, -1), (len(aneis) - 1, 1)):           # tampas na ponta do focinho e no fim do pedúnculo
        anel = aneis[qual]
        cx = np.mean([malha.v[k] for k in anel], axis=0)
        cuv = np.mean([malha.uv[k] for k in anel], axis=0)
        centro = malha.ponto(cx.tolist(), cuv.tolist(), corpo)
        for j in range(L):
            a, b = anel[j], anel[(j + 1) % L]
            if sentido < 0:
                malha.tri(centro, b, a)
            else:
                malha.tri(centro, a, b)

    # ---- dorsal: cartão vertical no plano do meio, recortado pelo alfa
    alto = int(min(np.where(m[:, x])[0].min() for x in range(d0, d1 + 1))) - 2
    base_d = float(max(topo[i0], topo[i1])) + 0.20 * (base[imax] - topo[imax])   # entra no corpo
    cantos = np.array([[0, y_de(base_d), z_de(d0)], [0, y_de(base_d), z_de(d1)],
                       [0, y_de(alto), z_de(d1)], [0, y_de(alto), z_de(d0)]], float)
    uvs = np.array([uv_lado(d0, base_d), uv_lado(d1, base_d), uv_lado(d1, alto), uv_lado(d0, alto)], float)
    malha.cartao(cantos, uvs, (0.5, 0.0, 0.0, 1.0), (10, 6))

    # ---- cauda: cartão horizontal no fim do pedúnculo
    z_cauda = z_de(cfg["fim_corpo"]) - cfg["cauda_comprimento"] * 0.18
    y_cauda = y_de((topo[-1] + base[-1]) / 2.0)
    env, comp = cfg["cauda_envergadura"], cfg["cauda_comprimento"]
    cor_cauda = (0.75, 0.0, 0.0, 1.0)
    if "cauda" in regioes:
        u0, v0, u1, v1 = regioes["cauda"]
        # na pintura a haste da cauda vem de cima: topo da imagem = junto do corpo
        cantos = np.array([[-env / 2, y_cauda, z_cauda], [env / 2, y_cauda, z_cauda],
                           [env / 2, y_cauda, z_cauda + comp], [-env / 2, y_cauda, z_cauda + comp]], float)
        uvs = np.array([[u0, v0], [u1, v0], [u1, v1], [u0, v1]], float)
        malha.cartao(cantos, uvs, cor_cauda, (10, 6))
    else:
        # crescente desenhado: leque de triângulos, UV num ponto do dorso (cinza escuro)
        uv_dorso = uv_lado((x0 + x1) // 2, topo[imax] + 0.15 * (base[imax] - topo[imax]))
        pts = []
        for k in range(17):
            a = -1 + 2 * k / 16
            borda = comp * (0.35 + 0.65 * abs(a) ** 1.6)        # ponta das lâminas mais para trás
            pts.append([a * env / 2, y_cauda, z_cauda + borda])
        for k in range(16, -1, -1):
            a = -1 + 2 * k / 16
            frente = comp * (0.05 + 0.75 * abs(a) ** 2.2)
            pts.append([a * env / 2 * 0.98, y_cauda, z_cauda + frente * 0.9])
        centro = malha.ponto([0, y_cauda, z_cauda + comp * 0.2], uv_dorso, cor_cauda)
        ids = [malha.ponto(p, uv_dorso, cor_cauda) for p in pts]
        for k in range(len(ids)):
            malha.tri(centro, ids[k], ids[(k + 1) % len(ids)])

    # ---- nadadeiras peitorais
    pc = cfg["peitoral"]
    col_raiz = int(pc["raiz"] * (len(xs) - 1))
    px_r = xs[col_raiz]
    h_r = (base[col_raiz] - topo[col_raiz]) / 2.0
    yc_r = (base[col_raiz] + topo[col_raiz]) / 2.0
    w_r = h_r * largura_em(cfg["largura"], (px_r - x0) / (x1 - x0)) * esc
    raiz_y = y_de(yc_r) + pc["altura"] * h_r * esc
    for lado in (-1.0, 1.0):
        ab, qd, rc = np.radians(pc["abertura"]), np.radians(pc["queda"]), np.radians(pc["recuo"])
        # direção da nadadeira: para fora, para trás e para baixo
        d = np.array([lado * np.cos(rc) * np.cos(qd), -np.sin(qd), np.sin(rc) * np.cos(qd)])
        d /= np.linalg.norm(d)
        # largura da nadadeira: perpendicular, quase no plano horizontal, inclinada pela abertura
        lat = np.cross(d, [0, 1, 0]); lat /= np.linalg.norm(lat)
        cima = np.cross(lat, d)
        largura_dir = lat * np.cos(ab * 0.3) + cima * np.sin(ab * 0.3) * 0.2
        largura_dir /= np.linalg.norm(largura_dir)
        r0 = np.array([lado * w_r * 0.85, raiz_y, z_de(px_r)])
        comp_n, larg_n = pc["comprimento"], pc["largura"]
        cantos = np.array([r0 - largura_dir * larg_n * 0.5, r0 + d * comp_n - largura_dir * larg_n * 0.5,
                           r0 + d * comp_n + largura_dir * larg_n * 0.5, r0 + largura_dir * larg_n * 0.5])
        lado_b = 0.0 if lado < 0 else 1.0
        if "nadadeira" in regioes:
            u0, v0, u1, v1 = regioes["nadadeira"]
            uvs = np.array([[u0, v1], [u1, v1], [u1, v0], [u0, v0]], float)
            malha.cartao(cantos, uvs, None, (12, 3), lambda u, w, lb=lado_b: (1.0, u, lb, 1.0))
        else:
            uv_d = uv_lado((x0 + x1) // 2, topo[imax] + 0.15 * (base[imax] - topo[imax]))
            # nadadeira pequena: folha pontuda (losango alongado)
            pts = [r0 - largura_dir * larg_n * 0.5, r0 + d * comp_n * 0.45 - largura_dir * larg_n * 0.35,
                   r0 + d * comp_n, r0 + d * comp_n * 0.45 + largura_dir * larg_n * 0.45, r0 + largura_dir * larg_n * 0.5]
            ids = [malha.ponto(p.tolist(), uv_d, (1.0, float(np.dot(p - r0, d) / comp_n), lado_b, 1.0)) for p in pts]
            malha.tri(ids[0], ids[1], ids[4]); malha.tri(ids[1], ids[3], ids[4]); malha.tri(ids[1], ids[2], ids[3])

    nrm = malha.normais()
    z_frente = z_de(x0)
    dados = {
        "v": np.round(np.array(malha.v), 4).ravel().tolist(),
        "n": np.round(nrm, 3).ravel().tolist(),
        "uv": np.round(np.array(malha.uv), 5).ravel().tolist(),
        "c": np.round(np.array(malha.c), 3).ravel().tolist(),
        "i": malha.i,
        "z_cabeca": round(z_frente, 3),
        "comprimento": cfg["comprimento"],
        "altura": round((base[imax] - topo[imax]) * esc, 3),
    }
    (DEST / (nome + ".json")).write_text(json.dumps(dados, separators=(",", ":")))
    print(nome, len(malha.v), "vértices", len(malha.i) // 3, "triângulos", "altura %.2f m" % dados["altura"])


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for nome, cfg in BICHOS.items():
        construir(nome, cfg)


def atoba():
    """v0.8.2: o atobá (ave das ilhas) visto de cima, do SpriteCook -> assets/fauna/atoba.png. Recorte (19,34)-(2029,1117)
    da pintura original; scripts/fauna_costeira.gd monta corpo e asas como cartões com essas mesmas medidas."""
    im = Image.open(ORIG / "atoba_cima.png").convert("RGBA").crop((19, 34, 2030, 1118))
    sangrar(im).resize((1024, 552), Image.LANCZOS).save(DEST / "atoba.png", optimize=True)
    print("atoba.png")


if __name__ == "__main__":
    main()
    atoba()
