shader_type sky;

// Ceu pintado para qualquer hora (as cores vem de scripts/clima.gd): degrade em tres faixas, sol baixo com halo e nuvens de aquarela
// iluminadas por baixo. As nuvens usam a textura de manchas (assets/texturas/mar/pigmento.png).
uniform sampler2D tex_nuvens : hint_default_black, repeat_enable, filter_linear_mipmap;
uniform vec3 cor_topo : source_color = vec3(0.17, 0.27, 0.52);
uniform vec3 cor_meio : source_color = vec3(0.86, 0.46, 0.44);
uniform vec3 cor_horizonte : source_color = vec3(1.0, 0.67, 0.36);
uniform vec3 cor_sol : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 cor_nuvem_luz : source_color = vec3(1.0, 0.60, 0.38);
uniform vec3 cor_nuvem_sombra : source_color = vec3(0.44, 0.31, 0.50);
uniform float quantidade_nuvens : hint_range(0.0, 1.0, 0.01) = 0.55;
uniform float tamanho_sol : hint_range(0.5, 4.0, 0.1) = 1.0;
uniform float estrelas : hint_range(0.0, 1.0, 0.01) = 0.0;      // 1 = noite fechada (e o sol vira lua)

float sorte(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
    vec3 d = normalize(EYEDIR);
    float alto = clamp(d.y, 0.0, 1.0);
    vec3 cor = mix(cor_horizonte, cor_meio, smoothstep(0.0, 0.20, alto));
    cor = mix(cor, cor_topo, smoothstep(0.12, 0.70, alto));

    if (estrelas > 0.01 && d.y > 0.02) {                              // estrelas: pontinhos numa grade torta
        vec2 g = d.xz / (d.y + 0.35) * 46.0;
        vec2 casa = floor(g);
        float s = sorte(casa);
        vec2 centro = casa + 0.5 + (vec2(sorte(casa + 3.1), sorte(casa + 7.7)) - 0.5) * 0.7;
        float ponto = smoothstep(0.09, 0.0, length(g - centro)) * step(0.82, s);
        cor += vec3(0.85, 0.90, 1.0) * ponto * estrelas * (0.5 + 0.5 * sin(TIME * (1.0 + s * 2.0) + s * 40.0)) * smoothstep(0.02, 0.25, d.y);
    }

    float claridade = mix(1.0, 0.35, estrelas);                       // a lua clareia bem menos o ceu
    float para_o_sol = max(dot(d, LIGHT0_DIRECTION), 0.0);
    cor += cor_sol * pow(para_o_sol, 6.0) * 0.30 * claridade;         // claridade larga em volta do sol
    cor += cor_sol * pow(para_o_sol, 60.0) * 0.55 * claridade;        // halo

    if (d.y > 0.005) {                                                // nuvens: um teto plano visto em perspectiva
        vec2 uv = d.xz / (d.y + 0.10);
        float n = texture(tex_nuvens, uv * 0.055 + vec2(TIME * 0.0012, 0.0)).r * 0.62
                + texture(tex_nuvens, uv * 0.19 - vec2(TIME * 0.0020, TIME * 0.0008)).r * 0.38;
        float corte = 0.64 - quantidade_nuvens * 0.24;
        float nuvem = smoothstep(corte, corte + 0.16, n) * smoothstep(0.01, 0.14, d.y);
        float miolo = smoothstep(corte + 0.05, corte + 0.30, n);          // o meio da nuvem e mais escuro
        vec3 cor_nuvem = mix(cor_nuvem_luz, cor_nuvem_sombra, miolo * 0.75);
        cor_nuvem = mix(cor_nuvem, cor_sol, pow(para_o_sol, 4.0) * 0.55); // perto do sol elas acendem
        cor = mix(cor, cor_nuvem, nuvem * 0.88);
        // Cirros altos finos, em escala diferente das nuvens baixas.
        vec2 uv_cirro = d.xz / (d.y + 0.35);
        float cirro_a = texture(tex_nuvens, uv_cirro * 0.31 + vec2(TIME * 0.00065, TIME * 0.00031)).r;
        float cirro_b = texture(tex_nuvens, uv_cirro * 0.56 - vec2(TIME * 0.00043, 0.0)).r;
        float cirros = smoothstep(0.64, 0.86, cirro_a * 0.70 + cirro_b * 0.30);
        cirros *= smoothstep(0.03, 0.21, d.y) * (1.0 - nuvem * 0.55);
        cor = mix(cor, mix(cor_nuvem_luz, cor_sol, pow(para_o_sol, 4.0) * 0.4), cirros * quantidade_nuvens * 0.22);

        // faixas de nuvens baixas, deitadas sobre o horizonte (as que mais aparecem do barco)
        float az = atan(d.x, d.z) / 6.2831853;
        float faixa = texture(tex_nuvens, vec2(az * 3.0 + TIME * 0.0006, d.y * 2.4)).r * 0.60
                    + texture(tex_nuvens, vec2(az * 7.0 - TIME * 0.0009, d.y * 5.5 + 0.3)).r * 0.40;
        float corte_b = 0.60 - quantidade_nuvens * 0.20;
        float baixa = smoothstep(corte_b, corte_b + 0.10, faixa) * smoothstep(0.02, 0.07, d.y) * smoothstep(0.40, 0.18, d.y);
        float miolo_b = smoothstep(corte_b + 0.04, corte_b + 0.20, faixa);
        vec3 cor_baixa = mix(cor_nuvem_luz, cor_nuvem_sombra, 0.25 + miolo_b * 0.6);
        cor_baixa = mix(cor_baixa, cor_sol, pow(para_o_sol, 3.0) * 0.6);
        cor = mix(cor, cor_baixa, baixa * 0.9);
    }

    float raio = 0.99985 - 0.0003 * tamanho_sol;                      // o disco do sol
    cor = mix(cor, mix(vec3(1.0, 0.95, 0.74) * 1.7, vec3(0.86, 0.90, 0.98), estrelas), smoothstep(raio, raio + 0.0002, para_o_sol));

    if (d.y < 0.0) {                                                  // abaixo do horizonte (so aparece em reflexos)
        cor = mix(cor_horizonte, cor_horizonte * 0.55, smoothstep(0.0, -0.3, d.y));
    }
    COLOR = cor;
}
