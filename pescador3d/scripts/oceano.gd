extends MeshInstance3D
## Mar v0.3.14. Ondas GPU/CPU sincronizadas, deriva, impacto de proa e esteira adaptativa.
## ATENCAO: onda() e a mesma funcao do shader oceano_pintado.gdshader.
## Malha mais densa (~6,7 m): ondas geometricas com comprimentos de ~43 a 85 m.
## As marolas muito pequenas sao normais animadas no shader, sem vertices extras.

## A malha do mar e um "clipmap": um bloco fino em volta do barco e aneis cada vez mais largos e grossos.
## O bloco inteiro anda de PASSO em PASSO (8 celulas finas) acompanhando o barco.
const SAIA: float = 3.0  # parede sob cada emenda entre aneis: esconde fendas entre celulas de tamanhos diferentes
const CELULA_FINA = [10.0, 8.0, 5.0, 3.5]   # metros, por qualidade (Baixa, Media, Alta, Ultra)
const ANEIS = [2, 3, 4, 4]                  # aneis alem do bloco fino
const PONTOS_RASTRO: int = 64
const INTERVALO_RASTRO: float = 0.22
const VIDA_RASTRO: float = 14.0
const POPA: float = 3.7
const CALMA_COSTEIRA: float = 0.27
const FORCA_ALTO_MAR: float = 1.27
const INICIO_ALTO_MAR: float = 25.0
const FIM_ALTO_MAR: float = 250.0

signal tempestade_comecou
signal tempestade_terminou

# 0 = automatico, 1 = calmo, 2 = moderado, 3 = agitado, 4 = temporal.
# F6 alterna os perfis para testes; o automatico varia devagar, independentemente da hora.
const ESTADOS = ["Automático", "Calmaria", "Mar moderado", "Mar agitado", "Temporal"]
const VALORES = [0.0, 0.09, 0.42, 0.74, 0.98]

@onready var barco: Node3D = get_node("../Barco")

var tempo: float = 0.0
var passo: float = 40.0
var _malha_q: int = -1
var modo_mar: int = 0
var agitacao: float = 0.48
var direcao_vento: Vector2 = Vector2(0.84, -0.54).normalized()
var _material: ShaderMaterial
var _rastro: PackedVector4Array = PackedVector4Array()
var _proximo: int = 0
var _relogio_rastro: float = 0.0
var _ultima_pos_espuma: Vector2 = Vector2.ZERO
var _tem_ultima_espuma: bool = false
var _altura: float = 0.40
var _velocidade: float = 0.80
# v0.5.8: fase das ondas acumulada (fase += delta * velocidade). Antes era tempo * velocidade: quando o clima mudava,
# a velocidade mudava e, com o tempo de jogo já grande, a fase disparava (ondas 8x mais rápidas na troca de clima).
var fase_ondas: float = 0.0
var _costas: Array = []  # [{"centro": Vector2, "raio": float}]
var simulando: bool = false
var tempestade_nivel: float = 0.0
var _em_tempestade: bool = false
var _tempestade_teste: bool = false
var _clima_manual: int = 0  # 0 automatico, 1 sol, 2 nublado, 3 chuva, 4 tempestade
var _espera_tempestade: float = 0.0
var _duracao_tempestade: float = 0.0

func _ready() -> void:
    # Deslocamento vertical do shader: evita descarte visual (frustum culling) nas cristas.
    custom_aabb = AABB(Vector3(-5300.0, -6.0, -5300.0), Vector3(10600.0, 12.0, 10600.0))
    # O mar não projeta sombra: sem isso a malha inteira era redesenhada em cada faixa da sombra do sol.
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _material = mesh.surface_get_material(0) as ShaderMaterial
    definir_qualidade(2)
    _rastro.resize(PONTOS_RASTRO)
    limpar_rastro()
    _espera_tempestade = randf_range(165.0, 270.0)
    if _material != null:
        for nome in ["ondas", "marolas", "espuma", "pigmento"]:
            var arquivo: String = "res://assets/texturas/mar/%s.png" % (nome + "_normal" if nome in ["ondas", "marolas"] else nome)
            if ResourceLoader.exists(arquivo):
                _material.set_shader_parameter("tex_" + nome, load(arquivo))
            else:
                push_warning("Textura do mar não encontrada: " + arquivo)
        _atualizar_uniformes()

## Reconstroi a malha do mar para a qualidade 0 (Baixa), 1 (Media), 2 (Alta) ou 3 (Ultra: celulas de 3,5 m perto do barco).
## Triangulos: ~33 mil nas tres; muda so o tamanho das celulas (e ate onde o mar chega).
func definir_qualidade(q: int) -> void:
    q = clampi(q, 0, CELULA_FINA.size() - 1)
    if _malha_q == q and mesh is ArrayMesh:
        return
    _malha_q = q
    var c0: float = CELULA_FINA[q]
    passo = c0 * 8.0
    var meio: float = c0 * 32.0
    var vertices := PackedVector3Array()
    var indices := PackedInt32Array()
    _grade(vertices, indices, -meio, -meio, meio, meio, c0)
    _saia(vertices, indices, meio, c0)
    var interno: float = meio
    var celula: float = c0
    for k in ANEIS[q]:
        celula *= 2.0
        var externo: float = interno * 2.0
        _grade(vertices, indices, -externo, -externo, externo, -interno, celula)   # topo
        _grade(vertices, indices, -externo, interno, externo, externo, celula)     # base
        _grade(vertices, indices, -externo, -interno, -interno, interno, celula)   # esquerda
        _grade(vertices, indices, interno, -interno, externo, interno, celula)     # direita
        _saia(vertices, indices, interno, celula)
        _saia(vertices, indices, externo, celula)
        interno = externo
    var matriz: Array = []
    matriz.resize(Mesh.ARRAY_MAX)
    matriz[Mesh.ARRAY_VERTEX] = vertices
    matriz[Mesh.ARRAY_INDEX] = indices
    var malha := ArrayMesh.new()
    malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, matriz)
    if _material != null:
        malha.surface_set_material(0, _material)
    mesh = malha

func _grade(vertices: PackedVector3Array, indices: PackedInt32Array, x0: float, z0: float, x1: float, z1: float, celula: float) -> void:
    var nx: int = roundi((x1 - x0) / celula)
    var nz: int = roundi((z1 - z0) / celula)
    var base: int = vertices.size()
    for j in nz + 1:
        for i in nx + 1:
            vertices.append(Vector3(x0 + i * celula, 0.0, z0 + j * celula))
    for j in nz:
        for i in nx:
            var a: int = base + j * (nx + 1) + i
            var d: int = a + nx + 1
            indices.append_array([a, a + 1, d + 1, a, d + 1, d])

## Parede vertical (dupla face) ao longo do quadrado de meia-largura "meio".
func _saia(vertices: PackedVector3Array, indices: PackedInt32Array, meio: float, celula: float) -> void:
    var n: int = roundi(2.0 * meio / celula)
    for lado in 4:
        for i in n:
            var t0: float = -meio + i * celula
            var t1: float = t0 + celula
            var p0: Vector3
            var p1: Vector3
            match lado:
                0: p0 = Vector3(t0, 0.0, -meio); p1 = Vector3(t1, 0.0, -meio)
                1: p0 = Vector3(t0, 0.0, meio); p1 = Vector3(t1, 0.0, meio)
                2: p0 = Vector3(-meio, 0.0, t0); p1 = Vector3(-meio, 0.0, t1)
                _: p0 = Vector3(meio, 0.0, t0); p1 = Vector3(meio, 0.0, t1)
            var b: int = vertices.size()
            vertices.append(p0)
            vertices.append(p1)
            vertices.append(p1 + Vector3(0.0, -SAIA, 0.0))
            vertices.append(p0 + Vector3(0.0, -SAIA, 0.0))
            indices.append_array([b, b + 1, b + 2, b, b + 2, b + 3, b, b + 2, b + 1, b, b + 3, b + 2])

## Cinco trens de onda. As duas primeiras sao ondas longas; as outras respondem
## mais ao vento. Grupo de ondas modula a amplitude, como series de marulhos reais.
static func onda(p: Vector2, t: float, vento: Vector2, forca: float) -> float:
    var w: Vector2 = vento.normalized()
    var cruz: Vector2 = Vector2(-w.y, w.x)
    var rumo_swell: Vector2 = (w * 0.75 + cruz * 0.25).normalized()
    var grupo: float = 0.78 + 0.22 * sin(p.dot(w * 0.012) - t * 0.17)
    var longo: float = 0.60 * sin(p.dot(rumo_swell * 0.100) - t * 0.79) \
                     + 0.32 * sin(p.dot(Vector2(-0.047, 0.076)) - t * 0.59 + 1.7)
    var marola: float = (0.08 + 0.18 * forca) * sin(p.dot(w * 0.145) - t * 1.38)
    var cruzada: float = 0.13 * sin(p.dot(cruz * 0.11 + w * 0.05) - t * 1.11 + 0.8)
    var swell_transversal: float = 0.12 * forca * sin(p.dot(cruz * 0.062 + w * 0.014) - t * 0.54 + 2.3)
    return grupo * longo + marola + cruzada + swell_transversal

## Mesmo envelope usado no shader; a diferença é calculada no ponto do mundo,
## e não apenas na posição do barco, evitando a malha mover toda por igual.
func configurar_costas(ilhas: Array) -> void:
    _costas.clear()
    for i in ilhas:
        _costas.append({"centro": Vector2(i.centro.x, i.centro.z), "raio": float(i.raio)})
    if _material != null:
        var arr := PackedVector3Array()                      # v0.5.8: até 12 ilhas (x, z, raio); antes eram 3
        for j in 12:
            if j < _costas.size():
                arr.append(Vector3(_costas[j].centro.x, _costas[j].centro.y, _costas[j].raio))
            else:
                arr.append(Vector3(1000000.0, 1000000.0, 0.0))
        _material.set_shader_parameter("ilhas_mar", arr)
        _material.set_shader_parameter("n_ilhas_mar", mini(12, _costas.size()))

func distancia_costeira(pos: Vector3) -> float:
    var menor: float = 99999.0
    for costa in _costas:
        menor = minf(menor, Vector2(pos.x, pos.z).distance_to(costa.centro) - float(costa.raio))
    return menor

func fator_onda_em(pos: Vector3) -> float:
    var distancia: float = distancia_costeira(pos)
    return lerpf(CALMA_COSTEIRA, FORCA_ALTO_MAR, smoothstep(INICIO_ALTO_MAR, FIM_ALTO_MAR, distancia))

func altura_em(pos: Vector3) -> float:
    return onda(Vector2(pos.x, pos.z), fase_ondas, direcao_vento, agitacao) * _altura * fator_onda_em(pos)

## Taxa vertical da superfície em metros/s. Mesmo campo temporal do shader.
## Evita estimar o impacto do casco apenas pela inclinação da onda.
func velocidade_vertical_em(pos: Vector3) -> float:
    var xz := Vector2(pos.x, pos.z)
    var intervalo: float = 0.09
    var futura: float = onda(xz, fase_ondas + intervalo * _velocidade, direcao_vento, agitacao)
    var passada: float = onda(xz, fase_ondas - intervalo * _velocidade, direcao_vento, agitacao)
    return (futura - passada) * _altura * fator_onda_em(pos) / (intervalo * 2.0)

func intensidade_em(pos: Vector3) -> float:
    return clampf(agitacao * fator_onda_em(pos) / FORCA_ALTO_MAR, 0.0, 1.0)

## Corrente suave: age no deslocamento, nao aumenta os nos mostrados no velocimetro.
func corrente_em(pos: Vector3) -> Vector3:
    var desvio: float = 0.13 * sin(pos.x * 0.003 + pos.z * 0.004 + tempo * 0.013)
    var rumo: Vector2 = direcao_vento.rotated(desvio)
    return Vector3(rumo.x, 0.0, rumo.y) * (0.015 + 0.13 * agitacao) * clampf(fator_onda_em(pos), 0.2, 1.2)

func intensidade() -> float:
    return intensidade_em(barco.global_position) if barco != null else agitacao

func testar_tempestade() -> String:
    _clima_manual = 0
    _tempestade_teste = not _tempestade_teste
    if _tempestade_teste:
        _em_tempestade = true
        _duracao_tempestade = 120.0
        tempestade_comecou.emit()
        return "Tempestade ativada (teste)"
    _em_tempestade = false
    _duracao_tempestade = 0.0
    _espera_tempestade = randf_range(210.0, 350.0)
    tempestade_terminou.emit()
    return "Tempestade desativada"

## Permite que K controle o tempo sem afetar os perfis de ondas testados por F6.
func definir_clima_manual(modo: int) -> void:
    _clima_manual = clampi(modo, 0, 4)
    _tempestade_teste = false
    var anterior: bool = _em_tempestade
    _em_tempestade = _clima_manual == 4
    if _clima_manual == 0:
        _espera_tempestade = randf_range(145.0, 280.0)
    if _em_tempestade and not anterior:
        tempestade_comecou.emit()
    elif anterior and not _em_tempestade:
        tempestade_terminou.emit()

func _atualizar_tempestade(delta: float) -> void:
    if not simulando or _clima_manual != 0:
        return
    if _em_tempestade:
        if not _tempestade_teste:
            _duracao_tempestade -= delta
            if _duracao_tempestade <= 0.0:
                _em_tempestade = false
                _espera_tempestade = randf_range(240.0, 430.0)
                tempestade_terminou.emit()
    else:
        _espera_tempestade -= delta
        if _espera_tempestade <= 0.0:
            _em_tempestade = true
            _duracao_tempestade = randf_range(65.0, 115.0)
            tempestade_comecou.emit()

func alternar_estado() -> String:
    modo_mar = (modo_mar + 1) % ESTADOS.size()
    return ESTADOS[modo_mar]

func resetar_mar() -> void:
    modo_mar = 0
    agitacao = 0.48
    tempestade_nivel = 0.0
    _em_tempestade = false
    _tempestade_teste = false
    _clima_manual = 0
    _espera_tempestade = randf_range(165.0, 270.0)
    _duracao_tempestade = 0.0
    tempo = 0.0
    fase_ondas = 0.0
    _relogio_rastro = 0.0
    limpar_rastro()
    _atualizar_uniformes()

func limpar_rastro() -> void:
    _proximo = 0
    _relogio_rastro = 0.0
    _tem_ultima_espuma = false
    for i in range(PONTOS_RASTRO):
        _rastro[i] = Vector4.ZERO

func _atualizar_uniformes() -> void:
    # v0.3.15F: altura física corrigida. O valor antigo, multiplicado pela
    # ressaca em alto-mar e por até cinco trens de onda, gerava paredes de
    # água de vários metros e encobria até a cabine do barco.
    # Mantemos o contraste entre costa e oceano, mas com swell navegável.
    _altura = 0.28 + 1.52 * pow(agitacao, 1.23)
    _velocidade = lerpf(0.63, 1.05, agitacao)
    if _material == null:
        return
    _material.set_shader_parameter("altura_ondas", _altura)
    _material.set_shader_parameter("velocidade_ondas", _velocidade)
    _material.set_shader_parameter("agitacao_mar", agitacao)
    _material.set_shader_parameter("direcao_vento", direcao_vento)
    _material.set_shader_parameter("quantidade_espuma", lerpf(0.18, 0.49, agitacao))
    _material.set_shader_parameter("tempo_mar", tempo)
    _material.set_shader_parameter("fase_ondas", fase_ondas)
    _material.set_shader_parameter("tempestade_nivel", tempestade_nivel)

func _process(delta: float) -> void:
    tempo += delta
    _atualizar_tempestade(delta)
    var alvo_tempestade: float = 1.0 if _em_tempestade else 0.0
    tempestade_nivel = move_toward(tempestade_nivel, alvo_tempestade, delta / 13.0)
    # Mudanças meteorológicas em centenas de segundos, sem saltos entre os perfis.
    var alvo: float = clampf(0.44 + 0.24 * sin(tempo * 0.0028) + 0.12 * sin(tempo * 0.0079 + 0.7), 0.10, 0.82)
    if modo_mar > 0:
        alvo = VALORES[modo_mar]
    if _clima_manual == 1:  # ensolarado: sem ressaca adicional
        alvo = minf(alvo, 0.35)
    elif _clima_manual == 2:
        alvo = maxf(alvo, 0.38)
    elif _clima_manual == 3:
        alvo = maxf(alvo, 0.62)
    # A tempestade sobrepõe-se ao perfil automático ou manual e decai suavemente.
    alvo = maxf(alvo, lerpf(alvo, 0.99, tempestade_nivel))
    agitacao = lerpf(agitacao, alvo, 1.0 - exp(-0.55 * delta))
    fase_ondas += delta * lerpf(0.63, 1.05, agitacao)      # mesma velocidade que _atualizar_uniformes() usa
    direcao_vento = Vector2(cos(-0.57 + tempo * 0.00042), sin(-0.57 + tempo * 0.00042))
    _atualizar_uniformes()

    if barco == null:
        return
    global_position = Vector3(snappedf(barco.global_position.x, passo), 0.0, snappedf(barco.global_position.z, passo))

    var frente: Vector3 = -barco.global_transform.basis.z
    var fracao: float = clampf(absf(barco.velocidade) / barco.velocidade_maxima, 0.0, 1.0)
    for i in range(PONTOS_RASTRO):
        var r: Vector4 = _rastro[i]
        if r.w > 0.0:
            r.z += delta
            if r.z >= VIDA_RASTRO:
                r = Vector4.ZERO
            _rastro[i] = r
    _relogio_rastro += delta
    if _relogio_rastro >= INTERVALO_RASTRO:
        _relogio_rastro = fmod(_relogio_rastro, INTERVALO_RASTRO)
        if fracao > 0.12:
            var atras: Vector3 = barco.global_position - frente * POPA * signf(barco.velocidade)
            var xz := Vector2(atras.x, atras.z)
            # Só grava novo ponto após deslocamento suficiente: sem círculos de espuma sobrepostos.
            if not _tem_ultima_espuma or _ultima_pos_espuma.distance_to(xz) >= lerpf(0.55, 1.45, fracao):
                _rastro[_proximo] = Vector4(atras.x, atras.z, 0.0, 0.25 + 0.75 * fracao)
                _proximo = (_proximo + 1) % PONTOS_RASTRO
                _ultima_pos_espuma = xz
                _tem_ultima_espuma = true
        else:
            _tem_ultima_espuma = false
    if _material != null:
        _material.set_shader_parameter("barco_pos", Vector2(barco.global_position.x, barco.global_position.z))
        _material.set_shader_parameter("barco_frente", Vector2(frente.x, frente.z).normalized())
        _material.set_shader_parameter("barco_vel", fracao)
        _material.set_shader_parameter("barco_sentido", signf(barco.velocidade))
        _material.set_shader_parameter("impacto_proa", barco.impacto_proa)
        _material.set_shader_parameter("rastro", _rastro)
