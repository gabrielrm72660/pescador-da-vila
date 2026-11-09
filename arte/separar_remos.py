"""Separa os remos do sprite do barco, para o jogo poder remar de verdade.

Lê jogo/imagens/barco_*.png (já alinhados por cortar_arte.py) e grava:
  - remo_esq.png, remo_dir.png     cada remo sozinho, com fundo transparente;
  - barco_*_sr.png                 o barco "sem remos" (o casco refeito por cima de onde eles estavam);
  - meta.json["remos"]             pivô (onde o remo gira, no cavado do casco) e a ponta da pá.
Uso:  python arte/separar_remos.py [--previa]
Precisa de numpy, opencv-python (cv2), scipy e Pillow: é só para gerar os arquivos, o jogo não usa.
"""
import json
import math
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

AQUI = os.path.dirname(os.path.abspath(__file__))
IMG = os.path.join(AQUI, "..", "jogo", "imagens")
VARIANTES = ("barco_base", "barco_ferro", "barco_danificado", "barco_lanterna", "barco_vela")

# eixo de cada remo no sprite do barco (240 x 372): da mão do remador até a ponta da pá
# (x, y) em px do sprite; "pivo" = ponto do eixo (0 a 1) onde o remo apoia no casco (o toleteiro)
REMOS = {
    "esq": {"a": (80.0, 192.0), "b": (18.0, 272.0), "pivo": 0.46},
    "dir": {"a": (160.0, 192.0), "b": (227.0, 268.0), "pivo": 0.46},
}


def poligono(a, b, folga=2.0):
    """Cápsula ao longo do eixo a->b: cabo fino, pá larga na ponta."""
    ax, ay = a
    bx, by = b
    L = math.hypot(bx - ax, by - ay)
    dx, dy = (bx - ax) / L, (by - ay) / L
    nx, ny = -dy, dx
    perfil = [(0.0, 4.5), (0.50, 5.0), (0.70, 6.5), (0.80, 10.5), (1.0, 11.5)]
    lado1, lado2 = [], []
    for t, w in perfil:
        w += folga
        x, y = ax + dx * L * t, ay + dy * L * t
        lado1.append((x + nx * w, y + ny * w))
        lado2.append((x - nx * w, y - ny * w))
    ponta = [(bx + dx * (folga + 1.5) + nx * 6, by + dy * (folga + 1.5) + ny * 6),
             (bx + dx * (folga + 3.0), by + dy * (folga + 3.0)),
             (bx + dx * (folga + 1.5) - nx * 6, by + dy * (folga + 1.5) - ny * 6)]
    return np.array(lado1 + ponta + lado2[::-1], np.int32)


def mascara(h, w, poli):
    m = np.zeros((h, w), np.uint8)
    cv2.fillPoly(m, [poli], 255)
    return m


def sem_remos(rgba, mask):
    """Refaz o casco por cima do remo: alfa e cor, nesta ordem."""
    h, w = mask.shape
    rgb = rgba[:, :, :3].copy()
    alfa = rgba[:, :, 3].copy()
    # a cor dos pixels transparentes não pode contaminar a reconstrução
    _, idx = ndimage.distance_transform_edt(alfa < 128, return_indices=True)
    rgb = rgb[idx[0], idx[1]]
    # só o remo some: onde havia remo, o alfa vem do que está em volta
    m = (mask > 0).astype(np.uint8) * 255
    novo_alfa = cv2.inpaint(alfa, m, 6, cv2.INPAINT_TELEA)
    novo_alfa = np.where(novo_alfa > 127, 255, 0).astype(np.uint8)
    novo_rgb = cv2.inpaint(rgb, m, 6, cv2.INPAINT_TELEA)
    saida = np.dstack([novo_rgb, novo_alfa])
    saida[:, :, :3][novo_alfa == 0] = 0
    return saida


def main(previa=False):
    base = np.array(Image.open(os.path.join(IMG, "barco_base.png")).convert("RGBA"))
    h, w = base.shape[:2]
    meta_remos = {}
    mascaras = {}
    for lado, d in REMOS.items():
        mascaras[lado] = mascara(h, w, poligono(d["a"], d["b"]))
    for lado, d in REMOS.items():
        m = mascaras[lado]
        recorte = base.copy()
        recorte[:, :, 3] = np.where(m > 0, base[:, :, 3], 0)
        ys, xs = np.where(recorte[:, :, 3] > 0)
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        img = recorte[y0:y1, x0:x1]
        Image.fromarray(img).save(os.path.join(IMG, "remo_%s.png" % lado))
        ax, ay = d["a"]
        bx, by = d["b"]
        px, py = ax + (bx - ax) * d["pivo"], ay + (by - ay) * d["pivo"]
        meta_remos[lado] = {"arq": "remo_%s" % lado, "pivo_img": [round(px - x0, 1), round(py - y0, 1)],
                            "pivo": [round(px, 1), round(py, 1)], "ponta": [bx, by],
                            "w": int(x1 - x0), "h": int(y1 - y0)}
    # a máscara do apagador é mais gorda que a do remo: leva junto o contorno escuro e as farpas
    mtotal = np.zeros((h, w), np.uint8)
    for lado, d in REMOS.items():
        mtotal |= mascara(h, w, poligono(d["a"], d["b"], folga=6.0))
    mtotal = cv2.dilate(mtotal, np.ones((3, 3), np.uint8))
    for nome in VARIANTES:
        arq = os.path.join(IMG, nome + ".png")
        if not os.path.isfile(arq):
            continue
        rgba = np.array(Image.open(arq).convert("RGBA"))
        Image.fromarray(sem_remos(rgba, mtotal)).save(os.path.join(IMG, nome + "_sr.png"))
        print("ok", nome + "_sr.png")
    caminho = os.path.join(IMG, "meta.json")
    meta = json.load(open(caminho)) if os.path.isfile(caminho) else {}
    meta["remos"] = meta_remos
    with open(caminho, "w") as f:
        json.dump(meta, f)
    print("remos:", json.dumps(meta_remos))
    if previa:
        fundo = Image.new("RGBA", (w * 3 + 20, h), (30, 90, 130, 255))
        for i, nome in enumerate(("barco_base", "barco_base_sr", "barco_ferro_sr")):
            fundo.alpha_composite(Image.open(os.path.join(IMG, nome + ".png")).convert("RGBA"), (i * (w + 10), 0))
        fundo.convert("RGB").save(os.path.join(AQUI, "previa_remos.png"))


if __name__ == "__main__":
    main("--previa" in sys.argv)
