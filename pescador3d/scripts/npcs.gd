extends RefCounted
## v0.6.0: os NPCs dos cais (retrato + nome + conversa fiada). As falas de missão ficam em scripts/missoes.gd.
## Todo texto está em português: é a chave de tradução de scripts/idioma.gd (T.t).

const DADOS := {
	"jacinto": {"nome": "Seu Jacinto", "papel": "Pescador aposentado", "ilha": "Vila do Porto",
			"retrato": "res://assets/retratos/jacinto.png", "cor": Color(0.74, 0.58, 0.30)},
	"zefa": {"nome": "Dona Zefa", "papel": "Peixeira", "ilha": "Vila do Porto",
			"retrato": "res://assets/retratos/zefa.png", "cor": Color(0.92, 0.50, 0.24)},
	"toinho": {"nome": "Toinho", "papel": "Zelador das Rocas", "ilha": "Ilha das Rocas",
			"retrato": "res://assets/retratos/toinho.png", "cor": Color(0.94, 0.74, 0.20)},
	"rosa": {"nome": "Dona Rosa", "papel": "Mercadora", "ilha": "Ilha de São Pedro",
			"retrato": "res://assets/retratos/rosa.png", "cor": Color(0.88, 0.42, 0.50)},
	"abilio": {"nome": "Seu Abílio", "papel": "Faroleiro", "ilha": "Ilha de São Pedro",
			"retrato": "res://assets/retratos/abilio.png", "cor": Color(0.96, 0.78, 0.38)},
}

## Conversa fiada: uma fala por vez, em ordem, quando o jogador puxa papo e não há missão para tratar.
const PAPO := {
	"jacinto": [
		"O mar é como gente: quem tem pressa se perde.",
		"Eu já pescava aqui antes de você nascer. Sabe o que aprendi? Escute o vento.",
		"Cavala gosta de manhã. Atum gosta de longe. Peixe de pedra gosta de noite.",
	],
	"zefa": [
		"Peixe grande vale mais, mas peixe fresco vale ainda mais. Venda logo!",
		"A cotação muda ao longo do dia. Olhe o preço antes de vender.",
		"Tenho um sobrinho que sonha em ser pescador. Eu digo: primeiro aprenda a ficar quieto.",
	],
	"toinho": [
		"Aqui nas Rocas somos só eu, o vento e as fragatas. Mas o posto paga bem.",
		"De madrugada o mar fica liso feito vidro. Aí eu sei que o dia vai ser comprido.",
		"Cuidado com as boias de sinalização. Se o barco bate, o casco sente.",
	],
	"rosa": [
		"Em São Pedro o peixe de recife vale muito mais. Ciobas, então, nem se fala!",
		"A feira daqui recebe barco de todo canto. Todo mundo quer peixe fresco.",
		"O Seu Abílio fala pouco, mas o que ele fala vale ouro. Passe no farol.",
	],
	"abilio": [
		"Há quarenta anos eu acendo essa luz. Nunca deixei apagar.",
		"Quando a bruma desce, o facho é a única coisa que não mente.",
		"O mar guarda silêncio demais em certas noites. Fique de olho no horizonte.",
	],
}

static func da_ilha(nome_ilha: String) -> Array:
	var ids: Array = []
	for id in DADOS:
		if DADOS[id].ilha == nome_ilha:
			ids.append(id)
	return ids

static func retrato(id: String) -> Texture2D:
	var caminho: String = DADOS[id].retrato
	return load(caminho) if ResourceLoader.exists(caminho) else null
