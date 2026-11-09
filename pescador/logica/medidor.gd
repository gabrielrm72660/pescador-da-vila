extends RefCounted
## Medidor de fisgada (spec 5.1): ponteiro em onda triangular e faixas verde e dourada centradas em `centro`.

const PERIODOS := {"comum": 1.6, "incomum": 1.3, "rara": 1.0, "lendaria": 0.8}
const FATOR_RARIDADE := {"comum": 1.0, "incomum": 0.85, "rara": 0.65, "lendaria": 0.45}
const VERDE_BASE := 0.30
const FRACAO_DOURADA := 0.25
const FOLGA := 1e-9

var periodo: float
var verde: float
var dourada: float
var centro: float


func _init(p_periodo: float, p_verde: float, p_dourada: float, p_centro := 0.5) -> void:
	periodo = maxf(p_periodo, 0.01)
	verde = p_verde
	dourada = p_dourada
	centro = p_centro


func posicao(t: float) -> float:
	var fase := fposmod(t, periodo) / periodo
	return 2.0 * fase if fase <= 0.5 else 2.0 * (1.0 - fase)


func resultado(t: float) -> String:
	var dist := absf(posicao(t) - centro)
	if dist <= dourada / 2.0 + FOLGA:
		return "dourada"
	if dist <= verde / 2.0 + FOLGA:
		return "verde"
	return "erro"


static func periodo_de(raridade: String) -> float:
	return PERIODOS.get(raridade, PERIODOS.comum)


static func largura_verde(raridade: String, f_previsto: float, nivel_pescador: int) -> float:
	return VERDE_BASE * FATOR_RARIDADE.get(raridade, 1.0) * (1.0 - 0.35 * f_previsto) * (1.0 + 0.08 * nivel_pescador)
