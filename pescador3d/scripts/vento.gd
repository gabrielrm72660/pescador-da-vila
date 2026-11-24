extends RefCounted
## Vento global do mundo: dois parâmetros de shader que as folhagens (Alta e Ultra) leem para balançar.
##   vento_forca  0 = calmaria ... 1 = temporal      vento_dir  para onde o vento sopra (plano X/Z do mundo)
## clima.gd atualiza os dois a partir do estado do mar. Os globais também estão em project.godot ([shader_globals]);
## garantir() cria os dois na hora se por algum motivo não existirem (nunca deixa o shader sem o parâmetro).

const FORCA := "vento_forca"
const DIRECAO := "vento_dir"
const FASES := "vento_fases"
const VOLTA_RAJADA := 20.0 * PI        # 1,9 x 20π é múltiplo de 2π: dá para zerar sem salto nas duas rajadas

static var _verificado: bool = false
static var _fases := Vector4.ZERO

## Os dois globais vêm do project.godot. Só se faltarem (arquivo antigo) eles são criados aqui.
## (global_shader_parameter_get_list() é proibida fora do editor: a checagem usa as configurações do projeto.)
static func garantir() -> void:
    if _verificado:
        return
    _verificado = true
    if not ProjectSettings.has_setting("shader_globals/" + FORCA):
        RenderingServer.global_shader_parameter_add(FORCA, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.25)
    if not ProjectSettings.has_setting("shader_globals/" + DIRECAO):
        RenderingServer.global_shader_parameter_add(DIRECAO, RenderingServer.GLOBAL_VAR_TYPE_VEC2, Vector2(0.84, -0.54))
    if not ProjectSettings.has_setting("shader_globals/" + FASES):
        RenderingServer.global_shader_parameter_add(FASES, RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)

static func definir(forca: float, direcao: Vector2) -> void:
    garantir()
    RenderingServer.global_shader_parameter_set(FORCA, clampf(forca, 0.0, 1.0))
    RenderingServer.global_shader_parameter_set(DIRECAO, direcao.normalized() if direcao.length() > 0.001 else Vector2(1.0, 0.0))

static func forca_atual() -> float:
    garantir()
    return float(RenderingServer.global_shader_parameter_get(FORCA))

## v0.7.9: avança as fases do balanço com a velocidade de AGORA (chamado todo quadro por clima.gd).
static func avancar(delta: float, forca: float) -> void:
    garantir()
    var f: float = clampf(forca, 0.0, 1.0)
    _fases.x = fposmod(_fases.x + delta * (0.7 + 1.6 * f), VOLTA_RAJADA)
    _fases.y = fposmod(_fases.y + delta * (1.3 + 1.2 * f), TAU)
    _fases.z = fposmod(_fases.z + delta * (6.0 + 5.0 * f), TAU)
    _fases.w = fposmod(_fases.w + delta * (7.0 + 4.0 * f), TAU)
    RenderingServer.global_shader_parameter_set(FASES, _fases)
