"""Compõe e sintetiza a trilha de vila de pescador do Náufrago -> jogo/musica/*.ogg

Uso (na pasta naufrago_mobile):   python arte/gerar_musica.py
Precisa de: numpy, scipy e ffmpeg (com libvorbis).  Sem ffmpeg:  python arte/gerar_musica.py --wav
Só conferir a teoria (sem gerar áudio):  python arte/gerar_musica.py --conferir

São três músicas curtas, calmas, de ~35-40 s cada (cabem numa manhã do jogo, que tem 90 s por dia). Nada é gravação: tudo é sintetizado aqui.

  musica1  "Barcarola da Vila"      Ré maior, 6/8 (balanço de barco), violão + flauta + acordeão suave + sino de boia
  musica2  "Rede ao Sol"            Lá menor, 4/4 lento, violão + acordeão
  musica3  "Entardecer no Cais"     Sol maior, valsa em 3/4, violão + flauta + sino de boia

Como cada música é escrita
  * "acordes": para cada acorde, as notas que ele permite, a posição do violão (baixo + 3 cordas) e a
    do acordeão de fundo (3 notas).
  * "barras": uma linha por compasso: (acorde, melodia). A melodia é "NOTA:duração em colcheias", ex.
    "A4:2 B4:1 A4:3". "R:2" é pausa. Compasso vazio = sem melodia (introdução).
  * conferir() confere a teoria antes de gerar: as notas do tempo forte da melodia têm de pertencer ao
    acorde, o violão e o acordeão só podem usar notas do acorde, e cada compasso tem de fechar a conta.
    Se você mudar uma nota e errar, o script avisa em vez de gerar uma música desafinada.
Para ouvir de outro jeito: mude o andamento (colcheia, em segundos), o acorde ou a melodia e rode de novo.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy import signal
from scipy.io import wavfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gerar_sons as gs                       # ferramentas de síntese (filtros, envelopes)

SR = gs.SR
AQUI = os.path.dirname(os.path.abspath(__file__))
DESTINO = os.path.join(os.path.dirname(AQUI), "jogo", "musica")

# ----------------------------------------------------------------------------- notas
_BASE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(nome):
    """'F#4' -> 66.  (A4 = 69 = 440 Hz)"""
    n, i = _BASE[nome[0]], 1
    while nome[i] in "#b":
        n += 1 if nome[i] == "#" else -1
        i += 1
    return 12 * (int(nome[i:]) + 1) + n


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def classe(nome_sem_oitava):
    return midi(nome_sem_oitava + "4") % 12


# ----------------------------------------------------------------------------- as três músicas
# acorde: (notas permitidas, violão "baixo c1 c2 c3", acordeão "n1 n2 n3")
T1 = dict(
    arq="musica1", titulo="Barcarola da Vila", compasso=6, forte=(0, 3), ritmo="arpejo6",
    colcheia=0.3125,                       # 64 por minuto (semínima pontuada)
    acordes={
        "D":    ("D F# A",  "D3 A3 D4 F#4",   "A3 D4 F#4"),
        "A":    ("A C# E",  "A2 E3 A3 C#4",   "A3 C#4 E4"),
        "Bm":   ("B D F#",  "B2 F#3 B3 D4",   "B3 D4 F#4"),
        "F#m":  ("F# A C#", "F#2 C#3 F#3 A3", "A3 C#4 F#4"),
        "G":    ("G B D",   "G2 D3 G3 B3",    "B3 D4 G4"),
        "D/F#": ("D F# A",  "F#2 D3 A3 D4",   "A3 D4 F#4"),
        "Em":   ("E G B",   "E2 B2 E3 G3",    "B3 E4 G4"),
        "Em7":  ("E G B D", "E2 B2 D3 G3",    "B3 D4 G4"),
    },
    barras=[
        ("D", ""), ("A", ""),                                                        # introdução (violão só)
        ("D", "A4:2 B4:1 A4:3"), ("A", "C#5:2 B4:1 A4:3"), ("Bm", "B4:2 C#5:1 D5:3"),   # tema
        ("F#m", "C#5:3 A4:2 F#4:1"), ("G", "B4:2 A4:1 G4:3"), ("D/F#", "A4:3 F#4:3"),
        ("Em", "G4:2 A4:1 B4:3"), ("A", "E5:3 C#5:2 A4:1"),
        ("G", "G4:3 B4:2 D5:1"), ("D/F#", "D5:3 F#5:2 E5:1"), ("Em7", "D5:3 B4:3"),      # subida
        ("A", "C#5:2 D5:1 E5:3"),
        ("D", "A4:3 F#4:3"), ("D", "D5:6"),                                         # volta para casa
    ],
    pad_desde=2, lead="flauta", sinos={10: "D5", 15: "D5"},
)

T2 = dict(
    arq="musica2", titulo="Rede ao Sol", compasso=8, forte=(0, 4), ritmo="arpejo8",
    colcheia=0.4167,                       # 72 por minuto
    acordes={
        "Am": ("A C E",  "A2 E3 A3 C4",  "A3 C4 E4"),
        "F":  ("F A C",  "F2 C3 A3 C4",  "A3 C4 F4"),
        "C":  ("C E G",  "C3 G3 C4 E4",  "G3 C4 E4"),
        "G":  ("G B D",  "G2 D3 G3 B3",  "G3 B3 D4"),
        "Dm": ("D F A",  "D2 A2 F3 A3",  "A3 D4 F4"),
        "E":  ("E G# B", "E2 B2 E3 G#3", "G#3 B3 E4"),
    },
    barras=[
        ("Am", ""),                                                                  # introdução
        ("Am", "E5:3 D5:1 C5:2 A4:2"), ("F", "A4:3 G4:1 A4:2 C5:2"), ("C", "E5:4 C5:2 D5:2"),
        ("G", "D5:4 B4:2 G4:2"), ("Am", "A4:4 C5:2 E5:2"), ("F", "F5:3 E5:1 C5:4"),
        ("Dm", "D5:4 F5:2 E5:2"), ("E", "B4:4 G#4:2 B4:2"),
        ("Am", "A4:8"),
    ],
    pad_desde=1, lead="acordeao", sinos={3: "G5", 9: "E5"},
)

T3 = dict(
    arq="musica3", titulo="Entardecer no Cais", compasso=6, forte=(0,), ritmo="valsa",
    colcheia=0.3947,                       # 76 por minuto (semínima)
    acordes={
        "G":   ("G B D",   "G2 B3 D4 G4",  "B3 D4 G4"),
        "Em":  ("E G B",   "E2 G3 B3 E4",  "G3 B3 E4"),
        "C":   ("C E G",   "C3 G3 C4 E4",  "G3 C4 E4"),
        "D":   ("D F# A",  "D3 A3 D4 F#4", "A3 D4 F#4"),
        "Bm":  ("B D F#",  "B2 F#3 B3 D4", "B3 D4 F#4"),
        "G/B": ("G B D",   "B2 G3 B3 D4",  "B3 D4 G4"),
        "Am":  ("A C E",   "A2 E3 A3 C4",  "A3 C4 E4"),
    },
    barras=[
        ("G", ""), ("D", ""),
        ("G", "D5:3 B4:1 G4:2"), ("Em", "G4:2 B4:2 E5:2"), ("C", "E5:3 D5:1 C5:2"),
        ("D", "D5:2 C5:1 B4:1 A4:2"), ("G", "B4:3 A4:1 G4:2"), ("Bm", "D5:2 F#5:2 D5:2"),
        ("C", "G4:2 C5:2 E5:2"), ("D", "A4:3 F#4:1 D5:2"),
        ("C", "G4:2 E5:4"), ("G/B", "D5:3 B4:3"), ("Am", "C5:3 B4:1 A4:2"), ("D", "A4:2 D5:2 F#5:2"),
        ("G", "D5:6"),
    ],
    pad_desde=2, lead="flauta", sinos={10: "G5", 14: "D5"},
)

FAIXAS = [T1, T2, T3]


# ----------------------------------------------------------------------------- conferência de teoria
def _notas(txt):
    return [midi(n) for n in txt.split()]


def _melodia(txt):
    """'A4:2 B4:1' -> [('A4', 2), ('B4', 1)]"""
    return [(p.split(":")[0], int(p.split(":")[1])) for p in txt.split()]


def conferir(T):
    erros = []
    perm = {nome: {classe(n) for n in a[0].split()} for nome, a in T["acordes"].items()}
    for i, (nome, mel) in enumerate(T["barras"], 1):
        if nome not in T["acordes"]:
            erros.append("compasso %d: acorde %s não existe" % (i, nome))
            continue
        for rotulo, txt in (("violão", T["acordes"][nome][1]), ("acordeão", T["acordes"][nome][2])):
            fora = [m for m in _notas(txt) if m % 12 not in perm[nome]]
            if fora:
                erros.append("compasso %d (%s): %s usa notas fora do acorde: %s" % (i, nome, rotulo, fora))
            sub = _notas(txt)
            if sub != sorted(sub):
                erros.append("compasso %d (%s): %s fora de ordem crescente" % (i, nome, rotulo))
        if not mel:
            continue
        pos = 0
        for nota, d in _melodia(mel):
            if nota != "R":
                m = midi(nota)
                if pos in T["forte"] and m % 12 not in perm[nome]:
                    erros.append("compasso %d (%s): %s cai no tempo forte (pos %d) e não é do acorde"
                                 % (i, nome, nota, pos))
                if not 62 <= m <= 84:
                    erros.append("compasso %d: %s fora da extensão do instrumento" % (i, nota))
            pos += d
        if pos != T["compasso"]:
            erros.append("compasso %d: a melodia soma %d colcheias, devia somar %d" % (i, pos, T["compasso"]))
    return erros


# ----------------------------------------------------------------------------- instrumentos
_cache_corda = {}
_sopro = None


def sopro():
    global _sopro
    if _sopro is None:
        r = np.random.default_rng(77)
        _sopro = gs.banda(r.standard_normal(int(6 * SR)), 1500, 4500)
        _sopro /= np.std(_sopro)
    return _sopro


def corda(m):
    """Corda de nylon dedilhada: harmônicos que morrem mais rápido quanto mais agudos + toque da unha."""
    if m in _cache_corda:
        return _cache_corda[m]
    dur = 3.6
    t = gs.tempo(dur)
    f = hz(m)
    r0 = 1.0 + 0.017 * max(0, m - 38)                   # graves duram mais
    x = np.zeros_like(t)
    for k in range(1, int(min(16, SR * 0.45 / f)) + 1):
        a = abs(np.sin(np.pi * k * 0.17)) / k ** 1.5      # dedilhado a 17% da corda
        x += a * np.sin(2 * np.pi * k * f * (1 + 1.5e-5 * k * k) * t) * np.exp(-r0 * (1 + 0.45 * (k - 1)) * t)
    rg = np.random.default_rng(m)
    unha = gs.banda(rg.standard_normal(len(t)), 900, 4200) * np.exp(-t / 0.006) * 0.10
    corpo = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.035) * 0.16
    x = x / (np.abs(x).max() + 1e-9) + unha + corpo
    x = x / (np.abs(x).max() + 1e-9)
    _cache_corda[m] = x
    return x


def flauta(m, dur, rg):
    """Flauta suave: quase só a fundamental, vibrato que chega devagar e um pouco de sopro."""
    rel = 0.25
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    vib = 0.0032 * np.clip((t - 0.15) / 0.45, 0, 1) * np.sin(2 * np.pi * 5.1 * t + rg.uniform(0, 6.28))
    fase = 2 * np.pi * np.cumsum(f * (1 + vib)) / SR
    tom = np.sin(fase) + 0.20 * np.sin(2 * fase) + 0.05 * np.sin(3 * fase)
    i0 = int(rg.integers(0, len(sopro()) - n))
    ar = sopro()[i0:i0 + n] * (0.017 + 0.05 * np.exp(-t / 0.07))
    ataque = 0.5 - 0.5 * np.cos(np.pi * np.minimum(t / 0.085, 1.0))
    solta = np.where(t < dur, 1.0, np.exp(-(t - dur) / 0.075))
    return (tom * 0.5 + ar) * ataque * solta * (1 + 0.04 * np.sin(2 * np.pi * 4.3 * t))


def palheta(m, dur, rg, brilho=1.0, ataque=0.09, solta=0.2, trem=0.10, abertura=0.7):
    """Acordeão/harmônio: palhetas levemente desafinadas entre si (o 'musette'), tremolo do fole.
    Devolve estéreo (n, 2)."""
    n = int((dur + solta * 3) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    pesos = (1.0, 0.75, 0.50, 0.34, 0.24, 0.16, 0.11, 0.08)
    vozes = []
    for desv in (-0.0026, 0.0026):
        ph = 2 * np.pi * np.cumsum(np.full(n, f * (1 + desv))) / SR + rg.uniform(0, 6.28)
        vozes.append(sum(p * np.sin((k + 1) * ph) for k, p in enumerate(pesos) if f * (k + 1) < SR * 0.45))
    esq = vozes[0] * 0.8 + vozes[1] * 0.45
    dir_ = vozes[0] * 0.45 + vozes[1] * 0.8
    saida = np.stack([esq, dir_], axis=1)
    saida = signal.sosfilt(signal.butter(2, 2300 * brilho, btype="low", fs=SR, output="sos"), saida, axis=0)
    subida = 0.5 - 0.5 * np.cos(np.pi * np.minimum(t / ataque, 1.0))
    queda = np.where(t < dur, 1.0, np.exp(-(t - dur) / solta))
    fole = (1 + trem * np.sin(2 * np.pi * 5.6 * t + rg.uniform(0, 6.28))) * subida * queda
    return saida * (fole[:, None] * 0.28 * abertura)


def sino_boia(m, dur=5.0):
    """Sino de boia ao longe: poucas parciais inarmônicas, ataque macio, decaimento longo."""
    t = gs.tempo(dur)
    f = hz(m)
    parc = ((1.0, 1.0, 2.6), (2.0, 0.42, 1.9), (2.76, 0.28, 1.3), (4.1, 0.14, 0.8), (5.4, 0.08, 0.5))
    x = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / d) for r, a, d in parc)
    x *= np.minimum(t / 0.004, 1.0)
    return x / (np.abs(x).max() + 1e-9)


# ----------------------------------------------------------------------------- mixagem
def colocar(buf, x, t0, ganho=1.0, pan=0.0):
    """Soma x (mono ou estéreo) em buf (n, 2) a partir de t0 segundos. pan -1..+1 (igual potência)."""
    i = int(round(t0 * SR))
    if i < 0:                                   # nota 'adiantada' pelo toque humano no início
        x, i = x[-i:], 0
    if i >= len(buf):
        return
    n = min(len(x), len(buf) - i)
    if x.ndim == 1:
        a = (pan + 1) * np.pi / 4
        buf[i:i + n, 0] += x[:n] * np.cos(a) * ganho
        buf[i:i + n, 1] += x[:n] * np.sin(a) * ganho
    else:
        buf[i:i + n] += x[:n] * ganho


def corte(x, dur, solta=0.12):
    """Corta a nota em 'dur' segundos com uma descida curta (para o acorde anterior não sujar o próximo)."""
    n = int(dur * SR)
    if n >= len(x):
        return x
    y = x[:n].copy()
    k = min(int(solta * SR), n)
    y[-k:] *= np.linspace(1, 0, k) ** 2
    return y


def reverb(x, rg, rt=2.4, pre=0.02):
    """Sala/enseada: resposta ao impulso de ruído que morre exponencialmente e escurece (fftconvolve)."""
    n = int(rt * 1.5 * SR)
    t = np.arange(n) / SR
    saida = []
    for c in range(2):
        ir = rg.standard_normal(n) * np.exp(-6.9 * t / rt)
        ir = 0.45 * ir + 0.55 * gs.passa(ir, "low", 2200)
        ir = np.concatenate([np.zeros(int(pre * SR)), ir])
        ir /= np.sqrt((ir ** 2).sum())
        saida.append(signal.fftconvolve(x[:, c], ir)[:len(x)])
    return np.stack(saida, axis=1)


def montar(T, semente):
    rg = np.random.default_rng(semente)
    barras, npb = T["barras"], T["compasso"]
    mult = [1.0] * len(barras)
    mult[-3:] = [1.0, 1.05, 1.14]                                # o fim desacelera
    durb = [T["colcheia"] * npb * m for m in mult]
    ini = np.concatenate([[0.0], np.cumsum(durb)])
    cauda = 4.5
    n = int((ini[-1] + cauda) * SR)
    voz = {k: np.zeros((n, 2)) for k in ("violao", "lead", "pad", "sino")}
    ult = len(barras) - 1

    for i, (nome, mel) in enumerate(barras):
        pcs, vio, pad = T["acordes"][nome]
        vio, pad = _notas(vio), _notas(pad)
        c = durb[i] / npb                                         # colcheia local (com a desaceleração)
        t0 = ini[i]
        resto = durb[i] + c                                       # a nota soa até o fim do compasso + 1 colcheia

        # --- violão
        def pluck(m, quando, vel, dur=None):
            vel *= rg.uniform(0.93, 1.07)
            colocar(voz["violao"], corte(corda(m), dur or resto), quando + rg.normal(0, 0.005), 0.55 * vel, -0.22)

        if i == ult:                                              # último compasso: acorde rolado e deixado soar
            for j, m in enumerate(vio):
                pluck(m, t0 + j * 0.075, 0.9 - 0.08 * j, dur=5.5)
        elif T["ritmo"] == "valsa":
            pluck(vio[0], t0, 1.0)
            for pos, cordas, v in ((2, vio[1:], 0.55), (4, vio[2:], 0.45)):
                for j, m in enumerate(cordas):
                    pluck(m, t0 + pos * c + j * 0.016, v * (1 - 0.1 * j))
        else:
            padrao = (0, 1, 2, 3, 2, 1) if T["ritmo"] == "arpejo6" else (0, 1, 2, 3, 2, 1, 2, 3)
            for j, idx in enumerate(padrao):
                vel = 1.0 if j == 0 else (0.72 if j == npb // 2 else 0.58)
                pluck(vio[idx], t0 + j * c, vel)

        # --- acordeão de fundo (entra depois da introdução)
        if i >= T["pad_desde"]:
            dur_pad = durb[i] + 0.35 if i < ult else durb[i] * 1.0 + 2.0
            for m in pad:
                colocar(voz["pad"], palheta(m, dur_pad, rg, brilho=0.55, ataque=0.55, solta=0.7, trem=0.07,
                                            abertura=0.26), t0 - 0.12, 1.0)

        # --- melodia
        if mel:
            pos = 0
            for nota, d in _melodia(mel):
                quando = t0 + pos * c + rg.normal(0, 0.008)
                if nota != "R":
                    m = midi(nota)
                    dur = d * c * 0.97
                    if i == ult:
                        dur = d * c * 1.0
                    if T["lead"] == "flauta":
                        x = flauta(m, dur, rg)
                        colocar(voz["lead"], x, quando, 0.50, 0.22)
                    else:
                        x = palheta(m, dur, rg, brilho=1.0, ataque=0.07, solta=0.16, trem=0.11, abertura=0.95)
                        colocar(voz["lead"], x, quando, 0.56, 0.12)
                pos += d

        # --- sino de boia
        if i in T["sinos"]:
            colocar(voz["sino"], sino_boia(midi(T["sinos"][i])), t0 + 0.02, 0.30, 0.55)

    return voz, n


def masterizar(voz, n, rg, alvo_rms=0.15):
    envio = voz["violao"] * 0.55 + voz["lead"] * 1.0 + voz["pad"] * 1.0 + voz["sino"] * 1.0
    molhado = reverb(envio, rg)
    mix = voz["violao"] + voz["lead"] + voz["pad"] + voz["sino"] + 0.34 * molhado
    mix = signal.sosfilt(signal.butter(2, 70, btype="high", fs=SR, output="sos"), mix, axis=0)
    mix = signal.sosfilt(signal.butter(2, 9500, btype="low", fs=SR, output="sos"), mix, axis=0)
    # entrada e saída suaves
    ent = int(0.35 * SR)
    mix[:ent] *= np.linspace(0, 1, ent)[:, None]
    sai = int(2.2 * SR)
    mix[-sai:] *= (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, sai)))[:, None]
    ativo = np.abs(mix).max(axis=1) > 0.01
    rms = np.sqrt((mix[ativo] ** 2).mean())
    mix *= alvo_rms / rms
    mix = np.tanh(mix * 1.1) / 1.1                                  # limitador suave, sem estalo
    return mix


def relatorio(nome, voz, mix):
    def db(x):
        a = np.abs(x).max(axis=1) > 1e-4
        return 20 * np.log10(np.sqrt((x[a] ** 2).mean()) + 1e-12)
    partes = "  ".join("%s %.1f" % (k, db(v)) for k, v in voz.items())
    m = mix.mean(axis=1)
    f, ps = signal.welch(m, SR, nperseg=4096)
    print("   %-8s %5.1f s  pico %.2f  rms %.1f dB  centroide %4.0f Hz  | partes (dB): %s" % (
        nome, len(mix) / SR, np.abs(mix).max(), 20 * np.log10(np.sqrt((mix ** 2).mean())),
        (f * ps).sum() / ps.sum(), partes))


def gravar(nome, x, usar_wav):
    os.makedirs(DESTINO, exist_ok=True)
    pcm = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    if usar_wav:
        wavfile.write(os.path.join(DESTINO, nome + ".wav"), SR, pcm)
        return
    with tempfile.TemporaryDirectory() as tmp:
        temp = os.path.join(tmp, nome + ".wav")
        wavfile.write(temp, SR, pcm)
        subprocess.check_call(["ffmpeg", "-y", "-loglevel", "error", "-i", temp, "-c:a", "libvorbis",
                               "-q:a", "3", os.path.join(DESTINO, nome + ".ogg")])


def main():
    todos_ok = True
    for T in FAIXAS:
        erros = conferir(T)
        print("%s (%s): %s" % (T["arq"], T["titulo"], "teoria OK" if not erros else "%d problema(s)" % len(erros)))
        for e in erros:
            print("   !", e)
        todos_ok = todos_ok and not erros
    if not todos_ok:
        sys.exit("Corrija a teoria acima antes de gerar.")
    if "--conferir" in sys.argv[1:]:
        return
    usar_wav = "--wav" in sys.argv[1:]
    for i, T in enumerate(FAIXAS):
        voz, n = montar(T, 100 + i)
        mix = masterizar(voz, n, np.random.default_rng(900 + i))
        relatorio(T["arq"], voz, mix)
        gravar(T["arq"], mix, usar_wav)
    print("Músicas gravadas em", DESTINO)


if __name__ == "__main__":
    main()
