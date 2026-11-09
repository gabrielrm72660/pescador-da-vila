"""Terreno da ilha tropical e máscara de chegada à praia."""
import pygame

class IlhaVila:
    CAIS = (0, 235)
    FOGO = (145, 195)

    def __init__(self):
        self.terra = None

    def preparar(self, surf, costa, S, arte):
        self.S = S
        mask = pygame.Surface((2*S, 2*S), pygame.SRCALPHA)
        pygame.draw.polygon(mask, (255, 255, 255), [(S+x*.98, S+y*.98) for x,y in costa])
        self.terra = pygame.mask.from_surface(mask)

    def chegou(self, x, y):
        if self.terra is None:
            return False
        px, py = round(x+self.S), round(y+self.S)
        return 0 <= px < 2*self.S and 0 <= py < 2*self.S and bool(self.terra.get_at((px, py)))

    def desenhar(self, tela, centro, tempo, arte=None):
        pass
