## FOINT CITY townsfolk: disguised. A cheap human suit walking stiffly: a mannequin's rubber face with painted doll eyes and a fixed red smile, a boxy plaid suit, rubber-glove hands; the top of the head is an open hatch (the wig rides on its lid), and down inside sits the real driver, a little green alien working a lever.
# Upgrade of the three.js game's disguised (folk-species-b.js; old render refs/old/disguised.png): same idea (a pink human head with blue eyes,
# a red tie, a teal check suit, the hatch flipped up at the back, the green pilot with antennae and a lever), lifted to the new sheets (refs
# 4/6/7): a visibly fake face (seams, rouge, a zip up the back), a wig on the lid, a squarer, stiffer suit.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 1.80
REF = ("old/disguised.png", None)

SKIN, EYE, LIP, WIG, INSIDE, ALIEN, AEYE, LEVER, KNOB, SUIT, SHIRT, TIE, SHOE, SOLE, BRASS, NOSE = range(1, 17)
COLOURS = {
    SKIN: ((0.82, 0.52, 0.42), 0.4, 0.0),
    EYE: ((0.9, 0.9, 0.88), 0.1, 0.0),
    LIP: ((0.7, 0.1, 0.12), 0.3, 0.0),
    WIG: ((0.3, 0.17, 0.08), 0.7, 0.0),
    INSIDE: ((0.15, 0.07, 0.06), 0.8, 0.0),
    ALIEN: ((0.3, 0.7, 0.2), 0.4, 0.0),
    AEYE: ((0.02, 0.02, 0.03), 0.05, 0.0),
    LEVER: ((0.5, 0.5, 0.5), 0.3, 1.0),
    KNOB: ((0.8, 0.08, 0.06), 0.25, 0.0),
    SUIT: ((0.1, 0.3, 0.3), 0.8, 0.0),
    SHIRT: ((0.88, 0.86, 0.8), 0.6, 0.0),
    TIE: ((0.6, 0.06, 0.06), 0.4, 0.0),
    SHOE: ((0.22, 0.12, 0.06), 0.35, 0.0),
    SOLE: ((0.1, 0.07, 0.05), 0.6, 0.0),
    BRASS: ((0.8, 0.6, 0.25), 0.3, 1.0),
    NOSE: ((0.85, 0.55, 0.45), 0.35, 0.0),
}
UP = v3((0, 0, 1))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# landmarks, left side (+X); the figure faces -Y
HIP = v3((0.11, 0.01, 0.88))
KNEE = v3((0.115, -0.006, 0.49))
ANKLE = v3((0.12, 0.025, 0.09))
HEM = v3((0.12, 0.018, 0.12))
BALL = v3((0.122, -0.095, 0.0))
SHOULDER = v3((0.285, 0.01, 1.385))
ELBOW = v3((0.315, 0.02, 1.10))
WRIST = v3((0.322, 0.0, 0.84))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
HEAD_C = v3((0.0, -0.004, 1.562))
HEAD_R = (0.118, 0.124, 0.13)
CUT_Z = 1.632                                  # the hatch's rim (it slopes up toward the back)
CUT_N = unit((0.0, -0.18, 1.0))
HINGE = v3((0.0, 0.112, 1.655))
LID_OPEN = -132.0                               # how far the lid is flipped back about the hinge (degrees about X)
EYES = [(v3((0.05, -0.108, 1.574)), 0.024), (v3((-0.052, -0.106, 1.578)), 0.025)]
PILOT_C = v3((0.0, -0.012, 1.628))
LEVER_A, LEVER_B = v3((0.05, -0.02, 1.53)), v3((0.062, -0.052, 1.652))


def mask_outer():
    return Union([
        Ellipsoid(HEAD_C, HEAD_R),
        Ellipsoid(HEAD_C + v3((0, -0.03, -0.075)), (0.09, 0.09, 0.07)),
    ], k=0.04, part=SKIN)


def head():
    """the mask: a too-round rubber head, hollow, its top cut off for the hatch; doll eyes, a moulded nose, a painted-on smile, flat ears,
    a fringe of wig round the back below the rim; the lid flipped back on its hinge carrying the rest of the wig; the pilot inside"""
    outer = mask_outer()
    neck = Union([RoundCone((0, 0.02, 1.36), (0, 0.006, 1.49), 0.062, 0.058), Torus((0, 0.016, 1.41), 0.06, 0.009), Torus((0, 0.012, 1.44), 0.059, 0.008)], k=0.012, part=SKIN)
    ears = Mirror(Union([Ellipsoid((0.118, 0.006, 1.56), (0.016, 0.03, 0.042), R=rot(rz=-8)), ], k=0.0, part=SKIN))
    eyes = [Sphere(ec, re, part=EYE) for ec, re in EYES]
    sockets = [Torus(ec + v3((0, -re * 0.55, 0)), re * 0.86, 0.0055, Rm=basis(v3((0, -1, 0)), v3((0, 0, 1))), part=SKIN) for ec, re in EYES]
    nose = Gem((0, -0.128, 1.547), (0.015, 0.015, 0.021, 0.008, 0.022, 0.015), soft=0.35, edge=0.004, part=NOSE)
    # the painted-on smile: a thin raised crescent of red following the chin, corners turned up
    xs = np.linspace(-0.054, 0.054, 13)
    crescent = [(float(xx), 1.503 + 6.0 * xx * xx) for xx in xs] + [(float(xx), 1.489 + 9.5 * xx * xx) for xx in xs[::-1]]
    smile = Clip(Inflate(outer, 0.0045, part=LIP), [prism(crescent, -0.5, -0.05)], k=0.0015)
    face = Union([Union([outer, neck, ears] + sockets, k=0.02), nose, smile], k=0.006)
    wig_back = Clip(Inflate(outer, 0.012, part=WIG), [Half((0, 0.02, 1.55), (0, -0.55, -1)), Half((0, -0.03, 0), (0, -1, 0))], k=0.006)
    face = Union([face, wig_back], k=0.0)
    # the hatch: everything above the sloping rim cut away, the head hollowed to a 9 mm shell
    head = Cut(Clip(face, [rim()], k=0.002), [Clip(shell_in(), [Half((0, 0, 1.47), (0, 0, -1))])], k=0.003)
    hinge = Union([RoundCone(HINGE + v3((-0.04, 0.006, 0)), HINGE + v3((0.04, 0.006, 0)), 0.008, 0.008, part=LEVER),
                   Box(HINGE + v3((0, -0.005, -0.012)), (0.035, 0.004, 0.014), rr=0.003, part=LEVER)], k=0.0)
    return Union([head, lid(), hinge] + eyes, k=0.0)


def rim():
    return Half(v3((0, 0, CUT_Z)), CUT_N)


def shell_in():
    return Inflate(mask_outer(), -0.009)


def lid_rest():
    """the cut-off cap where it was before it was flipped open: the skin shell and the rest of the wig, a side parting"""
    outer = mask_outer()
    cap = Clip(Union([outer, Inflate(outer, 0.012, part=WIG)], k=0.0), [Half(v3((0, 0, CUT_Z)), -CUT_N)], k=0.002)
    cap = Cut(cap, [shell_in()], k=0.002)
    part_line = Box((0.04, -0.02, 1.70), (0.004, 0.09, 0.02), rr=0.003)
    return Cut(cap, [part_line], k=0.003)


def lid():
    return Move(lid_rest(), R=rot(rx=LID_OPEN), pivot=HINGE)


def pilot():
    """the driver: a little green head peeping over the rim, big black eyes, two antennae, a hand on the lever"""
    pc = PILOT_C
    skull = Union([Ellipsoid(pc, (0.05, 0.045, 0.045)), Ellipsoid(pc + v3((0, -0.012, -0.03)), (0.032, 0.03, 0.025)), Ellipsoid(pc + v3((0, 0.01, -0.07)), (0.055, 0.04, 0.035))], k=0.02, part=ALIEN)
    eyes = Mirror(Ellipsoid(pc + v3((0.022, -0.035, 0.006)), (0.016, 0.012, 0.011), R=rot(ry=-24), part=AEYE))
    ants = Mirror(Union([loft([(pc + v3((0.018, 0.0, 0.04)), 0.004), (pc + v3((0.03, -0.004, 0.08)), 0.0032), (pc + v3((0.042, 0.004, 0.105)), 0.003)], part=ALIEN, k=0.003),
                         Sphere(pc + v3((0.043, 0.004, 0.108)), 0.0075, part=ALIEN)], k=0.002))
    arm = loft([(pc + v3((0.045, 0.006, -0.07)), 0.011), (pc + v3((0.06, -0.02, -0.062)), 0.009), (LEVER_B + v3((-0.004, 0.004, -0.02)), 0.0085)], part=ALIEN, k=0.006)
    fist = Sphere(LEVER_B + v3((-0.002, 0.003, -0.018)), 0.012, part=ALIEN)
    lever = Union([RoundCone(LEVER_A, LEVER_B, 0.004, 0.004, part=LEVER), Sphere(LEVER_B + unit(LEVER_B - LEVER_A) * 0.006, 0.011, part=KNOB)], k=0.0)
    return Union([Union([skull, ants, arm, fist], k=0.006), eyes, lever], k=0.0)


# ---------------------------------------------------------------------------------------------------- the suit

def torso_core():
    """a square chest, square shoulders, straight down: a suit cut for a shape that is not quite a man"""
    return Union([
        Box((0, 0.0, 1.23), (0.2, 0.115, 0.17), rr=0.09),
        Box((0, 0.008, 1.37), (0.25, 0.1, 0.05), rr=0.05),
        Box((0, 0.004, 1.02), (0.18, 0.11, 0.12), rr=0.08),
    ], k=0.05, part=SHIRT)


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def front_y(shape, x, z, y0=-0.5, y1=0.3):
    ys = np.linspace(y0, y1, 1601).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    return float(ys[int(np.argmax(shape.eval(P)[0] < 0))])


def jacket(sleeves):
    core = torso_core()
    shell = Union([
        Inflate(core, 0.014, part=SUIT),
        Mirror(Box((0.26, 0.008, 1.39), (0.06, 0.09, 0.035), rr=0.025, part=SUIT)),
        Box((0, 0.006, 0.94), (0.2, 0.13, 0.08), rr=0.07, part=SUIT),
    ], k=0.03, part=SUIT)
    shell = Clip(shell, [Half((0, 0, 0.87), (0, 0, -1))], k=0.004)
    shell = Union([shell] + sleeves, k=0.016, part=SUIT)
    opening = prism([(-0.075, 1.44), (0.075, 1.44), (0.008, 1.12), (-0.008, 1.12)])
    shell = Cut(shell, [opening], k=0.008)
    outer = [(0.075, 1.435), (0.008, 1.125), (0.07, 1.27), (0.11, 1.36), (0.098, 1.375), (0.118, 1.41), (0.096, 1.435)]
    lap = Clip(Inflate(core, 0.022, part=SUIT), [Mirror(prism(outer))], k=0.005)
    shell = Union([shell, lap], k=0.0, part=SUIT)
    collar = Clip(Cut(Inflate(core, 0.028, part=SHIRT), [Inflate(core, 0.021)], k=0.002), [Mirror(prism([(0.0, 1.41), (0.055, 1.445), (0.065, 1.4), (0.026, 1.37)]))], k=0.004)
    band = Clip(RoundCone((0, 0.016, 1.36), (0, 0.012, 1.43), 0.07, 0.066, part=SHIRT), [Half((0, 0, 1.435), (0, 0, 1))], k=0.003)
    ky = front_y(core, 0, 1.39)
    knot = Box((0, ky - 0.012, 1.392), (0.02, 0.014, 0.02), rr=0.009, R=rot(rx=10), part=TIE)
    blade = Clip(Inflate(core, 0.007, part=TIE), [prism([(-0.016, 1.38), (0.016, 1.38), (0.03, 1.25), (0.034, 1.16), (0.0, 1.12), (-0.034, 1.16), (-0.03, 1.25)])], k=0.002)
    buttons = [Ellipsoid((0.0, front_y(Inflate(core, 0.014), 0.0, z) - 0.002, z), (0.011, 0.005, 0.011), part=SOLE) for z in (0.98, 1.07)]
    pocket = Mirror(Clip(Inflate(core, 0.019, part=SUIT), [prism([(0.11, 1.0), (0.2, 1.0), (0.2, 1.012), (0.11, 1.012)])], k=0.002))
    return Union([core, shell, collar, band, knot, blade, pocket] + buttons, k=0.0)


def legs():
    hips = Union([
        Box((0, 0.008, 0.92), (0.19, 0.115, 0.07), rr=0.06),
        Mirror(loft([(HIP, 0.095), (KNEE, 0.084), (HEM, 0.082)])),
    ], k=0.04, part=SUIT)
    ridge = ridge_line((0.11, -0.095, 0.84), (0.12, -0.08, 0.13), 0.012)

    def crease(P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        return ridge(Q)
    hips = Bump(hips, crease, 0.003)
    trousers = Clip(hips, [Half((0, 0, 0.11), (0.0, -0.2, -1.0))], k=0.003)
    return Union([trousers, Mirror(shoe())], k=0.0)


def shoe():
    x = ANKLE[0]
    last = Union([
        loft([(ANKLE + v3((0, 0.012, 0.0)), 0.047), (v3((x + 0.002, -0.065, 0.045)), 0.05), (v3((x + 0.004, -0.15, 0.036)), 0.042)], k=0.02),
        Ellipsoid((x + 0.004, -0.16, 0.034), (0.05, 0.05, 0.034)),
    ], k=0.02)
    upper = Clip(Inflate(last, 0.0, part=SHOE), [Half((0, 0, 0.022), (0, 0, -1))], k=0.003)
    sole = Clip(Inflate(last, 0.005, part=SOLE), [Half((0, 0, 0.024), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    heel = Box((x, 0.035, 0.016), (0.042, 0.04, 0.016), rr=0.008, part=SOLE)
    return Union([upper, sole, heel], k=0.004)


def glove(s=1.06):
    """a pink rubber glove in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y): four sausage fingers held stiff together"""
    palm = Box((0.0, 0.0, -0.05), (0.017, 0.042, 0.05), rr=0.016, part=SKIN)
    wrist = Union([RoundCone((0, 0, 0.04), (0, 0, -0.01), 0.034, 0.03), Torus((0, 0, 0.022), 0.032, 0.006)], k=0.004, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.03, -0.01, 0.01, 0.03):
        parts.append(loft([(v3((0.0, f * 0.95, -0.09)), 0.0115), (v3((-0.004, f, -0.135)), 0.011), (v3((-0.01, f, -0.162)), 0.0105)], part=SKIN, k=0.003))
    parts.append(loft([(v3((-0.012, -0.034, -0.03)), 0.0135), (v3((-0.024, -0.05, -0.065)), 0.012), (v3((-0.03, -0.05, -0.09)), 0.011)], part=SKIN, k=0.003))
    return Union(parts, k=0.006)


def sleeve():
    s = Clip(loft([(SHOULDER, 0.074), (ELBOW, 0.068), (WRIST, 0.064)], part=SUIT, k=0.0), [Half(WRIST + (WRIST - ELBOW) * 0.02, (WRIST - ELBOW))], k=0.003)
    d = unit(WRIST - ELBOW)
    cuff = Clip(Cut(CappedCone(WRIST - d * 0.02, WRIST + d * 0.012, 0.052, 0.05, rr=0.004, part=SHIRT), [CappedCone(WRIST - d * 0.03, WRIST + d * 0.03, 0.044, 0.044)]), [Half(WRIST + d * 0.012, d)])
    return s, Union([cuff, place(glove(), WRIST, HAND)], k=0.0)


def pieces():
    sl, hd = sleeve()
    body = Union([jacket([sl, Move(sl, R=FLIP)]), legs(), hd, Move(hd, R=FLIP)], k=0.0)
    return [("head", head(), 0.0018), ("pilot", pilot(), 0.0012), ("body", body, 0.0035)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    N = c.N
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

    # the rubber skin: an even, slightly shiny salmon pink; round rouge spots; the seams of the mask inked as stitches; a zip up the back
    m = c.mask(SKIN, NOSE)
    sk = np.broadcast_to(srgb(236, 160, 136), (len(P), 3)).copy()
    sk *= (1.0 + 0.03 * mott)[:, None]
    rouge = smooth(0.032, 0.02, np.linalg.norm(Q - v3((0.075, -0.098, 1.535)), axis=1))
    sk = sk + (srgb(232, 104, 104) - sk) * (rouge * 0.7)[:, None]
    put(m, sk, 0.32, bump=0.05)
    hd = m & (z > 1.45) & (z < 1.75)
    rel = P - HEAD_C
    ring = np.abs(np.arctan2(rel[:, 0], -rel[:, 1]))          # 0 at the nose, pi at the back
    stitch = np.sin(np.linalg.norm(rel, axis=1) * 0 + (rel[:, 2] + np.abs(rel[:, 0])) * 330.0) > 0.0
    c.draw(hd & stitch & (np.abs(ring - 1.35) < 0.08), np.abs(ring - 1.35) * 0.12, 0.0011, 0.65)
    zip_ = m & (y > 0.05) & (np.abs(x) < 0.012) & (z > 1.36) & (z < CUT_Z + 0.02)
    teeth = np.sin(z * 900.0) > 0.0
    c.draw(zip_, np.where(teeth, np.abs(x) - 0.004, np.abs(x) - 0.0015), 0.0, 0.9)
    # painted brows: thin high arches, a little uneven
    for (ec, re), lift in zip(EYES, (0.042, 0.048)):
        bc = ec + v3((0.0, -0.01, lift))
        d = P - bc
        br = m & (np.abs(d[:, 0]) < 0.03) & (np.abs(d[:, 2]) < 0.015) & (y < -0.06)
        c.draw(br, np.abs(d[:, 2] + 18.0 * d[:, 0] ** 2), 0.0016, 0.85)
    # doll eyes: glossy whites, flat blue irises, black pupils, a painted lash line over each; they stare straight ahead
    m = c.mask(EYE)
    ey = np.broadcast_to(srgb(246, 246, 240), (len(P), 3)).copy()
    for ec, re in EYES:
        dv = P - ec
        r = np.linalg.norm(dv, axis=1)
        near = m & (r < re * 1.3)
        dd = dv / np.maximum(r, 1e-6)[:, None]
        ang = np.arccos(np.clip(dd @ v3((0, -1, 0)), -1, 1))
        ey[near] = np.where((ang < 0.52)[near, None], srgb(60, 128, 210), ey[near])
        c.draw(near, (ang - 0.24) * re, 0.0)
        c.draw(near & (ang < 0.7), np.abs(ang - 0.52) * re, 0.0006, 0.8)
        c.draw(near & (dd[:, 2] > 0.25), np.abs(dd[:, 2] - 0.55) * re, 0.0012, 0.95)
    put(m, ey, 0.05)
    c.spk[m, 3] = 0.0
    put(c.mask(LIP), srgb(206, 32, 44), 0.22)
    m = c.mask(WIG)
    wg = srgb(96, 56, 26) * (1.0 + 0.3 * noise3(P, 0.004))[:, None]
    put(m, wg, 0.55, bump=1.0)
    c.strp[m, 0] = ((P[:, 0] * 0.6 + P[:, 1] * 0.2) * 1.2)[m]
    c.strp[m, 1] = 0.9
    # the inside of the mask and of its lid: bare dark rubber
    hm = c.mask(SKIN, WIG) & (z > 1.47)
    if hm.any():
        is_lid = np.abs(lid().eval(P)[0]) < 0.0015
        local = (P - HINGE) @ rot(rx=LID_OPEN) + HINGE
        outer = mask_outer()
        din = np.where(is_lid, outer.eval(local)[0], outer.eval(P)[0])
        inside = hm & (din < -0.005)
        put(inside, srgb(58, 30, 26) * (1.0 + 0.15 * n2)[:, None], 0.8, bump=0.1)
        c.spk[inside, 3] = 0.0
        c.strp[inside, 1] = 0.0
    # the pilot: lime green, darker on top, glossy black eyes with a glint
    m = c.mask(ALIEN)
    al = srgb(120, 204, 70) + (srgb(70, 150, 50) - srgb(120, 204, 70)) * smooth(PILOT_C[2] - 0.01, PILOT_C[2] + 0.06, z)[:, None]
    put(m, al * (1.0 + 0.1 * mott)[:, None], 0.4, bump=0.2)
    spk(m, (60, 130, 40), 0.3)
    m = c.mask(AEYE)
    ae = np.broadcast_to(srgb(10, 10, 16), (len(P), 3)).copy()
    for s in (1.0, -1.0):
        gc = PILOT_C + v3((s * 0.018, -0.046, 0.012))
        ae = ae + (srgb(240, 240, 250) - ae) * smooth(0.005, 0.003, np.linalg.norm(P - gc, axis=1))[:, None]
    put(m, ae, 0.05)
    m = c.mask(LEVER)
    put(m, srgb(150, 150, 156) * (1.0 - 0.4 * c.cavity)[:, None], 0.3, metal=1.0, grain=1.0, bump=0.1)
    put(c.mask(KNOB), srgb(220, 30, 26), 0.2)
    # the suit: a loud teal plaid: dark teal ground, broad lighter bands both ways, a thin red over-check
    m = c.mask(SUIT)
    side = np.abs(N[:, 0]) > 0.7
    u = np.where(side, y, x)
    def band(v, w):
        return smooth(w, w * 0.6, np.abs(((v + 0.5) % 0.09) - 0.045))
    bu, bv = band(u, 0.016), band(z, 0.016)
    su = srgb(26, 76, 78) + (srgb(64, 132, 128) - srgb(26, 76, 78)) * (0.5 * bu + 0.5 * bv)[:, None]
    su = su * (1.0 + 0.06 * mott + 0.2 * c.wear)[:, None]
    red = smooth(0.0025, 0.0012, np.minimum(np.abs(((u + 0.5 + 0.045) % 0.09) - 0.045), np.abs(((z + 0.5 + 0.045) % 0.09) - 0.045)))
    su = su + (srgb(168, 40, 36) - su) * (red * 0.8)[:, None]
    put(m, su, 0.85, bump=1.0)
    m = c.mask(SHIRT)
    put(m, srgb(238, 234, 222) * (1.0 + 0.03 * mott)[:, None], 0.6, bump=0.4)
    m = c.mask(TIE)
    put(m, srgb(184, 26, 30), 0.35, bump=0.3)
    c.strp[m, 0] = ((x - z) * 0.6)[m]
    c.strp[m, 1] = 0.8
    m = c.mask(SHOE)
    put(m, srgb(92, 50, 24) * (1.0 + 0.9 * c.wear)[:, None], 0.25, bump=0.2, grain=1.0)
    put(c.mask(SOLE), srgb(34, 24, 18), 0.6)
    put(c.mask(BRASS), srgb(214, 164, 76), 0.3, metal=1.0)
    c.col *= (0.32 + 0.68 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model

GAME = {
    "budget": {"head": 3200, "pilot": 1000, "body": 4400},
    "density": {"head": 1.6, "pilot": 2.2},
    "tex": 2048,
    "stride": {"walk": 1.0, "run": 1.6},
    "speed": 0.8,
    "look": ["head", "lid", "pilot"], "neck": "neck",
    "look_pivot": (0.0, 0.01, 1.47),
    "radius": 0.38,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.01, 0.9), (0, 0.01, 1.04), "root", 0.15),
        Bone("spine", (0, 0.01, 1.04), (0, 0.005, 1.2), "hips", 0.15),
        Bone("chest", (0, 0.005, 1.2), (0, 0.01, 1.38), "spine", 0.17),
        Bone("neck", (0, 0.016, 1.38), (0, 0.006, 1.49), "chest", 0.06),
        Bone("head", (0, 0.006, 1.49), (0, 0.0, 1.64), "neck", 0.12),
        Bone("lid", HINGE, HINGE + v3((0, 0.02, 0.12)), "head", 0.05),
        Bone("pilot", PILOT_C - v3((0, 0, 0.07)), PILOT_C + v3((0, 0, 0.05)), "head", 0.04),
        Bone("lever", LEVER_A, LEVER_B, "head", 0.01),
        Bone("shoulder.L", (0.05, 0.01, 1.38), SHOULDER, "chest", 0.06),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.07),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.065),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.12, "forearm.L", 0.035),
        Bone("thigh.L", HIP, KNEE, "hips", 0.095),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.085),
        Bone("foot.L", ANKLE, (0.124, -0.17, 0.03), "shin.L", 0.04),
    ])
    return bones


def skin_rules(P, part, piece, names):
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 1.47)] = ix["head"]
    # the lid and everything on it (above the rim and behind it)
    lid = hp & ((z > CUT_Z + 0.02) & (y > 0.03) | (y > HINGE[1] + 0.012) & (z > 1.6))
    rig[lid] = ix["lid"]
    pp = piece == 1
    rig[pp & ~np.isin(part, (LEVER, KNOB))] = ix["pilot"]
    rig[pp & np.isin(part, (LEVER, KNOB))] = ix["lever"]
    near_knob = pp & (part == ALIEN) & (np.linalg.norm(P - LEVER_B, axis=1) < 0.03)
    rig[near_knob] = ix["lever"]
    allow(pp, "head")
    bp = piece == 2
    legs = bp & (z < 0.86) | bp & (z < 0.95) & (np.abs(x) < 0.22) & (part == SUIT) & ~((y < -0.08) & (z > 0.88))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    arms = bp & ~legs & (np.abs(x) > 0.245) & (z < 1.33)
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "upper_arm.R", "forearm.R", "hand.R")
    torso = bp & ~legs & ~arms
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.15) & (z > 1.2), "shoulder.L", "upper_arm.L")
    allow(torso & (x < -0.15) & (z > 1.2), "shoulder.R", "upper_arm.R")
    return A, rig


def motions(rig):
    """walk: stiff as a mannequin: straight-kneed steps that land flat and a touch too hard, arms swinging from the shoulder like boards,
    the body rigid and rocking side to side, the head fixed straight ahead; down in the hatch the pilot works the lever back and forth
    with each step and the lid flaps on its hinge. run: the same, faster and more desperate, the pilot hanging on. idle: standing too
    straight; the pilot peers left and right over the rim, the head (his steering) jerks after him a beat late"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, run):
        g = dict(stride=1.6 if run else 1.0, stance=0.5 if run else 0.62, foot_x=0.13, lift=0.09 if run else 0.05, bob=0.004, drop=0.012 if run else 0.004,
                 sway=0.035, roll=0.0, yaw=0.0, counter=0.0, lean=4.0 if run else 0.0, toe_off=4.0, toe_out=2.0, swing_point=-6.0)
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        s = math.sin(TAU * u)
        c = math.cos(TAU * u)
        # rigid rock from side to side over each foot, a stiff bob on each landing
        p.rot("hips", 0, 5.0 * s, 0)
        p.offset = p.offset + Vector((0.0, 0.0, 0.012 * abs(math.sin(TAU * u)) - 0.006))
        a = 30.0 if run else 20.0
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, sg * a * c, 0, -sg * (6.0 if run else 3.0))
            p.rot("forearm." + side, -(12.0 if run else 2.0), 0, 0)
        p.world["head"] = R(0.0, 0.0, 0.0)
        p.rot("lever", (26.0 if run else 18.0) * c, 0, 6.0 * s)
        p.rot("pilot", (8.0 if run else 3.0) * math.sin(2 * TAU * u), 0, (6.0 if run else 10.0) * math.sin(TAU * u * 1.0 + 0.6))
        p.rot("lid", (12.0 if run else 6.0) * math.sin(2 * TAU * u - 0.8) - (8.0 if run else 0.0), 0, 0)
        return p
    walk = [walkish(i / 32.0, False) for i in range(33)]
    run = [walkish(i / 24.0, True) for i in range(25)]
    idle = []
    keys = [(0.0, 0.0), (0.8, 30.0), (2.0, 30.0), (2.6, -35.0), (3.8, -35.0), (4.4, 0.0), (6.0, 0.0)]

    def peer(t):
        for (t0, a0), (t1, a1) in zip(keys, keys[1:]):
            if t0 <= t <= t1:
                return a0 + (a1 - a0) * ease((t - t0) / max(0.01, min(0.35, t1 - t0)))
        return 0.0
    for i in range(181):
        t = i / 30.0
        p = Pose()
        stand(rig, p, legs, {"L": (Vector((0.125, -0.095, 0.0)), 2.0), "R": (Vector((-0.125, -0.095, 0.0)), -2.0)},
              hip_shift=(0.0, 0.0, -0.003))
        p.rot("chest", 0.6 * math.sin(TAU * t / 3.0), 0, 0)
        pa = peer(t)
        ha = peer(max(0.0, t - 0.45))           # the head follows the pilot's lead, late and in one jerk
        p.world["head"] = R(0, 0, round(ha / 10.0) * 10.0 * 0.5)
        p.rot("pilot", 3.0 * math.sin(TAU * t / 2.0), 0, pa)
        p.rot("lever", 10.0 * math.sin(TAU * t / 1.5) * (abs(pa) > 5.0), 0, -pa * 0.4)
        p.rot("lid", 2.0 * math.sin(TAU * t / 3.0), 0, 0)
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, 0.5 * math.sin(TAU * t / 3.0), 0, -sg * 1.0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
