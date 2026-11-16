extends Node
## Melhorias do barco, compradas no cais: motor, tanque, porão e vara. Cada uma tem três níveis
## (o primeiro é o de fábrica). Quem cobra é scripts/jogo.gd; aqui ficam a tabela e o efeito de cada nível.

signal mudou

## nome na loja, a tecla no cais, o preço para subir a cada nível e o que cada nível dá
const TABELA := {
    "motor": {"nome": "Motor", "tecla": 3, "precos": [120, 260], "niveis": [5.7, 6.6, 7.5],
            "descricao": ["11 nós", "13 nós", "14,5 nós"]},
    "tanque": {"nome": "Tanque", "tecla": 4, "precos": [90, 200], "niveis": [60.0, 90.0, 120.0],
            "descricao": ["60 L", "90 L", "120 L"]},
    "porao": {"nome": "Porão", "tecla": 5, "precos": [150, 320], "niveis": [Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5)],
            "descricao": ["20 casas", "24 casas", "30 casas"]},
    "vara": {"nome": "Vara", "tecla": 6, "precos": [100, 240], "niveis": [1.0, 1.22, 1.45],
            "descricao": ["simples", "faixas verdes 22% maiores", "faixas verdes 45% maiores"]},
}
const ORDEM := ["motor", "tanque", "porao", "vara"]

var nivel: Dictionary = {"motor": 0, "tanque": 0, "porao": 0, "vara": 0}

func no_maximo(id: String) -> bool:
    return int(nivel[id]) >= TABELA[id].niveis.size() - 1

## Preço do próximo nível, ou -1 se já está no máximo.
func preco(id: String) -> int:
    return -1 if no_maximo(id) else int(TABELA[id].precos[int(nivel[id])])

func subir(id: String) -> void:
    if not no_maximo(id):
        nivel[id] = int(nivel[id]) + 1
        mudou.emit()

func valor(id: String):
    return TABELA[id].niveis[int(nivel[id])]

func zerar() -> void:
    for id in ORDEM:
        nivel[id] = 0
    mudou.emit()

## Põe os níveis atuais no barco, no porão e na pesca.
func aplicar(barco: Node, porao: Node, pesca: Node) -> void:
    barco.velocidade_maxima = float(valor("motor"))
    barco.tanque = float(valor("tanque"))
    barco.combustivel = minf(barco.combustivel, barco.tanque)
    var grade: Vector2i = valor("porao")
    porao.colunas = grade.x
    porao.linhas = grade.y
    pesca.fator_vara = float(valor("vara"))

## Linhas da loja para o painel do cais: {id, texto, pode}.
func vitrine(dinheiro: int) -> Array:
    var saida: Array = []
    for id in ORDEM:
        var t: Dictionary = TABELA[id]
        var n: int = int(nivel[id])
        if no_maximo(id):
            saida.append({"id": id, "texto": "%s: %s (máximo)" % [t.nome, t.descricao[n]], "pode": false})
        else:
            var p: int = int(t.precos[n])
            saida.append({"id": id, "texto": "%s: %s  →  %s   R$ %d   [%d]" % [t.nome, t.descricao[n], t.descricao[n + 1], p, t.tecla], "pode": dinheiro >= p})
    return saida
