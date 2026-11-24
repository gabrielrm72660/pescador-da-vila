#!/usr/bin/env python3
"""v0.8.7: sons do horror da noite, sintetizados (assets/sons/*.ogg):
  sussurro.ogg  - vozes que não dizem nada: ruído soprado com formantes de vogal que mudam devagar, entrando e saindo
  batida.ogg    - três pancadas surdas no casco, por baixo (madeira molhada + grave que reverbera no porão)
  canto.ogg     - o canto da Mãe-d'água: voz sem palavras, sobe e desce em intervalos estranhos, com eco longo
  grave.ogg     - a coisa de baixo: ronco muito grave que cresce, com batimento lento entre duas notas próximas
  sino_bordo.ogg- o sino de bronze do barco (parciais inarmônicos de sino de verdade)
Uso: python3 ferramentas/gerar_sons_bruma.py   (precisa de numpy e ffmpeg)"""
import pathlib, subprocess, wave
import numpy as np

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SR = 44100
rng = np.random.default_rng(87)


def salvar(nome, s):
    s = s / (np.max(np.abs(s)) + 1e-9) * 0.85
    wav = RAIZ / "ferramentas" / ("_%s.wav" % nome)
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((s * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "4",
                    str(RAIZ / "assets" / "sons" / (nome + ".ogg"))], check=True)
    wav.unlink()
    print("assets/sons/%s.ogg" % nome)


def ressonador(x, f, q):
    """Filtro passa-faixa de 2 polos (biquad simples), f pode variar no tempo (array)."""
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    f = np.broadcast_to(f, x.shape)
    for i in range(len(x)):
        w = 2 * np.pi * f[i] / SR
        r = np.exp(-w / (2 * q))
        a1 = -2 * r * np.cos(w)
        a2 = r * r
        y0 = (1 - r) * x[i] - a1 * y1 - a2 * y2
        y[i] = y0
        y2, y1 = y1, y0
    return y


def eco(s, atrasos):
    out = s.copy()
    for d, g in atrasos:
        k = int(d * SR)
        out[k:] += s[:-k] * g
    return out


def sussurro():
    dur = 4.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    ruido = rng.standard_normal(n)
    # formantes de vogais sopradas (a, e, o, u) trocando devagar
    f1 = 500 + 250 * np.sin(2 * np.pi * 0.7 * t + 1.0) + 120 * np.sin(2 * np.pi * 1.9 * t)
    f2 = 1500 + 600 * np.sin(2 * np.pi * 0.45 * t) + 300 * np.sin(2 * np.pi * 1.3 * t + 2.0)
    s = ressonador(ruido, f1, 6) + 0.7 * ressonador(ruido, f2, 8)
    # sílabas: rajadas curtas, irregulares
    silabas = np.zeros(n)
    tt = 0.2
    while tt < dur - 0.3:
        d = rng.uniform(0.12, 0.28)
        i0, i1 = int(tt * SR), int((tt + d) * SR)
        silabas[i0:i1] = np.sin(np.linspace(0, np.pi, i1 - i0)) ** 1.5 * rng.uniform(0.5, 1.0)
        tt += d + rng.uniform(0.04, 0.35)
    s *= np.convolve(silabas, np.ones(400) / 400, "same")
    s *= np.clip(t / 0.8, 0, 1) * np.clip((dur - t) / 1.0, 0, 1)
    salvar("sussurro", eco(s, [(0.09, 0.4), (0.21, 0.25), (0.47, 0.12)]))


def batida():
    dur = 2.6
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for t0, g in ((0.05, 1.0), (0.62, 0.8), (1.05, 1.0)):
        i0 = int(t0 * SR)
        tl = t[: n - i0]
        golpe = (np.sin(2 * np.pi * 62 * tl) * np.exp(-tl / 0.18) + 0.6 * np.sin(2 * np.pi * 118 * tl) * np.exp(-tl / 0.07)
                 + 0.35 * np.convolve(rng.standard_normal(len(tl)), np.ones(25) / 25, "same") * np.exp(-tl / 0.02))
        s[i0:] += g * golpe
    s = np.tanh(s * 1.4)
    salvar("batida", eco(s, [(0.11, 0.35), (0.26, 0.2)]))


def canto():
    dur = 9.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    # notas: intervalos "errados" (trítono, segunda menor), deslizando entre elas
    notas = [(0.0, 392.0), (1.4, 554.4), (2.6, 523.3), (4.0, 370.0), (5.3, 415.3), (6.8, 349.2)]
    f = np.zeros(n)
    for i, (t0, fr) in enumerate(notas):
        t1 = notas[i + 1][0] if i + 1 < len(notas) else dur
        i0, i1 = int(t0 * SR), int(t1 * SR)
        f[i0:i1] = fr
    f = np.convolve(f, np.ones(9000) / 9000, "same")                   # glissando entre as notas
    f[f < 100] = 349.2
    f *= 1 + 0.012 * np.sin(2 * np.pi * 5.1 * t)                      # vibrato
    fase = 2 * np.pi * np.cumsum(f) / SR
    voz = sum(a * np.sin(h * fase) for h, a in ((1, 1.0), (2, 0.35), (3, 0.18), (4, 0.06)))
    voz += 0.08 * rng.standard_normal(n) * (0.5 + 0.5 * np.sin(fase))  # sopro na voz
    voz = ressonador(voz, 700.0, 2.2) * 0.6 + voz * 0.4               # formante "oo"
    env = np.clip(t / 1.5, 0, 1) * np.clip((dur - t) / 2.0, 0, 1)
    s = voz * env
    salvar("canto", eco(s, [(0.31, 0.45), (0.67, 0.3), (1.1, 0.2), (1.7, 0.12)]))


def grave():
    dur = 7.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * 38 * t) + 0.9 * np.sin(2 * np.pi * 39.3 * t) + 0.4 * np.sin(2 * np.pi * 76.5 * t)
    s += 0.3 * np.convolve(rng.standard_normal(n), np.ones(600) / 600, "same") * 8
    env = np.clip(t / 3.5, 0, 1) ** 1.6 * np.clip((dur - t) / 2.0, 0, 1)
    salvar("grave", np.tanh(s * env * 0.9))


def sino_bordo():
    dur = 4.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = 523.0
    s = np.zeros(n)
    for razao, a, dec in ((0.5, 0.6, 2.8), (1.0, 1.0, 2.2), (1.2, 0.5, 1.6), (1.5, 0.35, 1.2), (2.0, 0.45, 1.0), (2.51, 0.2, 0.7), (3.0, 0.15, 0.5)):
        s += a * np.sin(2 * np.pi * base * razao * t) * np.exp(-t / dec)
    s += 0.4 * rng.standard_normal(n) * np.exp(-t / 0.004)
    salvar("sino_bordo", eco(s, [(0.18, 0.2), (0.4, 0.1)]))


if __name__ == "__main__":
    sussurro(); batida(); canto(); grave(); sino_bordo()
