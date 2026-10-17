# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends CanvasLayer

# Oyun içi gösterge, ana menü, garaj ve kaza ekranı; hepsi koddan kurulur.
# Yerleşim 720 px genişlik tabanlı: üst öğeler üste, alt öğeler alta sabitlenir.

var main # main.gd; tipsiz, çünkü onun alanlarına doğrudan erişiyoruz
var garage_open := false
var g_rim_i := 0
var settings_open := false
var g_car := 0
var g_paint := 0

var play_box: Control
var menu_box: Control
var garage_box: Control
var over_box: Control

var gauge: Control
var nitro_bar: Control
var fps_label: Label
var top_inset := 0.0
var score_label: Label
var km_label: Label
var combo_label: Label
var popup_label: Label
var toast_label: Label
var hint_label: Label
var popup_tween: Tween
var toast_tween: Tween

var best_pill: Label
var coin_pill: Label
var menu_card: VBoxContainer
var speed_lines: Control
var title_font: FontVariation
var tap_label: Label

var settings_box: Control
var set_rows := [] # [düğmeler, seçili indeksi veren Callable]
var signs: Control
var works_d := -1.0 # yol çalışmasına kalan m; 0 içindeyiz, < 0 yok
var works_sub := ""
var radar_d := -1.0
var chase_s := -1.0 # polis kovalamacasında kalan sn
var near_label: Label # yakın geçiş puanı: arabanın dibinde, küçük
var near_tween: Tween
var road_box: Control
var online_box: Control # online yarış paneli (net.gd)
var on_status: Label
var on_code: Label
var on_copy: Button
var on_start: Button

var g_coins: Label
var g_name: Label
var g_status: Label
var g_paint_label: Label
var g_action: Button
var swatches: Array[Button] = []

var over_score: Label
var over_detail: Label
var over_missions: Label

var tip_box: Control
var tip_taps: Control
var curtain: ColorRect

var over_title: Label
var mode_buttons: Array[Button] = []
var timer_label: Label
var flash_rect: ColorRect
var cockpit: Control
var pause_box: Control
var pause_title: Label
var count_label: Label # online: devam ve başlangıç geri sayımı
var count_t := 0.0
var counting := false
var hud_missions: Label
var race_label: Label
var hb_btn: Button
var rival_back: Label # rakip geride: altta ok ve mesafe
var racers: Array[Label] = [] # online yarışta solda üstte katılımcılar: sen ve arkadaşın (ping'iyle)
var np_label: Label # çalan parça
var station_buttons: Array[Button] = []
var cam_buttons: Array[Button] = []
var up_rows := {} # geliştirme anahtarı -> [ad, çubuk, düğme]


func _ready() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS # duraklatma menüsü oyun dururken de çalışsın
	main = get_parent()
	top_inset = safe_top()
	build_play()
	build_menu()
	build_garage()
	build_over()
	build_tip()
	build_settings()
	build_pause()
	build_road()
	build_online()


# Açık bir panel varken (garaj, ayarlar) dokunuş ve Enter oyunu başlatmaz.
func panel_open() -> bool:
	return garage_open or settings_open or road_box.visible or online_box.visible


# --- Oyun içi ---

func build_play() -> void:
	play_box = box()
	cockpit = Control.new() # kokpit kamerasında pano, direksiyon ve silecekler; HUD'un arkasında
	cockpit.set_anchors_preset(Control.PRESET_FULL_RECT)
	cockpit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cockpit.draw.connect(draw_cockpit)
	play_box.add_child(cockpit)
	# ortada, nitro çubuğunun altında: üstte kamera deliğine, köşede ekranın yuvarlak kenarına denk geliyordu
	fps_label = label(play_box, 14, 384)
	fps_label.modulate.a = 0.55
	gauge = Control.new()
	gauge.anchor_left = 0.5
	gauge.anchor_right = 0.5
	gauge.offset_left = -130.0
	gauge.offset_right = 130.0
	gauge.offset_top = 46.0
	gauge.offset_bottom = 246.0
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.draw.connect(draw_gauge)
	play_box.add_child(gauge)
	score_label = label(play_box, 36, 214)
	km_label = label(play_box, 20, 258)
	combo_label = label(play_box, 24, 284)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	nitro_bar = Control.new()
	nitro_bar.anchor_left = 0.5
	nitro_bar.anchor_right = 0.5
	nitro_bar.offset_left = -140.0
	nitro_bar.offset_right = 140.0
	nitro_bar.offset_top = 326.0
	nitro_bar.offset_bottom = 342.0
	nitro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nitro_bar.draw.connect(draw_nitro)
	play_box.add_child(nitro_bar)
	popup_label = label(play_box, 26, 440) # yakın geçiş vb.: küçük, göstergenin altında, yolu kapatmaz
	popup_label.modulate.a = 0.0
	toast_label = label(play_box, 22, 476)
	toast_label.modulate.a = 0.0
	timer_label = label(play_box, 40, 100) # zamana karşı: sağda, düğmelerin altında kalan süre
	timer_label.anchor_left = 0.5
	timer_label.anchor_right = 0.5
	timer_label.offset_left = 150.0
	timer_label.offset_right = 360.0
	near_label = Label.new()
	near_label.add_theme_font_size_override("font_size", 18)
	near_label.add_theme_constant_override("outline_size", 6)
	near_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	near_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	near_label.modulate.a = 0.0
	play_box.add_child(near_label)
	flash_rect = ColorRect.new() # radar flaşı
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(flash_rect)
	icon_button(play_box, "pause", 306, 18, func(): main.set_pause(true))
	icon_button(play_box, "radio", 224, 18, func(): main.change_station())
	icon_button(play_box, "camera", 142, 18, func(): main.change_cam())
	# el freni: sağ altta, başparmağın altında; basılı tutulur. Dokunuşu main okur (ikinci parmakla da çalışsın), düğme yalnız görüntü
	hb_btn = button(play_box, "", 262, -250, 116, 116, func(): pass, true, 16)
	hb_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb_btn.draw.connect(draw_icon.bind(hb_btn, "handbrake"))
	# sol üstte günlük görevler
	hud_missions = Label.new()
	hud_missions.offset_left = 12.0
	hud_missions.offset_top = 14.0
	hud_missions.add_theme_font_size_override("font_size", 14)
	hud_missions.add_theme_constant_override("outline_size", 6)
	hud_missions.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud_missions.add_theme_constant_override("line_spacing", 2)
	hud_missions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(hud_missions)
	for i in 2:
		var r := Label.new()
		r.offset_left = 12.0
		r.offset_top = 78.0 + i * 24.0
		r.add_theme_font_size_override("font_size", 17)
		r.add_theme_constant_override("outline_size", 6)
		r.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		play_box.add_child(r)
		racers.append(r)
	race_label = label(play_box, 22, 100)
	race_label.anchor_left = 0.5
	race_label.anchor_right = 0.5
	race_label.offset_left = 150.0
	race_label.offset_right = 360.0
	race_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	rival_back = label(play_box, 26, -330, "", true)
	rival_back.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	rival_back.add_theme_constant_override("outline_size", 6)
	rival_back.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	# sağda yaklaşan yol çalışması (turuncu duba) ve radar (mavi kamera) ikonları, altında kalan metre
	signs = Control.new()
	signs.anchor_left = 0.5
	signs.anchor_right = 0.5
	signs.offset_left = 240.0
	signs.offset_right = 356.0
	signs.offset_top = 520.0
	signs.offset_bottom = 800.0
	signs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	signs.draw.connect(draw_signs)
	play_box.add_child(signs)
	hint_label = label(play_box, 24, -260, "Sağa sola kaydır: direksiyon\nBasılı tut: fren\nÇift dokun: nitro", true)


func update_hud() -> void:
	if tip_box.visible:
		tip_taps.queue_redraw()
	if menu_box.visible:
		tap_label.modulate.a = 0.55 + 0.45 * sin(main.alive * 4.0)
		speed_lines.queue_redraw()
	if not play_box.visible:
		return
	gauge.queue_redraw()
	signs.visible = works_d >= 0.0 or radar_d >= 0.0 or chase_s >= 0.0 or main.against_traffic()
	if signs.visible:
		signs.queue_redraw()
	nitro_bar.queue_redraw()
	cockpit.visible = main.cam_mode() == 3
	gauge.visible = not cockpit.visible # kokpitte hız ve vites panodaki ekranda
	if cockpit.visible:
		cockpit.queue_redraw()
	if timer_label.visible:
		set_text(timer_label, "%.1f" % main.time_left)
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if main.time_left < 5.0 else Color(1, 1, 1))
	# metni yalnız değişince ata: her atama yazıyı yeniden şekillendirir
	set_text(fps_label, "%d FPS" % Engine.get_frames_per_second())
	set_text(score_label, str(int(main.score)))
	set_text(km_label, "%.2f km" % (main.distance / 1000.0) + ("   ·   %d COIN" % main.run_coins if main.run_coins > 0 else ""))
	set_text(combo_label, main.hud_tags())
	if Engine.get_process_frames() % 20 == 0: # görev metni sık değişmez
		set_text(hud_missions, hud_missions_text())
	race_label.visible = main.race_on
	for r in racers:
		r.visible = main.online and main.race_on
	if racers[0].visible and (Engine.get_process_frames() % 15 == 0 or racers[0].text == ""):
		var ms := int(Net.ping_ms)
		set_text(racers[0], "● SEN · " + Profile.car_info(Profile.car).name)
		set_text(racers[1], "● ARKADAŞIN · %s · %d ms" % [Profile.car_info(Net.remote.car).name, ms])
		racers[0].add_theme_color_override("font_color", Color(0.45, 0.85, 1.0))
		racers[1].add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if ms < 90 else (Color(1.0, 0.85, 0.3) if ms < 180 else Color(1.0, 0.4, 0.35)))
	if hb_btn.get_meta("on", false) != main.handbrake:
		hb_btn.set_meta("on", main.handbrake)
		hb_btn.queue_redraw()
		hb_btn.scale = Vector2.ONE * (0.94 if main.handbrake else 1.0)
		hb_btn.pivot_offset = hb_btn.size * 0.5
	var back: float = main.distance - main.rival_dist
	rival_back.visible = main.race_on and back > 12.0 # ekranda görünmüyor: ne kadar geride kaldığı
	if main.race_on:
		set_text(race_label, main.race_text())
		if rival_back.visible:
			set_text(rival_back, "▼  %s %d m GERİDE" % ["ARKADAŞIN" if main.online else "RAKİP", int(back)])
	hint_label.modulate.a = clampf(6.0 - main.run_time, 0.0, 1.0)


func set_text(l: Label, t: String) -> void:
	if l.text != t:
		l.text = t


# Devir saati: altı açık 240 derecelik yay, solda mavi, sağda kırmızı bölge; ortada vites, altta hız.
func draw_gauge() -> void:
	var c := Vector2(gauge.size.x * 0.5, 92.0)
	var r := 74.0
	var a0 := deg_to_rad(150.0)
	var a1 := deg_to_rad(390.0)
	gauge.draw_arc(c, r, a0, a1, 72, Color(1, 1, 1, 0.95), 4.0, true)
	gauge.draw_arc(c, r - 9.0, a0, deg_to_rad(205.0), 24, Color(0.15, 0.65, 1.0), 6.0, true)
	gauge.draw_arc(c, r - 9.0, deg_to_rad(300.0), deg_to_rad(345.0), 24, Color(1, 1, 1, 0.25), 6.0, true)
	gauge.draw_arc(c, r - 9.0, deg_to_rad(345.0), a1, 24, Color(1.0, 0.15, 0.15), 6.0, true)
	var a := lerpf(a0, a1, main.rpm) # ibre devri gösterir, vites atınca düşer
	var dir := Vector2(cos(a), sin(a))
	var needle := Color(1, 1, 1).lerp(Color(1.0, 0.2, 0.2), smoothstep(0.75, 0.95, main.rpm))
	gauge.draw_line(c + dir * 24.0, c + dir * (r + 2.0), needle, 4.0, true)
	var font := ThemeDB.fallback_font
	gauge.draw_string(font, c + Vector2(-60, 22), str(main.gear), HORIZONTAL_ALIGNMENT_CENTER, 120, 64)
	var sp := str(roundi(main.kmh))
	var w1 := font.get_string_size(sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	var w2 := font.get_string_size(" KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x0 := c.x - (w1 + w2) * 0.5
	gauge.draw_string(font, Vector2(x0, c.y + 60.0), sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 30)
	gauge.draw_string(font, Vector2(x0 + w1, c.y + 60.0), " KM/H", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))


# Yol çalışması uyarısı; boş metin gizler, flash yaklaşınca yanıp söndürür.
func set_works_sign(d: float, sub := "") -> void:
	works_d = d
	works_sub = sub


func set_radar_sign(d: float) -> void:
	radar_d = d


func draw_signs() -> void:
	var font := ThemeDB.fallback_font
	var cx := signs.size.x * 0.5
	var y := 0.0
	var blink := 0.6 + 0.4 * sin(main.alive * 9.0)
	if works_d >= 0.0:
		var a := blink if works_d < 300.0 else 1.0 # yaklaşınca yanıp söner
		var orange := Color(1.0, 0.45, 0.05, a)
		var white := Color(1, 1, 1, a)
		var tip := Vector2(cx, y + 4.0)
		var hw := func(yy: float) -> float: return 24.0 * (yy - tip.y) / 50.0 # dubanın o yükseklikteki yarı eni
		signs.draw_colored_polygon(PackedVector2Array([tip, Vector2(cx + 24.0, y + 54.0), Vector2(cx - 24.0, y + 54.0)]), orange)
		for band in [[22.0, 30.0], [38.0, 46.0]]: # beyaz reflektör bantları
			var y0: float = y + band[0]
			var y1: float = y + band[1]
			signs.draw_colored_polygon(PackedVector2Array([Vector2(cx - hw.call(y0), y0), Vector2(cx + hw.call(y0), y0),
				Vector2(cx + hw.call(y1), y1), Vector2(cx - hw.call(y1), y1)]), white)
		signs.draw_rect(Rect2(cx - 32.0, y + 54.0, 64.0, 9.0), Color(0.8, 0.3, 0.02, a))
		var t := "%d m" % int(works_d) if works_d > 0.0 else "BURADA"
		signs.draw_string(font, Vector2(0, y + 90.0), t, HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 24, Color(1.0, 0.75, 0.2, a))
		signs.draw_string(font, Vector2(0, y + 112.0), works_sub, HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 15, white)
		y += 136.0
	if radar_d >= 0.0:
		var a := blink if radar_d < 250.0 else 1.0
		var white := Color(1, 1, 1, a)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.25, 0.8, a)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = white
		signs.draw_style_box(sb, Rect2(cx - 32.0, y, 64.0, 56.0))
		signs.draw_rect(Rect2(cx - 17.0, y + 19.0, 34.0, 22.0), white, false, 3.0) # kamera gövdesi
		signs.draw_rect(Rect2(cx - 8.0, y + 13.0, 12.0, 6.0), white)
		signs.draw_arc(Vector2(cx, y + 30.0), 6.0, 0.0, TAU, 20, white, 3.0, true)
		signs.draw_string(font, Vector2(0, y + 86.0), "%d m" % int(radar_d), HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 24, Color(0.5, 0.75, 1.0, a))
		signs.draw_string(font, Vector2(0, y + 106.0), "RADAR", HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 15, white)
		y += 130.0
	if chase_s >= 0.0: # polis: tepe lambası kırmızı-mavi çakar, altında kalan sn
		var on := fmod(main.alive * 3.0, 1.0) < 0.5
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.08, 0.12)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = Color(1.0, 0.25, 0.25)
		signs.draw_style_box(sb, Rect2(cx - 32.0, y, 64.0, 56.0))
		signs.draw_rect(Rect2(cx - 22.0, y + 10.0, 21.0, 12.0), Color(1.0, 0.1, 0.1) if on else Color(0.35, 0.05, 0.05))
		signs.draw_rect(Rect2(cx + 1.0, y + 10.0, 21.0, 12.0), Color(0.15, 0.35, 1.0) if not on else Color(0.05, 0.1, 0.35))
		signs.draw_string(font, Vector2(0, y + 47.0), "POLİS", HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 15, Color(1, 1, 1))
		signs.draw_string(font, Vector2(0, y + 86.0), "%d SN" % ceili(chase_s), HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 24, Color(1.0, 0.45, 0.45))
		signs.draw_string(font, Vector2(0, y + 106.0), "KAÇ!", HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 15, Color(1, 1, 1))
		y += 130.0
	if main.state == "play" and main.against_traffic(): # karşı şerit: zıt oklar, puan çarpanı
		var c := Vector2(cx, y + 28.0)
		signs.draw_circle(c, 28.0, Color(1.0, 0.5, 0.1))
		var w := Color(1, 1, 1)
		signs.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -16), c + Vector2(-2, -4), c + Vector2(-18, -4)]), w)
		signs.draw_rect(Rect2(c.x - 12.0, c.y - 4.0, 4.0, 18.0), w)
		signs.draw_colored_polygon(PackedVector2Array([c + Vector2(10, 16), c + Vector2(2, 4), c + Vector2(18, 4)]), w)
		signs.draw_rect(Rect2(c.x + 8.0, c.y - 14.0, 4.0, 18.0), w)
		signs.draw_string(font, Vector2(0, y + 86.0), "x%.1f" % main.ONCOMING_MULT, HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 24, Color(1.0, 0.65, 0.3))
		signs.draw_string(font, Vector2(0, y + 106.0), "KARŞI ŞERİT", HORIZONTAL_ALIGNMENT_CENTER, signs.size.x, 15, w)


func draw_nitro() -> void:
	var w := nitro_bar.size.x
	var h := nitro_bar.size.y
	var f: float = main.nitro_level()
	var active: bool = main.nitro_t > 0.0
	var is_ready: bool = main.nitro >= 0.1 and not active # %10 dolunca kullanılır
	var col := Color(0.35, 0.5, 1.0).lerp(Color(0.8, 0.4, 1.0), f)
	if is_ready:
		col = col.lightened(0.3 + 0.3 * sin(main.alive * 8.0))
	nitro_bar.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
	nitro_bar.draw_rect(Rect2(0, 0, w * f, h), col)
	nitro_bar.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.6), false, 2.0)
	nitro_bar.draw_line(Vector2(w * 0.1, 0), Vector2(w * 0.1, h), Color(1, 1, 1, 0.7), 2.0) # kullanılabilir eşiği
	var text := "NİTRO!" if active else ("NİTRO HAZIR · ÇİFT DOKUN" if is_ready else "NİTRO")
	nitro_bar.draw_string(ThemeDB.fallback_font, Vector2(0, h + 20), text, HORIZONTAL_ALIGNMENT_CENTER, w, 16)


func popup(text: String, color := Color(1, 1, 1)) -> void:
	if popup_tween:
		popup_tween.kill()
	popup_label.text = text
	popup_label.add_theme_color_override("font_color", color)
	popup_label.offset_top = 440.0
	popup_label.modulate.a = 1.0
	popup_tween = create_tween().set_parallel()
	popup_tween.tween_property(popup_label, "offset_top", 410.0, 0.8)
	popup_tween.tween_property(popup_label, "modulate:a", 0.0, 0.6).set_delay(0.3)


func toast(text: String, color: Color) -> void:
	if toast_tween:
		toast_tween.kill()
	toast_label.text = text
	toast_label.add_theme_color_override("font_color", color)
	toast_label.modulate.a = 1.0
	toast_tween = create_tween()
	toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6).set_delay(1.4)


func show_play() -> void:
	settings_box.visible = false
	menu_box.visible = false
	over_box.visible = false
	garage_box.visible = false
	play_box.visible = true
	var free := Profile.mode == "free"
	score_label.visible = not free # serbest sürüşte puan yok
	combo_label.visible = not free
	timer_label.visible = Profile.mode == "time"
	chase_s = -1.0


func _process(dt: float) -> void:
	if garage_box.visible and g_ind: # bölümlü sekmenin seçim kapsülü: kritik sönümlü, o anki yerinden kayar
		var tx := -326.0 + g_tab * 132.0
		g_ind.offset_left = lerpf(g_ind.offset_left, tx, 1.0 - exp(-dt * 16.0))
		g_ind.offset_right = g_ind.offset_left + 124.0
	if pause_box.visible:
		set_text(np_label, main.now_playing()) # parça bitip yenisi başlarsa güncel kalsın
	if counting: # oyun dururken de akar (bu düğüm duraklatmada da çalışır)
		count_t -= dt
		set_text(count_label, str(ceili(count_t)) if count_t > 0.0 else "BAŞLA!")
		if count_t <= 0.0 and main.paused:
			main.set_pause(false, true)
		if count_t <= -0.4: # "BAŞLA!" bir an görünür
			stop_countdown()
	if main.online and main.race_on and main.paused and (not Net.connected or Net.remote.quit):
		stop_countdown()
		main.set_pause(false, true) # yarış update_online'da biter


func _notification(what: int) -> void:
	if main == null:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		main.on_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile") and main.state == "play" and not main.paused:
		main.set_pause(true) # telefonda uygulamadan çıkınca oyun durur


func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_pressed() and not e.is_echo() and e.keycode in [KEY_ESCAPE, KEY_P] and main.state == "play":
		main.set_pause(not main.paused) # masaüstünde Esc/P


func close_panels() -> void:
	road_box.visible = false
	if online_box.visible:
		close_online()
	if garage_open:
		close_garage()
	if settings_open:
		close_settings()


# --- Duraklatma ---

func build_pause() -> void:
	pause_box = box()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_box.add_child(dim)
	pause_title = label(pause_box, 56, 140, "DURAKLATILDI")
	pause_title.add_theme_font_override("font", title_font)
	count_label = label(play_box, 180, 460) # duraklatma panelinin altında kalmasın diye o kapanınca görünür
	count_label.add_theme_font_override("font", title_font)
	count_label.add_theme_constant_override("outline_size", 24)
	count_label.visible = false
	primary(button(pause_box, "DEVAM", 0, 250, 360, 84, func(): main.set_pause(false), false, 32))
	button(pause_box, "YENİDEN BAŞLA", 0, 352, 300, 62, func(): main.restart(), false, 24)
	button(pause_box, "MENÜ", 0, 430, 300, 62, func(): main.to_menu(), false, 24)
	label(pause_box, 24, 540, "RADYO").add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	np_label = label(pause_box, 22, 576)
	np_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.9))
	for i in Profile.STATIONS.size():
		station_buttons.append(button(pause_box, Profile.STATIONS[i], -200.0 + i * 200.0, 618, 186, 58, pick_station.bind(i), false, 20))
	button(pause_box, "SONRAKİ ŞARKI", 0, 690, 300, 58, func(): main.next_track(), false, 20)
	label(pause_box, 24, 790, "KAMERA").add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	for i in Profile.CAMS.size():
		cam_buttons.append(button(pause_box, Profile.CAMS[i], -225.0 + i * 150.0, 832, 140, 58, pick_cam.bind(i), false, 18))


func show_pause(on: bool) -> void:
	pause_box.visible = on
	pause_title.text = "ARKADAŞIN OYUNU\nDURDURDU" if main.remote_paused else "DURAKLATILDI"
	pause_title.add_theme_font_size_override("font_size", 40 if main.remote_paused else 56)
	refresh_pause()


func start_countdown(sec: float) -> void:
	count_t = sec
	counting = true
	count_label.add_theme_font_size_override("font_size", 180)
	pause_box.visible = false
	count_label.visible = true


# Arkadaşın sahnesi yüklenene kadar: sayı yok, bekleme yazısı.
func wait_countdown() -> void:
	counting = false
	pause_box.visible = false
	count_label.visible = true
	set_text(count_label, "HAZIRLANIYOR…")
	count_label.add_theme_font_size_override("font_size", 48)


func stop_countdown() -> void:
	counting = false
	count_label.visible = false


func refresh_pause() -> void:
	set_text(np_label, main.now_playing())
	for i in station_buttons.size():
		neon(station_buttons[i], ACCENT if i == Profile.radio else NEUTRAL)
	for i in cam_buttons.size():
		neon(cam_buttons[i], ACCENT if i == Profile.cam else NEUTRAL)


func pick_station(i: int) -> void:
	main.set_station(i)
	refresh_pause()


func pick_cam(i: int) -> void:
	main.set_cam(i)
	refresh_pause()


# Yuvarlak neon düğme, üstüne kodla çizilmiş ikon (dosya gerekmez, her çözünürlükte keskin).
func icon_button(parent: Control, kind: String, x: float, y: float, cb: Callable) -> Button:
	var b := button(parent, "", x, y, 72, 72, cb, false, 18)
	b.draw.connect(draw_icon.bind(b, kind))
	return b


func draw_icon(b: Button, kind: String) -> void:
	var c := b.size * 0.5
	var col := Color(0.9, 0.97, 1.0)
	match kind:
		"pause":
			b.draw_rect(Rect2(c + Vector2(-11, -13), Vector2(8, 26)), col)
			b.draw_rect(Rect2(c + Vector2(3, -13), Vector2(8, 26)), col)
		"camera":
			b.draw_rect(Rect2(c + Vector2(-17, -8), Vector2(34, 22)), col, false, 3.0)
			b.draw_rect(Rect2(c + Vector2(-7, -13), Vector2(12, 5)), col)
			b.draw_arc(c + Vector2(0, 3), 7.0, 0.0, TAU, 24, col, 3.0, true)
		"handbrake": # (P) ve yanlarda yay: el freni ikonu
			col = Color(1.0, 0.45, 0.4) if main.handbrake else col
			b.draw_arc(c + Vector2(0, -8), 26.0, 0.0, TAU, 40, col, 4.0, true)
			b.draw_arc(c + Vector2(0, -8), 36.0, PI * 0.7, PI * 1.3, 16, col, 4.0, true)
			b.draw_arc(c + Vector2(0, -8), 36.0, -PI * 0.3, PI * 0.3, 16, col, 4.0, true)
			b.draw_string(ThemeDB.fallback_font, c + Vector2(-30, 2), "P", HORIZONTAL_ALIGNMENT_CENTER, 60, 30, col)
			b.draw_string(ThemeDB.fallback_font, c + Vector2(-58, 46), "EL FRENİ", HORIZONTAL_ALIGNMENT_CENTER, 116, 14, col)
		"radio":
			# iki sekizlik nota ve bağı
			for dx in [-9.0, 9.0]:
				b.draw_circle(c + Vector2(dx - 4.0, 10.0), 5.5, col)
				b.draw_line(c + Vector2(dx + 1.0, 10.0), c + Vector2(dx + 1.0, -12.0), col, 3.0)
			b.draw_line(c + Vector2(-8.0, -12.0), c + Vector2(10.0, -15.0), col, 5.0)


func set_chase_sign(sec: float) -> void:
	chase_s = sec


# Oyun başlarken: karşıdan trafik olsun mu?
func build_road() -> void:
	road_box = box()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	road_box.add_child(dim)
	label(road_box, 34, 380, "YOL NASIL OLSUN?").add_theme_font_override("font", title_font)
	primary(button(road_box, "ÇİFT YÖN\nkarşıdan trafik var", 0, 470, 440, 110, pick_road.bind("two"), false, 24))
	button(road_box, "TEK YÖN\ndört şerit de ileri", 0, 600, 440, 110, pick_road.bind("one"), false, 26)
	button(road_box, "GERİ", 0, 740, 240, 60, func(): road_box.visible = false, false, 22)


# Online yarış: kodunu kopyalayıp arkadaşına gönderirsin, onunkini yapıştırırsın; bağlanınca biri başlatır.
func build_online() -> void:
	online_box = box()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	online_box.add_child(dim)
	label(online_box, 34, 200, "ONLİNE YARIŞ").add_theme_font_override("font", title_font)
	on_status = label(online_box, 22, 270)
	label(online_box, 20, 380, "SENİN KODUN").add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	on_code = label(online_box, 16, 415)
	on_code.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	for l in [on_status, on_code]:
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.offset_left = 50.0
		l.offset_right = -50.0
	on_copy = button(online_box, "KOPYALA", -115, 540, 210, 80, copy_code, false, 24)
	button(online_box, "PAYLAŞ", 115, 540, 210, 80, share_code, false, 24)
	button(online_box, "ARKADAŞIMIN KODUNU YAPIŞTIR", 0, 640, 440, 80, paste_code, false, 20)
	on_start = primary(button(online_box, "YARIŞI BAŞLAT", 0, 760, 440, 100,
		func(): Net.start(Profile.road, main.region_at(main.travel)), false, 30))
	button(online_box, "KAPAT", 0, 900, 240, 60, close_online, false, 22)
	var note := label(online_box, 16, 985, "Kod IP adresini içerir: yalnız yarışacağın arkadaşınla paylaş.")
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	Net.changed.connect(refresh_online)
	Net.go.connect(on_go)


func open_online() -> void:
	online_box.visible = true
	Net.car = Profile.car
	Net.paint = Profile.paint
	Net.rim = Profile.rim
	if not Net.udp.is_bound():
		Net.open()
	refresh_online()


func close_online() -> void:
	online_box.visible = false
	Net.close()


func refresh_online() -> void:
	var st := Net.status
	if Net.paired:
		st += "\nARKADAŞIN: %s · %d ms" % [Profile.car_info(Net.remote.car).name, int(Net.ping_ms)]
	on_status.text = st
	on_code.text = Net.code if Net.code != "" else "…"
	on_start.disabled = not Net.paired
	on_start.modulate.a = 1.0 if Net.paired else 0.35


func copy_code() -> void:
	if Net.code == "":
		return
	DisplayServer.clipboard_set(Net.code)
	on_copy.text = "KOPYALANDI"
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(on_copy): on_copy.text = "KOPYALA")


# WhatsApp'ta kişi seçme ekranı açılır, mesaj hazır gelir (WhatsApp yoksa tarayıcıda wa.me açılır).
func share_code() -> void:
	if Net.code != "":
		OS.shell_open("https://wa.me/?text=" + ("Forever Speed online yarış kodum:\n" + Net.code).uri_encode())


func paste_code() -> void:
	Net.set_peer(DisplayServer.clipboard_get())


# İki tarafta da: arkadaşın ya da sen başlattın. Sahne her zaman yenilenir: iki cihaz aynı tohumla, aynı
# başlangıçtan kurulur (main._ready).
func on_go(road: String, _region: int) -> void:
	Profile.mode = "race"
	Profile.road = road
	Profile.save()
	Profile.autostart = true
	get_tree().paused = false
	get_tree().reload_current_scene()


func ask_road() -> void:
	road_box.visible = true


func pick_road(r: String) -> void:
	Profile.road = r
	Profile.save()
	road_box.visible = false
	main.start_run()


func near_popup(text: String, color: Color) -> void:
	if near_tween:
		near_tween.kill()
	near_label.text = text
	near_label.add_theme_color_override("font_color", color)
	near_label.reset_size()
	var at: Vector2 = main.cam.unproject_position(main.car.global_position + Vector3(0, 1.8, 0))
	near_label.position = at - Vector2(near_label.size.x * 0.5, top_inset + near_label.size.y)
	near_label.modulate.a = 1.0
	near_tween = create_tween().set_parallel()
	near_tween.tween_property(near_label, "position:y", near_label.position.y - 45.0, 0.7)
	near_tween.tween_property(near_label, "modulate:a", 0.0, 0.4).set_delay(0.3)


func flash() -> void:
	flash_rect.color.a = 0.85
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.35)


# Kararıp açılır (yol ayrımında başka bölgeye geçiş).
func fade() -> void:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_box.add_child(r)
	var t := create_tween()
	t.tween_property(r, "color:a", 1.0, 0.25)
	t.tween_property(r, "color:a", 0.0, 0.45)
	t.tween_callback(r.queue_free)


# Kokpit: tavan, A sütunları, torpido, direksiyon; yağmurda silecekler süpürür.
# Kokpit (1. şahıs): ince tavan ve A direkleri, dikiz aynası, alçak pano, direksiyonun arkasında hız ve vites,
# dönüşle dönen direksiyon, yağmurda silecekler. Yol görüşü ekranın üstünden panoya kadar açık.
func draw_cockpit() -> void:
	var w := cockpit.size.x
	var h := cockpit.size.y
	var dark := Color(0.025, 0.026, 0.032)
	var edge := Color(1, 1, 1, 0.07)
	cockpit.draw_rect(Rect2(0, 0, w, h * 0.028), dark) # tavan
	cockpit.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.075, 0), Vector2(w * 0.012, h * 0.62), Vector2(0, h * 0.62)]), dark)
	cockpit.draw_colored_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h * 0.62), Vector2(w * 0.988, h * 0.62), Vector2(w * 0.925, 0)]), dark)
	# dikiz aynası
	var mirror := Rect2(w * 0.33, h * 0.032, w * 0.34, h * 0.05)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.05, 0.06, 0.09)
	msb.set_corner_radius_all(14)
	msb.set_border_width_all(3)
	msb.border_color = dark
	cockpit.draw_style_box(msb, mirror)
	cockpit.draw_line(Vector2(w * 0.5, 0), Vector2(w * 0.5, h * 0.032), dark, 6.0)
	cockpit.draw_line(mirror.position + Vector2(14, mirror.size.y * 0.35), mirror.position + Vector2(mirror.size.x * 0.6, mirror.size.y * 0.25), Color(1, 1, 1, 0.08), 3.0) # cam parıltısı
	# pano: alçak, ortası hafif yüksek; üst kenarda ince parlama
	var top := PackedVector2Array()
	for i in 17:
		var x := w * i / 16.0
		top.append(Vector2(x, h * 0.795 + 22.0 * pow((x / w - 0.5) * 2.0, 2.0)))
	var dash := top.duplicate()
	dash.append(Vector2(w, h))
	dash.append(Vector2(0, h))
	cockpit.draw_colored_polygon(dash, dark)
	cockpit.draw_polyline(top, edge, 2.0, true)
	# gösterge ekranı: direksiyonun arkasında hız ve vites
	var scr := Rect2(w * 0.38, h * 0.815, w * 0.24, h * 0.06)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.02, 0.04, 0.07)
	ssb.set_corner_radius_all(10)
	ssb.border_color = Color(0.3, 0.7, 1.0, 0.35)
	ssb.set_border_width_all(1)
	cockpit.draw_style_box(ssb, scr)
	var font := ThemeDB.fallback_font
	cockpit.draw_string(font, scr.position + Vector2(0, scr.size.y * 0.72), "%d" % roundi(main.kmh), HORIZONTAL_ALIGNMENT_CENTER, scr.size.x * 0.7, 34, Color(0.85, 0.95, 1.0))
	cockpit.draw_string(font, scr.position + Vector2(scr.size.x * 0.66, scr.size.y * 0.72), "%d" % main.gear, HORIZONTAL_ALIGNMENT_CENTER, scr.size.x * 0.3, 30, ACCENT)
	var rpm_w := scr.size.x - 16.0
	cockpit.draw_rect(Rect2(scr.position + Vector2(8, scr.size.y - 7), Vector2(rpm_w, 3)), Color(1, 1, 1, 0.1))
	cockpit.draw_rect(Rect2(scr.position + Vector2(8, scr.size.y - 7), Vector2(rpm_w * main.rpm, 3)), Color(1.0, 0.3, 0.3) if main.rpm > 0.85 else Color(0.3, 0.75, 1.0))
	# direksiyon: dönüşle döner
	var steer := clampf((main.target_x - main.car.position.x) * 0.35, -0.7, 0.7)
	var c := Vector2(w * 0.5, h * 1.0)
	var r := w * 0.27
	cockpit.draw_set_transform(c, steer, Vector2.ONE)
	cockpit.draw_arc(Vector2.ZERO, r, PI * 1.05, PI * 1.95, 40, Color(0.07, 0.07, 0.08), 22.0, true)
	cockpit.draw_arc(Vector2.ZERO, r + 8.0, PI * 1.12, PI * 1.88, 40, Color(1, 1, 1, 0.06), 2.0, true)
	for ang in [PI * 1.08, PI * 1.92]: # yan kollar
		cockpit.draw_line(Vector2(cos(ang), sin(ang)) * (r - 6.0), Vector2(cos(ang), sin(ang)) * 46.0, Color(0.06, 0.06, 0.07), 16.0, true)
	cockpit.draw_circle(Vector2.ZERO, 50.0, Color(0.05, 0.05, 0.06))
	cockpit.draw_arc(Vector2(0, -r), 4.0, 0.0, TAU, 12, ACCENT, 4.0, true) # tepe işareti
	cockpit.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if main.rain_level > 0.15:
		var sw := sin(main.wipe_phase * PI) # 0 -> 1 -> 0: gidip gelir
		for pivot in [Vector2(w * 0.3, h * 0.8), Vector2(w * 0.72, h * 0.8)]:
			var a := lerpf(-PI * 0.97, -PI * 0.12, sw)
			var tip: Vector2 = pivot + Vector2(cos(a), sin(a)) * h * 0.42
			cockpit.draw_line(pivot, tip, Color(0.02, 0.02, 0.02), 7.0, true)
			cockpit.draw_line(pivot, tip, Color(0.3, 0.3, 0.33, 0.6), 2.0, true)


# --- Ana menü ---

func build_menu() -> void:
	menu_box = box()
	var start := Button.new() # ekranın boş bir yerine dokununca oyun başlar
	start.flat = true
	start.focus_mode = Control.FOCUS_NONE
	start.set_anchors_preset(Control.PRESET_FULL_RECT)
	start.pressed.connect(ask_road) # önce yol tipi sorulur
	menu_box.add_child(start)
	shade(menu_box, true)
	shade(menu_box, false)

	title_font = FontVariation.new()
	title_font.base_font = ThemeDB.fallback_font
	title_font.variation_embolden = 1.2
	title_font.variation_transform = Transform2D(Vector2(1.0, 0.2), Vector2(0.0, 1.0), Vector2.ZERO) # eğik yazı
	var t1 := label(menu_box, 70, 110, "FOREVER")
	var t2 := label(menu_box, 108, 178, "SPEED")
	for t in [t1, t2]:
		t.add_theme_font_override("font", title_font)
		t.add_theme_constant_override("shadow_outline_size", 22)
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 0)
	t1.add_theme_color_override("font_shadow_color", Color(0.2, 0.8, 1.0, 0.5))
	t2.add_theme_color_override("font_color", Color(1.0, 0.35, 0.8))
	t2.add_theme_color_override("font_shadow_color", Color(1.0, 0.2, 0.7, 0.7))
	t2.add_theme_color_override("font_outline_color", Color(0.25, 0.0, 0.2))
	speed_lines = Control.new()
	speed_lines.anchor_right = 1.0
	speed_lines.offset_top = 318.0
	speed_lines.offset_bottom = 342.0
	speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_lines.draw.connect(draw_speed_lines)
	menu_box.add_child(speed_lines)

	best_pill = pill(menu_box, -135, 362, 250, Color(0.3, 0.85, 1.0))
	coin_pill = pill(menu_box, 135, 362, 250, Color(1.0, 0.8, 0.3))

	var card := PanelContainer.new() # günlük görevler kartı
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.offset_left = -310.0
	card.offset_right = 310.0
	card.offset_top = 430.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.06, 0.72)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	menu_card = VBoxContainer.new()
	menu_card.add_theme_constant_override("separation", 10)
	menu_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(menu_card)
	menu_box.add_child(card)

	for i in Profile.MODES.size():
		mode_buttons.append(button(menu_box, Profile.MODE_NAMES[i], -240.0 + i * 160.0, -525, 152, 58, pick_mode.bind(i), true, 16))
	primary(button(menu_box, "GARAJ", 0, -430, 360, 84, open_garage, true, 30))
	if OS.has_feature("web"): # tarayıcıda UDP yok
		button(menu_box, "AYARLAR", 0, -325, 300, 62, open_settings, true, 24)
	else:
		button(menu_box, "AYARLAR", -160, -325, 300, 62, open_settings, true, 24)
		button(menu_box, "ONLİNE YARIŞ", 160, -325, 300, 62, open_online, true, 24)
	tap_label = label(menu_box, 34, -220, "DOKUN VE BAŞLA", true)
	tap_label.add_theme_font_override("font", title_font)


func pick_mode(i: int) -> void:
	Profile.mode = Profile.MODES[i]
	Profile.save()
	refresh_menu()


func show_menu() -> void:
	play_box.visible = false
	over_box.visible = false
	garage_box.visible = false
	menu_box.visible = true
	Profile.refresh_missions() # uygulama gece yarısını açık geçirdiyse yeni günün görevleri
	refresh_menu()


func refresh_menu() -> void:
	best_pill.text = "REKOR  %d" % Profile.best
	for i in mode_buttons.size():
		neon(mode_buttons[i], ACCENT if Profile.MODES[i] == Profile.mode else NEUTRAL)
	coin_pill.text = "%d COIN" % Profile.coins
	for c in menu_card.get_children():
		c.free() # queue_free bir kare eski satırları da bırakır, kart iki kat uzar
	var head := Label.new()
	head.text = "GÜNLÜK GÖREVLER"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	menu_card.add_child(head)
	for m in Profile.missions:
		menu_card.add_child(mission_row(m))


# Görev satırı: metin, ödül ve ilerleme çubuğu.
func mission_row(m: Dictionary) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE # kartın üstüne dokununca da oyun başlasın
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := Label.new()
	text.text = Profile.MISSIONS[m.type][0] % m.target
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 21)
	var reward := Label.new()
	reward.text = "+%d" % m.reward
	reward.add_theme_font_size_override("font_size", 21)
	reward.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	line.add_child(text)
	line.add_child(reward)
	row.add_child(line)
	var bar := ProgressBar.new()
	bar.max_value = m.target
	bar.value = minf(m.progress, m.target)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.12)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 1.0, 0.5) if m.done else Color(0.3, 0.85, 1.0)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return row


# Başlığın altında sola akan hız çizgileri.
func draw_speed_lines() -> void:
	var w := speed_lines.size.x
	for i in 7:
		var x := fposmod(i * 131.0 - main.alive * (300.0 + i * 45.0), w + 200.0) - 100.0
		var col := Color(0.3, 0.85, 1.0, 0.7) if i % 2 == 0 else Color(1.0, 0.35, 0.8, 0.7)
		speed_lines.draw_line(Vector2(x, 3.0 + i * 3.0), Vector2(x + 60.0 + fmod(i * 37.0, 90.0), 3.0 + i * 3.0), col, 2.0)


# Yazıların sahnenin üstünde okunması için üstte/altta koyu geçiş.
func shade(parent: Control, top: bool) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.8 if top else 0.0))
	g.set_color(1, Color(0, 0, 0, 0.0 if top else 0.85))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var r := TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_right = 1.0
	if top:
		r.anchor_bottom = 0.45
	else:
		r.anchor_top = 0.6
		r.anchor_bottom = 1.0
	parent.add_child(r)


func pill(parent: Control, x: float, y: float, w: float, accent: Color) -> Label:
	var l := Label.new()
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.offset_left = x - w * 0.5
	l.offset_right = x + w * 0.5
	l.offset_top = y
	l.offset_bottom = y + 46.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", accent.lightened(0.3))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(23)
	l.add_theme_stylebox_override("normal", sb)
	parent.add_child(l)
	return l


# Neon düğme: yarı saydam dolgu, parlak kenar, dışa taşan ışıma.
# Düğme görünümü: koyu, hafif saydam zemin ve ince açık kenar. Seçili/vurgulu olan accent kenar ve accent'in
# koyu tonunda zemin alır. Parlama ve kalın neon çerçeve yok; köşeler hafif yuvarlak.
const ACCENT := Color(1.0, 0.3, 0.6)
const NEUTRAL := Color(0.4, 0.85, 1.0) # button()'ın varsayılanı: vurgusuz
const GOLD := Color(1.0, 0.75, 0.3)


func neon(b: Button, accent: Color) -> Button:
	var plain := accent.is_equal_approx(NEUTRAL) or accent.is_equal_approx(Color(0.4, 0.5, 0.65))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var down: bool = state.contains("pressed")
		if state == "disabled":
			sb.bg_color = Color(0.06, 0.065, 0.08, 0.6)
			sb.border_color = Color(1, 1, 1, 0.06)
		elif plain:
			sb.bg_color = Color(0.07, 0.08, 0.11, 0.85).lightened(0.08 if down else (0.03 if state == "hover" else 0.0))
			sb.border_color = Color(1, 1, 1, 0.22 if state == "hover" else 0.14)
		else:
			sb.bg_color = Color(accent.r * 0.22, accent.g * 0.22, accent.b * 0.22, 0.92).lightened(0.08 if down else 0.0)
			sb.border_color = accent
		sb.set_border_width_all(1 if plain else 2)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(state, sb)
	var fc := Color(1, 1, 1, 0.92) if plain else accent.lightened(0.6)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	return b


# Ana eylem: düz dolgu, koyu yazı.
func primary(b: Button, accent := ACCENT) -> Button:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.2, 0.21, 0.25, 0.9) if state == "disabled" else (accent.darkened(0.15) if state.contains("pressed") else accent)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(state, sb)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color(0.04, 0.03, 0.06))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	return b


# --- Ayarlar ---

func build_settings() -> void:
	settings_box = box()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_box.add_child(dim)
	var t := label(settings_box, 54, 110, "AYARLAR")
	t.add_theme_font_override("font", title_font)
	option_row(240, "SES", ["AÇIK", "KAPALI"], func(): return 0 if Profile.sound else 1, set_sound)
	option_row(390, "TİTREŞİM", ["AÇIK", "KAPALI"], func(): return 0 if Profile.vibration else 1, set_vibration)
	option_row(540, "GRAFİK", ["DÜŞÜK", "ORTA", "YÜKSEK"], func(): return Profile.quality, set_quality)
	option_row(690, "FPS SINIRI", ["30", "60", "90", "120"], func(): return [30, 60, 90, 120].find(Profile.fps), set_fps)
	var note := label(settings_box, 20, 840, "Telefon ısınıyor ya da takılıyorsa grafiği düşür, FPS'i 30 yap.\nEkranın hızından yüksek FPS bir şey kazandırmaz.")
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	button(settings_box, "GERİ", 0, -200, 260, 70, close_settings, true, 26)


# Başlık ve yan yana seçenek düğmeleri; seçili olan pembe parlar.
func option_row(y: float, title: String, options: Array, getter: Callable, setter: Callable) -> void:
	label(settings_box, 26, y, title)
	var buttons := []
	var w := 560.0 / options.size()
	for i in options.size():
		var b := button(settings_box, options[i], -280.0 + w * (i + 0.5), y + 46.0, w - 14.0, 64, func(): pick_option(setter, i), false, 24)
		buttons.append(b)
	set_rows.append([buttons, getter])


func pick_option(setter: Callable, i: int) -> void:
	setter.call(i)
	Profile.save()
	refresh_settings()


func refresh_settings() -> void:
	for row in set_rows:
		var sel: int = row[1].call()
		for i in row[0].size():
			neon(row[0][i], ACCENT if i == sel else NEUTRAL)


func set_sound(i: int) -> void:
	Profile.sound = i == 0
	AudioServer.set_bus_mute(0, not Profile.sound)


func set_vibration(i: int) -> void:
	Profile.vibration = i == 0
	main.buzz(40, 0.6)


func set_quality(i: int) -> void:
	Profile.quality = i
	main.auto_checking = false # elle seçildi: otomatik düzeltme karışmasın
	main.apply_settings()


func set_fps(i: int) -> void:
	Profile.fps = [30, 60, 90, 120][i]
	main.auto_checking = false
	main.apply_settings()


func open_settings() -> void:
	settings_open = true
	menu_box.visible = false
	settings_box.visible = true
	refresh_settings()


func close_settings() -> void:
	settings_open = false
	settings_box.visible = false
	menu_box.visible = true
	refresh_menu()


# Oyun içi kısa görev listesi: ödülsüz, biten işaretli.
func hud_missions_text() -> String:
	var lines := PackedStringArray()
	for m in Profile.missions:
		var label: String = Profile.MISSIONS[m.type][0] % m.target
		var pr := minf(m.progress, m.target)
		var prog := ("%.1f" % pr) if String(m.type).ends_with("km") else str(int(pr))
		lines.append(("TAMAM · " + label) if m.done else "%s  %s/%d" % [label, prog, m.target])
	return "\n".join(lines)


func missions_text() -> String:
	return "\n".join(PackedStringArray(Profile.missions.map(func(m): return Profile.mission_text(m))))


# --- Garaj ---
# Üstte araç adı, fiyatı ve değerleri; ortada oda (araç döner, sürükleyince açı kayar); altta sekmeler:
# ARAÇ (al/sür), BOYA, JANT, MODİFİYE, MOTOR. Seçimler anında önizlenir, eylem düğmesi sekmeye göre değişir.
const G_TABS := ["ARAÇ", "BOYA", "JANT", "MODİFİYE", "MOTOR"]
var g_tab := 0
var g_tab_btns: Array[Button] = []
var g_pages: Array[Control] = []
var g_bars: Array[ProgressBar] = []
var g_info: Label
var rim_btns: Array[Button] = []
var mod_rows := {} # mod -> [ad etiketi, düğme]
var g_ind: Panel # bölümlü sekmenin kayan seçim kapsülü
var f_title: FontVariation # büyük başlık: sıkı harf aralığı
var f_caps: FontVariation # küçük büyük harf etiketler: açık harf aralığı


func build_garage() -> void:
	garage_box = box()
	# odanın içinde araç etrafında dönmek için sürükleme alanı (düğmelerin arkasında)
	var drag := Control.new()
	drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	# parmak araçla birlikte 1:1 döner; bırakınca son hızıyla döner ve yavaşlar (momentum)
	drag.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			main.garage_yaw -= e.relative.x * 0.008
			main.garage_spin = -e.velocity.x * 0.008
			main.garage_drag_t = 0.1
		elif e is InputEventMouseButton and not e.pressed:
			main.garage_drag_t = 0.0)
	garage_box.add_child(drag)
	f_title = FontVariation.new()
	f_title.base_font = ThemeDB.fallback_font
	f_title.variation_embolden = 0.9
	f_title.spacing_glyph = -1
	f_caps = FontVariation.new()
	f_caps.base_font = ThemeDB.fallback_font
	f_caps.variation_embolden = 0.4
	f_caps.spacing_glyph = 2
	button(garage_box, "‹  Geri", -258, 18, 150, 54, close_garage, false, 21)
	g_coins = label(garage_box, 22, 24)
	g_coins.anchor_left = 0.5
	g_coins.anchor_right = 0.5
	g_coins.offset_left = 130.0
	g_coins.offset_right = 340.0
	g_coins.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	g_coins.add_theme_stylebox_override("normal", capsule(Color(1.0, 0.8, 0.3, 0.12), Color(1.0, 0.8, 0.3, 0.35)))
	g_name = label(garage_box, 48, 84)
	g_name.add_theme_font_override("font", f_title)
	g_status = label(garage_box, 20, 150)
	g_status.add_theme_font_override("font", f_caps)
	g_status.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	g_status.anchor_left = 0.5
	g_status.anchor_right = 0.5
	g_status.add_theme_stylebox_override("normal", capsule(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.12)))
	button(garage_box, "‹", -305, 380, 64, 96, func(): pick_car(-1), false, 40)
	button(garage_box, "›", 305, 380, 64, 96, func(): pick_car(1), false, 40)
	# alt panel
	var panel := Panel.new()
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -570.0
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.06, 0.07, 0.1, 1.0)
	psb.corner_radius_top_left = 28
	psb.corner_radius_top_right = 28
	psb.border_width_top = 1
	psb.border_color = Color(1, 1, 1, 0.16) # üst kenarda ışık yakalayan ince çizgi
	panel.add_theme_stylebox_override("panel", psb)
	var frost := ShaderMaterial.new()
	frost.shader = preload("res://frost.gdshader")
	panel.material = frost # buzlu cam: arkadaki oda bulanık görünür
	garage_box.add_child(panel)
	# bölümlü sekme: koyu kapsül, içinde kayan açık seçim kapsülü, yazı düğmeleri
	var seg := Panel.new()
	seg.anchor_left = 0.5
	seg.anchor_right = 0.5
	seg.anchor_top = 1.0
	seg.anchor_bottom = 1.0
	seg.offset_left = -332.0
	seg.offset_right = 332.0
	seg.offset_top = -96.0
	seg.offset_bottom = -32.0
	seg.add_theme_stylebox_override("panel", capsule(Color(0, 0, 0, 0.45), Color(1, 1, 1, 0.08)))
	seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	garage_box.add_child(seg)
	g_ind = Panel.new()
	g_ind.anchor_left = 0.5
	g_ind.anchor_right = 0.5
	g_ind.anchor_top = 1.0
	g_ind.anchor_bottom = 1.0
	g_ind.offset_left = -326.0
	g_ind.offset_right = -202.0
	g_ind.offset_top = -92.0
	g_ind.offset_bottom = -36.0
	g_ind.add_theme_stylebox_override("panel", capsule(Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.22)))
	g_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	garage_box.add_child(g_ind)
	for i in G_TABS.size():
		var tb := button(garage_box, G_TABS[i], -264.0 + i * 132.0, -94, 128, 60, pick_tab.bind(i), true, 18)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			tb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		tb.add_theme_font_override("font", f_caps)
		g_tab_btns.append(tb)
	for i in G_TABS.size():
		var pg := Control.new()
		pg.set_anchors_preset(Control.PRESET_FULL_RECT)
		pg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		garage_box.add_child(pg)
		g_pages.append(pg)
	# ARAÇ: hız ve ivme çubukları, bilgiler
	for k in 2:
		var y := -530.0 + k * 58.0
		var l := label(g_pages[0], 22, y - 4.0, ["HIZ", "İVME"][k], true)
		l.anchor_left = 0.5
		l.anchor_right = 0.5
		l.offset_left = -290.0
		l.offset_right = -160.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		g_bars.append(make_bar(g_pages[0], y + 6.0))
	g_info = label(g_pages[0], 20, -404, "", true)
	g_info.add_theme_font_override("font", f_caps)
	g_info.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	# BOYA: düz, modifiye, desen (üç sıra)
	g_paint_label = label(g_pages[1], 19, -556, "", true)
	g_paint_label.add_theme_font_override("font", f_caps)
	for i in Profile.PAINTS.size():
		swatches.append(button(g_pages[1], "", (i % 9 - 4) * 66.0, -510.0 + (i / 9) * 62.0, 54, 54, pick_paint.bind(i), true))
	# JANT: 3x3
	for i in Profile.RIMS.size():
		var rb := button(g_pages[2], "", -210.0 + (i % 3) * 210.0, -530.0 + (i / 3) * 64.0, 200, 58, pick_rim.bind(i), true, 18)
		rb.draw.connect(draw_chip.bind(rb, Profile.RIMS[i][2] if i > 0 else Color(0.55, 0.57, 0.6))) # jantın rengi
		rim_btns.append(rb)
	# MODİFİYE: satır başına ad ve seçenek düğmesi
	var mi := 0
	for k in Profile.MODS:
		var y := -530.0 + mi * 66.0
		var l := label(g_pages[3], 22, y + 12.0, Profile.MODS[k][0], true)
		l.anchor_left = 0.5
		l.anchor_right = 0.5
		l.offset_left = -290.0
		l.offset_right = -20.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var mb := button(g_pages[3], "", 140, y, 280, 58, use_mod.bind(k), true, 19)
		if k == "glow": # seçili neon rengi
			mb.draw.connect(func():
				var g := Profile.mod(Profile.CARS[g_car].id, "glow")
				if g > 0:
					draw_chip(mb, Profile.GLOW_COLORS[g]))
		mod_rows[k] = [l, mb]
		mi += 1
	# MOTOR: geliştirmeler
	for k in Profile.UPGRADES:
		var y := -530.0 + up_rows.size() * 66.0
		var l := label(g_pages[4], 22, y + 12.0, Profile.UPGRADES[k][0], true)
		l.anchor_left = 0.5
		l.anchor_right = 0.5
		l.offset_left = -290.0
		l.offset_right = -170.0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		up_rows[k] = [l, make_bar(g_pages[4], y + 20.0, Profile.MAX_LEVEL), button(g_pages[4], "", 200, y, 160, 58, buy_up.bind(k), true, 20)]
	g_action = primary(button(garage_box, "", 0, -186, 440, 76, garage_action, true, 26))


# İnce ilerleme çubuğu (garaj değerleri, geliştirme seviyesi). y alttan ölçülür.
func make_bar(parent: Control, y: float, max_v := 1.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_v
	bar.step = 0.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -150.0
	bar.offset_right = 100.0
	bar.offset_top = y
	bar.offset_bottom = y + 12.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.1)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func open_garage() -> void:
	garage_open = true
	menu_box.visible = false
	garage_box.visible = true
	g_car = 0
	for i in Profile.CARS.size():
		if Profile.CARS[i].id == Profile.car:
			g_car = i
	g_paint = Profile.paint
	g_rim_i = Profile.rim
	refresh_garage()


func close_garage() -> void:
	garage_open = false
	garage_box.visible = false
	menu_box.visible = true
	main.set_player_car(Profile.car, Profile.paint) # seçilmeyen önizlemeyi geri al
	refresh_menu()


# Sekme değişince yeni sayfa sekmenin bulunduğu yönden kayarak ve belirerek gelir (aynı yoldan gider).
func pick_tab(i: int) -> void:
	if i == g_tab:
		return
	var dir := signf(i - g_tab)
	g_tab = i
	refresh_garage()
	var pg := g_pages[i]
	pg.position.x = dir * 36.0
	pg.modulate.a = 0.0
	var t := pg.create_tween().set_parallel()
	t.tween_property(pg, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(pg, "modulate:a", 1.0, 0.18)
	main.buzz(10, 0.25)


# Yuvarlak renk çipi: düğmenin solunda (jant rengi, neon rengi).
func draw_chip(b: Button, col: Color) -> void:
	var c := Vector2(24.0, b.size.y * 0.5)
	b.draw_circle(c, 11.0, col)
	b.draw_arc(c, 11.0, 0.0, TAU, 24, Color(1, 1, 1, 0.35), 1.5, true)


# Kapsül zemin: etiketler ve sekme kutusu için.
func capsule(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(30)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb


func preview() -> void:
	main.set_player_car(Profile.CARS[g_car].id, g_paint, g_rim_i)


func pick_car(d: int) -> void:
	g_car = wrapi(g_car + d, 0, Profile.CARS.size())
	preview()
	refresh_garage()


func pick_paint(i: int) -> void:
	g_paint = i
	preview()
	refresh_garage()


func pick_rim(i: int) -> void:
	g_rim_i = i
	preview()
	refresh_garage()


# Eylem sekmeye göre: araç al/sür, boya al/uygula, jant al/tak.
func garage_action() -> void:
	var c: Dictionary = Profile.CARS[g_car]
	var ok := true
	match g_tab:
		0:
			ok = Profile.buy_car(c.id) if not (c.id in Profile.cars) else true
			if c.id in Profile.cars:
				Profile.select(c.id, Profile.paint)
				g_paint = Profile.paint
		1:
			if not (g_paint in Profile.paints):
				ok = Profile.buy_paint(g_paint)
			elif c.id in Profile.cars:
				Profile.select(c.id, g_paint)
		2:
			ok = Profile.use_rim(g_rim_i)
	if ok:
		main.buzz(30, 0.5)
		main.play("confirm")
	preview()
	refresh_garage()


func use_mod(k: String) -> void:
	if Profile.use_mod(Profile.CARS[g_car].id, k):
		preview()
		main.buzz(30, 0.5)
		main.play("click")
	refresh_garage()


func buy_up(k: String) -> void:
	if Profile.buy_upgrade(Profile.CARS[g_car].id, k):
		main.buzz(30, 0.5)
		main.play("confirm")
	refresh_garage()


func refresh_garage() -> void:
	var c: Dictionary = Profile.CARS[g_car]
	var car_owned: bool = c.id in Profile.cars
	var driving: bool = Profile.car == c.id
	g_coins.text = "%d COIN" % Profile.coins
	g_name.text = c.name
	g_status.text = ("SÜRDÜĞÜN ARAÇ" if driving else "SENİN") if car_owned else "%d COIN" % c.price
	for i in g_tab_btns.size():
		g_tab_btns[i].add_theme_color_override("font_color", Color(1, 1, 1) if i == g_tab else Color(1, 1, 1, 0.5))
		g_tab_btns[i].add_theme_color_override("font_hover_color", Color(1, 1, 1))
		g_pages[i].visible = i == g_tab
	g_status.offset_left = -g_status.get_minimum_size().x * 0.5
	g_status.offset_right = g_status.get_minimum_size().x * 0.5
	# ARAÇ
	var num: Vector2 = main.car_numbers(c.id)
	g_bars[0].value = clampf((num.x - 200.0) / 110.0, 0.05, 1.0)
	g_bars[1].value = clampf((16.0 - num.y) / 9.0, 0.05, 1.0)
	g_info.text = "MAKS %d KM/SA   ·   0-200 KM/SA %.1f SN" % [int(num.x), num.y]
	# BOYA
	var p: Array = Profile.PAINTS[g_paint]
	var paint_owned: bool = g_paint in Profile.paints
	g_paint_label.text = "%s%s" % [p[0], "" if paint_owned else "  ·  %d COIN" % p[2]]
	for i in swatches.size():
		var col: Color = Profile.PAINTS[i][1] if i > 0 else Color(0.25, 0.25, 0.3)
		style(swatches[i], Color(1, 1, 1) if i == g_paint else Color(1, 1, 1, 0.14), col, 14)
		swatches[i].pivot_offset = swatches[i].size * 0.5
		swatches[i].create_tween().tween_property(swatches[i], "scale", Vector2.ONE * (1.1 if i == g_paint else 1.0), 0.18) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# JANT
	for i in rim_btns.size():
		var r: Array = Profile.RIMS[i]
		rim_btns[i].text = "      " + r[0] + ("" if i in Profile.rims else "\n      %d COIN" % r[4])
		neon(rim_btns[i], ACCENT if i == g_rim_i else (GOLD if i == Profile.rim else NEUTRAL))
	# MODİFİYE: yalnız sahip olunan araçta
	for k in mod_rows:
		var st := Profile.mod(c.id, k)
		var b: Button = mod_rows[k][1]
		b.text = "AL  ·  %d" % Profile.MODS[k][1] if st < 0 else "%s  ›" % Profile.MODS[k][2][st]
		b.queue_redraw()
		b.disabled = not car_owned or (st < 0 and Profile.coins < Profile.MODS[k][1])
		neon(b, ACCENT if st > 0 else NEUTRAL)
	# MOTOR
	for k in up_rows:
		var lv := Profile.level(c.id, k)
		var price := Profile.upgrade_price(c.id, k)
		var row: Array = up_rows[k]
		(row[1] as ProgressBar).value = lv
		var b: Button = row[2]
		b.text = "MAKS" if lv >= Profile.MAX_LEVEL else "+  %d" % price
		b.disabled = not car_owned or lv >= Profile.MAX_LEVEL or Profile.coins < price
	# eylem
	g_action.visible = g_tab <= 2
	match g_tab:
		0:
			g_action.text = "ARACI AL  ·  %d" % c.price if not car_owned else ("SÜRÜYORSUN" if driving else "BU ARACI SÜR")
			g_action.disabled = (not car_owned and Profile.coins < c.price) or (car_owned and driving)
		1:
			if not paint_owned:
				g_action.text = "BOYAYI AL  ·  %d" % p[2]
				g_action.disabled = Profile.coins < p[2]
			else:
				g_action.text = "UYGULANDI" if driving and Profile.paint == g_paint else "BOYAYI UYGULA"
				g_action.disabled = not car_owned or (driving and Profile.paint == g_paint)
		2:
			var r: Array = Profile.RIMS[g_rim_i]
			var rim_owned: bool = g_rim_i in Profile.rims
			g_action.text = "TAKILI" if Profile.rim == g_rim_i else ("JANTI TAK" if rim_owned else "JANTI AL  ·  %d" % r[4])
			g_action.disabled = Profile.rim == g_rim_i or (not rim_owned and Profile.coins < r[4])


# --- Kaza ekranı ---

func build_over() -> void:
	over_box = box()
	over_title = label(over_box, 64, 230, "KAZA")
	over_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	over_score = label(over_box, 52, 320)
	over_detail = label(over_box, 26, 400)
	label(over_box, 24, 540, "GÜNLÜK GÖREVLER").add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	over_missions = label(over_box, 22, 580)
	button(over_box, "TEKRAR", 0, -330, 320, 84, func(): main.restart(), true, 34)
	button(over_box, "MENÜ", 0, -225, 240, 64, func(): main.to_menu(), true, 26)


func show_over(score: int, km: float, earned: int, new_best: bool, reason := "KAZA") -> void:
	play_box.visible = false
	over_box.visible = true
	over_title.text = reason
	over_score.text = str(score)
	var best_line := "YENİ REKOR!" if new_best else "REKOR %d" % Profile.best
	over_detail.text = "%.2f km   ·   +%d COIN\n%s" % [km, earned, best_line]
	over_missions.text = missions_text()


# --- Nitro öğreticisi ---

func build_tip() -> void:
	tip_box = box()
	var dim := ColorRect.new() # dokunuşlar alttaki oyuna geçer (çift dokunuş algılansın)
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_box.add_child(dim)
	label(tip_box, 54, 420, "NİTRO HAZIR!").add_theme_color_override("font_color", Color(0.8, 0.55, 1.0))
	label(tip_box, 30, 500, "Ekrana iki kez hızlıca dokun")
	tip_taps = Control.new()
	tip_taps.anchor_left = 0.5
	tip_taps.anchor_right = 0.5
	tip_taps.offset_left = -80.0
	tip_taps.offset_right = 80.0
	tip_taps.offset_top = 570.0
	tip_taps.offset_bottom = 730.0
	tip_taps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_taps.draw.connect(draw_taps)
	tip_box.add_child(tip_taps)


# İki hızlı dokunuşu canlandırır; gerçek zamanla döner, ağır çekimden etkilenmez.
func draw_taps() -> void:
	var c := tip_taps.size * 0.5
	var t := fmod(Time.get_ticks_msec() / 1000.0, 1.2)
	tip_taps.draw_circle(c, 34.0, Color(1, 1, 1, 0.25))
	for start in [0.0, 0.3]:
		var k: float = (t - start) / 0.3
		if k >= 0.0 and k <= 1.0:
			tip_taps.draw_circle(c, 30.0, Color(1, 1, 1, 0.8 * (1.0 - k)))
			tip_taps.draw_arc(c, 34.0 + k * 40.0, 0.0, TAU, 48, Color(0.8, 0.55, 1.0, 1.0 - k), 4.0, true)


func show_tip(on: bool) -> void:
	tip_box.visible = on


# Açılış ısınması: siyah perde arkasında yazılar ve öğretici de bir kez çizilir.
func warm(on: bool) -> void:
	if on:
		curtain = ColorRect.new()
		curtain.color = Color(0, 0, 0)
		curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(curtain)
		play_box.visible = true
		tip_box.visible = true
		popup_label.text = "YAKIN GEÇİŞ +0123456789 YOL VERDİN"
		toast_label.text = "GÖREV TAMAM COIN ORMAN YOLU ŞEHİR KÖPRÜ SAHİL"
		popup_label.modulate.a = 1.0
		toast_label.modulate.a = 1.0
		return
	play_box.visible = main.state == "play"
	tip_box.visible = false
	popup_label.modulate.a = 0.0
	toast_label.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(curtain, "modulate:a", 0.0, 0.35)
	t.tween_callback(curtain.queue_free)


# --- Yardımcılar ---

# Ekranın üstündeki çentik/kamera deliği payı (arayüz biriminde): üstteki yazılar onun altına iner.
func safe_top() -> float:
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return 0.0
	var safe := DisplayServer.get_display_safe_area()
	var ratio := get_viewport().get_visible_rect().size.y / float(win.y)
	return maxf(float(safe.position.y - DisplayServer.window_get_position().y), 0.0) * ratio


func box() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_top = top_inset # alta bağlı öğeler yerinde kalır, üsttekiler çentiğin altına iner
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	add_child(c)
	return c


func label(parent: Control, size: int, y: float, text := "", bottom := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	parent.add_child(l)
	return l


# x: ekran ortasına göre; bottom ise y alttan (negatif) ölçülür.
func button(parent: Control, text: String, x: float, y: float, w: float, h: float, cb: Callable, bottom := false, size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.anchor_left = 0.5
	b.anchor_right = 0.5
	if bottom:
		b.anchor_top = 1.0
		b.anchor_bottom = 1.0
	b.offset_left = x - w * 0.5
	b.offset_right = x + w * 0.5
	b.offset_top = y
	b.offset_bottom = y + h
	neon(b, NEUTRAL)
	b.add_theme_font_size_override("font_size", size)
	b.pivot_offset = Vector2(w, h) * 0.5
	b.button_down.connect(press_anim.bind(b, 0.95)) # geri bildirim basar basmaz, bırakmayı beklemez
	b.button_up.connect(press_anim.bind(b, 1.0))
	b.pressed.connect(func(): main.play("click"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# Basınca hızla küçülür, bırakınca yumuşak yaylanarak döner; o anki ölçekten başlar (yarıda kesilebilir).
func press_anim(b: Button, to: float) -> void:
	if b.has_meta("press"):
		(b.get_meta("press") as Tween).kill()
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2.ONE * to, 0.07 if to < 1.0 else 0.22) \
		.set_trans(Tween.TRANS_QUAD if to < 1.0 else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.set_meta("press", t)


func style(b: Button, border: Color, fill := Color(0, 0, 0, 0.35), radius := 14) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill.lightened(0.25) if state.contains("pressed") else fill
		sb.border_color = border if state != "disabled" else Color(1, 1, 1, 0.25)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(radius)
		b.add_theme_stylebox_override(state, sb)
