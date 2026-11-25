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
    # v0.9.1: falas reescritas: cada morador guarda um pedaço do sumiço do Bento (doc "Bruma — falas dos personagens").
    # Mudaram de dono: 11 e 20 (Maíra), 23 (fim com a Luana) e 24 (oferta da Luana, fim com o Abílio).
    {"texto": "Pescaria inaugural", "tipo": "pescar", "alvo": "", "quantos": 3, "premio": 20,
            "dica": "Pare perto de um cardume e aperte F.",
            "dado_por": "jacinto",
            "oferta": ["Bom dia, rapaz. Esse é o Estrela d'Alva. Ficou três anos amarrado nesse cais esperando alguém com coragem de soltar a corda.",
                    "Leva ele pra fora da arrebentação e me traz uns peixes. Quero ver se ele ainda sabe navegar.",
                    "Para perto de um cardume, desliga o motor e aperta F pra lançar a linha. Três peixes tá bom."],
            "fim": ["Ele obedeceu você. Comigo ele nunca mais obedeceu."]},
    {"texto": "Vender os peixes no cais", "tipo": "vender", "alvo": "", "quantos": 1, "premio": 30,
            "dica": "Siga a âncora do radar e aperte F na ponta do cais.",
            "dado_por": "zefa",
            "oferta": ["Você que chegou no Estrela d'Alva? ... Pois é.",
                    "Traz o peixe pra banca que eu pago o preço justo. Nem mais, nem menos.",
                    "Atraca na ponta do cais e vende: aperta 1, ou clica em Vender."],
            "fim": ["Peixe limpo, bem tratado. Quem te ensinou foi o Jacinto, dá pra ver."]},
    {"texto": "Comprar uma melhoria", "tipo": "comprar", "alvo": "", "quantos": 1, "premio": 40,
            "dica": "No cais da Vila do Porto, teclas 3 a 6.",
            "dado_por": "jacinto",
            "oferta": ["O motor tá cansado e a rede tá podre. A oficina do porto conserta.",
                    "Gasta dinheiro no barco, que é ele que te traz de volta."],
            "fim": ["Agora sim. Do jeito que ele era antes."]},
    {"texto": "Pescar olho-de-cão à noite", "tipo": "pescar", "alvo": "Olho-de-cão", "quantos": 2, "premio": 80,
            "dica": "Ele só aparece depois que escurece.",
            "dado_por": "jacinto",
            "oferta": ["Olho-de-cão só sobe de noite. Leva a lanterna acesa e não desliga por nada. Por nada, ouviu?"],
            "fim": ["Voltou inteiro. Viu alguma coisa estranha lá fora? ... Não precisa me contar."]},
    {"texto": "Atracar na Ilha das Rocas", "tipo": "atracar", "alvo": "Ilha das Rocas", "quantos": 1, "premio": 100,
            "dica": "Fica a noroeste da vila. Leve diesel.",
            "dado_por": "jacinto",
            "oferta": ["Tá na hora de ir mais longe. O Atol das Rocas fica a noroeste. Leva diesel.",
                    "Tem um rapaz lá, o Toinho, que cuida da estação. Diz que fui eu que mandei."],
            "fim_por": "toinho",
            "fim": ["Gente! Faz duas semanas que não vejo ninguém.",
                    "Você veio no barco do... no Estrela d'Alva? Amarra ali, que a maré aqui vira rápido. E o peixe aqui paga mais."]},
    {"texto": "Pescar um atum em alto-mar", "tipo": "pescar", "alvo": "Atum", "quantos": 1, "premio": 150,
            "dica": "Só longe das ilhas. Precisa de 6 casas livres.",
            "dado_por": "toinho",
            "oferta": ["Atum passa lá fora, longe das ilhas, rápido que nem bala. Deixa seis casas livres no porão.",
                    "Se pegar um, te ensino a limpar do jeito certo."],
            "fim": ["Olha o tamanho disso! Vou contar no rádio, ninguém vai acreditar."]},
    {"texto": "Juntar R$ 1000", "tipo": "dinheiro", "alvo": "", "quantos": 1000, "premio": 0,
            "dica": "A Ilha das Rocas paga mais pelo peixe.",
            "dado_por": "zefa",
            "oferta": ["Mil reais guardados. Pescador que não guarda dinheiro vende o barco no primeiro inverno.",
                    "Não vende esse barco."],
            "fim": ["Mil. Agora guarda mais."]},
    {"texto": "Descobrir o Banco das Cavalas", "tipo": "explorar", "alvo": "Banco das Cavalas", "quantos": 1, "premio": 85,
            "dica": "Consulte a carta náutica com M. Navegue até o banco submerso.",
            "dado_por": "jacinto",
            "oferta": ["Banco das Cavalas. Eu e meu parceiro enchíamos o barco lá em meia hora.",
                    "Abre a carta com M e marca o destino. Vê se o cardume ainda lembra do caminho."],
            "fim": ["Ainda lembra. Tem coisa que o mar não esquece."]},
    {"texto": "Entregar uma encomenda", "tipo": "contrato", "alvo": "", "quantos": 1, "premio": 120,
            "dica": "Veja a encomenda atual no cais. Venda a quantidade pedida.",
            "dado_por": "zefa",
            "oferta": ["Tenho uma freguesa exigente. O que ela quer tá no painel do cais, e ela quer hoje.",
                    "Vende a quantidade certa que o bônus é por minha conta."],
            "fim": ["Chegou fresco. Ela vai voltar, e você também."]},
    {"texto": "Atracar na Ilha de São Pedro", "tipo": "atracar", "alvo": "Ilha de São Pedro", "quantos": 1, "premio": 220,
            "dica": "O arquipélago de São Pedro fica longe, a oeste (veja a carta, M). Encha o tanque antes.",
            "dado_por": "toinho",
            "oferta": ["Quer ir mais longe? São Pedro fica lá no oeste, no meio do nada. Tem uma mercadora lá, a Maíra.",
                    "Enche o tanque antes, que no caminho não tem onde parar. E não sai perto do anoitecer."],
            "fim_por": "rosa",
            "fim": ["Chegou inteiro, que milagre. Aqui é a loja da Maíra: combustível, isca, gelo e conselho de graça.",
                    "O conselho é: não pesca na bruma."]},
    {"texto": "Explorar o Canal das Sardinhas", "tipo": "explorar", "alvo": "Canal das Sardinhas", "quantos": 1, "premio": 95,
            "dica": "Marque o destino na carta náutica e navegue até o novo banco.",
            "dado_por": "rosa",
            "oferta": ["Tem um caderno de rotas aqui que um freguês esqueceu.",
                    "Diz que no canal entre as pedras, perto da Vila, passa sardinha toda noite de lua. Marca na carta e vai conferir pra mim."],
            "fim": ["O caderno tava certo. Ele sempre tava certo."]},
    {"texto": "Pescar um agulhão-vela", "tipo": "pescar", "alvo": "Agulhão-vela", "quantos": 1, "premio": 350,
            "dica": "Só de dia e bem longe das ilhas. É rápido e forte; precisa de 6 casas livres.",
            "dado_por": "toinho",
            "oferta": ["Agulhão-vela salta da água igual bandeira. Mas briga.",
                    "Só de dia e bem longe das ilhas. Segura a linha e não solta."],
            "fim": ["Você é bom nisso. Melhor que eu, que só pesco do píer."]},
    {"texto": "Pescar uma moreia à noite", "tipo": "pescar", "alvo": "Moreia", "quantos": 1, "premio": 160,
            "dica": "Só nos recifes e só depois que escurece. Lula no fundo (B e N) ajuda.",
            "dado_por": "jacinto",
            "oferta": ["Moreia mora nas pedras e morde quem mete a mão. Igual gente velha. Me traz uma, que a Luana faz caldo.",
                    "Só sai de noite. Lula no fundo (B e N)."],
            "fim": ["Essa é das grandes. O Bento ia... deixa pra lá."]},
    {"texto": "Pescar um peixe-anjo no recife", "tipo": "pescar", "alvo": "Peixe-anjo", "quantos": 1, "premio": 220,
            "dica": "É raro e só aparece de dia, nos recifes. Camarão, na meia-água.",
            "dado_por": "zefa",
            "oferta": ["Peixe-anjo. O Zeca, meu cunhado, chamava de peixe de igreja, por causa das cores. Me traz um, quero ver de novo.",
                    "Só de dia, nos recifes. Camarão na meia-água."],
            "fim": ["É bonito, não é? Tem coisa bonita no fundo também."]},
    {"texto": "Entregar 3 encomendas", "tipo": "contrato", "alvo": "", "quantos": 3, "premio": 300,
            "dica": "Veja a encomenda atual no cais e venda a quantidade pedida.",
            "dado_por": "zefa",
            "oferta": ["Três encomendas de uma vez. A banca não vende tanto desde... faz tempo. Dá conta?",
                    "Olha o painel do cais antes de sair."],
            "fim": ["Deu conta. Senta aí, toma um café."]},
    {"texto": "Juntar R$ 3000", "tipo": "dinheiro", "alvo": "", "quantos": 3000, "premio": 200,
            "dica": "Peixes raros e encomendas pagam melhor; a Ilha das Rocas paga mais pelo peixe.",
            "dado_por": "jacinto",
            "oferta": ["Três mil reais. Dá pra trocar o casco e ainda sobra pro diesel. Barco bom é barco que volta."],
            "fim": ["Tá ficando melhor pescador do que eu fui."]},
    # --- segunda parte: a Ilha de São Pedro (v0.6.0)
    {"texto": "Levar a caixa de peças ao faroleiro", "tipo": "entregar", "alvo": "Ilha de São Pedro", "quantos": 1, "premio": 260,
            "dica": "A caixa ocupa 4 casas do porão. Entregue na Ilha de São Pedro (carta náutica, M) e encha o tanque antes.",
            "dado_por": "jacinto",
            "oferta": ["Essa caixa é do Abílio, o faroleiro de São Pedro: peças do farol, pavio e café.",
                    "Toda semana o meu parceiro levava uma dessas. Faz três anos que ela fica aqui no cais. Leva você.",
                    "Ocupa quatro casas do porão. Entrega na mão dele."],
            "fim_por": "abilio",
            "fim": ["O Jacinto mandou. ... Pavio novo. O antigo durou mais do que devia."]},
    {"texto": "Pescar um peixe-lua nas noites de bruma", "tipo": "pescar", "alvo": "Peixe-lua", "quantos": 1, "premio": 420,
            "dica": "Só em noite de neblina, longe das ilhas. O facho do farol clareia a bruma.",
            "dado_por": "abilio",
            "oferta": ["Peixe-lua só aparece na bruma. Sobe pra tomar sol e não tem sol.",
                    "Pesca um e traz aqui. Quero saber se você volta da bruma."],
            "fim": ["Voltou. Viu os vultos? Não responde. Eu sei que viu."]},
    {"texto": "Cumprir o pedido semanal da Maíra", "tipo": "contrato", "alvo": "Ilha de São Pedro", "quantos": 1, "premio": 450,
            "dica": "Veja o pedido no cais de São Pedro. As ciobas vivem nos recifes de lá.",
            "dado_por": "rosa",
            "oferta": ["Toda semana o Bento me trazia cinco ciobas pra feira. Faz três anos que ninguém traz.",
                    "Pesca nos recifes daqui e vende aqui mesmo. O pedido paga bônus."],
            "fim": ["Cioba bonita, igual às que ele trazia. Pode contar com um pedido toda semana."]},
    {"texto": "Descobrir o Recife da Agulha", "tipo": "explorar", "alvo": "Recife da Agulha", "quantos": 1, "premio": 150,
            "dica": "Fica ao lado do Ilhéu da Agulha, a leste de São Pedro. Há pedras escondidas na água: devagar!",
            "dado_por": "rosa",
            "oferta": ["Última página do caderno de rotas: Recife da Agulha, a leste daqui. Ele escreveu \"peixe grande, mar ruim\".",
                    "Tem pedra escondida na água. Vai devagar."],
            "fim": ["Voltou. O dono desse caderno não voltou de um lugar parecido."]},
    {"texto": "Juntar R$ 6000", "tipo": "dinheiro", "alvo": "", "quantos": 6000, "premio": 500,
            "dica": "Ciobas, olhos-de-boi e peixes-lua pagam muito bem em São Pedro.",
            "dado_por": "rosa",
            "oferta": ["Seis mil. É o preço de um motor que aguenta tempestade. Se você vai pra onde eu acho que vai, vai precisar."],
            "fim": ["Dinheiro guardado. Agora sobe no farol. O Abílio tem uma coisa pra te dizer."]},
    # --- terceira parte: o Bento (v0.7.0; a noite final fica em scripts/historia.gd)
    {"texto": "Perguntar ao Seu Jacinto pelo Bento", "tipo": "atracar", "precisa_oferta": true, "alvo": "Vila do Porto", "quantos": 1, "premio": 100,
            "dica": "Volte ao cais da Vila do Porto e fale com o Seu Jacinto.",
            "dado_por": "abilio",
            "oferta": ["Você tá usando o barco do Bento, pescando os pontos do Bento, levando a entrega do Bento. E ninguém te contou nada.",
                    "Vai perguntar pro Jacinto o que aconteceu. Pergunta olhando no olho."],
            "fim_por": "jacinto",
            "fim": ["O Abílio te mandou, né? ... Tá bem.",
                    "Eu tava com o Bento naquela noite. Ele no Estrela d'Alva, eu no meu barco, lado a lado na bruma.",
                    "A gente ouviu um sino. No meio do mar, onde não tem igreja, não tem boia, não tem nada.",
                    "O Bento virou a proa pro som. Eu virei pro porto. Faz três anos que eu viro pro porto toda noite."]},
    {"texto": "Achar as páginas do diário do Bento", "tipo": "pagina", "precisa_oferta": true, "alvo": "", "quantos": 5, "premio": 300,
            "dica": "Em noite de bruma, em mar aberto, chegue perto dos vultos.",
            "dado_por": "jacinto",
            "oferta": ["O Bento escrevia tudo num caderno.",
                    "Depois daquela noite, tem pescador que jura ter visto páginas boiando no meio dos vultos, nas noites de bruma. Eu nunca tive coragem de ir ver.",
                    "Junta as cinco e leva pra Luana. Ela tem mais direito do que eu."],
            "fim_por": "zefa",
            "fim": ["Essa letra é dele.",
                    "Ele escreveu meu nome aqui. \"Luana, não me espera acordada.\" Ele sempre escrevia isso quando ia pescar de noite.",
                    "Três anos eu esperei acordada."]},
    {"texto": "Seguir o sino na bruma", "tipo": "sino", "precisa_oferta": true, "alvo": "", "quantos": 1, "premio": 0,
            "dica": "Numa noite de bruma, navegue a oeste de São Pedro e siga o som do sino.",
            "dado_por": "zefa",
            "oferta": ["O Abílio diz que o sino toca a oeste de São Pedro, nas noites de bruma. Vai.",
                    "Se ele estiver lá, diz que eu não tô mais com raiva. Diz isso primeiro."],
            "fim_por": "abilio",
            "fim": ["A lanterna dele. Eu sabia que um dia alguém trazia de volta.",
                    "O sino parou. O Bento está descansando."]},
]

var indice: int = 0
var progresso: int = 0
var oferecidas: Dictionary = {}          # índice da missão -> true: o NPC já apresentou a missão
var fim_pendentes: Array = []            # missões cumpridas cuja fala final ainda não foi dita
var _volta_papo: Dictionary = {}         # NPC -> próxima fala da conversa fiada

## v0.7.0: as missões da Ilha de São Pedro (a "segunda parte") terminam em "Juntar R$ 6000".
func sao_pedro_concluido() -> bool:
    for i in LISTA.size():
        if String(LISTA[i].texto) == "Juntar R$ 6000":
            return indice > i
    return false

## v0.9.1: em que ponto da história estamos, para a conversa fiada dos moradores (scripts/npcs.gd PAPO).
## f1 = até chegar a São Pedro; f2 = São Pedro aberto; f3 = depois que o Jacinto conta do Bento; luz = depois do final da luz.
func fase() -> String:
    var h: Node = get_node_or_null("../Historia")
    if (h != null and str(h.final) == "luz") or terminou():
        return "luz"
    if indice >= 22:
        return "f3"
    if indice >= 10:
        return "f2"
    return "f1"

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
    if (m.tipo == "entregar" or m.get("precisa_oferta", false)) and not oferecidas.has(indice):
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
    if (m.tipo == "entregar" or m.get("precisa_oferta", false)) and not oferecidas.has(indice):
        return T.t("Ele (ela) passa a caixa para você quando você atraca no cais.")
    return T.t(str(m.dica))

## Algo aconteceu no jogo. "quantidade" é o dinheiro na carteira quando o tipo é "dinheiro".
func evento(tipo: String, alvo: String = "", quantidade: int = 1) -> void:
    if terminou():
        return
    var m: Dictionary = LISTA[indice]
    if m.tipo != tipo or (m.alvo != "" and m.alvo != alvo):
        return
    if (tipo == "entregar" or m.get("precisa_oferta", false)) and not oferecidas.has(indice):
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
    var h: Node = get_node_or_null("../Historia")
    var conversa: Array = Npcs.papo(id, fase(), h != null and bool(h.legado))
    var n: int = int(_volta_papo.get(id, 0))
    _volta_papo[id] = n + 1
    return {"falas": _falas(id, [conversa[n % conversa.size()]]), "carga": carga}
