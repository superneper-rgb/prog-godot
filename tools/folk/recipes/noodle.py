## FOINT CITY townsfolk: noodle. A tall teal fellow who is mostly head: a great round head with two big mismatched eyes, a small nose and a shy smile, cup ears and an antenna with a yellow bobble, on a thin neck over a narrow body in a checked short-sleeved shirt and high-water cords; his head bobs as he walks.
# Upgrade of the three.js game's noodle (folk-species-c.js; old render refs/old/noodle.png): same idea (teal, a huge round head on a thin neck,
# two big eyes, one bigger, cup ears, a little smile, an antenna bobble, a small body on long thin legs), lifted to the new sheets (refs 4/6/7):
# lidded eyes, a nose, freckled scalp, worn clothes in rust and cream against the teal, chunky sneakers.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 2.20
REF = ("old/noodle.png", None)

SKIN, EYE, LIP, MOUTH, BOBBLE, SHIRT, BUTTON, TROUSERS, BELT, BRASS, SOCK, SHOE, SOLE, LACE, NAIL = range(1, 16)
COLOURS = {
    SKIN: ((0.12, 0.5, 0.55), 0.55, 0.0),
    EYE: ((0.9, 0.9, 0.85), 0.2, 0.0),
    LIP: ((0.08, 0.33, 0.37), 0.4, 0.0),
    MOUTH: ((0.03, 0.08, 0.1), 0.6, 0.0),
    BOBBLE: ((0.92, 0.85, 0.3), 0.3, 0.0),
    SHIRT: ((0.75, 0.45, 0.3), 0.8, 0.0),
    BUTTON: ((0.85, 0.8, 0.7), 0.3, 0.0),
    TROUSERS: ((0.4, 0.25, 0.12), 0.85, 0.0),
    BELT: ((0.2, 0.12, 0.07), 0.5, 0.0),
    BRASS: ((0.8, 0.56, 0.2), 0.3, 1.0),
    SOCK: ((0.88, 0.86, 0.8), 0.9, 0.0),
    SHOE: ((0.75, 0.35, 0.12), 0.5, 0.0),
    SOLE: ((0.88, 0.85, 0.78), 0.7, 0.0),
    LACE: ((0.9, 0.88, 0.82), 0.8, 0.0),
    NAIL: ((0.1, 0.35, 0.38), 0.3, 0.0),
}
UP = v3((0, 0, 1))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# landmarks, left side (+X); the figure faces -Y
HIP = v3((0.075, 0.005, 0.95))
KNEE = v3((0.085, -0.02, 0.53))
ANKLE = v3((0.09, 0.012, 0.1))
BALL = v3((0.092, -0.09, 0.0))
SHOULDER = v3((0.15, 0.005, 1.30))
ELBOW = v3((0.215, 0.025, 1.03))
WRIST = v3((0.232, -0.012, 0.785))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
HEAD_C = v3((0.0, -0.01, 1.775))
NECK_A, NECK_B = v3((0, 0.02, 1.30)), v3((0, 0.005, 1.52))
# the eyes: his left a size smaller and wider open than his right; both look ahead and a little up, mildly
EYE_L = (v3((0.122, -0.238, 1.83)), 0.074, 0.2)
EYE_R = (v3((-0.13, -0.232, 1.84)), 0.084, 0.26)
LOOK = unit((0.03, -1.0, 0.1))
ANT_A, ANT_B = v3((0.0, 0.03, 2.09)), v3((0.035, 0.05, 2.165))


def head():
    skull = Union([
        Ellipsoid(HEAD_C, (0.33, 0.295, 0.335)),
        Ellipsoid(HEAD_C + v3((0, -0.045, -0.15)), (0.25, 0.235, 0.2)),
    ], k=0.08, part=SKIN)
    neck = RoundCone(NECK_A, NECK_B, 0.042, 0.04, part=SKIN)
    parts = []
    balls = []
    for ec, re, lid in (EYE_L, EYE_R):
        ln = unit(v3((0.0, -0.3, -1.0)))
        shell = Clip(Ellipsoid(ec, (re + 0.008, re + 0.006, re + 0.008), part=SKIN), [Half(ec + v3((0, 0, re * (0.62 - 1.0 * lid))), ln)], k=0.004)
        lower = Clip(Ellipsoid(ec, (re + 0.006, re + 0.004, re + 0.006), part=SKIN), [Half(ec - v3((0, 0, re * 0.6)), (0, 0, 1))], k=0.004)
        parts += [shell, lower]
        balls.append(Sphere(ec, re, part=EYE))
    brow = Mirror(Ellipsoid((0.13, -0.24, 1.955), (0.075, 0.03, 0.02), R=rot(ry=12), part=SKIN))
    nose = Union([Sphere((0.0, -0.302, 1.72), 0.03), Mirror(Sphere((0.02, -0.29, 1.708), 0.018))], k=0.012, part=SKIN)
    cheeks = Mirror(Ellipsoid((0.13, -0.235, 1.665), (0.07, 0.05, 0.05), part=SKIN))
    ears = []
    for s in (1.0, -1.0):
        c = v3((s * 0.33, 0.01, 1.75))
        cup = Ellipsoid(c, (0.04, 0.05, 0.068), part=SKIN)
        hole = Ellipsoid(c + v3((s * 0.028, -0.006, 0.0)), (0.022, 0.032, 0.046))
        ears.append(Cut(cup, [hole], k=0.006))
    face = Union([Union([skull, neck, brow, cheeks] + ears, k=0.04)] + parts + [nose], k=0.012)
    # a shy closed smile: a thin curved slot, a soft lower lip; dimples at its corners
    lo = Ellipsoid((0, -0.265, 1.64), (0.09, 0.07, 0.045))
    hi = Ellipsoid((0, -0.285, 1.66), (0.12, 0.09, 0.05))
    slot = Cut(lo, [hi], k=0.006)
    lip = Clip(Inflate(slot, 0.008, part=LIP), [Inflate(skull, 0.006)], k=0.003)
    face = Cut(Union([face, lip], k=0.005), [slot], k=0.003)
    throat = Ellipsoid((0, -0.235, 1.607), (0.085, 0.02, 0.016), part=MOUTH)
    m = ANT_A + (ANT_B - ANT_A) * 0.5 + v3((-0.008, 0, 0.0))
    ant = Union([loft([(ANT_A - v3((0, 0, 0.02)), 0.016), (m, 0.0085), (ANT_B, 0.0075)], part=SKIN, k=0.012), Sphere(ANT_B + v3((0, 0, 0.006)), 0.03, part=BOBBLE)], k=0.006)
    return Union([face, throat, ant] + balls, k=0.0)


def torso_core():
    return Union([
        Ellipsoid((0, 0.0, 1.205), (0.135, 0.095, 0.14)),
        Ellipsoid((0, 0.006, 1.31), (0.15, 0.075, 0.04)),
        Ellipsoid((0, -0.012, 1.075), (0.125, 0.1, 0.11)),
    ], k=0.06, part=SKIN)


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def front_y(shape, x, z, y0=-0.5, y1=0.3):
    ys = np.linspace(y0, y1, 1601).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    return float(ys[int(np.argmax(shape.eval(P)[0] < 0))])


def body():
    core = torso_core()
    d = unit(ELBOW - SHOULDER)
    sleeve = Clip(loft([(SHOULDER, 0.05), (SHOULDER + (ELBOW - SHOULDER) * 0.5, 0.044)], part=SHIRT), [Half(SHOULDER + (ELBOW - SHOULDER) * 0.48, d)], k=0.003)
    shirt = Union([Clip(Inflate(core, 0.01, part=SHIRT), [Half((0, 0, 1.0), (0, 0, -1))], k=0.003), Mirror(sleeve)], k=0.016, part=SHIRT)
    hemroll = Mirror(Torus(SHOULDER + (ELBOW - SHOULDER) * 0.47, 0.044, 0.007, Rm=basis(d, v3((0, 1, 0))), part=SHIRT))
    placket = Clip(Inflate(core, 0.014, part=SHIRT), [prism([(-0.014, 1.33), (0.014, 1.33), (0.014, 1.0), (-0.014, 1.0)])], k=0.003)
    collar = Clip(Cut(Inflate(core, 0.02, part=SHIRT), [Inflate(core, 0.014)], k=0.002), [Mirror(prism([(0.0, 1.31), (0.06, 1.345), (0.07, 1.30), (0.03, 1.275)]))], k=0.004)
    neckband = Clip(RoundCone((0, 0.02, 1.28), (0, 0.018, 1.345), 0.052, 0.048, part=SHIRT), [Half((0, 0, 1.345), (0, 0, 1))], k=0.003)
    buttons = [Ellipsoid((0, front_y(core, 0, z) - 0.016, z), (0.008, 0.004, 0.008), part=BUTTON) for z in (1.06, 1.14, 1.22, 1.29)]
    # high-waisted cords, a belt, high-water hems over white socks
    hips = Union([
        Ellipsoid((0, 0.008, 0.99), (0.14, 0.11, 0.1)),
        Ellipsoid((0, -0.006, 1.05), (0.135, 0.108, 0.06)),
        Mirror(loft([(HIP, 0.075), (KNEE, 0.058), (v3((0.09, 0.006, 0.22)), 0.06)])),
    ], k=0.05, part=TROUSERS)
    trousers = Clip(hips, [Half((0, 0, 1.075), (0, 0, 1)), Half((0, 0, 0.21), (0, 0, -1))], k=0.004)
    belt = Clip(Inflate(Ellipsoid((0, -0.006, 1.05), (0.135, 0.108, 0.06)), 0.006, part=BELT), [Half((0, 0, 1.07), (0, 0, 1)), Half((0, 0, 1.04), (0, 0, -1))], k=0.002)
    buckle = Box((0, front_y(Ellipsoid((0, -0.006, 1.05), (0.135, 0.108, 0.06)), 0, 1.055) - 0.008, 1.055), (0.02, 0.005, 0.016), rr=0.004, part=BRASS)
    return Union([core, shirt, hemroll, placket, collar, neckband] + buttons + [trousers, belt, buckle], k=0.0)


def leg():
    shin = RoundCone(v3((0.09, 0.006, 0.24)), ANKLE + v3((0, 0, 0.03)), 0.034, 0.03, part=SKIN)
    sock = Clip(Inflate(RoundCone(v3((0.09, 0.006, 0.24)), ANKLE + v3((0, 0, 0.03)), 0.034, 0.03), 0.006, part=SOCK), [Half((0, 0, 0.2), (0, 0, 1))], k=0.003)
    roll = Torus((0.09, 0.008, 0.195), 0.037, 0.009, part=SOCK)
    x = ANKLE[0]
    foot = Union([
        Box((x, -0.045, 0.052), (0.05, 0.115, 0.045), rr=0.04),
        Ellipsoid((x + 0.004, -0.125, 0.05), (0.054, 0.058, 0.046)),
    ], k=0.025, part=SHOE)
    collar = Union([CappedCone((x, 0.008, 0.05), (x, 0.004, 0.125), 0.05, 0.046, rr=0.012), Torus((x, 0.004, 0.122), 0.044, 0.011)], k=0.01, part=SHOE)
    upper = Clip(Union([foot, collar], k=0.025, part=SHOE), [Half((0, 0, 0.032), (0, 0, -1))], k=0.003)
    tongue = Box((x, -0.058, 0.115), (0.026, 0.01, 0.032), rr=0.009, R=rot(rx=-22), part=SHOE)
    sole = Clip(Inflate(foot, 0.008, part=SOLE), [Half((0, 0, 0.036), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)
    toe = Clip(Inflate(Ellipsoid((x + 0.004, -0.125, 0.05), (0.054, 0.058, 0.046)), 0.004, part=SOLE), [Half((0, -0.12, 0), (0, 1, -0.2))], k=0.003)
    laces = [Box((x, yy, zz), (0.028, 0.005, 0.005), rr=0.0045, R=rot(rx=-30), part=LACE) for yy, zz in ((-0.066, 0.104), (-0.082, 0.088), (-0.098, 0.074))]
    return Union([shin, sock, roll, Union([upper, tongue], k=0.008), sole, toe] + laces, k=0.0)


def hand(s=1.0):
    """a long thin four-fingered hand in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y)"""
    palm = Ellipsoid((0.0, 0.0, -0.042), (0.015, 0.032, 0.044), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.01), 0.026, 0.023, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.021, 0.86), (-0.007, 1.0), (0.007, 0.96), (0.021, 0.8)):
        pts = [((0.0, f, -0.075), 0.0082), ((-0.004, f * 1.05, -0.075 - 0.032 * L), 0.0076), ((-0.014, f * 1.1, -0.075 - 0.06 * L), 0.007), ((-0.026, f * 1.12, -0.075 - 0.076 * L), 0.0064)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
    parts.append(loft([(v3((-0.008, -0.024, -0.025)), 0.011), (v3((-0.02, -0.04, -0.052)), 0.0092), (v3((-0.029, -0.042, -0.072)), 0.008)], part=SKIN, k=0.004))
    return Union(parts, k=0.007)


def arm():
    a = loft([(SHOULDER, 0.04), (ELBOW, 0.031), (WRIST, 0.025)], part=SKIN, k=0.01)
    return Union([a, place(hand(), WRIST, HAND)], k=0.01)


def pieces():
    b = Union([body(), Mirror(leg()), Mirror(arm())], k=0.0)
    return [("head", head(), 0.0022), ("body", b, 0.003)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n1 = noise3(P, 0.06)
    n2 = noise3(P, 0.014)
    mott = n1 * 0.5 + n2 * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (m.sum(), 3)), np.broadcast_to(np.asarray(amt, np.float32), (m.sum(),))[:, None]], 1)

    # skin: teal, paler and greener down the face, deeper on the crown, freckled across the scalp, flushed cheeks
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(64, 168, 178), (len(P), 3)).copy()
    sk = sk + (srgb(44, 128, 146) - sk) * (smooth(1.9, 2.1, z) * 0.6)[:, None]
    sk = sk + (srgb(110, 196, 186) - sk) * (smooth(-0.15, -0.28, y) * smooth(1.55, 1.75, z) * smooth(2.0, 1.85, z) * 0.35)[:, None]
    cheek = smooth(0.07, 0.0, np.linalg.norm(Q - v3((0.15, -0.23, 1.68)), axis=1))
    sk = sk + (srgb(206, 132, 140) - sk) * (cheek * 0.45)[:, None]
    sk *= (1.0 + 0.08 * mott)[:, None]
    put(m, sk, 0.5, bump=0.22)
    spk(m & (z > 1.85), (34, 104, 118), 0.42)
    spk(m & (z <= 1.85), (40, 120, 130), 0.18)
    # eyes: big whites, sea-green irises, inked pupils, two glints (the old model's double highlight)
    m = c.mask(EYE)
    ey = np.broadcast_to(srgb(244, 242, 232), (len(P), 3)).copy()
    for ec, re, lid in (EYE_L, EYE_R):
        dv = P - ec
        r = np.linalg.norm(dv, axis=1)
        near = m & (r < re * 1.25)
        dd = dv / np.maximum(r, 1e-6)[:, None]
        ang = np.arccos(np.clip(dd @ LOOK, -1, 1))
        ir = srgb(120, 188, 120) + (srgb(36, 96, 70) - srgb(120, 188, 120)) * smooth(0.15, 0.48, ang)[:, None]
        ey[near] = np.where((ang < 0.5)[near, None], ir[near], ey[near])
        c.draw(near, (ang - 0.26) * re, 0.0)
        c.draw(near & (ang < 0.65), np.abs(ang - 0.5) * re, 0.0008, 0.7)
        for gd, sz in ((unit(LOOK + v3((0.3, 0, 0.5))), 0.16), (unit(LOOK + v3((-0.15, 0, -0.25))), 0.08)):
            g = smooth(sz, sz * 0.55, np.arccos(np.clip(dd @ gd, -1, 1)))
            ey[near] = ey[near] + (srgb(255, 255, 250) - ey[near]) * g[near, None]
        ey[near] *= (1.0 - 0.3 * smooth(0.1, 0.8, dd[near, 2]))[:, None]
        sm = c.mask(SKIN) & (r < re + 0.012) & (dv[:, 2] > -re * 0.1) & (dv[:, 1] < 0.01)
        c.draw(sm, np.abs(r - re - 0.002), 0.0016, 0.95)
        # lower lid: a faint crease under each eye
        lo = c.mask(SKIN) & (r < re + 0.03) & (dv[:, 2] < -re * 0.55)
        c.draw(lo, np.abs(r - re - 0.016), 0.0011, 0.3)
    put(m, ey, 0.08)
    c.spk[m, 3] = 0.0
    put(c.mask(LIP), srgb(42, 120, 128), 0.35, bump=0.2)
    put(c.mask(MOUTH), srgb(16, 36, 40), 0.6)
    m = c.mask(BOBBLE)
    put(m, srgb(246, 220, 80) * (1.0 + 0.4 * c.wear)[:, None], 0.25)
    # the shirt: rust and cream gingham check, a little faded, collar and cuffs worn pale
    m = c.mask(SHIRT)
    cu = np.floor((x + 0.5) / 0.022).astype(int) % 2
    cv = np.floor((z + 0.5) / 0.022).astype(int) % 2
    ck = (cu + cv) / 2.0
    sh = srgb(234, 214, 182) + (srgb(176, 74, 44) - srgb(234, 214, 182)) * (0.25 + 0.6 * ck)[:, None]
    sh *= (1.0 + 0.06 * mott + 0.3 * c.wear)[:, None]
    put(m, sh, 0.85, bump=0.8)
    spk(m, (120, 70, 40), 0.12)
    put(c.mask(BUTTON), srgb(236, 226, 206), 0.3)
    # cords: brown corduroy wales down the legs, worn at the knees and seat
    m = c.mask(TROUSERS)
    tr = srgb(120, 76, 40) * (1.0 + 0.08 * mott + 0.4 * c.wear)[:, None]
    knee = smooth(0.06, 0.0, np.linalg.norm(Q - (KNEE + v3((0, -0.05, 0))), axis=1))
    tr = tr + (srgb(156, 112, 72) - tr) * (knee * 0.5)[:, None]
    put(m, tr, 0.9, bump=1.0)
    c.strp[m, 0] = (np.arctan2(Q[:, 0] - 0.085, -y) * 0.06 * 0.4 * 2.5)[m]
    c.strp[m, 1] = 0.55
    m = c.mask(BELT)
    put(m, srgb(70, 42, 24) * (1.0 + 0.6 * c.wear)[:, None], 0.45, bump=0.8, grain=1.0)
    put(c.mask(BRASS), srgb(214, 164, 76), 0.3, metal=1.0, grain=1.0, bump=0.1)
    m = c.mask(SOCK)
    put(m, srgb(236, 232, 220) * (1.0 + 0.05 * mott)[:, None], 0.9, bump=1.0)
    c.strp[m, 0] = (np.arctan2(Q[:, 0] - 0.09, -y) * 0.035 * 0.4 * 2.5)[m]
    c.strp[m, 1] = 0.4
    # sneakers: orange suede, cream soles scuffed, cream laces
    m = c.mask(SHOE)
    put(m, srgb(214, 104, 40) * (1.0 + 0.08 * mott + 0.4 * c.wear)[:, None], 0.75, bump=1.0, grain=1.0)
    m = c.mask(SOLE)
    put(m, srgb(234, 226, 204) * (1.0 - 0.35 * smooth(0.2, 0.9, n2) - 0.3 * smooth(0.02, 0.0, z))[:, None], 0.75, bump=0.3)
    c.draw(m & (np.abs(z - 0.02) < 0.01), np.abs(z - 0.02), 0.0008, 0.45)
    put(c.mask(LACE), srgb(240, 236, 224), 0.8, bump=0.4)
    put(c.mask(NAIL), srgb(40, 120, 128), 0.3)
    c.col *= (0.32 + 0.68 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model

GAME = {
    "budget": {"head": 2600, "body": 5200},
    "density": {"head": 1.6},
    "tex": 2048,
    "stride": {"walk": 1.12, "run": 2.0},
    "speed": 0.9,
    "look": ["head", "antenna"], "neck": "neck",
    "look_pivot": (0.0, 0.01, 1.42),
    "radius": 0.4,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.005, 0.96), (0, 0.005, 1.08), "root", 0.12),
        Bone("spine", (0, 0.005, 1.08), (0, 0.0, 1.2), "hips", 0.11),
        Bone("chest", (0, 0.0, 1.2), (0, 0.01, 1.32), "spine", 0.12),
        Bone("neck", NECK_A, NECK_B, "chest", 0.04),
        Bone("head", NECK_B, HEAD_C + v3((0, 0, 0.3)), "neck", 0.25),
        Bone("antenna", ANT_A, ANT_B, "head", 0.02),
        Bone("shoulder.L", (0.03, 0.005, 1.3), SHOULDER, "chest", 0.04),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.035),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.028),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.11, "forearm.L", 0.02),
        Bone("thigh.L", HIP, KNEE, "hips", 0.07),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.05),
        Bone("foot.L", ANKLE, (0.094, -0.15, 0.03), "shin.L", 0.04),
    ])
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
    rig[hp & (z > 1.47)] = ix["head"]
    rig[hp & (np.linalg.norm(P - (ANT_A + ANT_B) * 0.5, axis=1) < 0.07) & (z > ANT_A[2] - 0.005)] = ix["antenna"]
    bp = piece == 1
    legs = bp & (np.isin(part, (TROUSERS, SOCK, SHOE, SOLE, LACE)) & (z < 1.02) | (z < 0.3) & (np.abs(x) < 0.17))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    arms = bp & ~legs & (np.abs(x) > 0.17)
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "upper_arm.R", "forearm.R", "hand.R")
    torso = bp & ~legs & ~arms
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.09) & (z > 1.2), "shoulder.L", "upper_arm.L")
    allow(torso & (x < -0.09) & (z > 1.2), "shoulder.R", "upper_arm.R")
    return A, rig


WALK = dict(stride=1.12, stance=0.58, foot_x=0.085, lift=0.075, bob=0.028, drop=0.035, sway=0.02, roll=4.0, yaw=6.0, counter=1.2,
            lean=2.0, toe_off=18.0, toe_out=5.0, swing_point=10.0)
RUN = dict(stride=2.0, stance=0.4, foot_x=0.09, lift=0.15, bob=0.04, drop=0.08, sway=0.02, roll=4.0, yaw=8.0, counter=1.3,
           lean=12.0, toe_off=26.0, toe_out=5.0, swing_point=16.0, spine_lean=4.0)


def motions(rig):
    """walk: an easy loose walk on long legs; the great head rides on the thin neck like a balloon on a stick: it bobs a beat behind every
    step, nodding and settling, the antenna flicking after it. run: a gangly run, the head thrown back and wobbling. idle: the head
    lolling gently, a slow look about, a blink-long nod"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        c = math.cos(TAU * u)
        a = 30.0 if run else 13.0
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, sg * a * c, 0, -sg * 3.0)
            p.rot("forearm." + side, -(40.0 if run else 10.0) - 10.0 * max(0.0, sg * c), 0, 0)
        # the head: a damped spring behind the hips' bob (two bobs a cycle), a nod, a sway the other way to the step
        b = math.sin(2 * TAU * u - 1.3)
        p.rot("neck", (10.0 if run else 0.0) + (5.0 if run else 4.0) * b, 0, 0)
        p.rot("head", (-14.0 if run else 0.0) + (6.0 if run else 7.0) * math.sin(2 * TAU * u - 2.0), -(5.0 if run else 4.0) * math.sin(TAU * u - 0.9),
              (4.0 if run else 2.5) * math.sin(TAU * u - 0.6))
        p.rot("antenna", 14.0 * math.sin(2 * TAU * u - 2.8), 0, 8.0 * math.sin(TAU * u - 1.6))
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sw = math.sin(TAU * t / 6.0)
        stand(rig, p, legs, {"L": (Vector((0.1, -0.08, 0.0)), 8.0), "R": (Vector((-0.11, -0.04, 0.0)), -12.0)},
              hip_shift=(0.02 * sw, 0.0, -0.012), roll=-2.0 * sw)
        p.rot("spine", 1.0 * math.sin(TAU * t / 3.0), 0, 0)
        look = ease((t - 1.0) / 0.8) * (1.0 - ease((t - 3.2) / 0.8))
        nod = math.exp(-((t - 4.4) / 0.2) ** 2)
        p.rot("neck", 3.0 * math.sin(TAU * t / 3.0), 0, 0)
        p.rot("head", 5.0 * math.sin(TAU * t / 6.0 + 1.0) + 10.0 * nod, -6.0 * math.sin(TAU * t / 6.0), 25.0 * look * math.sin(TAU * (t - 1.0) / 4.4))
        p.rot("antenna", 6.0 * math.sin(TAU * t / 2.0) + 12.0 * nod, 0, 4.0 * math.sin(TAU * t / 3.0))
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, 2.0 * math.sin(TAU * t / 3.0 + sg), 0, -sg * 2.0)
            p.rot("forearm." + side, -8.0, 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
