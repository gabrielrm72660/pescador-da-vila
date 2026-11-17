shader_type spatial;
render_mode cull_disabled;
#include "res://shaders/vento.gdshaderinc"

// Copa de pinheiro, árvore e moita com vento. Visual igual ao material comum do jogo (cor do vértice x detalhe
// de folhagem em triplanar), mais o balanço. Só entra em Alta e Ultra (ilha.gd escolhe o material).
uniform sampler2D tex_copa : source_color, filter_linear_mipmap, repeat_enable;
uniform float escala_tex = 0.3;
uniform float altura_ref = 9.0;      // altura da malha (unidades do objeto): define quanto do tronco fica preso ao chão
uniform float rugosidade = 0.96;
uniform float brilho = 1.42;         // compensa o escurecimento do mapa de detalhe (média ~0,7)

varying vec3 tri_pos;
varying vec3 tri_nor;

void vertex() {
    tri_pos = VERTEX;                // o detalhe fica colado na folhagem: usa a posição ANTES do balanço
    tri_nor = NORMAL;
    vec3 mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float esc = length(MODEL_MATRIX[1].xyz);
    float alto = clamp(VERTEX.y / altura_ref, 0.0, 1.0);
    vec3 d = vento_desloc(TIME, mundo, pow(alto, 1.7), alto, altura_ref * esc);
    VERTEX += inverse(mat3(MODEL_MATRIX)) * d;
}

void fragment() {
    vec3 w = abs(normalize(tri_nor));
    w /= max(w.x + w.y + w.z, 0.0001);
    vec3 q = tri_pos * escala_tex;
    vec3 detalhe = texture(tex_copa, q.zy).rgb * w.x + texture(tex_copa, q.xz).rgb * w.y + texture(tex_copa, q.xy).rgb * w.z;
    ALBEDO = COLOR.rgb * detalhe * brilho;
    ROUGHNESS = rugosidade;
}
