"""Corta os sprites das folhas de arte (arte/originais/*.png) e salva cada um, com fundo transparente,
em jogo/imagens/. Rodar:  python arte/cortar_arte.py            (corta tudo)
                          python arte/cortar_arte.py --previa   (também gera arte/previa_sprites.png)

Como funciona: o fundo das folhas é uma névoa suave e os sprites têm contorno escuro e nítido. O fundo é
tudo que se alcança, a partir da borda, sem cruzar uma aresta forte (gradiente alto). Depois uma limpeza
tira o halo: pixel da franja que ainda tem a cor do fundo vizinho vira transparente.
Se uma folha nova tiver outro layout, ajuste só as caixas em RECORTES."""
import os
import sys
import json
import numpy as np
import cv2
from PIL import Image
from scipy import ndimage as ndi

AQUI = os.path.dirname(os.path.abspath(__file__))
ORIG = os.path.join(AQUI, "originais")
SAIDA = os.path.join(os.path.dirname(AQUI), "jogo", "imagens")

# nome -> (folha, caixa (x0, y0, x1, y1) em pixels da folha, opções)
#   gira: graus anti-horários aplicados ao recorte | espelha: True | retangulo: sem remover fundo (tiles)
#   limiar: limiar de aresta usado na folha (padrão 14)
CRIATURAS = "folha_criaturas.png"
BARCO = "folha_barco.png"
ITENS = "folha_itens_icones.png"
AMB = "folha_ambiente_hud.png"
RECORTES = {
    # --- criaturas (a folha tem 1536 x 1024)
    "vulto_a": (CRIATURAS, (14, 9, 678, 534), {}),
    "vulto_b": (CRIATURAS, (698, 0, 1525, 532), {}),
    "tentaculo_1": (CRIATURAS, (57, 529, 311, 756), {}),
    "tentaculo_2": (CRIATURAS, (374, 527, 625, 756), {}),
    "tentaculo_3": (CRIATURAS, (676, 550, 1131, 763), {}),
    "tentaculo_4": (CRIATURAS, (1144, 540, 1477, 763), {}),
    "tubarao": (CRIATURAS, (75, 759, 259, 1014), {}),
    "tubarao_lado": (CRIATURAS, (314, 814, 609, 965), {}),
    "peixe_1": (CRIATURAS, (672, 824, 795, 884), {}),
    "peixe_2": (CRIATURAS, (797, 823, 921, 884), {}),
    "peixe_3": (CRIATURAS, (924, 825, 1048, 884), {}),
    "peixe_4": (CRIATURAS, (672, 890, 797, 950), {}),
    "peixe_5": (CRIATURAS, (798, 890, 922, 950), {}),
    "peixe_6": (CRIATURAS, (925, 892, 1049, 949), {}),
    "gaivota": (CRIATURAS, (1100, 793, 1501, 985), {}),
    # --- barco (1254 x 1254, já com transparência; proa para cima)
    "barco_base": (BARCO, (44, 9, 275, 323), {}),
    "barco_vela": (BARCO, (38, 631, 275, 974), {}),
    "barco_ferro": (BARCO, (355, 632, 585, 974), {}),
    "barco_danificado": (BARCO, (671, 632, 902, 974), {}),
    "barco_lanterna": (BARCO, (984, 630, 1211, 974), {}),
    "naufrago_frente": (BARCO, (91, 1010, 223, 1238), {}),
    "naufrago_costas": (BARCO, (406, 1009, 535, 1238), {}),
    # --- itens e ícones (1536 x 1024)
    "item_barril": (ITENS, (41, 27, 239, 268), {}),
    "item_tabua": (ITENS, (278, 43, 512, 246), {"gira": -34}),
    "item_corda": (ITENS, (534, 43, 756, 253), {}),
    "item_garrafa": (ITENS, (842, 22, 966, 248), {"gira": -90}),
    "item_bau": (ITENS, (1038, 56, 1259, 241), {}),
    "item_bau_aberto": (ITENS, (1293, 25, 1509, 249), {}),
    "ic_peixe": (ITENS, (28, 318, 249, 491), {}),
    "ic_gota": (ITENS, (319, 290, 459, 487), {}),
    "ic_consertar": (ITENS, (525, 279, 753, 498), {}),
    "ic_lanterna_acesa": (ITENS, (809, 266, 974, 501), {}),
    "ic_lanterna_apagada": (ITENS, (1069, 264, 1232, 501), {}),
    "ic_vara": (ITENS, (1282, 273, 1512, 503), {}),
    "mel_casco": (ITENS, (34, 530, 249, 751), {}),
    "mel_remos": (ITENS, (287, 535, 498, 743), {}),
    "mel_vela": (ITENS, (532, 522, 751, 757), {}),
    "mel_leme": (ITENS, (780, 523, 1022, 757), {}),
    "mel_lente": (ITENS, (1060, 526, 1233, 748), {}),
    "mel_rede": (ITENS, (1275, 537, 1508, 745), {}),
    "melc_casco": (ITENS, (34, 784, 249, 1005), {}),
    "melc_remos": (ITENS, (287, 791, 497, 999), {}),
    "melc_vela": (ITENS, (534, 777, 753, 1014), {}),
    "melc_leme": (ITENS, (780, 777, 1022, 1013), {}),
    "melc_lente": (ITENS, (1061, 781, 1231, 1005), {}),
    "melc_rede": (ITENS, (1275, 791, 1508, 1003), {}),
    # --- ambiente e interface (1536 x 1024)
    "agua_dia": (AMB, (32, 52, 274, 312), {"retangulo": True}),
    "agua_noite": (AMB, (294, 52, 528, 312), {"retangulo": True}),
    "agua_tempestade": (AMB, (546, 52, 792, 312), {"retangulo": True}),
    "ilha": (AMB, (810, 10, 1182, 360), {"limiar": 26}),
    "palmeira": (AMB, (1193, 40, 1374, 291), {"limiar": 26}),
    "pedra_1": (AMB, (1387, 25, 1503, 114), {"limiar": 26}),
    "pedra_2": (AMB, (1407, 125, 1485, 179), {"limiar": 26}),
    "pedra_3": (AMB, (1421, 189, 1471, 223), {"limiar": 26}),
    "fogueira": (AMB, (1360, 246, 1473, 353), {"limiar": 26}),
    "bs_vida": (AMB, (20, 602, 84, 663), {"limiar": 26}),
    "bs_peixe": (AMB, (9, 669, 89, 720), {"limiar": 26}),
    "bs_gota": (AMB, (23, 728, 73, 789), {"limiar": 26}),
    "bs_raio": (AMB, (22, 794, 73, 863), {"limiar": 26}),
    "bs_barco": (AMB, (9, 865, 88, 921), {"limiar": 26}),
    "bs_olho": (AMB, (9, 930, 89, 985), {"limiar": 26}),
    "moldura_barra": (AMB, (94, 598, 426, 662), {"limiar": 26}),
    "moldura_quadro": (AMB, (770, 603, 941, 765), {"limiar": 26}),
    "moldura_pergaminho": (AMB, (968, 609, 1525, 767), {"limiar": 26}),
    "bussola": (AMB, (749, 787, 954, 995), {"limiar": 26}),
    "agulha": (AMB, (972, 820, 1020, 969), {"limiar": 26}),
    "biruta": (AMB, (1056, 834, 1177, 952), {"limiar": 26}),
    "sol": (AMB, (1181, 830, 1285, 935), {"limiar": 26}),
    "lua": (AMB, (1294, 838, 1389, 931), {"limiar": 26}),
    "nuvem_raio": (AMB, (1397, 825, 1527, 958), {"limiar": 26}),
}


def _mascara_fundo(rgb, limiar, alfa=None):
    """True onde é fundo: alcançável da borda sem cruzar aresta forte; depois tira o halo."""
    b = cv2.GaussianBlur(rgb.astype(np.float32), (0, 0), 1.0)
    gx = cv2.Sobel(b, cv2.CV_32F, 1, 0, ksize=3)
    gy = cv2.Sobel(b, cv2.CV_32F, 0, 1, ksize=3)
    g = np.sqrt((gx ** 2 + gy ** 2).sum(-1)) / 4.0
    barreira = ndi.binary_closing(g > limiar, iterations=2)
    lab, _ = ndi.label(~barreira)
    borda = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    fundo = np.isin(lab, list(borda))
    if alfa is not None:                                   # folha com transparência: o transparente é fundo
        fundo |= alfa < 140
    # halo: pixels da franja que ainda têm a cor do fundo vizinho
    for _ in range(3):
        if not fundo.any():
            break
        _, (iy, ix) = ndi.distance_transform_edt(~fundo, return_indices=True)
        dist = np.hypot(*(np.indices(fundo.shape) - np.stack([iy, ix])))
        ref = rgb[iy, ix].astype(np.float32)
        dif = np.abs(rgb.astype(np.float32) - ref).sum(-1)
        fundo |= (~fundo) & (dist <= 2.2) & (dif < 70)
    return fundo


def recortar(nome, folha, caixa, op, cache):
    im = cache.setdefault(folha, np.array(Image.open(os.path.join(ORIG, folha)).convert("RGBA")))
    x0, y0, x1, y1 = caixa
    pad = 8
    X0, Y0 = max(0, x0 - pad), max(0, y0 - pad)
    X1, Y1 = min(im.shape[1], x1 + pad), min(im.shape[0], y1 + pad)
    sub = im[Y0:Y1, X0:X1].copy()
    rgb, a = sub[..., :3], sub[..., 3]
    if op.get("retangulo"):
        out = sub[y0 - Y0:y1 - Y0, x0 - X0:x1 - X0].copy()
        out[..., 3] = 255
        return Image.fromarray(out)
    transp = a.min() < 250
    fundo = _mascara_fundo(rgb, op.get("limiar", 14), a if transp else None)
    fg = ~fundo
    fg = ndi.binary_opening(fg, iterations=1)
    # só o que está dentro da caixa pedida e o maior bloco (mais pedaços próximos dele)
    caixa_m = np.zeros_like(fg)
    caixa_m[y0 - Y0:y1 - Y0, x0 - X0:x1 - X0] = True
    fg &= caixa_m
    lab, n = ndi.label(ndi.binary_dilation(fg, iterations=3))
    if n == 0:
        raise SystemExit("sem sprite em " + nome)
    areas = ndi.sum(fg, lab, range(1, n + 1))
    manter = [i + 1 for i, ar in enumerate(areas) if ar >= max(30, 0.02 * max(areas))]
    fg &= np.isin(lab, manter)
    # buracos fechados pelo contorno ficam como parte do sprite
    fg = ndi.binary_fill_holes(fg)
    out = sub.copy()
    out[..., 3] = np.where(fg, 255, 0).astype(np.uint8)
    ys, xs = np.where(fg)
    out = out[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    return Image.fromarray(out)


def main(previa=False):
    os.makedirs(SAIDA, exist_ok=True)
    cache, feitos = {}, {}
    for nome, (folha, caixa, op) in RECORTES.items():
        img = recortar(nome, folha, caixa, op, cache)
        if op.get("gira"):
            img = img.rotate(op["gira"], expand=True, resample=Image.BICUBIC)
        if op.get("espelha"):
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        feitos[nome] = img
    _alinhar_barcos(feitos)
    for nome, img in feitos.items():
        img.save(os.path.join(SAIDA, nome + ".png"), optimize=True)
    with open(os.path.join(SAIDA, "meta.json"), "w") as f:
        json.dump(_meta(feitos), f, indent=1)
    print(len(feitos), "sprites em", SAIDA)
    if previa:
        _previa(feitos)


BARCO_TELA = (240, 372)            # tela comum dos sprites do barco: centro do casco no meio, popa em baixo


def _alinhar_barcos(feitos):
    """As variantes do barco saem da folha com tamanhos de recorte diferentes. Aqui todas vão para a
    mesma tela, com o centro do casco no meio e a popa na mesma altura: trocar de variante no jogo
    (casco de ferro, avariado) não faz o barco pular."""
    W, H = BARCO_TELA
    popa_y = H // 2 + 146                                    # o barco base tem 292 de comprimento
    for nome in ("barco_base", "barco_vela", "barco_ferro", "barco_danificado", "barco_lanterna"):
        im = feitos[nome]
        a = np.array(im)[..., 3] > 200
        linha = int(im.height * 0.45)
        xs = np.where(a[linha])[0]
        cx = (xs.min() + xs.max()) / 2.0
        ys = np.where(a.any(1))[0]
        base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        base.alpha_composite(im, (int(round(W / 2 - cx)), int(popa_y - (ys.max() + 1))))
        feitos[nome] = base


def _meta(feitos):
    """Pontos de interesse achados nos sprites (lanterna e pás do barco, olhos e brilhos dos vultos),
    em pixels do próprio sprite, para o jogo posicionar luzes e efeitos sem precisar de numpy."""
    meta = {}
    a = np.array(feitos["barco_base"])
    h, w = a.shape[:2]
    r, g, b, al = (a[..., i].astype(int) for i in range(4))
    luz = (r > 235) & (g > 190) & (b < 170) & (al > 200)
    luz[h // 3:] = False                                         # a lanterna fica na proa (alto do sprite)
    ys, xs = np.where(luz)
    meta["barco"] = {"w": w, "h": h, "lanterna": [float(xs.mean()), float(ys.mean())] if len(xs) else [w / 2, h * 0.08]}
    opaco = al > 200
    colunas = np.where(opaco.any(0))[0]
    esq = colunas.min()
    dire = colunas.max()
    meta["barco"]["pa_esq"] = [float(esq), float(np.where(opaco[:, esq])[0].mean())]
    meta["barco"]["pa_dir"] = [float(dire), float(np.where(opaco[:, dire])[0].mean())]
    for nome in ("vulto_a", "vulto_b"):
        a = np.array(feitos[nome].convert("RGBA"))
        hh, ww = a.shape[:2]
        hsv = cv2.cvtColor(a[..., :3], cv2.COLOR_RGB2HSV).astype(int)
        H, S, V = hsv[..., 0] * 2, hsv[..., 1], hsv[..., 2]
        verde = (H > 45) & (H < 100) & (S > 90) & (V > 120) & (a[..., 3] > 200)        # olhos verdes
        ambar = (H > 25) & (H <= 45) & (S > 150) & (V > 190) & (a[..., 3] > 200)        # olho central
        olhos = []
        for ci, m in ((0, verde), (2, ambar)):
            lab, n = ndi.label(ndi.binary_closing(m, iterations=2))
            for i in range(1, n + 1):
                ys, xs = np.where(lab == i)
                if len(xs) < 40:
                    continue
                olhos.append([float(xs.mean() - ww / 2), float(ys.mean() - hh / 2),
                              float(max(xs.max() - xs.min(), ys.max() - ys.min()) / 2), ci])
        rosa = (H > 300) & (H < 345) & (S > 60) & (V > 190) & (a[..., 3] > 200)         # ventosas claras
        ys, xs = np.where(rosa)
        brilhos = []
        if len(xs):
            rng = np.random.RandomState(7)
            for k in rng.permutation(len(xs)):
                p = (float(xs[k] - ww / 2), float(ys[k] - hh / 2))
                if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 > 70 ** 2 for q in brilhos):
                    brilhos.append(list(p))
                if len(brilhos) >= 14:
                    break
        meta[nome] = {"w": ww, "h": hh, "olhos": olhos, "brilhos": brilhos}
    return meta


def _previa(feitos):
    W = 1800
    x = y = 8
    linha = 0
    fundos = [(24, 118, 168, 255), (6, 20, 48, 255)]
    itens = list(feitos.items())
    folha = Image.new("RGBA", (W, 2400), (24, 118, 168, 255))
    for k, (nome, img) in enumerate(itens):
        esc = min(1.0, 150 / max(img.size))
        im2 = img.resize((max(1, int(img.width * esc)), max(1, int(img.height * esc))), Image.LANCZOS)
        if x + im2.width + 8 > W:
            x, y, linha = 8, y + linha + 8, 0
        bloco = Image.new("RGBA", (im2.width, im2.height), fundos[k % 2])
        bloco.alpha_composite(im2)
        folha.paste(bloco, (x, y))
        x += im2.width + 8
        linha = max(linha, im2.height)
    folha = folha.crop((0, 0, W, y + linha + 8))
    folha.convert("RGB").save(os.path.join(AQUI, "previa_sprites.png"))


if __name__ == "__main__":
    main("--previa" in sys.argv)
    # o recorte reescreve o meta.json; o separar_remos tira os remos do casco e acrescenta "remos" ao meta
    sys.path.insert(0, AQUI)
    import separar_remos
    separar_remos.main()
