extends Node
## Hora do dia: troca céu, luz do sol, névoa e as cores do mar de uma vez.
## Dois ambientes prontos: "por_do_sol" (o padrão, como na arte do jogo) e "dia". A tecla T alterna.

const AMBIENTES := {
    "por_do_sol": {
        "nome": "Pôr do sol",
        "sol_graus": Vector3(-7.5, 205.0, 0.0), "sol_cor": Color(1.0, 0.76, 0.54), "sol_energia": 1.15,
        "ambiente_cor": Color(0.50, 0.66, 0.86), "ambiente_energia": 1.0,
        "nevoa_cor": Color(0.96, 0.62, 0.44), "nevoa_densidade": 0.0014,
        "mar": {"cor_profunda": Color(0.02, 0.15, 0.27), "cor_media": Color(0.03, 0.33, 0.43),
                "cor_turquesa": Color(0.08, 0.55, 0.58), "cor_espuma": Color(1.0, 0.91, 0.84),
                "cor_reflexo_ceu": Color(1.0, 0.70, 0.42), "cor_horizonte": Color(0.84, 0.62, 0.52), "brilho": 0.45,
                "reflexo_geral": 0.12, "reflexo_no_sol": 0.75},
    },
    "dia": {
        "nome": "Dia claro",
        "sol_graus": Vector3(-34.0, -28.0, 0.0), "sol_cor": Color(1.0, 0.86, 0.69), "sol_energia": 1.3,
        "ambiente_cor": Color(0.66, 0.74, 0.84), "ambiente_energia": 0.85,
        "nevoa_cor": Color(0.74, 0.72, 0.68), "nevoa_densidade": 0.0016,
        "mar": {"cor_profunda": Color(0.025, 0.135, 0.215), "cor_media": Color(0.035, 0.315, 0.400),
                "cor_turquesa": Color(0.110, 0.560, 0.600), "cor_espuma": Color(0.90, 0.96, 0.95),
                "cor_reflexo_ceu": Color(0.66, 0.74, 0.78), "cor_horizonte": Color(0.64, 0.70, 0.71), "brilho": 0.55,
                "reflexo_geral": 0.55, "reflexo_no_sol": 0.0},
    },
}

var atual := ""
var _ceu: WorldEnvironment
var _sol: DirectionalLight3D
var _mar: ShaderMaterial
var _ceu_dia: Sky
var _ceu_tarde: Sky

func configurar(ceu: WorldEnvironment, sol: DirectionalLight3D, oceano: MeshInstance3D) -> void:
    _ceu = ceu
    _sol = sol
    _mar = oceano.mesh.surface_get_material(0) as ShaderMaterial
    _ceu_dia = _ceu.environment.sky
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/ceu_pintado.gdshader")
    if ResourceLoader.exists("res://assets/texturas/mar/pigmento.png"):
        mat.set_shader_parameter("tex_nuvens", load("res://assets/texturas/mar/pigmento.png"))
    _ceu_tarde = Sky.new()
    _ceu_tarde.sky_material = mat

func aplicar(nome: String) -> void:
    if not AMBIENTES.has(nome) or _ceu == null:
        return
    atual = nome
    var a: Dictionary = AMBIENTES[nome]
    var env := _ceu.environment
    env.sky = _ceu_tarde if nome == "por_do_sol" else _ceu_dia
    env.ambient_light_color = a.ambiente_cor
    env.ambient_light_energy = a.ambiente_energia
    env.fog_light_color = a.nevoa_cor
    env.fog_density = a.nevoa_densidade
    _sol.rotation_degrees = a.sol_graus
    _sol.light_color = a.sol_cor
    _sol.light_energy = a.sol_energia
    if _mar != null:
        _mar.set_shader_parameter("direcao_sol", _sol.global_transform.basis.z)      # a luz viaja em -Z; o sol fica em +Z
        for chave in a.mar:
            _mar.set_shader_parameter(chave, a.mar[chave])

## Passa para o outro ambiente e devolve o nome dele.
func alternar() -> String:
    aplicar("dia" if atual == "por_do_sol" else "por_do_sol")
    return AMBIENTES[atual].nome
