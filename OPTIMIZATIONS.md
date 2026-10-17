# ForeverSpeed: Optimizasyon Denetimi

Tarih: 2026-10-18. Taban: `7b3a403` ve commit edilmemiş değişiklikler (`main.gd`, `net.gd`, `ui.gd` vb.).
Bu belge yalnız bulgu ve öneri içerir; koda dokunulmadı.

Kapsam: `main.gd`, `ui.gd`, `net.gd`, `profile.gd`, `regions.gd`, `pack.gd`, `build.gd`, bütün shader'lar,
`tools/relay.py`, import ayarları, `export_presets.cfg`, son APK (`build/ForeverSpeed.apk`, 104,6 MB) ve web çıktısı.
`addons/godot_mcp` üçüncü taraf eklenti: içi denetlenmedi, yalnız oyuna etkisi incelendi.

Satır numaraları denetim anındaki dosyadan alındı. `main.gd` denetim sırasında başka bir oturumda da düzenleniyordu;
satırlar kaymış olabilir, fonksiyon adı esas alınsın.

## Uygulama durumu (2026-10-18)

Bulgular uygulandı; aşağıdaki "sonra" sayıları aynı makinede, aynı betiklerle ölçüldü.

| Bulgu | Durum | Ne yapıldı | Ölçülen sonuç |
|---|---|---|---|
| B1 | Yapıldı | 75 araba dokusu `compress/mode=2`; normal map olan 4 dokuda `normal_map=1`; yeniden import | Bütün araçlar yüklüyken doku belleği 367,1 → 63,8 MB, video belleği 404,6 → 92,4 MB (pencereli) |
| B2 | Yapıldı | `pack.gd`: `_load_pack` / `_load_single` (istenince), `preload_async`; garaj komşu araçları arka planda okur (`ui.preload_near`) | Açılışta gereken yükleme 1058 → 82 ms (headless), 1808 → 190 ms (pencereli); doku 53,5 MB |
| B3 | Yapıldı | `apply_paint`; `set_player_car` araç + jant + modifiye aynıysa yalnız boyar (`build_key`) | Boya dokunuşunda model, `get_faces` ve parçacıklar yeniden kurulmuyor |
| B4 | Kısmen | `hood_cache` ve `rim_meshes` statik; `[perf] hazırlık=… yenileme=…` logu | Masaüstü sahne kurulumu ≈0,7 s (pencereli, ilk açılış). Sahne yenilemesiz yeniden başlatma yapılmadı: tablet ölçümü gerekçe vermeden 150+ durum değişkenini sıfırlamak riskli |
| B5 | Kısmen | `by_lane` şerit listeleri (`place`, `set_lane`, `drop_traffic` ile güncel), `lane_blocker` yalnız kendi şeridini tarar, `wall_count` yerine erken duran `walled` | 20/30/40 araç: 70 → 42, 161 → 92, 258 → 139 µs (%40-46). Tipli `TrafficCar` sınıfı yapılmadı: bütün `get_meta` çağrılarını değiştiren geniş bir değişiklik, kazanç bu ölçümden sonra küçük |
| B6 | Kısmen | Kenney trafiği `car_in.gdshader` (arka yüz çizilmez) | Önce/sonra render farkı en çok 0,18 piksel. Paket araçlarında yapılmadı: camdan bakınca iç paneller kayboluyor, aracın içinden arka plan görünüyor (minivan, polis; piksel karşılaştırmasıyla bulundu) |
| B7 | Yapıldı | e30'un 7 eski dokusu silindi; cop/phoenix'in 5 kullanılmayan dokusu GLB'de gömülü olduğu için import'ta yeniden çıkıyor, export filtresiyle dışlandı; `build/.gdignore`; `icon.png` 512²; MCP eklentisinin editör dosyaları export'tan dışlandı; hata ayıklayıcı yoksa `MCPRuntimeProbe` kapatılıyor (`main._ready`) | APK'da eklenti 0,55 → 0,04 MB |
| B8 | Yapıldı | `.tmp` + `rename_absolute`; açılışta `.tmp` yedeği | Ayrı projede yarım yazılmış kayıt senaryosu geçti |
| B9 | Yapıldı | Odası olmayan adres yalnız geçerli katılma paketiyle kayıt açar; `MAX_RATES` | 200 bin sahte kaynakta 0 kayıt; `tools/test_relay.gd` TEST OK |
| B10 | Yapıldı | Yarış durumu sabit ikili paket (22/30 bayt, `STATE_TAG`), `PROTO = 2`; `_num` NaN/sonsuzu reddeder | Paket 220/288 → 22/30 bayt (%90) |
| B11 | Yapıldı | `ack` (alan `a`), `RESEND_TRIES = 12`, kopmada kuyruk temizlenir | `tools/test_net.gd` TEST OK (onay, ikili paket, NaN denetimleri eklendi) |
| B12 | Yapıldı | `timer_label` rengi yalnız eşikte; dört StyleBox bir kez kuruluyor | |
| B13 | Kısmen | `Build.streak` malzeme önbelleği; `add_glow` boya göre tek QuadMesh | Trafik mesh birleştirme yapılmadı: birleşen meshte import'un LOD'ları kayboluyor; uzaktaki trafikte üçgen artışı birkaç çizim çağrısı kazancından ağır |
| B14 | Yapıldı | `create_shadow_meshes=false` (hepsi), `ensure_tangents=false` (normal map olmayanlar) | APK'da `.scn` 17,38 → 10,91 MB |
| B15 | Yapıldı | `set_road(StringName)` + `&"..."`; `stats.loose`; global uniform yalnız değişince; `update_curve` kopya dizi ve `in` araması olmadan (`bend`) | |
| B16 | Yapıldı | `field_split`, `field_s0`, `field_range` (ikili arama); `update_field`, `field_busy`, `field_ahead` yalnız pencereyi tarar | Eski kaba taramayla 3000 rastgele denemede 0 fark |
| B17 | Yapılmadı | Release anahtarı ve tablette ölçüm gerektiriyor | |

APK (debug): 104,6 → 106,7 MB. ETC2 dokuları sabit boyutlu, kayıpsız PNG'nin iyi sıkıştırdığı düz renkli dokularda
diskte daha büyük; bellek kazancının karşılığı. Disk boyutu da düşmeli derse sıradaki adım Basis Universal
(`compress/mode=3`): diskte küçük, yüklemede ETC2/ASTC'ye çevrilir; kalite ve yükleme süresi ölçülmeli.

Ölçülmeyenler: tablet (SM-X210) üstünde hiçbir şey ölçülmedi; çizim çağrısı etkisi (B13) ayrıca ölçülmedi.

## Ölçüm notu

Aşağıdaki sayıların bir kısmı bu denetimde ölçüldü, bir kısmı tahmin. Her bulguda hangisi olduğu yazıyor.

| Ölçüm | Sonuç | Nasıl |
|---|---|---|
| `Pack._load()` süresi | **991 ms** | masaüstü (i5-14500HX), `godot-mono --headless --script`, soğuk değil |
| `Pack._load()` sonrası statik bellek | **364 MB** | `Performance.MEMORY_STATIC`, aynı koşu |
| `mesh.get_faces()` (hood_height eşdeğeri) | sf90 12,2 ms, gtr 16,6 ms, e30 0,5 ms | aynı koşu |
| Trafik komşu sorguları (yalnız `lane_blocker` + `wall_count` + `wall_right`) | 20 araç 71 µs, 30 araç 161 µs, 40 araç 255 µs / kare | aynı koşu, 300 kare ortalaması |
| Online durum paketi (`var_to_bytes`) | 220 B, botlu 288 B | aynı koşu |
| Kayıpsız import edilmiş araba dokusu | 87 dokudan 85'i (`compress/mode=0`) | `.import` dosyaları |
| Dokuların bellekte kapladığı yer (tahmin) | ≈381 MB RGBA8 + mipmap; VRAM sıkıştırmalı ≈95 MB | görüntü boyutlarından hesap |
| APK'da oyunla ilgisiz ya da kullanılmayan dosya | ≈8,5 MB | APK zip listesi |

Tabletteki (SM-X210, Adreno 619) karşılıkları ölçülmedi. Mobil CPU'da GDScript genelde masaüstünden 3-5 kat yavaş
çalışır; tablet rakamları bu yüzden "olası" diye işaretli.

---

## 1) Optimizasyon Özeti

Oyun döngüsü genel olarak bilinçli yazılmış: sabit havuzlar, MultiMesh, uniform dallı shader'lar, 20 m'lik yol
parçaları, dinamik çözünürlük ve cihaz üstü `bench` aracı zaten var. Kare başı CPU'da büyük bir yangın yok.
Asıl sorunlar **varlık hattında** (doku import ayarı, hepsini birden yükleme) ve **yeniden kurma maliyetinde**
(her yeniden başlatmada sahnenin baştan kurulması, garajda her boya dokunuşunda aracın yeniden kurulması).

En yüksek etkili üç iyileştirme:

1. **Araba dokularını VRAM sıkıştırmalı import et.** 85 doku kayıpsız. Bellekte ≈381 MB yerine ≈95 MB
   (tahmin). Açılışta PNG çözme de kalkar.
2. **`Pack._load()`'u tembel yap.** Şu an trafikte hiç çıkmayan 8 oyuncu aracı dahil 11 GLB açılışta yükleniyor
   (masaüstünde 991 ms, 364 MB). Trafiğe gereken paket, e30 ve polis yeter.
3. **Yeniden kurmayı azalt.** Garajda boya ya da jant seçimi bütün aracı yeniden kuruyor
   (`get_faces` dahil); yeniden başlatma bütün sahneyi kuruyor. Kaput yüksekliğini önbelleğe al, boyayı ayrı yoldan
   uygula.

Hiçbir şey yapılmazsa en büyük risk: düşük RAM'li Android cihazda ve iPhone Safari'deki web sürümünde
**bellek yüzünden çökme ya da sistemin uygulamayı öldürmesi**. Doku belleği tek başına yüzlerce MB. Açılış da
tablette büyük olasılıkla birkaç saniye sürüyor.

---

## 2) Bulgular (önceliğe göre)

### B1. Araba dokuları kayıpsız import edilmiş: bellekte sıkıştırmasız duruyor

- **Kategori:** Memory / I/O
- **Önem:** Kritik
- **Etki:** RAM ve VRAM, açılış süresi, web sürümünde çökme riski
- **Kanıt:** `cars/**` altındaki 87 doku `.import` dosyasından 85'inde `compress/mode=0` (Lossless),
  `detect_3d/compress_to=1`. Yalnız `cars/r34_0.png` ve `cars/kenney/Textures/colormap.png` `mode=2`.
  Örnek: `cars/pack/car_pack_6.jpg.import`, `cars/e30/e30_Image_0.png.import`. Dokuların çoğu 1024×1024.
  Klasör başına tahmini bellek (RGBA8 + mipmap): pack 208 MB, cop 60, phoenix 55, e30 37, challenger 11,
  wreck 5, gtr 5. Ölçülen: `Pack._load()` sonrası statik bellek 364 MB.
- **Neden verimsiz:** Kayıpsız doku GPU'ya açılmış RGBA8 olarak gider: 1024² için mipmap'le ≈5,3 MB.
  ETC2/ASTC aynı doku için ≈1,3 MB (RGB JPEG'lerde ≈0,7 MB). Ayrıca her açılışta PNG/WebP çözülür, bu CPU işidir.
  "Detect 3D" bu dokular için tetiklenmemiş; büyük olasılıkla dokular yalnız koddan kurulan sahnede kullanıldığı için.
- **Önerilen düzeltme:** `cars/**` altındaki bütün doku `.import` dosyalarında `compress/mode=2` (VRAM Compressed),
  sonra yeniden import. Editörde FileSystem'de çoklu seçim, Import paneli, "Reimport" ile yapılabilir. Komut satırı:
  bölüm 6'da. Yalnız trafikte görünen paket araçları için `process/size_limit=512` da düşünülebilir.
  `tools/prep_car.py` başındaki talimata "dokular VRAM Compressed olmalı" notu eklenmeli; yeni araç aynı tuzağa düşmesin.
- **Ödünleşim / risk:** ETC2/ASTC hafif blok bozulması yapar. Oyun ölçeğinde ve gece sahnesinde fark edilmesi zor.
  Garajdaki yakın çekimde gövde dokusu kontrol edilmeli. APK boyutu bu yüzden belirgin küçülmeyebilir: `.ctex` dosyaları
  APK'da sıkıştırmasız saklanıyor, VRAM formatı da diskte kayıpsız PNG'den küçük olmayabilir.
- **Beklenen etki:** Doku belleği ≈%75 düşer (≈381 → ≈95 MB, tahmin). Açılışta doku çözme süresi büyük ölçüde kalkar.
- **Kaldırma güvenliği:** Güvenli (yalnız import ayarı; görsel kontrol gerekli)
- **Yeniden kullanım kapsamı:** Proje geneli (varlık hattı)

### B2. `Pack._load()` bütün araçları açılışta yüklüyor

- **Kategori:** Memory / I/O / CPU
- **Önem:** Yüksek
- **Etki:** Açılış süresi, kalıcı bellek
- **Kanıt:** `pack.gd:56` `_load()`: `car_pack.glb` ve `SINGLES` listesindeki 10 GLB'nin hepsini instantiate eder,
  gövde ve tekerlek meshlerinin `get_faces()`'ini dolaşır (`pack.gd:127`), sonuçları `static var _cars` içinde süreç
  boyunca tutar. İlk çağrı `main.gd:380` `Pack.names()` ile `_ready` içinde olur. Trafik `names()` ile yalnız paket
  araçlarını ve `e30`'u kullanır. Polis `cop`'u kullanır. `phoenix`, `challenger`, `m4`, `gtr`, `m5`, `sf90`, `civic`,
  `doblo` yalnız oyuncu, rakip ya da bot olarak seçilince gerekir. Ölçülen: masaüstünde 991 ms, 364 MB.
- **Neden verimsiz:** Kullanılmayacak 8 aracın meshi ve dokusu (≈75 MB doku, tahmin) her oturumda yüklenip bellekte kalır.
- **Önerilen düzeltme:** `_load()`'u ikiye böl: `_load_pack()` (paket, `names()` için) ve `_load_single(nm)`
  (`info(nm)` ilk istendiğinde). `names()` yalnız paketi ve e30'u yükler. Garaj açılınca seçili aracın komşularını
  `ResourceLoader.load_threaded_request` ile önden yükle; ok tuşunda takılma olmasın. Taslak: bölüm 6.
- **Ödünleşim / risk:** Garajda ilk kez açılan araçta kısa yükleme. Threaded ön yükleme bunu gizler.
  Online yarışta rakibin aracı yarış başında yüklenir; zaten siyah perde ve geri sayım var.
- **Beklenen etki:** Pack yükleme süresi ve kalıcı bellekte tahminen %30-50 düşüş (B1 ile birlikte çok daha fazla).
  Kesin pay tablette ölçülmeli.
- **Kaldırma güvenliği:** Büyük olasılıkla güvenli
- **Yeniden kullanım kapsamı:** Modül (`pack.gd`)

### B3. Garajda boya ve jant seçimi bütün aracı yeniden kuruyor

- **Kategori:** CPU / Memory (allocation churn)
- **Önem:** Orta
- **Etki:** Garaj dokunuş gecikmesi, çöp üretimi
- **Kanıt:** `ui.gd:1449` `pick_paint` ve `ui.gd:1455` `pick_rim` → `preview()` (`ui.gd:1439`) →
  `main.set_player_car` (`main.gd:3921`): eski aracı `queue_free` eder, `make_player` ile yeniden kurar.
  `make_player` (`main.gd:3935`) her seferinde: `Pack.build`, `apply_rims`, `cull_swaps` (malzeme kopyaları),
  `hood_height` (`main.gd:4422`, bütün meshlerin `get_faces()`'i: sf90'da 143 bin köşe, masaüstünde 12 ms),
  iki egzoz alevi, `GPUParticles3D` su sisi, `SpotLight3D`, `OmniLight3D`.
- **Neden verimsiz:** Boya yalnız `player_mat` uniform'larını değiştirir (`use_paint`, `paint`, `finish`, `paint2`;
  `main.gd:3985` civarı). Model ve ölçüler aynı kalır.
- **Önerilen düzeltme:** `make_player` içindeki boya bloğunu `apply_paint(mat, paint_index)` olarak çıkar.
  `preview()` araç ve jant değişmediyse yalnız onu çağırsın. Jant değişiminde de yalnız tekerlekler yeniden kurulabilir,
  ama önce boya yolu yeter. Kaput yüksekliği için B4.
- **Ödünleşim / risk:** Düşük. `make_player` rakip ve bot için de çağrılıyor; çıkarılan fonksiyon ikisine de uyar.
- **Beklenen etki:** Boya dokunuşu masaüstünde ~15 ms'den 1 ms'nin altına; tablette olası 50-150 ms takılma kalkar.
- **Kaldırma güvenliği:** Büyük olasılıkla güvenli
- **Yeniden kullanım kapsamı:** Yerel dosya; Yeniden kullanım fırsatı

### B4. Her yeniden başlatmada sahnenin tamamı baştan kuruluyor

- **Kategori:** CPU / Memory
- **Önem:** Orta (tablette ölçülmeli; yüksek çıkabilir)
- **Etki:** "TEKRAR", menüye dönüş ve online yarış başlangıcı gecikmesi
- **Kanıt:** `restart()` (`main.gd:768`), `to_menu()` (`main.gd:776`) ve `ui.on_go()` (`ui.gd:742`)
  `reload_current_scene()` çağırır. `_ready` (`main.gd:327`) her seferinde: 38 trafik aracı (her biri `Pack.build`
  ya da Kenney instantiate, `dress_car` ile 6 ek düğüm), 3 polis/siren seti, kepçeler, tünel, 9 çevre parçası,
  1.700 satırlık arayüz, `rim_meshes` (örnek değişkeni olduğu için her sahnede yeniden `SurfaceTool` birleştirmesi),
  oyuncu aracı için `hood_height` (`get_faces`), online yarışta rakip ve bot için de, sonra 4 karelik ısınma.
  Statik önbellekler (`Pack._cars`, `Regions._m`, `load()` önbelleği) korunuyor, ama instantiate ve script işi her seferinde tekrar.
- **Neden verimsiz:** Oyunlar arasında değişmeyen yapılar tekrar tekrar kurulup atılıyor.
- **Önerilen düzeltme (kademeli):**
  1. Kolay: kaput yüksekliğini araç kimliğine göre `static var` sözlükte tut (taslak bölüm 6).
     `rim_meshes`'i `static var` yap. İkisi de saf hesap, sahneye bağlı değil.
  2. Orta: önce ölç. `restart()` anında `Time.get_ticks_msec()` değerini `Profile`'a yaz, yeni sahnenin ilk
     `_process`'inde farkı logla.
  3. Büyük: sahneyi yenilemek yerine oyun durumunu sıfırlayan bir `reset_run()`. `main.gd`'de 150'yi aşkın durum
     değişkeni olduğu için hata riski yüksek; ancak ölçüm gerekçe verirse.
- **Ödünleşim / risk:** 1. adım güvenli. 3. adım "eski durum sızdı" hatalarına açık; online akış (`Net.racing`,
  tohumlama) sahne yenilemeye dayanıyor.
- **Beklenen etki:** 1. adım tabletteki yeniden başlatmadan olası 50-200 ms siler (tahmin). 3. adımın etkisi ölçümle belli olur.
- **Kaldırma güvenliği:** 1. adım güvenli; 3. adım doğrulama gerekir
- **Yeniden kullanım kapsamı:** Modül

### B5. Trafik döngüsünde O(n²) komşu sorguları ve yoğun `get_meta`

- **Kategori:** Algorithm / CPU
- **Önem:** Orta
- **Etki:** Kare başı CPU (özellikle online'da 38 araçlık havuz)
- **Kanıt:** `update_traffic` (`main.gd:1215`) her bizim yön aracı için `lane_blocker` (`main.gd:1232`, O(n)),
  koşullu `wall_count` (`main.gd:1243`, O(n) ve her çağrıda yeni `Dictionary`) ve `wall_right` (O(n)) çağırır.
  `traffic_ai` makasçı araçta yine `lane_blocker`. İç döngülerdeki her adım 2-4 `get_meta` (StringName araması).
  Kare başına toplam 40-50 farklı meta anahtarı okunuyor (`lane`, `dir`, `ghost`, `v`, `flash`, `drift`, `fid`,
  `half_l`, `half_w` ...). Ölçülen (yalnız komşu sorguları, masaüstü): 20 araç 71 µs, 30 araç 161 µs, 40 araç
  255 µs. Büyüme karesel.
- **Neden verimsiz:** Aynı kare içinde aynı şerit listesi araç başına baştan taranıyor. `get_meta` tipli alana göre
  belirgin yavaş ve tip denetimi yok.
- **Önerilen düzeltme:**
  1. Karenin başında bir kez `by_lane: Array` (6 şerit, her biri z'ye göre sıralı araç dizisi) kur.
     `lane_blocker` yalnız o şeridi, `wall_count`/`wall_right` sıralı tek bir süpürmeyle hesaplansın. Taslak: bölüm 6.
  2. Trafik kökü için küçük bir sınıf (`class_name TrafficCar extends Node3D` ya da `dress_car`'da atanan script):
     `var lane: int`, `var dir: int`, `var ghost: bool`, `var v: float`, `var half_l: float` ... `get_meta` yerine
     tipli alan.
- **Ödünleşim / risk:** 1. adım küçük ve yerel. 2. adım `lane_blocker`'ı kullanan siren, devriye, rakip, nitro taşı ve
  online alan kodunu da etkiler. Kare içinde şerit değiştiren araç için kova bir kare bayat kalabilir; mevcut davranışta
  da sıra bağımlılığı var, test edilmeli.
- **Beklenen etki:** Bu yolda %60-80 düşüş (tahmin). Tablette olası 0,3-1,3 ms/kare kazanç.
- **Kaldırma güvenliği:** Doğrulama gerekir
- **Yeniden kullanım kapsamı:** Modül (trafik)

### B6. Trafik araçları çift yüzlü çiziliyor

- **Kategori:** Frontend (GPU)
- **Önem:** Orta (olası; tablette darboğaz GPU)
- **Etki:** GPU süresi, kare hızı
- **Kanıt:** Bütün Kenney trafik araçları `kenney_mat` (`main.gd:347`, `car.gdshader`) kullanıyor ve
  `car.gdshader:7` `render_mode cull_disabled`. Paket malzemelerinin 13/41'i, tek araç GLB'lerinin malzemelerinin
  hepsi glTF'te `doubleSided`. `cull_swaps` (`main.gd:3889`) bu malzemelerin `CULL_BACK` kopyasını oyuncu için zaten
  üretiyor. `car_in.gdshader` aynı include'un `cull_back` sürümü olarak hazır duruyor.
- **Neden verimsiz:** Kapalı meshte arka yüzler hiç görünmez, ama rasterize edilir. Aynı mesh içindeki çizim sırası
  önden arkaya olmadığı için bir kısmı fragment shader'a da girer.
- **Önerilen düzeltme:** Kenney trafiği için `kenney_mat.shader = CAR_IN` (tek satır, yeni shader gerekmez).
  Paket trafik araçları için `cull_swaps`'taki kopya mantığını `Pack._add`'e taşıyıp trafik malzemelerini `CULL_BACK`
  yap. Oyuncu aracı `cull_disabled` kalabilir (kokpit ve ters normal sorunları için konmuş olabilir).
- **Ödünleşim / risk:** Bazı modellerde tek katmanlı ya da normali ters parçalar delik gibi görünebilir.
  `shot=` argümanıyla her trafik modeli önden ve arkadan kontrol edilmeli.
- **Beklenen etki:** Trafik çizimlerinde rasterize edilen üçgen ≈%50 azalır. Kare süresine etkisi `bench`'in
  "araba yok" adımıyla ölçülmeli.
- **Kaldırma güvenliği:** Doğrulama gerekir
- **Yeniden kullanım kapsamı:** Modül; Yeniden kullanım fırsatı (`car_in.gdshader`, `cull_swaps`)

### B7. APK'da kullanılmayan ve oyunla ilgisiz dosyalar

- **Kategori:** Build / Cost
- **Önem:** Orta
- **Etki:** APK boyutu (104,6 MB), editör import süresi
- **Kanıt (APK içinden sayıldı):**
  - Hiçbir sahne ve script'in başvurmadığı dokular, 4,97 MB: `cars/e30/e30_0..6.png` (eski çıkarma adları;
    `e30.glb` artık `e30_Image_*` kullanıyor), `cars/cop/cop_Image_3.png`, `cop_Image_10.png`,
    `cars/phoenix/phoenix_Image_1.png`, `_4`, `_10`. İçe aktarılmış `.scn`'ler açılıp taranarak doğrulandı.
  - `build/` altında `.gdignore` yok: editör web çıktısının ikonlarını import ediyor, APK'ya 13 dosya / 2,18 MB giriyor
    (`index.icon.png` vb.). `tools/` için `.gdignore` var, `build/` için yok.
  - `addons/godot_mcp` 91 dosya / 0,55 MB APK'da. `MCPRuntimeProbe` autoload'u release'de de çalışıyor:
    hata ayıklayıcı yokken `_capture_registered` hiç `true` olmadığı için `_process` her karede boşuna çağrılıyor
    (`addons/godot_mcp/runtime/mcp_runtime_probe.gd:11`).
  - `icon.png` 1024×1024, 2 MB ham olarak `assets/icon.png` ve ayrıca 1,55 MB `.ctex`. Android başlatıcı ikonları
    `res/` altında ayrıca var.
- **Neden verimsiz:** Oyunun hiç okumadığı ≈8,5 MB indirme ve kurulum boyutuna ekleniyor.
- **Önerilen düzeltme:** Ölü dokuları `git rm` ile sil. `build/.gdignore` ekle. `icon.png`'yi 512×512'ye indir.
  Eklenti için: açıkken autoload'u her editör açılışında yeniden kaydediyor (`_enter_tree` →
  `_ensure_runtime_probe_autoload`, `mcp_server_native.gd:530`), yalnız kapatılınca kaldırıyor (`_disable_plugin`,
  `:248`). Mağaza build'inden önce eklentiyi kapat, sonra preset'e `exclude_filter="addons/*"` ekle.
- **Ödünleşim / risk:** Autoload project.godot'ta kalıp eklenti dışlanırsa dışa aktarılan oyun açılışta "autoload
  yüklenemedi" hatası basar; sıra önemli (önce kapat, sonra dışla). Eklentiyi kapatmak MCP bağlantısını da keser;
  geliştirmede açık kalabilir.
- **Beklenen etki:** APK ≈104,6 → ≈96 MB (tahmin). Kare başı bir boş `_process` çağrısı gider.
- **Kaldırma güvenliği:** Ölü dokular güvenli (doğrulandı); eklenti dışlama doğrulama gerekir
- **Yeniden kullanım kapsamı:** Proje geneli; Ölü kod (varlık)

### B8. Kayıt dosyası atomik yazılmıyor

- **Kategori:** Reliability
- **Önem:** Orta
- **Etki:** Veri kaybı (coin, alınan araçlar)
- **Kanıt:** `profile.gd:178` `save()`: `ConfigFile.save(PATH)` doğrudan `user://save.cfg` üstüne yazar. En sık
  kazadan hemen sonra (`finish_run`) ve garajdaki satın almalarda çağrılır; oyuncunun uygulamayı kapattığı anlar.
  `_ready` yükleme başarısızsa sessizce varsayılanlara döner.
- **Neden riskli:** Yazma sırasında süreç öldürülürse (Android arka plan, pil) dosya yarım kalır, sonraki açılışta
  bütün ilerleme sıfırlanır. Godot'nun "güvenli kaydet"i editör ayarı; dışa aktarılan oyunda varsayılan olarak doğrudan
  yazdığı varsayıldı (doğrulanmalı).
- **Önerilen düzeltme:** `save.cfg.tmp`'ye yaz, başarılıysa `DirAccess.rename_absolute` ile üstüne taşı. Yüklemede
  ana dosya okunamazsa `.tmp`'yi dene. Taslak: bölüm 6.
- **Ödünleşim / risk:** Yok denecek kadar az; birkaç satır.
- **Beklenen etki:** Yarım yazılmış kayıt yüzünden ilerleme kaybı riski kalkar.
- **Kaldırma güvenliği:** Güvenli
- **Yeniden kullanım kapsamı:** Yerel dosya

### B9. Aktarma sunucusunda adres başına sınır sözlüğü doğrulamadan önce büyüyor

- **Kategori:** Reliability / Cost (kötüye kullanım vektörü)
- **Önem:** Orta (sunucu yayına girince)
- **Etki:** Sunucu belleği
- **Kanıt:** `tools/relay.py:39` her gelen datagram için, paket daha hiç incelenmeden
  `self.rate.setdefault(addr, ...)` ile kayıt açar. Temizlik 10 saniyede bir (`prune`).
- **Neden riskli:** UDP'de kaynak adresi taklit edilebilir. Her farklı kaynak adres bir sözlük girdisi demek;
  saniyede yüz binlerce sahte kaynakla 10 sn içinde yüzlerce MB bellek. `MAX_ROOMS` odaları sınırlıyor, `rate`'i sınırlamıyor.
- **Önerilen düzeltme:** Kayıt açmayı yalnız iki durumda yap: adres zaten bir odadaysa (`self.where`) ya da paket
  geçerli bir katılma paketiyse. Ek güvence: `len(self.rate)` belli bir sınırı geçerse yeni adres kabul etme ya da
  hemen `prune`. Taslak: bölüm 6.
- **Ödünleşim / risk:** Yok. Meşru istemcilerin ilk paketi zaten katılma paketi.
  Ayrı ve kalan risk: biçimi doğru sahte katılma paketleri `MAX_ROOMS`'u 30 sn (`TTL`) doldurup gerçek oyuncuları
  dışarıda bırakabilir. Kapatmak için katılmaya küçük bir el sıkışma (sunucunun verdiği çerezi geri isteme) gerekir;
  sunucu yayına girince düşünülmeli.
- **Beklenen etki:** Bellek büyümesi oda sayısıyla sınırlı kalır.
- **Kaldırma güvenliği:** Güvenli
- **Yeniden kullanım kapsamı:** Yerel dosya

### B10. Online durum paketi metin anahtarlı sözlük

- **Kategori:** Network / Cost
- **Önem:** Düşük (aktarma sunucusu açılınca Orta)
- **Etki:** Mobil veri, aktarma sunucusu trafiği
- **Kanıt:** `net.gd:256` `send_state` saniyede 20 kez `{"t","d","x","v","w","sc"}` + `_send`'in eklediği
  `fs`, `k`, `me` anahtarlarını `var_to_bytes` ile gönderir. Ölçülen: 220 B (botla 288 B). UDP/IP başlığıyla
  ≈5-6,3 KB/sn, yön başına. Aktarma sunucusundan geçince sunucu iki yönü de taşır: yarış başına ≈10-13 KB/sn.
  Anahtar adları ve 8 karakterlik metin anahtarlar her pakette tekrar ediyor.
- **Önerilen düzeltme:** `s` mesajı için sabit ikili düzen (`PackedByteArray`, `encode_float`/`encode_half`):
  sihirli bayt, tür, 4 baytlık iki anahtar, d, x, v, sc, bayraklar ≈26-40 B. Diğer seyrek mesajlar sözlük kalabilir.
  `PROTO` artırılır.
- **Ödünleşim / risk:** Sürüm uyumluluğu kırılır (iki taraf da güncellenmeli). Doğrulama ve sınırlar
  (`clampf`, boyut denetimi) aynen korunmalı.
- **Beklenen etki:** Durum trafiğinde ≈%80-85 düşüş.
- **Kaldırma güvenliği:** Doğrulama gerekir
- **Yeniden kullanım kapsamı:** Modül (`net.gd` + `relay.py` değişmez)

### B11. "Güvenilir" mesajlar onaysız üç kez gönderiliyor

- **Kategori:** Reliability / Network
- **Önem:** Düşük
- **Etki:** Yarış başlangıcı ve bitişinin takılması, gereksiz tekrar trafiği
- **Kanıt:** `net.gd:492` `_reliable` mesajı `_resend`'e 3 hakla koyar, `_process` 0,25 sn'de bir gönderir
  (`net.gd:444`). Onay (ack) yok: karşı ilk kopyayı alsa da iki kopya daha gider; üç kopya da kaybolursa
  (`go`, `rdy`, `quit`, `fsc`, `bft`) yarış zaman aşımına (15 sn `_ready_wait`, 5 sn `_state_quiet`) kalır.
- **Önerilen düzeltme:** Alınan sıra numarasını sonraki pakette `a` alanıyla geri yolla; `_resend` onaylananı silsin,
  onaysızı daha uzun süre (ör. 10 deneme / 2,5 sn) tekrarlasın.
- **Ödünleşim / risk:** Protokol değişikliği; B10 ile aynı sürüm artışında yapılabilir.
- **Beklenen etki:** Kayıplı mobil ağda yarış başlangıcı daha güvenilir. Trafiğe etkisi küçük.
- **Kaldırma güvenliği:** Doğrulama gerekir
- **Yeniden kullanım kapsamı:** Modül

### B12. Arayüzde kare başı tema değişikliği ve StyleBox üretimi

- **Kategori:** Frontend / CPU
- **Önem:** Düşük
- **Etki:** Arayüz CPU süresi
- **Kanıt:**
  - `ui.gd:248`: zamana karşı modda `timer_label.add_theme_color_override(...)` her karede çağrılıyor. Tema
    değişikliği `Label`'a `NOTIFICATION_THEME_CHANGED` gönderir, yazı yeniden şekillenir. Aynı dosya `set_text` ile
    bundan özellikle kaçınıyor (`ui.gd:249` yorumu).
  - `ui.gd:375` ve `ui.gd:389` `draw_signs`, `ui.gd:807` ve `ui.gd:827` `draw_cockpit`: her yeniden çizimde,
    yani her karede, yeni `StyleBoxFlat`.
- **Önerilen düzeltme:** Rengi yalnız eşik geçilince ata (`set_meta` ile son durumu tut, `hb_btn`'deki gibi).
  StyleBox'ları bir kez kur, karede yalnız `bg_color`'ı değiştir.
- **Ödünleşim / risk:** Yok.
- **Beklenen etki:** Küçük; ölçülebilir olması için profil gerekir.
- **Kaldırma güvenliği:** Güvenli
- **Yeniden kullanım kapsamı:** Yerel dosya

### B13. Trafik aracı başına çizim çağrısı ve paylaşılmayan malzemeler

- **Kategori:** Frontend (GPU/CPU sürücü yükü)
- **Önem:** Düşük (önce ölç)
- **Etki:** Çizim çağrısı sayısı
- **Kanıt:** Her trafik aracı: model parçaları (Kenney 5-7, paket ≈11 primitive) + gölge lekesi + 2 hâle + 2 yansıma
  şeridi + far ışığı. `Build.streak` (`build.gd:54`) her çağrıda yeni `ShaderMaterial` üretiyor; 38 araçta 76 ayrı
  malzeme. Oysa `add_beam` (`beam_mats`), `add_glow` (`glow_mats`) ve `Regions._pools` aynı renk için malzemeyi zaten
  paylaşıyor. `add_glow` her çağrıda yeni `QuadMesh` kuruyor.
- **Önerilen düzeltme:** `Build.streak` için renk+enerji anahtarlı `static var` malzeme önbelleği (mevcut desenin
  aynısı). `add_glow`'da boyuta göre `QuadMesh` önbelleği. Daha ileri: trafik araçlarının sabit parçalarını
  (tekerlekler dönmüyor) `Pack._add`'de malzeme başına tek yüzeyde birleştir. Oyuncu aracında yapılmamalı:
  `apply_rims` tekerlek meshlerini adlarından buluyor.
- **Ödünleşim / risk:** Malzeme önbelleği güvenli. Mesh birleştirme `set_beam`/hâle mantığına dokunmaz, ama paket
  araçlarında görsel kontrol ister.
- **Beklenen etki:** Malzeme ve mesh kaynak sayısı azalır. Çizim çağrısı etkisi `[perf]` satırındaki `cizim=` ile ölçülmeli.
- **Kaldırma güvenliği:** Önbellek güvenli; birleştirme doğrulama gerekir
- **Yeniden kullanım kapsamı:** Proje geneli; Yeniden kullanım fırsatı

### B14. Kullanılmayan import seçenekleri

- **Kategori:** Build / Memory
- **Önem:** Düşük
- **Etki:** `.scn` boyutu, mesh belleği
- **Kanıt:** Bütün araba GLB'lerinde `meshes/create_shadow_meshes=true`; koddaki hiçbir ışıkta `shadow_enabled` yok,
  gölge hiç çizilmiyor. `meshes/ensure_tangents=true`; `car.gdshaderinc` normal map kullanmıyor (paket
  malzemelerinin bir kısmı kullanıyor olabilir).
- **Önerilen düzeltme:** `create_shadow_meshes=false`. Tanjantı yalnız normal dokusu olan modellerde bırak.
- **Ödünleşim / risk:** Gölge ileride açılırsa ayar geri alınır.
- **Beklenen etki:** `.scn` boyutunda küçük düşüş (tahmin %5-10; ölçülmedi).
- **Kaldırma güvenliği:** Gölge meshleri güvenli; tanjant doğrulama gerekir
- **Yeniden kullanım kapsamı:** Proje geneli

### B15. Kare başı küçük ayırmalar ve gereksiz dönüşümler

- **Kategori:** CPU / Memory
- **Önem:** Düşük (yalnız profil script süresini yüksek gösterirse)
- **Kanıt:**
  - `update_curve` (`main.gd:3490`): viraj varken her karede `traffic.duplicate()` + `append_array`, ve
    `n in bent` (`main.gd:3510`) doğrusal arama. `movers` içinde aynı düğüm iki kez bulunmuyor; bu kontrol koruma amaçlı.
  - `set_road` (`main.gd:3561`): parametre `String`; kare başına ≈6 çağrı × 2 malzeme, her biri StringName'e dönüşüm.
  - `update_player` (`main.gd:1414`): her karede `Profile.car_info(Profile.car)` doğrusal arama; değer `load_stats`'ta
    bir kez hesaplanabilir.
  - `mission()` kare başı 1-3 kez, her biri `Profile.track` içinde yeni dizi.
  - `RenderingServer.global_shader_parameter_set("wetness"/"night")` (`main.gd:1466`, `main.gd:1676`) her karede,
    değer değişmese de.
- **Önerilen düzeltme:** `set_road(param: StringName, ...)` ve çağrılarda `&"offset"`. `loose`'u `stats`'a koy. Global
  uniform'ları değer değişince ata (`lamp_day` deseni). `movers` için örnek değişkeni olarak tekrar kullanılan dizi.
- **Beklenen etki:** Toplamda küçük (tahmin <0,1 ms/kare tablette).
- **Kaldırma güvenliği:** Güvenli
- **Yeniden kullanım kapsamı:** Yerel dosya

### B16. Online trafik alanı her karede baştan sona taranıyor

- **Kategori:** Algorithm / CPU
- **Önem:** Düşük
- **Kanıt:** `update_field` (`main.gd:3336`) bütün `field` dizisini (≈200 kayıt, tahmin) her karede dolaşır.
  `field_busy` (`main.gd:3377`) kapalı şeritte her çağrıda bütün diziyi tarar; `field_ahead` (`main.gd:3232`) bot için aynı.
- **Neden verimsiz:** Her yönün kayıtları başlangıç yerine göre sıralı ve aynı sabit hızla gidiyor: görüş penceresi
  dizide bitişik bir aralık.
- **Önerilen düzeltme:** Yön başına iki indeks (pencere başı/sonu) tut ya da `bsearch_custom` ile pencereyi bul.
- **Beklenen etki:** Küçük; yalnız online.
- **Kaldırma güvenliği:** Doğrulama gerekir (iki cihazda aynı sonuç şartı)
- **Yeniden kullanım kapsamı:** Yerel dosya

### B17. Ölçüm ve dağıtım debug şablonuyla yapılıyor

- **Kategori:** Build
- **Önem:** Düşük
- **Kanıt:** APK `--export-debug` ile üretiliyor; `lib/arm64-v8a/libgodot_android.so` 76,4 MB açık, 26,8 MB sıkıştırılmış.
  `[perf]` ölçümleri debug build'den.
- **Neden önemli:** Debug şablonu (`DEBUG_ENABLED`) GDScript'e ek denetimler katar; ölçülen CPU süresi release'den
  yüksektir, kütüphane de büyüktür.
- **Önerilen düzeltme:** Performans kararlarını release build'de de doğrula. Mağaza için release anahtarı (zaten not
  edilmiş). İleride özel motor derlemesi: B-derin-6.
- **Kaldırma güvenliği:** Güvenli

### Yeniden kullanım, ölü kod ve aşırı soyutlama

| Bulgu | Tür | Yer | Öneri |
|---|---|---|---|
| Kullanılmayan 12 doku | Ölü kod (varlık), güvenli | B7 listesi | `git rm` |
| `keep := player_mat` / `make_player` / `player_mat = keep` üç kez | Yeniden kullanım fırsatı | `main.gd:2798`, `2805`, `3108` | `make_player` global `player_mat`'ı değiştirmesin; malzemeyi parametre ya da dönüş olarak versin. Yan etki, kayma riski taşıyor. |
| Rakip ve bot isim etiketi aynı kod | Yeniden kullanım fırsatı | `main.gd:2819`, `3112` | `add_tag(node, text, color)` |
| Çarpışma efekti (popup + shake + buzz + `play("crash", 1.3, -10.0)`) üç kez | Yeniden kullanım fırsatı | `main.gd:2947`, `3076`, `3164` | `bump_fx(text, color)` |
| Radyal `GradientTexture2D` üç kez kuruluyor | Yeniden kullanım fırsatı | `_ready` (gölge, `glow_tex`), `build_spray` | `glow_tex` su sisi için de kullanılabilir (renk rampası zaten parçacıkta) |
| Etiket dış çizgi ayarları dört kez | Yeniden kullanım fırsatı | `ui.gd:166`, `186`, `196`, `211` | mevcut `label()` yardımcısına `outline` parametresi |
| `Build.streak` malzeme önbelleksiz | Yeniden kullanım fırsatı | `build.gd:54` | B13 |
| `hud_tags()` tek etiket için dizi + `join` | Aşırı soyutlama (önemsiz) | `main.gd` `hud_tags` | Dokunmaya değmez; ikinci etiket gelmeyecekse tek satır |
| `RELAY_HOST := ""` | Kapalı özellik (ölü değil) | `net.gd:46` | Sunucu kurulana kadar aktarma yolu hiç çalışmıyor; bilinçli |
| Fonksiyon, değişken, sabit | Ölü kod yok | bütün `.gd` dosyaları | Her fonksiyon ve sabit en az bir yerde kullanılıyor (taranarak doğrulandı) |

---

## 3) Hızlı Kazanımlar (önce bunlar)

| # | İş | Süre | Etki | Bulgu |
|---|---|---|---|---|
| 1 | `cars/**` dokularını VRAM Compressed yap, yeniden import et, garajda göz kontrolü | 15-30 dk | Çok yüksek (bellek, açılış) | B1 |
| 2 | 12 ölü dokuyu sil, `build/.gdignore` ekle | 5 dk | APK −≈7 MB | B7 |
| 3 | Kaput yüksekliği ve jant meshleri için `static var` önbellek | 10 dk | Yeniden başlatma ve garaj hızlanır | B4 |
| 4 | Garajda boyayı ayrı yoldan uygula (`apply_paint`) | 30 dk | Boya dokunuşunda takılma gider | B3 |
| 5 | Atomik kayıt (`.tmp` + rename) | 10 dk | İlerleme kaybı riski kalkar | B8 |
| 6 | Kenney trafiğinde `kenney_mat.shader = CAR_IN`, `shot=` ile görsel kontrol | 15 dk | Olası GPU kazancı | B6 |
| 7 | `relay.py`: sınır kaydını doğrulamadan sonra aç | 10 dk | Sunucu bellek saldırısı kapanır | B9 |
| 8 | `timer_label` rengi eşikte, StyleBox'lar önbellekte | 10 dk | Küçük CPU | B12 |
| 9 | `create_shadow_meshes=false` | 5 dk | Küçük boyut | B14 |

## 4) Derin Optimizasyonlar (sonra)

1. **Tembel araç yükleme + threaded ön yükleme** (B2). Garaj açılınca komşu araçlar arka planda.
2. **Trafik veri modeli:** tipli `TrafficCar` sınıfı ve kare başı şerit kovaları (B5). `lane_blocker`'ın bütün
   çağıranları (siren, devriye, rakip, nitro taşı) aynı kovayı kullanır.
3. **Sahne yenilemeden yeniden başlatma** (B4/3). Önce ölç; gerekçe çıkarsa.
4. **Protokol 2:** ikili durum paketi + ack'li güvenilir mesajlar (B10, B11). Aktarma sunucusu yayına girmeden önce
   yapılırsa sunucu trafiği baştan küçük olur.
5. **Trafik araçlarında mesh birleştirme ve paylaşılan malzemeler** (B13). Hâleleri bütün trafik için tek MultiMesh'e
   taşımak ≈100 çizim çağrısını tek çağrıya indirebilir; karşılığında araç başı dönüşümler her karede MultiMesh'e yazılır.
6. **Release + özel motor derlemesi:** oyun fizik motoru kullanmıyor (RigidBody, Area, ışın yok); kullanılmayan
   modüller bir "build profile" ile kapatılabilir. Kütüphane boyutunda ve açılışta kazanç beklenir (tahmin %30+, ölçülmedi).
7. **Gökyüzü:** bulut fbm'i her gökyüzü pikselinde 4 oktav. Sky shader'ın yarım/çeyrek çözünürlük geçişi
   (`use_half_res_pass`) Mobile renderer'da destekleniyorsa bulutlar orada hesaplanabilir. Destek doğrulanmalı;
   `bench`'in "gok yok" adımı önce payı göstersin.
8. **Web sürümü:** B1 olmadan iPhone Safari'de bellek sınırına takılma olasılığı yüksek. Web paketi 65,7 MB `.pck` +
   39,5 MB `.wasm`. B1 + B2 sonrası tekrar ölçülmeli; gerekirse web'e özel daha küçük doku sınırı (`size_limit`).

## 5) Doğrulama Planı

**Ortam.** Tablet (SM-X210), hem debug hem release APK. Masaüstünde headless mikro ölçüm.

**Metrikler (önce/sonra).**

| Metrik | Nasıl | Hedef |
|---|---|---|
| Doku belleği | `[perf]` satırına `Performance.RENDER_TEXTURE_MEM_USED` ekle | B1 sonrası ≈%70+ düşüş |
| Video belleği | `Performance.RENDER_VIDEO_MEM_USED` | düşüş |
| Statik bellek | `Performance.MEMORY_STATIC` | B1+B2 sonrası ≈100-250 MB düşüş |
| Açılış | `_ready` başı/sonu ve `Pack._load` çevresinde `Time.get_ticks_msec()`; logcat | düşüş |
| Yeniden başlatma | `restart()`'ta zaman damgası `Profile`'a, yeni sahnenin ilk karesinde fark | B4/1 sonrası düşüş |
| Garaj boya dokunuşu | `preview()` çevresinde `Time.get_ticks_usec()` | <1 ms |
| Kare süresi ve FPS | mevcut `[perf]` satırı (fps, `cizim=`, `üçgen=`, `işlem=`) aynı rota, aynı hava, 60 sn | `işlem` ve `cizim` düşüş |
| GPU payı | mevcut `user://bench` koşusu ("araba yok", "gok yok" adımları) B6 öncesi/sonrası | araba payı düşüş |
| APK boyutu | `python3 -c "import zipfile..."` listesi ya da `unzip -l` | ≈96 MB altı |
| Ağ | `Net._send`'e debug bayt sayacı, 2 dk yarış | B10 sonrası ≈%80 düşüş |
| Aktarma sunucusu | çok sayıda kaynak portundan sahte trafik + `ps -o rss` | RSS sabit kalmalı |

**Mikro ölçüm.** Bu denetimde kullanılan headless betik bölüm 6'da (§6.10). `tools/` altına konursa (klasörde
`.gdignore` var, APK'ya girmez) her değişiklikten sonra aynı komutla karşılaştırılabilir.

**Doğruluk testleri.**

- `godot-mono --headless --path . --script tools/test_net.gd` ve `tools/test_relay.gd`: `TEST OK` vermeli (B10, B11, B9).
- Her trafik modeli için `shot=` görüntüsü, önden ve arkadan (B6, B13). Örnek argümanlar: `car=<id> play shot=<dosya>:2`.
- Garajda her boya kaplaması (finish 0-14), jant ve modifiye: önizleme ve kayıttan sonra yeniden açılışta aynı görünüm (B3).
- Online iki cihaz: tohumlu olaylar ve trafik alanı iki tarafta aynı (B5, B16). `[olay]` logları iki cihazda aynı sırada olmalı.
- Kayıt: `save()` sırasında süreci öldür (`kill -9` masaüstünde, döngüyle), açılışta coin ve araçlar korunmalı (B8).

---

## 6) Önerilen Kod / Yama

Taslaklardır; uygulanmadı. Kod stili ve yorum yoğunluğu mevcut dosyalara göre yazıldı.

### 6.1 Dokuları VRAM sıkıştırmalı yap (B1)

Fish kabuğunda, proje kökünde:

```fish
sed -i 's/^compress\/mode=0$/compress\/mode=2/' cars/**.png.import cars/**.jpg.import
godot-mono --headless --path . --import
```

Ne değişir: kayıpsız (0) yerine VRAM sıkıştırmalı (2). `--import` yeniden import edip çıkar. Sonra garajda yakın
çekimde boya ve gövde dokusu kontrol edilmeli.

### 6.2 Ölü dokular ve `build/.gdignore` (B7)

```fish
git rm cars/e30/e30_{0,1,2,3,4,5,6}.png cars/e30/e30_{0,1,2,3,4,5,6}.png.import \
    cars/cop/cop_Image_{3,10}.png cars/cop/cop_Image_{3,10}.png.import \
    cars/phoenix/phoenix_Image_{1,4,10}.png cars/phoenix/phoenix_Image_{1,4,10}.png.import
touch build/.gdignore
```

`build/` `.gitignore`'da olduğu için `.gdignore` yerelde kalır; her makinede bir kez gerekir. Ya da web export yolu
proje dışına alınır.

### 6.3 Tembel paket yükleme (B2), `pack.gd`

```gdscript
static var _pack_loaded := false


# Trafikte dolaşabilenler: paketin araçları ve e30. Tek araç modelleri istenince yüklenir.
static func names() -> Array:
	_load_pack()
	info("e30")
	return _cars.keys().filter(func(n): return not n in SINGLES or n == "e30")


static func info(name: String) -> Dictionary:
	if not _cars.has(name):
		if name in SINGLES:
			_load_single(name)
		else:
			_load_pack()
	return _cars[name]


static func _load_pack() -> void:
	if _pack_loaded:
		return
	_pack_loaded = true
	# ... mevcut _load() içindeki car_pack.glb bölümü ...


static func _load_single(nm: String) -> void:
	# ... mevcut _load() içindeki SINGLES döngüsünün tek araçlık gövdesi ...
```

Ne değişir: açılışta yalnız paket, e30 ve (polis kurulunca) cop yüklenir. Garajda ilk dokunuşta takılma olursa
`ui.open_garage()` içinde komşu araçların GLB'si için `ResourceLoader.load_threaded_request(...)`.

### 6.4 Kaput yüksekliği ve jant önbelleği (B4/1), `main.gd`

```gdscript
static var hood_cache := {} # araç kimliği -> kaput yüksekliği; sahne yenilense de kalır
static var rim_meshes := {} # jant sırası -> ArrayMesh (örnek değişkeniydi, her sahnede yeniden kuruluyordu)

# make_player içinde:
	if not hood_cache.has(id):
		hood_cache[id] = hood_height(root, rear)
	root.set_meta("hood_y", hood_cache[id])
```

Ne değişir: `get_faces()` araç başına süreçte bir kez. Süspansiyon modu (`low`) `build_player_extras`'ta, kaput
hesabından sonra uygulanıyor; jant ve gölge lekesi de kaputun altında kalıyor. Bu yüzden anahtar olarak `id` yeterli.
Jant meshleri malzemeleriyle birlikte paylaşılır; sahneye bağlı bir şey tutmuyorlar.

### 6.5 Boyayı ayrı uygula (B3)

`main.gd`:

```gdscript
# Boya ve kaplama: yalnız malzeme; model ve ölçüler aynı kalır.
func apply_paint(m: ShaderMaterial, paint_index: int) -> void:
	m.set_shader_parameter("use_paint", 0.0 if paint_index == 0 else 1.0)
	var pd: Array = Profile.PAINTS[paint_index]
	m.set_shader_parameter("paint", pd[1])
	m.set_shader_parameter("finish", pd[3] if pd.size() > 3 else 0)
	if pd.size() > 4:
		m.set_shader_parameter("paint2", pd[4])

# make_player içindeki aynı blok yerine: apply_paint(player_mat, paint_index)
```

`ui.gd`:

```gdscript
func pick_paint(i: int) -> void:
	g_paint = i
	main.apply_paint(main.player_mat, g_paint) # araç aynı: yeniden kurmaya gerek yok
	refresh_garage()
```

Not: `paint2`'si olmayan boyaya geçince önceki `paint2` malzemede kalır. Zararsız: `paint2`'yi okuyan bütün
kaplamaların (4, 7, 9, 10, 13, 14) `Profile.PAINTS` kaydında ikinci renk var.

### 6.6 Atomik kayıt (B8), `profile.gd`

```gdscript
func save() -> void:
	var cfg := ConfigFile.new()
	# ... mevcut set_value satırları ...
	# önce yan dosyaya: yazma yarıda kesilirse eski kayıt sağlam kalır
	if cfg.save(PATH + ".tmp") == OK:
		DirAccess.rename_absolute(PATH + ".tmp", PATH)
```

`_ready`'de `cfg.load(PATH) != OK` ise `cfg.load(PATH + ".tmp")` denenebilir.

### 6.7 Arayüz: tema değişikliği yalnız eşikte (B12), `ui.gd`

```gdscript
	if timer_label.visible:
		set_text(timer_label, "%.1f" % main.time_left)
		var low: bool = main.time_left < 5.0
		if timer_label.get_meta("low", false) != low: # tema değişince yazı yeniden şekillenir
			timer_label.set_meta("low", low)
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3) if low else Color(1, 1, 1))
```

`draw_signs` ve `draw_cockpit`'teki `StyleBoxFlat.new()` bir kez `build_play()`'de kurulur, çizimde yalnız
`sb.bg_color.a = a` atanır.

### 6.8 Aktarma sunucusu: kayıt doğrulamadan sonra (B9), `tools/relay.py`

```python
    def datagram_received(self, data: bytes, addr: tuple) -> None:
        if len(data) > MAX_PACKET:
            return
        join = data.startswith(MAGIC)
        if not join and addr not in self.where:
            return # odası olmayan adresten yalnız katılma paketi kabul edilir: sahte kaynaklar kayıt açmasın
        if addr not in self.rate and len(self.rate) >= MAX_ROOMS * 4:
            return
        now = time.monotonic()
        r = self.rate.setdefault(addr, [int(now), 0])
        # ... mevcut sınır ve oda mantığı ...
```

Ne değişir: yalnız geçerli katılma paketi ya da bilinen üye kayıt açabilir; kayıt sayısı oda sınırına bağlı.
Katılma paketinin oda kimliği denetimi (`len(room) != 32`, HEX) kaydı açmadan önce yapılırsa daha da sıkı olur.

### 6.9 Trafik komşu sorguları için şerit kovası (B5), `main.gd` taslağı

```gdscript
var by_lane: Array = [[], [], [], [], [], []] # şerit -> görünür, hayalet olmayan araçlar; kare başında bir kez


func index_lanes() -> void:
	for b in by_lane:
		b.clear()
	for c in traffic:
		if c.visible and not c.get_meta("ghost", false):
			by_lane[c.get_meta("lane")].append(c)


func lane_blocker(l: int, z: float, back := 6.0, skip: Node3D = null) -> Node3D:
	for c in by_lane[l]: # yalnız o şerit: önceden bütün trafik taranıyordu
		if c == skip:
			continue
		var ahead: float = z - c.position.z
		if ahead > -back and ahead < (60.0 if c.get_meta("dir") > 0 else 170.0):
			return c
	return null
```

`update_traffic` başında `index_lanes()`. `wall_count`/`wall_right` için aynı kovalardan, z penceresine düşen
şerit sayısı. Dikkat: `lane_blocker` kare içinde şerit değiştiren araçları (`traffic_ai`, `update_tailgate`,
`take_fork`, `place`) bir kare geç görür; `place` ve `ghost` atamalarından sonra kova güncellenmeli ya da bu gecikme
testle kabul edilmeli. `ponytail:` notu: kova her kare baştan kurulur; araç sayısı yüzleri bulursa artımlı güncelleme.

### 6.10 Ölçüm betiği (doğrulama için)

Bu denetimde kullanılan betik. `tools/bench_load.gd` olarak konursa:
`godot-mono --headless --path . --script tools/bench_load.gd`

```gdscript
extends SceneTree

# Salt ölçüm: Pack._load maliyeti, kaput hesabı ve trafik komşu sorgularının kare başı maliyeti.
# Oyun sahnesi açılmaz, kayıt dosyasına dokunulmaz.

const LANES := [-5.25, -1.75, 1.75, 5.25, 8.75, -8.75]


func _initialize() -> void:
	var t0 := Time.get_ticks_usec()
	var pack: GDScript = load("res://pack.gd")
	pack.call("_load")
	print("[bench] Pack._load: %.1f ms, statik bellek %.1f MB" % [(Time.get_ticks_usec() - t0) / 1000.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	for nm in ["sf90", "gtr", "e30"]:
		var m: Node3D = pack.call("build", nm)
		var t2 := Time.get_ticks_usec()
		var n := 0
		for mi in m.get_children():
			n += (mi as MeshInstance3D).mesh.get_faces().size()
		print("[bench] get_faces %s: %d köşe, %.1f ms" % [nm, n, (Time.get_ticks_usec() - t2) / 1000.0])
		m.free()
	for count in [20, 30, 40]:
		bench_traffic(count)
	quit()


func bench_traffic(count: int) -> void:
	var traffic: Array[Node3D] = []
	for i in count:
		var c := Node3D.new()
		c.set_meta("lane", [2, 3, 0, 1][i % 4])
		c.set_meta("dir", 1 if i % 4 < 2 else -1)
		c.set_meta("ghost", false)
		c.position.z = -10.0 - i * 7.0
		root.add_child(c)
		traffic.append(c)
	var frames := 300
	var t0 := Time.get_ticks_usec()
	for f in frames:
		for c in traffic:
			if c.get_meta("dir") > 0:
				lane_blocker(traffic, c.get_meta("lane"), c.position.z, 0.0, c)
				if c.position.z < -8.0 and wall_count(traffic, c.position.z, 5.0, -1) >= 4:
					wall_right(traffic, c.position.z, 5.0)
	print("[bench] trafik %d araç: kare başı %.1f µs" % [count, (Time.get_ticks_usec() - t0) / float(frames)])
	for c in traffic:
		c.free()


# main.gd'deki üç fonksiyonun birebir kopyası (trafik dizisi parametre).
func lane_blocker(traffic: Array[Node3D], l: int, z: float, back: float, skip: Node3D) -> Node3D:
	for c in traffic:
		if c == skip or not c.visible or c.get_meta("ghost", false) or c.get_meta("lane") != l:
			continue
		var ahead: float = z - c.position.z
		if ahead > -back and ahead < (60.0 if c.get_meta("dir") > 0 else 170.0):
			return c
	return null


func wall_count(traffic: Array[Node3D], z: float, win: float, skip_lane: int) -> int:
	var seen := {}
	for c in traffic:
		if c.visible and not c.get_meta("ghost", false) and absf(c.position.z - z) < win and c.get_meta("lane") != skip_lane:
			seen[c.get_meta("lane")] = true
	return seen.size()


func wall_right(traffic: Array[Node3D], z: float, win: float) -> int:
	var best := -1
	for c in traffic:
		if c.visible and c.get_meta("dir") > 0 and absf(c.position.z - z) < win:
			var l: int = c.get_meta("lane")
			if best < 0 or LANES[l] > LANES[best]:
				best = l
	return best
```

Bu denetimdeki masaüstü sonuçları: Pack._load 991 ms / 364 MB; get_faces sf90 12,2 ms, gtr 16,6 ms, e30 0,5 ms;
trafik 20/30/40 araç 70,6 / 161,2 / 254,9 µs.

---

## Güveni artıracak ek veriler

- Tabletten bir release build `[perf]` kaydı (60 sn, yağmurlu gece, normal mod) ve `bench` çıktısı.
- `Performance.RENDER_TEXTURE_MEM_USED` değeri, B1 öncesi ve sonrası.
- Açılış ve yeniden başlatma süresi (tablette).
- Aktarma sunucusu yayına girecekse beklenen eşzamanlı yarış sayısı: B9, B10 ve sunucu boyutlandırması buna göre.
