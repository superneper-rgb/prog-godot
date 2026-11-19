## FOINT CITY townsfolk: the bean (working name; the user names it). A long pink fleshy bean lying sideways on three short legs: five eyes in a row along its front shrinking toward its huge ribbed lips at one end, little arms on top, baggy olive overall-shorts with straps, pockets and a chain, three mismatched chunky sneakers.
# Concept: the user's sheet, image 7 bottom right (F:/prog-godot-cache/folk/refs/7.webp). Measured off it (3x crop, 1.18 mm a pixel at 1.10 m to the top of the bean): the bean is 1.18 m long
# (its axis runs left to right, the face along its front: the three sneakers all point at the viewer), 0.55 m tall, z 0.52-1.1; the eyes in a row at 0.93-0.97 m, 12.5 cm
# down to 4 cm across; the lips fill its left end (+X), 0.3 m tall; the overall-shorts from about 0.75 m to rolled cuffs at 0.42, three legs 0.42 m apart, the sneakers 0.3 m
# long and 0.25 tall. No props (the alarm clock is dropped).
# Rest pose: its right hand hooked in the overall strap at its right end, as drawn; its left (the clock hand) raised open, as if to say "wait, I'm late".
# Kit gaps filled here: hit() / normal(), hands; the three-legged ripple waddle is written in motions().
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.10
REF = ("7.webp", (761, 367, 1161, 775))

(SKIN, EYE, LIP, LIP_L, TOOTH, TONGUE, DENIM, METAL, PENCIL, SOCK, SHOE, SOLE, LACE) = range(1, 14)
COLOURS = {
    SKIN: ((0.85, 0.38, 0.27), 0.5, 0.0),
    EYE: ((0.03, 0.03, 0.02), 0.08, 0.0),
    LIP: ((0.7, 0.2, 0.25), 0.35, 0.0),
    LIP_L: ((0.7, 0.2, 0.25), 0.35, 0.0),
    TOOTH: ((0.8, 0.72, 0.5), 0.4, 0.0),
    TONGUE: ((0.75, 0.3, 0.32), 0.4, 0.0),
    DENIM: ((0.12, 0.13, 0.05), 0.85, 0.0),
    METAL: ((0.6, 0.6, 0.62), 0.3, 1.0),
    PENCIL: ((0.7, 0.1, 0.1), 0.4, 0.0),
    SOCK: ((0.75, 0.72, 0.68), 0.9, 0.0),
    SHOE: ((0.6, 0.45, 0.15), 0.6, 0.0),
    SOLE: ((0.7, 0.65, 0.56), 0.8, 0.0),
    LACE: ((0.8, 0.78, 0.72), 0.8, 0.0),
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


# ---------------------------------------------------------------------------------------------------- landmarks (it faces -Y; its left, +X, is the lips end)

EYES = [(-0.135, 0.93, 0.062), (0.0, 0.935, 0.046), (0.125, 0.945, 0.032), (0.212, 0.962, 0.025), (0.285, 0.985, 0.021)]   # x, z, radius
LEGS = [("R", -0.42), ("C", 0.0), ("L", 0.42)]
HIP_Z, KNEE_Z, ANKLE_Z = 0.56, 0.37, 0.17
SHOE_YAW = {"R": -6.0, "C": 0.0, "L": 6.0}
LIP_C = v3((0.47, -0.1, 0.92))           # the mouth's centre at the bean's left end, opening out and a little forward
LIP_N = v3((0.62, -0.78, 0.06)) / np.linalg.norm((0.62, -0.78, 0.06))      # the open mouth faces out of the end and well forward
# arms on top of the bean: its right hooked in the strap, its left raised
R_SH, R_EL, R_WR = v3((-0.36, 0.02, 1.0)), v3((-0.5, 0.04, 1.14)), v3((-0.55, -0.1, 0.9))
R_HAND = frame(-v3((0.15, -0.35, -1.0)), v3((-1.0, 0.0, 0.0)))
L_SH, L_EL, L_WR = v3((0.2, 0.04, 1.06)), v3((0.32, 0.06, 1.2)), v3((0.42, -0.06, 1.22))
L_HAND = frame(-v3((0.4, -0.3, 1.0)), v3((0.3, 1.0, 0.0)))


def bean():
    """the bean: three lobes along X, the left end lifting toward the lips"""
    return Union([
        Ellipsoid((-0.33, 0.0, 0.775), (0.3, 0.27, 0.225)),
        Ellipsoid((-0.02, 0.0, 0.75), (0.3, 0.27, 0.205)),                    # a kidney: the middle sags a little
        Ellipsoid((0.3, -0.01, 0.87), (0.24, 0.24, 0.19)),
        Ellipsoid((0.0, 0.02, 0.665), (0.48, 0.24, 0.085)),                   # its belly sits high enough for the shorts-legs to hang free
    ], k=0.14, part=SKIN)


def eye_spots():
    b = bean()
    out = []
    for x, z, r in EYES:
        s = hit(b, (x, -0.8, z), (0, 1, 0))
        n = normal(b, s)
        out.append((s + n * r * 0.15, n, r))
    return out


def body():
    b = Bump(bean(), lambda P: noise3(P, 0.07) * 0.6 + noise3(P, 0.025) * 0.4, 0.006)
    # each eye sunk in a fleshy socket ring, the biggest with a fold under it
    rings, balls = [], []
    for c, n, r in eye_spots():
        rings.append(Torus(c - n * r * 0.25, r * 1.02, max(0.008, r * 0.28), Rm=basis(n, UP), part=SKIN))
        balls.append(Sphere(c, r, part=EYE))
    b = Union([b] + rings, k=0.018, part=SKIN)
    # the lips: a ribbed upper lip curling out over a fat drooping lower one, the mouth open on teeth and a tongue
    M = frame(LIP_N, UP)          # local z out of the mouth, local y... (x leaning up)
    up_ = M[:, 0]
    side = M[:, 1]
    upper = loft([(LIP_C - side * 0.13 + up_ * 0.02, 0.03), (LIP_C - side * 0.06 + up_ * 0.09 + LIP_N * 0.06, 0.055), (LIP_C + up_ * 0.11 + LIP_N * 0.1, 0.06),
                  (LIP_C + side * 0.08 + up_ * 0.09 + LIP_N * 0.06, 0.052), (LIP_C + side * 0.13 + up_ * 0.01, 0.03)], part=LIP, k=0.04)
    lower = loft([(LIP_C - side * 0.13 - up_ * 0.01, 0.03), (LIP_C - side * 0.06 - up_ * 0.1 + LIP_N * 0.05, 0.062), (LIP_C - up_ * 0.13 + LIP_N * 0.085, 0.068),
                  (LIP_C + side * 0.08 - up_ * 0.1 + LIP_N * 0.05, 0.06), (LIP_C + side * 0.13 - up_ * 0.02, 0.03)], part=LIP_L, k=0.04)
    ribs = lambda P: np.sin(((P - LIP_C) @ up_) * 120.0) * 0.6 + np.sin(((P - LIP_C) @ side) * 70.0) * 0.4
    upper = Bump(upper, ribs, 0.003)
    lower = Bump(lower, ribs, 0.003)
    cavity = Ellipsoid(LIP_C + LIP_N * 0.06, (0.06, 0.09, 0.07), R=frame(LIP_N, up_), part=SKIN)
    b = Cut(b, [cavity], k=0.02)
    teeth = [Box(LIP_C + LIP_N * 0.06 + up_ * (0.055 * sg) + side * o, (0.014, 0.011, 0.012), rr=0.004, R=frame(LIP_N, up_) @ rot(rz=o * 200), part=TOOTH)
             for sg in (1.0, -1.0) for o in (-0.05, -0.017, 0.017, 0.05)]
    tongue = Ellipsoid(LIP_C + LIP_N * 0.045 - up_ * 0.045, (0.05, 0.075, 0.03), R=frame(LIP_N, side) @ rot(rx=90), part=TONGUE)
    return Union([b, upper, lower, tongue] + teeth + balls, k=0.0)


# ---------------------------------------------------------------------------------------------------- the overall-shorts

def overalls():
    core = bean()
    lower = Union([core, Union([CappedCone((x, 0.0, 0.64), (x, 0.0, 0.43), 0.105, 0.098, rr=0.025) for _, x in LEGS], k=0.0)], k=0.03)       # three short shorts-legs, not a slab
    shell = Cut(Inflate(lower, 0.03, part=DENIM), [Inflate(lower, 0.014)])
    folds = lambda P: noise3(P * v3((0.6, 1.2, 1.6)), 0.05) * 0.7 + noise3(P, 0.02) * 0.3
    shell = Bump(shell, folds, 0.006)
    # cut along a waistline (higher at its right end where the bib is), and the three leg holes
    waist = Bump(Half((0, 0, 0.74), (0.18, 0.0, 1.0)), lambda P: np.zeros(len(P), F32), 0.0)
    shell = Clip(shell, [waist, Half((0, 0, 0.43), (0, 0, -1))], k=0.006)
    bib = Clip(Cut(Inflate(core, 0.03, part=DENIM), [Inflate(core, 0.014)]), [Box((-0.36, -0.2, 0.8), (0.16, 0.2, 0.12), rr=0.03)], k=0.004)
    cuffs = [Torus((x, 0.0, 0.448), 0.112, 0.02, part=DENIM) for _, x in LEGS]
    # straps over the top, metal buckles where they meet the bib and the front
    straps = []
    for sx, z_front in ((-0.33, 0.9), (0.18, 0.76)):
        pts = []
        for a in np.linspace(-0.4, 3.0, 14):
            d = v3((0.0, -np.cos(a), np.sin(a)))
            p = hit(core, v3((sx, 0.0, 0.72)) + d * 0.6, -d)
            pts.append((p + normal(core, p) * 0.016, 0.0))
        pts = [(p, 0.0) for p, _ in pts if p[2] > z_front - 0.02 or p[1] > 0]
        straps.append(Union([Box((pts[i][0] + pts[i + 1][0]) * 0.5, (0.032, 0.006, float(np.linalg.norm(pts[i + 1][0] - pts[i][0])) * 0.5 + 0.006), rr=0.004,
                                 R=frame(pts[i + 1][0] - pts[i][0], v3((1, 0, 0))) @ np.array([[1, 0, 0], [0, 1, 0], [0, 0, 1]], F32), part=DENIM)
                             for i in range(len(pts) - 1)], k=0.004))
        q = pts[0][0]
        straps.append(Cut(Box(q + v3((0, -0.012, 0.0)), (0.038, 0.008, 0.028), rr=0.004, part=METAL), [Box(q + v3((0, -0.012, 0.0)), (0.022, 0.02, 0.014))], k=0.002))
    # the bib pocket with a red pencil, a side pocket, the chain swagged across the front
    sp = hit(core, (-0.36, -0.8, 0.8), (0, 1, 0))
    n = normal(core, sp)
    R = frame(n, np.cross(UP, n))
    pocket = Box(sp + n * 0.034, (0.06, 0.055, 0.006), rr=0.005, R=R, part=DENIM)
    pencil = RoundCone(sp + n * 0.04 + UP * 0.02 + R[:, 0] * 0.02, sp + n * 0.04 + UP * 0.12 + R[:, 0] * 0.03, 0.006, 0.005, part=PENCIL)
    sq = hit(core, (0.32, -0.8, 0.6), (0, 1, 0))
    sn = normal(core, sq)
    spocket = Box(sq + sn * 0.034, (0.055, 0.05, 0.006), rr=0.005, R=frame(sn, np.cross(UP, sn)), part=DENIM)
    links = []
    a0 = sp + n * 0.04 - UP * 0.05
    b0 = hit(core, (0.08, -0.8, 0.72), (0, 1, 0))
    b0 = b0 + normal(core, b0) * 0.04
    for i in range(14):
        t = i / 13.0
        p = a0 * (1 - t) + b0 * t - UP * (0.1 * np.sin(np.pi * t))
        q = hit(lower, p - v3((0, 0.4, 0)), (0, 1, 0)) if False else p
        Rl = frame(v3((0, -1.0, 0.0)), (b0 - a0)) @ (rot(rx=90) if i % 2 else np.eye(3, dtype=F32))
        links.append(Torus(q, 0.016, 0.005, Rm=Rl, part=METAL))           # (thick enough for the voxel: thinner tubes go non-manifold and will not decimate)
    return Union([Union([shell, bib] + cuffs, k=0.01, part=DENIM), pocket, pencil, spocket] + straps + links, k=0.0)


# ---------------------------------------------------------------------------------------------------- arms, legs, sneakers

def hand(curl, thumb):
    parts = [RoundCone((0, 0, 0.012), (0, 0, -0.01), 0.016, 0.017, part=SKIN), Ellipsoid((0, 0, -0.028), (0.011, 0.024, 0.027), part=SKIN)]
    for i, fy in enumerate((-0.016, -0.0055, 0.0055, 0.016)):
        a = np.radians(curl[i])
        p = v3((0.0, fy, -0.05))
        pts = [(p, 0.0068)]
        for k, seg in enumerate((0.026, 0.019, 0.015)):
            ang = a * (k + 1) / 2.0
            p = p + v3((-np.sin(ang), 0.0, -np.cos(ang))) * seg
            pts.append((p, 0.0062 - 0.0006 * k))
        parts.append(loft(pts, part=SKIN, k=0.003))
    ta = np.radians(thumb)
    t0 = v3((-0.005, -0.019, -0.015))
    t1 = t0 + v3((-0.006, -0.017, -0.013))
    t2 = t1 + v3((-0.012 * np.sin(ta), -0.007, -0.017 * np.cos(ta)))
    parts.append(loft([(t0, 0.0082), (t1, 0.0072), (t2, 0.0064)], part=SKIN, k=0.003))
    return Union(parts, k=0.005)


def limbs():
    arms = []
    for sh, el, wr, R, curl, th in ((R_SH, R_EL, R_WR, R_HAND, (85.0, 90.0, 90.0, 85.0), 40.0), (L_SH, L_EL, L_WR, L_HAND, (6.0, 4.0, 8.0, 14.0), 20.0)):
        a = loft([(sh, 0.025), (el, 0.02), (wr, 0.017)], part=SKIN, k=0.01)
        arms.append(Union([a, Sphere(el, 0.023, part=SKIN), place(hand(curl, th), wr, R)], k=0.008))
    legs = [loft([(v3((x, 0.0, HIP_Z + 0.05)), 0.034), (v3((x, -0.01, KNEE_Z)), 0.031), (v3((x, 0.0, ANKLE_Z + 0.03)), 0.029)], part=SKIN, k=0.01) for _, x in LEGS]
    return Union(arms + legs, k=0.0)


def sneaker(side, x):
    f = rot(rz=SHOE_YAW[side]) @ v3((0, -1, 0))
    sv = np.cross(UP, f)
    a = v3((x, 0.0, 0.0))
    upper = Union([loft([(a - f * 0.09 + UP * 0.078, 0.066), (a + f * 0.06 + UP * 0.074, 0.073), (a + f * 0.18 + UP * 0.062, 0.058)], k=0.04),
                   Box(a + f * 0.07 + UP * 0.07, (0.07, 0.15, 0.05), rr=0.035, R=frame(UP, sv))], k=0.03, part=SHOE)        # boxy dad-sneaker
    upper = Clip(upper, [Half(UP * 0.03, -UP)])
    sole = Clip(Union([Inflate(upper, 0.012)], part=SOLE), [Half(UP * 0.06, UP), Half((0, 0, 0), -UP)], k=0.006)
    sole = Bump(sole, lambda P: np.clip(np.sin(((P - a) @ f) * 110.0) * 2.0 - 0.6, 0.0, 1.0) * np.clip((0.014 - np.abs(P[:, 2] - 0.035)) / 0.006, 0.0, 1.0), 0.003)    # (smooth: a stepped tread goes non-manifold)
    collar = Torus(a - f * 0.03 + UP * 0.15, 0.048, 0.016, Rm=frame(v3((0, 0, 1)) + f * 0.25, sv), part=SHOE)
    tongue = Box(a + f * 0.035 + UP * 0.16, (0.032, 0.008, 0.035), rr=0.008, R=frame(f + UP * 0.3, sv) @ rot(rx=90), part=SHOE)
    sock = CappedCone(a - f * 0.02 + UP * 0.12, a - f * 0.02 + UP * 0.2, 0.036, 0.034, rr=0.008, part=SOCK)
    laces = []
    for j in range(4):
        p = a + f * (0.13 - 0.024 * j)
        s = hit(upper, p + UP * 0.4, -UP)
        for sg in (-1.0, 1.0):
            d = sv * 0.03 * sg + f * 0.01
            laces.append(RoundCone(s - d + UP * 0.001, s + d + UP * 0.001, 0.005, part=LACE))       # sunk in: laces only grazing the upper went non-manifold
    return Union([Union([upper, collar, tongue], k=0.01, part=SHOE), sole, sock] + laces, k=0.0)


def pieces():
    import os
    q = float(os.environ.get("FOLK_DRAFT", "1"))
    return [("body", body(), 0.0026 * q), ("overalls", overalls(), 0.0026 * q), ("limbs", limbs(), 0.0017 * q),
            ("shoes", Union([sneaker(s, x) for s, x in LEGS]), 0.0024 * q)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
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

    # skin: warm salmon-pink flesh, blotchy rosy patches, freckle spots; inside the mouth dark red
    m = c.mask(SKIN)
    sk = full((240, 160, 124))
    sk *= (1.0 + 0.06 * mott)[:, None]
    blot = smooth(0.15, 0.45, noise3(P + 4.0, 0.06) * 0.7 + noise3(P, 0.02) * 0.3)
    sk = lerp(sk, srgb(214, 112, 104), blot * 0.55)
    sk = lerp(sk, srgb(180, 90, 70), c.cavity * 0.5)
    sk = lerp(sk, srgb(250, 196, 166), c.wear * 0.35)
    mouth_in = m & (((P - LIP_C) @ LIP_N) > -0.04) & (np.linalg.norm(P - LIP_C, axis=1) < 0.12)
    sk[mouth_in] = srgb(70, 20, 26)
    put(m, sk, 0.45, bump=0.25)
    spk(m, (196, 92, 76), 0.45)

    # eyes: glossy dark olive-black balls with a lighter ring, a big glint
    m = c.mask(EYE)
    ey = full((44, 48, 34))
    for ce, cn, r in eye_spots():
        d = P - ce
        dl = np.maximum(np.linalg.norm(d, axis=1), 1e-6)
        dn = d / dl[:, None]
        g = cn * 0.5 + v3((0, -1, 0)) * 0.5
        g /= np.linalg.norm(g)
        mine = m & (dl < r * 1.3)
        ang = np.arccos(np.clip(dn @ g, -1, 1))
        ey[mine] = lerp(ey, srgb(84, 92, 58), smooth(0.3, 0.55, ang) * smooth(0.85, 0.6, ang) * 0.6)[mine]
        ey[mine] = lerp(ey, srgb(230, 220, 200), smooth(0.85, 1.3, ang))[mine]
        c.draw(mine, (ang - 0.3) * r, 0.0)
        gl = smooth(0.03, 0.01, (dn[:, 0] + 0.25) ** 2 + (dn[:, 2] - 0.45) ** 2) * mine
        ey = lerp(ey, srgb(255, 255, 250), gl)
        c.ink[mine & (gl > 0.4), 2] = 0.0
    put(m, ey, 0.06)

    m = c.mask(LIP, LIP_L)
    lp = full((228, 120, 132))
    lp = lerp(lp, srgb(160, 66, 84), c.cavity * 0.8)
    lp = lerp(lp, srgb(246, 168, 176), c.wear * 0.5)
    put(m, lp, 0.25, bump=0.2)
    put(c.mask(TOOTH), srgb(232, 214, 160), 0.35)
    put(c.mask(TONGUE), lerp(full((206, 100, 110)), srgb(150, 60, 70), c.cavity), 0.35)

    # overalls: olive cotton drill, stained and paint-flecked, light worn seams; the steel chain and buckles
    m = c.mask(DENIM)
    dn_ = full((104, 102, 58))
    dn_ *= (1.0 + 0.1 * mott)[:, None]
    dn_ = lerp(dn_, srgb(60, 58, 32), c.cavity * 0.6)
    dn_ = lerp(dn_, srgb(150, 146, 92), c.wear * 0.5)
    flecks = smooth(0.38, 0.45, noise3(P + 9.0, 0.02) * 0.7 + noise3(P, 0.006) * 0.3)
    dn_ = lerp(dn_, srgb(196, 160, 80), flecks * 0.7)
    put(m, dn_, 0.88, bump=1.0)
    spk(m, (190, 150, 74), 0.35)
    put(c.mask(METAL), srgb(200, 200, 206) * (1.0 - 0.4 * c.cavity)[:, None], 0.28, metal=1.0, grain=1.0)
    put(c.mask(PENCIL), srgb(196, 40, 40), 0.4)

    # sneakers: one mustard and brown, one dusty pink and grey, one grey with purple stripes; chunky cream soles, mud
    m = c.mask(SHOE)
    sh = full((128, 128, 128))
    for side, xx in LEGS:
        mine = m & (np.abs(x - xx) < 0.2)
        base, panel = {"R": ((214, 170, 70), (92, 70, 48)), "C": ((210, 186, 176), (192, 120, 120)), "L": ((140, 136, 134), (140, 80, 150))}[side]
        f = rot(rz=SHOE_YAW[side]) @ v3((0, -1, 0))
        u = (P - v3((xx, 0, 0))) @ f
        stripe = (np.abs(np.sin(u * 30.0 + z * 18.0)) > 0.7) & (z > 0.06) & (z < 0.13)
        col = np.where(stripe[:, None], srgb(*panel), srgb(*base))
        sh[mine] = col[mine]
    sh = lerp(sh, srgb(150, 120, 90), smooth(0.4, 0.8, noise3(P, 0.012)) * 0.25)
    sh = lerp(sh, srgb(240, 236, 226), c.wear * 0.3)
    put(m, sh, 0.65, bump=0.7, grain=1.0)
    m = c.mask(SOLE)
    put(m, lerp(full((230, 220, 202)), srgb(150, 116, 84), smooth(0.03, 0.0, z) * 0.6), 0.8, bump=0.4, grain=1.0)
    spk(m, (150, 104, 70), 0.6)
    put(c.mask(SOCK), srgb(232, 228, 220), 0.9, bump=1.0)
    put(c.mask(LACE), srgb(232, 226, 214), 0.8, bump=0.5)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"body": 3200, "overalls": 2600, "limbs": 1000, "shoes": 1800},
    "density": {"body": 1.3},
    "tex": 2048,
    "stride": {"walk": 0.45, "run": 0.8},
    "speed": 0.95,
    "look": ["body"], "neck": "hips",
    "look_pivot": (0.0, 0.0, 0.72),
    "radius": 0.62,
}


def rig_bones():
    from kit.rig import Bone
    bones = [
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.0, 0.55), (0, 0.0, 0.7), "root", 0.3),
        Bone("body", (0, 0.0, 0.7), (0, 0.0, 1.0), "hips", 0.3),
        Bone("end.L", (0.2, 0.0, 0.8), (0.55, 0.0, 0.9), "body", 0.2),
        Bone("end.R", (-0.25, 0.0, 0.75), (-0.62, 0.0, 0.75), "body", 0.24),
        Bone("jaw", LIP_C, LIP_C + LIP_N * 0.15 - UP * 0.08, "end.L", 0.05),
    ]
    for sd, sh, el, wr, R, par in (("R", R_SH, R_EL, R_WR, R_HAND, "end.R"), ("L", L_SH, L_EL, L_WR, L_HAND, "end.L")):
        hend = wr - R[:, 2] * 0.05
        bones += [Bone("upper_arm." + sd, sh, el, par, 0.022), Bone("forearm." + sd, el, wr, "upper_arm." + sd, 0.02), Bone("hand." + sd, wr, hend, "forearm." + sd, 0.018)]
    for sd, x in LEGS:
        f = rot(rz=SHOE_YAW[sd]) @ v3((0, -1, 0))
        bones += [Bone("thigh." + sd, (x, 0.0, HIP_Z), (x, -0.01, KNEE_Z), "hips", 0.034), Bone("shin." + sd, (x, -0.01, KNEE_Z), (x, 0.0, ANKLE_Z), "thigh." + sd, 0.03),
                  Bone("foot." + sd, (x, 0.0, ANKLE_Z), v3((x, 0.0, 0.05)) + f * 0.2, "shin." + sd, 0.06)]
    return bones


def skin_rules(P, part, piece, names):
    """pieces: 0 body, 1 overalls, 2 limbs, 3 shoes"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    bp = piece == 0
    allow(bp, "hips", "body")
    allow(bp & (x > 0.1), "end.L")
    allow(bp & (x < -0.1), "end.R")
    rig[bp & np.isin(part, (LIP, TOOTH)) & (((P - LIP_C) @ UP) > -0.01)] = ix["end.L"]
    rig[bp & (np.isin(part, (LIP_L, TONGUE)) | (np.isin(part, (TOOTH,)) & (((P - LIP_C) @ UP) <= -0.01)))] = ix["jaw"]
    rig[bp & (part == EYE)] = ix["body"]
    op = piece == 1
    allow(op, "hips", "body")
    allow(op & (x > 0.15), "end.L")
    allow(op & (x < -0.15), "end.R")
    for sd, xx in LEGS:
        allow(op & (np.abs(x - xx) < 0.18) & (z < 0.56), "thigh." + sd)
    lp = piece == 2
    for sd, sh, wr, R in (("R", R_SH, R_WR, R_HAND), ("L", L_SH, L_WR, L_HAND)):
        arm = lp & (z > 0.7) & ((x < 0) if sd == "R" else (x > 0))
        allow(arm, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        rig[arm & (((P - wr) @ (-R[:, 2])) > 0.006)] = ix["hand." + sd]
    for sd, xx in LEGS:
        leg = lp & (z <= 0.7) & (np.abs(x - xx) < 0.15)
        allow(leg, "thigh." + sd, "shin." + sd)
        allow(leg & (z > HIP_Z), "hips")
        shoe = (piece == 3) & (np.abs(x - xx) < 0.2)
        rig[shoe] = ix["foot." + sd]
        allow(shoe, "foot." + sd)
    return A, rig


PH = {"L": 0.0, "C": 1.0 / 3.0, "R": 2.0 / 3.0}            # a ripple across its three legs: left, middle, right
WALK = dict(stride=0.45, stance=0.58, lift=0.07, bob=0.018, drop=0.02, roll=6.0, yaw=5.0, lean=5.0, toe_off=12.0, swing=8.0)
RUN = dict(stride=0.8, stance=0.45, lift=0.11, bob=0.035, drop=0.04, roll=8.0, yaw=7.0, lean=12.0, toe_off=18.0, swing=12.0)


def motions(rig):
    """walk: a hurried three-legged waddle: the feet patter left-middle-right, the bean rolls over whichever foot is down and jiggles at its ends,
    the lips flap with puffing breath, the raised hand flaps 'wait!'; run: the same at a scramble; idle: impatient, tapping the middle foot, the bean
    breathing, the lips working, the raised hand checking an imaginary watch"""
    import math
    from kit.gait import Pose, Leg, R, TAU, ease
    from mathutils import Vector, Matrix
    legs = {}
    for sd, x in LEGS:
        f = rot(rz=SHOE_YAW[sd]) @ v3((0, -1, 0))
        legs[sd] = (Leg("thigh." + sd, "shin." + sd, "foot." + sd, (v3((x, 0.0, 0.0)) + f * 0.08).tolist(), sd), f)

    def foot(p, sd, ball, pitch):
        lg, f = legs[sd]
        fw = Vector(f.tolist())
        wf = Matrix.Rotation(math.radians(pitch), 3, Vector((0, 0, 1)).cross(fw))
        ankle = ball + wf @ (rig.head[lg.foot] - lg.ball)
        p.ik[lg.thigh] = (ankle, Vector((0.0, -1.0, 0.0)), lg.foot, wf)

    def walkish(u, g, run):
        p = Pose()
        S, beta = g["stride"], g["stance"]
        roll = g["roll"] * math.sin(TAU * u + 0.5)
        p.offset = Vector((0.02 * math.sin(TAU * u + 0.5), 0.0, -g["drop"] + g["bob"] * math.cos(3 * TAU * u)))
        p.rot("hips", g["lean"], roll, -g["yaw"] * math.cos(TAU * u))
        p.rot("body", 1.5 * math.sin(3 * TAU * u - 1.0), -roll * 0.3, 0.0)
        jig = math.sin(3 * TAU * u - 1.6)
        p.rot("end.L", 0.0, -3.0 * jig, 0.0)
        p.rot("end.R", 0.0, 3.0 * jig, 0.0)
        for sd, x in LEGS:
            lg, f = legs[sd]
            uu = (u + PH[sd]) % 1.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                lift, pitch = 0.0, g["toe_off"] * ease((uu - (beta - 0.15)) / 0.15)
            else:
                t = (uu - beta) / (1.0 - beta)
                fy = S * beta / 2 - S * beta * ease(t)
                lift = g["lift"] * math.sin(math.pi * t) ** 0.8
                pitch = g["toe_off"] * (1.0 - ease(t * 1.6)) - g["swing"] * math.sin(math.pi * t)
            foot(p, sd, Vector((lg.ball.x, lg.ball.y + fy, lift)), pitch)
        p.rot("jaw", 6.0 + 6.0 * max(0.0, math.sin(3 * TAU * u)), 0.0, 0.0)
        p.rot("upper_arm.L", 0.0, 0.0, 10.0 * math.sin(3 * TAU * u))
        p.rot("hand.L", 0.0, (25.0 if run else 15.0) * math.sin(3 * TAU * u + 1.0), 0.0)
        p.rot("upper_arm.R", 4.0 * math.sin(TAU * u), 0.0, 0.0)
        return p

    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    def win(t, a, b, e=0.25):
        return ease((t - a) / e) * (1.0 - ease((t - b) / e))

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        p.offset = Vector((0.0, 0.0, -0.006 + 0.005 * math.sin(TAU * t / 2.0)))
        p.rot("hips", 1.0 * math.sin(TAU * t / 3.0), 1.5 * math.sin(TAU * t / 6.0), 0.0)
        p.rot("body", 1.0 * math.sin(TAU * t / 2.0), 0.0, 0.0)
        tap = max(win(t, 0.6, 0.85, 0.08), win(t, 1.0, 1.25, 0.08), win(t, 1.4, 1.65, 0.08), win(t, 4.0, 4.25, 0.08), win(t, 4.4, 4.65, 0.08))
        for sd, x in LEGS:
            lg, f = legs[sd]
            if sd == "C":
                foot(p, sd, Vector((lg.ball.x, lg.ball.y, 0.0)), -14.0 * tap)
            else:
                foot(p, sd, Vector((lg.ball.x, lg.ball.y, 0.0)), 0.0)
        look = win(t, 2.2, 3.4, 0.3)                      # the raised hand turned to look at its wrist, the bean tipping toward it
        p.rot("end.L", 0.0, -3.0 * look, 0.0)
        p.rot("forearm.L", -12.0 * look, 0.0, 30.0 * look)
        p.rot("hand.L", 0.0, 0.0, -20.0 * look + 8.0 * math.sin(TAU * t * 1.3) * (1.0 - look))
        p.rot("jaw", 4.0 + 8.0 * win(t, 3.6, 5.2) * max(0.0, math.sin(TAU * t * 3.0)) + 2.0 * math.sin(TAU * t / 2.0), 0.0, 0.0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
