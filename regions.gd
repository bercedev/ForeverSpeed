# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends RefCounted

# Yol kenarı parçaları (40 m). Her parça dört bölgenin süsünü de taşır, yalnız biri görünür.
# Parça öne taşınırken o noktanın bölgesine göre configure() edilir; geçiş sisin ötesinde olur.

const Build := preload("res://build.gd")

enum { FOREST, CITY, BRIDGE, COAST }
const NAMES := ["ORMAN YOLU", "ŞEHİR", "KÖPRÜ", "SAHİL YOLU"]
const LEN := 1600.0 # bölge uzunluğu (m)
const GAP := 40.0 # parça uzunluğu (m)
const WIDEN := 3.5 # 3. şerit genişliği: sağ taraf bu kadar dışa kayar

static var _m := {}
static var _pine: ArrayMesh # gövde + üç katlı çam
static var _broad: ArrayMesh # gövde + yuvarlak taç
static var _signs: Array[Material] = [] # şehir neon tabelaları
# sol ve sağ bariyer dizileri; sağdakinin 3. şerit için açılan (in) ve kapanan (out) eğik hâlleri de var
static var _side := {}
static var _pools := {} # lamba ışığı lekesi malzemesi, renk başına
static var _harbor: MultiMesh


static func _setup() -> void:
	_m = {
		"grass": Build.mat(Color(0.01, 0.014, 0.01), 0.9),
		"concrete": Build.mat(Color(0.045, 0.045, 0.05), 0.7),
		"rock": Build.mat(Color(0.05, 0.05, 0.055), 0.9),
		"pole": Build.mat(Color(0.08, 0.08, 0.09), 0.6, 0.5),
		"leaf": Build.mat(Color(0.01, 0.025, 0.015), 0.9),
		"steel": Build.mat(Color(0.3, 0.32, 0.36), 0.35, 0.7),
		"cable": Build.mat(Color(0.6, 0.75, 1.0), 0.4, 0.0, 1.5), # halatlarda LED: gecede köprü seçilsin
		"deck": Build.mat(Color(0.1, 0.1, 0.11), 0.8),
		"red": Build.mat(Color(1.0, 0.05, 0.05), 0.5, 0.0, 8.0),
		"refl": Build.mat(Color(1.0, 0.7, 0.35), 0.5, 0.0, 3.0),
		"harbor": Build.mat(Color(1.0, 0.8, 0.5), 0.5, 0.0, 5.0),
		"rail": Build.mat(Color(0.35, 0.37, 0.4), 0.3, 0.7),
	}
	for k in ["water", "building"]:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://%s.gdshader" % k)
		_m[k] = sm
	# ağaçlar: iki yüzeyli tek mesh (gövde, yaprak); parça başına bir MultiMesh, örnek rengiyle ton farkı
	var trunk := Build.mat(Color(0.05, 0.035, 0.025), 0.9)
	var leaf := Build.mat(Color(1, 1, 1), 0.9)
	leaf.vertex_color_use_as_albedo = true
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.3
	cyl.height = 3.0
	cyl.radial_segments = 6
	cyl.rings = 1
	_pine = _tree_mesh(cyl, [[2.4, 4.4, 4.0], [1.9, 3.8, 6.0], [1.3, 3.0, 7.8]], false, trunk, leaf)
	_broad = _tree_mesh(cyl, [[2.3, 3.4, 4.6], [1.6, 2.6, 5.8]], true, trunk, leaf)
	for c in [Color(1.0, 0.2, 0.7), Color(0.3, 0.9, 1.0), Color(1.0, 0.55, 0.15), Color(0.6, 0.4, 1.0)]:
		_signs.append(Build.mat(c, 0.5, 0.0, 5.0))
	# Bariyer direkleri ve reflektörleri 4 m'de bir: hız hissini en çok bunlar verir.
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 0.8, 0.12)
	var refl := BoxMesh.new()
	refl.size = Vector3(0.05, 0.1, 0.12)
	# her yan için düz, açılan (in: yakında 0 uzakta 3,5 m dışa) ve kapanan (out: tersi) dizi; anahtar "r", "rin", "lout"...
	var shifts := {
		"": func(_z): return 0.0,
		"in": func(z): return WIDEN * (GAP * 0.5 - z) / GAP,
		"out": func(z): return WIDEN * (z + GAP * 0.5) / GAP,
	}
	for s in [-1.0, 1.0]:
		for key in shifts:
			var pp := []
			var rp := []
			for k in int(GAP / 4.0):
				var z := -GAP * 0.5 + 2.0 + k * 4.0
				var dx: float = s * shifts[key].call(z)
				pp.append(Vector3(s * 7.95 + dx, 0.4, z))
				rp.append(Vector3(s * 7.72 + dx, 0.65, z))
			_side[("l" if s < 0.0 else "r") + key] = [Build.multimesh(post, pp), Build.multimesh(refl, rp)]
	var bulb := BoxMesh.new()
	bulb.size = Vector3(0.4, 0.4, 0.4)
	var hp := []
	for k in 8:
		hp.append(Vector3(randf_range(50.0, 110.0), randf_range(0.5, 14.0), randf_range(-GAP * 0.5, GAP * 0.5)))
	_harbor = Build.multimesh(bulb, hp)


static func make_chunk(i: int) -> Node3D:
	if _m.is_empty():
		_setup()
	var p := Node3D.new()
	var s := -1.0 if i % 2 == 0 else 1.0
	var col := Color(1.0, 0.55, 0.2) if i % 4 != 3 else Color(0.75, 0.85, 1.0)

	var lamp := Node3D.new()
	lamp.name = "lamp"
	p.add_child(lamp)
	p.set_meta("lamp", lamp)
	Build.box(lamp, Vector3(0.22, 8.0, 0.22), Vector3(s * 8.6, 4.0, 0), _m.pole)
	Build.box(lamp, Vector3(2.6, 0.15, 0.15), Vector3(s * 7.4, 8.0, 0), _m.pole)
	var head := Build.mat(col, 0.5, 0.0, 8.0)
	Build.box(lamp, Vector3(0.9, 0.18, 0.45), Vector3(s * 6.3, 7.9, 0), head)
	p.set_meta("lamp_mat", head) # gece-gündüz için
	p.set_meta("lamp_right", s > 0.0)
	# Mobile renderer'da mesh başına en çok 8 omni ışık: tek parça yol 9 lambanın hepsini alamaz.
	# Yalnız 0,1,4,5,8. parçalar gerçek ışık verir (iki yana dağılır); ötekiler parlayan başlık ve yansımayla kalır.
	if i % 4 < 2:
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 2.5
		light.omni_range = 20.0
		light.position = Vector3(s * 6.2, 7.4, 0)
		lamp.add_child(light)
		p.set_meta("lamp_light", light)
	Build.streak(lamp, Vector3(s * 6.2, 0, 0), col, 1.4, 14.0, 1.2)
	# yola düşen turuncu ışık lekesi (4. katman: gündüz kamera çizmez)
	var key := col.to_html()
	if not _pools.has(key):
		var pm := ShaderMaterial.new()
		pm.shader = preload("res://pool.gdshader")
		pm.set_shader_parameter("color", col)
		_pools[key] = pm
	var pool := Build.plane(lamp, Vector2(13.0, 13.0), Vector3(s * 5.4, 0.045, 0), _pools[key])
	pool.layers = 4
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# bariyer: direkler, reflektörler ve korkuluk. Her yan kendi düğümünde: 3. şerit açılınca o yan dışa kayar.
	for side in ["l", "r"]:
		var holder := Node3D.new()
		holder.name = side + "side"
		p.add_child(holder)
		var mms: Array = []
		for k in 2:
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = _side[side][k]
			mmi.material_override = _m.pole if k == 0 else _m.refl
			holder.add_child(mmi)
			mms.append(mmi)
		var rail := Build.box(holder, Vector3(0.12, 0.3, GAP), Vector3((-7.8 if side == "l" else 7.8), 0.65, 0), _m.rail)
		p.set_meta("mm_" + side, mms)
		p.set_meta("rail_" + side, rail)

	var groups: Array[Node3D] = []
	for r in 4:
		var g := Node3D.new()
		g.name = "r%d" % r
		p.add_child(g)
		groups.append(g)
		var deco := Node3D.new() # tünelin içinde gizlenen kısım
		deco.name = "deco"
		g.add_child(deco)
		match r:
			FOREST: _forest(g, deco)
			CITY: _city(g, deco)
			BRIDGE: _bridge(g, deco, i)
			COAST: _coast(g, deco)
	p.set_meta("groups", groups)
	# configure görünmeyen bölgeleri ağaçtan çıkarır: parça silinirken onlar da silinsin
	p.tree_exiting.connect(func():
		for g in groups:
			if g.get_parent() == null:
				g.queue_free())
	return p


# 3. şerit: 0 normal, 1 geniş, 2 bu parçada açılıyor, 3 bu parçada kapanıyor; side +1 sağ (bizim yön),
# -1 sol (karşı yön). O yandaki direk, reflektör, korkuluk ve lamba yolla birlikte dışa kayar, öteki yan düz.
static func set_widen(p: Node3D, mode: int, side := 1) -> void:
	var ang := atan2(WIDEN, GAP)
	for s in [-1, 1]:
		var m := mode if s == side else 0
		var tag := "l" if s < 0 else "r"
		var mms: Array = p.get_meta("mm_" + tag)
		for k in 2:
			(mms[k] as MultiMeshInstance3D).multimesh = _side[tag + ["", "", "in", "out"][m]][k]
		(p.get_node(tag + "side") as Node3D).position.x = s * WIDEN if m == 1 else 0.0
		var rail: MeshInstance3D = p.get_meta("rail_" + tag)
		rail.position.x = s * (7.8 + (WIDEN * 0.5 if m >= 2 else 0.0))
		rail.rotation.y = -s * ang if m == 2 else (s * ang if m == 3 else 0.0)
		rail.scale.z = 1.0 / cos(ang) if m >= 2 else 1.0
		if p.get_meta("lamp_right") == (s > 0):
			(p.get_meta("lamp") as Node3D).position.x = s * [0.0, WIDEN, WIDEN * 0.5, WIDEN * 0.5][m]
		if s > 0: # sahil duvarı yalnız sağda
			var wall: MeshInstance3D = (p.get_meta("groups")[COAST] as Node3D).get_meta("wall")
			wall.position.x = 8.7 + [0.0, WIDEN, WIDEN * 0.5, WIDEN * 0.5][m]
			wall.rotation.y = rail.rotation.y
			wall.scale.z = rail.scale.z


# edge: parça bölgenin ilk ya da son birkaç parçasında (köprüde kıyı görünür, boşluğa açılmasın)
# Görünmeyen bölgeler ağaçtan çıkarılır: parçalar her karede kayar, ağaçtaki her düğümün konumu da güncellenir
# (tablette karenin büyük kısmı buydu). all: hepsi ağaçta ve görünür (açılışta shader ısıtma).
static func configure(p: Node3D, r: int, edge := false, all := false) -> void:
	p.set_meta("region", r)
	p.set_meta("edge", edge)
	var groups: Array = p.get_meta("groups")
	for k in groups.size():
		var g: Node3D = groups[k]
		var want := all or k == r
		if want and g.get_parent() == null:
			p.add_child(g)
		elif not want and g.get_parent() != null:
			p.remove_child(g)
	p.set_meta("deco", (groups[r] as Node3D).get_node("deco")) # her karede yol aramasın
	(groups[BRIDGE] as Node3D).get_node("shore").visible = edge or all
	(groups[BRIDGE] as Node3D).get_node("sea").visible = not edge or all


# Gövde ve yaprak katmanlarından iki yüzeyli ağaç. layers: [taban yarıçapı, boy, merkez yüksekliği].
static func _tree_mesh(trunk_mesh: Mesh, layers: Array, round: bool, trunk: Material, leaf: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(trunk_mesh, 0, Transform3D(Basis(), Vector3(0, 1.5, 0)))
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for l in layers:
		var part: PrimitiveMesh
		if round:
			var sp := SphereMesh.new()
			sp.radius = l[0]
			sp.height = l[1]
			sp.radial_segments = 10
			sp.rings = 5
			part = sp
		else:
			var cn := CylinderMesh.new()
			cn.top_radius = 0.0
			cn.bottom_radius = l[0]
			cn.height = l[1]
			cn.radial_segments = 8
			cn.rings = 1
			part = cn
		st.append_from(part, 0, Transform3D(Basis(), Vector3(0, l[2], 0)))
	st.commit(mesh)
	mesh.surface_set_material(0, trunk)
	mesh.surface_set_material(1, leaf)
	return mesh


# Orman: iki sıra ağaç, çoğu çam. İlk sıra 14,5 m'den başlar: 3. şerit açılınca yola taşmasın.
static func _forest(g: Node3D, deco: Node3D) -> void:
	for s in [-1.0, 1.0]:
		Build.plane(g, Vector2(140, GAP), Vector3(s * 78.0, -0.05, 0), _m.grass).layers = 2
	for kind in [_pine, _broad]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = kind
		var n := 10 if kind == _pine else 4
		mm.instance_count = n
		for k in n:
			var side := -1.0 if k % 2 == 0 else 1.0
			var near := 14.5
			var x := side * (randf_range(near, near + 7.0) if k < n / 2 else randf_range(near + 8.0, near + 24.0))
			var sc := randf_range(0.8, 1.5)
			var t := Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, 0, randf_range(-GAP * 0.5, GAP * 0.5)))
			mm.set_instance_transform(k, t)
			mm.set_instance_color(k, Color(0.012, 0.03, 0.016).lerp(Color(0.03, 0.045, 0.02), randf()))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		deco.add_child(mmi)


# Şehir: binaların bir kısmında çatı katı ve kırmızı ışıklı anten, yola bakan cephede neon tabela.
static func _city(g: Node3D, deco: Node3D) -> void:
	for s in [-1.0, 1.0]:
		Build.plane(g, Vector2(140, GAP), Vector3(s * 78.0, -0.05, 0), _m.concrete).layers = 2
		for z in [-10.0, 10.0]:
			var w := randf_range(8.0, 16.0)
			var h := randf_range(12.0, 55.0)
			var d := randf_range(10.0, 18.0)
			var face: float = s * (13.0 + randf() * 6.0) # yola bakan cephe
			var cx: float = face + s * w * 0.5
			var b := Build.box(deco, Vector3(w, h, d), Vector3(cx, h * 0.5, z), _m.building)
			b.set_instance_shader_parameter("seed", randf() * 100.0)
			b.set_instance_shader_parameter("h", h)
			if randf() < 0.5:
				var rh := randf_range(2.5, 6.0)
				var r := Build.box(deco, Vector3(w * 0.6, rh, d * 0.6), Vector3(cx, h + rh * 0.5, z), _m.building)
				r.set_instance_shader_parameter("seed", randf() * 100.0)
				r.set_instance_shader_parameter("h", rh)
				h += rh
			if randf() < 0.35:
				Build.box(deco, Vector3(0.2, 6.0, 0.2), Vector3(cx, h + 3.0, z), _m.pole)
				Build.box(deco, Vector3(0.35, 0.35, 0.35), Vector3(cx, h + 6.1, z), _m.red)
			if randf() < 0.45:
				Build.box(deco, Vector3(0.15, randf_range(1.2, 2.2), randf_range(4.0, 7.0)),
					Vector3(face - s * 0.1, randf_range(6.0, 14.0), z + randf_range(-2.0, 2.0)), _signs.pick_random())


# Eğik askılı köprü: güverte, aşağıda su, iki parçada bir kule ve halatlar.
static func _bridge(g: Node3D, deco: Node3D, i: int) -> void:
	Build.box(g, Vector3(17.8, 1.6, GAP), Vector3(0, -0.85, 0), _m.deck).layers = 2 # yansımayı kapatmasın
	var sea := Node3D.new()
	sea.name = "sea"
	g.add_child(sea)
	Build.plane(sea, Vector2(400, GAP), Vector3(0, -14.0, 0), _m.water)
	# köprü girişi ve çıkışı: iki yanda kıyı (toprak, kaya, çam); configure açar
	var shore := Node3D.new()
	shore.name = "shore"
	shore.visible = false
	g.add_child(shore)
	for s in [-1.0, 1.0]:
		Build.plane(shore, Vector2(140, GAP), Vector3(s * 78.0, -0.05, 0), _m.grass).layers = 2
		var r := Build.box(shore, Vector3(randf_range(4.0, 8.0), randf_range(2.0, 5.0), randf_range(5.0, 9.0)),
			Vector3(s * randf_range(13.0, 20.0), 0.5, randf_range(-12.0, 12.0)), _m.rock)
		r.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _pine
	mm.instance_count = 8
	for k in 8:
		var side := -1.0 if k % 2 == 0 else 1.0
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * randf_range(0.8, 1.4)),
			Vector3(side * randf_range(15.0, 40.0), 0, randf_range(-GAP * 0.5, GAP * 0.5))))
		mm.set_instance_color(k, Color(0.012, 0.03, 0.016).lerp(Color(0.03, 0.045, 0.02), randf()))
	var trees := MultiMeshInstance3D.new()
	trees.multimesh = mm
	shore.add_child(trees)
	for s in [-1.0, 1.0]: # iki yanda uzak kıyı ışıkları: denizin yeri belli olsun
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = _harbor
		mmi.material_override = _m.harbor
		mmi.position.x = s * 60.0
		mmi.scale.x = s
		deco.add_child(mmi)
	if i % 2 != 0:
		return
	for s in [-1.0, 1.0]:
		Build.box(deco, Vector3(1.4, 38.0, 1.4), Vector3(s * 10.5, 5.0, 0), _m.steel)
		for z in [-16.0, -8.0, 8.0, 16.0]:
			Build.beam(deco, Vector3(s * 10.5, 21.0, 0), Vector3(s * 8.6, 0.6, z), 0.08, _m.cable)
	Build.box(deco, Vector3(22.4, 1.2, 1.4), Vector3(0, 23.0, 0), _m.steel)
	Build.box(deco, Vector3(0.5, 0.5, 0.5), Vector3(0, 24.0, 0), _m.red)


# Solda kayalık, sağda deniz ve uzakta liman ışıkları.
static func _coast(g: Node3D, deco: Node3D) -> void:
	Build.plane(g, Vector2(140, GAP), Vector3(-78.0, -0.05, 0), _m.rock).layers = 2
	var wall := Build.box(g, Vector3(1.0, 1.6, GAP), Vector3(8.7, -0.8, 0), _m.concrete) # yol ile deniz arasındaki duvar
	wall.layers = 2
	g.set_meta("wall", wall)
	Build.plane(g, Vector2(300, GAP), Vector3(159.2, -1.2, 0), _m.water)
	for k in 3:
		var r := Build.box(deco, Vector3(randf_range(6.0, 14.0), randf_range(5.0, 16.0), randf_range(6.0, 12.0)),
			Vector3(-randf_range(14.0, 30.0), 1.0, randf_range(-14.0, 14.0)), _m.rock)
		r.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _harbor
	mmi.material_override = _m.harbor
	deco.add_child(mmi)
