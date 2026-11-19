## FOINT CITY townsfolk: the accountant. A thin blue fellow with bat-wing ears, big yellow eyes behind square glasses, a long pointed nose, a wide toothy grin and slicked black hair; short-sleeved shirt, an open brown knit vest, striped tie, grey trousers, brown loafers. Free hands (the concept's papers and calculator are dropped).
# Concept: the user's sheet, image 4 bottom left (F:/prog-godot-cache/folk/refs/4.webp). Measured off it: 1.55 m to the top of the quiff; the head 0.33 m tall
# (a big head on a thin neck, pushed forward by his hunch), 0.30 wide, the bat ears 0.56 across; narrow shoulders (0.36); crotch at 0.61; trouser hems on the shoes.
# Rest pose = his hunch: back rounded, the head forward, elbows a little bent and held in.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

F32 = np.float32
HEIGHT = 1.55
REF = ("4.webp", (119, 382, 347, 782))

(SKIN, EYE, TOOTH, MOUTH, HAIR, BROW, WING, RIB, GLASS, LENS, SHIRT, VEST, TIE, BELT, BRASS, TROUSERS, SHOE, SOLE, WATCH, PEN_R,
 PEN_B, BUTTON) = range(1, 23)
COLOURS = {
    SKIN: ((0.42, 0.44, 0.78), 0.55, 0.0),
    EYE: ((0.95, 0.75, 0.25), 0.15, 0.0),
    TOOTH: ((0.88, 0.80, 0.50), 0.35, 0.0),
    MOUTH: ((0.30, 0.06, 0.10), 0.6, 0.0),
    HAIR: ((0.08, 0.07, 0.07), 0.35, 0.0),
    BROW: ((0.06, 0.05, 0.06), 0.6, 0.0),
    WING: ((0.72, 0.58, 0.70), 0.5, 0.0),
    RIB: ((0.50, 0.46, 0.72), 0.5, 0.0),
    GLASS: ((0.12, 0.08, 0.06), 0.3, 0.0),
    LENS: ((0.75, 0.80, 0.82), 0.05, 0.0),
    SHIRT: ((0.86, 0.80, 0.68), 0.8, 0.0),
    VEST: ((0.42, 0.26, 0.14), 0.9, 0.0),
    TIE: ((0.25, 0.32, 0.52), 0.5, 0.0),
    BELT: ((0.30, 0.18, 0.09), 0.5, 0.0),
    BRASS: ((0.85, 0.65, 0.30), 0.3, 1.0),
    TROUSERS: ((0.24, 0.25, 0.34), 0.8, 0.0),
    SHOE: ((0.40, 0.22, 0.12), 0.35, 0.0),
    SOLE: ((0.15, 0.10, 0.07), 0.6, 0.0),
    WATCH: ((0.30, 0.18, 0.08), 0.4, 0.0),
    PEN_R: ((0.80, 0.15, 0.12), 0.4, 0.0),
    PEN_B: ((0.15, 0.20, 0.50), 0.4, 0.0),
    BUTTON: ((0.30, 0.18, 0.10), 0.4, 0.0),
}

# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; the figure faces -Y)
HEAD_C = v3((0.0, -0.05, 1.375))
EYE_C = v3((0.052, -0.148, 1.333))
EYE_R = 0.034
EYE_FWD = v3((0.12, -1.0, 0.05)) / np.linalg.norm((0.12, -1.0, 0.05))
LID_PT = EYE_C + v3((0.0, 0.0, 0.022))
LID_N = v3((0.25, 0.0, -1.0)) / np.linalg.norm((0.25, 0.0, -1.0))
WING_ROOT = v3((0.118, -0.03, 1.335))
WING_U = v3((1.0, 0.28, 0.12)) / np.linalg.norm((1.0, 0.28, 0.12))
MOUTH_X = 0.072
MOUTH_Z = 1.238
NECK0 = v3((0.0, 0.03, 1.08))
NECK1 = v3((0.0, -0.03, 1.23))

SHOULDER = v3((0.148, 0.04, 1.085))
ELBOW = v3((0.19, 0.06, 0.86))
WRIST = v3((0.205, -0.045, 0.70))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
HIP = v3((0.075, 0.015, 0.66))
KNEE = v3((0.083, -0.02, 0.38))
ANKLE = v3((0.088, 0.02, 0.075))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def probe(shape, x, z, y0=-0.5, y1=0.4, step=0.0015):
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


class Bounded(Shape):
    """the child with a tighter box than its own: unions skip it outside the box"""
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
    """a long head: the cranium, cheeks, a long lower face and chin under the grin"""
    return Union([
        Ellipsoid(HEAD_C, (0.118, 0.13, 0.125)),
        Ellipsoid((0.0, -0.1, 1.33), (0.105, 0.07, 0.07)),
        Mirror(Ellipsoid((0.07, -0.12, 1.265), (0.05, 0.05, 0.045))),
        Ellipsoid((0.0, -0.105, 1.235), (0.088, 0.065, 0.06)),
        Ellipsoid((0.0, -0.12, 1.18), (0.045, 0.045, 0.035)),
    ], k=0.035, part=SKIN)


def face_shape():
    sk = skull()
    # big round eyes, bulging; the upper lid only just over their tops (wide-eyed)
    lid = Clip(Ellipsoid(EYE_C + v3((0, -0.0005, 0.001)), (0.0375, 0.037, 0.0375), part=SKIN), [Half(LID_PT, LID_N)], k=0.004)
    lower = Clip(Ellipsoid(EYE_C + v3((0, -0.001, -0.001)), (0.037, 0.0365, 0.037), part=SKIN), [Half(EYE_C + v3((0, 0, -0.026)), (0.0, 0.0, 1.0))], k=0.004)
    face = Union([sk, Mirror(lid), Mirror(lower)], k=0.01)
    # the long pointed nose, drooping over the grin
    nose = Union([
        RoundCone((0.0, -0.16, 1.345), (0.0, -0.212, 1.262), 0.016, 0.012),
        Ellipsoid((0.0, -0.214, 1.257), (0.013, 0.014, 0.013)),
        Mirror(Ellipsoid((0.012, -0.186, 1.272), (0.01, 0.012, 0.009))),
    ], k=0.012, part=SKIN)
    return Union([face, nose], k=0.01)


def wings():
    """bat-wing ears: a membrane between four finger ribs, scalloped between their tips"""
    u = WING_U
    vv = v3((0, 0, 1)) - u * u[2]
    vv /= np.linalg.norm(vv)
    n = np.cross(u, vv)
    if n[1] > 0:
        n = -n
    R = np.stack([u, vv, n], 1)
    tips = [(0.16, 0.055), (0.175, 0.0), (0.15, -0.045), (0.10, -0.075)]
    poly = [(-0.02, 0.03), (0.06, 0.05), tips[0], (0.135, 0.02), tips[1], (0.13, -0.02), tips[2], (0.095, -0.045), tips[3], (0.05, -0.05), (0.0, -0.03), (-0.02, -0.02)]
    plate = Slab(WING_ROOT, poly, 0.003, rr=0.002, R=R, part=WING)
    plate = Bounded(plate, *slab_box(WING_ROOT, poly, 0.006, R))
    ribs = [RoundCone(WING_ROOT, WING_ROOT + u * tx + vv * ty, 0.0065, 0.0028, part=RIB) for tx, ty in tips]
    return Mirror(Union([plate] + ribs, k=0.004))


def hair():
    """slicked black hair: a cap over the top and back, a tall quiff swept up and back at the front, comb grooves"""
    sk = Ellipsoid(HEAD_C, (0.118, 0.13, 0.125))
    cap = Clip(Inflate(sk, 0.02, part=HAIR), [Half((0, 0, 1.375), (0, 0.45, -1)), Half((0, -0.1, 1.3), (0, -1, 0.0))], k=0.02)
    quiff = Ellipsoid((0.0, -0.075, 1.475), (0.105, 0.085, 0.055), R=rot(rx=-15), part=HAIR)
    swoop = Ellipsoid((0.0, -0.035, 1.505), (0.09, 0.085, 0.04), R=rot(rx=-20, ry=6), part=HAIR)
    sides = Mirror(Ellipsoid((0.105, 0.01, 1.39), (0.03, 0.09, 0.06), part=HAIR))
    h = Union([cap, quiff, swoop, sides], k=0.03, part=HAIR)

    def comb(P):
        return 0.5 - 0.5 * np.cos((P[:, 0] + 0.04 * np.sin(P[:, 1] * 20.0)) * 260.0)
    return Bump(h, comb, 0.0018)


def mouth_z(x):
    return MOUTH_Z + 0.022 * (np.abs(x) / MOUTH_X) ** 2


def head():
    face = Union([face_shape(), wings()], k=0.008)
    neck = RoundCone(NECK0, NECK1, 0.036, 0.032, part=SKIN)
    face = Union([face, neck], k=0.03)
    base = face
    # the grin: an open crescent showing big buck teeth, the lower lip under it
    xs = np.linspace(-MOUTH_X, MOUTH_X, 13)
    pts = [on(base, x, mouth_z(x)) for x in xs]
    open_ = loft([(p + v3((0, 0.006, -0.004 * (1 - (abs(p[0]) / MOUTH_X) ** 2))), 0.0125 * (1 - 0.75 * (abs(p[0]) / MOUTH_X) ** 2)) for p in pts], k=0.004)
    face = Cut(face, [open_], k=0.003)
    back = loft([(p + v3((0, 0.02, -0.004)), 0.013 * (1 - 0.6 * (abs(p[0]) / MOUTH_X) ** 2)) for p in pts], part=MOUTH, k=0.004)
    teeth = []
    for x, w, h in ((-0.039, 0.0062, 0.0085), (-0.024, 0.0075, 0.0105), (-0.008, 0.0078, 0.0122), (0.009, 0.0078, 0.0118), (0.025, 0.0072, 0.0102), (0.041, 0.006, 0.008)):
        p = on(base, x, mouth_z(x))
        teeth.append(Box(p + v3((0, 0.004, 0.0015 - h * 0.35)), (w, 0.0035, h * 0.5), rr=0.002, part=TOOTH))
    face = Crease(face, [on(base, x, z, 0.002) for x, z in ((0.03, 1.272), (0.068, 1.262), (0.088, 1.24), (0.085, 1.215))], 0.006, -0.002)
    brows = Mirror(loft([(on(base, x, z, -0.006), r) for x, z, r in ((0.016, 1.398, 0.0075), (0.05, 1.392, 0.0085), (0.084, 1.378, 0.0062))], part=BROW, k=0.004))
    ball = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    return Union([face, back, ball, brows] + teeth, k=0.0)


def glasses():
    """square dark frames, thick, standing just off the face; temples back to the ears"""
    parts = []
    c = EYE_C + v3((0.004, -0.04, 0.002))
    outer = Box(c, (0.045, 0.004, 0.032), rr=0.007, part=GLASS)
    inner = Box(c, (0.037, 0.02, 0.024), rr=0.005)
    frame = Cut(outer, [inner], k=0.0)
    bridge = RoundCone(c + v3((-0.042, 0, 0.008)), v3((0.0, c[1] - 0.004, c[2] + 0.012)), 0.0035, 0.0035, part=GLASS)
    temple = RoundCone(c + v3((0.044, 0.0, 0.012)), v3((0.118, 0.0, 1.35)), 0.004, 0.0035, part=GLASS)
    return Mirror(Union([frame, bridge, temple], k=0.0))      # no lens: a baked lens would paint over the eyes


# ---------------------------------------------------------------------------------------------------- the body
def core():
    """thin and hunched: a narrow chest, a round upper back, a little belly, small seat"""
    return Union([
        Ellipsoid((0, 0.025, 0.99), (0.122, 0.088, 0.11)),
        Ellipsoid((0, 0.07, 1.04), (0.105, 0.06, 0.07)),
        Mirror(Ellipsoid((0.09, 0.035, 1.07), (0.07, 0.06, 0.04))),
        Ellipsoid((0, 0.005, 0.85), (0.112, 0.088, 0.09)),
        Ellipsoid((0, 0.012, 0.72), (0.125, 0.092, 0.08)),
    ], k=0.05, part=SHIRT)


def legs_core():
    return Mirror(loft([(HIP, 0.072), (KNEE, 0.062), (ANKLE + v3((0, 0.0, 0.04)), 0.062)], k=0.03))


def hand_hang():
    palm = Ellipsoid((0.0, 0.0, -0.038), (0.013, 0.03, 0.038), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.022, 0.02, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.02, -0.0067, 0.0067, 0.02):
        L = 1.0 - abs(f) * 6
        pts = [((0.0, f, -0.065), 0.0078), ((-0.004, f * 1.05, -0.065 - 0.024 * L), 0.0073), ((-0.013, f * 1.08, -0.083 - 0.024 * L), 0.0066), ((-0.024, f * 1.1, -0.09 - 0.02 * L), 0.006)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.003))
    parts.append(loft([(v3((-0.006, -0.025, -0.02)), 0.009), (v3((-0.017, -0.038, -0.047)), 0.008), (v3((-0.027, -0.035, -0.068)), 0.007)], part=SKIN, k=0.003))
    return Union(parts, k=0.007)


def body():
    co = core()
    ua = (ELBOW - SHOULDER) / np.linalg.norm(ELBOW - SHOULDER)
    sleeve = Clip(loft([(SHOULDER, 0.048), (SHOULDER + ua * 0.13, 0.045)], part=SHIRT, k=0.01), [Half(SHOULDER + ua * 0.12, ua)], k=0.004)
    cuff = Torus(SHOULDER + ua * 0.11, 0.043, 0.006, Rm=basis(ua, v3((0, 1, 0))), part=SHIRT)
    armskin = Union([loft([(SHOULDER, 0.032), (ELBOW, 0.027), (WRIST, 0.022)], part=SKIN, k=0.01), place(hand_hang(), WRIST, HAND)], k=0.008)
    shirt = Union([co, sleeve, cuff, Move(sleeve, R=FLIP), Move(cuff, R=FLIP)], k=0.015, part=SHIRT)
    collar = Clip(Cut(Inflate(co, 0.016, part=SHIRT), [Inflate(co, 0.009)], k=0.002), [Mirror(prism([(0.004, 1.115), (0.05, 1.15), (0.068, 1.125), (0.04, 1.07)]))], k=0.003)
    neckband = Clip(Cut(RoundCone(NECK0 + v3((0, 0, 0.02)), NECK1, 0.05, 0.046, part=SHIRT), [RoundCone(NECK0, NECK1, 0.036, 0.032)]),
                    [Half((0, 0, 1.15), (0, 0.4, 1)), Half((0, 0, 1.07), (0, 0, -1))], k=0.003)
    # the open knit vest: the body grown, a deep V open down to the hem, armholes, a ribbed hem
    vest = Inflate(co, 0.014, part=VEST)
    vest = Clip(vest, [Half((0, 0, 0.655), (0, 0, -1))], k=0.004)
    vest = Cut(vest, [prism([(-0.078, 1.2), (0.078, 1.2), (0.05, 0.98), (0.07, 0.62), (-0.07, 0.62), (-0.05, 0.98)]),
                      Mirror(Ellipsoid((0.16, 0.04, 1.04), (0.045, 0.085, 0.085))),
                      Ellipsoid((0, 0.03, 1.13), (0.058, 0.06, 0.06))], k=0.004)

    def knit(P):
        return 0.5 - 0.5 * np.cos(P[:, 0] * 380.0 + np.abs(np.sin(P[:, 2] * 140.0)) * 2.0)
    vest = Bump(vest, knit, 0.0016)
    tie = Clip(Inflate(co, 0.006, part=TIE), [prism([(-0.012, 1.13), (0.012, 1.13), (0.026, 0.80), (0.0, 0.775), (-0.026, 0.80)])], k=0.002)
    knot = Ellipsoid(on(co, 0.0, 1.115, -0.008), (0.016, 0.01, 0.015), part=TIE)
    pants = Union([Clip(Inflate(co, 0.006), [Half((0, 0, 0.79), (0, 0, 1))]), legs_core()], k=0.04, part=TROUSERS)
    pants = Clip(pants, [Half((0, 0, 0.06), (0, 0, -1))], k=0.004)

    def crease(P):
        Q = np.abs(P[:, 0]) - 0.085
        return np.clip(1.0 - np.abs(Q) / 0.006, 0, 1) * (P[:, 1] < -0.03) * (P[:, 2] < 0.6)
    pants = Bump(pants, crease, 0.002)
    belt = Clip(Inflate(co, 0.012, part=BELT), [Half((0, 0, 0.765), (0, 0, -1)), Half((0, 0, 0.795), (0, 0, 1))], k=0.002)
    shoes = Mirror(loafer())
    return Union([shirt, collar, neckband, vest, tie, knot, pants, belt, shoes, armskin, Move(armskin, R=FLIP)], k=0.0)


def loafer():
    foot = loft([(ANKLE + v3((0.0, 0.04, -0.035)), 0.04), (ANKLE + v3((0.002, -0.07, -0.04)), 0.042), (ANKLE + v3((0.004, -0.155, -0.05)), 0.03)], k=0.02)
    up = Clip(Inflate(foot, 0.0, part=SHOE), [Half((0, 0, 0.018), (0, 0, -1)), Half(ANKLE + v3((0, 0, 0.0)), (0, 0.5, 1))], k=0.004)
    sole = Clip(Inflate(foot, 0.006, part=SOLE), [Half((0, 0, 0.022), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    heel = Box(ANKLE + v3((0, 0.045, -0.067)), (0.032, 0.03, 0.012), rr=0.004, part=SOLE)
    strap = Clip(Inflate(foot, 0.004, part=SHOE), [Box(ANKLE + v3((0, -0.075, -0.02)), (0.05, 0.012, 0.05))], k=0.002)
    return Union([up, sole, heel, strap], k=0.0)


def kit_bits(bd):
    """glasses, the belt buckle, vest buttons, pens in the shirt pocket, the watch on his right wrist"""
    parts = [glasses()]
    by = probe(bd, 0.0, 0.78)
    parts.append(Cut(Box((0, by - 0.003, 0.78), (0.02, 0.004, 0.016), rr=0.003, part=BRASS), [Box((0.003, by - 0.006, 0.78), (0.01, 0.01, 0.008), rr=0.002)], k=0.0))
    for z in (0.93, 0.85, 0.77, 0.69):
        x = 0.064 if z > 0.9 else 0.078
        parts.append(Sphere(on(bd, x, z, 0.002), 0.006, part=BUTTON))
    for x, part, top in ((0.062, PEN_R, 1.02), (0.075, PEN_B, 1.012), (0.088, PEN_R, 1.018)):
        y = probe(bd, x, 0.98) + 0.009
        parts.append(RoundCone((x, y, 0.95), (x, y - 0.002, top), 0.0045, 0.0042, part=part))
    wd = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    w = (WRIST - wd * 0.012) * np.array([-1, 1, 1], np.float32)
    wdm = wd * np.array([-1, 1, 1], np.float32)
    parts.append(Torus(w, 0.022, 0.004, Rm=basis(wdm, v3((0, 1, 0))), part=WATCH))
    parts.append(Box(w + v3((-0.023, 0.0, 0.0)), (0.004, 0.011, 0.013), rr=0.003, part=BRASS))
    return Union(parts, k=0.0)


def pieces():
    import os
    only = os.environ.get("FOLK_ONLY", "")
    s = 1.5 if os.environ.get("FOLK_FAST") else 1.0
    if only == "head":
        return [("head", head(), 0.0016 * s), ("hair", hair(), 0.002 * s), ("kit", glasses(), 0.0015 * s)]
    bd = body()
    return [("head", head(), 0.0016 * s), ("hair", hair(), 0.002 * s), ("body", bd, 0.003 * s), ("kit", kit_bits(bd), 0.0015 * s)]


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

    # skin: periwinkle blue, a pink flush on the cheeks and the nose's tip, deeper blue in the folds; darker blue spots on the arms and brow
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(132, 136, 214), (n, 3)).copy() * (1.0 + 0.06 * mott)[:, None]
    flush = np.exp(-(((Q[:, 0] - 0.075) / 0.025) ** 2 + ((z - 1.275) / 0.02) ** 2)) * (y < -0.08)
    tipn = np.exp(-((Q[:, 0] / 0.015) ** 2 + ((z - 1.27) / 0.012) ** 2)) * (y < -0.19)
    sk = sk + (srgb(206, 140, 196) - sk) * (0.6 * np.clip(flush + tipn, 0, 1))[:, None]
    sk *= (1.0 - 0.35 * c.cavity)[:, None]
    put(m, sk, 0.5, bump=0.12)
    spk(m, (96, 98, 176), 0.3)
    # the eyes' lids: inked rims round the big round eyes
    de = Q - EYE_C
    r = np.linalg.norm(de, axis=1)
    pd = (Q - LID_PT) @ LID_N
    c.draw(m & (r < EYE_R + 0.008) & (np.abs(pd) < 0.004) & (de[:, 1] < 0.01), np.abs(pd + 0.001), 0.0014)
    lowz = Q[:, 2] - (EYE_C[2] - 0.026)
    c.draw(m & (r < EYE_R + 0.006) & (np.abs(lowz) < 0.004) & (de[:, 1] < 0.0), np.abs(lowz - 0.0006), 0.0008, 0.6)
    # eyes: all yellow, deepening to orange at the rim, a black pupil, a glint
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    a = np.arccos(np.clip(d @ EYE_FWD, -1, 1))
    ir = srgb(252, 214, 84) + (srgb(226, 136, 30) - srgb(252, 214, 84)) * smooth(0.35, 0.95, a)[:, None]
    c.draw(m, (a / 0.17 - 1.0) * 0.17 * EYE_R, 0.0)
    gl = np.zeros(n, np.float32)
    for sx in (1.0, -1.0):
        dd = P - EYE_C * np.array([sx, 1.0, 1.0], np.float32)
        dd /= np.maximum(np.linalg.norm(dd, axis=1), 1e-6)[:, None]
        gl = np.maximum(gl, smooth(0.012, 0.004, (dd[:, 0] + 0.3) ** 2 + (dd[:, 2] - 0.25) ** 2) * (dd[:, 1] < -0.5))
    ir = ir + (srgb(255, 252, 240) - ir) * gl[:, None]
    put(m, ir, 0.08)
    put(c.mask(TOOTH), srgb(238, 214, 150) * (1.0 - 0.3 * c.cavity)[:, None], 0.3)
    put(c.mask(MOUTH), srgb(110, 30, 44), 0.6)
    m = c.mask(HAIR)
    hr = srgb(34, 28, 28) * (1.0 + 0.9 * c.wear)[:, None]
    put(m, hr, 0.3, bump=0.3)
    put(c.mask(BROW), srgb(22, 18, 20), 0.6, bump=0.5)
    # bat wings: thin lilac-pink membrane, darker spots; ribs the skin's blue
    m = c.mask(WING)
    put(m, srgb(214, 168, 206) * (1.0 + 0.05 * mott)[:, None], 0.45, bump=0.15)
    spk(m, (150, 104, 150), 0.5)
    put(c.mask(RIB), srgb(130, 132, 208) * (1.0 - 0.2 * c.cavity)[:, None], 0.5)
    put(c.mask(GLASS), srgb(44, 30, 24) * (1.0 + 0.6 * c.wear)[:, None], 0.25)
    # shirt cream, a faint check; the vest brown knit with cables; the tie in navy and mustard bars
    m = c.mask(SHIRT)
    sh = srgb(232, 220, 192) * (1.0 + 0.04 * mott)[:, None]
    put(m, sh, 0.85, bump=0.8)
    spk(m, (206, 186, 156), 0.25)
    m = c.mask(VEST)
    vs = srgb(136, 86, 48) * (1.0 + 0.08 * mott)[:, None] * (1.0 + 0.35 * c.wear)[:, None]
    put(m, vs, 0.92, bump=1.0)
    cable = np.abs(((Q[:, 0] + 0.2) % 0.04) - 0.02)
    braid = np.abs(np.sin(z * 120.0 + np.sign(((Q[:, 0] + 0.2) % 0.04) - 0.02) * 1.2))
    c.draw(m & (cable < 0.012), np.abs(cable - 0.009) + braid * 0.002, 0.0008, 0.4)
    m = c.mask(TIE)
    bar = ((x + z * 0.8) * 26.0) % 1.0 < 0.42
    tc = np.where(bar[:, None], srgb(220, 172, 60), srgb(42, 58, 114))
    put(m, tc, 0.45, bump=0.3)
    m = c.mask(BELT)
    put(m, srgb(92, 54, 30) * (1.0 + 0.6 * c.wear)[:, None], 0.45, bump=0.6, grain=1.0)
    put(c.mask(BRASS), srgb(228, 176, 86) * (1.0 - 0.4 * c.cavity)[:, None], 0.3, metal=1.0)
    m = c.mask(TROUSERS)
    put(m, srgb(74, 78, 104) * (1.0 + 0.06 * mott)[:, None] * (1.0 + 0.3 * c.wear)[:, None], 0.8, bump=0.9)
    m = c.mask(SHOE)
    put(m, srgb(124, 70, 38) * (1.0 + 0.7 * c.wear)[:, None], 0.25, bump=0.3, grain=1.0)
    put(c.mask(SOLE), srgb(46, 32, 24), 0.6)
    put(c.mask(WATCH), srgb(96, 58, 30), 0.45, grain=1.0, bump=0.4)
    put(c.mask(PEN_R), srgb(200, 40, 36), 0.35)
    put(c.mask(PEN_B), srgb(40, 60, 150), 0.35)
    put(c.mask(BUTTON), srgb(82, 52, 30), 0.35)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    c.col *= (1.0 - 0.2 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion
GAME = {
    "budget": {"head": 2800, "hair": 900, "body": 4300, "kit": 700},
    "density": {"head": 1.9, "hair": 1.0, "kit": 1.3},
    "tex": 2048,
    "stride": {"walk": 0.72, "run": 1.1},
    "speed": 1.0,
    "look": ["head", "wing.L", "wing.R"], "neck": "neck",
    "look_pivot": (0.0, -0.03, 1.23),
    "radius": 0.3,
}
BALL = v3((0.088, -0.08, 0.0))


def rig_bones():
    from kit.rig import Bone, mirror
    tip = WING_ROOT + WING_U * 0.17
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.015, 0.68), (0, 0.015, 0.8), "root", 0.12),
        Bone("spine", (0, 0.015, 0.8), (0, 0.03, 0.93), "hips", 0.1),
        Bone("chest", (0, 0.03, 0.93), (0, 0.04, 1.08), "spine", 0.11),
        Bone("neck", NECK0, NECK1, "chest", 0.035),
        Bone("head", NECK1, (0, -0.05, 1.52), "neck", 0.13),
        Bone("wing.L", WING_ROOT, tip, "head", 0.01),
        Bone("shoulder.L", (0.03, 0.04, 1.08), SHOULDER, "chest", 0.04),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.032),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.026),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.085, "forearm.L", 0.022),
        Bone("thigh.L", HIP, KNEE, "hips", 0.072),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.062),
        Bone("foot.L", ANKLE, ANKLE + v3((0.004, -0.15, -0.05)), "shin.L", 0.04),
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
    rig[hp & ((z > 1.2) | ((z > 1.14) & (y < -0.07)))] = ix["head"]
    for s, sd in ((1, "L"), (-1, "R")):
        wm = hp & np.isin(part, (WING, RIB)) & (s * x > 0)
        rig[wm] = ix["wing." + sd]
        rig[wm & (s * x < 0.135)] = -1
        allow(wm, "head", "wing." + sd)
    rig[piece == 1] = ix["head"]
    allow(piece == 1, "head")
    kp = piece == 3
    allow(kp, "chest")
    rig[kp] = ix["chest"]
    rig[kp & (z > 1.2)] = ix["head"]
    rig[kp & (z < 0.95)] = ix["spine"]
    rig[kp & (z < 0.8)] = ix["hips"]
    rig[kp & (part == WATCH)] = ix["forearm.R"]
    rig[kp & (part == BRASS) & (np.abs(x) > 0.15)] = ix["forearm.R"]
    bp = piece == 2
    legs = bp & ((np.isin(part, (TROUSERS, SHOE, SOLE)) & (z < 0.7)) | (z < 0.3))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs & (np.abs(x) < 0.135) & ~((part == SKIN) & (z < 1.05))
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.06) & (z > 1.0), "shoulder.L")
    allow(torso & (x < -0.06) & (z > 1.0), "shoulder.R")
    arms = bp & ~legs & ~torso
    allow(arms & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (z > 1.0), "chest")
    return A, rig


WALK = dict(stride=0.72, stance=0.58, foot_x=0.06, lift=0.045, bob=0.012, drop=0.04, sway=0.015, roll=4.0, yaw=5.0, counter=1.0,
            lean=8.0, toe_off=14.0, toe_out=-2.0, swing_point=6.0)
RUN = dict(stride=1.1, stance=0.42, foot_x=0.06, lift=0.09, bob=0.024, drop=0.06, sway=0.012, roll=3.0, yaw=7.0, counter=1.2,
           lean=16.0, toe_off=22.0, toe_out=-2.0, swing_point=12.0, spine_lean=4.0)
BACK = 0.075


def motions(rig):
    """his clips: walk (hurried nervous little steps, hunched over, elbows held in with quick small swings, the head darting left and right),
    run (a flustered scurry, arms flapping), idle (glancing about, a fidget of the hands, pushing his glasses up his nose)"""
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
        A = 26.0 if run else 9.0
        p.rot("upper_arm.L", A * c, 0, 2.0 if not run else -10.0)
        p.rot("upper_arm.R", -A * c, 0, -2.0 if not run else 10.0)
        p.rot("forearm.L", -(70.0 if run else 32.0) - 6.0 * max(0.0, -c), 0, 0)
        p.rot("forearm.R", -(70.0 if run else 32.0) - 6.0 * max(0.0, c), 0, 0)
        p.rot("chest", 4.0, 0, 0)
        p.rot("neck", 4.0, 0, 0)
        # the head darts: a quick glance one way, back, the other way, over the cycle
        dart = math.sin(TAU * u) * 14.0
        dart = math.copysign(min(abs(dart) * 1.6, 14.0), dart) if not run else dart * 0.4
        p.world["head"] = R(-4.0 + 2.0 * math.sin(2 * TAU * u - 0.6), 0, dart)
        fl = (8.0 if run else 4.0) * math.sin(2 * TAU * u - 1.3)
        p.rot("wing.L", 0, -fl, 0)
        p.rot("wing.R", 0, fl, 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    sh, el, wr = Vector(SHOULDER.tolist()), Vector(ELBOW.tolist()), Vector(WRIST.tolist())
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        br = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.075, -0.08, 0.0)), -2.0), "R": (Vector((-0.075, -0.09, 0.0)), 4.0)},
              hip_shift=(0.008 * w, 0.0, -0.01), roll=-1.5 * w)
        p.rot("spine", 1.0 * br, 0, 0)
        p.rot("chest", 3.0 + 1.0 * br, 0, 0)
        # glances: quick snaps of the head to each side and back, then the glasses pushed up his nose with his right hand (2.3-3.4 s)
        g = 0.0
        for t0, ang in ((0.5, 24.0), (1.1, -20.0), (4.2, -26.0), (4.9, 18.0)):
            g += ang * (ease((t - t0) / 0.12) - ease((t - t0 - 0.45) / 0.15))
        push = ease((t - 2.3) / 0.35) * (1.0 - ease((t - 3.2) / 0.35))
        p.world["head"] = R(-3.0 - 6.0 * push, 0, g)
        tgt = Vector((-0.035, -0.262, 1.236))
        rest = Vector((-wr.x, wr.y, wr.z))
        p.ik["upper_arm.R"] = (rest.lerp(tgt, push), Vector((-0.2, 1.0, 0.0)).lerp(Vector((-0.8, 0.3, -0.6)), push), "hand.R", R(156.0 * push, 0, -15.0 * push))
        p.rot("upper_arm.L", 2.0 * br, 0, 0)
        p.rot("forearm.L", -28.0 - 3.0 * br, 0, 0)
        p.rot("wing.L", 0, -3.0 * br, 0)
        p.rot("wing.R", 0, 3.0 * br, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
