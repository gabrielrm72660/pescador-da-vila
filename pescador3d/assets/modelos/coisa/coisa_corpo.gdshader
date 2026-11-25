shader_type spatial;
// v0.8.9: a Coisa de Baixo, corpo inteiro. A malha (Hunyuan3D) não tem UV: a arte de perfil do Gabriel é projetada de lado
// (no eixo Z do objeto), casando a caixa do bicho na arte com a caixa da malha. Por cima e por baixo a projeção estica,
// e isso dá certo: no alto da arte está o dorso escuro, embaixo a barriga clara.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D arte : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D relevo : hint_normal, filter_linear_mipmap, repeat_disable;
uniform vec4 caixa = vec4(-0.996957, 0.989782, -0.257368, 0.250605);   // xmin, xmax, ymin, ymax da malha (ferramentas/coisa_de_baixo.py)
uniform float claridade : hint_range(0.0, 2.0) = 1.0;
uniform float molhado : hint_range(0.0, 1.0) = 0.6;
uniform float luar : hint_range(0.0, 2.0) = 0.7;      // contorno frio na silhueta: no breu, a forma ainda se lê

varying vec3 pos_obj;

void vertex() {
	pos_obj = VERTEX;
}

void fragment() {
	vec2 uv = vec2((pos_obj.x - caixa.x) / (caixa.y - caixa.x), (caixa.w - pos_obj.y) / (caixa.w - caixa.z));
	uv = clamp(uv, vec2(0.002), vec2(0.998));
	ALBEDO = texture(arte, uv).rgb * claridade;
	NORMAL_MAP = texture(relevo, uv).rgb;
	NORMAL_MAP_DEPTH = 0.7;
	ROUGHNESS = mix(0.85, 0.32, molhado);
	SPECULAR = mix(0.3, 0.6, molhado);
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.10, 0.16, 0.18) * borda * luar;
}
