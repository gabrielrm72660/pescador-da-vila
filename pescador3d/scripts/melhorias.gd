extends Node

const T = preload("res://scripts/idioma.gd")
## Melhorias do barco, compradas no cais: motor, tanque, porão e vara. Cada uma tem três níveis
## (o primeiro é o de fábrica). Quem cobra é scripts/jogo.gd; aqui ficam a tabela e o efeito de cada nível.

signal mudou

## nome na loja, a tecla no cais, o preço para subir a cada nível e o que cada nível dá
const TABELA := {
    "motor": {"nome": "Motor", "tecla": 3, "precos": [130, 340], "niveis": [5.7, 6.6, 7.5],
            "descricao": ["11 nós", "13 nós", "14,5 nós"]},
    "tanque": {"nome": "Tanque", "tecla": 4, "precos": [90, 240], "niveis": [60.0, 90.0, 120.0],
            "descricao": ["60 L", "90 L", "120 L"]},
    "porao": {"nome": "Porão", "tecla": 5, "precos": [160, 420], "niveis": [Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5)],
            "descricao": ["20 casas", "24 casas", "30 casas"]},
    "vara": {"nome": "Vara", "tecla": 6, "precos": [110, 300], "niveis": [1.0, 1.22, 1.45],
            "descricao": ["simples", "+22% acerto", "+45% acerto"]},
    "casco": {"nome": "Estabilizadores", "tecla": 7, "precos": [200, 520], "niveis": [1.0, 0.77, 0.56],
            "descricao": ["original", "balanço -23%", "balanço -44%"]},
    "leme": {"nome": "Leme", "tecla": 8, "precos": [150, 400], "niveis": [0.38, 0.47, 0.56],
            "descricao": ["original", "ágil", "hidráulico"]},
    "helice": {"nome": "Hélice", "tecla": 9, "precos": [190, 500], "niveis": [0, 1, 2],
            "descricao": ["original", "+20% acel.", "+40% acel."]},
    "radar": {"nome": "Radar", "tecla": 0, "precos": [170, 450], "niveis": [150.0, 225.0, 320.0],
            "descricao": ["150 m", "225 m", "320 m"]},
}
const ORDEM := ["motor", "tanque", "porao", "vara", "casco", "leme", "helice", "radar"]

var nivel: Dictionary = {"motor": 0, "tanque": 0, "porao": 0, "vara": 0, "casco": 0, "leme": 0, "helice": 0, "radar": 0}

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
func aplicar(barco: Node, porao: Node, pesca: Node, hud: Node = null) -> void:
    barco.velocidade_maxima = float(valor("motor"))
    barco.tanque = float(valor("tanque"))
    barco.combustivel = minf(barco.combustivel, barco.tanque)
    var grade: Vector2i = valor("porao")
    porao.colunas = grade.x
    porao.linhas = grade.y
    pesca.fator_vara = float(valor("vara"))
    barco.estabilidade = float(valor("casco"))
    barco.giro_maximo = float(valor("leme"))
    barco.aceleracao = 1.15 * (1.0 + 0.20 * int(valor("helice")))
    barco.consumo_maximo = 0.085 * (1.0 - 0.08 * int(valor("helice")))
    if hud != null:
        hud.alcance_radar = float(valor("radar"))

## Linhas da loja para o painel do cais: {id, texto, pode}.
func vitrine(dinheiro: int) -> Array:
    var saida: Array = []
    for id in ORDEM:
        var t: Dictionary = TABELA[id]
        var n: int = int(nivel[id])
        if no_maximo(id):
            saida.append({"id": id, "texto": T.t("%s\n%s (máximo)") % [T.t(String(t.nome)), T.t(String(t.descricao[n]))], "pode": false})
        else:
            var p: int = int(t.precos[n])
            saida.append({"id": id, "texto": T.t("[%d] %s\n%s → %s · R$ %d") % [t.tecla, T.t(String(t.nome)), T.t(String(t.descricao[n])), T.t(String(t.descricao[n + 1])), p], "pode": dinheiro >= p})
    return saida
