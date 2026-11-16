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
const Ilha = preload("res://scripts/ilha.gd")
var ilha: Node3D
const Melhorias = preload("res://scripts/melhorias.gd")
var melhorias: Node
const Porao = preload("res://scripts/porao.gd")
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
    ilha = Ilha.new()
    ilha.name = "Ilha"
    add_child(ilha)

func _ready() -> void:
    barco.obstaculo = ilha
    ilha.ligar_ao_mar(oceano)
    clima = Clima.new()
    clima.name = "Clima"
    add_child(clima)
    clima.configurar($Ceu, $Sol, $Oceano)
    clima.aplicar("por_do_sol")
    barco.encalhou.connect(func(): interface.aviso("Cuidado com a costa! Dê ré (S) para sair."))
    interface.vender_pressed.connect(vender)
    interface.volume_mudou.connect(func(grupo, valor): som.definir_volume(grupo, valor))
    interface.mudo_pressed.connect(func(): som.alternar_mudo())
    som.volumes_mudaram.connect(func(): interface.mostrar_volumes(som.volumes, som.mudo()))
    interface.mostrar_volumes(som.volumes, som.mudo())
    interface.abastecer_pressed.connect(abastecer)
    interface.zarpar_pressed.connect(zarpar)
    interface.melhoria_pressed.connect(comprar)
    melhorias.aplicar(barco, porao, pesca)
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
    interface.hud.devolveu.connect(func(item): interface.aviso("%s devolvido ao mar." % item.especie))
    interface.mostrar_inicio()
    atualizar_interface()

func _process(delta: float) -> void:
    relogio += delta
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
            KEY_ESCAPE:
                if not interface.fechar_painel():      # ESC fecha primeiro o painel aberto
                    alternar_pausa()
            KEY_T:
                interface.aviso("Hora do dia: %s." % clima.alternar())
            KEY_M:
                interface.aviso("Som desligado." if som.alternar_mudo() else "Som ligado.")
            KEY_R:
                if relogio - pedido_reinicio <= 2.5:
                    pedido_reinicio = -10.0
                    reiniciar()
                else:
                    pedido_reinicio = relogio
                    interface.aviso("Reiniciar a viagem? Pressione R de novo para confirmar.")

func iniciar_ou_retomar() -> void:
    if not iniciado:
        cardumes.semear()
    iniciado = true
    em_pausa = false
    barco.ativo = true
    pesca.ativo = true
    som.navegando = true
    interface.esconder_menu()
    interface.aviso("Procure um cardume (sombras na água, peixes no radar), pare perto dele e aperte F.")

func alternar_pausa() -> void:
    em_pausa = not em_pausa
    barco.ativo = not em_pausa
    pesca.ativo = not em_pausa
    som.navegando = not em_pausa
    if em_pausa:
        interface.mostrar_pausa()
    else:
        interface.esconder_menu()

func reiniciar() -> void:
    melhorias.zerar()
    melhorias.aplicar(barco, porao, pesca)
    barco.zerar()
    interface.limpar_partida()
    porao.esvaziar()
    cardumes.semear()
    oceano.limpar_rastro()
    som.navegando = true
    pesca.resetar()
    camera_barco.resetar()
    objetivo_cumprido = false
    dinheiro = DINHEIRO_INICIAL
    atracado = false
    ja_vendeu = false
    interface.esconder_porto()
    iniciado = true
    em_pausa = false
    barco.ativo = true
    pesca.ativo = true
    interface.esconder_menu()
    interface.aviso("Viagem reiniciada. Objetivo: capturar três peixes.")
    atualizar_interface()

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
    _atualizar_porto()

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
    return porao.valor_total()

func _atualizar_porto() -> void:
    var falta: float = barco.tanque - barco.combustivel
    interface.mostrar_porto({"nome": ilha.nome, "dinheiro": dinheiro, "peixes": interface.capturas.size(),
            "peso": porao.peso_total(), "valor": _valor_do_porao(), "litros": barco.combustivel, "tanque": barco.tanque,
            "falta_litros": falta, "preco_litro": PRECO_DIESEL,
            "litros_possiveis": minf(falta, floorf(float(dinheiro) / PRECO_DIESEL)), "loja": melhorias.vitrine(dinheiro)})

func vender() -> void:
    if not atracado or interface.capturas.is_empty():
        return
    var ganho := _valor_do_porao()
    dinheiro += ganho
    ja_vendeu = true
    porao.esvaziar()
    som.tocar("peixe", -6.0, 1.3)
    interface.aviso("Vendeu a pescaria por R$ %d." % ganho)
    _atualizar_porto()

func abastecer() -> void:
    if not atracado:
        return
    var litros: float = minf(barco.tanque - barco.combustivel, floorf(float(dinheiro) / PRECO_DIESEL))
    if litros < 1.0:
        return
    var entrou: float = barco.abastecer(litros)
    dinheiro -= roundi(entrou * PRECO_DIESEL)
    som.tocar("onda", -10.0, 1.4)
    interface.aviso("Abasteceu %d L." % roundi(entrou))
    _atualizar_porto()

## Compra o próximo nível de uma melhoria (motor, tanque, porao, vara).
func comprar(id: String) -> void:
    if not atracado:
        return
    var custo: int = melhorias.preco(id)
    if custo < 0:
        return
    if dinheiro < custo:
        interface.aviso("Faltam R$ %d para essa melhoria." % (custo - dinheiro))
        return
    dinheiro -= custo
    melhorias.subir(id)
    melhorias.aplicar(barco, porao, pesca)
    som.tocar("peixe", -6.0, 0.8)
    interface.aviso("%s melhorado: %s." % [melhorias.TABELA[id].nome, melhorias.TABELA[id].descricao[melhorias.nivel[id]]])
    _atualizar_porto()

func _ao_pescar(especie: String, peso: float) -> void:
    if not porao.guardar(especie, peso):
        pesca.num_peixes -= 1
        interface.aviso("Porão cheio: o peixe voltou ao mar. Venda a pescaria no cais.")
        return
    som.tocar("peixe", -5.0)
    if pesca.num_peixes >= 3 and not objetivo_cumprido:
        objetivo_cumprido = true
        interface.aviso("Missão cumprida: 3 peixes! Agora leve a pescaria ao cais (âncora no radar).")

func atualizar_interface() -> void:
    if interface == null:
        return
    interface.hud.radar_alvos = cardumes.relativos(barco)
    var ate_cais: Vector3 = ilha.cais_ponta - barco.global_position
    interface.hud.cais_rel = Vector2(ate_cais.dot(barco.global_transform.basis.x), ate_cais.dot(-barco.global_transform.basis.z))
    interface.hud.cais_dist = ilha.distancia_do_cais(barco.global_position)
    interface.hud.dinheiro = dinheiro
    interface.hud.dica = "E: atracar no cais" if (iniciado and not em_pausa and pode_atracar()) else ""
    # as missões vêm em sequência: pescar, vender, e depois viagem livre
    if objetivo_cumprido and not ja_vendeu:
        interface.hud.missao_titulo = "Segunda Missão"
    elif ja_vendeu:
        interface.hud.missao_titulo = "Viagem livre"
    else:
        interface.hud.missao_titulo = "Primeira Missão"
    interface.hud.combustivel = barco.combustivel / barco.tanque
    interface.hud.litros = barco.combustivel
    interface.atualizar(barco.nos(), barco.rumo(), barco.distancia_percorrida, pesca.num_peixes, porao.peso_total(), pesca.status(), objetivo_cumprido,
            clampf(absf(barco.velocidade) / barco.velocidade_maxima, 0.0, 1.0), pesca.estado != pesca.Estado.PRONTO)
