# Pescador da Vila (novo conceito do Náufrago) — especificação de design

Data: 09/11/2026 · Versão 2: **Godot 4, só PC** · Origem: jogo `naufrago_mobile` (pygame), versão "Tela Grande"

## 1. Objetivo

Refazer o jogo no **Godot 4** como um jogo de **pesca com progressão num arquipélago**. O jogador é um pescador do
Porto do Farol; sai com um pesqueiro a motor e vela, pesca 18 espécies de tamanhos aleatórios em águas rasas,
profundas e abissais, enche o porão, vende nos mercados de peixe das 3 cidades, cumpre missões e melhora o barco na
doca seca. Um catálogo registra espécies e recordes. A sobrevivência e o horror cósmico do jogo original continuam.

**Sucesso =** no PC (Windows), dá para jogar o ciclo completo — sair do Porto do Farol, pescar, encher o porão, vender,
cumprir uma missão, melhorar o barco e alcançar uma zona mais funda — com a partida salva entre sessões.

### Decisões do usuário (09/11/2026)

| Tema | Decisão |
|---|---|
| Plataforma | **Só PC** por enquanto (celular fica para depois) |
| Ferramenta | **Godot 4**, scripts em **GDScript** |
| Ciclo | Pescar → vender → melhorar **e** catálogo com recordes e raras |
| Sobrevivência e horror | **Mantidos** (fome, sede, sanidade, lanterna, criaturas à noite) |
| Pescaria | Parar no cardume e **acertar um medidor de tempo** (sem fase de briga) |
| Espécies | **18**, 6 por zona, com uma rara e uma lendária por zona |
| Arte das espécies | **SpriteCook** |
| Profundidade | **Regiões fixas no mapa**, indicadas pela cor da água |
| Mapa | **Arquipélago com 3 cidades** |
| Cidades | **Especializadas:** todas têm mercado de peixe e missões, com preços e pedidos diferentes; a **doca seca** fica só na cidade principal |
| Atracar | Abre o **mercado de peixe** |
| Melhorias do barco | Na **doca seca** |
| Farol | Na ilha principal: **luz que guia** e **zona segura** contra o horror |
| Missões | NPC do mercado: **encomendas, troféus, entregas e exploração** |

Números marcados *(proposta)* são valores iniciais de balanceamento; ficam em arquivos de dados (seção 3) para ajustar
sem mexer no código.

## 2. Arquitetura no Godot

```
pescador/                         projeto Godot 4
├─ project.godot                  1920×1080, stretch "canvas_items", aspecto "expand"; mapa de entradas (teclado e mouse)
├─ dados/                         balanceamento em JSON, editável à mão
│  ├─ especies.json               as 18 espécies (seção 4)
│  ├─ cidades.json                cidades, multiplicadores de preço e o que cada uma vende
│  ├─ loja.json                   itens do balcão e melhorias da doca seca, com preços e níveis
│  └─ missoes.json                modelos de missão (seção 8)
├─ logica/                        regras puras (classes GDScript sem nós de cena) — testáveis no modo headless
│  ├─ especies.gd                 carrega especies.json, sorteia espécie e exemplar
│  ├─ medidor.gd                  o medidor de fisgada
│  ├─ porao.gd                    inventário por volume
│  ├─ mercado.gd                  preços por cidade, venda, compra, carteira
│  ├─ missoes.gd                  gerar, acompanhar e entregar missões
│  └─ catalogo.gd                 catálogo e recordes
├─ autoload/                      singletons (Project Settings › Autoload)
│  ├─ Estado.gd                   estado da partida: dinheiro, dia, barco, varas, porão, missões, catálogo, habilidades
│  ├─ Salvamento.gd               grava e lê user://save.json
│  └─ Audio.gd                    efeitos e música (reaproveita os .ogg do jogo original)
├─ cenas/
│  ├─ Principal.tscn              menu inicial → partida
│  ├─ Mundo.tscn                  arquipélago (TileMapLayer), cidades, farol, pontos de interesse, ciclo dia/noite, clima
│  ├─ Barco.tscn                  pesqueiro (CharacterBody2D): motor, vela, leme, lanterna (PointLight2D)
│  ├─ Cardume.tscn                um cardume; o visual muda conforme o "estilo" da espécie
│  ├─ criaturas/                  tentáculo, gigante do fundo, tubarão, baleia, gaivotas (portados do jogo original)
│  └─ ui/                         HUD, Medidor, Porao, Catalogo, Missoes, TelaMercado, TelaDoca, Pausa, FichaHabilidades
├─ ferramentas/
│  └─ gerar_arquipelago.gd        script de editor (@tool) que pinta o mapa inicial; depois você ajusta no editor
├─ testes/
│  └─ rodar_testes.gd             testes da pasta logica/, rodando com `godot --headless --script`
└─ arte/, sons/, musica/, fontes/ arquivos reaproveitados do jogo original + arte nova do SpriteCook
```

**Princípios**
- **Lógica separada da cena:** as classes de `logica/` não dependem de nós nem de tela; as cenas só leem e mostram o
  estado. Isso permite testar as regras sem abrir o jogo.
- **Dados fora do código:** espécies, preços, cidades, loja e missões ficam em JSON.
- **Sinais do Godot** ligam lógica e interface (por exemplo, `Estado.dinheiro_mudou`, `Estado.porao_mudou`,
  `Estado.missao_concluida`).
- Do jogo original reaproveitamos **design, números, sons, músicas, fontes e arte**; o código é reescrito em GDScript.

## 3. Arquivos de dados (resumo)

- `especies.json`: lista de objetos com os campos da seção 4.1.
- `cidades.json`: `id`, `nome`, posição, raio do cais, `tem_doca`, multiplicador de preço por categoria e por zona,
  itens extras do balcão.
- `loja.json`: itens do balcão (preço unitário) e melhorias da doca (níveis e preço de cada nível).
- `missoes.json`: modelos por tipo, com faixas de quantidade, tamanho, prazo e recompensa.

## 4. Espécies (`logica/especies.gd`)

### 4.1 Campos

`id`, `nome`, `zona` (0 rasa, 1 profunda, 2 abissal), `categoria` (comum, crustaceo, arraia, especial, rara, lendaria),
`raridade` (comum, incomum, rara, lendaria), `tam_min` e `tam_max` (cm), `k_peso` (peso kg = k_peso × (tam/100)³),
`vol_medio` (litros de um exemplar médio), `preco_base` (R$ de um exemplar médio comum), `horario` (qualquer,
noite_mais, so_noite), `clima` (qualquer, tempestade), `estilo` (desenho do cardume), `qtd` ([mín, máx] de silhuetas),
`sprite` (caminho da arte).

### 4.2 As 18 espécies

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

Sardinha (12–25) e mero (80–250) vieram do design; as demais faixas são *(proposta)*, também na planilha
`Naufrago_Especies_e_Cardumes.xlsx`.

### 4.3 Sorteio de um exemplar

```
u      = aleatório em [0, 1)
f      = u ^ 2.2                          # favorece os pequenos
tam    = tam_min + f × (tam_max − tam_min)
classe = P se f < 0,35 · M se f < 0,70 · G se f < 0,95 · Recorde se f ≥ 0,95
peso   = k_peso × (tam / 100)³
volume = vol_medio × (tam / tam_medio)²              # sobe mais rápido que o tamanho
valor  = preco_base × (tam / tam_medio)^1,6 × MULT_RARIDADE × (1,5 se Recorde)
MULT_RARIDADE = comum 1 · incomum 1,5 · rara 3 · lendária 10      (proposta)
```

O preço de venda numa cidade é `valor × multiplicador da cidade` (seção 7.1). Acertar a faixa **dourada** do medidor
sorteia `u` duas vezes e fica com o maior.

### 4.4 Aparecimento e visual dos cardumes

- Cardumes nascem em volta do barco (fora da tela). A zona vem do mapa (seção 9) e a espécie é sorteada por raridade —
  comum 60, incomum 28, rara 10, lendária 2 *(proposta)* — filtrando horário e clima; "noite_mais" dobra o peso à noite
  e o reduz à metade de dia.
- Cada cardume tem **3 tentativas**; esgotadas ou depois de uma fisgada, ele se dispersa e nasce outro adiante.
- **Estilos** (sprite do SpriteCook visto de cima; mais escuro e azulado quanto mais fundo):
  `bola` (dezenas girando, brilho prateado na superfície), `grupo` / `grupo_pequeno`, `rapido` (grupo solto e veloz),
  `planando` (um só, sombra larga e lenta), `fundo` / `fundo_lento` (no fundo, andando de lado; nas rasas só com água
  clara), `linha` (um só, rápido, em linha reta), `saltos` (um só, salta de vez em quando), `gigante` (sombra enorme e
  lenta), `luzes_nuvem` / `luzes_sozinho` / `isca_luz` / `tentaculos_luz` (quase invisíveis, só pontos bioluminescentes,
  com `PointLight2D` e partículas), `silhueta_palida` (silhueta gigante pálida).
- Enquanto a arte não chega, cada estilo usa uma silhueta provisória colorida.

## 5. Pesca e varas (`logica/medidor.gd`)

### 5.1 Medidor

- Com o barco a menos de 90 px *(proposta)* de um cardume e abaixo de 30% da velocidade máxima, **PESCAR** abre o
  medidor: um ponteiro vai e volta numa barra com uma faixa **verde** e, no meio dela, uma **dourada**.
- PESCAR de novo para o ponteiro: dourada = fisgou com bônus de tamanho · verde = fisgou · fora = errou (gasta uma
  tentativa do cardume e espera 2 s).
- Parâmetros *(proposta)*:
  - período do ponteiro: comum 1,6 s · incomum 1,3 s · rara 1,0 s · lendária 0,8 s
  - largura da verde (fração da barra) = `0,30 × FATOR_RARIDADE × (1 − 0,35 × f_previsto) × (1 + 0,08 × nível_Pescador)`,
    com FATOR_RARIDADE comum 1 · incomum 0,85 · rara 0,65 · lendária 0,45
  - dourada = 25% da verde
- O exemplar é sorteado **antes** de abrir o medidor (`f_previsto`), para o peixe grande já aparecer mais difícil.
- API pura: `Medidor.new(periodo, verde, dourada)`, `posicao(t)` e `resultado(t)` → `"dourada" | "verde" | "erro"`.

### 5.2 Varas e rede

| Vara | Alcança | Preço | Onde comprar |
|---|---|---|---|
| Rasa | rasas | inicial | — |
| Profunda | rasas e profundas | R$ 600 *(proposta)* | qualquer mercado |
| Abissal | todas | R$ 4.000 *(proposta)* | só Ponta Negra |

- Cardume de zona acima da vara: o medidor não abre e aparece "Vara fraca para esta profundidade". A tecla **T** troca
  a vara; a equipada aparece no HUD.
- **Rede** (R$ 800, *proposta*): em cardume `bola` ou `luzes_nuvem`, PESCAR pega 3 a 6 exemplares pequenos (f até 0,5)
  sem medidor, com 6 s de recarga.

## 6. Porão (`logica/porao.gd`)

- Lista de exemplares `{especie, tam, classe, peso, volume, valor}` com capacidade em litros: 100 L (inicial) → 200 →
  400 → 800 L (melhorias da doca).
- `adicionar(ex)` falha se não couber; aparece "Porão cheio: soltar um peixe?" com os menores. `soltar(i)` remove.
- Cargas de missão de entrega também ocupam volume.
- **Comer** consome o exemplar comum de menor volume e recupera a fome como no jogo original. Água, tábua e corda ficam
  num inventário separado de suprimentos.
- HUD: barra "Porão 63/100 L"; tecla **I** abre a lista.

## 7. Arquipélago, cidades, mercado, doca seca e farol (`logica/mercado.gd`)

### 7.1 As três cidades

| Cidade | Onde *(proposta)* | O que tem | Especialidade |
|---|---|---|---|
| **Porto do Farol** (principal, início) | ilha principal, (0, 0) | mercado de peixe, missões, **doca seca**, **farol** | preço normal; pedidos de espécies rasas |
| **Vila das Arraias** | ~7.000 a nordeste, cercada de recifes | mercado de peixe, missões | +40% por arraias e crustáceos; pedidos de rasas e profundas |
| **Ponta Negra** | ~14.000 a sudoeste, na borda das fossas | mercado de peixe, missões | +50% por profundas e abissais; única com vara abissal e iscas abissais |

A carteira começa com R$ 50 *(proposta)*.

### 7.2 Atracar e o mercado de peixe

- Parado a menos de 120 px do cais de uma cidade, aparece **"Atracar"** (tecla **E** ou clique). Ao atracar, o mundo
  pausa, o jogo **salva** e abre o **mercado de peixe**, com três abas:
  - **Vender:** o porão com o preço de cada peixe nesta cidade, "Vender tudo" e venda unitária; primeira captura e
    recordes aparecem destacados.
  - **Missões:** o NPC do mercado (retrato e fala) oferece e recebe missões (seção 8).
  - **Balcão:** varas, rede, iscas, combustível (R$ 2/un.), água (R$ 5), tábua (R$ 15), corda (R$ 10), conserto da
    lanterna (R$ 120) *(proposta)*.
- No Porto do Farol aparece o botão **"Doca seca"**.

### 7.3 Doca seca (só no Porto do Farol)

- O barco aparece fora d'água com as melhorias, cada uma com nível atual, próximo nível e preço *(proposta)*: porão
  200/400/800 L (400/1.500/5.000) · motor nível 2/3 (1.000/3.500) · tanque maior 600 · vela grande 700 · casco reforçado
  900 · leme 400 · lente da lanterna 500.
- **Reparo completo do casco:** R$ 3 por ponto de dano *(proposta)*. No mar, tábua e corda continuam remendando.
- Os baús continuam boiando no mar, mas dão R$ 50–300 ou um "mapa de fossa" que marca uma fossa na bússola.

### 7.4 Farol (ilha principal)

- **Luz que guia:** à noite e na tempestade, um facho gira no alto do farol (`PointLight2D` com textura de cone) e é
  visto de longe (até ~8.000 px); fora da tela, um brilho na borda indica a direção. A **bússola** aponta para o
  destino escolhido (Porto do Farol por padrão; tecla **B** troca para outra cidade ou para o alvo de uma missão).
- **Zona segura:** até 2.500 px do farol *(proposta)* a sanidade não cai e volta devagar (+0,5/s); tentáculos e
  gigantes não aparecem, e os que estiverem perto mergulham e somem.

### 7.5 Fim de partida

Não há mais "chegar à ilha e ser salvo". O jogo começa atracado no Porto do Farol. Morrer encerra a partida e recomeça
do último salvamento, perdendo o que estava no porão.

## 8. Missões (`logica/missoes.gd`)

- O NPC de cada mercado oferece **3 missões**, renovadas a cada novo dia do jogo. Até **3 ativas** no total. As ofertas
  respeitam o progresso: só pedem espécies de zonas que a vara alcança, com no máximo uma zona acima como desafio.

| Tipo | Exemplo | Como se cumpre | Recompensa *(proposta)* |
|---|---|---|---|
| **Encomenda** | "3 tainhas M ou maiores" | entregar na cidade que pediu | 1,5× o valor de venda + XP |
| **Troféu** | "um robalo acima de 90 cm" | entregar o exemplar | 3× o valor + XP; lendárias dão título no catálogo |
| **Entrega** | "levar caixas de gelo à Ponta Negra em 2 dias" | a carga ocupa 20–60 L do porão; entregar no prazo | R$ fixo pela distância; atraso = falha |
| **Exploração** | "achar o naufrágio a leste da Vila das Arraias" | chegar ao ponto (raio 300) | R$ + ponto marcado; o naufrágio tem um baú |

- A tecla **J** mostra as missões ativas com o progresso ("2/3 tainhas", "prazo: 1 dia"); a bússola pode apontar para
  o alvo.
- API pura: `gerar(cidade, dia, progresso, rng)`, `progresso(missao, porao, posicao)`, `entregar(missao, porao,
  carteira)`.

## 9. Mapa do arquipélago (`Mundo.tscn`)

- **TileMapLayer** com tiles de água rasa (turquesa), profunda (azul-escuro), abissal (quase preto) e terra (ilhas). Cada
  tile tem um dado personalizado `zona`, que o jogo consulta para sortear espécies e mostrar "Rasas / Profundas /
  Abissais" no HUD. Um shader de água anima ondas, mistura as cores nas bordas entre zonas e escurece com a noite e a
  tempestade; nas fossas há névoa (partículas) e a perda de sanidade é ×1,4 *(proposta)*.
- O mapa inicial é pintado pelo script `ferramentas/gerar_arquipelago.gd` (semente fixa) e depois pode ser ajustado à
  mão no editor do Godot:
  - **rasas:** disco de raio 2.500 em volta de cada cidade (maior na Vila das Arraias) e 5 ilhotas com recife
    (raio 600–1.200);
  - **abissais:** 4 fossas elípticas (eixos de 1.200 a 2.500) entre 9.000 e 22.000 de distância, a maioria perto de
    Ponta Negra;
  - **profundas:** o resto.
- Pontos de interesse fixos (nós `Marker2D` com nome): 3 cidades com cais, o farol, 5 ilhotas, 4 fossas e 3 naufrágios.
- As ilhas têm colisão: o barco bate e só encosta pelos cais.

## 10. Barco pesqueiro a motor e vela (`Barco.tscn`)

- **CharacterBody2D** com o sprite do pesqueiro (casa de leme e mastro) nas variantes base, vela aberta e danificado.
- **Motor:** W/↑ sobe a marcha (0, ¼, ½, máx), S/↓ desce e dá ré lenta. Velocidade máxima no motor: nível 1 = 150,
  nível 2 = 185, nível 3 = 220 *(proposta)*. Consumo na máxima 0,8 un./s, proporcional à marcha; tanque de 100 (160 com
  tanque maior). Sem combustível, o motor para.
- **Ruído:** acima de ½ marcha, à noite, a chance de tentáculos e do gigante aumenta 1,5× *(proposta)*.
- **Vela:** V abre e fecha; usa o vento (vela grande +30%); silenciosa. Motor e vela somam até a velocidade máxima.
- **Leme:** A/D ou ←/→ viram; o leme melhorado vira mais rápido e sofre menos com as ondas.
- Esteira e espuma com partículas; a lanterna é uma `PointLight2D` (a lente melhora o alcance).

## 11. Sobrevivência, horror e progressão (portados do jogo original)

Mantidos com as mesmas regras e números do `main.py` original, adaptados ao Godot:
- fome e sede (comer um peixe do porão, beber água), vida e casco;
- ciclo dia/noite (`CanvasModulate` + luzes) e clima com tempestade (chuva em partículas, ondas mais fortes);
- sanidade, lanterna que pode quebrar, tentáculos, gigantes de olhos brilhantes, vultos;
- fauna ambiente: tubarão (golpe), baleia, gaivotas;
- XP e ficha com 5 habilidades: **Pescador**, **Motorista** (−7% de consumo por nível; substitui o Remador),
  **Navegador**, **Mente de aço**, **Sobrevivente**;
- efeitos sonoros e músicas do jogo original, com o mesmo controle de volume.

## 12. Catálogo e salvamento

- **Catálogo** (tecla **C**): 18 espaços, silhueta "?" até a primeira captura; mostra quantidade pescada, recorde de
  tamanho e títulos de troféus lendários.
- **Salvamento automático** ao atracar e ao sair pela pausa, em `user://save.json` (no Windows, dentro de
  `%APPDATA%\Godot\app_userdata\Pescador da Vila`):
  ```json
  {"versao": 1, "dinheiro": 0, "dia": 1, "cidade": "porto_farol", "destino": "porto_farol",
   "varas": ["rasa"], "vara": "rasa", "melhorias": {}, "combustivel": 100, "casco": 100,
   "suprimentos": {"agua": 2, "tabua": 2, "corda": 2}, "porao": [], "catalogo": {},
   "missoes": {"ativas": [], "ofertas": {}}, "pontos_achados": [], "xp": 0, "habilidades": {},
   "config": {"efeitos": 7, "musica": 5, "tela_cheia": true}}
  ```
- Arquivo ilegível: começa do zero e guarda o ruim como `save.json.bak`.

## 13. Controles (teclado e mouse)

| Ação | Tecla |
|---|---|
| Motor: subir / descer marcha | W ↑ / S ↓ |
| Virar | A D ← → |
| Vela | V |
| Pescar / parar o medidor | F (ou clique esquerdo) |
| Trocar vara | T |
| Atracar | E |
| Golpe | Espaço |
| Beber / comer / consertar com tábua / com corda / lanterna | 1 / 2 / 3 / 4 / L |
| Porão / catálogo / missões / ficha | I / C / J / K |
| Destino da bússola | B |
| Pausa | Esc ou P |
| Tela cheia | F11 |

Todas as telas (mercado, doca, catálogo, missões, pausa) também funcionam com o mouse. As teclas ficam no mapa de
entradas do Godot, o que facilita trocar as teclas ou adicionar controle (gamepad) depois.

## 14. Arte e som

- **SpriteCook**, usando a arte aprovada do jogo original como guia de estilo: 18 espécies vistas de cima (também usadas
  no catálogo); pesqueiro (base, vela aberta, danificado); farol; casas e cais das 3 cidades; 3 retratos de NPC dos
  mercados; doca seca; 3 naufrágios; ícones (moeda, combustível, porão, 3 varas, catálogo, missões).
- Reaproveitados: tiles de água e ilha, itens, criaturas, ícones do HUD, os 44 efeitos sonoros, as 3 músicas e as fontes
  DejaVu.

## 15. Testes

- `testes/rodar_testes.gd`, executado com `godot --headless --script res://testes/rodar_testes.gd`, cobre:
  sorteio de tamanho (limites, classes, distribuição), volume e valor crescentes, filtro de horário e clima, resultado
  do medidor, regras das varas, porão cheio/soltar/comer, preço por cidade, compra com saldo insuficiente, geração e
  entrega de cada tipo de missão (inclusive prazo vencido), recordes do catálogo e ida e volta do salvamento (inclusive
  arquivo corrompido).
- Os arquivos JSON de dados são validados por um teste (campos obrigatórios e faixas coerentes).
- Conferência no PC pelo usuário a cada fase, rodando o projeto no editor do Godot.

## 16. Entregas em fases

1. **Base e lógica:** projeto Godot, autoloads, arquivos de dados, classes de `logica/` e testes.
2. **Mundo e barco:** arquipélago gerado, câmera, pesqueiro com motor, vela, vento e combustível, colisão com ilhas,
   cais, farol (luz e zona segura), bússola, dia/noite.
3. **Pesca:** cardumes com visual provisório por estilo, medidor, varas, rede, porão no HUD, catálogo.
4. **Cidades:** mercado de peixe (vender, missões, balcão), doca seca, missões completas, salvamento.
5. **Sobrevivência e horror:** fome, sede, sanidade, lanterna, criaturas, tempestade, XP e habilidades, sons e música.
6. **Arte e ajuste:** sprites do SpriteCook, menu inicial, pausa, balanceamento.

## 17. Fora do escopo desta versão

Versão para celular, briga de linha, armadilhas de caranguejo, novos climas, multijogador e gamepad (fica fácil de
acrescentar depois pelo mapa de entradas).
