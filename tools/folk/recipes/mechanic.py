## FOINT CITY townsfolk: the mechanic. A huge green ogre-ish fellow: a small head with a heavy brow, a lantern jaw and big round ears sunk on massive shoulders; orange tee, grease-stained dark overalls with reflective bands, a radio on the belt, work gloves, heavy boots. Carries his battered toolbox in his left hand.
# Concept: the user's sheet, image 4 top middle (F:/prog-godot-cache/folk/refs/4.webp). Measured off it: 2.20 m; the head 0.37 m tall and 0.41 wide at the jaw (the jaw
# is its widest), only 8 cm of skull above the eyes; ears 0.8 m across; shoulders about 1.05 m across the deltoids, the waist 0.6; crotch at 0.86, boots to 0.25.
# Rest pose = his carrying pose: the toolbox hangs from the left glove, the right arm hangs wide of the body.
import numpy as np
from kit.sdf import (Shape, Gem, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

F32 = np.float32
HEIGHT = 2.20
REF = ("4.webp", (411, 3, 750, 388))

(SKIN, EAR_IN, EYE, MOUTH, TEE, OVERALL, STRAP, STRIPE, BELT, BRASS, GLOVE, GPAD, BOOT, SOLE, LACE, BOX, BOXRED, HANDLE, RADIO, SCREEN,
 PEN_B, PEN_O, PAPER) = range(1, 24)
COLOURS = {
    SKIN: ((0.30, 0.38, 0.18), 0.6, 0.0),
    EAR_IN: ((0.75, 0.40, 0.36), 0.55, 0.0),
    EYE: ((0.85, 0.45, 0.10), 0.2, 0.0),
    MOUTH: ((0.15, 0.08, 0.06), 0.6, 0.0),
    TEE: ((0.85, 0.32, 0.10), 0.85, 0.0),
    OVERALL: ((0.12, 0.11, 0.12), 0.85, 0.0),
    STRAP: ((0.10, 0.09, 0.10), 0.8, 0.0),
    STRIPE: ((0.62, 0.62, 0.60), 0.45, 0.0),
    BELT: ((0.10, 0.08, 0.07), 0.6, 0.0),
    BRASS: ((0.75, 0.55, 0.25), 0.35, 1.0),
    GLOVE: ((0.72, 0.52, 0.22), 0.7, 0.0),
    GPAD: ((0.22, 0.21, 0.22), 0.7, 0.0),
    BOOT: ((0.30, 0.20, 0.13), 0.6, 0.0),
    SOLE: ((0.12, 0.10, 0.09), 0.7, 0.0),
    LACE: ((0.35, 0.28, 0.18), 0.7, 0.0),
    BOX: ((0.70, 0.66, 0.58), 0.45, 0.7),
    BOXRED: ((0.75, 0.15, 0.10), 0.5, 0.0),
    HANDLE: ((0.20, 0.20, 0.20), 0.5, 0.6),
    RADIO: ((0.10, 0.10, 0.11), 0.5, 0.0),
    SCREEN: ((0.80, 0.70, 0.20), 0.3, 0.0),
    PEN_B: ((0.12, 0.18, 0.45), 0.4, 0.0),
    PEN_O: ((0.92, 0.55, 0.12), 0.4, 0.0),
    PAPER: ((0.90, 0.88, 0.80), 0.8, 0.0),
}

# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; the figure faces -Y)
HEAD_C = v3((0.0, -0.045, 2.078))
EYE_C = v3((0.072, -0.176, 2.112))
EYE_R = 0.029
EYE_FWD = v3((0.12, -1.0, 0.02)) / np.linalg.norm((0.12, -1.0, 0.02))
LID_PT = EYE_C + v3((0.0, 0.0, 0.006))
LID_N = v3((0.06, 0.0, -1.0)) / np.linalg.norm((0.06, 0.0, -1.0))       # a heavy, level upper lid: the confident half-squint
LOW_Z = EYE_C[2] - 0.018
EAR_ROOT = v3((0.135, -0.035, 2.11))
EAR_U = v3((1.0, 0.28, 0.1)) / np.linalg.norm((1.0, 0.28, 0.1))         # out, back and a little up
MOUTH_X = 0.135
MOUTH_Z = 2.03

NECK0 = v3((0.0, 0.03, 1.70))
NECK1 = v3((0.0, -0.01, 1.9))
SHOULDER = v3((0.415, 0.03, 1.675))
ELBOW = v3((0.545, 0.07, 1.22))
WRIST = v3((0.60, 0.0, 0.89))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
HIP = v3((0.17, 0.02, 0.92))
KNEE = v3((0.215, -0.03, 0.53))
ANKLE = v3((0.23, 0.03, 0.135))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def prism(poly_xz, y0=-0.8, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from y0 to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def side_prism(poly_yz, x0, x1):
    """a side-view outline (y, z) pushed through from x0 to x1"""
    return Slab(((x0 + x1) * 0.5, 0, 0), poly_yz, (x1 - x0) * 0.5, R=np.array([[0, 0, 1], [1, 0, 0], [0, 1, 0]], np.float32))


def probe(shape, x, z, y0=-0.7, y1=0.5, step=0.002):
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


class Local(Shape):
    """a Bump that only evaluates fn inside a box (lo, hi)"""
    def __init__(self, child, fn, amp, lo, hi):
        self.child, self.fn, self.amp = child, fn, F32(amp)
        self.blo, self.bhi = v3(lo), v3(hi)
        self.lo, self.hi = child.bound()
        self.part = child.part

    def eval(self, P):
        d, pt = self.child.eval(P)
        m = np.all((P >= self.blo) & (P <= self.bhi), axis=1)
        if m.any():
            d[m] -= self.amp * self.fn(P[m])
        return d, pt

    def dist(self, P):
        return self.eval(P)[0]


class Bounded(Shape):
    """the child with a tighter box than its own (a Slab's is a cube round its centre): unions skip it outside the box"""
    def __init__(self, child, lo, hi):
        self.child = child
        self.lo, self.hi = v3(lo), v3(hi)
        self.part = child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.child.eval(P)[0]


HS = 1.2                                   # round 2: the head 20% bigger, scaled about its crown
PIV = v3((0.0, -0.06, 2.205))


def W(p):
    """a head landmark (built at the old size) where it ends up in the world"""
    return PIV + (v3(p) - PIV) * HS


def L(P):
    """world points back into the head's build space"""
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


class Scale(Shape):
    """the child scaled by s about the origin (its own frame), with a true bound and distances (the kit's Move with a scaling matrix gets the bound wrong)"""
    def __init__(self, child, s):
        self.child, self.s = child, F32(s)
        lo, hi = child.bound()
        self.lo, self.hi = np.asarray(lo, F32) * self.s, np.asarray(hi, F32) * self.s
        self.part = child.part

    def eval(self, P):
        d, pt = self.child.eval(P / self.s)
        return d * self.s, pt

    def dist(self, P):
        return self.eval(P)[0]


def slab_box(c, poly, t, R):
    """the world box round a Slab's polygon"""
    pts = np.array([[u, v, s] for u, v in poly for s in (-t, t)], np.float32)
    w = pts @ np.asarray(R, np.float32).T + v3(c)
    return w.min(0) - 0.004, w.max(0) + 0.004


# ---------------------------------------------------------------------------------------------------- the head
def skull():
    """built small and scaled up by HS: a low blocky skull under a heavy shelf brow, flat cheek planes, a long flat upper lip, and a squared lantern
    jaw wider than the cranium (round 2: the lead asked for angular planes, not ellipsoids)"""
    return Union([
        Gem(HEAD_C, (0.14, 0.14, 0.15, 0.15, 0.12, 0.122), soft=0.55, edge=0.012),       # the low cranium
        Box((0.0, -0.17, 2.146), (0.15, 0.048, 0.026), rr=0.022, R=rot(rx=14)),          # the brow: a shelf over the eyes
        Mirror(Gem((0.112, -0.135, 2.062), (0.06, 0.075, 0.07, 0.06, 0.065, 0.05), soft=0.4, edge=0.01)),     # flat cheek planes
        Box((0.0, -0.188, 2.05), (0.122, 0.056, 0.042), rr=0.028),                       # the long flat upper lip
        Box((0.0, -0.095, 1.928), (0.196, 0.135, 0.1), rr=0.066),                        # the jaw: a broad block, its corners worn round
        Box((0.0, -0.205, 1.902), (0.138, 0.058, 0.086), rr=0.05),                       # the chin, squared and jutting
    ], k=0.045, part=SKIN)


def face_shape():
    sk = skull()
    lid = Clip(Ellipsoid(EYE_C + v3((0, -0.001, 0.002)), (0.034, 0.034, 0.034), part=SKIN), [Half(LID_PT, LID_N)], k=0.005)
    lower = Clip(Ellipsoid(EYE_C + v3((0, -0.001, -0.002)), (0.033, 0.033, 0.033), part=SKIN), [Half(v3((0, 0, LOW_Z)), (0.0, 0.0, 1.0))], k=0.005)
    # sockets: the brow overhangs deep-set eyes
    sockets = Mirror(Ellipsoid(EYE_C + v3((0.004, -0.024, 0.002)), (0.04, 0.026, 0.026), part=SKIN))
    face = Cut(sk, [sockets], k=0.012)
    face = Union([face, Mirror(lid), Mirror(lower)], k=0.007)
    # a short broad nose from under the brow, wide nostrils
    nose = Union([
        RoundCone((0, -0.195, 2.122), (0, -0.236, 2.088), 0.024, 0.028),
        Ellipsoid((0, -0.244, 2.08), (0.04, 0.03, 0.026)),
        Mirror(Ellipsoid((0.033, -0.228, 2.072), (0.021, 0.019, 0.017))),
    ], k=0.012, part=SKIN)
    face = Union([face, nose], k=0.012)
    nostrils = Mirror(Ellipsoid((0.021, -0.248, 2.066), (0.009, 0.01, 0.006), R=rot(rx=30, rz=-15), part=SKIN))
    return Cut(face, [nostrils], k=0.002)


def ears():
    """big round ears standing out, their pink insides to the front"""
    u = EAR_U
    vv = v3((0, 0, 1)) - u * u[2]
    vv /= np.linalg.norm(vv)
    n = np.cross(u, vv)
    if n[1] > 0:
        n = -n
    R = np.stack([u, vv, n], 1)
    poly = [(-0.04, 0.05), (0.05, 0.072), (0.13, 0.068), (0.2, 0.045), (0.245, 0.012), (0.24, -0.024), (0.2, -0.045), (0.12, -0.056), (0.04, -0.058), (-0.04, -0.045)]
    plate = Slab(EAR_ROOT, poly, 0.011, rr=0.009, R=R, part=SKIN)
    plate = Bounded(plate, *slab_box(EAR_ROOT, poly, 0.011, R))
    cup = Ellipsoid(EAR_ROOT + u * 0.125 + vv * 0.006 + n * 0.017, (0.11, 0.047, 0.014), R=R, part=EAR_IN)
    ear = Cut(plate, [cup], k=0.008)
    ear = Union([ear, Clip(Ellipsoid(EAR_ROOT + u * 0.125 + vv * 0.006 + n * 0.002, (0.105, 0.043, 0.008), R=R, part=EAR_IN), [Half(EAR_ROOT + n * 0.0, -n)])], k=0.0)
    return Mirror(ear)


def mouth_z(x):
    return MOUTH_Z + 0.012 * (np.abs(x) / MOUTH_X) ** 2 + 0.004 * np.clip(x / MOUTH_X, 0, 1)     # a slight smirk, higher at his left


def head():
    """the head built at its old size and scaled up HS about the crown (round 2: the concept's head is much bigger and blockier), on a thick neck
    that runs straight into the traps"""
    local = head_local()
    neck = Union([RoundCone(NECK0, W(NECK1), 0.19, 0.18, part=SKIN),
                  Mirror(RoundCone(v3((0.07, -0.06, 1.72)), W(v3((0.05, -0.14, 1.9))), 0.03, 0.026, part=SKIN))], k=0.04)
    return Union([ScaleAt(local, HS, PIV), neck], k=0.05)


def head_local():
    face = Union([face_shape(), ears()], k=0.02)
    base = face
    # the mouth: a long closed line where the upper lip meets the jaw, deepened at the corners
    curve = [(float(x), float(mouth_z(x))) for x in np.linspace(-MOUTH_X, MOUTH_X, 17)]
    pts = [on(base, x, z) for x, z in curve]
    rad = [0.0045 * (1.0 - 0.4 * (abs(x) / MOUTH_X) ** 2) for x, _ in curve]
    slit = loft([(p + v3((0, 0.003, 0)), r) for p, r in zip(pts, rad)], k=0.002)
    face = Cut(face, [slit], k=0.003)
    back = loft([(p + v3((0, 0.010, 0)), r) for p, r in zip(pts, rad)], part=MOUTH, k=0.002)
    # folds: the creases of the cheeks round the muzzle, the cleft and the jaw's lower lip line, the frown between the brows
    fold = [on(base, x, z, 0.002) for x, z in ((0.05, 2.09), (0.105, 2.07), (0.145, 2.03), (0.15, 1.99))]
    lip = [on(base, x, z, 0.002) for x, z in ((0.0, 1.995), (0.06, 1.998), (0.11, 2.005))]
    face = Crease(face, fold, 0.014, -0.007)
    face = Crease(face, lip, 0.01, -0.003)
    face = Crease(face, [on(base, 0.0, 1.88, 0.002), on(base, 0.0, 1.95, 0.002)], 0.008, -0.003, mirror=False)
    face = Crease(face, [on(base, 0.012, 2.145, 0.002), on(base, 0.02, 2.17, 0.002)], 0.006, -0.003)
    face = Crease(face, [on(base, x, 2.174, 0.002) for x in (0.0, 0.04, 0.08)], 0.006, -0.002)
    ball = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    return Union([face, back, ball], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body
def core():
    """the barrel chest and the great slope of the traps, a waist narrower than the shoulders, the seat"""
    return Union([
        Ellipsoid((0, 0.0, 1.47), (0.34, 0.25, 0.25)),
        Ellipsoid((0, 0.05, 1.74), (0.30, 0.18, 0.125)),                   # traps, rising to the back of the jaw
        Mirror(Ellipsoid((0.365, 0.03, 1.69), (0.165, 0.155, 0.135))),    # the shoulder caps
        Ellipsoid((0, 0.0, 1.20), (0.30, 0.22, 0.17)),
        Ellipsoid((0, 0.02, 1.0), (0.31, 0.22, 0.14)),
    ], k=0.08, part=TEE)


def legs_core():
    return Mirror(loft([(HIP, 0.16), (KNEE, 0.15), (ANKLE + v3((0, 0, 0.12)), 0.145)], k=0.05))


def arm_parts(elbow, wrist):
    """(the tee's sleeve, the bare arm, the glove cuff): huge arms"""
    d = (wrist - elbow) / np.linalg.norm(wrist - elbow)
    upper = loft([(SHOULDER, 0.14), (SHOULDER + (elbow - SHOULDER) * 0.45, 0.135), (elbow, 0.112)], part=SKIN, k=0.03)
    fore = loft([(elbow, 0.112), (elbow + (wrist - elbow) * 0.35, 0.128), (wrist, 0.095)], part=SKIN, k=0.03)
    ua = (elbow - SHOULDER) / np.linalg.norm(elbow - SHOULDER)
    sleeve = Clip(Inflate(loft([(SHOULDER, 0.14), (SHOULDER + (elbow - SHOULDER) * 0.45, 0.135), (elbow, 0.112)], k=0.03), 0.014, part=TEE),
                  [Half(SHOULDER + ua * 0.27, ua)], k=0.006)
    return sleeve, Union([upper, fore], k=0.04)


def glove(grip):
    """a big work glove in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y); grip: fingers hooked round a handle along Y"""
    cuff = CappedCone((0, 0, 0.06), (0, 0, -0.02), 0.098, 0.092, rr=0.012, part=GPAD)
    palm = Ellipsoid((0.0, 0.0, -0.07), (0.045, 0.075, 0.075), part=GLOVE)
    knuckle = Box((0.03, 0.0, -0.11), (0.018, 0.068, 0.03), rr=0.014, part=GPAD)
    parts = [cuff, palm, knuckle]
    for f in (-0.051, -0.017, 0.017, 0.051):
        L = 1.0 - abs(f) * 2.5
        if grip:
            pts = [((0.0, f, -0.13), 0.022), ((0.0, f, -0.13 - 0.05 * L), 0.021), ((-0.045, f, -0.17 - 0.04 * L), 0.02), ((-0.08, f, -0.155 - 0.03 * L), 0.018)]
        else:
            pts = [((0.0, f, -0.13), 0.022), ((-0.01, f, -0.13 - 0.05 * L), 0.021), ((-0.04, f, -0.17 - 0.04 * L), 0.02), ((-0.07, f, -0.17 - 0.03 * L), 0.018)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=GLOVE, k=0.006))
    parts.append(loft([(v3((-0.02, -0.06, -0.04)), 0.026), (v3((-0.05, -0.085, -0.10)), 0.023), (v3((-0.075, -0.07, -0.14)), 0.02)], part=GLOVE, k=0.006))
    return Union(parts, k=0.012)


GLOVE_S = 1.38                            # the gloves are built small and scaled up
GRIP_AT = v3((-0.055, 0.0, -0.17)) * GLOVE_S  # where the toolbox handle sits in the left glove, hand space


def toolbox():
    """the battered toolbox in hand space: its long side along hand Y (front to back), the handle under the hooked fingers"""
    top = GRIP_AT[2] - 0.035
    c = v3((GRIP_AT[0], 0.0, top - 0.14))
    body = Box(c, (0.12, 0.25, 0.14), rr=0.024, part=BOX)
    lidline = Box(c + v3((0, 0, 0.07)), (0.127, 0.256, 0.008), rr=0.006, part=BOX)
    latch = [Box(c + v3((sx * 0.127, sy * 0.13, 0.055)), (0.008, 0.024, 0.032), rr=0.004, part=HANDLE) for sx in (-1, 1) for sy in (-1, 1)]
    handle = loft([(v3((GRIP_AT[0], -0.13, top + 0.004)), 0.012), (v3((GRIP_AT[0], -0.112, GRIP_AT[2])), 0.013), (v3((GRIP_AT[0], 0.112, GRIP_AT[2])), 0.013),
                   (v3((GRIP_AT[0], 0.13, top + 0.004)), 0.012)], part=HANDLE, k=0.01)
    lugs = [Box(v3((GRIP_AT[0], s * 0.13, top + 0.003)), (0.024, 0.018, 0.01), rr=0.004, part=HANDLE) for s in (-1, 1)]
    label = Clip(Inflate(Box(c, (0.12, 0.25, 0.14), rr=0.024), 0.002, part=BOXRED), [Box(c + v3((-0.125, 0.08, -0.055)), (0.03, 0.13, 0.05))], k=0.0)
    box = Union([body, lidline] + latch + lugs + [handle, label], k=0.0)

    def dents(P):
        return noise3(P, 0.06) * 0.6 + noise3(P, 0.025) * 0.4
    return Bump(box, dents, 0.004)


def body():
    co = core()
    sl_l, arm_l = arm_parts(ELBOW, WRIST)
    tee = Union([co, sl_l, Move(sl_l, R=FLIP)], k=0.03, part=TEE)
    tee = Clip(tee, [Half((0, 0, 1.25), (0, 0, -1))], k=0.01)
    # the overalls: the seat and legs grown from the body; the bib, straps over the shoulders, pockets, a belt; reflective bands under the knees
    over_core = Union([Clip(Inflate(co, 0.012), [Half((0, 0, 1.18), (0, 0, 1))]), legs_core()], k=0.08)
    trousers = Clip(Inflate(over_core, 0.0, part=OVERALL), [Half((0, 0, 0.165), (0, 0, -1))], k=0.006)

    def folds(P):
        return noise3(P * np.array([1.0, 1.0, 0.4], np.float32), 0.05) * (P[:, 2] < 0.85)
    trousers = Bump(trousers, folds, 0.007)
    bib = Clip(Inflate(co, 0.018, part=OVERALL), [prism([(-0.22, 1.12), (0.22, 1.12), (0.21, 1.575), (-0.21, 1.575)])], k=0.006)
    back = Clip(Inflate(co, 0.018, part=OVERALL), [prism([(-0.25, 1.12), (0.25, 1.12), (0.18, 1.36), (-0.18, 1.36)], 0.0, 0.8)], k=0.006)
    straps = Clip(Inflate(co, 0.026, part=STRAP), [Mirror(Union([Box((0.215, -0.2, 1.72), (0.045, 0.21, 0.16)), Box((0.18, 0.25, 1.56), (0.045, 0.25, 0.31), R=rot(ry=-14))]))], k=0.004)
    pocket = Clip(Inflate(co, 0.03, part=OVERALL), [prism([(-0.15, 1.25), (0.15, 1.25), (0.155, 1.44), (-0.155, 1.44)])], k=0.004)
    pflap = Clip(Inflate(co, 0.034, part=OVERALL), [prism([(0.0, 1.41), (0.15, 1.41), (0.155, 1.445), (0.0, 1.445)])], k=0.004)
    belt = Clip(Inflate(over_core, 0.014, part=BELT), [Half((0, 0, 1.06), (0, 0, -1)), Half((0, 0, 1.115), (0, 0, 1))], k=0.003)
    cargo = Clip(Inflate(legs_core(), 0.016, part=OVERALL), [side_prism([(-0.14, 0.62), (0.02, 0.62), (0.02, 0.80), (-0.14, 0.80)], -0.6, -0.2)], k=0.004)
    cflap = Clip(Inflate(legs_core(), 0.02, part=OVERALL), [side_prism([(-0.145, 0.775), (0.025, 0.775), (0.025, 0.81), (-0.145, 0.81)], -0.6, -0.2)], k=0.004)
    stripes = Clip(Inflate(legs_core(), 0.006, part=STRIPE), [Half((0, 0, 0.47), (0, 0, -1)), Half((0, 0, 0.53), (0, 0, 1))], k=0.002)
    hem = Clip(Inflate(legs_core(), 0.008, part=OVERALL), [Half((0, 0, 0.165), (0, 0, -1)), Half((0, 0, 0.21), (0, 0, 1))], k=0.004)
    over = Union([trousers, bib, back, pocket, pflap, belt, cargo, cflap, stripes, hem], k=0.0)
    over = Union([over, straps], k=0.0)
    boots = Mirror(boot())
    gl = place(Scale(glove(True), GLOVE_S), WRIST, HAND)
    gr = place(Scale(glove(False), GLOVE_S), WRIST, HAND)
    return Union([tee, over, arm_l, Move(arm_l, R=FLIP), gl, Move(gr, R=FLIP), boots], k=0.0)


def boot():
    """a heavy laced work boot (left), the toe a rounded cap"""
    shaft = CappedCone(ANKLE + v3((0, 0.0, -0.11)), ANKLE + v3((0, -0.005, 0.11)), 0.118, 0.124, rr=0.02)
    foot = loft([(ANKLE + v3((0.0, 0.065, -0.045)), 0.094), (ANKLE + v3((0.004, -0.12, -0.05)), 0.098), (ANKLE + v3((0.006, -0.235, -0.062)), 0.08)], k=0.03)
    b = Union([shaft, foot], k=0.05, part=BOOT)
    b = Clip(b, [Half((0, 0, 0.045), (0, 0, -1))], k=0.006)
    sole = Clip(Inflate(Union([foot, shaft], k=0.05), 0.01, part=SOLE), [Half((0, 0, 0.055), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)

    def tread(P):
        return (np.sin(P[:, 1] * 140.0) > 0.3) * (P[:, 2] < 0.02)
    sole = Bump(sole, tread, -0.006)
    laces = []
    for i in range(4):
        z = 0.11 + i * 0.035
        y = ANKLE[1] - 0.12 + i * 0.012
        laces.append(Box((ANKLE[0], y, z), (0.045, 0.006, 0.006), rr=0.004, R=rot(rx=-30), part=LACE))
    tongue_pad = Clip(Inflate(shaft, 0.008, part=BOOT), [Half((0, 0, 0.21), (0, 0, -1)), Half((0, 0, 0.245), (0, 0, 1))], k=0.004)
    return Union([b, sole, tongue_pad] + laces, k=0.0)


def kit_bits(bd):
    """the radio on his right hip, pens and a notepad in the bib pocket, the bib buckles, a D-ring on his left hip"""
    parts = []
    ry = probe(bd, -0.2, 1.0)
    radio = Box((-0.20, ry - 0.022, 0.985), (0.042, 0.022, 0.07), rr=0.01, part=RADIO)
    screen = Box((-0.20, ry - 0.044, 1.01), (0.026, 0.002, 0.016), rr=0.002, part=SCREEN)
    antenna = RoundCone((-0.225, ry - 0.022, 1.05), (-0.235, ry - 0.022, 1.16), 0.007, 0.005, part=RADIO)
    knob = CappedCone((-0.18, ry - 0.022, 1.05), (-0.18, ry - 0.022, 1.07), 0.009, 0.009, rr=0.002, part=RADIO)
    parts += [radio, screen, antenna, knob]
    for x, part, top in ((-0.10, PEN_B, 1.50), (-0.075, PEN_O, 1.49)):
        y = probe(bd, x, 1.40) + 0.012
        parts.append(RoundCone((x, y, 1.38), (x, y - 0.004, top), 0.0085, 0.008, part=part))
    py = probe(bd, 0.04, 1.40) + 0.01
    parts.append(Box((0.04, py, 1.45), (0.06, 0.006, 0.05), rr=0.004, R=rot(ry=-6), part=PAPER))
    parts.append(Union([Torus((0.04 + k * 0.02 - 0.05, py - 0.002, 1.50), 0.006, 0.0018, Rm=rot(rx=90), part=HANDLE) for k in range(6)]))
    for s in (-1, 1):
        y = probe(bd, s * 0.19, 1.565)
        parts.append(Box((s * 0.19, y - 0.008, 1.565), (0.034, 0.008, 0.03), rr=0.006, part=BRASS))
        parts.append(Sphere((s * 0.19, y - 0.016, 1.545), 0.012, part=BRASS))
    dy = probe(bd, 0.23, 1.04)
    parts.append(Torus((0.23, dy - 0.01, 1.02), 0.026, 0.0055, Rm=rot(rx=90), part=BRASS))
    return Union(parts, k=0.0)


def pieces():
    import os
    only = os.environ.get("FOLK_ONLY", "")
    s = 1.4 if os.environ.get("FOLK_FAST") else 1.0
    if only == "head":
        return [("head", head(), 0.0025 * s)]
    bd = body()
    tb = place(toolbox(), WRIST, HAND)
    return [("head", head(), 0.0025 * s), ("body", bd, 0.005 * s), ("kit", kit_bits(bd), 0.0022 * s), ("props", tb, 0.003 * s)]


# ---------------------------------------------------------------------------------------------------- paint
def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.05) * 0.5 + noise3(P, 0.015) * 0.25

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

    grime = np.clip(noise3(P, 0.06) * 0.7 + noise3(P, 0.02) * 0.5, 0.0, 1.0)

    # skin: olive green, yellower where it stands out on the face, deeper in the folds; dark freckles over the jaw and arms; leathery
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(126, 134, 84), (n, 3)).copy() * (1.0 + 0.1 * mott)[:, None]
    hi = np.clip(c.wear * 1.4, 0, 1) * (z > 1.75)
    sk = sk + (srgb(156, 156, 100) - sk) * (0.5 * hi)[:, None]
    sk = sk * (1.0 - 0.45 * c.cavity)[:, None]
    # darker heavy lids, inked lash lines along them (worked out in the head's build space)
    Hh = L(P)
    HQ = Hh.copy()
    HQ[:, 0] = np.abs(HQ[:, 0])
    de = HQ - EYE_C
    r = np.linalg.norm(de, axis=1)
    pd = (HQ - LID_PT) @ LID_N
    near = (r < EYE_R + 0.008) & (pd > -0.006) & (pd < 0.003) & (de[:, 1] < 0.006)
    c.draw(near & m, np.abs(pd + 0.001), 0.0013)
    lowd = HQ[:, 2] - LOW_Z
    c.draw(m & (r < EYE_R + 0.006) & (np.abs(lowd) < 0.004) & (de[:, 1] < 0.0), np.abs(lowd - 0.0006), 0.0007, 0.6)
    lid = (r < EYE_R + 0.009) & (pd < 0)
    sk = np.where(lid[:, None], sk * np.array([0.82, 0.78, 0.8], np.float32), sk)
    put(m, sk, 0.62, bump=0.35, grain=1.0)
    spk(m, (92, 84, 52), 0.4 * (z > 1.0) + 0.3 * (z < 1.0))
    # the mouth line inked
    hx, hy, hz = Hh[:, 0], Hh[:, 1], Hh[:, 2]
    mz = MOUTH_Z + 0.012 * (np.abs(hx) / MOUTH_X) ** 2 + 0.004 * np.clip(hx / MOUTH_X, 0, 1)
    md = np.abs(hz - mz)
    c.draw(m & (np.abs(hx) < MOUTH_X + 0.006) & (md < 0.01) & (hy < -0.15) & (z > 1.6), (md - 0.0025 * (1.0 - (np.abs(hx) / MOUTH_X) ** 2)) * HS, 0.0009, 0.7)
    # ears: pink insides with fine darker veins
    m = c.mask(EAR_IN)
    q = HQ - EAR_ROOT
    ang = np.arctan2(q[:, 2], q[:, 0])
    vein = np.abs(np.sin(ang * 9.0 + noise3(P, 0.03) * 2.0))
    put(m, srgb(222, 140, 124) * (1.0 - 0.25 * c.cavity)[:, None], 0.5, bump=0.2)
    c.draw(m & (np.linalg.norm(q, axis=1) > 0.05), vein * 0.012, 0.0009, 0.35)
    # eyes: amber-orange irises, dark pupils glancing to his right, a glint
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    look = EYE_FWD + v3((-0.25, 0.0, 0.0))
    look /= np.linalg.norm(look)
    a = np.arccos(np.clip(d @ look, -1, 1))
    ir = srgb(244, 168, 56) + (srgb(196, 90, 20) - srgb(244, 168, 56)) * smooth(0.15, 0.55, a)[:, None]
    ir = ir + (srgb(70, 30, 10) - ir) * smooth(0.6, 0.8, a)[:, None]
    c.draw(m, (a / 0.24 - 1.0) * 0.24 * EYE_R, 0.0)
    gl = np.zeros(n, np.float32)
    for sx in (1.0, -1.0):
        dd = Hh - EYE_C * np.array([sx, 1.0, 1.0], np.float32)
        dd /= np.maximum(np.linalg.norm(dd, axis=1), 1e-6)[:, None]
        gl = np.maximum(gl, smooth(0.012, 0.004, (dd[:, 0] + 0.25) ** 2 + (dd[:, 2] + 0.05) ** 2) * (dd[:, 1] < -0.5))
    ir = ir + (srgb(255, 250, 236) - ir) * gl[:, None]
    put(m, ir, 0.1)
    put(c.mask(MOUTH), srgb(50, 26, 22), 0.6)

    # the tee: orange cotton, sweat-darkened and greasy in places, rubbed paler on top
    m = c.mask(TEE)
    te = srgb(206, 90, 40) * (1.0 + 0.08 * mott)[:, None]
    te = te + (srgb(150, 60, 26) - te) * (np.clip(grime - 0.45, 0, 1) * 0.9)[:, None]
    te *= (1.0 + 0.3 * c.wear)[:, None]
    put(m, te, 0.88, bump=1.0)
    # the overalls: near-black canvas rubbed grey on every edge, grease and rust stains, worse low down
    m = c.mask(OVERALL, STRAP)
    ov = srgb(52, 50, 56) * (1.0 + 0.12 * mott)[:, None]
    ov = ov * (1.0 + 0.9 * c.wear)[:, None]
    stain = np.clip(noise3(P, 0.04) * 0.8 + noise3(P, 0.012) * 0.5 + smooth(1.0, 0.2, z) * 0.35 - 0.3, 0, 1)
    ov = ov + (srgb(120, 74, 40) - ov) * (stain * 0.75)[:, None]
    put(m, ov, 0.9, bump=1.0)
    spk(m, (150, 92, 44), 0.55)
    put(c.mask(STRAP), ov * 0.85, 0.85, bump=1.0)
    # stitching round the bib and its pocket
    for (x0, x1, z0, z1) in ((-0.15, 0.15, 1.25, 1.44), (-0.22, 0.22, 1.12, 1.575)):
        inb = (x > x0 - 0.01) & (x < x1 + 0.01) & (z > z0 - 0.01) & (z < z1 + 0.01) & (y < -0.1)
        dist = np.minimum(np.where((z > z0) & (z < z1), np.minimum(np.abs(x - x0 - 0.008), np.abs(x - x1 + 0.008)), 1.0),
                          np.where((x > x0) & (x < x1), np.minimum(np.abs(z - z0 - 0.008), np.abs(z - z1 + 0.008)), 1.0))
        c.draw(c.mask(OVERALL) & inb, dist, 0.0011, 0.45 * (np.sin((x + z) * 500.0) > -0.3))
    m = c.mask(STRIPE)
    put(m, srgb(184, 186, 182) * (1.0 - 0.35 * stain)[:, None], 0.35, bump=0.3)
    m = c.mask(BELT)
    put(m, srgb(34, 28, 26) * (1.0 + 0.8 * c.wear)[:, None], 0.5, bump=0.6, grain=1.0)
    m = c.mask(BRASS)
    put(m, srgb(200, 150, 70) * (1.0 - 0.45 * c.cavity)[:, None], 0.35, metal=1.0, grain=1.0, bump=0.2)
    # gloves: tan leather scuffed paler, dirty in the creases; grey padding
    m = c.mask(GLOVE)
    gv = srgb(196, 146, 72) * (1.0 + 0.5 * c.wear)[:, None] * (1.0 - 0.5 * c.cavity)[:, None]
    gv = gv + (srgb(110, 80, 40) - gv) * (np.clip(grime - 0.4, 0, 1))[:, None]
    put(m, gv, 0.7, bump=0.8, grain=1.0)
    m = c.mask(GPAD)
    put(m, srgb(66, 64, 68) * (1.0 + 0.6 * c.wear)[:, None], 0.75, bump=1.0)
    # boots: brown leather, scuffed, mud splashed
    m = c.mask(BOOT, LACE)
    bt = srgb(96, 66, 44) * (1.0 + 0.8 * c.wear)[:, None]
    bt = bt + (srgb(150, 104, 60) - bt) * (np.clip(noise3(P, 0.025) * 0.9 - 0.2, 0, 1))[:, None]
    put(m, bt, 0.55, bump=0.7, grain=1.0)
    spk(m, (168, 112, 58), 0.5)
    put(c.mask(LACE), srgb(150, 120, 80), 0.7)
    put(c.mask(SOLE), srgb(36, 30, 28) * (1.0 + 0.5 * c.wear)[:, None], 0.8, bump=0.5)
    # the toolbox: pale enamelled steel, chipped and rusted, a red-and-yellow hazard label; dark handle and latches
    m = c.mask(BOX)
    rust = np.clip(noise3(P, 0.02) * 0.9 + noise3(P, 0.007) * 0.5 - 0.1, 0, 1)
    bx = srgb(204, 184, 152) * (1.0 + 0.06 * mott)[:, None]
    bx = bx + (srgb(150, 82, 40) - bx) * (rust * 0.85)[:, None]
    bx *= (1.0 - 0.4 * c.cavity)[:, None]
    put(m, bx, 0.5 + 0.4 * rust, metal=0.35 * (1.0 - rust), bump=0.4)
    spk(m, (120, 60, 28), 0.6)
    m = c.mask(BOXRED)
    hz = np.sin((y + z) * 55.0) > 0.0
    lab = np.where(hz[:, None], srgb(236, 190, 40), srgb(190, 40, 30))
    put(m, lab * (1.0 - 0.4 * rust)[:, None], 0.6)
    m = c.mask(HANDLE)
    put(m, srgb(60, 60, 62) * (1.0 + 1.2 * c.wear)[:, None], 0.45, metal=0.8, bump=0.2)
    m = c.mask(RADIO)
    put(m, srgb(30, 30, 34) * (1.0 + 0.8 * c.wear)[:, None], 0.45, bump=0.4, grain=1.0)
    put(c.mask(SCREEN), srgb(214, 190, 70), 0.25)
    put(c.mask(PEN_B), srgb(40, 60, 140), 0.35)
    put(c.mask(PEN_O), srgb(236, 150, 40), 0.4)
    m = c.mask(PAPER)
    put(m, srgb(232, 226, 210), 0.85)
    c.draw(m, np.abs(np.sin(z * 220.0)) * 0.0045, 0.0003, 0.35)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion
GAME = {
    "budget": {"head": 2600, "body": 5400, "kit": 600, "props": 900},
    "density": {"head": 1.7, "kit": 1.2, "props": 1.0},
    "tex": 2048,
    "stride": {"walk": 1.1, "run": 1.7},
    "speed": 0.75,
    "look": ["head", "ear.L", "ear.R"], "neck": "neck",
    "look_pivot": (0.0, -0.002, 1.84),
    "radius": 0.62,
}
BALL = v3((0.235, -0.15, 0.0))
GRIP = WRIST + HAND @ GRIP_AT


def rig_bones():
    from kit.rig import Bone, mirror
    hand_end = WRIST - HAND[:, 2] * 0.17
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.2, 0), None, 0.0),
        Bone("hips", (0, 0.02, 0.95), (0, 0.02, 1.12), "root", 0.24),
        Bone("spine", (0, 0.02, 1.12), (0, 0.02, 1.35), "hips", 0.24),
        Bone("chest", (0, 0.02, 1.35), (0, 0.02, 1.64), "spine", 0.26),
        Bone("neck", NECK0, W(NECK1), "chest", 0.19),
        Bone("head", W(NECK1), (0, -0.06, 2.2), "neck", 0.21),
        Bone("ear.L", W(EAR_ROOT), W(EAR_ROOT + EAR_U * 0.22), "head", 0.035),
        Bone("shoulder.L", (0.1, 0.03, 1.62), SHOULDER, "chest", 0.12),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.12),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.1),
        Bone("hand.L", WRIST, hand_end, "forearm.L", 0.06),
        Bone("thigh.L", HIP, KNEE, "hips", 0.15),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.14),
        Bone("foot.L", ANKLE, ANKLE + v3((0.005, -0.25, -0.08)), "shin.L", 0.08),
    ])
    bones.append(Bone("box", GRIP, GRIP - v3((0, 0, 0.3)), "hand.L", 0.15))
    return bones


def skin_rules(P, part, piece, names):
    """piece: 0 head, 1 body, 2 kit, 3 props"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    hp = piece == 0
    hl = L(P)
    allow(hp, "chest", "neck", "head")
    rig[hp & ((hl[:, 2] > 1.97) | ((hl[:, 1] < -0.13) & (hl[:, 2] > 1.8)))] = ix["head"]
    for s, sd in ((1, "L"), (-1, "R")):
        em = hp & (s * hl[:, 0] > 0.17) & (hl[:, 2] > 2.0)
        rig[em] = -1
        allow(em, "ear." + sd)
        rig[hp & (s * hl[:, 0] > 0.2) & (hl[:, 2] > 2.0)] = ix["ear." + sd]
    kp = piece == 2
    allow(kp, "hips")
    rig[kp] = ix["chest"]
    rig[kp & (z < 1.2)] = ix["hips"]
    rig[piece == 3] = ix["box"]
    allow(piece == 3, "box")
    bp = piece == 1
    legs = bp & ((np.isin(part, (OVERALL, STRIPE, BOOT, SOLE, LACE)) & (z < 0.98)) | (z < 0.5))
    allow(legs, "hips")
    allow(legs & (x > -0.06), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.06), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs & (np.isin(part, (OVERALL, STRAP, BELT)) | ((part == TEE) & (np.abs(x) < 0.37))) & (np.abs(x) < 0.42)
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.18) & (z > 1.4), "shoulder.L")
    allow(torso & (x < -0.18) & (z > 1.4), "shoulder.R")
    arms = bp & ~legs & ~torso
    allow(arms & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (z > 1.5), "chest")
    return A, rig


WALK = dict(stride=1.1, stance=0.62, foot_x=0.24, lift=0.075, bob=0.03, drop=0.07, sway=0.07, roll=7.0, yaw=9.0, counter=1.4,
            lean=4.0, toe_off=12.0, toe_out=10.0, swing_point=6.0)
RUN = dict(stride=1.7, stance=0.42, foot_x=0.22, lift=0.15, bob=0.05, drop=0.10, sway=0.05, roll=6.0, yaw=11.0, counter=1.5,
           lean=12.0, toe_off=22.0, toe_out=8.0, swing_point=14.0, spine_lean=5.0)
BACK = 0.12        # the walk centres the ball of the foot under the hips: shift the hips back over the ankles


def motions(rig):
    """his clips: walk (a heavy lumber: wide planted steps, the body rolling over each foot and twisting, the free arm swinging wide, the toolbox
    swinging from a stiff arm, the head low and forward), run (a pounding charge), idle (heavy breathing, a look round, a roll of the shoulders)"""
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
        s2 = math.sin(2 * TAU * u - 0.6)
        p.rot("upper_arm.R", -(30.0 if run else 16.0) * c, 0, -(6.0 if run else 4.0) - 3.0 * s2)
        p.rot("forearm.R", -(55.0 if run else 14.0) - (12.0 if run else 6.0) * max(0.0, c), 0, 0)
        p.rot("upper_arm.L", (10.0 if run else 4.0) * c, 0, 3.0)
        p.rot("forearm.L", -(20.0 if run else 3.0), 0, 0)
        p.world["box"] = R(-(18.0 if run else 7.0) * math.cos(TAU * u - 0.9), 2.5 * math.sin(TAU * u), 0)
        p.rot("shoulder.R", 0, 0, 3.0 * c)
        p.rot("shoulder.L", 0, 0, -2.0 * c)
        p.rot("chest", (6.0 if run else 2.0), 0, 0)
        p.rot("neck", (6.0 if run else 3.0) + 1.5 * s2, 0, 0)
        p.world["head"] = R((3.0 if run else -1.0) + 1.5 * s2, 2.0 * math.sin(TAU * u), -3.0 * math.sin(TAU * u))
        fl = (5.0 if run else 3.0) * math.sin(2 * TAU * u - 1.4)
        p.rot("ear.L", 0, -fl, 0)
        p.rot("ear.R", 0, fl, 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        br = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.25, -0.15, 0.0)), 12.0), "R": (Vector((-0.25, -0.13, 0.0)), -14.0)},
              hip_shift=(0.02 * w, 0.0, -0.04 + 0.005 * br), roll=-2.0 * w, yaw=2.5 * w)
        # a shoulder roll and neck crack around 2.4-3.4 s, a slow look about before and after
        sr = ease((t - 2.3) / 0.4) * (1.0 - ease((t - 3.4) / 0.5))
        ph = TAU * (t - 2.3) / 1.1
        p.rot("spine", 1.5 * br, 0, 0)
        p.rot("chest", 2.0 * br - 3.0 * sr * math.sin(ph), 0, 0)
        p.rot("shoulder.L", 0, 0, 6.0 * sr * math.cos(ph))
        p.rot("shoulder.R", 0, 0, -6.0 * sr * math.cos(ph))
        look = 18.0 * (ease((t - 0.4) / 0.9) - ease((t - 1.8) / 0.6)) - 14.0 * (ease((t - 4.0) / 0.8) - ease((t - 5.4) / 0.5))
        p.world["head"] = R(-4.0 * sr + 1.0 * br, 12.0 * sr * math.sin(ph * 0.5), look)
        p.rot("upper_arm.R", 2.0 * br, 0, -3.0 - 1.5 * br)
        p.rot("forearm.R", -10.0 - 4.0 * sr, 0, 0)
        p.rot("upper_arm.L", 1.0 * br, 0, 2.0)
        p.world["box"] = R(1.0 * br, 0, 0)
        p.rot("ear.L", 0, -3.0 * br, 0)
        p.rot("ear.R", 0, 3.0 * br, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
