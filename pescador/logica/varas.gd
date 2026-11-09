extends RefCounted
## Varas (spec 5.2): cada vara alcança a sua zona e as mais rasas.

const VARAS := {"rasa": 0, "profunda": 1, "abissal": 2}


static func alcanca(vara: String, zona: int) -> bool:
	return VARAS.has(vara) and zona <= VARAS[vara]


static func melhor(varas: Array) -> String:
	var escolhida := ""
	for v in varas:
		if VARAS.has(v) and (escolhida == "" or VARAS[v] > VARAS[escolhida]):
			escolhida = v
	return escolhida
