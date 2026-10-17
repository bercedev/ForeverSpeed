// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Araç boyası (car.gdshader dışarıdan, car_in.gdshader kokpitte içeriden).

// Palet dokulu araba modelleri (R34 ve Kenney). Paletteki dikdörtgenler (u0, v0, u1, v1):
// tail_uv stop lambası rengi, kendi ışığıyla parlar; paint_uv gövde boyası, garajda seçilen renge boyanır.
// R34: dokunun üst şeridi renk kareleri, v > body_v gövde. Kenney: body_v = 0, hepsi boya sayılır.
uniform sampler2D albedo_tex : source_color;
uniform vec3 base_col : source_color = vec3(1.0); // malzemenin kendi rengi (doku bununla çarpılır)
uniform float tail_energy = 4.0;
uniform vec4 tail_uv = vec4(0.75, 0.0, 0.875, 0.125);
uniform float body_v = 0.125;
uniform vec4 paint_uv = vec4(0.0, 0.125, 1.0, 1.0);
uniform vec3 paint : source_color = vec3(1.0);
uniform float use_paint = 0.0;
// 0 parlak, 1 metalik, 2 mat, 3 krom, 4 bukalemun, 5 neon, 6 şeker; desenler: 7 yarış şeridi, 8 alev, 9 kamuflaj,
// 10 dama, 11 grafiti, 12 karbon, 13 kaplan, 14 neon devre
uniform int finish = 0;
uniform vec3 paint2 : source_color = vec3(0.0, 0.9, 0.8); // ikinci renk (bukalemun, şerit, desen)
// desenler araç uzayında (metre; x yan, y yukarı, -z ön): model ne olursa olsun aynı ölçekte otursun.
// main.gd her karede arabanın ters dönüşümünü verir.
uniform mat4 car_inv = mat4(1.0);
uniform vec3 car_size = vec3(1.0, 1.3, 2.3); // yarım genişlik, yükseklik, yarım boy

varying vec3 lpos;
varying vec3 cpos;
varying vec3 cnrm;

void vertex() {
	lpos = VERTEX;
	cpos = (car_inv * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cnrm = normalize(mat3(car_inv) * mat3(MODEL_MATRIX) * NORMAL);
}

// sinüssüz hash: sin'li olanı komşu hücrelerde yuvarlama yüzünden farklı değer verip desende dikiş açıyordu
float h3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float n3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

vec3 hue(float h) {
	return clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
}

float inside(vec2 uv, vec4 r) {
	return step(r.x, uv.x) * step(uv.x, r.z) * step(r.y, uv.y) * step(uv.y, r.w);
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	vec3 c = tex * base_col;
	float body = step(body_v, UV.y);
	// boyada dokunun parlaklığı (gölge, çizgi) korunur, renk değişir; düz renkli gövdenin kendi rengi base_col'da,
	// boyayı karartmaz (koyu yeşil M5 seçilen boyayı da koyu gösteriyordu)
	float pm = inside(UV, paint_uv) * use_paint;
	float lum = max(tex.r, max(tex.g, tex.b));
	vec3 alb = mix(c, paint * lum, pm);
	float rough = mix(0.5, 0.25, body);
	float metal = 0.3 * body;
	vec3 emis = c * inside(UV, tail_uv) * tail_energy;
	// modifiye boyalar yalnız boyanan gövdede; trafik araçlarında finish 0, dal hiç çalışmaz
	if (pm > 0.5 && finish > 0) {
		float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
		if (finish == 1) { // metalik: ince pul (model uzayında; Kenney yüzleri tek texel'e bakar)
			vec3 cell = floor(lpos * 90.0);
			float flake = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
			alb *= 0.8 + 0.4 * flake;
			metal = 0.75;
			rough = 0.3;
		} else if (finish == 2) { // mat
			metal = 0.0;
			rough = 0.85;
		} else if (finish == 3) { // krom: gökyüzü yok, ufku sahte yansıtır
			alb = vec3(0.8, 0.82, 0.86);
			metal = 1.0;
			rough = 0.06;
			float up = reflect(-VIEW, NORMAL).y;
			emis += mix(vec3(0.02, 0.02, 0.03), vec3(0.25, 0.32, 0.45), smoothstep(-0.3, 0.6, up)) * 0.6;
		} else if (finish == 4) { // bukalemun: bakış açısıyla renk döner
			alb = mix(paint, paint2, fres) * lum;
			metal = 0.6;
			rough = 0.25;
		} else if (finish == 5) { // neon: kendi ışığıyla parlar
			emis += paint * 0.55;
			rough = 0.3;
		} else if (finish == 6) { // şeker: derin, parlak, koyu renk
			alb = paint * paint * 1.3 * lum;
			metal = 0.9;
			rough = 0.12;
		} else {
			vec3 P = cpos;
			vec3 N = cnrm;
			float side = smoothstep(0.4, 0.7, abs(N.x));
			float u = clamp((P.z + car_size.z) / (2.0 * car_size.z), 0.0, 1.0); // 0 ön, 1 arka
			float y = clamp(P.y / car_size.y, 0.0, 1.0);
			vec3 col = paint;
			if (finish == 7) { // yarış şeridi: tavan, kaput ve bagajda iki şerit
				float st = step(abs(abs(P.x) - 0.24), 0.09) * step(0.35, N.y);
				col = mix(paint, paint2, st);
			} else if (finish == 8) { // alev: önden arkaya yanlarda yalayan diller
				float edge = 0.78 - u * 0.95 + (n3(vec3(u * 9.0, y * 3.0, 0.0)) - 0.5) * 0.35 + 0.08 * sin(u * 40.0 + y * 6.0);
				float fl = step(y, edge) * max(side, step(0.5, N.y) * step(u, 0.35));
				vec3 fire = mix(vec3(1.0, 0.95, 0.3), mix(vec3(1.0, 0.45, 0.05), vec3(0.85, 0.05, 0.02), u * 1.6), smoothstep(0.0, 0.5, u + (0.6 - y) * 0.4));
				col = mix(paint, fire, fl);
				emis += fire * fl * 0.15;
			} else if (finish == 9) { // kamuflaj: üç ton leke
				float a = n3(P * 1.6);
				float b = n3(P * 2.7 + 17.0);
				col = a > 0.55 ? paint2 : (b > 0.6 ? paint * 0.35 : paint);
			} else if (finish == 10) { // dama
				float c = mod(floor(P.x * 4.0) + floor(P.y * 4.0) + floor(P.z * 4.0), 2.0);
				col = mix(paint, paint2, c);
			} else if (finish == 11) { // grafiti: renkli sprey lekeleri, koyu dış çizgi, akıntılar
				float f = n3(P * 1.8) * 0.7 + n3(P * 5.0 + 9.0) * 0.3;
				vec3 cell = floor(P * 1.2);
				vec3 spray = hue(h3(cell)) * 0.9 + 0.1;
				float blob = smoothstep(0.52, 0.55, f);
				float outline = smoothstep(0.47, 0.5, f) * (1.0 - blob);
				float drip = step(0.86, h3(vec3(floor(P.z * 14.0), floor(P.x * 2.0), 3.0))) * side
					* step(n3(vec3(P.z * 3.0, 0.0, 5.0)) * 0.6, y) * step(y, 0.75) * step(0.35, n3(P * 1.8));
				col = mix(paint, spray, max(blob, drip * 0.9));
				col = mix(col, vec3(0.02), outline);
				emis += spray * blob * 0.08;
			} else if (finish == 12) { // karbon: ince örgü
				float w = mod(floor(P.z * 28.0) + floor((P.x + P.y) * 28.0), 2.0);
				col = mix(vec3(0.03, 0.03, 0.035), vec3(0.1, 0.1, 0.11), w);
				metal = 0.4;
				rough = 0.22;
			} else if (finish == 13) { // kaplan: dalgalı siyah çizgiler
				float t = sin(P.z * 13.0 + n3(P * 2.0) * 5.0 + y * 2.0);
				col = mix(paint, paint2, smoothstep(0.55, 0.62, t));
			} else if (finish == 14) { // neon devre: siyah üstünde parlayan hatlar
				vec3 g = abs(fract(P * 3.0) - 0.5);
				float ln = step(min(g.x, min(g.y, g.z)), 0.025) * step(0.45, h3(floor(P * 3.0)));
				col = mix(vec3(0.02), paint2, ln);
				emis += paint2 * ln * 1.4;
				rough = 0.35;
			}
			alb = col * mix(1.0, lum, 0.6); // modelin koyu yerleri (cam, ızgara) koyu kalsın
		}
	}
	ALBEDO = alb;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emis;
}
