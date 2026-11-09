extends "res://testes/caso_teste.gd"
const C = preload("res://logica/catalogo.gd")

func test_nova_especie_e_recorde():
	var c = C.new()
	igual(c.registrar({"especie": "atum", "tam": 100.0, "classe": "M"}), {"nova": true, "recorde": true}, "primeira")
	igual(c.registrar({"especie": "atum", "tam": 90.0, "classe": "M"}), {"nova": false, "recorde": false}, "menor")
	igual(c.registrar({"especie": "atum", "tam": 180.0, "classe": "G"}), {"nova": false, "recorde": true}, "maior")
	igual(c.entradas.atum.qtd, 3, "contagem"); perto(c.entradas.atum.recorde_cm, 180.0, 1e-6, "recorde")
	igual(c.conhecidas(), 1, "uma espécie")

func test_titulo_e_ida_e_volta():
	var c = C.new(); c.registrar({"especie": "mero", "tam": 200.0, "classe": "G"}); c.dar_titulo("mero")
	var c2 = C.new(); c2.carregar_dict(c.para_dict())
	afirmar(c2.entradas.mero.titulo, "título salvo"); igual(c2.entradas.mero.qtd, 1, "qtd salva")
