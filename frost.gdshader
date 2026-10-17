// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type canvas_item;

// Buzlu cam: panelin arkasındaki görüntü bulanık ve koyulaşmış görünür, panel rengiyle karışır. Köşe
// yuvarlaklığı ve kenar çizgisi paneldeki StyleBox'tan gelir. Yalnız garajda kullanılır.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 3.2; // mip seviyesi: yükseldikçe daha bulanık

void fragment() {
	vec3 behind = textureLod(screen, SCREEN_UV, blur).rgb;
	COLOR = vec4(mix(behind * 0.5, COLOR.rgb, 0.55), COLOR.a);
}
