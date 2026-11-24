extends Node3D
## v0.6.0: o que anda na bruma. Duas coisas, enganosas e inofensivas:
##  - vultos: silhuetas escuras de barcos de pesca com uma luz fraca, que cruzam ao longe e se desfazem se o barco chega perto;
##  - miragens: cardumes-fantasma que aparecem no radar e somem quando o barco chega perto ("era só a bruma").
## Só existem em mar aberto com a bruma fechada. Com o clima limpo, ou perto das ilhas e do facho do farol, não aparecem.

signal vulto_nasceu                     # v0.7.0: para o aviso do Estrela d'Alva (final "bruma")
signal desfeito(tipo: String)           # "vulto" ou "miragem": o barco chegou perto e a coisa se desfez

const MAX_VULTOS := 2
const MAX_MIRAGENS := 2
const DIST_VULTO_SOME := 26.0           # m: o vulto se desfaz quando o barco chega a essa distância
const DIST_MIRAGEM_SOME := 44.0

var barco: Node3D
var clima: Node
var mundo: Node                         # scripts/jogo.gd: distancia_da_costa(pos)
var simulando: bool = false
var desligados: bool = false            # v0.7.0: depois do final "luz" a bruma não traz mais vultos nem miragens
var assombro: float = 0.0               # v0.8.7: o medo (scripts/assombro.gd). Alto: vultos também sem bruma, e eles CERCAM o barco
const TEX_VULTO := "res://assets/texturas/bruma/vulto.png"   # v0.8.7: o barco-fantasma pintado (SpriteCook)
var _tex_vulto: Texture2D = null
const PROA_DO_DESENHO := -1.0           # para que lado a proa aponta na pintura (-1 esquerda, 1 direita): o cartaz espelha

var _vultos: Array = []                 # {no, luz, dir: Vector3, vel, vida, alfa, desfazendo, fase}
var _miragens: Array = []               # {mundo: Vector2, rumo, vel, vida, alfa, fase}
var _espera_vulto: float = 9.0
var _espera_miragem: float = 6.0
var _mat_casco: StandardMaterial3D
var _tex_luz: GradientTexture2D
var _tempo: float = 0.0

func construir(barco_: Node3D, clima_: Node, mundo_: Node) -> void:
    barco = barco_
    clima = clima_
    mundo = mundo_
    name = "Fantasmas"
    _mat_casco = StandardMaterial3D.new()
    _mat_casco.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _mat_casco.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _mat_casco.disable_fog = true                          # a névoa de verdade apagaria o vulto cedo demais; ele se apaga por conta própria
    _mat_casco.albedo_color = Color(0.02, 0.04, 0.06, 0.0)
    _mat_casco.cull_mode = BaseMaterial3D.CULL_DISABLED
    _tex_luz = GradientTexture2D.new()
    var g := Gradient.new()
    g.set_color(0, Color(1.0, 0.86, 0.55, 1.0))
    g.set_color(1, Color(1.0, 0.70, 0.35, 0.0))
    _tex_luz.gradient = g
    _tex_luz.fill = GradientTexture2D.FILL_RADIAL
    _tex_luz.fill_from = Vector2(0.5, 0.5)
    _tex_luz.fill_to = Vector2(1.0, 0.5)
    _tex_luz.width = 64
    _tex_luz.height = 64

func _process(delta: float) -> void:
    if barco == null or clima == null:
        return
    _tempo += delta
    var bruma: float = float(clima.bruma)
    var mar_aberto: float = float(clima.bruma_local)
    var noite: float = float(clima.noite()) if clima.has_method("noite") else 0.0
    var pode: bool = simulando and not desligados and ((bruma > 0.6 and mar_aberto > 0.55) or (assombro >= 0.25 and noite > 0.6 and mar_aberto > 0.35))
    var max_vultos: int = MAX_VULTOS + int(assombro * 3.0)
    var max_miragens: int = MAX_MIRAGENS + int(assombro * 2.0)
    var pressa: float = 1.0 - 0.5 * assombro
    if simulando:
        _espera_vulto -= delta
        if pode and _espera_vulto <= 0.0 and _vultos.size() < max_vultos:
            _espera_vulto = randf_range(22.0, 48.0) * pressa
            _nascer_vulto()
        _espera_miragem -= delta
        if pode and _espera_miragem <= 0.0 and _miragens.size() < max_miragens:
            _espera_miragem = randf_range(16.0, 36.0) * pressa
            _nascer_miragem()
    _mover_vultos(delta, (bruma < 0.35 and assombro < 0.25) or mar_aberto < 0.25)
    _mover_miragens(delta, bruma < 0.35 or mar_aberto < 0.25)

# ---------------------------------------------------------------- vultos (3D)

func _nascer_vulto() -> void:
    var p0: Vector3 = barco.global_position
    var frente: Vector3 = -barco.global_transform.basis.z
    frente.y = 0.0
    frente = frente.normalized()
    for tentativa in 8:
        var ang: float = deg_to_rad(randf_range(35.0, 150.0)) * (1.0 if randf() < 0.5 else -1.0)
        var pos: Vector3 = p0 + frente.rotated(Vector3.UP, ang) * randf_range(80.0, 120.0)
        pos.y = 0.0
        if float(mundo.distancia_da_costa(pos)) < 70.0:
            continue
        # anda de través: quase perpendicular à linha de visada, um pouco para dentro (passa mais perto)
        var visada: Vector3 = (pos - p0).normalized()
        var lado: Vector3 = visada.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
        var dir: Vector3 = (lado * 0.90 - visada * 0.36).normalized()
        var no: Node3D = _construir_barco_fantasma()
        no.position = pos
        no.rotation.y = atan2(-dir.x, -dir.z)               # a proa (−Z) aponta para onde ele anda
        add_child(no)
        var lamp: MeshInstance3D = no.get_node("Lampada")
        _vultos.append({"no": no, "lampada": lamp, "dir": dir, "vel": randf_range(1.4, 2.4), "vida": randf_range(55.0, 85.0),
                "alfa": 0.0, "desfazendo": false, "fase": randf() * TAU, "lado": 1.0 if randf() < 0.5 else -1.0})
        vulto_nasceu.emit()
        return

## Um barco de pesca de caixotes: casco, proa, cabine, mastro e uma lâmpada fraca na popa.
func _construir_barco_fantasma() -> Node3D:
    if _tex_vulto == null and ResourceLoader.exists(TEX_VULTO):
        _tex_vulto = load(TEX_VULTO)
    if _tex_vulto != null:
        return _construir_vulto_pintado()
    var raiz := Node3D.new()
    var mat: StandardMaterial3D = _mat_casco.duplicate()
    raiz.set_meta("material", mat)
    _caixa(raiz, Vector3(3.0, 1.5, 7.4), Vector3(0.0, 0.55, 0.6), mat)           # casco
    var proa := MeshInstance3D.new()                                                # proa afilada (prisma deitado)
    var prisma := PrismMesh.new()
    prisma.size = Vector3(3.0, 1.5, 3.2)
    proa.mesh = prisma
    proa.material_override = mat
    proa.rotation_degrees = Vector3(0.0, 90.0, 0.0)
    proa.position = Vector3(0.0, 0.55, -4.0)
    raiz.add_child(proa)
    _caixa(raiz, Vector3(2.3, 2.1, 2.7), Vector3(0.0, 2.0, 2.0), mat)             # cabine na popa
    _caixa(raiz, Vector3(0.18, 6.0, 0.18), Vector3(0.0, 3.5, -0.6), mat)           # mastro
    _caixa(raiz, Vector3(0.12, 0.12, 4.0), Vector3(0.0, 5.6, 0.9), mat)            # retranca (pau de carga)
    var lampada := MeshInstance3D.new()
    lampada.name = "Lampada"
    var quad := QuadMesh.new()
    quad.size = Vector2(2.6, 2.6)
    lampada.mesh = quad
    lampada.material_override = _material_lampada()
    lampada.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lampada.position = Vector3(0.0, 2.2, 3.6)
    raiz.add_child(lampada)
    return raiz

## v0.8.7: o vulto pintado em guache: um cartaz que sempre olha para a câmera (gira só em Y), 13 m de comprimento.
func _construir_vulto_pintado() -> Node3D:
    var raiz := Node3D.new()
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = _tex_vulto
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_color = Color(1, 1, 1, 0)
    raiz.set_meta("material", mat)
    raiz.set_meta("pintado", true)
    var quadro := MeshInstance3D.new()
    var q := QuadMesh.new()
    var asp: float = float(_tex_vulto.get_height()) / float(_tex_vulto.get_width())
    q.size = Vector2(13.0, 13.0 * asp)
    q.center_offset = Vector3(0, 13.0 * asp * 0.5 - 0.6, 0)
    quadro.mesh = q
    quadro.material_override = mat
    quadro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    raiz.add_child(quadro)
    var lampada := MeshInstance3D.new()
    lampada.name = "Lampada"
    var quad := QuadMesh.new()
    quad.size = Vector2(2.6, 2.6)
    lampada.mesh = quad
    lampada.material_override = _material_lampada()
    lampada.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    lampada.position = Vector3(0.0, 2.2, 0.0)
    raiz.add_child(lampada)
    return raiz

func _material_lampada() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    m.albedo_texture = _tex_luz
    m.disable_fog = true
    m.albedo_color = Color(1, 1, 1, 0.0)
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material) -> void:
    var m := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = tam
    m.mesh = b
    m.material_override = mat
    m.position = pos
    m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pai.add_child(m)

func _mover_vultos(delta: float, forcar_sumir: bool) -> void:
    var p_barco: Vector3 = barco.global_position
    var cor_nevoa := Color(0.27, 0.35, 0.37)
    for v in _vultos.duplicate():
        var no: Node3D = v.no
        v.vida -= delta
        if assombro >= 0.45 and not v.desfazendo:
            # v0.8.7: a barca das almas: em vez de passar, o vulto vem e fica rodando o barco a ~40 m
            var para: Vector3 = no.position - p_barco
            para.y = 0.0
            var dist_b: float = maxf(para.length(), 0.1)
            var tangente: Vector3 = para.cross(Vector3.UP).normalized() * float(v.get("lado", 1.0))
            var alvo_dir: Vector3 = (tangente - para / dist_b * clampf((dist_b - 40.0) / 30.0, -1.0, 1.0)).normalized()
            v.dir = (v.dir as Vector3).lerp(alvo_dir, clampf(delta * 0.6, 0.0, 1.0)).normalized()
            v.vel = lerpf(float(v.vel), 2.6 + 2.0 * assombro, delta * 0.3)
            no.rotation.y = lerp_angle(no.rotation.y, atan2(-float(v.dir.x), -float(v.dir.z)), delta * 1.2)
            v.vida = maxf(float(v.vida), 20.0)
        no.position += (v.dir as Vector3) * float(v.vel) * delta
        no.position.y = 0.05 + 0.16 * sin(_tempo * 0.8 + float(v.fase))
        no.rotation.z = deg_to_rad(2.2) * sin(_tempo * 0.6 + float(v.fase) * 1.7)
        var d: float = Vector2(no.position.x - p_barco.x, no.position.z - p_barco.z).length()
        if d < DIST_VULTO_SOME and not v.desfazendo:
            v.desfazendo = true
            desfeito.emit("vulto")
        if float(mundo.distancia_da_costa(no.position)) < 40.0 or v.vida <= 0.0 or forcar_sumir:
            v.desfazendo = true
        var alvo: float = 0.0 if v.desfazendo else 1.0
        v.alfa = move_toward(float(v.alfa), alvo, delta / (1.6 if v.desfazendo else 5.0))
        # quanto mais longe, mais ele se mistura com a bruma; bem perto, some
        var visivel: float = (1.0 - smoothstep(40.0, 150.0, d)) * smoothstep(DIST_VULTO_SOME - 6.0, DIST_VULTO_SOME + 14.0, d)
        var cor: Color = Color(0.02, 0.04, 0.06).lerp(cor_nevoa, smoothstep(20.0, 110.0, d) * 0.85)
        var mat: StandardMaterial3D = no.get_meta("material")
        if no.has_meta("pintado"):
            var cam: Camera3D = get_viewport().get_camera_3d()
            if cam != null:                                    # a proa do desenho segue o lado para onde ele anda na tela
                var lado_tela: float = signf((v.dir as Vector3).dot(cam.global_transform.basis.x))
                var espelhar: bool = lado_tela != 0.0 and lado_tela != PROA_DO_DESENHO
                mat.uv1_scale = Vector3(-1.0 if espelhar else 1.0, 1.0, 1.0)
                mat.uv1_offset = Vector3(1.0 if espelhar else 0.0, 0.0, 0.0)
            var nevoa: float = smoothstep(20.0, 140.0, d) * 0.55
            mat.albedo_color = Color(Color(1, 1, 1).lerp(cor_nevoa * 1.6, nevoa), 0.92 * float(v.alfa) * visivel)
        else:
            mat.albedo_color = Color(cor, 0.88 * float(v.alfa) * visivel)
        var lamp: MeshInstance3D = v.lampada
        var pisca: float = 0.78 + 0.22 * sin(_tempo * 3.1 + float(v.fase))
        var lm: StandardMaterial3D = lamp.material_override
        lm.albedo_color = Color(1.0, 0.86, 0.55, 0.9 * float(v.alfa) * pisca * (1.0 - smoothstep(60.0, 230.0, d)) * smoothstep(DIST_VULTO_SOME - 8.0, DIST_VULTO_SOME + 10.0, d))
        no.visible = float(v.alfa) > 0.01
        if (float(v.alfa) <= 0.0 and v.desfazendo) or d > 330.0:
            _vultos.erase(v)
            no.queue_free()

# ---------------------------------------------------------------- miragens (radar)

func _nascer_miragem() -> void:
    var p0: Vector3 = barco.global_position
    for tentativa in 8:
        var ang: float = randf() * TAU
        var dist: float = randf_range(70.0, 135.0)
        var pos: Vector3 = p0 + Vector3(cos(ang), 0.0, sin(ang)) * dist
        if float(mundo.distancia_da_costa(pos)) < 60.0:
            continue
        _miragens.append({"mundo": Vector2(pos.x, pos.z), "rumo": randf() * TAU, "vel": randf_range(1.0, 1.9), "vida": randf_range(28.0, 55.0),
                "alfa": 0.0, "desfazendo": false, "fase": randf()})
        return

func _mover_miragens(delta: float, forcar_sumir: bool) -> void:
    var p_barco := Vector2(barco.global_position.x, barco.global_position.z)
    for m in _miragens.duplicate():
        m.vida -= delta
        m.rumo += 0.18 * sin(_tempo * 0.4 + float(m.fase) * 6.0) * delta
        m.mundo += Vector2.from_angle(float(m.rumo)) * float(m.vel) * delta
        var d: float = p_barco.distance_to(m.mundo)
        if d < DIST_MIRAGEM_SOME and not m.desfazendo:
            m.desfazendo = true
            desfeito.emit("miragem")
        if m.vida <= 0.0 or forcar_sumir:
            m.desfazendo = true
        m.alfa = move_toward(float(m.alfa), 0.0 if m.desfazendo else 1.0, delta / (0.8 if m.desfazendo else 3.0))
        if float(m.alfa) <= 0.0 and m.desfazendo:
            _miragens.erase(m)

## Para o radar (scripts/hud.gd): cardumes-fantasma, no mesmo formato dos de verdade mais "fantasma" (0..1 = quão visível).
func radar() -> Array:
    var saida: Array = []
    if barco == null:
        return saida
    var frente: Vector3 = -barco.global_transform.basis.z
    var direita: Vector3 = barco.global_transform.basis.x
    for m in _miragens:
        var d := Vector3(float(m.mundo.x) - barco.global_position.x, 0.0, float(m.mundo.y) - barco.global_position.z)
        saida.append({"pos": Vector2(d.dot(direita), d.dot(frente)), "mundo": m.mundo, "rumo": float(m.rumo), "grande": false,
                "restantes": 3, "fase": float(m.fase), "fantasma": float(m.alfa)})
    return saida

## v0.8.7: quantos vultos (visíveis, não se desfazendo) há a menos de "raio" m.
func vultos_perto(pos: Vector3, raio: float) -> int:
    var n := 0
    for v in _vultos:
        if v.desfazendo or float(v.alfa) < 0.3:
            continue
        if Vector2((v.no as Node3D).position.x - pos.x, (v.no as Node3D).position.z - pos.z).length() < raio:
            n += 1
    return n

## v0.8.7: o sino de bordo: os vultos e as miragens até "raio" m se desfazem (sem deixar página do diário).
func espantar(pos: Vector3, raio: float) -> void:
    for v in _vultos:
        if Vector2((v.no as Node3D).position.x - pos.x, (v.no as Node3D).position.z - pos.z).length() < raio:
            v.desfazendo = true
    for m in _miragens:
        if Vector2(float(m.mundo.x) - pos.x, float(m.mundo.y) - pos.z).length() < raio:
            m.desfazendo = true
    _espera_vulto = maxf(_espera_vulto, 40.0)

func limpar() -> void:
    for v in _vultos:
        (v.no as Node3D).queue_free()
    _vultos.clear()
    _miragens.clear()
    _espera_vulto = 9.0
    _espera_miragem = 6.0
