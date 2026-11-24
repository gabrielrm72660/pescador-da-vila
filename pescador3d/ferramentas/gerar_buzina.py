#!/usr/bin/env python3
"""v0.7.9: buzina náutica (assets/sons/buzina.ogg), sintetizada. Duas notas graves juntas (Lá1 ~110 Hz e Dó#2 ~138 Hz,
como os apitos de dois tons dos pesqueiros), timbre de palheta (harmônicos ímpares fortes), ataque de 90 ms com um
"engasgo" de ar no início, 1,9 s de som e cauda com eco curto (o som voltando do mar).
Uso: python3 ferramentas/gerar_buzina.py   (precisa de numpy e ffmpeg)"""
import pathlib, subprocess, wave
import numpy as np

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SR = 44100
DUR = 1.9
CAUDA = 1.3


def tom(f, t, vib):
    fase = 2 * np.pi * np.cumsum(f * (1 + vib)) / SR
    s = np.zeros_like(t)
    for h, a in ((1, 1.0), (2, 0.45), (3, 0.62), (4, 0.22), (5, 0.38), (6, 0.10), (7, 0.20), (9, 0.10), (11, 0.05)):
        s += a * np.sin(h * fase + h * 0.3)
    return s


def main():
    n = int((DUR + CAUDA) * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(7)
    vib = 0.004 * np.sin(2 * np.pi * 5.2 * t) + 0.002 * np.convolve(rng.standard_normal(n), np.ones(800) / 800, "same")
    queda = np.where(t < 0.12, -0.06 * (1 - t / 0.12), 0.0)              # a nota sobe um pouco no ataque
    s = tom(110.0, t, vib + queda) + 0.8 * tom(138.6, t, vib * 1.1 + queda)
    env = np.clip(t / 0.09, 0, 1) * np.where(t < DUR, 1.0, np.exp(-(t - DUR) / 0.09))
    s *= env
    ar = rng.standard_normal(n) * np.exp(-t / 0.08) * 0.25                # engasgo de ar no começo
    s += np.convolve(ar, np.ones(30) / 30, "same")
    s = np.tanh(s * 0.55)                                                  # saturação de palheta
    eco = np.zeros(n)
    for atraso, g in ((0.23, 0.32), (0.41, 0.20), (0.67, 0.12), (0.95, 0.07)):
        k = int(atraso * SR)
        eco[k:] += s[:-k] * g
    s = s + np.convolve(eco, np.ones(60) / 60, "same")                     # eco mais abafado que o som direto
    s *= 0.85 / np.max(np.abs(s))
    wav = RAIZ / "ferramentas" / "_buzina.wav"
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((s * 32767).astype(np.int16).tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "5",
                    str(RAIZ / "assets" / "sons" / "buzina.ogg")], check=True)
    wav.unlink()
    print("assets/sons/buzina.ogg")


if __name__ == "__main__":
    main()
