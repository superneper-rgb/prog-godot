## FOINT CITY townsfolk: the mob boss (working name; the user names him). An orange, bumpy, diamond-headed boss: a crest on top, spikes out of his temples, heavy brows, a scowl of huge lips;
# maroon turtleneck under a brown pinstripe three-piece with a pocket square, gold buttons and watch chain, rings, a gold watch, polished shoes. One hand in his pocket, the other at his lapel.
# Concept: the user's sheet, image 3 bottom (F:/prog-godot-cache/folk/refs/3.png). Measured off a 3x crop (1.57 mm a pixel): 1.75 m to the tip of his crest; the head sits in the
# turtleneck at 1.47, eyes 1.615, lips 1.53-1.585, temple spikes 0.24 out at 1.61; broad padded shoulders 0.76 across at 1.40; the jacket to 0.58; trousers turned up at 0.15.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, noise3, v3, basis, place)

HEIGHT = 1.75
REF = ("3.png", (14, 393, 321, 782))

SKIN, EYE, LIP, TEETH, KNIT, SUIT, LINING, GOLD, SHOE, SOLE, SQUARE, DIAL, STONE, NAIL = range(1, 15)
COLOURS = {
    SKIN: ((0.80, 0.38, 0.17), 0.55, 0.0),
    EYE: ((0.85, 0.70, 0.20), 0.2, 0.0),
    LIP: ((0.45, 0.16, 0.18), 0.4, 0.0),
    TEETH: ((0.80, 0.72, 0.50), 0.3, 0.0),
    KNIT: ((0.22, 0.03, 0.05), 0.85, 0.0),
    SUIT: ((0.10, 0.07, 0.07), 0.7, 0.0),
    LINING: ((0.20, 0.03, 0.05), 0.5, 0.0),
    GOLD: ((0.95, 0.68, 0.25), 0.3, 1.0),
    SHOE: ((0.18, 0.06, 0.04), 0.15, 0.0),
    SOLE: ((0.06, 0.04, 0.03), 0.6, 0.0),
    SQUARE: ((0.30, 0.04, 0.07), 0.6, 0.0),
    DIAL: ((0.03, 0.03, 0.04), 0.15, 0.0),
    STONE: ((0.15, 0.15, 0.40), 0.1, 0.0),
    NAIL: ((0.70, 0.40, 0.30), 0.3, 0.0),
}


def _unit(a):
    a = v3(a)
    return a / np.linalg.norm(a)


def bounded(s, lo, hi):
    s.lo, s.hi = v3(lo), v3(hi)
    return s


def _surface_y(shape, x, z, y0=-0.7, y1=0.3):
    ys = np.linspace(y0, y1, 2000, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


def prism(poly_xz, y0=-0.7, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


class Eye:
    """an eye: centre, radii (across, up, deep), where it looks, the lid edges' heights at the front of the ball (fractions of the up radius)"""
    def __init__(self, c, rad, fwd, roll=0.0, lid_up=0.3, lid_lo=0.5, arch=22.0, rim=0.008):
        self.c, self.rad = v3(c), v3(rad)
        self.f = _unit(fwd)
        u = v3((0, 0, 1)) - self.f * self.f[2]
        u /= np.linalg.norm(u)
        s = np.cross(self.f, u)
        a = np.radians(roll)
        self.u = (u * np.cos(a) + s * np.sin(a)).astype(np.float32)
        self.s = np.cross(self.u, self.f).astype(np.float32)
        self.M = np.stack([self.s, self.u, self.f], 1).astype(np.float32)
        self.lid_up, self.lid_lo, self.arch, self.rim = lid_up, lid_lo, np.radians(arch), rim

    def mound(self):
        rs, ru, rf = self.rad
        return Ellipsoid(self.c - self.f * 0.004, (rs + self.rim * 1.3, ru + self.rim * 1.2, rf + self.rim * 0.8), R=self.M, part=SKIN)

    def opening(self):
        c, f, u, a = self.c, self.f, self.u, self.arch
        rs, ru, rf = self.rad
        nu = u * np.cos(a) - f * np.sin(a)
        nl = -u * np.cos(a) - f * np.sin(a)
        front = c + f * rf
        return Clip(Sphere(c + f * rf * 0.6, rs * 1.6), [Half(front + u * self.lid_up * ru, nu), Half(front - u * self.lid_lo * ru, nl), Half(c + f * 0.1 * rf, -f)])

    def ball(self):
        return Ellipsoid(self.c, self.rad, R=self.M, part=EYE)

    def local(self, P):
        return ((P - self.c) @ self.M) / self.rad


# ---------------------------------------------------------------------------------------------------- the head: a rounded diamond, a crest on top, spikes from the temples, a scowl
EYE_L = Eye((0.06, -0.106, 1.616), (0.03, 0.016, 0.02), (0.18, -0.98, 0.0), roll=14.0, lid_up=-0.05, lid_lo=0.45, arch=8.0)   # the scowl: inner corners down
LIP_Z = 1.556


def skull():
    return Union([
        Gem((0, -0.005, 1.60), (0.135, 0.135, 0.12, 0.115, 0.13, 0.13), soft=0.55, edge=0.02),     # the diamond
        Ellipsoid((0, -0.03, 1.53), (0.145, 0.115, 0.08)),                                          # the heavy jaw
        Mirror(Ellipsoid((0.075, -0.075, 1.555), (0.06, 0.05, 0.05))),                              # the muzzle round the mouth
        Mirror(Ellipsoid((0.055, -0.098, 1.637), (0.045, 0.022, 0.016), R=rot(ry=-14))),            # heavy brows, lowered toward the middle
    ], k=0.035, part=SKIN)


def head():
    sk = skull()
    crest = RoundCone((0, 0.0, 1.69), (0.0, 0.01, 1.75), 0.034, 0.004, part=SKIN)
    spikes = Mirror(RoundCone((0.10, 0.01, 1.61), (0.235, 0.085, 1.60), 0.048, 0.005, part=SKIN))      # thick triangular spikes swept back from the temples
    face = Union([sk, crest, spikes, Mirror(EYE_L.mound())], k=0.02)
    face = Cut(face, [Mirror(EYE_L.opening())], k=0.003)
    face = Cut(face, [Mirror(Ellipsoid((0.012, _surface_y(sk, 0.012, 1.6) - 0.002, 1.598), (0.0045, 0.006, 0.0065), R=rot(rx=20)))], k=0.002)    # nostril slits
    # huge lips: a fat upper lip and a fatter, pouting lower lip, pushed forward; a gap between them with crooked teeth
    up, lo = [], []
    for t in np.linspace(-1.0, 1.0, 19):
        x = 0.075 * t
        z = LIP_Z + 0.006 * t * t
        y = _surface_y(sk, x, z)
        up.append((v3((x, y + 0.001 - 0.009 * (1 - t * t), z + 0.012)), 0.0075 + 0.0065 * (1 - t * t)))
        lo.append((v3((x, y - 0.003 - 0.014 * (1 - t * t), z - 0.016)), 0.008 + 0.0095 * (1 - t * t)))
    lips = Union([loft(up, part=LIP, k=0.012), loft(lo, part=LIP, k=0.012)], k=0.006, part=LIP)
    face = Union([face, lips], k=0.016)
    teeth = [Box((x, _surface_y(sk, x, LIP_Z) - 0.012 - 0.006 * (1 - (x / 0.075) ** 2), LIP_Z - 0.001 + 0.002 * ((i % 2) * 2 - 1)), (0.006, 0.004, 0.0065), rr=0.0025, part=TEETH)
             for i, x in enumerate((-0.04, -0.018, 0.006, 0.03, 0.05))]
    gum = loft([(v3((x, _surface_y(sk, x, LIP_Z) - 0.004 - 0.006 * (1 - (x / 0.075) ** 2), LIP_Z + 0.004)), 0.006) for x in np.linspace(-0.05, 0.06, 6)], part=LIP, k=0.005)
    face = Union([face, gum] + teeth, k=0.002)          # the gum ties the teeth together and to the lips (loose islands vanish in decimation)
    # folds from the nose round the mouth, and a sag under the eyes
    for sx in (1.0, -1.0):
        pts = [(v3((sx * (0.035 + 0.05 * t), _surface_y(sk, sx * (0.035 + 0.05 * t), 1.6 - 0.07 * t) - 0.002, 1.6 - 0.07 * t)), 0.003) for t in np.linspace(0, 1, 6)]
        face = Cut(face, [loft(pts, k=0.003)], k=0.004)
    face = Bump(face, lambda P: noise3(P, 0.012) * 0.6 + noise3(P, 0.03) * 0.4, 0.0022)       # his bumpy hide
    neck = RoundCone((0, 0.03, 1.36), (0, 0.0, 1.52), 0.11, 0.115, part=SKIN)
    return Union([Union([neck, face], k=0.03), Mirror(EYE_L.ball())], k=0.0)


# ---------------------------------------------------------------------------------------------------- body: turtleneck, three-piece suit, shoes
def torso_core():
    return Union([
        Ellipsoid((0, -0.005, 1.08), (0.315, 0.235, 0.31)),                     # one barrel, belly to chest (round 2: two stacked bulges read as a bust)
        Ellipsoid((0, 0.04, 1.3), (0.33, 0.17, 0.1)),                           # a broad flat chest
        Ellipsoid((0, 0.04, 1.36), (0.36, 0.17, 0.065)),                        # broad padded shoulders
        Ellipsoid((0, 0.02, 0.82), (0.29, 0.21, 0.12)),
    ], k=0.08)


def suit():
    core = torso_core()
    # the vest: the core in pinstripe, a V at the top showing the turtleneck
    vest = Clip(Inflate(core, 0.008, part=SUIT), [Half((0, 0, 0.78), (0, 0, -1))], k=0.006)
    vest = Cut(vest, [prism([(-0.13, 1.6), (0.13, 1.6), (0.0, 1.16)])], k=0.004)
    knit = Union([Clip(Inflate(core, 0.004, part=KNIT), [prism([(-0.14, 1.6), (0.14, 1.6), (0.0, 1.14)])], k=0.003),
                  Bump(Torus((0, 0.02, 1.46), 0.125, 0.04, part=KNIT), lambda P: np.cos(np.arctan2(P[:, 0], P[:, 1] - 0.02) * 80.0), 0.002),
                  RoundCone((0, 0.03, 1.38), (0, 0.02, 1.5), 0.12, 0.122, part=KNIT)], k=0.02, part=KNIT)
    # the jacket: a thicker layer, open in a deep V above its buttons, long to the hips with flap pockets; lapels folded back along the V
    jcore = Union([core, Ellipsoid((0, 0.02, 0.70), (0.33, 0.25, 0.16))], k=0.08)
    jacket = Clip(Inflate(jcore, 0.016, part=SUIT), [Half((0, 0, 0.58), (0, 0, -1))], k=0.006)       # a thin cloth over the vest, so its fronts don't stand off as two bulbs
    opening = prism([(-0.17, 1.62), (0.17, 1.62), (0.075, 0.96), (0.03, 0.86), (0.06, 0.58), (-0.06, 0.58), (-0.03, 0.86), (-0.075, 0.96)])
    jacket = Cut(jacket, [opening], k=0.006)
    lapel = Clip(Inflate(jcore, 0.022, part=SUIT), [Mirror(prism([(0.17, 1.47), (0.075, 0.96), (0.15, 1.18), (0.17, 1.30), (0.22, 1.32), (0.2, 1.44)]))], k=0.006)    # lying flat on the chest
    collar = bounded(Clip(Cut(Inflate(RoundCone((0, 0.03, 1.36), (0, 0.02, 1.52), 0.13, 0.13), 0.03, part=SUIT), [Inflate(RoundCone((0, 0.03, 1.36), (0, 0.02, 1.52), 0.13, 0.13), 0.012)]),
                          [Half((0, 0, 1.47), (0, 0.3, 1)), Half((0, 0, 1.36), (0, 0, -1)), Half((0, -0.05, 0), (0, -1, -0.3))], k=0.006), (-0.25, -0.2, 1.3), (0.25, 0.25, 1.55))
    flaps = []
    for sx in (1.0, -1.0):
        x0 = 0.2 * sx
        flaps.append(Clip(Inflate(jcore, 0.024, part=SUIT), [prism([(x0 - 0.08, 0.735), (x0 + 0.08, 0.735), (x0 + 0.08, 0.70), (x0 - 0.08, 0.70)])], k=0.003))
    # the breast pocket on his right chest, its maroon square peaking out
    bp = (-0.20, 1.21)
    pocket = Clip(Inflate(jcore, 0.022, part=SUIT), [prism([(bp[0] - 0.06, bp[1] + 0.01), (bp[0] + 0.06, bp[1] + 0.015), (bp[0] + 0.06, bp[1] - 0.005), (bp[0] - 0.06, bp[1] - 0.01)])], k=0.002)
    yq = _surface_y(jcore, bp[0], bp[1]) - 0.016
    square = Union([Gem((bp[0] - 0.02, yq, bp[1] + 0.03), (0.022, 0.022, 0.008, 0.008, 0.02, 0.03), soft=0.2, edge=0.004, part=SQUARE),
                    Gem((bp[0] + 0.02, yq, bp[1] + 0.025), (0.022, 0.022, 0.008, 0.008, 0.02, 0.026), soft=0.2, edge=0.004, part=SQUARE)], k=0.004)
    # gold buttons: two on the jacket, three on the vest; the watch chain looping between the vest's pockets
    buttons = []
    for x, z, lay in ((0.045, 0.84, jcore), (0.045, 0.74, jcore)):
        buttons.append(CappedCone((x, _surface_y(Inflate(lay, 0.016), x, z) + 0.004, z), (x, _surface_y(Inflate(lay, 0.016), x, z) - 0.005, z), 0.012, 0.011, rr=0.003, part=GOLD))
    for z in (1.08, 1.0, 0.92):
        x = 0.045
        y = _surface_y(Inflate(core, 0.008), x, z)
        buttons.append(CappedCone((x, y + 0.003, z), (x, y - 0.004, z), 0.008, 0.0075, rr=0.002, part=GOLD))
    chain = []
    for i, t in enumerate(np.linspace(0, 1, 15)):
        x = 0.05 + 0.07 * t
        z = 1.045 - 0.035 * np.sin(np.pi * t) - 0.04 * t       # from the middle button to the vest pocket, in the jacket's opening
        y = _surface_y(Inflate(core, 0.008), x, z) - 0.004
        chain.append(Torus((x, y, z), 0.0052, 0.0021, Rm=rot(ry=90 * (i % 2), rx=90), part=GOLD))
    return Union([vest, knit, jacket, lapel, collar, pocket, square] + flaps + buttons, k=0.0), Union(chain)


HIP_J = v3((0.158, 0.02, 0.82))
KNEE = v3((0.172, -0.015, 0.45))
ANKLE = v3((0.175, 0.03, 0.095))
TOE = v3((0.18, -0.17, 0.03))


def trousers():
    # the legs clear of each other below the seat: touching legs bake their insides dark, and that shows once they stride apart
    leg = loft([(v3((0.16, 0.015, 0.82)), 0.15), (v3((0.172, -0.005, 0.46)), 0.118), (v3((0.175, 0.01, 0.17)), 0.11)], k=0.05)
    tr = Union([Ellipsoid((0, 0.03, 0.82), (0.29, 0.21, 0.12)), Mirror(leg)], k=0.07, part=SUIT)
    cr = ridge_line((0.172, -0.125, 0.7), (0.175, -0.105, 0.17), 0.012)

    def detail(P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        return cr(Q) * 0.8 + noise3(Q, 0.07) * 0.7 * np.clip((0.6 - Q[:, 2]) / 0.4, 0, 1)
    tr = Bump(tr, detail, 0.004)
    tr = Clip(tr, [Half((0, 0, 0.115), (0, 0, -1)), Half((0, 0, 0.9), (0, 0, 1))], k=0.003)
    cuff = Mirror(Clip(Inflate(loft([(v3((0.175, 0.01, 0.2)), 0.11), (v3((0.175, 0.012, 0.1)), 0.112)]), 0.008, part=SUIT),
                       [Half((0, 0, 0.165), (0, 0, 1)), Half((0, 0, 0.112), (0, 0, -1))], k=0.003))
    pocket_bump = Ellipsoid((-0.27, -0.02, 0.69), (0.05, 0.06, 0.07), part=SUIT)         # his right hand in the pocket
    return Union([Union([tr, pocket_bump], k=0.04, part=SUIT), cuff], k=0.0)


def shoes():
    foot = Union([Ellipsoid((0.175, 0.055, 0.055), (0.058, 0.066, 0.055)), Ellipsoid((0.177, -0.05, 0.052), (0.066, 0.1, 0.05)),
                  Ellipsoid((0.18, -0.15, 0.042), (0.056, 0.075, 0.04))], k=0.03)        # big polished oxfords
    shoe = Clip(Inflate(foot, 0.003, part=SHOE), [Half((0, 0, 0.022), (0, 0, -1))], k=0.003)
    sole = Clip(Inflate(foot, 0.008, part=SOLE), [Half((0, 0, 0.026), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    heel = Box((0.175, 0.06, 0.016), (0.042, 0.035, 0.016), rr=0.005, part=SOLE)
    toecap = Bump(shoe, ridge_line((0.125, -0.12, 0.07), (0.235, -0.12, 0.07), 0.004), -0.0015)
    laces = [Box((0.177, -0.045 + 0.018 * i, 0.093 + 0.004 * i), (0.016, 0.0045, 0.0035), rr=0.0015, part=SOLE) for i in range(3)]
    return Mirror(Union([toecap, sole, heel] + laces, k=0.0))


# ---------------------------------------------------------------------------------------------------- arms (their own piece): the right hand in his trouser pocket, the left gripping his lapel
SHOULDER = v3((0.30, 0.04, 1.32))
ELBOW_L = v3((0.43, 0.06, 1.05))
WRIST_L = v3((0.27, -0.17, 1.22))
GRIP = basis(v3((0.75, 0.25, -0.6)), v3((0.0, 0.3, 1.0)))       # the hand turned in, the fingers up over the lapel's edge, the back of the hand forward
ELBOW_R = v3((-0.43, 0.10, 1.04))
WRIST_R = v3((-0.30, 0.0, 0.76))


def hand_grip():
    """in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): a meaty hand hooking round a lapel, the thumb behind it"""
    palm = Ellipsoid((0.0, 0.0, -0.052), (0.024, 0.046, 0.052), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.042, 0.037, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.031, 0.88), (-0.0105, 1.0), (0.0105, 0.97), (0.031, 0.82)):
        pts = [((0.0, f, -0.094), 0.0135), ((-0.008, f, -0.094 - 0.03 * L), 0.0128), ((-0.026, f, -0.094 - 0.048 * L), 0.0118), ((-0.044, f, -0.094 - 0.045 * L), 0.0108)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.005))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((-0.001, 0, 0.006)), (0.0075, 0.0088, 0.0065), part=NAIL))
    parts.append(loft([(v3((-0.01, -0.036, -0.03)), 0.017), (v3((-0.03, -0.052, -0.062)), 0.0145), (v3((-0.045, -0.046, -0.088)), 0.0125)], part=SKIN, k=0.005))
    ring = Torus(v3((0.0, -0.0105, -0.115)), 0.0155, 0.005, Rm=rot(rx=90), part=GOLD)
    stone = Ellipsoid(v3((0.016, -0.0105, -0.115)), (0.006, 0.009, 0.009), part=STONE)
    return Union([Union(parts, k=0.01), ring, stone])


def sleeve(sh, el, wr, cuff_at):
    d = _unit(wr - el)
    s = loft([(sh + v3((-0.02 * np.sign(sh[0]), 0, 0.03)), 0.1), (sh + (el - sh) * 0.5, 0.098), (el, 0.088), (el + (wr - el) * cuff_at, 0.078)], part=SUIT, k=0.03)
    s = Clip(s, [Half(el + (wr - el) * cuff_at, d)], k=0.004)
    knit = Clip(loft([(el + (wr - el) * (cuff_at - 0.05), 0.068), (el + (wr - el) * (cuff_at + 0.06), 0.062)], part=KNIT), [Half(el + (wr - el) * (cuff_at + 0.06), d)], k=0.003)
    return Union([s, knit], k=0.006)


def arms():
    left = Union([sleeve(SHOULDER, ELBOW_L, WRIST_L, 0.78), loft([(ELBOW_L, 0.06), (WRIST_L, 0.044)], part=SKIN), place(hand_grip(), WRIST_L, GRIP)], k=0.007)
    d = _unit(WRIST_L - ELBOW_L)
    at = WRIST_L - d * 0.035
    Rm = basis(d, v3((0, 0, 1)))
    out = -GRIP[:, 0] * 0.0 + _unit(np.cross(d, v3((0, 0, 1))))
    watch = Union([Torus(at, 0.05, 0.009, Rm=Rm, part=GOLD),
                   CappedCone(at - Rm[:, 1] * 0.05, at - Rm[:, 1] * 0.066, 0.027, 0.025, rr=0.004, part=GOLD),
                   CappedCone(at - Rm[:, 1] * 0.064, at - Rm[:, 1] * 0.068, 0.021, 0.021, rr=0.001, part=DIAL)])
    right = sleeve(SHOULDER * np.array([-1, 1, 1], np.float32), ELBOW_R, WRIST_R, 0.6)
    return Union([left, watch, right])


def pieces():
    s, chain = suit()
    body = Union([s, trousers(), shoes()], k=0.0)
    return [("head", head(), 0.0018), ("body", body, 0.003), ("arms", arms(), 0.003), ("chain", chain, 0.0013)]


# ---------------------------------------------------------------------------------------------------- paint (kit/paint.py fills the shader's layers from these)

def _around(P, a, b, out):
    """angle (radians) of each point round the segment a-b, 0 on the `out` side"""
    ax = _unit(b - a)
    rel = P - a
    rad = rel - np.outer(rel @ ax, ax)
    e1 = out - ax * (out @ ax)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(ax, e1)
    return np.arctan2(rad @ e2, rad @ e1)


def paint(c):
    from kit.paint import srgb, smooth
    P, N = c.P, c.N
    n = len(P)
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    mott = noise3(P, 0.035) * 0.5 + noise3(P, 0.011) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def speck(m, col, amt):
        amt = np.broadcast_to(np.asarray(amt, np.float32), (n,))
        c.spk[m] = np.concatenate([np.broadcast_to(col, (int(m.sum()), 3)), amt[m][:, None]], 1)

    # skin: tangerine, paler on the bumps and the crest, ruddy in the folds, scattered with dark warty spots
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(228, 146, 88), (n, 3)).copy()
    sk = sk + (srgb(244, 184, 128) - sk) * (c.wear * 0.6 + 0.4 * smooth(1.66, 1.75, z))[:, None]
    sk = sk + (srgb(176, 84, 60) - sk) * (c.cavity * 0.7)[:, None]
    sk *= (1.0 + 0.08 * mott)[:, None]
    for sx in (1.0, -1.0):
        PP = P * np.array([sx, 1, 1], np.float32)
        q = EYE_L.local(PP)
        rq = np.linalg.norm(q, axis=1)
        dball = (rq - 1.0) * float(EYE_L.rad[1])
        side = m & (PP[:, 0] > 0) & (rq < 2.2) & (q[:, 2] > -0.2)
        sk = np.where((side & (q[:, 1] < 0))[:, None], sk * (1.0 - 0.25 * smooth(0.02, 0.0, dball))[:, None], sk)
        c.draw(side & (q[:, 1] > -0.3) & (dball < 0.006), np.abs(dball), 0.0018, 0.95)
    put(m, sk, 0.5, bump=0.3)
    speck(m, srgb(120, 54, 36), np.where(z > 1.4, 0.45, 0.35))
    # eyes: sulphur yellow, a narrow dark pupil, looking down his nose
    m = c.mask(EYE)
    for sx in (1.0, -1.0):
        PP = P * np.array([sx, 1, 1], np.float32)
        q = EYE_L.local(PP)
        qn = q / np.maximum(np.linalg.norm(q, axis=1), 1e-6)[:, None]
        mine = m & (PP[:, 0] > 0)
        col = srgb(226, 196, 74) * (1.0 - 0.4 * smooth(-0.2, 0.6, qn[:, 1]))[:, None]
        c.col[mine] = col[mine]
        g = _unit((-0.12 * sx * 0 - 0.1, -0.1, 0.98))
        ang = np.arccos(np.clip(qn @ g, -1, 1))
        c.draw(mine, np.maximum(np.abs(qn @ _unit(np.cross(g, v3((0, 1, 0))))) * 0.03 - 0.0015, (ang - 0.45) * 0.03), 0.0)
    c.rough[m] = 0.1
    # the lips: dusky mauve, the lower pout catching the light; yellowed teeth
    m = c.mask(LIP)
    put(m, np.where((z < LIP_Z)[:, None], srgb(196, 112, 120), srgb(160, 82, 94)) * (1.0 + 0.4 * c.wear - 0.3 * c.cavity)[:, None], 0.3)
    put(c.mask(TEETH), srgb(226, 206, 150) * (1.0 - 0.5 * c.cavity)[:, None], 0.35)
    put(c.mask(NAIL), srgb(236, 176, 130), 0.3)
    # the turtleneck: maroon rib knit
    m = c.mask(KNIT)
    put(m, srgb(116, 30, 42) * (1.0 + 0.06 * mott + 0.3 * c.wear - 0.3 * c.cavity)[:, None], 0.85, bump=1.0)
    # the suit: dark brown-grey wool with copper pinstripes running down the body, the legs and the sleeves
    m = c.mask(SUIT)
    su = np.broadcast_to(srgb(84, 66, 64), (n, 3)) * (1.0 + 0.08 * mott + 0.3 * c.wear - 0.2 * c.cavity)[:, None]
    u = np.arctan2(x, -(y - 0.02)) * 0.28                                   # round the trunk
    for sx in (1.0, -1.0):
        legm = (z < 0.78) & ((x > 0) == (sx > 0))
        ul = _around(P, v3((0.16 * sx, 0.015, 0.82)), v3((0.175 * sx, 0.01, 0.15)), v3((0, -1, 0))) * 0.13
        u = np.where(legm, ul, u)
    for a_, b_ in ((SHOULDER, ELBOW_L), (ELBOW_L, WRIST_L), (SHOULDER * np.array([-1, 1, 1], np.float32), ELBOW_R), (ELBOW_R, WRIST_R)):
        ab = b_ - a_
        t = ((P - a_) @ ab) / (ab @ ab)
        d = np.linalg.norm(P - a_ - np.outer(np.clip(t, 0, 1), ab), axis=1)
        arm = (t > -0.1) & (t < 1.05) & (d < 0.13) & ((x > 0) == (a_[0] > 0)) & (Q[:, 0] > 0.25)
        u = np.where(arm, _around(P, a_, b_, v3((0, -1, 0))) * 0.1, u)
    sd = np.abs((u / 0.038) - np.round(u / 0.038)) * 0.038
    su = su + (srgb(206, 126, 66) - su) * smooth(0.0028, 0.0012, sd)[:, None]
    put(m, su, 0.75, bump=1.0)
    speck(m, srgb(120, 80, 60), 0.15)
    put(c.mask(SQUARE), srgb(128, 30, 46) * (1.0 + 0.4 * c.wear)[:, None], 0.5, bump=0.6)
    put(c.mask(GOLD), srgb(240, 186, 86) * (1.0 - 0.4 * c.cavity)[:, None], 0.22, metal=1.0, bump=0.05, grain=1.0)
    put(c.mask(STONE), srgb(52, 56, 120), 0.08)
    m = c.mask(DIAL)
    put(m, srgb(26, 26, 34), 0.12)
    put(c.mask(SHOE), srgb(70, 36, 28) * (1.0 + 1.5 * c.wear)[:, None], 0.1, bump=0.15, grain=1.0)
    put(c.mask(SOLE), srgb(40, 26, 22), 0.6, bump=0.3, grain=1.0)

    ao = np.where(c.mask(SUIT) & (z < 0.6), 0.6 + 0.4 * c.ao, 0.3 + 0.7 * c.ao)     # lighter between the legs: those insides show in the stride
    c.col *= ao[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2500, "body": 4600, "arms": 1700, "chain": 400},
    "density": {"head": 1.8, "arms": 1.1, "chain": 0.5},
    "tex": 2048,
    "stride": {"walk": 0.8, "run": 1.4},
    "speed": 0.7,
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.02, 1.5),
    "radius": 0.46,
}
BALL = v3((0.18, -0.15, 0.0))            # the shoe rolls near its toe: a pivot further back sinks the toe into the floor
STANCE_Y = 0.125         # his hips only 3 cm ahead of mid-stance: he leans back as he swaggers


def rig_bones():
    from kit.rig import Bone, mirror
    fr = np.array([-1, 1, 1], np.float32)
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.02, 0.82), (0, 0.02, 1.0), "root", 0.24),
        Bone("spine", (0, 0.02, 1.0), (0, 0.02, 1.18), "hips", 0.26),
        Bone("chest", (0, 0.02, 1.18), (0, 0.03, 1.38), "spine", 0.24),
        Bone("neck", (0, 0.03, 1.38), (0, 0.02, 1.50), "chest", 0.12),
        Bone("head", (0, 0.02, 1.50), (0, 0.0, 1.75), "neck", 0.13),
        Bone("shoulder.L", (0.08, 0.04, 1.36), SHOULDER, "chest", 0.08),
        Bone("thigh.L", HIP_J, KNEE, "hips", 0.15),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.11),
        Bone("foot.L", ANKLE, TOE, "shin.L", 0.05),
    ])
    bones += [
        Bone("upper_arm.L", SHOULDER, ELBOW_L, "shoulder.L", 0.09),
        Bone("forearm.L", ELBOW_L, WRIST_L, "upper_arm.L", 0.07),
        Bone("hand.L", WRIST_L, WRIST_L - GRIP[:, 2] * 0.13, "forearm.L", 0.045),
        Bone("upper_arm.R", SHOULDER * fr, ELBOW_R, "shoulder.R", 0.09),
        Bone("forearm.R", ELBOW_R, WRIST_R, "upper_arm.R", 0.07),
        Bone("hand.R", WRIST_R, WRIST_R + v3((0.0, -0.02, -0.08)), "forearm.R", 0.03),       # in the pocket, unweighted: the end the pocket IK aims
    ]
    return bones


def skin_rules(P, part, piece, names):
    """piece: 0 head, 1 body, 2 arms, 3 chain"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 1.5)] = ix["head"]
    rig[piece == 3] = ix["spine"]
    allow(piece == 3, "spine")
    bp = piece == 1
    legs = bp & (((part == SUIT) & (z < 0.6)) | np.isin(part, (SHOE, SOLE)) | (z < 0.3))
    allow(legs, "hips")
    allow(legs & (x > -0.05), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.05), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.2) & (z > 1.2), "shoulder.L")
    allow(torso & (x < -0.2) & (z > 1.2), "shoulder.R")
    rig[torso & (part == GOLD) & (z > 0.7)] = ix["spine"]
    ap = piece == 2
    allow(ap & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(ap & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R")
    allow(ap & (z > 1.24) & (np.abs(x) < 0.33), "chest")
    rig[ap & np.isin(part, (GOLD, DIAL, STONE)) & (x > 0)] = ix["forearm.L"]
    ring = ap & np.isin(part, (GOLD, STONE)) & (x > 0) & (np.linalg.norm(P - (WRIST_L + GRIP @ v3((0.0, -0.0105, -0.115))), axis=1) < 0.03)
    rig[ring] = ix["hand.L"]
    return A, rig


WALK = dict(stride=0.8, stance=0.62, foot_x=0.17, lift=0.05, bob=0.015, drop=0.04, sway=0.04, roll=5.0, yaw=11.0, counter=1.7,
            lean=-3.0, toe_off=10.0, toe_out=14.0, swing_point=6.0, spine_lean=-2.0)
RUN = dict(stride=1.4, stance=0.42, foot_x=0.15, lift=0.1, bob=0.035, drop=0.1, sway=0.03, roll=4.0, yaw=10.0, counter=1.5,
           lean=6.0, toe_off=14.0, toe_out=10.0, swing_point=10.0, spine_lean=0.0)


def motions(rig):
    """walk: a slow wide swagger (feet turned out and planted wide, the big shoulders rolling hard against the hips, leaning back, chin up,
    the left hand holding his lapel, the right hand riding in his pocket); run: a heavy trot; idle: a tug at the lapel, a roll of the neck,
    a long look round with his chin up"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    hip_head = Vector(rig.head["hips"])
    sh_r, el_r, wr_r = Vector((SHOULDER * f).tolist()), Vector(ELBOW_R.tolist()), Vector(WRIST_R.tolist())
    line = (wr_r - sh_r).normalized()
    pole_r = ((el_r - sh_r) - line * (el_r - sh_r).dot(line)).normalized()

    def pocket(p):
        Rh = p.delta.get("hips", Matrix.Identity(3))
        tgt = p.offset + hip_head + Rh @ (wr_r - hip_head)
        p.ik["upper_arm.R"] = (tgt, pole_r, "hand.R", None)

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.offset = p.offset + Vector((0.0, STANCE_Y, 0.0))
        s1, c1 = math.sin(TAU * u), math.cos(TAU * u)
        p.rot("chest", 0, 2.5 * s1, 0)
        p.rot("upper_arm.L", 3.0 * c1, 0, 0)
        pocket(p)
        p.rot("neck", -4.0, 0, 0)
        p.world["head"] = R(-5.0 + 1.0 * math.sin(2 * TAU * u), 0, -5.0 * c1)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        b = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector(BALL.tolist()), 14.0), "R": (Vector((BALL * f).tolist()), -14.0)},
              hip_shift=(0.02 * w, 0.0, -0.016), roll=-2.0 * w, yaw=2.0 * w)
        p.rot("spine", -2.0 + 1.5 * b, 0, 0)
        p.rot("chest", 1.2 * b, 1.0 * w, 2.0 * w)
        tug = math.sin(math.pi * min(1.0, max(0.0, (t - 0.8) / 0.5))) * 0.8 + math.sin(math.pi * min(1.0, max(0.0, (t - 1.25) / 0.4))) * 0.6
        p.rot("upper_arm.L", 0, 0, -6.0 * tug)
        p.rot("forearm.L", 10.0 * tug, 0, 0)
        p.rot("shoulder.L", 0, -3.0 * tug, 0)
        pocket(p)
        roll = ease((t - 2.2) / 0.5) * (1.0 - ease((t - 3.4) / 0.6))
        look = ease((t - 3.6) / 0.8) * (1.0 - ease((t - 5.3) / 0.6)) * 25.0
        p.world["head"] = R(-6.0 + 1.0 * b, 9.0 * roll * math.sin(TAU * (t - 2.2) / 1.2), look - 4.0 * tug)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
