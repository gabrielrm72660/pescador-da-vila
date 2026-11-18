extends Node
## Bancada de GPU (F2, ou o botão do painel F10). Percorre quatro vistas e várias configurações gráficas, mede o tempo
## de GPU de cada uma e mostra uma tabela. Serve para descobrir onde vai o tempo do quadro antes de empilhar recursos novos.
##
## Como mede: V-Sync desligado e sem limite de FPS (a placa trabalha a toda, sem baixar o clock); em cada combinação espera
## um instante para o renderizador se ajustar e então junta ~1 s de amostras do tempo de GPU. O valor da tabela é a MEDIANA
## (um engasgo isolado de compilação de shader não entra). Tudo é restaurado ao terminar. Esc cancela.

signal terminou

enum Fase { VISTA, CONFIG, MEDINDO, RESULTADO }

## Cada linha: nome, nível-base de qualidade (0 a 3) e ajustes avulsos por cima (ver OpcoesGraficas.sobrepor).
const CONFIGS := [
    {"nome": "Ultra (padrão)", "base": 3, "sobrepor": {}},
    {"nome": "Ultra sem MSAA", "base": 3, "sobrepor": {"msaa": 0}},
    {"nome": "Ultra com MSAA 4x", "base": 3, "sobrepor": {"msaa": 2}},
    {"nome": "Ultra sem SSAO", "base": 3, "sobrepor": {"sem_ssao": true}},
    {"nome": "Ultra sem glow", "base": 3, "sobrepor": {"sem_glow": true}},
    {"nome": "Ultra sem sombras do sol", "base": 3, "sobrepor": {"sem_sombra": true}},
    {"nome": "Ultra sombra 2 faixas", "base": 3, "sobrepor": {"faixas": 2}},
    {"nome": "Ultra sombra atlas 4096", "base": 3, "sobrepor": {"atlas": 4096}},
    {"nome": "Ultra sombra filtro duro", "base": 3, "sobrepor": {"filtro_duro": true}},
    {"nome": "Ultra vegetação nível 1", "base": 3, "sobrepor": {"detalhe": 1}},
    {"nome": "Ultra vegetação nível 0", "base": 3, "sobrepor": {"detalhe": 0}},
    {"nome": "Ultra mar nível Alta", "base": 3, "sobrepor": {"mar": 2}},
    {"nome": "Alta", "base": 2, "sobrepor": {}},
    {"nome": "Média", "base": 1, "sobrepor": {}},
    {"nome": "Baixa", "base": 0, "sobrepor": {}},
]

const ARQUIVO := "user://pescador_bancada.txt"

var espera_vista: float = 1.2
var espera_config: float = 0.6
var janela: float = 0.9
var min_amostras: int = 30

var _opcoes                     # OpcoesGraficas (CanvasLayer pai)
var _jogo: Node
var _camera: Camera3D
var _fase: int = Fase.VISTA
var _vistas: Array = []
var _vi: int = 0
var _ci: int = 0
var _t: float = 0.0
var _gpu: Array = []
var _cpu: Array = []
var _dt: Array = []
var _resultados: Array = []     # [vista][config] = {"gpu", "cpu", "quadro"}
var _gpu_medido: bool = false
var _etq_progresso: Label
var _painel_resultado: Control

# estado guardado para restaurar
var _salvo_qualidade: int
var _salvo_auto: bool
var _salvo_vsync: bool
var _salvo_fps: int
var _salvo_mostrar_fps: bool
var _salvo_cam: Transform3D
var _salvo_cam_proc: bool
var _salvo_cam_fis: bool
var _salvo_hora: float
var _salvo_clima: int
var _salvo_hud: bool

func iniciar(opcoes) -> bool:
    _opcoes = opcoes
    _jogo = opcoes.get_parent()
    _camera = _jogo.get_node_or_null("Camera") as Camera3D
    if not _jogo.iniciado or _camera == null:
        _jogo.interface.aviso("Comece a viagem antes: a bancada mede a cena real do jogo.")
        terminou.emit()
        queue_free()
        return false
    if OS.get_environment("PESCADOR_BANCADA_RAPIDA") == "1":      # só para testar a lógica fora de uma GPU de verdade
        espera_vista = 0.3
        espera_config = 0.15
        janela = 0.15
        min_amostras = 2
    if opcoes.esta_aberto():
        opcoes.alternar()
    _salvo_qualidade = opcoes.qualidade
    _salvo_auto = opcoes.automatica
    _salvo_vsync = opcoes.vsync
    _salvo_fps = opcoes.fps_indice
    _salvo_mostrar_fps = opcoes.mostrar_fps
    _salvo_cam = _camera.global_transform
    _salvo_cam_proc = _camera.is_processing()
    _salvo_cam_fis = _camera.is_physics_processing()
    _salvo_hora = _jogo.clima.hora
    _salvo_clima = _jogo.clima.modo_clima
    _salvo_hud = _jogo.interface.esconder_hud
    _vistas = _montar_vistas()
    _resultados.clear()
    for v in _vistas:
        _resultados.append([])
    opcoes.automatica = false
    opcoes.vsync = false
    opcoes.fps_indice = 3                                          # "Sem limite"
    opcoes._medir(true)
    _camera.set_process(false)
    _camera.set_physics_process(false)
    _jogo.interface.esconder_hud = true
    _etq_progresso = Label.new()
    _etq_progresso.position = Vector2(24, 20)
    _etq_progresso.add_theme_font_size_override("font_size", 18)
    _etq_progresso.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
    _etq_progresso.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    _etq_progresso.add_theme_constant_override("outline_size", 6)
    opcoes.add_child(_etq_progresso)
    _vi = 0
    _comecar_vista()
    return true

## Quatro vistas: vila vista do mar, mar aberto, cais e casas de perto, e a câmera do jogo na chuva (como o jogador vê).
func _montar_vistas() -> Array:
    var vistas: Array = []
    var ilha = _jogo.ilhas[0] if _jogo.ilhas.size() > 0 else null
    var mundo = ilha.get("mundo") if ilha != null else null
    if mundo is Dictionary and mundo.has("casas") and not mundo["casas"].is_empty():
        var centro: Vector3 = ilha.centro
        var cp: Vector3 = ilha.cais_ponta
        var eixo: Vector3 = (cp - ilha.cais_inicio).normalized()
        var lateral := Vector3(-eixo.z, 0.0, eixo.x)
        var casa: Dictionary = mundo["casas"][mini(4, mundo["casas"].size() - 1)]
        var alvo_casa: Vector3 = centro + Vector3(float(casa["x"]), 6.0, float(casa["z"]))
        var alvo_casa_baixo: Vector3 = centro + Vector3(float(casa["x"]), 5.0, float(casa["z"]))
        vistas.append(_vista("Vila vista do mar", "Vila", Transform3D(Basis.IDENTITY, cp + eixo * 52.0 + lateral * 8.0 + Vector3(0, 9.0, 0)).looking_at(alvo_casa, Vector3.UP), 16.0, 1))
        var p_mar: Vector3 = cp + eixo * 120.0 + Vector3(0, 6.0, 0)
        vistas.append(_vista("Mar aberto", "Mar", Transform3D(Basis.IDENTITY, p_mar).looking_at(p_mar + eixo * 500.0 + Vector3(0, -9.0, 0), Vector3.UP), 16.0, 1))
        vistas.append(_vista("Cais e casas de perto", "Cais", Transform3D(Basis.IDENTITY, cp + eixo * 34.0 + lateral * 14.0 + Vector3(0, 3.0, 0)).looking_at(alvo_casa_baixo, Vector3.UP), 16.5, 1))
    vistas.append(_vista("Câmera do jogo na chuva", "Chuva", _salvo_cam, 17.0, 3))
    return vistas

func _vista(nome: String, curto: String, tr: Transform3D, hora: float, clima: int) -> Dictionary:
    return {"nome": nome, "curto": curto, "tr": tr, "hora": hora, "clima": clima}

func _comecar_vista() -> void:
    var v: Dictionary = _vistas[_vi]
    _jogo.clima.definir_clima(int(v["clima"]))
    _jogo.clima.hora = float(v["hora"])
    _jogo.clima.pular_transicoes()
    _camera.global_transform = v["tr"]
    _opcoes.sobrepor = {}
    _opcoes.qualidade = 3
    _opcoes.aplicar()
    _fase = Fase.VISTA
    _t = 0.0
    _ci = 0

func _comecar_config() -> void:
    var c: Dictionary = CONFIGS[_ci]
    _opcoes.sobrepor = c["sobrepor"]
    _opcoes.qualidade = int(c["base"])
    _opcoes.aplicar()
    _fase = Fase.CONFIG
    _t = 0.0

func _process(delta: float) -> void:
    if _fase == Fase.RESULTADO or _vistas.is_empty():
        return
    var v: Dictionary = _vistas[_vi]
    # congela a hora e a câmera: o relógio do jogo e a câmera de popa não podem mexer na cena durante a medida
    _jogo.clima.hora = float(v["hora"])
    _camera.global_transform = v["tr"]
    var feito: int = _vi * CONFIGS.size() + _ci
    _etq_progresso.text = "BANCADA DE GPU  %d%%  ·  vista %d/%d (%s)  ·  %s  ·  Esc cancela, não mexa em nada" % [
        roundi(100.0 * feito / float(_vistas.size() * CONFIGS.size())), _vi + 1, _vistas.size(), v["curto"], CONFIGS[_ci]["nome"]]
    _t += delta
    match _fase:
        Fase.VISTA:
            if _t >= espera_vista:
                _comecar_config()
        Fase.CONFIG:
            if _t >= espera_config:
                _gpu.clear()
                _cpu.clear()
                _dt.clear()
                _t = 0.0
                _fase = Fase.MEDINDO
        Fase.MEDINDO:
            var rid: RID = get_viewport().get_viewport_rid()
            _gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
            _cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
            _dt.append(delta * 1000.0)
            if _t >= janela and _gpu.size() >= min_amostras:
                _fechar_config()

func _fechar_config() -> void:
    var gpu: float = _mediana(_gpu)
    if gpu > 0.0:
        _gpu_medido = true
    _resultados[_vi].append({"gpu": gpu, "cpu": _mediana(_cpu), "quadro": _mediana(_dt)})
    _ci += 1
    if _ci >= CONFIGS.size():
        _vi += 1
        if _vi >= _vistas.size():
            _terminar()
            return
        _comecar_vista()
    else:
        _comecar_config()

static func _mediana(a: Array) -> float:
    if a.is_empty():
        return 0.0
    var b: Array = a.duplicate()
    b.sort()
    return float(b[b.size() >> 1])

func _input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        return
    var tecla: int = event.physical_keycode
    if _fase == Fase.RESULTADO:
        if tecla == KEY_ENTER or tecla == KEY_KP_ENTER or tecla == KEY_ESCAPE or tecla == KEY_F2:
            get_viewport().set_input_as_handled()
            _fechar_resultado()
    elif tecla == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        _restaurar()
        _jogo.interface.aviso("Teste de desempenho cancelado.")
        terminou.emit()
        queue_free()

func _restaurar() -> void:
    _opcoes.sobrepor = {}
    _opcoes.qualidade = _salvo_qualidade
    _opcoes.automatica = _salvo_auto
    _opcoes.vsync = _salvo_vsync
    _opcoes.fps_indice = _salvo_fps
    _opcoes.aplicar()
    _opcoes._medir(_salvo_mostrar_fps)
    _camera.global_transform = _salvo_cam
    _camera.set_process(_salvo_cam_proc)
    _camera.set_physics_process(_salvo_cam_fis)
    _jogo.clima.definir_clima(_salvo_clima)
    _jogo.clima.hora = _salvo_hora
    _jogo.clima.atualizar()
    _jogo.interface.esconder_hud = _salvo_hud
    if _etq_progresso != null:
        _etq_progresso.queue_free()
        _etq_progresso = null

func _terminar() -> void:
    _restaurar()
    var texto: String = _relatorio()
    var arq := FileAccess.open(ARQUIVO, FileAccess.WRITE)
    if arq != null:
        arq.store_string(texto)
    DisplayServer.clipboard_set(texto)
    print(texto)
    _mostrar_resultado(texto)

func _relatorio() -> String:
    var nv: int = _vistas.size()
    var usa_gpu: bool = _gpu_medido
    var L: PackedStringArray = []
    L.append("%s — bancada de GPU" % str(ProjectSettings.get_setting("application/config/name", "Pescador")))
    L.append("Placa: %s  |  renderizador: %s  |  janela: %s" % [RenderingServer.get_video_adapter_name(), _opcoes.metodo_render(), str(DisplayServer.window_get_size())])
    L.append("Medido com V-Sync desligado e sem limite de FPS. Cada número é a mediana de ~1 s de quadros.")
    if not usa_gpu:
        L.append("ATENÇÃO: o renderizador não informou tempo de GPU; as colunas mostram o tempo de quadro (ms).")
    L.append("")
    var cab: String = "%-26s" % ("GPU (ms)" if usa_gpu else "Quadro (ms)")
    for v in _vistas:
        cab += "%7s" % v["curto"]
    cab += "%8s%8s%7s%7s" % ["Média", "Δ Ultra", "CPU", "FPS"]
    L.append(cab)
    L.append("-".repeat(cab.length()))
    var base_media: float = 0.0
    for ci in CONFIGS.size():
        var linha: String = "%-26s" % CONFIGS[ci]["nome"]
        var soma: float = 0.0
        var soma_cpu: float = 0.0
        var soma_q: float = 0.0
        for vi in nv:
            var r: Dictionary = _resultados[vi][ci]
            var valor: float = float(r["gpu"]) if usa_gpu else float(r["quadro"])
            soma += valor
            soma_cpu += float(r["cpu"])
            soma_q += float(r["quadro"])
            linha += "%7.1f" % valor
        var media: float = soma / float(nv)
        if ci == 0:
            base_media = media
        linha += "%8.1f%8s%7.1f%7d" % [media, "—" if ci == 0 else "%+.1f" % (media - base_media), soma_cpu / float(nv), roundi(1000.0 / maxf(0.01, soma_q / float(nv)))]
        L.append(linha)
    L.append("")
    L.append("Δ Ultra: quanto a configuração ganha (−) ou perde (+) de ms por quadro em relação ao Ultra padrão.")
    L.append("CPU = tempo de preparo do quadro (média das vistas); FPS = médio das vistas.")
    L.append("Orçamento por quadro: 60 FPS = 16,7 ms · 100 FPS = 10,0 ms · 144 FPS = 6,9 ms.")
    return "\n".join(L)

func _mostrar_resultado(texto: String) -> void:
    _fase = Fase.RESULTADO
    _painel_resultado = ColorRect.new()
    (_painel_resultado as ColorRect).color = Color(0.01, 0.04, 0.06, 0.94)
    _painel_resultado.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _painel_resultado.mouse_filter = Control.MOUSE_FILTER_STOP
    _opcoes.add_child(_painel_resultado)
    var centro := CenterContainer.new()
    centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _painel_resultado.add_child(centro)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 14)
    centro.add_child(coluna)
    var titulo := Label.new()
    titulo.text = "RESULTADO DA BANCADA — o texto já foi copiado (Ctrl+V). Tire um print desta tela ou cole a tabela na conversa."
    titulo.add_theme_color_override("font_color", Color(0.60, 0.81, 0.82))
    coluna.add_child(titulo)
    var tabela := Label.new()
    tabela.text = texto
    var fonte := SystemFont.new()
    fonte.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "DejaVu Sans Mono", "Courier New", "monospace"])
    tabela.add_theme_font_override("font", fonte)
    tabela.add_theme_font_size_override("font_size", 15)
    coluna.add_child(tabela)
    var caminho := Label.new()
    caminho.text = "Salvo em: %s" % ProjectSettings.globalize_path(ARQUIVO)
    caminho.add_theme_font_size_override("font_size", 13)
    caminho.add_theme_color_override("font_color", Color(0.60, 0.81, 0.82))
    coluna.add_child(caminho)
    var fechar := Button.new()
    fechar.text = "FECHAR [Enter]"
    fechar.pressed.connect(_fechar_resultado)
    coluna.add_child(fechar)

func _fechar_resultado() -> void:
    if _painel_resultado != null:
        _painel_resultado.queue_free()
        _painel_resultado = null
    terminou.emit()
    queue_free()
