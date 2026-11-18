"""Sons novos do Pescador (v0.5.10): água no casco, motor a diesel, alerta (sino de bordo) e chuva.
Síntese procedural em numpy, sem amostras de terceiros. Laços circulares (sem emenda)."""
import numpy as np
import gerar_mar as G
from gerar_mar import SR, ruido, banda, bolha, explosao, somar, normalizar, salvar_wav

rng = np.random.default_rng(21)
G.rng = rng


def agua_casco(dur=24.0):
    """Água correndo pelo casco com o barco andando: rumor turbulento, a proa batendo nas marolas, esteira de bolhas."""
    n = int(dur * SR)
    out = np.zeros((n, 2))
    t = np.arange(n) / SR
    # turbulência: modulação rápida e irregular (circular)
    def mod_lenta(fmax, r):
        m = ruido(n, 2.0, 0.3, fmax, 0.5, r)
        return m / (np.abs(m).max() + 1e-9)
    r = np.random.default_rng(5)
    for c in range(2):
        corpo = ruido(n, 1.0, 250, 2600, 0.35, r)
        turb = 0.65 + 0.35 * mod_lenta(9.0, r)
        out[:, c] += 0.28 * corpo * turb
        rumor = ruido(n, 1.8, 60, 300, 0.4, r)
        out[:, c] += 0.22 * rumor * (0.7 + 0.3 * mod_lenta(2.0, r))
        sibilo = ruido(n, 1.0, 1800, 6000, 0.35, r)
        out[:, c] += 0.07 * sibilo * (0.5 + 0.5 * mod_lenta(5.0, r))
    # proa batendo nas marolas: "chuá" a cada 1,4 a 2,8 s
    tp = 0.3
    while tp < dur:
        pan = rng.uniform(-0.35, 0.35)
        s = explosao(rng.uniform(0.6, 1.0), 250, 2400, rng.uniform(0.04, 0.09), rng.uniform(0.16, 0.30))
        somar(out, 0.95 * rng.uniform(0.6, 1.0) * s, tp * SR, pan)
        borrifo = explosao(rng.uniform(0.5, 0.8), 1500, 7000, 0.05, rng.uniform(0.15, 0.25))
        somar(out, 0.13 * borrifo, (tp + 0.05) * SR, pan * 1.5)
        for b in range(rng.integers(20, 45)):
            f0 = np.exp(rng.uniform(np.log(600), np.log(3500)))
            somar(out, bolha(f0, 0.018 * rng.uniform(0.3, 1.0)), (tp + rng.exponential(0.4)) * SR, rng.uniform(-0.7, 0.7))
        tp += rng.uniform(1.4, 2.8)
    # esteira: bolhas o tempo todo, bem baixinho
    for b in range(int(dur * 40)):
        f0 = np.exp(rng.uniform(np.log(700), np.log(4000)))
        somar(out, bolha(f0, 0.007 * rng.uniform(0.2, 1.0)), rng.uniform(0, n), rng.uniform(-0.9, 0.9))
    return out


def motor_diesel(dur=12.0, rpm=560.0, cilindros=2):
    """Diesel de barco de pesca (3 cilindros, 4 tempos) em marcha lenta: o "tuc-tuc" com cilindros desiguais,
    escape borbulhando na água, batida de válvulas e o ronco do casco. O jogo sobe o tom com a velocidade."""
    n = int(dur * SR)
    out = np.zeros((n, 2))
    f_explosao = rpm / 60.0 * cilindros / 2.0            # explosões por segundo
    n_exp = int(round(dur * f_explosao))
    periodo = dur / n_exp                                 # número inteiro de explosões no laço
    forca_cil = [1.0, 0.84, 0.93]                        # cilindros desiguais: dá o "galope" do diesel velho
    tempos = np.arange(n_exp) * periodo
    tempos += rng.normal(0, periodo * 0.025, n_exp)       # pequena irregularidade
    tt = np.arange(int(0.12 * SR)) / SR
    for i, t0 in enumerate(tempos):
        f = forca_cil[i % cilindros] * rng.uniform(0.9, 1.08)
        # explosão: estalo grave (corpo do motor) + "pop" de escapamento
        corpo = np.sin(2 * np.pi * rng.uniform(52, 60) * tt) * np.exp(-tt / 0.042)
        corpo += 0.5 * np.sin(2 * np.pi * rng.uniform(105, 120) * tt) * np.exp(-tt / 0.018)
        corpo *= np.sin(np.minimum(1, tt * SR / 60) * np.pi / 2)
        somar(out, 0.55 * f * corpo, t0 * SR, 0.0)
        pop = explosao(0.12, 90, 900, 0.003, 0.022)
        somar(out, 0.40 * f * pop, t0 * SR, rng.uniform(-0.15, 0.15))
        # batida metálica (válvulas/injetor) logo depois
        tic = explosao(0.04, 1800, 5200, 0.0008, 0.006)
        somar(out, 0.07 * rng.uniform(0.6, 1.0) * tic, (t0 + periodo * 0.45) * SR, rng.uniform(-0.3, 0.3))
    # escape molhado: borbulhar grave que acompanha as explosões
    env = np.zeros(n)
    idx = (tempos * SR).astype(int) % n
    env[idx] = 1.0
    k = np.exp(-np.arange(int(0.09 * SR)) / SR / 0.035)
    env = np.real(np.fft.ifft(np.fft.fft(env) * np.fft.fft(np.pad(k, (0, n - len(k))))))
    for c in range(2):
        borb = ruido(n, 1.5, 120, 700)
        out[:, c] += 0.22 * borb * env
        # ronco contínuo do casco/motor
        out[:, c] += 0.12 * ruido(n, 2.0, 35, 160)
        # zumbido mecânico (engrenagem/eixo) bem baixo
        tt2 = np.arange(n) / SR
        out[:, c] += 0.025 * np.sin(2 * np.pi * (round(f_explosao * 6 * dur) / dur) * tt2 + c)
    return out


def sino(dur=1.9):
    """Alerta: sino de bordo de latão, duas batidas (como o sino do barco). Parciais de sino (inarmônicos)."""
    n = int(dur * SR)
    out = np.zeros((n, 2))
    base = 830.0
    parciais = [(0.5, 0.35, 1.6), (1.0, 1.0, 1.1), (1.19, 0.45, 0.8), (1.5, 0.30, 0.7), (2.0, 0.55, 0.55),
                (2.51, 0.22, 0.4), (2.66, 0.18, 0.35), (3.01, 0.15, 0.3), (4.1, 0.08, 0.18)]
    for j, t0 in enumerate([0.0, 0.34]):
        a = 1.0 if j == 0 else 0.85
        m = int((dur - t0) * SR)
        tt = np.arange(m) / SR
        s = np.zeros(m)
        for r, amp, dec in parciais:
            fr = base * r * (1 + rng.uniform(-0.002, 0.002))
            # batimento leve (sino real tem pares de modos um pouco desafinados)
            s += amp * np.sin(2 * np.pi * fr * tt) * (1 + 0.15 * np.sin(2 * np.pi * rng.uniform(1.5, 3.5) * tt)) * np.exp(-tt / dec)
        golpe = explosao(0.03, 2000, 9000, 0.0005, 0.004)
        s[:len(golpe)] += 0.5 * golpe
        s *= np.minimum(1, tt * SR / 30)
        somar(out, a * s, t0 * SR, -0.1 if j == 0 else 0.1, circular=False)
    t = np.arange(n) / SR
    out *= np.minimum(1, (dur - t) / 0.25)[:, None]
    return out


def chuva(dur=30.0):
    """Chuva no mar e no barco: chiado das gotas na água (com o pico agudo das bolhinhas), pingos no convés e
    na cabine de madeira, e respingos maiores escorrendo da cobertura. Rajadas lentas mudam a intensidade."""
    n = int(dur * SR)
    out = np.zeros((n, 2))
    r = np.random.default_rng(9)
    rajada = ruido(n, 2.0, 0.05, 0.4, 0.5, r)
    rajada = 0.75 + 0.25 * rajada / (np.abs(rajada).max() + 1e-9)
    for c in range(2):
        # gotas na água: base larga + pico das bolhas de gotas pequenas (~12-15 kHz, suave)
        out[:, c] += 0.30 * ruido(n, 0.8, 400, 9000, 0.35, r) * rajada
        out[:, c] += 0.10 * banda(r.standard_normal(n), 11000, 15500, 0.15) * rajada
        out[:, c] += 0.10 * ruido(n, 1.6, 80, 500, 0.4, r) * rajada          # rumor grave da chuva no mar
    # gotas individuais na água perto (bolhinha + respingo)
    for k in range(int(dur * 260)):
        t0 = rng.uniform(0, n)
        f0 = np.exp(rng.uniform(np.log(1200), np.log(6000)))
        somar(out, bolha(f0, 0.012 * rng.uniform(0.2, 1.0), 0.03), t0, rng.uniform(-1, 1))
    # pingos na madeira (convés/cabine): tique curto com ressonância de tábua
    for k in range(int(dur * 22)):
        t0 = rng.uniform(0, n)
        fr = rng.uniform(900, 2600)
        tt = np.arange(int(0.05 * SR)) / SR
        tic = np.sin(2 * np.pi * fr * tt) * np.exp(-tt / rng.uniform(0.004, 0.010))
        e = explosao(0.02, 2500, 8000, 0.0004, 0.002)
        tic[:len(e)] += 0.6 * e
        somar(out, 0.05 * rng.uniform(0.3, 1.0) * tic, t0, rng.uniform(-0.8, 0.8))
    # respingos maiores escorrendo da cobertura (de vez em quando)
    for k in range(int(dur * 0.7)):
        t0 = rng.uniform(0, n)
        f0 = rng.uniform(500, 900)
        pl = bolha(f0, 0.10, 0.12)
        somar(out, pl, t0, rng.uniform(-0.6, 0.6))
    return out


def ajustar_ao_antigo(novo, antigo_wav):
    """Mesmo volume médio (RMS) do som antigo, para não desequilibrar a mixagem do jogo."""
    from scipy.io import wavfile
    sr, a = wavfile.read(antigo_wav)
    a = a.astype(float) / 32768
    rms_a = 20 * np.log10(np.sqrt((a ** 2).mean()))
    return normalizar(novo, rms_a)


if __name__ == "__main__":
    salvar_wav("agua_casco_novo.wav", ajustar_ao_antigo(agua_casco(), "agua_casco_atual.wav"))
    salvar_wav("motor_diesel_novo.wav", ajustar_ao_antigo(motor_diesel(), "motor_diesel_atual.wav"))
    salvar_wav("aviso_novo.wav", ajustar_ao_antigo(sino(), "aviso_atual.wav"))
    salvar_wav("chuva_novo.wav", ajustar_ao_antigo(chuva(), "chuva_atual.wav"))
    print("ok")
