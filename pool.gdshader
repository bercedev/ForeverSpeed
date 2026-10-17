// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Sokak lambasının yola düşen ışığı: gerçek ışık yerine toplamalı yuvarlak leke (düşük grafikte de görünür,
// gerçek ışık yalnız bazı lambalarda ve orta-yüksek grafikte var). Yalnız gece; ıslak yolda daha parlak.
uniform vec3 color : source_color = vec3(1.0, 0.55, 0.2);
global uniform float night;
global uniform float wetness;

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.6);
	ALBEDO = color * a * 0.65 * smoothstep(0.3, 0.9, night) * mix(1.0, 1.5, wetness);
}
