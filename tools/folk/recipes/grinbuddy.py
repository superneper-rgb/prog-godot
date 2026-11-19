## FOINT CITY townsfolk: grinbuddy. A short round sunny-yellow fellow who is always delighted: one big ball of a body that is mostly grin (a huge open smile full of teeth), smiling eyes squeezed up by round rosy cheeks, raised brows, a single curly hair, a red bow tie, little navy trousers and shiny black shoes; he skips.
# Upgrade of the three.js game's grinbuddy (folk-species-c.js; old render refs/old/grinbuddy.png): same idea (a yellow ball, two eyes, pink
# blush and nose, an enormous toothy grin, one hair on top, short dark legs, black shoes, stubby arms), lifted to the new sheets (refs 4/6/7).
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 1.10
REF = ("old/grinbuddy.png", None)

SKIN, EYE, MOUTH, TOOTH, TONGUE, BROW, HAIR, TIE, TROUSERS, SHOE, SOLE, NAIL, BUTTON = range(1, 14)
COLOURS = {
    SKIN: ((0.85, 0.62, 0.08), 0.5, 0.0),
    EYE: ((0.9, 0.9, 0.86), 0.15, 0.0),
    MOUTH: ((0.2, 0.03, 0.04), 0.6, 0.0),
    TOOTH: ((0.92, 0.9, 0.82), 0.3, 0.0),
    TONGUE: ((0.8, 0.3, 0.35), 0.4, 0.0),
    BROW: ((0.35, 0.2, 0.08), 0.8, 0.0),
    HAIR: ((0.2, 0.12, 0.06), 0.6, 0.0),
    TIE: ((0.7, 0.06, 0.06), 0.4, 0.0),
    TROUSERS: ((0.08, 0.1, 0.25), 0.8, 0.0),
    SHOE: ((0.02, 0.02, 0.02), 0.2, 0.0),
    SOLE: ((0.1, 0.07, 0.05), 0.6, 0.0),
    NAIL: ((0.8, 0.6, 0.2), 0.3, 0.0),
    BUTTON: ((0.8, 0.6, 0.2), 0.3, 1.0),
}
UP = v3((0, 0, 1))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# landmarks, left side (+X); the figure faces -Y
BODY_C = v3((0.0, 0.0, 0.625))
BODY_R = (0.36, 0.305, 0.4)
HIP = v3((0.12, 0.005, 0.36))
KNEE = v3((0.125, -0.012, 0.225))
ANKLE = v3((0.128, 0.008, 0.088))
BALL = v3((0.13, -0.06, 0.0))
SHOULDER = v3((0.30, 0.0, 0.70))
ELBOW = v3((0.46, -0.015, 0.63))
WRIST = v3((0.535, -0.04, 0.53))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
EYE_C = v3((0.122, -0.218, 0.855))
EYE_R = 0.056
LOOK = unit((0.0, -1.0, 0.1))
WAIST = 0.42
HAIR_PTS = [v3((0.0, 0.01, 1.0)), v3((0.008, -0.004, 1.05)), v3((0.03, -0.02, 1.08)), v3((0.05, -0.006, 1.095)), v3((0.052, 0.018, 1.08)), v3((0.036, 0.024, 1.064))]


def ball():
    return Union([Ellipsoid(BODY_C, BODY_R), Ellipsoid(BODY_C + v3((0, 0.01, -0.12)), (0.37, 0.31, 0.28))], k=0.08, part=SKIN)


def front_y(shape, x, z, y0=-0.6, y1=0.3):
    ys = np.linspace(y0, y1, 1801).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    return float(ys[int(np.argmax(shape.eval(P)[0] < 0))])


MOUTH_LO = Ellipsoid((0, -0.27, 0.64), (0.215, 0.17, 0.15))
MOUTH_HI = Ellipsoid((0, -0.33, 0.785), (0.31, 0.22, 0.105))


def body():
    b = ball()
    cheeks = Mirror(Ellipsoid((0.19, -0.215, 0.725), (0.085, 0.07, 0.07), part=SKIN))
    nose = Sphere((0.0, -0.3, 0.79), 0.03, part=SKIN)
    brows = Mirror(Ellipsoid((0.125, -0.162, 0.942), (0.056, 0.018, 0.013), R=rot(rx=-38) @ rot(ry=10), part=SKIN))
    face = Union([b, cheeks, brows], k=0.04)
    # the eyes: balls set in the face, lower lids pushed up by the cheeks into a happy squint, upper lids raised
    lids = []
    for s in (1.0, -1.0):
        ec = EYE_C * np.array([s, 1, 1], np.float32)
        lids.append(Clip(Ellipsoid(ec, (EYE_R + 0.007, EYE_R + 0.005, EYE_R + 0.007), part=SKIN), [Half(ec + v3((0, 0, EYE_R * 0.86)), (0, -0.25, -1))], k=0.004))
        lids.append(Clip(Ellipsoid(ec, (EYE_R + 0.008, EYE_R + 0.006, EYE_R + 0.008), part=SKIN), [Half(ec - v3((0, 0, EYE_R * 0.5)), (0, 0.15, 1))], k=0.005))
    face = Union([face] + lids + [nose], k=0.01)
    # the grin: a huge crescent, deep; lips rolled round it; a row of square teeth along the top; a tongue
    cav = Cut(MOUTH_LO, [MOUTH_HI], k=0.012)
    lips = Clip(Inflate(cav, 0.014, part=SKIN), [Inflate(b, 0.009)], k=0.005)
    face = Cut(Union([face, lips], k=0.008), [cav], k=0.006)
    throat = Ellipsoid((0, -0.17, 0.64), (0.2, 0.06, 0.12), part=MOUTH)
    teeth = []
    for i in range(-3, 4):
        x = i * 0.044
        top = 0.785 - 0.105 * np.sqrt(max(0.0, 1.0 - (x / 0.31) ** 2)) + 0.012
        y = front_y(b, x, top - 0.02) + 0.018
        teeth.append(Box((x, y, top - 0.022), (0.02, 0.012, 0.028), rr=0.008, part=TOOTH))
    tongue = Union([Ellipsoid((0, -0.2, 0.545), (0.12, 0.08, 0.04)), Ellipsoid((0.0, -0.25, 0.55), (0.08, 0.04, 0.03))], k=0.03, part=TONGUE)
    eyes = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    hair = loft([(p, 0.009 - 0.0007 * i) for i, p in enumerate(HAIR_PTS)], part=HAIR, k=0.006)
    return Union([face, throat, tongue, eyes, hair] + teeth, k=0.0)


def clothes():
    b = ball()
    pants = Union([
        Inflate(b, 0.014),
        Mirror(loft([(HIP, 0.085), (KNEE, 0.072), (ANKLE + v3((0, 0, 0.05)), 0.066)])),
    ], k=0.05, part=TROUSERS)
    pants = Clip(pants, [Half((0, 0, WAIST), (0, 0, 1)), Half((0, 0, 0.115), (0, 0, -1))], k=0.004)
    band = Clip(Inflate(b, 0.02, part=TROUSERS), [Half((0, 0, WAIST), (0, 0, 1)), Half((0, 0, WAIST - 0.03), (0, 0, -1))], k=0.004)
    buttons = Mirror(Sphere((0.14, front_y(Inflate(b, 0.02), 0.14, WAIST - 0.016) - 0.002, WAIST - 0.016), 0.012, part=BUTTON))
    ty = front_y(b, 0.0, 0.468)
    knot = Box((0, ty - 0.016, 0.468), (0.02, 0.014, 0.018), rr=0.008, part=TIE)
    wing = Slab((0, 0, 0), [(0.0, -0.01), (0.06, -0.032), (0.07, 0.0), (0.06, 0.032), (0.0, 0.01)], 0.009, rr=0.006, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32), part=TIE)
    bow = Union([knot, Mirror(Move(wing, t=(0.004, ty - 0.008, 0.468)))], k=0.008)
    return Union([pants, band, buttons, bow], k=0.0)


def shoe():
    x = ANKLE[0]
    last = Union([
        loft([(ANKLE + v3((0, 0.012, 0.0)), 0.048), (v3((x + 0.002, -0.055, 0.045)), 0.052), (v3((x + 0.004, -0.12, 0.04)), 0.046)], k=0.02),
        Ellipsoid((x + 0.004, -0.125, 0.04), (0.054, 0.056, 0.04)),
    ], k=0.02)
    upper = Clip(Inflate(last, 0.0, part=SHOE), [Half((0, 0, 0.024), (0, 0, -1))], k=0.003)
    sole = Clip(Inflate(last, 0.006, part=SOLE), [Half((0, 0, 0.026), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    strap = Clip(Inflate(last, 0.004, part=SHOE), [Half((0, -0.03, 0), (0, 1, 0.2)), Half((0, -0.012, 0), (0, -1, -0.2)), Half((0, 0, 0.04), (0, 0, -1))], k=0.002)
    buckle = Box((x + 0.05, -0.02, 0.07), (0.004, 0.012, 0.012), rr=0.003, part=BUTTON)
    return Union([upper, sole, strap, buckle], k=0.004)


def hand(s=1.0):
    """a chubby four-fingered hand in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y), held open as if about to wave"""
    palm = Ellipsoid((0.0, 0.0, -0.04), (0.02, 0.038, 0.042), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.01), 0.034, 0.03, part=SKIN)
    parts = [palm, wrist]
    for f, L, spread in ((-0.027, 0.8, -0.12), (-0.009, 1.0, -0.04), (0.009, 0.95, 0.04), (0.027, 0.78, 0.12)):
        pts = [((0.0, f, -0.07), 0.0125), ((-0.004, f + spread * 0.025 * L, -0.07 - 0.026 * L), 0.0118), ((-0.012, f + spread * 0.05 * L, -0.07 - 0.048 * L), 0.011)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
    parts.append(loft([(v3((-0.01, -0.03, -0.025)), 0.014), (v3((-0.022, -0.05, -0.048)), 0.0125), (v3((-0.03, -0.058, -0.066)), 0.0115)], part=SKIN, k=0.004))
    return Union(parts, k=0.008)


def arm():
    a = loft([(SHOULDER, 0.06), (ELBOW, 0.048), (WRIST, 0.042)], part=SKIN, k=0.015)
    return Union([a, place(hand(), WRIST, HAND)], k=0.012)


def pieces():
    b = Union([body(), clothes(), Mirror(shoe()), Mirror(arm())], k=0.0)
    return [("body", b, 0.0028)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n1 = noise3(P, 0.06)
    n2 = noise3(P, 0.012)
    mott = n1 * 0.5 + n2 * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (m.sum(), 3)), np.broadcast_to(np.asarray(amt, np.float32), (m.sum(),))[:, None]], 1)

    # skin: sunny yellow, warmer orange underneath and round the sides, rosy cheeks and nose, freckles across the cheeks
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(255, 204, 24), (len(P), 3)).copy()
    sk = sk + (srgb(240, 160, 40) - sk) * (smooth(0.6, 0.3, z) * 0.35 + smooth(0.15, 0.32, y) * 0.2)[:, None]
    sk = sk + (srgb(255, 230, 120) - sk) * (smooth(0.85, 1.0, z) * 0.35)[:, None]
    blush = smooth(0.075, 0.0, np.linalg.norm(Q - v3((0.19, -0.24, 0.73)), axis=1))
    sk = sk + (srgb(244, 110, 100) - sk) * (blush * 0.9)[:, None]
    nose = smooth(0.035, 0.015, np.linalg.norm(P - v3((0.0, -0.3, 0.79)), axis=1))
    sk = sk + (srgb(236, 116, 104) - sk) * (nose * 0.8)[:, None]
    sk *= (1.0 + 0.07 * mott)[:, None]
    inside = m & (Cut(MOUTH_LO, [MOUTH_HI], k=0.012).eval(P)[0] < 0.004)
    sk[inside] = srgb(110, 22, 30)
    put(m, sk, 0.45, bump=0.25)
    fr = m & (np.linalg.norm(Q - v3((0.19, -0.24, 0.75)), axis=1) < 0.06)
    spk(fr, (200, 110, 40), 0.55)
    spk(m & ~fr, (226, 166, 40), 0.15)
    # eyes: big brown irises looking up and out at the world, a double glint; liners; smile creases under each
    m = c.mask(EYE)
    ey = np.broadcast_to(srgb(248, 246, 238), (len(P), 3)).copy()
    for s in (1.0, -1.0):
        ec = EYE_C * np.array([s, 1, 1], np.float32)
        dv = P - ec
        r = np.linalg.norm(dv, axis=1)
        near = m & (r < EYE_R * 1.25)
        dd = dv / np.maximum(r, 1e-6)[:, None]
        ang = np.arccos(np.clip(dd @ LOOK, -1, 1))
        ir = srgb(120, 74, 30) + (srgb(60, 30, 12) - srgb(120, 74, 30)) * smooth(0.2, 0.55, ang)[:, None]
        ey[near] = np.where((ang < 0.58)[near, None], ir[near], ey[near])
        c.draw(near, (ang - 0.3) * EYE_R, 0.0)
        for gd, sz in ((unit(LOOK + v3((0.3, 0, 0.5))), 0.2), (unit(LOOK + v3((-0.2, 0, -0.2))), 0.09)):
            g = smooth(sz, sz * 0.55, np.arccos(np.clip(dd @ gd, -1, 1)))
            ey[near] = ey[near] + (srgb(255, 255, 255) - ey[near]) * g[near, None]
        lm = c.mask(SKIN) & (r < EYE_R + 0.013) & (dv[:, 1] < 0.012)
        c.draw(lm & (dv[:, 2] > 0.0), np.abs(r - EYE_R - 0.002), 0.0018, 0.95)
        cr = c.mask(SKIN) & (r < EYE_R + 0.04) & (dv[:, 2] < -EYE_R * 0.4) & (dv[:, 1] < 0.0)
        c.draw(cr, np.abs(r - EYE_R - 0.022), 0.0012, 0.45)
    put(m, ey, 0.06)
    c.spk[m, 3] = 0.0
    # brows: drawn on the brow bumps in brown
    bm = c.mask(SKIN) & (z > 0.92) & (y < -0.11)
    for s in (1.0, -1.0):
        bc = v3((s * 0.125, -0.17, 0.95))
        d = P - bc
        c.draw(bm & (np.abs(d[:, 0]) < 0.05), np.abs(d[:, 2] + 6.0 * d[:, 0] ** 2), 0.005, 0.85)
    put(c.mask(MOUTH), srgb(70, 12, 20), 0.6)
    m = c.mask(TOOTH)
    put(m, srgb(250, 246, 232), 0.25, bump=0.1)
    put(c.mask(TONGUE), srgb(226, 96, 112) * (1.0 + 0.1 * n2)[:, None], 0.3, bump=0.3)
    put(c.mask(HAIR), srgb(60, 36, 20), 0.5)
    # bow tie: red with white polka dots; trousers: navy flannel, brass buttons; patent shoes
    m = c.mask(TIE)
    put(m, srgb(204, 30, 34), 0.35, bump=0.3)
    spk(m, (250, 244, 236), 0.5)
    m = c.mask(TROUSERS)
    put(m, srgb(34, 44, 96) * (1.0 + 0.08 * mott + 0.3 * c.wear)[:, None], 0.85, bump=1.0)
    c.strp[m, 0] = (x * 0.7)[m]
    c.strp[m, 1] = 0.35
    m = c.mask(BUTTON)
    put(m, srgb(220, 170, 70) * (1.0 - 0.4 * c.cavity)[:, None], 0.3, metal=1.0, grain=1.0, bump=0.1)
    m = c.mask(SHOE)
    put(m, srgb(18, 16, 20) * (1.0 + 2.0 * c.wear)[:, None], 0.12, bump=0.1, grain=1.0)
    put(c.mask(SOLE), srgb(52, 36, 26), 0.6)
    c.col *= (0.42 + 0.58 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model

GAME = {
    "budget": {"body": 8200},
    "density": {},
    "tex": 2048,
    "stride": {"walk": 0.6, "run": 0.95},
    "speed": 0.7,
    "look": ["chest", "hair"], "neck": "spine",
    "look_pivot": (0.0, 0.0, 0.6),
    "radius": 0.4,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.0, 0.36), (0, 0.0, 0.5), "root", 0.15),
        Bone("spine", (0, 0.0, 0.5), (0, 0.0, 0.66), "hips", 0.15),
        Bone("chest", (0, 0.0, 0.66), (0, 0.0, 0.95), "spine", 0.15),
        Bone("hair", HAIR_PTS[0], HAIR_PTS[3], "chest", 0.01),
        Bone("upper_arm.L", SHOULDER, ELBOW, "chest", 0.05),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.045),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.1, "forearm.L", 0.035),
        Bone("thigh.L", HIP, KNEE, "hips", 0.08),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.07),
        Bone("foot.L", ANKLE, (0.132, -0.14, 0.03), "shin.L", 0.045),
    ])
    return bones


def skin_rules(P, part, piece, names):
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True

    def seg(a, b):
        ab = b - a
        t = np.clip(((Q - a) @ ab) / float(ab @ ab), 0.0, 1.0)
        return np.linalg.norm(Q - a - np.outer(t, ab), axis=1)
    bp = piece == 0
    leg_d = np.minimum(seg(HIP, KNEE), seg(KNEE, ANKLE))
    legs = bp & ((z < 0.12) | (z < 0.29) & (leg_d < 0.1))
    allow(legs & (z > 0.24), "hips")
    allow(legs & (x > 0), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0), "thigh.R", "shin.R", "foot.R")
    arm_d = np.minimum(np.minimum(seg(SHOULDER, ELBOW) - 0.06, seg(ELBOW, WRIST) - 0.048), seg(WRIST, WRIST - HAND[:, 2] * 0.12) - 0.045)
    body_d = ball().eval(P)[0]
    arms = bp & ~legs & (Q[:, 0] > 0.26) & (arm_d < body_d - 0.012)
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x < 0), "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (arm_d > body_d - 0.04), "chest")
    hair = bp & (part == HAIR)
    rig[hair] = ix["hair"]
    trunk = bp & ~legs & ~arms & ~hair
    allow(trunk, "hips", "spine", "chest")
    rig[trunk & (z > 0.72)] = ix["chest"]
    return A, rig


def motions(rig):
    """walk: a skip: step-hop, step-hop, the ball bouncing up off each hop with both feet in the air, arms flung out and up, the hair
    springing after; run: a hurried bouncing skip; idle: bouncing on his toes, swaying, a little delighted wave"""
    import math
    from kit.gait import Pose, Leg, R, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def skip(u, S, hop, run):
        """each foot (phase uu): planted 0-0.3 sliding back with the ground, hops 0.3-0.45 (off the ground, still carried back), lands and
        stays 0.45-0.56, swings forward 0.56-1"""
        p = Pose()
        A, Bh, C = 0.3, 0.45, 0.56
        up = 0.0
        for lg in legs:
            s = 1.0 if lg.side == "L" else -1.0
            uu = (u + (0.0 if lg.side == "L" else 0.5)) % 1.0
            if uu < C:
                fy = -S * C / 2 + S * uu
                h = 0.0
                pitch = 0.0
                if A <= uu < Bh:
                    t = (uu - A) / (Bh - A)
                    h = hop * 0.55 * math.sin(math.pi * t)
                    pitch = 22.0 * math.sin(math.pi * t)
                    up = max(up, hop * math.sin(math.pi * t))
                elif uu < A:
                    pitch = 18.0 * ease((uu - (A - 0.1)) / 0.1)
                else:
                    pitch = 18.0 * (1.0 - ease((uu - Bh) / 0.06))
            else:
                t = (uu - C) / (1.0 - C)
                fy = S * C / 2 - S * C * ease(t)
                h = (0.09 if not run else 0.12) * math.sin(math.pi * t) ** 0.8
                pitch = -10.0 * math.sin(math.pi * t)
            wf = R(0, 0, s * 8.0) @ R(pitch, 0, 0)
            b = Vector((s * 0.12, fy, h))
            ankle = b + wf @ (rig.head[lg.foot] - lg.ball)
            p.ik[lg.thigh] = (ankle, Vector((s * 0.15, -1.0, 0.0)), lg.foot, wf)
        # the body: up on every hop, squatting a little on every landing
        land = max(math.exp(-((((u - 0.47) % 1.0) - 0.0) / 0.05) ** 2), math.exp(-((((u - 0.97) % 1.0) - 0.0) / 0.05) ** 2))
        p.offset = Vector((0.03 * math.sin(TAU * u), 0.03, up - 0.025 * land - 0.012))
        rk = 8.0 * math.sin(TAU * u)
        p.rot("hips", 4.0 if run else 0.0, rk * 0.5, -5.0 * math.cos(TAU * u))
        p.rot("spine", 0, rk * 0.3, 3.0 * math.cos(TAU * u))
        p.rot("chest", -4.0 * up / max(hop, 1e-6) + 3.0 * land, 0, 0)
        for side, sg in (("L", 1.0), ("R", -1.0)):
            c = math.cos(TAU * u)
            fling = up / max(hop, 1e-6)
            p.rot("upper_arm." + side, sg * (24.0 if run else 16.0) * c, -sg * (4.0 + 22.0 * fling), 0)          # (ry lifts an arm out to the side)
            p.rot("forearm." + side, -20.0 - 20.0 * fling, 0, 0)
        p.rot("hair", -25.0 * land + 18.0 * math.sin(2 * TAU * u - 2.4), 0, 10.0 * math.sin(TAU * u - 1.0))
        return p
    walk = [skip(i / 32.0, 0.6, 0.06, False) for i in range(33)]
    run = [skip(i / 24.0, 0.95, 0.09, True) for i in range(25)]
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        bounce = abs(math.sin(TAU * t / 1.0))
        stand(rig, p, legs, {"L": (Vector((0.13, -0.06, 0.0)), 10.0), "R": (Vector((-0.13, -0.06, 0.0)), -10.0)},
              hip_shift=(0.015 * math.sin(TAU * t / 3.0), 0.03, -0.022 + 0.012 * bounce), roll=-3.0 * math.sin(TAU * t / 3.0))
        p.rot("chest", 2.0 * bounce, 4.0 * math.sin(TAU * t / 3.0), 0)
        wave = ease((t - 2.0) / 0.4) * (1.0 - ease((t - 3.8) / 0.4))
        p.rot("upper_arm.L", -15.0 * wave, -(4.0 + 72.0 * wave), 0)
        p.rot("forearm.L", -25.0 * wave, -30.0 * math.sin(TAU * 2.5 * t) * wave, 0)
        p.rot("upper_arm.R", 3.0 * math.sin(TAU * t / 1.0), 4.0, 0)
        p.rot("forearm.R", -15.0, 0, 0)
        p.rot("hair", 10.0 * math.sin(TAU * t / 1.0 - 1.0), 0, 6.0 * math.sin(TAU * t / 3.0))
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
