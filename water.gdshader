// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;

// Gece suyu: koyu, çok parlak; hareketli dalga normali lamba ışıklarını kırpıştırır.
uniform vec3 color : source_color = vec3(0.01, 0.018, 0.035);

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
	p = VERTEX.xz;
}

void fragment() {
	vec2 q = p * 0.35 + vec2(TIME * 0.15, TIME * 0.25);
	float a = noise(q) - 0.5;
	float b = noise(q * 2.1 + 7.0) - 0.5;
	ALBEDO = color;
	ROUGHNESS = 0.08;
	SPECULAR = 0.8;
	NORMAL_MAP = vec3(0.5 + a * 0.5, 0.5 + b * 0.5, 1.0);
}
