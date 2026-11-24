shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
// v0.8.0: jubarte e golfinho (malhas de ferramentas/cetaceos.py). O corpo inteiro ondula de cima para baixo, como
// cetáceo nada (a onda cresce da cabeça para a cauda); as nadadeiras peitorais remam devagar. A fase vem do script
// (somada aos poucos), então mudar a velocidade não dá tranco.
// Cor do vértice: r = 0 corpo, 0,5 dorsal, 0,75 cauda, 1 peitoral; g = distância da raiz da peitoral; b = lado.

uniform sampler2D pele : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float fase = 0.0;
uniform float amplitude = 0.3;          // m que a ponta da cauda sobe e desce
uniform float z_cabeca = -6.5;
uniform float comprimento = 13.0;
uniform float remada = 0.0;             // 0..1: quanto as peitorais batem
uniform float fase_remada = 0.0;
uniform float molhado : hint_range(0.0, 1.0) = 0.6;   // brilho de pele molhada
uniform float corte_alfa = 0.5;

float desloc(float s) {
	float w = pow(smoothstep(0.22, 1.0, s), 1.5);
	return amplitude * (w * sin(fase - s * 4.2) - 0.12 * (1.0 - s) * sin(fase + 0.6));
}

void vertex() {
	float s = clamp((VERTEX.z - z_cabeca) / comprimento, 0.0, 1.0);
	float dy = desloc(s);
	float ds = 0.01;
	float inclin = (desloc(min(s + ds, 1.0)) - desloc(max(s - ds, 0.0))) / (2.0 * ds * comprimento);
	VERTEX.y += dy;
	NORMAL = normalize(vec3(NORMAL.x, NORMAL.y, NORMAL.z - inclin * NORMAL.y));
	if (COLOR.r > 0.9) {
		// peitoral: gira em torno da raiz (sobe e desce mais na ponta)
		float lado = COLOR.b > 0.5 ? 1.0 : -1.0;
		VERTEX.y += COLOR.g * comprimento * 0.045 * remada * sin(fase_remada + lado * 0.3);
	}
}

void fragment() {
	vec4 t = texture(pele, UV);
	if (t.a < corte_alfa) {
		discard;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = mix(0.75, 0.32, molhado);
	SPECULAR = mix(0.25, 0.55, molhado);
	RIM = 0.15;
	RIM_TINT = 0.6;
}
