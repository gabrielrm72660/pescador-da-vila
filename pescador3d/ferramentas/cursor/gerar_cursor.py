"""v0.7.4: cursor do mouse do Bruma (seta em aquarela turquesa, dourada sobre o que dá para clicar).
Desenha 8x maior e reduz para 40x40. Uso: python3 ferramentas/cursor/gerar_cursor.py"""
import math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont
S = 8          # desenha 8x maior e reduz (bordas suaves)
T = 40         # tamanho final (px)
CREME=(245,237,214,255); NANQ=(34,28,22,255); OURO=(232,174,66,255); OURO_E=(170,110,30,255)
TURQ=(48,170,165,255); TURQ_E=(20,95,100,255); VERM=(176,52,38,255); AZUL=(26,48,72,255); LATAO=(200,160,80,255)
def tela(): return Image.new("RGBA",(T*S,T*S),(0,0,0,0))
def pts(lst): return [(x*S,y*S) for x,y in lst]
def tremido(lst, amp=0.25, seed=1):
    r=random.Random(seed); return [(x+r.uniform(-amp,amp), y+r.uniform(-amp,amp)) for x,y in lst]
def sombra(img, dx=1.2, dy=1.6, a=110):
    al=img.split()[3].filter(ImageFilter.GaussianBlur(S*0.9))
    sh=Image.new("RGBA",img.size,(0,0,0,0)); sh.putalpha(al.point(lambda v: v*a//255))
    base=Image.new("RGBA",img.size,(0,0,0,0)); base.alpha_composite(sh,(int(dx*S),int(dy*S))); base.alpha_composite(img); return base
def final(img): return sombra(img).resize((T,T),Image.LANCZOS)

def seta_nanquim(hover=False):
    im=tela(); d=ImageDraw.Draw(im)
    forma=[(2,2),(2,27),(8.5,21),(13,31),(17.5,29),(13,19.5),(21.5,19.5)]
    d.polygon(pts(tremido(forma,0.18,3)), fill=NANQ)
    dentro=[(4.2,6.6),(4.2,22.5),(9.1,17.8),(13.8,27.9),(15.3,27.2),(10.6,17.5),(17.1,17.5)]
    d.polygon(pts(dentro), fill=OURO if hover else CREME)
    d.line(pts([(4.6,8),(4.6,15)]), fill=(255,255,255,170), width=S)   # brilho
    return final(im)

def agulha(hover=False):
    im=tela(); d=ImageDraw.Draw(im)
    # agulha de bússola inclinada: ponta vermelha no canto (hotspot 2,2)
    a=math.radians(-45); c=(17,17)
    def rot(p): x,y=p[0]-c[0],p[1]-c[1]; return (c[0]+x*math.cos(a)-y*math.sin(a), c[1]+x*math.sin(a)+y*math.cos(a))
    ponta=[rot(p) for p in [(17,-3.6),(21,17),(13,17)]]
    cauda=[rot(p) for p in [(21,17),(17,37.6),(13,17)]]
    d.polygon(pts(ponta), fill=VERM if not hover else OURO, outline=NANQ, width=int(S*0.9))
    d.polygon(pts(cauda), fill=AZUL, outline=NANQ, width=int(S*0.9))
    d.ellipse([ (c[0]-3.2)*S,(c[1]-3.2)*S,(c[0]+3.2)*S,(c[1]+3.2)*S], fill=LATAO, outline=NANQ, width=int(S*0.8))
    return final(im)

def anzol(hover=False):
    im=tela(); d=ImageDraw.Draw(im)
    cor=OURO if not hover else CREME
    # haste do canto superior esquerdo para baixo, curva e farpa; ponta no (3,3)
    # olho
    d.ellipse([20*S,1*S,27*S,8*S], outline=NANQ, width=int(S*3.2)); d.ellipse([20*S,1*S,27*S,8*S], outline=cor, width=int(S*1.6))
    curva=[]
    for k in range(0,181,6):
        t=math.radians(k); curva.append((16+8*math.cos(t), 27+8*math.sin(t)*-1*-1))
    haste=[(24,7.5),(24,27)]
    linha=[(24,7.5),(24,27)]+[(16+8*math.cos(math.radians(k)), 27+8*math.sin(math.radians(k))) for k in range(0,181,6)]+[(8,27),(8,16),(4.5,12.5)]
    d.line(pts(linha), fill=NANQ, width=int(S*4.2), joint="curve")
    d.line(pts(linha), fill=cor, width=int(S*2.2), joint="curve")
    d.polygon(pts([(8,13),(3,3),(11.5,11)]), fill=NANQ)
    d.polygon(pts([(8.2,12.2),(4.4,5.4),(10.2,10.6)]), fill=cor)
    return final(im)

def seta_aquarela(hover=False):
    im=tela(); d=ImageDraw.Draw(im)
    forma=[(2,2),(2,26),(8.3,20.5),(12.5,30),(17,28),(12.8,19),(21,19)]
    d.polygon(pts(forma), fill=CREME)
    dentro=[(4.3,7),(4.3,21),(9,16.8),(13.6,26.8),(14.8,26.2),(10.4,16.6),(16.4,16.6)]
    cor= OURO if hover else TURQ
    d.polygon(pts(dentro), fill=cor)
    # mancha mais escura de aquarela
    d.polygon(pts([(4.3,14),(4.3,21),(9,16.8),(10.4,16.6),(7,13)]), fill=(OURO_E if hover else TURQ_E))
    return final(im)

if __name__ == "__main__":
    import pathlib
    destino = pathlib.Path(__file__).resolve().parent.parent.parent / "assets" / "cursor"
    destino.mkdir(parents=True, exist_ok=True)
    seta_aquarela().save(destino / "seta.png")
    seta_aquarela(True).save(destino / "seta_sobre.png")
    print("ok")
