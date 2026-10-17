# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends Node

# Online yarış: sunucusuz, iki cihaz arasında doğrudan UDP. Herkes dış adresini Google'ın ücretsiz STUN
# sunucusundan öğrenir; adresler "kod" olarak elle (WhatsApp vb.) değiş tokuş edilir, iki taraf aynı anda
# birbirine paket atarak NAT'ta delik açar (hole punching). Kod yerel ağ ve IPv6 adreslerini de taşır: aynı
# Wi-Fi'da ve IPv6'lı mobil veride NAT'a takılmadan bağlanır. Bağlantı sahne yenilense de sürer (autoload).
# İki taraf da simetrik NAT / CGNAT arkasındaysa doğrudan bağlantı kurulamaz: kod yapıştırıldıktan 4 sn sonra
# hâlâ bağlanılmadıysa ikisi de aktarma sunucusuna (tools/relay.py) aynı oda numarasıyla katılır, paketler oradan
# geçer. Sunucu paketin içini okumaz; doğrulama yine anahtarlarla.
# Aynı Wi-Fi: panel açıkken kod yerel ağa saniyede bir yayınlanır (LAN_PORT), arkadaş tek dokunuşla bağlanır;
# yayın yalnız bağlanana kadar sürer (o arada aynı ağdaki herkes kodu görebilir).
#
# Güvenlik: kodda rastgele bir anahtar var (yalnız tanışmada); bağlanınca iki taraf init ile yeni bir oturum
# anahtarı verir ve karşıdan oturum anahtarlı ilk paket gelince kod anahtarı artık kabul edilmez (Wi-Fi'da yayınlanan
# kodu gören araya giremez). Anahtarı tutmayan, büyük ya da sözlük olmayan paket atılır (nesne çözülmez). Karşının bildirdiği yol, araç hızının izin
# verdiğinden hızlı artamaz. ponytail: trafik şifreli değil; kodu ele geçiren yarışa girebilir (IP de içerir).
#
# Mesajlar: hi (delik açma, canlı tutma), init (bağlantı kurulunca iki taraf araç bilgisini verir),
# p/q (ping), cfg (lobi: mod ve bot, ikimizde ortak), want (yarışa hazırım: ikisi de hazırsa başlar), go (yarış
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

# İki ayrı sağlayıcı: NAT türü, iki farklı adrese giden paketin aynı dış portu alıp almadığıyla ölçülür
# (Google'ın stun1..4 adları da aynı IP'ye çıkıyor, ölçüm olmuyordu).
const STUN := [["stun.l.google.com", 19302], ["stun.cloudflare.com", 3478]]
const MAGIC := "FS1"
const PROTO := 2 # init'teki sürüm: farklıysa yarış başlatılamaz (2: ikili durum paketi, onaylı mesajlar)
const MAX_PACKET := 512
const STATE_TAG := 0xB5 # ikili durum paketinin ilk baytı (sözlük paketleri 0x1B ile başlar)
const RESEND_TRIES := 12 # onaylanmayan mesaj 0,25 sn arayla en çok bu kadar gider (3 sn)
const LAN_PORT := 47811
const RELAY_HOST := "" # aktarma sunucusunun adresi (alan adı ya da IP); boşsa sunucu kullanılmaz
const RELAY_PORT := 47812
const RELAY_MAGIC := "FSR1"
const MAX_MPS := 190.0 # karşının yolu saniyede en çok bu kadar artabilir (~680 km/sa, oyunda erişilmez)

var udp := PacketPeerUDP.new()
var lan := PacketPeerUDP.new() # aynı Wi-Fi keşfi (yayın)
var lan_peers := {} # aynı ağda yayın yapan kod -> {"car": araç, "t": son görülme ms}
var _lan_bcast: Array[String] = [] # yayın adresleri: genel ve her yerel ağın /24 yayını
var _lan_t := 0.0
var port := 0
var token := "" # bizim anahtarımız: karşı her pakette bunu yollar
var car := "" # bizim araç, boyası ve jantı: init'le gider, karşıda rakip modeli olur
var paint := 0
var rim := 0
var code := "" # bizim kod
var status := ""
var no_inet := false # ne dış IPv4 ne IPv6 adresi var: yalnız aynı ağ
var hard := false # iki STUN sunucusu farklı port gördü: simetrik NAT, dışarıdan bağlanmak zor
var peer_hard := false # arkadaşın kodu: onun NAT'ı zor (kodun 7. alanı "h")
var _spray: Array = [] # arkadaşın NAT'ı zorsa dış adresi [ip, port]: yakın portlara da paket gider
var _spray_i := 0 # her turda 32 port: -8..+120 aralığı 4 turda (1 sn) bir dolaşılır
var targets: Array = [] # karşının kodundaki adresler: [ip, port]
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
var _stun_ips := {} # STUN sunucusu IP -> portu
var _dns: Array = [] # çözülmekte olan STUN adları (bloklamadan, IP kuyruğunda): [kuyruk no, port]
var _mapped := {} # STUN sunucusu -> onun gördüğü [ip, port]
var _code_t := 0.0 # kod en geç 3 sn'de çıkar (STUN yanıt vermese de yerel / IPv6 adresle)
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
var _relay_wait := 0.0 # kod yapıştırıldı: bu kadar sn sonra hâlâ bağlanılmadıysa sunucuya geçilir
var _relay_on := false
var _relay_ok := false # sunucu katılmayı onayladı
var _connect_t := 0.0 # kod yapıştırıldı: bu kadar sn içinde bağlanamazsak delik açma durur, nedeni söylenir
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
	token = "%08x" % randi()
	lan.set_broadcast_enabled(true) # Android'de çoklu yayın kilidini de alır (change_wifi_multicast_state izni)
	if lan.bind(LAN_PORT, "0.0.0.0") != OK: # aynı cihazda ikinci oyun: yalnız yayınlar, dinleyemez
		lan.bind(0, "0.0.0.0")
	for h in STUN:
		_dns.append([IP.resolve_hostname_queue_item(h[0], IP.TYPE_IPV4), h[1]])
	if relay_host != "":
		_relay_dns = IP.resolve_hostname_queue_item(relay_host, IP.TYPE_IPV4)
	_code_t = 3.0
	_say("ADRESİN BULUNUYOR…")


func close() -> void:
	udp.close()
	lan.close()
	lan_peers.clear()
	_lan_bcast.clear()
	for d in _dns:
		IP.erase_resolve_item(d[0])
	_dns.clear()
	if _relay_dns >= 0:
		IP.erase_resolve_item(_relay_dns)
	_relay_dns = -1
	_relay = []
	_relay_on = false
	_relay_ok = false
	via_relay = false
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
	peer_hard = false
	_spray = []
	ping_ms = 0.0
	silence = 0.0


# Arkadaşın kodu: içindeki adreslere delik açma paketi gider. Kod geçersizse false.
func set_peer(text: String) -> bool:
	# paylaşılan mesajın tamamı yapıştırılabilir ("... yarış kodum: <kod>"): kod "FS1|" ile başlar, base64'ü "RlMx"
	var found := RegEx.create_from_string("RlMx[A-Za-z0-9+/=]+").search(text)
	text = found.get_string() if found else text.strip_edges()
	if text == code:
		_say("BU SENİN KODUN · ARKADAŞININKİNİ YAPIŞTIR")
		return false
	var f := Marshalls.base64_to_utf8(text).split("|") if text.length() > 8 and text.length() < 400 else PackedStringArray()
	if f.size() not in [6, 7] or f[0] != MAGIC or f[5].length() != 8: # 7. alan (NAT türü) eski kodlarda yok
		_say("KOD GEÇERSİZ")
		return false
	if connected:
		return true
	targets.clear()
	var p := int(f[4])
	peer_hard = f.size() == 7 and f[6] == "h"
	_spray = []
	if f[1] != "":
		var hp := f[1].rsplit(":", true, 1)
		targets.append([hp[0], int(hp[1])])
		if peer_hard:
			_spray = [hp[0], int(hp[1])]
	for a in f[2].split(",", false) + f[3].split(",", false):
		targets.append([a, p])
	targets = targets.slice(0, 6) # bizim kodumuzda en çok 6 adres: fazlası yabancı adrese paket attırmasın
	peer_token = f[5]
	_connect_t = 10.0
	_relay_wait = 4.0
	_say("BAĞLANILIYOR… ARKADAŞIN DA SENİN KODUNU YAPIŞTIRSIN" + (" (AĞI ZOR, DENENİYOR)" if peer_hard else ""))
	return true


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
	_connect_t = 10.0 # elimizdeki adreslere yeniden delik açılır; olmazsa 10 sn sonra sebebi söylenir
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
		if _stun_ips.get(ip, -1) == prt:
			_stun_reply(pk, ip)
		elif not _relay.is_empty() and ip == _relay[0] and prt == _relay[1] and pk.size() >= 4 \
				and pk.slice(0, 4).get_string_from_ascii() == RELAY_MAGIC:
			_relay_ok = true # katılma onayı (oyun paketleri sunucudan da gelir, onlar _recv'e)
		else:
			_recv(pk, ip, prt)
	for d in _dns.duplicate():
		var st := IP.get_resolve_item_status(d[0])
		if st == IP.RESOLVER_STATUS_WAITING:
			continue
		if st == IP.RESOLVER_STATUS_DONE and IP.get_resolve_item_address(d[0]) != "":
			_stun_ips[IP.get_resolve_item_address(d[0])] = d[1]
		IP.erase_resolve_item(d[0])
		_dns.erase(d)
	if _relay_dns >= 0 and IP.get_resolve_item_status(_relay_dns) != IP.RESOLVER_STATUS_WAITING:
		if IP.get_resolve_item_status(_relay_dns) == IP.RESOLVER_STATUS_DONE and IP.get_resolve_item_address(_relay_dns) != "":
			_relay = [IP.get_resolve_item_address(_relay_dns), relay_port]
		IP.erase_resolve_item(_relay_dns)
		_relay_dns = -1
	if not connected and not targets.is_empty() and not _relay.is_empty() and not _relay_on:
		_relay_wait -= dt
		if _relay_wait <= 0.0: # doğrudan olmadı: sunucuya katıl (arkadaş da 4 sn sonra katılır)
			_relay_on = true
			_connect_t = maxf(_connect_t, 12.0)
			_say("BAĞLANILIYOR… SUNUCU ÜZERİNDEN DENENİYOR")
	n = 0
	while lan.get_available_packet_count() > 0 and n < 64:
		n += 1
		_lan_recv(lan.get_packet())
	_lan_t -= dt
	if _lan_t <= 0.0:
		_lan_t = 1.0
		if code != "" and not connected:
			var pk := var_to_bytes({"fs": 1, "t": "lan", "code": code, "car": car})
			for ip in _lan_bcast:
				lan.set_dest_address(ip, LAN_PORT)
				lan.put_packet(pk)
		for k in lan_peers.keys(): # 4 sn duyulmayan ağdan çıkmıştır
			if Time.get_ticks_msec() - lan_peers[k].t > 4000:
				lan_peers.erase(k)
				changed.emit()
	_send_t -= dt
	if code == "":
		_code_t -= dt
		if _mapped.size() >= 2 or (_mapped.size() == 1 and _code_t < 1.5) or _code_t <= 0.0:
			_make_code()
	if not _pending.is_empty():
		_begin_t -= dt
		if _begin_t <= 0.0:
			_begin(_pending.road, _pending.rg, _pending.rid, _pending.mode, _pending.bot)
			_pending = {}
	if not connected and not targets.is_empty():
		_connect_t -= dt
		if _connect_t <= 0.0:
			targets.clear()
			_spray = []
			if _relay_on and not _relay_ok:
				_say("BAĞLANAMADI · SUNUCUYA ULAŞILAMADI, İNTERNETİNİ KONTROL ET")
			elif _relay_on:
				_say("BAĞLANAMADI · ARKADAŞIN SUNUCUYA GELMEDİ, İKİNİZ DE KODU YAPIŞTIRIN")
			elif no_inet:
				_say("BAĞLANAMADI · İNTERNET ADRESİN BULUNAMADI, AYNI WI-FI'DA DENEYİN")
			elif hard and peer_hard:
				_say("BAĞLANAMADI · İKİNİZİN AĞI DA DIŞARIDAN BAĞLANTIYA KAPALI, BİRİNİZ BAŞKA AĞ DENESİN")
			elif hard:
				_say("BAĞLANAMADI · SENİN AĞIN DIŞARIDAN BAĞLANTIYA KAPALI, BAŞKA AĞ DENE")
			elif peer_hard:
				_say("BAĞLANAMADI · ARKADAŞININ AĞI DIŞARIDAN BAĞLANTIYA KAPALI, O BAŞKA AĞ DENESİN")
			else:
				_say("BAĞLANAMADI · İKİNİZ DE BİRBİRİNİZİN KODUNU YAPIŞTIRIN, SONRA TEKRAR DENEYİN")
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
	if code == "": # yanıt gelene kadar tekrar sor
		for ip in _stun_ips:
			udp.set_dest_address(ip, _stun_ips[ip])
			udp.put_packet(_stun_request())
	for r in _resend: # onay ("ack") gelene kadar
		_send(r[0])
		r[1] -= 1
	_resend = _resend.filter(func(r): return r[1] > 0)
	if not connected:
		for t in targets: # delik açma: karşı da bize atınca iki NAT'ta da yol açılır
			_send({"t": "hi"}, t[0], t[1])
		# arkadaşın NAT'ı her hedefe yeni port açıyor: bize açacağı port kodundakinin (en son gördüğü) biraz
		# ilerisinde olur, çoğu modem portları sırayla verir (kod gittikten sonra evdeki başka cihazlar da sayacı ilerletir)
		if _relay_on: # sunucuya katıl (onay gelene kadar ve sonra da canlı tut), delik açma paketi oradan da gider
			udp.set_dest_address(_relay[0], _relay[1])
			udp.put_packet((RELAY_MAGIC + _room()).to_ascii_buffer())
			_send({"t": "hi"}, _relay[0], _relay[1])
		if not _spray.is_empty() and not hard: # biz de zorsak her paket modemde yeni port açar, tahmini bozar
			for k in 32:
				var pp: int = _spray[1] - 8 + (_spray_i * 32 + k) % 128
				if pp != _spray[1] and pp > 1024 and pp < 65536:
					_send({"t": "hi"}, _spray[0], pp)
			_spray_i += 1
	elif not _got_init:
		_send_init()
	else:
		_send({"t": "hi"}) # bağlantı canlı kalsın: duraklatmada durum paketi gitmez, NAT eşlemesi de düşer


# Oda numarası: iki kod anahtarından, iki tarafta aynı (sıralı), dışarıdan tahmin edilemez.
func _room() -> String:
	return (mini_str(token, peer_token) + maxi_str(token, peer_token)).sha256_text().substr(0, 32)


static func mini_str(a: String, b: String) -> String:
	return a if a < b else b


static func maxi_str(a: String, b: String) -> String:
	return b if a < b else a


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


# Düğmede ayırt etmek için: kodun ilk yerel ağ adresinin son hanesi ("(.85)"); araç adları aynı olabilir.
func lan_tag(c: String) -> String:
	var f := Marshalls.base64_to_utf8(c).split("|")
	if f.size() == 6 and f[2] != "":
		return "(.%s)" % f[2].split(",")[0].get_slice(".", 3)
	return ""


func _lan_recv(pk: PackedByteArray) -> void:
	if pk.size() < 8 or pk.size() > MAX_PACKET or (pk.decode_u32(0) & 0xFF) != TYPE_DICTIONARY:
		return
	var m = bytes_to_var(pk)
	if not (m is Dictionary) or m.get("fs") != 1 or m.get("t") != "lan" or not (m.get("code") is String):
		return
	var c: String = m.code
	if c == code or c.length() > 400:
		return
	var fresh := not lan_peers.has(c)
	lan_peers[c] = {"car": str(m.get("car", "")).left(32), "t": Time.get_ticks_msec()}
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


func _make_code() -> void:
	var seen: Array = _mapped.values()
	var pub := ""
	if not seen.is_empty(): # zor NAT'ta en büyük port: bir sonraki hedefe verilecek olan onun hemen ardından
		pub = "%s:%d" % [seen[0][0], seen.map(func(m): return m[1]).max()]
	var lans := PackedStringArray()
	var v6 := PackedStringArray()
	for a in IP.get_local_addresses():
		var o := a.split(".")
		if a.contains(":"):
			if (a.begins_with("2") or a.begins_with("3")) and not a.contains("%"): # yalnız internet adresi (2000::/3)
				v6.append(a)
		elif o[0] == "10" or (o[0] == "192" and o[1] == "168") or (o[0] == "172" and int(o[1]) >= 16 and int(o[1]) <= 31):
			lans.append(a)
	_lan_bcast.assign(["255.255.255.255"])
	for a in lans:
		var o := a.split(".")
		if o[0] == "192" and o[1] == "168": # ev ağları /24; başka maskeli ağda a.b.c.255 sıradan bir cihaz olabilir
			_lan_bcast.append("%s.%s.%s.255" % [o[0], o[1], o[2]])
	hard = seen.size() >= 2 and seen[0][1] != seen[1][1]
	var nat := "h" if hard else ("e" if seen.size() >= 2 else "?") # NAT türü: zor / kolay / bilinmiyor
	code = Marshalls.utf8_to_base64("%s|%s|%s|%s|%d|%s|%s" % [MAGIC, pub, ",".join(lans.slice(0, 3)), ",".join(v6.slice(0, 2)), port, token, nat])
	if OS.is_debug_build():
		print("[net] kod ", code, " ", Marshalls.base64_to_utf8(code), " stun: ", seen)
	no_inet = pub == "" and v6.is_empty()
	if no_inet:
		_say("İNTERNET ADRESİ BULUNAMADI · YALNIZ AYNI WI-FI")
	elif hard:
		_say("KODUNU ARKADAŞINA GÖNDER · AĞIN ZOR, BAĞLANTI UZUN SÜREBİLİR")
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
