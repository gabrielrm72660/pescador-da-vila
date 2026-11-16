"""Gera as texturas pintadas do MAR ABERTO (barco e oceano). Todas se repetem sem emenda.

Uso:  python ferramentas/gerar_texturas.py
Saída: assets/texturas/barco/*.png e assets/texturas/mar/*.png
Precisa de numpy, opencv-python, scipy e Pillow (só para gerar; o jogo não usa Python).
"""
import os
import numpy as np
import cv2
from scipy.spatial import cKDTree
from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 1024


def ruido(n, beta, esticar=(1.0, 1.0), semente=0):
    """Ruído que se repete sem emenda (filtrado no espectro). esticar=(ex, ey): >1 alonga nesse eixo."""
    rng = np.random.default_rng(semente)
    fx = np.fft.fftfreq(n)[None, :] * esticar[0]
    fy = np.fft.fftfreq(n)[:, None] * esticar[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    esp = np.fft.fft2(rng.standard_normal((n, n))) / f ** beta
    esp[0, 0] = 0
    r = np.real(np.fft.ifft2(esp))
    lo, hi = np.percentile(r, [0.5, 99.5])
    return np.clip((r - lo) / (hi - lo), 0, 1)


def degrau(a, b, x):
    t = np.clip((x - a) / (b - a + 1e-9), 0, 1)
    return t * t * (3 - 2 * t)


def borrar_sem_emenda(img, func, margem=48):
    """Aplica um filtro do OpenCV sem criar emenda: envolve a imagem, filtra e recorta."""
    e = cv2.copyMakeBorder(img, margem, margem, margem, margem, cv2.BORDER_WRAP)
    return func(e)[margem:-margem, margem:-margem]


def normal_de_altura(h, forca):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * forca
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * forca
    n = np.dstack([-dx, -dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def salvar(caminho, rgb):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    cv2.imwrite(caminho, cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR) if rgb.ndim == 3 and rgb.shape[2] == 3 else rgb)


def pintado(rgb):
    """Acabamento de pintura à mão: achata os tons em manchas, mantendo as bordas."""
    u8 = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    u8 = borrar_sem_emenda(u8, lambda e: cv2.bilateralFilter(cv2.bilateralFilter(e, 9, 38, 7), 7, 26, 5))
    return u8


def tabuas(cor, fundo, semente, n_tabuas=8, desgaste=0.22, ferrugem=0.0, veio=0.10, costura=(0.10, 0.08, 0.07),
           largura_costura=1.7, madeira_crua=False):
    """Tábuas horizontais pintadas e gastas. cor = tinta; fundo = o que aparece onde a tinta soltou."""
    rng = np.random.default_rng(semente)
    cor = np.array(cor, float)
    fundo = np.array(fundo, float)
    yy, xx = np.mgrid[0:N, 0:N]
    alt = N / n_tabuas
    indice = (yy // alt).astype(int)
    dist_costura = np.minimum(yy % alt, alt - yy % alt)
    linha = np.exp(-(dist_costura / largura_costura) ** 2)
    # veio da madeira: liso ao longo da tábua, fino através dela; cada tábua começa num ponto diferente
    veio_base = ruido(N, 1.5, (14.0, 1.0), semente + 1)
    veio_fino = ruido(N, 1.0, (30.0, 1.0), semente + 2)
    grao = np.zeros((N, N))
    tom = np.zeros((N, N))
    emenda = np.zeros((N, N))
    for i in range(n_tabuas):
        faixa = indice == i
        d = int(rng.integers(0, N))
        grao[faixa] = (0.7 * np.roll(veio_base, d, 1) + 0.3 * np.roll(veio_fino, d // 2, 1))[faixa]
        tom[faixa] = rng.uniform(-0.055, 0.055)
        x0 = int(rng.integers(0, N))                       # emenda de topo entre duas tábuas
        dx = np.minimum(np.abs(xx - x0), N - np.abs(xx - x0))
        emenda[faixa] = np.exp(-(dx / 1.4) ** 2)[faixa]
    linha = np.maximum(linha, emenda * 0.8)
    pincel = ruido(N, 2.1, (5.0, 1.0), semente + 3)        # pinceladas largas no sentido da tábua
    mancha = ruido(N, 2.9, (1.0, 1.0), semente + 4)        # variação lenta de tom
    quente = ruido(N, 3.0, (1.0, 1.0), semente + 5)

    seco = ruido(N, 0.7, (9.0, 1.0), semente + 11)          # pincel seco: fios finos de tinta
    sujeira = np.exp(-(dist_costura / 10.0) ** 2)            # encardido junto das costuras
    luz = np.exp(-((yy % alt - 4.5) / 1.6) ** 2)             # filete de luz na quina de cima da tábua
    tinta = cor[None, None, :] * (1.0 + veio * (grao - 0.5) + 0.17 * (pincel - 0.5) + 0.14 * (mancha - 0.5)
                                  + 0.07 * (seco - 0.5) + tom - 0.13 * sujeira + 0.07 * luz)[..., None]
    tinta = tinta * (1.0 + (quente - 0.5)[..., None] * np.array([0.05, 0.0, -0.05]))
    cru = fundo[None, None, :] * (0.78 + 0.5 * grao + 0.1 * tom)[..., None]

    # onde a tinta soltou: manchas irregulares, mais perto das costuras
    m = 0.55 * ruido(N, 1.9, (2.5, 1.0), semente + 6) + 0.30 * ruido(N, 1.1, (3.0, 1.0), semente + 7) + 0.20 * linha
    if desgaste > 0:
        corte = np.quantile(m, 1.0 - desgaste * 0.42)        # desgaste = fração aproximada da área sem tinta
        solto = degrau(corte - 0.012, corte + 0.012, m)
    else:
        solto = np.zeros((N, N))
    if madeira_crua:
        solto[:] = 1.0
        cru = cor[None, None, :] * (0.72 + 0.62 * grao + tom)[..., None]
        cinza = degrau(0.55, 0.85, ruido(N, 2.4, (3.0, 1.0), semente + 8))      # madeira acinzentada pelo sol
        cru = cru * (1 - 0.35 * cinza[..., None]) + np.array([0.52, 0.5, 0.47]) * 0.35 * cinza[..., None]
    borda = np.clip(cv2.GaussianBlur(solto, (0, 0), 2.2) - solto, 0, 1) if not madeira_crua else 0.0
    img = tinta * (1 - solto[..., None]) + cru * solto[..., None]
    img *= (1.0 - 0.9 * np.clip(borda * 2.2, 0, 1))[..., None] * 0.35 + 0.65
    # ferrugem escorrida: riscos verticais abaixo de pontos perto das costuras
    if ferrugem > 0:
        risco = ruido(N, 1.25, (0.45, 14.0), semente + 9) * (0.35 + 0.65 * ruido(N, 2.4, (1.0, 1.0), semente + 10))
        corte_f = np.quantile(risco, 1.0 - 0.10 * ferrugem)
        fer = degrau(corte_f - 0.05, corte_f + 0.10, risco) * min(1.0, 0.5 + ferrugem)
        img = img * (1 - fer[..., None]) + np.array([0.52, 0.27, 0.13]) * fer[..., None]
    img *= (1.0 - 0.55 * linha)[..., None]
    img = img * (1 - 0.35 * linha[..., None]) + np.array(costura) * 0.35 * linha[..., None]
    altura = -1.0 * linha - 0.35 * solto + 0.22 * grao + 0.08 * pincel
    return pintado(img), normal_de_altura(cv2.GaussianBlur(altura, (0, 0), 0.8), 5.0)


def metal(cor, semente, ferrugem=0.3):
    cor = np.array(cor, float)
    pincel = ruido(N, 2.0, (3.0, 1.0), semente)
    mancha = ruido(N, 2.8, (1.0, 1.0), semente + 1)
    img = cor[None, None, :] * (1 + 0.12 * (pincel - 0.5) + 0.16 * (mancha - 0.5))[..., None]
    m = 0.6 * ruido(N, 1.8, (1.0, 1.0), semente + 2) + 0.4 * ruido(N, 1.0, (1.0, 1.0), semente + 3)
    fer = degrau(1 - ferrugem - 0.05, 1 - ferrugem + 0.06, m / m.max())
    cor_fer = np.array([0.50, 0.26, 0.12])[None, None, :] * (0.7 + 0.6 * ruido(N, 1.2, (1, 1), semente + 4))[..., None]
    escorre = degrau(0.62, 0.85, ruido(N, 1.25, (0.45, 14.0), semente + 5)) * 0.45 * ferrugem / 0.3
    img = img * (1 - fer[..., None]) + cor_fer * fer[..., None]
    img = img * (1 - escorre[..., None]) + np.array([0.5, 0.28, 0.14]) * escorre[..., None]
    return pintado(img), normal_de_altura(cv2.GaussianBlur(-0.5 * fer + 0.1 * pincel, (0, 0), 1.0), 4.0)


def corda(semente):
    yy, xx = np.mgrid[0:N, 0:N]
    voltas = 16                                           # cordões diagonais (fecha na emenda)
    fase = (xx / N * voltas + yy / N * voltas * 4) * 2 * np.pi
    cordao = 0.5 + 0.5 * np.sin(fase)
    fibra = ruido(N, 1.2, (1.0, 6.0), semente)
    base = np.array([0.72, 0.58, 0.38])
    img = base[None, None, :] * (0.62 + 0.42 * cordao + 0.18 * (fibra - 0.5))[..., None]
    return pintado(img), normal_de_altura(cordao + 0.2 * fibra, 6.0)


def rede(semente):
    """Rede de pesca amontoada: malha em losangos verde sobre fundo escuro."""
    yy, xx = np.mgrid[0:N, 0:N]
    malhas = 14
    a = np.abs(np.sin((xx + yy) / N * malhas * np.pi))
    b = np.abs(np.sin((xx - yy) / N * malhas * np.pi))
    fio = np.maximum(degrau(0.16, 0.04, a), degrau(0.16, 0.04, b))
    sombra = ruido(N, 2.4, (1, 1), semente)
    img = np.array([0.05, 0.13, 0.11])[None, None, :] * (0.7 + 0.6 * sombra)[..., None]
    cor_fio = np.array([0.20, 0.52, 0.42])[None, None, :] * (0.7 + 0.5 * ruido(N, 1.5, (1, 1), semente + 1))[..., None]
    img = img * (1 - fio[..., None]) + cor_fio * fio[..., None]
    return pintado(img)


def bandeira():
    w, h = 768, 512
    im = Image.new("RGB", (w, h), (0, 136, 62))
    d = ImageDraw.Draw(im)
    d.polygon([(w * 0.085, h / 2), (w / 2, h * 0.115), (w * 0.915, h / 2), (w / 2, h * 0.885)], fill=(248, 206, 36))
    r = h * 0.25
    d.ellipse([w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=(26, 52, 124))
    d.arc([w / 2 - r * 1.9, h / 2 - r * 0.42, w / 2 + r * 1.2, h / 2 + r * 2.2], 258, 334, fill=(246, 246, 240), width=int(r * 0.13))
    a = np.asarray(im, float) / 255
    pano = cv2.resize(ruido(512, 2.2, (1, 3), 77), (w, h))
    a = a * (0.86 + 0.22 * pano)[..., None]
    return pintado(a)


def matricula(texto="PE-3476"):
    w, h = 1024, 256
    im = Image.new("L", (w, h), 0)
    fonte = None
    for caminho in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "C:/Windows/Fonts/arialbd.ttf",
                    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
        if os.path.exists(caminho):
            fonte = ImageFont.truetype(caminho, 170)
            break
    d = ImageDraw.Draw(im)
    caixa = d.textbbox((0, 0), texto, font=fonte)
    d.text(((w - caixa[2] + caixa[0]) / 2 - caixa[0], (h - caixa[3] + caixa[1]) / 2 - caixa[1]), texto, fill=255, font=fonte)
    alfa = np.asarray(im, float) / 255
    gasto = cv2.resize(ruido(512, 1.6, (3, 1), 91), (w, h))
    alfa = alfa * (1 - 0.75 * degrau(0.62, 0.8, gasto))                 # tinta da matrícula falhada
    rgba = np.dstack([np.full((h, w), 28), np.full((h, w), 30), np.full((h, w), 36), alfa * 235]).astype(np.uint8)
    return rgba


# ------------------------------------------------------------------ ilha

def areia(semente):
    """Areia de praia: grão fino, ondulações do vento e manchas mais úmidas."""
    yy, xx = np.mgrid[0:N, 0:N]
    grao = ruido(N, 0.6, (1, 1), semente)
    torce = (ruido(N, 2.4, (1, 1), semente + 1) - 0.5) * 1.6
    ondas = 0.5 + 0.5 * np.sin((yy / N * 22 + torce * 4.0) * 2 * np.pi)          # 22 riscos: fecha na emenda
    mancha = ruido(N, 2.6, (1, 1), semente + 2)
    base = np.array([0.90, 0.81, 0.61])
    img = base[None, None, :] * (0.90 + 0.07 * (grao - 0.5) + 0.07 * ondas + 0.16 * (mancha - 0.5))[..., None]
    conchas = degrau(0.965, 0.985, ruido(N, 0.35, (1, 1), semente + 3))            # pontinhos claros
    img = img * (1 - conchas[..., None]) + np.array([0.97, 0.94, 0.86]) * conchas[..., None]
    return pintado(img), normal_de_altura(cv2.GaussianBlur(ondas * 0.6 + grao * 0.15, (0, 0), 1.2), 3.0)


def grama(semente):
    """Mato rasteiro: manchas de verdes diferentes e pinceladas curtas em várias direções."""
    larga = ruido(N, 2.3, (1, 1), semente)
    media = ruido(N, 1.5, (1, 1), semente + 1)
    tufos_a = ruido(N, 0.9, (1, 5), semente + 2)
    tufos_b = ruido(N, 0.9, (5, 1), semente + 3)
    tufos = np.maximum(tufos_a, tufos_b)
    escuro, claro, seco = np.array([0.17, 0.33, 0.15]), np.array([0.36, 0.52, 0.22]), np.array([0.55, 0.56, 0.28])
    img = escuro[None, None, :] + (claro - escuro)[None, None, :] * (0.55 * larga + 0.45 * media)[..., None]
    img = img * (0.82 + 0.36 * tufos)[..., None]
    queimado = degrau(0.62, 0.86, ruido(N, 2.0, (1, 1), semente + 4))             # trechos de capim seco
    img = img * (1 - 0.55 * queimado[..., None]) + seco * 0.55 * queimado[..., None]
    return pintado(img), normal_de_altura(cv2.GaussianBlur(tufos, (0, 0), 1.0), 3.5)


def rocha(semente):
    """Pedra vulcânica escura: camadas, rachaduras e manchas de líquen."""
    rng = np.random.default_rng(semente)
    yy, xx = np.mgrid[0:N, 0:N]
    torce_x = (ruido(N, 2.0, (1, 1), semente + 1) - 0.5) * 90.0
    torce_y = (ruido(N, 2.0, (1, 1), semente + 2) - 0.5) * 90.0
    pontos = rng.uniform(0, N, (55, 2))
    copias = np.vstack([pontos + np.array([dx, dy]) * N for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
    d, _ = cKDTree(copias).query(np.column_stack([(xx + torce_x).ravel() % N, (yy + torce_y).ravel() % N]), k=2)
    f1, f2 = d[:, 0].reshape(N, N), d[:, 1].reshape(N, N)
    racha = 1.0 - degrau(0.0, 0.07, (f2 - f1) / (N / np.sqrt(55)))                 # linhas entre os blocos
    camadas = ruido(N, 1.6, (9.0, 1.0), semente + 3)
    grosso = ruido(N, 2.2, (1, 1), semente + 4)
    fino = ruido(N, 0.8, (1, 1), semente + 5)
    base = np.array([0.33, 0.31, 0.30])
    img = base[None, None, :] * (0.72 + 0.34 * camadas + 0.26 * (grosso - 0.5) + 0.12 * (fino - 0.5))[..., None]
    img = img * (1.0 + (grosso - 0.5)[..., None] * np.array([0.10, 0.02, -0.08]))  # ora mais parda, ora mais azulada
    liquen = degrau(0.70, 0.88, ruido(N, 1.9, (1, 1), semente + 6))
    img = img * (1 - 0.5 * liquen[..., None]) + np.array([0.52, 0.55, 0.40]) * 0.5 * liquen[..., None]
    img *= (1.0 - 0.6 * racha)[..., None]
    altura = -0.9 * racha + 0.5 * camadas + 0.3 * grosso
    return pintado(img), normal_de_altura(cv2.GaussianBlur(altura, (0, 0), 0.9), 6.0)


def telhas(semente):
    """Telhado de barro: fileiras de telhas arredondadas, cada uma num tom."""
    rng = np.random.default_rng(semente)
    yy, xx = np.mgrid[0:N, 0:N]
    fileiras, colunas = 8, 16
    ah, lw = N / fileiras, N / colunas
    fy = (yy % ah) / ah
    fx = (xx % lw) / lw
    lombo = np.sqrt(np.clip(1.0 - (fx * 2 - 1) ** 2, 0, 1))                         # cada telha é meio cano
    sombra = degrau(0.0, 0.16, fy)                                                 # a fileira de cima faz sombra
    tom = rng.uniform(-0.12, 0.12, (fileiras, colunas))[(yy // ah).astype(int) % fileiras, (xx // lw).astype(int) % colunas]
    base = np.array([0.74, 0.35, 0.19])
    img = base[None, None, :] * ((0.55 + 0.5 * lombo) * (0.62 + 0.38 * sombra) * (1.0 + tom) + 0.06 * (ruido(N, 1.2, (1, 1), semente + 1) - 0.5))[..., None]
    musgo = degrau(0.72, 0.9, ruido(N, 2.0, (1, 1), semente + 2)) * 0.35
    img = img * (1 - musgo[..., None]) + np.array([0.30, 0.34, 0.22]) * musgo[..., None]
    return pintado(img), normal_de_altura(cv2.GaussianBlur(lombo * 1.2 + sombra * 0.6, (0, 0), 1.0), 5.0)


def reboco(semente):
    """Parede caiada: manchas de umidade, pinceladas e rachaduras finas. Fica clara, para ser tingida no jogo."""
    larga = ruido(N, 2.6, (1, 1), semente)
    pincel = ruido(N, 1.7, (4.0, 1.0), semente + 1)
    escorrido = degrau(0.6, 0.9, ruido(N, 1.5, (0.6, 12.0), semente + 2))
    img = np.array([0.95, 0.93, 0.88])[None, None, :] * (0.92 + 0.10 * (larga - 0.5) + 0.07 * (pincel - 0.5))[..., None]
    img = img * (1 - 0.16 * escorrido[..., None])
    falha = degrau(0.80, 0.84, ruido(N, 1.9, (1, 1), semente + 3))                 # reboco caído: aparece o tijolo
    img = img * (1 - falha[..., None]) + np.array([0.66, 0.42, 0.30]) * falha[..., None]
    return pintado(img), normal_de_altura(cv2.GaussianBlur(pincel * 0.3 - falha * 0.6, (0, 0), 1.0), 3.0)


# ------------------------------------------------------------------ oceano

def normal_ondas(semente, beta, direcao, abertura, forca, n=1024):
    """Mapa de normais de água: espectro de ondas com uma direção de vento, sem emenda."""
    rng = np.random.default_rng(semente)
    fx = np.fft.fftfreq(n)[None, :] * n
    fy = np.fft.fftfreq(n)[:, None] * n
    k = np.sqrt(fx * fx + fy * fy)
    k[0, 0] = 1
    ang = np.arctan2(fy, fx)
    lobulo = np.abs(np.cos(ang - direcao)) ** abertura            # ondas correm mais numa direção
    amp = lobulo / k ** beta * np.exp(-(3.0 / k) ** 2)            # corta as ondas maiores que a textura
    amp[0, 0] = 0
    h = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((n, n))) * amp))
    h /= np.abs(h).max()
    h = np.sign(h) * np.abs(h) ** 0.85                            # cristas um pouco mais agudas
    return normal_de_altura(h, forca), h


def espuma(semente, n=1024):
    """Renda de espuma: bordas de células (Worley) em duas escalas, roídas por ruído."""
    rng = np.random.default_rng(semente)
    yy, xx = np.mgrid[0:n, 0:n]
    # entorta a grade antes de medir: as paredes das bolhas ficam curvas, e não retas como vidro trincado
    torce_x = (ruido(n, 2.2, (1, 1), semente + 11) - 0.5) * 110.0 + (ruido(n, 1.4, (1, 1), semente + 13) - 0.5) * 26.0
    torce_y = (ruido(n, 2.2, (1, 1), semente + 12) - 0.5) * 110.0 + (ruido(n, 1.4, (1, 1), semente + 14) - 0.5) * 26.0
    pontos_px = np.column_stack([(xx + torce_x).ravel() % n, (yy + torce_y).ravel() % n]).astype(float)
    total = np.zeros((n, n))
    for qtd, peso, largura in ((46, 0.65, 0.30), (300, 0.45, 0.34)):
        p = rng.uniform(0, n, (qtd, 2))
        copias = np.vstack([p + np.array([dx, dy]) * n for dx in (-1, 0, 1) for dy in (-1, 0, 1)])
        d, _ = cKDTree(copias).query(pontos_px, k=2)
        f1 = d[:, 0].reshape(n, n)
        f2 = d[:, 1].reshape(n, n)
        celula = n / np.sqrt(qtd)
        borda = 1.0 - degrau(0.0, largura, (f2 - f1) / celula)      # 1 na parede entre duas bolhas
        total = np.maximum(total, borda * peso / 0.65)
    roer = ruido(n, 1.8, (1, 1), semente + 5)
    total = total * (0.40 + 0.80 * roer) + 0.42 * degrau(0.50, 0.9, ruido(n, 2.3, (1, 1), semente + 6))
    total = cv2.GaussianBlur(np.clip(total, 0, 1), (0, 0), 1.6)
    return (np.clip(total, 0, 1) * 255).astype(np.uint8)


def pigmento(semente, n=1024):
    """Manchas de aquarela: variação larga de cor da água, com pinceladas alongadas."""
    a = 0.65 * ruido(n, 2.3, (1.5, 1.0), semente) + 0.35 * ruido(n, 1.5, (2.2, 1.0), semente + 1)
    u8 = (np.clip(a, 0, 1) * 255).astype(np.uint8)
    return borrar_sem_emenda(u8, lambda e: cv2.bilateralFilter(e, 11, 30, 9))


def gerar():
    barco = os.path.join(RAIZ, "assets", "texturas", "barco")
    mar = os.path.join(RAIZ, "assets", "texturas", "mar")
    madeira = (0.46, 0.33, 0.22)
    receitas = {
        "casco_branco": dict(cor=(0.90, 0.87, 0.80), fundo=madeira, semente=10, desgaste=0.12, ferrugem=0.22),
        "casco_vermelho": dict(cor=(0.60, 0.17, 0.12), fundo=(0.30, 0.20, 0.16), semente=20, desgaste=0.26, ferrugem=0.15),
        "pintura_azul": dict(cor=(0.16, 0.36, 0.58), fundo=madeira, semente=30, desgaste=0.22, ferrugem=0.2),
        "pintura_laranja": dict(cor=(0.86, 0.40, 0.17), fundo=madeira, semente=40, desgaste=0.18, ferrugem=0.0),
        "pintura_creme": dict(cor=(0.91, 0.86, 0.74), fundo=madeira, semente=50, desgaste=0.07, ferrugem=0.15),
        "pintura_amarela": dict(cor=(0.88, 0.68, 0.20), fundo=madeira, semente=60, desgaste=0.2, ferrugem=0.0, n_tabuas=6),
        "conves": dict(cor=(0.56, 0.40, 0.25), fundo=madeira, semente=70, desgaste=0.0, madeira_crua=True, veio=0.3,
                       largura_costura=2.6, costura=(0.05, 0.04, 0.04)),
        "madeira_escura": dict(cor=(0.33, 0.22, 0.15), fundo=madeira, semente=80, desgaste=0.0, madeira_crua=True, veio=0.3,
                               n_tabuas=4),
    }
    for nome, r in receitas.items():
        cor, normal = tabuas(**r)
        salvar(os.path.join(barco, nome + ".png"), cor)
        salvar(os.path.join(barco, nome + "_normal.png"), normal)
        print("barco:", nome)
    cor, normal = metal((0.42, 0.47, 0.52), 90)
    salvar(os.path.join(barco, "metal.png"), cor)
    salvar(os.path.join(barco, "metal_normal.png"), normal)
    cor, normal = corda(95)
    salvar(os.path.join(barco, "corda.png"), cor)
    salvar(os.path.join(barco, "corda_normal.png"), normal)
    salvar(os.path.join(barco, "rede.png"), rede(97))
    salvar(os.path.join(barco, "bandeira.png"), bandeira())
    cv2.imwrite(os.path.join(barco, "matricula.png"), cv2.cvtColor(matricula(), cv2.COLOR_RGBA2BGRA))

    ilha = os.path.join(RAIZ, "assets", "texturas", "ilha")
    for nome, func, semente in (("areia", areia, 110), ("grama", grama, 120), ("rocha", rocha, 130),
                                ("telhas", telhas, 140), ("reboco", reboco, 150)):
        cor, normal = func(semente)
        salvar(os.path.join(ilha, nome + ".png"), cor)
        if nome not in ("areia", "grama"):                     # o chão não usa relevo (PC fraco agradece)
            salvar(os.path.join(ilha, nome + "_normal.png"), cv2.resize(normal, (512, 512), interpolation=cv2.INTER_AREA))
        print("ilha:", nome)
    cor, _ = tabuas(**receitas["conves"])
    salvar(os.path.join(ilha, "madeira.png"), cor)

    n1, _ = normal_ondas(1, 2.45, 0.5, 2.0, 70.0)
    n2, _ = normal_ondas(2, 1.85, -0.9, 0.6, 30.0)
    salvar(os.path.join(mar, "ondas_normal.png"), n1)
    salvar(os.path.join(mar, "marolas_normal.png"), n2)
    cv2.imwrite(os.path.join(mar, "espuma.png"), espuma(3))
    cv2.imwrite(os.path.join(mar, "pigmento.png"), pigmento(4))
    print("mar: ondas_normal, marolas_normal, espuma, pigmento")


if __name__ == "__main__":
    gerar()
