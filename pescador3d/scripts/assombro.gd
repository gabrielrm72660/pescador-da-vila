extends Node
## v0.8.7: o Assombro — o horror da noite tem preço.
## Um medidor de 0 a 1 (a lamparina do HUD vai escurecendo e a chama esverdeia). Sobe à noite em mar aberto, mais
## ainda na bruma, longe de qualquer luz, com vultos por perto e com peixe aberrante no porão. Desce com luz: a lanterna
## do barco, o facho do farol, perto da terra, o amanhecer e o cais.
## O que acontece conforme sobe (começa sutil, fica assustador):
##   0,25  sussurros; mais miragens no radar; vultos também fora da bruma
##   0,45  batidas no casco (perde casco); os vultos cercam o barco; a lanterna falha
##   0,50  o canto da Mãe-d'água (só o som): o leme puxa sozinho por alguns segundos
##   0,65  a coisa de baixo: sombra enorme no radar, o barco levanta numa onda sem vento; o motor engasga; some peixe
##   1,00  desmaio: acorda ao amanhecer, à deriva, longe; perde parte do porão e do diesel
## Proteção: óleo da lanterna, vela na capela (uma noite), patuá (Maíra, São Pedro), sino de bordo [G].
## Peixe aberrante: de noite, com o medo alto, às vezes o que sobe não é peixe direito. Só o homem da capa compra.

signal mudou

const T = preload("res://scripts/idioma.gd")

var jogo: Node
var valor: float = 0.0
var oleo: float = 1.0                     # tanque da lanterna (0..1); só gasta de noite com a luz ligada
var vela: bool = false                    # acendeu vela na capela: vale até o próximo amanhecer
var patua: bool = false                   # patuá da Maíra: o medo sobe 25% mais devagar
var sino: bool = false                    # sino de bronze de bordo: [G] espanta vultos e acalma
var luz_falhando: float = 0.0             # s em que a lanterna fica apagada sozinha
var sombra_radar: float = 0.0             # s em que a coisa de baixo aparece no radar

var _prox := {"sussurro": 20.0, "batida": 30.0, "lanterna": 40.0, "canto": 80.0, "coisa": 60.0, "motor": 45.0, "peixe": 80.0}
var _avisou := {}
var _canto_t: float = 0.0
var _canto_lado: float = 1.0
var _engasgo_t: float = 0.0
var _sino_recarga: float = 0.0
var _desmaio_t: float = -1.0
var _vinheta: ColorRect
var _veu: ColorRect
var _tempo: float = 0.0

func construir(jogo_: Node) -> void:
	jogo = jogo_
	name = "Assombro"
	var camada := CanvasLayer.new()          # vinheta: por cima do mar, por baixo do HUD
	camada.layer = -1
	add_child(camada)
	_vinheta = ColorRect.new()
	_vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float forca = 0.0;
uniform float pulso = 0.0;
void fragment() {
	vec2 d = UV - 0.5;
	float r = length(d * vec2(1.25, 1.0));
	float v = smoothstep(0.32, 0.85, r) * forca * (0.85 + 0.15 * pulso);
	COLOR = vec4(0.01, 0.05, 0.06, v);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_vinheta.material = m
	camada.add_child(_vinheta)
	var cima := CanvasLayer.new()            # véu do desmaio: cobre tudo, até o HUD
	cima.layer = 60
	add_child(cima)
	_veu = ColorRect.new()
	_veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veu.color = Color(0, 0, 0, 0)
	cima.add_child(_veu)
	if jogo.clima.has_signal("amanheceu"):
		jogo.clima.amanheceu.connect(func(): vela = false)

func zerar() -> void:
	valor = 0.0
	oleo = 1.0
	vela = false
	patua = false
	sino = false
	luz_falhando = 0.0
	sombra_radar = 0.0
	_avisou.clear()

func para_salvar() -> Dictionary:
	return {"valor": valor, "oleo": oleo, "vela": vela, "patua": patua, "sino": sino}

func carregar(d: Dictionary) -> void:
	valor = clampf(float(d.get("valor", 0.0)), 0.0, 0.95)
	oleo = clampf(float(d.get("oleo", 1.0)), 0.0, 1.0)
	vela = bool(d.get("vela", false))
	patua = bool(d.get("patua", false))
	sino = bool(d.get("sino", false))

## A lanterna pode acender agora? (tem óleo e não está falhando)
func lanterna_acesa() -> bool:
	return jogo.luz_ligada and oleo > 0.0 and luz_falhando <= 0.0

func preco_oleo() -> int:
	return ceili((1.0 - oleo) * 20.0)

## Chance de o peixe que acabou de subir ser aberrante (noite, medo alto ou bruma, longe da costa).
func chance_aberrante() -> float:
	var n: float = jogo.clima.noite()
	if n < 0.5:
		return 0.0
	var bruma: float = float(jogo.clima.bruma) * float(jogo.clima.bruma_local)
	return clampf(0.04 + 0.45 * smoothstep(0.25, 0.9, valor) + 0.25 * bruma, 0.0, 0.6) * n

func _aviso(chave: String, texto: String, vezes: int = 2) -> void:
	var n: int = int(_avisou.get(chave, 0))
	if n >= vezes:
		return
	_avisou[chave] = n + 1
	jogo.interface.aviso(texto)

# ------------------------------------------------------------------ o relógio do medo

## Chamado por jogo.gd a cada quadro. navegando = o barco está no mar e o jogo correndo.
func atualizar(delta: float, navegando: bool) -> void:
	_tempo += delta
	if _desmaio_t >= 0.0:
		_desmaiar_passo(delta)
		_pintar(delta)
		return
	if jogo.atracado:
		valor = move_toward(valor, 0.0, 0.12 * delta)      # no cais, com gente e luz, o medo passa
		luz_falhando = 0.0
		sombra_radar = 0.0
		_pintar(delta)
		return
	if not navegando:
		_pintar(delta)
		return
	var clima: Node = jogo.clima
	var barco: Node3D = jogo.barco
	var pos: Vector3 = barco.global_position
	var n: float = clima.noite()
	var longe: float = smoothstep(120.0, 420.0, float(jogo.distancia_da_costa(pos)))
	var bruma: float = float(clima.bruma) * float(clima.bruma_local)
	var farol: float = 0.0
	for i in jogo.ilhas:
		farol = maxf(farol, float(i.clareio_do_farol(pos)))
	# óleo: a lanterna gasta de noite
	if jogo.luz_ligada and n > 0.3 and oleo > 0.0:
		oleo = maxf(0.0, oleo - delta / 320.0)
		if oleo <= 0.0:
			jogo.interface.aviso(T.t("A lanterna apagou: acabou o óleo. Compre mais no cais (aba Noite)."))
		elif oleo < 0.2:
			_aviso("oleo_baixo", T.t("O óleo da lanterna está acabando."), 1)
	luz_falhando = maxf(0.0, luz_falhando - delta)
	var acesa: bool = lanterna_acesa()
	# quanto sobe
	var ganho: float = 0.0030 * n * (0.35 + 0.65 * longe) + 0.0045 * bruma
	ganho += 0.0040 * float(_vultos_perto(70.0))
	ganho += 0.0006 * float(_aberrantes_no_porao()) * n
	if acesa:
		ganho *= 0.5
	if patua:
		ganho *= 0.75
	if vela:
		ganho *= 0.6
	if clima.bruma_mansa:
		ganho *= 0.4
	# quanto desce
	var perda: float = 0.02 * (1.0 - n) + 0.02 * farol + 0.006 * (1.0 - longe) * (1.0 if acesa else 0.4)
	var antes: float = valor
	valor = clampf(valor + (ganho - perda) * delta, 0.0, 1.0)
	if absf(valor - antes) > 0.0:
		mudou.emit()
	if jogo.fantasmas != null:
		jogo.fantasmas.assombro = valor
	_sino_recarga = maxf(0.0, _sino_recarga - delta)
	_efeitos(delta, n, acesa)
	if valor >= 0.995:
		_comecar_desmaio()
	_pintar(delta)

func _vultos_perto(raio: float) -> int:
	if jogo.fantasmas == null:
		return 0
	return int(jogo.fantasmas.vultos_perto(jogo.barco.global_position, raio))

func _aberrantes_no_porao() -> int:
	var c := 0
	for item in jogo.porao.itens:
		if String(item.get("qualidade", "")) == "Aberrante":
			c += 1
	return c

func _vez(chave: String, delta: float, faixa: Vector2) -> bool:
	_prox[chave] = float(_prox[chave]) - delta
	if float(_prox[chave]) <= 0.0:
		_prox[chave] = randf_range(faixa.x, faixa.y)
		return true
	return false

func _efeitos(delta: float, n: float, acesa: bool) -> void:
	var barco: Node3D = jogo.barco
	var som: Node = jogo.som
	# sussurros
	if valor >= 0.25 and _vez("sussurro", delta, Vector2(18.0, 36.0) * (1.4 - valor)):
		som.tocar("sussurro", lerpf(-26.0, -12.0, valor), randf_range(0.85, 1.1))
		_aviso("sussurro", T.t("Você ouviu alguém falar baixinho... mas não há ninguém a bordo."), 1)
	# batidas no casco, por baixo
	if valor >= 0.45 and _vez("batida", delta, Vector2(24.0, 48.0) * (1.5 - valor)):
		som.tocar("batida", -6.0, randf_range(0.9, 1.05))
		barco.danificar(randf_range(2.0, 5.0) * valor, "bruma")
		if barco.has_method("sacudir"):
			barco.sacudir(1.0 + valor)
		_aviso("batida", T.t("Algo bateu no casco. Por baixo."))
	# a lanterna falha
	if valor >= 0.45 and jogo.luz_ligada and _vez("lanterna", delta, Vector2(30.0, 60.0)):
		luz_falhando = randf_range(1.5, 3.5) * (0.6 + valor)
		_aviso("lanterna", T.t("A lanterna piscou e apagou sozinha."), 1)
	# o canto da Mãe-d'água
	if _canto_t <= 0.0 and valor >= 0.50 and n > 0.5 and _vez("canto", delta, Vector2(70.0, 130.0)):
		_canto_t = 9.0
		_canto_lado = 1.0 if randf() < 0.5 else -1.0
		som.tocar("canto", -10.0)
		_aviso("canto", T.t("Um canto vem da água... o leme puxa sozinho. Segure firme!"))
	if _canto_t > 0.0:
		_canto_t -= delta
		var env: float = sin(clampf(1.0 - _canto_t / 9.0, 0.0, 1.0) * PI)
		barco.puxao_leme = _canto_lado * 0.75 * env * (0.5 if acesa else 1.0)
	else:
		barco.puxao_leme = 0.0
	# a coisa de baixo
	sombra_radar = maxf(0.0, sombra_radar - delta)
	if valor >= 0.65 and _vez("coisa", delta, Vector2(50.0, 95.0)):
		sombra_radar = 7.0
		som.tocar("grave", -4.0)
		if barco.has_method("sacudir"):
			barco.sacudir(3.2)
		_aviso("coisa", T.t("O barco subiu numa onda sem vento. O radar mostra algo enorme bem embaixo de você."))
	# o motor engasga
	if valor >= 0.65 and _vez("motor", delta, Vector2(35.0, 65.0)):
		_engasgo_t = randf_range(1.8, 3.2)
		_aviso("motor", T.t("O motor engasgou."), 1)
	if _engasgo_t > 0.0:
		_engasgo_t -= delta
		barco.engasgo = 0.25 + 0.2 * sin(_tempo * 23.0)
	else:
		barco.engasgo = 1.0
	# some peixe do porão
	if valor >= 0.70 and _vez("peixe", delta, Vector2(60.0, 110.0)):
		var peixes: Array = jogo.porao.itens.filter(func(i): return not jogo.porao.eh_carga(String(i.especie)))
		if not peixes.is_empty():
			jogo.porao.retirar(peixes[randi() % peixes.size()])
			som.tocar("batida", -14.0, 1.4)
			jogo.interface.aviso(T.t("Um baque no porão. Quando você olhou, faltava um peixe."))

## [G] o sino de bordo: espanta os vultos por perto e acalma um pouco.
func tocar_sino() -> void:
	if not sino:
		jogo.interface.aviso(T.t("Não há sino a bordo. O sino de bronze se compra no cais da Vila do Porto (aba Noite)."))
		return
	if _sino_recarga > 0.0:
		jogo.interface.aviso(T.t("O sino ainda está vibrando. Espere um pouco."))
		return
	_sino_recarga = 90.0
	jogo.som.tocar("sino_bordo", -4.0)
	valor = maxf(0.0, valor - 0.15)
	if jogo.fantasmas != null:
		jogo.fantasmas.espantar(jogo.barco.global_position, 140.0)
	jogo.interface.aviso(T.t("O sino de bronze ecoou longe. As sombras recuaram."))

# ------------------------------------------------------------------ desmaio

func _comecar_desmaio() -> void:
	_desmaio_t = 0.0
	jogo.som.tocar("grave", -2.0, 0.8)

func _desmaiar_passo(delta: float) -> void:
	_desmaio_t += delta
	var barco: Node3D = jogo.barco
	barco.engasgo = 0.0
	barco.puxao_leme = 0.0
	if _desmaio_t < 2.5:
		_veu.color.a = _desmaio_t / 2.5
		return
	if _desmaio_t - delta < 2.5:                         # no escuro: o tempo passa e o mar leva o barco
		_acordar_longe()
	if _desmaio_t < 5.0:
		_veu.color.a = 1.0
		return
	_veu.color.a = clampf(1.0 - (_desmaio_t - 5.0) / 2.5, 0.0, 1.0)
	if _desmaio_t >= 7.5:
		_desmaio_t = -1.0
		barco.engasgo = 1.0
		_veu.color.a = 0.0

func _acordar_longe() -> void:
	var barco: Node3D = jogo.barco
	var p0: Vector3 = barco.global_position
	var destino: Vector3 = p0
	for k in 30:
		var ang: float = randf_range(0.0, TAU)
		var p: Vector3 = p0 + Vector3(cos(ang), 0.0, sin(ang)) * randf_range(250.0, 480.0)
		if float(jogo.distancia_da_costa(p)) > 60.0:
			destino = p
			break
	barco.global_position = Vector3(destino.x, barco.global_position.y, destino.z)
	barco.rotation.y = randf_range(0.0, TAU)
	barco.velocidade = 0.0
	# o mar cobra: 40% dos peixes e 30% do diesel
	var peixes: Array = jogo.porao.itens.filter(func(i): return not jogo.porao.eh_carga(String(i.especie)))
	peixes.shuffle()
	var perder: int = ceili(peixes.size() * 0.4)
	for i in perder:
		jogo.porao.retirar(peixes[i])
	barco.combustivel *= 0.7
	var c: Node = jogo.clima
	var faltam: float = fposmod(6.0 - float(c.hora), 24.0)
	if faltam > 0.0 and faltam < 12.0:
		c.avancar(faltam)
	valor = 0.15
	luz_falhando = 0.0
	sombra_radar = 0.0
	_canto_t = 0.0
	if jogo.fantasmas != null:
		jogo.fantasmas.limpar()
	jogo.interface.aviso(T.t("Você apagou. Acordou ao amanhecer, à deriva, longe de onde estava. Faltam %d peixe(s) no porão e diesel no tanque.") % perder)

# ------------------------------------------------------------------ tela

func _pintar(_delta: float) -> void:
	var m: ShaderMaterial = _vinheta.material
	m.set_shader_parameter("forca", smoothstep(0.25, 1.0, valor) * 0.85)
	m.set_shader_parameter("pulso", sin(_tempo * (1.5 + 3.0 * valor)))
	var hud: Node = jogo.interface.hud
	hud.assombro = valor
	hud.sombra_radar = sombra_radar
