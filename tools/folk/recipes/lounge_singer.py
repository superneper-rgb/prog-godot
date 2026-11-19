## FOINT CITY townsfolk: the lounge singer (working name; the user names her). A tall yellow-green woman with dramatic swept purple hair, sultry lidded eyes, plum lips and dotted skin; a sequinned purple gown slit to the thigh, silver bangles, necklace and heels.
# Concept: the user's sheet, image 3 top (F:/prog-godot-cache/folk/refs/3.png). Measured off a 3x crop (1.64 mm a pixel): 1.85 m to the crown of her hair; a long head (chin 1.505,
# eyes 1.625, a broad forehead to 1.76) on a long thin neck; shoulders 1.32, a narrow waist at 1.02, hips 0.88; the mermaid gown hugs her to the knee and flares to the floor,
# slit up her left leg to 0.80; stiletto sandals 0.10 high. The mic stand is dropped (roster): her right hand rests on her hip, her left arm hangs free. The arms are their own piece.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, noise3, v3, basis, place)

HEIGHT = 1.85
REF = ("3.png", (27, 2, 250, 389))

SKIN, EYE, LIP, HAIR, GOWN, SILVER, NAIL, HEEL, LASH = range(1, 10)
COLOURS = {
    SKIN: ((0.52, 0.48, 0.22), 0.55, 0.0),
    EYE: ((0.80, 0.55, 0.15), 0.2, 0.0),
    LIP: ((0.30, 0.06, 0.12), 0.35, 0.0),
    HAIR: ((0.25, 0.08, 0.25), 0.5, 0.0),
    GOWN: ((0.08, 0.06, 0.25), 0.35, 0.0),
    SILVER: ((0.85, 0.85, 0.88), 0.2, 1.0),
    NAIL: ((0.30, 0.06, 0.12), 0.3, 0.0),
    HEEL: ((0.80, 0.80, 0.82), 0.25, 1.0),
    LASH: ((0.02, 0.02, 0.02), 0.6, 0.0),
}


def _unit(a):
    a = v3(a)
    return a / np.linalg.norm(a)


def bounded(s, lo, hi):
    s.lo, s.hi = v3(lo), v3(hi)
    return s


def _surface_y(shape, x, z, y0=-0.6, y1=0.3):
    ys = np.linspace(y0, y1, 1800, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


def prism(poly_xz, y0=-0.7, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


class Eye:
    """an eye: centre, radii (across, up, deep), where it looks, the lid edges' heights at the front of the ball (fractions of the up radius)"""
    def __init__(self, c, rad, fwd, roll=0.0, lid_up=0.3, lid_lo=0.5, arch=22.0, rim=0.006):
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
        return Ellipsoid(self.c - self.f * 0.003, (rs + self.rim * 1.3, ru + self.rim * 1.4, rf + self.rim * 0.8), R=self.M, part=SKIN)

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


# ---------------------------------------------------------------------------------------------------- the head: a broad brow, sultry lids, a small nose, full lips, a pointed chin, elfin ears
EYE_L = Eye((0.047, -0.092, 1.627), (0.034, 0.019, 0.021), (0.14, -0.99, 0.02), roll=-9.0, lid_up=0.2, lid_lo=0.55, arch=10.0, rim=0.007)    # big sultry eyes that read from a distance (round 2)
MOUTH_Z = 1.584
CRANIUM = Ellipsoid((0, 0.03, 1.665), (0.114, 0.124, 0.098))


def skull():
    return Union([
        CRANIUM,
        Ellipsoid((0, -0.025, 1.61), (0.1, 0.09, 0.072)),             # a wider face (round 2: the first read gaunt)
        Mirror(Ellipsoid((0.064, -0.06, 1.6), (0.044, 0.038, 0.03), R=rot(ry=-18))),         # full high cheekbones
        RoundCone((0, -0.025, 1.58), (0, -0.068, 1.512), 0.068, 0.02),       # the jaw tapering to a pointed chin
    ], k=0.04, part=SKIN)


def head():
    sk = skull()
    face = Union([sk, Mirror(EYE_L.mound())], k=0.012)
    face = Cut(face, [Mirror(EYE_L.opening())], k=0.0025)
    nose = Union([RoundCone((0, -0.099, 1.648), (0, -0.115, 1.613), 0.008, 0.0115, part=SKIN), Mirror(Ellipsoid((0.01, -0.106, 1.608), (0.0075, 0.0075, 0.0065), part=SKIN))], k=0.005)
    face = Union([face, nose], k=0.006)
    face = Cut(face, [Mirror(Ellipsoid((0.0065, -0.112, 1.604), (0.0028, 0.0045, 0.0025)))], k=0.0015)
    # full lips with a cupid's bow, the left corner curling up in a smirk
    up, lo = [], []
    for t in np.linspace(-1.0, 1.0, 19):
        x = 0.037 * t
        z = MOUTH_Z + 0.004 * t * t + 0.002 * t
        y = _surface_y(sk, x, z)
        bow = 0.0018 * np.exp(-((abs(t) - 0.3) / 0.25) ** 2)
        up.append((v3((x, y + 0.0042, z + 0.0038 + bow)), 0.0056 * (1.0 - 0.6 * t * t) + 0.0016))
        if abs(t) < 0.9:
            lo.append((v3((x, y + 0.0042, z - 0.006)), 0.0074 * (1.0 - 0.75 * t * t) + 0.0017))
    face = Union([face, loft(up, part=LIP, k=0.006), loft(lo, part=LIP, k=0.006)], k=0.003)
    face = Cut(face, [loft([(v3((0.034 * t, _surface_y(sk, 0.034 * t, MOUTH_Z) - 0.004, MOUTH_Z + 0.004 * t * t + 0.002 * t)), 0.0016) for t in np.linspace(-1, 1, 15)], k=0.003)], k=0.0015)
    # elfin ears sweeping back and down from the jaw's hinge
    ear = Union([RoundCone((0.086, 0.01, 1.575), (0.103, 0.088, 1.548), 0.017, 0.0025), Ellipsoid((0.088, 0.012, 1.566), (0.01, 0.017, 0.02))], k=0.008, part=SKIN)
    face = Union([face, Mirror(ear)], k=0.008)
    neck = RoundCone((0, 0.025, 1.29), (0, 0.005, 1.54), 0.058, 0.049, part=SKIN)      # long, but not a stick
    # lashes: a short wing off each outer corner
    lash = Mirror(RoundCone(EYE_L.c + EYE_L.s * 0.024 + EYE_L.f * 0.006 + EYE_L.u * 0.002, EYE_L.c + EYE_L.s * 0.038 + EYE_L.f * 0.0 + EYE_L.u * 0.008, 0.0018, 0.0008, part=LASH))
    return Union([Union([neck, face], k=0.02), Mirror(EYE_L.ball()), lash], k=0.0)


def hair():
    """big swept locks: from the hairline over the crown, back, out to her right and curling down, over a mass at the back of the head"""
    cap = Clip(Inflate(CRANIUM, 0.012, part=HAIR), [Half((0, 0.0, 1.76), (0, -0.8, -0.6)), Half((0, 0, 1.55), (0, 0.5, -1.0))], k=0.015)    # a high hairline: her broad brow bare
    # round 2: a great swept mass about as wide as her shoulders, fanning out to both sides and heaped to her right
    mass = Union([Ellipsoid((-0.03, 0.1, 1.665), (0.19, 0.15, 0.13)), Ellipsoid((-0.06, 0.12, 1.55), (0.17, 0.11, 0.11))], k=0.05, part=HAIR)
    locks = []
    rng = np.random.default_rng(4)
    for i in range(13):
        a = -1.25 + 2.5 * i / 12.0
        p0 = v3((0.09 * np.sin(a), 0.0 + 0.04 * abs(np.sin(a)), 1.77 - 0.045 * abs(np.sin(a))))
        out = 0.13 * np.sin(a) - 0.04 - 0.03 * rng.uniform()
        pts = []
        for t in np.linspace(0.0, 1.0, 7):
            p = p0 + v3((out * t, 0.17 * t, 0.075 * np.sin(np.pi * t * 0.9) - 0.2 * t ** 2.2))
            curl = max(0.0, t - 0.6) / 0.4
            p = p + v3((0.05 * np.sign(out) * curl, -0.03 * curl * curl, 0.05 * curl * curl))
            pts.append((p, 0.04 * (1.0 - 0.6 * t) + 0.006))
        locks.append(loft(pts, k=0.014))
    for i in range(6):
        p0 = v3((-0.1 + 0.04 * i, 0.12, 1.62))
        pts = [(p0 + v3((-0.05 * t - 0.06 * t * t + 0.04 * (i - 2.5) * t, 0.05 * t, -0.2 * t)), 0.034 * (1.0 - 0.6 * t) + 0.005) for t in np.linspace(0, 1, 5)]
        locks.append(loft(pts, k=0.012))
    hair = Union([cap, mass] + locks, k=0.018, part=HAIR)

    def strands(P):
        return np.cos(noise3(P, 0.06) * 6.0 + P[:, 0] * 160.0 + P[:, 2] * 60.0)
    return Bump(hair, strands, 0.0022)


EAR_RING = v3((0.093, 0.012, 1.508))


def jewels():
    hoop = Union([Torus(EAR_RING, 0.02, 0.0052, Rm=rot(ry=90), part=SILVER), RoundCone((0.091, 0.012, 1.548), (0.093, 0.012, 1.526), 0.004, 0.0035, part=SILVER)])
    # the necklace: one beaded rope (23 loose bead spheres decimated into flipped faces)
    pts = []
    for i in range(23):
        a = -np.pi * 0.98 + np.pi * 1.96 * i / 22
        pts.append((v3((0.06 * np.sin(a), 0.018 - 0.054 * np.cos(a), 1.337 - 0.016 * max(0.0, np.cos(a)) ** 2)), 0.0055))
    rope = Bump(loft(pts, part=SILVER, k=0.004), lambda P: np.cos(np.arctan2(P[:, 0], P[:, 1] - 0.018) * 40.0), 0.0012)
    return Union([Mirror(hoop), rope])


# ---------------------------------------------------------------------------------------------------- body: the gown, legs, heels
HIP_J = v3((0.085, 0.025, 0.86))
KNEE = v3((0.085, -0.01, 0.47))
ANKLE = v3((0.075, 0.035, 0.115))
BALL = v3((0.07, -0.10, 0.0))            # she rolls over the front of her sandals


def torso_core():
    return Union([
        Ellipsoid((0, 0.02, 1.215), (0.133, 0.092, 0.09)),
        Ellipsoid((0, 0.025, 1.29), (0.158, 0.075, 0.042)),
        Mirror(Ellipsoid((0.056, -0.058, 1.168), (0.06, 0.056, 0.055))),
        Ellipsoid((0, 0.012, 1.025), (0.108, 0.082, 0.08)),
        Ellipsoid((0, 0.03, 0.88), (0.178, 0.13, 0.11)),
    ], k=0.06)


def foot():
    """her foot pitched up on its stiletto: heel up at 0.06, arch, the ball and toes on the ground"""
    return Union([loft([(ANKLE + v3((0.0, 0.005, -0.01)), 0.028), (v3((0.072, -0.04, 0.047)), 0.026), (v3((0.07, -0.092, 0.02)), 0.02), (v3((0.07, -0.122, 0.016)), 0.014)], k=0.012),
                  Sphere((0.075, 0.052, 0.086), 0.024)], k=0.015)


def legs():
    # round 2: a real knee and calf (the leg shows in the slit)
    leg = Union([loft([(HIP_J, 0.085), (v3((0.087, -0.002, 0.66)), 0.068), (v3((0.086, -0.01, 0.52)), 0.052), (KNEE, 0.046), (v3((0.082, 0.02, 0.35)), 0.053),
                       (v3((0.08, 0.02, 0.25)), 0.04), (ANKLE + v3((0, -0.005, 0.03)), 0.028)], k=0.03),
                 Ellipsoid((0.086, -0.04, 0.47), (0.03, 0.02, 0.032))], k=0.02)
    return Union([leg, foot()], k=0.015, part=SKIN)


def heels():
    """silver sandals: a sole plate under the arch and the ball, a stiletto, an ankle strap, a strap over the toes"""
    f = foot()
    arch = Clip(Inflate(f, 0.0065, part=HEEL), [Half((0, -0.092, 0.011), (0.0, -0.383, 0.924)), Half((0, -0.085, 0), (0, -1, 0))], k=0.002)
    fore = Clip(Inflate(f, 0.0065, part=HEEL), [Half((0, 0, 0.011), (0, 0, 1)), Half((0, -0.085, 0), (0, 1, 0))], k=0.002)
    stiletto = RoundCone((0.075, 0.056, 0.064), (0.075, 0.066, 0.004), 0.0075, 0.0042, part=HEEL)
    strap = Torus(ANKLE + v3((0.0, -0.003, 0.016)), 0.0315, 0.0055, Rm=rot(rx=8), part=HEEL)
    toe = Clip(Inflate(f, 0.0055, part=HEEL), [Half((0, -0.104, 0), (0, -1, 0)), Half((0, -0.078, 0), (0, 1, 0)), Half((0, 0, 0.012), (0, 0, -1))], k=0.002)
    return Mirror(Union([arch, fore, stiletto, strap, toe], k=0.003))


def gown():
    core = torso_core()
    bodice = Clip(Inflate(core, 0.006, part=GOWN), [Half((0, 0, 0.8), (0, 0, -1))], k=0.004)
    # the neckline: a sweetheart dipping between the cups, rising to thin straps
    neck = prism([(-0.2, 1.42), (0.2, 1.42), (0.2, 1.23), (0.12, 1.215), (0.07, 1.20), (0.035, 1.205), (0.0, 1.17), (-0.035, 1.205), (-0.07, 1.20), (-0.12, 1.215), (-0.2, 1.23)], y0=-0.5, y1=0.6)
    straps = Mirror(Clip(Inflate(core, 0.006), [Half((0.082, 0, 0), (-1, 0, 0)), Half((0.094, 0, 0), (1, 0, 0))], k=0.002))
    bodice = Cut(bodice, [Cut(neck, [straps])], k=0.003)
    bodice = Union([bodice, Clip(straps, [Half((0, 0, 1.2), (0, 0, -1))])], k=0.002, part=GOWN)
    # the skirt: hugging the hips and thighs to the knee, then flaring into a train on the floor
    skirt = Union([
        Ellipsoid((0, 0.03, 0.86), (0.2, 0.145, 0.14)),
        Ellipsoid((0, 0.02, 0.6), (0.19, 0.14, 0.33)),           # wide enough that her legs never poke through as they stride
        CappedCone((0, 0.04, 0.44), (0, 0.07, 0.0), 0.14, 0.3),
    ], k=0.1, part=GOWN)
    skirt = Clip(skirt, [Half((0, 0, 0.004), (0, 0, -1)), Half((0, 0, 1.0), (0, 0, 1))], k=0.004)

    def drape(P):
        # the wrap: diagonal folds gathered at her right hip, falling across to her left; soft folds round the flare
        d = (P[:, 0] * 0.8 + P[:, 2]) * 90.0
        hip = np.clip(1.0 - np.abs(P[:, 2] - 0.82) / 0.2, 0, 1) * (P[:, 1] < 0.05)
        a = np.arctan2(P[:, 0], P[:, 1] - 0.05)
        low = np.clip((0.45 - P[:, 2]) / 0.3, 0, 1)
        return np.sin(d) * hip + np.sin(a * 9.0 + noise3(P, 0.08) * 1.0) * low * 2.0
    skirt = Bump(skirt, drape, 0.0025)
    # the slit up her left leg: the gown cut away in front of the leg down to the floor
    left = legs()
    skirt = Cut(skirt, [prism([(0.035, 0.80), (0.115, 0.80), (0.2, 0.0), (0.02, 0.0)], y0=-0.6, y1=-0.005)], k=0.008)      # the front only: the gown still wraps the back of the leg
    skin = Union([torso_core()], part=SKIN)          # her bare shoulders, back and chest above the neckline
    return Union([skin, bodice, skirt], k=0.012), left


# ---------------------------------------------------------------------------------------------------- arms (their own piece): her right hand on her hip, her left arm hanging free
SHOULDER = v3((0.163, 0.02, 1.295))
ELBOW_L = v3((0.205, 0.04, 1.045))
WRIST_L = v3((0.232, -0.005, 0.83))
HAND_L = basis(-(WRIST_L - ELBOW_L), v3((0.35, 1.0, 0.0)))
ELBOW_R = v3((-0.315, 0.07, 1.10))
WRIST_R = v3((-0.175, -0.035, 0.955))
HAND_R = basis(v3((-0.25, 0.8, 0.45)), v3((-0.6, 0.0, -0.2)))       # on the hip: the fingers forward and down over the gown, the back of the hand out


def hand_soft(curl=1.0):
    """a slim hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y), the fingers gently curved, long nails"""
    palm = Ellipsoid((0.0, 0.0, -0.043), (0.013, 0.031, 0.043), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.024, 0.021, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.02, 0.92), (-0.0068, 1.0), (0.0068, 0.97), (0.02, 0.8)):
        pts = [((0.0, f, -0.076), 0.0078), ((-0.006 * curl, f, -0.076 - 0.03 * L), 0.0072), ((-0.016 * curl, f, -0.076 - 0.055 * L), 0.0064), ((-0.026 * curl, f * 1.1, -0.076 - 0.07 * L), 0.0056)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.003))
        tip = v3(pts[-1][0])
        parts.append(Ellipsoid(tip + v3((0.002, 0, -0.004)), (0.0042, 0.0058, 0.0075), part=NAIL))
    parts.append(loft([(v3((-0.006, -0.024, -0.025)), 0.0105), (v3((-0.016, -0.04, -0.055)), 0.0085), (v3((-0.024, -0.042, -0.078)), 0.0072)], part=SKIN, k=0.003))
    return Union(parts, k=0.006)


def arm_l():
    return loft([(SHOULDER, 0.043), (ELBOW_L, 0.032), (WRIST_L, 0.025)], part=SKIN, k=0.015)


def arm_r():
    return loft([(SHOULDER * np.array([-1, 1, 1], np.float32), 0.043), (ELBOW_R, 0.032), (WRIST_R, 0.025)], part=SKIN, k=0.015)


def hands():
    """the hands, bangles and ring: their own piece (decimated with the arms they were squeezed under 1.5% and flipped faces caught the light)"""
    out = []
    for wr, el, rm, curl, up in ((WRIST_L, ELBOW_L, HAND_L, 0.8, v3((0, 1, 0))), (WRIST_R, ELBOW_R, HAND_R, 0.35, v3((0, 0, 1)))):
        d = _unit(wr - el)
        stub = RoundCone(wr - d * 0.04, wr, 0.0262, 0.025, part=SKIN)          # overlaps the arm's end under the bangles
        bang = [Torus(wr - d * (0.011 + 0.0105 * i), 0.0255 + 0.0015 * i, 0.005, Rm=basis(d, up), part=SILVER) for i in range(3)]   # sunk into the wrist
        out.append(Union([Union([stub, place(hand_soft(curl), wr, rm)], k=0.007)] + bang))
    out.append(Torus(WRIST_R + HAND_R @ v3((0.0, -0.0068, -0.1)), 0.0098, 0.003, Rm=HAND_R, part=SILVER))
    return Union(out)


def pieces():
    g, left = gown()
    body = Union([g, left, Move(legs(), R=np.diag([-1, 1, 1]).astype(np.float32)), heels()], k=0.0)
    return [("head", head(), 0.0016), ("hair", hair(), 0.0025), ("body", body, 0.0032), ("arms", Union([arm_l(), arm_r()]), 0.0024), ("jewels", jewels(), 0.0013),
            ("hands", hands(), 0.0018)]


# ---------------------------------------------------------------------------------------------------- paint (kit/paint.py fills the shader's layers from these)

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

    # skin: yellow-green, paler on the brow and cheekbones, dappled with rusty patches and spots
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(198, 188, 116), (n, 3)).copy()
    sk = sk + (srgb(218, 210, 146) - sk) * (smooth(0.3, 0.9, N[:, 2]) * 0.35)[:, None]
    patch = smooth(0.25, 0.55, noise3(P + 3.1, 0.045) * 0.7 + noise3(P, 0.015) * 0.3)
    sk = sk + (srgb(170, 112, 84) - sk) * (patch * 0.45)[:, None]
    blush = smooth(1.0, 0.2, np.linalg.norm((Q - v3((0.06, -0.07, 1.6))) / v3((0.03, 0.03, 0.022)), axis=1))
    sk = sk + (srgb(196, 120, 110) - sk) * (blush * 0.4)[:, None]
    sk *= (1.0 + 0.06 * mott)[:, None]
    # her lids: a plum shadow over the heavy upper lid, inked liner swept into a wing, a drawn arched brow
    for sx in (1.0, -1.0):
        PP = P * np.array([sx, 1, 1], np.float32)
        q = EYE_L.local(PP)
        rq = np.linalg.norm(q, axis=1)
        dball = (rq - 1.0) * float(EYE_L.rad[1])
        side = m & (PP[:, 0] > 0)
        lid = side & (rq < 2.6) & (q[:, 1] > 0.0) & (q[:, 2] > -0.3)
        sk = np.where(lid[:, None], sk + (srgb(140, 96, 120) - sk) * (smooth(0.02, 0.004, dball) * 0.55)[:, None], sk)
        c.draw(side & (rq < 2.2) & (q[:, 1] > -0.3) & (dball < 0.008) & (q[:, 2] > -0.2), np.abs(dball), 0.0026, 1.0)
        wing_t = (q[:, 0] - 0.9) / 1.1
        wing = side & (wing_t > 0) & (wing_t < 1) & (np.abs(q[:, 1] - 0.15 - 0.9 * wing_t) < 0.6) & (q[:, 2] > -0.5)
        c.draw(wing, np.abs(q[:, 1] - 0.15 - 0.9 * wing_t) * float(EYE_L.rad[1]), 0.0016 * (1.0 - wing_t) + 0.0003)
        bt = (PP[:, 0] - 0.018) / 0.058
        bz = 1.683 + 0.012 * np.sin(np.pi * np.clip(bt * 0.85 + 0.1, 0, 1)) - 0.008 * np.clip(bt, 0, 1) ** 2
        brow = side & (bt > 0) & (bt < 1) & (y < -0.04) & (np.abs(z - bz) < 0.006)
        c.draw(brow, np.abs(z - bz), 0.0012 * (1.0 - 0.6 * bt) + 0.0003, 0.95)
    put(m, sk, 0.45, bump=0.12)
    speck(m, srgb(150, 86, 64), 0.32)
    # eyes: amber irises looking down her nose, inked pupils
    m = c.mask(EYE)
    for sx in (1.0, -1.0):
        PP = P * np.array([sx, 1, 1], np.float32)
        q = EYE_L.local(PP)
        qn = q / np.maximum(np.linalg.norm(q, axis=1), 1e-6)[:, None]
        mine = m & (PP[:, 0] > 0)
        g = _unit((-0.15, -0.05, 0.98))
        ang = np.arccos(np.clip(qn @ g, -1, 1))
        col = np.where((ang < 0.62)[:, None], srgb(212, 150, 46) + (srgb(150, 86, 20) - srgb(212, 150, 46)) * smooth(0.2, 0.6, ang)[:, None], srgb(236, 222, 196))
        col *= (1.0 - 0.45 * smooth(-0.3, 0.5, qn[:, 1]))[:, None]
        c.col[mine] = col[mine]
        c.draw(mine, (ang - 0.26) * 0.02, 0.0)
    c.rough[m] = 0.08
    # lips and nails: glossy plum
    m = c.mask(LIP)
    put(m, np.where((z < MOUTH_Z)[:, None], srgb(132, 42, 74), srgb(108, 30, 60)) * (1.0 + 0.5 * c.wear)[:, None], 0.22)
    c.draw(c.mask(LIP, SKIN) & (np.abs(x) < 0.036) & (np.abs(z - MOUTH_Z - 0.002 * x / 0.033) < 0.006) & (y < -0.07), np.abs(z - MOUTH_Z - 0.002 * x / 0.033), 0.0007)
    put(c.mask(NAIL), srgb(110, 32, 64) * (1.0 + 0.6 * c.wear)[:, None], 0.2)
    put(c.mask(LASH), srgb(14, 10, 14), 0.6)
    # hair: purple locks, pink on the ridges, near black in the grooves
    m = c.mask(HAIR)
    hc = srgb(120, 56, 112) + (srgb(196, 112, 168) - srgb(120, 56, 112)) * (c.wear * 0.6)[:, None]
    put(m, hc * (1.0 - 0.5 * c.cavity + 0.06 * mott)[:, None], 0.4, bump=0.6)
    # the gown: deep indigo velvet sewn with sequins that catch the light
    m = c.mask(GOWN)
    gw = srgb(56, 44, 128) * (1.0 + 0.08 * mott - 0.3 * c.cavity)[:, None]
    put(m, gw, 0.7, metal=0.0, bump=0.4)          # the sparkle is in the sequin flecks: a shiny metal gown flashed white at her waist
    speck(m, srgb(150, 140, 236), 0.62)
    put(c.mask(SILVER), srgb(226, 226, 232) * (1.0 - 0.4 * c.cavity)[:, None], 0.32, metal=1.0, bump=0.05, grain=1.0)
    put(c.mask(HEEL), srgb(214, 214, 222) * (1.0 - 0.3 * c.cavity)[:, None], 0.2, metal=1.0)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2300, "hair": 1500, "body": 3800, "arms": 600, "jewels": 500, "hands": 1100},
    "density": {"head": 1.9, "hair": 1.0, "arms": 1.0, "jewels": 0.8, "hands": 1.4},
    "tex": 2048,
    "stride": {"walk": 0.72, "run": 1.3},
    "speed": 0.85,
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.005, 1.53),
    "radius": 0.36,
}
STANCE_Y = 0.05         # hips over mid-foot, the weight forward on the balls of her feet as in heels


def rig_bones():
    from kit.rig import Bone, mirror
    fr = np.array([-1, 1, 1], np.float32)
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.025, 0.86), (0, 0.02, 1.0), "root", 0.16),
        Bone("spine", (0, 0.02, 1.0), (0, 0.015, 1.15), "hips", 0.12),
        Bone("chest", (0, 0.015, 1.15), (0, 0.02, 1.3), "spine", 0.12),
        Bone("neck", (0, 0.02, 1.3), (0, 0.005, 1.53), "chest", 0.045),
        Bone("head", (0, 0.005, 1.53), (0, 0.0, 1.78), "neck", 0.12),
        Bone("shoulder.L", (0.04, 0.02, 1.28), SHOULDER, "chest", 0.045),
        Bone("thigh.L", HIP_J, KNEE, "hips", 0.085),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.055),
        Bone("foot.L", ANKLE, BALL + v3((0, 0, 0.02)), "shin.L", 0.03),
    ])
    bones += [
        Bone("upper_arm.L", SHOULDER, ELBOW_L, "shoulder.L", 0.043),
        Bone("forearm.L", ELBOW_L, WRIST_L, "upper_arm.L", 0.032),
        Bone("hand.L", WRIST_L, WRIST_L - HAND_L[:, 2] * 0.09, "forearm.L", 0.022),
        Bone("upper_arm.R", SHOULDER * fr, ELBOW_R, "shoulder.R", 0.043),
        Bone("forearm.R", ELBOW_R, WRIST_R, "upper_arm.R", 0.032),
        Bone("hand.R", WRIST_R, WRIST_R - HAND_R[:, 2] * 0.09, "forearm.R", 0.022),
    ]
    return bones


def skin_rules(P, part, piece, names):
    """piece: 0 head, 1 hair, 2 body, 3 arms, 4 jewels, 5 hands"""
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
    rig[hp & (z > 1.52)] = ix["head"]
    rig[piece == 1] = ix["head"]
    allow(piece == 1, "head")
    jp = piece == 4
    allow(jp, "chest", "neck", "head")
    rig[jp & (z > 1.42)] = ix["head"]
    rig[jp & (z <= 1.42)] = ix["neck"]
    bp = piece == 2
    legs = bp & (z < 0.84)
    allow(legs, "hips")
    limb = legs & ((part != GOWN) | (z > 0.45))             # below the knee the gown hangs from the hips and thighs, so its hem never flips up behind a swinging shin
    allow(legs & (x > -0.035), "thigh.L")
    allow(legs & (x < 0.035), "thigh.R")
    allow(limb & (x > -0.035), "shin.L", "foot.L")
    allow(limb & (x < 0.035), "shin.R", "foot.R")
    rig[bp & (part == HEEL) & (x > 0)] = ix["foot.L"]
    rig[bp & (part == HEEL) & (x <= 0)] = ix["foot.R"]
    torso = bp & ~legs
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.1) & (z > 1.18), "shoulder.L")
    allow(torso & (x < -0.1) & (z > 1.18), "shoulder.R")
    ap = (piece == 3) | (piece == 5)
    allow(ap & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(ap & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(ap & (z > 1.2) & (np.abs(x) < 0.18), "chest")
    return A, rig


WALK = dict(stride=0.72, stance=0.6, foot_x=0.018, lift=0.045, bob=0.01, drop=0.055, sway=0.045, roll=9.0, yaw=8.0, counter=1.4,
            lean=-1.0, toe_off=8.0, toe_out=5.0, swing_point=4.0)
RUN = dict(stride=1.3, stance=0.42, foot_x=0.03, lift=0.09, bob=0.025, drop=0.075, sway=0.03, roll=7.0, yaw=9.0, counter=1.4,
           lean=7.0, toe_off=16.0, toe_out=5.0, swing_point=8.0, spine_lean=2.0)


def motions(rig):
    """walk: a slinky catwalk in heels (feet crossing onto one line, the hips rolling and swaying wide, the shoulders countering, chin up, her right hand
    kept on her hip, the left arm swinging loose from a limp wrist); run: a tottering hurry; idle: weight slung on one hip, a fluff of the hair"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    hip_head = Vector(rig.head["hips"])
    sh_r, el_r, wr_r = Vector((SHOULDER * f).tolist()), Vector(ELBOW_R.tolist()), Vector(WRIST_R.tolist())
    line = (wr_r - sh_r).normalized()
    pole_r = ((el_r - sh_r) - line * (el_r - sh_r).dot(line)).normalized()
    hand_r_rest = Matrix(HAND_R.tolist())

    def on_hip(p):
        """her right hand rides her hip"""
        Rh = p.delta.get("hips", Matrix.Identity(3))
        tgt = p.offset + hip_head + Rh @ (wr_r - hip_head)
        p.ik["upper_arm.R"] = (tgt, pole_r, "hand.R", Rh)

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.offset = p.offset + Vector((0.0, STANCE_Y, 0.0))
        s1, c1 = math.sin(TAU * u), math.cos(TAU * u)
        p.rot("upper_arm.L", (26.0 if run else 13.0) * c1, 0, 0)
        p.rot("forearm.L", -(40.0 if run else 6.0) - (14.0 if run else 6.0) * max(0.0, -c1), 0, 0)
        p.rot("hand.L", 12.0 + 10.0 * math.sin(TAU * u - 1.2), 0, 0)              # the limp wrist trailing the swing
        on_hip(p)
        p.rot("neck", -3.0, 0, 0)
        p.world["head"] = R(-4.0 + 1.0 * math.sin(2 * TAU * u), 3.0 * s1, -3.0 * c1)    # chin up, the head steady over the rolling hips
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    sh_l, el_l, wr_l = Vector(SHOULDER.tolist()), Vector(ELBOW_L.tolist()), Vector(WRIST_L.tolist())
    pole_l = Vector((0.6, 0.3, -0.75)).normalized()
    hair_at = Vector((0.115, 0.06, 1.64))
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        b = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.07, -0.13, 0.0)), 14.0), "R": (Vector((-0.06, -0.06, 0.0)), -4.0)},
              hip_shift=(-0.035 + 0.008 * w, 0.0, -0.018), roll=6.0 + 1.5 * w, yaw=-6.0)
        p.rot("spine", 1.0 * b, -4.0, 3.0)
        p.rot("chest", 1.2 * b, -3.0, 2.0 * w)
        on_hip(p)
        fl = ease((t - 2.0) / 0.6) * (1.0 - ease((t - 3.6) / 0.6))           # a fluff of her hair (2 s to 4 s)
        pat = 0.02 * math.sin(TAU * (t - 2.0) * 2.0) * fl
        tgt = wr_l.lerp(hair_at + Vector((0.0, pat, pat)), fl)
        p.ik["upper_arm.L"] = (tgt, pole_l.lerp(Vector((0.9, 0.3, 0.3)).normalized(), fl).normalized(), "hand.L", None)
        p.rot("hand.L", 30.0 * fl, 0, 0)
        p.world["head"] = R(-5.0 - 3.0 * fl + 1.0 * b, -6.0 * fl + 3.0 * w, 8.0 * math.sin(TAU * t / 6.0 + 0.5))
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
