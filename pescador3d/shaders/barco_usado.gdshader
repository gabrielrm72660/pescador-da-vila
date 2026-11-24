shader_type spatial;
// v0.7.6: dois lados. As amuradas e o espelho de popa do modelo têm faces de um lado só; com cull_back, olhando de
// cima ou de trás, a parede do outro lado sumia e o mar aparecia através da popa.
render_mode diffuse_burley, cull_disabled;
// v0.5.7: o barco do jogador com cara de barco de pesca usado, por cima das texturas de tinta do modelo.
//  - tinta desbotada pelo sol e pelo sal (menos saturada, um pouco mais escura e amarelada);
//  - manchas de sujeira e de mão nas partes de baixo;
//  - lascas onde a tinta caiu e aparece a madeira (só nas peças pintadas);
//  - escorridos de ferrugem descendo das ferragens e do convés;
//  - limo verde-marrom e encardido na linha d'água;
//  - sal esbranquiçado nas quinas de cima.
// "tipo": 0 pintura/casco, 1 madeira, 2 metal, 3 corda/rede/lona, 4 plástico/boia. "desgaste": 0 novo ... 1 usado.

uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool tem_textura = true;
uniform bool tem_normal = false;
uniform vec4 cor : source_color = vec4(1.0);
uniform float tipo = 0.0;
uniform float desgaste : hint_range(0.0, 1.5) = 1.0;
uniform float linha_dagua = 0.03;
uniform float semente = 0.0;

varying vec3 p_obj;
varying vec3 n_obj;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * ruido(p);
		p = p * 2.07 + vec2(13.7, 7.1);
		a *= 0.5;
	}
	return s;
}

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
}

void fragment() {
	vec3 c = cor.rgb;
	if (tem_textura) {
		c *= texture(tex_albedo, UV).rgb;
	}
	vec3 n = normalize(n_obj);
	// coordenada "de pintura": nos lados usa (z, y); em cima usa (x, z)
	vec2 lado = vec2(p_obj.z + p_obj.x * 0.37, p_obj.y);
	vec2 cima = p_obj.xz;
	vec2 q = mix(lado, cima, step(0.7, abs(n.y))) + vec2(semente * 7.3);

	float pintado = step(tipo, 0.5);
	float madeira = step(0.5, tipo) * step(tipo, 1.5);
	float metal = step(1.5, tipo) * step(tipo, 2.5);
	float plastico = step(3.5, tipo);

	// 1) tinta velha: desbotada, amarelada, um pouco escura (plástico perde mais cor com o sol)
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum) * vec3(1.03, 0.98, 0.88), (0.30 + 0.18 * plastico) * desgaste);
	c *= mix(1.0, 0.80 - 0.04 * madeira, desgaste);
	// pátina: o branco vira creme acinzentado (barco que nunca mais viu tinta nova)
	c = mix(c, c * vec3(0.92, 0.90, 0.84), smoothstep(0.55, 0.9, lum) * 0.6 * desgaste);

	// 2) manchas de sujeira, mais fortes embaixo e no convés
	float sujo = fbm(q * 1.6);
	float baixo = 1.0 - smoothstep(0.2, 1.6, p_obj.y);
	c *= 1.0 - desgaste * (0.10 + 0.14 * baixo + 0.10 * madeira) * smoothstep(0.42, 0.78, sujo);

	// 3) lascas de tinta: aparece a madeira escura por baixo, mais nas quinas e perto da água
	// lascas: poucas e pequenas no meio do costado, mais nas quinas, na borda de cima e perto da água
	float lasca = fbm(q * 12.0 + vec2(3.1, 9.7)) * (0.82 + 0.3 * fbm(q * 1.7 + vec2(8.0)));
	float quina = smoothstep(1.05, 1.35, p_obj.y) + smoothstep(0.35, 0.05, p_obj.y);
	float limite = 0.80 - 0.07 * quina - 0.03 * (1.0 - abs(n.y));
	float m_lasca = smoothstep(limite, limite + 0.025, lasca) * pintado * desgaste;
	c = mix(c, vec3(0.27, 0.20, 0.14) * (0.8 + 0.4 * ruido(q * 40.0)), m_lasca * 0.9);
	c = mix(c, c * 0.72, smoothstep(limite - 0.03, limite, lasca) * (1.0 - smoothstep(limite, limite + 0.02, lasca)) * pintado * desgaste);   // borda escura da lasca

	// 4) escorridos de ferrugem: estrias verticais que nascem nas ferragens/borda e descem
	float coluna = ruido(vec2(q.x * 11.0, 0.5)) * ruido(vec2(q.x * 3.7 + 4.0, 1.5));
	float comprimento = 0.25 + 0.9 * ruido(vec2(q.x * 5.3, 7.0));
	float da_borda = smoothstep(1.45, 1.10, p_obj.y) * smoothstep(1.45 - comprimento - 0.2, 1.45 - comprimento * 0.4, p_obj.y);
	float ferrugem = smoothstep(0.30, 0.55, coluna) * da_borda * (1.0 - step(0.7, abs(n.y)));
	ferrugem = max(ferrugem, metal * smoothstep(0.45, 0.75, fbm(q * 5.0 + vec2(1.7))));
	c = mix(c, vec3(0.44, 0.24, 0.11) * (0.8 + 0.3 * sujo), ferrugem * 0.55 * desgaste * (1.0 - plastico * 0.7));

	// 5) linha d'água: limo e encardido logo acima e abaixo dela, com borda irregular
	float onda = 0.06 * sin(p_obj.z * 2.3 + semente) + 0.05 * (ruido(vec2(p_obj.z * 3.0, p_obj.x)) - 0.5);
	float limo = 1.0 - smoothstep(linha_dagua + 0.06 + onda, linha_dagua + 0.32 + onda, p_obj.y);
	limo *= smoothstep(linha_dagua - 0.55, linha_dagua - 0.05, p_obj.y);
	c = mix(c, c * vec3(0.46, 0.50, 0.36) + vec3(0.03, 0.045, 0.02), limo * 0.85 * desgaste * (1.0 - step(0.7, abs(n.y))));
	float sob = 1.0 - smoothstep(linha_dagua - 0.25, linha_dagua + 0.05, p_obj.y);
	c = mix(c, c * vec3(0.62, 0.66, 0.58), sob * 0.55 * desgaste);

	// 6) sal: véu esbranquiçado nas partes de cima e viradas para cima
	float sal = smoothstep(0.55, 0.9, fbm(q * 3.3 + vec2(5.5))) * smoothstep(0.6, 1.8, p_obj.y) * (0.4 + 0.6 * max(n.y, 0.0));
	c = mix(c, vec3(0.86, 0.85, 0.80), sal * 0.18 * desgaste);

	ALBEDO = c;
	ROUGHNESS = mix(0.94, 0.78, metal) - 0.06 * limo;
	SPECULAR = mix(0.10, 0.25, metal);
	METALLIC = 0.0;
	if (tem_normal) {
		NORMAL_MAP = texture(tex_normal, UV).rgb;
		NORMAL_MAP_DEPTH = 0.6 + 0.4 * m_lasca;
	}
	RIM = 0.10;
	RIM_TINT = 0.5;
}
