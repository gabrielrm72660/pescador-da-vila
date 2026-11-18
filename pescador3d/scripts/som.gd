extends Node
## Som do jogo (seis volumes: geral, mar, vento, chuva, barco, efeitos): ressaca costeira, mar com respiracao lenta e vento em rajadas espaçadas; motor e água no casco conforme a velocidade; uma onda quebrando de vez
## em quando; efeitos da pesca. Volumes ajustados em Opções > Áudio e
## guardados em user://pescador.cfg. Os arquivos ficam em assets/sons/; se algum faltar, o jogo segue.
## v0.5.10: mar, ondas (3 variações), água no casco, motor diesel, alerta (sino de bordo) e chuva refeitos
## por síntese (ferramentas/sons/gerar_*.py). O mar.ogg já tem as ondas passando, então o "respiro" do código ficou leve.

signal volumes_mudaram

const PASTA := "res://assets/sons/"
const ARQUIVO_CONFIG := "user://pescador.cfg"
const ARQUIVO_ANTIGO := "user://mar_aberto.cfg"      # de quando o jogo se chamava Mar Aberto
const GRUPOS := ["geral", "mar", "vento", "chuva", "barco", "efeitos"]
const NOME_GRUPO := {"geral": "Geral", "mar": "Mar e ondas", "vento": "Vento", "chuva": "Chuva e trovões", "barco": "Motor e casco", "efeitos": "Efeitos"}
const CANAL := {"geral": "Master", "mar": "Mar", "vento": "Vento", "chuva": "Chuva", "barco": "Barco", "efeitos": "Efeitos"}

var barco: Node3D
var oceano: Node3D
var navegando: bool = false          # falso no menu e na pausa: o motor cala
var volumes: Dictionary = {"geral": 0.8, "mar": 0.8, "vento": 0.8, "chuva": 0.8, "barco": 0.8, "efeitos": 0.8}
var _mar: AudioStreamPlayer
var _vento: AudioStreamPlayer
var _agua: AudioStreamPlayer
var _motor: AudioStreamPlayer
var _chuva: AudioStreamPlayer
var _avulsos: Dictionary = {}
var _proximo_trovao: float = 19.0
var _prox_onda: float = 9.0
var _tempo_ambiente: float = 0.0  # ciclo lento, evita volume de ambiente mecanicamente constante
# O arquivo vento.ogg roda em laco, mas fica inaudivel entre rajadas.
# Dessa maneira nao ha corte seco no meio do arquivo e o vento deixa de dominar o som.
var _proxima_rajada: float = 15.0
var _tempo_rajada: float = 0.0
var _duracao_rajada: float = 0.0
var _pico_rajada_db: float = -36.0

func _ready() -> void:
    for grupo in GRUPOS:                                     # um canal de áudio por grupo, todos saindo no geral
        if AudioServer.get_bus_index(CANAL[grupo]) == -1:
            AudioServer.add_bus()
            AudioServer.set_bus_name(AudioServer.bus_count - 1, CANAL[grupo])
            AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
    _carregar_config()
    barco = get_node_or_null("../Barco")
    oceano = get_node_or_null("../Oceano")
    _mar = _laco("mar", -14.0, "mar")
    _vento = _laco("vento", -60.0, "vento")
    _proxima_rajada = randf_range(12.0, 25.0)
    _agua = _laco("agua_casco", -60.0, "barco")
    _motor = _laco("motor_diesel", -60.0, "barco")
    _chuva = _laco("chuva", -60.0, "chuva")
    _proximo_trovao = randf_range(18.0, 36.0)
    _guardar_avulso("onda", "mar")
    _guardar_avulso("onda_2", "mar")
    _guardar_avulso("onda_3", "mar")
    _guardar_avulso("trovao", "chuva")
    for nome in ["pesca_lancar", "aviso", "peixe", "acerto", "perfeito", "estalo", "tensao", "captura"]:
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
        AudioServer.set_bus_mute(canal, false)               # mexer no geral tira o mudo geral
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
        var antigo = cfg.get_value("som", "ambiente", -1.0) if cfg.has_section_key("som", "ambiente") else -1.0   # até a 0.5.5 era um só ("ambiente")
        if typeof(antigo) in [TYPE_FLOAT, TYPE_INT] and float(antigo) >= 0.0 and not cfg.has_section_key("som", "mar"):
            for grupo in ["mar", "vento", "chuva"]:
                volumes[grupo] = clampf(float(antigo), 0.0, 1.0)
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
    var mar_agitado: float = oceano.intensidade() if oceano != null and oceano.has_method("intensidade") else 0.0
    _tempo_ambiente += delta
    var proximidade_costa: float = 0.0
    var mundo: Node = get_parent()
    if barco != null and mundo.has_method("distancia_da_costa"):
        var distancia: float = maxf(0.0, mundo.distancia_da_costa(barco.global_position))
        proximidade_costa = 1.0 - smoothstep(30.0, 170.0, distancia)
    var suave: float = 1.0 - exp(-2.5 * delta)
    if _mar != null:
        # O respiro das ondas e lento; pertinho da praia o ambiente cresce um pouco.
        var ciclo: float = 0.68 * sin(_tempo_ambiente * 0.21) + 0.32 * sin(_tempo_ambiente * 0.37 + 1.2)
        var alvo_mar: float = lerpf(-15.0, -10.0, mar_agitado) + 2.2 * proximidade_costa + 0.5 * ciclo
        _mar.volume_db = lerpf(_mar.volume_db, alvo_mar, suave)
    if _motor != null:                                       # marcha lenta baixinha, acelera com o barco
        var com_diesel: bool = barco == null or barco.combustivel > 0.0        # sem combustível o motor cala
        var alvo_motor: float = lerpf(-18.0, -7.5, fracao) if (navegando and com_diesel) else -60.0
        _motor.volume_db = lerpf(_motor.volume_db, alvo_motor, suave)
        _motor.pitch_scale = lerpf(_motor.pitch_scale, 0.88 + 0.42 * fracao, suave)
    if _agua != null:                                        # água correndo pelo casco
        var alvo_agua: float = lerpf(-26.0, -10.5, sqrt(fracao)) if fracao > 0.03 else -60.0
        alvo_agua += 2.0 * mar_agitado if fracao > 0.03 else 0.0
        _agua.volume_db = lerpf(_agua.volume_db, alvo_agua, suave)
        _agua.pitch_scale = lerpf(_agua.pitch_scale, 0.96 + 0.07 * fracao, suave)
    if _vento != null:
        # Rajadas calmas e intermitentes: 6 a 11 s, seguidas de 25 a 55 s de descanso.
        # No temporal o descanso encurta um pouco, mas sem virar vento continuo.
        var alvo_vento: float = -60.0
        if _duracao_rajada > 0.0:
            _tempo_rajada += delta
            var entrada: float = smoothstep(0.0, 2.3, _tempo_rajada)
            var saida: float = 1.0 - smoothstep(_duracao_rajada - 3.0, _duracao_rajada, _tempo_rajada)
            var envelope: float = clampf(entrada * saida, 0.0, 1.0)
            alvo_vento = lerpf(-60.0, _pico_rajada_db + 1.5 * fracao, envelope)
            if _tempo_rajada >= _duracao_rajada:
                _duracao_rajada = 0.0
                _proxima_rajada = randf_range(25.0, 55.0) * lerpf(1.0, 0.72, mar_agitado)
        else:
            _proxima_rajada -= delta
            if _proxima_rajada <= 0.0:
                _tempo_rajada = 0.0
                _duracao_rajada = randf_range(6.0, 11.0)
                _pico_rajada_db = lerpf(-39.0, -30.0, mar_agitado) + randf_range(-2.0, 1.0)
        _vento.volume_db = lerpf(_vento.volume_db, alvo_vento, 1.0 - exp(-5.0 * delta))

    # Chuva e tempestade recebem trilhas separadas para não usar vento como chuva.
    var chuva_forca: float = 0.0
    var clima: Node = get_node_or_null("../Clima")
    if clima != null:
        if int(clima.modo_clima) == 3:
            chuva_forca = 0.64
        elif int(clima.modo_clima) == 4:
            chuva_forca = 1.0
    if oceano != null:
        chuva_forca = maxf(chuva_forca, float(oceano.tempestade_nivel))
    if _chuva != null:
        var volume_chuva: float = lerpf(-60.0, -18.0, pow(chuva_forca, 1.3))
        _chuva.volume_db = lerpf(_chuva.volume_db, volume_chuva, 1.0 - exp(-1.3 * delta))
    if chuva_forca > 0.75:
        _proximo_trovao -= delta
        if _proximo_trovao <= 0.0:
            tocar("trovao", randf_range(-22.0, -15.0), randf_range(0.82, 1.03))
            _proximo_trovao = randf_range(18.0, 42.0)
    else:
        _proximo_trovao = maxf(_proximo_trovao, 10.0)

    _prox_onda -= delta
    if _prox_onda <= 0.0:
        # Rebentacao tem sentido junto da costa; alto-mar tem ondas largas, sem estalos constantes.
        _prox_onda = randf_range(8.0, 17.0) * lerpf(1.0, 0.70, mar_agitado)
        if proximidade_costa > 0.13:
            var volume_onda: float = lerpf(-34.0, -21.0, proximidade_costa) + 2.0 * mar_agitado
            var qual: String = ["onda", "onda_2", "onda_3"][randi() % 3]
            if not _avulsos.has(qual):
                qual = "onda"
            tocar(qual, volume_onda + randf_range(-2.0, 1.0), randf_range(0.90, 1.04))
