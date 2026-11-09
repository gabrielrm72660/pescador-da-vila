# Náufrago — versão para celular

Mesmo jogo, agora com controles de toque, escala automática de tela, tela de carregamento com a
arte de capa e dois caminhos para rodar no Android. Tudo aqui é Python (sem `.bat`).

```
naufrago_mobile/
├─ jogo/                      ← o jogo em si (é esta pasta que vai para o celular)
│  ├─ main.py                 o código (mesmo arquivo para PC, navegador e Android)
│  ├─ fontes/                 fonte DejaVu embutida (+ licença)
│  ├─ sons/                   44 sons .ogg (efeitos e ambientes), ~1,3 MB
│  ├─ musica/                 3 músicas .ogg da trilha de vila de pescador, ~1,2 MB
│  ├─ imagens/                70 sprites .png da arte nova + meta.json (cortados das 4 folhas de arte)
│  ├─ icon.png  presplash.png  favicon.png     gerados da arte de capa
│  └─ buildozer.spec          configuração do APK
├─ arte/                      capa original + gerar_arte.py (ícone/splash) + gerar_sons.py (refaz os sons)
│                             + gerar_musica.py (compõe e refaz as músicas)
│                             + originais/ (as 4 folhas de arte) + cortar_arte.py (refaz jogo/imagens/)
├─ testar_no_celular.py       passo 2: testa no celular pelo navegador, via Wi-Fi
├─ construir_android.py       passo 3: gera o APK (Linux / WSL2)
└─ LEIAME.md
```

## 1. No PC

```
python jogo/main.py            # teclado (WASD, espaço, F, V, 1/2/3/4/L, E, K, P; M liga/desliga o som) + mouse
python jogo/main.py --toque    # simula um celular: botões na tela, clique do mouse faz o papel do dedo
```

Precisa de `pygame` (ou `pygame-ce`): `pip install pygame`.

**Mouse no PC:** clique em ENTER/começar, nos botões da pausa (continuar, recomeçar, som, sair), nos botões − e + e direto
nas barras de volume, nas habilidades da ficha (K), na barra de XP (abre a ficha), no painel "Montar", no painel da lanterna
quebrada e nos itens da base da tela (beber, comer, tábua, corda, lanterna). O teclado continua valendo para tudo.

**Controles de toque:** setas ◀ ▶ e FREAR à esquerda; REMAR, PESCAR, GOLPE e VELA à direita; os cinco
itens da base da tela (gota = beber, peixe = comer, tábua com martelo = consertar com tábua, rolo de corda = consertar
com corda, lanterna) são botões só com ícones. Dá para segurar REMAR e virar ao mesmo
tempo (multitoque) e deslizar o dedo de uma seta para a outra sem soltar. Se você usar o teclado, os
botões somem; tocou na tela, eles voltam. O botão "voltar" do Android pausa o jogo, e mandar o app para
segundo plano pausa sozinho.

## A arte nova

A arte vem das quatro folhas em `arte/originais/` (criaturas, ambiente e HUD, barco com remador, itens e
ícones). `python arte/cortar_arte.py` recorta tudo de novo para `jogo/imagens/` (70 sprites com fundo
transparente e o `meta.json` com as posições da lanterna, das pás e dos olhos dos gigantes). Para ver como
cada recorte ficou: `python arte/cortar_arte.py --previa`. O `meta.json` é pré-calculado de propósito: no
Android não há `numpy`, então o jogo só lê o arquivo.

Onde cada coisa entra no jogo:

- **Água:** três blocos repetidos (dia, noite, tempestade) que se misturam com a hora e o clima.
- **Barco:** o sprite com o remador gira para o rumo. Os dois remos são recortados do desenho (`arte/separar_remos.py`,
  chamado no fim do `cortar_arte.py`; ele também gera `barco_*_sr.png`, o barco sem remos) e giram sozinhos no
  toleteiro. A vela, o leme, a rede, a lente e os remos longos (só aumentam a escala dos remos) continuam sendo
  desenhados por código por cima, porque mudam com o vento e com as melhorias.
- **Itens:** barril, tábua, corda, garrafa e baú; **criaturas:** tubarão (fica vermelho ao levar golpe), os dois
  gigantes de olhos brilhantes sob a água, tentáculos (paleta nova) e gaivotas voando quando o som delas toca.
  Cardume, golfinho e baleia são sprites vistos **de cima**, gerados por código (veja abaixo).
- **HUD:** ícones das barras, do inventário e das melhorias, molduras de madeira, bússola com a agulha dourada,
  sol, lua e nuvem de tempestade. **Ilha:** desenhada por código (`_ilha`) e guardada pronta numa imagem; só as palmeiras, a fogueira e a
  espuma se mexem a cada quadro.

### Animações (todas por código, em cima dos sprites)

Não há folhas de quadros: o jogo anima os próprios sprites em tempo de execução, então nada disso pesa no
tamanho do pacote.

- **Remada:** pegada, puxada e recuperação, com arrancada do barco a cada remada, balanço do casco e espuma na
  pá. Os remos ficam levantados quando o barco está parado e balançam com a marola (mais na tempestade).
- **Peixes e tubarão:** `Arte.ondular()` fatia o sprite em tiras e faz uma onda andar da cabeça ao rabo: cabeça
  firme, corpo em S, rabo balançando. O cardume usa 8 quadros em cache; o tubarão, 12 quadros girados na hora.
- **Gaivotas:** batem asa em rajadas e depois planam (7 aberturas de asa), com a sombra acompanhando.
- **Gigantes sob a água:** o corpo todo se contorce devagar, além de respirar e piscar os olhos.
- **Itens:** barril rolando na marola, corda e garrafa balançando, tábua à deriva.
- **Palmeiras:** a copa balança sem mexer o tronco. **Fogueira:** a chama treme e a base de pedras fica parada.
- **HUD:** o sol gira devagar, a lua e a nuvem de tempestade flutuam.

Para ajustar: `amp` (quantos pixels o rabo ou a copa balançam), `ciclos` (quantas ondas cabem no corpo) e o
número de quadros ficam nas chamadas a `rot(..., onda=(quadros, amp, eixo, âncora, ciclos))` e `ondular(...)`.

Se a pasta `jogo/imagens/` não existir (ou um arquivo faltar), o jogo volta sozinho ao desenho por código de
antes. Não usados por enquanto: as vistas laterais e em 8 direções do barco, a vela içada em sprite (a vela é
dinâmica, no código), as cristas de onda, a chuva e o cone de luz em sprite, a moldura de pergaminho, a ilha
inteira em sprite (a ilha continua procedural) e a moldura de barra (as barras de
status usam um contorno de madeira feito por código).

## Peixes, golfinhos, baleias e o gigante

Os sprites novos saem de `python arte/gerar_animais.py` (precisa de numpy/opencv, só no PC; `--previa` gera
`arte/previa_animais.png`): `peixe_topo_1..4.png`, `golfinho.png` e `baleia.png`, todos vistos de cima e
apontando para cima, como os outros.

- **Cardume:** os peixes nadam de **frente**, todos para o mesmo lado, em formação solta que vira junto (`Cardume`,
  `CARDUME_VEL`). Ao longo do corpo corre a mesma onda de nado do resto.
- **Golfinhos:** bandos de 2 a 4 que vêm até o barco de dia (um a cada ~1,5 a 2 min), nadam na proa (ou dão voltas
  se você está parado), pulam da água e deixam espuma. Ficam pouco: ~22 a 34 s (`Bando.vida`) e vão embora. Ver golfinho acalma (sanidade sobe um pouco) e **tubarão foge** quando há golfinhos por perto.
- **Baleias:** raras (uma a cada 5 a 8 min de dia, `Baleia`). Passam devagar, sopram jatos de água, empurram o barco
  de leve se você chegar muito perto e acalmam bastante (+10 de sanidade).
- **Gigante do fundo (Vulto):** só desperta com a **sanidade abaixo de 50%** (`SAN_VULTO`) e de noite. Antes disso
  o mar avisa: **manchas escuras** passando por baixo e **bolhas** subindo perto do barco. Se a sanidade volta
  acima de ~62%, ele afunda de novo.

## Noite mais pesada e lanterna quebrável

- **Sanidade à noite:** o desgaste só por estar no mar à noite subiu (`SAN_NOITE` 0,16 → 0,27) e no escuro total (lanterna
  apagada **ou quebrada**) o extra subiu (`SAN_SEM_LANTERNA` 0,35 → 0,50). A habilidade Mente de aço e a lente da lanterna
  continuam aliviando.
- **Lanterna quebra** com onda de tempestade (a chance cresce com a tempestade), mordida de tubarão (10%) e agarrão de
  tentáculo (30%). Depois de quebrar ou de ser consertada ela tem 90 s de folga (`LANTERNA_FOLGA`) e a partida começa com
  40 s de proteção. Quebrada ela apaga, não acende (a tecla **L** vira "consertar"), solta faíscas e fumaça, o ícone da base
  ganha um X vermelho e aparece um painel "Lanterna quebrada!" com o material que falta.
- **Conserto: 4 tábuas + 4 cordas** (`LANTERNA_CONSERTO`), por **L** ou **E** (se não houver planta esperando), clicando no
  painel ou no ícone da lanterna. Consertar rende 15 de XP.

## Bússola, ilha e distância

A bússola agora tem **uma só ponta dourada** que aponta a ilha (e uma linha vermelha que mostra o rumo do barco),
mais um selo da ilha na borda. A distância aparece escrita se você tem o mapa, está a menos de ~2500 px ou tem
**Navegador nível 3**. A ilha foi redesenhada (praia, mata, pedras, lagoa, espuma) e fica a `DIST_ILHA = 48000`
px do início (~240 mi na bússola) — um trecho bem mais longo que antes. Se ficar demorado ou curto demais,
mude esse número no topo do `main.py`.

## RPG: planos, receitas e ficha

- **Baú dourado = planta (blueprint).** Em vez da melhoria pronta, o baú dá o *plano* dela. Para construir, aperte
  **E** (ou toque no painel "montar") — isso gasta materiais do inventário (`RECEITAS`):

  | Melhoria | Materiais |
  |---|---|
  | Casco reforçado | 3 tábuas |
  | Remos longos | 2 tábuas + **2 cordas** |
  | Vela grande | 1 tábua + **4 cordas** |
  | Leme de popa | 2 tábuas + 1 corda |
  | Lente da lanterna | 2 tábuas |
  | Rede de pesca | **3 cordas** |

  Ou seja: **vela e remos (velocidade do barco) só saem com corda.** Corda e tábua continuam servindo de remendo, então
  é preciso escolher entre consertar e construir. As melhorias pendentes pulsam nos ícones.
- **Experiência e ficha (tecla K / botão FICHA no celular):** pescar, achar baú, sobreviver à noite, ferir tentáculo
  etc. dão XP; cada nível rende 1 ponto. Cinco habilidades de até nível 5, gastas na ficha (teclas 1–5 ou toque):
  **Pescador** (pesca +12%/nível), **Remador** (remada +5%, cansa −7%), **Navegador** (vela +6%, nível 3 mostra a
  distância na bússola), **Mente de aço** (sanidade cai 8% menos) e **Sobrevivente** (fome/sede −7%, vida volta mais
  rápido). A curva é `80 + 40 × (nível − 1)` de XP por nível; veja `_xp_prox`, `INFO_HAB`, `HAB_MAX`.

## Consertos, corda e melhorias do barco

- **Tábua** (tecla **3**) remenda o casco em **+25**; **corda** (tecla **4**, rolo de corda na base da tela) remenda
  em **+12**. As duas boiam no mar e agora são bem mais comuns (até 5 de cada por perto, e a corda também sai de
  barris). Você começa com 2 tábuas e 2 cordas. Valores em `CASCO_TABUA` e `CASCO_CORDA`.
- **Baús dourados:** o primeiro aparece uns 40 a 55 s depois do começo e os seguintes de 55 a 90 s depois que você pega
  um. Nascem a ~1 km do barco, mais ou menos na direção da ilha, **brilham** (também de noite), tilintam quando você
  chega perto (dá para achar de ouvido) e uma **seta dourada** na borda da tela mostra a direção e a distância
  enquanto ele está a menos de ~1900 px e fora da tela. **Garrafa com mapa** marca o baú de qualquer distância (e cria um, se não
  houver). Cada baú dá **o plano de uma melhoria** que você ainda não tinha (são 6; depois de todas, não aparecem mais). A melhoria só vale depois de montada (veja "RPG" acima):

  | Melhoria | Efeito | Como aparece no barco |
  |---|---|---|
  | Casco reforçado | dano ao casco −35% e +20 de casco na hora | borda e proa de ferro com rebites |
  | Remos longos | remar +20% de velocidade e cansa 25% menos | remos maiores e claros (guardados na borda) |
  | Vela grande | vela +30% de velocidade | vela ~20% maior e flâmula vermelha |
  | Leme de popa | vira 25% mais rápido, ondas e tentáculos empurram 40% menos | leme na popa que gira com a curva |
  | Lente da lanterna | luz mais longa e larga; a mente perde 22% menos quando a lanterna está acesa | aro azulado na lanterna |
  | Rede de pesca | pesca 40% mais rápida, 95% de acerto e às vezes +1 peixe | rede dobrada no convés |

  A fileira de ícones abaixo das barras de status mostra as seis: acesas = você já tem. Ao achar uma, aparece um
  aviso grande no alto da tela. Ajustes: `BAU_PRIMEIRO`, `BAU_ENTRE`, `MELHORIAS` e `INFO_MELHORIA` no topo do `main.py`
  (os números de cada efeito estão nas funções `vel_remo`, `vel_vela`, `mult_dano` e nos pontos onde são usados).

## Som

O jogo agora tem som: efeitos e ambientes que reagem ao que acontece.

- **Ambientes (em loop):** mar, vento (mais forte na tempestade e com a vela içada), chuva, água cortada pela proa
  (cresce com a velocidade) e um **zumbido grave de horror** que sobe com a noite, com a perda de sanidade e
  quando um vulto ou tentáculo está perto.
- **Efeitos:** remadas, golpe de remo e acerto, mordida do tubarão, tentáculo (emergir, agarrar, recuar), vulto,
  olhos, sussurros, trovão depois do relâmpago, onda gigante, pesca, beber, comer, consertar, lanterna, vela,
  itens, corda puxada para o convés, tilintar do baú dourado, fanfarra de melhoria, gaivotas perto da ilha, noite caindo e amanhecer, batimento cardíaco acelerando com a loucura,
  e fanfarras de vitória, derrota e loucura. Sons de criaturas e do mar vêm do lado certo e ficam mais fracos
  com a distância.
- **Chuva:** gotinhas macias caindo na água (centro do som em ~2 kHz, quase nada acima de 5 kHz) sobre um sussurro
  grave; agora ela fica bem baixa, ~11 dB abaixo do mar mesmo na tempestade. **Remo:** remada abafada e curta, ~4 dB abaixo do mar.
  Golpes fortes (trovão, mordida, tentáculo, onda gigante) abaixam os ambientes por ~1 s para não estourar o som.
- **Trilha de vila de pescador:** três músicas calmas de ~35 a 40 s, feitas de violão de nylon, flauta, acordeão
  suave e um sino de boia ao longe: *Barcarola da Vila* (6/8, Ré maior), *Rede ao Sol* (Lá menor) e
  *Entardecer no Cais* (valsa, Sol maior). Elas **só tocam de vez em quando**: a primeira vem uns 6 a 10 s depois
  que a partida começa e as seguintes depois de um bom silêncio (em média uma por dia do jogo; no total ela toca em ~17% do tempo). Só
  começam de manhã ou de dia claro, sem tempestade, com a sanidade razoável e sem tubarão, vulto ou tentáculo por perto. Se a
  noite cai, a tempestade chega, a mente falha ou uma criatura se aproxima, a música abaixa e some. Não toca no menu.
- **Volume:** a música ficou ~11 dB mais presente do que antes (o mar e o vento abaixam sozinhos enquanto ela toca).
  Na **pausa** há duas barras: **EFEITOS** (efeitos e ambientes: teclas ← →, ou − / + na tela) e **MÚSICA** (teclas ↓ ↑,
  ou − / +), de 0 a 10. Você pode abaixar o que achar alto. **M** liga/desliga todo o som, música incluída (no celular: botão
  **SOM** na tela de pausa). A pausa cala os ambientes e pausa a música (por isso a mudança no volume da música só se
  ouve ao voltar ao jogo).
- O som vem das pastas `jogo/sons/` e `jogo/musica/`. Se elas não estiverem ao lado do `main.py`, ou não houver
  placa de som, o jogo roda em silêncio normalmente (sem a pasta `musica/` ele só fica sem trilha).
- Tudo é **sintetizado** (ruído filtrado, ondas, envelopes, cordas e palhetas simuladas), não gravado. Para mudar um
  som, edite a função dele em `arte/gerar_sons.py` e rode `python arte/gerar_sons.py` (precisa de numpy, scipy e
  ffmpeg); para refazer só alguns: `python arte/gerar_sons.py corda tesouro`. Para mudar as músicas (notas, acordes, andamento), edite `arte/gerar_musica.py` e rode
  `python arte/gerar_musica.py`: ele confere a teoria antes de gerar (nota fora do acorde no tempo forte, compasso
  que não fecha a conta...) e avisa em vez de gerar uma música desafinada. `--conferir` só confere.
- Volumes: `GANHO` / `LOOP_GANHO` (efeitos e ambientes), `MUSICA_GANHO` e `MUSICA_ABAIXA` (quanto o mar abaixa com a música) na classe `Som` do `main.py`; a chuva é `LOOP_GANHO["chuva"]` e a remada, o volume passado em `self.som.tocar("remo", ...)`. Quando e
  com que frequência a música toca: `MUSICA_PRIMEIRA`, `MUSICA_ENTRE`, `MUSICA_RETOMA` e `MUSICA_LUZ_MIN`, no mesmo lugar.

## 2. Testar no celular (navegador, sem instalar nada)

```
python testar_no_celular.py
```

O script instala o `pygbag` na primeira vez, sobe um servidor e mostra um endereço do tipo
`http://192.168.x.x:8000`. Abra no navegador do celular (**mesma rede Wi-Fi do PC**). Se o Windows
perguntar sobre o firewall, permita em "redes privadas". O celular precisa de internet na primeira
abertura (baixa o ambiente Python do navegador, ~30 MB).

- Serve para sentir o toque, a escala de tela e **o desempenho**. O navegador é mais lento que o APK:
  se ficar bom ali, no APK fica melhor.
- **Medir fps:** toque no painel de dia/hora (canto superior direito). 1º toque mostra os fps, 2º força o
  modo leve, 3º desliga. No PC, a tecla F3 faz o mesmo.
- **Modo leve:** liga sozinho se o jogo ficar abaixo de ~33 fps por 4 s (aparece um aviso). Corta os brilhos
  da lanterna, a vinheta e algumas texturas de água; o visual perde um pouco, o desempenho ganha ~40%.
- O navegador pede **um toque na tela para iniciar**: é o que libera o som (navegadores bloqueiam áudio antes
  da primeira interação). É o padrão (`UME_BLOCK = "1"` em `testar_no_celular.py`).
- Para publicar a versão web: `python testar_no_celular.py --publicar` e envie o conteúdo de `jogo/build/web`
  para uma hospedagem de site estático (itch.io, Vercel, GitHub Pages…).

## 3. Gerar o APK (Android)

O Buildozer só funciona em Linux. No Windows, use o Ubuntu do WSL2:

1. No PowerShell (uma vez): `wsl --install -d Ubuntu` (reinicie se pedir) e abra o app **Ubuntu**.
2. No Ubuntu, vá até esta pasta, por exemplo: `cd "/mnt/c/Users/SEU_USUARIO/Downloads/naufrago_mobile"`
3. Rode: `python3 construir_android.py`

O script instala o que falta (pede a senha do Ubuntu), cria um ambiente isolado com as versões que
funcionam (Cython<3, setuptools<71), compila e deixa o arquivo em `apk/naufrago-1.0-arm64-v8a-debug.apk`.
A **primeira compilação baixa o SDK/NDK do Android (alguns GB) e leva de 20 a 40 minutos**; as seguintes,
poucos minutos. Para instalar: passe o `.apk` para o celular (cabo, Drive, WhatsApp), abra-o e permita
"instalar apps desconhecidos". Se algo ficar estranho: `python3 construir_android.py --limpar`.

Ver erros do jogo no celular (USB + depuração USB ligada): `adb logcat -s python`.

Observações do APK: só arm64 (celulares recentes); para aparelhos de 32 bits, edite `android.archs` em
`jogo/buildozer.spec`. É um APK de depuração, ótimo para uso próprio; para publicar na Play Store seria
preciso assinar um release (outro passo).

## O que foi e o que não foi testado

- A arte nova foi conferida em capturas (dia, noite, tempestade, ilha, horror, HUD no PC e no celular) e o jogo
  também roda sem a pasta `imagens/`. Como ela *fica* no seu aparelho (tamanho dos sprites, contraste da água)
  só você avalia; me diga o que estiver grande, pequeno ou carregado demais.
- Testado no PC (pygame e pygame-ce): lógica dos botões de toque, multitoque, pausa/reinício, três
  proporções de tela, modo leve, tela de carregamento, partidas simuladas, horror, desempenho e **o som** (cada
  evento dispara o efeito certo, os ambientes reagem, mudo, pausa, fim de jogo, funcionamento sem a pasta de sons) e
  **os volumes** (chuva e remo bem abaixo do mar, música acima dele, barras de volume da pausa no teclado e no toque),
  **a corda e as seis melhorias** (cada efeito medido, baú que nasce perto da direção da ilha, seta, mapa, reinício,
  layout de cinco botões no inventário em 5 larguras de tela) e **a trilha** (quando começa, quando é cortada por noite, tempestade, loucura ou tubarão, pausa, mudo, silêncio
  entre músicas, faixa corrompida, pasta ausente; numa partida de bot a música toca em ~17% do tempo).
  Com um driver de áudio "de mentira" (o ambiente de teste não tem caixa de som): **como os sons e as músicas soam**
  só você pode avaliar. Eu só consegui medir (volume, brilho, notas tocadas, picos). Se algum ficar alto, baixo,
  estranho ou irritante, me diga o nome (ex.: "remo", "chuva", "musica2").
- O ambiente de compilação (Buildozer + python-for-android) foi preparado e o `buildozer.spec` foi lido sem
  erros, mas **o APK em si e o jogo rodando em celular real ainda não foram testados**: isso depende de baixar
  o SDK/NDK e de um aparelho. Os números de fps só você consegue medir (passo 2). O som em `.ogg` (e a música,
  que usa o fluxo `pygame.mixer.music`) no navegador e no Android também não foi testado.

## Ajustes rápidos

- **Duração do dia:** `DURACAO_DIA` (segundos de um dia inteiro, hoje 150) e `ALONGA_DIA` (0 = relógio uniforme;
  hoje 0,55: o sol ocupa ~2/3 do ciclo, ~95 s de dia claro e ~60 s de noite). Para mais tempo de dia, aumente
  `DURACAO_DIA` ou `ALONGA_DIA` (sempre abaixo de 1). A música e o relógio da tela acompanham sozinhos.

- Largura/altura lógica no celular: `ALTURA_CELULAR` em `main.py` (576). Menor = mais rápido, mais pixelado.
- Dificuldade: constantes no topo de `main.py` (`DURACAO_DIA`, `DIST_ILHA`, `SAN_*`…).
- Trocou a capa? Substitua `arte/capa.png`, ajuste `RECORTE_ICONE` em `arte/gerar_arte.py` e rode `python arte/gerar_arte.py`.

A fonte DejaVu Sans Condensed (licença em `jogo/fontes/LICENCA_DEJAVU.txt`) é embutida para o texto ficar
igual em qualquer aparelho.
