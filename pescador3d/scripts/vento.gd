extends RefCounted
## Vento global do mundo: dois parâmetros de shader que as folhagens (Alta e Ultra) leem para balançar.
##   vento_forca  0 = calmaria ... 1 = temporal      vento_dir  para onde o vento sopra (plano X/Z do mundo)
## clima.gd atualiza os dois a partir do estado do mar. Os globais também estão em project.godot ([shader_globals]);
## garantir() cria os dois na hora se por algum motivo não existirem (nunca deixa o shader sem o parâmetro).

const FORCA := "vento_forca"
const DIRECAO := "vento_dir"

static var _verificado: bool = false

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

static func definir(forca: float, direcao: Vector2) -> void:
    garantir()
    RenderingServer.global_shader_parameter_set(FORCA, clampf(forca, 0.0, 1.0))
    RenderingServer.global_shader_parameter_set(DIRECAO, direcao.normalized() if direcao.length() > 0.001 else Vector2(1.0, 0.0))

static func forca_atual() -> float:
    garantir()
    return float(RenderingServer.global_shader_parameter_get(FORCA))
