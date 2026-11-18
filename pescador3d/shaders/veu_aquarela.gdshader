shader_type canvas_item;
// Véu de aquarela para trás dos menus: uma lavagem azul-marinho rala no meio (o mar aparece) e carregada nas bordas,
// com manchas e grão de papel. Substitui o retângulo chapado que escurecia a tela inteira.

uniform vec4 cor : source_color = vec4(0.02, 0.07, 0.12, 1.0);
uniform vec4 cor2 : source_color = vec4(0.05, 0.16, 0.24, 1.0);
uniform float forca : hint_range(0.0, 1.0) = 0.82;     // opacidade nas bordas
uniform float centro : hint_range(0.0, 1.0) = 0.42;    // opacidade no meio, em relação às bordas
uniform vec2 proporcao = vec2(1.0, 0.5625);

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

void fragment() {
	vec2 q = (UV - vec2(0.5)) * 2.0;
	float borda = clamp(length(q * vec2(0.92, 1.0)) / 1.25, 0.0, 1.0);
	float nuvem = fbm(UV * vec2(4.2, 2.6) * 2.0 + 3.0);
	float mancha = fbm(UV * vec2(9.0, 5.0) + 11.0);
	// a tinta recua do meio de forma irregular, com a beirada mais carregada
	float limiar = borda + (nuvem - 0.5) * 0.55;
	float massa = smoothstep(0.10, 0.92, limiar);
	float a = forca * mix(centro, 1.0, massa);
	a *= 0.86 + 0.28 * mancha;
	vec2 px = UV / max(SCREEN_PIXEL_SIZE * 1.0, vec2(0.0001));
	float g = ruido(px * 1.1) * 0.55 + ruido(px * 2.6 + 7.0) * 0.45;
	a *= 1.0 + (g - 0.5) * 0.12;
	vec3 col = mix(cor.rgb, cor2.rgb, smoothstep(0.30, 0.80, mancha));
	col *= 1.0 - 0.25 * smoothstep(0.62, 0.78, nuvem) + 0.0;
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
