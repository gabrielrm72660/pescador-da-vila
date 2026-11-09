"""Gera jogo/icon.png, jogo/presplash.png e jogo/favicon.png a partir de arte/capa.png.

Uso (na pasta naufrago_mobile):   python arte/gerar_arte.py
Se trocar a capa por outra imagem, ajuste RECORTE_ICONE (x, y, lado) para o quadrado
da arte que deve virar o ícone.
"""
import os

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
import pygame

AQUI = os.path.dirname(os.path.abspath(__file__))
DESTINO = os.path.join(os.path.dirname(AQUI), "jogo")
RECORTE_ICONE = (570, 92, 531)      # x, y e lado do quadrado da arte na capa de 1672x941

pygame.init()
pygame.display.set_mode((8, 8))
capa = pygame.image.load(os.path.join(AQUI, "capa.png")).convert()
x, y, lado = RECORTE_ICONE
icone = pygame.Surface((lado, lado))
icone.blit(capa, (0, 0), (x, y, lado, lado))


def salvar(img, tam, nome):
    pygame.image.save(pygame.transform.smoothscale(img, tam), os.path.join(DESTINO, nome))


salvar(icone, (512, 512), "icon.png")           # ícone do app (Android) e da janela (PC)
salvar(icone, (256, 256), "favicon.png")        # ícone e tela de espera no navegador (pygbag)
salvar(capa, (1280, 720), "presplash.png")      # tela de carregamento
print("ok:", DESTINO)
