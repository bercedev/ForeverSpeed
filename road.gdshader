// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;

// Islak asfalt ve şerit çizgileri. Yol mesh'i sabit durur, desen `offset` ile kayar.
// Bütün desenler 900 m'de tekrar eder; main.gd offset'i 900'de sarar, atlama görünmez.
uniform float offset = 0.0;
global uniform float wetness; // hava durumu: 1 sırılsıklam, 0 kuru

varying vec2 p;

float hash(vec2 q) {
	q = fract(q * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

// Değer gürültüsü; cell 900'ü tam bölmeli.
float noise(vec2 q, float cell) {
	vec2 g = q / cell;
	vec2 i = floor(g);
	vec2 f = fract(g);
	f = f * f * (3.0 - 2.0 * f);
	float per = 900.0 / cell;
	float y0 = mod(i.y, per);
	float y1 = mod(i.y + 1.0, per);
	float a = hash(vec2(i.x, y0));
	float b = hash(vec2(i.x + 1.0, y0));
	float c = hash(vec2(i.x, y1));
	float d = hash(vec2(i.x + 1.0, y1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float line(float x, float center, float w) {
	float aa = fwidth(x);
	return 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, abs(x - center));
}

void vertex() {
	p = VERTEX.xz;
}

void fragment() {
	vec2 q = vec2(p.x, p.y - offset);
	float x = q.x;

	float dz = fract(q.y / 9.0);
	float dash = smoothstep(0.0, 0.02, dz) * (1.0 - smoothstep(0.4, 0.42, dz));
	// 4 şerit: ortada çift sarı (karşı yön ayrımı), her yönde şerit arası kesikli beyaz, kenarlarda düz beyaz
	float white = max((line(x, -3.5, 0.14) + line(x, 3.5, 0.14)) * dash, max(line(x, -7.0, 0.16), line(x, 7.0, 0.16)));
	float yellow = max(line(x, -0.15, 0.12), line(x, 0.15, 0.12));

	float puddle = smoothstep(0.45, 0.75, noise(q, 4.0) * 0.7 + noise(q, 1.5) * 0.3) * wetness;
	float grain = hash(vec2(floor(x * 30.0), mod(floor(q.y * 30.0), 27000.0)));

	vec3 asphalt = vec3(0.035, 0.037, 0.042) * (0.8 + 0.4 * grain);
	asphalt *= mix(1.0, 0.6, puddle);
	asphalt *= mix(1.0, 0.85, wetness); // ıslak asfalt koyulaşır
	asphalt = mix(asphalt, vec3(0.02, 0.022, 0.02), smoothstep(7.3, 7.5, abs(x)));

	vec3 col = mix(asphalt, vec3(0.8), white * 0.85);
	col = mix(col, vec3(0.85, 0.6, 0.1), yellow);

	ALBEDO = col;
	ROUGHNESS = mix(mix(mix(0.75, 0.35, wetness), 0.12, puddle), 0.5, max(white, yellow));
	SPECULAR = 0.6;
	EMISSION = vec3(0.9, 0.6, 0.1) * yellow * 0.08 + vec3(white * 0.03);
}
