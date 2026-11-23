# -*- coding: utf-8 -*-
"""Gera scripts/idioma_conteudo.gd (português -> [es, en, zh]) e scripts/idioma_zh.gd (português -> zh, dos textos antigos).
Rode na pasta do projeto:  python3 ferramentas/idioma/gerar.py"""
import re, json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from conteudo_a import A
from conteudo_b import B
from conteudo_c import C
from zh_existente import ZH_POR_EN

def unesc(s):
    return s.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\').replace('\\t', '\t')

def lit(s):
    return json.dumps(s, ensure_ascii=False)

txt = open('scripts/idioma.gd', encoding='utf-8').read()
bloco = txt[txt.index('const TABELA'):]
L = r'"((?:[^"\\]|\\.)*)"'
pares = re.findall(L + r'\s*:\s*\[\s*' + L + r'\s*,\s*' + L + r'\s*\]', bloco, re.S)
antigos = {unesc(k): (unesc(es), unesc(en)) for k, es, en in pares}
print(len(antigos), 'textos antigos (es/en)')

def achar_zh(en):
    if en in ZH_POR_EN:
        return ZH_POR_EN[en]
    cand = [k for k in ZH_POR_EN if len(k) >= 10 and en.startswith(k)]
    if cand:
        return ZH_POR_EN[max(cand, key=len)]
    return None

zh = {}
faltou = []
for pt, (es, en) in antigos.items():
    z = achar_zh(en)
    if z is None:
        faltou.append((pt, en))
    else:
        zh[pt] = z
if faltou:
    print('SEM chinês para', len(faltou), 'textos antigos:')
    for pt, en in faltou:
        print('  ', repr(en)[:110])

# o texto sobre idiomas mudou: a chave antiga fica sem uso
cont = {}
for d in (A, B, C):
    for pt, v in d.items():
        if len(v) != 3:
            print('tupla errada:', pt)
        cont[pt] = v

def tabela_gd(nome, dados, formato):
    linhas = ['extends RefCounted', formato, '', 'const TABELA := {']
    for k, v in dados.items():
        if isinstance(v, str):
            linhas.append('\t%s: %s,' % (lit(k), lit(v)))
        else:
            linhas.append('\t%s: [%s],' % (lit(k), ', '.join(lit(x) for x in v)))
    linhas.append('}')
    open('scripts/%s.gd' % nome, 'w', encoding='utf-8').write('\n'.join(linhas) + '\n')

tabela_gd('idioma_zh', zh, '## GERADO por ferramentas/idioma/gerar.py. português -> 中文 dos textos de menus e painéis (v0.5.6).')
tabela_gd('idioma_conteudo', cont, '## GERADO por ferramentas/idioma/gerar.py. português -> [español, english, 中文]: missões, falas, avisos, peixes (v0.6.0).')
print('ok:', len(zh), 'zh antigos,', len(cont), 'novos')
