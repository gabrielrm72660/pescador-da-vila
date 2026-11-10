extends RefCounted
## Regras da pescaria (spec 4.4, 5.1 e 5.2): quando pode pescar, o medidor de cada fisgada, cardumes,
## onde eles nascem, rede e troca de varas. Sem nós nem tela.

const Especies = preload("res://logica/especies.gd")
const Medidor = preload("res://logica/medidor.gd")
const Varas = preload("res://logica/varas.gd")
const Mapa = preload("res://logica/mapa.gd")

const DIST_PESCA := 90.0          ## px até o cardume
const FRAC_VEL := 0.3             ## fração da velocidade máxima acima da qual não dá para pescar
const TENTATIVAS := 3
const ESPERA_ERRO := 2.0          ## s depois de errar
const RECARGA_REDE := 6.0         ## s entre lances de rede
const ESTILOS_REDE := ["bola", "luzes_nuvem"]
const ORDEM_VARAS := ["rasa", "profunda", "abissal"]
const MARGEM_BORDA := 300.0
const TEXTOS := {
	"longe": "Chegue mais perto de um cardume para pescar",
	"rapido": "Reduza a velocidade para pescar",
	"vara": "Vara fraca para esta profundidade",
}


## "" se pode pescar; senão "longe", "rapido" ou "vara".
static func motivo_bloqueio(dist: float, vel: float, vel_max: float, vara: String, zona_cardume: int) -> String:
	if dist > DIST_PESCA:
		return "longe"
	if absf(vel) >= FRAC_VEL * vel_max:
		return "rapido"
	if not Varas.alcanca(vara, zona_cardume):
		return "vara"
	return ""


static func texto_bloqueio(motivo: String) -> String:
	return TEXTOS.get(motivo, "")


## Sorteia o exemplar ANTES de abrir o medidor, para o peixe grande já aparecer mais difícil.
static func preparar(esp: Dictionary, rng: RandomNumberGenerator, nivel_pescador: int) -> Dictionary:
	var u := rng.randf()
	var f := pow(u, Especies.EXPOENTE_F)
	var verde := Medidor.largura_verde(esp.raridade, f, nivel_pescador)
	return {"u": u, "f": f,
		"medidor": Medidor.new(Medidor.periodo_de(esp.raridade), verde, verde * Medidor.FRACAO_DOURADA)}


## O exemplar fisgado, ou {} se errou. A faixa dourada sorteia de novo e fica com o maior.
static func concluir(esp: Dictionary, prep: Dictionary, resultado: String, rng: RandomNumberGenerator) -> Dictionary:
	if resultado == "verde":
		return Especies.exemplar_com_f(esp, float(prep.f))
	if resultado == "dourada":
		var u := maxf(float(prep.u), rng.randf())
		return Especies.exemplar_com_f(esp, pow(u, Especies.EXPOENTE_F))
	return {}


static func novo_cardume(esp: Dictionary, pos: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	return {"especie": esp.id, "zona": int(esp.zona), "estilo": str(esp.get("estilo", "grupo")),
		"raridade": esp.raridade, "qtd": rng.randi_range(int(esp.qtd[0]), int(esp.qtd[1])),
		"tentativas": TENTATIVAS, "pos": pos}


## Um ponto na água, dentro do mapa, a uma distância entre r_min e r_max do centro; Vector2.INF se não achar.
static func ponto_de_nascimento(mundo: Dictionary, centro: Vector2, rng: RandomNumberGenerator,
		r_min: float, r_max: float, tentativas := 12) -> Vector2:
	var lim := float(mundo.get("mapa", {}).get("limite", 0.0)) - MARGEM_BORDA
	for i in tentativas:
		var p := centro + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(r_min, r_max)
		if lim > 0.0 and (absf(p.x) >= lim or absf(p.y) >= lim):
			continue
		if Mapa.zona_da_celula(mundo, p) == Mapa.TERRA:
			continue
		return p
	return Vector2.INF


static func usa_rede(tem_rede: bool, estilo: String) -> bool:
	return tem_rede and estilo in ESTILOS_REDE


## A vara equipada, se o jogador a tem; senão a melhor que ele tem ("rasa" se não tiver nenhuma).
static func vara_valida(varas: Array, equipada: String) -> String:
	if equipada in varas and Varas.VARAS.has(equipada):
		return equipada
	var melhor := Varas.melhor(varas)
	return melhor if melhor != "" else "rasa"


## A próxima vara que o jogador tem, na ordem rasa → profunda → abissal, dando a volta.
static func proxima_vara(varas: Array, equipada: String) -> String:
	var tem := ORDEM_VARAS.filter(func(v): return v in varas)
	if tem.is_empty():
		return "rasa"
	return tem[(tem.find(equipada) + 1) % tem.size()]
