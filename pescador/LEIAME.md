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
