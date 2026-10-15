// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;

// Sağdaki 3. şerit parçası (x 8..11,6): yalnız genişleyen bölgede görünür, ötesini atar. discard ayrı bir
// shader'da kalsın: ana yol shader'ında olsaydı bütün yolun erken derinlik testi kapanırdı.
#include "res://road_common.gdshaderinc"

varying vec2 p;

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float wf = wide_f(p.y);
	if (wf <= 0.0 || p.x > 7.0 + 3.5 * wf + 0.6) {
		discard;
	}
	vec3 alb;
	float rough;
	float spec;
	vec3 emis;
	vec3 nm;
	road_surface(p, SCREEN_UV, TIME, alb, rough, spec, emis, nm);
	ALBEDO = alb;
	ROUGHNESS = rough;
	SPECULAR = spec;
	EMISSION = emis;
	NORMAL_MAP = nm;
}
