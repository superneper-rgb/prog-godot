## FOINT CITY townsfolk: the walkman fellow (working name; the user names him). A pink three-eyed fellow with a huge toothy grin, spiky dark hair and big ears; purple tracksuit with a teal stripe, gold chain, a walkman clipped on, earphones in, chunky sneakers.
# Concept: the user's sheet, image 2 bottom (F:/prog-godot-cache/folk/refs/2.png). Measured off a 3x crop (1.39 mm a pixel): 1.60 m to the tips of his hair; a big head 0.34 tall
# (chin 1.22, grin 1.30-1.37, side eyes 1.44, top eye 1.50, brow 1.545); the jacket's shoulders 1.18, its ribbed band 0.76-0.82; baggy trousers gathered at 0.25; sneakers 0.20 high.
# His pose is the concept's: right hand in his trouser pocket, left hand up in a shaka by his shoulder. The arms are their own piece; the earphone cables are their own piece.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, noise3, v3, basis, place)

HEIGHT = 1.60
REF = ("2.png", (29, 383, 334, 779))

SKIN, EYE, LIP, MOUTHIN, TEETH, HAIR, JACKET, RIB, SWEATER, GOLD, TROUSERS, SNEAKER, SOLE, LACE, WALKMAN, BUD, NAIL, ZIP = range(1, 19)
COLOURS = {
    SKIN: ((0.62, 0.22, 0.20), 0.55, 0.0),
    EYE: ((0.85, 0.78, 0.40), 0.2, 0.0),
    LIP: ((0.62, 0.20, 0.22), 0.4, 0.0),
    MOUTHIN: ((0.05, 0.01, 0.01), 0.6, 0.0),
    TEETH: ((0.80, 0.72, 0.50), 0.3, 0.0),
    HAIR: ((0.04, 0.025, 0.025), 0.7, 0.0),
    JACKET: ((0.22, 0.07, 0.28), 0.6, 0.0),
    RIB: ((0.17, 0.05, 0.22), 0.8, 0.0),
    SWEATER: ((0.80, 0.74, 0.62), 0.9, 0.0),
    GOLD: ((0.95, 0.68, 0.25), 0.3, 1.0),
    TROUSERS: ((0.22, 0.07, 0.28), 0.6, 0.0),
    SNEAKER: ((0.78, 0.72, 0.62), 0.6, 0.0),
    SOLE: ((0.82, 0.76, 0.66), 0.7, 0.0),
    LACE: ((0.85, 0.80, 0.70), 0.7, 0.0),
    WALKMAN: ((0.85, 0.45, 0.06), 0.4, 0.0),
    BUD: ((0.90, 0.88, 0.85), 0.3, 0.0),
    NAIL: ((0.70, 0.40, 0.38), 0.3, 0.0),
    ZIP: ((0.75, 0.70, 0.60), 0.3, 1.0),
}


def _unit(a):
    a = v3(a)
    return a / np.linalg.norm(a)


def bounded(s, lo, hi):
    """narrow a shape's bound (a clipped garment layer is far smaller than the body it was grown from): unions then skip it everywhere else"""
    s.lo, s.hi = v3(lo), v3(hi)
    return s


def _surface_y(shape, x, z, y0=-0.6, y1=0.3):
    """where the shape's front surface is at (x, z), marching back from the front"""
    ys = np.linspace(y0, y1, 1800, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


def prism(poly_xz, y0=-0.7, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from the front (y0) to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


class Eye:
    """an eye: centre, radii (across, up, deep), where it looks, the lid edges' heights at the front of the ball (fractions of the up radius)"""
    def __init__(self, c, rad, fwd, roll=0.0, lid_up=0.3, lid_lo=0.5, arch=22.0, rim=0.016):
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
        return ((P - self.c) @ self.M) / self.rad


# ---------------------------------------------------------------------------------------------------- the head
EYE_TOP = Eye((0.0, -0.112, 1.497), (0.05, 0.032, 0.04), (0.0, -0.97, 0.24), lid_up=0.28, lid_lo=0.42, arch=14.0)
EYE_SIDE = Eye((0.108, -0.122, 1.437), (0.058, 0.034, 0.045), (0.18, -0.98, 0.04), roll=-9.0, lid_up=0.3, lid_lo=0.46, arch=14.0)
NOSE = v3((0.0, -0.178, 1.392))
GRIN_W = 0.158                 # half the grin's width
UP_Z = 1.356                   # the upper lip's edge at the middle (an almost flat arc)
LO_Z = 1.298                   # the lower lip's edge at the middle (a deep U up to the corners)
CORNER_Z = 1.37
CROWN = Ellipsoid((0, 0.02, 1.44), (0.165, 0.155, 0.12))


def z_up(x):
    return UP_Z + (CORNER_Z - UP_Z) * (x / GRIN_W) ** 2


def z_lo(x):
    t = np.clip(np.abs(x) / GRIN_W, 0, 1)
    return LO_Z + (CORNER_Z - LO_Z) * t ** 2.2


def skull():
    return Union([
        CROWN,
        Ellipsoid((0, -0.035, 1.335), (0.188, 0.14, 0.112)),                # the wide grinning lower face
        Mirror(Ellipsoid((0.125, -0.06, 1.36), (0.07, 0.07, 0.065))),       # cheeks pushed up by the grin
        Ellipsoid((0, -0.05, 1.265), (0.15, 0.115, 0.07)),                  # the jaw
        Ellipsoid((0, -0.125, 1.258), (0.075, 0.045, 0.042)),               # the big chin under the lower lip
        Ellipsoid((0, -0.02, 1.215), (0.12, 0.09, 0.055)),                  # under the jaw, into the neck
        Ellipsoid((0, -0.1, 1.534), (0.065, 0.032, 0.022)),                 # the brow over the top eye
    ], k=0.045, part=SKIN)


def head():
    sk = skull()
    face = Union([sk, Mirror(EYE_SIDE.mound()), EYE_TOP.mound()], k=0.026)
    face = Cut(face, [Mirror(EYE_SIDE.opening()), EYE_TOP.opening()], k=0.006)
    # the nose: a round bulb on a short bridge, wings either side, nostrils underneath
    nose = Union([RoundCone((0, -0.135, 1.44), (0, -0.168, 1.402), 0.013, 0.019, part=SKIN), Ellipsoid(NOSE, (0.029, 0.024, 0.024), part=SKIN),
                  Mirror(Ellipsoid((0.024, -0.155, 1.384), (0.016, 0.017, 0.014), part=SKIN))], k=0.008)
    face = Union([face, nose], k=0.008)
    face = Cut(face, [Mirror(Ellipsoid((0.013, -0.176, 1.372), (0.0065, 0.009, 0.005), R=rot(rx=-15)))], k=0.003)
    # the grin: a crescent cut deep into the face, a dark mouth behind, teeth along both lips, a thin upper lip and a fat lower one
    xs = np.linspace(-GRIN_W, GRIN_W, 25)
    poly = [(x, z_up(x)) for x in xs] + [(x, z_lo(x)) for x in xs[-2:0:-1]]      # the corners once each (a repeated point breaks the outline)
    face = Cut(face, [prism(poly, y0=-0.5, y1=-0.07)], k=0.005)
    inside = Ellipsoid((0, -0.075, 1.33), (0.15, 0.06, 0.055), part=MOUTHIN)
    face = Union([face, inside], k=0.004)
    up, lo, teeth = [], [], []
    for x in np.linspace(-GRIN_W, GRIN_W, 25):
        t = x / GRIN_W
        y = _surface_y(sk, x, z_up(x) + 0.004)
        up.append((v3((x, y + 0.004, z_up(x) + 0.002)), 0.0042 + 0.0012 * (1 - t * t)))
        y = _surface_y(sk, x, z_lo(x) - 0.006)
        if abs(t) < 0.93:
            lo.append((v3((x, y + 0.003, z_lo(x) - 0.007)), 0.006 + 0.008 * (1 - t * t)))
    for i, x in enumerate(np.linspace(-0.122, 0.122, 10)):
        y = _surface_y(sk, x, z_up(x) - 0.01) + 0.013
        h = 0.011 + 0.003 * ((i * 7) % 3 == 0)
        teeth.append(Box((x, y, z_up(x) - 0.011), (0.0105, 0.007, h), rr=0.004, R=rot(rz=-np.degrees(np.arctan(x / 0.2))), part=TEETH))
    for i, x in enumerate(np.linspace(-0.085, 0.085, 7)):
        y = _surface_y(sk, x, z_lo(x) + 0.01) + 0.014
        teeth.append(Box((x, y, z_lo(x) + 0.008), (0.009, 0.006, 0.008 + 0.002 * (i % 2)), rr=0.0035, R=rot(rz=-np.degrees(np.arctan(x / 0.2))), part=TEETH))
    # gums behind each row tie the teeth together and to the lips (loose little islands vanish when the game model is decimated)
    gu = [(v3((x, _surface_y(sk, x, z_up(x) - 0.004) + 0.017, z_up(x) - 0.003)), 0.0075) for x in np.linspace(-0.13, 0.13, 9)]
    gl = [(v3((x, _surface_y(sk, x, z_lo(x) + 0.004) + 0.018, z_lo(x) + 0.002)), 0.007) for x in np.linspace(-0.095, 0.095, 7)]
    face = Union([face, loft(up, part=LIP, k=0.008), loft(lo, part=LIP, k=0.01), loft(gu, part=MOUTHIN, k=0.006), loft(gl, part=MOUTHIN, k=0.006)], k=0.004)
    face = Union([face] + teeth, k=0.002)
    # smile creases from the corners curving up round the cheeks
    for sx in (1.0, -1.0):
        pts = []
        for t in np.linspace(0.0, 1.0, 6):
            x = sx * (GRIN_W + 0.012 - 0.06 * t * t)
            z = CORNER_Z + 0.004 + 0.05 * t
            pts.append((v3((x, _surface_y(sk, x, z) - 0.002, z)), 0.0028))
        face = Cut(face, [loft(pts, k=0.003)], k=0.004)
    # big ears flaring out, a deep hollow, a fat lobe
    ear = Union([Ellipsoid((0.262, 0.012, 1.395), (0.02, 0.072, 0.08), R=rot(rz=-58, rx=-6), part=SKIN),       # a satellite dish of an ear
                 Ellipsoid((0.2, 0.01, 1.39), (0.04, 0.035, 0.04), part=SKIN),
                 Ellipsoid((0.222, 0.0, 1.322), (0.018, 0.022, 0.022), part=SKIN)], k=0.016)
    ear = Cut(ear, [Ellipsoid((0.28, 0.0, 1.398), (0.012, 0.05, 0.058), R=rot(rz=-58, rx=-6))], k=0.006)
    face = Union([face, Mirror(ear)], k=0.012)
    neck = RoundCone((0, 0.03, 1.08), (0, 0.0, 1.25), 0.085, 0.1, part=SKIN)
    return Union([Union([neck, face], k=0.035), Mirror(EYE_SIDE.ball()), EYE_TOP.ball()], k=0.0)


def hair():
    """a messy crown of dark spikes swept up and back, over a short buzz"""
    zone = [Half((0, -0.055, 1.5), (0.0, -0.75, -0.66)), Half((0, 0, 1.47), (0, 0.3, -1)), Ellipsoid((0, 0.04, 1.52), (0.12, 0.17, 0.12))]   # a crown of hair, the sides shaved
    buzz = Clip(Inflate(CROWN, 0.006, part=HAIR), zone, k=0.01)
    rng = np.random.default_rng(7)
    spikes = []
    for i in range(30):
        a = rng.uniform(-1.0, 1.0)
        b = rng.uniform(-0.15, 1.0)
        d = _unit((np.sin(a) * 0.55, -0.35 + b * 0.9, 0.8 + 0.2 * rng.uniform()))
        base = v3((0, 0.02, 1.44)) + d * 0.0
        # where this direction leaves the crown
        tt = np.linspace(0.05, 0.3, 200)
        pts = (v3((0, 0.02, 1.44)) + np.outer(tt, d)).astype(np.float32)
        dd = CROWN.eval(pts)[0]
        root = pts[int(np.argmax(dd > 0))]
        if root[2] < 1.47 or (root[1] < -0.06):
            continue
        tip = root + _unit(d + v3((rng.uniform(-0.3, 0.3), 0.35, 0.25))) * rng.uniform(0.04, 0.07)
        spikes.append(RoundCone(root - d * 0.004, tip, 0.0085, 0.0016, part=HAIR))
    return Union([buzz] + spikes, k=0.006, part=HAIR)


# ---------------------------------------------------------------------------------------------------- body: sweater, tracksuit, sneakers, walkman
WAIST = Ellipsoid((0, -0.005, 0.79), (0.235, 0.18, 0.06))


def torso_core():
    return Union([
        Ellipsoid((0, 0.02, 1.04), (0.245, 0.175, 0.15)),
        Ellipsoid((0, 0.03, 1.15), (0.265, 0.15, 0.06)),
        Ellipsoid((0, -0.02, 0.9), (0.26, 0.2, 0.12)),
        WAIST,
    ], k=0.07)


def jacket():
    core = torso_core()
    shell = Clip(Inflate(core, 0.016, part=JACKET), [Half((0, 0, 0.8), (0, 0, -1))], k=0.008)
    # the zip half open: a V from the collar to the chest showing the sweater
    vee = prism([(-0.075, 1.30), (0.075, 1.30), (0.03, 1.08), (0.0, 1.05), (-0.03, 1.08)])
    shell = Cut(shell, [vee], k=0.006)
    sweater = bounded(Clip(Inflate(core, 0.004, part=SWEATER), [prism([(-0.09, 1.3), (0.09, 1.3), (0.04, 1.03), (-0.04, 1.03)])], k=0.004), (-0.12, -0.4, 1.0), (0.12, 0.1, 1.3))
    roll = Torus((0, 0.012, 1.19), 0.1, 0.019, Rm=rot(rx=8), part=SWEATER)
    # the stand collar of the jacket, open at the zip, the hood folded behind
    collar = bounded(Clip(Cut(Inflate(RoundCone((0, 0.03, 1.08), (0, 0.0, 1.25), 0.085, 0.1), 0.045, part=JACKET),
                              [Inflate(RoundCone((0, 0.03, 1.08), (0, 0.0, 1.25), 0.085, 0.1), 0.03)], k=0.003),
                         [Half((0, 0, 1.25), (0, 0.3, 1)), Half((0, 0, 1.13), (0, 0, -1)), Half((0, -0.09, 0), (0, -1, -0.6))], k=0.006),
                     (-0.2, -0.2, 1.1), (0.2, 0.2, 1.3))
    hood = Ellipsoid((0, 0.16, 1.17), (0.15, 0.06, 0.07), part=JACKET)
    band = bounded(Clip(Inflate(WAIST, 0.03, part=RIB), [Half((0, 0, 0.825), (0, 0, 1)), Half((0, 0, 0.758), (0, 0, -1))], k=0.004), (-0.3, -0.25, 0.74), (0.3, 0.25, 0.84))
    pull = Box((0.0, _surface_y(core, 0.0, 1.04) - 0.02, 1.035), (0.007, 0.003, 0.013), rr=0.002, part=GOLD)
    zipline = bounded(Clip(Inflate(core, 0.019, part=ZIP), [prism([(-0.004, 1.05), (0.004, 1.05), (0.004, 0.77), (-0.004, 0.77)])], k=0.001), (-0.02, -0.4, 0.75), (0.02, 0.0, 1.06))

    def ribs(P):
        a = np.arctan2(P[:, 0], P[:, 1])
        return np.cos(a * 110.0) * ((P[:, 2] < 0.83) & (P[:, 2] > 0.75))
    band = Bump(band, ribs, 0.0015)

    def creases(P):
        return noise3(P, 0.05) + 0.5 * noise3(P, 0.02)
    shell = Bump(Union([shell, collar, hood], k=0.03, part=JACKET), creases, 0.004)
    return Union([shell, sweater, roll, band, pull], k=0.0)       # the zip itself is painted (a raised strip that narrow breaks the mesh)


HIP_J = v3((0.13, 0.02, 0.76))
KNEE = v3((0.155, -0.025, 0.45))
ANKLE = v3((0.165, 0.025, 0.13))
TOE = v3((0.17, -0.17, 0.05))


def trousers():
    seat = Ellipsoid((0, 0.03, 0.75), (0.245, 0.185, 0.12))
    # the legs stand clear of each other below the seat: touching legs bake their insides dark, and that shows once they stride apart
    leg = loft([(v3((0.135, 0.012, 0.74)), 0.135), (v3((0.155, -0.012, 0.47)), 0.118), (v3((0.165, 0.012, 0.33)), 0.1), (v3((0.165, 0.02, 0.27)), 0.085)], k=0.04)
    pocket_bump = Ellipsoid((-0.235, -0.04, 0.655), (0.045, 0.05, 0.065))        # his right hand in the pocket
    tr = Union([seat, Mirror(leg), pocket_bump], k=0.05, part=TROUSERS)

    def folds(P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        a = np.arctan2(Q[:, 1] - 0.02, Q[:, 0] - 0.165)
        low = np.clip((0.36 - Q[:, 2]) / 0.1, 0.0, 1.0)
        return noise3(Q, 0.06) * (1 - low) * 1.2 + np.cos(a * 8.0) * low
    tr = Bump(tr, folds, 0.006)
    tr = Clip(tr, [Half((0, 0, 0.255), (0, 0, -1)), Half((0, 0, 0.8), (0, 0, 1))], k=0.004)
    slit = Ellipsoid((-0.262, -0.02, 0.70), (0.012, 0.05, 0.045), R=rot(rx=20))
    tr = Cut(tr, [slit], k=0.006)
    cuff = Mirror(Bump(Clip(loft([(v3((0.165, 0.022, 0.30)), 0.084), (v3((0.165, 0.024, 0.22)), 0.078)], part=RIB),
                            [Half((0, 0, 0.28), (0, 0, 1)), Half((0, 0, 0.215), (0, 0, -1))], k=0.004),
                       lambda P: np.cos(np.arctan2(P[:, 1] - 0.022, np.abs(P[:, 0]) - 0.165) * 60.0), 0.0012))
    return Union([tr, cuff], k=0.0)


def sneakers():
    foot = Union([Ellipsoid((0.163, 0.065, 0.075), (0.062, 0.07, 0.075)), Ellipsoid((0.165, -0.04, 0.066), (0.072, 0.095, 0.066)),
                  Ellipsoid((0.17, -0.135, 0.05), (0.062, 0.075, 0.05)), Ellipsoid((0.163, 0.03, 0.17), (0.062, 0.07, 0.07))], k=0.03)
    shoe = Clip(Inflate(foot, 0.002, part=SNEAKER), [Half((0, 0, 0.24), (0, 0.2, 1)), Half((0, 0, 0.03), (0, 0, -1))], k=0.006)
    sole = Clip(Inflate(foot, 0.014, part=SOLE), [Half((0, 0, 0.042), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.004)

    def lugs(P):
        return (np.cos(P[:, 1] * 160.0) > 0.4) * (P[:, 2] < 0.03)
    sole = Bump(sole, lugs, -0.0025)
    tongue = Ellipsoid((0.165, -0.035, 0.17), (0.035, 0.03, 0.06), R=rot(rx=-30), part=SNEAKER)
    laces = [Box((0.165, -0.05 + 0.025 * i - 0.022, 0.115 + 0.022 * i), (0.032, 0.006, 0.005), rr=0.002, R=rot(rx=-35, rz=12 * (-1) ** i), part=LACE) for i in range(4)]
    return Mirror(Union([shoe, sole, tongue] + laces, k=0.0))


WALKMAN_C = v3((-0.118, 0.0, 0.715))


def walkman():
    y = _surface_y(Union([Ellipsoid((0, 0.03, 0.75), (0.245, 0.185, 0.12))]), WALKMAN_C[0], WALKMAN_C[2]) - 0.017
    c = v3((WALKMAN_C[0], y, WALKMAN_C[2]))
    body = Box(c, (0.034, 0.014, 0.047), rr=0.008, R=rot(rz=6), part=WALKMAN)
    clip = Box(c + v3((0, 0.016, 0.03)), (0.012, 0.004, 0.03), rr=0.002, part=ZIP)
    jack = RoundCone(c + v3((0.012, 0.0, 0.047)), c + v3((0.012, 0.0, 0.056)), 0.0045, 0.004, part=ZIP)
    return Union([body, clip, jack], k=0.0), c


# ---------------------------------------------------------------------------------------------------- arms (their own piece): the shaka (left) and the hand in his pocket (right)
SHOULDER = v3((0.25, 0.03, 1.13))
ELBOW_L = v3((0.37, 0.0, 0.915))
WRIST_L = v3((0.405, -0.09, 1.12))
SHAKA = basis(v3((0.12, 0.25, -1.0)), v3((1.0, 0.0, 0.25)))       # fingers up, palm forward, thumb toward his head, pinky out
ELBOW_R = v3((-0.36, 0.10, 0.92))
WRIST_R = v3((-0.272, -0.012, 0.73))


def hand_shaka():
    """in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): three fingers curled tight, thumb and pinky out"""
    palm = Ellipsoid((0.0, 0.0, -0.048), (0.022, 0.042, 0.048), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.036, 0.032, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.026, -0.009, 0.009):
        pts = [((0.0, f, -0.085), 0.0118), ((-0.012, f, -0.1), 0.0112), ((-0.03, f, -0.095), 0.0104), ((-0.036, f, -0.075), 0.0096)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((-0.004, 0, 0.002)), (0.006, 0.0075, 0.007), part=NAIL))
    pk = [((0.0, 0.026, -0.08), 0.0105), ((0.002, 0.036, -0.103), 0.0097), ((0.003, 0.045, -0.122), 0.009), ((0.003, 0.052, -0.137), 0.0083)]
    parts.append(loft([(v3(p), r) for p, r in pk], part=SKIN, k=0.004))
    parts.append(Ellipsoid(v3(pk[-1][0]) + v3((0.005, 0.0, 0.0)), (0.004, 0.006, 0.0075), part=NAIL))
    th = [((-0.008, -0.03, -0.025), 0.015), ((-0.012, -0.058, -0.05), 0.0128), ((-0.008, -0.078, -0.075), 0.0115), ((-0.004, -0.09, -0.094), 0.0105)]
    parts.append(loft([(v3(p), r) for p, r in th], part=SKIN, k=0.005))
    parts.append(Ellipsoid(v3(th[-1][0]) + v3((0.006, 0.0, 0.0)), (0.004, 0.0075, 0.008), part=NAIL))
    return Union(parts, k=0.009)


def sleeve(sh, el, wr, cuff_at):
    d = _unit(wr - el)
    s = loft([(sh + v3((-0.015 * np.sign(sh[0]), 0, 0.02)), 0.085), (sh + (el - sh) * 0.5, 0.088), (el, 0.08), (el + (wr - el) * cuff_at, 0.072)], part=JACKET, k=0.03)
    s = Clip(s, [Half(el + (wr - el) * cuff_at, d)], k=0.004)
    s = Bump(s, lambda P: noise3(P, 0.04), 0.004)
    a = el + (wr - el) * cuff_at
    cuff = Bump(Clip(loft([(a - d * 0.01, 0.058), (a + d * 0.07, 0.048)], part=RIB), [Half(a + d * 0.07, d), Half(a - d * 0.005, -d)], k=0.003),
                lambda P: np.cos((P @ np.cross(d, v3((0, 0, 1)) if abs(d[2]) < 0.9 else v3((1, 0, 0)))) * 900.0), 0.001)
    return Union([s, cuff], k=0.006)


def arms():
    fr = np.array([-1, 1, 1], np.float32)
    left = Union([sleeve(SHOULDER, ELBOW_L, WRIST_L, 0.7), loft([(ELBOW_L, 0.05), (WRIST_L, 0.036)], part=SKIN), place(hand_shaka(), WRIST_L, SHAKA)], k=0.006)
    right = sleeve(SHOULDER * fr, ELBOW_R, WRIST_R, 0.62)          # his right forearm runs into the pocket, the hand inside
    return Union([left, right], k=0.0)


# ---------------------------------------------------------------------------------------------------- jewels and wires: the gold chain, ear rings, earbuds and their cables
EAR_IN = v3((0.232, -0.018, 1.385))


def jewels():
    links = []
    n = 26
    for i in range(n):
        a = -np.pi * 0.95 + np.pi * 1.9 * i / (n - 1)          # round the front of the neck, ends hidden under the collar
        p = v3((0.112 * np.sin(a), 0.01 - (0.11 + 0.066 * max(0.0, np.cos(a)) ** 3) * np.cos(a), 1.175 - 0.1 * max(0.0, np.cos(a)) ** 3))     # hangs down into the open zip
        t = _unit((0.112 * np.cos(a), 0.11 * np.sin(a), 0.0))
        nrm = _unit(p - v3((0, 0.01, 1.2)))
        Rm = basis(t, nrm if i % 2 else np.cross(t, nrm))
        links.append(Torus(p, 0.0085, 0.0032, Rm=Rm @ rot(rx=90), part=GOLD))
    chain = Union(links)
    rings = Mirror(Union([Torus((0.226, -0.004, 1.298), 0.0078, 0.0024, Rm=rot(ry=90), part=GOLD), Sphere((0.262, 0.004, 1.34), 0.0048, part=GOLD)]))
    buds = Mirror(Union([Ellipsoid(EAR_IN, (0.011, 0.011, 0.012), part=BUD), RoundCone(EAR_IN + v3((-0.004, -0.004, -0.008)), EAR_IN + v3((-0.006, -0.008, -0.03)), 0.005, 0.004, part=BUD)]))
    return Union([chain, rings, buds])


def cables(jack):
    """the earphone wires: down each side of his face, over the chest, joining and running down to the walkman's jack"""
    core = torso_core()
    out = []
    join = v3((-0.06, 0.0, 0.98))
    join[1] = _surface_y(core, join[0], join[2]) - 0.025
    for sx in (1.0, -1.0):
        start = EAR_IN * np.array([sx, 1, 1], np.float32) + v3((-0.006 * sx, -0.008, -0.032))
        pts = [start, start + v3((-0.01 * sx, -0.03, -0.07))]
        for z, x in ((1.17, 0.13 * sx), (1.08, 0.07 * sx if sx < 0 else 0.05)):
            pts.append(v3((x, _surface_y(core, x, z) - 0.03, z)))
        pts.append(join)
        out.append(loft([(p, 0.003) for p in pts], part=BUD, k=0.01))
    pts = [join]
    for z in (0.9, 0.82):
        x = join[0] + (jack[0] - join[0]) * (0.98 - z) / (0.98 - jack[2])
        pts.append(v3((x, _surface_y(core, x, z) - 0.035, z)))
    pts.append(jack + v3((0, 0, 0.004)))
    out.append(loft([(p, 0.003) for p in pts], part=BUD, k=0.01))
    return Union(out, k=0.004)


def pieces():
    wm, wc = walkman()
    jack = wc + v3((0.012, 0.0, 0.056))
    body = Union([jacket(), trousers(), sneakers(), wm], k=0.0)
    return [("head", head(), 0.0018), ("hair", hair(), 0.0016), ("body", body, 0.0035), ("arms", arms(), 0.003), ("jewels", jewels(), 0.0013),
            ("cables", cables(jack), 0.0016)]


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
    u1 = (x + z) / 0.055
    u2 = (x - z) / 0.055
    diamond = np.minimum(0.5 - np.abs(u1 - np.floor(u1) - 0.5), 0.5 - np.abs(u2 - np.floor(u2) - 0.5))

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def speck(m, col, amt):
        amt = np.broadcast_to(np.asarray(amt, np.float32), (n,))
        c.spk[m] = np.concatenate([np.broadcast_to(col, (int(m.sum()), 3)), amt[m][:, None]], 1)

    # skin: salmon pink, rosier on the nose, cheeks and ears, darker in the smile creases; brown freckle spots
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(214, 120, 112), (n, 3)).copy()
    rosy = smooth(0.05, 0.0, np.linalg.norm(P - NOSE, axis=1) - 0.02)
    rosy = np.maximum(rosy, smooth(1.0, 0.3, np.linalg.norm((Q - v3((0.12, -0.11, 1.38))) / v3((0.05, 0.05, 0.04)), axis=1)) * 0.6)
    rosy = np.maximum(rosy, (Q[:, 0] > 0.19) * smooth(1.30, 1.36, z) * smooth(1.46, 1.42, z) * 0.6)
    sk = sk + (srgb(206, 92, 92) - sk) * rosy[:, None]
    sk = sk + (srgb(228, 146, 132) - sk) * (smooth(1.45, 1.55, z) * 0.5)[:, None]
    sk *= (1.0 + 0.07 * mott)[:, None]
    for e, PP in ((EYE_SIDE, P * np.array([1, 1, 1], np.float32)), (EYE_SIDE, P * np.array([-1, 1, 1], np.float32)), (EYE_TOP, P)):
        q = e.local(PP)
        rq = np.linalg.norm(q, axis=1)
        dball = (rq - 1.0) * float(e.rad[1])
        rim = m & (rq < 1.9) & (q[:, 2] > -0.2) & ((PP[:, 0] > 0) if e is EYE_SIDE else True)
        sk = np.where((rim & (q[:, 1] > 0))[:, None], sk * (1.0 - 0.15 * smooth(0.025, 0.0, dball))[:, None], sk)
        c.draw(rim & (q[:, 1] > -0.2) & (dball < 0.012), np.abs(dball), 0.004, 0.85)
        c.draw(rim & (q[:, 1] <= -0.2) & (dball < 0.008), np.abs(dball), 0.0022, 0.4)
    put(m, sk, 0.5, bump=0.15)
    speck(m, srgb(120, 52, 48), np.where(z > 1.2, 0.3, 0.2))
    # eyes: pale yellow whites, small dark irises looking a little up and in, inked pupils
    m = c.mask(EYE)
    for e, sx in ((EYE_SIDE, 1.0), (EYE_SIDE, -1.0), (EYE_TOP, 0.0)):
        PP = P * np.array([sx if sx else 1.0, 1, 1], np.float32)
        q = e.local(PP)
        qn = q / np.maximum(np.linalg.norm(q, axis=1), 1e-6)[:, None]
        mine = m & ((PP[:, 0] > 0) if sx else (np.abs(x) < 0.06) & (z > 1.47))
        g = _unit((-0.22 if sx else 0.1, 0.22, 0.95))
        ang = np.arccos(np.clip(qn @ g, -1, 1))
        col = np.broadcast_to(srgb(240, 226, 162), (n, 3)).copy()
        col = np.where((ang < 0.36)[:, None], srgb(78, 54, 30), col)
        col *= (1.0 - 0.35 * smooth(-0.1, 0.65, qn[:, 1]))[:, None]
        gl = smooth(0.14, 0.07, np.linalg.norm(qn - _unit((-0.3, 0.45, 0.84)), axis=1))
        col = col + (srgb(255, 252, 240) - col) * gl[:, None]
        c.col[mine] = col[mine]
        c.draw(mine, (ang - 0.2) * 0.03, 0.0)
    c.rough[m] = 0.08
    # the grin: a pink fat lower lip, a darker thin upper one, yellowed teeth, a dark mouth
    m = c.mask(LIP)
    put(m, np.where((z > 1.33)[:, None], srgb(176, 84, 86), srgb(212, 116, 118)) * (1.0 + 0.3 * c.wear)[:, None], 0.32)
    m = c.mask(TEETH)
    put(m, srgb(236, 218, 170) * (1.0 - 0.5 * c.cavity)[:, None], 0.3)
    put(c.mask(MOUTHIN), srgb(44, 12, 18), 0.6)
    put(c.mask(HAIR), srgb(48, 32, 32) * (1.0 + 0.8 * c.wear)[:, None], 0.6, bump=0.6)
    put(c.mask(NAIL), srgb(230, 168, 160), 0.3)
    # the tracksuit: purple with the sheet's faint diamond weave, a teal chevron across the chest, twin cream stripes down the sleeves and legs
    m = c.mask(JACKET, TROUSERS)
    tc = np.broadcast_to(srgb(132, 70, 146), (n, 3)) * (1.0 + 0.08 * mott - 0.1 * smooth(0.06, 0.0, diamond) + 0.25 * c.wear)[:, None]
    zc = 0.985 - 0.045 * np.clip(1.0 - np.abs(x) / 0.28, 0, 1)
    teal = c.mask(JACKET) & (np.abs(z - zc) < 0.032) & (np.abs(x) < 0.32)
    tc = np.where(teal[:, None], srgb(74, 172, 166) * (1.0 + 0.06 * mott)[:, None], tc)
    tc = np.where((c.mask(JACKET) & (np.abs(z - zc + 0.045) < 0.006) & (np.abs(x) < 0.32))[:, None], tc * 0.7, tc)
    stripe = np.zeros(n, bool)
    for a_, b_, o_ in ((SHOULDER, ELBOW_L, v3((1, 0, 0.2))), (ELBOW_L, WRIST_L, v3((1, 0, 0))), (SHOULDER * np.array([-1, 1, 1], np.float32), ELBOW_R, v3((-1, 0.2, 0))),
                       (ELBOW_R, WRIST_R, v3((-1, 0.3, 0)))):
        ang = _around(P, a_, b_, _unit(o_))
        t = ((P - a_) @ _unit(b_ - a_)) / np.linalg.norm(b_ - a_)
        on = (t > -0.15) & (t < 1.05) & ((x > 0) == (a_[0] > 0)) & (Q[:, 0] > 0.2)
        stripe |= on & ((np.abs(ang - 0.16) < 0.07) | (np.abs(ang + 0.16) < 0.07))
    for sx in (1.0, -1.0):
        ang = _around(P, v3((0.14 * sx, 0.0, 0.8)), v3((0.165 * sx, 0.02, 0.25)), v3((sx, 0, 0)))
        on = c.mask(TROUSERS) & ((x > 0) == (sx > 0))
        stripe |= on & ((np.abs(ang - 0.17) < 0.075) | (np.abs(ang + 0.17) < 0.075))
    tc = np.where(stripe[:, None], srgb(232, 218, 190) * (1.0 + 0.05 * mott)[:, None], tc)
    put(m, tc, 0.62, bump=1.0)
    speck(m, srgb(200, 110, 80), 0.18)
    m = c.mask(RIB)
    put(m, srgb(110, 56, 124) * (1.0 + 0.3 * c.wear)[:, None], 0.8, bump=1.0)
    put(c.mask(SWEATER), srgb(234, 222, 198) * (1.0 + 0.05 * mott - 0.2 * c.cavity)[:, None], 0.9, bump=1.0)
    m = c.mask(ZIP)
    put(m, srgb(214, 200, 170), 0.35, metal=1.0)
    c.draw(m & (y < -0.1) & (z < 1.06) & (z > 0.75), np.abs(np.abs(x) - 0.0045), 0.0007, 0.6)
    put(c.mask(GOLD), srgb(240, 186, 82) * (1.0 - 0.4 * c.cavity)[:, None], 0.24, metal=1.0, bump=0.05, grain=1.0)
    # sneakers: cream leather, purple panels and a yellow flash on the sides, a scuffed cream sole
    m = c.mask(SNEAKER)
    sn = np.broadcast_to(srgb(228, 216, 194), (n, 3)).copy()
    side = (np.abs(Q[:, 0] - 0.165) > 0.035)
    panel = side & (z > 0.05) & (z < 0.13) & (y > -0.16) & (y < 0.04)
    sn = np.where(panel[:, None], srgb(132, 70, 146), sn)
    flash = side & (np.abs((z - 0.06) - (y + 0.12) * 0.6) < 0.012) & (y > -0.1) & (y < 0.06)
    sn = np.where(flash[:, None], srgb(232, 176, 40), sn)
    put(m, sn * (1.0 + 0.2 * c.wear - 0.2 * c.cavity)[:, None], 0.6, bump=0.5, grain=1.0)
    speck(m, srgb(150, 100, 70), 0.25)
    m = c.mask(SOLE)
    put(m, srgb(230, 220, 200) * (1.0 - 0.35 * c.cavity)[:, None], 0.7, bump=0.4)
    speck(m, srgb(140, 96, 64), 0.4)
    put(c.mask(LACE), srgb(236, 228, 210), 0.7)
    # the walkman: sunny yellow plastic, a grey screen, a pale wheel
    m = c.mask(WALKMAN)
    wm = np.broadcast_to(srgb(236, 172, 46), (n, 3)).copy()
    rel = P - WALKMAN_C
    front = N[:, 1] < -0.5
    screen = front & (np.abs(rel[:, 0] - 0.0) < 0.022) & (rel[:, 2] > 0.008) & (rel[:, 2] < 0.036)
    rr = np.sqrt((rel[:, 0] + 0.002) ** 2 + (rel[:, 2] + 0.016) ** 2)
    wm = np.where(screen[:, None], srgb(70, 78, 72), wm)
    wm = np.where((front & (rr < 0.02))[:, None], srgb(226, 222, 210), wm)
    wm = np.where((front & (rr < 0.0075))[:, None], srgb(236, 172, 46), wm)
    put(m, wm * (1.0 - 0.3 * c.cavity)[:, None], 0.35)
    c.draw(m & front & (rr < 0.026), np.abs(rr - 0.02), 0.0006, 0.5)
    put(c.mask(BUD), srgb(236, 232, 226), 0.3)

    ao = np.where(c.mask(TROUSERS) & (z < 0.7), 0.6 + 0.4 * c.ao, 0.3 + 0.7 * c.ao)     # lighter between the legs: those insides show in the stride
    c.col *= ao[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2700, "hair": 600, "body": 3700, "arms": 1500, "jewels": 700, "cables": 450},
    "density": {"head": 1.8, "arms": 1.2, "jewels": 0.8, "cables": 0.4},
    "tex": 2048,
    "stride": {"walk": 1.0, "run": 1.6},
    "speed": 1.0,
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.01, 1.25),
    "radius": 0.40,
}
BALL = v3((0.167, -0.16, 0.0))          # the chunky sneaker rolls near its toe: a pivot further back sinks the toe into the floor
STANCE_Y = 0.105         # hips over mid-foot: the ball sits far forward in his big sneakers


def rig_bones():
    from kit.rig import Bone, mirror
    fr = np.array([-1, 1, 1], np.float32)
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.03, 0.76), (0, 0.03, 0.9), "root", 0.2),
        Bone("spine", (0, 0.03, 0.9), (0, 0.02, 1.02), "hips", 0.22),
        Bone("chest", (0, 0.02, 1.02), (0, 0.03, 1.17), "spine", 0.2),
        Bone("neck", (0, 0.03, 1.17), (0, 0.01, 1.25), "chest", 0.09),
        Bone("head", (0, 0.01, 1.25), (0, 0.0, 1.56), "neck", 0.17),
        Bone("shoulder.L", (0.06, 0.03, 1.15), SHOULDER, "chest", 0.07),
        Bone("thigh.L", HIP_J, KNEE, "hips", 0.13),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.1),
        Bone("foot.L", ANKLE, TOE, "shin.L", 0.06),
    ])
    bones += [
        Bone("upper_arm.L", SHOULDER, ELBOW_L, "shoulder.L", 0.085),
        Bone("forearm.L", ELBOW_L, WRIST_L, "upper_arm.L", 0.06),
        Bone("hand.L", WRIST_L, WRIST_L - SHAKA[:, 2] * 0.12, "forearm.L", 0.04),
        Bone("upper_arm.R", SHOULDER * fr, ELBOW_R, "shoulder.R", 0.085),
        Bone("forearm.R", ELBOW_R, WRIST_R, "upper_arm.R", 0.06),
        Bone("hand.R", WRIST_R, WRIST_R + v3((0.0, -0.02, -0.08)), "forearm.R", 0.03),       # in the pocket, unweighted: the end the pocket IK aims
    ]
    return bones


def skin_rules(P, part, piece, names):
    """piece: 0 head, 1 hair, 2 body, 3 arms, 4 jewels, 5 cables"""
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
    rig[hp & (z > 1.24)] = ix["head"]
    rig[piece == 1] = ix["head"]
    allow(piece == 1, "head")
    jp = piece == 4
    allow(jp, "chest", "neck", "head")
    rig[jp & (part == BUD)] = ix["head"]
    rig[jp & (part == GOLD) & (np.abs(x) > 0.18)] = ix["head"]
    rig[jp & (part == GOLD) & (np.abs(x) <= 0.18)] = ix["chest"]
    cp = piece == 5
    allow(cp & (z > 1.24), "head")
    allow(cp & (z > 1.1), "neck")
    allow(cp & (z > 0.85), "chest", "spine")
    allow(cp & (z <= 0.95), "spine", "hips")
    bp = piece == 2
    legs = bp & ((np.isin(part, (TROUSERS, SNEAKER, SOLE, LACE)) | ((part == RIB) & (z < 0.5))) & (z < 0.74) | (z < 0.3))
    allow(legs, "hips")
    allow(legs & (x > -0.04), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.04), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.17) & (z > 1.0), "shoulder.L")
    allow(torso & (x < -0.17) & (z > 1.0), "shoulder.R")
    rig[torso & np.isin(part, (WALKMAN,))] = ix["hips"]
    ap = piece == 3
    allow(ap & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(ap & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R")
    allow(ap & (z > 1.06) & (np.abs(x) < 0.28), "chest")
    return A, rig


WALK = dict(stride=1.0, stance=0.58, foot_x=0.155, lift=0.075, bob=0.03, drop=0.05, sway=0.03, roll=6.0, yaw=9.0, counter=1.3,
            lean=2.0, toe_off=14.0, toe_out=10.0, swing_point=8.0)
RUN = dict(stride=1.6, stance=0.42, foot_x=0.14, lift=0.13, bob=0.04, drop=0.075, sway=0.022, roll=5.0, yaw=11.0, counter=1.4,
           lean=9.0, toe_off=18.0, toe_out=8.0, swing_point=12.0, spine_lean=3.0)
POCKET_WRIST = WRIST_R


def motions(rig):
    """walk: a bouncy groove (a double bounce in every step, shoulders shimmying, the head bobbing on the beat, the shaka pumping, the other hand
    staying in his pocket); run: a loping jog, the shaka held up; idle: grooving in place, knees bouncing to the beat, the shaka waggling"""
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
        """keep the right hand in the pocket: the wrist rides the hips"""
        Rh = p.delta.get("hips", Matrix.Identity(3))
        tgt = p.offset + hip_head + Rh @ (wr_r - hip_head)
        p.ik["upper_arm.R"] = (tgt, pole_r, "hand.R", None)

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.offset = p.offset + Vector((0.0, STANCE_Y, 0.0))
        s1, c1 = math.sin(TAU * u), math.cos(TAU * u)
        beat = math.sin(2 * TAU * u - 0.6)                    # one beat per step
        p.offset = p.offset + Vector((0.0, 0.0, (0.008 if not run else 0.0) * max(0.0, beat)))
        p.rot("chest", 2.0 * beat, 0, 7.0 * s1)                                  # the shoulders shimmy
        p.rot("upper_arm.L", 6.0 * c1, 0, 0)
        p.rot("forearm.L", -(8.0 if not run else 4.0) * beat, 0, 0)                # the shaka pumping on the beat
        p.rot("hand.L", 0, 0, 10.0 * s1)
        pocket(p)
        p.rot("neck", 4.0, 0, 0)
        p.world["head"] = R(2.0 + (9.0 if not run else 5.0) * max(0.0, beat) - 2.0, 3.0 * s1, -4.0 * c1)   # nodding to the music
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        beat = math.sin(TAU * t * 2.0)                        # two beats a second
        w = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector(BALL.tolist()), 12.0), "R": (Vector((BALL * f).tolist()), -12.0)},
              hip_shift=(0.02 * w, 0.0, -0.022 - 0.014 * max(0.0, beat)), roll=-3.0 * w, yaw=4.0 * w)
        p.rot("spine", 1.5 * beat, 0, 0)
        p.rot("chest", 1.0 * beat, 2.0 * w, 5.0 * math.sin(TAU * t))
        p.rot("forearm.L", -6.0 * max(0.0, beat), 0, 0)
        wag = math.sin(TAU * t * 2.0) * 22.0 * ease((t - 1.0) / 0.3) * (1.0 - ease((t - 2.6) / 0.3))      # the shaka waggle
        p.rot("hand.L", 0, 0, wag)
        pocket(p)
        p.world["head"] = R(-1.0 + 8.0 * max(0.0, beat), 4.0 * w, 8.0 * math.sin(TAU * t / 6.0))
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
