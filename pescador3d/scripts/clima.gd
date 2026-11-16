extends Node
## O relógio do mundo: o dia passa sozinho e leva junto o céu, o sol (à noite, a lua), a névoa e as
## cores do mar. À noite desce uma neblina fechada sobre a água. Um dia inteiro dura DURACAO_DIA segundos.
## Os quatro momentos (DIA, TARDE, NOITE e o amanhecer, que reaproveita a tarde) são misturados aos poucos.

signal anoiteceu
signal amanheceu

const DURACAO_DIA := 960.0           # segundos de jogo para 24 horas (16 min; 40 s por hora)
const HORA_INICIAL := 8.0

const DIA := {
    "sol_cor": Color(1.0, 0.86, 0.69), "sol_energia": 1.3,
    "ambiente_cor": Color(0.66, 0.74, 0.84), "ambiente_energia": 0.85,
    "nevoa_cor": Color(0.74, 0.72, 0.68), "nevoa_densidade": 0.0016, "nevoa_no_ceu": 0.0,
    "ceu": {"cor_topo": Color(0.20, 0.37, 0.56), "cor_meio": Color(0.46, 0.61, 0.74), "cor_horizonte": Color(0.80, 0.76, 0.68),
            "cor_sol": Color(1.0, 0.95, 0.80), "cor_nuvem_luz": Color(1.0, 1.0, 0.97), "cor_nuvem_sombra": Color(0.62, 0.68, 0.76), "estrelas": 0.0},
    "mar": {"cor_profunda": Color(0.025, 0.135, 0.215), "cor_media": Color(0.035, 0.315, 0.400),
            "cor_turquesa": Color(0.110, 0.560, 0.600), "cor_espuma": Color(0.90, 0.96, 0.95),
            "cor_reflexo_ceu": Color(0.66, 0.74, 0.78), "cor_horizonte": Color(0.64, 0.70, 0.71), "brilho": 0.55,
            "reflexo_geral": 0.55, "reflexo_no_sol": 0.0, "cor_raso": Color(0.20, 0.78, 0.72)},
}
const TARDE := {
    "sol_cor": Color(1.0, 0.76, 0.54), "sol_energia": 1.15,
    "ambiente_cor": Color(0.50, 0.66, 0.86), "ambiente_energia": 1.0,
    "nevoa_cor": Color(0.96, 0.62, 0.44), "nevoa_densidade": 0.0014, "nevoa_no_ceu": 0.0,
    "ceu": {"cor_topo": Color(0.17, 0.27, 0.52), "cor_meio": Color(0.86, 0.46, 0.44), "cor_horizonte": Color(1.0, 0.67, 0.36),
            "cor_sol": Color(1.0, 0.86, 0.55), "cor_nuvem_luz": Color(1.0, 0.60, 0.38), "cor_nuvem_sombra": Color(0.44, 0.31, 0.50), "estrelas": 0.0},
    "mar": {"cor_profunda": Color(0.02, 0.15, 0.27), "cor_media": Color(0.03, 0.33, 0.43),
            "cor_turquesa": Color(0.08, 0.55, 0.58), "cor_espuma": Color(1.0, 0.91, 0.84),
            "cor_reflexo_ceu": Color(1.0, 0.70, 0.42), "cor_horizonte": Color(0.84, 0.62, 0.52), "brilho": 0.45,
            "reflexo_geral": 0.12, "reflexo_no_sol": 0.75, "cor_raso": Color(0.22, 0.70, 0.66)},
}
## A noite: lua fraca e azulada, e a neblina que fecha o mar em volta do barco.
const NOITE := {
    "sol_cor": Color(0.56, 0.68, 0.90), "sol_energia": 0.30,
    "ambiente_cor": Color(0.20, 0.28, 0.40), "ambiente_energia": 0.60,
    "nevoa_cor": Color(0.17, 0.235, 0.26), "nevoa_densidade": 0.013, "nevoa_no_ceu": 0.85,
    "ceu": {"cor_topo": Color(0.010, 0.020, 0.055), "cor_meio": Color(0.030, 0.050, 0.095), "cor_horizonte": Color(0.15, 0.21, 0.24),
            "cor_sol": Color(0.75, 0.83, 0.96), "cor_nuvem_luz": Color(0.16, 0.20, 0.27), "cor_nuvem_sombra": Color(0.04, 0.05, 0.08), "estrelas": 1.0},
    "mar": {"cor_profunda": Color(0.010, 0.040, 0.075), "cor_media": Color(0.015, 0.090, 0.125),
            "cor_turquesa": Color(0.040, 0.200, 0.230), "cor_espuma": Color(0.55, 0.64, 0.70),
            "cor_reflexo_ceu": Color(0.26, 0.34, 0.44), "cor_horizonte": Color(0.17, 0.235, 0.26), "brilho": 0.40,
            "reflexo_geral": 0.22, "reflexo_no_sol": 0.55, "cor_raso": Color(0.07, 0.30, 0.32)},
}
## hora -> momento. Entre duas linhas, mistura.
const LINHA_DO_TEMPO := [[0.0, NOITE], [4.9, NOITE], [6.2, TARDE], [8.2, DIA], [16.0, DIA], [17.8, TARDE], [19.4, NOITE], [24.0, NOITE]]
const NASCER := 5.4                  # hora em que o sol aponta no horizonte
const POR := 18.9                    # e em que ele some

var hora: float = HORA_INICIAL
var correndo: bool = false           # o tempo só passa navegando (não no menu, na pausa nem no cais)
var _ceu: WorldEnvironment
var _sol: DirectionalLight3D
var _mar: ShaderMaterial
var _mat_ceu: ShaderMaterial
var _relogio: float = 0.0
var _tempo: float = 0.0
var _era_noite: bool = false

func configurar(ceu: WorldEnvironment, sol: DirectionalLight3D, oceano: MeshInstance3D) -> void:
    _ceu = ceu
    _sol = sol
    _mar = oceano.mesh.surface_get_material(0) as ShaderMaterial
    _mat_ceu = ShaderMaterial.new()
    _mat_ceu.shader = load("res://shaders/ceu_pintado.gdshader")
    if ResourceLoader.exists("res://assets/texturas/mar/pigmento.png"):
        _mat_ceu.set_shader_parameter("tex_nuvens", load("res://assets/texturas/mar/pigmento.png"))
    var ceu_pintado := Sky.new()
    ceu_pintado.sky_material = _mat_ceu
    _ceu.environment.sky = ceu_pintado
    _era_noite = noite() > 0.5
    atualizar()

func _process(delta: float) -> void:
    _tempo += delta
    if correndo:
        hora = fposmod(hora + delta * 24.0 / DURACAO_DIA, 24.0)
    _relogio += delta
    if _relogio >= 0.2:                              # cinco vezes por segundo basta: o céu muda devagar
        _relogio = 0.0
        atualizar()

## Quanto é noite agora: 0 de dia, 1 noite fechada.
func noite() -> float:
    return smoothstep(17.9, 19.4, hora) if hora > 12.0 else 1.0 - smoothstep(4.9, 6.1, hora)

func texto_hora() -> String:
    return "%02d:%02d" % [int(hora), int(fmod(hora, 1.0) * 6.0) * 10]

func nome_do_momento() -> String:
    if hora < 4.9 or hora >= 19.4:
        return "noite"
    if hora < 7.0:
        return "amanhecer"
    if hora < 16.5:
        return "dia"
    return "fim de tarde"

func avancar(horas: float) -> void:
    hora = fposmod(hora + horas, 24.0)
    atualizar()

## Compatível com as versões antigas: pula para um momento pelo nome.
func aplicar(nome: String) -> void:
    hora = {"dia": 12.0, "por_do_sol": 17.9, "noite": 23.0, "amanhecer": 6.2}.get(nome, hora)
    atualizar()

func _misturar(a, b, t: float):
    if a is Dictionary:
        var saida := {}
        for chave in a:
            saida[chave] = _misturar(a[chave], b[chave], t)
        return saida
    if a is Color:
        return (a as Color).lerp(b, t)
    return lerpf(float(a), float(b), t)

func momento() -> Dictionary:
    for i in LINHA_DO_TEMPO.size() - 1:
        var h0: float = LINHA_DO_TEMPO[i][0]
        var h1: float = LINHA_DO_TEMPO[i + 1][0]
        if hora >= h0 and hora <= h1:
            return _misturar(LINHA_DO_TEMPO[i][1], LINHA_DO_TEMPO[i + 1][1], smoothstep(h0, h1, hora))
    return NOITE

func atualizar() -> void:
    if _ceu == null:
        return
    var a := momento()
    var env := _ceu.environment
    env.ambient_light_color = a.ambiente_cor
    env.ambient_light_energy = a.ambiente_energia
    env.fog_light_color = a.nevoa_cor
    # a neblina da noite respira: fecha e abre bem devagar
    env.fog_density = float(a.nevoa_densidade) * (1.0 + 0.22 * noite() * sin(_tempo * 0.17))
    env.fog_sky_affect = a.nevoa_no_ceu
    # o sol cruza o céu do nascer ao pôr; fora disso quem ilumina é a lua, parada no alto
    var forca := 1.0
    if hora > NASCER and hora < POR:
        var t := (hora - NASCER) / (POR - NASCER)
        _sol.rotation_degrees = Vector3(-(1.5 + 40.0 * sin(t * PI)), lerpf(25.0, 208.0, t), 0.0)
        forca = smoothstep(0.0, 0.05, t) * smoothstep(1.0, 0.95, t)
    else:
        _sol.rotation_degrees = Vector3(-42.0, -70.0, 0.0)
        var desde := fposmod(hora - POR, 24.0)
        var ate := fposmod(NASCER - hora, 24.0)
        forca = smoothstep(0.0, 0.6, desde) * smoothstep(0.0, 0.6, ate)
    _sol.light_color = a.sol_cor
    _sol.light_energy = float(a.sol_energia) * forca
    for chave in a.ceu:
        _mat_ceu.set_shader_parameter(chave, a.ceu[chave])
    if _mar != null:
        _mar.set_shader_parameter("direcao_sol", _sol.global_transform.basis.z)      # a luz viaja em -Z; o sol fica em +Z
        for chave in a.mar:
            _mar.set_shader_parameter(chave, a.mar[chave])
    var e_noite := noite() > 0.5
    if e_noite != _era_noite:
        _era_noite = e_noite
        if e_noite:
            anoiteceu.emit()
        else:
            amanheceu.emit()
