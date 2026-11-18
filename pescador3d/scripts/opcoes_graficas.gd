extends CanvasLayer
## Configurações leves, sem dependências externas. F10 abre; F3 mostra FPS.

signal tela_mudou
signal qualidade_ajustada(texto: String)
const ARQUIVO := "user://pescador_graficos.json"
const Bancada = preload("res://scripts/bancada_gpu.gd")
const Cinema = preload("res://scripts/cinema.gd")
static var modo_editor: bool = false     # Modo Construtor aberto: nada de vegetação desbastada (quem edita precisa ver tudo)
const NOMES := ["Baixa", "Média", "Alta", "Ultra"]
const QUALIDADE_MAX := 3
const LIMITES := [30, 60, 120, 0]
var qualidade: int = 1
var automatica: bool = true      # abaixa a qualidade sozinha se o jogo ficar lento (nunca sobe sozinha)
var fps_indice: int = 1
var mostrar_fps: bool = false
var vsync: bool = true           # trava o FPS na taxa do monitor; desligue (com "Sem limite") para medir a capacidade real
var _vsync_opcao: CheckButton
## Ajustes avulsos aplicados POR CIMA do nível de qualidade; só a bancada de GPU usa (mede o custo de cada recurso).
## Chaves: msaa (0 = desligado, 1 = 2x, 2 = 4x, 3 = 8x), sem_ssao, sem_glow, sem_sombra, faixas (1, 2 ou 4), atlas (tamanho),
## filtro_duro, detalhe (0 a 2, vegetação), mar (0 a 3).
var sobrepor: Dictionary = {}
var _bancada: Node
var cinema: Node                  # painel Cinema (F11): visual cinematográfico por cima da qualidade
var _soma_quadro: float = 0.0
var _n_quadros: int = 0
var _painel: Control
var _fps_label: Label
var _qualidade_opcao: OptionButton
var _qualidade_dica: Label
var _fps_opcao: OptionButton
var _contador: float = 0.0
var _ilhas: Array = []
var _sol: DirectionalLight3D
var _oceano: MeshInstance3D
var _ambiente: WorldEnvironment
var _camera: Camera3D
var _original_particulas: Dictionary = {}
var _auto_opcao: CheckButton
var _auto_tempo: float = 0.0     # janela de medicao atual
var _auto_quadros: int = 0
var _auto_lentas: int = 0        # janelas seguidas abaixo da meta
var _auto_espera: float = 8.0    # carência: ignora o inicio, a abertura de telas e logo apos cada ajuste

func _ready() -> void:
    layer = 25
    _carregar()
    if not FileAccess.file_exists(ARQUIVO):
        # Primeira vez: sem GPU de verdade (renderizador por software), comeca na Baixa.
        var placa: String = RenderingServer.get_video_adapter_name().to_lower()
        for nome in ["llvmpipe", "swiftshader", "software", "basic render", "softpipe"]:
            if placa.contains(nome):
                qualidade = 0
                break
    # Variaveis de teste (sondas automaticas): PESCADOR_SEM_AUTO=1 desliga o ajuste; PESCADOR_QUALIDADE=0..2 fixa o nivel.
    if OS.get_environment("PESCADOR_SEM_AUTO") == "1":
        automatica = false
    if OS.get_environment("PESCADOR_QUALIDADE") != "":
        qualidade = clampi(int(OS.get_environment("PESCADOR_QUALIDADE")), 0, QUALIDADE_MAX)
    _construir()
    cinema = Cinema.new()
    cinema.name = "Cinema"
    add_child(cinema)
    cinema.preparar(self)
    _medir(mostrar_fps)

func configurar(ilhas: Array, sol: DirectionalLight3D, oceano: MeshInstance3D, ambiente: WorldEnvironment) -> void:
    _ilhas = ilhas.duplicate()
    _sol = sol
    _oceano = oceano
    _ambiente = ambiente
    _camera = get_node_or_null("../Camera") as Camera3D
    cinema.configurar(get_parent(), ambiente, sol, _camera)
    aplicar()

func esta_aberto() -> bool:
    return _painel != null and _painel.visible

func alternar() -> void:
    _painel.visible = not _painel.visible
    tela_mudou.emit()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_F10:
            if _bancada == null:
                alternar()
            get_viewport().set_input_as_handled()
        elif event.physical_keycode == KEY_F3:
            alternar_fps()
            get_viewport().set_input_as_handled()
        elif event.physical_keycode == KEY_F2:
            iniciar_bancada()
            get_viewport().set_input_as_handled()

func alternar_fps() -> void:
    mostrar_fps = not mostrar_fps
    _fps_label.visible = mostrar_fps
    _medir(mostrar_fps)
    _salvar()

## Bancada de GPU (F2 ou botão do painel): mede quanto cada recurso gráfico custa em ms de GPU. Leva ~2 min; Esc cancela.
func iniciar_bancada(modo: String = "recursos") -> void:
    if _bancada != null:
        return
    _bancada = Bancada.new()
    _bancada.name = "Bancada"
    add_child(_bancada)
    _bancada.terminou.connect(func(): _bancada = null)
    _bancada.iniciar(self, modo)

## Liga/desliga a medição de tempo de GPU e CPU do quadro (só com o overlay F3 aberto, porque custa um pouco).
func _medir(ligado: bool) -> void:
    _soma_quadro = 0.0
    _n_quadros = 0
    RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), ligado)

func _estilo(cor: Color) -> StyleBoxFlat:
    var st := StyleBoxFlat.new()
    st.bg_color = cor
    st.corner_radius_top_left = 12
    st.corner_radius_top_right = 12
    st.corner_radius_bottom_left = 12
    st.corner_radius_bottom_right = 12
    st.content_margin_left = 16.0
    st.content_margin_right = 16.0
    st.content_margin_top = 12.0
    st.content_margin_bottom = 12.0
    return st

func _construir() -> void:
    _fps_label = Label.new()
    _fps_label.text = "FPS"
    _fps_label.add_theme_font_size_override("font_size", 15)
    _fps_label.add_theme_color_override("font_color", Color(0.93, 0.93, 0.83))
    _fps_label.position = Vector2(20, 188)
    _fps_label.visible = mostrar_fps
    add_child(_fps_label)
    _painel = ColorRect.new()
    _painel.color = Color(0.01, 0.04, 0.06, 0.82)
    _painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _painel.mouse_filter = Control.MOUSE_FILTER_STOP
    _painel.visible = false
    add_child(_painel)
    var central := CenterContainer.new()
    central.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _painel.add_child(central)
    var cartao := PanelContainer.new()
    cartao.custom_minimum_size = Vector2(500, 420)
    cartao.add_theme_stylebox_override("panel", _estilo(Color(0.055, 0.13, 0.17, 0.98)))
    central.add_child(cartao)
    var margem := MarginContainer.new()
    for lado in ["left", "right", "top", "bottom"]:
        margem.add_theme_constant_override("margin_" + lado, 20)
    cartao.add_child(margem)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 12)
    margem.add_child(coluna)
    var titulo := Label.new()
    titulo.text = "GRÁFICOS E DESEMPENHO"
    titulo.add_theme_font_size_override("font_size", 23)
    coluna.add_child(titulo)
    var dica := Label.new()
    dica.text = "F10 fecha esta tela · F3 alterna FPS"
    dica.add_theme_color_override("font_color", Color(0.60, 0.81, 0.82))
    coluna.add_child(dica)
    var rotulo := Label.new()
    rotulo.text = "Qualidade (sombras, água, vegetação e partículas)"
    coluna.add_child(rotulo)
    _qualidade_opcao = OptionButton.new()
    for nome in NOMES:
        _qualidade_opcao.add_item(nome)
    _qualidade_opcao.select(qualidade)
    _qualidade_opcao.item_selected.connect(func(n: int):
        qualidade = n
        _atualizar_dica()
        automatica = false          # quem escolhe a qualidade assume o controle
        if _auto_opcao != null:
            _auto_opcao.set_pressed_no_signal(false)
        aplicar()
        _salvar())
    coluna.add_child(_qualidade_opcao)
    _qualidade_dica = Label.new()
    _qualidade_dica.add_theme_font_size_override("font_size", 13)
    _qualidade_dica.add_theme_color_override("font_color", Color(0.60, 0.81, 0.82))
    _qualidade_dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _qualidade_dica.custom_minimum_size = Vector2(460, 0)
    coluna.add_child(_qualidade_dica)
    _atualizar_dica()
    _auto_opcao = CheckButton.new()
    _auto_opcao.text = "Ajuste automático (abaixa a qualidade se travar)"
    _auto_opcao.button_pressed = automatica
    _auto_opcao.toggled.connect(func(ligado: bool):
        automatica = ligado
        _auto_lentas = 0
        _salvar())
    coluna.add_child(_auto_opcao)
    var frotulo := Label.new()
    frotulo.text = "Limite de quadros por segundo"
    coluna.add_child(frotulo)
    _fps_opcao = OptionButton.new()
    for nome in ["30 FPS", "60 FPS", "120 FPS", "Sem limite"]:
        _fps_opcao.add_item(nome)
    _fps_opcao.select(fps_indice)
    _fps_opcao.item_selected.connect(func(n: int):
        fps_indice = n
        aplicar()
        _salvar())
    coluna.add_child(_fps_opcao)
    _vsync_opcao = CheckButton.new()
    _vsync_opcao.text = "V-Sync (trava o FPS na taxa do monitor)"
    _vsync_opcao.button_pressed = vsync
    _vsync_opcao.toggled.connect(func(ligado: bool):
        vsync = ligado
        aplicar()
        _salvar())
    coluna.add_child(_vsync_opcao)
    var cinema_botao := Button.new()
    cinema_botao.text = "PAINEL CINEMA (luz, névoa, reflexos, pintura) [F11]"
    cinema_botao.pressed.connect(func():
        alternar()
        cinema.alternar())
    coluna.add_child(cinema_botao)
    var teste := Button.new()
    teste.text = "TESTE DE DESEMPENHO DA GPU (≈2 min) [F2]"
    teste.tooltip_text = "Mede em ms quanto cada recurso gráfico custa na sua placa. Esc cancela; ao fim mostra uma tabela."
    teste.pressed.connect(iniciar_bancada)
    coluna.add_child(teste)
    var fechar := Button.new()
    fechar.text = "VOLTAR AO JOGO [F10]"
    fechar.pressed.connect(alternar)
    coluna.add_child(fechar)

## Nome do renderizador em uso ("forward_plus", "mobile" ou "gl_compatibility").
static func metodo_render() -> String:
    if RenderingServer.has_method("get_current_rendering_method"):
        return String(RenderingServer.call("get_current_rendering_method"))
    return String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))

static func e_forward_plus() -> bool:
    return metodo_render() == "forward_plus"

## Usados pela tela "Opções > Gráficos" do menu: mudam o mesmo estado que o painel F10 e o mantêm em dia.
func definir_qualidade(n: int) -> void:
    qualidade = clampi(n, 0, QUALIDADE_MAX)
    _qualidade_opcao.select(qualidade)
    _atualizar_dica()
    automatica = false
    _auto_opcao.set_pressed_no_signal(false)
    aplicar()
    _salvar()

func definir_automatica(ligado: bool) -> void:
    automatica = ligado
    _auto_lentas = 0
    _auto_opcao.set_pressed_no_signal(ligado)
    _salvar()

func definir_limite_fps(n: int) -> void:
    fps_indice = clampi(n, 0, LIMITES.size() - 1)
    _fps_opcao.select(fps_indice)
    aplicar()
    _salvar()

func definir_vsync(ligado: bool) -> void:
    vsync = ligado
    _vsync_opcao.set_pressed_no_signal(ligado)
    aplicar()
    _salvar()

func abrir_avancado() -> void:
    if not cinema.esta_aberto():
        cinema.alternar()

func texto_dica() -> String:
    return _qualidade_dica.text if _qualidade_dica != null else ""

func _atualizar_dica() -> void:
    if _qualidade_dica == null:
        return
    _qualidade_dica.text = [
        "Baixa: sem sombras, vegetação reduzida. Para PCs fracos.",
        "Média: sombras simples, vegetação reduzida.",
        "Alta: sombras, vegetação detalhada e árvores que balançam com o vento.",
        "Ultra: tudo da Alta + sombras suaves em alta resolução, mar mais fino, árvores e pedras com mais detalhe, filtro de textura máximo e alcance maior. Pede placa de vídeo boa; extras de iluminação só no renderizador Forward+.",
    ][clampi(qualidade, 0, QUALIDADE_MAX)]

func aplicar() -> void:
    Engine.max_fps = LIMITES[clampi(fps_indice, 0, LIMITES.size() - 1)]
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
    var q: int = clampi(qualidade, 0, QUALIDADE_MAX)
    var ultra: bool = q >= 3
    var qb: int = mini(q, 2)                       # tabelas de três posições (Baixa, Média, Alta) usam a Alta no Ultra
    var fplus: bool = e_forward_plus()
    var vp: Viewport = get_viewport()
    var suavizacao: Viewport.MSAA = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][qb]
    if ultra and fplus:
        suavizacao = Viewport.MSAA_8X              # 8x só onde o renderizador aguenta (Forward+)
    vp.msaa_3d = suavizacao
    # Filtro de textura em ângulo raso (areia, mar, chão): a Alta sobe para 8x e o Ultra para 16x; as demais seguem o padrão do projeto.
    var aniso_projeto: int = int(ProjectSettings.get_setting("rendering/textures/default_filters/anisotropic_filtering_level", 2))
    vp.anisotropic_filtering_level = [aniso_projeto, aniso_projeto, maxi(aniso_projeto, 3), 4][q]
    # Sombras do sol: o Ultra usa o atlas maior, filtro suave de alta qualidade e alcance maior.
    RenderingServer.directional_shadow_atlas_set_size(8192 if ultra else 4096, true)
    RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if ultra else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
    RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH if ultra else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
    if _sol != null:
        _sol.shadow_enabled = q > 0
        # Cada faixa de sombra redesenha a ilha de novo: Alta e Ultra usam 4 faixas, Média só 2 (metade do custo de sombra).
        _sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if qb == 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
        _sol.directional_shadow_max_distance = 190.0 if ultra else 120.0
        _sol.shadow_blur = 1.0 if ultra else 1.6
    if _camera != null:
        _camera.far = [850.0, 1350.0, 1900.0, 2600.0][q]
    if _ambiente != null and _ambiente.environment != null:
        _ambiente.environment.ssao_enabled = q > 0
        _ambiente.environment.glow_enabled = q > 0
        if fplus:
            # Só o Forward+ tem estes recursos: sombreamento de contato mais fino (SSAO em qualidade alta) no Ultra.
            RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_HIGH if ultra else RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
            _ambiente.environment.ssao_radius = 2.0 if ultra else 1.0
    if _oceano != null and _oceano.has_method("definir_qualidade"):
        _oceano.definir_qualidade(q)
    var nivel_detalhe: int = [0, 0, 1, 2][q]       # malhas de vegetação: leves, detalhadas (Alta, com vento) ou ultra
    for ilha in _ilhas:
        if ilha.has_method("definir_detalhe"):
            ilha.definir_detalhe(nivel_detalhe)
        for no in ilha.find_children("*", "MultiMeshInstance3D", true, false):
            var grupo: MultiMeshInstance3D = no as MultiMeshInstance3D
            if grupo != null and grupo.multimesh != null:
                var conta: int = grupo.multimesh.instance_count
                if grupo.has_meta("sem_reducao") or modo_editor:      # pinheiros da serra: poucos e baratos, ficam sempre inteiros
                    grupo.multimesh.visible_instance_count = -1
                    continue
                grupo.multimesh.visible_instance_count = -1 if qb == 2 else maxi(1, roundi(conta * (0.35 if q == 0 else 0.68)))
    for no in get_tree().root.find_children("*", "CPUParticles3D", true, false):
        var efeito: CPUParticles3D = no as CPUParticles3D
        if efeito == null:
            continue
        var chave: int = efeito.get_instance_id()
        if not _original_particulas.has(chave):
            _original_particulas[chave] = efeito.amount
        efeito.amount = maxi(4, roundi(int(_original_particulas[chave]) * [0.35, 0.65, 1.0, 1.3][q]))
    _aplicar_sobreposicoes()
    if cinema != null:
        cinema.aplicar()

## Aplica `sobrepor` por cima do que o nível de qualidade acabou de definir (vazio fora da bancada de GPU).
func _aplicar_sobreposicoes() -> void:
    if sobrepor.is_empty():
        return
    var vp: Viewport = get_viewport()
    if sobrepor.has("msaa"):
        var nivel_msaa: int = clampi(int(sobrepor["msaa"]), 0, 3)
        if nivel_msaa == 3 and not e_forward_plus():
            nivel_msaa = 2
        var tabela_msaa: Array = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
        var msaa: Viewport.MSAA = tabela_msaa[nivel_msaa]
        vp.msaa_3d = msaa
    if _ambiente != null and _ambiente.environment != null:
        if sobrepor.get("sem_ssao", false):
            _ambiente.environment.ssao_enabled = false
        if sobrepor.get("sem_glow", false):
            _ambiente.environment.glow_enabled = false
    if sobrepor.has("atlas"):
        RenderingServer.directional_shadow_atlas_set_size(int(sobrepor["atlas"]), true)
    if sobrepor.get("filtro_duro", false):
        RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
        RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
    if _sol != null:
        if sobrepor.get("sem_sombra", false):
            _sol.shadow_enabled = false
        if sobrepor.has("faixas"):
            var faixas: int = int(sobrepor["faixas"])
            _sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if faixas >= 4 else (DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if faixas == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL)
    if sobrepor.has("detalhe"):
        for ilha in _ilhas:
            if ilha.has_method("definir_detalhe"):
                ilha.definir_detalhe(int(sobrepor["detalhe"]))
    if sobrepor.has("mar") and _oceano != null and _oceano.has_method("definir_qualidade"):
        _oceano.definir_qualidade(int(sobrepor["mar"]))

func _process(delta: float) -> void:
    _ajuste_automatico(delta)
    if not mostrar_fps:
        return
    _contador += delta
    _soma_quadro += delta
    _n_quadros += 1
    if _contador >= 0.5:
        _contador = 0.0
        # quadro = tempo médio entre quadros; GPU/CPU = tempo de desenho medido pelo renderizador ("n/d" se ele não medir).
        var rid: RID = get_viewport().get_viewport_rid()
        var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(rid)
        var cpu: float = RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
        var quadro: float = _soma_quadro / maxf(1.0, float(_n_quadros)) * 1000.0
        _soma_quadro = 0.0
        _n_quadros = 0
        var gpu_txt: String = ("%.1f ms" % gpu) if gpu > 0.0 else "n/d"
        _fps_label.text = "FPS %d  |  quadro %.1f ms  |  GPU %s  |  CPU %.1f ms  |  %s  |  V-Sync %s" % [Engine.get_frames_per_second(), quadro, gpu_txt, cpu, NOMES[clampi(qualidade, 0, QUALIDADE_MAX)], "ligado" if vsync else "desligado"]

## Mede o FPS medio em janelas de 1 s. Se ficar abaixo da meta por 4 janelas seguidas, desce um nivel.
## Nunca sobe sozinho (evita vai-e-vem) e para de agir se o jogador mexer na qualidade.
func _ajuste_automatico(delta: float) -> void:
    if not automatica or qualidade <= 0:
        return
    if _auto_espera > 0.0:
        _auto_espera -= delta
        return
    if _painel != null and _painel.visible:
        return
    if delta > 0.5:          # engasgo isolado (carregar, arrastar a janela): nao conta
        return
    _auto_tempo += delta
    _auto_quadros += 1
    if _auto_tempo < 1.0:
        return
    var fps: float = float(_auto_quadros) / _auto_tempo
    _auto_tempo = 0.0
    _auto_quadros = 0
    var meta: float = 24.0 if LIMITES[clampi(fps_indice, 0, LIMITES.size() - 1)] == 30 else 33.0
    _auto_lentas = _auto_lentas + 1 if fps < meta else 0
    if _auto_lentas >= 4:
        _auto_lentas = 0
        _auto_espera = 6.0
        qualidade -= 1
        aplicar()
        if _qualidade_opcao != null:
            _qualidade_opcao.select(qualidade)
        _salvar()
        qualidade_ajustada.emit("Quadros baixos (%d FPS): qualidade ajustada para %s. F10 muda." % [roundi(fps), NOMES[qualidade]])

func _carregar() -> void:
    if not FileAccess.file_exists(ARQUIVO):
        return
    var dados = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
    if typeof(dados) != TYPE_DICTIONARY:
        return
    qualidade = clampi(int(dados.get("qualidade", 1)), 0, QUALIDADE_MAX)
    automatica = bool(dados.get("automatica", true))
    fps_indice = clampi(int(dados.get("fps", 1)), 0, 3)
    mostrar_fps = bool(dados.get("mostrar_fps", false))
    vsync = bool(dados.get("vsync", true))

func _salvar() -> void:
    var arquivo := FileAccess.open(ARQUIVO, FileAccess.WRITE)
    if arquivo != null:
        arquivo.store_string(JSON.stringify({"qualidade": qualidade, "automatica": automatica, "fps": fps_indice, "mostrar_fps": mostrar_fps, "vsync": vsync}))
