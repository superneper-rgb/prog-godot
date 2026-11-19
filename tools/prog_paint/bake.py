## Prog's painted texture, step 1 (Blender, headless batch job): lay out UVs on his model and bake the maps the painter works from.
## Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/prog_paint/bake.py -- assets/prog.glb F:/prog-godot-cache/prog_paint 2048
## The mesh comes from prog_mesh.py (the glb's own arrays), so every triangle corner maps back to the file's vertex it came from and write_glb.py can add the
## UVs to the file without touching its skeleton, skin or weights.
## Out (in the work folder): uv.npz (per surface, the UV of each triangle corner) and maps.npz (per texel: bind-pose position, outward face normal, smooth
## vertex colour, surface id, near and far ambient occlusion, pointiness, coverage), all in the glb's own Y-up space, rows bottom first as Blender stores them.
import bpy, bmesh, math, sys, os
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from prog_mesh import Model, NEVER_HIDDEN

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, OUT, RES = argv[0], argv[1], int(argv[2]) if len(argv) > 2 else 2048
SRC_IMG = argv[3] if len(argv) > 3 else None     # a texture whose colours are carried over through the file's TEXCOORD_1 (V3's head)
os.makedirs(OUT, exist_ok=True)
HEAD_Y = 1.55            # above this the islands are head (texel density raised: the face is what the camera comes close to)

for o in list(bpy.data.objects):        # (the startup cube would shadow his middle in the occlusion bake)
	bpy.data.objects.remove(o)
M = Model(GLB)
prims, verts, faces, face_src, mat_of_face = M.prims, M.verts, M.faces, M.face_src, M.sid
print("prog_paint: %d welded verts, %d faces" % (len(verts), len(faces)))
ob = M.make_object("prog")
me = ob.data
bpy.context.view_layer.objects.active = ob
ob.select_set(True)

# ---- UV layout: smart projection, even texel density, the head scaled up, packed
painted_ids = M.painted_ids()
bpy.ops.object.mode_set(mode="EDIT")
bpy.context.scene.tool_settings.use_uv_select_sync = True
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
for f in bm.faces:
	f.select_set(mat_of_face[f.index] in painted_ids)
bmesh.update_edit_mesh(me)
bpy.ops.uv.smart_project(angle_limit=math.radians(60.0), island_margin=0.0)
bpy.ops.uv.average_islands_scale()

# faces nobody ever sees (skin under the shirt and shorts): every ray from either side hits the body within a few cm. They keep a sliver of texture.
from mathutils import Vector
from mathutils.bvhtree import BVHTree
bvh = BVHTree.FromPolygons([Vector(v) for v in verts], faces)
gold = math.pi * (3.0 - math.sqrt(5.0))
hemi = []
for k in range(20):
	z = 1.0 - (k + 0.5) / 20.0
	r = math.sqrt(1.0 - z * z)
	hemi.append((r * math.cos(gold * k), r * math.sin(gold * k), z))
hidden = np.zeros(len(faces), bool)
for fi, w in enumerate(faces):
	a, b, c = (Vector(verts[k]) for k in w)
	n = (b - a).cross(c - a)
	if n.length < 1e-12:
		continue
	n.normalize()
	t1 = (b - a).normalized()
	t2 = n.cross(t1)
	cen = (a + b + c) / 3.0
	escaped = False
	for p in (cen, cen.lerp(a, 0.6), cen.lerp(b, 0.6), cen.lerp(c, 0.6)):
		for s in (1.0, -1.0):
			for h in hemi:
				d = t1 * h[0] + t2 * h[1] + n * (h[2] * s)
				if bvh.ray_cast(p + n * (2e-4 * s), d, 0.3)[0] is None:
					escaped = True
					break
			if escaped:
				break
		if escaped:
			break
	hidden[fi] = not escaped
print("prog_paint: %d hidden faces" % hidden.sum())

# per UV island: scale about its own centre. The face gets the most texels, the back of the head and the hair less, hidden islands a sliver.
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.active
parent = list(range(len(bm.faces)))
def find(x):
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x
for e in bm.edges:
	lf = e.link_faces
	if len(lf) != 2 or not (lf[0].select and lf[1].select):
		continue
	ok = True
	for v in e.verts:
		u0 = next(l[uv].uv for l in lf[0].loops if l.vert == v)
		u1 = next(l[uv].uv for l in lf[1].loops if l.vert == v)
		if (u0 - u1).length > 1e-6:
			ok = False
	if ok:
		parent[find(lf[0].index)] = find(lf[1].index)
islands = {}
for f in bm.faces:
	if f.select:
		islands.setdefault(find(f.index), []).append(f)
for fs in islands.values():
	area = sum(f.calc_area() for f in fs)
	cen = sum((f.calc_center_median() * f.calc_area() for f in fs), Vector()) / max(area, 1e-12)
	names = {prims[mat_of_face[f.index]]["name"] for f in fs}
	if all(hidden[f.index] for f in fs) and not (names & set(NEVER_HIDDEN)):
		k = 0.15
	elif cen.y > HEAD_Y and "bk_tank" not in names:
		k = 2.6 if cen.z > 0.0 else 1.5
	elif abs(cen.x) > 0.45 and cen.y < 1.15:
		k = 1.3                                   # hands
	elif names == {"bk_tank"}:
		k = 1.35                                  # the tank: its ribs are painted, a few millimetres apart, and need the texels
	elif names & {"bk_boot", "bk_sole"}:
		k = 1.5                                   # the boots (boots.py): stitching, hardware and scuffs, and the camera often looks down at them
	else:
		k = 1.0
	if k == 1.0:
		continue
	uc = sum((l[uv].uv for f in fs for l in f.loops), Vector((0.0, 0.0))) / sum(len(f.loops) for f in fs)
	for f in fs:
		for l in f.loops:
			l[uv].uv = uc + (l[uv].uv - uc) * k
bmesh.update_edit_mesh(me)
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.003)
bm = bmesh.from_edit_mesh(me)
bm.faces.ensure_lookup_table()
uv = bm.loops.layers.uv.active
for f in bm.faces:                                # unpainted surfaces: off the image, so no bake ever writes over the atlas
	if mat_of_face[f.index] not in painted_ids:
		for l in f.loops:
			l[uv].uv = (l[uv].uv.x * 0.01 + 5.0, l[uv].uv.y * 0.01 + 5.0)
bmesh.update_edit_mesh(me)
bpy.ops.object.mode_set(mode="OBJECT")

# corner UVs back to the file's triangles (Blender keeps from_pydata's face order and corner order)
uvs = np.zeros(len(me.loops) * 2, np.float32)
me.uv_layers["UVMap"].data.foreach_get("uv", uvs)
uvs = uvs.reshape(-1, 2)
lstart = np.zeros(len(me.polygons), np.int64)
me.polygons.foreach_get("loop_start", lstart)
per = {}
for si, pr in enumerate(prims):
	per[si] = np.full((len(pr["I"]), 3, 2), np.nan, np.float32)
for fi, (si, t) in enumerate(face_src):
	per[si][t] = uvs[lstart[fi]:lstart[fi] + 3]
np.savez(os.path.join(OUT, "uv.npz"), names=np.array([p["name"] for p in prims]), **{"uv%d" % k: v for k, v in per.items()})

# ---- bakes
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.render.bake.margin = 24
scene.render.bake.margin_type = "EXTEND"
scene.render.bake.use_clear = True
if scene.world is None:
	scene.world = bpy.data.worlds.new("w")
scene.world.use_nodes = True
scene.world.light_settings.distance = 0.22

mat = bpy.data.materials.new("bake")
mat.use_nodes = True
nt = mat.node_tree
for n in list(nt.nodes):
	nt.nodes.remove(n)
outn = nt.nodes.new("ShaderNodeOutputMaterial")
emit = nt.nodes.new("ShaderNodeEmission")
nt.links.new(emit.outputs[0], outn.inputs[0])
img_node = nt.nodes.new("ShaderNodeTexImage")
nt.nodes.active = img_node
geo = nt.nodes.new("ShaderNodeNewGeometry")
attr_sid = nt.nodes.new("ShaderNodeAttribute")
attr_sid.attribute_name = "sid"
attr_vs = nt.nodes.new("ShaderNodeAttribute")
attr_vs.attribute_name = "vsmooth"
# position and normal are offset into positive values before the bake (position + 2, normal * 0.5 + 0.5)
addp = nt.nodes.new("ShaderNodeVectorMath")
addp.operation = "ADD"
addp.inputs[1].default_value = (2.0, 2.0, 2.0)
nt.links.new(geo.outputs["Position"], addp.inputs[0])
srcuv = nt.nodes.new("ShaderNodeUVMap")
srcuv.uv_map = "src"
srcimg = nt.nodes.new("ShaderNodeTexImage")
srcimg.extension = "CLIP"
if SRC_IMG:
	srcimg.image = bpy.data.images.load(SRC_IMG)
nt.links.new(srcuv.outputs[0], srcimg.inputs[0])
sep = nt.nodes.new("ShaderNodeSeparateXYZ")
nt.links.new(srcuv.outputs[0], sep.inputs[0])
gt = nt.nodes.new("ShaderNodeMath")
gt.operation = "GREATER_THAN"
gt.inputs[1].default_value = -0.5
nt.links.new(sep.outputs[0], gt.inputs[0])
muln = nt.nodes.new("ShaderNodeVectorMath")
muln.operation = "MULTIPLY_ADD"
muln.inputs[1].default_value = (0.5, 0.5, 0.5)
muln.inputs[2].default_value = (0.5, 0.5, 0.5)
nt.links.new(geo.outputs["Normal"], muln.inputs[0])      # (the shading normal: smooth on the head and neck, prog_mesh.smooth_skin; the face's own elsewhere)
ob.data.materials.append(mat)


def bake(name, src, kind="EMIT", samples=1):
	img = bpy.data.images.new(name, RES, RES, alpha=False, float_buffer=True)
	img.colorspace_settings.name = "Non-Color"
	img_node.image = img
	for l in list(emit.inputs[0].links):
		nt.links.remove(l)
	if src is not None:
		nt.links.new(src, emit.inputs[0])
	scene.cycles.samples = samples
	bpy.ops.object.bake(type=kind)
	px = np.zeros(RES * RES * 4, np.float32)
	img.pixels.foreach_get(px)
	print("prog_paint: baked", name)
	return px.reshape(RES, RES, 4)[:, :, :3]


pos = bake("pos", addp.outputs[0]) - 2.0
nrm = bake("nrm", muln.outputs[0]) * 2.0 - 1.0
vs = bake("vcol", attr_vs.outputs["Color"])
sid = bake("sid", attr_sid.outputs["Fac"])[:, :, 0]
pnt = bake("pnt", geo.outputs["Pointiness"])[:, :, 0]
src = bake("src", srcimg.outputs["Color"]) if SRC_IMG else np.zeros((RES, RES, 3), np.float32)
src_ok = bake("srcok", gt.outputs[0])[:, :, 0] if SRC_IMG else np.zeros((RES, RES), np.float32)
# occlusion from both sides of every face (some of the file's faces wind inwards; it is drawn double sided), near creases and the broad body shading.
# The open side is the outside: the normal map is turned to face it.
ao_n = bake("aon", None, "AO", 96)[:, :, 0]
scene.world.light_settings.distance = 0.7
ao_fn = bake("aofn", None, "AO", 64)[:, :, 0]
me.flip_normals()
ao_f = bake("aof", None, "AO", 64)[:, :, 0]
scene.world.light_settings.distance = 0.22
ao_b = bake("aob", None, "AO", 96)[:, :, 0]
me.flip_normals()
back = ao_b > ao_n + 0.02
nrm[back] *= -1.0
ao = np.maximum(ao_n, ao_b)
ao_far = np.where(back, ao_f, ao_fn)
# coverage: which texels lie on a face (the margins are filled by the bake's extend)
emit.inputs[0].default_value = (1, 1, 1, 1)
scene.render.bake.margin = 0
cov = bake("cov", None, "EMIT")[:, :, 0]
np.savez_compressed(os.path.join(OUT, "maps.npz"), pos=pos, nrm=nrm, vcol=vs, sid=sid, pnt=pnt, ao=ao, ao_far=ao_far, cov=cov, src=src, src_ok=src_ok,
	names=np.array([p["name"] for p in prims]), glb=np.array(os.path.abspath(GLB)))
print("prog_paint: done")
