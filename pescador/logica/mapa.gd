extends RefCounted
## Geografia do arquipélago (spec 9 e 7.4): zonas de água, terra, cais, zona segura do farol e bússola.
## Tudo calculado a partir de dados/mundo.json; o gerador do mapa e o jogo usam as mesmas regras.

const TERRA := -1
const RASA := 0
const PROFUNDA := 1
const ABISSAL := 2
const NOMES_ZONA := ["Rasas", "Profundas", "Abissais"]
const PX_POR_MILHA := 200.0


static func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _na_elipse(f: Dictionary, pos: Vector2) -> bool:
	var rel := (pos - _v(f.centro)).rotated(-deg_to_rad(float(f.get("rotacao", 0.0))))
	var a := float(f.eixos[0])
	var b := float(f.eixos[1])
	return (rel.x * rel.x) / (a * a) + (rel.y * rel.y) / (b * b) <= 1.0


## Zona no ponto: terra > abissal > rasa > profunda.
static func zona_em(mundo: Dictionary, pos: Vector2) -> int:
	var frac := float(mundo.get("mapa", {}).get("fracao_terra_ilhota", 0.35))
	for c in mundo.get("cidades", []):
		if pos.distance_to(_v(c.pos)) <= float(c.get("raio_ilha", 0.0)):
			return TERRA
	for i in mundo.get("ilhotas", []):
		if pos.distance_to(_v(i.centro)) <= float(i.raio) * frac:
			return TERRA
	for f in mundo.get("fossas", []):
		if _na_elipse(f, pos):
			return ABISSAL
	for r in mundo.get("rasas", []):
		if pos.distance_to(_v(r.centro)) <= float(r.raio):
			return RASA
	for i in mundo.get("ilhotas", []):
		if pos.distance_to(_v(i.centro)) <= float(i.raio):
			return RASA
	return PROFUNDA


## Zona do tile onde o ponto está (o centro da célula): é o que o mapa pinta e o que o jogador vê.
static func zona_da_celula(mundo: Dictionary, pos: Vector2) -> int:
	var cel := float(mundo.get("mapa", {}).get("celula", 128))
	return zona_em(mundo, Vector2(floorf(pos.x / cel) * cel + cel / 2.0, floorf(pos.y / cel) * cel + cel / 2.0))


## Perto da parede que fecha o mundo (a até `margem` px do limite)?
static func perto_da_borda(mundo: Dictionary, pos: Vector2, margem := 600.0) -> bool:
	var lim := float(mundo.get("mapa", {}).get("limite", 0.0))
	return lim > 0.0 and maxf(absf(pos.x), absf(pos.y)) >= lim - margem


## A cidade cujo cais está a até raio_cais do ponto, ou {}.
static func cais_proximo(mundo: Dictionary, pos: Vector2) -> Dictionary:
	for c in mundo.get("cidades", []):
		if c.has("cais") and pos.distance_to(_v(c.cais)) <= float(c.get("raio_cais", 120.0)):
			return c
	return {}


static func na_zona_segura(mundo: Dictionary, pos: Vector2) -> bool:
	var f: Dictionary = mundo.get("farol", {})
	return not f.is_empty() and pos.distance_to(_v(f.pos)) <= float(f.raio_seguro)


## As 3 cidades (na ordem do JSON) e depois os extras (alvos de missão, fase 4): [{id, nome, pos: Vector2}].
static func destinos(mundo: Dictionary, extras: Array = []) -> Array:
	var lista: Array = []
	for c in mundo.get("cidades", []):
		lista.append({"id": c.id, "nome": c.get("nome", c.id), "pos": _v(c.cais if c.has("cais") else c.pos)})
	for e in extras:
		var x: Dictionary = e.duplicate()
		if not x.pos is Vector2:
			x.pos = _v(x.pos)
		lista.append(x)
	return lista


static func proximo_destino(lista: Array, atual_id: String) -> String:
	if lista.is_empty():
		return ""
	for i in lista.size():
		if lista[i].id == atual_id:
			return lista[(i + 1) % lista.size()].id
	return lista[0].id


static func rumo(de: Vector2, para: Vector2) -> float:
	return (para - de).angle()


static func distancia_milhas(de: Vector2, para: Vector2) -> float:
	return de.distance_to(para) / PX_POR_MILHA
