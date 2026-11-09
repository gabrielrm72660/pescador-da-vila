# Náufrago → Pescador da Vila — especificação de design

Data: 09/11/2026 · Base: `naufrago_mobile` versão "Tela Grande" · Abordagem escolhida: **módulos novos ao lado do `main.py`**

## 1. Objetivo

Transformar o jogo de sobrevivência ("chegar à ilha e ser salvo") num jogo de **pesca com progressão**: o jogador é um
pescador de uma vila, sai com um pesqueiro a motor e vela, pesca 18 espécies de tamanhos aleatórios em águas rasas,
profundas e abissais, enche o porão, volta à vila para vender e compra melhorias. Um catálogo registra espécies e
recordes. A sobrevivência e o horror cósmico continuam como estão.

**Sucesso =** dá para jogar o ciclo completo (sair → pescar → encher o porão → vender → comprar vara/porão/motor →
alcançar uma zona mais funda) no PC, no modo `--toque` e no Android, com a partida salva entre sessões.

### Decisões do usuário (09/11/2026)

| Tema | Decisão |
|---|---|
| Ciclo | Pescar → vender → melhorar **e** catálogo com recordes e raras |
| Sobrevivência e horror | **Mantidos como estão** (fome, sede, sanidade, lanterna, criaturas à noite) |
| Pescaria | Parar no cardume e **acertar um medidor de tempo** (sem fase de briga) |
| Arte das espécies | **SpriteCook** |
| Profundidade | **Regiões fixas no mapa**, indicadas pela cor da água |
| Escopo | **18 espécies**, 6 por zona (com uma rara e uma lendária por zona) |
| Código | **Módulos novos** chamados pelo `main.py` |

Os números abaixo marcados *(proposta)* são valores iniciais para balancear depois; ficam todos em constantes no topo
de cada módulo.

## 2. Arquitetura

```
jogo/
├─ main.py          (existente) laço, desenho, HUD, entrada; passa a usar os módulos abaixo
├─ especies.py      tabela das 18 espécies + sorteio de tamanho/peso/volume/preço
├─ pesca.py         medidor de fisgada e regras das varas
├─ porao.py         inventário por volume
├─ mercado.py       preços de venda, loja e carteira
├─ mapa_fundo.py    regiões de profundidade do mar
├─ catalogo.py      catálogo, recordes e salvamento (JSON)
└─ testes/          testes de unidade dos módulos acima (unittest, sem pygame)
```

Regra de isolamento: **`especies`, `pesca`, `porao`, `mercado`, `mapa_fundo` e `catalogo` não importam pygame**. São
lógica pura, testável sem tela. O desenho de cardumes, medidor, porão e vila fica no `main.py` (ou num `desenho_*.py`
se o arquivo crescer), lendo o estado desses módulos.

## 3. Espécies (`especies.py`)

### 3.1 Dados

```python
@dataclass(frozen=True)
class Especie:
    id: str            # "sardinha"
    nome: str          # "Sardinha"
    zona: int          # 0 rasa, 1 profunda, 2 abissal
    categoria: str     # "comum" | "crustaceo" | "arraia" | "especial" | "rara" | "lendaria"
    raridade: str      # "comum" | "incomum" | "rara" | "lendaria"
    tam_min: float     # cm
    tam_max: float     # cm
    k_peso: float      # peso (kg) = k_peso * (tam/100)**3
    vol_medio: float   # litros ocupados no porão por um exemplar de tamanho médio
    preco_base: float  # R$ de um exemplar de tamanho médio, comum
    horario: str       # "qualquer" | "noite_mais" | "so_noite"
    clima: str         # "qualquer" | "tempestade"
    estilo: str        # estilo do cardume (ver 3.4)
    qtd: tuple         # (mín, máx) de silhuetas desenhadas no cardume
```

### 3.2 As 18 espécies

| Zona | id | Raridade | Tamanho (cm) | Estilo | Horário / clima |
|---|---|---|---|---|---|
| Rasa | sardinha | comum | 12–25 | bola | qualquer |
| Rasa | tainha | comum | 30–80 | grupo | qualquer |
| Rasa | siri_azul | incomum | 8–20 | fundo | qualquer |
| Rasa | arraia_pintada | incomum | 40–150 | planando | qualquer |
| Rasa | robalo | rara | 40–120 | grupo_pequeno | qualquer |
| Rasa | mero | lendária | 80–250 | gigante | qualquer |
| Profunda | atum | comum | 60–250 | rapido | qualquer |
| Profunda | dourado | comum | 50–150 | rapido (brilho verde) | qualquer |
| Profunda | caranguejo_real | incomum | 15–40 | fundo | qualquer |
| Profunda | jamanta | incomum | 200–600 | planando | qualquer |
| Profunda | espadarte | rara | 120–400 | linha | qualquer |
| Profunda | marlim_azul | lendária | 150–450 | saltos | qualquer |
| Abissal | peixe_lanterna | comum | 3–15 | luzes_nuvem | noite_mais |
| Abissal | tamboril | comum | 20–100 | isca_luz | noite_mais |
| Abissal | caranguejo_aranha | incomum | 60–370 | fundo_lento | noite_mais |
| Abissal | peixe_vibora | incomum | 20–35 | luzes_sozinho | noite_mais |
| Abissal | lula_gigante | rara | 300–1200 | tentaculos_luz | noite_mais |
| Abissal | devorador_palido | lendária | 400–1500 | silhueta_palida | so_noite + tempestade |

Faixas de tamanho: sardinha e mero vieram do design; as demais são *(proposta)* e estão na planilha
`Naufrago_Especies_e_Cardumes.xlsx`.

### 3.3 Sorteio de um exemplar

```
u      = aleatório em [0, 1)
f      = u ** 2.2                         # favorece os pequenos
tam    = tam_min + f * (tam_max - tam_min)
classe = P se f < 0,35 · M se f < 0,70 · G se f < 0,95 · Recorde se f ≥ 0,95
peso   = k_peso * (tam / 100) ** 3
volume = vol_medio * (tam / tam_medio) ** 2          # sobe mais rápido que o tamanho
preco  = preco_base * (tam / tam_medio) ** 1.6 * MULT_RARIDADE * (1,5 se Recorde)
MULT_RARIDADE = comum 1 · incomum 1,5 · rara 3 · lendária 10      (proposta)
```

Acertar a faixa **dourada** do medidor sorteia `u` duas vezes e fica com o maior.

### 3.4 Aparecimento e cardumes

- Cada cardume nasce numa posição do mar; `mapa_fundo.zona(x, y)` define a zona e `especies.sortear(zona, hora, clima,
  rng)` escolhe a espécie, com peso por raridade: comum 60, incomum 28, rara 10, lendária 2 *(proposta)*, filtrando
  horário e clima. "noite_mais" dobra o peso à noite e o reduz à metade de dia.
- Cada cardume tem **3 tentativas**; ao esgotá-las ou ao ser fisgado, ele se dispersa e nasce outro mais adiante.
- **Estilos de desenho** (sprite SpriteCook visto de cima, escurecido e azulado conforme a zona):
  `bola` (dezenas girando, brilho prateado), `grupo` / `grupo_pequeno` (grupo médio ou pequeno junto à superfície ou ao
  recife), `rapido` (grupo solto e veloz), `planando` (um só, sombra larga e lenta), `fundo` / `fundo_lento` (no fundo,
  andando de lado; nas rasas só aparece com água clara), `linha` (um só, rápido, em linha reta), `saltos` (um só, salta
  de vez em quando), `gigante` (sombra enorme e lenta), `luzes_nuvem` / `luzes_sozinho` / `isca_luz` /
  `tentaculos_luz` (quase invisíveis, só pontos bioluminescentes), `silhueta_palida` (silhueta gigante pálida).
- Os cardumes antigos (`Cardume` no `main.py`) são substituídos.

## 4. Pesca e varas (`pesca.py`)

### 4.1 Medidor

- Com o barco a menos de `DIST_PESCA` (proposta: 90 px) de um cardume e a velocidade abaixo de 30% da máxima, PESCAR
  abre o medidor: um ponteiro vai e volta numa barra; nela há uma faixa **verde** e, no meio dela, uma **dourada**.
- PESCAR de novo para o ponteiro: dourada = fisgou com bônus de tamanho · verde = fisgou · fora = errou (gasta 1
  tentativa do cardume, 2 s de espera).
- Parâmetros *(proposta)*:
  - período do ponteiro: comum 1,6 s · incomum 1,3 s · rara 1,0 s · lendária 0,8 s
  - largura da verde (fração da barra): `0,30 × FATOR_RARIDADE × (1 − 0,35 × f_previsto) × (1 + 0,08 × nível_Pescador)`,
    com FATOR_RARIDADE comum 1 · incomum 0,85 · rara 0,65 · lendária 0,45
  - dourada = 25% da verde
- O tamanho é sorteado **antes** de abrir o medidor (`f_previsto`), assim peixe grande já aparece mais difícil; a
  dourada refaz o sorteio pegando o maior dos dois.
- A lógica é pura: `Medidor(periodo, verde, dourada).posicao(t)` e `.resultado(t)` → `"dourada" | "verde" | "erro"`.

### 4.2 Varas

| Vara | Alcança | Preço |
|---|---|---|
| Rasa | rasas | inicial |
| Profunda | rasas e profundas | R$ 600 *(proposta)* |
| Abissal | todas | R$ 4.000 *(proposta)* |

Cardume de zona acima da vara: o medidor não abre e aparece "Vara fraca para esta profundidade". A vara equipada
aparece no HUD e troca pela tecla **T** ou por toque no ícone.

### 4.3 Rede

Melhoria comprada (R$ 800, *proposta*). Em cardume `bola` ou `luzes_nuvem`, PESCAR com a rede pega de 3 a 6 exemplares
pequenos (f sorteado só até 0,5) sem medidor, com 6 s de recarga.

## 5. Porão (`porao.py`)

- Lista de exemplares `{especie, tam, classe, peso, volume, preco}` com capacidade em litros.
- Níveis: 100 L (inicial) → 200 L (R$ 400) → 400 L (R$ 1.500) → 800 L (R$ 5.000) *(proposta)*.
- `adicionar(ex)` falha se não couber, e aparece a escolha "Porão cheio: soltar um peixe?" listando os menores.
  `soltar(i)` remove um exemplar.
- **Comer** (tecla 2 e item do HUD) consome o exemplar de menor volume entre as espécies comuns e dá a mesma recuperação
  de fome de hoje (`inv["peixe"]` deixa de existir; água, tábua e corda continuam em `inv`).
- HUD: barra "Porão 63/100 L" com cor que esquenta ao encher; tecla **I** abre a lista do porão.

## 6. Mercado e vila (`mercado.py`)

- Carteira em R$; começa com R$ 50 *(proposta)*.
- **Atracar:** parado a menos de 120 px do cais da vila, a tecla **E** (ou o toque no aviso) abre a tela da vila e pausa
  o mundo.
- **Peixaria:** lista do porão com o preço de cada um, "Vender tudo" e venda unitária. Primeira captura de uma espécie
  e recordes aparecem destacados antes da venda.
- **Loja** *(preços em proposta)*: vara profunda 600 · vara abissal 4.000 · porão 200/400/800 L (400/1.500/5.000) ·
  motor nível 2/3 (1.000/3.500) · tanque maior 600 · vela grande 700 · casco reforçado 900 · lente da lanterna 500 ·
  leme 400 · rede 800 · combustível R$ 2/unidade · água R$ 5 · tábua R$ 15 · corda R$ 10 · conserto da lanterna R$ 120.
- **Melhorias:** passam a ser compradas aqui. `MELHORIAS`, `RECEITAS` e as plantas dos baús saem; os baús continuam
  boiando, mas dão R$ 50–300 ou um "mapa de fossa" que marca uma fossa abissal na bússola.
- O objetivo antigo (`DIST_ILHA`, `RAIO_ILHA`, "salvo") sai. Morrer continua encerrando a partida e o jogo recomeça do
  último salvamento, perdendo o que estava no porão.

## 7. Barco pesqueiro a motor e vela

- Novo sprite (SpriteCook) de **pesqueiro** com casa de leme e mastro, nas variantes base, com vela aberta e danificado.
  Os remos, o remador e `separar_remos.py` deixam de ser usados.
- **Motor:** W/↑ acelera em 4 marchas (0, ¼, ½, máx), S/↓ reduz e dá ré lenta. Velocidade máxima no motor: nível 1 =
  150, nível 2 = 185, nível 3 = 220 *(proposta)*. Consumo na máxima: 0,8 unidade/s, proporcional à marcha; tanque de 100
  (ou 160 com tanque maior). Sem combustível, o motor para.
- **Ruído:** acima de ½ marcha, à noite, o motor aumenta a chance de tentáculos e do gigante (multiplicador 1,5 sobre a
  chance atual, *proposta*).
- **Vela:** V abre e fecha; usa o vento que já existe (`VEL_VELA`, vela grande +30%); é silenciosa. Motor e vela juntos
  somam, limitados por `VEL_MAX`.
- Habilidades: **Remador** vira **Motorista** (−7% de consumo por nível); **Navegador**, **Pescador**, **Mente de aço** e
  **Sobrevivente** continuam.

## 8. Mapa de profundidade (`mapa_fundo.py`)

- O mundo fica fixo e o jogador o aprende: a vila em (0, 0), sempre no mesmo lugar.
- Regiões definidas por formas (círculos e elipses) com semente fixa:
  - **rasas:** um disco de raio 2.500 em volta da vila e 5 ilhotas com recife de raio 600–1.200 até 8.000 de distância;
  - **abissais:** 4 fossas elípticas (eixos de 1.200 a 2.500) entre 9.000 e 22.000 de distância;
  - **profundas:** todo o resto.
- `zona(x, y)` → 0/1/2 e `mistura(x, y)` → valor contínuo para a cor da água fazer transição suave (de turquesa para
  azul-escuro e para quase preto com névoa). O HUD mostra "Rasas / Profundas / Abissais".
- Nas fossas a perda de sanidade é ×1,4 *(proposta)*.

## 9. Catálogo e salvamento (`catalogo.py`)

- 18 espaços; espécie não pescada aparece como silhueta "?". Cada uma guarda a quantidade pescada, o maior tamanho
  (recorde) e a classe. A tecla **C** (ou um ícone) abre o catálogo.
- **Salvamento automático** ao atracar e ao sair pela pausa; arquivo JSON versionado:
  ```json
  {"versao": 1, "dinheiro": 0, "varas": ["rasa"], "vara": "rasa", "melhorias": {}, "porao_nivel": 0,
   "combustivel": 100, "inv": {"agua": 2, "madeira": 2, "corda": 2}, "porao": [], "catalogo": {},
   "habilidades": {}, "xp": 0, "config": {"efeitos": 7, "musica": 5}}
  ```
- Onde fica: PC em `~/.naufrago/save.json`; Android na pasta privada do app (`ANDROID_PRIVATE`); navegador em
  `localStorage` quando disponível. Falha ao ler o arquivo = começa do zero e guarda o arquivo ruim como `.bak`.

## 10. Controles

| Ação | Teclado | Toque |
|---|---|---|
| Acelerar / reduzir motor | W ↑ / S ↓ | botões MOTOR + e − (substituem REMAR e FREAR) |
| Virar | A D ← → | setas ◀ ▶ (como hoje) |
| Vela | V | VELA (como hoje) |
| Pescar / parar o medidor | F | PESCAR |
| Trocar vara | T | ícone da vara no HUD |
| Atracar / vila | E | aviso "Atracar" na tela |
| Porão / catálogo | I / C | ícones no HUD |
| Golpe, beber, comer, consertar, lanterna, ficha, pausa | como hoje | como hoje |

Também corrige a pendência da análise: tocar no **painel da lanterna quebrada** passa a funcionar.

## 11. Arte (SpriteCook)

Usando `arte/aprovada/sprites.png` como guia de estilo:
- 18 sprites de espécie vistos de cima, com fundo transparente (também usados no catálogo);
- pesqueiro: base, com vela aberta e danificado;
- ícones: moeda, combustível, porão, as três varas, catálogo;
- fundo da tela da vila (peixaria e loja).

Os sprites vão para `jogo/imagens/` com prefixo `esp_` e `pesq_`. Enquanto a arte não chega, cada espécie é desenhada
por código (silhueta colorida) para o jogo já ficar jogável.

## 12. Testes

- `jogo/testes/` com `unittest` (sem dependências): sorteio de tamanho (distribuição, classes e limites), volume e
  preço crescentes, filtro de horário e clima, `Medidor.resultado`, regras das varas, porão cheio/soltar/comer, compra
  e venda com saldo insuficiente, `zona()` em pontos conhecidos, ida e volta do salvamento e arquivo corrompido.
- Teste de fumaça do jogo (pygame com vídeo "dummy"): abre, entra na partida, pesca, atraca, vende e compra sem erros.
- Conferência manual no PC, em `--toque` e no navegador antes de gerar o APK.

## 13. Entregas em fases

1. **Lógica:** `especies`, `porao`, `mercado`, `catalogo` (com salvamento), `mapa_fundo`, `pesca` + testes.
2. **No jogo:** cardumes novos (desenho provisório), medidor, varas, porão no HUD, cores do mapa de profundidade.
3. **Barco e vila:** motor e combustível, tela da vila (peixaria e loja), fim do objetivo da ilha, baús novos.
4. **Arte:** sprites do SpriteCook para espécies, pesqueiro e ícones.
5. **Ajuste:** balanceamento de preços e dificuldade e verificação no Android.

## 14. Fora do escopo desta versão

Briga de linha, armadilhas de caranguejo, missões e encomendas da vila, novos climas, multijogador e a divisão completa
do `main.py` (só sai dele o que for substituído).
