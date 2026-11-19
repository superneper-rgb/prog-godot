## FOINT CITY townsfolk: the spiral (working name; the user names it). A green coiled creature like a curled chameleon tail: its neck rises out of a stained beige raincoat and arches forward to a grumpy big-lipped head, its tail curls out under the coat into a spiral; mismatched footwear (a blue wellington, a brown work boot) and a closed umbrella for a cane.
# Concept: the user's sheet, image 7 bottom middle (F:/prog-godot-cache/folk/refs/7.webp), drawn side-on. Measured off it (3x crop, 1.36 mm a pixel at 1.60 m): the arch tops out at
# 1.60, the head hangs forward at 1.3 m, the spiral's eye at 1.12 m, the coil 0.15 m thick tapering to a 4 cm tip, the coat 1.42-0.6 m, the wellington 0.4 m tall, the boot 0.2;
# the depth is pulled in 15% (the coat's back to the lips about 1.0 m).
# So the coil lies in its own front-to-back plane: the side view shows the spiral as drawn; it faces -Y with the head leading.
# Rest pose: leaning on the umbrella in its right hand (tip on the ground ahead), the left index raised beside its head (the concept's "now listen here").
# Kit gaps filled here: the coil path (a tapering spiral loft with belly scutes on its inner side), hit() / normal(), hands; the limp and the cane are written in motions().
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.60
REF = ("7.webp", (385, 366, 747, 775))

(SKIN, BELLY, EYE, LIP, LIP_L, TOOTH, COAT, BUTTON, WELLY, BOOT, SOLE, LACE, UMB, HANDLE, STEEL) = range(1, 16)
COLOURS = {
    SKIN: ((0.25, 0.25, 0.08), 0.6, 0.0),
    BELLY: ((0.08, 0.2, 0.18), 0.5, 0.0),
    EYE: ((0.8, 0.4, 0.05), 0.15, 0.0),
    LIP: ((0.7, 0.2, 0.25), 0.35, 0.0),
    LIP_L: ((0.7, 0.2, 0.25), 0.35, 0.0),
    TOOTH: ((0.8, 0.75, 0.6), 0.4, 0.0),
    COAT: ((0.7, 0.55, 0.38), 0.85, 0.0),
    BUTTON: ((0.12, 0.07, 0.04), 0.4, 0.0),
    WELLY: ((0.1, 0.15, 0.28), 0.4, 0.0),
    BOOT: ((0.18, 0.08, 0.03), 0.6, 0.0),
    SOLE: ((0.05, 0.03, 0.02), 0.8, 0.0),
    LACE: ((0.25, 0.15, 0.08), 0.8, 0.0),
    UMB: ((0.6, 0.62, 0.65), 0.2, 0.0),
    HANDLE: ((0.15, 0.07, 0.04), 0.35, 0.0),
    STEEL: ((0.6, 0.6, 0.62), 0.3, 1.0),
}
F32 = np.float32
UP = np.array((0, 0, 1), F32)


def hit(shape, start, direction, far=1.5, n=500):
    d = v3(direction) / np.linalg.norm(direction)
    s = v3(start)
    ts = np.linspace(0.0, far, n).astype(F32)
    dd = shape.eval((s[None, :] + ts[:, None] * d[None, :]).astype(F32))[0]
    i = int(np.argmax(dd < 0))
    if dd[i] >= 0 or i == 0:
        raise ValueError("hit: no surface along the ray from %s" % (s,))
    a, b = float(ts[i - 1]), float(ts[i])
    for _ in range(30):
        m = 0.5 * (a + b)
        if shape.eval((s + d * m)[None, :].astype(F32))[0][0] < 0:
            b = m
        else:
            a = m
    return s + d * F32(0.5 * (a + b))


def normal(shape, p, e=0.0015):
    ex = np.eye(3, dtype=F32) * e
    g = np.array([shape.eval((p + ex[i])[None, :])[0][0] - shape.eval((p - ex[i])[None, :])[0][0] for i in range(3)], F32)
    return g / np.linalg.norm(g)


def frame(z_dir, x_dir):
    z = v3(z_dir) / np.linalg.norm(z_dir)
    x = v3(x_dir) - z * float(v3(x_dir) @ z)
    x /= np.linalg.norm(x)
    return np.stack([x, np.cross(z, x), z], 1).astype(F32)


class Bounded(Shape):
    def __init__(self, child, lo, hi):
        self.child, self.lo, self.hi, self.part = child, v3(lo), v3(hi), child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.child.eval(P)[0]


# ---------------------------------------------------------------------------------------------------- the coil

SC = v3((0.0, -0.07, 1.115))                 # the spiral's eye
DEPTH = 0.85                                 # front-to-back squeeze
TH0 = 55.0                                   # where the head joins, degrees from straight up toward the front
R_KEYS = [(0, 0.35), (52, 0.39), (142, 0.30), (232, 0.34), (322, 0.215), (412, 0.14), (502, 0.085), (560, 0.05)]
T_KEYS = [(0, 0.095), (100, 0.088), (232, 0.084), (322, 0.07), (412, 0.052), (502, 0.036), (560, 0.024)]
S_END = 560.0


def _interp(keys, s):
    ks = np.array([k for k, _ in keys], F32)
    vs = np.array([v for _, v in keys], F32)
    return np.interp(s, ks, vs)


def coil_at(s):
    """the coil's centre line at sweep s (degrees from the head end), and its thickness"""
    s = np.asarray(s, F32)
    th = np.radians(TH0 - s)
    r = _interp(R_KEYS, s)
    p = np.stack([np.zeros_like(s), SC[1] - r * np.sin(th) * DEPTH, SC[2] + r * np.cos(th)], -1)
    return p.astype(F32), _interp(T_KEYS, s)


SS = np.linspace(0.0, S_END, 71).astype(F32)
CP, CR = coil_at(SS)


def nearest_s(P):
    """(sweep s, centre point) of the coil nearest each point"""
    d = np.linalg.norm(P[:, None, :] - CP[None, :, :], axis=2) - CR[None, :] * 0.5
    i = np.argmin(d, axis=1)
    return SS[i], CP[i]


def scutes(P):
    """the belly scutes: transverse ribs on the side of the coil facing the spiral's eye"""
    s, c = nearest_s(P)
    inner = ((SC - c) * v3((0, 1.0 / DEPTH, 1.0)))
    out = (P - c)
    side = np.einsum("ij,ij->i", out, inner) / np.maximum(np.linalg.norm(out, axis=1) * np.linalg.norm(inner, axis=1), 1e-6)
    r = _interp(R_KEYS, s)
    rib = np.abs(np.sin(np.radians(s) * r * 1.0 / 0.024 * np.pi * 0.5))
    return np.clip((side - 0.15) / 0.3, 0, 1) * (rib ** 0.6 - 0.6)


HEAD_C = v3((0.0, -0.42, 1.255))
HEAD_R = rot(rx=22.0)                        # the head hangs nose-down a little
HEAD_RAD = v3((0.11, 0.165, 0.13))


def hl(p):
    """head space to world"""
    return HEAD_C + HEAD_R @ v3(p)


def coil():
    segs = [RoundCone(CP[i], CP[i + 1], CR[i], CR[i + 1], part=SKIN) for i in range(len(SS) - 1)]
    body = Union(segs, k=0.012, part=SKIN)
    body = Bump(body, scutes, 0.006)
    head = Ellipsoid(HEAD_C, HEAD_RAD, R=HEAD_R, part=SKIN)
    brow = Mirror(Ellipsoid(hl((0.0549, -0.0854, 0.0732)), (0.061, 0.061, 0.043), R=HEAD_R, part=SKIN))
    jowl = Ellipsoid(hl((0.0, -0.0732, -0.0732)), (0.092, 0.098, 0.073), R=HEAD_R, part=SKIN)
    snout = Ellipsoid(hl((0.0, -0.1403, -0.0122)), (0.061, 0.049, 0.055), R=HEAD_R, part=SKIN)
    h = Union([head, brow, jowl, snout], k=0.03, part=SKIN)
    whole = Union([body, h], k=0.05, part=SKIN)
    # eyes: orange balls under heavy grumpy lids, a bag under each
    eyes, lids = [], []
    for sx in (1.0,):
        ec = hl((0.0586 * sx, -0.128, 0.055))
        er = 0.037
        eyes.append(Sphere(ec, er, part=EYE))
        nn = HEAD_R @ v3((0.3, -1.0, 0.2))
        nn /= np.linalg.norm(nn)
        lids.append(Clip(Sphere(ec + nn * 0.002, er + 0.007, part=SKIN), [Half(ec + HEAD_R @ v3((0, 0, 0.009)), HEAD_R @ v3((0.0, 0.35, -1.0)))], k=0.003))     # heavy, half down
        lids.append(Clip(Sphere(ec - HEAD_R @ v3((0, 0, 0.024)), er + 0.004, part=SKIN), [Half(ec - HEAD_R @ v3((0, 0, 0.036)), HEAD_R @ v3((0, 0, 1)))], k=0.003))   # the bag under it
    whole = Union([whole, Mirror(Union(lids))], k=0.006)
    # nostrils, two slits above the lips
    whole = Cut(whole, [Mirror(Ellipsoid(hl((0.0195, -0.1928, -0.0366)), (0.01, 0.0075, 0.0045), R=HEAD_R @ rot(rz=20)))], k=0.002)
    # the lips: a pouting upper lip, a big drooping lower lip, the corners turned down; a row of teeth between
    up = loft([(hl((sx * 0.067, -0.159, -0.073)), 0.015) for sx in (-1.0,)] + [(hl((-0.0305, -0.1952, -0.0549)), 0.024), (hl((0.0, -0.2013, -0.0586)), 0.025),
              (hl((0.0305, -0.1952, -0.0549)), 0.024), (hl((0.0671, -0.1586, -0.0732)), 0.015)], part=LIP, k=0.015)
    lo = loft([(hl((-0.0708, -0.1525, -0.0854)), 0.016), (hl((-0.0366, -0.1952, -0.1098)), 0.03), (hl((0.0, -0.205, -0.1135)), 0.033),
               (hl((0.0366, -0.1952, -0.1098)), 0.03), (hl((0.0708, -0.1525, -0.0854)), 0.016)], part=LIP_L, k=0.015)
    teeth = [Box(hl((tx, -0.181, -0.082)), (0.01, 0.006, 0.011), rr=0.0035, R=HEAD_R @ rot(rz=tx * 250), part=TOOTH) for tx in (-0.032, -0.011, 0.011, 0.032)]
    whole = Cut(whole, [Ellipsoid(hl((0.0, -0.1708, -0.083)), (0.055, 0.036, 0.012), R=HEAD_R)], k=0.004)
    return Union([whole, up, lo] + teeth + [Mirror(e) for e in eyes], k=0.0)


# ---------------------------------------------------------------------------------------------------- the raincoat

def torso():
    return Union([Ellipsoid((0, 0.22, 1.02), (0.235, 0.21, 0.4)), Ellipsoid((0, 0.2, 1.31), (0.27, 0.19, 0.1))], k=0.08)


SH = v3((0.25, 0.19, 1.3))
CUFF = v3((0.3, 0.02, 1.03))


def coat():
    t = torso()
    shell = Cut(Inflate(t, 0.032, part=COAT), [Inflate(t, 0.012)])
    folds = lambda P: noise3(P * v3((1.4, 1.4, 0.5)), 0.06) * 0.7 + noise3(P, 0.02) * 0.3
    shell = Bump(shell, folds, 0.006)
    # the hem, the front opening the coil comes out of, the hole the neck rises through
    shell = Clip(shell, [Bump(Half((0, 0, 0.6), (0.0, 0.1, -1.0)), lambda P: noise3(P, 0.05), 0.012)], k=0.006)
    opening = Box((0.0, -0.15, 0.95), (0.075, 0.3, 0.42), rr=0.05)
    neck = RoundCone(CP[16] + v3((0, 0.02, -0.12)), CP[16] + v3((0, -0.06, 0.25)), CR[16] + 0.03, CR[16] + 0.04)
    shell = Cut(shell, [opening, neck], k=0.012)
    # the collar turned down round the neck hole, the hood hanging at the back
    collar = Clip(Cut(Inflate(t, 0.05, part=COAT), [Inflate(t, 0.03)]), [Half((0, 0, 1.33), (0, 0, -1)), Half((0, 0, 1.47), (0, 0, 1))], k=0.008)
    collar = Cut(collar, [opening, neck], k=0.01)
    hood = Cut(Ellipsoid((0, 0.36, 1.36), (0.18, 0.11, 0.14), part=COAT), [Ellipsoid((0, 0.32, 1.39), (0.15, 0.09, 0.11))], k=0.006)
    hood = Clip(hood, [Half((0, 0.3, 0), (0, -1, 0))], k=0.006)
    # wide sleeves, open at the cuff
    du = (CUFF - SH) / np.linalg.norm(CUFF - SH)
    sleeve = Clip(loft([(SH - du * 0.03, 0.08), (CUFF, 0.075)], part=COAT, k=0.02), [Half(CUFF, du)], k=0.004)
    sleeve = Cut(sleeve, [RoundCone(CUFF - du * 0.06, CUFF + du * 0.02, 0.05, 0.055)], k=0.004)
    sleeve = Bump(sleeve, folds, 0.005)
    body = Union([shell, collar, hood, Mirror(sleeve)], k=0.02, part=COAT)
    # buttons down its right front edge, flap pockets
    parts = [body]
    for bz in (1.27, 1.12, 0.97, 0.82):
        try:
            q = hit(body, (-0.1, -0.6, bz), (0, 1, 0))
        except ValueError:
            continue
        nn = normal(body, q)
        parts.append(CappedCone(q - nn * 0.004, q + nn * 0.008, 0.016, 0.015, rr=0.004, part=BUTTON))
    for sx in (1.0, -1.0):
        q = hit(body, (sx * 0.3, -0.6, 0.8), (0, 1, 0)) if False else None
    return Union(parts, k=0.0)


# ---------------------------------------------------------------------------------------------------- arms, legs, boots, umbrella

def hand(curl, thumb):
    """hand space: wrist at the origin, fingers along -Z, back of the hand +X, thumb toward -Y; long knobbly fingers"""
    parts = [RoundCone((0, 0, 0.012), (0, 0, -0.01), 0.018, 0.019, part=SKIN), Ellipsoid((0, 0, -0.03), (0.012, 0.027, 0.03), part=SKIN)]
    for i, fy in enumerate((-0.017, -0.006, 0.006, 0.017)):
        a = np.radians(curl[i])
        p = v3((0.0, fy, -0.055))
        pts = [(p, 0.0078)]
        for k, seg in enumerate((0.032, 0.024, 0.019)):
            ang = a * (k + 1) / 2.0
            p = p + v3((-np.sin(ang), 0.0, -np.cos(ang))) * seg
            pts.append((p, 0.007 - 0.0007 * k))
        parts.append(loft(pts, part=SKIN, k=0.003))
        parts.append(Sphere(pts[1][0], 0.0088, part=SKIN))
    ta = np.radians(thumb)
    t0 = v3((-0.006, -0.021, -0.016))
    t1 = t0 + v3((-0.006, -0.02, -0.015))
    t2 = t1 + v3((-0.014 * np.sin(ta), -0.008, -0.02 * np.cos(ta)))
    parts.append(loft([(t0, 0.0095), (t1, 0.0082), (t2, 0.0072)], part=SKIN, k=0.003))
    return Union(parts, k=0.005)


# its right hand on the umbrella's crook (built on the left, mirrored), its left raised with the index up
R_EL, R_WR = v3((0.3, 0.03, 1.05)), v3((0.31, -0.2, 0.9))
R_HAND = frame(-v3((0.0, -0.35, -1.0)), v3((1.0, 0.0, 0.0)))
L_EL, L_WR = v3((0.31, 0.01, 1.04)), v3((0.29, -0.4, 1.12))
L_HAND = frame(-v3((-0.1, -0.25, 1.0)), v3((1.0, -0.2, 0.1)))
FLIP = np.diag([-1.0, 1.0, 1.0]).astype(F32)
HIP = v3((0.1, 0.18, 0.66))
KNEE = v3((0.13, 0.09, 0.40))
ANKLE = v3((0.14, 0.15, 0.11))
FWD = v3((0.0, -1.0, 0.0))
BALL = v3((ANKLE[0], ANKLE[1], 0.0)) + FWD * 0.15
GRIP = R_WR + R_HAND @ v3((-0.03, 0.0, -0.06))              # where the crook sits in its fist (left-side space)
TIP = v3((0.36, -0.44, 0.0))                               # the umbrella's tip on the ground (left-side space; mirrored to its right)


def limbs():
    def arm(el, wr, R, curl, thumb):
        a = loft([(SH, 0.026), (el, 0.022), (wr, 0.018)], part=SKIN, k=0.01)
        return Union([a, Sphere(el, 0.027, part=SKIN), place(hand(curl, thumb), wr, R)], k=0.008)
    left = arm(L_EL, L_WR, L_HAND, (0.0, 95.0, 100.0, 105.0), 70.0)
    right = Move(arm(R_EL, R_WR, R_HAND, (100.0, 105.0, 105.0, 100.0), 80.0), R=FLIP)
    leg = Union([loft([(HIP, 0.033), (KNEE, 0.029), (ANKLE + v3((0, 0, 0.06)), 0.026)], part=SKIN, k=0.012),
                 Sphere(KNEE + v3((0, -0.012, 0.0)), 0.042, part=SKIN)], k=0.015)
    return Union([left, right, Mirror(leg)], k=0.0)


def welly():
    """its right foot (built on the left, mirrored): a tall blue wellington, a thick tread"""
    a = v3((ANKLE[0], ANKLE[1], 0.0))
    f = FWD
    foot = loft([(a - f * 0.06 + UP * 0.06, 0.06), (a + f * 0.08 + UP * 0.055, 0.066), (a + f * 0.18 + UP * 0.045, 0.052)], part=WELLY, k=0.04)
    shaft = CappedCone(a + UP * 0.05, a + UP * 0.4, 0.072, 0.08, rr=0.012, part=WELLY)
    up = Union([foot, shaft], k=0.05, part=WELLY)
    up = Clip(up, [Half(UP * 0.02, -UP)])
    up = Cut(up, [CappedCone(a + UP * 0.25, a + UP * 0.45, 0.06, 0.068)], k=0.006)
    sole = Clip(Inflate(foot, 0.008, part=SOLE), [Half(UP * 0.035, UP), Half((0, 0, 0), -UP)], k=0.003)
    sole = Bump(sole, lambda P: np.sign(np.sin(P[:, 1] * 260.0)) * (P[:, 2] < 0.012), 0.002)
    rim = Torus(a + UP * 0.4, 0.074, 0.008, part=WELLY)
    return Union([up, sole, rim], k=0.0)


def boot():
    """its left foot: a scuffed brown lace-up work boot, a patch on the toe"""
    a = v3((ANKLE[0], ANKLE[1], 0.0))
    f = FWD
    side = np.cross(UP, f)
    foot = loft([(a - f * 0.06 + UP * 0.055, 0.058), (a + f * 0.08 + UP * 0.052, 0.064), (a + f * 0.18 + UP * 0.045, 0.054)], part=BOOT, k=0.04)
    shaft = CappedCone(a + UP * 0.05, a + UP * 0.19, 0.062, 0.058, rr=0.012, part=BOOT)
    up = Clip(Union([foot, shaft], k=0.04, part=BOOT), [Half(UP * 0.02, -UP)])
    patch = Clip(Inflate(foot, 0.004, part=BOOT), [Half(a + f * 0.13, -f), Half(UP * 0.12, UP)], k=0.004)
    sole = Clip(Inflate(foot, 0.009, part=SOLE), [Half(UP * 0.038, UP), Half((0, 0, 0), -UP)], k=0.003)
    collar = Torus(a + UP * 0.19, 0.056, 0.011, part=BOOT)
    laces = []
    for j in range(5):
        p = a + f * (0.12 - 0.022 * j)
        s = hit(up, p + UP * 0.4, -UP)
        for sg in (-1.0, 1.0):
            d = side * 0.026 * sg + f * 0.008
            laces.append(RoundCone(s - d + UP * 0.004, s + d + UP * 0.004, 0.0045, part=LACE))
    bow = [loft([(a + f * 0.03 + UP * 0.2, 0.004), (a + f * 0.06 + side * sg * 0.03 + UP * 0.21, 0.004), (a + f * 0.07 + side * sg * 0.035 + UP * 0.16, 0.004)], part=LACE, k=0.003)
           for sg in (-1.0, 1.0)]
    return Union([up, patch, sole, collar] + laces + bow, k=0.0)


def umbrella():
    """a closed clear umbrella with a dark wooden crook, held by the crook, its tip on the ground (left-side space, mirrored to its right hand)"""
    top = GRIP - v3((0, 0, 0.0))
    d = (TIP - top) / np.linalg.norm(TIP - top)
    sidev = np.cross(d, v3((1, 0, 0)))
    sidev /= np.linalg.norm(sidev)
    crook = Clip(Torus(top + sidev * 0.04, 0.04, 0.011, Rm=frame(np.cross(d, sidev), d), part=HANDLE), [Half(top + sidev * 0.04 - d * 0.0, d)], k=0.002)
    stem = RoundCone(top, top + d * 0.12, 0.011, 0.01, part=HANDLE)
    shaft = RoundCone(top + d * 0.1, TIP - d * 0.02, 0.006, 0.005, part=STEEL)
    can_a, can_b = top + d * 0.17, TIP - d * 0.1
    canopy = CappedCone(can_a, can_b, 0.045, 0.012, rr=0.008, part=UMB)
    pleats = lambda P: np.sin(np.arctan2((P - can_a) @ sidev, (P - can_a) @ np.cross(d, sidev)) * 8.0 + ((P - can_a) @ d) * 9.0)
    canopy = Bump(canopy, pleats, 0.004)
    strap = Torus(can_a + d * 0.12, 0.04, 0.006, Rm=frame(d, sidev), part=UMB)
    tip = CappedCone(TIP - d * 0.03, TIP, 0.007, 0.004, rr=0.002, part=STEEL)
    return Union([crook, stem, shaft, canopy, strap, tip], k=0.004)


def pieces():
    import os
    q = float(os.environ.get("FOLK_DRAFT", "1"))
    return [("coil", coil(), 0.0024 * q), ("coat", coat(), 0.003 * q), ("limbs", limbs(), 0.0017 * q),
            ("boots", Union([Move(welly(), R=FLIP), boot()]), 0.0024 * q), ("umbrella", Move(umbrella(), R=FLIP), 0.0016 * q)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.04) * 0.5 + noise3(P, 0.012) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, F32)], 1)

    def lerp(a, b, t):
        t = np.asarray(t, F32)
        return a + (b - a) * (t[:, None] if t.ndim else t)

    def full(col):
        return np.broadcast_to(srgb(*col), (n, 3)).copy()

    # the coil: olive with mauve-brown camouflage patches; its inner side teal, the scutes' grooves dark
    m = c.mask(SKIN)
    sk = full((150, 150, 78))
    sk = lerp(sk, srgb(174, 170, 96), smooth(0.2, 0.9, c.N[:, 2]) * 0.4)
    sk *= (1.0 + 0.07 * mott)[:, None]
    patch = smooth(0.12, 0.2, noise3(Q * v3((1, 1, 1)) + 2.0, 0.05) * 0.75 + noise3(P, 0.012) * 0.25)
    sk = lerp(sk, srgb(150, 110, 92), patch * 0.75)
    s_, cpt = nearest_s(P)
    inner = (SC - cpt) * v3((0, 1.0 / DEPTH, 1.0))
    out = P - cpt
    side = np.einsum("ij,ij->i", out, inner) / np.maximum(np.linalg.norm(out, axis=1) * np.linalg.norm(inner, axis=1), 1e-6)
    on_coil = (np.linalg.norm(P - HEAD_C, axis=1) > 0.16) & (np.linalg.norm(P - cpt, axis=1) < _interp(T_KEYS, s_) + 0.03)      # the coil only, not the arms
    belly = smooth(0.0, 0.3, side) * on_coil
    sk = lerp(sk, srgb(82, 136, 128), belly * 0.9)
    sk = lerp(sk, srgb(40, 70, 66), belly * c.cavity * 0.8)
    # the face: lids and bags a darker green, a crease of a scowl
    sk = lerp(sk, srgb(104, 110, 56), c.cavity * 0.5)
    put(m, sk, 0.5, bump=0.3, grain=1.0)
    spk(m, (110, 84, 56), 0.3)

    # eyes: orange-yellow all over, a small dark pupil looking ahead and down, a glint
    m = c.mask(EYE)
    ey = full((240, 170, 52))
    for sx in (1.0, -1.0):
        ec = hl((0.0586 * sx, -0.128, 0.055))
        d = P - ec
        dl = np.maximum(np.linalg.norm(d, axis=1), 1e-6)
        dn = d / dl[:, None]
        g = HEAD_R @ v3((0.1 * sx, -1.0, -0.15))
        g /= np.linalg.norm(g)
        mine = m & (dl < 0.045)
        ey[mine] = lerp(ey, srgb(196, 112, 30), smooth(0.5, 1.3, np.arccos(np.clip(dn @ g, -1, 1))))[mine]
        c.draw(mine, np.arccos(np.clip(dn @ g, -1, 1)) * 0.03 - 0.28 * 0.03, 0.0)
        gl = smooth(0.02, 0.006, (dn[:, 0] + 0.3 * sx * 0 - 0.25) ** 2 + (dn[:, 2] - 0.5) ** 2) * mine
        ey = lerp(ey, srgb(255, 250, 230), gl)
    put(m, ey, 0.1)
    m = c.mask(LIP, LIP_L)
    lp = lerp(full((228, 116, 128)), srgb(170, 66, 84), smooth(0.4, 0.95, -c.N[:, 2]) * 0.35)
    lp = lerp(lp, srgb(246, 160, 170), c.wear * 0.35)
    put(m, lp, 0.25, bump=0.15)
    put(c.mask(TOOTH), srgb(230, 220, 190), 0.35)

    # the raincoat: stone-beige cotton, blotched with tea-brown stains, darker at the hem
    m = c.mask(COAT)
    co = full((222, 196, 156))
    co *= (1.0 + 0.05 * mott)[:, None]
    stain = smooth(0.08, 0.3, noise3(P + 7.0, 0.035) * 0.7 + noise3(P, 0.01) * 0.3)
    co = lerp(co, srgb(168, 112, 62), stain * 0.6)
    co = lerp(co, srgb(140, 100, 64), smooth(0.7, 0.6, z) * 0.4)
    co = lerp(co, srgb(120, 88, 58), c.cavity * 0.5)
    put(m, co, 0.85, bump=1.0)
    spk(m, (150, 100, 56), 0.35)
    put(c.mask(BUTTON), srgb(84, 56, 38) * (1.0 + 0.5 * c.wear)[:, None], 0.35)

    # limbs: olive-khaki, darker in the knuckle creases
    # (the limbs share SKIN with the coil above: nothing more to do)

    # footwear: a blue wellington spattered with mud; a brown boot with a tan patch; dark soles
    m = c.mask(WELLY)
    wl = full((84, 104, 148))
    wl = lerp(wl, srgb(150, 168, 200), c.wear * 0.4)
    mud = smooth(0.15, 0.35, noise3(P + 3.0, 0.03) * 0.7 + noise3(P, 0.01) * 0.3) * (0.5 + 0.5 * smooth(0.3, 0.05, z))
    wl = lerp(wl, srgb(160, 116, 70), mud * 0.8)
    put(m, wl, 0.35, bump=0.15)
    spk(m, (170, 120, 70), 0.4)
    m = c.mask(BOOT)
    bt = full((112, 70, 44))
    a = v3((ANKLE[0], ANKLE[1], 0.0))
    toe = (y < a[1] + FWD[1] * 0.13) & (z < 0.12) & (x > 0)
    bt = np.where(toe[:, None], srgb(168, 112, 66), bt)
    bt = lerp(bt, srgb(170, 130, 96), c.wear * 0.5)
    put(m, bt, 0.6, bump=0.9, grain=1.0)
    c.draw(m & toe, np.abs(y - (a[1] + FWD[1] * 0.13)), 0.0008, 0.5)
    put(c.mask(SOLE), lerp(full((60, 44, 34)), srgb(140, 110, 80), smooth(0.2, 0.8, noise3(P, 0.012)) * 0.4), 0.85, bump=0.6, grain=1.0)
    put(c.mask(LACE), srgb(92, 60, 38), 0.8)

    # the umbrella: clear plastic gone milky, a few dark creases; steel; the crook dark polished wood
    m = c.mask(UMB)
    put(m, lerp(full((204, 210, 214)), srgb(150, 156, 162), c.cavity * 0.7), 0.15, bump=0.1)
    put(c.mask(HANDLE), srgb(86, 50, 32) * (1.0 + 0.6 * c.wear)[:, None], 0.3, grain=1.0, bump=0.2)
    put(c.mask(STEEL), srgb(180, 182, 186), 0.3, metal=1.0)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"coil": 3600, "coat": 2200, "limbs": 1300, "boots": 1300, "umbrella": 500},
    "density": {"coil": 1.3, "umbrella": 1.1},
    "tex": 2048,
    "stride": {"walk": 0.8, "run": 1.2},
    "speed": 0.75,
    "look": ["head"], "neck": "neck.2",
    "look_pivot": tuple(coil_at(0.0)[0].tolist()),
    "radius": 0.5,
}
NECK_S = [142.0, 100.0, 52.0, 0.0]          # chest -> neck.0 -> neck.1 -> neck.2 -> head
TAIL_S = [142.0, 232.0, 322.0, 412.0, 560.0]


def rig_bones():
    from kit.rig import Bone, mirror
    P = lambda s: coil_at(s)[0]
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.18, 0.62), (0, 0.2, 0.9), "root", 0.2),
        Bone("chest", (0, 0.2, 0.9), (0, 0.2, 1.35), "hips", 0.25),
        Bone("shoulder.L", (0.08, 0.2, 1.3), SH, "chest", 0.05),
        Bone("thigh.L", HIP, KNEE, "hips", 0.035),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.03),
        Bone("foot.L", ANKLE, v3((ANKLE[0], ANKLE[1], 0.03)) + FWD * 0.2, "shin.L", 0.06),
    ])
    par = "chest"
    for i in range(3):
        bones.append(Bone("neck.%d" % i, P(NECK_S[i]), P(NECK_S[i + 1]), par, 0.08))
        par = "neck.%d" % i
    bones.append(Bone("head", P(0.0), HEAD_C + HEAD_R @ v3((0, -0.15, 0)), "neck.2", 0.12))
    bones.append(Bone("jaw", hl((0.0, -0.1342, -0.0732)), hl((0.0, -0.2196, -0.1098)), "head", 0.02))
    par = "chest"
    for i in range(4):
        bones.append(Bone("tail.%d" % i, P(TAIL_S[i]), P(TAIL_S[i + 1]), par, 0.07))
        par = "tail.%d" % i
    for sd, el, wr, R, f in (("L", L_EL, L_WR, L_HAND, np.eye(3, dtype=F32)), ("R", R_EL, R_WR, R_HAND, FLIP)):
        hend = wr - R[:, 2] * 0.05
        bones += [Bone("upper_arm." + sd, f @ SH, f @ el, "shoulder." + sd, 0.024), Bone("forearm." + sd, f @ el, f @ wr, "upper_arm." + sd, 0.02),
                  Bone("hand." + sd, f @ wr, f @ hend, "forearm." + sd, 0.02)]
    return bones


def skin_rules(P, part, piece, names):
    """pieces: 0 coil, 1 coat, 2 limbs, 3 boots, 4 umbrella"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    cp = piece == 0
    s, _ = nearest_s(P)
    head = cp & (np.linalg.norm(((P - HEAD_C) @ HEAD_R) / (HEAD_RAD + 0.03), axis=1) < 1.0)
    head |= cp & ~np.isin(part, (SKIN, BELLY))
    allow(cp & ~head & (s >= 110), "chest")
    for i in range(3):
        lo_, hi_ = NECK_S[i + 1], NECK_S[i]
        allow(cp & ~head & (s <= hi_ + 30) & (s >= lo_ - 30) & (s < 142.0 + 30), "neck.%d" % i)
    for i in range(4):
        lo_, hi_ = TAIL_S[i], TAIL_S[i + 1]
        allow(cp & ~head & (s >= lo_ - 30) & (s <= hi_ + 30) & (s > 142.0 - 30), "tail.%d" % i)
    allow(head, "head", "neck.2")
    rig[head] = ix["head"]
    rig[cp & np.isin(part, (LIP_L,))] = ix["jaw"]
    allow(piece == 1, "hips", "chest")
    allow((piece == 1) & (x > 0.2) & (z > 1.0), "shoulder.L", "upper_arm.L")
    allow((piece == 1) & (x < -0.2) & (z > 1.0), "shoulder.R", "upper_arm.R")
    lp = piece == 2
    for sgn, sd, wr, R in ((1, "L", L_WR, L_HAND), (-1, "R", R_WR * v3((-1, 1, 1)), FLIP @ R_HAND)):
        arm = lp & (x * sgn > 0) & (z > 0.8)
        allow(arm, "shoulder." + sd, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        rig[arm & (((P - wr) @ (-R[:, 2])) > 0.006)] = ix["hand." + sd]
        leg = lp & (x * sgn > 0) & (z <= 0.8)
        allow(leg, "thigh." + sd, "shin." + sd)
        allow(leg & (z > 0.6), "hips")
    bp = piece == 3
    for sgn, sd in ((1, "L"), (-1, "R")):
        m = bp & (x * sgn > 0)
        allow(m, "shin." + sd, "foot." + sd)
        rig[m & ((z < 0.1) | (part == SOLE))] = ix["foot." + sd]
        allow(m & (z > 0.1), "shin." + sd)
    rig[piece == 4] = ix["hand.R"]
    allow(piece == 4, "hand.R")
    return A, rig


WALK = dict(stride=0.8, beta={"L": 0.64, "R": 0.5}, lift={"L": 0.06, "R": 0.035}, bob=0.025, dip=0.03, drop=0.025, sway=0.03, toe_off=12.0, swing=8.0)
RUN = dict(stride=1.2, beta={"L": 0.48, "R": 0.38}, lift={"L": 0.1, "R": 0.06}, bob=0.04, dip=0.05, drop=0.05, sway=0.03, toe_off=18.0, swing=12.0)


def motions(rig):
    """walk: a lilting limp: the wellington leg (its right) is the sore one: short, stiff steps the body dips onto, the umbrella planted alongside to take
    the weight, the left stepping long and light; the neck's arch rises and falls in a sing-song and the head stays level and grumpy, the tail coil
    wobbling; run: a hurried hobble; idle: leaning on the umbrella, lecturing with the raised finger, the lower lip grumbling, the coil breathing"""
    import math
    from kit.gait import Pose, Leg, R, solve, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], F32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    tip0 = Vector((TIP * f).tolist())
    grip0 = Vector((GRIP * f).tolist())
    wr0 = Vector((R_WR * f).tolist())
    cane_len = (grip0 - tip0).length

    def foot(p, lg, ball, pitch):
        s = 1.0 if lg.side == "L" else -1.0
        wf = Matrix.Rotation(math.radians(pitch), 3, Vector((1, 0, 0)))
        ankle = ball + wf @ (rig.head[lg.foot] - lg.ball)
        p.ik[lg.thigh] = (ankle, Vector((s * 0.1, -1.0, 0.0)), lg.foot, wf)

    def cane(p, tip, lean):
        """the umbrella's tip at `tip`, its crook where the right hand naturally hangs: the hand follows the crook"""
        A = solve(rig, p)
        want = A["chest"] @ grip0 + Vector((0.0, -lean, 0.0))
        d = (want - tip).normalized()
        grip = tip + d * cane_len
        Rc = (grip0 - tip0).normalized().rotation_difference(d).to_matrix()
        wr = grip + Rc @ (wr0 - grip0)
        p.ik["upper_arm.R"] = (wr, Vector((-1.0, 0.3, -0.4)), "hand.R", Rc)

    def neckish(p, a, b, head_pitch, tail):
        p.rot("neck.0", a, 0.0, 0.0)
        p.rot("neck.1", b, 0.0, 0.0)
        p.rot("neck.2", -0.5 * (a + b), 0.0, 0.0)
        p.world["head"] = R(head_pitch, 0.0, 0.0)
        for i in range(4):
            p.rot("tail.%d" % i, tail * (1.0 + 0.3 * i), 0.0, 0.0)

    def walkish(u, g, run):
        p = Pose()
        S = g["stride"]
        sw = math.sin(TAU * u)
        # the limp: the body dips while the sore right foot carries it (u 0.5 .. 0.5 + beta_R), and rises off the good left
        uR = (u - 0.5) % 1.0
        dip = math.sin(math.pi * min(1.0, uR / g["beta"]["R"])) if uR < g["beta"]["R"] else 0.0
        p.offset = Vector((g["sway"] * sw, 0.0, -g["drop"] + g["bob"] * math.cos(2 * TAU * (u - 0.3)) - g["dip"] * dip))
        p.rot("hips", 2.0 + (8.0 if run else 0.0), -3.0 * dip + 2.0 * sw, -5.0 * math.cos(TAU * u))
        p.rot("chest", 0.0, 2.0 * dip, 3.0 * math.cos(TAU * u))
        for lg in legs:
            side = lg.side
            beta = g["beta"][side]
            uu = (u + (0.0 if side == "L" else 0.5)) % 1.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                lift, pitch = 0.0, g["toe_off"] * ease((uu - (beta - 0.15)) / 0.15) * (0.4 if side == "R" else 1.0)
            else:
                t = (uu - beta) / (1.0 - beta)
                fy = S * beta / 2 - S * beta * ease(t)
                lift = g["lift"][side] * math.sin(math.pi * t) ** 0.8
                pitch = g["toe_off"] * (1.0 - ease(t * 1.6)) * (0.4 if side == "R" else 1.0) - g["swing"] * math.sin(math.pi * t)
            foot(p, lg, Vector((lg.ball.x, lg.ball.y + fy, lift)), pitch)
        # the neck's sing-song and the grumpy, level head
        lilt = math.sin(2 * TAU * u - 0.8)
        neckish(p, 3.0 * lilt + 2.0 * dip, -2.0 * lilt, 2.0 + (6.0 if run else 0.0) + 1.5 * math.sin(2 * TAU * u), 2.0 * math.sin(TAU * u - 1.4))
        # the umbrella: planted beside the sore foot while it carries the weight, swung ahead with it
        bR = g["beta"]["R"]
        if uR < bR:
            cy = -S * bR / 2 + S * uR
            cl = 0.0
        else:
            t = (uR - bR) / (1.0 - bR)
            cy = S * bR / 2 - S * bR * ease(t)
            cl = 0.05 * math.sin(math.pi * t)
        cane(p, Vector((tip0.x, tip0.y + cy, tip0.z + cl)), 0.0)
        # the raised finger wags as it walks; the lower lip grumbles
        p.rot("upper_arm.L", 4.0 * math.sin(TAU * u), 0.0, 0.0)
        p.rot("hand.L", 0.0, 0.0, 10.0 * math.sin(2 * TAU * u))
        p.rot("jaw", 4.0 + 3.0 * max(0.0, math.sin(3 * TAU * u)), 0.0, 0.0)
        return p

    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    def win(t, a, b, e=0.35):
        return ease((t - a) / e) * (1.0 - ease((t - b) / e))

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        lean = 0.5 + 0.5 * math.sin(TAU * t / 6.0)
        p.offset = Vector((-0.015 * lean, 0.0, -0.012 + 0.004 * math.sin(TAU * t / 3.0)))
        p.rot("hips", 1.0, -2.0 * lean, 0.0)
        for lg in legs:
            foot(p, lg, Vector((lg.ball.x, lg.ball.y, 0.0)), 0.0)
        lec = win(t, 1.2, 3.4)                            # lecturing: the finger jabs, the head pushes forward, the lip works
        neckish(p, 2.0 * math.sin(TAU * t / 3.0) - 4.0 * lec, 1.5 * math.sin(TAU * t / 3.0 + 1.0) + 3.0 * lec,
                2.0 + 5.0 * lec * max(0.0, math.sin(TAU * t * 1.6)), 1.5 * math.sin(TAU * t / 6.0))
        cane(p, tip0, 0.0)
        p.rot("upper_arm.L", -6.0 * lec, 0.0, 0.0)
        p.rot("forearm.L", -10.0 * lec * max(0.0, math.sin(TAU * t * 1.6)), 0.0, 0.0)
        p.rot("hand.L", 0.0, 0.0, 14.0 * math.sin(TAU * t * 0.8) * (1.0 - lec))
        p.rot("jaw", 3.0 + 9.0 * lec * max(0.0, math.sin(TAU * t * 3.2)) + 2.0 * math.sin(TAU * t / 2.0) ** 2, 0.0, 0.0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
