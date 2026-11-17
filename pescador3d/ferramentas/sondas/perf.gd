extends SceneTree
# Mede custo de render por qualidade: triângulos, draw calls e ms por quadro (CPU/llvmpipe = proxy de PC fraco)
var jogo
var q := 0
var qual := [2, 1, 0]
var fase := 0
var t0 := 0
var n := 0
func _initialize() -> void:
	jogo = load("res://cenas/Jogo.tscn").instantiate()
	root.add_child(jogo)
func info(rot: String, ms: float) -> void:
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var ob := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	print("PERF %s draws=%d tris=%d objs=%d nos=%d ms/quadro=%.0f" % [rot, dc, pr, ob, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), ms])
func _process(_d: float) -> bool:
	q += 1
	if q == 3:
		jogo.iniciar_ou_retomar()
		jogo.clima.hora = 15.5; jogo.clima.atualizar()
		jogo.interface.esconder_hud = true
	if q < 6:
		return false
	if fase < qual.size():
		if n == 0:
			jogo.graficos.qualidade = qual[fase]
			jogo.graficos.aplicar()
			n = 1
			return false
		if n < 5:
			n += 1
			if n == 5:
				t0 = Time.get_ticks_usec()
			return false
		if n < 13:
			n += 1
			return false
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / 8.0
		info("qualidade=%d" % qual[fase], ms)
		fase += 1
		n = 0
		return false
	return true
