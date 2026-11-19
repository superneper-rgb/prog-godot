## FOINT CITY townsfolk: twohead. One extra-wide mustard suit, two heads, two opinions: the cheerful one (his left, in a knit beanie) and the sour one (his right, in a bowler and a monocle) bicker all day.
# Upgrade of the three.js game's twohead (folk-species-d.js; old render refs/old/twohead.png): same idea (one suit, two necks, beanie with a
# bobble vs bowler hat, smile vs frown), lifted to the new sheets (refs 4/6/7): one double-width jacket with two V-necks, two shirt collars
# and two ties (a loud red polka-dot one and a sober navy stripe), pointed alien ears, each head with a jaw that flaps when it talks.
# 1.85 m to the top of the hats. Rest pose: the heads turned a little toward each other, mid-argument.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 1.85
REF = ("old/twohead.png", None)

SKIN, EYE, LIP, MOUTH, TOOTH, BROW, SUIT, SHIRT, TIE_A, TIE_B, KNIT, BOBBLE, HAT, BAND, GOLD, GLASS, SHOE, SOLE, BUTTON, NAIL, TROUSERS = range(1, 22)
COLOURS = {
    SKIN: ((0.74, 0.46, 0.36), 0.55, 0.0),
    EYE: ((0.9, 0.88, 0.82), 0.2, 0.0),
    LIP: ((0.55, 0.25, 0.25), 0.4, 0.0),
    MOUTH: ((0.12, 0.02, 0.03), 0.6, 0.0),
    TOOTH: ((0.9, 0.86, 0.76), 0.3, 0.0),
    BROW: ((0.3, 0.2, 0.12), 0.8, 0.0),
    SUIT: ((0.62, 0.42, 0.1), 0.8, 0.0),
    SHIRT: ((0.88, 0.86, 0.8), 0.6, 0.0),
    TIE_A: ((0.6, 0.06, 0.06), 0.4, 0.0),
    TIE_B: ((0.06, 0.08, 0.22), 0.4, 0.0),
    KNIT: ((0.5, 0.18, 0.08), 0.9, 0.0),
    BOBBLE: ((0.85, 0.65, 0.15), 0.9, 0.0),
    HAT: ((0.03, 0.03, 0.03), 0.55, 0.0),
    BAND: ((0.12, 0.1, 0.1), 0.35, 0.0),
    GOLD: ((0.9, 0.66, 0.25), 0.3, 1.0),
    GLASS: ((0.6, 0.7, 0.75), 0.05, 0.0),
    SHOE: ((0.25, 0.12, 0.06), 0.35, 0.0),
    SOLE: ((0.1, 0.07, 0.05), 0.6, 0.0),
    BUTTON: ((0.3, 0.2, 0.1), 0.4, 0.0),
    NAIL: ((0.8, 0.6, 0.55), 0.3, 0.0),
    TROUSERS: ((0.55, 0.37, 0.09), 0.8, 0.0),
}
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
UP = v3((0, 0, 1))


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# landmarks, left side (+X); the figure faces -Y
HIP = v3((0.12, 0.01, 0.92))
KNEE = v3((0.125, -0.012, 0.50))
ANKLE = v3((0.13, 0.03, 0.095))
HEM = v3((0.13, 0.02, 0.12))
SHOULDER = v3((0.355, 0.012, 1.40))
ELBOW = v3((0.43, 0.035, 1.125))
WRIST = v3((0.455, 0.0, 0.885))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
XV = 0.165                                  # each V-neck's middle, either side
NECK_TOP = 1.53


HS = 1.12                                   # the heads are built life-size and set down this much bigger (stylised big heads)


class Head:
    """where one head sits: built about the origin in its own frame, set at t turned by R and scaled by HS"""
    def __init__(self, t, R):
        self.t, self.R = v3(t), np.asarray(R, np.float32)

    def w(self, p):
        return self.R @ v3(p) * HS + self.t

    def local(self, P):
        return ((P - self.t) @ self.R) / HS


HA = Head((0.175, -0.012, 1.628), rot(ry=-4) @ rot(rz=-13))       # the cheerful one, his left, turned toward the other
HB = Head((-0.175, -0.005, 1.618), rot(ry=3) @ rot(rz=11))        # the sour one, his right

# eyes in each head's own frame: (centre, radius, where it looks, lid plane point offset, lid plane normal)
EYE_A = (v3((0.043, -0.094, 0.032)), 0.026, unit((-0.32, -1.0, 0.06)))
EYE_B = (v3((0.04, -0.088, 0.028)), 0.023, unit((0.35, -1.0, -0.12)))
JAW_A = (v3((0.0, -0.02, -0.035)), v3((0.0, -0.105, -0.11)))     # hinge, chin
JAW_B = (v3((0.0, -0.02, -0.04)), v3((0.0, -0.10, -0.125)))


def eye_parts(ec, re, fwd, lid_drop, lower_rise=0.6):
    """an eyeball, its heavy upper lid (a shell above a plane that slopes with the brow) and a thin lower lid, for a head's left eye"""
    lid_n = unit(v3((0.0, 0.0, -1.0)) + fwd * 0.25)
    lid = Clip(Ellipsoid(ec + v3((0, -0.001, 0.001)), (re + 0.0055, re + 0.004, re + 0.005), part=SKIN), [Half(ec + v3((0, 0, re * lid_drop)), lid_n)], k=0.003)
    lower = Clip(Ellipsoid(ec, (re + 0.004, re + 0.003, re + 0.004), part=SKIN), [Half(ec - v3((0, 0, re * lower_rise)), (0, 0, 1))], k=0.003)
    ball = Sphere(ec, re, part=EYE)
    return Union([lid, lower], k=0.004), ball


def pointed_ear(root, s=1.0):
    """a leaf-shaped alien ear sweeping up and back from the side of the head (left side)"""
    u = unit((0.45, 0.75, 0.55))
    vv = unit(np.cross(u, v3((0, 1, 0))) * -1.0)
    n = np.cross(u, vv)
    R = np.stack([u, vv, n], 1)
    poly = [(0.0, -0.022), (0.035, -0.03), (0.075, -0.018), (0.105, 0.004), (0.06, 0.02), (0.02, 0.026), (0.0, 0.018)]
    plate = Slab(root, [(a * s, b * s) for a, b in poly], 0.009 * s, rr=0.006, R=R, part=SKIN)
    inner = Slab(root + n * 0.007 + u * 0.01, [(a * s * 0.8, b * s * 0.6) for a, b in poly], 0.006, rr=0.004, R=R, part=SKIN)
    return Cut(plate, [inner], k=0.004)


def head_a():
    """the cheerful one: a round head, apple cheeks, a big open grin, a bulb of a nose, brows up, a rust beanie with a bobble"""
    ec, re, fwd = EYE_A
    skull = Union([
        Ellipsoid((0, 0.012, 0.03), (0.112, 0.116, 0.122)),
        Ellipsoid((0, -0.022, -0.045), (0.103, 0.098, 0.085)),
        Mirror(Ellipsoid((0.054, -0.064, -0.028), (0.05, 0.046, 0.044))),
        Ellipsoid((0, -0.05, -0.098), (0.055, 0.05, 0.035)),
    ], k=0.035, part=SKIN)
    brow = Mirror(Ellipsoid((0.042, -0.095, 0.072), (0.04, 0.02, 0.014), R=rot(ry=-14), part=SKIN))
    lids, ball = eye_parts(ec, re, fwd, 0.36, 0.42)
    nose = Union([RoundCone((0, -0.104, 0.035), (0, -0.124, 0.002), 0.014, 0.02), Sphere((0, -0.13, -0.005), 0.027),
                  Mirror(Sphere((0.022, -0.118, -0.016), 0.016))], k=0.014, part=SKIN)
    ears = Mirror(pointed_ear(v3((0.105, 0.0, 0.0)), 1.0))
    face = Union([Union([skull, brow, Mirror(lids), ears], k=0.012), nose], k=0.01)
    # the grin: a wide crescent, corners up; lips rolled round it
    lo = Ellipsoid((0, -0.112, -0.064), (0.062, 0.06, 0.034))
    hi = Ellipsoid((0, -0.125, -0.032), (0.085, 0.07, 0.03))
    cav = Cut(lo, [hi], k=0.006)
    lips = Clip(Inflate(cav, 0.008, part=LIP), [Inflate(skull, 0.006)], k=0.003)
    face = Cut(Union([face, lips], k=0.004), [cav], k=0.003)
    throat = Ellipsoid((0, -0.07, -0.068), (0.06, 0.03, 0.035), part=MOUTH)
    teeth = Box((0, -0.098, -0.052), (0.045, 0.012, 0.009), rr=0.006, part=TOOTH)
    tongue = Ellipsoid((0, -0.09, -0.085), (0.035, 0.03, 0.012), part=LIP)
    brows = Mirror(loft([((0.014, -0.117, 0.086), 0.0065), ((0.038, -0.119, 0.091), 0.0075), ((0.066, -0.106, 0.077), 0.006)], part=BROW, k=0.004))
    # the beanie: a knit layer over the crown, a turned-up cuff, a bobble
    crown = Ellipsoid((0, 0.012, 0.03), (0.112, 0.116, 0.122))
    beanie = Clip(Inflate(crown, 0.012, part=KNIT), [Half((0, 0, 0.072), (0, -0.32, -1))], k=0.004)
    cuff = Clip(Inflate(crown, 0.022, part=KNIT), [Half((0, 0, 0.072), (0, -0.32, -1)), Half((0, 0, 0.112), (0, 0.32, 1))], k=0.006)
    peak = Ellipsoid((0.0, 0.02, 0.135), (0.07, 0.075, 0.04), part=KNIT)
    bobble = Sphere((0.008, 0.024, 0.19), 0.034, part=BOBBLE)
    hat = Union([Union([beanie, peak], k=0.03), cuff, bobble], k=0.0)
    return Union([face, Mirror(ball), throat, teeth, tongue, brows, hat], k=0.0)


def head_b():
    """the sour one: a longer face with jowls, a heavy brow, a hooked nose, a drooping grey moustache over a frown, a bowler, a monocle"""
    ec, re, fwd = EYE_B
    skull = Union([
        Ellipsoid((0, 0.012, 0.025), (0.103, 0.114, 0.128)),
        Ellipsoid((0, -0.018, -0.055), (0.094, 0.094, 0.092)),
        Mirror(Ellipsoid((0.066, -0.045, -0.092), (0.042, 0.048, 0.05))),
        Ellipsoid((0, -0.045, -0.118), (0.05, 0.05, 0.035)),
    ], k=0.035, part=SKIN)
    brow = Union([Ellipsoid((0, -0.088, 0.055), (0.088, 0.03, 0.02)), Mirror(Ellipsoid((0.045, -0.09, 0.05), (0.04, 0.026, 0.02), R=rot(ry=12)))], k=0.02, part=SKIN)
    lids, ball = eye_parts(ec, re, fwd, 0.05, 0.55)
    nose = loft([((0, -0.092, 0.042), 0.013), ((0, -0.135, 0.008), 0.019), ((0, -0.148, -0.018), 0.018), ((0, -0.132, -0.036), 0.013)], part=SKIN, k=0.012)
    nostrils = Mirror(Sphere((0.016, -0.124, -0.034), 0.012, part=SKIN))
    ears = Mirror(pointed_ear(v3((0.098, 0.004, -0.004)), 0.9))
    face = Union([Union([skull, brow, Mirror(lids), ears], k=0.012), nose, nostrils], k=0.01)
    # the frown: a slot that turns down at its corners
    lo = Ellipsoid((0, -0.104, -0.092), (0.048, 0.05, 0.022))
    hi = Ellipsoid((0, -0.112, -0.112), (0.065, 0.06, 0.022))
    cav = Cut(lo, [hi], k=0.005)
    lips = Clip(Inflate(cav, 0.007, part=LIP), [Inflate(skull, 0.005)], k=0.003)
    face = Cut(Union([face, lips], k=0.004), [cav], k=0.003)
    throat = Ellipsoid((0, -0.07, -0.09), (0.05, 0.03, 0.03), part=MOUTH)
    # bushy grey brows angled down to the middle, and the moustache
    brows = Mirror(loft([((0.012, -0.112, 0.056), 0.009), ((0.04, -0.112, 0.07), 0.011), ((0.07, -0.098, 0.072), 0.008)], part=BROW, k=0.006))
    mous = Mirror(loft([((0.0, -0.13, -0.05), 0.012), ((0.03, -0.122, -0.058), 0.013), ((0.055, -0.106, -0.08), 0.009), ((0.062, -0.098, -0.098), 0.0055)], part=BROW, k=0.008))
    # the bowler: a round crown, a band, a brim curled up at the sides
    crown = Clip(Ellipsoid((0, 0.012, 0.075), (0.112, 0.124, 0.105), part=HAT), [Half((0, 0, 0.052), (0, 0.15, -1))], k=0.003)
    band = Clip(Ellipsoid((0, 0.012, 0.075), (0.114, 0.126, 0.107), part=BAND), [Half((0, 0, 0.052), (0, 0.15, -1)), Half((0, 0, 0.075), (0, 0.15, 1))], k=0.002)
    brim = Clip(Ellipsoid((0, 0.012, 0.055), (0.158, 0.165, 0.02), part=HAT), [Half((0, 0, 0.067), (0, 0.0, 1))], k=0.003)
    curl = Mirror(Ellipsoid((0.15, 0.012, 0.062), (0.014, 0.1, 0.014), part=HAT))
    hat = Union([crown, band, Union([brim, curl], k=0.012)], k=0.0)
    # the monocle over his right eye (the -X side of his own frame), a chain hanging to the lapel
    mx = ec * np.array([-1, 1, 1], np.float32) + v3((0, -0.026, 0))
    ring = Torus(mx, 0.03, 0.0035, Rm=basis(v3((0, -1, 0)), v3((0, 0, 1))), part=GOLD)
    glass = Ellipsoid(mx + v3((0, 0.002, 0)), (0.028, 0.002, 0.028), part=GLASS)
    return Union([face, Mirror(ball), throat, brows, mous, hat, ring, glass], k=0.0)


# ---------------------------------------------------------------------------------------------------- the suit

def torso_core():
    """the shirt: one broad chest for two, shoulders, waist"""
    return Union([
        Ellipsoid((0, 0.0, 1.245), (0.31, 0.16, 0.22)),
        Ellipsoid((0, 0.012, 1.405), (0.355, 0.13, 0.065)),
        Ellipsoid((0, 0.004, 1.04), (0.265, 0.148, 0.14)),
        Ellipsoid((0, -0.02, 1.11), (0.235, 0.15, 0.12)),
    ], k=0.08, part=SHIRT)


def prism(poly_xz, y0=-0.6, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def about(poly, xv):
    """an outline mirrored about the vertical line x = xv"""
    return [(2 * xv - a, b) for a, b in poly]


def front_y(shape, x, z, y0=-0.6, y1=0.3):
    ys = np.linspace(y0, y1, 1801).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


def neck_v():
    """the V-neck opening, left one (mirrored for the right)"""
    return [(XV - 0.075, 1.50), (XV + 0.075, 1.50), (XV + 0.006, 1.135), (XV - 0.006, 1.135)]


def jacket(sleeves):
    core = torso_core()
    shell = Union([
        Inflate(core, 0.014, part=SUIT),
        Mirror(Box((0.31, 0.01, 1.418), (0.07, 0.07, 0.034), rr=0.03, part=SUIT)),
        Ellipsoid((0, 0.012, 0.965), (0.285, 0.172, 0.15), part=SUIT),
    ], k=0.04, part=SUIT)
    shell = Clip(shell, [Half((0, 0, 0.88), (0, 0.0, -1.0))], k=0.004)
    shell = Union([shell] + sleeves, k=0.02, part=SUIT)
    shell = Cut(shell, [Mirror(prism(neck_v()))], k=0.008)
    # lapels down each side of each V, notched; a thicker layer of the jacket inside their outline
    outer = [(XV + 0.075, 1.495), (XV + 0.006, 1.14), (XV + 0.06, 1.29), (XV + 0.098, 1.39), (XV + 0.085, 1.405), (XV + 0.105, 1.44), (XV + 0.088, 1.49)]
    lap = Clip(Inflate(core, 0.022, part=SUIT), [Mirror(Union([prism(outer), prism(about(outer, XV))]))], k=0.005)
    shell = Union([shell, lap], k=0.0, part=SUIT)
    # two shirt collars: thin flaps round each neck, points out over the lapels
    cpoly = [(XV + 0.0, 1.475), (XV + 0.062, 1.51), (XV + 0.07, 1.46), (XV + 0.026, 1.425)]
    collar = Clip(Cut(Inflate(core, 0.03, part=SHIRT), [Inflate(core, 0.023)], k=0.002), [Mirror(Union([prism(cpoly), prism(about(cpoly, XV))]))], k=0.004)
    band = Mirror(Clip(RoundCone((0.175, 0.015, 1.43), (0.175, 0.01, 1.50), 0.066, 0.06, part=SHIRT), [Half((0, 0, 1.505), (0, 0, 1))], k=0.003))
    # the ties: knot and blade down each V; his left's wide and loud, his right's narrow and sober
    ties = []
    for side, part, w in ((1.0, TIE_A, 1.15), (-1.0, TIE_B, 0.85)):
        x = side * XV
        ky = front_y(core, x, 1.44)
        knot = Box((x, ky - 0.01, 1.445), (0.019 * w, 0.014, 0.019), rr=0.009, R=rot(rx=12), part=part)
        w0, w1, w2 = 0.016 * w, 0.026 * w, 0.031 * w
        blade = Clip(Inflate(core, 0.006, part=part), [prism([(x - w0, 1.43), (x + w0, 1.43), (x + w1, 1.30), (x + w2, 1.19), (x, 1.15), (x - w2, 1.19), (x - w1, 1.30)])], k=0.002)
        ties += [knot, blade]
    # one row of buttons down the shared middle panel, a breast pocket each side with a hanky on his left
    buttons = []
    for z in (1.10, 1.21, 1.32):
        by = front_y(Inflate(core, 0.014), 0.0, z)
        buttons.append(Ellipsoid((0, by, z), (0.012, 0.005, 0.012), part=BUTTON))
    hy = front_y(Inflate(core, 0.014), 0.25, 1.33)
    hanky = Union([Gem((0.25, hy - 0.004, 1.342), (0.012, 0.012, 0.004, 0.004, 0.006, 0.02), soft=0.2, edge=0.002, part=TIE_A),
                   Gem((0.27, hy - 0.001, 1.338), (0.01, 0.01, 0.004, 0.004, 0.006, 0.016), soft=0.2, edge=0.002, part=TIE_A)])
    return Union([core, shell, collar, band] + ties + buttons + [hanky], k=0.0)


def legs():
    hips = Union([
        Ellipsoid((0, 0.01, 0.95), (0.25, 0.15, 0.12)),
        Mirror(loft([(HIP, 0.105), (KNEE, 0.085), (HEM, 0.084)])),
    ], k=0.05, part=TROUSERS)
    ridge = ridge_line((0.12, -0.105, 0.86), (0.13, -0.075, 0.13), 0.012)

    def crease(P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        return ridge(Q)
    hips = Bump(hips, crease, 0.003)
    trousers = Clip(hips, [Half((0, 0, 0.11), (0.0, -0.2, -1.0))], k=0.003)
    return Union([trousers, Mirror(shoe())], k=0.0)


def shoe():
    """a round-toed derby: the last, a heel, a sole"""
    x = ANKLE[0]
    last = Union([
        loft([(ANKLE + v3((0, 0.012, 0.0)), 0.046), (v3((x + 0.002, -0.06, 0.045)), 0.05), (v3((x + 0.006, -0.15, 0.036)), 0.04)], k=0.02),
        Ellipsoid((x + 0.006, -0.155, 0.035), (0.048, 0.05, 0.034)),
    ], k=0.02, part=SHOE)
    last = Clip(last, [Half((0, 0, 0.022), (0, 0, -1))], k=0.003)
    sole = Clip(Inflate(Union([loft([(ANKLE + v3((0, 0.012, 0.0)), 0.046), (v3((x + 0.002, -0.06, 0.045)), 0.05), (v3((x + 0.006, -0.15, 0.036)), 0.04)], k=0.02),
                               Ellipsoid((x + 0.006, -0.155, 0.035), (0.048, 0.05, 0.034))], k=0.02), 0.005, part=SOLE),
                [Half((0, 0, 0.024), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    heel = Box((x, 0.03, 0.016), (0.042, 0.04, 0.016), rr=0.008, part=SOLE)
    return Union([last, sole, heel], k=0.004)


def hand_relaxed():
    """a relaxed four-fingered hand in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y)"""
    palm = Ellipsoid((0.0, 0.0, -0.048), (0.019, 0.042, 0.05), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.032, 0.028, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.028, 0.86), (-0.009, 1.0), (0.01, 0.97), (0.028, 0.8)):
        pts = [((0.0, f, -0.088), 0.0105), ((-0.006, f, -0.088 - 0.03 * L), 0.0098), ((-0.018, f * 1.04, -0.088 - 0.055 * L), 0.009), ((-0.032, f * 1.05, -0.088 - 0.068 * L), 0.0082)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((0.004, 0, 0.003)), (0.005, 0.0065, 0.006), part=NAIL))
    parts.append(loft([(v3((-0.01, -0.03, -0.028)), 0.013), (v3((-0.026, -0.048, -0.058)), 0.0112), (v3((-0.036, -0.05, -0.082)), 0.0095)], part=SKIN, k=0.004))
    return Union(parts, k=0.008)


def sleeve():
    s = Clip(loft([(SHOULDER, 0.072), (ELBOW, 0.064), (WRIST, 0.056)], part=SUIT, k=0.012), [Half(WRIST + (WRIST - ELBOW) * 0.02, (WRIST - ELBOW))], k=0.003)
    d = unit(WRIST - ELBOW)
    cuff = Clip(Cut(CappedCone(WRIST - d * 0.02, WRIST + d * 0.012, 0.047, 0.045, rr=0.004, part=SHIRT), [CappedCone(WRIST - d * 0.03, WRIST + d * 0.03, 0.04, 0.04)]), [Half(WRIST + d * 0.012, d)])
    return s, Union([cuff, place(hand_relaxed(), WRIST, HAND)], k=0.0)


def necks():
    return Union([Mirror(RoundCone((0.175, 0.018, 1.40), (0.175, 0.006, NECK_TOP), 0.055, 0.05, part=SKIN))], k=0.0)


def pieces():
    sl, hd = sleeve()
    body = Union([jacket([sl, Move(sl, R=FLIP)]), legs(), hd, Move(hd, R=FLIP), necks()], k=0.0)
    heads = Union([Move(head_a(), R=HA.R / HS, t=HA.t), Move(head_b(), R=HB.R / HS, t=HB.t)], k=0.0)
    return [("heads", heads, 0.0018), ("body", body, 0.0035)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n1 = noise3(P, 0.05)
    n2 = noise3(P, 0.013)
    mott = n1 * 0.5 + n2 * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (m.sum(), 3)), np.broadcast_to(np.asarray(amt, np.float32), (m.sum(),))[:, None]], 1)

    def local(h):
        return h.local(P)                 # each point in a head's own frame

    A, B = local(HA), local(HB)
    on_a = x > 0
    # skin: warm peach, the cheerful one flushed in the cheeks and nose, the sour one sallow with grey stubble on the jowls
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(232, 170, 134), (len(P), 3)).copy()
    sk *= (1.0 + 0.06 * mott)[:, None]
    blush_a = on_a * (smooth(0.06, 0.0, np.linalg.norm(np.abs(A) - v3((0.06, -0.08, -0.03)), axis=1)) * 0.6 + smooth(0.04, 0.0, np.linalg.norm(A - v3((0, -0.13, -0.005)), axis=1)) * 0.5)
    sk = sk + (srgb(224, 108, 100) - sk) * blush_a[:, None]
    sallow = ~on_a * 0.25
    sk = sk + (srgb(196, 164, 128) - sk) * sallow[:, None]
    sk = sk + (srgb(220, 150, 120) - sk) * (~on_a * smooth(0.035, 0.0, np.linalg.norm(B - v3((0, -0.145, -0.012)), axis=1)) * 0.6)[:, None]
    shade = smooth(1.47, 1.40, z)
    sk *= (1.0 - 0.15 * shade)[:, None]
    put(m, sk, 0.5, bump=0.12)
    stub = m & ~on_a & (B[:, 2] < -0.06) & (B[:, 1] < 0.0)
    spk(stub, (90, 80, 76), 0.55)
    spk(m & on_a & (A[:, 1] < -0.05) & (A[:, 2] < 0.02) & (A[:, 2] > -0.06), (196, 120, 96), 0.25)
    # each eye: white, an iris looking where the head looks, inked pupil, liner along the upper lid
    m = c.mask(EYE)
    ey = np.broadcast_to(srgb(244, 238, 226), (len(P), 3)).copy()
    for h, (ec, re, fwd), L, iris, ring in ((HA, EYE_A, A, (70, 150, 160), (30, 70, 80)), (HB, EYE_B, B, (128, 128, 112), (60, 60, 52))):
        mine = (x > 0) == (h is HA)
        gdir = unit(fwd + v3((0.25, 0.0, 0.5)))
        for s in (1.0, -1.0):
            ce = ec * np.array([s, 1, 1], np.float32)                  # this eye's centre in the head's frame; both eyes look along fwd
            dv = L - ce
            r = np.linalg.norm(dv, axis=1)
            near = m & mine & (r < re * 1.3)
            dd = dv / np.maximum(r, 1e-6)[:, None]
            ang = np.arccos(np.clip(dd @ fwd, -1, 1))
            ir = srgb(*iris) + (srgb(*ring) - srgb(*iris)) * smooth(0.25, 0.6, ang)[:, None]
            ey[near] = np.where((ang < 0.6)[near, None], ir[near], ey[near])
            c.draw(near, (ang - 0.3) * re, 0.0)
            c.draw(near & (ang < 0.75), np.abs(ang - 0.6) * re, 0.0006, 0.7)
            g = smooth(0.26, 0.15, np.arccos(np.clip(dd @ gdir, -1, 1)))
            ey[near] = ey[near] + (srgb(255, 255, 250) - ey[near]) * g[near, None]
            ey[near] *= (1.0 - 0.35 * smooth(0.0, 0.7, dd[near, 2]))[:, None]
            sm = c.mask(SKIN) & mine & (r < re + 0.009) & (dv[:, 2] > -0.004) & (dv[:, 1] < 0.004)
            c.draw(sm, np.abs(r - re - 0.0015), 0.0013, 0.95)
    put(m, ey, 0.08)
    c.spk[m, 3] = 0.0
    m = c.mask(LIP)
    put(m, np.where(on_a[:, None], srgb(196, 92, 88), srgb(166, 104, 96)) * (1.0 + 0.08 * n2)[:, None], 0.3, bump=0.2)
    put(c.mask(MOUTH), srgb(52, 10, 18), 0.6)
    put(c.mask(TOOTH), srgb(240, 232, 210), 0.28)
    m = c.mask(BROW)
    put(m, np.where(on_a[:, None], srgb(112, 64, 34), srgb(168, 164, 158)) * (1.0 + 0.25 * noise3(P, 0.004))[:, None], 0.85, bump=1.0)
    # the beanie: rust knit, ribbed round the cuff; mustard bobble
    m = c.mask(KNIT)
    phi = np.arctan2(A[:, 0], -A[:, 1])
    kn = srgb(170, 76, 40) * (1.0 + 0.1 * mott)[:, None]
    put(m, kn, 0.95, bump=1.0)
    c.strp[m, 0] = (phi * 0.12 * 0.4)[m]
    c.strp[m, 1] = 0.6
    spk(m, (120, 50, 24), 0.25)
    m = c.mask(BOBBLE)
    put(m, srgb(224, 172, 58) * (1.0 + 0.2 * noise3(P, 0.006))[:, None], 0.95, bump=1.0)
    # the bowler, its band, the monocle
    m = c.mask(HAT)
    put(m, (srgb(22, 20, 22) * (1.0 + 1.4 * c.wear)[:, None]), 0.6, bump=0.4)
    put(c.mask(BAND), srgb(40, 34, 36), 0.3, bump=0.1)
    m = c.mask(GOLD)
    put(m, srgb(236, 180, 86) * (1.0 - 0.4 * c.cavity)[:, None], 0.25, metal=1.0, grain=1.0, bump=0.05)
    put(c.mask(GLASS), srgb(170, 196, 206), 0.04, metal=0.3)
    # the suit: mustard with a brown windowpane check, worn at the elbows and cuffs
    m = c.mask(SUIT, TROUSERS)
    su = srgb(198, 150, 52) * (1.0 + 0.06 * mott)[:, None]
    su = su * (1.0 + 0.25 * c.wear)[:, None]
    put(m, su, 0.85, bump=1.0)
    c.strp[m, 0] = (x * 0.4)[m]
    c.strp[m, 1] = 0.9
    win = np.abs(((z + 0.015) / 0.06) % 1.0 - 0.5) * 0.06
    c.draw(m, np.abs(win - 0.03), 0.0011, 0.35)
    spk(m, (120, 84, 30), 0.12)
    # shirt white, ties: his left's red with white polka dots, his right's navy with a thin gold stripe
    m = c.mask(SHIRT)
    put(m, srgb(240, 236, 226) * (1.0 + 0.03 * mott)[:, None], 0.6, bump=0.4)
    m = c.mask(TIE_A)
    put(m, srgb(196, 30, 34), 0.35, bump=0.3)
    spk(m, (250, 240, 230), 0.6)
    m = c.mask(TIE_B)
    put(m, srgb(26, 34, 76), 0.35, bump=0.3)
    c.strp[m, 0] = ((x + z) * 0.5)[m]
    c.strp[m, 1] = 1.0
    m = c.mask(BUTTON)
    put(m, srgb(98, 64, 34), 0.35)
    m = c.mask(SHOE)
    put(m, srgb(96, 50, 26) * (1.0 + 0.9 * c.wear)[:, None], 0.25, bump=0.2, grain=1.0)
    put(c.mask(SOLE), srgb(34, 24, 18), 0.6)
    put(c.mask(NAIL), srgb(236, 196, 180), 0.3)
    c.col *= (0.32 + 0.68 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model

GAME = {
    "budget": {"heads": 4200, "body": 4800},
    "density": {"heads": 1.8},
    "tex": 2048,
    "stride": {"walk": 1.24, "run": 2.0},
    "speed": 0.95,
    "look": ["head.L", "jaw.L"], "neck": "neck.L",
    "look_pivot": (0.175, 0.0, 1.55),
    "radius": 0.42,
}
BALL = v3((0.132, -0.09, 0.0))


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.01, 0.93), (0, 0.01, 1.06), "root", 0.15),
        Bone("spine", (0, 0.01, 1.06), (0, 0.005, 1.22), "hips", 0.15),
        Bone("chest", (0, 0.005, 1.22), (0, 0.01, 1.40), "spine", 0.17),
        Bone("shoulder.L", (0.06, 0.01, 1.40), SHOULDER, "chest", 0.06),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.065),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.058),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.1, "forearm.L", 0.03),
        Bone("thigh.L", HIP, KNEE, "hips", 0.1),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.08),
        Bone("foot.L", ANKLE, (0.135, -0.16, 0.03), "shin.L", 0.04),
    ])
    for nm, h, (hinge, chin), s in (("L", HA, JAW_A, 1.0), ("R", HB, JAW_B, -1.0)):
        bones += [
            Bone("neck." + nm, (s * 0.175, 0.016, 1.42), (s * 0.175, 0.006, 1.53), "chest", 0.05),
            Bone("head." + nm, h.w((0, 0.0, -0.06)), h.w((0, 0.0, 0.14)), "neck." + nm, 0.1),
            Bone("jaw." + nm, h.w(hinge), h.w(chin), "head." + nm, 0.03),
        ]
    return bones


def skin_rules(P, part, piece, names):
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    # heads: rigid on the head above the mouth, the lower lip and chin on the jaw
    hp = piece == 0
    for nm, h, (hinge, chin) in (("L", HA, JAW_A), ("R", HB, JAW_B)):
        mine = hp & ((x > 0) if nm == "L" else (x <= 0))
        L = h.local(P)
        zcut, tilt = (-0.076, 0.25) if nm == "L" else (-0.096, -0.2)      # the middle of each mouth's slot, rising (a smile) or falling (a frown) to its corners
        jaw_lo = (L[:, 1] < -0.03) & (L[:, 2] < zcut + tilt * np.abs(L[:, 0])) & (np.abs(L[:, 0]) < 0.085) & ~np.isin(part, (BROW,))
        rig[mine & ~jaw_lo] = ix["head." + nm]
        rig[mine & jaw_lo] = ix["jaw." + nm]
        allow(mine, "head." + nm)
    # body: legs, torso, arms, necks
    bp = piece == 1
    legs = bp & (np.isin(part, (TROUSERS, SHOE, SOLE)) | (z < 0.3))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    neck = bp & (part == SKIN) & (z > 1.38) & (np.abs(x) < 0.26)
    allow(neck & (x > 0), "chest", "neck.L")
    allow(neck & (x <= 0), "chest", "neck.R")
    torso = bp & ~legs & ~neck & ((np.abs(x) < 0.3) | (z > 1.38)) & ~((np.abs(x) > 0.37) & (z < 1.3))
    torso &= ~((part == SKIN) & (z < 1.0))
    allow(torso, "hips", "spine", "chest")
    allow(torso & (x > 0.12), "shoulder.L", "upper_arm.L")
    allow(torso & (x < -0.12), "shoulder.R", "upper_arm.R")
    arms = bp & ~legs & ~neck & ~torso
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "upper_arm.R", "forearm.R", "hand.R")
    return A, rig


WALK = dict(stride=1.24, stance=0.6, foot_x=0.11, lift=0.06, bob=0.016, drop=0.03, sway=0.022, roll=5.0, yaw=6.0, counter=1.0,
            lean=1.0, toe_off=18.0, toe_out=7.0, swing_point=8.0)
RUN = dict(stride=2.0, stance=0.42, foot_x=0.12, lift=0.13, bob=0.034, drop=0.07, sway=0.02, roll=4.0, yaw=9.0, counter=1.3,
           lean=10.0, toe_off=26.0, toe_out=6.0, swing_point=16.0, spine_lean=4.0)


def motions(rig):
    """walk: a plain business walk below, an argument above: each step one head leans in at the other and talks (its jaw going), the other
    pulls back with its chin up, then they swap; each head's own arm jabs when it speaks. run: both heads face front, jaws shut, arms pumping.
    idle: a full row over six seconds: the cheerful one chatters, the sour one shakes his head, they glare, and turn away in a huff"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def talk(t, rate):
        """a jaw's opening (degrees) when speaking: syllables at `rate` a second"""
        return 7.0 + 7.0 * math.sin(TAU * rate * t) * math.sin(TAU * rate * 0.37 * t + 1.0)

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        c = math.cos(TAU * u)
        a = 30.0 if run else 14.0
        p.rot("upper_arm.L", a * c, 0, 0)
        p.rot("forearm.L", -(30.0 if run else 8.0) - 6.0 * max(0.0, c), 0, 0)
        p.rot("upper_arm.R", -a * c, 0, 0)
        p.rot("forearm.R", -(30.0 if run else 8.0) - 6.0 * max(0.0, -c), 0, 0)
        if run:
            p.world["head.L"] = R(6.0, 0, 6.0 + 3.0 * math.sin(2 * TAU * u))
            p.world["head.R"] = R(6.0, 0, -6.0 - 3.0 * math.sin(2 * TAU * u + 1))
            p.rot("jaw.L", 10.0, 0, 0)
            p.rot("jaw.R", 4.0, 0, 0)
            return p
        # who has the floor: the cheerful one (k = 1) through the first half, the sour one (k = 0) the second
        k = 0.5 + 0.5 * math.cos(TAU * u)
        lean_a = 14.0 * k + 2.0
        lean_b = 16.0 * (1.0 - k) + 2.0
        p.world["head.L"] = R(-4.0 * k + 3.0, -6.0 * k, -lean_a + 2.0 * math.sin(2 * TAU * u))
        p.world["head.R"] = R(-8.0 * (1 - k) + 4.0 * k, 5.0 * (1 - k), lean_b - 4.0 * k)
        p.rot("jaw.L", talk(u * 1.1, 4.0) * k + 1.0, 0, 0)
        p.rot("jaw.R", talk(u * 1.1 + 0.3, 4.0) * (1 - k) + 1.0, 0, 0)
        # the speaker's forearm comes up in a jab
        p.rot("forearm.L", -30.0 * k * k, 0, -10.0 * k * k)
        p.rot("forearm.R", -30.0 * (1 - k) ** 2, 0, 10.0 * (1 - k) ** 2)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        br = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.15, -0.1, 0.0)), 8.0), "R": (Vector((-0.15, -0.06, 0.0)), -10.0)},
              hip_shift=(0.012 * math.sin(TAU * t / 6.0), 0.0, -0.01), roll=-2.0 * math.sin(TAU * t / 6.0))
        p.rot("spine", 1.0 * br, 0, 0)
        p.rot("chest", 1.0 * br, 0, 0)
        # 0-2 s the cheerful one chatters at the other; 2-3.6 s the sour one shakes his head and grumbles; 3.6-4.6 they glare; 4.6-6 a huff, back to start
        a_talk = ease(t / 0.3) * (1.0 - ease((t - 2.0) / 0.3))
        b_talk = ease((t - 2.0) / 0.3) * (1.0 - ease((t - 3.6) / 0.3))
        glare = ease((t - 3.6) / 0.3) * (1.0 - ease((t - 4.6) / 0.4))
        huff = ease((t - 4.6) / 0.4) * (1.0 - ease((t - 5.6) / 0.4))
        shake = 9.0 * math.sin(TAU * 2.2 * t) * b_talk
        yaw_a = -12.0 * a_talk - 16.0 * glare + 14.0 * huff + 3.0 * math.sin(TAU * t * 1.7) * a_talk
        yaw_b = 6.0 * a_talk + 12.0 * glare - 16.0 * huff + shake
        p.world["head.L"] = R(-3.0 * a_talk + 3.0 * math.sin(TAU * 3.0 * t) * a_talk, -5.0 * a_talk, yaw_a)
        p.world["head.R"] = R(-6.0 * b_talk + 5.0 * huff - 4.0 * glare, 4.0 * glare, yaw_b)
        p.rot("jaw.L", talk(t, 4.5) * a_talk + 1.0, 0, 0)
        p.rot("jaw.R", talk(t + 0.2, 3.0) * b_talk + 1.0, 0, 0)
        p.rot("upper_arm.L", -18.0 * a_talk * (0.6 + 0.4 * math.sin(TAU * 1.5 * t)), 0, -6.0 * a_talk)
        p.rot("forearm.L", -50.0 * a_talk, 0, -20.0 * a_talk)
        p.rot("upper_arm.R", -14.0 * b_talk, 0, 4.0 * b_talk + 8.0 * glare)
        p.rot("forearm.R", -40.0 * b_talk - 20.0 * glare, 0, 25.0 * b_talk)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
