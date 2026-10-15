# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends CanvasLayer

# Oyun içi gösterge, ana menü, garaj ve kaza ekranı; hepsi koddan kurulur.
# Yerleşim 720 px genişlik tabanlı: üst öğeler üste, alt öğeler alta sabitlenir.

var main # main.gd; tipsiz, çünkü onun alanlarına doğrudan erişiyoruz
var garage_open := false
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
var warn_label: Label

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


func _ready() -> void:
	layer = 2
	main = get_parent()
	build_play()
	build_menu()
	build_garage()
	build_over()
	build_tip()
	build_settings()


# Açık bir panel varken (garaj, ayarlar) dokunuş ve Enter oyunu başlatmaz.
func panel_open() -> bool:
	return garage_open or settings_open


# --- Oyun içi ---

func build_play() -> void:
	play_box = box()
	fps_label = label(play_box, 18, 28)
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
	popup_label = label(play_box, 40, 500)
	popup_label.modulate.a = 0.0
	toast_label = label(play_box, 34, 600)
	toast_label.modulate.a = 0.0
	warn_label = label(play_box, 26, 392) # yol çalışması uyarısı
	warn_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = Color(0.1, 0.06, 0.0, 0.7)
	wsb.border_color = Color(1.0, 0.7, 0.1)
	wsb.set_border_width_all(2)
	wsb.set_corner_radius_all(16)
	wsb.set_content_margin_all(10)
	warn_label.add_theme_stylebox_override("normal", wsb)
	warn_label.anchor_left = 0.5
	warn_label.anchor_right = 0.5
	warn_label.offset_left = -230.0
	warn_label.offset_right = 230.0
	warn_label.visible = false
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
	nitro_bar.queue_redraw()
	# metni yalnız değişince ata: her atama yazıyı yeniden şekillendirir
	set_text(fps_label, "%d FPS" % Engine.get_frames_per_second())
	set_text(score_label, str(int(main.score)))
	set_text(km_label, "%.2f km" % (main.distance / 1000.0))
	set_text(combo_label, main.hud_tags())
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
func set_warning(text: String, flash := false) -> void:
	warn_label.visible = text != ""
	set_text(warn_label, text)
	warn_label.modulate.a = (0.55 + 0.45 * sin(main.alive * 9.0)) if flash else 1.0


func draw_nitro() -> void:
	var w := nitro_bar.size.x
	var h := nitro_bar.size.y
	var f: float = main.nitro_level()
	var active: bool = main.nitro_t > 0.0
	var is_ready: bool = main.nitro >= 1.0 and not active
	var col := Color(0.35, 0.5, 1.0).lerp(Color(0.8, 0.4, 1.0), f)
	if is_ready:
		col = col.lightened(0.3 + 0.3 * sin(main.alive * 8.0))
	nitro_bar.draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.45))
	nitro_bar.draw_rect(Rect2(0, 0, w * f, h), col)
	nitro_bar.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.6), false, 2.0)
	var text := "NİTRO!" if active else ("NİTRO HAZIR · ÇİFT DOKUN" if is_ready else "NİTRO")
	nitro_bar.draw_string(ThemeDB.fallback_font, Vector2(0, h + 20), text, HORIZONTAL_ALIGNMENT_CENTER, w, 16)


func popup(text: String, color := Color(1, 1, 1)) -> void:
	if popup_tween:
		popup_tween.kill()
	popup_label.text = text
	popup_label.add_theme_color_override("font_color", color)
	popup_label.offset_top = 500.0
	popup_label.modulate.a = 1.0
	popup_tween = create_tween().set_parallel()
	popup_tween.tween_property(popup_label, "offset_top", 440.0, 0.8)
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


# --- Ana menü ---

func build_menu() -> void:
	menu_box = box()
	var start := Button.new() # ekranın boş bir yerine dokununca oyun başlar
	start.flat = true
	start.focus_mode = Control.FOCUS_NONE
	start.set_anchors_preset(Control.PRESET_FULL_RECT)
	start.pressed.connect(func(): main.start_run())
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

	neon(button(menu_box, "GARAJ", 0, -430, 360, 84, open_garage, true, 34), Color(1.0, 0.3, 0.8))
	button(menu_box, "AYARLAR", 0, -325, 300, 62, open_settings, true, 24)
	tap_label = label(menu_box, 34, -220, "DOKUN VE BAŞLA", true)
	tap_label.add_theme_font_override("font", title_font)


func show_menu() -> void:
	play_box.visible = false
	over_box.visible = false
	garage_box.visible = false
	menu_box.visible = true
	Profile.refresh_missions() # uygulama gece yarısını açık geçirdiyse yeni günün görevleri
	refresh_menu()


func refresh_menu() -> void:
	best_pill.text = "REKOR  %d" % Profile.best
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
func neon(b: Button, accent: Color) -> Button:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		var a := 0.35 if state.contains("pressed") else 0.16
		sb.bg_color = Color(accent.r, accent.g, accent.b, a if state != "disabled" else 0.05)
		sb.border_color = accent if state != "disabled" else Color(1, 1, 1, 0.25)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(42)
		sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.45 if state != "disabled" else 0.0)
		sb.shadow_size = 12
		b.add_theme_stylebox_override(state, sb)
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
	neon(button(settings_box, "GERİ", 0, -200, 260, 70, close_settings, true, 28), Color(1.0, 0.3, 0.8))


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
			neon(row[0][i], Color(1.0, 0.3, 0.8) if i == sel else Color(0.4, 0.5, 0.65))


func set_sound(i: int) -> void:
	Profile.sound = i == 0
	AudioServer.set_bus_mute(0, not Profile.sound)


func set_vibration(i: int) -> void:
	Profile.vibration = i == 0
	main.buzz(40, 0.6)


func set_quality(i: int) -> void:
	Profile.quality = i
	main.apply_settings()


func set_fps(i: int) -> void:
	Profile.fps = [30, 60, 90, 120][i]
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


func missions_text() -> String:
	return "\n".join(PackedStringArray(Profile.missions.map(func(m): return Profile.mission_text(m))))


# --- Garaj ---

func build_garage() -> void:
	garage_box = box()
	label(garage_box, 40, 60, "GARAJ")
	g_coins = label(garage_box, 26, 116)
	g_name = label(garage_box, 48, 190)
	g_status = label(garage_box, 26, 256)
	button(garage_box, "<", -300, 560, 90, 110, func(): pick_car(-1), false, 48)
	button(garage_box, ">", 300, 560, 90, 110, func(): pick_car(1), false, 48)
	g_paint_label = label(garage_box, 24, -380, "", true)
	for i in Profile.PAINTS.size():
		swatches.append(button(garage_box, "", (i - 4) * 70.0, -335, 56, 56, pick_paint.bind(i), true))
	g_action = button(garage_box, "", 0, -245, 400, 80, garage_action, true, 30)
	button(garage_box, "GERİ", 0, -145, 240, 64, close_garage, true, 26)


func open_garage() -> void:
	garage_open = true
	menu_box.visible = false
	garage_box.visible = true
	g_car = 0
	for i in Profile.CARS.size():
		if Profile.CARS[i].id == Profile.car:
			g_car = i
	g_paint = Profile.paint
	refresh_garage()


func close_garage() -> void:
	garage_open = false
	garage_box.visible = false
	menu_box.visible = true
	main.set_player_car(Profile.car, Profile.paint) # seçilmeyen önizlemeyi geri al
	refresh_menu()


func pick_car(d: int) -> void:
	g_car = wrapi(g_car + d, 0, Profile.CARS.size())
	main.set_player_car(Profile.CARS[g_car].id, g_paint)
	refresh_garage()


func pick_paint(i: int) -> void:
	g_paint = i
	main.set_player_car(Profile.CARS[g_car].id, g_paint)
	refresh_garage()


func garage_action() -> void:
	var c: Dictionary = Profile.CARS[g_car]
	if not (c.id in Profile.cars):
		Profile.buy_car(c.id)
	elif not (g_paint in Profile.paints):
		Profile.buy_paint(g_paint)
	else:
		Profile.select(c.id, g_paint)
	main.buzz(30, 0.5)
	refresh_garage()


func refresh_garage() -> void:
	var c: Dictionary = Profile.CARS[g_car]
	var p: Array = Profile.PAINTS[g_paint]
	var car_owned: bool = c.id in Profile.cars
	var paint_owned: bool = g_paint in Profile.paints
	g_coins.text = "%d COIN" % Profile.coins
	g_name.text = c.name
	g_status.text = "SENİN" if car_owned else "%d COIN" % c.price
	g_paint_label.text = "BOYA: %s%s" % [p[0], "" if paint_owned else "  ·  %d COIN" % p[2]]
	for i in swatches.size():
		var col: Color = Profile.PAINTS[i][1] if i > 0 else Color(0.25, 0.25, 0.3)
		style(swatches[i], Color(1, 1, 1) if i == g_paint else Color(1, 1, 1, 0.3), col, 28)
	if not car_owned:
		g_action.text = "ARACI AL · %d" % c.price
		g_action.disabled = Profile.coins < c.price
	elif not paint_owned:
		g_action.text = "BOYAYI AL · %d" % p[2]
		g_action.disabled = Profile.coins < p[2]
	elif Profile.car == c.id and Profile.paint == g_paint:
		g_action.text = "SEÇİLİ"
		g_action.disabled = true
	else:
		g_action.text = "SEÇ"
		g_action.disabled = false


# --- Kaza ekranı ---

func build_over() -> void:
	over_box = box()
	label(over_box, 64, 230, "KAZA").add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	over_score = label(over_box, 52, 320)
	over_detail = label(over_box, 26, 400)
	label(over_box, 24, 540, "GÜNLÜK GÖREVLER").add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	over_missions = label(over_box, 22, 580)
	button(over_box, "TEKRAR", 0, -330, 320, 84, func(): main.restart(), true, 34)
	button(over_box, "MENÜ", 0, -225, 240, 64, func(): main.to_menu(), true, 26)


func show_over(score: int, km: float, earned: int, new_best: bool) -> void:
	play_box.visible = false
	over_box.visible = true
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

func box() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	neon(b, Color(0.4, 0.85, 1.0))
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func(): main.play("click"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func style(b: Button, border: Color, fill := Color(0, 0, 0, 0.35), radius := 14) -> void:
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill.lightened(0.25) if state.contains("pressed") else fill
		sb.border_color = border if state != "disabled" else Color(1, 1, 1, 0.25)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(radius)
		b.add_theme_stylebox_override(state, sb)
