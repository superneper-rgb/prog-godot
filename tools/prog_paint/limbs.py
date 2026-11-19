## Prog's arms and hands made one with his body (user, 2026-11-15: they looked "disconnected like a roblox character"). V1's body is a set of closed shells
## pushed into each other (torso, each arm, each palm, every finger segment). Worked out step by step in the user's live Blender:
##   - a union alone leaves a V-notch between the top of the torso and the arm's cap, so a shoulder cap goes over it: the convex hull of the torso's
##     shoulder top and the arm's cap, cut lower toward the front and back so it runs down into the chest and back as a deltoid instead of ending in a shelf;
##   - each palm (a 12-face box) is fused onto its forearm with a hull from the forearm's last 7 cm to the palm's top;
##   - everything is one boolean union, the seams are rounded off (gently at the wrists, where stronger rounding dents the front), and the bone weights are
##     blended across them so a raised arm or a bent wrist stretches the skin rather than folding it.
## Runs in Blender on the "Prog" object that head_swap.run builds, before glb_out.write.
import bpy, bmesh
import numpy as np
from mathutils import Vector, kdtree

SEAM_SMOOTH = 0.04         # m round the seam that is rounded off
WEIGHT_BLEND = 0.07        # m round the seam the weights are blended over


def _components(bm, mi):
	seen, comps = set(), []
	for f in bm.faces:
		if f.material_index != mi or f in seen:
			continue
		stack, comp = [f], []
		seen.add(f)
		while stack:
			g = stack.pop()
			comp.append(g)
			for e in g.edges:
				for h in e.link_faces:
					if h.material_index == mi and h not in seen:
						seen.add(h)
						stack.append(h)
		comps.append(comp)
	return comps


def _box(comp):
	vs = {v for f in comp for v in f.verts}
	co = np.array([v.co[:] for v in vs])
	return co.min(0), co.max(0)


def _piece(name, comp):
	## a closed shell as its own object (positions only)
	vi, verts, faces = {}, [], []
	for f in comp:
		idx = []
		for v in f.verts:
			if v not in vi:
				vi[v] = len(verts)
				verts.append(v.co.copy())
			idx.append(vi[v])
		faces.append(idx)
	me = bpy.data.meshes.new(name)
	me.from_pydata(verts, [], faces)
	me.update()
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def _hull(name, pts):
	bm = bmesh.new()
	vs = [bm.verts.new(p) for p in pts]
	bmesh.ops.convex_hull(bm, input=vs, use_existing_faces=False)
	for v in [v for v in bm.verts if not v.link_faces]:
		bm.verts.remove(v)
	me = bpy.data.meshes.new(name)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(name, me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def _shoulder_cap(name, torso, arm, side):
	## over the notch: the torso's shoulder top and the arm's cap, the cut sloping down toward front and back
	def cut(co):      # (the back cut higher than the front: reaching far down the back, the cap stretched into a web when the arm went overhead)
		return 1.405 - (0.75 if co.z > 0.0 else 0.35) * max(abs(co.z) - 0.03, 0.0)
	pts = [v.co.copy() for v in {v for f in torso for v in f.verts} if v.co.x * side > 0.17 and v.co.y > cut(v.co)]
	pts += [v.co.copy() for v in {v for f in arm for v in f.verts} if v.co.y > cut(v.co)]
	return _hull(name, pts)


def _wrist(name, arm, palm):
	av = {v for f in arm for v in f.verts}
	pv = {v for f in palm for v in f.verts}
	ay = min(v.co.y for v in av)
	pt = max(v.co.y for v in pv)
	return _hull(name, [v.co.copy() for v in av if v.co.y < ay + 0.07] + [v.co.copy() for v in pv if v.co.y > pt - 0.045])


def _union(base, others):
	## The torso is open at the neck (the head sits on that ring), and the exact solver needs closed inputs: given the open torso it left a hole the size of
	## a hand in the right shoulder (user, 2026-11-16: "you can see through the shoulder"). So the neck is capped for the union and the cap taken out after.
	bm = bmesh.new()
	bm.from_mesh(base.data)
	ring = [v for e in bm.edges if e.is_boundary for v in e.verts]
	cap_y = sum(v.co.y for v in ring) / len(ring) if ring else None
	cap_r = max((Vector((v.co.x, v.co.z)).length for v in ring), default=0.0) + 1e-4
	bmesh.ops.holes_fill(bm, edges=bm.edges, sides=0)
	bm.to_mesh(base.data)
	bm.free()
	for o in others:
		m = base.modifiers.new("u_" + o.name, "BOOLEAN")
		m.operation = "UNION"
		m.solver = "EXACT"
		m.object = o
	dg = bpy.context.evaluated_depsgraph_get()
	me = bpy.data.meshes.new_from_object(base.evaluated_get(dg))
	if cap_y is not None:
		bm = bmesh.new()
		bm.from_mesh(me)
		cap = [f for f in bm.faces if all(abs(v.co.y - cap_y) < 1e-4 and Vector((v.co.x, v.co.z)).length < cap_r for v in f.verts)]
		bmesh.ops.delete(bm, geom=cap, context="FACES_ONLY")
		bm.to_mesh(me)
		bm.free()
	return me


def _bones(glb):
	import sys, os
	sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
	from prog_mesh import read_glb, acc
	j, B = read_glb(glb)
	sk = j["skins"][0]
	ibm = acc(j, B, sk["inverseBindMatrices"]).reshape(-1, 4, 4)
	return {j["nodes"][n]["name"]: Vector(np.linalg.inv(ibm[k].T)[:3, 3].tolist()) for k, n in enumerate(sk["joints"])}


def _sst(a, b, x):
	t = min(max((x - a) / (b - a), 0.0), 1.0)
	return t * t * (3.0 - 2.0 * t)


def _tree(comp, dv, gname):
	vs = list({v for f in comp for v in f.verts})
	t = kdtree.KDTree(len(vs))
	for i, v in enumerate(vs):
		t.insert(v.co, i)
	t.balance()
	return t, [{gname[g]: w for g, w in v[dv].items()} for v in vs]


def _near(tw, p):
	return tw[1][tw[0].find(p)[1]]


def _mix(a, b, t):
	return {g: a.get(g, 0.0) * (1.0 - t) + b.get(g, 0.0) * t for g in set(a) | set(b)}


def run(ob, glb):
	bone = _bones(glb)
	me = ob.data
	skin = [i for i, m in enumerate(me.materials) if m.name.endswith("bk_skin")][0]
	gname = {g.index: g.name for g in ob.vertex_groups}
	bm = bmesh.new()
	bm.from_mesh(me)
	dv = bm.verts.layers.deform.verify()
	uv_src = bm.loops.layers.uv.get("src")
	comps = _components(bm, skin)
	torso, arms, palms = None, [], []
	for c in comps:
		lo, hi = _box(c)
		if lo[0] < -0.28 and hi[0] > 0.28 and hi[1] > 1.45 and lo[1] < 0.85:
			torso = c
		elif len(c) > 150 and (lo[0] > 0.2 or hi[0] < -0.2) and hi[1] > 1.45:
			arms.append(c)
		elif len(c) <= 16 and abs((lo[0] + hi[0]) / 2) > 0.5 and lo[1] > 0.7 and hi[1] < 0.86 and (hi[2] - lo[2]) > 0.1:
			palms.append(c)
	if torso is None or len(arms) != 2 or len(palms) != 2:
		raise RuntimeError("limbs: expected a torso, two arms, two palms; found %s %d %d" % (torso is not None, len(arms), len(palms)))
	pieces = [torso] + arms + palms
	used = {f for c in pieces for f in c}
	# the weights before: per piece, a tree of its vertices and their weights
	src_pts, src_w = [], []
	for c in pieces:
		for v in {v for f in c for v in f.verts}:
			src_pts.append(v.co.copy())
			src_w.append({gname[g]: w for g, w in v[dv].items()})
	tree = kdtree.KDTree(len(src_pts))
	for i, p in enumerate(src_pts):
		tree.insert(p, i)
	tree.balance()
	# weights: every original point keeps its own, a point the union made on the seam takes half of each side's, then all are blended over the seam.
	# (Two rules tried first in the live Blender with the arms raised: nearest old vertex left a spike on the shoulder blade; torso-to-arm by position
	# along the hanging arm caught the side of the back below the shoulder and swung it out in two flaps.)
	t_torso = _tree(torso, dv, gname)
	sides = {}
	for arm in arms:
		sgn = 1.0 if _box(arm)[0][0] > 0 else -1.0
		sd = "L" if sgn > 0 else "R"
		palm = min(palms, key=lambda c: abs((_box(c)[0][0] + _box(c)[1][0]) / 2 - 0.57 * sgn))
		sides[sgn] = (_tree(arm, dv, gname), _tree(palm, dv, gname), bone["upper_arm." + sd], bone["forearm." + sd], bone["hand." + sd])
	orig = {tuple(round(c, 6) for c in p) for p in src_pts}
	own = {tuple(round(c, 6) for c in p): w for p, w in zip(src_pts, src_w)}

	tmp = [_piece("limb_torso", torso)] + [_piece("limb_arm%d" % k, c) for k, c in enumerate(arms)] + [_piece("limb_palm%d" % k, c) for k, c in enumerate(palms)]
	for k, arm in enumerate(arms):
		side = 1.0 if _box(arm)[0][0] > 0 else -1.0
		tmp.append(_shoulder_cap("limb_cap%d" % k, torso, arm, side))
		palm = min(palms, key=lambda c: abs(_box(c)[0][0] - _box(arm)[0][0]) if (_box(c)[0][0] > 0) == (side > 0) else 9.0)
		tmp.append(_wrist("limb_wrist%d" % k, arm, palm))
	merged = _union(tmp[0], tmp[1:])
	for o in tmp:
		bpy.data.objects.remove(o, do_unlink=True)

	# ---- the new skin: the rest of the model as it was, plus the fused shells
	out = bmesh.new()
	odv = out.verts.layers.deform.verify()
	osrc = out.loops.layers.uv.new("src")
	gi = {g.name: g.index for g in ob.vertex_groups}
	vmap = {}
	for f in bm.faces:
		if f in used:
			continue
		vs = []
		for v in f.verts:
			if v not in vmap:
				nv = out.verts.new(v.co)
				for g, w in v[dv].items():
					nv[odv][g] = w
				vmap[v] = nv
			vs.append(vmap[v])
		try:
			nf = out.faces.new(vs)
		except ValueError:
			continue
		nf.material_index = f.material_index
		if uv_src is not None:
			for l, lo_ in zip(nf.loops, f.loops):
				l[osrc].uv = lo_[uv_src].uv
	mbm = bmesh.new()
	mbm.from_mesh(merged)
	bpy.data.meshes.remove(merged)
	mv = {}
	fused = []
	for v in mbm.verts:
		nv = out.verts.new(v.co)
		mv[v] = nv
		fused.append(nv)
	for f in mbm.faces:
		try:
			nf = out.faces.new([mv[v] for v in f.verts])
		except ValueError:
			continue
		nf.material_index = skin
	mbm.free()
	bm.free()

	# ---- round the seam: vertices the union made are on it; those near it are smoothed toward their neighbours
	seam = [v for v in fused if tuple(round(c, 6) for c in v.co) not in orig]
	st = kdtree.KDTree(max(1, len(seam)))
	for i, v in enumerate(seam):
		st.insert(v.co, i)
	st.balance()
	dist = {}
	for v in fused:
		_, _, d = st.find(v.co)
		dist[v] = d if d is not None else 1e9
	zone = [v for v in fused if dist[v] < SEAM_SMOOTH]
	for it in range(8):
		new = {}
		for v in zone:
			nb = [e.other_vert(v) for e in v.link_edges]
			if not nb:
				continue
			avg = sum((n.co for n in nb), Vector()) / len(nb)
			k = (0.55 if v.co.y > 1.1 else 0.3) * (1.0 - dist[v] / SEAM_SMOOTH)      # (gentle at the wrists)
			new[v] = v.co.lerp(avg, k)
		for v, p in new.items():
			v.co = p

	W = {}
	for v in fused:
		p = v.co
		key = tuple(round(c, 6) for c in p)
		if key in own:
			W[v] = dict(own[key])                 # an original point keeps its own weights exactly
			continue
		t_arm, t_palm, S, E, Hj = sides[1.0 if p.x >= 0.0 else -1.0]
		if (p - Hj).length < 0.09:                # a seam point: half each side's
			W[v] = _mix(_near(t_arm, p), _near(t_palm, p), 0.5)
		else:
			W[v] = _mix(_near(t_torso, p), _near(t_arm, p), 0.5)
	blend = [v for v in fused if dist[v] < WEIGHT_BLEND]
	for it in range(12):
		new = {}
		for v in blend:
			nb = [e.other_vert(v) for e in v.link_edges if e.other_vert(v) in W]
			if not nb:
				continue
			acc = dict(W[v])
			for n in nb:
				for g, w in W[n].items():
					acc[g] = acc.get(g, 0.0) + w
			tot = sum(acc.values())
			new[v] = {g: w / tot for g, w in acc.items() if w / tot > 0.005}
		W.update(new)
	for v in fused:
		ws = sorted(W[v].items(), key=lambda x: -x[1])[:4]
		tot = sum(w for _, w in ws) or 1.0
		for g, w in ws:
			v[odv][gi[g]] = w / tot
	out.normal_update()
	out.to_mesh(me)
	out.free()
	for p in me.polygons:
		p.use_smooth = False
	me.update()
	return {"seam_verts": len(seam), "smoothed": len(zone), "weight_blended": len(blend), "fused_verts": len(fused)}
