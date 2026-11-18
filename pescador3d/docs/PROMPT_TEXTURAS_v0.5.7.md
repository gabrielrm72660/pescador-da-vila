# Pedido de texturas: jogo "Pescador" (v0.5.7)

Você vai criar texturas para um jogo 3D de pesca feito na Godot 4. O jogo se passa em ilhas tropicais inventadas no litoral do Nordeste brasileiro, inspiradas em Fernando de Noronha. O barco do jogador é um pesqueiro de madeira chamado **Estrela d'Alva**.

## Estilo (vale para todas)

- **Pintura à mão / aquarela com guache**, no espírito de *Life is Strange* (2015): pinceladas visíveis, cores um pouco dessaturadas, nada fotorrealista, nada de "cartoon plástico".
- **Sem iluminação gravada na textura**: sem sombra projetada, sem brilho especular, sem luz vindo de um lado. A luz é feita pelo jogo.
- **Repetíveis sem emenda (seamless/tileable)** nas duas direções, salvo onde o item disser o contrário. Teste colocando 2×2 cópias lado a lado: não pode aparecer linha nem padrão repetido óbvio (evite um elemento marcante que se repita).
- **PNG, RGB 8 bits, sem canal alfa** (salvo onde dito). Tamanho 1024×1024.
- Nada de texto, logotipo, marca d'água ou assinatura.
- Paleta geral: mar turquesa, areia clara amarelada, mato verde-amarelado, rocha vulcânica cinza-escura com tons de ferrugem, terra avermelhada.

## Mapas normais (quando pedido)

- Mesmo nome com `_normal` no fim, 512×512, formato **OpenGL (Y+, verde para cima)**, tangente.
- Relevo suave, coerente com a textura de cor (fendas, ripas, grãos). Sem ruído fino de alta frequência.

## Lista de texturas

### A. Terreno das ilhas (pasta `assets/texturas/ilha/`)

Vistas **de cima** (projetadas no chão), escala de cerca de **9 m por repetição** (areia, mato) e **22 m** (rocha).

1. **`areia.png`**: areia de praia clara e fina, levemente amarelada, com marcas suaves do vento e pequenas manchas de conchas trituradas. Sem pegadas, sem objetos.
2. **`grama.png`**: mato rasteiro tropical visto de cima, verde-amarelado com manchas mais escuras e algumas folhas secas. Pinceladas curtas em várias direções. Não pode parecer gramado de jardim.
3. **`rocha.png`** + **`rocha_normal.png`**: rocha vulcânica (basalto/fonolito) cinza-escura, com camadas horizontais discretas, fissuras e manchas de ferrugem e líquen claro.
4. **`barranco.png`** + **`barranco_normal.png`** (**NOVA**): **parede vertical** de barranco costeiro de terra (laterita) **vista de lado**. Terra avermelhada e ocre em **faixas horizontais** (estratos), algumas raízes finas escuras saindo na parte de cima, pedrinhas encravadas e marcas verticais de erosão da chuva. A parte de baixo é um pouco mais clara e acinzentada (sal), a de cima mais escura (matéria orgânica). Escala de **cerca de 8 m por repetição**. Precisa repetir sem emenda **na horizontal**; na vertical também, mas a variação de cima para baixo deve ser suave.

### B. Barco do jogador, aspecto de usado (pasta `assets/barco/`)

O modelo 3D já existe. Mantenha **os mesmos nomes de arquivo**: o jogo troca as imagens sem mexer no modelo. Todas são **madeira pintada de barco de pesca artesanal brasileiro, com anos de uso**: tinta desbotada pelo sol, lascas mostrando a madeira por baixo, sal e encardido. O desgaste deve ser **moderado**, como num barco que trabalha todo dia, e não um barco abandonado.

Tábuas **horizontais** (no costado, cerca de 8 ripas por imagem, com as juntas aparecendo como linhas finas escuras), salvo onde dito.

5. **`PE3476_v4_casco_branco.png`** + `_normal`: costado branco-creme (tinta velha, quase gelo), lascas pequenas nas juntas, escorridos finos de ferrugem descendo de pregos, leve sujeira esverdeada no terço de baixo.
6. **`PE3476_v4_casco_vermelho.png`** + `_normal`: obra viva (a parte que fica na água), tinta antivegetativa **vermelho-tijolo escuro**, com cracas pequenas, limo verde-marrom e áreas onde a tinta saiu.
7. **`PE3476_v4_pintura_azul.png`** + `_normal`: faixa de borda (a "verdugada") e detalhes em **azul-cobalto desbotado**, com lascas brancas e madeira aparecendo.
8. **`PE3476_v4_pintura_creme.png`** + `_normal`: paredes da casaria (cabine), creme, tábuas **verticais** estreitas, marcas de mão perto das portas, sal.
9. **`PE3476_v4_pintura_laranja.png`** + `_normal`: teto da cabine, laranja desbotado, quase salmão, com sujeira acumulada nos cantos.
10. **`PE3476_v4_conves.png`** + `_normal`: convés de tábuas de madeira **sem pintura**, cinza-prateado de sol e sal, com manchas escuras de óleo e escamas, tábuas **no sentido do comprimento**.
11. **`PE3476_v4_madeira_escura.png`** + `_normal`: madeira escura envernizada já gasta (mastro, bordas, molduras), com veios.
12. **`PE3476_v4_metal.png`** + `_normal`: ferragem galvanizada velha, cinza com ferrugem alaranjada nas bordas.

### C. Placa de nome (pasta `assets/barco/`)

13. **`estrela_dalva_nome.png`**: 1024×256, **RGBA com fundo transparente**. O nome **"Estrela d'Alva"** pintado à mão com pincel em **azul-marinho**, letra cursiva de letreiro de barco de pesca nordestino, com pequenas falhas de tinta. Centralizado, ocupando cerca de 85% da largura. **Não** repete (não precisa ser seamless).

## Como entregar

- Um ZIP **por grupo** (A, B, C), cada um com **no máximo 40 MB**: os ZIPs grandes chegam truncados.
- Dentro do ZIP, só os PNGs com os nomes exatos acima, sem subpastas.
- Junto, um `LEIA-ME.txt` curto dizendo qual arquivo é qual e se algum ficou de fora.
