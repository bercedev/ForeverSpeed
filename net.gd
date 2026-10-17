# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node

# Online yarış: sunucusuz, iki cihaz arasında doğrudan UDP. Herkes dış adresini Google'ın ücretsiz STUN
# sunucusundan öğrenir; adresler "kod" olarak elle (WhatsApp vb.) değiş tokuş edilir, iki taraf aynı anda
# birbirine paket atarak NAT'ta delik açar (hole punching). Kod yerel ağ ve IPv6 adreslerini de taşır: aynı
# Wi-Fi'da ve IPv6'lı mobil veride NAT'a takılmadan bağlanır. Bağlantı sahne yenilense de sürer (autoload).
# ponytail: aktarma (TURN) sunucusu yok; iki taraf da simetrik NAT / CGNAT arkasındaysa bağlantı kurulamaz.
#
# Güvenlik: kodda rastgele bir anahtar var; paket bu anahtarı taşımıyorsa, bağlanılan adresten gelmiyorsa,
# büyükse ya da sözlük değilse atılır (nesne çözülmez). Karşının bildirdiği yol, araç hızının izin
# verdiğinden hızlı artamaz. ponytail: trafik şifreli değil; kodu ele geçiren yarışa girebilir (IP de içerir).
#
# Mesajlar: hi (delik açma, canlı tutma), init (bağlantı kurulunca iki taraf araç bilgisini verir),
# p/q (ping), go (yarış başlar), rdy (sahne yüklendi: ikisi de hazır olunca 3 sn sayılır), s (yarış durumu,
# 20/sn), gh (alan aracı kayboldu), hit (çarpışma: karşı kaçırdıysa kendi payını uygular), pause/resume (duraklatma iki tarafta),
# quit (yarıştan çıktı). Birkaç kez gönderilenler sıra numarası
# taşır, kopyası atılır.

signal changed # durum değişti (arayüz yenilensin)
signal go(road: String, region: int) # yarış başlıyor (iki tarafta da)
signal remote_pause(on: bool) # arkadaş duraklattı / devam dedi
signal ghost(fid: int) # arkadaş trafik alanındaki bu araca çarptı, kayboldu
signal hit(kind: String) # arkadaş çarpışma gördü: bizim payımız (front: öndeydik, rear: bindirdik, side)
signal countdown(sec: float) # iki taraf da hazır: geri sayım (karşıdan gelen mesajla başlayan yarım ping kısa sayar)

const STUN := ["stun.l.google.com", "stun1.l.google.com"]
const STUN_PORT := 19302
const MAGIC := "FS1"
const PROTO := 1 # init'teki sürüm: farklıysa yarış başlatılamaz
const MAX_PACKET := 512
const MAX_MPS := 190.0 # karşının yolu saniyede en çok bu kadar artabilir (~680 km/sa, oyunda erişilmez)

var udp := PacketPeerUDP.new()
var port := 0
var token := "" # bizim anahtarımız: karşı her pakette bunu yollar
var car := "" # bizim araç, boyası ve jantı: init'le gider, karşıda rakip modeli olur
var paint := 0
var rim := 0
var code := "" # bizim kod
var status := ""
var hard := false # iki STUN sunucusu farklı port gördü: simetrik NAT, dışarıdan bağlanmak zor
var targets: Array = [] # karşının kodundaki adresler: [ip, port]
var peer_ip := ""
var peer_port := 0
var peer_token := ""
var connected := false
var paired := false # iki taraf da init'i aldı: yarış başlatılabilir
var racing := false
var region := 0 # yarışın bölgesi (başlatanınki)
var ping_ms := 0.0
var remote := {"d": 0.0, "x": 0.0, "v": 0.0, "w": false, "ft": -1.0, "car": "", "paint": 0, "rim": 0, "quit": false} # karşının son durumu
# (w: kazada yanıp sönüyor, çarpışmaz; ft: bitiş süresi, bitirmediyse -1)
var silence := 0.0 # karşıdan son paketten beri geçen sn
var peer_paused := false # arkadaş duraklattı: uygulaması arka planda olabilir, kopma süresi uzun
var _got_init := false
var _stun_ips := {}
var _dns: Array[int] = [] # çözülmekte olan STUN adları (bloklamadan, IP kuyruğunda)
var _mapped := {} # STUN sunucusu -> onun gördüğü [ip, port]
var _code_t := 0.0 # kod en geç 3 sn'de çıkar (STUN yanıt vermese de yerel / IPv6 adresle)
var _t := 0.0
var _ping_t := 0.0
var _resend := [] # birkaç kez gidecek mesajlar (UDP kaybolabilir): [mesaj, kalan]
var _pending := {} # biz başlattık: ping'in yarısı kadar sonra başlarız, iki taraf aynı anda kalkar
var _begin_t := 0.0
var _send_t := 0.0
var _s_ms := 0
var _seq := 0
var _seen := {} # karşıdan işlenen sıra numaraları (birkaç kez gönderilenlerin kopyası atılır)
var _seen_floor := 0 # bunun altındakiler çoktan işlendi (küme büyümesin)
var _rx_pause := 0 # pause/resume sırası: eskisi geç gelirse yenisini ezmesin
var race_id := 0 # rdy eski yarışa karışmasın
var _me_ready := false
var _peer_rid := -1
var _counted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # duraklatmada da bağlantı ayakta kalsın


func open() -> void:
	close()
	port = randi_range(20000, 60000)
	if udp.bind(port, "*") != OK:
		_say("BAĞLANTI AÇILAMADI")
		return
	token = "%08x" % randi()
	for h in STUN:
		_dns.append(IP.resolve_hostname_queue_item(h, IP.TYPE_IPV4))
	_code_t = 3.0
	_say("ADRESİN BULUNUYOR…")


func close() -> void:
	udp.close()
	for id in _dns:
		IP.erase_resolve_item(id)
	_dns.clear()
	code = ""
	hard = false
	targets.clear()
	_mapped.clear()
	_stun_ips.clear()
	_resend.clear()
	_pending = {}
	connected = false
	paired = false
	racing = false
	_got_init = false
	peer_ip = ""
	peer_token = ""
	remote.car = ""
	peer_paused = false
	_seq = 0
	_seen.clear()
	_seen_floor = 0
	_rx_pause = 0
	ping_ms = 0.0
	silence = 0.0


# Arkadaşın kodu: içindeki adreslere delik açma paketi gider. Kod geçersizse false.
func set_peer(text: String) -> bool:
	text = text.strip_edges()
	if text == code:
		_say("BU SENİN KODUN · ARKADAŞININKİNİ YAPIŞTIR")
		return false
	var f := Marshalls.base64_to_utf8(text).split("|") if text.length() > 8 and text.length() < 400 else PackedStringArray()
	if f.size() != 6 or f[0] != MAGIC or f[5].length() != 8:
		_say("KOD GEÇERSİZ")
		return false
	if connected:
		return true
	targets.clear()
	var p := int(f[4])
	if f[1] != "":
		var hp := f[1].rsplit(":", true, 1)
		targets.append([hp[0], int(hp[1])])
	for a in f[2].split(",", false) + f[3].split(",", false):
		targets.append([a, p])
	targets = targets.slice(0, 6) # bizim kodumuzda en çok 6 adres: fazlası yabancı adrese paket attırmasın
	peer_token = f[5]
	_say("BAĞLANILIYOR… ARKADAŞIN DA SENİN KODUNU YAPIŞTIRSIN")
	return true


# Yarışı başlatır: karşıya hemen, bize ping'in yarısı kadar sonra (go sinyali iki tarafta da).
func start(road: String, rg: int) -> void:
	if not paired or racing or not _pending.is_empty():
		return
	_pending = {"t": "go", "road": road, "rg": rg, "rid": randi() % 1000000}
	_reliable(_pending)
	_begin_t = ping_ms / 2000.0


# Yarışta her kare çağrılır, saniyede 20 kez gider.
func send_state(d: float, x: float, v: float, wreck: bool) -> void:
	if connected and _send_t <= 0.0:
		_send_t = 0.05
		_send({"t": "s", "d": d, "x": x, "v": v, "w": wreck})


# Son konum paketinin yaşı (sn): rakip bu kadar ileri tahmin edilir.
func state_age() -> float:
	return (Time.get_ticks_msec() - _s_ms) / 1000.0


func send_ghost(fid: int) -> void:
	_reliable({"t": "gh", "f": fid})


func send_hit(kind: String) -> void:
	_reliable({"t": "hit", "kind": kind}) # "k" anahtar alanı, _send ezer


# Bitişte son durum ve bitiş süresi (geri sayımın bitişinden): kazananı süre belirler.
func send_final(d: float, x: float, v: float, ft: float) -> void:
	_reliable({"t": "s", "d": d, "x": x, "v": v, "ft": ft})


func send_quit() -> void:
	_reliable({"t": "quit"})


func send_pause(on: bool) -> void:
	_reliable({"t": "pause" if on else "resume"})


# Sahne yüklendi, araçlar hazır: karşı da hazırsa geri sayım başlar.
func mark_ready() -> void:
	_me_ready = true
	_reliable({"t": "rdy", "rid": race_id})
	_check_ready(false)


func _check_ready(from_peer: bool) -> void:
	if racing and _me_ready and _peer_rid == race_id and not _counted:
		_counted = true
		countdown.emit(3.0 - (ping_ms / 2000.0 if from_peer else 0.0))


func _process(dt: float) -> void:
	if not udp.is_bound():
		return
	var n := 0
	while udp.get_available_packet_count() > 0 and n < 64: # sel gibi paket gelirse kareyi kilitlemesin
		n += 1
		var pk := udp.get_packet()
		var ip := udp.get_packet_ip()
		var prt := udp.get_packet_port()
		if _stun_ips.has(ip) and prt == STUN_PORT:
			_stun_reply(pk, ip)
		else:
			_recv(pk, ip, prt)
	for id in _dns.duplicate():
		var st := IP.get_resolve_item_status(id)
		if st == IP.RESOLVER_STATUS_WAITING:
			continue
		if st == IP.RESOLVER_STATUS_DONE and IP.get_resolve_item_address(id) != "":
			_stun_ips[IP.get_resolve_item_address(id)] = true
		IP.erase_resolve_item(id)
		_dns.erase(id)
	_send_t -= dt
	if code == "":
		_code_t -= dt
		if _mapped.size() >= 2 or (_mapped.size() == 1 and _code_t < 1.5) or _code_t <= 0.0:
			_make_code()
	if not _pending.is_empty():
		_begin_t -= dt
		if _begin_t <= 0.0:
			_begin(_pending.road, _pending.rg, _pending.rid)
			_pending = {}
	if connected:
		silence += dt
		if silence > (30.0 if peer_paused else 5.0):
			connected = false
			paired = false
			racing = false
			_got_init = false
			_say("BAĞLANTI KOPTU · KODLARI YENİDEN DEĞİŞİN")
		_ping_t -= dt
		if _ping_t <= 0.0:
			_ping_t = 1.0
			_send({"t": "p", "ts": Time.get_ticks_msec()})
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.25
	if code == "": # yanıt gelene kadar tekrar sor
		for ip in _stun_ips:
			udp.set_dest_address(ip, STUN_PORT)
			udp.put_packet(_stun_request())
	for r in _resend:
		_send(r[0])
		r[1] -= 1
	_resend = _resend.filter(func(r): return r[1] > 0)
	if not connected:
		for t in targets: # delik açma: karşı da bize atınca iki NAT'ta da yol açılır
			_send({"t": "hi"}, t[0], t[1])
	elif not _got_init:
		_send_init()
	else:
		_send({"t": "hi"}) # bağlantı canlı kalsın: duraklatmada durum paketi gitmez, NAT eşlemesi de düşer


func _send(m: Dictionary, ip := peer_ip, prt := peer_port) -> void:
	var out := m.duplicate()
	out["fs"] = 1
	out["k"] = peer_token # karşının anahtarı: onu bilmeyen paketi atılır
	out["me"] = token
	udp.set_dest_address(ip, prt)
	udp.put_packet(var_to_bytes(out))


func _reliable(m: Dictionary) -> void:
	_seq += 1
	m["n"] = _seq
	_send(m)
	_resend.append([m, 3])


func _send_init() -> void:
	_send({"t": "init", "v": PROTO, "car": car, "paint": paint, "rim": rim, "got": _got_init})


func _recv(pk: PackedByteArray, ip: String, prt: int) -> void:
	if pk.size() < 8 or pk.size() > MAX_PACKET or (pk.decode_u32(0) & 0xFF) != TYPE_DICTIONARY:
		return
	var m = bytes_to_var(pk) # nesne çözülmez (bytes_to_var_with_objects değil)
	if not (m is Dictionary) or m.get("fs") != 1 or m.get("k") != token or not (m.get("me") is String):
		return
	var me: String = m.me
	if connected:
		if ip != peer_ip or prt != peer_port or me != peer_token:
			return
	else:
		if me.length() != 8 or (peer_token != "" and me != peer_token): # kodunu yapıştırdığımız kişi değil
			return
		connected = true
		peer_ip = ip
		peer_port = prt
		peer_token = me
		# yeniden bağlanma: init yeniden alışılır; arkadaş uygulamayı yeniden açtıysa sıra numaraları sıfırdan
		_got_init = false
		paired = false
		_seen.clear()
		_seen_floor = 0
		_rx_pause = 0
		_send_init()
		_say("BAĞLANDI · ARAÇ BİLGİSİ BEKLENİYOR…")
	silence = 0.0
	if m.has("n"): # birkaç kez gönderilen mesajın kopyası; pause/resume ayrıca sıralı (sonuncusu geçer)
		var seq := int(_num(m, "n"))
		if seq <= _seen_floor or _seen.has(seq):
			return
		_seen[seq] = true
		if _seen.size() > 512: # eskiler atılır: o kadar geç gelen kopya çoktan işlenmiştir
			_seen_floor = seq - 256
			for q in _seen.keys():
				if q <= _seen_floor:
					_seen.erase(q)
		if m.get("t") in ["pause", "resume"]:
			if seq <= _rx_pause:
				return
			_rx_pause = seq
	match m.get("t"):
		"init":
			if not _got_init:
				_got_init = true
				remote.car = str(m.get("car", "")).left(32)
				remote.paint = int(_num(m, "paint")) # aralığı oyun denetler
				remote.rim = int(_num(m, "rim"))
				paired = m.get("v") == PROTO
				_say("HAZIR · YARIŞI İKİNİZDEN BİRİ BAŞLATSIN" if paired else "SÜRÜMLER FARKLI · OYUNU GÜNCELLEYİN")
			if not m.get("got", true):
				_send_init() # bizimki ona ulaşmamış
		"p":
			_send({"t": "q", "ts": _num(m, "ts")})
		"q":
			var rtt := Time.get_ticks_msec() - _num(m, "ts")
			if rtt >= 0.0 and rtt < 5000.0:
				ping_ms = rtt if ping_ms == 0.0 else lerpf(ping_ms, rtt, 0.3)
				changed.emit()
		"go":
			# ikimiz aynı anda bastıysak anahtarı küçük olanınki geçer
			if paired and not racing and (_pending.is_empty() or me < token):
				_pending = {}
				_begin(str(m.get("road", "two")), int(_num(m, "rg")), int(_num(m, "rid")))
		"rdy":
			_peer_rid = int(_num(m, "rid")) # go'dan önce gelebilir (sıra karışırsa): saklanır
			_check_ready(true)
		"s":
			var now := Time.get_ticks_msec()
			# geçen süre 1 sn'yle sınırlı: duraklatmada s gitmez, birikmiş süre büyük bir sıçramaya izin vermesin
			var lim: float = remote.d + MAX_MPS * minf(now - _s_ms, 1000.0) / 1000.0 + 30.0
			remote.d = clampf(_num(m, "d"), remote.d, lim) # paket sırası karışabilir, yol geri gitmez
			remote.x = clampf(_num(m, "x"), -12.0, 12.0)
			remote.v = clampf(_num(m, "v"), 0.0, 600.0)
			remote.w = m.get("w") == true
			if m.has("ft"): # oyun, mesajın geliş anına göre ayrıca denetler (main.update_online)
				remote.ft = maxf(_num(m, "ft"), 0.0)
			_s_ms = now
		"quit":
			if racing:
				remote.quit = true
		"gh":
			if racing:
				ghost.emit(int(_num(m, "f")))
		"hit":
			if racing and m.get("kind") in ["front", "rear", "side"]: # yakınlığı oyun denetler
				hit.emit(m.kind)
		"pause", "resume":
			if racing:
				peer_paused = m.t == "pause"
				remote_pause.emit(peer_paused)


func _num(m: Dictionary, k: String) -> float:
	var v = m.get(k, 0.0)
	return float(v) if v is float or v is int else 0.0


func _begin(road: String, rg: int, rid: int) -> void:
	racing = true
	race_id = rid
	_me_ready = false
	_counted = false
	region = clampi(rg, 0, 3)
	remote.d = 0.0
	remote.v = 0.0
	remote.ft = -1.0
	remote.w = false
	remote.quit = false
	peer_paused = false
	_s_ms = Time.get_ticks_msec()
	go.emit("one" if road == "one" else "two", region)


func _make_code() -> void:
	var seen: Array = _mapped.values()
	var pub := "%s:%d" % seen[0] if not seen.is_empty() else ""
	var lan := PackedStringArray()
	var v6 := PackedStringArray()
	for a in IP.get_local_addresses():
		var o := a.split(".")
		if a.contains(":"):
			if (a.begins_with("2") or a.begins_with("3")) and not a.contains("%"): # yalnız internet adresi (2000::/3)
				v6.append(a)
		elif o[0] == "10" or (o[0] == "192" and o[1] == "168") or (o[0] == "172" and int(o[1]) >= 16 and int(o[1]) <= 31):
			lan.append(a)
	code = Marshalls.utf8_to_base64("%s|%s|%s|%s|%d|%s" % [MAGIC, pub, ",".join(lan.slice(0, 3)), ",".join(v6.slice(0, 2)), port, token])
	hard = seen.size() >= 2 and seen[0][1] != seen[1][1]
	if OS.is_debug_build():
		print("[net] kod ", code, " ", Marshalls.base64_to_utf8(code))
	if pub == "" and v6.is_empty():
		_say("İNTERNET ADRESİ BULUNAMADI · YALNIZ AYNI WI-FI")
	elif hard:
		_say("KODUNU ARKADAŞINA GÖNDER · AĞIN ZOR, OLMAZSA WI-FI DENE")
	else:
		_say("KODUNU ARKADAŞINA GÖNDER, ONUNKİNİ YAPIŞTIR")


# STUN bağlama isteği (RFC 5389): tür 0x0001, uzunluk 0, sihirli çerez, 12 bayt işlem kimliği.
func _stun_request() -> PackedByteArray:
	var r := PackedByteArray([0, 1, 0, 0, 0x21, 0x12, 0xA4, 0x42])
	for i in 12:
		r.append(randi() % 256)
	return r


# Yanıttaki (XOR-)MAPPED-ADDRESS: dışarıdan görünen IPv4 ve port.
func _stun_reply(p: PackedByteArray, server: String) -> void:
	if p.size() < 20 or p[0] != 0x01 or p[1] != 0x01:
		return
	var i := 20
	while i + 12 <= p.size():
		var typ := p[i] << 8 | p[i + 1]
		var n := p[i + 2] << 8 | p[i + 3]
		if (typ == 0x0020 or typ == 0x0001) and n >= 8 and p[i + 5] == 0x01:
			var k := [0x21, 0x12, 0xA4, 0x42] if typ == 0x0020 else [0, 0, 0, 0]
			var prt: int = (p[i + 6] << 8 | p[i + 7]) ^ (k[0] << 8 | k[1])
			var ip := "%d.%d.%d.%d" % [p[i + 8] ^ k[0], p[i + 9] ^ k[1], p[i + 10] ^ k[2], p[i + 11] ^ k[3]]
			_mapped[server] = [ip, prt]
			return
		i += 4 + ((n + 3) & ~3)


func _say(s: String) -> void:
	status = s
	changed.emit()
