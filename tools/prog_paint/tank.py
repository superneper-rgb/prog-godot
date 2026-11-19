## Prog's ribbed white tank top (user, 2026-11-16: "a proper ribbed white tank top with some mild stains"). It replaces V1's, which was a bib: a straight edge
## across his chest and across his back with two thin straps stuck on like overalls, and a gap above the jorts behind. This one is a classic A-shirt, built in
## code round his body as one surface:
##   - a grid cast out from inside him: rings round a vertical axis from the hem up to his chest, then a cap of rings fanning up over the shoulders from a
##     centre in his chest, so the grid also covers the tops of his shoulders where the straps cross;
##   - each ring is the convex hull of his torso (and of the jorts' waistband at the hem) pushed out a little, so the cloth bridges the hollows of his
##     back and sternum, and below his gut it hangs instead of tucking in after the skin;
##   - the outline (a deep U neck in front, a shallower scoop behind, narrow straps over the trapezius, deep round armholes, a hem over the waistband) is
##     a field over the surface; the grid is cut along it and its edge vertices are slid onto it, so the edges run clean whatever the grid does;
##   - every edge folds under, so the binding has thickness.
## Weights come from the skin under each vertex (torso, collarbone and upper-arm bones only). The ribs, binding and stains are paint (paint.py).
## Runs in Blender on the "Prog" object (glb space, Y up, front +Z, left +X) after jorts.run, before glb_out.write.
import bmesh, math
from mathutils import Vector, kdtree
from mathutils.bvhtree import BVHTree

# ---- shape (metres, glb space)
C_Y, C_Z = 1.24, -0.01                  # the cap's centre (inside his chest); the rings below are cast round the vertical through it
HEM_FRONT, HEM_BACK = 0.872, 0.892      # the hem, over the jorts' waistband (its top: 0.905 in front, 0.94 behind)
N_TH = 104                              # grid vertices round him
CYL_STEP = 0.0135                       # ring spacing up the body
CAP_STEP, CAP_MAX = 2.4, 84.0           # cap ring spacing and its last ring (degrees of elevation from the centre)
XS_F, XS_B = 0.152, 0.158               # strap centre line, distance from the middle, in front and behind
STRAP_TOP = 1.548                       # the highest a strap goes (over his trapezius, ~1.51 under it)
STRAP_W = 0.046                         # strap width (an A-shirt's is narrow: a big man's ~4.5 cm)
NECK_F, NECK_B = 1.352, 1.405           # the bottom of the neckline in front and behind
ROOT_F, ROOT_B = 1.425, 1.44            # where the neckline and the armhole meet the strap
ARM_LOW = 1.20                          # the bottom of the armhole, at the side seam (a few cm under his armpit)
EASE_TOP, EASE_HEM = 0.0045, 0.012      # how far the cloth stands off him: snug on the chest, a little looser over the gut
DENIM_CLEAR = 0.011                     # the hem stands this far off the jorts' waistband
HANG = 0.45                             # going down, the cloth may come in at most this much per metre (it hangs off the gut, never tucks under it)
FACING = 0.0042                         # thickness of the turned edges
TANK_BONES = ("pelvis", "spine1", "spine2", "chest", "clavicle", "upper_arm")      # (not the neck: with its share the strap tops lifted off his shoulders in flaps
                                                                                   # whenever his head moved, as V1's straps had: ProgV1Fix._meld_straps)


def _sst(a, b, x):
	t = min(max((x - a) / (b - a), 0.0), 1.0)
	return t * t * (3.0 - 2.0 * t)


def _hem_y(th):
	## th: radians round him (0 front, pi back); a slow wave so the hem does not read ruled
	back = (1.0 - math.cos(th)) * 0.5
	return HEM_FRONT + (HEM_BACK - HEM_FRONT) * back + 0.0025 * math.sin(th * 3.0 + 0.7)


def _hull_radii(dirs, pts):
	## convex hull of the 2D points round (0, 0), read back as a radius per direction
	P = sorted(set(pts))
	def cross(o, a, b):
		return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
	lo, hi = [], []
	for p in P:
		while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
			lo.pop()
		lo.append(p)
	for p in reversed(P):
		while len(hi) >= 2 and cross(hi[-2], hi[-1], p) <= 0:
			hi.pop()
		hi.append(p)
	H = lo[:-1] + hi[:-1]
	out = []
	for d in dirs:
		best = 0.0
		for k in range(len(H)):
			a, b = H[k], H[(k + 1) % len(H)]
			ex, ez = b[0] - a[0], b[1] - a[1]
			den = d[0] * ez - d[1] * ex
			if abs(den) < 1e-9:
				continue
			t = (a[0] * ez - a[1] * ex) / den
			u = (a[0] * d[1] - a[1] * d[0]) / den
			if t > 0.0 and -1e-6 <= u <= 1.0 + 1e-6:
				best = max(best, t)
		out.append(best)
	return out


def outline(p):
	## > 0 on the shirt, < 0 off it, roughly in metres. The panel (front and back, below the neckline and the armholes) and the straps.
	ax = abs(p.x)
	th = math.atan2(ax, p.z - C_Z)                                      # 0 front .. pi back, the same either side
	back = _sst(math.radians(70.0), math.radians(110.0), th)
	xs = XS_F + (XS_B - XS_F) * back
	hw = STRAP_W * 0.5
	root = ROOT_F + (ROOT_B - ROOT_F) * back
	neck = NECK_F + (NECK_B - NECK_F) * back
	# the neckline: a deep U from the middle up to the strap's inner edge
	a = min(ax / (xs - hw), 1.0)
	top_neck = neck + (root - neck) * a ** 2.3
	# the armhole: from the strap's outer edge straight down, round the bottom at the side seam (a quarter circle in angle and height)
	th_f = math.atan2(xs + hw, 0.215)                                   # the strap's outer edge in front and behind, as angles round him
	th_b = math.pi - math.atan2(xs + hw, 0.175)
	if th < math.pi * 0.5:
		u = (th - th_f) / (math.pi * 0.5 - th_f)
	else:
		u = (th_b - th) / (th_b - math.pi * 0.5)
	u = min(max(u, 0.0), 1.0)
	top_arm = ARM_LOW + (root - ARM_LOW) * (1.0 - math.sqrt(max(0.0, 1.0 - (1.0 - u) ** 2)))
	if ax <= xs - hw:
		top = top_neck
	elif u <= 0.0:
		top = root
	else:
		top = top_arm
	f_panel = top - p.y
	# the strap: a band round x = xs from just below its root up over the shoulder (in the cap, out of reach of the head and the arm)
	# (and never above the top of his shoulder: the cap's rays that go up the front and back of his neck pass the strap's x too, and grew flaps up it)
	f_strap = min(hw - abs(ax - xs), p.y - (root - 0.03), STRAP_TOP - p.y)
	return max(f_panel, f_strap)


def run(ob):
	me = ob.data
	mi = {m.name[2:] if m.name.startswith("P_") else m.name: i for i, m in enumerate(me.materials)}
	M_SKIN, M_TANK, M_DEN = mi["bk_skin"], mi["bk_tank"], mi["bk_shorts"]
	M_DARK = mi.get("bk_skin_dark", -1)                                 # (his navel: a dimple of its own surface, which poked through a shirt cast on the skin alone)
	gname = {g.index: g.name for g in ob.vertex_groups}
	gidx = {g.name: g.index for g in ob.vertex_groups}
	bm = bmesh.new()
	bm.from_mesh(me)
	dv = bm.verts.layers.deform.verify()
	# ---- V1's tank goes
	old = [f for f in bm.faces if f.material_index == M_TANK]
	bmesh.ops.delete(bm, geom=old, context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bm.faces.ensure_lookup_table()

	def top_bone(v):
		w = {gname[g]: x for g, x in v[dv].items() if x > 1e-4}
		return max(w, key=w.get) if w else ""

	def sub_bvh(faces):
		sb = bmesh.new()
		vm = {}
		for f in faces:
			vs = []
			for v in f.verts:
				if v not in vm:
					vm[v] = sb.verts.new(v.co)
				vs.append(vm[v])
			try:
				sb.faces.new(vs)
			except ValueError:
				pass
		return BVHTree.FromBMesh(sb), sb

	# his torso as the shirt sees it: the skin, less his forearms and hands (they hang beside his gut) and his head above the neck
	arm_low = ("forearm", "hand", "thumb", "index", "middle", "ring", "pinky", "head", "jaw", "hair")
	torso_f = [f for f in bm.faces if f.material_index in (M_SKIN, M_DARK) and 0.75 < f.calc_center_median().y < 1.62
		and not any(top_bone(v).startswith(arm_low) for v in f.verts)]
	torso, tb = sub_bvh(torso_f)
	denim, db = sub_bvh([f for f in bm.faces if f.material_index == M_DEN and f.calc_center_median().y > 0.82])
	# skin weights for the shirt: torso bones only, per skin vertex
	wpts, wsrc = [], []
	for f in torso_f:
		for v in f.verts:
			w = {gname[g]: x for g, x in v[dv].items() if x > 1e-4 and gname[g].startswith(TANK_BONES)}
			if w:
				wpts.append(v.co.copy())
				wsrc.append(w)
	wtree = kdtree.KDTree(len(wpts))
	for i, p in enumerate(wpts):
		wtree.insert(p, i)
	wtree.balance()

	# ---- the grid: rows from the hem (t = 0) up the body to the cap's centre, then up over the shoulders
	n_cyl = max(2, int(round((C_Y - HEM_FRONT) / CYL_STEP)))
	n_cap = int(CAP_MAX / CAP_STEP)
	NT = n_cyl + n_cap + 1
	ths = [2.0 * math.pi * k / N_TH for k in range(N_TH)]

	def ray(th, t):
		## origin and direction of the grid's ray at angle th round him and row t (a float: the snapping slides vertices between rows)
		if t <= n_cyl:
			hy = _hem_y(th)
			y = hy + (C_Y - hy) * (t / n_cyl)
			return Vector((0.0, y, C_Z)), Vector((math.sin(th), 0.0, math.cos(th)))
		e = math.radians((t - n_cyl) * CAP_STEP)
		return Vector((0.0, C_Y, C_Z)), Vector((math.sin(th) * math.cos(e), math.sin(e), math.cos(th) * math.cos(e)))

	R = [[0.0] * N_TH for _ in range(NT)]
	SK = [[0.0] * N_TH for _ in range(NT)]
	FLOOR = [[0.0] * N_TH for _ in range(NT)]                           # the least radius per grid vertex: off the skin, outside the waistband
	for ti in range(NT):
		for k, th in enumerate(ths):
			o, d = ray(th, ti)
			h = torso.ray_cast(o, d, 0.6)
			rs = (h[0] - o).length if h[0] is not None else None
			if rs is not None and o.y < 1.2:
				# and anything standing a little proud of that skin (the navel's dimple sat in front of it and showed through the shirt)
				h2 = torso.ray_cast(o + d * (rs + 0.05), -d, 0.05)
				if h2[0] is not None:
					rs = max(rs, (h2[0] - o).length)
			SK[ti][k] = rs if rs is not None else -1.0
		# fill misses from the neighbours round the ring
		row = SK[ti]
		good = [k for k in range(N_TH) if row[k] > 0.0]
		for k in range(N_TH):
			if row[k] <= 0.0 and good:
				kk = min(good, key=lambda g: min(abs(g - k), N_TH - abs(g - k)))
				row[k] = row[kk]
	for ti in range(NT):
		u = min(ti / n_cyl, 1.0)
		ease = EASE_HEM + (EASE_TOP - EASE_HEM) * _sst(0.0, 1.0, u * 1.6)
		r = [SK[ti][k] + ease for k in range(N_TH)]
		if ti <= n_cyl:
			# the hem rows: never inside the jorts' waistband
			for k, th in enumerate(ths):
				o, d = ray(th, ti)
				h = denim.ray_cast(o + d * 0.6, -d, 0.6)
				if h[0] is not None:
					r[k] = max(r[k], (h[0] - o).length + DENIM_CLEAR)
					FLOOR[ti][k] = (h[0] - o).length + DENIM_CLEAR * 0.8
			# bridge the hollows: the convex hull of the ring
			pts = [(r[k] * math.sin(th), r[k] * math.cos(th)) for k, th in enumerate(ths)]
			hr = _hull_radii([(math.sin(th), math.cos(th)) for th in ths], pts)
			r = [max(r[k], hr[k]) for k in range(N_TH)]
		R[ti] = r
	# hang: going down from the chest, the cloth comes in no faster than HANG per metre (it drapes off his gut and the small of his back)
	for ti in range(n_cyl - 1, -1, -1):
		for k, th in enumerate(ths):
			o0, _ = ray(th, ti)
			o1, _ = ray(th, ti + 1)
			R[ti][k] = max(R[ti][k], R[ti + 1][k] - HANG * (o1.y - o0.y))
	# soften: a few passes of smoothing on the radii (the skin is low-poly; cloth is not), never closer to the skin than a few millimetres
	for _ in range(3):
		Rn = [row[:] for row in R]
		for ti in range(NT):
			for k in range(N_TH):
				nb = [R[ti][(k - 1) % N_TH], R[ti][(k + 1) % N_TH]]
				if ti > 0:
					nb.append(R[ti - 1][k])
				if ti < NT - 1:
					nb.append(R[ti + 1][k])
				Rn[ti][k] = max(0.5 * R[ti][k] + 0.5 * sum(nb) / len(nb), SK[ti][k] + 0.003, FLOOR[ti][k])
		R = Rn

	def radius(th, t):
		## bilinear in the grid
		kf = (th % (2.0 * math.pi)) / (2.0 * math.pi) * N_TH
		k0 = int(math.floor(kf)) % N_TH
		k1 = (k0 + 1) % N_TH
		a = kf - math.floor(kf)
		t = min(max(t, 0.0), NT - 1.0)
		t0 = min(int(math.floor(t)), NT - 2)
		b = t - t0
		r0 = R[t0][k0] * (1.0 - a) + R[t0][k1] * a
		r1 = R[t0 + 1][k0] * (1.0 - a) + R[t0 + 1][k1] * a
		return r0 * (1.0 - b) + r1 * b

	def pos(th, t):
		o, d = ray(th, t)
		return o + d * radius(th, t)

	# ---- cut it along the outline
	G = [[pos(th, ti) for th in ths] for ti in range(NT)]
	Fv = [[outline(G[ti][k]) for k in range(N_TH)] for ti in range(NT)]
	keep = []
	for ti in range(NT - 1):
		for k in range(N_TH):
			k2 = (k + 1) % N_TH
			fs = (Fv[ti][k], Fv[ti][k2], Fv[ti + 1][k2], Fv[ti + 1][k])
			if sum(fs) * 0.25 > 0.0 and max(fs) > 0.0:
				keep.append((ti, k))
	used = {}
	for ti, k in keep:
		k2 = (k + 1) % N_TH
		for key in ((ti, k), (ti, k2), (ti + 1, k2), (ti + 1, k)):
			used[key] = True
	# edge vertices: those on a kept quad next to a dropped one (or on the hem row)
	kept = set(keep)
	edge = set()
	for ti, k in keep:
		k2 = (k + 1) % N_TH
		for (dt, dk, a, b) in ((-1, 0, (ti, k), (ti, k2)), (1, 0, (ti + 1, k), (ti + 1, k2)), (0, -1, (ti, k), (ti + 1, k)), (0, 1, (ti, k2), (ti + 1, k2))):
			nt, nk = ti + dt, (k + dk) % N_TH
			if nt < 0 or nt >= NT - 1 or (nt, nk) not in kept:
				edge.add(a)
				edge.add(b)
	# slide the edge vertices (not the hem's, which is a row of the grid already) onto the outline: Newton steps in grid space
	param = {key: [ths[key[1]], float(key[0])] for key in used}
	dth = 2.0 * math.pi / N_TH
	for key in edge:
		if key[0] == 0:
			continue
		th, t = param[key]
		for _ in range(8):
			f = outline(pos(th, t))
			if abs(f) < 2e-4:
				break
			gth = (outline(pos(th + dth * 0.25, t)) - outline(pos(th - dth * 0.25, t))) / (dth * 0.5)
			gt = (outline(pos(th, t + 0.25)) - outline(pos(th, t - 0.25))) / 0.5
			# along one grid direction only, the one the outline crosses more steeply per cell (a diagonal step let neighbours slide past each other where
			# the edge runs level, and folded the shirt: a spike at the bottom of the neckline)
			if gt * gt >= (gth * dth) ** 2:
				if abs(gt) < 1e-9:
					break
				sth, st = 0.0, -f / gt
			else:
				sth, st = -f / gth, 0.0
			# at most 0.7 of a cell
			L = math.sqrt((sth / dth) ** 2 + st ** 2)
			if L > 0.7:
				sth *= 0.7 / L
				st *= 0.7 / L
			th += sth
			t = min(max(t + st, 0.0), NT - 1.0)
		param[key] = [th, t]

	# ---- mesh it
	def weights_at(p):
		near = wtree.find_n(p, 6)
		acc = {}
		for (co, i, d) in near:
			kk = 1.0 / max(d, 0.004) ** 2
			for b, x in wsrc[i].items():
				acc[b] = acc.get(b, 0.0) + x * kk
		top = sorted(acc.items(), key=lambda e: -e[1])[:4]
		s = sum(x for _, x in top) or 1.0
		return {b: x / s for b, x in top}

	def new_vert(p):
		v = bm.verts.new(p)
		hit = torso.find_nearest(p)
		for b, x in weights_at(hit[0] if hit[0] is not None else p).items():
			if b in gidx:
				v[dv][gidx[b]] = x
		return v

	def placed(th, t):
		## over the shoulders the cap's rays graze his trapezius, and a small step up the grid jumps from shoulder to neck: the straps' ends lifted off him in
		## flaps. Up there a point standing more than a centimetre off his skin is pulled back onto it (a strap lies tight); the rest keep the grid's place.
		p = pos(th, t)
		k = _sst(1.40, 1.45, p.y)
		if k <= 0.0:
			return p
		hit = torso.find_nearest(p)
		if hit[0] is None:
			return p
		d = (p - hit[0]).length
		if d <= 0.011:
			return p
		return p.lerp(hit[0] + (p - hit[0]).normalized() * 0.0075, k * _sst(0.011, 0.016, d))

	VV = {}
	for key, (th, t) in param.items():
		VV[key] = new_vert(placed(th, t))
	faces = []

	def face(vs):
		u = []
		for v in vs:
			if v not in u:
				u.append(v)
		if len(u) < 3:
			return None
		try:
			fc = bm.faces.new(u)
		except ValueError:
			return None
		fc.material_index = M_TANK
		faces.append(fc)
		return fc

	for ti, k in keep:
		k2 = (k + 1) % N_TH
		face([VV[(ti, k)], VV[(ti, k2)], VV[(ti + 1, k2)], VV[(ti + 1, k)]])
	# edge vertices that slid onto the same spot: welded
	tank_v = list(set(v for f in faces for v in f.verts))
	bmesh.ops.remove_doubles(bm, verts=tank_v, dist=0.0025)
	faces = [f for f in faces if f.is_valid]
	bmesh.ops.recalc_face_normals(bm, faces=faces)
	# ---- the turned edges: every open edge folds straight under by FACING, so the binding has thickness. (A facing running back up the inside as well
	# folded out sideways at the strap tips, where the edge turns tightly, and stood off his shoulders as flaps.)
	bm.normal_update()
	tank_v = set(v for f in faces for v in f.verts)
	open_e = [e for e in bm.edges if e.is_boundary and all(v in tank_v for v in e.verts)]
	inner = {}
	for e in open_e:
		for v in e.verts:
			if v not in inner:
				inner[v] = new_vert(v.co - v.normal * FACING)
	for e in open_e:
		v0, v1 = e.verts
		face([v0, v1, inner[v1], inner[v0]])
	for f in faces:
		f.normal_update()
	bmesh.ops.triangulate(bm, faces=[f for f in faces if f.is_valid])
	bm.to_mesh(me)
	bm.free()
	tb.free()
	db.free()
	me.update()
	return {"grid": (NT, N_TH), "quads": len(keep), "edge_verts": len(edge), "open_edges": len(open_e)}
