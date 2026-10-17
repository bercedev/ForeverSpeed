# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

extends RefCounted

# Sahneyi koddan kurmak için ortak küçük yardımcılar (main.gd ve regions.gd kullanır).

static var streak_shader: Shader = preload("res://streak.gdshader")
static var _streaks := {} # renk + enerji -> yansıma malzemesi: aynı ışığın şeritleri tek malzemeyi paylaşır


static func mat(color: Color, rough := 0.5, metal := 0.0, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func plane(parent: Node3D, size: Vector2, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


# İki nokta arasına ince kutu: köprü halatı vb.
static func beam(parent: Node3D, a: Vector3, b: Vector3, thickness: float, m: Material) -> void:
	var mi := box(parent, Vector3(thickness, thickness, a.distance_to(b)), (a + b) * 0.5, m)
	mi.basis = Basis.looking_at(b - a)


# Islak yol yansıması: ışığın yerdeki izdüşümünden kameraya doğru uzanan parlak şerit.
static func streak(parent: Node3D, at: Vector3, color: Color, width: float, length: float, energy: float) -> MeshInstance3D:
	var key := "%s%.2f" % [color.to_html(), energy]
	if not _streaks.has(key):
		var m := ShaderMaterial.new()
		m.shader = streak_shader
		m.set_shader_parameter("color", color)
		m.set_shader_parameter("energy", energy)
		_streaks[key] = m
	var mi := plane(parent, Vector2(width, length), Vector3(at.x, 0.05, at.z + length * 0.5), _streaks[key])
	mi.layers = 2 # yansıma kamerası yalnız 1. katmanı çizer: sahte yansıma iki kez görünmesin
	return mi


static func multimesh(mesh: Mesh, points: Array) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		mm.set_instance_transform(i, Transform3D(Basis(), points[i]))
	return mm
