// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;
render_mode cull_disabled;

// Palet dokulu araba modelleri (R34 ve Kenney). Paletteki dikdörtgenler (u0, v0, u1, v1):
// tail_uv stop lambası rengi, kendi ışığıyla parlar; paint_uv gövde boyası, garajda seçilen renge boyanır.
// R34: dokunun üst şeridi renk kareleri, v > body_v gövde. Kenney: body_v = 0, hepsi boya sayılır.
uniform sampler2D albedo_tex : source_color;
uniform float tail_energy = 4.0;
uniform vec4 tail_uv = vec4(0.75, 0.0, 0.875, 0.125);
uniform float body_v = 0.125;
uniform vec4 paint_uv = vec4(0.0, 0.125, 1.0, 1.0);
uniform vec3 paint : source_color = vec3(1.0);
uniform float use_paint = 0.0;

float inside(vec2 uv, vec4 r) {
	return step(r.x, uv.x) * step(uv.x, r.z) * step(r.y, uv.y) * step(uv.y, r.w);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float body = step(body_v, UV.y);
	// boyada orijinal tonun parlaklığı korunur, renk değişir
	vec3 alb = mix(c, paint * max(c.r, max(c.g, c.b)), inside(UV, paint_uv) * use_paint);
	ALBEDO = alb;
	ROUGHNESS = mix(0.5, 0.25, body);
	METALLIC = 0.3 * body;
	EMISSION = c * inside(UV, tail_uv) * tail_energy;
}
