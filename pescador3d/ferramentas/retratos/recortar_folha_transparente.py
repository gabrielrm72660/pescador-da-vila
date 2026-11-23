#!/usr/bin/env python3
"""v0.7.5: recorta os 5 retratos da folha já sem fundo (arte_original/retratos/retratos_sem_fundo_v074.png).
A folha vem com um halo avermelhado quase transparente em volta das figuras e o miolo com alfa 253: aqui o miolo
vira opaco, o halo some, a cor da beirada é trocada pela do pixel opaco mais próximo (sem franja ao filtrar no jogo)
e cada figura é cortada, aparada e posta na altura dos retratos antigos (650 px).
Ordem na folha: Zefa, Jacinto, Toinho, Rosa, Abílio.   Uso: python3 ferramentas/retratos/recortar_folha_transparente.py"""
import pathlib
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

RAIZ = pathlib.Path(__file__).resolve().parent.parent.parent
FOLHA = RAIZ / "arte_original" / "retratos" / "retratos_sem_fundo_v074.png"
DEST = RAIZ / "assets" / "retratos"
NOMES = ["zefa", "jacinto", "toinho", "rosa", "abilio"]
ALTURA = 650

def limpar(img: Image.Image) -> Image.Image:
    A = np.array(img.convert("RGBA")).astype(np.float32)
    a = A[..., 3]
    # alfa: o halo fraco (< 60) some, o miolo (>= 235) fica opaco, a beirada entre os dois vira uma rampa
    novo = np.clip((a - 60.0) / (235.0 - 60.0), 0.0, 1.0)
    # tira farelos soltos (pontinhos do halo que passaram do limiar)
    figura = novo > 0.5
    rot, n = ndimage.label(figura)
    if n > 0:
        tam = ndimage.sum(figura, rot, range(1, n + 1))
        grandes = np.isin(rot, 1 + np.flatnonzero(tam > 400))
        perto = ndimage.binary_dilation(grandes, iterations=3)
        novo *= perto
    # cor da beirada = cor do pixel firme mais próximo (alfa >= 0.97), para não sobrar franja vermelha
    firme = novo >= 0.97
    _, (iy, ix) = ndimage.distance_transform_edt(~firme, return_indices=True)
    rgb = A[..., :3].copy()
    beirada = ~firme
    rgb[beirada] = A[..., :3][iy[beirada], ix[beirada]]
    # alfa levemente suavizado (meio pixel) para a borda não serrilhar
    alfa = Image.fromarray((novo * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))
    out = Image.fromarray(np.dstack([rgb.astype(np.uint8), np.array(alfa)]), "RGBA")
    return out

def colunas(a: np.ndarray) -> list:
    ocupada = (a > 60).any(0)
    seg, ini = [], None
    for x, v in enumerate(ocupada):
        if v and ini is None:
            ini = x
        if not v and ini is not None:
            seg.append((ini, x))
            ini = None
    if ini is not None:
        seg.append((ini, len(ocupada)))
    return [s for s in seg if s[1] - s[0] > 60]

def main():
    folha = Image.open(FOLHA).convert("RGBA")
    segs = colunas(np.array(folha)[..., 3])
    if len(segs) != len(NOMES):
        raise SystemExit("achei %d figuras, esperava %d" % (len(segs), len(NOMES)))
    for nome, (x0, x1) in zip(NOMES, segs):
        recorte = folha.crop((max(0, x0 - 6), 0, min(folha.width, x1 + 6), folha.height))
        limpo = limpar(recorte)
        caixa = limpo.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox()
        limpo = limpo.crop(caixa)
        k = ALTURA / limpo.height
        limpo = limpo.resize((round(limpo.width * k), ALTURA), Image.LANCZOS)
        limpo.save(DEST / (nome + ".png"), optimize=True)
        print(nome, limpo.size)

if __name__ == "__main__":
    main()
