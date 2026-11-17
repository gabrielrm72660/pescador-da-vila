extends CanvasLayer
## Configurações leves, sem dependências externas. F10 abre; F3 mostra FPS.

signal tela_mudou
signal qualidade_ajustada(texto: String)
const ARQUIVO := "user://pescador_graficos.json"
const NOMES := ["Baixa", "Média", "Alta"]
const LIMITES := [30, 60, 120, 0]
var qualidade: int = 1
var automatica: bool = true      # abaixa a qualidade sozinha se o jogo ficar lento (nunca sobe sozinha)
var fps_indice: int = 1
var mostrar_fps: bool = false
var _painel: Control
var _fps_label: Label
var _qualidade_opcao: OptionButton
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
        qualidade = clampi(int(OS.get_environment("PESCADOR_QUALIDADE")), 0, 2)
    _construir()

func configurar(ilhas: Array, sol: DirectionalLight3D, oceano: MeshInstance3D, ambiente: WorldEnvironment) -> void:
    _ilhas = ilhas.duplicate()
    _sol = sol
    _oceano = oceano
    _ambiente = ambiente
    _camera = get_node_or_null("../Camera") as Camera3D
    aplicar()

func esta_aberto() -> bool:
    return _painel != null and _painel.visible

func alternar() -> void:
    _painel.visible = not _painel.visible
    tela_mudou.emit()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_F10:
            alternar()
            get_viewport().set_input_as_handled()
        elif event.physical_keycode == KEY_F3:
            alternar_fps()
            get_viewport().set_input_as_handled()

func alternar_fps() -> void:
    mostrar_fps = not mostrar_fps
    _fps_label.visible = mostrar_fps
    _salvar()

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
    cartao.custom_minimum_size = Vector2(500, 350)
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
        automatica = false          # quem escolhe a qualidade assume o controle
        if _auto_opcao != null:
            _auto_opcao.set_pressed_no_signal(false)
        aplicar()
        _salvar())
    coluna.add_child(_qualidade_opcao)
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
    var fechar := Button.new()
    fechar.text = "VOLTAR AO JOGO [F10]"
    fechar.pressed.connect(alternar)
    coluna.add_child(fechar)

func aplicar() -> void:
    Engine.max_fps = LIMITES[clampi(fps_indice, 0, LIMITES.size() - 1)]
    var q: int = clampi(qualidade, 0, 2)
    get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
    if _sol != null:
        _sol.shadow_enabled = q > 0
        # Cada faixa de sombra redesenha a ilha de novo: Alta usa 4 faixas, Média só 2 (metade do custo de sombra).
        _sol.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if q == 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
    if _camera != null:
        _camera.far = [850.0, 1350.0, 1900.0][q]
    if _ambiente != null and _ambiente.environment != null:
        _ambiente.environment.ssao_enabled = q > 0
        _ambiente.environment.glow_enabled = q > 0
    if _oceano != null and _oceano.has_method("definir_qualidade"):
        _oceano.definir_qualidade(q)
    for ilha in _ilhas:
        for no in ilha.find_children("*", "MultiMeshInstance3D", true, false):
            var grupo: MultiMeshInstance3D = no as MultiMeshInstance3D
            if grupo != null and grupo.multimesh != null:
                var conta: int = grupo.multimesh.instance_count
                grupo.multimesh.visible_instance_count = -1 if q == 2 else maxi(1, roundi(conta * (0.35 if q == 0 else 0.68)))
    for no in get_tree().root.find_children("*", "CPUParticles3D", true, false):
        var efeito: CPUParticles3D = no as CPUParticles3D
        if efeito == null:
            continue
        var chave: int = efeito.get_instance_id()
        if not _original_particulas.has(chave):
            _original_particulas[chave] = efeito.amount
        efeito.amount = maxi(4, roundi(int(_original_particulas[chave]) * [0.35, 0.65, 1.0][q]))

func _process(delta: float) -> void:
    _ajuste_automatico(delta)
    if not mostrar_fps:
        return
    _contador += delta
    if _contador >= 0.5:
        _contador = 0.0
        _fps_label.text = "FPS %d  |  %.1f ms  |  %s" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, NOMES[clampi(qualidade, 0, 2)]]

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
    qualidade = clampi(int(dados.get("qualidade", 1)), 0, 2)
    automatica = bool(dados.get("automatica", true))
    fps_indice = clampi(int(dados.get("fps", 1)), 0, 3)
    mostrar_fps = bool(dados.get("mostrar_fps", false))

func _salvar() -> void:
    var arquivo := FileAccess.open(ARQUIVO, FileAccess.WRITE)
    if arquivo != null:
        arquivo.store_string(JSON.stringify({"qualidade": qualidade, "automatica": automatica, "fps": fps_indice, "mostrar_fps": mostrar_fps}))
