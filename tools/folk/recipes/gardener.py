## FOINT CITY townsfolk: the gardener. A small wrinkly lavender-pink old fellow with a sly grin, two short antennae and pointed ears, a wide straw hat pushed far back like a halo, floral shirt, green work vest with pens, patched brown trousers, muddy rubber boots. Free hands (the concept's shears and plant pot are dropped).
# Concept: the user's sheet, image 4 top left (F:/prog-godot-cache/folk/refs/4.webp). Measured off it: 1.45 m to the hat brim's top edge; the head 0.36 m wide at the
# cheeks (nearly the shoulders' width) and only 0.27 m tall; ears out to 0.56 m across; short legs (crotch at 0.48); the brim about 0.72 m across, its plane leaning
# back about 50 degrees so it rings the face. Rest pose = his slight stoop with the arms hanging loose, a little bowed out.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

F32 = np.float32

HEIGHT = 1.45
REF = ("4.webp", (80, 3, 370, 388))

(SKIN, EYE, TOOTH, MOUTH, ANT, GOLD, PEARL, HAT, PETAL, PETAL2, FCENTRE, LEAF, SHIRT, VEST, BELT, TROUSERS, PATCH, RAG, BOOT, SOLE,
 PEN_S, PEN_O, PEN_R, PEN_Y, BUTTON) = range(1, 26)
COLOURS = {
    SKIN: ((0.62, 0.36, 0.56), 0.55, 0.0),
    EYE: ((0.30, 0.16, 0.07), 0.2, 0.0),
    TOOTH: ((0.86, 0.80, 0.58), 0.4, 0.0),
    MOUTH: ((0.20, 0.04, 0.06), 0.6, 0.0),
    ANT: ((0.70, 0.68, 0.62), 0.4, 0.0),
    GOLD: ((0.90, 0.66, 0.26), 0.3, 1.0),
    PEARL: ((0.92, 0.88, 0.80), 0.2, 0.0),
    HAT: ((0.66, 0.46, 0.20), 0.8, 0.0),
    PETAL: ((0.90, 0.40, 0.62), 0.6, 0.0),
    PETAL2: ((0.96, 0.52, 0.12), 0.6, 0.0),
    FCENTRE: ((0.94, 0.78, 0.18), 0.6, 0.0),
    LEAF: ((0.22, 0.42, 0.14), 0.6, 0.0),
    SHIRT: ((0.88, 0.80, 0.66), 0.8, 0.0),
    VEST: ((0.32, 0.38, 0.16), 0.85, 0.0),
    BELT: ((0.32, 0.18, 0.09), 0.5, 0.0),
    TROUSERS: ((0.36, 0.22, 0.14), 0.85, 0.0),
    PATCH: ((0.55, 0.33, 0.28), 0.85, 0.0),
    RAG: ((0.80, 0.72, 0.58), 0.85, 0.0),
    BOOT: ((0.30, 0.32, 0.22), 0.4, 0.0),
    SOLE: ((0.42, 0.30, 0.18), 0.6, 0.0),
    PEN_S: ((0.75, 0.75, 0.78), 0.3, 1.0),
    PEN_O: ((0.92, 0.36, 0.10), 0.4, 0.0),
    PEN_R: ((0.60, 0.10, 0.20), 0.3, 0.0),
    PEN_Y: ((0.95, 0.75, 0.15), 0.4, 0.0),
    BUTTON: ((0.40, 0.30, 0.18), 0.4, 0.0),
}

# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; the figure faces -Y)
HEAD_C = v3((0.0, 0.012, 1.195))
HEAD_RAD = (0.178, 0.13, 0.13)
EYE_C = v3((0.095, -0.112, 1.19))
EYE_R = 0.040
EYE_FWD = v3((0.16, -1.0, 0.0)) / np.linalg.norm((0.16, -1.0, 0.0))
LID_PT = EYE_C + v3((0.0, 0.0, 0.006))
LID_N = v3((-0.10, 0.0, -1.0)) / np.linalg.norm((-0.10, 0.0, -1.0))     # the heavy upper lid stops on this plane, drooping to the outer corner
LOW_Z = EYE_C[2] - 0.028                                                 # the puffy lower lid's edge: a sly squint between
EAR_ROOT = v3((0.17, 0.004, 1.165))
EAR_U = v3((1.0, 0.16, -0.12)) / np.linalg.norm((1.0, 0.16, -0.12))      # root to tip
ANT_PTS = [((0.06, -0.112, 1.243), 0.0092), ((0.071, -0.126, 1.283), 0.0078), ((0.089, -0.132, 1.314), 0.0066), ((0.114, -0.126, 1.33), 0.006)]
HAT_C = v3((0.0, 0.035, 1.175))
HAT_R = rot(rx=-50.0, ry=-6.0)               # the hat's local Z (up) leans back 50 degrees and a little to his right
HAT_U = HAT_R[:, 2]
BRIM = 0.372
CROWN = 0.20
MOUTH_X = 0.13                                # the grin's corners
MOUTH_Z = 1.112

NECK0 = v3((0.0, 0.008, 0.905))
NECK1 = v3((0.0, -0.045, 1.07))
SHOULDER = v3((0.172, 0.03, 0.885))
ELBOW = v3((0.246, 0.05, 0.70))
WRIST = v3((0.266, -0.012, 0.548))
CUFF = ELBOW + (WRIST - ELBOW) * 0.32
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))       # hangs along the forearm, thumb forward
HIP = v3((0.09, 0.02, 0.53))
KNEE = v3((0.108, -0.016, 0.31))
ANKLE = v3((0.113, 0.025, 0.085))
BUNCH = v3((0.112, 0.02, 0.268))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def prism(poly_xz, y0=-0.5, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from y0 to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def side_prism(poly_yz, x0, x1):
    """a side-view outline (y, z) pushed through from x0 to x1"""
    return Slab(((x0 + x1) * 0.5, 0, 0), poly_yz, (x1 - x0) * 0.5, R=np.array([[0, 0, 1], [1, 0, 0], [0, 1, 0]], np.float32))


def probe(shape, x, z, y0=-0.45, y1=0.35, step=0.0015):
    """the first surface met coming from the front (-Y) along the line at (x, z)"""
    ys = np.arange(y0, y1, step, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    i = int(np.argmax(d < 0))
    if d[i] >= 0 or i == 0:
        return float(y1)
    return float(ys[i - 1] + (ys[i] - ys[i - 1]) * d[i - 1] / (d[i - 1] - d[i]))


def on(shape, x, z, inset=0.0):
    y = probe(shape, x, z)
    if y >= 0.34:
        raise ValueError("no surface at x %.3f z %.3f" % (x, z))
    return v3((x, y + inset, z))


class Bounded(Shape):
    """the child with a tighter box than its own (a clipped layer of the whole body, a Slab): unions skip it outside the box"""
    def __init__(self, child, lo, hi):
        self.child = child
        self.lo, self.hi = v3(lo), v3(hi)
        self.part = child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.child.eval(P)[0]


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


# ---------------------------------------------------------------------------------------------------- the head
class Local(Shape):
    """a Bump that only evaluates fn inside a box (lo, hi): rings round a neck, a lip's roll"""
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


def skull():
    """the bare head: a broad cranium and cheekbones (the widest of him), the lower face tapering in a V to a small pointed chin"""
    return Union([
        Ellipsoid(HEAD_C, HEAD_RAD),                                           # cranium
        Ellipsoid((0.0, -0.068, 1.185), (0.176, 0.08, 0.09)),                 # the broad front of the face the eyes sit in
        Mirror(Ellipsoid((0.124, -0.05, 1.165), (0.07, 0.075, 0.055))),      # cheekbones, the widest of him
        Ellipsoid((0.0, -0.076, 1.118), (0.155, 0.08, 0.06)),                 # the grinning lower face
        Ellipsoid((0.0, -0.098, 1.07), (0.09, 0.062, 0.045)),
        Ellipsoid((0.0, -0.122, 1.034), (0.035, 0.034, 0.027)),               # the pointed chin
    ], k=0.045, part=SKIN)


def face_shape():
    """the head without mouth or creases: skull, brows, heavy lids, bags, grin-bunched cheeks, the nose"""
    sk = skull()
    lid = Clip(Ellipsoid(EYE_C + v3((-0.002, -0.001, 0.002)), (0.0445, 0.0445, 0.045), part=SKIN), [Half(LID_PT, LID_N)], k=0.007)
    lower = Clip(Ellipsoid(EYE_C + v3((0, -0.002, -0.002)), (0.0445, 0.044, 0.044), part=SKIN), [Half(v3((0, 0, LOW_Z)), (0.0, 0.0, 1.0))], k=0.006)
    brow = Ellipsoid(EYE_C + v3((-0.002, 0.004, 0.034)), (0.042, 0.024, 0.015), part=SKIN)       # the brow's padding over the lid
    bag = Ellipsoid(EYE_C + v3((0.006, -0.006, -0.040)), (0.042, 0.02, 0.014), part=SKIN)      # the bag under the eye
    apple = Ellipsoid((0.098, -0.128, 1.142), (0.05, 0.03, 0.03), part=SKIN)                  # the cheek bunched up by the grin
    face = Union([sk, Mirror(lid), Mirror(lower), Mirror(brow), Mirror(bag), Mirror(apple)], k=0.013)
    # the nose: short, broad and bulbous: a soft bridge from between the eyes, a round tip, flared wings
    nose = Union([
        RoundCone((0, -0.146, 1.198), (0, -0.162, 1.178), 0.018, 0.021),
        Ellipsoid((0, -0.172, 1.168), (0.027, 0.023, 0.022)),
        Mirror(Ellipsoid((0.028, -0.158, 1.157), (0.018, 0.016, 0.014))),
    ], k=0.013, part=SKIN)
    face = Union([face, nose], k=0.012)
    nostrils = Mirror(Ellipsoid((0.0155, -0.173, 1.1505), (0.0066, 0.008, 0.005), R=rot(rx=30, rz=-20), part=SKIN))
    face = Cut(face, [nostrils], k=0.002)
    return face


def ears():
    u = EAR_U
    vv = v3((0, 0, 1)) - u * u[2]
    vv /= np.linalg.norm(vv)
    n = np.cross(u, vv)                    # points forward: the ear's open side
    R = np.stack([u, vv, n], 1)
    poly = [(-0.03, 0.05), (0.02, 0.053), (0.075, 0.04), (0.125, 0.014), (0.158, -0.006), (0.115, -0.02), (0.058, -0.035), (0.0, -0.052), (-0.03, -0.052)]
    plate = Slab(EAR_ROOT, poly, 0.0075, rr=0.006, R=R, part=SKIN)
    cup = Ellipsoid(EAR_ROOT + u * 0.064 + vv * 0.004 + n * 0.012, (0.058, 0.025, 0.0085), R=R, part=SKIN)
    ear = Cut(plate, [cup], k=0.006)
    return Mirror(ear)


EARRING = v3((0.178, -0.014, 1.104))


def earrings():
    hook = Torus(EARRING, 0.0075, 0.0028, Rm=rot(ry=90), part=GOLD)
    cap = Sphere(EARRING + v3((0, 0, -0.013)), 0.0064, part=GOLD)
    pearl = Sphere(EARRING + v3((0, -0.001, -0.031)), 0.017, part=PEARL)
    return Mirror(Union([hook, cap, pearl], k=0.0))


def mouth_z(x):
    return MOUTH_Z + 0.030 * (np.abs(x) / MOUTH_X) ** 2


def mouth_curve(n=19):
    xs = np.linspace(-MOUTH_X, MOUTH_X, n)
    return [(float(x), float(mouth_z(x))) for x in xs]


def head():
    face = face_shape()
    face = Union([face, ears()], k=0.012)
    # the neck: thin and sinewy, jutting the head forward; tendons down its front
    neck = Union([RoundCone(NECK0, NECK1, 0.052, 0.045, part=SKIN),
                  Mirror(RoundCone((0.027, -0.035, 0.935), (0.022, -0.088, 1.04), 0.0088, 0.0082, part=SKIN))], k=0.012)
    face = Union([face, neck], k=0.025)
    base = face
    # the grin's lower lip rolled out a little under the slit
    lip = [on(base, x, mouth_z(x)) + v3((0, 0.006, -0.009)) for x in np.linspace(-0.085, 0.085, 9)]
    face = Union([face, loft([(p, 0.0075 * (1.0 - 0.5 * abs(p[0]) / 0.085)) for p in lip], part=SKIN, k=0.004)], k=0.008)
    base = face
    # wrinkles: smile folds round the grin, crow's feet, forehead lines, the bags' crease, under the lip, the neck's rings
    fold = [on(base, x, z, 0.002) for x, z in ((0.042, 1.170), (0.08, 1.160), (0.122, 1.156), (0.148, 1.138), (0.15, 1.11), (0.128, 1.086))]
    crow = [[on(base, 0.148, 1.19), on(base, x, z)] for x, z in ((0.168, 1.204), (0.172, 1.19), (0.166, 1.174))]
    brow_l = [[on(base, x, z, 0.001) for x, z in ((0.0, zz), (0.035, zz + 0.002), (0.07, zz + 0.007))] for zz in (1.252, 1.268)]
    bag_l = [on(base, x, z, 0.001) for x, z in ((0.068, 1.150), (0.10, 1.141), (0.132, 1.150))]
    chin_l = [on(base, x, z, 0.001) for x, z in ((0.0, 1.077), (0.03, 1.08), (0.058, 1.088))]
    face = Crease(face, fold, 0.007, -0.0036)
    face = Crease(face, [p + v3((-0.004, -0.004, 0.006)) for p in fold[:4]], 0.010, 0.0022)
    for c in crow:
        face = Crease(face, c, 0.004, -0.0009)
    for b in brow_l:
        face = Crease(face, b, 0.0045, -0.0012)
    face = Crease(face, bag_l, 0.005, -0.0018)
    face = Crease(face, chin_l, 0.006, -0.002)

    def neck_rings(P):
        return np.clip(1.0 - np.abs(np.sin((P[:, 2] - 0.93) * 105.0)) * 2.2, 0.0, 1.0)
    face = Local(face, neck_rings, -0.0011, (-0.1, -0.2, 0.95), (0.1, -0.02, 1.03))
    # the grin: a slit along the curve on the face, the dark mouth behind it, the upper teeth showing in its middle
    curve = mouth_curve()
    pts = [on(base, x, z) for x, z in curve]
    rad = [0.0062 * (1.0 - 0.6 * (abs(x) / MOUTH_X) ** 2) for x, _ in curve]
    slit = loft([(p + v3((0, 0.0035, 0)), r) for p, r in zip(pts, rad)], part=SKIN, k=0.002)
    face = Cut(face, [slit], k=0.0022)
    back = loft([(p + v3((0, 0.0125, 0)), r * 1.15) for p, r in zip(pts, rad)], part=MOUTH, k=0.002)
    teeth = []
    for x, w in ((-0.054, 0.0050), (-0.040, 0.0056), (-0.025, 0.0058), (-0.010, 0.0063), (0.005, 0.0061), (0.020, 0.0058), (0.050, 0.0050)):
        p = on(base, x, mouth_z(x))
        teeth.append(Box(p + v3((0, 0.0048, 0.0024)), (w, 0.0032, 0.0044), rr=0.0016, part=TOOTH))
    ball = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    ant = Mirror(Union([loft([(v3(p), r) for p, r in ANT_PTS], part=ANT, k=0.004), Sphere(ANT_PTS[-1][0], 0.007, part=ANT)], k=0.003))
    face = Union([face, ant], k=0.006)
    return Union([face, back, ball] + teeth, k=0.0)


# ---------------------------------------------------------------------------------------------------- the hat
def flower(c, n, d0, size, petal_part):
    """five petals round a raised centre, lying in the plane of normal n"""
    n = v3(n) / np.linalg.norm(n)
    d0 = v3(d0) - n * float(v3(d0) @ n)
    d0 /= np.linalg.norm(d0)
    parts = [Sphere(v3(c) + n * 0.004, size * 0.3, part=FCENTRE)]
    for k in range(5):
        a = k * np.pi * 2 / 5
        d = d0 * np.cos(a) + np.cross(n, d0) * np.sin(a)
        R = np.stack([d, np.cross(n, d), n], 1)
        parts.append(Ellipsoid(v3(c) + d * size * 0.62, (size * 0.6, size * 0.4, 0.005), R=R, part=petal_part))
    return Union(parts, k=0.003)


def leaf(c, d, n, size):
    d = v3(d) / np.linalg.norm(d)
    n = v3(n) - d * float(v3(n) @ d)
    n /= np.linalg.norm(n)
    R = np.stack([d, np.cross(n, d), n], 1)
    return Ellipsoid(v3(c), (size, size * 0.38, 0.0042), R=R, part=LEAF)


def hat():
    e1, e2, u = HAT_R[:, 0], HAT_R[:, 1], HAT_U
    brim = CappedCone(HAT_C - u * 0.0075, HAT_C + u * 0.0075, BRIM, BRIM, rr=0.0065, part=HAT)
    roll = Torus(HAT_C + u * 0.002, BRIM - 0.004, 0.0125, Rm=HAT_R, part=HAT)
    crown = Clip(Ellipsoid(HAT_C, (CROWN, CROWN, 0.165), R=HAT_R, part=HAT), [Half(HAT_C, -u)], k=0.0)
    # a gentle wave in the wide brim
    hatc = Union([brim, roll, crown], k=0.03, part=HAT)

    def weave(P):
        q = (P - HAT_C) @ HAT_R
        rho = np.sqrt(q[:, 0] ** 2 + q[:, 1] ** 2)
        th = np.arctan2(q[:, 2] / 0.165, rho / CROWN)
        s = np.where(rho > CROWN + 0.01, rho, th * 0.17)
        return 0.5 - 0.5 * np.cos(2 * np.pi * s / 0.021)
    hatc = Bump(hatc, weave, 0.0016)
    wave = lambda P: noise3(P, 0.09)
    hatc = Bump(hatc, wave, 0.004)
    # flowers tucked over the rim at his right, up (the concept shows them face on, straddling the edge); leaves fanning out past it
    def at(psi, rho, lift):
        a = np.radians(psi)
        d = e1 * np.cos(a) - e2 * np.sin(a)          # psi 90 = the brim's top (front-up)
        return HAT_C + d * rho - u * lift, d
    bits = []
    for psi, rho, size, pp in ((126.0, BRIM - 0.03, 0.05, PETAL), (150.0, BRIM - 0.02, 0.042, PETAL), (106.0, BRIM - 0.012, 0.034, PETAL2), (167.0, BRIM - 0.035, 0.03, PETAL2)):
        c, d = at(psi, rho, 0.02)
        bits.append(flower(c, -u * 0.85 + d * 0.45, np.cross(u, d), size, pp))
    for psi, rho, ang in ((116.0, BRIM + 0.02, 30.0), (138.0, BRIM + 0.025, -25.0), (160.0, BRIM + 0.02, 15.0), (176.0, BRIM + 0.0, -40.0), (96.0, BRIM + 0.015, 35.0)):
        c, d = at(psi, rho, 0.008)
        side = np.cross(u, d)
        a = np.radians(ang)
        bits.append(leaf(c, d * np.cos(a) + side * np.sin(a), -u + d * 0.3, 0.036))
    deco = Union(bits, k=0.002)
    # where the head goes into the hat, the hat is hollow (saves triangles, nothing shows there)
    inner = Ellipsoid((0.0, 0.0, 1.19), (0.155, 0.13, 0.12))
    return Cut(Union([hatc, deco], k=0.0), [inner], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body
def core():
    """the shirt's body: a short chest on a rounded old back, a soft belly, the seat (the vest and the trousers are this grown)"""
    return Union([
        Ellipsoid((0, 0.012, 0.80), (0.134, 0.104, 0.125)),
        Ellipsoid((0, 0.052, 0.862), (0.118, 0.07, 0.07)),
        Mirror(Ellipsoid((0.104, 0.026, 0.868), (0.078, 0.068, 0.045))),
        Ellipsoid((0, -0.004, 0.67), (0.14, 0.116, 0.10)),
        Ellipsoid((0, 0.016, 0.57), (0.152, 0.112, 0.086)),
    ], k=0.06, part=SHIRT)


def sleeve():
    s = loft([(SHOULDER, 0.06), (ELBOW, 0.054), (CUFF, 0.05)], part=SHIRT, k=0.012)
    d = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    roll = Torus(CUFF - d * 0.006, 0.045, 0.015, Rm=basis(d, v3((0, 1, 0))), part=SHIRT)
    s = Clip(s, [Half(CUFF, d)], k=0.003)
    return Union([s, roll], k=0.006)


def hand_hang():
    """a loose hanging hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): four chubby fingers, a little curled"""
    palm = Ellipsoid((0.0, 0.0, -0.042), (0.017, 0.036, 0.043), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.03, 0.027, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.025, -0.0085, 0.0085, 0.025):
        L = 1.0 - abs(f) * 5
        pts = [((0.0, f, -0.07), 0.0108), ((-0.004, f * 1.05, -0.07 - 0.026 * L), 0.0102), ((-0.014, f * 1.08, -0.09 - 0.026 * L), 0.0094), ((-0.026, f * 1.1, -0.098 - 0.022 * L), 0.0086)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
    parts.append(loft([(v3((-0.008, -0.03, -0.022)), 0.0125), (v3((-0.02, -0.046, -0.052)), 0.011), (v3((-0.031, -0.042, -0.075)), 0.0095)], part=SKIN, k=0.004))
    return Union(parts, k=0.009)


def arm():
    s = sleeve()
    fore = RoundCone(CUFF, WRIST, 0.039, 0.031, part=SKIN)
    return s, Union([fore, place(Move(hand_hang(), R=np.eye(3, dtype=np.float32) / 1.15), WRIST, HAND)], k=0.01)


def legs_core():
    return Mirror(loft([(HIP, 0.098), (KNEE, 0.088), (BUNCH, 0.094)], k=0.03))


def boot():
    shaft = CappedCone((0.105, 0.028, 0.03), (0.105, 0.022, 0.236), 0.071, 0.076, rr=0.012)
    foot = loft([(v3((0.105, 0.06, 0.054)), 0.055), (v3((0.108, -0.04, 0.054)), 0.06), (v3((0.112, -0.128, 0.05)), 0.054)], k=0.02)
    b = Union([shaft, foot], k=0.035, part=BOOT)
    b = Clip(b, [Half((0, 0, 0.016), (0, 0, -1))], k=0.004)
    band = Clip(Inflate(CappedCone((0.105, 0.028, 0.03), (0.105, 0.022, 0.236), 0.071, 0.076, rr=0.012), 0.011, part=BOOT),
                [Half((0, 0, 0.198), (0, 0, -1)), Half((0, 0, 0.240), (0, 0, 1))], k=0.003)
    sole_shape = Union([foot, CappedCone((0.105, 0.028, 0.02), (0.105, 0.028, 0.06), 0.071, 0.071)], k=0.03)
    sole = Clip(Inflate(sole_shape, 0.007, part=SOLE), [Half((0, 0, 0.034), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)

    def lugs(P):
        return (np.sin(P[:, 1] * 260.0) > 0.2) * (P[:, 2] < 0.012)
    sole = Bump(sole, lugs, -0.0035)
    return Union([b, band, sole], k=0.0)


def body():
    co = core()
    s, h = arm()
    # the vest: the shirt grown, open down the front, armholes, a neck hole, the hem at the seat; patch pockets and flaps proud of it
    vest = Inflate(co, 0.017, part=VEST)
    vest = Clip(vest, [Half((0, 0, 0.50), (0, 0, -1))], k=0.004)
    vest = Cut(vest, [prism([(-0.06, 1.02), (0.06, 1.02), (0.04, 0.84), (0.052, 0.48), (-0.052, 0.48), (-0.04, 0.84)]),
                      Mirror(Ellipsoid((0.19, 0.026, 0.835), (0.05, 0.10, 0.105))),
                      Ellipsoid((0, 0.012, 0.975), (0.068, 0.07, 0.07))], k=0.006)
    pockets = []
    for x0, x1, z0, z1 in ((0.042, 0.112, 0.755, 0.83), (0.046, 0.132, 0.525, 0.625)):
        pockets.append(Mirror(prism([(x0, z0), (x1, z0), (x1, z1), (x0, z1)])))
    pocket = Bounded(Clip(Inflate(co, 0.023, part=VEST), [Union(pockets)], k=0.003), (-0.15, -0.2, 0.5), (0.15, 0.0, 0.85))
    flaps = Clip(Inflate(co, 0.028, part=VEST), [Union([Mirror(prism([(0.038, 0.808), (0.116, 0.808), (0.116, 0.842), (0.077, 0.835), (0.038, 0.842)])),
                                                        prism([(0.042, 0.606), (0.136, 0.606), (0.136, 0.642), (0.089, 0.635), (0.042, 0.642)])])], k=0.003)
    flaps = Bounded(flaps, (-0.15, -0.2, 0.58), (0.15, 0.0, 0.86))
    vest = Union([vest, pocket, flaps], k=0.0, part=VEST)
    # the shirt: the body, its sleeves set in smoothly, a pointed collar lying on the vest
    shirt = Union([co, s, Move(s, R=FLIP)], k=0.02, part=SHIRT)
    collar = Clip(Cut(Inflate(co, 0.026, part=SHIRT), [Inflate(co, 0.018)], k=0.002),
                  [Mirror(prism([(0.004, 0.905), (0.052, 0.95), (0.074, 0.93), (0.05, 0.86)]))], k=0.004)
    collar = Bounded(collar, (-0.09, -0.2, 0.84), (0.09, 0.05, 0.97))
    neckband = Clip(Cut(RoundCone(NECK0 + v3((0, 0, 0.02)), NECK1, 0.066, 0.059, part=SHIRT), [RoundCone(NECK0, NECK1, 0.05, 0.043)]),
                    [Half((0, 0, 0.978), (0, 0.3, 1)), Half((0, 0, 0.88), (0, 0, -1))], k=0.004)
    # trousers: the seat grown and the legs, bunched over the boots; a patch on the right knee and one on the left seat
    tro = Union([Clip(Inflate(co, 0.006), [Half((0, 0, 0.672), (0, 0, 1))]), legs_core()], k=0.045, part=TROUSERS)
    tro = Clip(tro, [Half((0, 0, 0.214), (0, 0, -1))], k=0.004)

    def folds(P):
        return noise3(P * np.array([1.0, 1.0, 0.35], np.float32), 0.03) * (P[:, 2] < 0.5)
    tro = Bump(tro, folds, 0.0035)
    patch = Clip(Inflate(Union([Clip(Inflate(co, 0.006), [Half((0, 0, 0.672), (0, 0, 1))]), legs_core()], k=0.045), 0.0045, part=PATCH),
                 [Union([prism([(-0.145, 0.30), (-0.07, 0.295), (-0.068, 0.375), (-0.142, 0.382)]),
                         side_prism([(0.02, 0.50), (0.11, 0.49), (0.115, 0.56), (0.03, 0.575)], 0.02, 0.2)])], k=0.002)
    patch = Union([Bounded(patch, (-0.2, -0.2, 0.27), (0.0, 0.05, 0.4)), Bounded(patch, (0.0, 0.0, 0.47), (0.22, 0.15, 0.6))])
    belt = Bounded(Clip(Inflate(co, 0.012, part=BELT), [Half((0, 0, 0.636), (0, 0, -1)), Half((0, 0, 0.672), (0, 0, 1))], k=0.002), (-0.2, -0.2, 0.62), (0.2, 0.2, 0.69))
    # the rag tucked in at his left hip, hanging over the trousers
    rag_core = Bump(Union([co, legs_core()], k=0.045), lambda P: np.sin(P[:, 1] * 160.0 + P[:, 2] * 20.0) * (P[:, 0] > 0.1), 0.004)
    rag = Clip(Inflate(rag_core, 0.0125, part=RAG),
               [side_prism([(-0.085, 0.575), (0.0, 0.575), (0.012, 0.44), (-0.01, 0.425), (-0.03, 0.445), (-0.055, 0.428), (-0.08, 0.45)], 0.07, 0.3)], k=0.004)
    rag = Bounded(rag, (0.07, -0.11, 0.4), (0.3, 0.04, 0.6))
    boots = Mirror(boot())
    return Union([shirt, vest, collar, neckband, tro, patch, belt, rag, boots, h, Move(h, R=FLIP)], k=0.0)


def kit_bits(bd):
    """small hard things: the pens in his right lower pocket, buttons, the belt buckle"""
    pens = []
    for x, tilt, top, part in ((-0.122, -9.0, 0.676, PEN_S), (-0.103, -3.0, 0.668, PEN_O), (-0.084, 4.0, 0.682, PEN_R), (-0.064, 10.0, 0.662, PEN_Y)):
        y = probe(bd, x, 0.60) + 0.012
        a = np.radians(tilt)
        d = v3((np.sin(a), 0.08, np.cos(a)))
        base = v3((x, y, 0.575))
        pens.append(RoundCone(base, base + d * (top - 0.575), 0.0058, 0.0055, part=part))
        if part in (PEN_O, PEN_Y):           # pencils: a sharpened tip
            tip = base + d * (top - 0.575)
            pens.append(RoundCone(tip, tip + d * 0.014, 0.0052, 0.0015, part=PEN_S))
        else:                                # pens: a clip
            pens.append(Box(base + d * (top - 0.585) + v3((0, -0.0065, 0)), (0.0018, 0.0012, 0.012), rr=0.0008, part=PEN_S))
    buttons = []
    for x, z in ((0.077, 0.826), (-0.077, 0.826), (0.089, 0.624)):
        buttons.append(Sphere(on(bd, x, z, 0.0025), 0.0055, part=BUTTON))
    for z in (0.79, 0.735, 0.69):
        buttons.append(Sphere(on(bd, 0.0, z, 0.0015), 0.0042, part=BUTTON))
    by = probe(bd, 0.0, 0.654)
    buckle = Cut(Box((0, by - 0.002, 0.654), (0.022, 0.004, 0.019), rr=0.003, part=GOLD), [Box((0.004, by - 0.006, 0.654), (0.011, 0.01, 0.010), rr=0.002)], k=0.0)
    prong = Box((0.0, by - 0.005, 0.654), (0.0045, 0.002, 0.0018), rr=0.0008, part=GOLD)
    return Union(pens + buttons + [buckle, prong, earrings()], k=0.0)


def pieces():
    import os
    only = os.environ.get("FOLK_ONLY", "")          # quick looks while sculpting: FOLK_ONLY=head builds just that piece, FOLK_FAST=1 a coarser clay
    s = 1.5 if os.environ.get("FOLK_FAST") else 1.0
    if only == "head":
        return [("head", head(), 0.0018 * s)]
    if only == "face":
        return [("head", head(), 0.0018 * s), ("hat", hat(), 0.0024 * s)]
    bd = body()
    return [("head", head(), 0.0018 * s), ("hat", hat(), 0.0024 * s), ("body", bd, 0.0035 * s), ("kit", kit_bits(bd), 0.0018 * s)]


# ---------------------------------------------------------------------------------------------------- paint
def _hash(ix, iy, iz):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF).astype(np.float32) / 65535.0


def flower_print(P, N, cell=0.06, size=0.021):
    """(inside 0..1, centre 0..1): five-petalled flowers scattered over the cloth, drawn in each vertex's tangent plane"""
    best = np.full(len(P), 1e3, np.float32)
    inside = np.zeros(len(P), np.float32)
    centre = np.zeros(len(P), np.float32)
    base = np.floor(P / cell).astype(np.int64)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                ci = base + np.array([dx, dy, dz])
                j = np.stack([_hash(ci[:, 0], ci[:, 1], ci[:, 2] + k * 7) for k in range(4)], 1)
                cen = (ci + 0.2 + 0.6 * j[:, :3]) * cell
                d = P - cen
                dist = np.linalg.norm(d, axis=1)
                take = dist < best
                if not take.any():
                    continue
                t = d - N * np.einsum("ij,ij->i", d, N)[:, None]
                a1 = np.cross(N, np.array([0.3, 0.5, 0.8], np.float32))
                a1 /= np.maximum(np.linalg.norm(a1, axis=1), 1e-6)[:, None]
                a2 = np.cross(N, a1)
                th = np.arctan2(np.einsum("ij,ij->i", t, a2), np.einsum("ij,ij->i", t, a1)) + j[:, 3] * 6.28
                r = np.linalg.norm(t, axis=1)
                sz = size * (0.75 + 0.5 * j[:, 0])
                rr = sz * (0.45 + 0.55 * np.abs(np.cos(2.5 * th)))
                inn = np.clip((rr - r) / 0.002, 0.0, 1.0)
                cc = np.clip((sz * 0.28 - r) / 0.0015, 0.0, 1.0)
                best = np.where(take, dist, best)
                inside = np.where(take, inn, inside)
                centre = np.where(take, cc, centre)
    return inside, centre


def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    z = P[:, 2]
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
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.broadcast_to(np.asarray(amt, np.float32), (int(m.sum()),))[:, None] if np.ndim(amt) == 0 else np.asarray(amt, np.float32)[m][:, None]], 1)

    # skin: lavender-pink, warmer on the cheeks and nose, deeper mauve down the neck and in the folds; mauve spots over the brow, cheeks and hands
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(202, 142, 174), (n, 3)).copy()
    cheek = np.exp(-(((Q[:, 0] - 0.10) / 0.04) ** 2 + ((z - 1.14) / 0.03) ** 2)) * (P[:, 1] < -0.08)
    nose = np.exp(-((Q[:, 0] / 0.03) ** 2 + ((z - 1.165) / 0.02) ** 2)) * (P[:, 1] < -0.15)
    sk = sk + (srgb(222, 132, 158) - sk) * (0.55 * np.clip(cheek + nose, 0, 1))[:, None]
    sk = sk + (srgb(162, 104, 146) - sk) * (smooth(1.06, 0.92, z) * 0.55 * (z > 0.85))[:, None]
    sk *= (1.0 + 0.07 * mott)[:, None]
    sk *= (1.0 - 0.35 * c.cavity)[:, None]
    # the ears' insides darker and pinker
    inear = (Q[:, 0] > 0.17) & (z > 1.1) & (z < 1.23) & (c.N[:, 1] < -0.3)
    sk = np.where(inear[:, None], sk * np.array([0.92, 0.78, 0.86], np.float32), sk)
    # around the eyes: the lids a touch darker; inked lash lines along both lid edges, a crease over the upper lid
    de = Q - EYE_C
    r = np.linalg.norm(de, axis=1)
    pd = (Q - LID_PT) @ LID_N                   # < 0 on the upper lid
    lidm = (r < EYE_R + 0.012) & (pd < 0.0)
    sk = sk + (srgb(160, 96, 150) - sk) * (lidm * smooth(-0.03, -0.004, pd) * 0.5)[:, None]
    near = (r < EYE_R + 0.011) & (pd > -0.008) & (pd < 0.004) & (de[:, 1] < 0.012)
    c.draw(near & m, np.abs(pd + 0.0012), 0.0016)
    lowd = Q[:, 2] - LOW_Z
    nearl = (r < EYE_R + 0.009) & (np.abs(lowd) < 0.006) & (de[:, 1] < 0.0)
    c.draw(nearl & m, np.abs(lowd - 0.0008), 0.0009, 0.7)
    put(m, sk, 0.55, bump=0.15)
    face = m & (z > 1.0)
    spk(m, (138, 74, 128), 0.0)
    c.spk[face, 3] = (0.55 * smooth(1.13, 1.2, z[face]) + 0.4 * np.clip(cheek[face] * 2, 0, 1))
    hands = m & (z < 0.75)
    c.spk[hands, 3] = 0.35
    # the mouth: a crisp ink line along the slit's lips
    curve = mouth_curve(41)
    cx = np.array([p[0] for p in curve], np.float32)
    cz = np.array([p[1] for p in curve], np.float32)
    mz = np.interp(P[:, 0], cx, cz)
    md = np.abs(z - mz)
    nearm = m & (np.abs(P[:, 0]) < 0.135) & (md < 0.012) & (P[:, 1] < -0.09)
    c.draw(nearm, md - 0.0045 * (1.0 - (np.abs(P[:, 0]) / 0.13) ** 2), 0.0007, 0.75)
    lip = m & (np.abs(P[:, 0]) < 0.12) & (z < mz) & (z > mz - 0.012) & (P[:, 1] < -0.1)
    c.col[lip] *= np.array([0.95, 0.82, 0.88], np.float32)

    # eyes: a dark brown iris almost filling the slit, a gleam of yellowed white in the corners, an inked pupil, a glint
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    ang = np.arccos(np.clip(d @ EYE_FWD, -1, 1))
    ir = srgb(150, 92, 40) + (srgb(84, 44, 18) - srgb(150, 92, 40)) * smooth(0.12, 0.42, ang)[:, None]
    ir = ir + (srgb(222, 206, 168) - ir) * smooth(0.5, 0.56, ang)[:, None]
    pup = ang / 0.2
    c.draw(m, (pup - 1.0) * 0.2 * EYE_R, 0.0)
    up = d[:, 2]
    ir *= (1.0 - 0.45 * smooth(-0.15, 0.05, up))[:, None]
    gl = np.zeros(n, np.float32)
    for sx in (1.0, -1.0):
        ec = EYE_C * np.array([sx, 1.0, 1.0], np.float32)
        dd = P - ec
        dd /= np.maximum(np.linalg.norm(dd, axis=1), 1e-6)[:, None]
        side = (dd[:, 0] + 0.22) ** 2 + (dd[:, 2] + 0.2) ** 2
        gl = np.maximum(gl, smooth(0.01, 0.003, side) * (dd[:, 1] < -0.5))
    ir = ir + (srgb(255, 250, 236) - ir) * gl[:, None]
    put(m, ir, 0.08)

    put(c.mask(TOOTH), srgb(226, 208, 150) * (1.0 - 0.25 * c.cavity)[:, None], 0.35)
    put(c.mask(MOUTH), srgb(70, 22, 34), 0.6)
    m = c.mask(ANT)
    put(m, srgb(196, 188, 172) * (1.0 + 0.4 * c.wear)[:, None] * (1.0 - 0.06 * (np.sin(z * 900.0) > 0.6))[:, None], 0.35, bump=0.2)
    put(c.mask(GOLD), srgb(232, 176, 84) * (1.0 - 0.4 * c.cavity)[:, None], 0.25, metal=1.0, grain=1.0, bump=0.05)
    put(c.mask(PEARL), srgb(238, 230, 214), 0.16)

    # the straw hat: rows of plaited straw round the brim and up the crown, each plait a slightly different straw, inked joins; darker underneath
    m = c.mask(HAT)
    if m.any():
        q = (P - HAT_C) @ HAT_R
        rho = np.sqrt(q[:, 0] ** 2 + q[:, 1] ** 2)
        th = np.arctan2(q[:, 2] / 0.165, rho / CROWN)
        on_crown = (rho < CROWN + 0.01) & (q[:, 2] > 0.004)
        s = np.where(on_crown, th * 0.17, rho)
        row = np.floor(s / 0.021)
        phi = np.arctan2(q[:, 1], q[:, 0])
        circ = phi * np.where(on_crown, np.maximum(rho, 0.02), rho)
        blk = np.floor(circ / 0.03 + 0.5 * row)
        hv = _hash(row.astype(np.int64), blk.astype(np.int64), np.zeros(n, np.int64) + 3)
        st = srgb(224, 178, 102) + (srgb(186, 134, 70) - srgb(224, 178, 102)) * hv[:, None]
        st = st * (1.0 + 0.08 * mott)[:, None]
        under = q[:, 2] < -0.003
        st = np.where(under[:, None], st * 0.86, st)
        st = st * (1.0 - 0.45 * smooth(0.21, 0.16, rho) * under)[:, None]       # the crown's dark mouth round his head
        st *= (1.0 + 0.25 * c.wear)[:, None]
        put(m, st, 0.85, bump=0.7)
        rd = np.abs(s / 0.021 - np.round(s / 0.021)) * 0.021
        c.draw(m, rd, 0.0007, 0.5)
        bd_ = np.abs(circ / 0.03 + 0.5 * row - np.round(circ / 0.03 + 0.5 * row)) * 0.03
        c.draw(m & (rd > 0.002), bd_, 0.0005, 0.35)
    put(c.mask(PETAL), srgb(234, 128, 172) * (1.0 - 0.3 * c.cavity)[:, None], 0.55)
    put(c.mask(PETAL2), srgb(244, 146, 46) * (1.0 - 0.3 * c.cavity)[:, None], 0.55)
    put(c.mask(FCENTRE), srgb(244, 206, 70), 0.6, bump=0.6, grain=1.0)
    m = c.mask(LEAF)
    put(m, srgb(78, 128, 52) * (1.0 + 0.3 * c.wear)[:, None], 0.5)

    # the shirt: cream, a print of purple flowers with pale centres
    m = c.mask(SHIRT)
    if m.any():
        fi, fc = flower_print(P, c.N)
        sh = np.broadcast_to(srgb(232, 214, 184), (n, 3)).copy() * (1.0 + 0.04 * mott)[:, None]
        sh = sh + (srgb(150, 86, 168) - sh) * (fi * 0.92)[:, None]
        sh = sh + (srgb(214, 180, 214) - sh) * fc[:, None]
        put(m, sh, 0.85, bump=0.9)
    # the vest: olive canvas, rubbed paler on the edges, grimy low down; stitching round the pockets
    m = c.mask(VEST)
    vs = srgb(96, 108, 52) * (1.0 + 0.08 * mott)[:, None]
    vs = vs * (1.0 + 0.55 * c.wear)[:, None]
    vs = vs + (srgb(74, 66, 40) - vs) * (smooth(0.6, 0.5, z) * 0.5 * (0.6 + 0.4 * noise3(P, 0.02)))[:, None]
    put(m, vs, 0.9, bump=1.0)
    for x0, x1, z0, z1 in ((0.042, 0.112, 0.755, 0.83), (0.046, 0.132, 0.525, 0.625)):
        dx = np.minimum(np.abs(Q[:, 0] - x0), np.abs(Q[:, 0] - x1))
        dz = z - z0
        inb = (Q[:, 0] > x0 - 0.006) & (Q[:, 0] < x1 + 0.006) & (z > z0 - 0.006) & (z < z1 + 0.003) & (P[:, 1] < 0)
        dist = np.minimum(np.where((z > z0) & (z < z1), np.abs(dx - 0.0045), 1.0), np.where((Q[:, 0] > x0) & (Q[:, 0] < x1), np.abs(dz - 0.0045), 1.0))
        dash = (np.sin((Q[:, 0] + z) * 900.0) > -0.2).astype(np.float32)
        c.draw(m & inb, dist, 0.0006, 0.55 * dash)
    # trousers: brown twill, mud splashed up from the boots and at the knees; the patches pinker with big stitches
    m = c.mask(TROUSERS, PATCH)
    mud = np.clip(noise3(P, 0.025) * 0.6 + noise3(P, 0.009) * 0.4 + smooth(0.45, 0.22, z) * 0.9 - 0.35, 0.0, 1.0)
    tr = srgb(112, 74, 54) * (1.0 + 0.08 * mott)[:, None]
    tr = tr + (srgb(156, 112, 70) - tr) * (mud * 0.85)[:, None]
    tr *= (1.0 - 0.3 * c.cavity)[:, None]
    put(m, tr, 0.9, bump=1.0)
    spk(m, (150, 104, 62), smooth(0.4, 0.2, z) * 0.5)
    m = c.mask(PATCH)
    pa = srgb(160, 108, 96) * (1.0 + 0.06 * mott)[:, None]
    put(m, pa, 0.9, bump=1.0)
    pw = c.wear * m
    c.draw(m & (c.wear > 0.25), 1.0 - c.wear, 0.4, 0.0)
    m = c.mask(RAG)
    rg = srgb(214, 196, 162) * (1.0 + 0.08 * mott)[:, None]
    rg = rg + (srgb(150, 120, 84) - rg) * np.clip(noise3(P, 0.015) * 0.8, 0, 1)[:, None]
    put(m, rg, 0.9, bump=0.8)
    m = c.mask(BELT)
    put(m, srgb(96, 56, 32) * (1.0 + 0.6 * c.wear)[:, None], 0.5, bump=0.8, grain=1.0)
    # boots: dull olive rubber caked with orange mud, worst at the toes and the sole
    m = c.mask(BOOT, SOLE)
    bmud = np.clip(noise3(P, 0.02) * 0.7 + noise3(P, 0.007) * 0.5 + smooth(0.12, 0.0, z) * 0.6 - 0.15, 0.0, 1.0)
    bt = srgb(84, 90, 64) * (1.0 + 0.06 * mott)[:, None]
    bt = bt + (srgb(170, 124, 70) - bt) * (bmud * 0.9)[:, None]
    bt *= (1.0 + 0.35 * c.wear)[:, None]
    put(m, bt, 0.45 + 0.4 * bmud, bump=0.3)
    spk(m, (186, 136, 80), 0.6)
    m = c.mask(SOLE)
    c.col[m] *= 0.85
    put(c.mask(PEN_S), srgb(190, 192, 198), 0.25, metal=1.0)
    put(c.mask(PEN_O), srgb(230, 96, 30), 0.45)
    put(c.mask(PEN_R), srgb(150, 26, 60), 0.3)
    put(c.mask(PEN_Y), srgb(236, 190, 40), 0.45)
    put(c.mask(BUTTON), srgb(108, 82, 50), 0.35)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion
GAME = {
    "budget": {"head": 2800, "hat": 1300, "body": 4200, "kit": 1400},
    "density": {"head": 1.9, "hat": 1.0, "kit": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.62, "run": 0.98},
    "speed": 0.55,
    "look": ["head", "antenna.L", "antenna.R"], "neck": "neck",
    "look_pivot": (0.0, -0.045, 1.07),
    "radius": 0.34,
}
BALL = v3((0.11, -0.095, 0.0))       # the ball of his left boot


def rig_bones():
    from kit.rig import Bone, mirror
    f = np.array([-1, 1, 1], np.float32)
    a0, a1 = v3(ANT_PTS[0][0]), v3(ANT_PTS[-1][0])
    hand_end = WRIST - HAND[:, 2] * 0.09
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.02, 0.55), (0, 0.02, 0.66), "root", 0.13),
        Bone("spine", (0, 0.02, 0.66), (0, 0.025, 0.78), "hips", 0.12),
        Bone("chest", (0, 0.025, 0.78), (0, 0.02, 0.92), "spine", 0.12),
        Bone("neck", (0, 0.004, 0.92), NECK1, "chest", 0.045),
        Bone("head", NECK1, (0, -0.03, 1.32), "neck", 0.15),
        Bone("antenna.L", a0, a1, "head", 0.008),
        Bone("ear.L", EAR_ROOT, EAR_ROOT + EAR_U * 0.13, "head", 0.02),
        Bone("shoulder.L", (0.04, 0.025, 0.88), SHOULDER, "chest", 0.05),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.05),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.036),
        Bone("hand.L", WRIST, hand_end, "forearm.L", 0.03),
        Bone("thigh.L", HIP, KNEE, "hips", 0.085),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.072),
        Bone("foot.L", ANKLE, (0.112, -0.15, 0.03), "shin.L", 0.05),
    ])
    return bones


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for rigid vertices). piece: 0 head, 1 hat, 2 body, 3 kit"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    # head: rigid above the jaw; the neck bends from the collar; antennae and ears on their own bones
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & ((z > 1.085) | ((z > 1.01) & (y < -0.085)))] = ix["head"]
    for s, sd in ((1, "L"), (-1, "R")):
        am = hp & (part == ANT) & (s * x > 0)
        rig[am & (z > 1.255)] = ix["antenna." + sd]
        allow(am, "antenna." + sd)
        em = hp & (part == SKIN) & (s * x > 0.19) & (z > 1.1) & (z < 1.24)
        rig[em] = -1
        allow(em, "ear." + sd)
        rig[hp & (s * x > 0.218) & (part == SKIN) & (z > 1.1)] = ix["ear." + sd]
    # hat: on the head
    rig[piece == 1] = ix["head"]
    allow(piece == 1, "head")
    # small hard things: pens and lower buttons ride the hips' end of the vest, chest buttons the chest, the buckle the hips
    kp = piece == 3
    allow(kp, "hips")
    rig[kp] = ix["spine"]
    rig[kp & (z > 0.77)] = ix["chest"]
    rig[kp & (part == GOLD) & (z < 1.0)] = ix["hips"]
    rig[kp & (z > 1.0)] = ix["head"]                    # the earrings
    # the body: legs, torso (the vest's skirt and the rag follow the hips), arms
    bp = piece == 2
    legs = bp & ((np.isin(part, (TROUSERS, PATCH, BOOT, SOLE)) & (z < 0.6)) | (z < 0.3))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs & (np.isin(part, (VEST, BELT, RAG, TROUSERS, PATCH)) | ((part == SHIRT) & (np.abs(x) < 0.15)))
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.07) & (z > 0.78), "shoulder.L")
    allow(torso & (x < -0.07) & (z > 0.78), "shoulder.R")
    rag = bp & (part == RAG)
    allow(rag & (z < 0.53), "thigh.L")
    arms = bp & ~legs & ~torso
    allow(arms & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (z > 0.8), "chest")
    return A, rig


WALK = dict(stride=0.62, stance=0.61, foot_x=0.105, lift=0.048, bob=0.011, drop=0.034, sway=0.03, roll=5.0, yaw=6.0, counter=1.0,
            lean=5.0, toe_off=12.0, toe_out=9.0, swing_point=5.0)
RUN = dict(stride=0.98, stance=0.42, foot_x=0.095, lift=0.095, bob=0.022, drop=0.06, sway=0.022, roll=4.0, yaw=8.0, counter=1.2,
           lean=12.0, toe_off=22.0, toe_out=8.0, swing_point=12.0, spine_lean=4.0)
BACK = 0.05        # the walk centres the ball of the foot under the hips: shift the hips back over the ankles


def motions(rig):
    """his clips: walk (a stooped pottering amble: short duck-footed steps, a side-to-side roll, the head nodding forward on each step,
    loose arms; antennae and ears bouncing), run (a hurried old man's trot, elbows pumping), idle (shifting weight, a look round, a sly chuckle)"""
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
        s2 = math.sin(2 * TAU * u - 0.9)
        A = 26.0 if run else 11.0
        flex = 62.0 if run else 14.0
        p.rot("chest", 4.0 if run else 3.0, 0, 0)
        p.rot("upper_arm.L", A * c, 4.0 if run else 0.0, -3.0)
        p.rot("upper_arm.R", -A * c, -4.0 if run else 0.0, 3.0)
        p.rot("forearm.L", -flex - (10.0 if run else 6.0) * max(0.0, -c), 0, 0)
        p.rot("forearm.R", -flex - (10.0 if run else 6.0) * max(0.0, c), 0, 0)
        p.rot("hand.L", 6.0 * math.cos(TAU * u - 0.7), 0, 0)
        p.rot("hand.R", -6.0 * math.cos(TAU * u - 0.7), 0, 0)
        # the head nods forward with each step and looks a little about
        p.rot("neck", (4.0 if run else 2.0) + (2.0 if run else 3.0) * s2, 0, 0)
        p.world["head"] = R((3.0 if run else 0.0) + 2.5 * s2, 1.5 * math.sin(TAU * u), 4.0 * math.sin(TAU * u + 0.5) * (0.4 if run else 1.0))
        bnc = (9.0 if run else 6.0) * math.sin(2 * TAU * u - 1.6)
        p.rot("antenna.L", -bnc, 0, 0)
        p.rot("antenna.R", -bnc, 0, 0)
        p.rot("ear.L", 0, 0, 0)
        p.rot("ear.L", 0, -(4.0 if run else 3.0) * math.sin(2 * TAU * u - 1.2), 0)
        p.rot("ear.R", 0, (4.0 if run else 3.0) * math.sin(2 * TAU * u - 1.2), 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        stand(rig, p, legs, {"L": (Vector((0.115, -0.095 - 0.01 * w, 0.0)), 10.0), "R": (Vector((-0.11, -0.075, 0.0)), -12.0)},
              hip_shift=(0.012 * w, 0.004, -0.012 + 0.003 * math.sin(TAU * t / 3.0)), roll=-2.5 * w, yaw=3.0 * w)
        br = math.sin(TAU * t / 3.0)
        p.rot("spine", 1.0 * br, 0, 0)
        p.rot("chest", 1.2 * br, 0, 0)
        # a look to his left, back, then a sly chuckle (shoulders bouncing, head tipped) around 2.5-3.6 s, then a look to his right
        look = 22.0 * (ease((t - 0.4) / 0.8) - ease((t - 1.8) / 0.6)) - 18.0 * (ease((t - 4.0) / 0.7) - ease((t - 5.3) / 0.6))
        ch = ease((t - 2.2) / 0.3) * (1.0 - ease((t - 3.6) / 0.4))
        shake = ch * math.sin(TAU * t * 4.0)
        p.rot("chest", -2.0 * ch + 1.5 * shake, 0, 0)
        p.rot("shoulder.L", 0, 0, 3.0 * shake)
        p.rot("shoulder.R", 0, 0, -3.0 * shake)
        p.world["head"] = R(-6.0 * ch + 2.0 * shake, 7.0 * ch, look)
        p.rot("upper_arm.L", 2.0 * br, 0, -2.0 * ch)
        p.rot("upper_arm.R", -1.5 * br, 0, 2.0 * ch)
        p.rot("forearm.L", -8.0 - 6.0 * ch, 0, 0)
        p.rot("forearm.R", -8.0 - 6.0 * ch, 0, 0)
        tw = math.sin(TAU * t * 1.5) * (ease((t - 1.0) / 0.2) - ease((t - 1.6) / 0.2)) + math.sin(TAU * t * 1.7) * (ease((t - 4.4) / 0.2) - ease((t - 5.0) / 0.2))
        p.rot("antenna.L", -8.0 * tw - 3.0 * br, 0, 0)
        p.rot("antenna.R", 6.0 * tw - 3.0 * br, 0, 0)
        p.rot("ear.L", 0, -4.0 * ch * math.sin(TAU * t * 2.0), 0)
        p.rot("ear.R", 0, 4.0 * ch * math.sin(TAU * t * 2.0), 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
