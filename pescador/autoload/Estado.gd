extends Node
## Estado da partida (spec 12). Registrado como autoload "Estado".

signal dinheiro_mudou(valor: int)
signal porao_mudou
signal missoes_mudaram

const Porao = preload("res://logica/porao.gd")
const Catalogo = preload("res://logica/catalogo.gd")
const Mercado = preload("res://logica/mercado.gd")
const Missoes = preload("res://logica/missoes.gd")
const Varas = preload("res://logica/varas.gd")
const VERSAO := 1

var dinheiro: int = 0
var dia: int = 1
var cidade: String = "porto_farol"
var destino: String = "porto_farol"
var varas: Array = ["rasa"]
var vara: String = "rasa"
var melhorias: Dictionary = {}
var combustivel: float = 100.0
var casco: float = 100.0
var lanterna_quebrada: bool = false
var suprimentos: Dictionary = {}
var porao = Porao.new()
var catalogo = Catalogo.new()
var missoes: Dictionary = {"ativas": [], "ofertas": {}}
var pontos_achados: Array = []
var xp: int = 0
var habilidades: Dictionary = {}
var config: Dictionary = {}

var _loja: Dictionary = {}


func _dados_loja() -> Dictionary:
	if _loja.is_empty():
		_loja = Mercado.carregar_dados().loja
	return _loja


func _nivel_valor(id: String, padrao: float) -> float:
	var m: Dictionary = _dados_loja().get("melhorias", {}).get(id, {})
	var niveis: Array = m.get("niveis", [])
	var n := int(melhorias.get(id, 0))
	return float(niveis[clampi(n, 0, niveis.size() - 1)]) if not niveis.is_empty() else padrao


func capacidade_porao() -> float:
	return _nivel_valor("porao", 100.0)


func tanque() -> float:
	return _nivel_valor("tanque", 100.0)


func _ready() -> void:
	var s := get_node_or_null("/root/Salvamento")
	var d: Dictionary = s.carregar() if s != null else {}
	if d.is_empty():
		novo_jogo()
	else:
		de_dict(d)


func salvar() -> bool:
	var s := get_node_or_null("/root/Salvamento") if is_inside_tree() else null
	return s != null and s.salvar(para_dict())


func novo_jogo() -> void:
	dinheiro = int(_dados_loja().get("carteira_inicial", 50))
	dia = 1
	cidade = "porto_farol"
	destino = "porto_farol"
	varas = ["rasa"]
	vara = "rasa"
	melhorias = {}
	combustivel = 100.0
	casco = 100.0
	lanterna_quebrada = false
	suprimentos = {"agua": 2, "tabua": 2, "corda": 2}
	porao = Porao.new(capacidade_porao())
	catalogo = Catalogo.new()
	missoes = {"ativas": [], "ofertas": {}}
	pontos_achados = []
	xp = 0
	habilidades = {}
	config = {"efeitos": 7, "musica": 5, "tela_cheia": true}


func mudar_dinheiro(delta: int) -> void:
	dinheiro += delta
	dinheiro_mudou.emit(dinheiro)


func para_dict() -> Dictionary:
	return {
		"versao": VERSAO, "dinheiro": dinheiro, "dia": dia, "cidade": cidade, "destino": destino,
		"varas": varas.duplicate(), "vara": vara, "melhorias": melhorias.duplicate(),
		"combustivel": combustivel, "casco": casco, "lanterna_quebrada": lanterna_quebrada,
		"suprimentos": suprimentos.duplicate(), "porao": porao.para_lista(), "catalogo": catalogo.para_dict(),
		"missoes": missoes.duplicate(true), "pontos_achados": pontos_achados.duplicate(), "xp": xp,
		"habilidades": habilidades.duplicate(), "config": config.duplicate(),
	}


func de_dict(d: Dictionary) -> void:
	novo_jogo()
	dinheiro = int(d.get("dinheiro", dinheiro))
	dia = int(d.get("dia", dia))
	cidade = str(d.get("cidade", cidade))
	destino = str(d.get("destino", destino))
	if d.get("varas") is Array and not d.varas.is_empty():
		varas = d.varas.duplicate()
	vara = str(d.get("vara", vara))
	if d.get("melhorias") is Dictionary:
		melhorias = d.melhorias.duplicate()
	combustivel = float(d.get("combustivel", combustivel))
	casco = float(d.get("casco", casco))
	lanterna_quebrada = bool(d.get("lanterna_quebrada", lanterna_quebrada))
	if d.get("suprimentos") is Dictionary:
		suprimentos.merge(d.suprimentos, true)
	porao = Porao.new(capacidade_porao())
	if d.get("porao") is Array:
		porao.carregar_lista(d.porao)
	if d.get("catalogo") is Dictionary:
		catalogo.carregar_dict(d.catalogo)
	if d.get("missoes") is Dictionary:
		missoes = {"ativas": d.missoes.get("ativas", []), "ofertas": d.missoes.get("ofertas", {})}
	if d.get("pontos_achados") is Array:
		pontos_achados = d.pontos_achados.duplicate()
	xp = int(d.get("xp", xp))
	if d.get("habilidades") is Dictionary:
		habilidades = d.habilidades.duplicate()
	if d.get("config") is Dictionary:
		config.merge(d.config, true)


# ------------------------------------------------------------------ cidade: balcão, doca, venda e missões
# As regras ficam em logica/mercado.gd e logica/missoes.gd; aqui elas são aplicadas à partida.

func _conta() -> Dictionary:
	return {"dinheiro": dinheiro, "varas": varas, "melhorias": melhorias, "combustivel": combustivel,
		"tanque": tanque(), "lanterna_quebrada": lanterna_quebrada, "suprimentos": suprimentos}


func _aplicar(c: Dictionary) -> void:
	combustivel = float(c.combustivel)
	lanterna_quebrada = bool(c.lanterna_quebrada)
	if int(c.dinheiro) != dinheiro:
		mudar_dinheiro(int(c.dinheiro) - dinheiro)


func comprar(dados: Dictionary, item: String, qtd: int) -> String:
	var c := _conta()
	var r := Mercado.comprar(dados, item, qtd, cidade, c)
	if r == "ok":
		_aplicar(c)
	return r


func melhorar(dados: Dictionary, id: String) -> String:
	var c := _conta()
	var r := Mercado.melhorar(dados, id, cidade, c)
	if r == "ok":
		_aplicar(c)
		porao.capacidade = capacidade_porao()
		porao_mudou.emit()
	return r


func preco_reparo(dados: Dictionary) -> int:
	return Mercado.preco_reparo(dados, ceili(100.0 - casco))


func reparar_casco(dados: Dictionary) -> String:
	if not Mercado.cidade(dados, cidade).get("tem_doca", false):
		return "sem_doca"
	var preco := preco_reparo(dados)
	if preco <= 0:
		return "ja_tem"
	if dinheiro < preco:
		return "sem_dinheiro"
	casco = 100.0
	mudar_dinheiro(-preco)
	return "ok"


func preco_de(dados: Dictionary, especies: Array, indice: int) -> int:
	var it: Dictionary = porao.itens[indice]
	return Mercado.preco_venda(it, Mercado.Especies.por_id(especies, it.especie), Mercado.cidade(dados, cidade))


func vender(dados: Dictionary, especies: Array, indices: Array) -> int:
	var ganho := Mercado.vender(porao, indices, especies, Mercado.cidade(dados, cidade))
	if ganho != 0:
		mudar_dinheiro(ganho)
	porao_mudou.emit()
	return ganho


func vender_tudo(dados: Dictionary, especies: Array) -> int:
	var ganho := Mercado.vender_tudo(porao, especies, Mercado.cidade(dados, cidade))
	if ganho != 0:
		mudar_dinheiro(ganho)
	porao_mudou.emit()
	return ganho


## As ofertas da cidade atual: sorteadas na primeira visita do dia e trocadas quando o dia muda.
func ofertas_de(dados: Dictionary, especies: Array, rng: RandomNumberGenerator) -> Array:
	var o = missoes.ofertas.get(cidade)
	if typeof(o) != TYPE_DICTIONARY or int(o.get("dia", -1)) != dia:
		var zona_max := int(Varas.VARAS.get(Varas.melhor(varas), 0))
		var lista := Missoes.gerar(dados, especies, cidade, dia, zona_max, rng)
		for m in lista:
			if m.has("pos"):
				m.pos = m.pos.duplicate()       # não partilha a lista com o mundo.json
		o = {"dia": dia, "lista": lista.filter(func(m): return not missoes.ativas.any(func(a): return a.id == m.id))}
		missoes.ofertas[cidade] = o
	return o.lista


func aceitar_missao(dados: Dictionary, id: String) -> String:
	var lista: Array = missoes.ofertas.get(cidade, {}).get("lista", [])
	for m in lista:
		if m.id == id:
			if missoes.ativas.size() >= int(Missoes.config().get("max_ativas", 3)):
				return "limite"
			if not Missoes.aceitar(dados, missoes.ativas, m, porao, dia):
				return "sem_espaco" if m.get("tipo", "") == "entrega" else "indisponivel"
			lista.erase(m)
			missoes_mudaram.emit()
			porao_mudou.emit()
			return "ok"
	return "indisponivel"


func entregar_missao(dados: Dictionary, especies: Array, id: String) -> Dictionary:
	for m in missoes.ativas:
		if m.id == id:
			var r := Missoes.entregar(dados, m, porao, especies, cidade, dia, catalogo)
			if r.ok:
				missoes.ativas.erase(m)
				xp += int(r.xp)
				if int(r.reais) != 0:
					mudar_dinheiro(int(r.reais))
				missoes_mudaram.emit()
				porao_mudou.emit()
			return r
	return {"ok": false, "motivo": "inexistente", "reais": 0, "xp": 0}


## Tira as missões vencidas (e a carga delas); devolve as removidas.
func expirar_missoes() -> Array:
	var removidas := Missoes.expirar(missoes.ativas, porao, dia)
	if not removidas.is_empty():
		missoes_mudaram.emit()
		porao_mudou.emit()
	return removidas


## Chamado no mar: devolve as explorações cujo ponto acabou de ser achado.
func marcar_exploracao(pos: Vector2) -> Array:
	var novas: Array = []
	for m in missoes.ativas:
		if m.get("tipo", "") == "exploracao" and not m.get("achado", false):
			if Missoes.progresso(m, porao, pos, dia).feito > 0:
				novas.append(m)
				if not m.get("alvo", "") in pontos_achados:
					pontos_achados.append(m.get("alvo", ""))
	if not novas.is_empty():
		missoes_mudaram.emit()
	return novas
