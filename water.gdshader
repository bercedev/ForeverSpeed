// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;

// Gece suyu: koyu, çok parlak; hareketli dalga normali lamba ışıklarını kırpıştırır. Dalga tepelerinde ay
// pırıltısı ve uzak kıyı ışıklarının titreyen yansımaları kendi ışığıyla parlar: köprüden bakınca deniz seçilsin.
// Desen dünya koordinatında: parçalar arasında kesintisiz.
uniform vec3 color : source_color = vec3(0.012, 0.03, 0.055);
global uniform float night;

varying vec2 p;

float hash(vec2 q) {
	q = fract(q * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

float noise(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 q = p * 0.35 + vec2(TIME * 0.15, TIME * 0.25);
	float a = noise(q) - 0.5;
	float b = noise(q * 2.1 + 7.0) - 0.5;
	float glint = pow(noise(p * 1.7 + vec2(TIME * 0.9, -TIME * 0.6)), 14.0) * 4.0; // ay pırıltısı
	// uzak ışıkların suda sütun sütun titreyen yansıması
	float id = floor(p.x / 7.0);
	float band = step(0.8, hash(vec2(id, 1.0))) * smoothstep(0.5, 0.0, abs(fract(p.x / 7.0) - 0.5) * 2.0 - 0.3);
	vec3 lc = mix(vec3(1.0, 0.6, 0.3), vec3(0.45, 0.65, 1.0), hash(vec2(id, 2.0)));
	float shimmer = 0.4 + 0.6 * noise(vec2(p.x * 0.9, p.y * 0.2 + TIME * 0.7));
	ALBEDO = color * mix(3.0, 1.0, night);
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	NORMAL_MAP = vec3(0.5 + a * 0.7, 0.5 + b * 0.7, 1.0);
	EMISSION = (vec3(0.55, 0.65, 0.85) * glint + lc * band * shimmer * 0.5) * mix(0.15, 1.0, night)
		+ vec3(0.008, 0.02, 0.035) * night; // ay ışığında hafif lacivert
}
