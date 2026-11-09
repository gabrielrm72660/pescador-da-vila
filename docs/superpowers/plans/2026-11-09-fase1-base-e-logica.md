# Pescador da Vila — Fase 1: base e lógica — Plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar o projeto Godot 4 do Pescador da Vila com os arquivos de dados e todas as regras puras do jogo
(espécies, medidor, varas, porão, mercado, catálogo, missões, estado e salvamento), cobertas por testes que rodam sem
tela.

**Architecture:** Projeto Godot em `pescador/` dentro do repositório. Regras em classes GDScript de `logica/` (estendem
`RefCounted`, sem nós de cena), balanceamento em JSON em `dados/`, estado da partida e salvamento em `autoload/`. Um
executor de testes próprio (`testes/rodar_testes.gd`, um `SceneTree`) roda todos os `testes/test_*.gd` com
`godot --headless`. Nenhuma cena visual nesta fase.

**Tech Stack:** Godot 4.7 (GDScript), JSON, Python 3 só para o lançador de testes (preferência do usuário: Python em
vez de `.bat`).

**Spec:** `docs/superpowers/specs/2026-11-09-pescador-da-vila-design.md` (versão 2). Esta é a fase 1 da seção 16; as
fases 2 a 6 terão planos próprios.

## Global Constraints

- Godot **4.7** (testado com 4.7.2 stable); GDScript, sem C#, sem addons.
- Só PC; resolução base **1920×1080**, stretch **"canvas_items"**, aspecto **"expand"**.
- Pastas exatamente como a seção 2 da spec: `dados/`, `logica/`, `autoload/`, `cenas/`, `ferramentas/`, `testes/`.
- `logica/` não usa nós nem tela; arquivos se referenciam por `preload("res://...")` (não dependem de `class_name`,
  porque o modo `--script` não carrega o cache de classes globais).
- Números *(proposta)* da spec ficam nos JSON de `dados/`, nunca fixos no código.
- Dinheiro em **R$ inteiros** (arredondar com `roundi`).
- Textos visíveis em português do Brasil.
- Lançadores e scripts auxiliares em **Python**, nunca `.bat`.

## Review Focus

1. **Dados inválidos ou faltando no JSON** (campo ausente, `tam_min ≥ tam_max`, zona fora de 0–2): o jogo deve falhar
   cedo com mensagem clara, não sortear valores absurdos → teste `test_dados.gd` (Task 9) valida todos os arquivos.
2. **Arquivo de salvamento corrompido, vazio ou de versão futura**: começar do zero sem travar e preservar o arquivo como
   `.bak` → testes em `test_salvamento.gd` (Task 8).
3. **Porão no limite** (peixe exatamente do tamanho do espaço livre; peixe maior que o porão inteiro; soltar índice
   inválido) → testes em `test_porao.gd` (Task 4).
4. **Missão impossível de cumprir** (prazo vencido, carga já não está no porão, entregar na cidade errada, 4ª missão
   ativa) → testes em `test_missoes.gd` (Task 7).
5. **Compra sem saldo ou além do nível máximo** (vara já possuída, melhoria no nível máximo, vara abissal fora de Ponta
   Negra, doca fora do Porto do Farol) → testes em `test_mercado.gd` (Task 5).

---

## Estrutura de arquivos desta fase

```
pescador/
├─ project.godot              Task 1 (autoloads registrados na Task 8)
├─ .gitignore                 Task 1 (ignora .godot/)
├─ rodar_testes.py            Task 1 — lançador em Python
├─ dados/especies.json        Task 2
├─ dados/mundo.json           Task 5 (cidades, farol, pontos de interesse)
├─ dados/cidades.json         Task 5 (economia de cada cidade)
├─ dados/loja.json            Task 5
├─ dados/missoes.json         Task 7
├─ logica/especies.gd         Task 2
├─ logica/medidor.gd          Task 3
├─ logica/varas.gd            Task 3
├─ logica/porao.gd            Task 4
├─ logica/mercado.gd          Task 5
├─ logica/catalogo.gd         Task 6
├─ logica/missoes.gd          Task 7
├─ autoload/Estado.gd         Task 8
├─ autoload/Salvamento.gd     Task 8
└─ testes/
   ├─ caso_teste.gd           Task 1 — base com as asserções
   ├─ rodar_testes.gd         Task 1 — executor
   └─ test_*.gd               um por task
```

---

### Task 1: Projeto Godot, executor de testes e lançador Python

**Files:**
- Create: `pescador/project.godot`, `pescador/.gitignore`, `pescador/icon.svg` (ícone simples de barco)
- Create: `pescador/testes/caso_teste.gd`, `pescador/testes/rodar_testes.gd`, `pescador/testes/test_sanidade.gd`
- Create: `pescador/rodar_testes.py`

**Interfaces:**
- Produces: `caso_teste.gd` (`extends RefCounted`) com `var falhas: Array[String]` e
  `afirmar(cond: bool, msg: String) -> void`, `igual(obtido, esperado, msg: String) -> void`,
  `perto(obtido: float, esperado: float, tol: float, msg: String) -> void`. Todo teste é um arquivo
  `testes/test_<nome>.gd` que `extends "res://testes/caso_teste.gd"` e tem métodos `test_*()` sem argumentos.
- Produces: comando de teste `godot --headless --path pescador --script res://testes/rodar_testes.gd`, que imprime
  `OK <arquivo>::<teste>` ou `FALHA <arquivo>::<teste>: <mensagens>`, o resumo `N testes, M falhas` e sai com código 0
  (tudo passou) ou 1.
- Produces: `python rodar_testes.py [caminho_do_godot]`, que acha o executável (argumento, variável `GODOT` ou `godot`
  no PATH), roda `--headless --import` uma vez e depois o comando acima, devolvendo o mesmo código de saída.

- [ ] **Step 1: Escrever `test_sanidade.gd`**

```gdscript
extends "res://testes/caso_teste.gd"

func test_asercoes_basicas():
	afirmar(true, "afirmar verdadeiro")
	igual(2 + 2, 4, "soma")
	perto(0.1 + 0.2, 0.3, 0.0001, "ponto flutuante")
```

- [ ] **Step 2: Criar `project.godot`, `caso_teste.gd`, `rodar_testes.gd`**

`project.godot`: `config/name="Pescador da Vila"`, `config/features=PackedStringArray("4.7")`, `run/main_scene` vazio
nesta fase, `window/size/viewport_width=1920`, `viewport_height=1080`, `window/stretch/mode="canvas_items"`,
`window/stretch/aspect="expand"`. `rodar_testes.gd` estende `SceneTree`; em `_init()` lista `res://testes/` com
`DirAccess`, carrega cada `test_*.gd` em ordem alfabética, instancia, chama cada método cujo nome começa com `test_`
(via `get_method_list()`), lê `falhas` depois de cada chamada (zerando antes) e termina com `quit(0 ou 1)`.

- [ ] **Step 3: Rodar e conferir**

Run: `godot --headless --path pescador --script res://testes/rodar_testes.gd`
Expected: `OK test_sanidade.gd::test_asercoes_basicas` e `1 testes, 0 falhas`, código de saída 0. Trocar
temporariamente `igual(2 + 2, 5, ...)` deve mostrar `FALHA` e sair com 1; desfazer depois.

- [ ] **Step 4: Criar `rodar_testes.py` e conferir**

Run: `python3 pescador/rodar_testes.py <caminho do godot>`
Expected: mesma saída do Step 3 e código 0.

- [ ] **Step 5: Commit**

```bash
git add pescador
git commit -m "Fase 1: projeto Godot, executor de testes e lançador Python"
```

---

### Task 2: Espécies — dados e sorteio

**Files:**
- Create: `pescador/dados/especies.json`, `pescador/logica/especies.gd`
- Test: `pescador/testes/test_especies.gd`

**Interfaces:**
- Produces (`logica/especies.gd`, `extends RefCounted`):
  - `static func carregar(caminho := "res://dados/especies.json") -> Array[Dictionary]` — lista das espécies (cada uma
    com os campos da spec 4.1 mais `tam_medio = (tam_min + tam_max) / 2`).
  - `static func por_id(lista: Array, id: String) -> Dictionary` (vazio se não existir).
  - `static func sortear_especie(lista: Array, zona: int, eh_noite: bool, clima: String, rng: RandomNumberGenerator) -> Dictionary`
  - `static func sortear_exemplar(esp: Dictionary, rng: RandomNumberGenerator, dourada := false) -> Dictionary` →
    `{especie: id, tam: float, f: float, classe: "P"|"M"|"G"|"Recorde", peso: float, volume: float, valor: int}`.
  - `static func exemplar_com_f(esp: Dictionary, f: float) -> Dictionary` — o mesmo cálculo a partir de um `f` dado
    (usado pelo medidor e pela rede).
  - `static func sortear_rede(esp: Dictionary, rng: RandomNumberGenerator) -> Array` — de 3 a 6 exemplares com
    `f = 0.5 × u^2.2` (só pequenos), para a rede (spec 5.2).
- Constantes no topo: `EXPOENTE_F = 2.2`, `LIMITES_CLASSE = [0.35, 0.70, 0.95]`, `MULT_RARIDADE = {comum 1.0,
  incomum 1.5, rara 3.0, lendaria 10.0}`, `BONUS_RECORDE = 1.5`, `PESO_SORTEIO = {comum 60, incomum 28, rara 10,
  lendaria 2}`.

**Dados de `especies.json`** (campos da spec 4.1; tamanhos e estilos da tabela 4.2; `sprite` =
`"res://arte/especies/<id>.png"`; os valores abaixo são *(proposta)*, com preço por litro subindo com a zona):

| id | categoria | k_peso | vol_medio | preco_base | qtd |
|---|---|---|---|---|---|
| sardinha | comum | 13 | 0.2 | 1 | [20, 40] |
| tainha | comum | 9 | 1.5 | 5 | [6, 12] |
| siri_azul | crustaceo | 55 | 0.3 | 3 | [3, 6] |
| arraia_pintada | arraia | 8 | 6 | 18 | [1, 1] |
| robalo | rara | 11 | 4 | 12 | [3, 5] |
| mero | lendaria | 30 | 60 | 180 | [1, 1] |
| atum | comum | 14 | 25 | 150 | [5, 9] |
| dourado | comum | 8 | 8 | 48 | [4, 7] |
| caranguejo_real | crustaceo | 120 | 2 | 20 | [2, 4] |
| jamanta | arraia | 6 | 120 | 720 | [1, 1] |
| espadarte | rara | 6 | 40 | 240 | [1, 1] |
| marlim_azul | lendaria | 7 | 70 | 420 | [1, 1] |
| peixe_lanterna | comum | 10 | 0.05 | 1 | [25, 50] |
| tamboril | comum | 25 | 3 | 45 | [1, 1] |
| caranguejo_aranha | crustaceo | 0.5 | 10 | 150 | [1, 2] |
| peixe_vibora | especial | 5 | 0.2 | 15 | [1, 1] |
| lula_gigante | rara | 0.3 | 150 | 2250 | [1, 1] |
| devorador_palido | lendaria | 0.5 | 300 | 4500 | [1, 1] |

- [ ] **Step 1: Escrever os testes**

```gdscript
extends "res://testes/caso_teste.gd"
const E = preload("res://logica/especies.gd")

func _rng(s := 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_dezoito_especies_seis_por_zona():
	var l = E.carregar()
	igual(l.size(), 18, "total")
	for z in 3:
		igual(l.filter(func(e): return e.zona == z).size(), 6, "zona %d" % z)

func test_faixas_do_design():
	var l = E.carregar()
	igual([E.por_id(l, "sardinha").tam_min, E.por_id(l, "sardinha").tam_max], [12.0, 25.0], "sardinha")
	igual([E.por_id(l, "mero").tam_min, E.por_id(l, "mero").tam_max], [80.0, 250.0], "mero")

func test_exemplar_dentro_da_faixa_e_classes():
	var esp = E.por_id(E.carregar(), "atum"); var r = _rng()
	for i in 2000:
		var ex = E.sortear_exemplar(esp, r)
		afirmar(ex.tam >= esp.tam_min and ex.tam <= esp.tam_max, "faixa")
		var c = "P" if ex.f < 0.35 else ("M" if ex.f < 0.70 else ("G" if ex.f < 0.95 else "Recorde"))
		igual(ex.classe, c, "classe")

func test_favorece_pequenos():
	var esp = E.por_id(E.carregar(), "tainha"); var r = _rng(); var p := 0; var rec := 0
	for i in 5000:
		var c = E.sortear_exemplar(esp, r).classe
		if c == "P": p += 1
		if c == "Recorde": rec += 1
	afirmar(p > 2500, "maioria P (%d)" % p)        # u^2.2 < 0.35 ⇔ u < 0.62
	afirmar(rec < 200, "Recorde raro (%d)" % rec)  # u > 0.977 → ~2,3%

func test_volume_e_valor_crescem_mais_que_o_tamanho():
	var esp = E.por_id(E.carregar(), "robalo")
	var a = E.exemplar_com_f(esp, 0.2); var b = E.exemplar_com_f(esp, 0.8)
	var razao_tam = b.tam / a.tam
	afirmar(b.volume / a.volume > razao_tam, "volume")
	afirmar(float(b.valor) / a.valor > razao_tam, "valor")

func test_formulas_no_tamanho_medio():
	var esp = E.por_id(E.carregar(), "atum")
	var ex = E.exemplar_com_f(esp, 0.5)              # f = 0,5 dá o tamanho médio
	perto(ex.tam, 155.0, 0.01, "tam médio")
	perto(ex.volume, 25.0, 0.01, "volume médio")
	igual(ex.valor, 150, "valor médio comum")        # classe M, sem bônus
	perto(ex.peso, 14.0 * pow(1.55, 3), 0.01, "peso")

func test_recorde_tem_bonus():
	var esp = E.por_id(E.carregar(), "atum")
	var ex = E.exemplar_com_f(esp, 0.96)
	igual(ex.classe, "Recorde", "classe")
	igual(ex.valor, roundi(150 * pow(ex.tam / 155.0, 1.6) * 1.5), "bônus 1,5")

func test_dourada_pega_o_maior_de_dois():
	var esp = E.por_id(E.carregar(), "dourado"); var s1 := 0.0; var s2 := 0.0
	var r1 = _rng(3); var r2 = _rng(3)
	for i in 3000:
		s1 += E.sortear_exemplar(esp, r1).f
		s2 += E.sortear_exemplar(esp, r2, true).f
	afirmar(s2 > s1 * 1.3, "dourada maior em média")

func test_rede_pega_varios_pequenos():
	var esp = E.por_id(E.carregar(), "sardinha"); var r = _rng()
	for i in 200:
		var lote = E.sortear_rede(esp, r)
		afirmar(lote.size() >= 3 and lote.size() <= 6, "3 a 6")
		for ex in lote: afirmar(ex.f <= 0.5, "só pequenos")

func test_horario_e_clima():
	var l = E.carregar(); var r = _rng(); var viu_dev := false
	for i in 4000:
		var e = E.sortear_especie(l, 2, false, "qualquer", r)
		afirmar(e.id != "devorador_palido", "devorador não aparece de dia")
		igual(e.zona, 2, "zona")
	for i in 20000:
		if E.sortear_especie(l, 2, true, "tempestade", r).id == "devorador_palido": viu_dev = true
	afirmar(viu_dev, "devorador aparece de noite na tempestade")

func test_noite_mais_dobra_a_chance():
	var l = E.carregar(); var r = _rng(); var dia := 0; var noite := 0
	for i in 20000:
		if E.sortear_especie(l, 2, false, "qualquer", r).id == "tamboril": dia += 1
		if E.sortear_especie(l, 2, true, "qualquer", r).id == "tamboril": noite += 1
	afirmar(noite > dia, "tamboril mais comum à noite (%d × %d)" % [noite, dia])
```

- [ ] **Step 2: Rodar e ver falhar** — Run: `python3 pescador/rodar_testes.py` · Expected: falhas em `test_especies.gd`
  (script `logica/especies.gd` inexistente).
- [ ] **Step 3: Criar `especies.json` e `especies.gd`** com as fórmulas da spec 4.3 (a classe usa `f` e
  `LIMITES_CLASSE`; volume e valor usam `tam / tam_medio`; `exemplar_com_f` é a base de `sortear_exemplar`, que gera
  `f = u ** 2.2`, e com `dourada` usa o maior de dois `u`). `sortear_especie`: filtra zona, `clima` ("tempestade" só
  quando a espécie pede tempestade e o clima é tempestade; espécie "qualquer" aparece em todo clima), horário
  (`so_noite` só com `eh_noite`; `noite_mais` peso ×2 de noite e ×0,5 de dia) e sorteia por `PESO_SORTEIO` com
  `rng.randf()`.
- [ ] **Step 4: Rodar e ver passar** — Expected: todos os testes de `test_especies.gd` com `OK`, 0 falhas.
- [ ] **Step 5: Commit** — `git commit -m "Fase 1: espécies (dados e sorteio)"`

---

### Task 3: Medidor de fisgada e varas

**Files:**
- Create: `pescador/logica/medidor.gd`, `pescador/logica/varas.gd`
- Test: `pescador/testes/test_medidor.gd`

**Interfaces:**
- Produces (`logica/medidor.gd`, `extends RefCounted`):
  - `func _init(periodo: float, verde: float, dourada: float, centro := 0.5)` — `verde` e `dourada` são larguras como
    fração da barra; as faixas ficam centradas em `centro`.
  - `func posicao(t: float) -> float` — onda triangular: 0 em t=0, 1 em t=periodo/2, 0 em t=periodo, e repete.
  - `func resultado(t: float) -> String` — `"dourada"`, `"verde"` ou `"erro"`; a borda conta como dentro, com folga
    de `1e-9` na comparação (evita erro de arredondamento).
  - `static func periodo_de(raridade: String) -> float` — comum 1.6, incomum 1.3, rara 1.0, lendaria 0.8.
  - `static func largura_verde(raridade: String, f_previsto: float, nivel_pescador: int) -> float` —
    `0.30 × FATOR_RARIDADE × (1 − 0.35 × f_previsto) × (1 + 0.08 × nivel_pescador)`, FATOR_RARIDADE comum 1.0, incomum
    0.85, rara 0.65, lendaria 0.45.
  - `const FRACAO_DOURADA = 0.25`.
- Produces (`logica/varas.gd`): `const VARAS = {"rasa": 0, "profunda": 1, "abissal": 2}` (zona máxima) e
  `static func alcanca(vara: String, zona: int) -> bool`, `static func melhor(varas: Array) -> String`.

- [ ] **Step 1: Escrever os testes**

```gdscript
extends "res://testes/caso_teste.gd"
const M = preload("res://logica/medidor.gd")
const V = preload("res://logica/varas.gd")

func test_posicao_triangular():
	var m = M.new(2.0, 0.3, 0.075)
	perto(m.posicao(0.0), 0.0, 1e-6, "início"); perto(m.posicao(1.0), 1.0, 1e-6, "meio")
	perto(m.posicao(0.5), 0.5, 1e-6, "subindo"); perto(m.posicao(1.5), 0.5, 1e-6, "descendo")
	perto(m.posicao(2.5), 0.5, 1e-6, "repete")

func test_resultado_por_faixa():
	var m = M.new(2.0, 0.3, 0.075)      # verde 0.35–0.65, dourada 0.4625–0.5375
	igual(m.resultado(0.5), "dourada", "no centro")      # posição 0.5
	igual(m.resultado(0.4), "verde", "dentro da verde")  # posição 0.4
	igual(m.resultado(0.2), "erro", "fora")              # posição 0.2
	igual(m.resultado(0.35), "verde", "borda inclusa")   # posição 0.35

func test_centro_deslocado():
	var m = M.new(2.0, 0.2, 0.05, 0.8)
	igual(m.resultado(0.8), "dourada", "centro 0.8"); igual(m.resultado(0.5), "erro", "0.5 fora")

func test_parametros_da_spec():
	perto(M.periodo_de("comum"), 1.6, 1e-6, "comum"); perto(M.periodo_de("lendaria"), 0.8, 1e-6, "lendária")
	perto(M.largura_verde("comum", 0.0, 0), 0.30, 1e-6, "base")
	perto(M.largura_verde("lendaria", 1.0, 0), 0.30 * 0.45 * 0.65, 1e-6, "lendária grande")
	perto(M.largura_verde("comum", 0.0, 5), 0.30 * 1.4, 1e-6, "Pescador 5")

func test_varas():
	afirmar(V.alcanca("rasa", 0) and not V.alcanca("rasa", 1), "rasa")
	afirmar(V.alcanca("profunda", 1) and not V.alcanca("profunda", 2), "profunda")
	afirmar(V.alcanca("abissal", 2) and V.alcanca("abissal", 0), "abissal")
	igual(V.melhor(["rasa", "abissal", "profunda"]), "abissal", "melhor vara")
	afirmar(not V.alcanca("inexistente", 0), "vara desconhecida não alcança nada")
```

- [ ] **Step 2: Rodar e ver falhar.**
- [ ] **Step 3: Implementar `medidor.gd` e `varas.gd`** conforme as interfaces.
- [ ] **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** — `git commit -m "Fase 1: medidor de fisgada e varas"`

---

### Task 4: Porão

**Files:**
- Create: `pescador/logica/porao.gd`
- Test: `pescador/testes/test_porao.gd`

**Interfaces:**
- Consumes: exemplares de `Especies.sortear_exemplar` (Task 2) e a lista de espécies (para saber a raridade ao comer).
- Produces (`logica/porao.gd`, `extends RefCounted`):
  - `var capacidade: float` (litros) e `var itens: Array[Dictionary]`; `func _init(capacidade_l := 100.0)`.
  - `func usado() -> float`, `func livre() -> float`.
  - `func adicionar(item: Dictionary) -> bool` — aceita exemplares e cargas (`{carga: true, missao: id, volume: L}`);
    falso se `item.volume > livre()` (igual ao livre cabe).
  - `func soltar(indice: int) -> Dictionary` — remove e devolve; índice inválido devolve `{}` sem erro.
  - `func menores(n: int) -> Array` — índices dos `n` peixes (não cargas) de menor volume.
  - `func comer(especies: Array) -> Dictionary` — remove e devolve o peixe de raridade `comum` de menor volume; `{}` se
    não houver.
  - `func peixes() -> Array[Dictionary]` (sem cargas), `func remover_carga(missao_id: String) -> bool`.
  - `func para_lista() -> Array` e `func carregar_lista(l: Array) -> void` (para o salvamento).
- Constante de níveis em `dados/loja.json` (Task 5): 100, 200, 400, 800 L.

- [ ] **Step 1: Escrever os testes**

```gdscript
extends "res://testes/caso_teste.gd"
const P = preload("res://logica/porao.gd")
const E = preload("res://logica/especies.gd")

func _ex(id: String, vol: float) -> Dictionary:
	return {"especie": id, "tam": 10.0, "f": 0.1, "classe": "P", "peso": 1.0, "volume": vol, "valor": 1}

func test_cabe_ate_o_limite():
	var p = P.new(100.0)
	afirmar(p.adicionar(_ex("atum", 60.0)), "60 cabe"); afirmar(p.adicionar(_ex("atum", 40.0)), "exato cabe")
	afirmar(not p.adicionar(_ex("sardinha", 0.1)), "cheio recusa"); perto(p.livre(), 0.0, 1e-6, "livre 0")

func test_maior_que_o_porao():
	var p = P.new(100.0)
	afirmar(not p.adicionar(_ex("mero", 128.0)), "mero recorde não cabe no porão inicial")
	igual(p.itens.size(), 0, "nada entrou")

func test_soltar_e_indice_invalido():
	var p = P.new(100.0); p.adicionar(_ex("tainha", 2.0))
	igual(p.soltar(5), {}, "índice inválido"); igual(p.soltar(-1), {}, "negativo")
	igual(p.soltar(0).especie, "tainha", "soltou"); igual(p.itens.size(), 0, "vazio")

func test_menores_ignora_carga():
	var p = P.new(200.0)
	p.adicionar(_ex("atum", 30.0)); p.adicionar({"carga": true, "missao": "m1", "volume": 1.0}); p.adicionar(_ex("tainha", 2.0))
	igual(p.menores(1), [2], "menor peixe é a tainha")

func test_comer_o_comum_menor():
	var l = E.carregar(); var p = P.new(100.0)
	p.adicionar(_ex("robalo", 1.0)); p.adicionar(_ex("tainha", 3.0)); p.adicionar(_ex("sardinha", 0.2))
	igual(p.comer(l).especie, "sardinha", "come a sardinha (comum, menor)")
	igual(p.comer(l).especie, "tainha", "depois a tainha; robalo é raro")
	igual(p.comer(l), {}, "não come o raro")

func test_carga_e_lista():
	var p = P.new(100.0); p.adicionar({"carga": true, "missao": "m7", "volume": 40.0}); p.adicionar(_ex("atum", 10.0))
	afirmar(p.remover_carga("m7"), "removeu carga"); afirmar(not p.remover_carga("m7"), "já não existe")
	var q = P.new(100.0); q.carregar_lista(p.para_lista()); igual(q.peixes().size(), 1, "ida e volta")
```

- [ ] **Step 2: Rodar e ver falhar.** · **Step 3: Implementar `porao.gd`.** · **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** — `git commit -m "Fase 1: porão por volume"`

---

### Task 5: Mundo, cidades, loja e mercado

**Files:**
- Create: `pescador/dados/mundo.json`, `pescador/dados/cidades.json`, `pescador/dados/loja.json`,
  `pescador/logica/mercado.gd`
- Test: `pescador/testes/test_mercado.gd`

**Interfaces:**
- Consumes: exemplares (Task 2), `Porao` (Task 4).
- Produces (`dados/mundo.json`, usado também pela fase 2):
  `{"cidades": [{id, nome, pos: [x, y], raio_cais: 120}], "farol": {pos: [250, -200], raio_seguro: 2500, alcance_luz: 8000},
  "rasas": [{centro, raio}], "fossas": [{id, centro, eixos: [a, b], rotacao}], "ilhotas": [{id, centro, raio}],
  "naufragios": [{id, nome, pos}]}` com os valores *(proposta)*:
  - cidades: `porto_farol` "Porto do Farol" [0, 0] · `vila_arraias` "Vila das Arraias" [4950, -4950] · `ponta_negra`
    "Ponta Negra" [-9900, 9900] (y cresce para baixo; ~7.000 a nordeste e ~14.000 a sudoeste)
  - rasas: discos de raio 2500 em porto_farol e ponta_negra, 3500 em vila_arraias, mais os das ilhotas
  - ilhotas: [3000, 2500] r 900 · [-3500, -3000] r 700 · [7500, 1500] r 1200 · [-6500, 4500] r 600 · [2000, -7500] r 1000
  - fossas: `fossa_negra` [-12500, 7000] eixos [2500, 1400] · `fossa_funda` [-8000, 14500] [2000, 1200] ·
    `fossa_sul` [6000, 9000] [1800, 1300] · `fossa_norte` [15000, -12000] [2400, 1500]
  - naufrágios: `naufragio_leste` "Naufrágio a leste da Vila das Arraias" [9000, -5200] · `naufragio_sul` [-4000, 8000] ·
    `naufragio_distante` [11000, 6000]
- Produces (`dados/cidades.json`): por cidade `{id, tem_doca, mult_categoria: {arraia, crustaceo}, mult_zona: [z0, z1, z2],
  itens_extras: [...]}` — porto_farol: doca, multiplicadores 1; vila_arraias: arraia 1.4, crustaceo 1.4; ponta_negra:
  zonas 1 e 2 ×1.5, itens_extras ["vara_abissal", "isca_abissal"].
- Produces (`dados/loja.json`): `balcao` {vara_profunda 600, vara_abissal 4000, rede 800, combustivel 2, agua 5,
  tabua 15, corda 10, conserto_lanterna 120, isca_abissal 30} e `melhorias` {porao: níveis [100, 200, 400, 800] L com
  preços [0, 400, 1500, 5000]; motor: níveis [1, 2, 3] preços [0, 1000, 3500]; tanque: [100, 160] [0, 600]; vela:
  [0, 1] [0, 700]; casco: [0, 1] [0, 900]; leme: [0, 1] [0, 400]; lente: [0, 1] [0, 500]}; `reparo_casco_por_ponto` 3;
  `carteira_inicial` 50.
- Produces (`logica/mercado.gd`, só funções `static`):
  - `carregar_dados() -> Dictionary` → `{mundo, cidades, loja}` dos três JSON; `cidade(dados, id) -> Dictionary` (junta
    o de `mundo` com o de `cidades`).
  - `preco_venda(ex: Dictionary, esp: Dictionary, cidade: Dictionary) -> int` = `roundi(ex.valor × mult_categoria ×
    mult_zona)`; multiplicadores ausentes valem 1.
  - `vender(porao, indices: Array, especies: Array, cidade: Dictionary) -> int` — remove os peixes (nunca cargas) e
    devolve o total; `vender_tudo(porao, especies, cidade) -> int`.
  - `item_disponivel(dados, item: String, cidade_id: String) -> bool` — `vara_abissal` e `isca_abissal` só onde
    estiverem em `itens_extras`; o resto em todas.
  - `comprar(dados, item: String, qtd: int, cidade_id: String, estado: Dictionary) -> String` — `estado` tem
    `dinheiro`, `varas`, `suprimentos`, `combustivel`, `tanque`; devolve `"ok"`, `"sem_dinheiro"`, `"indisponivel"`,
    `"ja_tem"`; varas entram em `estado.varas`; combustível não passa de `tanque`.
  - `preco_melhoria(dados, id: String, nivel_atual: int) -> int` (−1 no máximo) e
    `melhorar(dados, id, cidade_id, estado) -> String` — `"ok"`, `"sem_doca"`, `"maximo"`, `"sem_dinheiro"`; nível em
    `estado.melhorias[id]`.
  - `preco_reparo(dados, dano: int) -> int`.

- [ ] **Step 1: Escrever os testes**

```gdscript
extends "res://testes/caso_teste.gd"
const MK = preload("res://logica/mercado.gd")
const E = preload("res://logica/especies.gd")
const P = preload("res://logica/porao.gd")

var d; var l
func _init(): d = MK.carregar_dados(); l = E.carregar()
func _estado(din := 1000) -> Dictionary:
	return {"dinheiro": din, "varas": ["rasa"], "suprimentos": {"agua": 0, "tabua": 0, "corda": 0},
			"combustivel": 90, "tanque": 100, "melhorias": {}}

func test_tres_cidades_e_doca_so_no_porto():
	igual(d.mundo.cidades.size(), 3, "cidades")
	afirmar(MK.cidade(d, "porto_farol").tem_doca, "porto tem doca")
	afirmar(not MK.cidade(d, "vila_arraias").tem_doca and not MK.cidade(d, "ponta_negra").tem_doca, "outras não")

func test_preco_por_cidade():
	var esp = E.por_id(l, "arraia_pintada"); var ex = E.exemplar_com_f(esp, 0.5)
	igual(MK.preco_venda(ex, esp, MK.cidade(d, "porto_farol")), ex.valor, "normal")
	igual(MK.preco_venda(ex, esp, MK.cidade(d, "vila_arraias")), roundi(ex.valor * 1.4), "+40% arraia")
	var atum = E.por_id(l, "atum"); var ea = E.exemplar_com_f(atum, 0.5)
	igual(MK.preco_venda(ea, atum, MK.cidade(d, "ponta_negra")), roundi(ea.valor * 1.5), "+50% profunda")

func test_vender_tudo_preserva_carga():
	var p = P.new(100.0); var esp = E.por_id(l, "tainha")
	p.adicionar(E.exemplar_com_f(esp, 0.5)); p.adicionar({"carga": true, "missao": "m1", "volume": 20.0})
	var total = MK.vender_tudo(p, l, MK.cidade(d, "porto_farol"))
	afirmar(total > 0, "recebeu"); igual(p.itens.size(), 1, "carga ficou")

func test_comprar_regras():
	var e = _estado(500)
	igual(MK.comprar(d, "vara_profunda", 1, "porto_farol", e), "sem_dinheiro", "600 > 500")
	e.dinheiro = 5000
	igual(MK.comprar(d, "vara_abissal", 1, "porto_farol", e), "indisponivel", "abissal só em Ponta Negra")
	igual(MK.comprar(d, "vara_abissal", 1, "ponta_negra", e), "ok", "comprou"); igual(e.dinheiro, 1000, "pagou")
	igual(MK.comprar(d, "vara_abissal", 1, "ponta_negra", e), "ja_tem", "não compra de novo")
	igual(MK.comprar(d, "combustivel", 50, "porto_farol", e), "ok", "combustível")
	igual(e.combustivel, 100, "não passa do tanque"); igual(e.dinheiro, 1000 - 20, "paga só os 10 que couberam")

func test_doca_seca():
	var e = _estado(10000)
	igual(MK.melhorar(d, "porao", "vila_arraias", e), "sem_doca", "só no Porto do Farol")
	igual(MK.preco_melhoria(d, "porao", 0), 400, "porão nível 1")
	for i in 3: igual(MK.melhorar(d, "porao", "porto_farol", e), "ok", "nível %d" % (i + 1))
	igual(MK.melhorar(d, "porao", "porto_farol", e), "maximo", "800 L é o máximo")
	igual(e.dinheiro, 10000 - 400 - 1500 - 5000, "pagou os três")
	igual(MK.preco_reparo(d, 20), 60, "R$ 3 por ponto")
```

- [ ] **Step 2: Rodar e ver falhar.** · **Step 3: Criar os três JSON e `mercado.gd`.** (Combustível parcial: compra só o
  que cabe no tanque e cobra por isso; se nada couber, `"ja_tem"`.) · **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** — `git commit -m "Fase 1: mundo, cidades, loja e mercado"`

---

### Task 6: Catálogo

**Files:**
- Create: `pescador/logica/catalogo.gd`
- Test: `pescador/testes/test_catalogo.gd`

**Interfaces:**
- Produces (`logica/catalogo.gd`, `extends RefCounted`):
  - `var entradas: Dictionary` — por id de espécie: `{qtd: int, recorde_cm: float, classe: String, titulo: bool}`.
  - `func registrar(ex: Dictionary) -> Dictionary` → `{nova: bool, recorde: bool}` (o primeiro exemplar conta como
    nova e também como recorde).
  - `func dar_titulo(especie_id: String) -> void` (troféu lendário, usado pelas missões).
  - `func conhecidas() -> int`, `func para_dict() -> Dictionary`, `func carregar_dict(d: Dictionary) -> void`.

- [ ] **Step 1: Escrever os testes**

```gdscript
extends "res://testes/caso_teste.gd"
const C = preload("res://logica/catalogo.gd")

func test_nova_especie_e_recorde():
	var c = C.new()
	igual(c.registrar({"especie": "atum", "tam": 100.0, "classe": "M"}), {"nova": true, "recorde": true}, "primeira")
	igual(c.registrar({"especie": "atum", "tam": 90.0, "classe": "M"}), {"nova": false, "recorde": false}, "menor")
	igual(c.registrar({"especie": "atum", "tam": 180.0, "classe": "G"}), {"nova": false, "recorde": true}, "maior")
	igual(c.entradas.atum.qtd, 3, "contagem"); perto(c.entradas.atum.recorde_cm, 180.0, 1e-6, "recorde")
	igual(c.conhecidas(), 1, "uma espécie")

func test_titulo_e_ida_e_volta():
	var c = C.new(); c.registrar({"especie": "mero", "tam": 200.0, "classe": "G"}); c.dar_titulo("mero")
	var c2 = C.new(); c2.carregar_dict(c.para_dict())
	afirmar(c2.entradas.mero.titulo, "título salvo"); igual(c2.entradas.mero.qtd, 1, "qtd salva")
```

- [ ] **Step 2: Rodar e ver falhar.** · **Step 3: Implementar.** · **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** — `git commit -m "Fase 1: catálogo e recordes"`

---

### Task 7: Missões

**Files:**
- Create: `pescador/dados/missoes.json`, `pescador/logica/missoes.gd`
- Test: `pescador/testes/test_missoes.gd`

**Interfaces:**
- Consumes: espécies (Task 2), `Porao` (Task 4), `Mercado.carregar_dados` e `mundo.json` (Task 5), `Catalogo` (Task 6).
- Produces (`dados/missoes.json`, *(proposta)*): `ofertas_por_cidade` 3, `max_ativas` 3, `encomenda` {qtd [2, 5],
  classe_min ["P", "M", "G"], prazo_dias [2, 4], mult_recompensa 1.5, xp 20}, `trofeu` {f_min 0.75, prazo_dias [3, 5],
  mult_recompensa 3.0, xp 40}, `entrega` {volume [20, 60], prazo_dias [1, 3], reais_por_px 0.06, xp 15},
  `exploracao` {raio 300, recompensa 150, xp 25}. Pedidos de espécies por cidade: porto_farol só zona 0; vila_arraias
  zonas 0–1; ponta_negra zonas 1–2.
- Produces (`logica/missoes.gd`, funções `static`; missão = Dictionary):
  - campos comuns: `id` (`"<cidade>-<dia>-<n>"`), `tipo`, `cidade` (onde se entrega), `prazo_dia` (−1 sem prazo),
    `recompensa_xp`; encomenda: `especie`, `qtd`, `classe_min`; troféu: `especie`, `tam_min`; entrega: `destino`,
    `volume`, `recompensa`; exploração: `alvo` (id de ponto de `mundo.json`), `pos`, `recompensa`.
  - `gerar(dados, especies, cidade_id: String, dia: int, zona_max: int, rng) -> Array` — 3 ofertas de tipos variados;
    espécies limitadas às zonas da cidade **e** a `zona_max + 1` (desafio de no máximo uma zona acima).
  - `aceitar(dados, ativas: Array, oferta: Dictionary, porao) -> bool` — falso se já houver `max_ativas`; ao aceitar,
    acrescenta a oferta em `ativas`; numa entrega, antes coloca a carga no porão (`{carga: true, missao: id, volume}`) e
    falha (sem acrescentar) se não couber.
  - `progresso(m, porao, pos: Vector2, dia: int) -> Dictionary` → `{feito: int, total: int, pronta: bool,
    vencida: bool}`; exploração fica pronta a ≤ `raio` do alvo.
  - `entregar(m, porao, especies, cidade_id: String, dia: int, catalogo) -> Dictionary` → `{ok: bool, motivo: String,
    reais: int, xp: int}`; motivos de falha: `"vencida"`, `"cidade_errada"`, `"incompleta"`. Encomenda e troféu
    removem do porão os exemplares usados (os menores que servem) e pagam `mult × soma dos valores`; troféu de espécie
    lendária chama `catalogo.dar_titulo`; entrega remove a carga e paga `recompensa`.
  - `vencidas(ativas: Array, dia: int) -> Array` (para a interface avisar e remover).

- [ ] **Step 1: Escrever os testes**

```gdscript
extends "res://testes/caso_teste.gd"
const MI = preload("res://logica/missoes.gd")
const MK = preload("res://logica/mercado.gd")
const E = preload("res://logica/especies.gd")
const P = preload("res://logica/porao.gd")
const C = preload("res://logica/catalogo.gd")

var d; var l
func _init(): d = MK.carregar_dados(); l = E.carregar()
func _rng(s := 11):
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_gerar_respeita_progresso():
	var r = _rng()
	for dia in 30:
		var of = MI.gerar(d, l, "ponta_negra", dia, 0, r)
		igual(of.size(), 3, "três ofertas")
		for m in of:
			if m.has("especie"): afirmar(E.por_id(l, m.especie).zona <= 1, "no máximo uma zona acima da vara rasa")

func test_porto_so_pede_rasas():
	for m in MI.gerar(d, l, "porto_farol", 1, 2, _rng()):
		if m.has("especie"): igual(E.por_id(l, m.especie).zona, 0, "rasas")

func test_maximo_de_ativas_e_carga():
	var p = P.new(100.0); var ativas := []
	var ent = {"id": "x-1-0", "tipo": "entrega", "cidade": "ponta_negra", "destino": "ponta_negra", "volume": 40.0,
			"recompensa": 840, "prazo_dia": 3, "recompensa_xp": 15}
	afirmar(MI.aceitar(d, ativas, ent, p), "aceitou"); perto(p.usado(), 40.0, 1e-6, "carga no porão")
	for i in 2: ativas.append({"id": "e%d" % i, "tipo": "exploracao"})
	afirmar(not MI.aceitar(d, ativas, {"id": "z", "tipo": "exploracao"}, p), "4ª recusada")

func test_encomenda_completa_e_paga():
	var p = P.new(100.0); var tainha = E.por_id(l, "tainha"); var c = C.new()
	for f in [0.5, 0.6, 0.1]: p.adicionar(E.exemplar_com_f(tainha, f))
	var m = {"id": "m", "tipo": "encomenda", "cidade": "porto_farol", "especie": "tainha", "qtd": 2,
			"classe_min": "M", "prazo_dia": 5, "recompensa_xp": 20}
	igual(MI.progresso(m, p, Vector2.ZERO, 1).feito, 2, "duas M servem; a P não")
	igual(MI.entregar(m, p, l, "vila_arraias", 1, c).motivo, "cidade_errada", "cidade errada")
	var r = MI.entregar(m, p, l, "porto_farol", 1, c)
	afirmar(r.ok, "entregou"); igual(p.peixes().size(), 1, "sobrou a P")
	igual(r.reais, roundi(1.5 * (E.exemplar_com_f(tainha, 0.5).valor + E.exemplar_com_f(tainha, 0.6).valor)), "1,5×")

func test_prazo_vencido():
	var m = {"id": "m", "tipo": "trofeu", "cidade": "porto_farol", "especie": "robalo", "tam_min": 90.0,
			"prazo_dia": 2, "recompensa_xp": 40}
	afirmar(MI.progresso(m, P.new(), Vector2.ZERO, 3).vencida, "venceu")
	igual(MI.entregar(m, P.new(), l, "porto_farol", 3, C.new()).motivo, "vencida", "não entrega")
	igual(MI.vencidas([m], 3).size(), 1, "listada como vencida")

func test_trofeu_lendario_da_titulo():
	var p = P.new(800.0); var mero = E.por_id(l, "mero"); var c = C.new()
	p.adicionar(E.exemplar_com_f(mero, 0.9))
	var m = {"id": "t", "tipo": "trofeu", "cidade": "porto_farol", "especie": "mero", "tam_min": 200.0,
			"prazo_dia": -1, "recompensa_xp": 40}
	c.registrar(p.peixes()[0])
	afirmar(MI.entregar(m, p, l, "porto_farol", 9, c).ok, "entregou"); afirmar(c.entradas.mero.titulo, "título")

func test_exploracao_por_distancia():
	var m = {"id": "x", "tipo": "exploracao", "cidade": "vila_arraias", "alvo": "naufragio_leste",
			"pos": [9000, -5200], "recompensa": 150, "prazo_dia": -1, "recompensa_xp": 25}
	afirmar(not MI.progresso(m, P.new(), Vector2(8000, -5200), 1).pronta, "longe")
	afirmar(MI.progresso(m, P.new(), Vector2(8750, -5200), 1).pronta, "a 250 px")
```

- [ ] **Step 2: Rodar e ver falhar.** · **Step 3: Criar `missoes.json` e `missoes.gd`.** Entrega gerada: destino é
  outra cidade; `recompensa = roundi(0.06 × distância entre as cidades)`. Exploração gerada: alvo sorteado entre
  naufrágios, fossas e ilhotas, `pos` copiada de `mundo.json`. Troféu gerado: `tam_min = tam_min + 0.75 × (tam_max −
  tam_min)`. · **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** — `git commit -m "Fase 1: missões"`

---

### Task 8: Estado da partida e salvamento

**Files:**
- Create: `pescador/autoload/Estado.gd`, `pescador/autoload/Salvamento.gd`
- Modify: `pescador/project.godot` (seção `[autoload]`: `Estado="*res://autoload/Estado.gd"`,
  `Salvamento="*res://autoload/Salvamento.gd"`)
- Test: `pescador/testes/test_salvamento.gd`

**Interfaces:**
- Consumes: `Porao` (Task 4), `Catalogo` (Task 6), `loja.json` (Task 5).
- Produces (`autoload/Estado.gd`, `extends Node`):
  - campos com os nomes do JSON da spec 12: `dinheiro`, `dia`, `cidade`, `destino`, `varas`, `vara`, `melhorias`,
    `combustivel`, `casco`, `suprimentos`, `porao` (instância de `Porao`), `catalogo` (instância de `Catalogo`),
    `missoes` (`{ativas: [], ofertas: {}}`), `pontos_achados`, `xp`, `habilidades`, `config`.
  - sinais `dinheiro_mudou(valor: int)`, `porao_mudou()`, `missoes_mudaram()`.
  - `func novo_jogo() -> void` (dinheiro = `carteira_inicial` de loja.json; porão 100 L; vara "rasa"; combustível 100;
    casco 100; suprimentos água 2, tábua 2, corda 2; config efeitos 7, música 5, tela_cheia true).
  - `func para_dict() -> Dictionary` (com `"versao": 1`) e `func de_dict(d: Dictionary) -> void` (campos ausentes
    ficam com o valor de `novo_jogo`).
- Produces (`autoload/Salvamento.gd`, `extends Node`):
  - `const CAMINHO = "user://save.json"`, `const VERSAO = 1`.
  - `func salvar(dados: Dictionary, caminho := CAMINHO) -> bool` (grava num `.tmp` e renomeia, para não corromper
    se o jogo fechar no meio).
  - `func carregar(caminho := CAMINHO) -> Dictionary` — `{}` se não existir; se o JSON for inválido, não for objeto ou
    tiver `versao` maior que `VERSAO`, renomeia para `<caminho>.bak` e devolve `{}`.

- [ ] **Step 1: Escrever os testes**

```gdscript
extends "res://testes/caso_teste.gd"
const EST = preload("res://autoload/Estado.gd")
const SAL = preload("res://autoload/Salvamento.gd")
const TESTE = "user://teste_save.json"

func _limpar():
	for c in [TESTE, TESTE + ".bak", TESTE + ".tmp"]:
		if FileAccess.file_exists(c): DirAccess.remove_absolute(ProjectSettings.globalize_path(c))

func test_novo_jogo():
	var e = EST.new(); e.novo_jogo()
	igual(e.dinheiro, 50, "carteira inicial"); igual(e.varas, ["rasa"], "vara rasa")
	perto(e.porao.capacidade, 100.0, 1e-6, "porão 100 L"); igual(e.cidade, "porto_farol", "começa no porto")
	e.free()

func test_ida_e_volta():
	_limpar(); var e = EST.new(); e.novo_jogo(); var s = SAL.new()
	e.dinheiro = 777; e.porao.adicionar({"especie": "atum", "tam": 150.0, "f": 0.5, "classe": "M",
			"peso": 50.0, "volume": 25.0, "valor": 150})
	e.catalogo.registrar({"especie": "atum", "tam": 150.0, "classe": "M"})
	afirmar(s.salvar(e.para_dict(), TESTE), "salvou")
	var e2 = EST.new(); e2.de_dict(s.carregar(TESTE))
	igual(e2.dinheiro, 777, "dinheiro"); igual(e2.porao.peixes().size(), 1, "porão")
	igual(e2.catalogo.entradas.atum.qtd, 1, "catálogo")
	e.free(); e2.free(); s.free(); _limpar()

func test_arquivo_inexistente():
	_limpar(); var s = SAL.new(); igual(s.carregar(TESTE), {}, "vazio"); s.free()

func test_corrompido_vira_bak():
	_limpar(); var f = FileAccess.open(TESTE, FileAccess.WRITE); f.store_string("{isto não é json"); f.close()
	var s = SAL.new(); igual(s.carregar(TESTE), {}, "começa do zero")
	afirmar(FileAccess.file_exists(TESTE + ".bak"), "guardou .bak"); s.free(); _limpar()

func test_versao_futura_vira_bak():
	_limpar(); var s = SAL.new(); s.salvar({"versao": 99}, TESTE)
	igual(s.carregar(TESTE), {}, "não abre versão futura")
	afirmar(FileAccess.file_exists(TESTE + ".bak"), "guardou .bak"); s.free(); _limpar()

func test_campos_ausentes_usam_padrao():
	var e = EST.new(); e.de_dict({"versao": 1, "dinheiro": 5})
	igual(e.dinheiro, 5, "lido"); igual(e.vara, "rasa", "padrão"); e.free()
```

- [ ] **Step 2: Rodar e ver falhar.** · **Step 3: Implementar `Estado.gd` e `Salvamento.gd` e registrar os autoloads.**
  · **Step 4: Rodar e ver passar.**
- [ ] **Step 5: Commit** — `git commit -m "Fase 1: estado da partida e salvamento"`

---

### Task 9: Validação dos dados e fechamento da fase

**Files:**
- Test: `pescador/testes/test_dados.gd`
- Create: `pescador/LEIAME.md` (como abrir o projeto no Godot 4.7 e como rodar os testes com `python rodar_testes.py`)

**Interfaces:**
- Consumes: os quatro JSON de `dados/` e os carregadores das Tasks 2, 5 e 7.

- [ ] **Step 1: Escrever os testes**

```gdscript
extends "res://testes/caso_teste.gd"
const E = preload("res://logica/especies.gd")
const MK = preload("res://logica/mercado.gd")

const CAMPOS = ["id", "nome", "zona", "categoria", "raridade", "tam_min", "tam_max", "k_peso", "vol_medio",
		"preco_base", "horario", "clima", "estilo", "qtd", "sprite"]

func test_especies_validas():
	var ids := {}
	for e in E.carregar():
		for c in CAMPOS: afirmar(e.has(c), "%s sem %s" % [e.get("id", "?"), c])
		afirmar(e.zona in [0, 1, 2], "%s zona" % e.id)
		afirmar(e.tam_min > 0 and e.tam_min < e.tam_max, "%s tamanho" % e.id)
		afirmar(e.raridade in ["comum", "incomum", "rara", "lendaria"], "%s raridade" % e.id)
		afirmar(e.horario in ["qualquer", "noite_mais", "so_noite"] and e.clima in ["qualquer", "tempestade"], "%s horário/clima" % e.id)
		afirmar(e.qtd[0] >= 1 and e.qtd[0] <= e.qtd[1], "%s qtd" % e.id)
		afirmar(not ids.has(e.id), "%s repetido" % e.id); ids[e.id] = true
	for z in 3:
		var l = E.carregar().filter(func(x): return x.zona == z)
		igual(l.filter(func(x): return x.raridade == "rara").size(), 1, "uma rara na zona %d" % z)
		igual(l.filter(func(x): return x.raridade == "lendaria").size(), 1, "uma lendária na zona %d" % z)

func test_mundo_e_loja_coerentes():
	var d = MK.carregar_dados()
	for c in d.mundo.cidades: afirmar(MK.cidade(d, c.id).has("tem_doca"), "%s sem economia" % c.id)
	igual(d.mundo.fossas.size(), 4, "4 fossas"); igual(d.mundo.ilhotas.size(), 5, "5 ilhotas")
	igual(d.mundo.naufragios.size(), 3, "3 naufrágios")
	for m in d.loja.melhorias.values(): igual(m.niveis.size(), m.precos.size(), "níveis e preços")
	for f in d.mundo.fossas:
		var dist = Vector2(f.centro[0], f.centro[1]).length()
		afirmar(dist >= 9000 and dist <= 22000, "%s entre 9.000 e 22.000" % f.id)
```

- [ ] **Step 2: Rodar a suíte inteira** — Run: `python3 pescador/rodar_testes.py` · Expected: todos os arquivos
  `test_*.gd` com `OK` e `0 falhas`.
- [ ] **Step 3: Escrever `LEIAME.md`** (abrir `pescador/project.godot` no Godot 4.7; rodar os testes; onde ficam os
  dados para balancear).
- [ ] **Step 4: Abrir o projeto no editor sem erros** — Run:
  `godot --headless --path pescador --editor --quit` · Expected: termina sem `ERROR` de script na saída.
- [ ] **Step 5: Commit** — `git commit -m "Fase 1: validação dos dados e LEIAME"`
