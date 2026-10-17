# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node

# Online yarış: 8 haneli kodla, aktarma sunucusu (tools/relay.py) üzerinden. Kodu veren kendi kodunun odasında
# bekler, kodu giren o odaya katılır; sunucu paketleri iki taraf arasında taşır, içini okumaz (doğrulama anahtarla).
# İkisi birbirinin kodunu girerse giren taraf 3 sn'de bir iki kodun küçüğünün odasına da bakar, orada buluşurlar.
# Aynı Wi-Fi: panel açıkken kod yerel ağa saniyede bir yayınlanır (LAN_PORT), arkadaş tek dokunuşla doğrudan
# (sunucusuz) bağlanır; yayın yalnız bağlanana kadar sürer (o arada aynı ağdaki herkes kodu görebilir).
# Bağlantı sahne yenilense de sürer (autoload).
#
# Güvenlik: kod aynı zamanda tanışma anahtarı (yalnız tanışmada); bağlanınca iki taraf init ile yeni bir oturum
# anahtarı verir ve karşıdan oturum anahtarlı ilk paket gelince kod anahtarı artık kabul edilmez (Wi-Fi'da yayınlanan
# kodu gören araya giremez). Anahtarı tutmayan, büyük ya da sözlük olmayan paket atılır (nesne çözülmez). Karşının bildirdiği yol, araç hızının izin
# verdiğinden hızlı artamaz. ponytail: trafik şifreli değil; kodu bilen (ya da 10^8'de tahmin eden) bekleyen odaya girebilir.
#
# Mesajlar: init (bağlantı kurulunca iki taraf araç bilgisini verir),
# hi (katılma, canlı tutma), p/q (ping), cfg (lobi: mod ve bot, ikimizde ortak), want (yarışa hazırım: ikisi de hazırsa başlar), go (yarış
# başlar), pk (nitro taşını aldım), fsc (puan yarışında son puan), bft / bh (bot bitirdi / bota çarptım), rdy (sahne yüklendi: ikisi de hazır olunca 3 sn sayılır), s (yarış durumu,
# 20/sn), bye (bağlantıyı bıraktım: karşı da kopmuş sayar), gh (alan aracı kayboldu), hit (çarpışma: karşı kaçırdıysa kendi payını uygular), pause/resume (duraklatma iki tarafta),
# quit (yarıştan çıktı). Birkaç kez gönderilenler sıra numarası
# taşır, karşı her birine ack döner, kopyası atılır. Yarıştaki s (20/sn) sözlük değil, sabit ikili paket (send_state);
# bitişteki son s sözlük olarak, sıra numarasıyla gider.

signal changed # durum değişti (arayüz yenilensin)
signal go(road: String, region: int) # yarış başlıyor (iki tarafta da)
signal remote_pause(on: bool) # arkadaş duraklattı / devam dedi
signal ghost(fid: int) # arkadaş trafik alanındaki bu araca çarptı, kayboldu
signal picked(id: int) # arkadaş bu nitro taşını aldı
signal bot_hit(kind: String) # arkadaş bota çarptı (botu süren biziz)
signal hit(kind: String) # arkadaş çarpışma gördü: bizim payımız (front: öndeydik, rear: bindirdik, side)
signal countdown(sec: float) # iki taraf da hazır: geri sayım (karşıdan gelen mesajla başlayan yarım ping kısa sayar)

const PROTO := 3 # init'teki sürüm: farklıysa yarış başlatılamaz (2: ikili durum paketi, onaylı mesajlar; 3: 8 haneli kod)
const MAX_PACKET := 512
const STATE_TAG := 0xB5 # ikili durum paketinin ilk baytı (sözlük paketleri 0x1B ile başlar)
const RESEND_TRIES := 12 # onaylanmayan mesaj 0,25 sn arayla en çok bu kadar gider (3 sn)
const LAN_PORT := 47811
const RELAY_HOST := "forever-speed-relay.cerceyn.com" # aktarma sunucusu (tools/relay.compose.yml, kurucucan sunucusu); Cloudflare proxy'siz (gri bulut) A kaydı olmalı: UDP proxy'den geçmez
const RELAY_PORT := 47812
const RELAY_MAGIC := "FSR1"
const MAX_MPS := 190.0 # karşının yolu saniyede en çok bu kadar artabilir (~680 km/sa, oyunda erişilmez)

var udp := PacketPeerUDP.new()
var lan := PacketPeerUDP.new() # aynı Wi-Fi keşfi (yayın)
var lan_peers := {} # aynı ağda yayın yapan kod -> {"car": araç, "t": son görülme ms, "ip", "port"}
var _lan_bcast: Array[String] = [] # yayın adresleri: genel ve her yerel ağın /24 yayını
var _lan_t := 0.0
var port := 0
var token := "" # bizim anahtarımız (kodumuzla aynı, 8 rakam): karşı her pakette bunu yollar
var car := "" # bizim araç, boyası ve jantı: init'le gider, karşıda rakip modeli olur
var paint := 0
var rim := 0
var code := "" # bizim kod: 8 rakam
var entered := false # arkadaşın kodunu biz girdik (odasına biz gideriz); girmediysek kendi odamızda bekleriz
var status := ""
var targets: Array = [] # doğrudan denenecek adresler (aynı Wi-Fi): [ip, port]
var peer_ip := ""
var peer_port := 0
var peer_token := ""
var _sess := "" # bu bağlantının oturum anahtarları (init'le değişilir)
var _peer_sess := ""
var _peer_has_sess := false # arkadaş bizim oturum anahtarımızı aldı: artık onunla göndeririz
var _sess_ok := false # arkadaştan oturum anahtarlı paket geldi: kod anahtarlısı artık atılır
var _roam := "" # adres değişimi: yeni adresten art arda gelen paketler (geç gelen delik açma paketi adresi çevirmesin)
var _roam_n := 0
var connected := false
var paired := false # iki taraf da init'i aldı: yarış başlatılabilir
var racing := false
var lobby := {"mode": "race", "bot": false} # mod: race (4 km) ya da score (2 dk puan); bot: üçüncü yarışçı
var mode := "race" # başlayan yarışın modu ve botu (başlatanınki)
var bot := false
var want := false # "YARIŞA HAZIRIM" dedik; yarış ikimiz de deyince başlar (kimse habersiz içeri çekilmesin)
var peer_want := false
var region := 0 # yarışın bölgesi (başlatanınki)
var ping_ms := 0.0
var remote := {"d": 0.0, "x": 0.0, "v": 0.0, "w": false, "nz": false, "bn": false, "ft": -1.0, "sc": 0.0, "fsc": -1, "bd": 0.0, "bx": 0.0, "bv": 0.0, "bft": -1.0, "car": "", "paint": 0, "rim": 0, "quit": false} # karşının son durumu
# (w: kazada yanıp sönüyor, çarpışmaz; ft: bitiş süresi, bitirmediyse -1)
var silence := 0.0 # karşıdan son paketten beri geçen sn
var peer_paused := false # arkadaş duraklattı: uygulaması arka planda olabilir, kopma süresi uzun
var _got_init := false
var _t := 0.0
var _ping_t := 0.0
var _resend := [] # birkaç kez gidecek mesajlar (UDP kaybolabilir): [mesaj, kalan]
var _pending := {} # biz başlattık: ping'in yarısı kadar sonra başlarız, iki taraf aynı anda kalkar
var _begin_t := 0.0
var _send_t := 0.0
var _s_ms := 0
var _got_state := false # bu yarışta karşıdan konum geldi (hazırlıkta gelmez)
var _state_quiet := 0.0 # yarışta, ikimiz de oynarken konumsuz geçen süre: kopma sayılır ("hi" gelse bile)
var _self_paused := false
var relay_host := RELAY_HOST # test başka sunucu verebilir
var relay_port := RELAY_PORT
var via_relay := false # bağlantı aktarma sunucusundan geçiyor
var _relay: Array = [] # çözülmüş sunucu adresi [ip, port]
var _relay_dns := -1
var _relay_wait := 0.0 # aynı Wi-Fi'da önce doğrudan denenir, bu kadar sn sonra sunucu da
var _relay_on := false # sunucudaki odaya katılıyoruz (kod verdiysek kendi odamız, girdiysek arkadaşınki)
var _flip_t := 0.0 # kodu giren: 3 sn arkadaşın odası, 3 sn iki kodun küçüğünün odası (ikisi de girdiyse buluşma)
var _relay_ok := false # sunucu katılmayı onayladı
var _connect_t := 0.0 # kod girildi: bu kadar sn içinde bağlanamazsak denemek durur, nedeni söylenir
var _ready_wait := 0.0 # hazırız ama arkadaş hazır değil: çok sürerse yarış iptal (siyah ekranda kalınmasın)
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
	code = "%08d" % (randi() % 100000000)
	token = code # rakamlar onaltılık da geçerli: ikili durum paketinde %08x ile aynı geri döner
	entered = false
	lan.set_broadcast_enabled(true) # Android'de çoklu yayın kilidini de alır (change_wifi_multicast_state izni)
	if lan.bind(LAN_PORT, "0.0.0.0") != OK: # aynı cihazda ikinci oyun: yalnız yayınlar, dinleyemez
		lan.bind(0, "0.0.0.0")
	if relay_host != "":
		_relay_dns = IP.resolve_hostname_queue_item(relay_host, IP.TYPE_IPV4)
	_lan_setup()
	if OS.is_debug_build():
		print("[net] kod ", code)
	_say("KODUNU ARKADAŞINA GÖNDER YA DA ONUN KODUNU GİR")


func close() -> void:
	udp.close()
	lan.close()
	lan_peers.clear()
	_lan_bcast.clear()
	if _relay_dns >= 0:
		IP.erase_resolve_item(_relay_dns)
	_relay_dns = -1
	_relay = []
	_relay_on = false
	_relay_ok = false
	via_relay = false
	code = ""
	entered = false
	targets.clear()
	_resend.clear()
	_pending = {}
	connected = false
	paired = false
	racing = false
	want = false
	peer_want = false
	_got_init = false
	peer_ip = ""
	peer_token = ""
	_sess = ""
	_peer_sess = ""
	_peer_has_sess = false
	_sess_ok = false
	remote.car = ""
	peer_paused = false
	_seq = 0
	_seen.clear()
	_seen_floor = 0
	_rx_pause = 0
	ping_ms = 0.0
	silence = 0.0


# Arkadaşın kodu (8 rakam; paylaşılan mesajın tamamı da yapıştırılabilir): onun odasına sunucudan katılırız.
func set_peer(text: String) -> bool:
	var found := RegEx.create_from_string("(\\d{4})\\s*(\\d{4})").search(text)
	var c := found.get_string(1) + found.get_string(2) if found else ""
	if c == "":
		_say("KOD GEÇERSİZ · 8 RAKAM OLMALI")
		return false
	if c == code:
		_say("BU SENİN KODUN · ARKADAŞININKİNİ GİR")
		return false
	if connected:
		return true
	peer_token = c
	entered = true
	targets.clear()
	_relay_on = true
	_flip_t = 0.0
	_connect_t = 12.0
	_say("BAĞLANILIYOR…")
	return true


# Aynı Wi-Fi'da bulunan arkadaş: önce doğrudan, 3 sn'de olmazsa sunucudan da denenir.
func connect_lan(c: String) -> void:
	if not lan_peers.has(c) or not set_peer(c):
		return
	targets = [[lan_peers[c].ip, lan_peers[c].port]]
	_relay_on = false
	_relay_wait = 3.0


# Lobi ayarı: ikimizde ortak (son değiştiren geçer); değişince ikimiz de yeniden "hazırım" demeliyiz.
func set_lobby(key: String, val) -> void:
	lobby[key] = val
	want = false
	peer_want = false
	if paired:
		_reliable({"t": "cfg", "mode": lobby.mode, "bot": lobby.bot})
	changed.emit()


func set_want(on: bool) -> void:
	if not paired or racing:
		return
	want = on
	_reliable({"t": "want", "on": on})
	changed.emit()


# Yarışı başlatır: karşıya hemen, bize ping'in yarısı kadar sonra (go sinyali iki tarafta da).
func start(road: String, rg: int) -> void:
	if not paired or racing or not _pending.is_empty():
		return
	_pending = {"t": "go", "road": road, "rg": rg, "rid": randi() % 1000000, "mode": lobby.mode, "bot": lobby.bot}
	_reliable(_pending)
	_begin_t = ping_ms / 2000.0


# Yarışta her kare çağrılır, saniyede 20 kez gider. b: botu biz sürüyorsak [yol, x, km/sa].
func send_state(d: float, x: float, v: float, wreck: bool, sc: float, b: Array = [], nz := false, bn := false) -> void:
	if connected and _send_t <= 0.0:
		_send_t = 0.05
		# sabit ikili düzen, 22 bayt (botlu 30): sözlük olarak anahtar adlarıyla 220-290 bayttı. Alanlar: etiket,
		# karşının ve bizim anahtar, yol, x, hız, puan, bayraklar (kaza, nitro, bot nitrosu), botun yolu, x, hızı.
		var pk := PackedByteArray()
		pk.resize(30 if b.size() == 3 else 22)
		var keys := _keys()
		pk[0] = STATE_TAG
		pk.encode_u32(1, keys[0].hex_to_int())
		pk.encode_u32(5, keys[1].hex_to_int())
		pk.encode_float(9, d)
		pk.encode_half(13, x)
		pk.encode_half(15, v)
		pk.encode_float(17, sc)
		pk[21] = int(wreck) | int(nz) << 1 | int(bn) << 2
		if b.size() == 3:
			pk.encode_float(22, b[0])
			pk.encode_half(26, b[1])
			pk.encode_half(28, b[2])
		udp.set_dest_address(peer_ip, peer_port)
		udp.put_packet(pk)


# İkili durum paketi, sözlükteki "s" mesajının alanlarıyla: anahtar denetimi ve sınırlar ortak yoldan geçer.
func _unpack_state(pk: PackedByteArray) -> Dictionary:
	var f: int = pk[21]
	var m := {"fs": 1, "t": "s", "k": "%08x" % pk.decode_u32(1), "me": "%08x" % pk.decode_u32(5),
		"d": pk.decode_float(9), "x": pk.decode_half(13), "v": pk.decode_half(15), "sc": pk.decode_float(17),
		"w": (f & 1) != 0, "nz": (f & 2) != 0, "bn": (f & 4) != 0}
	if pk.size() == 30:
		m.merge({"bd": pk.decode_float(22), "bx": pk.decode_half(26), "bv": pk.decode_half(28)})
	return m


func send_pick(id: int) -> void:
	_reliable({"t": "pk", "id": id})


func send_final_score(sc: int) -> void:
	_reliable({"t": "fsc", "sc": sc})


func send_bot_final(ft: float) -> void:
	_reliable({"t": "bft", "ft": ft})


func send_bot_hit(kind: String) -> void:
	_reliable({"t": "bh", "kind": kind})


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
	_self_paused = on
	_reliable({"t": "pause" if on else "resume"})


# Bağlantı bitti. tell: karşıya "bye" (o da beklemeden kopmuş saysın; tek yönlü kopmada bizim delik açma
# paketlerimiz onu canlı tutuyordu).
func _drop(msg: String, tell := true) -> void:
	if tell and peer_ip != "":
		for i in 3:
			_send({"t": "bye"})
	_resend.clear() # yeniden bağlanınca eski bağlantının mesajları karşıda yeniden işlenmesin
	connected = false
	paired = false
	racing = false
	want = false
	peer_want = false
	_got_init = false
	_peer_sess = "" # yeniden tanışma koddaki anahtarla, yeni oturum anahtarı alınır
	_peer_has_sess = false
	_sess_ok = false
	_connect_t = 12.0 # yeniden bağlanma denenir; olmazsa 12 sn sonra sebebi söylenir
	if not entered:
		peer_token = "" # kodu biz verdiysek odamızda yeniden bekleriz (arkadaş yeniden katılır)
	_say(msg)


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
		if not _relay.is_empty() and ip == _relay[0] and prt == _relay[1] and pk.size() >= 4 \
				and pk.slice(0, 4).get_string_from_ascii() == RELAY_MAGIC:
			_relay_ok = true # katılma onayı (oyun paketleri sunucudan da gelir, onlar _recv'e)
		else:
			_recv(pk, ip, prt)
	if _relay_dns >= 0 and IP.get_resolve_item_status(_relay_dns) != IP.RESOLVER_STATUS_WAITING:
		if IP.get_resolve_item_status(_relay_dns) == IP.RESOLVER_STATUS_DONE and IP.get_resolve_item_address(_relay_dns) != "":
			_relay = [IP.get_resolve_item_address(_relay_dns), relay_port]
		IP.erase_resolve_item(_relay_dns)
		_relay_dns = -1
	if not connected and not targets.is_empty() and not _relay_on:
		_relay_wait -= dt
		if _relay_wait <= 0.0: # aynı Wi-Fi'da doğrudan olmadı: sunucudan da
			_relay_on = true
			_connect_t = maxf(_connect_t, 12.0)
	n = 0
	while lan.get_available_packet_count() > 0 and n < 64:
		n += 1
		var lpk := lan.get_packet()
		_lan_recv(lpk, lan.get_packet_ip())
	_lan_t -= dt
	if _lan_t <= 0.0:
		_lan_t = 1.0
		if code != "" and not connected:
			var pk := var_to_bytes({"fs": 1, "t": "lan", "code": code, "car": car, "port": port})
			for ip in _lan_bcast:
				lan.set_dest_address(ip, LAN_PORT)
				lan.put_packet(pk)
		for k in lan_peers.keys(): # 4 sn duyulmayan ağdan çıkmıştır
			if Time.get_ticks_msec() - lan_peers[k].t > 4000:
				lan_peers.erase(k)
				changed.emit()
	_send_t -= dt
	if not _pending.is_empty():
		_begin_t -= dt
		if _begin_t <= 0.0:
			_begin(_pending.road, _pending.rg, _pending.rid, _pending.mode, _pending.bot)
			_pending = {}
	if not connected and entered and (_relay_on or not targets.is_empty()):
		_flip_t += dt
		_connect_t -= dt
		if _connect_t <= 0.0:
			targets.clear()
			_relay_on = false
			if _relay.is_empty():
				_say("BAĞLANAMADI · SUNUCU BULUNAMADI, İNTERNETİNİ KONTROL ET")
			elif not _relay_ok:
				_say("BAĞLANAMADI · SUNUCUYA ULAŞILAMADI, İNTERNETİNİ KONTROL ET")
			else:
				_say("BAĞLANAMADI · KOD YANLIŞ YA DA ARKADAŞIN PANELİ KAPALI")
	if connected:
		silence += dt
		if silence > (30.0 if peer_paused else 5.0):
			_drop("BAĞLANTI KOPTU · KODLARI YENİDEN DEĞİŞİN")
		elif racing and _got_state and not peer_paused and not _self_paused:
			_state_quiet += dt
			if _state_quiet > 5.0:
				_drop("BAĞLANTI KOPTU")
		if racing and _me_ready and not _counted:
			_ready_wait += dt
			if _ready_wait > 15.0:
				_drop("ARKADAŞIN OYUNU AÇILMADI")
		_ping_t -= dt
		if _ping_t <= 0.0:
			_ping_t = 1.0
			_send({"t": "p", "ts": Time.get_ticks_msec()})
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.25
	for r in _resend: # onay ("ack") gelene kadar
		_send(r[0])
		r[1] -= 1
	_resend = _resend.filter(func(r): return r[1] > 0)
	if not connected:
		for t in targets: # aynı Wi-Fi: doğrudan
			_send({"t": "hi"}, t[0], t[1])
		# sunucu: kodu verdiysek kendi odamızda bekleriz (katılma canlı tutulur), girdiysek odasına "hi" atarız
		if not _relay.is_empty() and code != "" and (_relay_on or not entered):
			udp.set_dest_address(_relay[0], _relay[1])
			udp.put_packet((RELAY_MAGIC + _room()).to_ascii_buffer())
			if entered:
				_send({"t": "hi"}, _relay[0], _relay[1])
	elif not _got_init:
		_send_init()
	else:
		_send({"t": "hi"}) # bağlantı canlı kalsın: duraklatmada durum paketi gitmez, NAT eşlemesi de düşer


# Sunucudaki oda: bir kodun özeti (32 onaltılık). Kodu veren kendi kodunun odasında; giren arkadaşınkinde,
# 2 sn'de bir de iki kodun küçüğünün odasında (ikisi de birbirininkini girdiyse orada buluşurlar).
func _room() -> String:
	var c := code
	if entered:
		c = peer_token if int(_flip_t / 2.0) % 2 == 0 else mini_str(code, peer_token)
	return ("fs-" + c).sha256_text().substr(0, 32)


static func mini_str(a: String, b: String) -> String:
	return a if a < b else b


# [karşının anahtarı, bizimki]: karşının anahtarını bilmeyenin paketi atılır.
func _keys() -> PackedStringArray:
	var sess := _peer_has_sess and _peer_sess != ""
	return PackedStringArray([_peer_sess if sess else peer_token, _sess if sess else token])


func _send(m: Dictionary, ip := peer_ip, prt := peer_port) -> void:
	var out := m.duplicate()
	out["fs"] = 1
	var keys := _keys()
	out["k"] = keys[0]
	out["me"] = keys[1]
	udp.set_dest_address(ip, prt)
	udp.put_packet(var_to_bytes(out))


# Sıra numaralı mesaj: karşı her kopyasına "ack" döner, onaylanana kadar tekrar gider (önceden onaysız 3 kez
# gidiyordu: üçü de kaybolunca yarış başlangıcı ve bitişi zaman aşımına kalıyordu).
func _reliable(m: Dictionary) -> void:
	_seq += 1
	m["n"] = _seq
	_send(m)
	_resend.append([m, RESEND_TRIES])


func _send_init() -> void:
	_send({"t": "init", "v": PROTO, "car": car, "paint": paint, "rim": rim, "sk": _sess, "got": _got_init, "mode": lobby.mode, "bot": lobby.bot})


func _recv(pk: PackedByteArray, ip: String, prt: int) -> void:
	var m
	if (pk.size() == 22 or pk.size() == 30) and pk[0] == STATE_TAG:
		m = _unpack_state(pk)
	elif pk.size() >= 8 and pk.size() <= MAX_PACKET and (pk.decode_u32(0) & 0xFF) == TYPE_DICTIONARY:
		m = bytes_to_var(pk) # nesne çözülmez (bytes_to_var_with_objects değil)
	else:
		return
	if not (m is Dictionary) or m.get("fs") != 1 or not (m.get("k") is String) or not (m.get("me") is String):
		return
	var k: String = m.k
	var me: String = m.me
	var by_sess := connected and _sess != "" and _peer_sess != "" and k == _sess and me == _peer_sess
	var by_code := k == token and not _sess_ok and (me == peer_token if connected \
		else me.length() == 8 and (peer_token == "" or me == peer_token)) # kodunu yapıştırdığımız kişi
	if not (by_sess or by_code):
		return
	if by_sess:
		_sess_ok = true
		_peer_has_sess = true # bizim oturum anahtarımızla geldi: onu almış
	if connected:
		var from := "%s|%d" % [ip, prt]
		if ip == peer_ip and prt == peer_port:
			_roam_n = 0
		else: # adres değişti (NAT eşlemesi, IPv6 gizlilik adresi): art arda 3 paket gelirse geçilir
			_roam_n = _roam_n + 1 if from == _roam else 1
			_roam = from
			if _roam_n >= 3:
				peer_ip = ip
				peer_port = prt
				_roam_n = 0
				via_relay = not _relay.is_empty() and ip == _relay[0] and prt == _relay[1]
	else:
		connected = true
		peer_ip = ip
		peer_port = prt
		peer_token = me
		via_relay = not _relay.is_empty() and ip == _relay[0] and prt == _relay[1]
		_sess = "%08x" % randi()
		_peer_sess = ""
		_peer_has_sess = false
		_sess_ok = false
		_roam_n = 0
		# yeniden bağlanma: init yeniden alışılır; arkadaş uygulamayı yeniden açtıysa sıra numaraları sıfırdan
		_got_init = false
		paired = false
		want = false
		peer_want = false
		_seen.clear()
		_seen_floor = 0
		_rx_pause = 0
		_send_init()
		_say("BAĞLANDI · ARAÇ BİLGİSİ BEKLENİYOR…")
	silence = 0.0
	if m.has("n"): # birkaç kez gönderilen mesajın kopyası; pause/resume ayrıca sıralı (sonuncusu geçer)
		var seq := int(_num(m, "n"))
		# kopyası da onaylanır (önceki onay kaybolmuş olabilir). Alan "a": "n" olsaydı onay da sıralı mesaj sayılırdı.
		_send({"t": "ack", "a": seq})
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
			var sk := str(m.get("sk", ""))
			if sk.length() == 8:
				_peer_sess = sk
			if m.get("got") == true:
				_peer_has_sess = true # bizim init'imizi (oturum anahtarımızı) almış
			if not _got_init:
				_got_init = true
				remote.car = str(m.get("car", "")).left(32)
				remote.paint = int(_num(m, "paint")) # aralığı oyun denetler
				remote.rim = int(_num(m, "rim"))
				paired = m.get("v") == PROTO
				if peer_token < token: # lobi ayarı farklıysa anahtarı küçük olanınki geçer
					_take_lobby(m)
				_say("HAZIR · YARIŞI İKİNİZDEN BİRİ BAŞLATSIN" if paired else "SÜRÜMLER FARKLI · OYUNU GÜNCELLEYİN")
			if not m.get("got", true):
				_send_init() # bizimki ona ulaşmamış
		"ack":
			var n := int(_num(m, "a"))
			_resend = _resend.filter(func(r): return r[0].n != n)
		"p":
			_send({"t": "q", "ts": _num(m, "ts")})
		"q":
			var rtt := Time.get_ticks_msec() - _num(m, "ts")
			if rtt >= 0.0 and rtt < 5000.0:
				ping_ms = rtt if ping_ms == 0.0 else lerpf(ping_ms, rtt, 0.3)
				changed.emit()
		"go":
			# ikimiz aynı anda bastıysak anahtarı küçük olanınki geçer
			if paired and not racing and (_pending.is_empty() or peer_token < token):
				_pending = {}
				_begin(str(m.get("road", "two")), int(_num(m, "rg")), int(_num(m, "rid")), str(m.get("mode", "race")), m.get("bot") == true)
		"rdy":
			_peer_rid = int(_num(m, "rid")) # go'dan önce gelebilir (sıra karışırsa): saklanır
			_check_ready(true)
		"want":
			peer_want = m.get("on") == true
			changed.emit()
		"cfg":
			_take_lobby(m)
			want = false
			peer_want = false
			changed.emit()
		"pk":
			if racing:
				picked.emit(int(_num(m, "id")))
		"fsc":
			if racing:
				remote.fsc = maxi(int(_num(m, "sc")), 0)
		"bft":
			if racing:
				remote.bft = maxf(_num(m, "ft"), 0.0)
		"bh":
			if racing and m.get("kind") in ["front", "rear", "side"]:
				bot_hit.emit(m.kind)
		"bye":
			_drop("ARKADAŞIN BAĞLANTISI KOPTU", false)
			return
		"s":
			_got_state = true
			_state_quiet = 0.0
			var now := Time.get_ticks_msec()
			# geçen süre 1 sn'yle sınırlı: duraklatmada s gitmez, birikmiş süre büyük bir sıçramaya izin vermesin
			var lim: float = remote.d + MAX_MPS * minf(now - _s_ms, 1000.0) / 1000.0 + 30.0
			remote.d = clampf(_num(m, "d"), remote.d, lim) # paket sırası karışabilir, yol geri gitmez
			remote.x = clampf(_num(m, "x"), -12.0, 12.0)
			remote.v = clampf(_num(m, "v"), 0.0, 600.0)
			remote.w = m.get("w") == true
			remote.nz = m.get("nz") == true # arkadaşın nitrosu (alev)
			remote.bn = m.get("bn") == true
			# puan saniyede en çok ~5000 artabilir (yakın geçiş, kombo, nitro); geri gitmez
			remote.sc = clampf(_num(m, "sc"), remote.sc, remote.sc + 5000.0 * minf(now - _s_ms, 1000.0) / 1000.0 + 3000.0)
			if m.has("bd"):
				remote.bd = clampf(_num(m, "bd"), remote.bd, remote.bd + MAX_MPS * minf(now - _s_ms, 1000.0) / 1000.0 + 30.0)
				remote.bx = clampf(_num(m, "bx"), -12.0, 12.0)
				remote.bv = clampf(_num(m, "bv"), 0.0, 600.0)
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


# Düğmede ayırt etmek için: arkadaşın yerel ağ adresinin son hanesi ("(.85)"); araç adları aynı olabilir.
func lan_tag(c: String) -> String:
	return "(.%s)" % str(lan_peers[c].ip).get_slice(".", 3) if lan_peers.has(c) else ""


func _lan_recv(pk: PackedByteArray, ip: String) -> void:
	if pk.size() < 8 or pk.size() > MAX_PACKET or (pk.decode_u32(0) & 0xFF) != TYPE_DICTIONARY:
		return
	var m = bytes_to_var(pk)
	if not (m is Dictionary) or m.get("fs") != 1 or m.get("t") != "lan" or not (m.get("code") is String):
		return
	var c: String = m.code
	if c == code or not c.is_valid_int() or c.length() != 8 or not (m.get("port") is int):
		return
	var fresh := not lan_peers.has(c)
	lan_peers[c] = {"car": str(m.get("car", "")).left(32), "t": Time.get_ticks_msec(), "ip": ip, "port": clampi(m.port, 1, 65535)}
	if fresh:
		if OS.is_debug_build():
			print("[lan] bulundu: ", lan_peers[c].car)
		changed.emit()


func _num(m: Dictionary, k: String) -> float:
	var v = m.get(k, 0.0)
	if v is float:
		return v if is_finite(v) else 0.0 # NaN/sonsuz clampf'ten geçip konumu bozuyordu
	return float(v) if v is int else 0.0


func _take_lobby(m: Dictionary) -> void:
	lobby = {"mode": "score" if m.get("mode") == "score" else "race", "bot": m.get("bot") == true}


func _begin(road: String, rg: int, rid: int, md := "race", b := false) -> void:
	racing = true
	race_id = rid
	mode = "score" if md == "score" else "race"
	bot = b and mode == "race"
	remote.sc = 0.0
	remote.fsc = -1
	remote.bd = 0.0
	remote.bx = 0.0
	remote.bv = 0.0
	remote.bft = -1.0
	want = false
	peer_want = false
	_me_ready = false
	_counted = false
	_got_state = false
	_state_quiet = 0.0
	_self_paused = false
	_ready_wait = 0.0
	region = clampi(rg, 0, 3)
	remote.d = 0.0
	remote.v = 0.0
	remote.ft = -1.0
	remote.w = false
	remote.quit = false
	peer_paused = false
	_s_ms = Time.get_ticks_msec()
	go.emit("one" if road == "one" else "two", region)


# Aynı Wi-Fi yayın adresleri: genel ve her 192.168 ağının /24 yayını.
func _lan_setup() -> void:
	_lan_bcast.assign(["255.255.255.255"])
	for a in IP.get_local_addresses():
		var o := a.split(".")
		if o.size() == 4 and o[0] == "192" and o[1] == "168": # ev ağları /24; başka maskeli ağda a.b.c.255 sıradan bir cihaz olabilir
			_lan_bcast.append("%s.%s.%s.255" % [o[0], o[1], o[2]])


func _say(s: String) -> void:
	status = s
	changed.emit()
