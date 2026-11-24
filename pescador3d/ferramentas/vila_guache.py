#!/usr/bin/env python3
"""v0.8.5: texturas em guache das casas da vila, pintadas no SpriteCook (originais e prompts em arte_original/spritecook/v085/).
  reboco.png   -> assets/texturas/ilha/reboco.png (+ _normal): parede caiada, clara e pouco saturada (a cor da casa tinge)
  telhas.png   -> assets/texturas/ilha/telhas.png (+ _normal): telha colonial; recortada nas juntas (11 x 7 telhas) para emendar
  madeira.png  -> assets/texturas/ilha/madeira_pintada.png (+ _normal): portas e janelas (a cor do vértice tinge);
                  recortada nas frestas (11 tábuas). O cais continua com madeira.png (madeira crua).
Uso: python3 ferramentas/vila_guache.py"""
import pathlib
import numpy as np
from PIL import Image, ImageFilter

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORIG = RAIZ / "arte_original" / "spritecook" / "v085"
DEST = RAIZ / "assets" / "texturas" / "ilha"


def emendar(a, faixa, eixos=(0, 1)):
    """Funde as bordas com a imagem deslocada de meia volta (só nos eixos pedidos): emenda sem costura."""
    h, w, _ = a.shape
    r = a
    pesos = np.ones((h, w), np.float32)
    if 1 in eixos:
        r = np.roll(r, w // 2, 1)
        p = np.clip(np.abs(np.arange(w) - w / 2.0) / faixa, 0.0, 1.0)
        pesos *= p[None, :]
    if 0 in eixos:
        r = np.roll(r, h // 2, 0)
        p = np.clip(np.abs(np.arange(h) - h / 2.0) / faixa, 0.0, 1.0)
        pesos *= p[:, None]
    # onde o peso é 1 fica o original; perto das bordas entra a versão deslocada (cujo miolo é contínuo)
    return a * pesos[..., None] + r * (1.0 - pesos[..., None])


def saturacao(a, fator):
    cinza = a.mean(axis=2, keepdims=True)
    return cinza + (a - cinza) * fator


def normal(img, forca, borrao=1.2):
    g = np.array(img.convert("L").filter(ImageFilter.GaussianBlur(borrao))).astype(np.float32) / 255.0
    dx = (np.roll(g, -1, 1) - np.roll(g, 1, 1)) * 0.5
    dy = (np.roll(g, -1, 0) - np.roll(g, 1, 0)) * 0.5
    n = np.dstack([-dx * forca, dy * forca, np.ones_like(g)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def salvar(a, nome, forca):
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB").resize((1024, 1024), Image.LANCZOS)
    img.save(DEST / (nome + ".png"), optimize=True)
    normal(img, forca).resize((512, 512), Image.LANCZOS).save(DEST / (nome + "_normal.png"), optimize=True)
    m = np.asarray(img).reshape(-1, 3).mean(0) / 255
    print(nome, "média", m.round(2))


def main():
    abrir = lambda n: np.asarray(Image.open(ORIG / (n + ".png")).convert("RGB")).astype(np.float32)
    # reboco: quase emendado de fábrica; tira 40% da saturação para a cor da casa mandar
    a = saturacao(abrir("reboco"), 0.6)
    a = a * (0.92 / (a.mean() / 255.0))
    salvar(emendar(a, 64), "reboco", 3.0)
    # telhas: corta nas juntas (colunas 77..1021 = 11 telhas; fileiras 51..907 = 7) e tira 10% da saturação
    a = saturacao(abrir("telhas")[51:907, 77:1021], 0.9)
    salvar(a, "telhas", 6.0)
    # madeira das portas e janelas: corta nas frestas (83..1022 = 11 tábuas); emenda só na vertical
    a = abrir("madeira")[:, 83:1022]
    salvar(emendar(a, 48, eixos=(0,)), "madeira_pintada", 5.0)


if __name__ == "__main__":
    main()
