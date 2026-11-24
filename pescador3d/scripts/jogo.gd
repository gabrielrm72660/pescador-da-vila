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
const Cursor = preload("res://scripts/cursor.gd")             # v0.7.4: cursor em aquarela e mouse preso navegando
const Toque = preload("res://scripts/toque.gd")               # v0.7.0: controles de toque (celular)
const Controle = preload("res://scripts/controle.gd")         # v0.7.0: controle (gamepad)
const Historia = preload("res://scripts/historia.gd")         # v0.7.0: o compadre Bento e os dois finais
const Fantasmas = preload("res://scripts/fantasmas.gd")      # v0.6.0: vultos e miragens da bruma
var fantasmas: Node3D
var historia: Node
var _avisos_bruma: Dictionary = {"vulto": 0, "miragem": 0}
const Ilha = preload("res://scripts/ilha.gd")
var ilha: Node3D                  # a ilha do cais mais próximo do barco
var ilhas: Array = []
const Missoes = preload("res://scripts/missoes.gd")
const Npcs = preload("res://scripts/npcs.gd")
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
const Construtor = preload("res://scripts/construtor.gd")
var construtor: Node                  # Modo Construtor (Tab; F9 também, fora do editor do Godot): edita a ilha principal
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
const VELOCIDADE_ATRACAR := 2.6  # m/s (5 nós): dá para atracar sem parar o barco antes (v0.5.8)
const PRECO_REPARO := 3          # R$ por ponto de casco consertado no cais (100 pontos = R$ 300)
const Idioma = preload("res://scripts/idioma.gd")
var _avisou_avaria: int = 10     # última faixa de 10 pontos de casco já avisada
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
var colecao: Dictionary = {}          # v0.7.0: caderno de peixes: especie -> {"n": pescados, "maior": kg}
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
    ilha.arquipelago = "Arquipélago de São Paulo"
    ilha.rochedos = [[136.0, 84.0, 20.0, 8.2], [148.0, 61.0, 16.0, 7.0], [143.0, -53.0, -1.8, 14.0], [154.0, -68.0, 4.0, 6.4]]
    add_child(ilha)
    var rata := Ilha.new()                         # Ilha das Rocas: pequena e deserta, só um posto que paga mais pelo peixe
    rata.name = "IlhaRata"
    rata.nome = "Ilha das Rocas"
    rata.centro = Vector3(-380.0, 0.0, -430.0)
    rata.raio = 64.0
    rata.semente = 815
    rata.pico = [12.0, -10.0, 17.0, 17.0]
    rata.morro = [-22.0, 14.0, 7.0, 20.0]
    rata.rochedos = [[-78.0, -52.0, 13.0, 6.0]]
    rata.com_vila = false
    rata.tem_farol = false
    rata.tem_torre = true                          # v0.8.3: torre de telecom no cume
    rata.relevo_detalhado = false
    rata.coqueiros = 30
    rata.bonus_venda = 1.3
    rata.preco_diesel = 6
    rata.tem_loja = false
    rata.pode_editar = true
    rata.chave_mundo = "ilha_das_rocas"
    add_child(rata)
    # v0.5.8: a Ilha das Conchas chegou para perto da Vila do Porto (canal estreito a leste) e ficou deserta (sem cais nem casa).
    var conchas := Ilha.new()
    conchas.name = "IlhaConchas"
    conchas.nome = "Ilha das Conchas"
    conchas.centro = Vector3(400.0, 0.0, -300.0)
    conchas.raio = 46.0
    conchas.semente = 1931
    conchas.pico = [-8.0, 5.0, 11.0, 16.0]
    conchas.morro = [12.0, -15.0, 5.0, 14.0]
    conchas.rochedos = [[52.0, 38.0, 7.0, 5.0]]
    conchas.com_vila = false
    conchas.tem_cais = false
    conchas.tem_farol = false
    conchas.relevo_detalhado = false
    conchas.coqueiros = 26
    conchas.pinheiros_soltos = 10
    conchas.lado = 220.0
    conchas.arquipelago = "Arquipélago de São Paulo"
    add_child(conchas)
    ilhas = [ilha, rata, conchas]
    # Três ilhotas desertas ao norte, só coqueiros e pinheiros.
    for d in [["IlhotaAtobas", "Ilhota dos Atobás", Vector3(-147.0, 0.0, -598.0), 27.0, 4411],
            ["IlhotaMeio", "Ilhota do Meio", Vector3(91.0, 0.0, -521.0), 23.0, 4523],
            ["IlhotaGarcas", "Ilhota das Garças", Vector3(-133.0, 0.0, -441.0), 25.0, 4637]]:
        ilhas.append(_ilhota(d[0], d[1], d[2], d[3], d[4]))
    # Arquipélago de São Pedro, a oeste: uma ilha grande com cais e uma vila pequena, e dois ilhéus desertos.
    var sao_pedro := Ilha.new()
    sao_pedro.name = "IlhaSaoPedro"
    sao_pedro.nome = "Ilha de São Pedro"
    sao_pedro.centro = Vector3(-1263.0, 0.0, 151.0)
    sao_pedro.raio = 92.0
    sao_pedro.semente = 6107
    sao_pedro.pico = [-28.0, 18.0, 24.0, 24.0]
    sao_pedro.morro = [8.0, -34.0, 11.0, 20.0]
    sao_pedro.rochedos = [[-104.0, -40.0, 12.0, 6.5], [-92.0, 70.0, 3.0, 9.0]]
    sao_pedro.com_vila = false
    sao_pedro.vila_pequena = true
    sao_pedro.tem_farol = true            # v0.5.8: farol no topo do morro
    sao_pedro.relevo_detalhado = false
    sao_pedro.coqueiros = 46
    sao_pedro.pinheiros_soltos = 70
    sao_pedro.bonus_venda = 1.25
    sao_pedro.bonus_especie = {"Cioba": 1.6, "Olho-de-boi": 1.5, "Peixe-lua": 1.4, "Garoupa": 1.3, "Peixe-anjo": 1.3, "Namorado": 1.25}
    sao_pedro.preco_diesel = 5
    sao_pedro.tem_loja = false
    sao_pedro.pode_editar = true
    sao_pedro.chave_mundo = "ilha_sao_pedro"
    sao_pedro.arquipelago = "Arquipélago de São Pedro"
    add_child(sao_pedro)
    ilhas.append(sao_pedro)
    ilhas.append(_ilhota("IlheuCacao", "Ilhéu do Cação", Vector3(-1147.0, 0.0, 268.0), 26.0, 6233))
    ilhas.append(_ilhota("IlheuAgulha", "Ilhéu da Agulha", Vector3(-975.0, 0.0, 280.0), 18.0, 6359))
    for k in [ilhas.size() - 2, ilhas.size() - 1]:
        ilhas[k].arquipelago = "Arquipélago de São Pedro"

## Ilha pequena e deserta: sem cais, sem casas, só coqueiros e pinheiros.
func _ilhota(no: String, nome_ilha: String, c: Vector3, r: float, sem: int) -> Node3D:
    var il := Ilha.new()
    il.name = no
    il.nome = nome_ilha
    il.centro = c
    il.raio = r
    il.semente = sem
    il.pico = [r * 0.08, -r * 0.10, 3.5 + r * 0.12, r * 0.50]
    il.morro = [-r * 0.25, r * 0.25, 2.0 + r * 0.05, r * 0.35]
    il.rochedos = [[r * 1.35, -r * 0.6, 4.0, 3.2]]
    il.com_vila = false
    il.tem_cais = false
    il.tem_farol = false
    il.relevo_detalhado = false
    il.coqueiros = int(r * 0.9)
    il.lado = clampf(r * 4.6, 110.0, 300.0)
    il.pinheiros_soltos = int(r * 0.35)
    add_child(il)
    return il

func _ready() -> void:
    barco.obstaculo = self
    Ilha.ligar_todas_ao_mar(ilhas, oceano)      # v0.5.8: um mapa de fundo só para o mundo todo (antes, 3 ilhas no máximo)
    oceano.configurar_costas(ilhas)
    oceano.tempestade_comecou.connect(func():
        interface.aviso(Idioma.t("O céu fechou! Tempestade se aproximando. Procure abrigo perto das ilhas."))
        som.tocar("aviso", -7.0, 0.85))
    oceano.tempestade_terminou.connect(func(): interface.aviso(Idioma.t("A tempestade se afasta e o mar começa a acalmar.")))
    missoes.cumprida.connect(_missao_cumprida)
    clima = Clima.new()
    clima.name = "Clima"
    add_child(clima)
    clima.configurar($Ceu, $Sol, $Oceano)
    clima.anoiteceu.connect(func():
        if clima.noite_de_bruma():
            interface.aviso(Idioma.t("Anoitece, e a BRUMA desce. Longe das ilhas, a bússola e o radar falham."))
        else:
            interface.aviso(Idioma.t("Anoitece, e uma neblina sobe do mar. A âncora do radar leva de volta ao cais.")))
    clima.amanheceu.connect(func(): interface.aviso(Idioma.t("Amanhece. A neblina se desfaz.")))
    clima.bruma_mudou.connect(func(ativa: bool):
        if not ativa and fantasmas != null:
            fantasmas.limpar())
    fantasmas = Fantasmas.new()
    add_child(fantasmas)
    fantasmas.construir(barco, clima, self)
    fantasmas.desfeito.connect(_ao_desfazer_fantasma)
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
    boias.barco = barco                    # v0.5.12: o casco bate nas boias
    vida_portuaria.definir_boias(boias)    # e os barcos NPC também desviam delas
    graficos = OpcoesGraficas.new()
    graficos.name = "OpcoesGraficas"
    add_child(graficos)
    graficos.configurar(ilhas, $Sol, oceano, $Ceu)
    graficos.qualidade_ajustada.connect(func(texto: String): interface.aviso(texto))
    construtor = Construtor.new()
    construtor.name = "Construtor"
    add_child(construtor)
    var editaveis: Array = []
    for i in ilhas:
        if i.editavel:
            editaveis.append(i)
    construtor.configurar(self, editaveis[0] if not editaveis.is_empty() else null, editaveis)
    barco.encalhou.connect(func():
        som.tocar("estalo", -9.0, 0.62)
        interface.aviso(Idioma.t("Batida na costa! Casco em %d%%. Dê ré (S) para sair.") % floori(barco.saude)))
    vida_portuaria.definir_jogador(barco)
    barco.bateu_em_barco.connect(func(forca: float):
        som.tocar("estalo", lerpf(-16.0, -7.0, forca), randf_range(0.7, 0.85))
        interface.aviso(Idioma.t("Barco batendo no seu! Casco em %d%%.") % floori(barco.saude)))
    barco.bateu_em_boia.connect(func(forca: float):
        som.tocar("estalo", lerpf(-14.0, -6.0, forca), randf_range(1.05, 1.25))
        interface.aviso(Idioma.t("Batida na boia! Casco em %d%%.") % floori(barco.saude)))
    barco.casco_avariado.connect(_casco_avariado)
    interface.graficos = graficos
    interface._atualizar_graficos()
    interface.idioma_mudou.connect(atualizar_interface)
    interface.consertar_pressed.connect(consertar)
    interface.conversar_pressed.connect(_conversar)
    interface.dialogo_terminou.connect(_ao_fim_do_dialogo)
    historia = Historia.new()
    add_child(historia)
    historia.construir(self)
    var controle := Controle.new()
    add_child(controle)
    controle.construir(self)
    var cursor := Cursor.new()
    add_child(cursor)
    cursor.construir(self)
    if Toque.ligado():
        var toque := Toque.new()
        add_child(toque)
        toque.construir(self)
    interface.sair_pressed.connect(sair_do_jogo)
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
    interface.iniciar_pressed.connect(func():
        if no_titulo: interface.tela_inicial.sair_com_cortina(iniciar_ou_retomar)
        else: iniciar_ou_retomar())
    interface.reiniciar_pressed.connect(func():
        if no_titulo: interface.tela_inicial.sair_com_cortina(reiniciar)
        else: reiniciar())
    interface.construtor_pressed.connect(func(): if construtor != null: construtor.abrir())
    interface.pescar_pressed.connect(func(): if iniciado and not em_pausa: pesca.acao())
    interface.pausa_pressed.connect(func(): if iniciado: alternar_pausa())
    pesca.mensagem.connect(interface.aviso)
    pesca.peixe_capturado.connect(_ao_pescar)
    barco.combustivel_baixo.connect(func(): som.tocar("aviso", -6.0); interface.aviso(Idioma.t("Combustível baixo: menos de 20% no tanque.")))
    barco.combustivel_acabou.connect(func(): som.tocar("aviso", -4.0); interface.aviso(Idioma.t("Acabou o combustível! O barco só se arrasta a 2 nós. (R reinicia a viagem.)")))
    pesca.linha_lancada.connect(func(): som.tocar("pesca_lancar", -6.0))
    pesca.acertou.connect(func(perfeito): som.tocar("perfeito" if perfeito else "acerto", -7.0 if perfeito else -9.0, randf_range(0.97, 1.05)))
    pesca.errou.connect(func(): som.tocar("aviso", -14.0, 0.6))
    pesca.linha_rompida.connect(func(): som.tocar("estalo", -4.0))
    pesca.tensao_alta.connect(func(): som.tocar("tensao", -8.0, randf_range(0.95, 1.08)))
    interface.hud.pesca = pesca
    interface.porao = porao
    interface.hud.porao = porao
    interface.conectar_mapa(barco, ilhas)
    interface.mapa.configurar_extras(recifes.pontos_carta())
    interface.mapa.configurar_batimetria(self)
    _preparar_minimapa()
    interface.hud.devolveu.connect(func(item): interface.aviso(Idioma.t("%s devolvido ao mar.") % Idioma.t(String(item.especie))))
    posicionar_no_cais()
    interface.mostrar_inicio(Salvamento.existe())
    _entrar_titulo()
    atualizar_interface()

## O radar mostra o desenho das ilhas: praia, mata e águas rasas, no mesmo contorno da carta (tecla M).
func _preparar_minimapa() -> void:
    var dados: Array = []
    for i in ilhas:
        dados.append({
            "centro": Vector2(i.centro.x, i.centro.z), "raio": i.raio,
            "raso": interface.mapa._contorno(i, -5.0), "linha": interface.mapa._contorno(i, 0.0), "alto": interface.mapa._contorno(i, 7.0),
            "cais": [Vector2(i.cais_inicio.x, i.cais_inicio.z), Vector2(i.cais_ponta.x, i.cais_ponta.z)] if i.tem_cais else []})
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
    if no_titulo:
        _mover_camera_titulo(delta)
    var pode_navegar: bool = iniciado and not em_pausa and not atracado and not graficos.esta_aberto() and not interface.dialogo_ativo() and not interface.caderno_aberto() and not interface.final_ativo
    barco.ativo = pode_navegar
    pesca.ativo = pode_navegar
    oceano.simulando = pode_navegar
    cardumes.simulando = pode_navegar
    if baleias != null:
        baleias.simulando = pode_navegar
    fauna_costeira.simulando = pode_navegar
    if fantasmas != null:
        fantasmas.simulando = pode_navegar
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
    if not iniciado or (construtor != null and construtor.ativo) or interface.dialogo_ativo():
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
                KEY_R: consertar()
                KEY_T: _conversar("")
                KEY_P:
                    interface.caderno.colecao = colecao
                    interface.alternar_livro("peixes")
                KEY_TAB:
                    interface.caderno.colecao = colecao
                    interface.alternar_livro()
                KEY_M:
                    interface.aviso(Idioma.t("Carta náutica aberta. [M] fecha.") if interface.alternar_mapa() else Idioma.t("Carta náutica fechada."))
                KEY_L:
                    alternar_luz()
                KEY_H:
                    buzinar()
                KEY_K:
                    interface.aviso(Idioma.t("Clima: %s. [K] alternar") % Idioma.t(clima.alternar_clima()))
                KEY_F, KEY_E, KEY_ESCAPE: zarpar()
            return
        match event.physical_keycode:
            KEY_E:
                if not em_pausa:
                    atracar()
            KEY_F:                                       # F pesca; na ponta do cais, atraca
                if not em_pausa:
                    if pesca.estado == pesca.Estado.PRONTO and ilha.pode_atracar(barco.global_position):
                        atracar()
                    else:
                        pesca.acao()
            KEY_I:
                if not em_pausa:
                    interface.alternar_painel("porao")
            KEY_TAB:                                     # v0.8.4: o diário de bordo virou o Livro do Pescador
                if not em_pausa:
                    interface.caderno.colecao = colecao
                    interface.alternar_livro()
            KEY_P:
                if not em_pausa:
                    interface.caderno.colecao = colecao
                    interface.alternar_livro("peixes")
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
                interface.aviso(Idioma.t("O tempo avança: %s (%s).") % [clima.texto_hora(), Idioma.t(clima.nome_do_momento())])
            KEY_M:
                interface.aviso(Idioma.t("Carta náutica aberta. [M] fecha.") if interface.alternar_mapa() else Idioma.t("Carta náutica fechada."))
            KEY_F6:
                interface.aviso(Idioma.t("Estado do mar: %s. (F6 para alternar)") % Idioma.t(oceano.alternar_estado()))
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
            KEY_H:
                buzinar()
            KEY_K:
                interface.aviso(Idioma.t("Clima: %s. [K] alternar") % Idioma.t(clima.alternar_clima()))
            KEY_R:
                if relogio - pedido_reinicio <= 2.5:
                    pedido_reinicio = -10.0
                    reiniciar()
                else:
                    pedido_reinicio = relogio
                    interface.aviso(Idioma.t("Reiniciar a viagem? Pressione R de novo para confirmar."))

func _diagnostico_navegacao() -> void:
    var pos: Vector3 = barco.global_position
    var fundo: float = altura_terra(pos)
    var superficie: float = oceano.altura_em(pos)
    var distancia_porto: float = _ilha_do_cais_mais_perto().distancia_do_cais(pos)
    var mensagem: String = "DIAG: %.1f nós · água %.1fm · fundo %.1fm · cais %.0fm" % [barco.nos(), superficie, fundo, distancia_porto]
    print("[BRUMA v0.8.4] ", mensagem, " | FPS=", Engine.get_frames_per_second(), " | Cardumes=", cardumes.lista.size())
    interface.aviso(mensagem)

## v0.7.9: buzina náutica [H]. Um toque por vez (não empilha enquanto ainda soa).
func buzinar() -> void:
    if som != null and not som.tocando("buzina"):
        som.tocar("buzina", -3.0, randf_range(0.98, 1.02))

func alternar_luz() -> void:
    luz_ligada = not luz_ligada
    interface.aviso(Idioma.t("Lanterna do barco ligada. [L]") if luz_ligada else Idioma.t("Lanterna do barco desligada. [L]"))

## O barco nasce ao lado da ponta do cais da Vila do Porto, de proa para o mar (viagem nova e reinicio).
func posicionar_no_cais() -> void:
    var partida: Dictionary = ilha.posicao_de_partida()
    barco.global_position = partida["pos"]
    barco.rotation = Vector3(0.0, float(partida["giro"]), 0.0)
    barco.velocidade = 0.0
    if camera_barco != null:
        camera_barco.resetar()

# ------------------------------------------------------------------ v0.6.0: tela inicial
var no_titulo: bool = false
var _hora_antes_titulo: float = 0.0
var _giro_titulo: float = 0.0

## A tela inicial: câmera passeando em volta da vila na hora dourada, relógio parado, HUD escondido.
func _entrar_titulo() -> void:
    no_titulo = true
    camera_barco.set_process(false)
    camera_barco.set_process_input(false)
    _hora_antes_titulo = clima.hora
    clima.hora = 17.25
    clima.hora_congelada = true
    clima.atualizar()
    var cais: Vector3 = ilha.cais_ponta
    var c: Vector3 = ilha.global_position
    _giro_titulo = atan2(cais.z - c.z, cais.x - c.x) - 0.55
    _mover_camera_titulo(0.0)

func _mover_camera_titulo(delta: float) -> void:
    _giro_titulo += delta * 0.018
    var c: Vector3 = ilha.global_position
    var cais: Vector3 = ilha.cais_ponta
    var foco: Vector3 = c.lerp(cais, 0.55) + Vector3(0.0, 10.0, 0.0)
    var raio_orbita: float = ilha.raio * 1.55
    var pos: Vector3 = foco + Vector3(cos(_giro_titulo), 0.0, sin(_giro_titulo)) * raio_orbita + Vector3(0.0, 32.0 + 6.0 * sin(_giro_titulo * 1.7), 0.0)
    pos.y = maxf(pos.y, ilha.altura_em(pos) + 14.0)
    camera_barco.global_position = pos
    camera_barco.look_at(foco)

## Sai da tela inicial: devolve a hora (a viagem salva ainda pode trocá-la), o relógio e a câmera do barco.
func _sair_titulo() -> void:
    if not no_titulo:
        return
    no_titulo = false
    clima.hora_congelada = false
    clima.hora = _hora_antes_titulo
    clima.atualizar()
    camera_barco.set_process(true)
    camera_barco.set_process_input(true)
    camera_barco.resetar()
    interface.fechar_titulo()

func iniciar_ou_retomar() -> void:
    _sair_titulo()
    var continuou := false
    if not iniciado:
        continuou = Salvamento.carregar(self)
        _avisou_avaria = ceili(barco.saude / 10.0)
        cardumes.semear()
        oceano.limpar_rastro()
    iniciado = true
    em_pausa = false
    barco.ativo = true
    pesca.ativo = true
    som.navegando = true
    interface.esconder_menu()
    if continuou:
        interface.aviso(Idioma.t("Viagem retomada: %s, R$ %d na carteira.") % [clima.texto_hora(), dinheiro])
    else:
        interface.aviso(Idioma.t("Procure um cardume no radar (os peixinhos), pare perto dele e aperte F."))
        _dialogo_de_abertura()

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
    _sair_titulo()
    Salvamento.apagar()
    melhorias.zerar()
    melhorias.aplicar(barco, porao, pesca, interface.hud)
    barco.zerar()
    _avisou_avaria = 10
    for i in ilhas:                                  # recomeça sempre na Vila do Porto, mesmo saindo de longe
        if String(i.nome) == "Vila do Porto":
            ilha = i
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
    clima.dias = 0
    clima.bruma = 0.0
    clima.bruma_local = 1.0
    clima.definir_clima(0)
    clima.atualizar()
    fantasmas.limpar()
    _avisos_bruma = {"vulto": 0, "miragem": 0}
    objetivo_cumprido = false
    missoes.zerar()
    economia.zerar()
    explorados.clear()
    colecao.clear()
    historia.zerar()
    interface.caderno.paginas_bento = 0
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
    interface.aviso(Idioma.t("Viagem reiniciada. Missão: capturar três peixes."))
    atualizar_interface()
    _dialogo_de_abertura()

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

## v0.6.0: "sao_pedro" perto do arquipélago de São Pedro (a cioba e o olho-de-boi só nascem lá), "" no resto do mar.
const REGIAO_SAO_PEDRO := Vector2(-1263.0, 151.0)
const RAIO_REGIAO_SAO_PEDRO := 720.0
func regiao_em(pos: Vector3) -> String:
    return "sao_pedro" if Vector2(pos.x, pos.z).distance_to(REGIAO_SAO_PEDRO) <= RAIO_REGIAO_SAO_PEDRO else ""

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
        if not i.tem_cais:
            continue
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
                interface.aviso(Idioma.t("Descoberta: %s! +R$ 25 por exploração.") % Idioma.t(nome))
            # Missões de exploração podem ser concluídas mesmo após visitar a área antes.
            if not missoes.terminou():
                missoes.evento("explorar", nome)

## v0.6.0: as espécies que a missão atual pede (piscam no radar). Missão de pesca com espécie certa, ou encomenda
## (a espécie do pedido do cais da missão, ou do pedido geral). "Qualquer peixe" não destaca nada.
func _especies_da_missao() -> Array:
    var m: Dictionary = missoes.atual()
    if m.is_empty():
        return []
    match String(m.tipo):
        "pescar":
            return [] if String(m.alvo) == "" else [String(m.alvo)]
        "contrato":
            var locais: Array = economia.CONTRATOS_LOCAIS.get(String(m.alvo), [])
            var c: Dictionary = locais[posmod(economia.indice_local, locais.size())] if not locais.is_empty() else economia.atual()
            return [String(c.get("especie", ""))]
    return []

## v0.7.0: registra a captura no caderno de peixes; a primeira de cada espécie ganha aviso.
func _anotar_no_caderno(especie: String, peso: float) -> void:
    var d: Dictionary = colecao.get(especie, {"n": 0, "maior": 0.0})
    var nova: bool = int(d.n) == 0
    d.n = int(d.n) + 1
    d.maior = maxf(float(d.maior), peso)
    colecao[especie] = d
    interface.caderno.colecao = colecao
    if nova:
        interface.caderno.ir_para_especie(especie)
        interface.aviso(Idioma.t("Nova espécie no caderno: %s! [P]") % Idioma.t(especie))

func _missao_cumprida(m: Dictionary) -> void:
    dinheiro += int(m.premio)
    som.tocar("peixe", -4.0, 1.5)
    var premio: String = Idioma.t(" Prêmio: R$ %d.") % int(m.premio) if int(m.premio) > 0 else ""
    var proxima: String = Idioma.t("Você está por conta própria: boa pesca!") if missoes.terminou() else Idioma.t("Próxima: %s.") % Idioma.t(String(missoes.atual().texto))
    interface.aviso(Idioma.t("Missão cumprida!%s %s") % [premio, proxima])
    if not melhorias.motor_30_liberado and missoes.sao_pedro_concluido():
        melhorias.motor_30_liberado = true
        interface.aviso(Idioma.t("Missões de São Pedro concluídas! Nova melhoria na loja da Vila: motor de 30 nós."))

# ------------------------------------------------------------------ cais: atracar, vender, abastecer

func pode_atracar() -> bool:
    return not atracado and ilha.pode_atracar(barco.global_position) and absf(barco.velocidade) <= VELOCIDADE_ATRACAR

func atracar() -> void:
    if atracado:
        return
    if not ilha.pode_atracar(barco.global_position):
        interface.aviso(Idioma.t("Chegue à ponta do cais para atracar (o radar mostra a âncora)."))
        return
    if absf(barco.velocidade) > VELOCIDADE_ATRACAR:
        interface.aviso(Idioma.t("Devagar! Reduza para 5 nós ou menos para atracar."))
        return
    atracado = true
    barco.ativo = false
    barco.velocidade = 0.0
    pesca.ativo = false
    pesca.estado = pesca.Estado.PRONTO
    som.navegando = false
    interface.fechar_painel()
    missoes.evento("atracar", ilha.nome)
    _entregar_carga()
    _atualizar_porto()
    salvar()

# ------------------------------------------------------------------ v0.6.0: os NPCs do cais
var _dar_carga_depois: bool = false
var _congelado_no_dialogo: bool = false
var _npc_tecla: int = 0

## Abre a conversa: sem "papo_com", o que o cais tem de novo (fim de missão, apresentação da próxima);
## com um NPC, a conversa que o jogador puxou. Falso se não havia nada a dizer.
func _falar_no_cais(papo_com: String = "") -> bool:
    var r: Dictionary
    if papo_com == "":
        r = missoes.falas_ao_atracar(ilha.nome)
    else:
        r = missoes.falas_do_papo(papo_com, not porao.carga_a_bordo().is_empty())
    if r.falas.is_empty():
        return false
    interface.esconder_porto()
    _dar_carga_depois = bool(r.carga)
    _congelado_no_dialogo = not atracado
    if _congelado_no_dialogo:
        barco.ativo = false
        pesca.ativo = false
    interface.abrir_dialogo(r.falas)
    return true

## v0.7.0: abre uma conversa fora do cais (página do diário, o Bento): o barco para enquanto ela dura.
func abrir_falas(falas: Array) -> void:
    _dar_carga_depois = false
    _congelado_no_dialogo = not atracado
    if _congelado_no_dialogo:
        barco.ativo = false
        pesca.ativo = false
    interface.abrir_dialogo(falas)

func _ao_fim_do_dialogo() -> void:
    if _dar_carga_depois:
        _dar_carga_depois = false
        _dar_carga()
    if _congelado_no_dialogo:
        _congelado_no_dialogo = false
        if iniciado and not em_pausa and not atracado:
            barco.ativo = true
            pesca.ativo = true
    if atracado:
        _atualizar_porto()
    salvar()

func _conversar(id: String) -> void:
    if not atracado or interface.dialogo_ativo():
        return
    var aqui: Array = Npcs.da_ilha(ilha.nome)
    if aqui.is_empty():
        return
    if id == "" or not id in aqui:
        id = aqui[_npc_tecla % aqui.size()]
        _npc_tecla += 1
    _falar_no_cais(id)

## O NPC entrega a caixa de peças: ela vai para o porão, ocupando casas.
func _dar_carga() -> void:
    if porao.guardar("Caixa de peças", 8.0, "Carga"):
        interface.aviso(Idioma.t("Você recebeu uma caixa de peças. Ela ocupa 4 casas do porão e não se vende."))
    else:
        missoes.oferecidas.erase(missoes.indice)
        interface.aviso(Idioma.t("Sem espaço no porão para a caixa! Venda ou devolva peixes e converse de novo."))

## Chegou ao destino da carga: o NPC recebe a caixa e a missão se cumpre.
func _entregar_carga() -> void:
    var m: Dictionary = missoes.atual()
    if m.is_empty() or m.tipo != "entregar" or m.alvo != ilha.nome:
        return
    var caixa: Dictionary = porao.carga_a_bordo()
    if caixa.is_empty():
        return
    porao.retirar(caixa)
    missoes.evento("entregar", ilha.nome)

## Viagem nova: o primeiro NPC (Seu Jacinto) recebe o jogador no cais antes de zarpar.
func _dialogo_de_abertura() -> void:
    if missoes.indice == 0 and not missoes.oferecidas.has(0):
        _falar_no_cais()

func zarpar() -> void:
    if not atracado:
        return
    atracado = false
    barco.ativo = true
    pesca.ativo = true
    som.navegando = true
    interface.esconder_porto()
    interface.aviso(Idioma.t("Bons ventos! Volte ao cais para vender e abastecer."))

func _valor_do_porao() -> int:
    economia.ilha_atual = ilha.nome
    return economia.valor_porao(porao, cardumes, float(ilha.bonus_venda), clima.hora, ilha.bonus_especie)

func _atualizar_porto() -> void:
    if interface.dialogo_ativo():
        return
    if atracado and missoes.tem_falas_em(ilha.nome) and _falar_no_cais():      # v0.6.0: o NPC do cais tem algo a dizer
        return
    var falta: float = barco.tanque - barco.combustivel
    interface.mostrar_porto({"nome": ilha.nome, "dinheiro": dinheiro, "peixes": porao.n_peixes(), "npcs": Npcs.da_ilha(ilha.nome),
            "peso": porao.peso_total(), "valor": _valor_do_porao(),
            "ocupado": float(porao.casas_ocupadas()) / float(maxi(1, porao.colunas * porao.linhas)), "litros": barco.combustivel, "tanque": barco.tanque,
            "falta_litros": falta, "preco_litro": ilha.preco_diesel,
            "litros_possiveis": minf(falta, floorf(float(dinheiro) / ilha.preco_diesel)),
            "loja": melhorias.vitrine(dinheiro) if ilha.tem_loja else [],
            "iscas": Idioma.t("Camarão %d · Lula %d") % [pesca.iscas_camarao, pesca.iscas_lula],
            "pode_comprar_iscas": dinheiro >= PRECO_KIT_ISCAS,
            "preco_linha": pesca.preco_linha(), "nivel_linha": pesca.linha_nivel,
            "tem_oficina": ilha.tem_loja,
            "saude": barco.saude, "preco_reparo": PRECO_REPARO,
            "contrato": economia.texto_contrato(porao),
            "nota": Idioma.t("\nEste posto paga %d%% a mais pelo peixe.") % roundi((ilha.bonus_venda - 1.0) * 100.0) if ilha.bonus_venda > 1.0 else ""})

func vender() -> void:
    if not atracado or porao.n_peixes() == 0:
        return
    var ganho: int = _valor_do_porao()
    economia.ilha_atual = ilha.nome
    var premio: int = economia.premio_venda(porao)
    dinheiro += ganho + premio
    if premio > 0:
        missoes.evento("contrato", ilha.nome)
    ja_vendeu = true
    missoes.evento("vender")
    porao.esvaziar_peixes()
    som.tocar("peixe", -6.0, 1.3)
    interface.aviso(Idioma.t("Venda de R$ %d + encomenda R$ %d.") % [ganho, premio] if premio > 0 else Idioma.t("Vendeu a pescaria por R$ %d.") % ganho)
    _atualizar_porto()
    salvar()

func comprar_iscas() -> void:
    if not atracado:
        return
    if dinheiro < PRECO_KIT_ISCAS:
        interface.aviso(Idioma.t("Faltam R$ %d para o kit de iscas.") % (PRECO_KIT_ISCAS - dinheiro))
        return
    dinheiro -= PRECO_KIT_ISCAS
    pesca.comprar_iscas()
    som.tocar("peixe", -9.0, 1.1)
    interface.aviso(Idioma.t("Iscas compradas: +6 camarões e +3 lulas."))
    _atualizar_porto()
    salvar()

func melhorar_linha() -> void:
    if not atracado or not ilha.tem_loja:
        return
    var custo: int = pesca.preco_linha()
    if custo < 0:
        interface.aviso(Idioma.t("Sua linha já está no nível máximo."))
        return
    if dinheiro < custo:
        interface.aviso(Idioma.t("Dinheiro insuficiente para reforçar a linha."))
        return
    dinheiro -= custo
    pesca.reforcar_linha()
    missoes.evento("comprar")
    interface.aviso(Idioma.t("Linha reforçada! %s") % pesca.estado_linha())
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
    interface.aviso(Idioma.t("Abasteceu %d L.") % roundi(entrou))
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
        interface.aviso(Idioma.t("Faltam R$ %d para essa melhoria.") % (custo - dinheiro))
        return
    dinheiro -= custo
    melhorias.subir(id)
    melhorias.aplicar(barco, porao, pesca, interface.hud)
    missoes.evento("comprar")
    salvar()
    som.tocar("peixe", -6.0, 0.8)
    interface.aviso(Idioma.t("%s melhorado: %s.") % [Idioma.t(String(melhorias.TABELA[id].nome)), Idioma.t(String(melhorias.TABELA[id].descricao[melhorias.nivel[id]]))])
    _atualizar_porto()

## Conserto do casco no cais: R$ por ponto; se o dinheiro não der, conserta o que der.
func consertar() -> void:
    if not atracado:
        return
    var pontos: float = minf(ceilf(100.0 - barco.saude - 0.001), floorf(float(dinheiro) / float(PRECO_REPARO)))
    if 100.0 - barco.saude < 0.01:
        interface.aviso(Idioma.t("O casco está em ordem."))
        return
    if pontos < 1.0:
        interface.aviso(Idioma.t("Sem dinheiro para o conserto (R$ %d por ponto).") % PRECO_REPARO)
        return
    barco.consertar(pontos)
    dinheiro -= roundi(pontos) * PRECO_REPARO
    _avisou_avaria = ceili(barco.saude / 10.0)
    som.tocar("estalo", -14.0, 1.3)
    interface.aviso(Idioma.t("Casco consertado: %d%%.") % floori(barco.saude))
    _atualizar_porto()
    salvar()

## Avisos da avaria: a cada 10 pontos perdidos na tempestade, e sempre ao cruzar a metade e o zero.
func _casco_avariado(_perda: float, motivo: String) -> void:
    var faixa: int = ceili(barco.saude / 10.0)        # 10 = 91..100, 9 = 81..90...
    if barco.saude <= 0.0:
        som.tocar("aviso", -4.0)
        interface.aviso(Idioma.t("O casco está fazendo água! O barco só se arrasta: volte ao cais para consertar."))
    elif barco.saude < 50.0 and _avisou_avaria > 5:
        som.tocar("aviso", -6.0)
        interface.aviso(Idioma.t("Casco avariado (%d%%): o motor perde força. Conserte no cais [R].") % floori(barco.saude))
    elif motivo == "tempestade" and faixa < _avisou_avaria:
        interface.aviso(Idioma.t("A tempestade castiga o casco: %d%%. Procure abrigo ou volte ao cais.") % floori(barco.saude))
    _avisou_avaria = mini(_avisou_avaria, faixa)

func sair_do_jogo() -> void:
    salvar()
    get_tree().quit()

func _ao_pescar(especie: String, peso: float) -> void:
    if not porao.guardar(especie, peso, pesca.ultima_qualidade):
        pesca.num_peixes -= 1
        interface.aviso(Idioma.t("Porão cheio: o peixe voltou ao mar. Venda a pescaria no cais."))
        return
    som.tocar("peixe", -5.0)
    som.tocar("captura", -7.0)
    _anotar_no_caderno(especie, peso)
    interface.aviso(Idioma.t("%s capturado — qualidade: %s.") % [Idioma.t(especie), Idioma.t(pesca.ultima_qualidade)])
    missoes.evento("pescar", especie)

## v0.6.0: quão aberto (longe de terra e de luz) está o mar em volta do barco. Alimenta a bruma: densa em mar aberto,
## mais rala perto das ilhas e quase limpa dentro do alcance do facho do farol.
func _atualizar_bruma_local() -> void:
    var pos: Vector3 = barco.global_position
    var limpeza: float = 0.0
    for i in ilhas:
        limpeza = maxf(limpeza, float(i.clareio_do_farol(pos)))
    var longe: float = smoothstep(110.0, 520.0, distancia_da_costa(pos))
    var alvo: float = longe * (1.0 - 0.85 * limpeza)
    clima.bruma_local = lerpf(clima.bruma_local, alvo, 0.30)

func _ao_desfazer_fantasma(tipo: String) -> void:
    if int(_avisos_bruma.get(tipo, 9)) >= 2:
        return
    _avisos_bruma[tipo] = int(_avisos_bruma[tipo]) + 1
    if tipo == "vulto":
        interface.aviso(Idioma.t("O vulto se desfez na bruma, como se nunca tivesse existido."))
    else:
        interface.aviso(Idioma.t("O cardume do radar era só bruma. Não adianta persegui-lo."))

func atualizar_interface() -> void:
    if interface == null:
        return
    clima.correndo = iniciado and not em_pausa and not atracado and not graficos.esta_aberto()
    var escuro: float = clima.escuridao()             # v0.7.9: noite ou tempestade (antes só a noite)
    luz_barco.light_energy = 2.2 * escuro if luz_ligada else 0.0
    barco.definir_holofotes(maxf(escuro, 0.35) if luz_ligada else 0.0)
    ilha = _ilha_do_cais_mais_perto()
    for i in ilhas:
        i.acender(escuro)
    boias.acender(escuro)
    missoes.evento("dinheiro", "", dinheiro)
    cardumes.noite = escuro > 0.5
    _atualizar_bruma_local()
    cardumes.bruma = clima.bruma_densa()
    interface.hud.instavel = 0.0 if clima.bruma_mansa else clima.bruma * clima.bruma_local
    interface.hud.hora = clima.texto_hora()
    interface.hud.noite = escuro
    interface.hud.radar_alvos = cardumes.relativos(barco) + (fantasmas.radar() if fantasmas != null else [])
    interface.hud.especies_destaque = _especies_da_missao()
    var ate_cais: Vector3 = ilha.cais_ponta - barco.global_position
    interface.hud.cais_rel = Vector2(ate_cais.dot(barco.global_transform.basis.x), ate_cais.dot(-barco.global_transform.basis.z))
    interface.hud.cais_mundo = Vector2(ilha.cais_ponta.x, ilha.cais_ponta.z)
    # v0.8.2: o destino marcado na carta também aparece no radar (traço até ele)
    interface.hud.destino_mundo = interface.mapa.marcador if interface.mapa.tem_marcador else Vector2.INF
    interface.hud.cais_dist = ilha.distancia_do_cais(barco.global_position)
    interface.hud.dinheiro = dinheiro
    interface.hud.dica = (Idioma.t("F: atracar em %s") % Idioma.t(String(ilha.nome))) if (iniciado and not em_pausa and pode_atracar()) else ""
    interface.hud.saude = barco.saude
    if interface.hud.dica == "" and interface.mapa.tem_marcador:
        var destino_distancia: float = interface.mapa.distancia_ate_destino()
        interface.hud.dica = Idioma.t("Destino marcado: %.0f m  [M]") % destino_distancia
    interface.hud.missao_titulo = missoes.titulo()
    interface.hud.missao_texto = missoes.texto()
    interface.hud.missao_feita = missoes.terminou()
    interface.hud.combustivel = barco.combustivel / barco.tanque
    interface.hud.litros = barco.combustivel
    interface.atualizar(barco.nos(), barco.rumo(), barco.distancia_percorrida, pesca.num_peixes, porao.peso_total(), pesca.status(), objetivo_cumprido,
            clampf(absf(barco.velocidade) / barco.velocidade_maxima, 0.0, 1.0), pesca.estado != pesca.Estado.PRONTO)
