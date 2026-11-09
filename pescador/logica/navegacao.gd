extends RefCounted
## Navegação do pesqueiro (spec 10): motor com marchas, vela com vento, combustível e deriva.
## Números da vela, aceleração, giro e deriva vêm do jogo original (main.py).

const MARCHAS := [-0.2, 0.0, 0.25, 0.5, 1.0]   ## 0 = ré lenta, 1 = parado, 4 = máxima
const MARCHA_PARADO := 1
const VEL_MOTOR := [150.0, 185.0, 220.0]          ## níveis 1, 2 e 3 do motor
const VEL_VELA := 95.0
const BONUS_VELA_GRANDE := 1.3
const CONSUMO_MAX := 0.8                          ## unidades por segundo na marcha máxima
const DESCONTO_MOTORISTA := 0.07                  ## por nível da habilidade Motorista
const CORRENTE := 10.0
const DERIVA_VENTO := 6.0


static func vel_motor(nivel_motor: int) -> float:
	return VEL_MOTOR[clampi(nivel_motor, 1, VEL_MOTOR.size()) - 1]


static func vel_vela(vela_grande: bool, forca_vento: float, ang_barco: float, ang_vento: float) -> float:
	var rel := angle_difference(ang_barco, ang_vento)
	return VEL_VELA * (BONUS_VELA_GRANDE if vela_grande else 1.0) * forca_vento * maxf(0.1, cos(rel))


static func velocidade_alvo(marcha: int, nivel_motor: int, com_combustivel: bool, vela_aberta: bool,
		vela_grande: bool, forca_vento: float, ang_barco: float, ang_vento: float) -> float:
	marcha = clampi(marcha, 0, MARCHAS.size() - 1)
	var teto := vel_motor(nivel_motor)
	var motor: float = MARCHAS[marcha] * teto if com_combustivel else 0.0
	if marcha < MARCHA_PARADO:
		return motor
	var alvo := motor
	if vela_aberta:
		alvo += vel_vela(vela_grande, forca_vento, ang_barco, ang_vento)
	return minf(alvo, teto)


static func acelerar(vel: float, alvo: float, dt: float) -> float:
	return vel + (alvo - vel) * minf(1.0, 1.3 * dt)


static func consumo(marcha: int, dt: float, nivel_motorista := 0) -> float:
	var frac: float = absf(MARCHAS[clampi(marcha, 0, MARCHAS.size() - 1)])
	return CONSUMO_MAX * frac * dt * maxf(0.0, 1.0 - DESCONTO_MOTORISTA * nivel_motorista)


static func taxa_giro(leme_melhorado: bool) -> float:
	return 2.0 if leme_melhorado else 1.6


static func deriva(ang_corrente: float, ang_vento: float, forca_vento: float) -> Vector2:
	return Vector2.from_angle(ang_corrente) * CORRENTE + Vector2.from_angle(ang_vento) * DERIVA_VENTO * forca_vento


## Vento que muda de direção devagar: a cada 6–12 s sorteia um novo giro de até ±0,09 rad/s.
class Vento:
	var ang: float
	var giro := 0.0
	var tm := 5.0

	func _init(rng: RandomNumberGenerator) -> void:
		ang = rng.randf_range(0.0, TAU)

	func atualizar(dt: float, rng: RandomNumberGenerator) -> void:
		tm -= dt
		if tm <= 0.0:
			tm = rng.randf_range(6.0, 12.0)
			giro = rng.randf_range(-0.09, 0.09)
		ang += giro * dt
