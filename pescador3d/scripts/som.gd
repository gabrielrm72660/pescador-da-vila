extends Node
## Som do jogo: mar e vento sempre; motor e água no casco conforme a velocidade; uma onda quebrando de vez
## em quando; efeitos da pesca. Quatro volumes (geral, ambiente, barco, efeitos), ajustados no menu e
## guardados em user://pescador.cfg. Os arquivos ficam em assets/sons/; se algum faltar, o jogo segue.

signal volumes_mudaram

const PASTA := "res://assets/sons/"
const ARQUIVO_CONFIG := "user://pescador.cfg"
const ARQUIVO_ANTIGO := "user://mar_aberto.cfg"      # de quando o jogo se chamava Mar Aberto
const GRUPOS := ["geral", "ambiente", "barco", "efeitos"]
const NOME_GRUPO := {"geral": "Geral", "ambiente": "Mar e vento", "barco": "Motor e casco", "efeitos": "Efeitos"}
const CANAL := {"geral": "Master", "ambiente": "Ambiente", "barco": "Barco", "efeitos": "Efeitos"}

var barco: Node3D
var navegando: bool = false          # falso no menu e na pausa: o motor cala
var volumes: Dictionary = {"geral": 0.8, "ambiente": 0.8, "barco": 0.8, "efeitos": 0.8}
var _mar: AudioStreamPlayer
var _vento: AudioStreamPlayer
var _agua: AudioStreamPlayer
var _motor: AudioStreamPlayer
var _avulsos: Dictionary = {}
var _prox_onda: float = 9.0

func _ready() -> void:
    for grupo in GRUPOS:                                     # um canal de áudio por grupo, todos saindo no geral
        if AudioServer.get_bus_index(CANAL[grupo]) == -1:
            AudioServer.add_bus()
            AudioServer.set_bus_name(AudioServer.bus_count - 1, CANAL[grupo])
            AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
    _carregar_config()
    barco = get_node_or_null("../Barco")
    _mar = _laco("mar", -10.0, "ambiente")
    _vento = _laco("vento", -19.0, "ambiente")
    _agua = _laco("agua_casco", -60.0, "barco")
    _motor = _laco("motor_diesel", -60.0, "barco")
    for nome in ["onda"]:
        _guardar_avulso(nome, "ambiente")
    for nome in ["pesca_lancar", "aviso", "peixe"]:
        _guardar_avulso(nome, "efeitos")

func _guardar_avulso(nome: String, grupo: String) -> void:
    var p := _tocador(nome, -8.0, grupo)
    if p != null:
        _avulsos[nome] = p

func _tocador(nome: String, db: float, grupo: String) -> AudioStreamPlayer:
    var caminho := PASTA + nome + ".ogg"
    if not ResourceLoader.exists(caminho):
        push_warning("Som não encontrado: " + caminho)
        return null
    var p := AudioStreamPlayer.new()
    p.stream = load(caminho)
    p.volume_db = db
    p.bus = CANAL[grupo]
    add_child(p)
    return p

func _laco(nome: String, db: float, grupo: String) -> AudioStreamPlayer:
    var p := _tocador(nome, db, grupo)
    if p != null:
        if p.stream is AudioStreamOggVorbis:
            p.stream.loop = true
        p.play()
    return p

## Toca um som avulso ("pesca_lancar", "aviso", "peixe"...).
func tocar(nome: String, db: float = -8.0, tom: float = 1.0) -> void:
    var p: AudioStreamPlayer = _avulsos.get(nome)
    if p != null:
        p.volume_db = db
        p.pitch_scale = tom
        p.play()

# ------------------------------------------------------------------ volumes

## Ajusta um dos quatro volumes (0 a 1) e guarda a escolha.
func definir_volume(grupo: String, valor: float, guardar: bool = true) -> void:
    if not volumes.has(grupo):
        return
    volumes[grupo] = clampf(valor, 0.0, 1.0)
    var canal := AudioServer.get_bus_index(CANAL[grupo])
    if canal == -1:
        return
    # o ouvido não é linear: metade do controle soa como "metade do volume" com esta curva
    AudioServer.set_bus_volume_db(canal, linear_to_db(maxf(pow(volumes[grupo], 1.6), 0.0001)))
    if grupo != "geral":
        AudioServer.set_bus_mute(canal, volumes[grupo] <= 0.0)
    elif volumes[grupo] > 0.0 and guardar:
        AudioServer.set_bus_mute(canal, false)               # mexer no geral tira o mudo da tecla M
    if guardar:
        _salvar_config()
        volumes_mudaram.emit()

func mudo() -> bool:
    return AudioServer.is_bus_mute(AudioServer.get_bus_index("Master"))

func alternar_mudo() -> bool:
    var mestre := AudioServer.get_bus_index("Master")
    AudioServer.set_bus_mute(mestre, not AudioServer.is_bus_mute(mestre))
    volumes_mudaram.emit()
    return AudioServer.is_bus_mute(mestre)

func _carregar_config() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(ARQUIVO_CONFIG) == OK or cfg.load(ARQUIVO_ANTIGO) == OK:
        for grupo in GRUPOS:
            var v = cfg.get_value("som", grupo, volumes[grupo])
            if typeof(v) in [TYPE_FLOAT, TYPE_INT]:
                volumes[grupo] = clampf(float(v), 0.0, 1.0)
    for grupo in GRUPOS:
        definir_volume(grupo, volumes[grupo], false)

func _salvar_config() -> void:
    var cfg := ConfigFile.new()
    cfg.load(ARQUIVO_CONFIG)                                 # mantém o que mais houver no arquivo
    for grupo in GRUPOS:
        cfg.set_value("som", grupo, volumes[grupo])
    cfg.save(ARQUIVO_CONFIG)

# ------------------------------------------------------------------ mistura conforme o barco

func _process(delta: float) -> void:
    var fracao: float = 0.0
    if barco != null:
        fracao = clampf(absf(barco.velocidade) / barco.velocidade_maxima, 0.0, 1.0)
    var suave: float = 1.0 - exp(-4.0 * delta)
    if _motor != null:                                       # marcha lenta baixinha, acelera com o barco
        var com_diesel: bool = barco == null or barco.combustivel > 0.0        # sem combustível o motor cala
        var alvo_motor: float = lerpf(-17.0, -5.0, fracao) if (navegando and com_diesel) else -60.0
        _motor.volume_db = lerpf(_motor.volume_db, alvo_motor, suave)
        _motor.pitch_scale = lerpf(_motor.pitch_scale, 0.88 + 0.42 * fracao, suave)
    if _agua != null:                                        # água correndo pelo casco
        var alvo_agua: float = lerpf(-24.0, 0.0, sqrt(fracao)) if fracao > 0.03 else -60.0
        _agua.volume_db = lerpf(_agua.volume_db, alvo_agua, suave)
        _agua.pitch_scale = lerpf(_agua.pitch_scale, 0.9 + 0.2 * fracao, suave)
    if _vento != null:                                       # mais vento no rosto quando corre
        _vento.volume_db = lerpf(_vento.volume_db, lerpf(-19.0, -13.0, fracao), suave)

    _prox_onda -= delta
    if _prox_onda <= 0.0:
        _prox_onda = randf_range(11.0, 26.0)
        tocar("onda", randf_range(-22.0, -16.0), randf_range(0.8, 1.05))
