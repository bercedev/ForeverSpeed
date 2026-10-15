// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;

// Şehir binası: kutunun yan yüzlerine 3 x 3.5 m'lik pencere ızgarası, rastgele pencereler yanık.
// Kutu BoxMesh.size ile ölçeklenir, model uzayı metre cinsindendir.
instance uniform float seed = 0.0;
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
	vec2 f = abs(ln.x) > 0.5 ? vec2(lp.z, lp.y) : vec2(lp.x, lp.y);
	vec2 cell = f / vec2(3.0, 3.5);
	vec2 id = floor(cell) + vec2(seed * 17.0, ln.x * 31.0 + ln.z * 57.0);
	vec2 g = fract(cell);
	float win = step(0.25, g.x) * step(g.x, 0.75) * step(0.3, g.y) * step(g.y, 0.8) * step(abs(ln.y), 0.5);
	float lit = step(0.62, hash(id));
	vec3 warm = mix(vec3(1.0, 0.72, 0.42), vec3(0.6, 0.75, 1.0), step(0.85, hash(id * 1.7 + 3.1)));
	ROUGHNESS = 0.6;
	ALBEDO = mix(vec3(0.03, 0.035, 0.045), vec3(0.12, 0.13, 0.15), 1.0 - night) + vec3(0.08) * win * (1.0 - night); // gündüz cam ve beton
	EMISSION = warm * win * lit * 1.6 * mix(0.1, 1.0, night);
}
