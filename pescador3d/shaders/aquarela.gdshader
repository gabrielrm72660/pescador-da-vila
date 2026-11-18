shader_type canvas_item;
// Lavagem de aquarela para a interface (v0.5.5). Um retângulo (ou círculo) de pigmento sobre papel:
//  - contorno irregular, com a ondulação do pincel e, nas pontas, estrias de pincel seco;
//  - pigmento que se acumula na borda (borda mais escura, "wet edge");
//  - variação de cor entre dois tons, manchas claras com anel escuro ("flores" de aquarela);
//  - granulação do papel, pontos de sal e respingos soltos perto da borda;
//  - fio de nanquim quebrado, opcional.
// Cada lavagem é um ColorRect com este material; "tam" é o tamanho dele em pixels e "margem" é a folga entre a borda
// do ColorRect e a forma pintada (onde a tinta pode escorrer e os respingos caem).

uniform vec2 tam = vec2(240.0, 80.0);
uniform float margem = 22.0;
uniform vec4 cor : source_color = vec4(0.09, 0.27, 0.35, 1.0);
uniform vec4 cor2 : source_color = vec4(0.04, 0.15, 0.25, 1.0);
uniform float alfa : hint_range(0.0, 1.0) = 0.90;
uniform float raio = 14.0;                       // raio dos cantos; um valor grande vira círculo
uniform float semente = 1.0;
uniform float irregular : hint_range(0.0, 20.0) = 5.0;
uniform float borda : hint_range(0.0, 1.0) = 0.40;
uniform float largura_borda = 9.0;
uniform float grao : hint_range(0.0, 0.6) = 0.16;
uniform float seco : hint_range(0.0, 1.0) = 0.55;
uniform float respingos : hint_range(0.0, 1.0) = 0.5;
uniform float brilho : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tinta : source_color = vec4(0.03, 0.07, 0.11, 0.0);   // alfa 0 = sem fio de nanquim
uniform float papel : hint_range(0.0, 1.0) = 0.0;                  // 1 = folha de papel (mais opaca, com fibras)

varying vec2 pos;

void vertex() {
	pos = VERTEX;
}

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float ruido(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * ruido(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s;
}

float caixa(vec2 p, vec2 meia, float r) {
	vec2 q = abs(p) - (meia - vec2(r));
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = pos - tam * 0.5;
	vec2 meia = max(tam * 0.5 - vec2(margem), vec2(2.0));
	float r = clamp(raio, 0.0, min(meia.x, meia.y));
	float s = semente * 37.7;

	// contorno: ondulação do pincel (baixa frequência) e tremida da mão (média)
	float onda = fbm(pos * 0.040 + s) - 0.5;
	float tremida = ruido(pos * 0.17 + s * 1.7) - 0.5;
	float d = caixa(p, meia, r) + onda * irregular * 2.2 + tremida * irregular * 0.6;

	// pincel seco nas pontas: cada estria horizontal recua um pouco, como cerdas
	float cerda = ruido(vec2(pos.x * 0.028 + s, pos.y * 0.85 + s * 2.0));
	float ponta = smoothstep(0.50, 1.0, abs(p.x) / meia.x);
	d += seco * (cerda - 0.35) * 26.0 * ponta;

	float massa = 1.0 - smoothstep(-0.8, 1.4, d);

	// pigmento
	float prof = clamp(-d / largura_borda, 0.0, 1.0);
	float acumula = (1.0 - prof) * (1.0 - prof) * borda;                 // a tinta junta na borda
	float nuvem = fbm(pos * 0.017 + s * 0.5);
	float flor = fbm(pos * 0.030 + s * 3.1);
	float miolo = smoothstep(0.56, 0.64, flor);                           // mancha clara
	float anel = smoothstep(0.50, 0.56, flor) - smoothstep(0.56, 0.62, flor);   // beirada escura da mancha
	vec3 col = mix(cor.rgb, cor2.rgb, smoothstep(0.28, 0.78, nuvem));
	col *= 1.0 - acumula * 0.85;
	// no papel as manchas quase somem: só uma variação de tom, nada de buracos brancos com anel escuro
	float suave = 1.0 - papel * 0.88;
	col = mix(col, col * 1.30 + vec3(0.035), miolo * 0.55 * suave);
	col *= 1.0 - anel * 0.22 * suave;

	// papel: grão fino, fibras e sal
	float g = ruido(pos * 1.2 + s) * 0.55 + ruido(pos * 2.7 + s * 2.0) * 0.45;
	float fibra = ruido(vec2(pos.x * 0.35 + s, pos.y * 0.05 + s * 3.0));
	col *= 1.0 + (g - 0.5) * grao * 2.0;
	col *= 1.0 + (fibra - 0.5) * papel * 0.10;
	float sal = smoothstep(0.84, 0.90, ruido(pos * 0.9 + s * 4.0)) * grao * 2.2;

	float a = alfa * massa;
	a *= 0.86 + 0.14 * nuvem + acumula * 0.30 + (g - 0.5) * grao;
	a *= 1.0 - sal * 0.55;
	a *= 1.0 - miolo * 0.12 * (1.0 - papel);
	a = mix(a, massa * alfa, papel * 0.6);

	// fio de nanquim, um pouco para dentro da borda e interrompido
	float fio = (1.0 - smoothstep(0.0, 1.6, abs(d + 3.0))) * smoothstep(0.30, 0.55, ruido(pos * 0.22 + s * 5.0));
	col = mix(col, tinta.rgb, fio * tinta.a);
	a = max(a, fio * tinta.a * 0.85);

	// respingos soltos perto da borda
	if (respingos > 0.0) {
		vec2 cel = floor(pos / 15.0);
		float h = hash(cel + s);
		vec2 centro = (cel + vec2(hash(cel + 1.7 + s), hash(cel + 3.1 + s))) * 15.0;
		float rg = 0.9 + 2.6 * hash(cel + 9.0 + s);
		float gota = step(1.0 - 0.09 * respingos, h) * (1.0 - smoothstep(rg * 0.6, rg, length(pos - centro)));
		float perto = smoothstep(1.5, 5.0, d) * (1.0 - smoothstep(9.0, 20.0, d));
		float ag = gota * perto * alfa * 0.55;
		col = mix(col, cor2.rgb * 0.9, ag / max(a + ag, 0.001));
		a = max(a, ag);
	}

	col = mix(col, vec3(1.0), brilho * 0.14);
	a = clamp(a + brilho * 0.05 * massa, 0.0, 1.0);
	COLOR = vec4(col, a);
}
