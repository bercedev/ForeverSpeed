// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// Islak yol yansıması hilesi: ışığın altından kameraya doğru uzayan parlak şerit.
// Mesh yere yatık PlaneMesh; UV.y = 0 ışık tarafı.
uniform vec3 color : source_color = vec3(1.0, 0.4, 0.1);
uniform float energy = 1.0;
uniform float fade = 0.012; // uzaklıkla sönme, sisle uyumlu
global uniform float wetness; // kuru yolda yansıma zayıflar
global uniform float night; // gündüz yansımalar söner

void fragment() {
	float wob = sin(UV.y * 40.0 - TIME * 3.0) * 0.06 * UV.y;
	float side = 1.0 - clamp(abs((UV.x + wob) * 2.0 - 1.0), 0.0, 1.0);
	float along = 1.0 - UV.y;
	ALBEDO = color * energy;
	ALPHA = side * side * along * along * exp(-length(VERTEX) * fade) * mix(0.15, 1.0, wetness) * mix(0.3, 1.0, night);
}
