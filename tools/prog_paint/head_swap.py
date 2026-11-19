## Prog's new head (user, 2026-11-15): V3's head (modelled from the character art: chin, jaw, nose, heavy-lidded eyes, mustache, a mouth with teeth and
## a tongue) put on V1's body and skeleton. Runs in Blender (live through the MCP, or headless): builds one object, "Prog", in glb space (Y up) with
##   - V1's body from prog.glb's own arrays (its head, eyes, nose and mouth slot removed above the neck ring at 1.51 m; of its hair only the long fall
##     down the back stays, under V3's sculpted hair: the user's mix, his length and swing with V3's shape and no side tufts),
##   - V3's head parts set back 2.5 cm, the neck's edge laid exactly onto V1's neck ring (one surface, so nothing can tear),
##   - vertex groups named after V1's bones plus a new "jaw" (lower lip, chin, lower teeth, tongue); the neck blends into V1's own neck weights,
##   - V3's texture coordinates kept in a "src" UV layer (bake.py carries V3's painted face over into the new texture).
## glb_out.py writes the result back into a glb with V1's skeleton untouched.
import bpy, bmesh, math, os, sys
import numpy as np
from mathutils import Vector, kdtree

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from prog_mesh import read_glb, acc

NECK_Y = 1.51                    # V1's neck ring the new head joins
HEAD_SHIFT = Vector((0.0, 0.0, -0.025))
# V3 part -> surface in the new model
V3_PARTS = {
	"prog_head_skin": "bk_skin", "prog_ear.L": "bk_skin", "prog_ear.R": "bk_skin", "prog_nose": "bk_skin",
	"prog_mouth": "bk_mouth", "prog_teeth_upper": "bk_teeth", "prog_teeth_lower": "bk_teeth", "prog_tongue": "bk_tongue",
	"prog_eye.L": "bk_eye_white", "prog_eye.R": "bk_eye_white",
	"prog_brow.L": "bk_hair", "prog_brow.R": "bk_hair", "prog_lash.L": "bk_hair", "prog_lash.R": "bk_hair",
	"prog_moustache": "bk_hair", "prog_hair": "bk_hair",
}
# V3 bone -> V1 bones (weight shares)
BONE_MAP = {
	"head": {"head": 1.0}, "neck": {"neck": 1.0}, "jaw": {"jaw": 1.0},
	"lip_lower.L": {"jaw": 1.0}, "lip_lower.R": {"jaw": 1.0}, "lip_lower_c": {"jaw": 1.0},
	"lip_upper.L": {"head": 1.0}, "lip_upper.R": {"head": 1.0}, "lip_upper_c": {"head": 1.0},
	"mouth_corner.L": {"head": 0.55, "jaw": 0.45}, "mouth_corner.R": {"head": 0.55, "jaw": 0.45},
	"teeth_upper": {"head": 1.0}, "teeth_lower": {"jaw": 1.0}, "tongue_base": {"jaw": 1.0}, "tongue_tip": {"jaw": 1.0},
}
V1_DROP = {"bk_nose", "bk_eye_white", "bk_pupil", "bk_iris", "bk_wrinkle"}
CURTAIN_Y = 1.64               # V1's back hair below this hangs under V3's sculpted hair
SURFACES = ["bk_skin", "bk_skin_dark", "bk_tank", "bk_shorts", "bk_shorts_fray", "bk_boot", "bk_sole", "bk_lace",
	"bk_hair", "bk_eye_white", "bk_mouth", "bk_teeth", "bk_tongue"]


def _v1_parts(glb):
	## V1's surfaces as (name, positions, triangles, joint names per vertex, weights per vertex)
	j, B = read_glb(glb)
	sk = j["skins"][0]
	jn = [j["nodes"][n]["name"] for n in sk["joints"]]
	out = []
	for p in j["meshes"][0]["primitives"]:
		at = p["attributes"]
		out.append((j["materials"][p["material"]]["name"], acc(j, B, at["POSITION"]), acc(j, B, p["indices"]).astype(np.int64).reshape(-1, 3),
			acc(j, B, at["JOINTS_0"]).astype(np.int64), acc(j, B, at["WEIGHTS_0"])))
	return out, jn


def smooth(a, b, x):
	t = min(max((x - a) / (b - a), 0.0), 1.0)
	return t * t * (3.0 - 2.0 * t)


def strong_chin(skin):
	## A strong chin with a jaw that separates face from neck (user, 2026-11-15: the chin ran straight down into the neck). Below a jawline that rises
	## from the chin (1.538 m) toward the jaw's angle under the ears, the throat is tucked back toward the neck's axis, easing to nothing at V1's neck ring
	## (so the join never opens); the chin itself comes 1.2 cm forward, below the lower lip only (the lips, teeth and tongue keep their places).
	for v in skin:
		x, y, z = v.co
		if z <= 0.0 or abs(x) > 0.14:
			continue
		u = min(abs(x) / 0.11, 1.0)
		yj = 1.538 + 0.07 * u * u
		under = 1.0 - smooth(yj - 0.014, yj, y)          # 1 on the throat, 0 on the face
		k = 1.0 - 0.24 * under * smooth(NECK_Y + 0.002, NECK_Y + 0.012, y)
		chin = (1.0 - smooth(0.03, 0.06, abs(x))) * smooth(yj, yj + 0.006, y) * (1.0 - smooth(1.565, 1.58, y))
		v.co.z = z * k + 0.012 * chin


def run(v1_glb, v3_glb, name="Prog"):
	old = bpy.data.objects.get(name)
	if old is not None:
		bpy.data.objects.remove(old)
	parts, jn = _v1_parts(v1_glb)
	bm = bmesh.new()
	uv_src = bm.loops.layers.uv.new("src")
	dvert = bm.verts.layers.deform.verify()
	groups = list(jn) + ["jaw"]
	gi = {n: i for i, n in enumerate(groups)}

	def add_tri(vs, mat):
		try:
			f = bm.faces.new(vs)
		except ValueError:
			return None
		f.material_index = SURFACES.index(mat)
		return f

	# ---- V1's body: welded per surface (copies of a corner share position; their weights are averaged as the game's own weld does)
	neck_ring = []
	v1_hair = []
	for nm, P, I, J, Wt in parts:
		if nm == "bk_hair":
			v1_hair = [(P[k], J[k], Wt[k]) for k in range(len(P))]
		if nm in V1_DROP:
			continue
		if nm == "bk_tank":
			# the straps' tops reached 1.52 m, above the neck join, and V3's narrower neck no longer hid them: their corners poked through as spikes
			P = P.copy()
			top = (P[:, 1] > 1.48) & (np.abs(P[:, 0]) < 0.17)
			P[top, 1] = np.minimum(P[top, 1], NECK_Y - 0.006)
			P[top, 0] *= 0.95
		key = np.round(P * 20000.0).astype(np.int64)
		uniq, inv = np.unique(key, axis=0, return_inverse=True)
		inv = inv.reshape(-1)
		verts = [None] * len(uniq)
		wsum = [dict() for _ in uniq]
		for k in range(len(P)):
			u = inv[k]
			if verts[u] is None:
				verts[u] = bm.verts.new(Vector(P[k].tolist()))
			for c in range(4):
				if Wt[k][c] > 0.0:
					wsum[u][jn[J[k][c]]] = wsum[u].get(jn[J[k][c]], 0.0) + float(Wt[k][c])
		for u, v in enumerate(verts):
			tot = sum(wsum[u].values()) or 1.0
			for b, w in wsum[u].items():
				v[dvert][gi[b]] = w / tot
		for tri in I:
			c = P[tri].mean(0)
			if nm == "bk_hair" and not (c[1] < CURTAIN_Y and c[2] < -0.05):
				continue                         # of V1's hair only the long fall down his back stays (the user likes its length and swing; the side tufts go)
			if nm == "bk_skin" and abs(c[0]) < 0.2 and P[tri][:, 1].min() > NECK_Y - 0.001:
				continue                         # V1's flat cap across the neck at the join (it notched the join where V3's neck lies on it)
			if nm == "bk_skin" and c[1] > NECK_Y + 0.001 and abs(c[0]) < 0.2:
				continue                         # V1's head and upper neck
			if nm == "bk_skin_dark" and c[1] > 1.3:
				continue                         # V1's eye sockets (the navel stays)
			vs = [verts[inv[k]] for k in tri]
			if len(set(vs)) == 3:
				add_tri(vs, nm)
		if nm == "bk_skin":
			neck_ring = [verts[u] for u in range(len(verts)) if abs(verts[u].co.y - NECK_Y) < 0.002 and abs(verts[u].co.x) < 0.17]

	# ---- V3's head parts, from a fresh import (glb space: Blender's import turned Y up into Z up)
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=v3_glb)
	imported = [o for o in bpy.data.objects if o not in before]
	tree = None
	if v1_hair:
		tree = kdtree.KDTree(len(v1_hair))
		for k, (p, _, _) in enumerate(v1_hair):
			tree.insert(Vector(p.tolist()), k)
		tree.balance()
	v3_bottom = []
	v3_skin = set()
	for o in imported:
		part = o.name.split(".0")[0]
		if o.type != "MESH" or part not in V3_PARTS:
			continue
		mat = V3_PARTS[part]
		mw = o.matrix_world
		me = o.data
		vmap = []
		for v in me.vertices:
			w = mw @ v.co
			q = Vector((w.x, w.z, -w.y)) + HEAD_SHIFT
			nv = bm.verts.new(q)
			if part == "prog_hair" and tree is not None:
				_, k, _ = tree.find(q)
				_, J, Wt = v1_hair[k]
				for c in range(4):
					if Wt[c] > 0.0:
						b = jn[J[c]]
						nv[dvert][gi[b]] = nv[dvert].get(gi[b], 0.0) + float(Wt[c])
			else:
				share = {}
				tot = 0.0
				for g in v.groups:
					gname = o.vertex_groups[g.group].name
					for b, s in BONE_MAP.get(gname, {"head": 1.0}).items():
						share[b] = share.get(b, 0.0) + g.weight * s
					tot += g.weight
				if tot <= 0.0:
					share = {"head": 1.0}
					tot = 1.0
				for b, w in share.items():
					nv[dvert][gi[b]] = w / tot
			vmap.append(nv)
		uvl = me.uv_layers.active.data if me.uv_layers else None
		new_faces = []
		for poly in me.polygons:
			vs = [vmap[i] for i in poly.vertices]
			if part == "prog_hair":
				c = sum((vmap[i].co for i in poly.vertices), Vector()) / len(poly.vertices)
				if c.y < 1.585 and c.z > -0.06:
					continue                     # V3's side-hair tips, which poked out of the thicker neck as dark spikes
			for t in range(1, len(vs) - 1):
				tri = [vs[0], vs[t], vs[t + 1]]
				li = [poly.loop_indices[0], poly.loop_indices[t], poly.loop_indices[t + 1]]
				f = add_tri(tri, mat)
				if f is None:
					continue
				new_faces.append(f)
				if uvl is not None:
					for l, k in zip(f.loops, li):
						l[uv_src].uv = uvl[k].uv
		if part == "prog_head_skin":
			v3_skin = set(vmap)
			bm.edges.ensure_lookup_table()
			edges = {e for f in new_faces for e in f.edges if e.is_boundary}
			v3_bottom = sorted({v for e in edges for v in e.verts if v.co.y < NECK_Y + 0.03}, key=lambda v: v.co.y)
	for o in imported:
		bpy.data.objects.remove(o, do_unlink=True)
	for a in [a for a in bpy.data.armatures if a.users == 0]:
		bpy.data.armatures.remove(a)

	# ---- the join: V3's neck edge laid onto V1's neck ring, each of its points on one of the ring's straight edges (no strip of skin between them, no gap),
	# with weights blended from that edge's two ends; the neck above eases onto it over the bottom 4 cm. (A zipped strip between the 16-point ring and
	# the 244-point edge made a jagged band of slivers under the chin, 2026-11-15.)
	def ang(v):
		return math.atan2(v.co.x, v.co.z)
	ring = sorted(neck_ring, key=ang)
	n1 = len(ring)
	ra = [ang(v) for v in ring]
	bottom = sorted({v for v in v3_bottom if v.is_boundary}, key=ang)
	n2 = len(bottom)
	ba = [ang(v) for v in bottom]

	def on_ring(a):
		## (segment start, segment end, t) of the ring edge at angle a
		for k in range(n1):
			a0, a1 = ra[k], ra[(k + 1) % n1] + (2 * math.pi if k == n1 - 1 else 0.0)
			aa = a if a >= a0 else a + 2 * math.pi
			if a0 <= aa <= a1:
				return k, (k + 1) % n1, (aa - a0) / max(a1 - a0, 1e-9)
		return n1 - 1, 0, 0.0

	def bottom_at(a):
		## V3's neck edge at angle a (between its two nearest points)
		for k in range(n2):
			a0, a1 = ba[k], ba[(k + 1) % n2] + (2 * math.pi if k == n2 - 1 else 0.0)
			aa = a if a >= a0 else a + 2 * math.pi
			if a0 <= aa <= a1:
				t = (aa - a0) / max(a1 - a0, 1e-9)
				return bottom[k].co.lerp(bottom[(k + 1) % n2].co, t)
		return bottom[0].co.copy()

	snapped = {}
	if n1 and n2:
		moves = []
		for v in v3_skin:
			if v.co.y > NECK_Y + 0.06:
				continue
			a = ang(v)
			k0, k1, t = on_ring(a)
			target = ring[k0].co.lerp(ring[k1].co, t)
			if v in bottom:
				moves.append((v, target))
				snapped[v] = (k0, k1, t)
			else:
				b0 = bottom_at(a)
				w = 1.0 - smooth(b0.y, b0.y + 0.04, v.co.y)
				if w > 0.0:
					moves.append((v, v.co + (target - b0) * w))
		for v, p in moves:
			v.co = p
		for f in [f for f in bm.faces if all(v in snapped for v in f.verts)]:
			bm.faces.remove(f)                   # V3's faces pressed flat onto the ring (zero height)
		strong_chin(v3_skin)
		# behind each jaw corner a strip of V3's skin folds back on itself (dark wedges under the ears): only those faces' points and their neighbours are
		# relaxed. (Relaxing the whole side of the neck pulled the jaw in and opened the mouth from the side.)
		for it in range(30):
			bm.normal_update()
			fold = set()
			for v in v3_skin:
				if v in snapped or not (1.52 < v.co.y < 1.6) or abs(v.co.x) < 0.06:
					continue
				for f in v.link_faces:
					c = f.calc_center_median()
					r = Vector((c.x, 0.0, c.z))
					if r.length > 1e-6 and f.normal.dot(r.normalized()) < -0.15:
						fold.update(f.verts)
			if not fold:
				break
			zone = {n for v in fold for e in v.link_edges for n in (v, e.other_vert(v)) if n in v3_skin and n not in snapped}
			new = {}
			for v in zone:
				nb = [e.other_vert(v) for e in v.link_edges]
				if nb:
					new[v] = v.co.lerp(sum((n.co for n in nb), Vector()) / len(nb), 0.5)
			for v, p in new.items():
				v.co = p
		print("head_swap: folds left", len(fold), "after", it + 1, "passes")
	made = len(snapped)
	# the neck blends into V1's own neck weights at the join, the head is the head's above it
	rk = kdtree.KDTree(len(ring))
	for k, v in enumerate(ring):
		rk.insert(Vector((v.co.x, 0.0, v.co.z)), k)
	rk.balance()
	bm.verts.ensure_lookup_table()
	for v in bm.verts:
		if v in ring or v.co.y > 1.62 or v.co.y < NECK_Y - 0.01 or abs(v.co.x) > 0.2:
			continue
		if not any(f.material_index == SURFACES.index("bk_skin") for f in v.link_faces):
			continue
		t = 1.0 - smooth(NECK_Y + 0.008, 1.6, v.co.y)
		if t <= 0.0:
			continue
		_, k, _ = rk.find(Vector((v.co.x, 0.0, v.co.z)))
		src = dict(ring[k][dvert].items())
		cur = dict(v[dvert].items())
		jaw = cur.get(gi["jaw"], 0.0)
		t *= 1.0 - jaw                       # (the chin keeps its jaw)
		for g in set(src) | set(cur):
			v[dvert][g] = cur.get(g, 0.0) * (1.0 - t) + src.get(g, 0.0) * t
	for v, (k0, k1, t) in snapped.items():   # the edge itself: exactly between the ring points it lies between
		w0 = dict(ring[k0][dvert].items())
		w1 = dict(ring[k1][dvert].items())
		for g in list(v[dvert].keys()):
			del v[dvert][g]
		for g in set(w0) | set(w1):
			v[dvert][g] = w0.get(g, 0.0) * (1.0 - t) + w1.get(g, 0.0) * t
	bm.normal_update()
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	for g in groups:
		ob.vertex_groups.new(name=g)
	for s in SURFACES:
		m = bpy.data.materials.get("P_" + s) or bpy.data.materials.new("P_" + s)
		me.materials.append(m)
	for p in me.polygons:
		p.use_smooth = False
	return ob, {"joined": made, "ring": n1, "bottom": n2, "verts": len(me.vertices), "faces": len(me.polygons)}


if __name__ == "__main__" and "--" in sys.argv:
	a = sys.argv[sys.argv.index("--") + 1:]
	print(run(a[0], a[1])[1])
