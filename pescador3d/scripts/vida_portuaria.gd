extends Node3D
const Arq = preload("res://scripts/arquitetura_malhas.gd")
## Vida visual portuária de baixo custo: barcos NPC e pescadores nos cais.
## Os barcos NPC são o MESMO modelo do barco do jogador (PE-3476), só com outra pintura
## (shaders/pintura_npc.gdshader troca a cor mantendo o desgaste da textura). Seguem as ondas como o do jogador.
const Mesclador = preload("res://scripts/mesclador.gd")
const MODELO_BARCO := preload("res://assets/barco/PE3476_v4.glb")
const SHADER_PINTURA := preload("res://shaders/pintura_npc.gdshader")

## Quais materiais do casco viram tinta nova, e qual o papel de cada um no esquema de cores.
const PAPEL_TINTA := {"casco_vermelho": "casco", "pintura_vermelha": "casco", "pintura_azul": "faixa", "pintura_laranja": "teto",
        "casco_branco": "claro", "pintura_creme": "claro"}
## Claridade média (linear) das texturas originais; o shader usa isso para manter o desgaste da pintura.
const LUMA_REF := {"casco_vermelho": 0.110, "pintura_vermelha": 0.110, "pintura_azul": 0.101, "pintura_laranja": 0.285,
        "casco_branco": 0.703, "pintura_creme": 0.670}
const ESQUEMAS := [
    {"casco": Color(0.10, 0.38, 0.28), "faixa": Color(0.90, 0.74, 0.22), "teto": Color(0.08, 0.40, 0.38), "claro": Color(0.84, 0.93, 0.87)},    # verde, faixa amarela, teto verde-água
    {"casco": Color(0.12, 0.25, 0.50), "faixa": Color(0.82, 0.22, 0.16), "teto": Color(0.92, 0.80, 0.38), "claro": Color(0.78, 0.87, 0.95)},    # azul-marinho, faixa vermelha, teto amarelo
    {"casco": Color(0.80, 0.62, 0.16), "faixa": Color(0.14, 0.52, 0.58), "teto": Color(0.66, 0.22, 0.16), "claro": Color(0.96, 0.90, 0.74)},    # ocre, faixa turquesa, teto vermelho
]
const VELOCIDADE := [2.7, 3.3]        # m/s de cada barco da ilha
const DISTANCIA_PERTO := 260.0        # m: até aqui o barco acompanha cada quadro; além disso, só de vez em quando
const DISTANCIA_VISTA := 480.0        # m: além disso nem é desenhado (poupa chamadas de desenho)
const Fisica = preload("res://scripts/fisica_barcos.gd")

## Uma batida entre um barco NPC e o do jogador (intensidade 0..1, ponto no mundo).
signal bateu_no_jogador(intensidade: float, ponto: Vector3)

var simulando: bool = false
var fisica = null                       # Fisica: dinâmica dos cascos (passo fixo)
var _ilhas: Array = []
var _barcos: Array = []                 # Fisica.Casco de cada barco NPC (o nó fica em casco.no)
var _pessoas: Array = []
var _tempo: float = 0.0
var _oceano: Node = null
var _cache_pintura: Dictionary = {}     # "esquema|papel" -> ShaderMaterial
var _cache_tripulacao: Dictionary = {}  # "esquema|lado" -> malha da tripulação
var _mat_tripulacao: StandardMaterial3D = null
var _cache_refinado: Dictionary = {}    # id do material original -> material com o acabamento do barco do jogador

func configurar(ilhas: Array) -> void:
    _ilhas = ilhas.duplicate()
    _oceano = get_node_or_null("../Oceano")
    fisica = Fisica.new()
    fisica.ilhas = _ilhas
    fisica.oceano = _oceano
    fisica.batida.connect(_ao_bater)
    _criar()

## Diz à física quem é o barco do jogador: os NPC passam a desviar dele e a bater de verdade nele.
func definir_jogador(barco: Node3D) -> void:
    fisica.jogador = barco

func _ao_bater(intensidade: float, ponto: Vector3, com_jogador: bool) -> void:
    if com_jogador:
        bateu_no_jogador.emit(intensidade, ponto)

func _cor(cor: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = cor
    m.roughness = 0.88
    return m

# ------------------------------------------------------------------ barcos NPC

func _criar() -> void:
    for no in get_children():
        no.queue_free()
    _barcos.clear()
    _pessoas.clear()
    if fisica != null:
        fisica.cascos.clear()
    var contador: int = 0
    for ilha in _ilhas:
        if not ilha.tem_cais:
            continue
        for k in 2:
            var rota: Dictionary = _rota_livre(ilha, k)
            if rota.is_empty():
                continue
            var sentido: float = 1.0 if (contador % 2) == 0 else -1.0
            var barco: Node3D = _novo_barco(contador % ESQUEMAS.size(), sentido)
            barco.name = "PesqueiroNPC"
            add_child(barco)
            var vel: float = float(VELOCIDADE[k % VELOCIDADE.size()])
            var casco = fisica.novo_casco(barco, rota.centro, float(rota.raio), sentido, vel, float(contador) * 2.1)
            _barcos.append(casco)
            fisica.animar(casco, 0.0, 1.0, false)
            contador += 1
        _criar_pescadores(ilha)

## Procura um circuito de água livre ao largo do cais (e fora do canal de entrada, por onde o jogador passa).
func _rota_livre(ilha: Node3D, k: int) -> Dictionary:
    var cais: Vector3 = ilha.cais_ponta
    var dir: Vector3 = cais - ilha.centro
    dir.y = 0.0
    dir = dir.normalized()
    var lat := Vector3(-dir.z, 0.0, dir.x)
    var raio: float = 30.0 + 12.0 * float(k)
    var lado: float = 1.0 if k == 0 else -1.0
    for avanco in [105.0, 135.0, 170.0, 215.0]:
        for desvio in [78.0, 110.0, 150.0]:
            var centro: Vector3 = cais + dir * (float(avanco) + 25.0 * float(k)) + lat * (lado * float(desvio))
            if _circuito_livre(centro, raio + 8.0):
                return {"centro": centro, "raio": raio}
    return {}

func _circuito_livre(centro: Vector3, raio: float) -> bool:
    for i in 20:
        var a: float = TAU * float(i) / 20.0
        var p := centro + Vector3(cos(a), 0.0, sin(a)) * raio
        for ilha in _ilhas:
            if ilha.bloqueado(p):
                return false
    return true

func _novo_barco(indice_esquema: int, lado: float = 1.0) -> Node3D:
    var raiz := Node3D.new()
    var modelo: Node3D = MODELO_BARCO.instantiate()
    raiz.add_child(modelo)
    if OS.get_environment("PESCADOR_CASA_SIMPLES") != "1":
        raiz.add_child(_tripulacao(indice_esquema, lado))
    for no in modelo.find_children("*", "MeshInstance3D", true, false):
        var m := no as MeshInstance3D
        if m == null or m.mesh == null:
            continue
        m.visibility_range_end = DISTANCIA_VISTA
        m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # a água não recebe sombra: poupa a passada de sombras
        var por_nome: Dictionary = {}
        for i in m.mesh.get_surface_count():
            var original := m.mesh.surface_get_material(i) as BaseMaterial3D
            if original != null:
                por_nome[original.resource_name] = original
        for i in m.mesh.get_surface_count():
            var original := m.mesh.surface_get_material(i) as BaseMaterial3D
            if original == null:
                continue
            var nome: String = original.resource_name
            if PAPEL_TINTA.has(nome):
                m.set_surface_override_material(i, _pintura(indice_esquema, nome, original))
            elif nome == "matricula":
                # A placa leva "PE-3476": no barco dos outros fica lisa, na cor do casco claro.
                if por_nome.has("casco_branco"):
                    m.set_surface_override_material(i, _pintura(indice_esquema, "casco_branco", por_nome["casco_branco"]))
                else:
                    m.set_surface_override_material(i, _refinado(original))
            else:
                m.set_surface_override_material(i, _refinado(original))
    return raiz

## Dois pescadores (um de vara na proa, outro de balde na popa, junto a um monte de rede). A jaqueta muda de barco para barco.
func _tripulacao(indice_esquema: int, lado: float) -> MeshInstance3D:
    var chave := "%d|%d" % [indice_esquema, int(lado)]
    if not _cache_tripulacao.has(chave):
        var roupas: Array = [
            [Color(0.90, 0.72, 0.16), Color(0.26, 0.28, 0.36)],
            [Color(0.74, 0.28, 0.20), Color(0.32, 0.30, 0.26)],
            [Color(0.22, 0.46, 0.58), Color(0.30, 0.27, 0.22)],
            [Color(0.30, 0.52, 0.34), Color(0.28, 0.26, 0.22)],
        ]
        var a: Array = roupas[indice_esquema % roupas.size()]
        var b: Array = roupas[(indice_esquema + 2) % roupas.size()]
        _cache_tripulacao[chave] = Arq.tripulacao(a[0], a[1], b[0], b[1], lado)
    if _mat_tripulacao == null:
        _mat_tripulacao = StandardMaterial3D.new()
        _mat_tripulacao.vertex_color_use_as_albedo = true
        _mat_tripulacao.roughness = 0.9
    var no := MeshInstance3D.new()
    no.name = "Tripulacao"
    no.mesh = _cache_tripulacao[chave]
    no.material_override = _mat_tripulacao
    no.visibility_range_end = DISTANCIA_VISTA
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return no

func _pintura(indice_esquema: int, nome_material: String, original: BaseMaterial3D) -> ShaderMaterial:
    var papel: String = PAPEL_TINTA[nome_material]
    var chave := "%d|%s" % [indice_esquema, nome_material]
    if _cache_pintura.has(chave):
        return _cache_pintura[chave]
    var mat := ShaderMaterial.new()
    mat.shader = SHADER_PINTURA
    mat.set_shader_parameter("tex_albedo", original.albedo_texture)
    if original.normal_texture != null:
        mat.set_shader_parameter("tex_normal", original.normal_texture)
    mat.set_shader_parameter("tinta", Color(ESQUEMAS[indice_esquema][papel]))
    mat.set_shader_parameter("luma_ref", float(LUMA_REF[nome_material]))
    _cache_pintura[chave] = mat
    return mat

## Mesmo acabamento do barco do jogador (scripts/barco.gd): tinta fosca e um fio de luz na borda.
func _refinado(original: BaseMaterial3D) -> BaseMaterial3D:
    var id: int = original.get_instance_id()
    if _cache_refinado.has(id):
        return _cache_refinado[id]
    var mat: BaseMaterial3D = original.duplicate()
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    mat.roughness = 0.96
    mat.metallic_specular = 0.12
    mat.normal_scale = 0.6
    mat.rim_enabled = true
    mat.rim = 0.12
    mat.rim_tint = 0.55
    _cache_refinado[id] = mat
    return mat

# ------------------------------------------------------------------ pescadores no cais

## Um pescador de chapéu de palha com vara, numa malha só (cores nos vértices): uma chamada de desenho por pessoa.
func _malha_pescador(jaqueta: Color, bermuda: Color) -> ArrayMesh:
    var pele := Color(0.66, 0.46, 0.32)
    var palha := Color(0.86, 0.72, 0.38)
    var bota := Color(0.28, 0.20, 0.15)
    var madeira := Color(0.30, 0.22, 0.14)
    var pecas: Array = []
    pecas.append(_peca(_caixa_malha(Vector3(0.17, 0.50, 0.20)), Transform3D(Basis(), Vector3(-0.11, 0.33, 0.0)), bermuda))
    pecas.append(_peca(_caixa_malha(Vector3(0.17, 0.50, 0.20)), Transform3D(Basis(), Vector3(0.11, 0.33, 0.0)), bermuda))
    pecas.append(_peca(_caixa_malha(Vector3(0.19, 0.16, 0.26)), Transform3D(Basis(), Vector3(-0.11, 0.08, -0.02)), bota))
    pecas.append(_peca(_caixa_malha(Vector3(0.19, 0.16, 0.26)), Transform3D(Basis(), Vector3(0.11, 0.08, -0.02)), bota))
    pecas.append(_peca(_caixa_malha(Vector3(0.46, 0.56, 0.28)), Transform3D(Basis(), Vector3(0.0, 0.88, 0.0)), jaqueta))
    # braços para a frente, segurando a vara
    var braco := Basis(Vector3.RIGHT, deg_to_rad(-48.0))
    pecas.append(_peca(_caixa_malha(Vector3(0.12, 0.46, 0.13)), Transform3D(braco, Vector3(-0.30, 0.93, -0.12)), jaqueta))
    pecas.append(_peca(_caixa_malha(Vector3(0.12, 0.46, 0.13)), Transform3D(braco, Vector3(0.30, 0.93, -0.12)), jaqueta))
    var esfera := SphereMesh.new()
    esfera.radius = 0.15
    esfera.height = 0.30
    esfera.radial_segments = 10
    esfera.rings = 6
    pecas.append(_peca(esfera, Transform3D(Basis(), Vector3(0.0, 1.36, 0.0)), pele))
    var aba := CylinderMesh.new()
    aba.top_radius = 0.30
    aba.bottom_radius = 0.30
    aba.height = 0.03
    aba.radial_segments = 14
    pecas.append(_peca(aba, Transform3D(Basis(), Vector3(0.0, 1.47, 0.0)), palha))
    var copa := CylinderMesh.new()
    copa.top_radius = 0.14
    copa.bottom_radius = 0.18
    copa.height = 0.13
    copa.radial_segments = 14
    pecas.append(_peca(copa, Transform3D(Basis(), Vector3(0.0, 1.55, 0.0)), palha))
    var vara := CylinderMesh.new()
    vara.top_radius = 0.012
    vara.bottom_radius = 0.025
    vara.height = 2.3
    vara.radial_segments = 5
    # deitada para a frente e para cima, saindo das mãos
    var inclinada := Basis(Vector3.RIGHT, deg_to_rad(-62.0))
    pecas.append(_peca(vara, Transform3D(inclinada, Vector3(0.0, 1.35, -1.0)), madeira))
    return Mesclador._juntar(pecas)

func _caixa_malha(tamanho: Vector3) -> BoxMesh:
    var caixa := BoxMesh.new()
    caixa.size = tamanho
    return caixa

## [vértices, transformação, nó] com a cor gravada nos vértices (formato que Mesclador._juntar espera).
func _peca(malha: Mesh, t: Transform3D, cor: Color) -> Array:
    var matriz: Array = malha.get_mesh_arrays()
    var n: int = (matriz[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
    var cores := PackedColorArray()
    cores.resize(n)
    cores.fill(cor)
    matriz[Mesh.ARRAY_COLOR] = cores
    return [matriz, t, null]

func _criar_pescadores(ilha: Node3D) -> void:
    var cais: Vector3 = ilha.cais_ponta
    var para_o_mar: Vector3 = cais - ilha.cais_inicio
    para_o_mar.y = 0.0
    para_o_mar = para_o_mar.normalized()
    var lat := Vector3(-para_o_mar.z, 0.0, para_o_mar.x)
    var roupas := [
        [Color(0.90, 0.72, 0.16), Color(0.26, 0.28, 0.36)],     # jaqueta amarela
        [Color(0.74, 0.28, 0.20), Color(0.32, 0.30, 0.26)],     # jaqueta vermelha
        [Color(0.22, 0.46, 0.58), Color(0.30, 0.27, 0.22)],     # jaqueta azul
    ]
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.9
    for i in 3:
        var pessoa := MeshInstance3D.new()
        pessoa.name = "PescadorNPC"
        if OS.get_environment("PESCADOR_CASA_SIMPLES") == "1":
            pessoa.mesh = _malha_pescador(roupas[i][0], roupas[i][1])
        else:
            pessoa.mesh = Arq.pescador(roupas[i][0], roupas[i][1], i != 1)
        pessoa.material_override = material
        pessoa.visibility_range_end = 260.0
        add_child(pessoa)
        var ao_longo: float = 0.34 + float(i) * 0.20
        var pos: Vector3 = cais + (ilha.cais_inicio - cais) * ao_longo + lat * (0.55 if i % 2 == 0 else -0.55)
        pos.y = 1.26                                    # em cima do convés do cais
        pessoa.position = pos
        var giro_base: float = atan2(-para_o_mar.x, -para_o_mar.z)    # de frente para o mar
        pessoa.rotation.y = giro_base
        _pessoas.append({"no": pessoa, "fase": float(i) * 1.8 + float(_pessoas.size()) * 0.7, "giro": giro_base})

# ------------------------------------------------------------------ andamento

var _acumulado_longe: float = 0.0

## Dinâmica dos barcos NPC em passo fixo (a mesma cadência do barco do jogador, que também anda no _physics_process).
func _physics_process(delta: float) -> void:
    if simulando and fisica != null:
        fisica.passo(delta)

func _process(delta: float) -> void:
    if not simulando:
        return
    _tempo += delta
    _acumulado_longe += delta
    var camera: Camera3D = get_viewport().get_camera_3d()
    var olho: Vector3 = camera.global_position if camera != null else Vector3.ZERO
    var atualiza_longe: bool = _acumulado_longe >= 0.3
    var dt_longe: float = _acumulado_longe
    var alfa: float = Engine.get_physics_interpolation_fraction()      # entre dois passos fixos: imagem lisa a 100 Hz
    for c in _barcos:
        var perto: bool = c.no.global_position.distance_to(olho) < DISTANCIA_PERTO
        if perto:
            fisica.animar(c, delta, alfa, true)
        elif atualiza_longe:
            fisica.animar(c, dt_longe, alfa, false)
    if atualiza_longe:
        _acumulado_longe = 0.0
    for item in _pessoas:
        var pessoa: Node3D = item["no"]
        pessoa.rotation.y = float(item["giro"]) + 0.13 * sin(_tempo * 0.7 + float(item["fase"]))
