#!/usr/bin/env python3
"""v0.8.7: peixes aberrantes (o que a bruma devolve quando o pescador fica tempo demais na noite).
Parte do desenho em guache de cada espécie (assets/texturas/peixes/porao/<slug>.png) e pinta por cima, no mesmo estilo:
  - as cores afundam num azul-escuro esverdeado, com a barriga pálida como osso;
  - manchas que brilham por dentro (verde-água), ao longo da linha lateral, como o peixe-lua do diário do Bento;
  - olhos a mais perto da cabeça (a cabeça fica do lado esquerdo do desenho).
Saída: assets/texturas/peixes/aberrante/<slug>.png (mesmo tamanho e mesmo alfa do original).
Uso: python3 ferramentas/peixes_aberrantes.py"""
import pathlib
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORIG = RAIZ / "assets" / "texturas" / "peixes" / "porao"
DEST = RAIZ / "assets" / "texturas" / "peixes" / "aberrante"

ESCURO = np.array([0.08, 0.11, 0.18])
MEIO = np.array([0.22, 0.42, 0.42])
OSSO = np.array([0.86, 0.84, 0.74])
BRILHO = np.array([0.55, 1.0, 0.85])


def gradiente(l):
    l = l[..., None]
    a = np.clip(l / 0.55, 0, 1)
    b = np.clip((l - 0.55) / 0.45, 0, 1)
    return ESCURO * (1 - a) + MEIO * a * (1 - b) + OSSO * b


def mancha(h, w, cy, cx, r):
    yy, xx = np.mgrid[0:h, 0:w]
    return np.exp(-(((yy - cy) ** 2 + (xx - cx) ** 2) / (2 * r * r)))


def aberrar(caminho, semente):
    rng = np.random.default_rng(semente)
    img = np.asarray(Image.open(caminho).convert("RGBA")).astype(np.float32) / 255.0
    rgb, a = img[..., :3], img[..., 3]
    h, w = a.shape
    corpo = a > 0.6
    if corpo.sum() < 50:
        return None
    lum = rgb @ np.array([0.30, 0.59, 0.11])
    novo = 0.78 * gradiente(lum) + 0.22 * rgb * np.array([0.55, 0.75, 0.85])
    # pincelada: um pouco de ruído grosso, para não ficar liso
    ruido = ndimage.gaussian_filter(rng.standard_normal((h, w)), 2.2)
    novo *= (1.0 + 0.10 * ruido / (np.abs(ruido).max() + 1e-6))[..., None]
    # linha lateral: a faixa do meio do corpo em cada coluna
    miolo = ndimage.binary_erosion(corpo, iterations=max(2, h // 20))
    cols = np.flatnonzero(miolo.any(axis=0))
    if len(cols) == 0:
        cols = np.flatnonzero(corpo.any(axis=0))
        miolo = corpo
    x0, x1 = cols.min(), cols.max()
    largura = x1 - x0
    luz = np.zeros((h, w))
    n_manchas = int(rng.integers(7, 12))
    for k in range(n_manchas):
        x = int(x0 + largura * rng.uniform(0.22, 0.92))
        ys = np.flatnonzero(miolo[:, x])
        if len(ys) == 0:
            continue
        y = int(ys.mean() + (ys.max() - ys.min()) * rng.uniform(-0.25, 0.25))
        r = max(2.0, h * rng.uniform(0.018, 0.035))
        luz += mancha(h, w, y, x, r) * rng.uniform(0.7, 1.0)
    luz = np.clip(luz, 0, 1)
    halo = ndimage.gaussian_filter(luz, h * 0.04) * 2.2
    novo = novo * (1 - 0.85 * luz[..., None]) + BRILHO * 0.85 * luz[..., None] + BRILHO * 0.25 * np.clip(halo, 0, 1)[..., None]
    # olhos a mais, perto da cabeça
    yy, xx = np.mgrid[0:h, 0:w]
    for k in range(int(rng.integers(2, 4))):
        x = int(x0 + largura * rng.uniform(0.10, 0.32))
        ys = np.flatnonzero(miolo[:, x])
        if len(ys) == 0:
            continue
        y = int(rng.uniform(ys.min() + (ys.max() - ys.min()) * 0.15, ys.max() - (ys.max() - ys.min()) * 0.15))
        r = max(2.5, h * rng.uniform(0.035, 0.055))
        d = np.sqrt((yy - y) ** 2 + (xx - x) ** 2)
        anel = (d < r * 1.25) & corpo
        novo[anel] = novo[anel] * 0.45                                            # sombra em volta
        branco = (d < r) & corpo
        novo[branco] = np.array([0.93, 0.92, 0.84]) * (0.85 + 0.15 * (1 - d[branco] / r))[..., None]
        pupila = (np.sqrt((yy - y) ** 2 + ((xx - x) * 1.6) ** 2) < r * 0.55) & corpo   # pupila vertical, de bicho
        novo[pupila] = np.array([0.03, 0.04, 0.05])
        brilho = (np.sqrt((yy - (y - r * 0.35)) ** 2 + (xx - (x - r * 0.3)) ** 2) < r * 0.18) & corpo
        novo[brilho] = np.array([0.95, 1.0, 0.95])
    out = np.dstack([np.clip(novo, 0, 1), a])
    return Image.fromarray((out * 255).astype(np.uint8), "RGBA")


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for i, arq in enumerate(sorted(ORIG.glob("*.png"))):
        img = aberrar(arq, 1000 + i * 17)
        if img is None:
            continue
        img.save(DEST / arq.name, optimize=True)
        print(arq.name)


if __name__ == "__main__":
    main()
