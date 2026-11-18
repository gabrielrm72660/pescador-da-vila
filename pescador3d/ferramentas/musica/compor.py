"""Trilhas sonoras do Pescador: Tarde, Final do dia e Noite.
v2 (acústica): violão (Karplus-Strong), cavaquinho, sanfona, marimba, baixo acústico, zabumba e triângulo.
As funções flauta/piano_eletrico/sino_vidro/pad/baixo da v1 ficam no arquivo, mas não são mais usadas.
reverb por convolução com resposta sintética. Sem amostras de terceiros."""
import numpy as np
from scipy import signal
from scipy.io import wavfile
import subprocess, sys

SR = 44100
rng = np.random.default_rng(3)


def mf(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


# ------------------------------------------------------------------ instrumentos

def violao(m, dur, vel=0.8, brilho=0.6, pos=0.18):
    """Corda dedilhada (Karplus-Strong com atraso fracionário) + ressonância de caixa."""
    f = mf(m)
    n = int((dur + 1.2) * SR)
    atraso = SR / f - 0.5
    N = int(np.floor(atraso))
    b = atraso - N + 0.5            # peso para atraso N+b (aprox.)
    b = min(max(b, 0.05), 0.95)
    g = 0.996 - 0.004 * (1 - brilho) - 0.0000015 * f
    ex = rng.standard_normal(N + 2)
    ex = signal.lfilter([1 - 0.55 * (1 - brilho)], [1, -0.55 * (1 - brilho)], ex)      # palhetada mais macia
    k = max(1, int(pos * N))
    ex[k:] -= ex[:-k] * 0.9                                                             # posição do dedo na corda
    x = np.zeros(n)
    x[:len(ex)] = ex
    den = np.zeros(N + 2)
    den[0] = 1.0
    den[N] = -g * (1 - b)
    den[N + 1] = -g * b
    y = signal.lfilter([1.0], den, x)
    # abafa depois da duração (o dedo segura a corda)
    t = np.arange(n) / SR
    y *= np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.12))
    # caixa do violão: duas ressonâncias suaves
    caixa = 0
    for fc, q, a in [(105, 4, 0.35), (210, 5, 0.25), (420, 3, 0.12)]:
        bb, aa = signal.iirpeak(fc, q, SR)
        caixa = caixa + a * signal.lfilter(bb, aa, y)
    y = y + caixa
    y = y / (np.abs(y[:int(0.05 * SR)]).max() + 1e-9)
    return vel * 0.5 * y


def flauta(m, dur, vel=0.7):
    f = mf(m)
    n = int((dur + 0.35) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.0045 * np.sin(2 * np.pi * 5.1 * t + rng.uniform(0, 6)) * np.clip((t - 0.35) / 0.4, 0, 1)
    fase = 2 * np.pi * f * np.cumsum(vib) / SR
    s = np.sin(fase) + 0.22 * np.sin(2 * fase) + 0.07 * np.sin(3 * fase) + 0.03 * np.sin(4 * fase)
    sopro = signal.lfilter(*signal.iirpeak(min(f * 2, 9000), 2.5, SR), rng.standard_normal(n)) * 0.10
    env = np.clip(t / 0.07, 0, 1) ** 1.5 * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.09))
    env *= 1 - 0.12 * np.clip(t / max(dur, 0.1), 0, 1)
    ataque = np.exp(-t / 0.05) * 0.4                              # sopro mais forte no início
    return vel * 0.30 * (s * env + sopro * (env + ataque))


def piano_eletrico(m, dur, vel=0.7):
    """Rhodes simplificado (FM 1:1 com índice caindo) + o 'tine'."""
    f = mf(m)
    n = int((dur + 2.5) * SR)
    t = np.arange(n) / SR
    indice = (1.6 * vel + 0.4) * np.exp(-t / 0.35) + 0.25
    mod = np.sin(2 * np.pi * f * t)
    s = np.sin(2 * np.pi * f * t + indice * mod)
    tine = 0.15 * np.sin(2 * np.pi * f * 7.0 * t) * np.exp(-t / 0.03)
    env = np.exp(-t / (1.6 - 0.006 * (m - 60))) * np.minimum(1, t * SR / 40)
    env *= np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.25))
    return vel * 0.28 * (s + tine) * env


def sino_vidro(m, dur, vel=0.6):
    f = mf(m)
    n = int((dur + 4.0) * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / 2.6) + 0.35 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / 1.2)
         + 0.12 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / 0.6) + 0.05 * np.sin(2 * np.pi * f * 4.2 * t) * np.exp(-t / 0.3))
    return vel * 0.22 * s * np.minimum(1, t * SR / 60)


def pad(notas, dur, vel=0.5, corte=6.0, ataque=1.5, solta=2.5):
    """Pad quente: dentes-de-serra desafinados (aditivo, harmônicos atenuados)."""
    n = int((dur + solta) * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for m in notas:
        f = mf(m)
        for det in (-0.07, 0.0, 0.08):
            fd = f * 2 ** (det / 12)
            fase = rng.uniform(0, 2 * np.pi)
            for k in range(1, 14):
                if fd * k > 5000:
                    break
                y += (1 / k) * np.exp(-k / corte) * np.sin(2 * np.pi * fd * k * t + fase * k)
    env = np.clip(t / ataque, 0, 1) ** 2 * np.where(t < dur, 1.0, np.exp(-(t - dur) / (solta / 3)))
    lfo = 1 + 0.06 * np.sin(2 * np.pi * 0.17 * t)
    return vel * 0.05 * y * env * lfo / max(1, len(notas) ** 0.5)


def baixo(m, dur, vel=0.7):
    f = mf(m)
    n = int((dur + 0.4) * SR)
    t = np.arange(n) / SR
    s = np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.3) + 0.1 * np.sin(6 * np.pi * f * t) * np.exp(-t / 0.15)
    env = np.minimum(1, t * SR / 120) * np.exp(-t / 1.4) * np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.08))
    return vel * 0.45 * s * env


def zabumba(vel=0.8):
    n = int(0.6 * SR)
    t = np.arange(n) / SR
    fq = 58 + 40 * np.exp(-t / 0.04)
    s = np.sin(2 * np.pi * np.cumsum(fq) / SR) * np.exp(-t / 0.22)
    pele = signal.lfilter(*signal.butter(2, [150, 900], "bandpass", fs=SR), rng.standard_normal(n)) * np.exp(-t / 0.02) * 0.4
    return vel * 0.36 * (s + pele)


def bacalhau(vel=0.5):
    """Varinha na pele de baixo da zabumba: estalo seco."""
    n = int(0.12 * SR)
    t = np.arange(n) / SR
    s = signal.lfilter(*signal.butter(2, [900, 4000], "bandpass", fs=SR), rng.standard_normal(n)) * np.exp(-t / 0.018)
    return vel * 0.35 * s


def triangulo(aberto=True, vel=0.5):
    n = int((0.9 if aberto else 0.12) * SR)
    t = np.arange(n) / SR
    dec = 0.55 if aberto else 0.035
    s = 0
    for r, a in [(1.0, 1.0), (2.76, 0.6), (5.40, 0.45), (8.93, 0.3), (13.3, 0.18)]:
        s = s + a * np.sin(2 * np.pi * 1350 * r * t + rng.uniform(0, 6)) * np.exp(-t / (dec / (1 + 0.15 * r)))
    golpe = rng.standard_normal(n) * np.exp(-t / 0.002) * 0.3
    return vel * 0.06 * (s + golpe)




# ------------------------------------------------------------------ instrumentos acústicos (v2)

def sanfona(m, dur, vel=0.7, palhetas=(0.0, 8.0, -6.0), ar=0.04, ataque=0.045):
    """Sanfona (acordeão): palhetas livres levemente desafinadas entre si (o 'tremido' musette),
    câmara de palheta realçando ~1,4 kHz, fole com pequena variação de pressão e o sopro de ar."""
    f = mf(m)
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    fole = 1 + 0.05 * np.sin(2 * np.pi * rng.uniform(0.5, 0.9) * t + rng.uniform(0, 6))
    y = np.zeros(n)
    for cents in palhetas:
        fr = f * 2 ** (cents / 1200)
        k = 1
        while fr * k < 7500 and k <= 30:
            fk = fr * k
            amp = k ** -0.85 * (1 + 1.3 * np.exp(-(np.log(fk / 1400) / 0.55) ** 2)) * (0.75 if k % 2 == 0 else 1.0)
            y += amp * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6))
            k += 1
    y /= len(palhetas)
    sopro = signal.lfilter(*signal.butter(2, [800, 5000], "bandpass", fs=SR), rng.standard_normal(n))
    env = np.clip(t / ataque, 0, 1) ** 1.6 * np.where(t < dur, 1.0, np.exp(-(t - dur) / max(0.06, ataque * 0.6)))
    clique = np.exp(-t / 0.004) * rng.standard_normal(n) * 0.15
    return vel * 0.14 * (y * fole + ar * 6 * sopro * fole) * env + vel * clique * 0.05


def marimba(m, dur, vel=0.6, dura=0.4):
    """Marimba de baquetas macias: barra afinada 1 : 3,93 : 9,2 com o tubo realçando a fundamental."""
    f = mf(m)
    dec = float(np.clip(1.4 * (262 / f) ** 0.6, 0.35, 2.4))
    n = int((dec * 4 + 0.1) * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / dec)
         + dura * 0.45 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / (dec / 4))
         + dura * 0.15 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / (dec / 10)))
    golpe = signal.lfilter(*signal.butter(2, 1800 + 2500 * dura, "low", fs=SR), rng.standard_normal(n)) * np.exp(-t / 0.003) * 0.4
    return vel * 0.30 * (s + golpe) * np.minimum(1, t * SR / 25)


def baixo_acustico(m, dur, vel=0.7):
    """Violão baixo / contrabaixo acústico dedilhado: corda grave escura, sustentação longa."""
    return 1.15 * violao(m, dur, vel, brilho=0.15, pos=0.30)


def rasqueado(fx, t, notas, vel, pan, rev, brilho=0.8, desce=True, dur=0.25, passo=0.012):
    """Cavaquinho/violão tocando o acorde de uma vez (as cordas soam uma depois da outra)."""
    ordem = notas if desce else notas[::-1]
    for k, m in enumerate(ordem):
        fx.por(violao(m, dur, vel * (0.9 + 0.1 * rng.random()), brilho, 0.12), t + k * passo, pan, rev)


# ------------------------------------------------------------------ mixagem

class Faixa:
    def __init__(self, dur):
        self.n = int(dur * SR)
        self.seco = np.zeros((self.n, 2))
        self.envio = np.zeros((self.n, 2))      # vai para o reverb

    def por(self, som, t, pan=0.0, rev=0.3, ganho=1.0):
        i = int(t * SR + rng.normal(0, 0.004) * SR) if t > 0.01 else int(t * SR)
        i = max(0, i)
        m = min(len(som), self.n - i)
        if m <= 0:
            return
        a = (pan + 1) * np.pi / 4
        s = som[:m] * ganho
        for c, gc in enumerate((np.cos(a), np.sin(a))):
            self.seco[i:i + m, c] += s * gc * (1 - rev * 0.5)
            self.envio[i:i + m, c] += s * gc * rev


def resposta_reverb(rt60=2.4, pre=0.02, brilho=0.5):
    n = int((rt60 * 1.2) * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for c in range(2):
        r = np.random.default_rng(50 + c).standard_normal(n)
        agudo = signal.lfilter(*signal.butter(1, 3000, "high", fs=SR), r)
        grave = r - agudo
        ir[:, c] = grave * np.exp(-6.9 * t / rt60) + brilho * agudo * np.exp(-6.9 * t / (rt60 * 0.45))
    ir[: int(pre * SR)] = 0
    ir *= np.minimum(1, (t - pre).clip(0) / 0.03)[:, None]
    return ir / np.sqrt((ir ** 2).sum(axis=0))


def finalizar(fx, nome, rt60, mix_rev, fade_fim=5.0):
    ir = resposta_reverb(rt60)
    mol = np.stack([signal.fftconvolve(fx.envio[:, c], ir[:, c])[: fx.n] for c in range(2)], axis=1)
    y = fx.seco + mix_rev * mol
    y = signal.lfilter(*signal.butter(2, 35, "high", fs=SR), y, axis=0)
    t = np.arange(fx.n) / SR
    y *= np.minimum(1, t / 1.5)[:, None] * np.clip((t[-1] - t) / fade_fim, 0, 1)[:, None] ** 1.5
    y = y / (np.abs(y).max() + 1e-9) * 0.9
    y = np.tanh(y * 1.3) / np.tanh(1.3) * 0.9
    wavfile.write(nome + ".wav", SR, (y * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", nome + ".wav", "-af", "loudnorm=I=-18:TP=-1.5:LRA=11",
                    "-ar", "44100", "-b:a", "192k", nome + ".mp3"], check=True)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", nome + ".wav", "-af", "loudnorm=I=-18:TP=-1.5:LRA=11",
                    "-ar", "44100", "-c:a", "libvorbis", "-q:a", "6", nome + ".ogg"], check=True)
    print(nome, "%.1f s" % (fx.n / SR))


def arpejo_violao(fx, t0, batida, acorde, padrao, compassos=1, vel=0.75, pan=-0.25, rev=0.25, brilho=0.6):
    """acorde = (baixo, [agudas]); padrao = lista de (tempo_em_batidas, 'b' | índice da aguda, duração)."""
    bx, ag = acorde
    for c in range(compassos):
        for (pos, qual, d) in padrao:
            m = bx if qual == "b" else (bx + 7 if qual == "q" else ag[qual % len(ag)])
            v = vel * (1.0 if qual in ("b", "q") else 0.72) * rng.uniform(0.85, 1.05)
            fx.por(violao(m, d * batida, v, brilho), t0 + (c * 4 + pos) * batida, pan + rng.uniform(-0.05, 0.05), rev)


def violao_solo(m, dur, vel=0.7):
    return 1.2 * violao(m, max(dur, 0.6), vel, brilho=0.72, pos=0.22)


def sanfona_solo(m, dur, vel=0.7):
    return sanfona(m, dur, vel)


def sanfona_suave(m, dur, vel=0.6):
    return sanfona(m, dur, vel, palhetas=(0.0, 5.0), ar=0.06)


def marimba_macia(m, dur, vel=0.6):
    return marimba(m, dur, vel, dura=0.2)


def melodia(fx, t0, batida, notas, inst, pan=0.15, rev=0.35, vel=0.7, oitava=0):
    for (pos, m, d) in notas:
        if m is None:
            continue
        fx.por(inst(m + 12 * oitava, d * batida * 0.96, vel * rng.uniform(0.9, 1.05)), t0 + pos * batida, pan, rev)


def frase(compassos):
    """[[(beat, midi, dur), ...] por compasso] -> lista com tempos absolutos (em batidas)."""
    out = []
    for i, c in enumerate(compassos):
        for (b, m, d) in c:
            out.append((i * 4 + b, m, d))
    return out


def seq(*notas_dur, inicio=0.0):
    """seq((m, d), (m, d), ...) -> [(beat, m, d)] em sequência."""
    out, b = [], inicio
    for m, d in notas_dur:
        out.append((b, m, d))
        b += d
    return out


# ------------------------------------------------------------------ 1) TARDE: xote leve em Ré mixolídio

def tarde():
    bpm = 92.0
    bt = 60.0 / bpm
    A = {"D": (50, [57, 62, 66]), "G": (43, [59, 62, 67]), "C": (48, [55, 60, 64]), "A7": (45, [55, 61, 64]),
         "Bm": (47, [54, 59, 62]), "Em7": (40, [55, 62, 64]), "A": (45, [57, 61, 64])}
    secA = ["D", "G", "C", "D", "D", "G", "A7", "D"]
    secB = ["Bm", "G", "D", "A", "Bm", "G", "Em7", "A7"]
    forma = [("intro", ["D", "G", "C", "D"]), ("A", secA), ("B", secB), ("A2", secA), ("outro", ["D", "G", "A7", "D", "D"])]
    total = sum(len(c) for _, c in forma) * 4 * bt + 4
    fx = Faixa(total)
    padrao = [(0, "b", 1.0), (0.5, 1, 0.5), (1, 2, 0.5), (1.5, 0, 0.5), (2, "q", 1.0), (2.5, 1, 0.5), (3, 2, 0.5), (3.5, 0, 0.5)]
    melA = [seq((None, 1), (69, .5), (74, .5), (76, 1), (78, 1)), seq((79, 1.5), (78, .5), (76, 1), (74, 1)),
            seq((72, 1.5), (74, .5), (76, 1), (79, 1)), seq((78, 1), (76, 1), (74, 2)),
            seq((81, 1), (78, .5), (81, .5), (83, 1), (81, 1)), seq((79, 1), (83, .5), (81, .5), (79, 1), (76, 1)),
            seq((76, 1), (79, .5), (78, .5), (76, 1), (73, 1)), seq((74, 3), (None, 1))]
    melB = [seq((78, 2), (74, 1), (71, 1)), seq((74, 1.5), (76, .5), (74, 1), (71, 1)),
            seq((69, 1), (74, 1), (78, 1), (81, 1)), seq((76, 2), (73, 1), (69, 1)),
            seq((71, 1), (74, 1), (78, 1.5), (76, .5)), seq((74, 1), (76, 1), (79, 1.5), (78, .5)),
            seq((76, 1.5), (74, .5), (71, 1), (74, 1)), seq((73, 1), (76, 1), (79, 1), (76, .5), (73, .5))]
    t = 0.0
    for nome, cs in forma:
        for i, ch in enumerate(cs):
            tc = t + i * 4 * bt
            fim = nome == "outro" and i == len(cs) - 1
            if fim:
                bx, ag = A[ch]
                for k, m in enumerate([bx] + ag + [ag[-1] + 5]):
                    fx.por(violao(m, 5.0, 0.7), tc + k * 0.06, -0.25 + 0.1 * k, 0.35)
                fx.por(baixo_acustico(A[ch][0] - 12, 4.0, 0.6), tc, 0.0, 0.1)
                continue
            arpejo_violao(fx, tc, bt, A[ch], padrao, vel=0.62 if nome == "intro" else 0.7, pan=-0.38)
            if nome != "intro":
                fx.por(baixo_acustico(A[ch][0] - 12 if A[ch][0] > 45 else A[ch][0], 1.6 * bt, 0.5), tc, 0.0, 0.08)
                fx.por(baixo_acustico(A[ch][0] - 5 if A[ch][0] > 45 else A[ch][0] + 7, 1.2 * bt, 0.42), tc + 2 * bt, 0.0, 0.08)
                if nome in ("B", "A2"):         # cavaquinho no contratempo
                    agudas = [m + 12 for m in A[ch][1]] + [A[ch][1][0] + 24]
                    for b in (1.5, 3.5):
                        rasqueado(fx, tc + b * bt, agudas, 0.32, 0.4, 0.18, 0.85, desce=(b == 1.5), dur=0.16, passo=0.008)
                # xote: zabumba no 1 e no "e" do 2, bacalhau no contratempo, triângulo em colcheias
                fx.por(zabumba(0.8), tc, 0.0, 0.12)
                fx.por(zabumba(0.45), tc + 1.5 * bt, 0.0, 0.12)
                fx.por(zabumba(0.6), tc + 2 * bt, 0.0, 0.12)
                for b in (1.0, 3.0):
                    fx.por(bacalhau(0.5), tc + b * bt, 0.05, 0.1)
                for k in range(8):
                    fx.por(triangulo(k % 2 == 1, 0.55 if k % 2 else 0.4), tc + k * 0.5 * bt, 0.45, 0.2)
        if nome in ("A", "A2"):
            melodia(fx, t, bt, frase(melA), sanfona_solo, 0.22, 0.28, 0.8)
            if nome == "A2":
                melodia(fx, t, bt, frase(melA), violao_solo, -0.15, 0.3, 0.35, oitava=-1)
        if nome == "B":
            melodia(fx, t, bt, frase(melB), sanfona_solo, 0.22, 0.28, 0.75)
            for i, ch in enumerate(cs):
                bx, ag = A[ch]
                pass
        t += len(cs) * 4 * bt
    finalizar(fx, "trilha_tarde", 1.3, 0.4)


# ------------------------------------------------------------------ 2) FINAL DO DIA: balada em Lá maior

def final_do_dia():
    bpm = 70.0
    bt = 60.0 / bpm
    A = {"Amaj7": (45, [52, 56, 61, 64]), "F#m7": (42, [54, 57, 61, 64]), "Dmaj7": (50, [57, 61, 66, 69]),
         "E7sus4": (40, [52, 57, 59, 62]), "E": (40, [52, 56, 59, 64]), "Bm7": (47, [54, 57, 62, 66]),
         "C#m7": (49, [56, 59, 64, 68])}
    secA = ["Amaj7", "F#m7", "Dmaj7", ("E7sus4", "E"), "Amaj7", "F#m7", "Dmaj7", "E"]
    secB = ["Bm7", "C#m7", "Dmaj7", "E", "F#m7", "Dmaj7", "Bm7", ("E7sus4", "E")]
    forma = [("intro", ["Amaj7", "F#m7", "Dmaj7", ("E7sus4", "E")]), ("A", secA), ("B", secB), ("A2", secA),
             ("outro", ["Amaj7", "F#m7", "Dmaj7", "Amaj7"])]
    total = sum(len(c) for _, c in forma) * 4 * bt + 6
    fx = Faixa(total)
    padrao = [(0, "b", 2.0), (0.5, 0, 0.5), (1, 1, 0.5), (1.5, 2, 0.5), (2, 3, 1.0), (2.5, 2, 0.5), (3, 1, 0.5), (3.5, 0, 0.5)]
    melA = [seq((76, 1.5), (73, .5), (71, 1), (73, 1)), seq((69, 2), (71, 1), (73, 1)),
            seq((78, 1.5), (76, .5), (73, 1), (69, 1)), seq((71, 2), (69, 1), (68, 1)),
            seq((73, 1), (76, 1), (80, 1.5), (76, .5)), seq((78, 2), (76, 1), (73, 1)),
            seq((74, 1), (73, 1), (69, 1.5), (66, .5)), seq((68, 1), (71, 1), (76, 2))]
    melB = [seq((74, 1.5), (73, .5), (71, 1), (69, 1)), seq((68, 1.5), (71, .5), (73, 1), (76, 1)),
            seq((78, 2), (81, 1), (78, 1)), seq((76, 3), (None, 1)),
            seq((73, 1), (76, 1), (81, 1.5), (80, .5)), seq((78, 1.5), (76, .5), (74, 1), (73, 1)),
            seq((71, 1), (74, 1), (78, 1), (76, 1)), seq((76, 1), (74, 1), (73, 1), (71, 1))]
    t = 0.0
    for nome, cs in forma:
        for i, ch in enumerate(cs):
            tc = t + i * 4 * bt
            partes = [(ch, 0, 4)] if isinstance(ch, str) else [(ch[0], 0, 2), (ch[1], 2, 2)]
            for nome_ac, ini, dur in partes:
                bx, ag = A[nome_ac]
                if nome == "intro" or (nome == "outro" and i == len(cs) - 1):
                    # piano elétrico em acordes longos
                    rasqueado(fx, tc + ini * bt, [bx] + ag, 0.55, -0.2, 0.35, 0.5, desce=False,
                              dur=dur * bt * (1.6 if nome == "outro" else 0.95), passo=0.07)
                    fx.por(baixo_acustico(bx - 12 if bx > 44 else bx, dur * bt, 0.65), tc + ini * bt, 0, 0.1)
                    continue
                sub = [p for p in padrao if ini <= p[0] < ini + dur]
                arpejo_violao(fx, tc, bt, (bx, ag), sub, vel=0.62, pan=-0.3, rev=0.3, brilho=0.5)
                if nome != "A":
                    fx.por(baixo_acustico(bx - 12 if bx > 44 else bx, dur * bt * 0.9, 0.75), tc + ini * bt, 0, 0.08)
                if nome in ("B", "A2"):
                    for m in ag[1:]:
                        fx.por(sanfona(m, dur * bt, 0.16, (0.0, 4.0), 0.07, 0.6), tc + ini * bt, 0.1, 0.45)
        if nome == "A":
            melodia(fx, t, bt, frase(melA), violao_solo, 0.25, 0.32, 0.8)
        if nome == "B":
            melodia(fx, t, bt, frase(melB), sanfona_suave, 0.25, 0.35, 0.7)
            melodia(fx, t, bt, frase(melB), marimba_macia, -0.25, 0.4, 0.3, oitava=-1)
        if nome == "A2":
            melodia(fx, t, bt, frase(melA), violao_solo, 0.25, 0.32, 0.8)
            melodia(fx, t, bt, frase(melA), marimba_macia, -0.2, 0.4, 0.35, oitava=-1)
        t += len(cs) * 4 * bt
    finalizar(fx, "trilha_final_do_dia", 1.8, 0.5, 7.0)


# ------------------------------------------------------------------ 3) NOITE: ambiente em Mi dórico

def noite():
    bpm = 56.0
    bt = 60.0 / bpm
    A = {"Em9": (40, [55, 59, 62, 66]), "Cmaj7": (36, [55, 59, 64, 66]), "Am9": (45, [55, 60, 64, 71]),
         "Bm7": (47, [54, 57, 62, 66])}
    ciclo = ["Em9", "Cmaj7", "Am9", "Bm7"]          # 2 compassos cada
    forma = [("intro", ciclo[:2]), ("A", ciclo), ("A2", ciclo), ("outro", ["Em9", "Cmaj7", "Em9"])]
    total = sum(len(c) for _, c in forma) * 8 * bt + 8
    fx = Faixa(total)
    mel = [seq((71, 2), (74, 1), (78, 3), (76, 2)), seq((79, 3), (76, 1), (71, 4)),
           seq((72, 2), (71, 1), (69, 2), (76, 3)), seq((74, 3), (78, 1), (76, 2), (74, 2))]
    mel2 = [seq((None, 2), (67, 2), (71, 2), (74, 2)), seq((76, 4), (74, 2), (71, 2)),
            seq((69, 3), (72, 1), (76, 4)), seq((74, 2), (71, 2), (69, 2), (71, 2))]
    t = 0.0
    for nome, cs in forma:
        for i, ch in enumerate(cs):
            tc = t + i * 8 * bt
            bx, ag = A[ch]
            ultimo = nome == "outro" and i == len(cs) - 1
            dur = 8 * bt * (1.8 if ultimo else 1.0)
            for m in ag[:3]:
                fx.por(sanfona(m, dur, 0.13, (0.0, 3.0), 0.08, 2.2), tc, 0.0, 0.6)
            if nome in ("A2", "outro") or (nome == "A" and i >= 2):
                fx.por(baixo_acustico(bx, 6 * bt, 0.5), tc, 0, 0.15)
            # violão em notas soltas, como harmônicos, espalhadas
            nplucks = 3 if nome == "intro" else (5 if nome == "A" else 6)
            for k in range(nplucks):
                pos = rng.choice(np.arange(0, 8, 0.5))
                m = rng.choice(ag) + 12 * rng.choice([0, 1], p=[0.6, 0.4])
                fx.por(violao(m, 2.5, 0.35, 0.85, 0.5), tc + pos * bt, rng.uniform(-0.7, 0.7), 0.6)
        if nome == "A":
            melodia(fx, t, bt, [(b * 2, m, d * 2) for (b, m, d) in frase(mel)], marimba_macia, 0.1, 0.55, 0.75)
        if nome == "A2":
            melodia(fx, t, bt, [(b * 2, m, d * 2) for (b, m, d) in frase(mel2)], violao_solo, 0.2, 0.5, 0.6)
            melodia(fx, t, bt, [(b * 2, m, d * 2) for (b, m, d) in frase(mel)], marimba_macia, -0.2, 0.6, 0.4)
        t += len(cs) * 8 * bt
    finalizar(fx, "trilha_noite", 2.6, 0.6, 9.0)


if __name__ == "__main__":
    qual = sys.argv[1:] or ["tarde", "final", "noite"]
    if "tarde" in qual:
        tarde()
    if "final" in qual:
        final_do_dia()
    if "noite" in qual:
        noite()
