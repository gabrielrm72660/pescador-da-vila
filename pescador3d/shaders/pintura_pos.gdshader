shader_type canvas_item;
// Pós-processamento "pintura" (painel Cinema): filtro Kuwahara (cada pixel vira a média da vizinhança mais uniforme, como pinceladas
// de aquarela), mais vinheta e grão leves. Roda sobre a imagem 3D já pronta, abaixo da interface. Raio 0 e vinheta/grão 0 = desligado.
uniform sampler2D tela : hint_screen_texture, repeat_disable, filter_linear;
uniform int raio : hint_range(0, 6) = 3;
uniform float mistura : hint_range(0.0, 1.0) = 0.8;
uniform float vinheta : hint_range(0.0, 1.0) = 0.25;
uniform float grao : hint_range(0.0, 0.1) = 0.02;
uniform float tempo = 0.0;

float luz(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float ruido(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 original = texture(tela, SCREEN_UV).rgb;
	vec3 cor = original;
	if (raio > 0) {
		vec2 px = SCREEN_PIXEL_SIZE;
		vec3 media[4];
		float var_[4];
		for (int q = 0; q < 4; q++) {
			media[q] = vec3(0.0);
			var_[q] = 0.0;
		}
		float n = float((raio + 1) * (raio + 1));
		for (int j = -raio; j <= raio; j++) {
			for (int i = -raio; i <= raio; i++) {
				vec3 c = texture(tela, SCREEN_UV + vec2(float(i), float(j)) * px).rgb;
				float l = luz(c);
				// quatro quadrantes que se sobrepõem na linha central: cima-esquerda, cima-direita, baixo-esquerda, baixo-direita
				if (i <= 0 && j <= 0) { media[0] += c; var_[0] += l * l; }
				if (i >= 0 && j <= 0) { media[1] += c; var_[1] += l * l; }
				if (i <= 0 && j >= 0) { media[2] += c; var_[2] += l * l; }
				if (i >= 0 && j >= 0) { media[3] += c; var_[3] += l * l; }
			}
		}
		float melhor = 1e9;
		vec3 escolhida = original;
		for (int q = 0; q < 4; q++) {
			vec3 m = media[q] / n;
			float v = var_[q] / n - pow(luz(m), 2.0);
			if (v < melhor) {
				melhor = v;
				escolhida = m;
			}
		}
		cor = mix(original, escolhida, mistura);
	}
	if (vinheta > 0.0) {
		vec2 d = SCREEN_UV - vec2(0.5);
		cor *= 1.0 - vinheta * smoothstep(0.35, 0.95, length(d * vec2(1.25, 1.0)) * 1.4);
	}
	if (grao > 0.0) {
		cor += (ruido(FRAGCOORD.xy + vec2(tempo * 61.0, tempo * 37.0)) - 0.5) * grao;
	}
	COLOR = vec4(cor, 1.0);
}
