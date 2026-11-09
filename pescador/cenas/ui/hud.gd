extends CanvasLayer
## Painel de navegação (spec 10, 7.4): marcha, vela, combustível, zona, relógio, bússola, farol e avisos.
## Só mostra o que recebe em atualizar(); quem calcula é o Mundo (dados_hud()).

const TEXTO_MARCHA := ["R", "0", "¼", "½", "MÁX"]
const DURACAO_AVISO := 2.5
const MARGEM := 60.0
const RAIO_TELA := 900.0     ## px do mundo: além disso o farol está fora da tela (zoom 0,75 em 1920×1080)

var _aviso_id := 0
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
