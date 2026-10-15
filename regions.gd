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

static var _m := {}
static var _cone: CylinderMesh
static var _posts: MultiMesh
static var _refls: MultiMesh
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
	}
	for k in ["water", "building"]:
		var sm := ShaderMaterial.new()
		sm.shader = load("res://%s.gdshader" % k)
		_m[k] = sm
	_cone = CylinderMesh.new()
	_cone.top_radius = 0.0
	_cone.bottom_radius = 1.8
	_cone.height = 7.0
	# Bariyer direkleri ve reflektörleri 4 m'de bir: hız hissini en çok bunlar verir.
	var post := BoxMesh.new()
	post.size = Vector3(0.12, 0.8, 0.12)
	var refl := BoxMesh.new()
	refl.size = Vector3(0.05, 0.1, 0.12)
	var pp := []
	var rp := []
	for k in int(GAP / 4.0):
		for s in [-1.0, 1.0]:
			var z := -GAP * 0.5 + 2.0 + k * 4.0
			pp.append(Vector3(s * 7.95, 0.4, z))
			rp.append(Vector3(s * 7.72, 0.65, z))
	_posts = Build.multimesh(post, pp)
	_refls = Build.multimesh(refl, rp)
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
	for pair in [[_posts, _m.pole], [_refls, _m.refl]]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = pair[0]
		mmi.material_override = pair[1]
		p.add_child(mmi)

	for r in 4:
		var g := Node3D.new()
		g.name = "r%d" % r
		p.add_child(g)
		var deco := Node3D.new() # tünelin içinde gizlenen kısım
		deco.name = "deco"
		g.add_child(deco)
		match r:
			FOREST: _forest(g, deco)
			CITY: _city(g, deco)
			BRIDGE: _bridge(g, deco, i)
			COAST: _coast(g, deco)
	return p


static func configure(p: Node3D, r: int) -> void:
	p.set_meta("region", r)
	p.set_meta("deco", p.get_node("r%d/deco" % r)) # her karede yol aramasın
	for k in 4:
		p.get_node("r%d" % k).visible = k == r


static func _forest(g: Node3D, deco: Node3D) -> void:
	for s in [-1.0, 1.0]:
		Build.plane(g, Vector2(140, GAP), Vector3(s * 78.0, -0.05, 0), _m.grass)
	for k in 4:
		var t := MeshInstance3D.new()
		t.mesh = _cone
		t.material_override = _m.leaf
		var sc := randf_range(0.7, 1.4)
		var side := -1.0 if k < 2 else 1.0
		t.scale = Vector3.ONE * sc
		t.position = Vector3(side * randf_range(11.0, 22.0), 3.5 * sc, randf_range(-GAP * 0.5, GAP * 0.5))
		deco.add_child(t)


static func _city(g: Node3D, deco: Node3D) -> void:
	for s in [-1.0, 1.0]:
		Build.plane(g, Vector2(140, GAP), Vector3(s * 78.0, -0.05, 0), _m.concrete)
		for z in [-10.0, 10.0]:
			var w := randf_range(8.0, 16.0)
			var h := randf_range(12.0, 55.0)
			var b := Build.box(deco, Vector3(w, h, randf_range(10.0, 18.0)), Vector3(s * (13.0 + w * 0.5 + randf() * 6.0), h * 0.5, z), _m.building)
			b.set_instance_shader_parameter("seed", randf() * 100.0)


# Eğik askılı köprü: güverte, aşağıda su, iki parçada bir kule ve halatlar.
static func _bridge(g: Node3D, deco: Node3D, i: int) -> void:
	Build.box(g, Vector3(17.8, 1.6, GAP), Vector3(0, -0.85, 0), _m.deck)
	Build.plane(g, Vector2(400, GAP), Vector3(0, -14.0, 0), _m.water)
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
	Build.plane(g, Vector2(140, GAP), Vector3(-78.0, -0.05, 0), _m.rock)
	Build.box(g, Vector3(1.0, 1.6, GAP), Vector3(8.7, -0.8, 0), _m.concrete) # yol ile deniz arasındaki duvar
	Build.plane(g, Vector2(300, GAP), Vector3(159.2, -1.2, 0), _m.water)
	for k in 3:
		var r := Build.box(deco, Vector3(randf_range(6.0, 14.0), randf_range(5.0, 16.0), randf_range(6.0, 12.0)),
			Vector3(-randf_range(14.0, 30.0), 1.0, randf_range(-14.0, 14.0)), _m.rock)
		r.rotation = Vector3(randf_range(-0.3, 0.3), randf() * TAU, randf_range(-0.3, 0.3))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _harbor
	mmi.material_override = _m.harbor
	deco.add_child(mmi)
