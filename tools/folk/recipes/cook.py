## FOINT CITY townsfolk: the cook. A stout tan fellow with big floppy pig-like ears, a broad snout, a sleepy smug face over a heavy double chin, a pencil behind his ear; blue-striped shirt with rolled sleeves, a stained apron with a wooden spoon and a whisk in its pocket, a checked towel tucked at his hip, rolled dark trousers, crocs. Free hands (the concept's mug is dropped).
# Concept: the user's sheet, image 4 bottom right (F:/prog-godot-cache/folk/refs/4.webp). Measured off it: 1.60 m to the top of the hair; the head 0.33 m tall
# with its double chin, 0.34 wide at the jowls, the ears 0.6 across; a big round belly 0.62 wide; the apron to the knees (0.41); trousers rolled to 0.25.
# Rest pose = his head tipped back, belly out, arms hanging round it.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

F32 = np.float32
HEIGHT = 1.60
REF = ("4.webp", (771, 393, 1076, 782))

(SKIN, EAR_IN, EYE, LIP, HAIR, SHIRT, APRON, STRAP, TOWEL, TROUSERS, CROC, WOOD, STEEL, PENCIL, LEAD, BUTTON) = range(1, 17)
COLOURS = {
    SKIN: ((0.80, 0.62, 0.40), 0.55, 0.0),
    EAR_IN: ((0.85, 0.52, 0.48), 0.5, 0.0),
    EYE: ((0.22, 0.14, 0.08), 0.15, 0.0),
    LIP: ((0.70, 0.45, 0.38), 0.45, 0.0),
    HAIR: ((0.10, 0.08, 0.07), 0.7, 0.0),
    SHIRT: ((0.55, 0.62, 0.78), 0.8, 0.0),
    APRON: ((0.88, 0.82, 0.72), 0.85, 0.0),
    STRAP: ((0.84, 0.78, 0.68), 0.85, 0.0),
    TOWEL: ((0.85, 0.30, 0.30), 0.85, 0.0),
    TROUSERS: ((0.22, 0.21, 0.22), 0.85, 0.0),
    CROC: ((0.90, 0.88, 0.84), 0.5, 0.0),
    WOOD: ((0.65, 0.42, 0.22), 0.6, 0.0),
    STEEL: ((0.75, 0.75, 0.78), 0.3, 1.0),
    PENCIL: ((0.92, 0.70, 0.20), 0.5, 0.0),
    LEAD: ((0.20, 0.18, 0.18), 0.5, 0.0),
    BUTTON: ((0.88, 0.86, 0.82), 0.4, 0.0),
}

# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; the figure faces -Y)
HEAD_C = v3((0.0, -0.02, 1.47))
EYE_C = v3((0.058, -0.125, 1.505))
EYE_R = 0.028
EYE_FWD = v3((0.12, -1.0, -0.25)) / np.linalg.norm((0.12, -1.0, -0.25))    # looking down his snout
LID_PT = EYE_C + v3((0.0, 0.0, 0.001))
LID_N = v3((-0.08, 0.15, -1.0)) / np.linalg.norm((-0.08, 0.15, -1.0))    # heavy sleepy lids, half shut, drooping outward
LOW_Z = EYE_C[2] - 0.021
EAR_ROOT = v3((0.125, -0.005, 1.5))
EAR_U = v3((1.0, 0.1, -0.35)) / np.linalg.norm((1.0, 0.1, -0.35))       # out and drooping
MOUTH_X = 0.06
MOUTH_Z = 1.415
NECK0 = v3((0.0, 0.02, 1.2))
NECK1 = v3((0.0, -0.02, 1.36))

SHOULDER = v3((0.225, 0.03, 1.2))
ELBOW = v3((0.33, 0.05, 0.975))
WRIST = v3((0.35, -0.03, 0.775))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
HIP = v3((0.11, 0.02, 0.75))
KNEE = v3((0.12, -0.01, 0.42))
ANKLE = v3((0.125, 0.025, 0.085))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def prism(poly_xz, y0=-0.6, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def side_prism(poly_yz, x0, x1):
    return Slab(((x0 + x1) * 0.5, 0, 0), poly_yz, (x1 - x0) * 0.5, R=np.array([[0, 0, 1], [1, 0, 0], [0, 1, 0]], np.float32))


def probe(shape, x, z, y0=-0.6, y1=0.4, step=0.0015):
    ys = np.arange(y0, y1, step, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    i = int(np.argmax(d < 0))
    if d[i] >= 0 or i == 0:
        raise ValueError("no surface at x %.3f z %.3f" % (x, z))
    return float(ys[i - 1] + (ys[i] - ys[i - 1]) * d[i - 1] / (d[i - 1] - d[i]))


def on(shape, x, z, inset=0.0):
    return v3((x, probe(shape, x, z) + inset, z))


class Crease(Shape):
    """a Bump along a polyline (mirrored to both sides) that only evaluates near the line: `amp` < 0 cuts a crease, > 0 raises a ridge"""
    def __init__(self, child, pts, width, amp, mirror=True):
        self.child, self.w, self.amp, self.mirror = child, F32(width), F32(amp), mirror
        self.pts = [v3(p) for p in pts]
        self.lo, self.hi = child.bound()
        self.part = child.part
        a = np.array(self.pts)
        self.blo, self.bhi = a.min(0) - width, a.max(0) + width

    def eval(self, P):
        d, pt = self.child.eval(P)
        Q = P.copy()
        if self.mirror:
            Q[:, 0] = np.abs(Q[:, 0])
        m = np.all((Q >= self.blo) & (Q <= self.bhi), axis=1)
        if m.any():
            q = Q[m]
            dm = np.full(len(q), 1e3, np.float32)
            for a, b in zip(self.pts[:-1], self.pts[1:]):
                ab = b - a
                t = np.clip(((q - a) @ ab) / float(ab @ ab), 0.0, 1.0)
                dm = np.minimum(dm, np.linalg.norm(q - a - np.outer(t, ab), axis=1))
            x = np.clip(1.0 - dm / self.w, 0.0, 1.0)
            d[m] -= self.amp * x * x * (3.0 - 2.0 * x)
        return d, pt

    def dist(self, P):
        return self.eval(P)[0]


HS = 1.17                                  # round 2: the head 17% bigger, scaled about its crown
PIV = v3((0.0, -0.02, 1.59))


def W(p):
    return PIV + (v3(p) - PIV) * HS


def L(P):
    return PIV + (P - PIV) / HS


class ScaleAt(Shape):
    """the child scaled by s about a pivot, with a true bound and distances"""
    def __init__(self, child, s, pv):
        self.child, self.s, self.pv = child, F32(s), v3(pv)
        lo, hi = child.bound()
        self.lo, self.hi = self.pv + (np.asarray(lo, F32) - self.pv) * self.s, self.pv + (np.asarray(hi, F32) - self.pv) * self.s
        self.part = child.part

    def eval(self, P):
        d, pt = self.child.eval(self.pv + (P - self.pv) / self.s)
        return d * self.s, pt

    def dist(self, P):
        return self.eval(P)[0]


class Bounded(Shape):
    def __init__(self, child, lo, hi):
        self.child = child
        self.lo, self.hi = v3(lo), v3(hi)
        self.part = child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.child.eval(P)[0]


def slab_box(c, poly, t, R):
    pts = np.array([[u, v, s] for u, v in poly for s in (-t, t)], np.float32)
    w = pts @ np.asarray(R, np.float32).T + v3(c)
    return w.min(0) - 0.004, w.max(0) + 0.004


# ---------------------------------------------------------------------------------------------------- the head
def skull():
    """a round head tipped back, heavy jowls and a double chin sagging into the neck"""
    return Union([
        Ellipsoid(HEAD_C, (0.13, 0.13, 0.12)),
        Mirror(Ellipsoid((0.09, -0.065, 1.405), (0.088, 0.076, 0.078))),     # heavy jowls (round 2: wider at the bottom)
        Ellipsoid((0.0, -0.09, 1.405), (0.09, 0.065, 0.055)),                # the pout's chin
        Ellipsoid((0.0, -0.06, 1.33), (0.152, 0.112, 0.08)),                 # the double chin, resting on the collar
        Ellipsoid((0.0, -0.075, 1.37), (0.075, 0.06, 0.04)),
    ], k=0.04, part=SKIN)


def face_shape():
    sk = skull()
    lid = Clip(Ellipsoid(EYE_C + v3((0, -0.0005, 0.002)), (0.034, 0.033, 0.034), part=SKIN), [Half(LID_PT, LID_N)], k=0.005)
    lower = Clip(Ellipsoid(EYE_C + v3((0, -0.001, -0.001)), (0.033, 0.032, 0.033), part=SKIN), [Half(v3((0, 0, LOW_Z)), (0.0, 0.0, 1.0))], k=0.005)
    bag = Ellipsoid(EYE_C + v3((0.004, -0.008, -0.03)), (0.032, 0.016, 0.012), part=SKIN)
    brow = Ellipsoid(EYE_C + v3((0.002, -0.004, 0.031)), (0.042, 0.024, 0.014), part=SKIN)        # a low, heavy brow
    face = Union([sk, Mirror(lid), Mirror(lower), Mirror(bag), Mirror(brow)], k=0.01)
    # the snout: a broad upturned nose with a flat pink end and two big nostrils
    snout = Union([
        RoundCone((0.0, -0.13, 1.51), (0.0, -0.168, 1.465), 0.024, 0.034),
        Ellipsoid((0.0, -0.176, 1.462), (0.046, 0.032, 0.034), R=rot(rx=20)),
        Mirror(Ellipsoid((0.034, -0.158, 1.453), (0.024, 0.022, 0.022))),
    ], k=0.014, part=SKIN)
    face = Union([face, snout], k=0.012)
    nostrils = Mirror(Ellipsoid((0.019, -0.202, 1.452), (0.0095, 0.009, 0.0075), R=rot(rx=40), part=SKIN))
    return Cut(face, [nostrils], k=0.002)


def ears():
    u = EAR_U
    vv = v3((0, 0, 1)) - u * u[2]
    vv /= np.linalg.norm(vv)
    n = np.cross(u, vv)
    if n[1] > 0:
        n = -n
    R = np.stack([u, vv, n], 1)
    poly = [(-0.03, 0.045), (0.04, 0.06), (0.1, 0.052), (0.145, 0.025), (0.165, -0.005), (0.14, -0.035), (0.08, -0.045), (0.02, -0.042), (-0.03, -0.035)]
    plate = Slab(EAR_ROOT, poly, 0.008, rr=0.006, R=R, part=SKIN)
    plate = Bounded(plate, *slab_box(EAR_ROOT, poly, 0.008, R))
    cup = Ellipsoid(EAR_ROOT + u * 0.075 + vv * 0.008 + n * 0.012, (0.07, 0.035, 0.009), R=R, part=EAR_IN)
    ear = Cut(plate, [cup], k=0.006)
    inner = Clip(Ellipsoid(EAR_ROOT + u * 0.075 + vv * 0.008 + n * 0.0012, (0.066, 0.032, 0.006), R=R, part=EAR_IN), [Half(EAR_ROOT, -n)])
    return Mirror(Union([ear, inner], k=0.0))


def hair():
    sk = Ellipsoid(HEAD_C, (0.13, 0.13, 0.12))
    cap = Clip(Inflate(sk, 0.01, part=HAIR), [Half((0, 0, 1.51), (0, 0.5, -1)), Half((0, -0.06, 1.55), (0, -1, 0.2))], k=0.012)
    return ScaleAt(Bump(cap, lambda P: noise3(P, 0.008), 0.0015), HS, PIV)


def mouth_z(x):
    return MOUTH_Z - 0.012 * (np.abs(x) / MOUTH_X) ** 2      # the corners turned down: the smug pout


def head():
    """round 2: the head built at its old size and scaled up HS about the crown, so the double chin comes down onto the collar; the neck stays put"""
    neck = Union([RoundCone(NECK0, NECK1, 0.1, 0.09, part=SKIN), Ellipsoid((0.0, -0.06, 1.3), (0.12, 0.1, 0.06), part=SKIN)], k=0.04)   # webbed up under the double chin
    return Union([ScaleAt(head_local(), HS, PIV), neck], k=0.08)


def head_local():
    face = Union([face_shape(), ears()], k=0.012)
    base = Union([face, RoundCone(NECK0, NECK1, 0.1, 0.09)], k=0.05)
    xs = np.linspace(-MOUTH_X, MOUTH_X, 11)
    pts = [on(base, x, mouth_z(x)) for x in xs]
    slit = loft([(p + v3((0, 0.003, 0)), 0.0032) for p in pts], k=0.002)
    face = Cut(face, [slit], k=0.002)
    lower = loft([(p + v3((0, 0.004, -0.009)), 0.0075 * (1 - 0.5 * (abs(p[0]) / MOUTH_X) ** 2)) for p in pts[2:-2]], part=LIP, k=0.004)
    face = Union([face, lower], k=0.006)
    # folds: round the snout to the mouth corners, under the lip, the chin's double fold
    face = Crease(face, [on(base, x, z, 0.002) for x, z in ((0.05, 1.47), (0.07, 1.44), (0.075, 1.41), (0.068, 1.39))], 0.007, -0.0025)
    face = Crease(face, [on(base, x, z, 0.002) for x, z in ((0.0, 1.355), (0.05, 1.36), (0.09, 1.38))], 0.008, -0.003)
    ball = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    return Union([face, ball], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body
def core():
    """stout: a broad chest, a big round belly carried forward, a wide seat"""
    return Union([
        Ellipsoid((0, 0.02, 1.07), (0.23, 0.16, 0.16)),                     # round 2: round from chest to belt
        Mirror(Ellipsoid((0.155, 0.03, 1.17), (0.095, 0.085, 0.06))),
        Ellipsoid((0, -0.05, 0.9), (0.28, 0.25, 0.22)),                     # the belly
        Ellipsoid((0, 0.03, 0.76), (0.23, 0.16, 0.12)),
    ], k=0.07, part=SHIRT)


def legs_core():
    return Mirror(loft([(HIP, 0.095), (KNEE, 0.08), (ANKLE + v3((0, 0, 0.18)), 0.075)], k=0.03))


def hand_hang():
    palm = Ellipsoid((0.0, 0.0, -0.04), (0.017, 0.037, 0.042), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.033, 0.029, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.025, -0.0085, 0.0085, 0.025):
        L = 1.0 - abs(f) * 5
        pts = [((0.0, f, -0.07), 0.0115), ((-0.006, f * 1.05, -0.07 - 0.022 * L), 0.011), ((-0.017, f * 1.08, -0.088 - 0.022 * L), 0.0102), ((-0.028, f * 1.1, -0.095 - 0.016 * L), 0.0094)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
    parts.append(loft([(v3((-0.008, -0.032, -0.022)), 0.013), (v3((-0.02, -0.048, -0.05)), 0.0115), (v3((-0.032, -0.044, -0.072)), 0.0102)], part=SKIN, k=0.004))
    return Union(parts, k=0.009)


def croc():
    heel = ANKLE + v3((0.0, 0.05, -0.04))
    foot = loft([(heel, 0.054), (ANKLE + v3((0.003, -0.075, -0.034)), 0.066), (ANKLE + v3((0.006, -0.165, -0.041)), 0.058)], k=0.025)
    shell = Clip(Inflate(foot, 0.0, part=CROC), [Half((0, 0, 0.012), (0, 0, -1)), Half(ANKLE + v3((0, -0.03, -0.005)), (0, 0.7, 1))], k=0.006)
    sole = Clip(Inflate(foot, 0.006, part=CROC), [Half((0, 0, 0.022), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)
    strap = Clip(Torus(ANKLE + v3((0, 0.02, -0.03)), 0.06, 0.008, Rm=rot(ry=90), part=CROC), [Half(ANKLE + v3((0, 0.02, -0.02)), (0, -1, 0))], k=0.0)
    holes = [Sphere(ANKLE + v3((x, y, 0.0)), 0.0065) for x in (-0.025, 0.0, 0.025) for y in (-0.08, -0.115)]
    holes = [Move(h, t=v3((0, 0, probe_top(foot, ANKLE[0] + hx, ANKLE[1] + hy) - ANKLE[2]))) for h, (hx, hy) in
             zip(holes, [(x, y) for x in (-0.025, 0.0, 0.025) for y in (-0.08, -0.115)])]
    shell = Cut(shell, holes, k=0.002)
    foot_in = Clip(Ellipsoid(ANKLE + v3((0.0, -0.02, -0.02)), (0.04, 0.07, 0.04), part=SKIN), [Half((0, 0, 0.02), (0, 0, -1))], k=0.0)
    return Union([shell, sole, strap, foot_in], k=0.0)


def probe_top(shape, x, y, z0=0.3, z1=-0.05, step=0.0015):
    zs = np.arange(z1, z0, step, dtype=np.float32)[::-1]
    P = np.stack([np.full_like(zs, x), np.full_like(zs, y), zs], 1)
    d = shape.eval(P)[0]
    i = int(np.argmax(d < 0))
    return float(zs[i])


def body():
    co = core()
    # the shirt: sleeves rolled to the elbow, a collar standing round the thick neck
    ua = (ELBOW - SHOULDER) / np.linalg.norm(ELBOW - SHOULDER)
    sleeve = loft([(SHOULDER, 0.07), (ELBOW, 0.06)], part=SHIRT, k=0.01)
    roll = Torus(ELBOW + ua * 0.005, 0.058, 0.018, Rm=basis(ua, v3((0, 1, 0))), part=SHIRT)
    arm = Union([RoundCone(ELBOW, WRIST, 0.055, 0.04, part=SKIN), place(hand_hang(), WRIST, HAND)], k=0.01)
    shirt = Union([co, sleeve, roll, Move(sleeve, R=FLIP), Move(roll, R=FLIP)], k=0.02, part=SHIRT)
    collar = Clip(Cut(RoundCone(NECK0 + v3((0, 0.0, 0.0)), NECK1, 0.118, 0.108, part=SHIRT), [RoundCone(NECK0 + v3((0, 0, -0.02)), NECK1 + v3((0, 0, 0.02)), 0.1, 0.09)]),
                  [Half((0, 0, 1.27), (0, 0.35, 1)), Half((0, 0, 1.18), (0, 0, -1))], k=0.004)
    flaps = Clip(Cut(Inflate(co, 0.036, part=SHIRT), [Inflate(co, 0.02)], k=0.004), [Mirror(prism([(0.01, 1.2), (0.07, 1.25), (0.11, 1.2), (0.06, 1.15)]))], k=0.009)
    # the apron: a bib over the chest and a skirt over belly and thighs to the knees; a neck strap; a pocket; ties round the waist with a bow at his left hip
    apron_core = Union([co, Box((0, -0.09, 0.6), (0.255, 0.15, 0.2), rr=0.09)], k=0.08)       # the skirt hangs straight off the belly, clear of the thighs
    apron = Clip(Inflate(apron_core, 0.012, part=APRON), [prism([(-0.15, 1.17), (0.15, 1.17), (0.2, 0.86), (0.25, 0.42), (-0.25, 0.42), (-0.2, 0.86)])], k=0.012)
    pocket = Clip(Inflate(apron_core, 0.018, part=APRON), [prism([(-0.1, 0.62), (0.1, 0.62), (0.1, 0.8), (-0.1, 0.8)])], k=0.003)
    neckstrap = Clip(Inflate(Union([co, RoundCone(NECK0, NECK1, 0.1, 0.09)], k=0.05), 0.014, part=STRAP),
                     [Mirror(Box((0.135, -0.02, 1.25), (0.02, 0.2, 0.08), R=rot(ry=-25)))], k=0.003)
    ties = Clip(Inflate(co, 0.016, part=STRAP), [Half((0, 0, 0.84), (0, 0, -1)), Half((0, 0, 0.87), (0, 0, 1)), Half((0, -0.05, 0), (0, 1, 0))], k=0.002)
    bow = Union([Ellipsoid((0.235, -0.07, 0.86), (0.014, 0.018, 0.016), part=STRAP),
                 Ellipsoid((0.24, -0.08, 0.885), (0.01, 0.04, 0.022), R=rot(rx=40), part=STRAP),
                 Ellipsoid((0.24, -0.08, 0.835), (0.01, 0.04, 0.022), R=rot(rx=-40), part=STRAP),
                 Box((0.245, -0.085, 0.76), (0.006, 0.016, 0.08), rr=0.004, R=rot(rx=8), part=STRAP),
                 Box((0.25, -0.06, 0.75), (0.006, 0.016, 0.085), rr=0.004, R=rot(rx=-6), part=STRAP)], k=0.004)
    towel_core = Bump(apron_core, lambda P: 0.5 + 0.5 * np.sin(P[:, 0] * 150.0 + np.sin(P[:, 2] * 30.0)), 0.009)
    towel = Clip(Inflate(towel_core, 0.02, part=TOWEL), [prism([(-0.275, 0.865), (-0.115, 0.865), (-0.11, 0.54), (-0.15, 0.525), (-0.2, 0.545), (-0.275, 0.52)])], k=0.004)
    trousers = Union([Clip(Inflate(co, 0.006), [Half((0, 0, 0.84), (0, 0, 1))]), legs_core()], k=0.05, part=TROUSERS)
    trousers = Clip(trousers, [Half((0, 0, 0.25), (0, 0, -1))], k=0.004)
    rolls = Mirror(Clip(Inflate(legs_core(), 0.01, part=TROUSERS), [Half((0, 0, 0.23), (0, 0, -1)), Half((0, 0, 0.3), (0, 0, 1))], k=0.006))
    shins = Mirror(RoundCone(ANKLE + v3((0, 0, -0.02)), ANKLE + v3((0, 0, 0.2)), 0.045, 0.055, part=SKIN))
    crocs = Mirror(croc())
    return Union([shirt, collar, flaps, apron, pocket, neckstrap, ties, bow, towel, trousers, rolls, shins, crocs, arm, Move(arm, R=FLIP)], k=0.0)


def kit_bits(bd):
    """the wooden spoon and the whisk in the apron pocket, the pencil behind his right ear, shirt buttons"""
    parts = []
    py = probe(bd, -0.04, 0.72)
    spoon = Union([RoundCone((-0.04, py + 0.004, 0.66), (-0.045, py + 0.0, 0.84), 0.007, 0.006, part=WOOD),
                   Ellipsoid((-0.046, py - 0.002, 0.87), (0.024, 0.009, 0.036), part=WOOD)], k=0.006)
    spoon = Cut(spoon, [Ellipsoid((-0.046, py - 0.011, 0.872), (0.018, 0.006, 0.028))], k=0.002)
    wy = probe(bd, 0.045, 0.72)
    whisk = [RoundCone((0.045, wy + 0.004, 0.66), (0.047, wy + 0.002, 0.79), 0.0065, 0.0065, part=STEEL)]
    for k in range(6):
        a = k / 6.0 * np.pi
        whisk.append(Clip(Torus((0.048, wy + 0.0, 0.84), 0.05, 0.0018, Rm=rot(rz=np.degrees(a), rx=90) @ np.diag([1.0, 0.55, 1.0]).astype(np.float32), part=STEEL),
                          [Half((0, 0, 0.79), (0, 0, -1))]))
    parts += [spoon] + whisk
    a, b = W(v3((-0.15, 0.018, 1.522))), W(v3((-0.04, -0.075, 1.598)))           # tucked behind his right ear, lying up over the side of his head
    d = (b - a) / np.linalg.norm(b - a)
    pencil = loft([(a, 0.0055), (b, 0.0055)], part=PENCIL)
    tip = RoundCone(b, b + d * 0.018, 0.0052, 0.0012, part=LEAD)
    parts += [pencil, tip]
    for z in (1.15, 1.09):
        parts.append(Sphere(on(bd, 0.0, z, 0.002), 0.005, part=BUTTON))
    return Union(parts, k=0.0)


def pieces():
    import os
    only = os.environ.get("FOLK_ONLY", "")
    s = 1.5 if os.environ.get("FOLK_FAST") else 1.0
    if only == "head":
        return [("head", head(), 0.0018 * s), ("hair", hair(), 0.002 * s)]
    bd = body()
    return [("head", head(), 0.0018 * s), ("hair", hair(), 0.002 * s), ("body", bd, 0.0035 * s), ("kit", kit_bits(bd), 0.0016 * s)]


# ---------------------------------------------------------------------------------------------------- paint
def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.01) * 0.25

    def sel(v, m):
        return v[m] if np.ndim(v) >= 1 and len(v) == n else v

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = sel(rough, m)
        c.metal[m] = sel(metal, m)
        c.bump[m] = sel(bump, m)
        c.grain[m] = sel(grain, m)

    def spk(m, col, amt):
        a = np.broadcast_to(np.asarray(amt, np.float32), (n,))[m]
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), a[:, None]], 1)

    # skin: tan, the snout and cheeks flushed pink, stubble over the jowls and chin, hairy forearms; heavy lids darker
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(222, 180, 124), (n, 3)).copy() * (1.0 + 0.06 * mott)[:, None]
    Hh = L(P)
    HQ = Hh.copy()
    HQ[:, 0] = np.abs(HQ[:, 0])
    hx, hy, hz = Hh[:, 0], Hh[:, 1], Hh[:, 2]
    snout = np.exp(-((HQ[:, 0] / 0.05) ** 2 + ((hz - 1.465) / 0.03) ** 2)) * (hy < -0.12)
    cheek = np.exp(-(((HQ[:, 0] - 0.095) / 0.03) ** 2 + ((hz - 1.455) / 0.025) ** 2)) * (hy < -0.05)
    sk = sk + (srgb(226, 146, 124) - sk) * (0.65 * np.clip(snout + 0.6 * cheek, 0, 1))[:, None]
    de = HQ - EYE_C
    r = np.linalg.norm(de, axis=1)
    pd = (HQ - LID_PT) @ LID_N
    lid = (r < EYE_R + 0.01) & (pd < 0.0)
    sk = sk + (srgb(186, 136, 96) - sk) * (lid * smooth(-0.025, -0.003, pd) * 0.6)[:, None]
    sk *= (1.0 - 0.35 * c.cavity)[:, None]
    put(m, sk, 0.55, bump=0.15)
    stub = m & (hz > 1.27) & (hz < 1.43) & (hy < -0.02) & (z > 1.15) & ~((hz > 1.4) & (HQ[:, 0] < 0.05))
    hairy = m & (z < 1.0) & (z > 0.72)
    spk(m, (110, 84, 60), 0.0)
    c.spk[stub, 3] = 0.75
    c.spk[hairy, 3] = 0.6
    c.draw(m & (r < EYE_R + 0.008) & (pd > -0.006) & (pd < 0.003) & (de[:, 1] < 0.01), np.abs(pd + 0.001), 0.0015)
    c.draw(m & (r < EYE_R + 0.006) & (np.abs(HQ[:, 2] - LOW_Z) < 0.004) & (de[:, 1] < 0.0), np.abs(HQ[:, 2] - LOW_Z - 0.0006), 0.0008, 0.5)
    mz = MOUTH_Z - 0.012 * (np.abs(hx) / MOUTH_X) ** 2
    c.draw(m & (np.abs(hx) < MOUTH_X + 0.004) & (np.abs(hz - mz) < 0.008) & (hy < -0.1) & (z > 1.15), np.abs(hz - mz) * HS, 0.0008, 0.6)
    put(c.mask(EAR_IN), srgb(232, 150, 140) * (1.0 - 0.2 * c.cavity)[:, None], 0.5)
    put(c.mask(LIP), srgb(206, 140, 116), 0.4)
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    look = EYE_FWD + v3((0.0, 0.0, -0.1))
    look /= np.linalg.norm(look)
    a = np.arccos(np.clip(d @ look, -1, 1))
    ir = srgb(96, 60, 32) + (srgb(44, 26, 14) - srgb(96, 60, 32)) * smooth(0.1, 0.34, a)[:, None]
    ir = ir + (srgb(236, 226, 210) - ir) * smooth(0.4, 0.45, a)[:, None]
    c.draw(m, (a / 0.16 - 1.0) * 0.16 * EYE_R, 0.0)
    put(m, ir, 0.1)
    m = c.mask(HAIR)
    put(m, srgb(36, 30, 28) * (1.0 + 0.5 * c.wear)[:, None], 0.7, bump=0.8)
    # the shirt: cream and slate-blue stripes; the apron cream canvas, splashed with brown and tomato stains
    m = c.mask(SHIRT)
    st = 0.5 + 0.5 * np.sin(x * 2 * np.pi / 0.026 + 0.6 * np.sin(z * 6.0))
    sh = srgb(232, 222, 200) + (srgb(98, 112, 160) - srgb(232, 222, 200)) * smooth(0.45, 0.6, st)[:, None]
    sh *= (1.0 + 0.04 * mott)[:, None]
    put(m, sh, 0.85, bump=0.9)
    m = c.mask(APRON, STRAP)
    ap = srgb(242, 232, 210) * (1.0 + 0.05 * mott)[:, None]
    stain = np.clip(noise3(P, 0.025) * 0.9 + noise3(P, 0.008) * 0.5 - 0.55, 0, 1)
    ap = ap + (srgb(176, 128, 76) - ap) * (stain * 0.8)[:, None]
    red = np.clip(noise3(P + 7.0, 0.02) * 1.2 - 0.75, 0, 1) * (z > 0.9)
    ap = ap + (srgb(186, 70, 60) - ap) * (red * 0.8)[:, None]
    ap *= (1.0 - 0.2 * c.cavity)[:, None]
    put(m, ap, 0.9, bump=0.9)
    spk(m, (184, 128, 70), 0.5)
    # the towel: red and white gingham
    m = c.mask(TOWEL)
    gx = (np.floor((x + 1.0) / 0.018) % 2) == 0
    gz = (np.floor((z + 1.0) / 0.018) % 2) == 0
    tw = np.where((gx & gz)[:, None], srgb(196, 50, 52), np.where((gx | gz)[:, None], srgb(226, 148, 146), srgb(240, 234, 226)))
    put(m, tw * (1.0 - 0.3 * c.cavity)[:, None], 0.9, bump=0.9)
    m = c.mask(TROUSERS)
    put(m, srgb(66, 62, 66) * (1.0 + 0.06 * mott)[:, None] * (1.0 + 0.4 * c.wear)[:, None], 0.85, bump=0.9)
    m = c.mask(CROC)
    put(m, srgb(236, 230, 220) * (1.0 - 0.3 * c.cavity)[:, None] * (1.0 - 0.06 * np.clip(noise3(P, 0.012), 0, 1))[:, None], 0.5, bump=0.3)
    m = c.mask(WOOD)
    put(m, srgb(184, 126, 70) * (1.0 + 0.15 * np.sin((z + 0.3 * x) * 300.0))[:, None], 0.6, bump=0.4)
    put(c.mask(STEEL), srgb(206, 208, 214), 0.25, metal=1.0)
    m = c.mask(PENCIL)
    pc = np.broadcast_to(srgb(238, 186, 48), (n, 3)).copy()
    pc[x < -0.135] = srgb(222, 120, 130)
    put(m, pc, 0.45)
    put(c.mask(LEAD), srgb(214, 184, 140), 0.6)
    put(c.mask(BUTTON), srgb(236, 232, 224), 0.35)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    c.col *= (1.0 - 0.2 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion
GAME = {
    "budget": {"head": 2800, "hair": 500, "body": 5000, "kit": 900},
    "density": {"head": 1.9, "hair": 0.8, "kit": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.78, "run": 1.1},
    "speed": 0.7,
    "look": ["head", "ear.L", "ear.R"], "neck": "neck",
    "look_pivot": (0.0, -0.02, 1.36),
    "radius": 0.4,
}
BALL = v3((0.125, -0.075, 0.0))


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.02, 0.76), (0, 0.0, 0.9), "root", 0.2),
        Bone("spine", (0, 0.0, 0.9), (0, 0.02, 1.04), "hips", 0.22),
        Bone("chest", (0, 0.02, 1.04), (0, 0.03, 1.2), "spine", 0.18),
        Bone("neck", NECK0, NECK1, "chest", 0.09),
        Bone("head", NECK1, (0, -0.02, 1.6), "neck", 0.15),
        Bone("ear.L", W(EAR_ROOT), W(EAR_ROOT + EAR_U * 0.16), "head", 0.025),
        Bone("shoulder.L", (0.05, 0.03, 1.19), SHOULDER, "chest", 0.06),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.06),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.045),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.09, "forearm.L", 0.03),
        Bone("thigh.L", HIP, KNEE, "hips", 0.095),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.08),
        Bone("foot.L", ANKLE, ANKLE + v3((0.004, -0.15, -0.05)), "shin.L", 0.05),
    ])
    return bones


def skin_rules(P, part, piece, names):
    """piece: 0 head, 1 hair, 2 body, 3 kit"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    hl = L(P)
    rig[hp & ((hl[:, 2] > 1.39) | ((hl[:, 2] > 1.3) & (hl[:, 1] < -0.09)))] = ix["head"]
    for s, sd in ((1, "L"), (-1, "R")):
        em = hp & (s * hl[:, 0] > 0.13) & (hl[:, 2] > 1.38)
        rig[em] = -1
        allow(em, "ear." + sd)
        rig[hp & (s * hl[:, 0] > 0.16) & (hl[:, 2] > 1.38)] = ix["ear." + sd]
    rig[piece == 1] = ix["head"]
    allow(piece == 1, "head")
    kp = piece == 3
    allow(kp, "hips")
    rig[kp] = ix["hips"]
    rig[kp & (z > 1.0)] = ix["chest"]
    rig[kp & (z > 1.5)] = ix["head"]
    bp = piece == 2
    legs = bp & ((np.isin(part, (TROUSERS, CROC)) & (z < 0.78)) | (z < 0.35))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs & (np.isin(part, (APRON, STRAP, TOWEL)) | ((part == SHIRT) & (np.abs(x) < 0.25)) | ((part == TROUSERS) & (z > 0.7)))
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.1) & (z > 1.05), "shoulder.L")
    allow(torso & (x < -0.1) & (z > 1.05), "shoulder.R")
    arms = bp & ~legs & ~torso
    allow(arms & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (z > 1.05), "chest")
    return A, rig


WALK = dict(stride=0.78, stance=0.62, foot_x=0.13, lift=0.032, bob=0.012, drop=0.045, sway=0.04, roll=6.0, yaw=6.0, counter=1.0,
            lean=-3.0, toe_off=10.0, toe_out=12.0, swing_point=3.0)
RUN = dict(stride=1.1, stance=0.45, foot_x=0.13, lift=0.08, bob=0.03, drop=0.07, sway=0.04, roll=6.0, yaw=8.0, counter=1.1,
           lean=6.0, toe_off=18.0, toe_out=10.0, swing_point=10.0)
BACK = 0.07


def motions(rig):
    """his clips: walk (a relaxed shuffle in crocs: low sliding steps, a side-to-side roll, belly first, head tipped back, arms swinging round the belly,
    ears flopping), run (a reluctant jiggling jog), idle (a smug look down his snout, a sigh, two pats of the belly)"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.offset.y += BACK
        c = math.cos(TAU * u)
        s2 = math.sin(2 * TAU * u - 0.7)
        A = 24.0 if run else 13.0
        p.rot("upper_arm.L", A * c, 0, 0)
        p.rot("upper_arm.R", -A * c, 0, 0)
        p.rot("forearm.L", -(50.0 if run else 10.0) - 6.0 * max(0.0, -c), 0, 0)
        p.rot("forearm.R", -(50.0 if run else 10.0) - 6.0 * max(0.0, c), 0, 0)
        p.rot("chest", -2.0 if not run else 2.0, 0, 0)
        p.world["head"] = R(-6.0 + 1.5 * s2, 0, 2.5 * math.sin(TAU * u))
        fl = (10.0 if run else 6.0) * math.sin(2 * TAU * u - 1.5)
        p.rot("ear.L", 0, -fl, 0)
        p.rot("ear.R", 0, fl, 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    wr = Vector((WRIST * f).tolist())
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        br = math.sin(TAU * t / 3.0)
        sigh = ease((t - 0.8) / 0.8) * (1.0 - ease((t - 2.0) / 0.8))
        stand(rig, p, legs, {"L": (Vector((0.13, -0.075, 0.0)), 12.0), "R": (Vector((-0.13, -0.07, 0.0)), -14.0)},
              hip_shift=(0.01 * w, 0.0, -0.01), roll=-1.5 * w)
        p.rot("spine", -1.0 * br - 2.0 * sigh, 0, 0)
        p.rot("chest", -1.0 * br - 3.0 * sigh, 0, 0)
        # two pats of the belly with his right hand (2.3-3.7 s), the head tipped back, eyes down the snout
        pat = ease((t - 2.2) / 0.35) * (1.0 - ease((t - 3.6) / 0.35))
        tap = 0.025 * max(0.0, math.sin(TAU * (t - 2.55) / 0.5)) * pat
        tgt = wr.lerp(Vector((-0.11, -0.33 - tap, 0.92)), pat)
        p.ik["upper_arm.R"] = (tgt, Vector((-0.3, 1.0, 0.0)).lerp(Vector((-1.0, 0.5, -0.3)), pat), "hand.R", R(-70.0 * pat, 0, 40.0 * pat))
        p.world["head"] = R(-8.0 - 4.0 * sigh + 1.0 * br, 0, 6.0 * w)
        p.rot("upper_arm.L", 1.5 * br, 0, 0)
        p.rot("ear.L", 0, -2.0 * br, 0)
        p.rot("ear.R", 0, 2.0 * br, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
