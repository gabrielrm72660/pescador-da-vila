# Fase 2 — Mundo e barco: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O jogador abre o projeto no Godot, aperta F5 e pilota o pesqueiro pelo arquipélago: motor com marchas, vela com vento, combustível, colisão com ilhas, cais para atracar, farol com luz e zona segura, bússola e ciclo de dia e noite.

**Architecture:** As regras novas ficam em `logica/` (tempo, navegação, mapa), testadas no modo headless como na fase 1. Um script de ferramenta gera a cena do mapa (`TileMapLayer` com tiles provisórios coloridos) a partir de `dados/mundo.json`. As cenas (`Barco`, `Mundo`, `HUD`) só leem a lógica e mostram; recebem a configuração por propriedades, sem depender dos autoloads, para poderem ser instanciadas nos testes.

**Tech Stack:** Godot 4.7, GDScript, executor de testes próprio (`testes/rodar_testes.gd`), lançadores em Python.

**Spec:** `docs/superpowers/specs/2026-11-09-pescador-da-vila-design.md` (seções 7.4, 9, 10, 13, 16 item 2)

## Global Constraints

- Godot 4.7; janela 1920×1080, stretch `canvas_items`, aspecto `expand`.
- Classes de `logica/` estendem `RefCounted`, usam funções estáticas e se referenciam por `preload` (sem `class_name`).
- Números do jogo original (`jogo/main.py`): `DURACAO_DIA = 150.0`, `ALONGA_DIA = 0.55`, brilho `clamp(0.5 + 0.8·sin(τ·(fase − 0.25)), 0.12, 1.0)`, noite `clamp((1 − brilho)/0.88, 0, 1)`, é noite quando noite > 0,35; vento gira a `uniform(−0.09, 0.09)` rad/s trocado a cada `uniform(6, 12)` s; força do vento `1 + 1.4·tempestade`; vela `95 × (1,3 com vela grande) × força × max(0.1, cos(ângulo relativo))`; aceleração `vel += (alvo − vel)·min(1, 1.3·dt)`; deriva: corrente 10 px/s + vento 6·força px/s; giro 1,6 rad/s (2,0 com leme melhorado).
- Da spec: motor 150 / 185 / 220 px/s nos níveis 1–3; marchas 0, ¼, ½, máx; consumo 0,8 un./s na máxima, proporcional à marcha; tanque 100 (160); sem combustível o motor para; motor e vela somam até a velocidade máxima do motor; zona segura 2.500 px do farol; alcance da luz 8.000 px; tecla B troca o destino da bússola.
- Todo lançador é Python, nunca `.bat`.
- Arte provisória (cores e polígonos); a arte do SpriteCook é da fase 6.

## Review Focus

1. O barco encosta numa ilha em ângulo e fica preso, ou atravessa um canto do tile — esperado: desliza pela costa (`move_and_slide`) e nunca entra em terra.
2. Combustível acaba no meio do mar — esperado: o motor para, mas a vela e a deriva ainda movem o barco (o jogador não fica travado para sempre).
3. Apertar E para atracar em alta velocidade ou longe do cais — esperado: só atraca a até `raio_cais` do cais e abaixo de 40 px/s; senão mostra o motivo.
4. Vento exatamente contra a proa — esperado: a vela ainda rende 10% (o `max(0.1, cos)` do original), nunca velocidade negativa.
5. Borda do mundo — esperado: uma parede invisível segura o barco fora do mapa; a bússola e o farol continuam apontando certo de qualquer lugar.

---

### Task 1: Tempo (dia e noite)

**Files:**
- Create: `pescador/logica/tempo.gd`
- Test: `pescador/testes/test_tempo.gd`

**Interfaces:**
- Produces: `Tempo.DURACAO_DIA := 150.0`, `Tempo.ALONGA_DIA := 0.55`, `Tempo.T_INICIAL` (instante do ciclo em que o sol está na fase 0,3 — começo da manhã), `fase_do_dia(t: float) -> float`, `brilho(t: float) -> float`, `noite(t: float) -> float`, `eh_noite(t: float) -> bool`, `dia_de(t: float) -> int` (1 no primeiro ciclo), `hora_texto(t: float) -> String` ("06:00" quando a fase é 0,25; 24 h).

- [ ] **Step 1: Escrever o teste que falha** — `test_fase_tem_amanhecer_e_meio_dia` (fase(0)=0, fase(75)=0,5, fase(37,5) > 0,25 porque o dia se alonga); `test_brilho_e_noite` (brilho no meio-dia = 1,0, à meia-noite = 0,12; `eh_noite(0)` verdadeiro, `eh_noite(75)` falso); `test_dia_conta_ciclos` (`dia_de(0)` = 1, `dia_de(150)` = 2, `dia_de(449)` = 3); `test_hora_texto` (`hora_texto(0)` = "00:00", hora no instante da fase 0,25 = "06:00"); `test_t_inicial_e_manha` (perto(fase_do_dia(T_INICIAL), 0.3, 1e-3), não é noite).
- [ ] **Step 2: Rodar e ver falhar** — `python3 pescador/rodar_testes.py <godot>` → FALHA test_tempo.gd (não carrega).
- [ ] **Step 3: Implementar `logica/tempo.gd`** — fórmulas das Global Constraints; `T_INICIAL` por busca binária igual a `tempo_da_fase` do original (40 iterações), calculado numa função estática `tempo_da_fase(fase) -> float` e exposto como constante via função `t_inicial()` se a constante não puder ser calculada em tempo de compilação (registrar Ruling).
- [ ] **Step 4: Rodar** → todos passam.
- [ ] **Step 5: Commit** `feat: ciclo de dia e noite (logica/tempo.gd)`.

### Task 2: Navegação (motor, vela, vento, combustível)

**Files:**
- Create: `pescador/logica/navegacao.gd`
- Test: `pescador/testes/test_navegacao.gd`

**Interfaces:**
- Produces:
  - `MARCHAS := [-0.2, 0.0, 0.25, 0.5, 1.0]` (índice 0 = ré lenta, 1 = parado); `MARCHA_PARADO := 1`.
  - `vel_motor(nivel_motor: int) -> float` → 150/185/220 (nível 1–3, valores fora da faixa ficam no limite).
  - `vel_vela(vela_grande: bool, forca_vento: float, ang_barco: float, ang_vento: float) -> float`.
  - `velocidade_alvo(marcha: int, nivel_motor: int, com_combustivel: bool, vela_aberta: bool, vela_grande: bool, forca_vento: float, ang_barco: float, ang_vento: float) -> float` — motor `MARCHAS[marcha]·vel_motor` (0 sem combustível) + vela (se aberta e marcha ≥ parado), limitado a `vel_motor(nivel)`; ré não soma vela.
  - `acelerar(vel: float, alvo: float, dt: float) -> float`.
  - `consumo(marcha: int, dt: float, nivel_motorista := 0) -> float` → `0.8·|MARCHAS[marcha]|·dt·(1 − 0.07·nivel)`.
  - `taxa_giro(leme_melhorado: bool) -> float` → 1,6 / 2,0.
  - `deriva(ang_corrente: float, ang_vento: float, forca_vento: float) -> Vector2`.
  - Classe interna de instância `Vento` (`var ang`, `var giro`, `var tm`; `_init(rng)`; `atualizar(dt, rng)`): mesma regra do original.

- [ ] **Step 1: Teste que falha** — `test_vel_motor_por_nivel` (150/185/220; nível 0 → 150; nível 9 → 220); `test_marcha_maxima_sem_vela` (alvo = 185 no nível 2); `test_vela_a_favor_e_contra` (vento a favor = 95; contra = 9,5; vela grande a favor = 123,5); `test_motor_e_vela_somam_ate_o_teto` (marcha ½ nível 1 + vela a favor = min(75+95, 150) = 150); `test_sem_combustivel_so_vela` (marcha máx sem combustível, vela fechada → 0; vela aberta a favor → 95); `test_re_nao_soma_vela` (marcha 0 → −30 no nível 1 mesmo com vela); `test_consumo_proporcional` (máx 1 s = 0,8; ½ = 0,4; parado = 0; motorista nível 2 na máx = 0,688); `test_acelerar_aproxima` (acelerar(0, 100, 0.5) = 65; dt grande não passa do alvo); `test_vento_gira_devagar` (100 atualizações de 0,1 s mudam o ângulo no máximo 0,9 rad; `tm` sempre em (0, 12]).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar `logica/navegacao.gd`.**
- [ ] **Step 4: Rodar** → passam.
- [ ] **Step 5: Commit** `feat: motor, vela, vento e combustível (logica/navegacao.gd)`.

### Task 3: Mapa (zonas, ilhas, cais, farol e bússola)

**Files:**
- Modify: `pescador/dados/mundo.json` — cada cidade ganha `"raio_ilha": 600` e `"cais": [x, y]` (ponto na água, a `raio_ilha + 80` do centro, voltado para o mar aberto: Porto do Farol `[0, 680]`, Vila das Arraias `[4950, -4270]`, Ponta Negra `[-9900, 9220]`); novo bloco `"mapa": {"celula": 128, "limite": 20480, "fracao_terra_ilhota": 0.35}`.
- Create: `pescador/logica/mapa.gd`
- Modify: `pescador/logica/mercado.gd` (`validar_dados` confere `raio_ilha`, `cais` fora da terra e o bloco `mapa`)
- Test: `pescador/testes/test_mapa.gd`

**Interfaces:**
- Consumes: `Mercado.carregar_dados() -> {mundo, cidades, loja}`.
- Produces:
  - `TERRA := -1`; `zona_em(mundo: Dictionary, pos: Vector2) -> int` — terra (disco `raio_ilha` das cidades; disco `raio·fracao_terra_ilhota` das ilhotas) > abissal (dentro de uma elipse de fossa, rotação em graus) > rasa (disco de `rasas` ou disco `raio` da ilhota) > profunda.
  - `NOMES_ZONA := ["Rasas", "Profundas", "Abissais"]`.
  - `cais_proximo(mundo, pos: Vector2) -> Dictionary` → a cidade (dicionário do mundo) cujo cais está a até `raio_cais`, ou `{}`.
  - `na_zona_segura(mundo, pos: Vector2) -> bool`.
  - `destinos(mundo, extras: Array = []) -> Array` → `[{id, nome, pos: Vector2}]` das 3 cidades na ordem do JSON, seguidas dos `extras` (fase 4 passa alvos de missão).
  - `proximo_destino(lista: Array, atual_id: String) -> String` (cíclico; id desconhecido → primeiro).
  - `rumo(de: Vector2, para: Vector2) -> float` (radianos, mesma convenção de `Vector2.angle()`); `distancia_milhas(de, para) -> float` (px/200, como a bússola do original).

- [ ] **Step 1: Teste que falha** — `test_zonas_em_pontos_conhecidos` (centro do Porto = TERRA; farol = TERRA; [0, 1500] = 0; [0, 4000] = 1; centro da Fossa Negra = 2; borda da Fossa Norte no eixo maior girado = 2 e logo fora = 1; centro da Ilhota Grande = TERRA, a 0,8·raio = 0); `test_cais_ficam_na_agua_e_perto_da_cidade` (para cada cidade, `zona_em(cais)` ≠ TERRA e `cais_proximo(cais).id` = cidade; a 200 px do cais → `{}`); `test_zona_segura` (farol + 2.499 = segura; + 2.501 = não); `test_destinos_ciclam` (porto → vila → ponta → porto; extra aparece depois de Ponta Negra; id inválido → porto_farol); `test_rumo_e_milhas` (rumo de (0,0) a (0,−100) = −π/2; 2.000 px = 10 mi); `test_validar_dados_aponta_cais_em_terra` (mover o cais do Porto para [0,0] → erro citando porto_farol).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** `mapa.gd`, os campos novos de `mundo.json` e a validação.
- [ ] **Step 4: Rodar** → passam (incluindo os 52 da fase 1).
- [ ] **Step 5: Commit** `feat: mapa do arquipélago em lógica (zonas, cais, farol, bússola)`.

### Task 4: Tiles provisórios e gerador do mapa

**Files:**
- Create: `pescador/ferramentas/gerar_arquipelago.gd` (estende `SceneTree`; roda com `godot --headless --script`)
- Create: `pescador/gerar_mapa.py` (lançador Python: `--import` e depois o script; mesmo padrão de `rodar_testes.py`)
- Generated (commitados): `pescador/arte/provisorio/tiles.png`, `pescador/arte/provisorio/tiles.tres` (TileSet), `pescador/cenas/Mapa.tscn`
- Test: `pescador/testes/test_mapa_gerado.gd`

**Interfaces:**
- Consumes: `Mapa.zona_em`, bloco `mapa` de `mundo.json`.
- Produces:
  - `gerar_arquipelago.gd` com funções estáticas testáveis: `criar_tileset() -> TileSet` (atlas 4×1 de 128 px: rasa `#3ec1c9`, profunda `#1f4e8c`, abissal `#0b1526`, terra `#c9b27a`; dado personalizado `zona` (int) = 0, 1, 2, −1; camada de física 0 com polígono do tile inteiro só na terra) e `pintar(camada: TileMapLayer, mundo: Dictionary, regiao: Rect2i) -> void` (cada célula recebe o tile de `zona_em` no centro da célula).
  - `cenas/Mapa.tscn`: raiz `TileMapLayer` chamada `Mapa`, cobrindo `[-limite, limite)` nos dois eixos (320×320 células), com uma moldura `StaticBody2D` `Borda` (4 `CollisionShape2D` retangulares fora do limite).
- Ruling previsto: a spec fala em shader de água animado; nesta fase os tiles são cores sólidas e o shader fica para a fase 6 (arte e ajuste) — o jogo já é pilotável e a cena aceita o shader depois sem mudar a lógica.

- [ ] **Step 1: Teste que falha** — `test_tileset_tem_zonas_e_colisao` (4 tiles; `zona` correta em cada; só a terra tem polígono de colisão); `test_pintar_regiao_pequena` (pintar `Rect2i(-8, -8, 16, 16)` numa `TileMapLayer` nova: célula (0,0) é terra, célula (0,12) — fora da região — vazia, célula (0,7) tem a `zona` de `zona_em(célula·128 + 64)`); `test_mapa_gerado_bate_com_a_logica` (carrega `res://cenas/Mapa.tscn`; 400 células sorteadas com semente fixa têm `zona` igual a `zona_em` no centro; tem o nó `Borda` com 4 formas).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** o gerador e o lançador; rodar `python3 pescador/gerar_mapa.py <godot>` para criar os três arquivos.
- [ ] **Step 4: Rodar os testes** → passam.
- [ ] **Step 5: Commit** `feat: gerador do arquipélago e mapa com tiles provisórios`.

### Task 5: Barco

**Files:**
- Modify: `pescador/project.godot` — mapa de entradas da spec 13 usado nesta fase: `motor_subir` (W, ↑), `motor_descer` (S, ↓), `virar_esq` (A, ←), `virar_dir` (D, →), `vela` (V), `atracar` (E), `destino` (B), `tela_cheia` (F11).
- Create: `pescador/cenas/Barco.tscn`, `pescador/cenas/barco.gd`
- Test: `pescador/testes/test_barco.gd`

**Interfaces:**
- Consumes: `Navegacao.*`, `Navegacao.Vento`.
- Produces: `Barco.tscn` = `CharacterBody2D` `Barco` com `Polygon2D` provisório (casco + casa de leme, proa para +x), `CollisionPolygon2D`, `PointLight2D` `Lanterna`, `GPUParticles2D` `Esteira`. Script `barco.gd`:
  - propriedades configuráveis: `nivel_motor := 1`, `vela_grande := false`, `leme_melhorado := false`, `tanque := 100.0`, `combustivel := 100.0`, `nivel_motorista := 0`;
  - estado: `marcha := Navegacao.MARCHA_PARADO`, `vela_aberta := false`, `vel := 0.0`, `atracado := false`;
  - `passo(dt: float, entrada: Dictionary, vento_ang: float, forca_vento: float, corrente_ang: float) -> void` — `entrada` = `{subir: bool, descer: bool, virar: float(−1..1), vela: bool}` (subir/descer/vela são "apertou neste quadro"); atualiza marcha, vela, rumo (`rotation`), `vel`, combustível (nunca < 0) e `velocity` (= frente·vel + deriva); atracado ignora tudo e zera `velocity`;
  - `_physics_process` monta a `entrada` pelo `Input` e chama `passo` + `move_and_slide()`;
  - sinal `combustivel_mudou(valor: float)`.

- [ ] **Step 1: Teste que falha** — `test_marchas_sobem_e_descem_no_limite` (4 "subir" a partir de parado → índice 4; mais um continua 4; 5 "descer" → índice 0 = ré); `test_passo_gasta_combustivel_e_acelera` (marcha máx, 1 s em passos de 0,1 → combustível ≈ 99,2 ± 0,01; `vel` > 0; `velocity` aponta para a frente do barco ± deriva); `test_sem_combustivel_o_motor_para` (combustível 0,05, marcha máx, 1 s → combustível 0, `vel` cai rumo a 0 com vela fechada); `test_atracado_nao_se_move` (atracado, marcha máx → `velocity` = 0 e combustível intacto); `test_vela_alterna` (dois apertos de vela → fechada de novo).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** a cena, o script e o mapa de entradas.
- [ ] **Step 4: Rodar** → passam.
- [ ] **Step 5: Commit** `feat: pesqueiro com motor, vela e combustível`.

### Task 6: Mundo (câmera, dia/noite, farol, cidades, atracar)

**Files:**
- Create: `pescador/cenas/Mundo.tscn`, `pescador/cenas/mundo.gd`, `pescador/cenas/Farol.tscn`, `pescador/cenas/farol.gd`, `pescador/cenas/Principal.tscn` (cena principal; por ora abre direto o Mundo — o menu é da fase 6)
- Modify: `pescador/project.godot` (`run/main_scene="res://cenas/Principal.tscn"`)
- Test: `pescador/testes/test_mundo.gd`

**Interfaces:**
- Consumes: `Mapa.tscn`, `Barco.tscn`, `Tempo.*`, `Mapa.*` (lógica), `Navegacao.Vento`.
- Produces:
  - `Mundo.tscn`: `Mapa` (instância), `Cidades` (um `Node2D` por cidade com `Polygon2D` de casinhas e cais provisórios + `Label` com o nome), `Farol` (instância), `Barco` (instância) com `Camera2D` filha (suavizada), `CanvasModulate` `Luz`, `HUD` (instância — Task 7; até lá, opcional).
  - `mundo.gd`: `var t: float` (começa em `Tempo.T_INICIAL`), `var vento` (`Navegacao.Vento`), `var destino_id := "porto_farol"`, `var dia := 1`; `_process` avança `t`, atualiza vento, cor do `CanvasModulate` (`Color(1,1,1)` × brilho, com tom azulado à noite), `Farol.aceso = Tempo.eh_noite(t)`, conta dias; trata `atracar` (só com `Mapa.cais_proximo` e `vel < 40`; atracar encaixa o barco no cais, zera marcha; apertar de novo desatraca) e `destino` (B → `Mapa.proximo_destino`); expõe `dados_hud() -> Dictionary` com `{marcha, vela, combustivel, tanque, zona_nome, dia, hora, destino_nome, rumo_destino, milhas, rumo_farol, farol_visivel, aviso}` para o HUD.
  - Integração com `Estado` só aqui, e só se o autoload existir (`get_node_or_null("/root/Estado")`): lê nível do motor/vela/leme/tanque e combustível ao começar; grava `cidade` ao atracar e `combustivel`/`dia`. Nos testes, sem autoload, usa os valores padrão.
  - `Farol.tscn`: `Node2D` com torre provisória (`Polygon2D`), `PointLight2D` `Facho` com textura de cone gerada por código (gradiente), gira a 0,8 rad/s quando `aceso`; `PointLight2D` `Brilho` circular pequeno.
- Ruling previsto: "fora da tela, um brilho na borda indica a direção" do farol é feito no HUD (Task 7), não no Mundo.

- [ ] **Step 1: Teste que falha** — `test_mundo_instancia_com_os_nos` (`Mundo.tscn` instancia; tem `Mapa`, `Barco`, `Farol`, `Luz`, `Cidades` com 3 filhos); `test_comeca_atracado_no_porto` (depois de `_ready` manual: barco na posição do cais do Porto do Farol, `atracado` verdadeiro); `test_atracar_so_perto_e_devagar` (chamar `tentar_atracar()` longe do cais → falso e `aviso` com "cais"; perto a 100 px/s → falso e `aviso` com "devagar"; perto e parado → verdadeiro); `test_destino_cicla_com_b` (`trocar_destino()` três vezes volta ao porto); `test_dados_hud_tem_as_chaves` (todas as chaves acima presentes; `zona_nome` em `Mapa.NOMES_ZONA` ou "Terra").
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar** → passam.
- [ ] **Step 5: Commit** `feat: mundo com câmera, dia e noite, farol e cais`.

### Task 7: HUD

**Files:**
- Create: `pescador/cenas/ui/HUD.tscn`, `pescador/cenas/ui/hud.gd`
- Modify: `pescador/cenas/Mundo.tscn` (adiciona o HUD), `pescador/LEIAME.md` (como rodar a fase 2 e o roteiro de conferência)
- Test: `pescador/testes/test_hud.gd`

**Interfaces:**
- Consumes: `Mundo.dados_hud()`.
- Produces: `HUD.tscn` = `CanvasLayer` com `Painel` (canto inferior esquerdo: marcha "R / 0 / ¼ / ½ / MÁX", vela "Vela aberta/fechada", barra de combustível com número, zona, "Dia N — HH:MM"), `Bussola` (canto superior direito: seta girada para `rumo_destino`, nome do destino, "N mi"), `IndicadorFarol` (seta amarela na borda da tela quando `farol_visivel` e o farol está fora da tela), `Aviso` (texto central que some em 2,5 s). `hud.gd`: `atualizar(d: Dictionary) -> void` e `TEXTO_MARCHA := ["R", "0", "¼", "½", "MÁX"]`.

- [ ] **Step 1: Teste que falha** — `test_hud_mostra_os_valores` (instanciar, `atualizar` com dados fixos: rótulo da marcha = "½", combustível "62 / 100", texto do dia "Dia 2 — 18:30", bússola "Vila das Arraias — 35 mi", seta com `rotation` = `rumo_destino`); `test_indicador_do_farol_some_de_dia` (`farol_visivel` falso → indicador invisível); `test_aviso_aparece_e_some` (aviso "x" → visível; depois de `_process(3.0)` → invisível).
- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar** e ligar o HUD no Mundo.
- [ ] **Step 4: Rodar a suíte inteira** → todos passam; abrir o editor em headless (`godot --headless --editor --quit`) sem erros.
- [ ] **Step 5: Commit** `feat: HUD da navegação e LEIAME da fase 2`.

**Conferência do usuário (LEIAME):** abrir `pescador/` no Godot 4.7, F5; desatracar com E, subir marchas com W, abrir a vela com V, virar com A/D, ver o combustível cair, bater numa ilhota e deslizar, esperar a noite (~1 min) e ver o farol girar, apertar B e seguir a bússola até a Vila das Arraias, atracar com E.
