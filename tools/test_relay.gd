# Aktarma sunucusu denemesi: B kodunu verir (kendi odasında bekler), A kodu girer ve sunucu üzerinden eşleşmeli,
# konum gönderebilmeli. İkinci tur: C ve D birbirinin kodunu girer (iki kodun küçüğünün odasında buluşmalı).
# Sunucu ayrı çalışır:
#   python3 tools/relay.py &   FS_RELAY_PORT=47812 godot-mono --headless --path . --script tools/test_relay.gd
extends SceneTree

var a: Node
var b: Node
var c: Node
var d: Node
var t := 0.0
var step := 0


func _initialize() -> void:
	var net: GDScript = load("res://net.gd")
	a = net.new()
	b = net.new()
	c = net.new()
	d = net.new()
	for n in [a, b, c, d]:
		n.relay_host = "127.0.0.1"
		n.relay_port = int(OS.get_environment("FS_RELAY_PORT")) if OS.get_environment("FS_RELAY_PORT") != "" else 47812
		root.add_child(n)
		n.open()


func _process(dt: float) -> bool:
	t += dt
	if step == 0 and not a._relay.is_empty():
		assert(a.set_peer(b.code), "kod girilemedi")
		assert(c.set_peer(d.code) and d.set_peer(c.code), "karşılıklı kod girilemedi")
		step = 1
	elif step == 1 and a.paired and b.paired:
		print("SUNUCUDAN EŞLEŞTİ %.2f sn  a.via_relay=%s b.via_relay=%s" % [t, a.via_relay, b.via_relay])
		assert(a.via_relay and b.via_relay, "sunucudan geçmiyor")
		a.start("two", 1)
		step = 2
	elif step == 2 and a.racing and b.racing:
		a.send_state(15.0, 1.0, 120.0, false, 0.0)
		step = 3
	elif step == 3 and b.remote.d == 15.0:
		step = 4
	elif step == 4 and c.paired and d.paired:
		print("KARŞILIKLI KODLA EŞLEŞTİ %.2f sn" % t)
		print("TEST OK")
		quit(0)
	if t > 25.0:
		print("ZAMAN AŞIMI adım=%d  %s / %s / %s / %s" % [step, a.status, b.status, c.status, d.status])
		quit(1)
	return false
