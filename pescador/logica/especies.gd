extends RefCounted
## Espécies: carrega dados/especies.json e sorteia espécies e exemplares (spec 4).

const EXPOENTE_F := 2.2
const LIMITES_CLASSE := [0.35, 0.70, 0.95]
const MULT_RARIDADE := {"comum": 1.0, "incomum": 1.5, "rara": 3.0, "lendaria": 10.0}
const BONUS_RECORDE := 1.5
const PESO_SORTEIO := {"comum": 60.0, "incomum": 28.0, "rara": 10.0, "lendaria": 2.0}
const REDE_QTD := [3, 6]
const REDE_F_MAX := 0.5


static func carregar(caminho := "res://dados/especies.json") -> Array[Dictionary]:
	var texto := FileAccess.get_file_as_string(caminho)
	var dados = JSON.parse_string(texto)
	var lista: Array[Dictionary] = []
	if typeof(dados) != TYPE_DICTIONARY or not dados.has("especies"):
		push_error("especies.json inválido: %s" % caminho)
		return lista
	for e in dados.especies:
		var esp: Dictionary = e.duplicate()
		esp.zona = int(esp.zona)
		esp.tam_min = float(esp.tam_min)
		esp.tam_max = float(esp.tam_max)
		esp.tam_medio = (esp.tam_min + esp.tam_max) / 2.0
		esp.qtd = [int(esp.qtd[0]), int(esp.qtd[1])]
		lista.append(esp)
	return lista


static func por_id(lista: Array, id: String) -> Dictionary:
	for e in lista:
		if e.id == id:
			return e
	return {}


static func classe_de(f: float) -> String:
	if f < LIMITES_CLASSE[0]:
		return "P"
	if f < LIMITES_CLASSE[1]:
		return "M"
	if f < LIMITES_CLASSE[2]:
		return "G"
	return "Recorde"


static func exemplar_com_f(esp: Dictionary, f: float) -> Dictionary:
	f = clampf(f, 0.0, 1.0)
	var tam: float = esp.tam_min + f * (esp.tam_max - esp.tam_min)
	var classe := classe_de(f)
	var razao: float = tam / esp.tam_medio
	var valor: float = esp.preco_base * pow(razao, 1.6) * MULT_RARIDADE.get(esp.raridade, 1.0)
	if classe == "Recorde":
		valor *= BONUS_RECORDE
	return {
		"especie": esp.id,
		"tam": tam,
		"f": f,
		"classe": classe,
		"peso": esp.k_peso * pow(tam / 100.0, 3),
		"volume": esp.vol_medio * razao * razao,
		"valor": roundi(valor),
	}


static func sortear_exemplar(esp: Dictionary, rng: RandomNumberGenerator, dourada := false) -> Dictionary:
	var u := rng.randf()
	if dourada:
		u = maxf(u, rng.randf())
	return exemplar_com_f(esp, pow(u, EXPOENTE_F))


static func sortear_rede(esp: Dictionary, rng: RandomNumberGenerator) -> Array:
	var lote: Array = []
	for i in rng.randi_range(REDE_QTD[0], REDE_QTD[1]):
		lote.append(exemplar_com_f(esp, REDE_F_MAX * pow(rng.randf(), EXPOENTE_F)))
	return lote


static func peso_de(esp: Dictionary, eh_noite: bool, clima: String) -> float:
	if esp.clima == "tempestade" and clima != "tempestade":
		return 0.0
	if esp.horario == "so_noite" and not eh_noite:
		return 0.0
	var p: float = PESO_SORTEIO.get(esp.raridade, 0.0)
	if esp.horario == "noite_mais":
		p *= 2.0 if eh_noite else 0.5
	return p


static func sortear_especie(lista: Array, zona: int, eh_noite: bool, clima: String, rng: RandomNumberGenerator) -> Dictionary:
	var candidatas: Array = []
	var pesos: Array[float] = []
	var soma := 0.0
	for e in lista:
		if e.zona != zona:
			continue
		var p := peso_de(e, eh_noite, clima)
		if p > 0.0:
			candidatas.append(e)
			pesos.append(p)
			soma += p
	if candidatas.is_empty():
		return {}
	var alvo := rng.randf() * soma
	for i in candidatas.size():
		alvo -= pesos[i]
		if alvo < 0.0:
			return candidatas[i]
	return candidatas[-1]
