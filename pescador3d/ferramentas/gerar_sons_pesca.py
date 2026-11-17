#!/usr/bin/env python3
"""Sintetiza os efeitos da pescaria (sem arquivos externos) e grava em assets/sons/*.ogg.
Uso:  python3 ferramentas/gerar_sons_pesca.py      (precisa de numpy e do ffmpeg no PATH)

acerto     toque suave quando o ponteiro pega a faixa verde
perfeito   duas notas brilhantes quando pega a parte dourada
estalo     a linha arrebenta
tensao     rangido grave de aviso quando a tensão passa de ~70%
captura    respingo + três notas subindo quando o peixe vem a bordo
"""
import os, subprocess, tempfile, wave
import numpy as np

SR = 44100
PASTA = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sons")
rng = np.random.default_rng(7)


def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, ataque=0.004, queda=6.0):
    t = np.arange(n) / SR
    a = np.minimum(1.0, t / ataque)
    return a * np.exp(-queda * t)


def nota(freq, dur, queda=7.0, harm=(1.0, 0.35, 0.12)):
    t = t_(dur)
    y = sum(h * np.sin(2 * np.pi * freq * (i + 1) * t) for i, h in enumerate(harm))
    return y * env(len(t), queda=queda)


def passa_baixa(x, corte):
    # filtro de um polo, o bastante para amaciar o ruído
    a = np.exp(-2 * np.pi * corte / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def mistura(*partes):
    n = max(p[1] + len(p[0]) for p in partes)
    y = np.zeros(n)
    for sinal, inicio in partes:
        y[inicio:inicio + len(sinal)] += sinal
    return y


def acerto():
    return mistura((nota(520, 0.28, queda=11.0) * 0.8, 0), (nota(780, 0.20, queda=14.0, harm=(1.0,)) * 0.25, 0))


def perfeito():
    return mistura((nota(784, 0.45, queda=6.0), 0), (nota(1175, 0.50, queda=5.0), int(SR * 0.07)),
                   (nota(1568, 0.40, queda=8.0, harm=(1.0,)) * 0.35, int(SR * 0.07)))


def estalo():
    n = int(SR * 0.45)
    ruido = passa_baixa(rng.standard_normal(n), 5000) * env(n, 0.001, 22.0)
    t = np.arange(n) / SR
    corda = np.sin(2 * np.pi * (900 - 700 * t / 0.45) * t) * env(n, 0.001, 9.0) * 0.5
    return ruido * 1.2 + corda


def tensao():
    t = t_(0.55)
    base = np.sin(2 * np.pi * 92 * t) + 0.6 * np.sin(2 * np.pi * 138 * t + 0.6)
    ranger = passa_baixa(rng.standard_normal(len(t)), 700) * 6.0
    mod = 0.55 + 0.45 * np.sin(2 * np.pi * 21 * t)
    return (base * 0.5 + ranger) * mod * np.minimum(1.0, t / 0.05) * np.exp(-2.2 * t)


def captura():
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    respingo = passa_baixa(rng.standard_normal(n), 2600) * (1 - np.exp(-t / 0.02)) * np.exp(-6.5 * t) * 1.4
    notas = mistura((nota(523, 0.3, queda=8.0), int(SR * 0.10)), (nota(659, 0.3, queda=8.0), int(SR * 0.22)),
                    (nota(784, 0.5, queda=6.0), int(SR * 0.34)))
    return mistura((respingo, 0), (notas * 0.55, 0))


def gravar(nome, sinal, ganho=0.8):
    sinal = sinal / max(1e-6, np.max(np.abs(sinal))) * ganho
    pcm = (sinal * 32767).astype("<i2")
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, nome + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        destino = os.path.join(PASTA, nome + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", destino], check=True)
    print("ok", nome, "%.2f s" % (len(sinal) / SR))


if __name__ == "__main__":
    os.makedirs(PASTA, exist_ok=True)
    for nome, fn in [("acerto", acerto), ("perfeito", perfeito), ("estalo", estalo), ("tensao", tensao), ("captura", captura)]:
        gravar(nome, fn())
