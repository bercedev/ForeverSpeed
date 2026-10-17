// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;
render_mode cull_disabled;

// Tekerlek: lastik dokunun koyu yeri, jant açık yeri. Jantın rengi ve kaplaması garajda seçilir;
// açık texeller (jant) boyanır, koyular (lastik) olduğu gibi kalır. Hem Kenney paleti hem R34 dokusunda çalışır.
uniform sampler2D albedo_tex : source_color;
uniform vec3 rim_col : source_color = vec3(0.8);
uniform int rim_fin = 0; // 0 orijinal, 1 krom, 2 mat, 3 metalik, 4 neon

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float lum = max(c.r, max(c.g, c.b));
	float rim = smoothstep(0.4, 0.5, lum) * step(0.5, float(rim_fin));
	ALBEDO = mix(c, rim_col * (0.65 + 0.35 * lum), rim);
	METALLIC = mix(0.2, rim_fin == 2 ? 0.0 : 0.9, rim);
	ROUGHNESS = mix(0.6, rim_fin == 1 ? 0.08 : (rim_fin == 2 ? 0.8 : 0.3), rim);
	EMISSION = rim_fin == 4 ? rim_col * rim * 0.9 : vec3(0.0);
}
