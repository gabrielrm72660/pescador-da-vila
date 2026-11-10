extends RefCounted
## Mercado de peixe, balcão e doca seca (spec 7). Só funções estáticas sobre dados e dicionários de estado.

const Especies = preload("res://logica/especies.gd")
const Mapa = preload("res://logica/mapa.gd")
const VARAS_A_VENDA := ["vara_profunda", "vara_abissal"]
const SUPRIMENTOS := ["agua", "tabua", "corda", "isca_abissal"]


static func _ler(caminho: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if typeof(d) != TYPE_DICTIONARY:
		push_error("JSON inválido: %s" % caminho)
		return {}
	return d


static func carregar_dados() -> Dictionary:
	var d := {
		"mundo": _ler("res://dados/mundo.json"),
		"cidades": _ler("res://dados/cidades.json"),
		"loja": _ler("res://dados/loja.json"),
	}
	for erro in validar_dados(d):
		push_error("dados do mercado: " + erro)
	return d


## Confere a economia das cidades contra o mundo; devolve a lista de problemas.
static func validar_dados(d: Dictionary) -> Array:
	var erros: Array = []
	var economia := {}
	for c in d.get("cidades", {}).get("cidades", []):
		var id := str(c.get("id", "?"))
		economia[id] = true
		var mz = c.get("mult_zona", [])
		if typeof(mz) != TYPE_ARRAY or mz.size() != 3:
			erros.append("%s: mult_zona precisa de 3 valores" % id)
		var zp = c.get("zonas_pedidos", [])
		if typeof(zp) != TYPE_ARRAY or zp.is_empty() or zp.any(func(z): return int(z) < 0 or int(z) > 2):
			erros.append("%s: zonas_pedidos deve listar zonas entre 0 e 2" % id)
	var mundo: Array = d.get("mundo", {}).get("cidades", [])
	if mundo.is_empty():
		erros.append("mundo.json sem cidades")
	for m in mundo:
		if not economia.has(str(m.get("id", "?"))):
			erros.append("%s: cidade sem dados em cidades.json" % m.get("id", "?"))
		if float(m.get("raio_ilha", 0)) <= 0:
			erros.append("%s: falta raio_ilha" % m.get("id", "?"))
		var cais = m.get("cais")
		if typeof(cais) != TYPE_ARRAY or cais.size() != 2:
			erros.append("%s: falta o cais [x, y]" % m.get("id", "?"))
		elif Mapa.zona_em(d.mundo, Vector2(float(cais[0]), float(cais[1]))) == Mapa.TERRA:
			erros.append("%s: o cais está em terra" % m.get("id", "?"))
	var mp: Dictionary = d.get("mundo", {}).get("mapa", {})
	if int(mp.get("celula", 0)) < 16 or int(mp.get("limite", 0)) < 1000 or not (float(mp.get("fracao_terra_ilhota", -1)) > 0 and float(mp.get("fracao_terra_ilhota", 2)) < 1):
		erros.append("mundo.json: bloco 'mapa' ausente ou inválido (celula, limite, fracao_terra_ilhota)")
	if not mundo.any(func(m): return cidade(d, str(m.id)).get("tem_doca", false)):
		erros.append("nenhuma cidade tem doca seca")
	return erros


static func cidade(dados: Dictionary, id: String) -> Dictionary:
	var c := {}
	for m in dados.mundo.get("cidades", []):
		if m.id == id:
			c.merge(m)
	for e in dados.cidades.get("cidades", []):
		if e.id == id:
			c.merge(e)
	return c


static func preco_venda(ex: Dictionary, esp: Dictionary, cid: Dictionary) -> int:
	var mult: float = float(cid.get("mult_categoria", {}).get(esp.get("categoria", ""), 1.0))
	var zonas: Array = cid.get("mult_zona", [1.0, 1.0, 1.0])
	var z := int(esp.get("zona", 0))
	if z >= 0 and z < zonas.size():
		mult *= float(zonas[z])
	return roundi(float(ex.valor) * mult)


static func vender(porao, indices: Array, especies: Array, cid: Dictionary) -> int:
	var ordem := indices.duplicate()
	ordem.sort()
	ordem.reverse()
	var total := 0
	for i in ordem:
		if i < 0 or i >= porao.itens.size() or porao.itens[i].get("carga", false):
			continue
		var ex: Dictionary = porao.soltar(i)
		total += preco_venda(ex, Especies.por_id(especies, ex.especie), cid)
	return total


static func vender_tudo(porao, especies: Array, cid: Dictionary) -> int:
	var indices: Array = []
	for i in porao.itens.size():
		if not porao.itens[i].get("carga", false):
			indices.append(i)
	return vender(porao, indices, especies, cid)


static func item_disponivel(dados: Dictionary, item: String, cidade_id: String) -> bool:
	if not dados.loja.balcao.has(item):
		return false
	if item in dados.loja.get("itens_restritos", []):
		return item in cidade(dados, cidade_id).get("itens_extras", [])
	return true


static func comprar(dados: Dictionary, item: String, qtd: int, cidade_id: String, estado: Dictionary) -> String:
	if qtd < 1 or not item_disponivel(dados, item, cidade_id):
		return "indisponivel"
	var preco_un := int(dados.loja.balcao[item])
	var n := qtd
	if item in VARAS_A_VENDA:
		var vara := item.trim_prefix("vara_")
		if vara in estado.varas:
			return "ja_tem"
		n = 1
	elif item == "rede":
		if int(estado.melhorias.get("rede", 0)) > 0:
			return "ja_tem"
		n = 1
	elif item == "combustivel":
		n = mini(qtd, int(floor(float(estado.tanque) - float(estado.combustivel))))
		if n <= 0:
			return "ja_tem"
	elif item == "conserto_lanterna":
		if not estado.get("lanterna_quebrada", false):
			return "ja_tem"
		n = 1
	elif not item in SUPRIMENTOS:
		return "indisponivel"          # item do JSON que o jogo não sabe entregar: recusa antes de cobrar
	var custo := preco_un * n
	if int(estado.dinheiro) < custo:
		return "sem_dinheiro"
	estado.dinheiro = int(estado.dinheiro) - custo
	if item in VARAS_A_VENDA:
		estado.varas.append(item.trim_prefix("vara_"))
	elif item == "rede":
		estado.melhorias["rede"] = 1
	elif item == "combustivel":
		estado.combustivel = float(estado.combustivel) + n
	elif item == "conserto_lanterna":
		estado.lanterna_quebrada = false
	elif item in SUPRIMENTOS:
		estado.suprimentos[item] = int(estado.suprimentos.get(item, 0)) + n
	return "ok"


static func preco_melhoria(dados: Dictionary, id: String, nivel_atual: int) -> int:
	var m: Dictionary = dados.loja.melhorias.get(id, {})
	var precos: Array = m.get("precos", [])
	if nivel_atual + 1 >= precos.size():
		return -1
	return int(precos[nivel_atual + 1])


static func melhorar(dados: Dictionary, id: String, cidade_id: String, estado: Dictionary) -> String:
	if not cidade(dados, cidade_id).get("tem_doca", false):
		return "sem_doca"
	var nivel := int(estado.melhorias.get(id, 0))
	var preco := preco_melhoria(dados, id, nivel)
	if preco < 0:
		return "maximo"
	if int(estado.dinheiro) < preco:
		return "sem_dinheiro"
	estado.dinheiro = int(estado.dinheiro) - preco
	estado.melhorias[id] = nivel + 1
	return "ok"


static func preco_reparo(dados: Dictionary, dano: int) -> int:
	return maxi(dano, 0) * int(dados.loja.get("reparo_casco_por_ponto", 3))
