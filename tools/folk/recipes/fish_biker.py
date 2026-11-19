## FOINT CITY townsfolk: the fish biker (working name; the user names him). A hulking teal fish-faced goth biker, 1.90 m: a blocky head sunk between huge shoulders, a wide toothy grin, a big yellow eye each side, a maroon fin crest; sleeveless long leather coat, chains, maroon shirt, black jeans, buckled boots; hands in his pockets.
# Concept: the user's sheet 5.webp, top middle (F:/prog-godot-cache/folk/refs/5.webp, box 431,2,695,386). Measured off it (head top to heel 350 px, 5.4 mm a pixel):
# the head 0.24 m tall and about 0.30 wide, flat-topped, its jaw resting on his chest (no neck shows); the crest 9 cm over it; the shoulders' bulk up to 1.70 m,
# the arms enormous (deltoids 0.12 m round, elbows held out half a metre from his middle), chest 1.51, belt 1.21, crotch 0.98, knees 0.60, boot tops 0.40,
# block heels 6 cm. The coat reaches his knees, open at the front, no sleeves. The skin reads as facets of teal and sea-green (painted, not modelled).
# Rest pose = how he always walks: hands pushed into his front jeans pockets, elbows out; the hands are not built past the cuffs (they are in the pockets).
import math
import os
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3, ridge_line)

HEIGHT = 1.90
REF = ("5.webp", (431, 2, 695, 386))

SKIN, EYE, MOUTH, TOOTH, CREST, SHIRT, COAT, LINING, JEANS, BELT, SILVER, BOOT, SOLE, CUFF, ARM = range(1, 16)
COLOURS = {
    SKIN: ((0.22, 0.42, 0.38), 0.55, 0.0),
    ARM: ((0.22, 0.42, 0.38), 0.55, 0.0),
    EYE: ((0.95, 0.62, 0.08), 0.15, 0.0),
    MOUTH: ((0.06, 0.02, 0.03), 0.6, 0.0),
    TOOTH: ((0.85, 0.80, 0.66), 0.3, 0.0),
    CREST: ((0.18, 0.05, 0.10), 0.45, 0.0),
    SHIRT: ((0.20, 0.05, 0.10), 0.85, 0.0),
    COAT: ((0.05, 0.035, 0.035), 0.4, 0.0),
    LINING: ((0.22, 0.04, 0.07), 0.6, 0.0),
    JEANS: ((0.04, 0.035, 0.04), 0.8, 0.0),
    BELT: ((0.03, 0.025, 0.025), 0.4, 0.0),
    SILVER: ((0.75, 0.75, 0.78), 0.25, 1.0),
    BOOT: ((0.05, 0.035, 0.035), 0.3, 0.0),
    SOLE: ((0.02, 0.02, 0.02), 0.6, 0.0),
    CUFF: ((0.05, 0.035, 0.035), 0.35, 0.0),
}

# landmarks, left side (+X); the figure faces -Y
SHOULDER = v3((0.30, 0.03, 1.60))
ELBOW = v3((0.50, 0.05, 1.32))
WRIST = v3((0.245, -0.15, 1.12))        # at the mouth of his front pocket
POCKET = v3((0.17, -0.10, 1.06))          # where the hand is, inside the jeans
HIP = v3((0.115, 0.01, 1.04))
KNEE = v3((0.125, -0.01, 0.60))
ANKLE = v3((0.135, 0.03, 0.17))
BALL = v3((0.14, -0.10, 0.0))
HEAD_C = v3((0.0, -0.03, 1.79))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


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
    """a blocky fish head: a flat-topped cranium over a heavier, wider jaw, a blunt front, brow ridges over the eyes, the back of it running into his traps"""
    cran = Box((0, -0.035, 1.826), (0.125, 0.172, 0.068), rr=0.062)
    jaw = Box((0, -0.02, 1.735), (0.148, 0.168, 0.062), rr=0.058)
    snout = Ellipsoid((0, -0.15, 1.782), (0.112, 0.07, 0.082))
    back = Ellipsoid((0, 0.08, 1.75), (0.15, 0.12, 0.12))
    neck = RoundCone((0, 0.05, 1.56), (0, 0.04, 1.70), 0.12, 0.13)
    brow = Mirror(Ellipsoid((0.095, -0.085, 1.862), (0.058, 0.07, 0.026), R=rot(ry=-14)))
    head = Union([cran, jaw, snout, back, neck], k=0.05)
    head = Union([head, brow], k=0.025, part=SKIN)
    # grown 12% about the jaw and sunk 3 cm into his shoulders: the concept's head is bigger against his bulk than first built.
    # (Move's own bound only covers a shrink, so the grown bound is set here.)
    pv, t, s = v3((0, -0.03, 1.70)), v3((0, 0, -0.03)), 1.12
    big = Move(head, R=np.eye(3, dtype=np.float32) / s, pivot=pv, t=t)
    lo, hi = head.bound()
    big.lo, big.hi = pv + t + (lo - pv) * s, pv + t + (hi - pv) * s
    return big


HEAD0 = head_base()


class Eye:
    def __init__(self, c, f, r, lid, slant, low):
        self.c, self.f, self.r = c, f, r
        up = v3((0, 0, 1)) - f * float(f[2])
        self.up = up / np.linalg.norm(up)
        self.fwd = np.cross(f, self.up)          # along the eye toward the snout, for a left eye looking out (+X)
        if self.fwd[1] > 0:
            self.fwd = -self.fwd
        self.lid_pt = c + self.up * (lid * r)
        n = -self.up + self.fwd * slant
        self.lid_n = n / np.linalg.norm(n)
        self.low = low


def _eye():
    d = v3((0.86, -0.46, 0.12))
    d /= np.linalg.norm(d)
    p, n = hit(HEAD0, HEAD_C + v3((0, -0.045, 0.03)) + d * 0.5, -d)
    f = n * 0.5 + d * 0.5
    f /= np.linalg.norm(f)
    r = 0.052
    return Eye(p - f * (r * 0.42), f, r, 0.12, 0.22, 0.62)


EYE_L = _eye()
MOUTH_Z = 1.745


def mouth_path(dz=0.0, inset=0.0, n=17, span=105.0):
    """the grin: points round the face at mouth height, from his right cheek round the snout to his left, rising a little to the corners"""
    pts = []
    for th in np.linspace(-span, span, n):
        a = math.radians(th)
        d = v3((math.sin(a), -math.cos(a), 0.0))
        z = MOUTH_Z + dz + 0.016 * (abs(th) / span) ** 2.2
        o = v3((0, -0.03, z)) + d * 0.5
        p, nn = hit(HEAD0, o, -d)
        pts.append((p - nn * inset, th / span))
    return pts


def head():
    e = EYE_L
    lid = Clip(Sphere(e.c, e.r + 0.007, part=SKIN), [Half(e.lid_pt, e.lid_n)], k=0.004)
    lower = Clip(Sphere(e.c, e.r + 0.005, part=SKIN), [Half(e.c - e.up * (e.r * e.low), e.up)], k=0.004)
    face = Union([HEAD0, Mirror(Union([lid, lower]))], k=0.008)
    # the grin: a deep groove round the face, wide open at the front, closing to the corners; small sharp teeth along both gums
    path = mouth_path(inset=0.004)
    groove = loft([(p, 0.006 + 0.015 * (1.0 - abs(t) ** 2)) for p, t in path], k=0.005)
    lip = loft([(p + v3((0, 0, -0.012 * (1 - abs(t) ** 2))), 0.006 + 0.004 * (1.0 - abs(t) ** 2)) for p, t in mouth_path(dz=-0.012, inset=-0.001)], k=0.004)
    face = Union([face, Inflate(lip, 0.0, part=SKIN)], k=0.01)
    face = Cut(face, [groove], k=0.003)
    inner = loft([(p, 0.005 + 0.011 * (1.0 - abs(t) ** 2)) for p, t in mouth_path(inset=0.02)], part=MOUTH, k=0.004)
    teeth = []
    for j, (p, t) in enumerate(mouth_path(inset=0.008, n=13, span=90.0)[1:-1]):
        h = (0.011 * (1.0 - abs(t) ** 2) + 0.005) * (1.0, 0.7, 1.15, 0.85, 1.0, 0.6, 1.1)[j % 7]
        teeth.append(Gem(p + v3((0, 0, 0.015 * (1 - abs(t) ** 2) + 0.004 - h * 0.5)), (0.0075, 0.0075, 0.005, 0.005, h, 0.002), soft=0.25, part=TOOTH))
        teeth.append(Gem(p + v3((0, 0, -0.015 * (1 - abs(t) ** 2) - 0.004 + h * 0.5)), (0.0075, 0.0075, 0.005, 0.005, 0.002, h * 0.75), soft=0.25, part=TOOTH))
    ball = Mirror(Sphere(e.c, e.r, part=EYE))
    return Union([face, inner, ball] + teeth, k=0.0)


def crest():
    """the fin crest: dark maroon spines along the top of his head and fanned out behind it, each a pointed blade with a ridge"""
    spines = []
    spec = [  # (along the top -0.1..0.2, x, angle up from back, length, base width)
        (-0.10, 0.0, 62, 0.10, 0.05), (-0.05, 0.0, 55, 0.13, 0.055), (0.0, 0.0, 48, 0.15, 0.06), (0.05, 0.0, 40, 0.17, 0.06),
        (0.10, 0.0, 32, 0.18, 0.06), (0.15, 0.0, 24, 0.17, 0.055), (0.19, 0.0, 14, 0.15, 0.05),
        (-0.02, 0.05, 44, 0.12, 0.045), (0.06, 0.06, 30, 0.14, 0.05), (0.14, 0.065, 16, 0.14, 0.05),
        (-0.02, -0.05, 44, 0.12, 0.045), (0.06, -0.06, 30, 0.14, 0.05), (0.14, -0.065, 16, 0.14, 0.05)]
    for y, x, ang, L, W in spec:
        p, n = hit(HEAD0, (x, y, 2.2), (0, 0, -1))
        root = p - v3((0, 0, 0.012))
        a = math.radians(ang)
        eu = v3((x * 2.0, math.cos(a), math.sin(a)))
        eu /= np.linalg.norm(eu)
        en = np.cross(eu, v3((0, 0, 1)))
        en /= np.linalg.norm(en)
        ev = np.cross(en, eu)
        R = np.stack([eu, ev, en], 1).astype(np.float32)
        poly = [(0.0, W * 0.5), (L * 0.55, W * 0.32), (L, 0.0), (L * 0.5, -W * 0.25), (0.0, -W * 0.5)]
        blade = Slab(root, poly, 0.007, rr=0.004, R=R, part=CREST)
        rib = RoundCone(root, root + eu * L * 0.92, 0.012, 0.002, part=CREST)
        spines.append(Union([blade, rib], k=0.006))
    return Union(spines, k=0.005)


# ---------------------------------------------------------------------------------------------------- the body

def torso_core():
    """a barrel chest and a thick middle (the shirt is this, grown a little)"""
    return Union([
        Ellipsoid((0, 0.0, 1.50), (0.25, 0.17, 0.19)),
        Ellipsoid((0, 0.05, 1.63), (0.24, 0.13, 0.08)),
        Mirror(Ellipsoid((0.11, -0.07, 1.52), (0.11, 0.09, 0.08))),
        Ellipsoid((0, 0.01, 1.27), (0.215, 0.155, 0.13)),
        Ellipsoid((0, 0.015, 1.10), (0.205, 0.145, 0.11)),
    ], k=0.07, part=SHIRT)


def arm():
    """the bare arm, shoulder to wrist: a huge deltoid, a biceps, a heavy forearm; the leather cuff at the wrist"""
    S, E, W = SHOULDER, ELBOW, WRIST
    delt = Ellipsoid(S + v3((0.03, 0.0, 0.03)), (0.12, 0.115, 0.12), part=ARM)
    up = loft([(S, 0.105), (S + (E - S) * 0.45, 0.098), (E, 0.075)], part=ARM, k=0.02)
    bic = Ellipsoid(S + (E - S) * 0.45 + v3((0.0, -0.05, 0.0)), (0.08, 0.07, 0.11), R=basis(E - S, v3((0, -1, 0))), part=ARM)
    fore = loft([(E, 0.075), (E + (W - E) * 0.35, 0.085), (W, 0.056)], part=ARM, k=0.02)
    d = (W - E) / np.linalg.norm(W - E)
    cuff = CappedCone(W - d * 0.09, W - d * 0.005, 0.066, 0.06, rr=0.006, part=CUFF)
    hand = Ellipsoid(POCKET + v3((0.0, -0.005, 0.02)), (0.045, 0.04, 0.055), R=basis(d, v3((0, 0, 1))), part=ARM)
    a = Union([Union([delt, up, bic], k=0.03), fore], k=0.025)
    return Union([a, hand], k=0.02), cuff


def coat(core):
    """the long sleeveless leather coat: shoulders squared over the deltoids, a popped collar behind his head, wide lapels, open down the front; the skirt to his knees, lined"""
    cap = Clip(Inflate(Ellipsoid(SHOULDER + v3((0.03, 0.0, 0.03)), (0.12, 0.115, 0.12)), 0.016), [Half((0, 0, 1.62), (0.12, 0, -1))], k=0.012)
    body = Union([Inflate(core, 0.024), Mirror(cap)], k=0.07, part=COAT)
    body = Clip(body, [Half((0, 0, 1.08), (0, 0, -1))], k=0.004)
    # armholes, a big open front from the collar to the waist
    body = Cut(body, [Mirror(Ellipsoid((0.37, 0.03, 1.52), (0.12, 0.16, 0.13)))], k=0.01)
    R = np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32)
    front = Slab((0, -0.3, 0), [(-0.11, 1.75), (0.11, 1.75), (0.19, 1.30), (0.22, 1.0), (-0.22, 1.0), (-0.19, 1.30)], 0.3, R=R)
    body = Cut(body, [front], k=0.01)
    # lapels: a thicker layer of the coat folded back either side of the opening
    lap = Slab((0, -0.3, 0), [(0.10, 1.70), (0.14, 1.34), (0.21, 1.48), (0.24, 1.62), (0.19, 1.68), (0.20, 1.73)], 0.3, R=R)
    lapel = Clip(Inflate(core, 0.036, part=COAT), [Mirror(lap)], k=0.008)
    # the collar: a band standing up behind his head and out to the sides
    collar = Clip(Cut(Ellipsoid((0, 0.05, 1.70), (0.21, 0.16, 0.16), part=COAT), [Ellipsoid((0, 0.04, 1.72), (0.19, 0.14, 0.17))], k=0.005),
                  [Half((0, 0, 1.64), (0, 0, -1)), Half((0, -0.02, 1.64), (0, -1, -0.3))], k=0.006)
    # the skirt: a lined shell from the waist to the knees, flaring, open at the front
    outer = Union([CappedCone((0, 0.02, 1.16), (0, 0.04, 0.52), 0.235, 0.30)], part=COAT)
    skirt = Move(Cut(Inflate(outer, 0.0, part=COAT), [Inflate(outer, -0.014)], k=0.0), R=np.diag([1.0, 1 / 0.82, 1.0]).astype(np.float32), pivot=(0, 0.03, 0))
    gap = Slab((0, -0.3, 0), [(-0.2, 1.2), (0.2, 1.2), (0.27, 0.40), (-0.27, 0.40)], 0.3, R=R)
    skirt = Clip(Cut(skirt, [gap], k=0.01), [Half((0, 0, 1.16), (0, 0, 1))], k=0.003)
    return Union([Union([body, skirt], k=0.03), lapel, collar], k=0.006)


def legs():
    hips = Union([
        Ellipsoid((0, 0.015, 1.10), (0.21, 0.15, 0.11)),
        Mirror(Ellipsoid((0.085, 0.06, 1.0), (0.1, 0.09, 0.09))),
    ], k=0.05, part=JEANS)
    leg = loft([(HIP, 0.11), (v3((0.12, 0.0, 0.84)), 0.095), (KNEE, 0.078), (v3((0.13, 0.01, 0.42)), 0.08), (v3((0.133, 0.02, 0.38)), 0.088)], part=JEANS, k=0.03)
    # bunched over the boot tops
    bunch = Torus((0.133, 0.02, 0.40), 0.082, 0.014, part=JEANS)
    jeans = Union([hips, Mirror(Union([leg, bunch], k=0.02))], k=0.05)
    return Clip(jeans, [Half((0, 0, 1.215), (0, 0.05, 1))], k=0.004)


def belt():
    hipcore = Ellipsoid((0, 0.015, 1.10), (0.21, 0.15, 0.11))
    return Clip(Inflate(hipcore, 0.012, part=BELT), [Half((0, 0, 1.232), (0, 0.05, 1)), Half((0, 0, 1.19), (0, -0.05, -1))], k=0.003)


def boot():
    shaft = RoundCone(v3((0.135, 0.03, 0.40)), ANKLE, 0.085, 0.07, part=BOOT)
    foot = Box((0.14, -0.05, 0.09), (0.066, 0.13, 0.055), rr=0.04, part=BOOT)
    toe = Box((0.14, -0.15, 0.065), (0.064, 0.065, 0.032), rr=0.026, part=BOOT)
    sole = Box((0.14, -0.09, 0.018), (0.074, 0.13, 0.018), rr=0.008, part=SOLE)
    heel = Box((0.14, 0.045, 0.035), (0.055, 0.045, 0.035), rr=0.006, part=SOLE)
    straps = []
    for z, r in ((0.33, 0.091), (0.25, 0.085), (0.18, 0.08)):
        straps.append(CappedCone((0.135, 0.03, z - 0.013), (0.135, 0.03, z + 0.013), r, r - 0.002, rr=0.005, part=CUFF))
    instep = Clip(Inflate(foot, 0.008, part=CUFF), [Half((0, -0.04, 0), (0, 1, 0.5)), Half((0, -0.08, 0), (0, -1, -0.5))], k=0.003)
    b = Union([shaft, Union([foot, toe], k=0.03)], k=0.03)
    return Union([b, sole, heel, instep] + straps, k=0.004)


def body():
    core = torso_core()
    a, cuff = arm()
    skin = Union([core, Mirror(a)], k=0.0)
    return Union([skin, coat(core), legs(), belt(), Mirror(boot()), Mirror(cuff)], k=0.0)


# ---------------------------------------------------------------------------------------------------- chains and buckles

def chain(pts, R=0.012, r=0.0038, part=SILVER):
    """links along a polyline, each turned a quarter to the last"""
    out = []
    P = [v3(p) for p in pts]
    L = [0.0]
    for i in range(1, len(P)):
        L.append(L[-1] + float(np.linalg.norm(P[i] - P[i - 1])))
    step = R * 1.55
    s = 0.0
    k = 0
    while s <= L[-1]:
        i = max(1, int(np.searchsorted(L, s)))
        i = min(i, len(P) - 1)
        t = (s - L[i - 1]) / max(L[i] - L[i - 1], 1e-6)
        c = P[i - 1] + (P[i] - P[i - 1]) * t
        d = (P[i] - P[i - 1]) / max(np.linalg.norm(P[i] - P[i - 1]), 1e-6)
        side = np.cross(d, v3((0, 0, 1)))
        if np.linalg.norm(side) < 1e-3:
            side = v3((1, 0, 0))
        side /= np.linalg.norm(side)
        n = np.cross(d, side) if k % 2 else side
        M = basis(n, d)
        out.append(Move(Box((0, 0, 0), (R * 0.5, R, r), rr=r * 0.98, part=part), R=M, t=c))
        out.append(Move(Box((0, 0, 0), (R * 0.5 - r * 1.4, R - r * 1.6, r * 2.0)), R=M, t=c))
        s += step
        k += 1
    links = [Cut(out[i], [out[i + 1]], k=0.0) for i in range(0, len(out), 2)]
    return links


def necklace():
    core = Inflate(torso_core(), 0.006)
    pts = []
    for t in np.linspace(0.0, 1.0, 11):
        a = math.radians(-70 + 70 * t)
        x = 0.15 * math.sin(-a) * (1.0 - 0.15 * t)
        z = 1.64 - 0.10 * t ** 1.3
        p, n = hit(core, (x, -0.5, z), (0, 1, 0))
        pts.append(p + n * 0.006)
    left = pts
    right = [p * FLIP.diagonal() for p in pts[::-1]]
    links = chain(right + left[1:], R=0.021, r=0.0058)
    end = pts[-1]
    Rf = np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32)
    c = end + v3((0, -0.01, -0.045))
    outer = Slab(c, [(0, 0.036), (0.022, 0), (0, -0.036), (-0.022, 0)], 0.004, rr=0.0015, R=Rf, part=SILVER)
    inner = Slab(c, [(0, 0.026), (0.013, 0), (0, -0.026), (-0.013, 0)], 0.008, R=Rf)
    stone = Gem(c + v3((0, 0.002, 0)), (0.012, 0.012, 0.004, 0.004, 0.024, 0.024), soft=0.1, part=CREST)
    bail = Torus(end + v3((0, -0.006, -0.008)), 0.006, 0.002, Rm=rot(ry=90), part=SILVER)
    return links + [Cut(outer, [inner], k=0.0), stone, bail]


def wallet_chain():
    """from a belt loop at his right front hip, a loop of chain down his thigh and back up to his back pocket"""
    a = v3((-0.12, -0.15, 1.20))
    pts = [a, v3((-0.15, -0.14, 1.08)), v3((-0.19, -0.11, 0.97)), v3((-0.215, -0.05, 0.93)), v3((-0.225, 0.03, 0.95)), v3((-0.21, 0.09, 1.04)), v3((-0.17, 0.13, 1.12))]
    return chain(pts, R=0.011, r=0.0032)


def buckles():
    def frame(c, w, h, Rm, t=0.004):
        return Cut(Box(c, (w, t, h), rr=0.002, R=Rm, part=SILVER), [Box(c, (w - 0.006, t * 3, h - 0.006), R=Rm)], k=0.0)
    out = []
    p, n = hit(Ellipsoid((0, 0.015, 1.10), (0.222, 0.162, 0.122)), (0.0, -0.5, 1.212), (0, 1, 0))
    out.append(frame(p + v3((0, -0.004, 0)), 0.04, 0.026, np.eye(3, dtype=np.float32)))
    # the cuffs' buckles, on the outside of each wrist
    d = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    side = np.cross(d, v3((0, 0, 1)))
    side /= np.linalg.norm(side)
    up = np.cross(side, d)
    for k, off in enumerate((0.03, 0.065)):
        c = WRIST - d * off + up * 0.068
        out.append(Mirror(frame(c, 0.017, 0.02, basis(d, up))))
    # the boots' buckles, on the outside of each strap
    for z, r in ((0.33, 0.091), (0.25, 0.085), (0.18, 0.08)):
        c = v3((0.135 + r + 0.004, 0.03, z))
        out.append(Mirror(frame(c, 0.016, 0.016, basis(v3((0, 0, 1)), v3((1, 0, 0))), t=0.003)))
    c = v3((0.205, -0.075, 0.11))
    out.append(Mirror(frame(c, 0.015, 0.015, basis(v3((0, 0.3, 1.0)), v3((1, -0.3, 0.4))), t=0.003)))
    # studs down the lapels
    for t in np.linspace(0.1, 0.9, 3):
        c = v3((0.10 + 0.08 * t, -0.165 + 0.02 * t, 1.69 - 0.3 * t))
        p, n = hit(Inflate(torso_core(), 0.036), (c[0], -0.5, c[2]), (0, 1, 0))
        out.append(Mirror(Sphere(p + n * 0.002, 0.006, part=SILVER)))
    return out


def jewels():
    return Union(necklace() + wallet_chain() + buckles(), k=0.0)


def pieces():
    only = os.environ.get("FOLK_ONLY", "")
    out = [("head", head, 0.0019), ("crest", crest, 0.0025), ("body", body, 0.0046), ("jewels", jewels, 0.0016)]
    return [(n, f(), h) for n, f, h in out if not only or n in only.split(",")]


# ---------------------------------------------------------------------------------------------------- paint

def facets(P, size=0.032, seed=7):
    """a cell id and a random 0..1 per point from jittered 3D cells: the concept's faceted, low-poly look of his skin"""
    q = P / size
    base = np.floor(q).astype(np.int64)
    best = np.full(len(P), 1e9, np.float32)
    rnd = np.zeros(len(P), np.float32)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = base + np.array([dx, dy, dz])
                h = (c[:, 0] * 73856093) ^ (c[:, 1] * 19349663) ^ (c[:, 2] * 83492791) ^ seed
                h = (h ^ (h >> 13)) * 1274126177
                jx = ((h >> 3) & 1023) / 1023.0
                jy = ((h >> 13) & 1023) / 1023.0
                jz = ((h >> 23) & 1023) / 1023.0
                pt = c + np.stack([jx, jy, jz], 1) * 0.8 + 0.1
                d = np.sum((q - pt) ** 2, 1)
                take = d < best
                best[take] = d[take]
                rnd[take] = (((h >> 33) & 1023) / 1023.0)[take]
    return rnd.astype(np.float32)


def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.009) * 0.25
    n3 = noise3(P + 1.7, 0.07)

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

    # skin: teal, broken into facets of sea-green, blue-green and the odd dusty violet; darker in the creases, a paler belly to the jaw
    m = c.mask(SKIN, ARM)
    f = facets(P)
    f2 = facets(P, 0.05, 3)
    sk = mix(np.broadcast_to(srgb(70, 122, 110), (len(P), 3)), srgb(126, 172, 156), f)
    sk = mix(sk, srgb(78, 116, 132), smooth(0.6, 0.9, f2) * 0.7)
    sk = mix(sk, srgb(118, 112, 146), smooth(0.8, 0.95, f) * 0.7)
    sk *= (1.0 + 0.05 * mott)[:, None]
    jaw = smooth(1.735, 1.665, z) * (P[:, 1] < 0.05) * (z > 1.58)
    sk = mix(sk, srgb(150, 178, 150), jaw * 0.45)
    # the eye's lid: a darker heavy brow, a thick dark line along its edge
    e = EYE_L
    de = Q - e.c
    r = np.linalg.norm(de, axis=1)
    pd = (Q - e.lid_pt) @ e.lid_n
    on_lid = (r < e.r + 0.016) & (pd < 0.0)
    sk = mix(sk, srgb(58, 92, 88), on_lid * 0.6)
    c.draw((r < e.r + 0.016) & (pd > -0.01) & (pd < 0.005) & (de @ e.f > -0.012), np.abs(pd + 0.0014), 0.0028)
    pl = (Q - (e.c - e.up * (e.r * e.low))) @ e.up
    c.draw((r < e.r + 0.012) & (np.abs(pl) < 0.006) & (de @ e.f > -0.008), np.abs(pl - 0.001), 0.0014, 0.8)
    sk = mix(sk, srgb(52, 80, 76), smooth(e.r + 0.02, e.r + 0.006, r) * (de @ e.f > -0.03) * 0.5)
    put(m, sk[m], 0.55, bump=0.25)
    spk(m, (60, 96, 90), 0.18)
    # the eye: gold going amber to the rim, a dark pupil looking ahead, a glint
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    g = e.f * 0.5 + v3((0, -1, 0)) * 0.5
    g /= np.linalg.norm(g)
    ang = np.arccos(np.clip(d @ g, -1, 1))
    ec = mix(np.broadcast_to(srgb(255, 214, 70), (len(P), 3)), srgb(236, 150, 26), smooth(0.2, 0.75, ang))
    ec = mix(ec, srgb(150, 76, 14), smooth(0.8, 1.1, ang))
    ec *= (1.0 - 0.45 * smooth(0.0, 0.3, d @ e.up))[:, None]
    c.draw(m, (np.sqrt((ang / 0.2) ** 2) - 1.0) * 0.2 * e.r, 0.0)
    gd = g + e.up * 0.35 + e.fwd * 0.2
    gd /= np.linalg.norm(gd)
    ec = mix(ec, srgb(255, 252, 236), smooth(0.984, 0.993, d @ gd))
    put(m, ec[m], 0.08)
    put(c.mask(MOUTH), srgb(40, 14, 20), 0.6)
    m = c.mask(TOOTH)
    put(m, (srgb(226, 214, 180) * (1.0 - 0.35 * c.cavity)[:, None])[m], 0.3)
    # the crest: dark maroon, lighter toward the tips and on the edges
    m = c.mask(CREST)
    hc = mix(np.broadcast_to(srgb(70, 26, 44), (len(P), 3)), srgb(118, 56, 80), smooth(1.9, 2.0, z) * 0.6 + c.wear * 0.4)
    put(m, hc[m], 0.45, bump=0.3)

    # the shirt: maroon cotton, faded on what stands out
    m = c.mask(SHIRT)
    put(m, (srgb(92, 30, 56) * (1.0 + 0.45 * c.wear + 0.05 * mott)[:, None])[m], 0.9, bump=1.0)
    # the coat: near-black brown leather, scuffed to a rusty brown on every edge and in patches, panels outlined by seams; the lining maroon
    m = c.mask(COAT)
    cc = np.broadcast_to(srgb(52, 40, 42), (len(P), 3)).copy() * (1.0 + 0.08 * mott)[:, None]
    cc = mix(cc, srgb(120, 78, 58), np.clip(c.wear * 0.9 + smooth(0.35, 0.7, n3) * 0.25, 0, 1))
    cc = mix(cc, srgb(28, 20, 22), c.cavity * 0.5)
    inside = np.zeros(len(P), bool)
    ax = np.stack([P[:, 0], P[:, 1] - 0.03], 1)
    nr = np.einsum("ij,ij->i", ax, c.N[:, :2]) / np.maximum(np.linalg.norm(ax, axis=1), 1e-6)
    inside = m & (z < 1.16) & (nr < -0.2)
    cc = np.where(inside[:, None], mix(cc, srgb(96, 26, 44), np.ones(len(P))), cc)
    put(m, cc[m], 0.42, bump=0.8, grain=1.0)
    put(inside, cc[inside], 0.7, bump=0.4, grain=0.0)
    # panel seams across the skirt and down its back
    sk_m = m & (z < 1.15) & ~inside
    for zz in (0.85,):
        c.draw(sk_m & (np.abs(z - zz) < 0.005), np.abs(z - zz), 0.0012, 0.5)
    c.draw(sk_m & (np.abs(P[:, 0]) < 0.006) & (P[:, 1] > 0), np.abs(P[:, 0]), 0.0012, 0.5)
    c.draw(m & (np.abs(z - 0.535) < 0.006), np.abs(z - 0.535), 0.0009, 0.4)
    # jeans: washed black denim, seams down the outside of each leg, the pocket's mouth
    m = c.mask(JEANS)
    jc = srgb(48, 42, 50) * (1.0 + 0.5 * c.wear + 0.06 * mott)[:, None]
    put(m, jc[m], 0.85, bump=1.0)
    kx = np.interp(z, [0.0, 0.6, 1.04], [0.135, 0.125, 0.115])
    phi = np.arctan2(Q[:, 0] - kx, -(P[:, 1] - 0.0))
    rad = np.hypot(Q[:, 0] - kx, P[:, 1])
    for a0 in (math.pi * 0.5, 0.15):
        dphi = np.abs(np.angle(np.exp(1j * (phi - a0))))
        c.draw(m & (z < 1.0) & (dphi * rad < 0.01), dphi * rad, 0.0011, 0.6)
    pocket = np.abs(np.hypot(Q[:, 0] - 0.30, z - 1.21) - 0.13)
    c.draw(m & (P[:, 1] < 0) & (pocket < 0.006) & (z > 1.06), pocket, 0.0012, 0.7)
    put(c.mask(BELT), (srgb(30, 24, 26) * (1.0 + 1.0 * c.wear)[:, None])[c.mask(BELT)], 0.35, bump=0.6, grain=1.0)
    m = c.mask(CUFF)
    put(m, (srgb(46, 32, 30) * (1.0 + 1.2 * c.wear)[:, None])[m], 0.35, bump=0.6, grain=1.0)
    m = c.mask(BOOT)
    put(m, (srgb(48, 34, 34) * (1.0 + 1.3 * c.wear)[:, None])[m], 0.25, bump=0.4, grain=1.0)
    put(c.mask(SOLE), srgb(24, 20, 20), 0.6, bump=0.4)
    m = c.mask(SILVER)
    put(m, (srgb(204, 202, 208) * (1.0 - 0.55 * c.cavity)[:, None])[m], 0.24, metal=1.0, bump=0.05, grain=1.0)
    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2100, "crest": 600, "body": 4700, "jewels": 1000},      # (decimation lands about 14% over these)
    "density": {"head": 1.7, "crest": 1.2, "jewels": 1.2},
    "tex": 2048,
    "stride": {"walk": 1.1, "run": 1.7},
    "speed": 0.88,                                                   # a slouchy swagger, never hurried
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.03, 1.70),
    "radius": 0.55,
}
COAT_L = (v3((0.20, -0.05, 1.14)), v3((0.25, -0.07, 0.56)))
COAT_B = (v3((0.0, 0.17, 1.14)), v3((0.0, 0.25, 0.56)))


def rig_bones():
    from kit.rig import Bone, mirror
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.015, 1.04), (0, 0.015, 1.22), "root", 0.16),
        Bone("spine", (0, 0.015, 1.22), (0, 0.01, 1.42), "hips", 0.15),
        Bone("chest", (0, 0.01, 1.42), (0, 0.04, 1.66), "spine", 0.18),
        Bone("neck", (0, 0.045, 1.62), (0, 0.035, 1.72), "chest", 0.1),
        Bone("head", (0, 0.035, 1.72), (0, -0.03, 1.92), "neck", 0.06),
        Bone("shoulder.L", (0.07, 0.03, 1.62), SHOULDER, "chest", 0.08),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.09),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.075),
        Bone("hand.L", WRIST, POCKET, "forearm.L", 0.05),
        Bone("coat.L", COAT_L[0], COAT_L[1], "hips", 0.04),
        Bone("coat.B", COAT_B[0], COAT_B[1], "hips", 0.04),
        Bone("thigh.L", HIP, KNEE, "hips", 0.1),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.08),
        Bone("foot.L", ANKLE, (0.14, -0.20, 0.05), "shin.L", 0.06),
    ])


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for vertices that move rigidly). piece: 0 head, 1 crest, 2 body, 3 jewels"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    fl = FLIP.diagonal()

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    L, Rt = x > 0, x <= 0
    # the head rides its bone above the jaw; under it, it settles into his chest
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 1.70)] = ix["head"]
    cp = piece == 1
    allow(cp, "head")
    rig[cp] = ix["head"]
    bp = piece == 2
    # arms (the hand in the pocket goes with the hand bone, which the clips keep in the pocket)
    arm = bp & (part == ARM)
    allow(arm & L, "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(arm & Rt, "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(arm & (z > 1.5) & (np.abs(x) < 0.34), "chest")
    cuff = bp & (part == CUFF) & (z > 0.6)
    allow(cuff & L, "forearm.L", "hand.L")
    allow(cuff & Rt, "forearm.R", "hand.R")
    # legs and boots
    jeans = bp & (part == JEANS)
    allow(jeans & (z > 0.85), "hips")
    allow(jeans & (x > -0.05), "thigh.L", "shin.L")
    allow(jeans & (x < 0.05), "thigh.R", "shin.R")
    boots = bp & (np.isin(part, (BOOT, SOLE)) | ((part == CUFF) & (z <= 0.6)))
    allow(boots & L, "shin.L", "foot.L")
    allow(boots & Rt, "shin.R", "foot.R")
    legs = jeans | boots
    # the coat: the body with the chest, the skirt on its three tails
    coat = bp & np.isin(part, (COAT, LINING))
    skirt = coat & (z < 1.12)
    upper = coat & ~skirt
    allow(upper, "spine", "chest")
    allow(upper & (z > 1.62), "neck")
    allow(upper & L & (x > 0.15) & (z > 1.45), "shoulder.L")
    allow(upper & Rt & (x < -0.15) & (z > 1.45), "shoulder.R")
    allow(upper & L & (x > 0.26) & (z > 1.55), "upper_arm.L")         # the caps over the deltoids
    allow(upper & Rt & (x < -0.26) & (z > 1.55), "upper_arm.R")
    allow(upper & (z < 1.3), "hips")
    phi = np.degrees(np.arctan2(x, -(y - 0.03)))
    allow(skirt, "hips")
    allow(skirt & (phi > 10), "coat.L")
    allow(skirt & (phi < -10), "coat.R")
    allow(skirt & (np.abs(phi) > 100), "coat.B")
    torso = bp & ~arm & ~cuff & ~legs & ~coat
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.18) & (z > 1.5), "shoulder.L")
    allow(torso & (x < -0.18) & (z > 1.5), "shoulder.R")
    # jewellery
    jp = piece == 3
    near_w = np.minimum(np.linalg.norm(P - WRIST, axis=1), np.linalg.norm(P - WRIST * fl, axis=1)) < 0.12
    allow(jp & near_w & L, "forearm.L")
    rig[jp & near_w & L] = ix["forearm.L"]
    allow(jp & near_w & Rt, "forearm.R")
    rig[jp & near_w & Rt] = ix["forearm.R"]
    boots = jp & ~near_w & (z < 0.45)
    allow(boots & L, "shin.L", "foot.L")
    allow(boots & Rt, "shin.R", "foot.R")
    wallet = jp & ~near_w & (z >= 0.45) & (z < 1.26) & (x < -0.09)
    allow(wallet, "hips", "thigh.R")
    buck = jp & ~near_w & ~boots & ~wallet & (z < 1.26)
    allow(buck, "hips")
    rig[buck] = ix["hips"]
    rest = jp & ~near_w & ~boots & ~wallet & ~buck
    allow(rest, "chest")
    rig[rest] = ix["chest"]
    return A, rig


WALK = dict(stride=1.1, stance=0.62, foot_x=0.145, lift=0.07, bob=0.024, drop=0.05, sway=0.045, roll=7.0, yaw=10.0, counter=1.7,
            lean=-2.0, toe_off=16.0, toe_out=12.0, swing_point=8.0)
RUN = dict(stride=1.7, stance=0.42, foot_x=0.15, lift=0.13, bob=0.036, drop=0.075, sway=0.035, roll=6.0, yaw=12.0, counter=1.6,
           lean=8.0, toe_off=24.0, toe_out=10.0, swing_point=14.0, spine_lean=3.0)


def motions(rig):
    """his clips: walk (a slouchy swagger: hands kept in his pockets, shoulders rolling hard against the hips, a sway, the head bobbing a beat late, the
    coat's tails swinging), run (the same hands-in-pockets lumber, sped up, coat flapping), idle (rocking on his heels, a big shrug, looking about)"""
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    hh = Vector((0.0, 0.015, 1.04))
    sh, el, wr = Vector(SHOULDER.tolist()), Vector(ELBOW.tolist()), Vector(WRIST.tolist())
    line = (wr - sh).normalized()
    pole_rest = ((el - sh) - line * (el - sh).dot(line)).normalized()

    def pockets(p, shrug=0.0):
        """the hands kept in the pockets: each wrist where the posed hips carry its pocket, the elbow out the way it rests, the hand turned with the hips"""
        Rh = p.delta.get("hips", Matrix.Identity(3))
        for side, s in (("L", 1.0), ("R", -1.0)):
            w = Vector((s * wr.x, wr.y, wr.z))
            tgt = p.offset + hh + Rh @ (w - hh)
            pole = Vector((s * pole_rest.x, pole_rest.y, pole_rest.z + shrug))
            p.ik["upper_arm." + side] = (tgt, pole, "hand." + side, Rh.copy())

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        c, s1 = math.cos(TAU * u), math.sin(TAU * u)
        # shoulders: the leading one dips and rolls forward, the other rides up
        p.rot("shoulder.L", 0, 4.0 * c, 0)
        p.rot("shoulder.R", 0, 4.0 * c, 0)
        p.rot("chest", -3.0 if not run else 4.0, 0, 0)
        pockets(p)
        p.rot("neck", (6.0 if run else 2.0) + 3.0 * math.sin(2 * TAU * u - 1.3), 0, 0)
        p.world["head"] = R((4.0 if run else -3.0) + 3.0 * math.sin(2 * TAU * u - 1.9), 0, 6.0 * math.sin(TAU * u - 0.5))
        A = 22.0 if run else 9.0
        p.rot("coat.L", -A * math.cos(TAU * u - 0.7), 0, 0)
        p.rot("coat.R", A * math.cos(TAU * u - 0.7), 0, 0)
        p.rot("coat.B", (16.0 if run else 4.0) + (8.0 if run else 4.0) * math.sin(2 * TAU * u - 1.4), -3.0 * s1, 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        rock = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.17, -0.10, 0.0)), 14.0), "R": (Vector((-0.16, -0.07, 0.0)), -16.0)},
              hip_shift=(0.02 * math.sin(TAU * t / 6.0), 0.012 * rock, -0.012 - 0.006 * rock), roll=-3.0 * math.sin(TAU * t / 6.0), yaw=4.0 * math.sin(TAU * t / 6.0))
        p.rot("spine", -2.0 - 1.5 * rock, 0, 0)
        p.rot("chest", 1.0 * math.sin(TAU * t / 3.0 + 0.5), 0, 2.0 * math.sin(TAU * t / 6.0))
        shr = ease((t - 2.0) / 0.35) * (1.0 - ease((t - 2.6) / 0.6))
        p.rot("shoulder.L", 0, -14.0 * shr, 0)
        p.rot("shoulder.R", 0, 14.0 * shr, 0)
        pockets(p, shrug=0.0)
        look = math.sin(TAU * t / 6.0 - 0.6)
        amp = 8.0 + 14.0 * ease((t - 3.2) / 0.8) * (1.0 - ease((t - 5.1) / 0.8))
        p.world["head"] = R(-4.0 + 3.0 * shr + 2.0 * math.sin(TAU * t / 3.0), 0, amp * look)
        p.rot("coat.B", 2.0 * math.sin(TAU * t / 3.0), 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
