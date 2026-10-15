// Copyright (c) 2026 bercedev (https://github.com/bercedev)
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// Islak asfalt, şerit çizgileri, su birikintileri, yol çalışması toprağı ve 3. şerit. road.gdshader (ana yol)
// ve road_side.gdshader (sağdaki 3. şerit parçası) paylaşır. Yol parçaları sabit durur, desen `offset` ile kayar;
// bütün desenler 900 m'de tekrar eder, main.gd offset'i 900'de sarar, atlama görünmez.
uniform float offset = 0.0;
uniform float rain_amt = 1.0; // yağış şiddeti: birikintilerde damla halkaları
uniform vec2 widen = vec2(-1e6, -1e6); // 3. şerit bölgesinin başı ve sonu (sahne z'si, baş > son)
uniform vec4 works = vec4(0.0, 0.0, -1e6, -1e6); // yol çalışması toprağı: x0, x1, yakın z, uzak z
uniform sampler2D refl_tex : hint_default_black, filter_linear; // yüksek grafikte düzlem yansıması
uniform float refl_amt = 0.0;
global uniform float wetness; // hava durumu: 1 sırılsıklam, 0 kuru
global uniform float night;

const float WIDEN_TAPER = 40.0;

float hash(vec2 q) {
	q = fract(q * vec2(123.34, 456.21));
	q += dot(q, q + 45.32);
	return fract(q.x * q.y);
}

// Değer gürültüsü; cell 900'ü tam bölmeli.
float noise(vec2 q, float cell) {
	vec2 g = q / cell;
	vec2 i = floor(g);
	vec2 f = fract(g);
	f = f * f * (3.0 - 2.0 * f);
	float per = 900.0 / cell;
	float y0 = mod(i.y, per);
	float y1 = mod(i.y + 1.0, per);
	float a = hash(vec2(i.x, y0));
	float b = hash(vec2(i.x + 1.0, y0));
	float c = hash(vec2(i.x, y1));
	float d = hash(vec2(i.x + 1.0, y1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float line(float x, float center, float w) {
	float aa = fwidth(x);
	return 1.0 - smoothstep(w * 0.5 - aa, w * 0.5 + aa, abs(x - center));
}

// 3. şeridin açıklığı 0..1; z sahne z'si (yol parçaları sabit olduğundan dünya z'si ile aynı).
float wide_f(float z) {
	return clamp((widen.x - z) / WIDEN_TAPER, 0.0, 1.0) * clamp((z - widen.y) / WIDEN_TAPER, 0.0, 1.0);
}

void road_surface(vec2 p, vec2 suv, float time, out vec3 albedo, out float rough, out float spec, out vec3 emis, out vec3 nmap) {
	vec2 q = vec2(p.x, p.y - offset);
	float x = q.x;
	float wf = wide_f(p.y);
	float edge = x > 0.0 ? 7.0 + 3.5 * wf : 7.0; // 3. şerit açılınca sağ kenar dışarı kayar

	float dz = fract(q.y / 9.0);
	float dash = smoothstep(0.0, 0.02, dz) * (1.0 - smoothstep(0.4, 0.42, dz));
	// 4 şerit: ortada çift sarı (karşı yön ayrımı), her yönde şerit arası kesikli beyaz, kenarlarda düz beyaz.
	// 3. şerit bölgesinde sağdaki eski kenar çizgisi kesikliye döner, yeni kenar çizgisi dışta.
	float right_old = line(x, 7.0, 0.16) * (wf > 0.001 ? dash : 1.0);
	float white = max((line(x, -3.5, 0.14) + line(x, 3.5, 0.14)) * dash, max(line(x, -7.0, 0.16), right_old));
	if (wf > 0.001) {
		white = max(white, line(x, edge, 0.16));
	}
	float yellow = max(line(x, -0.15, 0.12), line(x, 0.15, 0.12));

	// yol çalışması: kapalı şeritte asfalt sökülmüş, toprak ve iş makinesi izleri
	float dirt = smoothstep(works.x, works.x + 0.2, x) * (1.0 - smoothstep(works.y - 0.2, works.y, x))
		* smoothstep(works.w, works.w + 2.0, p.y) * (1.0 - smoothstep(works.z - 2.0, works.z, p.y));

	float damp = smoothstep(0.45, 0.75, noise(q, 4.0) * 0.7 + noise(q, 1.5) * 0.3) * wetness;
	// su birikintisi: keskin kenarlı ayrı göller; tekerlek izlerinde (şerit ortası ±0,85 m) ve yol kenarında daha sık
	float rut = 0.5 + 0.5 * cos((x - 0.9) * 6.2832 / 1.75);
	float pn = noise(q, 9.0) * 0.6 + noise(q + vec2(31.7, 0.0), 2.5) * 0.4 + rut * 0.08 + smoothstep(5.5, 7.0, abs(x)) * 0.1;
	float puddle = smoothstep(0.66, 0.70, pn) * smoothstep(0.3, 0.7, wetness);
	float grain = hash(vec2(floor(x * 30.0), mod(floor(q.y * 30.0), 27000.0)));

	vec3 asphalt = vec3(0.035, 0.037, 0.042) * (0.8 + 0.4 * grain);
	asphalt *= mix(1.0, 0.6, damp);
	asphalt *= mix(1.0, 0.85, wetness); // ıslak asfalt koyulaşır
	asphalt *= mix(1.0, 0.35, puddle); // su altındaki asfalt çok koyu, ışığı yüzey yansıtır
	asphalt = mix(asphalt, vec3(0.02, 0.022, 0.02), smoothstep(edge + 0.3, edge + 0.5, abs(x)));

	vec3 col = mix(asphalt, vec3(0.8), white * 0.85 * mix(1.0, 0.5, puddle));
	col = mix(col, vec3(0.85, 0.6, 0.1), yellow * mix(1.0, 0.6, puddle));
	float r = mix(mix(mix(0.75, 0.35, wetness), 0.12, damp), 0.5, max(white, yellow));
	if (dirt > 0.001) {
		float n = noise(q, 0.6) * 0.6 + noise(q, 2.5) * 0.4;
		vec3 soil = mix(vec3(0.07, 0.05, 0.035), vec3(0.15, 0.11, 0.07), n) * mix(1.0, 0.6, wetness);
		float mid = (works.x + works.y) * 0.5;
		float tracks = (line(x, mid - 0.9, 0.55) + line(x, mid + 0.9, 0.55)) * step(0.45, fract(q.y * 2.5));
		soil *= 1.0 - tracks * 0.35;
		col = mix(col, soil, dirt);
		r = mix(r, 0.95, dirt);
		puddle *= mix(1.0, 0.7, dirt); // çamurlu su
	}

	// yağmur damlası halkaları: 0,5 m hücrelerde rastgele anlarda büyüyüp sönen halka, yüzey normalini bükerek parlar
	vec2 ripple = vec2(0.0);
	if (puddle > 0.01 && rain_amt > 0.01) {
		vec2 g = q * 2.0;
		vec2 id = vec2(floor(g.x), mod(floor(g.y), 1800.0)); // desen 900 m sarmasında atlamasın
		float h = hash(id);
		float t = fract(time * 0.9 + h);
		vec2 d = fract(g) - 0.5 - (vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5) * 0.4;
		float ring = (1.0 - smoothstep(0.0, 0.04, abs(length(d) - t * 0.45))) * (1.0 - t) * step(h, rain_amt);
		ripple = normalize(d + 0.0001) * ring * puddle;
	}

	albedo = col;
	rough = mix(r, mix(0.08, 0.02, night), puddle);
	spec = mix(0.6, mix(0.5, 0.85, night), puddle); // gündüz gökyüzünü bembeyaz yansıtmasın
	nmap = vec3(ripple * 0.5 + 0.5, 1.0);
	// gökyüzünün sahte yansıması: birikinti gece hafif lacivert, gündüz gri-mavi parlar
	emis = vec3(0.9, 0.6, 0.1) * yellow * 0.08 + vec3(white * 0.03)
		+ vec3(0.008, 0.012, 0.025) * night * puddle;
	// yüksek grafik: yansıma kamerasının görüntüsü birikintide net, ıslak asfaltta soluk
	if (refl_amt > 0.0) {
		vec3 rc = texture(refl_tex, vec2(suv.x, 1.0 - suv.y) + ripple * 0.03).rgb;
		emis += min(rc, vec3(1.5)) * refl_amt * (puddle * 0.7 + wetness * 0.035 * (1.0 - dirt));
	}
}
