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
const GRUPOS := ["geral", "musica", "mar", "vento", "chuva", "barco", "efeitos"]
const NOME_GRUPO := {"geral": "Geral", "musica": "Música", "mar": "Mar e ondas", "vento": "Vento", "chuva": "Chuva e trovões", "barco": "Motor e casco", "efeitos": "Efeitos"}
const CANAL := {"geral": "Master", "musica": "Musica", "mar": "Mar", "vento": "Vento", "chuva": "Chuva", "barco": "Barco", "efeitos": "Efeitos"}

var barco: Node3D
var oceano: Node3D
var navegando: bool = false          # falso no menu e na pausa: o motor cala
var volumes: Dictionary = {"geral": 1.0, "musica": 0.7, "mar": 0.7, "vento": 0.35, "chuva": 0.35, "barco": 0.8, "efeitos": 0.8}   # v0.5.12: padrões do Gabriel
var _mar: AudioStreamPlayer
var _vento: AudioStreamPlayer
var _agua: AudioStreamPlayer
var _motor: AudioStreamPlayer
var _chuva: AudioStreamPlayer
var _avulsos: Dictionary = {}
var _proximo_trovao: float = 19.0
var _prox_onda: float = 9.0
# v0.5.13: trilhas de fundo (bem baixas). Uma por período do dia; toca inteira, descansa uns minutos, toca de novo.
const MUSICAS := {"tarde": "musica_tarde", "final": "musica_final_do_dia", "noite": "musica_noite"}
const MUSICA_DB := -17.0                    # já é baixo; o controle "Música" em Opções > Áudio ajusta por cima
const MUSICA_PAUSA := [60.0, 150.0]         # s de silêncio entre uma vez e outra (o dia do jogo passa em ~16 min)
var _musica: AudioStreamPlayer
var _musica_streams: Dictionary = {}
var _musica_atual: String = ""
var _musica_espera: float = 25.0            # primeira vez: meio minuto depois de entrar no jogo
var _musica_saindo: bool = false
var _periodo_ant: String = ""
var _tempo_ambiente: float = 0.0  # ciclo lento, evita volume de ambiente mecanicamente constante
# v0.6.0: bruma. O mar e o vento ficam abafados (passa-baixa que fecha com a névoa) e, de longe, bate um sino de boia.
var _filtros_bruma: Array = []              # [{bus, indice, filtro}]
var _sino: AudioStreamPlayer
var _prox_sino: float = 22.0
var _clima_ref: Node = null
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
    _musica = AudioStreamPlayer.new()
    _musica.bus = CANAL["musica"]
    _musica.volume_db = -60.0
    add_child(_musica)
    for periodo in MUSICAS:
        var caminho: String = PASTA + String(MUSICAS[periodo]) + ".ogg"
        if ResourceLoader.exists(caminho):
            var st: AudioStream = load(caminho)
            if st is AudioStreamOggVorbis:
                st.loop = false
            _musica_streams[periodo] = st
    _preparar_bruma()
    _guardar_avulso("onda_2", "mar")
    _guardar_avulso("onda_3", "mar")
    _guardar_avulso("trovao", "chuva")
    for nome in ["pesca_lancar", "aviso", "peixe", "acerto", "perfeito", "estalo", "tensao", "captura"]:
        _guardar_avulso(nome, "efeitos")

func _preparar_bruma() -> void:
    for nome in ["Mar", "Vento"]:
        var i: int = AudioServer.get_bus_index(nome)
        if i < 0:
            continue
        var f := AudioEffectLowPassFilter.new()
        f.cutoff_hz = 20000.0
        AudioServer.add_bus_effect(i, f)
        var idx: int = AudioServer.get_bus_effect_count(i) - 1
        AudioServer.set_bus_effect_enabled(i, idx, false)
        _filtros_bruma.append({"bus": i, "indice": idx, "filtro": f})
    var caminho: String = PASTA + "sino_bruma.ogg"
    if not ResourceLoader.exists(caminho):
        return
    if AudioServer.get_bus_index("Sino") == -1:
        AudioServer.add_bus()
        var k: int = AudioServer.bus_count - 1
        AudioServer.set_bus_name(k, "Sino")
        AudioServer.set_bus_send(k, CANAL["efeitos"])
        var passa_baixa := AudioEffectLowPassFilter.new()
        passa_baixa.cutoff_hz = 1900.0
        AudioServer.add_bus_effect(k, passa_baixa)
        var eco := AudioEffectReverb.new()
        eco.room_size = 0.85
        eco.damping = 0.6
        eco.wet = 0.35
        eco.dry = 0.7
        AudioServer.add_bus_effect(k, eco)
    _sino = AudioStreamPlayer.new()
    _sino.stream = load(caminho)
    _sino.bus = "Sino"
    _sino.volume_db = -26.0
    add_child(_sino)

## Quão abafado está o mar (0..1): a bruma fecha mais longe das ilhas.
func _bruma_do_som() -> float:
    if _clima_ref == null:
        _clima_ref = get_node_or_null("../Clima")
    if _clima_ref == null:
        return 0.0
    return clampf(float(_clima_ref.bruma) * (0.40 + 0.60 * float(_clima_ref.bruma_local)), 0.0, 1.0)

func _aplicar_bruma(delta: float, bruma: float) -> void:
    for f in _filtros_bruma:
        var ligado: bool = bruma > 0.02
        if AudioServer.is_bus_effect_enabled(f.bus, f.indice) != ligado:
            AudioServer.set_bus_effect_enabled(f.bus, f.indice, ligado)
        (f.filtro as AudioEffectLowPassFilter).cutoff_hz = lerpf(20000.0, 2500.0, bruma)
    if _sino == null:
        return
    if navegando and bruma > 0.45:
        _prox_sino -= delta
        if _prox_sino <= 0.0:
            _sino.volume_db = lerpf(-33.0, -23.0, bruma) + randf_range(-3.0, 1.0)
            _sino.pitch_scale = randf_range(0.92, 1.07)
            _sino.play()
            _prox_sino = randf_range(24.0, 52.0)
    else:
        _prox_sino = maxf(_prox_sino, 10.0)

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

## Período do dia pela hora do jogo: tarde 13h–16h30, fim de tarde 16h30–18h45, noite 19h–5h. Manhã: sem música.
static func periodo_musical(hora: float) -> String:
    if hora >= 13.0 and hora < 16.5:
        return "tarde"
    if hora >= 16.5 and hora < 18.75:
        return "final"
    if hora >= 19.0 or hora < 5.0:
        return "noite"
    return ""

func _tocar_musica(delta: float, clima: Node, chuva_forca: float) -> void:
    if _musica == null or _musica_streams.is_empty():
        return
    var hora: float = float(clima.hora) if clima != null else 15.0
    var periodo: String = periodo_musical(hora)
    var temporal: bool = chuva_forca > 0.7                   # no temporal a música sai: o mar manda
    if periodo != _periodo_ant:
        _periodo_ant = periodo
        if not _musica.playing and periodo != "":
            _musica_espera = minf(_musica_espera, 8.0)         # começou a tarde / o fim de tarde / a noite: a trilha entra
    if _musica.playing:
        # a trilha toca até o fim mesmo se o período virar (termina no próprio fade); só o temporal a tira antes
        if temporal and not _musica_saindo:
            _musica_saindo = true
        var alvo: float = -60.0 if _musica_saindo else MUSICA_DB
        var veloc: float = 0.18 if _musica_saindo else 0.12             # entra e sai devagar (~8 s)
        _musica.volume_db = lerpf(_musica.volume_db, alvo, 1.0 - exp(-veloc * 6.0 * delta))
        if _musica_saindo and _musica.volume_db < -45.0:
            _musica.stop()
            _musica_saindo = false
            _musica_atual = ""
            _musica_espera = 20.0                              # trocou o período: a do novo entra logo
        return
    if _musica_atual != "" and not _musica_saindo and _musica_espera <= 0.0:
        # acabou de terminar sozinha (o arquivo tem o próprio fade): descansa antes de tocar de novo
        _musica_espera = randf_range(MUSICA_PAUSA[0], MUSICA_PAUSA[1])
        _musica_atual = ""
        return
    _musica_espera -= delta
    if _musica_espera > 0.0 or periodo == "" or temporal or not _musica_streams.has(periodo):
        return
    _musica.stream = _musica_streams[periodo]
    _musica.volume_db = -40.0
    _musica.play()
    _musica_atual = periodo
    _musica_saindo = false

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
    var bruma_som: float = _bruma_do_som()
    _aplicar_bruma(delta, bruma_som)
    if _mar != null:
        # O respiro das ondas e lento; pertinho da praia o ambiente cresce um pouco.
        var ciclo: float = 0.68 * sin(_tempo_ambiente * 0.21) + 0.32 * sin(_tempo_ambiente * 0.37 + 1.2)
        var alvo_mar: float = lerpf(-15.0, -10.0, mar_agitado) + 2.2 * proximidade_costa + 0.5 * ciclo - 4.0 * bruma_som
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

    _tocar_musica(delta, clima, chuva_forca)

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
