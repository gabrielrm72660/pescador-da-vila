extends RefCounted
## Ciclo de dia e noite (números do jogo original: DURACAO_DIA e ALONGA_DIA de main.py).

const DURACAO_DIA := 150.0   ## segundos reais de um dia inteiro (dia + noite)
const ALONGA_DIA := 0.55     ## quanto o dia claro se alonga e a noite encurta (abaixo de 1)
const FASE_INICIAL := 0.3    ## o jogo começa no começo da manhã


## Posição do sol no ciclo: 0 = meia-noite, 0,25 = amanhecer, 0,5 = meio-dia, 0,75 = entardecer.
static func fase_do_dia(t: float) -> float:
	var u := fposmod(t, DURACAO_DIA) / DURACAO_DIA
	return u + ALONGA_DIA / TAU * sin(TAU * u)


## Inverso de fase_do_dia: em que instante do ciclo (s) o sol está em "fase".
static func tempo_da_fase(fase: float) -> float:
	var lo := 0.0
	var hi := 1.0
	for i in 40:
		var meio := (lo + hi) / 2.0
		if meio + ALONGA_DIA / TAU * sin(TAU * meio) < fase:
			lo = meio
		else:
			hi = meio
	return (lo + hi) / 2.0 * DURACAO_DIA


static func t_inicial() -> float:
	return tempo_da_fase(FASE_INICIAL)


static func brilho(t: float) -> float:
	return clampf(0.5 + 0.8 * sin(TAU * (fase_do_dia(t) - 0.25)), 0.12, 1.0)


static func noite(t: float) -> float:
	return clampf((1.0 - brilho(t)) / 0.88, 0.0, 1.0)


static func eh_noite(t: float) -> bool:
	return noite(t) > 0.35


static func dia_de(t: float) -> int:
	return int(floor(t / DURACAO_DIA)) + 1


static func hora_texto(t: float) -> String:
	var minutos := roundi(fase_do_dia(t) * 1440.0) % 1440
	return "%02d:%02d" % [minutos / 60, minutos % 60]
