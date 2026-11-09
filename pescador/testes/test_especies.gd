extends "res://testes/caso_teste.gd"
const E = preload("res://logica/especies.gd")

func _rng(s := 7) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_dezoito_especies_seis_por_zona():
	var l = E.carregar()
	igual(l.size(), 18, "total")
	for z in 3:
		igual(l.filter(func(e): return e.zona == z).size(), 6, "zona %d" % z)

func test_faixas_do_design():
	var l = E.carregar()
	igual([E.por_id(l, "sardinha").tam_min, E.por_id(l, "sardinha").tam_max], [12.0, 25.0], "sardinha")
	igual([E.por_id(l, "mero").tam_min, E.por_id(l, "mero").tam_max], [80.0, 250.0], "mero")

func test_exemplar_dentro_da_faixa_e_classes():
	var esp = E.por_id(E.carregar(), "atum"); var r = _rng()
	for i in 2000:
		var ex = E.sortear_exemplar(esp, r)
		afirmar(ex.tam >= esp.tam_min and ex.tam <= esp.tam_max, "faixa")
		var c = "P" if ex.f < 0.35 else ("M" if ex.f < 0.70 else ("G" if ex.f < 0.95 else "Recorde"))
		igual(ex.classe, c, "classe")

func test_favorece_pequenos():
	var esp = E.por_id(E.carregar(), "tainha"); var r = _rng(); var p := 0; var rec := 0
	for i in 5000:
		var c = E.sortear_exemplar(esp, r).classe
		if c == "P": p += 1
		if c == "Recorde": rec += 1
	afirmar(p > 2500, "maioria P (%d)" % p)        # u^2.2 < 0.35 ⇔ u < 0.62
	afirmar(rec < 200, "Recorde raro (%d)" % rec)  # u > 0.977 → ~2,3%

func test_volume_e_valor_crescem_mais_que_o_tamanho():
	var esp = E.por_id(E.carregar(), "robalo")
	var a = E.exemplar_com_f(esp, 0.2); var b = E.exemplar_com_f(esp, 0.8)
	var razao_tam = b.tam / a.tam
	afirmar(b.volume / a.volume > razao_tam, "volume")
	afirmar(float(b.valor) / a.valor > razao_tam, "valor")

func test_formulas_no_tamanho_medio():
	var esp = E.por_id(E.carregar(), "atum")
	var ex = E.exemplar_com_f(esp, 0.5)              # f = 0,5 dá o tamanho médio
	perto(ex.tam, 155.0, 0.01, "tam médio")
	perto(ex.volume, 25.0, 0.01, "volume médio")
	igual(ex.valor, 150, "valor médio comum")        # classe M, sem bônus
	perto(ex.peso, 14.0 * pow(1.55, 3), 0.01, "peso")

func test_recorde_tem_bonus():
	var esp = E.por_id(E.carregar(), "atum")
	var ex = E.exemplar_com_f(esp, 0.96)
	igual(ex.classe, "Recorde", "classe")
	igual(ex.valor, roundi(150 * pow(ex.tam / 155.0, 1.6) * 1.5), "bônus 1,5")

func test_dourada_pega_o_maior_de_dois():
	var esp = E.por_id(E.carregar(), "dourado"); var s1 := 0.0; var s2 := 0.0
	var r1 = _rng(3); var r2 = _rng(3)
	for i in 3000:
		s1 += E.sortear_exemplar(esp, r1).f
		s2 += E.sortear_exemplar(esp, r2, true).f
	afirmar(s2 > s1 * 1.3, "dourada maior em média")

func test_rede_pega_varios_pequenos():
	var esp = E.por_id(E.carregar(), "sardinha"); var r = _rng()
	for i in 200:
		var lote = E.sortear_rede(esp, r)
		afirmar(lote.size() >= 3 and lote.size() <= 6, "3 a 6")
		for ex in lote: afirmar(ex.f <= 0.5, "só pequenos")

func test_horario_e_clima():
	var l = E.carregar(); var r = _rng(); var viu_dev := false
	for i in 4000:
		var e = E.sortear_especie(l, 2, false, "qualquer", r)
		afirmar(e.id != "devorador_palido", "devorador não aparece de dia")
		igual(e.zona, 2, "zona")
	for i in 20000:
		if E.sortear_especie(l, 2, true, "tempestade", r).id == "devorador_palido": viu_dev = true
	afirmar(viu_dev, "devorador aparece de noite na tempestade")

func test_noite_mais_dobra_a_chance():
	var l = E.carregar(); var r = _rng(); var dia := 0; var noite := 0
	for i in 20000:
		if E.sortear_especie(l, 2, false, "qualquer", r).id == "tamboril": dia += 1
		if E.sortear_especie(l, 2, true, "qualquer", r).id == "tamboril": noite += 1
	afirmar(noite > dia, "tamboril mais comum à noite (%d × %d)" % [noite, dia])
