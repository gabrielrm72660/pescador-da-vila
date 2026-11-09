"""Efeitos visuais em coordenadas do mundo, independentes das regras do jogo."""
import math
import random
import pygame


class Animacoes:
    def __init__(self):
        self.rng = random.Random()  # efeitos não alteram os sorteios da partida
        self.particulas = []
        self.aneis = []
        self.tempo = 0.0
        self.emissao = 0.0
        self.ciclo = 0.0
        self.esforco = 0.0

    def rajada(self, x, y, cor=(180, 225, 232), quantidade=12):
        for _ in range(quantidade):
            a = self.rng.uniform(0, math.tau)
            v = self.rng.uniform(18, 68)
            vida = self.rng.uniform(.35, .8)
            self.particulas.append([x, y, math.cos(a)*v, math.sin(a)*v,
                                    vida, vida, cor, self.rng.choice((2, 2, 3))])
        self.particulas = self.particulas[-180:]
        self.aneis.append([x, y, 0.0, .7, cor])
        self.aneis = self.aneis[-36:]

    def atualizar(self, dt, barco, leve=False, remos_longos=False):
        self.tempo += dt
        self.esforco += (float(barco.remando)-self.esforco)*(1-math.exp(-7*dt))
        anterior = self.ciclo
        self.ciclo += dt * .95 * (1.2 if remos_longos else 1.0) if self.esforco > .01 else 0
        # Entrada das pás na água: um pulso por remada, independente do FPS.
        if int(self.ciclo + .85) != int(anterior + .85) and self.esforco > .3:
            for lado in (-1, 1):
                a = barco.ang
                dist = 55 if remos_longos else 43
                x = barco.x - math.cos(a)*8 - math.sin(a)*lado*dist
                y = barco.y - math.sin(a)*8 + math.cos(a)*lado*dist
                self.rajada(x, y, quantidade=3 if leve else 7)
        self.emissao -= dt
        if barco.vel > 25 and self.emissao <= 0:
            self.emissao = .20 if leve else .10
            a = barco.ang
            v = min(1, barco.vel/185)
            for lado in (-1, 1):
                x = barco.x - math.cos(a)*30 - math.sin(a)*lado*16
                y = barco.y - math.sin(a)*30 + math.cos(a)*lado*16
                self.particulas.append([x, y, -math.cos(a)*12-math.sin(a)*lado*22*v,
                    -math.sin(a)*12+math.cos(a)*lado*22*v, 1.1, 1.1, (180, 225, 232), 3])
        for p in self.particulas:
            p[0] += p[2]*dt
            p[1] += p[3]*dt
            p[2] *= math.exp(-1.2*dt)
            p[3] *= math.exp(-1.2*dt)
            p[4] -= dt
        self.particulas = [p for p in self.particulas if p[4] > 0][-180:]
        for r in self.aneis:
            r[2] += dt
        self.aneis = [r for r in self.aneis if r[2] < r[3]][-36:]

    def pose(self, barco, tempestade):
        t = self.tempo
        onda = math.sin(t*1.8) + .35*math.sin(t*3.1 + 1.2)
        altura = onda*(1.3 + tempestade*3)
        giro = (math.sin(t*1.3)*.023 + math.sin(t*2.4)*.008)*(1+tempestade*2)
        giro -= barco.timao*min(abs(barco.vel)/185, 1)*.035
        return altura, giro

    def desenhar(self, tela, cx, cy, agua):
        w, h = tela.get_size()
        def cor(c, f):
            return tuple(round(agua[i] + (c[i]-agua[i])*f) for i in range(3))
        for x, y, idade, vida, c in self.aneis:
            sx, sy = round(x-cx), round(y-cy)
            if -60 < sx < w+60 and -60 < sy < h+60:
                f = idade/vida
                raio = round(4+26*f)
                pygame.draw.ellipse(tela, cor(c, (1-f)*.65),
                    (sx-raio, sy-raio//2, raio*2, max(2, raio)), 1)
        for x, y, vx, vy, vida, total, c, tamanho in self.particulas:
            sx, sy = round(x-cx), round(y-cy)
            if 0 <= sx < w and 0 <= sy < h:
                f = vida/total
                k = max(1, round(tamanho*f))
                pygame.draw.rect(tela, cor(c, f*.85), (sx, sy, k, k))
