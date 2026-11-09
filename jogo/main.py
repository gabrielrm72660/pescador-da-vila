#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
NÁUFRAGO — jogo de sobrevivência no mar
=======================================
Seu navio afundou e você está sozinho num barquinho no meio do oceano.
Sobreviva à fome, à sede, às tempestades e aos tubarões enquanto navega
até a ilha, que fica a dias de viagem.

Requisitos:  pip install pygame
Executar:    python main.py            (teclado)
             python main.py --toque    (testa os botões de toque com o mouse)
No celular roda com toque: veja o LEIAME.md (versão web com pygbag ou APK com Buildozer).
"""

import asyncio
import math
import os
import random
import sys

import pygame
from animacoes import Animacoes
from oceano import Oceano
from ilha_vila import IlhaVila


def _plataforma():
    if sys.platform == "emscripten":
        return "web"                      # pygbag (navegador, inclusive no celular)
    if "ANDROID_ARGUMENT" in os.environ or hasattr(sys, "getandroidapilevel"):
        return "android"                  # APK feito com python-for-android / Buildozer
    return "desktop"


PLATAFORMA = _plataforma()
APRESENTACAO = None
PASTA = os.path.dirname(os.path.abspath(__file__))

# ----------------------------------------------------------------------------
# Configurações gerais (mexa à vontade para ajustar a dificuldade)
# ----------------------------------------------------------------------------
LARGURA, ALTURA = 1100, 720   # tamanho lógico da tela (no celular é recalculado em abrir_tela)
FPS = 100
DURACAO_DIA = 150.0       # segundos reais que dura um dia inteiro (dia + noite) no jogo
ALONGA_DIA = 0.55         # 0 = o relógio anda sempre igual; quanto maior, mais o dia claro se alonga e a noite
                          # encurta (0,55 deixa ~2/3 do ciclo com sol). Fica abaixo de 1.
DIST_ILHA = 48000.0       # distância inicial até a ilha (em pixels do mundo; ~240 mi na bússola)
RAIO_ILHA = 340.0         # chegou dentro desse raio = salvo

CONSUMO_FOME = 0.45       # pontos por segundo
CONSUMO_SEDE = 0.65
VEL_REMO = 115.0
VEL_VELA = 95.0
VEL_MAX = 185.0

# Consertos do casco: a tábua é o remendo bom; a corda é mais comum, mas remenda menos.
CASCO_TABUA = 25
CASCO_CORDA = 12
LANTERNA_CONSERTO = {"madeira": 4, "corda": 4}   # o que custa consertar a lanterna quebrada
LANTERNA_FOLGA = 90.0    # segundos em que a lanterna consertada (ou recém-quebrada) não quebra de novo

# Baús dourados: boiam no mar e guardam melhorias permanentes para o barco (uma de cada por partida).
BAU_PRIMEIRO = (40.0, 55.0)   # segundos até o primeiro baú aparecer
BAU_ENTRE = (55.0, 90.0)      # espera até o próximo baú, depois de pegar um
MELHORIAS = ("casco", "remos", "vela", "leme", "lente", "rede")
# O baú dá a PLANTA da melhoria; para montar o barco precisa de material (tábuas e cordas do inventário).
# Vela e remos (a velocidade do barco) pedem mais corda: ela também serve para remendar o casco, então
# gastar com a vela é uma escolha.
RECEITAS = {
    "casco": {"madeira": 3},
    "remos": {"madeira": 2, "corda": 2},
    "vela": {"madeira": 1, "corda": 4},
    "leme": {"madeira": 2, "corda": 1},
    "lente": {"madeira": 2},
    "rede": {"corda": 3},
}
NOME_MAT = {"madeira": ("tábua", "tábuas"), "corda": ("corda", "cordas")}

# Habilidades do náufrago (RPG): cada nível de experiência dá 1 ponto; cada habilidade vai até o nível 5.
HABILIDADES = ("pesca", "remo", "vela", "mente", "corpo")
HAB_MAX = 5
INFO_HAB = {
    "pesca": ("Pescador", "Pesca 12% mais rápida e 7% de chance de peixe extra, por nível."),
    "remo": ("Remador", "Remada 5% mais veloz e 7% menos cansaço, por nível."),
    "vela": ("Navegador", "Vela 6% mais veloz por nível. No nível 3, a bússola mostra a distância."),
    "mente": ("Mente de aço", "A escuridão e as criaturas pesam 8% menos na sanidade, por nível."),
    "corpo": ("Sobrevivente", "Fome e sede passam 7% mais devagar e a vida volta mais rápido, por nível."),
}
SAN_VULTO = 50.0          # o gigante do fundo só desperta quando a sanidade cai abaixo disso
INFO_MELHORIA = {
    "casco": ("Casco reforçado", "Cintas de ferro: o casco sofre 35% menos dano (e já ganha um remendo)."),
    "remos": ("Remos longos", "Remar rende 20% mais velocidade e cansa 25% menos."),
    "vela": ("Vela grande", "A vela rende 30% mais velocidade com o vento."),
    "leme": ("Leme de popa", "O barco vira mais rápido e as ondas o empurram menos."),
    "lente": ("Lente da lanterna", "A luz vai mais longe e a escuridão pesa menos na mente."),
    "rede": ("Rede de pesca", "Pescar fica 40% mais rápido e a rede rende peixe extra."),
}

BRANCO = (245, 245, 245)
VERMELHO = (255, 120, 120)
VERDE = (150, 235, 150)
AMARELO = (255, 225, 120)
CINZA = (200, 205, 212)
AZUL_CLARO = (140, 205, 255)

AGUA_DIA = (24, 118, 168)
AGUA_NOITE = (6, 20, 48)
AGUA_TEMPESTADE = (38, 66, 84)

RUMOS = ["N", "NE", "L", "SE", "S", "SO", "O", "NO"]

# Horror cósmico: quanto de sanidade se perde por segundo em cada situação
SAN_NOITE = 0.27           # só por estar no mar à noite (x intensidade da noite)
SAN_SEM_LANTERNA = 0.50    # extra, no escuro total (lanterna apagada ou quebrada)
SAN_VULTO_PERTO = 0.75     # gigante nadando a menos de 250 px
SAN_VULTO_LONGE = 0.15     # gigante a menos de 700 px
SAN_TENTACULO = 0.65       # tentáculo emergido a menos de 320 px
SAN_OLHOS = 0.10           # cada par de olhos acesos no escuro
SAN_REGEN_DIA = 0.75       # recuperação à luz do dia


def fase_do_dia(t):
    """Posição do sol no ciclo: 0 = meia-noite, 0,25 = amanhecer, 0,5 = meio-dia, 0,75 = entardecer.

    O tempo não passa igual o dia todo: perto do meio-dia o relógio anda mais devagar (o dia dura mais) e perto
    da meia-noite anda mais depressa (a noite passa mais rápido). A curva é suave, sem trancos no amanhecer."""
    u = (t % DURACAO_DIA) / DURACAO_DIA
    return u + ALONGA_DIA / math.tau * math.sin(math.tau * u)


def tempo_da_fase(fase):
    """Inverso de fase_do_dia: em que instante do ciclo (s) o sol está em 'fase' (0 a 1)."""
    lo, hi = 0.0, 1.0
    for _ in range(40):
        meio = (lo + hi) / 2
        if meio + ALONGA_DIA / math.tau * math.sin(math.tau * meio) < fase:
            lo = meio
        else:
            hi = meio
    return (lo + hi) / 2 * DURACAO_DIA

VIOLETA = (200, 160, 255)
SUSSURRO_HUD = ["S4nid4de", "ELE VÊ", "NÃO OLHE", "S a n i d a d e"]   # rótulo da barra com a mente falhando

SUSSURROS = [
    "Algo sussurra seu nome sob as ondas...",
    "Os olhos do fundo se abrem, um a um.",
    "Não olhe para baixo. Não olhe para baixo.",
    "Ele dorme, mas sonha com você.",
    "Ph'nglui mglw'nafh... fhtagn.",
    "As estrelas refletidas na água estão erradas.",
    "Há uma cidade lá embaixo. Ela te espera.",
    "O mar respira. Devagar. Em uníssono com você.",
    "Você ouve um canto sem boca, sem voz, sem fim.",
    "Alguma coisa muito antiga acabou de virar de lado.",
]

# bilhetes das garrafas (cada um com duas linhas)
NOTAS = [
    ("Diário do capitão, noite 9: algo enorme passa sob o casco.",
     "Mantenham a lanterna acesa. No escuro, ELE nos vê."),
    ("Quem dorme em R'lyeh sonha — e os sonhos vêm à tona com a maré.",
     "Quando o braço negro subir, bata nele com o remo. Ele recua."),
    ("Perdi a conta dos dias. As estrelas não estão onde deveriam.",
     "Só o sol me devolve a mente. De dia, o mar fica quieto."),
    ("Não confie nos olhos que brilham na água à noite.",
     "Alguns existem. Outros só existem para você."),
    ("O imediato mergulhou ontem, sorrindo, atrás de uma música.",
     "Se ouvir o canto, agarre o mastro e conte até cem."),
]


# ----------------------------------------------------------------------------
# Funções auxiliares
# ----------------------------------------------------------------------------
def limitar(v, a, b):
    return max(a, min(b, v))


def lerp(a, b, t):
    return a + (b - a) * t


def misturar(c1, c2, t):
    t = limitar(t, 0.0, 1.0)
    return (int(lerp(c1[0], c2[0], t)),
            int(lerp(c1[1], c2[1], t)),
            int(lerp(c1[2], c2[2], t)))


def dif_ang(a, b):
    """Menor diferença angular assinada de a para b."""
    return (b - a + math.pi) % math.tau - math.pi


def girar(pontos, ang, cx, cy, escala=1.0):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + (px * c - py * s) * escala, cy + (px * s + py * c) * escala)
            for px, py in pontos]


def definir_tela(largura, altura):
    """Muda o tamanho lógico da tela. Deve ser chamado antes de criar o Jogo."""
    global LARGURA, ALTURA
    LARGURA, ALTURA = int(largura), int(altura)


def fonte(tam, negrito=False):
    """Fonte embutida (a pasta fontes/ viaja junto no APK); o Android não tem Segoe/Arial."""
    arq = os.path.join(PASTA, "fontes", "DejaVuSansCondensed-Bold.ttf" if negrito
                       else "DejaVuSansCondensed.ttf")
    try:
        return pygame.font.Font(arq, tam)
    except (OSError, pygame.error):
        return pygame.font.SysFont("segoeui,arial,dejavusans,freesans", tam, bold=negrito)


def nome_rumo(ang):
    """Converte um ângulo do mundo (0 = leste, -90° = norte) em rumo de bússola."""
    graus = (math.degrees(ang) + 90) % 360
    return RUMOS[int((graus + 22.5) // 45) % 8], int(graus)


# ----------------------------------------------------------------------------
# Arte (sprites)
# ----------------------------------------------------------------------------
IMAGENS = os.path.join(PASTA, "imagens")
ESCALA_BARCO = 0.29        # pixels da tela por pixel do sprite do barco (o barco todo tem ~85 px)
BARCO_TELA_H = 372        # altura da tela comum dos sprites do barco (arte/cortar_arte.py)
ESCALA_AGUA = 0.85         # tamanho dos tiles de água em relação ao arquivo


class Arte:
    """Sprites da pasta imagens/ (arte nova, cortada das folhas por arte/cortar_arte.py).
    Tudo é opcional: se um arquivo faltar, quem pede recebe None e usa o desenho por código."""

    def __init__(self):
        self.cache = {}
        self.meta = {}
        try:
            import json
            with open(os.path.join(IMAGENS, "meta.json")) as f:
                self.meta = json.load(f)
        except Exception:
            self.meta = {}
        self.ok = "barco" in self.meta and os.path.isfile(os.path.join(IMAGENS, "barco_base.png"))

    def _ler(self, nome):
        k = ("raw", nome)
        if k not in self.cache:
            try:
                self.cache[k] = pygame.image.load(os.path.join(IMAGENS, nome + ".png")).convert_alpha()
            except Exception:
                self.cache[k] = None
        return self.cache[k]

    def get(self, nome, w=None, h=None, fit=None):
        """Sprite suavizado no tamanho pedido: w ou h fixa uma medida e mantém a proporção;
        fit=(w, h) cabe dentro da caixa. Fica em cache, então pedir de novo é de graça."""
        chave = (nome, w, h, fit)
        if chave in self.cache:
            return self.cache[chave]
        raw = self._ler(nome)
        if raw is None:
            self.cache[chave] = None
            return None
        rw, rh = raw.get_size()
        esc = 1.0
        if fit:
            esc = min(fit[0] / rw, fit[1] / rh)
        elif w:
            esc = w / rw
        elif h:
            esc = h / rh
        nw, nh = max(1, round(rw * esc)), max(1, round(rh * esc))
        s = pygame.transform.smoothscale(raw, (nw, nh)) if (nw, nh) != (rw, rh) else raw
        self.cache[chave] = s
        return s

    def ondular(self, nome, quadros=8, amp=3.0, eixo="x", ancora="min", ciclos=1.0, w=None, h=None):
        """O sprite ondulando, em 'quadros' imagens que fecham o ciclo (loop sem emenda). O sprite é fatiado em
        tiras de 1-2 px ao longo do 'eixo' e cada tira desliza para o lado (perpendicular) numa onda que anda
        da âncora para o outro fim; a onda cresce de zero na âncora até 'amp' px na ponta (a cabeça do peixe
        fica quieta, o rabo balança; o tronco da palmeira fica parado, a copa balança)."""
        chave = ("onda", nome, quadros, amp, eixo, ancora, ciclos, w, h)
        if chave in self.cache:
            return self.cache[chave]
        base = self.get(nome, w=w, h=h)
        if base is None:
            self.cache[chave] = None
            return None
        bw, bh = base.get_size()
        a = int(math.ceil(amp))
        tira = 2 if max(bw, bh) > 60 else 1
        lista = []
        for q in range(quadros):
            fase = q / float(quadros)
            if eixo == "x":
                out = pygame.Surface((bw, bh + 2 * a), pygame.SRCALPHA, 32)
                for x in range(0, bw, tira):
                    u = x / float(max(1, bw - 1))
                    u = u if ancora == "min" else 1.0 - u
                    d = amp * (u ** 1.4) * math.sin(math.tau * (ciclos * u - fase))
                    out.blit(base, (x, a + int(round(d))), (x, 0, tira, bh))
            else:
                out = pygame.Surface((bw + 2 * a, bh), pygame.SRCALPHA, 32)
                for y in range(0, bh, tira):
                    u = y / float(max(1, bh - 1))
                    u = u if ancora == "min" else 1.0 - u
                    d = amp * (u ** 1.4) * math.sin(math.tau * (ciclos * u - fase))
                    out.blit(base, (a + int(round(d)), y), (0, y, bw, tira))
            lista.append(out)
        self.cache[chave] = lista
        return lista

    def rot(self, nome, graus, passo=6, w=None, h=None, tinta=None, alfa=None, escuro=False, soma=None,
            onda=None, quadro=0, guardar=True):
        """Sprite girado (graus anti-horários, como o rotozoom), com o ângulo arredondado de 'passo' em
        'passo' graus para caber no cache. 'tinta' multiplica as cores, 'escuro' faz a sombra na água.
        'onda' = argumentos de ondular() (quadros, amp, eixo, ancora, ciclos) e 'quadro' = qual deles."""
        q = int(round(graus / passo)) % int(round(360 / passo))
        chave = ("rot", nome, q, passo, w, h, tinta, alfa, escuro, soma, onda, quadro % onda[0] if onda else 0)
        if chave in self.cache:
            return self.cache[chave]
        if onda:
            lista = self.ondular(nome, *onda, w=w, h=h)
            base = lista[quadro % len(lista)] if lista else None
        else:
            base = self.get(nome, w=w, h=h)
        if base is None:
            self.cache[chave] = None
            return None
        if tinta or escuro or soma:
            base = base.copy()
            if tinta or escuro:
                base.fill((18, 40, 64, 255) if escuro else tinta, special_flags=pygame.BLEND_RGBA_MULT)
            if soma:
                base.fill(soma + (0,), special_flags=pygame.BLEND_RGBA_ADD)
        r = pygame.transform.rotozoom(base, q * passo, 1.0)
        if escuro:
            r.set_alpha(80)
        elif alfa is not None:
            r.set_alpha(alfa)
        if guardar:
            self.cache[chave] = r
        return r

    def quadro(self, w, h, borda=5):
        """Moldura de madeira (moldura_quadro) esticada para w x h em 9 fatias: só as bordas, o miolo
        fica transparente (o painel desenha o próprio fundo translúcido por baixo)."""
        chave = ("quadro", w, h, borda)
        if chave in self.cache:
            return self.cache[chave]
        raw = self._ler("moldura_quadro")
        if raw is None or w < 2 * borda + 2 or h < 2 * borda + 2:
            self.cache[chave] = None
            return None
        rw, rh = raw.get_size()
        f = 23                                                  # largura da borda no sprite original

        def fatia(x, y, ww, hh, nw, nh):
            return pygame.transform.smoothscale(raw.subsurface((x, y, ww, hh)), (max(1, nw), max(1, nh)))
        out = pygame.Surface((w, h), pygame.SRCALPHA, 32)
        b = borda
        out.blit(fatia(0, 0, f, f, b, b), (0, 0))
        out.blit(fatia(rw - f, 0, f, f, b, b), (w - b, 0))
        out.blit(fatia(0, rh - f, f, f, b, b), (0, h - b))
        out.blit(fatia(rw - f, rh - f, f, f, b, b), (w - b, h - b))
        out.blit(fatia(f, 0, rw - 2 * f, f, w - 2 * b, b), (b, 0))
        out.blit(fatia(f, rh - f, rw - 2 * f, f, w - 2 * b, b), (b, h - b))
        out.blit(fatia(0, f, f, rh - 2 * f, b, h - 2 * b), (0, b))
        out.blit(fatia(rw - f, f, f, rh - 2 * f, b, h - 2 * b), (w - b, b))
        self.cache[chave] = out
        return out

    def apagado(self, nome, **kw):
        """Versão 'sem o item': mais escura e fosca."""
        chave = ("apagado", nome, tuple(sorted(kw.items())))
        if chave not in self.cache:
            s = self.get(nome, **kw)
            if s is None:
                self.cache[chave] = None
            else:
                s = s.copy()
                s.fill((96, 100, 112, 255), special_flags=pygame.BLEND_RGBA_MULT)
                self.cache[chave] = s
        return self.cache[chave]

    def mosaico(self, nome, largura, altura, suave=0.0):
        """Superfície grande, sem emenda, com o tile de água repetido (o tile é espelhado em 2 x 2,
        porque os tiles vindos da folha não casam nas bordas). Devolve (superfície, tw, th)."""
        chave = ("mosaico", nome, largura, altura, suave)
        if chave in self.cache:
            return self.cache[chave]
        raw = self._ler(nome)
        if raw is None:
            self.cache[chave] = None
            return None
        rw, rh = raw.get_size()
        t = pygame.transform.smoothscale(raw, (max(8, int(rw * ESCALA_AGUA)), max(8, int(rh * ESCALA_AGUA)))).convert()
        if suave > 0:                       # abaixa o contraste (as cristas brancas gritam perto dos sprites)
            media = pygame.transform.average_color(t)
            veu = pygame.Surface(t.get_size()).convert()
            veu.fill(media)
            veu.set_alpha(int(255 * suave))
            t.blit(veu, (0, 0))
        w, h = t.get_size()
        bloco = pygame.Surface((w * 2, h * 2)).convert()
        bloco.blit(t, (0, 0))
        bloco.blit(pygame.transform.flip(t, True, False), (w, 0))
        bloco.blit(pygame.transform.flip(t, False, True), (0, h))
        bloco.blit(pygame.transform.flip(t, True, True), (w, h))
        bw, bh = bloco.get_size()
        big = pygame.Surface((largura + bw, altura + bh)).convert()
        for x in range(0, largura + bw, bw):
            for y in range(0, altura + bh, bh):
                big.blit(bloco, (x, y))
        r = (big, bw, bh)
        self.cache[chave] = r
        return r

    def cor_media(self, nome):
        raw = self._ler(nome)
        if raw is None:
            return None
        c = pygame.transform.average_color(raw)
        return (c[0], c[1], c[2])


def girar_spr(spr, ang, cima=True, extra=0.0):
    """Gira um sprite para o rumo 'ang' do mundo (0 = leste, y para baixo). Se o desenho olha para
    cima (cima=True) a proa é o topo; senão, o sprite olha para a esquerda (peixes, tubarão de lado)."""
    graus = -math.degrees(ang) - 90.0 if cima else 180.0 - math.degrees(ang)
    return pygame.transform.rotozoom(spr, graus + extra, 1.0)


# ----------------------------------------------------------------------------
# Entidades
# ----------------------------------------------------------------------------
class Barco:
    def __init__(self):
        self.x = 0.0
        self.y = 0.0
        self.ang = -math.pi / 2     # apontando para o norte (cima da tela)
        self.vel = 0.0
        self.vela = True
        self.push = [0.0, 0.0]      # empurrão de ondas
        self.remando = False
        self.timao = 0.0            # -1 (esquerda) a +1 (direita), suavizado: mexe o leme desenhado


class Item:
    """Coisas que boiam: barril, tábua, corda, garrafa e o baú dourado (melhoria do barco)."""

    def __init__(self, tipo, x, y):
        self.tipo = tipo
        self.x = x
        self.y = y
        self.fase = random.uniform(0, math.tau)
        self.ang = random.uniform(0, math.tau)


CARDUME_VEL = 22.0         # o cardume inteiro deriva nesta velocidade (px/s)


class Cardume:
    """Peixes nadando juntos para o mesmo lado, como um bando: cada um tem um lugar (à frente, ao lado)
    que ele balança de leve, e o rumo dele acompanha esse vaivém."""

    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.n = random.randint(3, 6)
        self.dir = random.uniform(0, math.tau)
        self.giro = 0.0
        self.fase = random.uniform(0, math.tau)
        # (à frente, ao lado, fase do vaivém, ritmo do vaivém)
        self.peixes = [(random.uniform(-28, 28), random.uniform(-26, 26), random.uniform(0, math.tau),
                        random.uniform(0.7, 1.4)) for _ in range(6)]

    def atualizar(self, dt):
        self.giro = limitar(self.giro + random.uniform(-1, 1) * dt * 0.9, -0.3, 0.3)    # curva suave
        self.dir += self.giro * dt
        self.x += math.cos(self.dir) * CARDUME_VEL * dt
        self.y += math.sin(self.dir) * CARDUME_VEL * dt


class Tubarao:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.ang = random.uniform(0, math.tau)
        self.hp = 3
        self.estado = "rondar"      # rondar -> atacar -> fugir
        self.t = random.uniform(3, 6)
        self.fuga = 0.0
        self.orbita = random.choice((-1, 1))
        self.mordida = 1.2
        self.mordidas = 0
        self.piscar = 0.0

    def atualizar(self, dt, barco, jogo):
        dx, dy = barco.x - self.x, barco.y - self.y
        d = math.hypot(dx, dy) + 1e-6
        para_barco = math.atan2(dy, dx)
        vel = 100.0

        if self.estado == "fugir":
            self.fuga -= dt
            desejado = para_barco + math.pi
            vel = 150.0
            if self.fuga <= 0:
                self.estado = "rondar"
                self.t = random.uniform(2, 4)
        elif self.estado == "rondar":
            self.t -= dt
            tang = para_barco + self.orbita * math.pi / 2
            if d > 320:
                desejado = para_barco
            elif d > 180:
                desejado = tang - self.orbita * 0.6
            else:
                desejado = tang + self.orbita * 0.5
            vel = 95.0
            if self.t <= 0:
                self.estado = "atacar"
        else:  # atacar
            desejado = para_barco
            vel = 135.0
            if d < 58:
                vel = max(60.0, barco.vel * 0.8)
                self.mordida -= dt
                if self.mordida <= 0:
                    self.mordida = 2.0
                    jogo.mordida_tubarao(self)

        self.ang += limitar(dif_ang(self.ang, desejado), -3.2 * dt, 3.2 * dt)
        self.x += math.cos(self.ang) * vel * dt
        self.y += math.sin(self.ang) * vel * dt
        self.piscar = max(0.0, self.piscar - dt)


# ----------------------------------------------------------------------------
# Vida marinha: golfinhos (bandos) e baleias (raras)
# ----------------------------------------------------------------------------
ONDA_GOLFINHO = (16, 2.4, "y", "min", 0.9)
ONDA_BALEIA = (20, 6.0, "y", "min", 0.6)
H_GOLFINHO = 62
H_BALEIA = 290


class Bando:
    """Golfinhos: vêm até o barco, nadam na proa (ou dão voltas nele, se ele estiver parado), saltam de vez em
    quando e vão embora. Dão coragem (sanidade) e afugentam tubarões."""

    def __init__(self, x, y, n, rumo):
        self.x, self.y, self.ang = x, y, rumo
        self.n = n
        self.t = 0.0
        self.vida = random.uniform(22, 34)          # segundos até irem embora (ficam pouco com o barco)
        self.visto = False
        self.membros = [{"fr": random.uniform(-30, 12) - i * 5.0, "lat": (i - (n - 1) / 2.0) * random.uniform(30, 42),
                         "fase": random.uniform(0, math.tau), "salto": -1.0, "prox": random.uniform(2, 5),
                         "dur": random.uniform(0.8, 1.1)} for i in range(n)]

    def atualizar(self, dt, barco, jogo):
        self.t += dt
        self.vida -= dt
        dx, dy = barco.x - self.x, barco.y - self.y
        d = math.hypot(dx, dy) + 1e-6
        para = math.atan2(dy, dx)
        if self.vida > 0:
            if barco.vel > 25:       # barco andando: nadam um pouco à frente e ao lado da proa
                lado = math.sin(self.t * 0.3) * 60
                qx = barco.x + math.cos(barco.ang) * 70 - math.sin(barco.ang) * lado
                qy = barco.y + math.sin(barco.ang) * 70 + math.cos(barco.ang) * lado
            else:                    # barco parado: dão voltas em volta dele
                qx = barco.x + math.cos(self.t * 0.4) * 150
                qy = barco.y + math.sin(self.t * 0.4) * 150
            dq = math.hypot(qx - self.x, qy - self.y)
            desejado = math.atan2(qy - self.y, qx - self.x)
            vel = limitar(40 + dq * 0.6, 40, 175)
            if dq < 70 and barco.vel > 25:
                desejado = barco.ang
                vel = max(40.0, barco.vel * 1.05)
        else:                        # hora de partir
            desejado = para + math.pi
            vel = 135.0
        self.ang += limitar(dif_ang(self.ang, desejado), -2.4 * dt, 2.4 * dt)
        self.x += math.cos(self.ang) * vel * dt
        self.y += math.sin(self.ang) * vel * dt
        if d < 420 and not self.visto:
            self.visto = True
            jogo.msg("Golfinhos! Eles nadam ao lado do barco e afastam os tubarões.", VERDE)
            jogo._xp(8)
        for i, m in enumerate(self.membros):                 # saltos
            if m["salto"] >= 0:
                m["salto"] += dt / m["dur"]
                if m["salto"] >= 1.0:
                    m["salto"] = -1.0
                    m["prox"] = random.uniform(4, 9)
                    jogo._respingo(self._pos(m)[0], self._pos(m)[1])
            elif self.vida > 0 and d < 600:
                m["prox"] -= dt
                if m["prox"] <= 0:
                    m["salto"] = 0.0
                    jogo._respingo(self._pos(m)[0], self._pos(m)[1])

    def _pos(self, m):
        fr = m["fr"] + math.sin(self.t * 0.9 + m["fase"]) * 6
        lat = m["lat"] + math.sin(self.t * 1.1 + m["fase"] * 2) * 5
        ca, sa = math.cos(self.ang), math.sin(self.ang)
        return self.x + ca * fr - sa * lat, self.y + sa * fr + ca * lat


class Baleia:
    """Jubarte enorme, rara: atravessa o caminho do barco devagar, mergulha e volta, soltando jatos de água.
    Ouvir seu canto acalma a mente."""

    def __init__(self, x, y, rumo):
        self.x, self.y, self.ang = x, y, rumo
        self.vel = 24.0
        self.t = 0.0
        self.fase = random.uniform(0, math.tau)
        self.ciclo = random.uniform(0, 38.0)
        self.profund = 0.0                  # 0 = na superfície, 1 = mergulhada
        self.sopro_cd = random.uniform(2.0, 5.0)
        self.sopros = []                    # [idade, x, y]
        self.visto = False
        self.bateu = False

    def cabeca(self):
        return self.x + math.cos(self.ang) * 86, self.y + math.sin(self.ang) * 86

    def atualizar(self, dt, barco, jogo):
        self.t += dt
        self.ang += math.sin(self.t * 0.11 + self.fase) * 0.03 * dt
        self.x += math.cos(self.ang) * self.vel * dt
        self.y += math.sin(self.ang) * self.vel * dt
        alvo = 0.0 if (self.t + self.ciclo) % 38.0 < 24.0 else 1.0
        self.profund += limitar(alvo - self.profund, -dt / 3.5, dt / 3.5)
        self.sopro_cd -= dt
        if self.sopro_cd <= 0 and self.profund < 0.3:
            self.sopro_cd = random.uniform(7.0, 10.0)
            hx, hy = self.cabeca()
            self.sopros.append([0.0, hx, hy])
        for so in self.sopros:
            so[0] += dt
        self.sopros = [so for so in self.sopros if so[0] < 2.2]
        d = math.hypot(barco.x - self.x, barco.y - self.y)
        if d < 750 and not self.visto:
            self.visto = True
            jogo.msg("Uma BALEIA! O canto grave atravessa o casco e, por um instante, a mente aquieta.", AZUL_CLARO)
            jogo.sanidade = min(100.0, jogo.sanidade + 10.0)
            jogo._xp(40)
        # corpo (um segmento de ponta a ponta): se o barco chega muito perto, as ondas o empurram
        if self.profund < 0.6:
            ca, sa = math.cos(self.ang), math.sin(self.ang)
            u = limitar((barco.x - self.x) * ca + (barco.y - self.y) * sa, -110.0, 110.0)
            px, py = self.x + ca * u, self.y + sa * u
            dd = math.hypot(barco.x - px, barco.y - py) + 1e-6
            if dd < 62:
                barco.push[0] += (barco.x - px) / dd * 90 * dt
                barco.push[1] += (barco.y - py) / dd * 90 * dt
                jogo.tremor = max(jogo.tremor, 0.15)
                if not self.bateu:
                    self.bateu = True
                    jogo.msg("A baleia passa rente ao barco! O casco estremece.", AZUL_CLARO)


# ----------------------------------------------------------------------------
# Horror cósmico: o que dorme no fundo
# ----------------------------------------------------------------------------
class Vulto:
    """Ser colossal que nada sob o barco durante a noite. Só se vê a silhueta e os olhos."""

    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.ang = random.uniform(0, math.tau)
        self.tam = random.uniform(1.0, 1.4)
        self.fase = random.uniform(0, math.tau)
        self.orb = random.choice((-1, 1))
        self.vis = 0.0              # 0 = invisível, 1 = totalmente à vista
        self.afundando = False
        self.pts_tent = []          # pontos na tela (preenchidos ao desenhar), usados no brilho
        self.var = random.randint(0, 1)     # qual sprite da arte nova (vulto_a ou vulto_b)
        self.olhos_tela = []        # (x, y, raio, fase, cor) na tela, preenchido ao desenhar o sprite
        self.tent = [(i * math.tau / 11 + random.uniform(-0.2, 0.2),
                      random.uniform(170, 300), random.uniform(0, math.tau)) for i in range(11)]
        self.olhos = [(random.uniform(-34, 34), random.uniform(-30, 30), random.uniform(5, 11),
                       random.uniform(0, math.tau), random.choice((0, 0, 1, 2))) for _ in range(9)]

    def atualizar(self, dt, barco, jogo):
        nf = jogo.noite_f()
        dx, dy = barco.x - self.x, barco.y - self.y
        d = math.hypot(dx, dy) + 1e-6
        para = math.atan2(dy, dx)
        raio = 150 + 170 * (1 - nf)       # quanto mais escuro, mais perto ele chega
        tang = para + self.orb * math.pi / 2
        if d > raio + 80:
            desejado = para
        elif d < raio - 80:
            desejado = tang - self.orb * 1.1
        else:
            desejado = tang
        self.ang += limitar(dif_ang(self.ang, desejado), -0.5 * dt, 0.5 * dt)
        # se o barco se afasta, ele acelera para continuar embaixo dele
        vel = 42.0 + limitar((d - raio) / 300.0, 0.0, 1.0) * (max(0.0, barco.vel) * 1.1 + 30.0)
        self.x += math.cos(self.ang) * vel * dt
        self.y += math.sin(self.ang) * vel * dt
        self.fase += dt * 0.9
        if nf < 0.3 or jogo.sanidade > SAN_VULTO + 12:      # amanheceu, ou a mente se recompôs: ele volta ao fundo
            self.afundando = True
        if self.afundando:
            self.vis = max(0.0, self.vis - dt / 4.0)
        else:
            self.vis = min(1.0, self.vis + dt / 5.0)


class Tentaculo:
    """Tentáculo que emerge perto do barco, paira e tenta agarrar o casco."""
    T_EMERGIR, T_PAIRAR, T_GOLPEAR, T_AGARRAR, T_RECOLHER = 2.6, 1.3, 0.35, 0.7, 1.3

    def __init__(self, x, y, barco):
        self.x = x                  # base, na água
        self.y = y
        self.ang = math.atan2(barco.y - y, barco.x - x)
        self.alcance = random.uniform(150, 200)
        self.fase = random.uniform(0, math.tau)
        self.arco = random.choice((-1, 1))
        self.estado = "emergir"     # emergir -> pairar -> golpear -> agarrar -> recolher
        self.t = 0.0
        self.altura = 0.0           # 0 = submerso, 1 = totalmente fora
        self.ponta = (x, y)
        self.p0 = (x, y)
        self.alt0 = 0.0
        self.morto = False
        self.pts = []               # pontos na tela (preenchidos ao desenhar)

    @property
    def alcance_max(self):
        return self.alcance * 1.4

    def _ir(self, estado):
        self.estado = estado
        self.t = 0.0
        self.p0 = self.ponta
        self.alt0 = self.altura

    def ferir(self, jogo):
        """Levou uma remada: recua para o fundo."""
        if self.estado != "recolher":
            self._ir("recolher")
            jogo.stats["tentaculos"] += 1
            jogo._xp(30)
            jogo.som.agendar("acerto", 0.12)
            jogo.som_em("tentaculo_recua", self.x, self.y, 0.9)
            jogo.msg("O tentáculo recua para a escuridão!", AMARELO)

    def atualizar(self, dt, jogo):
        b = jogo.barco
        self.t += dt
        dx, dy = b.x - self.x, b.y - self.y
        d = math.hypot(dx, dy) + 1e-6
        alvo = math.atan2(dy, dx)
        if self.estado in ("emergir", "pairar"):
            self.ang += limitar(dif_ang(self.ang, alvo), -2.0 * dt, 2.0 * dt)

        if self.estado == "emergir":
            k = limitar(self.t / self.T_EMERGIR, 0.0, 1.0)
            self.altura = k * k * (3 - 2 * k)
            if self.t >= self.T_EMERGIR:
                self.altura = 1.0
                self._ir("pairar")
        elif self.estado == "pairar":
            self.altura = 1.0
            if d > self.alcance_max * 1.3:
                self._ir("recolher")        # o barco escapou
            elif self.t >= self.T_PAIRAR:
                self._ir("golpear")
        elif self.estado == "golpear":
            k = limitar(self.t / self.T_GOLPEAR, 0.0, 1.0)
            if d <= self.alcance_max:
                fim = (b.x, b.y)
            else:
                fim = (self.x + math.cos(alvo) * self.alcance_max,
                       self.y + math.sin(alvo) * self.alcance_max)
            e = k * k * (3 - 2 * k)
            self.ponta = (lerp(self.p0[0], fim[0], e), lerp(self.p0[1], fim[1], e))
            if self.t >= self.T_GOLPEAR:
                if d <= self.alcance_max * 1.05:
                    self._ir("agarrar")
                    jogo.golpe_tentaculo(self)
                else:
                    self._ir("recolher")    # errou: o barco já tinha passado
        elif self.estado == "agarrar":
            self.ponta = (b.x, b.y)
            if self.t >= self.T_AGARRAR:
                self._ir("recolher")
        else:  # recolher
            k = limitar(self.t / self.T_RECOLHER, 0.0, 1.0)
            self.altura = self.alt0 * (1 - k)
            self.ponta = (lerp(self.p0[0], self.x, k), lerp(self.p0[1], self.y, k))
            if k >= 1.0:
                self.morto = True

        if self.estado in ("emergir", "pairar"):
            comp = min(0.85 * self.alcance * self.altura, max(0.0, d - 30.0))
            self.ponta = (self.x + math.cos(self.ang) * comp, self.y + math.sin(self.ang) * comp)


class Olhos:
    """Par de olhos brilhando no escuro, longe do barco. De dia, só os que a mente inventa."""

    def __init__(self, x, y, falso=False):
        self.x = x
        self.y = y
        self.falso = falso
        self.dur = random.uniform(4, 9)
        self.t = 0.0
        self.sep = random.uniform(10, 20)
        self.ci = random.choice((0, 1, 2))
        self.ang = random.uniform(0, math.tau)
        self.fase = random.uniform(0, math.tau)

    @property
    def abertura(self):
        f = self.t / self.dur
        env = limitar(min(f / 0.2, (1 - f) / 0.2), 0.0, 1.0)
        piscar = max(0.0, (math.sin(self.t * 2.3 + self.fase) - 0.9) / 0.1)
        return env * (1 - piscar)


# ----------------------------------------------------------------------------
# Controles de toque
# ----------------------------------------------------------------------------
class Entrada:
    """Junta o teclado de verdade com as teclas "seguradas" pelos botões virtuais."""

    def __init__(self, fisicas, virtuais):
        self.fisicas = fisicas
        self.virtuais = virtuais

    def __getitem__(self, k):
        return bool(self.fisicas[k]) or k in self.virtuais


class Toque:
    """Botões virtuais na tela: dedos (ou o mouse, no modo --toque) viram teclas.

    Os botões de segurar (virar, remar, frear, pescar) entram em segurando();
    os demais disparam um KEYDOWN sintético no instante do toque.
    """
    FOLGA = 10          # área de toque além do desenho do botão
    PROTECAO_FIM = 1.0  # segundos sem reagir a toques depois que o jogo acaba

    def __init__(self, jogo):
        self.jogo = jogo
        self.ptr = {}               # ponteiro -> [x, y, botão capturado]
        self.viu_dedo = False
        self.estado_ant = None
        self.t_estado = 0.0
        self.botoes = []
        self.botoes_pausa = []
        self.montar()

    # -------------------------------------------------------------- layout
    def montar(self):
        L, A = LARGURA, ALTURA
        f = fonte(15, True)
        defs = (  # id, tecla, segura, cx, cy, r, rótulo
            ("esq", pygame.K_a, True, 62, A - 70, 46, "esq"),
            ("dir", pygame.K_d, True, 170, A - 70, 46, "dir"),
            ("frear", pygame.K_s, True, 116, A - 168, 36, "FREAR"),
            ("remar", pygame.K_w, True, L - 96, A - 96, 60, "REMAR"),
            ("golpe", pygame.K_SPACE, False, L - 230, A - 70, 44, "GOLPE"),
            ("pescar", pygame.K_f, True, L - 86, A - 230, 44, "PESCAR"),
            ("vela", pygame.K_v, False, L - 218, A - 186, 40, "VELA"),
            ("pausa", pygame.K_p, False, L - 270, 51, 26, "pausa"),
            ("ficha", pygame.K_k, False, L - 330, 51, 26, "FICHA"),
        )
        self.botoes = []
        for id_, tecla, segura, cx, cy, r, rot in defs:
            imgs = [self._desenhar_botao(f if r > 30 else fonte(12, True), r, rot, p) for p in (False, True)]
            self.botoes.append({"id": id_, "tecla": tecla, "segura": segura, "cx": cx, "cy": cy,
                                "r": r, "rect": None, "imgs": imgs,
                                "pos": (cx - r - 2, cy - r - 2)})
        # o inventário é desenhado pelo HUD; aqui só os retângulos de toque
        for r, tecla in zip(self.jogo._rects_slots(True),
                            (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_l)):
            self.botoes.append({"id": "slot%d" % tecla, "tecla": tecla, "segura": False, "cx": 0, "cy": 0,
                                "r": 0, "rect": r, "imgs": None, "pos": None})
        self.botoes_pausa = self.jogo._botoes_pausa()

    @staticmethod
    def _desenhar_botao(f, r, rot, pressionado):
        s = pygame.Surface((2 * r + 4, 2 * r + 4), pygame.SRCALPHA, 32)
        c = (r + 2, r + 2)
        pygame.draw.circle(s, (255, 255, 255, 105 if pressionado else 38), c, r)
        pygame.draw.circle(s, (255, 255, 255, 200 if pressionado else 125), c, r, 2)
        branco = (255, 255, 255, 235)
        if rot in ("esq", "dir"):
            d = -1 if rot == "esq" else 1
            pygame.draw.polygon(s, branco, [(c[0] + d * 15, c[1]), (c[0] - d * 11, c[1] - 17),
                                            (c[0] - d * 11, c[1] + 17)])
        elif rot == "pausa":
            pygame.draw.rect(s, branco, (c[0] - 9, c[1] - 10, 6, 20), border_radius=2)
            pygame.draw.rect(s, branco, (c[0] + 3, c[1] - 10, 6, 20), border_radius=2)
        else:
            img = f.render(rot, True, branco[:3])
            sombra = f.render(rot, True, (0, 0, 0))
            s.blit(sombra, sombra.get_rect(center=(c[0] + 1, c[1] + 1)))
            s.blit(img, img.get_rect(center=c))
        return s

    # -------------------------------------------------------------- eventos
    def _achar(self, x, y):
        melhor, dmin = None, 1e9
        for b in self.botoes:
            if b["rect"] is not None:
                if b["rect"].inflate(8, 8).collidepoint(x, y):
                    return b
                continue
            d = math.hypot(x - b["cx"], y - b["cy"])
            if d <= b["r"] + self.FOLGA and d < dmin:
                melhor, dmin = b, d
        return melhor

    def _tecla(self, k):
        self.jogo.evento(pygame.event.Event(pygame.KEYDOWN, key=k, sintetico=True))

    def _baixo(self, pid, x, y):
        j = self.jogo
        if j.estado == "jogando":
            if pygame.Rect(LARGURA - 232, 12, 220, 78).collidepoint(x, y):
                j.alternar_diagnostico()        # tocar no painel de dia/hora mostra os fps
                return
            if j.rect_montar is not None and j.rect_montar.collidepoint(x, y):
                self._tecla(pygame.K_e)         # tocar no aviso da planta monta a melhoria
                return
            if j.rect_xp is not None and j.rect_xp.collidepoint(x, y):
                self._tecla(pygame.K_k)         # tocar na barra de experiência abre a ficha
                return
            b = self._achar(x, y)
            self.ptr[pid] = [x, y, b]
            if b is not None and not b["segura"]:
                self._tecla(b["tecla"])
        elif j.estado == "ficha":
            linhas, fechar, _ = j._rects_ficha()
            for i, r in enumerate(linhas):
                if r.collidepoint(x, y):
                    self._tecla(pygame.K_1 + i)
                    return
            if fechar.inflate(20, 20).collidepoint(x, y):
                self._tecla(pygame.K_k)
        elif j.estado == "menu":
            self._tecla(pygame.K_RETURN)
        elif j.estado == "fim":
            if j.anim - self.t_estado > self.PROTECAO_FIM:
                self._tecla(pygame.K_RETURN)
        elif j.estado == "pausa":
            for tecla, rect in j._botoes_pausa():
                if rect.collidepoint(x, y):
                    self._tecla(tecla)
                    return
            # clicar direto na barra de volume põe o nível naquele ponto
            for (painel, menos, mais), que in zip(j._rects_volume(356), ("efeitos", "musica")):
                x0, x1 = menos.right + 4, mais.x - 4
                if painel.collidepoint(x, y) and x0 <= x <= x1:
                    alvo = int(limitar(round((x - x0) / float(x1 - x0) * j.som.NIVEIS), 0, j.som.NIVEIS))
                    atual = j.som.nivel_efeitos if que == "efeitos" else j.som.nivel_musica
                    j.som.ajustar(que, alvo - atual)
                    if que == "efeitos":
                        j.som.tocar("clique")

    def _clique_pc(self, x, y):
        """Clique do mouse no PC (botão esquerdo): menus, ficha, painéis do HUD e inventário."""
        j = self.jogo
        if j.estado != "jogando":
            self._baixo("mouse", x, y)
            return
        for r, tecla in ((j.rect_montar, pygame.K_e), (j.rect_lant, pygame.K_l), (j.rect_xp, pygame.K_k)):
            if r is not None and r.collidepoint(x, y):
                self._tecla(tecla)
                return
        for r, tecla in zip(j._rects_slots(), (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_l)):
            if r.collidepoint(x, y):
                self._tecla(tecla)
                return

    def _mover(self, pid, x, y):
        p = self.ptr.get(pid)
        if p is None:
            return
        p[0], p[1] = x, y
        b = self._achar(x, y)
        # deslizar o dedo de uma seta para outra troca de botão sem soltar
        if p[2] is not None and p[2]["segura"] and b is not None and b["segura"]:
            p[2] = b

    def evento(self, ev):
        t = ev.type
        if t in (pygame.FINGERDOWN, pygame.FINGERMOTION, pygame.FINGERUP):
            self.viu_dedo = True
            x, y, pid = ev.x * LARGURA, ev.y * ALTURA, ("f", ev.finger_id)
        elif t in (pygame.MOUSEBUTTONDOWN, pygame.MOUSEBUTTONUP, pygame.MOUSEMOTION):
            # em aparelhos de toque o SDL também gera eventos de mouse: ignora para não duplicar
            if self.viu_dedo or getattr(ev, "touch", False):
                return
            if not self.jogo.modo_toque:                # PC: o mouse clica nos menus, na ficha e no HUD
                if t == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                    self._clique_pc(ev.pos[0], ev.pos[1])
                return
            if t != pygame.MOUSEMOTION and ev.button != 1:
                return
            if t == pygame.MOUSEMOTION and not ev.buttons[0]:
                return
            x, y, pid = ev.pos[0], ev.pos[1], "mouse"
        else:
            return
        if t in (pygame.FINGERDOWN, pygame.MOUSEBUTTONDOWN):
            self._baixo(pid, x, y)
        elif t in (pygame.FINGERMOTION, pygame.MOUSEMOTION):
            self._mover(pid, x, y)
        else:
            self.ptr.pop(pid, None)

    # --------------------------------------------------------------- estado
    def atualizar(self):
        j = self.jogo
        if j.estado != self.estado_ant:
            self.estado_ant = j.estado
            self.t_estado = j.anim
        if j.estado != "jogando":
            self.ptr.clear()

    def segurando(self):
        if not self.jogo.modo_toque or self.jogo.estado != "jogando":
            return set()
        return {p[2]["tecla"] for p in self.ptr.values() if p[2] is not None and p[2]["segura"]}

    def desenhar(self):
        t = self.jogo.tela
        apertados = {id(p[2]) for p in self.ptr.values() if p[2] is not None}
        for b in self.botoes:
            if b["imgs"] is not None:
                t.blit(b["imgs"][id(b) in apertados], b["pos"])


# ----------------------------------------------------------------------------
# Som
# ----------------------------------------------------------------------------
class Som:
    """Efeitos e ambientes (mar, vento, chuva, esteira, zumbido do horror) a partir de sons/*.ogg,
    mais a trilha de vila de pescador (musica/*.ogg), que só toca de vez em quando e só em calma.

    Sem a pasta sons/, sem placa de som ou com o mixer indisponível, tudo vira silêncio: nunca dá erro.
    Os ambientes tocam em loop em canais reservados; o jogo só muda o volume-alvo de cada um.
    A música usa o fluxo próprio do mixer (pygame.mixer.music), então não ocupa canais nem memória à toa.
    """
    LOOPS = ("mar", "vento", "chuva", "esteira", "horror")
    # chuva: 0,16 (era 0,45) — fica como um chuvisco ao fundo, bem abaixo do mar, mesmo na tempestade
    LOOP_GANHO = {"mar": 0.50, "vento": 0.45, "chuva": 0.16, "esteira": 0.40, "horror": 0.65}
    GANHO = {"remo": 0.50, "golpe": 0.7, "acerto": 0.85, "mordida": 0.95, "tubarao": 0.6,
             "tentaculo_emerge": 0.75, "tentaculo_golpe": 0.95, "tentaculo_recua": 0.6, "vulto": 0.7,
             "sussurro": 0.55, "olhos": 0.35, "trovao": 0.85, "pesca_lancar": 0.6, "peixe": 0.7,
             "beber": 0.7, "comer": 0.7, "consertar": 0.75, "lanterna": 0.5, "vela": 0.55, "item": 0.55,
             "garrafa": 0.55, "gaivota": 0.45, "onda": 0.85, "aviso": 0.4, "nao": 0.45, "exausto": 0.55,
             "noite": 0.6, "amanhecer": 0.5, "vitoria": 0.8, "derrota": 0.8, "loucura": 0.9,
             "clique": 0.4, "sino": 0.6, "coracao": 0.8, "corda": 0.6, "tesouro": 0.55, "melhoria": 0.8}
    INTERVALO = {"trovao": 3.0, "gaivota": 4.0, "sussurro": 6.0, "olhos": 1.5, "coracao": 0.2,
                 "remo": 0.3, "tubarao": 4.0, "vulto": 3.0, "tentaculo_emerge": 2.0, "tesouro": 3.0}
    MESTRE = 0.80
    # efeitos fortes abaixam os ambientes por ~1 s (o quanto, de 0 a 1): dá clareza ao golpe e evita estourar
    DUCK = {"trovao": 0.35, "mordida": 0.40, "tentaculo_golpe": 0.40, "onda": 0.30, "tubarao": 0.20,
            "tentaculo_emerge": 0.20}
    # --- trilha: três músicas calmas; toca só de vez em quando, quando o mar está tranquilo
    MUSICA_GANHO = 1.0              # volume da música (0 a 1), antes do MESTRE (era 0,45: ficava abaixo do mar)
    MUSICA_ABAIXA = 0.38            # quanto mar/vento/esteira baixam enquanto a música toca (0 a 1)
    NIVEIS = 10                     # os controles de volume da pausa vão de 0 a 10
    MUSICA_PRIMEIRA = (6.0, 10.0)   # segundos de calma até a 1ª música da partida
    MUSICA_ENTRE = (40.0, 90.0)     # silêncio (em segundos de calma) entre uma música e a próxima
    MUSICA_RETOMA = (20.0, 40.0)    # espera depois que a noite/tempestade/loucura cortou a música
    MUSICA_LUZ_MIN = 30.0           # só começa uma música se ainda restar tanta luz do dia (ela dura ~35-40 s)

    def __init__(self):
        self.ok = False
        self.mudo = False
        self.efeitos = {}               # nome -> [variantes]  (remo1, remo2... viram "remo")
        self.loops = {}
        self.canais = {}
        self.alvo = dict.fromkeys(self.LOOPS, 0.0)
        self.atual = dict.fromkeys(self.LOOPS, 0.0)
        self.agenda = []                # [atraso, nome, volume, pan]
        self.ultimo = {}
        self.relogio = 0.0
        self.rnd = random.Random(5)     # gerador próprio: o som não mexe na sorte do jogo
        self.faixas = []                # caminhos de musica/*.ogg
        self.calmo = 0.0                # 0..1: o quanto o momento combina com música (o jogo informa)
        self.mus_estado = "espera"      # espera | tocando
        self.mus_timer = self.rnd.uniform(*self.MUSICA_PRIMEIRA)
        self.mus_vol = 0.0
        self.mus_t = 0.0
        self.mus_baixo = 0.0            # há quantos segundos a calma está ~zero
        self.mus_ultima = -1
        self.mus_pausada = False
        self.nivel_efeitos = self.NIVEIS    # volume escolhido na pausa (0 a NIVEIS): efeitos e ambientes
        self.nivel_musica = self.NIVEIS     # idem, só a trilha
        self.duck_nivel = 0.0           # abaixamento pedido pelo último efeito forte (decai sozinho)
        self.duck_atual = 0.0           # o que está sendo aplicado (suavizado)
        self.luz_resta = 999.0          # segundos de dia que restam (o jogo informa enquanto espera)
        pasta = os.path.join(PASTA, "sons")
        if not os.path.isdir(pasta):
            return
        try:
            if not pygame.mixer.get_init():
                pygame.mixer.init(44100, -16, 2, 512)
            pygame.mixer.set_num_channels(24)
            pygame.mixer.set_reserved(len(self.LOOPS))
            for arq in sorted(os.listdir(pasta)):
                nome, ext = os.path.splitext(arq)
                if ext.lower() not in (".ogg", ".wav"):
                    continue
                snd = pygame.mixer.Sound(os.path.join(pasta, arq))
                if nome in self.LOOPS:
                    self.loops[nome] = snd
                else:
                    self.efeitos.setdefault(nome.rstrip("0123456789") or nome, []).append(snd)
            for i, nome in enumerate(self.LOOPS):
                if nome in self.loops:
                    canal = pygame.mixer.Channel(i)
                    canal.set_volume(0.0)
                    canal.play(self.loops[nome], loops=-1)
                    self.canais[nome] = canal
            self.ok = bool(self.efeitos or self.loops)
            pm = os.path.join(PASTA, "musica")
            if self.ok and os.path.isdir(pm):
                self.faixas = [os.path.join(pm, a) for a in sorted(os.listdir(pm))
                               if a.lower().endswith((".ogg", ".wav"))]
        except Exception as erro:       # sem placa de som, driver ausente, arquivo ruim...
            print("Som desativado:", erro)
            self.ok = False

    def tocar(self, nome, vol=1.0, pan=0.0):
        """Toca um efeito. pan: -1 = só na esquerda, +1 = só na direita."""
        if not self.ok or self.mudo:
            return
        variantes = self.efeitos.get(nome)
        if not variantes:
            return
        if self.relogio - self.ultimo.get(nome, -99.0) < self.INTERVALO.get(nome, 0.05):
            return
        self.ultimo[nome] = self.relogio
        canal = self.rnd.choice(variantes).play()
        if canal is None:               # todos os canais ocupados
            return
        if nome in self.DUCK:
            self.duck_nivel = max(self.duck_nivel, self.DUCK[nome] * limitar(vol, 0.0, 1.0))
        g = limitar(vol, 0.0, 1.0) * self.GANHO.get(nome, 0.7) * self.MESTRE * self.f_efeitos
        canal.set_volume(g * (1 - max(0.0, pan)), g * (1 + min(0.0, pan)))

    @property
    def f_efeitos(self):
        return self.nivel_efeitos / self.NIVEIS

    @property
    def f_musica(self):
        return self.nivel_musica / self.NIVEIS

    def ajustar(self, que, delta):
        """Muda o volume de 'efeitos' ou 'musica' em passos de 1/NIVEIS. Devolve o nível novo (0 a NIVEIS)."""
        atr = "nivel_efeitos" if que == "efeitos" else "nivel_musica"
        novo = int(limitar(getattr(self, atr) + delta, 0, self.NIVEIS))
        setattr(self, atr, novo)
        return novo

    def agendar(self, nome, atraso, vol=1.0, pan=0.0):
        if self.ok:
            self.agenda.append([atraso, nome, vol, pan])

    def ambiente(self, **alvos):
        """Define o volume-alvo (0 a 1) de cada loop; os que não forem citados vão a zero."""
        for nome in self.LOOPS:
            self.alvo[nome] = limitar(alvos.get(nome, 0.0), 0.0, 1.0)

    def passo(self, dt, congelar=False):
        if not self.ok:
            return
        if not congelar:
            self.relogio += dt
            for item in self.agenda[:]:
                item[0] -= dt
                if item[0] <= 0:
                    self.agenda.remove(item)
                    self.tocar(item[1], item[2], item[3])
        k = min(1.0, (6.0 if congelar else 2.5) * dt)
        mestre = 0.0 if self.mudo else self.MESTRE
        if not congelar:
            self.duck_nivel = max(0.0, self.duck_nivel - dt * 0.5)
        self.duck_atual += (self.duck_nivel - self.duck_atual) * min(1.0, 25.0 * dt)
        # enquanto a música toca, mar, vento e esteira abrem espaço para ela (sobe e desce junto com o volume dela)
        cama = 1.0 - self.MUSICA_ABAIXA * limitar(self.mus_vol, 0.0, 1.0)
        for nome, canal in self.canais.items():
            self.atual[nome] += (self.alvo[nome] - self.atual[nome]) * k
            v = self.atual[nome] * self.LOOP_GANHO[nome] * mestre * (1.0 - self.duck_atual) * self.f_efeitos
            canal.set_volume(v * cama if nome != "horror" else v)
        self._musica(dt, congelar)

    # ------------------------------------------------------------ trilha
    def _musica(self, dt, congelar):
        """Máquina da trilha. Só começa depois de um tempo de calma (dia, sem tempestade, sanidade boa, sem
        criaturas por perto), toca uma música inteira, some em silêncio por um bom tempo e recomeça. Se a calma
        acaba (noite, tempestade, loucura, criatura), o volume cai junto e a música é cortada."""
        if not self.faixas:
            return
        try:
            mus = pygame.mixer.music
            if congelar:                                    # pausa do jogo: a música pausa junto
                if self.mus_estado == "tocando" and not self.mus_pausada:
                    mus.pause()
                    self.mus_pausada = True
                return
            if self.mus_pausada:
                mus.unpause()
                self.mus_pausada = False
            c = self.calmo
            if self.mus_estado == "espera":
                if c > 0.8:                                 # o tempo de espera só corre em calma
                    self.mus_timer -= dt
                    if self.mus_timer <= 0 and self.luz_resta >= self.MUSICA_LUZ_MIN:
                        self._comecar_musica()      # (sem luz suficiente, espera o próximo amanhecer)
            else:
                self.mus_t += dt
                self.mus_baixo = self.mus_baixo + dt if c < 0.05 else 0.0
                # um susto curto (tubarão passando) só abaixa o volume; a música só é cortada se a calma
                # some por uns segundos (noite, tempestade, loucura)
                if not mus.get_busy() or self.mus_baixo > 6.0 or self.mus_t > 240.0:
                    cortada = self.mus_baixo > 6.0
                    mus.stop()
                    self.mus_estado = "espera"
                    self.mus_vol = 0.0
                    self.mus_timer = self.rnd.uniform(*(self.MUSICA_RETOMA if cortada else self.MUSICA_ENTRE))
            alvo = c if (self.mus_estado == "tocando" and not self.mudo) else 0.0
            k = min(1.0, (1.0 if alvo > self.mus_vol else 3.0) * dt)    # sobe devagar, desce mais rápido
            self.mus_vol += (alvo - self.mus_vol) * k
            mus.set_volume(self.mus_vol * self.MUSICA_GANHO * self.MESTRE * self.f_musica * (1.0 - self.duck_atual))
        except Exception as erro:                           # faixa ruim, mixer sem música... vira silêncio
            print("Música desativada:", erro)
            self.faixas = []

    def _comecar_musica(self):
        opcoes = [i for i in range(len(self.faixas)) if i != self.mus_ultima] or [0]
        i = self.rnd.choice(opcoes)
        mus = pygame.mixer.music
        mus.load(self.faixas[i])
        mus.set_volume(0.0)                                 # entra do silêncio (sobe pelo passo)
        mus.play()
        self.mus_ultima = i
        self.mus_estado = "tocando"
        self.mus_vol = 0.0
        self.mus_t = 0.0
        self.mus_baixo = 0.0

    def alternar_mudo(self):
        self.mudo = not self.mudo
        return self.mudo


# ----------------------------------------------------------------------------
# O jogo
# ----------------------------------------------------------------------------
class Jogo:
    def __init__(self, tela, modo_toque=False, travar_toque=False):
        self.tela = tela
        self.modo_toque = modo_toque        # mostra botões virtuais e textos para toque
        self.travar_toque = travar_toque    # --toque: nunca volta para o modo teclado
        # desempenho: se o aparelho não acompanha, reduz os efeitos mais caros (modo leve)
        self.ema_dt = 1 / 60.0
        self.t_lento = 0.0
        self.leve_auto = False
        self.diag = 0                       # 0 = nada, 1 = mostra fps, 2 = fps + modo leve forçado
        self.f_pq = fonte(14)
        self.f_md = fonte(17)
        self.f_gd = fonte(28, True)
        self.f_tit = fonte(72, True)
        self.ov = pygame.Surface((LARGURA, ALTURA), pygame.SRCALPHA)
        self.anim = 0.0
        self.estado = "menu"        # menu, jogando, pausa, fim
        self.cx = self.cy = 0.0
        self.cor_agua = AGUA_DIA
        self.bx = self.by = 0.0
        self.pos_lanterna = (LARGURA / 2, ALTURA / 2)
        self.ang_barco = -math.pi / 2
        self._deco_chave = None
        self._tiles = None
        self.arte = Arte()
        self._criar_efeitos()
        self.toque = Toque(self)
        self.som = Som()
        self.novo()

    # ---------------------------------------------------------------- setup
    def novo(self):
        self.t = tempo_da_fase(0.27)          # começa de manhã
        self.t0 = self.t
        self.barco = Barco()
        self.vida = self.fome = self.sede = self.energia = self.casco = 100.0
        self.exausto = False
        self.lanterna = True
        self.inv = {"agua": 2, "peixe": 1, "madeira": 2, "corda": 2}
        self.melhorias = []                   # melhorias do barco já montadas (na ordem em que vieram)
        self.plantas = []                     # plantas achadas nos baús, esperando material para montar
        self.xp, self.nivel, self.pontos = 0, 1, 0
        self.hab = {h: 0 for h in HABILIDADES}
        self.rect_montar = None               # retângulos de toque do HUD (preenchidos ao desenhar)
        self.rect_xp = None
        self.rect_lant = None
        self.ficha_aviso = None               # (texto, cor, instante) da última ação na ficha
        self.lant_quebrada = False            # a lanterna pode quebrar (onda, tentáculo, mordida); conserto: 4 tábuas + 4 cordas
        self.lant_folga = 40.0                # segundos de folga em que ela não quebra (começa protegida)
        self.bandos, self.baleias = [], []    # vida marinha
        self.spawn_golf = random.uniform(35, 60)
        self.spawn_bal = random.uniform(160, 300)
        self.consolo = 0.0
        self.bau_cd = random.uniform(*BAU_PRIMEIRO)
        self.bau_ping = 0.0
        self.banner = None                    # aviso grande da última melhoria: [nome, ttl]

        rumo = random.uniform(0, math.tau)
        self.ilha = (math.cos(rumo) * DIST_ILHA, math.sin(rumo) * DIST_ILHA)
        self.palmeiras = []         # (ângulo, distância, fase, altura): sorteadas junto com a ilha em _deco_ilha()

        self.itens, self.cardumes, self.tubaroes = [], [], []
        self.gaivotas = []
        self.vila = IlhaVila()
        self.efeitos = Animacoes()
        self.oceano = Oceano(self.tela.get_size())
        self.remo_fase = 0.0        # ponto da remada (radianos) e quanto os remos estão em ação (0 a 1)
        self.remo_amp = 0.0
        self.msgs = []
        self.rastro = []
        self.rastro_cd = 0.0

        self.vento_ang = random.uniform(0, math.tau)
        self.vento_giro = 0.0
        self.vento_tm = 5.0
        self.corr_ang = random.uniform(0, math.tau)
        self.corr_giro = 0.0

        self.tempestade = 0.0
        self.temp_ativa = False
        self.temp_prox = random.uniform(55, 90)
        self.temp_resta = 0.0
        self.onda_cd = 3.0
        self.flash = 0.0
        self.tremor = 0.0

        self.pesca_prog = 0.0
        self.cardume_perto = None
        self.remo_cd = 0.0
        self.remo_anim = 0.0
        self.mapa = 0.0
        self.percorrido = 0.0
        self.stats = {"peixes": 0, "tubaroes": 0, "tentaculos": 0}
        self.vitoria = False
        self.fim_texto = ""
        self.fim_loucura = False

        self.spawn_cd = 0.0
        self.spawn_tub = 30.0
        self.aviso = {"sede": False, "fome": False, "casco": False,
                      "gaivotas": False, "terra": False, "tubarao": False,
                      "noite": False, "vulto": False, "tentaculo": False,
                      "loucura1": False, "loucura2": False, "golf_tub": False}

        # horror cósmico
        self.sanidade = 100.0
        self.vultos, self.tentaculos, self.olhos = [], [], []
        self.bolhas = []            # manchas escuras e bolhas que sobem do fundo (aviso de que algo se move)
        self.spawn_bolha = 6.0
        self.spawn_tent = 6.0       # só contam durante a noite
        self.spawn_vulto = 8.0
        self.spawn_olho = 5.0
        self.sussurro_cd = random.uniform(10, 18)
        self.fase_bat = 0.0
        self.noites = 0
        self.nota_i = random.randrange(len(NOTAS))

        # controle do som (não usa o sorteio do jogo)
        self.som.agenda = []
        self.remo_som = 0.0         # tempo até a próxima remada audível
        self.gaivota_cd = 5.0
        self.bat_ult = 0            # número da última batida de coração tocada
        self.pescando = False

        self.msg("Você está à deriva. Siga o ponteiro dourado da bússola até a ilha!", AMARELO)
        self._popular_inicio()
        self._deco_chave = None
        self._deco_ilha()                       # desenha a ilha agora, para não travar quando ela aparecer

    def _pos_anel(self, rmin, rmax):
        a = random.uniform(0, math.tau)
        r = random.uniform(rmin, rmax)
        return self.barco.x + math.cos(a) * r, self.barco.y + math.sin(a) * r

    def _popular_inicio(self):
        for tipo, rmin, rmax in (("barril", 220, 420), ("tabua", 300, 520), ("corda", 260, 480),
                                 ("tabua", 420, 700), ("corda", 440, 760), ("barril", 620, 900),
                                 ("tabua", 560, 860)):
            x, y = self._pos_anel(rmin, rmax)
            self.itens.append(Item(tipo, x, y))
        x, y = self._pos_anel(300, 480)
        self.cardumes.append(Cardume(x, y))

    def msg(self, texto, cor=BRANCO):
        if self.msgs and self.msgs[-1][0] == texto:
            self.msgs[-1][1] = 6.0
            return
        self.msgs.append([texto, 6.0, cor])
        self.msgs = self.msgs[-6:]

    # ------------------------------------------------------------- utilidades
    def brilho(self):
        return self.brilho_em(self.t)

    @staticmethod
    def brilho_em(t):
        frac = fase_do_dia(t)
        return limitar(0.5 + 0.8 * math.sin(math.tau * (frac - 0.25)), 0.12, 1.0)

    def luz_restante(self):
        """Segundos até o entardecer começar a engolir a trilha (noite_f > 0,6). Máx. 60."""
        for k in range(0, 61, 2):
            if (1.0 - self.brilho_em(self.t + k)) / 0.88 > 0.6:
                return float(k)
        return 60.0

    def noite_f(self):
        """0 = dia claro, 1 = noite fechada."""
        return limitar((1 - self.brilho()) / 0.88, 0.0, 1.0)

    def dist_ilha(self):
        return math.hypot(self.ilha[0] - self.barco.x, self.ilha[1] - self.barco.y)

    def chegou_ilha(self):
        if self.dist_ilha()>650:return False
        self._deco_ilha()
        return self.vila.chegou(self.barco.x-self.ilha[0], self.barco.y-self.ilha[1])

    def destino_ilha(self):
        return self.ilha[0]+self.vila.CAIS[0], self.ilha[1]+self.vila.CAIS[1]

    def dia(self):
        return int((self.t - self.t0) // DURACAO_DIA) + 1

    def hora_txt(self):
        h = fase_do_dia(self.t) * 24
        return "%02d:%02d" % (int(h), int((h - int(h)) * 60))

    # ----------------------------------------------------------------- eventos
    def sair(self):
        if PLATAFORMA != "web":      # no navegador não há para onde "sair"
            pygame.quit()
            sys.exit()

    def teclas(self, fisicas):
        """Teclado + botões virtuais, no formato que atualizar() espera."""
        return Entrada(fisicas, self.toque.segurando())

    @property
    def leve(self):
        return self.leve_auto or self.diag == 2

    def alternar_diagnostico(self):
        """F3 no PC, ou toque no painel de dia/hora no celular: fps -> fps + modo leve -> nada."""
        self.diag = (self.diag + 1) % 3

    def rot(self, acao):
        """Como se faz cada ação: tecla no PC, botão no celular (para as mensagens do jogo)."""
        if self.modo_toque:
            return {"golpe": "botão GOLPE", "vela": "botão VELA", "beber": "toque na gota para beber",
                    "comer": "toque no peixe para comer",
                    "consertar": "toque na tábua ou na corda para consertar"}[acao]
        return {"golpe": "ESPAÇO", "vela": "V", "beber": "tecla 1 para beber",
                "comer": "tecla 2 para comer", "consertar": "tecla 3 (tábua) ou 4 (corda) para consertar"}[acao]

    def _rects_slots(self, toque=None):
        """Retângulos do inventário (água, comida, tábuas, corda, lanterna). No celular são botões."""
        if self.modo_toque if toque is None else toque:
            esq, dir_, folga = 226, 284, 6      # faixas ocupadas pelos botões laterais; espaço entre slots
            disp = LARGURA - esq - dir_
            w = max(72, min(150, (disp - 4 * folga) // 5))
            x0 = esq + (disp - (5 * w + 4 * folga)) // 2
            return [pygame.Rect(x0 + i * (w + folga), ALTURA - 82, w, 66) for i in range(5)]
        w, folga = 122, 5
        x0 = (LARGURA - (5 * w + 4 * folga)) // 2
        return [pygame.Rect(x0 + i * (w + folga), ALTURA - 62, w, 48) for i in range(5)]

    def evento(self, ev):
        if ev.type == pygame.QUIT:
            self.sair()
            return
        if ev.type in (pygame.FINGERDOWN, pygame.FINGERMOTION, pygame.FINGERUP,
                       pygame.MOUSEBUTTONDOWN, pygame.MOUSEBUTTONUP, pygame.MOUSEMOTION):
            if ev.type in (pygame.FINGERDOWN, pygame.FINGERMOTION):
                self.modo_toque = True      # tocou na tela: aparelho de toque
            self.toque.evento(ev)
            return
        if ev.type in (getattr(pygame, "APP_WILLENTERBACKGROUND", -1),
                       getattr(pygame, "APP_DIDENTERBACKGROUND", -1)):
            if self.estado == "jogando":    # foi para segundo plano: pausa sozinho
                self.estado = "pausa"
            return
        if ev.type != pygame.KEYDOWN:
            return
        k = ev.key
        if k == getattr(pygame, "K_AC_BACK", -1):
            k = pygame.K_ESCAPE             # botão "voltar" do Android age como ESC
        if k == pygame.K_F3:
            self.alternar_diagnostico()
            return
        if not getattr(ev, "sintetico", False) and not self.travar_toque and k != pygame.K_ESCAPE:
            self.modo_toque = False         # teclado de verdade: esconde os botões

        if k == pygame.K_m:
            self._alternar_som()
            return

        if self.estado == "menu":
            if k in (pygame.K_RETURN, pygame.K_KP_ENTER, pygame.K_SPACE):
                self.estado = "jogando"
                self.som.tocar("sino")
            elif k == pygame.K_ESCAPE:
                self.sair()
        elif self.estado == "pausa":
            if k in (pygame.K_p, pygame.K_ESCAPE):
                self.estado = "jogando"
                self.som.tocar("clique")
            elif k == pygame.K_r:
                self.novo()
                self.estado = "jogando"
                self.som.tocar("sino")
            elif k == pygame.K_q:
                self.sair()
            elif k in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_DOWN, pygame.K_UP):
                # ← → : volume dos efeitos      ↓ ↑ : volume da música
                que = "efeitos" if k in (pygame.K_LEFT, pygame.K_RIGHT) else "musica"
                self.som.ajustar(que, 1 if k in (pygame.K_RIGHT, pygame.K_UP) else -1)
                if que == "efeitos":
                    self.som.tocar("clique")    # dá para ouvir o novo nível (a música fica pausada)
        elif self.estado == "ficha":
            if k in (pygame.K_k, pygame.K_ESCAPE, pygame.K_p):
                self.estado = "jogando"
                self.som.tocar("clique")
            elif pygame.K_1 <= k <= pygame.K_5:
                self._gastar(HABILIDADES[k - pygame.K_1])
            elif pygame.K_KP1 <= k <= pygame.K_KP5:
                self._gastar(HABILIDADES[k - pygame.K_KP1])
        elif self.estado == "fim":
            if k in (pygame.K_RETURN, pygame.K_KP_ENTER, pygame.K_r):
                self.novo()
                self.estado = "jogando"
                self.som.tocar("sino")
            elif k == pygame.K_ESCAPE:
                self.sair()
        elif self.estado == "jogando":
            if k in (pygame.K_p, pygame.K_ESCAPE):
                self.estado = "pausa"
                self.som.tocar("clique")
            elif k == pygame.K_1:
                self._beber()
            elif k == pygame.K_2:
                self._comer()
            elif k == pygame.K_3:
                self._consertar("madeira")
            elif k == pygame.K_4:
                self._consertar("corda")
            elif k == pygame.K_k:
                self.estado = "ficha"
                self.som.tocar("clique")
            elif k == pygame.K_e:
                if self.lant_quebrada and not self.plantas:
                    self._consertar_lanterna()
                else:
                    self._montar()
            elif k == pygame.K_v:
                self.barco.vela = not self.barco.vela
                self.som.tocar("vela")
                self.msg("Vela içada." if self.barco.vela else "Vela recolhida.", AZUL_CLARO)
            elif k == pygame.K_SPACE:
                self._golpear()
            elif k == pygame.K_l and self.lant_quebrada:
                self._consertar_lanterna()
            elif k == pygame.K_l:
                self.lanterna = not self.lanterna
                self.som.tocar("lanterna")
                self.msg("Lanterna acesa." if self.lanterna else "Lanterna apagada.", AMARELO)
            elif k == pygame.K_f and self.cardume_perto is None:
                self.msg("Nenhum cardume ao alcance. Aproxime-se das sombras de peixes.", CINZA)

    def _alternar_som(self):
        if not self.som.ok:
            self.msg("Sem som: a pasta sons/ não foi encontrada ao lado do jogo.", CINZA)
            return
        mudo = self.som.alternar_mudo()
        if not mudo:
            self.som.tocar("clique")
        self.msg("Som desligado." if mudo else "Som ligado.", CINZA)

    def som_em(self, nome, x, y, vol=1.0):
        """Efeito vindo de um ponto do mundo: mais fraco com a distância e deslocado para o lado."""
        b = self.barco
        dx, dy = x - b.x, y - b.y
        d = math.hypot(dx, dy)
        self.som.tocar(nome, vol * limitar(1.15 - d / 900.0, 0.12, 1.0), limitar(dx / 450.0, -0.9, 0.9))

    # ------------------------------------------------------------------- ações
    def _beber(self):
        if self.inv["agua"] <= 0:
            self.som.tocar("nao")
            self.msg("Você não tem água potável!", VERMELHO)
        elif self.sede >= 97:
            self.som.tocar("nao")
            self.msg("Você não está com sede.", CINZA)
        else:
            self.inv["agua"] -= 1
            self.sede = min(100, self.sede + 35)
            self.som.tocar("beber")
            self.msg("Você bebeu água. (+35 sede)", AZUL_CLARO)

    def _comer(self):
        if self.inv["peixe"] <= 0:
            self.som.tocar("nao")
            self.msg("Você não tem comida!", VERMELHO)
        elif self.fome >= 97:
            self.som.tocar("nao")
            self.msg("Você não está com fome.", CINZA)
        else:
            self.inv["peixe"] -= 1
            self.fome = min(100, self.fome + 28)
            self.energia = min(100, self.energia + 8)
            self.som.tocar("comer")
            self.msg("Você comeu peixe cru. (+28 fome)", VERDE)

    def _consertar(self, material="madeira"):
        """Remenda o casco com uma tábua (+25) ou com um pedaço de corda (+12)."""
        corda = material == "corda"
        if self.inv[material] <= 0:
            self.som.tocar("nao")
            self.msg("Você não tem corda para amarrar o casco!" if corda else "Você não tem tábuas para consertar!",
                     VERMELHO)
        elif self.casco >= 98:
            self.som.tocar("nao")
            self.msg("O casco está inteiro.", CINZA)
        else:
            ganho = CASCO_CORDA if corda else CASCO_TABUA
            self.inv[material] -= 1
            self.casco = min(100, self.casco + ganho)
            self.som.tocar("consertar")
            self.msg("Você amarrou e vedou o casco com corda. (+%d casco)" % ganho if corda
                     else "Você remendou o casco com uma tábua. (+%d casco)" % ganho, VERDE)

    # ------------------------------------------------------ lanterna quebrável
    def _quebrar_lanterna(self, chance):
        """Um golpe forte (onda, tentáculo, mordida) pode quebrar a lanterna; depois de quebrar, não quebra de novo logo."""
        if self.lant_quebrada or self.lant_folga > 0 or random.random() >= chance:
            return
        self.lant_quebrada = True
        self.lanterna = False
        self.lant_folga = LANTERNA_FOLGA
        self.som.tocar("aviso")
        self.msg("A LANTERNA QUEBROU! Conserto: %s (tecla %s)." % (self._txt_mat(LANTERNA_CONSERTO), "L ou E"), VERMELHO)

    @staticmethod
    def _txt_mat(receita):
        return " + ".join("%d %s" % (q, NOME_MAT[m][0 if q == 1 else 1]) for m, q in receita.items())

    def _consertar_lanterna(self):
        if not self.lant_quebrada:
            return
        falta = [(m, q - self.inv.get(m, 0)) for m, q in LANTERNA_CONSERTO.items() if self.inv.get(m, 0) < q]
        if falta:
            self.som.tocar("nao")
            self.msg("Faltam %s para consertar a lanterna." % " e ".join(
                "%d %s" % (n, NOME_MAT[m][0 if n == 1 else 1]) for m, n in falta), VERMELHO)
            return
        for m, q in LANTERNA_CONSERTO.items():
            self.inv[m] -= q
        self.lant_quebrada = False
        self.lanterna = True
        self.lant_folga = LANTERNA_FOLGA
        self.som.tocar("consertar")
        self.som.tocar("lanterna")
        self.msg("Lanterna consertada! Material usado: %s." % self._txt_mat(LANTERNA_CONSERTO), VERDE)
        self._xp(15)

    # ------------------------------------------------------ melhorias do barco
    def tem(self, melhoria):
        return melhoria in self.melhorias

    @property
    def mult_dano(self):
        """Quanto do dano ao casco passa (o reforço de ferro corta 35%)."""
        return 0.65 if self.tem("casco") else 1.0

    def vel_remo(self):
        return VEL_REMO * (1.2 if self.tem("remos") else 1.0) * (1.0 + 0.05 * self.hab["remo"])

    def vel_vela(self):
        return VEL_VELA * (1.3 if self.tem("vela") else 1.0) * (1.0 + 0.06 * self.hab["vela"])

    def vel_max(self):
        return VEL_MAX + 12.0 * (self.tem("remos") + self.tem("vela")) + 4.0 * (self.hab["remo"] + self.hab["vela"])

    # ----------------------------------------------------------------- RPG
    def _xp_prox(self):
        return 80 + 40 * (self.nivel - 1)

    def _xp(self, n):
        """Ganha experiência; cada nível rende 1 ponto de habilidade (ficha: tecla K ou botão FICHA)."""
        self.xp += n
        subiu = False
        while self.xp >= self._xp_prox():
            self.xp -= self._xp_prox()
            self.nivel += 1
            self.pontos += 1
            subiu = True
            self.msg("NÍVEL %d! +1 ponto de habilidade (%s)" % (self.nivel, "botão FICHA" if self.modo_toque
                                                                  else "tecla K"), AMARELO)
        if subiu:
            self.som.tocar("melhoria")

    def _aviso_ficha(self, texto, cor):
        self.msg(texto, cor)
        self.ficha_aviso = (texto, cor, self.anim)

    def _gastar(self, hab):
        if self.hab[hab] >= HAB_MAX:
            self.som.tocar("nao")
            self._aviso_ficha("%s já está no máximo." % INFO_HAB[hab][0], CINZA)
        elif self.pontos <= 0:
            self.som.tocar("nao")
            self._aviso_ficha("Sem pontos. Ganhe experiência: pescar, montar o barco, vencer a noite.", CINZA)
        else:
            self.hab[hab] += 1
            self.pontos -= 1
            self.som.tocar("item")
            self._aviso_ficha("%s: nível %d!" % (INFO_HAB[hab][0], self.hab[hab]), VERDE)

    # ------------------------------------------------- plantas e montagem
    @property
    def falta_melhoria(self):
        return len(self.melhorias) + len(self.plantas) < len(MELHORIAS)

    def _pode(self, nome):
        return all(self.inv.get(m, 0) >= q for m, q in RECEITAS[nome].items())

    @staticmethod
    def _txt_receita(nome):
        return " + ".join("%d %s" % (q, NOME_MAT[m][0 if q == 1 else 1]) for m, q in RECEITAS[nome].items())

    def _foco_planta(self):
        """A planta que o botão de montar usa: a primeira que já dá para pagar, senão a primeira."""
        for nome in self.plantas:
            if self._pode(nome):
                return nome
        return self.plantas[0] if self.plantas else None

    def _planta(self, nome):
        self.plantas.append(nome)
        titulo = INFO_MELHORIA[nome][0]
        self.banner = [nome, 7.0, "planta"]
        self.som.tocar("melhoria")
        self.msg("PLANTA: %s! Material: %s." % (titulo, self._txt_receita(nome)), AMARELO)
        self.msg("Junte o material e monte (%s)." % ("toque no aviso" if self.modo_toque else "tecla E"), BRANCO)

    def _montar(self, nome=None):
        if not self.plantas:
            self.msg("Nenhuma planta para montar. Abra os baús dourados no mar.", CINZA)
            return
        nome = nome if nome in self.plantas else self._foco_planta()
        titulo = INFO_MELHORIA[nome][0]
        falta = [(m, q - self.inv.get(m, 0)) for m, q in RECEITAS[nome].items() if self.inv.get(m, 0) < q]
        if falta:
            self.som.tocar("nao")
            self.msg("Faltam %s para montar: %s." % (" e ".join("%d %s" % (n, NOME_MAT[m][0 if n == 1 else 1])
                                                                  for m, n in falta), titulo), VERMELHO)
            return
        for m, q in RECEITAS[nome].items():
            self.inv[m] -= q
        self.plantas.remove(nome)
        self._melhorar(nome)
        self.msg("Material usado: %s." % self._txt_receita(nome), CINZA)
        self._xp(40)

    # ------------------------------------------------- vida marinha
    def _respingo(self, x, y):
        for _ in range(6):
            self.rastro.append([x + random.uniform(-16, 16), y + random.uniform(-16, 16), 1.6])

    def _fauna(self, dt):
        b = self.barco
        nf = self.noite_f()
        # golfinhos: de dia, de vez em quando, um bando vem ao encontro do barco
        self.spawn_golf -= dt
        if self.spawn_golf <= 0:
            self.spawn_golf = random.uniform(10, 25)                 # se não deu, tenta de novo logo
            if not self.bandos and nf < 0.55 and self.tempestade < 0.4 and (self.t - self.t0) > 20:
                a = b.ang + random.uniform(-1.2, 1.2)
                d = random.uniform(750, 950)
                self.bandos.append(Bando(b.x + math.cos(a) * d, b.y + math.sin(a) * d, random.randint(2, 4), a + math.pi))
                self.spawn_golf = random.uniform(70, 130)
        self.consolo = 0.0
        for bd in self.bandos[:]:
            bd.atualizar(dt, b, self)
            d = math.hypot(bd.x - b.x, bd.y - b.y)
            if bd.vida > 0 and d < 380:
                self.consolo = max(self.consolo, 1.0 - d / 380.0)
            if (bd.vida <= 0 and d > 1400) or d > 2600:
                self.bandos.remove(bd)
        # baleias: raras
        self.spawn_bal -= dt
        if self.spawn_bal <= 0:
            self.spawn_bal = random.uniform(30, 60)
            if not self.baleias and nf < 0.7 and self.tempestade < 0.5 and not self.vultos and (self.t - self.t0) > 60:
                a = b.ang + random.uniform(-0.9, 0.9)
                d = random.uniform(850, 1050)
                rumo = a + random.choice((-1, 1)) * (math.pi / 2 + random.uniform(-0.4, 0.4))   # cruza o caminho
                self.baleias.append(Baleia(b.x + math.cos(a) * d, b.y + math.sin(a) * d, rumo))
                self.spawn_bal = random.uniform(300, 480)
        for bl in self.baleias[:]:
            bl.atualizar(dt, b, self)
            if math.hypot(bl.x - b.x, bl.y - b.y) > 2200:
                self.baleias.remove(bl)
            elif bl.profund < 0.5:
                self.consolo = max(self.consolo, 1.0 - math.hypot(bl.x - b.x, bl.y - b.y) / 500.0)
        self.consolo = limitar(self.consolo, 0.0, 1.0)

    def _melhorar(self, nome):
        """Aplica uma melhoria permanente e avisa o jogador."""
        self.melhorias.append(nome)
        if nome == "casco":
            self.casco = min(100.0, self.casco + 20.0)
        titulo, texto = INFO_MELHORIA[nome]
        self.banner = [nome, 7.0]
        self.som.tocar("melhoria")
        self.msg("MELHORIA: %s!" % titulo, AMARELO)
        self.msg(texto, BRANCO)
        if len(self.melhorias) == len(MELHORIAS):
            self.msg("O barco está totalmente equipado!", VERDE)

    def _bau(self):
        for it in self.itens:
            if it.tipo == "bau":
                return it
        return None

    def _nascer_bau(self, perto=False):
        """Faz um baú boiar a ~1 km do barco, mais ou menos na direção da ilha. False se não deu (ilha perto)."""
        b = self.barco
        if self.dist_ilha() < 2200:
            return False
        a = math.atan2(self.ilha[1] - b.y, self.ilha[0] - b.x) + random.uniform(-0.9, 0.9)
        r = random.uniform(620, 900) if perto else random.uniform(800, 1250)
        self.itens.append(Item("bau", b.x + math.cos(a) * r, b.y + math.sin(a) * r))
        self.bau_ping = 0.0
        return True

    def _golpear(self):
        if self.remo_cd > 0:
            return
        if self.energia < 6:
            self.som.tocar("nao")
            self.msg("Sem energia para golpear!", VERMELHO)
            return
        b = self.barco
        self.remo_cd = 0.5
        self.remo_anim = 0.25
        self.energia -= 6
        self.som.tocar("golpe")
        for s in self.tubaroes[:]:
            if math.hypot(s.x - b.x, s.y - b.y) < 125:
                self.efeitos.rajada(s.x, s.y, quantidade=20)
                s.hp -= 1
                s.piscar = 0.3
                self.som.agendar("acerto", 0.12)
                if s.hp <= 0:
                    self.tubaroes.remove(s)
                    self.inv["peixe"] += 2
                    self.stats["tubaroes"] += 1
                    self._xp(30)
                    self.msg("Tubarão abatido! Você aproveitou a carne (+2 peixes).", VERDE)
                else:
                    s.estado = "fugir"
                    s.fuga = 3.5
                    self.msg("Você acertou o tubarão com o remo!", AMARELO)
        for tn in self.tentaculos:
            if tn.estado != "recolher" and tn.altura > 0.35 and \
                    math.hypot(tn.ponta[0] - b.x, tn.ponta[1] - b.y) < 140:
                self.efeitos.rajada(*tn.ponta, cor=(183, 153, 230), quantidade=18)
                tn.ferir(self)

    def mordida_tubarao(self, s):
        self.efeitos.rajada(s.x, s.y, quantidade=22)
        self.casco -= 7 * self.mult_dano
        self.tremor = 0.5
        self._quebrar_lanterna(0.10)
        s.mordidas += 1
        if self.casco < 30:
            self.vida -= 4
        if s.mordidas % 3 == 0:
            s.estado = "fugir"
            s.fuga = 5.0
        self.som_em("mordida", s.x, s.y)
        self.msg("O tubarão mordeu o casco! Use o remo (%s)!" % self.rot("golpe"), VERMELHO)

    def _coletar(self, it):
        self.efeitos.rajada(it.x, it.y, (255, 218, 110), 18)
        self.som.tocar({"garrafa": "garrafa", "corda": "corda", "bau": "item"}.get(it.tipo, "item"))
        if it.tipo not in ("bau", "garrafa"):
            self._xp(3)
        elif it.tipo == "garrafa":
            self._xp(8)
        if it.tipo == "barril":
            r = random.random()
            if r < 0.55:
                n = random.choice((1, 1, 2))
                self.inv["agua"] += n
                self.msg("Barril: +%d água potável." % n, AZUL_CLARO)
            elif r < 0.78:
                self.inv["peixe"] += 2
                self.msg("Barril com peixe salgado: +2 comida.", VERDE)
            elif r < 0.90:
                self.inv["madeira"] += 2
                self.msg("O barril quebrou e rendeu 2 tábuas.", AMARELO)
            else:
                self.inv["corda"] += 3
                self.msg("O barril estava cheio de cordas: +3 cordas.", AMARELO)
        elif it.tipo == "tabua":
            n = random.choice((1, 2, 2))
            self.inv["madeira"] += n
            self.msg("Você pegou %d tábua(s) boiando." % n, AMARELO)
        elif it.tipo == "corda":
            n = random.choice((1, 2, 2, 3))
            self.inv["corda"] += n
            self.msg("Você pegou %d corda(s) boiando. Serve para remendar o casco." % n, AMARELO)
        elif it.tipo == "bau":
            falta = [m for m in MELHORIAS if m not in self.melhorias and m not in self.plantas]
            if falta:
                self._planta(random.choice(falta))
            self._xp(25)
            self.bau_cd = random.uniform(*BAU_ENTRE)
        else:
            self.mapa = 120.0
            self.msg("Garrafa com um mapa! Você sabe a distância da ilha por 2 minutos.", AMARELO)
            if self._bau() is None and self.falta_melhoria:
                self._nascer_bau(perto=True)        # o mapa também marca um baú
            bau = self._bau()
            if bau is not None:
                self.msg("O mapa marca um baú dourado no mar: siga a seta dourada!", AMARELO)
                self.som_em("tesouro", bau.x, bau.y)
            for linha in NOTAS[self.nota_i % len(NOTAS)]:
                self.msg(linha, VIOLETA)
            self.nota_i += 1

    # ------------------------------------------------------------- atualização
    def atualizar(self, dt, k):
        self.anim += dt
        self.toque.atualizar()
        self.tremor = max(0.0, self.tremor - dt * 1.5)
        self._som(dt)
        if self.estado != "jogando":
            return
        self.efeitos.atualizar(dt, self.barco, self.leve_auto, self.tem("remos"))
        self.lant_folga = max(0.0, self.lant_folga - dt)

        # mede o ritmo real dos quadros; se ficar abaixo de ~33 fps por 4 s, liga o modo leve
        self.ema_dt += (dt - self.ema_dt) * 0.05
        if self.ema_dt > 0.030:
            self.t_lento += dt
        else:
            self.t_lento = max(0.0, self.t_lento - dt)
        if self.t_lento > 4.0 and not self.leve_auto:
            self.leve_auto = True
            self.msg("Aparelho lento: efeitos reduzidos (modo leve).", CINZA)

        self.t += dt
        for m in self.msgs:
            m[1] -= dt
        self.msgs = [m for m in self.msgs if m[1] > 0]
        self.mapa = max(0.0, self.mapa - dt)
        if self.banner is not None:
            self.banner[1] -= dt
            if self.banner[1] <= 0:
                self.banner = None
        self.remo_cd = max(0.0, self.remo_cd - dt)
        self.remo_anim = max(0.0, self.remo_anim - dt)
        self.flash = max(0.0, self.flash - dt * 2.5)

        self._clima(dt)
        self._barco(dt, k)
        self._status(dt)
        self._pesca(dt, k)
        self._objetos(dt)
        self._fauna(dt)
        self._horror(dt)
        self._checar_fim()

    def _som(self, dt):
        """Dirige os ambientes: volume-alvo de mar, vento, chuva, esteira e zumbido do horror."""
        s = self.som
        if not s.ok:
            return
        if self.estado == "jogando":
            b = self.barco
            nf, tp = self.noite_f(), self.tempestade
            ins = 1.0 - self.sanidade / 100.0
            perto = 0.0
            for v in self.vultos:
                perto = max(perto, v.vis * limitar(1.0 - math.hypot(v.x - b.x, v.y - b.y) / 800.0, 0.0, 1.0))
            for tn in self.tentaculos:
                if tn.estado != "recolher":
                    perto = max(perto, tn.altura * limitar(1.0 - math.hypot(tn.x - b.x, tn.y - b.y) / 500.0, 0.0, 1.0))
            s.ambiente(mar=0.55 + 0.25 * tp,
                       vento=0.14 + 0.32 * tp + 0.08 * nf + (0.12 if b.vela else 0.0),
                       chuva=0.9 * tp if tp > 0.05 else 0.0,
                       esteira=0.45 * limitar(abs(b.vel) / VEL_MAX, 0.0, 1.0),
                       horror=0.10 * nf + 0.75 * ins ** 1.2 + 0.5 * perto)
            # a trilha (vila de pescador) pede calma: dia (some ao cair da noite), sem tempestade, com a
            # cabeça no lugar (some só quando a mente já está falhando) e sem tubarão, vulto ou
            # tentáculo por perto
            ameaca = perto
            for tb in self.tubaroes:
                ameaca = max(ameaca, limitar(1.0 - math.hypot(tb.x - b.x, tb.y - b.y) / 320.0, 0.0, 1.0))
            if s.mus_estado == "espera" and s.mus_timer <= 0.0:     # só calcula quando vai decidir começar
                s.luz_resta = self.luz_restante()
            s.calmo = (limitar(1.0 - (nf - 0.55) / 0.35, 0.0, 1.0)
                       * (1.0 - limitar(tp * 3.0, 0.0, 1.0))
                       * (1.0 - limitar((ins - 0.60) / 0.20, 0.0, 1.0))
                       * (1.0 - limitar(ameaca * 3.0, 0.0, 1.0)))
            s.passo(dt)
        elif self.estado == "menu":
            s.ambiente(mar=0.45, vento=0.12)
            s.calmo = 0.0
            s.passo(dt)
        elif self.estado == "fim":
            s.ambiente(mar=0.25)
            s.calmo = 0.0
            s.passo(dt)
        else:                                   # pausa: os ambientes se calam e a agenda congela
            s.ambiente()
            s.passo(dt, congelar=True)

    def _clima(self, dt):
        # vento e corrente variam devagar
        self.vento_tm -= dt
        if self.vento_tm <= 0:
            self.vento_tm = random.uniform(6, 12)
            self.vento_giro = random.uniform(-0.09, 0.09)
            self.corr_giro = random.uniform(-0.03, 0.03)
        self.vento_ang += self.vento_giro * dt
        self.corr_ang += self.corr_giro * dt

        # tempestades
        if not self.temp_ativa:
            self.temp_prox -= dt
            if self.temp_prox <= 0:
                self.temp_ativa = True
                self.temp_resta = random.uniform(22, 34)
                self.som.agendar("trovao", 0.3, 0.8, -0.4)
                self.msg("TEMPESTADE! Recolha a vela (%s). A chuva ajuda com a sede." % self.rot("vela"),
                         VERMELHO)
        else:
            self.temp_resta -= dt
            if self.temp_resta <= 0:
                self.temp_ativa = False
                self.temp_prox = random.uniform(70, 130)
                self.msg("A tempestade passou.", AZUL_CLARO)
        alvo = 1.0 if self.temp_ativa else 0.0
        self.tempestade += (alvo - self.tempestade) * min(1.0, 0.6 * dt)

        if self.tempestade > 0.4:
            self.onda_cd -= dt
            if self.onda_cd <= 0:
                self.onda_cd = random.uniform(2.5, 4.5)
                a = random.uniform(0, math.tau)
                f = random.uniform(70, 130) * self.tempestade * (0.6 if self.tem("leme") else 1.0)
                self.barco.push[0] += math.cos(a) * f
                self.barco.push[1] += math.sin(a) * f
                dano = random.uniform(3, 7) * self.tempestade
                if self.barco.vela:
                    dano *= 1.6
                self.casco -= dano * self.mult_dano
                self.tremor = 0.6
                self._quebrar_lanterna(0.22 * self.tempestade + 0.04)
                self.som.tocar("onda")
                self.msg("Uma onda gigante bateu no barco!", VERMELHO)
        if self.tempestade > 0.5 and random.random() < 0.35 * dt:
            self.flash = 1.0
            # o trovão chega depois do relâmpago, de um lado qualquer (som próprio: não mexe na sorte do jogo)
            self.som.agendar("trovao", self.som.rnd.uniform(0.25, 1.4), 0.9, self.som.rnd.uniform(-0.7, 0.7))

    def forca_vento(self):
        return 1.0 + 1.4 * self.tempestade

    def _barco(self, dt, k):
        b = self.barco
        dir_ = (1 if (k[pygame.K_d] or k[pygame.K_RIGHT]) else 0) - \
               (1 if (k[pygame.K_a] or k[pygame.K_LEFT]) else 0)
        b.ang += dir_ * (2.0 if self.tem("leme") else 1.6) * dt
        b.timao += (dir_ - b.timao) * min(1.0, 8.0 * dt)

        if self.exausto and self.energia >= 25:
            self.exausto = False
        quer = bool(k[pygame.K_w] or k[pygame.K_UP])
        remando = quer and not self.exausto and self.energia > 0
        b.remando = remando

        if remando:
            self.energia -= 5.0 * (0.75 if self.tem("remos") else 1.0) * (1.0 - 0.07 * self.hab["remo"]) * dt
            self.remo_som -= dt
            if self.remo_som <= 0:          # uma remada audível a cada ~1,1 s
                self.remo_som = 1.1
                self.som.tocar("remo", 0.24)     # bem baixo (era 0,6): a remada é só um toque na água
            if self.energia <= 0:
                self.energia = 0
                self.exausto = True
                self.som.tocar("exausto")
                self.msg("Você está exausto! Descanse para voltar a remar.", VERMELHO)
        else:
            self.remo_som = 0.0
            reg = 6.0
            if self.fome < 20 or self.sede < 20:
                reg *= 0.5
            self.energia = min(100.0, self.energia + reg * dt)

        alvo = 0.0
        if remando:
            alvo += self.vel_remo()
        if b.vela:
            rel = dif_ang(b.ang, self.vento_ang)
            alvo += self.vel_vela() * self.forca_vento() * max(0.1, math.cos(rel))
        alvo = min(alvo, self.vel_max())
        if k[pygame.K_s] or k[pygame.K_DOWN]:
            alvo = 0.0
            b.vel *= max(0.0, 1 - 1.6 * dt)
        b.vel += (alvo - b.vel) * min(1.0, 1.3 * dt)

        # deriva: corrente + vento
        dx = math.cos(self.corr_ang) * 10 + math.cos(self.vento_ang) * 6 * self.forca_vento()
        dy = math.sin(self.corr_ang) * 10 + math.sin(self.vento_ang) * 6 * self.forca_vento()
        vx = math.cos(b.ang) * b.vel + dx + b.push[0]
        vy = math.sin(b.ang) * b.vel + dy + b.push[1]
        b.x += vx * dt
        b.y += vy * dt
        self.percorrido += math.hypot(vx, vy) * dt
        f = max(0.0, 1 - 1.2 * dt)
        b.push[0] *= f
        b.push[1] *= f

        # esteira de espuma
        self.rastro_cd -= dt
        if self.rastro_cd <= 0 and b.vel > 25:
            self.rastro_cd = 0.07
            self.rastro.append([b.x - math.cos(b.ang) * 30, b.y - math.sin(b.ang) * 30, 1.6])
        for r in self.rastro:
            r[2] -= dt
        self.rastro = [r for r in self.rastro if r[2] > 0][-70:]

    def _status(self, dt):
        k_corpo = 1.0 - 0.07 * self.hab["corpo"]
        self.fome = max(0.0, self.fome - CONSUMO_FOME * k_corpo * dt)
        self.sede = max(0.0, self.sede - CONSUMO_SEDE * k_corpo * dt)
        if self.tempestade > 0.35:
            self.sede = min(100.0, self.sede + 1.8 * self.tempestade * dt)

        dano = 0.0
        if self.fome <= 0:
            dano += 1.6
        if self.sede <= 0:
            dano += 2.6
        if dano:
            self.vida -= dano * dt
        elif self.fome > 55 and self.sede > 55:
            self.vida = min(100.0, self.vida + 0.7 * (1.0 + 0.15 * self.hab["corpo"]) * dt)

        # avisos (uma vez cada vez que o nível cai)
        for chave, valor, limite, texto in (
                ("sede", self.sede, 25, "Você está com muita sede! (%s)" % self.rot("beber")),
                ("fome", self.fome, 25, "Você está com muita fome! (%s)" % self.rot("comer")),
                ("casco", self.casco, 35, "O casco está muito danificado! (%s)" % self.rot("consertar"))):
            if valor < limite and not self.aviso[chave]:
                self.aviso[chave] = True
                self.som.tocar("aviso")
                self.msg(texto, VERMELHO)
            elif valor > limite + 15:
                self.aviso[chave] = False

        d = self.dist_ilha()
        if d < 3500 and not self.aviso["gaivotas"]:
            self.aviso["gaivotas"] = True
            self.som.tocar("gaivota", 1.0, -0.3)
            self._bando_gaivotas(3)
            self.msg("Gaivotas! Terra firme deve estar perto.", AMARELO)
        if d < 1500 and not self.aviso["terra"]:
            self.aviso["terra"] = True
            self.msg("TERRA À VISTA!", VERDE)
        if d < 3500 and self.noite_f() < 0.5:       # gaivotas de dia, cada vez mais seguidas perto da ilha
            self.gaivota_cd -= dt
            if self.gaivota_cd <= 0:
                self.gaivota_cd = self.som.rnd.uniform(6.0, 12.0) * (0.35 + 0.65 * d / 3500.0)
                self.som.tocar("gaivota", 0.5 + 0.5 * (1 - d / 3500.0), self.som.rnd.uniform(-0.8, 0.8))
                self._bando_gaivotas(random.randint(1, 3))

    def _bando_gaivotas(self, n):
        """Gaivotas da arte nova cruzando a tela (só enfeite, no ritmo do som). Voam rumo à ilha."""
        if not self.arte.ok:
            return
        b = self.barco
        rumo = math.atan2(self.ilha[1] - b.y, self.ilha[0] - b.x) + random.uniform(-0.5, 0.5)
        dist = max(LARGURA, ALTURA) * 0.75
        ox, oy = b.x - math.cos(rumo) * dist, b.y - math.sin(rumo) * dist
        for i in range(n):
            lado = random.uniform(-160, 160)
            self.gaivotas.append({"x": ox - math.sin(rumo) * lado + random.uniform(-60, 60),
                                  "y": oy + math.cos(rumo) * lado + random.uniform(-60, 60),
                                  "ang": rumo + random.uniform(-0.12, 0.12), "vel": random.uniform(95, 135),
                                  "fase": random.uniform(0, math.tau), "t": 0.0})

    def _pesca(self, dt, k):
        b = self.barco
        alvo, melhor = None, 95.0
        for c in self.cardumes:
            d = math.hypot(c.x - b.x, c.y - b.y)
            if d < melhor:
                melhor, alvo = d, c
        self.cardume_perto = alvo
        if k[pygame.K_f] and alvo is not None and not self.exausto:
            if not self.pescando:
                self.pescando = True
                self.som.tocar("pesca_lancar")
            rede = self.tem("rede")
            self.pesca_prog += dt * (1.0 + 0.12 * self.hab["pesca"]) / (1.6 / 1.4 if rede else 1.6)
            if self.pesca_prog >= 1:
                self.pesca_prog = 0.0
                alvo.n -= 1
                self.energia = max(0.0, self.energia - 3)
                if random.random() < (0.95 if rede else 0.85):
                    p_extra = (0.3 if rede else 0.0) + 0.07 * self.hab["pesca"]
                    extra = 1 if (p_extra > 0 and random.random() < p_extra) else 0
                    self.inv["peixe"] += 1 + extra
                    self.stats["peixes"] += 1 + extra
                    self._xp(6 + 3 * extra)
                    self.som.tocar("peixe")
                    self.msg("Pescaria farta! (+2 comida)" if extra else "Você pescou um peixe! (+1 comida)", VERDE)
                else:
                    self.som.tocar("nao")
                    self.msg("O peixe escapou...", CINZA)
                if alvo.n <= 0:
                    self.cardumes.remove(alvo)
                    self.cardume_perto = None
                    self.msg("O cardume foi embora.", CINZA)
                self.pescando = False       # cada peixe começa com um novo lançamento
        else:
            self.pescando = False
            self.pesca_prog = max(0.0, self.pesca_prog - 2 * dt)

    def _objetos(self, dt):
        b = self.barco

        for it in self.itens[:]:
            d = math.hypot(it.x - b.x, it.y - b.y)
            if d < (58 if it.tipo == "bau" else 42):
                self.itens.remove(it)
                self._coletar(it)
            elif d > 2600:
                self.itens.remove(it)
                if it.tipo == "bau":                # ficou para trás: outro nasce daqui a pouco
                    self.bau_cd = 20.0
            elif it.tipo == "bau" and d < 760:      # o brilho tilinta de leve quando está perto (acha-se de ouvido)
                self.bau_ping -= dt
                if self.bau_ping <= 0:
                    self.bau_ping = 4.5
                    self.som_em("tesouro", it.x, it.y, 0.9)

        # baú dourado: um por vez, até o barco ter todas as melhorias
        if self.falta_melhoria and self._bau() is None:
            self.bau_cd -= dt
            if self.bau_cd <= 0:
                if self._nascer_bau():
                    bau = self._bau()
                    self.som_em("tesouro", bau.x, bau.y, 0.9)
                    self.msg("Um brilho dourado surgiu no mar! Siga a seta dourada: é um baú.", AMARELO)
                else:
                    self.bau_cd = 10.0              # ilha perto demais: tenta mais tarde

        for g in self.gaivotas[:]:
            g["x"] += math.cos(g["ang"]) * g["vel"] * dt
            g["y"] += math.sin(g["ang"]) * g["vel"] * dt
            g["t"] += dt
            if g["t"] > 20.0:
                self.gaivotas.remove(g)
        for c in self.cardumes[:]:
            c.atualizar(dt)
            if math.hypot(c.x - b.x, c.y - b.y) > 2600:
                self.cardumes.remove(c)

        for s in self.tubaroes[:]:
            s.atualizar(dt, b, self)
            if math.hypot(s.x - b.x, s.y - b.y) > 1100:
                self.tubaroes.remove(s)
                continue
            for bd in self.bandos:                  # golfinhos por perto afugentam o tubarão
                if bd.vida > 0 and s.estado != "fugir" and math.hypot(bd.x - s.x, bd.y - s.y) < 330:
                    s.estado, s.fuga = "fugir", 4.0
                    if not self.aviso["golf_tub"]:
                        self.aviso["golf_tub"] = True
                        self.msg("Os golfinhos afugentam o tubarão!", VERDE)
                        self._xp(15)

        # reposição de itens e cardumes
        self.spawn_cd -= dt
        if self.spawn_cd <= 0:
            self.spawn_cd = 2.0
            cont = {"barril": 0, "tabua": 0, "corda": 0, "garrafa": 0, "bau": 0}
            for it in self.itens:
                cont[it.tipo] += 1
            # tipo, quantos no mar ao mesmo tempo, chance a cada 2 s, anel de nascimento (tábuas e cordas: mais perto)
            for tipo, n, chance, rmin, rmax in (("barril", 2, 0.5, 850, 1400), ("tabua", 5, 0.7, 650, 1250),
                                                ("corda", 5, 0.7, 650, 1250), ("garrafa", 1, 0.12, 850, 1400)):
                if cont[tipo] < n and random.random() < chance:
                    x, y = self._pos_anel(rmin, rmax)
                    self.itens.append(Item(tipo, x, y))
            if len(self.cardumes) < 2 and random.random() < 0.5:
                x, y = self._pos_anel(800, 1400)
                self.cardumes.append(Cardume(x, y))

        # tubarões
        self.spawn_tub -= dt
        if self.spawn_tub <= 0:
            noite = 1 - self.brilho()
            self.spawn_tub = random.uniform(22, 42) * (1 - 0.4 * noite) * (1 - 0.3 * self.tempestade)
            if len(self.tubaroes) < 3 and (self.t - self.t0) > 25:
                x, y = self._pos_anel(650, 850)
                self.tubaroes.append(Tubarao(x, y))
                self.som_em("tubarao", x, y, 1.0 if not self.aviso["tubarao"] else 0.6)
                if not self.aviso["tubarao"]:
                    self.aviso["tubarao"] = True
                    self.msg("Uma barbatana corta a água... TUBARÃO! (%s golpeia com o remo)"
                             % self.rot("golpe"), VERMELHO)

    def golpe_tentaculo(self, tn):
        """Chamado no instante em que um tentáculo agarra o casco."""
        b = self.barco
        self.casco -= 6 * self.mult_dano
        self.sanidade = max(0.0, self.sanidade - 7)
        self.tremor = 0.8
        self._quebrar_lanterna(0.30)
        a = math.atan2(b.y - tn.y, b.x - tn.x)
        emp = 0.6 if self.tem("leme") else 1.0
        b.push[0] += math.cos(a) * 70 * emp
        b.push[1] += math.sin(a) * 70 * emp
        for _ in range(8):  # espuma do impacto
            self.rastro.append([b.x + random.uniform(-34, 34), b.y + random.uniform(-34, 34), 1.6])
        self.som_em("tentaculo_golpe", tn.x, tn.y)
        self.msg("Um tentáculo agarrou o casco! Golpeie-o com o remo (%s)!" % self.rot("golpe"), VIOLETA)

    def _nasce_tentaculo(self):
        """Brota à frente do barco, onde ele estará em alguns segundos."""
        b = self.barco
        lead = 3.6
        vx = math.cos(b.ang) * b.vel + math.cos(self.corr_ang) * 10 + \
            math.cos(self.vento_ang) * 6 * self.forca_vento() + b.push[0]
        vy = math.sin(b.ang) * b.vel + math.sin(self.corr_ang) * 10 + \
            math.sin(self.vento_ang) * 6 * self.forca_vento() + b.push[1]
        a = random.uniform(0, math.tau)
        r = random.uniform(70, 130)
        x = b.x + vx * lead + math.cos(a) * r
        y = b.y + vy * lead + math.sin(a) * r
        d = math.hypot(x - b.x, y - b.y)
        if d < 140:  # nunca nasce em cima do casco
            if d < 1:
                x, y, d = b.x + 140, b.y, 140.0
            x = b.x + (x - b.x) / d * 140
            y = b.y + (y - b.y) / d * 140
        self.tentaculos.append(Tentaculo(x, y, b))
        self.som_em("tentaculo_emerge", x, y)
        if not self.aviso["tentaculo"]:
            self.aviso["tentaculo"] = True
            self.msg("Um TENTÁCULO emerge da água! Golpeie-o com o remo (%s) ou desvie!"
                     % self.rot("golpe"), VIOLETA)

    def _horror(self, dt):
        b = self.barco
        nf = self.noite_f()
        jogado = self.t - self.t0

        # a noite cai
        if nf > 0.5 and not self.aviso["noite"]:
            self.aviso["noite"] = True
            self.noites += 1
            self.som.tocar("noite")
            if self.noites == 1:
                self.msg("A noite cai. Mantenha a lanterna acesa... algo se agita lá embaixo.", VIOLETA)
            else:
                self.msg("A noite cai de novo. O fundo do mar desperta.", VIOLETA)
        elif nf < 0.2:
            if self.aviso["noite"]:
                self.som.tocar("amanhecer")
                self.msg("Você sobreviveu à noite! (+40 XP)", VERDE)
                self._xp(40)
            self.aviso["noite"] = False

        # nascimento das criaturas
        if jogado > 30:
            if nf > 0.4:
                self.spawn_tent -= dt
                if self.spawn_tent <= 0:
                    self.spawn_tent = random.uniform(9, 16)
                    if len(self.tentaculos) < 2:
                        self._nasce_tentaculo()
            if nf > 0.3 and self.sanidade < SAN_VULTO:        # o gigante só vem atrás de uma mente que cede
                self.spawn_vulto -= dt
                if self.spawn_vulto <= 0:
                    self.spawn_vulto = random.uniform(20, 40)
                    if len(self.vultos) < 2:
                        x, y = self._pos_anel(850, 900)
                        self.vultos.append(Vulto(x, y))
                        self.som_em("vulto", x, y, 1.2)
                        if not self.aviso["vulto"]:
                            self.aviso["vulto"] = True
                            self.msg("Uma sombra IMENSA desliza sob o barco. Não olhe para baixo.", VIOLETA)
        # mistério: manchas escuras e bolhas sobem do fundo quando a noite cai ou a mente falha
        self.spawn_bolha -= dt
        if self.spawn_bolha <= 0:
            ins = 1 - self.sanidade / 100.0
            self.spawn_bolha = random.uniform(3.5, 8.0) / (0.5 + ins + nf)
            if ((nf > 0.4 and self.sanidade < 75) or self.sanidade < 50) and len(self.bolhas) < 4:
                x, y = self._pos_anel(160, 520)
                self.bolhas.append([x, y, 0.0, random.uniform(5.0, 8.0), random.uniform(34, 62) * (1 + ins)])
        for bo in self.bolhas[:]:
            bo[2] += dt
            if bo[2] >= bo[3] or math.hypot(bo[0] - b.x, bo[1] - b.y) > 1000:
                self.bolhas.remove(bo)
        self.spawn_olho -= dt
        if self.spawn_olho <= 0:
            ins = 1 - self.sanidade / 100.0
            noite = nf > 0.35
            falso = (not noite) and self.sanidade < 25   # de dia, só alucinações
            if (noite or falso) and len(self.olhos) < 7:
                x, y = self._pos_anel(260, 650)
                self.olhos.append(Olhos(x, y, falso))
                self.som_em("olhos", x, y, 1.0)
            self.spawn_olho = random.uniform(2.5, 7.0) / (0.4 + nf + ins)

        # movimento das criaturas
        for v in self.vultos[:]:
            v.atualizar(dt, b, self)
            if (v.afundando and v.vis <= 0) or math.hypot(v.x - b.x, v.y - b.y) > 1800:
                self.vultos.remove(v)
        for tn in self.tentaculos[:]:
            tn.atualizar(dt, self)
            if tn.morto or math.hypot(tn.x - b.x, tn.y - b.y) > 900:
                self.tentaculos.remove(tn)
        for o in self.olhos[:]:
            o.t += dt
            if o.t >= o.dur or math.hypot(o.x - b.x, o.y - b.y) > 1000:
                self.olhos.remove(o)

        # sanidade
        dreno = SAN_NOITE * nf
        if not self.lanterna:
            dreno += SAN_SEM_LANTERNA * nf
        for v in self.vultos:
            d = math.hypot(v.x - b.x, v.y - b.y)
            if d < 250:
                dreno += SAN_VULTO_PERTO * v.vis
            elif d < 700:
                dreno += SAN_VULTO_LONGE * v.vis
            if d < 120:
                self.tremor = max(self.tremor, 0.2 * v.vis)   # o casco vibra com ele passando
        for tn in self.tentaculos:
            if tn.estado != "recolher" and math.hypot(tn.ponta[0] - b.x, tn.ponta[1] - b.y) < 320:
                dreno += SAN_TENTACULO * tn.altura
        for o in self.olhos:
            dreno += SAN_OLHOS * o.abertura
        dreno *= 1.0 - 0.08 * self.hab["mente"]
        if self.lanterna and self.tem("lente"):
            dreno *= 0.78                   # a luz forte da lente afasta um pouco o medo
        dreno = min(dreno, 3.5)
        regen = (SAN_REGEN_DIA if nf < 0.25 else 0.0) + 0.8 * self.consolo     # golfinhos e baleias acalmam
        self.sanidade = limitar(self.sanidade + (regen - dreno) * dt, 0.0, 100.0)

        # batimento cardíaco acelera conforme a mente cede
        k = limitar(1 - self.sanidade / 60.0, 0.0, 1.0)
        self.fase_bat = (self.fase_bat + dt * (1.1 + 2.0 * k) * math.tau) % (math.tau * 100)
        batida = int(self.fase_bat // math.tau)
        if batida != self.bat_ult:
            self.bat_ult = batida
            if k > 0:                       # o coração dispara conforme a mente cede
                self.som.tocar("coracao", 0.3 + 0.7 * k)

        # sussurros
        self.sussurro_cd -= dt
        if self.sussurro_cd <= 0 and ((nf > 0.4 and self.sanidade < 65) or self.sanidade < 30):
            self.sussurro_cd = random.uniform(14, 26)
            self.som.tocar("sussurro", 0.6 + 0.4 * (1 - self.sanidade / 100.0), self.som.rnd.uniform(-0.8, 0.8))
            self.msg(random.choice(SUSSURROS), VIOLETA)

        for chave, limite, texto in (
                ("loucura1", 50, "Sua mente começa a ceder. Lá embaixo, algo enorme percebeu."),
                ("loucura2", 25, "Você ouve o canto vindo do fundo. RESISTA!")):
            if self.sanidade < limite and not self.aviso[chave]:
                self.aviso[chave] = True
                if chave == "loucura2":
                    self.som.tocar("sussurro", 1.0, self.som.rnd.uniform(-0.6, 0.6))
                self.msg(texto, VIOLETA)
            elif self.sanidade > limite + 15:
                self.aviso[chave] = False

    def _checar_fim(self):
        if self.sanidade <= 0:
            self.fim_texto = "Sua mente se partiu. Você mergulhou, atraído pelo canto lá embaixo."
            self.fim_loucura = True
            self._fim(False)
        elif self.vida <= 0:
            if self.sede <= 0.5:
                self.fim_texto = "Você morreu de sede."
            elif self.fome <= 0.5:
                self.fim_texto = "Você morreu de fome."
            else:
                self.fim_texto = "Os ferimentos foram graves demais."
            self._fim(False)
        elif self.casco <= 0:
            self.fim_texto = "O barco afundou. Sem casco, não há como flutuar."
            self._fim(False)
        elif self.chegou_ilha():
            self.fim_texto = "Você alcançou uma ilha paradisíaca. Finalmente, terra firme!"
            self._fim(True)

    def _fim(self, vitoria):
        self.vitoria = vitoria
        self.estado = "fim"
        self.som.tocar("vitoria" if vitoria else ("loucura" if self.fim_loucura else "derrota"))

    # ------------------------------------------------------------------ efeitos
    @staticmethod
    def _textura(rnd, tam, cor, modo, termos, kmax, expoente=1.0, limiar=0.0):
        """Textura suave que se repete sem emendas, feita de ondas senoidais.
        modo "crista": linhas finas de luz (cáusticas); modo "mancha": manchas largas (nuvens)."""
        res = 128
        ondas = [(rnd.randint(1, kmax), rnd.choice((-1, 1)) * rnd.randint(1, kmax), rnd.uniform(0, math.tau))
                 for _ in range(termos)]
        pequena = pygame.Surface((res, res), 0, 32)
        for x in range(res):
            for y in range(res):
                s = sum(math.sin(math.tau * (a * x + b * y) / res + f) for a, b, f in ondas) / termos
                if modo == "crista":
                    v = (1 - abs(s)) ** expoente
                else:
                    v = max(0.0, (s * 0.5 + 0.5 - limiar) / (1.0 - limiar)) ** expoente
                pequena.set_at((x, y), (int(cor[0] * v), int(cor[1] * v), int(cor[2] * v)))
        mosaico = pygame.Surface((res * 3, res * 3), 0, 32)
        for i in range(3):
            for j in range(3):
                mosaico.blit(pequena, (i * res, j * res))
        grande = pygame.transform.smoothscale(mosaico, (tam * 3, tam * 3))
        tex = pygame.Surface((tam, tam), 0, 32)
        tex.blit(grande, (0, 0), (tam, tam, tam, tam))
        return tex

    @staticmethod
    def _radial(raio, forca=255, expo=1.6, cor=(0, 0, 0)):
        """Gradiente circular: opaco no centro, transparente na borda."""
        meio = max(4, raio // 2)
        s = pygame.Surface((meio * 2, meio * 2), pygame.SRCALPHA, 32)
        for r in range(meio, 0, -1):
            a = int(forca * (1 - r / meio) ** expo)
            pygame.draw.circle(s, (cor[0], cor[1], cor[2], a), (meio, meio), r)
        return pygame.transform.smoothscale(s, (raio * 2, raio * 2))

    @staticmethod
    def _feixe(comp, larg, meio_angulo, forca, expo, cor):
        """Facho de luz apontando para a direita, com origem no meio da borda esquerda."""
        mc, ml = comp // 2, larg // 2
        s = pygame.Surface((mc, ml), pygame.SRCALPHA, 32)
        cy = ml // 2
        passos = 32
        for k in range(passos):
            t = (k + 1) / passos
            tamanho = mc * (1.0 - 0.34 * t)
            meia = meio_angulo * (1.0 - 0.55 * t)
            pts = [(0, cy)]
            for i in range(13):
                a = -meia + 2 * meia * i / 12
                pts.append((math.cos(a) * tamanho, cy + math.sin(a) * tamanho))
            pygame.draw.polygon(s, (cor[0], cor[1], cor[2], int(forca * t ** expo)), pts)
        return pygame.transform.smoothscale(s, (comp, larg))

    def _criar_lente(self):
        """Luz da lente da lanterna: halo ~15% maior e feixe mais comprido e mais aberto, mais branco.
        Só é criada na hora em que a melhoria é achada (não pesa na abertura do jogo)."""
        raios = (310, 326, 343, 359, 375)
        return ([self._radial(r, 255, 1.5) for r in raios],
                [self._radial(int(r * 0.78), 125, 2.0, (255, 196, 110)) for r in raios],
                self._feixe(620, 430, 0.40, 215, 1.2, (0, 0, 0)),
                self._feixe(620, 430, 0.40, 85, 1.4, (255, 222, 150)))

    def _criar_efeitos(self):
        """Texturas, vinheta e máscaras de luz: geradas uma única vez na abertura."""
        rnd = random.Random(2024)
        self.tex_b1 = self._textura(rnd, 512, (30, 62, 66), "crista", 4, 3, 6.0)
        self.tex_b2 = self._textura(rnd, 512, (18, 44, 54), "crista", 4, 5, 6.0)
        self.tex_nuvem = self._textura(rnd, 768, (22, 26, 32), "mancha", 3, 2, 1.3, 0.5)

        peq = pygame.Surface((64, 42), pygame.SRCALPHA, 32)
        for x in range(64):
            for y in range(42):
                d = math.hypot((x + 0.5) / 32 - 1, (y + 0.5) / 21 - 1)
                a = limitar((d - 0.62) / 0.75, 0, 1) ** 1.7 * 120
                peq.set_at((x, y), (2, 8, 18, int(a)))
        self.vinheta = pygame.transform.smoothscale(peq, (LARGURA, ALTURA))
        self.escuro = pygame.Surface((LARGURA, ALTURA), pygame.SRCALPHA, 32)

        # lanterna: várias intensidades para dar o efeito de chama tremulando
        raios = (270, 284, 298, 312, 326)
        self.luz_sub = [self._radial(r, 255, 1.5) for r in raios]
        self.luz_glow = [self._radial(int(r * 0.78), 120, 2.0, (255, 170, 70)) for r in raios]
        self._cache_feixe = {}
        self.spr_espuma = []
        for k in range(10):
            r = 3 + k
            spr = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA, 32)
            pygame.draw.circle(spr, (232, 244, 255, 255), (r, r), r)
            pygame.draw.circle(spr, (232, 244, 255, 90), (r, r), r, 2)
            self.spr_espuma.append(spr)
        self.feixe_sub = self._feixe(520, 380, 0.36, 215, 1.2, (0, 0, 0))
        self.feixe_glow = self._feixe(520, 380, 0.36, 75, 1.4, (255, 205, 120))
        self.lamp_glow = self._radial(40, 230, 1.6, (255, 205, 120))
        # pequenos brilhos para achar itens na escuridão e a fogueira da ilha
        self.item_sub = self._radial(30, 170, 1.2)
        self.item_glow = self._radial(30, 90, 1.5, (130, 170, 210))
        # o baú dourado brilha bem mais (de dia e de noite)
        self.bau_halo = self._radial(140, 150, 1.4, (255, 205, 100))
        self.bau_sub = self._radial(120, 200, 1.2)
        self.bau_glow = self._radial(120, 140, 1.5, (255, 205, 100))
        self.lente = None            # luz da lente da lanterna (criada na hora em que a melhoria é achada)
        self.fogo_sub = self._radial(380, 255, 1.6)
        self.fogo_glow = self._radial(380, 130, 2.0, (255, 140, 50))

        # horror: olhos que brilham, bioluminescência e vinheta de sangue
        self.cores_olho = ((140, 255, 170), (190, 130, 255), (255, 210, 120))
        self.glow_olho = [self._radial(26, 255, 1.7, c) for c in self.cores_olho]
        self.glow_bio = self._radial(36, 170, 1.7, (160, 100, 255))
        # (fill com special_flags é lento no pygame; blitar uma superfície sólida com o mesmo
        # modo de mistura custa ~20x menos, então os tons de tela cheia usam esta superfície)
        self.tinta_s = pygame.Surface((LARGURA, ALTURA), 0, 32)
        # vinheta de sangue em 8 intensidades prontas (set_alpha em superfície com alfa por pixel é lento)
        self.vinheta_sangue = []
        for nivel in range(1, 9):
            peq = pygame.Surface((64, 42), pygame.SRCALPHA, 32)
            for x in range(64):
                for y in range(42):
                    d = math.hypot((x + 0.5) / 32 - 1, (y + 0.5) / 21 - 1)
                    a = limitar((d - 0.45) / 0.85, 0, 1) ** 1.5 * 210 * nivel / 8.0
                    peq.set_at((x, y), (110, 0, 14, int(a)))
            self.vinheta_sangue.append(pygame.transform.smoothscale(peq, (LARGURA, ALTURA)))

    def _tintar(self, cor, modo):
        """Soma/subtrai uma cor de toda a tela (modo = pygame.BLEND_RGB_ADD ou BLEND_RGB_SUB)."""
        self.tinta_s.fill(cor)
        self.tela.blit(self.tinta_s, (0, 0), special_flags=modo)

    def _tilear(self, tex, ox, oy, flags=0):
        w, h = tex.get_size()
        x0 = -(int(ox) % w)
        y0 = -(int(oy) % h)
        for x in range(x0, LARGURA, w):
            for y in range(y0, ALTURA, h):
                self.tela.blit(tex, (x, y), special_flags=flags)

    def _sombra_poligono(self, pts, ang, sx, sy, dx, dy, alpha=70, margem=80):
        spr = pygame.Surface((margem * 2, margem * 2), pygame.SRCALPHA, 32)
        pygame.draw.polygon(spr, (0, 10, 25, alpha), girar(pts, ang, margem, margem))
        self.tela.blit(spr, (int(sx - margem + dx), int(sy - margem + dy)))

    def _sombra_elipse(self, x, y, rx, ry, alpha=60):
        spr = pygame.Surface((rx * 2 + 2, ry * 2 + 2), pygame.SRCALPHA, 32)
        pygame.draw.ellipse(spr, (0, 10, 25, alpha), (0, 0, rx * 2, ry * 2))
        self.tela.blit(spr, (int(x - rx), int(y - ry)))

    # ------------------------------------------------------------------ desenho
    def desenhar(self):
        b = self.barco
        tremx = tremy = 0.0
        if self.tremor > 0:
            tremx = random.uniform(-1, 1) * self.tremor * 8
            tremy = random.uniform(-1, 1) * self.tremor * 8
        aproxima = limitar((1800-self.dist_ilha())/1000, 0, 1)
        olhar_x = limitar((self.ilha[0]-b.x)*.2, -LARGURA*.08, LARGURA*.08)*aproxima
        olhar_y = limitar((self.ilha[1]-b.y)*.8, -ALTURA*.25, ALTURA*.25)*aproxima
        self.cx = b.x - LARGURA / 2 + tremx + olhar_x
        self.cy = b.y - ALTURA / 2 + tremy + olhar_y
        self.bx = b.x - self.cx
        self.by = b.y - self.cy

        self._mar()
        self._rastro()
        self._itens()
        self._cardumes()
        self._baleias_desenho()
        self._tubaroes()
        self._golfinhos_desenho()
        self._bolhas_desenho()
        self._ilha()
        self.efeitos.desenhar(self.tela, self.cx, self.cy, self.cor_agua)
        self._barco_desenho()
        self._lant_faiscas()
        self._tentaculos_desenho()
        self._gaivotas_desenho()
        self._iluminacao()
        self._horror_overlay()
        self._clima_overlay()
        if self.estado != "menu":
            self._hud()

        if self.estado == "menu":
            self._tela_menu()
        elif self.estado == "pausa":
            self._tela_pausa()
        elif self.estado == "ficha":
            self._tela_ficha()
        elif self.estado == "fim":
            self._tela_fim()

    def _lant_faiscas(self):
        """Lanterna quebrada: faíscas fracas e um fio de fumaça saindo dela."""
        if not self.lant_quebrada or self.estado == "menu":
            return
        x, y = self.pos_lanterna
        if not (-40 < x < LARGURA + 40 and -40 < y < ALTURA + 40):
            return
        t = self.anim
        for i in range(4):
            f = (t * 0.55 + i * 0.25) % 1.0                         # fumaça sobe e some
            r = 3 + 8 * f
            fum = pygame.Surface((int(2 * r) + 2, int(2 * r) + 2), pygame.SRCALPHA, 32)
            pygame.draw.circle(fum, (90, 90, 96, int(110 * (1 - f))), (int(r) + 1, int(r) + 1), int(r))
            self.tela.blit(fum, (x + math.sin(t * 1.3 + i * 2) * 5 * f - r, y - 6 - 34 * f - r))
        for i in range(3):
            f = (t * 2.3 + i * 0.33) % 1.0
            if f < 0.25 and math.sin(t * 5.0 + i * 3.7) > -0.2:      # faísca: pisca de vez em quando
                a = i * 2.1 + int(t * 2.3 + i * 0.33) * 1.7
                px, py = x + math.cos(a) * 16 * f * 4, y + math.sin(a) * 12 * f * 4 - 4
                pygame.draw.circle(self.tela, (255, 214, 120), (int(px), int(py)), 2)
                pygame.draw.circle(self.tela, (255, 255, 230), (int(px), int(py)), 1)

    def _mar(self):
        br = self.brilho()
        self.cor_agua = self.oceano.desenhar(self.tela, self.anim, self.cx, self.cy,
                                            br, self.tempestade, self.leve)
        self._vultos_desenho()
        self.oceano.superficie(self.tela, self.anim, self.cx, self.cy,
                              br, self.tempestade, self.leve, self.cor_agua)

    def _mar_tiles(self, br):
        """Mar feito com os tiles de água da arte nova (dia, noite e tempestade, misturados conforme a hora
        e o clima). Devolve False se faltar algum tile: aí vale o mar desenhado por código."""
        if not self.arte.ok:
            return False
        if self._tiles is None:
            tiles = [self.arte.mosaico(n, LARGURA, ALTURA, sv) for n, sv in
                     (("agua_dia", 0.42), ("agua_noite", 0.20), ("agua_tempestade", 0.30))]
            meds = [self.arte.cor_media(n) for n in ("agua_dia", "agua_noite", "agua_tempestade")]
            self._tiles = tiles if all(tiles) and all(meds) else False
            self._tiles_med = meds
        if not self._tiles:
            return False
        dia, noite, storm = self._tiles
        md, mn, ms = self._tiles_med
        # cor média da água (os anéis, a espuma e as águas rasas da ilha usam)
        self.cor_agua = misturar(misturar(mn, md, br), ms, self.tempestade * 0.65)
        t = self.tela
        noite_f = limitar(1.0 - br, 0.0, 1.0)
        pri, sec, a_sec = (dia, noite, noite_f) if noite_f < 0.5 else (noite, dia, 1.0 - noite_f)
        if self.leve:
            a_sec = 0.0
        for k, (tile, alfa) in enumerate(((pri, 1.0), (sec, a_sec), (storm, self.tempestade * 0.8))):
            if alfa < 0.03:
                continue
            surf, bw, bh = tile
            x0 = -(int(self.cx * 0.97 + self.anim * 6) % bw)
            y0 = -(int(self.cy * 0.97 + self.anim * 3) % bh)
            if alfa < 0.99:
                surf.set_alpha(int(255 * alfa))
            t.blit(surf, (x0, y0))
            if alfa < 0.99:
                surf.set_alpha(None)
        return True

    def _rastro(self):
        # espuma translúcida: sprites prontos, só muda a transparência conforme envelhece
        for x, y, vida in self.rastro:
            f = vida / 1.6
            k = int((1 - f) * (len(self.spr_espuma) - 1))
            spr = self.spr_espuma[k]
            spr.set_alpha(int(170 * f))
            r = spr.get_width() // 2
            self.tela.blit(spr, (int(x - self.cx) - r, int(y - self.cy) - r))

    ILHA_S = 600            # meia-largura (px) da superfície onde a ilha é pré-desenhada

    def _deco_ilha(self):
        """Pré-desenha a ilha inteira numa superfície: águas rasas em degradê, praia de contorno irregular, mata
        em tufos sombreados, morro de pedra, pedras, troncos e conchas. Só as palmeiras, a fogueira e a
        espuma são animadas por quadro (em _ilha)."""
        if self._deco_chave == self.ilha:
            return
        self._deco_chave = self.ilha
        r = random.Random(int(abs(self.ilha[0]) * 7 + abs(self.ilha[1])))
        S = self.ILHA_S
        tau = math.tau

        # contorno da costa; a fogueira (no sul) precisa ficar na areia
        while True:
            f = [r.uniform(0, tau) for _ in range(6)]

            def rho(th, f=f):
                return 280.0 * (1 + 0.085 * math.sin(2 * th + f[0]) + 0.06 * math.sin(3 * th + f[1]) +
                                0.04 * math.sin(5 * th + f[2]) + 0.024 * math.sin(8 * th + f[3]) +
                                0.014 * math.sin(13 * th + f[4]))
            if min(rho(math.pi / 2 + d) for d in (-0.5, -0.25, 0, 0.25, 0.5)) >= 262:
                break
        g = [r.uniform(0, tau) for _ in range(4)]

        def rho_mata(th):
            v = 196.0 * (1 + 0.12 * math.sin(3 * th + g[0]) + 0.07 * math.sin(5 * th + g[1]) +
                         0.05 * math.sin(7 * th + g[2]))
            return v * (1 - 0.20 * max(0.0, math.cos(th - math.pi / 2)) ** 2)    # abre espaço para a fogueira

        N = 120
        costa = [(math.cos(i * tau / N) * rho(i * tau / N), math.sin(i * tau / N) * rho(i * tau / N))
                 for i in range(N)]
        mata = [(math.cos(i * tau / N) * rho_mata(i * tau / N), math.sin(i * tau / N) * rho_mata(i * tau / N))
                for i in range(N)]
        self._ilha_costa = costa

        surf = pygame.Surface((2 * S, 2 * S), pygame.SRCALPHA, 32)

        def poli(pts, esc, cor, larg=0):
            pygame.draw.polygon(surf, cor, [(S + x * esc, S + y * esc) for x, y in pts], larg)

        # A água animada continua visível sob a faixa rasa, sem borda de recorte.
        for k in range(40):
            f_ = k/39
            poli(costa,1.38-k*.009,(65,205,191,round(175*f_**1.3)))
        def textura(nome, pontos, escala):
            raw=self.arte.get(nome, w=180)
            if raw is None:return
            camada=pygame.Surface(surf.get_size(),pygame.SRCALPHA)
            for xx in range(0,2*S,raw.get_width()):
                for yy in range(0,2*S,raw.get_height()):camada.blit(raw,(xx,yy))
            mascara=pygame.Surface(surf.get_size(),pygame.SRCALPHA)
            pygame.draw.polygon(mascara,(255,255,255,255),[(S+x*escala,S+y*escala) for x,y in pontos])
            camada.blit(mascara,(0,0),special_flags=pygame.BLEND_RGBA_MULT)
            surf.blit(camada,(0,0))

        # areia molhada, seca e o miolo mais claro
        poli(costa, 1.018, (145, 210, 187, 190))
        poli(costa, 1.005, (226, 215, 169, 240))
        poli(costa, 0.975, (248, 235, 193, 255))
        poli(costa, 0.80, (250, 239, 203, 255))

        # Areia discreta, sem padrão diagonal repetido.

        def na_areia(dmin, dmax):
            th = r.uniform(0, tau)
            return th, r.uniform(dmin, dmax) * rho(th)
        for _ in range(240):                                       # grãos de areia
            th, d = na_areia(0.25, 0.94)
            pygame.draw.circle(surf, r.choice(((218, 200, 148), (250, 240, 196), (226, 208, 156))),
                               (int(S + math.cos(th) * d), int(S + math.sin(th) * d)), r.randint(1, 2))
        # sombra da mata na areia e a mata
        poli(mata, 1.07, (206, 188, 140, 255))
        poli(mata, 1.0, (75, 112, 58, 255))

        # Pequenos grupos de grama quebram a cor chapada sem repetir um tile.
        for _ in range(1800):
            a=r.uniform(0,tau);dd=math.sqrt(r.random())*rho_mata(a)*.98
            gx,gy=round(S+math.cos(a)*dd),round(S+math.sin(a)*dd)
            c=r.choice(((83,120,62),(90,127,65),(68,103,52),(102,133,68)))
            pygame.draw.line(surf,c,(gx,gy),(gx+1,gy-r.choice((2,3,4))),1)
            if r.random()<.35:pygame.draw.line(surf,c,(gx,gy),(gx-2,gy-2),1)

        def no_mata(fmin, fmax):
            while True:
                th = r.uniform(0, tau)
                d = rho_mata(th) * r.uniform(fmin, fmax)
                return th, d
        tufos = []
        for _ in range(78):
            th, d = no_mata(0.0, 0.97)
            d *= math.sqrt(r.random())
            tufos.append((S + math.cos(th) * d, S + math.sin(th) * d, r.uniform(20, 44), r.randint(0, 2)))
        for _ in range(44):                                        # tufos na borda: deixam o contorno irregular
            th, d = no_mata(0.90, 0.99)
            tufos.append((S + math.cos(th) * d, S + math.sin(th) * d, r.uniform(14, 26), r.randint(0, 2)))
        paleta = (((26, 74, 42), (44, 108, 58), (62, 136, 70), (92, 168, 90)),
                  ((24, 70, 44), (38, 98, 60), (54, 124, 72), (84, 154, 92)),
                  ((30, 80, 40), (58, 118, 54), (82, 148, 66), (122, 182, 90)))
        for i,(x,y,rr,k) in enumerate(sorted(tufos,key=lambda q:q[1])):
            if y>S+105 and abs(x-S)<65:continue
            if i%2:continue
            arb=self.arte.get("vila_moita_a" if k%2 else "vila_moita_b",w=round(rr*1.9))
            if arb:surf.blit(arb,arb.get_rect(midbottom=(round(x),round(y+rr*.45))))

        # A mata usa os tufos e palmeiras independentes do jogo.

        ped=self.arte.get("vila_rocha",w=90)
        if ped:surf.blit(ped,ped.get_rect(midbottom=(S-95,S-80)))

        # pedras (sprites) na beira da água
        for i in range(15):
            th = r.uniform(0, tau)
            if abs(th - math.pi / 2) < 0.4:
                continue
            d = rho(th) * r.uniform(0.93, 1.0)
            px, py = S + math.cos(th) * d, S + math.sin(th) * d
            rr = r.uniform(8, 20)
            ped = self.arte.get("pedra_%d" % (i % 3 + 1), w=max(10, int(rr * 2.6))) if self.arte.ok else None
            if ped is not None:
                pygame.draw.ellipse(surf, (150, 136, 98, 255), (px - ped.get_width() // 2 + 2, py + ped.get_height() // 6,
                                                                ped.get_width(), ped.get_height() // 2))
                surf.blit(ped, ped.get_rect(center=(int(px), int(py))))
            else:
                pygame.draw.circle(surf, (84, 88, 96), (int(px) + 2, int(py) + 3), int(rr))
                pygame.draw.circle(surf, (118, 122, 130), (int(px), int(py)), int(rr))
        # troncos trazidos pelo mar, conchas, estrelas-do-mar e algas na linha da maré
        for _ in range(4):
            th, d = na_areia(0.80, 0.95)
            if abs(th - math.pi / 2) < 0.4:
                continue
            a_ = th + math.pi / 2 + r.uniform(-0.5, 0.5)
            comp, larg = r.uniform(26, 40), r.uniform(6, 8)
            cx_, cy_ = S + math.cos(th) * d, S + math.sin(th) * d
            for gro, cor_ in ((larg + 2, (60, 38, 22)), (larg, (108, 74, 42)), (larg * 0.4, (150, 110, 66))):
                pygame.draw.line(surf, cor_, (cx_ - math.cos(a_) * comp / 2, cy_ - math.sin(a_) * comp / 2 - (larg - gro) * 0.15),
                                 (cx_ + math.cos(a_) * comp / 2, cy_ + math.sin(a_) * comp / 2 - (larg - gro) * 0.15),
                                 max(1, int(gro)))
        for _ in range(16):
            th, d = na_areia(0.55, 0.93)
            pygame.draw.circle(surf, r.choice(((244, 196, 196), (250, 246, 238), (232, 176, 150))),
                               (int(S + math.cos(th) * d), int(S + math.sin(th) * d)), 2)
        for _ in range(2):
            th, d = na_areia(0.7, 0.9)
            ex, ey = S + math.cos(th) * d, S + math.sin(th) * d
            pts = [(ex + math.cos(i * tau / 10 - 1.57) * (7 if i % 2 == 0 else 3),
                    ey + math.sin(i * tau / 10 - 1.57) * (7 if i % 2 == 0 else 3)) for i in range(10)]
            pygame.draw.polygon(surf, (230, 120, 70), pts)
        for _ in range(12):
            th = r.uniform(0, tau)
            d = rho(th) * r.uniform(0.985, 1.02)
            ax, ay = S + math.cos(th) * d, S + math.sin(th) * d
            for k in range(3):
                pygame.draw.line(surf, (46, 96, 62), (ax, ay), (ax + r.uniform(-7, 7), ay + r.uniform(-7, 7)), 2)

        # palmeiras: borda da mata, miolo e algumas na praia (a altura varia)
        pal = []
        for _ in range(6):
            th, d = no_mata(0.80, 0.96)
            pal.append((th, d, r.uniform(0, tau), r.choice((78, 84, 92))))
        for _ in range(6):
            th, d = no_mata(0.15, 0.70)
            pal.append((th, d, r.uniform(0, tau), r.choice((84, 92, 98))))
        for _ in range(8):
            th = r.uniform(0, tau)
            d = rho(th) * r.uniform(0.80, 0.86)
            if abs(th - math.pi / 2) < 0.5 or d < rho_mata(th) + 36:
                continue
            pal.append((th, d, r.uniform(0, tau), r.choice((70, 78))))
        self.palmeiras = pal[:18]
        self.vila.preparar(surf,costa,S,self.arte)
        self._ilha_surf = surf.convert_alpha()

    def pos_fogo_mundo(self):
        return self.ilha[0]+self.vila.FOGO[0], self.ilha[1]+self.vila.FOGO[1]

    def _ilha(self):
        self._ilha_antiga()
        if self.dist_ilha()<1400:
            self.vila.desenhar(self.tela,(self.ilha[0]-self.cx,self.ilha[1]-self.cy),self.anim,self.arte)

    def _ilha_antiga(self):
        sx = self.ilha[0] - self.cx
        sy = self.ilha[1] - self.cy
        S = self.ILHA_S
        if not (-S < sx < LARGURA + S and -S < sy < ALTURA + S):
            return
        self._deco_ilha()
        t = self.tela
        t.blit(self._ilha_surf, (int(sx) - S, int(sy) - S))
        # Espuma fragmentada acompanha a costa; sem anéis fechados.
        for k in range(2):
            fase=(self.anim*.22+k*.5)%1
            esc=1.13-fase*.10
            intensidade=math.sin(fase*math.pi)*.5
            cor=misturar(self.cor_agua,(195,232,219),intensidade)
            pts=[(sx+x*esc,sy+y*esc) for x,y in self._ilha_costa]
            for i in range(0,len(pts)-3,6):
                if i%18!=0:pygame.draw.lines(t,cor,False,pts[i:i+3],1)
        # palmeiras (de trás para a frente), balançando
        palma = self.arte.get("palmeira", h=84) if self.arte.ok else None
        onda_palma = (24, 3.5, "y", "max", 0.6)
        for a, d, fase, alt in (sorted(self.palmeiras, key=lambda q: math.sin(q[0]) * q[1]) if palma else self.palmeiras):
            px = sx + math.cos(a) * d
            py = sy + math.sin(a) * d
            if palma is not None:
                pygame.draw.ellipse(t, (22, 70, 34), (int(px - 20), int(py + 14), 40, 16))
                lista = self.arte.ondular("palmeira", *onda_palma, h=alt)
                if lista:
                    q = int((self.anim * 0.55 + fase / math.tau) * len(lista)) % len(lista)
                    t.blit(lista[q], lista[q].get_rect(midbottom=(int(px), int(py) + 26)))
                else:
                    t.blit(palma, palma.get_rect(midbottom=(int(px), int(py) + 26)))
                continue
            pygame.draw.circle(t, (22, 70, 34), (int(px + 5), int(py + 7)), 16)
            for i in range(8):
                af = i * math.tau / 8 + fase + math.sin(self.anim * 1.2 + fase) * 0.07
                folha = girar([(0, 0), (12, -5), (32, -1), (34, 0), (32, 1), (12, 5)], af, px, py)
                pygame.draw.polygon(t, (30, 118, 50) if i % 2 else (44, 140, 62), folha)
                pygame.draw.line(t, (92, 176, 96), (px, py),
                                 (px + math.cos(af) * 30, py + math.sin(af) * 30), 1)
            pygame.draw.circle(t, (96, 62, 30), (int(px - 2), int(py - 1)), 4)
            pygame.draw.circle(t, (120, 80, 40), (int(px + 3), int(py + 2)), 4)
    def _itens(self):
        t = self.tela
        esp = misturar(self.cor_agua, BRANCO, 0.4)
        for it in self.itens:
            sx = it.x - self.cx
            sy = it.y - self.cy + math.sin(self.anim * 2 + it.fase) * 2
            if not (-50 < sx < LARGURA + 50 and -50 < sy < ALTURA + 50):
                continue
            p = (int(sx), int(sy))
            if it.tipo == "bau":
                self._desenhar_bau(it, sx, sy)
                continue
            for k in range(2):  # ondas concêntricas
                f = (self.anim * 0.5 + it.fase + k * 0.5) % 1.0
                pygame.draw.circle(t, misturar(esp, self.cor_agua, f), p, int(14 + f * 20), 1)
            self._sombra_elipse(sx + 3, sy + 5, 16, 11)

            if self._item_sprite(it, sx, sy):
                continue
            if it.tipo == "corda":
                a = it.ang + math.sin(self.anim * 0.9 + it.fase) * 0.25
                pygame.draw.circle(t, (84, 62, 36), p, 12)                      # rolo de corda visto de cima
                pygame.draw.circle(t, (216, 188, 132), p, 10)
                pygame.draw.circle(t, (84, 62, 36), p, 7)
                pygame.draw.circle(t, (200, 172, 116), p, 6)
                pygame.draw.circle(t, (84, 62, 36), p, 3)
                for i in range(9):                                              # trama (torção) da corda
                    ai = a + i * math.tau / 9
                    for r0, r1 in ((7.5, 9.8), (3.6, 5.6)):
                        pygame.draw.line(t, (160, 128, 82), (sx + math.cos(ai) * r0, sy + math.sin(ai) * r0),
                                         (sx + math.cos(ai + 0.3) * r1, sy + math.sin(ai + 0.3) * r1), 1)
                ponta = [(sx + math.cos(a) * 10, sy + math.sin(a) * 10),
                         (sx + math.cos(a) * 16 - math.sin(a) * 4, sy + math.sin(a) * 16 + math.cos(a) * 4),
                         (sx + math.cos(a) * 22 - math.sin(a) * 2, sy + math.sin(a) * 22 + math.cos(a) * 9)]
                pygame.draw.lines(t, (84, 62, 36), False, ponta, 5)
                pygame.draw.lines(t, (216, 188, 132), False, ponta, 3)
            elif it.tipo == "barril":
                pygame.draw.circle(t, (84, 52, 26), p, 15)
                pygame.draw.circle(t, (160, 110, 60), p, 12)
                for dx in (-7, -3.5, 0, 3.5, 7):
                    h = math.sqrt(max(0.0, 144 - dx * dx))
                    pygame.draw.line(t, (122, 80, 42), (sx + dx, sy - h), (sx + dx, sy + h), 1)
                pygame.draw.circle(t, (118, 122, 130), p, 12, 2)
                pygame.draw.circle(t, (118, 122, 130), p, 6, 1)
                pygame.draw.circle(t, (214, 176, 126), (int(sx - 5), int(sy - 6)), 2)
            elif it.tipo == "tabua":
                a = it.ang + math.sin(self.anim + it.fase) * 0.2
                pts = girar([(-17, -4.5), (17, -4.5), (17, 4.5), (-17, 4.5)], a, sx, sy)
                pygame.draw.polygon(t, (178, 132, 82), pts)
                pygame.draw.polygon(t, (100, 66, 36), pts, 2)
                for yy in (-1.8, 1.8):
                    g = girar([(-14, yy), (14, yy)], a, sx, sy)
                    pygame.draw.line(t, (150, 106, 64), g[0], g[1], 1)
                for xx in (-13, 13):
                    n = girar([(xx, 0)], a, sx, sy)[0]
                    pygame.draw.circle(t, (70, 70, 78), (int(n[0]), int(n[1])), 1)
            else:  # garrafa com mapa
                a = it.ang + math.sin(self.anim * 1.2 + it.fase) * 0.3
                corpo = [(-10, -4.5), (5, -4.5), (5, 4.5), (-10, 4.5)]
                gargalo = [(5, -2), (12, -2), (12, 2), (5, 2)]
                pygame.draw.polygon(t, (98, 196, 150), girar(corpo, a, sx, sy))
                pygame.draw.polygon(t, (98, 196, 150), girar(gargalo, a, sx, sy))
                pygame.draw.polygon(t, (238, 228, 192), girar([(-7, -1.8), (2, -1.8), (2, 1.8), (-7, 1.8)], a, sx, sy))
                brilho = girar([(-9, -3.2), (4, -3.2)], a, sx, sy)
                pygame.draw.line(t, (215, 250, 232), brilho[0], brilho[1], 1)
                rolha = girar([(12.5, 0)], a, sx, sy)[0]
                pygame.draw.circle(t, (176, 128, 80), (int(rolha[0]), int(rolha[1])), 3)

    # tamanho na tela de cada item da arte nova (altura, ou largura quando for comprido)
    ITEM_ARTE = {"barril": ("item_barril", "h", 34), "corda": ("item_corda", "h", 30),
                 "tabua": ("item_tabua", "w", 42), "garrafa": ("item_garrafa", "w", 34)}

    def _item_sprite(self, it, sx, sy):
        """Desenha o item com o sprite da arte nova; False se não houver (volta ao desenho por código)."""
        if not self.arte.ok or it.tipo not in self.ITEM_ARTE:
            return False
        nome, lado, tam = self.ITEM_ARTE[it.tipo]
        kw = {lado: tam}
        if it.tipo == "barril":
            graus = math.sin(self.anim * 1.1 + it.fase) * 7.0           # o barril rola um pouco na marola
            som = self.arte.rot(nome, graus, passo=3, escuro=True, **kw)
            if som is not None:
                self.tela.blit(som, som.get_rect(center=(int(sx + 3), int(sy + 5))))
            spr = self.arte.rot(nome, graus, passo=3, **kw)
        else:
            if it.tipo == "tabua":
                a = it.ang + math.sin(self.anim + it.fase) * 0.2
            elif it.tipo == "garrafa":
                a = it.ang + math.sin(self.anim * 1.2 + it.fase) * 0.3
            else:
                a = math.sin(self.anim * 0.9 + it.fase) * 0.45
            graus = -math.degrees(a)
            som = self.arte.rot(nome, graus, passo=5, escuro=True, **kw)
            if som is not None:
                self.tela.blit(som, som.get_rect(center=(int(sx + 3), int(sy + 5))))
            spr = self.arte.rot(nome, graus, passo=5, **kw)
        if spr is None:
            return False
        self.tela.blit(spr, spr.get_rect(center=(int(sx), int(sy))))
        return True

    def _desenhar_bau(self, it, sx, sy):
        """Baú dourado boiando: halo pulsante, ondas douradas e faíscas, para dar para achar de longe."""
        t = self.tela
        pulso = 0.5 + 0.5 * math.sin(self.anim * 3.0 + it.fase)
        for k in range(3):                                          # ondas largas e douradas
            f = (self.anim * 0.45 + k / 3.0 + it.fase) % 1.0
            pygame.draw.circle(t, misturar((255, 214, 110), self.cor_agua, f), (int(sx), int(sy)),
                               int(20 + f * 46), 2)
        self.bau_halo.set_alpha(int(80 + 90 * pulso))
        t.blit(self.bau_halo, (int(sx) - 70, int(sy) - 70))
        self._sombra_elipse(sx + 4, sy + 6, 21, 14)
        a = math.sin(self.anim * 1.2 + it.fase) * 0.12
        spr = self.arte.rot("item_bau", -math.degrees(a), passo=3, w=44) if self.arte.ok else None
        if spr is not None:
            t.blit(spr, spr.get_rect(center=(int(sx), int(sy))))
            for i in range(3):                                      # faíscas girando em volta
                ang = self.anim * 0.9 + i * 2.1 + it.fase
                r = 26 + 3 * math.sin(self.anim * 2 + i)
                fx, fy = sx + math.cos(ang) * r, sy + math.sin(ang) * r * 0.75
                tam = 2 + 3 * (0.5 + 0.5 * math.sin(self.anim * 5 + i * 2))
                pygame.draw.line(t, (255, 244, 190), (fx - tam, fy), (fx + tam, fy), 1)
                pygame.draw.line(t, (255, 244, 190), (fx, fy - tam), (fx, fy + tam), 1)
            return

        def G(pts):
            return girar(pts, a, sx, sy)
        corpo = G([(-14, -10), (14, -10), (14, 10), (-14, 10)])
        pygame.draw.polygon(t, (122, 78, 40), corpo)
        pygame.draw.polygon(t, (50, 28, 12), corpo, 2)
        for yy in (-5, 0, 5):                                       # tábuas da tampa
            g = G([(-13, yy), (13, yy)])
            pygame.draw.line(t, (92, 58, 28), g[0], g[1], 1)
        for xx in (-9.5, 6.5):                                      # cintas de ouro
            cinta = G([(xx, -10), (xx + 3, -10), (xx + 3, 10), (xx, 10)])
            pygame.draw.polygon(t, (238, 192, 72), cinta)
            pygame.draw.polygon(t, (150, 104, 30), cinta, 1)
        trava = G([(0, 0)])[0]
        pygame.draw.circle(t, (255, 228, 124), (int(trava[0]), int(trava[1])), 4)
        pygame.draw.circle(t, (150, 104, 30), (int(trava[0]), int(trava[1])), 4, 1)
        pygame.draw.circle(t, (60, 36, 12), (int(trava[0]), int(trava[1])), 1)
        for i in range(3):                                          # faíscas girando em volta
            ang = self.anim * 0.9 + i * 2.1 + it.fase
            r = 22 + 3 * math.sin(self.anim * 2 + i)
            fx, fy = sx + math.cos(ang) * r, sy + math.sin(ang) * r * 0.75
            tam = 2 + 3 * (0.5 + 0.5 * math.sin(self.anim * 5 + i * 2))
            pygame.draw.line(t, (255, 244, 190), (fx - tam, fy), (fx + tam, fy), 1)
            pygame.draw.line(t, (255, 244, 190), (fx, fy - tam), (fx, fy + tam), 1)

    def _cardumes(self):
        t = self.tela
        for c in self.cardumes:
            sx, sy = c.x - self.cx, c.y - self.cy
            if not (-80 < sx < LARGURA + 80 and -80 < sy < ALTURA + 80):
                continue
            for k in range(2):
                f = (self.anim * 0.35 + c.fase + k * 0.5) % 1.0
                raio = 34 + f * 22
                pygame.draw.circle(t, misturar(misturar(self.cor_agua, BRANCO, 0.16), self.cor_agua, f),
                                   (int(sx), int(sy)), int(raio), 1)
            cor = misturar(self.cor_agua, (215, 228, 238), 0.7)
            sombra = misturar(self.cor_agua, (0, 10, 30), 0.25)
            for i in range(c.n):
                fr, lat, fp, fv = c.peixes[i]
                lado = lat + math.sin(self.anim * fv + fp) * 7.0              # vaivém de lado
                frente = fr + math.sin(self.anim * fv * 0.7 + fp * 2.0) * 9.0
                vlat = math.cos(self.anim * fv + fp) * 7.0 * fv               # o quanto ele escorrega de lado
                d = c.dir + math.atan2(vlat, CARDUME_VEL + 10.0)              # o focinho segue a curva
                px = sx + math.cos(c.dir) * frente - math.sin(c.dir) * lado
                py = sy + math.sin(c.dir) * frente + math.cos(c.dir) * lado
                if self.arte.ok:
                    nome = "peixe_topo_%d" % ((i + int(c.fase * 4)) % 4 + 1)
                    graus = -math.degrees(d) - 90.0                           # o peixe do sprite olha para cima
                    onda = (16, 1.6, "y", "min", 1.0)                          # corpo em S, rabo balançando
                    qd = int(self.anim * 17.0 + i * 3 + c.fase * 5)
                    spr = self.arte.rot(nome, graus, passo=6, h=31, onda=onda, quadro=qd, alfa=222)
                    if spr is not None:
                        som = self.arte.rot(nome, graus, passo=6, h=31, escuro=True, onda=onda, quadro=qd)
                        t.blit(som, som.get_rect(center=(int(px + 3), int(py + 5))))
                        t.blit(spr, spr.get_rect(center=(int(px), int(py))))
                        continue
                bal = math.sin(self.anim * 9 + i * 1.7) * 2.5
                corpo = [(7, 0), (-4, -3.5), (-7, 0), (-4, 3.5)]
                cauda = [(-7, 0), (-12, -3 + bal), (-12, 3 + bal)]
                pygame.draw.polygon(t, sombra, girar(corpo, d, px + 3, py + 4))
                pygame.draw.polygon(t, cor, girar(corpo, d, px, py))
                pygame.draw.polygon(t, cor, girar(cauda, d, px, py))

    def _tubaroes(self):
        t = self.tela
        espuma = misturar(self.cor_agua, BRANCO, 0.5)
        for s in self.tubaroes:
            sx, sy = s.x - self.cx, s.y - self.cy
            if not (-100 < sx < LARGURA + 100 and -100 < sy < ALTURA + 100):
                continue
            if self.arte.ok:
                soma = None if s.piscar <= 0 else (120, 18, 10)
                graus = -math.degrees(s.ang) - 90.0                # o tubarão do sprite olha para cima
                onda = (24, 5.5, "y", "min", 0.8)                      # a cabeça firme, o corpo e o rabo ondulam
                qd = int(self.anim * 24.0 + s.x * 0.013)
                im = self.arte.rot("tubarao", graus, passo=2, h=100, soma=soma, alfa=228, onda=onda, quadro=qd,
                                   guardar=False)
                if im is not None:
                    fin = girar([(6, 0)], s.ang, sx, sy)[0]
                    for lado in (-1, 1):                           # rastro de espuma
                        fim = girar([(-24, lado * 11)], s.ang, sx, sy)[0]
                        pygame.draw.line(t, espuma, fin, fim, 2)
                    sombra = self.arte.rot("tubarao", graus, passo=2, h=100, escuro=True, onda=onda, quadro=qd,
                                           guardar=False)
                    t.blit(sombra, sombra.get_rect(center=(int(sx + 4), int(sy + 7))))
                    t.blit(im, im.get_rect(center=(int(sx), int(sy))))
                    continue
            m = 70
            spr = pygame.Surface((m * 2, m * 2), pygame.SRCALPHA, 32)
            o = math.sin(self.anim * 6 + s.x * 0.01)
            semi = [(38, 0), (32, 3.5), (22, 7), (8, 10), (-6, 9.5), (-18, 6), (-28, 2.5)]
            corpo = semi + [(x, -y) for x, y in reversed(semi)]
            cor = (52, 74, 96, 210) if s.piscar <= 0 else (222, 112, 100, 235)
            cauda = [(-26, 2), (-45, 13 + o * 5), (-38, o * 2.5), (-45, -13 + o * 5), (-26, -2)]
            pygame.draw.polygon(spr, cor, girar(cauda, s.ang, m, m))
            for lado in (-1, 1):
                nad = [(14, lado * 8), (-6, lado * 26), (-2, lado * 9)]
                pygame.draw.polygon(spr, cor, girar(nad, s.ang, m, m))
            pygame.draw.polygon(spr, cor, girar(corpo, s.ang, m, m))
            ventre = [(30, 0), (20, 4), (4, 5.5), (-10, 4), (-20, 0), (-10, -4), (4, -5.5), (20, -4)]
            pygame.draw.polygon(spr, (150, 172, 188, 80), girar(ventre, s.ang, m, m))
            t.blit(spr, (int(sx - m), int(sy - m)))
            # barbatana dorsal acima da água e rastro de espuma
            fin = girar([(6, 0)], s.ang, sx, sy)[0]
            for lado in (-1, 1):
                fim = girar([(-24, lado * 11)], s.ang, sx, sy)[0]
                pygame.draw.line(t, espuma, fin, fim, 2)
            pygame.draw.polygon(t, (28, 42, 58), girar([(8, 0), (-6, -3.5), (-9, 0), (-6, 3.5)], s.ang, sx, sy))
            pygame.draw.polygon(t, (60, 84, 106), girar([(7, 0), (-4, -1.5), (-4, 1.5)], s.ang, sx, sy))

    def _spr_fauna(self, nome, h, onda, quadro, graus, escala=1.0, alfa=255, escuro=False):
        """Quadro da ondulação, girado na hora (os bichos grandes não cabem no cache de ângulos)."""
        lista = self.arte.ondular(nome, *onda, h=h)
        if not lista:
            return None
        base = lista[quadro % len(lista)]
        if escuro:
            base = base.copy()
            base.fill((18, 40, 64, 255), special_flags=pygame.BLEND_RGBA_MULT)
        r = pygame.transform.rotozoom(base, graus, escala)
        if escuro:
            r.set_alpha(alfa if alfa < 255 else 80)
        elif alfa < 255:
            r.set_alpha(alfa)
        return r

    def _golfinhos_desenho(self):
        t = self.tela
        for bd in self.bandos:
            sx, sy = bd.x - self.cx, bd.y - self.cy
            if not (-260 < sx < LARGURA + 260 and -260 < sy < ALTURA + 260):
                continue
            for i, m in enumerate(bd.membros):
                wx, wy = bd._pos(m)
                px, py = wx - self.cx, wy - self.cy
                sl = m["salto"]
                alto = math.sin(math.pi * sl) if sl >= 0 else 0.0           # 0 na água, 1 no pico do salto
                graus = -math.degrees(bd.ang) - 90.0 + math.sin(bd.t * 2.1 + m["fase"]) * 5.0
                qd = 0 if sl >= 0 else int(bd.t * 9.0 + i * 3)
                if self.arte.ok:
                    som = self._spr_fauna("golfinho", H_GOLFINHO, ONDA_GOLFINHO, qd, graus, 1.0, 90 - int(40 * alto), True)
                    spr = self._spr_fauna("golfinho", H_GOLFINHO, ONDA_GOLFINHO, qd, graus, 1.0 + 0.30 * alto)
                    if spr is not None:
                        t.blit(som, som.get_rect(center=(int(px + 4 + 10 * alto), int(py + 6 + 12 * alto))))
                        t.blit(spr, spr.get_rect(center=(int(px), int(py - 28 * alto))))
                        continue
                corpo = [(20, 0), (12, -5), (-6, -6.5), (-20, -2.5), (-26, 0), (-20, 2.5), (-6, 6.5), (12, 5)]
                cauda = [(-24, 0), (-34, -8), (-30, 0), (-34, 8)]
                pygame.draw.polygon(t, (22, 46, 70), girar(corpo, bd.ang, px + 4, py + 6))
                pygame.draw.polygon(t, (110, 134, 152), girar(cauda, bd.ang, px, py - 28 * alto))
                pygame.draw.polygon(t, (110, 134, 152), girar(corpo, bd.ang, px, py - 28 * alto))

    def _baleias_desenho(self):
        t = self.tela
        for bl in self.baleias:
            sx, sy = bl.x - self.cx, bl.y - self.cy
            if -420 < sx < LARGURA + 420 and -420 < sy < ALTURA + 420:
                graus = -math.degrees(bl.ang) - 90.0
                fund = bl.profund                                              # mergulhada: some e fica escura
                esc = 1.0 - 0.10 * fund
                qd = int(bl.t * 2.2)
                if self.arte.ok:
                    som = self._spr_fauna("baleia", H_BALEIA, ONDA_BALEIA, qd, graus, esc, int(70 * (1 - 0.7 * fund)), True)
                    spr = self._spr_fauna("baleia", H_BALEIA, ONDA_BALEIA, qd, graus, esc, int(255 - 150 * fund))
                    if spr is not None:
                        t.blit(som, som.get_rect(center=(int(sx + 8), int(sy + 12))))
                        t.blit(spr, spr.get_rect(center=(int(sx), int(sy))))
                else:
                    corpo = [(145, 0), (120, -34), (40, -48), (-60, -42), (-120, -20), (-145, 0), (-120, 20),
                             (-60, 42), (40, 48), (120, 34)]
                    cauda = [(-135, 0), (-170, -46), (-150, 0), (-170, 46)]
                    cor = misturar((48, 64, 84), self.cor_agua, 0.6 * fund)
                    pygame.draw.polygon(t, cor, girar(cauda, bl.ang, sx, sy))
                    pygame.draw.polygon(t, cor, girar(corpo, bl.ang, sx, sy))
            for idade, wx, wy in bl.sopros:                                    # jato de água e anéis
                px, py = wx - self.cx, wy - self.cy
                if not (-80 < px < LARGURA + 80 and -80 < py < ALTURA + 80):
                    continue
                f = idade / 2.2
                for k in range(10):
                    a = k * math.tau / 10 + wx * 0.01
                    rr = 4 + 40 * f ** 0.6
                    cor = misturar(BRANCO, self.cor_agua, f)
                    pygame.draw.circle(t, cor, (int(px + math.cos(a) * rr), int(py + math.sin(a) * rr * 0.8)),
                                       max(1, int(3 - 2 * f)))
                pygame.draw.circle(t, misturar(BRANCO, self.cor_agua, 0.4 + 0.6 * f), (int(px), int(py)),
                                   int(8 + 26 * f), 2)

    def _bolhas_desenho(self):
        """Mancha escura que cresce sob a água, com bolhas estourando em anéis: algo enorme está subindo."""
        t = self.tela
        for x, y, tt, dur, rmax in self.bolhas:
            sx, sy = x - self.cx, y - self.cy
            if not (-120 < sx < LARGURA + 120 and -120 < sy < ALTURA + 120):
                continue
            f = tt / dur
            env = math.sin(math.pi * f)
            r = rmax * (0.35 + 0.65 * f)
            self._sombra_elipse(sx, sy, int(r * 1.15), int(r * 0.9), int(54 * env))
            self._sombra_elipse(sx, sy, int(r * 0.7), int(r * 0.55), int(42 * env))
            for k in range(4):
                g = (f * 3.0 + k * 0.37) % 1.0
                ang = k * 1.9 + x * 0.01
                px = sx + math.cos(ang) * r * 0.55
                py = sy + math.sin(ang) * r * 0.45
                cor = misturar(self.cor_agua, BRANCO, 0.6 * (1 - g) * env)
                pygame.draw.circle(t, cor, (int(px), int(py)), int(2 + g * 9), 1)

    def _gaivotas_desenho(self):
        """Gaivotas voando: o bater de asas é a largura do sprite, e a sombra cai na água."""
        if not self.gaivotas or not self.arte.ok:
            return
        t = self.tela
        for g in self.gaivotas:
            sx, sy = g["x"] - self.cx, g["y"] - self.cy
            if not (-60 < sx < LARGURA + 60 and -60 < sy < ALTURA + 60):
                continue
            rajada = 0.5 + 0.5 * math.sin(self.anim * 0.9 + g["fase"] * 2)       # bate asa um tempo, depois plana
            bate = 0.5 + 0.5 * math.sin(self.anim * 9.0 + g["fase"]) if rajada > 0.35 else 0.85
            w = 28 + int(round(bate * 6)) * 4                         # 7 aberturas de asa: 28 a 52
            graus = -math.degrees(g["ang"]) - 90.0                    # a gaivota do sprite olha para cima
            som = self.arte.rot("gaivota", graus, passo=6, w=w, escuro=True)
            spr = self.arte.rot("gaivota", graus, passo=6, w=w)
            if spr is None:
                continue
            t.blit(som, som.get_rect(center=(int(sx + 24 + 4 * bate), int(sy + 34 + 6 * bate))))
            t.blit(spr, spr.get_rect(center=(int(sx), int(sy))))

    def _barco_desenho(self):
        if self.arte.ok and self.arte.get("barco_base", h=round(BARCO_TELA_H * ESCALA_BARCO)) is not None:
            self._barco_desenho_sprite()
        else:
            self._barco_desenho_codigo()

    def _barco_desenho_sprite(self):
        """Barco da arte nova: o sprite (proa para cima, com o remador) gira para o rumo; a vela, o leme,
        a rede, a lente, os remos longos e os respingos continuam sendo desenhados por cima por código."""
        b = self.barco
        t = self.tela
        K = ESCALA_BARCO
        M = self.arte.meta["barco"]
        sx = b.x - self.cx
        altura, inclinacao = self.efeitos.pose(b, self.tempestade)
        sy = b.y - self.cy + altura
        ang = b.ang + inclinacao
        remos = self.arte.meta.get("remos") if self.arte.ok else None
        remos_ok = bool(remos) and self.arte.get("remo_esq") is not None and self.arte.get("remo_dir") is not None
        golpe = self._remada(b)                                    # (arrasto 0 a 1, avanço -1 a 1, esforço 0 a 1)
        if remos_ok and golpe[2] > 0.01:
            avanco = golpe[1] * golpe[2] * 1.8                     # o barco dá uma "puxada" a cada remada
            sx += math.cos(ang) * avanco
            sy += math.sin(ang) * avanco
            ang += math.sin(self.remo_fase) * 0.035 * golpe[2]      # e balança de proa a cada lado
        self.ang_barco = ang
        cy_s = M["h"] / 2.0
        luz_x = (cy_s - M["lanterna"][1]) * K                     # a lanterna na proa, em px da tela
        pa_x = (cy_s - M["pa_esq"][1]) * K                         # pás dos remos: x local (negativo = atrás do centro)
        pa_y = (M["pa_dir"][0] - M["pa_esq"][0]) * K / 2.0

        casco = [(44, 0), (38, -7), (27, -14), (10, -18), (-12, -19), (-29, -16), (-38, -8), (-40, 0),
                 (-38, 8), (-29, 16), (-12, 19), (10, 18), (27, 14), (38, 7)]
        v = limitar(b.vel / 140.0, 0, 1)
        if v > 0.15:                                               # marola de proa
            for lado in (-1, 1):
                pts = girar([(42, 0), (26, lado * 17), (4, lado * 31), (-22, lado * 45)], ang, sx, sy)
                pygame.draw.lines(t, misturar(self.cor_agua, BRANCO, 0.55 * v), False, pts, 2)
        self._sombra_poligono(casco, ang, sx, sy, 7, 9, 80)

        if self.tem("leme"):                                       # leme de popa, por baixo do casco
            r = -b.timao * 0.55
            rudder = [(0, -3), (-10, -4.5), (-15, 0), (-10, 4.5), (0, 3)]
            pts = [(-40 + x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)) for x, y in rudder]
            pygame.draw.polygon(t, (30, 38, 50), girar(pts, ang, sx, sy))
            pygame.draw.polygon(t, (112, 124, 140), girar(pts, ang, sx, sy, 0.8))

        if self.tem("casco"):
            chave = "barco_ferro"
        elif self.casco < 55:
            chave = "barco_danificado"
        elif self.lanterna and self.noite_f() > 0.4:
            chave = "barco_lanterna"
        else:
            chave = "barco_base"
        spr = self.arte.get(chave + "_sr", h=round(BARCO_TELA_H * K)) if remos_ok else None
        if spr is None:
            remos_ok = False
            spr = self.arte.get(chave, h=round(BARCO_TELA_H * K))
        rot = girar_spr(spr, ang)
        t.blit(rot, rot.get_rect(center=(round(sx), round(sy))))
        if remos_ok:
            self._remos_desenho(remos, M, K, sx, sy, ang, golpe)

        if self.tem("rede"):                                       # rede de pesca dobrada na proa, à esquerda
            rede = [(6, -17), (18, -17), (20, -9), (8, -9)]
            pygame.draw.polygon(t, (206, 198, 164), girar(rede, ang, sx, sy))
            for i in range(1, 4):
                f = i / 4.0
                a1 = girar([(6 + 12 * f, -17), (8 + 12 * f, -9)], ang, sx, sy)
                pygame.draw.line(t, (104, 98, 76), a1[0], a1[1], 1)
            for yy in (-15, -13, -11):
                a2 = girar([(7, yy), (19, yy)], ang, sx, sy)
                pygame.draw.line(t, (104, 98, 76), a2[0], a2[1], 1)
            pygame.draw.polygon(t, (70, 64, 48), girar(rede, ang, sx, sy), 1)
        if self.tem("remos") and not remos_ok:                     # remos longos: o cabo e a pá passam do sprite
            for lado in (-1, 1):
                ini = girar([(pa_x, lado * pa_y)], ang, sx, sy)[0]
                fim = girar([(pa_x - 11, lado * (pa_y + 13))], ang, sx, sy)[0]
                pygame.draw.line(t, (70, 44, 24), ini, fim, 5)
                pygame.draw.line(t, (226, 192, 134), ini, fim, 3)
                pygame.draw.circle(t, (70, 44, 24), (int(fim[0]), int(fim[1])), 6)
                pygame.draw.circle(t, (200, 160, 100), (int(fim[0]), int(fim[1])), 4)
        if b.remando and not remos_ok:                             # respingos na pá a cada remada
            ciclo = math.sin(self.anim * 7)
            ext = 12 if self.tem("remos") else 0
            for lado in (-1, 1):
                p2 = girar([(pa_x - ext * 0.9, lado * (pa_y + ext))], ang, sx, sy)[0]
                if ciclo > 0.3:
                    pygame.draw.circle(t, BRANCO, (int(p2[0]), int(p2[1])), int(6 + ciclo * 5), 1)
                    pygame.draw.circle(t, misturar(BRANCO, self.cor_agua, 0.4), (int(p2[0]), int(p2[1])),
                                       int(3 + ciclo * 3), 1)

        # vela: o mastro fica na proa, à frente do remador
        mastro = (16, 0)
        if b.vela:
            rel = dif_ang(b.ang, self.vento_ang)
            lado = 1 if math.sin(rel) >= 0 else -1
            tremula = math.sin(self.efeitos.tempo * 6.5) * .035 + math.sin(self.efeitos.tempo * 11) * .012
            abre = limitar(abs(math.sin(rel)) * 0.9 + 0.2 + tremula * (1 + self.tempestade), 0.2, 1.1)
            larg = 46 if self.tem("vela") else 38               # vela grande é ~20% maior
            fim = (mastro[0] - larg * math.cos(abre), lado * larg * math.sin(abre))
            bojo = ((mastro[0] + fim[0]) / 2, fim[1] / 2 + lado * 8)
            pts = girar([mastro, bojo, fim], ang, sx, sy)
            self._sombra_poligono([mastro, bojo, fim], ang, sx, sy, 6, 8, 55)
            pygame.draw.polygon(t, (240, 230, 200), pts)
            sombra_vela = girar([mastro, ((mastro[0] + bojo[0]) / 2, bojo[1] * 0.7), bojo], ang, sx, sy)
            pygame.draw.polygon(t, (212, 198, 164), sombra_vela)
            pygame.draw.polygon(t, (92, 62, 36), pts, 2)
            costura = girar([mastro, (bojo[0], bojo[1] * 0.55 + fim[1] * 0.2)], ang, sx, sy)
            pygame.draw.line(t, (176, 160, 124), costura[0], costura[1], 1)
        else:
            pygame.draw.line(t, (92, 62, 36), girar([mastro], ang, sx, sy)[0], girar([(-22, 0)], ang, sx, sy)[0], 5)
            pygame.draw.line(t, (230, 218, 186), girar([mastro], ang, sx, sy)[0], girar([(-22, 0)], ang, sx, sy)[0], 3)
        m = girar([mastro], ang, sx, sy)[0]
        pygame.draw.circle(t, (60, 38, 22), (int(m[0]), int(m[1])), 5)
        pygame.draw.circle(t, (118, 80, 46), (int(m[0]), int(m[1])), 3)
        if self.tem("vela"):                                       # flâmula vermelha, balançando a favor do vento
            va = self.vento_ang + math.sin(self.anim * 6) * 0.25
            comp = 15 + 2 * math.sin(self.anim * 9)
            ponta = (m[0] + math.cos(va) * comp, m[1] + math.sin(va) * comp)
            lado_x, lado_y = -math.sin(va) * 3.4, math.cos(va) * 3.4
            bandeira = [(m[0] + lado_x, m[1] + lado_y), ponta, (m[0] - lado_x, m[1] - lado_y)]
            pygame.draw.polygon(t, (222, 62, 56), bandeira)
            pygame.draw.polygon(t, (120, 24, 24), bandeira, 1)

        # lanterna na proa (a do sprite está acesa; apagada, ganha uma tampa escura)
        lp = girar([(luz_x, 0)], ang, sx, sy)[0]
        self.pos_lanterna = lp
        if not self.lanterna:
            pygame.draw.circle(t, (46, 34, 22), (int(lp[0]), int(lp[1])), 6)
            pygame.draw.circle(t, (96, 82, 62), (int(lp[0]), int(lp[1])), 3)
        if self.tem("lente"):
            pygame.draw.circle(t, (170, 214, 255), (int(lp[0]), int(lp[1])), 8, 1)
            pygame.draw.circle(t, (226, 242, 255), (int(lp[0]) - 2, int(lp[1]) - 2), 1)

        if self.remo_anim > 0:                                     # golpe de remo
            frac = 1 - self.remo_anim / 0.25
            a = -0.9 + 1.8 * frac
            p1 = girar([(6, 0)], ang, sx, sy)[0]
            p2 = girar([(math.cos(a) * 85, math.sin(a) * 85)], ang, sx, sy)[0]
            pygame.draw.line(t, (130, 88, 48), p1, p2, 5)
            for k in range(4):
                ak = a - k * 0.22
                pk = girar([(math.cos(ak) * 85, math.sin(ak) * 85)], ang, sx, sy)[0]
                pygame.draw.circle(t, BRANCO, (int(pk[0]), int(pk[1])), max(1, 7 - k * 2), 1)

        if self.pesca_prog > 0:
            pygame.draw.rect(t, (20, 24, 30), (sx - 32, sy - 62, 64, 9), border_radius=4)
            pygame.draw.rect(t, VERDE, (sx - 31, sy - 61, 62 * self.pesca_prog, 7), border_radius=3)
        elif self.cardume_perto is not None:
            self._texto("Segure F para pescar", self.f_pq, BRANCO, sx, sy - 66, centro=True)

    # remada: ângulos do remo esquerdo em relação à posição do sprite (graus, sentido horário; o direito é o espelho)
    REMO_ENTRA, REMO_SAI, REMO_REPOUSO = 24.0, -16.0, 4.0

    def _remada(self, b):
        """Avança a remada (uma vez por quadro) e devolve (arrasto, avanço, esforço):
        arrasto = 0 no começo da puxada e 1 no fim, avanço = quanto o barco é puxado, esforço = 0 a 1."""
        self.remo_amp = self.efeitos.esforco
        self.remo_fase = (self.efeitos.ciclo % 1.0) * math.tau
        c = self.remo_fase / math.tau                              # 0 a 1 no ciclo
        if c < 0.58:                                               # puxada: a pá na água, devagar no começo e no fim
            u = c / 0.58
            arrasto = u * u * (3 - 2 * u)
            avanco = math.sin(math.pi * u)
        else:                                                      # volta: a pá fora d'água, mais rápida
            u = (c - 0.58) / 0.42
            arrasto = 1.0 - u * u * (3 - 2 * u)
            avanco = -0.25 * math.sin(math.pi * u)
        return arrasto, avanco, self.remo_amp

    def _remos_desenho(self, remos, M, K, sx, sy, ang, golpe):
        """Os dois remos, recortados do sprite do barco, giram no toleteiro. Parados, balançam com a água;
        remando, vão da entrada (pá à frente) ao fim da puxada (pá atrás) e deixam espuma onde a pá toca."""
        t = self.tela
        arrasto, _, esforco = golpe
        esc = 1.3 if self.tem("remos") else 1.0                   # remos longos: 30% maiores
        cy_s = M["h"] / 2.0
        phi = ang + math.pi / 2
        for lado, sinal in (("esq", 1), ("dir", -1)):
            R = remos[lado]
            ocioso = math.sin(self.anim * 1.7 + (0.0 if lado == "esq" else 1.3)) * 1.8 * (1 + self.tempestade * 2)
            puxada = self.REMO_ENTRA + (self.REMO_SAI - self.REMO_ENTRA) * arrasto
            graus = (self.REMO_REPOUSO + ocioso) * (1 - esforco) + puxada * esforco
            theta = math.radians(graus) * sinal
            k = K * esc
            W = max(4, round(R["w"] * k))
            kk = W / R["w"]
            px, py = R["pivo"]
            vx, vy = (px - M["w"] / 2.0) * K, (py - cy_s) * K        # pivô em relação ao centro do barco
            Sx = sx + vx * math.cos(phi) - vy * math.sin(phi)
            Sy = sy + vx * math.sin(phi) + vy * math.cos(phi)
            dx, dy = (R["w"] / 2.0 - R["pivo_img"][0]) * kk, (R["h"] / 2.0 - R["pivo_img"][1]) * kk
            tot = phi + theta
            Cx = Sx + dx * math.cos(tot) - dy * math.sin(tot)
            Cy = Sy + dx * math.sin(tot) + dy * math.cos(tot)
            if esforco > 0.3 and self.remo_fase / math.tau < 0.58:      # pá na água: anéis de espuma, por baixo do remo
                tx, ty = (R["ponta"][0] - px) * kk, (R["ponta"][1] - py) * kk
                Px = Sx + tx * math.cos(tot) - ty * math.sin(tot)
                Py = Sy + tx * math.sin(tot) + ty * math.cos(tot)
                f = (self.remo_fase / math.tau) / 0.58
                esp = misturar(BRANCO, self.cor_agua, 0.15 + 0.55 * f)
                pygame.draw.circle(t, esp, (int(Px), int(Py)), int(5 + f * 11), 1)
                pygame.draw.circle(t, misturar(esp, self.cor_agua, 0.5), (int(Px), int(Py)), int(2 + f * 6), 1)
            spr = self.arte.rot(R["arq"], -math.degrees(tot), passo=2, w=W)
            if spr is None:
                continue
            t.blit(spr, spr.get_rect(center=(round(Cx), round(Cy))))

    def _barco_desenho_codigo(self):
        b = self.barco
        t = self.tela
        sx = b.x - self.cx
        altura, inclinacao = self.efeitos.pose(b, self.tempestade)
        sy = b.y - self.cy + altura
        ang = b.ang + inclinacao
        self.ang_barco = ang

        casco = [(36, 0), (31, -6), (22, -11.5), (8, -15), (-10, -16), (-24, -13), (-31, -7), (-33, 0),
                 (-31, 7), (-24, 13), (-10, 16), (8, 15), (22, 11.5), (31, 6)]

        # marola de proa (V de espuma) e sombra
        v = limitar(b.vel / 140.0, 0, 1)
        if v > 0.15:
            for lado in (-1, 1):
                pts = girar([(34, 0), (20, lado * 14), (2, lado * 26), (-18, lado * 38)], ang, sx, sy)
                pygame.draw.lines(t, misturar(self.cor_agua, BRANCO, 0.55 * v), False, pts, 2)
        self._sombra_poligono(casco, ang, sx, sy, 7, 9, 80)

        if self.tem("leme"):            # leme de popa (por baixo do casco): gira para o lado em que o barco vira
            r = -b.timao * 0.55
            rudder = [(0, -2.4), (-8, -3.6), (-12, 0), (-8, 3.6), (0, 2.4)]
            pts = [(-31 + x * math.cos(r) - y * math.sin(r), x * math.sin(r) + y * math.cos(r)) for x, y in rudder]
            pygame.draw.polygon(t, (30, 38, 50), girar(pts, ang, sx, sy))
            pygame.draw.polygon(t, (112, 124, 140), girar(pts, ang, sx, sy, 0.8))

        cor = misturar((158, 104, 60), (96, 64, 44), 1 - self.casco / 100)
        pygame.draw.polygon(t, (86, 54, 32), girar(casco, ang, sx, sy))
        pygame.draw.polygon(t, cor, girar(casco, ang, sx, sy, 0.93))
        pygame.draw.polygon(t, (200, 154, 104), girar(casco, ang, sx, sy, 0.78))
        for yy in (-7, -3.5, 0, 3.5, 7):  # tábuas do convés
            lim = 22 - abs(yy) * 1.6
            g = girar([(-lim, yy), (lim, yy)], ang, sx, sy)
            pygame.draw.line(t, (156, 112, 70), g[0], g[1], 1)
        for xb in (-14, -2, 10):  # bancos
            a1, a2 = girar([(xb, -9.5)], ang, sx, sy)[0], girar([(xb, 9.5)], ang, sx, sy)[0]
            pygame.draw.line(t, (138, 94, 56), a1, a2, 4)
            b1, b2 = girar([(xb + 1, -8.5)], ang, sx, sy)[0], girar([(xb + 1, 8.5)], ang, sx, sy)[0]
            pygame.draw.line(t, (190, 144, 96), b1, b2, 1)
        # caixote na popa e rolo de corda
        caixa = girar([(-27, -5.5), (-17, -5.5), (-17, 5.5), (-27, 5.5)], ang, sx, sy)
        pygame.draw.polygon(t, (168, 118, 68), caixa)
        pygame.draw.polygon(t, (96, 62, 34), caixa, 2)
        pygame.draw.line(t, (120, 80, 44), caixa[0], caixa[2], 1)
        pygame.draw.line(t, (120, 80, 44), caixa[1], caixa[3], 1)
        corda = girar([(7, 7)], ang, sx, sy)[0]
        pygame.draw.circle(t, (222, 204, 160), (int(corda[0]), int(corda[1])), 4, 2)
        # melhorias que aparecem no casco
        if self.tem("casco"):           # borda e proa de ferro, com rebites
            pygame.draw.polygon(t, (118, 130, 148), girar(casco, ang, sx, sy, 0.96), 2)
            pygame.draw.polygon(t, (40, 48, 60), girar(casco, ang, sx, sy), 1)
            for px, py in casco[1::2]:
                rb = girar([(px * 0.9, py * 0.9)], ang, sx, sy)[0]
                pygame.draw.circle(t, (214, 222, 234), (int(rb[0]), int(rb[1])), 1)
            proa = girar([(37, 0), (30, -6), (24, 0), (30, 6)], ang, sx, sy)
            pygame.draw.polygon(t, (150, 162, 180), proa)
            pygame.draw.polygon(t, (40, 48, 60), proa, 1)
        if self.tem("rede"):            # rede de pesca dobrada no convés
            rede = [(-14, -12.5), (-5, -12.5), (-4, -8), (-13, -8)]
            pygame.draw.polygon(t, (196, 190, 160), girar(rede, ang, sx, sy))
            for i in range(1, 4):
                f = i / 4.0
                a1 = girar([(-14 + 9 * f, -12.5), (-13 + 9 * f, -8)], ang, sx, sy)
                pygame.draw.line(t, (104, 98, 76), a1[0], a1[1], 1)
            for yy in (-11.4, -10.2, -9.0):
                a2 = girar([(-14, yy), (-4.5, yy)], ang, sx, sy)
                pygame.draw.line(t, (104, 98, 76), a2[0], a2[1], 1)
            pygame.draw.polygon(t, (96, 90, 70), girar(rede, ang, sx, sy), 1)
        if self.tem("remos") and not b.remando:     # remos longos guardados ao longo da borda
            for lado in (-1, 1):
                ini, fim = girar([(-17, lado * 14.4), (15, lado * 14.4)], ang, sx, sy)
                pygame.draw.line(t, (226, 192, 134), ini, fim, 2)
                pa = girar([(15, lado * 13.2), (22, lado * 13.2), (22, lado * 15.8), (15, lado * 15.8)], ang, sx, sy)
                pygame.draw.polygon(t, (170, 128, 76), pa)
                pygame.draw.polygon(t, (86, 56, 30), pa, 1)
        # rachaduras conforme o dano
        if self.casco < 65:
            rachaduras = [[(-6, -13), (-2, -9), (-5, -6)], [(12, 12), (8, 8), (10, 5)],
                          [(-22, 10), (-18, 6), (-20, 3)]]
            for r in rachaduras[:int((65 - self.casco) / 15) + 1]:
                pygame.draw.lines(t, (40, 24, 14), False, girar(r, ang, sx, sy), 2)

        # remos de propulsão
        if b.remando:
            ciclo = math.sin(self.anim * 7)
            longo = self.tem("remos")
            for lado in (-1, 1):
                p1 = girar([(4, lado * 13)], ang, sx, sy)[0]
                p2 = girar([((4 + (20 if longo else 16) * ciclo), lado * (48 if longo else 40))], ang, sx, sy)[0]
                pygame.draw.line(t, (226, 192, 134) if longo else (118, 80, 44), p1, p2, 3)
                pygame.draw.circle(t, (170, 128, 76) if longo else (152, 108, 62), (int(p2[0]), int(p2[1])),
                                   6 if longo else 5)
                pygame.draw.circle(t, (96, 64, 36), (int(p2[0]), int(p2[1])), 6 if longo else 5, 1)
                if ciclo > 0.3:
                    pygame.draw.circle(t, BRANCO, (int(p2[0]), int(p2[1])), int(6 + ciclo * 4), 1)

        # vela
        mastro = (4, 0)
        if b.vela:
            rel = dif_ang(b.ang, self.vento_ang)
            lado = 1 if math.sin(rel) >= 0 else -1
            tremula = math.sin(self.efeitos.tempo * 6.5) * .035 + math.sin(self.efeitos.tempo * 11) * .012
            abre = limitar(abs(math.sin(rel)) * 0.9 + 0.2 + tremula * (1 + self.tempestade), 0.2, 1.1)
            larg = 34 if self.tem("vela") else 28           # vela grande é ~20% maior
            fim = (4 - larg * math.cos(abre), lado * larg * math.sin(abre))
            bojo = ((4 + fim[0]) / 2, fim[1] / 2 + lado * 7)
            pts = girar([mastro, bojo, fim], ang, sx, sy)
            self._sombra_poligono([mastro, bojo, fim], ang, sx, sy, 6, 8, 55)
            pygame.draw.polygon(t, (244, 242, 232), pts)
            sombra_vela = girar([mastro, ((4 + bojo[0]) / 2, bojo[1] * 0.7), bojo], ang, sx, sy)
            pygame.draw.polygon(t, (210, 208, 198), sombra_vela)
            pygame.draw.polygon(t, (150, 150, 150), pts, 1)
            costura = girar([mastro, (bojo[0], bojo[1] * 0.55 + fim[1] * 0.2)], ang, sx, sy)
            pygame.draw.line(t, (190, 190, 184), costura[0], costura[1], 1)
        else:
            pygame.draw.line(t, (225, 220, 205), girar([mastro], ang, sx, sy)[0],
                             girar([(-20, 0)], ang, sx, sy)[0], 3)
        m = girar([mastro], ang, sx, sy)[0]
        pygame.draw.circle(t, (60, 38, 22), (int(m[0]), int(m[1])), 5)
        pygame.draw.circle(t, (118, 80, 46), (int(m[0]), int(m[1])), 3)
        if self.tem("vela"):            # flâmula vermelha no topo do mastro, balançando a favor do vento
            va = self.vento_ang + math.sin(self.anim * 6) * 0.25
            comp = 14 + 2 * math.sin(self.anim * 9)
            ponta = (m[0] + math.cos(va) * comp, m[1] + math.sin(va) * comp)
            lado_x, lado_y = -math.sin(va) * 3.2, math.cos(va) * 3.2
            bandeira = [(m[0] + lado_x, m[1] + lado_y), ponta, (m[0] - lado_x, m[1] - lado_y)]
            pygame.draw.polygon(t, (222, 62, 56), bandeira)
            pygame.draw.polygon(t, (120, 24, 24), bandeira, 1)

        # lanterna na proa
        lp = girar([(27, 0)], ang, sx, sy)[0]
        self.pos_lanterna = lp
        pygame.draw.circle(t, (60, 42, 26), (int(lp[0]), int(lp[1])), 5)
        if self.lanterna:
            pygame.draw.circle(t, (255, 232, 160), (int(lp[0]), int(lp[1])), 3)
            pygame.draw.circle(t, (255, 252, 220), (int(lp[0]), int(lp[1])), 1)
        else:
            pygame.draw.circle(t, (110, 92, 66), (int(lp[0]), int(lp[1])), 3)
        if self.tem("lente"):           # aro azulado da lente em volta da chama
            pygame.draw.circle(t, (170, 214, 255), (int(lp[0]), int(lp[1])), 6, 1)
            pygame.draw.circle(t, (226, 242, 255), (int(lp[0]) - 2, int(lp[1]) - 2), 1)

        # golpe de remo
        if self.remo_anim > 0:
            frac = 1 - self.remo_anim / 0.25
            a = -0.9 + 1.8 * frac
            p1 = girar([(6, 0)], ang, sx, sy)[0]
            p2 = girar([(math.cos(a) * 85, math.sin(a) * 85)], ang, sx, sy)[0]
            pygame.draw.line(t, (130, 88, 48), p1, p2, 5)
            for k in range(4):  # respingos no arco do golpe
                ak = a - k * 0.22
                pk = girar([(math.cos(ak) * 85, math.sin(ak) * 85)], ang, sx, sy)[0]
                pygame.draw.circle(t, BRANCO, (int(pk[0]), int(pk[1])), max(1, 7 - k * 2), 1)

        # indicadores sobre o barco
        if self.pesca_prog > 0:
            pygame.draw.rect(t, (20, 24, 30), (sx - 32, sy - 52, 64, 9), border_radius=4)
            pygame.draw.rect(t, VERDE, (sx - 31, sy - 51, 62 * self.pesca_prog, 7), border_radius=3)
        elif self.cardume_perto is not None:
            self._texto("Segure F para pescar", self.f_pq, BRANCO, sx, sy - 56, centro=True)

    # --------------------------------------------------------------- iluminação
    def _blit_feixe(self, alvo, surf, px, py, ang, alpha=None):
        graus = round(-math.degrees(ang))  # passos de 1° para reaproveitar rotações já feitas
        chave = (id(surf), graus)
        rot = self._cache_feixe.get(chave)
        if rot is None:
            if len(self._cache_feixe) > 24:
                self._cache_feixe.clear()
            rot = pygame.transform.rotate(surf, graus)
            self._cache_feixe[chave] = rot
        if alpha is not None:
            rot.set_alpha(alpha)
        w = surf.get_width()
        cx = px + math.cos(ang) * w / 2
        cy = py + math.sin(ang) * w / 2
        return rot, (int(cx - rot.get_width() / 2), int(cy - rot.get_height() / 2))

    def _iluminacao(self):
        t = self.tela
        br = self.brilho()
        noite = limitar((1 - br) / 0.88, 0, 1)
        storm = self.tempestade

        # tom quente no amanhecer e no entardecer; clarão dos relâmpagos
        frac = fase_do_dia(self.t)
        s = math.sin(math.tau * (frac - 0.25))
        tw = max(0.0, 1 - abs(s) / 0.28) * (1 - storm)
        if tw > 0.03:
            self._tintar((int(64 * tw), int(26 * tw), 0), pygame.BLEND_RGB_ADD)
        if self.flash > 0:
            v = int(110 * self.flash)
            self._tintar((v, v, v), pygame.BLEND_RGB_ADD)

        # camada de escuridão (noite + tempestade + vinheta nas bordas)
        alpha = int(min(215, 200 * noite + 100 * storm * (1 - 0.5 * noite)))
        cor = misturar((6, 10, 34), (24, 32, 42), storm * (1 - noite))
        esc = self.escuro
        if alpha > 0:
            esc.fill((cor[0], cor[1], cor[2], alpha))
        fe = alpha / 215.0  # quanto está escuro (0 a 1)

        brilhos = []  # brilhos aditivos que vão por cima da cena, antes da escuridão
        if fe > 0.06:
            # itens brilhando de leve para dar para achá-los no escuro
            for it in self.itens:
                ix = it.x - self.cx
                iy = it.y - self.cy
                if it.tipo == "bau":                # o baú dourado brilha mais forte
                    if -130 < ix < LARGURA + 130 and -130 < iy < ALTURA + 130:
                        esc.blit(self.bau_sub, (int(ix) - 120, int(iy) - 120), special_flags=pygame.BLEND_RGBA_SUB)
                        self.bau_glow.set_alpha(int(255 * fe))
                        brilhos.append((self.bau_glow, (int(ix) - 120, int(iy) - 120)))
                elif -40 < ix < LARGURA + 40 and -40 < iy < ALTURA + 40:
                    esc.blit(self.item_sub, (int(ix) - 30, int(iy) - 30), special_flags=pygame.BLEND_RGBA_SUB)
                    self.item_glow.set_alpha(int(255 * fe))
                    brilhos.append((self.item_glow, (int(ix) - 30, int(iy) - 30)))

        # lanterna do barco: halo, feixe à frente e brilho nas ondas (a lente alonga o feixe e alarga o halo)
        if self.lanterna:
            lx, ly = self.pos_lanterna
            if self.tem("lente"):
                if self.lente is None:
                    self.lente = self._criar_lente()
                luz_sub, luz_glow, feixe_sub, feixe_glow = self.lente
            else:
                luz_sub, luz_glow, feixe_sub, feixe_glow = self.luz_sub, self.luz_glow, self.feixe_sub, self.feixe_glow
            n = len(luz_sub)
            osc = 0.5 + 0.25 * math.sin(self.anim * 9.0) + 0.25 * math.sin(self.anim * 14.3 + 1.7)
            i = min(n - 1, int(osc * n))
            m = luz_sub[i]
            r = m.get_width() // 2
            if fe > 0.04:
                esc.blit(m, (int(lx) - r, int(ly) - r), special_flags=pygame.BLEND_RGBA_SUB)
                rot, pos = self._blit_feixe(esc, feixe_sub, lx, ly, self.ang_barco)
                esc.blit(rot, pos, special_flags=pygame.BLEND_RGBA_SUB)
                if not self.leve:   # os brilhos quentes são o que mais pesa; o modo leve dispensa
                    g = luz_glow[i]
                    g.set_alpha(int(255 * fe))
                    rg = g.get_width() // 2
                    brilhos.append((g, (int(lx) - rg, int(ly) - rg)))
                    rot2, pos2 = self._blit_feixe(t, feixe_glow, lx, ly, self.ang_barco, int(255 * fe))
                    brilhos.append((rot2, pos2))
            self.lamp_glow.set_alpha(int(255 * (0.35 + 0.65 * fe)))
            brilhos.append((self.lamp_glow, (int(lx) - 40, int(ly) - 40)))

        for surf, pos in brilhos:
            t.blit(surf, pos)
        if alpha > 0:
            t.blit(esc, (0, 0))
        if not self.leve:
            t.blit(self.vinheta, (0, 0))

    # ------------------------------------------------------------------ horror
    def _vultos_desenho(self):
        """Silhuetas colossais sob a água: massa escura com franja mais clara."""
        t = self.tela
        for v in self.vultos:
            if v.vis < 0.02:
                continue
            sx, sy = v.x - self.cx, v.y - self.cy
            if not (-560 < sx < LARGURA + 560 and -560 < sy < ALTURA + 560):
                v.pts_tent = []
                continue
            if self._vulto_sprite(v, sx, sy):
                continue
            v.olhos_tela = []
            c1 = misturar(self.cor_agua, (0, 4, 12), 0.40 * v.vis)
            c2 = misturar(self.cor_agua, (0, 4, 12), 0.74 * v.vis)
            tam, fase = v.tam, v.fase
            formas, brilhos = [], []
            for i, (a0, comp, ph) in enumerate(v.tent):
                ang = v.ang + a0 + math.sin(fase * 0.8 + ph) * 0.25
                curva = math.sin(ph + fase * 0.5) * 1.1
                n = 10
                seg = comp * tam * 0.9 / n
                x = sx + math.cos(ang) * 50 * tam
                y = sy + math.sin(ang) * 50 * tam
                e1, d1, e2, d2 = [], [], [], []
                for k in range(n + 1):
                    s = k / n
                    th = ang + curva * s + math.sin(fase * 1.6 - s * 5 + ph) * s * 0.9
                    w = 17 * tam * (1 - s) + 2
                    w2 = w * 1.45 + 3
                    nx, ny = -math.sin(th), math.cos(th)
                    e1.append((x + nx * w, y + ny * w))
                    d1.append((x - nx * w, y - ny * w))
                    e2.append((x + nx * w2, y + ny * w2))
                    d2.append((x - nx * w2, y - ny * w2))
                    if k in (3, 6, 9):
                        brilhos.append((x, y, i + k))
                    x += math.cos(th) * seg
                    y += math.sin(th) * seg
                d1.reverse()
                d2.reverse()
                formas.append((e2 + d2, e1 + d1))
            v.pts_tent = brilhos
            blob = []
            for j in range(16):
                a = j * math.tau / 16
                r = 62 * tam * (1 + 0.12 * math.sin(3 * a + fase) + 0.08 * math.sin(5 * a - fase * 1.3))
                blob.append((v.ang + a, r))
            # primeiro a franja de todos, depois o miolo
            for franja, _ in formas:
                pygame.draw.polygon(t, c1, franja)
            pygame.draw.polygon(t, c1, [(sx + math.cos(a) * r * 1.18, sy + math.sin(a) * r * 1.18)
                                        for a, r in blob])
            for _, miolo in formas:
                pygame.draw.polygon(t, c2, miolo)
            pygame.draw.polygon(t, c2, [(sx + math.cos(a) * r, sy + math.sin(a) * r) for a, r in blob])

    ESCALA_VULTO = 1.25

    def _vulto_sprite(self, v, sx, sy):
        """O gigante da arte nova: o sprite escurecido e translúcido, girado para o rumo dele. Deixa em
        v.olhos_tela e v.pts_tent os olhos e os brilhos já na tela, para o _horror_overlay usar."""
        nome = "vulto_a" if v.var == 0 else "vulto_b"
        M = self.arte.meta.get(nome) if self.arte.ok else None
        if not M:
            return False
        K = round(self.ESCALA_VULTO * v.tam / 0.05) * 0.05
        chave = ("vulto", nome, round(K, 2))
        base = self.arte.cache.get(chave)
        if base is None:
            raw = self.arte._ler(nome)
            if raw is None:
                return False
            base = pygame.transform.smoothscale(raw, (max(8, int(raw.get_width() * K)), max(8, int(raw.get_height() * K))))
            base.fill((50, 44, 78, 255), special_flags=pygame.BLEND_RGBA_MULT)      # silhueta escura sob a água
            self.arte.cache[chave] = base
        frames_chave=("vulto_respira",nome,round(K,2))
        frames=self.arte.cache.get(frames_chave)
        if frames is None:
            frames=[]
            for q in range(16):
                ff=pygame.Surface(base.get_size(),pygame.SRCALPHA)
                for yy in range(0,base.get_height(),2):
                    dx=round(math.sin(yy*.035-q*math.tau/16)*3)
                    ff.blit(base,(dx,yy),(0,yy,base.get_width(),2))
                frames.append(ff)
            self.arte.cache[frames_chave]=frames
        quadro=int(self.anim*12+v.fase)%16
        base=frames[quadro]
        graus = -math.degrees(v.ang) + 5.0 * math.sin(self.anim * 0.8 + v.fase) + 3.0 * math.sin(self.anim * 1.9 + v.fase * 2)
        c = getattr(v, "_rot", None)
        if c is None or getattr(v,"_quadro",-1)!=quadro or abs(dif_ang(c[0], math.radians(graus))) > math.radians(2.5):   # só gira de novo se mudou o rumo
            c = (math.radians(graus), pygame.transform.rotozoom(base, graus, 1.0))
            v._rot = c
            v._quadro = quadro
        spr = c[1]
        spr.set_alpha(int(215 * v.vis))
        self.tela.blit(spr, spr.get_rect(center=(int(sx), int(sy))))
        ang = -math.radians(graus)
        v.olhos_tela = []
        for i, (dx, dy, r, ci) in enumerate(M["olhos"]):
            p = girar([(dx * K, dy * K)], ang, sx, sy)[0]
            v.olhos_tela.append((p[0], p[1], r * K * 0.55, i * 0.9, int(ci)))
        v.pts_tent = []
        for i, (dx, dy) in enumerate(M["brilhos"]):
            p = girar([(dx * K, dy * K)], ang, sx, sy)[0]
            v.pts_tent.append((p[0], p[1], i))
        return True

    def _tentaculos_desenho(self):
        """Tentáculos que rompem a superfície, por cima do barco."""
        t = self.tela
        esp = misturar(self.cor_agua, BRANCO, 0.45)
        sombra = misturar(self.cor_agua, (0, 10, 25), 0.5)
        if self.arte.ok:
            corpo, borda, luz, ventosa = (120, 50, 130), (40, 15, 50), (176, 96, 170), (224, 140, 168)
        else:
            corpo, borda, luz, ventosa = (52, 40, 80), (16, 10, 30), (118, 100, 158), (190, 176, 214)
        for tn in self.tentaculos:
            bx0, by0 = tn.x - self.cx, tn.y - self.cy
            tx, ty = tn.ponta[0] - self.cx, tn.ponta[1] - self.cy
            if not (-350 < bx0 < LARGURA + 350 and -350 < by0 < ALTURA + 350):
                tn.pts = []
                continue
            esc = min(1.0, tn.altura * 3.0)
            # ondulações e bolhas na base
            for k in range(3):
                f = (self.anim * 0.8 + tn.fase + k / 3.0) % 1.0
                pygame.draw.circle(t, misturar(esp, self.cor_agua, f), (int(bx0), int(by0)),
                                   int(10 + f * (26 + 20 * tn.altura)), 1 if f > 0.4 else 2)
            for k in range(4):
                a = self.anim * 1.3 + tn.fase + k * 1.57
                f = (self.anim * 0.9 + k * 0.27) % 1.0
                pygame.draw.circle(t, esp, (int(bx0 + math.cos(a) * (18 + 14 * f)),
                                            int(by0 + math.sin(a) * (18 + 14 * f))), 1 + k % 2, 1)
            dx, dy = tx - bx0, ty - by0
            L = math.hypot(dx, dy)
            if L < 3 or esc < 0.05:
                tn.pts = []
                continue
            if tn.estado in ("emergir","pairar","recolher"):
                altura=max(32,min(240,round((L+30)*esc/8)*8))
                spr=self.arte.rot("tentaculo_1",-math.degrees(math.atan2(dy,dx))-90,
                    passo=4,h=altura,onda=(16,3.0,"y","max",1.0),quadro=int(self.anim*18+tn.fase),guardar=False)
                if spr is not None:
                    t.blit(spr,spr.get_rect(center=(round((bx0+tx)/2),round((by0+ty)/2))))
                    tn.pts=[(tx,ty)]
                    continue
            px, py = -dy / L, dx / L
            sway = (math.sin(self.anim * 1.8 + tn.fase) * 0.16 + tn.arco * 0.3) * L
            cxm, cym = (bx0 + tx) / 2 + px * sway, (by0 + ty) / 2 + py * sway
            # no repouso a ponta se enrola; ao golpear ou agarrar, estica até o alvo
            enrola = 1.0 if tn.estado in ("emergir", "pairar", "recolher") else 0.0
            n = 18
            pts, ws = [], []
            for k in range(n + 1):
                s = k / n
                a, m, c = (1 - s) ** 2, 2 * (1 - s) * s, s * s
                ond = math.sin(s * 8 - self.anim * 4.0 + tn.fase) * 24 * s * (1 - s)
                ond += tn.arco * enrola * 46 * s ** 4          # curva da ponta
                along = -enrola * 22 * s ** 5                  # e encolhe um pouco
                pts.append((a * bx0 + m * cxm + c * tx + px * ond + (dx / L) * along,
                            a * by0 + m * cym + c * ty + py * ond + (dy / L) * along))
                ws.append((17 * (1 - s) ** 0.85 + 3.0 * s) * esc)
            e0, d0, e1, d1, luzp, vent = [], [], [], [], [], []
            for k in range(n + 1):
                ax, ay = pts[max(0, k - 1)]
                bx_, by_ = pts[min(n, k + 1)]
                mm = math.hypot(bx_ - ax, by_ - ay) or 1.0
                nx, ny = -(by_ - ay) / mm, (bx_ - ax) / mm
                w = ws[k]
                x, y = pts[k]
                e0.append((x + nx * (w + 2.2), y + ny * (w + 2.2)))
                d0.append((x - nx * (w + 2.2), y - ny * (w + 2.2)))
                e1.append((x + nx * w, y + ny * w))
                d1.append((x - nx * w, y - ny * w))
                luzp.append((x - nx * w * 0.4, y - ny * w * 0.4))
                if k >= 3 and k % 2 == 1 and k < n:
                    vent.append((int(x + nx * w * 0.4), int(y + ny * w * 0.4),
                                 max(1, int(2.8 * (1 - k / n) + 0.8))))
            d0.reverse()
            d1.reverse()
            pygame.draw.polygon(t, sombra, [(x + 6, y + 9) for x, y in e0 + d0])
            pygame.draw.polygon(t, borda, e0 + d0)
            pygame.draw.polygon(t, corpo, e1 + d1)
            pygame.draw.lines(t, luz, False, luzp[1:-1], 2)
            for vx, vy, vr in vent:
                pygame.draw.circle(t, ventosa, (vx, vy), vr)
            xp, yp = pts[-1]
            pygame.draw.circle(t, borda, (int(xp), int(yp)), int(ws[-1]) + 2)
            pygame.draw.circle(t, corpo, (int(xp), int(yp)), max(1, int(ws[-1])))
            tn.pts = [pts[6], pts[11], pts[16]]

            # agarrando: anéis em volta do casco
            if tn.estado == "agarrar":
                esforco = 1 + math.sin(self.anim * 16) * 0.04
                for rx, ry, larg in (((55, 29, 8), (46, 23, 6)) if self.arte.ok else ((44, 23, 7), (37, 18, 5))):
                    anel = girar([(math.cos(a * math.tau / 24) * rx * esforco,
                                   math.sin(a * math.tau / 24) * ry) for a in range(24)],
                                 self.ang_barco, self.bx, self.by)
                    pygame.draw.lines(t, borda, True, anel, larg + 3)
                    pygame.draw.lines(t, corpo, True, anel, larg)
                    pygame.draw.lines(t, luz, True, anel, 1)

    def _olho(self, p, r, ci, abre):
        """Olho brilhante de pupila vertical. 'abre' vai de 0 (fechado) a 1."""
        if abre <= 0.04:
            return
        t = self.tela
        x, y = int(p[0]), int(p[1])
        g = self.glow_olho[ci]
        g.set_alpha(int(235 * abre))
        t.blit(g, (x - 26, y - 26))
        cor = self.cores_olho[ci]
        h = max(1.0, r * abre)
        rect = pygame.Rect(0, 0, max(3, int(r * 3.0)), max(2, int(h * 2)))
        rect.center = (x, y)
        pygame.draw.ellipse(t, misturar(cor, BRANCO, 0.55), rect)
        pygame.draw.ellipse(t, cor, rect, 1)
        pw = max(1, int(r * 0.32))
        ph = max(2, int(h * 1.8))
        pygame.draw.ellipse(t, (6, 4, 12), (x - pw, y - ph // 2, pw * 2, ph))

    def _horror_overlay(self):
        """O que brilha no escuro (depois da camada de escuridão) e os efeitos da loucura."""
        t = self.tela
        anim = self.anim
        nf = self.noite_f()
        fn = limitar((nf - 0.25) / 0.5, 0.0, 1.0)
        L, A = LARGURA, ALTURA

        # bioluminescência roxa nos gigantes e nos tentáculos
        if fn > 0.02:
            g = self.glow_bio
            for v in self.vultos:
                if v.vis < 0.15:
                    continue
                for x, y, idx in v.pts_tent:
                    a = (0.45 + 0.55 * math.sin(anim * 1.7 + idx * 1.3)) * v.vis * fn
                    if a > 0.05 and -40 < x < L + 40 and -40 < y < A + 40:
                        g.set_alpha(int(190 * a))
                        t.blit(g, (int(x) - 36, int(y) - 36))
            for tn in self.tentaculos:
                if tn.altura < 0.1:
                    continue
                bx0, by0 = tn.x - self.cx, tn.y - self.cy
                if not (-60 < bx0 < L + 60 and -60 < by0 < A + 60):
                    continue
                g.set_alpha(int(130 * tn.altura * fn))
                t.blit(g, (int(bx0) - 36, int(by0) - 36))
                for i, (x, y) in enumerate(tn.pts):
                    g.set_alpha(int(210 * tn.altura * fn * (0.5 + 0.5 * math.sin(anim * 3 + i * 2 + tn.fase))))
                    t.blit(g, (int(x) - 36, int(y) - 36))

        # olhos dos gigantes: abrem um a um
        for v in self.vultos:
            if v.vis < 0.45:
                continue
            sx, sy = v.x - self.cx, v.y - self.cy
            if not (-300 < sx < L + 300 and -300 < sy < A + 300):
                continue
            if v.olhos_tela:
                for i, (ex, ey, r, ph, ci) in enumerate(v.olhos_tela):
                    ab = limitar((v.vis - 0.45 - 0.05 * i) * 6, 0.0, 1.0)
                    piscar = max(0.0, (math.sin(anim * 1.3 + ph * 3) - 0.92) / 0.08)
                    self._olho((ex, ey), r, min(ci, len(self.glow_olho) - 1), ab * (1 - piscar))
                continue
            for i, (dx, dy, r, ph, ci) in enumerate(v.olhos):
                ab = limitar((v.vis - 0.45 - 0.05 * i) * 6, 0.0, 1.0)
                piscar = max(0.0, (math.sin(anim * 1.3 + ph * 3) - 0.92) / 0.08)
                p = girar([(dx * v.tam, dy * v.tam)], v.ang, sx, sy)[0]
                self._olho(p, r * v.tam * 1.05, ci, ab * (1 - piscar))

        # pares de olhos no escuro (e os que só existem na cabeça de quem está enlouquecendo)
        for o in self.olhos:
            ab = o.abertura
            if o.falso:
                ab *= 0.7
            else:
                ab *= limitar((nf - 0.1) / 0.3, 0.0, 1.0)
            if ab < 0.04:
                continue
            sx = o.x - self.cx
            sy = o.y - self.cy + math.sin(anim * 0.8 + o.fase) * 3
            if not (-40 < sx < L + 40 and -40 < sy < A + 40):
                continue
            ca, sa = math.cos(o.ang) * o.sep * 0.5, math.sin(o.ang) * o.sep * 0.5
            self._olho((sx - ca, sy - sa), 3.6, o.ci, ab)
            self._olho((sx + ca, sy + sa), 3.6, o.ci, ab)

        # efeitos da loucura: coração disparado, enjoo e visão ondulando
        s = self.sanidade
        if s < 60:
            k = limitar((60 - s) / 60.0, 0.0, 1.0)
            f = self.fase_bat
            lub = max(0.0, math.sin(f)) ** 10
            dub = max(0.0, math.sin(f - 0.9)) ** 10 * 0.6
            forca = k * (0.35 + 0.65 * min(1.0, lub + dub))
            nivel = int(forca * 8.0 + 0.5)
            if nivel > 0:
                t.blit(self.vinheta_sangue[min(7, nivel - 1)], (0, 0))
        if s < 45 and not self.leve:
            k = (45 - s) / 45.0
            self._tintar((int(34 * k), int(6 * k), int(26 * k)), pygame.BLEND_RGB_SUB)
        if s < 30 and not self.leve:
            k = (30 - s) / 30.0
            amp = 1.0 + 5.0 * k
            copia = t.copy()
            for y in range(0, A, 6):
                dx = int(math.sin(anim * 2.5 + y * 0.035) * amp)
                if dx:
                    t.blit(copia, (dx, y), (0, y, L, 6))

    def _clima_overlay(self):
        st = self.tempestade
        if st > 0.02:
            rnd = random.random
            for _ in range(int(170 * st)):
                x = int(rnd() * (LARGURA + 40)) - 40
                y = int(rnd() * ALTURA)
                pygame.draw.line(self.tela, (170, 190, 212), (x, y), (x - 5, y + 12 + int(rnd() * 10)), 1)
            for _ in range(int(26 * st)):
                pygame.draw.circle(self.tela, (118, 142, 164),
                                   (int(rnd() * LARGURA), int(rnd() * ALTURA)), 1 + int(rnd() * 3), 1)

    # ---------------------------------------------------------------------- HUD
    def _texto(self, txt, f, cor, x, y, centro=False, sombra=True):
        img = f.render(txt, True, cor)
        r = img.get_rect()
        if centro:
            r.midtop = (int(x), int(y))
        else:
            r.topleft = (int(x), int(y))
        if sombra:
            s = f.render(txt, True, (0, 0, 0))
            self.tela.blit(s, (r.x + 1, r.y + 1))
        self.tela.blit(img, r)

    def _painel(self, x, y, w, h, alpha=135):
        s = pygame.Surface((w, h), pygame.SRCALPHA, 32)
        fr = self.arte.quadro(int(w), int(h)) if self.arte.ok else None
        if fr is not None:                                       # moldura de madeira da arte nova
            pygame.draw.rect(s, (8, 16, 28, alpha), (3, 3, w - 6, h - 6), border_radius=4)
            s.blit(fr, (0, 0))
        else:
            pygame.draw.rect(s, (8, 16, 28, alpha), (0, 0, w, h), border_radius=10)
            pygame.draw.rect(s, (255, 255, 255, 38), (0, 0, w, h), 1, border_radius=10)
        self.tela.blit(s, (int(x), int(y)))

    ICONE_BARRA = {"vida": "bs_vida", "peixe": "bs_peixe", "gota": "bs_gota", "raio": "bs_raio",
                   "casco": "bs_barco", "olho": "bs_olho", "tabua": "ic_consertar", "lanterna": "ic_lanterna_acesa"}

    def _icone(self, nome, x, y, cor):
        t = self.tela
        if self.arte.ok and nome in self.ICONE_BARRA:
            spr = self.arte.get(self.ICONE_BARRA[nome], fit=(16, 16))
            if spr is not None:
                t.blit(spr, spr.get_rect(center=(x + 7, y + 7)))
                return
        if nome == "vida":
            pygame.draw.circle(t, cor, (x + 4, y + 4), 4)
            pygame.draw.circle(t, cor, (x + 10, y + 4), 4)
            pygame.draw.polygon(t, cor, [(x, y + 6), (x + 14, y + 6), (x + 7, y + 14)])
        elif nome == "peixe":
            pygame.draw.ellipse(t, cor, (x, y + 3, 10, 8))
            pygame.draw.polygon(t, cor, [(x + 9, y + 7), (x + 14, y + 2), (x + 14, y + 12)])
        elif nome == "gota":
            pygame.draw.circle(t, cor, (x + 7, y + 9), 5)
            pygame.draw.polygon(t, cor, [(x + 7, y), (x + 2, y + 8), (x + 12, y + 8)])
        elif nome == "raio":
            pygame.draw.polygon(t, cor, [(x + 8, y), (x + 2, y + 8), (x + 7, y + 8), (x + 5, y + 14),
                                         (x + 12, y + 5), (x + 7, y + 5)])
        elif nome == "casco":
            pygame.draw.polygon(t, cor, [(x, y + 6), (x + 14, y + 6), (x + 11, y + 13), (x + 3, y + 13)])
            pygame.draw.line(t, cor, (x + 7, y), (x + 7, y + 6), 2)
        elif nome == "tabua":
            pygame.draw.rect(t, cor, (x, y + 4, 14, 6))
            pygame.draw.circle(t, (60, 40, 20), (x + 3, y + 7), 1)
        elif nome == "olho":
            pygame.draw.ellipse(t, cor, (x, y + 3, 14, 9), 2)
            pygame.draw.circle(t, cor, (x + 7, y + 7), 3)
        elif nome == "lanterna":
            pygame.draw.rect(t, cor, (x + 3, y + 3, 8, 9), border_radius=2)
            pygame.draw.line(t, cor, (x + 7, y), (x + 7, y + 3), 2)
            pygame.draw.line(t, cor, (x + 3, y + 14), (x + 11, y + 14), 2)

    def _icone_item(self, nome, cx, cy, tam, ativo=True, aceso=True):
        """Ícone grande (32 x 32 unidades, centrado em cx, cy, escalado para 'tam' px) dos itens da base da tela:
        gota (beber), peixe (comer), tábua com martelo (consertar) e lanterna. Sem o item, fica cinza."""
        t = self.tela
        k = tam / 32.0

        def P(x, y):
            return (cx + (x - 16) * k, cy + (y - 16) * k)

        def R(x, y, w, h):
            a = P(x, y)
            return pygame.Rect(round(a[0]), round(a[1]), max(1, round(w * k)), max(1, round(h * k)))

        if self.arte.ok:
            arq = {"gota": "ic_gota", "peixe": "ic_peixe", "tabua": "ic_consertar", "corda": "item_corda",
                   "lanterna": "ic_lanterna_acesa" if aceso else "ic_lanterna_apagada"}.get(nome)
            if arq:
                kw = dict(fit=(round(tam), round(tam)))
                spr = self.arte.get(arq, **kw) if ativo else self.arte.apagado(arq, **kw)
                if spr is not None:
                    t.blit(spr, spr.get_rect(center=(round(cx), round(cy))))
                    return
        cinza = (140, 144, 150)
        esc = (14, 22, 34)
        lw = max(1, round(1.4 * k))
        if nome == "gota":
            c = (72, 160, 236) if ativo else cinza
            claro = misturar(c, BRANCO, 0.55)
            # contorno = a mesma gota um pouco maior, por trás (assim não aparece linha dentro dela)
            pygame.draw.polygon(t, esc, [P(16, -0.4), P(7.2, 15.6), P(24.8, 15.6)])
            pygame.draw.circle(t, esc, P(16, 19.5), 8.5 * k + lw)
            pygame.draw.polygon(t, c, [P(16, 1.5), P(8.57, 15.4), P(23.43, 15.4)])
            pygame.draw.circle(t, c, P(16, 19.5), 8.5 * k)
            pygame.draw.ellipse(t, claro, R(10.6, 16.5, 3.2, 6.2))
        elif nome == "peixe":
            c = (236, 150, 52) if ativo else cinza
            claro = misturar(c, BRANCO, 0.55)
            escuro = misturar(c, (0, 0, 0), 0.35)
            pygame.draw.polygon(t, escuro, [P(21, 16), P(30.5, 7.5), P(30.5, 24.5)])               # cauda
            pygame.draw.polygon(t, escuro, [P(10, 10), P(15, 4), P(19, 10.5)])                     # nadadeira
            pygame.draw.ellipse(t, c, R(2, 9, 21, 14))                                             # corpo
            pygame.draw.ellipse(t, claro, R(5, 17, 15, 4))                                         # barriga
            pygame.draw.ellipse(t, esc, R(2, 9, 21, 14), lw)
            pygame.draw.arc(t, esc, R(11, 10.5, 6, 11), math.pi * 0.55, math.pi * 1.45, lw)        # guelra
            pygame.draw.circle(t, BRANCO, P(7.2, 14.2), 2.2 * k)
            pygame.draw.circle(t, esc, P(7.2, 14.2), 1.2 * k)
        elif nome == "tabua":
            madeira = (190, 138, 78) if ativo else cinza
            veio = misturar(madeira, (0, 0, 0), 0.3)
            ferro = (176, 186, 200) if ativo else (120, 124, 130)
            cabo = (226, 190, 126) if ativo else (150, 152, 156)
            pygame.draw.rect(t, madeira, R(1.5, 21.5, 29, 7.5), border_radius=max(1, round(1.2 * k)))      # tábua
            pygame.draw.rect(t, esc, R(1.5, 21.5, 29, 7.5), lw, border_radius=max(1, round(1.2 * k)))
            pygame.draw.line(t, veio, P(6, 25.2), P(14, 25.2), lw)
            pygame.draw.line(t, veio, P(18, 26.4), P(26, 26.4), lw)
            pygame.draw.circle(t, esc, P(4.8, 25.2), 0.9 * k)                                         # pregos
            pygame.draw.circle(t, esc, P(27.2, 25.2), 0.9 * k)
            pygame.draw.line(t, esc, P(12.1, 21.9), P(22, 12), max(2, round(4.4 * k)))              # martelo: cabo
            pygame.draw.line(t, cabo, P(12.1, 21.9), P(22, 12), max(1, round(2.8 * k)))
            cabeca = [P(29.1, 14.8), P(24.8, 19.1), P(14.9, 9.2), P(19.2, 4.9)]
            pygame.draw.polygon(t, ferro, cabeca)
            pygame.draw.polygon(t, esc, cabeca, lw)
        elif nome == "lanterna":
            c = (255, 214, 120) if (ativo and aceso) else cinza
            ferro = (190, 160, 100) if aceso else (120, 124, 130)
            if aceso:                                                                              # halo da luz
                r = int(15 * k)
                halo = pygame.Surface((2 * r, 2 * r), pygame.SRCALPHA, 32)
                for i, a in ((r, 34), (int(r * 0.72), 44), (int(r * 0.45), 60)):
                    pygame.draw.circle(halo, (255, 214, 120, a), (r, r), i)
                t.blit(halo, (round(cx - r), round(cy - r + 1.5 * k)))
            pygame.draw.arc(t, ferro, R(10, 1, 12, 11), 0, math.pi, max(1, round(1.8 * k)))         # alça
            vidro = R(9.5, 10, 13, 15)
            pygame.draw.rect(t, (24, 34, 48), vidro, border_radius=max(1, round(1.5 * k)))
            if aceso:
                pygame.draw.polygon(t, c, [P(16, 12.5), P(12.8, 20.5), P(16, 23.5), P(19.2, 20.5)])  # chama
                pygame.draw.polygon(t, (255, 250, 220), [P(16, 16.5), P(14.5, 20.8), P(16, 22.3), P(17.5, 20.8)])
            else:
                pygame.draw.line(t, cinza, P(13.5, 22.5), P(18.5, 14.5), lw + 1)                    # apagada: só o pavio
            pygame.draw.rect(t, ferro, vidro, lw + 1, border_radius=max(1, round(1.5 * k)))
            pygame.draw.polygon(t, ferro, [P(8, 10.5), P(24, 10.5), P(20.5, 6.5), P(11.5, 6.5)])      # tampa
            pygame.draw.rect(t, ferro, R(8, 25, 16, 3.4), border_radius=max(1, round(1 * k)))        # base
        elif nome == "corda":
            c = (230, 200, 140) if ativo else cinza
            sombra = misturar(c, (0, 0, 0), 0.45)
            centro = P(14.5, 15.5)
            pygame.draw.circle(t, esc, centro, 13.4 * k)                                           # rolo: contorno
            pygame.draw.circle(t, c, centro, 12 * k)
            pygame.draw.circle(t, sombra, centro, 8.8 * k)                                         # vão entre as voltas
            pygame.draw.circle(t, c, centro, 7.6 * k)
            pygame.draw.circle(t, sombra, centro, 4.2 * k)
            pygame.draw.circle(t, esc, centro, 2.6 * k)
            for i in range(10):                                                                    # torção da corda
                a = i * math.tau / 10
                for r0, r1 in ((9.2, 11.6), (5, 7.2)):
                    pygame.draw.line(t, sombra, (centro[0] + math.cos(a) * r0 * k, centro[1] + math.sin(a) * r0 * k),
                                     (centro[0] + math.cos(a + 0.35) * r1 * k, centro[1] + math.sin(a + 0.35) * r1 * k), lw)
            ponta = [P(22.5, 22.5), P(27, 25), P(28.5, 30)]                                        # ponta solta
            pygame.draw.lines(t, esc, False, ponta, max(3, round(5.4 * k)))
            pygame.draw.lines(t, c, False, ponta, max(2, round(3.4 * k)))

    def _icone_melhoria(self, nome, cx, cy, tam, ativo=True):
        """Ícones das melhorias do barco (grade de 32 unidades). Sem a melhoria, ficam cinza e apagados."""
        t = self.tela
        k = tam / 32.0

        def P(x, y):
            return (cx + (x - 16) * k, cy + (y - 16) * k)

        if self.arte.ok:
            spr = self.arte.get(("mel_" if ativo else "melc_") + nome, fit=(round(tam), round(tam)))
            if spr is not None:
                t.blit(spr, spr.get_rect(center=(round(cx), round(cy))))
                return
        cinza = (96, 104, 114)
        esc = (14, 22, 34) if ativo else (30, 38, 48)
        lw = max(1, round(1.4 * k))
        if nome == "casco":                        # escudo de ferro com cinta
            c = (156, 176, 204) if ativo else cinza
            esc_pts = [P(4.6, 2.6), P(27.4, 2.6), P(27.4, 15.5), P(16, 30.4), P(4.6, 15.5)]
            fundo = [P(6.4, 4.6), P(25.6, 4.6), P(25.6, 14.9), P(16, 27.6), P(6.4, 14.9)]
            pygame.draw.polygon(t, esc, esc_pts)
            pygame.draw.polygon(t, c, fundo)
            pygame.draw.polygon(t, misturar(c, BRANCO, 0.4), [P(6.4, 4.6), P(16, 4.6), P(16, 27.6), P(6.4, 14.9)])
            pygame.draw.line(t, misturar(c, (0, 0, 0), 0.45), P(6.4, 11), P(25.6, 11), max(2, round(2.6 * k)))
            for x, y in ((9.5, 8), (22.5, 8)):
                pygame.draw.circle(t, esc, P(x, y), 1.1 * k)
        elif nome == "remos":                       # dois remos cruzados
            cabo = (226, 192, 134) if ativo else cinza
            pa = (170, 128, 76) if ativo else (80, 88, 98)
            for x0, y0, x1, y1 in ((5, 27, 25, 5), (27, 27, 7, 5)):
                pygame.draw.line(t, esc, P(x0, y0), P(x1, y1), max(3, round(4.6 * k)))
                pygame.draw.line(t, cabo, P(x0, y0), P(x1, y1), max(2, round(2.8 * k)))
            for x, y in ((25, 5), (7, 5)):          # pás
                pygame.draw.circle(t, esc, P(x, y), 4.4 * k)
                pygame.draw.circle(t, pa, P(x, y), 3.2 * k)
        elif nome == "vela":                        # vela triangular num pequeno casco
            vela = (246, 244, 234) if ativo else (120, 128, 138)
            pygame.draw.polygon(t, esc, [P(14.2, 1.2), P(14.2, 22), P(29.4, 22)])
            pygame.draw.polygon(t, vela, [P(15, 4.6), P(15, 20.6), P(26, 20.6)])
            pygame.draw.polygon(t, (222, 62, 56) if ativo else cinza, [P(15, 16.4), P(15, 20.6), P(26, 20.6), P(23.4, 16.4)])
            pygame.draw.polygon(t, esc, [P(3, 23.6), P(29, 23.6), P(24.5, 29.4), P(7.5, 29.4)])
            pygame.draw.polygon(t, (166, 114, 66) if ativo else cinza, [P(4.8, 24.6), P(27.2, 24.6), P(23.6, 28.2), P(8.4, 28.2)])
            pygame.draw.line(t, esc, P(13.4, 2.4), P(13.4, 24), max(2, round(2.2 * k)))
        elif nome == "leme":                        # timão
            madeira = (196, 142, 80) if ativo else cinza
            centro = P(16, 16)
            for i in range(8):
                a = i * math.tau / 8
                fim = (centro[0] + math.cos(a) * 14 * k, centro[1] + math.sin(a) * 14 * k)
                pygame.draw.line(t, esc, centro, fim, max(3, round(4.4 * k)))
                pygame.draw.line(t, madeira, centro, fim, max(2, round(2.6 * k)))
                pygame.draw.circle(t, esc, fim, 2.8 * k)
                pygame.draw.circle(t, madeira, fim, 1.8 * k)
            pygame.draw.circle(t, esc, centro, 10.6 * k, max(3, round(4.6 * k)))
            pygame.draw.circle(t, madeira, centro, 10.6 * k, max(2, round(2.8 * k)))
            pygame.draw.circle(t, esc, centro, 3.6 * k)
            pygame.draw.circle(t, (238, 192, 72) if ativo else cinza, centro, 2.4 * k)
        elif nome == "lente":                       # lente de aumento com um raio de luz
            vidro = (150, 206, 255) if ativo else cinza
            aro = (214, 176, 104) if ativo else (110, 118, 128)
            pygame.draw.line(t, esc, P(21.4, 21.4), P(29, 29), max(4, round(6 * k)))
            pygame.draw.line(t, (166, 114, 66) if ativo else cinza, P(21.4, 21.4), P(29, 29), max(2, round(3.6 * k)))
            pygame.draw.circle(t, esc, P(13.6, 13.6), 11.4 * k)
            pygame.draw.circle(t, aro, P(13.6, 13.6), 10 * k)
            pygame.draw.circle(t, vidro, P(13.6, 13.6), 7.6 * k)
            pygame.draw.arc(t, BRANCO if ativo else (150, 158, 168), pygame.Rect(
                round(P(8, 8)[0]), round(P(8, 8)[1]), round(9 * k), round(9 * k)), math.pi * 0.55, math.pi * 1.1, lw + 1)
            if ativo:                               # raios de luz
                pygame.draw.line(t, (255, 226, 140), P(25, 3), P(29, 1.4), lw)
                pygame.draw.line(t, (255, 226, 140), P(26.6, 7), P(30.4, 7), lw)
                pygame.draw.line(t, (255, 226, 140), P(23, 0.6), P(24, -1.6), lw)
        elif nome == "rede":                        # rede em losango
            fio = (214, 208, 178) if ativo else cinza
            v = [P(16, 2.4), P(29.6, 16), P(16, 29.6), P(2.4, 16)]
            pygame.draw.polygon(t, esc, [P(16, 0.4), P(31.6, 16), P(16, 31.6), P(0.4, 16)])
            pygame.draw.polygon(t, (46, 74, 98) if ativo else (52, 60, 70), v)
            for i in range(1, 4):
                f = i / 4.0
                a0 = (v[0][0] + (v[1][0] - v[0][0]) * f, v[0][1] + (v[1][1] - v[0][1]) * f)
                a1 = (v[3][0] + (v[2][0] - v[3][0]) * f, v[3][1] + (v[2][1] - v[3][1]) * f)
                pygame.draw.line(t, fio, a0, a1, lw)
                b0 = (v[0][0] + (v[3][0] - v[0][0]) * f, v[0][1] + (v[3][1] - v[0][1]) * f)
                b1 = (v[1][0] + (v[2][0] - v[1][0]) * f, v[1][1] + (v[2][1] - v[1][1]) * f)
                pygame.draw.line(t, fio, b0, b1, lw)
            pygame.draw.polygon(t, fio, v, lw + 1)

    def _icone_bau(self, cx, cy, tam):
        """Baú dourado (grade de 32 unidades), usado na seta que aponta para ele."""
        t = self.tela
        k = tam / 32.0
        spr = self.arte.get("item_bau", fit=(round(tam), round(tam))) if self.arte.ok else None
        if spr is not None:
            t.blit(spr, spr.get_rect(center=(round(cx), round(cy))))
            return

        def R(x, y, w, h):
            return pygame.Rect(round(cx + (x - 16) * k), round(cy + (y - 16) * k), max(1, round(w * k)), max(1, round(h * k)))
        esc = (14, 22, 34)
        lw = max(1, round(1.4 * k))
        pygame.draw.rect(t, esc, R(2, 9, 28, 20), border_radius=max(2, round(3 * k)))
        pygame.draw.rect(t, (150, 98, 50), R(3.6, 10.6, 24.8, 16.8), border_radius=max(1, round(2 * k)))
        pygame.draw.rect(t, (112, 70, 34), R(3.6, 16.4, 24.8, 11), border_radius=max(1, round(2 * k)))
        for x in (8, 21):
            pygame.draw.rect(t, (238, 192, 72), R(x, 10.6, 3.4, 16.8))
        pygame.draw.rect(t, (238, 192, 72), R(3.6, 15.4, 24.8, 2.6))
        pygame.draw.rect(t, (255, 232, 130), R(13.4, 13.6, 5.2, 6.4), border_radius=max(1, round(1.2 * k)))
        pygame.draw.circle(t, esc, (round(cx), round(cy + 4.6 * k)), max(1, round(1 * k)))

    def _barra(self, x, y, w, valor, cor, nome, icone):
        t = self.tela
        madeira = self.arte.ok
        pygame.draw.rect(t, (14, 20, 28), (x, y, w, 20), border_radius=6)
        cheio = int((w - 2) * limitar(valor / 100.0, 0, 1))
        c = cor
        if valor < 20 and int(self.anim * 4) % 2 == 0:
            c = (240, 60, 60)
        if cheio > 2:
            pygame.draw.rect(t, c, (x + 1, y + 1, cheio, 18), border_radius=5)
            pygame.draw.rect(t, misturar(c, BRANCO, 0.3), (x + 1, y + 1, cheio, 7),
                             border_top_left_radius=5, border_top_right_radius=5)
        if madeira:                                          # contorno de madeira, como as molduras
            pygame.draw.rect(t, (22, 12, 8), (x - 1, y - 1, w + 2, 22), 1, border_radius=7)
            pygame.draw.rect(t, (196, 112, 48), (x, y, w, 20), 2, border_radius=6)
            pygame.draw.rect(t, (236, 160, 74), (x + 1, y + 1, w - 2, 1), 1)
        else:
            pygame.draw.rect(t, (200, 205, 212), (x, y, w, 20), 1, border_radius=6)
        self._icone(icone, x + 6, y + 3, BRANCO)
        self._texto("%s  %d" % (nome, int(valor)), self.f_pq, BRANCO, x + 26, y + 1)

    def _astro(self, x, y):
        t = self.tela
        if self.arte.ok:
            nome = "nuvem_raio" if self.tempestade > 0.5 else ("sol" if self.brilho() > 0.42 else "lua")
            spr = self.arte.get(nome, fit=(30, 30))
            if nome == "sol":
                spr = self.arte.rot("sol", -self.anim * 8.0, passo=6, h=30) or spr   # os raios giram devagar
            elif nome == "nuvem_raio":
                y += int(math.sin(self.anim * 2.0) * 1.5)
            elif nome == "lua":
                y += int(math.sin(self.anim * 0.9) * 1.5)
            if spr is not None:
                t.blit(spr, spr.get_rect(center=(x, y)))
                return
        if self.brilho() > 0.42:
            pygame.draw.circle(t, (255, 214, 90), (x, y), 6)
            for i in range(8):
                a = i * math.pi / 4
                pygame.draw.line(t, (255, 214, 90), (x + math.cos(a) * 9, y + math.sin(a) * 9),
                                 (x + math.cos(a) * 12, y + math.sin(a) * 12), 2)
        else:
            pygame.draw.circle(t, (226, 232, 246), (x, y), 7)
            pygame.draw.circle(t, (196, 204, 224), (x - 2, y - 2), 2)
            pygame.draw.circle(t, (196, 204, 224), (x + 3, y + 2), 1)

    def _hud(self):
        b = self.barco

        # barras de status
        self._painel(12, 12, 254, 176)
        rotulo_san = "Sanidade"
        if self.sanidade < 35 and int(self.anim * 6) % 7 == 0:  # o rótulo "falha" quando a mente cede
            rotulo_san = SUSSURRO_HUD[int(self.anim * 6 / 7) % len(SUSSURRO_HUD)]
        barras = (("Vida", self.vida, (224, 72, 72), "vida"),
                  ("Fome", self.fome, (236, 150, 52), "peixe"),
                  ("Sede", self.sede, (72, 160, 236), "gota"),
                  ("Energia", self.energia, (240, 216, 72), "raio"),
                  ("Casco", self.casco, (176, 124, 72), "casco"),
                  (rotulo_san, self.sanidade, (170, 120, 240), "olho"))
        for i, (nome, val, cor, ic) in enumerate(barras):
            self._barra(22, 22 + i * 26, 234, val, cor, nome, ic)

        # melhorias do barco: as montadas acendem, as que faltam ficam apagadas; planta achada = contorno que pulsa
        self._painel(12, 194, 254, 42)
        pulso = 0.5 + 0.5 * math.sin(self.anim * 5)
        for i, nome in enumerate(MELHORIAS):
            self._icone_melhoria(nome, 36 + i * 40, 215, 28, ativo=nome in self.melhorias)
            if nome in self.plantas:
                cor = VERDE if self._pode(nome) else AMARELO
                pygame.draw.rect(self.tela, misturar((40, 40, 40), cor, 0.55 + 0.45 * pulso),
                                 (36 + i * 40 - 17, 215 - 17, 34, 34), 2, border_radius=6)

        # experiência e nível (tocar ou K abre a ficha)
        t = self.tela
        self._painel(12, 240, 254, 28)
        frac = limitar(self.xp / float(self._xp_prox()), 0.0, 1.0)
        pygame.draw.rect(t, (14, 20, 28), (22, 245, 234, 18), border_radius=6)
        if frac > 0:
            lar = max(4, int(232 * frac))
            pygame.draw.rect(t, (150, 104, 28), (23, 246, lar, 16), border_radius=5)
            pygame.draw.rect(t, (206, 150, 44), (23, 246, lar, 6), border_top_left_radius=5, border_top_right_radius=5)
        pygame.draw.rect(t, (22, 12, 8), (21, 244, 236, 20), 1, border_radius=7)
        pygame.draw.rect(t, (196, 112, 48), (22, 245, 234, 18), 2, border_radius=6)
        self._texto("Nv %d   XP %d/%d" % (self.nivel, self.xp, self._xp_prox()), self.f_pq, BRANCO, 30, 246)
        if self.pontos > 0:
            self._texto("%s: +%d" % ("FICHA" if self.modo_toque else "K", self.pontos), self.f_pq,
                        misturar(AMARELO, BRANCO, pulso), 252, 246)
        elif not self.modo_toque:
            self._texto("K ficha", self.f_pq, CINZA, 256 - 54, 246)
        self.rect_xp = pygame.Rect(12, 240, 254, 28)

        # planta achada: o que falta para montar (E, ou tocar no aviso)
        self.rect_montar = None
        y_msg = 276
        if self.plantas and self.estado == "jogando":
            foco = self._foco_planta()
            ok = self._pode(foco)
            self._painel(12, 272, 254, 44, 170)
            self._texto("%s: %s" % ("Montar" if ok else "Planta", INFO_MELHORIA[foco][0]), self.f_pq,
                        VERDE if ok else AMARELO, 22, 277)
            self._texto("  ".join("%s %d/%d" % (NOME_MAT[m][1], self.inv.get(m, 0), q)
                                   for m, q in RECEITAS[foco].items()), self.f_pq, BRANCO if ok else CINZA, 22, 296)
            dica = ("toque aqui" if self.modo_toque else "[E]") if ok else ""
            if dica:
                self._texto(dica, self.f_pq, VERDE, 258 - self.f_pq.size(dica)[0], 277)
            if len(self.plantas) > 1:
                self._texto("+%d" % (len(self.plantas) - 1), self.f_pq, CINZA, 244, 296)
            self.rect_montar = pygame.Rect(12, 272, 254, 44)
            y_msg = 324

        # lanterna quebrada: o que falta para consertar (L ou E, ou clicar no painel)
        self.rect_lant = None
        if self.lant_quebrada and self.estado == "jogando":
            y_l = y_msg - 4
            ok = all(self.inv.get(m, 0) >= q for m, q in LANTERNA_CONSERTO.items())
            self._painel(12, y_l, 254, 44, 170)
            self._texto("Lanterna quebrada!", self.f_pq, VERMELHO, 22, y_l + 5)
            self._texto("  ".join("%s %d/%d" % (NOME_MAT[m][1], self.inv.get(m, 0), q)
                                   for m, q in LANTERNA_CONSERTO.items()), self.f_pq, BRANCO if ok else CINZA,
                        22, y_l + 24)
            if ok:
                dica = "toque aqui" if self.modo_toque else "[L]"
                self._texto(dica, self.f_pq, VERDE, 258 - self.f_pq.size(dica)[0], y_l + 5)
            self.rect_lant = pygame.Rect(12, y_l, 254, 44)
            y_msg = y_l + 52

        # relógio, rumo e clima
        self._painel(LARGURA - 232, 12, 220, 78)
        self._astro(LARGURA - 214, 32)
        self._texto("Dia %d   %s" % (self.dia(), self.hora_txt()), self.f_md, BRANCO, LARGURA - 196, 22)
        n, g = nome_rumo(b.ang)
        self._texto("Rumo do barco: %s (%d°)" % (n, g), self.f_pq, CINZA, LARGURA - 222, 48)
        if self.tempestade > 0.4:
            self._texto("TEMPESTADE", self.f_pq, VERMELHO, LARGURA - 222, 66)
        else:
            self._texto("Vento %s" % ("forte" if self.forca_vento() > 1.4 else "fraco"), self.f_pq,
                        AZUL_CLARO, LARGURA - 222, 66)

        if self.diag:
            self._texto("%d fps%s" % (round(1.0 / max(self.ema_dt, 0.001)), "  ·  modo leve" if self.leve else ""),
                        self.f_pq, AMARELO, LARGURA / 2, 40 if self.modo_toque else 38, centro=True)

        # dicas de controles (só no começo, e só com teclado)
        if self.estado == "jogando" and (self.t - self.t0) < 40 and not self.modo_toque:
            self._texto("W remar   A/D virar   S frear   V vela   L lanterna   F pescar   ESPAÇO golpear   P pausa",
                        self.f_pq, BRANCO, LARGURA / 2, 14, centro=True)
            self._texto("E monta o barco      K ficha do náufrago", self.f_pq, CINZA, LARGURA / 2, 32, centro=True)

        # mensagens, com fundo e esmaecendo ao sumir
        for i, (txt, ttl, cor) in enumerate(self.msgs if self.estado == "jogando" else []):
            img = self.f_md.render(txt, True, cor)
            w, h = img.get_size()
            fundo = pygame.Surface((w + 16, h + 4), pygame.SRCALPHA, 32)
            pygame.draw.rect(fundo, (6, 12, 22, 125), fundo.get_rect(), border_radius=6)
            fundo.blit(img, (8, 2))
            fundo.set_alpha(int(255 * limitar(ttl, 0, 1)))
            self.tela.blit(fundo, (14, y_msg + i * 26))

        # inventário e lanterna: só ícones (gota = beber, peixe = comer, tábua = consertar). Quantidade ao lado.
        # No celular os quatro são botões: tocar usa o item.
        slots = (("1", self.inv["agua"], "gota"),
                 ("2", self.inv["peixe"], "peixe"),
                 ("3", self.inv["madeira"], "tabua"),
                 ("4", self.inv["corda"], "corda"),
                 ("L", None, "lanterna"))
        for (tecla, q, ic), r in zip(slots, self._rects_slots()):
            self._painel(r.x, r.y, r.w, r.h)
            tem = q is None or q > 0
            cor_n = BRANCO if tem else (140, 144, 150)
            f_q = self.f_gd if r.w >= 100 else self.f_md        # número menor nos botões mais estreitos
            img = f_q.render("×%d" % q, True, cor_n) if q is not None else None
            if img and not self.modo_toque and img.get_width() > 42:    # "×12": cabe com a tecla de atalho ao lado
                f_q = self.f_md
                img = f_q.render("×%d" % q, True, cor_n)
            tam = max(24, min(46 if self.modo_toque else 32, r.w - 12 - (8 + img.get_width() if img else 0)))
            largura = tam + (8 + img.get_width() if img else 0)
            x = r.x + (r.w - largura) // 2
            if not self.modo_toque:                          # tecla de atalho, num 'botãozinho' no canto
                kc = pygame.Rect(r.x + 7, r.y + 7, 18, 18)
                pygame.draw.rect(self.tela, (20, 30, 44), kc, border_radius=5)
                pygame.draw.rect(self.tela, (150, 160, 172), kc, 1, border_radius=5)
                self._texto(tecla, self.f_pq, CINZA, kc.centerx, kc.centery - 8, centro=True)
                x = max(x, r.x + 30) if img else x + 8
            self._icone_item(ic, x + tam / 2, r.centery, tam, ativo=tem, aceso=self.lanterna)
            if ic == "lanterna" and self.lant_quebrada:             # quebrada: X vermelho e contorno que pulsa
                ok = all(self.inv.get(m, 0) >= q2 for m, q2 in LANTERNA_CONSERTO.items())
                cx2, cy2, d = x + tam / 2, r.centery, tam * 0.30
                pygame.draw.line(self.tela, (30, 8, 8), (cx2 - d, cy2 - d), (cx2 + d, cy2 + d), 6)
                pygame.draw.line(self.tela, (30, 8, 8), (cx2 + d, cy2 - d), (cx2 - d, cy2 + d), 6)
                pygame.draw.line(self.tela, (236, 60, 52), (cx2 - d, cy2 - d), (cx2 + d, cy2 + d), 3)
                pygame.draw.line(self.tela, (236, 60, 52), (cx2 + d, cy2 - d), (cx2 - d, cy2 + d), 3)
                pygame.draw.rect(self.tela, misturar((40, 40, 40), VERDE if ok else VERMELHO, 0.55 + 0.45 * pulso),
                                 r, 2, border_radius=8)
            elif self._sobre(r):                                   # mouse em cima do item do inventário
                pygame.draw.rect(self.tela, AMARELO, r, 2, border_radius=8)
            if img:
                pos = (x + tam + 8, r.centery - img.get_height() // 2)
                self.tela.blit(f_q.render("×%d" % q, True, (0, 0, 0)), (pos[0] + 1, pos[1] + 1))
                self.tela.blit(img, pos)

        self._bussola()
        if self.estado == "jogando":
            self._seta_bau()
            self._aviso_melhoria()
        if self.modo_toque and self.estado == "jogando":
            self.toque.desenhar()
            if self.pontos > 0:                             # bolinha no botão FICHA: tem ponto para gastar
                pygame.draw.circle(self.tela, (30, 14, 10), (LARGURA - 312, 33), 9)
                pygame.draw.circle(self.tela, misturar(AMARELO, BRANCO, pulso), (LARGURA - 312, 33), 7)
                self._texto("%d" % self.pontos, self.f_pq, (30, 14, 10), LARGURA - 312, 25, centro=True, sombra=False)

    def _seta_bau(self):
        """Seta dourada na borda da tela apontando para o baú (quando ele está perto ou o mapa o marcou)."""
        bau = self._bau()
        if bau is None:
            return
        b = self.barco
        d = math.hypot(bau.x - b.x, bau.y - b.y)
        if d > 1900 and self.mapa <= 0:
            return
        sx, sy = bau.x - self.cx, bau.y - self.cy
        if -20 < sx < LARGURA + 20 and -20 < sy < ALTURA + 20:
            return                                  # já está na tela, brilhando
        cx, cy = LARGURA / 2, ALTURA / 2
        dx, dy = sx - cx, sy - cy
        # a seta corre numa elipse em volta do centro, para não ficar escondida atrás dos painéis dos cantos
        rx, ry = cx - 200, cy - (100 if self.modo_toque else 120)
        esc = 1.0 / max(math.hypot(dx / rx, dy / ry), 1e-6)
        px, py = cx + dx * esc, cy + dy * esc
        a = math.atan2(dy, dx)
        pulso = 0.5 + 0.5 * math.sin(self.anim * 5)
        t = self.tela
        r = 22
        ponta = (px + math.cos(a) * (r + 12 + 3 * pulso), py + math.sin(a) * (r + 12 + 3 * pulso))
        b1 = (px + math.cos(a + 1.6) * 11 + math.cos(a) * (r - 2), py + math.sin(a + 1.6) * 11 + math.sin(a) * (r - 2))
        b2 = (px + math.cos(a - 1.6) * 11 + math.cos(a) * (r - 2), py + math.sin(a - 1.6) * 11 + math.sin(a) * (r - 2))
        pygame.draw.polygon(t, (14, 22, 34), [ponta, b1, b2])
        pygame.draw.polygon(t, (255, 214, 96), [ponta, b1, b2])
        pygame.draw.polygon(t, (150, 104, 30), [ponta, b1, b2], 1)
        pygame.draw.circle(t, (14, 22, 34), (int(px), int(py)), r + 2)
        pygame.draw.circle(t, misturar((74, 56, 20), (150, 112, 36), pulso), (int(px), int(py)), r)
        pygame.draw.circle(t, (255, 214, 96), (int(px), int(py)), r, 2)
        self._icone_bau(px, py, 30)
        self._texto("%d m" % (int(d / 100) * 10), self.f_pq, (255, 226, 140), px, py + r + 3, centro=True)

    def _aviso_melhoria(self):
        """Faixa grande no alto da tela quando se acha uma melhoria do barco."""
        if self.banner is None:
            return
        nome, ttl = self.banner[:2]
        planta = len(self.banner) > 2 and self.banner[2] == "planta"
        titulo, texto = INFO_MELHORIA[nome]
        if planta:
            texto = "Material: %s. %s" % (self._txt_receita(nome),
                                          "Toque no aviso da planta para montar." if self.modo_toque
                                          else "Aperte E para montar.")
        alfa = int(255 * limitar(ttl / 1.0, 0.0, 1.0) * limitar((7.0 - ttl) / 0.25, 0.0, 1.0))
        w = min(LARGURA - 40, 560)
        h = 96
        x, y = (LARGURA - w) // 2, 86 if not self.modo_toque else 70
        cartao = pygame.Surface((w, h), pygame.SRCALPHA, 32)
        pygame.draw.rect(cartao, (8, 16, 28, 225), (0, 0, w, h), border_radius=14)
        pygame.draw.rect(cartao, (255, 214, 96, 255), (0, 0, w, h), 2, border_radius=14)
        cab = ("PLANTA ENCONTRADA" if planta else "MELHORIA MONTADA  %d/%d" % (len(self.melhorias), len(MELHORIAS)))
        cartao.blit(self.f_pq.render(cab, True, (255, 214, 96)), (96, 10))
        cartao.blit(self.f_gd.render(titulo, True, BRANCO), (96, 26))
        # a descrição pode ser longa: quebra em duas linhas
        palavras, linhas, atual = texto.split(), [], ""
        for pal in palavras:
            tent = (atual + " " + pal).strip()
            if self.f_pq.size(tent)[0] > w - 112 and atual:
                linhas.append(atual)
                atual = pal
            else:
                atual = tent
        linhas.append(atual)
        for i, l in enumerate(linhas[:2]):
            cartao.blit(self.f_pq.render(l, True, CINZA), (96, 58 + i * 16))
        tela0, self.tela = self.tela, cartao        # o ícone é desenhado dentro do cartão, para sumir junto com ele
        try:
            self._icone_melhoria(nome, 48, h // 2, 64)
        finally:
            self.tela = tela0
        cartao.set_alpha(alfa)                      # entra e sai suavemente
        self.tela.blit(cartao, (x, y))

    def _bussola(self):
        b = self.barco
        t = self.tela
        cx, cy, r = LARGURA - 84, (170 if self.modo_toque else ALTURA - 100), 56
        self._painel(cx - r - 12, cy - r - 12, 2 * r + 24, 2 * r + 52)
        mostrador = self.arte.get("bussola", fit=(2 * r + 6, 2 * r + 6)) if self.arte.ok else None
        if mostrador is not None:
            t.blit(mostrador, mostrador.get_rect(center=(cx, cy)))
        else:
            pygame.draw.circle(t, (16, 30, 44), (cx, cy), r)
            pygame.draw.circle(t, (200, 205, 212), (cx, cy), r, 2)
            for i in range(24):  # marcações de 15 em 15 graus
                a = i * math.tau / 24 - math.pi / 2
                ini = r - (8 if i % 6 == 0 else 4)
                pygame.draw.line(t, (150, 160, 172), (cx + math.cos(a) * ini, cy + math.sin(a) * ini),
                                 (cx + math.cos(a) * (r - 1), cy + math.sin(a) * (r - 1)), 1)
            self._texto("N", self.f_pq, (255, 120, 110), cx, cy - r + 8, centro=True)
        # ilha: ponteiro dourado (uma ponta só) e a ilhota desenhada na borda do mostrador, no rumo dela
        alvo_x, alvo_y = self.destino_ilha()
        a = math.atan2(alvo_y - b.y, alvo_x - b.x)
        if self.sanidade < 30:  # com a mente falhando, a agulha mente
            k = (30 - self.sanidade) / 30.0
            a += math.sin(self.anim * 2.1) * 0.9 * k + math.sin(self.anim * 0.7) * 0.8 * k
        pulso = 0.5 + 0.5 * math.sin(self.anim * 3.0)
        pr = (cx + math.cos(b.ang) * (r - 22), cy + math.sin(b.ang) * (r - 22))      # proa do barco
        if mostrador is not None:
            pygame.draw.line(t, (30, 14, 10), (cx, cy), pr, 5)
            pygame.draw.line(t, (236, 78, 60), (cx, cy), pr, 3)
            pygame.draw.circle(t, (30, 14, 10), (int(pr[0]), int(pr[1])), 5)
            pygame.draw.circle(t, (236, 78, 60), (int(pr[0]), int(pr[1])), 3)
        else:
            pygame.draw.line(t, BRANCO, (cx, cy), pr, 3)
            pygame.draw.circle(t, BRANCO, (int(pr[0]), int(pr[1])), 4)
        ra = r - 17
        ix, iy = cx + math.cos(a) * ra, cy + math.sin(a) * ra
        ponta = (cx + math.cos(a) * (ra - 9), cy + math.sin(a) * (ra - 9))
        lado1 = (cx + math.cos(a + 1.5) * 6.5, cy + math.sin(a + 1.5) * 6.5)
        lado2 = (cx + math.cos(a - 1.5) * 6.5, cy + math.sin(a - 1.5) * 6.5)
        cauda = (cx - math.cos(a) * 12, cy - math.sin(a) * 12)
        losango = [ponta, lado1, cauda, lado2]
        pygame.draw.polygon(t, (30, 14, 10), losango)
        pygame.draw.polygon(t, (255, 205, 70), [ponta, (cx + math.cos(a + 1.5) * 4.2, cy + math.sin(a + 1.5) * 4.2),
                                                (cx - math.cos(a) * 9, cy - math.sin(a) * 9),
                                                (cx + math.cos(a - 1.5) * 4.2, cy + math.sin(a - 1.5) * 4.2)])
        pygame.draw.line(t, (255, 244, 190), (cx, cy), (cx + math.cos(a) * (ra - 14), cy + math.sin(a) * (ra - 14)), 1)
        # a ilhota: anel de águas rasas, areia e uma palmeira
        pygame.draw.circle(t, (255, 226, 140), (int(ix), int(iy)), int(13 + 2 * pulso), 1)
        pygame.draw.circle(t, (30, 14, 10), (int(ix), int(iy)), 12)
        pygame.draw.circle(t, (84, 204, 214), (int(ix), int(iy)), 11)
        pygame.draw.circle(t, (238, 222, 168), (int(ix), int(iy)), 8)
        palma = self.arte.get("palmeira", h=17) if self.arte.ok else None
        if palma is not None:
            t.blit(palma, palma.get_rect(midbottom=(int(ix), int(iy) + 8)))
        else:
            pygame.draw.circle(t, (54, 140, 66), (int(ix), int(iy) - 1), 4)
        pygame.draw.circle(t, (30, 14, 10), (cx, cy), 4)
        pygame.draw.circle(t, (236, 190, 90), (cx, cy), 2)

        d = self.dist_ilha()
        if self.mapa > 0 or d < 2500 or self.hab["vela"] >= 3:
            txt = "Ilha: %d mi" % (d / 200)
        else:
            txt = "Ilha: distância ?"
        self._texto(txt, self.f_pq, (255, 205, 70), cx, cy + r + 8, centro=True)

        # indicador de vento
        wx, wy = cx - r - 46, cy + 20
        self._painel(wx - 30, wy - 30, 60, 76)
        pygame.draw.circle(t, (16, 30, 44), (wx, wy), 22)
        pygame.draw.circle(t, (200, 205, 212), (wx, wy), 22, 1)
        va = self.vento_ang
        p = (wx + math.cos(va) * 18, wy + math.sin(va) * 18)
        pygame.draw.line(t, AZUL_CLARO, (wx - math.cos(va) * 12, wy - math.sin(va) * 12), p, 3)
        pygame.draw.polygon(t, AZUL_CLARO, [p, (wx + math.cos(va + 2.5) * 8 + math.cos(va) * 6,
                                               wy + math.sin(va + 2.5) * 8 + math.sin(va) * 6),
                                            (wx + math.cos(va - 2.5) * 8 + math.cos(va) * 6,
                                             wy + math.sin(va - 2.5) * 8 + math.sin(va) * 6)])
        self._texto("Vento", self.f_pq, CINZA, wx, wy + 26, centro=True)

    # ----------------------------------------------------------------- telas
    def _escurecer(self, alpha):
        self.ov.fill((4, 10, 22, alpha))
        self.tela.blit(self.ov, (0, 0))

    def _tela_menu(self):
        self._escurecer(165)
        cx = LARGURA / 2
        alta = ALTURA >= 700                # telas baixas (celular) usam um menu mais compacto
        ty = 80 if alta else 26
        for dx, dy, cor in ((3, 4, (10, 20, 40)), (0, 0, (255, 225, 140))):
            img = self.f_tit.render("NÁUFRAGO", True, cor)
            self.tela.blit(img, img.get_rect(midtop=(cx + dx, ty + dy)))
        self._texto("sobrevivência e horror cósmico", self.f_gd, VIOLETA, cx, ty + 88, centro=True)
        if self.modo_toque:
            controles = [
                "Esquerda: setas para virar e FREAR.   Direita: REMAR (gasta energia), GOLPE, PESCAR e VELA.",
                "Embaixo: toque na gota (beber), no peixe (comer), na tábua ou na corda (consertar) e na lanterna.   No canto: pausa.",
                "PESCAR: segure perto de um cardume.   Use o vento a favor com a VELA.",
            ]
        else:
            controles = [
                "W / ↑  remar (gasta energia)          A D / ← →  virar          S / ↓  frear",
                "V  içar/recolher a vela (use o vento a favor!)          L  acender/apagar a lanterna (ou consertá-la)",
                "F  pescar (segure perto de um cardume)          ESPAÇO  golpear tubarões com o remo",
                "1  beber água    2  comer    3  consertar com tábua    4  consertar com corda    M  som",
                "E  montar melhoria    K  ficha do náufrago    P  pausa (volume, som)    F11 tela cheia/janela",
            ]
        linhas = [
            "Seu navio afundou. Você está sozinho num barquinho no meio do oceano.",
            "A ilha mais próxima fica a dias de viagem. Siga o ponteiro dourado da bússola!",
            "",
        ] + controles + [
            "Pegue barris, tábuas, cordas e garrafas que boiam — basta encostar neles.",
            "Baús dourados guardam plantas de melhorias: monte-as com tábuas e CORDAS. Siga a seta dourada!",
            "À noite, algo muito antigo desperta no fundo. Mantenha a lanterna acesa e a mente firme.",
            "Tentáculos emergem para agarrar o barco: golpeie-os (%s) ou desvie."
            % ("GOLPE" if self.modo_toque else "ESPAÇO"),
            "Ondas, mordidas e tentáculos podem QUEBRAR a lanterna: consertar custa 4 tábuas + 4 cordas.",
            "A sanidade cai no escuro e perto das criaturas; a luz do dia a restaura.",
        ]
        y = ty + 152
        esp = 26 if alta else 23
        for l in linhas:
            cor = VIOLETA if ("noite" in l.lower() or "tentáculos" in l.lower() or "sanidade" in l.lower()) else BRANCO
            self._texto(l, self.f_md, cor, cx, y, centro=True)
            y += esp
        if int(self.anim * 2) % 2 == 0:
            self._texto("Toque para começar" if self.modo_toque else "Pressione ENTER (ou clique) para começar",
                        self.f_gd, VERDE, cx, ALTURA - (100 if alta else 56), centro=True)

    def _tela_texto(self, titulo, cor, linhas):
        self._escurecer(150)
        self._texto(titulo, self.f_tit, cor, LARGURA / 2, 190 if ALTURA >= 700 else 120, centro=True)
        y = 320 if ALTURA >= 700 else 236
        for l in linhas:
            self._texto(l, self.f_gd, BRANCO, LARGURA / 2, y, centro=True)
            y += 42 if ALTURA >= 700 else 38

    def _rects_volume(self, y0):
        """Duas linhas (efeitos, música) da pausa: (painel, botão −, botão +), cada uma com 56 px de altura."""
        x0 = LARGURA // 2 - 190
        return [(pygame.Rect(x0, y0 + i * 68, 380, 56), pygame.Rect(x0, y0 + i * 68, 64, 56),
                 pygame.Rect(x0 + 316, y0 + i * 68, 64, 56)) for i in range(2)]

    def _volumes_pausa(self, y0, dica_efeitos="", dica_musica=""):
        """Barras de volume da tela de pausa (PC e toque): efeitos+ambientes e música."""
        s = self.som
        dados = (("EFEITOS", s.nivel_efeitos, dica_efeitos), ("MÚSICA", s.nivel_musica, dica_musica))
        for (painel, menos, mais), (nome, nivel, dica) in zip(self._rects_volume(y0), dados):
            self._painel(painel.x, painel.y, painel.w, painel.h, 190)
            self._texto("%s  %d/%d%s" % (nome, nivel, s.NIVEIS, dica), self.f_pq, BRANCO,
                        painel.centerx, painel.y + 6, centro=True)
            x0, x1 = menos.right + 4, mais.x - 4
            seg = (x1 - x0) / s.NIVEIS
            for i in range(s.NIVEIS):
                r = pygame.Rect(int(x0 + i * seg) + 1, painel.y + 30, max(3, int(seg) - 3), 16)
                pygame.draw.rect(self.tela, VERDE if i < nivel else (58, 72, 90), r, border_radius=3)
            for r, mais_ in ((menos, False), (mais, True)):
                cx, cy = r.center
                if self._sobre(r):
                    pygame.draw.rect(self.tela, AMARELO, r, 2, border_radius=8)
                pygame.draw.line(self.tela, BRANCO, (cx - 9, cy), (cx + 9, cy), 3)
                if mais_:
                    pygame.draw.line(self.tela, BRANCO, (cx, cy - 9), (cx, cy + 9), 3)

    def _sobre(self, r):
        """Mouse em cima do retângulo? (só no PC)"""
        return (not self.modo_toque) and r.collidepoint(APRESENTACAO.posicao(pygame.mouse.get_pos()) if APRESENTACAO else pygame.mouse.get_pos())

    def _botoes_pausa(self):
        """(tecla, retângulo) de cada botão da pausa: continuar, recomeçar, som, volumes (−/+) e, no PC, sair."""
        L = LARGURA
        bs = [(pygame.K_p, pygame.Rect(L // 2 - 190, 150, 380, 58)),
              (pygame.K_r, pygame.Rect(L // 2 - 190, 216, 380, 58)),
              (pygame.K_m, pygame.Rect(L // 2 - 190, 282, 380, 58))]
        for (_, menos, mais), (t_menos, t_mais) in zip(self._rects_volume(356),
                                                       ((pygame.K_LEFT, pygame.K_RIGHT),
                                                        (pygame.K_DOWN, pygame.K_UP))):
            bs += [(t_menos, menos), (t_mais, mais)]
        if not self.modo_toque:
            bs.append((pygame.K_q, pygame.Rect(L // 2 - 190, 504, 380, 48)))
        return bs

    def _tela_pausa(self):
        """Pausa: botões clicáveis (mouse ou dedo) e as mesmas teclas de sempre."""
        self._escurecer(150)
        pc = not self.modo_toque
        self._texto("PAUSADO", self.f_tit, AZUL_CLARO, LARGURA / 2, 40, centro=True)
        bs = self._botoes_pausa()
        rotulos = ["CONTINUAR", "RECOMEÇAR", "SOM: DESLIGADO" if self.som.mudo else "SOM: LIGADO"]
        atalhos = ("P", "R", "M")
        grupo = bs[:3] + ([bs[-1]] if pc else [])
        if pc:
            rotulos.append("SAIR DO JOGO")
            atalhos += ("Q",)
        for (tecla, rect), rot, at in zip(grupo, rotulos, atalhos):
            sobre = self._sobre(rect)
            self._painel(rect.x, rect.y, rect.w, rect.h, 235 if sobre else 190)
            if sobre:
                pygame.draw.rect(self.tela, AMARELO, rect, 2, border_radius=8)
            self._texto(rot + ("   [%s]" % at if pc else ""), self.f_gd, AMARELO if sobre else BRANCO,
                        rect.centerx, rect.centery - 11, centro=True)
        self._volumes_pausa(356, "  (← →)" if pc else "", "  (↓ ↑)" if pc else "")
        if pc:
            self._texto("Clique nos botões e nas barras de volume, ou use o teclado", self.f_pq, CINZA,
                        LARGURA / 2, 566, centro=True)

    def _tela_pausa_toque(self):
        self._tela_pausa()

    def _rects_ficha(self):
        """(retângulo de cada habilidade, botão fechar, painel) da ficha do náufrago."""
        w = min(LARGURA - 40, 720)
        x0 = (LARGURA - w) // 2
        y0 = 118 if ALTURA >= 700 else 94
        linhas = [pygame.Rect(x0 + 20, y0 + i * 68, w - 40, 62) for i in range(len(HABILIDADES))]
        fechar = pygame.Rect(LARGURA // 2 - 110, linhas[-1].bottom + 14, 220, 38)
        painel = pygame.Rect(x0, y0 - 80, w, fechar.bottom + 46 - (y0 - 80))      # sobra uma linha de aviso embaixo
        return linhas, fechar, painel

    def _tela_ficha(self):
        self._escurecer(170)
        linhas, fechar, painel = self._rects_ficha()
        self._painel(painel.x, painel.y, painel.w, painel.h, 215)
        self._texto("FICHA DO NÁUFRAGO", self.f_gd, AMARELO, LARGURA / 2, painel.y + 14, centro=True)
        self._texto("Nível %d   ·   XP %d/%d   ·   Pontos para gastar: %d" % (self.nivel, self.xp, self._xp_prox(), self.pontos),
                    self.f_md, BRANCO, LARGURA / 2, painel.y + 50, centro=True)
        t = self.tela
        for i, (h, r) in enumerate(zip(HABILIDADES, linhas)):
            nome, desc = INFO_HAB[h]
            lv = self.hab[h]
            pode = self.pontos > 0 and lv < HAB_MAX
            sobre = self._sobre(r)
            pygame.draw.rect(t, (26, 40, 58) if sobre else (14, 24, 38), r, border_radius=8)
            pygame.draw.rect(t, (255, 214, 96) if (pode or sobre) else (84, 100, 118), r, 2, border_radius=8)
            x = r.x + 12
            if not self.modo_toque:
                kc = pygame.Rect(x, r.y + 10, 22, 22)
                pygame.draw.rect(t, (20, 30, 44), kc, border_radius=5)
                pygame.draw.rect(t, (150, 160, 172), kc, 1, border_radius=5)
                self._texto(str(i + 1), self.f_pq, CINZA, kc.centerx, kc.centery - 8, centro=True)
                x += 32
            self._texto(nome, self.f_md, BRANCO, x, r.y + 8)
            for k in range(HAB_MAX):                                        # nível: cinco quadradinhos
                q = pygame.Rect(x + 170 + k * 20, r.y + 11, 16, 16)
                pygame.draw.rect(t, (236, 190, 70) if k < lv else (30, 42, 58), q, border_radius=3)
                pygame.draw.rect(t, (150, 160, 172), q, 1, border_radius=3)
            self._texto(desc, self.f_pq, CINZA, x, r.y + 36)
            bt = pygame.Rect(r.right - 48, r.y + 10, 38, 42)                # botão de gastar o ponto
            if lv >= HAB_MAX:
                self._texto("MÁX", self.f_pq, AMARELO, bt.centerx, bt.centery - 8, centro=True)
            elif pode:
                pygame.draw.rect(t, (38, 96, 52), bt, border_radius=8)
                pygame.draw.rect(t, VERDE, bt, 2, border_radius=8)
                self._texto("+", self.f_gd, BRANCO, bt.centerx, bt.centery - 11, centro=True)
            else:
                pygame.draw.rect(t, (22, 30, 42), bt, border_radius=8)
                pygame.draw.rect(t, (70, 82, 98), bt, 1, border_radius=8)
                self._texto("+", self.f_gd, (90, 100, 114), bt.centerx, bt.centery - 11, centro=True)
        sobre = self._sobre(fechar)
        pygame.draw.rect(t, (26, 40, 58) if sobre else (14, 24, 38), fechar, border_radius=8)
        pygame.draw.rect(t, AMARELO if sobre else (150, 160, 172), fechar, 2, border_radius=8)
        self._texto("Fechar" if self.modo_toque else "Fechar   [K / ESC]", self.f_md, BRANCO, fechar.centerx,
                    fechar.centery - 9, centro=True)
        # linha de aviso: o resultado do último clique (ou o que fazer quando não há pontos)
        if self.ficha_aviso and self.anim - self.ficha_aviso[2] < 4.0:
            txt, cor = self.ficha_aviso[0], self.ficha_aviso[1]
        elif self.pontos <= 0:
            txt, cor = "Sem pontos: ganhe XP pescando, montando melhorias e sobrevivendo às noites.", CINZA
        else:
            txt, cor = ("Clique numa habilidade para gastar 1 ponto." if not self.modo_toque
                        else "Toque numa habilidade para gastar 1 ponto."), BRANCO
        self._texto(txt, self.f_pq, cor, LARGURA / 2, fechar.bottom + 12, centro=True)

    def _tela_fim(self):
        horas = (self.t - self.t0) / DURACAO_DIA * 24
        dias, h = int(horas // 24), int(horas % 24)
        titulo = "SALVO!" if self.vitoria else ("A LOUCURA TE LEVOU" if self.fim_loucura else "FIM DE JOGO")
        cor = VERDE if self.vitoria else (VIOLETA if self.fim_loucura else VERMELHO)
        self._tela_texto(titulo, cor, [
            self.fim_texto,
            "Tempo no mar: %d dia(s) e %d h      Nível %d      Melhorias: %d/%d"
            % (dias, h, self.nivel, len(self.melhorias), len(MELHORIAS)),
            "Peixes: %d     Tubarões abatidos: %d     Tentáculos repelidos: %d"
            % (self.stats["peixes"], self.stats["tubaroes"], self.stats["tentaculos"]),
            "",
            "Toque na tela para jogar de novo" if self.modo_toque
            else "ENTER, R ou clique: jogar de novo      ESC: sair",
        ])


# ----------------------------------------------------------------------------
ALTURA_CELULAR = 576      # altura lógica no celular: a largura segue a proporção da tela


def _largura_para(prop):
    return int(limitar(round(ALTURA_CELULAR * prop), 900, 1400))


def abrir_tela(forcar_toque=False):
    """Abre a janela e devolve (tela, modo_toque). No celular a tela lógica tem altura fixa
    e a largura da proporção do aparelho; o SDL amplia na GPU (pygame.SCALED), o que é bem
    mais barato do que desenhar em resolução cheia."""
    global APRESENTACAO
    if PLATAFORMA == "desktop":
        from tela_desktop import TelaDesktop
        definir_tela(1280, 576 if forcar_toque else 720)
        APRESENTACAO = TelaDesktop((LARGURA, ALTURA), cheia="--janela" not in sys.argv[1:])
        return APRESENTACAO.logica, forcar_toque
    toque = forcar_toque
    flags = 0
    if PLATAFORMA == "android":
        toque = True
        info = pygame.display.Info()
        dw, dh = max(info.current_w, info.current_h), min(info.current_w, info.current_h)
        definir_tela(_largura_para(dw / dh if dh > 0 else 16 / 9), ALTURA_CELULAR)
        flags = pygame.SCALED | pygame.FULLSCREEN
    elif PLATAFORMA == "web":
        flags = pygame.SCALED
        try:                                    # pygbag expõe o window do navegador
            import platform
            w = platform.window
            if w.navigator.maxTouchPoints > 0:  # celular/tablet: tela baixa e larga
                toque = True
                a, b = float(w.innerWidth), float(w.innerHeight)
                definir_tela(_largura_para(max(a, b) / max(1.0, min(a, b))), ALTURA_CELULAR)
        except Exception:
            pass
    elif forcar_toque:
        definir_tela(1280, ALTURA_CELULAR)      # simula um celular 20:9 no PC
    try:
        tela = pygame.display.set_mode((LARGURA, ALTURA), flags)
    except pygame.error:
        tela = pygame.display.set_mode((LARGURA, ALTURA))
    if tela.get_size() != (LARGURA, ALTURA):    # sem SCALED o SDL pode dar outro tamanho
        definir_tela(*tela.get_size())
    return tela, toque


def tela_carregando(tela):
    """Mostra a arte de capa (presplash.png) enquanto texturas e efeitos são gerados, o que no
    celular leva alguns segundos. Sem a imagem na pasta, simplesmente não mostra nada."""
    try:
        arte = pygame.image.load(os.path.join(PASTA, "presplash.png")).convert()
    except Exception:
        return
    w, h = tela.get_size()
    esc = min(w / arte.get_width(), h / arte.get_height())
    tam = (int(arte.get_width() * esc), int(arte.get_height() * esc))
    img = pygame.transform.smoothscale(arte, tam)
    x0, y0 = (w - tam[0]) // 2, (h - tam[1]) // 2
    # as faixas laterais (ou de cima/baixo) repetem a borda da arte, sem emenda visível
    if x0 > 0:
        tela.blit(pygame.transform.scale(img.subsurface((0, 0, 1, tam[1])), (x0, tam[1])), (0, y0))
        tela.blit(pygame.transform.scale(img.subsurface((tam[0] - 1, 0, 1, tam[1])),
                                         (w - x0 - tam[0], tam[1])), (x0 + tam[0], y0))
    if y0 > 0:
        tela.blit(pygame.transform.scale(img.subsurface((0, 0, tam[0], 1)), (tam[0], y0)), (x0, 0))
        tela.blit(pygame.transform.scale(img.subsurface((0, tam[1] - 1, tam[0], 1)),
                                         (tam[0], h - y0 - tam[1])), (x0, y0 + tam[1]))
    tela.blit(img, (x0, y0))
    APRESENTACAO.mostrar() if APRESENTACAO else pygame.display.flip()


async def main():
    pygame.mixer.pre_init(44100, -16, 2, 512)       # buffer pequeno: efeitos sem atraso perceptível
    pygame.init()
    forcar = "--toque" in sys.argv[1:]
    try:                                            # ícone da janela (no PC); ignora se não houver
        pygame.display.set_icon(pygame.image.load(os.path.join(PASTA, "icon.png")))
    except Exception:
        pass
    tela, toque = abrir_tela(forcar)
    pygame.display.set_caption("Náufrago — sobrevivência e horror cósmico")
    tela_carregando(tela)
    await asyncio.sleep(0)                          # deixa o quadro aparecer antes do trabalho pesado
    relogio = pygame.time.Clock()
    jogo = Jogo(tela, modo_toque=toque, travar_toque=forcar)

    if "--visitar-vila" in sys.argv:
        jogo.estado = "jogando"
        jogo.t = tempo_da_fase(.43)
        jogo.ilha = (0, -430)
        jogo.barco.ang = -math.pi/2
        jogo.msg("Vila à vista! Siga a bússola até o cais.", VERDE)

    while True:
        dt = min(relogio.tick(FPS) / 1000.0, 0.05)
        for ev in pygame.event.get():
            if APRESENTACAO:
                ev = APRESENTACAO.evento(ev)
            if ev is not None:
                jogo.evento(ev)
        jogo.atualizar(dt, jogo.teclas(pygame.key.get_pressed()))
        jogo.desenhar()
        APRESENTACAO.mostrar() if APRESENTACAO else pygame.display.flip()
        await asyncio.sleep(0)      # exigido pelo pygbag; no PC/Android não atrapalha


if __name__ == "__main__":
    asyncio.run(main())
