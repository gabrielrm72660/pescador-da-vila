extends Node
## Modo Construtor (Tab): edita a ilha principal dentro do jogo.
## Casas e prédios, ruas, postes, props do porto e vegetação (pinheiros, coqueiros, árvores, moitas, pedras).
## O que o jogador monta vive em ilha.mundo (scripts/mundo_dados.gd) e é salvo em user://mundo_ilha_principal.json.
## O jogo fica pausado enquanto o construtor está aberto; ao sair, o mundo editado vale para a viagem.
##
## Câmera:  WASD move · setas giram · roda aproxima · botão do meio (ou Alt + esquerdo) gira · Shift acelera
## Ações:   B colocar · V mover · X apagar · 1..9 e 0 trocam de categoria · Q/E giram · C varia · Delete apaga
##          Ctrl+Z desfaz · Ctrl+Y refaz · Ctrl+S salva · Tab sai

signal fechado

const MundoDados = preload("res://scripts/mundo_dados.gd")
const OpcoesGraficas = preload("res://scripts/opcoes_graficas.gd")

const MAX_DESFAZER := 60
const RECUO_RUA := 3.7                  # m entre o eixo da rua e a frente da casa (a rua tem 1,9 m de meia largura)
const ALCANCE_IMA := 15.0               # m: até onde a rua "puxa" a casa que está sendo colocada

## id, rótulo, tecla de atalho
const CATEGORIAS := [
    ["casas", "1  Casas", KEY_1],
    ["ruas", "2  Ruas", KEY_2],
    ["postes", "3  Postes", KEY_3],
    ["props", "4  Props", KEY_4],
    ["pinheiros", "5  Pinheiros", KEY_5],
    ["coqueiros", "6  Coqueiros", KEY_6],
    ["arvores", "7  Árvores", KEY_7],
    ["moitas", "8  Moitas", KEY_8],
    ["pedras", "9  Pedras", KEY_9],
    ["limpar", "0  Borracha", KEY_0],
]
const VEGETACAO := ["pinheiros", "coqueiros", "arvores", "moitas", "pedras"]
## Regras de cada vegetação: distância mínima entre dois, altura mínima/máxima do terreno, raio para clicar, altura da marca.
const REGRAS := {
    "pinheiros": {"dist": 2.4, "hmin": 1.6, "hmax": 45.0, "pega": 2.2, "marca": 9.0},
    "coqueiros": {"dist": 2.6, "hmin": 1.0, "hmax": 18.0, "pega": 2.4, "marca": 10.5},
    "arvores": {"dist": 3.4, "hmin": 3.0, "hmax": 34.0, "pega": 3.0, "marca": 9.0},
    "moitas": {"dist": 1.3, "hmin": 1.0, "hmax": 32.0, "pega": 1.6, "marca": 3.5},
    "pedras": {"dist": 1.6, "hmin": -1.6, "hmax": 34.0, "pega": 1.8, "marca": 3.5},
}
const TIPOS_CASA := [["casa", "Casa de pescador"], ["armazem", "Armazém"], ["mercado", "Mercado"], ["capela", "Capela"]]
const TIPOS_RUA := [["calcada", "Calçada de pedra"], ["areia", "Areia batida"]]
## tipo, variante, rótulo
const TIPOS_PROP := [["rede", 0, "Rede de pesca"], ["canoa", 0, "Canoa vermelha"], ["canoa", 1, "Canoa azul"],
        ["caixote", 0, "Caixote"], ["caixote", 1, "Pilha de caixotes"], ["barril", 0, "Barril"], ["banco", 0, "Banco"]]

var jogo: Node3D
var ilha: Node3D
var ativo: bool = false
var categoria: String = "casas"
var ferramenta: String = "colocar"            # colocar | selecionar | apagar
var camera: Camera3D
var modificado: bool = false

var _foco := Vector2.ZERO                     # ponto olhado (local da ilha)
var _yaw: float = 0.35
var _pitch: float = 0.95                      # rad acima do horizonte
var _dist: float = 125.0
var _orbitando: bool = false
var _hover = null                             # Vector2 (local) sob o mouse, ou null
var _hover_sujo: bool = true
var _giro_atual: float = 0.0                  # giro que o próximo objeto leva (Q/E)
var _raio_pincel: float = 7.0
var _ima: bool = true
var _limpar_ao_construir: bool = true
var _tipo_casa: int = 0
var _tipo_rua: int = 0
var _tipo_prop: int = 0
var _desfazer: Array = []
var _refazer: Array = []
var _sel: Dictionary = {}                     # {"cat", "i", "v"} ou vazio
var _arrastando: bool = false
var _arrasto_moveu: bool = false
var _pintando: int = 0                        # 0 nada · 1 pinta · 2 apaga
var _ultimo_carimbo := Vector2(1e9, 1e9)
var _rua_atual: Array = []                    # pontos (Vector2 local) da rua que está sendo desenhada
var _rua_estende: Dictionary = {}             # {"i": rua existente, "inicio": bool} quando a nova rua continua uma antiga
var _macio: bool = true                       # arrastar um ponto da rua puxa os vizinhos (a curva continua suave)
var _arrasto_rua: Dictionary = {}             # estado do arrasto de um ponto de rua: pontos originais e distâncias
const RAIO_MACIO := 10.0
var _rng := RandomNumberGenerator.new()
var _aviso_tempo: float = 0.0
var _estado: Label                            # linha de diagnóstico (FPS, GPU, mouse) no pé do painel
var _estado_tempo: float = 0.0
var _n_raw: int = 0                           # eventos de mouse que chegaram ao editor (antes da interface)
var _n_mundo: int = 0                         # eventos de mouse que chegaram ao mundo (depois da interface)
var _n_cliques: int = 0
var _ultimo_mouse := Vector2.ZERO

# --- visuais (filhos da ilha, em coordenadas locais) ---
var _visuais: Node3D
var _cursor: MeshInstance3D
var _fantasma: MeshInstance3D
var _seta: MeshInstance3D
var _marca: MeshInstance3D
var _anel_marca: MeshInstance3D
var _fita: MeshInstance3D
var _pontos_rua: MultiMeshInstance3D

# --- interface ---
var _ui: CanvasLayer
var _painel: PanelContainer
var _tipo_opcao: OptionButton
var _linha_pincel: HBoxContainer
var _rotulo_pincel: Label
var _botoes_cat: Dictionary = {}
var _botoes_ferr: Dictionary = {}
var _dica: Label
var _info: Label
var _aviso: Label
var _check_ima: CheckButton
var _check_limpar: CheckButton
var _check_macio: CheckButton

func configurar(jogo_: Node3D, ilha_: Node3D) -> void:
    jogo = jogo_
    ilha = ilha_
    process_mode = Node.PROCESS_MODE_ALWAYS
    _rng.randomize()

func _input(event: InputEvent) -> void:
    if ativo and event is InputEventMouse:
        _n_raw += 1
        _ultimo_mouse = event.position
    if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_TAB or event.physical_keycode == KEY_F9):
        get_viewport().set_input_as_handled()
        if ativo:
            fechar()
        else:
            abrir()

# ---------------------------------------------------------------------------------------------------------------
# abrir / fechar
# ---------------------------------------------------------------------------------------------------------------

func abrir() -> void:
    if ativo or ilha == null or not ilha.editavel:
        return
    ativo = true
    _n_raw = 0
    _n_mundo = 0
    _n_cliques = 0
    OpcoesGraficas.modo_editor = true
    jogo.graficos.aplicar()                       # mostra toda a vegetação, mesmo na qualidade Baixa
    jogo.interface.visible = false
    if camera == null:
        camera = Camera3D.new()
        camera.near = 0.3
        camera.far = 2000.0
        camera.fov = 62.0
        add_child(camera)
        _construir_visuais()
        _construir_interface()
    _foco = _centro_da_vila()
    _desfazer.clear()
    _refazer.clear()
    _sel = {}
    _rua_atual = []
    _rua_estende = {}
    modificado = false
    camera.current = true
    _ui.visible = true
    _visuais.visible = true
    _escolher_categoria(categoria)
    _escolher_ferramenta(ferramenta)
    _atualizar_camera()
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    _mostrar_aviso("Modo Construtor aberto. Clique na ilha para colocar. Tab sai e guarda.")
    _registrar_diagnostico("abriu")
    get_tree().paused = true                      # por último: se algo acima falhar, o jogo não fica congelado

func fechar() -> void:
    if not ativo:
        return
    var salvou := false
    if modificado:
        salvou = _salvar(false)
    ativo = false
    _arrastando = false
    _pintando = 0
    _ui.visible = false
    _visuais.visible = false
    camera.current = false
    jogo.camera_barco.current = true
    jogo.interface.visible = true
    OpcoesGraficas.modo_editor = false
    jogo.graficos.aplicar()
    get_tree().paused = false
    if salvou:
        jogo.interface.aviso("Mundo salvo. O que você construiu vale daqui para frente.")
    fechado.emit()

func _centro_da_vila() -> Vector2:
    var soma := Vector2.ZERO
    var n := 0
    for c in ilha.mundo.get("casas", []):
        soma += Vector2(float(c["x"]), float(c["z"]))
        n += 1
    return soma / float(n) if n > 0 else Vector2.ZERO

# ---------------------------------------------------------------------------------------------------------------
# câmera
# ---------------------------------------------------------------------------------------------------------------

func _atualizar_camera() -> void:
    var h: float = maxf(0.0, ilha.altura_local(_foco.x, _foco.y))
    var alvo: Vector3 = Vector3(_foco.x, h, _foco.y) + ilha.centro
    var desloc := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
    camera.global_position = alvo + desloc
    camera.look_at(alvo, Vector3.UP)
    _hover_sujo = true

func _process(delta: float) -> void:
    if not ativo:
        return
    var mudou := false
    var rapido: float = 2.6 if Input.is_key_pressed(KEY_SHIFT) else 1.0
    if not Input.is_key_pressed(KEY_CTRL):
        var mover := Vector2.ZERO
        if Input.is_key_pressed(KEY_W):
            mover.y -= 1.0
        if Input.is_key_pressed(KEY_S):
            mover.y += 1.0
        if Input.is_key_pressed(KEY_A):
            mover.x -= 1.0
        if Input.is_key_pressed(KEY_D):
            mover.x += 1.0
        if mover != Vector2.ZERO:
            var frente := Vector2(-sin(_yaw), -cos(_yaw))
            var direita := Vector2(cos(_yaw), -sin(_yaw))
            _foco += (frente * -mover.y + direita * mover.x) * _dist * 0.8 * rapido * delta
            _foco = _foco.clamp(Vector2(-165, -165), Vector2(165, 165))
            mudou = true
    if Input.is_key_pressed(KEY_LEFT):
        _yaw += 1.6 * delta
        mudou = true
    if Input.is_key_pressed(KEY_RIGHT):
        _yaw -= 1.6 * delta
        mudou = true
    if Input.is_key_pressed(KEY_UP):
        _pitch = minf(1.5, _pitch + 1.0 * delta)
        mudou = true
    if Input.is_key_pressed(KEY_DOWN):
        _pitch = maxf(0.25, _pitch - 1.0 * delta)
        mudou = true
    if mudou:
        _atualizar_camera()
    if _hover_sujo:
        _hover_sujo = false
        _hover = _ponto_no_terreno(get_viewport().get_mouse_position())
        _atualizar_cursor()
    if _aviso_tempo > 0.0:
        _aviso_tempo -= delta
        _aviso.modulate.a = clampf(_aviso_tempo, 0.0, 1.0)
    # O jogo fica pausado enquanto se edita, mas o mar continua mexendo (senão parece que travou).
    var mar = jogo.get("oceano")
    if mar != null and mar.get("_material") != null:
        mar.tempo += delta
        mar._material.set_shader_parameter("tempo_mar", mar.tempo)
    _estado_tempo -= delta
    if _estado_tempo <= 0.0 and _estado != null:
        _estado_tempo = 0.4
        var onde: String = "fora da ilha" if _hover == null else "(%d, %d)" % [roundi(_hover.x), roundi(_hover.y)]
        _estado.text = "%d FPS · mouse %d/%d · cliques %d · cursor %s" % [Engine.get_frames_per_second(), _n_raw, _n_mundo, _n_cliques, onde]

func _registrar_diagnostico(evento: String) -> void:
    var metodo: String = str(RenderingServer.call("get_current_rendering_method")) if RenderingServer.has_method("get_current_rendering_method") else str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))
    var linha: String = "%s | %s | Godot %s | %s | %s | janela %s" % [Time.get_datetime_string_from_system(), evento, Engine.get_version_info().get("string", "?"), metodo, RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size()]
    print("[CONSTRUTOR] ", linha)
    var arq := FileAccess.open("user://construtor_diag.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://construtor_diag.txt") else FileAccess.WRITE)
    if arq != null:
        arq.seek_end()
        arq.store_line(linha)

## Onde o raio do mouse encontra o terreno (coordenadas locais da ilha), ou null.
func _ponto_no_terreno(tela: Vector2) -> Variant:
    if camera == null:
        return null
    var o: Vector3 = camera.project_ray_origin(tela)
    var d: Vector3 = camera.project_ray_normal(tela)
    if d.y > -0.001:
        return null
    var t: float = maxf(0.0, (o.y - 48.0) / -d.y)
    var t_fim: float = minf((o.y + 14.0) / -d.y, t + 900.0)     # raio quase horizontal não varre dezenas de km
    var anterior: float = t
    var achou := false
    while t <= t_fim:
        var q: Vector3 = o + d * t
        if q.y <= ilha.altura_local(q.x - ilha.centro.x, q.z - ilha.centro.z):
            achou = true
            break
        anterior = t
        t += 2.0
    if not achou:
        return null
    var a: float = anterior
    var b: float = t
    for i in 9:
        var m: float = (a + b) * 0.5
        var q2: Vector3 = o + d * m
        if q2.y <= ilha.altura_local(q2.x - ilha.centro.x, q2.z - ilha.centro.z):
            b = m
        else:
            a = m
    var f: Vector3 = o + d * b
    return Vector2(f.x - ilha.centro.x, f.z - ilha.centro.z)

# ---------------------------------------------------------------------------------------------------------------
# entrada
# ---------------------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if not ativo:
        return
    if event is InputEventMouse:
        _n_mundo += 1
    if event is InputEventMouseButton:
        _mouse_botao(event)
    elif event is InputEventMouseMotion:
        _mouse_movimento(event)
    elif event is InputEventKey and event.pressed and not event.echo:
        _tecla(event)

func _mouse_botao(e: InputEventMouseButton) -> void:
    match e.button_index:
        MOUSE_BUTTON_WHEEL_UP:
            if e.pressed:
                if e.ctrl_pressed and _categoria_e_pincel():
                    _mudar_pincel(1.0)
                else:
                    _dist = clampf(_dist * 0.88, 10.0, 340.0)
                    _atualizar_camera()
        MOUSE_BUTTON_WHEEL_DOWN:
            if e.pressed:
                if e.ctrl_pressed and _categoria_e_pincel():
                    _mudar_pincel(-1.0)
                else:
                    _dist = clampf(_dist * 1.14, 10.0, 340.0)
                    _atualizar_camera()
        MOUSE_BUTTON_MIDDLE:
            _orbitando = e.pressed
        MOUSE_BUTTON_LEFT:
            if e.pressed:
                if e.alt_pressed:
                    _orbitando = true
                    return
                _esquerdo_aperta(e)
            else:
                _orbitando = false
                _esquerdo_solta()
        MOUSE_BUTTON_RIGHT:
            if e.pressed:
                _direito_aperta()
            else:
                if _pintando == 2:
                    _pintando = 0

func _mouse_movimento(e: InputEventMouseMotion) -> void:
    if _orbitando:
        if Input.is_key_pressed(KEY_SHIFT):
            var frente := Vector2(-sin(_yaw), -cos(_yaw))
            var direita := Vector2(cos(_yaw), -sin(_yaw))
            _foco += (direita * -e.relative.x + frente * e.relative.y) * _dist * 0.0022
            _foco = _foco.clamp(Vector2(-165, -165), Vector2(165, 165))
        else:
            _yaw -= e.relative.x * 0.006
            _pitch = clampf(_pitch + e.relative.y * 0.005, 0.25, 1.5)
        _atualizar_camera()
        return
    _hover = _ponto_no_terreno(e.position)
    _hover_sujo = false
    _atualizar_cursor()
    if _hover == null:
        return
    var p: Vector2 = _hover
    if _arrastando:
        if not _arrasto_moveu:
            _guardar_desfazer()
            _arrasto_moveu = true
        _mover_selecionado(p)
        _atualizar_marca()
    elif _pintando != 0 and _categoria_e_pincel():
        if p.distance_to(_ultimo_carimbo) >= maxf(1.2, _raio_pincel * 0.45):
            _carimbar(p, _pintando == 2)

func _esquerdo_aperta(e: InputEventMouseButton) -> void:
    _n_cliques += 1
    if _hover == null:
        _mostrar_aviso("O clique caiu fora da ilha (mar ou céu). Aponte para a terra.")
        return
    var p: Vector2 = _hover
    if categoria == "limpar":
        _guardar_desfazer()
        _pintando = 2
        _ultimo_carimbo = Vector2(1e9, 1e9)
        _carimbar(p, true)
        return
    match ferramenta:
        "colocar":
            _colocar(p, e.double_click)
        "selecionar":
            _selecionar(p)
        "apagar":
            _apagar(p)

func _esquerdo_solta() -> void:
    if _arrastando:
        _arrastando = false
        if _arrasto_moveu:
            _arrasto_moveu = false
            _depois_de_mover()
    if _pintando == 1 or (_pintando == 2 and categoria == "limpar") or _pintando == 2:
        _pintando = 0

func _direito_aperta() -> void:
    if categoria == "ruas" and not _rua_atual.is_empty():
        _terminar_rua()
        return
    if _categoria_e_pincel() and _hover != null:
        _guardar_desfazer()
        _pintando = 2
        _ultimo_carimbo = Vector2(1e9, 1e9)
        _carimbar(_hover, true)
        return
    _sel = {}
    _atualizar_marca()

func _tecla(e: InputEventKey) -> void:
    var k: Key = e.physical_keycode
    if e.ctrl_pressed:
        match k:
            KEY_Z:
                if e.shift_pressed:
                    _refazer_acao()
                else:
                    _desfazer_acao()
            KEY_Y:
                _refazer_acao()
            KEY_S:
                _salvar(true)
        return
    for c in CATEGORIAS:
        if k == c[2]:
            _escolher_categoria(c[0])
            return
    match k:
        KEY_B:
            _escolher_ferramenta("colocar")
        KEY_V:
            _escolher_ferramenta("selecionar")
        KEY_X:
            _escolher_ferramenta("apagar")
        KEY_DELETE, KEY_BACKSPACE:
            _apagar_selecionado()
        KEY_Q:
            _girar(PI / 12.0 * (0.33 if e.shift_pressed else 1.0))
        KEY_E:
            _girar(-PI / 12.0 * (0.33 if e.shift_pressed else 1.0))
        KEY_C:
            _variar()
        KEY_ENTER, KEY_KP_ENTER:
            if categoria == "ruas":
                _terminar_rua()
        KEY_ESCAPE:
            if not _rua_atual.is_empty():
                _rua_atual = []
                _rua_estende = {}
                _atualizar_fita()
                _atualizar_pontos_ruas()
            elif not _sel.is_empty():
                _sel = {}
                _atualizar_marca()
            else:
                fechar()
        KEY_BRACKETLEFT:
            _mudar_pincel(-1.0)
        KEY_BRACKETRIGHT:
            _mudar_pincel(1.0)

# ---------------------------------------------------------------------------------------------------------------
# categorias e ferramentas
# ---------------------------------------------------------------------------------------------------------------

func _categoria_e_pincel() -> bool:
    return categoria == "limpar" or VEGETACAO.has(categoria)

func _escolher_categoria(id: String) -> void:
    categoria = id
    _sel = {}
    _rua_atual = []
    _rua_estende = {}
    _arrastando = false
    _pintando = 0
    for chave in _botoes_cat:
        (_botoes_cat[chave] as Button).set_pressed_no_signal(chave == id)
    _preencher_tipos()
    _linha_pincel.visible = _categoria_e_pincel()
    _check_ima.visible = id == "casas"
    _check_macio.visible = id == "ruas"
    _check_limpar.visible = id == "casas" or id == "ruas"
    _atualizar_dica()
    _atualizar_pontos_ruas()
    _atualizar_fita()
    _atualizar_marca()
    _atualizar_cursor()

func _escolher_ferramenta(nome: String) -> void:
    ferramenta = nome
    _arrastando = false
    _pintando = 0
    for chave in _botoes_ferr:
        (_botoes_ferr[chave] as Button).set_pressed_no_signal(chave == nome)
    _atualizar_dica()
    _atualizar_cursor()

func _preencher_tipos() -> void:
    _tipo_opcao.clear()
    var itens: Array = []
    var escolhido := 0
    match categoria:
        "casas":
            for t in TIPOS_CASA:
                itens.append(t[1])
            escolhido = _tipo_casa
        "ruas":
            for t in TIPOS_RUA:
                itens.append(t[1])
            escolhido = _tipo_rua
        "props":
            for t in TIPOS_PROP:
                itens.append(t[2])
            escolhido = _tipo_prop
    for nome in itens:
        _tipo_opcao.add_item(nome)
    _tipo_opcao.visible = not itens.is_empty()
    if not itens.is_empty():
        _tipo_opcao.select(escolhido)

func _ao_escolher_tipo(n: int) -> void:
    match categoria:
        "casas":
            _tipo_casa = n
        "ruas":
            _tipo_rua = n
        "props":
            _tipo_prop = n
    _atualizar_cursor()

func _mudar_pincel(passo: float) -> void:
    _raio_pincel = clampf(_raio_pincel + passo, 2.0, 24.0)
    _rotulo_pincel.text = "Pincel: %d m" % roundi(_raio_pincel)
    _atualizar_cursor()

func _atualizar_dica() -> void:
    var texto := ""
    if categoria == "limpar":
        texto = "Segure o botão e passe a borracha: apaga toda a vegetação sob o círculo. Ctrl+roda muda o tamanho."
    elif ferramenta == "colocar":
        match categoria:
            "casas":
                texto = "Clique para colocar. A casa vira sozinha para a rua mais próxima (Ímã). Q/E giram, C muda a cor."
            "ruas":
                texto = "Clique para marcar os pontos da rua. Duplo clique, Enter ou botão direito termina. Esc cancela. Começar na ponta de uma rua continua ela."
            "postes":
                texto = "Clique para colocar um poste de luz (acende à noite)."
            "props":
                texto = "Clique para colocar. Q/E giram, C varia."
            _:
                texto = "Segure o botão e pinte. Botão direito apaga. Ctrl+roda ou [ ] mudam o tamanho do pincel."
    elif ferramenta == "selecionar":
        texto = "Clique num objeto para escolher e arraste para mover. Q/E giram, C varia, Delete apaga."
    else:
        texto = "Clique no objeto para apagar. Na vegetação, segure e arraste para varrer."
    _dica.text = texto

# ---------------------------------------------------------------------------------------------------------------
# dados: acesso genérico
# ---------------------------------------------------------------------------------------------------------------

func _lista(cat: String) -> Array:
    return ilha.mundo.get(cat, [])

func _pos_item(item) -> Vector2:
    if item is Dictionary:
        return Vector2(float(item["x"]), float(item["z"]))
    return Vector2(float(item[0]), float(item[1]))

func _guardar_desfazer() -> void:
    _desfazer.append(MundoDados.copiar(ilha.mundo))
    if _desfazer.size() > MAX_DESFAZER:
        _desfazer.pop_front()
    _refazer.clear()
    modificado = true

func _restaurar(foto: Dictionary) -> void:
    var refazer_cats: Array = []
    for chave in MundoDados.CHAVES:
        if foto.has(chave) and ilha.mundo.get(chave) != foto[chave]:
            ilha.mundo[chave] = foto[chave]
            refazer_cats.append(chave)
    _sel = {}
    _rua_atual = []
    _rua_estende = {}
    _reconstruir(refazer_cats)
    modificado = true

func _desfazer_acao() -> void:
    if _desfazer.is_empty():
        _mostrar_aviso("Nada para desfazer.")
        return
    _refazer.append(MundoDados.copiar(ilha.mundo))
    _restaurar(_desfazer.pop_back())
    _mostrar_aviso("Desfeito.")

func _refazer_acao() -> void:
    if _refazer.is_empty():
        _mostrar_aviso("Nada para refazer.")
        return
    _desfazer.append(MundoDados.copiar(ilha.mundo))
    _restaurar(_refazer.pop_back())
    _mostrar_aviso("Refeito.")

func _reconstruir(cats: Array) -> void:
    for c in cats:
        ilha.reconstruir(c)
    if cats.has("ruas"):
        _atualizar_pontos_ruas()
    _atualizar_marca()
    _atualizar_cursor()

func _salvar(avisar: bool) -> bool:
    var ok: bool = MundoDados.salvar(ilha.mundo)
    if ok:
        modificado = false
    if avisar:
        _mostrar_aviso("Mundo salvo." if ok else "Não consegui salvar o mundo.")
    return ok

func _exportar() -> void:
    DirAccess.make_dir_recursive_absolute("res://dados")
    var ok: bool = MundoDados.salvar(ilha.mundo, MundoDados.ARQUIVO_JOGO)
    _mostrar_aviso("Gravado na pasta do jogo: dados/mundo_ilha_principal.json" if ok else "Só dá para gravar na pasta do jogo rodando pelo editor do Godot.")

func _restaurar_padrao(publicado: bool = true) -> void:
    _guardar_desfazer()
    ilha.restaurar_padrao(publicado)
    _sel = {}
    _rua_atual = []
    _atualizar_pontos_ruas()
    _atualizar_marca()
    modificado = false
    _mostrar_aviso(("Mundo do jogo restaurado" if publicado else "Ilha original restaurada") + " (Ctrl+Z desfaz).")

# ---------------------------------------------------------------------------------------------------------------
# geometria de apoio
# ---------------------------------------------------------------------------------------------------------------

## Ponto mais próximo de p sobre uma polilinha (lista de Vector2).
func _ponto_mais_proximo(pts: Array, p: Vector2) -> Dictionary:
    var melhor := {"d": INF, "q": Vector2.ZERO, "seg": -1}
    for i in range(pts.size() - 1):
        var a: Vector2 = pts[i]
        var b: Vector2 = pts[i + 1]
        var ab: Vector2 = b - a
        var t: float = 0.0 if ab.length_squared() < 0.0001 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
        var q: Vector2 = a + ab * t
        var d: float = p.distance_to(q)
        if d < float(melhor["d"]):
            melhor = {"d": d, "q": q, "seg": i}
    return melhor

func _pontos_da_rua(rua: Dictionary) -> Array:
    var pts: Array = []
    for p in rua["pts"]:
        pts.append(Vector2(float(p[0]), float(p[1])))
    return pts

## A rua mais próxima de p: {"d", "q" (ponto na rua), "rua"}.
func _rua_mais_proxima(p: Vector2) -> Dictionary:
    var melhor := {"d": INF, "q": p, "rua": -1}
    var ruas: Array = _lista("ruas")
    for k in ruas.size():
        var r: Dictionary = _ponto_mais_proximo(_pontos_da_rua(ruas[k]), p)
        if float(r["d"]) < float(melhor["d"]):
            melhor = {"d": r["d"], "q": r["q"], "rua": k}
    return melhor

## Tamanho (largura na direção da porta) da construção, para o recuo do ímã.
func _tam_do_tipo(tipo: String) -> Vector3:
    match tipo:
        "armazem":
            return Vector3(9.0, 3.5, 8.0)
        "mercado":
            return Vector3(9.0, 3.5, 7.2)
        "capela":
            return Vector3(9.0, 4.2, 6.0)
    return Vector3(5.25, 3.3, 6.2)

## O ímã: a casa encosta a uma distância certa da rua e vira a porta para ela.
func _ajustar_casa(p: Vector2, tam_x: float, giro_padrao: float) -> Dictionary:
    if _ima:
        var rua: Dictionary = _rua_mais_proxima(p)
        if float(rua["d"]) < ALCANCE_IMA:
            var q: Vector2 = rua["q"]
            var fora: Vector2 = p - q
            if fora.length() < 0.2:
                fora = Vector2(1, 0)
            var novo: Vector2 = q + fora.normalized() * (tam_x * 0.5 + 1.95 + 1.75)
            var para_rua: Vector2 = q - novo
            return {"p": novo, "giro": -atan2(para_rua.y, para_rua.x)}
    return {"p": p, "giro": giro_padrao}

func _altura(p: Vector2) -> float:
    return ilha.altura_local(p.x, p.y)

## Já tem outra construção em cima deste lugar? (ignora a de índice "ignorar")
func _colide_casa(q: Vector2, tam: Vector3, ignorar: int = -1) -> bool:
    var lista: Array = _lista("casas")
    for i in lista.size():
        if i == ignorar:
            continue
        var outra = lista[i]
        var tam_outra: Vector3 = _tam_do_tipo(str(outra.get("tipo", "casa")))
        var minimo: float = maxf(tam.x, tam.z) * 0.5 + maxf(tam_outra.x, tam_outra.z) * 0.5 - 0.8
        if _pos_item(outra).distance_to(q) < minimo:
            return true
    return false

# ---------------------------------------------------------------------------------------------------------------
# colocar
# ---------------------------------------------------------------------------------------------------------------

func _colocar(p: Vector2, duplo: bool) -> void:
    match categoria:
        "casas":
            _colocar_casa(p)
        "ruas":
            _clicar_rua(p, duplo)
        "postes":
            if _altura(p) < 0.7:
                _mostrar_aviso("Poste só em terra firme.")
                return
            _guardar_desfazer()
            _lista("postes").append([p.x, p.y])
            _reconstruir(["postes"])
            _sel = {"cat": "postes", "i": _lista("postes").size() - 1, "v": -1}
            _atualizar_marca()
        "props":
            _colocar_prop(p)
        _:
            if VEGETACAO.has(categoria):
                _guardar_desfazer()
                _pintando = 1
                _ultimo_carimbo = Vector2(1e9, 1e9)
                _carimbar(p, false)

func _colocar_casa(p: Vector2) -> void:
    var tipo: String = TIPOS_CASA[_tipo_casa][0]
    var tam: Vector3 = _tam_do_tipo(tipo)
    var aj: Dictionary = _ajustar_casa(p, tam.x, _giro_atual)
    var q: Vector2 = aj["p"]
    if _altura(q) < 1.0:
        _mostrar_aviso("Aqui é água ou praia baixa demais para construir.")
        return
    if _colide_casa(q, tam):
        _mostrar_aviso("Já tem uma construção aqui. Escolha outro lugar.")
        return
    _guardar_desfazer()
    var casa := {"tipo": tipo, "x": q.x, "z": q.y, "giro": float(aj["giro"])}
    if tipo == "casa":
        casa["w"] = _rng.randf_range(5.0, 5.5)
        casa["h"] = _rng.randf_range(3.0, 3.6)
        casa["d"] = _rng.randf_range(5.8, 6.6)
        casa["cor"] = _rng.randi() % 6
        casa["porta"] = _rng.randi() % 3
    _lista("casas").append(casa)
    var cats: Array = ["casas"]
    if _limpar_ao_construir:
        cats.append_array(_limpar_vegetacao_em(q, maxf(tam.x, tam.z) * 0.5 + 1.2))
    _reconstruir(cats)
    _sel = {"cat": "casas", "i": _lista("casas").size() - 1, "v": -1}
    _atualizar_marca()

func _colocar_prop(p: Vector2) -> void:
    var t: Array = TIPOS_PROP[_tipo_prop]
    if _altura(p) < -1.2:
        _mostrar_aviso("Fundo demais para colocar isso.")
        return
    _guardar_desfazer()
    _lista("props").append({"tipo": t[0], "x": p.x, "z": p.y, "giro": _giro_atual, "var": t[1]})
    _reconstruir(["props"])
    _sel = {"cat": "props", "i": _lista("props").size() - 1, "v": -1}
    _atualizar_marca()

## Ruas: os pontos grudam num ponto de rua que já existe (cruzamentos limpos).
func _prender_em_rua(p: Vector2) -> Vector2:
    var ruas: Array = _lista("ruas")
    var melhor_d: float = 2.6
    var resultado: Vector2 = p
    for rua in ruas:
        var pts: Array = _pontos_da_rua(rua)
        for v in pts:
            var d: float = (v as Vector2).distance_to(p)
            if d < melhor_d:
                melhor_d = d
                resultado = v
    if melhor_d < 2.6:
        return resultado
    var perto: Dictionary = _rua_mais_proxima(p)
    if float(perto["d"]) < 1.6:
        return perto["q"]
    return p

func _clicar_rua(p: Vector2, duplo: bool) -> void:
    if duplo:
        _terminar_rua()
        return
    var q: Vector2 = _prender_em_rua(p)
    if _altura(q) < 0.4:
        _mostrar_aviso("Rua só em terra firme.")
        return
    if _rua_atual.is_empty():
        # Começar na ponta de uma rua existente continua essa rua.
        var ruas: Array = _lista("ruas")
        for k in ruas.size():
            var pts: Array = _pontos_da_rua(ruas[k])
            if pts.size() >= 2:
                if (pts[pts.size() - 1] as Vector2).distance_to(q) < 0.5:
                    _rua_estende = {"i": k, "inicio": false}
                    break
                if (pts[0] as Vector2).distance_to(q) < 0.5:
                    _rua_estende = {"i": k, "inicio": true}
                    break
    if not _rua_atual.is_empty() and (_rua_atual[_rua_atual.size() - 1] as Vector2).distance_to(q) < 0.6:
        return
    _rua_atual.append(q)
    _atualizar_fita()
    _atualizar_pontos_ruas()

func _terminar_rua() -> void:
    if _rua_atual.size() < 2:
        if _rua_atual.size() == 1:
            _mostrar_aviso("Uma rua precisa de pelo menos 2 pontos.")
        _rua_atual = []
        _rua_estende = {}
        _atualizar_fita()
        _atualizar_pontos_ruas()
        return
    _guardar_desfazer()
    var novos: Array = []
    for q in _rua_atual:
        novos.append([(q as Vector2).x, (q as Vector2).y])
    var ruas: Array = _lista("ruas")
    var indice: int = -1
    if not _rua_estende.is_empty():
        var k: int = int(_rua_estende["i"])
        var rua: Dictionary = ruas[k]
        var antigos: Array = rua["pts"]
        if bool(_rua_estende["inicio"]):
            novos.reverse()
            novos.pop_back()                      # o último repete o primeiro ponto antigo
            rua["pts"] = novos + antigos
        else:
            novos.pop_front()
            rua["pts"] = antigos + novos
        indice = k
    else:
        ruas.append({"tipo": TIPOS_RUA[_tipo_rua][0], "pts": novos})
        indice = ruas.size() - 1
    var cats: Array = ["ruas"]
    if _limpar_ao_construir:
        cats.append_array(_limpar_vegetacao_na_rua(_pontos_da_rua(ruas[indice]), 2.4))
    _rua_atual = []
    _rua_estende = {}
    _atualizar_fita()
    _reconstruir(cats)                          # (já refaz as bolinhas das ruas)
    _sel = {"cat": "ruas", "i": indice, "v": -1}
    _atualizar_marca()

# ---------------------------------------------------------------------------------------------------------------
# vegetação: pincel e borracha
# ---------------------------------------------------------------------------------------------------------------

func _tem_obstaculo(p: Vector2) -> bool:
    if float(_rua_mais_proxima(p)["d"]) < 2.5:
        return true
    for c in _lista("casas"):
        var tam: Vector3 = _tam_do_tipo(str(c.get("tipo", "casa")))
        if _pos_item(c).distance_to(p) < maxf(tam.x, tam.z) * 0.5 + 0.8:
            return true
    return false

func _carimbar(centro: Vector2, apagar: bool) -> void:
    _ultimo_carimbo = centro
    var mudadas: Array = []
    if apagar:
        var cats: Array = VEGETACAO if categoria == "limpar" else [categoria]
        for cat in cats:
            var lista: Array = _lista(cat)
            var antes: int = lista.size()
            for i in range(lista.size() - 1, -1, -1):
                if _pos_item(lista[i]).distance_to(centro) <= _raio_pincel:
                    lista.remove_at(i)
            if lista.size() != antes:
                mudadas.append(cat)
        if not mudadas.is_empty():
            _sel = {}
            _reconstruir(mudadas)
        return
    var regra: Dictionary = REGRAS[categoria]
    var lista2: Array = _lista(categoria)
    var quantas: int = clampi(roundi(_raio_pincel * _raio_pincel * 0.10), 1, 16)
    var mudou := false
    for n in quantas:
        var ang: float = _rng.randf() * TAU
        var rr: float = sqrt(_rng.randf()) * _raio_pincel
        var q: Vector2 = centro + Vector2(cos(ang), sin(ang)) * rr
        var h: float = _altura(q)
        if h < float(regra["hmin"]) or h > float(regra["hmax"]):
            continue
        if _tem_obstaculo(q):
            continue
        var livre := true
        for outro in lista2:
            if _pos_item(outro).distance_to(q) < float(regra["dist"]):
                livre = false
                break
        if not livre:
            continue
        if categoria == "coqueiros":
            lista2.append([q.x, q.y, _rng.randi(), _rng.randi() % 3])
        else:
            lista2.append([q.x, q.y, _rng.randi()])
        mudou = true
    if mudou:
        _reconstruir([categoria])

## Tira a vegetação de um círculo (o que a casa nova ocupa). Devolve as categorias que mudaram.
func _limpar_vegetacao_em(p: Vector2, r: float) -> Array:
    var mudadas: Array = []
    for cat in VEGETACAO:
        var lista: Array = _lista(cat)
        var antes: int = lista.size()
        for i in range(lista.size() - 1, -1, -1):
            if _pos_item(lista[i]).distance_to(p) < r:
                lista.remove_at(i)
        if lista.size() != antes:
            mudadas.append(cat)
    return mudadas

func _limpar_vegetacao_na_rua(pts: Array, meia: float) -> Array:
    var mudadas: Array = []
    for cat in VEGETACAO:
        var lista: Array = _lista(cat)
        var antes: int = lista.size()
        for i in range(lista.size() - 1, -1, -1):
            if float(_ponto_mais_proximo(pts, _pos_item(lista[i]))["d"]) < meia:
                lista.remove_at(i)
        if lista.size() != antes:
            mudadas.append(cat)
    return mudadas

# ---------------------------------------------------------------------------------------------------------------
# selecionar, mover, girar, variar, apagar
# ---------------------------------------------------------------------------------------------------------------

## O objeto mais perto de p na categoria atual. Vazio se não houver nenhum ao alcance.
func _achar(cat: String, p: Vector2) -> Dictionary:
    if cat == "ruas":
        var ruas: Array = _lista("ruas")
        var melhor_v := {}
        var melhor_d: float = 3.0
        for k in ruas.size():
            var pts: Array = _pontos_da_rua(ruas[k])
            for j in pts.size():
                var d: float = (pts[j] as Vector2).distance_to(p)
                if d < melhor_d:
                    melhor_d = d
                    melhor_v = {"cat": "ruas", "i": k, "v": j}
        if not melhor_v.is_empty():
            return melhor_v
        var rua: Dictionary = _rua_mais_proxima(p)
        if float(rua["d"]) < 2.4:
            return {"cat": "ruas", "i": int(rua["rua"]), "v": -1}
        return {}
    var alcance: float = 1.6
    match cat:
        "casas":
            alcance = 5.2
        "props":
            alcance = 2.6
        "postes":
            alcance = 1.8
        _:
            if REGRAS.has(cat):
                alcance = float(REGRAS[cat]["pega"])
    var lista: Array = _lista(cat)
    var melhor_i: int = -1
    var melhor_dist: float = alcance
    for i in lista.size():
        var d2: float = _pos_item(lista[i]).distance_to(p)
        if d2 < melhor_dist:
            melhor_dist = d2
            melhor_i = i
    if melhor_i < 0:
        return {}
    return {"cat": cat, "i": melhor_i, "v": -1}

func _selecionar(p: Vector2) -> void:
    var r: Dictionary = _achar(categoria, p)
    _sel = r
    _atualizar_marca()
    # numa rua só se arrasta um ponto (as bolinhas); clicar no meio do trecho só escolhe a rua
    if not r.is_empty() and not (str(r["cat"]) == "ruas" and int(r["v"]) < 0):
        _arrastando = true
        _arrasto_moveu = false
        if str(r["cat"]) == "ruas":
            _preparar_arrasto_rua(int(r["i"]), int(r["v"]))

## Guarda a forma original da rua e a distância (ao longo dela) de cada ponto até o ponto agarrado.
func _preparar_arrasto_rua(i: int, v: int) -> void:
    var pts: Array = _pontos_da_rua(_lista("ruas")[i])
    var acum: Array = [0.0]
    for k in range(1, pts.size()):
        acum.append(float(acum[k - 1]) + (pts[k] as Vector2).distance_to(pts[k - 1]))
    var dist: Array = []
    for k in pts.size():
        dist.append(absf(float(acum[k]) - float(acum[v])))
    _arrasto_rua = {"orig": pts, "dist": dist, "v": v}

func _mover_selecionado(p: Vector2) -> void:
    if _sel.is_empty():
        return
    var cat: String = _sel["cat"]
    var i: int = int(_sel["i"])
    var lista: Array = _lista(cat)
    if i >= lista.size():
        return
    if cat == "ruas":
        var rua: Dictionary = lista[i]
        var v: int = int(_sel["v"])
        if v >= 0 and not _arrasto_rua.is_empty():
            var orig: Array = _arrasto_rua["orig"]
            var dist: Array = _arrasto_rua["dist"]
            var delta: Vector2 = p - (orig[v] as Vector2)
            for k in orig.size():
                var peso: float = 1.0
                if k != v:
                    peso = 0.0
                    if _macio and float(dist[k]) < RAIO_MACIO:
                        peso = 0.5 * (1.0 + cos(PI * float(dist[k]) / RAIO_MACIO))
                var base: Vector2 = orig[k]
                rua["pts"][k] = [base.x + delta.x * peso, base.y + delta.y * peso]
        return
    var item = lista[i]
    var q: Vector2 = p
    if cat == "casas":
        var tam: Vector3 = _tam_do_tipo(str(item.get("tipo", "casa")))
        var aj: Dictionary = _ajustar_casa(p, tam.x, float(item["giro"]))
        q = aj["p"]
        item["giro"] = float(aj["giro"])
    if item is Dictionary:
        item["x"] = q.x
        item["z"] = q.y
    else:
        item[0] = q.x
        item[1] = q.y

func _depois_de_mover() -> void:
    if _sel.is_empty():
        return
    var cat: String = _sel["cat"]
    var cats: Array = [cat]
    if cat == "casas" and _limpar_ao_construir:
        var item: Dictionary = _lista("casas")[int(_sel["i"])]
        var tam: Vector3 = _tam_do_tipo(str(item.get("tipo", "casa")))
        cats.append_array(_limpar_vegetacao_em(_pos_item(item), maxf(tam.x, tam.z) * 0.5 + 1.2))
    elif cat == "ruas" and _limpar_ao_construir:
        cats.append_array(_limpar_vegetacao_na_rua(_pontos_da_rua(_lista("ruas")[int(_sel["i"])]), 2.4))
    _reconstruir(cats)

func _girar(passo: float) -> void:
    if _sel.is_empty():
        _giro_atual = fposmod(_giro_atual + passo, TAU)
        _atualizar_cursor()
        return
    var cat: String = _sel["cat"]
    if cat != "casas" and cat != "props":
        return
    _guardar_desfazer()
    var item: Dictionary = _lista(cat)[int(_sel["i"])]
    item["giro"] = fposmod(float(item["giro"]) + passo, TAU)
    _reconstruir([cat])

func _variar() -> void:
    if _sel.is_empty():
        return
    var cat: String = _sel["cat"]
    var i: int = int(_sel["i"])
    _guardar_desfazer()
    var item = _lista(cat)[i]
    match cat:
        "casas":
            if str(item.get("tipo", "casa")) == "casa":
                item["cor"] = (int(item.get("cor", 0)) + 1) % 6
                item["porta"] = (int(item.get("porta", 0)) + 1) % 3
        "ruas":
            item["tipo"] = "areia" if str(item.get("tipo", "areia")) == "calcada" else "calcada"
        "props":
            item["var"] = 1 - int(item.get("var", 0))
        "coqueiros":
            item[3] = (int(item[3]) + 1) % 3
        "postes":
            pass
        _:
            item[2] = _rng.randi()
    _reconstruir([cat])

func _apagar(p: Vector2) -> void:
    if VEGETACAO.has(categoria):
        _guardar_desfazer()
        _pintando = 2
        _ultimo_carimbo = Vector2(1e9, 1e9)
        _carimbar(p, true)
        return
    var r: Dictionary = _achar(categoria, p)
    if r.is_empty():
        return
    _sel = r
    _apagar_selecionado()

func _apagar_selecionado() -> void:
    if _sel.is_empty():
        return
    var cat: String = _sel["cat"]
    var i: int = int(_sel["i"])
    var lista: Array = _lista(cat)
    if i >= lista.size():
        _sel = {}
        return
    _guardar_desfazer()
    if cat == "ruas":
        var rua: Dictionary = lista[i]
        var v: int = int(_sel["v"])
        if v >= 0 and rua["pts"].size() > 2:
            rua["pts"].remove_at(v)
        else:
            lista.remove_at(i)
    else:
        lista.remove_at(i)
    _sel = {}
    _reconstruir([cat])

# ---------------------------------------------------------------------------------------------------------------
# visuais 3D do editor
# ---------------------------------------------------------------------------------------------------------------

func _material_aviso(cor: Color, sem_profundidade: bool = true) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = cor
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    if cor.a < 1.0:
        m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.no_depth_test = sem_profundidade
    m.render_priority = 20
    return m

func _construir_visuais() -> void:
    _visuais = Node3D.new()
    _visuais.name = "ConstrutorVisuais"
    ilha.add_child(_visuais)
    var anel := TorusMesh.new()
    anel.inner_radius = 0.93
    anel.outer_radius = 1.0
    anel.rings = 40
    anel.ring_segments = 6
    _cursor = MeshInstance3D.new()
    _cursor.mesh = anel
    _cursor.material_override = _material_aviso(Color(1.0, 1.0, 1.0, 0.9))
    _cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _visuais.add_child(_cursor)
    _fantasma = MeshInstance3D.new()
    _fantasma.mesh = BoxMesh.new()
    _fantasma.material_override = _material_aviso(Color(0.45, 0.95, 0.55, 0.45), false)
    _fantasma.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _fantasma.visible = false
    _visuais.add_child(_fantasma)
    _seta = MeshInstance3D.new()
    var caixa_seta := BoxMesh.new()
    caixa_seta.size = Vector3(1.8, 0.14, 0.7)
    _seta.mesh = caixa_seta
    _seta.material_override = _material_aviso(Color(1.0, 0.62, 0.15, 0.95))
    _seta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _seta.visible = false
    _visuais.add_child(_seta)
    var cone := CylinderMesh.new()
    cone.top_radius = 0.9
    cone.bottom_radius = 0.0
    cone.height = 2.2
    cone.radial_segments = 8
    _marca = MeshInstance3D.new()
    _marca.mesh = cone
    _marca.material_override = _material_aviso(Color(1.0, 0.88, 0.15, 1.0))
    _marca.scale = Vector3(1.7, 1.7, 1.7)
    _marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _marca.visible = false
    _visuais.add_child(_marca)
    _anel_marca = MeshInstance3D.new()
    _anel_marca.mesh = anel
    _anel_marca.material_override = _material_aviso(Color(1.0, 0.88, 0.15, 1.0))
    _anel_marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _anel_marca.visible = false
    _visuais.add_child(_anel_marca)
    _fita = MeshInstance3D.new()
    _fita.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _visuais.add_child(_fita)
    _pontos_rua = MultiMeshInstance3D.new()
    _pontos_rua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _visuais.add_child(_pontos_rua)

## O círculo que acompanha o mouse (e a casa/objeto fantasma na ferramenta Colocar).
func _atualizar_cursor() -> void:
    if _cursor == null:
        return
    _fantasma.visible = false
    _seta.visible = false
    if _hover == null:
        _cursor.visible = false
        return
    var p: Vector2 = _hover
    var h: float = maxf(_altura(p), 0.0)
    _cursor.visible = true
    var raio: float = 1.2
    var cor := Color(1, 1, 1, 0.9)
    if _categoria_e_pincel():
        raio = _raio_pincel
        cor = Color(1.0, 0.45, 0.35, 0.95) if (categoria == "limpar" or ferramenta == "apagar") else Color(0.55, 1.0, 0.55, 0.95)
    elif ferramenta == "apagar":
        cor = Color(1.0, 0.4, 0.35, 0.95)
    elif ferramenta == "selecionar":
        cor = Color(0.5, 0.8, 1.0, 0.95)
    (_cursor.material_override as StandardMaterial3D).albedo_color = cor
    _cursor.position = Vector3(p.x, h + 0.25, p.y)
    _cursor.scale = Vector3(raio, 1.0, raio)
    if ferramenta == "colocar" and categoria == "casas":
        var tipo: String = TIPOS_CASA[_tipo_casa][0]
        var tam: Vector3 = _tam_do_tipo(tipo)
        var aj: Dictionary = _ajustar_casa(p, tam.x, _giro_atual)
        var q: Vector2 = aj["p"]
        var giro: float = float(aj["giro"])
        _posicionar_fantasma(q, giro, tam)
        var ocupado: bool = _colide_casa(q, tam) or _altura(q) < 1.0
        (_fantasma.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.35, 0.30, 0.5) if ocupado else Color(0.45, 0.95, 0.55, 0.45)
        _cursor.position = Vector3(q.x, maxf(_altura(q), 0.0) + 0.25, q.y)
    elif ferramenta == "colocar" and categoria == "props":
        _posicionar_fantasma(p, _giro_atual, Vector3(2.0, 1.0, 1.0))
    elif ferramenta == "colocar" and categoria == "postes":
        _posicionar_fantasma(p, 0.0, Vector3(0.3, 4.2, 0.3))
    elif ferramenta == "selecionar" and _arrastando and not _sel.is_empty() and _sel["cat"] == "casas":
        var item: Dictionary = _lista("casas")[int(_sel["i"])]
        _posicionar_fantasma(_pos_item(item), float(item["giro"]), _tam_do_tipo(str(item.get("tipo", "casa"))))
    if _rua_atual.size() > 0:
        _atualizar_fita()

func _posicionar_fantasma(q: Vector2, giro: float, tam: Vector3) -> void:
    var h: float = maxf(_altura(q), 0.0)
    (_fantasma.mesh as BoxMesh).size = tam
    _fantasma.position = Vector3(q.x, h + tam.y * 0.5, q.y)
    _fantasma.rotation.y = giro
    _fantasma.visible = true
    if categoria == "casas":
        _seta.visible = true
        _seta.position = Vector3(q.x, h + 0.35, q.y) + Vector3(cos(giro), 0.0, -sin(giro)) * (tam.x * 0.5 + 1.3)
        _seta.rotation.y = giro

## Marca amarela sobre o objeto escolhido.
func _atualizar_marca() -> void:
    if _marca == null:
        return
    if _sel.is_empty():
        _marca.visible = false
        _anel_marca.visible = false
        _info.text = ""
        return
    var cat: String = _sel["cat"]
    var i: int = int(_sel["i"])
    var lista: Array = _lista(cat)
    if i >= lista.size():
        _sel = {}
        _marca.visible = false
        _anel_marca.visible = false
        return
    var item = lista[i]
    var p: Vector2
    var altura_marca: float = 6.0
    var anel: float = 1.6
    var descricao := ""
    match cat:
        "ruas":
            var pts: Array = _pontos_da_rua(item)
            var v: int = int(_sel["v"])
            p = pts[clampi(v, 0, pts.size() - 1)] if v >= 0 else pts[pts.size() / 2]
            altura_marca = 3.0
            descricao = "Rua %s · %d pontos%s" % ["de pedra" if str(item["tipo"]) == "calcada" else "de areia", pts.size(), " · ponto %d" % (v + 1) if v >= 0 else ""]
        "casas":
            p = _pos_item(item)
            altura_marca = 9.5
            anel = 4.0
            descricao = "%s · giro %d°" % [str(item.get("tipo", "casa")).capitalize(), roundi(rad_to_deg(float(item["giro"])))]
        "postes":
            p = _pos_item(item)
            altura_marca = 7.0
            descricao = "Poste de luz"
        "props":
            p = _pos_item(item)
            altura_marca = 4.5
            anel = 2.2
            descricao = "%s · giro %d°" % [str(item["tipo"]).capitalize(), roundi(rad_to_deg(float(item["giro"])))]
        _:
            p = _pos_item(item)
            altura_marca = float(REGRAS[cat]["marca"]) if REGRAS.has(cat) else 6.0
            descricao = cat.capitalize()
    var h: float = maxf(_altura(p), 0.0)
    _marca.visible = true
    _marca.position = Vector3(p.x, h + altura_marca + 1.1, p.y)
    _anel_marca.visible = true
    _anel_marca.position = Vector3(p.x, h + 0.3, p.y)
    _anel_marca.scale = Vector3(anel, 1.0, anel)
    _info.text = "Selecionado: %s" % descricao

## Prévia da rua que está sendo desenhada (fita laranja) com um trecho até o mouse.
func _atualizar_fita() -> void:
    if _fita == null:
        return
    if _rua_atual.is_empty():
        _fita.mesh = null
        return
    var pts: Array = _rua_atual.duplicate()
    if _hover != null:
        pts.append(_prender_em_rua(_hover))
    if pts.size() < 2:
        _fita.mesh = null
        return
    var im := ImmediateMesh.new()
    var vertices := PackedVector3Array()
    for i in range(pts.size() - 1):
        var a: Vector2 = pts[i]
        var b: Vector2 = pts[i + 1]
        var dist: float = a.distance_to(b)
        if dist < 0.05:
            continue
        var n: int = maxi(1, ceili(dist / 1.5))
        var lado: Vector2 = Vector2(-(b - a).y, (b - a).x).normalized() * 0.9
        for k in n:
            var p0: Vector2 = a.lerp(b, float(k) / n)
            var p1: Vector2 = a.lerp(b, float(k + 1) / n)
            var v0 := Vector3(p0.x, _altura(p0) + 0.45, p0.y)
            var v1 := Vector3(p1.x, _altura(p1) + 0.45, p1.y)
            var l := Vector3(lado.x, 0.0, lado.y)
            vertices.append_array(PackedVector3Array([v0 - l, v0 + l, v1 + l, v0 - l, v1 + l, v1 - l]))
    if vertices.is_empty():
        _fita.mesh = null
        return
    im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
    for v in vertices:
        im.surface_add_vertex(v)
    im.surface_end()
    _fita.mesh = im
    _fita.material_override = _material_aviso(Color(1.0, 0.6, 0.15, 0.85))

## Bolinhas laranja em todos os pontos das ruas (só enquanto a categoria é Ruas): são o que se agarra para mover.
func _atualizar_pontos_ruas() -> void:
    if _pontos_rua == null:
        return
    if categoria != "ruas":
        _pontos_rua.multimesh = null
        return
    var todos: Array = []
    for rua in _lista("ruas"):
        for p in rua["pts"]:
            todos.append(Vector2(float(p[0]), float(p[1])))
    for q in _rua_atual:
        todos.append(q)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var esfera := SphereMesh.new()
    esfera.radius = 0.5
    esfera.height = 1.0
    esfera.radial_segments = 8
    esfera.rings = 4
    mm.mesh = esfera
    mm.instance_count = todos.size()
    for i in todos.size():
        var q2: Vector2 = todos[i]
        mm.set_instance_transform(i, Transform3D(Basis(), Vector3(q2.x, maxf(_altura(q2), 0.0) + 0.55, q2.y)))
    _pontos_rua.multimesh = mm
    _pontos_rua.material_override = _material_aviso(Color(1.0, 0.55, 0.12, 1.0))

# ---------------------------------------------------------------------------------------------------------------
# interface
# ---------------------------------------------------------------------------------------------------------------

func _botao(texto: String, ao_clicar: Callable, grupo: ButtonGroup = null) -> Button:
    var b := Button.new()
    b.text = texto
    b.focus_mode = Control.FOCUS_NONE
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT if grupo != null else HORIZONTAL_ALIGNMENT_CENTER
    if grupo != null:
        b.toggle_mode = true
        b.button_group = grupo
    b.pressed.connect(ao_clicar)
    return b

func _estilo(cor: Color) -> StyleBoxFlat:
    var st := StyleBoxFlat.new()
    st.bg_color = cor
    st.set_corner_radius_all(10)
    st.content_margin_left = 12.0
    st.content_margin_right = 12.0
    st.content_margin_top = 10.0
    st.content_margin_bottom = 10.0
    return st

func _construir_interface() -> void:
    _ui = CanvasLayer.new()
    _ui.layer = 30
    add_child(_ui)
    _painel = PanelContainer.new()
    _painel.add_theme_stylebox_override("panel", _estilo(Color(0.04, 0.10, 0.14, 0.93)))
    _painel.position = Vector2(10, 10)
    _painel.custom_minimum_size = Vector2(250, 0)
    _painel.mouse_filter = Control.MOUSE_FILTER_STOP
    _ui.add_child(_painel)
    var coluna := VBoxContainer.new()
    coluna.add_theme_constant_override("separation", 5)
    _painel.add_child(coluna)

    var titulo := Label.new()
    titulo.text = "MODO CONSTRUTOR"
    titulo.add_theme_font_size_override("font_size", 19)
    coluna.add_child(titulo)
    coluna.add_child(_rotulo_pequeno("Tab sai e guarda · Ctrl+S salva"))
    coluna.add_child(HSeparator.new())

    coluna.add_child(_rotulo_pequeno("O QUE CONSTRUIR"))
    var grupo_cat := ButtonGroup.new()
    var grade := GridContainer.new()
    grade.columns = 2
    grade.add_theme_constant_override("h_separation", 4)
    grade.add_theme_constant_override("v_separation", 4)
    for c in CATEGORIAS:
        var id: String = c[0]
        var b := _botao(c[1], func(): _escolher_categoria(id), grupo_cat)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _botoes_cat[id] = b
        grade.add_child(b)
    coluna.add_child(grade)
    coluna.add_child(HSeparator.new())

    coluna.add_child(_rotulo_pequeno("FERRAMENTA"))
    var linha := HBoxContainer.new()
    var grupo_f := ButtonGroup.new()
    for f in [["colocar", "Colocar (B)"], ["selecionar", "Mover (V)"], ["apagar", "Apagar (X)"]]:
        var nome: String = f[0]
        var bf := _botao(f[1], func(): _escolher_ferramenta(nome), grupo_f)
        bf.alignment = HORIZONTAL_ALIGNMENT_CENTER
        bf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _botoes_ferr[nome] = bf
        linha.add_child(bf)
    coluna.add_child(linha)

    _tipo_opcao = OptionButton.new()
    _tipo_opcao.focus_mode = Control.FOCUS_NONE
    _tipo_opcao.item_selected.connect(_ao_escolher_tipo)
    coluna.add_child(_tipo_opcao)

    _linha_pincel = HBoxContainer.new()
    _rotulo_pincel = Label.new()
    _rotulo_pincel.text = "Pincel: %d m" % roundi(_raio_pincel)
    _linha_pincel.add_child(_rotulo_pincel)
    var menos := _botao("−", func(): _mudar_pincel(-2.0))
    var mais := _botao("+", func(): _mudar_pincel(2.0))
    _linha_pincel.add_child(menos)
    _linha_pincel.add_child(mais)
    coluna.add_child(_linha_pincel)

    _check_ima = CheckButton.new()
    _check_ima.text = "Ímã na rua"
    _check_ima.button_pressed = _ima
    _check_ima.focus_mode = Control.FOCUS_NONE
    _check_ima.toggled.connect(func(v: bool):
        _ima = v
        _atualizar_cursor())
    coluna.add_child(_check_ima)
    _check_macio = CheckButton.new()
    _check_macio.text = "Rua macia (puxa vizinhos)"
    _check_macio.button_pressed = _macio
    _check_macio.focus_mode = Control.FOCUS_NONE
    _check_macio.toggled.connect(func(v: bool):
        _macio = v)
    coluna.add_child(_check_macio)
    _check_limpar = CheckButton.new()
    _check_limpar.text = "Tirar árvores do caminho"
    _check_limpar.button_pressed = _limpar_ao_construir
    _check_limpar.focus_mode = Control.FOCUS_NONE
    _check_limpar.toggled.connect(func(v: bool):
        _limpar_ao_construir = v)
    coluna.add_child(_check_limpar)
    coluna.add_child(HSeparator.new())

    var barra := PanelContainer.new()
    barra.add_theme_stylebox_override("panel", _estilo(Color(0.04, 0.10, 0.14, 0.93)))
    barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    barra.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    barra.offset_right = -10.0
    barra.offset_top = 10.0
    barra.mouse_filter = Control.MOUSE_FILTER_STOP
    _ui.add_child(barra)
    var linha_barra := HBoxContainer.new()
    linha_barra.add_theme_constant_override("separation", 6)
    barra.add_child(linha_barra)
    linha_barra.add_child(_botao("Desfazer (Ctrl+Z)", _desfazer_acao))
    linha_barra.add_child(_botao("Refazer (Ctrl+Y)", _refazer_acao))
    linha_barra.add_child(_botao("Salvar (Ctrl+S)", func(): _salvar(true)))
    linha_barra.add_child(_botao("Gravar na pasta do jogo", _exportar))
    linha_barra.add_child(_botao("Mundo do jogo", func(): _restaurar_padrao(true)))
    linha_barra.add_child(_botao("Ilha original", func(): _restaurar_padrao(false)))
    linha_barra.add_child(_botao("Sair (Tab)", fechar))

    _info = Label.new()
    _info.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
    _info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _info.custom_minimum_size = Vector2(226, 0)
    coluna.add_child(_info)
    coluna.add_child(HSeparator.new())
    _estado = _rotulo_pequeno("")
    _estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _estado.custom_minimum_size = Vector2(226, 0)
    _estado.add_theme_font_size_override("font_size", 11)
    coluna.add_child(_estado)

    var faixa := PanelContainer.new()
    faixa.add_theme_stylebox_override("panel", _estilo(Color(0.02, 0.06, 0.09, 0.80)))
    faixa.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    faixa.offset_left = 272.0
    faixa.offset_right = -10.0
    faixa.offset_top = -44.0
    faixa.offset_bottom = -10.0
    faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _ui.add_child(faixa)
    _dica = Label.new()
    _dica.add_theme_font_size_override("font_size", 15)
    _dica.add_theme_color_override("font_color", Color(0.93, 0.95, 0.85))
    _dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
    faixa.add_child(_dica)

    _aviso = Label.new()
    _aviso.add_theme_font_size_override("font_size", 20)
    _aviso.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
    _aviso.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
    _aviso.add_theme_constant_override("shadow_offset_x", 2)
    _aviso.add_theme_constant_override("shadow_offset_y", 2)
    _aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
    _aviso.offset_left = -300.0
    _aviso.offset_right = 300.0
    _aviso.offset_top = 78.0
    _aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _aviso.modulate.a = 0.0
    _ui.add_child(_aviso)

func _rotulo_pequeno(texto: String) -> Label:
    var l := Label.new()
    l.text = texto
    l.add_theme_font_size_override("font_size", 13)
    l.add_theme_color_override("font_color", Color(0.60, 0.81, 0.82))
    return l

func _mostrar_aviso(texto: String) -> void:
    if _aviso == null:
        return
    _aviso.text = texto
    _aviso_tempo = 3.5
    _aviso.modulate.a = 1.0
