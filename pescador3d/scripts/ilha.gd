extends Node3D
const Mesclador = preload("res://scripts/mesclador.gd")
## Ilha procedural: praia, encostas, dorsais, paredoes e costa com rochedos.
## Coqueiros, moitas, pedras, vila e cais. O farol e opcional em cada ilha. Responde onde há terra (para o barco não atravessar) e onde é o cais.

## Tudo abaixo pode ser mudado antes de a ilha entrar na cena (scripts/jogo.gd cria as ilhas).
var centro := Vector3(150.0, 0.0, -290.0)      # onde a ilha fica no mundo
var raio := 128.0                              # tamanho aproximado (m)
var semente := 3476                            # muda o desenho da costa e do relevo
var pico := [-18.0, -8.0, 34.0, 22.0]          # configuração legada da ilha secundária
var morro := [34.0, -32.0, 16.0, 26.0]         # colina secundária ao sul da vila
var com_vila := true                           # falso: só um posto de pesca ao pé do cais
var coqueiros := 85
var bonus_venda := 1.0                         # quanto o cais paga pelo peixe (1.3 = 30% a mais)
var preco_diesel := 4                          # R$ por litro
var tem_loja := true                           # vende melhorias do barco?
var tem_farol := true                          # cada ilha decide se tem farol; Ilha Rata = false
var relevo_detalhado := true                    # espigoes e vales: apenas a ilha principal
const LADO := 300.0                            # lado da malha do terreno (m)
const DIVISOES := 180
const CALADO := 0.9                            # o barco encalha onde a água tem menos que isso (m)
const COMPRIMENTO_CAIS := 34.0
const LARGURA_CAIS := 3.4
const ALCANCE_CAIS := 15.0                     # m da ponta do cais até onde dá para atracar
const FAIXA_COSTA := Vector2(-12.0, 4.0)       # alturas (m) que viram 0 e 1 no mapa enviado ao mar
## Dois rochedos altos no mar, ao lado da ilha (posição local x, z; altura; largura)
var rochedos := [[136.0, 84.0, 20.0, 8.2], [148.0, 61.0, 16.0, 7.0],
        [143.0, -53.0, -1.8, 14.0], [154.0, -68.0, 4.0, 6.4]]

var nome := "Vila do Porto"
var cais_inicio: Vector3                       # onde o cais sai da praia
var cais_ponta: Vector3                        # a ponta no mar
var _ruido := FastNoiseLite.new()
## Marcadores regionais usados pela carta náutica; não são ilhas navegáveis adicionais.
var pontos_interesse: Array = []
var pos_farol: Vector2 = Vector2.ZERO   # marcador da entrada da baía (coordenadas do mundo)
var _mirante_pronto: bool = false

func _ready() -> void:
    _ruido.seed = semente
    _ruido.frequency = 0.012
    _ruido.fractal_octaves = 4
    position = centro
    _criar_terreno()
    _criar_cais()
    _criar_vila()
    if com_vila:
        _criar_detalhes_porto()
        _criar_mirante()
        _registrar_pontos_interesse()
    _criar_coqueiros()
    _criar_arvores_nativas()
    _criar_pedras_e_moitas()
    # Junta as pecas estaticas (casas, cais, muros) por material: centenas de draw calls viram dezenas.
    var resumo: Dictionary = Mesclador.mesclar(self)
    if OS.get_environment("PESCADOR_DIAG") == "1":
        print("Mesclador ", nome, ": ", resumo.get("antes", 0), " pecas -> ", resumo.get("depois", 0), " malhas")

## Altura do terreno (m) num ponto do MUNDO. Negativa = fundo do mar.
func altura_em(pos: Vector3) -> float:
    return _altura_local(pos.x - centro.x, pos.z - centro.z)

func _altura_local(x: float, z: float) -> float:
    if com_vila:
        return _altura_principal(x, z)
    var plano := Vector2(x, z)
    var d := plano.length()
    if d > LADO * 0.5:
        return -30.0
    var ang := atan2(z, x)
    var acesso := Vector2(-centro.x, -centro.z).normalized()
    var lado := Vector2(-acesso.y, acesso.x)
    var along := plano.dot(acesso)
    var across := plano.dot(lado)

    # Contorno-base da ilha: recortes orgânicos, mas com uma enseada protegida para a vila.
    var contorno := 1.0 + 0.15 * _ruido.get_noise_2d(cos(ang) * 90.0, sin(ang) * 90.0) + 0.07 * sin(ang * 2.0 + 0.8)
    if com_vila:
        var enseada := exp(-(pow((along - raio * 0.62) / (raio * 0.22), 2.0) + pow(across / (raio * 0.34), 2.0)))
        var alarga_costas := exp(-(pow((along + raio * 0.12) / (raio * 0.55), 2.0) + pow((across + raio * 0.03) / (raio * 0.72), 2.0)))
        var ponta_lateral := exp(-(pow((along + raio * 0.06) / (raio * 0.28), 2.0) + pow((across - raio * 0.66) / (raio * 0.22), 2.0)))
        contorno *= 1.0 - 0.16 * enseada + 0.08 * alarga_costas + 0.05 * ponta_lateral
    var r := d / maxf(raio * contorno, 1.0)

    var h := 13.2 * pow(maxf(0.0, 1.0 - r * r), 1.42) - 1.45 * smoothstep(0.74, 1.48, r) * 6.0 + 0.85
    h += _ruido.get_noise_2d(x * 2.2, z * 2.2) * 2.7 * clampf(1.0 - r, 0.0, 1.0)

    if com_vila:
        # Plataforma mais mansa em torno do cais e relevo principal recuado, como uma ilha habitada.
        var plataforma := exp(-(pow((along - raio * 0.13) / 18.0, 2.0) + pow((across + 1.0) / 24.0, 2.0)))
        var nivel_vila := 4.6 + _ruido.get_noise_2d(x * 0.9 + 12.0, z * 0.9 - 20.0) * 0.55
        h = lerpf(h, maxf(h, nivel_vila), plataforma * 0.72)
        var serra1 := 21.0 * exp(-(pow((along + 14.0) / 20.0, 2.0) + pow((across - 10.0) / 15.0, 2.0)))
        serra1 *= 1.0 + 0.18 * _ruido.get_noise_2d(x * 4.0 + 36.0, z * 4.0 - 12.0)
        var serra2 := 13.0 * exp(-(pow((along + 36.0) / 18.0, 2.0) + pow((across + 18.0) / 18.0, 2.0)))
        var vale := -5.0 * exp(-(pow((along + 6.0) / 10.0, 2.0) + pow((across + 1.0) / 8.0, 2.0)))
        var sela := -2.2 * exp(-(pow((along - 8.0) / 15.0, 2.0) + pow((across - 24.0) / 16.0, 2.0)))
        h += serra1 + serra2 + vale + sela

    # A serra principal e a colina secundária ainda variam por semente, mas em volume mais crível.
    var quebra := 1.0 + 0.24 * _ruido.get_noise_2d(x * 4.5 + 40.0, z * 4.5) + 0.10 * _ruido.get_noise_2d(x * 13.0, z * 13.0 + 90.0)
    h += float(pico[2]) * exp(-Vector2((x - float(pico[0])) * 1.05, z - float(pico[1])).length_squared() / (2.0 * float(pico[3]) * float(pico[3]))) * quebra
    h += float(morro[2]) * exp(-Vector2(x - float(morro[0]), z - float(morro[1])).length_squared() / (2.0 * float(morro[3]) * float(morro[3])))

    if relevo_detalhado:
        var interior: float = 1.0 - smoothstep(0.50, 0.92, r)
        var p_dir: Vector2 = plano.normalized() if d > 0.01 else Vector2.ZERO
        var protegido: float = 1.0 - 0.76 * pow(maxf(p_dir.dot(acesso), 0.0), 9.0)
        if com_vila:
            var faixa_vila := exp(-(pow((along - raio * 0.10) / 22.0, 2.0) + pow(across / 28.0, 2.0)))
            protegido *= 1.0 - 0.55 * faixa_vila
        var ondulacao: float = _ruido.get_noise_2d(x * 0.68 + 193.0, z * 0.68 - 84.0)
        var coluna: float = x * 0.38 + z * 0.92 + 18.0 + 6.0 * _ruido.get_noise_2d(x + 80.0, z - 20.0)
        var espigao: float = 7.2 * exp(-pow(coluna / 21.0, 2.0))
        var espora: float = 4.2 * exp(-pow((x * 0.74 - z * 0.56 - 17.0) / 28.0, 2.0))
        var textura_montanha: float = 3.4 * ondulacao + 0.9 * _ruido.get_noise_2d(x * 3.2, z * 3.2)
        var valeta: float = -2.6 * exp(-pow((z - 19.0 + 4.0 * ondulacao) / 13.0, 2.0))
        h += (espigao + espora + textura_montanha + valeta) * interior * protegido

    if r > 1.0:
        h = minf(h, lerpf(h, -9.0, smoothstep(1.0, 1.6, r)))
    for rc in rochedos:                                              # os rochedos saem do mar, fora da praia
        var dr := Vector2((x - float(rc[0])) * 1.35, z - float(rc[1])).length()
        dr *= 1.0 + 0.35 * _ruido.get_noise_2d(x * 5.0 + 11.0, z * 5.0)
        var corpo := exp(-pow(dr / float(rc[3]), 2.2))
        h = maxf(h, -9.0 + (float(rc[2]) + 9.0) * corpo * (1.0 + 0.22 * _ruido.get_noise_2d(x * 14.0, z * 14.0 + 30.0)))
    return h


## Geografia própria da ilha principal. Morros largos + enseada protegida + plataforma portuária.
## Esta altura também é usada pelo mar, pelo bloqueio do barco, pelas casas e pela carta náutica.
func _altura_principal(x: float, z: float) -> float:
    var p := Vector2(x, z)
    var d := p.length()
    if d > LADO * 0.5:
        return -30.0
    var frente := Vector2(-centro.x, -centro.z).normalized()
    var transversal := Vector2(-frente.y, frente.x)
    var l := p.dot(frente)   # positivo: face voltada ao continente e ao acesso
    var t := p.dot(transversal)
    var a := atan2(z, x)

    # Ilha maior, com duas pontas avançando e uma baía interna ampla e protegida.
    var sinuoso := _ruido.get_noise_2d(cos(a) * 76.0, sin(a) * 76.0)
    var costa := raio * (1.0 + 0.080 * sinuoso + 0.060 * sin(a * 3.0 + 0.2) + 0.040 * sin(a * 5.0 - 0.8))
    var forca_frente := clampf((p.normalized().dot(frente) if d > 0.01 else 0.0), -1.0, 1.0)
    var ponta_norte := 15.0 * exp(-pow((l - 95.0) / 36.0, 2.0) - pow((t - 46.0) / 27.0, 2.0))
    var ponta_sul := 12.0 * exp(-pow((l - 92.0) / 34.0, 2.0) - pow((t + 56.0) / 30.0, 2.0))
    var ombro_interno := 7.0 * exp(-pow((l - 40.0) / 46.0, 2.0) - pow(t / 52.0, 2.0))
    costa += ponta_norte + ponta_sul + ombro_interno
    # recorte da baía em meia-lua, profundo no centro e suave nas bordas
    var baia_centro := exp(-pow((l - 88.0) / 32.0, 2.0) - pow(t / 44.0, 2.0))
    var abertura_baia := clampf(forca_frente, 0.0, 1.0)
    costa -= 29.0 * baia_centro * abertura_baia
    var r := d / maxf(costa, 1.0)

    # Base da ilha maior, sem pico central agressivo.
    var base := 10.6 * pow(maxf(0.0, 1.0 - pow(r, 1.46)), 1.08) + 1.0
    base -= 8.4 * smoothstep(0.84, 1.32, r)
    var interior := 1.0 - smoothstep(0.67, 1.0, r)
    var ruido_largo := _ruido.get_noise_2d(x * 1.34 + 19.0, z * 1.34 - 21.0)
    var ruido_fino := _ruido.get_noise_2d(x * 4.9 + 71.0, z * 4.9 + 17.0)

    # Serra recuada, ampla, com colinas laterais; a cidade fica na boca da baía.
    var dorsal := 19.5 * exp(-pow((l + 34.0) / 47.0, 2.0) - pow((t - 2.0) / 34.0, 2.0))
    var colina_norte := 8.8 * exp(-pow((l - 4.0) / 31.0, 2.0) - pow((t - 56.0) / 26.0, 2.0))
    var colina_sul := 8.2 * exp(-pow((l - 10.0) / 34.0, 2.0) - pow((t + 46.0) / 29.0, 2.0))
    var esporao := 6.0 * exp(-pow((l + 59.0) / 31.0, 2.0) - pow((t - 44.0) / 22.0, 2.0))
    var sela := 4.0 * exp(-pow((l + 3.0) / 22.0, 2.0) - pow((t - 4.0) / 15.0, 2.0))
    var h := base + (dorsal + colina_norte + colina_sul + esporao - sela) * (0.94 + 0.06 * ruido_largo)
    h += (1.75 * ruido_largo + 0.38 * ruido_fino) * interior

    # Talvegue da baía e canais drenando para ela: o terreno desce em direção ao porto.
    var rebaixo_baia := 6.8 * exp(-pow((l - 70.0) / 23.0, 2.0) - pow(t / 34.0, 2.0))
    var espelho_agua := 3.6 * exp(-pow((l - 93.0) / 16.0, 2.0) - pow(t / 24.0, 2.0))
    h -= rebaixo_baia + espelho_agua
    var canal_a: float = t - (-18.0 + 4.6 * sin(l * 0.052))
    var canal_b: float = t - (38.0 + 3.4 * sin((l + 30.0) * 0.078))
    var erosao_a: float = 2.3 * exp(-pow(canal_a / 8.4, 2.0)) * exp(-pow((l + 22.0) / 42.0, 2.0))
    var erosao_b: float = 1.7 * exp(-pow(canal_b / 7.6, 2.0)) * exp(-pow((l + 18.0) / 35.0, 2.0))
    h -= (erosao_a + erosao_b) * interior

    # Faces exteriores mais firmes; dentro da baía as praias ficam suaves.
    var face_externa := (1.0 - smoothstep(-64.0, -10.0, l)) * smoothstep(0.48, 0.80, r)
    h += 4.8 * face_externa * (1.0 - smoothstep(0.97, 1.14, r))

    # Plataforma urbana ao redor da baía, em crescente, deixando a praia e o espelho d'água livres.
    var faixa_urbana := smoothstep(24.0, 78.0, l) * (1.0 - smoothstep(52.0, 84.0, absf(t)))
    var fora_agua_baia := 1.0 - exp(-pow((l - 88.0) / 17.0, 2.0) - pow(t / 20.0, 2.0))
    var fora_praia := 1.0 - smoothstep(0.79, 0.93, r)
    var plataforma := clampf(faixa_urbana * fora_agua_baia * fora_praia, 0.0, 1.0)
    var altura_urbana := 4.7 + 0.025 * (88.0 - l) + 0.26 * ruido_largo + 0.35 * smoothstep(28.0, 70.0, absf(t))
    h = lerpf(h, altura_urbana, plataforma * 0.95)

    # Faixa rasa dentro da baía para manter a sensação de abrigo.
    var sapata_baia := exp(-pow((l - 88.0) / 20.0, 2.0) - pow(t / 28.0, 2.0))
    h = lerpf(h, h + 1.2, sapata_baia * smoothstep(0.88, 1.06, r))

    if r > 1.0:
        h = minf(h, lerpf(h, -11.5, smoothstep(1.0, 1.58, r)))

    for rc in rochedos:
        var dr := Vector2((x - float(rc[0])) * 1.30, z - float(rc[1])).length()
        dr *= 1.0 + 0.19 * _ruido.get_noise_2d(x * 5.0, z * 5.0)
        var corpo := exp(-pow(dr / float(rc[3]), 2.2))
        h = maxf(h, -9.0 + (float(rc[2]) + 9.0) * corpo)
    return h

func _criar_terreno() -> void:
    var passo := LADO / DIVISOES
    var alturas := PackedFloat32Array()
    alturas.resize((DIVISOES + 1) * (DIVISOES + 1))
    for j in DIVISOES + 1:
        for i in DIVISOES + 1:
            alturas[j * (DIVISOES + 1) + i] = _altura_local(-LADO / 2.0 + i * passo, -LADO / 2.0 + j * passo)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in DIVISOES + 1:
        for i in DIVISOES + 1:
            var h := alturas[j * (DIVISOES + 1) + i]
            var he := alturas[j * (DIVISOES + 1) + maxi(i - 1, 0)]
            var hd := alturas[j * (DIVISOES + 1) + mini(i + 1, DIVISOES)]
            var hc := alturas[maxi(j - 1, 0) * (DIVISOES + 1) + i]
            var hb := alturas[mini(j + 1, DIVISOES) * (DIVISOES + 1) + i]
            var normal := Vector3(he - hd, 2.0 * passo, hc - hb).normalized()
            st.set_normal(normal)
            st.add_vertex(Vector3(-LADO / 2.0 + i * passo, h, -LADO / 2.0 + j * passo))
    for j in DIVISOES:
        for i in DIVISOES:
            var a := j * (DIVISOES + 1) + i
            var b := a + 1
            var c := a + DIVISOES + 1
            var d := c + 1
            if maxf(maxf(alturas[a], alturas[b]), maxf(alturas[c], alturas[d])) < -6.0:
                continue                                     # fundo que nunca aparece
            st.add_index(a); st.add_index(b); st.add_index(c)
            st.add_index(b); st.add_index(d); st.add_index(c)
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/terreno_pintado.gdshader")
    for par in [["tex_areia", "ilha/areia"], ["tex_grama", "ilha/grama"], ["tex_rocha", "ilha/rocha"], ["tex_manchas", "mar/pigmento"]]:
        var arquivo: String = "res://assets/texturas/%s.png" % par[1]
        if ResourceLoader.exists(arquivo):
            mat.set_shader_parameter(par[0], load(arquivo))
        else:
            push_warning("Textura da ilha não encontrada: " + arquivo)
    var malha := MeshInstance3D.new()
    malha.name = "Terreno"
    malha.mesh = st.commit()
    malha.material_override = mat
    add_child(malha)

func _material(cor: Color, textura: String = "", repeticao: float = 0.5, relevo: String = "") -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = cor
    m.roughness = 1.0                                  # fosco, como pintura: a forma vem da cor, não do brilho
    m.metallic_specular = 0.08
    if textura != "" and ResourceLoader.exists(textura):
        m.albedo_texture = load(textura)
        m.uv1_triplanar = true
        m.uv1_scale = Vector3(repeticao, repeticao, repeticao)
        if relevo != "" and ResourceLoader.exists(relevo):
            m.normal_enabled = true
            m.normal_texture = load(relevo)
    return m

func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, giro_y: float = 0.0) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = tam
    m.mesh = b
    m.material_override = mat
    m.position = pos
    m.rotation.y = giro_y
    pai.add_child(m)
    return m

func _cilindro(pai: Node3D, raio_base: float, raio_topo: float, altura: float, pos: Vector3, mat: Material) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var c := CylinderMesh.new()
    c.bottom_radius = raio_base
    c.top_radius = raio_topo
    c.height = altura
    c.radial_segments = 10
    m.mesh = c
    m.material_override = mat
    m.position = pos + Vector3(0, altura / 2.0, 0)
    pai.add_child(m)
    return m

## O cais sai da praia na direção de onde o barco começa (a origem do mundo).
func _criar_cais() -> void:
    var frente: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    var lado: Vector2 = Vector2(-frente.y, frente.x)
    var dir_cais: Vector2 = frente
    var inicio: Vector2 = Vector2.ZERO
    var ponta: Vector2 = Vector2.ZERO

    if com_vila:
        # Porto da vila: dentro da baía. Mantém a posição do cais da versão anterior.
        var eixo_baia: Vector2 = frente * 78.0 - lado * 16.0
        dir_cais = (frente * 0.88 + lado * 0.47).normalized()
        var d: float = -10.0
        while d < 28.0 and _altura_local(eixo_baia.x - dir_cais.x * d, eixo_baia.y - dir_cais.y * d) < 0.7:
            d += 0.5
        inicio = eixo_baia - dir_cais * maxf(0.0, d - 4.5)
        ponta = inicio + dir_cais * COMPRIMENTO_CAIS
    else:
        # Ilha Rata: cais tradicional curto, sem baía artificial e SEM dique.
        # Antes, a mesma função também construía um muro na Ilha Rata.
        var d_rata: float = 20.0
        while d_rata < LADO * 0.5 and _altura_local(frente.x * d_rata, frente.y * d_rata) > 0.6:
            d_rata += 0.5
        inicio = frente * (d_rata - 5.0)
        ponta = inicio + frente * COMPRIMENTO_CAIS

    cais_inicio = centro + Vector3(inicio.x, 0.0, inicio.y)
    cais_ponta = centro + Vector3(ponta.x, 0.0, ponta.y)
    var cais := Node3D.new()
    cais.name = "Cais"
    add_child(cais)
    var madeira: Material = _material(Color(1.0, 0.95, 0.88), "res://assets/texturas/ilha/madeira.png")
    var escura: Material = _material(Color(0.55, 0.45, 0.38), "res://assets/texturas/ilha/madeira.png")
    var estaca: Material = _material(Color(0.95, 0.93, 0.89), "res://assets/texturas/ilha/estaca.png", 0.7)
    var borracha: Material = _material(Color(0.10, 0.10, 0.11))
    var corda: Material = _material(Color(0.74, 0.64, 0.44))
    var giro: float = -atan2(dir_cais.y, dir_cais.x)
    var lateral: Vector2 = Vector2(-dir_cais.y, dir_cais.x)
    # Cais de madeira: passadiço estreito + plataforma larga na ponta, onde o barco encosta.
    var cabeca_c: float = 4.4
    var cabeca_l: float = 7.6
    var corpo: float = COMPRIMENTO_CAIS - cabeca_c
    var p1: Vector2 = inicio + dir_cais * (corpo * 0.5)
    _caixa(cais, Vector3(corpo, 0.22, LARGURA_CAIS), Vector3(p1.x, 1.15, p1.y), madeira, giro)
    var p2: Vector2 = inicio + dir_cais * (COMPRIMENTO_CAIS - cabeca_c * 0.5)
    _caixa(cais, Vector3(cabeca_c, 0.22, cabeca_l), Vector3(p2.x, 1.15, p2.y), madeira, giro)
    # Vigas por baixo (transversais e longitudinais).
    var n_vigas: int = int(COMPRIMENTO_CAIS / 2.0)
    for i in n_vigas + 1:
        var a: float = COMPRIMENTO_CAIS * float(i) / float(n_vigas)
        var largura: float = cabeca_l if a > corpo + 0.1 else LARGURA_CAIS
        var pv: Vector2 = inicio + dir_cais * a
        _caixa(cais, Vector3(0.26, 0.26, largura + 0.3), Vector3(pv.x, 0.88, pv.y), escura, giro)
    for c in [-1.15, 1.15]:
        var pl: Vector2 = inicio + dir_cais * (COMPRIMENTO_CAIS * 0.5) + lateral * float(c)
        _caixa(cais, Vector3(COMPRIMENTO_CAIS, 0.24, 0.24), Vector3(pl.x, 0.66, pl.y), escura, giro)
    # Estacas de madeira escura craveiras no fundo (textura de madeira molhada, com craca e alga na base).
    var n: int = maxi(1, int(COMPRIMENTO_CAIS / 4.25))
    for i in n + 1:
        var a: float = COMPRIMENTO_CAIS * float(i) / float(n)
        var meia: float = (cabeca_l if a > corpo + 0.1 else LARGURA_CAIS) * 0.5 - 0.2
        var p: Vector2 = inicio + dir_cais * a
        for s in [-1.0, 1.0]:
            var q: Vector2 = p + lateral * float(s) * meia
            _cilindro(cais, 0.21, 0.19, 3.9, Vector3(q.x, -2.9, q.y), estaca)
    # Cabeços de amarração nos cantos da plataforma, com a volta de corda.
    for a in [COMPRIMENTO_CAIS - 0.5, COMPRIMENTO_CAIS - cabeca_c + 0.5]:
        for s in [-1.0, 1.0]:
            var q: Vector2 = inicio + dir_cais * float(a) + lateral * float(s) * (cabeca_l * 0.5 - 0.3)
            _cilindro(cais, 0.15, 0.17, 0.55, Vector3(q.x, 1.26, q.y), estaca)
            _cilindro(cais, 0.18, 0.18, 0.08, Vector3(q.x, 1.38, q.y), corda)
    # Defensas (pneus) nos dois lados da plataforma.
    for a in [COMPRIMENTO_CAIS - 0.9, COMPRIMENTO_CAIS - 2.2, COMPRIMENTO_CAIS - 3.5]:
        for s in [-1.0, 1.0]:
            var q: Vector2 = inicio + dir_cais * float(a) + lateral * float(s) * (cabeca_l * 0.5 + 0.12)
            _cilindro(cais, 0.2, 0.2, 0.5, Vector3(q.x, 0.55, q.y), borracha)
    # Guarda-corpo no passadiço e escada na ponta.
    var a_corrimao: float = 2.0
    while a_corrimao < corpo - 1.0:
        for s in [-1.0, 1.0]:
            var q: Vector2 = inicio + dir_cais * a_corrimao + lateral * float(s) * (LARGURA_CAIS * 0.5 - 0.1)
            _caixa(cais, Vector3(0.1, 0.95, 0.1), Vector3(q.x, 1.7, q.y), escura, giro)
        a_corrimao += 3.0
    for s in [-1.0, 1.0]:
        var q: Vector2 = inicio + dir_cais * (corpo * 0.5 + 1.0) + lateral * float(s) * (LARGURA_CAIS * 0.5 - 0.1)
        _caixa(cais, Vector3(corpo - 3.0, 0.08, 0.1), Vector3(q.x, 2.12, q.y), escura, giro)
    var esc: Vector2 = inicio + dir_cais * (COMPRIMENTO_CAIS + 0.06) + lateral * 1.6
    for s in [-0.3, 0.3]:
        var r: Vector2 = esc + lateral * float(s)
        _caixa(cais, Vector3(0.07, 2.6, 0.07), Vector3(r.x, 0.2, r.y), escura, giro)
    for k in 5:
        _caixa(cais, Vector3(0.08, 0.06, 0.62), Vector3(esc.x, 1.0 - 0.42 * float(k), esc.y), escura, giro)
    # Barris e caixotes no fundo da plataforma.
    var barril: Vector2 = inicio + dir_cais * (COMPRIMENTO_CAIS - 3.4) - lateral * 2.9
    _cilindro(cais, 0.32, 0.30, 0.9, Vector3(barril.x, 1.26, barril.y), _material(Color(0.22, 0.42, 0.58)))
    _cilindro(cais, 0.32, 0.30, 0.9, Vector3(barril.x + dir_cais.x * 0.8, 1.26, barril.y + dir_cais.y * 0.8), _material(Color(0.52, 0.30, 0.16)))
    var caixote: Vector2 = inicio + dir_cais * (COMPRIMENTO_CAIS - 1.4) - lateral * 2.8
    _caixa(cais, Vector3(0.8, 0.55, 0.8), Vector3(caixote.x, 1.6, caixote.y), _material(Color(0.62, 0.45, 0.26), "res://assets/texturas/ilha/madeira.png", 0.5), giro + 0.2)

    # Diesel e luz no cais funcionam em ambas as ilhas, como antes.
    var cabeca: Vector2 = ponta - dir_cais * 2.0
    _caixa(cais, Vector3(0.7, 1.3, 0.5), Vector3(cabeca.x + lateral.x, 1.9, cabeca.y + lateral.y), _material(Color(0.80, 0.22, 0.16)), giro)
    _caixa(cais, Vector3(0.9, 0.7, 0.9), Vector3(cabeca.x - lateral.x - dir_cais.x * 2.0, 1.6, cabeca.y - lateral.y - dir_cais.y * 2.0), _material(Color(0.86, 0.66, 0.2)), giro + 0.3)
    _cilindro(cais, 0.07, 0.06, 3.2, Vector3(ponta.x - dir_cais.x * 0.4, 1.2, ponta.y - dir_cais.y * 0.4), escura)
    var lanterna: StandardMaterial3D = _material(Color(1.0, 0.85, 0.5))
    lanterna.emission_enabled = true
    lanterna.emission = Color(1.0, 0.75, 0.35)
    lanterna.emission_energy_multiplier = 2.0
    _caixa(cais, Vector3(0.3, 0.36, 0.3), Vector3(ponta.x - dir_cais.x * 0.4, 4.5, ponta.y - dir_cais.y * 0.4), lanterna)
    _luz(cais, Vector3(ponta.x - dir_cais.x * 0.4, 4.6, ponta.y - dir_cais.y * 0.4), 3.0, 22.0)

    if com_vila:
        _criar_dique_portuario(cais, frente, lado)


## Substitui o paredão que atravessava a boca do porto por proteção discreta
## junto a uma das margens. Não toca nem cruza a rota de aproximação ao cais.
func _criar_dique_portuario(pai: Node3D, frente: Vector2, lado: Vector2) -> void:
    var rocha: Material = _material(Color(0.58, 0.56, 0.53), "res://assets/texturas/ilha/rocha.png", 0.28)
    var topo: Material = _material(Color(0.69, 0.67, 0.60), "res://assets/texturas/ilha/rocha.png", 0.22)
    # Esporão de APENAS 13 m, junto à ponta da baía (t ~ +76 m).
    # O canal de entrada e o cais ficam aproximadamente em t = -16..+5 m.
    var raiz: Vector2 = frente * 83.0 + lado * 76.0
    var extremidade: Vector2 = frente * 94.0 + lado * 82.0
    var direcao: Vector2 = (extremidade - raiz).normalized()
    var comprimento: float = raiz.distance_to(extremidade)
    var meio: Vector2 = (raiz + extremidade) * 0.5
    var giro: float = -atan2(direcao.y, direcao.x)
    _caixa(pai, Vector3(comprimento, 1.45, 3.4), Vector3(meio.x, 0.25, meio.y), rocha, giro)
    _caixa(pai, Vector3(comprimento, 0.20, 2.8), Vector3(meio.x, 1.07, meio.y), topo, giro)


## Uma casa: paredes caiadas (tingidas), rodapé, porta e janelas de madeira pintada e telhado de barro de
## duas águas. A frente (porta) fica em +X local; "giro" vira a casa para o mar.
func _casa(pai: Node3D, pos: Vector3, giro: float, tam: Vector3, cor: Color, cor_madeira: Color) -> Node3D:
    var casa := Node3D.new()
    casa.position = pos + Vector3(0, -0.4, 0)                        # um pouco enterrada: assenta em chão torto
    casa.rotation.y = giro
    pai.add_child(casa)
    var parede := _material(cor, "res://assets/texturas/ilha/reboco.png", 0.22, "res://assets/texturas/ilha/reboco_normal.png")
    _caixa(casa, tam, Vector3(0, tam.y / 2.0, 0), parede)
    _caixa(casa, Vector3(tam.x + 0.10, 0.75, tam.z + 0.10), Vector3(0, 0.375, 0), _material(cor.darkened(0.42)))
    var madeira := _material(cor_madeira)
    if _vidro == null:
        _vidro = _material(Color(0.10, 0.14, 0.18))
        _vidro.roughness = 0.25
        _vidro.emission_enabled = true
        _vidro.emission = Color(1.0, 0.72, 0.36)
        _vidro.emission_energy_multiplier = 0.0
    var vidro := _vidro
    var fx := tam.x / 2.0
    _caixa(casa, Vector3(0.10, 2.0, 1.0), Vector3(fx, 1.4, -tam.z * 0.18), madeira)                 # porta
    _caixa(casa, Vector3(0.16, 0.12, 1.3), Vector3(fx, 2.46, -tam.z * 0.18), madeira.duplicate())
    for jan in [Vector3(fx, 1.95, tam.z * 0.24), Vector3(-fx, 1.95, 0.0)]:                         # janelas na frente e atrás
        _caixa(casa, Vector3(0.08, 0.95, 0.95), jan, vidro)
        for s in [-1.0, 1.0]:
            _caixa(casa, Vector3(0.14, 1.0, 0.36), jan + Vector3(0, 0, s * 0.62), madeira)       # folhas abertas
    for s in [-1.0, 1.0]:                                                                          # e uma em cada lado
        var jl := Vector3(tam.x * 0.12, 1.95, s * tam.z / 2.0)
        _caixa(casa, Vector3(0.95, 0.95, 0.08), jl, vidro)
        _caixa(casa, Vector3(1.15, 0.12, 0.16), jl + Vector3(0, -0.54, 0), madeira)
    _telhado(casa, tam, 1.7, parede)
    return casa

## Telhado de duas águas com a cumeeira ao longo de Z, beiral sobrando, e os dois oitões de parede.
func _telhado(casa: Node3D, tam: Vector3, subida: float, parede: Material) -> void:
    var a := tam.x / 2.0 + 0.55
    var b := tam.z / 2.0 + 0.45
    var y0 := tam.y - 0.12
    var rampa := Vector2(a, subida).length()
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for s in [1.0, -1.0]:
        var cantos := [Vector3(0, y0 + subida, -b), Vector3(0, y0 + subida, b), Vector3(s * a, y0, b), Vector3(s * a, y0, -b)]
        var uvs := [Vector2(-b, 0), Vector2(b, 0), Vector2(b, rampa), Vector2(-b, rampa)]
        for k in [0, 1, 2, 0, 2, 3]:
            st.set_normal(Vector3(s * subida, a, 0).normalized())
            st.set_tangent(Plane(0, 0, 1, 1))
            st.set_uv(uvs[k] / 3.6)
            st.add_vertex(cantos[k])
    var telhas := StandardMaterial3D.new()
    telhas.albedo_texture = load("res://assets/texturas/ilha/telhas.png")
    telhas.normal_enabled = true
    telhas.normal_texture = load("res://assets/texturas/ilha/telhas_normal.png")
    telhas.roughness = 1.0
    telhas.metallic_specular = 0.08
    telhas.normal_scale = 0.5
    telhas.cull_mode = BaseMaterial3D.CULL_DISABLED
    var m := MeshInstance3D.new()
    m.mesh = st.commit()
    m.material_override = telhas
    casa.add_child(m)
    var oitao := SurfaceTool.new()                                    # o triângulo de parede sob cada ponta
    oitao.begin(Mesh.PRIMITIVE_TRIANGLES)
    var meia := tam.x / 2.0
    var topo := subida * meia / a
    for s in [1.0, -1.0]:
        for v in [Vector3(-meia, tam.y, s * tam.z / 2.0), Vector3(meia, tam.y, s * tam.z / 2.0), Vector3(0, tam.y + topo, s * tam.z / 2.0)]:
            oitao.set_normal(Vector3(0, 0, s))
            oitao.add_vertex(v)
    var mo := MeshInstance3D.new()
    mo.mesh = oitao.commit()
    var mat_oitao: StandardMaterial3D = parede.duplicate()
    mat_oitao.cull_mode = BaseMaterial3D.CULL_DISABLED
    mo.material_override = mat_oitao
    casa.add_child(mo)

var _vidro: StandardMaterial3D        # um só para todas as janelas: acendem juntas à noite
var _luzes: Array = []                # luzes do farol e do cais
var _farol_pivo: Node3D = null
var _farol_foco: SpotLight3D = null
var _farol_halo: Sprite3D = null
var _farol_feixe: MeshInstance3D = null      # cone de luz visível (aditivo), gira junto com a lanterna
var _farol_feixe_mat: ShaderMaterial = null
var _farol_material: StandardMaterial3D = null
var _farol_noite: float = 0.0
var _barco_observador: Node3D = null
var _ocupado: Array = []          # (x, z, raio) do que já foi construído: árvores e pedras ficam fora

## Fita de chão que segue a altura do terreno. Também evita caminhos flutuando acima da praia.
## Material de piso (trilha, calçada): textura pintada em projeção por cima, com a borda dissolvendo na terra.
func _material_trilha(textura: String, cor: Color, repeticao: float) -> StandardMaterial3D:
    var m := _material(cor, textura, repeticao)
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    m.vertex_color_use_as_albedo = true
    return m

## Faixa de chão que segue o relevo. A largura oscila de leve e as bordas ficam macias (alfa 0 -> 1):
## em vez de um retângulo laranja, a trilha parece gasta pelo uso.
func _caminho(pai: Node3D, pontos: Array, largura: float, material: Material) -> void:
    if pontos.size() < 2:
        return
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var percorrido := 0.0
    var semente_borda := float(pontos.size()) * 1.7 + float(int(absf(pontos[0].x)) % 7)
    for i in range(pontos.size() - 1):
        var a: Vector2 = pontos[i]
        var b: Vector2 = pontos[i + 1]
        var dist := a.distance_to(b)
        var passos := maxi(1, ceili(dist / 1.4))
        var tangente := (b - a).normalized()
        var normal2 := Vector2(-tangente.y, tangente.x)
        var secao_anterior: Array = []
        for k in passos + 1:
            var centro_secao := a.lerp(b, float(k) / passos)
            var s_atual := percorrido + dist * float(k) / passos
            var oscila := 1.0 + 0.13 * sin(s_atual * 0.55 + semente_borda) + 0.07 * sin(s_atual * 1.7 + semente_borda * 2.0)
            var meia := largura * 0.5 * oscila
            var secao: Array = []
            for par in [[-1.0, 0.0], [-0.62, 1.0], [0.62, 1.0], [1.0, 0.0]]:
                var local: Vector2 = centro_secao + normal2 * meia * float(par[0])
                secao.append([Vector3(local.x, _altura_local(local.x, local.y) + 0.13, local.y), float(par[1])])
            if not secao_anterior.is_empty():
                for j in 3:
                    for idx in [[0, 0], [0, 1], [1, 0], [1, 0], [0, 1], [1, 1]]:
                        var v: Array = (secao_anterior if idx[0] == 0 else secao)[j + idx[1]]
                        st.set_color(Color(1.0, 1.0, 1.0, v[1]))
                        st.set_normal(Vector3.UP)
                        st.add_vertex(v[0])
            secao_anterior = secao
        percorrido += dist
    var malha := MeshInstance3D.new()
    malha.mesh = st.commit()
    malha.material_override = material
    malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    pai.add_child(malha)

func _criar_vila() -> void:
    var vila := Node3D.new()
    vila.name = "Vila"
    add_child(vila)
    var dir := Vector2(-centro.x, -centro.z).normalized()
    var lado := Vector2(-dir.y, dir.x)
    var pe_do_cais := Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    _ocupado.append(Vector3(pe_do_cais.x, pe_do_cais.y, 10.0))
    var virada := -atan2(dir.y, dir.x)
    var rng := RandomNumberGenerator.new()
    rng.seed = 3676
    var cores := [Color(0.96, 0.91, 0.80), Color(0.96, 0.80, 0.55), Color(0.70, 0.83, 0.83),
            Color(0.94, 0.78, 0.68), Color(0.88, 0.90, 0.74), Color(0.98, 0.95, 0.88)]
    var portas := [Color(0.24, 0.42, 0.51), Color(0.52, 0.28, 0.20), Color(0.30, 0.42, 0.28)]
    var areia_batida := _material_trilha("res://assets/texturas/ilha/trilha.png", Color(1.0, 0.94, 0.82), 0.30)
    var calcada := _material_trilha("res://assets/texturas/ilha/calcada.png", Color(1.0, 0.95, 0.84), 0.55)

    if not com_vila:
        # Posto isolado de pescadores: a Ilha Rata não vira vila e não recebe farol.
        var barracao := pe_do_cais - dir * 13.0 + lado * 8.0
        var hs := _altura_local(barracao.x, barracao.y)
        if hs > 0.5:
            _casa(vila, Vector3(barracao.x, hs, barracao.y), virada, Vector3(6, 3.0, 6), cores[0], portas[0])
            _ocupado.append(Vector3(barracao.x, barracao.y, 8.0))
        return

    # Hierarquia urbana: cais -> rua de chegada -> praça -> rua do mercado e das moradias.
    var chegada := pe_do_cais - dir * 14.0
    var praca := pe_do_cais - dir * 49.0 + lado * 3.0
    _caminho(vila, [pe_do_cais, chegada, praca], 4.7, calcada)
    _caminho(vila, [chegada + lado * -46.0, chegada, chegada + lado * 46.0], 4.3, areia_batida)
    _caminho(vila, [praca + lado * -40.0, praca, praca + lado * 40.0], 3.8, areia_batida)
    _caminho(vila, [praca - dir * 23.0, praca], 3.0, calcada)

    # Pequena praça caiada com banco, fonte e sombra — elemento legível desde o mar.
    _ocupado.append(Vector3(praca.x, praca.y, 11.0))
    var hp := _altura_local(praca.x, praca.y)
    _cilindro(vila, 3.0, 3.0, 0.32, Vector3(praca.x, hp + 0.05, praca.y), calcada)
    _cilindro(vila, 0.8, 0.6, 1.1, Vector3(praca.x, hp + 0.25, praca.y), _material(Color(0.72, 0.71, 0.66)))
    for s in [-1.0, 1.0]:
        var pos_banco: Vector2 = praca + lado * float(s) * 7.2
        _caixa(vila, Vector3(2.8, 0.25, 0.7), Vector3(pos_banco.x, _altura_local(pos_banco.x, pos_banco.y) + 0.55, pos_banco.y), _material(Color(0.36, 0.27, 0.17)), virada)

    # Grupos compactos de casinhas, com rua e respiro entre quadras; casas não invadem o mar.
    var distribuicao := [
        [18.0, -54.0], [19.0, -40.0], [19.0, -26.0], [18.0, 24.0], [18.0, 38.0], [18.0, 52.0],
        [35.0, -49.0], [35.0, -34.0], [34.0, -18.0], [34.0, 19.0], [35.0, 35.0], [35.0, 50.0],
        [53.0, -42.0], [52.0, -27.0], [51.0, -10.0], [51.0, 12.0], [52.0, 29.0], [53.0, 44.0],
        [71.0, -31.0], [70.0, -15.0], [70.0, 16.0], [71.0, 33.0],
        [85.0, -18.0], [85.0, 0.0], [85.0, 19.0]
    ]
    var construidas := 0
    for par in distribuicao:
        var pp := pe_do_cais - dir * float(par[0]) + lado * float(par[1])
        var hh := _altura_local(pp.x, pp.y)
        var aclive := absf(_altura_local(pp.x + 3.0, pp.y) - _altura_local(pp.x - 3.0, pp.y)) + absf(_altura_local(pp.x, pp.y + 3.0) - _altura_local(pp.x, pp.y - 3.0))
        if hh < 1.5 or aclive > 3.1 or not _livre(pp, 6.0):
            continue
        var tam := Vector3(rng.randf_range(5.0, 6.4), rng.randf_range(3.0, 3.8), rng.randf_range(5.4, 7.2))
        var cor: Color = cores[construidas % cores.size()]
        # Cada moradia tem acesso a uma rua, sem atravessar quarteirões vizinhos.
        var central_rua: Vector2 = pe_do_cais - dir * float(par[0]) + lado * (5.0 if float(par[1]) > 0.0 else -5.0)
        var inicio_acesso: Vector2 = pp + lado * (3.5 if float(par[1]) < 0.0 else -3.5)
        _caminho(vila, [inicio_acesso, central_rua], 1.5, areia_batida)
        _casa(vila, Vector3(pp.x, hh, pp.y), virada + rng.randf_range(-0.1, 0.1), tam, cor, portas[construidas % portas.size()])
        _ocupado.append(Vector3(pp.x, pp.y, 6.7))
        construidas += 1

    # Galpões de pescadores junto ao desembarque, mantendo livre a circulação no cais.
    var armazem := chegada + lado * -20.0 - dir * 2.0
    var ha := _altura_local(armazem.x, armazem.y)
    if ha > 1.2 and _livre(armazem, 7.0):
        _casa(vila, Vector3(armazem.x, ha, armazem.y), virada, Vector3(9.0, 3.5, 8.0), Color(0.80, 0.78, 0.66), Color(0.33, 0.29, 0.22))
        _ocupado.append(Vector3(armazem.x, armazem.y, 8.0))
        for k in 3:
            var caixas := armazem + lado * -5.0 + dir * (3.0 + k * 1.0)
            _caixa(vila, Vector3(1.2, 0.8, 1.0), Vector3(caixas.x, _altura_local(caixas.x, caixas.y) + 0.45, caixas.y), _material(Color(0.45, 0.34, 0.23)), virada + 0.1 * k)
    var mercado := chegada + lado * 22.0 - dir * 1.0
    var hm := _altura_local(mercado.x, mercado.y)
    if hm > 1.2 and _livre(mercado, 7.0):
        _casa(vila, Vector3(mercado.x, hm, mercado.y), virada, Vector3(9.0, 3.5, 7.2), Color(0.83, 0.88, 0.85), portas[0])
        _ocupado.append(Vector3(mercado.x, mercado.y, 8.0))

    # Capela pequena no fim da rua; nunca no meio da serra.
    var pc := praca - dir * 29.0 + lado * 4.0
    var hc := _altura_local(pc.x, pc.y)
    if hc > 2.0 and _livre(pc, 9.0):
        var nave := _casa(vila, Vector3(pc.x, hc, pc.y), virada, Vector3(9.0, 4.2, 6.0), Color(0.98, 0.97, 0.92), Color(0.18, 0.35, 0.42))
        var branca := _material(Color(0.98, 0.97, 0.92), "res://assets/texturas/ilha/reboco.png", 0.24)
        _caixa(nave, Vector3(2.0, 8.0, 2.0), Vector3(4.5, 4.0, 3.3), branca)
        _caixa(nave, Vector3(0.16, 1.45, 0.16), Vector3(4.5, 9.15, 3.3), _material(Color(0.30, 0.22, 0.17)))
        _caixa(nave, Vector3(0.16, 0.16, 1.0), Vector3(4.5, 9.5, 3.3), _material(Color(0.30, 0.22, 0.17)))
        _ocupado.append(Vector3(pc.x, pc.y, 9.0))
    if tem_farol and com_vila:
        _criar_farol_no_cume(vila)



## Busca o ponto de maior altitude no interior da ilha principal, afastado da praia e dos rochedos.
## O cume é calculado a partir da mesma função usada na malha 3D e na colisão.
func _encontrar_cume() -> Vector2:
    var melhor: Vector2 = Vector2.ZERO
    var maior_altitude: float = -INF
    var dir_interior: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    for ix in range(-106, 107, 4):
        for iz in range(-106, 107, 4):
            var candidato: Vector2 = Vector2(float(ix), float(iz))
            if candidato.length() > 105.0 or candidato.dot(dir_interior) > 36.0:
                continue
            var altura: float = _altura_local(candidato.x, candidato.y)
            if altura > maior_altitude:
                maior_altitude = altura
                melhor = candidato
    # Ajuste local de 1 metro para o farol ficar assentado na parte mais alta.
    var proximo: Vector2 = melhor
    for ix in range(-4, 5):
        for iz in range(-4, 5):
            var candidato: Vector2 = melhor + Vector2(float(ix), float(iz))
            if candidato.length() > 108.0 or candidato.dot(dir_interior) > 38.0:
                continue
            var altura: float = _altura_local(candidato.x, candidato.y)
            if altura > maior_altitude:
                maior_altitude = altura
                proximo = candidato
    return proximo


## Textura radial em tempo de execução: halo visível de longe sem depender de novos PNGs.
func _criar_halo_farol() -> Texture2D:
    const TAMANHO: int = 64
    var imagem: Image = Image.create(TAMANHO, TAMANHO, false, Image.FORMAT_RGBA8)
    for y in TAMANHO:
        for x in TAMANHO:
            var dx: float = (float(x) + 0.5 - TAMANHO * 0.5) / (TAMANHO * 0.5)
            var dy: float = (float(y) + 0.5 - TAMANHO * 0.5) / (TAMANHO * 0.5)
            var raio_px: float = sqrt(dx * dx + dy * dy)
            var nucleo: float = 1.0 - smoothstep(0.01, 0.19, raio_px)
            var borda: float = (1.0 - smoothstep(0.20, 1.0, raio_px)) * 0.43
            var opacidade: float = clampf(nucleo + borda, 0.0, 1.0)
            imagem.set_pixel(x, y, Color(1.0, 0.92, 0.68, opacidade))
    return ImageTexture.create_from_image(imagem)


## Constrói a torre em uma elevação do interior, com lâmpada de longo alcance e feixe giratório.
func _criar_farol_no_cume(vila: Node3D) -> void:
    var cume: Vector2 = _encontrar_cume()
    var altura_cume: float = _altura_local(cume.x, cume.y)
    pos_farol = Vector2(centro.x + cume.x, centro.z + cume.y)
    _ocupado.append(Vector3(cume.x, cume.y, 11.0))  # mantém árvores fora da torre

    var pedra: StandardMaterial3D = _material(Color(0.64, 0.62, 0.57), "res://assets/texturas/ilha/rocha.png", 0.3)
    var branco: StandardMaterial3D = _material(Color(0.96, 0.95, 0.90), "res://assets/texturas/ilha/reboco.png", 0.25)
    var vermelho: StandardMaterial3D = _material(Color(0.74, 0.18, 0.14))
    var escuro: StandardMaterial3D = _material(Color(0.20, 0.18, 0.17))
    _cilindro(vila, 3.1, 2.7, 1.4, Vector3(cume.x, altura_cume - 0.65, cume.y), pedra)
    _cilindro(vila, 1.75, 1.20, 13.0, Vector3(cume.x, altura_cume - 0.35, cume.y), branco)
    _cilindro(vila, 1.65, 1.50, 2.0, Vector3(cume.x, altura_cume + 2.65, cume.y), vermelho)
    _cilindro(vila, 1.43, 1.30, 2.0, Vector3(cume.x, altura_cume + 7.15, cume.y), vermelho)
    _cilindro(vila, 1.80, 1.80, 0.42, Vector3(cume.x, altura_cume + 12.7, cume.y), escuro)

    _farol_material = _material(Color(1.0, 0.96, 0.75))
    _farol_material.emission_enabled = true
    _farol_material.emission = Color(1.0, 0.86, 0.55)
    _farol_material.emission_energy_multiplier = 0.0
    _cilindro(vila, 1.12, 1.12, 1.6, Vector3(cume.x, altura_cume + 13.15, cume.y), _farol_material)
    _cilindro(vila, 1.65, 0.18, 1.2, Vector3(cume.x, altura_cume + 14.8, cume.y), vermelho)

    var ponto_luminoso: Vector3 = Vector3(cume.x, altura_cume + 14.0, cume.y)
    _luz(vila, ponto_luminoso, 8.5, 150.0)

    _barco_observador = get_parent().get_node_or_null("Barco") as Node3D
    _farol_pivo = Node3D.new()
    _farol_pivo.name = "LanternaGiratoria"
    _farol_pivo.position = ponto_luminoso
    vila.add_child(_farol_pivo)

    _farol_foco = SpotLight3D.new()
    _farol_foco.name = "FeixeFarol"
    _farol_foco.light_color = Color(1.0, 0.94, 0.71)
    _farol_foco.spot_range = 205.0
    _farol_foco.spot_angle = 17.0
    _farol_foco.spot_attenuation = 0.75
    _farol_foco.light_energy = 0.0
    _farol_foco.shadow_enabled = false
    _farol_foco.position = Vector3(0.0, 0.0, -0.65)
    _farol_foco.rotation_degrees.x = -1.6          # aponta um pouco para baixo: o feixe encosta no mar ao longe
    _farol_pivo.add_child(_farol_foco)
    _criar_feixe_visivel(_farol_pivo)

    _farol_halo = Sprite3D.new()
    _farol_halo.name = "BrilhoFarol"
    _farol_halo.texture = _criar_halo_farol()
    _farol_halo.pixel_size = 0.11
    _farol_halo.shaded = false
    _farol_halo.no_depth_test = true
    _farol_halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _farol_halo.modulate = Color(1.0, 0.97, 0.81, 0.0)
    _farol_halo.position = ponto_luminoso
    vila.add_child(_farol_halo)


## Cone de luz aditivo: é o que se enxerga varrendo o mar de longe (o SpotLight só ilumina, não aparece no ar).
## Sem texturas: o brilho some com a distância da lâmpada e nas bordas do cone.
func _criar_feixe_visivel(pivo: Node3D) -> void:
    const COMPRIMENTO: float = 190.0
    const RAIO_FIM: float = 11.0
    const LADOS: int = 18
    var vertices := PackedVector3Array()
    var normais := PackedVector3Array()
    var indices := PackedInt32Array()
    vertices.append(Vector3(0.0, 0.0, -0.3))
    normais.append(Vector3(0.0, 0.0, 1.0))
    for i in LADOS:
        var a: float = TAU * float(i) / float(LADOS)
        vertices.append(Vector3(cos(a) * RAIO_FIM, sin(a) * RAIO_FIM, -COMPRIMENTO))
        normais.append(Vector3(cos(a), sin(a), 0.0))
    for i in LADOS:
        indices.append(0)
        indices.append(1 + i)
        indices.append(1 + (i + 1) % LADOS)
    var matriz: Array = []
    matriz.resize(Mesh.ARRAY_MAX)
    matriz[Mesh.ARRAY_VERTEX] = vertices
    matriz[Mesh.ARRAY_NORMAL] = normais
    matriz[Mesh.ARRAY_INDEX] = indices
    var malha := ArrayMesh.new()
    malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, matriz)
    var codigo := Shader.new()
    codigo.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 cor : source_color = vec3(1.0, 0.93, 0.68);
uniform float forca = 0.0;
uniform float comprimento = 190.0;
varying float v_t;
void vertex() { v_t = clamp(-VERTEX.z / comprimento, 0.0, 1.0); }
void fragment() {
    float centro = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
    float ao_longo = pow(1.0 - v_t, 1.35) * smoothstep(0.0, 0.025, v_t);
    ALBEDO = cor;
    ALPHA = clamp(forca * centro * ao_longo, 0.0, 1.0);
}
"""
    _farol_feixe_mat = ShaderMaterial.new()
    _farol_feixe_mat.shader = codigo
    _farol_feixe_mat.set_shader_parameter("comprimento", COMPRIMENTO)
    _farol_feixe = MeshInstance3D.new()
    _farol_feixe.name = "FeixeVisivel"
    _farol_feixe.mesh = malha
    _farol_feixe.material_override = _farol_feixe_mat
    _farol_feixe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _farol_feixe.rotation_degrees.x = -1.6
    pivo.add_child(_farol_feixe)


func _process(delta: float) -> void:
    if _farol_pivo != null and _farol_noite > 0.01:
        # Uma volta a cada ~14 segundos. Só gira enquanto a lanterna está acesa.
        _farol_pivo.rotate_y(delta * 0.45)
        if _farol_halo != null and _barco_observador != null:
            # Quando o foco aponta para o barco, o brilho aumenta como em um farol real.
            # Assim a varredura continua perceptível mesmo com neblina volumétrica desligada.
            var ate_barco: Vector3 = _barco_observador.global_position - _farol_pivo.global_position
            ate_barco.y = 0.0
            if ate_barco.length_squared() > 1.0:
                var frente_feixe: Vector3 = -_farol_pivo.global_transform.basis.z
                frente_feixe.y = 0.0
                var alinhamento: float = maxf(frente_feixe.normalized().dot(ate_barco.normalized()), 0.0)
                var brilho: float = 0.18 + 0.68 * pow(alinhamento, 24.0)
                _farol_halo.modulate = Color(1.0, 0.97, 0.81, brilho * _farol_noite)




## Duas boias de balizamento na entrada da baía (sistema IALA-B, o do Brasil): entrando no porto, a vermelha
## fica a boreste (direita) e a verde a bombordo (esquerda). Só a ilha da vila tem baía com canal.
## Devolve [{tipo, pos (mundo)}].
func posicoes_boias() -> Array:
    if not com_vila:
        return []
    var frente: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    var lado: Vector2 = Vector2(-frente.y, frente.x)
    var saida: Array = []
    for sinal in [-1.0, 1.0]:                                          # -1: boreste (vermelha); +1: bombordo (verde)
        var local: Vector2 = _agua_para_boia(frente * 150.0 + lado * (30.0 * float(sinal)), frente)
        saida.append({"tipo": "boreste" if sinal < 0.0 else "bombordo", "pos": Vector3(centro.x + local.x, 0.0, centro.z + local.y)})
    return saida

## Empurra o ponto (coordenadas locais) para longe da ilha até haver água funda o bastante para a boia.
func _agua_para_boia(p: Vector2, sentido: Vector2) -> Vector2:
    var q: Vector2 = p
    for i in 12:
        if _altura_local(q.x, q.y) < -2.0:
            break
        q += sentido * 8.0
    return q

## Armazéns, redes, barcos de pesca em seco e iluminação do cais: detalhes estáticos,
## sem colisão nem alteração das regras de atracação ou navegação.
func _criar_detalhes_porto() -> void:
    var detalhes := Node3D.new()
    detalhes.name = "CenarioPortuario"
    add_child(detalhes)
    var dir: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    var lado: Vector2 = Vector2(-dir.y, dir.x)
    var origem: Vector2 = Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    var giro: float = -atan2(dir.y, dir.x)
    var madeira: Material = _material(Color(0.51, 0.35, 0.21), "res://assets/texturas/ilha/madeira.png", 0.35)
    var corda: Material = _material(Color(0.77, 0.68, 0.45))
    var vermelho: StandardMaterial3D = _material(Color(0.70, 0.21, 0.16))
    var azul: StandardMaterial3D = _material(Color(0.23, 0.45, 0.55))
    # As canoas são malhas leves e precisam ser vistas dos dois lados.
    vermelho.cull_mode = BaseMaterial3D.CULL_DISABLED
    azul.cull_mode = BaseMaterial3D.CULL_DISABLED

    # Passarela alargada no acesso ao cais e duas defensas de madeira.
    var base: Vector2 = origem - dir * 5.0
    var altura_base: float = _altura_local(base.x, base.y)
    if altura_base > 0.4:
        _caixa(detalhes, Vector3(7.2, 0.22, 6.8), Vector3(base.x, altura_base + 0.11, base.y), madeira, giro)
    for s in [-1.0, 1.0]:
        var p: Vector2 = origem + lado * float(s) * 3.9 + dir * 3.0
        _cilindro(detalhes, 0.25, 0.19, 2.1, Vector3(p.x, -0.3, p.y), madeira)
        _caixa(detalhes, Vector3(0.65, 0.16, 0.4), Vector3(p.x, 1.7, p.y), corda)

    # Redes secando: dois conjuntos paralelos, longe da passagem do barco.
    for grupo in 2:
        var pos: Vector2 = origem - dir * (14.0 + float(grupo) * 5.5) + lado * 26.0
        var nivel: float = _altura_local(pos.x, pos.y)
        if nivel < 1.0 or not _livre(pos, 2.0):
            continue
        for s in [-1.0, 1.0]:
            var p: Vector2 = pos + lado * float(s) * 2.1
            _cilindro(detalhes, 0.12, 0.1, 3.0, Vector3(p.x, nivel - 0.1, p.y), madeira)
        _caixa(detalhes, Vector3(4.3, 0.12, 0.14), Vector3(pos.x, nivel + 2.4, pos.y), madeira, giro)
        for k in 7:
            var q: Vector2 = pos + lado * (float(k) - 3.0) * 0.55
            _caixa(detalhes, Vector3(0.03, 1.5, 0.03), Vector3(q.x, nivel + 1.4, q.y), corda)
        _ocupado.append(Vector3(pos.x, pos.y, 4.5))

    # Duas canoas coloridas retiradas da água: formas leves de madeira pintada.
    for k in 2:
        var p: Vector2 = origem - dir * (10.0 + float(k) * 7.0) - lado * 25.0
        var h: float = _altura_local(p.x, p.y)
        if h < 0.6 or not _livre(p, 3.0):
            continue
        var canoa := Node3D.new()
        canoa.position = Vector3(p.x, h + 0.35, p.y)
        canoa.rotation.y = giro + 0.18 * float(k)
        detalhes.add_child(canoa)
        var cor_casco: Material = vermelho if k == 0 else azul
        var casco := SurfaceTool.new()
        casco.begin(Mesh.PRIMITIVE_TRIANGLES)
        var pontos := PackedVector3Array([
            Vector3(-2.9, 0.0, 0.0), Vector3(-1.65, -0.32, -0.65), Vector3(1.65, -0.32, -0.65),
            Vector3(2.9, 0.0, 0.0), Vector3(1.65, -0.32, 0.65), Vector3(-1.65, -0.32, 0.65)])
        for idx in [0, 1, 5, 1, 2, 5, 5, 2, 4, 2, 3, 4]:
            casco.set_normal(Vector3.UP)
            casco.add_vertex(pontos[idx])
        var m := MeshInstance3D.new()
        m.mesh = casco.commit()
        m.material_override = cor_casco
        canoa.add_child(m)
        _caixa(canoa, Vector3(3.0, 0.15, 0.13), Vector3(0, 0.08, 0), madeira)
        _ocupado.append(Vector3(p.x, p.y, 4.0))

    # Postes com iluminação quente ao longo do eixo praça-cais.
    for k in 3:
        var p: Vector2 = origem - dir * (13.0 + float(k) * 13.0) - lado * 5.8
        var h: float = _altura_local(p.x, p.y)
        if h <= 0.7 or not _livre(p, 1.5):
            continue
        _cilindro(detalhes, 0.12, 0.11, 4.2, Vector3(p.x, h, p.y), madeira)
        var vidro: StandardMaterial3D = _material(Color(0.98, 0.81, 0.51))
        vidro.emission_enabled = true
        vidro.emission = Color(1.0, 0.76, 0.40)
        vidro.emission_energy_multiplier = 1.15
        _caixa(detalhes, Vector3(0.50, 0.50, 0.50), Vector3(p.x, h + 4.3, p.y), vidro)
        _luz(detalhes, Vector3(p.x, h + 4.3, p.y), 1.0, 13.0)

## Mirante discreto sobre a dorsal, com cerca de madeira e trilha de acesso.
## O marcador é puramente de exploração: não altera missões nem concede recompensas.
func _criar_mirante() -> void:
    var dir: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    var lado: Vector2 = Vector2(-dir.y, dir.x)
    var local: Vector2 = -dir * 26.0 + lado * 18.0
    var h: float = _altura_local(local.x, local.y)
    if h < 7.0:
        return
    var ponto := Node3D.new()
    ponto.name = "MiranteDaSerra"
    add_child(ponto)
    var madeira: Material = _material(Color(0.48, 0.32, 0.19), "res://assets/texturas/ilha/madeira.png", 0.4)
    var claro: Material = _material(Color(0.77, 0.67, 0.45))
    _caixa(ponto, Vector3(5.5, 0.22, 5.5), Vector3(local.x, h + 0.14, local.y), madeira)
    for dx in [-1.0, 1.0]:
        for dz in [-1.0, 1.0]:
            var base: Vector2 = local + Vector2(dx * 2.45, dz * 2.45)
            _cilindro(ponto, 0.10, 0.10, 1.25, Vector3(base.x, h + 0.16, base.y), madeira)
    for s in [-1.0, 1.0]:
        _caixa(ponto, Vector3(5.0, 0.11, 0.10), Vector3(local.x, h + 1.2, local.y + float(s) * 2.45), claro)
        _caixa(ponto, Vector3(0.10, 0.11, 5.0), Vector3(local.x + float(s) * 2.45, h + 1.2, local.y), claro)
    _ocupado.append(Vector3(local.x, local.y, 4.6))
    _mirante_pronto = true
    var origem: Vector2 = Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    var praca: Vector2 = origem - dir * 49.0 + lado * 3.0
    var fim_trilha: Vector2 = praca - dir * 17.0
    var curva: Vector2 = (fim_trilha + local) * 0.5 - lado * 10.0
    var trilha: StandardMaterial3D = _material_trilha("res://assets/texturas/ilha/trilha.png", Color(1.0, 0.92, 0.80), 0.34)
    _caminho(ponto, [fim_trilha, curva, local], 2.3, trilha)
    # Reserva a faixa da trilha para impedir coqueiros e árvores em cima da passagem.
    for trecho in [[fim_trilha, curva], [curva, local]]:
        var a: Vector2 = trecho[0]
        var b: Vector2 = trecho[1]
        var n: int = maxi(2, ceili(a.distance_to(b) / 3.5))
        for i in n + 1:
            var amostra: Vector2 = a.lerp(b, float(i) / float(n))
            _ocupado.append(Vector3(amostra.x, amostra.y, 1.7))

func _registrar_pontos_interesse() -> void:
    var dir: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    var lado: Vector2 = Vector2(-dir.y, dir.x)
    var mirante: Vector2 = -dir * 26.0 + lado * 18.0
    pontos_interesse = [
        {"nome": "Baía do Porto", "pos": Vector2(centro.x + 90.0, centro.z + 0.0), "tipo": "baia"},
        {"nome": "Recife das Tainhas", "pos": Vector2(centro.x + 143.0, centro.z - 53.0), "tipo": "recife"},
    ]
    if tem_farol and pos_farol != Vector2.ZERO:
        pontos_interesse.append({"nome": "Farol da Serra", "pos": pos_farol, "tipo": "farol"})
    if _mirante_pronto:
        pontos_interesse.append({"nome": "Mirante", "pos": Vector2(centro.x + mirante.x, centro.z + mirante.y), "tipo": "trilha"})


func _livre(p: Vector2, folga: float = 0.0) -> bool:
    for o in _ocupado:
        if Vector2(o.x, o.y).distance_to(p) < o.z + folga:
            return false
    return true

## Um coqueiro inteiro numa malha só: tronco curvo com anéis e folhas compridas que caem nas pontas.
func _malha_coqueiro(tipo: int = 0) -> ArrayMesh:
    # Três silhuetas distintas: curvo e baixo / alto e estreito / copa aberta.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var altura: float = [5.5, 7.4, 6.4][tipo]
    var curva: float = [1.6, 0.7, 2.1][tipo]
    var aneis := 8
    var lados := 7
    var pontos: Array = []
    for j in aneis + 1:
        var t := float(j) / float(aneis)
        var cc := Vector3(curva * pow(t, 1.5), altura * t, 0.25 * curva * t * t)
        var rr := lerpf(0.31, 0.13, t)
        var cor := Color(0.52, 0.40, 0.28) if j % 2 == 0 else Color(0.40, 0.31, 0.23)
        for k in lados:
            var ang := TAU * float(k) / lados
            pontos.append([cc + Vector3(cos(ang), 0.0, sin(ang)) * rr, cor])
    for j in aneis:
        for k in lados:
            var a0 := j * lados + k
            var a1 := j * lados + (k + 1) % lados
            for idx in [a0, a0 + lados, a1, a1, a0 + lados, a1 + lados]:
                st.set_color(pontos[idx][1])
                st.add_vertex(pontos[idx][0])
    var topo := Vector3(curva, altura - 0.04, curva * 0.25)
    var rng := RandomNumberGenerator.new()
    rng.seed = 99 + tipo * 71
    var folhas: int = [9, 12, 10][tipo]
    for f in folhas:
        var ang := TAU * float(f) / folhas + rng.randf_range(-0.17, 0.17)
        var dir := Vector3(cos(ang), 0.0, sin(ang))
        var lat := Vector3(-dir.z, 0.0, dir.x)
        var comp: float = rng.randf_range(3.0, 4.2) * float([0.93, 1.04, 1.13][tipo])
        var sobe := rng.randf_range(0.23, 0.68)
        var verde := Color(0.20, 0.40, 0.20).lerp(Color(0.43, 0.56, 0.24), rng.randf())
        var seg := 7
        var espinha: Array = []
        var largura: Array = []
        for j in seg + 1:
            var u := float(j) / seg
            espinha.append(topo + dir * (comp * u) + Vector3.UP * comp * (sobe * u - (0.62 + sobe) * u * u))
            largura.append(0.76 * sin(PI * clampf(u * 0.88 + 0.08, 0.0, 1.0)))
        for j in seg:
            for lado_folha in [-1.0, 1.0]:
                var e0: Vector3 = espinha[j]
                var e1: Vector3 = espinha[j + 1]
                var b0: Vector3 = e0 + lat * lado_folha * float(largura[j]) - Vector3.UP * float(largura[j]) * 0.36
                var b1: Vector3 = e1 + lat * lado_folha * float(largura[j + 1]) - Vector3.UP * float(largura[j + 1]) * 0.36
                for par in [[e0, verde.darkened(0.22)], [e1, verde.darkened(0.25)], [b0, verde],
                        [b0, verde], [e1, verde.darkened(0.20)], [b1, verde.lightened(0.11)]]:
                    st.set_color(par[1])
                    st.add_vertex(par[0])
    st.generate_normals()
    return st.commit()

func _criar_coqueiros() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 21 + semente
    var lugares: Array = [[], [], []]
    for k in 2700:
        var p := Vector2(rng.randf_range(-raio, raio), rng.randf_range(-raio, raio))
        var h := _altura_local(p.x, p.y)
        var incl := absf(_altura_local(p.x + 2.0, p.y) - h) + absf(_altura_local(p.x, p.y + 2.0) - h)
        if h < 1.4 or h > 14.0 or incl > 1.9 or not _livre(p, 2.6):
            continue
        var manchas: float = _ruido.get_noise_2d(p.x * 0.55 + 173.0, p.y * 0.55 - 95.0)
        var faixa_costeira: float = 0.86 if h < 5.0 else 0.44
        faixa_costeira *= lerpf(0.20, 1.0, smoothstep(-0.35, 0.28, manchas))
        if rng.randf() > faixa_costeira:
            continue
        var tipo := rng.randi_range(0, 2)
        lugares[tipo].append(Vector3(p.x, h - 0.1, p.y))
        _ocupado.append(Vector3(p.x, p.y, 2.3))
        if lugares[0].size() + lugares[1].size() + lugares[2].size() >= coqueiros:
            break
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.93
    for tipo in 3:
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = _malha_coqueiro(tipo)
        mm.instance_count = lugares[tipo].size()
        for i in mm.instance_count:
            var e := rng.randf_range(0.76, 1.30)
            var giro := rng.randf_range(0.0, TAU)
            var curva_natural := Basis.from_euler(Vector3(rng.randf_range(-0.06, 0.06), giro, rng.randf_range(-0.06, 0.06)))
            mm.set_instance_transform(i, Transform3D(curva_natural.scaled(Vector3(e, e * rng.randf_range(0.85, 1.18), e)), lugares[tipo][i]))
        var inst := MultiMeshInstance3D.new()
        inst.name = "CoqueirosVar%d" % tipo
        inst.multimesh = mm
        inst.material_override = mat
        add_child(inst)

func _malha_arvore_nativa() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    # Tronco com casca mais escura e copa em 3 volumes assimétricos.
    for k in 8:
        var a := TAU * float(k) / 8.0
        var b := TAU * float(k + 1) / 8.0
        var p0 := Vector3(cos(a) * 0.32, 0.0, sin(a) * 0.32)
        var p1 := Vector3(cos(b) * 0.32, 0.0, sin(b) * 0.32)
        var p2 := Vector3(cos(a) * 0.18 + 0.35, 4.0, sin(a) * 0.18)
        var p3 := Vector3(cos(b) * 0.18 + 0.35, 4.0, sin(b) * 0.18)
        for v in [p0, p2, p1, p1, p2, p3]:
            st.set_color(Color(0.30, 0.25, 0.18))
            st.add_vertex(v)
    var copas := [
        [Vector3(0.0, 4.9, 0.0), Vector3(2.2, 1.8, 2.0), Color(0.28, 0.47, 0.27)],
        [Vector3(1.45, 4.2, 0.6), Vector3(1.9, 1.4, 1.8), Color(0.34, 0.52, 0.28)],
        [Vector3(-1.4, 4.45, -0.4), Vector3(1.8, 1.4, 1.7), Color(0.23, 0.39, 0.25)],
    ]
    for copa in copas:
        var centro_c: Vector3 = copa[0]
        var ext: Vector3 = copa[1]
        var c: Color = copa[2]
        for lat in 5:
            var v0 := -PI / 2.0 + float(lat) * PI / 5.0
            var v1 := -PI / 2.0 + float(lat + 1) * PI / 5.0
            for lon in 9:
                var u0 := float(lon) * TAU / 9.0
                var u1 := float(lon + 1) * TAU / 9.0
                var pts := PackedVector3Array()
                for v in [v0, v1]:
                    for u in [u0, u1]:
                        pts.append(centro_c + Vector3(cos(v) * cos(u) * ext.x, sin(v) * ext.y, cos(v) * sin(u) * ext.z))
                for idx in [0, 2, 1, 1, 2, 3]:
                    st.set_color(c.lightened(0.06 * float(lon % 3)))
                    st.add_vertex(pts[idx])
    st.generate_normals()
    return st.commit()

func _criar_arvores_nativas() -> void:
    if not com_vila:
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = semente + 907
    var lugares: Array = []
    for k in 3000:
        var p := Vector2(rng.randf_range(-raio, raio), rng.randf_range(-raio, raio))
        var h := _altura_local(p.x, p.y)
        var inclinacao := absf(_altura_local(p.x + 2.0, p.y) - h) + absf(_altura_local(p.x, p.y + 2.0) - h)
        if h < 6.0 or h > 29.0 or inclinacao > 3.2 or not _livre(p, 4.0):
            continue
        var mata: float = _ruido.get_noise_2d(p.x * 0.65 + 46.0, p.y * 0.65 + 130.0)
        if mata < -0.17 or rng.randf() > smoothstep(-0.17, 0.28, mata):
            continue
        lugares.append(Vector3(p.x, h - 0.2, p.y))
        _ocupado.append(Vector3(p.x, p.y, 3.8))
        if lugares.size() >= 78:
            break
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = _malha_arvore_nativa()
    mm.instance_count = lugares.size()
    for i in mm.instance_count:
        var sc := rng.randf_range(0.72, 1.35)
        mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc * rng.randf_range(0.85, 1.15), sc)), lugares[i]))
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.96
    var inst := MultiMeshInstance3D.new()
    inst.name = "ArvoresNativas"
    inst.multimesh = mm
    inst.material_override = mat
    add_child(inst)

## Pedras soltas na beira da água e nas encostas, e moitas no mato.
func _criar_pedras_e_moitas() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 33
    var pedra := SphereMesh.new()
    pedra.radius = 1.0
    pedra.height = 1.5
    pedra.radial_segments = 7
    pedra.rings = 4
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = pedra
    var lugares: Array = []
    for k in 4000:
        var p := Vector2(rng.randf_range(-LADO * 0.46, LADO * 0.46), rng.randf_range(-LADO * 0.46, LADO * 0.46))
        var h := _altura_local(p.x, p.y)
        var na_beira := h > -1.6 and h < 0.9
        var na_encosta := h > 6.0 and absf(_altura_local(p.x + 2.0, p.y) - h) + absf(_altura_local(p.x, p.y + 2.0) - h) > 2.4
        if (na_beira and rng.randf() < 0.5 or na_encosta and rng.randf() < 0.25) and _livre(p, 3.0) and _dist_cais(centro + Vector3(p.x, 0, p.y)) > 9.0:
            lugares.append(Vector3(p.x, h, p.y))
        if lugares.size() >= 110:
            break
    mm.instance_count = lugares.size()
    for i in lugares.size():
        var e := rng.randf_range(0.5, 1.9) * (1.5 if rng.randf() < 0.12 else 1.0)
        var base := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(0.0, TAU), rng.randf_range(-0.5, 0.5))).scaled(Vector3(e * rng.randf_range(0.8, 1.5), e * rng.randf_range(0.55, 1.0), e))
        mm.set_instance_transform(i, Transform3D(base, lugares[i] + Vector3(0, e * 0.1, 0)))
    var mat := _material(Color(0.95, 0.93, 0.90), "res://assets/texturas/ilha/rocha.png", 0.22, "res://assets/texturas/ilha/rocha_normal.png")
    mat.uv1_world_triplanar = true
    var inst := MultiMeshInstance3D.new()
    inst.name = "Pedras"
    inst.multimesh = mm
    inst.material_override = mat
    add_child(inst)

    var moita := SphereMesh.new()
    moita.radius = 1.0
    moita.height = 1.3
    moita.radial_segments = 6
    moita.rings = 3
    var mb := MultiMesh.new()
    mb.transform_format = MultiMesh.TRANSFORM_3D
    mb.use_colors = true
    mb.mesh = moita
    var pontos: Array = []
    for k in 3000:
        var p := Vector2(rng.randf_range(-raio, raio), rng.randf_range(-raio, raio))
        var h := _altura_local(p.x, p.y)
        if h > 2.6 and h < 26.0 and _livre(p, 1.0) and absf(_altura_local(p.x + 2.0, p.y) - h) < 1.5:
            pontos.append(Vector3(p.x, h, p.y))
        if pontos.size() >= 170:
            break
    mb.instance_count = pontos.size()
    for i in pontos.size():
        var e := rng.randf_range(0.7, 1.8)
        mb.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(e * rng.randf_range(1.0, 1.6), e * 0.75, e)), pontos[i] + Vector3(0, e * 0.15, 0)))
        mb.set_instance_color(i, Color(0.16, 0.34, 0.15).lerp(Color(0.38, 0.50, 0.20), rng.randf()))
    var verde := StandardMaterial3D.new()
    verde.vertex_color_use_as_albedo = true
    verde.roughness = 0.95
    var moitas := MultiMeshInstance3D.new()
    moitas.name = "Moitas"
    moitas.multimesh = mb
    moitas.material_override = verde
    add_child(moitas)

## À noite (0 a 1) as janelas, o farol e a lanterna do cais acendem.
func acender(noite: float) -> void:
    var intensidade: float = clampf(noite, 0.0, 1.0)
    if _vidro != null:
        _vidro.emission_energy_multiplier = 2.2 * intensidade
    for luz in _luzes:
        luz.light_energy = float(luz.get_meta("forca")) * intensidade
    _farol_noite = intensidade
    if _farol_material != null:
        _farol_material.emission_energy_multiplier = 12.0 * intensidade
    if _farol_foco != null:
        _farol_foco.light_energy = 13.0 * intensidade
    if _farol_halo != null:
        _farol_halo.modulate = Color(1.0, 0.97, 0.81, 0.86 * intensidade)
    if _farol_feixe_mat != null:
        _farol_feixe_mat.set_shader_parameter("forca", 0.5 * intensidade)
    if _farol_feixe != null:
        _farol_feixe.visible = intensidade > 0.02

func _luz(pai: Node3D, pos: Vector3, forca: float, alcance: float) -> void:
    var luz := OmniLight3D.new()
    luz.light_color = Color(1.0, 0.80, 0.50)
    luz.omni_range = alcance
    luz.light_energy = 0.0
    luz.position = pos
    luz.set_meta("forca", forca)
    pai.add_child(luz)
    _luzes.append(luz)

## O desenho do fundo em volta da ilha, para o mar ficar raso e claro perto da praia e a espuma quebrar
## na areia (shaders/oceano_pintado.gdshader). "numero" é 1 ou 2: o mar aceita duas ilhas.
func ligar_ao_mar(oceano: MeshInstance3D, numero: int = 1) -> void:
    var mat := oceano.mesh.surface_get_material(0) as ShaderMaterial
    if mat == null:
        return
    var n := 192
    var img := Image.create(n, n, false, Image.FORMAT_L8)
    for j in n:
        for i in n:
            var h := _altura_local((float(i) + 0.5) / n * LADO - LADO / 2.0, (float(j) + 0.5) / n * LADO - LADO / 2.0)
            var v := clampf(inverse_lerp(FAIXA_COSTA.x, FAIXA_COSTA.y, h), 0.0, 1.0)
            img.set_pixel(i, j, Color(v, v, v))
    var sufixo := "" if numero == 1 else ("2" if numero == 2 else "3")
    mat.set_shader_parameter("tex_costa" + sufixo, ImageTexture.create_from_image(img))
    mat.set_shader_parameter("costa_centro" + sufixo, Vector2(centro.x, centro.z))
    mat.set_shader_parameter("costa_lado" + sufixo, LADO)
    mat.set_shader_parameter("costa_faixa", FAIXA_COSTA)

## O barco não pode estar aqui? (terra, água rasa demais ou o cais)
func bloqueado(pos: Vector3) -> bool:
    if altura_em(pos) > -CALADO:
        return true
    return _dist_cais(pos) < LARGURA_CAIS / 2.0 + 1.3

## Distância (m) do ponto até o segmento do cais.
func _dist_cais(pos: Vector3) -> float:
    var a := Vector2(cais_inicio.x, cais_inicio.z)
    var b := Vector2(cais_ponta.x, cais_ponta.z)
    var p := Vector2(pos.x, pos.z)
    var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
    return p.distance_to(a + (b - a) * t)

func distancia_do_cais(pos: Vector3) -> float:
    return Vector2(pos.x - cais_ponta.x, pos.z - cais_ponta.z).length()

func pode_atracar(pos: Vector3) -> bool:
    return distancia_do_cais(pos) <= ALCANCE_CAIS

## Onde o barco começa (e recomeça): encostado na plataforma da ponta do cais, de proa para o mar.
## Procura, nos dois lados, um ponto com fundo suficiente para todo o casco; se o lado for raso, avança para o mar.
func posicao_de_partida() -> Dictionary:
    var dir := Vector2(cais_ponta.x - cais_inicio.x, cais_ponta.z - cais_inicio.z).normalized()
    var lateral := Vector2(-dir.y, dir.x)
    var ponta := Vector2(cais_ponta.x, cais_ponta.z)
    var escolhido := ponta + dir * 12.0
    var achou := false
    for avanco in [0.0, 2.0, 4.0, 6.0, 9.0, 12.0, 16.0]:
        for lado in [1.0, -1.0]:
            var c: Vector2 = ponta + lateral * float(lado) * 5.7 + dir * (float(avanco) - 1.5)
            var fundo_minimo := INF
            for dx in [-4.0, 0.0, 4.0]:
                for dz in [-1.8, 0.0, 1.8]:
                    var q: Vector2 = c + dir * float(dx) + lateral * float(dz)
                    fundo_minimo = minf(fundo_minimo, -altura_em(Vector3(q.x, 0.0, q.y)))
            if fundo_minimo >= 2.0:
                escolhido = c
                achou = true
                break
        if achou:
            break
    return {"pos": Vector3(escolhido.x, 0.0, escolhido.y), "giro": atan2(-dir.x, -dir.y)}
