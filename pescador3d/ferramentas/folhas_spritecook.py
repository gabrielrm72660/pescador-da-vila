#!/usr/bin/env python3
"""v0.9.3: monta o atlas das cartas de folha das árvores de Noronha (assets/texturas/ilha/folhas.png).

Entrada: as folhas do SpriteCook em arte_original/spritecook/v093/ (cada uma com 4 cachos separados, fundo transparente):
    folhas_castanhola.png, folhas_gameleira.png, folhas_mulungu.png, folhas_leucena.png  -> cinza (o jogo tinge)
    folhas_destaque.png  -> colorida: em cima 2 cachos de folha vermelha, embaixo 2 de flor de mulungu
Saída: atlas 1024 x 1280, 4 colunas x 5 linhas de 256 px (a ordem das linhas é a de LINHA em scripts/vegetacao_tropical.gd).

Cada cacho é achado pela transparência (componentes ligados), recortado, centrado numa célula quadrada com folga e
reduzido. A cor das bordas é "espalhada" para dentro do transparente (senão o mipmap faz um contorno escuro).
As linhas cinzas são normalizadas para média ~0,62 (o shader multiplica pela cor do vértice e por 1,25).

Uso:  python3 ferramentas/folhas_spritecook.py              (precisa de numpy, opencv-python e Pillow)
      python3 ferramentas/folhas_spritecook.py --provisorio  (desenha cachos por código, só para testar sem o SpriteCook)
"""
import os
import sys
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ORIGEM = os.path.join(RAIZ, "arte_original", "spritecook", "v093")
SAIDA = os.path.join(RAIZ, "assets", "texturas", "ilha", "folhas.png")
CEL = 256
LINHAS = ["castanhola", "gameleira", "mulungu", "leucena", "destaque"]


def cachos(img: np.ndarray, n: int = 4) -> list:
    """Os n maiores pedaços opacos da folha, em ordem de leitura (linha de cima primeiro, esquerda para a direita)."""
    a = img[:, :, 3]
    mascara = (a > 40).astype(np.uint8)
    mascara = cv2.dilate(mascara, np.ones((15, 15), np.uint8))     # junta folhas soltas do mesmo cacho
    qtd, rotulos, stats, cent = cv2.connectedComponentsWithStats(mascara, 8)
    pedacos = sorted(range(1, qtd), key=lambda i: -stats[i, cv2.CC_STAT_AREA])[:n]
    meio_y = img.shape[0] / 2
    pedacos.sort(key=lambda i: (cent[i][1] > meio_y, cent[i][0]))
    saida = []
    for i in pedacos:
        x, y, w, h = stats[i, :4]
        recorte = img[y:y + h, x:x + w].copy()
        recorte[:, :, 3] = np.where(rotulos[y:y + h, x:x + w] == i, recorte[:, :, 3], 0)
        saida.append(recorte)
    return saida


def celula(recorte: np.ndarray) -> np.ndarray:
    h, w = recorte.shape[:2]
    lado = int(max(h, w) * 1.06)
    quad = np.zeros((lado, lado, 4), np.uint8)
    oy, ox = (lado - h) // 2, (lado - w) // 2
    quad[oy:oy + h, ox:ox + w] = recorte
    return cv2.resize(quad, (CEL, CEL), interpolation=cv2.INTER_AREA)


def espalhar_cor(img: np.ndarray) -> np.ndarray:
    """Preenche o RGB do transparente com a cor do vizinho opaco mais perto (evita contorno escuro no mipmap)."""
    a = img[:, :, 3]
    opaco = a > 20
    if not opaco.any():
        return img
    rgb = img[:, :, :3].astype(np.float32)
    peso = opaco.astype(np.float32)
    soma = rgb * peso[:, :, None]
    for _ in range(6):
        soma = cv2.blur(soma, (9, 9))
        peso_b = cv2.blur(peso, (9, 9))
        cor = soma / np.maximum(peso_b[:, :, None], 1e-4)
        rgb = np.where(opaco[:, :, None], rgb, cor)
        soma = rgb * np.maximum(peso_b, peso)[:, :, None]
        peso = np.maximum(peso_b, peso)
    out = img.copy()
    out[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    return out


def normalizar_cinza(cel: np.ndarray, media: float = 0.62) -> np.ndarray:
    a = cel[:, :, 3] > 100
    if not a.any():
        return cel
    cinza = cv2.cvtColor(cel[:, :, :3], cv2.COLOR_RGB2GRAY).astype(np.float32) / 255.0
    m = float(cinza[a].mean())
    cinza = np.clip(cinza * (media / max(m, 0.05)), 0, 1)
    out = cel.copy()
    for c in range(3):
        out[:, :, c] = (cinza * 255).astype(np.uint8)
    return out


def provisorio(nome: str) -> list:
    """Cachos desenhados por código (elipses de folha), só para testar o jogo antes das folhas do SpriteCook."""
    rng = np.random.default_rng(LINHAS.index(nome) + 7)
    saida = []
    for k in range(4):
        im = Image.new("RGBA", (300, 300), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        n = {"castanhola": 9, "gameleira": 28, "mulungu": 12, "leucena": 60, "destaque": 8}[nome]
        tam = {"castanhola": 70, "gameleira": 28, "mulungu": 45, "leucena": 14, "destaque": 50}[nome]
        for i in range(n):
            ang = rng.uniform(0, np.pi * 2)
            r = rng.uniform(0, 100)
            cx, cy = 150 + np.cos(ang) * r, 150 + np.sin(ang) * r * 0.8
            if nome == "destaque":
                cor = (200, 70, 40, 255) if k < 2 else (230, 100, 40, 255)
            else:
                v = int(rng.uniform(110, 230))
                cor = (v, v, v, 255)
            folha = Image.new("RGBA", (tam * 2, tam), (0, 0, 0, 0))
            ImageDraw.Draw(folha).ellipse((0, 0, tam * 2 - 1, tam - 1), fill=cor)
            folha = folha.rotate(rng.uniform(0, 360), expand=True)
            im.alpha_composite(folha, (int(cx - folha.width / 2), int(cy - folha.height / 2)))
        saida.append(np.array(im.filter(ImageFilter.SMOOTH)))
    return saida


def main() -> None:
    falso = "--provisorio" in sys.argv
    atlas = np.zeros((CEL * len(LINHAS), CEL * 4, 4), np.uint8)
    for li, nome in enumerate(LINHAS):
        if falso:
            pedacos = provisorio(nome)
        else:
            arq = os.path.join(ORIGEM, "folhas_%s.png" % nome)
            img = np.array(Image.open(arq).convert("RGBA"))
            pedacos = cachos(img)
            if len(pedacos) < 4:
                print("aviso: %s tem só %d cachos; repetindo" % (nome, len(pedacos)))
                pedacos = (pedacos * 4)[:4]
        for ci, ped in enumerate(pedacos[:4]):
            cel = celula(ped)
            if nome != "destaque":
                cel = normalizar_cinza(cel)
            atlas[li * CEL:(li + 1) * CEL, ci * CEL:(ci + 1) * CEL] = cel
    atlas = espalhar_cor(atlas)
    Image.fromarray(atlas).save(SAIDA)
    print("ok", SAIDA, atlas.shape, "(provisório)" if falso else "")


if __name__ == "__main__":
    main()
