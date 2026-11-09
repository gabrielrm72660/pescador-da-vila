extends Node
## Estado da partida (spec 12). Registrado como autoload "Estado".

signal dinheiro_mudou(valor: int)
signal porao_mudou
signal missoes_mudaram

const Porao = preload("res://logica/porao.gd")
const Catalogo = preload("res://logica/catalogo.gd")
const Mercado = preload("res://logica/mercado.gd")
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
