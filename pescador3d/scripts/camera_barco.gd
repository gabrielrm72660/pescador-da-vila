extends Camera3D
## Câmera atrás da popa. Gira em volta do barco mexendo o mouse (v0.7.4: navegando, o mouse fica preso e não precisa
## segurar botão; ver scripts/cursor.gd), com o botão direito arrastando ou com as teclas Z e X,
## aproxima com a roda do mouse, alterna dois enquadramentos com C e volta para trás da popa com V.
var alvo: Node3D
var aproximada: bool = false
var distancia: float = 15.5
var altura: float = 7.1
var giro: float = 0.0                 # radianos em volta do barco (0 = atrás da popa)
var elevacao: float = 1.0             # multiplica a altura: menos = rente à água, mais = de cima

const SENSIBILIDADE := 0.006          # radianos por pixel arrastado
const GIRO_TECLA := 1.6               # radianos por segundo com Z e X
const ELEVACAO_MIN := 0.22
const ELEVACAO_MAX := 2.6

var _arrastando: bool = false
var mouse_livre: bool = false          # v0.7.4: mouse preso na janela: só mexer já gira a câmera
var _mexeu: float = 0.0
const SENSIBILIDADE_LIVRE := 0.0032

func _ready() -> void:
    alvo = get_node("../Barco")
    resetar()

func _posicao_desejada() -> Vector3:
    var d := distancia
    var h := altura
    if aproximada:
        d *= 0.63
        h *= 0.74
    var atras: Vector3 = alvo.global_transform.basis.z
    atras.y = 0.0
    atras = atras.normalized().rotated(Vector3.UP, giro)
    return alvo.global_position + atras * d + Vector3.UP * h * elevacao

func _process(delta: float) -> void:
    if alvo == null:
        return
    if Input.is_physical_key_pressed(KEY_Z):
        giro += GIRO_TECLA * delta
    if Input.is_physical_key_pressed(KEY_X):
        giro -= GIRO_TECLA * delta
    giro = wrapf(giro, -PI, PI)
    _mexeu = maxf(0.0, _mexeu - delta)
    var fator := 1.0 - exp(-(9.0 if (_arrastando or _mexeu > 0.0) else 3.3) * delta)      # mexendo o mouse, a câmera responde na hora
    global_position = global_position.lerp(_posicao_desejada(), fator)
    look_at(alvo.global_position + Vector3(0.0, 1.35, 0.0), Vector3.UP)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT:
            _arrastando = event.pressed
        elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
            recentrar()
        elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            var sobre := get_viewport().gui_get_hovered_control()
            if sobre is Range or sobre is BaseButton:                   # roda em cima do menu não mexe na câmera
                return
            var sinal := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
            distancia = clampf(distancia + 1.5 * sinal, 8.0, 27.0)
            altura = clampf(altura + 0.5 * sinal, 4.0, 12.5)
    elif event is InputEventMouseMotion and mouse_livre and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        girar(-event.relative.x * SENSIBILIDADE_LIVRE, event.relative.y * 0.0028)
        _mexeu = 0.3
    elif event is InputEventMouseMotion and _arrastando:
        girar(-event.relative.x * SENSIBILIDADE, event.relative.y * 0.006)
    elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_V:
        recentrar()

## Gira em volta do barco (radianos) e sobe ou desce a câmera.
func girar(d_giro: float, d_elevacao: float) -> void:
    giro = wrapf(giro + d_giro, -PI, PI)
    elevacao = clampf(elevacao + d_elevacao, ELEVACAO_MIN, ELEVACAO_MAX)

func recentrar() -> void:
    giro = 0.0
    elevacao = 1.0

func alternar() -> void:
    aproximada = not aproximada

func resetar() -> void:
    aproximada = false
    distancia = 15.5
    altura = 7.1
    giro = 0.0
    elevacao = 1.0
    _arrastando = false
    if alvo != null:
        global_position = _posicao_desejada()
        look_at(alvo.global_position + Vector3(0.0, 1.35, 0.0), Vector3.UP)
