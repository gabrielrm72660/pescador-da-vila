#!/usr/bin/env python3
"""Fatia as folhas de peixes do SpriteCook em um PNG por espécie, com fundo transparente.

Entrada (arte_original/spritecook/):
  lado_a.png / lado_b.png   folhas de peixes de lado (9 espécies cada), fundo transparente
  cima_a.png / cima_b.png   folhas de peixes vistos de cima (9 cada), fundo branco
  <especie>_lado.png        peixes avulsos de lado, fundo branco (sardinha, tainha, xareu, cavala)
Saída:
  assets/texturas/peixes/porao/<especie>.png   ilustração lateral (porão e anel de pesca)
  assets/texturas/peixes/cima/<especie>.png    visto de cima, cabeça para cima (cardumes na água)

Uso:  python3 ferramentas/fatiar_peixes.py
Precisa de: pip install pillow numpy opencv-python scipy
"""
import pathlib
import numpy as np
import cv2
from PIL import Image
from scipy import ndimage

RAIZ = pathlib.Path(__file__).resolve().parent.parent
FONTE = RAIZ / "arte_original" / "spritecook"
PORAO = RAIZ / "assets" / "texturas" / "peixes" / "porao"
CIMA = RAIZ / "assets" / "texturas" / "peixes" / "cima"

# ordem de cada folha: linhas de cima para baixo, da esquerda para a direita
FOLHA_A = ["sardinha", "tainha", "xareu", "cavala", "barracuda", "dourado", "atum", "olho_de_cao", "garoupa"]
FOLHA_B = ["agulhao_vela", "peixe_voador", "budiao", "moreia", "arabaiana", "baiacu", "peixe_anjo", "robalo", "namorado"]
LINHAS_A = [3, 3, 3]
LINHAS_B = [3, 4, 2]          # a folha B saiu com 3 peixes na 1ª linha, 4 na 2ª e 2 na 3ª
AVULSOS = ["sardinha", "tainha", "xareu", "cavala"]   # versões maiores, já usadas no lugar das da folha A
LADO_MAX = 512
CIMA_MAX = 384


def elipse(r):
    return cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))


def mascara_fundo_branco(rgb, limiar=238):
    """Primeiro plano = tudo que não é o branco ligado às bordas da imagem."""
    candidato = (rgb.min(axis=2) >= limiar).astype(np.uint8)
    _, rot = cv2.connectedComponents(candidato, connectivity=4)
    borda = np.unique(np.concatenate([rot[0, :], rot[-1, :], rot[:, 0], rot[:, -1]]))
    borda = borda[borda > 0]
    return ~np.isin(rot, borda)


def acabar(rgb, fg):
    """Alfa suave e cores da borda trocadas pelas de dentro (sem halo branco nem do fundo removido)."""
    fg = fg.astype(np.uint8)
    solido = cv2.erode(fg, elipse(1))
    nucleo = cv2.erode(fg, elipse(2)).astype(bool)
    idx = ndimage.distance_transform_edt(~nucleo, return_distances=False, return_indices=True)
    cor = rgb[idx[0], idx[1]]
    cor[nucleo] = rgb[nucleo]
    alfa = cv2.GaussianBlur(solido.astype(np.float32), (0, 0), 0.8)
    alfa[cv2.dilate(solido, elipse(2)) == 0] = 0
    return np.dstack([cor, np.clip(alfa * 255.0, 0, 255).astype(np.uint8)])


def recortar_salvar(rgb, fg, destino, lado_max):
    ys, xs = np.where(fg)
    pad = 6
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad + 1, fg.shape[0])
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad + 1, fg.shape[1])
    rgba = acabar(rgb[y0:y1, x0:x1], fg[y0:y1, x0:x1])
    ys, xs = np.where(rgba[..., 3] > 8)
    rgba = rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    im = Image.fromarray(rgba, "RGBA")
    if max(im.size) > lado_max:
        k = lado_max / max(im.size)
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.LANCZOS)
    destino.parent.mkdir(parents=True, exist_ok=True)
    im.save(destino, optimize=True)
    return im.size


def achar(fg, dilatar, esperado):
    d = cv2.dilate(fg.astype(np.uint8), elipse(dilatar))
    n, rot, st, _ = cv2.connectedComponentsWithStats(d, connectivity=8)
    grandes = sorted(range(1, n), key=lambda i: -st[i, 4])[:esperado]
    return rot, st, grandes


def ordenar(st, ids, linhas):
    por_y = sorted(ids, key=lambda i: st[i, 1] + st[i, 3] / 2)
    saida, k = [], 0
    for n in linhas:
        saida += sorted(por_y[k:k + n], key=lambda i: st[i, 0] + st[i, 2] / 2)
        k += n
    return saida


def folha(arquivo, nomes, linhas, destino, lado_max, fundo_branco, dilatar):
    im = Image.open(FONTE / arquivo)
    if fundo_branco:
        rgb = np.array(im.convert("RGB"))
        fg = mascara_fundo_branco(rgb)
    else:
        a = np.array(im.convert("RGBA"))
        rgb, fg = a[..., :3], a[..., 3] > 128
    rot, st, ids = achar(fg, dilatar, len(nomes))
    if len(ids) != len(nomes):
        raise SystemExit("%s: achei %d peixes, esperava %d" % (arquivo, len(ids), len(nomes)))
    for nome, i in zip(nomes, ordenar(st, ids, linhas)):
        tam = recortar_salvar(rgb, fg & (rot == i), destino / (nome + ".png"), lado_max)
        print("%-34s %-14s %dx%d" % (arquivo, nome, tam[0], tam[1]))


def avulso(nome):
    rgb = np.array(Image.open(FONTE / (nome + "_lado.png")).convert("RGB"))
    fg = mascara_fundo_branco(rgb)
    rot, st, ids = achar(fg, 6, 1)
    tam = recortar_salvar(rgb, fg & (rot == ids[0]), PORAO / (nome + ".png"), LADO_MAX)
    print("%-34s %-14s %dx%d" % (nome + "_lado.png", nome, tam[0], tam[1]))


if __name__ == "__main__":
    folha("lado_a.png", FOLHA_A, LINHAS_A, PORAO, LADO_MAX, False, 10)
    folha("lado_b.png", FOLHA_B, LINHAS_B, PORAO, LADO_MAX, False, 3)
    folha("cima_a.png", FOLHA_A, LINHAS_A, CIMA, CIMA_MAX, True, 12)
    folha("cima_b.png", FOLHA_B, LINHAS_A, CIMA, CIMA_MAX, True, 12)    # de cima a folha B saiu em grade 3x3
    for nome in AVULSOS:
        avulso(nome)
