shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
#include "res://shaders/vento.gdshaderinc"

// v0.9.3: cartas de folha das árvores de Noronha (scripts/vegetacao_tropical.gd). Cada carta é um quadrado com um cacho
// de folhas pintado em guache (atlas do SpriteCook, ferramentas/folhas_spritecook.py), recortado pela transparência.
// As folhas do atlas são cinzas: a cor vem do vértice (verde de cada lóbulo). As células coloridas (folha vermelha,
// flor) vêm com o vértice branco. A normal de cada carta aponta para fora da copa (sombreamento redondo, não de papel).
uniform sampler2D tex_folhas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float altura_ref = 9.0;      // altura da árvore (unidades do objeto): o pé do tronco não balança
uniform bool com_vento = true;
uniform float brilho = 1.25;
uniform float corte : hint_range(0.0, 1.0) = 0.42;
uniform float transluz = 0.35;       // luz que atravessa a folha quando o sol está atrás

void vertex() {
    if (com_vento) {
        vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        float esc = length(MODEL_MATRIX[1].xyz);
        float alto = clamp(VERTEX.y / altura_ref, 0.0, 1.0);
        vec3 d = vento_desloc(TIME, mundo, pow(alto, 1.7), 1.0, altura_ref * esc);
        VERTEX += inverse(mat3(MODEL_MATRIX)) * d;
    }
}

void fragment() {
    vec4 t = texture(tex_folhas, UV);
    ALBEDO = COLOR.rgb * t.rgb * brilho;
    ALPHA = t.a;
    ALPHA_SCISSOR_THRESHOLD = corte;
    ROUGHNESS = 0.92;
    SPECULAR = 0.15;
    BACKLIGHT = ALBEDO * transluz;
}
