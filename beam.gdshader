// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Farın yola düşen ışığı: gerçek ışık yerine toplamalı düzlem (telefonda ucuz). UV.y 0 aracın önü, 1 ışığın ucu;
// araçtan uzaklaştıkça ve kenarlara doğru söner. Gece ve ıslak yolda daha belirgin.
uniform vec3 color : source_color = vec3(1.0, 0.92, 0.8);
uniform float energy = 1.0;
instance uniform float boost = 1.0; // selektör yanıp söner
global uniform float night;
global uniform float wetness;

void fragment() {
	float along = UV.y;
	float side = 1.0 - abs(UV.x - 0.5) * 2.0;
	// geniş ve yumuşak: kenara doğru uzun geçiş, uca doğru yavaş sönüş
	float a = smoothstep(0.0, 0.35, along) * pow(1.0 - along, 1.6) * smoothstep(0.0, 1.0, side) * smoothstep(0.0, 1.0, side);
	// gündüz far yolu aydınlatmaz: plaka gündüz tamamen söner (yoksa açık renkli bir dikdörtgen gibi görünüyordu)
	ALBEDO = color * a * energy * boost * smoothstep(0.3, 0.9, night) * mix(1.0, 1.4, wetness);
}
