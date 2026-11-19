## FOINT CITY townsfolk: the lilac spider (working name; the user names her). A four-armed goth woman, 2.10 m: a long smooth head with three orange eyes, a dark blade crest, plum lips; black crop top, studded choker, wine-red flares, heeled ankle boots.
# Concept: the user's sheet 5.webp, top left (F:/prog-godot-cache/folk/refs/5.webp, box 118,0,360,388). Measured off it (head top to heel 365 px, so 5.75 mm a pixel):
# the head 0.31 m tall from crown to chin and about 0.6 m from lips to the blade point behind (a big bulb with a steep face, three eyes in an arc across its
# upper half, wide lips at the bottom front; behind the neck it is drawn out into a drooping blade); the neck thin (r 2.7 cm) and short, 11 cm showing above a
# studded choker at 1.67 m; shoulders 1.57 m and narrow; a short torso (bust 1.44, top's hem 1.35, waist 1.29, belt 1.22) on long legs (crotch 1.04);
# FOUR very long thin arms (the upper pair from the shoulders, the lower pair from her flanks just under the crop top), spidery hands about 0.3 m long.
# Rest pose = her walking pose: the upper arms hang loose, elbows a little out; the lower arms reach out and down like a spider's legs, wrists drooping.
import math
import os
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3, ridge_line)

HEIGHT = 2.10
REF = ("5.webp", (118, 0, 360, 388))

SKIN, ARM, ARM2, EYE, LIP, NAIL, HAIR, TOP, BAND, TROUSERS, BELT, SILVER, GOLD, BOOT, SOLE, LEATHER, HEM = range(1, 18)
COLOURS = {
    SKIN: ((0.60, 0.42, 0.66), 0.5, 0.0),
    ARM: ((0.60, 0.42, 0.66), 0.5, 0.0),
    ARM2: ((0.56, 0.40, 0.64), 0.5, 0.0),
    EYE: ((1.0, 0.45, 0.16), 0.2, 0.0),
    LIP: ((0.26, 0.05, 0.16), 0.35, 0.0),
    NAIL: ((0.08, 0.03, 0.08), 0.25, 0.0),
    HAIR: ((0.05, 0.035, 0.06), 0.4, 0.0),
    TOP: ((0.035, 0.03, 0.04), 0.7, 0.0),
    BAND: ((0.02, 0.02, 0.025), 0.35, 0.0),
    TROUSERS: ((0.30, 0.04, 0.06), 0.75, 0.0),
    HEM: ((0.36, 0.06, 0.07), 0.75, 0.0),
    BELT: ((0.12, 0.06, 0.035), 0.5, 0.0),
    SILVER: ((0.78, 0.78, 0.80), 0.25, 1.0),
    GOLD: ((0.86, 0.62, 0.28), 0.3, 1.0),
    BOOT: ((0.03, 0.025, 0.03), 0.3, 0.0),
    SOLE: ((0.015, 0.012, 0.015), 0.5, 0.0),
    LEATHER: ((0.02, 0.018, 0.024), 0.35, 0.0),
}

# landmarks, left side (+X); the figure faces -Y
NECK_TOP = v3((0.0, 0.0, 1.80))
SHOULDER = v3((0.163, 0.015, 1.55))
ELBOW = v3((0.29, 0.06, 1.23))
WRIST = v3((0.30, -0.01, 0.94))
ROOT2 = v3((0.088, 0.045, 1.305))        # where the lower arm leaves her flank, just under the top's band
ELBOW2 = v3((0.232, 0.105, 1.115))
WRIST2 = v3((0.46, 0.085, 1.075))
HIP = v3((0.10, 0.015, 1.06))
KNEE = v3((0.13, -0.005, 0.58))
ANKLE = v3((0.155, 0.035, 0.13))
BALL = v3((0.159, -0.075, 0.0))           # the ball of her left foot, what she stands and rolls on
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
# the hands: the upper pair hangs on along the forearm, fingers a little forward; the lower pair droops from the wrist, down and out
H1 = basis(-(v3((0.0, -0.12, -1.0))), v3((0, 1, 0)))
H2 = basis(-(v3((0.30, -0.05, -1.0))), v3((0, 1, 0)))


def hit(shape, o, d, t1=0.8, n=800):
    """where a ray from o along d first enters `shape`, and the surface normal there"""
    o = v3(o)
    d = v3(d) / np.linalg.norm(d)
    ts = np.linspace(0.0, t1, n).astype(np.float32)
    dd = shape.eval(o[None] + ts[:, None] * d[None])[0]
    i = int(np.argmax(dd < 0))
    a, b = float(ts[max(i - 1, 0)]), float(ts[i])
    for _ in range(30):
        m = (a + b) * 0.5
        if shape.eval((o + m * d)[None].astype(np.float32))[0][0] < 0:
            b = m
        else:
            a = m
    p = (o + b * d).astype(np.float32)
    e = 2e-4
    g = np.array([shape.eval((p + ex)[None])[0][0] - shape.eval((p - ex)[None])[0][0] for ex in np.eye(3, dtype=np.float32) * e], np.float32)
    return p, g / np.linalg.norm(g)


# ---------------------------------------------------------------------------------------------------- the head

def head_base():
    """the skull without its features: a big bulb with a steep face and a filled lower face, cheeks, drawn out behind the neck into a drooping blade
    (a crease under it to the point); the thin neck flaring into it like a trumpet"""
    bulb = Ellipsoid((0, -0.095, 1.95), (0.135, 0.165, 0.155))
    lower = Ellipsoid((0, -0.155, 1.855), (0.1, 0.108, 0.075))
    cheeks = Mirror(Ellipsoid((0.07, -0.19, 1.885), (0.045, 0.045, 0.032), R=rot(rz=-25)))
    rear = Gem((0, 0.07, 1.97), (0.085, 0.085, 0.12, 0.36, 0.10, 0.11), soft=0.35, edge=0.012, R=rot(rx=-8))
    neck = loft([(v3((0, 0.028, 1.58)), 0.028), (v3((0, 0.02, 1.70)), 0.027), (NECK_TOP, 0.034)])
    skull = Union([Union([bulb, lower, rear], k=0.09), cheeks], k=0.03)
    return Union([skull, neck], k=0.085, part=SKIN)


HEAD0 = head_base()
HEAD_C = v3((0.0, -0.06, 1.97))


class Eye:
    def __init__(self, c, f, r, lid, slant, side):
        self.c, self.f, self.r = c, f, r
        up = v3((0, 0, 1)) - f * float(f[2])
        self.up = up / np.linalg.norm(up)
        out = np.cross(self.up, f) * side
        self.out = out / max(np.linalg.norm(out), 1e-6)
        self.lid_pt = c + self.up * (lid * r)
        n = -self.up + self.out * slant
        self.lid_n = n / np.linalg.norm(n)


def _eye(origin_dir, r, lid, slant, side, sink=0.42):
    """an eye where a ray toward the head's centre meets the face; it looks halfway between that ray and the face's normal there"""
    d = v3(origin_dir) / np.linalg.norm(origin_dir)
    p, n = hit(HEAD0, HEAD_C + d * 0.5, -d)
    f = n + d
    f /= np.linalg.norm(f)
    return Eye(p - f * (r * sink), f, r, lid, slant, side)


# the three eyes in an arc across the upper face: the middle one rounder and open, the outer two bigger, heavy-lidded and swept back
EYES = [_eye((0.0, -1.0, -0.03), 0.045, 0.6, 0.0, 1.0, sink=0.5),
        _eye((math.sin(math.radians(36)), -math.cos(math.radians(36)), -0.09), 0.053, 0.2, -0.12, 1.0, sink=0.5)]
LOWER = (0.76, 0.72)       # where the lower lid stops, of each eye's radius below its centre
MOUTH_Z = 1.83


def lip_line(dz, inset, half=0.078, n=13):
    """points across the front of the face at height MOUTH_Z + dz, sitting `inset` out of its surface; her right corner (x < 0) curls up in a smirk"""
    pts = []
    for x in np.linspace(-half, half, n):
        smirk = 0.016 * max(0.0, (-x - 0.03) / (half - 0.03)) ** 1.6 + 0.005 * (x / half) ** 2
        z = MOUTH_Z + dz + smirk
        p, nn = hit(HEAD0, (x, -0.5, z), (0, 1, 0))
        pts.append((p + nn * inset, x))
    return pts


def head():
    face = HEAD0
    lids, balls = [], []
    for e, lw in zip(EYES, LOWER):
        lid = Clip(Sphere(e.c, e.r + 0.0058, part=SKIN), [Half(e.lid_pt, e.lid_n)], k=0.004)
        lower = Clip(Sphere(e.c, e.r + 0.0045, part=SKIN), [Half(e.c - e.up * (e.r * lw), e.up)], k=0.004)
        rim = Union([lid, lower])
        ball = Sphere(e.c, e.r, part=EYE)
        if abs(e.c[0]) > 1e-3:
            rim, ball = Mirror(rim), Mirror(ball)
        lids.append(rim)
        balls.append(ball)
    face = Union([face] + lids, k=0.007)
    # the lips: a full upper and a fuller lower lip wrapped round the front of the face, wide as the outer eyes
    # the upper lip thinner with a cupid's bow at its middle, the lower full; both sunk half into the face so they swell from it rather than sit on it
    up = lip_line(0.007, -0.0015)
    up = [(p + v3((0, 0, 0.0035 * math.exp(-((abs(x) - 0.016) / 0.01) ** 2) - 0.002 * math.exp(-(x / 0.006) ** 2))), x) for p, x in up]
    lo = lip_line(-0.011, -0.001, half=0.07)
    ru = lambda x: 0.0045 + 0.0062 * (1.0 - (x / 0.078) ** 2)
    rl = lambda x: 0.0045 + 0.0095 * (1.0 - (x / 0.07) ** 2) ** 0.7
    lips = Union([loft([(p, ru(x)) for p, x in up], part=LIP, k=0.004), loft([(p, rl(x)) for p, x in lo], part=LIP, k=0.004)], k=0.005)
    part_line = lip_line(-0.002, 0.003, half=0.074)
    lips = Cut(lips, [loft([(p, 0.0018) for p, x in part_line])], k=0.0015)
    face = Union([face, lips], k=0.01)
    return Union([face] + balls, k=0.0)


def blade(root, ang, L, W, bend, splay, x, t=0.006):
    """one lock of the crest: a flat curved blade with a rounded spine, leaving the crown at `ang` degrees (0 straight back, + up), bending down by `bend`"""
    a = math.radians(ang)
    eu = v3((math.sin(math.radians(splay)), math.cos(a), math.sin(a)))
    eu /= np.linalg.norm(eu)
    en = np.cross(eu, v3((0, 0, 1)))
    en /= np.linalg.norm(en)
    ev = np.cross(en, eu)
    R = np.stack([eu, ev, en], 1).astype(np.float32)
    us = np.linspace(0.0, 1.0, 7)
    vc = [-bend * L * u ** 2 for u in us]
    w = [W * 0.5 * (1.0 - u ** 1.6) ** 0.8 * (0.75 + 0.25 * min(1.0, u * 5.0)) for u in us]
    top = [(u * L, vc[i] + w[i]) for i, u in enumerate(us)]
    bot = [(u * L, vc[i] - w[i]) for i, u in enumerate(us)][::-1]
    poly = top + bot[1:]
    base = v3(root) + v3((x, 0, 0))
    plate = Slab(base, poly, t, rr=0.003, R=R, part=HAIR)
    spine = loft([(base + R @ v3((u * L, vc[i * 2], 0.0)), 0.011 * (1.0 - u) + 0.0018) for i, u in enumerate(us[::2])], part=HAIR, k=0.004)
    return Union([plate, spine], k=0.005)


def crest():
    """the crest: broad dark blades rooted along the crown and the back of the skull, swept back and cascading down past the blade of the head to her shoulders"""
    locks = []
    spec = [  # (along the crown 0..1, angle, length, width, bend, splay)
        (0.00, 30, 0.42, 0.074, 0.36, 0), (0.10, 24, 0.50, 0.082, 0.46, 6), (0.16, 20, 0.50, 0.082, 0.5, -6),
        (0.27, 12, 0.56, 0.085, 0.6, 9), (0.33, 8, 0.56, 0.085, 0.62, -9), (0.45, 0, 0.58, 0.085, 0.62, 4),
        (0.55, -6, 0.56, 0.08, 0.6, -7), (0.65, -14, 0.52, 0.078, 0.55, 5), (0.76, -22, 0.48, 0.072, 0.5, -3),
        (0.86, -30, 0.42, 0.066, 0.45, 3), (0.95, -40, 0.34, 0.058, 0.4, -2)]
    for t, ang, L, W, bend, spl in spec:
        root = v3((0.0, -0.11 + 0.28 * t, 2.09 - 0.11 * t ** 1.3))
        x = 0.026 * math.sin(math.radians(spl) * 6.0)
        locks.append(blade(root, ang, L, W, bend, spl, x))
    return Union(locks, k=0.004)


# ---------------------------------------------------------------------------------------------------- the body

def torso_core():
    """bare skin: chest, bust, the base of the neck (the top's high neck covers it), a narrow waist (the midriff shows), the pelvis under the trousers"""
    return Union([
        Ellipsoid((0, 0.02, 1.535), (0.14, 0.07, 0.05)),
        Ellipsoid((0, 0.012, 1.46), (0.118, 0.079, 0.11)),
        Mirror(Ellipsoid((0.055, -0.042, 1.44), (0.054, 0.05, 0.05))),
        RoundCone((0, 0.025, 1.55), (0, 0.027, 1.66), 0.052, 0.031),
        Ellipsoid((0, 0.012, 1.295), (0.083, 0.064, 0.095)),
        Ellipsoid((0, 0.015, 1.15), (0.15, 0.105, 0.10)),
    ], k=0.06, part=SKIN)


def upper_arm():
    S, E, W = SHOULDER, ELBOW, WRIST
    up = loft([(S, 0.034), (S + (E - S) * 0.45, 0.027), (E, 0.0205)], part=ARM, k=0.01)
    knob = Sphere(E + v3((0.004, 0.011, 0.0)), 0.023, part=ARM)
    fore = loft([(E, 0.0205), (E + (W - E) * 0.3, 0.023), (W, 0.0155)], part=ARM, k=0.01)
    return Union([up, knob, fore], k=0.012)


def armband():
    S, E = SHOULDER, ELBOW
    return CappedCone(S + (E - S) * 0.16, S + (E - S) * 0.32, 0.0375, 0.0355, rr=0.004, part=LEATHER)


def lower_arm():
    S, E, W = ROOT2, ELBOW2, WRIST2
    root = Sphere(S, 0.027, part=ARM2)
    up = loft([(S, 0.026), (S + (E - S) * 0.5, 0.023), (E, 0.019)], part=ARM2, k=0.01)
    knob = Sphere(E + v3((0.0, 0.006, -0.007)), 0.0215, part=ARM2)
    fore = loft([(E, 0.019), (E + (W - E) * 0.3, 0.021), (W, 0.015)], part=ARM2, k=0.01)
    return Union([root, up, knob, fore], k=0.012)


def top_and_choker(core):
    shell = Clip(Inflate(core, 0.0065, part=TOP), [Half((0, 0, 1.352), (0, 0, -1)), Half((0, 0, 1.655), (0, 0, 1))], k=0.003)
    # a high neck and deep armholes: her shoulders bare, the top held up by broad straps either side of the neck
    shell = Cut(shell, [Mirror(Ellipsoid((0.19, 0.012, 1.565), (0.088, 0.12, 0.09)))], k=0.008)
    band = Clip(Inflate(core, 0.0105, part=BAND), [Half((0, 0, 1.345), (0, 0, -1)), Half((0, 0, 1.374), (0, 0, 1))], k=0.002)
    choker = CappedCone((0, 0.026, 1.645), (0, 0.025, 1.69), 0.036, 0.034, rr=0.005, part=LEATHER)
    return Union([shell, band, choker], k=0.0)


def legs():
    hips = Union([
        Ellipsoid((0, 0.015, 1.12), (0.175, 0.118, 0.125)),
        Ellipsoid((0, 0.012, 1.21), (0.105, 0.078, 0.045)),
        Mirror(Ellipsoid((0.068, 0.05, 1.075), (0.088, 0.078, 0.092))),
    ], k=0.05, part=TROUSERS)
    thigh = loft([(HIP, 0.09), (v3((0.117, 0.0, 0.84)), 0.071), (KNEE, 0.052)], part=TROUSERS, k=0.02)
    # the bell: fitted to the knee, then a trumpet flaring to a hem nearly as wide as her hips; flatter side to side than front to back so the legs pass
    a, m1, m2, b = v3((0.13, -0.005, 0.56)), v3((0.138, 0.004, 0.36)), v3((0.146, 0.012, 0.19)), v3((0.155, 0.02, 0.026))
    bell = Union([CappedCone(a, m1, 0.054, 0.078), CappedCone(m1, m2, 0.078, 0.118), CappedCone(m2, b, 0.122, 0.18, rr=0.006)], k=0.04, part=TROUSERS)
    bell = Cut(bell, [CappedCone((0.155, 0.02, -0.02), (0.153, 0.016, 0.13), 0.17, 0.1)], k=0.004)
    bell = Clip(bell, [Half((0, 0, 0.032), (0.0, -0.05, -1.0))], k=0.003)
    # the turned-up cuff round the hem
    cuff = Clip(Inflate(bell, 0.004, part=HEM), [Half((0, 0, 0.068), (0.0, 0.05, 1.0))], k=0.002)
    bell = Union([bell, cuff], k=0.0)
    bell = Move(bell, R=np.diag([1 / 0.80, 1.0, 1.0]).astype(np.float32), pivot=(0.155, 0.0, 0.0))
    leg = Union([thigh, bell], k=0.04, part=None)
    trousers = Union([hips, Mirror(leg)], k=0.04)
    # low on the hips: the waistband dips to the front
    return Clip(trousers, [Half((0, 0, 1.232), (0.0, 0.12, 1.0))], k=0.003)


def belt():
    hipcore = Ellipsoid((0, 0.013, 1.20), (0.118, 0.087, 0.07))
    band = Clip(Inflate(hipcore, 0.009, part=BELT), [Half((0, 0, 1.236), (0, 0.12, 1)), Half((0, 0, 1.208), (0, -0.12, -1))], k=0.002)
    # two buckled straps across the front of her right hip
    hips = Ellipsoid((0, 0.015, 1.12), (0.175, 0.118, 0.125))
    straps = []
    for z in (1.165, 1.12):
        s = Clip(Inflate(hips, 0.012, part=BELT), [Half((0, 0, z + 0.01), (0.3, 0, 1)), Half((0, 0, z - 0.01), (-0.3, 0, -1)),
                                                   Half((-0.03, 0, 0), (1, 0, 0)), Half((0, 0.03, 0), (0, 1, 0))], k=0.002)
        straps.append(s)
    return Union([band] + straps, k=0.0)


def boot():
    shaft = RoundCone(ANKLE + v3((0, 0.005, 0.10)), ANKLE, 0.042, 0.038, part=BOOT)
    foot = loft([(ANKLE + v3((0, 0.012, -0.012)), 0.036), (BALL + v3((0, 0, 0.034)), 0.034), (v3((0.161, -0.15, 0.022)), 0.019),
                 (v3((0.162, -0.198, 0.013)), 0.005)], part=BOOT, k=0.012)
    heel = CappedCone((0.155, 0.046, 0.09), (0.155, 0.056, 0.0), 0.022, 0.017, rr=0.003, part=SOLE)
    return Union([Union([shaft, foot], k=0.015), heel], k=0.004)


def body():
    core = torso_core()
    navel = Ellipsoid((0, -0.06, 1.262), (0.006, 0.01, 0.009))
    skin = Union([core, Mirror(upper_arm()), Mirror(lower_arm())], k=0.022)
    skin = Cut(skin, [navel], k=0.003)
    return Union([skin, top_and_choker(core), Mirror(armband()), legs(), belt(), Mirror(boot())], k=0.0)


# ---------------------------------------------------------------------------------------------------- hands and jewellery

def spider_hand(curl=(16.0, 22.0, 18.0), spread=1.0, length=1.0):
    """a hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): a slim palm, four very long knuckled fingers, a thumb, pointed nails"""
    parts = [Sphere((0, 0, 0), 0.0165, part=SKIN), RoundCone((0, 0, 0.012), (0, 0, -0.02), 0.0158, 0.0152, part=SKIN),
             Ellipsoid((0, 0, -0.055), (0.012, 0.027, 0.05), part=SKIN)]
    nails = []
    for i, (fy, L) in enumerate(((-0.0185, 0.9), (-0.0062, 1.0), (0.006, 0.96), (0.0175, 0.8))):
        ang = math.radians((i - 1.4) * 6.0 * spread)
        d0 = v3((0.0, math.sin(ang), -math.cos(ang)))
        base = v3((0.0, fy, -0.095))
        lens = (0.068 * L * length, 0.054 * L * length, 0.042 * L * length)
        rad = (0.0074, 0.0066, 0.0057, 0.0047)
        pts = [(base, rad[0])]
        a = 0.0
        p = base.copy()
        d = d0
        for k in range(3):
            a += math.radians(curl[k])
            d = d0 * math.cos(a) + v3((-1, 0, 0)) * math.sin(a)
            p = p + d * lens[k]
            pts.append((p.copy(), rad[k + 1]))
        parts.append(loft(pts, part=SKIN, k=0.003))
        for k in (1, 2):
            parts.append(Sphere(pts[k][0] + v3((0.0018, 0, 0)), pts[k][1] * 1.12, part=SKIN))
        nails.append(RoundCone(pts[3][0] - d * 0.007 + v3((0.0015, 0, 0)), pts[3][0] + d * 0.02, 0.0049, 0.0011, part=NAIL))
    th = [(v3((-0.004, -0.02, -0.022)), 0.0088), (v3((-0.013, -0.036, -0.055)), 0.007), (v3((-0.02, -0.043, -0.088)), 0.0059)]
    parts.append(loft(th, part=SKIN, k=0.004))
    tdir = (th[2][0] - th[1][0]) / np.linalg.norm(th[2][0] - th[1][0])
    nails.append(RoundCone(th[2][0] - tdir * 0.006, th[2][0] + tdir * 0.017, 0.0049, 0.0011, part=NAIL))
    return Union([Union(parts, k=0.006)] + nails, k=0.002)


def hands():
    up = place(spider_hand((14.0, 18.0, 16.0), 0.8, 1.12), WRIST, H1)
    lo = place(spider_hand((10.0, 26.0, 22.0), 1.6, 1.15), WRIST2, H2)
    return Mirror(Union([up, lo]))


def bangles(W, E, n, tilt):
    d = (W - E) / np.linalg.norm(W - E)
    out = []
    for i in range(n):
        Rm = basis(d, v3((0, 0, 1)) if abs(d[2]) < 0.9 else v3((0, 1, 0))) @ rot(rx=tilt * (1 if i % 2 else -1), ry=tilt * 0.5 * (i - 1))
        out.append(Torus(W - d * (0.004 + 0.0085 * i), 0.0205 + 0.0006 * i, 0.0036, Rm=Rm, part=GOLD if i % 2 else SILVER))
    return out


def rings():
    """a ring on two fingers of each hand (index and ring finger, first joint), in hand space as spider_hand builds them"""
    return []


def earring():
    """built about its hook at the origin, its face to the front: a ring, a link, a long open diamond with a bar and a small stone in it, a spike under it"""
    R = np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32)
    ring = Torus((0, 0, -0.006), 0.0058, 0.0019, Rm=rot(ry=90), part=SILVER)
    link = RoundCone((0, 0, -0.012), (0, 0, -0.04), 0.0024, 0.0024, part=SILVER)
    c = v3((0, 0, -0.092))
    outer = Slab(c, [(0, 0.052), (0.03, 0), (0, -0.052), (-0.03, 0)], 0.003, rr=0.001, R=R, part=SILVER)
    inner = Slab(c, [(0, 0.042), (0.021, 0), (0, -0.042), (-0.021, 0)], 0.006, R=R)
    frame = Cut(outer, [inner], k=0.001)
    bar = RoundCone(c + v3((0, 0, 0.044)), c + v3((0, 0, -0.044)), 0.0017, 0.0017, part=SILVER)
    stone = Gem(c, (0.007, 0.007, 0.004, 0.004, 0.014, 0.014), soft=0.1, edge=0.001, part=SILVER)
    spike = RoundCone((0, 0, -0.152), (0, 0, -0.2), 0.008, 0.001, part=SILVER)
    cap = Sphere((0, 0, -0.149), 0.0058, part=SILVER)
    return Union([ring, link, frame, bar, stone, spike, cap], k=0.0015)


def ear_hook():
    p, n = hit(HEAD0, (0.068, 0.10, 1.62), (0, 0, 1))
    return p


def necklace():
    core = Inflate(torso_core(), 0.0065)
    pts = []
    for t in np.linspace(0.0, 1.0, 9):
        x = 0.04 * (1.0 - t) ** 1.2
        z = 1.645 - 0.165 * t
        p, n = hit(core, (x, -0.4, z), (0, 1, 0))
        pts.append((p + n * 0.003, 0.0021))
    chain = Mirror(loft(pts, part=SILVER, k=0.002))
    end = pts[-1][0]
    R = np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32)
    c = end + v3((0, -0.006, -0.03))
    outer = Slab(c, [(0, 0.026), (0.014, 0), (0, -0.026), (-0.014, 0)], 0.0025, rr=0.001, R=R, part=SILVER)
    inner = Slab(c, [(0, 0.019), (0.008, 0), (0, -0.019), (-0.008, 0)], 0.006, R=R)
    loop = Torus(end + v3((0, -0.003, -0.002)), 0.004, 0.0016, Rm=rot(ry=90), part=SILVER)
    spike = RoundCone(c + v3((0, 0, -0.026)), c + v3((0, 0, -0.045)), 0.004, 0.0008, part=SILVER)
    return Union([chain, loop, Cut(outer, [inner], k=0.001), spike], k=0.0015)


def studs():
    out = []
    for i in range(12):
        a = 2 * math.pi * i / 12
        out.append(Sphere((0.0385 * math.sin(a), 0.0255 - 0.0385 * math.cos(a), 1.667), 0.0043, part=SILVER))
    return out


def buckles():
    def frame(c, w, h, Rm):
        return Cut(Box(c, (w, 0.0025, h), rr=0.0015, R=Rm, part=SILVER), [Box(c, (w - 0.004, 0.006, h - 0.004), R=Rm)], k=0.0)
    out = []
    p, n = hit(Ellipsoid((0, 0.013, 1.20), (0.127, 0.096, 0.079)), (0.05, -0.4, 1.222), (0, 1, 0))
    out.append(frame(p + v3((0, -0.003, 0)), 0.016, 0.017, rot(rz=-20)))
    hips = Inflate(Ellipsoid((0, 0.015, 1.12), (0.175, 0.118, 0.125)), 0.014)
    for z in (1.165, 1.12):
        p, n = hit(hips, (-0.09, -0.4, z + 0.006), (0, 1, 0))
        out.append(frame(p, 0.013, 0.014, rot(rz=25, rx=-10)))
    return out


def jewels():
    hook = ear_hook()
    ear = Move(earring(), t=hook)
    parts = [Mirror(ear), necklace()] + studs() + buckles()
    parts += [Mirror(Union(bangles(WRIST, ELBOW, 3, 8.0))), Mirror(Union(bangles(WRIST2, ELBOW2, 2, 10.0)))]
    return Union(parts, k=0.0)


def pieces():
    only = os.environ.get("FOLK_ONLY", "")
    out = [("head", head, 0.0018), ("hair", crest, 0.003), ("body", body, 0.0035), ("hands", hands, 0.0021), ("jewels", jewels, 0.0015)]
    return [(n, f(), h) for n, f, h in out if not only or n in only.split(",")]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    z = P[:, 2]
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.009) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def mix(a, b, t):
        return a + (b - a) * np.asarray(t, np.float32)[:, None]

    def spk(m, col, amount):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.broadcast_to(np.float32(amount), (int(m.sum()), 1))], 1)

    n3 = noise3(P + 3.1, 0.06)
    n2 = noise3(P, 0.012)
    UP = v3((0, 0, 1))

    # skin: lilac, mottled, with darker mauve blotches (the concept's head and arms are dappled) and fine dark freckles; pinker on knuckles and elbows
    m = c.mask(SKIN, ARM, ARM2)
    sk = np.broadcast_to(srgb(200, 160, 212), (len(P), 3)).copy() * (1.0 + 0.07 * mott)[:, None]
    sk = mix(sk, srgb(150, 104, 166), smooth(0.2, 0.6, n3 * 0.75 + n2 * 0.35) * 0.5)
    sk = mix(sk, srgb(214, 150, 196), c.wear * 0.35)
    # the midriff: the line down her middle and the ribs either side, drawn in shade
    mid = c.mask(SKIN) & (z > 1.2) & (z < 1.35) & (P[:, 1] < 0)
    sk = np.where((mid & (np.abs(P[:, 0]) < 0.006))[:, None], sk * 0.86, sk)
    for zz in (1.29, 1.315):
        sk = np.where((mid & (np.abs(z - zz) < 0.0035) & (np.abs(P[:, 0]) > 0.012) & (np.abs(P[:, 0]) < 0.045))[:, None], sk * 0.9, sk)
    # round the eyes: a dark plum socket, purple shadow on the lids, inked liner with a wing swept back on the outer two
    for e, lw in zip(EYES, LOWER):
        de = Q - e.c
        r = np.linalg.norm(de, axis=1)
        sock = smooth(e.r + 0.022, e.r + 0.006, r) * (de @ e.f > -0.03)
        sk = mix(sk, srgb(118, 66, 134), sock * 0.75)
        pd = (Q - e.lid_pt) @ e.lid_n
        on_lid = (r < e.r + 0.014) & (pd < 0.0)
        sk = mix(sk, srgb(96, 52, 120), on_lid * smooth(-0.035, -0.004, pd) * 0.7)
        edge = (r < e.r + 0.014) & (pd > -0.01) & (pd < 0.004) & (de @ e.f > -0.012)
        c.draw(edge, np.abs(pd + 0.0012), 0.0032 if e.c[0] > 0.01 else 0.0018)
        lo_pt = e.c - e.up * (e.r * lw)
        pl = (Q - lo_pt) @ e.up
        c.draw((r < e.r + 0.012) & (np.abs(pl) < 0.006) & (de @ e.f > -0.006), np.abs(pl - 0.0008), 0.0009, 0.7)
        if e.c[0] > 0.01:
            wt = ((de @ e.out) - e.r * 0.75) / 0.06
            wing = (wt > 0) & (wt < 1) & (r < e.r + 0.06) & (np.abs(pd) < 0.025) & (de @ e.f > -0.03)
            c.draw(wing, np.abs(pd + 0.0012 - 0.016 * np.clip(wt, 0, 1) ** 1.3), 0.0032 * (1.0 - np.clip(wt, 0, 1)) + 0.0002)
    # the smirk's crease up from her right mouth corner, a softer one on her left
    for sx, ln, st in ((-1.0, 0.03, 0.55), (1.0, 0.02, 0.3)):
        a, _ = hit(HEAD0, (sx * 0.075, -0.5, MOUTH_Z + (0.02 if sx < 0 else 0.004)), (0, 1, 0))
        b, _ = hit(HEAD0, (sx * 0.088, -0.5, MOUTH_Z + (0.02 if sx < 0 else 0.004) + ln), (0, 1, 0))
        ab = b - a
        h = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        dist = np.linalg.norm(P - a - np.outer(h, ab), axis=1)
        c.draw(c.mask(SKIN) & (dist < 0.01), dist, 0.0011 * (1.0 - h * 0.7), st)
    put(m, sk[m], 0.48, bump=0.12)
    spk(m, (140, 92, 156), 0.22)

    # eyes: glowing orange, pale peach at the heart going to a red-orange rim; a small inked pupil looking ahead, a glint
    m = c.mask(EYE)
    ir = np.zeros((len(P), 3), np.float32)
    for e in EYES:
        de = Q - e.c
        r = np.linalg.norm(de, axis=1)
        mine = m & (np.abs(r - e.r) < 0.004)
        d = de / np.maximum(r, 1e-6)[:, None]
        g = e.f if e.c[0] < 0.01 else (e.f * 0.45 + v3((0, -1, 0)) * 0.55)
        g = g / np.linalg.norm(g)
        ang = np.arccos(np.clip(d @ g, -1, 1))
        col = mix(np.broadcast_to(srgb(255, 224, 178), (len(P), 3)), srgb(255, 156, 86), smooth(0.1, 0.62, ang))
        col = mix(col, srgb(206, 82, 48), smooth(0.65, 1.0, ang))
        col *= (1.0 - 0.35 * smooth(0.1, 0.45, d @ e.up))[:, None]
        c.draw(mine, (ang - 0.105) * e.r, 0.0)
        gd = g + e.up * 0.3 - e.out * 0.25
        gd /= np.linalg.norm(gd)
        col = mix(col, srgb(255, 252, 240), smooth(0.985, 0.994, d @ gd))
        ir[mine] = col[mine]
    put(m, ir[m], 0.06)

    # lips: plum, the lower lip catching light, dark where they part
    m = c.mask(LIP)
    xs = P[:, 0]
    smirk = 0.016 * np.clip((-xs - 0.03) / 0.048, 0, None) ** 1.6 + 0.005 * (xs / 0.078) ** 2
    zl = MOUTH_Z - 0.002 + smirk
    lp = np.broadcast_to(srgb(116, 38, 84), (len(P), 3)).copy()
    lp = np.where((z < zl)[:, None], lp * 1.18, lp)
    lp *= (1.0 - 0.55 * smooth(0.005, 0.0, np.abs(z - zl)))[:, None]
    put(m, lp[m], 0.26, bump=0.2)
    put(c.mask(NAIL), srgb(48, 16, 50), 0.15)

    # the crest: near-black plum, lighter along its edges, a little more purple toward the tips
    m = c.mask(HAIR)
    tip = smooth(0.15, 0.45, np.linalg.norm(P - v3((0, 0.05, 2.0)), axis=1))
    hc = mix(np.broadcast_to(srgb(36, 24, 42), (len(P), 3)), srgb(72, 48, 86), tip * 0.6)
    hc = mix(hc, srgb(128, 102, 140), c.wear * 0.5)
    hc *= (1.0 + 0.12 * n2)[:, None]
    put(m, hc[m], 0.32, bump=0.25)

    # the crop top: black rib knit; the band at its hem and the choker black leather; armbands leather with silver rims
    m = c.mask(TOP)
    tc = srgb(36, 31, 40) * (1.0 + 0.6 * c.wear)[:, None]
    put(m, tc[m], 0.75, bump=1.0)
    c.strp[m, 0] = (np.arctan2(P[:, 0], -(P[:, 1] - 0.012)) * 0.12 * 3.5)[m]
    c.strp[m, 1] = 0.7
    m = c.mask(BAND, LEATHER)
    lc = srgb(24, 21, 27) * (1.0 + 1.2 * c.wear)[:, None]
    put(m, lc[m], 0.3, bump=0.5, grain=1.0)
    ax = (ELBOW - SHOULDER) / np.linalg.norm(ELBOW - SHOULDER)
    bc = SHOULDER + (ELBOW - SHOULDER) * 0.24
    t_ax = np.abs((Q - bc) @ ax)
    rimz = c.mask(LEATHER) & (Q[:, 0] > 0.08) & (t_ax > 0.019) & (t_ax < 0.03)
    put(rimz, srgb(200, 198, 206), 0.25, metal=1.0)

    # the flares: wine red, rubbed to a hot orange-red over the thighs and the bells (the concept's distressed velvet), seams down the legs, a stitched cuff
    m = c.mask(TROUSERS, HEM)
    tr = np.broadcast_to(srgb(124, 30, 42), (len(P), 3)).copy() * (1.0 + 0.05 * mott)[:, None]
    rub = smooth(0.05, 0.6, n3 * 0.6 + n2 * 0.5 + noise3(P, 0.004) * 0.25) * (0.35 + 0.65 * smooth(0.75, 0.3, z))
    tr = mix(tr, srgb(178, 70, 52), rub * 0.6)
    tr = mix(tr, srgb(160, 64, 58), c.wear * 0.5)
    tr = mix(tr, srgb(70, 14, 22), c.cavity * 0.4)
    put(m, tr[m], 0.82, bump=0.9)
    spk(m, (186, 84, 60), 0.12)
    legs_m = m & (z < 1.08)
    kx = np.interp(z, [0.0, 0.58, 1.06], [0.155, 0.13, 0.10])
    ky = np.interp(z, [0.0, 0.58, 1.06], [0.02, -0.005, 0.015])
    rx, ry = Q[:, 0] - kx, P[:, 1] - ky
    rad = np.hypot(rx, ry)
    phi = np.arctan2(rx, -ry)
    for a0 in (0.0, math.pi * 0.5, -math.pi * 0.5, math.pi * 0.25, -math.pi * 0.3):
        if abs(a0) == math.pi * 0.25 or a0 == -math.pi * 0.3:
            mm = legs_m & (z < 0.5)
        else:
            mm = legs_m
        dphi = np.abs(np.angle(np.exp(1j * (phi - a0))))
        c.draw(mm & (dphi * rad < 0.01), dphi * rad, 0.0009, 0.45)
    fly = m & (P[:, 1] < 0) & (z > 1.1) & (z < 1.225)
    c.draw(fly & (np.abs(P[:, 0] - 0.024) < 0.01), np.abs(P[:, 0] - 0.024), 0.0008, 0.5)
    cuff = c.mask(HEM)
    c.draw(m & (np.abs(z - 0.074) < 0.006), np.abs(z - 0.074), 0.0008, 0.45)
    c.draw(cuff & (np.abs(z - 0.047) < 0.005), np.abs(z - 0.047), 0.0006, 0.35)

    # belt and straps: dark brown leather, rubbed light on the edges
    m = c.mask(BELT)
    put(m, (srgb(66, 40, 28) * (1.0 + 0.9 * c.wear)[:, None])[m], 0.42, bump=0.8, grain=1.0)
    # metal: silver and brass, dark in their recesses
    m = c.mask(SILVER)
    put(m, (srgb(212, 210, 218) * (1.0 - 0.5 * c.cavity)[:, None])[m], 0.22, metal=1.0, bump=0.05, grain=1.0)
    m = c.mask(GOLD)
    put(m, (srgb(226, 178, 100) * (1.0 - 0.5 * c.cavity)[:, None])[m], 0.26, metal=1.0, bump=0.05, grain=1.0)
    # boots: black patent, scuffed at the toes; dark heels and soles
    m = c.mask(BOOT)
    put(m, (srgb(30, 24, 30) * (1.0 + 1.4 * c.wear)[:, None])[m], 0.16, bump=0.15, grain=1.0)
    put(c.mask(SOLE), srgb(20, 16, 18), 0.5, bump=0.3)
    put(c.mask(BOOT) & (z < 0.006), srgb(20, 16, 18), 0.5)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2300, "hair": 1000, "body": 4300, "hands": 1700, "jewels": 700},     # triangles per piece
    "density": {"head": 1.8, "hands": 1.3, "jewels": 1.2},
    "tex": 2048,
    "stride": {"walk": 1.3, "run": 2.1},
    "speed": 0.92,                                                            # languid: long legs, an unhurried pace
    "look": ["head", "ear.L", "ear.R"], "neck": "neck",
    "look_pivot": (0.0, 0.0, 1.80),
    "radius": 0.42,
}


def rig_bones():
    from kit.rig import Bone, mirror
    hook = ear_hook()
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.015, 1.06), (0, 0.015, 1.22), "root", 0.13),
        Bone("spine", (0, 0.015, 1.22), (0, 0.012, 1.37), "hips", 0.08),
        Bone("chest", (0, 0.012, 1.37), (0, 0.022, 1.58), "spine", 0.11),
        Bone("neck", (0, 0.026, 1.62), NECK_TOP, "chest", 0.026),
        Bone("head", NECK_TOP, (0, -0.05, 2.08), "neck", 0.03),
        Bone("ear.L", hook, hook - v3((0, 0, 0.2)), "head", 0.01),
        Bone("shoulder.L", (0.035, 0.018, 1.535), SHOULDER, "chest", 0.04),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.03),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.021),
        Bone("hand.L", WRIST, WRIST - H1[:, 2] * 0.26, "forearm.L", 0.02),
        Bone("arm2.L", ROOT2, ELBOW2, "spine", 0.025),
        Bone("fore2.L", ELBOW2, WRIST2, "arm2.L", 0.02),
        Bone("hand2.L", WRIST2, WRIST2 - H2[:, 2] * 0.26, "fore2.L", 0.02),
        Bone("thigh.L", HIP, KNEE, "hips", 0.09),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.06),
        Bone("foot.L", ANKLE, (0.161, -0.15, 0.022), "shin.L", 0.035),
    ])
    return bones


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for vertices that move rigidly). piece: 0 head, 1 hair, 2 body, 3 hands, 4 jewels"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    fl = FLIP.diagonal()

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    # head: rigid above the neck's flare, the neck bends from the choker
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rnk = np.hypot(x, y - 0.015)
    rig[hp & ((z > 1.795) | (rnk > 0.075))] = ix["head"]
    # the crest rides the head
    cp = piece == 1
    allow(cp, "head")
    rig[cp] = ix["head"]
    # the body: trousers and belt with hips and legs (never the feet: the bells hang from the shins), boots with shins and feet, arms by pair and side
    bp = piece == 2
    trou = bp & np.isin(part, (TROUSERS, HEM, BELT))
    allow(trou, "hips")
    allow(trou & (x > -0.04), "thigh.L")
    allow(trou & (x < 0.04), "thigh.R")
    allow(trou & (x > -0.04) & (z < 0.9), "shin.L")
    allow(trou & (x < 0.04) & (z < 0.9), "shin.R")
    allow(bp & (part == BELT), "spine")
    boots = bp & np.isin(part, (BOOT, SOLE))
    allow(boots & (x > 0), "shin.L", "foot.L")
    allow(boots & (x <= 0), "shin.R", "foot.R")
    arm1 = bp & ((part == ARM) | ((part == LEATHER) & (np.abs(x) > 0.08)))
    allow(arm1 & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L")
    allow(arm1 & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R")
    allow(arm1 & (z > 1.46) & (np.abs(x) < 0.19), "chest")
    arm2 = bp & (part == ARM2)
    allow(arm2, "spine")
    allow(arm2 & (x > 0), "arm2.L", "fore2.L")
    allow(arm2 & (x <= 0), "arm2.R", "fore2.R")
    torso = bp & ~trou & ~boots & ~arm1 & ~arm2
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.08) & (z > 1.45), "shoulder.L")
    allow(torso & (x < -0.08) & (z > 1.45), "shoulder.R")
    allow(torso & (x > 0.05) & (z > 1.24) & (z < 1.36), "arm2.L")
    allow(torso & (x < -0.05) & (z > 1.24) & (z < 1.36), "arm2.R")
    rig[bp & (part == LEATHER) & (np.abs(x) <= 0.08)] = ix["chest"]       # the choker
    # hands: each rigid on its own hand bone
    hd = piece == 3
    wr = [(WRIST, H1, "hand.L"), (WRIST * fl, H1 * fl[:, None], "hand.R"), (WRIST2, H2, "hand2.L"), (WRIST2 * fl, H2 * fl[:, None], "hand2.R")]

    def seg(a, b):
        ab = b - a
        t = np.clip(((P - a) @ ab) / float(ab @ ab), 0, 1)
        return np.linalg.norm(P - a - np.outer(t, ab), axis=1)
    # by distance to each hand's own wrist-to-fingertip line (a lower hand's fingertips come nearer the upper wrist than their own)
    D = np.stack([seg(w, w - h[:, 2] * 0.26) for w, h, _ in wr], 1)
    wr = [(w, bn) for w, _, bn in wr]
    near = np.argmin(D, 1)
    for k, (_, bn) in enumerate(wr):
        allow(hd & (near == k), bn)
        rig[hd & (near == k)] = ix[bn]
    # jewellery: earrings on their own swinging bones, bangles on the forearms, buckles with the hips, the rest on the chest
    jp = piece == 4
    fw = [(WRIST, "forearm.L"), (WRIST * fl, "forearm.R"), (WRIST2, "fore2.L"), (WRIST2 * fl, "fore2.R")]
    D = np.stack([np.linalg.norm(P - w, axis=1) for w, _ in fw], 1)
    near = np.argmin(D, 1)
    bang = jp & (D.min(1) < 0.06)
    for k, (_, bn) in enumerate(fw):
        allow(bang & (near == k), bn)
        rig[bang & (near == k)] = ix[bn]
    ear = jp & ~bang & (z > 1.6) & (np.hypot(x, y - 0.0255) > 0.055) & (y > 0.0)
    allow(ear, "head")
    rig[ear & (x > 0)] = ix["ear.L"]
    rig[ear & (x <= 0)] = ix["ear.R"]
    buck = jp & ~bang & ~ear & (z < 1.3)
    allow(buck, "hips", "spine")
    allow(buck & (x < 0), "thigh.R")
    rest = jp & ~bang & ~ear & ~buck
    allow(rest, "chest")
    rig[rest] = ix["chest"]
    return A, rig


WALK = dict(stride=1.3, stance=0.6, foot_x=0.155, lift=0.06, bob=0.016, drop=0.055, sway=0.036, roll=6.0, yaw=8.0, counter=1.15,
            lean=1.0, toe_off=24.0, toe_out=7.0, swing_point=6.0)
RUN = dict(stride=2.1, stance=0.38, foot_x=0.155, lift=0.16, bob=0.035, drop=0.08, sway=0.022, roll=5.0, yaw=11.0, counter=1.3,
           lean=10.0, toe_off=30.0, toe_out=7.0, swing_point=14.0, spine_lean=5.0)


def motions(rig):
    """her clips: walk (languid: long unhurried strides, hips rolling, four arms dangling and trailing a beat behind like a spider's legs, the long head
    swaying level and aloof), run (a loping scuttle, the lower arms trailing back), idle (weight on a hip, her right hand on it, the left brought up to
    her chin to drum her fingers on it, as in the concept)"""
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector, Matrix, Quaternion
    f = np.array([-1, 1, 1], np.float32)
    F3 = Matrix(FLIP.tolist())
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def head_and_ears(p, u, run):
        p.rot("chest", 2.0, 0, 0)
        p.rot("neck", (8.0 if run else 4.0) + 2.0 * math.sin(2 * TAU * u - 0.9), 0, 0)
        p.world["head"] = R((2.0 if run else -2.0) + 2.2 * math.sin(2 * TAU * u - 1.7), 0, 3.5 * math.sin(TAU * u - 0.7))
        for side, s in (("L", 1.0), ("R", -1.0)):
            p.world["ear." + side] = R((12.0 if run else 0.0) + 8.0 * math.sin(2 * TAU * u - 2.4), s * 5.0 * math.sin(TAU * u - 1.9), 0)

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        A = 30.0 if run else 12.0
        A2 = 14.0 if run else 9.0
        for side, s, ph0 in (("L", 1.0, 0.0), ("R", -1.0, math.pi)):
            ph = TAU * u + ph0
            sw = math.cos(ph)
            # the upper arm a loose pendulum; the forearm and the hand trail it, the hand flopping at the wrist
            p.rot("upper_arm." + side, A * sw, -s * (2.0 + (8.0 if run else 0.0)), 0.0)
            p.rot("forearm." + side, -(50.0 if run else 6.0) + A * 0.55 * (math.cos(ph - 0.8) - sw), 0, 0)
            p.rot("hand." + side, A * 0.9 * (math.cos(ph - 1.6) - math.cos(ph - 0.8)) + (12.0 if run else 0.0), 0, 0)
            # the lower arm swings fore and aft from the flank a beat behind, rising and falling like a spider's leg, the hand trailing
            p.rot("arm2." + side, 0, -s * (3.0 * math.sin(2 * ph - 1.0) - (10.0 if run else 0.0)), s * (A2 * math.cos(ph - 0.6) + (6.0 if run else 0.0)))
            p.rot("fore2." + side, 0, -s * 4.0 * math.sin(2 * ph - 1.6), s * A2 * 0.5 * (math.cos(ph - 1.2) - math.cos(ph - 0.6)))
            p.rot("hand2." + side, A2 * 1.1 * math.cos(ph - 1.8) + (14.0 if run else 0.0), 0, 0)
        head_and_ears(p, u, run)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    def hand_rot(fingers, back):
        """the left upper hand's world rotation from its rest to fingers pointing along `fingers` with the back of the hand to `back`"""
        zz = -np.asarray(fingers, np.float64)
        zz /= np.linalg.norm(zz)
        xx = np.asarray(back, np.float64)
        xx = xx - zz * (xx @ zz)
        xx /= np.linalg.norm(xx)
        yy = np.cross(zz, xx)
        D = np.stack([xx, yy, zz], 1)
        return Matrix((D @ H1.T.astype(np.float64)).tolist())

    sh, el, wr = Vector(SHOULDER.tolist()), Vector(ELBOW.tolist()), Vector(WRIST.tolist())
    line = (wr - sh).normalized()
    pole_rest = (el - sh) - line * (el - sh).dot(line)
    chin_wr, chin_pole = Vector((0.065, -0.2, 1.62)), Vector((0.5, 0.25, -0.8))
    chin_q = hand_rot((-0.2, -0.22, 1.0), (0.55, -0.83, 0.0)).to_quaternion()
    hip_wr, hip_pole = Vector((0.205, 0.005, 1.24)), Vector((1.0, 0.45, 0.15))
    hip_q = hand_rot((-0.2, -0.75, -0.6), (0.75, 0.1, 0.65)).to_quaternion()
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sw = 0.008 * math.sin(TAU * t / 6.0)
        stand(rig, p, legs, {"L": (Vector((0.165, -0.06, 0.0)), 9.0), "R": (Vector((-0.155, 0.02, 0.0)), -10.0)},
              hip_shift=(0.03 + sw, 0.0, -0.02), roll=-4.0, yaw=-4.0)
        p.rot("spine", 1.0 * math.sin(TAU * t / 3.0), 2.5, 3.0)
        p.rot("chest", 1.5 * math.sin(TAU * t / 3.0), 1.5, 2.0)
        s = ease((t - 1.4) / 0.8) * (1.0 - ease((t - 4.4) / 0.9))
        # her left hand to her chin, drumming the long fingers on it
        tap = 5.0 * math.sin(TAU * t * 2.0) * s
        q = Quaternion().slerp(chin_q, s)
        rq = R(tap, 0, 0) @ q.to_matrix()
        p.ik["upper_arm.L"] = (wr.lerp(chin_wr, s), pole_rest.lerp(chin_pole, s), "hand.L", rq)
        # her right hand on her hip the whole time (mirrored from a left-hand pose)
        hq = hip_q.to_matrix()
        p.ik["upper_arm.R"] = (F3 @ hip_wr, F3 @ hip_pole, "hand.R", F3 @ hq @ F3)
        # the lower arms hang and drift, the right one back out of the way of her elbow; the fingers drum at the ends
        p.rot("arm2.L", 0, 2.0 * math.sin(TAU * t / 3.0), 4.0 * math.sin(TAU * t / 6.0))
        p.rot("arm2.R", 0, 0, -14.0 + 2.0 * math.sin(TAU * t / 6.0 + 1.0))
        p.rot("hand2.L", 6.0 * math.sin(TAU * t / 1.5) * ease((t - 0.3) / 0.5) * (1 - ease((t - 1.5) / 0.4)), 0, 0)
        p.rot("hand2.R", 4.0 * math.sin(TAU * t / 3.0), 0, 0)
        p.world["head"] = R(-7.0 * s + 1.5 * math.sin(TAU * t / 3.0), 0, 6.0 * s + 8.0 * math.sin(TAU * t / 6.0) * (1.0 - s))
        p.rot("neck", 3.0, 0, 0)
        for side, sd in (("L", 1.0), ("R", -1.0)):
            p.world["ear." + side] = R(3.0 * math.sin(TAU * t / 2.0 - sd), sd * 2.0 * math.sin(TAU * t / 3.0), 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
