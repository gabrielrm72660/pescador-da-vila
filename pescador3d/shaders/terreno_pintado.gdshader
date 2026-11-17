shader_type spatial;
render_mode cull_back, diffuse_burley;

// Terreno da ilha: areia, mato e rocha pintados (assets/texturas/ilha), misturados pela altura e pela
// inclinacao do chao. A rocha e projetada pelos lados, para nao esticar nos paredoes.
uniform sampler2D tex_areia : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_grama : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_rocha : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_manchas : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform float altura_grama = 2.2;        // m acima do mar onde a areia vira mato
uniform float altura_pedra = 24.0;       // m onde o mato rareia e sobra pedra

varying vec3 pos_mundo;
varying vec3 normal_mundo;

void vertex() {
    pos_mundo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    normal_mundo = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    vec3 n = normalize(normal_mundo);
    float h = pos_mundo.y;
    float larga = texture(tex_manchas, pos_mundo.xz * 0.021).r;
    float fina = texture(tex_manchas, pos_mundo.xz * 0.17 + vec2(0.3, 0.7)).r;

    vec3 areia = texture(tex_areia, pos_mundo.xz * 0.11).rgb * vec3(1.0, 0.97, 0.93);
    vec3 grama = texture(tex_grama, pos_mundo.xz * 0.085).rgb * mix(0.80, 1.04, larga) * vec3(0.76, 0.90, 0.84);   // menos amarelo
    // rocha: de cima no chao, de lado nos paredoes
    vec3 peso = pow(abs(n), vec3(4.0));
    peso /= (peso.x + peso.y + peso.z);
    vec3 rocha = texture(tex_rocha, pos_mundo.xz * 0.045).rgb * peso.y
               + texture(tex_rocha, pos_mundo.zy * 0.045).rgb * peso.x
               + texture(tex_rocha, pos_mundo.xy * 0.045).rgb * peso.z;
    // camadas deitadas, como rocha vulcanica: faixas mais claras e mais escuras conforme a altura
    float camada = texture(tex_manchas, vec2(h * 0.045 + larga * 0.25, (pos_mundo.x + pos_mundo.z) * 0.004)).r;
    rocha *= mix(0.86, 1.30, camada);
    rocha *= mix(0.85, 1.25, smoothstep(30.0, 66.0, h));                 // o alto do pico e mais claro

    float borda = (larga - 0.5) * 1.6 + (fina - 0.5) * 0.5;             // a fronteira entre as tintas e irregular
    float inclinacao = 1.0 - n.y;
    vec3 cor = mix(areia, grama, smoothstep(-0.5, 0.7, h - altura_grama + borda * 1.4));
    float pedra = smoothstep(0.16, 0.34, inclinacao + borda * 0.07);
    pedra = max(pedra, smoothstep(-5.0, 6.0, h - altura_pedra + borda * 6.0));
    cor = mix(cor, rocha, pedra);

    // areia molhada na beira e o fundo raso, que se ve atraves da agua
    float molhado = smoothstep(0.75, 0.05, h) * (1.0 - pedra * 0.6);
    cor = mix(cor, cor * vec3(0.62, 0.60, 0.56), molhado);
    cor = mix(cor, vec3(0.50, 0.66, 0.60), smoothstep(-0.2, -2.5, h) * 0.7);

    ALBEDO = cor * (0.90 + 0.16 * larga);                     // sem granulado fino: a pintura ja traz a pincelada
    ROUGHNESS = mix(1.0, 0.62, molhado);                      // pintura fosca: nada brilha, so a areia molhada
    SPECULAR = mix(0.04, 0.32, molhado);
}
