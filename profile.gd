# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node

# Kalıcı oyuncu verisi (autoload "Profile"): coin, rekor, garaj, ayarlar, günlük görevler.

const PATH := "user://save.cfg"
# İsimlerde marka yok: mağazada sorun çıkarmasın.
# top: tavan hıza eklenen km/sa, accel: ivme çarpanı
const CARS := [
	{"id": "p:e30", "name": "E30 KLASİK", "price": 0, "top": -2.0, "accel": 0.8},
	{"id": "p:doblo", "name": "DOBLO", "price": 750, "top": -10.0, "accel": 0.72},
	{"id": "p:compact", "name": "CITY HOPPER", "price": 1000, "top": -5.0, "accel": 0.8},
	{"id": "p:civic", "name": "CIVIC", "price": 1600, "top": 0.0, "accel": 0.85},
	{"id": "r34", "name": "MIDNIGHT GT", "price": 2500, "top": 4.0, "accel": 0.9},
	{"id": "p:coupe", "name": "COUPE GT", "price": 3800, "top": 12.0, "accel": 1.05},
	{"id": "p:suv", "name": "BIG SUV", "price": 5100, "top": 8.0, "accel": 0.95},
	{"id": "p:phoenix", "name": "PHOENIX 455", "price": 5700, "top": 16.0, "accel": 1.1},
	{"id": "p:challenger", "name": "CHALLENGER SRT", "price": 7500, "top": 22.0, "accel": 1.2},
	{"id": "p:maybach", "name": "MAYBACH", "price": 8800, "top": 26.0, "accel": 1.12},
	{"id": "p:sport", "name": "SPORT X", "price": 9500, "top": 28.0, "accel": 1.25},
	{"id": "p:m4", "name": "M4 CSL", "price": 10800, "top": 30.0, "accel": 1.3},
	{"id": "p:gtr", "name": "GT-R", "price": 11500, "top": 32.0, "accel": 1.35},
	{"id": "p:m5", "name": "M5", "price": 12500, "top": 33.0, "accel": 1.38},
	{"id": "p:sf90", "name": "SF90 STRADALE", "price": 14000, "top": 36.0, "accel": 1.45},
]
# Listeden çıkan eski (Kenney) araçlar: sahibine fiyatı geri verilir.
const RETIRED := {"taxi": 1200, "sedan-sports": 1500, "hatchback-sports": 2500, "suv-luxury": 3500,
	"race": 8500, "police": 11050, "race-future": 15300}
# Araç başına geliştirme: [ad, ilk seviye fiyatı]. Fiyat seviyeyle artar, en çok MAX_LEVEL.
const UPGRADES := {
	"speed": ["HIZ", 400],
	"accel": ["İVME", 350],
	"brake": ["FREN", 250],
	"nitro": ["NİTRO", 450],
}
const MAX_LEVEL := 5
const MODES := ["normal", "time", "race", "free"]
const MODE_NAMES := ["NORMAL", "ZAMANA KARŞI", "YARIŞ", "SERBEST"]
const CAMS := ["TAKİP", "UZAK", "KAPUT", "KOKPİT"]
const STATIONS := ["KAPALI", "SYNTH FM", "LO-FI FM"]
# [ad, renk, fiyat, kaplama, ikinci renk]; 0 = modelin kendi rengi. Kaplama car.gdshader'daki finish.
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
	["METALİK GRİ", Color(0.35, 0.37, 0.41), 800, 1],
	["METALİK MAVİ", Color(0.1, 0.3, 0.85), 900, 1],
	["MAT SİYAH", Color(0.05, 0.05, 0.055), 900, 2],
	["MAT HAKİ", Color(0.25, 0.3, 0.17), 900, 2],
	["ŞEKER KIRMIZI", Color(0.75, 0.02, 0.06), 1300, 6],
	["NEON PEMBE", Color(1.0, 0.15, 0.65), 1600, 5],
	["BUKALEMUN", Color(0.5, 0.1, 0.85), 1900, 4, Color(0.0, 0.9, 0.75)],
	["KROM", Color(0.85, 0.87, 0.9), 2400, 3],
	["YARIŞ ŞERİDİ", Color(0.08, 0.2, 0.75), 1100, 7, Color(0.95, 0.95, 0.97)],
	["ALEV", Color(0.04, 0.04, 0.05), 1700, 8],
	["KAMUFLAJ", Color(0.22, 0.27, 0.15), 1200, 9, Color(0.42, 0.36, 0.22)],
	["DAMA", Color(0.92, 0.92, 0.94), 1300, 10, Color(0.04, 0.04, 0.05)],
	["GRAFİTİ", Color(0.12, 0.1, 0.16), 2200, 11],
	["KARBON", Color(0.06, 0.06, 0.07), 1500, 12],
	["KAPLAN", Color(0.95, 0.5, 0.05), 1800, 13, Color(0.03, 0.03, 0.03)],
	["NEON DEVRE", Color(0.03, 0.03, 0.04), 2600, 14, Color(0.1, 0.95, 1.0)],
]
# Jant: [ad, desen, renk, kaplama, fiyat]. Desen 0 aracın kendi tekerleği; 1 beş kol, 2 on ince kol,
# 3 örgü, 4 çift kol, 5 altı kol derin çanak (main.rim_mesh). Kaplama: 1 krom, 2 mat, 3 metalik, 4 neon.
const RIMS := [
	["ORİJİNAL", 0, Color(1, 1, 1), 0, 0],
	["KROM", 1, Color(0.85, 0.87, 0.9), 1, 500],
	["MAT SİYAH", 2, Color(0.06, 0.06, 0.07), 2, 500],
	["ALTIN", 3, Color(1.0, 0.75, 0.25), 3, 800],
	["SPOR", 4, Color(0.8, 0.82, 0.86), 3, 900],
	["SPOR KIRMIZI", 1, Color(0.85, 0.08, 0.08), 3, 1100],
	["KLASİK BEYAZ", 5, Color(0.92, 0.92, 0.94), 3, 900],
	["DERİN SİYAH", 5, Color(0.08, 0.08, 0.09), 1, 1000],
	["NEON MAVİ", 2, Color(0.1, 0.8, 1.0), 4, 1600],
]
# Araç başına modifiye: [ad, fiyat, seçenekler]. Alınınca seçenekler arasında gezilir (ilk seçenek kapalı).
const MODS := {
	"glow": ["ALT NEON", 900, ["KAPALI", "MAVİ", "PEMBE", "YEŞİL", "MOR", "BEYAZ"]],
	"low": ["SÜSPANSİYON", 700, ["STANDART", "ALÇAK", "ÇOK ALÇAK"]],
	"fog": ["SİS FARI", 600, ["KAPALI", "AÇIK"]],
	"amber": ["AMERİKAN PARK", 400, ["KAPALI", "AÇIK"]],
}
const GLOW_COLORS := [Color(0, 0, 0), Color(0.15, 0.45, 1.0), Color(1.0, 0.15, 0.65), Color(0.15, 1.0, 0.4), Color(0.6, 0.2, 1.0), Color(0.9, 0.95, 1.0)]
# tür: [metin, hedefler, ödül coin]
const MISSIONS := {
	"near": ["%d yakın geçiş yap", [15, 25, 40], 150],
	"near_tunnel": ["Tünelde %d yakın geçiş", [3, 5, 8], 200],
	"fast_km": ["220+ km/sa ile %d km git", [1, 2, 3], 200],
	"run_km": ["Tek oyunda %d km git", [3, 5, 8], 250],
	"nitro": ["%d kez nitro kullan", [2, 4, 6], 150],
	"combo": ["x%d kombo yap", [4, 6, 8], 200],
	"siren": ["Sirenli araca %d kez yol ver", [1, 2, 3], 150],
	"bridge_km": ["Köprüde %d km git", [1, 2], 200],
}
const MAX_TYPES := ["run_km", "combo"] # bunlarda ilerleme toplanmaz, en iyi değer tutulur

var coins := 0
var best := 0
var cars: Array = ["p:e30"]
var paints: Array = [0]
var car := "p:e30"
var paint := 0
var rims: Array = [0] # alınan jantlar
var rim := 0
var vibration := true
var sound := true
var quality := 1 # 0 düşük, 1 orta, 2 yüksek
var fps := 60 # kare hızı sınırı: zayıf telefonda 30, iyisinde 90-120
var auto_tuned := false # grafik ve FPS ilk açılışta telefona göre seçildi mi
var nitro_tip := false # nitro öğreticisi bir kez gösterilir
var upgrades := {} # araç id -> {speed, accel, brake, nitro: seviye}
var mods := {} # araç id -> {mod: seçili seçenek}; yoksa alınmamış
var mode := "normal"
var road := "two" # "two": karşıdan trafik var, "one": dört şerit de ileri
var cam := 0
var radio := 1
var autostart := false # kaydedilmez: "TEKRAR" sahneyi yenileyince menüyü atlar
var clock := 0.0 # kaydedilmez: oyun saati (0-24); açılışta gerçek saat, oyunda hızlı akar, sahne yenilense de sürer
var day := ""
var missions: Array = []


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK or cfg.load(PATH + ".tmp") == OK: # kayıt yeniden adlandırılmadan kesildiyse yan dosya
		coins = cfg.get_value("p", "coins", 0)
		best = cfg.get_value("p", "best", 0)
		cars = cfg.get_value("p", "cars", ["p:e30"])
		paints = cfg.get_value("p", "paints", [0])
		car = cfg.get_value("p", "car", "p:e30")
		paint = cfg.get_value("p", "paint", 0)
		rims = cfg.get_value("p", "rims", [0])
		rim = cfg.get_value("p", "rim", 0)
		vibration = cfg.get_value("p", "vibration", true)
		sound = cfg.get_value("p", "sound", true)
		quality = cfg.get_value("p", "quality", 1)
		fps = cfg.get_value("p", "fps", 60)
		auto_tuned = cfg.get_value("p", "auto_tuned", false)
		nitro_tip = cfg.get_value("p", "nitro_tip", false)
		upgrades = cfg.get_value("p", "upgrades", {})
		mods = cfg.get_value("p", "mods", {})
		var old: Dictionary = cfg.get_value("p", "extras", {}) # eski kayıt: 1 kapalı, 2 açık
		for id in old:
			for k in old[id]:
				if old[id][k] > 0 and not mods.get(id, {}).has(k):
					var d: Dictionary = mods.get(id, {})
					d[k] = old[id][k] - 1
					mods[id] = d
		mode = cfg.get_value("p", "mode", "normal")
		road = cfg.get_value("p", "road", "two")
		cam = cfg.get_value("p", "cam", 0)
		radio = cfg.get_value("p", "radio", 1)
		day = cfg.get_value("m", "day", "")
		missions = cfg.get_value("m", "list", [])
		# yeni ilk araç herkese; listeden çıkan araçların parası iade
		if not "p:e30" in cars:
			cars.append("p:e30")
		for id in RETIRED:
			if id in cars:
				cars.erase(id)
				coins += RETIRED[id]
		if CARS.all(func(c): return c.id != car):
			car = "p:e30"
	refresh_missions()
	var now := Time.get_time_dict_from_system()
	clock = now.hour + now.minute / 60.0


func save() -> void:
	var cfg := ConfigFile.new()
	for k in ["coins", "best", "cars", "paints", "car", "paint", "rims", "rim", "vibration", "sound", "quality", "fps", "auto_tuned", "nitro_tip", "upgrades", "mods", "mode", "road", "cam", "radio"]:
		cfg.set_value("p", k, get(k))
	cfg.set_value("m", "day", day)
	cfg.set_value("m", "list", missions)
	# önce yan dosyaya, sonra yeniden adlandırma: yazarken uygulama öldürülürse eski kayıt sağlam kalır
	# (doğrudan yazmada yarım kalan dosya açılışta okunamıyor, bütün ilerleme sıfırlanıyordu)
	if cfg.save(PATH + ".tmp") == OK:
		DirAccess.rename_absolute(PATH + ".tmp", PATH)


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


# Yoksa alır, varsa takar.
func use_rim(i: int) -> bool:
	if not (i in rims):
		if coins < RIMS[i][4]:
			return false
		coins -= RIMS[i][4]
		rims.append(i)
	rim = i
	save()
	return true


# Seçili seçenek; -1 alınmamış.
func mod(id: String, key: String) -> int:
	return mods.get(id, {}).get(key, -1)


# Yoksa satın alır (ilk açık seçenekle gelir), varsa sıradaki seçeneğe geçer.
func use_mod(id: String, key: String) -> bool:
	var st := mod(id, key)
	if st < 0:
		if coins < MODS[key][1]:
			return false
		coins -= MODS[key][1]
	var d: Dictionary = mods.get(id, {})
	d[key] = (st + 1) % MODS[key][2].size() if st >= 0 else 1
	mods[id] = d
	save()
	return true


func level(id: String, key: String) -> int:
	return upgrades.get(id, {}).get(key, 0)


func upgrade_price(id: String, key: String) -> int:
	return UPGRADES[key][1] * (level(id, key) + 1)


func buy_upgrade(id: String, key: String) -> bool:
	var price := upgrade_price(id, key)
	if level(id, key) >= MAX_LEVEL or coins < price:
		return false
	coins -= price
	if not upgrades.has(id):
		upgrades[id] = {}
	upgrades[id][key] = level(id, key) + 1
	save()
	return true


func select(id: String, paint_index: int) -> void:
	car = id
	paint = paint_index
	save()
