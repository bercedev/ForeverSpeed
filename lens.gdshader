// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type canvas_item;

// Kameradaki yağmur damlaları: her damla arkasındaki görüntüyü ters çevirip bulanık kırar.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear; // mipmap'siz: telefonda her kare tüm ekranın mipmap'ini üretmesin
uniform float amount : hint_range(0.0, 1.0) = 0.5; // damla yoğunluğu
uniform float wet : hint_range(0.0, 1.0) = 1.0; // tünelde 0'a iner, damlalar söner
uniform float speed : hint_range(0.0, 1.0) = 0.0; // hız hissi: kenar bulanıklığı ve hız çizgileri
uniform float nitro : hint_range(0.0, 1.0) = 0.0; // nitro: kenarlar mor-mavi parlar
uniform int taps = 6; // hız bulanıklığı örnek sayısı; düşük grafikte 1 (kapalı)
uniform vec3 siren_col : source_color = vec3(1.0, 0.1, 0.1);
uniform float siren_amt = 0.0; // arkadan siren yaklaşınca ekranın altı kırmızı-mavi yanar

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// xy: damla içindeki konum (-1..1), z: maske
vec3 drops(vec2 uv, float cells, float t) {
	vec2 g = uv * cells;
	vec2 id = floor(g);
	float n = hash(id);
	if (n > amount) {
		return vec3(0.0);
	}
	vec2 c = (vec2(hash(id + 7.1), hash(id + 3.7)) - 0.5) * 0.6;
	float life = fract(t * (0.1 + 0.15 * n) + n * 7.0);
	float r = mix(0.08, 0.25, hash(id + 1.3)) * smoothstep(0.0, 0.08, life);
	vec2 d = fract(g) - 0.5 - c;
	float m = smoothstep(r, r * 0.7, length(d * vec2(1.0, 0.85)));
	m *= 1.0 - smoothstep(0.75, 1.0, life);
	return vec3(d / max(r, 0.001), m);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 auv = vec2(uv.x * aspect, uv.y);
	vec3 a = drops(auv, 10.0, TIME);
	vec3 b = drops(auv + vec2(0.31, 0.57), 22.0, TIME * 1.3 + 4.0);
	a.z *= wet;
	b.z *= wet;

	vec2 off = a.xy * a.z * 0.05 + b.xy * b.z * 0.025;
	off.x /= aspect;
	float m = max(a.z, b.z);

	// Hız hissi: kenarlar ufuk noktasından dışa doğru bulanır, ortası net kalır.
	vec2 dir = uv - vec2(0.5, 0.42);
	float r = length(vec2(dir.x * aspect, dir.y));
	float blur = speed * smoothstep(0.12, 0.6, r) * 0.05;
	int n = speed > 0.01 ? taps : 1;
	vec3 col = vec3(0.0);
	for (int i = 0; i < n; i++) {
		col += textureLod(screen_tex, uv - off - dir * blur * float(i) / 5.0, 0.0).rgb;
	}
	col /= float(n);

	float rim = max(a.z * smoothstep(0.55, 1.0, length(a.xy)), b.z * smoothstep(0.55, 1.0, length(b.xy)));
	col = mix(col, col * 0.6, rim * 0.4);
	// sol üstte küçük parlama: damla ışığı yakalasın
	float hl = a.z * smoothstep(0.45, 0.0, length(a.xy + 0.4)) + b.z * smoothstep(0.45, 0.0, length(b.xy + 0.4));
	col += hl * 0.12;

	// Hız çizgileri: kenarlarda dışa kayan ince ışık parçaları.
	float h = hash(vec2(floor(atan(dir.y, dir.x) * 70.0), 3.0));
	float seg = step(0.65, fract(r * 2.5 - TIME * (2.5 + 2.0 * h) - h * 7.0));
	col += vec3(0.75, 0.85, 1.0) * step(0.9, h) * seg * smoothstep(0.3, 0.6, r) * speed * 0.25;
	col += siren_col * smoothstep(0.55, 1.0, uv.y) * siren_amt * 0.35;

	col += vec3(0.3, 0.35, 1.0) * smoothstep(0.35, 0.8, r) * nitro * 0.3;

	vec2 v = uv - 0.5;
	col *= 1.0 - dot(v, v) * 0.8;
	COLOR = vec4(col, 1.0);
}
