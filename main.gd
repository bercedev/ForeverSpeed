# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node3D

# Araba z=0'da sabit durur, dünya +z yönünde akar (kamera -z'ye bakar).
# Yol ne kadar uzarsa uzasın koordinatlar küçük kalır, float hassasiyeti bozulmaz.
# Durumlar: menu (araba kendi gider, trafik yok) -> play -> over.

const Build := preload("res://build.gd")
const Regions := preload("res://regions.gd")

# Yol 4 şerit, şerit 3,5 m. 0-1 karşı yön (araçlar bize doğru gelir), 2-3 bizim yönümüz.
const LANES := [-5.25, -1.75, 1.75, 5.25]
const ONCOMING := [0, 1]
const OURS := [2, 3]
const LANE_KMH := [80.0, 65.0, 85.0, 60.0] # şerit başına sabit hız: aynı şeritte araçlar üst üste binmez
const ROAD_EDGE := 7.0 # dış şerit çizgisi
const ONCOMING_MULT := 1.5 # karşı şeritte giderken puan çarpanı
const GEAR_UP := [0.0, 50.0, 90.0, 135.0, 185.0, 240.0, 340.0] # otomatik vites eşikleri (km/sa)
const MIN_KMH := 50.0
const MENU_KMH := 140.0
const PROP_COUNT := 9
const SPAWN_Z := -260.0
const TUNNEL_LEN := 240.0
const TUNNEL_NAMES := ["CERCEYN TUNNEL", "NIGHT BAY TUNNEL", "RAIN PASS TUNNEL"]
const SIREN_REL := 16.0 # siren aracı bizi bu kadar m/sn farkla geçer
const TRAFFIC_MODELS := ["sedan", "sedan-sports", "hatchback-sports", "suv", "suv-luxury", "taxi", "van", "delivery"]
const KENNEY_SCALE := Vector3(1.25, 1.2, 1.5) # Kenney arabaları oyuncak oranlı; boyu uzatıp gerçeğe yaklaştır
const KENNEY_TAIL := Vector4(0.25, 0.75, 0.375, 1.0) # Kenney paletinde kırmızı stop lambası karesi
# Garaj araçlarında boyanacak gövde rengi karesi (Kenney paleti)
const PAINT_UV := {
	"sedan-sports": Vector4(0.75, 0.25, 0.875, 0.5),
	"hatchback-sports": Vector4(0.375, 0.25, 0.5, 0.5),
	"race": Vector4(0.75, 0.25, 0.875, 0.5),
	"race-future": Vector4(0.875, 0.25, 1.0, 0.5),
}
const NEAR_MIN_KMH := 120.0
const COMBO_WINDOW := 3.0
const NITRO_TIME := 3.5
const NITRO_KMH := 90.0
# hava: [yağmur 0..1, sis yoğunluğu, şimşek]
const WEATHERS := {
	"sağanak": [1.0, 0.016, true],
	"çisenti": [0.4, 0.012, false],
	"açık": [0.0, 0.008, false],
	"sis": [0.15, 0.035, false],
}
# Serbest direksiyon: araba şeride kilitlenmez, parmakla kaydırılır.
const ROAD_HALF := 6.1 # arabanın merkezinin gidebileceği en uç x (bariyerin içi)
const DRAG_GAIN := 0.022 # parmak 1 px kayınca araba bu kadar metre yana gider (720 px genişlikte)
const KEY_STEER := 9.0 # klavyede yana kayma hızı (m/sn)
const MAX_BUMPS := 3 # bir oyunda bu kadar hafif çarpma kaza sayılır: köşe sıyırarak trafiği yarmak bedava olmasın
const NEAR_GAP := 0.9 # yakın geçiş: yan boşluk bundan azsa sayılır (m)
const HEAVY_KMH := 50.0 # tam arkadan bu hız farkıyla bindirmek kaza; sıyırma ya da yavaş temas uyarı
# Yol çalışması: çok önceden uyarılır, sonra bir şerit konilerle daralıp bariyerle kapanır.
const WORK_LEN := 320.0
const WORK_TAPER := 45.0 # konilerle şeridin daraldığı bölüm
const WORK_WARN := 1500.0 # 300 km/sa'de yaklaşık 18 sn önceden
# Gece-gündüz: gecenin çoğu, şafak, gündüz, akşam. Saat Profile'da durur, oyunlar arasında akar.
const DAY_LEN := 300.0
const NIGHT_SKY := Color(0.03, 0.045, 0.08)
const DAWN_SKY := Color(0.42, 0.26, 0.3)
const DAY_SKY := Color(0.36, 0.42, 0.5) # yağmurlu, bulutlu gündüz
const CLEAR_SKY := Color(0.3, 0.48, 0.78)

var state := "menu"
var gear := 1
var rpm := 0.0
var kmh := MENU_KMH
var target_x: float = LANES[2] # direksiyon: arabanın gitmek istediği x
var bumps := 0 # bu oyundaki hafif çarpma sayısı
var lamp_day := -1.0 # lambaları en son hangi gün ışığına göre ayarladık
var travel := 0.0 # dünyanın kaydığı yol; bölge, tünel ve yol çalışması takvimi buna göre
var distance := 0.0 # bu oyunda gidilen yol
var score := 0.0
var run_time := 0.0
var alive := 0.0
var since_row := 0.0
var since_on := 0.0
var crash_time := 0.0
var shake := 0.0
var cam_x := 0.0
var cam_pos := Vector3(0, 3.3, 7.4)
var lens_nitro := 0.0
var touch_start := Vector2.ZERO
var swiped := false
var holding := false
var hold_time := 0.0
var braking := false
var hit_car: Node3D # çarpılan araç kazadan sonra bize yapışır, içimizden geçmez
var hit_push := 0.0
var combo := 0
var combo_t := 0.0
var nitro := 0.0 # depo 0..1
var nitro_t := 0.0 # kalan nitro süresi
var region := -1
var region_offset := 0.0
var tunnel: Node3D # bir kez kurulur, gerektikçe öne taşınır
var tunnel_sign: Label3D
var tunnel_on := false
var tunnel_t0 := 1e9 # tünel girişi z
var tunnel_t1 := 1e9 # tünel çıkışı z
var tunnel_in := 0.0 # 0 dışarıda, 1 içeride
var next_tunnel := 900.0
var siren: Node3D
var sirens: Array[Node3D] = [] # polis ve ambulans bir kez kurulur, sırayla kullanılır
var siren_red: MeshInstance3D
var siren_blue: MeshInstance3D
var siren_light: OmniLight3D
var next_siren := 500.0
var works: Node3D # yol çalışması, tünel gibi bir kez kurulur
var works_on := false
var works_lane := 3
var works_start := 0.0 # konilerin başladığı yer (travel cinsinden)
var works_warned := 0.0 # titreşimli uyarıların en son verildiği mesafe
var works_close := 0.0 # bariyerin dibinden gidilen yol (dar geçiş bonusu)
var works_cam := 0.0 # 0..1, yol çalışmasında kamera alçalır
var next_works := 1e9
var works_cones: MultiMesh
var works_barriers: MultiMesh
var works_lights: MultiMesh
var works_amber: StandardMaterial3D
var works_arrow: Label3D
var works_board: MeshInstance3D
var weather := "sağanak"
var weather_t := 45.0
var rain_level := 1.0
var wetness := 1.0
var flash_t := 99.0
var next_flash := 8.0
var warmup := 4 # açılışta siyah ekran arkasında her şey birkaç kare çizilir: shader'lar oyunda derlenip takılmasın
var last_tap := -10.0 # çift dokunuş (nitro) için, gerçek zaman
var last_tap_pos := Vector2.ZERO
var tip_on := false # nitro öğreticisi açık: oyun ağır çekimde
var tip_until := 0.0
var models := {} # Kenney sahneleri bir kez yüklenir; oyun sırasında diskten okumak takılma yapar
var sfx := {} # tek seferlik sesler
var engine_snd: AudioStreamPlayer
var rain_snd: AudioStreamPlayer
var reverb: AudioEffectReverb
var thunder_in := -1.0 # şimşekten gök gürültüsüne kalan süre: ışık sesten hızlı
var day := 0.0 # 0 gece, 1 gündüz
var sky := NIGHT_SKY
var amb_base := 0.9 # gece-gündüzün verdiği ortam ışığı; şimşek bunun üstüne eklenir
var sun_base := 0.35

var car: Node3D
var player_mat: ShaderMaterial
var flame_mat: StandardMaterial3D
var flames: Array[MeshInstance3D] = []
var cam: Camera3D
var env: Environment
var moon: DirectionalLight3D
var rain: GPUParticles3D
var rain_pm: ParticleProcessMaterial
var road_mat: ShaderMaterial
var lens_mat: ShaderMaterial
var kenney_mat: ShaderMaterial
var head_mat: StandardMaterial3D
var blob_mat: StandardMaterial3D
var props: Array[Node3D] = []
var traffic: Array[Node3D] = []
var pool: Array[Node3D] = [] # bizim yöndeki boşta araçlar
var pool_on: Array[Node3D] = [] # karşı yöndeki boşta araçlar (farları yanık, önü bize dönük)
var ui # ui.gd


func _ready() -> void:
	Engine.time_scale = 1.0 # öğretici ağır çekimdeyken sahne yenilenirse kalmasın
	region_offset = (randi() % 4) * Regions.LEN
	for n in TRAFFIC_MODELS + ["police", "ambulance"]:
		models[n] = load("res://cars/kenney/%s.glb" % n)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.75))
	g.set_color(1, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	blob_mat = StandardMaterial3D.new()
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.albedo_texture = tex
	kenney_mat = ShaderMaterial.new()
	kenney_mat.shader = preload("res://car.gdshader")
	kenney_mat.set_shader_parameter("albedo_tex", preload("res://cars/kenney/Textures/colormap.png"))
	kenney_mat.set_shader_parameter("tail_uv", KENNEY_TAIL)
	kenney_mat.set_shader_parameter("body_v", 0.0)
	head_mat = Build.mat(Color(1.0, 0.95, 0.85), 0.5, 0.0, 6.0)

	build_world()
	for i in PROP_COUNT:
		var p := Regions.make_chunk(i)
		p.position.z = 30.0 - i * Regions.GAP
		Regions.configure(p, region_at(travel - p.position.z))
		add_child(p)
		props.append(p)
	set_player_car(Profile.car, Profile.paint)
	car.position.x = target_x
	for i in 18:
		var c := make_kenney(TRAFFIC_MODELS.pick_random())
		c.visible = false
		add_child(c)
		pool.append(c)
	for i in 10:
		var c := make_kenney(TRAFFIC_MODELS.pick_random(), true)
		c.visible = false
		add_child(c)
		pool_on.append(c)
	build_audio()
	build_tunnel()
	build_works()
	build_sirens()
	build_rain()
	build_lens()
	apply_settings()
	ui = preload("res://ui.gd").new()
	add_child(ui)
	if Profile.autostart:
		Profile.autostart = false
		start_run()
	else:
		ui.show_menu()
	warm(true)


func _process(dt: float) -> void:
	if warmup > 0:
		warmup -= 1
		if warmup == 0:
			warm(false)
	alive += dt
	update_speed(dt)
	var step := kmh / 3.6 * dt
	travel += step
	road_mat.set_shader_parameter("offset", fmod(travel, 900.0))
	if state == "play":
		update_run(step, dt)
	elif state == "over":
		crash_time += dt
	if siren == null and travel > next_siren and not works_on:
		spawn_siren()
	update_tunnel(step, dt)
	update_works(dt)
	update_props(step)
	update_traffic(step, dt)
	if siren:
		update_siren(dt)
	else:
		lens_mat.set_shader_parameter("siren_amt", 0.0)
	update_player(dt)
	update_daylight(dt)
	update_weather(dt)
	update_camera(dt)
	update_audio(dt)
	ui.update_hud()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ENTER, KEY_SPACE]:
		if state == "menu" and not ui.panel_open():
			start_run()
			return
		if state == "over" and crash_time > 0.8:
			restart()
			return
	if state != "play":
		return
	if (e is InputEventScreenTouch or e is InputEventScreenDrag) and e.index != 0:
		return # ikinci parmak ne direksiyon ne fren ne nitro
	if e is InputEventScreenTouch:
		holding = e.pressed
		if e.pressed:
			touch_start = e.position
			swiped = false
			hold_time = 0.0
			# çift dokunuş: nitro
			var now := Time.get_ticks_msec() / 1000.0
			if now - last_tap < 0.35 and e.position.distance_to(last_tap_pos) < 90.0:
				last_tap = -10.0
				fire_nitro()
			else:
				last_tap = now
				last_tap_pos = e.position
		elif swiped:
			last_tap = -10.0 # kaydırma dokunuş sayılmaz
	elif e is InputEventScreenDrag:
		# parmak ne kadar kayarsa araba o kadar yana gider; bir kez kaydıran dokunuş fren sayılmaz
		target_x = clampf(target_x + e.relative.x * DRAG_GAIN, -ROAD_HALF, ROAD_HALF)
		if e.position.distance_to(touch_start) > 12.0:
			swiped = true
			last_tap = -10.0 # kaydırma, çift dokunuşun ilk dokunuşu sayılmaz
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_UP, KEY_W]:
		fire_nitro()


# --- Oyun akışı ---

func start_run() -> void:
	state = "play"
	region = region_at(travel)
	run_time = 0.0
	next_works = travel + randf_range(1800.0, 2600.0) # ilk yol çalışması oyunun ~2. km'sinde
	ui.show_play()


func restart() -> void:
	Profile.autostart = true
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().reload_current_scene()


# c: çarpılan araç; yol çalışması bariyerine çarpınca null.
func crash(c: Node3D) -> void:
	if state != "play":
		return
	state = "over"
	braking = false
	nitro_t = 0.0
	close_tip()
	shake = 0.5
	hit_car = c
	hit_push = clampf(kmh / 3.6 * 0.3, 4.0, 18.0)
	buzz(400, 1.0)
	play("crash")
	var earned := int(score / 25.0)
	var new_best := Profile.finish_run(int(score), earned)
	ui.show_over(int(score), distance / 1000.0, earned, new_best)


# Arabanın şu an üstünden geçtiği şeritler (iki şeridin arasındaysa ikisi de).
func player_lanes() -> Array:
	return [0, 1, 2, 3].filter(func(k): return absf(LANES[k] - car.position.x) < 2.9)


func fire_nitro() -> void:
	if nitro < 1.0 or nitro_t > 0.0:
		return
	close_tip()
	nitro = 0.0
	nitro_t = NITRO_TIME
	shake = 0.25
	buzz(80, 0.8)
	play("boost")
	mission("nitro", 1)


# Nitro ilk kez dolunca bir kez: oyun ağır çekime girer, çift dokunuş anlatılır.
func open_tip() -> void:
	tip_on = true
	tip_until = Time.get_ticks_msec() / 1000.0 + 6.0
	Engine.time_scale = 0.3
	ui.show_tip(true)
	buzz(50, 0.5)


func close_tip() -> void:
	if not tip_on:
		return
	tip_on = false
	Engine.time_scale = 1.0
	ui.show_tip(false)
	Profile.nitro_tip = true
	Profile.save()


func nitro_level() -> float:
	return nitro_t / NITRO_TIME if nitro_t > 0.0 else nitro


# Skorun altındaki etiketler: karşı şerit çarpanı ve kombo.
func hud_tags() -> String:
	var tags := PackedStringArray()
	if car.position.x < 0.0:
		tags.append("KARŞI ŞERİT x%.1f" % ONCOMING_MULT)
	if combo > 1:
		tags.append("KOMBO x%d" % combo)
	return "  ·  ".join(tags)


func buzz(ms: int, amplitude: float) -> void:
	if Profile.vibration:
		Input.vibrate_handheld(ms, amplitude)


func mission(type: String, amount: float) -> void:
	for m in Profile.track(type, amount):
		ui.toast("GÖREV TAMAM  +%d COIN" % m.reward, Color(1.0, 0.8, 0.3))
		buzz(60, 0.6)
		play("confirm")


# Grafik ve FPS ayarı (Ayarlar sekmesi). Düşük: 3B çözünürlük %60, MSAA ve parlama kapalı, az yağmur.
func apply_settings() -> void:
	var q: int = Profile.quality
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = [0.6, 0.8, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	env.glow_enabled = q > 0
	rain.amount = [500, 1000, 1500][q]
	lens_mat.set_shader_parameter("taps", [1, 4, 6][q])
	Engine.max_fps = Profile.fps


# Açılışta her şey birkaç kare görünür çizilir, siyah perdenin arkasında: bölgelerin su ve bina
# shader'ları, tünel, yol çalışması, siren araçları, trafik modelleri, yazı fontları ilk kez oyunun
# ortasında değil burada derlenir. Yoksa ilk köprüde, ilk tünelde, ilk sirende oyun takılır.
func warm(on: bool) -> void:
	for p in props:
		for k in 4:
			p.get_node("r%d" % k).visible = on or k == p.get_meta("region")
	tunnel.visible = on
	tunnel.position.z = -40.0
	tunnel_sign.text = " ".join(TUNNEL_NAMES) if on else ""
	if on:
		configure_works(3)
	works.visible = on
	works.position.z = -20.0
	for i in sirens.size():
		sirens[i].visible = on
		sirens[i].position = Vector3(LANES[2 + i], 0, -14.0)
	for i in 4:
		pool[i].visible = on
		pool[i].position = Vector3(LANES[2 + i % 2], 0, -24.0 - i * 6.0)
		pool_on[i].visible = on
		pool_on[i].position = Vector3(LANES[i % 2], 0, -24.0 - i * 6.0)
	ui.warm(on)


func region_at(w: float) -> int:
	return posmod(int(floor((w + region_offset) / Regions.LEN)), 4) # kameranın arkasında w negatif olabilir


# --- Kare güncellemeleri ---

func update_speed(dt: float) -> void:
	if state == "over":
		kmh = move_toward(kmh, 0.0, 400.0 * dt)
	elif state == "menu":
		kmh = move_toward(kmh, MENU_KMH, 60.0 * dt)
	else:
		hold_time += dt
		braking = (holding and not swiped and hold_time > 0.12) \
			or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE)
		var top := minf(230.0 + distance / 40.0, 320.0) # yol uzadıkça tavan hız artar
		if nitro_t > 0.0:
			kmh = move_toward(kmh, top + NITRO_KMH, 150.0 * dt)
		elif braking:
			kmh = move_toward(kmh, MIN_KMH, 140.0 * dt)
		elif kmh > top:
			kmh = move_toward(kmh, top, 40.0 * dt)
		else:
			kmh = move_toward(kmh, top, maxf(12.0 + 50.0 * (1.0 - kmh / top), 5.0) * dt) # hızlandıkça ivme düşer
	player_mat.set_shader_parameter("tail_energy", 12.0 if braking else 4.0)
	gear = 1
	while gear < 6 and kmh >= GEAR_UP[gear]:
		gear += 1
	var lo: float = GEAR_UP[gear - 1]
	var hi: float = GEAR_UP[gear]
	rpm = clampf((kmh - lo) / (hi - lo), 0.0, 1.0)


func update_run(step: float, dt: float) -> void:
	run_time += dt
	nitro_t = maxf(nitro_t - dt, 0.0)
	distance += step
	var mult := (2.0 if nitro_t > 0.0 else 1.0) * (ONCOMING_MULT if car.position.x < 0.0 else 1.0)
	score += step * mult
	# yol çalışmasına yaklaşırken ve içindeyken trafik seyrelir
	var sparse := 2.2 if works_on and works_start - travel < 700.0 else 1.0
	var hard := clampf(distance / 6000.0, 0.0, 1.0)
	since_row += step
	if since_row > lerpf(45.0, 24.0, hard) * sparse:
		since_row = 0.0
		spawn_row()
	since_on += step
	if since_on > lerpf(150.0, 70.0, hard) * sparse:
		since_on = 0.0
		spawn_oncoming()
	if nitro_t <= 0.0:
		nitro = minf(nitro + dt * 0.015, 1.0)
	if nitro >= 1.0 and not Profile.nitro_tip and not tip_on:
		open_tip()
	if tip_on and Time.get_ticks_msec() / 1000.0 > tip_until:
		close_tip()
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	if kmh >= 280.0:
		mission("fast_km", step / 1000.0)
	var r := region_at(travel)
	if r == Regions.BRIDGE:
		mission("bridge_km", step / 1000.0)
	if r != region:
		region = r
		ui.toast(Regions.NAMES[r], Color(0.6, 0.85, 1.0))
	mission("run_km", distance / 1000.0)


func update_tunnel(step: float, dt: float) -> void:
	if not tunnel_on and travel > next_tunnel and tunnel_fits():
		tunnel_on = true
		tunnel.position.z = -330.0 # kamera far'ının ve sisin ötesinde belirir
		tunnel.visible = true
		tunnel_sign.text = TUNNEL_NAMES.pick_random()
	tunnel_t0 = 1e9
	tunnel_t1 = 1e9
	if tunnel_on:
		tunnel.position.z += step
		tunnel_t0 = tunnel.position.z
		tunnel_t1 = tunnel_t0 - TUNNEL_LEN
		if tunnel_t1 > 30.0:
			tunnel_on = false
			tunnel.visible = false
			next_tunnel = travel + randf_range(1500.0, 3000.0)
	var inside := tunnel_t0 > cam.position.z and tunnel_t1 < cam.position.z
	tunnel_in = move_toward(tunnel_in, 1.0 if inside else 0.0, dt * 1.5)


# Köprüde ve yol çalışmasında tünel olmaz.
func tunnel_fits() -> bool:
	return not works_on and region_at(travel + 330.0) != Regions.BRIDGE \
		and region_at(travel + 330.0 + TUNNEL_LEN) != Regions.BRIDGE


func update_props(step: float) -> void:
	for p in props:
		p.position.z += step
		if p.position.z > 50.0:
			p.position.z -= PROP_COUNT * Regions.GAP
			Regions.configure(p, region_at(travel - p.position.z))
		var covered := p.position.z < tunnel_t0 + 25.0 and p.position.z > tunnel_t1 - 5.0 # tünelin içinden süs çıkmasın
		(p.get_meta("lamp") as Node3D).visible = not covered
		(p.get_meta("deco") as Node3D).visible = not covered


func update_traffic(step: float, dt: float) -> void:
	for i in range(traffic.size() - 1, -1, -1): # sondan başa: silerken kopya dizi gerekmez
		var c := traffic[i]
		if c == hit_car:
			hit_update(c, dt)
			continue
		var before: float = c.position.z - car.position.z
		var dir: int = c.get_meta("dir")
		# bizim yöndekiler bizden yavaş gider, karşı yöndekiler bize doğru gelir
		c.position.z += step - dir * LANE_KMH[c.get_meta("lane")] / 3.6 * dt
		var gone := c.position.z > 15.0 or c.position.z < SPAWN_Z - 60.0
		if c.get_meta("ghost", false):
			gone = fade_out(c, dt) or gone
		if gone:
			c.visible = false
			c.set_meta("ghost", false)
			traffic.erase(c)
			(pool if dir > 0 else pool_on).append(c)
		elif state == "play" and not c.get_meta("ghost", false):
			if touching(c):
				hit(c, kmh - dir * LANE_KMH[c.get_meta("lane")], before)
			elif before < 0.0 and c.position.z - car.position.z >= 0.0:
				near_miss(c)


func touching(c: Node3D) -> bool:
	return absf(c.position.z - car.position.z) < 4.3 and absf(c.position.x - car.position.x) < side_gap(c)


# İki aracın yanlardan değmeden durabileceği en küçük merkez aralığı: yarım genişlikler toplamı.
func side_gap(c: Node3D) -> float:
	return c.get_meta("half_w", 0.95) + car.get_meta("half_w", 0.95)


# Temas: karşıdan gelene değmek ya da tam arkadan büyük hız farkıyla bindirmek kaza. Sıyırmak, yandan
# değmek ya da yavaşken dokunmak yalnız uyarı: hız ve kombo gider, öteki araç yanıp sönerek kaybolur.
# before: bu kareden önceki dz. Sonrakine bakılsa düşük FPS'te araç bir karede 2-3 m ilerler,
# arkadan bindirme yandan değme sanılır.
func hit(c: Node3D, closing_kmh: float, before: float) -> void:
	if c.get_meta("dir", 1) < 0:
		crash(c)
		return
	var from_behind := before < -2.6 # öndeki aracın arkasına bindirdik
	var overlap := absf(c.position.x - car.position.x) < 1.3
	bumps += 1
	if (from_behind and overlap and closing_kmh > HEAVY_KMH) or bumps >= MAX_BUMPS:
		crash(c)
		return
	c.set_meta("ghost", true)
	c.set_meta("fade", 0.0)
	c.set_meta("push", signf(c.position.x - car.position.x) * 3.0) # değdiğimiz yönün tersine savrulur
	kmh *= 0.8
	combo = 0
	combo_t = 0.0
	shake = 0.3
	buzz(150, 0.7)
	play("crash", 1.4, -8.0)
	ui.popup("DİKKAT!  HAFİF ÇARPMA  %d/%d" % [bumps, MAX_BUMPS], Color(1.0, 0.55, 0.2))


# Hafif çarpılan araç 0,9 sn yanıp söner ve yana savrulur; bitince true.
func fade_out(c: Node3D, dt: float) -> bool:
	var t: float = c.get_meta("fade") + dt
	c.set_meta("fade", t)
	c.visible = fmod(t, 0.16) < 0.08
	c.position.x += c.get_meta("push") * dt
	return t > 0.9


# Bir aracı yakından sıyırarak geçmek: puan, kombo, nitro. Ne kadar yakınsa o kadar puan;
# karşıdan gelen araçta iki kat.
func near_miss(c: Node3D) -> void:
	var gap := absf(c.position.x - car.position.x) - side_gap(c) # iki araç arasındaki yan boşluk (m)
	if kmh < NEAR_MIN_KMH or gap > NEAR_GAP:
		return
	var head_on: bool = c.get_meta("dir") < 0
	combo = mini(combo + 1, 10)
	combo_t = COMBO_WINDOW
	var close := 1.0 + (NEAR_GAP - gap) / NEAR_GAP # 1 (sınırda) .. 2 (sürtünerek)
	var bonus := int((40 + kmh / 10.0) * close) * combo * (2 if nitro_t > 0.0 else 1) * (2 if head_on else 1)
	score += bonus
	if nitro_t <= 0.0:
		nitro = minf(nitro + (0.3 if head_on else 0.2), 1.0)
	ui.popup(("KARŞIDAN YAKIN GEÇİŞ  +%d" if head_on else "YAKIN GEÇİŞ  +%d") % bonus)
	buzz(25, 0.4)
	play("whoosh", randf_range(0.9, 1.2))
	mission("near", 1)
	if tunnel_in > 0.5:
		mission("near_tunnel", 1)
	mission("combo", combo)


func update_player(dt: float) -> void:
	if state == "play":
		var keys := float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) \
			- float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A))
		target_x = clampf(target_x + keys * KEY_STEER * dt, -ROAD_HALF, ROAD_HALF)
	elif state == "menu":
		target_x = LANES[2]
	var before := car.position.x
	car.position.x = lerpf(car.position.x, target_x, 1.0 - exp(-12.0 * dt))
	var lean := clampf((car.position.x - before) / maxf(dt, 0.001) * 0.12, -2.0, 2.0) # yana kayma hızına göre gövde yatar
	if state == "over":
		car.rotation.y += dt * kmh / 60.0
	else:
		car.rotation = car.rotation.lerp(Vector3(0, -lean * 0.08, lean * 0.03), 1.0 - exp(-10.0 * dt))
	var boost := nitro_t > 0.0
	flame_mat.emission = Color(0.7, 0.35, 1.0) if boost else Color(0.45, 0.5, 1.0)
	flame_mat.emission_energy_multiplier = 10.0 if boost else 4.0
	var flame_len := 2.2 if boost else (0.3 if braking else 0.5 + gear / 12.0)
	for f in flames:
		f.visible = state != "over"
		f.scale = Vector3(1, 1, randf_range(1.5, 2.5) * flame_len)


func update_weather(dt: float) -> void:
	weather_t -= dt
	if weather_t <= 0.0:
		var keys := WEATHERS.keys()
		keys.erase(weather)
		weather = keys.pick_random()
		weather_t = randf_range(35.0, 70.0)
	var w: Array = WEATHERS[weather]
	rain_level = move_toward(rain_level, w[0], dt * 0.12)
	var wet_target := clampf(rain_level * 1.2, 0.2, 1.0)
	wetness = move_toward(wetness, wet_target, dt * (0.2 if wet_target > wetness else 0.02)) # yol geç kurur
	env.fog_density = move_toward(env.fog_density, w[1], dt * 0.002)
	rain.amount_ratio = rain_level
	RenderingServer.global_shader_parameter_set("wetness", wetness)
	lens_mat.set_shader_parameter("wet", (1.0 - tunnel_in) * rain_level)
	# şimşek: iki çakan flaş, ortamı ve gökyüzünü aydınlatır
	if w[2] and rain_level > 0.7:
		next_flash -= dt
		if next_flash <= 0.0:
			flash_t = 0.0
			next_flash = randf_range(7.0, 18.0)
			thunder_in = randf_range(0.4, 1.6)
	flash_t += dt
	var f := (exp(-flash_t * 18.0) + 0.6 * exp(-absf(flash_t - 0.18) * 30.0)) * (1.0 - tunnel_in) * (1.0 - day * 0.7)
	env.background_color = sky.lerp(Color(0.45, 0.5, 0.65), f * 0.7)
	env.ambient_light_energy = amb_base + f * 2.5
	moon.light_energy = sun_base + f * 3.0


# Gece-gündüz: gök ve sis rengi, güneş/ay, ortam ışığı, sokak lambaları ve yansımalar birlikte döner.
func update_daylight(dt: float) -> void:
	Profile.clock += dt
	var ph := fmod(Profile.clock / DAY_LEN, 1.0)
	day = smoothstep(0.4, 0.5, ph) * (1.0 - smoothstep(0.85, 0.95, ph))
	var warm := 1.0 - absf(day * 2.0 - 1.0) # şafakta ve akşamda 1: gök turuncuya döner
	sky = NIGHT_SKY.lerp(DAY_SKY.lerp(CLEAR_SKY, 1.0 - rain_level), day).lerp(DAWN_SKY, warm * 0.6)
	env.fog_light_color = sky
	env.ambient_light_color = Color(0.12, 0.16, 0.28).lerp(Color(0.55, 0.6, 0.68), day)
	amb_base = 0.9 + day * 0.4
	moon.light_color = Color(0.5, 0.6, 1.0).lerp(Color(1.0, 0.88, 0.75), day).lerp(Color(1.0, 0.55, 0.35), warm * 0.5)
	moon.rotation_degrees.x = lerpf(-40.0, -55.0, day)
	sun_base = 0.35 + day * 1.4
	env.glow_hdr_threshold = 0.8 + day * 0.6 # gündüz her şey parlamasın
	RenderingServer.global_shader_parameter_set("night", 1.0 - day)
	if absf(day - lamp_day) < 0.002:
		return
	lamp_day = day
	var lamp := 1.0 - day * 0.85 # gündüz sokak lambaları söner
	for p in props:
		if p.has_meta("lamp_light"):
			(p.get_meta("lamp_light") as OmniLight3D).light_energy = 2.5 * lamp
		(p.get_meta("lamp_mat") as StandardMaterial3D).emission_energy_multiplier = 8.0 * lamp


func update_camera(dt: float) -> void:
	var ratio := kmh / 300.0
	var k := 1.0 - exp(-4.0 * dt)
	var boost := 1.0 if nitro_t > 0.0 else 0.0
	shake = maxf(shake - dt, 0.0)
	lens_nitro = move_toward(lens_nitro, boost, dt * 3.0)
	lens_mat.set_shader_parameter("nitro", lens_nitro)
	rain_pm.direction = Vector3(0, -1, ratio * 0.8)
	if ui.garage_open:
		# garajda araba yandan-arkadan, yakından görünür
		cam_pos = cam_pos.lerp(car.position + Vector3(3.6, 1.5, 5.2), k)
		cam.position = cam_pos
		cam.look_at(car.position + Vector3(0, 0.6, -0.5))
		cam.fov = lerpf(cam.fov, 55.0, k)
		lens_mat.set_shader_parameter("speed", 0.0)
		return
	if state == "menu":
		# menüde sinematik çekim: kamera arabanın arkasından yanlarına yavaşça salınır
		var a := sin(alive * 0.12) * 0.9
		cam_pos = cam_pos.lerp(car.position + Vector3(sin(a) * 6.5, 1.6 + 0.4 * sin(alive * 0.2), cos(a) * 6.5), k)
		cam.position = cam_pos
		cam.look_at(car.position + Vector3(0, 1.4, -4.0)) # araba ekranın alt-ortasında, görev kartının altında
		cam.fov = lerpf(cam.fov, 60.0, k)
		lens_mat.set_shader_parameter("speed", 0.0)
		return
	# yol çalışmasında kamera alçalıp yaklaşır, kapalı şeride doğru hafif yatar: bariyerler yanından akar
	var wc := works_cam
	var roll := deg_to_rad(3.0) * wc * (1.0 if works_lane == 3 else -1.0)
	cam_x = lerpf(cam_x, car.position.x * 0.7, k)
	cam_pos = cam_pos.lerp(Vector3(cam_x, lerpf(3.3, 2.4, wc), lerpf(7.4, 6.2, wc)), 1.0 - exp(-8.0 * dt))
	var j := 0.02 * ratio * ratio + shake * 0.25 + boost * 0.03
	cam.position = cam_pos + Vector3(randf_range(-j, j), randf_range(-j, j), 0)
	cam.quaternion = cam.quaternion.slerp(Quaternion.from_euler(Vector3(deg_to_rad(lerpf(-12.0, -9.0, wc)), 0, roll)), k)
	cam.fov = lerpf(cam.fov, 58.0 + 18.0 * ratio + boost * 8.0 + wc * 6.0, 1.0 - exp(-5.0 * dt))
	lens_mat.set_shader_parameter("speed", clampf((kmh - 140.0) / 180.0, 0.0, 1.0))


func spawn_row() -> void:
	var lanes := OURS.filter(func(l): return not (works_on and l == works_lane)) # kapalı şeride araç çıkmaz
	lanes.shuffle()
	# iki şerit birden dolarsa geçmenin yolu karşı şerit ya da fren
	for i in (2 if randf() < 0.2 and lanes.size() == 2 else 1):
		if pool.is_empty():
			return
		place(pool.pop_back(), lanes[i], 1)


func spawn_oncoming() -> void:
	if not pool_on.is_empty():
		place(pool_on.pop_back(), ONCOMING.pick_random(), -1)


func place(c: Node3D, l: int, dir: int) -> void:
	c.set_meta("lane", l)
	c.set_meta("dir", dir)
	c.set_meta("ghost", false)
	c.position = Vector3(LANES[l], 0, SPAWN_Z - randf() * 8.0)
	c.rotation = Vector3.ZERO
	c.visible = true
	traffic.append(c)


# Çarpılan araç bizimle birlikte yavaşlar; darbeyle biraz öne itilip döner.
func hit_update(c: Node3D, dt: float) -> void:
	hit_push = move_toward(hit_push, 0.0, 15.0 * dt)
	c.position.z -= hit_push * dt
	c.rotation.y += hit_push * dt * 0.06


# --- Tünel ---

func build_tunnel() -> void:
	tunnel = Node3D.new()
	tunnel.visible = false
	var half := TUNNEL_LEN * 0.5
	var concrete := Build.mat(Color(0.18, 0.18, 0.19), 0.8)
	for s in [-1.0, 1.0]:
		Build.box(tunnel, Vector3(0.6, 7.5, TUNNEL_LEN), Vector3(s * 8.6, 3.75, -half), concrete)
		Build.box(tunnel, Vector3(14.6, 12.5, 1.5), Vector3(s * 16.2, 6.25, 0.0), concrete) # giriş cephesi
		Build.box(tunnel, Vector3(0.3, 0.3, 0.3), Vector3(s * 2.5, 8.3, 0.85), Build.mat(Color(0.1, 1.0, 0.3), 0.5, 0.0, 6.0)) # yeşil sinyal
	Build.box(tunnel, Vector3(17.8, 0.5, TUNNEL_LEN), Vector3(0, 7.5, -half), concrete)
	Build.box(tunnel, Vector3(17.8, 5.0, 1.5), Vector3(0, 10.0, 0.0), concrete)
	Build.box(tunnel, Vector3(7.0, 1.4, 0.15), Vector3(0, 10.2, 0.8), Build.mat(Color(0.03, 0.3, 0.12), 0.5, 0.0, 0.6))
	tunnel_sign = Label3D.new()
	tunnel_sign.font_size = 96
	tunnel_sign.pixel_size = 0.006
	tunnel_sign.position = Vector3(0, 10.2, 0.9)
	tunnel.add_child(tunnel_sign)
	var portal := OmniLight3D.new() # giriş cephesi karanlıkta kaybolmasın
	portal.light_color = Color(1.0, 0.6, 0.3)
	portal.light_energy = 3.0
	portal.omni_range = 26.0
	portal.position = Vector3(0, 9.0, 8.0)
	tunnel.add_child(portal)

	# Tavan lambaları tek MultiMesh: 80 lamba tek çizim çağrısı.
	var lamp := BoxMesh.new()
	lamp.size = Vector3(0.25, 0.1, 1.8)
	var points := []
	for i in int(TUNNEL_LEN / 6.0):
		for s in [-1.0, 1.0]:
			points.append(Vector3(s * 6.7, 7.2, -3.0 - i * 6.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = Build.multimesh(lamp, points)
	mmi.material_override = Build.mat(Color(1.0, 0.6, 0.25), 0.5, 0.0, 8.0)
	tunnel.add_child(mmi)
	# Mobile renderer mesh başına 8 omni ışık sınırı var; az ve güçlü ışık
	for i in int(TUNNEL_LEN / 40.0):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.6, 0.3)
		l.light_energy = 2.0
		l.omni_range = 22.0
		l.position = Vector3(0, 6.5, -20.0 - i * 40.0)
		tunnel.add_child(l)

	# Tavanın üstüne düşen yağmur damlaları burada söner, tünelin içine yağmur girmez.
	var dry := GPUParticlesCollisionBox3D.new()
	dry.size = Vector3(18.5, 30.0, TUNNEL_LEN)
	dry.position = Vector3(0, 22.5, -half)
	tunnel.add_child(dry)
	add_child(tunnel)


# --- Yol çalışması ---

# Koniler, bariyerler ve sarı lambalar MultiMesh: hangi şeridin kapandığına göre configure_works dizer.
func build_works() -> void:
	works = Node3D.new()
	works.visible = false
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = 0.24
	cone.height = 0.75
	var barrier := BoxMesh.new()
	barrier.size = Vector3(0.5, 0.9, 2.0)
	var bulb := BoxMesh.new()
	bulb.size = Vector3(0.18, 0.18, 0.18)
	works_amber = Build.mat(Color(1.0, 0.6, 0.05), 0.5, 0.0, 9.0)
	for item in [[cone, Build.mat(Color(1.0, 0.35, 0.05), 0.6, 0.0, 0.8), "cones"],
			[barrier, Build.mat(Color(0.7, 0.7, 0.68), 0.8), "barriers"],
			[bulb, works_amber, "lights"]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = item[0]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = item[1]
		works.add_child(mmi)
		set("works_" + item[2], mm)
	# kapalı şeridin başında sarı ok panosu
	works_board = Build.box(works, Vector3(2.6, 1.5, 0.15), Vector3.ZERO, Build.mat(Color(0.03, 0.03, 0.03), 0.8))
	works_arrow = Label3D.new()
	works_arrow.font_size = 160
	works_arrow.pixel_size = 0.008
	works_arrow.modulate = Color(1.0, 0.65, 0.1)
	works_arrow.outline_size = 0
	works.add_child(works_arrow)
	# uyarı levhaları: 180 ve 90 m önce, sağ kenarda
	for item in [[180.0, "YOL ÇALIŞMASI"], [90.0, "ŞERİT KAPANIYOR"]]:
		Build.box(works, Vector3(0.15, 3.0, 0.15), Vector3(8.6, 1.5, item[0]), Build.mat(Color(0.2, 0.2, 0.2), 0.6))
		Build.box(works, Vector3(3.4, 1.4, 0.1), Vector3(8.6, 3.4, item[0]), Build.mat(Color(1.0, 0.55, 0.05), 0.6, 0.0, 1.5))
		var t := Label3D.new()
		t.text = item[1]
		t.font_size = 64
		t.pixel_size = 0.006
		t.modulate = Color(0.05, 0.05, 0.05)
		t.outline_size = 0
		t.position = Vector3(8.6, 3.4, item[0] + 0.07)
		works.add_child(t)
	add_child(works)


func configure_works(l: int) -> void:
	# kapalı şerit lane 3 (sağ dış) ise koniler dış çizgiden içeri, lane 2 ise orta çizgiden dışarı daralır
	var inner := 3.5 + (0.35 if l == 3 else -0.35) # bariyerin durduğu şerit çizgisi
	var cones := []
	for i in 16:
		var f := i / 15.0
		var x := (ROAD_EDGE - 3.5 * f - 0.3) if l == 3 else (3.5 * f + 0.3)
		cones.append(Transform3D(Basis(), Vector3(x, 0.37, -f * WORK_TAPER)))
	var barriers := []
	var lights := []
	var z := -WORK_TAPER
	while z > -WORK_LEN:
		barriers.append(Transform3D(Basis(), Vector3(inner, 0.45, z)))
		if barriers.size() % 4 == 0:
			lights.append(Transform3D(Basis(), Vector3(inner, 1.0, z)))
		z -= 2.2
	for pair in [[works_cones, cones], [works_barriers, barriers], [works_lights, lights]]:
		var mm: MultiMesh = pair[0]
		mm.instance_count = pair[1].size()
		for i in pair[1].size():
			mm.set_instance_transform(i, pair[1][i])
	var lane_x: float = LANES[l]
	works_board.position = Vector3(lane_x, 1.6, -WORK_TAPER * 0.3)
	works_arrow.position = Vector3(lane_x, 1.6, -WORK_TAPER * 0.3 + 0.1)
	works_arrow.text = "<<<" if l == 3 else ">>>" # açık şeride doğru


func start_works() -> void:
	works_on = true
	works_lane = 3 if randf() < 0.65 else 2
	works_start = travel + WORK_WARN
	works_warned = WORK_WARN
	works_close = 0.0
	configure_works(works_lane)
	next_tunnel = maxf(next_tunnel, works_start + WORK_LEN + 400.0)
	next_siren = maxf(next_siren, works_start + WORK_LEN + 100.0)
	ui.toast("İLERİDE YOL ÇALIŞMASI", Color(1.0, 0.75, 0.2))
	buzz(80, 0.6)


func update_works(dt: float) -> void:
	if not works_on:
		works_cam = move_toward(works_cam, 0.0, dt * 1.5)
		if state == "play" and travel > next_works and not tunnel_on:
			start_works()
		else:
			ui.set_warning("")
		return
	var d := works_start - travel # konilere kalan mesafe; içerideyken negatif
	var into := -d
	works.visible = d < 330.0
	works.position.z = -d
	works_amber.emission_energy_multiplier = 9.0 if fmod(alive * 2.5, 1.0) < 0.5 else 0.8
	works_arrow.visible = fmod(alive * 2.0, 1.0) < 0.6
	var side := "SAĞ" if works_lane == 3 else "SOL"
	if d > 0.0:
		ui.set_warning("YOL ÇALIŞMASI  %d m\n%s ŞERİT KAPALI" % [int(d), side], d < 300.0)
		for mark in [1000.0, 500.0, 200.0]:
			if d < mark and works_warned >= mark:
				buzz(70, 0.6)
		works_warned = minf(works_warned, d)
	elif into < WORK_LEN:
		ui.set_warning("YOL ÇALIŞMASI  ·  %s ŞERİT KAPALI" % side, true)
	else:
		ui.set_warning("")
	works_cam = move_toward(works_cam, 1.0 if into > -60.0 and into < WORK_LEN + 20.0 else 0.0, dt * 1.5)
	if state == "play" and into > 0.0 and into < WORK_LEN:
		# kapalı bölge konilerle daralır: f 0'dan 1'e, sonra bariyer boyunca tam şerit
		var f := clampf(into / WORK_TAPER, 0.0, 1.0)
		var lo := (ROAD_EDGE - 3.5 * f) if works_lane == 3 else 0.0
		var hi := ROAD_EDGE if works_lane == 3 else 3.5 * f
		var hw: float = car.get_meta("half_w")
		if f > 0.05 and car.position.x + hw > lo + 0.25 and car.position.x - hw < hi - 0.25:
			ui.toast("YOL ÇALIŞMASINA GİRDİN", Color(1.0, 0.6, 0.2))
			crash(null)
		elif f >= 1.0:
			# bariyerin dibinden geçmek: dar geçiş bonusu
			var gap := (lo - (car.position.x + hw)) if works_lane == 3 else ((car.position.x - hw) - hi)
			if gap < 0.7:
				works_close += kmh / 3.6 * dt
				if works_close > 40.0:
					works_close = 0.0
					score += 150
					ui.popup("DAR GEÇİŞ  +150", Color(1.0, 0.75, 0.2))
					play("whoosh", 1.3)
					buzz(20, 0.3)
	if into > WORK_LEN + 40.0:
		works_on = false
		works.visible = false
		ui.set_warning("")
		next_works = travel + randf_range(3000.0, 5000.0)


# --- Polis / ambulans ---

func build_sirens() -> void:
	var red := Build.mat(Color(1.0, 0.05, 0.05), 0.5, 0.0, 10.0)
	var blue := Build.mat(Color(0.1, 0.25, 1.0), 0.5, 0.0, 10.0)
	var siren_stream: AudioStreamOggVorbis = preload("res://audio/siren.ogg")
	siren_stream.loop = true
	for kind in ["police", "ambulance"]:
		var s := make_kenney(kind)
		var top: float = s.get_meta("top")
		var bar_z := -0.33 if kind == "police" else -1.6 # polis: tavan ortası, ambulans: kasanın ön üstü
		s.set_meta("red", Build.box(s, Vector3(0.5, 0.14, 0.25), Vector3(-0.35, top + 0.02, bar_z), red))
		s.set_meta("blue", Build.box(s, Vector3(0.5, 0.14, 0.25), Vector3(0.35, top + 0.02, bar_z), blue))
		var l := OmniLight3D.new()
		l.light_energy = 3.0
		l.omni_range = 16.0
		l.position = Vector3(0, top + 0.5, bar_z)
		s.add_child(l)
		s.set_meta("light", l)
		# konumlu siren sesi: yanımızdan geçerken doppler ile perdesi düşer
		var snd := AudioStreamPlayer3D.new()
		snd.stream = siren_stream
		snd.bus = "World"
		snd.volume_db = -4.0
		snd.unit_size = 10.0
		snd.max_distance = 250.0
		snd.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		s.add_child(snd)
		s.set_meta("snd", snd)
		s.visible = false
		add_child(s)
		sirens.append(s)


# Siren bizim yönde, bizim şeridimizde arkadan gelir; yol vermek oyuncunun işi.
func spawn_siren() -> void:
	siren = sirens.pick_random()
	siren_red = siren.get_meta("red")
	siren_blue = siren.get_meta("blue")
	siren_light = siren.get_meta("light")
	var l: int = (2 if car.position.x < 3.5 else 3) if car.position.x > 0.0 else OURS.pick_random()
	siren.set_meta("lane", l)
	siren.set_meta("dir", 1)
	siren.set_meta("ghost", false)
	siren.set_meta("blocked", false)
	siren.position = Vector3(LANES[l], 0, 30.0)
	siren.rotation = Vector3.ZERO
	siren.visible = true
	(siren.get_meta("snd") as AudioStreamPlayer3D).play(randf() * 30.0)


# Sirenin önü trafikle tıkalı mı (şerit değiştirmesi gerekir mi).
func traffic_blocks(l: int) -> bool:
	for c in traffic:
		if c.get_meta("lane") == l and c.get_meta("dir") > 0 \
				and c.position.z > siren.position.z - 60.0 and c.position.z < siren.position.z + 8.0:
			return true
	return false


func update_siren(dt: float) -> void:
	if siren == hit_car:
		hit_update(siren, dt)
	else:
		var before := siren.position.z - car.position.z
		siren.position.z -= SIREN_REL * dt
		var l: int = siren.get_meta("lane")
		# yalnız trafik yüzünden şerit değiştirir; bizim şeridimize girmez, önümüzde kalırsa bekler
		var other := 5 - l # 2 <-> 3
		var dz := siren.position.z - car.position.z
		if traffic_blocks(l) and not traffic_blocks(other) and not (other in player_lanes() and dz > -30.0):
			l = other
			siren.set_meta("lane", l)
		# ponytail: iki şerit de tıkalıysa öndeki aracın arkasında bekler; trafiği kenara çektirme eklenebilir
		for c in traffic:
			var gap: float = siren.position.z - c.position.z
			if c.get_meta("lane") == l and c.get_meta("dir") > 0 and gap > -4.3 and gap < 9.0:
				siren.position.z = c.position.z + 9.0
		# yolunu tıkıyorsak arkamızda bekler; kenara çekilirsek geçer
		dz = siren.position.z - car.position.z
		if absf(siren.position.x - car.position.x) < side_gap(siren) + 0.3 and dz > 0.0 and dz < 14.0:
			siren.position.z = move_toward(siren.position.z, car.position.z + 12.0, 30.0 * dt)
			if state == "play" and not siren.get_meta("blocked"):
				siren.set_meta("blocked", true)
				ui.toast("SİRENE YOL VER!", Color(1.0, 0.4, 0.4))
				buzz(60, 0.5)
		siren.position.x = lerpf(siren.position.x, LANES[l], 1.0 - exp(-6.0 * dt))
		if state == "play" and not siren.get_meta("ghost"):
			if touching(siren):
				hit(siren, -SIREN_REL * 3.6, before) # bizden hızlı: değmek hep hafif
			elif before > 0.0 and siren.position.z - car.position.z <= 0.0 and siren.get_meta("blocked"):
				# yalnız gerçekten yolunu tıkayıp sonra kenara çekildiysek
				score += 200
				ui.popup("YOL VERDİN  +200", Color(0.5, 0.8, 1.0))
				play("confirm")
				mission("siren", 1)
	var on := fmod(alive * 3.0, 1.0) < 0.5
	siren_red.visible = on
	siren_blue.visible = not on
	siren_light.light_color = Color(1.0, 0.1, 0.1) if on else Color(0.15, 0.3, 1.0)
	# arkamızdaki siren görünmez: ekranın altı kırmızı-mavi yanıp söner
	var behind := siren.position.z - car.position.z
	lens_mat.set_shader_parameter("siren_amt", clampf((45.0 - behind) / 30.0, 0.0, 1.0) if behind > 0.0 else 0.0)
	lens_mat.set_shader_parameter("siren_col", Color(1.0, 0.1, 0.1) if on else Color(0.15, 0.3, 1.0))
	var faded: bool = siren.get_meta("ghost") and fade_out(siren, dt)
	if (siren.position.z < SPAWN_Z or faded) and siren != hit_car:
		siren.visible = false
		(siren.get_meta("snd") as AudioStreamPlayer3D).stop()
		siren = null
		next_siren = travel + randf_range(800.0, 2000.0)


# --- Araçlar ---

func set_player_car(id: String, paint_index: int) -> void:
	var x: float = LANES[2]
	if car:
		x = car.position.x
		car.queue_free()
	flames.clear()
	car = make_player(id, paint_index)
	car.position.x = x
	add_child(car)
	build_player_extras(car.get_meta("rear"))


func make_player(id: String, paint_index: int) -> Node3D:
	var root := Node3D.new()
	player_mat = ShaderMaterial.new()
	player_mat.shader = preload("res://car.gdshader")
	var model: Node3D
	var rear := 2.3
	var half_w := 0.96 # R34 gövdesi 1,92 m
	if id == "r34":
		# R34 modeli (cars/r34.glb, CC BY, bkz. CREDITS.md)
		model = preload("res://cars/r34.glb").instantiate()
		var m0: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
		player_mat.set_shader_parameter("albedo_tex", (m0.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture)
	else:
		model = load("res://cars/kenney/%s.glb" % id).instantiate()
		model.scale = KENNEY_SCALE
		rear = kenney_rear(model)
		var body: MeshInstance3D = model.find_children("body", "MeshInstance3D", true, false)[0]
		half_w = body.get_aabb().size.x * 0.5 * KENNEY_SCALE.x
		player_mat.set_shader_parameter("albedo_tex", preload("res://cars/kenney/Textures/colormap.png"))
		player_mat.set_shader_parameter("tail_uv", KENNEY_TAIL)
		player_mat.set_shader_parameter("body_v", 0.0)
		player_mat.set_shader_parameter("paint_uv", PAINT_UV[id])
	model.rotation.y = PI # modellerin önü +z, oyunda ön -z
	root.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = player_mat
	player_mat.set_shader_parameter("use_paint", 0.0 if paint_index == 0 else 1.0)
	player_mat.set_shader_parameter("paint", Profile.PAINTS[paint_index][1])
	add_blob(root, rear)
	for s in [-1.0, 1.0]:
		Build.streak(root, Vector3(s * 0.5, 0, rear), Color(1.0, 0.08, 0.04), 0.6, 7.0, 1.5)
	root.set_meta("rear", rear)
	root.set_meta("half_w", half_w)
	return root


func build_player_extras(rear: float) -> void:
	if flame_mat == null:
		flame_mat = Build.mat(Color(0.45, 0.5, 1.0), 0.5, 0.0, 4.0)
	var flame := SphereMesh.new()
	flame.radius = 0.07
	flame.height = 0.14
	for s in [-1.0, 1.0]:
		var f := MeshInstance3D.new()
		f.mesh = flame
		f.material_override = flame_mat
		f.position = Vector3(s * 0.4, 0.3, rear + 0.15)
		car.add_child(f)
		flames.append(f)
	Build.streak(car, Vector3(0, 0, rear), Color(0.5, 0.4, 1.0), 0.6, 5.0, 0.4)
	var head := SpotLight3D.new()
	head.light_color = Color(0.85, 0.9, 1.0)
	head.light_energy = 5.0
	head.spot_range = 50.0
	head.spot_angle = 28.0
	head.position = Vector3(0, 0.7, -rear)
	head.rotation_degrees.x = -6.0
	car.add_child(head)
	# arabanın kendi dolgu ışığı: lamba uzaktayken de gövde seçilsin
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 1.2
	fill.omni_range = 7.0
	fill.position = Vector3(0, 3.0, 3.5)
	car.add_child(fill)


# Kenney Car Kit modeli (cars/kenney, CC0). Modelin önü +z: bizim yönde 180° çevrilir, arkası bize
# döner; karşı yönde (oncoming) çevrilmez, farları yanık olarak üstümüze gelir.
func make_kenney(model_name: String, oncoming := false) -> Node3D:
	var root := Node3D.new()
	var model: Node3D = models[model_name].instantiate()
	model.rotation.y = 0.0 if oncoming else PI
	model.scale = KENNEY_SCALE
	root.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = kenney_mat
	var rear := kenney_rear(model)
	var body: MeshInstance3D = model.find_children("body", "MeshInstance3D", true, false)[0]
	var aabb := body.get_aabb()
	root.set_meta("top", (aabb.end.y + body.position.y) * KENNEY_SCALE.y)
	root.set_meta("half_w", aabb.size.x * 0.5 * KENNEY_SCALE.x)
	add_blob(root, rear)
	if oncoming:
		var front := (aabb.end.z + body.position.z) * KENNEY_SCALE.z
		for s in [-1.0, 1.0]:
			Build.box(root, Vector3(0.32, 0.14, 0.05), Vector3(s * 0.55 * KENNEY_SCALE.x, 0.55, front + 0.02), head_mat)
			Build.streak(root, Vector3(s * 0.55 * KENNEY_SCALE.x, 0, front), Color(1.0, 0.9, 0.7), 0.6, 10.0, 1.3)
	else:
		for s in [-1.0, 1.0]:
			Build.streak(root, Vector3(s * 0.55 * KENNEY_SCALE.x, 0, rear), Color(1.0, 0.08, 0.04), 0.5, 7.0, 1.5)
	return root


func kenney_rear(model: Node3D) -> float:
	var body: MeshInstance3D = model.find_children("body", "MeshInstance3D", true, false)[0]
	return -(body.get_aabb().position.z + body.position.z) * KENNEY_SCALE.z


func add_blob(root: Node3D, rear: float) -> void:
	var blob := Build.plane(root, Vector2(2.4, rear * 2.0 + 0.8), Vector3(0, 0.03, 0), blob_mat)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Ses ---

func build_audio() -> void:
	# Dünya sesleri (motor, siren) "World" bus'ından geçer; tünelde yankı açılır.
	var bus := AudioServer.get_bus_index("World")
	if bus == -1: # bus'lar sahne yenilense de kalır, bir kez kurulur
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "World")
		AudioServer.set_bus_send(bus, "Master")
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.6
		rv.wet = 0.0
		AudioServer.add_bus_effect(bus, rv)
	reverb = AudioServer.get_bus_effect(bus, 0)
	AudioServer.set_bus_mute(0, not Profile.sound)
	var engine: AudioStreamWAV = preload("res://audio/engine.wav")
	engine.loop_mode = AudioStreamWAV.LOOP_FORWARD
	engine.loop_end = int(engine.get_length() * engine.mix_rate)
	engine_snd = add_player(engine, -16.0, "World")
	engine_snd.play()
	var rain_stream: AudioStreamOggVorbis = preload("res://audio/rain.ogg")
	rain_stream.loop = true
	rain_snd = add_player(rain_stream, -3.0, "Master")
	rain_snd.play()
	for n in ["thunder", "crash", "whoosh", "boost", "click", "confirm"]:
		var p := add_player(load("res://audio/%s.%s" % [n, "wav" if n == "whoosh" else "ogg"]), 0.0, "Master")
		p.max_polyphony = 3
		sfx[n] = p
	cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP


func add_player(stream: AudioStream, db: float, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.bus = bus
	add_child(p)
	return p


func play(n: String, pitch := 1.0, db := 0.0) -> void:
	var p: AudioStreamPlayer = sfx[n]
	p.pitch_scale = pitch
	p.volume_db = db
	p.play()


func update_audio(dt: float) -> void:
	reverb.wet = tunnel_in * 0.35
	rain_snd.volume_db = linear_to_db(maxf(rain_level * (1.0 - tunnel_in * 0.85), 0.001)) - 3.0
	var target := -60.0 if state == "over" else (-16.0 if state == "menu" else -8.0)
	engine_snd.volume_db = move_toward(engine_snd.volume_db, target, dt * (40.0 if state == "over" else 20.0))
	# devir ve vitese göre perde: vites atınca devir düşer, ses de düşer
	engine_snd.pitch_scale = 0.55 + rpm * 0.75 + gear * 0.05 + (0.15 if nitro_t > 0.0 else 0.0)
	if thunder_in > 0.0:
		thunder_in -= dt
		if thunder_in <= 0.0:
			sfx.thunder.volume_db = -2.0 - tunnel_in * 20.0
			sfx.thunder.play()


# --- Sahne kurulumu ---

func build_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NIGHT_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.16, 0.28)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_light_color = NIGHT_SKY
	env.fog_density = 0.016
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.1
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.8
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.5, 0.6, 1.0)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-40, 30, 0)
	add_child(moon)

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH # telefon en-boy oranı ne olursa olsun yol genişliği sabit
	cam.near = 0.1
	cam.far = 320.0
	cam.position = cam_pos
	cam.rotation_degrees.x = -12.0
	cam.fov = 60.0
	add_child(cam)

	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(16, 420)
	road.mesh = rm
	road.position.z = -190.0
	road_mat = ShaderMaterial.new()
	road_mat.shader = preload("res://road.gdshader")
	road.material_override = road_mat
	add_child(road)

	var rail := Build.mat(Color(0.35, 0.37, 0.4), 0.3, 0.7)
	for s in [-1.0, 1.0]:
		Build.box(self, Vector3(0.12, 0.3, 420), Vector3(s * 7.8, 0.65, -190), rail)


func build_rain() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 1500
	rain.lifetime = 1.1
	rain.preprocess = 1.1
	rain.position = Vector3(0, 18, -30) # damlalar görüş alanının üstünde doğsun, tavan gibi görünmesin
	rain.visibility_aabb = AABB(Vector3(-16, -30, -40), Vector3(32, 40, 100))
	rain_pm = ParticleProcessMaterial.new()
	rain_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_pm.emission_box_extents = Vector3(14, 8, 36)
	rain_pm.spread = 3.0
	rain_pm.initial_velocity_min = 26.0
	rain_pm.initial_velocity_max = 34.0
	rain_pm.gravity = Vector3(0, -10, 0)
	rain_pm.particle_flag_align_y = true
	rain_pm.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	rain.process_material = rain_pm
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.75, 0.85, 1.0, 0.15)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	rain.draw_pass_1 = q
	add_child(rain)


func build_lens() -> void:
	var fx := CanvasLayer.new()
	var lens := ColorRect.new()
	lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lens_mat = ShaderMaterial.new()
	lens_mat.shader = preload("res://lens.gdshader")
	lens.material = lens_mat
	fx.add_child(lens)
	add_child(fx)
