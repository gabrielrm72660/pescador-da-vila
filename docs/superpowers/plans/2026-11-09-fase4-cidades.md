# Fase 4 — Cidades (plano)

**Objetivo:** fechar o ciclo pescar → vender → melhorar: mercado de peixe ao atracar (vender, missões, balcão), doca
seca no Porto do Farol, missões completas e salvamento automático. Spec: seções 7.2, 7.3, 8 e 12. Base: `fase3-pesca`.

## Decisões desta fase

- O Mundo passa a trabalhar sempre com um **Estado**: o autoload quando existe, ou um próprio (novo jogo) nos testes.
- As regras de mercado continuam em `logica/mercado.gd` recebendo um dicionário; o Estado monta esse dicionário e
  grava o resultado de volta (resolve a pendência "Mercado recebe Dictionary, mas o Estado é um Node").
- Comprar a melhoria do porão atualiza a capacidade na hora (pendência da fase 1).
- Item do balcão sem tratamento é recusado antes de cobrar (problema adiado da fase 1).
- Atracar abre o mercado e salva. O jogo começa atracado com o mercado fechado; atracado, **M** reabre o mercado e
  **E** zarpa. Com o mercado aberto o tempo do mundo para.
- As ofertas de cada cidade são sorteadas na primeira visita do dia e trocadas quando o dia muda.
- Exploração: chegar ao ponto marca "achado" e avisa; a recompensa é paga na cidade que deu a missão.
- A bússola (B) também passa pelos alvos das missões ativas.
- Ficam para depois: retrato e fala do NPC (fase 6), destaque de primeira captura na venda, baús (fase 5).

## Tarefas

1. **Estado** (`autoload/Estado.gd`, testes em `test_estado_cidade.gd`): `comprar`, `melhorar`, `reparar_casco`,
   `vender`/`vender_tudo`, `ofertas_de`, `aceitar_missao`, `entregar_missao`, `expirar_missoes`, `marcar_exploracao`;
   carregar o save ao iniciar. `Missoes.descricao` e `Missoes.texto_progresso` para a interface.
2. **Tela do mercado** (`cenas/ui/tela_mercado.gd`, testes em `test_mercado_ui.gd`): abas Vender, Missões, Balcão e,
   só com doca, Doca seca; cada botão chama o Estado e a tela se refaz.
3. **Painel de missões** (tecla J) com o progresso de cada ativa.
4. **Mundo** (testes em `test_cidades.gd`): atracar abre o mercado e salva; M reabre; tempo parado com o mercado
   aberto; melhorias valem no barco ao fechar; missões vencem na virada do dia; exploração detectada no mar; bússola
   com alvos de missão.
5. **Revisão e PR #4.** Conferir: vender com carga de missão no porão; aceitar entrega sem espaço; melhorar sem
   dinheiro; missão vencida com a tela aberta; save de um jogo no meio do mar (posição volta ao último cais).
