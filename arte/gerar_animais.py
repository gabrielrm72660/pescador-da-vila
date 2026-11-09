"""Gera os animais vistos de cima: peixes, golfinho e baleia (todos olhando para CIMA, como o tubarão).

O jogo é visto do alto, então os peixes da folha (de lado, com a barriga para baixo) pareciam nadar deitados.
Aqui os bichos são desenhados por código, sombreados como um tubo (mais escuro no meio do dorso, mais claro
nos flancos), com contorno escuro, e gravados em jogo/imagens/:
    peixe_topo_1..4.png, golfinho.png, baleia.png
Uso:  python arte/gerar_animais.py [--previa]
Precisa de numpy, opencv-python (cv2), scipy e Pillow: só para gerar; o jogo lê os PNGs prontos.
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy.interpolate import PchipInterpolator

AQUI = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(AQUI, "..", "jogo", "imagens")
SS = 4                                  # supersampling: desenha 4x maior e reduz (bordas lisas)


def cor(c):
    return np.array(c, np.float32)


class Tela:
    """Pintura em camadas num canvas RGBA grande; no fim reduz com média de área."""

    def __init__(self, w, h):
        self.w, self.h = w * SS, h * SS
        self.rgb = np.zeros((self.h, self.w, 3), np.float32)
        self.a = np.zeros((self.h, self.w), np.float32)
        yy, xx = np.mgrid[0:self.h, 0:self.w].astype(np.float32)
        self.xx, self.yy = xx / SS, yy / SS

    def mascara(self, pts):
        m = np.zeros((self.h, self.w), np.uint8)
        cv2.fillPoly(m, [np.round(np.array(pts, np.float32) * SS).astype(np.int32)], 255)
        return m

    def forma(self, pts, borda, centro, expo=0.75, luz=0.16, contorno=None, larg=1.6, grad=None):
        """Preenche um polígono sombreado como um tubo. 'grad' = (c0, c1, y0, y1): faixa de cor ao longo de y."""
        m = self.mascara(pts)
        self._pintar(m, borda, centro, expo, luz, contorno, larg, grad)
        return m

    def _pintar(self, m, borda, centro, expo, luz, contorno, larg, grad):
        if contorno is not None:
            k = max(1, int(round(larg * SS)))
            gr = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * k + 1, 2 * k + 1)))
            anel = (gr > 0) & (m == 0)
            self.rgb[anel] = cor(contorno)
            self.a[anel] = 1.0
        dist = cv2.distanceTransform(m, cv2.DIST_L2, 5)
        mx = float(dist.max()) or 1.0
        h = np.clip(dist / (mx * 0.92), 0, 1) ** expo
        b, c = cor(borda), cor(centro)
        if grad is not None:
            c0, c1, y0, y1 = grad
            u = np.clip((self.yy - y0) / float(y1 - y0), 0, 1)[..., None]
            c = cor(c0) * (1 - u) + cor(c1) * u
            b = c * 0.55 + cor(borda) * 0.45
        col = b * (1 - h[..., None]) + c * h[..., None]
        # luz vinda do alto e da esquerda
        gx = (self.xx - self.xx[m > 0].mean()) / max(1.0, np.ptp(self.xx[m > 0]))
        gy = (self.yy - self.yy[m > 0].mean()) / max(1.0, np.ptp(self.yy[m > 0]))
        col = col * (1.0 - luz * (gx + gy * 0.6))[..., None]
        sel = m > 0
        self.rgb[sel] = np.clip(col[sel], 0, 255)
        self.a[sel] = 1.0

    def manchas(self, m, c, forca, escala, semente):
        """Manchas claras (ruído suave) por cima de uma forma já pintada."""
        rnd = np.random.RandomState(semente)
        ruido = rnd.rand(self.h // (SS * 2) + 2, self.w // (SS * 2) + 2).astype(np.float32)
        ruido = cv2.resize(ruido, (self.w, self.h), interpolation=cv2.INTER_CUBIC)
        ruido = cv2.GaussianBlur(ruido, (0, 0), escala * SS)
        ruido = (ruido - ruido.min()) / max(1e-6, ruido.max() - ruido.min())
        t = np.clip((ruido - 0.55) * 4.0, 0, 1) * forca
        sel = (m > 0)
        w = (t * sel)[..., None]
        self.rgb = self.rgb * (1 - w) + cor(c) * w

    def elipse(self, cx, cy, rx, ry, c, alfa=1.0, ang=0.0):
        m = np.zeros((self.h, self.w), np.uint8)
        cv2.ellipse(m, (int(cx * SS), int(cy * SS)), (max(1, int(rx * SS)), max(1, int(ry * SS))), ang, 0, 360, 255, -1)
        sel = (m > 0) & (self.a > 0)
        self.rgb[sel] = self.rgb[sel] * (1 - alfa) + cor(c) * alfa

    def linha(self, pts, c, larg, alfa=1.0):
        m = np.zeros((self.h, self.w), np.uint8)
        cv2.polylines(m, [np.round(np.array(pts, np.float32) * SS).astype(np.int32)], False, 255,
                      max(1, int(larg * SS)), cv2.LINE_AA)
        sel = (m > 0) & (self.a > 0)
        w = (m[sel].astype(np.float32) / 255.0 * alfa)[:, None]
        self.rgb[sel] = self.rgb[sel] * (1 - w) + cor(c) * w

    def salvar(self, caminho, w, h):
        pre = self.rgb * self.a[..., None]
        pre = cv2.resize(pre, (w, h), interpolation=cv2.INTER_AREA)
        a = cv2.resize(self.a, (w, h), interpolation=cv2.INTER_AREA)
        rgb = np.where(a[..., None] > 1e-4, pre / np.maximum(a[..., None], 1e-4), 0)
        out = np.dstack([np.clip(rgb, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8)
        Image.fromarray(out, "RGBA").save(caminho)
        return out


def corpo(ctrl, cx, n=240):
    """Contorno simétrico em volta do eixo x=cx, a partir de pontos (y, meia-largura), suavizados."""
    ys = np.array([p[0] for p in ctrl], np.float64)
    ws = np.array([p[1] for p in ctrl], np.float64)
    f = PchipInterpolator(ys, ws)
    yy = np.linspace(ys[0], ys[-1], n)
    ww = np.maximum(f(yy), 0.0)
    esq = [(cx - w, y) for y, w in zip(yy, ww)]
    dir_ = [(cx + w, y) for y, w in zip(yy, ww)]
    return esq + dir_[::-1]


def espelho(meio, cx):
    """Lado esquerdo -> polígono inteiro (espelha em x=cx)."""
    return list(meio) + [(2 * cx - x, y) for x, y in reversed(meio)]


# ------------------------------------------------------------------ peixe visto de cima
def peixe(nome, w, h, semente, dorso, flanco, listras=None, barriga_clara=False, gordo=1.0, cauda_cor=None):
    cx = w / 2.0
    t = Tela(w, h)
    esc = h / 100.0
    contorno = (22, 34, 48)
    cc = cauda_cor or dorso
    # cauda em forquilha
    cauda = espelho([(cx - 1.6, 76 * esc), (cx - 9.0 * gordo, 90 * esc), (cx - 11.0 * gordo, 99 * esc),
                     (cx - 3.0, 91 * esc), (cx, 93 * esc)][:-1] + [(cx, 90 * esc)], cx)
    t.forma(cauda, flanco, cc, expo=0.6, luz=0.05, contorno=contorno, larg=0.9)
    # nadadeiras peitorais
    for lado in (-1, 1):
        pts = [(cx + lado * 4.0 * gordo, 28 * esc), (cx + lado * 13.0 * gordo, 38 * esc),
               (cx + lado * 4.5 * gordo, 36 * esc)]
        t.forma(pts, flanco, flanco, expo=0.5, luz=0.0, contorno=contorno, larg=0.8)
    # corpo fusiforme
    ctrl = [(2 * esc, 0.0), (5 * esc, 2.6), (12 * esc, 4.8 * gordo), (26 * esc, 6.6 * gordo),
            (44 * esc, 7.0 * gordo), (62 * esc, 5.2 * gordo), (76 * esc, 2.6), (82 * esc, 1.5)]
    m = t.forma(corpo(ctrl, cx), flanco, dorso, expo=0.85, luz=0.20, contorno=contorno, larg=1.0)
    if listras:
        for i in range(5):
            y = (22 + i * 9) * esc
            t.linha([(cx - 5.5 * gordo, y - 1.5), (cx, y + 1.0), (cx + 5.5 * gordo, y - 1.5)], listras, 0.9, 0.55)
    # dorso mais escuro e brilho do flanco
    t.linha([(cx, 8 * esc), (cx, 70 * esc)], tuple(int(c * 0.62) for c in dorso), 1.1, 0.55)
    t.linha([(cx - 3.2 * gordo, 18 * esc), (cx - 3.6 * gordo, 50 * esc)], (232, 240, 246), 0.8, 0.32)
    # olhos
    for lado in (-1, 1):
        t.elipse(cx + lado * 3.0, 9 * esc, 0.9, 0.9, (12, 18, 28))
    t.salvar(os.path.join(IMG, nome), w, h)


# ------------------------------------------------------------------ golfinho
def golfinho():
    W, H = 128, 320
    cx = W / 2.0
    t = Tela(W, H)
    contorno = (24, 38, 54)
    dorso, flanco = (78, 100, 120), (164, 186, 200)
    # cauda (nadadeira horizontal em meia-lua)
    lobo = [(60, 246), (50, 250), (30, 260), (10, 278), (6, 296), (24, 288), (42, 280), (56, 276), (64, 284)]
    t.forma(espelho(lobo, cx)[:-1], flanco, (96, 118, 136), expo=0.5, luz=0.08, contorno=contorno, larg=1.5)
    # peitorais varridas para trás
    for lado in (-1, 1):
        pts = [(cx + lado * 17, 96), (cx + lado * 36, 118), (cx + lado * 49, 146), (cx + lado * 39, 144),
               (cx + lado * 27, 138), (cx + lado * 17, 122)]
        t.forma(pts, flanco, (120, 142, 158), expo=0.5, luz=0.1, contorno=contorno, larg=1.5)
    # corpo
    ctrl = [(14, 0.0), (17, 2.4), (26, 4.6), (40, 6.4), (50, 9.5), (62, 14.5), (84, 18.5), (116, 20.5),
            (150, 19.0), (190, 14.0), (226, 8.0), (254, 4.6)]
    m = t.forma(corpo(ctrl, cx), flanco, dorso, expo=0.8, luz=0.20, contorno=contorno, larg=1.6)
    # "capa" escura do dorso e brilho
    t.linha([(cx, 52), (cx - 1, 120), (cx, 200), (cx, 240)], (46, 62, 80), 7.0, 0.42)
    t.linha([(cx - 6, 74), (cx - 7, 130), (cx - 5, 190)], (214, 230, 238), 2.2, 0.38)
    t.elipse(cx, 160, 3.2, 13.0, (36, 50, 66), 0.9)                 # a nadadeira dorsal vista de cima
    t.elipse(cx, 70, 1.6, 1.0, (18, 26, 38), 1.0)                   # o respiradouro
    for lado in (-1, 1):
        t.elipse(cx + lado * 14.0, 56, 1.9, 1.9, (12, 18, 28), 1.0)  # os olhos, nas laterais da cabeça
    t.salvar(os.path.join(IMG, "golfinho.png"), W, H)


# ------------------------------------------------------------------ baleia (jubarte vista de cima)
def baleia():
    W, H = 240, 560
    cx = W / 2.0
    t = Tela(W, H)
    contorno = (20, 30, 44)
    dorso, flanco = (30, 42, 58), (68, 90, 110)
    # cauda larga, com a borda de trás clara
    lobo = [(120, 498), (100, 502), (62, 514), (18, 534), (6, 556), (30, 548), (70, 536), (104, 530), (120, 538)]
    m = t.forma(espelho(lobo, cx)[:-1], (74, 96, 114), (40, 54, 72), expo=0.5, luz=0.08, contorno=contorno, larg=2.0)
    t.linha([(12, 552), (30, 545), (70, 533), (104, 527), (120, 535), (136, 527), (170, 533), (210, 545), (228, 552)],
            (214, 226, 232), 3.0, 0.8)
    # peitorais longas e claras (a marca da jubarte)
    for lado in (-1, 1):
        pts = [(cx + lado * 36, 196), (cx + lado * 62, 226), (cx + lado * 92, 276), (cx + lado * 110, 340),
               (cx + lado * 100, 362), (cx + lado * 88, 338), (cx + lado * 70, 300), (cx + lado * 48, 262),
               (cx + lado * 34, 232)]
        mf = t.forma(pts, (150, 172, 186), (218, 232, 238), expo=0.55, luz=0.1, contorno=contorno, larg=1.8)
        # nós na borda da frente
        for k in range(5):
            y = 252 + k * 20
            xx = cx + lado * (62 + k * 9.5)
            t.elipse(xx, y, 2.6, 2.6, (160, 182, 196), 0.9)
    # corpo
    ctrl = [(14, 0.0), (20, 14), (34, 28), (58, 38), (96, 46), (150, 51), (210, 52), (290, 48), (370, 38),
            (440, 24), (480, 12), (508, 7)]
    m = t.forma(corpo(ctrl, cx), flanco, dorso, expo=0.7, luz=0.24, contorno=contorno, larg=2.2)
    t.manchas(m, (92, 116, 134), 0.55, 9.0, 7)
    t.manchas(m, (22, 32, 46), 0.35, 5.0, 11)
    # cristas da cabeça, protuberâncias e sulcos da garganta (linhas finas)
    t.linha([(cx, 24), (cx, 96)], (110, 134, 150), 1.6, 0.5)
    for lado in (-1, 1):
        for k in range(5):
            t.elipse(cx + lado * (6 + k * 1.2), 34 + k * 12, 2.2, 2.2, (150, 172, 184), 0.75)
        t.linha([(cx + lado * 12, 110), (cx + lado * 20, 170), (cx + lado * 26, 240)], (96, 120, 138), 1.4, 0.5)
        t.elipse(cx + lado * 9, 112, 5.0, 1.4, (14, 22, 32), 0.95, ang=lado * 20)   # os dois respiradouros
        t.elipse(cx + lado * 30, 76, 3.0, 3.0, (10, 16, 26), 1.0)                   # olhos
    t.elipse(cx, 398, 8.0, 20.0, (40, 56, 74), 0.5)                                    # a corcova baixa
    t.salvar(os.path.join(IMG, "baleia.png"), W, H)


def main(previa=False):
    os.makedirs(IMG, exist_ok=True)
    peixe("peixe_topo_1.png", 40, 104, 1, (74, 104, 132), (190, 208, 218), listras=None, gordo=0.9)
    peixe("peixe_topo_2.png", 44, 108, 2, (198, 112, 52), (240, 190, 120), listras=None, gordo=1.15,
          cauda_cor=(214, 92, 44))
    peixe("peixe_topo_3.png", 40, 108, 3, (84, 118, 100), (196, 214, 190), listras=(32, 50, 46), gordo=0.95)
    peixe("peixe_topo_4.png", 42, 100, 4, (56, 72, 104), (150, 168, 196), listras=None, gordo=1.3,
          cauda_cor=(76, 92, 124))
    golfinho()
    baleia()
    print("animais gravados em", os.path.normpath(IMG))
    if previa:
        nomes = ["peixe_topo_%d.png" % i for i in range(1, 5)] + ["golfinho.png", "baleia.png"]
        ims = [Image.open(os.path.join(IMG, n)) for n in nomes]
        h = max(i.height for i in ims)
        folha = Image.new("RGBA", (sum(i.width for i in ims) + 20 * (len(ims) + 1), h + 40), (30, 90, 130, 255))
        x = 20
        for i in ims:
            folha.alpha_composite(i, (x, 20))
            x += i.width + 20
        folha.convert("RGB").save(os.path.join(AQUI, "previa_animais.png"))


if __name__ == "__main__":
    main("--previa" in sys.argv)
