extends CanvasLayer
## Painel Cinema (F11, ou o botão do painel F10): ajuste ao vivo do visual "cinematográfico" por cima da qualidade escolhida.
## Cada recurso tem liga/desliga e sliders; o painel mostra o custo de GPU em ms enquanto você mexe. Salva em user://pescador_cinema.json
## e copia a configuração para a área de transferência (para mandar para o desenvolvimento). Tudo desligado = o visual de sempre.
##
## Recursos: luz global SDFGI, SSIL, SSR, SSAO, névoa volumétrica com raios de sol, profundidade de campo, tom/cor/brilho,
## luz do dia (energia, calor dourado, hora congelada) e o filtro "pintura" (Kuwahara, vinheta, grão). SDFGI, SSIL, SSR e névoa
## volumétrica só existem no renderizador Forward+ (o do projeto).

const ARQUIVO := "user://pescador_cinema.json"
const PINTURA := preload("res://shaders/pintura_pos.gdshader")
const TONEMAPS := [Environment.TONE_MAPPER_FILMIC, Environment.TONE_MAPPER_ACES, Environment.TONE_MAPPER_AGX, Environment.TONE_MAPPER_REINHARDT]
const RECURSOS := ["sdfgi", "ssil", "ssr", "nevoa_vol", "dof", "pintura"]
const LARGURA := 430.0

## t = tipo (titulo, bool, opcao, slider) · k = chave · r = rótulo · d = padrão · min/max/p = faixa e passo · o = opções
## Os padrões reproduzem o visual atual do jogo: ligar o Cinema sem mexer em nada não muda a imagem.
const ESQUEMA := [
    {"k": "ligado", "t": "bool", "r": "CINEMA LIGADO", "d": false},
    {"t": "titulo", "r": "LUZ GLOBAL E SOMBREAMENTO (Forward+)"},
    {"k": "sdfgi", "t": "bool", "r": "Luz global SDFGI (a luz rebate nas ilhas)", "d": false},
    {"k": "sdfgi_qualidade", "t": "opcao", "r": "SDFGI qualidade", "o": ["Baixa", "Média", "Alta"], "d": 1},
    {"k": "sdfgi_celula", "t": "slider", "r": "SDFGI célula (menor = mais fino e pesado; recria ao mexer)", "min": 0.25, "max": 2.0, "p": 0.05, "d": 0.6},
    {"k": "sdfgi_cascatas", "t": "slider", "r": "SDFGI cascatas (alcance; recria ao mexer)", "min": 2, "max": 6, "p": 1, "d": 4},
    {"k": "sdfgi_energia", "t": "slider", "r": "SDFGI força", "min": 0.0, "max": 3.0, "p": 0.05, "d": 1.0},
    {"k": "ssil", "t": "bool", "r": "SSIL (luz rebatida na tela)", "d": false},
    {"k": "ssil_intensidade", "t": "slider", "r": "SSIL intensidade", "min": 0.0, "max": 4.0, "p": 0.1, "d": 1.0},
    {"k": "ssil_raio", "t": "slider", "r": "SSIL raio", "min": 1.0, "max": 12.0, "p": 0.5, "d": 5.0},
    {"k": "ssao_intensidade", "t": "slider", "r": "SSAO intensidade (sombra de contato)", "min": 0.0, "max": 4.0, "p": 0.05, "d": 1.15},
    {"k": "ssao_raio", "t": "slider", "r": "SSAO raio (0 = o da qualidade)", "min": 0.0, "max": 4.0, "p": 0.1, "d": 0.0},
    {"k": "ssr", "t": "bool", "r": "SSR (reflexos na tela)", "d": false},
    {"k": "ssr_passos", "t": "slider", "r": "SSR passos", "min": 8, "max": 128, "p": 8, "d": 48},
    {"t": "titulo", "r": "ATMOSFERA"},
    {"k": "nevoa_vol", "t": "bool", "r": "Névoa volumétrica (raios de sol)", "d": false},
    {"k": "nevoa_densidade", "t": "slider", "r": "Névoa densidade", "min": 0.0, "max": 0.15, "p": 0.0025, "d": 0.02},
    {"k": "nevoa_aniso", "t": "slider", "r": "Névoa direção da luz (raios)", "min": 0.0, "max": 0.95, "p": 0.05, "d": 0.6},
    {"k": "nevoa_alcance", "t": "slider", "r": "Névoa alcance (m)", "min": 40, "max": 400, "p": 10, "d": 150},
    {"k": "nevoa_ambiente", "t": "slider", "r": "Névoa pega luz do ambiente", "min": 0.0, "max": 1.0, "p": 0.05, "d": 0.2},
    {"k": "nevoa_ceu", "t": "slider", "r": "Névoa no céu", "min": 0.0, "max": 1.0, "p": 0.05, "d": 0.3},
    {"k": "raios_sol", "t": "slider", "r": "Força dos raios do sol", "min": 0.0, "max": 4.0, "p": 0.1, "d": 1.5},
    {"t": "titulo", "r": "CÂMERA"},
    {"k": "dof", "t": "bool", "r": "Profundidade de campo (fundo desfocado)", "d": false},
    {"k": "dof_distancia", "t": "slider", "r": "Foco até (m)", "min": 30, "max": 800, "p": 10, "d": 220},
    {"k": "dof_transicao", "t": "slider", "r": "Transição do foco (m)", "min": 20, "max": 800, "p": 10, "d": 300},
    {"k": "dof_quantidade", "t": "slider", "r": "Desfoque", "min": 0.01, "max": 0.4, "p": 0.01, "d": 0.08},
    {"t": "titulo", "r": "COR E BRILHO"},
    {"k": "tonemap", "t": "opcao", "r": "Curva de tom", "o": ["Filmic (atual)", "ACES", "AgX", "Reinhard"], "d": 0},
    {"k": "exposicao", "t": "slider", "r": "Exposição", "min": 0.5, "max": 1.8, "p": 0.05, "d": 1.0},
    {"k": "branco", "t": "slider", "r": "Ponto branco (não vale para AgX)", "min": 0.8, "max": 4.0, "p": 0.05, "d": 1.4},
    {"k": "brilho", "t": "slider", "r": "Brilho", "min": 0.7, "max": 1.3, "p": 0.01, "d": 1.0},
    {"k": "contraste", "t": "slider", "r": "Contraste", "min": 0.8, "max": 1.4, "p": 0.01, "d": 1.04},
    {"k": "saturacao", "t": "slider", "r": "Saturação", "min": 0.6, "max": 1.6, "p": 0.01, "d": 1.1},
    {"k": "glow_intensidade", "t": "slider", "r": "Brilho suave (glow)", "min": 0.0, "max": 1.5, "p": 0.02, "d": 0.26},
    {"k": "glow_bloom", "t": "slider", "r": "Glow nas partes claras", "min": 0.0, "max": 0.3, "p": 0.01, "d": 0.04},
    {"k": "glow_limiar", "t": "slider", "r": "Glow limiar (menor = mais coisas brilham)", "min": 0.4, "max": 2.0, "p": 0.05, "d": 1.1},
    {"t": "titulo", "r": "LUZ DO DIA"},
    {"k": "sol_energia", "t": "slider", "r": "Força do sol", "min": 0.3, "max": 2.0, "p": 0.05, "d": 1.0},
    {"k": "sol_calor", "t": "slider", "r": "Sol dourado (0 = natural)", "min": 0.0, "max": 1.0, "p": 0.05, "d": 0.0},
    {"k": "ambiente", "t": "slider", "r": "Luz do ambiente (sombras)", "min": 0.4, "max": 1.8, "p": 0.05, "d": 1.0},
    {"k": "congelar_hora", "t": "bool", "r": "Congelar a hora (para ajustar com calma)", "d": false},
    {"k": "hora", "t": "slider", "r": "Hora (17 a 18 = hora dourada)", "min": 5.0, "max": 20.0, "p": 0.1, "d": 17.4},
    {"t": "titulo", "r": "PINTURA E FILME"},
    {"k": "pintura", "t": "bool", "r": "Filtro pintura (pinceladas)", "d": false},
    {"k": "pintura_raio", "t": "slider", "r": "Pincelada (tamanho)", "min": 1, "max": 6, "p": 1, "d": 3},
    {"k": "pintura_mistura", "t": "slider", "r": "Pintura x imagem original", "min": 0.0, "max": 1.0, "p": 0.05, "d": 0.8},
    {"k": "vinheta", "t": "slider", "r": "Vinheta (cantos escuros)", "min": 0.0, "max": 1.0, "p": 0.05, "d": 0.0},
    {"k": "grao", "t": "slider", "r": "Grão de filme", "min": 0.0, "max": 0.1, "p": 0.005, "d": 0.0},
]

const PRESET_LEVE := {
    "ssao_intensidade": 1.5, "glow_intensidade": 0.45, "glow_bloom": 0.08, "glow_limiar": 0.9, "saturacao": 1.18, "contraste": 1.08,
    "sol_calor": 0.35, "dof": true, "dof_distancia": 260, "dof_transicao": 340, "dof_quantidade": 0.07,
    "pintura": true, "pintura_raio": 2, "pintura_mistura": 0.6, "vinheta": 0.25, "grao": 0.02,
}
const PRESET_CHEIO := {
    "ssao_intensidade": 1.5, "glow_intensidade": 0.45, "glow_bloom": 0.08, "glow_limiar": 0.9, "saturacao": 1.15, "contraste": 1.1,
    "tonemap": 2, "sol_calor": 0.5, "dof": true, "dof_distancia": 260, "dof_transicao": 340, "dof_quantidade": 0.07,
    "sdfgi": true, "ssil": true, "ssr": true, "nevoa_vol": true, "raios_sol": 1.8,
    "pintura": true, "pintura_raio": 3, "pintura_mistura": 0.7, "vinheta": 0.3, "grao": 0.02,
}
const PRESET_DOURADA := {
    "ssao_intensidade": 1.5, "glow_intensidade": 0.5, "glow_bloom": 0.1, "glow_limiar": 0.9, "saturacao": 1.15, "contraste": 1.1,
    "tonemap": 2, "sol_calor": 0.65, "sol_energia": 1.1, "dof": true, "dof_distancia": 260, "dof_transicao": 340, "dof_quantidade": 0.07,
    "sdfgi": true, "ssil": true, "ssr": true, "nevoa_vol": true, "nevoa_densidade": 0.03, "raios_sol": 2.2,
    "congelar_hora": true, "hora": 17.4,
    "pintura": true, "pintura_raio": 3, "pintura_mistura": 0.7, "vinheta": 0.3, "grao": 0.02,
}

## Propriedades do Environment que o Cinema muda: guardadas na 1ª vez e devolvidas ao desligar.
## (ssao_enabled, glow_enabled e ssao_radius ficam de fora: quem manda neles é a qualidade escolhida.)
const GUARDAR := [
    "tonemap_mode", "tonemap_exposure", "tonemap_white", "adjustment_enabled", "adjustment_brightness", "adjustment_contrast",
    "adjustment_saturation", "glow_intensity", "glow_bloom", "glow_hdr_threshold", "ssao_intensity", "ssil_enabled", "ssil_intensity",
    "ssil_radius", "ssr_enabled", "ssr_max_steps", "sdfgi_enabled", "sdfgi_cascades", "sdfgi_min_cell_size", "sdfgi_energy",
    "sdfgi_use_occlusion", "volumetric_fog_enabled", "volumetric_fog_density", "volumetric_fog_albedo", "volumetric_fog_anisotropy",
    "volumetric_fog_length", "volumetric_fog_ambient_inject", "volumetric_fog_sky_affect",
]

var p: Dictionary = {}                 # valores do jogador
var teste: Dictionary = {}             # só a bancada: {"ligado": bool, "recursos": [..] | "todos" | "painel"}
var _opcoes                            # OpcoesGraficas
var _jogo: Node
var _env_no: WorldEnvironment
var _sol: DirectionalLight3D
var _camera: Camera3D
var _orig: Dictionary = {}
var _ativo: bool = false
var _gi_ajustado: bool = false
var _attr: CameraAttributesPractical
var _attr_orig: CameraAttributes
var _attr_guardado: bool = false
var _pos_camada: CanvasLayer
var _pos_rect: ColorRect
var _pos_mat: ShaderMaterial
var _painel: PanelContainer
var _gpu_label: Label
var _estado: Label
var _ctl: Dictionary = {}
var _relogio: float = 0.0
var _padrao: Dictionary = {}
var _vida: float = 0.0
var _gi_revisado: bool = false

func _ready() -> void:
    layer = 26
    for it in ESQUEMA:
        if it.has("k"):
            _padrao[it["k"]] = it["d"]
    p = _padrao.duplicate()
    _carregar()
    _construir()

func preparar(opcoes) -> void:
    _opcoes = opcoes

## Chamado quando o jogo já tem céu, sol e câmera.
func configurar(jogo: Node, ambiente: WorldEnvironment, sol: DirectionalLight3D, camera: Camera3D) -> void:
    _jogo = jogo
    _env_no = ambiente
    _sol = sol
    _camera = camera
    _pos_mat = ShaderMaterial.new()
    _pos_mat.shader = PINTURA
    _pos_rect = ColorRect.new()
    _pos_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _pos_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _pos_rect.material = _pos_mat
    _pos_camada = CanvasLayer.new()
    _pos_camada.name = "PinturaPos"
    _pos_camada.layer = -1                  # abaixo da interface (camada 1), acima da imagem 3D
    _pos_camada.visible = false
    _pos_camada.add_child(_pos_rect)
    _jogo.add_child.call_deferred(_pos_camada)

func esta_aberto() -> bool:
    return _painel != null and _painel.visible

func alternar() -> void:
    _painel.visible = not _painel.visible
    if _opcoes != null:
        _opcoes._medir(_painel.visible or _opcoes.mostrar_fps)
    if not _painel.visible:
        _salvar()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
        alternar()
        get_viewport().set_input_as_handled()

# ---------------------------------------------------------------------------------------------------------------- aplicação

func _efetivo() -> Dictionary:
    if teste.is_empty():
        return p
    var e: Dictionary = p.duplicate()
    e["ligado"] = bool(teste.get("ligado", false))
    var rec = teste.get("recursos", "painel")
    if rec is String:
        if rec == "todos":
            for chave in RECURSOS:
                e[chave] = true
    else:
        for chave in RECURSOS:
            e[chave] = (rec as Array).has(chave)
    e["congelar_hora"] = false              # na bancada quem manda na hora é a própria bancada
    return e

func aplicar() -> void:
    if _env_no == null or _env_no.environment == null:
        return
    var e: Dictionary = _efetivo()
    if not bool(e["ligado"]):
        _desfazer()
        return
    var env: Environment = _env_no.environment
    if _orig.is_empty():
        for nome in GUARDAR:
            _orig[nome] = env.get(nome)
    _ativo = true
    var fplus: bool = _opcoes.e_forward_plus()
    # cor e brilho
    env.tonemap_mode = TONEMAPS[clampi(int(e["tonemap"]), 0, TONEMAPS.size() - 1)]
    env.tonemap_exposure = float(e["exposicao"])
    env.tonemap_white = float(e["branco"])
    env.adjustment_enabled = true
    env.adjustment_brightness = float(e["brilho"])
    env.adjustment_contrast = float(e["contraste"])
    env.adjustment_saturation = float(e["saturacao"])
    env.glow_intensity = float(e["glow_intensidade"])
    env.glow_bloom = float(e["glow_bloom"])
    env.glow_hdr_threshold = float(e["glow_limiar"])
    env.ssao_intensity = float(e["ssao_intensidade"])
    if float(e["ssao_raio"]) > 0.0:
        env.ssao_radius = float(e["ssao_raio"])
    # luz global e sombreamento na tela
    var gi: bool = bool(e["sdfgi"])
    env.sdfgi_enabled = gi
    if gi:
        env.sdfgi_cascades = int(e["sdfgi_cascatas"])
        env.sdfgi_min_cell_size = float(e["sdfgi_celula"])
        env.sdfgi_energy = float(e["sdfgi_energia"])
        env.sdfgi_use_occlusion = int(e["sdfgi_qualidade"]) >= 1
        var q: int = clampi(int(e["sdfgi_qualidade"]), 0, 2)
        RenderingServer.environment_set_sdfgi_ray_count([RenderingServer.ENV_SDFGI_RAY_COUNT_16, RenderingServer.ENV_SDFGI_RAY_COUNT_32, RenderingServer.ENV_SDFGI_RAY_COUNT_64][q])
        RenderingServer.environment_set_sdfgi_frames_to_converge([RenderingServer.ENV_SDFGI_CONVERGE_IN_30_FRAMES, RenderingServer.ENV_SDFGI_CONVERGE_IN_15_FRAMES, RenderingServer.ENV_SDFGI_CONVERGE_IN_10_FRAMES][q])
        RenderingServer.environment_set_sdfgi_frames_to_update_light([RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_8_FRAMES, RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_4_FRAMES, RenderingServer.ENV_SDFGI_UPDATE_LIGHT_IN_2_FRAMES][q])
    _ajustar_gi(gi)
    var ssil: bool = bool(e["ssil"])
    env.ssil_enabled = ssil
    if ssil:
        env.ssil_intensity = float(e["ssil_intensidade"])
        env.ssil_radius = float(e["ssil_raio"])
        if fplus:
            RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
    var ssr: bool = bool(e["ssr"])
    env.ssr_enabled = ssr
    if ssr:
        env.ssr_max_steps = int(e["ssr_passos"])
        if fplus:
            RenderingServer.environment_set_ssr_half_size(true)
    # névoa volumétrica
    var nv: bool = bool(e["nevoa_vol"])
    env.volumetric_fog_enabled = nv
    if nv:
        env.volumetric_fog_density = float(e["nevoa_densidade"])
        env.volumetric_fog_anisotropy = float(e["nevoa_aniso"])
        env.volumetric_fog_length = float(e["nevoa_alcance"])
        env.volumetric_fog_ambient_inject = float(e["nevoa_ambiente"])
        env.volumetric_fog_sky_affect = float(e["nevoa_ceu"])
        env.volumetric_fog_albedo = Color(0.92, 0.95, 1.0).lerp(Color(1.0, 0.86, 0.68), float(e["sol_calor"]))
    if _sol != null:
        _sol.light_volumetric_fog_energy = float(e["raios_sol"])
    # profundidade de campo (atributos da câmera)
    if _camera != null:
        if not _attr_guardado:
            _attr_orig = _camera.attributes
            _attr_guardado = true
        if bool(e["dof"]):
            if _attr == null:
                _attr = CameraAttributesPractical.new()
            _attr.dof_blur_far_enabled = true
            _attr.dof_blur_far_distance = float(e["dof_distancia"])
            _attr.dof_blur_far_transition = float(e["dof_transicao"])
            _attr.dof_blur_amount = float(e["dof_quantidade"])
            _camera.attributes = _attr
        else:
            _camera.attributes = _attr_orig
    # luz do dia (o clima aplica por cima de si mesmo)
    var clima = _jogo.get("clima") if _jogo != null else null
    if clima != null:
        clima.estilo_sol = float(e["sol_energia"])
        clima.estilo_calor = float(e["sol_calor"])
        clima.estilo_ambiente = float(e["ambiente"])
        clima.hora_congelada = bool(e["congelar_hora"])
        if bool(e["congelar_hora"]):
            clima.hora = float(e["hora"])
        clima.atualizar()
    # filtro pintura, vinheta e grão
    if _pos_camada != null:
        var raio: int = int(e["pintura_raio"]) if bool(e["pintura"]) else 0
        _pos_mat.set_shader_parameter("raio", raio)
        _pos_mat.set_shader_parameter("mistura", float(e["pintura_mistura"]))
        _pos_mat.set_shader_parameter("vinheta", float(e["vinheta"]))
        _pos_mat.set_shader_parameter("grao", float(e["grao"]))
        _pos_camada.visible = raio > 0 or float(e["vinheta"]) > 0.0 or float(e["grao"]) > 0.0

## Devolve tudo ao visual de sempre. Barato quando o Cinema já estava desligado.
func _desfazer() -> void:
    if not _ativo:
        return
    _ativo = false
    var env: Environment = _env_no.environment
    for nome in _orig:
        env.set(nome, _orig[nome])
    _ajustar_gi(false)
    if _sol != null:
        _sol.light_volumetric_fog_energy = 1.0
    if _camera != null and _attr_guardado:
        _camera.attributes = _attr_orig
    var clima = _jogo.get("clima") if _jogo != null else null
    if clima != null:
        clima.estilo_sol = 1.0
        clima.estilo_calor = 0.0
        clima.estilo_ambiente = 1.0
        clima.hora_congelada = false
        clima.atualizar()
    if _pos_camada != null:
        _pos_camada.visible = false

## SDFGI enxerga a geometria "estática": o mar (enorme e animado) fica de fora e o que se move (barco, bichos) vira dinâmico.
func _ajustar_gi(ligado: bool) -> void:
    if ligado == _gi_ajustado or _jogo == null:
        return
    _gi_ajustado = ligado
    var oceano = _jogo.get("oceano")
    if oceano is GeometryInstance3D:
        (oceano as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DISABLED if ligado else GeometryInstance3D.GI_MODE_STATIC
    for nome in ["barco", "cardumes", "baleias", "fauna_costeira"]:
        var raiz = _jogo.get(nome)
        if raiz is Node:
            for no in (raiz as Node).find_children("*", "GeometryInstance3D", true, false):
                (no as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC if ligado else GeometryInstance3D.GI_MODE_STATIC

func _process(delta: float) -> void:
    if not _gi_revisado:
        _vida += delta
        if _vida > 3.0:                      # bichos criados depois do começo também viram "dinâmicos" para o SDFGI
            _gi_revisado = true
            if _gi_ajustado:
                _gi_ajustado = false
                _ajustar_gi(true)
    if _pos_camada != null and _pos_camada.visible and float(p["grao"]) > 0.0:
        _pos_mat.set_shader_parameter("tempo", fmod(Time.get_ticks_msec() / 1000.0, 100.0))
    if not esta_aberto():
        return
    _relogio += delta
    if _relogio >= 0.5:
        _relogio = 0.0
        var rid: RID = get_viewport().get_viewport_rid()
        var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
        var txt: String = ("%.1f ms" % gpu) if gpu > 0.0 else "n/d"
        var teto: String = ""
        if gpu > 0.0:
            teto = "  ·  cabe em %d FPS" % int(1000.0 / (gpu * 1.12))
        _gpu_label.text = "GPU %s%s  ·  FPS %d  ·  %s" % [txt, teto, Engine.get_frames_per_second(), _opcoes.NOMES[clampi(_opcoes.qualidade, 0, 3)]]

# --------------------------------------------------------------------------------------------------------------- salvar

func _carregar() -> void:
    if not FileAccess.file_exists(ARQUIVO):
        return
    var dados = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
    if typeof(dados) != TYPE_DICTIONARY or typeof(dados.get("parametros")) != TYPE_DICTIONARY:
        return
    for chave in _padrao:
        if dados["parametros"].has(chave):
            p[chave] = _coagir(_padrao[chave], dados["parametros"][chave])

static func _coagir(modelo, valor):
    match typeof(modelo):
        TYPE_BOOL: return bool(valor)
        TYPE_INT: return int(valor)
        _: return float(valor)

func _salvar() -> void:
    var arq := FileAccess.open(ARQUIVO, FileAccess.WRITE)
    if arq != null:
        arq.store_string(JSON.stringify({"versao": 1, "parametros": p}, "  "))

func _texto_config() -> String:
    return JSON.stringify({"cinema": p, "qualidade": _opcoes.NOMES[clampi(_opcoes.qualidade, 0, 3)], "placa": RenderingServer.get_video_adapter_name(), "gpu_ms": snapped(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()), 0.1)}, "  ")

# ------------------------------------------------------------------------------------------------------------------ painel

func _estilo(cor: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = cor
    s.set_corner_radius_all(8)
    return s

func _construir() -> void:
    _painel = PanelContainer.new()
    _painel.anchor_left = 1.0
    _painel.anchor_right = 1.0
    _painel.anchor_top = 0.0
    _painel.anchor_bottom = 1.0
    _painel.offset_left = -LARGURA - 12.0
    _painel.offset_right = -12.0
    _painel.offset_top = 12.0
    _painel.offset_bottom = -12.0
    _painel.mouse_filter = Control.MOUSE_FILTER_STOP
    _painel.add_theme_stylebox_override("panel", _estilo(Color(0.035, 0.09, 0.13, 0.93)))
    _painel.visible = false
    add_child(_painel)
    var margem := MarginContainer.new()
    for lado in ["left", "right", "top", "bottom"]:
        margem.add_theme_constant_override("margin_" + lado, 10)
    _painel.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 6)
    margem.add_child(coluna)
    var titulo := Label.new()
    titulo.text = "PAINEL CINEMA  [F11]"
    titulo.add_theme_font_size_override("font_size", 20)
    coluna.add_child(titulo)
    _gpu_label = Label.new()
    _gpu_label.text = "GPU …"
    _gpu_label.add_theme_font_size_override("font_size", 14)
    _gpu_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
    coluna.add_child(_gpu_label)
    var dica := Label.new()
    dica.text = "Use com qualidade Ultra. Mexeu em algo, o Cinema liga sozinho. Os padrões reproduzem o visual atual."
    dica.add_theme_font_size_override("font_size", 12)
    dica.add_theme_color_override("font_color", Color(0.60, 0.81, 0.82))
    dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(dica)
    var presets := HBoxContainer.new()
    presets.add_theme_constant_override("separation", 4)
    coluna.add_child(presets)
    for par in [["Desligar", {}], ["Leve", PRESET_LEVE], ["Cheio", PRESET_CHEIO], ["Hora dourada", PRESET_DOURADA]]:
        var b := _botao(par[0])
        var dados: Dictionary = par[1]
        var nome: String = par[0]
        b.pressed.connect(func(): _preset(nome, dados))
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        presets.add_child(b)
    var rolagem := ScrollContainer.new()
    rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
    rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    coluna.add_child(rolagem)
    var lista := VBoxContainer.new()
    lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lista.add_theme_constant_override("separation", 3)
    rolagem.add_child(lista)
    for it in ESQUEMA:
        _linha(lista, it)
    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 4)
    coluna.add_child(acoes)
    var copiar := _botao("Copiar")
    copiar.pressed.connect(func():
        DisplayServer.clipboard_set(_texto_config())
        _dizer("Configuração copiada: cole (Ctrl+V) na conversa."))
    var salvar := _botao("Salvar")
    salvar.pressed.connect(func():
        _salvar()
        _dizer("Salvo em " + ProjectSettings.globalize_path(ARQUIVO)))
    var medir := _botao("Medir custo")
    medir.tooltip_text = "Mede em ms de GPU quanto cada recurso do Cinema soma ao Ultra, nas 4 vistas (~1,5 min)."
    medir.pressed.connect(func():
        alternar()
        _opcoes.iniciar_bancada("cinema"))
    var fechar := _botao("Fechar")
    fechar.pressed.connect(alternar)
    for b in [copiar, salvar, medir, fechar]:
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        acoes.add_child(b)
    _estado = Label.new()
    _estado.add_theme_font_size_override("font_size", 12)
    _estado.add_theme_color_override("font_color", Color(0.60, 0.81, 0.82))
    _estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    coluna.add_child(_estado)

func _botao(texto: String) -> Button:
    var b := Button.new()
    b.text = texto
    b.focus_mode = Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size", 13)
    return b

func _dizer(texto: String) -> void:
    if _estado != null:
        _estado.text = texto

static func _formatar(v: float, passo: float) -> String:
    if passo >= 1.0:
        return "%d" % roundi(v)
    if passo >= 0.1:
        return "%.1f" % v
    if passo >= 0.01:
        return "%.2f" % v
    return "%.3f" % v

func _linha(pai: Control, it: Dictionary) -> void:
    var tipo: String = it["t"]
    if tipo == "titulo":
        var t := Label.new()
        t.text = it["r"]
        t.add_theme_font_size_override("font_size", 13)
        t.add_theme_color_override("font_color", Color(0.95, 0.80, 0.45))
        pai.add_child(t)
        return
    var k: String = it["k"]
    var caixa := HBoxContainer.new()
    caixa.add_theme_constant_override("separation", 6)
    pai.add_child(caixa)
    if tipo == "bool":
        var c := CheckButton.new()
        c.text = it["r"]
        c.focus_mode = Control.FOCUS_NONE
        c.add_theme_font_size_override("font_size", 13)
        c.button_pressed = bool(p[k])
        c.toggled.connect(func(v: bool): _definir(k, v))
        c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        caixa.add_child(c)
        _ctl[k] = {"no": c, "tipo": tipo}
        return
    var rot := Label.new()
    rot.text = it["r"]
    rot.custom_minimum_size = Vector2(175, 0)
    rot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    rot.add_theme_font_size_override("font_size", 12)
    caixa.add_child(rot)
    if tipo == "opcao":
        var o := OptionButton.new()
        o.add_theme_font_size_override("font_size", 12)
        for nome in it["o"]:
            o.add_item(nome)
        o.select(int(p[k]))
        o.focus_mode = Control.FOCUS_NONE
        o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        o.item_selected.connect(func(n: int): _definir(k, n))
        caixa.add_child(o)
        _ctl[k] = {"no": o, "tipo": tipo}
        return
    var passo: float = float(it["p"])
    var s := HSlider.new()
    s.min_value = float(it["min"])
    s.max_value = float(it["max"])
    s.step = passo
    s.value = float(p[k])
    s.focus_mode = Control.FOCUS_NONE
    s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    s.custom_minimum_size = Vector2(100, 16)
    caixa.add_child(s)
    var val := Label.new()
    val.custom_minimum_size = Vector2(46, 0)
    val.add_theme_font_size_override("font_size", 12)
    val.text = _formatar(float(p[k]), passo)
    caixa.add_child(val)
    s.value_changed.connect(func(v: float):
        val.text = _formatar(v, passo)
        _definir(k, v))
    _ctl[k] = {"no": s, "tipo": tipo, "rotulo": val, "passo": passo}

## Valor mudou no painel: guarda, liga o Cinema (se for outra coisa que não o interruptor) e aplica.
func _definir(k: String, v) -> void:
    p[k] = _coagir(_padrao[k], v)
    if k == "hora" and not bool(p["congelar_hora"]):
        p["congelar_hora"] = true
        _marcar("congelar_hora", true)
    if k != "ligado" and not bool(p["ligado"]):
        p["ligado"] = true
        _marcar("ligado", true)
    if k == "ligado" or k == "ssao_raio":
        _opcoes.aplicar()                    # devolve ao valor da qualidade (SSAO) ou refaz tudo
    else:
        aplicar()

func _marcar(k: String, v: bool) -> void:
    if _ctl.has(k):
        (_ctl[k]["no"] as BaseButton).set_pressed_no_signal(v)

func _sincronizar() -> void:
    for k in _ctl:
        var c: Dictionary = _ctl[k]
        match c["tipo"]:
            "bool":
                (c["no"] as BaseButton).set_pressed_no_signal(bool(p[k]))
            "opcao":
                (c["no"] as OptionButton).select(int(p[k]))
            "slider":
                (c["no"] as HSlider).set_value_no_signal(float(p[k]))
                (c["rotulo"] as Label).text = _formatar(float(p[k]), float(c["passo"]))

func _preset(nome: String, dados: Dictionary) -> void:
    p = _padrao.duplicate()
    for k in dados:
        p[k] = _coagir(_padrao[k], dados[k])
    p["ligado"] = nome != "Desligar"
    _sincronizar()
    _opcoes.aplicar()
    _dizer("Preset \"%s\". Ajuste à vontade; Copiar manda a configuração." % nome)
