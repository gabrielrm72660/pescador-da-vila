#!/usr/bin/env python3
"""v0.8.7: a arte do horror da noite, pintada no SpriteCook (originais e prompts em arte_original/spritecook/v087/)
-> assets/texturas/bruma/: lamparina (HUD), vulto, coisa (radar), icone_{oleo,vela,patua,sino}.
Limpa o halo do recorte (mesma limpeza dos retratos: rampa de alfa + cor do pixel firme na beirada), corta e reduz.
Os de névoa/fogo (vulto, boitatá, mãe-d'água, coisa) guardam a transparência macia: rampa começando bem baixo.
Uso: python3 ferramentas/bruma_arte.py"""
import importlib.util
import pathlib
import numpy as np
from PIL import Image
from scipy import ndimage

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORIG = RAIZ / "arte_original" / "spritecook" / "v087"
DEST = RAIZ / "assets" / "texturas" / "bruma"

_spec = importlib.util.spec_from_file_location("ret", RAIZ / "ferramentas" / "retratos" / "preparar_spritecook.py")
_ret = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ret)

#           nome          a0   a1   lado maior (px)
PECAS = [("lamparina", 40, 220, 160), ("vulto", 6, 200, 1024), ("coisa", 10, 200, 512)]
# (boitatá e mãe-d'água foram tirados na v0.8.7: cartaz chapado não convenceu; originais ficam em arte_original)
ICONES = ["oleo", "vela", "patua", "sino"]


def cortar(img: Image.Image, lado: int) -> Image.Image:
    caixa = img.split()[3].point(lambda v: 255 if v > 4 else 0).getbbox()
    img = img.crop(caixa)
    k = lado / max(img.size)
    return img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.LANCZOS)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    for nome, a0, a1, lado in PECAS:
        limpo = _ret.limpar(Image.open(ORIG / (nome + ".png")), a0, a1)
        out = cortar(limpo, lado)
        out.save(DEST / (nome + ".png"), optimize=True)
        print(nome, out.size)
    # a folha de ícones: 4 objetos lado a lado; separa pelas colunas vazias
    folha = _ret.limpar(Image.open(ORIG / "icones_noite.png"), 40, 220)
    a = np.array(folha)[..., 3] > 10
    cols = a.any(axis=0)
    rot, n = ndimage.label(cols)
    grupos = sorted([(np.flatnonzero(rot == k).min(), np.flatnonzero(rot == k).max()) for k in range(1, n + 1)
                     if (rot == k).sum() > 40])
    if len(grupos) != len(ICONES):                     # não deu para separar pelas colunas: corta em quartos
        w = folha.width // 4
        grupos = [(i * w, (i + 1) * w - 1) for i in range(4)]
    for nome, (x0, x1) in zip(ICONES, grupos):
        ic = cortar(folha.crop((x0, 0, x1 + 1, folha.height)), 160)
        ic.save(DEST / ("icone_%s.png" % nome), optimize=True)
        print("icone_" + nome, ic.size)


if __name__ == "__main__":
    main()
