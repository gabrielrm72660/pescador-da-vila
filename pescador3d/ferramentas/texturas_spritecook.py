#!/usr/bin/env python3
"""v0.7.6: põe no formato do jogo as texturas pintadas no SpriteCook (originais em arte_original/spritecook/v076/):

  barranco.png  (1024, colorida)   -> assets/texturas/ilha/barranco.png   encosta de terra; o terreno já procurava esse arquivo
  copa.png      (1024, colorida)   -> assets/texturas/ilha/copa.png       256x256 em cinza (multiplica a cor de cada vértice)
  folha.png     (1152x2048, alfa)  -+
  casca.png     (1024, colorida)   -+-> assets/texturas/ilha/palmeira.png  atlas 512x1024 em cinza: folha em pena com alfa
                                                                          nas linhas 0..895 (espinha em x=256, ponta em cima)
                                                                          e faixa de casca opaca nas linhas 896..1023
  icone.png     (1024, colorida)   -> assets/marca/icone.png (512, cantos arredondados) e icone_cheio.png (432, para o
                                      ícone adaptável do Android, que recorta sozinho)

As texturas de folhagem são em cinza porque a cor vem da malha (cada árvore tem seu verde); aqui só fica o desenho da
pincelada. Uso: python3 ferramentas/texturas_spritecook.py"""
import pathlib
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORIG = RAIZ / "arte_original" / "spritecook" / "v076"
ILHA = RAIZ / "assets" / "texturas" / "ilha"
MARCA = RAIZ / "assets" / "marca"


def ladrilhar(img: Image.Image, faixa: int = 96) -> Image.Image:
    """Garante a emenda: mistura cada borda com a do lado oposto numa faixa estreita."""
    a = np.array(img.convert("RGB")).astype(np.float32)
    h, w, _ = a.shape
    r = np.roll(np.roll(a, w // 2, 1), h // 2, 0)          # a emenda vai para o meio
    pesos = np.ones((h, w), np.float32)
    for eixo, n in ((0, h), (1, w)):
        t = np.abs(np.arange(n) - n / 2.0)
        p = np.clip(t / faixa, 0.0, 1.0)
        pesos *= p[:, None] if eixo == 0 else p[None, :]
    out = a * pesos[..., None] + r * (1.0 - pesos[..., None])
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def cinza(a: np.ndarray) -> np.ndarray:
    return a[..., 0] * 0.30 + a[..., 1] * 0.59 + a[..., 2] * 0.11


def barranco():
    img = ladrilhar(Image.open(ORIG / "barranco.png").convert("RGB").resize((1024, 1024), Image.LANCZOS))
    # a pintura veio laranja demais para o resto da ilha: tira 35% da saturação e escurece até a média de terra úmida
    a = np.array(img).astype(np.float32) / 255.0
    lum = cinza(a)[..., None]
    a = lum + (a - lum) * 0.65
    a *= 0.46 / max(float(cinza(a).mean()), 1e-3)
    Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8)).save(ILHA / "barranco.png", optimize=True)
    print("barranco.png")


def copa():
    img = ladrilhar(Image.open(ORIG / "copa.png").convert("RGB").resize((1024, 1024), Image.LANCZOS))
    g = cinza(np.array(img).astype(np.float32) / 255.0)
    g = np.array(Image.fromarray((g * 255).astype(np.uint8)).resize((256, 256), Image.LANCZOS)).astype(np.float32) / 255
    g = g / max(np.percentile(g, 97), 1e-3)                  # como a antiga: os claros chegam a 1
    g = 0.71 + (g - g.mean()) * 0.75                         # mesma média da antiga (0,71) e vãos menos pretos
    Image.fromarray((np.clip(g, 0, 1) * 255).astype(np.uint8), "L").save(ILHA / "copa.png", optimize=True)
    print("copa.png")


def palmeira(W=512, H=1024, regiao=896):
    folha = Image.open(ORIG / "folha.png").convert("RGBA")
    A = np.array(folha).astype(np.float32) / 255.0
    alfa = np.clip((A[..., 3] - 0.15) / 0.7, 0, 1)
    figura = alfa > 0.5
    rot, n = ndimage.label(figura)
    if n > 1:                                                 # só a folha (maior mancha), sem farelo do recorte
        tam = ndimage.sum(figura, rot, range(1, n + 1))
        alfa *= ndimage.binary_dilation(rot == 1 + int(np.argmax(tam)), iterations=4)
    ys, xs = np.nonzero(alfa > 0.1)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    # espinha: a coluna com mais pixels opacos no terço de baixo (onde a folha é só o talo e os folíolos curtos)
    meio = int(np.argmax((alfa[y0 + (y1 - y0) * 2 // 3:y1] > 0.5).sum(0)))
    meia = max(meio - x0, x1 - meio)
    x0, x1 = meio - meia, meio + meia
    pad = np.zeros((A.shape[0], A.shape[1] + 2 * meia, 4), np.float32)
    pad[:, meia:meia + A.shape[1], :3] = A[..., :3]
    pad[:, meia:meia + A.shape[1], 3] = alfa
    rec = pad[y0:y1, x0 + meia:x1 + meia]
    g = cinza(rec)
    al = rec[..., 3]
    # cabe na região da folha: altura ~ toda (base embaixo, ponta em cima), largura até 512 sem distorcer além de 1,6x
    alt = regiao - 8
    larg = min(W - 4, int(round(rec.shape[1] * alt / rec.shape[0] * 1.6)))
    gi = np.array(Image.fromarray((g * 255).astype(np.uint8)).resize((larg, alt), Image.LANCZOS)).astype(np.float32) / 255
    ai = np.array(Image.fromarray((al * 255).astype(np.uint8)).resize((larg, alt), Image.LANCZOS)).astype(np.float32) / 255
    rgb = np.zeros((H, W), np.float32)
    alfa_out = np.zeros((H, W), np.float32)
    ox, oy = (W - larg) // 2, regiao - alt - 2
    rgb[oy:oy + alt, ox:ox + larg] = gi
    alfa_out[oy:oy + alt, ox:ox + larg] = ai
    # cor de fora da folha = a do folíolo mais próximo (sem franja escura com mipmaps)
    firme = alfa_out[:regiao] > 0.5
    _, (iy, ix) = ndimage.distance_transform_edt(~firme, return_indices=True)
    rgb[:regiao] = np.where(firme, rgb[:regiao], rgb[:regiao][iy, ix])
    m = rgb[:regiao][firme].mean()
    rgb[:regiao] = rgb[:regiao] / max(m, 1e-3) * 0.92
    # casca: faixa de 128 linhas da textura (anéis horizontais), em cinza, média 0,86
    casca = ladrilhar(Image.open(ORIG / "casca.png").convert("RGB").resize((512, 512), Image.LANCZOS))
    c = cinza(np.array(casca).astype(np.float32) / 255.0)
    faixa = np.array(Image.fromarray((c * 255).astype(np.uint8)).resize((W, 256), Image.LANCZOS)).astype(np.float32) / 255
    faixa = faixa[:H - regiao]
    rgb[regiao:] = np.clip(faixa / max(faixa.mean(), 1e-3) * 0.86, 0.3, 1.0)
    alfa_out[regiao:] = 1.0
    g8 = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    out = np.dstack([g8, g8, g8, (np.clip(alfa_out, 0, 1) * 255).astype(np.uint8)])
    Image.fromarray(out, "RGBA").save(ILHA / "palmeira.png", optimize=True)
    print("palmeira.png", (larg, alt))


def icone():
    img = Image.open(ORIG / "icone.png").convert("RGB")
    lado = min(img.size)
    img = img.crop(((img.width - lado) // 2, (img.height - lado) // 2, (img.width + lado) // 2, (img.height + lado) // 2))
    cheio = img.resize((432, 432), Image.LANCZOS)
    cheio.save(MARCA / "icone_cheio.png", optimize=True)
    i512 = img.resize((512, 512), Image.LANCZOS).convert("RGBA")
    mascara = Image.new("L", (2048, 2048), 0)
    ImageDraw.Draw(mascara).rounded_rectangle((0, 0, 2047, 2047), radius=420, fill=255)
    i512.putalpha(mascara.resize((512, 512), Image.LANCZOS))
    i512.save(MARCA / "icone.png", optimize=True)
    print("icone.png e icone_cheio.png")


if __name__ == "__main__":
    for f in (barranco, copa, palmeira, icone):
        nome = {"barranco": "barranco", "copa": "copa", "palmeira": "folha", "icone": "icone"}[f.__name__]
        if (ORIG / (nome + ".png")).exists():
            f()
        else:
            print("falta", nome + ".png")
