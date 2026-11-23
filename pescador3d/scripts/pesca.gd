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
signal linha_rompida
signal tensao_alta        # a tensão passou de ~72% do limite: aviso sonoro

const T = preload("res://scripts/idioma.gd")

const VELOCIDADE_MAXIMA_PESCA: float = 1.03  # m/s = 2 nós
const PERDA_NO_ERRO: float = 0.10            # quanto da barra volta num aperto fora da faixa
const TRAVA_NO_ERRO: float = 0.45            # s sem poder apertar depois de errar
const PARTE_DOURADA: float = 0.30            # fração do meio da faixa que vale o dobro
# v0.5.8: peixes comuns ficaram mais fáceis (o Gabriel achou o anel difícil demais).
# Os peixes grandes, raros e de alto-mar continuam como estavam.
const COMUNS := ["Sardinha", "Tainha", "Xaréu", "Cavala", "Barracuda", "Olho-de-cão", "Baiacu", "Peixe-voador", "Budião", "Robalo"]
const FACIL := {"ponteiro": 0.85, "largura": 1.25, "acertos": 0, "espera": 0.75,
        "perda": 0.05, "trava": 0.30, "tensao_erro": 0.10, "tensao_acerto": 0.75}

## v0.6.0: cada espécie luta de um jeito. O anel mostra o ícone e a cor do comportamento.
const COMPORTAMENTO := {
    "Sardinha": "bando", "Tainha": "bando", "Baiacu": "bando", "Peixe-voador": "bando",
    "Xaréu": "corredor", "Cavala": "corredor", "Barracuda": "corredor", "Dourado": "corredor", "Atum": "corredor",
    "Arabaiana": "corredor", "Olho-de-boi": "corredor",
    "Garoupa": "pesado", "Namorado": "pesado", "Cioba": "pesado",
    "Olho-de-cão": "arisco", "Budião": "arisco", "Robalo": "arisco", "Peixe-anjo": "arisco",
    "Moreia": "escorregadio",
    "Agulhão-vela": "saltador", "Peixe-lua": "colosso",
}
## nome na tela, cor do anel e a dica que sai no diário ao lançar a linha
const INFO_COMPORTAMENTO := {
    "bando": {"nome": "Bando", "cor": Color(0.40, 0.84, 0.86), "dica": "Bando: faixas largas, luta fácil."},
    "corredor": {"nome": "Corredor", "cor": Color(0.98, 0.62, 0.26), "dica": "Corredor: o ponteiro dispara e inverte sozinho."},
    "pesado": {"nome": "Pesado", "cor": Color(0.82, 0.60, 0.34), "dica": "Pesado: a tensão sobe sozinha. Técnica Suave (J) ajuda."},
    "arisco": {"nome": "Arisco", "cor": Color(0.96, 0.52, 0.70), "dica": "Arisco: as faixas verdes não param quietas."},
    "escorregadio": {"nome": "Escorregadio", "cor": Color(0.62, 0.90, 0.36), "dica": "Escorregadio: faixas finas, mas o miolo dourado é maior."},
    "saltador": {"nome": "Saltador", "cor": Color(0.40, 0.62, 1.0), "dica": "Saltador: ele salta! Espere o aviso e aperte F quando mandar."},
    "colosso": {"nome": "Colosso", "cor": Color(0.74, 0.62, 0.96), "dica": "Colosso: a luta tem três fases, cada uma mais difícil."},
}
const TENSAO_PESADO: float = 0.20            # tensão por segundo que um peixe pesado puxa sozinho
const DISPARADA: float = 2.2                 # quanto o ponteiro acelera numa disparada do corredor

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
var comum: bool = false         # o peixe da linha é comum (anel mais fácil)
var comportamento: String = "bando"
var parte_dourada: float = PARTE_DOURADA
var mult_ponteiro: float = 1.0
var fase: int = 0               # colosso: 0, 1 ou 2
var salto_estado: int = 0       # saltador: 0 nada, 1 "espere", 2 "agora!"
var salto_t: float = 0.0
var _salto_marcas: Array = []
var _rajada: float = 0.0
var _prox_rajada: float = 2.5
var _deriva: Array = []

# Novo sistema de pesca: B troca a isca; N escolhe a camada do anzol.
const ISCAS := ["Comum", "Camarão", "Lula"]
const PROFUNDIDADES := ["Superfície", "Meia-água", "Fundo"]
const PERFIL := {
    "Sardinha": {"prof": 0, "isca": 1}, "Tainha": {"prof": 1, "isca": 1},
    "Xaréu": {"prof": 1, "isca": 2}, "Cavala": {"prof": 1, "isca": 2},
    "Barracuda": {"prof": 0, "isca": 2}, "Dourado": {"prof": 0, "isca": 2},
    "Atum": {"prof": 1, "isca": 2}, "Olho-de-cão": {"prof": 2, "isca": 1},
    "Garoupa": {"prof": 2, "isca": 1},
    "Baiacu": {"prof": 1, "isca": 1}, "Peixe-voador": {"prof": 0, "isca": 1},
    "Budião": {"prof": 1, "isca": 1}, "Robalo": {"prof": 0, "isca": 1},
    "Peixe-anjo": {"prof": 1, "isca": 1}, "Moreia": {"prof": 2, "isca": 2},
    "Arabaiana": {"prof": 1, "isca": 2}, "Namorado": {"prof": 2, "isca": 2},
    "Agulhão-vela": {"prof": 0, "isca": 2},
    "Cioba": {"prof": 2, "isca": 1}, "Olho-de-boi": {"prof": 1, "isca": 2},
    "Peixe-lua": {"prof": 0, "isca": 2},
}
var tipo_isca: int = 0
var profundidade: int = 1
var iscas_camarao: int = 6
var iscas_lula: int = 4
var tensao: float = 0.0
var _alerta_tensao: bool = false
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
    return T.t("Técnica: %s. [J]") % T.t(TECNICAS[tecnica])

func preco_linha() -> int:
    return -1 if linha_nivel >= 3 else [90, 190, 350][linha_nivel]

func reforcar_linha() -> void:
    if linha_nivel < 3:
        linha_nivel += 1
        desgaste_linha = 0.0

func estado_linha() -> String:
    return T.t("Linha %d/4 · desgaste %d%%") % [linha_nivel + 1, roundi(desgaste_linha * 100.0)]

func nome_isca() -> String:
    return ISCAS[tipo_isca]

func nome_profundidade() -> String:
    return PROFUNDIDADES[profundidade]

func trocar_isca() -> String:
    if estado == Estado.PUXANDO:
        return T.t("Termine a captura antes de trocar a isca.")
    tipo_isca = (tipo_isca + 1) % ISCAS.size()
    var quantidade: String = T.t("ilimitada") if tipo_isca == 0 else str(iscas_camarao if tipo_isca == 1 else iscas_lula)
    return T.t("Isca: %s (%s). [B]") % [T.t(nome_isca()), quantidade]

func mudar_profundidade() -> String:
    if estado == Estado.PUXANDO:
        return T.t("Termine a captura antes de ajustar o anzol.")
    profundidade = (profundidade + 1) % PROFUNDIDADES.size()
    return T.t("Anzol: %s. [N]") % T.t(nome_profundidade())

func comprar_iscas() -> void:
    iscas_camarao += 6
    iscas_lula += 3

func _soltar_cardume() -> void:
    if not alvo.is_empty():
        alvo["fisgado"] = false

func _romper_linha(motivo: String) -> void:
    salto_estado = 0
    estado = Estado.PRONTO
    _soltar_cardume()
    tensao = 0.0
    _alerta_tensao = false
    mensagem.emit(T.t(motivo))
    linha_rompida.emit()

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
    _atualizar_comportamento(delta)
    angulo = fposmod(angulo + sentido * voltas_por_s * mult_ponteiro * TAU * delta, TAU)
    # Linha forte tolera mais tensão; o desgaste reduz sua resistência máxima.
    limite_linha = 1.0 + linha_nivel * 0.15 - desgaste_linha * 0.20
    var taxa_recuperacao: float = [0.34, 0.25, 0.14][tecnica]
    tensao = maxf(0.0, tensao - delta * (taxa_recuperacao + fator_vara * 0.04))
    desgaste_linha = clampf(desgaste_linha + maxf(0.0, tensao - 0.42) * delta * 0.004, 0.0, 1.0)
    if tensao >= limite_linha:
        _romper_linha("Linha rompida pelo excesso de tensão. Espere entre as puxadas!")
        return
    var relativa: float = tensao / maxf(0.1, limite_linha)
    if relativa > 0.72 and not _alerta_tensao:
        _alerta_tensao = true
        tensao_alta.emit()
    elif relativa < 0.55:
        _alerta_tensao = false
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
    _alerta_tensao = false
    comum = COMUNS.has(String(alvo.especie))
    voltas_por_s = float(dados.get("ponteiro", 0.5)) * (FACIL.ponteiro if comum else 1.0)
    var n: int = int(dados.get("faixas", 3))
    var largura: float = deg_to_rad(float(dados.get("largura", 38))) * fator_vara * bonus_iscagem * (FACIL.largura if comum else 1.0)
    var acertos: int = int(dados.get("acertos", 3)) + (int(FACIL.acertos) if comum else 0)
    _ganho = 1.0 / float(maxi(2, acertos)) + 0.01
    limite_linha = 1.0 + linha_nivel * 0.15 - desgaste_linha * 0.20
    var espera: Array = dados.get("espera", [3.0, 6.0])
    _sozinho = 1.0 / (randf_range(espera[0], espera[1]) * 3.0 * (FACIL.espera if comum else 1.0))      # sem acertar nada: de 8 a 24 s
    comportamento = String(COMPORTAMENTO.get(String(alvo.especie), "bando"))
    parte_dourada = PARTE_DOURADA
    fase = 0
    salto_estado = 0
    _rajada = 0.0
    _prox_rajada = randf_range(1.6, 3.0)
    _salto_marcas = [0.30, 0.65] if comportamento == "saltador" else []
    match comportamento:
        "bando":
            largura *= 1.12
            voltas_por_s *= 0.92
        "escorregadio":
            largura *= 0.62
            parte_dourada = 0.60
    faixas.clear()
    _deriva.clear()
    var inicio := randf_range(0.0, TAU)
    for i in n:                                                     # espalhadas pelo anel, sem encostar
        faixas.append({"centro": fposmod(inicio + TAU * i / n + randf_range(-0.25, 0.25), TAU), "largura": largura * randf_range(0.85, 1.15), "usada": 0.0})
        _deriva.append(1.0 if i % 2 == 0 else -1.0)
    angulo = fposmod(float(faixas[0].centro) + PI + randf_range(-0.4, 0.4), TAU)    # começa longe de uma faixa
    sentido = 1.0
    progresso = 0.0
    trava = 0.0
    brilho = 0.0
    estado = Estado.PUXANDO
    alvo["fisgado"] = true
    linha_lancada.emit()
    mensagem.emit("%s — %s" % [T.t(String(alvo.especie)), T.t(String(INFO_COMPORTAMENTO[comportamento].dica))])

func _capturar() -> void:
    estado = Estado.PRONTO
    _soltar_cardume()
    var especie: String = alvo.especie
    var peso: float = cardumes.sortear_peso(especie)
    ultima_qualidade = "Excepcional" if tensao < 0.28 and bonus_iscagem > 1.06 else ("Boa" if tensao < 0.58 else "Regular")
    var restam: int = cardumes.consumir(alvo)
    num_peixes += 1
    peso_total += peso
    peixe_capturado.emit(especie, peso)
    var fim: String = T.t(" O cardume se dispersou.") if restam == 0 else ""
    mensagem.emit((T.t("Pescado: %s de %s kg!") % [T.t(especie), ("%.1f" % peso).replace(".", ",")]) + fim)

func acao() -> void:
    if not ativo:
        return
    if estado == Estado.PRONTO:
        if abs(barco.velocidade) > VELOCIDADE_MAXIMA_PESCA:
            mensagem.emit(T.t("Reduza a velocidade do barco para menos de 2 nós antes de pescar."))
            return
        alvo = cardumes.ao_alcance(barco.global_position) if cardumes != null else {}
        if alvo.is_empty():
            mensagem.emit(T.t("Nenhum cardume ao alcance. O radar mostra onde estão os peixes."))
            return
        if porao != null and not porao.cabe(alvo.especie):
            mensagem.emit(T.t("Não há espaço no porão para %s. Arrume o porão ou venda no cais.") % T.t(String(alvo.especie)).to_lower())
            return
        if tipo_isca == 1 and iscas_camarao <= 0 or tipo_isca == 2 and iscas_lula <= 0:
            mensagem.emit(T.t("Isca esgotada. Use B para trocar ou compre no porto."))
            return
        _lancar()
        return
    if salto_estado != 0:
        _apertou_no_salto()
        return
    if trava > 0.0:
        return
    var i := faixa_sob_ponteiro()
    if i == -1:
        progresso = maxf(0.0, progresso - (FACIL.perda if comum else PERDA_NO_ERRO))
        trava = FACIL.trava if comum else TRAVA_NO_ERRO
        tensao += FACIL.tensao_erro if comum else 0.17
        errou.emit()
        return
    var f: Dictionary = faixas[i]
    ultimo_perfeito = absf(angle_difference(angulo, float(f.centro))) <= float(f.largura) * parte_dourada / 2.0
    progresso += _ganho * (2.0 if ultimo_perfeito else 1.0) * bonus_iscagem
    var forca_tecnica: float = [0.77, 1.0, 1.25][tecnica]
    progresso += _ganho * ([0.0, 0.0, 0.22][tecnica])
    tensao += (0.10 if ultimo_perfeito else 0.16) * (1.0 + voltas_por_s * 0.35) * forca_tecnica * (FACIL.tensao_acerto if comum else 1.0)
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

## v0.6.0: o que cada comportamento faz com o anel, a cada quadro.
func _atualizar_comportamento(delta: float) -> void:
    mult_ponteiro = 1.0
    var corre: bool = comportamento == "corredor" or comportamento == "saltador" or (comportamento == "colosso" and fase == 2)
    if salto_estado != 0:
        mult_ponteiro = 0.0                                          # o peixe saltou: o anel congela
    elif corre:
        if _rajada > 0.0:
            _rajada -= delta
            mult_ponteiro = DISPARADA
        else:
            _prox_rajada -= delta
            if _prox_rajada <= 0.0:
                _prox_rajada = randf_range(2.0, 3.8)
                if randf() < 0.5:
                    _rajada = randf_range(0.55, 0.9)
                else:
                    sentido = -sentido
    if comportamento == "arisco":
        for i in faixas.size():
            faixas[i].centro = fposmod(float(faixas[i].centro) + float(_deriva[i]) * 0.55 * delta, TAU)
    var passivo: float = 0.0
    if comportamento == "pesado":
        passivo = TENSAO_PESADO
    elif comportamento == "colosso":
        var nova: int = 0 if progresso < 0.33 else (1 if progresso < 0.66 else 2)
        if nova != fase:
            fase = nova
            for f in faixas:
                f.largura = float(f.largura) * 0.82
            mensagem.emit(T.t("O peixe-lua se agita! Fase %d de 3.") % (fase + 1))
        passivo = [0.0, 0.18, 0.12][fase]
    tensao += passivo * delta
    if comportamento == "saltador":
        _atualizar_salto(delta)

func _atualizar_salto(delta: float) -> void:
    if salto_estado == 0:
        if not _salto_marcas.is_empty() and progresso >= float(_salto_marcas[0]):
            _salto_marcas.pop_front()
            salto_estado = 1
            salto_t = randf_range(0.55, 0.95)
            mensagem.emit(T.t("O agulhão vai saltar! Espere o aviso..."))
        return
    salto_t -= delta
    if salto_t > 0.0:
        return
    if salto_estado == 1:
        salto_estado = 2
        salto_t = 0.95
    else:
        salto_estado = 0
        tensao += 0.22
        mensagem.emit(T.t("O agulhão sacudiu a linha! Apertou tarde."))

## F durante o salto: cedo demais custa tensão; na hora certa o agulhão cansa de uma vez.
func _apertou_no_salto() -> void:
    if salto_estado == 1:
        salto_estado = 0
        tensao += 0.14
        progresso = maxf(0.0, progresso - 0.04)
        errou.emit()
        mensagem.emit(T.t("Cedo demais! O agulhão aproveitou a folga."))
        return
    salto_estado = 0
    ultimo_perfeito = true
    brilho = 0.35
    progresso += 0.16
    tensao = maxf(0.0, tensao - 0.10)
    acertou.emit(true)
    mensagem.emit(T.t("Salto aparado!"))
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
        return T.t("PUXANDO · %s · tensão %d%% · [J] técnica") % [T.t(TECNICAS[tecnica]), roundi(tensao * 100.0)]
    if cardumes == null or cardumes.ao_alcance(barco.global_position).is_empty():
        return T.t("PROCURE UM CARDUME")
    if abs(barco.velocidade) > VELOCIDADE_MAXIMA_PESCA:
        return T.t("CARDUME PERTO — reduza para pescar")
    return T.t("CARDUME AO ALCANCE — F pescar · B isca · N profundidade")

func resetar() -> void:
    salto_estado = 0
    estado = Estado.PRONTO
    _soltar_cardume()
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
