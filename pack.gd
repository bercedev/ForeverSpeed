# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends RefCounted

# "Generic passenger car pack" (Comrade1280, Sketchfab, CC BY 4.0; bkz. CREDITS.md). Yedi araç tek dosyada,
# daire şeklinde dizili; her gövde (gövde, cam, far meshleri) ve en yakın dört tekerleği ayrılır, metre
# cinsinden, yere oturmuş, ortalanmış ve önü +z olacak şekilde (Kenney modelleriyle aynı) hazırlanır.

const PATH := "res://cars/pack/car_pack.glb"
const SCALE := 1.0 # sahne kökü milimetreyi zaten 0.000889 ile çarpıyor: gerçek boyun yaklaşık %89u
# ön ucu dosyada -y'de olanlar (çeviri sonrası 180° döndürülür)
const FLIP := ["minivan", "offroad"]

static var _cars := {} # ad -> {parts: [[mesh, xform, material]], half_w, half_l, top}


static func names() -> Array:
	_load()
	return _cars.keys()


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
		for w in own:
			meshes += w.find_children("*", "MeshInstance3D", true, false)
		# Aracın ekseni geometriden: gövde node'larının dönüşü aracın boyuna denk gelmiyor. Dört tekerlek
		# merkezinin düzlemi yukarıyı, aynı akstaki iki tekerlek (en kısa kenar) yanı verir; boy ikisine dik.
		var pts: Array = own.map(func(w): return _global(w, scn).origin)
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
		for mi: MeshInstance3D in meshes:
			var t := Transform3D(basis, Vector3.ZERO) * frame * _global(mi, scn)
			if String(mi.name).contains("_Body_"):
				# ölçü gövdenin köşelerinden: bazı gövdeler dosyada kendi içinde döndürülmüş, kutusu şişiyor
				var faces := mi.mesh.get_faces()
				for k in range(0, faces.size(), 3):
					var w: Vector3 = t * faces[k]
					box = AABB(w, Vector3.ZERO) if box.size == Vector3.ZERO and k == 0 else box.expand(w)
			var mat := mi.mesh.surface_get_material(0)
			if String(mi.name).contains("Optics") and mat is BaseMaterial3D:
				var lit := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				lit.emission_enabled = true
				lit.emission_texture = lit.albedo_texture
				lit.emission_energy_multiplier = 2.5
				mat = lit
			var part_name := "wheel" if String(mi.get_parent().name).to_lower().begins_with("wheel_") else String(mi.name)
			parts.append([mi.mesh, t, mat, part_name])
		# yere oturt ve ortala
		var shift := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
		for p in parts:
			p[1] = Transform3D(Basis(), shift) * p[1]
		_cars[nm] = {"parts": parts, "half_w": box.size.x * 0.5, "half_l": box.size.z * 0.5, "top": box.size.y}
	scn.free()
