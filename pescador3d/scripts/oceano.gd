extends MeshInstance3D
## O mar. Reposiciona a malha em volta do barco, marca o tempo das ondas e desenha a esteira.
## A função das ondas é a MESMA do shader (shaders/oceano_pintado.gdshader): se mudar lá, mude aqui.

## A malha anda em passos do tamanho de uma célula (4000 m / 400 = 10 m). Como as ondas são calculadas
## em coordenadas do mundo, cada vértice cai sempre no mesmo ponto do mar e a água não "treme" ao navegar.
const PASSO := 10.0
const PONTOS_RASTRO := 96
const INTERVALO_RASTRO := 0.14      # s entre pontos da esteira
const VIDA_RASTRO := 14.0           # s até a espuma sumir (igual ao shader)
const POPA := 3.7                   # m do centro do barco até a popa

@onready var barco: Node3D = get_node("../Barco")

var tempo: float = 0.0
var _material: ShaderMaterial
var _rastro: PackedVector4Array = PackedVector4Array()
var _proximo: int = 0
var _relogio_rastro: float = 0.0

func _ready() -> void:
    _material = mesh.surface_get_material(0) as ShaderMaterial
    _rastro.resize(PONTOS_RASTRO)
    if _material != null:                        # texturas pintadas do mar
        for nome in ["ondas", "marolas", "espuma", "pigmento"]:
            var arquivo := "res://assets/texturas/mar/%s.png" % (nome + "_normal" if nome in ["ondas", "marolas"] else nome)
            if ResourceLoader.exists(arquivo):
                _material.set_shader_parameter("tex_" + nome, load(arquivo))
            else:
                push_warning("Textura do mar não encontrada: " + arquivo)

static func onda(p: Vector2, t: float) -> float:
    return 0.47 * sin(p.x * 0.21 + p.y * 0.09 + t * 0.82) \
         + 0.33 * sin(p.y * 0.31 - p.x * 0.07 - t * 0.68) \
         + 0.17 * sin(p.dot(Vector2(0.62, -0.24)) + t * 1.18) \
         + 0.08 * sin(p.dot(Vector2(-0.90, 0.41)) - t * 1.45)

## Altura da água (m) num ponto do mundo, agora.
func altura_em(pos: Vector3) -> float:
    var vel: float = 0.75
    var alt: float = 0.30
    if _material != null:          # só há valor aqui se alguém mudou o padrão do shader no editor
        var v = _material.get_shader_parameter("velocidade_ondas")
        var a = _material.get_shader_parameter("altura_ondas")
        if v != null:
            vel = float(v)
        if a != null:
            alt = float(a)
    return onda(Vector2(pos.x, pos.z), tempo * vel) * alt

func limpar_rastro() -> void:
    for i in PONTOS_RASTRO:
        _rastro[i] = Vector4.ZERO

func _process(delta: float) -> void:
    tempo += delta
    if barco == null:
        return
    global_position = Vector3(snappedf(barco.global_position.x, PASSO), 0.0, snappedf(barco.global_position.z, PASSO))

    var frente: Vector3 = -barco.global_transform.basis.z
    var fracao: float = clampf(absf(barco.velocidade) / barco.velocidade_maxima, 0.0, 1.0)
    for i in PONTOS_RASTRO:                      # a espuma envelhece
        var r: Vector4 = _rastro[i]
        if r.w > 0.0:
            r.z += delta
            if r.z >= VIDA_RASTRO:
                r = Vector4.ZERO
            _rastro[i] = r
    _relogio_rastro += delta
    if _relogio_rastro >= INTERVALO_RASTRO:
        _relogio_rastro = 0.0
        if fracao > 0.08:                        # parado não deixa esteira
            var atras: Vector3 = barco.global_position - frente * POPA * signf(barco.velocidade)
            _rastro[_proximo] = Vector4(atras.x, atras.z, 0.0, 0.35 + 0.65 * fracao)
            _proximo = (_proximo + 1) % PONTOS_RASTRO

    if _material != null:
        _material.set_shader_parameter("tempo_mar", tempo)
        _material.set_shader_parameter("barco_pos", Vector2(barco.global_position.x, barco.global_position.z))
        _material.set_shader_parameter("barco_frente", Vector2(frente.x, frente.z).normalized())
        _material.set_shader_parameter("barco_vel", fracao)
        _material.set_shader_parameter("rastro", _rastro)
