// Vento compartilhado pelas folhagens (árvores, moitas, palmeiras). Valores mantidos por scripts/vento.gd.
global uniform float vento_forca;     // 0 = calmaria, 1 = temporal
global uniform vec2 vento_dir;        // para onde o vento sopra (plano X/Z do mundo)

// Deslocamento, em metros no MUNDO, de um ponto da folhagem.
//   t      tempo (TIME do shader)
//   mundo  posição do ponto no mundo
//   peso   0..1: quanto o ponto se solta do chão (0 = pé do tronco, 1 = ponta da copa)
//   folha  0..1: quanto ele treme rápido, como folha
//   porte  tamanho do objeto no mundo (m): árvore grande balança mais em metros
vec3 vento_desloc(float t, vec3 mundo, float peso, float folha, float porte) {
    float f = clamp(vento_forca, 0.0, 1.0);
    vec2 d = vento_dir;
    float comp = length(d);
    d = comp > 0.001 ? d / comp : vec2(1.0, 0.0);
    float ao_longo = dot(mundo.xz, d);
    float vel = 0.7 + 1.6 * f;
    // rajadas: ondas lentas que atravessam a ilha no sentido do vento (as árvores vizinhas não balançam em uníssono)
    float rajada = 0.55 * sin(ao_longo * 0.05 - t * vel)
                 + 0.30 * sin(ao_longo * 0.13 - t * vel * 1.9 + 1.7)
                 + 0.15 * sin(dot(mundo.xz, vec2(0.37, 0.21)) + t * 1.1);
    float inclina = f * 0.55 + (0.05 + 0.40 * f) * rajada;          // dobra a favor do vento + vai e vem
    float lado = sin(t * (1.3 + 1.2 * f) + dot(mundo.xz, vec2(0.23, -0.31))) * (0.03 + 0.12 * f);
    vec2 perp = vec2(-d.y, d.x);
    vec2 h = (d * inclina + perp * lado) * peso * porte * 0.09;
    float tremor_x = sin(t * (6.0 + 5.0 * f) + mundo.x * 1.7 + mundo.z * 2.3 + mundo.y * 3.1);
    float tremor_z = sin(t * (7.0 + 4.0 * f) + mundo.z * 2.9 - mundo.y * 1.3);
    vec2 tre = vec2(tremor_x, tremor_z) * folha * (0.015 + 0.08 * f);
    return vec3(h.x + tre.x, -abs(inclina) * peso * porte * 0.012, h.y + tre.y);
}
