## FOINT CITY townsfolk: the TV-headed robot (tvbot). A portable CRT for a head, a phosphor face on its screen, rabbit-ear antennas; a chunky mustard cardigan over a round tin body, thin steel legs in rubber boots.
# Upgrade of the three.js folk species "tvbot" (progalpha levels/hub/folk-species-a.js; old render refs/old/tvbot.png): kept its yellow knit jacket with a dark
# placket and buttons, grey TV head with a black screen and yellow oval eyes and smile, side knobs, two antennas (red ball on its left, yellow on its right),
# thin dark legs and black feet. The smiley shopping bag is dropped (roster). 1.70 m to the antenna balls; the TV casing tops out at 1.45.
# Moves: a stiff toy-robot stride, legs swinging nearly straight from the hip, arms swinging stiff with a little tick at each end, antennas springing behind.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.70
REF = ("old/tvbot.png", None)

CASE, BEZEL, SCREEN, CHROME, KNOB, ANT, BALL, NECK, KNIT, RIB, BUTTON, STEEL, JOINT, RUBBER, SOLE = range(1, 16)
COLOURS = {
    CASE: ((0.62, 0.58, 0.50), 0.5, 0.0),
    BEZEL: ((0.06, 0.06, 0.07), 0.4, 0.0),
    SCREEN: ((0.02, 0.05, 0.04), 0.08, 0.0),
    CHROME: ((0.8, 0.8, 0.82), 0.2, 1.0),
    KNOB: ((0.04, 0.04, 0.04), 0.3, 0.0),
    ANT: ((0.7, 0.7, 0.72), 0.25, 1.0),
    BALL: ((0.9, 0.2, 0.1), 0.25, 0.0),
    NECK: ((0.18, 0.18, 0.2), 0.5, 0.0),
    KNIT: ((0.80, 0.56, 0.08), 0.85, 0.0),
    RIB: ((0.62, 0.42, 0.06), 0.85, 0.0),
    BUTTON: ((0.22, 0.12, 0.06), 0.45, 0.0),
    STEEL: ((0.22, 0.23, 0.25), 0.35, 1.0),
    JOINT: ((0.45, 0.46, 0.48), 0.3, 1.0),
    RUBBER: ((0.03, 0.03, 0.03), 0.8, 0.0),
    SOLE: ((0.10, 0.09, 0.08), 0.9, 0.0),
}

# landmarks, left side (+X); the figure faces -Y
TV_C = v3((0.0, -0.02, 1.29))          # the casing's front box centre
SCR_C = v3((0.0, -0.152, 1.297))       # the screen's centre, on its glass
SCR_HALF = (0.158, 0.118)              # the screen's half width and half height
SHOULDER = v3((0.235, 0.012, 1.0))
ELBOW = v3((0.298, 0.03, 0.785))
WRIST = v3((0.318, 0.0, 0.585))
HIP = v3((0.085, 0.01, 0.655))
KNEE = v3((0.092, 0.0, 0.37))
ANKLE = v3((0.098, 0.02, 0.098))
ANT_ROOT = v3((0.018, 0.035, 1.465))
ANT_TIP = v3((0.135, 0.06, 1.655))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))       # hangs along the forearm: fingers -Z, back of the hand +X, thumb -Y
CUFF_T = 0.74                                       # where the sleeve ends along the forearm


class Scaled(Shape):
    """a shape scaled uniformly about the origin (the kit has no scale; this one is exact for a uniform factor)"""
    def __init__(self, child, s):
        self.child, self.s = child, np.float32(s)
        lo, hi = child.bound()
        self.lo, self.hi = lo * self.s, hi * self.s
        self.part = child.part

    def eval(self, P):
        d, pt = self.child.eval(P / self.s)
        return d * self.s, pt

    def dist(self, P):
        return self.eval(P)[0]


def folds(dirn, scale, amp_fn=None):
    """soft cloth folds across `dirn`: noise squeezed along it (ridges run across the direction)"""
    d = v3(dirn) / np.linalg.norm(dirn)

    def fn(P):
        P = P.copy()
        P[:, 0] = np.abs(P[:, 0])          # mirror-symmetric (the decimator keeps the two sides alike)
        Pt = P + np.outer(P @ d, d) * 2.2
        f = noise3(Pt, scale)
        return f if amp_fn is None else f * amp_fn(P)
    return fn


def prism(poly_xz, y0=-0.5, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from the front (y0) to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


# ---------------------------------------------------------------------------------------------------- the TV

def tv():
    # a portable set: a pillowy front box, the tube's housing tapering away behind it
    front = Box(TV_C, (0.212, 0.125, 0.158), rr=0.058, part=CASE)
    hood = Box(TV_C + v3((0.0, 0.17, -0.008)), (0.158, 0.085, 0.118), rr=0.06, part=CASE)
    casing = Union([front, hood], k=0.06, part=CASE)
    # (the vent slots on the hood and the speaker slots under the screen are painted: cut in, they cost the decimator its budget and flipped faces)
    # the front: a dark bezel set into the casing, a chrome ring round it, the screen bulging inside
    rim_out = Box((0.0, -0.15, SCR_C[2]), (SCR_HALF[0] + 0.026, 0.02, SCR_HALF[1] + 0.026), rr=0.045)
    casing = Cut(casing, [rim_out], k=0.006)
    bezel = Box((0.0, -0.125, SCR_C[2]), (SCR_HALF[0] + 0.024, 0.016, SCR_HALF[1] + 0.024), rr=0.044, part=BEZEL)
    hole = Box((0.0, -0.15, SCR_C[2]), (SCR_HALF[0], 0.03, SCR_HALF[1]), rr=0.034)
    bezel = Cut(bezel, [hole], k=0.004)
    ring = Cut(Box((0.0, -0.134, SCR_C[2]), (SCR_HALF[0] + 0.03, 0.012, SCR_HALF[1] + 0.03), rr=0.05, part=CHROME),
               [Box((0.0, -0.134, SCR_C[2]), (SCR_HALF[0] + 0.021, 0.03, SCR_HALF[1] + 0.021), rr=0.042)], k=0.002)
    glass = Clip(Box((0.0, -0.08, SCR_C[2]), (SCR_HALF[0] + 0.007, 0.09, SCR_HALF[1] + 0.007), rr=0.037, part=SCREEN),
                 [Sphere((0.0, SCR_C[1] + 1.1, SCR_C[2]), 1.1)], k=0.003)      # (the big sphere only trims: its bound would blow up the grid)
    # the knobs, one each side like ears: a ridged bakelite dial with a chrome cap and a pointer
    knob = CappedCone((0.205, -0.03, 1.31), (0.248, -0.03, 1.31), 0.042, 0.036, rr=0.008, part=KNOB)      # (its grip ridges are painted)
    cap = CappedCone((0.244, -0.03, 1.31), (0.254, -0.03, 1.31), 0.022, 0.019, rr=0.004, part=CHROME)
    pointer = Box((0.252, -0.03, 1.335), (0.004, 0.005, 0.013), rr=0.002, part=CHROME)
    small = CappedCone((0.20, -0.04, 1.215), (0.232, -0.04, 1.215), 0.021, 0.018, rr=0.005, part=KNOB)
    # the antenna base on top, the speaker slots under the screen
    base = Union([CappedCone((0.0, 0.035, 1.44), (0.0, 0.035, 1.47), 0.05, 0.04, rr=0.01, part=CHROME),
                  Mirror(Sphere(ANT_ROOT, 0.016, part=CHROME))], k=0.008)
    feet = Mirror(Box((0.15, 0.04, 1.125), (0.03, 0.06, 0.012), rr=0.008, part=KNOB))
    body = Union([casing, bezel], k=0.0)
    return Union([body, ring, glass, base, feet], k=0.0), Mirror(Union([knob, cap, pointer, small], k=0.0))


def antennas():
    """telescoping rabbit ears (left one built, mirrored), a ball on each tip"""
    d = (ANT_TIP - ANT_ROOT) / np.linalg.norm(ANT_TIP - ANT_ROOT)
    L = np.linalg.norm(ANT_TIP - ANT_ROOT)
    segs = [RoundCone(ANT_ROOT + d * 0.01, ANT_ROOT + d * L * 0.45, 0.0072, 0.0072, part=ANT),
            RoundCone(ANT_ROOT + d * L * 0.43, ANT_ROOT + d * L * 0.78, 0.0058, 0.0058, part=ANT),
            RoundCone(ANT_ROOT + d * L * 0.76, ANT_TIP, 0.0046, 0.0046, part=ANT)]
    collars = [Sphere(ANT_ROOT + d * L * t, r, part=ANT) for t, r in ((0.45, 0.0085), (0.78, 0.007))]
    ball = Sphere(ANT_TIP + d * 0.026, 0.031, part=BALL)
    return Mirror(Union(segs + collars + [ball], k=0.003))


# ---------------------------------------------------------------------------------------------------- the body

def torso_core():
    """the round tin body under the cardigan"""
    return Union([
        Ellipsoid((0, 0.012, 0.875), (0.182, 0.142, 0.17)),
        Ellipsoid((0, 0.0, 0.735), (0.17, 0.138, 0.125)),
        Ellipsoid((0, 0.018, 0.982), (0.205, 0.112, 0.068)),
    ], k=0.05, part=KNIT)


def sleeve():
    """the left sleeve: knit down to most of the forearm, a ribbed cuff; then the steel wrist"""
    cuff_at = ELBOW + (WRIST - ELBOW) * CUFF_T
    d = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    s = Clip(loft([(SHOULDER, 0.056), (ELBOW, 0.051), (cuff_at, 0.048)], part=KNIT, k=0.015), [Half(cuff_at - d * 0.032, d)], k=0.004)
    s = Bump(s, folds(WRIST - SHOULDER, 0.035, lambda P: np.exp(-((P[:, 2] - ELBOW[2]) / 0.09) ** 2) + 0.3), 0.004)
    cuff = Clip(RoundCone(cuff_at - d * 0.05, cuff_at + d * 0.01, 0.049, 0.048, part=RIB), [Half(cuff_at, d), Half(cuff_at - d * 0.034, -d)], k=0.003)
    # (knit ribbing is painted, not sculpted: sculpted ribs made the decimator spend the whole torso's budget on them)
    return s, cuff, cuff_at


def cardigan(sleeves):
    core = torso_core()
    knit = Clip(Inflate(core, 0.014, part=KNIT), [Half((0, 0, 0.695), (0, 0, -1))], k=0.006)
    knit = Bump(knit, folds((0, 0, 1), 0.05, lambda P: np.clip((0.86 - P[:, 2]) / 0.12, 0.25, 1.0)), 0.0035)      # gathered toward the hem
    knit = Union([knit] + sleeves, k=0.02, part=KNIT)
    # the ribbed hem band, gathered under the belly
    band = Clip(Inflate(core, 0.02, part=RIB), [Half((0, 0, 0.70), (0, 0, 1)), Half((0, 0, 0.628), (0, 0, -1))], k=0.004)
    # a ribbed roll collar round the neck hole
    collar = Torus((0, 0.022, 1.044), 0.072, 0.024, Rm=rot(rx=-12), part=RIB)
    # the button placket down the front, and its buttons
    placket = Clip(Inflate(core, 0.021, part=RIB), [prism([(-0.022, 1.02), (0.022, 1.02), (0.022, 0.70), (-0.022, 0.70)])], k=0.003)
    buttons = []
    for z in (0.93, 0.835, 0.745):
        y = float(probe_front(core, 0.0, z)) - 0.026
        b = CappedCone((0.0, y + 0.012, z), (0.0, y - 0.004, z), 0.017, 0.015, rr=0.005, part=BUTTON)
        holes = [Sphere((sx * 0.005, y - 0.006, z + sz * 0.005), 0.0028) for sx in (-1, 1) for sz in (-1, 1)]
        buttons.append(Cut(b, holes, k=0.0008))
    # patch pockets on the belly: a thin layer of the knit, a ribbed top
    pocket = Clip(Cut(Inflate(core, 0.024, part=KNIT), [Inflate(core, 0.008)], k=0.002), [Mirror(prism([(0.055, 0.81), (0.145, 0.81), (0.138, 0.71), (0.062, 0.71)]))], k=0.004)
    neck_hole = Cylinder_cut()
    shell = Cut(Union([knit, band, placket, pocket], k=0.0), [neck_hole], k=0.01)
    return Union([shell, collar] + buttons, k=0.0)


def Cylinder_cut():
    return CappedCone((0, 0.02, 1.0), (0, 0.02, 1.12), 0.05, 0.05, rr=0.0)


def probe_front(shape, x, z, y_from=-0.5):
    """where a shape's front surface is at (x, z): march from the front"""
    ys = np.linspace(y_from, 0.2, 1400).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    i = int(np.argmax(d < 0))
    return ys[i]


def neck():
    n = RoundCone((0, 0.025, 1.0), (0, 0.025, 1.17), 0.047, 0.042, part=NECK)

    def acc(P):
        return 0.5 + 0.5 * np.cos(P[:, 2] * np.pi * 2 / 0.016)
    return Bump(n, acc, 0.004)


def hand():
    """a steel mitt in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): three thick jointed fingers, a thumb"""
    palm = Box((0.0, 0.0, -0.05), (0.021, 0.04, 0.042), rr=0.017, part=STEEL)
    wrist = RoundCone((0, 0, 0.035), (0, 0, -0.012), 0.022, 0.026, part=JOINT)
    parts = [palm, wrist]
    for i, f in enumerate((-0.025, 0.0, 0.025)):
        L = 1.0 - abs(f) * 4.0
        pts = [v3((0.0, f, -0.086)), v3((-0.006, f * 1.05, -0.112 - 0.006 * L)), v3((-0.02, f * 1.05, -0.135 - 0.006 * L)), v3((-0.036, f * 1.05, -0.145 - 0.004 * L))]
        for a, b in zip(pts[:-1], pts[1:]):
            parts.append(RoundCone(a, b, 0.0118, 0.0108, part=STEEL))
        for p in pts[:-1]:
            parts.append(Sphere(p, 0.0135, part=JOINT))
    th = [v3((-0.006, -0.036, -0.03)), v3((-0.018, -0.054, -0.06)), v3((-0.03, -0.054, -0.085))]
    parts += [RoundCone(th[0], th[1], 0.013, 0.012, part=STEEL), RoundCone(th[1], th[2], 0.012, 0.011, part=STEEL), Sphere(th[1], 0.0138, part=JOINT)]
    return Union(parts, k=0.004)


def arm_parts():
    """(the sleeve, its cuff, the steel wrist and hand) of the left arm"""
    s, cuff, cuff_at = sleeve()
    wristbar = RoundCone(cuff_at - (WRIST - ELBOW) * 0.08, WRIST, 0.024, 0.022, part=STEEL)
    return s, cuff, Union([wristbar, place(Scaled(hand(), 1.3), WRIST, HAND)], k=0.004)


def legs():
    hipball = Sphere(HIP + v3((0, 0, -0.04)), 0.047, part=JOINT)
    thigh = RoundCone(HIP, KNEE, 0.038, 0.034, part=STEEL)
    knee = Sphere(KNEE, 0.049, part=JOINT)
    piston = RoundCone(KNEE + v3((0, 0.004, -0.05)), KNEE + (ANKLE - KNEE) * 0.55, 0.045, 0.04, part=STEEL)
    shin = RoundCone(KNEE, ANKLE, 0.033, 0.031, part=STEEL)
    ankle = Sphere(ANKLE, 0.039, part=JOINT)
    # a rubber boot: round toe, a chunky sole with a heel step
    boot = Union([Ellipsoid((0.1, -0.04, 0.066), (0.076, 0.132, 0.066), part=RUBBER),
                  Ellipsoid((0.1, 0.032, 0.075), (0.066, 0.078, 0.066), part=RUBBER)], k=0.03)
    boot = Clip(boot, [Half((0, 0, 0.024), (0, 0, -1))], k=0.004)
    sole = Box((0.1, -0.035, 0.014), (0.08, 0.142, 0.014), rr=0.012, part=SOLE)
    toe = Clip(Inflate(Ellipsoid((0.1, -0.04, 0.066), (0.076, 0.132, 0.066)), 0.004, part=SOLE), [Half((0.1, -0.1, 0.0), (0, 1, 0)), Half((0, 0, 0.034), (0, 0, -1))], k=0.003)
    leg = Union([thigh, shin, piston], k=0.01)
    return Mirror(Union([leg, hipball, knee, ankle, boot, sole, toe], k=0.0))


def pieces():
    """the cardigan and the steel limbs are separate pieces with their own triangle budgets (one piece let the decimator spend
    everything on the knit and collapse the thin legs to spikes); the legs go up under the hem, the wrists into the cuffs"""
    s, cuff, hnd = arm_parts()
    torso = Union([cardigan([s, Move(s, R=FLIP)]), Mirror(cuff)], k=0.0)
    limbs = Union([Mirror(hnd), legs()], k=0.0)
    casing, knobs = tv()          # (the knobs are their own piece: decimated with the casing they left dark bake streaks where they joined it)
    return [("head", casing, 0.0022), ("torso", torso, 0.0032), ("limbs", limbs, 0.003), ("neck", neck(), 0.0025), ("antennas", antennas(), 0.0013),
            ("knobs", knobs, 0.0014)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    from kit.sdf import noise3
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.04) * 0.5 + noise3(P, 0.012) * 0.25
    grime = np.clip(noise3(P + 3.1, 0.03) * 0.8 + 0.2, 0, 1)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = rough[m] if np.ndim(rough) == 1 and np.size(rough) == n else rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, np.float32)], 1)

    # the casing: warm putty plastic, yellowed toward the top, rubbed light on its edges, grime in the seams and the vents
    m = c.mask(CASE)
    cs = np.broadcast_to(srgb(204, 196, 176), (n, 3)).copy()
    cs = cs + (srgb(214, 196, 150) - cs) * smooth(1.30, 1.46, z)[:, None] * 0.6
    cs *= (1.0 + 0.05 * mott)[:, None]
    cs = cs + (srgb(236, 230, 214) - cs) * (c.wear * 0.5)[:, None]
    cs = cs * (1.0 - 0.35 * grime * smooth(0.05, 0.3, c.cavity))[:, None]
    put(m, cs, 0.42, bump=0.15, grain=1.0)
    spk(m, (120, 104, 82), 0.18)
    # vent slots: six across the back of the hood, seven along its top; speaker slots under the screen
    vb = m & (y > TV_C[1] + 0.24) & (np.abs(x) < 0.085) & (np.abs(z - (TV_C[2] - 0.0)) < 0.075)
    c.draw(vb, np.abs(((z - (TV_C[2] - 0.06) + 0.012) % 0.024) - 0.012), 0.0035, 0.95)
    vt = m & (z > TV_C[2] + 0.1) & (np.abs(y - (TV_C[1] + 0.17)) < 0.05) & (np.abs(x) < 0.085)
    c.draw(vt, np.abs(((x + 0.08 + 0.01333) % 0.02667) - 0.01333), 0.0035, 0.95)
    sp = m & (np.abs(z - 1.145) < 0.006) & (y < -0.12) & (np.abs(x) < 0.074)
    c.draw(sp, np.abs(((x + 0.07 + 0.00875) % 0.0175) - 0.00875), 0.0028, 0.95)
    # a strip of silver duct tape wrapped over its right top corner (over a crack), frayed at the ends
    ty = y - (-0.045)
    fray = 0.005 * np.abs(np.sin(ty * 700.0))
    tape = m & (np.abs(ty) < 0.02) & (x < -0.125 - fray) & (z > 1.355 + fray)
    c.col[tape] = (srgb(150, 152, 156) * (1.0 + 0.12 * mott)[:, None])[tape]
    c.rough[tape] = 0.35
    c.metal[tape] = 0.5
    c.grain[tape] = 0.0
    c.draw(m & (x < -0.12) & (z > 1.35), np.abs(np.abs(ty) - 0.02), 0.0006, 0.35)
    # a round sticker on its left side behind the knob: a red star on cream, the edge dark where it lifts
    sq = P - v3((0.212, 0.058, 1.392))
    sd = np.sqrt(sq[:, 1] ** 2 + sq[:, 2] ** 2)
    stick = m & (sd < 0.024) & (x > 0.18)
    c.col[stick] = srgb(232, 220, 190)
    ang = np.arctan2(sq[:, 2], sq[:, 1])
    star = sd - 0.015 * (0.62 + 0.38 * np.cos(5 * (ang - np.pi / 2)))
    c.col[stick & (star < 0)] = srgb(196, 40, 34)
    c.rough[stick] = 0.3
    c.draw(m & (sd < 0.028) & (x > 0.18), np.abs(sd - 0.024), 0.0006, 0.5)
    # a strip of chrome trim round the hood seam is the ring; the bezel: satin black, scuffed
    m = c.mask(BEZEL)
    bz = srgb(22, 22, 24) + (srgb(70, 70, 74) - srgb(22, 22, 24)) * (c.wear * 0.7)[:, None]
    put(m, bz, 0.38, bump=0.1, grain=1.0)
    m = c.mask(CHROME)
    put(m, srgb(214, 214, 220) * (1.0 - 0.45 * c.cavity)[:, None], 0.18, metal=1.0, bump=0.05, grain=1.0)
    m = c.mask(KNOB)
    put(m, srgb(26, 22, 20) + (srgb(78, 66, 56) - srgb(26, 22, 20)) * (c.wear * 0.8)[:, None], 0.32, bump=0.1, grain=1.0)
    kz = np.where(z > 1.27, 1.31, 1.215)
    ky = np.where(z > 1.27, -0.03, -0.04)
    c.strp[m, 0] = (np.arctan2(z - kz, y - ky) * 0.04 * 4.0)[m]
    c.strp[m, 1] = 1.0
    m = c.mask(ANT)
    put(m, srgb(200, 202, 210) * (1.0 - 0.2 * mott)[:, None], 0.2, metal=1.0)
    m = c.mask(BALL)
    bl = np.where((x > 0)[:, None], srgb(224, 44, 30)[None, :], srgb(250, 196, 30)[None, :])
    bl = bl * (1.0 + 0.4 * c.wear)[:, None]
    put(m, bl, 0.22)

    # the screen: a phosphor face on a dark green-black tube. Eyes are two tall ovals, brows lifted, a small smile; a bloom round them,
    # scanlines (Strp), darker toward the corners, a soft reflection across the glass
    m = c.mask(SCREEN)
    u = x - SCR_C[0]
    v = z - SCR_C[2]
    col = np.broadcast_to(srgb(14, 26, 20), (n, 3)).copy()
    corner = np.sqrt((u / SCR_HALF[0]) ** 4 + (v / SCR_HALF[1]) ** 4)
    col = col * (1.0 - 0.6 * smooth(0.55, 1.0, corner))[:, None]
    col = col + (srgb(30, 52, 36) - col) * (smooth(0.9, 0.2, corner) * 0.6)[:, None]

    def oval(cx, cz, rx, rz):
        return (np.sqrt(((u - cx) / rx) ** 2 + ((v - cz) / rz) ** 2) - 1.0) * min(rx, rz)
    eyes = np.minimum(oval(0.056, 0.022, 0.027, 0.046), oval(-0.056, 0.022, 0.027, 0.046))
    def arc(cx, cz, r, a0, a1, w):
        """distance to a round-ended stroke along a circle's arc from angle a0 to a1 (radians, 0 = +u, counter-clockwise)"""
        a = np.arctan2(v - cz, u - cx)
        mid, half = (a0 + a1) * 0.5, (a1 - a0) * 0.5
        da = np.angle(np.exp(1j * (a - mid)))
        on = np.abs(da) <= half
        dr = np.abs(np.sqrt((u - cx) ** 2 + (v - cz) ** 2) - r)
        e0 = np.sqrt((u - cx - r * np.cos(a0)) ** 2 + (v - cz - r * np.sin(a0)) ** 2)
        e1 = np.sqrt((u - cx - r * np.cos(a1)) ** 2 + (v - cz - r * np.sin(a1)) ** 2)
        return np.where(on, dr, np.minimum(e0, e1)) - w
    # the smile: an arc under the eyes, lifted a little at the corners
    smile = arc(0.0, 0.0, 0.062, np.radians(-125), np.radians(-55), 0.0055)
    # brows: short raised arcs over the eyes, the outer ends lower (curious, friendly)
    br = np.minimum(arc(0.054, 0.03, 0.068, np.radians(68), np.radians(108), 0.0042),
                    arc(-0.054, 0.03, 0.068, np.radians(72), np.radians(112), 0.0042))
    feat = np.minimum(np.minimum(eyes, smile), br)
    glow = smooth(0.022, 0.0, feat)
    phos = srgb(255, 212, 64)
    col = col + (srgb(150, 110, 22) - col) * (glow * 0.55)[:, None]
    lit = smooth(0.0012, -0.0012, feat)
    core = smooth(-0.004, -0.016, eyes)
    fc = phos + (srgb(255, 248, 200) - phos) * core[:, None]
    col = col + (fc - col) * lit[:, None]
    # a glint in each eye (up and to its right), the phosphor's tint
    for sx in (1, -1):
        gd = np.sqrt((u - sx * 0.056 + 0.008) ** 2 + (v - 0.044) ** 2)
        col = col + (srgb(255, 255, 240) - col) * smooth(0.008, 0.005, gd)[:, None]
    # the reflection: a soft band across the upper left of the glass
    refl = smooth(0.03, 0.0, np.abs((u + 0.04) * 0.6 + (v - 0.06) - 0.0)) * smooth(-0.16, -0.06, u) * smooth(0.0, 0.08, v)
    col = col + (srgb(140, 160, 150) - col) * (refl * 0.35)[:, None]
    put(m, col, 0.06)
    c.strp[m, 0] = (v * 2.4)[m]
    c.strp[m, 1] = 0.55

    # the neck: a ribbed rubber bellows
    m = c.mask(NECK)
    put(m, srgb(42, 42, 46) * (0.6 + 0.4 * c.ao)[:, None], 0.6, bump=0.3, grain=1.0)

    # the cardigan: mustard knit, flecked, sun-faded on the shoulders, dirt at the hem and pocket mouths, a darned patch on the left elbow
    for part, base in ((KNIT, (214, 158, 34)), (RIB, (176, 122, 22))):
        m = c.mask(part)
        kn = np.broadcast_to(srgb(*base), (n, 3)).copy()
        kn *= (1.0 + 0.07 * mott)[:, None]
        kn = kn + (srgb(232, 196, 96) - kn) * (smooth(0.92, 1.03, z) * smooth(0.0, 0.1, np.abs(x) - 0.08) * 0.35)[:, None]
        kn = kn * (1.0 - 0.3 * smooth(0.7, 0.63, z) * grime)[:, None]
        kn = kn + (srgb(240, 206, 120) - kn) * (c.wear * 0.25)[:, None]
        put(m, kn, 0.9, bump=1.0)
        spk(m, (138, 88, 18), 0.32)
    # ribbing: fine stripes across each band (hem and collar round the body, cuffs round the arm)
    m = c.mask(RIB)
    Qa = P.copy()
    Qa[:, 0] = np.abs(Qa[:, 0])
    rc = np.where(z > 1.0, np.arctan2(P[:, 0], -(P[:, 1] - 0.022)) * 0.072, np.arctan2(P[:, 0], -(P[:, 1] - 0.005)) * 0.19)
    dcuff = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    e1 = np.cross(dcuff, v3((0, 1, 0)))
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(dcuff, e1)
    qc = Qa - (ELBOW + (WRIST - ELBOW) * CUFF_T)
    cuffs = Qa[:, 0] > 0.215
    rc = np.where(cuffs, np.arctan2(qc @ e2, qc @ e1) * 0.048, rc)
    c.strp[m, 0] = (rc * 4.0)[m]
    c.strp[m, 1] = 1.0
    # the darn: a brown patch on the left elbow's back, stitched round
    m = c.mask(KNIT)
    de = P - (ELBOW + v3((0.012, 0.03, 0.0)))
    pd = np.maximum(np.abs(de[:, 0] * 0.5 + de[:, 1]) - 0.032, np.abs(de[:, 2]) - 0.04)
    patch = m & (x > 0.2) & (pd < 0.0) & (y > 0.0)
    c.col[patch] = (srgb(110, 70, 36) * (1.0 + 0.1 * mott)[:, None])[patch]
    c.strp[patch, 0] = (z * 1.6)[patch]
    c.strp[patch, 1] = 0.8
    edge = m & (x > 0.2) & (y > 0.0) & (np.abs(pd + 0.003) < 0.004)
    c.draw(edge, np.abs(np.sin((de[:, 2] + de[:, 1]) * 900.0)) * 0.002 + np.abs(pd + 0.003), 0.0008, 0.7)
    # pocket mouths and the placket's edges inked faintly
    m = c.mask(RIB)
    m = c.mask(BUTTON)
    put(m, srgb(92, 52, 26) * (1.0 + 0.6 * c.wear)[:, None] * (1.0 - 0.5 * c.cavity)[:, None], 0.4, bump=0.6, grain=1.0)

    # steel: dark gunmetal, chipped bright on the edges, oily dirt in the joints; joints lighter, polished
    m = c.mask(STEEL)
    st = srgb(104, 107, 116) * (1.0 + 0.1 * mott)[:, None]
    st = st + (srgb(176, 176, 182) - st) * (c.wear * 0.5)[:, None]
    st = st * (1.0 - 0.4 * c.cavity)[:, None]
    put(m, st, 0.38 + 0.15 * grime, metal=0.75, bump=0.1, grain=1.0)        # (painted steel, a touch of diffuse: fully metallic it read black on the street)
    spk(m, (60, 44, 30), 0.25)
    m = c.mask(JOINT)
    put(m, srgb(150, 150, 156) * (1.0 - 0.5 * c.cavity)[:, None], 0.28, metal=1.0, bump=0.05, grain=1.0)
    m = c.mask(RUBBER)
    rb = srgb(30, 30, 32) + (srgb(90, 88, 84) - srgb(30, 30, 32)) * (c.wear * 0.6)[:, None]
    rb = rb + (srgb(80, 66, 50) - rb) * (smooth(0.06, 0.0, z) * 0.5)[:, None]
    put(m, rb, 0.75, bump=0.4, grain=1.0)
    m = c.mask(SOLE)
    put(m, srgb(58, 50, 42) * (1.0 + 0.3 * mott)[:, None], 0.9, bump=0.8, grain=1.0)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    scr = c.mask(SCREEN)
    c.col[scr] /= (0.35 + 0.65 * c.ao[scr])[:, None] ** 0.7       # the screen glows: let less of the room's shadow onto it
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"head": 2100, "torso": 3400, "limbs": 3000, "neck": 400, "antennas": 500, "knobs": 600},
    "density": {"head": 2.0, "antennas": 0.8},
    "tex": 2048,
    "stride": {"walk": 0.8, "run": 1.4},
    "speed": 0.85,
    "look": ["head", "ant.L", "ant.R"], "neck": "neck",
    "look_pivot": (0.0, 0.025, 1.14),
    "radius": 0.32,
}
BALL_PT = v3((0.098, 0.02, 0.0))          # under the ankle: the robot sets its boots down flat and lifts them flat (no toe roll)


def rig_bones():
    from kit.rig import Bone, mirror
    hand_end = WRIST - HAND[:, 2] * 0.13
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.01, 0.66), (0, 0.01, 0.76), "root", 0.12),
        Bone("spine", (0, 0.01, 0.76), (0, 0.01, 0.88), "hips", 0.12),
        Bone("chest", (0, 0.01, 0.88), (0, 0.015, 1.0), "spine", 0.14),
        Bone("neck", (0, 0.025, 1.02), (0, 0.025, 1.14), "chest", 0.04),
        Bone("head", (0, 0.025, 1.14), (0, 0.0, 1.45), "neck", 0.18),
        Bone("ant.L", ANT_ROOT, ANT_TIP, "head", 0.02),
        Bone("shoulder.L", (0.06, 0.012, 0.99), SHOULDER, "chest", 0.05),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.05),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.045),
        Bone("hand.L", WRIST, hand_end, "forearm.L", 0.03),
        Bone("thigh.L", HIP, KNEE, "hips", 0.035),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.035),
        Bone("foot.L", ANKLE, (0.10, -0.13, 0.03), "shin.L", 0.04),
    ])


def skin_rules(P, part, piece, names):
    """piece: 0 head (the TV), 1 torso (cardigan, sleeves), 2 limbs (legs, wrists, hands), 3 neck, 4 antennas, 5 knobs"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]
    f = np.array([-1, 1, 1], np.float32)

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    hp = (piece == 0) | (piece == 5)
    allow(hp, "head")
    rig[hp] = ix["head"]
    ap = piece == 4
    allow(ap, "head")
    rig[ap & (x > 0)] = ix["ant.L"]
    rig[ap & (x <= 0)] = ix["ant.R"]
    np_ = piece == 3
    allow(np_, "chest", "neck", "head")
    rig[np_ & (z > 1.13)] = ix["head"]
    rig[np_ & (z < 1.035)] = ix["chest"]
    # the cardigan: the body rides hips, spine, chest; the sleeves their arm
    tp = piece == 1
    torso = tp & (np.abs(x) < 0.215)
    allow(torso, "hips", "spine", "chest")
    allow(torso & (x > 0.17) & (z > 0.9), "shoulder.L", "upper_arm.L")
    allow(torso & (x < -0.17) & (z > 0.9), "shoulder.R", "upper_arm.R")
    sl = tp & ~torso
    allow(sl & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L")
    allow(sl & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R")
    # the limbs: legs by side, the steel wrists and hands rigid on the hand bones (the wrist bar on the forearm)
    lp = piece == 2
    legs = lp & (np.abs(x) < 0.2)
    allow(legs, "hips")
    allow(legs & (x > 0), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x <= 0), "thigh.R", "shin.R", "foot.R")
    rig[legs & (z < 0.03)] = np.where(x[legs & (z < 0.03)] > 0, ix["foot.L"], ix["foot.R"])
    arms = lp & ~legs
    allow(arms & (x > 0), "forearm.L", "hand.L")
    allow(arms & (x <= 0), "forearm.R", "hand.R")
    beyond_l = (P - WRIST) @ (-HAND[:, 2])
    beyond_r = (P - WRIST * f) @ (-HAND[:, 2] * f)
    rig[arms & (x > 0) & (beyond_l > -0.004)] = ix["hand.L"]
    rig[arms & (x <= 0) & (beyond_r > -0.004)] = ix["hand.R"]
    rig[arms & (x > 0) & (beyond_l <= -0.004)] = ix["forearm.L"]
    rig[arms & (x <= 0) & (beyond_r <= -0.004)] = ix["forearm.R"]
    return A, rig


# legs swing nearly straight (0.56 m long): the hips vault high over each planted boot and dip between steps, a toy's up-and-down
WALK = dict(stride=0.8, stance=0.6, foot_x=0.095, lift=0.075, bob=0.03, drop=0.035, sway=0.022, roll=2.0, yaw=3.0, counter=0.6,
            lean=0.0, toe_off=0.0, toe_out=2.0, swing_point=6.0)
RUN = dict(stride=1.4, stance=0.4, foot_x=0.095, lift=0.13, bob=0.03, drop=0.07, sway=0.018, roll=3.0, yaw=5.0, counter=0.8,
           lean=9.0, toe_off=0.0, toe_out=2.0, swing_point=14.0, spine_lean=3.0)


def tick(s, sharp=2.6):
    """a robot's swing: a sine squared toward its ends, so the limb snaps across and holds a moment at each end"""
    import math
    return math.tanh(s * sharp) / math.tanh(sharp)


def motions(rig):
    """walk: a stiff toy stride (legs swing nearly straight, arms stiff with a tick at each end, the TV level, the antennas springing behind);
    run: arms bent and pumping, a forward lean; idle: still as a parked machine, the TV tilting like a curious dog, the antennas wobbling after"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL_PT.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL_PT * f).tolist(), "R")]

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        c = math.cos(TAU * u)
        sw = tick(c, 2.2)
        amp = 30.0 if run else 22.0
        p.rot("shoulder.L", 0, 0, 0)
        p.rot("upper_arm.L", amp * sw, 0, -3.0)
        p.rot("upper_arm.R", -amp * sw, 0, 3.0)
        el = -55.0 if run else -6.0
        p.rot("forearm.L", el, 0, 0)
        p.rot("forearm.R", el, 0, 0)
        # the TV kept level, nodding a touch with each heel strike; the antennas lag the bob
        bob = math.cos(2 * TAU * u)
        p.world["head"] = R((3.0 if run else 0.0) + 1.5 * bob, 0, -2.0 * sw)
        p.rot("neck", 0, 0, 0)
        wob = 7.0 * math.sin(2 * TAU * u - 1.2) * (1.6 if run else 1.0)
        p.rot("ant.L", wob, 0, -wob * 0.6)
        p.rot("ant.R", wob, 0, wob * 0.6)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        hum = 0.002 * math.sin(TAU * t * 2.0)
        stand(rig, p, legs, {"L": (Vector((0.098, 0.02, 0.0)), 3.0), "R": (Vector((-0.098, 0.02, 0.0)), -3.0)},
              hip_shift=(0.0, 0.0, -0.004 + hum), roll=0.0, yaw=0.0)
        # the head tilts: to its left at 1.2 s, holds, snaps back; a quick double-take to the right at 3.2 s; a slow look down at 4.5 s
        tl = ease((t - 1.0) / 0.25) * (1.0 - ease((t - 2.2) / 0.2))
        tr = ease((t - 3.1) / 0.12) * (1.0 - ease((t - 3.5) / 0.12)) + ease((t - 3.7) / 0.12) * (1.0 - ease((t - 4.1) / 0.3))
        dn = ease((t - 4.5) / 0.4) * (1.0 - ease((t - 5.5) / 0.4))
        roll = 14.0 * tl - 11.0 * tr
        pitch = -8.0 * dn + 3.0 * tl
        p.world["head"] = R(pitch, roll, 4.0 * tl - 6.0 * tr)
        # the antennas spring after each move: a damped wobble kicked by the head's speed
        kick = 0.0
        for t0, a in ((1.0, 1.0), (2.2, -0.8), (3.1, -0.7), (3.5, 0.6), (3.7, -0.7), (4.1, 0.5), (4.5, 0.3), (5.5, -0.3)):
            dt = t - t0
            if dt > 0:
                kick += a * math.exp(-dt * 3.2) * math.sin(dt * 18.0)
        p.rot("ant.L", 10.0 * kick, 0, -6.0 * kick)
        p.rot("ant.R", 10.0 * kick, 0, 6.0 * kick)
        sway = 1.2 * math.sin(TAU * t / 6.0)
        p.rot("upper_arm.L", sway, 0, -2.0)
        p.rot("upper_arm.R", -sway, 0, 2.0)
        p.rot("forearm.L", -8.0, 0, 0)
        p.rot("forearm.R", -8.0, 0, 0)
        p.rot("chest", 0, 0, 2.0 * tl - 2.0 * tr)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
