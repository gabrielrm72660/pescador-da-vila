shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Mar pintado, todo procedural: sem imagens externas e sem costura visivel.
// Cores pensadas para combinar com a pintura artesanal do barco PE-3476.
uniform vec4 cor_profunda : source_color = vec4(0.025, 0.135, 0.215, 1.0);
uniform vec4 cor_media : source_color = vec4(0.035, 0.315, 0.400, 1.0);
uniform vec4 cor_turquesa : source_color = vec4(0.110, 0.560, 0.600, 1.0);
uniform vec4 cor_espuma : source_color = vec4(0.90, 0.96, 0.95, 1.0);
uniform vec4 cor_reflexo_ceu : source_color = vec4(0.66, 0.74, 0.78, 1.0);
uniform vec4 cor_horizonte : source_color = vec4(0.64, 0.70, 0.71, 1.0);

uniform float altura_ondas : hint_range(0.0, 1.5, 0.01) = 0.30;
uniform float velocidade_ondas : hint_range(0.0, 3.0, 0.05) = 0.75;
uniform float quantidade_espuma : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float brilho : hint_range(0.0, 1.0, 0.01) = 0.55;

// Texturas pintadas (assets/texturas/mar, geradas por ferramentas/gerar_texturas.py); scripts/oceano.gd as liga.
uniform sampler2D tex_ondas : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_marolas : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D tex_espuma : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_pigmento : hint_default_white, repeat_enable, filter_linear_mipmap;
// O reflexo do ceu: fraco em toda a agua e forte so na direcao do sol (o caminho de luz).
uniform float reflexo_geral : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float reflexo_no_sol : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform vec3 direcao_sol = vec3(0.0, 1.0, 0.0);      // do mar para o sol (enviada por scripts/clima.gd)
uniform float forca_relevo : hint_range(0.0, 2.0, 0.01) = 0.55;
// A costa: mapa de alturas do fundo em volta da ilha (enviado por scripts/ilha.gd). costa_lado = 0 desliga.
uniform sampler2D tex_costa : hint_default_black, repeat_disable, filter_linear;
uniform vec2 costa_centro = vec2(0.0);
uniform float costa_lado = 0.0;                      // lado (m) do quadrado que o mapa cobre
uniform sampler2D tex_costa2 : hint_default_black, repeat_disable, filter_linear;   // a segunda ilha
uniform vec2 costa_centro2 = vec2(0.0);
uniform float costa_lado2 = 0.0;
uniform vec2 costa_faixa = vec2(-12.0, 4.0);         // altura (m) que vale 0 e 1 no mapa
uniform vec4 cor_raso : source_color = vec4(0.20, 0.78, 0.72, 1.0);
uniform float luz_propria = 1.0;                     // a agua se acende um pouco sozinha de dia; a noite, nao

// Enviados por scripts/oceano.gd. O tempo vem do script (e nao de TIME) para o barco
// calcular a mesma onda e subir e descer junto com a agua.
uniform float tempo_mar = 0.0;
uniform vec2 barco_pos = vec2(0.0);
uniform vec2 barco_frente = vec2(0.0, -1.0);
uniform float barco_vel = 0.0;                 // 0 parado ... 1 velocidade maxima
uniform vec4 rastro[96];                        // x, z, idade (s), forca (0 = vazio)

const float VIDA_RASTRO = 14.0;

varying vec2 coordenada_mundo;
varying float altura_crista;

float onda(vec2 p, float t) {
    return 0.47 * sin(p.x * 0.21 + p.y * 0.09 + t * 0.82)
         + 0.33 * sin(p.y * 0.31 - p.x * 0.07 - t * 0.68)
         + 0.17 * sin(dot(p, vec2(0.62, -0.24)) + t * 1.18)
         + 0.08 * sin(dot(p, vec2(-0.90, 0.41)) - t * 1.45);
}

float aleatorio(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ruido(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(aleatorio(i), aleatorio(i + vec2(1.0, 0.0)), u.x),
        mix(aleatorio(i + vec2(0.0, 1.0)), aleatorio(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float turbulencia(vec2 p) {
    float a = ruido(p) * 0.54;
    a += ruido(p * 2.07 + vec2(7.4, 1.2)) * 0.29;
    a += ruido(p * 4.13 + vec2(3.8, 4.9)) * 0.17;
    return a;
}

void vertex() {
    vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    float h = onda(p, tempo_mar * velocidade_ondas);
    coordenada_mundo = p;
    altura_crista = h;
    VERTEX.y += h * altura_ondas;
    NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
    vec2 p = coordenada_mundo;
    float t = tempo_mar * velocidade_ondas;
    float distancia = length(VERTEX);                       // metros ate a camera
    float perto = 1.0 - smoothstep(40.0, 220.0, distancia);  // detalhe fino so perto: longe ele vira chuvisco

    // ---- relevo: ondas grandes (calculadas) + tres camadas de textura deslizando em direcoes diferentes
    float d = 0.12;
    float dx = (onda(p + vec2(d, 0.0), t) - onda(p - vec2(d, 0.0), t)) * altura_ondas / (2.0 * d);
    float dz = (onda(p + vec2(0.0, d), t) - onda(p - vec2(0.0, d), t)) * altura_ondas / (2.0 * d);
    vec2 n_larga = texture(tex_ondas, p * 0.011 - vec2(t * 0.004, t * 0.006)).xy * 2.0 - 1.0;   // ~90 m
    vec2 n_media = texture(tex_ondas, p * 0.037 + vec2(t * 0.013, t * 0.008)).xy * 2.0 - 1.0;   // ~27 m
    vec2 n_fina = texture(tex_marolas, p * 0.17 + vec2(-t * 0.05, t * 0.035)).xy * 2.0 - 1.0;   // ~6 m
    vec2 relevo = (n_larga * 0.40 + n_media * 0.45 + n_fina * 0.32 * perto) * forca_relevo;
    vec3 normal_mundo = normalize(vec3(-dx - relevo.x, 1.0, -dz - relevo.y));
    NORMAL = normalize((VIEW_MATRIX * vec4(normal_mundo, 0.0)).xyz);

    // ---- pigmento pintado: manchas de aquarela da textura + tres tons de azul
    float aquarela = texture(tex_pigmento, p * 0.0065 + vec2(t * 0.0015, -t * 0.001)).r;
    float pincelada = texture(tex_pigmento, p * 0.031 + vec2(-t * 0.004, t * 0.003)).r;
    float camada = mix(turbulencia(p * 0.091 + vec2(t * 0.029, -t * 0.017)), aquarela, 0.55);
    float detalhe = mix(turbulencia(p * 0.28 + vec2(-t * 0.11, t * 0.083)), pincelada, 0.5);
    vec3 base = mix(cor_profunda.rgb, cor_media.rgb, smoothstep(0.23, 0.82, camada));
    base = mix(base, cor_turquesa.rgb, smoothstep(0.52, 0.92, detalhe) * 0.36);
    base *= mix(0.90, 1.10, pincelada);
    // a luz atravessa o alto das ondas: crista mais clara e esverdeada
    float crista_fina = clamp(altura_crista + (n_media.x + n_media.y) * 0.35, -1.0, 1.0);
    base = mix(base, cor_turquesa.rgb, smoothstep(0.25, 1.0, crista_fina) * 0.30);

    // ---- agua rasa em volta da ilha: turquesa clara, deixando ver a areia do fundo
    float fundura = 30.0;
    if (costa_lado > 0.0) {
        vec2 uv = (p - costa_centro) / costa_lado + 0.5;
        if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
            fundura = -mix(costa_faixa.x, costa_faixa.y, texture(tex_costa, uv).r);
        }
    }
    if (costa_lado2 > 0.0) {
        vec2 uv2 = (p - costa_centro2) / costa_lado2 + 0.5;
        if (uv2.x > 0.0 && uv2.x < 1.0 && uv2.y > 0.0 && uv2.y < 1.0) {
            fundura = -mix(costa_faixa.x, costa_faixa.y, texture(tex_costa2, uv2).r);
        }
    }
    float raso = smoothstep(9.0, 0.4, fundura);
    base = mix(base, cor_raso.rgb * mix(0.92, 1.08, pincelada), raso * 0.80);
    base = mix(base, vec3(0.74, 0.84, 0.70), smoothstep(1.3, 0.1, fundura) * 0.45);

    // ---- o ceu refletido: quanto mais rasante o olhar, mais ceu e menos agua
    float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
    vec3 olhar = -normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);          // da camera para a agua, no mundo
    float para_o_sol = max(dot(normalize(olhar.xz + vec2(0.0001)), normalize(direcao_sol.xz + vec2(0.0001))), 0.0);
    base = mix(base, cor_reflexo_ceu.rgb, fresnel * (reflexo_geral + reflexo_no_sol * pow(para_o_sol, 5.0)));

    // ---- a renda da espuma vem da textura, em duas escalas que deslizam
    float renda = max(texture(tex_espuma, p * 0.115 + vec2(t * 0.020, -t * 0.014)).r,
                      texture(tex_espuma, p * 0.047 - vec2(t * 0.011, t * 0.008)).r * 0.85);

    // quanto de espuma cada coisa pede (0 a 1), antes de virar renda
    float pedido = smoothstep(0.58, 1.0, crista_fina) * quantidade_espuma * 1.35;      // cristas das ondas

    vec2 q = p - barco_pos;                                                            // em volta do casco
    vec2 lado = vec2(-barco_frente.y, barco_frente.x);
    float ao_longo = dot(q, barco_frente);
    float de_lado = dot(q, lado);
    float e = length(vec2(ao_longo / 4.4, de_lado / 1.55));
    float casco = smoothstep(1.50, 1.10, e) * smoothstep(0.78, 1.02, e);
    pedido = max(pedido, casco * (0.45 + 0.55 * barco_vel));
    float bigode = smoothstep(2.6, 0.0, abs(abs(de_lado) - (4.6 - ao_longo) * 0.62))     // onda de proa
                 * smoothstep(-3.5, 2.5, ao_longo) * smoothstep(6.2, 4.4, ao_longo);
    pedido = max(pedido, bigode * barco_vel * 0.85);

    // ondas quebrando na praia: faixas de espuma que andam para a areia e uma linha fixa na beira
    float vaga = fract(fundura * 0.42 + t * 0.16 + aquarela * 0.8);
    float arrebenta = smoothstep(0.55, 0.95, vaga) * smoothstep(1.0, 0.95, vaga) * smoothstep(3.6, 0.5, fundura) * smoothstep(-0.2, 0.3, fundura);
    pedido = max(pedido, arrebenta * 0.80);
    pedido = max(pedido, smoothstep(0.60, 0.10, fundura) * smoothstep(-0.35, 0.05, fundura) * 0.95);

    float esteira = 0.0;                                                               // rastro: alarga e some
    for (int i = 0; i < 96; i++) {
        vec4 r = rastro[i];
        if (r.w <= 0.0) { continue; }
        float raio = 1.5 + r.z * 0.42;
        float dist = length(p - r.xy);
        float vida = 1.0 - r.z / VIDA_RASTRO;
        esteira = max(esteira, smoothstep(raio, raio * 0.05, dist) * r.w * vida * vida);
    }
    pedido = max(pedido, esteira);
    // agua remexida atras do barco fica mais clara e esverdeada mesmo sem espuma
    base = mix(base, cor_turquesa.rgb * 1.08, esteira * 0.38);

    // a renda aparece onde ha pedido: pouco pedido = so os fios mais fortes; muito = espuma cheia
    float espuma = clamp((renda - (1.0 - pedido)) / 0.34, 0.0, 1.0);
    espuma = max(espuma, smoothstep(0.82, 1.0, pedido));
    espuma *= mix(0.55, 1.0, perto) ;

    // ---- sombra de contato sob o casco
    base *= 1.0 - 0.30 * smoothstep(1.30, 0.70, e);

    base = mix(base, cor_espuma.rgb, espuma);

    // ---- ao longe a agua se desmancha na cor do horizonte (esconde a borda do mar)
    float longe = smoothstep(500.0, 1800.0, distancia);
    base = mix(base, cor_horizonte.rgb, longe * 0.85);

    ALBEDO = base;
    ROUGHNESS = mix(0.44 - brilho * 0.20, 0.85, max(espuma, longe));
    SPECULAR = mix(0.28 + brilho * 0.22, 0.10, espuma);
    METALLIC = 0.0;
    EMISSION = base * (0.04 + 0.10 * espuma) * luz_propria;
}
