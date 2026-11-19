## FOINT CITY townsfolk: the vegetable granny (working name; the user names her). Short, stout mint-green granny: three big eyes on top of her toad-wide head gazing up, a plum braided bun, gold hoops; flowered blouse, maroon apron, olive balloon trousers.
# Concept: the user's sheet, image 1 top (F:/prog-godot-cache/folk/refs/1.png). Measured off a 3x crop (1.26 mm a pixel): 1.35 m to the top of the bun; the head 0.38 wide and 0.27 tall,
# tipped back so her three eyes (each 0.11 across) look up; the smile 6 cm under the lower eyes, a round chin pad under it; shoulders 0.98, waist tie 0.70, the blouse
# flares out round her hips to 0.43, the apron hem 0.31, balloon trousers gathered at 0.11. The vegetable crate is dropped (roster): her arms hang free beside her round body.
# The arms are their own piece so they can rest against that body without the mesher fusing them.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, noise3, v3, basis, place)

HEIGHT = 1.35
REF = ("1.png", (75, 6, 364, 378))

SKIN, EYE, LIP, HAIR, BAND, GOLD, BLOUSE, APRON, TOWEL, TROUSERS, SHOE, SOLE, NAIL, PEN, PENCIL, POCKET = range(1, 17)
COLOURS = {
    SKIN: ((0.34, 0.56, 0.42), 0.55, 0.0),
    EYE: ((0.86, 0.74, 0.58), 0.2, 0.0),
    LIP: ((0.50, 0.14, 0.16), 0.4, 0.0),
    HAIR: ((0.22, 0.05, 0.14), 0.6, 0.0),
    BAND: ((0.80, 0.45, 0.10), 0.5, 0.0),
    GOLD: ((0.95, 0.68, 0.25), 0.3, 1.0),
    BLOUSE: ((0.88, 0.70, 0.58), 0.8, 0.0),
    APRON: ((0.30, 0.05, 0.08), 0.8, 0.0),
    POCKET: ((0.36, 0.07, 0.10), 0.8, 0.0),
    TOWEL: ((0.86, 0.80, 0.70), 0.85, 0.0),
    TROUSERS: ((0.30, 0.27, 0.10), 0.85, 0.0),
    SHOE: ((0.28, 0.08, 0.06), 0.4, 0.0),
    SOLE: ((0.45, 0.30, 0.22), 0.6, 0.0),
    NAIL: ((0.70, 0.36, 0.34), 0.3, 0.0),
    PEN: ((0.20, 0.30, 0.55), 0.3, 0.0),
    PENCIL: ((0.90, 0.62, 0.10), 0.5, 0.0),
}


def _unit(a):
    a = v3(a)
    return a / np.linalg.norm(a)


def bounded(s, lo, hi):
    """narrow a shape's bound (a clipped garment layer is far smaller than the body it was grown from): unions then skip it everywhere else"""
    s.lo, s.hi = v3(lo), v3(hi)
    return s


def _surface_y(shape, x, z, y0=-0.5, y1=0.2):
    """where the shape's front surface is at (x, z), marching back from the front"""
    ys = np.linspace(y0, y1, 1400, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


# ---------------------------------------------------------------------------------------------------- the head, built upright and tipped back about PIV
TILT = 21.0
PIV = v3((0.0, 0.03, 1.01))
TILT_R = rot(rx=-TILT)          # face turned up


def tilt(s):
    return Move(s, R=TILT_R, pivot=PIV)


def untilt(P):
    """world points back into the upright head's frame"""
    return ((P - PIV) @ TILT_R + PIV).astype(np.float32)


class Eye:
    """one eye in the upright head: centre, radii (across, up, deep), where it looks, the lid edges' heights at the front of the ball (fractions of the up radius)"""
    def __init__(self, c, rad, fwd, roll=0.0, lid_up=0.3, lid_lo=0.5, arch=22.0, rim=0.016):
        self.c, self.rad = v3(c), v3(rad)
        self.f = _unit(fwd)
        u = v3((0, 0, 1)) - self.f * self.f[2]
        u /= np.linalg.norm(u)
        s = np.cross(self.f, u)
        a = np.radians(roll)
        self.u = (u * np.cos(a) + s * np.sin(a)).astype(np.float32)
        self.s = np.cross(self.u, self.f).astype(np.float32)          # toward the figure's left for an eye looking at -Y
        self.M = np.stack([self.s, self.u, self.f], 1).astype(np.float32)
        self.lid_up, self.lid_lo, self.arch, self.rim = lid_up, lid_lo, np.radians(arch), rim

    def mound(self):
        """the thick rolled lids the eyeball sits in: a shell a rim larger than the ball, its opening cut below"""
        rs, ru, rf = self.rad
        return Ellipsoid(self.c - self.f * 0.008, (rs + self.rim * 1.2, ru + self.rim, rf + self.rim * 0.85), R=self.M, part=SKIN)

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
        """points in the eye's own frame, scaled so the ball is the unit sphere"""
        return ((P - self.c) @ self.M) / self.rad


# the three eyes, wide lens shapes packed into one brow mass: one on top in the middle, two below at the front corners (the left one here; the right mirrors it)
EYE_TOP = Eye((0.0, -0.13, 1.262), (0.054, 0.037, 0.044), (0.0, -0.985, 0.17), lid_up=0.36, lid_lo=0.42, arch=14.0)
EYE_SIDE = Eye((0.10, -0.137, 1.19), (0.056, 0.038, 0.046), (0.10, -0.99, 0.05), roll=-6.0, lid_up=0.36, lid_lo=0.48, arch=14.0)
MOUTH_Z = 1.137                 # the middle of the smile (upright frame), just under the lower lids; the corners rise into the cheeks
MOUTH_RISE = 0.022
CHIN = v3((0.0, 0.0, 1.074))


def skull():
    return Union([
        Ellipsoid((0, 0.03, 1.165), (0.175, 0.155, 0.115)),              # the wide crown, lower than the eyes' brow
        Ellipsoid((0, -0.03, 1.12), (0.192, 0.130, 0.100)),               # the broad lower face
        Mirror(Ellipsoid((0.13, -0.055, 1.10), (0.09, 0.086, 0.07))),   # jowls
        Ellipsoid((0, -0.05, 1.04), (0.115, 0.088, 0.068)),               # under the jaw, into the neck
    ], k=0.05, part=SKIN)


def head_upright():
    sk = skull()
    face = Union([sk, Mirror(EYE_SIDE.mound()), EYE_TOP.mound()], k=0.028)
    face = Cut(face, [Mirror(EYE_SIDE.opening()), EYE_TOP.opening()], k=0.007)
    # the chin pad under the smile: a soft round bump
    yc = _surface_y(sk, 0.0, CHIN[2])
    chin = Ellipsoid((0, yc + 0.009, CHIN[2] + 0.004), (0.04, 0.017, 0.026), part=SKIN)
    # ears: small rounded shells low on the sides of the head, the hollow facing out and forward
    ear = Union([Ellipsoid((0.19, 0.04, 1.088), (0.013, 0.021, 0.033), R=rot(rx=-12, rz=-25), part=SKIN),
                 Ellipsoid((0.188, 0.045, 1.062), (0.012, 0.014, 0.014), part=SKIN)], k=0.008)
    ear = Cut(ear, [Ellipsoid((0.2, 0.034, 1.094), (0.006, 0.012, 0.019), R=rot(rx=-12, rz=-25))], k=0.004)
    face = Union([face, chin, Mirror(ear)], k=0.014)
    # the smile: a thin upper lip, a fuller lower lip, along a curve rising into the cheeks; a parting cut between; dimples at the corners
    up, lo, cut = [], [], []
    for t in np.linspace(-1.0, 1.0, 25):
        x = 0.088 * t
        z = MOUTH_Z + MOUTH_RISE * t * t
        y = _surface_y(sk, x, z)
        up.append((v3((x, y + 0.003, z + 0.004)), 0.0032 * (1.0 - 0.5 * t * t) + 0.0018))
        cut.append((v3((x, y - 0.0035, z - 0.0005)), 0.0028))
        if abs(t) <= 0.84:
            lo.append((v3((x, y + 0.0042, z - 0.0072)), 0.0055 * (1.0 - 0.8 * t * t) + 0.002))
    lips = Union([loft(up, part=LIP, k=0.01), loft(lo, part=LIP, k=0.01)], k=0.004, part=LIP)
    face = Union([face, lips], k=0.005)
    face = Cut(face, [loft(cut, k=0.004)], k=0.002)
    for sx in (1.0, -1.0):
        x = 0.091 * sx
        z = MOUTH_Z + MOUTH_RISE + 0.002
        face = Cut(face, [Sphere((x, _surface_y(sk, x, z) - 0.001, z), 0.0055)], k=0.005)
    # nostrils: two small slits under the brow (no nose to speak of: a toad's face)
    for sx in (1.0, -1.0):
        x, z = 0.016 * sx, 1.172
        face = Cut(face, [Ellipsoid((x, _surface_y(sk, x, z) - 0.002, z), (0.0035, 0.006, 0.0055), R=rot(rx=30, rz=25 * sx))], k=0.002)
    balls = Union([Mirror(EYE_SIDE.ball()), EYE_TOP.ball()])
    return Union([face, balls], k=0.0)


def head():
    neck = RoundCone((0, 0.045, 0.88), (0, 0.01, 1.04), 0.095, 0.11, part=SKIN)
    return Union([neck, tilt(head_upright())], k=0.035)


# ---------------------------------------------------------------------------------------------------- hair: a cap combed back, a striped band, the braided bun

CROWN = Ellipsoid((0, 0.03, 1.165), (0.175, 0.155, 0.115))
HAIR_N = _unit((0.0, -1.0, -0.62))          # the band runs across the crown along this plane, behind the hairline
HAIR_PT = v3((0.0, -0.06, 1.24))
HAIR_ZONE = Ellipsoid((0.0, 0.10, 1.20), (0.235, 0.215, 0.20))   # the hair grows inside this: a hairline curving from behind the top eye down behind the ears
BUN_C = v3((0.0, 0.13, 1.255))
BUN_AX = _unit((0.0, 0.85, 0.53))


def hair():
    cap = Clip(Inflate(CROWN, 0.026, part=HAIR), [HAIR_ZONE, Half((0, 0, 1.085), (0, 0.45, -1.0))], k=0.025)

    def grooves(P):
        a = np.arctan2(P[:, 0], P[:, 2] - 1.02)
        return (0.5 + 0.5 * np.cos(a * 34.0)) ** 2
    cap = Bump(cap, grooves, -0.003)
    band = Clip(Inflate(CROWN, 0.026, part=BAND), [Half(HAIR_PT - HAIR_N * 0.040, -HAIR_N), Half(HAIR_PT - HAIR_N * 0.021, HAIR_N), Inflate(HAIR_ZONE, -0.015), Half((0, 0, 1.09), (0, 0, -1.0))], k=0.004)
    # the bun: a thick two-strand braid coiled two and a half times, stacking out from the back of the head
    ax = BUN_AX
    e1 = _unit(np.cross(ax, v3((1, 0, 0))))
    e2 = np.cross(ax, e1)
    path = []
    n = 56
    for i in range(n + 1):
        t = i / n
        a = t * np.pi * 2 * 2.4
        R = 0.092 - 0.052 * t
        h = 0.0 + 0.075 * t
        path.append(BUN_C + ax * h + (e1 * np.cos(a) + e2 * np.sin(a)) * R)
    strands = []
    for ph in (0.0, np.pi):
        pts = []
        for i, p in enumerate(path):
            t = i / n
            tg = path[min(i + 1, n)] - path[max(i - 1, 0)]
            tg /= np.linalg.norm(tg)
            nn = _unit(np.cross(tg, ax))
            bb = np.cross(tg, nn)
            w = ph + t * np.pi * 2 * 15
            rr = 0.021 - 0.006 * t
            pts.append((p + (nn * np.cos(w) + bb * np.sin(w)) * rr * 0.55, rr))
        strands.append(loft(pts, part=HAIR, k=0.005))
    core = Ellipsoid(BUN_C + ax * 0.02, (0.09, 0.09, 0.06), R=np.stack([e1, e2, ax], 1), part=HAIR)
    bun = Union([core] + strands, k=0.006, part=HAIR)
    return tilt(Union([cap, band, bun], k=0.004))


EAR_RING = v3((0.198, 0.035, 1.03))


def jewels():
    ring = Torus(EAR_RING, 0.026, 0.0052, Rm=rot(ry=90), part=GOLD)
    return tilt(Mirror(ring))


# ---------------------------------------------------------------------------------------------------- body: blouse, apron, towel, trousers, shoes

BELLY = Ellipsoid((0, -0.005, 0.665), (0.255, 0.195, 0.135))


def torso_core():
    """the blouse over her round body"""
    return Union([
        Ellipsoid((0, 0.03, 0.85), (0.215, 0.16, 0.135)),
        Ellipsoid((0, 0.04, 0.93), (0.225, 0.13, 0.062)),
        Mirror(Ellipsoid((0.092, -0.085, 0.80), (0.095, 0.085, 0.082))),
        BELLY,
        Ellipsoid((0, 0.04, 0.53), (0.30, 0.225, 0.13)),
    ], k=0.07, part=BLOUSE)


def prism(poly_xz, y0=-0.6, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from the front (y0) to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def skirt_core():
    """what the apron's skirt hangs from: the belly, then a curtain falling nearly straight and flaring a little to the hem"""
    return Union([
        BELLY,
        Ellipsoid((0, 0.0, 0.40), (0.30, 0.225, 0.40)),      # widest at the hem: the apron falls straight and flares a little
    ], k=0.06)


def blouse():
    core = torso_core()
    # the hem flares out round her hips and seat, widest behind (the apron covers the front)
    flare = Clip(Ellipsoid((0, 0.06, 0.505), (0.355, 0.265, 0.13), part=BLOUSE), [Half((0, 0, 0.425), (0, 0, -1.0))], k=0.012)
    shell = Union([core, flare], k=0.06, part=BLOUSE)
    # the collar: a pointed flap lying on the shoulders round the neck, a raised layer of the blouse (a floating flap thinner than four voxels
    # leaves non-manifold edges that wreck the game model's decimation)
    collar = Clip(Inflate(core, 0.017, part=BLOUSE),
                  [Mirror(prism([(0.0, 0.905), (0.095, 0.99), (0.15, 0.982), (0.112, 0.93), (0.075, 0.855)], y0=-0.6, y1=0.09))], k=0.005)
    collar = bounded(collar, (-0.2, -0.3, 0.82), (0.2, 0.15, 1.02))
    return Union([shell, collar], k=0.0)


def apron():
    core = torso_core()
    sc = skirt_core()
    bib = bounded(Clip(Inflate(core, 0.009, part=APRON), [prism([(-0.13, 0.70), (0.13, 0.70), (0.12, 0.935), (-0.12, 0.935)])], k=0.004),
                  (-0.16, -0.32, 0.66), (0.16, 0.05, 0.98))
    straps = bounded(Mirror(Clip(Inflate(core, 0.008, part=APRON), [Half((0.094, 0, 0), (-1, 0, 0)), Half((0.132, 0, 0), (1, 0, 0)), Half((0, 0, 0.88), (0, 0, -1))], k=0.003)),
                     (-0.16, -0.25, 0.85), (0.16, 0.25, 1.01))
    skirt = bounded(Clip(Inflate(sc, 0.011, part=APRON), [Half((0, 0, 0.70), (0, 0, 1)), Half((0, 0, 0.31), (0, 0, -1)), Half((0, 0.03, 0), (0, 1, 0))], k=0.006),
                    (-0.33, -0.27, 0.29), (0.33, 0.06, 0.72))
    tie = bounded(Clip(Inflate(core, 0.014, part=APRON), [Half((0, 0, 0.722), (0, 0, 1)), Half((0, 0, 0.688), (0, 0, -1))], k=0.003),
                  (-0.3, -0.25, 0.67), (0.3, 0.25, 0.74))
    # the bow at the back: two loops and two tails
    yb = _surface_y(Move(core, R=rot(rz=180)), 0.0, 0.705) * -1.0 + 0.01
    bow = Union([
        Mirror(Ellipsoid((0.045, yb, 0.708), (0.042, 0.013, 0.024), R=rot(ry=-15), part=APRON)),
        Mirror(Box((0.028, yb - 0.004, 0.632), (0.016, 0.0068, 0.062), rr=0.005, R=rot(ry=-12), part=APRON)),
        Sphere((0, yb + 0.002, 0.706), 0.015, part=APRON),
    ], k=0.006)
    # patch pockets, a layer standing off the skirt, their mouths cut open
    pk = Mirror(prism([(0.035, 0.59), (0.205, 0.59), (0.21, 0.45), (0.195, 0.43), (0.045, 0.43), (0.03, 0.45)]))
    pocket = Clip(Inflate(sc, 0.021, part=POCKET), [pk, Half((0, 0, 0.70), (0, 0, 1))], k=0.004)
    mouth = Mirror(Box((0.12, -0.25, 0.597), (0.083, 0.06, 0.012), rr=0.004))
    pocket = bounded(Cut(pocket, [Cut(mouth, [Inflate(sc, 0.0135)])], k=0.002), (-0.25, -0.30, 0.40), (0.25, -0.05, 0.62))    # a step, never a wall thinner than four voxels
    return Union([bib, straps, skirt, tie, bow, pocket], k=0.004)


def towel():
    """the tea towel tucked into the apron's waist on her right, folded over the tie and hanging to her thigh"""
    sc = skirt_core()
    out = prism([(-0.27, 0.715), (-0.185, 0.715), (-0.18, 0.43), (-0.2, 0.418), (-0.25, 0.422), (-0.274, 0.44)])
    sheet = Clip(Cut(Inflate(sc, 0.038, part=TOWEL), [Inflate(sc, 0.022)], k=0.002), [out], k=0.005)

    def folds(P):
        return np.cos((P[:, 0] + 0.23) * 135.0 + np.sin(P[:, 2] * 22.0) * 1.2) * np.clip((0.70 - P[:, 2]) / 0.2, 0, 1)
    sheet = Bump(sheet, folds, 0.004)
    lip = Clip(Inflate(BELLY, 0.03, part=TOWEL), [prism([(-0.275, 0.738), (-0.18, 0.738), (-0.18, 0.688), (-0.275, 0.688)])], k=0.006)
    return bounded(Union([sheet, lip], k=0.008), (-0.34, -0.32, 0.38), (-0.10, 0.1, 0.78))


def pens():
    sc = skirt_core()
    out = []
    # her right pocket: a blue pen; her left: two pens and a yellow pencil
    for x, z1, part, r, tilt_deg in ((-0.10, 0.65, PEN, 0.0055, 6), (0.09, 0.64, PEN, 0.005, -8), (0.12, 0.655, PENCIL, 0.0058, 10), (0.155, 0.63, PEN, 0.005, 14)):
        y = _surface_y(sc, x, 0.56, -0.5, 0.2) - 0.009
        a = v3((x, y, 0.55))
        b = v3((x + np.sin(np.radians(tilt_deg)) * (z1 - 0.55), y - 0.004, z1))
        out.append(RoundCone(a, b, r, r * 0.9, part=part))
        out.append(Sphere(b, r * 1.05, part=GOLD if part == PEN else SKIN))
    return Union(out)


HIP_J = v3((0.13, 0.02, 0.45))
KNEE = v3((0.16, -0.02, 0.26))
ANKLE = v3((0.168, 0.025, 0.075))
TOE = v3((0.178, -0.14, 0.03))


def legs():
    seat = Ellipsoid((0, 0.04, 0.43), (0.29, 0.21, 0.13))
    leg = loft([(v3((0.13, 0.015, 0.42)), 0.15), (v3((0.168, -0.005, 0.25)), 0.158), (v3((0.168, 0.005, 0.14)), 0.09), (v3((0.168, 0.012, 0.112)), 0.066)], k=0.045)
    tr = Union([seat, Mirror(leg)], k=0.06, part=TROUSERS)

    def gathers(P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        a = np.arctan2(Q[:, 1] - 0.005, Q[:, 0] - 0.168)
        low = np.clip((0.27 - Q[:, 2]) / 0.13, 0.0, 1.0)
        n = noise3(Q, 0.05)
        return np.cos(a * 9.0 + n * 1.5) * low * low + 0.5 * n * (1.0 - low)
    tr = Bump(tr, gathers, 0.0065)
    tr = Clip(tr, [Half((0, 0, 0.104), (0, 0, -1))], k=0.003)
    cuff = Mirror(Torus((0.168, 0.012, 0.112), 0.06, 0.012, part=TROUSERS))
    ankle = RoundCone((0.168, 0.02, 0.14), (0.168, 0.025, 0.06), 0.037, 0.035, part=SKIN)
    foot = Union([Ellipsoid((0.168, 0.04, 0.036), (0.04, 0.05, 0.036)), Ellipsoid((0.171, -0.035, 0.033), (0.05, 0.065, 0.033)),
                  Ellipsoid((0.176, -0.10, 0.027), (0.046, 0.058, 0.027))], k=0.03, part=SKIN)
    shell = Inflate(foot, 0.007, part=SHOE)
    # a low leather flat: toes and sides covered, a low opening round the ankle that shows the top of her foot
    shoe = Clip(shell, [Half((0, 0, 0.05), (0.0, 0.35, 1.0)), Half((0, 0, 0.012), (0, 0, -1))], k=0.004)
    sole = Clip(Inflate(foot, 0.0105, part=SOLE), [Half((0, 0, 0.015), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    heel = Box((0.168, 0.05, 0.013), (0.038, 0.034, 0.013), rr=0.006, part=SOLE)
    return Union([tr, cuff, Mirror(Union([ankle, foot, shoe, sole, heel], k=0.0))], k=0.0)


# ---------------------------------------------------------------------------------------------------- arms (their own piece)
SHOULDER = v3((0.225, 0.035, 0.915))
ELBOW = v3((0.325, 0.03, 0.71))
WRIST = v3((0.355, -0.06, 0.535))
HAND = basis(-(WRIST - ELBOW), v3((0.3, 1.0, 0.0)))      # hangs along the forearm; the palm toward her hip, the thumb forward


def hand_relaxed():
    """a chubby relaxed hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y), fingers loosely curled"""
    palm = Ellipsoid((0.0, 0.0, -0.048), (0.023, 0.041, 0.048), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.04, 0.034, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.028, 0.85), (-0.0095, 1.0), (0.0095, 0.97), (0.028, 0.8)):
        pts = [((0.0, f, -0.083), 0.0128), ((-0.005, f, -0.083 - 0.027 * L), 0.0121), ((-0.018, f, -0.083 - 0.047 * L), 0.0112), ((-0.033, f, -0.083 - 0.054 * L), 0.0102)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((-0.003, 0, 0.004)), (0.008, 0.0083, 0.0065), part=NAIL))
    parts.append(loft([(v3((-0.008, -0.032, -0.028)), 0.015), (v3((-0.023, -0.049, -0.06)), 0.0128), (v3((-0.034, -0.044, -0.086)), 0.0112)], part=SKIN, k=0.004))
    return Union(parts, k=0.009)


def arm():
    # a puffed short sleeve rolled up above the elbow, a chubby green forearm, the hand
    mid = SHOULDER + (ELBOW - SHOULDER) * 0.5
    sleeve = loft([(SHOULDER + v3((-0.025, 0, 0.02)), 0.07), (mid, 0.08), (ELBOW + (SHOULDER - ELBOW) * 0.24, 0.07)], part=BLOUSE, k=0.025)
    d = _unit(ELBOW - SHOULDER)
    roll = Torus(ELBOW + (SHOULDER - ELBOW) * 0.25, 0.064, 0.016, Rm=basis(d, v3((0, 1, 0))), part=BLOUSE)
    upper = RoundCone(SHOULDER, ELBOW, 0.062, 0.055, part=SKIN)
    fore = RoundCone(ELBOW, WRIST, 0.054, 0.039, part=SKIN)
    return Union([Union([upper, fore], k=0.025, part=SKIN), sleeve, roll, place(hand_relaxed(), WRIST, HAND)], k=0.006)


def pieces():
    body = Union([blouse(), apron(), towel(), pens(), legs()], k=0.0)
    return [("head", head(), 0.0018), ("hair", hair(), 0.0025), ("body", body, 0.0035), ("arms", Mirror(arm()), 0.003), ("jewels", jewels(), 0.0015)]


# ---------------------------------------------------------------------------------------------------- paint (kit/paint.py fills the shader's layers from these)

def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    return ((h ^ (h >> 16)) & 0xFFFF).astype(np.float32) / 65535.0


def flower_print(P, N, cell=0.07, size=0.027, seed=3):
    """the blouse's print: scattered five-petal flowers on a jittered 3D grid, each drawn flat in the surface's tangent plane. (petals, hearts) masks 0..1"""
    from kit.paint import smooth
    b = np.floor(P / cell).astype(np.int64)
    pet = np.zeros(len(P), np.float32)
    cen = np.zeros(len(P), np.float32)
    t1 = np.cross(N, np.array([0, 0, 1], np.float32))
    bad = np.linalg.norm(t1, axis=1) < 0.3
    t1[bad] = np.cross(N[bad], np.array([1, 0, 0], np.float32))
    t1 /= np.maximum(np.linalg.norm(t1, axis=1, keepdims=True), 1e-6)
    t2 = np.cross(N, t1)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                ix, iy, iz = b[:, 0] + dx, b[:, 1] + dy, b[:, 2] + dz
                j = np.stack([_hash(ix, iy, iz, seed + k) for k in range(4)], 1)
                cpos = (np.stack([ix, iy, iz], 1).astype(np.float32) + 0.15 + 0.7 * j[:, :3]) * cell
                v = P - cpos
                vn = np.einsum("ij,ij->i", v, N)
                vt = v - N * vn[:, None]
                r = np.linalg.norm(vt, axis=1)
                a = np.arctan2(np.einsum("ij,ij->i", vt, t2), np.einsum("ij,ij->i", vt, t1)) + j[:, 3] * 6.283
                sz = size * (0.6 + 0.6 * j[:, 3])
                edge = sz * (0.48 + 0.52 * np.abs(np.cos(2.5 * a)))
                near = (np.abs(vn) < cell * 0.5).astype(np.float32)
                pet = np.maximum(pet, near * smooth(edge + 0.0014, edge - 0.0014, r))
                cen = np.maximum(cen, near * smooth(sz * 0.22 + 0.001, sz * 0.22 - 0.001, r))
    return pet, cen


def paint(c):
    from kit.paint import srgb, smooth
    P, N = c.P, c.N
    n = len(P)
    U = untilt(P)                                   # the upright head's frame
    Uq = U.copy()
    Uq[:, 0] = np.abs(Uq[:, 0])
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    z = P[:, 2]
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

    # skin: mint, lighter over the brow and the tops of the cheeks, deeper under the jaw and down the neck; rosy cheeks; freckles
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(150, 194, 162), (n, 3)).copy()
    sk = sk + (srgb(176, 214, 184) - sk) * (smooth(1.18, 1.34, z) * 0.7)[:, None]
    under = smooth(-0.2, -0.75, N[:, 2]) * smooth(1.12, 0.98, z)
    sk = sk + (srgb(104, 146, 122) - sk) * (np.maximum(under, smooth(1.0, 0.86, z)) * 0.55 * (z > 0.8))[:, None]
    cheek = np.linalg.norm((Uq - v3((0.125, -0.13, 1.14))) / v3((0.06, 0.06, 0.045)), axis=1)
    sk = sk + (srgb(206, 160, 148) - sk) * (smooth(1.0, 0.25, cheek) * 0.55)[:, None]
    sk *= (1.0 + 0.07 * mott)[:, None]
    # the eyes' rolled lids: the rims a shade deeper, a teal-grey line under each eye; inked liner along the upper lids
    for e, PP in ((EYE_SIDE, Uq), (EYE_TOP, U)):
        q = e.local(PP)
        rq = np.linalg.norm(q, axis=1)
        dball = (rq - 1.0) * float(e.rad[1])
        rim = m & (rq < 1.9) & (q[:, 2] > -0.2)
        sk = np.where((rim & (q[:, 1] > 0.0))[:, None], sk * (1.0 - 0.18 * smooth(0.03, 0.0, dball))[:, None], sk)
        low = rim & (q[:, 1] < -0.1)
        sk = np.where(low[:, None], sk + (srgb(96, 132, 128) - sk) * (smooth(0.012, 0.0, dball) * 0.7)[:, None], sk)
        c.draw(rim & (q[:, 1] > -0.2) & (dball < 0.014), np.abs(dball), 0.0055, 0.9)
        c.draw(rim & (q[:, 1] <= -0.2) & (dball < 0.01), np.abs(dball), 0.003, 0.35)
    put(m, sk, 0.5, bump=0.15)
    face = m & (z > 0.9)
    speck(m, srgb(172, 104, 80), np.where(face, 0.38, 0.32))

    # eyes: warm cream whites, a big hazel iris looking up and to her left under the lids, inked pupil and rim, a glint
    m = c.mask(EYE)
    ew = np.broadcast_to(srgb(240, 220, 190), (n, 3)).copy()
    for e, PP, side_eye in ((EYE_SIDE, Uq, True), (EYE_TOP, U, False)):
        q = e.local(PP)
        qn = q / np.maximum(np.linalg.norm(q, axis=1), 1e-6)[:, None]
        mine = m & (np.linalg.norm(q, axis=1) < 1.15)
        gs = np.where(P[:, 0] > 0, 0.22, -0.22) if side_eye else np.full(n, 0.12)      # all three glance to her left
        g = np.stack([gs, np.full(n, 0.3), np.full(n, 0.9)], 1)
        g /= np.linalg.norm(g, axis=1, keepdims=True)
        ang = np.arccos(np.clip(np.einsum("ij,ij->i", qn, g), -1, 1))
        ir = srgb(172, 132, 64) + (srgb(96, 64, 28) - srgb(172, 132, 64)) * smooth(0.12, 0.4, ang)[:, None]
        col = np.where((ang < 0.42)[:, None], ir, ew)
        col *= (1.0 - 0.35 * smooth(-0.1, 0.6, qn[:, 1]))[:, None]           # the lids' shadow over the top of the ball
        gl = smooth(0.13, 0.06, np.linalg.norm(qn - _unit((-0.35, 0.55, 0.76)), axis=1))
        col = col + (srgb(255, 252, 240) - col) * gl[:, None]
        c.col[mine] = col[mine]
        c.draw(mine, (ang - 0.17) * 0.04, 0.0)                              # pupil
        c.draw(mine & (ang > 0.3), np.abs(ang - 0.42) * 0.04, 0.0009, 0.7)  # iris rim
    c.rough[m] = 0.08
    c.metal[m] = 0.0

    # lips: the upper lip a deep red, the lower a rose pink catching the light, the parting inked and curling up into the dimples
    m = c.mask(LIP)
    zc = MOUTH_Z + MOUTH_RISE * (U[:, 0] / 0.088) ** 2
    lp = np.where((U[:, 2] > zc)[:, None], srgb(150, 58, 66), srgb(206, 118, 120))
    lp = lp * (1.0 + 0.25 * smooth(-0.004, -0.012, U[:, 2] - zc) * smooth(0.06, 0.0, np.abs(U[:, 0])))[:, None]
    put(m, lp, 0.3)
    near_mouth = (np.abs(U[:, 0]) < 0.092) & (np.abs(U[:, 2] - zc) < 0.01) & (U[:, 1] < -0.1)
    c.draw(near_mouth & c.mask(LIP, SKIN), np.abs(U[:, 2] - zc + 0.0005), 0.0006 + 0.0007 * smooth(0.092, 0.03, np.abs(U[:, 0])))

    # hair: plum, violet on the raised strands, near black in the grooves
    m = c.mask(HAIR)
    hc = srgb(108, 36, 80) + (srgb(146, 98, 168) - srgb(108, 36, 80)) * (c.wear * 0.45 + 0.15 * (noise3(P, 0.02) * 0.5 + 0.5))[:, None]
    hc *= (1.0 - 0.45 * c.cavity)[:, None]
    put(m, hc, 0.45, bump=0.5)
    # the band: gold, a red stripe down its middle edged in blue
    m = c.mask(BAND)
    t = np.clip(((U - HAIR_PT) @ HAIR_N + 0.040) / 0.019, 0, 1)
    bd = np.broadcast_to(srgb(226, 164, 58), (n, 3)).copy()
    bd = np.where((np.abs(t - 0.5) < 0.12)[:, None], srgb(176, 50, 44), bd)
    bd = np.where((np.abs(np.abs(t - 0.5) - 0.26) < 0.05)[:, None], srgb(52, 70, 140), bd)
    put(m, bd, 0.55, bump=0.8)
    m = c.mask(GOLD)
    put(m, srgb(240, 184, 90) * (1.0 - 0.4 * c.cavity)[:, None], 0.25, metal=1.0, bump=0.05, grain=1.0)

    # blouse: warm cream, orange five-petal flowers with darker hearts
    m = c.mask(BLOUSE)
    pet, cen = flower_print(P, N)
    bl = np.broadcast_to(srgb(240, 216, 196), (n, 3)) * (1.0 + 0.04 * mott)[:, None]
    bl = bl + (srgb(232, 138, 56) - bl) * pet[:, None]
    bl = bl + (srgb(184, 86, 38) - bl) * cen[:, None]
    put(m, bl, 0.85, bump=1.0)
    speck(m, srgb(226, 150, 92), 0.12)

    # apron: maroon, a faint quilted diamond, gold flecks, orange stitching along the hem and the pocket edges
    u1 = (P[:, 0] + P[:, 2]) / 0.05
    u2 = (P[:, 0] - P[:, 2]) / 0.05
    dd = np.minimum(0.5 - np.abs(u1 - np.floor(u1) - 0.5), 0.5 - np.abs(u2 - np.floor(u2) - 0.5))
    for part, base in ((APRON, srgb(128, 34, 50)), (POCKET, srgb(140, 40, 56))):
        m = c.mask(part)
        ap = np.broadcast_to(base, (n, 3)) * (1.0 + 0.1 * mott - 0.14 * smooth(0.07, 0.0, dd) + 0.35 * c.wear)[:, None]
        put(m, ap, 0.82, bump=1.0)
        speck(m, srgb(214, 126, 66), 0.22)
    dash = (np.sin(P[:, 0] * 520.0) > -0.2) | (np.sin(P[:, 2] * 520.0) > 0.6)
    stitch = np.abs(z - 0.322) < 0.0022
    inpk = (Q[:, 0] > 0.03) & (Q[:, 0] < 0.21) & (z > 0.425) & (z < 0.6)
    stitch |= inpk & ((np.abs(z - 0.578) < 0.0022) | (np.abs(Q[:, 0] - 0.046) < 0.0022) | (np.abs(Q[:, 0] - 0.195) < 0.0022) | (np.abs(z - 0.442) < 0.0022))
    stitch &= c.mask(APRON, POCKET) & dash
    c.col[stitch] = c.col[stitch] * 0.4 + srgb(222, 138, 80) * 0.6
    # the towel: cream linen with red bands
    m = c.mask(TOWEL)
    band = (np.abs(z - 0.462) < 0.008) | (np.abs(z - 0.486) < 0.0035) | (np.abs(z - 0.712) < 0.006)
    tw = np.where(band[:, None], srgb(188, 70, 80), srgb(236, 226, 206)) * (1.0 + 0.05 * mott)[:, None]
    put(m, tw, 0.9, bump=1.0)
    # trousers: olive cotton, darker down the gathers, a little orange fleck
    m = c.mask(TROUSERS)
    put(m, srgb(132, 116, 60) * (1.0 + 0.06 * mott + 0.25 * c.wear)[:, None], 0.85, bump=1.0)
    speck(m, srgb(184, 122, 60), 0.12)
    # shoes: oxblood leather polished at the toes, a dark sole
    put(c.mask(SHOE), srgb(124, 52, 42) * (1.0 + 0.7 * c.wear)[:, None], 0.32, bump=0.3, grain=1.0)
    put(c.mask(SOLE), srgb(64, 38, 28), 0.6, bump=0.3, grain=1.0)
    put(c.mask(PEN), srgb(60, 92, 170), 0.3)
    put(c.mask(PENCIL), srgb(236, 184, 40), 0.5)
    put(c.mask(NAIL), srgb(206, 130, 128), 0.3)

    # light the room does not give: occlusion into the creases, dirt in the cavities
    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]



# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2600, "hair": 1100, "body": 3900, "arms": 1400, "jewels": 240},     # triangles per piece
    "density": {"head": 1.8, "hair": 1.1, "arms": 1.2},                                   # texture resolution against the rest
    "tex": 2048,
    "stride": {"walk": 0.44, "run": 0.80},                                                # metres per cycle (two steps)
    "speed": 0.45,                                                                        # a slow waddle against the crowd's pace
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.03, 1.01),
    "radius": 0.40,
}
BALL = v3((0.172, -0.12, 0.0))                  # where her left shoe rolls, near its toe (further back the toe sinks into the floor)
TOWEL_TOP = v3((-0.222, -0.235, 0.70))


def rig_bones():
    from kit.rig import Bone, mirror
    ring_top = TILT_R @ (EAR_RING + v3((0, 0, 0.026)) - PIV) + PIV
    ring_bot = TILT_R @ (EAR_RING - v3((0, 0, 0.026)) - PIV) + PIV
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.03, 0.45), (0, 0.03, 0.60), "root", 0.2),
        Bone("spine", (0, 0.03, 0.60), (0, 0.03, 0.76), "hips", 0.2),
        Bone("chest", (0, 0.03, 0.76), (0, 0.04, 0.93), "spine", 0.17),
        Bone("neck", (0, 0.045, 0.93), PIV, "chest", 0.09),
        Bone("head", PIV, (0, 0.0, 1.30), "neck", 0.17),
        Bone("hoop.L", ring_top, ring_bot, "head", 0.01),
        Bone("shoulder.L", (0.06, 0.035, 0.90), SHOULDER, "chest", 0.06),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.062),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.05),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.11, "forearm.L", 0.035),
        Bone("thigh.L", HIP_J, KNEE, "hips", 0.13),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.08),
        Bone("foot.L", ANKLE, TOE, "shin.L", 0.04),
    ])
    bones.append(Bone("towel", TOWEL_TOP, TOWEL_TOP + v3((0.0, -0.01, -0.28)), "hips", 0.04))
    return bones


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for rigid vertices). piece: 0 head, 1 hair, 2 body, 3 arms, 4 jewels"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]
    U = untilt(P)

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    # head rigid above the jaw, the neck bending from the collar; hair rigid; the hoops on their own swinging bones
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (U[:, 2] > 1.04) & (z > 1.0)] = ix["head"]
    rig[piece == 1] = ix["head"]
    allow(piece == 1, "head")
    jp = piece == 4
    rig[jp & (x > 0)] = ix["hoop.L"]
    rig[jp & (x <= 0)] = ix["hoop.R"]
    allow(jp, "head")
    # the body: trousers and shoes on the legs; blouse, apron and pens on the trunk (the flare and the apron's skirt follow the hips, never the thighs)
    bp = piece == 2
    legs = bp & (np.isin(part, (TROUSERS, SHOE, SOLE)) | (z < 0.2))
    allow(legs, "hips")
    allow(legs & (x > -0.04), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.04), "thigh.R", "shin.R", "foot.R")
    tw = bp & (part == TOWEL)
    allow(tw, "hips", "towel")
    rig[tw & (z < 0.66)] = ix["towel"]
    torso = bp & ~legs & ~tw
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.12) & (z > 0.8), "shoulder.L")
    allow(torso & (x < -0.12) & (z > 0.8), "shoulder.R")
    rig[torso & np.isin(part, (PEN, PENCIL))] = ix["hips"]
    # arms, each to its own side; the sleeve's top may lean on the chest
    ap = piece == 3
    allow(ap & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(ap & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(ap & (z > 0.86) & (np.abs(x) < 0.21), "chest")
    return A, rig


WALK = dict(stride=0.44, stance=0.62, foot_x=0.16, lift=0.042, bob=0.012, drop=0.042, sway=0.036, roll=5.0, yaw=6.0, counter=1.0,
            lean=2.0, toe_off=8.0, toe_out=12.0, swing_point=4.0)
RUN = dict(stride=0.80, stance=0.42, foot_x=0.14, lift=0.08, bob=0.028, drop=0.065, sway=0.028, roll=4.0, yaw=8.0, counter=1.2,
           lean=10.0, toe_off=18.0, toe_out=10.0, swing_point=8.0, spine_lean=4.0)
STANCE_Y = 0.06        # her hips over mid-foot (kit.gait centres the stance on the ball), a stout body leaning back a little as it waddles


def motions(rig):
    """walk: a slow rocking waddle (feet wide and turned out, the whole trunk rocking over each planted foot, arms swinging out, the head
    still gazing up and nodding with the steps, the hoops and the towel swinging); run: a hurried jog, elbows tucked; idle: she shifts her
    weight, breathes, and looks about the sky"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.offset = p.offset + Vector((0.0, STANCE_Y, 0.0))
        s1, c1 = math.sin(TAU * u), math.cos(TAU * u)
        rock = 4.0 if run else 9.0
        p.rot("spine", 0, rock * s1, 0)
        p.rot("chest", 0, rock * 0.35 * s1, 0)
        sw = 24.0 if run else 9.0
        p.rot("upper_arm.L", sw * c1, -6.0 - (2.0 if run else 6.0) * math.sin(TAU * u - 0.5), 0)
        p.rot("upper_arm.R", -sw * c1, 6.0 - (2.0 if run else 6.0) * math.sin(TAU * u - 0.5), 0)
        bend = 55.0 if run else 10.0
        p.rot("forearm.L", -bend - (10.0 if run else 4.0) * max(0.0, -c1), 0, 0)
        p.rot("forearm.R", -bend - (10.0 if run else 4.0) * max(0.0, c1), 0, 0)
        p.rot("neck", 2.0 if run else 0.0, 0, 0)
        p.world["head"] = R((5.0 if run else 0.0) + 2.0 * math.sin(2 * TAU * u + 0.6), (2.0 if run else 4.0) * s1, -2.0 * c1)
        for side in ("L", "R"):
            p.world["hoop." + side] = R(4.0 * math.sin(2 * TAU * u + 1.2), -(5.0 if run else 9.0) * math.sin(TAU * u - 1.0), 0)
        p.rot("towel", -(10.0 if run else 6.0) * math.cos(TAU * (u + 0.5) - 0.4), 0, 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)                       # her weight going from foot to foot once in the clip
        b = math.sin(TAU * t / 3.0)                       # breath
        stand(rig, p, legs, {"L": (Vector(BALL.tolist()), 10.0), "R": (Vector((BALL * f).tolist()), -10.0)},
              hip_shift=(0.02 * w, 0.0, -0.012 - 0.004 * abs(w)), roll=-3.0 * w, yaw=2.0 * w)
        p.rot("spine", 1.0 * b, 4.0 * w, 0)
        p.rot("chest", 1.2 * b, 1.5 * w, 0)
        p.rot("upper_arm.L", 1.5 * b, -3.0 + 1.5 * w, 0)
        p.rot("upper_arm.R", 1.5 * b, 3.0 + 1.5 * w, 0)
        p.rot("forearm.L", -8.0, 0, 0)
        p.rot("forearm.R", -8.0, 0, 0)
        # looking about the sky: up and to her left, then a slow sweep to her right, home again
        look = ease((t - 0.8) / 1.2) * (1.0 - ease((t - 2.6) / 1.4)) * 14.0 - ease((t - 3.0) / 1.4) * (1.0 - ease((t - 5.0) / 0.9)) * 12.0
        up = 5.0 * ease((t - 0.8) / 1.0) * (1.0 - ease((t - 5.0) / 0.9))
        p.world["head"] = R(-up + 1.5 * b, 2.0 * w, look)
        for side in ("L", "R"):
            p.world["hoop." + side] = R(1.5 * b, -3.0 * math.sin(TAU * t / 6.0 - 0.8), 0)
        p.rot("towel", 1.5 * w, 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
