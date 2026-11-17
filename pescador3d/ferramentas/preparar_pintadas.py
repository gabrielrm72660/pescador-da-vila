"""Prepara texturas pintadas (feitas fora, por exemplo no SpriteCook) para o jogo.

Uso:  python ferramentas/preparar_pintadas.py [PASTA_DE_ORIGEM]      (sem pasta: usa arte_original/)
A pasta deve ter arquivos com o nome da textura (areia.png, telhas.png, conves.png, tabuas_pintadas.png...).
Para cada um: fecha a emenda (para repetir sem marca), grava em assets/texturas/ilha/ ou /barco/ e,
para as que usam relevo no jogo, cria um relevo bem suave a partir do claro-escuro da pintura.
Depois de mudar texturas do barco: python ferramentas/gerar_barco.py (elas ficam dentro do modelo).
"""
import os
import sys
import cv2
import numpy as np

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ILHA = os.path.join(RAIZ, "assets", "texturas", "ilha")
BARCO = os.path.join(RAIZ, "assets", "texturas", "barco")
TAMANHO = 1024
# nome do arquivo -> (pasta de destino, força do relevo ou None). O relevo é baixo de propósito:
# no estilo pintado a forma vem da cor, não do brilho.
DESTINOS = {
    "areia": (ILHA, None), "grama": (ILHA, None), "rocha": (ILHA, 2.2), "reboco": (ILHA, 1.0),
    "telhas": (ILHA, 2.6), "madeira": (ILHA, None),
    "conves": (BARCO, 1.6), "madeira_escura": (BARCO, 1.2), "metal": (BARCO, 1.0), "corda": (BARCO, 2.4),
}
# desenhos com fileiras (telhas, tábuas, corda): dissolver uma faixa larga borraria as fileiras
COM_FILEIRAS = {"telhas", "madeira", "conves", "madeira_escura", "corda", "tabuas_pintadas"}
# "tabuas_pintadas" é branca e vira todas as pinturas do barco, tingida com estas cores
PINTURAS = {
    "casco_branco": (0.93, 0.90, 0.84), "casco_vermelho": (0.62, 0.19, 0.14), "pintura_azul": (0.18, 0.38, 0.60),
    "pintura_laranja": (0.88, 0.43, 0.19), "pintura_creme": (0.93, 0.88, 0.76), "pintura_amarela": (0.90, 0.70, 0.22),
}


def fechar_emenda(img, faixa=96):
    """Corta uma faixa de cada lado e a dissolve na borda oposta: a imagem passa a repetir sem marca."""
    f = img.astype(np.float32)
    n = f.shape[1]
    t = np.linspace(0.0, 1.0, faixa, dtype=np.float32)[None, :, None]
    lado = f[:, :n - faixa].copy()
    lado[:, :faixa] = f[:, n - faixa:] * (1 - t) + f[:, :faixa] * t
    n = lado.shape[0]
    t = t.transpose(1, 0, 2)
    tudo = lado[:n - faixa].copy()
    tudo[:faixa] = lado[n - faixa:] * (1 - t) + lado[:faixa] * t
    return np.clip(cv2.resize(tudo, (TAMANHO, TAMANHO), interpolation=cv2.INTER_LANCZOS4), 0, 255).astype(np.uint8)


def emenda(img):
    f = img.astype(np.float32)
    borda = (np.abs(f[:, 0] - f[:, -1]).mean() + np.abs(f[0] - f[-1]).mean()) / 2
    dentro = (np.abs(f[:, 1:] - f[:, :-1]).mean() + np.abs(f[1:] - f[:-1]).mean()) / 2
    return borda / max(dentro, 0.01)


def relevo(img, forca):
    h = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY).astype(np.float32) / 255.0
    h = cv2.GaussianBlur(np.tile(h, (3, 3)), (0, 0), 2.5)[TAMANHO:2 * TAMANHO, TAMANHO:2 * TAMANHO]
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * forca
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * forca
    n = np.dstack([-dx, -dy, np.ones_like(h) * 0.25])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return cv2.resize(((n[..., ::-1] * 0.5 + 0.5) * 255).astype(np.uint8), (512, 512), interpolation=cv2.INTER_AREA)


def tingir(img, cor):
    """Pinta a textura branca com uma cor, guardando o claro-escuro das pinceladas."""
    f = img.astype(np.float32) / 255.0
    f = f / np.percentile(f, 92)                                   # o branco da tinta vira 1
    saida = f * np.array(cor[::-1], dtype=np.float32)[None, None, :]
    return (np.clip(saida, 0, 1) * 255).astype(np.uint8)


def preparar(origem):
    for arquivo in sorted(os.listdir(origem)):
        nome, ext = os.path.splitext(arquivo)
        if ext.lower() != ".png" or (nome not in DESTINOS and nome != "tabuas_pintadas"):
            continue
        img = cv2.imread(os.path.join(origem, arquivo), cv2.IMREAD_COLOR)
        antes = emenda(img)
        if antes > 1.25:
            img = fechar_emenda(img, 20 if nome in COM_FILEIRAS else 96)
        elif img.shape[0] != TAMANHO:
            img = cv2.resize(img, (TAMANHO, TAMANHO), interpolation=cv2.INTER_AREA)
        print("%-16s emenda %.2f -> %.2f" % (nome, antes, emenda(img)))
        if nome == "tabuas_pintadas":
            for pintura, cor in PINTURAS.items():
                cv2.imwrite(os.path.join(BARCO, pintura + ".png"), tingir(img, cor))
                cv2.imwrite(os.path.join(BARCO, pintura + "_normal.png"), relevo(img, 1.4))
            continue
        pasta, forca = DESTINOS[nome]
        cv2.imwrite(os.path.join(pasta, nome + ".png"), img)
        if forca is not None:
            cv2.imwrite(os.path.join(pasta, nome + "_normal.png"), relevo(img, forca))


if __name__ == "__main__":
    preparar(sys.argv[1] if len(sys.argv) > 1 else os.path.join(RAIZ, "arte_original"))
    print("Pronto. Se mudou textura do barco, rode: python ferramentas/gerar_barco.py")
