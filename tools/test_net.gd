# Online bağlantı denemesi: iki Net aynı süreçte kodlarını birbirine verir, bağlanır, init ile araçlarını
# öğrenir, yarışı başlatıp durum gönderir; yanlış anahtarlı ve hileli paketler reddedilir. STUN için internet
# ister. godot-mono --headless --path . --script tools/test_net.gd
extends SceneTree

var a: Node
var c: Node # ulaşılamayan koda bağlanmaya çalışan: 10 sn sonra vazgeçmeli
var b: Node
var t := 0.0
var step := 0
var gos := 0
var counts := 0
var pauses: Array = []
var hits: Array = []
var wait := 0.0


func _initialize() -> void:
	var net: GDScript = load("res://net.gd")
	a = net.new()
	b = net.new()
	a.car = "p:gtr"
	b.car = "p:civic"
	root.add_child(a)
	root.add_child(b)
	a.go.connect(func(_r, _g): gos += 1)
	b.go.connect(func(_r, _g): gos += 1)
	a.countdown.connect(func(_s): counts += 1)
	b.countdown.connect(func(_s): counts += 1)
	b.remote_pause.connect(func(on): pauses.append(on))
	b.hit.connect(func(k): hits.append(k))
	a.open()
	b.open()
	c = net.new()
	root.add_child(c)
	c.open()
	# belgelere ayrılmış, yanıtsız adres; NAT'ı zor (7. alan "h"): yakın portlara da denenir
	c.set_peer(Marshalls.utf8_to_base64("FS1|203.0.113.1:40000|||9|abcdef12|h"))
	assert(c.peer_hard and c._spray == ["203.0.113.1", 40000], "zor NAT okunmadı")


# Eşleşmeden sonra paketler oturum anahtarıyla gider.
func pkt(to: Node, from: Node, m: Dictionary) -> PackedByteArray:
	m.merge({"fs": 1, "k": to._sess, "me": from._sess})
	return var_to_bytes(m)


func _process(dt: float) -> bool:
	t += dt
	wait -= dt
	if step == 0 and a.code != "" and b.code != "":
		print("KOD A ", Marshalls.base64_to_utf8(a.code), "  ", a.status)
		assert(Marshalls.base64_to_utf8(a.code).split("|").size() == 7, "kodda NAT türü yok")
		assert(a.set_peer(Marshalls.utf8_to_base64("FS1|1.2.3.4:5|||6|0123abcd")), "eski 6 alanlı kod reddedildi")
		assert(Marshalls.base64_to_utf8(a.code).split("|")[1] != "", "STUN dış adresi yok (DNS kuyruğu)")
		assert(not a.set_peer(a.code), "kendi kodu kabul edildi")
		assert(not a.set_peer("bozuk kod"), "bozuk kod kabul edildi")
		# A, B'nin paylaştığı mesajın tamamını yapıştırır
		assert(a.set_peer("Forever Speed online yarış kodum:\n" + b.code) and b.set_peer(a.code), "kod çözülemedi")
		step = 1
	elif step == 1 and a.paired and b.paired:
		print("EŞLEŞTİ %.2f sn  %s:%d  A'nın rakibi %s, B'nin rakibi %s" % [t, a.peer_ip, a.peer_port, a.remote.car, b.remote.car])
		assert(a.remote.car == "p:civic" and b.remote.car == "p:gtr", "init araç bilgisi")
		wait = 1.5 # ping ölçülsün
		step = 2
	elif step == 2 and wait <= 0.0:
		print("PING A %.1f ms  B %.1f ms" % [a.ping_ms, b.ping_ms])
		assert(a.ping_ms > 0.0, "ping ölçülmedi")
		a.set_want(true)
		wait = 1.0
		step = 21
	elif step == 21 and wait <= 0.0:
		assert(b.peer_want and gos == 0, "tek taraf hazırken başladı")
		b.set_want(true)
		step = 22
	elif step == 22 and a.peer_want and b.peer_want:
		a.start("one", 2) # oyunda arayüz başlatır (anahtarı küçük olan); burada A
		step = 3
	elif step == 3 and gos == 2:
		assert(a.region == 2 and b.region == 2, "bölge")
		# yanlış anahtar: atılır
		b._recv(pkt(a, a, {"t": "s", "d": 50.0}).duplicate(), b.peer_ip, b.peer_port)
		assert(b.remote.d == 0.0, "yanlış anahtarlı paket kabul edildi")
		# oturum başladıktan sonra koddaki (Wi-Fi'da yayınlanan) anahtarla gelen: atılır
		assert(b._sess_ok, "oturum anahtarına geçilmedi")
		b._recv(var_to_bytes({"fs": 1, "k": b.token, "me": a.token, "t": "s", "d": 50.0}), b.peer_ip, b.peer_port)
		assert(b.remote.d == 0.0, "kod anahtarlı paket oturumda kabul edildi")
		# hile: başlar başlamaz 3999 m diyen paket sınıra kırpılır
		b._recv(pkt(b, a, {"t": "s", "d": 3999.0, "x": 1.0, "v": 900.0}), b.peer_ip, b.peer_port)
		assert(b.remote.d <= 220.0 and b.remote.v == 600.0, "hileli yol kırpılmadı: %s" % b.remote)
		b.remote.d = 0.0
		a.send_state(20.0, 2.5, 200.0, false) # sınırın (30 m + hız payı) altında
		b.mark_ready() # B önce yüklendi; A hazır olunca ikisinde de geri sayım
		step = 4
	elif step == 4 and b.remote.d == 20.0:
		assert(b.remote.x == 2.5)
		assert(counts == 0, "tek taraf hazırken sayım başladı")
		a.mark_ready()
		step = 5
	elif step == 5 and counts == 2:
		a.send_pause(true)
		a.send_pause(false)
		a.send_hit("rear")
		wait = 1.2 # kopyalar da gelsin: her biri bir kez işlenmeli
		step = 6
	elif step == 6 and wait <= 0.0:
		assert(pauses == [true, false], "duraklatma: %s" % [pauses])
		assert(hits == ["rear"], "çarpışma: %s" % [hits])
		a.send_final(4000.0, 0.0, 200.0, 25.5)
		step = 7
	elif step == 7 and b.remote.ft == 25.5:
		a.send_quit()
		step = 8
	elif step == 8 and b.remote.quit:
		a._connect_t = -1.0 # gerçekte kopma kod yapıştırıldıktan çok sonra olur: bağlanma süresi çoktan dolmuş
		b._connect_t = -1.0
		a.silence = 6.0 # A kopmuş sayar; yeniden bağlanıp init alışmalı
		step = 9
	elif step == 9 and not a.connected:
		step = 10
	elif step == 10 and a.paired and b.paired:
		print("YENİDEN EŞLEŞTİ %.2f sn" % t)
		step = 11
	elif step == 11 and c.targets.is_empty():
		assert(c.status.begins_with("BAĞLANAMADI") and t >= 10.0 and c._spray.is_empty(), "zaman aşımı: %s" % c.status)
		assert(c.status.contains("ARKADAŞININ AĞI") or c.hard, "zor NAT mesajı: %s" % c.status)
		print("ZAMAN AŞIMI %.1f sn: %s" % [t, c.status])
		print("TEST OK")
		quit(0)
	if t > 20.0:
		print("ZAMAN AŞIMI adım=%d  %s / %s" % [step, a.status, b.status])
		quit(1)
	return false
