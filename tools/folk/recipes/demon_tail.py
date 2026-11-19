## FOINT CITY townsfolk: the demon tail (working name; the user names him). A cocky red-pink goth, 1.85 m: a broad grinning head with two fangs and a spiky maroon crest, an eye on his throat; ribbed black tank, armbands, chains, black flares, chunky boots; a long pointed tail that swishes, a jacket slung over his right shoulder.
# Concept: the user's sheet 5.webp, bottom right (F:/prog-godot-cache/folk/refs/5.webp, box 790,380,1090,783). Measured off it (head top to soles 378 px, 4.9 mm a pixel):
# the head 0.22 m tall, 0.30 wide and long in the snout (eyes 1.785 at its top front corners, the grin and fangs 1.70, chin 1.64), the crest sweeping back
# from its crown to 1.93; a thin neck with a third eye on the throat (1.58) just over the tank's roll collar (1.555); big deltoids (1.48), chest 1.36,
# belt 1.13, crotch 0.98, knees 0.59, flares to 0.19 over boots with 5 cm heels. The tail leaves the small of his back and curls out to his left and down
# to a flat spade at knee height. His right hand holds the jacket's collar at his shoulder (the jacket hangs down his back and his right side); his left
# hand is in his pocket. Both arms are built in those poses (they are how he always walks), so the figure is not mirrored above the hips.
import math
import os
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3, ridge_line)

HEIGHT = 1.85
REF = ("5.webp", (790, 380, 1090, 783))

SKIN, EYE, MOUTH, TOOTH, NAIL, CREST, TANK, TROUSERS, BELT, SILVER, BOOT, SOLE, BAND, JACKET, LINING, ARM, TAILP = range(1, 18)
COLOURS = {
    SKIN: ((0.68, 0.26, 0.24), 0.5, 0.0),
    ARM: ((0.68, 0.26, 0.24), 0.5, 0.0),
    TAILP: ((0.68, 0.26, 0.24), 0.5, 0.0),
    EYE: ((0.6, 0.72, 0.7), 0.15, 0.0),
    MOUTH: ((0.1, 0.02, 0.03), 0.6, 0.0),
    TOOTH: ((0.9, 0.86, 0.76), 0.3, 0.0),
    NAIL: ((0.1, 0.04, 0.04), 0.2, 0.0),
    CREST: ((0.22, 0.07, 0.08), 0.45, 0.0),
    TANK: ((0.03, 0.025, 0.03), 0.75, 0.0),
    TROUSERS: ((0.04, 0.03, 0.035), 0.7, 0.0),
    BELT: ((0.10, 0.06, 0.04), 0.4, 0.0),
    SILVER: ((0.78, 0.78, 0.80), 0.25, 1.0),
    BOOT: ((0.04, 0.03, 0.03), 0.25, 0.0),
    SOLE: ((0.02, 0.02, 0.02), 0.5, 0.0),
    BAND: ((0.03, 0.025, 0.03), 0.35, 0.0),
    JACKET: ((0.28, 0.06, 0.10), 0.7, 0.0),
    LINING: ((0.12, 0.03, 0.05), 0.6, 0.0),
}

# landmarks (his left is +X; the figure faces -Y). The arms are not mirrored: the right holds the jacket at his shoulder, the left is in his pocket.
SH_L = v3((0.215, 0.02, 1.455))
EL_L = v3((0.325, 0.07, 1.20))
WR_L = v3((0.205, -0.07, 1.055))            # at the mouth of his left front pocket
SH_R = v3((-0.215, 0.02, 1.455))
EL_R = v3((-0.29, -0.085, 1.19))
WR_R = v3((-0.235, -0.115, 1.425))          # the fist holding the jacket's collar over his shoulder
HIP = v3((0.10, 0.015, 1.04))
KNEE = v3((0.115, -0.01, 0.59))
ANKLE = v3((0.125, 0.03, 0.13))
BALL = v3((0.13, -0.085, 0.0))
TAIL = [(v3((0.0, 0.11, 1.03)), 0.036), (v3((0.08, 0.22, 0.96)), 0.032), (v3((0.22, 0.27, 0.86)), 0.027), (v3((0.36, 0.22, 0.74)), 0.022),
        (v3((0.43, 0.13, 0.62)), 0.017), (v3((0.44, 0.06, 0.53)), 0.013)]
NECK_TOP = v3((0.0, 0.03, 1.66))
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
    """a broad flat-topped head drawn forward into a wide snout, heavy brows over the eyes at its top front corners, a narrower jaw tapering into a thin neck"""
    cran = Box((0, -0.03, 1.79), (0.118, 0.13, 0.055), rr=0.05)
    snout = Ellipsoid((0, -0.16, 1.732), (0.10, 0.125, 0.062))          # round 2: the snout drawn longer, as in the concept
    jaw = Ellipsoid((0, -0.12, 1.672), (0.082, 0.105, 0.042))
    back = Ellipsoid((0, 0.04, 1.74), (0.10, 0.09, 0.08))
    brows = Mirror(Ellipsoid((0.072, -0.12, 1.812), (0.052, 0.05, 0.022), R=rot(ry=-12)))
    neck = loft([(v3((0, 0.04, 1.48)), 0.052), (v3((0, 0.035, 1.60)), 0.046), (NECK_TOP, 0.05)])
    head = Union([cran, snout, jaw, back], k=0.05)
    head = Union([head, brows], k=0.02)
    return Union([head, neck], k=0.05, part=SKIN)


HEAD0 = head_base()


class Eye:
    def __init__(self, c, f, r, lid, slant, low):
        self.c, self.f, self.r = c, f, r
        up = v3((0, 0, 1)) - f * float(f[2])
        self.up = up / np.linalg.norm(up)
        out = np.cross(self.up, f)
        self.out = out / np.linalg.norm(out)
        self.lid_pt = c + self.up * (lid * r)
        n = -self.up + self.out * slant
        self.lid_n = n / np.linalg.norm(n)
        self.low = low


def _eye(o, d, r, lid, slant, low, sink=0.45):
    d = v3(d) / np.linalg.norm(d)
    p, n = hit(HEAD0, v3(o) + d * 0.4, -d)
    f = n * 0.5 + d * 0.5
    f /= np.linalg.norm(f)
    return Eye(p - f * (r * sink), f, r, lid, slant, low)


EYE_L = _eye((0.07, -0.08, 1.785), (0.45, -1.0, 0.1), 0.031, 0.12, 0.25, 0.6)
EYE_T = _eye((0.0, 0.03, 1.59), (0.0, -1.0, 0.0), 0.029, 0.25, 0.0, 0.5)          # the eye on his throat
MOUTH_Z = 1.698


def grin(dz, inset, half=0.095, n=15):
    """across the snout at mouth height: a wide grin, the corners pulled up and back"""
    pts = []
    for xx in np.linspace(-half, half, n):
        t = xx / half
        p, nn = hit(HEAD0, (xx, -0.5, MOUTH_Z + dz + 0.016 * abs(t) ** 2.2), (0, 1, 0))
        pts.append((p - nn * inset, t))
    return pts


def head():
    face = HEAD0
    parts = []
    for e, mir in ((EYE_L, True), (EYE_T, False)):
        lid = Clip(Sphere(e.c, e.r + 0.0055, part=SKIN), [Half(e.lid_pt, e.lid_n)], k=0.003)
        lower = Clip(Sphere(e.c, e.r + 0.0045, part=SKIN), [Half(e.c - e.up * (e.r * e.low), e.up)], k=0.003)
        rim = Union([lid, lower])
        ball = Sphere(e.c, e.r, part=EYE)
        parts.append((Mirror(rim) if mir else rim, Mirror(ball) if mir else ball))
    face = Union([face] + [r for r, b in parts], k=0.007)
    nostrils = Mirror(Ellipsoid((0.024, -0.278, 1.75), (0.006, 0.009, 0.0045), R=rot(rx=30)))
    groove = loft([(p, 0.004 + 0.008 * (1 - t * t)) for p, t in grin(0.0, 0.002)], k=0.004)
    face = Cut(face, [nostrils, groove], k=0.002)
    inner = loft([(p, 0.003 + 0.006 * (1 - t * t)) for p, t in grin(0.0, 0.012)], part=MOUTH, k=0.003)
    teeth = []
    for p, t in grin(0.0, 0.006, half=0.07, n=9)[1:-1]:
        teeth.append(Box(p + v3((0, 0, 0.004)), (0.0065, 0.004, 0.0045), rr=0.002, part=TOOTH))
    fangs = []
    for p, t in (grin(0.0, 0.004, half=0.064, n=2)):
        fangs.append(RoundCone(p + v3((0, -0.004, 0.006)), p + v3((0, -0.009, -0.03)), 0.0068, 0.0012, part=TOOTH))
    return Union([face, inner] + [b for r, b in parts] + teeth + fangs, k=0.0)


def crest():
    """the crest: maroon spines rooted along his crown and down the back of his head, swept back and out, the lower ones falling to his nape"""
    spines = []
    spec = [(-0.07, 0.0, 55, 0.20, 0.05), (-0.03, 0.03, 42, 0.24, 0.05), (-0.03, -0.03, 42, 0.24, 0.05), (0.01, 0.0, 30, 0.28, 0.055),
            (0.04, 0.045, 18, 0.27, 0.05), (0.04, -0.045, 18, 0.27, 0.05), (0.07, 0.0, 6, 0.26, 0.05), (0.09, 0.05, -10, 0.22, 0.045),
            (0.09, -0.05, -10, 0.22, 0.045), (0.11, 0.0, -24, 0.2, 0.045)]
    for y, x, ang, L, W in spec:
        p, n = hit(HEAD0, (x, y, 2.1), (0, 0, -1)) if y < 0.07 else hit(HEAD0, (x, 0.5, 1.80 - (y - 0.07) * 2.0), (0, -1, 0))
        root = p - n * 0.012
        a = math.radians(ang)
        eu = v3((x * 3.0, math.cos(a), math.sin(a)))
        eu /= np.linalg.norm(eu)
        en = np.cross(eu, v3((0, 0, 1)))
        en /= np.linalg.norm(en)
        ev = np.cross(en, eu)
        R = np.stack([eu, ev, en], 1).astype(np.float32)
        bend = 0.12
        poly = [(0.0, W * 0.5), (L * 0.5, W * 0.32 - bend * L * 0.1), (L, -bend * L), (L * 0.5, -W * 0.3 - bend * L * 0.1), (0.0, -W * 0.5)]
        blade = Slab(root, poly, 0.007, rr=0.004, R=R, part=CREST)
        rib = RoundCone(root, root + eu * L * 0.85 - ev * bend * L * 0.6, 0.011, 0.002, part=CREST)
        spines.append(Union([blade, rib], k=0.005))
    return Union(spines, k=0.004)


# ---------------------------------------------------------------------------------------------------- the body

def torso_core():
    return Union([
        Ellipsoid((0, 0.03, 1.47), (0.20, 0.09, 0.06)),
        Ellipsoid((0, 0.01, 1.36), (0.185, 0.115, 0.135)),
        Mirror(Ellipsoid((0.08, -0.065, 1.39), (0.09, 0.06, 0.07))),
        Ellipsoid((0, 0.01, 1.19), (0.145, 0.10, 0.10)),
        Ellipsoid((0, 0.015, 1.06), (0.16, 0.11, 0.09)),
    ], k=0.06, part=TANK)


def _orth(v, axis):
    v = v3(v) - axis * float(v3(v) @ axis)
    return v / np.linalg.norm(v)


def arm(S, E, W):
    """a bare, heavy arm in angular planes (round 2: the ellipsoid chain read as lumpy tubes): a capped deltoid, a biceps peak in front and a
    triceps behind, a clear bony elbow, a forearm wedge swelling below the elbow and tapering to the wrist"""
    s = float(np.sign(S[0]))
    Lu, Lf = float(np.linalg.norm(E - S)), float(np.linalg.norm(W - E))
    ua, fa = (E - S) / Lu, (W - E) / Lf
    Ru = basis(ua, _orth((0, -1, 0), ua))           # local z down the upper arm, y to its front
    Rf = basis(fa, _orth((0, -1, 0), fa))
    out = _orth((s, 0, 0), ua)
    delt = Gem(S + ua * 0.035 + out * 0.022 + v3((0, 0, 0.012)), (0.068, 0.068, 0.072, 0.074, 0.06, 0.11), soft=0.45, edge=0.012, R=Ru, part=ARM)
    core = RoundCone(S, E, 0.058, 0.041, part=ARM)
    bic = Gem(S + ua * (0.47 * Lu) + Ru[:, 1] * 0.02, (0.05, 0.05, 0.04, 0.058, 0.11, 0.1), soft=0.45, edge=0.01, R=Ru, part=ARM)
    tri = Gem(S + ua * (0.42 * Lu) - Ru[:, 1] * 0.022, (0.046, 0.046, 0.052, 0.03, 0.12, 0.12), soft=0.45, edge=0.01, R=Ru, part=ARM)
    elbow = Sphere(E - Rf[:, 1] * 0.012, 0.042, part=ARM)
    fore = Gem(E + fa * 0.085, (0.05, 0.05, 0.05, 0.054, 0.07, Lf * 0.85), soft=0.45, edge=0.01, R=Rf, part=ARM)
    wrist = RoundCone(E + fa * 0.1, W, 0.043, 0.032, part=ARM)
    band = CappedCone(S + (E - S) * 0.58, S + (E - S) * 0.74, 0.07, 0.066, rr=0.005, part=BAND)
    upper = Union([core, delt, bic, tri], k=0.014)
    return Union([upper, elbow, fore, wrist], k=0.012), band


def fist():
    """a closed fist in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y), knuckles rounded"""
    palm = Box((0.0, 0.0, -0.05), (0.022, 0.042, 0.04), rr=0.02, part=ARM)
    fingers = Box((-0.018, 0.0, -0.085), (0.024, 0.04, 0.022), rr=0.017, part=ARM)
    knuck = [Sphere((0.006, fy, -0.088), 0.0125, part=ARM) for fy in (-0.028, -0.009, 0.01, 0.028)]
    thumb = loft([(v3((-0.006, -0.036, -0.03)), 0.013), (v3((-0.03, -0.034, -0.06)), 0.011), (v3((-0.04, -0.02, -0.078)), 0.01)], part=ARM, k=0.004)
    return Union([palm, fingers, thumb] + knuck, k=0.012)


def jacket():
    """the jacket slung over his right shoulder: its collar gathered under his fist, the body of it hanging down his back and the outside of his arm in heavy folds"""
    S = SH_R
    drape = RoundCone(S + v3((0.0, 0.03, 0.06)), v3((-0.30, 0.07, 0.86)), 0.10, 0.17)
    shell = Inflate(drape, 0.008)          # solid: as a thin shell it came out riddled with holes, which the decimator cannot reduce
    shell = Clip(shell, [Half((-0.10, 0, 0), (1, 0, 0)), Half((0, -0.03, 0), (0, -1, 0)), Half((0, 0, 1.55), (0, 0, 1))], k=0.01)

    def folds(P):
        # heavy hanging folds running down from the shoulder, deeper toward the hem, and a turned-back lapel band near the top (round 2: "a smooth sack")
        z = P[:, 2]
        hang = np.sin(P[:, 0] * 48.0 + P[:, 1] * 30.0 + np.sin(z * 9.0) * 1.2) * (0.45 + 0.55 * np.clip((1.45 - z) / 0.5, 0, 1))
        lapel = np.exp(-((z - 1.38) / 0.025) ** 2)
        return hang + 0.8 * lapel
    shell = Bump(shell, folds, 0.016)
    collar = RoundCone(S + v3((0.05, 0.02, 0.07)), S + v3((-0.06, 0.02, 0.06)), 0.035, 0.04)
    return Union([Inflate(shell, 0.0, part=JACKET), Inflate(collar, 0.0, part=JACKET)], k=0.02)


def legs():
    hips = Ellipsoid((0, 0.015, 1.06), (0.165, 0.115, 0.10), part=TROUSERS)
    leg = loft([(HIP, 0.095), (v3((0.11, 0.0, 0.82)), 0.08), (KNEE, 0.062), (v3((0.12, 0.01, 0.40)), 0.075), (v3((0.125, 0.02, 0.19)), 0.105)], part=TROUSERS, k=0.03)
    leg = Clip(leg, [Half((0, 0, 0.19), (0, -0.15, -1))], k=0.004)
    return Clip(Union([hips, Mirror(leg)], k=0.04), [Half((0, 0, 1.135), (0, 0, 1))], k=0.003)


def boot():
    shaft = RoundCone(ANKLE + v3((0, 0.005, 0.1)), ANKLE, 0.06, 0.055, part=BOOT)
    foot = Box((0.128, -0.045, 0.075), (0.058, 0.125, 0.045), rr=0.035, part=BOOT)
    sole = Box((0.128, -0.06, 0.016), (0.064, 0.14, 0.016), rr=0.006, part=SOLE)
    heel = Box((0.128, 0.05, 0.03), (0.05, 0.04, 0.03), rr=0.005, part=SOLE)
    return Union([Union([shaft, foot], k=0.03), sole, heel], k=0.004)


def tail():
    """the tail: a ringed tube tapering out of the small of his back, ending in a flat diamond spade"""
    t = loft([(p, r) for p, r in TAIL], part=TAILP, k=0.02)
    ax = TAIL[-1][0] - TAIL[-2][0]
    ax /= np.linalg.norm(ax)
    spade = Gem(TAIL[-1][0] + ax * 0.07, (0.062, 0.062, 0.013, 0.013, 0.09, 0.075), soft=0.15, edge=0.003, R=basis(ax, v3((0, -1, 0))), part=TAILP)
    return Union([t, spade], k=0.012)


# The kit decimates every piece with X symmetry. His first build came out in shards; the culprits were a thin jacket shell full of holes (genus ~340)
# and touching chain links, not the lopsided arms (the naga's lopsided tail decimates fine). So the arms are back in the body, filleted into the
# shoulders, while the jacket (now solid) and the tail are their own pieces and the chains are solid links.

def body():
    """torso, tank, both posed arms filleted into the shoulders, legs, belt, boots"""
    core = torso_core()
    tank = Clip(Inflate(core, 0.006, part=TANK), [Half((0, 0, 1.10), (0, 0, -1))], k=0.003)
    tank = Cut(tank, [Mirror(Ellipsoid((0.23, 0.02, 1.47), (0.085, 0.12, 0.10)))], k=0.01)
    roll = CappedCone((0, 0.04, 1.50), (0, 0.04, 1.565), 0.066, 0.058, rr=0.012, part=TANK)
    belt = Clip(Inflate(Ellipsoid((0, 0.015, 1.10), (0.16, 0.11, 0.06)), 0.012, part=BELT), [Half((0, 0, 1.11), (0, 0, -1)), Half((0, 0, 1.145), (0, 0, 1))], k=0.002)
    aL, bL = arm(SH_L, EL_L, WR_L)
    aR, bR = arm(SH_R, EL_R, WR_R)
    hand_l = Ellipsoid(WR_L + v3((-0.035, 0.005, -0.045)), (0.04, 0.035, 0.05), part=ARM)
    dR = (WR_R - EL_R) / np.linalg.norm(WR_R - EL_R)
    hand_r = place(fist(), WR_R, basis(-dR, v3((1, 0, 0))))
    skin = Union([Inflate(core, 0.0, part=SKIN), aL, aR], k=0.03)
    return Union([skin, Union([hand_l, aL], k=0.015), Union([hand_r, aR], k=0.012), tank, roll, bL, bR, legs(), belt, Mirror(boot())], k=0.0)


def arm_left():
    """his left arm, the hand pushed into his pocket"""
    a, b = arm(SH_L, EL_L, WR_L)
    hand = Ellipsoid(WR_L + v3((-0.035, 0.005, -0.045)), (0.04, 0.035, 0.05), part=ARM)
    return Clip(Union([Union([a, hand], k=0.015), b], k=0.0), [Half((0.06, 0, 0), (-1, 0, 0))], k=0.005)


def arm_right():
    """his right arm, the fist holding the jacket's collar at his shoulder (the jacket is its own piece: the arm runs through it)"""
    a, b = arm(SH_R, EL_R, WR_R)
    dR = (WR_R - EL_R) / np.linalg.norm(WR_R - EL_R)
    hand = place(fist(), WR_R, basis(-dR, v3((1, 0, 0))))
    return Clip(Union([Union([a, hand], k=0.012), b], k=0.0), [Half((-0.06, 0, 0), (1, 0, 0))], k=0.005)


# ---------------------------------------------------------------------------------------------------- chains and studs

def chain(pts, R=0.012, r=0.0038, part=SILVER):
    out = []
    P = [v3(p) for p in pts]
    L = [0.0]
    for i in range(1, len(P)):
        L.append(L[-1] + float(np.linalg.norm(P[i] - P[i - 1])))
    s, k = 0.0, 0
    while s <= L[-1]:
        i = min(max(1, int(np.searchsorted(L, s))), len(P) - 1)
        t = (s - L[i - 1]) / max(L[i] - L[i - 1], 1e-6)
        c = P[i - 1] + (P[i] - P[i - 1]) * t
        d = (P[i] - P[i - 1]) / max(np.linalg.norm(P[i] - P[i - 1]), 1e-6)
        side = np.cross(d, v3((0, 0, 1)))
        side = side / np.linalg.norm(side) if np.linalg.norm(side) > 1e-3 else v3((1, 0, 0))
        n = np.cross(d, side) if k % 2 else side
        M = basis(n, d)
        # solid oval links (no holes): open links that touch make a mesh of hundreds of handles, which the decimator cannot bring down
        out.append(Ellipsoid(c, (R * 0.55, R * 0.95, r * 1.1), R=M, part=part))
        s += R * 1.55
        k += 1
    return out


def jewels():
    out = []
    core = Inflate(torso_core(), 0.006)
    pts = []
    for t in np.linspace(0.0, 1.0, 9):
        xx = 0.08 * (1.0 - t) ** 1.1
        p, n = hit(core, (xx, -0.5, 1.53 - 0.12 * t ** 1.4), (0, 1, 0))
        pts.append(p + n * 0.004)
    out += chain([p * FLIP.diagonal() for p in pts[::-1]] + pts[1:], R=0.009, r=0.0028)
    end = pts[-1]
    Rf = np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32)
    c = end + v3((0, -0.006, -0.03))
    out.append(Cut(Slab(c, [(0, 0.028), (0.016, 0), (0, -0.028), (-0.016, 0)], 0.003, rr=0.001, R=Rf, part=SILVER), [Slab(c, [(0, 0.02), (0.009, 0), (0, -0.02), (-0.009, 0)], 0.006, R=Rf)]))
    p, n = hit(Inflate(Ellipsoid((0, 0.015, 1.10), (0.16, 0.11, 0.06)), 0.012), (0.0, -0.5, 1.128), (0, 1, 0))
    out.append(Cut(Box(p + n * 0.003, (0.03, 0.004, 0.02), rr=0.002, part=SILVER), [Box(p + n * 0.003, (0.024, 0.01, 0.014))]))
    # diamond earrings at the back corners of the jaw
    p, n = hit(HEAD0, (0.10, -0.02, 1.4), (0, 0, 1))
    c = p + v3((0, 0, -0.045))
    ear = Union([Torus(p + v3((0, 0, -0.006)), 0.005, 0.0018, Rm=rot(ry=90), part=SILVER),
                 Cut(Slab(c, [(0, 0.035), (0.017, 0), (0, -0.035), (-0.017, 0)], 0.0025, rr=0.001, R=Rf, part=SILVER), [Slab(c, [(0, 0.027), (0.01, 0), (0, -0.027), (-0.01, 0)], 0.006, R=Rf)])], k=0.001)
    out.append(Mirror(ear))
    return Union(out, k=0.0)


def band_buckle(S, E):
    c = S + (E - S) * 0.635
    d = (E - S) / np.linalg.norm(E - S)
    outv = np.cross(d, v3((0, 1, 0)))
    outv = outv / np.linalg.norm(outv) * np.sign(S[0])
    cc = c + outv * 0.074
    return Cut(Box(cc, (0.014, 0.003, 0.013), rr=0.0015, R=basis(d, outv), part=SILVER), [Box(cc, (0.009, 0.008, 0.008), R=basis(d, outv))])


def jewels_left():
    """on his left only: the wallet chains' two loops from his left front belt loop, his left armband's buckle"""
    out = []
    for drop in (0.10, 0.17):
        out += chain([v3((0.06, -0.12, 1.12)), v3((0.08, -0.125, 1.12 - drop * 0.6)), v3((0.12, -0.11, 1.12 - drop)), v3((0.16, -0.08, 1.12 - drop * 0.7)), v3((0.17, -0.06, 1.11))], R=0.008, r=0.0024)
    out.append(band_buckle(SH_L, EL_L))
    return Union(out, k=0.0)


def jewels_right():
    return band_buckle(SH_R, EL_R)


def pieces():
    only = os.environ.get("FOLK_ONLY", "")
    out = [("head", head, 0.0018), ("crest", crest, 0.0026), ("body", body, 0.0036), ("jacket", jacket, 0.0036),
           ("tail", tail, 0.0026), ("jewels", jewels, 0.0015), ("jewels_l", jewels_left, 0.0015), ("jewels_r", jewels_right, 0.0015)]
    return [(n, f(), h) for n, f, h in out if not only or n in only.split(",")]


# ---------------------------------------------------------------------------------------------------- paint

def facets(P, size=0.03, seed=11):
    """a random 0..1 per point from jittered 3D cells: the faceted, low-poly read of his skin in the concept"""
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
                pt = c + np.stack([((h >> 3) & 1023) / 1023.0, ((h >> 13) & 1023) / 1023.0, ((h >> 23) & 1023) / 1023.0], 1) * 0.8 + 0.1
                d = np.sum((q - pt) ** 2, 1)
                take = d < best
                best[take] = d[take]
                rnd[take] = (((h >> 33) & 1023) / 1023.0)[take]
    return rnd


def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.009) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def mix(a, b, t):
        return a + (b - a) * np.asarray(t, np.float32)[:, None]

    # skin: a red-pink broken into facets of coral and dusky rose, darker in the creases; rings round the tail
    m = c.mask(SKIN, ARM, TAILP)
    f = facets(P)
    sk = mix(np.broadcast_to(srgb(196, 92, 88), (len(P), 3)), srgb(224, 124, 112), f)
    sk = mix(sk, srgb(160, 66, 72), smooth(0.8, 0.95, facets(P, 0.05, 5)) * 0.6)
    sk *= (1.0 + 0.04 * mott)[:, None]
    tl = c.mask(TAILP)
    if tl.any():
        best = np.full(len(P), 1e9, np.float32)
        s_out = np.zeros(len(P), np.float32)
        s0 = 0.0
        for (a, _), (b, _) in zip(TAIL[:-1], TAIL[1:]):
            ab = b - a
            Lg = float(np.linalg.norm(ab))
            t = np.clip(((P - a) @ ab) / (Lg * Lg), 0, 1)
            d = np.linalg.norm(P - a - np.outer(t, ab), axis=1)
            take = d < best
            best[take] = d[take]
            s_out[take] = (s0 + t * Lg)[take]
            s0 += Lg
        fr = s_out / 0.035 - np.floor(s_out / 0.035)
        c.draw(tl & (s_out < s0 - 0.01), np.minimum(fr, 1 - fr) * 0.035, 0.0012, 0.55)
    # the eyes' lids: a dark heavy line, the throat eye's too
    for e, mir in ((EYE_L, True), (EYE_T, False)):
        PP = Q if mir else P
        de = PP - e.c
        r = np.linalg.norm(de, axis=1)
        pd = (PP - e.lid_pt) @ e.lid_n
        sk = mix(sk, srgb(150, 60, 66), ((r < e.r + 0.012) & (pd < 0)) * 0.6)
        c.draw((r < e.r + 0.012) & (pd > -0.008) & (pd < 0.004) & (de @ e.f > -0.01), np.abs(pd + 0.001), 0.0022)
        pl = (PP - (e.c - e.up * (e.r * e.low))) @ e.up
        c.draw((r < e.r + 0.01) & (np.abs(pl) < 0.005) & (de @ e.f > -0.006), np.abs(pl - 0.0008), 0.0011, 0.7)
    put(m, sk[m], 0.5, bump=0.25)
    # eyes: grey-green, a dark pupil looking ahead, a glint
    m = c.mask(EYE)
    ec = np.zeros((len(P), 3), np.float32)
    for e, cs in ((EYE_L, (EYE_L.c, EYE_L.c * FLIP.diagonal())), (EYE_T, (EYE_T.c,))):
        for cc in cs:
            dd = P - cc
            rad = np.linalg.norm(dd, axis=1)
            mine = m & (np.abs(rad - e.r) < 0.003)
            d = dd / np.maximum(rad, 1e-6)[:, None]
            g = v3((0, -1, 0))
            ang = np.arccos(np.clip(d @ g, -1, 1))
            col = mix(np.broadcast_to(srgb(150, 186, 176), (len(P), 3)), srgb(236, 230, 214), smooth(0.5, 0.6, ang))
            col *= (1.0 - 0.35 * smooth(0.0, 0.4, d @ e.up))[:, None]
            c.draw(mine, (ang - 0.2) * e.r, 0.0)
            gd = g + e.up * 0.4 + v3((0.15, 0, 0))
            gd /= np.linalg.norm(gd)
            col = mix(col, srgb(255, 255, 250), smooth(0.985, 0.993, d @ gd))
            ec[mine] = col[mine]
    put(m, ec[m], 0.06)
    put(c.mask(MOUTH), srgb(50, 12, 18), 0.6)
    m = c.mask(TOOTH)
    put(m, (srgb(236, 226, 200) * (1.0 - 0.3 * c.cavity)[:, None])[m], 0.25)
    m = c.mask(CREST)
    put(m, (mix(np.broadcast_to(srgb(88, 32, 40), (len(P), 3)), srgb(140, 66, 70), c.wear * 0.5))[m], 0.45, bump=0.3)
    # the ribbed black tank
    m = c.mask(TANK)
    put(m, (srgb(34, 30, 34) * (1.0 + 0.5 * c.wear)[:, None])[m], 0.8, bump=1.0)
    c.strp[m, 0] = (np.arctan2(P[:, 0], -(P[:, 1] - 0.01)) * 0.17 * 3.0)[m]
    c.strp[m, 1] = 0.75
    # trousers: black with a fine pinstripe; leather: belt, bands, boots
    m = c.mask(TROUSERS)
    put(m, (srgb(40, 32, 38) * (1.0 + 0.5 * c.wear + 0.05 * mott)[:, None])[m], 0.75, bump=0.9)
    kx = np.interp(z, [0.19, 0.59, 1.04], [0.125, 0.115, 0.10])
    c.strp[m, 0] = (np.arctan2(Q[:, 0] - kx, -y) * np.maximum(np.hypot(Q[:, 0] - kx, y), 0.03) * 1.4)[m]
    c.strp[m, 1] = -0.4
    for parts, base, rough in (((BELT,), (74, 46, 32), 0.4), ((BAND,), (26, 22, 26), 0.32), ((BOOT,), (44, 30, 30), 0.2)):
        m = c.mask(*parts)
        put(m, (srgb(*base) * (1.0 + 1.3 * c.wear)[:, None])[m], rough, bump=0.5, grain=1.0)
    put(c.mask(SOLE), srgb(22, 18, 18), 0.55, bump=0.4)
    # the jacket: a maroon plaid wool, a darker grid over it, worn on the folds
    m = c.mask(JACKET)
    # a tartan (round 2: the grid alone read as a plain sack): wide dark bands both ways over the maroon, darker where they cross, thin light
    # threads between, then the folds' light and shadow over it all
    u = (P[:, 0] + P[:, 1]) / 0.07
    w = z / 0.07
    bu = smooth(0.32, 0.26, np.abs(u - np.floor(u) - 0.5))
    bw = smooth(0.32, 0.26, np.abs(w - np.floor(w) - 0.5))
    jc = np.broadcast_to(srgb(134, 36, 56), (len(P), 3)).copy()
    jc = mix(jc, srgb(76, 18, 34), bu * 0.55)
    jc = mix(jc, srgb(76, 18, 34), bw * 0.55)
    jc = mix(jc, srgb(176, 92, 84), smooth(0.465, 0.49, np.abs((u + 0.25) - np.floor(u + 0.25) - 0.5)) * 0.5)
    jc = mix(jc, srgb(176, 92, 84), smooth(0.465, 0.49, np.abs((w + 0.25) - np.floor(w + 0.25) - 0.5)) * 0.5)
    jc *= (1.0 + 0.6 * c.wear - 0.45 * c.cavity + 0.05 * mott)[:, None]
    put(m, jc[m], 0.85, bump=1.0)
    m = c.mask(SILVER)
    put(m, (srgb(210, 208, 214) * (1.0 - 0.5 * c.cavity)[:, None])[m], 0.22, metal=1.0, bump=0.05, grain=1.0)
    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2200, "crest": 600, "body": 4600, "jacket": 1000, "tail": 450, "jewels": 500, "jewels_l": 300, "jewels_r": 60},
    "density": {"head": 1.7, "crest": 1.2, "jewels": 1.2},
    "tex": 2048,
    "stride": {"walk": 1.15, "run": 1.8},
    "speed": 1.0,
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.03, 1.66),
    "radius": 0.45,
}
TAIL_BONES = ["tail1", "tail2", "tail3", "tail4", "tail5"]
JACKET_A, JACKET_B = SH_R + v3((-0.03, 0.03, 0.06)), v3((-0.30, 0.07, 0.88))


def rig_bones():
    from kit.rig import Bone
    f = np.array([-1, 1, 1], np.float32)
    bones = [
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.015, 1.04), (0, 0.015, 1.20), "root", 0.15),
        Bone("spine", (0, 0.015, 1.20), (0, 0.012, 1.36), "hips", 0.12),
        Bone("chest", (0, 0.012, 1.36), (0, 0.03, 1.52), "spine", 0.15),
        Bone("neck", (0, 0.04, 1.52), NECK_TOP, "chest", 0.05),
        Bone("head", NECK_TOP, (0, -0.04, 1.86), "neck", 0.04),
        Bone("shoulder.L", (0.05, 0.025, 1.50), SH_L, "chest", 0.06),
        Bone("upper_arm.L", SH_L, EL_L, "shoulder.L", 0.065),
        Bone("forearm.L", EL_L, WR_L, "upper_arm.L", 0.05),
        Bone("hand.L", WR_L, WR_L + v3((-0.04, 0.0, -0.07)), "forearm.L", 0.04),
        Bone("shoulder.R", (-0.05, 0.025, 1.50), SH_R, "chest", 0.06),
        Bone("upper_arm.R", SH_R, EL_R, "shoulder.R", 0.065),
        Bone("forearm.R", EL_R, WR_R, "upper_arm.R", 0.05),
        Bone("hand.R", WR_R, WR_R + (WR_R - EL_R) / np.linalg.norm(WR_R - EL_R) * 0.09, "forearm.R", 0.04),
        Bone("jacket", JACKET_A, JACKET_B, "shoulder.R", 0.08),
        Bone("thigh.L", HIP, KNEE, "hips", 0.095),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.07),
        Bone("foot.L", ANKLE, (0.13, -0.17, 0.03), "shin.L", 0.05),
        Bone("thigh.R", HIP * f, KNEE * f, "hips", 0.095),
        Bone("shin.R", KNEE * f, ANKLE * f, "thigh.R", 0.07),
        Bone("foot.R", ANKLE * f, v3((0.13, -0.17, 0.03)) * f, "shin.R", 0.05),
    ]
    for k, nm in enumerate(TAIL_BONES):
        a, b = TAIL[k], TAIL[k + 1]
        bones.append(Bone(nm, a[0], b[0], "hips" if k == 0 else TAIL_BONES[k - 1], a[1]))
    return bones


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for vertices that move rigidly). piece: 0 head, 1 crest, 2 body (with both arms), 3 jacket, 4 tail, 5 jewels, 6 left jewels, 7 right buckle"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    L, Rt = x > 0, x <= 0

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True

    def seg(a, b):
        ab = b - a
        t = np.clip(((P - a) @ ab) / float(ab @ ab), 0, 1)
        return np.linalg.norm(P - a - np.outer(t, ab), axis=1)
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 1.655)] = ix["head"]
    allow(piece == 1, "head")
    rig[piece == 1] = ix["head"]
    bp = np.isin(piece, (2, 3, 4))             # body with the arms, jacket, tail
    tl = bp & (part == TAILP)
    D = np.stack([seg(TAIL[k][0], TAIL[k + 1][0]) for k in range(5)], 1)
    near = np.argmin(D, 1)
    for k, nm in enumerate(TAIL_BONES):
        allow(tl & (np.abs(near - k) <= 1), nm)
    allow(tl & (near == 0), "hips")
    rig[tl & (near == 4) & (seg(TAIL[4][0], TAIL[5][0]) > 0.0) & ((P - TAIL[4][0]) @ (TAIL[5][0] - TAIL[4][0]) > 0.0)] = ix["tail5"]
    dl = np.minimum(seg(SH_L, EL_L), seg(EL_L, WR_L))
    dr = np.minimum(seg(SH_R, EL_R), seg(EL_R, WR_R))
    armL = bp & ~tl & np.isin(part, (ARM, BAND)) & L & (dl < 0.11)
    armR = bp & ~tl & np.isin(part, (ARM, BAND)) & Rt & (dr < 0.13)
    allow(armL, "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(armR, "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow((armL | armR) & (z > 1.4) & (np.abs(x) < 0.3), "chest")
    jk = bp & (part == JACKET)
    allow(jk, "shoulder.R", "jacket")
    allow(jk & (z > 1.45), "upper_arm.R", "chest")
    rig[jk & (z < 1.25)] = ix["jacket"]
    legs = bp & np.isin(part, (TROUSERS,))
    allow(legs, "hips")
    allow(legs & (x > -0.04), "thigh.L", "shin.L")
    allow(legs & (x < 0.04), "thigh.R", "shin.R")
    boots = bp & np.isin(part, (BOOT, SOLE))
    allow(boots & L, "shin.L", "foot.L")
    allow(boots & Rt, "shin.R", "foot.R")
    torso = bp & ~tl & ~armL & ~armR & ~jk & ~legs & ~boots
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & L & (x > 0.12) & (z > 1.38), "shoulder.L")
    allow(torso & Rt & (x < -0.12) & (z > 1.38), "shoulder.R")
    jp = np.isin(piece, (5, 6, 7))
    ear = jp & (z > 1.6) & (np.abs(x) > 0.06)
    allow(ear, "head")
    rig[ear] = ix["head"]
    bandL = jp & ~ear & (seg(SH_L, EL_L) < 0.1) & L
    bandR = jp & ~ear & (seg(SH_R, EL_R) < 0.1) & Rt
    allow(bandL, "upper_arm.L")
    rig[bandL] = ix["upper_arm.L"]
    allow(bandR, "upper_arm.R")
    rig[bandR] = ix["upper_arm.R"]
    low = jp & ~ear & ~bandL & ~bandR & (z < 1.16)
    allow(low, "hips", "thigh.L")
    rest = jp & ~ear & ~bandL & ~bandR & ~low
    allow(rest, "chest")
    rig[rest] = ix["chest"]
    return A, rig


WALK = dict(stride=1.15, stance=0.6, foot_x=0.13, lift=0.065, bob=0.026, drop=0.045, sway=0.032, roll=7.0, yaw=9.0, counter=1.6,
            lean=-3.0, toe_off=20.0, toe_out=10.0, swing_point=8.0)
RUN = dict(stride=1.8, stance=0.4, foot_x=0.13, lift=0.14, bob=0.036, drop=0.08, sway=0.02, roll=5.0, yaw=11.0, counter=1.4,
           lean=9.0, toe_off=26.0, toe_out=8.0, swing_point=14.0, spine_lean=3.0)


def motions(rig):
    """his clips: walk (a cocky stroll: chin up, chest out, shoulders rolling hard, a bounce in it; the jacket kept on his shoulder swinging behind,
    his left hand in his pocket, the tail swishing in a lazy wave that runs to its tip), run (the same, faster, tail streaming), idle (hip-shot, the
    tail curling and flicking, a toss of the head, a shrug of the jacket)"""
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector, Matrix
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * np.array([-1, 1, 1], np.float32)).tolist(), "R")]
    hh = Vector((0.0, 0.015, 1.04))
    sh, el, wr = Vector(SH_L.tolist()), Vector(EL_L.tolist()), Vector(WR_L.tolist())
    line = (wr - sh).normalized()
    pole = ((el - sh) - line * (el - sh).dot(line)).normalized()

    def pocket(p):
        Rh = p.delta.get("hips", Matrix.Identity(3))
        p.ik["upper_arm.L"] = (p.offset + hh + Rh @ (wr - hh), pole, "hand.L", Rh.copy())

    def swish(p, u, amp, speed=1.0, curl=0.0):
        for k, nm in enumerate(TAIL_BONES):
            p.rot(nm, 0, (curl + 3.0 * math.sin(TAU * u * speed - k * 0.9)) * (0.5 + 0.2 * k), amp * (0.6 + 0.25 * k) * math.sin(TAU * u * speed - k * 0.8))

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.rot("chest", -4.0 if not run else 3.0, 0, 0)
        pocket(p)
        c = math.cos(TAU * u)
        p.rot("forearm.R", 3.0 * math.sin(2 * TAU * u - 1.0), 0, 0)
        p.rot("jacket", (14.0 if run else 4.0) + (8.0 if run else 5.0) * math.sin(2 * TAU * u - 1.5), 0, 4.0 * c)
        p.rot("neck", 2.0 * math.sin(2 * TAU * u - 1.2), 0, 0)
        p.world["head"] = R((2.0 if run else -6.0) + 2.5 * math.sin(2 * TAU * u - 1.8), 0, 6.0 * math.sin(TAU * u - 0.5))
        swish(p, u, 16.0 if run else 11.0, curl=-6.0 if run else 0.0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sw = math.sin(TAU * t / 6.0)
        stand(rig, p, legs, {"L": (Vector((0.15, -0.08, 0.0)), 12.0), "R": (Vector((-0.15, -0.02, 0.0)), -16.0)},
              hip_shift=(-0.03 + 0.008 * sw, 0.0, -0.015), roll=4.0, yaw=5.0)
        p.rot("spine", -2.0, -2.0, -3.0)
        p.rot("chest", 1.2 * math.sin(TAU * t / 3.0), 0, 0)
        pocket(p)
        toss = ease((t - 2.2) / 0.25) * (1.0 - ease((t - 2.7) / 0.6))
        shrug = ease((t - 4.0) / 0.3) * (1.0 - ease((t - 4.6) / 0.5))
        p.rot("shoulder.R", 0, 10.0 * shrug, 0)
        p.rot("jacket", 3.0 * math.sin(TAU * t / 3.0) - 6.0 * shrug, 0, 0)
        p.world["head"] = R(-5.0 - 10.0 * toss + 1.5 * math.sin(TAU * t / 3.0), -6.0 * toss, 10.0 * math.sin(TAU * t / 6.0 + 0.5))
        swish(p, t / 3.0, 9.0, curl=4.0)
        p.rot("tail5", 0, 0, 18.0 * math.sin(TAU * t * 1.5) * ease((t - 0.5) / 0.3) * (1.0 - ease((t - 1.4) / 0.3)))
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
