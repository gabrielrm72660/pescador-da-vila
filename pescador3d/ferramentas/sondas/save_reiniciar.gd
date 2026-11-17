extends SceneTree
# Duas execuções: FASE=1 salva; FASE=2 (outro processo do Godot) carrega e confere.
var jogo
var q := 0
var fase := "1"
const S = preload("res://scripts/salvamento.gd")
func _initialize() -> void:
	fase = OS.get_environment("FASE")
	if fase == "1":
		S.apagar()
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func estado() -> Dictionary:
	var itens := []
	for i in jogo.porao.itens:
		itens.append("%s %.1f %s @%d,%d r%d" % [i.especie, i.peso, i.qualidade, i.x, i.y, i.rot])
	return {"dinheiro": jogo.dinheiro, "hora": snappedf(jogo.clima.hora, 0.1), "missao": jogo.missoes.indice, "prog": jogo.missoes.progresso,
		"contrato": jogo.economia.indice, "linha": jogo.pesca.linha_nivel, "explorados": jogo.explorados.keys(),
		"x": snappedf(jogo.barco.global_position.x, 0.1), "z": snappedf(jogo.barco.global_position.z, 0.1),
		"melhorias": jogo.melhorias.nivel, "porao": itens}
func _process(_d: float) -> bool:
	q += 1
	if q == 3:
		print("FASE ", fase, " existe save: ", S.existe())
		if fase == "1":
			jogo.iniciar_ou_retomar()
			jogo.dinheiro = 2345
			jogo.clima.hora = 22.5
			jogo.missoes.indice = 12
			jogo.missoes.progresso = 0
			jogo.economia.indice = 7
			jogo.pesca.linha_nivel = 2
			jogo.explorados = {"Banco das Cavalas": true}
			jogo.melhorias.nivel["motor"] = 1
			jogo.porao.itens.clear()
			jogo.porao.guardar("Agulhão-vela", 33.4, "Excepcional")
			jogo.porao.guardar("Moreia", 3.2, "Boa")
			jogo.porao.guardar("Baiacu", 0.8)
			jogo.salvar()
			print("SALVO ", estado())
		else:
			jogo.iniciar_ou_retomar()
			print("CARREGADO ", estado())
			print("missao atual: ", jogo.missoes.texto())
	if q == 6:
		if fase == "2":
			S.apagar()
		return true
	return false
