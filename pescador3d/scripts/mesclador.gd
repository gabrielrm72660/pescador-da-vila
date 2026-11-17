extends RefCounted
## Junta pecas estaticas (casas, cais, muros...) em poucas malhas: menos draw calls, o mesmo desenho.
## Uso: Mesclador.mesclar(no_raiz). So mexe em MeshInstance3D "folha", visiveis, de um material comum
## sem transparencia e com poucos vertices. Materiais com emissao (janelas, lampadas, farol) so se juntam quando
## sao o MESMO objeto: assim acender() continua ligando e desligando todos de uma vez.
## Transparentes, com filhos ou com script ficam como estao.

const MAX_VERTICES := 4000      # malhas maiores (terreno) nao entram
const CELULA := 96.0            # m: pecas distantes entre si nao viram uma malha so (o corte de camera continua util)

static func mesclar(raiz: Node3D) -> Dictionary:
    var grupos: Dictionary = {}     # chave -> {"material", "sombra", "pecas": [[mesh, Transform3D]]}
    _coletar(raiz, raiz, Transform3D.IDENTITY, grupos)
    var antes: int = 0
    var depois: int = 0
    for chave in grupos:
        var g: Dictionary = grupos[chave]
        var pecas: Array = g["pecas"]
        antes += pecas.size()
        if pecas.size() < 2:
            continue                # nada a juntar: deixa a peca onde esta
        var malha: ArrayMesh = _juntar(pecas)
        if malha == null:
            continue
        for p in pecas:
            var no: MeshInstance3D = p[2]
            if no.get_parent() != null:
                no.get_parent().remove_child(no)
            no.queue_free()
        var m := MeshInstance3D.new()
        m.name = "Mesclado"
        m.mesh = malha
        m.material_override = g["material"]
        m.cast_shadow = g["sombra"]
        raiz.add_child(m)
        depois += 1
    return {"antes": antes, "depois": depois}

static func _coletar(no: Node, raiz: Node3D, ate_aqui: Transform3D, grupos: Dictionary) -> void:
    for filho in no.get_children():
        var f3 := filho as Node3D
        if f3 == null:
            continue
        if filho.get_script() != null or not f3.visible:
            continue                # tem logica propria ou esta escondido
        var local: Transform3D = ate_aqui * f3.transform
        var inst := filho as MeshInstance3D
        if inst != null:
            if inst.get_child_count() == 0 and _serve(inst):
                var mat: StandardMaterial3D = _material_de(inst)
                var arrays: Array = inst.mesh.surface_get_arrays(0)
                var chave: String = "%s|%d|%d,%d|%s" % [_chave_material(mat), inst.cast_shadow, floori(local.origin.x / CELULA), floori(local.origin.z / CELULA), _assinatura(arrays)]
                if not grupos.has(chave):
                    grupos[chave] = {"material": mat, "sombra": inst.cast_shadow, "pecas": []}
                grupos[chave]["pecas"].append([arrays, local, inst])
            continue
        _coletar(filho, raiz, local, grupos)

static func _serve(inst: MeshInstance3D) -> bool:
    if inst.mesh == null or inst.mesh.get_surface_count() != 1:
        return false
    if inst.layers != 1 or inst.visibility_range_end > 0.0 or inst.visibility_range_begin > 0.0:
        return false
    if inst.get_surface_override_material(0) != null:
        return false
    var mat: StandardMaterial3D = _material_de(inst)
    if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
        return false
    if mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and mat.albedo_color.a < 1.0:
        return false
    var arrays: Array = inst.mesh.surface_get_arrays(0)
    var v = arrays[Mesh.ARRAY_VERTEX]
    return v != null and (v as PackedVector3Array).size() <= MAX_VERTICES

static func _material_de(inst: MeshInstance3D) -> StandardMaterial3D:
    if inst.material_override != null:
        return inst.material_override as StandardMaterial3D
    return inst.mesh.surface_get_material(0) as StandardMaterial3D

static func _chave_material(m: StandardMaterial3D) -> String:
    if m.emission_enabled:
        return "emissivo#%d" % m.get_instance_id()
    var tex: String = "-"
    if m.albedo_texture != null:
        tex = m.albedo_texture.resource_path if m.albedo_texture.resource_path != "" else str(m.albedo_texture.get_instance_id())
    var nor: String = "-"
    if m.normal_enabled and m.normal_texture != null:
        nor = m.normal_texture.resource_path if m.normal_texture.resource_path != "" else str(m.normal_texture.get_instance_id())
    return "%s|%s|%s|%.3f|%.3f|%.3f|%d|%d|%d|%s|%s|%d" % [m.albedo_color.to_html(true), tex, nor, m.roughness, m.metallic, m.metallic_specular,
        m.cull_mode, m.shading_mode, int(m.vertex_color_use_as_albedo), str(m.uv1_scale), str(m.uv1_offset), int(m.uv1_triplanar)]

## Quais atributos a malha tem: so juntam malhas com os mesmos.
static func _assinatura(a: Array) -> String:
    var s := ""
    for i in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV]:
        s += "1" if a[i] != null and (a[i] as Array).size() > 0 else "0"
    return s

static func _juntar(pecas: Array) -> ArrayMesh:
    var vertices := PackedVector3Array()
    var normais := PackedVector3Array()
    var tangentes := PackedFloat32Array()
    var cores := PackedColorArray()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    var amostra: Array = pecas[0][0]
    var tem_normal: bool = amostra[Mesh.ARRAY_NORMAL] != null
    var tem_tangente: bool = amostra[Mesh.ARRAY_TANGENT] != null
    var tem_cor: bool = amostra[Mesh.ARRAY_COLOR] != null
    var tem_uv: bool = amostra[Mesh.ARRAY_TEX_UV] != null
    for p in pecas:
        var a: Array = p[0]
        var t: Transform3D = p[1]
        var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
        var base: int = vertices.size()
        var normal_basis: Basis = t.basis.inverse().transposed()
        for v in vs:
            vertices.append(t * v)
        if tem_normal:
            for n in (a[Mesh.ARRAY_NORMAL] as PackedVector3Array):
                normais.append((normal_basis * n).normalized())
        if tem_tangente:
            var tg: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
            for i in range(0, tg.size(), 4):
                var d: Vector3 = (t.basis * Vector3(tg[i], tg[i + 1], tg[i + 2])).normalized()
                tangentes.append(d.x)
                tangentes.append(d.y)
                tangentes.append(d.z)
                tangentes.append(tg[i + 3])
        if tem_cor:
            cores.append_array(a[Mesh.ARRAY_COLOR])
        if tem_uv:
            uvs.append_array(a[Mesh.ARRAY_TEX_UV])
        var ind = a[Mesh.ARRAY_INDEX]
        if ind != null and (ind as PackedInt32Array).size() > 0:
            for i in (ind as PackedInt32Array):
                indices.append(base + i)
        else:
            for i in vs.size():
                indices.append(base + i)
    var matriz: Array = []
    matriz.resize(Mesh.ARRAY_MAX)
    matriz[Mesh.ARRAY_VERTEX] = vertices
    if tem_normal:
        matriz[Mesh.ARRAY_NORMAL] = normais
    if tem_tangente:
        matriz[Mesh.ARRAY_TANGENT] = tangentes
    if tem_cor:
        matriz[Mesh.ARRAY_COLOR] = cores
    if tem_uv:
        matriz[Mesh.ARRAY_TEX_UV] = uvs
    matriz[Mesh.ARRAY_INDEX] = indices
    var malha := ArrayMesh.new()
    malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, matriz)
    return malha

## Uma peça [vértices, transformação, nó] com a cor gravada nos vértices: o formato que _juntar espera.
## Serve para montar um bicho ou uma boia inteira numa malha só (uma chamada de desenho).
static func peca(malha: Mesh, t: Transform3D, cor: Color) -> Array:
    var matriz: Array = malha.get_mesh_arrays()
    var n: int = (matriz[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
    var cores := PackedColorArray()
    cores.resize(n)
    cores.fill(cor)
    matriz[Mesh.ARRAY_COLOR] = cores
    return [matriz, t, null]

## Elipsoide: esfera de raio 1 esticada nos três eixos, girada (graus) e posta em "centro".
static func elipsoide(centro: Vector3, escala: Vector3, cor: Color, giro_graus: Vector3 = Vector3.ZERO) -> Array:
    var esfera := SphereMesh.new()
    esfera.radius = 1.0
    esfera.height = 2.0
    esfera.radial_segments = 12
    esfera.rings = 6
    var base := Basis.from_euler(Vector3(deg_to_rad(giro_graus.x), deg_to_rad(giro_graus.y), deg_to_rad(giro_graus.z))) * Basis.from_scale(escala)
    return peca(esfera, Transform3D(base, centro), cor)
