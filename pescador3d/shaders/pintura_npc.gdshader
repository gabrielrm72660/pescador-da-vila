shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;   // v0.7.9: dois lados (popa transparente)
// Pintura do barco do jogador com outra cor: mantém os traços e o desgaste da textura original
// (só a claridade dela entra) e troca a cor. Usado nos barcos NPC (scripts/vida_portuaria.gd).
uniform sampler2D tex_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tinta : source_color = vec3(0.2, 0.4, 0.6);
uniform float luma_ref = 0.2;       // claridade média da textura original (espaço linear)
uniform float escala_normal = 0.6;

void fragment() {
	vec3 c = texture(tex_albedo, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float k = clamp(l / max(luma_ref, 0.04), 0.40, 1.55);
	ALBEDO = clamp(tinta * k, 0.0, 1.0);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
	NORMAL_MAP = texture(tex_normal, UV).xyz;
	NORMAL_MAP_DEPTH = escala_normal;
}
