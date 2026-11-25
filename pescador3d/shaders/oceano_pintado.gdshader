shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx, shadows_disabled;

// Mar pintado, todo procedural: sem imagens externas e sem costura visivel.
// Cores pensadas para combinar com a pintura artesanal do barco PE-3476.
uniform vec4 cor_profunda : source_color = vec4(0.025, 0.135, 0.215, 1.0);
uniform vec4 cor_media : source_color = vec4(0.035, 0.315, 0.400, 1.0);
uniform vec4 cor_turquesa : source_color = vec4(0.110, 0.560, 0.600, 1.0);
uniform vec4 cor_espuma : source_color = vec4(0.90, 0.96, 0.95, 1.0);
uniform vec4 cor_reflexo_ceu : source_color = vec4(0.66, 0.74, 0.78, 1.0);
uniform vec4 cor_horizonte : source_color = vec4(0.64, 0.70, 0.71, 1.0);

uniform float altura_ondas : hint_range(0.0, 4.5, 0.01) = 1.50;
uniform float velocidade_ondas : hint_range(0.0, 3.0, 0.05) = 0.75;
uniform float quantidade_espuma : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform float agitacao_mar : hint_range(0.0, 1.0, 0.01) = 0.36;
uniform float tempestade_nivel : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float cobertura : hint_range(0.0, 1.0, 0.01) = 0.0;     // ceu coberto (nublado, chuva, temporal): esfria e escurece a agua (enviada por scripts/clima.gd)
uniform float chuva_mar : hint_range(0.0, 1.0, 0.01) = 0.0;     // chuva batendo na agua: aneis de gota e superficie picada (idem)
// Proteção costeira: mesma interpolação em scripts/oceano.gd.
uniform vec2 ilha_centro_a = vec2(1000000.0);
uniform vec2 ilha_centro_b = vec2(1000000.0);
uniform vec2 ilha_centro_c = vec2(1000000.0);
uniform float ilha_raio_a = 0.0;
uniform float ilha_raio_b = 0.0;
uniform float ilha_raio_c = 0.0;
uniform vec3 ilhas_mar[12];                 // v0.5.8: (x, z, raio) de até 12 ilhas
uniform int n_ilhas_mar = 0;
uniform vec2 direcao_vento = vec2(0.84, -0.54);
uniform float brilho : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float brilho_especular : hint_range(0.0, 1.0, 0.01) = 0.38;
uniform float causticas_rasas : hint_range(0.0, 1.0, 0.01) = 0.34;

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
uniform sampler2D tex_costa3 : hint_default_black, repeat_disable, filter_linear;
uniform vec2 costa_centro3 = vec2(0.0);
uniform float costa_lado3 = 0.0;
uniform vec2 costa_faixa = vec2(-12.0, 4.0);         // altura (m) que vale 0 e 1 no mapa
uniform vec4 cor_raso : source_color = vec4(0.20, 0.78, 0.72, 1.0);
uniform float nevoa = 0.0;                           // 0 a 1: fiapos de neblina deitados sobre a agua (a noite)
uniform vec4 cor_nevoa : source_color = vec4(0.36, 0.45, 0.49, 1.0);
uniform float luz_propria = 1.0;                     // a agua se acende um pouco sozinha de dia; a noite, nao

// Enviados por scripts/oceano.gd. O tempo vem do script (e nao de TIME) para o barco
// calcular a mesma onda e subir e descer junto com a agua.
uniform float tempo_mar = 0.0;
uniform float fase_ondas = 0.0;              // v0.5.8: fase acumulada no script (sem salto quando a velocidade muda)
// v0.7.9: deslizamento das texturas de relevo e fase das vagas da costa, também acumulados no script. Antes eram
// "fase * velocidade(agitacao)": no começo e no fim da tempestade a agitação muda e, com a fase já grande, as texturas
// disparavam (o mar parecia correr 3x mais rápido).
uniform vec2 desl_larga = vec2(0.0);
uniform vec2 desl_media = vec2(0.0);
uniform vec2 desl_fina = vec2(0.0);
uniform float fase_vaga = 0.0;
uniform vec2 barco_pos = vec2(0.0);
uniform vec2 barco_frente = vec2(0.0, -1.0);
uniform float barco_vel = 0.0;                 // 0 parado ... 1 velocidade maxima
uniform float barco_sentido = 1.0;             // +1 avante, -1 re; espuma de proa apenas avante
uniform float impacto_proa = 0.0;             // intensidade de contato da onda com a proa (CPU)
uniform vec4 rastro[64];                        // x, z, idade (s), forca (0 = vazio)

const float VIDA_RASTRO = 14.0;

varying vec2 coordenada_mundo;
varying float altura_crista;

// Distancia (m) do ponto ate a costa aproximada da ilha mais proxima.
float dist_costa(vec2 p) {
    float d = 99999.0;
    for (int i = 0; i < n_ilhas_mar; i++) {
        d = min(d, length(p - ilhas_mar[i].xy) - ilhas_mar[i].z);
    }
    return d;
}

float fator_costeiro(vec2 p) {
    return mix(0.27, 1.27, smoothstep(25.0, 250.0, dist_costa(p)));
}

// Deve coincidir com a funcao estatica onda() de scripts/oceano.gd.
// Ondas longas na geometria; marolas submetricas apenas nas normais.
float onda(vec2 p, float t) {
    vec2 w = normalize(direcao_vento);
    vec2 cruz = vec2(-w.y, w.x);
    vec2 swell = normalize(w * 0.75 + cruz * 0.25);
    float grupo = 0.78 + 0.22 * sin(dot(p, w * 0.012) - t * 0.17);
    float longo = 0.60 * sin(dot(p, swell * 0.100) - t * 0.79)
                + 0.32 * sin(dot(p, vec2(-0.047, 0.076)) - t * 0.59 + 1.7);
    float marola = (0.08 + 0.18 * agitacao_mar) * sin(dot(p, w * 0.145) - t * 1.38);
    float cruzada = 0.13 * sin(dot(p, cruz * 0.11 + w * 0.05) - t * 1.11 + 0.8);
    float swell_transversal = 0.12 * agitacao_mar * sin(dot(p, cruz * 0.062 + w * 0.014) - t * 0.54 + 2.3);
    return grupo * longo + marola + cruzada + swell_transversal;
}

// Derivada analitica: mais leve que recalcular a onda 4 vezes por pixel.
vec2 inclinacao_onda(vec2 p, float t) {
    vec2 w = normalize(direcao_vento);
    vec2 cruz = vec2(-w.y, w.x);
    vec2 swell = normalize(w * 0.75 + cruz * 0.25);
    float fase_grupo = dot(p, w * 0.012) - t * 0.17;
    float grupo = 0.78 + 0.22 * sin(fase_grupo);
    float f1 = dot(p, swell * 0.100) - t * 0.79;
    float f2 = dot(p, vec2(-0.047, 0.076)) - t * 0.59 + 1.7;
    float longo = 0.60 * sin(f1) + 0.32 * sin(f2);
    vec2 derivada_longa = 0.60 * cos(f1) * swell * 0.100
                       + 0.32 * cos(f2) * vec2(-0.047, 0.076);
    vec2 derivada_grupo = 0.22 * cos(fase_grupo) * w * 0.012;
    vec2 k4 = cruz * 0.11 + w * 0.05;
    vec2 k5 = cruz * 0.062 + w * 0.014;
    vec2 dh = grupo * derivada_longa + longo * derivada_grupo
             + (0.08 + 0.18 * agitacao_mar) * cos(dot(p, w * 0.145) - t * 1.38) * w * 0.145
             + 0.13 * cos(dot(p, k4) - t * 1.11 + 0.8) * k4
             + 0.12 * agitacao_mar * cos(dot(p, k5) - t * 0.54 + 2.3) * k5;
    // A transição costeira também altera a normal das ondas, não só sua altura.
    float d = 99999.0;
    vec2 radial = vec2(0.0);
    for (int i = 0; i < n_ilhas_mar; i++) {
        float di = length(p - ilhas_mar[i].xy) - ilhas_mar[i].z;
        if (di < d) { d = di; radial = normalize(p - ilhas_mar[i].xy + vec2(0.00001)); }
    }
    float u = clamp((d - 25.0) / 225.0, 0.0, 1.0);
    vec2 df = radial * (6.0 * u * (1.0 - u) / 225.0); // amplitude aumenta de 0.27 para 1.27
    return altura_ondas * (fator_costeiro(p) * dh + onda(p, t) * df);
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

float hash21(vec2 c) {
    return fract(sin(dot(c, vec2(127.1, 311.7))) * 43758.5453);
}

// Aneis de gota de chuva: uma gota por celula, que nasce, abre e some. Devolve a inclinacao (x, z) da superficie.
vec2 gotas_chuva(vec2 p, float tt, float celula) {
    vec2 g = p / celula;
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;
    float h = hash21(id);
    float viva = step(hash21(id + 11.7), chuva_mar);                // quanto maior a chuva, mais celulas com gota
    float fase = fract(tt * (0.75 + 0.6 * h) + h * 9.0);
    vec2 d = f - (vec2(hash21(id + 3.1), hash21(id + 7.7)) - 0.5) * 0.5;
    float r = length(d);
    float x = (r - fase * 0.23) * 34.0;                             // o anel abre ate 0,23 da celula e nao cruza a vizinha
    float anel = x * exp(-x * x) * (1.0 - fase) * (1.0 - fase);
    return d / max(r, 0.001) * anel * viva;
}

void vertex() {
    vec2 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
    float h = onda(p, fase_ondas);
    coordenada_mundo = p;
    altura_crista = h;
    VERTEX.y += h * altura_ondas * fator_costeiro(p);
    NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
    vec2 p = coordenada_mundo;
    float t = fase_ondas;
    float distancia = length(VERTEX);                       // metros ate a camera
    float perto = 1.0 - smoothstep(40.0, 220.0, distancia);  // detalhe fino so perto: longe ele vira chuvisco

    // ---- relevo: ondas grandes (calculadas) + tres camadas de textura deslizando em direcoes diferentes
    vec2 pendente = inclinacao_onda(p, t);
    vec2 vento = normalize(direcao_vento);
    vec2 cruz = vec2(-vento.y, vento.x);
    vec2 n_larga = texture(tex_ondas, p * 0.011 - desl_larga).xy * 2.0 - 1.0;
    vec2 n_media = texture(tex_ondas, p * 0.037 - desl_media).xy * 2.0 - 1.0;
    vec2 n_fina = texture(tex_marolas, p * 0.17 - desl_fina).xy * 2.0 - 1.0;
    vec2 relevo = (n_larga * 0.36 + n_media * 0.41 + n_fina * (0.20 + 0.25 * agitacao_mar) * perto) * forca_relevo;
    if (chuva_mar > 0.001) {
        // chuva: gotas em duas escalas + a superficie picada por gotas miudas (so perto, onde da para ver)
        vec2 gotas = gotas_chuva(p, tempo_mar, 1.9) + gotas_chuva(p + vec2(17.3, 5.1), tempo_mar * 1.13 + 3.0, 3.4) * 0.8;
        relevo += gotas * chuva_mar * perto * 2.0;
        relevo += (texture(tex_marolas, p * 0.55 + vec2(tempo_mar * 0.9, -tempo_mar * 0.7)).xy * 2.0 - 1.0) * 0.16 * chuva_mar * perto;
    }
    vec3 normal_mundo = normalize(vec3(-pendente.x - relevo.x, 1.0, -pendente.y - relevo.y));
    NORMAL = normalize((VIEW_MATRIX * vec4(normal_mundo, 0.0)).xyz);

    // ---- pigmento pintado: manchas de aquarela da textura + tres tons de azul
    float aquarela = texture(tex_pigmento, p * 0.0065 + vec2(t * 0.0015, -t * 0.001)).r;
    float pincelada = texture(tex_pigmento, p * 0.031 + vec2(-t * 0.004, t * 0.003)).r;
    float camada = mix(turbulencia(p * 0.091 + vec2(t * 0.029, -t * 0.017)), aquarela, 0.55);
    float detalhe = mix(turbulencia(p * 0.28 + vec2(-t * 0.11, t * 0.083)), pincelada, 0.5);
    vec3 base = mix(cor_profunda.rgb, cor_media.rgb, smoothstep(0.23, 0.82, camada));
    base = mix(base, cor_turquesa.rgb, smoothstep(0.52, 0.92, detalhe) * 0.36);
    base *= mix(0.90, 1.10, pincelada);
    // profundidade: longe das ilhas o mar e fundo e azul-escuro; perto da costa, a plataforma rasa e mais clara e turquesa
    float d_costa = dist_costa(p);
    float mar_aberto = smoothstep(120.0, 560.0, d_costa);
    float plataforma = 1.0 - smoothstep(10.0, 190.0, d_costa);
    base = mix(base, mix(cor_profunda.rgb, cor_media.rgb, 0.30 + 0.40 * camada) * 1.04, mar_aberto * 0.66);
    // a luz atravessa o alto das ondas: crista mais clara e esverdeada
    float crista_fina = clamp(altura_crista + (n_media.x + n_media.y) * 0.26, -1.0, 1.0);
    float encosta_crista = smoothstep(0.28, 0.95, crista_fina);
    base = mix(base, cor_turquesa.rgb, encosta_crista * (0.30 + 0.20 * agitacao_mar) * (1.0 - 0.60 * mar_aberto));
    // Contraste amplo nas ondas: vales escuros, encostas iluminadas e cristais turquesa.
    // A faixa iluminada atravessa a superficie acompanhando cada ondulacao (nao e textura fixa).
    float faixa_onda = smoothstep(0.18, 0.60, altura_crista) * (1.0 - smoothstep(0.75, 1.05, altura_crista));
    base = mix(base, cor_turquesa.rgb * 1.13, faixa_onda * (0.22 + 0.20 * agitacao_mar) * (1.0 - 0.55 * mar_aberto));
    base = mix(base, cor_raso.rgb * mix(0.86, 1.04, pincelada), plataforma * 0.26);
    base *= mix(0.68, 1.12, smoothstep(-0.78, 0.75, altura_crista));
    float sombra_encosta = clamp(dot(pendente, vento) * 0.70, -0.20, 0.20);
    base *= 1.0 - sombra_encosta;

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
    if (costa_lado3 > 0.0) {
        vec2 uv3 = (p - costa_centro3) / costa_lado3 + 0.5;
        if (uv3.x > 0.0 && uv3.x < 1.0 && uv3.y > 0.0 && uv3.y < 1.0) {
            fundura = -mix(costa_faixa.x, costa_faixa.y, texture(tex_costa3, uv3).r);
        }
    }
    float raso = (1.0 - smoothstep(0.4, 9.0, fundura));
    base = mix(base, cor_raso.rgb * mix(0.92, 1.08, pincelada), raso * 0.80);
    base = mix(base, vec3(0.74, 0.84, 0.70), (1.0 - smoothstep(0.1, 1.3, fundura)) * 0.45);
    // Causticas lentas perto da praia, so onde o fundo e suficientemente raso.
    float raso_visivel = (1.0 - smoothstep(0.8, 6.5, fundura)) * smoothstep(-0.6, 0.4, fundura);
    float malha_luz = texture(tex_espuma, p * 0.095 + vento * t * 0.015).r;
    malha_luz += texture(tex_espuma, p * 0.132 - cruz * t * 0.023).r * 0.65;
    float filamentos = smoothstep(0.86, 1.18, malha_luz);
    base += vec3(0.075, 0.12, 0.085) * filamentos * raso_visivel * causticas_rasas;

    // ---- o ceu refletido: quanto mais rasante o olhar, mais ceu e menos agua
    float fresnel = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
    vec3 olhar = -normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);          // da camera para a agua, no mundo
    float para_o_sol = max(dot(normalize(olhar.xz + vec2(0.0001)), normalize(direcao_sol.xz + vec2(0.0001))), 0.0);
    base = mix(base, cor_reflexo_ceu.rgb, fresnel * (reflexo_geral + reflexo_no_sol * pow(para_o_sol, 5.0)));
    // Trilho brilhante do sol que tremula na geometria das ondas, e nao uma faixa fixa na tela.
    vec3 para_camera = normalize(-olhar);
    vec3 reflexo_fisico = reflect(-normalize(direcao_sol), normal_mundo);
    float alinhamento = clamp(dot(reflexo_fisico, para_camera), 0.0, 1.0);
    float luz_na_agua = pow(alinhamento, mix(110.0, 37.0, agitacao_mar));
    float cintilar = 0.50 + 0.50 * texture(tex_marolas, p * 0.090 - vento * t * 0.065).r;
    float brilho_faixa = luz_na_agua * (0.30 + 0.70 * cintilar) * brilho_especular * (0.25 + 0.75 * reflexo_no_sol);
    base += cor_reflexo_ceu.rgb * brilho_faixa * 0.45;

    // ---- a renda da espuma vem da textura, em duas escalas que deslizam
    float renda = max(texture(tex_espuma, p * 0.115 - vento * t * 0.035).r,
                      texture(tex_espuma, p * 0.047 - (vento - cruz * 0.18) * t * 0.014).r * 0.85);

    // quanto de espuma cada coisa pede (0 a 1), antes de virar renda
    float declive = clamp(length(pendente) * 4.2, 0.0, 1.0);
    // Em temporal, as cristas não viram uma manta branca contínua.
    float pedido = smoothstep(0.63, 1.08, crista_fina) * quantidade_espuma
                 * (0.20 + agitacao_mar * 0.42) * (0.60 + declive * 0.30);

    vec2 q = p - barco_pos;                                                            // em volta do casco
    vec2 lado = vec2(-barco_frente.y, barco_frente.x);
    float ao_longo = dot(q, barco_frente);
    float de_lado = dot(q, lado);
    float e = length(vec2(ao_longo / 4.4, de_lado / 1.55));
    float casco = (1.0 - smoothstep(1.10, 1.50, e)) * smoothstep(0.78, 1.02, e);
    pedido = max(pedido, casco * (0.45 + 0.55 * barco_vel));
    float bigode = (1.0 - smoothstep(0.0, 2.6, abs(abs(de_lado) - (4.6 - ao_longo) * 0.62)))     // onda de proa
                 * smoothstep(-3.5, 2.5, ao_longo) * (1.0 - smoothstep(4.4, 6.2, ao_longo));
    float avante = barco_vel * max(barco_sentido, 0.0);
    pedido = max(pedido, bigode * avante * (0.60 + 0.28 * impacto_proa));
    // Compressão da água ao atingir a proa. Nos temporais a espuma se espalha.
    float proa_espuma = 1.0 - smoothstep(0.85, 3.0 + 1.5 * impacto_proa, length(q - barco_frente * 3.7));
    pedido = max(pedido, proa_espuma * avante * (0.38 + impacto_proa * 0.55));

    // ondas quebrando na praia: faixas de espuma que andam para a areia e uma linha fixa na beira
    float vaga = fract(fundura * 0.36 + fase_vaga + aquarela * 0.28);
    float arrebenta = smoothstep(0.63, 0.92, vaga) * (1.0 - smoothstep(0.92, 1.0, vaga))
                    * (1.0 - smoothstep(0.7, 4.0, fundura)) * smoothstep(-0.3, 0.5, fundura);
    pedido = max(pedido, arrebenta * (0.70 + 0.30 * agitacao_mar));
    pedido = max(pedido, (1.0 - smoothstep(0.10, 0.65, fundura))
                         * smoothstep(-0.35, 0.05, fundura) * 0.90);

    float esteira = 0.0;                                                               // rastro: alarga e some
    // A esteira so e avaliada perto do barco: economiza dezenas de iteracoes ao longe.
    if (length(q) < 135.0) {
    for (int i = 0; i < 64; i++) {
        vec4 r = rastro[i];
        if (r.w <= 0.0) { continue; }
        // Espuma deriva com a corrente e se espalha mais em mar revolto.
        vec2 atual = r.xy + vento * r.z * (0.025 + 0.125 * agitacao_mar);
        float raio = 1.3 + r.z * (0.35 + 0.12 * agitacao_mar);
        // Próximo da popa: espuma esticada no sentido da marcha. Depois: difunde e dissolve.
        vec2 delta_rastro = p - atual;
        float idade = clamp(r.z / VIDA_RASTRO, 0.0, 1.0);
        float longitudinal = dot(delta_rastro, barco_frente) / (raio * mix(1.4, 1.0, idade));
        float transversal = dot(delta_rastro, lado) / (raio * mix(0.72, 1.0, idade));
        float dist_normalizada = length(vec2(longitudinal, transversal));
        float vida = 1.0 - idade;
        esteira = max(esteira, (1.0 - smoothstep(0.22, 1.0, dist_normalizada)) * r.w * vida * vida);
    }
    }
    pedido = max(pedido, esteira);
    // agua remexida atras do barco fica mais clara e esverdeada mesmo sem espuma
    base = mix(base, cor_turquesa.rgb * 1.08, esteira * 0.38);

    // a renda aparece onde ha pedido: pouco pedido = so os fios mais fortes; muito = espuma cheia
    float espuma = clamp((renda - (1.0 - pedido)) / 0.42, 0.0, 1.0);
    espuma = max(espuma, smoothstep(0.87, 1.0, pedido));
    // Bordas irregulares e claras sobre as cristas de ondas maiores: perceptiveis mesmo
    // se a textura de espuma for muito discreta. Em calmaria quase nao quebram.
    float quebra_crista = smoothstep(0.71, 1.18, altura_crista)
                        * smoothstep(0.17, 0.45, length(pendente))
                        * (0.025 + 0.18 * agitacao_mar)
                        * (0.55 + 0.45 * detalhe);
    espuma = max(espuma, quebra_crista);
    // em volta do casco e no rastro a espuma e batida, cheia: manchas macias em vez de fios de renda
    float batida = max(max(casco * (0.45 + 0.55 * barco_vel), bigode * avante * 0.85), esteira * 0.9);
    batida = max(batida, proa_espuma * avante * (0.30 + 0.62 * impacto_proa));
    espuma = max(espuma, smoothstep(0.30, 0.80, batida * (0.40 + 1.15 * detalhe)) * 0.92);
    espuma *= mix(0.44, 0.97, perto);

    // ---- sombra de contato sob o casco
    base *= 1.0 - 0.30 * (1.0 - smoothstep(0.70, 1.30, e));

    // Espuma revela volume: branca na crista, aquecida pela luz e suavizada nas bordas.
    base = mix(base, cor_espuma.rgb, espuma);

    // ---- ao longe a agua se desmancha na cor do horizonte (esconde a borda do mar)
    float longe = smoothstep(500.0 - 260.0 * chuva_mar, 1800.0 - 900.0 * chuva_mar, distancia);     // com chuva o horizonte fecha mais perto
    base = mix(base, cor_horizonte.rgb, longe * 0.85);

    // ---- neblina da noite: um veu baixo sobre a agua, com fiapos mais densos que andam devagar.
    // Fica aqui (e nao so na nevoa do ceu) para aparecer tambem com a camera olhando de cima.
    float veu = 0.0;
    if (nevoa > 0.001) {
        float fiapo = texture(tex_pigmento, p * 0.012 + vec2(t * 0.006, t * 0.004)).r * 0.6
                    + texture(tex_pigmento, p * 0.047 - vec2(t * 0.011, -t * 0.007)).r * 0.4;
        veu = nevoa * (0.22 + 0.78 * smoothstep(0.36, 0.70, fiapo));
        veu *= 1.0 - 0.75 * (1.0 - smoothstep(3.0, 9.0, length(q)));          // a lanterna do barco abre um claro em volta
        base = mix(base, cor_nevoa.rgb, veu * 0.82);
    }

    // Céu carregado escurece a cor sem desligar a espuma do temporal.
    base *= mix(vec3(1.0), vec3(0.67, 0.77, 0.83), tempestade_nivel * 0.78);
    // Ceu coberto (nublado, chuva): a agua perde o verde-turquesa, esfria para cinza-azulado e escurece um pouco.
    float nuvem = clamp(cobertura, 0.0, 1.0);
    float lum = dot(base, vec3(0.299, 0.587, 0.114));
    base = mix(base, vec3(lum) * vec3(0.94, 1.0, 1.03), nuvem * 0.34 * (1.0 - espuma * 0.6));
    base *= 1.0 - 0.12 * nuvem;
    ALBEDO = base;
    ROUGHNESS = mix(mix(0.44 - brilho * 0.20, 0.85, max(espuma, longe)), 1.0, veu);
    SPECULAR = mix(0.28 + brilho * 0.22, 0.10, max(espuma, veu));
    METALLIC = 0.0;
    EMISSION = base * (0.04 + 0.10 * espuma) * luz_propria * (1.0 - 0.5 * nuvem) + cor_nevoa.rgb * veu * 0.30;
}
