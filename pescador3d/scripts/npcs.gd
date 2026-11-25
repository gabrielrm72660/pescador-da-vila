extends RefCounted
## v0.6.0: os NPCs dos cais (retrato + nome + conversa fiada). As falas de missão ficam em scripts/missoes.gd.
## Todo texto está em português: é a chave de tradução de scripts/idioma.gd (T.t).

const DADOS := {
	"jacinto": {"nome": "Seu Jacinto", "papel": "Pescador aposentado", "ilha": "Vila do Porto",
			"retrato": "res://assets/retratos/jacinto.png", "cor": Color(0.74, 0.58, 0.30)},
	# v0.9.1: o id "zefa" ficou (missões e saves usam), mas ela agora é a Luana, moça nova, mulher do Bento
	"zefa": {"nome": "Luana", "papel": "Peixeira", "ilha": "Vila do Porto",
			"retrato": "res://assets/retratos/luana.png", "cor": Color(0.92, 0.50, 0.24)},
	"toinho": {"nome": "Toinho", "papel": "Zelador das Rocas", "ilha": "Ilha das Rocas",
			"retrato": "res://assets/retratos/toinho.png", "cor": Color(0.94, 0.74, 0.20)},
	# v0.9.1: o id "rosa" ficou; ela agora é a Maíra, moça nova, dona da loja de São Pedro
	"rosa": {"nome": "Maíra", "papel": "Mercadora", "ilha": "Ilha de São Pedro",
			"retrato": "res://assets/retratos/maira.png", "cor": Color(0.88, 0.42, 0.50)},
	"abilio": {"nome": "Seu Abílio", "papel": "Faroleiro", "ilha": "Ilha de São Pedro",
			"retrato": "res://assets/retratos/abilio.png", "cor": Color(0.96, 0.78, 0.38)},
	# v0.7.0: quem não mora em cais nenhum (ilha vazia: nunca aparecem no painel do cais)
	"bento": {"nome": "Bento", "papel": "O pescador que a bruma levou", "ilha": "",
			"retrato": "res://assets/retratos/bento.png", "cor": Color(0.70, 0.78, 0.86)},
	"diario": {"nome": "Diário do Bento", "papel": "Uma página molhada", "ilha": "",
			"retrato": "res://assets/retratos/diario.png", "cor": Color(0.86, 0.80, 0.62)},
	# v0.8.7: só aparece de noite, no cais da Vila do Porto (scripts/jogo.gd _npcs_aqui)
	"comprador": {"nome": "Homem da capa", "papel": "Compra o que a noite devolve", "ilha": "",
			"retrato": "res://assets/retratos/comprador.png", "cor": Color(0.45, 0.85, 0.72)},
}

## Conversa fiada: uma fala por vez, em ordem, quando o jogador puxa papo e não há missão para tratar.
## v0.9.1: cada morador guarda um pedaço do sumiço do Bento, e a conversa muda com a história (missoes.gd fase()):
##   f1 = missões 1 a 10 (ninguém diz o nome dele), f2 = 11 a 22 (o nome escapa), f3 = depois que o Jacinto conta,
##   luz = depois do final da luz. "bruma" = o que se diz num jogo novo depois do final da bruma (historia.gd legado),
##   misturado às falas de f1 e f2. Roteiro completo: doc "Bruma — falas dos personagens".
const PAPO := {
	"jacinto": {
		"f1": ["Esse barco tem manha: puxa pra esquerda quando o mar cresce. Segura firme o leme.",
				"Quando a bruma desce, volta pro porto. Não tem peixe que valha.",
				"Eu pesquei quarenta anos. Agora só olho o mar daqui do cais."],
		"f2": ["Foi até São Pedro? Eu não passo das Rocas faz tempo.",
				"A Maíra ainda pergunta de mim? Diz que eu tô bem.",
				"Ouviu algum sino lá fora? Não? Melhor assim."],
		"f3": ["Eu devia ter ido atrás dele. Todo dia eu acordo sabendo disso.",
				"O Estrela d'Alva voltou sozinho, sabia? Acharam ele à deriva, vazio, com a lanterna apagada.",
				"Se for seguir o som, vai de lanterna acesa e tanque cheio. E volta."],
		"luz": ["O farol tá aceso e eu dormi a noite inteira. Primeira vez em três anos.",
				"Fica com o barco. Agora ele é seu de verdade."],
		"bruma": ["Agora são dois barcos que a gente escuta na bruma. Eu deixo a lanterna do cais acesa pros dois."],
	},
	"zefa": {
		"f1": ["Peixe bom tem olho brilhante e guelra vermelha. O resto eu não compro.",
				"Esse barco... deixa. Cuida bem dele.",
				"O Jacinto fala pouco, mas não mente. Escuta o que ele diz da bruma."],
		"f2": ["Foi pra São Pedro? Manda lembrança pra Maíra. A gente não se fala desde a missa sem caixão.",
				"Na banca todo mundo pergunta de você. Pescador novo é novidade aqui.",
				"O Zeca se afogou perto das Rocas. Não pesca lá de noite."],
		"f3": ["Agora você sabe. Eu sou a mulher do Bento. Ainda sou, eu acho.",
				"Ele dizia que o mar devolve tudo. Devolveu o barco. Eu queria o resto.",
				"Se ouvir a voz do Zeca lá fora, não responde. Não era ele da outra vez, e não vai ser agora."],
		"luz": ["O Abílio me disse que você levou a lanterna. Acendi uma vela na igreja. Ficou bonito, as duas luzes.",
				"Agora eu durmo."],
		"bruma": ["Dizem que agora são dois barcos na bruma. Eu deixo o café pronto pros dois, mesmo sabendo."],
	},
	"toinho": {
		"f1": ["Aqui sou eu, as tartarugas e as aves. As aves não conversam. As tartarugas também não.",
				"O rádio da estação pega tudo: barco de pesca, navio, às vezes umas coisas que não são nada.",
				"Da última vez que esse barco atracou aqui, eu ainda era estagiário."],
		"f2": ["Quando a bruma cobre o atol eu desligo o rádio. Não quero ouvir de novo.",
				"Me conta como é São Pedro. Eu só conheço pela voz do rádio.",
				"Uma vez um pescador me chamou numa noite de bruma. Eu respondi. Ele não respondeu mais."],
		"f3": ["Era o Bento, aquela chamada. Ele dizia a posição, a oeste de São Pedro.",
				"E tinha um sino. Ali no fundo, tocando devagar. A Marinha disse que era interferência. Eu sei o que ouvi.",
				"Se você for lá, chama no rádio. Eu fico na escuta. Dessa vez eu não desligo."],
		"luz": ["A bruma levantou do atol. Liguei o rádio e só tem estática. Estática boa.",
				"Agora eu conto essa história pra cada barco que passa."],
		"bruma": ["Nas noites de bruma o rádio chia e eu ouço duas vozes. Eu respondo. Fico conversando."],
	},
	"rosa": {
		# f1: só se o jogador chegar a São Pedro antes da hora
		"f1": ["Isca fresca, gelo, querosene. O resto é sorte.",
				"Em São Pedro o peixe de recife vale muito mais. Ciobas, então, nem se fala!",
				"O Seu Abílio fala pouco, mas o que ele fala vale ouro. Passe no farol."],
		"f2": ["Isca fresca, gelo, querosene. O resto é sorte.",
				"O caderno? Era do Bento. Ele deixou aqui no último dia, junto com o fiado.",
				"Fui eu que vendi o combustível da última viagem dele. Se eu tivesse fechado mais cedo naquele dia..."],
		"f3": ["Então o Jacinto finalmente falou. Ele carrega isso sozinho faz tempo.",
				"Leva o que precisar, por minha conta. Não quero vender a última viagem de mais ninguém.",
				"Se encontrar ele, diz que o fiado tá perdoado. Ele ia rir disso."],
		"luz": ["O Abílio desceu do farol pra tomar café comigo. Em três anos, nunca tinha descido.",
				"Guardei o caderno do Bento. Já te ensinou o que tinha pra ensinar."],
		"bruma": ["Continuo mandando querosene pro farol. Agora pra duas lanternas."],
	},
	"abilio": {
		"f1": ["O farol fica aceso a noite toda. Sempre. Não me pergunta por quê.",
				"Quando a bruma desce, o facho é a única coisa que não mente.",
				"O mar guarda silêncio demais em certas noites. Fique de olho no horizonte."],
		"f2": ["O farol fica aceso a noite toda. Sempre. Não me pergunta por quê.",
				"Daqui de cima eu vejo a bruma chegando antes de todo mundo. Ela vem do oeste. Sempre do oeste.",
				"Pescador novo, barco velho. Conheço esse barco. Conheço bem."],
		"f3": ["Nas noites de bruma eu ouço um sino a oeste. Toda noite de bruma, há três anos.",
				"Deixo o farol aceso pra ele achar o caminho. Se ele não quiser voltar, pelo menos sabe onde é aqui.",
				"Leva a lanterna acesa. Dentro da bruma, ela é a única coisa que é sua."],
		"luz": ["A lanterna dele tá lá em cima, junto da lâmpada. Agora o farol tem duas luzes.",
				"Pode vir tomar café quando quiser. Eu não falo muito, mas faço café bom."],
		"bruma": ["O sino não parou. Agora toca mais perto. Eu continuo acendendo o farol, pros dois."],
	},
	# o comprador da noite não tem fases (v0.8.7)
	"comprador": {
		"f1": ["Boa noite. Trouxe alguma coisa que a bruma devolveu? Esses ninguém mais quer. Eu quero.",
				"Pago bem pelos de olhos a mais. Não pergunte para quê.",
				"Seu Bento também vendia para mim. Até a noite em que não voltou.",
				"Acenda uma vela antes de sair. Não por mim. Por você."],
	},
}

## As falas soltas de um NPC numa fase (cai para f1 se faltar). Com o legado da bruma, as de "bruma" entram no meio.
static func papo(id: String, fase: String, legado: bool) -> Array:
	var tudo: Dictionary = PAPO[id]
	var linhas: Array = (tudo.get(fase, tudo["f1"]) as Array).duplicate()
	if legado and (fase == "f1" or fase == "f2") and tudo.has("bruma"):
		linhas.append_array(tudo["bruma"])
	return linhas

static func da_ilha(nome_ilha: String) -> Array:
	var ids: Array = []
	for id in DADOS:
		if DADOS[id].ilha == nome_ilha:
			ids.append(id)
	return ids

static func retrato(id: String) -> Texture2D:
	var caminho: String = DADOS[id].retrato
	return load(caminho) if ResourceLoader.exists(caminho) else null
