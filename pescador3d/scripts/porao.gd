extends Node
## O porão do barco: uma grade onde cada peixe ocupa um formato. Peixe grande ocupa mais casas, e o que
## não cabe não vem a bordo. Dá para arrumar à mão (painel do porão, scripts/hud.gd) ou pedir para arrumar.

signal mudou

const Cardumes = preload("res://scripts/cardumes.gd")

## As casas que cada espécie ocupa (coluna, linha), deitada. Girar é por conta do jogador.
const FORMAS := {
    "Sardinha": [Vector2i(0, 0)],
    "Tainha": [Vector2i(0, 0), Vector2i(1, 0)],
    "Xaréu": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
    "Cavala": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
    "Olho-de-cão": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
    "Garoupa": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
}
const CORES := {
    "Sardinha": Color(0.62, 0.76, 0.84), "Tainha": Color(0.74, 0.78, 0.66), "Xaréu": Color(0.90, 0.78, 0.40),
    "Cavala": Color(0.40, 0.66, 0.78), "Garoupa": Color(0.82, 0.52, 0.38), "Olho-de-cão": Color(0.90, 0.30, 0.28),
}

var colunas: int = 5
var linhas: int = 4
var itens: Array = []            # {especie, peso, x, y, rot}

## As casas de uma espécie girada "rot" quartos de volta, encostadas no canto (0, 0).
func casas(especie: String, rot: int = 0) -> Array:
    var saida: Array = []
    for c in FORMAS.get(especie, [Vector2i(0, 0)]):
        var v: Vector2i = c
        for i in posmod(rot, 4):
            v = Vector2i(-v.y, v.x)
        saida.append(v)
    var menor := Vector2i(99, 99)
    for v in saida:
        menor = Vector2i(mini(menor.x, v.x), mini(menor.y, v.y))
    for i in saida.size():
        saida[i] -= menor
    return saida

func casas_do_item(item: Dictionary) -> Array:
    var saida: Array = []
    for c in casas(item.especie, item.rot):
        saida.append(c + Vector2i(item.x, item.y))
    return saida

## O item que ocupa a casa, ou {}.
func item_em(casa: Vector2i) -> Dictionary:
    for item in itens:
        if casa in casas_do_item(item):
            return item
    return {}

func cabe_em(especie: String, x: int, y: int, rot: int, ignorar: Dictionary = {}) -> bool:
    for c in casas(especie, rot):
        var casa: Vector2i = c + Vector2i(x, y)
        if casa.x < 0 or casa.y < 0 or casa.x >= colunas or casa.y >= linhas:
            return false
        var dono := item_em(casa)
        if not dono.is_empty() and not is_same(dono, ignorar):
            return false
    return true

## O primeiro lugar livre para a espécie ({x, y, rot}), ou {}.
func achar_lugar(especie: String) -> Dictionary:
    for rot in [0, 1]:
        for y in linhas:
            for x in colunas:
                if cabe_em(especie, x, y, rot):
                    return {"x": x, "y": y, "rot": rot}
    return {}

func cabe(especie: String) -> bool:
    if not achar_lugar(especie).is_empty():
        return true
    var antes := _copia()                    # arrumando tudo de novo, cabe?
    var ok := arrumar() and not achar_lugar(especie).is_empty()
    itens = antes
    return ok

## Guarda um peixe; arruma o porão se for preciso. Falso = não coube.
func guardar(especie: String, peso: float) -> bool:
    var lugar := achar_lugar(especie)
    if lugar.is_empty():
        arrumar()
        lugar = achar_lugar(especie)
        if lugar.is_empty():
            return false
    itens.append({"especie": especie, "peso": peso, "x": lugar.x, "y": lugar.y, "rot": lugar.rot})
    mudou.emit()
    return true

func mover(item: Dictionary, x: int, y: int, rot: int) -> bool:
    if not cabe_em(item.especie, x, y, rot, item):
        return false
    item.x = x
    item.y = y
    item.rot = posmod(rot, 4)
    mudou.emit()
    return true

func retirar(item: Dictionary) -> void:
    for i in itens.size():
        if is_same(itens[i], item):
            itens.remove_at(i)
            break
    mudou.emit()

## Recoloca tudo, os maiores primeiro. Se não der, deixa como estava e devolve falso.
func arrumar() -> bool:
    var antes := _copia()
    var fila := itens.duplicate()
    fila.sort_custom(func(a, b): return FORMAS.get(a.especie, []).size() > FORMAS.get(b.especie, []).size())
    itens = []
    for item in fila:
        var lugar := achar_lugar(item.especie)
        if lugar.is_empty():
            itens = antes
            return false
        item.x = lugar.x
        item.y = lugar.y
        item.rot = lugar.rot
        itens.append(item)
    mudou.emit()
    return true

func _copia() -> Array:
    var saida: Array = []
    for item in itens:
        saida.append(item.duplicate())
    return saida

func esvaziar() -> void:
    itens.clear()
    mudou.emit()

func peso_total() -> float:
    var total := 0.0
    for item in itens:
        total += float(item.peso)
    return total

func casas_ocupadas() -> int:
    var n := 0
    for item in itens:
        n += FORMAS.get(item.especie, [0]).size()
    return n

func valor(item: Dictionary) -> int:
    return roundi(float(Cardumes.ESPECIES.get(item.especie, {}).get("preco", 5)) * float(item.peso))

func valor_total() -> int:
    var total := 0
    for item in itens:
        total += valor(item)
    return total

func aumentar(novas_colunas: int, novas_linhas: int) -> void:
    colunas = maxi(colunas, novas_colunas)
    linhas = maxi(linhas, novas_linhas)
    mudou.emit()
