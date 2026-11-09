"""Oceano pixel art procedural: relevo animado em tiles e cristas em coordenadas do mundo."""
import math
import os
from collections import OrderedDict
import pygame


def mistura(a, b, f):
    return tuple(round(x+(y-x)*f) for x,y in zip(a,b))


class Oceano:
    TAM = 256
    FASES = 24
    def __init__(self, tamanho):
        self.cache = OrderedDict()
        self.fase = 0.0
        self.ultimo_tempo = None
        self.misturada = pygame.Surface((self.TAM, self.TAM))
        self.temporal = pygame.Surface((self.TAM, self.TAM))
        self.ampliada = pygame.Surface((512, 512))
        self.borda = pygame.Surface((513,513))
        self.horizontal = pygame.Surface((512,513))
        self.auxiliar = pygame.Surface((512,513))
        self.final = pygame.Surface((512,512))
        caminho = os.path.join(os.path.dirname(__file__), "imagens", "oceano_aprovado.png")
        self.fonte = None
        if os.path.isfile(caminho):
            raw = pygame.image.load(caminho).convert()
            self.fonte = pygame.transform.smoothscale(raw,(256,256))
        self.alturas = []
        # Mais amostras espaciais, sem cortes bruscos de altura em sete tons.
        for frame in range(0 if self.fonte is not None else self.FASES):
            fase = frame*math.tau/self.FASES
            mapa = []
            for y in range(self.TAM):
                linha=[]
                for x in range(self.TAM):
                    u,v=x*math.tau/self.TAM,y*math.tau/self.TAM
                    onda=(math.sin(u*2+v*3+fase)*.46 +
                          math.sin(u*4-v*2-fase)*.29 +
                          math.sin(u*7+v*5+fase*2)*.16 +
                          math.sin(u*11-v*8-fase)*.09)
                    linha.append(max(0,min(63,int((onda+1)*31.5))))
                mapa.append(linha)
            self.alturas.append(mapa)
        # Pré-carrega: nenhuma geração de textura durante a partida.
        for frame in range(self.FASES):
            for clima in range(3): self.tile(frame, clima)

    def tile(self, frame, clima):
        chave=(frame, clima)
        if chave in self.cache:return self.cache[chave]
        if self.fonte is not None:
            s=pygame.Surface((self.TAM,self.TAM))
            fase=frame*math.tau/self.FASES
            for y in range(self.TAM):
                desloc=round(2.5*math.sin(y*math.tau/self.TAM+fase))
                faixa=pygame.Rect(0,y,self.TAM,1)
                for x in (desloc-self.TAM,desloc,desloc+self.TAM):s.blit(self.fonte,(x,y),faixa)
            s.fill(((48,65,110),(235,250,245),(110,139,155))[clima],special_flags=pygame.BLEND_RGB_MULT)
            self.cache[chave]=s
            return s
        fundo,topo=(((7,21,43),(14,40,63)),
                    ((20,94,130),(44,139,162)),
                    ((26,55,71),(68,102,112)))[clima]
        pal=[mistura(fundo,topo,k/63) for k in range(64)]
        s=pygame.Surface((self.TAM,self.TAM))
        px=pygame.PixelArray(s)
        cores=[s.map_rgb(c) for c in pal]
        for y,linha in enumerate(self.alturas[frame]):
            for x,k in enumerate(linha):px[x,y]=cores[k]
        del px
        self.cache[chave]=s
        return s

    def _clima(self, destino, frame, brilho, tempestade):
        destino.blit(self.tile(frame,0),(0,0))
        dia=self.tile(frame,1)
        dia.set_alpha(round(max(0,min(1,brilho))*255))
        destino.blit(dia,(0,0));dia.set_alpha(None)
        chuva=self.tile(frame,2)
        chuva.set_alpha(round(max(0,min(1,tempestade))*.8*255))
        destino.blit(chuva,(0,0));chuva.set_alpha(None)

    def desenhar(self, tela, tempo, cx, cy, brilho, tempestade, leve):
        dt=0 if self.ultimo_tempo is None else max(0,tempo-self.ultimo_tempo)
        self.ultimo_tempo=tempo
        # Integra a velocidade: mudar o clima não salta para outra fase.
        self.fase=(self.fase+dt*(2.2+tempestade*1.6))%self.FASES
        base=int(self.fase)
        self._clima(self.misturada,base,brilho,tempestade)
        self._clima(self.temporal,(base+1)%self.FASES,brilho,tempestade)
        self.temporal.set_alpha(round((self.fase%1)*255))
        self.misturada.blit(self.temporal,(0,0))
        self.temporal.set_alpha(None)
        # Filtragem apenas da água; sprites e interface mantêm seus pixels nítidos.
        pygame.transform.smoothscale(self.misturada,(512,512),self.ampliada)
        # Interpolação subpixel evita pequenos trancos ao navegar devagar.
        dx,dy=cx+tempo*7.2,cy+tempo*2.8
        nx,ny=math.floor(dx),math.floor(dy)
        fx,fy=dx-nx,dy-ny
        self.borda.blit(self.ampliada,(0,0))
        self.borda.blit(self.ampliada,(512,0),pygame.Rect(0,0,1,512))
        self.borda.blit(self.ampliada,(0,512),pygame.Rect(0,0,512,1))
        self.borda.set_at((512,512),self.ampliada.get_at((0,0)))
        self.horizontal.blit(self.borda,(0,0),pygame.Rect(0,0,512,513))
        self.auxiliar.blit(self.borda,(0,0),pygame.Rect(1,0,512,513))
        self.auxiliar.set_alpha(round(fx*255))
        self.horizontal.blit(self.auxiliar,(0,0));self.auxiliar.set_alpha(None)
        self.final.blit(self.horizontal,(0,0))
        self.horizontal.set_alpha(round(fy*255))
        self.final.blit(self.horizontal,(0,0),pygame.Rect(0,1,512,512))
        self.horizontal.set_alpha(None)
        ox=-(nx%512);oy=-(ny%512)
        for x in range(ox,tela.get_width(),512):
            for y in range(oy,tela.get_height(),512):tela.blit(self.final,(x,y))
        return mistura(mistura((10,30,50),(31,116,146),brilho),(40,74,88),tempestade*.7)

    def superficie(self, tela, tempo, cx, cy, brilho, tempestade, leve, agua):
        w,h=tela.get_size()
        passo=108 if leve else 78
        for ix in range(int(cx//passo)-1,int((cx+w)//passo)+2):
            for iy in range(int(cy//passo)-1,int((cy+h)//passo)+2):
                seed=((ix*73856093)^(iy*19349663))&0xffffff
                if seed%4==0:continue
                fase=tempo*.7+seed%103
                forca=max(0,math.sin(fase))
                if forca<.01:continue
                x=ix*passo+seed%53-cx+math.sin(fase*.4)*5
                y=iy*passo+(seed>>6)%49-cy+math.sin(fase)*3
                largura=8+(seed>>12)%19
                clara=mistura(agua,(170,220,218),forca*(.12+brilho*.27+tempestade*.12))
                pts=[(round(x-largura),round(y+2)),(round(x-largura*.6),round(y+2)),
                     (round(x-largura*.6),round(y)),(round(x+largura*.2),round(y)),
                     (round(x+largura*.2),round(y-2)),(round(x+largura),round(y-2))]
                pygame.draw.lines(tela,clara,False,pts,2)
                # Espuma quebrada nas cristas, mais presente durante a tempestade.
                if tempestade>.35 and forca>.7:
                    for k in range(3):
                        pygame.draw.rect(tela,mistura(clara,(209,228,222), min(1, (forca-.7)/.3)*min(1, (tempestade-.35)/.3)*.45),
                            (round(x-largura+k*9),round(y+5+k%2*2),4,2))
                if brilho>.5 and seed%11==0 and forca>.94:
                    pygame.draw.rect(tela,mistura(agua,(184,227,219), min(1,(forca-.94)/.06)*min(1,(brilho-.5)*2)),(round(x),round(y-5),5,2))
