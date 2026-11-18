shader_type spatial;
render_mode cull_back, diffuse_burley;

// Terreno da ilha: areia, mato e rocha pintados (assets/texturas/ilha), misturados pela altura e pela
// inclinacao do chao. A rocha e projetada pelos lados, para nao esticar nos paredoes.
uniform sampler2D tex_areia : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_grama : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_rocha : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_manchas : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_barro : source_color, repeat_enable, filter_linear_mipmap;   // v0.5.7: opcional (assets/texturas/ilha/barranco.png)
uniform bool tem_barro = false;
uniform float altura_grama = 2.2;        // m acima do mar onde a areia vira mato
uniform float altura_pedra = 22.0;       // m onde o mato rareia e sobra pedra

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
    float granito = texture(tex_manchas, pos_mundo.xz * 0.035 + vec2(0.17, 0.59)).r;

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
    // Camadas geologicas descontinuas: paredes mais definidas sem listras retas.
    float laminacao = sin(h * 0.72 + larga * 3.5 + granito * 2.0);
    rocha *= mix(0.82, 1.27, camada) * (0.94 + 0.08 * laminacao);
    rocha = mix(rocha, rocha * vec3(0.73, 0.77, 0.80), (1.0 - n.y) * (1.0 - fina) * 0.26);
    rocha *= mix(0.85, 1.25, smoothstep(30.0, 66.0, h));                 // o alto do pico e mais claro

    float borda = (larga - 0.5) * 1.6 + (fina - 0.5) * 0.5;             // a fronteira entre as tintas e irregular
    float inclinacao = 1.0 - n.y;
    // v0.5.7: areia só onde a praia é baixa E quase plana; encosta baixa vira barranco de terra, encosta alta vira rocha
    float tangente = length(n.xz) / max(n.y, 0.05);                   // declividade de verdade (0,1 = 6 graus)
    float plano = 1.0 - smoothstep(0.09, 0.19, tangente + borda * 0.04);
    float baixa = 1.0 - smoothstep(-0.5, 0.7, h - altura_grama + borda * 1.4);
    vec3 cor = mix(grama, areia, baixa * plano);
    // linha d'água: mesmo numa rampa sobra uma tira estreita de areia grossa e cascalho (não no barranco a prumo)
    float beira = (1.0 - smoothstep(0.25, 1.0, h + borda * 0.35)) * (1.0 - smoothstep(0.45, 0.9, tangente));
    cor = mix(cor, areia * vec3(0.86, 0.84, 0.80) * mix(0.85, 1.05, fina), beira);
    // barro dos barrancos: terra avermelhada em faixas deitadas, com raízes/escuro no topo e sal claro embaixo
    vec3 barro = rocha * vec3(1.10, 0.80, 0.60);
    if (tem_barro) {                                                      // textura própria: projetada de lado, como a rocha
        barro = texture(tex_barro, pos_mundo.zy * 0.12).rgb * peso.x + texture(tex_barro, pos_mundo.xy * 0.12).rgb * peso.z
              + texture(tex_barro, pos_mundo.xz * 0.12).rgb * peso.y;
    }
    float estrato = 0.5 + 0.5 * sin(h * 2.6 + larga * 4.0 + fina * 1.5);
    barro *= mix(0.80, 1.12, estrato) * mix(0.88, 1.06, granito);
    barro = mix(barro, barro * vec3(0.55, 0.50, 0.42), smoothstep(0.0, 1.2, h - 4.2 - borda * 1.5) * 0.6);
    barro = mix(barro, vec3(0.70, 0.66, 0.58), (1.0 - smoothstep(0.0, 1.1, h)) * 0.45);
    float pedra = smoothstep(0.12, 0.38, inclinacao + borda * 0.08);
    float alto_rocha = smoothstep(-5.0, 6.0, h - altura_pedra + borda * 6.0);
    vec3 encosta = mix(barro, rocha, smoothstep(8.0, 14.0, h + borda * 3.0));
    cor = mix(cor, encosta, pedra);
    cor = mix(cor, rocha, alto_rocha);
    pedra = max(pedra, alto_rocha);
    // Reentrancias e sombra natural nas fendas; evita um morro liso e plastico.
    float cavidades = (1.0 - fina) * (0.5 + 0.5 * (1.0 - granito));
    cor *= 1.0 - cavidades * pedra * 0.16;
    // Variacao suave de exposicao solar e vegetacao nas encostas.
    cor *= 0.95 + 0.10 * clamp(dot(n, normalize(vec3(0.55, 0.95, -0.22))), 0.0, 1.0);

    // areia molhada na beira e o fundo raso, que se ve atraves da agua
    float molhado = (1.0 - smoothstep(0.05, 0.75, h)) * (1.0 - pedra * 0.6);
    cor = mix(cor, cor * vec3(0.62, 0.60, 0.56), molhado);
    cor = mix(cor, vec3(0.50, 0.66, 0.60), (1.0 - smoothstep(-2.5, -0.2, h)) * 0.7);

    ALBEDO = cor * (0.90 + 0.16 * larga);                     // sem granulado fino: a pintura ja traz a pincelada
    ROUGHNESS = mix(mix(0.98, 0.90, pedra), 0.66, molhado);                      // pintura fosca: nada brilha, so a areia molhada
    SPECULAR = mix(0.04, 0.32, molhado);
}
