#!/usr/bin/env python3
"""v0.7.6: prepara os retratos gerados um a um no SpriteCook (arte_original/retratos/spritecook_v076/*.png, 1152x2048
com fundo transparente) para o jogo:
  - o halo quase invisível que o recorte do SpriteCook deixa em volta (alfa 1..30) some;
  - o miolo fica opaco e a beirada vira uma rampa curta, com a cor do pixel firme mais próximo (sem franja ao filtrar);
  - farelos soltos longe da figura somem;
  - corta na figura e põe na altura dos retratos (650 px; diário 560 px).
O Bento é fantasma: a bruma que sai da cintura é semitransparente de propósito, então a rampa dele começa mais baixo.
Uso: python3 ferramentas/retratos/preparar_spritecook.py"""
import pathlib
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

RAIZ = pathlib.Path(__file__).resolve().parent.parent.parent
ORIGEM = RAIZ / "arte_original" / "retratos" / "spritecook_v076"
DEST = RAIZ / "assets" / "retratos"
#           nome       altura  alfa_min alfa_max
RETRATOS = [("zefa", 650, 40, 220), ("jacinto", 650, 40, 220), ("toinho", 650, 40, 220), ("rosa", 650, 40, 220),
            ("abilio", 650, 40, 220), ("bento", 660, 14, 200), ("diario", 560, 40, 220)]


def limpar(img: Image.Image, a0: float, a1: float) -> Image.Image:
    A = np.array(img.convert("RGBA")).astype(np.float32)
    a = A[..., 3]
    novo = np.clip((a - a0) / (a1 - a0), 0.0, 1.0)
    # farelos: só fica o que está colado nas manchas grandes
    figura = novo > 0.35
    rot, n = ndimage.label(figura)
    if n > 0:
        tam = ndimage.sum(figura, rot, range(1, n + 1))
        grandes = np.isin(rot, 1 + np.flatnonzero(tam > 1500))
        novo *= ndimage.binary_dilation(grandes, iterations=6)
    firme = novo >= 0.97
    _, (iy, ix) = ndimage.distance_transform_edt(~firme, return_indices=True)
    rgb = A[..., :3].copy()
    beira = (~firme) & (novo > 0.0)
    # na beirada, mistura a cor original com a do pixel firme vizinho (mais firme -> mais da própria cor)
    viz = A[..., :3][iy, ix]
    peso = novo[..., None]
    rgb[beira] = (rgb * peso + viz * (1.0 - peso))[beira]
    rgb[novo <= 0.0] = viz[novo <= 0.0]
    alfa = Image.fromarray((novo * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.array(alfa)]), "RGBA")


def main():
    for nome, altura, a0, a1 in RETRATOS:
        img = Image.open(ORIGEM / (nome + ".png"))
        limpo = limpar(img, a0, a1)
        caixa = limpo.split()[3].point(lambda v: 255 if v > 6 else 0).getbbox()
        limpo = limpo.crop(caixa)
        k = altura / limpo.height
        limpo = limpo.resize((round(limpo.width * k), altura), Image.LANCZOS)
        limpo.save(DEST / (nome + ".png"), optimize=True)
        print(nome, limpo.size)


if __name__ == "__main__":
    main()
