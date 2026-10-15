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
const LANES := [-5.25, -1.75, 1.75, 5.25, 8.75] # 4: ara sıra açılan 3. şerit (bizim yön)
const ONCOMING := [0, 1]
const OURS := [2, 3]
const LANE_KMH := [80.0, 65.0, 85.0, 60.0, 75.0] # şerit başına sabit hız: aynı şeritte araçlar üst üste binmez
const ROAD_EDGE := 7.0 # dış şerit çizgisi
const ONCOMING_MULT := 1.5 # karşı şeritte giderken puan çarpanı
const GEAR_FRAC := [0.0, 0.2, 0.36, 0.52, 0.68, 0.84, 1.12] # vites eşikleri, aracın tavan hızına oranla; 6. viteste nitro devri kırmızıya dayar
const SHIFT_RPM := 0.62 # vites atınca devir buraya iner, sıfırlanmaz
const MIN_KMH := 50.0
const MENU_KMH := 140.0
const PROP_COUNT := 9
const SPAWN_Z := -260.0
const TUNNEL_LEN := 240.0
const TUNNEL_NAMES := ["CERCEYN TUNNEL", "NIGHT BAY TUNNEL", "RAIN PASS TUNNEL"]
const SIREN_REL := 16.0 # siren aracı bizi bu kadar m/sn farkla geçer
const TRAFFIC_MODELS := ["sedan", "sedan-sports", "hatchback-sports", "suv", "suv-luxury", "taxi", "van", "truck"]
const TRUCK_MODELS := ["garbage-truck", "delivery", "truck-flat", "delivery-flat"]
const TRUCK_SCALE := Vector3(1.4, 1.45, 2.2) # kamyon: uzun ve yüksek, sollaması zor
const KENNEY_SCALE := Vector3(1.25, 1.2, 1.5) # Kenney arabaları oyuncak oranlı; boyu uzatıp gerçeğe yaklaştır
const KENNEY_TAIL := Vector4(0.25, 0.75, 0.375, 1.0) # Kenney paletinde kırmızı stop lambası karesi
# Garaj araçlarında boyanacak gövde rengi karesi (Kenney paleti)
const PAINT_UV := {
	"sedan-sports": Vector4(0.75, 0.25, 0.875, 0.5),
	"hatchback-sports": Vector4(0.375, 0.25, 0.5, 0.5),
	"race": Vector4(0.75, 0.25, 0.875, 0.5),
	"race-future": Vector4(0.875, 0.25, 1.0, 0.5),
	"taxi": Vector4(0.5, 0.25, 0.625, 0.5),
	"suv-luxury": Vector4(0.5, 0.25, 0.625, 0.5),
	"police": Vector4(0.75, 0.5, 0.875, 0.75),
}
const NEAR_MIN_KMH := 120.0
const COMBO_WINDOW := 3.0
const NITRO_TIME := 3.5
const NITRO_KMH := 60.0
const CP_GAP := 2000.0 # zamana karşı: kontrol noktaları arası (m)
const RADAR_MIN_KMH := 200.0 # radarın önünden bundan hızlı geçmek bonus
const CHASE_TIME := 20.0 # polis kovalamacası: bu kadar dayanırsan kaçtın
# istasyon -> [dosya, parça adı]
const MUSIC := {
	1: [["synth_midnight_drive", "Midnight Drive"], ["synth_space_city", "Space City"], ["synth_wave", "Synth Wave"]],
	2: [["lofi_hiphop", "lofi hip hop"], ["lofi_chill", "Chill lofi"], ["lofi_midnight_cruiser", "Midnight Cruiser"]],
}
const LENS_FULL := preload("res://lens.gdshader")
const LENS_LITE := preload("res://lens_lite.gdshader") # ekran kopyası okumaz: telefonda büyük kazanç
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
const CONTRA := -1 # works_lane: bizim iki şerit kapalı, karşı yönün iç şeridi (1) bize verilir
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
var top_now := 230.0 # o anki tavan hız (nitrosuz)
var pop_t := 0.0 # vites atınca egzozdan kısa alev
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
var diggers: Array[Node3D] = [] # yol çalışmasındaki kepçeler
var lens_rect: ColorRect
var loader: Node3D # yol çalışmasındaki yükleyici kepçe
var road_side: Array[MeshInstance3D] = [] # 3. şerit parçaları
var road_side_mat: ShaderMaterial
var refl_vp: SubViewport # yüksek grafik: yolun aynadaki görüntüsü
var refl_cam: Camera3D
var widen_a := -1e9 # 3. şerit bölgesi (travel cinsinden): a'da açılmaya başlar, b'de kapanmış olur
var widen_b := -1e9
var next_widen := 0.0
var widen_said := 0 # uyarılar bir kez
# yarış modu: trafikte bir rakiple RACE_LEN metrelik kapışma
const RACE_LEN := 4000.0
const RIVAL_MODELS := ["race", "race-future", "sedan-sports", "hatchback-sports"]
var race_on := false
var finished := false # yarış bitti: kaza değil, araba dönmesin
var rival: Node3D
var rival_kmh := 0.0
var rival_dist := 0.0 # rakibin yarışta aldığı yol
var rival_lane := 3
var rival_nitro_t := 0.0
var rival_nitro_cd := 8.0
var rival_bump_t := 0.0
var rival_think := 0.0
var rival_stun := 0.0 # vurulunca bu kadar sn hızlanamaz, yalpalar
var benching := false
var weather := "sağanak"
var weather_t := 45.0
var rain_level := 1.0
var wetness := 1.0
var flash_t := 99.0
var flash_glow := 0.0 # arkamızdaki aracın selektörü: ekranın altı beyaz yanıp söner
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
var stats := {} # seçili aracın ve geliştirmelerinin sürüş değerleri
var time_left := 30.0 # zamana karşı modu
var cp_next := 0.0 # sıradaki kontrol noktası (travel cinsinden)
var cp_count := 0
var gate: Node3D # kontrol noktası kapısı, bir kez kurulur
var radar: Node3D
var radar_on := false
var radar_at := 1e9 # radarın yeri (travel cinsinden)
var patrol: Node3D # trafikte devriye polis; çok hızlı sollanırsa kovalar
var patrol_active := false
var next_patrol := 0.0 # devriye en erken bu yolda çıkar
var chase_on := false
var chase_t := 0.0
var police_kmh := 0.0
var patrol_want := 0.0 # kovalayan polisin gittiği x
var patrol_hold := 0.0 # boş şeride geçince bu kadar sn o şeritte kalır
var music: AudioStreamPlayer
var track := 0
var wipe := 1.0 # kokpitte silecek geçtikçe camdaki damlalar azalır
var wipe_phase := 0.0
var paused := false
var max_scale := 1.0 # grafik ayarının izin verdiği en yüksek 3B çözünürlük
var perf_t := 0.0
var perf_good := 0

var car: Node3D
var player_mat: ShaderMaterial
var flame_mat: StandardMaterial3D
var flames: Array[Node3D] = []
var core_mat: StandardMaterial3D
var spray: GPUParticles3D
var cam: Camera3D
var env: Environment
var moon: DirectionalLight3D
var rain: GPUParticles3D
var rain_pm: ParticleProcessMaterial
var road_mat: ShaderMaterial
var lens_mat: ShaderMaterial
var kenney_mat: ShaderMaterial
var glow_mats := {} # far hâlesi malzemeleri, renge göre bir kez
var glow_tex: GradientTexture2D
var beam_mats := {} # far ışığı malzemeleri, renk+güce göre bir kez
var blob_mat: StandardMaterial3D
var props: Array[Node3D] = []
var traffic: Array[Node3D] = []
var pool: Array[Node3D] = [] # bizim yöndeki boşta araçlar
var pool_on: Array[Node3D] = [] # karşı yöndeki boşta araçlar (farları yanık, önü bize dönük)
var ui # ui.gd


func _ready() -> void:
	Engine.time_scale = 1.0 # öğretici ağır çekimdeyken sahne yenilenirse kalmasın
	region_offset = (randi() % 4) * Regions.LEN
	for n in TRAFFIC_MODELS + TRUCK_MODELS + RIVAL_MODELS + ["police", "ambulance", "firetruck", "tractor-shovel"]:
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
	glow_tex = GradientTexture2D.new() # far hâlesi: ortası parlak, kenara doğru sönen yuvarlak
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(0.5, 0.0)
	glow_tex.gradient = Gradient.new()
	glow_tex.gradient.set_color(0, Color(1, 1, 1, 1))
	glow_tex.gradient.set_color(1, Color(1, 1, 1, 0))
	glow_tex.gradient.add_point(0.25, Color(1, 1, 1, 0.45))

	load_stats()
	build_world()
	build_reflection()
	for i in PROP_COUNT:
		var p := Regions.make_chunk(i)
		p.position.z = 30.0 - i * Regions.GAP
		Regions.configure(p, region_at(travel - p.position.z))
		add_child(p)
		props.append(p)
	set_player_car(Profile.car, Profile.paint)
	car.position.x = target_x
	# her beş araçtan biri kamyon
	for i in 28:
		var oncoming := i >= 18
		var c := make_kenney(TRUCK_MODELS.pick_random(), oncoming, TRUCK_SCALE) if i % 5 == 0 \
			else make_kenney(TRAFFIC_MODELS.pick_random(), oncoming)
		c.visible = false
		add_child(c)
		(pool_on if oncoming else pool).append(c)
	pool.shuffle()
	pool_on.shuffle()
	build_audio()
	build_tunnel()
	build_works()
	build_sirens()
	build_gate()
	build_radar()
	build_music()
	build_rain()
	build_lens()
	apply_settings()
	get_tree().quit_on_go_back = false # geri tuşu on_back'e gider, uygulamayı kapatmaz
	ui = preload("res://ui.gd").new()
	add_child(ui)
	if Profile.autostart:
		Profile.autostart = false
		start_run()
	else:
		ui.show_menu()
	warm(true)
	if OS.is_debug_build() and FileAccess.file_exists("user://bench"):
		DirAccess.remove_absolute("user://bench")
		bench()


# Test: bulunduğumuz yeri r bölgesine taşır, bütün çevre parçalarını yeniden kurar (yalnız debug).
func dbg_region(r: int) -> void:
	if not OS.is_debug_build():
		return
	region_offset = fposmod(r * Regions.LEN - travel + 200.0, 4.0 * Regions.LEN)
	for p in props:
		Regions.configure(p, region_at(travel - p.position.z))
		Regions.set_widen(p, widen_mode(travel - p.position.z))


# Test: hemen önümüzde 3. şerit açar (yalnız debug).
func dbg_widen() -> void:
	if not OS.is_debug_build():
		return
	widen_a = ceilf((travel + 40.0 - 30.0) / Regions.GAP) * Regions.GAP + 30.0
	widen_b = widen_a + Regions.GAP * 8
	dbg_region(region_at(travel))


# Yalnız debug build, user://bench dosyası varsa: her efekti tek tek kapatıp GPU süresini logcat'e yazar.
# Tablette: adb shell run-as com.bercedev.foreverspeed touch files/bench, sonra uygulamayı aç.
func bench() -> void:
	benching = true
	var vp := get_viewport()
	var rid := vp.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	vp.scaling_3d_scale = 0.75
	var meshes := find_children("*", "MeshInstance3D", true, false)
	var road := meshes.filter(func(m): return m.material_override == road_mat)
	var streaks := meshes.filter(func(m): return m.material_override is ShaderMaterial and m.material_override.shader == Build.streak_shader)
	var lamps := props.filter(func(p): return p.has_meta("lamp_light")).map(func(p): return p.get_meta("lamp_light"))
	var lights := find_children("*", "Light3D", true, false)
	var saved := {} # gizlenmeden önceki görünürlük: zaten kapalı olan (siren vb.) geri açılmasın
	var hide := func(nodes: Array, on: bool) -> void:
		for n in nodes:
			if on:
				saved[n] = n.visible
				n.visible = false
			else:
				n.visible = saved[n]
	var steps := [
		["taban", func(_on): pass],
		["olcek 0.5", func(on): vp.scaling_3d_scale = 0.5 if on else 0.75],
		["olcek 1.0", func(on): vp.scaling_3d_scale = 1.0 if on else 0.75],
		["lamba isigi yok", func(on): hide.call(lamps, on)],
		["tum isiklar yok", func(on): hide.call(lights, on)],
		["yol yok", func(on): hide.call(road, on)],
		["yansima seritleri yok", func(on): hide.call(streaks, on)],
		["cevre yok", func(on): hide.call(props, on)],
		["araba yok", func(on): car.visible = not on],
		["yagmur yok", func(on): rain.visible = not on],
		["lens yok", func(on): lens_rect.visible = not on],
		["arayuz yok", func(on): ui.visible = not on],
		["glow yok", func(on): env.glow_enabled = not on],
	]
	await get_tree().create_timer(4.0).timeout
	for st in steps:
		st[1].call(true)
		await get_tree().create_timer(0.8).timeout
		var gpu := 0.0
		var cpu := 0.0
		var n := 0
		var until := Time.get_ticks_msec() + 2500
		while Time.get_ticks_msec() < until:
			if not is_inside_tree():
				return # sahne yeniden yüklendi
			await get_tree().process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			n += 1
		print("[bench] %s: gpu=%.1fms cpu=%.1fms fps=%d" % [st[0], gpu / n, cpu / n, Engine.get_frames_per_second()])
		st[1].call(false)
	print("[bench] bitti")
	benching = false


func _process(dt: float) -> void:
	if warmup > 0:
		warmup -= 1
		if warmup == 0:
			warm(false)
	alive += dt
	update_perf(dt)
	update_speed(dt)
	var step := kmh / 3.6 * dt
	travel += step
	set_road("offset", fmod(travel, 900.0))
	if state == "play":
		update_run(step, dt)
	elif state == "over":
		crash_time += dt
	if state == "play" and siren == null and travel > next_siren and not works_on and not chase_on \
			and Profile.mode != "race": # menüde ve yarışta siren yok
		spawn_siren()
	update_tunnel(step, dt)
	update_works(dt)
	update_widen()
	update_gate()
	update_radar()
	update_props(step)
	update_traffic(step, dt)
	if siren:
		update_siren(dt)
	elif not chase_on:
		lens_mat.set_shader_parameter("siren_amt", flash_glow)
		if flash_glow > 0.0:
			lens_mat.set_shader_parameter("siren_col", Color(1.0, 0.95, 0.85))
	update_player(dt)
	update_daylight(dt)
	update_weather(dt)
	update_camera(dt)
	update_reflection()
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
		target_x = clampf(target_x + e.relative.x * DRAG_GAIN, left_limit(), right_limit())
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
	load_stats()
	if Profile.mode != "free":
		next_works = travel + randf_range(1800.0, 2600.0) # ilk yol çalışması oyunun ~2. km'sinde
	time_left = 30.0
	cp_count = 0
	cp_next = travel + CP_GAP
	radar_at = travel + randf_range(800.0, 1600.0)
	next_siren = travel + randf_range(600.0, 1200.0)
	next_patrol = travel + randf_range(900.0, 1600.0)
	next_widen = travel + randf_range(500.0, 1200.0)
	if Profile.mode == "race":
		start_race()
	ui.show_play()


# Seçili aracın temel değerleri ve garajdaki geliştirmeleri.
func load_stats() -> void:
	var c := Profile.car_info(Profile.car)
	var lv := func(k): return Profile.level(Profile.car, k)
	stats = {
		"top": c.top + lv.call("speed") * 8.0,
		"accel": c.accel * (1.0 + lv.call("accel") * 0.1),
		"brake": 1.0 + lv.call("brake") * 0.15,
		"nitro_time": NITRO_TIME + lv.call("nitro") * 0.5,
	}


func restart() -> void:
	get_tree().paused = false # duraklatma sahne yenilense de kalır
	Profile.autostart = true
	get_tree().reload_current_scene()


func to_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


# c: çarpılan araç; yol çalışması bariyerine çarpınca null.
func crash(c: Node3D, reason := "KAZA", crashed := true) -> void:
	if state != "play":
		return
	state = "over"
	finished = not crashed
	braking = false
	nitro_t = 0.0
	close_tip()
	hit_car = c
	if crashed:
		shake = 0.5
		hit_push = clampf(kmh / 3.6 * 0.3, 4.0, 18.0)
		buzz(400, 1.0)
		play("crash")
	var earned := int(score / 25.0)
	var new_best := Profile.finish_run(int(score), earned)
	ui.show_over(int(score), distance / 1000.0, earned, new_best, reason)


# Arabanın şu an üstünden geçtiği şeritler (iki şeridin arasındaysa ikisi de).
func player_lanes() -> Array:
	return [0, 1, 2, 3, 4].filter(func(k): return absf(LANES[k] - car.position.x) < 2.9)


func fire_nitro() -> void:
	if nitro < 0.5 or nitro_t > 0.0:
		return
	close_tip()
	nitro_t = stats.nitro_time * nitro # yarım dolu nitro yarım süre yanar
	nitro = 0.0
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
	return nitro_t / stats.nitro_time if nitro_t > 0.0 else nitro


# Skorun altındaki etiketler: karşı şerit çarpanı ve kombo.
func hud_tags() -> String:
	var tags := PackedStringArray()
	if against_traffic():
		tags.append("KARŞI ŞERİT x%.1f" % ONCOMING_MULT)
	if combo > 1:
		tags.append("KOMBO x%d" % combo)
	return "  ·  ".join(tags)


func buzz(ms: int, amplitude: float) -> void:
	if Profile.vibration:
		Input.vibrate_handheld(ms, amplitude)


func mission(type: String, amount: float) -> void:
	if Profile.mode == "free":
		return # serbest sürüş ödül kazandırmaz
	for m in Profile.track(type, amount):
		ui.toast("GÖREV TAMAM  +%d COIN" % m.reward, Color(1.0, 0.8, 0.3))
		buzz(60, 0.6)
		play("confirm")


# Grafik ve FPS ayarı (Ayarlar sekmesi). Düşük: 3B çözünürlük %60, MSAA ve parlama kapalı, az yağmur.
# Düşük: 3B %60, MSAA ve parlama yok, az yağmur, lamba ışıkları kapalı (parlayan başlıklar ve yol yansıması
# kalır). Orta: 3B %75, MSAA yok. Yüksek: tam çözünürlük, 2x MSAA, ekranı kıran tam lens.
# Dinamik çözünürlük FPS düşerse 3B ölçeği %50'ye kadar indirir (update_perf).
func apply_settings() -> void:
	var q: int = Profile.quality
	var vp := get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	max_scale = [0.6, 0.75, 1.0][q]
	vp.scaling_3d_scale = max_scale
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X][q]
	env.glow_enabled = q > 0
	rain.amount = [300, 700, 1500][q]
	lens_mat.shader = LENS_FULL if q == 2 else LENS_LITE
	lens_mat.set_shader_parameter("taps", 6)
	for p in props:
		if p.has_meta("lamp_light"):
			(p.get_meta("lamp_light") as Node3D).visible = q > 0
	# yalnız yüksek grafikte: sahne ¼ çözünürlükte bir kez daha, aynadan çizilir
	refl_vp.size = Vector2i(get_window().size / 4)
	refl_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if q == 2 else SubViewport.UPDATE_DISABLED
	set_road("refl_amt", 1.0 if q == 2 else 0.0)
	Engine.max_fps = Profile.fps


# Dinamik çözünürlük: hedef FPS tutmazsa 3B ölçeği adım adım düşer, uzun süre tutarsa geri çıkar.
func update_perf(dt: float) -> void:
	if benching:
		return
	perf_t += dt
	if perf_t < 1.5:
		return
	perf_t = 0.0
	var fps := Engine.get_frames_per_second()
	var hz := DisplayServer.screen_get_refresh_rate()
	var target := float(mini(Profile.fps, roundi(hz) if hz > 0.0 else 60))
	var vp := get_viewport()
	if fps < target * 0.9 and vp.scaling_3d_scale > 0.5:
		vp.scaling_3d_scale = maxf(vp.scaling_3d_scale - 0.05, 0.5)
		perf_good = 0
	elif fps >= target * 0.97:
		perf_good += 1
		if perf_good >= 3 and vp.scaling_3d_scale < max_scale:
			vp.scaling_3d_scale = minf(vp.scaling_3d_scale + 0.05, max_scale)
			perf_good = 0
	if OS.is_debug_build() and OS.has_feature("mobile"): # adb logcat ile ölçüm için
		print("[perf] fps=%d hedef=%d olcek=%.2f cizim=%d durum=%s" % [fps, target, vp.scaling_3d_scale,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), state])


# --- Duraklatma ---

func set_pause(on: bool) -> void:
	if on and state != "play":
		return
	paused = on
	holding = false # basılı kalan fren takılmasın
	get_tree().paused = on
	ui.show_pause(on)


# Android geri tuşu: oyunda duraklat/devam, panelde kapat, menüde çık.
func on_back() -> void:
	if state == "play":
		set_pause(not paused)
	elif ui.panel_open():
		ui.close_panels()
	elif state == "menu":
		get_tree().quit()
	else:
		to_menu()


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
	for n in [patrol, gate, radar]:
		n.visible = on
		n.position = Vector3(0, 0, -30.0) if n != patrol else Vector3(LANES[0], 0, -12.0)
	set_siren_lights(patrol, on)
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
		# ilk araba geliştirmesiz 240'a çıkmaz; yol uzadıkça tavan 25 km/sa artar
		top_now = minf(205.0 + distance / 200.0, 230.0) + stats.top
		var top := top_now
		if nitro_t > 0.0:
			kmh = move_toward(kmh, top + NITRO_KMH, 120.0 * dt)
		elif braking:
			kmh = move_toward(kmh, MIN_KMH, 140.0 * stats.brake * dt)
		elif kmh > top:
			kmh = move_toward(kmh, top, 40.0 * dt)
		else:
			kmh = move_toward(kmh, top, maxf(12.0 + 50.0 * (1.0 - kmh / top), 5.0) * stats.accel * dt) # hızlandıkça ivme düşer
	player_mat.set_shader_parameter("tail_energy", 12.0 if braking else 4.0)
	var g := 1
	while g < 6 and kmh >= GEAR_FRAC[g] * top_now:
		g += 1
	if g > gear and state == "play" and kmh > 90.0 and randf() < 0.6:
		pop_t = 0.07 # vites atınca egzoz patlar
	gear = g
	var lo: float = GEAR_FRAC[g - 1] * top_now
	var hi: float = GEAR_FRAC[g] * top_now
	# 1. vites rölantiden, üstteki vitesler SHIFT_RPM'den başlar; ibre yeni devre yumuşakça iner
	var want := lerpf(0.12 if g == 1 else SHIFT_RPM, 0.97, clampf((kmh - lo) / (hi - lo), 0.0, 1.0))
	rpm = lerpf(rpm, want, 1.0 - exp(-(12.0 if want > rpm else 6.0) * dt))


func update_run(step: float, dt: float) -> void:
	run_time += dt
	nitro_t = maxf(nitro_t - dt, 0.0)
	distance += step
	var mult := (2.0 if nitro_t > 0.0 else 1.0) * (ONCOMING_MULT if against_traffic() else 1.0)
	score += step * mult
	# yol çalışmasına yaklaşırken ve içindeyken trafik seyrelir
	var sparse := 2.2 if works_on and works_start - travel < 700.0 else 1.0
	if nitro_t > 0.0:
		sparse *= 2.0 # nitroda trafik seyrelir: hız patlaması hemen çarpışmayla bitmesin
	var hard := clampf(distance / 6000.0, 0.0, 1.0)
	if Profile.mode != "free": # serbest sürüşte trafik yok
		since_row += step
		if since_row > lerpf(45.0, 24.0, hard) * sparse:
			since_row = 0.0
			spawn_row()
		since_on += step
		if since_on > lerpf(150.0, 70.0, hard) * sparse:
			since_on = 0.0
			spawn_oncoming()
	if Profile.mode == "time":
		time_left -= dt
		if travel >= cp_next:
			var bonus := maxi(10, 22 - cp_count * 2) # her kontrol noktası biraz daha az süre verir
			time_left += bonus
			cp_count += 1
			cp_next += CP_GAP
			ui.popup("KONTROL NOKTASI  +%d SN" % bonus, Color(0.4, 1.0, 0.6))
			play("confirm")
			buzz(60, 0.5)
		if time_left <= 0.0:
			time_left = 0.0
			crash(null, "SÜRE BİTTİ")
	update_chase(dt)
	update_race(dt)
	if nitro_t <= 0.0:
		nitro = minf(nitro + dt * 0.015, 1.0)
	if nitro >= 0.5 and not Profile.nitro_tip and not tip_on:
		open_tip()
	if tip_on and Time.get_ticks_msec() / 1000.0 > tip_until:
		close_tip()
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	if kmh >= 220.0:
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
		and region_at(travel + 330.0 + TUNNEL_LEN) != Regions.BRIDGE \
		and not widen_hits(travel + 280.0, travel + 380.0 + TUNNEL_LEN)


func update_props(step: float) -> void:
	for p in props:
		p.position.z += step
		if p.position.z > 50.0:
			p.position.z -= PROP_COUNT * Regions.GAP
			Regions.configure(p, region_at(travel - p.position.z))
			Regions.set_widen(p, widen_mode(travel - p.position.z))
		var covered := p.position.z < tunnel_t0 + 25.0 and p.position.z > tunnel_t1 - 5.0 # tünelin içinden süs çıkmasın
		(p.get_meta("lamp") as Node3D).visible = not covered
		(p.get_meta("deco") as Node3D).visible = not covered


func update_traffic(step: float, dt: float) -> void:
	flash_glow = 0.0
	for i in range(traffic.size() - 1, -1, -1): # sondan başa: silerken kopya dizi gerekmez
		var c := traffic[i]
		if c == hit_car:
			hit_update(c, dt)
			continue
		var before: float = c.position.z - car.position.z
		var dir: int = c.get_meta("dir")
		# bizim yöndekiler bizden yavaş gider, karşı yöndekiler bize doğru gelir
		var v: float = LANE_KMH[c.get_meta("lane")]
		# arkamızdan yetişen araç bize bindirmez: hızımıza iner ve selektör yapar
		if dir > 0 and before > 0.0 and before < len_gap(c) + 10.0 and v > kmh \
				and absf(c.position.x - car.position.x) < side_gap(c) + 0.5:
			v = maxf(kmh - 3.0, 0.0)
			if state == "play" and c.get_meta("flash", 0.0) <= 0.0:
				c.set_meta("flash", 1.2)
		c.position.z += step - dir * v / 3.6 * dt
		var fl: float = c.get_meta("flash", 0.0)
		if fl > 0.0:
			c.set_meta("flash", fl - dt)
			set_beam(c, 4.0 if fmod(fl, 0.3) > 0.15 else 1.0)
			if fl - dt <= 0.0:
				set_beam(c, 1.0)
			flash_glow = maxf(flash_glow, 0.6 if fmod(fl, 0.3) > 0.15 else 0.0)
		var lost: bool = (c.get_meta("lane") == 4 and wide_at(c.position.z) < 0.99) \
			or (c.get_meta("lane") == 1 and dir > 0 and not lane_closed(2, c.position.z))
		if lost and not c.get_meta("ghost", false):
			c.set_meta("ghost", true) # biten 3. şeritte kalan araç kaybolur
			c.set_meta("fade", 0.0)
			c.set_meta("push", 0.0)
		var gone := c.position.z > 15.0 or c.position.z < SPAWN_Z - 60.0
		if c.get_meta("ghost", false):
			gone = fade_out(c, dt) or gone
		if gone:
			c.visible = false
			c.set_meta("ghost", false)
			traffic.erase(c)
			if c == patrol:
				patrol_active = false
			else:
				(pool if dir > 0 else pool_on).append(c)
		elif state == "play" and not c.get_meta("ghost", false):
			if touching(c):
				if dir > 0 and before > 0.6 * len_gap(c):
					c.position.z = car.position.z + len_gap(c) # arkadaki araç bindirmez, hak gitmez
				else:
					hit(c, kmh - dir * LANE_KMH[c.get_meta("lane")], before)
			elif before < 0.0 and c.position.z - car.position.z >= 0.0:
				near_miss(c)
				if c == patrol and kmh > 200.0:
					traffic.erase(c)
					start_chase()


func touching(c: Node3D) -> bool:
	return absf(c.position.z - car.position.z) < len_gap(c) and absf(c.position.x - car.position.x) < side_gap(c)


# Önden-arkadan değmeden durabileceği en küçük merkez aralığı (kamyonlar uzun).
func len_gap(c: Node3D) -> float:
	return c.get_meta("half_l", 2.2) + car.get_meta("half_l", 2.3) - 0.2


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
	var from_behind := before < -0.6 * len_gap(c) # öndeki aracın arkasına bindirdik
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
		target_x = clampf(target_x + keys * KEY_STEER * dt, left_limit(), right_limit()) # 3. şerit kapanınca araç kendiliğinden içeri girer
	elif state == "menu":
		target_x = LANES[2]
	target_x = clampf(target_x, left_limit(), right_limit())
	var before := car.position.x
	car.position.x = lerpf(car.position.x, target_x, 1.0 - exp(-12.0 * dt))
	player_mat.set_shader_parameter("car_inv", car.global_transform.affine_inverse()) # desenli boyalar araçla gitsin
	var lean := clampf((car.position.x - before) / maxf(dt, 0.001) * 0.12, -2.0, 2.0) # yana kayma hızına göre gövde yatar
	if state == "over" and not finished:
		car.rotation.y += dt * kmh / 60.0
	else:
		car.rotation = car.rotation.lerp(Vector3(0, -lean * 0.08, lean * 0.03), 1.0 - exp(-10.0 * dt))
	# egzoz alevi yalnız nitroda (mavi) ve vites atınca kısa bir an (turuncu) görünür
	var boost := nitro_t > 0.0
	pop_t = maxf(pop_t - dt, 0.0)
	var fire := state != "over" and (boost or pop_t > 0.0)
	flame_mat.albedo_color = Color(0.25, 0.4, 1.0) if boost else Color(1.0, 0.4, 0.08)
	core_mat.albedo_color = Color(0.8, 0.9, 1.0) if boost else Color(1.0, 0.85, 0.45)
	for f in flames:
		f.visible = fire
		if fire:
			f.scale = Vector3(1, 1, randf_range(0.75, 1.15) if boost else randf_range(0.25, 0.4))
	# ıslak yolda arka tekerleklerden su sisi: hız ve ıslaklıkla artar, tünelde kesilir
	spray.amount_ratio = clampf((kmh - 50.0) / 150.0, 0.0, 1.0) * clampf(wetness * 1.4 - 0.3, 0.0, 1.0) * (1.0 - tunnel_in)
	spray.emitting = Profile.quality > 0 and state != "over" and spray.amount_ratio > 0.02


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
	set_road("rain_amt", rain_level * (1.0 - tunnel_in))
	lens_mat.set_shader_parameter("wet", (1.0 - tunnel_in) * rain_level * wipe)
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
	if benching:
		return # ölçümde kamera sabit: kare içeriği adımlar arasında değişmesin
	var ratio := minf(kmh / 250.0, 1.25) # hız hissi: tavan hızı düşük araçta da yol akıcı görünsün
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
	var roll := deg_to_rad(3.0) * wc * (-1.0 if works_lane == 2 else 1.0)
	var j := 0.02 * ratio * ratio + shake * 0.25 + boost * 0.03
	var fov := 58.0 + 18.0 * ratio + boost * 8.0 + wc * 6.0
	var top: float = car.get_meta("top", 1.3)
	var pose: Vector3
	var pitch := lerpf(-12.0, -9.0, wc)
	var mode := cam_mode()
	match mode:
		1: # uzak
			cam_x = lerpf(cam_x, car.position.x * 0.6, k)
			pose = Vector3(cam_x, lerpf(4.6, 3.6, wc), lerpf(11.0, 9.5, wc))
			pitch = -14.0
			fov -= 6.0
		2: # kaput
			pose = car.position + Vector3(0, car.get_meta("hood_y") + 0.32, -car.get_meta("rear") * 0.62) # kaputun üstü, camın önü
			pitch = -4.0
			fov += 8.0
			j *= 0.4
		3: # kokpit
			pose = car.position + Vector3(-0.35, top * 0.72, 0.1)
			pitch = -3.0
			fov += 12.0
			j *= 0.4
		_: # takip
			cam_x = lerpf(cam_x, car.position.x * 0.7, k)
			pose = Vector3(cam_x, lerpf(3.3, 2.4, wc), lerpf(7.4, 6.2, wc))
	# arabaya bağlı kameralar gecikmesiz, dıştakiler yumuşak takip eder
	cam_pos = pose if mode >= 2 else cam_pos.lerp(pose, 1.0 - exp(-8.0 * dt))
	cam.position = cam_pos + Vector3(randf_range(-j, j), randf_range(-j, j), 0)
	cam.quaternion = cam.quaternion.slerp(Quaternion.from_euler(Vector3(deg_to_rad(pitch), 0, roll)), 1.0 if mode >= 2 else k)
	cam.fov = lerpf(cam.fov, fov, 1.0 - exp(-5.0 * dt))
	lens_mat.set_shader_parameter("speed", clampf((kmh - 120.0) / 140.0, 0.0, 1.0))
	car.get_child(0).visible = mode != 3 # kokpitte gövde gizli, pano ve silecekler arayüzde çizilir
	# silecek: her süpürüşte camdaki damlalar silinir, yağmur yeniden ıslatır
	if mode == 3 and rain_level > 0.15:
		var ph := fmod(alive / 1.3, 1.0)
		if ph < wipe_phase:
			wipe = 0.15
		wipe_phase = ph
		wipe = move_toward(wipe, 1.0, dt * 0.7)
	else:
		wipe = 1.0


# Oyun sırasında seçili kamera; menüde ve kazadan sonra hep takip kamerası.
func cam_mode() -> int:
	return Profile.cam if state == "play" else 0


func set_cam(i: int) -> void:
	Profile.cam = i
	Profile.save()


func change_cam() -> void:
	set_cam((Profile.cam + 1) % Profile.CAMS.size())
	ui.toast("KAMERA: " + Profile.CAMS[Profile.cam], Color(0.6, 0.85, 1.0))


func spawn_row() -> void:
	var lanes := OURS.filter(func(l): return not (works_on and l == works_lane)) # kapalı şeride araç çıkmaz
	if works_on and works_lane == CONTRA:
		# yolu bölgeye denk gelen araç kapalı şeritlere çıkmaz; tamamen bölgedeyse bize verilen şeritte gider
		var path_in := lane_closed(2, SPAWN_Z) or lane_closed(2, SPAWN_Z - 160.0)
		lanes = [1] if lane_closed(2, SPAWN_Z) and lane_closed(2, SPAWN_Z - 160.0) else ([] if path_in else lanes)
		if lanes.is_empty():
			return
	if wide_at(SPAWN_Z) >= 1.0 and wide_at(SPAWN_Z - 160.0) >= 1.0: # biz yetişene kadar 3. şerit sürsün
		lanes.append(4)
	lanes.shuffle()
	if not patrol_active and not chase_on and travel > next_patrol and Profile.mode != "race":
		patrol_active = true
		next_patrol = travel + randf_range(1800.0, 3200.0)
		place(patrol, lanes[0], 1)
		return
	# iki şerit birden dolarsa geçmenin yolu karşı şerit ya da fren
	for i in (2 if randf() < 0.2 and lanes.size() == 2 else 1):
		if pool.is_empty():
			return
		place(pool.pop_back(), lanes[i], 1)


func spawn_oncoming() -> void:
	if not pool_on.is_empty():
		place(pool_on.pop_back(), 0 if works_on and works_lane == CONTRA else ONCOMING.pick_random(), -1)


func place(c: Node3D, l: int, dir: int) -> void:
	c.set_meta("flash", 0.0)
	set_beam(c, 1.0)
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
	var yellow := Build.mat(Color(0.95, 0.68, 0.05), 0.5, 0.0, 0.35) # gece de seçilsin
	var dark := Build.mat(Color(0.07, 0.07, 0.07), 0.8)
	var glass := Build.mat(Color(0.12, 0.16, 0.22), 0.1, 0.0, 0.4)
	var dirt := Build.mat(Color(0.17, 0.12, 0.08), 0.95)
	for i in 2:
		diggers.append(make_digger(yellow, dark, glass, dirt))
	loader = make_kenney("tractor-shovel", false, Vector3(1.7, 1.7, 1.7)) # Kenney yükleyici
	loader.rotation.y = 0.35
	works.add_child(loader)
	add_child(works)


# Paletli kepçe: dönen gövde, bom, kol ve kova ayrı pivotlarda; update_works kazı hareketi yaptırır.
func make_digger(yellow: Material, dark: Material, glass: Material, dirt: Material) -> Node3D:
	var d := Node3D.new()
	for s in [-1.0, 1.0]:
		Build.box(d, Vector3(0.6, 0.8, 3.6), Vector3(s * 0.95, 0.4, 0), dark) # paletler
	var swing := Node3D.new()
	swing.position.y = 0.85
	d.add_child(swing)
	Build.box(swing, Vector3(2.2, 1.0, 2.6), Vector3(0, 0.55, 0.3), yellow)
	Build.box(swing, Vector3(2.0, 0.5, 0.5), Vector3(0, 0.75, 1.55), dark) # karşı ağırlık
	Build.box(swing, Vector3(0.95, 1.3, 1.1), Vector3(-0.6, 1.6, -0.4), glass) # kabin
	Build.box(swing, Vector3(0.25, 0.2, 0.25), Vector3(-0.6, 2.35, -0.4), works_amber) # tepe lambası
	var boom := Node3D.new()
	boom.position = Vector3(0.35, 0.9, -1.0)
	swing.add_child(boom)
	Build.box(boom, Vector3(0.35, 0.45, 3.4), Vector3(0, 0, -1.7), yellow)
	var stick := Node3D.new()
	stick.position.z = -3.4
	boom.add_child(stick)
	Build.box(stick, Vector3(0.28, 0.35, 2.4), Vector3(0, 0, -1.2), yellow)
	var bucket := Node3D.new()
	bucket.position.z = -2.4
	stick.add_child(bucket)
	Build.box(bucket, Vector3(0.9, 0.6, 0.7), Vector3(0, -0.2, -0.3), dark)
	var pile := MeshInstance3D.new() # kazılan toprak yığını
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 1.4
	pile.mesh = sm
	pile.material_override = dirt
	pile.position = Vector3(0, 0, -4.6)
	pile.scale = Vector3(1.0, 0.7, 1.3)
	d.add_child(pile)
	# ışık kulesi: gerçek ışık yerine parlayan panel ve ıslak yolda yansıması (telefonda ucuz)
	var tower := Node3D.new()
	d.add_child(tower)
	Build.box(tower, Vector3(0.15, 5.0, 0.15), Vector3(0, 2.5, 0), dark)
	Build.box(tower, Vector3(1.3, 0.5, 0.2), Vector3(0, 5.1, 0), Build.mat(Color(1.0, 0.95, 0.85), 0.5, 0.0, 6.0))
	Build.streak(tower, Vector3.ZERO, Color(1.0, 0.95, 0.85), 1.2, 10.0, 1.0)
	d.set_meta("tower", tower)
	d.set_meta("parts", [swing, boom, stick, bucket])
	works.add_child(d)
	return d


func configure_works(l: int) -> void:
	# kapalı şerit lane 3 (sağ dış) ise koniler dış çizgiden içeri, lane 2 ise orta çizgiden dışarı daralır.
	# CONTRA: koniler iki şeridi birden kapatıp orta çizgiye çeker; karşı yönün iki şeridi koni sırasıyla ayrılır.
	var contra := l == CONTRA
	var inner := 0.35 if contra else 3.5 + (0.35 if l == 3 else -0.35) # bariyerin durduğu çizgi
	var cones := []
	var n := 24 if contra else 16
	for i in n:
		var f := i / float(n - 1)
		var x := (ROAD_EDGE - 0.3 - (ROAD_EDGE - 0.6) * f) if contra else ((ROAD_EDGE - 3.5 * f - 0.3) if l == 3 else (3.5 * f + 0.3))
		cones.append(Transform3D(Basis(), Vector3(x, 0.37, -f * WORK_TAPER)))
	var barriers := []
	var lights := []
	var z := -WORK_TAPER
	while z > -WORK_LEN:
		barriers.append(Transform3D(Basis(), Vector3(inner, 0.45, z)))
		if barriers.size() % 4 == 0:
			lights.append(Transform3D(Basis(), Vector3(inner, 1.0, z)))
		if contra and barriers.size() % 2 == 0: # karşı yönü ayıran koni sırası
			cones.append(Transform3D(Basis(), Vector3(-3.5, 0.37, z)))
			if barriers.size() % 8 == 0:
				lights.append(Transform3D(Basis(), Vector3(-3.5, 0.85, z)))
		z -= 2.2
	for pair in [[works_cones, cones], [works_barriers, barriers], [works_lights, lights]]:
		var mm: MultiMesh = pair[0]
		mm.instance_count = pair[1].size()
		for i in pair[1].size():
			mm.set_instance_transform(i, pair[1][i])
	var lane_x: float = 3.5 if contra else LANES[l]
	works_board.position = Vector3(lane_x, 1.6, -WORK_TAPER * 0.3)
	works_arrow.position = Vector3(lane_x, 1.6, -WORK_TAPER * 0.3 + 0.1)
	works_arrow.text = ">>>" if l == 2 else "<<<" # açık şeride doğru
	# kepçeler kapalı şeritte, bariyerden uzak kenara yakın; kol açık şeride uzanmasın diye dışa döner
	for i in diggers.size():
		var dg := diggers[i]
		var dx: float = LANES[2 + i] if contra else LANES[l] + (0.15 if l == 3 else -0.15)
		dg.position = Vector3(dx, 0, -WORK_TAPER - 70.0 - i * 140.0)
		dg.set_meta("side", 1.0 if l == 2 else -1.0) # CONTRA'da kol dışa: bize verilen şeride uzanmasın
		(dg.get_meta("tower") as Node3D).position = Vector3(-1.4 if l == 2 else 1.4, 0, 2.4) # yol kenarı ya da orta çizgi tarafı
		dg.set_meta("phase", randf() * TAU)
	loader.position.x = 3.5 if contra else LANES[l]


func start_works() -> void:
	works_on = true
	var r := randf()
	works_lane = 3 if r < 0.5 else (2 if r < 0.75 else CONTRA)
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
			if widen_hits(travel + WORK_WARN - 150.0, travel + WORK_WARN + WORK_LEN + 150.0):
				next_works = travel + 300.0
			else:
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
	if works.visible:
		# kapalı şeritte asfalt sökülmüş: konilerin bittiği yerden bariyer sonuna kadar toprak
		var x0 := 3.5 + 0.7 if works_lane == 3 else (0.7 if works_lane == CONTRA else 0.25)
		var x1 := 2.8 if works_lane == 2 else 7.9
		set_road("works", Vector4(x0, x1, works.position.z - WORK_TAPER, works.position.z - WORK_LEN))
		loader.position.z = -WORK_TAPER - 185.0 + sin(alive * 0.45) * 4.0 # iki kepçenin arasında ileri geri
		for dg in diggers:
			var t: float = alive + dg.get_meta("phase")
			var parts: Array = dg.get_meta("parts")
			(parts[0] as Node3D).rotation.y = dg.get_meta("side") * (0.3 + sin(t * 0.35) * 0.15)
			(parts[1] as Node3D).rotation.x = 0.45 + sin(t * 0.9) * 0.2
			(parts[2] as Node3D).rotation.x = -1.7 + sin(t * 0.9 + 1.0) * 0.35
			(parts[3] as Node3D).rotation.x = -0.6 + sin(t * 0.9 + 2.0) * 0.5
	var side := "SAĞ ŞERİT KAPALI" if works_lane == 3 else ("SOL ŞERİT KAPALI" if works_lane == 2 else "İKİ ŞERİT KAPALI · SOLA GEÇ")
	if d > 0.0:
		ui.set_warning("YOL ÇALIŞMASI  %d m\n%s" % [int(d), side], d < 300.0)
		for mark in [1000.0, 500.0, 200.0]:
			if d < mark and works_warned >= mark:
				buzz(70, 0.6)
		works_warned = minf(works_warned, d)
	elif into < WORK_LEN:
		ui.set_warning("YOL ÇALIŞMASI  ·  %s" % side, true)
	else:
		ui.set_warning("")
	works_cam = move_toward(works_cam, 1.0 if into > -60.0 and into < WORK_LEN + 20.0 else 0.0, dt * 1.5)
	if state == "play" and into > 0.0 and into < WORK_LEN:
		# kapalı bölge konilerle daralır: f 0'dan 1'e, sonra bariyer boyunca tam şerit
		var f := clampf(into / WORK_TAPER, 0.0, 1.0)
		var lo := (ROAD_EDGE - 3.5 * f) if works_lane == 3 else ((ROAD_EDGE - ROAD_EDGE * f) if works_lane == CONTRA else 0.0)
		var hi := 3.5 * f if works_lane == 2 else ROAD_EDGE
		var hw: float = car.get_meta("half_w")
		if f > 0.05 and car.position.x + hw > lo + 0.25 and car.position.x - hw < hi - 0.25:
			ui.toast("YOL ÇALIŞMASINA GİRDİN", Color(1.0, 0.6, 0.2))
			crash(null)
		elif f >= 1.0:
			# bariyerin dibinden geçmek: dar geçiş bonusu
			var gap := ((car.position.x - hw) - hi) if works_lane == 2 else (lo - (car.position.x + hw))
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
		set_road("works", Vector4(0, 0, -1e6, -1e6))
		ui.set_warning("")
		next_works = travel + randf_range(3000.0, 5000.0)


# --- Polis / ambulans ---

func build_sirens() -> void:
	var red := Build.mat(Color(1.0, 0.05, 0.05), 0.5, 0.0, 10.0)
	var blue := Build.mat(Color(0.1, 0.25, 1.0), 0.5, 0.0, 10.0)
	var siren_stream: AudioStreamOggVorbis = preload("res://audio/siren.ogg")
	siren_stream.loop = true
	for kind in ["police", "ambulance", "firetruck"]:
		var s := make_kenney(kind)
		add_siren_kit(s, {"police": -0.33, "ambulance": -1.6, "firetruck": -1.9}[kind], red, blue, siren_stream) # tavan ortası / kasanın ön üstü
		s.visible = false
		add_child(s)
		sirens.append(s)
	patrol = make_kenney("police")
	add_siren_kit(patrol, -0.33, red, blue, siren_stream)
	set_siren_lights(patrol, false) # devriyeyken çakarlar sönük
	patrol.visible = false
	add_child(patrol)


# Tepe lambası (kırmızı/mavi), çakar ışığı ve konumlu siren sesi.
func add_siren_kit(s: Node3D, bar_z: float, red: Material, blue: Material, stream: AudioStream) -> void:
	var top: float = s.get_meta("top")
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
	snd.stream = stream
	snd.bus = "World"
	snd.volume_db = -4.0
	snd.unit_size = 10.0
	snd.max_distance = 250.0
	snd.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
	s.add_child(snd)
	s.set_meta("snd", snd)


func set_siren_lights(s: Node3D, on: bool) -> void:
	(s.get_meta("red") as Node3D).visible = on
	(s.get_meta("blue") as Node3D).visible = on
	(s.get_meta("light") as Node3D).visible = on


# --- Polis kovalamacası ---
# Devriye trafikte sakin gider; 200 km/sa üstünde sollanırsa çakarlarını yakıp kovalar. Polis giderek
# hızlanır: ondan yavaş gidersen yaklaşır, değerse yakalandın. 20 sn dayanır ya da açılırsan kaçtın.

func start_chase() -> void:
	chase_on = true
	chase_t = CHASE_TIME
	police_kmh = maxf(kmh - 40.0, 180.0)
	set_siren_lights(patrol, true)
	(patrol.get_meta("snd") as AudioStreamPlayer3D).play(randf() * 30.0)
	ui.toast("POLİS PEŞİNDE!  KAÇ!", Color(1.0, 0.35, 0.35))
	buzz(120, 0.8)


func update_chase(dt: float) -> void:
	if not chase_on:
		return
	chase_t -= dt
	police_kmh = move_toward(police_kmh, top_now + 10.0 + (CHASE_TIME - chase_t) * 1.0, 30.0 * dt) # bizden biraz hızlı: zikzakla ya da nitroyla kaçılır
	patrol.position.z += (kmh - police_kmh) / 3.6 * dt
	var behind := patrol.position.z - car.position.z
	# yan yanayken bize kırmaz; geriye düşünce şeridimize geçip kovalar. Önü doluysa trafiği silmez:
	# boş şeride geçer, boş şerit yoksa öndeki aracın arkasında yavaşlar.
	# seçtiği boş şeritte 1,5 sn kalır: engelin yanından geçerken iki şerit arasında gidip gelmesin
	patrol_hold -= dt
	if patrol_hold <= 0.0:
		var want := car.position.x if behind > 10.0 else patrol.position.x
		if lane_blocker(lane_of(want), patrol.position.z, 2.0, patrol) != null \
				or lane_blocker(lane_of(patrol.position.x), patrol.position.z, 2.0, patrol) != null:
			var k := free_lane(patrol.position.z, want, false, patrol)
			if k >= 0:
				want = LANES[k]
				patrol_hold = 1.5
			elif lane_of(patrol.position.x) in ONCOMING:
				want = LANES[2] # karşıdan araç geliyor, boş yer yoksa kendi yönüne döner
		patrol_want = want
	var b := lane_blocker(lane_of(patrol.position.x), patrol.position.z, 0.0, patrol)
	if b != null and b.get_meta("dir") > 0 and patrol.position.z - b.position.z < len_gap(b) + 2.5:
		patrol.position.z = b.position.z + len_gap(b) + 2.5
	patrol.position.x = lerpf(patrol.position.x, patrol_want, 1.0 - exp(-1.5 * dt))
	var on := fmod(alive * 3.0, 1.0) < 0.5
	(patrol.get_meta("red") as Node3D).visible = on
	(patrol.get_meta("blue") as Node3D).visible = not on
	(patrol.get_meta("light") as OmniLight3D).light_color = Color(1.0, 0.1, 0.1) if on else Color(0.15, 0.3, 1.0)
	var dz := patrol.position.z - car.position.z
	lens_mat.set_shader_parameter("siren_amt", clampf((40.0 - dz) / 30.0, 0.0, 1.0))
	lens_mat.set_shader_parameter("siren_col", Color(1.0, 0.1, 0.1) if on else Color(0.15, 0.3, 1.0))
	ui.set_chase("POLİS PEŞİNDE  %d SN" % ceili(chase_t))
	if dz > 0.0 and dz < len_gap(patrol) and absf(patrol.position.x - car.position.x) < side_gap(patrol):
		end_chase(false)
		crash(patrol, "YAKALANDIN")
	elif chase_t <= 0.0 or dz > 150.0:
		score += 1000
		ui.popup("POLİSTEN KAÇTIN  +1000", Color(0.5, 0.8, 1.0))
		play("confirm")
		buzz(80, 0.6)
		end_chase(true)


func end_chase(hide_car: bool) -> void:
	chase_on = false
	ui.set_chase("")
	if hide_car:
		patrol.visible = false
		set_siren_lights(patrol, false)
		(patrol.get_meta("snd") as AudioStreamPlayer3D).stop()
		patrol_active = false


# --- Radar ve kontrol noktası ---

func build_radar() -> void:
	radar = Node3D.new()
	radar.visible = false
	var dark := Build.mat(Color(0.12, 0.12, 0.13), 0.5, 0.5)
	Build.box(radar, Vector3(0.18, 5.2, 0.18), Vector3(8.5, 2.6, 0), dark)
	Build.box(radar, Vector3(1.2, 0.6, 0.7), Vector3(8.0, 5.2, 0), Build.mat(Color(0.85, 0.85, 0.8), 0.4))
	Build.box(radar, Vector3(0.2, 0.2, 0.05), Vector3(7.6, 5.1, 0.38), Build.mat(Color(1.0, 0.1, 0.1), 0.5, 0.0, 8.0))
	# radardan 400, 250 ve 100 m önce mesafeli tabelalar
	var blue := Build.mat(Color(0.05, 0.2, 0.7), 0.6, 0.0, 1.2)
	for at in [400.0, 250.0, 100.0]:
		Build.box(radar, Vector3(0.15, 2.6, 0.15), Vector3(8.6, 1.3, at), dark)
		Build.box(radar, Vector3(2.6, 1.5, 0.1), Vector3(8.6, 3.0, at), blue)
		var t := Label3D.new()
		t.text = "RADAR\n%d m" % int(at)
		t.font_size = 72
		t.pixel_size = 0.008
		t.outline_size = 0
		t.position = Vector3(8.6, 3.0, at + 0.07)
		radar.add_child(t)
	add_child(radar)


# Hız kamerası: önünden 220 km/sa üstünde geçince flaş patlar, hızına göre bonus.
func update_radar() -> void:
	var d := radar_at - travel
	if d > 720.0: # en uzak tabela 400 m önde; kamera 320 m görür
		return
	if not radar_on and (tunnel_on or widen_hits(radar_at - 430.0, radar_at + 30.0)):
		radar_at += 600.0 # tünelin ve 3. şeridin içine radar ve tabelası konmaz
		return
	radar_on = true
	radar.visible = true
	radar.position.z = -d
	if d <= 0.0 and not radar.get_meta("shot", false):
		radar.set_meta("shot", true)
		if state == "play" and kmh >= RADAR_MIN_KMH:
			var bonus := int((kmh - 150.0) * 4.0)
			if Profile.mode != "free":
				score += bonus
			ui.flash()
			ui.popup("RADAR  %d KM/SA  +%d" % [roundi(kmh), bonus], Color(1, 1, 1))
			play("click", 0.6)
			buzz(30, 0.4)
	if d < -40.0:
		radar_on = false
		radar.visible = false
		radar.set_meta("shot", false)
		radar_at = travel + randf_range(1800.0, 3200.0)


func build_gate() -> void:
	gate = Node3D.new()
	gate.visible = false
	var neon := Build.mat(Color(0.2, 1.0, 0.5), 0.5, 0.0, 6.0)
	for s in [-1.0, 1.0]:
		Build.box(gate, Vector3(0.5, 7.5, 0.5), Vector3(s * 8.3, 3.75, 0), neon)
	Build.box(gate, Vector3(17.1, 0.6, 0.5), Vector3(0, 7.5, 0), neon)
	Build.box(gate, Vector3(14.0, 0.02, 0.6), Vector3(0, 0.03, 0), neon)
	var t := Label3D.new()
	t.text = "KONTROL NOKTASI"
	t.font_size = 96
	t.pixel_size = 0.008
	t.outline_size = 0
	t.modulate = Color(0.5, 1.0, 0.7)
	t.position = Vector3(0, 6.5, 0.3)
	gate.add_child(t)
	add_child(gate)


func update_gate() -> void:
	var d := cp_next - travel
	gate.visible = state == "play" and Profile.mode == "time" and d < 330.0
	gate.position.z = -d


# --- Radyo ---

func build_music() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = -9.0
	music.process_mode = Node.PROCESS_MODE_ALWAYS # duraklatma menüsünde de çalsın
	add_child(music)
	music.finished.connect(func(): play_track(track + 1))
	play_track(randi() % 3)


func play_track(i: int) -> void:
	if Profile.radio == 0:
		music.stop()
		return
	var list: Array = MUSIC[Profile.radio]
	track = posmod(i, list.size())
	music.stream = load("res://audio/music/%s.ogg" % list[track][0])
	music.play()


func now_playing() -> String:
	if Profile.radio == 0:
		return "RADYO KAPALI"
	return "%s  ·  %s" % [Profile.STATIONS[Profile.radio], MUSIC[Profile.radio][track][1]]


func next_track() -> void:
	if Profile.radio != 0:
		play_track(track + 1)


func set_station(i: int) -> void:
	Profile.radio = i
	Profile.save()
	play_track(randi() % 3)


func change_station() -> void:
	set_station((Profile.radio + 1) % Profile.STATIONS.size())
	ui.toast(now_playing(), Color(1.0, 0.5, 0.9))


# Siren bizim yönde, bizim şeridimizde arkadan gelir; yol vermek oyuncunun işi.
func spawn_siren() -> void:
	siren = sirens.pick_random()
	siren_red = siren.get_meta("red")
	siren_blue = siren.get_meta("blue")
	siren_light = siren.get_meta("light")
	var l: int = lane_of(car.position.x) if car.position.x > 0.0 else OURS.pick_random()
	siren.set_meta("lane", l)
	siren.set_meta("dir", 1)
	siren.set_meta("ghost", false)
	siren.set_meta("blocked", false)
	siren.position = Vector3(LANES[l], 0, 30.0)
	siren.rotation = Vector3.ZERO
	siren.visible = true
	(siren.get_meta("snd") as AudioStreamPlayer3D).play(randf() * 30.0)


# --- Yarış modu ---
# Rakip trafikte kendi şeridini seçer, önü doluysa boş şeride (gerekirse karşı şeride) geçer, önümüze kırar.
# Birbirimize değince: arkadan vuran öndekini yavaşlatır, yandan sürtünen ikisi iki yana savrulur. Rakiple
# temas hafif çarpma hakkından düşmez. Hız tavanı bizimkine göre: geride kalan hafifçe hızlanır (lastik bant).

func start_race() -> void:
	race_on = true
	if rival == null:
		var model: String = RIVAL_MODELS.filter(func(m): return m != Profile.car).pick_random()
		rival = make_kenney(model)
		var m: ShaderMaterial = kenney_mat.duplicate()
		m.set_shader_parameter("use_paint", 1.0)
		m.set_shader_parameter("paint_uv", PAINT_UV[model])
		m.set_shader_parameter("paint", Color(0.85, 0.05, 0.08))
		m.set_shader_parameter("finish", 1)
		for mi in rival.get_child(0).find_children("*", "MeshInstance3D", true, false):
			mi.material_override = m
		var tag := Label3D.new()
		tag.text = "RAKİP"
		tag.font_size = 64
		tag.pixel_size = 0.01
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color(1.0, 0.35, 0.35)
		tag.position.y = rival.get_meta("top") + 0.9
		rival.add_child(tag)
		add_child(rival)
	rival_dist = distance
	rival_kmh = kmh
	rival_lane = 3 if car.position.x < 3.5 else 2
	rival.position = Vector3(LANES[rival_lane], 0, car.position.z)
	rival.visible = true
	ui.toast("YARIŞ BAŞLADI · %d KM" % int(RACE_LEN / 1000.0), Color(1.0, 0.4, 0.4))


func update_race(dt: float) -> void:
	if not race_on:
		return
	var gap := rival_dist - distance # + rakip önde
	var target := top_now + 4.0
	if gap < -60.0:
		target += 18.0
	elif gap > 120.0:
		target -= 12.0
	rival_nitro_cd -= dt
	if rival_nitro_t > 0.0:
		rival_nitro_t -= dt
		target += NITRO_KMH
	elif rival_nitro_cd <= 0.0 and gap < 30.0:
		rival_nitro_t = 3.0
		rival_nitro_cd = randf_range(10.0, 16.0)
	if rival_stun > 0.0:
		rival_stun -= dt
		target = minf(target, rival_kmh) # sersemken hızlanamaz
	var rz := car.position.z - gap
	# karar: 0,4 sn'de bir şerit seçer
	rival_think -= dt
	if rival_think <= 0.0:
		rival_think = 0.4
		var mine := lane_of(car.position.x)
		var blk := lane_blocker(rival_lane, rz, 3.0)
		var behind_us := gap < -3.0 and gap > -16.0 and mine == rival_lane
		var in_works := lane_closed(rival_lane, rz) or lane_closed(rival_lane, rz - 60.0)
		if blk != null or in_works or (behind_us and randf() < 0.7) or (rival_lane == 4 and wide_at(rz - 80.0) < 1.0):
			var k := free_lane(rz, rival.position.x, behind_us)
			if k < 0 and in_works:
				k = 1 if works_lane == CONTRA else 5 - works_lane # kapalı şeritten çıkar, gerekirse öndekinin arkasında yavaşlar
			if k >= 0:
				rival_lane = k
		elif gap > 6.0 and gap < 25.0 and mine != rival_lane and mine >= 2 and randf() < 0.12 \
				and lane_blocker(mine, rz, 3.0) == null:
			rival_lane = mine # önümüze kırar
			ui.toast("RAKİP ÖNÜNE KIRDI!", Color(1.0, 0.45, 0.35))
	var blk2 := lane_blocker(rival_lane, rz, 0.0)
	if blk2 != null and rz - blk2.position.z < 30.0 and blk2.get_meta("dir") > 0:
		target = minf(target, LANE_KMH[blk2.get_meta("lane")]) # boş şerit yoksa arkasında yavaşlar
	rival_kmh = move_toward(rival_kmh, target, (25.0 if target > rival_kmh else 70.0) * dt)
	rival_dist += rival_kmh / 3.6 * dt
	gap = rival_dist - distance
	var before_x := rival.position.x
	rival.position.z = car.position.z - gap
	rival.position.x = lerpf(rival.position.x, LANES[rival_lane], 1.0 - exp(-3.0 * dt))
	rival.rotation.y = clampf((before_x - rival.position.x) / maxf(dt, 0.001) * 0.04, -0.3, 0.3) \
		+ sin(alive * 18.0) * 0.12 * clampf(rival_stun, 0.0, 1.0) # vurulunca yalpalar
	# trafiğe değerse onu savurur, kendisi yavaşlar
	for c in traffic:
		if not c.get_meta("ghost", false) and c.visible and absf(c.position.z - rival.position.z) < len_gap(c) \
				and absf(c.position.x - rival.position.x) < side_gap(c):
			c.set_meta("ghost", true)
			c.set_meta("fade", 0.0)
			c.set_meta("push", signf(c.position.x - rival.position.x + 0.01) * 4.0)
			rival_kmh *= 0.6
	# biz ve rakip
	rival_bump_t -= dt
	var lg := len_gap(rival)
	if rival_bump_t <= 0.0 and absf(rival.position.z - car.position.z) < lg \
			and absf(rival.position.x - car.position.x) < side_gap(rival):
		rival_bump_t = 0.6
		var dzr := rival.position.z - car.position.z # + rakip arkada
		if dzr > 0.6 * lg:
			kmh *= 0.85
			rival_kmh *= 0.95
			ui.popup("RAKİP ARKADAN VURDU!", Color(1.0, 0.4, 0.35))
		elif dzr < -0.6 * lg:
			rival_kmh *= 0.45
			rival_stun = 1.5
			kmh *= 0.93
			ui.popup("RAKİBE BİNDİRDİN!", Color(1.0, 0.75, 0.3))
		else:
			var sgn := signf(rival.position.x - car.position.x + 0.01)
			rival.position.x += sgn * 0.5
			target_x -= sgn * 0.9
			rival_lane = clampi(lane_of(rival.position.x + sgn * 1.2), 0, 4)
			kmh *= 0.95
			rival_kmh *= 0.7
			rival_stun = 0.8
			ui.popup("SÜRTÜŞME!", Color(1.0, 0.75, 0.3))
		shake = 0.25
		buzz(120, 0.7)
		play("crash", 1.3, -10.0)
	if distance >= RACE_LEN or rival_dist >= RACE_LEN:
		race_on = false
		if distance >= rival_dist:
			score += 1500
			play("confirm")
			crash(null, "YARIŞI KAZANDIN", false)
		else:
			crash(null, "YARIŞI KAYBETTİN", false)


# Yarış göstergesi: sıra, rakiple ara, kalan yol.
func race_text() -> String:
	var gap := rival_dist - distance
	return "%d. SIRA   %s%d m\nKALAN %.1f km" % [2 if gap > 0.0 else 1, "-" if gap > 0.0 else "+", absi(int(gap)),
		maxf(RACE_LEN - distance, 0.0) / 1000.0]


# --- 3. şerit ---
# Bizim yönde ara sıra sağa bir şerit açılır, bir süre sonra kapanır. Köprüde olmaz: güverte yer bırakmaz
# (sahilde deniz duvarı da dışa kayar). Bölge sınırları çevre parçalarının sınırına denk gelir (40 m),
# böylece direkler ve korkuluk parça parça kayar; yol shader'ı aynı eğimi çizer.
const WIDEN_TAPER := 40.0


func wide_at(z: float) -> float:
	var w := travel - z
	return clampf((w - widen_a) / WIDEN_TAPER, 0.0, 1.0) * clampf((widen_b - w) / WIDEN_TAPER, 0.0, 1.0)


func widen_hits(a: float, b: float) -> bool:
	return a < widen_b + 40.0 and b > widen_a - 40.0


# Çevre parçasının 3. şerit hâli; w parçanın ortasının yol üstündeki yeri.
func widen_mode(w: float) -> int:
	w = roundf((w - 10.0) / Regions.GAP) * Regions.GAP + 10.0 # parça ortaları 40k + 10'da
	if absf(w - Regions.GAP * 0.5 - widen_a) < 1.0:
		return 2
	if absf(w + Regions.GAP * 0.5 - widen_b) < 1.0:
		return 3
	if w - Regions.GAP * 0.5 > widen_a + 1.0 and w + Regions.GAP * 0.5 < widen_b - 1.0:
		return 1
	return 0


func right_limit() -> float:
	return ROAD_HALF + Regions.WIDEN * wide_at(car.position.z)


func set_road(param: String, value: Variant) -> void:
	road_mat.set_shader_parameter(param, value)
	road_side_mat.set_shader_parameter(param, value)


func update_widen() -> void:
	if state == "play" and travel > next_widen and travel > widen_b + 50.0:
		# parçaların sınırı travel cinsinden 40k + 30'da (ilk dizilişten); 700 m ileride: en uzak parçanın da ötesi
		var a := ceilf((travel + 700.0 - 30.0) / Regions.GAP) * Regions.GAP + 30.0
		var b := a + Regions.GAP * randi_range(8, 14)
		var ok := region_at(a) != Regions.BRIDGE and region_at(b) != Regions.BRIDGE \
			and region_at((a + b) * 0.5) != Regions.BRIDGE and not tunnel_on \
			and not (works_on and works_start < b + 100.0 and works_start + WORK_LEN > a - 100.0)
		if ok:
			widen_a = a
			widen_b = b
			widen_said = 0
			next_widen = b + randf_range(1200.0, 2400.0)
			next_tunnel = maxf(next_tunnel, b - 200.0)
			if radar_at > a - 450.0 and radar_at < b + 50.0 and not radar_on:
				radar_at = b + 500.0
			if Profile.mode == "time" and cp_next > a - 40.0 and cp_next < b + 40.0:
				cp_next = b + 60.0 # kontrol noktası kapısının direği 3. şeritte kalmasın
		else:
			next_widen = travel + 300.0
	if widen_said == 0 and widen_a - travel < 250.0 and widen_a > travel:
		widen_said = 1
		ui.toast("SAĞDA 3. ŞERİT AÇILIYOR", Color(0.5, 0.9, 1.0))
	elif widen_said == 1 and widen_b - WIDEN_TAPER - travel < 220.0:
		widen_said = 2
		if car.position.x > 7.0:
			ui.toast("SAĞ ŞERİT BİTİYOR", Color(1.0, 0.75, 0.2))
			buzz(60, 0.5)
	set_road("widen", Vector2(travel - widen_a, travel - widen_b))
	for seg in road_side:
		seg.visible = wide_at(seg.position.z + 10.0) > 0.0 or wide_at(seg.position.z - 10.0) > 0.0


# z'de l şeridi yol çalışması yüzünden kapalı mı. CONTRA'da bizim iki şerit ve koniyle ayrılan dış karşı
# şerit (0) kapalı, 1 bize verilir.
func lane_closed(k: int, z: float) -> bool:
	if not works_on:
		return false
	var into := (travel - z) - works_start
	if into < -60.0 or into > WORK_LEN + 20.0:
		return false
	if works_lane == CONTRA:
		return k == 2 or k == 3 or k == 0
	return k == works_lane


func against_traffic() -> bool:
	return car.position.x < 0.0 and not lane_closed(2, car.position.z)


# Sol sınır: CONTRA bölgesinde karşı yönü ayıran koni sırasını geçemeyiz.
func left_limit() -> float:
	if works_on and works_lane == CONTRA:
		var into := travel - works_start
		if into > WORK_TAPER * 0.5 and into < WORK_LEN:
			return -3.5 + car.get_meta("half_w") + 0.2
	return -ROAD_HALF


func lane_of(x: float) -> int:
	var best := 0
	for k in LANES.size():
		if absf(LANES[k] - x) < absf(LANES[best] - x):
			best = k
	return best


# z'deki bir aracın önünü l şeridinde tıkayan trafik (yoksa null). Karşıdan gelen daha uzaktan sayılır:
# kapanma hızı yüksek. back: aracın bu kadar arkasındakiler de sayılır (şerit değiştirirken yan çarpma).
func lane_blocker(l: int, z: float, back := 6.0, skip: Node3D = null) -> Node3D:
	for c in traffic:
		if c == skip or not c.visible or c.get_meta("ghost", false) or c.get_meta("lane") != l:
			continue
		var ahead: float = z - c.position.z
		if ahead > -back and ahead < (60.0 if c.get_meta("dir") > 0 else 170.0):
			return c
	return null


# Boş şerit: önce kendi yönümüz (from_x'e en yakın), sonra karşı şerit. -1: hiçbiri boş değil.
# avoid_player: oyuncunun şeridine girme (dibimizdeyken önümüze kırmasın).
func free_lane(z: float, from_x: float, avoid_player: bool, skip: Node3D = null) -> int:
	var ours := OURS.duplicate()
	if wide_at(z) >= 1.0 and wide_at(z - 120.0) >= 1.0:
		ours.append(4)
	ours.sort_custom(func(a, b): return absf(LANES[a] - from_x) < absf(LANES[b] - from_x))
	var mine := player_lanes()
	for k in ours + [1, 0]:
		if lane_closed(k, z):
			continue
		if avoid_player and k in mine:
			continue
		if lane_blocker(k, z, 6.0, skip) == null:
			return k
	return -1


func update_siren(dt: float) -> void:
	if siren == hit_car:
		hit_update(siren, dt)
	else:
		var before := siren.position.z - car.position.z
		siren.position.z -= SIREN_REL * dt
		var l: int = siren.get_meta("lane")
		# yolunu tıkıyorsak kısa bir an arkamızda bekler; kenara çekilirsek geçer, ödül alırız
		var dz := siren.position.z - car.position.z
		var by_us := absf(siren.position.x - car.position.x) < side_gap(siren) + 0.3 and dz > 0.0 and dz < 14.0
		if by_us:
			siren.position.z = move_toward(siren.position.z, car.position.z + 12.0, 30.0 * dt)
			if state == "play" and not siren.get_meta("blocked"):
				siren.set_meta("blocked", true)
				siren.set_meta("wait", 0.0)
				ui.toast("SİRENE YOL VER!", Color(1.0, 0.4, 0.4))
				buzz(60, 0.5)
			siren.set_meta("wait", siren.get_meta("wait", 0.0) + dt)
		# önü trafikle doluysa ya da 1,5 sn yol vermezsek beklemez: boş şeritten, gerekirse karşı şeritten geçer
		if lane_blocker(l, siren.position.z) != null or (by_us and siren.get_meta("wait", 0.0) > 1.5):
			var k := free_lane(siren.position.z, LANES[l], dz > -40.0 and dz < 30.0 and not by_us)
			if k < 0 and l in ONCOMING:
				k = 3 if car.position.x < 3.5 else 2 # karşıdan araç geliyor, boş yer yoksa kendi yönüne döner
			if k >= 0 and k != l:
				l = k
				siren.set_meta("lane", l)
				siren.set_meta("blocked", false) # kendi yolunu bulduysa ödül yok
		# hiçbir şerit boş değilse öndeki (aynı yöndeki) aracın arkasında yavaşlar
		var b := lane_blocker(l, siren.position.z, 0.0)
		if b != null and b.get_meta("dir") > 0 and siren.position.z - b.position.z < 9.0:
			siren.position.z = b.position.z + 9.0
		siren.position.x = lerpf(siren.position.x, LANES[l], 1.0 - exp(-6.0 * dt))
		if state == "play" and Profile.mode != "free" and not siren.get_meta("ghost"):
			if touching(siren):
				if before > 0.6 * len_gap(siren):
					siren.position.z = car.position.z + len_gap(siren) # arkadan bindirmez, hak gitmez
				else:
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
	build_player_extras(car.get_meta("rear"), id)


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
	var pd: Array = Profile.PAINTS[paint_index]
	player_mat.set_shader_parameter("paint", pd[1])
	player_mat.set_shader_parameter("finish", pd[3] if pd.size() > 3 else 0)
	if pd.size() > 4:
		player_mat.set_shader_parameter("paint2", pd[4])
	add_blob(root, rear)
	for s in [-1.0, 1.0]:
		Build.streak(root, Vector3(s * 0.5, 0, rear), Color(1.0, 0.08, 0.04), 0.6, 7.0, 1.5)
	root.set_meta("rear", rear)
	root.set_meta("hood_y", hood_height(root, rear))
	root.set_meta("half_w", half_w)
	root.set_meta("half_l", rear)
	root.set_meta("top", 1.34 if id == "r34" else (model.find_children("body", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb().end.y * KENNEY_SCALE.y)
	player_mat.set_shader_parameter("car_size", Vector3(half_w, root.get_meta("top"), rear)) # desen ölçüsü
	return root


func build_player_extras(rear: float, id: String) -> void:
	if flame_mat == null:
		flame_mat = glow_mat()
		core_mat = glow_mat()
	# egzoz alevi: dışta geniş renkli koni, içte ince parlak çekirdek; pivotun z ölçeği boyu verir
	for s in [-1.0, 1.0]:
		var f := Node3D.new()
		f.position = Vector3(s * 0.4, 0.3, rear + 0.05)
		f.visible = false
		for layer in [[0.085, 1.0, flame_mat], [0.04, 0.6, core_mat]]:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = layer[0]
			cone.height = layer[1]
			cone.radial_segments = 8
			cone.rings = 1
			var mi := MeshInstance3D.new()
			mi.mesh = cone
			mi.material_override = layer[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.rotation.x = PI * 0.5 # koninin ucu arkaya (+z) bakar
			mi.position.z = layer[1] * 0.5
			f.add_child(mi)
		car.add_child(f)
		flames.append(f)
	build_spray(car.get_meta("half_w"), rear)
	var head := SpotLight3D.new()
	head.light_color = Color(0.85, 0.9, 1.0)
	head.light_energy = 2.2
	head.spot_range = 50.0
	head.spot_angle = 42.0 # geniş ve yumuşak: yolun iki yanı da aydınlansın
	head.spot_angle_attenuation = 0.6
	head.position = Vector3(0, 0.7, -rear)
	head.rotation_degrees.x = -6.0
	car.add_child(head)
	# far camları ve yola düşen ışık; garajda alınan sis farı ve Amerikan park
	var hw: float = car.get_meta("half_w")
	var ly := clampf(car.get_meta("hood_y") - 0.3, 0.45, 0.85)
	for s in [-1.0, 1.0]:
		add_glow(car, Vector3(s * (hw - 0.3), ly, -rear - 0.05), Color(1.0, 0.95, 0.85), 0.55)
	add_beam(car, -rear, -1.0, 8.0, 32.0, Color(1.0, 0.95, 0.85), 0.28)
	if Profile.extra(id, "fog") == 2:
		for s in [-1.0, 1.0]:
			add_glow(car, Vector3(s * (hw - 0.35), 0.3, -rear - 0.05), Color(1.0, 0.8, 0.3), 0.42)
		add_beam(car, -rear, -1.0, 9.0, 14.0, Color(1.0, 0.78, 0.3), 0.35) # alçak, geniş, sarı
	if Profile.extra(id, "amber") == 2:
		for s in [-1.0, 1.0]:
			add_glow(car, Vector3(s * (hw - 0.04), ly - 0.05, -rear + 0.15), Color(1.0, 0.5, 0.05), 0.34) # köşe
	# arabanın kendi dolgu ışığı: lamba uzaktayken de gövde seçilsin
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.7, 0.8, 1.0)
	fill.light_energy = 1.2
	fill.omni_range = 7.0
	fill.position = Vector3(0, 3.0, 3.5)
	car.add_child(fill)


func glow_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# Arka tekerleklerin kaldırdığı su sisi. Dünya araca göre +z akar: damlalar önce arabayla gider,
# hava sürtünmesiyle geri kalıp (+z ivme) büyüyerek söner. Arkadaki stop lambaları sisi kızıla boyar.
func build_spray(half_w: float, rear: float) -> void:
	spray = GPUParticles3D.new()
	spray.amount = 24
	spray.lifetime = 0.6
	spray.position = Vector3(0, 0.25, rear - 0.6)
	spray.visibility_aabb = AABB(Vector3(-3, -1, -2), Vector3(6, 4, 14))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(half_w * 0.8, 0.05, 0.15)
	pm.direction = Vector3(0, 0.3, 1)
	pm.spread = 14.0
	pm.initial_velocity_min = 2.0
	pm.initial_velocity_max = 4.0
	pm.linear_accel_min = 18.0
	pm.linear_accel_max = 30.0
	pm.gravity = Vector3(0, -3, 0)
	pm.scale_min = 0.4
	pm.scale_max = 0.7
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 1.8))
	pm.scale_curve = CurveTexture.new()
	(pm.scale_curve as CurveTexture).curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.45, 0.25, 0.25, 0.07))
	fade.set_color(1, Color(0.25, 0.27, 0.32, 0.0))
	pm.color_ramp = GradientTexture1D.new()
	(pm.color_ramp as GradientTexture1D).gradient = fade
	spray.process_material = pm
	var dot := GradientTexture2D.new() # yumuşak yuvarlak leke, dosya gerekmez
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(0.5, 0.0)
	dot.gradient = Gradient.new()
	dot.gradient.set_color(0, Color(1, 1, 1, 1))
	dot.gradient.set_color(1, Color(1, 1, 1, 0))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot
	var q := QuadMesh.new()
	q.material = m
	spray.draw_pass_1 = q
	car.add_child(spray)


# Kenney Car Kit modeli (cars/kenney, CC0). Modelin önü +z: bizim yönde 180° çevrilir, arkası bize
# döner; karşı yönde (oncoming) çevrilmez, farları yanık olarak üstümüze gelir.
func make_kenney(model_name: String, oncoming := false, scale := KENNEY_SCALE) -> Node3D:
	var root := Node3D.new()
	var model: Node3D = models[model_name].instantiate()
	model.rotation.y = 0.0 if oncoming else PI
	model.scale = scale
	root.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = kenney_mat
	var rear := kenney_rear(model)
	var body: MeshInstance3D = model.find_children("body", "MeshInstance3D", true, false)[0]
	var aabb := body.get_aabb()
	root.set_meta("top", (aabb.end.y + body.position.y) * scale.y)
	root.set_meta("half_w", aabb.size.x * 0.5 * scale.x)
	root.set_meta("half_l", rear)
	add_blob(root, rear)
	# farlar her araçta yanar; bizim yöndekilerin ışığı önlerindeki yola düşer, arkamızdakiler selektör yapar
	var nose := (aabb.end.z + body.position.z) * scale.z * (1.0 if oncoming else -1.0)
	var dir := 1.0 if oncoming else -1.0
	for s in [-1.0, 1.0]:
		if oncoming: # bizim yöndekilerin önü bize dönük değil, hâle yalnız karşıdan gelende
			add_glow(root, Vector3(s * 0.55 * scale.x, 0.55, nose + 0.1), Color(1.0, 0.92, 0.75), 0.7, 1.0)
			Build.streak(root, Vector3(s * 0.55 * scale.x, 0, nose), Color(1.0, 0.9, 0.7), 0.6, 10.0, 1.3)
		else:
			Build.streak(root, Vector3(s * 0.55 * scale.x, 0, rear), Color(1.0, 0.08, 0.04), 0.5, 7.0, 1.5)
	var beam := add_beam(root, nose, dir, 5.5 * scale.x, 24.0, Color(1.0, 0.92, 0.8), 0.3)
	beam.visible = oncoming # bizim yöndekinin ışığı önüne düşer, bize görünmez: yalnız selektörde açılır
	root.set_meta("beam", beam)
	return root


# Far ışığının yola düşen kısmı (beam.gdshader). dir +1: +z'ye (bize doğru), -1: ileri.
func add_beam(root: Node3D, at_z: float, dir: float, width: float, length: float, color: Color, energy: float) -> MeshInstance3D:
	var key := "%s%.2f" % [color.to_html(), energy]
	if not beam_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://beam.gdshader")
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("energy", energy)
		beam_mats[key] = m
	var mi := Build.plane(root, Vector2(width, length), Vector3(0, 0.05, at_z + dir * length * 0.5), beam_mats[key])
	mi.rotation.y = 0.0 if dir > 0.0 else PI # UV.y hep aracın önünden ışığın ucuna
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.layers = 2
	return mi


# Far camı yerine ışık hâlesi: toplamalı, yumuşak kenarlı, yalnız önden görünür (arka yüzü çizilmez;
# her yöne dönük olsaydı basık araçlarda farlar arkadan da parlıyordu). facing +1: +z'ye bakar.
func add_glow(root: Node3D, pos: Vector3, color: Color, size: float, facing := -1.0) -> MeshInstance3D:
	var key := color.to_html()
	if not glow_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = glow_tex
		m.albedo_color = color
		glow_mats[key] = m
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = glow_mats[key]
	mi.position = pos
	mi.rotation.y = 0.0 if facing > 0.0 else PI # QuadMesh'in önü +z
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


func set_beam(c: Node3D, v: float) -> void:
	var b: MeshInstance3D = c.get_meta("beam", null)
	if b:
		b.set_instance_shader_parameter("boost", v)
		if c.get_meta("dir", 1) > 0:
			b.visible = v > 1.0


# Modelin ölçeğiyle arka ucu (z); model.scale önceden ayarlanmış olmalı.
func kenney_rear(model: Node3D) -> float:
	var body: MeshInstance3D = model.find_children("body", "MeshInstance3D", true, false)[0]
	return -(body.get_aabb().position.z + body.position.z) * model.scale.z


# Kaputun yüksekliği: aracın ön %27'lik kısmındaki en yüksek köşe. Kaput kamerası bunun üstüne konur;
# sabit oranla konunca bazı modellerde kamera gövdenin içinde kalıp aracın içini gösteriyordu.
func hood_height(root: Node3D, rear: float) -> float:
	var hy := 0.5
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = mi.transform
		var n := mi.get_parent()
		while n != null:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		for v in (mi as MeshInstance3D).mesh.get_faces():
			var w: Vector3 = t * v
			if w.z < -rear * 0.45:
				hy = maxf(hy, w.y)
	return hy


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

	# Yol 20 m'lik parçalar: Mobile renderer ışıkları nesne başına atar; tek parça 420 m yolda her piksel
	# menzildeki bütün lambaları hesaplıyordu (tablette yolun payı 16 ms idi). Parça yalnız yakın ışıkları alır.
	road_mat = ShaderMaterial.new()
	road_mat.shader = preload("res://road.gdshader")
	var rm := PlaneMesh.new()
	rm.size = Vector2(16, 20)
	road_side_mat = ShaderMaterial.new()
	road_side_mat.shader = preload("res://road_side.gdshader")
	var sm := PlaneMesh.new()
	sm.size = Vector2(3.6, 20)
	for i in 21:
		var road := MeshInstance3D.new()
		road.mesh = rm
		road.position.z = 10.0 - i * 20.0
		road.material_override = road_mat
		road.layers = 2 # yansıma kamerası yolu çizmez
		add_child(road)
		var side := MeshInstance3D.new() # 3. şerit: yalnız genişleyen bölgede görünür
		side.mesh = sm
		side.position = Vector3(9.8, 0, road.position.z)
		side.material_override = road_side_mat
		side.layers = 2
		side.visible = false
		add_child(side)
		road_side.append(side)



# Düzlem yansıması: ana kamerayı yol düzlemine (y = 0) göre aynalayan kamera. Görüntüsü dikey ters; yol
# shader'ı SCREEN_UV'nin y'sini çevirip okur. Yol, zemin, güverte, far ışığı ve sahte yansıma şeritleri
# 2. katmanda: ayna kamerası yalnız 1. katmanı çizer, altlarından bakınca görüntüyü kapatmazlar.
func build_reflection() -> void:
	refl_vp = SubViewport.new()
	refl_vp.size = Vector2i(180, 320)
	refl_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	refl_cam = Camera3D.new()
	refl_cam.cull_mask = 1
	refl_cam.keep_aspect = Camera3D.KEEP_WIDTH
	refl_cam.near = 0.1
	refl_cam.far = 160.0
	refl_vp.add_child(refl_cam)
	add_child(refl_vp)
	set_road("refl_tex", refl_vp.get_texture())


func update_reflection() -> void:
	if refl_vp.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		return
	var t := cam.global_transform
	var m := func(v: Vector3) -> Vector3: return Vector3(v.x, -v.y, v.z)
	# aynalanmış taban sol elli olur; y eksenini çevirip sağ elli yap (görüntü baş aşağı, shader düzeltir)
	refl_cam.global_transform = Transform3D(Basis(m.call(t.basis.x), -m.call(t.basis.y), m.call(t.basis.z)), m.call(t.origin))
	refl_cam.fov = cam.fov


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
	lens_rect = lens
	fx.add_child(lens)
	add_child(fx)
