## FOINT CITY townsfolk: the jelly worker (working name; the user names it). An orange see-through jelly bell with its innards showing, three bug eyes on top, a pursed little mouth, a one-ear headset with an antenna, a work belt of pouches, five thin legs in little work boots.
# Concept: the user's sheet, image 7 top middle (F:/prog-godot-cache/folk/refs/7.webp). Measured off it (3x crop, 1.47 mm a pixel at 1.40 m to the top of the bell): the bell is
# 1.22 m across (the jelly is wider than its legs), its scalloped rim at 1.0 m, the lower bell (orange, the innards) down to the belt at 0.8 m; the eyes 0.13-0.16 m
# across, the biggest on its right; five legs (the lead: five, as drawn) about 2 cm thick, three in front and two behind; boots 0.18 m long. No props (the drill is dropped).
# Rest pose: standing on its five legs, the right hand up with the index raised (the concept's "well, actually"), the left hand open.
# The jelly's see-through look is painted: an opaque game shader, so the innards are drawn on the lower bell where they show through.
# Kit gaps filled here: hit() / normal() (probe the clay to seat features on it), Bounded, hand frames; the five-legged ripple gait and the jelly's rim ripple are written in motions().
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.40
REF = ("7.webp", (392, 9, 756, 362))

(JELLY, EYE, LIP, CUP, BAND, PAD, METAL, BELT, POUCH, RADIO, SCREEN, TAPE, SKIN, LEG, BOOT, SOLE, LACE) = range(1, 18)
COLOURS = {
    JELLY: ((0.85, 0.18, 0.06), 0.15, 0.0),
    EYE: ((0.88, 0.78, 0.55), 0.1, 0.0),
    LIP: ((0.7, 0.2, 0.2), 0.25, 0.0),
    CUP: ((0.8, 0.5, 0.02), 0.4, 0.0),
    BAND: ((0.02, 0.02, 0.02), 0.4, 0.0),
    PAD: ((0.01, 0.01, 0.01), 0.9, 0.0),
    METAL: ((0.6, 0.6, 0.62), 0.35, 1.0),
    BELT: ((0.13, 0.06, 0.02), 0.6, 0.0),
    POUCH: ((0.55, 0.36, 0.06), 0.8, 0.0),
    RADIO: ((0.05, 0.05, 0.06), 0.5, 0.0),
    SCREEN: ((0.4, 0.45, 0.1), 0.2, 0.0),
    TAPE: ((0.6, 0.55, 0.48), 0.6, 0.0),
    SKIN: ((0.62, 0.22, 0.13), 0.45, 0.0),
    LEG: ((0.22, 0.02, 0.03), 0.2, 0.0),
    BOOT: ((0.13, 0.07, 0.04), 0.6, 0.0),
    SOLE: ((0.04, 0.03, 0.02), 0.8, 0.0),
    LACE: ((0.7, 0.4, 0.04), 0.7, 0.0),
}
F32 = np.float32
UP = np.array((0, 0, 1), F32)


# ---------------------------------------------------------------------------------------------------- helpers the kit lacks

class ERing(Shape):
    """a torus whose centre line is an ellipse: semi-axes a (local x) and b (local y) in the local XY plane of R, tube radius r"""
    def __init__(self, c, a, b, r, R=None, part=0):
        self.c, self.e, self.r, self.part = v3(c), np.array([a, b], F32), F32(r), part
        self.R = np.eye(3, dtype=F32) if R is None else np.asarray(R, F32)
        m = max(a, b) + r
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.R
        q2 = q[:, :2]
        k0 = np.sqrt(((q2 / self.e) ** 2).sum(1))
        k1 = np.sqrt(((q2 / (self.e * self.e)) ** 2).sum(1))
        rho = np.where(k0 < 1e-6, -float(self.e.min()), k0 * (k0 - 1.0) / np.maximum(k1, 1e-9))
        return np.sqrt(rho * rho + q[:, 2] ** 2) - self.r


class Bounded(Shape):
    """the child with a tighter bound than it works out itself"""
    def __init__(self, child, lo, hi):
        self.child, self.lo, self.hi, self.part = child, v3(lo), v3(hi), child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.child.eval(P)[0]


def hit(shape, start, direction, far=1.5, n=500):
    """where a ray from `start` first enters `shape`"""
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


def azi(deg, r=1.0, z=0.0):
    """a point at azimuth deg (0 = straight ahead, -Y; +90 = its left, +X), radius r, height z"""
    a = np.radians(deg)
    return v3((np.sin(a) * r, -np.cos(a) * r, z))


def frame(z_dir, x_dir):
    """columns x, y, z: local +Z along z_dir, local +X leaning to x_dir"""
    z = v3(z_dir) / np.linalg.norm(z_dir)
    x = v3(x_dir) - z * float(v3(x_dir) @ z)
    x /= np.linalg.norm(x)
    return np.stack([x, np.cross(z, x), z], 1).astype(F32)


# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; the figure faces -Y)

CAP_C = v3((0.0, 0.0, 1.02))
CAP_R = v3((0.56, 0.48, 0.38))
JELLY_AXIS = v3((0.0, 0.0, 0.98))
EYES = [("eye.R", -0.172, 1.205, 0.080), ("eye.C", 0.0, 1.235, 0.073), ("eye.L", 0.162, 1.2, 0.066)]     # name, x, z, radius (its right eye the biggest)
MOUTH = (0.04, 1.108)
LEG_AZ = [0.0, 72.0, 144.0, 216.0, 288.0]                    # 0 front centre, 1 front left, 2 back left, 3 back right, 4 front right
LEG_YAW = [0.0, 14.0, 7.0, -7.0, -14.0]                     # boots toe out a little
HIPS = [azi(a, 0.3, 0.795) for a in LEG_AZ]
KNEES = [azi(a, 0.43, 0.45) + v3((0, -0.012, 0)) for a in LEG_AZ]       # knees bowed out a little: slack for the stride
ANKLES = [azi(a, 0.38, 0.085) for a in LEG_AZ]
FWDS = [rot(rz=y) @ v3((0, -1, 0)) for y in LEG_YAW]
BALLS = [v3((a[0], a[1], 0.0)) + f * 0.055 for a, f in zip(ANKLES, FWDS)]
SH = v3((0.36, -0.05, 0.965))                                # the shoulder, tucked under the rim (left; the right arm is its own pose)
EL_L, WR_L = v3((0.585, -0.12, 0.80)), v3((0.5, -0.37, 0.885))
EL_R, WR_R = v3((0.565, -0.19, 0.79)), v3((0.43, -0.43, 0.89))       # (built on the left, mirrored): in front of the rim
HAND_L = frame(-v3((0.35, -1.0, 0.3)), v3((0.1, 0.2, -1.0)))         # open, palm up, fingers out front
HAND_R = frame(-v3((-0.12, -0.3, 1.0)), v3((1.0, 0.25, 0.05)))       # the index raised
FLIP = np.diag([-1.0, 1.0, 1.0]).astype(F32)


# ---------------------------------------------------------------------------------------------------- the jelly bell

def scallop(P):
    th = np.arctan2(P[:, 0], -P[:, 1])
    rim = np.clip((1.17 - P[:, 2]) / 0.12, 0.0, 1.0)
    return np.sin(7.0 * th + 0.4) * rim * 0.8 + noise3(P, 0.13) * 0.55 + noise3(P, 0.05) * 0.2


def bell():
    """the jelly without its face: a lumpy dome, its scalloped rim hanging over a rounder lower bell"""
    flare = ERing((0, 0, 1.0), 0.545, 0.465, 0.055)                # the bell's margin flares out past the dome
    cap = Bump(Union([Ellipsoid(CAP_C, CAP_R), flare], k=0.07), scallop, 0.026)
    cap = Cut(cap, [Ellipsoid((0, 0, 0.70), (0.92, 0.80, 0.33))], k=0.035)
    lower = Clip(Ellipsoid((0, 0.0, 0.95), (0.43, 0.37, 0.33)), [Half((0, 0, 0.765), (0, 0, -1))], k=0.06)
    lower = Bump(lower, lambda P: noise3(P + 2.0, 0.09), 0.01)
    return Union([cap, lower], k=0.05, part=JELLY)


def eye_points():
    b = bell()
    out = []
    for name, x, z, r in EYES:
        s = hit(b, (x, -1.2, z), (0, 1, 0))
        n = normal(b, s)
        d = n + v3((0, -0.8, 0))
        d /= np.linalg.norm(d)
        out.append((name, s + d * (r * 0.5), d, r))          # bug eyes: bulging forward off the bell's face
    return out


def jelly():
    b = bell()
    lids, balls = [], []
    for name, c, n, r in eye_points():
        lids.append(Torus(c - n * (r * 0.15), r * 0.93, 0.017, Rm=basis(n, UP), part=JELLY))         # a thick jelly lid round each eye
        lids.append(Clip(Sphere(c - n * 0.012, r + 0.02, part=JELLY), [Half(c - n * (r * 0.1), n)], k=0.01))
        balls.append(Sphere(c, r, part=EYE))
    face = Union([b] + lids, k=0.025, part=JELLY)
    # the pursed mouth: a puckered ring, its hole dark
    s = hit(b, (MOUTH[0], -1.2, MOUTH[1]), (0, 1, 0))
    n = normal(b, s)
    M = basis(n, UP)
    s0 = s * v3((0.0, 1.0, 1.0))           # built on the centre line, then slid over to where the mouth sits
    lips = Union([Mirror(Ellipsoid(s0 + M @ v3((0.011, 0.009, 0.009)), (0.022, 0.0095, 0.011), R=M @ rot(rz=-12, rx=-12), part=LIP)),   # a pouting upper lip, two lobes
                  Ellipsoid(s0 + M @ v3((0, -0.011, 0.01)), (0.03, 0.0125, 0.013), R=M @ rot(rx=14), part=LIP)], k=0.007)                # the fuller lower lip
    lips = Move(lips, t=(float(s[0]), 0.0, 0.0))
    face = Union([face, lips], k=0.008)
    face = Cut(face, [Ellipsoid(s + M @ v3((0.0, -0.001, 0.02)), (0.016, 0.0032, 0.02), R=M)], k=0.002)
    return Union([face] + balls, k=0.0)


# ---------------------------------------------------------------------------------------------------- the headset (one ear cup on its right, a band over the top, the antenna, the mic)

def headset():
    b = bell()
    d0 = azi(-52.0)
    s = hit(b, d0 * 1.2 + v3((0, 0, 1.23)), -d0)
    n = normal(b, s)
    cup = CappedCone(s - n * 0.012, s + n * 0.045, 0.072, 0.066, rr=0.012, part=CUP)
    ring = Torus(s + n * 0.04, 0.064, 0.0085, Rm=basis(n, UP), part=BAND)
    hub = CappedCone(s + n * 0.04, s + n * 0.052, 0.036, 0.034, rr=0.004, part=BAND)
    cushion = Torus(s - n * 0.004, 0.058, 0.015, Rm=basis(n, UP), part=PAD)
    tip = s + n * 0.075 + UP * 0.17 - d0 * 0.03
    ant = Union([RoundCone(s + n * 0.035 + UP * 0.055, tip, 0.0065, 0.0042, part=BAND), Sphere(tip, 0.0085, part=METAL)], k=0.002)
    # the band: up over the bell from the cup to a pad on the far side
    pts = []
    for a in np.linspace(0.42, 2.75, 15):
        dd = d0 * np.cos(a) + UP * np.sin(a)
        p = hit(b, JELLY_AXIS + dd * 1.0, -dd)
        pts.append((p + normal(b, p) * 0.011, 0.0105))
    band = loft(pts, part=BAND, k=0.01)
    far = pts[-1][0]
    pad = Ellipsoid(far, (0.03, 0.03, 0.03), part=PAD)
    # the mic boom: from the cup's front, along the bell toward the mouth
    mpts = [s + n * 0.035 - UP * 0.035 + v3((0.0, -0.02, 0.0))]
    for az, z, off in ((-38.0, 1.155, 0.04), (-22.0, 1.125, 0.045), (-12.0, 1.118, 0.05)):
        q = hit(b, azi(az, 1.2, z), -azi(az))
        mpts.append(q + normal(b, q) * off)
    boom = loft([(p, 0.0055) for p in mpts], part=BAND, k=0.01)
    mic = Ellipsoid(mpts[-1], (0.016, 0.02, 0.014), part=PAD)
    return Union([cup, ring, hub, cushion, ant, band, pad, boom, mic], k=0.0)


# ---------------------------------------------------------------------------------------------------- the work belt

def gear():
    lower = Clip(Ellipsoid((0, 0.0, 0.95), (0.43, 0.37, 0.33)), [Half((0, 0, 0.765), (0, 0, -1))], k=0.06)
    belt = Bounded(Clip(Inflate(lower, 0.013, part=BELT), [Half((0, 0, 0.832), (0, 0, 1)), Half((0, 0, 0.778), (0, 0, -1))], k=0.003),
                   (-0.48, -0.42, 0.75), (0.48, 0.42, 0.86))
    parts = [belt]

    def on_belt(az, z=0.805):
        p = hit(belt, azi(az, 1.0, z), -azi(az))
        nn = normal(belt, p)
        nn[2] = 0.0
        nn /= np.linalg.norm(nn)
        return p, nn, frame(nn, np.cross(UP, nn))      # local x along the belt, y up, z out

    p, nn, R = on_belt(0.0)
    buckle = Cut(Box(p + nn * 0.004, (0.04, 0.03, 0.006), rr=0.003, R=R, part=METAL), [Box(p + nn * 0.004, (0.026, 0.017, 0.02), rr=0.002, R=R)], k=0.002)
    parts += [buckle, Box(p + nn * 0.004, (0.003, 0.016, 0.004), rr=0.0015, R=R, part=METAL)]
    for az in (-18.0, 18.0, -75.0, 75.0):
        q, qn, QR = on_belt(az)
        parts.append(Box(q + qn * 0.006, (0.009, 0.032, 0.005), rr=0.003, R=QR, part=POUCH))            # keepers
    # the double pouch on its right front, a card sticking out of one
    for off in (-0.046, 0.046):
        q, qn, QR = on_belt(-44.0)
        c = q + QR[:, 0] * off + qn * 0.026 - UP * 0.035
        parts.append(Box(c, (0.04, 0.056, 0.024), rr=0.01, R=QR, part=POUCH))
        parts.append(Box(c + qn * 0.022 + UP * 0.03, (0.041, 0.026, 0.006), rr=0.005, R=QR @ rot(rx=-8), part=POUCH))
        parts.append(Sphere(c + qn * 0.029 + UP * 0.012, 0.0055, part=METAL))
    q, qn, QR = on_belt(-44.0)
    parts.append(Box(q + QR[:, 0] * 0.03 + qn * 0.024 + UP * 0.03, (0.022, 0.03, 0.004), rr=0.002, R=QR @ rot(rz=8), part=RADIO))
    # a meter clipped on its left front, its cable looping down
    q, qn, QR = on_belt(36.0)
    c = q + qn * 0.024 - UP * 0.02
    parts += [Box(c, (0.033, 0.05, 0.02), rr=0.007, R=QR, part=RADIO), Box(c + qn * 0.02 + UP * 0.016, (0.02, 0.017, 0.003), rr=0.002, R=QR, part=SCREEN),
              Box(q + qn * 0.012 + UP * 0.02, (0.012, 0.025, 0.006), rr=0.003, R=QR, part=POUCH)]
    cb = c - UP * 0.05
    parts.append(loft([(cb + QR[:, 0] * 0.015, 0.0035), (cb - UP * 0.06 + qn * 0.01, 0.0035), (cb - UP * 0.08 - QR[:, 0] * 0.02, 0.0035),
                       (cb - UP * 0.03 - QR[:, 0] * 0.03, 0.0035)], part=RADIO, k=0.004))
    # a roll of tape hanging from a strap, and a small pouch on the left side
    q, qn, QR = on_belt(14.0)
    parts += [Box(q + qn * 0.012 - UP * 0.03, (0.01, 0.045, 0.004), rr=0.002, R=QR, part=POUCH),
              Torus(q + qn * 0.03 - UP * 0.1, 0.034, 0.016, Rm=QR, part=TAPE)]
    q, qn, QR = on_belt(64.0)
    parts += [Box(q + qn * 0.024 - UP * 0.025, (0.03, 0.05, 0.02), rr=0.008, R=QR, part=POUCH),
              Box(q + qn * 0.044 - UP * 0.0, (0.031, 0.022, 0.005), rr=0.004, R=QR @ rot(rx=-8), part=POUCH)]
    return Union(parts, k=0.0)


# ---------------------------------------------------------------------------------------------------- arms and hands

def hand(curl, thumb):
    """hand space: the wrist at the origin, fingers along -Z, the back of the hand +X, the thumb toward -Y. curl: four finger bends (degrees)"""
    parts = [RoundCone((0, 0, 0.015), (0, 0, -0.012), 0.016, 0.017, part=SKIN), Ellipsoid((0.0, 0.0, -0.032), (0.011, 0.024, 0.03), part=SKIN)]
    for i, (fy, L) in enumerate(((-0.017, 0.9), (-0.006, 1.0), (0.006, 0.95), (0.017, 0.78))):
        a = np.radians(curl[i])
        p = v3((0.0, fy, -0.056))
        pts = [(p, 0.0068)]
        d = v3((0.0, 0.0, -1.0))
        for k, seg in enumerate((0.026, 0.019, 0.016)):
            ang = a * (k + 1) / 2.0
            d = v3((-np.sin(ang), 0.0, -np.cos(ang)))
            p = p + d * seg * L
            pts.append((p, 0.0062 - 0.0006 * k))
        parts.append(loft(pts, part=SKIN, k=0.004))
        parts.append(Sphere(pts[1][0], 0.0072, part=SKIN))
    ta = np.radians(thumb)
    t0 = v3((-0.006, -0.02, -0.018))
    t1 = t0 + v3((-0.008, -0.016, -0.014))
    t2 = t1 + v3((-0.012 * np.cos(ta) - 0.004, -0.006 + 0.014 * np.sin(ta), -0.016 * np.cos(ta)))
    parts.append(loft([(t0, 0.0085), (t1, 0.0072), (t2, 0.0064)], part=SKIN, k=0.004))
    return Union(parts, k=0.006)


def arm(el, wr, R, curl, thumb):
    a = loft([(SH - (el - SH) * 0.1, 0.024), (el, 0.019), (el + (wr - el) * 0.4, 0.021), (wr, 0.016)], part=SKIN, k=0.012)
    return Union([a, Sphere(el, 0.022, part=SKIN), place(hand(curl, thumb), wr, R)], k=0.008)


def arms():
    left = arm(EL_L, WR_L, HAND_L, (25.0, 18.0, 22.0, 30.0), 10.0)
    right = Move(arm(EL_R, WR_R, HAND_R, (0.0, 95.0, 105.0, 110.0), 60.0), R=FLIP)
    return Union([left, right], k=0.0)


# ---------------------------------------------------------------------------------------------------- five legs, five boots

def legs():
    out = []
    for h, k, a in zip(HIPS, KNEES, ANKLES):
        mid = (h + k) * 0.5 + (k - h) * 0.0 + v3((h[0], h[1], 0)) / max(np.linalg.norm(h[:2]), 1e-6) * 0.012
        out.append(loft([(h, 0.025), (mid, 0.022), (k, 0.0195), ((k + a) * 0.5, 0.019), (a + v3((0, 0, 0.03)), 0.0175)], part=LEG, k=0.02))
    return Union(out, k=0.006)


def boot(i):
    f = FWDS[i]
    side = np.cross(UP, f)
    a = v3((ANKLES[i][0], ANKLES[i][1], 0.0))
    upper = loft([(a - f * 0.028 + UP * 0.042, 0.04), (a + f * 0.035 + UP * 0.04, 0.043), (a + f * 0.078 + UP * 0.034, 0.035)], part=BOOT, k=0.02)
    shaft = CappedCone(a + UP * 0.04, a + UP * 0.112, 0.041, 0.038, rr=0.008, part=BOOT)
    up = Clip(Union([upper, shaft], k=0.02, part=BOOT), [Half(UP * 0.012, -UP)])
    sole = Clip(Inflate(upper, 0.006, part=SOLE), [Half(UP * 0.024, UP), Half((0, 0, 0), -UP)], k=0.002)
    heel = Clip(Inflate(upper, 0.007, part=SOLE), [Half(UP * 0.03, UP), Half((0, 0, 0), -UP), Half(a + f * 0.0, f)], k=0.002)
    collar = Torus(a + UP * 0.111, 0.037, 0.009, part=BOOT)
    tongue = Box(a + f * 0.03 + UP * 0.112, (0.022, 0.006, 0.018), rr=0.005, R=basis(f, UP) @ rot(rx=-90), part=BOOT)
    laces = []
    for j in range(4):
        p = a + f * (0.07 - 0.017 * j)
        s = hit(up, p + UP * 0.3, -UP)
        for sg in (-1.0, 1.0):
            d = side * 0.019 * sg + f * 0.006
            laces.append(RoundCone(s - d + UP * 0.003, s + d + UP * 0.003, 0.0035, part=LACE))
    loop = Torus(a + f * 0.028 + UP * 0.125, 0.012, 0.0035, Rm=basis(side, UP), part=LACE)
    return Union([up, sole, heel, collar, tongue, loop] + laces, k=0.0)


def boots():
    return Union([boot(i) for i in range(5)], k=0.0)


def pieces():
    import os
    q = float(os.environ.get("FOLK_DRAFT", "1"))
    return [("jelly", jelly(), 0.0036 * q), ("headset", headset(), 0.0018 * q), ("gear", gear(), 0.0022 * q), ("arms", arms(), 0.0016 * q),
            ("legs", legs(), 0.0018 * q), ("boots", boots(), 0.002 * q)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.01) * 0.25

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

    # the jelly: deep raspberry on the dome, glowing orange down the rim and the lower bell, the innards showing through
    m = c.mask(JELLY)
    depth = noise3(P + 3.0, 0.16) * 0.6 + noise3(P, 0.06) * 0.4          # how thick the jelly is here: thin glows orange, thick goes deep red
    jl = full((178, 40, 54))
    jl = lerp(jl, srgb(236, 92, 58), smooth(-0.15, 0.45, depth) * 0.6)
    jl = lerp(jl, srgb(222, 96, 84), smooth(0.4, 0.95, c.N[:, 2]) * 0.3)
    jl = lerp(jl, srgb(246, 116, 40), smooth(1.18, 1.03, z))
    jl = lerp(jl, srgb(255, 168, 62), smooth(1.07, 0.99, z) * smooth(0.38, 0.55, np.hypot(x, y)) * 0.85)          # the thin rim glows
    jl = lerp(jl, srgb(252, 128, 36), smooth(0.99, 0.93, z))
    jl = lerp(jl, srgb(118, 18, 34), c.cavity * 0.6)
    # innards: a tangle of soft maroon tubes in the lower bell, blurred by the jelly, their tops catching a little light
    zone = smooth(0.79, 0.85, z) * smooth(1.06, 0.97, z) * smooth(0.18, 0.3, np.hypot(x, y))
    tube, core = innards(P, zone > 0.01)
    jl = lerp(jl, srgb(140, 30, 32), tube * zone * 0.75)
    jl = lerp(jl, srgb(206, 86, 62), core * zone * 0.5)
    jl = lerp(jl, srgb(255, 200, 150), c.wear * 0.3)                  # light catching the lumps
    put(m, jl, 0.12, bump=0.05)
    spk(m, (255, 190, 120), 0.12)

    # eyes: cream balls, yellowing round the edge, a small black pupil straight ahead (the eye bones turn them), a glint
    m = c.mask(EYE)
    ey = full((250, 232, 168))
    pup = np.full(n, 9.0, F32)
    glint = np.zeros(n, F32)
    for name, ce, nn, r in eye_points():
        d = P - ce
        dl = np.linalg.norm(d, axis=1)
        mine = m & (dl < r * 1.3)
        dn = d / np.maximum(dl, 1e-6)[:, None]
        g = gaze(nn)
        ang = np.arccos(np.clip(dn @ g, -1, 1))
        ey[mine] = lerp(ey, srgb(228, 176, 100), smooth(0.8, 1.55, ang))[mine]
        g2 = g + v3((0.22, 0.0, 0.1))                 # the pupils glance up and to its left, as drawn
        g2 /= np.linalg.norm(g2)
        pup = np.where(mine, np.arccos(np.clip(dn @ g2, -1, 1)) / 0.2, pup)
        gl = smooth(0.02, 0.006, (dn[:, 0] + 0.35) ** 2 + (dn[:, 2] - 0.55) ** 2)
        glint = np.where(mine, gl, glint)
    c.draw(m, (pup - 1.0) * 0.006, 0.0)
    ey = lerp(ey, srgb(255, 254, 246), glint)
    put(m, ey, 0.06)

    m = c.mask(LIP)
    put(m, lerp(full((224, 106, 98)), srgb(160, 52, 58), smooth(0.4, 0.95, -c.N[:, 2]) * 0.5), 0.18)

    # the headset: yellow cup with a red label, black band, foam
    m = c.mask(CUP)
    cp = full((232, 172, 30))
    cp = lerp(cp, srgb(160, 110, 30), smooth(0.2, 0.8, noise3(P + 3.0, 0.02)) * 0.3)
    put(m, cp, 0.4, bump=0.2, grain=1.0)
    put(c.mask(BAND), srgb(32, 32, 34) * (1.0 + 0.6 * c.wear)[:, None], 0.4, bump=0.1, grain=1.0)
    put(c.mask(PAD), srgb(24, 24, 24), 0.9, bump=1.0)
    put(c.mask(METAL), srgb(196, 198, 204) * (1.0 - 0.5 * c.cavity)[:, None], 0.3, metal=1.0, grain=1.0, bump=0.05)

    # the belt: brown leather, holes and stitching; canvas pouches; the meter; the tape
    m = c.mask(BELT)
    bt = lerp(full((104, 70, 42)), srgb(150, 110, 70), c.wear * 0.6)
    bt *= (1.0 + 0.12 * mott)[:, None]
    put(m, bt, 0.55, bump=0.8, grain=1.0)
    holes = m & (np.abs(z - 0.805) < 0.006) & (np.abs(np.sin(np.arctan2(x, -y) * 30.0)) > 0.97) & (y < 0)
    c.draw(m, np.where(holes, -1.0, 1.0) * 0.003, 0.0, 0.8)
    c.draw(m & (np.abs(np.abs(z - 0.805) - 0.02) < 0.004), np.abs(np.abs(z - 0.805) - 0.02), 0.0006, 0.35)
    m = c.mask(POUCH)
    pc = full((198, 150, 58))
    pc = lerp(pc, srgb(120, 84, 40), smooth(0.2, 0.75, noise3(P + 5.0, 0.03)) * 0.45)
    pc = lerp(pc, srgb(232, 196, 110), c.wear * 0.5)
    put(m, pc, 0.85, bump=1.0)
    spk(m, (110, 76, 40), 0.3)
    put(c.mask(RADIO), srgb(58, 60, 66) * (1.0 + 0.8 * c.wear)[:, None], 0.5, bump=0.2, grain=1.0)
    put(c.mask(SCREEN), srgb(182, 196, 80), 0.15)
    m = c.mask(TAPE)
    put(m, lerp(full((214, 208, 196)), srgb(150, 140, 126), smooth(0.2, 0.8, noise3(P, 0.01)) * 0.4), 0.6, bump=0.3)

    # arms: warm peach-orange flesh, darker at the elbows
    m = c.mask(SKIN)
    sk = full((222, 132, 98))
    sk = lerp(sk, srgb(188, 88, 70), smooth(0.4, 0.9, noise3(P + 1.0, 0.025)) * 0.35)
    sk *= (1.0 + 0.06 * mott)[:, None]
    put(m, sk, 0.45, bump=0.15)
    spk(m, (200, 96, 74), 0.25)

    # legs: glossy maroon tubes; boots: scuffed brown leather, dark soles, yellow laces, mud
    m = c.mask(LEG)
    lg = lerp(full((124, 30, 38)), srgb(84, 16, 22), smooth(0.3, 0.8, noise3(P, 0.04)) * 0.4)
    put(m, lg, 0.18, bump=0.05)
    m = c.mask(BOOT)
    bo = full((96, 64, 46))
    bo = lerp(bo, srgb(140, 104, 74), c.wear * 0.7)
    bo = lerp(bo, srgb(70, 54, 40), smooth(0.05, 0.0, z) * 0.5)
    put(m, bo, 0.6, bump=0.9, grain=1.0)
    spk(m, (120, 92, 62), 0.4)
    m = c.mask(SOLE)
    put(m, lerp(full((58, 46, 36)), srgb(130, 110, 86), smooth(0.2, 0.8, noise3(P, 0.012)) * 0.4), 0.85, bump=0.6, grain=1.0)
    spk(m, (140, 112, 84), 0.5)
    put(c.mask(LACE), srgb(226, 166, 44), 0.7, bump=0.5)

    ao = np.where(c.mask(JELLY, EYE), 0.65 + 0.35 * c.ao, 0.3 + 0.7 * c.ao)        # the jelly is lit through: shallow occlusion
    c.col *= ao[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


def innards(P, where):
    """(tube, core) per vertex: a tangle of meandering gut-tubes drawn round the lower bell, seen through the jelly (distance to random noodle paths
    laid out in the bell's unrolled (arc, height) plane)"""
    from kit.paint import smooth
    rng = np.random.default_rng(21)
    tube = np.zeros(len(P), F32)
    core = np.zeros(len(P), F32)
    idx = np.nonzero(where)[0]
    if len(idx) == 0:
        return tube, core
    Q = P[idx]
    U = np.arctan2(Q[:, 0], -Q[:, 1]) * 0.42
    V = Q[:, 2]
    best = np.full(len(idx), 9.0, F32)
    width = np.full(len(idx), 0.01, F32)
    for i in range(30):
        u, v = rng.uniform(-1.25, 1.25), rng.uniform(0.84, 0.98)
        hd = rng.uniform(0, 2 * np.pi)
        w = rng.uniform(0.0065, 0.012)
        pts = [(u, v)]
        for k in range(int(rng.integers(14, 30))):
            hd += rng.normal(0.0, 0.5)
            if v > 0.985:
                hd = -abs(hd) if np.sin(hd) > 0 else hd
            if v < 0.83:
                hd = abs(hd)
            u, v = u + np.cos(hd) * 0.016, float(np.clip(v + np.sin(hd) * 0.012, 0.82, 1.0))
            pts.append((u, v))
        pts = np.array(pts, F32)
        for a, b in zip(pts[:-1], pts[1:]):
            ab = b - a
            t = np.clip(((U - a[0]) * ab[0] + (V - a[1]) * ab[1]) / max(float(ab @ ab), 1e-9), 0, 1)
            d = np.hypot(U - a[0] - t * ab[0], V - a[1] - t * ab[1])
            take = d - w < best - width
            best = np.where(take, d, best)
            width = np.where(take, w, width)
    tube[idx] = smooth(width + 0.006, width - 0.002, best)
    core[idx] = smooth(width * 0.55, 0.0, best)
    return tube, core


def gaze(nn):
    """where an eye looks in the rest pose: mostly ahead, a little along its own normal"""
    g = v3((0.0, -1.0, 0.1)) * 0.75 + nn * 0.25
    return g / np.linalg.norm(g)


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"jelly": 2700, "headset": 650, "gear": 1500, "arms": 1000, "legs": 900, "boots": 1300},
    "density": {"jelly": 1.25, "headset": 1.1, "arms": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.5, "run": 0.9},
    "speed": 0.9,
    "look": ["cap"], "neck": "body",
    "look_pivot": (0.0, 0.0, 1.0),
    "radius": 0.62,
}
LOBES = 6


def rig_bones():
    from kit.rig import Bone
    bones = [
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("body", (0, 0, 0.80), (0, 0, 0.98), "root", 0.36),
        Bone("cap", (0, 0, 0.98), (0, 0, 1.40), "body", 0.42),
    ]
    for i in range(LOBES):
        a = i * 360.0 / LOBES
        bones.append(Bone("lobe.%d" % i, azi(a, 0.4, 1.02), azi(a, 0.63, 1.0), "cap", 0.07))
    for name, ce, nn, r in eye_points():
        bones.append(Bone(name, ce, ce + gaze(nn) * 0.08, "cap", r * 0.5))
    for side, el, wr, R, f in (("L", EL_L, WR_L, HAND_L, np.eye(3, dtype=F32)), ("R", EL_R, WR_R, HAND_R, FLIP)):
        hend = wr - R[:, 2] * 0.06
        bones += [Bone("upper_arm." + side, f @ SH, f @ el, "body", 0.022), Bone("forearm." + side, f @ el, f @ wr, "upper_arm." + side, 0.02),
                  Bone("hand." + side, f @ wr, f @ hend, "forearm." + side, 0.018)]
    for i in range(5):
        toe = v3((ANKLES[i][0], ANKLES[i][1], 0.03)) + FWDS[i] * 0.1
        bones += [Bone("thigh.%d" % i, HIPS[i], KNEES[i], "body", 0.024), Bone("shin.%d" % i, KNEES[i], ANKLES[i], "thigh.%d" % i, 0.02),
                  Bone("foot.%d" % i, ANKLES[i], toe, "shin.%d" % i, 0.04)]
    return bones


def skin_rules(P, part, piece, names):
    """pieces: 0 jelly, 1 headset, 2 gear, 3 arms, 4 legs, 5 boots"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    rxy = np.hypot(x, y)
    az = np.degrees(np.arctan2(x, -y)) % 360.0

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    jp = piece == 0
    allow(jp, "cap")
    allow(jp & (z < 1.06), "body")
    rim = jp & (rxy > 0.34) & (z < 1.17) & (z > 0.9)
    for i in range(LOBES):
        da = np.abs((az - i * 360.0 / LOBES + 180.0) % 360.0 - 180.0)
        allow(rim & (da < 360.0 / LOBES * 1.05), "lobe.%d" % i)
    rig[jp & (z < 0.9)] = ix["body"]
    eyes = eye_points()
    for name, ce, nn, r in eyes:
        mine = jp & (part == EYE) & (np.linalg.norm(P - ce, axis=1) < r * 1.25)
        rig[mine] = ix[name]
        allow(mine, name)
    rig[jp & (part == LIP)] = ix["cap"]
    rig[piece == 1] = ix["cap"]
    allow(piece == 1, "cap")
    rig[piece == 2] = ix["body"]
    allow(piece == 2, "body")
    ap = piece == 3
    for s, sd, wr, R in ((1, "L", WR_L, HAND_L), (-1, "R", WR_R * v3((-1, 1, 1)), FLIP @ HAND_R)):
        m = ap & (x * s > 0)
        allow(m, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        rig[m & (((P - wr) @ (-R[:, 2])) > 0.006)] = ix["hand." + sd]
    lp = piece == 4
    lb = piece == 5
    dk = np.stack([np.hypot(x - a[0], y - a[1]) for a in ANKLES], 1)
    dh = np.stack([np.hypot(x - h[0] - (a[0] - h[0]) * np.clip((0.795 - z) / 0.71, 0, 1), y - h[1] - (a[1] - h[1]) * np.clip((0.795 - z) / 0.71, 0, 1))
                   for h, a in zip(HIPS, ANKLES)], 1)
    near_leg = np.argmin(dh, 1)
    near_boot = np.argmin(dk, 1)
    for i in range(5):
        m = lp & (near_leg == i)
        allow(m, "thigh.%d" % i, "shin.%d" % i)
        allow(m & (z > 0.75), "body")
        rig[lb & (near_boot == i)] = ix["foot.%d" % i]
        allow(lb & (near_boot == i), "foot.%d" % i)
    return A, rig


PHASE = [(k * 2.0 / 5.0) % 1.0 for k in range(5)]          # a ripple: each leg 2/5 of a cycle after its neighbour round the ring
WALK = dict(stride=0.5, stance=0.62, lift=0.06, bob=0.01, drop=0.012, lean=2.0, wob=1.5)
RUN = dict(stride=0.9, stance=0.46, lift=0.1, bob=0.018, drop=0.03, lean=7.0, wob=2.4)


def motions(rig):
    """walk: a skittery five-legged ripple, the boots pattering in turn round the ring, the bell jiggling over them and its rim rippling;
    run: the same, scurrying, leaning in, arms flapping; idle: one foot tapping, the bell breathing, the three eyes wandering each their own way,
    the raised finger wagging"""
    import math
    from kit.gait import Pose, Leg, R, TAU, ease
    from mathutils import Vector, Matrix
    legs = [Leg("thigh.%d" % i, "shin.%d" % i, "foot.%d" % i, BALLS[i].tolist(), str(i)) for i in range(5)]
    poles = [Vector((azi(a)[0], azi(a)[1], 0.25)) + Vector((0, -0.35, 0)) for a in LEG_AZ]

    def foot(p, i, ball, pitch):
        lg = legs[i]
        fw = Vector(FWDS[i].tolist())
        wf = Matrix.Rotation(math.radians(pitch), 3, Vector((0, 0, 1)).cross(fw))
        ankle = ball + wf @ (rig.head[lg.foot] - lg.ball)
        p.ik[lg.thigh] = (ankle, poles[i], lg.foot, wf)

    def ripple(p, u, amp, speed=2.0):
        for i in range(LOBES):
            a = math.radians(i * 360.0 / LOBES)
            tangent = Vector((math.cos(a), math.sin(a), 0.0))          # (the lobe's axis is (sin a, -cos a, 0): this is across it)
            p.delta["lobe.%d" % i] = Matrix.Rotation(math.radians(amp * math.sin(TAU * (speed * u - i / LOBES))), 3, tangent)

    def eyes(p, looks):
        for name, (rx, rz) in looks.items():
            p.rot(name, rx, 0.0, rz)

    def walkish(u, g, run):
        p = Pose()
        S, beta = g["stride"], g["stance"]
        w = g["wob"]
        p.offset = Vector((0.008 * math.sin(TAU * u), 0.0, -g["drop"] + g["bob"] * math.cos(5 * TAU * u)))
        p.rot("body", g["lean"] + 1.2 * w * math.sin(5 * TAU * u + 0.4), 1.8 * w * math.sin(TAU * u), 2.0 * math.sin(TAU * u + 1.0))
        p.rot("cap", 2.4 * w * math.sin(5 * TAU * u - 1.1) + (3.0 if run else 0.0), 2.2 * w * math.sin(TAU * u - 0.9), 1.5 * math.sin(TAU * u))
        ripple(p, u, 6.0 * w)
        for i in range(5):
            uu = (u + PHASE[i]) % 1.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                lift, pitch = 0.0, 8.0 * ease((uu - (beta - 0.12)) / 0.12)
            else:
                t = ease((uu - beta) / (1.0 - beta))          # a quick, skittery swing
                fy = S * beta / 2 - S * beta * ease(t)
                lift = g["lift"] * math.sin(math.pi * t) ** 0.6
                pitch = 8.0 * (1.0 - ease(t * 2.0)) - 10.0 * math.sin(math.pi * t)
            b = BALLS[i]
            foot(p, i, Vector((b[0], b[1] + fy, lift)), pitch)
        fl = math.sin(2 * TAU * u)
        for s, sd in ((1.0, "L"), (-1.0, "R")):
            p.rot("upper_arm." + sd, (14.0 if run else 6.0) * fl * s, 0.0, (10.0 if run else 4.0) * math.sin(2 * TAU * u + 0.8))
            p.rot("forearm." + sd, (12.0 if run else 6.0) * math.sin(2 * TAU * u + 1.5), 0.0, 0.0)
        eyes(p, {"eye.R": (-3.0 + 2.0 * math.sin(TAU * u), 0.0), "eye.C": (-2.0, 3.0 * math.sin(TAU * u + 2.0)), "eye.L": (-3.0, -2.0 + 2.0 * math.sin(TAU * u + 4.0))})
        return p

    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    def win(t, a, b, e=0.25):
        return ease((t - a) / e) * (1.0 - ease((t - b) / e))

    idle = []
    for fr in range(181):
        t = fr / 30.0
        p = Pose()
        tap = max(win(t, 1.0, 1.25, 0.1), win(t, 1.45, 1.7, 0.1), win(t, 4.1, 4.35, 0.1))
        jig = sum(math.exp(-(t - t0) * 3.0) * math.sin((t - t0) * 18.0) for t0 in (1.25, 1.7, 4.35) if t > t0) * (1.0 - ease((t - 5.4) / 0.6))
        p.offset = Vector((0.0, 0.0, -0.004 + 0.005 * math.sin(TAU * t / 3.0)))
        p.rot("body", 0.8 * math.sin(TAU * t / 6.0), 1.0 * math.sin(TAU * t / 3.0), 0.0)
        p.rot("cap", 1.6 * math.sin(TAU * t / 3.0 + 0.8) + 2.0 * jig, 1.2 * jig, 0.0)
        ripple(p, t / 6.0, 2.0 + 3.0 * abs(jig), speed=3.0)
        for i in range(5):
            b = BALLS[i]
            if i == 0:
                foot(p, 0, Vector((b[0], b[1], 0.03 * tap)), -6.0 * tap)
            else:
                foot(p, i, Vector((b[0], b[1], 0.0)), 0.0)
        # the eyes wander, each on its own
        L1 = win(t, 0.6, 2.2) - win(t, 3.0, 4.4)
        eyes(p, {"eye.R": (6.0 * win(t, 2.4, 3.4) - 2.0, -16.0 * L1),
                 "eye.C": (-4.0 + 8.0 * win(t, 4.8, 5.6), -14.0 * L1 + 6.0 * win(t, 4.8, 5.6)),
                 "eye.L": (-8.0 * win(t, 1.0, 1.8) + 5.0 * win(t, 3.6, 4.6), 18.0 * win(t, 1.4, 2.6) - 10.0 * L1)})
        wag = win(t, 2.0, 3.6, 0.3)
        p.rot("upper_arm.R", -8.0 * wag, 0.0, 0.0)
        p.rot("forearm.R", -6.0 * wag, 0.0, 0.0)
        p.rot("hand.R", 0.0, 0.0, 14.0 * wag * math.sin(TAU * t * 2.2))
        p.rot("upper_arm.L", 2.0 * math.sin(TAU * t / 3.0), 0.0, 0.0)
        p.rot("hand.L", 6.0 * win(t, 3.8, 5.0), 0.0, 0.0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
