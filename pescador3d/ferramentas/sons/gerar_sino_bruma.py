"""v0.6.0: sino de boia ao longe, para as noites de bruma. Um golpe grave de bronze, cauda longa
(parciais inarmônicos de sino), abafado como se viesse de dentro da névoa. Saída: assets/sons/sino_bruma.ogg"""
import subprocess, numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
rng = np.random.default_rng(6)
dur = 9.0
n = int(dur * SR)
tt = np.arange(n) / SR
base = 232.0                                   # grave: é um sino de boia, não de barco
parciais = [(0.5, 0.40, 3.2), (1.0, 1.00, 2.6), (1.19, 0.55, 2.1), (1.5, 0.30, 1.6), (2.0, 0.50, 1.4),
            (2.51, 0.20, 1.0), (2.66, 0.16, 0.9), (3.01, 0.12, 0.7), (4.1, 0.06, 0.4)]
s = np.zeros(n)
for r, amp, dec in parciais:
    f = base * r * (1 + rng.uniform(-0.002, 0.002))
    bat = 1 + 0.18 * np.sin(2 * np.pi * rng.uniform(0.7, 1.8) * tt)          # batimento lento
    s += amp * np.sin(2 * np.pi * f * tt) * bat * np.exp(-tt / dec)
s *= np.minimum(1, tt * SR / 90)                                              # ataque curto, sem estalo
# abafa: passa-baixa suave (distância) e um pouco de eco de névoa
b, a = butter(2, 1500 / (SR / 2), "low")
s = lfilter(b, a, s)
eco = np.zeros(n)
for atraso, g in [(0.23, 0.35), (0.47, 0.22), (0.81, 0.13), (1.3, 0.08)]:
    k = int(atraso * SR)
    eco[k:] += g * s[:-k]
s = s + eco
s *= np.minimum(1, (dur - tt) / 1.5)
s = s / np.max(np.abs(s)) * 0.8
est = np.stack([s * 0.95, np.roll(s, 90) * 0.85], axis=1)                     # leve diferença entre os ouvidos
wavfile.write("/tmp/sino_bruma.wav", SR, (est * 32767).astype(np.int16))
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", "/tmp/sino_bruma.wav", "-c:a", "libvorbis", "-q:a", "4",
                "assets/sons/sino_bruma.ogg"], check=True)
print("ok", dur, "s")
