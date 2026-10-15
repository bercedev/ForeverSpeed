// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

shader_type spatial;

// Ana yol (x -8..8). Desen road_common.gdshaderinc'te.
#include "res://road_common.gdshaderinc"

varying vec2 p;

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; // parçalar arasında desen kesintisiz
}

void fragment() {
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
