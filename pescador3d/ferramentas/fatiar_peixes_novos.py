#!/usr/bin/env python3
"""Fatia a folha dos peixes novos da v0.6.0 (Cioba, Olho-de-boi, Peixe-lua), feita no SpriteCook.

Entrada: arte_original/spritecook/novos_v060.png — grade 3x2 em fundo branco:
  linha de cima  = os três de lado (cabeça para a esquerda)  -> assets/texturas/peixes/porao/
  linha de baixo = os três vistos de cima (cabeça para cima) -> assets/texturas/peixes/cima/
  colunas: cioba, olho_de_boi, peixe_lua
Uso:  python3 ferramentas/fatiar_peixes_novos.py
"""
import sys
import pathlib
import numpy as np
from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import fatiar_peixes as F

NOMES = ["cioba", "olho_de_boi", "peixe_lua"]


def main():
    arq = F.FONTE / "novos_v060.png"
    rgb = np.array(Image.open(arq).convert("RGB"))
    fg = F.mascara_fundo_branco(rgb)
    rot, st, ids = F.achar(fg, 10, 6)
    if len(ids) != 6:
        raise SystemExit("achei %d peixes, esperava 6" % len(ids))
    ordem = F.ordenar(st, ids, [3, 3])
    for k, i in enumerate(ordem):
        nome = NOMES[k % 3]
        if k < 3:
            tam = F.recortar_salvar(rgb, fg & (rot == i), F.PORAO / (nome + ".png"), F.LADO_MAX)
            print("lado  %-12s %dx%d" % (nome, tam[0], tam[1]))
        else:
            tam = F.recortar_salvar(rgb, fg & (rot == i), F.CIMA / (nome + ".png"), F.CIMA_MAX)
            print("cima  %-12s %dx%d" % (nome, tam[0], tam[1]))


if __name__ == "__main__":
    main()
