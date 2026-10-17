# Aktarma sunucusu denemesi: iki Net birbirinin kodunu ulaşılamaz adreslerle alır (doğrudan bağlanamaz), 4 sn
# sonra sunucuya katılıp oradan eşleşmeli ve konum gönderebilmeli. Sunucu ayrı çalışır:
#   python3 tools/relay.py &   FS_RELAY_PORT=47812 godot-mono --headless --path . --script tools/test_relay.gd
extends SceneTree

var a: Node
var b: Node
var t := 0.0
var step := 0


func _initialize() -> void:
	var net: GDScript = load("res://net.gd")
	a = net.new()
	b = net.new()
	for n in [a, b]:
		n.relay_host = "127.0.0.1"
		n.relay_port = int(OS.get_environment("FS_RELAY_PORT")) if OS.get_environment("FS_RELAY_PORT") != "" else 47812
		root.add_child(n)
		n.open()


# Kodun anahtarı aynı, adresleri belgelere ayrılmış yanıtsız adres: doğrudan bağlantı imkânsız.
func dead_code(n: Node) -> String:
	return Marshalls.utf8_to_base64("FS1|203.0.113.7:40000|||9|%s|e" % n.token)


func _process(dt: float) -> bool:
	t += dt
	if step == 0 and a.code != "" and b.code != "":
		assert(a.set_peer(dead_code(b)) and b.set_peer(dead_code(a)))
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
		print("TEST OK")
		quit(0)
	if t > 20.0:
		print("ZAMAN AŞIMI adım=%d  %s / %s" % [step, a.status, b.status])
		quit(1)
	return false
