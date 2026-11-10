# Pescador da Vila — projeto Godot 4

Novo conceito do Náufrago: um pescador do Porto do Farol, num arquipélago com 3 cidades. Design completo em
`../docs/superpowers/specs/2026-11-09-pescador-da-vila-design.md`.

## Abrir o projeto

1. Instale o **Godot 4.7** (versão padrão, não a .NET): https://godotengine.org/download/windows/
2. Abra o Godot, clique em **Importar** e escolha o arquivo `project.godot` desta pasta.

> Fase 1 concluída: ainda não há cena para jogar. Esta fase entrega as **regras do jogo** prontas e testadas.
> O barco navegando pelo arquipélago chega na fase 2.

## Rodar os testes

```
python rodar_testes.py "C:\caminho\para\Godot_v4.7.2-stable_win64.exe"
```

(ou defina a variável `GODOT` com esse caminho, ou deixe um `godot` no PATH). Cada teste aparece como `OK` ou
`FALHA`, e no fim aparece o total, por exemplo `45 testes, 0 falhas`.

## Onde ajustar o balanceamento

Tudo em `dados/`, sem mexer no código:

| Arquivo | O que tem |
|---|---|
| `especies.json` | as 18 espécies: tamanhos, peso, volume no porão, preço, horário, clima e estilo do cardume |
| `mundo.json` | posição das 3 cidades, farol, recifes, ilhotas, fossas e naufrágios |
| `cidades.json` | o que cada cidade paga a mais, se tem doca seca e o que vende de especial |
| `loja.json` | preços do balcão, melhorias da doca seca (níveis e preços), reparo e dinheiro inicial |
| `missoes.json` | quantidades, prazos e recompensas das missões |

Depois de mudar um JSON, rode os testes: `test_dados.gd` avisa se algum valor ficou incoerente.

## Estrutura

- `logica/` — regras puras (espécies, medidor, varas, porão, mercado, catálogo, missões)
- `autoload/` — `Estado` (a partida) e `Salvamento` (grava em `user://save.json`)
- `testes/` — um arquivo `test_*.gd` por parte, e o executor `rodar_testes.gd`

## Fase 2 — mundo e barco

Abra a pasta `pescador/` no Godot 4.7 e aperte **F5**. O jogo começa atracado no Porto do Farol.

| Ação | Tecla |
|---|---|
| Atracar / desatracar (perto de um cais e devagar) | E |
| Motor: subir / descer marcha (R, 0, ¼, ½, MÁX) | W ↑ / S ↓ |
| Virar | A D ← → |
| Abrir / fechar a vela | V |
| Trocar o destino da bússola | B |
| Tela cheia | F11 |

**Roteiro de conferência:** desatraque com E, suba as marchas com W, abra a vela com V e vire com A/D; veja o
combustível cair (a vela sozinha não gasta nada). Bata numa ilhota: o barco desliza pela costa. Se bater de frente, a ré
(S) sempre tira o barco. Se o combustível acabar, um aviso manda abrir a vela; na borda do mapa outro aviso manda dar
meia-volta e a câmera para ali. Espere a noite (cerca
de 1 minuto): a lanterna acende, o farol gira e, longe dele, uma seta amarela na borda da tela aponta o caminho de
volta. Aperte B, siga a bússola até a Vila das Arraias e atraque com E.

## Fase 3 — pesca

| Ação | Tecla |
|---|---|
| Pescar / parar o ponteiro do medidor | F ou clique esquerdo |
| Trocar de vara | T |
| Porão (lista, soltar peixe) | I |
| Catálogo de espécies | C |

**Como pescar:** os cardumes aparecem em volta do barco (silhuetas provisórias, uma para cada estilo). Chegue a menos
de 90 px de um, quase parado (abaixo de 30% da velocidade máxima), e aperte F: abre o medidor. Aperte F de novo com o
ponteiro na faixa **verde** para fisgar; na **dourada** o peixe tende a ser maior. Errar gasta uma das 3 tentativas do
cardume e pede 2 s de espera. Depois de uma fisgada o cardume se dispersa e outro nasce adiante.

- Cardume mais fundo que a vara: "Vara fraca para esta profundidade". No começo só há a vara rasa.
- Com a rede (comprada no mercado, fase 4), em cardume de sardinha ou peixe-lanterna o F pega de 3 a 6 pequenos de uma
  vez, com 6 s de recarga.
- Porão cheio: o peixe fica "na mão" e o porão abre; solte um peixe para guardar o novo, ou feche para devolvê-lo.
- O painel mostra a vara equipada e "Porão 63/100 L".

**Roteiro de conferência:** desatraque, vá até um cardume nas águas rasas (verde-água), pare e pesque com F. Veja o
peixe no porão (I) e no catálogo (C). Erre de propósito três vezes e veja o cardume sumir. Vá às águas profundas (azul
escuro) e tente pescar: a vara rasa não alcança.

## Fase 4 — cidades

| Ação | Tecla |
|---|---|
| Mercado (quando atracado) | M |
| Missões ativas | J |
| Bússola: próximo destino (cidades e alvos de missão) | B |

**Atracar** num cais (E, devagar) salva o jogo e abre o **mercado** da cidade; com ele aberto o tempo para. Fechou,
você continua atracado: M reabre e E zarpa. O jogo também é salvo ao fechar o mercado, em `user://save.json`, e ao
abrir de novo você volta atracado na última cidade.

- **Vender:** cada peixe com o preço desta cidade, venda unitária e "Vender tudo". A Vila das Arraias paga +40% por
  arraias e crustáceos; Ponta Negra paga +50% por peixes de águas profundas e abissais.
- **Missões:** 3 ofertas por cidade, trocadas a cada dia; até 3 ativas. Encomenda e troféu se entregam com o peixe no
  porão; a entrega põe uma carga no porão e tem prazo; a exploração é achada no mar (aviso na tela) e paga na volta.
- **Balcão:** combustível (encher o tanque), água, tábua, corda, vara profunda, rede; a vara abissal só em Ponta Negra.
- **Doca seca** (só no Porto do Farol): porão, motor, tanque, vela grande, casco, leme e lente, e o reparo do casco.

**Roteiro de conferência:** pesque algumas tainhas, atraque no Porto do Farol e venda. Aceite uma entrega, veja a carga
no porão (I) e a missão em J, leve à cidade indicada (B aponta o caminho) e entregue. Junte R$ 400 e melhore o porão
na doca seca: a barra do painel passa a 200 L. Feche o jogo e abra de novo: dinheiro e melhorias continuam lá.

**Refazer o mapa** depois de mudar `dados/mundo.json`: `python gerar_mapa.py [caminho_do_godot]` (recria
`cenas/Mapa.tscn`; retoques feitos à mão no editor se perdem).
