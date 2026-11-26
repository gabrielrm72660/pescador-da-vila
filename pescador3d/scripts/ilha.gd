extends Node3D
const Mesclador = preload("res://scripts/mesclador.gd")
const MundoDados = preload("res://scripts/mundo_dados.gd")
const Vento = preload("res://scripts/vento.gd")
const VegetacaoTropical = preload("res://scripts/vegetacao_tropical.gd")   # v0.8.5: castanhola, gameleira, mulungu, leucena
const ESPECIES_MATA := ["castanhola", "gameleira", "mulungu", "leucena"]
const VegetacaoMalhas = preload("res://scripts/vegetacao_malhas.gd")   # pinheiro, árvore, pedra e moita em níveis de detalhe 1 e 2
const LayoutPrincipal = preload("res://scripts/layout_principal.gd")   # ruas, casas e pinheiros da Vila do Porto (desenho do Gabriel)
const Arq = preload("res://scripts/arquitetura_malhas.gd")             # casas, capela, armazém, mercado, farol e cais detalhados (v0.5.1)
const TorreAntena = preload("res://scripts/torre_antena.gd")    # v0.8.3: torre de telecom (Ilha das Rocas)
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
var bonus_especie: Dictionary = {}               # v0.6.0: quanto o cais paga a mais por certas espécies (Cioba: 1.6 = 60% a mais)
var bonus_venda := 1.0                         # quanto o cais paga pelo peixe (1.3 = 30% a mais)
var preco_diesel := 4                          # R$ por litro
var tem_loja := true                           # vende melhorias do barco?
var tem_farol := true                          # cada ilha decide se tem farol; Ilha das Rocas = false
var tem_torre := false
var _plato := Vector4(0, 0, 0, -1)             # v0.8.6: (x, z, altura, raio) do platô do farol nas ilhas sem a vila grande                         # v0.8.3: torre de telecom vermelha e branca no cume (Ilha das Rocas)
var _torre: Node3D
var relevo_detalhado := true                    # espigoes e vales: apenas a ilha principal
## v0.5.8
var tem_cais := true                           # falso: ilha deserta, sem cais nem posto (não dá para atracar)
var vila_pequena := false                      # vila de pescadores pequena ao pé do cais (ruas, casas, capela)
var pinheiros_soltos := 0                      # pinheiros espalhados nas ilhas que não têm a vila desenhada
var mata_densa := 0.0                          # v0.8.6: 0 = mata em manchas (padrão); 1 = cobre quase todo o morro
var pode_editar := false                       # o Modo Construtor pode editar esta ilha (além da ilha principal)
var chave_mundo := "ilha_principal"            # nome do arquivo do mundo editado: user://mundo_<chave>.json
var arquipelago := ""                          # nome do arquipélago (só para a carta náutica)
var lado := LADO                               # lado (m) do quadrado do terreno desta ilha (ilhotas usam menos)
const TEX_COPA := "res://assets/texturas/ilha/copa.png"             # detalhe de folhagem (ferramentas/gerar_folhagem.py)
const TEX_PALMEIRA := "res://assets/texturas/ilha/palmeira.png"       # folha em pena + casca
const SHADER_COPA := "res://shaders/folhagem_vento.gdshader"          # folhagem que balança com o vento (Alta e Ultra)
const SHADER_PALMA := "res://shaders/palmeira_vento.gdshader"
const TEX_FOLHAS := "res://assets/texturas/ilha/folhas.png"           # v0.9.3: atlas de cachos de folha (ferramentas/folhas_spritecook.py)
const SHADER_FOLHAS := "res://shaders/folhas_cartas.gdshader"
const ALTURA_ESPECIE := {"castanhola": 7.0, "gameleira": 11.0, "mulungu": 6.4, "leucena": 3.6, "arvore": 7.6, "moita": 1.1}
const LADO := 300.0                            # lado da malha do terreno (m)
const DIVISOES := 270                          # v0.5.1: 180 -> 270 (células de 1,1 m): costa, rochedos e encostas mais nítidos
const CALADO := 0.9                            # o barco encalha onde a água tem menos que isso (m)
const COMPRIMENTO_CAIS := 34.0
const LARGURA_CAIS := 3.4
const ALCANCE_CAIS := 15.0                     # m da ponta do cais até onde dá para atracar
const GRUPOS_EDITAVEIS := ["Ruas", "Casas", "Props", "Postes"]     # nós que o Modo Construtor refaz e junta (Mesclador) sozinhos
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
    editavel = _usa_layout() or pode_editar
    if editavel:
        mundo = MundoDados.carregar(chave_mundo)   # {} se o jogador nunca salvou: tudo nasce do padrão
    if tem_farol and not com_vila:
        _preparar_plato_do_farol()
    _criar_terreno()
    _criar_cais()
    _criar_vila()
    if com_vila:
        _criar_detalhes_porto()
        _registrar_pontos_interesse()          # v0.5.8: o mirante ao lado do farol saiu (o Gabriel achou sem sentido)
    _criar_pinheiros()
    _criar_coqueiros()
    _criar_arvores_nativas()
    _criar_pedras_e_moitas()
    # Junta as pecas estaticas (casas, cais, muros) por material: centenas de draw calls viram dezenas.
    # Os grupos editaveis ficam de fora desta passada e sao juntos cada um no seu no: assim o Modo Construtor
    # consegue refazer so o que mudou (reconstruir) sem mexer no resto.
    var editaveis: Array = []
    for grupo in GRUPOS_EDITAVEIS:
        var no_grupo: Node3D = get_node_or_null(grupo) as Node3D
        if no_grupo != null:
            no_grupo.visible = false
            editaveis.append(no_grupo)
    var resumo: Dictionary = Mesclador.mesclar(self)
    for no_grupo in editaveis:
        no_grupo.visible = true
        Mesclador.mesclar(no_grupo)
    _reservando = false
    if OS.get_environment("PESCADOR_DIAG") == "1":
        print("Mesclador ", nome, ": ", resumo.get("antes", 0), " pecas -> ", resumo.get("depois", 0), " malhas")

## Altura do terreno (m) num ponto do MUNDO. Negativa = fundo do mar.
func altura_em(pos: Vector3) -> float:
    return _altura_local(pos.x - centro.x, pos.z - centro.z)

## Altura do terreno (m) num ponto LOCAL da ilha (mundo menos o centro).
func altura_local(x: float, z: float) -> float:
    return _altura_local(x, z)

## Modo Construtor: volta ao mundo do jogo (o publicado em res://dados, se houver) ou à ilha original (o desenho do Gabriel +
## vegetação sorteada) e apaga o arquivo salvo.
func restaurar_padrao(publicado: bool = true) -> void:
    if not editavel:
        return
    MundoDados.apagar_salvo(chave_mundo)
    _ocupado = _ocupado_fixo.duplicate()
    _reservando = true
    mundo = MundoDados.carregar_publicado(chave_mundo) if publicado else {}
    if _usa_layout():
        _padrao_da_vila()
    else:
        _padrao_simples()
    _construir_ruas()
    _construir_casas()
    if not mundo.has("props"):
        mundo["props"] = _gerar_props_padrao()
    if not mundo.has("postes"):
        mundo["postes"] = _gerar_postes_padrao()
    _construir_props()
    _construir_postes()
    if not mundo.has("pinheiros"):
        mundo["pinheiros"] = _gerar_pinheiros() if _usa_layout() else _gerar_pinheiros_soltos()
    _construir_pinheiros()
    if not mundo.has("coqueiros"):
        mundo["coqueiros"] = _gerar_coqueiros()
    _construir_coqueiros()
    if com_vila:
        if not mundo.has("arvores"):
            mundo["arvores"] = _gerar_arvores_nativas()
        _construir_arvores_nativas()
    if not mundo.has("pedras"):
        mundo["pedras"] = _gerar_pedras()
    if not mundo.has("moitas"):
        mundo["moitas"] = _gerar_moitas()
    _construir_pedras()
    _construir_moitas()
    _reservando = false
    for grupo in GRUPOS_EDITAVEIS:
        var no_grupo: Node3D = get_node_or_null(grupo) as Node3D
        if no_grupo != null:
            Mesclador.mesclar(no_grupo)

## Modo Construtor: refaz só uma categoria do mundo editável (ruas, casas, postes, props, pinheiros, coqueiros,
## arvores, pedras, moitas) a partir de "mundo". O resto da ilha não é tocado.
func reconstruir(categoria: String) -> void:
    if not editavel or (not mundo.has(categoria) and categoria != "pintura"):
        return
    _reservando = false
    match categoria:
        "ruas": _construir_ruas()
        "casas": _construir_casas()
        "postes": _construir_postes()
        "props": _construir_props()
        "pinheiros": _construir_pinheiros()
        "coqueiros": _construir_coqueiros()
        "arvores": _construir_arvores_nativas()
        "pedras": _construir_pedras()
        "moitas": _construir_moitas()
        "pintura": _carregar_pintura()
    var no_grupo: Node3D = get_node_or_null({"ruas": "Ruas", "casas": "Casas", "postes": "Postes", "props": "Props"}.get(categoria, "_")) as Node3D
    if no_grupo != null:
        Mesclador.mesclar(no_grupo)

func _altura_local(x: float, z: float) -> float:
    if com_vila:
        return _altura_principal(x, z)
    var plano := Vector2(x, z)
    var d := plano.length()
    if d > self.lado * 0.5:
        return -30.0
    var ang := atan2(z, x)
    var acesso := Vector2(-centro.x, -centro.z).normalized()
    var lado := Vector2(-acesso.y, acesso.x)
    var along := plano.dot(acesso)
    var across := plano.dot(lado)

    # Contorno-base da ilha: recortes orgânicos, mas com uma enseada protegida para a vila.
    var contorno := 1.0 + 0.15 * _ruido.get_noise_2d(cos(ang) * 90.0, sin(ang) * 90.0) + 0.07 * sin(ang * 2.0 + 0.8)
    contorno += 0.045 * _ruido.get_noise_2d(cos(ang) * 210.0 + 40.0, sin(ang) * 210.0)     # v0.5.7: pequenas enseadas e pontas
    if com_vila:
        var enseada := exp(-(pow((along - raio * 0.62) / (raio * 0.22), 2.0) + pow(across / (raio * 0.34), 2.0)))
        var alarga_costas := exp(-(pow((along + raio * 0.12) / (raio * 0.55), 2.0) + pow((across + raio * 0.03) / (raio * 0.72), 2.0)))
        var ponta_lateral := exp(-(pow((along + raio * 0.06) / (raio * 0.28), 2.0) + pow((across - raio * 0.66) / (raio * 0.22), 2.0)))
        contorno *= 1.0 - 0.16 * enseada + 0.08 * alarga_costas + 0.05 * ponta_lateral
    var r := d / maxf(raio * contorno, 1.0)

    var esc_alt: float = clampf(raio / 60.0, 0.38, 1.0)          # v0.5.8: ilhota pequena é baixa (senão vira um cone)
    var h := 13.2 * esc_alt * pow(maxf(0.0, 1.0 - r * r), 1.42) - 1.45 * smoothstep(0.74, 1.48, r) * 6.0 + 0.85
    h += _ruido.get_noise_2d(x * 2.2, z * 2.2) * 2.7 * esc_alt * clampf(1.0 - r, 0.0, 1.0)

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

    if vila_pequena:
        # chão da vila: um patamar manso que sobe da praia (o cais fica na beira; a vila, de 6 a 50 m para dentro)
        var plat: float = exp(-(pow((along - raio * 0.42) / (raio * 0.30), 2.0) + pow(across / (raio * 0.34), 2.0)))
        var nivel_v: float = 2.6 + 0.08 * (raio * 0.70 - along) + 0.5 * _ruido.get_noise_2d(x * 0.8, z * 0.8)
        h = lerpf(h, maxf(nivel_v, 1.6), plat * 0.85 * (1.0 - smoothstep(0.86, 0.98, r)))
    if r > 1.0:
        h = minf(h, lerpf(h, -9.0, smoothstep(1.0, 1.6, r)))
    var dir_p: Vector2 = plano.normalized() if d > 0.01 else Vector2.ZERO
    h = _barranco(h, x, z, r, raio * contorno, 1.0 - smoothstep(0.25, 0.70, dir_p.dot(acesso)))
    for rc in rochedos:                                              # os rochedos saem do mar, fora da praia
        var dr := Vector2((x - float(rc[0])) * 1.35, z - float(rc[1])).length()
        dr *= 1.0 + 0.35 * _ruido.get_noise_2d(x * 5.0 + 11.0, z * 5.0)
        var corpo := exp(-pow(dr / float(rc[3]), 2.2))
        h = maxf(h, -9.0 + (float(rc[2]) + 9.0) * corpo * (1.0 + 0.22 * _ruido.get_noise_2d(x * 14.0, z * 14.0 + 30.0)))
    if _plato.w > 0.0:
        # v0.8.6: o cume pontudo vira um platô gramado (o farol, a casa do faroleiro e a mureta assentam nele);
        # em volta o morro desce macio até o relevo de sempre.
        var dp: float = Vector2(x - _plato.x, z - _plato.y).length()
        # só a ponta do pico é aparada: fora do raio do platô o morro continua com o relevo dele (sem arredondar)
        var topo: float = _plato.z + 0.25 * _ruido.get_noise_2d(x * 3.0 + 7.0, z * 3.0)
        h = lerpf(h, minf(h, topo), 1.0 - smoothstep(_plato.w, _plato.w * 1.45, dp))      # apara o que passa do patamar
        h = lerpf(h, maxf(h, topo), 1.0 - smoothstep(_plato.w * 0.45, _plato.w, dp))      # e completa só o miolo (o pé do farol)
    return h


## Geografia própria da ilha principal. Morros largos + enseada protegida + plataforma portuária.
## Esta altura também é usada pelo mar, pelo bloqueio do barco, pelas casas e pela carta náutica.
func _altura_principal(x: float, z: float) -> float:
    var p := Vector2(x, z)
    var d := p.length()
    if d > self.lado * 0.5:
        return -30.0
    var frente := Vector2(-centro.x, -centro.z).normalized()
    var transversal := Vector2(-frente.y, frente.x)
    var l := p.dot(frente)   # positivo: face voltada ao continente e ao acesso
    var t := p.dot(transversal)
    var a := atan2(z, x)

    # Ilha maior, com duas pontas avançando e uma baía interna ampla e protegida.
    var sinuoso := _ruido.get_noise_2d(cos(a) * 76.0, sin(a) * 76.0)
    var costa := raio * (1.0 + 0.080 * sinuoso + 0.060 * sin(a * 3.0 + 0.2) + 0.040 * sin(a * 5.0 - 0.8)
            + 0.032 * _ruido.get_noise_2d(cos(a) * 190.0 + 40.0, sin(a) * 190.0))      # v0.5.7: pequenas enseadas e pontas
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
    h = _barranco(h, x, z, r, costa, 1.0 - smoothstep(0.10, 0.50, forca_frente))     # a face da baía (vila e cais) fica de praia

    for rc in rochedos:
        var dr := Vector2((x - float(rc[0])) * 1.30, z - float(rc[1])).length()
        dr *= 1.0 + 0.19 * _ruido.get_noise_2d(x * 5.0, z * 5.0)
        var corpo := exp(-pow(dr / float(rc[3]), 2.2))
        h = maxf(h, -9.0 + (float(rc[2]) + 9.0) * corpo)
    return h

## v0.5.7: barrancos. Em trechos da costa escolhidos por ruído no ângulo (e só onde "livre" > 0: fora da baía e do acesso),
## o terreno sobe num patamar de 3 a 7 m perto da beira e cai quase a prumo no mar (uns 4 m de largura), em vez da rampa
## de areia. A areia fica para as praias de verdade (ver shaders/terreno_pintado.gdshader: areia só onde é plano).
## Tira da lista o que ficou na água ou no pé do barranco (o terreno mudou na 0.5.7; o mundo salvo não precisa mudar).
func _em_terra(lista: Array, minimo: float) -> Array:
    return lista.filter(func(d): return _altura_local(float(d[0]), float(d[1])) >= minimo)

func _barranco(h: float, x: float, z: float, r: float, raio_costa: float, livre: float) -> float:
    if livre <= 0.001 or r < 0.70 or r > 1.3:
        return h
    var a := atan2(z, x)
    var setor := _ruido.get_noise_2d(cos(a) * 55.0 + 300.0, sin(a) * 55.0 - 140.0)
    var mascara := smoothstep(-0.08, 0.18, setor) * livre
    if mascara <= 0.001:
        return h
    var rb := r + 0.020 * _ruido.get_noise_2d(x * 3.1 + 55.0, z * 3.1 - 9.0)
    var largura: float = clampf(4.2 / maxf(raio_costa, 1.0), 0.02, 0.09)     # a queda tem ~4 m em qualquer ilha
    var alto := 3.2 + 3.8 * (0.5 + 0.5 * _ruido.get_noise_2d(x * 1.1 - 70.0, z * 1.1 + 33.0))
    var terra := maxf(h, lerpf(h, alto, smoothstep(1.0 - largura * 6.0, 1.0 - largura * 1.5, rb)))
    var mar := minf(h, -2.6 - 3.2 * smoothstep(1.0, 1.0 + largura * 4.0, rb))
    var f := lerpf(mar, terra, 1.0 - smoothstep(1.0 - largura * 0.7, 1.0 + largura * 0.3, rb))
    return lerpf(h, f, mascara)

func _criar_terreno() -> void:
    var divisoes: int = maxi(90, int(round(float(DIVISOES) * lado / LADO)))     # mesma finura (~1,1 m) em ilha menor
    var passo := lado / divisoes
    var alturas := PackedFloat32Array()
    alturas.resize((divisoes + 1) * (divisoes + 1))
    for j in divisoes + 1:
        for i in divisoes + 1:
            alturas[j * (divisoes + 1) + i] = _altura_local(-lado / 2.0 + i * passo, -lado / 2.0 + j * passo)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in divisoes + 1:
        for i in divisoes + 1:
            var h := alturas[j * (divisoes + 1) + i]
            var he := alturas[j * (divisoes + 1) + maxi(i - 1, 0)]
            var hd := alturas[j * (divisoes + 1) + mini(i + 1, divisoes)]
            var hc := alturas[maxi(j - 1, 0) * (divisoes + 1) + i]
            var hb := alturas[mini(j + 1, divisoes) * (divisoes + 1) + i]
            var normal := Vector3(he - hd, 2.0 * passo, hc - hb).normalized()
            st.set_normal(normal)
            st.add_vertex(Vector3(-lado / 2.0 + i * passo, h, -lado / 2.0 + j * passo))
    for j in divisoes:
        for i in divisoes:
            var a := j * (divisoes + 1) + i
            var b := a + 1
            var c := a + divisoes + 1
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
    if ResourceLoader.exists("res://assets/texturas/ilha/barranco.png"):
        mat.set_shader_parameter("tex_barro", load("res://assets/texturas/ilha/barranco.png"))
        mat.set_shader_parameter("tem_barro", true)
    if _plato.w > 0.0:
        mat.set_shader_parameter("altura_pedra", _plato.z + 2.5)     # v0.8.6: o topo aparado fica com mato; a encosta continua de pedra
    _material_terreno = mat
    _carregar_pintura()
    if ResourceLoader.exists("res://assets/texturas/ilha/trilha.png"):
        mat.set_shader_parameter("tex_terra", load("res://assets/texturas/ilha/trilha.png"))
    var malha := MeshInstance3D.new()
    malha.name = "Terreno"
    malha.mesh = st.commit()
    malha.material_override = mat
    add_child(malha)

## ---- v0.5.8: pincel de terreno (Modo Construtor) ---------------------------------------------------------------
## Uma imagem 256x256 cobre o quadrado do terreno: R = grama, G = terra, B = areia, A = quanto a pintura vale ali.
## Fica em mundo["pintura"] (PNG em base64) e o shader do terreno mistura por cima das cores automáticas.
const PINTURA_N := 256
var _material_terreno: ShaderMaterial
var _pintura_img: Image
var _pintura_tex: ImageTexture

func _carregar_pintura() -> void:
    _pintura_img = null
    var texto: String = str(mundo.get("pintura", ""))
    if texto != "":
        var img := Image.new()
        if img.load_png_from_buffer(Marshalls.base64_to_raw(texto)) == OK:
            img.convert(Image.FORMAT_RGBA8)
            if img.get_width() != PINTURA_N:
                img.resize(PINTURA_N, PINTURA_N)
            _pintura_img = img
    if _pintura_img == null:
        _pintura_img = Image.create(PINTURA_N, PINTURA_N, false, Image.FORMAT_RGBA8)
        _pintura_img.fill(Color(0, 0, 0, 0))
    _pintura_tex = ImageTexture.create_from_image(_pintura_img)
    if _material_terreno != null:
        _material_terreno.set_shader_parameter("tex_pintura", _pintura_tex)
        _material_terreno.set_shader_parameter("pintura_centro", Vector2(centro.x, centro.z))
        _material_terreno.set_shader_parameter("pintura_lado", lado if (texto != "" or editavel) else 0.0)

## Pinta (tipo 0 grama, 1 terra, 2 areia) ou apaga (tipo -1) um círculo em coordenadas LOCAIS. Borda macia.
func pintar_terreno(local: Vector2, raio_m: float, tipo: int, forca: float = 0.35) -> void:
    if _pintura_img == null:
        return
    var px_por_m: float = float(PINTURA_N) / lado
    var c := (local + Vector2.ONE * lado * 0.5) * px_por_m
    var r: float = maxf(1.0, raio_m * px_por_m)
    var alvo := Color(1, 0, 0) if tipo == 0 else (Color(0, 1, 0) if tipo == 1 else Color(0, 0, 1))
    for j in range(maxi(0, int(c.y - r)), mini(PINTURA_N, int(c.y + r) + 1)):
        for i in range(maxi(0, int(c.x - r)), mini(PINTURA_N, int(c.x + r) + 1)):
            var d: float = Vector2(float(i) + 0.5, float(j) + 0.5).distance_to(c) / r
            if d >= 1.0:
                continue
            var w: float = forca * (1.0 - smoothstep(0.55, 1.0, d))
            var atual: Color = _pintura_img.get_pixel(i, j)
            if tipo < 0:
                atual.a = maxf(0.0, atual.a - w * 1.6)
            else:
                atual.r = lerpf(atual.r, alvo.r, w)
                atual.g = lerpf(atual.g, alvo.g, w)
                atual.b = lerpf(atual.b, alvo.b, w)
                atual.a = minf(1.0, atual.a + w)
            _pintura_img.set_pixel(i, j, atual)
    _pintura_tex.update(_pintura_img)
    if _material_terreno != null:
        _material_terreno.set_shader_parameter("pintura_lado", lado)

func pintura_para_texto() -> String:
    if _pintura_img == null or _pintura_img.is_invisible():
        return ""
    return Marshalls.raw_to_base64(_pintura_img.save_png_to_buffer())

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

    if not tem_cais:
        cais_inicio = centro
        cais_ponta = centro
        return
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
        # Ilha das Rocas: cais tradicional curto, sem baía artificial e SEM dique.
        # Antes, a mesma função também construía um muro na Ilha das Rocas.
        var d_rata: float = 20.0
        while d_rata < self.lado * 0.5 and _altura_local(frente.x * d_rata, frente.y * d_rata) > 0.6:
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
    var cais_novo: bool = OS.get_environment("PESCADOR_CASA_SIMPLES") != "1"
    if cais_novo:
        # piso de tábuas soltas, faixa de borda e guarda-corpo (scripts/arquitetura_malhas.gd)
        var deck := Node3D.new()
        deck.name = "Piso"
        deck.position = Vector3(inicio.x, 0.0, inicio.y)
        deck.rotation.y = giro
        cais.add_child(deck)
        var pecas_cais: Dictionary = Arq.cais(COMPRIMENTO_CAIS, LARGURA_CAIS, cabeca_c, cabeca_l)
        if not _mats_arq.has("tabua"):
            var mt: StandardMaterial3D = _material(Color(1.0, 0.95, 0.88), "res://assets/texturas/ilha/madeira.png")
            mt.vertex_color_use_as_albedo = true
            _mats_arq["tabua"] = mt
        _instancia(deck, pecas_cais["tabuas"], _mats_arq["tabua"], "Tabuas")
        if not _mats_arq.has("acab_cais"):
            var ma: StandardMaterial3D = _material(Color.WHITE)
            ma.vertex_color_use_as_albedo = true
            _mats_arq["acab_cais"] = ma
    else:
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
            if cais_novo:
                _instancia(cais, _malha_arq("cabeco"), _mats_arq["acab_cais"], "Cabeco").position = Vector3(q.x, 1.26, q.y)
            else:
                _cilindro(cais, 0.15, 0.17, 0.55, Vector3(q.x, 1.26, q.y), estaca)
                _cilindro(cais, 0.18, 0.18, 0.08, Vector3(q.x, 1.38, q.y), corda)
    # Defensas (pneus) nos dois lados da plataforma.
    for a in [COMPRIMENTO_CAIS - 0.9, COMPRIMENTO_CAIS - 2.2, COMPRIMENTO_CAIS - 3.5]:
        for s in [-1.0, 1.0]:
            var q: Vector2 = inicio + dir_cais * float(a) + lateral * float(s) * (cabeca_l * 0.5 + 0.12)
            if cais_novo:
                _instancia(cais, _malha_arq("pneus"), _mats_arq["acab_cais"], "Defensa").position = Vector3(q.x, 0.55, q.y)
            else:
                _cilindro(cais, 0.2, 0.2, 0.5, Vector3(q.x, 0.55, q.y), borracha)
    # Guarda-corpo no passadiço e escada na ponta.
    if not cais_novo:              # no cais novo o guarda-corpo já faz parte da malha do piso
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
    var lanterna: StandardMaterial3D = _material(Color(1.0, 0.85, 0.5))
    lanterna.emission_enabled = true
    lanterna.emission = Color(1.0, 0.75, 0.35)
    lanterna.emission_energy_multiplier = 2.0
    var luz_pos: Vector2 = ponta - dir_cais * 0.4
    if cais_novo:
        # cargas, bomba de diesel e lampião do cais (scripts/arquitetura_malhas.gd)
        var pe := func(chave: String, mat: Material, a: float, sl: float, y: float, extra: float) -> MeshInstance3D:
            var qq: Vector2 = inicio + dir_cais * a + lateral * sl
            var mi: MeshInstance3D = _instancia(cais, _malha_arq(chave), mat, chave)
            mi.position = Vector3(qq.x, y, qq.y)
            mi.rotation.y = giro + extra
            return mi
        var acab_c: Material = _mats_arq["acab_cais"]
        var tab_c: Material = _mats_arq["tabua"]
        var fim: float = COMPRIMENTO_CAIS
        pe.call("barril_azul", acab_c, fim - 3.4, -2.9, 1.26, 0.0)
        pe.call("barril", acab_c, fim - 2.6, -2.9, 1.26, 1.0)
        pe.call("caixote", tab_c, fim - 1.4, -2.8, 1.26, 0.2)
        pe.call("caixote", tab_c, fim - 1.4, -2.8, 1.81, 0.62)
        pe.call("caixote", tab_c, fim - 0.7, -3.3, 1.26, -0.15)
        pe.call("pilha_caixas", acab_c, fim - 4.0, -1.0, 1.26, 0.3)
        pe.call("rede", acab_c, fim - 3.6, 2.6, 1.26, 0.8)
        pe.call("bobina", acab_c, fim - 1.1, 2.9, 1.26, 0.4)
        pe.call("bomba", acab_c, fim - 2.0, 1.0, 1.26, 0.0)
        if not _mats_arq.has("m_lampiao"):
            _mats_arq["m_lampiao"] = Arq.lampiao_cais()
        var lamp: Dictionary = _mats_arq["m_lampiao"]
        var lp: Node3D = Node3D.new()
        lp.name = "Lampiao"
        lp.position = Vector3(luz_pos.x, 1.26, luz_pos.y)
        lp.rotation.y = giro
        cais.add_child(lp)
        _instancia(lp, lamp["acab"], acab_c, "Mastro")
        _instancia(lp, lamp["vidro"], lanterna, "Vidro")
    else:
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
        _caixa(cais, Vector3(0.3, 0.36, 0.3), Vector3(ponta.x - dir_cais.x * 0.4, 4.5, ponta.y - dir_cais.y * 0.4), lanterna)
    _luz(cais, Vector3(luz_pos.x, 4.6, luz_pos.y), 3.0, 22.0)

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
## v0.5.1: as peças vêm de scripts/arquitetura_malhas.gd (telhado em relevo, janelas com venezianas, porta com batente,
## varanda, chaminé...). PESCADOR_CASA_SIMPLES=1 volta ao desenho antigo, só para comparar.
func _casa(pai: Node3D, pos: Vector3, giro: float, tam: Vector3, cor: Color, cor_madeira: Color, tipo: String = "casa", semente_casa: int = 0) -> Node3D:
    if OS.get_environment("PESCADOR_CASA_SIMPLES") == "1":
        return _casa_simples(pai, pos, giro, tam, cor, cor_madeira)
    var casa := Node3D.new()
    casa.position = pos + Vector3(0, -0.4, 0)
    casa.rotation.y = giro
    pai.add_child(casa)
    if _vidro == null:
        _vidro = _material(Color(0.10, 0.14, 0.18))
        _vidro.roughness = 0.25
        _vidro.emission_enabled = true
        _vidro.emission = Color(1.0, 0.72, 0.36)
        _vidro.emission_energy_multiplier = 0.0
    var pecas: Dictionary = Arq.edificio(tipo, tam, cor, cor_madeira, semente_casa)
    var mats: Dictionary = _materiais_arq(cor)
    for chave in ["parede", "telhado", "acab", "mad", "vidro"]:
        var malha: ArrayMesh = pecas[chave]
        if malha.get_surface_count() == 0:
            continue
        var mi := MeshInstance3D.new()
        mi.name = chave
        mi.mesh = malha
        mi.material_override = _vidro if chave == "vidro" else mats[chave]
        casa.add_child(mi)
    return casa

var _mats_arq: Dictionary = {}          # materiais da arquitetura (um por cor de parede; os demais são comuns a todos)

func _instancia(pai: Node3D, malha: Mesh, mat: Material, nome: String = "") -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    mi.mesh = malha
    mi.material_override = mat
    if nome != "":
        mi.name = nome
    pai.add_child(mi)
    return mi

func _materiais_arq(cor: Color) -> Dictionary:
    var k: String = "parede|" + cor.to_html(false)
    if not _mats_arq.has(k):
        var p: StandardMaterial3D = _material(cor, "res://assets/texturas/ilha/reboco.png", 0.22, "res://assets/texturas/ilha/reboco_normal.png")
        p.vertex_color_use_as_albedo = true
        _mats_arq[k] = p
    if not _mats_arq.has("telhado"):
        var t := StandardMaterial3D.new()
        t.albedo_texture = load("res://assets/texturas/ilha/telhas.png")
        t.normal_enabled = true
        t.normal_texture = load("res://assets/texturas/ilha/telhas_normal.png")
        t.roughness = 1.0
        t.metallic_specular = 0.08
        t.normal_scale = 0.5
        t.cull_mode = BaseMaterial3D.CULL_DISABLED
        _mats_arq["telhado"] = t
    if not _mats_arq.has("flat"):
        var f := StandardMaterial3D.new()
        f.vertex_color_use_as_albedo = true
        f.roughness = 1.0
        f.metallic_specular = 0.08
        _mats_arq["flat"] = f
    if not _mats_arq.has("mad"):
        # v0.8.5: portas, janelas, venezianas e beirais em madeira pintada a guache (a cor do vértice tinge a tábua)
        var md: StandardMaterial3D = _material(Color.WHITE, "res://assets/texturas/ilha/madeira_pintada.png", 0.85, "res://assets/texturas/ilha/madeira_pintada_normal.png")
        md.vertex_color_use_as_albedo = true
        md.albedo_color = Color(1.2, 1.2, 1.2)      # a tábua média é ~0,8: devolve o tom da tinta de antes
        md.normal_scale = 0.6
        _mats_arq["mad"] = md
    return {"parede": _mats_arq[k], "telhado": _mats_arq["telhado"], "acab": _mats_arq["flat"], "mad": _mats_arq["mad"]}

## O desenho antigo (caixas e dois planos de telhado), mantido só para comparação.
func _casa_simples(pai: Node3D, pos: Vector3, giro: float, tam: Vector3, cor: Color, cor_madeira: Color) -> Node3D:
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
var mundo: Dictionary = {}        # ruas, casas, postes, props e vegetação editáveis (ver mundo_dados.gd)
var editavel: bool = false        # só a ilha principal (a vila desenhada) pode ser editada no Modo Construtor
var _reservando: bool = true      # durante o primeiro desenho, cada construção reserva espaço em _ocupado
var _malhas: Dictionary = {}      # malhas de vegetação já montadas (cache)
var _mats_veg: Dictionary = {}    # materiais de vegetação por família e nível (cache)
var nivel_detalhe: int = 0        # vegetação: 0 leve (Baixa e Média), 1 detalhada (Alta), 2 ultra. Troca por definir_detalhe()
var _ocupado_fixo: Array = []     # reservas que não são editáveis (pé do cais, farol, mirante e trilha): base do "restaurar padrão"

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
    _fixar(pe_do_cais.x, pe_do_cais.y, 10.0)
    var virada := -atan2(dir.y, dir.x)
    var rng := RandomNumberGenerator.new()
    rng.seed = 3676
    var cores := [Color(0.96, 0.91, 0.80), Color(0.96, 0.80, 0.55), Color(0.70, 0.83, 0.83),
            Color(0.94, 0.78, 0.68), Color(0.88, 0.90, 0.74), Color(0.98, 0.95, 0.88)]
    var portas := [Color(0.24, 0.42, 0.51), Color(0.52, 0.28, 0.20), Color(0.30, 0.42, 0.28)]
    var areia_batida := _material_trilha("res://assets/texturas/ilha/trilha.png", Color(1.0, 0.94, 0.82), 0.30)
    var calcada := _material_trilha("res://assets/texturas/ilha/calcada.png", Color(1.0, 0.95, 0.84), 0.55)

    if not com_vila:
        # v0.5.8: ilha sem cais = deserta. Com cais: posto (Ilha das Rocas) ou vila pequena; tudo vem de "mundo" (editável).
        if not tem_cais:
            return
        _padrao_simples()
        _construir_ruas()
        _construir_casas()
        _construir_props()
        _construir_postes()
        if tem_farol:
            _criar_farol_no_cume(vila)         # v0.5.8: farol no alto do morro de São Pedro
            _arredores_do_farol(vila)          # v0.8.6: casa do faroleiro, mureta, banco e trilha até a vila
        if tem_torre:
            _criar_torre_antena()
        return

    if _usa_layout():
        # Vila desenhada à mão: ruas, casas viradas para a rua, armazém, mercado e capela (dados em "mundo").
        _padrao_da_vila()
        _construir_ruas()
        _construir_casas()
        if tem_farol:
            _criar_farol_no_cume(vila)
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
        if OS.get_environment("PESCADOR_CASA_SIMPLES") != "1":
            var banco_praca: MeshInstance3D = _instancia(vila, _malha_arq("banco"), _materiais_arq(Color.WHITE)["acab"], "BancoDaPraca")
            banco_praca.position = Vector3(pos_banco.x, _altura_local(pos_banco.x, pos_banco.y) - 0.02, pos_banco.y)
            banco_praca.rotation.y = virada + (PI if s > 0.0 else 0.0)        # quem senta olha para a fonte
            continue
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

## A vila desenhada à mão (scripts/layout_principal.gd) vale só para a ilha principal.
## PESCADOR_VILA_ANTIGA=1 (teste) volta à grade antiga, para comparar.
## Mundo padrão das ilhas sem a vila desenhada: o barracão do posto, ou a vila pequena ao pé do cais.
func _padrao_simples() -> void:
    var dir := Vector2(-centro.x, -centro.z).normalized()
    var lado := Vector2(-dir.y, dir.x)
    var pe := Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    var rng := RandomNumberGenerator.new()
    rng.seed = semente + 77
    var olhar := func(q: Vector2, alvo: Vector2) -> float:
        var v: Vector2 = alvo - q
        return -atan2(v.y, v.x)
    if not mundo.has("ruas"):
        var ruas: Array = []
        if vila_pequena:
            var a: Vector2 = pe - dir * 2.0
            var b: Vector2 = pe - dir * 46.0
            var meio: Vector2 = pe - dir * 24.0
            ruas.append({"tipo": "calcada", "pts": [[a.x, a.y], [meio.x, meio.y], [b.x, b.y]]})
            var c1: Vector2 = meio + lado * 26.0
            var c2: Vector2 = meio - lado * 24.0
            ruas.append({"tipo": "areia", "pts": [[c2.x, c2.y], [meio.x, meio.y], [c1.x, c1.y]]})
        mundo["ruas"] = ruas
    if not mundo.has("casas"):
        var casas: Array = []
        if vila_pequena:
            var n := 0
            for k in [10.0, 19.0, 32.0, 40.0]:
                for s in [-1.0, 1.0]:
                    var na_rua: Vector2 = pe - dir * float(k)
                    var q: Vector2 = na_rua + lado * float(s) * 7.6
                    if _altura_local(q.x, q.y) < 1.2:
                        continue
                    casas.append({"tipo": "casa", "x": q.x, "z": q.y, "giro": olhar.call(q, na_rua),
                            "w": rng.randf_range(5.0, 5.5), "h": rng.randf_range(3.0, 3.6), "d": rng.randf_range(5.8, 6.6),
                            "cor": n % CORES_CASA.size(), "porta": n % CORES_PORTA.size()})
                    n += 1
            var meio2: Vector2 = pe - dir * 24.0
            for s2 in [-1.0, 1.0]:
                var na_cruz: Vector2 = meio2 + lado * float(s2) * 16.0
                var q2: Vector2 = na_cruz - dir * 7.4
                if _altura_local(q2.x, q2.y) > 1.2:
                    casas.append({"tipo": "casa", "x": q2.x, "z": q2.y, "giro": olhar.call(q2, na_cruz),
                            "w": 5.2, "h": 3.3, "d": 6.2, "cor": (n + 2) % CORES_CASA.size(), "porta": n % CORES_PORTA.size()})
                    n += 1
            var fim: Vector2 = pe - dir * 46.0
            var capela: Vector2 = fim - dir * 7.0
            if _altura_local(capela.x, capela.y) > 1.2:
                casas.append({"tipo": "capela", "x": capela.x, "z": capela.y, "giro": olhar.call(capela, fim)})
            var arm: Vector2 = pe - dir * 6.0 + lado * 15.0
            if _altura_local(arm.x, arm.y) > 1.0:
                casas.append({"tipo": "armazem", "x": arm.x, "z": arm.y, "giro": olhar.call(arm, pe - dir * 6.0)})
        else:
            var barracao: Vector2 = pe - dir * 13.0 + lado * 8.0
            if _altura_local(barracao.x, barracao.y) > 0.5:
                casas.append({"tipo": "casa", "x": barracao.x, "z": barracao.y, "giro": -atan2(dir.y, dir.x),
                        "w": 6.0, "h": 3.0, "d": 6.0, "cor": 0, "porta": 0})
        mundo["casas"] = casas
    if not mundo.has("postes"):
        var postes: Array = []
        if vila_pequena:
            for k in [6.0, 20.0, 34.0]:
                var q3: Vector2 = pe - dir * float(k) + lado * 2.9
                postes.append([q3.x, q3.y])
        else:
            for k in 2:
                var q4: Vector2 = pe - dir * (6.0 + float(k) * 10.0) - lado * 3.0
                if _altura_local(q4.x, q4.y) > 0.7:
                    postes.append([q4.x, q4.y])
        mundo["postes"] = postes
    if not mundo.has("props"):
        var props: Array = []
        var g: float = -atan2(lado.y, lado.x)
        for item in [["canoa", 0, 7.0, 4.5], ["canoa", 1, 9.0, -5.5], ["rede", 0, 15.0, -9.0], ["barril", 0, 4.0, -3.4], ["caixote", 1, 5.0, 3.6]]:
            var q5: Vector2 = pe - dir * float(item[2]) + lado * float(item[3])
            if _altura_local(q5.x, q5.y) > -0.5:
                props.append({"tipo": item[0], "x": q5.x, "z": q5.y, "giro": g + rng.randf_range(-0.3, 0.3), "var": item[1]})
        mundo["props"] = props
    for c in mundo["casas"]:
        _reservar(float(c["x"]), float(c["z"]), 5.0)

## Pinheiros sorteados (ilhas sem a vila desenhada): em terra, longe da praia e das casas.
func _gerar_pinheiros_soltos() -> Array:
    if pinheiros_soltos <= 0:
        return []
    var rng := RandomNumberGenerator.new()
    rng.seed = semente + 5151
    var lista: Array = []
    for k in 3000:
        var p := Vector2(rng.randf_range(-raio, raio), rng.randf_range(-raio, raio))
        var h := _altura_local(p.x, p.y)
        if h < 2.4 or not _livre(p, 2.0):
            continue
        var mata: float = _ruido.get_noise_2d(p.x * 0.7 - 61.0, p.y * 0.7 + 18.0)
        if rng.randf() > lerpf(smoothstep(-0.30, 0.25, mata) * 0.85, 0.92, mata_densa):
            continue
        lista.append([p.x, p.y, rng.randi()])
        _ocupado.append(Vector3(p.x, p.y, 2.4))
        if lista.size() >= pinheiros_soltos:
            break
    return lista

func _usa_layout() -> bool:
    return com_vila and OS.get_environment("PESCADOR_VILA_ANTIGA") != "1"

## ---- Mundo editável (ilha principal) -----------------------------------------------------------------------------
## Tudo o que o Modo Construtor mexe vive em "mundo" (scripts/mundo_dados.gd). Sem arquivo salvo, o mundo nasce do
## desenho do Gabriel (layout_principal.gd) e da vegetação sorteada, que é guardada em "mundo" assim que nasce.
## Cada categoria tem um construtor próprio (_construir_X), que apaga e refaz o seu nó: é isso que reconstruir() chama.

const CORES_CASA := [Color(0.96, 0.91, 0.80), Color(0.96, 0.80, 0.55), Color(0.70, 0.83, 0.83),
        Color(0.94, 0.78, 0.68), Color(0.88, 0.90, 0.74), Color(0.98, 0.95, 0.88)]
const CORES_PORTA := [Color(0.24, 0.42, 0.51), Color(0.52, 0.28, 0.20), Color(0.30, 0.42, 0.28)]

## Reserva de espaço que vale para sempre (cais, farol, mirante): entra também na base do "restaurar padrão".
func _fixar(x: float, z: float, r: float) -> void:
    _ocupado.append(Vector3(x, z, r))
    _ocupado_fixo.append(Vector3(x, z, r))

## Só o primeiro desenho (padrão) reserva espaço: o que vem do arquivo já está onde o jogador quis.
func _reservar(x: float, z: float, r: float) -> void:
    if _reservando:
        _ocupado.append(Vector3(x, z, r))

func _limpar_no(nome: String) -> void:
    var antigo: Node = get_node_or_null(nome)
    if antigo != null:
        remove_child(antigo)
        antigo.queue_free()

func _novo_no(nome: String) -> Node3D:
    _limpar_no(nome)
    var no := Node3D.new()
    no.name = nome
    add_child(no)
    return no

func _rng_de(semente_item: int) -> RandomNumberGenerator:
    var r := RandomNumberGenerator.new()
    r.seed = semente_item
    return r

## Preenche o que falta em "mundo" com o desenho padrão da vila (ruas e casas do layout).
func _padrao_da_vila() -> void:
    if not mundo.has("ruas"):
        var eixo := [11, 8, 1, 3, 2]       # a rua do cais ao começo da trilha e a que cruza a vila: calçada
        var ruas: Array = []
        for k in LayoutPrincipal.RUAS.size():
            var pts: Array = []
            for p in LayoutPrincipal.RUAS[k]:
                pts.append([float(p[0]), float(p[1])])
            ruas.append({"tipo": "calcada" if k in eixo else "areia", "pts": pts})
        mundo["ruas"] = ruas
    if not mundo.has("casas"):
        var rng := RandomNumberGenerator.new()
        rng.seed = 3676
        var casas: Array = []
        var n := 0
        for c in LayoutPrincipal.CASAS:
            casas.append({"tipo": "casa", "x": float(c[0]), "z": float(c[1]), "giro": float(c[2]),
                    "w": rng.randf_range(5.0, 5.5), "h": rng.randf_range(3.0, 3.6), "d": rng.randf_range(5.8, 6.6),
                    "cor": n % CORES_CASA.size(), "porta": n % CORES_PORTA.size()})
            n += 1
        for par in [["armazem", LayoutPrincipal.ARMAZEM], ["mercado", LayoutPrincipal.MERCADO], ["capela", LayoutPrincipal.CAPELA]]:
            var e: Array = par[1]
            casas.append({"tipo": par[0], "x": float(e[0]), "z": float(e[1]), "giro": float(e[2])})
        mundo["casas"] = casas

## Ruas (vermelho do desenho): fita de chão que segue o relevo. Calçada de pedra ou areia batida.
func _construir_ruas() -> void:
    var no := _novo_no("Ruas")
    var areia_batida := _material_trilha("res://assets/texturas/ilha/trilha.png", Color(1.0, 0.94, 0.82), 0.30)
    var calcada := _material_trilha("res://assets/texturas/ilha/calcada.png", Color(1.0, 0.95, 0.84), 0.55)
    for rua in mundo["ruas"]:
        var pontos: Array = []
        for p in rua["pts"]:
            pontos.append(Vector2(float(p[0]), float(p[1])))
        if pontos.size() < 2:
            continue
        var pavimentada: bool = str(rua.get("tipo", "areia")) == "calcada"
        _caminho(no, pontos, 3.9 if pavimentada else 3.6, calcada if pavimentada else areia_batida)
        # Árvores, pedras e redes ficam fora da rua: um ponto reservado a cada ~3 m.
        for i in range(pontos.size() - 1):
            var a: Vector2 = pontos[i]
            var b: Vector2 = pontos[i + 1]
            var n: int = maxi(1, ceili(a.distance_to(b) / 3.0))
            for j in n:
                var m: Vector2 = a.lerp(b, float(j) / float(n))
                _reservar(m.x, m.y, 2.0)
        var fim: Vector2 = pontos[pontos.size() - 1]
        _reservar(fim.x, fim.y, 2.0)

## Casas (amarelo do desenho, de frente para a rua), armazém, mercado e capela.
func _construir_casas() -> void:
    var no := _novo_no("Casas")
    var idx: int = 0
    for c in mundo["casas"]:
        if not c.has("var"):
            c["var"] = idx                      # variante da casa (varanda, chaminé...): fica gravada e não muda ao mover a casa
        _construir_edificio(no, c)
        idx += 1

func _construir_edificio(no: Node3D, c: Dictionary) -> void:
    var p := Vector2(float(c["x"]), float(c["z"]))
    var giro: float = float(c["giro"])
    var tipo: String = str(c.get("tipo", "casa"))
    var sem: int = int(c.get("var", 0))
    if tipo == "armazem":
        _casa_no_terreno(no, p, giro, Vector3(9.0, 3.5, 8.0), Color(0.80, 0.78, 0.66), Color(0.33, 0.29, 0.22), "armazem", sem)
        _reservar(p.x, p.y, 7.0)
        var frente_a := Vector2(cos(giro), -sin(giro))
        var lado_a := Vector2(-frente_a.y, frente_a.x)
        for k in 3:
            var cx: Vector2 = p + frente_a * 5.3 + lado_a * (1.7 + 1.1 * float(k % 2))
            var base_y: float = _altura_local(cx.x, cx.y) + 0.45 + (0.8 if k == 2 else 0.0)
            _caixa(no, Vector3(1.2, 0.8, 1.0), Vector3(cx.x, base_y, cx.y), _material(Color(0.45, 0.34, 0.23)), giro + 0.1 * float(k))
    elif tipo == "mercado":
        _casa_no_terreno(no, p, giro, Vector3(9.0, 3.5, 7.2), Color(0.83, 0.88, 0.85), CORES_PORTA[0], "mercado", sem)
        _reservar(p.x, p.y, 7.0)
    elif tipo == "capela":
        # Capela com a torre sineira na fachada (a torre agora faz parte da malha da capela).
        if OS.get_environment("PESCADOR_CASA_SIMPLES") == "1":
            var nave := _casa_no_terreno(no, p, giro, Vector3(9.0, 4.2, 6.0), Color(0.98, 0.97, 0.92), Color(0.18, 0.35, 0.42))
            var branca := _material(Color(0.98, 0.97, 0.92), "res://assets/texturas/ilha/reboco.png", 0.24)
            _caixa(nave, Vector3(2.0, 8.0, 2.0), Vector3(4.5, 4.0, 3.3), branca)
            _caixa(nave, Vector3(0.16, 1.45, 0.16), Vector3(4.5, 9.15, 3.3), _material(Color(0.30, 0.22, 0.17)))
            _caixa(nave, Vector3(0.16, 0.16, 1.0), Vector3(4.5, 9.5, 3.3), _material(Color(0.30, 0.22, 0.17)))
        else:
            _casa_no_terreno(no, p, giro, Vector3(9.0, 4.2, 6.0), Color(0.98, 0.97, 0.92), Color(0.18, 0.35, 0.42), "capela", sem)
        _reservar(p.x, p.y, 8.0)
    else:
        var tam := Vector3(float(c.get("w", 5.2)), float(c.get("h", 3.3)), float(c.get("d", 6.2)))
        var cor_i: int = int(c.get("cor", 0)) % CORES_CASA.size()
        var porta_i: int = int(c.get("porta", 0)) % CORES_PORTA.size()
        var cor: Color = CORES_CASA[cor_i]
        var porta: Color = CORES_PORTA[porta_i]
        _casa_no_terreno(no, p, giro, tam, cor, porta, "casa", sem)
        _reservar(p.x, p.y, 4.6)

## Casa em terreno torto: o piso fica na altura média dos quatro cantos e um alicerce de pedra
## cobre o vão no lado que desce. "giro" é o da _casa (a porta, em +X, aponta para a rua).
func _casa_no_terreno(pai: Node3D, p: Vector2, giro: float, tam: Vector3, cor: Color, cor_madeira: Color, tipo: String = "casa", semente_casa: int = 0) -> Node3D:
    var frente := Vector2(cos(giro), -sin(giro))
    var lateral := Vector2(-frente.y, frente.x)
    var soma := 0.0
    var menor := INF
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            var q: Vector2 = p + frente * (tam.x * 0.5 + 0.2) * sx + lateral * (tam.z * 0.5 + 0.2) * sz
            var hq: float = _altura_local(q.x, q.y)
            soma += hq
            menor = minf(menor, hq)
    var piso: float = soma / 4.0
    var casa: Node3D = _casa(pai, Vector3(p.x, piso, p.y), giro, tam, cor, cor_madeira, tipo, semente_casa)
    var fundo: float = (piso - 0.4) - menor + 0.35          # a casa nasce 0,4 m abaixo de "piso"
    if fundo > 0.2:
        var alicerce := _material(cor.darkened(0.38), "res://assets/texturas/ilha/reboco.png", 0.22)     # caiado escuro, como o rodapé
        _caixa(casa, Vector3(tam.x + 0.30, fundo + 0.10, tam.z + 0.30), Vector3(0, -fundo * 0.5 + 0.05, 0), alicerce)
    return casa

## Pinheiro: tronco reto e copa em camadas de cones recortados (borda em dentes), verde bem escuro.
func _malha_pinheiro() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var lados := 7
    for k in lados:
        var a := TAU * float(k) / float(lados)
        var b := TAU * float(k + 1) / float(lados)
        var p0 := Vector3(cos(a) * 0.36, 0.0, sin(a) * 0.36)
        var p1 := Vector3(cos(b) * 0.36, 0.0, sin(b) * 0.36)
        var p2 := Vector3(cos(a) * 0.20, 5.0, sin(a) * 0.20)
        var p3 := Vector3(cos(b) * 0.20, 5.0, sin(b) * 0.20)
        for v in [p0, p2, p1, p1, p2, p3]:
            st.set_color(Color(0.30, 0.22, 0.15))
            st.add_vertex(v)
    var dentes := 10
    for camada in 5:
        var y0: float = 1.8 + 1.85 * float(camada)
        var raio_c: float = 2.7 - 0.48 * float(camada)
        var ponta := Vector3(0.0, y0 + 3.1, 0.0)
        var escuro := Color(0.08, 0.22, 0.14).lerp(Color(0.10, 0.26, 0.16), float(camada) / 4.0)
        var claro := Color(0.15, 0.34, 0.20).lerp(Color(0.19, 0.39, 0.23), float(camada) / 4.0)
        for k in dentes:
            var a := TAU * float(k) / float(dentes)
            var b := TAU * float(k + 1) / float(dentes)
            var ra: float = raio_c * (1.0 if k % 2 == 0 else 0.80)
            var rb: float = raio_c * (1.0 if (k + 1) % 2 == 0 else 0.80)
            var ya: float = y0 - (0.0 if k % 2 == 0 else 0.30)
            var yb: float = y0 - (0.0 if (k + 1) % 2 == 0 else 0.30)
            var va := Vector3(cos(a) * ra, ya, sin(a) * ra)
            var vb := Vector3(cos(b) * rb, yb, sin(b) * rb)
            st.set_color(escuro)
            st.add_vertex(va)
            st.set_color(escuro.lerp(claro, 0.25))
            st.add_vertex(vb)
            st.set_color(claro)
            st.add_vertex(ponta)
    st.generate_normals()
    return st.commit()

## Os pinheiros do desenho (azul-escuro). Ficam fora do desbaste da qualidade Baixa: são poucos,
## baratos (cerca de 60 triângulos) e são a cara da serra.
func _criar_pinheiros() -> void:
    if not _usa_layout() and pinheiros_soltos <= 0 and not pode_editar:
        return
    if not mundo.has("pinheiros"):
        mundo["pinheiros"] = _gerar_pinheiros() if _usa_layout() else _gerar_pinheiros_soltos()
    _construir_pinheiros()

func _gerar_pinheiros() -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = semente + 4242
    var lista: Array = []
    for p in LayoutPrincipal.PINHEIROS:
        var q := Vector2(p[0], p[1])
        var h: float = _altura_local(q.x, q.y)
        if h < 1.6 or not _livre(q, 0.4):
            continue
        lista.append([q.x, q.y, rng.randi()])
    for l in lista:
        _ocupado.append(Vector3(l[0], l[1], 2.4))
    return lista

## v0.8.5: a "mata" das ilhas. A lista continua sendo "pinheiros" (mundo salvo, Construtor), mas cada ponto vira uma
## árvore de Noronha: no alto do morro mais gameleiras; embaixo castanholas e mulungus; leucenas em touceira de três.
## A espécie sai da semente do ponto, então é sempre a mesma árvore no mesmo lugar.
static func especie_da_mata(semente_ponto: int, altura: float) -> String:
    var r := RandomNumberGenerator.new()
    r.seed = semente_ponto
    var x: float = r.randf()
    if altura > 11.0:
        return "gameleira" if x < 0.30 else ("castanhola" if x < 0.55 else ("mulungu" if x < 0.70 else "leucena"))
    return "castanhola" if x < 0.42 else ("leucena" if x < 0.74 else ("mulungu" if x < 0.88 else "gameleira"))

func _construir_pinheiros() -> void:
    _limpar_no("Pinheiros")
    for esp in ESPECIES_MATA:
        _limpar_no("Mata_" + esp)
    var lista: Array = _em_terra(mundo["pinheiros"], 1.0)
    var grupos: Dictionary = {}
    for esp in ESPECIES_MATA:
        grupos[esp] = []
    for d in lista:
        var x: float = float(d[0])
        var z: float = float(d[1])
        var h: float = _altura_local(x, z)
        var r := _rng_de(int(d[2]))
        var esp: String = especie_da_mata(int(d[2]), h)
        var sc: float = {"castanhola": r.randf_range(0.85, 1.2), "gameleira": r.randf_range(0.75, 1.05),
                "mulungu": r.randf_range(0.85, 1.2), "leucena": r.randf_range(0.9, 1.35)}[esp]
        var inclina := Basis.from_euler(Vector3(r.randf_range(-0.03, 0.03), r.randf_range(0.0, TAU), r.randf_range(-0.03, 0.03)))
        grupos[esp].append(Transform3D(inclina.scaled(Vector3(sc, sc * r.randf_range(0.92, 1.1), sc)), Vector3(x, h - 0.15, z)))
        if esp == "leucena":                               # touceira: mais duas dentro do espaço reservado do ponto
            for k in 2:
                var o := Vector2(r.randf_range(-1.8, 1.8), r.randf_range(-1.8, 1.8))
                var hl: float = _altura_local(x + o.x, z + o.y)
                if hl > 1.0:
                    grupos["leucena"].append(Transform3D(Basis(Vector3.UP, r.randf_range(0.0, TAU)).scaled(Vector3.ONE * r.randf_range(0.7, 1.05)), Vector3(x + o.x, hl - 0.15, z + o.y)))
    for esp in ESPECIES_MATA:
        var ts: Array = grupos[esp]
        if ts.is_empty():
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = malha_para(esp, nivel_detalhe)
        mm.instance_count = ts.size()
        for i in ts.size():
            mm.set_instance_transform(i, ts[i])
        var inst := MultiMeshInstance3D.new()
        inst.name = "Mata_" + esp
        inst.multimesh = mm
        if esp != "leucena":
            inst.set_meta("sem_reducao", true)             # as árvores seguram o morro cheio; a leucena rareia na Baixa
        _equipar_vegetacao(inst, esp)
        add_child(inst)

## Malhas de vegetação são caras de montar: cada tipo é feito uma vez e reaproveitado a cada reconstrução.
## Nível 0 = as malhas leves de sempre (e coqueiros, que têm uma só); níveis 1 e 2 = vegetacao_malhas.gd.
func malha_para(chave: String, nivel: int) -> Mesh:
    var n: int = clampi(nivel, 0, 2)
    if chave.begins_with("coqueiro"):
        n = 0
    var k: String = chave if n == 0 else "%s_n%d" % [chave, n]
    if not _malhas.has(k):
        if chave in ESPECIES_MATA:
            var malha_t: ArrayMesh = VegetacaoTropical.criar(chave, n)
            # v0.9.3: superfície 0 = tronco e miolo da copa, 1 = cartas de folha (cada uma com o seu material)
            malha_t.surface_set_material(0, _material_vegetacao("arvore", n))
            if malha_t.get_surface_count() > 1:
                malha_t.surface_set_material(1, _material_folhas(chave, n))
            _malhas[k] = malha_t
        elif chave in ["arvore", "moita"] and n >= 1:
            # v0.9.3: árvore nativa e moita com cartas de folha (Alta e Ultra); na Baixa/Média seguem as malhas leves
            var malha_f: ArrayMesh = VegetacaoTropical.criar(chave, n)
            malha_f.surface_set_material(0, _material_vegetacao(chave, n))
            if malha_f.get_surface_count() > 1:
                malha_f.surface_set_material(1, _material_folhas(chave, n))
            _malhas[k] = malha_f
        elif n == 0:
            match chave:
                "pinheiro": _malhas[k] = _malha_pinheiro()
                "coqueiro0": _malhas[k] = _malha_coqueiro(0)
                "coqueiro1": _malhas[k] = _malha_coqueiro(1)
                "coqueiro2": _malhas[k] = _malha_coqueiro(2)
                "arvore": _malhas[k] = _malha_arvore_nativa()
                "pedra": _malhas[k] = _malha_pedra_leve()
                "moita": _malhas[k] = _malha_moita_leve()
        else:
            _malhas[k] = VegetacaoMalhas.criar(chave, n)
    return _malhas[k]

func _malha_em_cache(chave: String) -> Mesh:
    return malha_para(chave, 0)

func _malha_pedra_leve() -> Mesh:
    var pedra := SphereMesh.new()
    pedra.radius = 1.0
    pedra.height = 1.5
    pedra.radial_segments = 7
    pedra.rings = 4
    return pedra

func _malha_moita_leve() -> Mesh:
    var moita := SphereMesh.new()
    moita.radius = 1.0
    moita.height = 1.3
    moita.radial_segments = 6
    moita.rings = 3
    return moita

## Material de cada família de vegetação no nível de detalhe dado. Folhagem em Alta e Ultra usa o shader do vento.
func _material_vegetacao(familia: String, nivel: int) -> Material:
    var k: String = "%s|%d" % [familia, clampi(nivel, 0, 2)]
    if _mats_veg.has(k):
        return _mats_veg[k]
    var vento: bool = nivel >= 1
    var m: Material = null
    match familia:
        "pinheiro": m = _material_copa(0.34, 0.96, 9.6, vento, true)
        "arvore": m = _material_copa(0.30, 0.96, 7.6, vento, true)
        "moita": m = _material_copa(0.75, 0.95, 1.1, vento, false)
        "coqueiro": m = _material_palmeira(vento)
        "pedra":
            var rocha := _material(Color(0.95, 0.93, 0.90), "res://assets/texturas/ilha/rocha.png", 0.22, "res://assets/texturas/ilha/rocha_normal.png")
            rocha.uv1_world_triplanar = true
            rocha.vertex_color_use_as_albedo = nivel >= 1       # as pedras novas trazem musgo e sombra na cor do vértice
            if nivel >= 1:
                rocha.albedo_color = Color(1.30, 1.26, 1.22)    # a cor do vértice escurece; este fator devolve o brilho da pedra antiga
            m = rocha
    _mats_veg[k] = m
    return m

## Copa (pinheiro, árvore, moita): cor do vértice + detalhe de folhagem em triplanar. Com vento, o mesmo visual num shader.
func _material_copa(escala: float, rugosidade: float, altura_ref: float, vento: bool, dois_lados: bool) -> Material:
    if vento and ResourceLoader.exists(SHADER_COPA):
        Vento.garantir()                                    # os globais do vento têm de existir antes do shader compilar
        var sm := ShaderMaterial.new()
        sm.shader = load(SHADER_COPA)
        if ResourceLoader.exists(TEX_COPA):
            sm.set_shader_parameter("tex_copa", load(TEX_COPA))
        sm.set_shader_parameter("escala_tex", escala)
        sm.set_shader_parameter("altura_ref", altura_ref)
        sm.set_shader_parameter("rugosidade", rugosidade)
        return sm
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    if dois_lados or vento:
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = rugosidade
    _aplicar_detalhe_de_folhagem(mat, escala)
    return mat

## v0.9.3: cartas de folha das árvores de Noronha (atlas em guache, recorte pela transparência, vento em Alta e Ultra).
func _material_folhas(especie: String, nivel: int) -> Material:
    var k: String = "folhas|%s|%d" % [especie, nivel]
    if _mats_veg.has(k):
        return _mats_veg[k]
    Vento.garantir()
    var sm := ShaderMaterial.new()
    sm.shader = load(SHADER_FOLHAS)
    if ResourceLoader.exists(TEX_FOLHAS):
        sm.set_shader_parameter("tex_folhas", load(TEX_FOLHAS))
    sm.set_shader_parameter("altura_ref", float(ALTURA_ESPECIE.get(especie, 7.0)))
    sm.set_shader_parameter("com_vento", nivel >= 1)
    _mats_veg[k] = sm
    return sm

func _material_palmeira(vento: bool) -> Material:
    if vento and ResourceLoader.exists(SHADER_PALMA) and ResourceLoader.exists(TEX_PALMEIRA):
        Vento.garantir()
        var sm := ShaderMaterial.new()
        sm.shader = load(SHADER_PALMA)
        sm.set_shader_parameter("tex_palma", load(TEX_PALMEIRA))
        sm.set_shader_parameter("altura_ref", 9.0)
        return sm
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.roughness = 0.93
    if ResourceLoader.exists(TEX_PALMEIRA):                    # folhas em "pena" (transparência) + casca no mesmo atlas
        mat.albedo_texture = load(TEX_PALMEIRA)
        mat.albedo_color = Color(1.40, 1.40, 1.40)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        mat.alpha_scissor_threshold = 0.38
        mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return mat

func _familia_veg(chave: String) -> String:
    if chave in ESPECIES_MATA:
        return "arvore"
    return "coqueiro" if chave.begins_with("coqueiro") else chave

## Põe num grupo (MultiMeshInstance3D) a malha e o material do nível de detalhe atual. A chave fica no grupo
## ("malha_chave") para definir_detalhe() poder trocar tudo depois.
func _equipar_vegetacao(inst: MultiMeshInstance3D, chave: String) -> void:
    inst.set_meta("malha_chave", chave)
    inst.multimesh.mesh = malha_para(chave, nivel_detalhe)
    # v0.9.3: as árvores de Noronha levam o material em cada superfície da malha (tronco/miolo e cartas de folha)
    var malha_v: Mesh = inst.multimesh.mesh
    var por_superficie: bool = malha_v is ArrayMesh and malha_v.get_surface_count() > 1
    inst.material_override = null if por_superficie else _material_vegetacao(_familia_veg(chave), nivel_detalhe)

## Troca o nível de detalhe de toda a vegetação da ilha (0 leve, 1 detalhada, 2 ultra). Barato: as malhas ficam em cache.
func definir_detalhe(nivel: int) -> void:
    var n: int = clampi(nivel, 0, 2)
    if n == nivel_detalhe:
        return
    nivel_detalhe = n
    for no in find_children("*", "MultiMeshInstance3D", false, false):
        var grupo: MultiMeshInstance3D = no as MultiMeshInstance3D
        if grupo != null and grupo.has_meta("malha_chave"):
            _equipar_vegetacao(grupo, String(grupo.get_meta("malha_chave")))

## Caixa inclinada: gira em Y (como _caixa) e depois cai ou sobe ao longo do próprio eixo X.
func _caixa_inclinada(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, giro_y: float, inclinacao: float) -> MeshInstance3D:
    var m: MeshInstance3D = _caixa(pai, tam, pos, mat)
    m.basis = Basis(Vector3.UP, giro_y) * Basis(Vector3.BACK, inclinacao)
    return m

## Rampa de tábuas que liga o fim da rua ao piso do cais. O pé do cais nasce enterrado no morro (o piso fica
## em 1,26 m e o chão ali sobe a 3 m), então a rampa acompanha o chão e termina rente ao piso. Tem travessas e corrimão.
func _criar_rampa_do_cais(pai: Node3D) -> void:
    var o := Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    var d := Vector2(cais_ponta.x - cais_inicio.x, cais_ponta.z - cais_inicio.z).normalized()
    var lat := Vector2(-d.y, d.x)
    var giro: float = -atan2(d.y, d.x)
    var tabua := _material(Color(1.0, 0.95, 0.88), "res://assets/texturas/ilha/madeira.png")
    var escura := _material(Color(0.55, 0.45, 0.38), "res://assets/texturas/ilha/madeira.png")
    var k_topo := -1.5               # onde a rua encosta (o fim da rua 11 em layout_principal.gd)
    var k_pe := 4.8                  # onde o piso do cais sai do chão
    var n := 7
    var passo: float = (k_pe - k_topo) / float(n)
    var largura := 3.0
    var piso_cais := 1.26            # topo do cais: caixa de 0,22 m centrada em y = 1,15
    var ys: Array = []
    for i in n + 1:
        var k: float = k_topo + passo * float(i)
        var p: Vector2 = o + d * k
        var chao: float = maxf(_altura_local(p.x, p.y), maxf(_altura_local(p.x + lat.x * 1.5, p.y + lat.y * 1.5), _altura_local(p.x - lat.x * 1.5, p.y - lat.y * 1.5)))
        ys.append(lerpf(chao + 0.13, piso_cais, clampf((k - 4.0) / 0.8, 0.0, 1.0)))
    for i in n:
        var k0: float = k_topo + passo * float(i)
        var y0: float = ys[i]
        var y1: float = ys[i + 1]
        var meio: Vector2 = o + d * (k0 + passo * 0.5)
        var y_meio: float = (y0 + y1) * 0.5
        var ang: float = atan2(y1 - y0, passo)
        var comp: float = sqrt(passo * passo + (y1 - y0) * (y1 - y0))
        _caixa_inclinada(pai, Vector3(comp + 0.05, 0.14, largura), Vector3(meio.x, y_meio - 0.07, meio.y), tabua, giro, ang)
        _caixa_inclinada(pai, Vector3(0.14, 0.05, largura - 0.1), Vector3(meio.x, y_meio + 0.025, meio.y), escura, giro, ang)
        # Apoio: preenche o vão entre a rampa e o chão dos lados.
        var baixo: float = minf(_altura_local(meio.x, meio.y), minf(_altura_local(meio.x + lat.x * largura * 0.5, meio.y + lat.y * largura * 0.5), _altura_local(meio.x - lat.x * largura * 0.5, meio.y - lat.y * largura * 0.5)))
        var fundo: float = (y_meio - 0.14) - baixo
        if fundo > 0.12:
            _caixa_inclinada(pai, Vector3(comp, fundo, largura - 0.5), Vector3(meio.x, y_meio - 0.14 - fundo * 0.5, meio.y), escura, giro, ang)
        for s in [-1.0, 1.0]:
            var q: Vector2 = meio + lat * float(s) * (largura * 0.5 - 0.08)
            _caixa_inclinada(pai, Vector3(comp + 0.05, 0.07, 0.07), Vector3(q.x, y_meio + 0.9, q.y), escura, giro, ang)
    for i in n + 1:
        if i % 2 != 0 and i != n:
            continue
        var pp: Vector2 = o + d * (k_topo + passo * float(i))
        for s in [-1.0, 1.0]:
            var q: Vector2 = pp + lat * float(s) * (largura * 0.5 - 0.08)
            _caixa(pai, Vector3(0.1, 0.95, 0.1), Vector3(q.x, float(ys[i]) + 0.47, q.y), escura, giro)
    for k in [0.0, 3.0]:
        var pr: Vector2 = o + d * k
        _fixar(pr.x, pr.y, 3.0)

## Busca o ponto de maior altitude no interior da ilha principal, afastado da praia e dos rochedos.
## O cume é calculado a partir da mesma função usada na malha 3D e na colisão.
## v0.8.3: torre de telecomunicações no cume (com abrigo de equipamentos e alambrado). Fica fora do Mesclador
## (tem script) e a vegetação desvia dela; à noite as luzes de balizamento piscam (acender()).
func _criar_torre_antena() -> void:
    var melhor := -INF
    var lugar := Vector2.ZERO
    for ix in range(-16, 17):
        for iz in range(-16, 17):
            var x := float(ix)
            var z := float(iz)
            var h := _altura_local(x, z)
            var desnivel := 0.0
            for o in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
                desnivel = maxf(desnivel, absf(_altura_local(x + o.x, z + o.y) - h))
            if h - desnivel * 2.0 > melhor:
                melhor = h - desnivel * 2.0
                lugar = Vector2(x, z)
    _fixar(lugar.x + 1.5, lugar.y + 1.0, 9.5)        # torre + abrigo + alambrado
    # mundo salvo no Modo Construtor (de antes da torre): tira o que cairia dentro do alambrado
    for cat in ["coqueiros", "moitas", "pedras", "pinheiros", "arvores"]:
        if mundo.has(cat):
            mundo[cat] = mundo[cat].filter(func(d): return Vector2(float(d[0]) - lugar.x - 1.5, float(d[1]) - lugar.y - 1.0).length() > 9.5)
    var base_y: float = _altura_local(lugar.x, lugar.y) + 0.15
    var giro := 0.6
    var bs := Basis(Vector3.UP, giro)
    _torre = TorreAntena.new()
    _torre.name = "TorreAntena"
    _torre.chao = func(x: float, z: float) -> float:
        var w: Vector3 = bs * Vector3(x, 0, z)
        return _altura_local(lugar.x + w.x, lugar.y + w.z) - base_y
    _torre.position = Vector3(lugar.x, base_y, lugar.y)
    _torre.rotation.y = giro
    add_child(_torre)

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
## v0.8.6: o farol deixa de ficar sozinho no pico: ponta aparada num patamar pequeno, mureta de pedra com a abertura
## virada para a trilha, banco olhando o mar e a trilha de terra que sobe da vila em zigue-zague (sem casa no topo).
func _arredores_do_farol(vila: Node3D) -> void:
    if _plato.w <= 0.0:
        return
    var c := Vector2(_plato.x, _plato.y)
    # de onde a trilha vem: o centro das casas (ou o pé do cais)
    var origem := Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    if mundo.has("casas") and not mundo["casas"].is_empty():
        var soma := Vector2.ZERO
        for k in mundo["casas"]:
            soma += Vector2(float(k["x"]), float(k["z"]))
        origem = soma / float(mundo["casas"].size())
    var para_vila: Vector2 = (origem - c).normalized()
    var lado := Vector2(-para_vila.y, para_vila.x)
    var raio: float = _plato.w
    # trilha: da vila ao platô em zigue-zague (sobe com menos inclinação)
    var entrada: Vector2 = c + para_vila * (raio - 0.5)
    var dist: float = origem.distance_to(entrada)
    var pts: Array = [origem + para_vila * -4.0]
    var n := 4
    for i in range(1, n):
        var t: float = float(i) / float(n)
        pts.append(origem.lerp(entrada, t) + lado * (7.0 if i % 2 == 1 else -7.0) * minf(1.0, dist / 60.0))
    pts.append(entrada)
    pts.append(c + para_vila * 2.5)
    var terra := _material_trilha("res://assets/texturas/ilha/trilha.png", Color(1.0, 0.94, 0.82), 0.30)
    _caminho(vila, pts, 2.2, terra)
    for i in range(pts.size() - 1):                           # a mata não nasce em cima da trilha
        var a: Vector2 = pts[i]
        var b: Vector2 = pts[i + 1]
        var passos: int = maxi(1, ceili(a.distance_to(b) / 3.0))
        for k in passos + 1:
            var q: Vector2 = a.lerp(b, float(k) / float(passos))
            _fixar(q.x, q.y, 2.6)
    _fixar(c.x, c.y, raio + 1.5)
    var giro_casa: float = -atan2(para_vila.y, para_vila.x)
    # mureta de pedra seca em volta do platô, aberta para a trilha
    var pedra := _material(Color(0.78, 0.75, 0.70), "res://assets/texturas/ilha/rocha.png", 0.35, "res://assets/texturas/ilha/rocha_normal.png")
    var ang_trilha: float = atan2(para_vila.y, para_vila.x)
    var segmentos := 22
    for k in segmentos:
        var ang: float = TAU * (float(k) + 0.5) / float(segmentos)
        if absf(angle_difference(ang, ang_trilha)) < 0.32:
            continue
        var q := c + Vector2(cos(ang), sin(ang)) * (raio - 0.6)
        var hq: float = _altura_local(q.x, q.y)
        var comp: float = TAU * (raio - 0.6) / float(segmentos) + 0.12
        var alt: float = 0.55 + 0.12 * sin(float(k) * 2.3)
        _caixa(vila, Vector3(0.5, alt + 0.3, comp), Vector3(q.x, hq + alt * 0.5 - 0.15, q.y), pedra, -ang)
    # banco olhando o mar, do lado oposto à trilha
    var p_banco: Vector2 = c - para_vila * (raio - 2.4)
    var banco: MeshInstance3D = _instancia(vila, _malha_arq("banco"), _materiais_arq(Color.WHITE)["acab"], "BancoDoFarol")
    banco.position = Vector3(p_banco.x, _altura_local(p_banco.x, p_banco.y) - 0.02, p_banco.y)
    banco.rotation.y = giro_casa + PI * 0.5
    # mundo salvo (Modo Construtor, de antes): tira a vegetação que cairia no platô ou na trilha
    for cat in ["coqueiros", "moitas", "pedras", "pinheiros", "arvores"]:
        if mundo.has(cat):
            mundo[cat] = mundo[cat].filter(func(d): return not _no_farol(Vector2(float(d[0]), float(d[1])), pts))

func _no_farol(p: Vector2, trilha: Array) -> bool:
    if p.distance_to(Vector2(_plato.x, _plato.y)) < _plato.w + 1.5:
        return true
    for i in range(trilha.size() - 1):
        var a: Vector2 = trilha[i]
        var b: Vector2 = trilha[i + 1]
        var t: float = clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
        if p.distance_to(a.lerp(b, t)) < 2.4:
            return true
    return false

func _preparar_plato_do_farol() -> void:
    var cume: Vector2 = _encontrar_cume()                 # ainda sem platô: acha o ponto mais alto de verdade
    var h: float = _altura_local(cume.x, cume.y)
    _plato = Vector4(cume.x, cume.y, h - 1.2, 7.0)

func _criar_farol_no_cume(vila: Node3D) -> void:
    var cume: Vector2 = _encontrar_cume() if _plato.w <= 0.0 else Vector2(_plato.x, _plato.y)
    var altura_cume: float = _altura_local(cume.x, cume.y)
    pos_farol = Vector2(centro.x + cume.x, centro.z + cume.y)
    _fixar(cume.x, cume.y, 11.0)  # mantém árvores fora da torre

    var pedra: StandardMaterial3D = _material(Color(0.64, 0.62, 0.57), "res://assets/texturas/ilha/rocha.png", 0.3)
    var branco: StandardMaterial3D = _material(Color(0.96, 0.95, 0.90), "res://assets/texturas/ilha/reboco.png", 0.25)
    var vermelho: StandardMaterial3D = _material(Color(0.74, 0.18, 0.14))
    var escuro: StandardMaterial3D = _material(Color(0.20, 0.18, 0.17))
    var farol_novo: bool = OS.get_environment("PESCADOR_CASA_SIMPLES") != "1"     # =1 volta ao farol de cilindros (comparação)
    var pecas_farol: Dictionary = {}
    var no_farol: Node3D = null
    if farol_novo:
        pecas_farol = Arq.farol()
        no_farol = Node3D.new()
        no_farol.name = "TorreFarol"
        no_farol.position = Vector3(cume.x, altura_cume, cume.y)
        vila.add_child(no_farol)
        var mat_pedra: StandardMaterial3D = pedra.duplicate()
        mat_pedra.vertex_color_use_as_albedo = true
        var mat_torre: StandardMaterial3D = branco.duplicate()
        mat_torre.vertex_color_use_as_albedo = true
        _instancia(no_farol, pecas_farol["pedra"], mat_pedra, "Embasamento")
        _instancia(no_farol, pecas_farol["torre"], mat_torre, "Torre")
        _instancia(no_farol, pecas_farol["acab"], _materiais_arq(Color.WHITE)["acab"], "Galeria")
    else:
        _cilindro(vila, 3.1, 2.7, 1.4, Vector3(cume.x, altura_cume - 0.65, cume.y), pedra)
        _cilindro(vila, 1.75, 1.20, 13.0, Vector3(cume.x, altura_cume - 0.35, cume.y), branco)
        _cilindro(vila, 1.65, 1.50, 2.0, Vector3(cume.x, altura_cume + 2.65, cume.y), vermelho)
        _cilindro(vila, 1.43, 1.30, 2.0, Vector3(cume.x, altura_cume + 7.15, cume.y), vermelho)
        _cilindro(vila, 1.80, 1.80, 0.42, Vector3(cume.x, altura_cume + 12.7, cume.y), escuro)

    _farol_material = _material(Color(1.0, 0.96, 0.75))
    _farol_material.emission_enabled = true
    _farol_material.emission = Color(1.0, 0.86, 0.55)
    _farol_material.emission_energy_multiplier = 0.0
    if farol_novo:
        _instancia(no_farol, pecas_farol["vidro"], _farol_material, "Lanterna")      # o vidro acende junto com o feixe
    else:
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

func _criar_detalhes_porto() -> void:
    var detalhes := Node3D.new()
    detalhes.name = "CenarioPortuario"
    add_child(detalhes)
    var dir: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    var lado: Vector2 = Vector2(-dir.y, dir.x)
    var origem: Vector2 = Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    var madeira: Material = _material(Color(0.51, 0.35, 0.21), "res://assets/texturas/ilha/madeira.png", 0.35)
    var corda: Material = _material(Color(0.77, 0.68, 0.45))

    # Rampa de tábuas da rua até o piso do cais (no lugar da antiga plataforma solta) e duas defensas de madeira.
    _criar_rampa_do_cais(detalhes)
    for s in [-1.0, 1.0]:
        var p: Vector2 = origem + lado * float(s) * 3.9 + dir * 3.0
        _cilindro(detalhes, 0.25, 0.19, 2.1, Vector3(p.x, -0.3, p.y), madeira)
        _caixa(detalhes, Vector3(0.65, 0.16, 0.4), Vector3(p.x, 1.7, p.y), corda)

    # Redes, canoas e postes são do mundo editável: nascem do padrão e depois passam a vir do arquivo.
    if not mundo.has("props"):
        mundo["props"] = _gerar_props_padrao()
    if not mundo.has("postes"):
        mundo["postes"] = _gerar_postes_padrao()
    _construir_props()
    _construir_postes()

## Redes secando (dois conjuntos paralelos, longe da passagem do barco) e duas canoas coloridas retiradas da água.
func _gerar_props_padrao() -> Array:
    var dir: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    var lado: Vector2 = Vector2(-dir.y, dir.x)
    var origem: Vector2 = Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    var giro: float = -atan2(dir.y, dir.x)
    var props: Array = []
    for grupo in 2:
        var pos: Vector2 = origem - dir * (14.0 + float(grupo) * 5.5) + lado * 26.0
        var nivel: float = _altura_local(pos.x, pos.y)
        if nivel < 1.0 or not _livre(pos, 2.0):
            continue
        props.append({"tipo": "rede", "x": pos.x, "z": pos.y, "giro": giro + PI * 0.5, "var": 0})
        _ocupado.append(Vector3(pos.x, pos.y, 4.5))
    for k in 2:
        var p: Vector2 = origem - dir * (10.0 + float(k) * 7.0) - lado * 25.0
        var h: float = _altura_local(p.x, p.y)
        if h < 0.6 or not _livre(p, 3.0):
            continue
        props.append({"tipo": "canoa", "x": p.x, "z": p.y, "giro": giro + 0.18 * float(k), "var": k})
        _ocupado.append(Vector3(p.x, p.y, 4.0))
    return props

## Postes com iluminação quente ao longo da rua que sobe do cais (na vila desenhada, os pontos vêm do layout).
func _gerar_postes_padrao() -> Array:
    var dir: Vector2 = Vector2(-centro.x, -centro.z).normalized()
    var lado: Vector2 = Vector2(-dir.y, dir.x)
    var origem: Vector2 = Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    var candidatos: Array = []
    if _usa_layout():
        for q in LayoutPrincipal.POSTES:
            candidatos.append(Vector2(q[0], q[1]))
    else:
        for k in 3:
            candidatos.append(origem - dir * (13.0 + float(k) * 13.0) - lado * 5.8)
    var lista: Array = []
    for p in candidatos:
        var h: float = _altura_local(p.x, p.y)
        # Na vila desenhada o poste fica à beira da rua, que já está reservada: a folga é negativa de propósito.
        if h <= 0.7 or not _livre(p, -1.4 if _usa_layout() else 1.5):
            continue
        lista.append([p.x, p.y])
    return lista

func _construir_postes() -> void:
    var antigo: Node = get_node_or_null("Postes")
    if antigo != null:
        for luz in antigo.find_children("*", "OmniLight3D", true, false):
            _luzes.erase(luz)
    var no := _novo_no("Postes")
    var madeira: Material = _material(Color(0.51, 0.35, 0.21), "res://assets/texturas/ilha/madeira.png", 0.35)
    for q in mundo["postes"]:
        var p := Vector2(float(q[0]), float(q[1]))
        var h: float = _altura_local(p.x, p.y)
        var vidro: StandardMaterial3D = _material(Color(0.98, 0.81, 0.51))
        vidro.emission_enabled = true
        vidro.emission = Color(1.0, 0.76, 0.40)
        vidro.emission_energy_multiplier = 1.15
        if OS.get_environment("PESCADOR_CASA_SIMPLES") != "1":
            if not _mats_arq.has("m_poste"):
                _mats_arq["m_poste"] = Arq.poste()
            var pecas_poste: Dictionary = _mats_arq["m_poste"]
            var mi_p: MeshInstance3D = _instancia(no, pecas_poste["acab"], _materiais_arq(Color.WHITE)["acab"], "Poste")
            mi_p.position = Vector3(p.x, h, p.y)
            var mi_v: MeshInstance3D = _instancia(no, pecas_poste["vidro"], vidro, "Lampiao")
            mi_v.position = Vector3(p.x, h, p.y)
        else:
            _cilindro(no, 0.12, 0.11, 4.2, Vector3(p.x, h, p.y), madeira)
            _caixa(no, Vector3(0.50, 0.50, 0.50), Vector3(p.x, h + 4.3, p.y), vidro)
        _luz(no, Vector3(p.x, h + 4.3, p.y), 1.0, 13.0)
    acender(_farol_noite)      # as luzes novas já nascem no brilho da hora atual

## Redes, canoas, caixotes, barris e bancos.
func _malha_arq(chave: String) -> Mesh:
    var k: String = "m_" + chave
    if not _mats_arq.has(k):
        match chave:
            "canoa0":
                _mats_arq[k] = Arq.canoa(Color(0.70, 0.21, 0.16))
            "canoa1":
                _mats_arq[k] = Arq.canoa(Color(0.23, 0.45, 0.55))
            "barril_azul":
                _mats_arq[k] = Arq.barril(Color(0.22, 0.42, 0.58))
            "caixote":
                _mats_arq[k] = Arq.caixote(Color(0.66, 0.48, 0.28))
            "pilha_caixas":
                _mats_arq[k] = Arq.pilha_caixas()
            "bobina":
                _mats_arq[k] = Arq.bobina_corda()
            "rede":
                _mats_arq[k] = Arq.rede_pilha()
            "bomba":
                _mats_arq[k] = Arq.bomba_diesel()
            "pneus":
                _mats_arq[k] = Arq.defensa_pneus()
            "cabeco":
                _mats_arq[k] = Arq.cabeco()
            "banco":
                _mats_arq[k] = Arq.banco()
            "varal":
                _mats_arq[k] = Arq.varal_de_redes()
            "mirante":
                _mats_arq[k] = Arq.mirante()
            "vaso", "cerca", "fogueira", "ancora", "boias", "mesa", "carrinho":
                _mats_arq[k] = Arq.decoracao(chave)
            _:
                _mats_arq[k] = Arq.barril(Color(0.50, 0.36, 0.22))
    return _mats_arq[k]

func _construir_props() -> void:
    var props_novos: bool = OS.get_environment("PESCADOR_CASA_SIMPLES") != "1"
    var no := _novo_no("Props")
    var madeira: Material = _material(Color(0.51, 0.35, 0.21), "res://assets/texturas/ilha/madeira.png", 0.35)
    var corda: Material = _material(Color(0.77, 0.68, 0.45))
    var vermelho: StandardMaterial3D = _material(Color(0.70, 0.21, 0.16))
    var azul: StandardMaterial3D = _material(Color(0.23, 0.45, 0.55))
    vermelho.cull_mode = BaseMaterial3D.CULL_DISABLED        # as canoas são malhas leves e precisam ser vistas dos dois lados
    azul.cull_mode = BaseMaterial3D.CULL_DISABLED
    var caixote: StandardMaterial3D = _material(Color(0.45, 0.34, 0.23))
    var barril: StandardMaterial3D = _material(Color(0.40, 0.28, 0.18), "res://assets/texturas/ilha/madeira.png", 0.5)
    var aro: StandardMaterial3D = _material(Color(0.17, 0.16, 0.15))
    for pr in mundo["props"]:
        var p := Vector2(float(pr["x"]), float(pr["z"]))
        var giro: float = float(pr.get("giro", 0.0))
        var variante: int = int(pr.get("var", 0))
        var h: float = _altura_local(p.x, p.y)
        var u := Vector2(cos(giro), -sin(giro))            # a direção do "comprimento" (o eixo X do objeto)
        match str(pr.get("tipo", "")):
            "rede":
                var chao: Array = []
                for s in [-1.0, 1.0]:
                    var q: Vector2 = p + u * float(s) * 2.1
                    chao.append(_altura_local(q.x, q.y))
                var nivel: float = maxf(float(chao[0]), float(chao[1]))
                if props_novos:
                    var varal: MeshInstance3D = _instancia(no, _malha_arq("varal"), _materiais_arq(Color.WHITE)["acab"], "VaralDeRedes")
                    varal.position = Vector3(p.x, nivel - 0.15, p.y)
                    varal.rotation.y = giro
                    continue
                for i in 2:
                    var q2: Vector2 = p + u * (-2.1 if i == 0 else 2.1)
                    var base: float = float(chao[i]) - 0.1
                    _cilindro(no, 0.12, 0.1, (nivel + 2.55) - base, Vector3(q2.x, base, q2.y), madeira)
                _caixa(no, Vector3(4.3, 0.12, 0.14), Vector3(p.x, nivel + 2.4, p.y), madeira, giro)
                for k in 7:
                    var q3: Vector2 = p + u * (float(k) - 3.0) * 0.55
                    _caixa(no, Vector3(0.03, 1.5, 0.03), Vector3(q3.x, nivel + 1.4, q3.y), corda)
            "canoa":
                var canoa := Node3D.new()
                canoa.position = Vector3(p.x, h + 0.35, p.y)
                canoa.rotation.y = giro
                no.add_child(canoa)
                if props_novos:
                    _instancia(canoa, _malha_arq("canoa%d" % (0 if variante == 0 else 1)), _materiais_arq(Color.WHITE)["acab"], "Casco")
                    continue
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
                m.material_override = vermelho if variante == 0 else azul
                canoa.add_child(m)
                _caixa(canoa, Vector3(3.0, 0.15, 0.13), Vector3(0, 0.08, 0), madeira)
            "caixote":
                _caixa(no, Vector3(1.2, 0.8, 1.0), Vector3(p.x, h + 0.4, p.y), caixote, giro)
                if variante == 1:
                    _caixa(no, Vector3(1.0, 0.7, 0.9), Vector3(p.x, h + 1.15, p.y), caixote, giro + 0.35)
            "barril":
                if props_novos:
                    var mi_b: MeshInstance3D = _instancia(no, _malha_arq("barril"), _materiais_arq(Color.WHITE)["acab"], "Barril")
                    mi_b.position = Vector3(p.x, h - 0.05, p.y)
                    mi_b.rotation.y = giro
                else:
                    _cilindro(no, 0.36, 0.33, 0.95, Vector3(p.x, h - 0.05, p.y), barril)
                    _cilindro(no, 0.375, 0.375, 0.07, Vector3(p.x, h + 0.2, p.y), aro)
                    _cilindro(no, 0.355, 0.355, 0.07, Vector3(p.x, h + 0.66, p.y), aro)
            "monte_rede", "bobina", "pneus", "cabeco", "pilha_caixas", "barril_azul", "caixote_novo", "bomba", "vaso", "cerca", "fogueira", "ancora", "boias", "mesa", "carrinho":
                var chave_m: String = {"monte_rede": "rede", "caixote_novo": "caixote"}.get(str(pr.get("tipo", "")), str(pr.get("tipo", "")))
                var deco: MeshInstance3D = _instancia(no, _malha_arq(chave_m), _materiais_arq(Color.WHITE)["acab"], "Decoracao")
                deco.position = Vector3(p.x, h - 0.03, p.y)
                deco.rotation.y = giro
            "banco":
                if props_novos:
                    var bc: MeshInstance3D = _instancia(no, _malha_arq("banco"), _materiais_arq(Color.WHITE)["acab"], "Banco")
                    bc.position = Vector3(p.x, h - 0.02, p.y)
                    bc.rotation.y = giro
                    continue
                _caixa(no, Vector3(2.4, 0.18, 0.62), Vector3(p.x, h + 0.55, p.y), madeira, giro)
                for s in [-1.0, 1.0]:
                    var q4: Vector2 = p + u * float(s) * 0.95
                    _caixa(no, Vector3(0.14, 0.55, 0.5), Vector3(q4.x, h + 0.27, q4.y), madeira, giro)

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
    var fim_da_trilha: Vector2 = Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z) - dir * 66.0 + lado * 3.0
    if _usa_layout():
        fim_da_trilha = Vector2(LayoutPrincipal.TRILHA_INICIO[0], LayoutPrincipal.TRILHA_INICIO[1])
    if OS.get_environment("PESCADOR_CASA_SIMPLES") != "1":
        # Mirante novo: cobertura de palha, guarda-corpo, degraus e luneta. A entrada (+X da malha) fica virada para a trilha.
        var para_a_trilha: Vector2 = fim_da_trilha - local
        var mir: MeshInstance3D = _instancia(ponto, _malha_arq("mirante"), _materiais_arq(Color.WHITE)["acab"], "Mirante")
        mir.position = Vector3(local.x, h, local.y)
        mir.rotation.y = atan2(-para_a_trilha.y, para_a_trilha.x)
    else:
        _caixa(ponto, Vector3(5.5, 0.22, 5.5), Vector3(local.x, h + 0.14, local.y), madeira)
        for dx in [-1.0, 1.0]:
            for dz in [-1.0, 1.0]:
                var base: Vector2 = local + Vector2(dx * 2.45, dz * 2.45)
                _cilindro(ponto, 0.10, 0.10, 1.25, Vector3(base.x, h + 0.16, base.y), madeira)
        for s in [-1.0, 1.0]:
            _caixa(ponto, Vector3(5.0, 0.11, 0.10), Vector3(local.x, h + 1.2, local.y + float(s) * 2.45), claro)
            _caixa(ponto, Vector3(0.10, 0.11, 5.0), Vector3(local.x + float(s) * 2.45, h + 1.2, local.y), claro)
    _fixar(local.x, local.y, 4.6)
    _mirante_pronto = true
    var origem: Vector2 = Vector2(cais_inicio.x - centro.x, cais_inicio.z - centro.z)
    var praca: Vector2 = origem - dir * 49.0 + lado * 3.0
    var fim_trilha: Vector2 = praca - dir * 17.0
    if _usa_layout():
        fim_trilha = Vector2(LayoutPrincipal.TRILHA_INICIO[0], LayoutPrincipal.TRILHA_INICIO[1])
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
            _fixar(amostra.x, amostra.y, 1.7)

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
            var indices := [a0, a0 + lados, a1, a1, a0 + lados, a1 + lados]
            var colunas_uv := [k, k, k + 1, k + 1, k, k + 1]
            var aneis_uv := [j, j + 1, j, j, j + 1, j + 1]
            for n in 6:                                   # u em volta do tronco; v na faixa de casca do atlas (parte de baixo)
                st.set_color(pontos[indices[n]][1])
                st.set_uv(Vector2(float(colunas_uv[n]) / float(lados), lerpf(0.99, 0.89, float(aneis_uv[n]) / float(aneis))))
                st.add_vertex(pontos[indices[n]][0])
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
                var v0: float = lerpf(0.862, 0.012, float(j) / float(seg))
                var v1: float = lerpf(0.862, 0.012, float(j + 1) / float(seg))
                var ub: float = 0.0 if lado_folha < 0.0 else 1.0
                for par in [[e0, verde.darkened(0.22), Vector2(0.5, v0)], [e1, verde.darkened(0.25), Vector2(0.5, v1)], [b0, verde, Vector2(ub, v0)],
                        [b0, verde, Vector2(ub, v0)], [e1, verde.darkened(0.20), Vector2(0.5, v1)], [b1, verde.lightened(0.11), Vector2(ub, v1)]]:
                    st.set_color(par[1])
                    st.set_uv(par[2])
                    st.add_vertex(par[0])
    st.generate_normals()
    return st.commit()

## Mapa de detalhe de folhagem (cachos de folhas, em tons de cinza) por cima da cor de cada vértice. Em coordenadas do
## próprio objeto (triplanar), então não precisa de UV nas malhas. Sem o arquivo, fica só a cor.
func _aplicar_detalhe_de_folhagem(mat: StandardMaterial3D, escala: float) -> void:
    if not ResourceLoader.exists(TEX_COPA):
        return
    mat.albedo_texture = load(TEX_COPA)
    mat.albedo_color = Color(1.42, 1.42, 1.42)               # compensa o escurecimento do mapa (média ~0,7)
    mat.uv1_triplanar = true
    mat.uv1_scale = Vector3(escala, escala, escala)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _criar_coqueiros() -> void:
    if not mundo.has("coqueiros"):
        mundo["coqueiros"] = _gerar_coqueiros()
    _construir_coqueiros()

func _gerar_coqueiros() -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = 21 + semente
    var lista: Array = []
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
        lista.append([p.x, p.y, rng.randi(), tipo])
        _ocupado.append(Vector3(p.x, p.y, 2.3))
        if lista.size() >= coqueiros:
            break
    return lista

func _construir_coqueiros() -> void:
    for tipo in 3:
        _limpar_no("CoqueirosVar%d" % tipo)
    var por_tipo: Array = [[], [], []]
    for d in _em_terra(mundo["coqueiros"], 1.0):
        por_tipo[clampi(int(d[3]), 0, 2)].append(d)
    for tipo in 3:
        var itens: Array = por_tipo[tipo]
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = _malha_em_cache("coqueiro%d" % tipo)
        mm.instance_count = itens.size()
        for i in mm.instance_count:
            var d: Array = itens[i]
            var h: float = _altura_local(float(d[0]), float(d[1]))
            var r := _rng_de(int(d[2]))
            var e: float = r.randf_range(0.76, 1.30)
            var giro: float = r.randf_range(0.0, TAU)
            var curva_natural := Basis.from_euler(Vector3(r.randf_range(-0.06, 0.06), giro, r.randf_range(-0.06, 0.06)))
            mm.set_instance_transform(i, Transform3D(curva_natural.scaled(Vector3(e, e * r.randf_range(0.85, 1.18), e)), Vector3(float(d[0]), h - 0.1, float(d[1]))))
        var inst := MultiMeshInstance3D.new()
        inst.name = "CoqueirosVar%d" % tipo
        inst.multimesh = mm
        _equipar_vegetacao(inst, "coqueiro%d" % tipo)
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
    if not mundo.has("arvores"):
        mundo["arvores"] = _gerar_arvores_nativas()
    _construir_arvores_nativas()

func _gerar_arvores_nativas() -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = semente + 907
    var lista: Array = []
    for k in 3000:
        var p := Vector2(rng.randf_range(-raio, raio), rng.randf_range(-raio, raio))
        var h := _altura_local(p.x, p.y)
        var inclinacao := absf(_altura_local(p.x + 2.0, p.y) - h) + absf(_altura_local(p.x, p.y + 2.0) - h)
        if h < 6.0 or h > 29.0 or inclinacao > 3.2 or not _livre(p, 4.0):
            continue
        var mata: float = _ruido.get_noise_2d(p.x * 0.65 + 46.0, p.y * 0.65 + 130.0)
        if mata < -0.17 or rng.randf() > smoothstep(-0.17, 0.28, mata):
            continue
        lista.append([p.x, p.y, rng.randi()])
        _ocupado.append(Vector3(p.x, p.y, 3.8))
        if lista.size() >= 78:
            break
    return lista

func _construir_arvores_nativas() -> void:
    _limpar_no("ArvoresNativas")
    var lista: Array = _em_terra(mundo["arvores"], 1.0)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = malha_para("arvore", nivel_detalhe)
    mm.instance_count = lista.size()
    for i in mm.instance_count:
        var d: Array = lista[i]
        var h: float = _altura_local(float(d[0]), float(d[1]))
        var r := _rng_de(int(d[2]))
        var sc: float = r.randf_range(0.72, 1.35)
        mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, r.randf_range(0.0, TAU)).scaled(Vector3(sc, sc * r.randf_range(0.85, 1.15), sc)), Vector3(float(d[0]), h - 0.2, float(d[1]))))
    var inst := MultiMeshInstance3D.new()
    inst.name = "ArvoresNativas"
    inst.multimesh = mm
    _equipar_vegetacao(inst, "arvore")
    add_child(inst)

func _criar_pedras_e_moitas() -> void:
    if not mundo.has("pedras"):
        mundo["pedras"] = _gerar_pedras()
    if not mundo.has("moitas"):
        mundo["moitas"] = _gerar_moitas()
    _construir_pedras()
    _construir_moitas()

func _gerar_pedras() -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = 33
    var lista: Array = []
    for k in 4000:
        var p := Vector2(rng.randf_range(-self.lado * 0.46, self.lado * 0.46), rng.randf_range(-self.lado * 0.46, self.lado * 0.46))
        var h := _altura_local(p.x, p.y)
        var na_beira := h > -1.6 and h < 0.9
        var na_encosta := h > 6.0 and absf(_altura_local(p.x + 2.0, p.y) - h) + absf(_altura_local(p.x, p.y + 2.0) - h) > 2.4
        if (na_beira and rng.randf() < 0.5 or na_encosta and rng.randf() < 0.25) and _livre(p, 3.0) and _dist_cais(centro + Vector3(p.x, 0, p.y)) > 9.0:
            lista.append([p.x, p.y, rng.randi()])
        if lista.size() >= 110:
            break
    return lista

func _gerar_moitas() -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = 34
    var lista: Array = []
    for k in 3000:
        var p := Vector2(rng.randf_range(-raio, raio), rng.randf_range(-raio, raio))
        var h := _altura_local(p.x, p.y)
        if h > 2.6 and h < 26.0 and _livre(p, 1.0) and absf(_altura_local(p.x + 2.0, p.y) - h) < 1.5:
            lista.append([p.x, p.y, rng.randi()])
        if lista.size() >= 170:
            break
    return lista

## Pedras soltas na beira da água e nas encostas.
func _construir_pedras() -> void:
    _limpar_no("Pedras")
    var lista: Array = mundo["pedras"]
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = malha_para("pedra", nivel_detalhe)
    mm.instance_count = lista.size()
    for i in lista.size():
        var d: Array = lista[i]
        var h: float = _altura_local(float(d[0]), float(d[1]))
        var r := _rng_de(int(d[2]))
        var e: float = r.randf_range(0.5, 1.9) * (1.5 if r.randf() < 0.12 else 1.0)
        if d.size() >= 4:                                   # v0.5.8: tamanho escolhido no editor (0 pequena, 1 média, 2 grande)
            e = [0.45, 1.1, 2.6][clampi(int(d[3]), 0, 2)] * r.randf_range(0.85, 1.15)
        var base := Basis.from_euler(Vector3(r.randf_range(-0.5, 0.5), r.randf_range(0.0, TAU), r.randf_range(-0.5, 0.5))).scaled(Vector3(e * r.randf_range(0.8, 1.5), e * r.randf_range(0.55, 1.0), e))
        mm.set_instance_transform(i, Transform3D(base, Vector3(float(d[0]), h + e * 0.1, float(d[1]))))
    var inst := MultiMeshInstance3D.new()
    inst.name = "Pedras"
    inst.multimesh = mm
    _equipar_vegetacao(inst, "pedra")
    add_child(inst)

## Moitas no mato.
func _construir_moitas() -> void:
    _limpar_no("Moitas")
    var lista: Array = _em_terra(mundo["moitas"], 0.6)
    var mb := MultiMesh.new()
    mb.transform_format = MultiMesh.TRANSFORM_3D
    mb.use_colors = true
    mb.mesh = malha_para("moita", nivel_detalhe)
    mb.instance_count = lista.size()
    for i in lista.size():
        var d: Array = lista[i]
        var h: float = _altura_local(float(d[0]), float(d[1]))
        var r := _rng_de(int(d[2]))
        var e: float = r.randf_range(0.7, 1.8)
        mb.set_instance_transform(i, Transform3D(Basis(Vector3.UP, r.randf_range(0.0, TAU)).scaled(Vector3(e * r.randf_range(1.0, 1.6), e * 0.75, e)), Vector3(float(d[0]), h + e * 0.15, float(d[1]))))
        mb.set_instance_color(i, Color(0.16, 0.34, 0.15).lerp(Color(0.38, 0.50, 0.20), r.randf()))
    var moitas := MultiMeshInstance3D.new()
    moitas.name = "Moitas"
    moitas.multimesh = mb
    _equipar_vegetacao(moitas, "moita")
    add_child(moitas)

## À noite (0 a 1) as janelas, o farol e a lanterna do cais acendem.
func acender(noite: float) -> void:
    var intensidade: float = clampf(noite, 0.0, 1.0)
    if _vidro != null:
        _vidro.emission_energy_multiplier = 2.2 * intensidade
    for luz in _luzes:
        luz.light_energy = float(luz.get_meta("forca")) * intensidade
    _farol_noite = intensidade
    if _torre != null:
        _torre.definir_noite(intensidade)
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

## v0.6.0: quanto o farol clareia a bruma em "pos" (0 nada, 1 por inteiro). O facho vale para quem está até ~560 m: perto
## do farol (< 140 m) a bruma quase some; mais longe, ela se abre só quando o facho varre na direção do barco.
func clareio_do_farol(pos: Vector3) -> float:
    if not tem_farol or _farol_pivo == null or _farol_noite < 0.01:
        return 0.0
    var ate: Vector3 = pos - _farol_pivo.global_position
    ate.y = 0.0
    var d: float = ate.length()
    if d > 560.0:
        return 0.0
    var perto: float = 1.0 - smoothstep(140.0, 380.0, d)
    var facho: float = 0.0
    if d > 1.0:
        var frente_feixe: Vector3 = -_farol_pivo.global_transform.basis.z
        frente_feixe.y = 0.0
        facho = pow(maxf(frente_feixe.normalized().dot(ate / d), 0.0), 14.0)
    var alcance: float = 1.0 - smoothstep(300.0, 560.0, d)
    return clampf(maxf(perto, 0.80 * facho * alcance), 0.0, 1.0) * _farol_noite

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
            var h := _altura_local((float(i) + 0.5) / n * self.lado - self.lado / 2.0, (float(j) + 0.5) / n * self.lado - self.lado / 2.0)
            var v := clampf(inverse_lerp(FAIXA_COSTA.x, FAIXA_COSTA.y, h), 0.0, 1.0)
            img.set_pixel(i, j, Color(v, v, v))
    var sufixo := "" if numero == 1 else ("2" if numero == 2 else "3")
    mat.set_shader_parameter("tex_costa" + sufixo, ImageTexture.create_from_image(img))
    mat.set_shader_parameter("costa_centro" + sufixo, Vector2(centro.x, centro.z))
    mat.set_shader_parameter("costa_lado" + sufixo, self.lado)
    mat.set_shader_parameter("costa_faixa", FAIXA_COSTA)

## v0.5.8: um mapa de fundo único para o mundo todo (o mar aceitava só 3 ilhas). Cada ilha pinta o seu quadrado de 300 m
## na mesma resolução de antes (1,56 m por pixel), guardando o mais raso onde dois quadrados se cruzam.
static func ligar_todas_ao_mar(lista: Array, oceano: MeshInstance3D) -> void:
    var mat := oceano.mesh.surface_get_material(0) as ShaderMaterial
    if mat == null or lista.is_empty():
        return
    var passo: float = LADO / 192.0                    # 1,56 m por pixel, como antes
    var mn := Vector2(INF, INF)
    var mx := Vector2(-INF, -INF)
    for il in lista:
        mn = mn.min(Vector2(il.centro.x, il.centro.z) - Vector2.ONE * il.lado * 0.5)
        mx = mx.max(Vector2(il.centro.x, il.centro.z) + Vector2.ONE * il.lado * 0.5)
    var lado_m: float = maxf(mx.x - mn.x, mx.y - mn.y)
    var n: int = mini(int(ceil(lado_m / passo)), 2048)
    passo = lado_m / float(n)
    var dados := PackedByteArray()
    dados.resize(n * n)
    dados.fill(0)
    for il in lista:
        var c := Vector2(il.centro.x, il.centro.z)
        var i0: int = clampi(int((c.x - il.lado * 0.5 - mn.x) / passo), 0, n - 1)
        var i1: int = clampi(int((c.x + il.lado * 0.5 - mn.x) / passo), 0, n - 1)
        var j0: int = clampi(int((c.y - il.lado * 0.5 - mn.y) / passo), 0, n - 1)
        var j1: int = clampi(int((c.y + il.lado * 0.5 - mn.y) / passo), 0, n - 1)
        for j in range(j0, j1 + 1):
            var z: float = mn.y + (float(j) + 0.5) * passo - c.y
            for i in range(i0, i1 + 1):
                var h: float = il._altura_local(mn.x + (float(i) + 0.5) * passo - c.x, z)
                if h <= FAIXA_COSTA.x:
                    continue
                var v: int = int(clampf(inverse_lerp(FAIXA_COSTA.x, FAIXA_COSTA.y, h), 0.0, 1.0) * 255.0)
                var k: int = j * n + i
                if v > dados[k]:
                    dados[k] = v
    var img := Image.create_from_data(n, n, false, Image.FORMAT_L8, dados)
    mat.set_shader_parameter("tex_costa", ImageTexture.create_from_image(img))
    mat.set_shader_parameter("costa_centro", mn + Vector2.ONE * lado_m * 0.5)
    mat.set_shader_parameter("costa_lado", lado_m)
    mat.set_shader_parameter("costa_lado2", 0.0)
    mat.set_shader_parameter("costa_lado3", 0.0)
    mat.set_shader_parameter("costa_faixa", FAIXA_COSTA)

## O barco não pode estar aqui? (terra, água rasa demais ou o cais)
func bloqueado(pos: Vector3) -> bool:
    if altura_em(pos) > -CALADO:
        return true
    return _dist_cais(pos) < LARGURA_CAIS / 2.0 + 1.3

## Distância (m) do ponto até o segmento do cais.
func _dist_cais(pos: Vector3) -> float:
    if not tem_cais or cais_inicio.distance_squared_to(cais_ponta) < 0.01:
        return 1.0e9
    var a := Vector2(cais_inicio.x, cais_inicio.z)
    var b := Vector2(cais_ponta.x, cais_ponta.z)
    var p := Vector2(pos.x, pos.z)
    var t := clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
    return p.distance_to(a + (b - a) * t)

func distancia_do_cais(pos: Vector3) -> float:
    if not tem_cais:
        return 1.0e9
    return Vector2(pos.x - cais_ponta.x, pos.z - cais_ponta.z).length()

func pode_atracar(pos: Vector3) -> bool:
    return tem_cais and distancia_do_cais(pos) <= ALCANCE_CAIS

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
