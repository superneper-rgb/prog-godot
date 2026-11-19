## Prog's boots (user, 2026-11-16: "upgrade the quality of his boots", brown). They replace V1's, which were a cylinder on a slab with the laces as a stack of
## boxes. A worn moc-toe work boot, built in code per foot, as chunky as V1's (the same footprint and shaft) so it still fits him and his moves:
##   - the upper: a grid of profiles fanned round the ankle, each running from the welt up over the toe box or the heel counter to the collar; profiles for the
##     front, the sides and the back blend by angle, so the toe box, the instep and the heel come out of one smooth surface;
##   - a padded collar rolled over the top and turned inside, a pull tab at the back;
##   - a lacing throat in front: the tongue sits a few millimetres under the eyestays, which stand proud; brass eyelets low, speed hooks high;
##   - laces: criss-crossed round cords lying on the tongue, a bow at the top with two loops and two hanging ends;
##   - the sole: a welt ledge standing out round the upper, a midsole, a lug outsole with notched edges, a heel block and an arch.
## Surfaces: bk_boot (the leather and its hardware: paint.py tells them apart by position), bk_sole, bk_lace. Weights come from V1's boot and its bones
## (foot, toe, shin), nearest first. Runs in Blender on the "Prog" object (glb space, Y up) after tank.run, before glb_out.write.
import bmesh, math
from mathutils import Vector, kdtree

# ---- shape (metres; local to each foot: x' outward from his midline, z forward, y up)
X0 = 0.265                       # the foot's centre line (V1's foot bone)
AX_C = (0.006, 0.0)              # the shaft's axis (x', z): the profiles fan round it
WELT_Y = 0.068                   # top of the welt (the sole stack below it)
COLLAR_Y = 0.428                 # top of the shaft
SHAFT_R = (0.135, 0.148)         # the shaft's radii across and along the foot
NA = 64                          # profiles round the boot
NM = 24                          # samples up each profile
# the footprint at the welt, through the toe tip and round the outside to the heel and back up the inside (x', z)
FOOT = [(0.02, 0.272), (0.09, 0.246), (0.133, 0.19), (0.147, 0.12), (0.136, 0.03), (0.108, -0.06), (0.094, -0.112), (0.062, -0.142), (0.0, -0.153),
	(-0.06, -0.143), (-0.088, -0.112), (-0.096, -0.05), (-0.104, 0.03), (-0.116, 0.11), (-0.11, 0.19), (-0.075, 0.246)]
EYES = [0.238, 0.268, 0.298, 0.332, 0.366, 0.4]     # lacing rows: brass eyelets (first three), speed hooks (the rest)
MOC_C, MOC_R = (0.018, 0.162), (0.082, 0.098)          # the moc toe's apron seam: an ellipse on top of the toe box (x', z)
THROAT_Y = 0.212                                       # where the lacing opening starts, over the instep
LACE_R = 0.0038


def _cr(p0, p1, p2, p3, t):
	t2, t3 = t * t, t * t * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


def _closed_spline(pts, n):
	## a smooth closed curve through pts (Vector 2D), n samples evenly in arc length
	m = len(pts)
	dense = []
	for i in range(m):
		p0, p1, p2, p3 = pts[(i - 1) % m], pts[i], pts[(i + 1) % m], pts[(i + 2) % m]
		for k in range(24):
			dense.append(_cr(p0, p1, p2, p3, k / 24.0))
	return dense


def _open_resample(pts, n):
	## Catmull-Rom through an open polyline, n samples evenly in arc length
	m = len(pts)
	ext = [pts[0] * 2.0 - pts[1]] + pts + [pts[-1] * 2.0 - pts[-2]]
	dense = []
	for i in range(m - 1):
		for k in range(16):
			dense.append(_cr(ext[i], ext[i + 1], ext[i + 2], ext[i + 3], k / 16.0))
	dense.append(pts[-1])
	L = [0.0]
	for i in range(1, len(dense)):
		L.append(L[-1] + (dense[i] - dense[i - 1]).length)
	out = []
	j = 0
	for s in range(n):
		tgt = L[-1] * s / (n - 1)
		while j < len(L) - 2 and L[j + 1] < tgt:
			j += 1
		f = (tgt - L[j]) / max(L[j + 1] - L[j], 1e-9)
		out.append(dense[j].lerp(dense[j + 1], min(max(f, 0.0), 1.0)))
	return out


def tilt(y):
	## the shaft leans in with his shin (the leg splays out from the knee to the foot): its top sits a few centimetres nearer his midline
	return -0.036 * _sst(0.2, COLLAR_Y, y)


def _sst(a, b, x):
	t = min(max((x - a) / (b - a), 0.0), 1.0)
	return t * t * (3.0 - 2.0 * t)


def _ray_hit(poly, c, d):
	## distance from c along the 2D direction d to the closed polyline poly (the farthest crossing)
	best = None
	for i in range(len(poly)):
		a, b = poly[i], poly[(i + 1) % len(poly)]
		e = b - a
		den = d.x * e.y - d.y * e.x
		if abs(den) < 1e-12:
			continue
		w = a - c
		t = (w.x * e.y - w.y * e.x) / den
		u = (w.x * d.y - w.y * d.x) / den
		if t > 0.0 and -1e-6 <= u <= 1.0 + 1e-6:
			best = t if best is None else max(best, t)
	return best


def profile(a, rw):
	## the profile at angle a round the shaft axis (0 toward the toe, +pi/2 outward), from the welt (r = rw) to the collar: (r, y) points
	c = math.cos(a)
	fw = max(c, 0.0) ** 1.4
	bw = max(-c, 0.0) ** 1.6
	sw = 1.0 - fw - bw
	rc = 1.0 / math.sqrt((math.sin(a) / SHAFT_R[0]) ** 2 + (c / SHAFT_R[1]) ** 2)
	# (radii only ever narrow from the foot into the shaft: an S between them read as the fold of a rubber boot)
	front = [(rw, WELT_Y), (rw + 0.004, 0.092), (rw - 0.01, 0.122), (rw - 0.045, 0.14), (max(rw - 0.1, rc + 0.022), 0.163), (rc + 0.006, 0.222), (rc - 0.002, 0.31), (rc, COLLAR_Y)]
	side = [(rw, WELT_Y), (rw + 0.003, 0.094), (rw - 0.002, 0.125), (rw - 0.009, 0.158), (rw * 0.35 + rc * 0.65, 0.205), (rc, 0.262), (rc - 0.003, 0.34), (rc, COLLAR_Y)]
	back = [(rw, WELT_Y), (rw + 0.004, 0.1), (rw + 0.001, 0.14), (rw - 0.006, 0.176), (rw * 0.3 + rc * 0.7, 0.226), (rc - 0.004, 0.28), (rc - 0.005, 0.345), (rc + 0.002, COLLAR_Y)]
	out = []
	for i in range(len(front)):
		r = front[i][0] * fw + side[i][0] * sw + back[i][0] * bw
		y = front[i][1] * fw + side[i][1] * sw + back[i][1] * bw
		out.append(Vector((r, y)))
	return out


def run(ob):
	me = ob.data
	mi = {m.name[2:] if m.name.startswith("P_") else m.name: i for i, m in enumerate(me.materials)}
	M_BOOT, M_SOLE, M_LACE = mi["bk_boot"], mi["bk_sole"], mi["bk_lace"]
	gname = {g.index: g.name for g in ob.vertex_groups}
	gidx = {g.name: g.index for g in ob.vertex_groups}
	bm = bmesh.new()
	bm.from_mesh(me)
	dv = bm.verts.layers.deform.verify()
	# ---- V1's boots: their weights are kept to skin the new ones, then they go
	old = [f for f in bm.faces if f.material_index in (M_BOOT, M_SOLE, M_LACE)]
	wpts, wsrc = [], []
	seen = set()
	for f in old:
		for v in f.verts:
			if v.index in seen:
				continue
			seen.add(v.index)
			w = {gname[g]: x for g, x in v[dv].items() if x > 1e-4}
			if w:
				wpts.append(v.co.copy())
				wsrc.append(w)
	bmesh.ops.delete(bm, geom=old, context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	wtree = kdtree.KDTree(len(wpts))
	for i, p in enumerate(wpts):
		wtree.insert(p, i)
	wtree.balance()

	def weights_at(p):
		acc = {}
		for (co, i, d) in wtree.find_n(p, 5):
			if co.x * p.x < 0.0:
				continue
			k = 1.0 / max(d, 0.005) ** 2
			for b, x in wsrc[i].items():
				acc[b] = acc.get(b, 0.0) + x * k
		top = sorted(acc.items(), key=lambda e: -e[1])[:4]
		s = sum(x for _, x in top) or 1.0
		return {b: x / s for b, x in top}

	faces = {M_BOOT: [], M_SOLE: [], M_LACE: []}

	def face(vs, mat):
		u = []
		for v in vs:
			if v not in u:
				u.append(v)
		if len(u) < 3:
			return
		try:
			fc = bm.faces.new(u)
		except ValueError:
			return
		fc.material_index = mat
		faces[mat].append(fc)

	stats = {}
	for s in (1.0, -1.0):
		def W(xl, y, z):
			## local (x' outward, y, z) to glb space for this foot
			return Vector((s * (X0 + xl), y, z))

		def vert(p):
			v = bm.verts.new(p)
			for b, x in weights_at(p).items():
				if b in gidx:
					v[dv][gidx[b]] = x
			return v

		cx, cz = AX_C
		cen = Vector((cx, cz))
		foot = [Vector(p) for p in FOOT]
		foot_dense = _closed_spline(foot, 0)
		angs = [2.0 * math.pi * k / NA for k in range(NA)]
		dirs = [Vector((math.sin(a), math.cos(a))) for a in angs]
		rws = [_ray_hit(foot_dense, cen, d) for d in dirs]
		# ---- the upper's grid: per angle, its profile resampled; then the throat (tongue under the eyestays) and the collar roll
		prof = []
		for k, a in enumerate(angs):
			pts = _open_resample(profile(a, rws[k]), NM)
			prof.append(pts)

		def open_half(y):
			## the lacing opening's half width (m) at height y
			return 0.0 if y < THROAT_Y else 0.019 + 0.015 * _sst(THROAT_Y, COLLAR_Y, y)

		G = []
		for k, a in enumerate(angs):
			ring = []
			for j, q in enumerate(prof[k]):
				r, y = q.x, q.y
				lat = r * math.sin(a)                                     # sideways distance from the front centre line
				if math.cos(a) > 0.0 and y > THROAT_Y - 0.01:
					h = open_half(y)
					d = abs(lat)
					if h > 0.0:
						r -= 0.005 * (1.0 - _sst(h - 0.004, h + 0.002, d)) * _sst(THROAT_Y - 0.01, THROAT_Y + 0.015, y)          # the tongue, under
						r += 0.0035 * math.exp(-((d - h - 0.008) / 0.006) ** 2) * _sst(THROAT_Y, THROAT_Y + 0.02, y) * _sst(COLLAR_Y, COLLAR_Y - 0.03, y)   # the eyestay's edge, proud
				# the moc toe: the apron's seam stands as a low ridge round the top of the toe box
				xl, zl = cx + math.sin(a) * r, cz + math.cos(a) * r
				em = math.sqrt(((xl - MOC_C[0]) / MOC_R[0]) ** 2 + ((zl - MOC_C[1]) / MOC_R[1]) ** 2)
				if y > 0.1 and zl > MOC_C[1] - 0.075:
					r += 0.0028 * math.exp(-((em - 1.0) / 0.045) ** 2) * _sst(0.1, 0.12, y)
				ring.append((r, y))
			G.append(ring)
		# collar: the top rolls outward (the padding) and turns in and down inside the shaft
		# (in the lacing opening the tongue rises above it instead, and leans forward a little)
		roll = [(0.006, 0.006), (0.004, 0.013), (-0.004, 0.016), (-0.013, 0.012), (-0.017, -0.012), (-0.016, -0.05)]
		tongue = [(-0.002, 0.016), (0.0, 0.034), (-0.002, 0.046), (-0.007, 0.046), (-0.009, 0.024), (-0.009, -0.04)]     # (it stays out in front of his shin)
		for k in range(NA):
			r0, y0 = G[k][-1]
			lat = r0 * math.sin(angs[k])
			tw = (1.0 - _sst(open_half(COLLAR_Y) - 0.008, open_half(COLLAR_Y) + 0.01, abs(lat))) * (math.cos(angs[k]) > 0.0)
			G[k][-1] = (r0 + 0.003 * (1.0 - tw), y0)
			for (dr, dy), (tr, ty) in zip(roll, tongue):
				G[k].append((r0 + dr + (tr - dr) * tw, y0 + dy + (ty - dy) * tw))
		NJ = len(G[0])

		def P(k, j):
			r, y = G[k][j]
			d = dirs[k]
			return W(cx + d.x * r + tilt(y), y, cz + d.y * r)

		UV = [[vert(P(k, j)) for j in range(NJ)] for k in range(NA)]
		for k in range(NA):
			k2 = (k + 1) % NA
			for j in range(NJ - 1):
				face([UV[k][j], UV[k2][j], UV[k2][j + 1], UV[k][j + 1]], M_BOOT)
		# pull tab: a loop of leather standing up at the back of the collar
		kb = NA // 2
		rb, yb = G[kb][NM - 1]
		tab = []
		for (dr, dy, dw) in ((0.004, -0.03, 0.013), (0.008, 0.0, 0.013), (0.009, 0.03, 0.012), (0.006, 0.048, 0.010), (-0.002, 0.052, 0.010)):
			row = []
			for side_ in (-1.0, 1.0):
				d = dirs[kb]
				t = Vector((d.y, -d.x))
				row.append(vert(W(cx + d.x * (rb + dr) + t.x * dw * side_ + tilt(yb + dy), yb + dy, cz + d.y * (rb + dr) + t.y * dw * side_)))
			tab.append(row)
		for i in range(len(tab) - 1):
			face([tab[i][0], tab[i][1], tab[i + 1][1], tab[i + 1][0]], M_BOOT)

		# ---- the sole: welt ledge, midsole, lug outsole (notched), heel block and arch, and the bottom
		def sole_ring(out, y, lug=0.0):
			ring = []
			for k in range(NA):
				d = dirs[k]
				r = rws[k] + out - (lug if k % 2 else 0.0)
				x, z = cx + d.x * r, cz + d.y * r
				yy = y
				if y < 0.03:
					yy = y + 0.013 * _sst(0.05, 0.0, z - 0.012) * _sst(-0.06, -0.03, z) if z > -0.06 else y     # the arch between the heel block and the ball
				ring.append(vert(W(x, yy, z)))
			return ring
		S0 = UV_bottom = [UV[k][0] for k in range(NA)]
		rings = [S0, sole_ring(0.0095, WELT_Y), sole_ring(0.0095, 0.056), sole_ring(0.006, 0.053), sole_ring(0.0065, 0.04), sole_ring(0.0068, 0.012, 0.0035),
			sole_ring(0.0045, 0.0, 0.0035)]
		for i in range(len(rings) - 1):
			A, B = rings[i], rings[i + 1]
			for k in range(NA):
				k2 = (k + 1) % NA
				face([A[k], A[k2], B[k2], B[k]], M_SOLE)
		# the bottom: an inner ring and a fan
		last = rings[-1]
		inner = []
		for k in range(NA):
			p = last[k].co
			q = W(cx + dirs[k].x * rws[k] * 0.55, 0.0, cz + dirs[k].y * rws[k] * 0.55)
			q.y = p.y
			inner.append(vert(q))
		for k in range(NA):
			k2 = (k + 1) % NA
			face([last[k], last[k2], inner[k2], inner[k]], M_SOLE)
		mid = vert(W(cx, 0.008, cz))
		for k in range(NA):
			face([inner[k], inner[(k + 1) % NA], mid], M_SOLE)

		# ---- lacing: eye positions either side of the opening, brass eyelets and hooks, criss-crossed laces, a bow
		def surf_at(lat, y):
			## the upper's outer surface point (local) at sideways offset lat from the front centre line and height y, and its outward normal
			best = None
			for k in range(NA):
				if math.cos(angs[k]) < 0.3:
					continue
				for j in range(NM - 1):
					p = P(k, j)
					l = (p.x - s * X0) * s - cx - tilt(p.y)
					e = (l - lat) ** 2 + (p.y - y) ** 2
					if best is None or e < best[0]:
						best = (e, k, j)
			_, k, j = best
			p = P(k, j)
			n = (P(k, j) - W(cx + tilt(p.y), p.y, cz))
			n.y = 0.0
			return p, n.normalized()

		eyes = []
		for i, y in enumerate(EYES):
			h = open_half(y) + 0.008
			row = []
			for side_ in (-1.0, 1.0):
				p, n = surf_at(side_ * h, y)
				row.append((p + n * 0.0035, n))
			eyes.append(row)
		# hardware: a flat brass ring for an eyelet, a ring and a hook standing off for a speed hook
		for i, row in enumerate(eyes):
			for (c, n) in row:
				up = Vector((0.0, 1.0, 0.0))
				t1 = up.cross(n).normalized()
				t2 = n.cross(t1).normalized()
				ro, ri = (0.0062, 0.003) if i < 3 else (0.0055, 0.0025)
				ring_o, ring_i = [], []
				for q in range(8):
					aq = 2.0 * math.pi * q / 8.0
					dvec = t1 * math.cos(aq) + t2 * math.sin(aq)
					ring_o.append(vert(c + dvec * ro - n * 0.0015))
					ring_i.append(vert(c + dvec * ri + n * 0.0012))
				for q in range(8):
					q2 = (q + 1) % 8
					face([ring_o[q], ring_o[q2], ring_i[q2], ring_i[q]], M_BOOT)
				if i >= 3:
					# the hook: a short post out from the ring, bent back toward the opening
					lat_e = (c.x - s * X0) * s - cx - tilt(c.y)
					toward = Vector((-math.copysign(1.0, lat_e) * s, 0.0, 0.0))
					toward = (toward - n * toward.dot(n)).normalized()
					base = c + n * 0.001
					tip = c + n * 0.0075 + toward * 0.0035
					end = tip + toward * 0.004 - n * 0.002
					for (a0, a1) in ((base, tip), (tip, end)):
						ax = (a1 - a0).normalized()
						o1 = ax.cross(t2).normalized() * 0.0016
						o2 = ax.cross(o1).normalized() * 0.0016
						r0 = [vert(a0 + o1 * math.cos(aq) * 1.0 + o2 * math.sin(aq)) for aq in (0.0, 2.1, 4.2)]
						r1 = [vert(a1 + o1 * math.cos(aq) * 1.0 + o2 * math.sin(aq)) for aq in (0.0, 2.1, 4.2)]
						for q in range(3):
							q2 = (q + 1) % 3
							face([r0[q], r0[q2], r1[q2], r1[q]], M_BOOT)
		# the laces: round cords. Each segment sags onto the tongue: points along it are pushed out to lie just over the surface.
		def tube(pts, rad, sides=6):
			rings_ = []
			for i, p in enumerate(pts):
				ax = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
				ref = Vector((0.0, 1.0, 0.0)) if abs(ax.y) < 0.9 else Vector((1.0, 0.0, 0.0))
				o1 = ax.cross(ref).normalized()
				o2 = ax.cross(o1).normalized()
				rings_.append([vert(p + (o1 * math.cos(2.0 * math.pi * q / sides) + o2 * math.sin(2.0 * math.pi * q / sides)) * rad) for q in range(sides)])
			for i in range(len(rings_) - 1):
				for q in range(sides):
					q2 = (q + 1) % sides
					face([rings_[i][q], rings_[i][q2], rings_[i + 1][q2], rings_[i + 1][q]], M_LACE)
			for rr, rev in ((rings_[0], True), (rings_[-1], False)):
				face(rr[::-1] if rev else rr, M_LACE)

		def lay(a, b, n_=7, lift=0.0045):
			pts = []
			for t in range(n_):
				p = a.lerp(b, t / (n_ - 1))
				loc = (p.x - s * X0) * s
				q, nn = surf_at(loc - cx - tilt(p.y), p.y)
				# out from the shaft's axis to just over the surface (the tongue lies lower than the eyestays: the cord dips over it)
				rp = math.hypot(loc - cx - tilt(p.y), p.z - cz)
				rq = math.hypot((q.x - s * X0) * s - cx - tilt(p.y), q.z - cz)
				if rp < rq + lift:
					d2 = Vector(((loc - cx - tilt(p.y)), (p.z - cz))).normalized()
					p = W(cx + tilt(p.y) + d2.x * (rq + lift), p.y, cz + d2.y * (rq + lift))
				pts.append(p)
			return pts

		tube(lay(eyes[0][0][0], eyes[0][1][0]), LACE_R)
		for i in range(len(eyes) - 1):
			tube(lay(eyes[i][0][0], eyes[i + 1][1][0]), LACE_R)
			tube(lay(eyes[i][1][0], eyes[i + 1][0][0]), LACE_R)
		# the bow at the top front: two loops falling out to the sides and two ends hanging down
		kp, kn = surf_at(0.0, COLLAR_Y - 0.004)
		knot = kp + kn * 0.012
		for side_ in (-1.0, 1.0):
			t1 = Vector((s * side_, 0.0, 0.0))
			loop = []
			for q in range(13):
				aq = math.pi * q / 12.0
				loop.append(knot + t1 * (0.026 * math.sin(aq) + 0.003) + Vector((0.0, -0.012 * math.sin(aq) + 0.009 * math.sin(aq * 2.0) * 0.5, 0.0)) + kn * (0.007 * math.sin(aq)))
			tube(loop, LACE_R * 0.95)
			end = [knot + t1 * 0.004, knot + t1 * (0.009 + 0.004 * side_) + Vector((0.0, -0.025, 0.0)) + kn * 0.006,
				knot + t1 * (0.013 + 0.006 * side_) + Vector((0.0, -0.05 - 0.008 * side_, 0.0)) + kn * 0.004]
			tube(_open_resample(end, 6), LACE_R * 0.95)
		tube([knot - kn * 0.002, knot + kn * 0.006], 0.0055, 8)
		stats["side_%d" % int(s)] = {"profiles": NA, "rings": NJ}
	# outward winding: the closed cords by their own topology; the leather and the sole (open where they meet) by facing away from the shaft's axis
	for mat, fl in faces.items():
		fl = [f for f in fl if f.is_valid]
		bmesh.ops.recalc_face_normals(bm, faces=fl)
		if mat == M_LACE:
			continue
		score = 0.0
		for f in fl:
			c = f.calc_center_median()
			if c.y > 0.3 or c.y < 0.02:
				continue
			sd = 1.0 if c.x > 0.0 else -1.0
			out = Vector((c.x - sd * (X0 + AX_C[0]), 0.0, c.z - AX_C[1]))
			score += f.normal.dot(out) * f.calc_area()
		if score < 0.0:
			bmesh.ops.reverse_faces(bm, faces=fl)
	allf = [f for fl in faces.values() for f in fl if f.is_valid]
	bmesh.ops.triangulate(bm, faces=allf)
	bm.to_mesh(me)
	bm.free()
	me.update()
	stats["faces"] = len(allf)
	return stats
