// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type sky;

// Gökyüzü: ufuktan tepeye renk geçişi, gece yıldızlar, gündüz güneş, bulutlar. cover yağmurda/karda bulutu
// kalınlaştırıp koyulaştırır. Işık hesabı (ortam, yansıma) gökyüzünü kullanmaz: yalnız arka plan çizilir.
// TIME kullanılmaz: bulut kayması main.gd'den gelir, gökyüzü her karede ışık haritası yeniden üretmesin.
uniform vec3 horizon : source_color = vec3(0.03, 0.045, 0.08);
uniform vec3 zenith : source_color = vec3(0.01, 0.015, 0.035);
uniform float night = 1.0;
uniform float cover = 0.5; // 0 açık, 1 kapalı
uniform vec3 sun_dir = vec3(0.0, 0.5, -1.0);
uniform float sun_amt = 0.0;
uniform vec2 cloud_off = vec2(0.0);
uniform float flash = 0.0; // şimşek

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// Bulut gürültüsü için sinüssüz hash: sin(büyük sayı) * 43758 komşu hücrelerin ortak köşesine yuvarlama
// farkıyla iki ayrı değer veriyor, gökte düz kenarlı dikişler çıkıyordu.
float hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash2(i);
	float b = hash2(i + vec2(1.0, 0.0));
	float c = hash2(i + vec2(0.0, 1.0));
	float d = hash2(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, -0.2, 1.0);
	vec3 col = mix(horizon, zenith, smoothstep(0.0, 0.6, up));
	// yıldızlar: yön küresinde hücreler, binde birkaçı parlar; bulut ve ufuk sisi örter
	if (night > 0.05 && d.y > 0.0) {
		vec3 sp = d * 240.0;
		vec3 id = floor(sp);
		float r = hash3(id);
		float star = step(0.9965, r) * smoothstep(0.5, 0.05, length(fract(sp) - 0.5)) * (0.5 + 0.5 * hash3(id + 7.0));
		col += vec3(0.9, 0.93, 1.0) * star * night * smoothstep(0.02, 0.25, d.y) * 2.0;
	}
	// güneş: keskin disk ve geniş hale; bulut kalınlaştıkça söner
	float sd = max(dot(d, normalize(sun_dir)), 0.0);
	col += vec3(1.0, 0.85, 0.6) * (pow(sd, 900.0) * 25.0 + pow(sd, 10.0) * 0.35) * sun_amt * (1.0 - cover * 0.9);
	// bulutlar: gökyüzünü bir düzleme yansıtıp kıvrımlı gürültü
	if (d.y > 0.0) {
		vec2 uv = d.xz / (d.y + 0.12) * 0.55 + cloud_off;
		float n = fbm(uv);
		float c = smoothstep(0.62 - cover * 0.5, 0.9 - cover * 0.35, n) * smoothstep(0.0, 0.12, d.y);
		vec3 lit = mix(vec3(0.92, 0.93, 0.96), vec3(0.45, 0.47, 0.52), cover); // açıkta beyaz, yağmurda gri
		vec3 cc = lit * mix(1.0, 0.08, night) + horizon * 0.3;
		col = mix(col, cc, c * mix(0.85, 1.0, cover));
	}
	col += vec3(0.6, 0.65, 0.85) * flash;
	COLOR = col;
}
