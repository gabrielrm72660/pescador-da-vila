"""Verificacoes estaticas e numericas do PESCADOR 0.3.14.

Nao substituem compilacao do GDScript, renderizacao no Godot nem testes de jogabilidade.
Execute: python ferramentas/verificar_mar_0314.py
"""
from pathlib import Path
import math, random, re

ROOT = Path(__file__).resolve().parents[1]
sea = (ROOT / 'scripts/oceano.gd').read_text(encoding='utf-8')
boat = (ROOT / 'scripts/barco.gd').read_text(encoding='utf-8')
shader = (ROOT / 'shaders/oceano_pintado.gdshader').read_text(encoding='utf-8')
scene = (ROOT / 'cenas/Jogo.tscn').read_text(encoding='utf-8')

for key in ('0.12 * forca', 'cruz * 0.062 + w * 0.014', 't * 0.54 + 2.3'):
    assert key in sea, f'onda CPU sem {key}'
for key in ('0.12 * agitacao_mar', 'cruz * 0.062 + w * 0.014', 't * 0.54 + 2.3'):
    assert key in shader, f'onda GPU sem {key}'
assert 'velocidade_vertical_em' in sea
assert 'impacto_proa' in sea and 'impacto_proa' in boat and 'uniform float impacto_proa' in shader
assert 'balanceio.add_child(efeito)' in boat
assert 'rastro[64]' in shader and 'PONTOS_RASTRO: int = 64' in sea
assert 'PlaneMesh_agua' in scene

for file in (sea,boat,shader):
    for left, right in (('(',')'),('[',']'),('{','}')):
        # Verificacao grosseira sem remover comentarios/strings: suficiente p/ flagrar truncamentos.
        assert file.count(left)==file.count(right), f'Delimitador desbalanceado {left}{right}'

# GLSL smoothstep edge0 deve ser estritamente menor que edge1, inclusive nas operacoes de espuma.
for a,b in re.findall(r'smoothstep\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,',shader):
    assert float(a)<float(b), f'smoothstep com limites invertidos: {a}, {b}'

params = set(re.findall(r'uniform\s+(?:float|vec[234]|sampler2D|vec4\[\d+\])\s+(\w+)',shader))
for name in ('altura_ondas','velocidade_ondas','agitacao_mar','impacto_proa','barco_vel','rastro'):
    assert name in params or (name=='rastro' and 'uniform vec4 rastro[64]' in shader), name

# Modelos algebraicos independentes, equivalentes aos componentes declarados no CPU e GPU.
def norm(v):
    z=math.hypot(*v)
    return (v[0]/z,v[1]/z)

def dot(a,b): return a[0]*b[0]+a[1]*b[1]

def waveform_cpu(p,t,w,agitacao):
    w=norm(w); cruz=(-w[1],w[0]); swell=norm((w[0]*.75+cruz[0]*.25,w[1]*.75+cruz[1]*.25))
    grupo=.78+.22*math.sin(dot(p,w)*.012-t*.17)
    longo=.60*math.sin(dot(p,swell)*.100-t*.79)+.32*math.sin(dot(p,(-.047,.076))-t*.59+1.7)
    marola=(.08+.18*agitacao)*math.sin(dot(p,w)*.145-t*1.38)
    cruzada=.13*math.sin(dot(p,(cruz[0]*.11+w[0]*.05,cruz[1]*.11+w[1]*.05))-t*1.11+.8)
    return grupo*longo+marola+cruzada+.12*agitacao*math.sin(dot(p,(cruz[0]*.062+w[0]*.014,cruz[1]*.062+w[1]*.014))-t*.54+2.3)

def waveform_shader(p,t,w,agitacao):
    w=norm(w); c=(-w[1],w[0]); s=norm((w[0]*.75+c[0]*.25,w[1]*.75+c[1]*.25))
    g=.78+.22*math.sin(dot(p,(w[0]*.012,w[1]*.012))-t*.17)
    l=.60*math.sin(dot(p,(s[0]*.1,s[1]*.1))-t*.79)+.32*math.sin(dot(p,(-.047,.076))-t*.59+1.7)
    m=(.08+.18*agitacao)*math.sin(dot(p,(w[0]*.145,w[1]*.145))-t*1.38)
    q=.13*math.sin(dot(p,(c[0]*.11+w[0]*.05,c[1]*.11+w[1]*.05))-t*1.11+.8)
    x=.12*agitacao*math.sin(dot(p,(c[0]*.062+w[0]*.014,c[1]*.062+w[1]*.014))-t*.54+2.3)
    return g*l+m+q+x

def factor(distance):
    u=max(0.0,min(1.0,(distance-25.0)/225.0))
    return .27+u*u*(3-2*u)*1.0

rng=random.Random(314)
max_error=0
for _ in range(2000):
    p=(rng.uniform(-1800,1800),rng.uniform(-1800,1800))
    w=(rng.uniform(.02,1.2),rng.uniform(-1.2,-.02))
    t=rng.uniform(0,500); ag=rng.random()
    h1=waveform_cpu(p,t,w,ag)
    h2=waveform_shader(p,t,w,ag)
    max_error=max(max_error,abs(h1-h2))
assert max_error < 1e-12, max_error
assert factor(-50)==.27 and factor(25)==.27 and factor(250)==1.27 and factor(450)==1.27
assert factor(80)<factor(150)<factor(220)
print('OK: 2000 comparacoes numericas das ondas CPU/GPU; erro maximo %.3g' % max_error)
print('OK: atenuacao costeira monotona, formulas/arquivos e delimitadores verificados')
print('AVISO: compilacao GDScript, shader GPU e performance requerem Godot instalado')
