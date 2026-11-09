"""Sintetiza todos os sons do Náufrago e grava em jogo/sons/*.ogg.

Uso (na pasta naufrago_mobile):   python arte/gerar_sons.py
Precisa de: numpy, scipy e ffmpeg (com libvorbis) no PATH.
Sem ffmpeg:                       python arte/gerar_sons.py --wav     (grava .wav, que o jogo também lê)
Só alguns sons:                   python arte/gerar_sons.py corda tesouro

Nada aqui é gravação: são ruídos filtrados, ondas e envelopes. Para mudar um som, edite a função
dele abaixo (ou o volume dele em Som/ganhos dentro de main.py) e rode o script de novo.
Os ambientes (mar, vento, chuva, esteira, horror) são feitos para repetir sem emenda.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy import signal
from scipy.io import wavfile

SR = 44100
RNG = np.random.default_rng(1913)
AQUI = os.path.dirname(os.path.abspath(__file__))
DESTINO = os.path.join(os.path.dirname(AQUI), "jogo", "sons")


# ----------------------------------------------------------------------------- ferramentas
def tempo(dur):
    return np.arange(int(dur * SR)) / SR


def passa(x, tipo, fc, ordem=2):
    return signal.sosfilt(signal.butter(ordem, fc, btype=tipo, fs=SR, output="sos"), x)


def banda(x, f1, f2, ordem=2):
    return signal.sosfilt(signal.butter(ordem, [f1, min(f2, SR / 2 - 100)], btype="bandpass",
                                        fs=SR, output="sos"), x)


def ruido(dur, rg=None):
    return (rg or RNG).standard_normal(int(dur * SR))


def seno(f, dur, fase=0.0):
    return np.sin(2 * np.pi * f * tempo(dur) + fase)


def varrer(f0, f1, dur, curva=1.0):
    """Seno que desliza de f0 a f1 (curva > 1: demora para sair de f0)."""
    u = tempo(dur) / dur
    f = f0 + (f1 - f0) * u ** curva
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def serra(f0, f1, dur):
    u = tempo(dur) / dur
    return signal.sawtooth(2 * np.pi * np.cumsum(f0 + (f1 - f0) * u) / SR)


def env(dur, ataque, queda):
    """Sobe em 'ataque' s e cai exponencialmente com constante 'queda' s."""
    t = tempo(dur)
    return np.minimum(t / max(ataque, 1e-4), 1.0) * np.exp(-t / queda)


def sino_env(dur, centro, largura):
    """Montinho suave (gaussiana) de amplitude, para swells."""
    return np.exp(-0.5 * ((tempo(dur) - centro) / largura) ** 2)


def bolha(f0, f1, dur=0.07, ganho=1.0):
    """Estalo de bolha: seno que desliza rápido, com queda curta."""
    return varrer(f0, f1, dur) * env(dur, 0.003, dur * 0.3) * ganho


def desloca(x, t0):
    return np.concatenate([np.zeros(int(t0 * SR)), x])


def mistura(*partes):
    n = max(len(p) for p in partes)
    out = np.zeros(n)
    for p in partes:
        out[:len(p)] += p
    return out


def eco(x, taps):
    """Reverberação barata: cópias atrasadas e mais fracas [(atraso_s, ganho), ...]."""
    n = len(x) + int(max(d for d, _ in taps) * SR)
    out = np.zeros(n)
    out[:len(x)] += x
    for d, g in taps:
        i = int(d * SR)
        out[i:i + len(x)] += x * g
    return out


def normalizar(x, pico=0.9):
    x = np.tanh(1.15 * x) / np.tanh(1.15)
    return x * (pico / (np.max(np.abs(x)) + 1e-9))


def laco_ruido(dur, filtro, fonte=None, xf=0.6):
    """Ruído filtrado que repete sem emenda (emenda feita com fusão de potência igual). RMS = 1."""
    n, k, aq = int(dur * SR), int(xf * SR), int(0.5 * SR)
    total = n + k + aq
    bruto = fonte(total) if fonte else RNG.standard_normal(total)
    s = filtro(bruto)[aq:]
    u = np.linspace(0, 1, k)
    out = s[:n].copy()
    out[:k] = s[:k] * np.sin(u * np.pi / 2) + s[n:n + k] * np.cos(u * np.pi / 2)
    return out / (np.std(out) + 1e-9)


def lfo(dur, partes):
    """Soma de senos com frequências múltiplas de 1/dur (então fecham o laço): [(k, amp, fase)]."""
    t = tempo(dur)
    return sum(a * np.sin(2 * np.pi * (k / dur) * t + f) for k, a, f in partes)


def estereo(e, d):
    return np.stack([e, d], axis=1)


# ----------------------------------------------------------------------------- ambientes (loops)
def mar():
    dur, saidas = 12.0, []
    for lado in range(2):
        grave = laco_ruido(dur, lambda x: passa(x, "low", 520))
        espuma = laco_ruido(dur, lambda x: banda(x, 1300, 5200))
        ph = RNG.uniform(0, 2 * np.pi, 3)
        sw = 0.5 + 0.5 * lfo(dur, [(2, 0.6, ph[0]), (3, 0.4, ph[1])])
        sw = np.clip(sw, 0, 1) ** 2
        saidas.append(grave * (0.30 + 0.70 * sw) + espuma * (0.015 + 0.10 * sw ** 2.5))
    return estereo(*saidas)


def vento():
    dur, saidas = 10.0, []
    for lado in range(2):
        ph = RNG.uniform(0, 2 * np.pi, 3)
        rajada = np.clip(0.55 + lfo(dur, [(2, 0.30, ph[0]), (5, 0.15, ph[1])]), 0.05, 1.0)
        assobio = np.clip(lfo(dur, [(3, 1.0, ph[2])]), 0, 1) ** 2
        corpo = laco_ruido(dur, lambda x: banda(x, 140, 1100))
        fino = laco_ruido(dur, lambda x: banda(x, 760, 900, 3))
        saidas.append(corpo * rajada + fino * assobio * 0.9)
    return estereo(*saidas)


def _gota(f0, dur, queda, fase=0.0):
    """Um 'plip' de gota: seno curto que sobe um pouco de tom (como bolha) e some rápido."""
    t = tempo(dur)
    return np.sin(2 * np.pi * (f0 * t + 0.5 * (0.35 * f0 / dur) * t ** 2) + fase) * \
        np.minimum(t / 0.0015, 1.0) * np.exp(-t / queda)


def chuva():
    """Chuva fina caindo na água: um sussurro macio e escuro por baixo e muitas gotinhas pequenas por cima.

    Antes era um chiado agudo (centro em ~7 kHz) com estalos esparsos, o que soava como estática. Agora:
    - o leito é ruído entre 250 Hz e 3,5 kHz, sem brilho cortante;
    - as gotas são 'plips' curtos, em grande número, de volumes bem diferentes (quase todas fracas),
      independentes em cada lado para dar largura;
    - algumas batidas surdas no convés (grave, bem baixas) dão corpo.
    As gotas dão a volta no fim do arquivo, então o ciclo fecha sem emenda.
    """
    rg = np.random.default_rng(404)         # próprio: a chuva não muda quando outros sons mudam
    dur, saidas = 8.0, []
    n = int(dur * SR)
    banco = [_gota(rg.uniform(1000, 3400), 0.05, rg.uniform(0.005, 0.011)) for _ in range(40)]
    surdas = [_gota(rg.uniform(220, 520), 0.09, rg.uniform(0.014, 0.026)) for _ in range(10)]
    ruido_rg = lambda m: rg.standard_normal(m)
    for lado in range(2):
        leito = laco_ruido(dur, lambda x: passa(banda(x, 250, 3500), "low", 4200), fonte=ruido_rg)
        ph = rg.uniform(0, 2 * np.pi, 2)
        rajada = 1.0 + 0.16 * lfo(dur, [(1, 1.0, ph[0]), (3, 0.5, ph[1])])
        gotas = np.zeros(n)
        for _ in range(int(dur * 85)):              # ~85 gotinhas por segundo em cada lado
            g = banco[rg.integers(len(banco))]
            amp = min(rg.exponential(0.30), 1.0) + 0.04
            idx = (int(rg.integers(n)) + np.arange(len(g))) % n
            gotas[idx] += g * amp
        for _ in range(int(dur * 4)):               # batidas surdas no convés
            g = surdas[rg.integers(len(surdas))]
            idx = (int(rg.integers(n)) + np.arange(len(g))) % n
            gotas[idx] += g * (0.10 + 0.20 * rg.random())
        ar = laco_ruido(dur, lambda x: banda(x, 3500, 6500), fonte=ruido_rg) * 0.02   # um fiapo de ar
        saidas.append(leito * 0.30 * rajada + gotas * 0.55 + ar)
    return estereo(*saidas)


def esteira():
    dur, saidas = 6.0, []
    for lado in range(2):
        ph = RNG.uniform(0, 2 * np.pi)
        saidas.append(laco_ruido(dur, lambda x: banda(x, 600, 3600)) * (0.8 + 0.2 * lfo(dur, [(3, 1, ph)])))
    return estereo(*saidas)


def horror():
    """Zumbido grave e vozes distantes. Sobe com a loucura e com a proximidade das criaturas."""
    dur, saidas = 16.0, []
    t = tempo(dur)
    for lado in range(2):
        ph = RNG.uniform(0, 2 * np.pi, 8)
        respira = 0.65 + 0.35 * lfo(dur, [(2, 1.0, ph[0])])
        zumbido = (np.sin(2 * np.pi * 55.0 * t) + np.sin(2 * np.pi * 55.75 * t + ph[1])
                   + 0.6 * np.sin(2 * np.pi * 82.5 * t + ph[2]) + 0.4 * np.sin(2 * np.pi * 110.25 * t + ph[3]))
        agudo = 0.05 * np.sin(2 * np.pi * 1480.0 * t + ph[4]) * (0.5 + 0.5 * lfo(dur, [(3, 1, ph[5])]))
        vozes = laco_ruido(dur, lambda x: banda(x, 900, 2800, 3))
        vozes *= np.clip(lfo(dur, [(5, 0.7, ph[6]), (7, 0.5, ph[7])]), 0, 1) ** 2 * 0.22
        sub = laco_ruido(dur, lambda x: passa(x, "low", 70, 3)) * 0.8
        saidas.append((zumbido * 0.28 + sub * 0.5 + agudo + vozes) * respira)
    return estereo(*saidas)


# ----------------------------------------------------------------------------- efeitos
def remo(semente):
    """Remada suave: a pá entra na água (um 'tchlup' abafado, sem ataque seco), arrasta e pinga.

    Antes: espirro de ruído largo até 3,3 kHz + baque de 150 Hz, com o mesmo pico de todos os outros
    efeitos, o que soava mais alto que o próprio mar. Agora o som é escuro (poucos agudos), com subida
    lenta (45 ms), um ranger grave do toleteiro bem baixinho e dois pinguinhos no fim.
    """
    rg = np.random.default_rng(semente)
    entrada = passa(banda(ruido(0.5, rg), 160, 1500), "low", 1600) * env(0.5, 0.045, 0.10)
    arrasto = passa(ruido(0.9, rg), "low", 650) * env(0.9, 0.20, 0.30) * 0.45
    ranger = seno(100 + rg.uniform(-8, 8), 0.12) * env(0.12, 0.015, 0.04) * 0.20
    gotas = mistura(*[desloca(bolha(rg.uniform(900, 1500), rg.uniform(1500, 2400), 0.05, rg.uniform(0.05, 0.10)),
                              rg.uniform(0.30, 0.75)) for _ in range(2)])
    return mistura(desloca(entrada, 0.02), desloca(arrasto, 0.06), ranger, gotas)


def golpe():
    r = ruido(0.7)
    bandas = ((0.06, 350, 900), (0.12, 900, 2200), (0.20, 2000, 5000))
    vento_ = mistura(*[banda(r, f1, f2) * sino_env(0.7, c, 0.06) for c, f1, f2 in bandas])
    cauda = banda(ruido(0.5), 600, 3000) * env(0.5, 0.01, 0.1) * 0.35
    return mistura(vento_, desloca(cauda, 0.2))


def acerto():
    corpo = varrer(160, 55, 0.35) * env(0.35, 0.002, 0.09)
    estalo = passa(ruido(0.25), "low", 1500) * env(0.25, 0.001, 0.04) * 0.8
    tapa = banda(ruido(0.15), 1500, 5000) * env(0.15, 0.001, 0.025) * 0.5
    return mistura(corpo, estalo, tapa)


def mordida():
    rachar = banda(ruido(0.25), 700, 5000, 3) * env(0.25, 0.001, 0.03) * 1.2
    boom = varrer(90, 35, 0.8) * env(0.8, 0.004, 0.25) * 1.2
    lascas = [desloca(banda(ruido(0.03), 1500, 6000) * env(0.03, 0.0005, 0.006) * RNG.uniform(0.3, 0.8),
                      RNG.uniform(0.02, 0.28)) for _ in range(6)]
    agua = passa(ruido(0.7), "low", 1800) * env(0.7, 0.05, 0.2) * 0.4
    return mistura(rachar, boom, desloca(agua, 0.05), *lascas)


def tubarao():
    dur = 2.4
    t = tempo(dur)
    swell = np.where(t < 1.6, (t / 1.6) ** 2.2, np.exp(-(t - 1.6) / 0.25))
    tons = seno(46, dur) + seno(49.6, dur) + 0.5 * seno(92, dur) + 0.25 * seno(99.2, dur)
    ar = passa(ruido(dur), "low", 320) * 0.6
    return (tons * 0.5 + ar) * swell


def tentaculo_emerge():
    dur = 3.2
    agua = passa(ruido(dur), "low", 900) * sino_env(dur, 1.6, 0.8)
    bolhas = []
    for _ in range(26):
        t0 = float(np.clip(RNG.beta(2.2, 1.4) * 2.9 + 0.1, 0.1, 2.95))
        f = RNG.uniform(250, 700)
        bolhas.append(desloca(bolha(f, f * 2.2, 0.06, RNG.uniform(0.3, 0.8)), t0))
    t = tempo(dur)
    gemido = np.sin(2 * np.pi * np.cumsum(62 + 4 * np.sin(2 * np.pi * 5 * t)) / SR) * sino_env(dur, 2.0, 0.6) * 0.5
    return mistura(agua * 0.9, gemido, *bolhas)


def tentaculo_golpe():
    batida = varrer(110, 38, 0.7) * env(0.7, 0.003, 0.2) * 1.3
    ranger = banda(serra(150, 92, 0.9), 250, 1800) * env(0.9, 0.05, 0.35) * 0.55
    tapa = banda(ruido(0.4), 400, 3500) * env(0.4, 0.002, 0.07)
    agua = passa(ruido(0.9), "low", 1500) * env(0.9, 0.04, 0.25) * 0.45
    return mistura(batida, ranger, tapa, desloca(agua, 0.04))


def tentaculo_recua():
    arrasto = banda(ruido(1.2), 250, 1500) * env(1.2, 0.05, 0.4) * 0.8
    bolhas = [desloca(bolha(f, f * 0.45, 0.07, 0.5), t0)
              for f, t0 in zip(RNG.uniform(500, 800, 7), np.sort(RNG.uniform(0.05, 0.9, 7)))]
    return mistura(arrasto, *bolhas)


def vulto():
    dur = 3.8
    t = tempo(dur)
    f = 72 + 22 * np.sin(2 * np.pi * 0.31 * t) - 18 * t / dur
    canto = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.45 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    canto *= sino_env(dur, 1.5, 0.75)
    rumor = varrer(36, 27, dur) * sino_env(dur, 1.9, 1.0) * 0.8
    return eco(canto * 0.8 + rumor, [(0.13, 0.45), (0.29, 0.3), (0.5, 0.18)])


def sussurro():
    dur = 2.8
    saida = np.zeros(int(dur * SR))
    for _ in range(int(RNG.integers(5, 8))):
        t0, d = RNG.uniform(0.0, 2.1), RNG.uniform(0.12, 0.34)
        f = RNG.uniform(1300, 3000)
        s = banda(ruido(d), f, f * 1.7, 3) * np.hanning(int(d * SR))
        sibilo = banda(ruido(d * 0.6), 5000, 9000) * np.hanning(int(d * 0.6 * SR)) * 0.35
        trecho = mistura(s, desloca(sibilo, d * 0.5))
        i = int(t0 * SR)
        saida[i:i + len(trecho)] += trecho[:len(saida) - i]
    murmurio = (seno(138, dur) + 0.5 * seno(207, dur)) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * tempo(dur))) \
        * sino_env(dur, 1.4, 0.7) * 0.05
    return eco(saida * 0.8 + murmurio, [(0.09, 0.4), (0.21, 0.25)])


def olhos():
    dur = 1.6
    t = tempo(dur)
    brilho = sum(a * np.sin(2 * np.pi * f * t) for f, a in ((2093.0, 1.0), (2637.6, 0.7), (3136.0, 0.5), (3139.0, 0.4)))
    brilho *= sino_env(dur, 0.65, 0.3) * (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t))
    return eco(brilho * 0.35, [(0.2, 0.4), (0.4, 0.2)])


def trovao():
    dur = 4.8
    estalo = banda(ruido(0.5), 300, 9000) * env(0.5, 0.001, 0.05) * 1.1
    t = tempo(dur)
    retumbo = np.zeros_like(t)
    for _ in range(7):
        retumbo += np.exp(-0.5 * ((t - RNG.uniform(0.1, 2.8)) / RNG.uniform(0.15, 0.5)) ** 2) * RNG.uniform(0.4, 1.0)
    grave = passa(ruido(dur), "low", 160, 3) * 2.2
    medio = passa(ruido(dur), "low", 600) * 0.6 * np.exp(-t / 0.8)
    return mistura(estalo, (grave + medio) * retumbo * np.exp(-t / 1.7))


def pesca_lancar():
    chiado = banda(ruido(0.5), 1500, 6000) * sino_env(0.5, 0.14, 0.07) * 0.8
    plop = varrer(380, 900, 0.09) * env(0.09, 0.003, 0.03)
    espirro = banda(ruido(0.3), 700, 3000) * env(0.3, 0.005, 0.07) * 0.4
    return mistura(chiado, desloca(plop, 0.42), desloca(espirro, 0.42))


def peixe():
    espirro = banda(ruido(0.7), 600, 3500) * env(0.7, 0.01, 0.15)
    tapas = [desloca(banda(ruido(0.1), 500, 2500) * env(0.1, 0.002, 0.025), t0) for t0 in (0.18, 0.3, 0.37)]
    ding = seno(1318.5, 0.5) * env(0.5, 0.002, 0.12) * 0.25
    return mistura(espirro, *tapas, desloca(ding, 0.38))


def beber():
    saida = []
    for t0 in (0.05, 0.38, 0.7):
        glub = varrer(260, 120, 0.12) * env(0.12, 0.005, 0.05)
        bolha = banda(ruido(0.12), 300, 1200) * env(0.12, 0.003, 0.03) * 0.5
        saida.append(desloca(glub + bolha, t0))
    return mistura(*saida)


def comer():
    saida = []
    for t0 in (0.02, 0.16, 0.30, 0.45, 0.58):
        c = banda(ruido(0.05), 800, 4500) * env(0.05, 0.001, 0.012) * RNG.uniform(0.6, 1.0)
        c += seno(RNG.uniform(160, 260), 0.05) * env(0.05, 0.001, 0.015) * 0.5
        saida.append(desloca(c, t0 + RNG.uniform(-0.01, 0.01)))
    return mistura(*saida)


def consertar():
    saida = []
    for t0, g in ((0.05, 1.0), (0.38, 0.9), (0.70, 1.0)):
        tok = mistura(seno(480, 0.1) * env(0.1, 0.001, 0.02), seno(190, 0.15) * env(0.15, 0.001, 0.04) * 0.8,
                      banda(ruido(0.03), 1500, 6000) * env(0.03, 0.0005, 0.004) * 0.7)
        saida.append(desloca(tok * g, t0))
    return mistura(*saida)


def lanterna():
    c1 = mistura(banda(ruido(0.03), 2000, 7000) * env(0.03, 0.0005, 0.004),
                 seno(1800, 0.05) * env(0.05, 0.0005, 0.012) * 0.4)
    vidro = seno(3150, 0.3) * env(0.3, 0.001, 0.08) * 0.12
    return mistura(c1, desloca(c1 * 0.5, 0.05), vidro)


def vela():
    saida = []
    for t0, g in ((0.0, 1.0), (0.07, 0.8), (0.15, 0.7), (0.27, 0.5), (0.45, 0.3)):
        saida.append(desloca(passa(ruido(0.15), "low", 1500) * env(0.15, 0.002, 0.035) * g, t0))
    corda = banda(serra(200, 262, 0.7), 300, 1500) * env(0.7, 0.05, 0.3) * 0.06
    return mistura(*saida, corda)


def item():
    def nota(f):
        return (seno(f, 0.4) + 0.3 * seno(2 * f, 0.4) + 0.1 * seno(3 * f, 0.4)) * env(0.4, 0.002, 0.12)
    gota = bolha(400, 800, 0.05, 0.4)
    return mistura(nota(659.3), desloca(nota(987.8), 0.09), gota)


def garrafa():
    vidro = (seno(2400, 0.5) + 0.6 * seno(3720, 0.5) + 0.4 * seno(5100, 0.5)) * env(0.5, 0.0005, 0.09) * 0.5
    rolha = mistura(bolha(250, 800, 0.05), banda(ruido(0.02), 1000, 5000) * env(0.02, 0.0005, 0.004))
    return mistura(vidro, desloca(rolha, 0.25))


def gaivota():
    def grito(f0, f1, dur, voz=35):
        t = tempo(dur)
        u = t / dur
        f = f0 + (f1 - f0) * u + 60 * np.sin(2 * np.pi * voz * t)
        fase = 2 * np.pi * np.cumsum(f) / SR
        s = np.sin(fase) + 0.5 * np.sin(2 * fase) + 0.2 * np.sin(3 * fase)
        return banda(s, 900, 6000) * np.sin(np.pi * np.clip(u, 0, 1)) ** 0.7
    return mistura(grito(1700, 2800, 0.18), desloca(grito(2800, 1500, 0.34), 0.18),
                   desloca(grito(1800, 2900, 0.16), 0.78), desloca(grito(2900, 1600, 0.40), 0.94))


def onda():
    bandas = ((0.45, 250, 0.35), (0.5, 900, 0.3), (0.35, 3500, 0.18))
    r = ruido(2.0)
    partes = []
    for centro, fc, larg in bandas:
        partes.append(passa(r, "low", fc) * sino_env(2.0, centro, larg) * (1.0 if fc < 1000 else 0.5))
    boom = varrer(70, 40, 0.5) * env(0.5, 0.01, 0.15)
    return mistura(*partes, boom * 0.8)


def aviso():
    def nota(f, d=0.5):
        return (seno(f, d) + 0.3 * seno(2 * f, d)) * env(d, 0.003, 0.15)
    return mistura(nota(523.25), desloca(nota(392.0) * 0.9, 0.18))


def nao():
    return mistura(varrer(180, 110, 0.15) * env(0.15, 0.002, 0.045),
                   passa(ruido(0.08), "low", 700) * env(0.08, 0.001, 0.02) * 0.4)


def exausto():
    saida = []
    for c in (0.22, 0.62):
        saida.append(banda(ruido(1.0), 500, 2200) * sino_env(1.0, c, 0.1))
    return mistura(*saida) * 0.8


def noite():
    dur = 3.8
    pad = sum(seno(f, dur) * a for f, a in ((55, 0.8), (110, 1.0), (130.81, 0.7), (164.81, 0.6)))
    pad *= sino_env(dur, 1.5, 0.9)
    sino_ = sum(a * seno(110 * r, 3.0) * env(3.0, 0.002, d) for r, a, d in ((1, 1, 1.8), (2.76, 0.4, 0.9), (5.4, 0.2, 0.4)))
    return eco(mistura(pad * 0.6, sino_ * 0.5), [(0.17, 0.4), (0.37, 0.25)])


def amanhecer():
    dur = 3.8
    pad = sum(seno(f, dur) * a for f, a in ((261.63, 0.8), (329.63, 0.7), (392.0, 0.6), (523.25, 0.4)))
    pad *= sino_env(dur, 1.7, 0.9)
    brilho = seno(1046.5, 1.5) * env(1.5, 0.3, 0.5) * 0.18
    return eco(mistura(pad * 0.55, desloca(brilho, 0.9)), [(0.15, 0.35), (0.33, 0.2)])


def vitoria():
    dur = 5.4
    notas = []
    for t0, f in ((0.0, 261.63), (0.18, 329.63), (0.36, 392.0), (0.54, 523.25), (0.78, 659.26)):
        n = (seno(f, 1.6) + 0.3 * seno(2 * f, 1.6) + 0.1 * seno(3 * f, 1.6)) * env(1.6, 0.003, 0.5)
        notas.append(desloca(n * 0.6, t0))
    pad = sum(seno(f, dur) * 0.5 for f in (261.63, 329.63, 392.0, 523.25)) * sino_env(dur, 2.6, 1.2)
    return eco(mistura(*notas, pad * 0.5), [(0.2, 0.4), (0.45, 0.25), (0.7, 0.15)])


def derrota():
    dur = 4.0
    queda = varrer(196, 98, dur) * sino_env(dur, 1.2, 1.2) * 0.8
    pad = sum(seno(f, dur) * 0.4 for f in (98.0, 116.54, 146.83)) * sino_env(dur, 1.6, 1.1)
    boom = varrer(70, 30, 1.0) * env(1.0, 0.01, 0.35) * 1.1
    bolhas = [desloca(bolha(f, f * 0.5, 0.07, 0.4), t0)
              for f, t0 in zip(RNG.uniform(400, 800, 8), np.sort(RNG.uniform(2.2, 3.8, 8)))]
    return eco(mistura(queda, pad, boom, *bolhas), [(0.22, 0.35), (0.5, 0.2)])


def loucura():
    dur = 5.2
    t = tempo(dur)
    corte = np.where(t < 3.6, (t / 3.6) ** 2, 0.0)
    cluster = sum(np.sin(2 * np.pi * f * t + RNG.uniform(0, 6)) for f in (233.1, 246.9, 261.6, 277.2, 293.7))
    cluster *= corte * (1 + 0.4 * np.sin(2 * np.pi * (4 + 6 * t / 3.6) * t))
    sopro = banda(ruido(dur), 1500, 4500) * corte * 0.5
    boom = varrer(60, 25, 1.2) * env(1.2, 0.005, 0.5) * 1.3
    return eco(mistura(cluster * 0.25, sopro, desloca(boom, 3.6)), [(0.25, 0.4), (0.55, 0.25)])


def clique():
    return mistura(banda(ruido(0.05), 1500, 5000) * env(0.05, 0.0005, 0.006) * 0.6,
                   seno(900, 0.06) * env(0.06, 0.0005, 0.01) * 0.5)


def sino():
    f0 = 330.0
    parc = ((1.0, 1.0, 2.4), (2.0, 0.6, 1.8), (2.4, 0.5, 1.5), (3.0, 0.35, 1.0), (4.07, 0.25, 0.7), (5.43, 0.15, 0.4))
    s = sum(a * seno(f0 * r, 3.4) * env(3.4, 0.001, d) for r, a, d in parc)
    batida = banda(ruido(0.05), 800, 5000) * env(0.05, 0.0005, 0.01) * 0.3
    return eco(mistura(s, batida), [(0.28, 0.25), (0.6, 0.12)])


def coracao():
    def batida(g):
        return mistura(varrer(75, 42, 0.25) * env(0.25, 0.004, 0.07),
                       passa(ruido(0.05), "low", 400) * env(0.05, 0.001, 0.01) * 0.5) * g
    return mistura(batida(1.0), desloca(batida(0.7), 0.27))


# ---- sons acrescentados depois (usam geradores próprios, para não mudar nenhum dos sons anteriores)
def corda():
    """Corda sendo puxada para o convés: fricção de fibras e um toque surdo no fim."""
    rg = np.random.default_rng(777)
    dur = 0.45
    t = tempo(dur)
    fibras = banda(ruido(dur, rg), 1800, 5200) * (0.55 + 0.45 * np.sin(2 * np.pi * 38 * t) ** 2) * env(dur, 0.01, 0.12)
    corpo = banda(ruido(dur, rg), 700, 1600) * env(dur, 0.02, 0.2)
    toque = seno(180, 0.12) * env(0.12, 0.002, 0.035)
    return mistura(fibras * 0.6, corpo * 0.5, desloca(toque * 0.7, 0.18))


def tesouro():
    """Tinidos de ouro: três notas agudas que descem em cascata, com eco de água. Curto e suave."""
    partes = []
    for t0, f in ((0.0, 2093.0), (0.11, 2637.0), (0.23, 3136.0)):
        n = (seno(f, 0.8) + 0.4 * seno(2.01 * f, 0.8) + 0.15 * seno(3.02 * f, 0.8)) * env(0.8, 0.001, 0.16)
        partes.append(desloca(n * 0.5, t0))
    return eco(mistura(*partes), [(0.18, 0.35), (0.4, 0.2)])


def melhoria():
    """Fanfarra curta de sinos subindo em Ré maior, com brilho agudo e um pad suave: o barco evoluiu."""
    rg = np.random.default_rng(909)
    notas = []
    for i, f in enumerate((293.66, 369.99, 440.0, 587.33, 739.99)):
        n = (seno(f, 1.8) + 0.35 * seno(2 * f, 1.8) + 0.15 * seno(3.01 * f, 1.8)) * env(1.8, 0.003, 0.55)
        notas.append(desloca(n * 0.55, i * 0.10))
    brilho = banda(ruido(1.2, rg), 4000, 9000) * sino_env(1.2, 0.45, 0.25) * 0.08
    pad = sum(seno(f, 2.2) for f in (293.66, 440.0, 587.33)) * sino_env(2.2, 0.9, 0.5) * 0.18
    return eco(mistura(*notas, brilho, pad), [(0.2, 0.4), (0.45, 0.25), (0.7, 0.15)])


# nome do arquivo -> (função, pico, estéreo?)
SONS = {
    "mar": (mar, 0.8), "vento": (vento, 0.8), "chuva": (chuva, 0.8), "esteira": (esteira, 0.8), "horror": (horror, 0.85),
    "remo1": (lambda: remo(11), 0.55), "remo2": (lambda: remo(23), 0.55), "remo3": (lambda: remo(37), 0.55),
    "golpe": (golpe, 0.8), "acerto": (acerto, 0.9), "mordida": (mordida, 0.95), "tubarao": (tubarao, 0.85),
    "tentaculo_emerge": (tentaculo_emerge, 0.85), "tentaculo_golpe": (tentaculo_golpe, 0.95),
    "tentaculo_recua": (tentaculo_recua, 0.8), "vulto": (vulto, 0.85), "sussurro": (sussurro, 0.75),
    "olhos": (olhos, 0.6), "trovao": (trovao, 0.95), "pesca_lancar": (pesca_lancar, 0.8), "peixe": (peixe, 0.85),
    "beber": (beber, 0.8), "comer": (comer, 0.8), "consertar": (consertar, 0.85), "lanterna": (lanterna, 0.7),
    "vela": (vela, 0.7), "item": (item, 0.7), "garrafa": (garrafa, 0.7), "gaivota": (gaivota, 0.7),
    "onda": (onda, 0.9), "aviso": (aviso, 0.7), "nao": (nao, 0.7), "exausto": (exausto, 0.7),
    "noite": (noite, 0.8), "amanhecer": (amanhecer, 0.75), "vitoria": (vitoria, 0.85), "derrota": (derrota, 0.85),
    "loucura": (loucura, 0.9), "clique": (clique, 0.6), "sino": (sino, 0.8), "coracao": (coracao, 0.9),
    "corda": (corda, 0.75), "tesouro": (tesouro, 0.7), "melhoria": (melhoria, 0.85),
}


def gravar(nome, x, usar_wav):
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    if usar_wav:
        wavfile.write(os.path.join(DESTINO, nome + ".wav"), SR, pcm)
        return
    with tempfile.TemporaryDirectory() as tmp:
        temp = os.path.join(tmp, nome + ".wav")
        wavfile.write(temp, SR, pcm)
        q = "2" if x.ndim == 2 else "3"
        subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", temp, "-c:a", "libvorbis", "-q:a", q,
                               os.path.join(DESTINO, nome + ".ogg")])


def main():
    usar_wav = "--wav" in sys.argv[1:]
    so = [a for a in sys.argv[1:] if not a.startswith("--")]      # nomes: gera só esses sons
    os.makedirs(DESTINO, exist_ok=True)
    total = 0
    for nome, (fn, pico) in SONS.items():
        if so and nome not in so:
            continue
        x = normalizar(fn(), pico)
        gravar(nome, x, usar_wav)
        total += len(x) / SR
        print("%-18s %5.2f s %s" % (nome, len(x) / SR, "estéreo" if x.ndim == 2 else ""))
    print("%d sons, %.0f s de áudio em %s" % (len(SONS), total, DESTINO))


if __name__ == "__main__":
    main()
