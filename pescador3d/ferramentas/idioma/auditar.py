"""Audita as traduções: lista os textos em português que o jogo mostra e que não estão nas tabelas.
Uso: python3 ferramentas/idioma/auditar.py [--tudo]   (rode na pasta do projeto)
Fontes: T.t("..."), Idioma.t("..."), _t(controle, "..."), aviso("..."), mensagem.emit("..."), _texto(..., "...") do HUD,
e os dados de scripts/missoes.gd, scripts/npcs.gd, scripts/pesca.gd (comportamentos) e scripts/cardumes.gd (espécies)."""
import re, sys, glob, os, json

LIT = r'"((?:[^"\\]|\\.)*)"'
def unesc(s):
    return s.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\').replace('\\t', '\t')

def ler(p):
    return open(p, encoding='utf-8').read()

def chaves_tabela(arq, formato):
    """Chaves de uma tabela GDScript (const TABELA := { "pt": [...] })."""
    if not os.path.exists(arq):
        return set()
    txt = ler(arq)
    chaves = set()
    # chave = literal no começo da linha (após indentação) seguido de ':'
    for m in re.finditer(r'^\s+"((?:[^"\\]|\\.)*)"\s*:\s*', txt, re.M):
        chaves.add(unesc(m.group(1)))
    # chaves seguidas de quebra de linha antes do valor
    return chaves

def todos_literais(txt):
    return [unesc(m.group(1)) for m in re.finditer(LIT, txt)]

def eh_texto(s):
    if len(s) < 2: return False
    if not re.search(r'[A-Za-zÀ-ÿ]{2,}', s): return False
    if s.startswith('res://') or s.startswith('user://') or s.startswith('/'): return False
    return True

def main():
    tudo = '--tudo' in sys.argv
    tab = set()
    for arq in ['scripts/idioma.gd', 'scripts/idioma_conteudo.gd', 'scripts/idioma_zh.gd']:
        tab |= chaves_tabela(arq, None)
    achados = {}   # texto -> [(arquivo, categoria)]
    def add(txt, arq, cat):
        txt = txt.strip('\n') if False else txt
        if eh_texto(txt):
            achados.setdefault(txt, []).append((os.path.basename(arq), cat))

    for arq in sorted(glob.glob('scripts/*.gd')):
        if os.path.basename(arq) in ('idioma.gd', 'idioma_conteudo.gd', 'idioma_zh.gd'):
            continue
        txt = ler(arq)
        for m in re.finditer(r'\b(?:T|Idioma)\.t\(\s*' + LIT, txt):
            add(unesc(m.group(1)), arq, 'T.t')
        for m in re.finditer(r'\b_t\([^,()]*(?:\([^()]*\))?[^,()]*,\s*' + LIT, txt):
            add(unesc(m.group(1)), arq, '_t')
        for m in re.finditer(r'\baviso\(\s*(?:T\.t\()?\s*' + LIT, txt):
            add(unesc(m.group(1)), arq, 'aviso')
        for m in re.finditer(r'\bmensagem\.emit\(\s*\(?\s*(?:T\.t\()?\s*' + LIT, txt):
            add(unesc(m.group(1)), arq, 'mensagem')
        if os.path.basename(arq) == 'hud.gd':
            for m in re.finditer(r'\b_texto\([^"\n]*?,\s*' + LIT, txt):
                add(unesc(m.group(1)), arq, 'hud._texto')

    # dados
    miss = ler('scripts/missoes.gd')
    bloco = miss[miss.index('const LISTA'):]
    for m in re.finditer(r'"(?:texto|dica|titulo)"\s*:\s*' + LIT, bloco):
        add(unesc(m.group(1)), 'missoes.gd', 'missao')
    for m in re.finditer(r'"(?:oferta|fim)"\s*:\s*\[(.*?)\]', bloco, re.S):
        for l in todos_literais(m.group(1)):
            add(l, 'missoes.gd', 'fala')
    npcs = ler('scripts/npcs.gd')
    for m in re.finditer(r'"(?:nome|papel)"\s*:\s*' + LIT, npcs):
        add(unesc(m.group(1)), 'npcs.gd', 'npc')
    papo = npcs[npcs.index('const PAPO'):]
    for l in todos_literais(papo):
        add(l, 'npcs.gd', 'papo')
    pesca = ler('scripts/pesca.gd')
    for m in re.finditer(r'"(?:nome|dica)"\s*:\s*' + LIT, pesca[pesca.index('INFO_COMPORTAMENTO'):pesca.index('TENSAO_PESADO')]):
        add(unesc(m.group(1)), 'pesca.gd', 'comportamento')
    card = ler('scripts/cardumes.gd')
    bl = card[card.index('const ESPECIES'):]
    bl = bl[:bl.index('\n}\n')]
    for m in re.finditer(r'^\s*"([^"]+)"\s*:\s*\{', bl, re.M):
        add(m.group(1), 'cardumes.gd', 'especie')

    faltam = {k: v for k, v in achados.items() if k not in tab}
    por_cat = {}
    for k, v in faltam.items():
        por_cat.setdefault(v[0][1], []).append(k)
    print(f'{len(achados)} textos encontrados; {len(faltam)} sem tradução.')
    for cat, lst in sorted(por_cat.items()):
        print(f'  {cat}: {len(lst)}')
    if tudo:
        for cat, lst in sorted(por_cat.items()):
            print(f'\n=== {cat} ===')
            for k in lst:
                print(repr(k))
    json.dump(sorted(faltam), open('/tmp/faltam_traducao.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

main()
