# -*- coding: utf-8 -*-
"""v0.6.0: recorta a Noto Sans CJK SC (licença OFL) só com os ideogramas que o jogo usa, para o chinês caber em ~1 MB.
Rode de novo sempre que mudar um texto em chinês:  python3 ferramentas/idioma/subset_fonte.py"""
import subprocess, os, re, glob

caracteres = set("中文")
for arq in glob.glob('scripts/*.gd'):
    for c in open(arq, encoding='utf-8').read():
        if ord(c) > 0x2E80:
            caracteres.add(c)
# pontuação chinesa e alguns símbolos de uso comum
caracteres.update("，。！？：；（）、“”‘’…—·《》【】 ～—×→←↑↓•%+-/0123456789")
os.makedirs('assets/fontes', exist_ok=True)
open('/tmp/chars_zh.txt', 'w', encoding='utf-8').write(''.join(sorted(caracteres)))
print(len(caracteres), 'caracteres')
for peso, destino in [('Regular', 'NotoSansSC-Regular-subset.otf'), ('Bold', 'NotoSansSC-Bold-subset.otf')]:
    origem = '/usr/share/fonts/opentype/noto/NotoSansCJK-%s.ttc' % peso
    saida = 'assets/fontes/' + destino
    subprocess.run(['pyftsubset', origem, '--font-number=2', '--text-file=/tmp/chars_zh.txt', '--output-file=' + saida,
                    '--layout-features=*', '--no-hinting', '--desubroutinize'], check=True)
    print(destino, os.path.getsize(saida) // 1024, 'KB')
