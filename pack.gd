# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends RefCounted

# "Generic passenger car pack" (Comrade1280, Sketchfab, CC BY 4.0; bkz. CREDITS.md). Yedi araç tek dosyada,
# daire şeklinde dizili; her gövde (gövde, cam, far meshleri) ve en yakın dört tekerleği ayrılır, metre
# cinsinden, yere oturmuş, ortalanmış ve önü +z olacak şekilde (Kenney modelleriyle aynı) hazırlanır.

const PATH := "res://cars/pack/car_pack.glb"
# Tek araçlık modeller (cars/<ad>/<ad>.glb, CC BY; bkz. CREDITS.md). Blender'da hazırlandı: metre, üçgen sayısı
# mobile göre azaltılmış, tekerlekler "wheel0..3", boyanan gövde "car_Body_*", lambalar "car_Optics_*".
const SINGLES := ["e30", "doblo", "phoenix", "m4", "cop"]
const SCALE := 1.0 # sahne kökü milimetreyi zaten 0.000889 ile çarpıyor: gerçek boyun yaklaşık %89u
# ön ucu dosyada -y'de olanlar (çeviri sonrası 180° döndürülür)
const FLIP := ["minivan", "offroad", "coupe", "e30"]

static var _cars := {} # ad -> {parts: [[mesh, xform, material]], half_w, half_l, top}


# Trafikte dolaşabilenler: çok parçalı ağır modeller (Doblo, Phoenix, M4) ve polis yalnız oyuncu/polis olarak.
static func names() -> Array:
	_load()
	return _cars.keys().filter(func(n): return not n in ["doblo", "phoenix", "m4", "cop"])


static func info(name: String) -> Dictionary:
	_load()
	return _cars[name]


# Araç modeli: önü +z, tekerlekler yerde. Far ve stop lambaları gece kendi ışığıyla parlar.
static func build(name: String) -> Node3D:
	var m := Node3D.new()
	for p in info(name).parts:
		var mi := MeshInstance3D.new()
		mi.name = p[3]
		mi.mesh = p[0]
		mi.transform = p[1]
		if p[2]:
			mi.material_override = p[2]
		m.add_child(mi)
	return m


static func _global(n: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	while n != null and n != root:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _load() -> void:
	if not _cars.is_empty():
		return
	var scn: Node = (load(PATH) as PackedScene).instantiate()
	var bodies: Array = []
	var wheels: Array = []
	for n in scn.find_children("*", "Node3D", true, false):
		if n is MeshInstance3D:
			continue
		var nm := String(n.name).to_lower()
		if nm.ends_with("body"):
			bodies.append(n)
		elif nm.begins_with("wheel_"):
			wheels.append(n)
	for b in bodies:
		var gb := _global(b, scn)
		var nm := String(b.name).replace(" Body", "").replace(" body", "").to_lower()
		var meshes: Array = b.find_children("*", "MeshInstance3D", true, false)
		wheels.sort_custom(func(a, c): return _global(a, scn).origin.distance_to(gb.origin) < _global(c, scn).origin.distance_to(gb.origin))
		var own: Array = wheels.slice(0, 4)
		var wheel_of := {} # mesh -> tekerlek sırası
		for wi in own.size():
			for wm in own[wi].find_children("*", "MeshInstance3D", true, false):
				meshes.append(wm)
				wheel_of[wm] = wi
		_add(nm, scn, meshes, wheel_of, own.map(func(w): return _global(w, scn).origin))
	scn.free()
	for nm in SINGLES:
		var one: Node = (load("res://cars/%s/%s.glb" % [nm, nm]) as PackedScene).instantiate()
		var meshes: Array = []
		var wheel_of := {}
		var pts := [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
		for mi: MeshInstance3D in one.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).begins_with("wheel"):
				var wi := int(String(mi.name).substr(5, 1))
				wheel_of[mi] = wi
				pts[wi] = _global(mi, one) * mi.get_aabb().get_center()
			meshes.append(mi)
		meshes.sort_custom(func(x, y): return not wheel_of.has(x) and wheel_of.has(y)) # gövde önce (body_c)
		_add(nm, one, meshes, wheel_of, pts)
		one.free()


# Bir aracın parçalarını önü +z, yere oturmuş ve ortalanmış olarak kaydeder. pts: dört tekerleğin merkezi.
static func _add(nm: String, scn: Node, meshes: Array, wheel_of: Dictionary, pts: Array) -> void:
	# Aracın ekseni geometriden: gövde node'larının dönüşü aracın boyuna denk gelmiyor. Dört tekerlek
	# merkezinin düzlemi yukarıyı, aynı akstaki iki tekerlek (en kısa kenar) yanı verir; boy ikisine dik.
	var c: Vector3 = (pts[0] + pts[1] + pts[2] + pts[3]) * 0.25
	var body_c: Vector3 = _global(meshes[0], scn) * (meshes[0] as MeshInstance3D).get_aabb().get_center()
	var p0: Vector3 = pts[0]
	var up: Vector3 = (pts[1] - p0).cross(pts[2] - p0).normalized()
	if up.dot(body_c - c) < 0.0:
		up = -up
	var near: Vector3 = pts[1]
	for q: Vector3 in pts.slice(1):
		if (q - p0).length() < (near - p0).length():
			near = q
	var side: Vector3 = near - p0
	side = (side - up * side.dot(up)).normalized()
	var length: Vector3 = side.cross(up).normalized()
	var frame := Transform3D(Basis(side, up, length), c).affine_inverse()
	var basis := Basis().scaled(Vector3.ONE * SCALE)
	if nm in FLIP:
		basis = Basis(Vector3.UP, PI) * basis
	var parts: Array = []
	var box := AABB()
	var low := INF # tekerleklerin en alt noktası: araç buradan yere oturur
	for mi: MeshInstance3D in meshes:
		var t := Transform3D(basis, Vector3.ZERO) * frame * _global(mi, scn)
		if String(mi.name).contains("_Body_"):
			# ölçü gövdenin köşelerinden: bazı gövdeler dosyada kendi içinde döndürülmüş, kutusu şişiyor
			var faces := mi.mesh.get_faces()
			for k in range(0, faces.size(), 3):
				var w: Vector3 = t * faces[k]
				box = AABB(w, Vector3.ZERO) if box.size == Vector3.ZERO and k == 0 else box.expand(w)
		if wheel_of.has(mi):
			for v in mi.mesh.get_faces():
				low = minf(low, (t * v).y)
		var mat := mi.mesh.surface_get_material(0)
		var own_mat: Material = null # yalnız değiştirilen malzeme zorlanır: çok yüzeyli meshte hepsine ilki basılıyordu
		if String(mi.name).contains("Optics") and mat is BaseMaterial3D:
			var lit := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			lit.emission_enabled = true
			lit.emission = lit.albedo_color # varsayılan siyah: doku ışığı hiç görünmüyordu
			lit.emission_texture = lit.albedo_texture
			lit.emission_energy_multiplier = 2.5
			own_mat = lit
		if String(mi.name).contains("_Body_") and mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture == null:
			# dokusuz boya (düz renk): boya shader'ı dokudan okur, rengi küçük bir dokuya yazılır
			var flat := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
			var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
			img.fill(flat.albedo_color)
			flat.albedo_texture = ImageTexture.create_from_image(img)
			flat.albedo_color = Color.WHITE
			own_mat = flat
		# tekerlek parçaları "wheel<tekerlek>_<sıra>": aynı ad iki kez verilirse Godot yeniden adlandırıyor
		var part_name := "wheel%d_%d" % [wheel_of[mi], parts.size()] if wheel_of.has(mi) else String(mi.name)
		parts.append([mi.mesh, t, own_mat, part_name])
	# yere oturt ve ortala
	var shift := Vector3(-box.get_center().x, -low, -box.get_center().z)
	for p in parts:
		p[1] = Transform3D(Basis(), shift) * p[1]
	_cars[nm] = {"parts": parts, "half_w": box.size.x * 0.5, "half_l": box.size.z * 0.5, "top": box.end.y - low}
