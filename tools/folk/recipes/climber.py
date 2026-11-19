## FOINT CITY townsfolk: the climber. A wiry orange-red freckled woman with short dreadlocks tied up on top, a sly wide grin and piercings; maroon tank top, olive cargo pants with knee patches, a climbing harness with carabiners, a chalk bag, climbing shoes; a rope coil over her left shoulder, held there by her left hand.
# Concept: the user's sheet, image 4 bottom middle (F:/prog-godot-cache/folk/refs/4.webp). Measured off it: 1.65 m to the top of the dreads (skull 1.59); the head 0.21 m
# chin to crown and 0.24 wide at the cheeks; a long neck; shoulders 0.40; the harness at the hips (0.93); crotch at 0.77; cuffs gathered at 0.27.
# Rest pose = her carrying pose: the left hand up at the shoulder gripping the rope coil, the right arm hanging.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

F32 = np.float32
HEIGHT = 1.65
REF = ("4.webp", (460, 385, 672, 782))

(SKIN, EYE, TOOTH, MOUTH, LIP, HAIR, GOLD, SILVER, TANK, PANTS, PATCH_Y, PATCH_B, HARNESS, METAL, CARA, BAG, SHOE, SHOE_G, SOLE, ROPE,
 WATCH) = range(1, 22)
COLOURS = {
    SKIN: ((0.78, 0.40, 0.24), 0.55, 0.0),
    EYE: ((0.22, 0.12, 0.06), 0.15, 0.0),
    TOOTH: ((0.92, 0.90, 0.82), 0.3, 0.0),
    MOUTH: ((0.30, 0.08, 0.08), 0.6, 0.0),
    LIP: ((0.60, 0.26, 0.20), 0.45, 0.0),
    HAIR: ((0.24, 0.13, 0.14), 0.7, 0.0),
    GOLD: ((0.90, 0.68, 0.30), 0.25, 1.0),
    SILVER: ((0.80, 0.80, 0.82), 0.25, 1.0),
    TANK: ((0.48, 0.12, 0.14), 0.85, 0.0),
    PANTS: ((0.36, 0.36, 0.20), 0.85, 0.0),
    PATCH_Y: ((0.62, 0.55, 0.22), 0.85, 0.0),
    PATCH_B: ((0.40, 0.24, 0.18), 0.85, 0.0),
    HARNESS: ((0.20, 0.20, 0.22), 0.7, 0.0),
    METAL: ((0.72, 0.72, 0.74), 0.3, 1.0),
    CARA: ((0.85, 0.50, 0.18), 0.3, 0.8),
    BAG: ((0.45, 0.35, 0.60), 0.8, 0.0),
    SHOE: ((0.90, 0.45, 0.15), 0.6, 0.0),
    SHOE_G: ((0.30, 0.30, 0.32), 0.7, 0.0),
    SOLE: ((0.20, 0.18, 0.18), 0.7, 0.0),
    ROPE: ((0.50, 0.22, 0.40), 0.75, 0.0),
    WATCH: ((0.12, 0.12, 0.14), 0.5, 0.0),
}

# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; the figure faces -Y)
HEAD_C = v3((0.0, -0.01, 1.505))
EYE_C = v3((0.05, -0.098, 1.503))
EYE_R = 0.03
EYE_FWD = v3((0.15, -1.0, 0.0)) / np.linalg.norm((0.15, -1.0, 0.0))
LID_PT = EYE_C + v3((0.0, 0.0, 0.005))
LID_N = v3((0.3, 0.0, -1.0)) / np.linalg.norm((0.3, 0.0, -1.0))         # round 2: sly lizard eyes, a heavy lid rising to the outer corner
LOW_PT = EYE_C + v3((0.0, 0.0, -0.016))
LOW_N = v3((-0.3, 0.0, 1.0)) / np.linalg.norm((-0.3, 0.0, 1.0))
EAR_C = v3((0.098, 0.012, 1.48))
MOUTH_X = 0.062
MOUTH_Z = 1.432
NECK0 = v3((0.0, 0.01, 1.28))
NECK1 = v3((0.0, -0.01, 1.43))

SHOULDER = v3((0.16, 0.02, 1.285))
R_ELBOW = v3((0.205, 0.04, 1.02))           # the free (right) arm, built on the left and mirrored
R_WRIST = v3((0.225, -0.02, 0.785))
R_HAND = basis(-(R_WRIST - R_ELBOW), v3((0, 1, 0)))
C_ELBOW = v3((0.225, 0.02, 1.04))           # the rope (left) arm: elbow down at her side, the forearm up to the coil at the shoulder's front
C_WRIST = v3((0.205, -0.10, 1.215))
C_HAND = basis(v3((-0.15, -0.35, 1.0)), v3((-1.0, 0.0, 0.0)))     # fingers up and back, curled over the rope
HIP = v3((0.08, 0.012, 0.80))
KNEE = v3((0.09, -0.016, 0.47))
ANKLE = v3((0.095, 0.02, 0.08))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
COIL_C = v3((0.205, 0.0, 1.10))            # the rope coil: loops in a plane over her left shoulder


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def side_prism(poly_yz, x0, x1):
    return Slab(((x0 + x1) * 0.5, 0, 0), poly_yz, (x1 - x0) * 0.5, R=np.array([[0, 0, 1], [1, 0, 0], [0, 1, 0]], np.float32))


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


# ---------------------------------------------------------------------------------------------------- the head
def skull():
    """a round skull, wide high cheekbones, the face tapering to a neat pointed chin"""
    return Union([
        Ellipsoid(HEAD_C, (0.098, 0.11, 0.1)),
        Mirror(Ellipsoid((0.065, -0.06, 1.47), (0.05, 0.055, 0.045))),
        Ellipsoid((0.0, -0.065, 1.44), (0.075, 0.06, 0.05)),
        Ellipsoid((0.0, -0.085, 1.395), (0.032, 0.032, 0.025)),
    ], k=0.035, part=SKIN)


def face_shape():
    sk = skull()
    lid = Clip(Ellipsoid(EYE_C + v3((0, -0.001, 0.0015)), (0.0345, 0.034, 0.0345), part=SKIN), [Half(LID_PT, LID_N)], k=0.005)
    lower = Clip(Ellipsoid(EYE_C + v3((0, -0.001, -0.001)), (0.034, 0.0335, 0.034), part=SKIN), [Half(LOW_PT, LOW_N)], k=0.005)
    face = Union([sk, Mirror(lid), Mirror(lower)], k=0.008)
    nose = Union([
        RoundCone((0.0, -0.105, 1.505), (0.0, -0.122, 1.468), 0.011, 0.012),
        Ellipsoid((0.0, -0.125, 1.462), (0.015, 0.013, 0.012)),
        Mirror(Ellipsoid((0.012, -0.115, 1.458), (0.01, 0.01, 0.009))),
    ], k=0.01, part=SKIN)
    face = Union([face, nose], k=0.008)
    nostrils = Mirror(Ellipsoid((0.008, -0.123, 1.4535), (0.0035, 0.0045, 0.003), R=rot(rx=30), part=SKIN))
    return Cut(face, [nostrils], k=0.0015)


def ears():
    shell = Ellipsoid(EAR_C, (0.012, 0.024, 0.032), R=rot(rz=-15, ry=10), part=SKIN)
    bowl = Ellipsoid(EAR_C + v3((0.009, -0.004, 0.002)), (0.008, 0.016, 0.022), R=rot(rz=-15, ry=10), part=SKIN)
    e = Cut(shell, [bowl], k=0.004)
    studs = [Sphere(EAR_C + v3((0.004, 0.0, z)), 0.0032, part=SILVER) for z in (0.016, 0.006)]
    cuff = Torus(EAR_C + v3((0.002, 0.004, 0.025)), 0.008, 0.0018, Rm=rot(ry=90), part=SILVER)
    small = Torus(EAR_C + v3((0.0, -0.002, -0.034)), 0.0075, 0.0018, Rm=rot(ry=90), part=GOLD)
    return Mirror(e)


def jewellery():
    """round 2: the ear studs, cuff and hoops live in the kit piece: decimated with the head they collapsed into flipped slivers along the jaw
    (the white streak)"""
    studs = [Sphere(EAR_C + v3((0.004, 0.0, z)), 0.0034, part=SILVER) for z in (0.016, 0.006)]
    cuff = Torus(EAR_C + v3((0.002, 0.004, 0.025)), 0.008, 0.002, Rm=rot(ry=90), part=SILVER)
    small = Torus(EAR_C + v3((0.0, -0.002, -0.034)), 0.0075, 0.002, Rm=rot(ry=90), part=GOLD)
    big = Torus(EAR_C * np.array([-1, 1, 1], np.float32) + v3((-0.002, -0.004, -0.058)), 0.02, 0.003, Rm=rot(ry=90), part=GOLD)
    return Union([Mirror(Union(studs + [cuff, small], k=0.0)), big], k=0.0)


def dreads():
    """round 2: a full mop of short dreadlocks all over the top of the head (the concept's), springing up and out and flopping back, the sides
    cropped close"""
    rad = np.array([0.098, 0.11, 0.1], np.float32)
    sk = Ellipsoid(HEAD_C, tuple(rad))
    cap = Clip(Inflate(sk, 0.01, part=HAIR), [Half((0, 0, 1.505), (0, 0.25, -1)), Half((0, -0.085, 1.52), (0, -1, 0.35))], k=0.014)
    locks = [cap]
    rng = np.random.RandomState(3)
    for i in range(40):
        az = rng.rand() * np.pi * 2
        el = np.radians(24 + 62 * rng.rand())
        d = v3((np.cos(el) * np.cos(az), np.cos(el) * np.sin(az), np.sin(el)))
        if d[1] < -0.55 and d[2] < 0.75:          # keep the forehead clear
            continue
        root = HEAD_C + d * rad
        out = d + v3((0, 0.35, 0.25))
        out /= np.linalg.norm(out)
        L = 0.05 + 0.04 * rng.rand()
        mid = root + out * L * 0.55
        tip = root + out * L + v3((0, 0.012, -0.018 - 0.02 * rng.rand()))
        locks.append(loft([(root, 0.0088), (mid, 0.0084), (tip, 0.0074)], part=HAIR, k=0.004))
        locks.append(Sphere(tip, 0.0082, part=HAIR))
    return Union(locks, k=0.005)


def mouth_z(x):
    return MOUTH_Z + 0.018 * (np.abs(x) / MOUTH_X) ** 2 + 0.006 * np.clip(-x / MOUTH_X, 0, 1)      # the grin higher at her right


def head():
    face = Union([face_shape(), ears()], k=0.0)
    neck = Union([RoundCone(NECK0, NECK1, 0.039, 0.036, part=SKIN), Ellipsoid((0.0, -0.035, 1.412), (0.055, 0.05, 0.04), part=SKIN), Mirror(RoundCone((0.018, -0.02, 1.31), (0.012, -0.035, 1.40), 0.007, 0.006, part=SKIN))], k=0.01)
    face = Union([face, neck], k=0.045)        # round 2: a fuller jaw-to-neck fillet (the bake missed the sharp crease)
    base = face
    xs = np.linspace(-MOUTH_X, MOUTH_X, 13)
    pts = [on(base, x, mouth_z(x)) for x in xs]
    open_ = loft([(p + v3((0, 0.004, 0.0)), 0.0068 * (1 - 0.75 * (abs(p[0]) / MOUTH_X) ** 2)) for p in pts], k=0.003)
    face = Cut(face, [open_], k=0.002)
    back = loft([(p + v3((0, 0.012, 0)), 0.007 * (1 - 0.6 * (abs(p[0]) / MOUTH_X) ** 2)) for p in pts], part=MOUTH, k=0.003)
    teeth = Clip(loft([(p + v3((0, 0.0045, 0.001)), 0.0058 * (1 - 0.7 * (abs(p[0]) / MOUTH_X) ** 2)) for p in pts[2:-2]], part=TOOTH, k=0.003),
                 [Half((0, 0, MOUTH_Z - 0.0015), (0, 0, -1))], k=0.0)
    lip = loft([(p + v3((0, 0.003, -0.0075)), 0.0045 * (1 - 0.6 * (abs(p[0]) / MOUTH_X) ** 2)) for p in pts[1:-1]], part=LIP, k=0.003)
    face = Union([face, lip], k=0.004)
    face = Crease(face, [on(base, x, z, 0.001) for x, z in ((0.07, 1.445), (0.08, 1.43), (0.075, 1.415))], 0.004, -0.0015)
    ball = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    studs = Union([Sphere(on(base, 0.016, 1.468, -0.002), 0.003, part=SILVER), Sphere(on(base, -0.06, 1.538, -0.002), 0.0028, part=SILVER),
                   Sphere(on(base, -0.07, 1.536, -0.002), 0.0028, part=SILVER)], k=0.0)
    return Union([face, back, ball, teeth, studs], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body
def core():
    """wiry: a lean chest, a narrow waist, a small seat"""
    return Union([
        Ellipsoid((0, 0.015, 1.17), (0.13, 0.085, 0.12)),
        Ellipsoid((0, 0.02, 1.26), (0.145, 0.068, 0.045)),
        Mirror(Ellipsoid((0.048, -0.035, 1.16), (0.046, 0.042, 0.042))),
        Ellipsoid((0, 0.012, 1.0), (0.105, 0.075, 0.1)),
        Ellipsoid((0, 0.015, 0.86), (0.14, 0.095, 0.095)),
    ], k=0.05, part=TANK)


def legs_core():
    return Mirror(loft([(HIP, 0.084), (KNEE, 0.078), (ANKLE + v3((0, 0, 0.2)), 0.072)], k=0.03))


def hand(curl):
    palm = Ellipsoid((0.0, 0.0, -0.037), (0.013, 0.029, 0.038), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.023, 0.021, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.02, -0.0067, 0.0067, 0.02):
        L = 1.0 - abs(f) * 6
        pts = [((0.0, f, -0.066), 0.0078), ((-0.012 * curl, f * 1.05, -0.066 - 0.024 * L * (1 - curl * 0.4)), 0.0072),
               ((-0.032 * curl, f * 1.08, -0.086 - 0.018 * L * (1 - curl)), 0.0066), ((-0.042 * curl, f * 1.1, -0.085 - 0.012 * L * (1 - curl)), 0.006)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.003))
    parts.append(loft([(v3((-0.006, -0.025, -0.02)), 0.009), (v3((-0.017, -0.038, -0.047)), 0.008), (v3((-0.028, -0.034, -0.068)), 0.007)], part=SKIN, k=0.003))
    return Union(parts, k=0.007)


def arm(elbow, wrist, frame, curl):
    # round 2: a deltoid, a bicep, a knobbed elbow and a tapering forearm instead of a tube
    ua = (elbow - SHOULDER) / np.linalg.norm(elbow - SHOULDER)
    upper = loft([(SHOULDER, 0.046), (SHOULDER + (elbow - SHOULDER) * 0.22, 0.05), (SHOULDER + (elbow - SHOULDER) * 0.55, 0.04),
                  (elbow, 0.031)], part=SKIN, k=0.016)
    bicep = Ellipsoid(SHOULDER + (elbow - SHOULDER) * 0.55 + v3((0, -0.012, 0)), (0.034, 0.036, 0.06), R=basis(ua, v3((0, 1, 0))), part=SKIN)
    knob = Sphere(elbow + v3((0, 0.016, 0)), 0.024, part=SKIN)
    fore = loft([(elbow, 0.032), (elbow + (wrist - elbow) * 0.28, 0.039), (elbow + (wrist - elbow) * 0.7, 0.03), (wrist, 0.023)], part=SKIN, k=0.014)
    upper = Union([upper, bicep, knob], k=0.014)
    return Union([upper, fore, place(hand(curl), wrist, frame)], k=0.008)


def climbing_shoe():
    heel = ANKLE + v3((0.0, 0.045, -0.045))
    foot = loft([(heel, 0.04), (ANKLE + v3((-0.003, -0.08, -0.047)), 0.043), (ANKLE + v3((-0.012, -0.17, -0.058)), 0.026)], k=0.02)
    collar = RoundCone(ANKLE + v3((0, 0.008, -0.02)), ANKLE + v3((0, 0.0, 0.04)), 0.046, 0.042)
    up = Union([foot, collar], k=0.03, part=SHOE)
    up = Clip(up, [Half((0, 0, 0.015), (0, 0, -1)), Half(ANKLE + v3((0, 0, 0.045)), (0, 0.2, 1))], k=0.004)
    sole = Clip(Inflate(foot, 0.006, part=SOLE), [Half((0, 0, 0.024), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    straps = [Clip(Inflate(Union([foot, collar], k=0.03), 0.004, part=SHOE_G), [Box(ANKLE + v3((0, yy, zz)), (0.06, 0.013, 0.07), R=rot(rx=a))], k=0.002)
              for yy, zz, a in ((-0.045, -0.01, -30.0), (-0.09, -0.025, -40.0))]
    heelcup = Clip(Inflate(foot, 0.003, part=SHOE_G), [Half(ANKLE + v3((0, 0.02, 0)), (0, -1, 0))], k=0.004)
    return Union([up, sole, heelcup] + straps, k=0.0)


def body():
    co = core()
    arm_r = arm(R_ELBOW, R_WRIST, R_HAND, 0.35)
    arm_c = arm(C_ELBOW, C_WRIST, C_HAND, 0.95)
    # the tank top: the body grown, a scooped neck, wide armholes, racer back; hem under the harness
    tank = Inflate(co, 0.008, part=TANK)
    tank = Clip(tank, [Half((0, 0, 0.9), (0, 0, -1))], k=0.004)
    tank = Cut(tank, [Ellipsoid((0, -0.06, 1.32), (0.085, 0.09, 0.09)), Mirror(Ellipsoid((0.16, 0.02, 1.19), (0.06, 0.1, 0.1))),
                      Ellipsoid((0, 0.08, 1.32), (0.075, 0.06, 0.1))], k=0.006)
    delts = Mirror(Ellipsoid((0.148, 0.02, 1.268), (0.05, 0.052, 0.05), part=SKIN))       # round 2: shoulders that blend into the arms
    skin = Union([Clip(co, [Half((0, 0, 0.88), (0, 0, -1))], k=0.0), delts, arm_c, Move(arm_r, R=FLIP)], k=0.03, part=SKIN)
    # cargo pants: baggy, knee patches, cargo pockets, gathered cuffs
    pants = Union([Clip(Inflate(co, 0.008), [Half((0, 0, 0.955), (0, 0, 1))]), legs_core()], k=0.045, part=PANTS)
    pants = Clip(pants, [Half((0, 0, 0.25), (0, 0, -1))], k=0.004)

    def folds(P):
        return noise3(P * np.array([1.0, 1.0, 0.4], np.float32), 0.03) * (P[:, 2] < 0.75)
    pants = Bump(pants, folds, 0.004)
    cuffs = Mirror(Clip(RoundCone(ANKLE + v3((0, 0, 0.12)), ANKLE + v3((0, 0, 0.22)), 0.05, 0.054, part=PANTS), [Half((0, 0, 0.255), (0, 0, 1)), Half((0, 0, 0.17), (0, 0, -1))], k=0.004))
    patch_y = Clip(Inflate(legs_core(), 0.004, part=PATCH_Y), [prism([(-0.15, 0.42), (-0.05, 0.43), (-0.045, 0.53), (-0.145, 0.54)])], k=0.002)
    patch_b = Clip(Inflate(legs_core(), 0.004, part=PATCH_B), [prism([(0.05, 0.44), (0.15, 0.44), (0.15, 0.55), (0.05, 0.55)])], k=0.002)
    cargo = Mirror(Clip(Inflate(legs_core(), 0.012, part=PANTS), [side_prism([(-0.06, 0.58), (0.05, 0.58), (0.05, 0.72), (-0.06, 0.72)], 0.12, 0.4)], k=0.003))
    # the harness: a waist belt over the hips, leg loops round the tops of the thighs, a belay loop in front
    hcore = Union([Clip(Inflate(co, 0.008), [Half((0, 0, 0.955), (0, 0, 1))]), legs_core()], k=0.045)
    waist = Clip(Inflate(hcore, 0.014, part=HARNESS), [Half((0, 0, 0.905), (0, 0, -1)), Half((0, 0, 0.955), (0, 0, 1))], k=0.003)
    loops = Mirror(Clip(Inflate(legs_core(), 0.013, part=HARNESS), [Half(HIP + v3((0, 0, -0.12)), v3((0.25, 0.0, -1.0))), Half(HIP + v3((0, 0, -0.155)), v3((-0.25, 0.0, 1.0)))], k=0.003))
    belay = Torus(on(co, 0.0, 0.87, -0.03), 0.028, 0.008, Rm=rot(rx=80), part=HARNESS)
    shoes = Mirror(climbing_shoe())
    return Union([skin, tank, pants, cuffs, patch_y, patch_b, cargo, waist, loops, belay, shoes], k=0.0)


def rope_coil():
    """loops of rope hanging over her left shoulder, front and back of the arm; a few loose turns and two tails"""
    parts = []
    rng = np.random.RandomState(11)
    for i in range(8):
        k = i - 3.5
        c = COIL_C + v3((0.0085 * k + 0.003 * rng.randn(), 0.004 * rng.randn(), -0.004 * abs(k) - 0.012 * rng.rand()))
        R = rot(rx=5 * rng.randn(), ry=90.0 + 3.5 * k)
        parts.append(Ellipse(c, 0.226 + 0.006 * rng.randn(), 0.136 + 0.008 * rng.randn(), 0.011, R))
    tail1 = loft([(COIL_C + v3((0.01, -0.13, -0.17)), 0.0095), (COIL_C + v3((0.02, -0.12, -0.3)), 0.0095), (COIL_C + v3((0.015, -0.1, -0.4)), 0.0095)], part=ROPE, k=0.004)
    tail2 = loft([(COIL_C + v3((0.02, -0.11, -0.19)), 0.0095), (COIL_C + v3((0.03, -0.08, -0.33)), 0.0095), (COIL_C + v3((0.025, -0.06, -0.47)), 0.0095)], part=ROPE, k=0.004)
    return Union(parts + [tail1, tail2], k=0.003)


class Ellipse(Shape):
    """a tube along an ellipse (semi-axes a along local X, b along local Y of the in-plane frame) in the plane of R's local XY: a loop of rope"""
    def __init__(self, c, a, b, r, R):
        self.c, self.a, self.b, self.r = v3(c), F32(a), F32(b), F32(r)
        self.R = np.asarray(R, np.float32)
        self.part = ROPE
        m = max(a, b) + r
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.R
        ang = np.arctan2(q[:, 1] / self.b, q[:, 0] / self.a)
        best = np.full(len(P), 1e3, np.float32)
        for k in range(-2, 3):
            t = ang + k * 0.04
            ex, ey = self.a * np.cos(t), self.b * np.sin(t)
            dd = np.sqrt((q[:, 0] - ex) ** 2 + (q[:, 1] - ey) ** 2 + q[:, 2] ** 2)
            best = np.minimum(best, dd)
        return best - self.r


def kit_bits(bd):
    """carabiners on the harness, the chalk bag on her right hip, the watch on her right wrist, the harness buckle"""
    parts = []
    for i, (x, part) in enumerate(((0.085, CARA), (0.105, METAL), (0.125, CARA), (-0.115, METAL))):
        y = probe(bd, x, 0.89) - 0.006
        c = v3((x, y, 0.85))
        ring = Cut(Ellipsoid(c, (0.012, 0.004, 0.03), part=part), [Ellipsoid(c, (0.0075, 0.02, 0.024))], k=0.0)
        parts.append(ring)
    by = probe(bd, 0.0, 0.93)
    parts.append(Cut(Box((0, by - 0.004, 0.93), (0.022, 0.005, 0.016), rr=0.003, part=METAL), [Box((0.0, by - 0.008, 0.93), (0.012, 0.01, 0.007), rr=0.002)], k=0.0))
    bag = CappedCone((-0.115, 0.125, 0.765), (-0.118, 0.13, 0.885), 0.045, 0.05, rr=0.012, part=BAG)      # behind her right hip, clear of the swinging hand
    rim = Torus((-0.118, 0.13, 0.885), 0.05, 0.007, part=SOLE)
    parts += [bag, rim]
    wd = (R_WRIST - R_ELBOW) / np.linalg.norm(R_WRIST - R_ELBOW)
    w = (R_WRIST - wd * 0.012) * np.array([-1, 1, 1], np.float32)
    wdm = wd * np.array([-1, 1, 1], np.float32)
    parts.append(Torus(w, 0.025, 0.0045, Rm=basis(wdm, v3((0, 1, 0))), part=WATCH))
    parts.append(Box(w + v3((-0.026, 0.0, 0.0)), (0.004, 0.012, 0.014), rr=0.003, part=WATCH))
    parts.append(jewellery())
    return Union(parts, k=0.0)


def pieces():
    import os
    only = os.environ.get("FOLK_ONLY", "")
    s = 1.5 if os.environ.get("FOLK_FAST") else 1.0
    if only == "head":
        return [("head", head(), 0.0016 * s), ("hair", dreads(), 0.002 * s)]
    bd = body()
    return [("head", head(), 0.0016 * s), ("hair", dreads(), 0.002 * s), ("body", bd, 0.003 * s), ("kit", kit_bits(bd), 0.0016 * s),
            ("props", rope_coil(), 0.0025 * s)]


# ---------------------------------------------------------------------------------------------------- paint
def _hash(ix, iy, iz):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF).astype(np.float32) / 65535.0


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

    # skin: warm orange-red, darker freckles and clustered spots over the shoulders and arms; eyeshadow, a liner wing
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(230, 132, 88), (n, 3)).copy() * (1.0 + 0.07 * mott)[:, None]
    blotch = np.clip(noise3(P, 0.018) * 1.2 - 0.25, 0, 1) * ((z > 1.0) & (z < 1.32) & (Q[:, 0] > 0.11))
    sk = sk + (srgb(168, 74, 48) - sk) * (blotch * 0.8)[:, None]
    de = Q - EYE_C
    r = np.linalg.norm(de, axis=1)
    pd = (Q - LID_PT) @ LID_N
    lid = (r < EYE_R + 0.01) & (pd < 0.0)
    sk = sk + (srgb(150, 76, 60) - sk) * (lid * smooth(-0.025, -0.003, pd) * 0.6)[:, None]
    sk *= (1.0 - 0.3 * c.cavity)[:, None]
    put(m, sk, 0.62, bump=0.12)
    spk(m, (150, 66, 40), 0.35 + 0.25 * (z > 1.38))
    c.draw(m & (r < EYE_R + 0.01) & (pd > -0.007) & (pd < 0.003) & (de[:, 1] < 0.01), np.abs(pd + 0.001), 0.0018)
    wing_t = (Q[:, 0] - (EYE_C[0] + 0.022)) / 0.025
    wing = (wing_t > 0) & (wing_t < 1) & (de[:, 1] < 0.025) & (r < EYE_R + 0.03) & (np.abs(pd) < 0.016)
    c.draw(m & wing, np.abs(pd + 0.001 - 0.007 * wing_t ** 1.3), 0.0018 * (1.0 - wing_t))
    lowd = (Q - LOW_PT) @ LOW_N
    c.draw(m & (r < EYE_R + 0.007) & (np.abs(lowd) < 0.004) & (de[:, 1] < 0.0), np.abs(lowd - 0.0006), 0.0008, 0.6)
    # the grin's corners inked into the cheeks
    put(c.mask(LIP), srgb(150, 60, 50) * (1.0 + 0.3 * c.wear)[:, None], 0.4)
    # eyes: white, a big dark iris glancing to her left, a glint
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    look = EYE_FWD + v3((0.35, 0.0, 0.05))
    look /= np.linalg.norm(look)
    a = np.arccos(np.clip(d @ look, -1, 1))
    ir = srgb(110, 64, 34) + (srgb(48, 26, 14) - srgb(110, 64, 34)) * smooth(0.1, 0.36, a)[:, None]
    ir = ir + (srgb(242, 234, 224) - ir) * smooth(0.42, 0.47, a)[:, None]
    c.draw(m, (a / 0.17 - 1.0) * 0.17 * EYE_R, 0.0)
    ir *= (1.0 - 0.3 * smooth(-0.2, 0.1, d[:, 2]))[:, None]
    gl = np.zeros(n, np.float32)
    for sx in (1.0, -1.0):
        dd = P - EYE_C * np.array([sx, 1.0, 1.0], np.float32)
        dd /= np.maximum(np.linalg.norm(dd, axis=1), 1e-6)[:, None]
        gl = np.maximum(gl, smooth(0.008, 0.003, (dd[:, 0] - 0.05) ** 2 + (dd[:, 2] + 0.1) ** 2) * (dd[:, 1] < -0.5))
    ir = ir + (srgb(255, 250, 240) - ir) * gl[:, None]
    put(m, ir, 0.08)
    put(c.mask(TOOTH), srgb(240, 236, 222) * (1.0 - 0.2 * c.cavity)[:, None], 0.3)
    put(c.mask(MOUTH), srgb(90, 26, 26), 0.6)
    m = c.mask(HAIR)
    hr = srgb(82, 44, 48) * (1.0 + 0.15 * noise3(P, 0.006))[:, None] * (1.0 - 0.4 * c.cavity)[:, None]
    put(m, hr, 0.7, bump=0.9)
    put(c.mask(GOLD), srgb(236, 184, 90) * (1.0 - 0.35 * c.cavity)[:, None], 0.22, metal=1.0)
    put(c.mask(SILVER), srgb(212, 212, 216), 0.22, metal=1.0)
    # tank top: maroon jersey, a tan line drawing of mountains on the chest
    m = c.mask(TANK)
    tk = np.broadcast_to(srgb(128, 34, 44), (n, 3)).copy() * (1.0 + 0.06 * mott)[:, None] * (1.0 + 0.25 * c.wear)[:, None]
    mx = np.array([-0.075, -0.04, -0.018, 0.012, 0.042, 0.075], np.float32)
    mzz = np.array([1.095, 1.155, 1.125, 1.175, 1.115, 1.095], np.float32)
    front = (y < -0.04) & (np.abs(x) < 0.09) & (z > 1.08) & (z < 1.19)
    dl = np.full(n, 1.0, np.float32)
    for i in range(len(mx) - 1):
        a0, a1 = np.array([mx[i], mzz[i]]), np.array([mx[i + 1], mzz[i + 1]])
        ab = a1 - a0
        q = np.stack([x, z], 1) - a0
        t = np.clip((q @ ab) / (ab @ ab), 0, 1)
        dl = np.minimum(dl, np.linalg.norm(q - np.outer(t, ab), axis=1))
    tk = tk + (srgb(206, 150, 96) - tk) * (front * smooth(0.0035, 0.0015, dl))[:, None]
    put(m, tk, 0.85, bump=0.8)
    # pants: olive cotton, worn paler on the edges, dusty; the patches with big stitches
    m = c.mask(PANTS)
    pa = srgb(112, 110, 62) * (1.0 + 0.08 * mott)[:, None] * (1.0 + 0.45 * c.wear)[:, None]
    pa = pa + (srgb(150, 132, 96) - pa) * (np.clip(noise3(P, 0.03) - 0.2, 0, 1) * 0.6)[:, None]
    put(m, pa, 0.9, bump=1.0)
    for part, col in ((PATCH_Y, (176, 152, 66)), (PATCH_B, (116, 68, 50))):
        mm = c.mask(part)
        put(mm, srgb(*col) * (1.0 + 0.06 * mott)[:, None], 0.9, bump=1.0)
        c.draw(mm & (c.wear > 0.3), 1.0 - c.wear, 0.35, 0.0)
    m = c.mask(HARNESS)
    put(m, srgb(52, 52, 58) * (1.0 + 0.5 * c.wear)[:, None], 0.7, bump=0.7)
    put(c.mask(METAL), srgb(200, 200, 206), 0.25, metal=1.0)
    put(c.mask(CARA), srgb(232, 132, 48), 0.3, metal=0.7)
    # the chalk bag: a patchwork of purple, orange and blue triangles, chalk dust
    m = c.mask(BAG)
    tri = np.floor((z * 40.0) + np.floor(x * 40.0 + y * 40.0) * 0.5).astype(np.int64)
    hv = _hash(np.floor(x * 40.0 + y * 40.0).astype(np.int64), tri, np.zeros(n, np.int64))
    bag = np.where((hv < 0.33)[:, None], srgb(120, 84, 160), np.where((hv < 0.66)[:, None], srgb(226, 128, 60), srgb(70, 110, 170)))
    bag = bag + (srgb(230, 226, 220) - bag) * (np.clip(noise3(P, 0.012) - 0.3, 0, 1) * 0.6)[:, None]
    put(m, bag, 0.85, bump=0.8)
    # climbing shoes: orange and grey with dark rubber
    put(c.mask(SHOE), srgb(234, 122, 44) * (1.0 + 0.25 * c.wear)[:, None], 0.55, bump=0.4)
    put(c.mask(SHOE_G), srgb(80, 80, 86) * (1.0 + 0.4 * c.wear)[:, None], 0.65, bump=0.6)
    put(c.mask(SOLE), srgb(44, 40, 40), 0.75, bump=0.4)
    # rope: plum kernmantle, a fleck of pale threads, a twist
    m = c.mask(ROPE)
    rp = srgb(144, 58, 112) * (1.0 + 0.15 * np.sin((x + y + z) * 400.0))[:, None] * (1.0 - 0.35 * c.cavity)[:, None]
    put(m, rp, 0.75, bump=0.8)
    spk(m, (230, 200, 220), 0.45)
    put(c.mask(WATCH), srgb(34, 34, 40) * (1.0 + 0.6 * c.wear)[:, None], 0.45)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    c.col *= (1.0 - 0.2 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion
GAME = {
    "budget": {"head": 2400, "hair": 900, "body": 3500, "kit": 1100, "props": 1900},
    "density": {"head": 1.9, "hair": 1.0, "kit": 1.2, "props": 1.0},
    "tex": 2048,
    "stride": {"walk": 1.0, "run": 1.6},
    "speed": 1.1,
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, -0.01, 1.43),
    "radius": 0.32,
}
BALL = v3((0.095, -0.08, 0.0))


def rig_bones():
    from kit.rig import Bone, mirror
    f = np.array([-1, 1, 1], np.float32)
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.015, 0.82), (0, 0.015, 0.95), "root", 0.12),
        Bone("spine", (0, 0.015, 0.95), (0, 0.015, 1.1), "hips", 0.1),
        Bone("chest", (0, 0.015, 1.1), (0, 0.02, 1.28), "spine", 0.11),
        Bone("neck", NECK0, NECK1, "chest", 0.034),
        Bone("head", NECK1, (0, -0.01, 1.62), "neck", 0.11),
        Bone("shoulder.L", (0.03, 0.02, 1.28), SHOULDER, "chest", 0.04),
        Bone("thigh.L", HIP, KNEE, "hips", 0.078),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.068),
        Bone("foot.L", ANKLE, ANKLE + v3((-0.01, -0.17, -0.06)), "shin.L", 0.04),
    ])
    bones += [
        Bone("upper_arm.L", SHOULDER, C_ELBOW, "shoulder.L", 0.04),
        Bone("forearm.L", C_ELBOW, C_WRIST, "upper_arm.L", 0.032),
        Bone("hand.L", C_WRIST, C_WRIST - C_HAND[:, 2] * 0.08, "forearm.L", 0.024),
        Bone("rope", COIL_C + v3((0, 0, 0.22)), COIL_C - v3((0, 0, 0.2)), "shoulder.L", 0.1),
        Bone("upper_arm.R", SHOULDER * f, R_ELBOW * f, "shoulder.R", 0.04),
        Bone("forearm.R", R_ELBOW * f, R_WRIST * f, "upper_arm.R", 0.032),
        Bone("hand.R", R_WRIST * f, (R_WRIST - R_HAND[:, 2] * 0.08) * f, "forearm.R", 0.024),
    ]
    return bones


def skin_rules(P, part, piece, names):
    """piece: 0 head, 1 hair, 2 body, 3 kit, 4 props"""
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
    rig[hp & ((z > 1.41) | ((z > 1.37) & (y < -0.05)))] = ix["head"]
    rig[piece == 1] = ix["head"]
    allow(piece == 1, "head")
    kp = piece == 3
    allow(kp, "hips")
    rig[kp] = ix["hips"]
    rig[kp & (part == WATCH)] = ix["forearm.R"]
    rig[kp & (z > 1.3)] = ix["head"]                  # the ear jewellery
    rig[piece == 4] = ix["rope"]
    allow(piece == 4, "rope")
    bp = piece == 2
    legs = bp & ((np.isin(part, (PANTS, PATCH_Y, PATCH_B, SHOE, SHOE_G, SOLE)) & (z < 0.82)) | (z < 0.4) | ((part == HARNESS) & (z < 0.86)))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs & (np.abs(x) < 0.14) & ~((part == SKIN) & (z < 1.16) & (np.abs(x) > 0.1))
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.06) & (z > 1.18), "shoulder.L")
    allow(torso & (x < -0.06) & (z > 1.18), "shoulder.R")
    arms = bp & ~legs & ~torso
    allow(arms & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (z > 1.18), "chest")
    return A, rig


WALK = dict(stride=1.0, stance=0.58, foot_x=0.08, lift=0.07, bob=0.022, drop=0.036, sway=0.025, roll=6.0, yaw=8.0, counter=1.3,
            lean=2.0, toe_off=22.0, toe_out=6.0, swing_point=10.0)
RUN = dict(stride=1.6, stance=0.4, foot_x=0.08, lift=0.14, bob=0.04, drop=0.08, sway=0.02, roll=5.0, yaw=10.0, counter=1.4,
           lean=10.0, toe_off=28.0, toe_out=5.0, swing_point=16.0, spine_lean=3.0)
BACK = 0.07


def motions(rig):
    """her clips: walk (springy and confident: a bounce off the toes, shoulders rolling, the free arm swinging loose, the rope held on the shoulder),
    run (a light athletic jog), idle (hand on hip, weight on one leg, a bounce on the toes, a look round)"""
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
        s2 = math.sin(2 * TAU * u - 0.8)
        p.rot("upper_arm.R", -(34.0 if run else 20.0) * c, 0, -3.0)
        p.rot("forearm.R", -(62.0 if run else 14.0) - (12.0 if run else 8.0) * max(0.0, c), 0, 0)
        p.rot("shoulder.R", 0, 0, 3.0 * c)
        p.rot("shoulder.L", 0, 0, -2.0 * c)
        p.rot("chest", 0, 0, 0)
        p.world["head"] = R(-1.0 + 1.5 * s2, 0, 3.0 * math.sin(TAU * u))
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    wr = Vector((R_WRIST * f).tolist())
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        br = math.sin(TAU * t / 3.0)
        akimbo = ease((t - 0.6) / 0.5) * (1.0 - ease((t - 4.6) / 0.6))
        bounce = max(0.0, math.sin(TAU * (t - 2.4) / 0.5)) * ease((t - 2.4) / 0.1) * (1.0 - ease((t - 3.4) / 0.1))
        stand(rig, p, legs, {"L": (Vector((0.09, -0.07, 0.0)), 8.0), "R": (Vector((-0.12, -0.1, 0.0)), -16.0)},
              hip_shift=(-0.03 * akimbo + 0.006 * w, 0.0, -0.008 + 0.012 * bounce), roll=4.0 * akimbo, yaw=3.0 * akimbo)
        p.rot("spine", 1.0 * br, -3.0 * akimbo, -3.0 * akimbo)
        p.rot("chest", 1.2 * br, -2.0 * akimbo, -2.0 * akimbo)
        tgt = wr.lerp(Vector((-0.175, 0.0, 0.905)), akimbo)
        p.ik["upper_arm.R"] = (tgt, Vector((-0.3, 1.0, 0.0)).lerp(Vector((-1.0, 0.6, 0.0)), akimbo), "hand.R", R(0, -30.0 * akimbo, 70.0 * akimbo))
        look = 16.0 * (ease((t - 1.2) / 0.6) - ease((t - 2.2) / 0.5)) - 12.0 * (ease((t - 3.8) / 0.6) - ease((t - 5.0) / 0.5))
        p.world["head"] = R(-2.0 + 1.0 * br, 4.0 * akimbo, look)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
