# Copyright (c) 2026 bercedev (https://github.com/bercedev)
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

# Örnek (cars/<ad>/<ad>.glb için):
#   blender -b --python tools/prep_car.py -- indirilen.glb cars/m4/m4.glb '{"scale":1,"paint":"Car_Paint","target":40000,"wheel_tris":2500}'
# Sonra cars/<ad>/<ad>.glb.import içinde use_name_suffixes ve use_node_type_suffixes false olmalı, ad pack.gd SINGLES listesine.
# Blender: araba GLB'sini oyuna hazırlar. blender -b --python prep.py -- giriş.glb çıkış.glb '<json>'
# json: scale, split (tek mesh'te birden çok tekerlek varsa ad/malzeme regex'i), paint, optics (malzeme regex),
# target (toplam üçgen), tex (en büyük doku kenarı)
import bpy, bmesh, sys, re, json
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
src, dst, cfg = a[0], a[1], json.loads(a[2])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)

def meshes():
    return [o for o in bpy.data.objects if o.type == 'MESH']

def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)

def select(objs, active=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]

def bbox(o):
    w = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(v.x for v in w), min(v.y for v in w), min(v.z for v in w)))
    hi = Vector((max(v.x for v in w), max(v.y for v in w), max(v.z for v in w)))
    return lo, hi

def key(o):
    return o.name + "|" + "|".join(m.name for m in o.data.materials if m)

# ebeveynsiz, tek kullanıcılı, dönüşümleri uygulanmış meshler; ölçek
select(meshes())
bpy.ops.object.make_single_user(object=True, obdata=True)
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
for o in list(bpy.data.objects):
    if o.type != 'MESH':
        bpy.data.objects.remove(o)
for o in meshes():
    o.scale = o.scale * cfg.get("scale", 1.0)
    o.location = o.location * cfg.get("scale", 1.0)
select(meshes())
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# recolor: {"malzeme regex": [r, g, b]} — dokusuz modellerde beyaz kalan koltuk, lastik vb.
for pat, rgb in cfg.get("recolor", {}).items():
    for mat in bpy.data.materials:
        if re.search(pat, mat.name) and mat.node_tree:
            for n in mat.node_tree.nodes:
                if n.type == 'BSDF_PRINCIPLED':
                    n.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)

# modelde tek yedek tekerlek varsa (oyun modlarında tekerlek kodla kopyalanır) dört yuvaya kopyalanır.
# spare: {"match": nesne adı regex'i, "at": [[x, y, z] x4], "out": yedeğin dış yüzünün x işareti}
if cfg.get("spare"):
    import math
    from mathutils import Matrix
    sp = cfg["spare"]
    parts = [o for o in meshes() if re.search(sp["match"], o.name)]
    lo = Vector((min(bbox(o)[0].x for o in parts), min(bbox(o)[0].y for o in parts), min(bbox(o)[0].z for o in parts)))
    hi = Vector((max(bbox(o)[1].x for o in parts), max(bbox(o)[1].y for o in parts), max(bbox(o)[1].z for o in parts)))
    c = (lo + hi) * 0.5
    for p in sp["at"]:
        p = Vector(p)
        m = Matrix.Translation(p - c)
        if (p.x > 0) != (sp["out"] > 0):
            m = Matrix.Translation(p) @ Matrix.Rotation(math.pi, 4, 'Z') @ Matrix.Translation(-p) @ m
        for o in parts:
            d = o.copy()
            d.data = o.data.copy()
            bpy.context.scene.collection.objects.link(d)
            d.matrix_world = m @ o.matrix_world
    for o in parts:
        bpy.data.objects.remove(o)
    select(meshes())
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# tek mesh'te birden çok tekerlek: gevşek parçalara ayır
if cfg.get("split"):
    for o in [o for o in meshes() if re.search(cfg["split"], key(o))]:
        select([o])
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.separate(type='LOOSE')
        bpy.ops.object.mode_set(mode='OBJECT')

# minik parçalar (yazı, vida) gider
for o in meshes():
    lo, hi = bbox(o)
    if max(hi - lo) < 0.04:
        bpy.data.objects.remove(o)

z0 = min(bbox(o)[0].z for o in meshes())
# tekerlek: yere değen, yüksekliği ve bir yatay boyu eşit (daire), öbür yatay boyu dar
wheels = []
for o in meshes():
    lo, hi = bbox(o)
    d = hi - lo
    if not (0.25 < d.z < 0.95 and lo.z - z0 < 0.12):
        continue
    if (abs(d.x - d.z) < d.z * 0.25 and d.y < 0.5) or (abs(d.y - d.z) < d.z * 0.25 and d.x < 0.5):
        wheels.append(o)
cs = [(bbox(o)[0] + bbox(o)[1]) * 0.5 for o in wheels]
cx = sum(c.x for c in cs) / len(cs)
cy = sum(c.y for c in cs) / len(cs)
groups = {}
for o, c in zip(wheels, cs):
    groups.setdefault((c.x > cx) * 2 + (c.y > cy), []).append(o)
# lastiğin kutusunun içinde kalan her şey (jant, göbek, kaliper) o tekerleğe
boxes = {k: [bbox(o) for o in v] for k, v in groups.items()}
for o in meshes():
    if o in wheels:
        continue
    lo, hi = bbox(o)
    for k, bs in boxes.items():
        if any(all(lo[i] > b[0][i] - 0.03 and hi[i] < b[1][i] + 0.03 for i in range(3)) for b in bs):
            groups[k].append(o)
            break
print("TEKERLEK", {k: len(v) for k, v in groups.items()})
assert len(groups) == 4, "dört köşede tekerlek bulunamadı"
for k, objs in groups.items():
    select(objs)
    bpy.ops.object.join()
    bpy.context.view_layer.objects.active.name = "wheel%d" % k

# gövde: malzemeye göre ayır ve topla
rest = [o for o in meshes() if not o.name.startswith("wheel")]
select(rest)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.separate(type='MATERIAL')
bpy.ops.object.mode_set(mode='OBJECT')
by_mat = {}
for o in meshes():
    if o.name.startswith("wheel"):
        continue
    m = o.data.materials[0].name if o.data.materials and o.data.materials[0] else "none"
    by_mat.setdefault(m, []).append(o)
for m, objs in by_mat.items():
    select(objs)
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    if re.search(cfg["paint"], m):
        o.name = "car_Body_" + m
    elif cfg.get("optics") and re.search(cfg["optics"], m):
        o.name = "car_Optics_" + m
    else:
        o.name = "m_" + m

# üçgen azalt: tekerlek ve gövde ayrı bütçe (bazı modellerde üçgenlerin çoğu tekerlekte; tek oranla gövde
# panelleri delik deşik oluyordu). target gövde için, wheel_tris tekerlek başına.
total = sum(tris(o) for o in meshes())
wl = [o for o in meshes() if o.name.startswith("wheel")]
bd = [o for o in meshes() if not o.name.startswith("wheel")]
for objs, budget in [(wl, cfg.get("wheel_tris", 2500) * 4), (bd, cfg["target"])]:
    ratio = min(1.0, budget / max(1, sum(tris(o) for o in objs)))
    for o in objs:
        if tris(o) < 300 or ratio >= 1.0:
            continue
        # aynı noktadaki ayrık köşeler birleşmeden indirgenirse paneller delik deşik oluyor
        select([o])
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.remove_doubles(threshold=0.0005)
        bpy.ops.object.mode_set(mode='OBJECT')
        goal = tris(o) * ratio
        for _ in range(8): # adım adım: tek seferde büyük oran şekli bozuyor (ilerlemezse bırak)
            before = tris(o)
            if before <= goal * 1.05:
                break
            mod = o.modifiers.new("dec", 'DECIMATE')
            mod.ratio = max(0.5, goal / before)
            bpy.ops.object.modifier_apply(modifier="dec")
            if tris(o) > before * 0.95:
                break
print("UCGEN", total, "->", sum(tris(o) for o in meshes()))

for im in bpy.data.images:
    s = max(im.size[0], im.size[1])
    if s > cfg.get("tex", 1024):
        f = cfg.get("tex", 1024) / s
        im.scale(max(1, int(im.size[0] * f)), max(1, int(im.size[1] * f)))

for o in meshes():
    print("PARCA %-40s %6d" % (o.name, tris(o)))
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB', export_apply=True)
