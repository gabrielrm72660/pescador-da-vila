#!/usr/bin/env python3
"""v0.7.8: texturas do barco "Pesqueiro de Alto-Mar" pintadas no SpriteCook (originais em arte_original/spritecook/v078/)
-> assets/barco/altomar/{casco,cabine,teto}.png (1024, emenda garantida) e porta.png (576x1024), cada uma com
<nome>_normal.png gerada da luminância (as frestas entre tábuas e as almofadas da porta viram relevo de verdade na luz).
Uso: python3 ferramentas/barco_altomar.py"""
import pathlib
import numpy as np
from PIL import Image, ImageFilter

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORIG = RAIZ / "arte_original" / "spritecook" / "v078"
DEST = RAIZ / "assets" / "barco" / "altomar"


def ladrilhar(img, faixa=64):
    a = np.array(img.convert("RGB")).astype(np.float32)
    h, w, _ = a.shape
    r = np.roll(np.roll(a, w // 2, 1), h // 2, 0)
    pesos = np.ones((h, w), np.float32)
    for eixo, n in ((0, h), (1, w)):
        p = np.clip(np.abs(np.arange(n) - n / 2.0) / faixa, 0.0, 1.0)
        pesos *= p[:, None] if eixo == 0 else p[None, :]
    return Image.fromarray(np.clip(a * pesos[..., None] + r * (1 - pesos[..., None]), 0, 255).astype(np.uint8))


def normal(img, forca, borrao=1.2, repetir=True):
    g = np.array(img.convert("L").filter(ImageFilter.GaussianBlur(borrao))).astype(np.float32) / 255.0
    if repetir:
        dx = (np.roll(g, -1, 1) - np.roll(g, 1, 1)) * 0.5
        dy = (np.roll(g, -1, 0) - np.roll(g, 1, 0)) * 0.5
    else:
        dx = np.gradient(g, axis=1); dy = np.gradient(g, axis=0)
    n = np.dstack([-dx * forca, dy * forca, np.ones_like(g)])      # OpenGL (Y para cima), como o Godot espera
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for nome, forca in (("casco", 6.0), ("cabine", 7.0), ("teto", 5.0)):
        img = ladrilhar(Image.open(ORIG / (nome + ".png")).convert("RGB").resize((1024, 1024), Image.LANCZOS))
        img.save(DEST / (nome + ".png"), optimize=True)
        normal(img, forca).save(DEST / (nome + "_normal.png"), optimize=True)
        print(nome)
    porta = Image.open(ORIG / "porta.png").convert("RGB").resize((576, 1024), Image.LANCZOS)
    porta.save(DEST / "porta.png", optimize=True)
    normal(porta, 9.0, 1.5, False).save(DEST / "porta_normal.png", optimize=True)
    print("porta")


if __name__ == "__main__":
    main()
# (v0.7.8) assets/barco/altomar/nome_claro.png = estrela_dalva_nome.png com as letras em creme-claro (RGB 236,232,222),
# mesmo alfa, para ler sobre o casco azul-marinho; gerado à parte, uma vez.
