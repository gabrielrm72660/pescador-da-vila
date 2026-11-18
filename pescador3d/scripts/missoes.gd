extends Node
## As missões, uma de cada vez, em ordem. Cada uma pede um tipo de acontecimento (pescar, vender,
## comprar, atracar, juntar dinheiro) e paga um prêmio. scripts/jogo.gd avisa o que aconteceu com evento().

signal cumprida(missao: Dictionary)

## tipo: "pescar" (alvo = espécie, ou "" para qualquer), "vender", "comprar", "atracar" (alvo = nome da ilha),
## "dinheiro" (quantos = quanto ter na carteira)
const LISTA := [
    {"texto": "Pescaria inaugural", "tipo": "pescar", "alvo": "", "quantos": 3, "premio": 20,
            "dica": "Pare perto de um cardume e aperte F."},
    {"texto": "Vender os peixes no cais", "tipo": "vender", "alvo": "", "quantos": 1, "premio": 30,
            "dica": "Siga a âncora do radar e aperte F na ponta do cais."},
    {"texto": "Comprar uma melhoria", "tipo": "comprar", "alvo": "", "quantos": 1, "premio": 40,
            "dica": "No cais da Vila do Porto, teclas 3 a 6."},
    {"texto": "Pescar olho-de-cão à noite", "tipo": "pescar", "alvo": "Olho-de-cão", "quantos": 2, "premio": 80,
            "dica": "Ele só aparece depois que escurece."},
    {"texto": "Atracar na Ilha Rata", "tipo": "atracar", "alvo": "Ilha Rata", "quantos": 1, "premio": 100,
            "dica": "Fica a noroeste da vila. Leve diesel."},
    {"texto": "Pescar um atum em alto-mar", "tipo": "pescar", "alvo": "Atum", "quantos": 1, "premio": 150,
            "dica": "Só longe das ilhas. Precisa de 6 casas livres."},
    {"texto": "Juntar R$ 1000", "tipo": "dinheiro", "alvo": "", "quantos": 1000, "premio": 0,
            "dica": "A Ilha Rata paga mais pelo peixe."},
    {"texto": "Descobrir o Banco das Cavalas", "tipo": "explorar", "alvo": "Banco das Cavalas", "quantos": 1, "premio": 85,
            "dica": "Consulte a carta náutica com M. Navegue até o banco submerso."},
    {"texto": "Entregar uma encomenda", "tipo": "contrato", "alvo": "", "quantos": 1, "premio": 120,
            "dica": "Veja a encomenda atual no cais. Venda a quantidade pedida."},
    {"texto": "Atracar na Ilha das Conchas", "tipo": "atracar", "alvo": "Ilha das Conchas", "quantos": 1, "premio": 130,
            "dica": "Há um pequeno porto a leste da Vila do Porto."},
    {"texto": "Explorar o Canal das Sardinhas", "tipo": "explorar", "alvo": "Canal das Sardinhas", "quantos": 1, "premio": 95,
            "dica": "Marque o destino na carta náutica e navegue até o novo banco."},
    {"texto": "Pescar um agulhão-vela", "tipo": "pescar", "alvo": "Agulhão-vela", "quantos": 1, "premio": 350,
            "dica": "Só de dia e bem longe das ilhas. É rápido e forte; precisa de 6 casas livres."},
    {"texto": "Pescar uma moreia à noite", "tipo": "pescar", "alvo": "Moreia", "quantos": 1, "premio": 160,
            "dica": "Só nos recifes e só depois que escurece. Lula no fundo (B e N) ajuda."},
    {"texto": "Pescar um peixe-anjo no recife", "tipo": "pescar", "alvo": "Peixe-anjo", "quantos": 1, "premio": 220,
            "dica": "É raro e só aparece de dia, nos recifes. Camarão, na meia-água."},
    {"texto": "Entregar 3 encomendas", "tipo": "contrato", "alvo": "", "quantos": 3, "premio": 300,
            "dica": "Veja a encomenda atual no cais e venda a quantidade pedida."},
    {"texto": "Juntar R$ 3000", "tipo": "dinheiro", "alvo": "", "quantos": 3000, "premio": 200,
            "dica": "Peixes raros e encomendas pagam melhor; a Ilha Rata paga mais pelo peixe."},
]

var indice: int = 0
var progresso: int = 0

func terminou() -> bool:
    return indice >= LISTA.size()

func atual() -> Dictionary:
    return {} if terminou() else LISTA[indice]

func titulo() -> String:
    return "Viagem livre" if terminou() else "Missão %d de %d" % [indice + 1, LISTA.size()]

func texto() -> String:
    if terminou():
        return "Pescar, vender e melhorar o barco"
    var m: Dictionary = LISTA[indice]
    if m.tipo == "dinheiro" or int(m.quantos) <= 1:
        return m.texto
    return "%s (%d/%d)" % [m.texto, progresso, m.quantos]

func dica() -> String:
    return "" if terminou() else str(LISTA[indice].dica)

## Algo aconteceu no jogo. "quantidade" é o dinheiro na carteira quando o tipo é "dinheiro".
func evento(tipo: String, alvo: String = "", quantidade: int = 1) -> void:
    if terminou():
        return
    var m: Dictionary = LISTA[indice]
    if m.tipo != tipo or (m.alvo != "" and m.alvo != alvo):
        return
    progresso = quantidade if tipo == "dinheiro" else progresso + quantidade
    if progresso >= int(m.quantos):
        indice += 1
        progresso = 0
        cumprida.emit(m)

func zerar() -> void:
    indice = 0
    progresso = 0
