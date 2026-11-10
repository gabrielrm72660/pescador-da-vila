extends CanvasLayer
## Painel de navegação (spec 10, 7.4): marcha, vela, combustível, zona, relógio, bússola, farol e avisos.
## Só mostra o que recebe em atualizar(); quem calcula é o Mundo (dados_hud()).

const TEXTO_MARCHA := ["R", "0", "¼", "½", "MÁX"]
const DURACAO_AVISO := 2.5
const MARGEM := 60.0
const RAIO_TELA := 900.0     ## px do mundo: além disso o farol está fora da tela (zoom 0,75 em 1920×1080)

const NOME_VARA := {"rasa": "Rasa", "profunda": "Profunda", "abissal": "Abissal"}
const CARENCIA_CLIQUE := 200      ## ms: o clique que fecha um painel não vale como "pescar"

signal soltar_do_porao(indice: int)
signal painel_fechado(nome: String)
signal mercado_mudou

var _aviso_id := 0
var _fechou_em := -100000
var _ligado := false
var _aviso_tempo := 0.0


func atualizar(d: Dictionary) -> void:
	$Painel/Marcha.text = "Motor: %s" % TEXTO_MARCHA[clampi(int(d.marcha), 0, TEXTO_MARCHA.size() - 1)]
	$Painel/Vela.text = "Vela aberta" if d.vela else "Vela fechada"
	$Painel/Combustivel.max_value = float(d.tanque)
	$Painel/Combustivel.value = float(d.combustivel)
	$Painel/Combustivel/Texto.text = "%d / %d" % [roundi(d.combustivel), roundi(d.tanque)]
	$Painel/Zona.text = String(d.zona_nome)
	$Painel/Relogio.text = "Dia %d — %s" % [int(d.dia), d.hora]
	$Painel/Seguro.visible = bool(d.get("zona_segura", false))
	$Bussola/Destino.text = "%s — %d mi" % [d.destino_nome, roundi(d.milhas)]
	$Bussola/Seta.rotation = float(d.rumo_destino)
	var mostrar_farol := bool(d.farol_visivel) and float(d.get("dist_farol", 0.0)) > RAIO_TELA
	$IndicadorFarol.visible = mostrar_farol
	if mostrar_farol:
		var tela := _tamanho_tela()
		var dir := Vector2.from_angle(float(d.rumo_farol))
		var meio := tela / 2.0 - Vector2(MARGEM, MARGEM)
		var esc := minf(meio.x / maxf(absf(dir.x), 1e-6), meio.y / maxf(absf(dir.y), 1e-6))
		$IndicadorFarol.position = tela / 2.0 + dir * esc
		$IndicadorFarol.rotation = dir.angle()
	if d.has("vara"):
		$Painel/Vara.text = "Vara: %s" % NOME_VARA.get(d.vara, d.vara)
		$Painel/Porao.max_value = float(d.porao_cap)
		$Painel/Porao.value = float(d.porao_usado)
		$Painel/Porao/Texto.text = "Porão %d/%d L" % [roundi(d.porao_usado), roundi(d.porao_cap)]
	$Painel/Dinheiro.visible = d.has("dinheiro")
	if d.has("dinheiro"):
		var n := int(d.get("missoes", 0))
		$Painel/Dinheiro.text = "R$ %d" % int(d.dinheiro) + ("" if n == 0 else "  ·  %d %s" % [n, "missão" if n == 1 else "missões"])
	var med: Dictionary = d.get("medidor", {})
	$Medidor.definir(med)
	var no_cais: bool = bool(d.get("atracado", false)) and d.has("dinheiro") and not $TelaMercado.visible
	$Dica.visible = not med.is_empty() or bool(d.get("pode_pescar", false)) or no_cais
	$Dica.text = "F: parar o ponteiro na faixa verde" if not med.is_empty() else (
			"M: mercado   ·   E: zarpar" if no_cais else "F: pescar")
	if int(d.get("aviso_id", 0)) != _aviso_id:
		_aviso_id = int(d.aviso_id)
		$Aviso.text = String(d.aviso)
		$Aviso.visible = $Aviso.text != ""
		_aviso_tempo = DURACAO_AVISO


func _process(dt: float) -> void:
	if _aviso_tempo > 0.0:
		_aviso_tempo -= dt
		if _aviso_tempo <= 0.0:
			$Aviso.visible = false


func _tamanho_tela() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920, 1080)


# ------------------------------------------------------------------ painéis (porão e catálogo)

func _ligar() -> void:
	if _ligado:
		return
	_ligado = true
	$PainelPorao.soltar.connect(func(i): soltar_do_porao.emit(i))
	$PainelPorao.fechar.connect(fechar_paineis)
	$PainelCatalogo.fechar.connect(fechar_paineis)
	$PainelMissoes.fechar.connect(fechar_paineis)
	$TelaMercado.fechar.connect(fechar_paineis)
	$TelaMercado.mudou.connect(func(): mercado_mudou.emit())


func painel_aberto() -> bool:
	return $PainelPorao.visible or $PainelCatalogo.visible or $PainelMissoes.visible or $TelaMercado.visible or Time.get_ticks_msec() - _fechou_em < CARENCIA_CLIQUE


func porao_aberto() -> bool:
	return $PainelPorao.visible


func catalogo_aberto() -> bool:
	return $PainelCatalogo.visible


func mercado_aberto() -> bool:
	return $TelaMercado.visible


func missoes_abertas() -> bool:
	return $PainelMissoes.visible


func _so(painel: Control) -> void:
	_ligar()
	for p in [$PainelPorao, $PainelCatalogo, $PainelMissoes, $TelaMercado]:
		if p != painel:
			p.visible = false


func abrir_mercado(estado, dados: Dictionary, especies: Array, rng: RandomNumberGenerator) -> void:
	_so($TelaMercado)
	$TelaMercado.abrir(estado, dados, especies, rng)


func abrir_missoes(estado, dados: Dictionary, especies: Array, pos: Vector2) -> void:
	_so($PainelMissoes)
	$PainelMissoes.mostrar(estado, dados, especies, pos)
	$PainelMissoes.visible = true


func abrir_porao(itens: Array, especies: Array, usado: float, capacidade: float, pendente: Dictionary) -> void:
	_so($PainelPorao)
	$PainelPorao.mostrar(itens, especies, usado, capacidade, pendente)
	$PainelPorao.visible = true


func abrir_catalogo(especies: Array, entradas: Dictionary) -> void:
	_so($PainelCatalogo)
	$PainelCatalogo.mostrar(especies, entradas)
	$PainelCatalogo.visible = true


func fechar_paineis() -> void:
	var qual := ""
	for par in [["porao", $PainelPorao], ["catalogo", $PainelCatalogo], ["missoes", $PainelMissoes], ["mercado", $TelaMercado]]:
		if par[1].visible:
			qual = par[0]
		par[1].visible = false
	if qual != "":
		_fechou_em = Time.get_ticks_msec()
		painel_fechado.emit(qual)
