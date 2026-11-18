"""Som do mar novo para o Pescador: síntese procedural (numpy), sem amostras de terceiros.

Gera:
  mar_novo.wav        laço de 96 s, alto-mar visto de bordo: marulho grave, água passando, batidas no casco, bolhas,
                      carneirinhos ao longe. Laço sem emenda (tudo é circular: ruído por FFT e eventos com índice módulo N).
  onda_nova_*.wav     ondas quebrando na costa (avulsas, como o onda.ogg atual).
  previa_*.mp3        prévias para ouvir: atual, novo alto-mar, novo perto da costa.
"""
import numpy as np
from scipy.io import wavfile
import subprocess, sys

SR = 44100
rng = np.random.default_rng(7)


def ruido(n, inclinacao=1.0, f_lo=20.0, f_hi=16000.0, suave=0.35, r=None):
    """Ruído colorido periódico (circular): espectro ~ f^-inclinacao/2 em amplitude, limitado entre f_lo e f_hi."""
    r = r or rng
    X = r.standard_normal(n // 2 + 1) + 1j * r.standard_normal(n // 2 + 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1.0
    amp = f ** (-inclinacao / 2.0)
    lf = np.log(f)
    amp *= 1 / (1 + np.exp(-(lf - np.log(f_lo)) / suave)) * 1 / (1 + np.exp((lf - np.log(f_hi)) / suave))
    amp[0] = 0
    y = np.fft.irfft(X * amp, n)
    return y / (y.std() + 1e-12)


def banda(x, f_lo, f_hi, suave=0.3):
    """Passa-faixa circular suave (em log-frequência)."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1.0
    lf = np.log(f)
    m = 1 / (1 + np.exp(-(lf - np.log(f_lo)) / suave)) * 1 / (1 + np.exp((lf - np.log(f_hi)) / suave))
    return np.fft.irfft(X * m, n)


def bolha(f0, amp, dur_max=0.12):
    """Bolha (modelo de van den Doel): seno amortecido com o tom subindo um pouco."""
    d = 0.13 * f0 + 0.0072 * f0 ** 1.5
    dur = min(dur_max, 6.0 / d)
    t = np.arange(int(dur * SR)) / SR
    xi = rng.uniform(0.05, 0.25)
    fase = 2 * np.pi * f0 * (t + xi * d * t * t / 2)
    return amp * np.sin(fase) * np.exp(-d * t) * np.sin(np.minimum(1, t * SR / 40) * np.pi / 2) ** 2


def explosao(dur, f_lo, f_hi, ataque, decai, inclin=1.0):
    n = int(dur * SR)
    x = banda(rng.standard_normal(n), f_lo, f_hi)
    t = np.arange(n) / SR
    env = np.minimum(1, t / max(ataque, 1e-3)) * np.exp(-np.maximum(0, t - ataque) / decai)
    y = x * env
    return y / (np.abs(y).max() + 1e-9)


def somar(destino, sinal, inicio, pan=0.0, circular=True):
    """Soma em estéreo (destino N x 2) com pan de potência constante; circular = laço sem emenda."""
    n = len(destino)
    a = (pan + 1) * np.pi / 4
    gl, gr = np.cos(a), np.sin(a)
    idx = (int(inicio) + np.arange(len(sinal)))
    if circular:
        idx %= n
    else:
        ok = idx < n
        idx, sinal = idx[ok], sinal[ok]
    np.add.at(destino[:, 0], idx, sinal * gl)
    np.add.at(destino[:, 1], idx, sinal * gr)


def envelope_ondulacao(n, periodo=(6.5, 11.5)):
    """Passagem das ondas: corcovas assimétricas (sobe devagar, desce mais rápido), circulares. Retorna env e as cristas."""
    D = n / SR
    t = np.arange(n) / SR
    env = np.zeros(n)
    cristas = []
    pos = rng.uniform(0, 3)
    while pos < D - 4:
        cristas.append(pos)
        pos += rng.uniform(*periodo)
    # ajusta para fechar o laço sem um buraco no fim
    escala = D / (cristas[-1] + rng.uniform(*periodo) * 0 + (D - cristas[-1]))
    for c in cristas:
        forca = rng.uniform(0.55, 1.0)
        sobe, desce = rng.uniform(2.5, 4.5), rng.uniform(1.8, 3.2)
        dt = (t - c + D / 2) % D - D / 2
        corc = np.where(dt < 0, np.exp(-(dt / sobe) ** 2 * 2.2), np.exp(-(dt / desce) ** 2 * 2.2))
        env = np.maximum(env, forca * corc)
    return env, cristas


def mar_alto_mar(dur=96.0):
    n = int(dur * SR)
    out = np.zeros((n, 2))
    env, cristas = envelope_ondulacao(n)
    env_l = 0.25 + 0.75 * env

    # 1) marulho grave: ruído marrom 25-170 Hz, metade comum aos dois lados
    com = ruido(n, 2.0, 25, 170)
    for c in range(2):
        g = 0.6 * com + 0.8 * ruido(n, 2.0, 25, 170)
        out[:, c] += 0.30 * g * (0.45 + 0.55 * env)
    # 2) corpo da água passando: rosa 160-1300 Hz, acompanha a onda
    com = ruido(n, 1.0, 160, 1300)
    for c in range(2):
        g = 0.45 * com + 0.9 * ruido(n, 1.0, 160, 1300)
        out[:, c] += 0.50 * g * env_l ** 1.2
    # 3) chiado da crista: 1,5-5 kHz no alto da onda, e um "ar" de fundo bem baixo (o mar nunca fica mudo)
    for c in range(2):
        g = ruido(n, 1.0, 1500, 5200)
        out[:, c] += 0.40 * g * env ** 1.8
        out[:, c] += 0.13 * ruido(n, 1.0, 900, 6500) * (0.45 + 0.55 * env)

    # 4) batidas no casco a cada onda + bolhas em seguida
    for cr in cristas:
        for k in range(rng.integers(1, 3)):
            t0 = (cr + rng.uniform(-0.6, 0.9) + k * rng.uniform(0.35, 0.8)) * SR
            pan = rng.uniform(-0.6, 0.6)
            fc = rng.uniform(220, 520)
            tapa = explosao(rng.uniform(0.35, 0.6), fc * 0.6, fc * 2.2, 0.006, rng.uniform(0.07, 0.16))
            somar(out, 0.35 * rng.uniform(0.6, 1.0) * tapa, t0, pan)
            # ressonância grave do casco
            tt = np.arange(int(0.25 * SR)) / SR
            tum = np.sin(2 * np.pi * rng.uniform(75, 120) * tt) * np.exp(-tt / 0.07) * np.minimum(1, tt * SR / 30)
            somar(out, 0.12 * tum, t0, pan * 0.5)
            # bolhas e gorgolejo
            for b in range(rng.integers(25, 70)):
                tb = t0 + rng.exponential(0.35) * SR
                f0 = np.exp(rng.uniform(np.log(450), np.log(2600)))
                somar(out, bolha(f0, 0.025 * rng.uniform(0.3, 1.0)), tb, pan + rng.uniform(-0.25, 0.25))
    # 5) marolinhas pequenas batendo entre as ondas
    t = 0.0
    while t < dur:
        t += rng.exponential(1.1)
        if t >= dur:
            break
        pan = rng.uniform(-0.8, 0.8)
        fc = rng.uniform(300, 800)
        som = explosao(rng.uniform(0.2, 0.35), fc * 0.7, fc * 2.0, 0.01, rng.uniform(0.04, 0.09))
        somar(out, 0.09 * rng.uniform(0.4, 1.0) * som, t * SR, pan)
        for b in range(rng.integers(3, 14)):
            f0 = np.exp(rng.uniform(np.log(600), np.log(3200)))
            somar(out, bolha(f0, 0.015 * rng.uniform(0.3, 1.0)), (t + rng.exponential(0.15)) * SR, pan)
    # 6) carneirinhos ao longe (espuma estourando longe): chiado longo e baixo, bem espalhado
    t = rng.uniform(2, 6)
    while t < dur:
        pan = rng.uniform(-0.95, 0.95)
        d = rng.uniform(1.6, 3.2)
        som = explosao(d, 700, 3800, rng.uniform(0.4, 0.9), rng.uniform(0.5, 1.0))
        somar(out, 0.07 * som, t * SR, pan)
        t += rng.uniform(5.0, 11.0)
    return out


def onda_quebrando(dur=7.5, forca=1.0, seed=0):
    """Onda quebrando na praia: crescendo grave, estouro, espraiado e o refluxo chiando nas pedrinhas."""
    global rng
    rng = np.random.default_rng(100 + seed)
    n = int(dur * SR)
    out = np.zeros((n, 2))
    t = np.arange(n) / SR
    tq = rng.uniform(1.6, 2.2)                       # instante da quebra
    com_g = banda(rng.standard_normal(n), 40, 400)
    com_e = banda(rng.standard_normal(n), 250, 6500)
    # crescendo
    for c in range(2):
        g = 0.7 * com_g + 0.7 * banda(rng.standard_normal(n), 40, 400)
        e = np.exp(-((t - tq) / 0.9) ** 2) * (t < tq) + (t >= tq) * np.exp(-(t - tq) / 0.8)
        out[:, c] += 0.5 * g / g.std() * e
    # estouro
    for c in range(2):
        g = 0.6 * com_e + 0.8 * banda(rng.standard_normal(n), 250, 6500)
        sobe = 0.32
        e = np.clip((t - tq + sobe) / sobe, 0, 1) ** 2 * np.exp(-np.maximum(0, t - tq) / 0.75)
        out[:, c] += 0.50 * g / g.std() * e
        ga = banda(rng.standard_normal(n), 2500, 9000)                 # o agudo do estouro some antes
        out[:, c] += 0.18 * ga / ga.std() * np.clip((t - tq + 0.15) / 0.15, 0, 1) * np.exp(-np.maximum(0, t - tq) / 0.35)
    # espraiado (água correndo na areia)
    tw = tq + 0.6
    for c in range(2):
        g = banda(rng.standard_normal(n), 500, 5000)
        e = np.exp(-((t - tw - 1.2) / 1.1) ** 2)
        out[:, c] += 0.32 * g / g.std() * e
    # refluxo: muitas bolhinhas e grãos estalando
    for b in range(int(900 * forca)):
        tb = tw + 1.0 + rng.gamma(2.0, 0.7)
        if tb >= dur - 0.15:
            continue
        f0 = np.exp(rng.uniform(np.log(900), np.log(5500)))
        decai = np.exp(-(tb - tw - 1.0) / 2.2)
        somar(out, bolha(f0, 0.02 * decai * rng.uniform(0.2, 1.0), 0.04), tb * SR, rng.uniform(-0.7, 0.7), circular=False)
    # sobe e desce nas pontas
    fade = np.minimum(1, t / 0.4) * np.minimum(1, (dur - t) / 0.8)
    out *= fade[:, None]
    return out * forca


def normalizar(x, rms_db=-20.0, teto=0.89):
    x = x - x.mean(axis=0)
    rms = np.sqrt((x ** 2).mean())
    x = x * (10 ** (rms_db / 20) / rms)
    # limitador suave
    return np.tanh(x / teto) * teto


def salvar_wav(nome, x):
    wavfile.write(nome, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))


if __name__ == "__main__":
    mar = normalizar(mar_alto_mar(96.0), -21.0)
    salvar_wav("mar_novo.wav", mar)
    ondas = []
    for s in range(3):
        o = normalizar(onda_quebrando(7.5, 1.0, s), -19.0)
        salvar_wav("onda_nova_%d.wav" % s, o)
        ondas.append(o)

    # prévia "perto da costa": o laço novo um pouco mais baixo + ondas quebrando de 8 a 13 s (como o jogo faz)
    rng = np.random.default_rng(11)
    dur = 60.0
    n = int(dur * SR)
    costa = mar[:n] * 0.75
    t = 1.0
    while t < dur - 2:
        o = ondas[rng.integers(0, 3)] * rng.uniform(0.7, 1.0)
        somar(costa, o[:, 0] * 0 + o.mean(axis=1), t * SR, rng.uniform(-0.3, 0.3), circular=False)
        t += rng.uniform(8.0, 13.0)
    costa = normalizar(costa, -19.0)
    salvar_wav("previa_costa.wav", costa)
    print("ok")
