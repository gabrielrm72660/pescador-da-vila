shader_type spatial;
// v0.8.9: a Coisa de Baixo saindo da água (malha do TRELLIS, com UV). Pele molhada + contorno frio de luar na silhueta.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D cor : source_color, filter_linear_mipmap;
uniform sampler2D relevo : hint_normal, filter_linear_mipmap;
uniform float molhado : hint_range(0.0, 1.0) = 0.8;
uniform float luar : hint_range(0.0, 2.0) = 0.8;

void fragment() {
	ALBEDO = texture(cor, UV).rgb;
	NORMAL_MAP = texture(relevo, UV).rgb;
	NORMAL_MAP_DEPTH = 0.8;
	ROUGHNESS = mix(0.85, 0.3, molhado);
	SPECULAR = mix(0.3, 0.65, molhado);
	float borda = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.10, 0.16, 0.18) * borda * luar;
}
