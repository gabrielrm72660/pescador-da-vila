extends SceneTree
var jogo
var q := 0
var sinais := []
const S = preload("res://scripts/salvamento.gd")
func _initialize() -> void:
	S.apagar()
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func foto(n) -> void:
	root.get_texture().get_image().save_png("res://_%s.png" % n)
func _process(_d: float) -> bool:
	q += 1
	var b: Vector3 = jogo.barco.global_position
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 12.0; jogo.clima.atualizar()
		jogo.fauna_costeira.set_process(false)
		jogo.pesca.acertou.connect(func(p): sinais.append("acertou_%s" % p))
		jogo.pesca.errou.connect(func(): sinais.append("errou"))
		jogo.pesca.tensao_alta.connect(func(): sinais.append("tensao_alta"))
		jogo.pesca.linha_rompida.connect(func(): sinais.append("rompida"))
		jogo.porao.itens.clear()
		jogo.barco.velocidade = 0.0
		jogo.cardumes.criar(b + Vector3(3, 0, -5), "Robalo")
	if q == 5: jogo.pesca.acao()
	if q == 7:
		print("estado: ", jogo.pesca.estado, " alvo ", jogo.pesca.alvo.get("especie", "-"))
		jogo.pesca.angulo = float(jogo.pesca.faixas[0].centro)
		jogo.pesca.acao()          # acerto perfeito
	if q == 9: foto("e_pop_perfeito")
	if q == 14:
		jogo.pesca.trava = 0.0
		jogo.pesca.angulo = fposmod(float(jogo.pesca.faixas[0].centro) + 3.0, TAU)
		jogo.pesca.acao()          # erro
	if q == 16: foto("e_pop_erro")
	if q == 20:
		jogo.pesca.trava = 0.0
		jogo.pesca.tensao = 0.85 * jogo.pesca.limite_linha
	if q == 22: foto("e_tensao")
	if q == 24:
		jogo.pesca.tensao = 2.0
	if q == 27:
		print("sinais: ", sinais, " estado: ", jogo.pesca.estado)
		S.apagar()
		return true
	return false
