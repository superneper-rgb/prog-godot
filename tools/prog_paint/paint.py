## Prog's painted texture, step 2: paint the albedo from the baked maps (bake.py), toward the user's reference (low-poly, hand-painted: shading painted in,
## creases, heavy tired eyes with bags under them, a ruddy nose, strands in the hair, brows and mustache, ribbed tank top, worn denim, scuffed leather boots).
## Every stroke is a function of the bind-pose position, so it runs straight across UV seams. Plain Python (numpy, Pillow, scipy):
##   python tools/prog_paint/paint.py [work folder] [out.png]
import sys, os
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from prog_mesh import Model, read_glb, acc

WORK = sys.argv[1] if len(sys.argv) > 1 else "F:/prog-godot-cache/prog_paint"
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(WORK, "paint.png")
m = np.load(os.path.join(WORK, "maps.npz"))
GLB = str(m["glb"]) if "glb" in m else os.path.join(HERE, "..", "..", "assets", "prog.glb")     # the file the maps were baked from
names = [str(n) for n in m["names"]]
P = m["pos"].astype(np.float32)
N = m["nrm"].astype(np.float32)
N /= np.maximum(np.linalg.norm(N, axis=2, keepdims=True), 1e-6)
from scipy import ndimage as _nd
AO = np.clip(_nd.gaussian_filter(m["ao"], 1.4), 0.0, 1.0)            # (the occlusion bake is grainy where it is half shaded, under the chin: smoothed, or it shows as speckle)
AOF = np.clip(_nd.gaussian_filter(m["ao_far"], 2.0), 0.0, 1.0)
SID = np.round(m["sid"]).astype(np.int32)
PNT = m["pnt"]
H, W = SID.shape
X, Y, Z = P[:, :, 0], P[:, :, 1], P[:, :, 2]
AX = np.abs(X)
SX = np.where(X >= 0.0, 1.0, -1.0)
model = Model(GLB)

# bones in the bind pose
_j, _B = read_glb(GLB)
_sk = _j["skins"][0]
_ibm = acc(_j, _B, _sk["inverseBindMatrices"]).reshape(-1, 4, 4)
BONE = {}
for _k, _ni in enumerate(_sk["joints"]):
	BONE[_j["nodes"][_ni]["name"]] = np.linalg.inv(_ibm[_k].T)[:3, 3].astype(np.float32)


def sid_mask(*nm):
	k = np.zeros((H, W), bool)
	for n in nm:
		if n in names:
			k |= SID == names.index(n)
	return k


def rgb(*c):
	return np.array(c, np.float32) / 255.0


def sst(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def mix(a, b, t):
	t = np.asarray(t, np.float32)
	if t.ndim == 2:
		t = t[:, :, None]
	return a + (b - a) * t


def blend(col, target, t):
	## paint `target` over `col` with opacity t (per texel)
	return mix(col, np.broadcast_to(target, col.shape), np.clip(t, 0.0, 1.0))


def darken(col, t, tint=(1.0, 1.0, 1.0)):
	t = np.clip(np.asarray(t, np.float32), 0.0, 1.0)[:, :, None]
	return col * (1.0 - t * (1.0 - np.array(tint, np.float32)))


def line(d, w):
	## soft line of half-width w over a distance field d
	return np.exp(-(np.asarray(d) / w) ** 2)


# ---- 3D value noise, vectorised
def _hash(ix, iy, iz):
	h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return (h & 0xFFFF).astype(np.float32) / 65535.0


def vnoise(p):
	i = np.floor(p).astype(np.int64)
	f = (p - i).astype(np.float32)
	f = f * f * (3.0 - 2.0 * f)
	x0, y0, z0 = i[..., 0], i[..., 1], i[..., 2]
	fx, fy, fz = f[..., 0], f[..., 1], f[..., 2]
	def c(dx, dy, dz):
		return _hash(x0 + dx, y0 + dy, z0 + dz)
	a = c(0, 0, 0) + (c(1, 0, 0) - c(0, 0, 0)) * fx
	b = c(0, 1, 0) + (c(1, 1, 0) - c(0, 1, 0)) * fx
	cc = c(0, 0, 1) + (c(1, 0, 1) - c(0, 0, 1)) * fx
	d = c(0, 1, 1) + (c(1, 1, 1) - c(0, 1, 1)) * fx
	lo = a + (b - a) * fy
	return lo + ((cc + (d - cc) * fy) - lo) * fz


def fbm(p, oct=4):
	s, amp, tot = 0.0, 0.5, 0.0
	for o in range(oct):
		s = s + vnoise(p * (2.07 ** o) + o * 17.3) * amp
		tot += amp
		amp *= 0.5
	return s / tot


def stack(*a):
	return np.stack([np.broadcast_to(np.asarray(x, np.float32), (H, W)) for x in a], -1)


def seg(a, b):
	## per texel: position t along the segment a->b (0..1, unclamped), distance from its axis, and the angle around it (0 = facing +Z, the front)
	a = np.asarray(a, np.float32)
	b = np.asarray(b, np.float32)
	ax = b - a
	L = np.linalg.norm(ax)
	ax = ax / L
	q = P - a
	t = (q @ ax) / L
	r = q - (q @ ax)[:, :, None] * ax
	f = np.array([0.0, 0.0, 1.0], np.float32)
	f = f - ax * (f @ ax)
	f /= np.linalg.norm(f)
	g = np.cross(ax, f)
	return t, np.linalg.norm(r, axis=2), np.arctan2(r @ g, r @ f)


def boundary_dist(*prim_names):
	## distance (m) from each texel to the open edges of these surfaces: hems, necklines, boot tops
	pts = []
	for nm in prim_names:
		si = names.index(nm)
		fs = [tuple(sorted(f)) for f, s in zip(model.faces, model.sid) if s == si]
		cnt = {}
		for f in set(fs):
			for e in ((f[0], f[1]), (f[1], f[2]), (f[0], f[2])):
				cnt[e] = cnt.get(e, 0) + 1
		V = np.array(model.verts, np.float32)
		for (a, b), c in cnt.items():
			if c == 1:
				n = max(2, int(np.linalg.norm(V[a] - V[b]) / 0.002))
				pts.append(V[a] + (V[b] - V[a]) * np.linspace(0.0, 1.0, n)[:, None])
	tree = cKDTree(np.concatenate(pts))
	d, _ = tree.query(P.reshape(-1, 3), workers=-1)
	return d.reshape(H, W).astype(np.float32)


# round the neck the baked normal's side (which way is out) is a coin toss per texel where both sides are about as open: it is turned to face away
# from the neck's axis there, or the shading speckles (a red-dotted band at his collar, 2026-11-15)
_rad = np.stack([X, np.zeros_like(X), Z], -1)
_rad /= np.maximum(np.linalg.norm(_rad, axis=2, keepdims=True), 1e-6)
_flip = ((N * _rad).sum(2) < 0.0) & (Y > 1.38) & (Y < 1.66) & (AX < 0.2)
N[_flip] *= -1.0
# ---- painted light: occlusion in the creases, the broad body shading, a soft key from above and the front
key = np.clip(N[:, :, 1] * 0.55 + N[:, :, 2] * 0.35 + 0.45, 0.0, 1.0)
shade = np.clip((0.55 + 0.45 * AO ** 0.9) * (0.78 + 0.22 * AOF) * (0.86 + 0.14 * key), 0.0, 1.0)
grain = fbm(P * 140.0, 2) - 0.5          # fine paint grain, everywhere
mottle = fbm(P * 22.0, 3) - 0.5          # broad colour variation
out = np.zeros((H, W, 3), np.float32)


def ramp(dark, mid, light, deep=None, lo=0.45, hi=0.82, sh=None):
	sh = shade if sh is None else sh
	c = mix(dark, mid, sst(lo, hi, sh))
	c = mix(c, light, sst(hi, 1.0, sh) * 0.8)
	if deep is not None:
		c = mix(deep, c, sst(0.22, 0.52, sh))
	return c


# ================================================================ skin ================================================================
def paint_skin():
	col = ramp(rgb(178, 112, 82), rgb(228, 168, 124), rgb(246, 200, 158), rgb(118, 66, 50))
	col *= (1.0 + mottle * 0.09)[:, :, None]
	col = blend(col, col * rgb(255, 200, 186), sst(0.02, 0.22, mottle) * 0.3)          # ruddy patches
	front = sst(0.04, 0.09, Z)                                                         # the face, not the back of the head
	face = front * sst(1.55, 1.6, Y)

	# --- neck and chest: the sternum line and the collarbones above the shirt
	sternum = line(X, 0.003) * sst(1.36, 1.38, Y) * sst(1.47, 1.44, Y) * sst(0.1, 0.14, Z)
	col = darken(col, sternum * 0.5, (0.6, 0.4, 0.34))
	clav_y = 1.452 - (AX - 0.04) * 0.12
	clav = line(Y - clav_y, 0.005) * sst(0.03, 0.05, AX) * sst(0.19, 0.16, AX) * sst(0.08, 0.12, Z)
	col = blend(col, rgb(250, 208, 168), clav * 0.35)
	col = darken(col, line(Y - clav_y + 0.012, 0.004) * sst(0.03, 0.05, AX) * sst(0.19, 0.16, AX) * sst(0.08, 0.12, Z) * 0.35, (0.65, 0.45, 0.38))

	# --- arms: deltoid cap, the biceps / triceps split, the forearm's long muscle, veins, elbow creases
	for s in (1.0, -1.0):
		side = "L" if s > 0 else "R"
		sh, el, wr = BONE["upper_arm." + side], BONE["forearm." + side], BONE["hand." + side]
		on = (SX == s)
		t, r, th = seg(sh, el)
		lat = th - s * np.pi / 2.0                                  # 0 on the outer side of the arm
		lat = (lat + np.pi) % (2.0 * np.pi) - np.pi
		upper = on & (r < 0.16) & (t > -0.1) & (t < 1.05)
		t_d = 0.3 + 0.22 * (1.0 + np.cos(lat)) / 2.0                 # the deltoid comes to a point down the outside of the arm
		delt = line(t - t_d, 0.035) * (1.0 - sst(1.2, 2.4, np.abs(lat))) * upper
		col = darken(col, delt * 0.38, (0.66, 0.45, 0.38))
		col = blend(col, rgb(250, 206, 164), line(t - t_d + 0.07, 0.05) * (1.0 - sst(1.0, 2.2, np.abs(lat))) * upper * 0.3)
		for side_lat in (0.25, -2.6):                                # biceps / triceps split on the outside, and on the inside
			split = line(lat - side_lat - 0.15 * np.sin(t * 5.0), 0.12) * sst(0.4, 0.55, t) * sst(0.95, 0.8, t) * upper
			col = darken(col, split * 0.32, (0.66, 0.46, 0.4))
		t2, r2, th2 = seg(el, wr)
		lat2 = (th2 - s * np.pi / 2.0 + np.pi) % (2.0 * np.pi) - np.pi
		fore = on & (r2 < 0.14) & (t2 > -0.15) & (t2 < 1.0)
		brach = line(lat2 - (0.5 - t2 * 1.1), 0.14) * sst(0.0, 0.1, t2) * sst(0.65, 0.45, t2) * fore
		col = darken(col, brach * 0.3, (0.66, 0.46, 0.4))
		elbow = sst(0.06, -0.04, t2) * sst(-0.16, -0.06, t2) * (1.0 - sst(0.6, 1.3, np.abs(np.abs(lat2) - np.pi / 2.0 - np.pi / 2.0)))
		creases = (0.5 + 0.5 * np.sin(t2 * 160.0)) * elbow * on * (r2 < 0.14)
		col = darken(col, creases * 0.3, (0.62, 0.42, 0.36))
		vq = stack(P[:, :, 0] * 30.0, P[:, :, 1] * 9.0, P[:, :, 2] * 30.0)
		vein = line(fbm(vq, 3) - 0.5, 0.018) * sst(0.15, 0.35, t2) * sst(1.0, 0.85, t2) * fore * sst(0.2, 0.6, np.cos(th2) * 0.5 + 0.5 + 0.3 * np.cos(lat2))
		col = darken(col, vein * 0.3, (0.7, 0.62, 0.7))
		col = blend(col, rgb(250, 210, 172), line(fbm(vq + np.array([0.0, 0.06, 0.0], np.float32), 3) - 0.5, 0.012) * fore * sst(0.15, 0.35, t2) * sst(1.0, 0.85, t2) * 0.12)

		# hands: knuckles lit, creases at the finger joints, the nails
		hand = on & (np.linalg.norm(P - wr, axis=2) < 0.2)
		for f in ("index", "middle", "ring", "pinky", "thumb"):
			a1, a2, a3 = BONE[f + "_01." + side], BONE[f + "_02." + side], BONE[f + "_03." + side]
			knuck = 1.0 - sst(0.006, 0.016, np.linalg.norm(P - a1, axis=2))
			col = blend(col, rgb(240, 172, 140), knuck * hand * 0.35)
			for a in (a2, a3):
				dirv = (a3 - a2) / np.linalg.norm(a3 - a2)
				d_along = (P - a) @ dirv
				near = np.linalg.norm(P - a, axis=2) < 0.018
				col = darken(col, line(d_along, 0.0018) * near * hand * 0.55, (0.6, 0.4, 0.36))
			tipp = a3 + (a3 - a2) * 0.85
			dirv = (a3 - a2) / np.linalg.norm(a3 - a2)
			dorsal = np.array([-dirv[1] * s, dirv[0] * s, 0.0], np.float32)
			if dorsal[0] * s < 0.0:
				dorsal = -dorsal
			nail = (1.0 - sst(0.008, 0.012, np.linalg.norm(P - tipp, axis=2))) * sst(0.3, 0.6, N @ dorsal) * hand
			col = blend(col, rgb(236, 190, 168), nail * 0.75)
			col = darken(col, line(np.linalg.norm(P - tipp, axis=2) - 0.0115, 0.0015) * sst(0.3, 0.6, N @ dorsal) * hand * 0.5, (0.6, 0.42, 0.4))

	# --- legs: the knee cap and the lines around it
	for s in (1.0, -1.0):
		side = "L" if s > 0 else "R"
		knee = BONE["shin." + side] + np.array([0.0, 0.0, 0.09], np.float32)
		dk = np.sqrt(((X - knee[0]) / 0.045) ** 2 + ((Y - knee[1]) / 0.05) ** 2) * (SX == s)
		kz = sst(0.02, 0.06, Z)
		col = blend(col, rgb(242, 186, 146), (1.0 - sst(0.5, 1.0, dk)) * kz * 0.3)
	return col


skin = sid_mask("bk_skin", "bk_nose", "bk_wrinkle", "bk_skin_dark")
out[skin] = paint_skin()[skin]
navel = sid_mask("bk_skin_dark") & (Y < 1.1)
out[navel] = mix(rgb(90, 50, 40), rgb(170, 105, 80), shade)[navel]


# ================================================================ the head: V3's painted face, carried over ================================================================
def lin2srgb(c):
	c = np.clip(c, 0.0, 1.0)
	return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


SRC_OK = m["src_ok"] > 0.5 if "src_ok" in m else np.zeros((H, W), bool)
SMOOTH = np.zeros((H, W), np.float32)
if SRC_OK.any():
	srcc = lin2srgb(m["src"]).astype(np.float32)
	# a little crispness back on the upscaled painting (V3's texture was 512 px), grain, and the new model's own occlusion in the deep creases
	blur = np.stack([ndimage.gaussian_filter(srcc[:, :, c], 1.6) for c in range(3)], -1)
	srcc = np.clip(srcc + (srcc - blur) * 0.7, 0.0, 1.0)
	srcc *= (0.86 + 0.14 * AO ** 0.6)[:, :, None]
	# skin: V3's tone matched to the body's (gain per channel, cheeks and brow against the upper arms), fading into the body's skin down the neck
	head_skin = skin & SRC_OK
	ref_h = head_skin & (Y > 1.62) & (Y < 1.8) & (Z > 0.05) & (AO > 0.8)
	ref_b = skin & ~SRC_OK & (Y > 1.1) & (Y < 1.4) & (AX > 0.35) & (AO > 0.8)
	gain = np.clip(out[ref_b].mean(0) / np.maximum(srcc[ref_h].mean(0), 1e-3), 0.8, 1.25)
	hc = srcc * gain
	hc *= (1.0 + grain * 0.06)[:, :, None]
	# below the lower lip (chin, jaw, the underside, the neck) V3's painting is dropped for the body's own smooth skin (user, 2026-11-15: its stubble,
	# upscaled from 512 px and sharpened, read as grimy, mottled and stretched). The lower lip itself stays V3's; the chin and jaw keep a soft,
	# even shadow of stubble, a little cooler, with a lit ball on the chin.
	t = sst(1.588, 1.574, Y)
	# that skin is shaded from the smooth surface direction only: the occlusion baked on the neck's thin slivers came out in jagged wedges
	neck = ramp(rgb(178, 112, 82), rgb(228, 168, 124), rgb(246, 200, 158), rgb(118, 66, 50), sh=np.clip(0.62 + 0.38 * key, 0.0, 1.0))
	neck *= (1.0 + mottle * 0.06)[:, :, None]
	body = mix(out, neck, sst(1.43, 1.47, Y))
	hc = mix(hc, body, t)
	front = sst(0.0, 0.06, Z)
	stubble = sst(1.515, 1.55, Y) * sst(1.592, 1.578, Y) * front
	hc = mix(hc, hc * rgb(226, 212, 208), stubble * 0.8)
	ball = 1.0 - sst(0.4, 1.0, np.sqrt((X / 0.035) ** 2 + ((Y - 1.56) / 0.018) ** 2))
	hc = mix(hc, hc * 1.06, ball * front)
	out[head_skin] = hc[head_skin]
	SMOOTH = head_skin * sst(1.592, 1.575, Y)     # (no paint grain here either, below)
	neck_k = skin & ~SRC_OK & (Y > 1.43) & (AX < 0.17)          # V1's own upper neck, up to the join: the same smooth shading
	out[neck_k] = mix(out, neck, sst(1.43, 1.47, Y))[neck_k]
	SMOOTH = np.maximum(SMOOTH, neck_k * sst(1.43, 1.47, Y))
	print("paint: head skin gain", gain.round(3))
	for nm in ("bk_eye_white", "bk_mouth", "bk_teeth", "bk_tongue"):
		k = sid_mask(nm) & SRC_OK
		out[k] = srcc[k]


# ================================================================ tank top ================================================================
def tank_edges():
	## The tank's edges (tank.py) fold under: each open edge of the shirt turns in by a few millimetres. Returns the distance (m) from each texel to the
	## fold (the edge as seen), and the mask of the turned-under strip's texels.
	si = names.index("bk_tank")
	fs = [tuple(f) for f, s_ in zip(model.faces, model.sid) if s_ == si]
	cnt = {}
	for f in fs:
		for e in ((f[0], f[1]), (f[1], f[2]), (f[0], f[2])):
			e = tuple(sorted(e))
			cnt[e] = cnt.get(e, 0) + 1
	Bv = {v for e, c in cnt.items() if c == 1 for v in e}                         # the turned-under edge
	flap = [f for f in fs if Bv & set(f)]
	Fv = {v for f in flap for v in f} - Bv                                        # the fold: the edge of the shirt as seen
	V = np.array(model.verts, np.float32)
	pts = []
	for f in flap:
		for e in ((f[0], f[1]), (f[1], f[2]), (f[0], f[2])):
			if e[0] in Fv and e[1] in Fv:
				a, b = V[e[0]], V[e[1]]
				n = max(2, int(np.linalg.norm(b - a) / 0.0015))
				pts.append(a + (b - a) * np.linspace(0.0, 1.0, n)[:, None])
	tree = cKDTree(np.concatenate(pts))
	d, _ = tree.query(P.reshape(-1, 3), workers=-1)
	inner = cKDTree(V[sorted(Bv)])
	di, _ = inner.query(P.reshape(-1, 3), workers=-1)
	return d.reshape(H, W).astype(np.float32), (di.reshape(H, W) < 0.0025)


def paint_tank():
	## A worn white ribbed A-shirt (user, 2026-11-16; the geometry is tank.py): off-white cotton rib whose wales run up the body and along the straps,
	## spreading where his gut stretches them; folded binding round the neck and armholes with a coverstitch, a turned hem; soft drag lines where it pulls and
	## bunches; and mild wear: yellowed sweat at the pits and the collar, two dried drips down the front, greasy finger smudges by the hem.
	tank = sid_mask("bk_tank")
	C_Z = -0.01
	col = ramp(rgb(132, 128, 124), rgb(198, 194, 186), rgb(224, 221, 213), lo=0.42, hi=0.86)       # (off-white: brighter blew out to flat white in the game's light)
	col *= (1.0 + mottle * 0.05)[:, :, None]
	# --- the rib. u runs across the wales: round him (angle times a fixed radius, so the wales spread over his gut, where the knit stretches), and on the
	# straps across the strap (along |x|), its phase matched to the body's where each strap rises off the panel.
	R0, PER = 0.26, 0.0055                                     # (wale spacing: ~4 texels at the tank's density)
	th = np.arctan2(AX, Z - C_Z)
	u_body = th * R0
	off_f = np.arctan2(0.152, 0.215 - C_Z) * R0 - 0.152
	off_b = np.arctan2(0.158, -0.175 - C_Z) * R0 - 0.158
	tb = sst(0.12, -0.12, Z)
	u_strap = AX + off_f * (1.0 - tb) + off_b * tb
	xs = 0.152 + 0.006 * tb
	on_strap = sst(1.39, 1.45, Y) * (1.0 - sst(0.03, 0.05, np.abs(AX - xs)))
	u = u_body * (1.0 - on_strap) + u_strap * on_strap
	ph = 2.0 * np.pi * (u / PER + (fbm(P * 18.0, 2) - 0.5) * 0.35)             # (a little waver: knit is never ruled)
	wale = 0.5 + 0.5 * np.cos(ph)
	rib_k = 1.0 - 0.6 * (1.0 - sst(0.15, 0.4, np.abs(on_strap - 0.5)))         # (where body and strap blend the two phases fight: the rib fades there)
	rib = (wale ** 1.6 - 0.42) * rib_k
	col *= (1.0 + rib * (0.075 + 0.04 * sst(0.6, 0.95, shade)))[:, :, None]       # raised wales catch the light, the valleys between them sit in shadow
	# --- drag and bunching: soft horizontal folds where it gathers at his sides over the waistband and under the gut, diagonal pulls from the straps
	gather = np.sin(Y * 110.0 + fbm(P * 7.0, 3) * 6.0) * sst(0.16, 0.27, AX) * sst(1.08, 0.94, Y)
	col *= (1.0 - np.clip(gather, 0.0, 1.0) * 0.07 + np.clip(-gather, 0.0, 1.0) * 0.02)[:, :, None]
	under = sst(1.0, 0.92, Y) * sst(0.05, 0.2, Z) * (0.6 + 0.4 * np.sin(X * 55.0 + fbm(P * 5.0, 2) * 3.0))
	col = darken(col, under * 0.12, (0.85, 0.83, 0.82))
	for s in (1.0, -1.0):
		# from each strap root a few shallow pull lines fan down and in over the chest
		ang = np.arctan2((X * s - 0.15), (Y - 1.43))
		pull = np.sin(ang * 14.0 + fbm(P * 9.0, 2) * 2.0) * sst(1.42, 1.32, Y) * sst(1.16, 1.26, Y) * sst(0.0, 0.08, X * s) * sst(0.06, 0.12, Z)
		col *= (1.0 - np.clip(pull, 0.0, 1.0) * 0.045)[:, :, None]
	# --- edges: the fold catches the light; a 1.3 cm band of binding (neck and armholes) or a 2 cm turned hem, its coverstitch, the fold's shadow inside
	bd, facing = tank_edges()
	is_hem = (Y < 0.95).astype(np.float32)
	bw = 0.013 + 0.007 * is_hem
	band = 1.0 - sst(bw - 0.0015, bw + 0.0005, bd)
	col = blend(col, col * rgb(236, 234, 230), band * 0.6)                                              # the doubled cloth: a touch duller
	col = blend(col, rgb(232, 229, 222) * (0.75 + 0.25 * shade)[:, :, None], (1.0 - sst(0.0, 0.0028, bd)) * 0.55)   # the rolled fold, lit
	fine = np.cos(2.0 * np.pi * (Y * 0.6 + u * 0.8) / 0.0032)                    # the binding's own fine rib
	col *= (1.0 + band * (1.0 - is_hem) * fine * 0.025)[:, :, None]
	col = darken(col, line(bd - bw, 0.0011) * 0.16, (0.8, 0.79, 0.78))           # where the band is sewn on: a soft groove
	dash = (np.sin(2.0 * np.pi * (u + Y * 0.3) / 0.0042) > -0.35).astype(np.float32)
	for o in (bw - 0.0028, bw - 0.0062):                                         # the coverstitch: two needle rows on the outside
		col = darken(col, line(bd - o, 0.0006) * dash * 0.09, (0.8, 0.8, 0.78))     # (white thread on white: barely there; darker read as grime)
	col = blend(col, col * rgb(206, 202, 196), facing * 0.6)                    # the inside of the turn, a little shaded (darker read as a black outline)
	# --- wear, mild. Sweat: yellowed patches at the pits with a darker tide line round each, and along the collar at the back of his neck.
	for s in (1.0, -1.0):
		pit = np.array([0.255 * s, 1.215, -0.01], np.float32)
		dpit = np.linalg.norm((P - pit) * np.array([1.0, 0.75, 1.0], np.float32), axis=2) + (fbm(P * 11.0, 2) - 0.5) * 0.05
		k = (1.0 - sst(0.04, 0.11, dpit)) * (X * s > 0)
		col = blend(col, col * rgb(232, 214, 166), k * 0.75)
		col = blend(col, col * rgb(206, 186, 140), line(dpit - 0.105, 0.007) * (X * s > 0) * 0.45)
	collar = (1.0 - sst(0.008, 0.035, bd)) * sst(1.36, 1.42, Y) * (0.55 + 0.45 * fbm(P * 16.0, 2))
	col = blend(col, col * rgb(226, 214, 184), collar * (0.2 + 0.45 * sst(0.0, -0.1, Z)))
	# dried drips down the front: an irregular blot with a darker rim, and a run of droplets below it (coffee on the right of his chest, grease low on the left)
	for (cx, cy, rad, tint, kk) in ((-0.085, 1.27, 0.022, (196, 168, 132), 0.5), (0.11, 1.03, 0.017, (186, 176, 150), 0.42)):
		dd = np.sqrt((X - cx) ** 2 + ((Y - cy) * 1.25) ** 2) + (fbm(P * 45.0 + cx * 10.0, 2) - 0.5) * rad * 0.9
		fr = sst(0.05, 0.12, Z)
		blot = (1.0 - sst(rad * 0.85, rad, dd)) * fr
		col = blend(col, col * rgb(*tint), blot * kk * 0.75)
		col = blend(col, col * rgb(*tint) * 0.92, line(dd - rad * 0.92, rad * 0.12) * fr * kk)
		for i, (ox, oy, rr) in enumerate(((0.006, -0.032, 0.006), (-0.004, -0.05, 0.0045), (0.011, -0.063, 0.0032), (0.002, -0.078, 0.0024))):
			dp = np.sqrt((X - cx - ox) ** 2 + (Y - cy - oy) ** 2) + (fbm(P * 90.0 + i, 2) - 0.5) * rr * 0.6
			col = blend(col, col * rgb(*tint), (1.0 - sst(rr * 0.7, rr, dp)) * fr * kk * 0.85)
	# greasy finger smudges where he wipes his hands, low on each side by the hem: three short grey-brown streaks
	for s in (1.0, -1.0):
		for i in range(3):
			cx, cy = s * (0.2 + 0.022 * i), 0.955 - 0.012 * i
			along = (Y - cy) * 0.94 + (X - cx) * 0.34 * s
			across = (X - cx) * 0.94 - (Y - cy) * 0.34 * s
			sm = line(across, 0.0055) * sst(-0.045, -0.02, along) * sst(0.035, 0.0, along) * sst(0.0, 0.1, Z)
			col = blend(col, col * rgb(170, 160, 148), sm * (0.45 + 0.4 * fbm(P * 40.0, 2)) * (0.8 if s > 0 else 0.5))
	# grime: greyer toward the hem at the front where it rubs, and a general off-white dinginess
	hem = sst(0.99, 0.88, Y) * (0.5 + 0.5 * fbm(P * 14.0, 2))
	col = darken(col, hem * 0.12, (0.9, 0.86, 0.78))
	ding = sst(0.55, 0.75, fbm(P * 6.0 + 3.0, 3))
	col = blend(col, col * rgb(236, 228, 210), ding * 0.4)
	return col, tank


c, k = paint_tank()
out[k] = c[k]


# ================================================================ denim shorts ================================================================
def paint_shorts():
	## Baggy frayed jorts (user, 2026-11-16; the geometry is jorts.py): a mid-wash indigo, duller and greyer than the old royal blue (which read as plastic in
	## the game's light), worn pale where denim rubs (thigh fronts, the seat, whiskers at the crotch, the cut), the construction a jean has (waistband with
	## belt loops and a button, a J-stitched fly, scoop front pockets, a back yoke and patch pockets, out- and inseams) in tan thread with copper rivets,
	## a blown-out patch on the left thigh, and a fringe of white weft threads at the cut.
	den = sid_mask("bk_shorts", "bk_shorts_fray")
	fray = sid_mask("bk_shorts_fray")
	THREAD = rgb(196, 150, 84)
	COPPER = rgb(166, 102, 56)
	col = ramp(rgb(28, 38, 58), rgb(66, 86, 118), rgb(112, 134, 166), lo=0.4, hi=0.86)
	# the cloth: a fine right-hand twill and slubby warp (streaks running down the leg), the indigo unevenly dyed
	twill = np.sin((X * 0.7 + Y + Z * 0.7) * 2.0 * np.pi / 0.009)
	slub = fbm(stack(X * 300.0, Y * 22.0, Z * 300.0), 2) - 0.5
	col *= (1.0 + twill * 0.04 + slub * 0.16 + mottle * 0.12)[:, :, None]
	# leg coordinates: the thigh axis splays out toward the knee (V1's bones)
	tl = np.clip((0.86 - Y) / 0.34, 0.0, 1.2)
	cx = SX * (0.13 + 0.085 * tl)
	phi = np.arctan2((X - cx) * SX, Z)                              # round each leg: 0 front, +pi/2 outside, pi back, -pi/2 inside
	hip = np.arctan2(AX, Z - 0.01)                                  # round the seat: 0 front, pi/2 side, pi back
	legs = sst(0.82, 0.76, Y)                                       # 1 on the legs, 0 on the seat

	def adist(a, c, r):
		return np.abs((a - c + np.pi) % (2.0 * np.pi) - np.pi) * r

	# fading: pale where it rubs, the creases and the shadows stay dark
	wear = sst(0.35, 1.0, np.cos(phi)) * legs * 0.55                                       # thigh fronts
	wear += sst(-0.2, -0.85, np.cos(phi)) * sst(0.6, 0.72, Y) * legs * 0.35                 # the backs of the legs above the cut
	wear += sst(0.55, 0.95, -np.cos(hip)) * sst(0.92, 0.84, Y) * (1.0 - legs * 0.6) * 0.55  # the seat
	wear *= 0.65 + 0.7 * (fbm(P * 9.0, 3) - 0.2)
	wear *= sst(0.3, 0.75, shade)
	col = blend(col, rgb(138, 158, 186), wear)
	# whiskers: pale streaks fanning up and out from the crotch over the upper thighs, front and back
	for zs, k in ((1.0, 0.4), (-1.0, 0.25)):
		ang = np.arctan2(Y - 0.72, AX + 0.02)
		wk = np.sin(ang * 26.0 + fbm(P * 14.0, 2) * 2.5)
		wh = sst(0.55, 0.9, wk) * sst(0.0, 0.05, AX) * sst(0.24, 0.12, AX) * sst(0.72, 0.76, Y) * sst(0.86, 0.8, Y) * sst(0.0, 0.08, Z * zs)
		col = blend(col, rgb(150, 168, 194), wh * k)

	def seam(d, k, gap=(0.004, 0.0085), dark=0.4):
		## a dark fold along the distance field d (metres), and a double row of thread beside it
		nonlocal col
		col = darken(col, line(d, 0.0022) * k * dark, (0.55, 0.6, 0.7))
		dash = np.sin(Y * 720.0 + X * 300.0 + Z * 300.0) > -0.25
		for o in gap:
			col = blend(col, THREAD, line(np.abs(d - o), 0.0009) * dash * k * 0.6)

	# outseam down the side of each leg and up the hip, inseam inside each leg, the crotch and centre-back seam down the middle
	seam(np.where(legs > 0.5, adist(phi, np.pi / 2.0, 0.2), adist(hip, 1.62, 0.3)), sst(0.94, 0.9, Y))
	seam(adist(phi, -np.pi / 2.0, 0.2), legs * sst(0.8, 0.77, Y))
	seam(AX, np.clip(sst(0.9, 0.86, Y) * (Z < 0.0) + sst(0.8, 0.76, Y) * (Z >= 0.0) * legs, 0.0, 1.0), dark=0.5)
	# waistband: a band 3.6 cm deep round the top with its seam and a row of thread, five belt loops, a copper button
	bd = boundary_dist("bk_shorts")
	top = (Y > 0.86).astype(np.float32)
	wb = (bd < 0.036) * top
	col = blend(col, col * 0.9 + rgb(4, 6, 10), wb)
	seam(np.abs(bd - 0.036), top, gap=(-0.004, 0.004), dark=0.55)
	col = blend(col, THREAD, line(np.abs(bd - 0.007), 0.0009) * top * (np.sin(hip * 900.0) > -0.2) * 0.55)
	for la in (0.48, 1.25, 2.2, np.pi):
		ld = adist(hip, la, 0.3)
		on = (bd < 0.044) * top
		col = blend(col, col * 1.12 + rgb(10, 12, 16), (ld < 0.009) * on)
		col = darken(col, line(np.abs(ld - 0.009), 0.0014) * on * 0.55, (0.5, 0.55, 0.65))
		for o in (0.004, 0.04):
			col = blend(col, THREAD, line(np.abs(bd - o), 0.001) * (ld < 0.008) * top * 0.7)
	btn = np.sqrt(X ** 2 + (Y - 0.887) ** 2) + (Z < 0.1) * 9.0
	col = blend(col, COPPER * (0.75 + 0.5 * sst(0.009, 0.0, btn))[:, :, None], (btn < 0.009) * 1.0)
	col = darken(col, line(btn - 0.009, 0.0012) * 0.6, (0.4, 0.3, 0.25))
	# fly: the centre fold, and a J of double stitching left of it from under the waistband down toward the crotch
	fly = ((Z > 0.1) & (Y < 0.87) & (Y > 0.775)).astype(np.float32)
	fx = X - 0.032 + 0.032 * sst(0.80, 0.775, Y)
	col = darken(col, line(X, 0.0016) * fly * 0.55, (0.5, 0.55, 0.65))
	for o in (0.0, 0.005):
		col = blend(col, THREAD, line(np.abs(fx - o), 0.0009) * fly * (X > -0.002) * (np.sin(Y * 900.0) > -0.2) * 0.6)
	# front pockets: a scoop from the waistband round to the outseam, with its stitching
	fr = Z > 0.05
	for s in (1.0, -1.0):
		u = (AX - 0.27) / 0.14
		v = (Y - 0.905) / 0.075
		scoop = np.sqrt(u * u + v * v)
		pk = ((X * s > 0) & fr & (u < 0.05) & (v < 0.05)).astype(np.float32)
		col = darken(col, line(scoop - 1.0, 0.025) * pk * 0.6, (0.5, 0.55, 0.65))
		col = blend(col, THREAD, line(np.abs(scoop - 1.08), 0.012) * pk * (np.sin(Y * 800.0 + X * 400.0) > -0.2) * 0.55)
	# back: a yoke dipping toward the centre below the waistband, and patch pockets with their arcs
	bk = Z < -0.04
	yoke_y = 0.895 - 0.025 * sst(0.15, 0.0, AX)
	seam(np.abs(Y - yoke_y), bk * sst(0.3, 0.26, AX))
	for s in (1.0, -1.0):
		u = (X * s - 0.115) / 0.065
		v = (Y - 0.815) / 0.05
		box = np.maximum(np.abs(u), np.abs(v) + 0.3 * np.abs(u) * (v < 0))
		pk = (bk & (X * s > 0)).astype(np.float32)
		inside = (box < 1.0) * pk
		col = blend(col, col * 0.93, inside)
		col = darken(col, line(box - 1.0, 0.03) * pk * 0.5, (0.5, 0.55, 0.65))
		for o in (0.9, 0.95):
			col = blend(col, THREAD, line(np.abs(box - o), 0.012) * pk * (np.sin((u + v) * 70.0) > -0.2) * 0.6)
		for o in (0.0, 0.14):
			arc = v - 0.25 * np.cos(u * 2.6) - 0.05 + o
			col = blend(col, THREAD, line(np.abs(arc), 0.035) * inside * (np.abs(u) < 0.8) * 0.45)
	# copper rivets: the ends of each front scoop, the top corners of each back pocket
	for (rx, ry, front) in ((0.13, 0.893, True), (0.27, 0.833, True), (0.05, 0.865, False), (0.18, 0.865, False)):
		for s in (1.0, -1.0):
			rd = np.sqrt((X - rx * s) ** 2 + (Y - ry) ** 2) + ((Z < 0.04) if front else (Z > -0.04)) * 9.0
			col = blend(col, COPPER * (0.8 + 0.5 * sst(0.0045, 0.0, rd))[:, :, None], (rd < 0.0045) * 1.0)
			col = darken(col, line(rd - 0.0045, 0.001) * 0.5, (0.4, 0.3, 0.25))
	# a blown-out patch on the left thigh: a ragged slit, fine white weft threads strung across it over the darker thigh behind, worn pale round it
	hd = np.sqrt(((X - 0.17) / 0.042) ** 2 + ((Y - 0.705) / 0.016) ** 2) + (fbm(P * 50.0, 2) - 0.5) * 0.6
	on = ((X > 0.0) & (Z > 0.1)).astype(np.float32)
	col = blend(col, rgb(176, 190, 208), (1.0 - sst(1.0, 1.7, hd)) * on * 0.65)
	weft = sst(0.1, 0.6, np.sin(Y * 1700.0 + (fbm(P * 30.0, 2) - 0.5) * 4.0)) * (0.7 + 0.3 * fbm(stack(X * 200.0, Y * 900.0, Z * 200.0), 2))
	hcol = mix(rgb(92, 58, 46), rgb(222, 220, 212), weft) * (0.6 + 0.4 * shade)[:, :, None]
	col = blend(col, hcol, (1.0 - sst(0.9, 1.0, hd)) * on)
	# the cut: pale and fuzzy for a few centimetres above the hem, white weft ends showing
	cut = (1.0 - sst(0.0, 0.03, bd)) * (Y < 0.8)
	col = blend(col, rgb(150, 166, 190), cut * 0.5)
	col = blend(col, rgb(222, 224, 222), cut * sst(0.55, 0.85, fbm(stack(phi * 150.0, Y * 40.0, SX * 10.0), 2)) * 0.45)
	# the fringe: white weft threads and blue warp ends hanging from the cut
	thr = fbm(stack(phi * 150.0, Y * 25.0, SX * 10.0), 2)
	tuft = fbm(stack(phi * 18.0, Y * 4.0, SX * 3.0), 2)
	fc = mix(rgb(104, 124, 156), rgb(228, 228, 222), sst(0.3, 0.55, thr) * (0.55 + 0.45 * sst(0.3, 0.6, tuft)))
	fc = fc * (0.6 + 0.4 * shade)[:, :, None]
	col = np.where(fray[:, :, None], fc, col)
	return col, den


c, k = paint_shorts()
out[k] = c[k]


# ================================================================ boots ================================================================
# boots.py's shape, as far as the paint needs it (keep in step with it)
B_X0, B_AXC, B_COLLAR, B_THROAT = 0.265, (0.006, 0.0), 0.428, 0.212
B_MOC_C, B_MOC_R = (0.018, 0.162), (0.082, 0.098)
B_EYES = [0.238, 0.268, 0.298, 0.332, 0.366, 0.4]


def b_tilt(y):
	return -0.036 * sst(0.2, B_COLLAR, y)


def b_open(y):
	return np.where(y < B_THROAT, 0.0, 0.019 + 0.015 * sst(B_THROAT, B_COLLAR, y))


def paint_boots():
	## Worn moc-toe work boots (user, 2026-11-16; the geometry is boots.py) after the references: oiled "crazy horse" brown leather that pulls up pale where
	## it is stretched (toe box, heel, edges) and stays dark in its creases; the moc apron's seam with its cross stitches, the vamp, heel counter, back stay
	## and eyestays outlined by cream double stitching; brass eyelets and speed hooks; a padded collar with a tan lining; flex creases across the instep,
	## scuffed toes and heels, a haze of dried dust low down. The sole: a stitched welt, a dark lug outsole with a dusty edge.
	boot = sid_mask("bk_boot")
	THREAD = rgb(214, 188, 140)
	# local frame per foot: x' outward, the shaft's axis (leaning in with his shin), angle round it (0 toe, pi heel), lateral offset from the front centre line
	xl = AX - B_X0
	cxa = B_AXC[0] + b_tilt(Y)
	ang = np.arctan2(xl - cxa, Z - B_AXC[1])
	aa = np.abs(ang)
	rr = np.hypot(xl - cxa, Z - B_AXC[1])
	lat = rr * np.sin(ang)
	conv = np.clip((PNT - 0.5) * 6.0, -1.0, 1.0)                                     # >0 on convex bulges and edges, <0 in creases
	col = ramp(rgb(42, 24, 15), rgb(106, 62, 36), rgb(156, 102, 64), lo=0.38, hi=0.88)
	# oiled leather: broad waxy patches, a fine pebble grain, pull-up on the stretched convex parts, dark in the creases
	col *= (1.0 + (fbm(P * 9.0, 3) - 0.5) * 0.28)[:, :, None]
	col *= (1.0 + (fbm(P * 160.0, 2) - 0.5) * 0.1)[:, :, None]
	pull = np.clip(conv, 0.0, 1.0) * (0.5 + 0.5 * fbm(P * 25.0, 2))
	col = blend(col, rgb(196, 138, 82) * (0.7 + 0.3 * shade)[:, :, None], pull * 0.45)
	col = darken(col, np.clip(-conv, 0.0, 1.0) * 0.4, (0.6, 0.5, 0.45))
	front = (np.cos(ang) > 0.0)
	# --- the moc toe: a raised seam round the apron, thick cross stitches over it, the apron itself a little paler (it takes the knocks)
	ex = (xl - B_MOC_C[0]) / B_MOC_R[0]
	ez = (Z - B_MOC_C[1]) / B_MOC_R[1]
	em = np.sqrt(ex * ex + ez * ez)
	on_toe = sst(0.095, 0.115, Y) * sst(B_MOC_C[1] - 0.08, B_MOC_C[1] - 0.06, Z) * sst(0.24, 0.2, Y)
	dm = (em - 1.0) * 0.09                                                           # (roughly metres off the seam)
	col = blend(col, col * 1.1, (em < 1.0) * on_toe * 0.5)
	col = darken(col, line(dm - 0.0045, 0.0014) * on_toe * 0.5, (0.5, 0.42, 0.38))
	col = darken(col, line(dm + 0.0045, 0.0014) * on_toe * 0.5, (0.5, 0.42, 0.38))
	phi = np.arctan2(ez, ex)
	cross = (np.sin(phi * 70.0) > 0.25) * (np.abs(dm) < 0.0042)
	col = blend(col, THREAD * (0.75 + 0.25 * shade)[:, :, None], cross * on_toe * 0.85)
	for o in (0.009, 0.013):                                                        # the apron's own stitch rows inside the seam
		col = blend(col, THREAD * (0.7 + 0.3 * shade)[:, :, None], line(dm + o, 0.0007) * on_toe * (np.sin(phi * 160.0) > -0.3) * 0.6)

	def stitched_seam(d, k, rows=(0.004, 0.008)):
		## a panel edge along the distance field d (m, > 0 on the panel that overlaps): its shadow, and rows of thread on the overlapping side
		nonlocal col
		col = darken(col, line(d, 0.0016) * k * 0.55, (0.5, 0.42, 0.36))
		col = blend(col, col * 1.08, sst(0.0, 0.003, d) * sst(0.006, 0.003, d) * k * 0.5)
		dash = (np.sin((Y * 2.0 + rr * ang) * 2.0 * np.pi / 0.0045) > -0.3)
		for o in rows:
			col = blend(col, THREAD * (0.7 + 0.3 * shade)[:, :, None], line(d - o, 0.0007) * dash * k * 0.7)

	# --- the vamp: its edge runs from below the bottom eyelet round each side down to the welt behind the ball; the quarter overlaps it
	a_seam = 0.42 + (1.62 - 0.42) * sst(0.215, 0.08, Y)
	stitched_seam((aa - a_seam) * rr, sst(0.07, 0.085, Y) * sst(0.235, 0.21, Y) * front)
	# --- the heel counter: a cupped panel round the heel, up to 17 cm at the back
	y_hc = 0.075 + 0.1 * sst(1.85, np.pi, aa)
	stitched_seam(y_hc - Y, sst(1.75, 1.95, aa) * sst(0.07, 0.08, Y))
	# --- the back stay: a strip up the back from the counter to the collar
	dbs = (np.pi - aa) * rr
	stitched_seam(0.011 - dbs, (Y > y_hc - 0.005) * (Y < B_COLLAR) * (aa > 2.6), rows=(0.003, 0.0065))
	# --- the lacing: eyestays either side of the opening (stitched along their outer edge and the opening), the tongue between, darker and creased
	h = b_open(Y)
	inopen = (np.abs(lat) < h) * front * (Y > B_THROAT)
	tongue_c = col * rgb(170, 160, 152)
	tongue_c *= (1.0 + np.sin(Y * 260.0 + fbm(P * 20.0, 2) * 3.0)[:, :, None] * 0.05)
	col = np.where(inopen[:, :, None], tongue_c, col)
	stay = front * (Y > B_THROAT - 0.005)
	stitched_seam((h + 0.026) - np.abs(lat), stay * (np.abs(lat) > h), rows=(0.003, 0.0065))
	col = darken(col, line(np.abs(lat) - h, 0.0012) * stay * 0.7, (0.4, 0.33, 0.3))
	col = blend(col, THREAD * (0.7 + 0.3 * shade)[:, :, None], line(np.abs(lat) - h - 0.0035, 0.0007) * stay * (np.sin(Y * 2.0 * np.pi / 0.0045) > -0.3) * 0.6)
	# the tongue's gusset: a shadowed fold where it meets the throat
	col = darken(col, line(Y - B_THROAT, 0.003) * (np.abs(lat) < 0.03) * front * 0.5, (0.5, 0.42, 0.38))
	# --- brass: eyelets low (a dark hole where the lace goes through), speed hooks high
	BRASS_D, BRASS_L = rgb(92, 64, 26), rgb(222, 178, 86)
	for i, ey in enumerate(B_EYES):
		he = 0.019 + 0.015 * sst(B_THROAT, B_COLLAR, ey) + 0.008
		for sd in (-1.0, 1.0):
			de = np.sqrt((lat - sd * he) ** 2 + (Y - ey) ** 2) + (~front) * 9.0
			ring = 1.0 - sst(0.0058, 0.0072, de)
			bc = mix(BRASS_D, BRASS_L, np.clip(shade * 1.1 - 0.15 + 0.4 * sst(0.0035, 0.0055, de) * (1.0 - sst(0.0055, 0.007, de)), 0.0, 1.0))
			col = blend(col, bc, ring)
			if i < 3:
				col = blend(col, rgb(18, 12, 8), 1.0 - sst(0.0022, 0.003, de))
			col = darken(col, line(de - 0.0075, 0.001) * 0.5, (0.5, 0.42, 0.36))
	# --- the collar: a padded roll in a darker, softer leather, its seam and stitches, a tan lining inside; the pull tab
	shaft_r = 1.0 / np.sqrt((np.sin(ang) / 0.135) ** 2 + (np.cos(ang) / 0.148) ** 2)
	roll = sst(B_COLLAR - 0.012, B_COLLAR - 0.004, Y) * (1.0 - inopen)
	col = blend(col, ramp(rgb(40, 22, 14), rgb(98, 54, 32), rgb(146, 92, 58), lo=0.38, hi=0.9) * (1.0 + (fbm(P * 30.0, 2) - 0.5) * 0.2)[:, :, None], roll * 0.85)
	col = darken(col, line(Y - (B_COLLAR - 0.012), 0.0012) * (1.0 - inopen) * 0.5, (0.5, 0.42, 0.36))
	col = blend(col, THREAD * (0.7 + 0.3 * shade)[:, :, None], line(Y - (B_COLLAR - 0.017), 0.0007) * (np.sin(ang * 260.0) > -0.3) * (1.0 - inopen) * 0.6)
	lining = (rr < shaft_r - 0.008) * (Y > B_COLLAR - 0.07)
	col = np.where(lining[:, :, None], mix(rgb(84, 64, 44), rgb(176, 146, 108), shade) * (1.0 + (fbm(P * 60.0, 2) - 0.5) * 0.2)[:, :, None], col)
	tab = (Y > B_COLLAR + 0.004) * (aa > 2.8) * (~inopen.astype(bool))
	col = np.where(tab[:, :, None], ramp(rgb(60, 34, 20), rgb(134, 82, 46), rgb(180, 122, 74)), col)
	# --- wear: flex creases across the instep, scuffed toes and heels (pale abrasion with scratches), dust low on the upper, dark oil at the welt
	crease_k = sst(0.13, 0.15, Y) * sst(0.215, 0.19, Y) * front * (aa < 1.2)
	cr = np.sin(Y * 420.0 + np.abs(lat) * 18.0 + fbm(P * 15.0, 2) * 4.0)
	col = darken(col, np.clip(cr, 0.0, 1.0) ** 3 * crease_k * 0.5, (0.55, 0.46, 0.42))
	col = blend(col, col * 1.15, np.clip(-cr, 0.0, 1.0) ** 4 * crease_k * 0.6)
	scuff = sst(0.55, 0.72, fbm(P * 32.0 + 5.0, 3)) * (sst(0.2, 0.26, Z) * sst(0.15, 0.08, Y) + sst(2.4, 2.9, aa) * sst(0.15, 0.09, Y))
	scratch = sst(0.6, 0.9, np.sin((Y * 3.0 + xl * 2.0 + Z) * 900.0 + fbm(P * 20.0, 2) * 6.0)) * scuff
	col = blend(col, rgb(170, 132, 96) * (0.75 + 0.25 * shade)[:, :, None], scuff * 0.55)
	col = blend(col, rgb(200, 168, 128), scratch * 0.35)
	dust = sst(0.13, 0.075, Y) * (0.55 + 0.45 * fbm(P * 12.0, 3))
	col = blend(col, rgb(132, 114, 96) * (0.7 + 0.3 * shade)[:, :, None], dust * 0.35)
	col = darken(col, sst(0.085, 0.07, Y) * 0.25, (0.7, 0.62, 0.55))
	return col, boot


c, k = paint_boots()
out[k] = c[k]


def paint_sole():
	## the welt (leather, its top stitched in thick cream thread), a dark midsole, the lug outsole: near-black rubber, its edge greyed with dried dust and mud
	sole = sid_mask("bk_sole")
	xl = AX - B_X0
	ang = np.arctan2(xl - B_AXC[0], Z - B_AXC[1])
	welt = sst(0.054, 0.058, Y)
	rubber = mix(rgb(14, 12, 11), rgb(52, 46, 41), shade) * (1.0 + (fbm(P * 70.0, 2) - 0.5) * 0.25)[:, :, None]
	lugs = np.sin(ang * 32.0)
	rubber = darken(rubber, np.clip(lugs, 0.0, 1.0) * sst(0.045, 0.03, Y) * 0.35, (0.6, 0.6, 0.6))
	mud = sst(0.5, 0.7, fbm(P * 14.0 + 2.0, 3)) * sst(0.045, 0.01, Y)
	rubber = blend(rubber, rgb(96, 84, 70) * (0.6 + 0.4 * shade)[:, :, None], mud * 0.6 + sst(0.012, 0.0, Y) * 0.25)
	leather = ramp(rgb(30, 18, 12), rgb(76, 46, 28), rgb(116, 76, 48), lo=0.38, hi=0.88)
	top = sst(0.064, 0.0675, Y)
	st = (np.sin(ang * 150.0) > 0.0) * top
	leather = blend(leather, THREAD_S * (0.7 + 0.3 * shade)[:, :, None], st * 0.85)
	leather = darken(leather, line(Y - 0.0605, 0.0012) * 0.4, (0.5, 0.45, 0.4))           # the welt's notched edge
	col = mix(rubber, leather, welt)
	col = blend(col, rgb(120, 104, 88) * (0.6 + 0.4 * shade)[:, :, None], sst(0.6, 0.75, fbm(P * 20.0, 2)) * welt * 0.3)   # dust in the welt
	return col, sole


THREAD_S = rgb(214, 188, 140)
c, k = paint_sole()
out[k] = c[k]
lace = sid_mask("bk_lace")
# laces: a gold-tan braided cord, its twist in darker flecks
tw = np.sin((X * 1.3 + Y * 1.7 + Z * 1.1) * 2400.0) + (fbm(P * 400.0, 2) - 0.5) * 1.5
lc = mix(rgb(96, 62, 22), rgb(214, 160, 70), np.clip(shade * 1.1, 0.0, 1.0)) * (1.0 - np.clip(tw, 0.0, 1.0)[:, :, None] * 0.35)
out[lace] = lc[lace]


# ================================================================ hair, brows, mustache ================================================================
def paint_hair():
	hair = sid_mask("bk_hair")
	base = mix(rgb(8, 7, 6), rgb(30, 25, 22), shade)
	front = Z > 0.06
	brow = hair & front & (Y > 1.69) & (Y < 1.74) & (AX < 0.1)
	lash = hair & front & (Y > 1.68) & (Y < 1.7) & (Z > 0.12) & (AX < 0.085)
	stache = hair & front & (Y < 1.66) & (Y > 1.58)
	# head and back hair: strands falling from the crown, swept back over the ears, the long fall down the back
	crown = np.array([0.0, 1.9, 0.02], np.float32)
	d = P - crown
	ang = np.arctan2(d[:, :, 0], d[:, :, 2])
	rr = np.linalg.norm(d, axis=2)
	sq = stack(ang * 34.0, rr * 7.0, SX * 3.0)
	strand = fbm(sq + fbm(stack(ang * 6.0, rr * 3.0, 0.0), 2)[:, :, None] * 1.5, 3)
	sheen = sst(0.1, 0.5, N[:, :, 1]) * sst(0.9, 0.5, N[:, :, 1])
	hc = mix(base, base * 0.5, sst(0.55, 0.3, strand))
	hc = blend(hc, rgb(92, 78, 66), sst(0.55, 0.75, strand) * (0.35 + 0.65 * sheen) * 0.85 * shade)
	col = hc
	# brows: short coarse hairs sweeping outward and up
	bq = stack(AX * 28.0, (Y - 0.22 * AX) * 520.0, Z * 40.0 + SX * 5.0)
	bs = fbm(bq, 3)
	bc = mix(base, base * 0.45, sst(0.5, 0.25, bs))
	bc = blend(bc, rgb(74, 60, 52), sst(0.6, 0.8, bs) * sst(0.0, 0.5, N[:, :, 1] + 0.3) * 0.7)
	col = np.where(brow[:, :, None], bc, col)
	col = np.where(lash[:, :, None], base * 0.6, col)
	# mustache: thick hairs fanning out and down from under the nose, lit along its top roll
	cp = np.array([0.0, 1.64, 0.18], np.float32)
	ma = np.arctan2(Y - cp[1], AX + 0.004)
	mr = np.sqrt(AX ** 2 + (Y - cp[1]) ** 2)
	mq = stack(ma * 42.0, mr * 18.0, SX * 4.0 + Z * 20.0)
	ms = fbm(mq, 3)
	mc = mix(base, base * 0.45, sst(0.52, 0.28, ms))
	top = sst(0.0, 0.6, N[:, :, 1] + 0.2)
	mc = blend(mc, rgb(84, 68, 58), sst(0.58, 0.8, ms) * top * 0.75)
	col = np.where(stache[:, :, None], mc, col)
	return col, hair


c, k = paint_hair()
out[k] = c[k]

out *= (1.0 + grain * 0.045 * (1.0 - SMOOTH))[:, :, None]
out = np.clip(out, 0.0, 1.0)
img = (np.flipud(out) * 255.0 + 0.5).astype(np.uint8)          # (the maps are bottom row first, as Blender stores them; the PNG is top first)
tmp = OUT + ".tmp.png"
Image.fromarray(img).save(tmp)
os.replace(tmp, OUT)
print("paint:", OUT)
