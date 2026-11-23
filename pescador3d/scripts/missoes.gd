extends Node
## As missões, uma de cada vez, em ordem. Cada uma pede um tipo de acontecimento (pescar, vender,
## comprar, atracar, juntar dinheiro...) e paga um prêmio. scripts/jogo.gd avisa o que aconteceu com evento().
## v0.6.0: cada missão tem um NPC que a passa ("dado_por") e as falas do diálogo ao atracar:
## "oferta" (quando a missão começa) e "fim" (quando ela termina; "fim_por" = outro NPC, se for o caso).
## O texto de tudo é a chave de tradução de scripts/idioma.gd.

signal cumprida(missao: Dictionary)

const T = preload("res://scripts/idioma.gd")
const Npcs = preload("res://scripts/npcs.gd")

## tipo: "pescar" (alvo = espécie, ou "" para qualquer), "vender", "comprar", "atracar" (alvo = nome da ilha),
## "dinheiro" (quantos = quanto ter na carteira), "explorar", "contrato" (alvo = ilha, ou "" para qualquer),
## "entregar" (alvo = ilha de destino; o NPC põe a caixa no porão)
const LISTA := [
    {"texto": "Pescaria inaugural", "tipo": "pescar", "alvo": "", "quantos": 3, "premio": 20,
            "dica": "Pare perto de um cardume e aperte F.",
            "dado_por": "jacinto",
            "oferta": ["Bom dia, rapaz! Esse é o Estrela d'Alva, o barco do meu falecido compadre. Agora ele é seu.",
                    "Vá até um cardume ali na frente, pare o barco e aperte F para lançar a linha. Pesque umas três."],
            "fim": ["Isso! Você leva jeito. O mar gosta de quem tem paciência."]},
    {"texto": "Vender os peixes no cais", "tipo": "vender", "alvo": "", "quantos": 1, "premio": 30,
            "dica": "Siga a âncora do radar e aperte F na ponta do cais.",
            "dado_por": "zefa",
            "oferta": ["Ô, pescador! Peixe fresco é comigo. Traga o porão cheio que eu pago na hora.",
                    "É só atracar na ponta do cais e vender. Aperte 1, ou clique em Vender."],
            "fim": ["Que beleza! Esse aí vai direto para a feira. Volte sempre!"]},
    {"texto": "Comprar uma melhoria", "tipo": "comprar", "alvo": "", "quantos": 1, "premio": 40,
            "dica": "No cais da Vila do Porto, teclas 3 a 6.",
            "dado_por": "jacinto",
            "oferta": ["Esse motor já viu dias melhores... Dê uma olhada na oficina do cais.",
                    "Qualquer melhoria serve: motor, tanque, porão, vara. O dinheiro do peixe é para isso."],
            "fim": ["Agora sim! Barco bom é barco bem cuidado."]},
    {"texto": "Pescar olho-de-cão à noite", "tipo": "pescar", "alvo": "Olho-de-cão", "quantos": 2, "premio": 80,
            "dica": "Ele só aparece depois que escurece.",
            "dado_por": "jacinto",
            "oferta": ["O olho-de-cão é vermelho feito brasa e só aparece quando escurece.",
                    "Pesque dois e eu te conto o que mais a noite esconde."],
            "fim": ["Vermelhinhos, não é? A noite no mar tem dessas."]},
    {"texto": "Atracar na Ilha das Rocas", "tipo": "atracar", "alvo": "Ilha das Rocas", "quantos": 1, "premio": 100,
            "dica": "Fica a noroeste da vila. Leve diesel.",
            "dado_por": "jacinto",
            "oferta": ["A noroeste daqui tem a Ilha das Rocas. Meu amigo Toinho cuida do posto de lá.",
                    "Leve diesel: lá é mais caro, mas o peixe vale mais. Diga que fui eu que mandei."],
            "fim_por": "toinho",
            "fim": ["Opa, visita! Faz tempo que ninguém atraca por aqui.",
                    "Se o Jacinto mandou, é de confiança. Aqui o peixe paga mais: pode vender à vontade."]},
    {"texto": "Pescar um atum em alto-mar", "tipo": "pescar", "alvo": "Atum", "quantos": 1, "premio": 150,
            "dica": "Só longe das ilhas. Precisa de 6 casas livres.",
            "dado_por": "toinho",
            "oferta": ["Aqui de cima eu vejo os atuns passando, bem longe, onde a água é escura.",
                    "Vá para longe das ilhas e deixe o porão livre: um atum grande ocupa seis casas."],
            "fim": ["Um atum! Faz tempo que eu não via um desses de perto."]},
    {"texto": "Juntar R$ 1000", "tipo": "dinheiro", "alvo": "", "quantos": 1000, "premio": 0,
            "dica": "A Ilha das Rocas paga mais pelo peixe.",
            "dado_por": "zefa",
            "oferta": ["Sabe quanto custa um motor de verdade? Junte mil reais e depois a gente conversa.",
                    "Vender nas Rocas rende mais, e as encomendas pagam bônus."],
            "fim": ["Mil reais! Olha só, o pescador virou capitalista."]},
    {"texto": "Descobrir o Banco das Cavalas", "tipo": "explorar", "alvo": "Banco das Cavalas", "quantos": 1, "premio": 85,
            "dica": "Consulte a carta náutica com M. Navegue até o banco submerso.",
            "dado_por": "jacinto",
            "oferta": ["Dizem que existe um banco de pedra debaixo d'água onde as cavalas se juntam aos milhares.",
                    "Abra a carta náutica com M e marque o destino. E cuidado com as pedras."],
            "fim": ["Então é verdade! Meu avô falava desse lugar."]},
    {"texto": "Entregar uma encomenda", "tipo": "contrato", "alvo": "", "quantos": 1, "premio": 120,
            "dica": "Veja a encomenda atual no cais. Venda a quantidade pedida.",
            "dado_por": "zefa",
            "oferta": ["Chegou pedido na feira: o freguês quer uma quantidade certa de um peixe só.",
                    "Veja a encomenda no painel do cais e venda a quantidade pedida. O bônus é por minha conta."],
            "fim": ["Freguês satisfeito, bolso cheio. É assim que se faz!"]},
    {"texto": "Atracar na Ilha de São Pedro", "tipo": "atracar", "alvo": "Ilha de São Pedro", "quantos": 1, "premio": 220,
            "dica": "O arquipélago de São Pedro fica longe, a oeste (veja a carta, M). Encha o tanque antes.",
            "dado_por": "toinho",
            "oferta": ["Lá no oeste, bem longe, fica São Pedro. Tem um farol e uma feira que você não vê por aqui.",
                    "A viagem é comprida. Encha o tanque antes e não saia perto do anoitecer."],
            "fim_por": "rosa",
            "fim": ["Mas olha só! Gente nova em São Pedro!",
                    "Eu sou a Rosa. Aqui o peixe de recife vale ouro, e quem pesca cioba é sempre bem-vindo."]},
    {"texto": "Explorar o Canal das Sardinhas", "tipo": "explorar", "alvo": "Canal das Sardinhas", "quantos": 1, "premio": 95,
            "dica": "Marque o destino na carta náutica e navegue até o novo banco.",
            "dado_por": "jacinto",
            "oferta": ["Nas manhãs de maré cheia as sardinhas entram num canal estreito. É um espetáculo.",
                    "Marque o destino na carta e vá até lá."],
            "fim": ["As sardinhas! Já pensou ter uma rede para dar conta de tudo aquilo?"]},
    {"texto": "Pescar um agulhão-vela", "tipo": "pescar", "alvo": "Agulhão-vela", "quantos": 1, "premio": 350,
            "dica": "Só de dia e bem longe das ilhas. É rápido e forte; precisa de 6 casas livres.",
            "dado_por": "toinho",
            "oferta": ["Você já viu um agulhão-vela saltar? A vela azul aberta no sol...",
                    "Só de dia e bem longe. Ele é rápido e forte: segure a linha com calma."],
            "fim": ["Um agulhão! Ninguém vai acreditar quando eu contar."]},
    {"texto": "Pescar uma moreia à noite", "tipo": "pescar", "alvo": "Moreia", "quantos": 1, "premio": 160,
            "dica": "Só nos recifes e só depois que escurece. Lula no fundo (B e N) ajuda.",
            "dado_por": "jacinto",
            "oferta": ["Moreia mora nas pedras do recife e só sai à noite. Tem dente e mau humor.",
                    "Use lula no fundo (B e N). E cuidado com o dedo."],
            "fim": ["Que bicho feio! Mas dá um caldo e tanto..."]},
    {"texto": "Pescar um peixe-anjo no recife", "tipo": "pescar", "alvo": "Peixe-anjo", "quantos": 1, "premio": 220,
            "dica": "É raro e só aparece de dia, nos recifes. Camarão, na meia-água.",
            "dado_por": "zefa",
            "oferta": ["Conhece o peixe-anjo? Lindo, raro, azulzinho. Turista paga o que eu pedir.",
                    "Só de dia, nos recifes. Camarão na meia-água."],
            "fim": ["Que lindeza! Dá até pena de vender."]},
    {"texto": "Entregar 3 encomendas", "tipo": "contrato", "alvo": "", "quantos": 3, "premio": 300,
            "dica": "Veja a encomenda atual no cais e venda a quantidade pedida.",
            "dado_por": "zefa",
            "oferta": ["Agora o pessoal da feira só quer saber de você. Três encomendas, que tal?",
                    "Cada uma paga bônus. Olhe o painel do cais antes de partir."],
            "fim": ["Três de uma vez! Já tem freguês pedindo o seu peixe pelo nome."]},
    {"texto": "Juntar R$ 3000", "tipo": "dinheiro", "alvo": "", "quantos": 3000, "premio": 200,
            "dica": "Peixes raros e encomendas pagam melhor; a Ilha das Rocas paga mais pelo peixe.",
            "dado_por": "jacinto",
            "oferta": ["Quem diria, hein? O barco do compadre nas suas mãos...",
                    "Junte três mil. Com isso você chega até aonde eu nunca cheguei."],
            "fim": ["Três mil! O compadre ia gostar de ver."]},
    # --- segunda parte: a Ilha de São Pedro (v0.6.0)
    {"texto": "Levar a caixa de peças ao faroleiro", "tipo": "entregar", "alvo": "Ilha de São Pedro", "quantos": 1, "premio": 260,
            "dica": "A caixa ocupa 4 casas do porão. Entregue na Ilha de São Pedro (carta náutica, M) e encha o tanque antes.",
            "dado_por": "jacinto",
            "oferta": ["O Abílio, faroleiro de São Pedro, é meu velho compadre. A lâmpada do farol anda falhando.",
                    "Esta caixa tem as peças. Ocupa um bom espaço no porão: leve com cuidado e entregue só a ele."],
            "fim_por": "abilio",
            "fim": ["As peças! Faz meses que eu esperava. Sem elas, o farol apagava em noite de bruma.",
                    "Fique um instante, pescador. Preciso te contar uma coisa."]},
    {"texto": "Pescar um peixe-lua nas noites de bruma", "tipo": "pescar", "alvo": "Peixe-lua", "quantos": 1, "premio": 420,
            "dica": "Só em noite de neblina, longe das ilhas. O facho do farol clareia a bruma.",
            "dado_por": "abilio",
            "oferta": ["Nas noites de bruma sobe do fundo uma luz pálida, longe daqui. Os velhos chamam de peixe-lua.",
                    "Dizem que o facho do farol afasta a neblina, mas só até certo ponto.",
                    "Se for, vá numa noite de bruma. Se vir vultos no mar... não os siga. Mire a luz e volte."],
            "fim": ["Então era isso que brilhava...",
                    "Obrigado por voltar inteiro, pescador. Nem todo mundo volta."]},
    {"texto": "Cumprir o pedido semanal de Dona Rosa", "tipo": "contrato", "alvo": "Ilha de São Pedro", "quantos": 1, "premio": 450,
            "dica": "Veja o pedido no cais de São Pedro. As ciobas vivem nos recifes de lá.",
            "dado_por": "rosa",
            "oferta": ["Toda semana eu preciso de cioba para a feira. Cinco, fresquinhas.",
                    "Pesque nos recifes daqui e venda aqui mesmo: o pedido paga bônus, além do preço da feira."],
            "fim": ["Que cioba bonita! Pode contar com um pedido novo toda semana."]},
    {"texto": "Descobrir o Recife da Agulha", "tipo": "explorar", "alvo": "Recife da Agulha", "quantos": 1, "premio": 150,
            "dica": "Fica ao lado do Ilhéu da Agulha, a leste de São Pedro. Há pedras escondidas na água: devagar!",
            "dado_por": "abilio",
            "oferta": ["A leste do farol tem o Ilhéu da Agulha, e junto dele um recife cheio de pedras que não aparecem.",
                    "Já vi barco bom rasgar o casco ali. Vá devagar e olhe a carta."],
            "fim": ["Passou pela Agulha sem arranhar? Você tem mão boa no leme."]},
    {"texto": "Juntar R$ 6000", "tipo": "dinheiro", "alvo": "", "quantos": 6000, "premio": 500,
            "dica": "Ciobas, olhos-de-boi e peixes-lua pagam muito bem em São Pedro.",
            "dado_por": "rosa",
            "oferta": ["Sabe o que falta no seu barco? Um nome conhecido nas feiras de todo canto.",
                    "Junte seis mil e eu mesma ponho seu nome na lousa da feira."],
            "fim": ["Seis mil! Seu nome já está na lousa. Daqui para frente, o mar é seu."]},
]

var indice: int = 0
var progresso: int = 0
var oferecidas: Dictionary = {}          # índice da missão -> true: o NPC já apresentou a missão
var fim_pendentes: Array = []            # missões cumpridas cuja fala final ainda não foi dita
var _volta_papo: Dictionary = {}         # NPC -> próxima fala da conversa fiada

func terminou() -> bool:
    return indice >= LISTA.size()

func atual() -> Dictionary:
    return {} if terminou() else LISTA[indice]

func titulo() -> String:
    return T.t("Viagem livre") if terminou() else T.t("Missão %d de %d") % [indice + 1, LISTA.size()]

## O que o HUD mostra. Missões de entrega pedem, antes, uma conversa para pegar a carga.
func texto() -> String:
    if terminou():
        return T.t("Pescar, vender e melhorar o barco")
    var m: Dictionary = LISTA[indice]
    if m.tipo == "entregar" and not oferecidas.has(indice):
        var npc: Dictionary = Npcs.DADOS[m.dado_por]
        return T.t("Falar com %s (%s)") % [T.t(npc.nome), T.t(npc.ilha)]
    var base: String = T.t(m.texto)
    if m.tipo == "dinheiro" or int(m.quantos) <= 1:
        return base
    return "%s (%d/%d)" % [base, progresso, m.quantos]

func dica() -> String:
    if terminou():
        return ""
    var m: Dictionary = LISTA[indice]
    if m.tipo == "entregar" and not oferecidas.has(indice):
        return T.t("Ele (ela) passa a caixa para você quando você atraca no cais.")
    return T.t(str(m.dica))

## Algo aconteceu no jogo. "quantidade" é o dinheiro na carteira quando o tipo é "dinheiro".
func evento(tipo: String, alvo: String = "", quantidade: int = 1) -> void:
    if terminou():
        return
    var m: Dictionary = LISTA[indice]
    if m.tipo != tipo or (m.alvo != "" and m.alvo != alvo):
        return
    if tipo == "entregar" and not oferecidas.has(indice):
        return
    progresso = quantidade if tipo == "dinheiro" else progresso + quantidade
    if progresso >= int(m.quantos):
        fim_pendentes.append(indice)
        indice += 1
        progresso = 0
        cumprida.emit(m)

func zerar() -> void:
    indice = 0
    progresso = 0
    oferecidas.clear()
    fim_pendentes.clear()
    _volta_papo.clear()

func _falas(id: String, linhas: Array) -> Array:
    var saida: Array = []
    for l in linhas:
        saida.append({"npc": id, "texto": T.t(str(l)), "chave": str(l)})   # "chave": o diálogo retraduz se o idioma mudar no meio
    return saida

## Há algo novo a dizer neste cais? (sem gastar nada)
func tem_falas_em(nome_ilha: String) -> bool:
    for i in fim_pendentes:
        var m: Dictionary = LISTA[i]
        if Npcs.DADOS[str(m.get("fim_por", m.dado_por))].ilha == nome_ilha:
            return true
    if not terminou():
        var m: Dictionary = LISTA[indice]
        if not oferecidas.has(indice) and Npcs.DADOS[m.dado_por].ilha == nome_ilha:
            return true
    return false

## As falas que o cais tem para dar: o final das missões cumpridas (se o NPC está nesta ilha) e a apresentação
## da missão que começa. Devolve {falas, carga}: "carga" = o NPC põe a caixa de peças no porão.
func falas_ao_atracar(nome_ilha: String) -> Dictionary:
    var falas: Array = []
    var carga := false
    for i in fim_pendentes.duplicate():
        var m: Dictionary = LISTA[i]
        var quem: String = str(m.get("fim_por", m.dado_por))
        if Npcs.DADOS[quem].ilha == nome_ilha:
            falas.append_array(_falas(quem, m.fim))
            fim_pendentes.erase(i)
        elif fim_pendentes.size() > 3:                      # não deixa pilha de finais velhos
            fim_pendentes.erase(i)
    if not terminou():
        var m: Dictionary = LISTA[indice]
        if not oferecidas.has(indice) and Npcs.DADOS[m.dado_por].ilha == nome_ilha:
            oferecidas[indice] = true
            falas.append_array(_falas(m.dado_por, m.oferta))
            carga = m.tipo == "entregar"
    return {"falas": falas, "carga": carga}

## Puxar papo com um NPC do cais: lembra a missão dele, devolve a caixa que se perdeu, ou conversa fiada.
func falas_do_papo(id: String, tem_carga: bool) -> Dictionary:
    var carga := false
    if not terminou():
        var m: Dictionary = LISTA[indice]
        if m.dado_por == id and oferecidas.has(indice):
            if m.tipo == "entregar" and not tem_carga:
                carga = true
                return {"falas": _falas(id, ["Perdeu a caixa no caminho? Tenho outra aqui. Cuide bem dela desta vez."]), "carga": true}
            var lembrete: Array = [T.t("Então, como vai aquela história: %s?") % T.t(m.texto), m.dica]
            var saida: Array = [{"npc": id, "texto": lembrete[0], "chave": "Então, como vai aquela história: %s?", "arg": str(m.texto)}]
            saida.append_array(_falas(id, [lembrete[1]]))
            return {"falas": saida, "carga": false}
    var conversa: Array = Npcs.PAPO[id]
    var n: int = int(_volta_papo.get(id, 0))
    _volta_papo[id] = n + 1
    return {"falas": _falas(id, [conversa[n % conversa.size()]]), "carga": carga}
