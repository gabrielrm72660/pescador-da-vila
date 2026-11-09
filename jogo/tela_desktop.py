"""Apresentação desktop: resolução lógica fixa, tela cheia e mouse proporcional."""
import pygame

class TelaDesktop:
    def __init__(self, tamanho=(1280, 720), cheia=True):
        self.logica = pygame.Surface(tamanho)
        self.monitor = pygame.display.get_desktop_sizes()[0]
        mw, mh = self.monitor
        fator = min(mw * .90 / tamanho[0], mh * .86 / tamanho[1])
        self.janela_tamanho = (max(320, round(tamanho[0]*fator)), max(240, round(tamanho[1]*fator)))
        self.cheia = cheia
        self._abrir()

    def _abrir(self):
        if self.cheia:
            self.janela = pygame.display.set_mode(self.monitor, pygame.FULLSCREEN)
        else:
            self.janela = pygame.display.set_mode(self.janela_tamanho, pygame.RESIZABLE)
        self._layout()

    def _layout(self):
        w,h = self.janela.get_size()
        lw,lh = self.logica.get_size()
        escala = min(w/lw, h/lh)
        vw,vh = max(1,round(lw*escala)),max(1,round(lh*escala))
        self.area = pygame.Rect((w-vw)//2,(h-vh)//2,vw,vh)
        self.ampliada = pygame.Surface((vw,vh)).convert()

    def alternar(self):
        if not self.cheia:
            self.janela_tamanho = self.janela.get_size()
        self.cheia = not self.cheia
        self._abrir()

    def posicao(self, pos):
        lw,lh=self.logica.get_size()
        return (int((pos[0]-self.area.x)*lw/self.area.w), int((pos[1]-self.area.y)*lh/self.area.h))

    def evento(self, ev):
        if ev.type == pygame.KEYDOWN and (ev.key == pygame.K_F11 or
            (ev.key == pygame.K_RETURN and getattr(ev,'mod',0) & pygame.KMOD_ALT)):
            self.alternar()
            return None
        if ev.type in (pygame.VIDEORESIZE, pygame.WINDOWSIZECHANGED):
            if not self.cheia:
                self.janela_tamanho = pygame.display.get_surface().get_size()
            self.janela = pygame.display.get_surface()
            self._layout()
            return None
        if ev.type in (pygame.MOUSEBUTTONDOWN,pygame.MOUSEBUTTONUP,pygame.MOUSEMOTION):
            dados=ev.dict.copy()
            dados['pos']=self.posicao(ev.pos)
            if ev.type == pygame.MOUSEMOTION:
                lw,lh=self.logica.get_size()
                dados['rel']=(round(ev.rel[0]*lw/self.area.w),round(ev.rel[1]*lh/self.area.h))
            if ev.type == pygame.MOUSEBUTTONDOWN and not self.area.collidepoint(ev.pos):
                return None
            return pygame.event.Event(ev.type,dados)
        if ev.type in (pygame.FINGERDOWN,pygame.FINGERMOTION,pygame.FINGERUP):
            w,h=self.janela.get_size(); lw,lh=self.logica.get_size()
            px,py=self.posicao((ev.x*w,ev.y*h)); dados=ev.dict.copy()
            dados.update(x=px/lw,y=py/lh)
            if ev.type == pygame.FINGERDOWN and not (0<=px<lw and 0<=py<lh):
                return None
            return pygame.event.Event(ev.type,dados)
        return ev

    def mostrar(self):
        self.janela.fill((0,0,0))
        # Nearest-neighbor preserva os pixels ao ampliar.
        pygame.transform.scale(self.logica,self.area.size,self.ampliada)
        self.janela.blit(self.ampliada,self.area)
        pygame.display.flip()
