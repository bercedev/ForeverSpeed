// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;

// Şehir binası: kutunun yan yüzlerine pencere ızgarası, kat döşemesi çizgileri, zemin katta dükkân vitrinleri,
// çatıda koyu parapet. Tohuma göre iki cephe: beton (seyrek pencere) ya da cam giydirme (sık panel, parlak).
// Kutu BoxMesh.size ile ölçeklenir, model uzayı metre cinsindendir.
instance uniform float seed = 0.0;
instance uniform float h = 30.0; // bina yüksekliği: zemin katı ve çatı için
global uniform float night; // gündüz pencere ışıkları söner

varying vec3 lp;
varying vec3 ln;

float hash(vec2 q) {
	q = fract(q * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	float side = step(abs(ln.y), 0.5); // çatı değil
	float y = lp.y + h * 0.5; // zeminden yükseklik
	float glass = step(0.6, hash(vec2(seed, 1.7)));
	vec2 f = abs(ln.x) > 0.5 ? vec2(lp.z, lp.y) : vec2(lp.x, lp.y);
	vec2 cs = mix(vec2(3.0, 3.5), vec2(1.6, 3.5), glass);
	vec2 cell = f / cs;
	vec2 id = floor(cell) + vec2(seed * 17.0, ln.x * 31.0 + ln.z * 57.0);
	vec2 g = fract(cell);
	float win = mix(step(0.25, g.x) * step(g.x, 0.75) * step(0.3, g.y) * step(g.y, 0.8),
		step(0.06, g.x) * step(g.x, 0.94) * step(0.1, g.y) * step(g.y, 0.9), glass) * side;
	float upper = step(4.5, y) * (1.0 - step(h - 0.8, y));
	float slab = (1.0 - step(0.08, g.y)) * side; // kat döşemesi
	float lit = step(mix(0.62, 0.7, glass), hash(id)) * upper;
	float tv = step(0.97, hash(id * 2.3)) * (0.6 + 0.4 * sin(TIME * 7.0 + seed * 5.0)) * upper; // televizyon ışığı
	vec3 warm = mix(vec3(1.0, 0.72, 0.42), vec3(0.6, 0.75, 1.0), step(0.85, hash(id * 1.7 + 3.1)));
	// zemin kat vitrinleri: 5 m'lik dükkânlar, her biri kendi renginde
	float sid = floor(f.x / 5.0) + seed * 13.0;
	float shop = step(0.6, y) * step(y, 3.3) * step(0.08, fract(f.x / 5.0)) * step(fract(f.x / 5.0), 0.92) * side * step(0.25, hash(vec2(sid, 4.0)));
	vec3 shop_col = mix(mix(vec3(1.0, 0.75, 0.45), vec3(0.4, 0.9, 1.0), step(0.6, hash(vec2(sid, 5.0)))), vec3(1.0, 0.3, 0.7), step(0.85, hash(vec2(sid, 6.0))));
	float roof = step(h - 0.8, y) * side;
	vec3 wall = mix(mix(vec3(0.03, 0.035, 0.045), vec3(0.12, 0.13, 0.15), 1.0 - night), vec3(0.015, 0.03, 0.05), glass);
	wall *= 1.0 - slab * 0.4 - roof * 0.5;
	ROUGHNESS = mix(0.7, 0.12, glass * win);
	METALLIC = 0.5 * glass * win;
	ALBEDO = wall + vec3(0.08) * win * (1.0 - night) * (1.0 - glass); // gündüz cam ve beton
	EMISSION = (warm * lit * win * 1.6 + vec3(0.35, 0.5, 1.0) * tv * win + shop_col * shop * 1.4) * mix(0.1, 1.0, night);
}
