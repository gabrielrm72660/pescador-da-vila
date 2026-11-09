extends RefCounted
## Missões do NPC do mercado (spec 8): encomenda, troféu, entrega e exploração.

const Especies = preload("res://logica/especies.gd")
const Mercado = preload("res://logica/mercado.gd")
const ORDEM_CLASSE := {"P": 0, "M": 1, "G": 2, "Recorde": 3}
const TIPOS := ["encomenda", "trofeu", "entrega", "exploracao"]


static func config() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://dados/missoes.json"))
	return d if typeof(d) == TYPE_DICTIONARY else {}


## Confere dados/missoes.json; devolve a lista de problemas.
static func validar_config(cfg: Dictionary) -> Array:
	var erros: Array = []
	var faixas := {"encomenda": ["qtd", "prazo_dias"], "trofeu": ["prazo_dias"], "entrega": ["volume", "prazo_dias"]}
	for tipo in TIPOS:
		if typeof(cfg.get(tipo)) != TYPE_DICTIONARY:
			erros.append("falta a seção '%s'" % tipo)
			continue
		for chave in faixas.get(tipo, []):
			var f = cfg[tipo].get(chave)
			if typeof(f) != TYPE_ARRAY or f.size() != 2 or float(f[0]) > float(f[1]) or float(f[0]) < 0:
				erros.append("%s.%s deve ser [mín, máx] com 0 ≤ mín ≤ máx" % [tipo, chave])
	for chave in ["ofertas_por_cidade", "max_ativas"]:
		if int(cfg.get(chave, 0)) < 1:
			erros.append("%s deve ser pelo menos 1" % chave)
	return erros


static func _faixa_i(r: RandomNumberGenerator, f: Array) -> int:
	return r.randi_range(int(f[0]), int(f[1]))


static func _pos_de(ponto: Dictionary) -> Array:
	return ponto.get("pos", ponto.get("centro", [0, 0]))


static func _vencida(m: Dictionary, dia: int) -> bool:
	var prazo := int(m.get("prazo_dia", -1))
	return prazo >= 0 and dia > prazo


static func gerar(dados: Dictionary, especies: Array, cidade_id: String, dia: int, zona_max: int, rng: RandomNumberGenerator) -> Array:
	var cfg := config()
	var cid := Mercado.cidade(dados, cidade_id)
	var pool: Array = []
	for e in especies:
		if int(e.zona) in cid.get("zonas_pedidos", [0]) and int(e.zona) <= zona_max + 1:
			pool.append(e)
	var comuns: Array = pool.filter(func(e): return e.raridade in ["comum", "incomum"])
	var tipos: Array = []
	for t in TIPOS:
		if t == "encomenda" and comuns.is_empty():
			continue
		if t == "trofeu" and pool.is_empty():
			continue
		tipos.append(t)
	var ofertas: Array = []
	var n := int(cfg.get("ofertas_por_cidade", 3))
	var ordem: Array = []
	while ordem.size() < n:
		var rodada := tipos.duplicate()
		for i in range(rodada.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = rodada[i]; rodada[i] = rodada[j]; rodada[j] = tmp
		ordem.append_array(rodada)
	for k in n:
		var m := {"id": "%s-%d-%d" % [cidade_id, dia, k], "tipo": ordem[k], "cidade": cidade_id, "prazo_dia": -1}
		match ordem[k]:
			"encomenda":
				var c: Dictionary = cfg.encomenda
				var esp: Dictionary = comuns[rng.randi_range(0, comuns.size() - 1)]
				m.especie = esp.id
				m.qtd = _faixa_i(rng, c.qtd)
				m.classe_min = c.classe_min[rng.randi_range(0, c.classe_min.size() - 1)]
				m.prazo_dia = dia + _faixa_i(rng, c.prazo_dias)
				m.recompensa_xp = int(c.xp)
			"trofeu":
				var c: Dictionary = cfg.trofeu
				var esp: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
				m.especie = esp.id
				m.tam_min = esp.tam_min + float(c.f_min) * (esp.tam_max - esp.tam_min)
				m.prazo_dia = dia + _faixa_i(rng, c.prazo_dias)
				m.recompensa_xp = int(c.xp)
			"entrega":
				var c: Dictionary = cfg.entrega
				var outras: Array = dados.mundo.cidades.filter(func(x): return x.id != cidade_id)
				var dest: Dictionary = outras[rng.randi_range(0, outras.size() - 1)]
				var dist := Vector2(cid.pos[0], cid.pos[1]).distance_to(Vector2(dest.pos[0], dest.pos[1]))
				m.destino = dest.id
				m.cidade = dest.id
				m.volume = roundf(rng.randf_range(float(c.volume[0]), float(c.volume[1])))
				m.recompensa = roundi(float(c.reais_por_px) * dist)
				m.prazo_dia = dia + _faixa_i(rng, c.prazo_dias)
				m.recompensa_xp = int(c.xp)
			"exploracao":
				var c: Dictionary = cfg.exploracao
				var pontos: Array = []
				for chave in ["naufragios", "fossas", "ilhotas"]:
					pontos.append_array(dados.mundo.get(chave, []))
				var alvo: Dictionary = pontos[rng.randi_range(0, pontos.size() - 1)]
				m.alvo = alvo.id
				m.nome_alvo = alvo.get("nome", alvo.id)
				m.pos = _pos_de(alvo)
				m.recompensa = int(c.recompensa)
				m.recompensa_xp = int(c.xp)
		ofertas.append(m)
	return ofertas


static func aceitar(dados: Dictionary, ativas: Array, oferta: Dictionary, porao, dia: int) -> bool:
	if ativas.size() >= int(config().get("max_ativas", 3)):
		return false
	if _vencida(oferta, dia) or ativas.any(func(m): return m.id == oferta.id):
		return false
	if oferta.get("tipo", "") == "entrega":
		if not porao.adicionar({"carga": true, "missao": oferta.id, "volume": float(oferta.volume)}):
			return false
	ativas.append(oferta)
	return true


static func _servem(m: Dictionary, porao) -> Array:
	var lista: Array = []
	for i in porao.itens.size():
		var it: Dictionary = porao.itens[i]
		if it.get("carga", false) or it.get("especie", "") != m.especie:
			continue
		if m.tipo == "encomenda" and ORDEM_CLASSE.get(it.classe, 0) < ORDEM_CLASSE.get(m.classe_min, 0):
			continue
		if m.tipo == "trofeu" and float(it.tam) < float(m.tam_min):
			continue
		lista.append(i)
	lista.sort_custom(func(a, b): return float(porao.itens[a].volume) < float(porao.itens[b].volume))
	return lista


static func progresso(m: Dictionary, porao, pos: Vector2, dia: int) -> Dictionary:
	var feito := 0
	var total := 1
	match m.get("tipo", ""):
		"encomenda":
			total = int(m.qtd)
			feito = mini(_servem(m, porao).size(), total)
		"trofeu":
			feito = 1 if not _servem(m, porao).is_empty() else 0
		"entrega":
			for it in porao.itens:
				if it.get("carga", false) and it.get("missao", "") == m.id:
					feito = 1
		"exploracao":
			var raio := float(config().exploracao.raio)
			if m.get("achado", false) or pos.distance_to(Vector2(m.pos[0], m.pos[1])) <= raio:
				m.achado = true
				feito = 1
	var vencida := _vencida(m, dia)
	return {"feito": feito, "total": total, "pronta": feito >= total and not vencida, "vencida": vencida}


static func entregar(dados: Dictionary, m: Dictionary, porao, especies: Array, cidade_id: String, dia: int, catalogo) -> Dictionary:
	var falha := func(motivo): return {"ok": false, "motivo": motivo, "reais": 0, "xp": 0}
	if _vencida(m, dia):
		return falha.call("vencida")
	if cidade_id != m.cidade:
		return falha.call("cidade_errada")
	if not progresso(m, porao, Vector2.INF, dia).pronta:
		return falha.call("incompleta")
	var cfg := config()
	var reais := 0
	match m.tipo:
		"encomenda", "trofeu":
			var usar: Array = _servem(m, porao).slice(0, int(m.qtd) if m.tipo == "encomenda" else 1)
			var soma := 0
			usar.sort()
			usar.reverse()
			var cid := Mercado.cidade(dados, m.cidade)
			for i in usar:
				var ex: Dictionary = porao.soltar(i)
				soma += Mercado.preco_venda(ex, Especies.por_id(especies, ex.especie), cid)
			reais = roundi(float(cfg[m.tipo].mult_recompensa) * soma)
			if m.tipo == "trofeu" and Especies.por_id(especies, m.especie).get("raridade", "") == "lendaria":
				catalogo.dar_titulo(m.especie)
		"entrega":
			porao.remover_carga(m.id)
			reais = int(m.recompensa)
		"exploracao":
			reais = int(m.recompensa)
	return {"ok": true, "motivo": "", "reais": reais, "xp": int(m.get("recompensa_xp", 0))}


static func vencidas(ativas: Array, dia: int) -> Array:
	return ativas.filter(func(m): return _vencida(m, dia))


## Tira das ativas as missões vencidas e a carga de entrega delas; devolve as removidas.
static func expirar(ativas: Array, porao, dia: int) -> Array:
	var removidas := vencidas(ativas, dia)
	for m in removidas:
		ativas.erase(m)
		if m.get("tipo", "") == "entrega":
			porao.remover_carga(m.id)
	return removidas
