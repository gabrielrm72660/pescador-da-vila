#!/usr/bin/env python3
"""Pinta, por código, os mapas de detalhe da folhagem (em tons de cinza, para multiplicar a cor de cada vértice):

  assets/texturas/ilha/copa.png       copa de árvore e arbustos: cachos de folhas (ladrilho contínuo, 256x256)
  assets/texturas/ilha/palmeira.png   atlas 512x1024: folha de coqueiro em "pena" (com transparência) + faixa de casca

Se existir uma folha de texturas do SpriteCook (arte_original/spritecook/folhagem.png), use ferramentas/fatiar_folhagem.py,
que refaz copa.png a partir dela; a palmeira continua vindo daqui (a transparência precisa ser desenhada).

Uso:  python3 ferramentas/gerar_folhagem.py        (precisa de numpy e opencv-python)
"""
import os
import cv2
import numpy as np

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SAIDA = os.path.join(RAIZ, "assets", "texturas", "ilha")
rng = np.random.default_rng(2026)


def copa(n=256, folhas=520):
    """Cachos de folhas ovais sobrepostas; o fundo escuro aparece entre elas. Ladrilha nas quatro bordas."""
    img = np.full((n, n), 0.42, np.float32)
    for _ in range(folhas):
        cx, cy = rng.uniform(0, n, 2)
        a = rng.uniform(9, 20)            # semi-eixo maior
        b = a * rng.uniform(0.38, 0.6)
        ang = rng.uniform(0, 180)
        tom = rng.uniform(0.62, 1.12)
        for dx in (-n, 0, n):             # desenha também do outro lado da borda
            for dy in (-n, 0, n):
                x, y = cx + dx, cy + dy
                if -a * 2 < x < n + a * 2 and -a * 2 < y < n + a * 2:
                    camada = np.zeros((n, n), np.float32)
                    cv2.ellipse(camada, (int(x), int(y)), (int(a), int(b)), ang, 0, 360, 1.0, -1, cv2.LINE_AA)
                    # miolo mais claro, nervura central escura
                    miolo = np.zeros((n, n), np.float32)
                    cv2.ellipse(miolo, (int(x), int(y)), (int(a * 0.6), int(b * 0.5)), ang, 0, 360, 1.0, -1, cv2.LINE_AA)
                    rad = np.deg2rad(ang)
                    p0 = (int(x - np.cos(rad) * a * 0.9), int(y - np.sin(rad) * a * 0.9))
                    p1 = (int(x + np.cos(rad) * a * 0.9), int(y + np.sin(rad) * a * 0.9))
                    nerv = np.zeros((n, n), np.float32)
                    cv2.line(nerv, p0, p1, 1.0, 1, cv2.LINE_AA)
                    valor = tom * (0.86 + 0.20 * miolo) - 0.22 * nerv
                    img = img * (1 - camada) + valor * camada
    img = cv2.GaussianBlur(img, (0, 0), 0.8)
    img = img / np.percentile(img, 97)     # os claros chegam a 1 sem estourar; no jogo o material compensa o escurecimento
    return np.clip(img, 0.0, 1.0)


def palmeira(W=512, H=1024, regiao_folha=896):
    """Folha em pena: espinha no meio (x = W/2), folíolos para os dois lados, apontando para a ponta (topo da imagem).
    O mapa é esticado na folha do jogo (1,5 m de largura x ~3,5 m de comprimento), então o ângulo já vem compensado.
    Embaixo, uma faixa de casca com anéis horizontais (o tronco usa só essa faixa)."""
    rgb = np.zeros((H, W), np.float32)
    alfa = np.zeros((H, W), np.float32)
    meio = W // 2
    n = 34
    for i in range(n):
        t = i / (n - 1)
        y0 = regiao_folha - 6 - t * (regiao_folha - 40)             # da base (embaixo) à ponta (em cima)
        # comprimento do folíolo: curto na base e na ponta, longo no meio
        comp = (0.55 + 0.45 * np.sin(np.pi * min(1.0, t * 0.92 + 0.05))) * (meio - 6)
        for lado in (-1, 1):
            tom = rng.uniform(0.74, 1.06)
            dx = lado * comp
            dy = -comp * 0.52 * rng.uniform(0.9, 1.1)               # sobe em direção à ponta
            ax, ay = meio, y0
            bx, by = meio + dx, y0 + dy
            # folíolo: faixa contínua afinando até a ponta
            passos = 40
            anterior = (ax, ay)
            for s_ in range(1, passos + 1):
                u = s_ / passos
                cx = ax + (bx - ax) * u
                cy = ay + (by - ay) * u + 6.0 * np.sin(np.pi * u)   # leve curva
                esp = max(1, int(round(23.0 * (1.0 - u * 0.86))))
                ponto = (int(cx), int(cy))
                cv2.line(alfa, (int(anterior[0]), int(anterior[1])), ponto, 1.0, esp, cv2.LINE_AA)
                cv2.line(rgb, (int(anterior[0]), int(anterior[1])), ponto, tom * (1.05 - 0.2 * u), esp, cv2.LINE_AA)
                anterior = (cx, cy)
    cv2.line(alfa, (meio, regiao_folha), (meio, 0), 1.0, 7, cv2.LINE_AA)           # espinha
    cv2.line(rgb, (meio, regiao_folha), (meio, 0), 0.62, 5, cv2.LINE_AA)
    # faixa de casca (opaca)
    casca = np.zeros((H - regiao_folha, W), np.float32)
    h = casca.shape[0]
    for y in range(h):
        casca[y, :] = 0.86 + 0.14 * np.sin(y / h * np.pi * 6)        # anéis
    casca += rng.normal(0, 0.06, casca.shape).astype(np.float32)
    for _ in range(260):                                             # fibras verticais finas
        x = int(rng.integers(0, W))
        cv2.line(casca, (x, 0), (x + int(rng.integers(-3, 4)), h), float(rng.uniform(0.6, 0.95)), 1, cv2.LINE_AA)
    casca = cv2.GaussianBlur(casca, (0, 0), 0.7)
    rgb[regiao_folha:, :] = np.clip(casca, 0.35, 1.0)
    alfa[regiao_folha:, :] = 1.0
    # fora dos folíolos a cor se estende (evita franja escura quando a textura é suavizada)
    mascara = (alfa[:regiao_folha] > 0.5).astype(np.uint8)
    dist = cv2.distanceTransform(1 - mascara, cv2.DIST_L2, 3)
    sujo = cv2.GaussianBlur(rgb[:regiao_folha] * mascara, (0, 0), 6) / np.maximum(cv2.GaussianBlur(mascara.astype(np.float32), (0, 0), 6), 1e-3)
    rgb[:regiao_folha] = np.where(mascara > 0, rgb[:regiao_folha], np.clip(sujo, 0.4, 1.0))
    rgb = rgb / max(rgb[alfa > 0.5].mean(), 1e-3) * 0.92
    return np.clip(rgb, 0, 1), alfa


if __name__ == "__main__":
    os.makedirs(SAIDA, exist_ok=True)
    c = copa()
    cv2.imwrite(os.path.join(SAIDA, "copa.png"), (c * 255).astype(np.uint8))
    rgb, alfa = palmeira()
    g = (rgb * 255).astype(np.uint8)
    rgba = np.dstack([g, g, g, (alfa * 255).astype(np.uint8)])
    cv2.imwrite(os.path.join(SAIDA, "palmeira.png"), rgba)
    print("ok copa.png e palmeira.png em", os.path.normpath(SAIDA))
