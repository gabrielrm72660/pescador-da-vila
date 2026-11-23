#!/usr/bin/env python3
"""v0.7.0: retratos do diálogo que não são pessoas pintadas:
 - bento.png: o compadre Bento na bruma, só a silhueta (chapéu, capa de chuva e a lanterna acesa na mão);
 - diario.png: uma página molhada do diário de bordo dele.
Uso: python3 ferramentas/retratos/gerar_bento_diario.py   (precisa de pillow e numpy)"""
import pathlib, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = pathlib.Path(__file__).resolve().parent.parent.parent
DEST = RAIZ / "assets" / "retratos"
random.seed(7)

def bento():
    W, H = 470, 660
    sil = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(sil)
    cx = 190
    # capa de chuva: ombros largos que descem até embaixo
    d.polygon([(cx - 70, 250), (cx + 70, 250), (cx + 135, 400), (cx + 150, H), (cx - 150, H), (cx - 130, 400)], fill=255)
    d.ellipse([cx - 92, 225, cx + 92, 320], fill=255)           # ombros arredondados
    d.rectangle([cx - 26, 185, cx + 26, 250], fill=255)          # pescoço / gola
    d.ellipse([cx - 46, 110, cx + 46, 215], fill=255)            # cabeça
    d.ellipse([cx - 112, 112, cx + 112, 150], fill=255)          # aba do chapéu
    d.polygon([(cx - 52, 132), (cx - 40, 62), (cx + 40, 62), (cx + 52, 132)], fill=255)   # copa do chapéu
    # braço erguido segurando a lanterna, à direita dele (esquerda da tela fica livre para a caixa de texto)
    d.polygon([(cx + 70, 270), (cx + 120, 262), (cx + 190, 380), (cx + 160, 400), (cx + 100, 320)], fill=255)
    d.ellipse([cx + 150, 372, cx + 196, 412], fill=255)          # mão
    d.line([(cx + 172, 392), (cx + 172, 420)], fill=255, width=5)   # alça
    sil = sil.filter(ImageFilter.GaussianBlur(2.2))
    a = np.array(sil).astype(np.float32) / 255.0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # a bruma come a figura de baixo para cima e pelas bordas
    sumir = np.clip((yy - 380) / 260.0, 0, 1) ** 1.4
    a *= 1.0 - 0.92 * sumir
    ruido = np.array(Image.effect_noise((W, H), 40).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255.0
    a *= 0.82 + 0.25 * ruido
    cor = np.zeros((H, W, 3), np.float32)
    base = np.array([0.10, 0.13, 0.17])
    clara = np.array([0.30, 0.35, 0.40])
    mistura = np.clip((yy - 120) / 500.0, 0, 1)[..., None]
    cor[:] = base * (1 - mistura) + clara * mistura
    # lanterna: brilho quente com halo grande
    lx, ly = cx + 172, 445
    dist = np.sqrt((xx - lx) ** 2 + (yy - ly) ** 2)
    halo = np.exp(-(dist / 46.0) ** 2) * 0.9 + np.exp(-(dist / 22.0) ** 2)
    quente = np.array([1.0, 0.78, 0.42])
    cor = cor * (1 - np.clip(halo, 0, 1)[..., None] * 0.8) + quente * np.clip(halo, 0, 1)[..., None]
    a = np.maximum(a, np.clip(halo, 0, 1) * 0.95)
    # corpo da lanterna
    img = Image.fromarray(np.dstack([np.clip(cor * 255, 0, 255), np.clip(a * 255, 0, 255)]).astype(np.uint8), "RGBA")
    d2 = ImageDraw.Draw(img)
    d2.rectangle([lx - 13, ly - 22, lx + 13, ly + 20], outline=(40, 30, 20, 230), width=3)
    d2.rectangle([lx - 9, ly - 18, lx + 9, ly + 16], fill=(255, 214, 140, 245))
    d2.polygon([(lx - 15, ly - 22), (lx + 15, ly - 22), (lx, ly - 34)], fill=(40, 30, 20, 230))
    img.save(DEST / "bento.png", optimize=True)

def diario():
    W, H = 420, 560
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pagina = Image.new("RGBA", (330, 440), (226, 212, 176, 255))
    p = np.array(pagina).astype(np.float32)
    ruido = np.array(Image.effect_noise((330, 440), 60).filter(ImageFilter.GaussianBlur(3))).astype(np.float32)
    p[..., :3] += (ruido[..., None] - 128) * 0.18
    yy, xx = np.mgrid[0:440, 0:330]
    # manchas d'água e bordas escuras
    for _ in range(5):
        cx, cy, r = random.randint(30, 300), random.randint(40, 400), random.randint(40, 110)
        m = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (r * r)))
        p[..., :3] -= m[..., None] * np.array([38, 40, 30])
    borda = np.minimum(np.minimum(xx, 329 - xx), np.minimum(yy, 439 - yy)).astype(np.float32)
    p[..., :3] -= np.clip(1 - borda / 22.0, 0, 1)[..., None] * 60
    pagina = Image.fromarray(np.clip(p, 0, 255).astype(np.uint8), "RGBA")
    d = ImageDraw.Draw(pagina)
    for k in range(13):                                    # pauta
        y = 60 + k * 28
        d.line([(24, y), (306, y)], fill=(120, 140, 160, 120), width=1)
    d.line([(52, 30), (52, 420)], fill=(170, 80, 70, 120), width=1)
    for k in range(12):                                    # letra borrada: rabiscos de tinta
        y = 54 + k * 28
        x = 62
        fim = random.randint(200, 300) if k % 4 != 3 else random.randint(110, 180)
        while x < fim:
            w = random.randint(14, 42)
            pts = [(x + i * 3, y - 4 + 4 * math.sin(i * 1.7 + k)) for i in range(w // 3)]
            if len(pts) > 1:
                d.line(pts, fill=(40, 42, 70, 190), width=2)
            x += w + random.randint(6, 12)
    pagina = pagina.filter(ImageFilter.GaussianBlur(0.6)).rotate(-6, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(pagina, ((W - pagina.width) // 2, (H - pagina.height) // 2 + 30))
    img.save(DEST / "diario.png", optimize=True)

if __name__ == "__main__":
    bento()
    diario()
    print("ok")
