## FOINT CITY townsfolk: stilts. A three-eyed visitor up on very long thin legs, 2.6 m to the tips of his antennae: a wide bean of a head on a long neck, a pear of a body in a striped knit turtleneck and puffed shorts, knobbly knees in striped socks; he walks with careful high steps, watching where his feet go.
# Upgrade of the three.js game's stilts (folk-species-d.js; old render refs/old/stilts.png): same idea (purple, three yellow eyes in a row, two
# antennae with yellow bobbles, a long neck, a pear torso with a yellow striped band, long thin arms and legs, knobbly knees), lifted to the new
# sheets (refs 4/6/7): heavy-lidded eyes looking down at his own feet, a tongue poking out in concentration, worn knits.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 2.60
REF = ("old/stilts.png", None)

SKIN, EYE, LIP, MOUTH, TONGUE, KNIT, SHORTS, SOCK, SHOE, SOLE, BOBBLE, NAIL = range(1, 13)
COLOURS = {
    SKIN: ((0.34, 0.15, 0.5), 0.55, 0.0),
    EYE: ((0.9, 0.88, 0.5), 0.2, 0.0),
    LIP: ((0.3, 0.1, 0.32), 0.4, 0.0),
    MOUTH: ((0.08, 0.02, 0.05), 0.6, 0.0),
    TONGUE: ((0.8, 0.35, 0.45), 0.4, 0.0),
    KNIT: ((0.75, 0.6, 0.15), 0.9, 0.0),
    SHORTS: ((0.16, 0.3, 0.32), 0.8, 0.0),
    SOCK: ((0.85, 0.82, 0.7), 0.9, 0.0),
    SHOE: ((0.25, 0.08, 0.2), 0.4, 0.0),
    SOLE: ((0.8, 0.75, 0.6), 0.7, 0.0),
    BOBBLE: ((0.95, 0.85, 0.3), 0.3, 0.0),
    NAIL: ((0.2, 0.08, 0.25), 0.3, 0.0),
}
UP = v3((0, 0, 1))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# landmarks, left side (+X); the figure faces -Y
HIP = v3((0.095, 0.005, 1.62))
KNEE = v3((0.11, -0.03, 0.88))
ANKLE = v3((0.115, 0.012, 0.095))
BALL = v3((0.118, -0.08, 0.0))
SHOULDER = v3((0.185, 0.01, 1.995))
ELBOW = v3((0.31, 0.03, 1.64))
WRIST = v3((0.33, -0.01, 1.29))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
NECK_A, NECK_B = v3((0, 0.025, 2.02)), v3((0, 0.0, 2.33))
HEAD_C = v3((0.0, -0.005, 2.405))
# the three eyes: (centre, radius, how heavy the lid is); all look down and ahead at the pavement
EYES = [(v3((0.09, -0.116, 2.418)), 0.041, 0.36), (v3((-0.09, -0.116, 2.418)), 0.041, 0.36), (v3((0.0, -0.128, 2.475)), 0.049, 0.28)]
LOOK = unit((0.0, -1.0, -0.42))
ANT = [(v3((0.055, 0.0, 2.505)), v3((0.13, 0.03, 2.578))), (v3((-0.055, 0.0, 2.505)), v3((-0.125, 0.04, 2.575)))]


def head():
    """a wide bean of a head, its lower face pushed forward into a small muzzle; three eyes, a pursed mouth with the tongue tip out at one corner"""
    skull = Union([
        Ellipsoid(HEAD_C, (0.19, 0.145, 0.118)),
        Ellipsoid(HEAD_C + v3((0, 0.008, 0.04)), (0.15, 0.13, 0.1)),
        Ellipsoid(HEAD_C + v3((0, -0.055, -0.07)), (0.105, 0.09, 0.065)),
    ], k=0.06, part=SKIN)
    neck = RoundCone(NECK_A, NECK_B, 0.042, 0.036, part=SKIN)
    # neck rings
    rings = [Torus(NECK_A + (NECK_B - NECK_A) * t, 0.04 - 0.004 * t, 0.006, part=SKIN) for t in (0.45, 0.6)]
    parts = []
    balls = []
    for ec, re, lid in EYES:
        ln = unit(v3((0.0, -0.25, -1.0)))
        shell = Clip(Ellipsoid(ec, (re + 0.006, re + 0.005, re + 0.006), part=SKIN), [Half(ec + v3((0, 0, re * (0.62 - 1.1 * lid))), ln)], k=0.003)
        lower = Clip(Ellipsoid(ec, (re + 0.0045, re + 0.004, re + 0.0045), part=SKIN), [Half(ec - v3((0, 0, re * 0.55)), (0, 0, 1))], k=0.003)
        parts += [shell, lower]
        balls.append(Sphere(ec, re, part=EYE))
    nose = Union([Ellipsoid(HEAD_C + v3((0.0, -0.148, -0.03)), (0.022, 0.016, 0.014)), Mirror(Sphere(HEAD_C + v3((0.011, -0.15, -0.038)), 0.0085))], k=0.008, part=SKIN)
    nose = Cut(nose, [Mirror(Ellipsoid(HEAD_C + v3((0.011, -0.156, -0.043)), (0.0045, 0.006, 0.0035)))], k=0.002)
    face = Union([Union([skull, neck] + rings, k=0.03)] + parts, k=0.01)
    face = Union([face, nose], k=0.01)
    # the mouth: a small slot on the muzzle, lips pushed out, the tongue tip out at his left corner
    mc = HEAD_C + v3((0.0, -0.138, -0.083))
    slot = Ellipsoid(mc, (0.03, 0.03, 0.006))
    lips = Clip(Inflate(slot, 0.008, part=LIP), [Inflate(skull, 0.007)], k=0.003)
    face = Cut(Union([face, lips], k=0.005), [slot], k=0.002)
    throat = Ellipsoid(mc + v3((0, 0.02, 0)), (0.026, 0.015, 0.008), part=MOUTH)
    tongue = Union([Ellipsoid(mc + v3((0.022, -0.006, -0.002)), (0.011, 0.012, 0.005)), Ellipsoid(mc + v3((0.032, -0.012, -0.006)), (0.009, 0.009, 0.005))], k=0.006, part=TONGUE)
    # the antennae: thin stalks curving up and out, a bobble each
    ants = []
    for a, b in ANT:
        m = a + (b - a) * 0.5 + v3((0.0, 0.0, 0.012)) + unit(v3((a[0], 0, 0))) * -0.01
        ants.append(Union([loft([(a - v3((0, 0, 0.01)), 0.011), (m, 0.0065), (b, 0.006)], part=SKIN, k=0.01), Sphere(b + v3((0, 0, 0.004)), 0.022, part=BOBBLE)], k=0.006))
    return Union([face, throat, tongue] + balls + ants, k=0.0)


def torso_core():
    return Union([
        Ellipsoid((0, 0.005, 1.85), (0.155, 0.13, 0.2)),
        Ellipsoid((0, 0.01, 1.72), (0.19, 0.15, 0.13)),
        Ellipsoid((0, 0.01, 1.99), (0.16, 0.1, 0.06)),
    ], k=0.08, part=SKIN)


def body():
    core = torso_core()
    sweater = Clip(Inflate(core, 0.012, part=KNIT), [Half((0, 0, 1.66), (0, 0.0, -1))], k=0.004)
    hem = Clip(Inflate(core, 0.019, part=KNIT), [Half((0, 0, 1.66), (0, 0, -1)), Half((0, 0, 1.70), (0, 0, 1))], k=0.004)
    turtle = Union([Torus((0, 0.02, 2.05), 0.05, 0.022, part=KNIT), Torus((0, 0.022, 2.08), 0.047, 0.02, part=KNIT),
                    CappedCone((0, 0.02, 2.02), (0, 0.022, 2.1), 0.05, 0.047, rr=0.01, part=KNIT)], k=0.012)
    # sleeves to the elbow, a rolled cuff
    d = unit(ELBOW - SHOULDER)
    sleeve = Clip(loft([(SHOULDER, 0.046), (SHOULDER + (ELBOW - SHOULDER) * 0.62, 0.038)], part=KNIT, k=0.0), [Half(SHOULDER + (ELBOW - SHOULDER) * 0.6, d)], k=0.003)
    scuff = Torus(SHOULDER + (ELBOW - SHOULDER) * 0.58, 0.037, 0.008, Rm=basis(d, v3((0, 1, 0))), part=KNIT)
    top = Union([Union([sweater, hem, turtle], k=0.01), Mirror(Union([sleeve], k=0.0))], k=0.018, part=KNIT)
    top = Union([top, Mirror(scuff)], k=0.004)
    # puffed shorts, gathered at the thigh
    shorts = Union([
        Ellipsoid((0, 0.012, 1.62), (0.18, 0.145, 0.1)),
        Mirror(loft([(HIP + v3((0, 0, 0.02)), 0.085), (v3((0.105, -0.004, 1.47)), 0.074)])),
    ], k=0.05, part=SHORTS)
    shorts = Clip(shorts, [Half((0, 0, 1.68), (0, 0, 1)), Half((0, 0, 1.455), (0, 0, -1))], k=0.006)
    gather = Mirror(Torus((0.105, -0.004, 1.462), 0.058, 0.01, part=SHORTS))
    return Union([core, top, shorts, gather], k=0.0)


def leg():
    """a long thin leg: a knobbly knee, a striped knee sock, a little round boot"""
    thigh = loft([(HIP, 0.05), (HIP + (KNEE - HIP) * 0.5, 0.036), (KNEE, 0.032)], part=SKIN, k=0.01)
    shin = loft([(KNEE, 0.032), (KNEE + (ANKLE - KNEE) * 0.35, 0.034), (ANKLE + v3((0, 0, 0.05)), 0.025)], part=SKIN, k=0.01)
    knee = Union([Ellipsoid(KNEE + v3((0, -0.018, 0.012)), (0.04, 0.034, 0.046)), Sphere(KNEE + v3((0.0, -0.03, -0.02)), 0.022)], k=0.02, part=SKIN)
    bare = Union([thigh, shin, knee], k=0.02)
    sock = Clip(Inflate(shin, 0.006, part=SOCK), [Half((0, 0, 0.6), (0, 0, 1))], k=0.003)
    cuff = Torus(KNEE + (ANKLE - KNEE) * 0.355, 0.037, 0.008, Rm=basis(unit(KNEE - ANKLE), v3((0, 1, 0))), part=SOCK)
    x = ANKLE[0]
    foot = Union([
        loft([(ANKLE + v3((0, 0.01, 0.01)), 0.04), (v3((x, -0.06, 0.04)), 0.044), (v3((x + 0.004, -0.13, 0.034)), 0.034)], k=0.02),
        Ellipsoid((x + 0.004, -0.135, 0.033), (0.04, 0.045, 0.032)),
    ], k=0.02, part=SHOE)
    shoe = Clip(Union([foot, CappedCone((x, 0.006, 0.04), (x, 0.0, 0.13), 0.044, 0.04, rr=0.01, part=SHOE)], k=0.02), [Half((0, 0, 0.02), (0, 0, -1))], k=0.003)
    sole = Clip(Inflate(foot, 0.006, part=SOLE), [Half((0, 0, 0.022), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    strap = Clip(Inflate(foot, 0.005, part=SOLE), [Half((0, -0.05, 0), (0, 1, 0.3)), Half((0, -0.032, 0), (0, -1, -0.3)), Half((0, 0, 0.03), (0, 0, -1))], k=0.002)
    button = Sphere((x + 0.045, -0.04, 0.062), 0.007, part=BOBBLE)
    return Union([bare, sock, cuff, shoe, sole, strap, button], k=0.0)


def hand(s=1.0):
    """a long thin three-fingered hand in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y)"""
    palm = Ellipsoid(v3((0.0, 0.0, -0.04)) * s, v3((0.014, 0.03, 0.042)) * s, part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.01), 0.022, 0.02, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.017, 0.9), (0.0, 1.0), (0.017, 0.85)):
        pts = [((0.0, f, -0.07), 0.0095), ((-0.004, f * 1.1, -0.07 - 0.04 * L), 0.0085), ((-0.014, f * 1.2, -0.07 - 0.075 * L), 0.0078), ((-0.026, f * 1.25, -0.07 - 0.095 * L), 0.0072)]
        parts.append(loft([(v3(p) * s, r * s) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Ellipsoid(v3(pts[-1][0]) * s + v3((0.003, 0, 0.002)), (0.0045, 0.0055, 0.006), part=NAIL))
    parts.append(loft([(v3((-0.008, -0.022, -0.025)), 0.0105), (v3((-0.02, -0.038, -0.055)), 0.0085), (v3((-0.03, -0.04, -0.078)), 0.0075)], part=SKIN, k=0.004))
    return Union(parts, k=0.007)


def arm():
    a = loft([(SHOULDER, 0.04), (ELBOW, 0.026), (ELBOW + (WRIST - ELBOW) * 0.5, 0.025), (WRIST, 0.021)], part=SKIN, k=0.012)
    elbow = Sphere(ELBOW + v3((0.0, 0.01, 0.0)), 0.029, part=SKIN)
    return Union([a, elbow, place(hand(), WRIST, HAND)], k=0.012)


def pieces():
    b = Union([body(), Mirror(leg()), Mirror(arm())], k=0.0)
    return [("head", head(), 0.0018), ("body", b, 0.003)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n1 = noise3(P, 0.05)
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

    # skin: violet, the head a lighter lilac with darker freckled cheeks, the joints and hands darker
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(128, 70, 166), (len(P), 3)).copy()
    sk = sk + (srgb(160, 104, 196) - sk) * smooth(2.2, 2.35, z)[:, None]
    sk = sk + (srgb(92, 50, 128) - sk) * (smooth(1.45, 1.1, z) * 0.35 + 0.0)[:, None]
    knee = smooth(0.07, 0.0, np.linalg.norm(Q - KNEE, axis=1))
    sk = sk + (srgb(106, 54, 140) - sk) * (knee * 0.7)[:, None]
    cheek = smooth(0.05, 0.0, np.linalg.norm(Q - (HEAD_C + v3((0.12, -0.09, -0.04))), axis=1))
    sk = sk + (srgb(196, 104, 170) - sk) * (cheek * 0.55)[:, None]
    sk *= (1.0 + 0.09 * mott)[:, None]
    put(m, sk, 0.5, bump=0.25)
    spk(m & (z > 2.25), (104, 52, 140), 0.35)
    spk(m & (z <= 2.25), (150, 96, 190), 0.25)
    # eyes: pale lemon, no whites (alien), amber rings, big inked pupils looking down at the pavement; liners on the lids
    m = c.mask(EYE)
    ey = np.broadcast_to(srgb(244, 236, 150), (len(P), 3)).copy()
    for ec, re, lid in EYES:
        dv = P - ec
        r = np.linalg.norm(dv, axis=1)
        near = m & (r < re * 1.25)
        dd = dv / np.maximum(r, 1e-6)[:, None]
        ang = np.arccos(np.clip(dd @ LOOK, -1, 1))
        ey[near] = ey[near] + (srgb(214, 150, 40) - ey[near]) * smooth(0.45, 0.9, ang[near])[:, None]
        c.draw(near, (ang - 0.36) * re, 0.0)
        g = smooth(0.28, 0.16, np.arccos(np.clip(dd @ unit(LOOK + v3((0.3, 0, 0.75))), -1, 1)))
        ey[near] = ey[near] + (srgb(255, 255, 240) - ey[near]) * g[near, None]
        sm = c.mask(SKIN) & (r < re + 0.01) & (dv[:, 2] > -re * 0.1) & (dv[:, 1] < 0.006)
        c.draw(sm, np.abs(r - re - 0.0018), 0.0014, 0.95)
    put(m, ey, 0.08)
    c.spk[m, 3] = 0.0
    put(c.mask(LIP), srgb(96, 40, 104), 0.35, bump=0.2)
    put(c.mask(MOUTH), srgb(36, 8, 26), 0.6)
    put(c.mask(TONGUE), srgb(222, 110, 140), 0.3, bump=0.2)
    m = c.mask(BOBBLE)
    put(m, srgb(250, 226, 96) * (1.0 + 0.4 * c.wear)[:, None], 0.25)
    put(c.mask(NAIL), srgb(70, 30, 86), 0.25)
    # the turtleneck: mustard and plum stripes, ribbed at the hem, cuffs and neck, a darned hole or two
    m = c.mask(KNIT)
    band = np.floor((z - 1.66) / 0.045).astype(int) % 2 == 0
    kn = np.where(band[:, None], srgb(222, 176, 52), srgb(104, 40, 96)) * (1.0 + 0.1 * mott)[:, None]
    put(m, kn, 0.95, bump=1.0)
    phi = np.arctan2(x, -y)
    rib = m & ((z < 1.71) | (z > 2.0))
    c.strp[rib, 0] = (phi * 0.15 * 0.4)[rib]
    c.strp[rib, 1] = 0.7
    spk(m, (70, 30, 60), 0.18)
    # shorts: teal cord, worn pale at the seams; socks: cream with plum hoops; boots plum with a lemon button
    m = c.mask(SHORTS)
    put(m, srgb(40, 108, 116) * (1.0 + 0.08 * mott + 0.5 * c.wear)[:, None], 0.85, bump=1.0)
    c.strp[m, 0] = (phi * np.hypot(x, y) * 3.0)[m]
    c.strp[m, 1] = 0.5
    m = c.mask(SOCK)
    hoop = np.floor((z - 0.1) / 0.06).astype(int) % 2 == 0
    put(m, np.where(hoop[:, None], srgb(232, 224, 200), srgb(116, 52, 120)) * (1.0 + 0.08 * mott)[:, None], 0.92, bump=1.0)
    m = c.mask(SHOE)
    put(m, srgb(86, 30, 72) * (1.0 + 0.9 * c.wear)[:, None], 0.35, bump=0.6, grain=1.0)
    m = c.mask(SOLE)
    put(m, srgb(226, 214, 180) * (1.0 - 0.35 * smooth(0.3, 0.8, n2))[:, None], 0.75, bump=0.3)
    c.col *= (0.32 + 0.68 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model

GAME = {
    "budget": {"head": 2800, "body": 5200},
    "density": {"head": 1.7},
    "tex": 2048,
    "stride": {"walk": 1.36, "run": 2.4},
    "speed": 0.72,
    "look": ["head", "ant.L", "ant.R"], "neck": "neck",
    "look_pivot": (0.0, 0.01, 2.2),
    "radius": 0.35,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.01, 1.62), (0, 0.01, 1.76), "root", 0.15),
        Bone("spine", (0, 0.01, 1.76), (0, 0.005, 1.9), "hips", 0.15),
        Bone("chest", (0, 0.005, 1.9), (0, 0.02, 2.04), "spine", 0.13),
        Bone("neck", NECK_A, NECK_B, "chest", 0.04),
        Bone("head", NECK_B, HEAD_C + v3((0, 0, 0.13)), "neck", 0.12),
        Bone("ant.L", ANT[0][0], ANT[0][1], "head", 0.02),
        Bone("shoulder.L", (0.04, 0.01, 2.0), SHOULDER, "chest", 0.04),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.03),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.025),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.14, "forearm.L", 0.02),
        Bone("thigh.L", HIP, KNEE, "hips", 0.04),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.032),
        Bone("foot.L", ANKLE, (0.118, -0.14, 0.03), "shin.L", 0.03),
    ])
    for b in bones:
        if b.name == "ant.R":
            b.head, b.tail = ANT[1][0], ANT[1][1]
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
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 2.3)] = ix["head"]
    for i, side in enumerate(("L", "R")):
        a, b = ANT[i]
        on = hp & (np.linalg.norm(P - (a + b) * 0.5, axis=1) < 0.075) & (z > a[2] - 0.0)
        rig[on] = ix["ant." + side]
    bp = piece == 1
    legs = bp & ((z < 1.5) & (np.abs(x) < 0.2) | np.isin(part, (SHORTS,)) & (z < 1.56))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    arms = bp & ~legs & (np.abs(x) > 0.2) & (z < 1.95) | bp & (np.abs(x) > 0.215)
    arms &= ~legs
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "upper_arm.R", "forearm.R", "hand.R")
    torso = bp & ~legs & ~arms
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.1) & (z > 1.85), "shoulder.L", "upper_arm.L")
    allow(torso & (x < -0.1) & (z > 1.85), "shoulder.R", "upper_arm.R")
    return A, rig


def motions(rig):
    """walk: careful high steps: each foot lifted high (knee up to the hip's height), held, carried forward and set down toe first, the head
    bowed to watch it land, arms a little out for balance; run: a gangly loping trot, arms flailing; idle: swaying on the long legs, peering
    down, antennae twitching, a careful shift from foot to foot"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def high_step(p, u, S, beta, lift, fx):
        """the legs: stance as biped_walk's (the planted ball sliding back at the body's speed), but the swing goes up first, forward at
        the top, then down onto the toe"""
        for lg in legs:
            s = 1.0 if lg.side == "L" else -1.0
            uu = (u + (0.0 if lg.side == "L" else 0.5)) % 1.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                h = 0.0
                pitch = 14.0 * ease((uu - (beta - 0.12)) / 0.12)
            else:
                t = (uu - beta) / (1.0 - beta)
                fy = S * beta / 2 - S * beta * ease((t - 0.12) / 0.72)
                h = lift * math.sin(math.pi * min(1.0, t * 1.08)) ** 0.55
                pitch = 14.0 * (1.0 - ease(t * 3.0)) + 26.0 * math.sin(math.pi * t) ** 1.5      # toe hangs down under the lifted foot
            wf = R(0, 0, s * 6.0) @ R(pitch, 0, 0)
            ball = Vector((s * fx, fy, h))
            ankle = ball + wf @ (rig.head[lg.foot] - lg.ball)
            p.ik[lg.thigh] = (ankle, Vector((s * 0.2, -1.0, 0.0)), lg.foot, wf)

    def walkish(u, run):
        p = Pose()
        g = dict(stride=2.4 if run else 1.36, stance=0.42 if run else 0.56, foot_x=0.11, lift=0.2, bob=0.05 if run else 0.03,
                 drop=0.09 if run else 0.05, sway=0.03, roll=4.0, yaw=6.0, counter=1.0, lean=8.0 if run else 4.0, toe_off=16.0,
                 toe_out=6.0, swing_point=0.0)
        biped_walk(rig, p, u, g, legs)
        if run:
            pass
        else:
            high_step(p, u, 1.36, 0.56, 0.36, 0.11)
            # the body rises as it steps up over the planted leg and sinks as the foot is set down
            p.offset = p.offset + Vector((0.0, 0.0, 0.025 * math.cos(2 * TAU * (u - 0.2))))
        c = math.cos(TAU * u)
        s = math.sin(TAU * u)
        a = 34.0 if run else 9.0
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, sg * a * c, 0, -sg * (14.0 if run else 9.0 + 3.0 * math.sin(2 * TAU * u)))
            p.rot("forearm." + side, -(45.0 if run else 22.0) - (15.0 * max(0.0, sg * c) if run else 0.0), 0, 0)
            p.rot("hand." + side, (-20.0 if not run else 0.0), 0, 0)
        p.rot("neck", 14.0 if not run else 8.0, 0, 0)
        p.world["head"] = R((22.0 if not run else 6.0) + 3.0 * math.sin(2 * TAU * u - 0.6), 0, (5.0 if not run else 2.0) * s)
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("ant." + side, (10.0 if run else 6.0) * math.sin(2 * TAU * u - 1.4 - 0.4 * sg), 0, sg * 4.0 * math.sin(TAU * u))
        return p
    walk = [walkish(i / 32.0, False) for i in range(33)]
    run = [walkish(i / 24.0, True) for i in range(25)]
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        shift = math.sin(TAU * t / 6.0)
        stand(rig, p, legs, {"L": (Vector((0.13, -0.04, 0.0)), 8.0), "R": (Vector((-0.12, 0.02, 0.0)), -6.0)},
              hip_shift=(0.035 * shift, 0.0, -0.025 + 0.006 * math.sin(TAU * t / 3.0)), roll=-3.0 * shift)
        p.rot("spine", 2.0 + 1.0 * math.sin(TAU * t / 3.0), -1.5 * shift, 0)
        p.rot("chest", 1.0, -1.0 * shift, 0)
        peer = ease((t - 1.5) / 0.6) * (1.0 - ease((t - 3.8) / 0.6))
        p.rot("neck", 10.0 + 14.0 * peer, 0, 0)
        p.world["head"] = R(12.0 + 22.0 * peer, 0, 10.0 * math.sin(TAU * t / 6.0) - 18.0 * peer * math.sin(TAU * t / 2.3))
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, 2.0 * math.sin(TAU * t / 3.0 + sg), 0, -sg * 5.0)
            p.rot("forearm." + side, -14.0 - 4.0 * math.sin(TAU * t / 3.0), 0, 0)
            tw = math.exp(-((t - (2.2 if side == "L" else 4.4)) / 0.15) ** 2)
            p.rot("ant." + side, 4.0 * math.sin(TAU * t / 2.0 + sg) + 18.0 * tw * math.sin(TAU * 6.0 * t), 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
