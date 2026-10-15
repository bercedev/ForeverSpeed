# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node

# Kalıcı oyuncu verisi (autoload "Profile"): coin, rekor, garaj, ayarlar, günlük görevler.

const PATH := "user://save.cfg"
# İsimlerde marka yok: mağazada sorun çıkarmasın.
const CARS := [
	{"id": "r34", "name": "MIDNIGHT GT", "price": 0},
	{"id": "sedan-sports", "name": "STREET SEDAN", "price": 1500},
	{"id": "hatchback-sports", "name": "HOT HATCH", "price": 2500},
	{"id": "race", "name": "RACER", "price": 5000},
	{"id": "race-future", "name": "FUTURE", "price": 9000},
]
# [ad, renk, fiyat]; 0 = modelin kendi rengi
const PAINTS := [
	["ORİJİNAL", Color(1, 1, 1), 0],
	["GECE MAVİSİ", Color(0.08, 0.15, 0.75), 300],
	["SİYAH", Color(0.06, 0.06, 0.07), 300],
	["BEYAZ", Color(0.85, 0.86, 0.9), 300],
	["KIRMIZI", Color(0.75, 0.05, 0.05), 400],
	["MOR", Color(0.45, 0.1, 0.75), 400],
	["YEŞİL", Color(0.1, 0.6, 0.25), 400],
	["TURUNCU", Color(0.95, 0.45, 0.05), 500],
	["GÜMÜŞ", Color(0.55, 0.57, 0.6), 500],
]
# tür: [metin, hedefler, ödül coin]
const MISSIONS := {
	"near": ["%d yakın geçiş yap", [15, 25, 40], 150],
	"near_tunnel": ["Tünelde %d yakın geçiş", [3, 5, 8], 200],
	"fast_km": ["280+ km/sa ile %d km git", [1, 2, 3], 200],
	"run_km": ["Tek oyunda %d km git", [3, 5, 8], 250],
	"nitro": ["%d kez nitro kullan", [2, 4, 6], 150],
	"combo": ["x%d kombo yap", [4, 6, 8], 200],
	"siren": ["Sirenli araca %d kez yol ver", [1, 2, 3], 150],
	"bridge_km": ["Köprüde %d km git", [1, 2], 200],
}
const MAX_TYPES := ["run_km", "combo"] # bunlarda ilerleme toplanmaz, en iyi değer tutulur

var coins := 0
var best := 0
var cars: Array = ["r34"]
var paints: Array = [0]
var car := "r34"
var paint := 0
var vibration := true
var sound := true
var quality := 1 # 0 düşük, 1 orta, 2 yüksek
var fps := 60 # kare hızı sınırı: zayıf telefonda 30, iyisinde 90-120
var nitro_tip := false # nitro öğreticisi bir kez gösterilir
var autostart := false # kaydedilmez: "TEKRAR" sahneyi yenileyince menüyü atlar
var clock := 0.0 # kaydedilmez: gece-gündüz saati, sahne yenilense de akar; açılış hep gece
var day := ""
var missions: Array = []


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		coins = cfg.get_value("p", "coins", 0)
		best = cfg.get_value("p", "best", 0)
		cars = cfg.get_value("p", "cars", ["r34"])
		paints = cfg.get_value("p", "paints", [0])
		car = cfg.get_value("p", "car", "r34")
		paint = cfg.get_value("p", "paint", 0)
		vibration = cfg.get_value("p", "vibration", true)
		sound = cfg.get_value("p", "sound", true)
		quality = cfg.get_value("p", "quality", 1)
		fps = cfg.get_value("p", "fps", 60)
		nitro_tip = cfg.get_value("p", "nitro_tip", false)
		day = cfg.get_value("m", "day", "")
		missions = cfg.get_value("m", "list", [])
	refresh_missions()


func save() -> void:
	var cfg := ConfigFile.new()
	for k in ["coins", "best", "cars", "paints", "car", "paint", "vibration", "sound", "quality", "fps", "nitro_tip"]:
		cfg.set_value("p", k, get(k))
	cfg.set_value("m", "day", day)
	cfg.set_value("m", "list", missions)
	cfg.save(PATH)


# Her gün aynı tarihten türetilen 3 farklı görev.
func refresh_missions() -> void:
	var today := Time.get_date_string_from_system()
	if day == today and missions.size() == 3:
		return
	day = today
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today)
	var types := MISSIONS.keys()
	missions = []
	while missions.size() < 3:
		var t: String = types[rng.randi() % types.size()]
		if missions.any(func(m): return m.type == t):
			continue
		var targets: Array = MISSIONS[t][1]
		missions.append({"type": t, "target": targets[rng.randi() % targets.size()], "progress": 0.0, "reward": MISSIONS[t][2], "done": false})
	save()


# İlerleme ekler, yeni tamamlanan görevleri döndürür; ödül coin hemen eklenir.
func track(type: String, amount: float) -> Array:
	var done := []
	for m in missions:
		if m.type != type or m.done:
			continue
		m.progress = maxf(m.progress, amount) if type in MAX_TYPES else m.progress + amount
		if m.progress >= m.target:
			m.done = true
			coins += m.reward
			done.append(m)
	if not done.is_empty():
		save()
	return done


func mission_text(m: Dictionary) -> String:
	var label: String = MISSIONS[m.type][0] % m.target
	var p := minf(m.progress, m.target)
	var prog := ("%.1f" % p) if String(m.type).ends_with("km") else str(int(p))
	return "%s%s   %s/%d   +%d" % ["TAMAM · " if m.done else "", label, prog, m.target, m.reward]


# Oyun bitişi: coin ekler, rekoru günceller, görev ilerlemesini kaydeder. Yeni rekorsa true.
func finish_run(score: int, earned: int) -> bool:
	coins += earned
	var new_best := score > best
	if new_best:
		best = score
	save()
	return new_best


func car_info(id: String) -> Dictionary:
	for c in CARS:
		if c.id == id:
			return c
	return CARS[0]


func buy_car(id: String) -> bool:
	var price: int = car_info(id).price
	if id in cars or coins < price:
		return false
	coins -= price
	cars.append(id)
	save()
	return true


func buy_paint(i: int) -> bool:
	var price: int = PAINTS[i][2]
	if i in paints or coins < price:
		return false
	coins -= price
	paints.append(i)
	save()
	return true


func select(id: String, paint_index: int) -> void:
	car = id
	paint = paint_index
	save()
