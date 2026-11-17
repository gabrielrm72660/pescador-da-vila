extends Node3D
## Ponto de entrada. Controla menu, missão de pesca e fluxo de jogo.

@onready var barco = $Barco
@onready var camera_barco = $Camera
@onready var pesca = $Pesca
@onready var interface = $Interface
@onready var som = $Som
@onready var oceano = $Oceano

const Cardumes = preload("res://scripts/cardumes.gd")
var cardumes: Node3D
const Clima = preload("res://scripts/clima.gd")
var clima: Node
var luz_barco: OmniLight3D
var luz_ligada: bool = true
const Baleias = preload("res://scripts/baleias.gd")
var baleias: Node3D
const Ilha = preload("res://scripts/ilha.gd")
var ilha: Node3D                  # a ilha do cais mais próximo do barco
var ilhas: Array = []
const Missoes = preload("res://scripts/missoes.gd")
var missoes: Node
const Melhorias = preload("res://scripts/melhorias.gd")
var melhorias: Node
const Salvamento = preload("res://scripts/salvamento.gd")
const INTERVALO_SALVAR := 45.0   # s entre salvamentos automáticos navegando
var relogio_salvar: float = 0.0
const Porao = preload("res://scripts/porao.gd")
const Economia = preload("res://scripts/economia.gd")
const Recifes = preload("res://scripts/recifes.gd")
const FaunaCosteira = preload("res://scripts/fauna_costeira.gd")
const VidaPortuaria = preload("res://scripts/vida_portuaria.gd")
const Boias = preload("res://scripts/boias.gd")
const OpcoesGraficas = preload("res://scripts/opcoes_graficas.gd")
var fauna_costeira: Node3D
var vida_portuaria: Node3D
var boias: Node3D
var graficos
var economia: Node
var recifes: Node3D
const PRECO_KIT_ISCAS: int = 25
var porao: Node

const PRECO_DIESEL := 4          # R$ por litro
const DINHEIRO_INICIAL := 30
var dinheiro: int = DINHEIRO_INICIAL
var atracado: bool = false
var ja_vendeu: bool = false

var iniciado: bool = false
var em_pausa: bool = false
var objetivo_cumprido: bool = false
var tempo_interface: float = 0.0
var pedido_reinicio: float = -10.0   # instante do primeiro R; o segundo, em até 2,5 s, confirma
var relogio: float = 0.0
var explorados: Dictionary = {}
var relogio_exploracao: float = 0.0

func _enter_tree() -> void:
    cardumes = Cardumes.new()                      # antes dos outros nós procurarem por "../Cardumes"
    cardumes.name = "Cardumes"
    add_child(cardumes)
    melhorias = Melhorias.new()
    melhorias.name = "Melhorias"
    add_child(melhorias)
    porao = Porao.new()
    porao.name = "Porao"
    add_child(porao)
    missoes = Missoes.new()
    missoes.name = "Missoes"
    add_child(missoes)
    economia = Economia.new()
    economia.name = "Economia"
    add_child(economia)
    recifes = Recifes.new()
    recifes.name = "Recifes"
    add_child(recifes)
    ilha = Ilha.new()                              # Vila do Porto: a ilha grande, com vila, loja e diesel barato
    ilha.name = "Ilha"
    ilha.raio = 128.0
    ilha.rochedos = [[136.0, 84.0, 20.0, 8.2], [148.0, 61.0, 16.0, 7.0], [143.0, -53.0, -1.8, 14.0], [154.0, -68.0, 4.0, 6.4]]
    add_child(ilha)
    var rata := Ilha.new()                         # Ilha Rata: pequena e deserta, só um posto que paga mais pelo peixe
    rata.name = "IlhaRata"
    rata.nome = "Ilha Rata"
    rata.centro = Vector3(-380.0, 0.0, -430.0)
    rata.raio = 64.0
    rata.semente = 815
    rata.pico = [12.0, -10.0, 17.0, 17.0]
    rata.morro = [-22.0, 14.0, 7.0, 20.0]
    rata.rochedos = [[-78.0, -52.0, 13.0, 6.0]]
    rata.com_vila = false
    rata.tem_farol = false
    rata.relevo_detalhado = false
    rata.coqueiros = 30
    rata.bonus_venda = 1.3
    rata.preco_diesel = 6
    rata.tem_loja = false
    add_child(rata)
    # Terceiro porto pequeno: refúgio para expedições longas ao leste.
    var conchas := Ilha.new()
    conchas.name = "IlhaConchas"
    conchas.nome = "Ilha das Conchas"
    conchas.centro = Vector3(620.0, 0.0, -370.0)
    conchas.raio = 51.0
    conchas.semente = 1931
    conchas.pico = [-9.0, 5.0, 12.0, 18.0]
    conchas.morro = [14.0, -18.0, 6.0, 16.0]
    conchas.rochedos = [[64.0, 42.0, 9.0, 6.0]]
    conchas.com_vila = false
    conchas.tem_farol = false
    conchas.relevo_detalhado = false
    conchas.coqueiros = 28
    conchas.bonus_venda = 1.18
    conchas.preco_diesel = 5
    conchas.tem_loja = false
    add_child(conchas)
    ilhas = [ilha, rata, conchas]

func _ready() -> void:
    barco.obstaculo = self
    for i in ilhas.size():
        ilhas[i].ligar_ao_mar(oceano, i + 1)
    oceano.configurar_costas(ilhas)
    oceano.tempestade_comecou.connect(func():
        interface.aviso("O céu fechou! Tempestade se aproximando. Procure abrigo perto das ilhas.")
        som.tocar("aviso", -7.0, 0.85))
    oceano.tempestade_terminou.connect(func(): interface.aviso("A tempestade se afasta e o mar começa a acalmar."))
    missoes.cumprida.connect(_missao_cumprida)
    clima = Clima.new()
    clima.name = "Clima"
    add_child(clima)
    clima.configurar($Ceu, $Sol, $Oceano)
    clima.anoiteceu.connect(func(): interface.aviso("Anoitece, e uma neblina sobe do mar. A âncora do radar leva de volta ao cais."))
    clima.amanheceu.connect(func(): interface.aviso("Amanhece. A neblina se desfaz."))
    luz_barco = OmniLight3D.new()                     # lanterna do barco: só acende à noite
    luz_barco.light_color = Color(1.0, 0.78, 0.48)
    luz_barco.omni_range = 16.0
    luz_barco.omni_attenuation = 1.3
    luz_barco.light_energy = 0.0
    luz_barco.position = Vector3(0.0, 3.4, -0.6)
    barco.add_child(luz_barco)
    baleias = Baleias.new()
    baleias.name = "Baleias"
    add_child(baleias)
    fauna_costeira = FaunaCosteira.new()
    fauna_costeira.name = "FaunaCosteira"
    add_child(fauna_costeira)
    vida_portuaria = VidaPortuaria.new()
    vida_portuaria.name = "VidaPortuaria"
    add_child(vida_portuaria)
    vida_portuaria.configurar(ilhas)
    boias = Boias.new()
    boias.name = "Boias"
    add_child(boias)
    boias.configurar(ilhas, oceano)
    graficos = OpcoesGraficas.new()
    graficos.name = "OpcoesGraficas"
    add_child(graficos)
    graficos.configurar(ilhas, $Sol, oceano, $Ceu)
    graficos.qualidade_ajustada.connect(func(texto: String): interface.aviso(texto))
    barco.encalhou.connect(func(): interface.aviso("Cuidado com a costa! Dê ré (S) para sair."))
    interface.vender_pressed.connect(vender)
    interface.volume_mudou.connect(func(grupo, valor): som.definir_volume(grupo, valor))
    interface.mudo_pressed.connect(func(): som.alternar_mudo())
    som.volumes_mudaram.connect(func(): interface.mostrar_volumes(som.volumes, som.mudo()))
    interface.mostrar_volumes(som.volumes, som.mudo())
    interface.abastecer_pressed.connect(abastecer)
    interface.zarpar_pressed.connect(zarpar)
    interface.melhoria_pressed.connect(comprar)
    interface.comprar_iscas_pressed.connect(comprar_iscas)
    interface.melhorar_linha_pressed.connect(melhorar_linha)
    melhorias.aplicar(barco, porao, pesca, interface.hud)
    barco.ativo = false
    pesca.ativo = false
    interface.iniciar_pressed.connect(iniciar_ou_retomar)
    interface.reiniciar_pressed.connect(reiniciar)
    interface.pescar_pressed.connect(func(): if iniciado and not em_pausa: pesca.acao())
    interface.pausa_pressed.connect(func(): if iniciado: alternar_pausa())
    pesca.mensagem.connect(interface.aviso)
    pesca.peixe_capturado.connect(_ao_pescar)
    barco.combustivel_baixo.connect(func(): som.tocar("aviso", -6.0); interface.aviso("Combustível baixo: menos de 20% no tanque."))
    barco.combustivel_acabou.connect(func(): som.tocar("aviso", -4.0); interface.aviso("Acabou o combustível! O barco só se arrasta a 2 nós. (R reinicia a viagem.)"))
    pesca.linha_lancada.connect(func(): som.tocar("pesca_lancar", -6.0))
    pesca.acertou.connect(func(perfeito): som.tocar("pesca_lancar", -9.0, 1.7 if perfeito else 1.35))
    pesca.errou.connect(func(): som.tocar("aviso", -14.0, 0.6))
    interface.hud.pesca = pesca
    interface.porao = porao
    interface.hud.porao = porao
    interface.conectar_mapa(barco, ilhas)
    interface.mapa.configurar_extras(recifes.pontos_carta())
    interface.mapa.configurar_batimetria(self)
    _preparar_minimapa()
    interface.hud.devolveu.connect(func(item): interface.aviso("%s devolvido ao mar." % item.especie))
    posicionar_no_cais()
    interface.mostrar_inicio(Salvamento.existe())
    atualizar_interface()

## O radar mostra o desenho das ilhas: praia, mata e águas rasas, no mesmo contorno da carta (tecla M).
func _preparar_minimapa() -> void:
    var dados: Array = []
    for i in ilhas:
        dados.append({
            "centro": Vector2(i.centro.x, i.centro.z), "raio": i.raio,
            "raso": interface.mapa._contorno(i, -5.0), "linha": interface.mapa._contorno(i, 0.0), "alto": interface.mapa._contorno(i, 7.0),
            "cais": [Vector2(i.cais_inicio.x, i.cais_inicio.z), Vector2(i.cais_ponta.x, i.cais_ponta.z)]})
    interface.hud.radar_ilhas = dados
    interface.hud.barco_ref = barco
    interface.hud.radar_boias = boias.dados_radar

func salvar() -> void:
    if iniciado and pesca.estado == pesca.Estado.PRONTO:
        Salvamento.salvar(self)
    relogio_salvar = 0.0

func _notification(o_que: int) -> void:
    if o_que == NOTIFICATION_WM_CLOSE_REQUEST:              # fechou a janela: guarda a viagem antes de sair
        salvar()

func _process(delta: float) -> void:
    relogio += delta
    var pode_navegar: bool = iniciado and not em_pausa and not atracado and not graficos.esta_aberto()
    barco.ativo = pode_navegar
    pesca.ativo = pode_navegar
    oceano.simulando = pode_navegar
    cardumes.simulando = pode_navegar
    if baleias != null:
        baleias.simulando = pode_navegar
    fauna_costeira.simulando = pode_navegar
    vida_portuaria.simulando = iniciado and not em_pausa and not graficos.esta_aberto()
    if pode_navegar:
        relogio_exploracao += delta
        if relogio_exploracao >= 1.0:
            relogio_exploracao = 0.0
            _verificar_exploracao()
        relogio_salvar += delta
        if relogio_salvar >= INTERVALO_SALVAR:
            salvar()
    tempo_interface += delta
    if tempo_interface >= 0.12:
        tempo_interface = 0.0
        atualizar_interface()

func _unhandled_input(event: InputEvent) -> void:
    if not iniciado:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if atracado:                                   # no cais só valem as teclas do cais
            match event.physical_keycode:
                KEY_1: vender()
                KEY_2: abastecer()
                KEY_3: comprar("motor")
                KEY_4: comprar("tanque")
                KEY_5: comprar("porao")
                KEY_6: comprar("vara")
                KEY_7: comprar("casco")
                KEY_8: comprar("leme")
                KEY_9: comprar("helice")
                KEY_0: comprar("radar")
                KEY_Q: comprar_iscas()
                KEY_U: melhorar_linha()
                KEY_M:
                    interface.aviso("Carta náutica aberta. [M] fecha." if interface.alternar_mapa() else "Carta náutica fechada.")
                KEY_L:
                    alternar_luz()
                KEY_K:
                    interface.aviso("Clima: %s. [K] alternar" % clima.alternar_clima())
                KEY_E, KEY_ESCAPE: zarpar()
            return
        match event.physical_keycode:
            KEY_E:
                if not em_pausa:
                    atracar()
            KEY_F:
                if not em_pausa:
                    pesca.acao()
            KEY_C:
                if not em_pausa:
                    camera_barco.alternar()
            KEY_B:
                if not em_pausa:
                    interface.aviso(pesca.trocar_isca())
            KEY_N:
                if not em_pausa:
                    interface.aviso(pesca.mudar_profundidade())
            KEY_J:
                if not em_pausa:
                    interface.aviso(pesca.trocar_tecnica())
            KEY_ESCAPE:
                if not interface.fechar_painel():      # ESC fecha primeiro o painel aberto
                    alternar_pausa()
            KEY_T:
                clima.avancar(3.0)
                interface.aviso("O tempo avança: %s (%s)." % [clima.texto_hora(), clima.nome_do_momento()])
            KEY_M:
                interface.aviso("Carta náutica aberta. [M] fecha." if interface.alternar_mapa() else "Carta náutica fechada.")
            KEY_F6:
                interface.aviso("Estado do mar: %s. (F6 para alternar)" % oceano.alternar_estado())
            KEY_F7:
                if clima.modo_clima != 0:
                    clima.definir_clima(0)
                interface.aviso(oceano.testar_tempestade())
            KEY_F8:
                if not em_pausa and baleias != null:
                    interface.aviso(baleias.testar_avistamento())
            KEY_F4:
                _diagnostico_navegacao()
            KEY_L:
                alternar_luz()
            KEY_K:
                interface.aviso("Clima: %s. [K] alternar" % clima.alternar_clima())
            KEY_R:
                if relogio - pedido_reinicio <= 2.5:
                    pedido_reinicio = -10.0
                    reiniciar()
                else:
                    pedido_reinicio = relogio
                    interface.aviso("Reiniciar a viagem? Pressione R de novo para confirmar.")

func _diagnostico_navegacao() -> void:
    var pos: Vector3 = barco.global_position
    var fundo: float = altura_terra(pos)
    var superficie: float = oceano.altura_em(pos)
    var distancia_porto: float = _ilha_do_cais_mais_perto().distancia_do_cais(pos)
    var mensagem: String = "DIAG: %.1f nós · água %.1fm · fundo %.1fm · cais %.0fm" % [barco.nos(), superficie, fundo, distancia_porto]
    print("[PESCADOR v0.3.18] ", mensagem, " | FPS=", Engine.get_frames_per_second(), " | Cardumes=", cardumes.lista.size())
    interface.aviso(mensagem)

func alternar_luz() -> void:
    luz_ligada = not luz_ligada
    interface.aviso("Lanterna do barco ligada. [L]" if luz_ligada else "Lanterna do barco desligada. [L]")

## O barco nasce ao lado da ponta do cais da Vila do Porto, de proa para o mar (viagem nova e reinicio).
func posicionar_no_cais() -> void:
    var partida: Dictionary = ilha.posicao_de_partida()
    barco.global_position = partida["pos"]
    barco.rotation = Vector3(0.0, float(partida["giro"]), 0.0)
    barco.velocidade = 0.0
    if camera_barco != null:
        camera_barco.resetar()

func iniciar_ou_retomar() -> void:
    var continuou := false
    if not iniciado:
        continuou = Salvamento.carregar(self)
        cardumes.semear()
        oceano.limpar_rastro()
    iniciado = true
    em_pausa = false
    barco.ativo = true
    pesca.ativo = true
    som.navegando = true
    interface.esconder_menu()
    if continuou:
        interface.aviso("Viagem retomada: %s, R$ %d na carteira." % [clima.texto_hora(), dinheiro])
    else:
        interface.aviso("Procure um cardume (sombras na água, peixes no radar), pare perto dele e aperte F.")

func alternar_pausa() -> void:
    em_pausa = not em_pausa
    barco.ativo = not em_pausa
    pesca.ativo = not em_pausa
    som.navegando = not em_pausa
    if em_pausa:
        salvar()
        interface.mostrar_pausa()
    else:
        interface.esconder_menu()

func reiniciar() -> void:
    Salvamento.apagar()
    melhorias.zerar()
    melhorias.aplicar(barco, porao, pesca, interface.hud)
    barco.zerar()
    posicionar_no_cais()
    interface.limpar_partida()
    porao.esvaziar()
    cardumes.semear()
    oceano.resetar_mar()
    if baleias != null:
        baleias.reiniciar()
    fauna_costeira.reiniciar()
    interface.mapa.tem_marcador = false
    luz_ligada = true
    som.navegando = true
    pesca.resetar()
    camera_barco.resetar()
    clima.hora = clima.HORA_INICIAL
    clima.definir_clima(0)
    clima.atualizar()
    objetivo_cumprido = false
    missoes.zerar()
    economia.zerar()
    explorados.clear()
    relogio_exploracao = 0.0
    dinheiro = DINHEIRO_INICIAL
    atracado = false
    ja_vendeu = false
    interface.esconder_porto()
    iniciado = true
    em_pausa = false
    barco.ativo = true
    pesca.ativo = true
    interface.esconder_menu()
    interface.aviso("Viagem reiniciada. Missão: capturar três peixes.")
    atualizar_interface()

# ------------------------------------------------------------------ o mundo: as ilhas juntas

## Há terra (ou raso demais) aqui? É o que o barco pergunta antes de andar.
func bloqueado(pos: Vector3) -> bool:
    for i in ilhas:
        if i.bloqueado(pos):
            return true
    return recifes.bloqueado(pos) if recifes != null else false

## Altura do chão (m) neste ponto, olhando todas as ilhas. Negativa = fundo do mar.
func altura_terra(pos: Vector3) -> float:
    var h := -99.0
    for i in ilhas:
        h = maxf(h, i.altura_em(pos))
    if recifes != null:
        h = maxf(h, recifes.altura_em(pos))
    return h

## Distância (m) até a ilha mais próxima, medida da borda dela.
func distancia_da_costa(pos: Vector3) -> float:
    var d := INF
    for i in ilhas:
        d = minf(d, Vector2(pos.x - i.centro.x, pos.z - i.centro.z).length() - i.raio)
    return d

func zona_ecologica(pos: Vector3) -> String:
    if recifes != null:
        var zona: String = recifes.zona_em(pos)
        if zona != "":
            return zona
    var distancia: float = distancia_da_costa(pos)
    if distancia < 150.0:
        return "costeiro"
    if distancia >= 300.0:
        return "alto_mar"
    return "plataforma"

func _ilha_do_cais_mais_perto() -> Node3D:
    var melhor: Node3D = ilhas[0]
    for i in ilhas:
        if i.distancia_do_cais(barco.global_position) < melhor.distancia_do_cais(barco.global_position):
            melhor = i
    return melhor

func _verificar_exploracao() -> void:
    if recifes == null:
        return
    var pos: Vector2 = Vector2(barco.global_position.x, barco.global_position.z)
    for local in recifes.pontos_carta():
        var nome: String = String(local.nome)
        var c: Vector2 = local.pos
        if pos.distance_to(c) <= float(local.raio) + 22.0:
            if not explorados.has(nome):
                explorados[nome] = true
                dinheiro += 25
                interface.aviso("Descoberta: %s! +R$ 25 por exploração." % nome)
            # Missões de exploração podem ser concluídas mesmo após visitar a área antes.
            if not missoes.terminou():
                missoes.evento("explorar", nome)

func _missao_cumprida(m: Dictionary) -> void:
    dinheiro += int(m.premio)
    som.tocar("peixe", -4.0, 1.5)
    var premio := " Prêmio: R$ %d." % int(m.premio) if int(m.premio) > 0 else ""
    var proxima: String = "Você está por conta própria: boa pesca!" if missoes.terminou() else "Próxima: %s." % missoes.atual().texto
    interface.aviso("Missão cumprida!%s %s" % [premio, proxima])

# ------------------------------------------------------------------ cais: atracar, vender, abastecer

func pode_atracar() -> bool:
    return not atracado and ilha.pode_atracar(barco.global_position) and absf(barco.velocidade) <= pesca.VELOCIDADE_MAXIMA_PESCA

func atracar() -> void:
    if atracado:
        return
    if not ilha.pode_atracar(barco.global_position):
        interface.aviso("Chegue à ponta do cais para atracar (o radar mostra a âncora).")
        return
    if absf(barco.velocidade) > pesca.VELOCIDADE_MAXIMA_PESCA:
        interface.aviso("Devagar! Reduza para menos de 2 nós para atracar.")
        return
    atracado = true
    barco.ativo = false
    barco.velocidade = 0.0
    pesca.ativo = false
    pesca.estado = pesca.Estado.PRONTO
    som.navegando = false
    interface.fechar_painel()
    missoes.evento("atracar", ilha.nome)
    _atualizar_porto()
    salvar()

func zarpar() -> void:
    if not atracado:
        return
    atracado = false
    barco.ativo = true
    pesca.ativo = true
    som.navegando = true
    interface.esconder_porto()
    interface.aviso("Bons ventos! Volte ao cais para vender e abastecer.")

func _valor_do_porao() -> int:
    return economia.valor_porao(porao, cardumes, float(ilha.bonus_venda), clima.hora)

func _atualizar_porto() -> void:
    var falta: float = barco.tanque - barco.combustivel
    interface.mostrar_porto({"nome": ilha.nome, "dinheiro": dinheiro, "peixes": interface.capturas.size(),
            "peso": porao.peso_total(), "valor": _valor_do_porao(), "litros": barco.combustivel, "tanque": barco.tanque,
            "falta_litros": falta, "preco_litro": ilha.preco_diesel,
            "litros_possiveis": minf(falta, floorf(float(dinheiro) / ilha.preco_diesel)),
            "loja": melhorias.vitrine(dinheiro) if ilha.tem_loja else [],
            "iscas": "Camarão %d · Lula %d" % [pesca.iscas_camarao, pesca.iscas_lula],
            "pode_comprar_iscas": dinheiro >= PRECO_KIT_ISCAS,
            "preco_linha": pesca.preco_linha(), "nivel_linha": pesca.linha_nivel,
            "tem_oficina": ilha.tem_loja,
            "contrato": economia.texto_contrato(porao),
            "nota": "\nEste posto paga %d%% a mais pelo peixe." % roundi((ilha.bonus_venda - 1.0) * 100.0) if ilha.bonus_venda > 1.0 else ""})

func vender() -> void:
    if not atracado or interface.capturas.is_empty():
        return
    var ganho: int = _valor_do_porao()
    var premio: int = economia.premio_venda(porao)
    dinheiro += ganho + premio
    if premio > 0:
        missoes.evento("contrato")
    ja_vendeu = true
    missoes.evento("vender")
    porao.esvaziar()
    som.tocar("peixe", -6.0, 1.3)
    interface.aviso("Venda de R$ %d + encomenda R$ %d." % [ganho, premio] if premio > 0 else "Vendeu a pescaria por R$ %d." % ganho)
    _atualizar_porto()
    salvar()

func comprar_iscas() -> void:
    if not atracado:
        return
    if dinheiro < PRECO_KIT_ISCAS:
        interface.aviso("Faltam R$ %d para o kit de iscas." % (PRECO_KIT_ISCAS - dinheiro))
        return
    dinheiro -= PRECO_KIT_ISCAS
    pesca.comprar_iscas()
    som.tocar("peixe", -9.0, 1.1)
    interface.aviso("Iscas compradas: +6 camarões e +3 lulas.")
    _atualizar_porto()
    salvar()

func melhorar_linha() -> void:
    if not atracado or not ilha.tem_loja:
        return
    var custo: int = pesca.preco_linha()
    if custo < 0:
        interface.aviso("Sua linha já está no nível máximo.")
        return
    if dinheiro < custo:
        interface.aviso("Dinheiro insuficiente para reforçar a linha.")
        return
    dinheiro -= custo
    pesca.reforcar_linha()
    missoes.evento("comprar")
    interface.aviso("Linha reforçada! %s" % pesca.estado_linha())
    _atualizar_porto()
    salvar()

func abastecer() -> void:
    if not atracado:
        return
    var litros: float = minf(barco.tanque - barco.combustivel, floorf(float(dinheiro) / ilha.preco_diesel))
    if litros < 1.0:
        return
    var entrou: float = barco.abastecer(litros)
    dinheiro -= roundi(entrou * ilha.preco_diesel)
    som.tocar("onda", -10.0, 1.4)
    interface.aviso("Abasteceu %d L." % roundi(entrou))
    _atualizar_porto()
    salvar()

## Compra o próximo nível de uma melhoria (motor, tanque, porao, vara).
func comprar(id: String) -> void:
    if not atracado or not ilha.tem_loja:
        return
    var custo: int = melhorias.preco(id)
    if custo < 0:
        return
    if dinheiro < custo:
        interface.aviso("Faltam R$ %d para essa melhoria." % (custo - dinheiro))
        return
    dinheiro -= custo
    melhorias.subir(id)
    melhorias.aplicar(barco, porao, pesca, interface.hud)
    missoes.evento("comprar")
    salvar()
    som.tocar("peixe", -6.0, 0.8)
    interface.aviso("%s melhorado: %s." % [melhorias.TABELA[id].nome, melhorias.TABELA[id].descricao[melhorias.nivel[id]]])
    _atualizar_porto()

func _ao_pescar(especie: String, peso: float) -> void:
    if not porao.guardar(especie, peso, pesca.ultima_qualidade):
        pesca.num_peixes -= 1
        interface.aviso("Porão cheio: o peixe voltou ao mar. Venda a pescaria no cais.")
        return
    som.tocar("peixe", -5.0)
    interface.aviso("%s capturado — qualidade: %s." % [especie, pesca.ultima_qualidade])
    missoes.evento("pescar", especie)

func atualizar_interface() -> void:
    if interface == null:
        return
    clima.correndo = iniciado and not em_pausa and not atracado and not graficos.esta_aberto()
    var escuro: float = clima.noite()
    luz_barco.light_energy = 2.2 * escuro if luz_ligada else 0.0
    ilha = _ilha_do_cais_mais_perto()
    for i in ilhas:
        i.acender(escuro)
    boias.acender(escuro)
    missoes.evento("dinheiro", "", dinheiro)
    cardumes.noite = escuro > 0.5
    interface.hud.hora = clima.texto_hora()
    interface.hud.noite = escuro
    interface.hud.radar_alvos = cardumes.relativos(barco)
    var ate_cais: Vector3 = ilha.cais_ponta - barco.global_position
    interface.hud.cais_rel = Vector2(ate_cais.dot(barco.global_transform.basis.x), ate_cais.dot(-barco.global_transform.basis.z))
    interface.hud.cais_mundo = Vector2(ilha.cais_ponta.x, ilha.cais_ponta.z)
    interface.hud.cais_dist = ilha.distancia_do_cais(barco.global_position)
    interface.hud.dinheiro = dinheiro
    interface.hud.dica = ("E: atracar em %s" % ilha.nome) if (iniciado and not em_pausa and pode_atracar()) else ""
    if interface.hud.dica == "" and interface.mapa.tem_marcador:
        var destino_distancia: float = interface.mapa.distancia_ate_destino()
        interface.hud.dica = "Destino marcado: %.0f m  [M]" % destino_distancia
    interface.hud.missao_titulo = missoes.titulo()
    interface.hud.missao_texto = missoes.texto()
    interface.hud.missao_feita = missoes.terminou()
    interface.hud.combustivel = barco.combustivel / barco.tanque
    interface.hud.litros = barco.combustivel
    interface.atualizar(barco.nos(), barco.rumo(), barco.distancia_percorrida, pesca.num_peixes, porao.peso_total(), pesca.status(), objetivo_cumprido,
            clampf(absf(barco.velocidade) / barco.velocidade_maxima, 0.0, 1.0), pesca.estado != pesca.Estado.PRONTO)
