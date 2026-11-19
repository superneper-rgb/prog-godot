## Prog's baggy frayed jorts (user, 2026-11-16: "make prog some proper denim shorts"; style picked: baggy frayed jorts). They replace V1's shorts, which were one
## flared tube round both legs (a mini-skirt from every angle). Built in code, ring by ring, round his body:
##   - the seat: rings round the hips from a waistband (tucked under the tank's hem in front, higher up the back) down to the crotch, each ring the convex hull
##     of his belly and both thighs at that height pushed out a little, so the denim bridges the V between his thighs instead of following the skin into it;
##   - two leg tubes round the thigh bones, from the crotch to a cut-off hem just above the knee, looser and wider toward the hem (baggy), with soft folds;
##   - a crotch seam the two legs share (one surface, nothing to tear), hung a little low;
##   - the cut edge has thickness (an inner facing ring), and a fringe of frayed threads hangs from it (surface bk_shorts_fray: jagged tufts).
## Weights come from the skin underneath (body bones only), mirrored to an even split at the crotch seam, with the shin's share halved at the hem so the
## loose denim follows the thigh. The game's load-time fix (player/prog_v1_fix.gd) leaves them as they are.
## Runs in Blender on the "Prog" object (glb space, Y up) after head_swap.run and limbs.run, before glb_out.write.
import bpy, bmesh, math
import numpy as np
from mathutils import Vector, kdtree
from mathutils.bvhtree import BVHTree

# ---- shape (metres, glb space: front +Z, left +X)
THIGH_TOP = Vector((0.13, 0.86, 0.0))        # thigh.L head (V1's bones: the legs splay out to the knee)
KNEE = Vector((0.215, 0.52, 0.0))            # shin.L head
HIP_C = Vector((0.0, 0.0, 0.01))            # the seat's rings are cast round this vertical axis
WAIST_FRONT, WAIST_BACK = 0.905, 0.94        # waistband top: under the tank's hem in front, up over the small of his back behind
CROTCH_T = 0.30                              # along the thigh (0 hip, 1 knee): where the legs part
HEM_T = 0.80                                 # the cut: ~10 cm above the knee
N_LAT = 17                                   # leg ring vertices on the outer side (front centre round the outside to back centre)
N_SEAM = 5                                   # vertices along the shared crotch seam
SEAT_RINGS = 8                               # seat rings from the waistband down to the crotch ring
LEG_T = [0.30, 0.37, 0.44, 0.51, 0.58, 0.65, 0.72, 0.80]
EASE_SEAT, EASE_HEM = 0.016, 0.064           # how far the denim stands off the body: snug at the seat, baggy at the hem
FRAY = (0.012, 0.030)                        # thread length range at the hem
FACING = 0.009                               # thickness of the cut edge


def _sst(a, b, x):
	t = min(max((x - a) / (b - a), 0.0), 1.0)
	return t * t * (3.0 - 2.0 * t)


def _hash(*k):
	h = 0
	for v in k:
		h = (h * 1000003 + int(v) * 2654435761 + 12345) & 0xFFFFFFFF
	h ^= h >> 15
	h = (h * 2246822519) & 0xFFFFFFFF
	h ^= h >> 13
	return (h & 0xFFFF) / 65535.0


def _leg_frame(s):
	## the thigh axis of one side (s = +1 left, -1 right) and two perpendiculars: f toward the front, g toward the outside
	a0 = Vector((THIGH_TOP.x * s, THIGH_TOP.y, THIGH_TOP.z))
	a1 = Vector((KNEE.x * s, KNEE.y, KNEE.z))
	ax = (a1 - a0).normalized()
	f = Vector((0.0, 0.0, 1.0))
	f = (f - ax * f.dot(ax)).normalized()
	g = f.cross(ax) * (-1.0 if s > 0 else 1.0)
	if g.x * s < 0.0:
		g = -g
	return a0, a1, ax, f, g


def _hull_radii(dirs, pts, c):
	## convex hull of the 2D points (x, z) round centre c, read back as a radius per direction
	P = [(p.x, p.z) for p in pts]
	P = sorted(set(P))
	if len(P) < 3:
		return [None] * len(dirs)
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
		best = None
		for k in range(len(H)):
			a, b = H[k], H[(k + 1) % len(H)]
			ex, ez = b[0] - a[0], b[1] - a[1]
			den = d[0] * ez - d[1] * ex
			if abs(den) < 1e-9:
				continue
			ax, az = a[0] - c[0], a[1] - c[1]
			t = (ax * ez - az * ex) / den
			u = (ax * d[1] - az * d[0]) / den
			if t > 0.0 and -1e-6 <= u <= 1.0 + 1e-6:
				best = t if best is None else max(best, t)
		out.append(best)
	return out


def run(ob):
	me = ob.data
	mi = {m.name[2:] if m.name.startswith("P_") else m.name: i for i, m in enumerate(me.materials)}
	M_SKIN, M_DEN, M_FRAY = mi["bk_skin"], mi["bk_shorts"], mi["bk_shorts_fray"]
	gname = {g.index: g.name for g in ob.vertex_groups}
	gidx = {g.name: g.index for g in ob.vertex_groups}
	bm = bmesh.new()
	bm.from_mesh(me)
	dv = bm.verts.layers.deform.verify()
	# ---- V1's shorts go
	old = [f for f in bm.faces if f.material_index in (M_DEN, M_FRAY)]
	bmesh.ops.delete(bm, geom=old, context="FACES")
	loose = [v for v in bm.verts if not v.link_faces]
	bmesh.ops.delete(bm, geom=loose, context="VERTS")
	# ---- the body skin round the hips: rays and weights
	bm.faces.ensure_lookup_table()
	body_bones = ("pelvis", "spine", "thigh", "shin")
	def on_body(f):
		## a face of his body, not his arms (they hang beside his hips: rays that caught them stood the waistband out in spikes)
		for v in f.verts:
			w = {gname[g]: x for g, x in v[dv].items() if x > 1e-4}
			if not w or not max(w, key=w.get).startswith(body_bones):
				return False
		return True
	skin_f = [f for f in bm.faces if f.material_index == M_SKIN and abs(f.calc_center_median().x) < 0.45 and 0.4 < f.calc_center_median().y < 1.15 and on_body(f)]
	sb = bmesh.new()
	vmap = {}
	for f in skin_f:
		vs = []
		for v in f.verts:
			if v not in vmap:
				vmap[v] = sb.verts.new(v.co)
			vs.append(vmap[v])
		try:
			sb.faces.new(vs)
		except ValueError:
			pass
	bvh = BVHTree.FromBMesh(sb)
	wsrc, wpts = [], []
	for v in vmap:
		w = {gname[g]: x for g, x in v[dv].items() if x > 1e-4}
		if not w or not max(w, key=w.get).startswith(body_bones):
			continue
		wpts.append(v.co.copy())
		wsrc.append(w)
	wtree = kdtree.KDTree(len(wpts))
	for i, p in enumerate(wpts):
		wtree.insert(p, i)
	wtree.balance()

	def skin_out(c, d, far=0.40):
		## outermost skin along direction d from c: cast inward from just inside his hanging arms (from further out the rays caught the inside of the
		## arm and the waistband stood out round him like a hat brim)
		h = bvh.ray_cast(c + d * far, -d, far)
		return None if h[0] is None else min((h[0] - c).length, 0.37)

	def skin_first(c, d):
		h = bvh.ray_cast(c, d, 0.5)
		return None if h[0] is None else (h[0] - c).length

	def mirror_w(w):
		o = {}
		for b, x in w.items():
			nb = b[:-1] + ("R" if b.endswith("L") else "L") if b[-2:] in (".L", ".R") else b
			o[nb] = o.get(nb, 0.0) + x
		return o

	def weights_at(p, shin_keep=1.0, side=0.0):
		## side: a leg vertex's side (+1 left, -1 right): only that leg's skin counts, and there is no split with the other leg (0: the seat and the seam)
		acc = {}
		tot = 0.0
		near = [e for e in wtree.find_n(p, 14) if side == 0.0 or e[0].x * side > -0.005][:6]
		for (co, i, d) in near:
			k = 1.0 / max(d, 0.004) ** 2
			for b, x in wsrc[i].items():
				if b.startswith("shin"):
					x *= shin_keep
				acc[b] = acc.get(b, 0.0) + x * k
			tot += k
		mid = 0.0 if side else 1.0 - _sst(0.0, 0.06, abs(p.x))           # at the crotch seam: an even split between the legs
		if mid > 0.0:
			m = mirror_w(acc)
			acc = {b: acc.get(b, 0.0) * (1.0 - 0.5 * mid) + m.get(b, 0.0) * 0.5 * mid for b in set(acc) | set(m)}
		top = sorted(acc.items(), key=lambda e: -e[1])[:4]
		s = sum(x for _, x in top) or 1.0
		return {b: x / s for b, x in top}

	# ---- the leg rings. Per side: N_LAT outer vertices from front-centre round the outside to back-centre, then the seam back to the front.
	# A ring vertex k has an angle phi round the thigh (0 front, +90 outside, 180 back, 270 inside).
	lat_phi = [-60.0 + 300.0 * k / (N_LAT - 1) for k in range(N_LAT)]     # -60 (front, inner) .. 240 (back, inner)
	seam_phi = [240.0 + 60.0 * (k + 1) / (N_SEAM + 1) for k in range(N_SEAM)]             # under the crotch, back to front
	ring_phi = lat_phi + seam_phi
	NR = len(ring_phi)
	legs = {}
	# each vertex takes its weights from the skin straight under it (its ray's hit), not from whatever skin is nearest: near the hip crease the nearest
	# skin was the belly's, and with its pelvis and spine weights the denim stayed put while a raised thigh came forward through it
	anchor_of = {}

	def pkey(p):
		return (round(p.x, 5), round(p.y, 5), round(p.z, 5))
	for s in (1.0, -1.0):
		a0, a1, ax, f, g = _leg_frame(s)
		rings = []
		for ri, t in enumerate(LEG_T):
			c = a0 + (a1 - a0) * t
			u = (t - CROTCH_T) / (HEM_T - CROTCH_T)                  # 0 crotch .. 1 hem
			ease = EASE_SEAT + (EASE_HEM - EASE_SEAT) * u ** 1.3
			dirs = []
			pts = []
			for k, ph in enumerate(ring_phi):
				r = math.radians(ph)
				d = (f * math.cos(r) + g * math.sin(r)).normalized()
				rr = skin_first(c, d) or 0.15
				dirs.append(d)
				pts.append(c + d * rr)
			# hull in the ring's own plane (the thigh is round, but the fat at the back of it is not: the denim bridges it)
			loc = [Vector(((p - c).dot(g), 0.0, (p - c).dot(f))) for p in pts]
			hr = _hull_radii([(d.dot(g), d.dot(f)) for d in dirs], loc, (0.0, 0.0))
			ring = []
			for k, ph in enumerate(ring_phi):
				r0 = max(hr[k] or 0.0, (pts[k] - c).length)
				# soft folds: broad vertical drapes that grow toward the hem, a twist of creases fanning from the crotch at the top
				fold = 0.006 * u * math.sin(math.radians(ph) * 5.0 + s * 1.3) + 0.004 * math.sin(math.radians(ph) * 3.0 + t * 19.0 + s)
				p = c + dirs[k] * (r0 + ease + fold)
				if ri == len(LEG_T) - 1:
					# the cut: a little ragged, and lower at the outside and the back as cut-offs hang
					p += ax * (0.006 * (_hash(k, s * 3) - 0.5) + 0.008 * max(0.0, math.sin(math.radians(ph))) * 0.5)
				if p.x * s < 0.004:                                    # the inner sides of the two legs meet at the middle, never cross it
					p.x = 0.004 * s
				ring.append(p)
				anchor_of[pkey(p)] = (pts[k], s)
			rings.append(ring)
		legs[s] = (rings, a0, a1, ax, f, g)

	# the crotch ring: its front-inner (k=0) and back-inner (k=N_LAT-1) vertices move onto the middle, shared by both legs; the seam vertices
	# lie on the middle too, hung in an arc between them
	for s in (1.0, -1.0):
		rings = legs[s][0]
		for k in (0, N_LAT - 1):
			rings[0][k] = Vector((0.0, rings[0][k].y, rings[0][k].z))
	rl, rr_ = legs[1.0][0][0], legs[-1.0][0][0]
	F = (rl[0] + rr_[0]) * 0.5
	K = (rl[N_LAT - 1] + rr_[N_LAT - 1]) * 0.5
	seam = []
	for k in range(N_SEAM):
		q = (k + 1) / (N_SEAM + 1)                                     # 0 at the back .. 1 at the front
		p = K.lerp(F, q)
		below = legs[1.0][0][1][N_LAT + k].y                          # the next ring down: the seam hangs, but never below it
		p.y = max(p.y - 0.035 * math.sin(math.pi * q), below + 0.012)
		seam.append(Vector((0.0, p.y, p.z)))
	for s in (1.0, -1.0):
		legs[s][0][0][0] = F.copy()
		legs[s][0][0][N_LAT - 1] = K.copy()
		for k in range(N_SEAM):
			legs[s][0][0][N_LAT + k] = seam[k].copy()

	# ---- the seat: rings round the vertical axis, each vertex in the direction of its crotch-ring vertex
	bottom = [F] + [legs[1.0][0][0][k] for k in range(1, N_LAT - 1)] + [K] + [legs[-1.0][0][0][k] for k in range(N_LAT - 2, 0, -1)]
	NS = len(bottom)
	ycr = sum(p.y for p in bottom) / NS
	sdirs = []
	for p in bottom:
		d = Vector((p.x - HIP_C.x, 0.0, p.z - HIP_C.z))
		sdirs.append(d.normalized())
	seat = []
	for ri in range(SEAT_RINGS):
		q = ri / SEAT_RINGS                                           # 0 waistband .. toward the crotch
		ring = []
		raw = []
		for k, d in enumerate(sdirs):
			back = _sst(0.2, -0.9, d.z)                               # 1 behind, 0 in front
			ytop = WAIST_FRONT + (WAIST_BACK - WAIST_FRONT) * back
			y = ytop + (bottom[k].y - ytop) * (q ** 1.15)
			c = Vector((HIP_C.x, y, HIP_C.z))
			# a small fan of rays round each direction: one ray alone slipped past the thin rims where his thigh tops meet the belly, which then poked through
			rr = None
			for da in (-0.09, -0.045, 0.0, 0.045, 0.09):
				dd = Vector((d.x * math.cos(da) - d.z * math.sin(da), 0.0, d.x * math.sin(da) + d.z * math.cos(da)))
				for dy in (-0.012, 0.0, 0.012):
					h = skin_out(c + Vector((0.0, dy, 0.0)), dd)
					if h is not None:
						h *= dd.dot(d)
						rr = h if rr is None else max(rr, h)
			raw.append(c + d * (rr if rr else (bottom[k] - Vector((HIP_C.x, bottom[k].y, HIP_C.z))).length))
		hr = _hull_radii([(d.x, d.z) for d in sdirs], raw, (HIP_C.x, HIP_C.z))
		for k, d in enumerate(sdirs):
			y = raw[k].y
			r0 = max(hr[k] or 0.0, Vector((raw[k].x - HIP_C.x, 0.0, raw[k].z - HIP_C.z)).length)
			band = 0.004 if ri <= 1 else 0.0                          # the waistband stands proud
			p = Vector((HIP_C.x, y, HIP_C.z)) + d * (r0 + EASE_SEAT + 0.008 * (1.0 - q) + band)
			ring.append(p)
		if seat:
			# behind and at the sides the denim hangs from the waistband over the hollow under his belly to his seat, never tucking in after the skin
			# (following it, the back of the waistband jutted out as a lip)
			for k, d in enumerate(sdirs):
				hang = _sst(0.35, -0.4, d.z)
				if hang <= 0.0:
					continue
				up = seat[-1][k]
				ru = Vector((up.x - HIP_C.x, 0.0, up.z - HIP_C.z)).length - 0.3 * (up.y - ring[k].y)
				r = Vector((ring[k].x - HIP_C.x, 0.0, ring[k].z - HIP_C.z)).length
				if ru > r:
					ring[k] = Vector((HIP_C.x, ring[k].y, HIP_C.z)) + d * (r + (ru - r) * hang)
		for k, p in enumerate(ring):
			anchor_of[pkey(p)] = (raw[k], 0.0)
		seat.append(ring)

	# ---- mesh it
	new_v = {}
	def V(p, shin_keep=1.0):
		key = pkey(p)
		if key not in new_v:
			v = bm.verts.new(p)
			at, sd = anchor_of.get(key, (p, 0.0))
			for b, x in weights_at(at, shin_keep, sd).items():
				if b in gidx:
					v[dv][gidx[b]] = x
			new_v[key] = v
		return new_v[key]

	faces = []
	def quad(a, b, c, d, mat):
		poly([a, b, c, d], mat)

	def poly(vs, mat):
		uniq = []
		for v in vs:
			if v not in uniq:
				uniq.append(v)
		if len(uniq) < 3:
			return
		try:
			fc = bm.faces.new(uniq)
		except ValueError:
			return
		fc.material_index = mat
		faces.append(fc)

	seat_rings = [[V(p) for p in r] for r in seat] + [[V(p) for p in bottom]]
	for ri in range(len(seat_rings) - 1):
		A, B = seat_rings[ri], seat_rings[ri + 1]
		for k in range(NS):
			quad(A[k], A[(k + 1) % NS], B[(k + 1) % NS], B[k], M_DEN)
	# waistband top: a turned-over lip inward, so the edge has thickness
	top_in = [V(p - Vector((p.x - HIP_C.x, 0.0, p.z - HIP_C.z)).normalized() * FACING) for p in seat[0]]
	for k in range(NS):
		quad(top_in[k], top_in[(k + 1) % NS], seat_rings[0][(k + 1) % NS], seat_rings[0][k], M_DEN)
	for s in (1.0, -1.0):
		rings, a0, a1, ax, f, g = legs[s]
		nl = len(rings)
		VR = []
		for ri, r in enumerate(rings):
			u = ri / (nl - 1)
			VR.append([V(p, 1.0 - 0.5 * u) for p in r])
		for ri in range(nl - 1):
			A, B = VR[ri], VR[ri + 1]
			for k in range(NR):
				k2 = (k + 1) % NR
				if s > 0:
					quad(A[k], B[k], B[k2], A[k2], M_DEN)
				else:
					quad(A[k], A[k2], B[k2], B[k], M_DEN)
		# the cut edge: an inner facing ring, and the fringe
		hem = rings[-1]
		hv = VR[-1]
		c_h = a0 + (a1 - a0) * LEG_T[-1]
		inner = []
		inner_up = []
		for p in hem:
			out = (p - c_h)
			out = (out - ax * out.dot(ax)).normalized()
			inner.append(V(p - out * FACING, 0.5))
			inner_up.append(V(p - out * (FACING + 0.004) - ax * 0.05, 0.6))
		# the fringe: per hem segment a ragged run of tufts (two peaks and a notch between the corners), hanging nearly straight down; a corner's length
		# is shared by the segments either side. (Alternating long and short corners alone made an even sawtooth that read as a ruffled trim.)
		def tip(p, L, out):
			return p + ax * L + out * (0.002 + 0.12 * L)
		outs = []
		fr = []
		for k, p in enumerate(hem):
			out = (p - c_h)
			out = (out - ax * out.dot(ax)).normalized()
			outs.append(out)
			fr.append(V(tip(p, FRAY[0] + (FRAY[1] - FRAY[0]) * _hash(k * 7 + 3, s * 5) ** 1.3, out), 0.5))
		for k in range(NR):
			k2 = (k + 1) % NR
			if s > 0:
				quad(hv[k], inner[k], inner[k2], hv[k2], M_DEN)
				quad(inner[k], inner_up[k], inner_up[k2], inner[k2], M_DEN)
			else:
				quad(hv[k], hv[k2], inner[k2], inner[k], M_DEN)
				quad(inner[k], inner[k2], inner_up[k2], inner_up[k], M_DEN)
			mids = []
			for q, kind in ((0.3, 0), (0.52, 1), (0.74, 0)):
				pm = hem[k].lerp(hem[k2], q)
				om = outs[k].lerp(outs[k2], q).normalized()
				if kind:
					L = 0.009 + 0.008 * _hash(k * 13 + 1, s * 7)                 # (a shallow notch: deep ones made a row of teeth)
				else:
					L = FRAY[1] * (0.55 + 0.45 * _hash(k * 11 + int(q * 100), s * 9))
				mids.append(V(tip(pm, L, om), 0.5))
			ring = [hv[k], hv[k2], fr[k2], mids[2], mids[1], mids[0], fr[k]]
			poly(ring if s > 0 else ring[::-1], M_FRAY)
	# outward winding throughout (the leg loops were wound by side; the seat and the seam by the pass below)
	bmesh.ops.recalc_face_normals(bm, faces=faces)
	bmesh.ops.triangulate(bm, faces=faces)
	bm.to_mesh(me)
	bm.free()
	sb.free()
	me.update()
	return {"seat_verts": NS, "leg_ring": NR, "faces": len(faces), "crotch_y": round(ycr, 3)}
