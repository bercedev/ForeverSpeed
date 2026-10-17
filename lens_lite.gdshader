// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type canvas_item;
render_mode blend_premul_alpha;

// lens.gdshader'ın telefon sürümü: ekranın kopyasını okumaz (her karede tam ekran kopya mobilde çok
// pahalı). Damlalar kırılma yerine koyu kenar + parlak nokta olarak çizilir, hız bulanıklığı yoktur.
// Premultiplied alpha: rgb ekrana eklenen ışık, a altındakini karartma oranı.
uniform float amount : hint_range(0.0, 1.0) = 0.5;
uniform float wet : hint_range(0.0, 1.0) = 1.0;
uniform float speed : hint_range(0.0, 1.0) = 0.0;
uniform float nitro : hint_range(0.0, 1.0) = 0.0;
uniform int taps = 1; // lens.gdshader ile aynı arayüz; burada kullanılmaz
uniform vec3 siren_col : source_color = vec3(1.0, 0.1, 0.1);
uniform float siren_amt = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

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
	vec3 light = vec3(0.0);
	float rim = 0.0;
	// uniform'a bağlı dallar bütün ekranda aynı yöne gider: kapalı efekt hiç hesaplanmaz
	if (wet > 0.01) {
		vec3 a = drops(vec2(uv.x * aspect, uv.y), 12.0, TIME);
		// yolun göründüğü orta-alt bölgede damla az: cam ıslak kalsın ama yol okunsun
		float keep = mix(0.25, 1.0, smoothstep(0.15, 0.45, length((uv - vec2(0.5, 0.6)) * vec2(1.6, 1.0))));
		a.z *= wet * keep;
		rim = a.z * smoothstep(0.55, 1.0, length(a.xy));
		light += vec3(a.z * smoothstep(0.45, 0.0, length(a.xy + 0.4)) * 0.18);
	}
	vec2 dir = uv - vec2(0.5, 0.42);
	float r = length(vec2(dir.x * aspect, dir.y));
	if (speed > 0.01) {
		float h = hash(vec2(floor(atan(dir.y, dir.x) * 70.0), 3.0));
		float seg = step(0.65, fract(r * 2.5 - TIME * (2.5 + 2.0 * h) - h * 7.0));
		light += vec3(0.75, 0.85, 1.0) * step(0.9, h) * seg * smoothstep(0.3, 0.6, r) * speed * 0.25;
	}
	light += vec3(0.3, 0.35, 1.0) * smoothstep(0.35, 0.8, r) * nitro * 0.3;
	light += siren_col * smoothstep(0.55, 1.0, uv.y) * siren_amt * 0.35;
	vec2 v = uv - 0.5;
	float dark = clamp(dot(v, v) * 0.8 + rim * 0.25, 0.0, 1.0); // vinyet + damla kenarı
	COLOR = vec4(light, dark);
}
