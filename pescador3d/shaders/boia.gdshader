shader_type spatial;
render_mode diffuse_burley, cull_back;
// v0.5.11: boias de sinalização com cara de aço pintado que vive no mar.
// A cor da tinta vem da cor do vértice; o alfa do vértice diz o material:
//   1.0 aço pintado | 0.75 borracha (defensa) | 0.5 aço galvanizado | 0.25 painel solar
// Tudo procedural em coordenadas do objeto (sem textura), então não há emendas nem repetição visível:
//  - tinta marítima desbotada e manchada, lascas mostrando o primer e a ferrugem por baixo;
//  - escorridos de ferrugem descendo das quinas e dos parafusos;
//  - linha d'água com limo verde-marrom e cracas;
//  - fezes de aves marinhas no alto (manchas e escorridos brancos), como em toda boia de verdade;
//  - sal esbranquiçado nas partes de cima.

uniform float semente = 0.0;
uniform float desgaste : hint_range(0.0, 1.5) = 1.0;

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
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}
// pontinhos (cracas): distância ao centro da célula
float pontos(vec2 p, float densidade) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float h = hash(i);
	vec2 c = vec2(hash(i + 3.7), hash(i + 8.1)) * 0.6 + 0.2;
	float r = 0.12 + 0.18 * hash(i + 1.3);
	return step(h, densidade) * (1.0 - smoothstep(r * 0.6, r, length(f - c)));
}

void vertex() {
	p_obj = VERTEX;
	n_obj = NORMAL;
}

void fragment() {
	vec3 base = COLOR.rgb;
	float tipo = COLOR.a;
	vec3 n = normalize(n_obj);
	float ang = atan(p_obj.z, p_obj.x);
	float raio = length(p_obj.xz);
	// coordenada "de pintura": nos lados, (volta ao redor do eixo, altura); em cima, (x, z)
	vec2 lado = vec2(ang * max(raio, 0.25), p_obj.y);
	vec2 q = mix(lado, p_obj.xz, step(0.65, abs(n.y))) + vec2(semente * 5.3, semente * 2.1);
	float cima = max(n.y, 0.0);
	float y = p_obj.y;

	float pintado = step(0.875, tipo);
	float borracha = step(0.625, tipo) * (1.0 - pintado);
	float galv = step(0.375, tipo) * step(tipo, 0.625);
	float painel = step(0.125, tipo) * step(tipo, 0.375);

	vec3 c = base;
	float rough = 0.66;
	float spec = 0.3;

	// ---------- aço pintado
	if (pintado > 0.5) {
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		c = mix(c, vec3(lum) * vec3(1.05, 0.98, 0.9), 0.18 * desgaste);                 // desbotado pelo sol
		c *= 0.88 + 0.2 * fbm(q * 1.7);                                                    // manchado
		// lascas: primer cinza e ferrugem por baixo, mais nas quinas (borda de cima do flutuador e da torre)
		float quina = smoothstep(0.52, 0.62, y) * smoothstep(0.74, 0.62, y) + 0.4 * smoothstep(0.3, 0.0, abs(n.y) - 0.0) * step(0.8, y);
		float l = fbm(q * 9.0 + vec2(4.1, 2.2));
		float lim = 0.74 - 0.10 * quina;
		float lasca = smoothstep(lim, lim + 0.03, l) * desgaste;
		vec3 por_baixo = mix(vec3(0.42, 0.40, 0.37), vec3(0.36, 0.17, 0.08), smoothstep(0.75, 0.85, l));
		c = mix(c, por_baixo, lasca);
		rough = mix(rough, 0.85, lasca);
		// escorridos de ferrugem descendo da borda do flutuador e da plataforma
		float coluna = ruido(vec2(q.x * 9.0, 0.5)) * ruido(vec2(q.x * 2.9 + 3.0, 1.5));
		float comp = 0.15 + 0.45 * ruido(vec2(q.x * 4.3, 6.0));
		float da_borda = smoothstep(0.62, 0.52, y) * smoothstep(0.62 - comp - 0.1, 0.62 - comp * 0.3, y);
		float da_torre = smoothstep(2.55, 2.40, y) * smoothstep(1.4, 2.2, y);
		float ferrugem = smoothstep(0.32, 0.58, coluna) * (da_borda + 0.6 * da_torre) * (1.0 - step(0.65, abs(n.y)));
		c = mix(c, vec3(0.40, 0.19, 0.08) * (0.8 + 0.4 * fbm(q * 4.0)), clamp(ferrugem, 0.0, 1.0) * 0.6 * desgaste);
		rough = mix(rough, 0.9, ferrugem * 0.6);
	}

	// ---------- borracha da defensa
	if (borracha > 0.5) {
		c = vec3(0.045, 0.045, 0.05) * (0.85 + 0.3 * fbm(q * 6.0));
		float risco = smoothstep(0.72, 0.8, fbm(vec2(q.x * 3.0, q.y * 30.0)));
		c = mix(c, vec3(0.16, 0.15, 0.14), risco * 0.7);
		rough = 0.92;
		spec = 0.2;
	}

	// ---------- aço galvanizado
	if (galv > 0.5) {
		float m = fbm(q * 5.0);
		c = vec3(0.50, 0.52, 0.53) * (0.8 + 0.35 * m);
		c = mix(c, vec3(0.78, 0.78, 0.74), smoothstep(0.66, 0.78, fbm(q * 11.0)) * 0.6);      // óxido branco
		c = mix(c, vec3(0.38, 0.20, 0.10), smoothstep(0.72, 0.82, fbm(q * 7.0 + 9.0)) * 0.7 * desgaste);
		rough = 0.6;
		spec = 0.45;
	}

	// ---------- painel solar
	if (painel > 0.5) {
		vec2 g = fract(UV * vec2(18.0, 12.0));
		float linha = max(step(g.x, 0.06), step(g.y, 0.06));
		c = mix(vec3(0.025, 0.045, 0.11), vec3(0.55, 0.57, 0.6), linha * 0.7);
		c *= 0.9 + 0.2 * ruido(UV * 40.0);
		rough = mix(0.18, 0.5, linha);
		spec = 0.6;
	}

	// ---------- coisas do mar, em cima de tudo
	// linha d'água: limo e cracas no pé do flutuador
	float borda_limo = 0.14 + 0.08 * (fbm(vec2(q.x * 2.5, 3.0)) - 0.5);
	float limo = 1.0 - smoothstep(borda_limo - 0.04, borda_limo + 0.04, y);
	vec3 cor_limo = mix(vec3(0.07, 0.10, 0.05), vec3(0.20, 0.22, 0.10), fbm(q * 6.0));
	c = mix(c, cor_limo, limo * 0.85 * (1.0 - painel));
	float cracas = pontos(q * 22.0, 0.55) * limo * smoothstep(-0.5, borda_limo - 0.02, y);
	c = mix(c, vec3(0.70, 0.68, 0.62), cracas * 0.8);
	rough = mix(rough, 0.35, limo * 0.6);                 // molhado

	// fezes de aves: manchas em cima e escorridos brancos descendo das bordas altas
	float alto = smoothstep(0.4, 0.75, y);
	float mancha = smoothstep(0.70, 0.78, fbm(q * 3.2 + vec2(semente))) * cima * alto * 0.75;
	float esc_col = smoothstep(0.55, 0.75, ruido(vec2(q.x * 7.0 + semente, 2.0)));
	float esc_y = smoothstep(0.66, 0.58, y) * smoothstep(0.18, 0.5, y) * smoothstep(0.35, 0.65, ruido(vec2(q.x * 7.0, y * 3.0)));
	float escorrido = esc_col * esc_y * (1.0 - step(0.65, abs(n.y))) * (1.0 - borracha);
	float topo = smoothstep(3.3, 3.9, y) * cima;                                      // pouso preferido: o sinal de topo
	float aves = clamp(mancha + 0.7 * escorrido + 0.8 * topo * smoothstep(0.5, 0.65, fbm(q * 5.0)), 0.0, 1.0) * desgaste;
	c = mix(c, vec3(0.86, 0.85, 0.80) * (0.92 + 0.1 * ruido(q * 30.0)), aves * 0.85);
	rough = mix(rough, 0.9, aves);

	// sal nas partes de cima
	float sal = smoothstep(0.6, 0.85, fbm(q * 4.0 + 2.0)) * (0.3 + 0.7 * cima) * smoothstep(0.3, 1.0, y);
	c = mix(c, vec3(0.82, 0.82, 0.78), sal * 0.15 * desgaste);

	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
	METALLIC = 0.0;
	RIM = 0.08;
	RIM_TINT = 0.5;
}
