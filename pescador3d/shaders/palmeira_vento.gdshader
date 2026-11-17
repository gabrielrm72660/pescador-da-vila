shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/vento.gdshaderinc"

// Coqueiro com vento: o tronco se dobra de leve e as folhas em pena tremem nas pontas.
// Visual igual ao material comum (atlas palmeira.png com recorte de transparência).
uniform sampler2D tex_palma : source_color, filter_linear_mipmap, repeat_enable;
uniform float altura_ref = 9.0;
uniform float brilho = 1.40;
uniform float corte = 0.38;

void vertex() {
    vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float esc = length(MODEL_MATRIX[1].xyz);
    float alto = clamp(VERTEX.y / altura_ref, 0.0, 1.0);
    float ponta = 1.0 - smoothstep(0.0, 0.862, UV.y);       // folhas: v baixo = ponta; tronco usa v > 0,89
    vec3 d = vento_desloc(TIME, mundo, pow(alto, 1.5), ponta * 1.4 + alto * 0.2, altura_ref * esc * 0.8);
    VERTEX += inverse(mat3(MODEL_MATRIX)) * d;
}

void fragment() {
    vec4 t = texture(tex_palma, UV);
    ALBEDO = COLOR.rgb * t.rgb * brilho;
    ALPHA = t.a;
    ALPHA_SCISSOR_THRESHOLD = corte;
    ROUGHNESS = 0.93;
}
