#!/usr/bin/env python3
"""v0.8.9: prepara a Coisa de Baixo (modelos gerados a partir da arte conceitual do Gabriel).

Entradas (arte_original/monstro/):
  coisa_ataque_trellis.glb  — cabeça e pescoço saindo da água, boca aberta (TRELLIS, licença MIT), com textura
  coisa_corpo_hunyuan.glb   — corpo inteiro, só a forma (Hunyuan3D 2.1), sem textura nem UV
  coisa_de_baixo_conceito_lado.png — a arte de perfil (vira a textura do corpo, projetada de lado)

Saídas (assets/modelos/coisa/):
  coisa_ataque.glb + ataque_cor.png + ataque_relevo.png   (cor clareada e puxada para o verde-azulado da arte; relevo da luminância)
  coisa_corpo.glb (reduzido para ~22 mil triângulos, com normais) + corpo_arte.png + corpo_relevo.png
     (a arte de perfil recortada; o fundo é preenchido com a cor do pixel de bicho mais perto, para a projeção não pegar cinza)
     corpo_caixa.txt: xmin xmax ymin ymax do corpo (para o shader casar a arte com a malha)
Uso: python3 ferramentas/coisa_de_baixo.py
"""
import io
import json
import pathlib
import struct

import numpy as np
import trimesh
import fast_simplification
from PIL import Image, ImageEnhance, ImageFilter
from scipy import ndimage

RAIZ = pathlib.Path(__file__).resolve().parent.parent
ORIG = RAIZ / "arte_original" / "monstro"
DEST = RAIZ / "assets" / "modelos" / "coisa"


def relevo(cor: Image.Image, forca: float = 2.2, lado: int = 1024) -> Image.Image:
    """Normal map (OpenGL, Y para cima) a partir da luminância: rugas e cracas pegam a luz da lanterna."""
    g = np.asarray(cor.convert("L").resize((lado, lado), Image.LANCZOS), dtype=np.float32) / 255.0
    g = ndimage.gaussian_filter(g, 1.0)
    dx = ndimage.sobel(g, axis=1) * forca
    dy = ndimage.sobel(g, axis=0) * forca
    n = np.dstack([-dx, dy, np.ones_like(g)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8))


def textura_do_glb(caminho: pathlib.Path) -> Image.Image:
    b = caminho.read_bytes()
    n_json = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n_json])
    bin_ini = 20 + n_json + 8
    bv = j["bufferViews"][j["images"][0]["bufferView"]]
    ini = bin_ini + bv.get("byteOffset", 0)
    return Image.open(io.BytesIO(b[ini:ini + bv["byteLength"]])).convert("RGB")


def ataque() -> None:
    cena = trimesh.load(ORIG / "coisa_ataque_trellis.glb", force="scene")
    malha: trimesh.Trimesh = list(cena.geometry.values())[0]
    print("ataque:", len(malha.faces), "triângulos, caixa", malha.bounds.tolist())
    cor = textura_do_glb(ORIG / "coisa_ataque_trellis.glb")
    # a textura do TRELLIS sai escura e acinzentada: clareia e puxa para o verde-azulado da arte
    cor = ImageEnhance.Brightness(cor).enhance(1.35)
    cor = ImageEnhance.Contrast(cor).enhance(1.12)
    a = np.asarray(cor, dtype=np.float32)
    a = a * np.array([0.93, 1.04, 1.02])
    cor = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    cor = ImageEnhance.Color(cor).enhance(1.15).filter(ImageFilter.UnsharpMask(2, 60, 2))
    lado = 2048 if cor.width >= 2048 else cor.width
    cor = cor.resize((lado, lado), Image.LANCZOS)
    cor.save(DEST / "ataque_cor.png", optimize=True)
    relevo(cor).save(DEST / "ataque_relevo.png", optimize=True)
    # normais suaves (o arquivo do TRELLIS não traz) e exporta só a forma + UV
    malha.vertex_normals
    malha.visual = trimesh.visual.TextureVisuals(uv=malha.visual.uv)
    malha.export(DEST / "coisa_ataque.glb")


def corpo() -> None:
    cena = trimesh.load(ORIG / "coisa_corpo_hunyuan.glb", force="scene")
    malha: trimesh.Trimesh = list(cena.geometry.values())[0]
    print("corpo:", len(malha.faces), "triângulos")
    v, f = fast_simplification.simplify(malha.vertices.astype(np.float32), malha.faces.astype(np.int32), target_reduction=0.70)
    malha = trimesh.Trimesh(v, f, process=True)
    trimesh.smoothing.filter_taubin(malha, iterations=6)
    print("corpo reduzido:", len(malha.faces), "triângulos, caixa", malha.bounds.tolist())
    malha.export(DEST / "coisa_corpo.glb")
    (DEST / "corpo_caixa.txt").write_text("%f %f %f %f\n" % (malha.bounds[0][0], malha.bounds[1][0], malha.bounds[0][1], malha.bounds[1][1]))
    # a arte de perfil: recorta o bicho, preenche o fundo com a cor do bicho mais perto
    arte = Image.open(ORIG / "coisa_de_baixo_conceito_lado.png").convert("RGB")
    a = np.asarray(arte, dtype=np.float32)
    fundo = np.median(np.concatenate([a[:8].reshape(-1, 3), a[-8:].reshape(-1, 3)]), axis=0)
    dif = np.abs(a - fundo).sum(axis=2)
    bicho = ndimage.binary_opening(dif > 38, iterations=2)
    rot, n = ndimage.label(bicho)
    tam = ndimage.sum(bicho, rot, range(1, n + 1))
    bicho = rot == (1 + int(np.argmax(tam)))
    bicho = ndimage.binary_fill_holes(bicho)
    ys, xs = np.nonzero(bicho)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    print("arte: bicho em x", x0, x1, "y", y0, y1)
    miolo = ndimage.binary_erosion(bicho, iterations=6)        # a borda do desenho é clara (antisserrilhado): pega a cor de dentro
    _, (iy, ix) = ndimage.distance_transform_edt(~miolo, return_indices=True)
    cheio = a[iy, ix]
    cheio = np.where(miolo[..., None], a, ndimage.gaussian_filter(cheio, (6, 6, 0)))
    recorte = Image.fromarray(cheio.astype(np.uint8)).crop((x0, y0, x1 + 1, y1 + 1))
    recorte = recorte.resize((2048, int(2048 * recorte.height / recorte.width)), Image.LANCZOS)
    recorte.save(DEST / "corpo_arte.png", optimize=True)
    relevo(recorte, 1.6, 1024).resize((1024, 512)).save(DEST / "corpo_relevo.png", optimize=True)


def main():
    DEST.mkdir(parents=True, exist_ok=True)
    ataque()
    corpo()


if __name__ == "__main__":
    main()
