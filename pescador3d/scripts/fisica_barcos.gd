extends RefCounted
## Física dos barcos NPC (v0.5.5). Cada casco tem massa, velocidade para a frente (u) e de lado (v), giro com inércia, leme e
## flutuação com mola. Eles seguem a rota como antes (circuito ao largo do cais), mas agora:
##  - desviam do barco do jogador e uns dos outros (cedem passagem virando a boreste, como manda o regulamento; reduzem e param se preciso);
##  - desviam da costa e do cais (sondam à frente);
##  - batem de verdade (círculos ao longo do casco, separação e impulso com restituição); a batida empurra e gira o outro barco,
##    inclusive o do jogador (BarcoJogador.receber_batida);
##  - sobem, descem e adernam com as ondas, com um tranco extra nas batidas e inclinação nas curvas.
## Passo fixo (_physics_process); a imagem é interpolada no _process para ficar lisa em monitores de 100 Hz.

signal batida(intensidade: float, ponto: Vector3, com_jogador: bool)

const MEIO_COMPRIMENTO := 3.2
const MEIA_BOCA := 1.2
const RAIO_CIRCULO := 1.35
const DESLOCAMENTOS := [2.4, 0.0, -2.4]      # três círculos ao longo do casco (proa, meio, popa)
const GIRO_MAXIMO := 0.34                    # rad/s a toda velocidade
const ACELERACAO := 0.85
const FREADA := 1.7
const ATENCAO := 75.0                        # m: só se preocupa com quem está mais perto que isso
const TEMPO_ATENCAO := 9.0                   # s: horizonte da previsão de aproximação
const SEGURA := 14.0                         # m: distância mínima desejada na maior aproximação prevista
const RESTITUICAO := 0.28
const INERCIA := 6.0                         # m²: raio de giração ao quadrado
const MASSA_NPC := 1.0
const MASSA_JOGADOR := 1.5

class Casco:
    var no: Node3D
    var pos: Vector2 = Vector2.ZERO
    var pos_ant: Vector2 = Vector2.ZERO
    var rumo: float = 0.0                    # mesmo yaw do nó: a proa aponta para (-sen, -cos)
    var rumo_ant: float = 0.0
    var giro: float = 0.0                    # rad/s
    var u: float = 0.0                       # m/s para a frente
    var v: float = 0.0                       # m/s para boreste
    var massa: float = MASSA_NPC
    var centro: Vector2 = Vector2.ZERO       # rota: circuito em volta de centro
    var raio: float = 30.0
    var sentido: float = 1.0
    var cruzeiro: float = 3.0
    var ameaca: float = 0.0                  # 0..1: quão perto de bater (diagnóstico)
    var y: float = 0.0
    var vy: float = 0.0
    var pitch: float = 0.0
    var vpitch: float = 0.0
    var roll: float = 0.0
    var vroll: float = 0.0
    var relogio_terra: float = 0.0
    var terra_lado: float = 0.0              # -1 esquerda, +1 direita: para onde fugir da costa
    var terra_freio: float = 0.0
    var ref_pos: Vector2 = Vector2.ZERO      # onde estava 4 s atrás (para saber se está preso)
    var ref_t: float = 0.0
    var fuga_t: float = 0.0                  # tempo restante saindo de um beco (encalhado numa costa)
    var fuga_dir: Vector2 = Vector2.ZERO
    var vira_mem: float = 0.0                # desvio em curso (rad, + a boreste): dura ~2 s depois que o perigo passa
    # v0.5.12: rotina de pescador. "navegar" até um pesqueiro em água livre, "corrico" (pesca andando devagar em
    # círculos) ou "parado" (pesca parado, à deriva); depois escolhe outro pesqueiro.
    var estado: String = "navegar"
    var alvo: Vector2 = Vector2.ZERO
    var tempo_estado: float = 0.0
    var casa: Vector2 = Vector2.ZERO          # centro da ilha de onde o barco é
    var casa_raio: float = 100.0
    var sorte := RandomNumberGenerator.new()

var cascos: Array = []
var ilhas: Array = []
var oceano: Node = null
var jogador: Node3D = null
var batidas_total: int = 0
var evitar: bool = true                      # desligue só para comparar nos testes
var boias: Node = null                       # v0.5.12: Boias (scripts/boias.gd): os NPC desviam e batem nelas
const PESCA_TEMPO := [45.0, 130.0]           # s pescando em cada pesqueiro
const PESCA_LONGE := [70.0, 380.0]           # m além da costa da ilha de casa
const RAIO_CORRICO := 22.0
const VEL_CORRICO := 0.9
var _cooldown: float = 0.0

static func frente(rumo: float) -> Vector2:
    return Vector2(-sin(rumo), -cos(rumo))

static func direita(rumo: float) -> Vector2:
    return Vector2(cos(rumo), -sin(rumo))

func novo_casco(no: Node3D, centro: Vector3, raio: float, sentido: float, cruzeiro: float, ang: float) -> Casco:
    var c := Casco.new()
    c.no = no
    c.centro = Vector2(centro.x, centro.z)
    c.raio = raio
    c.sentido = sentido
    c.cruzeiro = cruzeiro
    c.pos = c.centro + Vector2(cos(ang), sin(ang)) * raio
    var tangente := Vector2(-sin(ang), cos(ang)) * sentido
    c.rumo = atan2(-tangente.x, -tangente.y)
    c.pos_ant = c.pos
    c.rumo_ant = c.rumo
    c.ref_pos = c.pos
    c.u = cruzeiro
    cascos.append(c)
    return c

## Pesqueiro novo: água livre (um círculo de 30 m sem terra), longe das boias e dos pesqueiros dos outros barcos.
func novo_destino(c: Casco) -> void:
    for tentativa in 24:
        var ang: float = c.sorte.randf() * TAU
        var dist: float = c.casa_raio + c.sorte.randf_range(PESCA_LONGE[0], PESCA_LONGE[1])
        var p: Vector2 = c.casa + Vector2(cos(ang), sin(ang)) * dist
        var ok: bool = not _bloqueado(p)
        if ok:
            for i in 10:
                var a: float = TAU * float(i) / 10.0
                if _bloqueado(p + Vector2(cos(a), sin(a)) * 30.0):
                    ok = false
                    break
        if ok and boias != null:
            for b in boias.call("lista_posicoes"):
                if (b as Vector2).distance_to(p) < 70.0:
                    ok = false
                    break
        if ok:
            for o in cascos:
                if o != c and o.alvo.distance_to(p) < 60.0:
                    ok = false
                    break
        if ok:
            c.alvo = p
            c.estado = "navegar"
            c.tempo_estado = 240.0            # se não chegar em 4 min (caminho ruim), escolhe outro
            return
    c.alvo = c.centro
    c.estado = "navegar"
    c.tempo_estado = 240.0

func _bloqueado(p: Vector2) -> bool:
    var p3 := Vector3(p.x, 0.0, p.y)
    for ilha in ilhas:
        if ilha.bloqueado(p3):
            return true
    return false

func _agua(p: Vector3) -> float:
    if oceano != null and oceano.has_method("altura_em"):
        return oceano.altura_em(p)
    return 0.0

# ------------------------------------------------------------------------------------------------------------------ passo fixo

func passo(dt: float) -> void:
    _cooldown = maxf(0.0, _cooldown - dt)
    for c in cascos:
        c.pos_ant = c.pos
        c.rumo_ant = c.rumo
    var jog = _estado_jogador()
    for c in cascos:
        _integrar(c, dt, jog)
    for i in cascos.size():
        for j in range(i + 1, cascos.size()):
            _colidir(cascos[i], cascos[j])
        if jog != null:
            _colidir_jogador(cascos[i], jog)
        if boias != null:
            _colidir_boias(cascos[i])

## Casco NPC contra a defensa das boias: os dois se afastam; a boia (presa na corrente) leva o empurrão maior.
func _colidir_boias(c: Casco) -> void:
    var lista: Array = boias.call("lista_posicoes")
    var r_boia: float = float(boias.RAIO_CONTATO)
    var f: Vector2 = frente(c.rumo)
    for i in lista.size():
        var pb: Vector2 = lista[i]
        if pb.distance_squared_to(c.pos) > 64.0:
            continue
        var melhor: float = 0.0
        var n: Vector2 = Vector2.ZERO
        var ponto: Vector2 = Vector2.ZERO
        for o in DESLOCAMENTOS:
            var cc: Vector2 = c.pos + f * float(o)
            var dv: Vector2 = cc - pb
            var dist: float = dv.length()
            var prof: float = RAIO_CIRCULO + r_boia - dist
            if prof > melhor and dist > 0.0001:
                melhor = prof
                n = dv / dist
                ponto = pb + n * r_boia
        if melhor <= 0.0:
            continue
        _empurrar(c, n * melhor * 0.35)
        var vc: Vector2 = frente(c.rumo) * c.u + direita(c.rumo) * c.v
        var vn: float = vc.dot(n)                 # < 0: indo contra a boia
        boias.call("empurrar", i, -n, melhor * 0.65, maxf(0.0, -vn))
        if vn < 0.0:
            _aplicar(c, -n * vn * (1.0 + RESTITUICAO) * 0.3, ponto)

func _estado_jogador():
    if jogador == null or not is_instance_valid(jogador):
        return null
    var vel3 := Vector3.ZERO
    if jogador.has_method("velocidade_mundo"):
        vel3 = jogador.velocidade_mundo()
    return {"pos": Vector2(jogador.global_position.x, jogador.global_position.z), "rumo": jogador.rotation.y,
            "vel": Vector2(vel3.x, vel3.z), "ativo": bool(jogador.get("ativo"))}

## Quão perigoso é "outro" para o casco c: x = ameaça (0..1), y = cosseno entre a minha proa e ele, z = lado (+ boreste, em m).
func _risco(c: Casco, f: Vector2, d: Vector2, vel: Vector2, p: Vector2, v_o: Vector2, folga: float) -> Vector3:
    var rel: Vector2 = p - c.pos
    var dist: float = rel.length()
    if dist > ATENCAO or dist < 0.01:
        return Vector3.ZERO
    var vr: Vector2 = v_o - vel
    var vr2: float = vr.length_squared()
    var t: float = 0.0
    if vr2 > 0.0004:
        t = clampf(-rel.dot(vr) / vr2, 0.0, TEMPO_ATENCAO)
    var cpa: float = (rel + vr * t).length()
    var segura: float = SEGURA + folga
    if cpa >= segura:
        return Vector3.ZERO
    var adiante: float = rel.dot(f) / dist
    var ameaca: float = (1.0 - cpa / segura) * (1.0 - 0.55 * t / TEMPO_ATENCAO)
    return Vector3(ameaca, adiante, rel.dot(d))

## Direção de água livre perto de c, preferindo a que segue o sentido da rota.
func _lado_livre(c: Casco) -> Vector2:
    var rel: Vector2 = c.pos - c.centro
    var a: float = atan2(rel.y, rel.x)
    var tang := Vector2(-sin(a), cos(a)) * c.sentido
    var melhor := tang
    var melhor_pont: float = -1e9
    for i in 16:
        var ang: float = TAU * float(i) / 16.0
        var dir := Vector2(cos(ang), sin(ang))
        var livre: float = 0.0
        for k in [6.0, 14.0, 24.0, 36.0]:
            if _bloqueado(c.pos + dir * float(k)):
                break
            livre += 1.0
        var pont: float = livre * 2.0 + dir.dot(tang)
        if pont > melhor_pont:
            melhor_pont = pont
            melhor = dir
    return melhor

func _integrar(c: Casco, dt: float, jog) -> void:
    var f: Vector2 = frente(c.rumo)
    var d: Vector2 = direita(c.rumo)
    var vel: Vector2 = f * c.u + d * c.v
    # 1) objetivo: um ponto à frente na rota (a "cenoura" anda na circunferência e o barco corre atrás dela)
    var cruzeiro: float = c.cruzeiro
    c.tempo_estado -= dt
    if c.estado == "navegar":
        c.centro = c.alvo
        var dist_alvo: float = c.pos.distance_to(c.alvo)
        if c.tempo_estado <= 0.0:
            novo_destino(c)
        elif dist_alvo < RAIO_CORRICO:
            c.estado = "corrico" if c.sorte.randf() < 0.55 else "parado"
            c.tempo_estado = c.sorte.randf_range(PESCA_TEMPO[0], PESCA_TEMPO[1])
            c.raio = RAIO_CORRICO
        cruzeiro = c.cruzeiro * clampf(dist_alvo / 45.0, 0.4, 1.0)                   # chega devagar no pesqueiro
    elif c.tempo_estado <= 0.0:
        novo_destino(c)
    if c.estado == "corrico":
        cruzeiro = VEL_CORRICO
    var rel: Vector2 = c.pos - c.centro
    var ang: float = atan2(rel.y, rel.x)
    var adiante_rota: float = c.sentido * clampf(18.0 / c.raio, 0.25, 0.75)
    var alvo: Vector2 = c.centro + Vector2(cos(ang + adiante_rota), sin(ang + adiante_rota)) * c.raio
    if c.estado == "navegar":
        alvo = c.alvo
    var desejado: Vector2 = (alvo - c.pos).normalized()
    if c.estado == "parado":
        desejado = f                                                                  # mantém a proa, à deriva
        cruzeiro = 0.0
    var vel_alvo: float = cruzeiro
    # 2) outros barcos: previsão de aproximação máxima; cede passagem virando a boreste e reduzindo
    var vira: float = 0.0                           # + vira a boreste, - a bombordo
    var freio: float = 0.0
    var fuga: float = 0.0
    var maior: float = 0.0
    var parar: bool = false
    if evitar:
        var riscos: Array = []
        for o in cascos:
            if o != c:
                var vo: Vector2 = frente(o.rumo) * o.u + direita(o.rumo) * o.v
                riscos.append([_risco(c, f, d, vel, o.pos, vo, 0.0), o.pos, vo.length() < 0.6])
        if jog != null:
            riscos.append([_risco(c, f, d, vel, jog["pos"], jog["vel"], 3.0), jog["pos"], (jog["vel"] as Vector2).length() < 0.6])
        if boias != null:                                     # boias: obstáculos parados, contornados por fora
            for pb in boias.call("lista_posicoes"):
                if (pb as Vector2).distance_squared_to(c.pos) < ATENCAO * ATENCAO:
                    riscos.append([_risco(c, f, d, vel, pb, Vector2.ZERO, -4.0), pb, true])
        for par in riscos:
            var r: Vector3 = par[0]
            if r.x <= 0.0:
                continue
            maior = maxf(maior, r.x)
            var giro_r: float = 0.0
            if r.y < -0.5:
                # vem de trás: não dá para frear; sai da frente dele pelo lado contrário e ganha um pouco de motor
                giro_r = (-1.0 if r.z > 1.0 else 1.0) * minf(1.0, r.x * 2.5) * deg_to_rad(55.0)
                fuga = maxf(fuga, r.x)
            elif par[2]:
                # obstáculo parado: contorna por fora, para o lado oposto ao que ele está
                giro_r = (-1.0 if r.z > 1.5 else 1.0) * minf(1.0, r.x * 2.5) * deg_to_rad(85.0)
                freio = maxf(freio, r.x * clampf(r.y + 0.2, 0.0, 1.0) * 0.6)
            else:
                if r.z > -3.5 or r.y > 0.75:       # a boreste, de frente ou muito perto: cede virando à direita
                    giro_r = minf(1.0, r.x * 2.5) * deg_to_rad(80.0)
                freio = maxf(freio, r.x * clampf(r.y + 0.4, 0.0, 1.0) * 0.6)
            if absf(giro_r) > absf(vira):
                vira = giro_r
            if (par[1] as Vector2).distance_to(c.pos) < 8.5 and r.y > 0.3:
                parar = true
    c.ameaca = maior
    c.vira_mem = lerpf(c.vira_mem, 0.0, 1.0 - exp(-0.5 * dt))
    if absf(vira) > absf(c.vira_mem):
        c.vira_mem = vira
    vira = c.vira_mem
    # 3) costa e cais: sonda a proa a cada 0,12 s e foge do lado bloqueado
    c.relogio_terra -= dt
    if c.relogio_terra <= 0.0:
        c.relogio_terra = 0.12
        var a: bool = _bloqueado(c.pos + f * 10.0 + d * 5.0)
        var b: bool = _bloqueado(c.pos + f * 10.0 - d * 5.0)
        var m: bool = _bloqueado(c.pos + f * 20.0)
        c.terra_lado = 0.0
        c.terra_freio = 0.0
        if a and not b:
            c.terra_lado = -1.0
        elif b and not a:
            c.terra_lado = 1.0
        elif a and b:
            c.terra_lado = 1.0 if (c.centro - c.pos).dot(d) >= 0.0 else -1.0
            c.terra_freio = 0.55
        elif m:
            c.terra_lado = 1.0 if (c.centro - c.pos).dot(d) >= 0.0 else -1.0
            c.terra_freio = 0.3
    desejado = desejado.rotated(vira + c.terra_lado * deg_to_rad(65.0))
    vel_alvo = cruzeiro * (1.0 - 0.85 * freio + 0.35 * fuga) * (1.0 - c.terra_freio)
    if c.estado == "parado" and maior > 0.2:
        vel_alvo = maxf(vel_alvo, 1.2)                     # parado no caminho de alguém: sai da frente
    # preso (menos de 4 m em 4 s, sem perigo por perto): vira para o lado livre e sai devagar
    c.ref_t += dt
    if c.ref_t >= 4.0:
        if c.fuga_t <= 0.0 and c.estado == "navegar" and c.pos.distance_to(c.ref_pos) < 4.0 and maior < 0.25:
            c.fuga_t = 6.0
            c.fuga_dir = _lado_livre(c)
        c.ref_pos = c.pos
        c.ref_t = 0.0
    if c.fuga_t > 0.0:
        c.fuga_t -= dt
        desejado = c.fuga_dir
        vel_alvo = 1.6
    if parar:
        vel_alvo = minf(vel_alvo, -0.6)
    # 4) leme e motor, com inércia (mesmos números de sensação do barco do jogador)
    var psi_d: float = atan2(-desejado.x, -desejado.y)
    var erro: float = wrapf(psi_d - c.rumo, -PI, PI)
    var fator: float = clampf(absf(c.u) / 2.0, 0.4, 1.0)
    var giro_alvo: float = clampf(erro * 1.5, -1.0, 1.0) * GIRO_MAXIMO * fator
    c.giro = lerpf(c.giro, giro_alvo, 1.0 - exp(-2.9 * dt))
    c.rumo = wrapf(c.rumo + c.giro * dt, -PI, PI)
    c.u = move_toward(c.u, vel_alvo, (ACELERACAO if vel_alvo > c.u else FREADA) * dt)
    c.v = lerpf(c.v, clampf(-c.giro * c.u * 0.37, -0.9, 0.9), 1.0 - exp(-2.0 * dt))      # a popa escorrega nas curvas
    # 5) anda; nunca para dentro da terra
    var f2: Vector2 = frente(c.rumo)
    var d2: Vector2 = direita(c.rumo)
    var mov: Vector2 = (f2 * c.u + d2 * c.v) * dt
    if oceano != null and oceano.has_method("corrente_em"):
        var cor: Vector3 = oceano.corrente_em(Vector3(c.pos.x, 0.0, c.pos.y))
        mov += Vector2(cor.x, cor.z) * dt
    var prox: Vector2 = c.pos + mov
    if _bloqueado(prox) and not _bloqueado(c.pos):
        c.u *= -0.1
        c.v = 0.0
    else:
        c.pos = prox

# ------------------------------------------------------------------------------------------------------------------ batidas

## Melhor contato entre os círculos de dois cascos: [profundidade, normal (de b para a), ponto]. Vazio se não encosta.
func _contato(pa: Vector2, ra: float, pb: Vector2, rb: float) -> Array:
    var fa: Vector2 = frente(ra)
    var fb: Vector2 = frente(rb)
    var melhor: float = 0.0
    var n: Vector2 = Vector2.ZERO
    var ponto: Vector2 = Vector2.ZERO
    var soma: float = RAIO_CIRCULO * 2.0
    for oa in DESLOCAMENTOS:
        var ca: Vector2 = pa + fa * float(oa)
        for ob in DESLOCAMENTOS:
            var cb: Vector2 = pb + fb * float(ob)
            var dv: Vector2 = ca - cb
            var dist2: float = dv.length_squared()
            if dist2 < soma * soma and dist2 > 0.000001:
                var dist: float = sqrt(dist2)
                var prof: float = soma - dist
                if prof > melhor:
                    melhor = prof
                    n = dv / dist
                    ponto = cb + n * RAIO_CIRCULO
    if melhor <= 0.0:
        return []
    return [melhor, n, ponto]

## Afasta o casco, mas nunca para dentro da terra (a batida não pode jogar um barco na praia).
func _empurrar(c: Casco, delta: Vector2) -> void:
    var novo: Vector2 = c.pos + delta
    if not _bloqueado(novo):
        c.pos = novo

func _colidir(a: Casco, b: Casco) -> void:
    if a.pos.distance_squared_to(b.pos) > 110.0:
        return
    var k: Array = _contato(a.pos, a.rumo, b.pos, b.rumo)
    if k.is_empty():
        return
    var prof: float = k[0]
    var n: Vector2 = k[1]
    var inv_a: float = 1.0 / a.massa
    var inv_b: float = 1.0 / b.massa
    var soma_inv: float = inv_a + inv_b
    _empurrar(a, n * prof * inv_a / soma_inv)
    _empurrar(b, -n * prof * inv_b / soma_inv)
    var va: Vector2 = frente(a.rumo) * a.u + direita(a.rumo) * a.v
    var vb: Vector2 = frente(b.rumo) * b.u + direita(b.rumo) * b.v
    var vn: float = (va - vb).dot(n)
    if vn >= 0.0:
        return
    var j: float = -(1.0 + RESTITUICAO) * vn / soma_inv
    _aplicar(a, n * j * inv_a, k[2])
    _aplicar(b, -n * j * inv_b, k[2])
    _avisar(-vn, k[2], false)

func _colidir_jogador(c: Casco, jog: Dictionary) -> void:
    if c.pos.distance_squared_to(jog["pos"]) > 110.0:
        return
    var k: Array = _contato(c.pos, c.rumo, jog["pos"], float(jog["rumo"]))
    if k.is_empty():
        return
    var prof: float = k[0]
    var n: Vector2 = k[1]
    var movel: bool = bool(jog["ativo"])
    var inv_c: float = 1.0 / c.massa
    var inv_j: float = (1.0 / MASSA_JOGADOR) if movel else 0.0      # barco do jogador atracado ou em pausa: parede
    var soma_inv: float = inv_c + inv_j
    _empurrar(c, n * prof * inv_c / soma_inv)
    var ponto3 := Vector3(k[2].x, 0.0, k[2].y)
    if movel and jogador.has_method("afastar"):
        jogador.afastar(Vector3(-n.x, 0.0, -n.y) * prof * inv_j / soma_inv)
    var vc: Vector2 = frente(c.rumo) * c.u + direita(c.rumo) * c.v
    var vn: float = (vc - jog["vel"]).dot(n)
    if vn >= 0.0:
        return
    var j: float = -(1.0 + RESTITUICAO) * vn / soma_inv
    _aplicar(c, n * j * inv_c, k[2])
    if movel and jogador.has_method("receber_batida"):
        var dv_j: Vector2 = -n * j * inv_j
        jogador.receber_batida(Vector3(dv_j.x, 0.0, dv_j.y), ponto3, clampf(-vn / 3.0, 0.0, 1.0))
    _avisar(-vn, k[2], true)

## Variação de velocidade dv no ponto de contato: muda u e v, gira o casco pelo braço do impulso e dá um tranco de adernamento.
func _aplicar(c: Casco, dv: Vector2, ponto: Vector2) -> void:
    var f: Vector2 = frente(c.rumo)
    var d: Vector2 = direita(c.rumo)
    c.u += dv.dot(f)
    c.v += dv.dot(d)
    var braco: Vector2 = ponto - c.pos
    c.giro = clampf(c.giro + (braco.y * dv.x - braco.x * dv.y) / INERCIA, -0.9, 0.9)    # componente Y de braço x impulso
    c.vroll += dv.dot(d) * 0.30
    c.vpitch += dv.dot(f) * 0.08

func _avisar(vn: float, ponto: Vector2, com_jogador: bool) -> void:
    if vn < 0.4 or _cooldown > 0.0:
        return
    batidas_total += 1
    _cooldown = 0.35
    batida.emit(clampf(vn / 3.0, 0.0, 1.0), Vector3(ponto.x, 0.0, ponto.y), com_jogador)

# ------------------------------------------------------------------------------------------------------------- imagem (por quadro)

## Põe o nó na posição interpolada entre dois passos fixos e o acomoda nas ondas: altura, arfagem e adernamento com mola.
## "preciso" = perto da câmera (mola completa); longe, só encaixa na onda.
func animar(c: Casco, delta: float, alfa: float, preciso: bool) -> void:
    var pos2: Vector2 = c.pos_ant.lerp(c.pos, alfa)
    var rumo: float = lerp_angle(c.rumo_ant, c.rumo, alfa)
    var f2: Vector2 = frente(rumo)
    var d2: Vector2 = direita(rumo)
    var p := Vector3(pos2.x, 0.0, pos2.y)
    var fr := Vector3(f2.x, 0.0, f2.y)
    var ld := Vector3(d2.x, 0.0, d2.y)
    var h0: float = _agua(p)
    var proa: float = _agua(p + fr * MEIO_COMPRIMENTO)
    var popa: float = _agua(p - fr * MEIO_COMPRIMENTO)
    var dir_h: float = _agua(p + ld * MEIA_BOCA)
    var esq_h: float = _agua(p - ld * MEIA_BOCA)
    var alvo_y: float = (h0 * 3.0 + proa + popa + dir_h + esq_h) / 7.0
    var fracao: float = clampf(absf(c.u) / 5.7, 0.0, 1.0)
    var alvo_pitch: float = atan2(proa - popa, MEIO_COMPRIMENTO * 2.0) + deg_to_rad(1.6) * fracao * signf(c.u)
    var alvo_roll: float = atan2(dir_h - esq_h, MEIA_BOCA * 2.0) + deg_to_rad(1.7 * minf(absf(c.u), 5.0) * c.giro / 0.38 * 0.38) + deg_to_rad(clampf(c.v * 1.8, -1.5, 1.5))
    if preciso and delta > 0.0:
        var n: int = clampi(ceili(delta / 0.03), 1, 8)
        var h: float = delta / float(n)
        for k in n:
            c.vy += (26.0 * (alvo_y - c.y) - 10.0 * c.vy) * h
            c.vy = clampf(c.vy, -5.5, 7.5)
            c.y += c.vy * h
            c.vpitch += wrapf(alvo_pitch - c.pitch, -PI, PI) * 12.0 * h
            c.vpitch *= exp(-5.4 * h)
            c.vroll += wrapf(alvo_roll - c.roll, -PI, PI) * 12.0 * h
            c.vroll *= exp(-5.4 * h)
            c.pitch = clampf(c.pitch + c.vpitch * h, deg_to_rad(-15.0), deg_to_rad(15.0))
            c.roll = clampf(c.roll + c.vroll * h, deg_to_rad(-19.0), deg_to_rad(19.0))
    else:
        c.y = alvo_y
        c.vy = 0.0
        c.pitch = alvo_pitch
        c.roll = alvo_roll
        c.vpitch = 0.0
        c.vroll = 0.0
    c.no.position = Vector3(pos2.x, c.y, pos2.y)
    c.no.rotation = Vector3(c.pitch, rumo, c.roll)
