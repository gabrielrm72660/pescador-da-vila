extends Node3D
## Dois bancos rochosos pouco profundos, em alto-mar, com aproximação navegável.
## Sem novas ilhas: não consome os dois canais de costa do shader atual.

const LOCAIS := [
    {"nome": "Recife do Leste", "centro": Vector2(425.0, -530.0), "raio": 22.0, "zona": "recife"},
    {"nome": "Pedras do Norte", "centro": Vector2(-185.0, -35.0), "raio": 17.0, "zona": "recife"},
    {"nome": "Banco das Cavalas", "centro": Vector2(110.0, -720.0), "raio": 52.0, "zona": "banco"},
    {"nome": "Baixo das Garoupas", "centro": Vector2(-72.0, -745.0), "raio": 28.0, "zona": "recife"},
    {"nome": "Canal das Sardinhas", "centro": Vector2(360.0, -100.0), "raio": 62.0, "zona": "banco"},
]

func _ready() -> void:
    _criar_rochedos()

func _criar_rochedos() -> void:
    var pedra := StandardMaterial3D.new()
    pedra.albedo_color = Color(0.43, 0.47, 0.45)
    pedra.roughness = 0.98
    var fundo := StandardMaterial3D.new()
    fundo.albedo_color = Color(0.30, 0.56, 0.55, 0.28)
    fundo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    fundo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    for local in LOCAIS:
        var nome: String = String(local.nome)
        var c: Vector2 = local.centro
        var raio: float = float(local.raio)
        var grupo := Node3D.new()
        grupo.name = nome.replace(" ", "")
        add_child(grupo)
        var disco := MeshInstance3D.new()
        var malha := CylinderMesh.new()
        malha.top_radius = raio * 0.82
        malha.bottom_radius = raio * 0.94
        malha.height = 0.2
        malha.radial_segments = 28
        disco.mesh = malha
        disco.material_override = fundo
        disco.position = Vector3(c.x, -1.5, c.y)
        grupo.add_child(disco)
        if String(local.zona) != "recife":
            continue
        var rng := RandomNumberGenerator.new()
        rng.seed = int(raio * 1000.0)
        var pedras := MultiMesh.new()
        pedras.transform_format = MultiMesh.TRANSFORM_3D
        var esfera := SphereMesh.new()
        esfera.radius = 1.0
        esfera.height = 2.0
        esfera.radial_segments = 8
        esfera.rings = 4
        pedras.mesh = esfera
        pedras.instance_count = 25
        for i in pedras.instance_count:
            var ang: float = rng.randf_range(0.0, TAU)
            var r: float = sqrt(rng.randf()) * raio * 0.83
            var p: Vector2 = c + Vector2.from_angle(ang) * r
            var alt: float = altura_em(Vector3(p.x, 0.0, p.y))
            var e: float = rng.randf_range(0.85, 2.4)
            var forma := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(e, e * 0.58, e * 1.1))
            pedras.set_instance_transform(i, Transform3D(forma, Vector3(p.x, alt - 0.7, p.y)))
        var inst := MultiMeshInstance3D.new()
        inst.multimesh = pedras
        inst.material_override = pedra
        grupo.add_child(inst)

func altura_em(pos: Vector3) -> float:
    var h: float = -99.0
    for local in LOCAIS:
        var c: Vector2 = local.centro
        var d: float = Vector2(pos.x, pos.z).distance_to(c)
        var raio: float = float(local.raio)
        if d > raio * 1.8:
            continue
        var topo: float = 0.9 if String(local.zona) == "recife" else -4.1
        var t: float = clampf(d / maxf(raio, 1.0), 0.0, 1.8)
        h = maxf(h, lerpf(topo, -15.0, smoothstep(0.12, 1.30, t)))
    return h

func bloqueado(pos: Vector3) -> bool:
    return altura_em(pos) > -0.95

func zona_em(pos: Vector3) -> String:
    for local in LOCAIS:
        var c: Vector2 = local.centro
        if Vector2(pos.x, pos.z).distance_to(c) <= float(local.raio) + 45.0:
            return String(local.zona)
    return ""

func pontos_carta() -> Array:
    var itens: Array = []
    for local in LOCAIS:
        itens.append({"nome": String(local.nome), "pos": local.centro, "tipo": String(local.zona), "raio": float(local.raio)})
    return itens
