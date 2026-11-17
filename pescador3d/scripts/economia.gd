extends Node
## Cotações variáveis e encomendas do mercado local.
## Não altera a definição dos peixes nem as formas do porão.

const CONTRATOS := [
    {"especie": "Tainha", "quantidade": 3, "premio": 70},
    {"especie": "Xaréu", "quantidade": 2, "premio": 90},
    {"especie": "Garoupa", "quantidade": 1, "premio": 130},
    {"especie": "Cavala", "quantidade": 2, "premio": 120},
    {"especie": "Atum", "quantidade": 1, "premio": 200},
    {"especie": "Robalo", "quantidade": 2, "premio": 90},
    {"especie": "Budião", "quantidade": 2, "premio": 70},
    {"especie": "Arabaiana", "quantidade": 1, "premio": 140},
    {"especie": "Peixe-anjo", "quantidade": 2, "premio": 90},
    {"especie": "Namorado", "quantidade": 1, "premio": 140},
]
var indice: int = 0
var contratos_concluidos: int = 0

func atual() -> Dictionary:
    return CONTRATOS[posmod(indice, CONTRATOS.size())]

## Oscilação leve e determinística; sem saltos de cotação a cada atualização do HUD.
func fator_preco(especie: String, hora: float) -> float:
    var indice_especie: int = absi(str(especie).hash()) % 17
    var fase: float = float(indice_especie) * 0.61 + hora * 0.16
    return clampf(1.0 + 0.17 * sin(fase), 0.82, 1.18)

func valor_porao(porao: Node, cardumes: Node, bonus_ilha: float, hora: float) -> int:
    var total: int = 0
    for item in porao.itens:
        var v: int = cardumes.valor(String(item.especie), float(item.peso))
        var grau: String = String(item.get("qualidade", "Regular"))
        var fator_grau: float = 1.28 if grau == "Excepcional" else (1.12 if grau == "Boa" else 1.0)
        total += maxi(1, roundi(float(v) * bonus_ilha * fator_preco(String(item.especie), hora) * fator_grau))
    return total

func quantidade_contrato(porao: Node) -> int:
    var qtd: int = 0
    var especie: String = String(atual().especie)
    for item in porao.itens:
        if String(item.especie) == especie:
            qtd += 1
    return qtd

func premio_venda(porao: Node) -> int:
    var contrato: Dictionary = atual()
    if quantidade_contrato(porao) < int(contrato.quantidade):
        return 0
    var valor: int = int(contrato.premio)
    indice += 1
    contratos_concluidos += 1
    return valor

func texto_contrato(porao: Node) -> String:
    var contrato: Dictionary = atual()
    return "Encomenda: %d %s (%d/%d) · bônus R$ %d" % [int(contrato.quantidade), String(contrato.especie),
        mini(quantidade_contrato(porao), int(contrato.quantidade)), int(contrato.quantidade), int(contrato.premio)]

func zerar() -> void:
    indice = 0
    contratos_concluidos = 0
