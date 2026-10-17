# Online bağlantı denemesi: A, B'nin 8 haneli kodunu girer ve aynı Wi-Fi gibi doğrudan (127.0.0.1) bağlanır, init ile
# araçlarını öğrenir, yarışı başlatıp durum gönderir; yanlış anahtarlı ve hileli paketler reddedilir. İnternet ve
# aktarma sunucusu gerekmez (sunucu yolu: tools/test_relay.gd). godot-mono --headless --path . --script tools/test_net.gd
extends SceneTree

var a: Node
var c: Node # sunucusu olmadan koda bağlanmaya çalışan: 12 sn sonra vazgeçip nedenini söylemeli
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
	c = net.new()
	root.add_child(c)
	for n in [a, b, c]:
		n.relay_host = "" # bu denemede sunucu yok
		n.open()
	assert(c.set_peer("1234 5678"), "boşluklu kod reddedildi")


# Eşleşmeden sonra paketler oturum anahtarıyla gider.
func pkt(to: Node, from: Node, m: Dictionary) -> PackedByteArray:
	m.merge({"fs": 1, "k": to._sess, "me": from._sess})
	return var_to_bytes(m)


# Yarış durumunun ikili paketi (net.send_state düzeni): etiket, anahtarlar, yol, x.
func bin(to: Node, from: Node, d: float, x := 0.0) -> PackedByteArray:
	var pk := PackedByteArray()
	pk.resize(22)
	pk[0] = 0xB5
	pk.encode_u32(1, to._sess.hex_to_int())
	pk.encode_u32(5, from._sess.hex_to_int())
	pk.encode_float(9, d)
	pk.encode_half(13, x)
	return pk


func _process(dt: float) -> bool:
	t += dt
	wait -= dt
	if step == 0 and a.code != "" and b.code != "":
		print("KOD A ", a.code, "  ", a.status)
		assert(a.code.length() == 8 and a.code.is_valid_int() and a.token == a.code, "kod 8 rakam değil")
		assert(not a.set_peer(a.code), "kendi kodu kabul edildi")
		assert(not a.set_peer("bozuk kod 12"), "bozuk kod kabul edildi")
		# A, B'nin paylaştığı mesajın tamamını yapıştırır; B kodu vermiş, bekler. Aynı Wi-Fi gibi doğrudan.
		assert(a.set_peer("Forever Speed online yarış kodum: %s %s" % [b.code.left(4), b.code.right(4)]), "kod çözülemedi")
		assert(a.peer_token == b.code and a.entered and not b.entered, "kod girilmedi")
		a.targets = [["127.0.0.1", b.port]]
		a._relay_on = false
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
		# ikili durum paketi: yanlış anahtarlı atılır, NaN yolu bozmaz
		b._recv(bin(a, a, 50.0), b.peer_ip, b.peer_port)
		assert(b.remote.d == 0.0, "yanlış anahtarlı ikili paket kabul edildi")
		b._recv(bin(b, a, NAN), b.peer_ip, b.peer_port)
		assert(is_finite(b.remote.d) and b.remote.d == 0.0, "NaN yol kabul edildi: %s" % b.remote.d)
		a.send_state(20.0, 2.5, 200.0, false, 0.0) # sınırın (30 m + hız payı) altında
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
		# onay gelince tekrar durur (onaysız olsaydı 3 sn boyunca gidecekti)
		assert(a._resend.is_empty(), "onaylanan mesaj hâlâ tekrar kuyruğunda: %d" % a._resend.size())
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
	elif step == 11 and not c._relay_on and c.status.begins_with("BAĞLANAMADI"):
		assert(t >= 11.0 and c.status.contains("SUNUCU"), "zaman aşımı: %s" % c.status)
		print("ZAMAN AŞIMI %.1f sn: %s" % [t, c.status])
		print("TEST OK")
		quit(0)
	if t > 20.0:
		print("ZAMAN AŞIMI adım=%d  %s / %s" % [step, a.status, b.status])
		quit(1)
	return false
