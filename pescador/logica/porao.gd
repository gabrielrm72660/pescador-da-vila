extends RefCounted
## Porão por volume (spec 6): guarda peixes e cargas de missão, com capacidade em litros.

const Especies = preload("res://logica/especies.gd")
const FOLGA := 1e-6

var capacidade: float
var itens: Array[Dictionary] = []


func _init(capacidade_l := 100.0) -> void:
	capacidade = capacidade_l


func usado() -> float:
	var soma := 0.0
	for it in itens:
		soma += float(it.volume)
	return soma


func livre() -> float:
	return maxf(capacidade - usado(), 0.0)


func adicionar(item: Dictionary) -> bool:
	if float(item.get("volume", 0.0)) > livre() + FOLGA:
		return false
	itens.append(item)
	return true


func soltar(indice: int) -> Dictionary:
	if indice < 0 or indice >= itens.size():
		return {}
	var it: Dictionary = itens[indice]
	itens.remove_at(indice)
	return it


func _eh_peixe(it: Dictionary) -> bool:
	return not it.get("carga", false)


func peixes() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for it in itens:
		if _eh_peixe(it):
			lista.append(it)
	return lista


func menores(n: int) -> Array:
	var indices: Array = []
	for i in itens.size():
		if _eh_peixe(itens[i]):
			indices.append(i)
	indices.sort_custom(func(a, b): return float(itens[a].volume) < float(itens[b].volume))
	return indices.slice(0, n)


func comer(especies: Array) -> Dictionary:
	var melhor := -1
	for i in itens.size():
		var it := itens[i]
		if not _eh_peixe(it):
			continue
		var esp := Especies.por_id(especies, it.especie)
		if esp.get("raridade", "") != "comum":
			continue
		if melhor == -1 or float(it.volume) < float(itens[melhor].volume):
			melhor = i
	return soltar(melhor) if melhor != -1 else {}


func remover_carga(missao_id: String) -> bool:
	for i in itens.size():
		if itens[i].get("carga", false) and itens[i].get("missao", "") == missao_id:
			itens.remove_at(i)
			return true
	return false


func para_lista() -> Array:
	var l: Array = []
	for it in itens:
		l.append(it.duplicate())
	return l


func carregar_lista(l: Array) -> void:
	itens.clear()
	for it in l:
		if typeof(it) == TYPE_DICTIONARY and it.has("volume"):
			itens.append(it.duplicate())
