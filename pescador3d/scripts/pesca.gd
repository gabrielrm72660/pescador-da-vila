extends Node
## Pesca com minijogo de anel: pare perto de um cardume e aperte F para lançar. Um ponteiro gira em
## volta do anel; aperte F quando ele passar por uma faixa verde para puxar o peixe mais depressa
## (a parte dourada da faixa vale o dobro). Errar solta um pouco de linha. O peixe também vem sozinho,
## devagar: quem não acerta nada só demora mais. Perde-se o peixe ao acelerar ou se o cardume for embora.
## A espécie, o peso e a dificuldade vêm do cardume (scripts/cardumes.gd).

signal mensagem(texto: String)
signal peixe_capturado(especie: String, peso: float)
signal linha_lancada
signal acertou(perfeito: bool)
signal errou

const VELOCIDADE_MAXIMA_PESCA: float = 1.03  # m/s = 2 nós
const PERDA_NO_ERRO: float = 0.10            # quanto da barra volta num aperto fora da faixa
const TRAVA_NO_ERRO: float = 0.45            # s sem poder apertar depois de errar
const PARTE_DOURADA: float = 0.30            # fração do meio da faixa que vale o dobro

enum Estado { PRONTO, PUXANDO }
var estado: Estado = Estado.PRONTO
var num_peixes: int = 0
var peso_total: float = 0.0
var ativo: bool = false
var alvo: Dictionary = {}       # o cardume em que a linha está

# o anel (lido por scripts/hud.gd para desenhar)
var angulo: float = 0.0         # ponteiro, em radianos; 0 = topo, cresce no sentido horário
var sentido: float = 1.0
var voltas_por_s: float = 0.5
var faixas: Array = []          # {centro: rad, largura: rad, usada: s restantes apagada}
var progresso: float = 0.0      # 0..1: em 1 o peixe sobe a bordo
var trava: float = 0.0          # > 0: acabou de errar
var brilho: float = 0.0         # > 0: acabou de acertar (pisca)
var ultimo_perfeito: bool = false
var fator_vara: float = 1.0      # vara melhor (loja do cais) alarga as faixas verdes
var _ganho: float = 0.34        # quanto cada acerto enche
var _sozinho: float = 0.05      # quanto enche por segundo sem fazer nada

# Novo sistema de pesca: B troca a isca; N escolhe a camada do anzol.
const ISCAS := ["Comum", "Camarão", "Lula"]
const PROFUNDIDADES := ["Superfície", "Meia-água", "Fundo"]
const PERFIL := {
    "Sardinha": {"prof": 0, "isca": 1}, "Tainha": {"prof": 1, "isca": 1},
    "Xaréu": {"prof": 1, "isca": 2}, "Cavala": {"prof": 1, "isca": 2},
    "Barracuda": {"prof": 0, "isca": 2}, "Dourado": {"prof": 0, "isca": 2},
    "Atum": {"prof": 1, "isca": 2}, "Olho-de-cão": {"prof": 2, "isca": 1},
    "Garoupa": {"prof": 2, "isca": 1},
}
var tipo_isca: int = 0
var profundidade: int = 1
var iscas_camarao: int = 6
var iscas_lula: int = 4
var tensao: float = 0.0
var limite_linha: float = 1.0
var bonus_iscagem: float = 1.0
# J alterna a técnica. A qualidade depende da técnica, da isca e do esforço da linha.
const TECNICAS := ["Suave", "Equilibrada", "Firme"]
var tecnica: int = 1
var linha_nivel: int = 0
var desgaste_linha: float = 0.0
var ultima_qualidade: String = "Regular"

func trocar_tecnica() -> String:
    tecnica = (tecnica + 1) % TECNICAS.size()
    return "Técnica: %s. [J]" % TECNICAS[tecnica]

func preco_linha() -> int:
    return -1 if linha_nivel >= 3 else [90, 190, 350][linha_nivel]

func reforcar_linha() -> void:
    if linha_nivel < 3:
        linha_nivel += 1
        desgaste_linha = 0.0

func estado_linha() -> String:
    return "Linha %d/4 · desgaste %d%%" % [linha_nivel + 1, roundi(desgaste_linha * 100.0)]

func nome_isca() -> String:
    return ISCAS[tipo_isca]

func nome_profundidade() -> String:
    return PROFUNDIDADES[profundidade]

func trocar_isca() -> String:
    if estado == Estado.PUXANDO:
        return "Termine a captura antes de trocar a isca."
    tipo_isca = (tipo_isca + 1) % ISCAS.size()
    var quantidade: String = "ilimitada" if tipo_isca == 0 else str(iscas_camarao if tipo_isca == 1 else iscas_lula)
    return "Isca: %s (%s). [B]" % [nome_isca(), quantidade]

func mudar_profundidade() -> String:
    if estado == Estado.PUXANDO:
        return "Termine a captura antes de ajustar o anzol."
    profundidade = (profundidade + 1) % PROFUNDIDADES.size()
    return "Anzol: %s. [N]" % nome_profundidade()

func comprar_iscas() -> void:
    iscas_camarao += 6
    iscas_lula += 3

func _romper_linha(motivo: String) -> void:
    estado = Estado.PRONTO
    tensao = 0.0
    mensagem.emit(motivo)

@onready var barco = get_node("../Barco")
@onready var cardumes = get_node_or_null("../Cardumes")
@onready var porao = get_node_or_null("../Porao")

func _ready() -> void:
    randomize()

func _process(delta: float) -> void:
    if not ativo or estado == Estado.PRONTO:
        return
    # Linha na água e o barco acelerou: a linha arrebenta.
    if abs(barco.velocidade) > VELOCIDADE_MAXIMA_PESCA:
        _romper_linha("A linha arrebentou! Fique abaixo de 2 nós enquanto pesca.")
        return
    if cardumes != null and (not cardumes.vivo(alvo) or cardumes.distancia(alvo, barco.global_position) > (cardumes.ALCANCE + float(alvo.raio)) * 1.5):
        _romper_linha("O cardume se afastou. Chegue perto de outro e lance de novo.")
        return
    trava = maxf(0.0, trava - delta)
    brilho = maxf(0.0, brilho - delta)
    for f in faixas:
        f.usada = maxf(0.0, float(f.usada) - delta)
    angulo = fposmod(angulo + sentido * voltas_por_s * TAU * delta, TAU)
    # Linha forte tolera mais tensão; o desgaste reduz sua resistência máxima.
    limite_linha = 1.0 + linha_nivel * 0.15 - desgaste_linha * 0.20
    var taxa_recuperacao: float = [0.34, 0.25, 0.14][tecnica]
    tensao = maxf(0.0, tensao - delta * (taxa_recuperacao + fator_vara * 0.04))
    desgaste_linha = clampf(desgaste_linha + maxf(0.0, tensao - 0.42) * delta * 0.004, 0.0, 1.0)
    if tensao >= limite_linha:
        _romper_linha("Linha rompida pelo excesso de tensão. Espere entre as puxadas!")
        return
    progresso += _sozinho * bonus_iscagem * delta * (1.0 - 0.45 * tensao)
    if progresso >= 1.0:
        _capturar()

## A faixa verde (acesa) sob o ponteiro, ou -1.
func faixa_sob_ponteiro() -> int:
    for i in faixas.size():
        var f: Dictionary = faixas[i]
        if float(f.usada) <= 0.0 and absf(angle_difference(angulo, float(f.centro))) <= float(f.largura) / 2.0:
            return i
    return -1

func _lancar() -> void:
    var dados: Dictionary = cardumes.ESPECIES[alvo.especie]
    var perfil: Dictionary = PERFIL.get(String(alvo.especie), {"prof": 1, "isca": 0})
    var diferenca: int = absi(profundidade - int(perfil.prof))
    var combina: bool = tipo_isca == int(perfil.isca)
    bonus_iscagem = clampf(1.0 + (0.24 if combina else 0.0) - float(diferenca) * 0.18, 0.52, 1.35)
    if tipo_isca == 1:
        iscas_camarao -= 1
    elif tipo_isca == 2:
        iscas_lula -= 1
    tensao = 0.0
    voltas_por_s = float(dados.get("ponteiro", 0.5))
    var n: int = int(dados.get("faixas", 3))
    var largura: float = deg_to_rad(float(dados.get("largura", 38))) * fator_vara * bonus_iscagem
    _ganho = 1.0 / float(dados.get("acertos", 3)) + 0.01
    limite_linha = 1.0 + linha_nivel * 0.15 - desgaste_linha * 0.20
    var espera: Array = dados.get("espera", [3.0, 6.0])
    _sozinho = 1.0 / (randf_range(espera[0], espera[1]) * 3.0)      # sem acertar nada: de 8 a 24 s
    faixas.clear()
    var inicio := randf_range(0.0, TAU)
    for i in n:                                                     # espalhadas pelo anel, sem encostar
        faixas.append({"centro": fposmod(inicio + TAU * i / n + randf_range(-0.25, 0.25), TAU), "largura": largura * randf_range(0.85, 1.15), "usada": 0.0})
    angulo = fposmod(float(faixas[0].centro) + PI + randf_range(-0.4, 0.4), TAU)    # começa longe de uma faixa
    sentido = 1.0
    progresso = 0.0
    trava = 0.0
    brilho = 0.0
    estado = Estado.PUXANDO
    linha_lancada.emit()
    mensagem.emit("%s: %s / %s. F no verde; cuidado com a tensão!" % [String(alvo.especie), nome_isca(), nome_profundidade()])

func _capturar() -> void:
    estado = Estado.PRONTO
    var especie: String = alvo.especie
    var peso: float = cardumes.sortear_peso(especie)
    ultima_qualidade = "Excepcional" if tensao < 0.28 and bonus_iscagem > 1.06 else ("Boa" if tensao < 0.58 else "Regular")
    var restam: int = cardumes.consumir(alvo)
    num_peixes += 1
    peso_total += peso
    peixe_capturado.emit(especie, peso)
    var fim := " O cardume se dispersou." if restam == 0 else ""
    mensagem.emit(("Pescado: %s de %s kg!" % [especie, ("%.1f" % peso).replace(".", ",")]) + fim)

func acao() -> void:
    if not ativo:
        return
    if estado == Estado.PRONTO:
        if abs(barco.velocidade) > VELOCIDADE_MAXIMA_PESCA:
            mensagem.emit("Reduza a velocidade do barco para menos de 2 nós antes de pescar.")
            return
        alvo = cardumes.ao_alcance(barco.global_position) if cardumes != null else {}
        if alvo.is_empty():
            mensagem.emit("Nenhum cardume ao alcance. Procure as sombras na água: o radar mostra onde estão.")
            return
        if porao != null and not porao.cabe(alvo.especie):
            mensagem.emit("Não há espaço no porão para %s. Arrume o porão ou venda no cais." % alvo.especie.to_lower())
            return
        if tipo_isca == 1 and iscas_camarao <= 0 or tipo_isca == 2 and iscas_lula <= 0:
            mensagem.emit("Isca esgotada. Use B para trocar ou compre no porto.")
            return
        _lancar()
        return
    if trava > 0.0:
        return
    var i := faixa_sob_ponteiro()
    if i == -1:
        progresso = maxf(0.0, progresso - PERDA_NO_ERRO)
        trava = TRAVA_NO_ERRO
        tensao += 0.17
        errou.emit()
        return
    var f: Dictionary = faixas[i]
    ultimo_perfeito = absf(angle_difference(angulo, float(f.centro))) <= float(f.largura) * PARTE_DOURADA / 2.0
    progresso += _ganho * (2.0 if ultimo_perfeito else 1.0) * bonus_iscagem
    var forca_tecnica: float = [0.77, 1.0, 1.25][tecnica]
    progresso += _ganho * ([0.0, 0.0, 0.22][tecnica])
    tensao += (0.10 if ultimo_perfeito else 0.16) * (1.0 + voltas_por_s * 0.35) * forca_tecnica
    desgaste_linha = clampf(desgaste_linha + 0.008 * forca_tecnica, 0.0, 1.0)
    brilho = 0.35
    f.usada = 0.9                                                   # a faixa apaga e reaparece noutro lugar
    f.centro = _lugar_livre(i)
    sentido = -sentido                                              # o ponteiro inverte: não dá para decorar o ritmo
    acertou.emit(ultimo_perfeito)
    if tensao >= limite_linha:
        _romper_linha("A tensão arrebentou a linha. Puxe com mais calma!")
        return
    if progresso >= 1.0:
        _capturar()

## Um ponto do anel longe das outras faixas e do ponteiro.
func _lugar_livre(indice: int) -> float:
    var melhor: float = randf_range(0.0, TAU)
    var folga_melhor: float = -1.0
    for tentativa in 12:
        var a: float = randf_range(0.0, TAU)
        var folga: float = absf(angle_difference(a, angulo)) * 0.6
        for j in faixas.size():
            if j != indice:
                folga = minf(folga, absf(angle_difference(a, float(faixas[j].centro))) - float(faixas[j].largura))
        if folga > folga_melhor:
            folga_melhor = folga
            melhor = a
    return melhor

## Quanto peixe ainda há no cardume da linha: "Alto", "Médio" ou "Baixo".
func estoque() -> String:
    var r: int = int(alvo.get("restantes", 0))
    return "Alto" if r >= 4 else ("Médio" if r >= 2 else "Baixo")

func status() -> String:
    if estado == Estado.PUXANDO:
        return "PUXANDO · %s · tensão %d%% · [J] técnica" % [TECNICAS[tecnica], roundi(tensao * 100.0)]
    if cardumes == null or cardumes.ao_alcance(barco.global_position).is_empty():
        return "PROCURE UM CARDUME"
    if abs(barco.velocidade) > VELOCIDADE_MAXIMA_PESCA:
        return "CARDUME PERTO — reduza para pescar"
    return "CARDUME AO ALCANCE — F pescar · B isca · N profundidade"

func resetar() -> void:
    estado = Estado.PRONTO
    alvo = {}
    progresso = 0.0
    tensao = 0.0
    tipo_isca = 0
    profundidade = 1
    tecnica = 1
    linha_nivel = 0
    desgaste_linha = 0.0
    ultima_qualidade = "Regular"
    iscas_camarao = 6
    iscas_lula = 4
    num_peixes = 0
    peso_total = 0.0
    ativo = false
