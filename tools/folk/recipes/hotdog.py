## FOINT CITY townsfolk: hotdog. The FOINT DOGS mascot: a foam hot dog in a bun, the sausage poking out top and bottom with a mustard squiggle down it, the wearer's sweaty grinning face in a hole in the sausage, the brand lettered on both sides of the bun, red tights, white cartoon gloves and big white sneakers; a mascot waddle.
# Upgrade of the three.js game's hotdog (folk-species-c.js; old render refs/old/hotdog.png): same idea (a tall bun, the sausage down the front
# with mustard, a face in the sausage, bun-coloured arms with white gloves, red legs, white shoes), lifted to the new sheets (refs 4/6/7):
# a split bun with soft crumb inside, grill marks, foam that is a bit grubby, the FOINT DOGS brand.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 1.90
REF = ("old/hotdog.png", None)

BUN, CRUMB, SAUSAGE, MUSTARD, FOAM, SKIN, EYE, MOUTH, TOOTH, HAIR, SLEEVE, GLOVE, TIGHTS, SHOE, SOLE, LACE, BROW = range(1, 18)
COLOURS = {
    BUN: ((0.66, 0.36, 0.12), 0.7, 0.0),
    CRUMB: ((0.9, 0.82, 0.62), 0.9, 0.0),
    SAUSAGE: ((0.55, 0.15, 0.08), 0.35, 0.0),
    MUSTARD: ((0.92, 0.7, 0.05), 0.3, 0.0),
    FOAM: ((0.85, 0.8, 0.65), 0.9, 0.0),
    SKIN: ((0.8, 0.55, 0.42), 0.5, 0.0),
    EYE: ((0.9, 0.9, 0.86), 0.15, 0.0),
    MOUTH: ((0.2, 0.04, 0.05), 0.6, 0.0),
    TOOTH: ((0.92, 0.9, 0.82), 0.3, 0.0),
    HAIR: ((0.2, 0.1, 0.05), 0.8, 0.0),
    SLEEVE: ((0.7, 0.42, 0.16), 0.8, 0.0),
    GLOVE: ((0.92, 0.92, 0.9), 0.6, 0.0),
    TIGHTS: ((0.62, 0.08, 0.06), 0.7, 0.0),
    SHOE: ((0.92, 0.92, 0.9), 0.5, 0.0),
    SOLE: ((0.75, 0.15, 0.1), 0.7, 0.0),
    LACE: ((0.75, 0.12, 0.1), 0.8, 0.0),
    BROW: ((0.2, 0.1, 0.05), 0.8, 0.0),
}
UP = v3((0, 0, 1))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# landmarks, left side (+X); the figure faces -Y
HIP = v3((0.105, 0.025, 0.78))
KNEE = v3((0.115, 0.0, 0.445))
ANKLE = v3((0.12, 0.03, 0.095))
BALL = v3((0.125, -0.09, 0.0))
SHOULDER = v3((0.25, 0.03, 1.33))
ELBOW = v3((0.39, 0.035, 1.125))
WRIST = v3((0.43, -0.01, 0.925))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
BUN_C = v3((0.0, 0.045, 1.2))
BUN_R = (0.305, 0.24, 0.53)
SAUS_A, SAUS_B = v3((0.0, -0.085, 0.80)), v3((0.0, -0.085, 1.735))       # the sausage's axis, bottom to top
SAUS_R = 0.158
FACE_C = v3((0.0, -0.15, 1.47))                                          # the wearer's face, behind the hole
HOLE_C = v3((0.0, -0.22, 1.475))
GROOVE = Ellipsoid((0.0, -0.17, 1.2), (0.17, 0.2, 0.62))
HOLE = Ellipsoid(HOLE_C + v3((0, 0.02, 0)), (0.088, 0.12, 0.104))


def costume():
    """the foam bun split down the front, the sausage lying in the split, the face hole, the mustard"""
    bun = Ellipsoid(BUN_C, BUN_R, part=BUN)
    bun = Union([bun, Ellipsoid(BUN_C + v3((0, 0.02, -0.33)), (0.29, 0.23, 0.2), part=BUN)], k=0.06, part=BUN)
    # the split: a groove down the front (its walls painted as soft crumb)
    bun = Cut(bun, [GROOVE], k=0.04)
    saus = RoundCone(SAUS_A, SAUS_B, SAUS_R, SAUS_R * 0.97, part=SAUSAGE)
    saus = Union([saus, Sphere(SAUS_B + v3((0, 0.0, 0.0)), SAUS_R * 0.985, part=SAUSAGE)], k=0.02)
    # the face hole: an oval cut through the foam (its walls painted as raw foam), its edge rolled
    rim = Clip(Torus(HOLE_C + v3((0, -0.005, 0)), 0.093, 0.012, Rm=basis(v3((0, -1, 0)), v3((0, 0, 1))), part=SAUSAGE), [Inflate(saus, 0.01)], k=0.004)
    saus = Union([Cut(saus, [HOLE], k=0.012), rim], k=0.01)
    # the mustard: a squiggle zig-zagging down the sausage's front, from the hole's chin to near the bottom, and a swirl on top
    pts = []
    for i in range(61):
        t = i / 60.0
        z = 1.34 - t * 0.48
        x = 0.082 * np.sin(t * np.pi * 9.0 + 0.5) * (1.0 - 0.2 * t)
        r = np.sqrt(max(SAUS_R ** 2 - x ** 2, 0.0))
        pts.append((v3((x, SAUS_A[1] - r + 0.006, z)), 0.0145 + 0.003 * np.sin(t * 23.0)))
    must = loft(pts, part=MUSTARD, k=0.01)
    top = []
    for i in range(8):
        a = i * 1.0
        z = 1.69 + 0.06 * np.sin(i * 0.9)
        rr = 0.118 - 0.006 * i
        top.append((v3((rr * np.sin(a), SAUS_A[1] - rr * np.cos(a) * 0.9, 1.80 - 0.01 * i)), 0.016))
    must2 = loft(top[:6], part=MUSTARD, k=0.012)
    return Union([bun, saus, must, must2], k=0.0)


def face():
    """the wearer: a round sweaty face filling the hole, big eyes, a wide forced grin, dark hair at the top edge"""
    fc = FACE_C
    head = Union([Ellipsoid(fc, (0.088, 0.07, 0.105)), Mirror(Ellipsoid(fc + v3((0.042, -0.04, -0.03)), (0.04, 0.035, 0.035)))], k=0.02, part=SKIN)
    nose = Union([Sphere(fc + v3((0, -0.078, -0.005)), 0.017), Mirror(Sphere(fc + v3((0.012, -0.07, -0.014)), 0.011))], k=0.008, part=SKIN)
    ec = fc + v3((0.034, -0.052, 0.025))
    eye = Sphere(ec, 0.018, part=EYE)
    lid = Clip(Sphere(ec, 0.0215, part=SKIN), [Half(ec + v3((0, 0, 0.011)), (0, -0.2, -1))], k=0.002)
    brows = Mirror(loft([(fc + v3((0.016, -0.066, 0.052)), 0.005), (fc + v3((0.034, -0.068, 0.06)), 0.0055), (fc + v3((0.054, -0.058, 0.055)), 0.004)], part=BROW, k=0.003))
    lo = Ellipsoid(fc + v3((0, -0.066, -0.048)), (0.046, 0.04, 0.024))
    hi = Ellipsoid(fc + v3((0, -0.08, -0.026)), (0.06, 0.05, 0.022))
    cav = Cut(lo, [hi], k=0.004)
    f = Union([Union([head, Mirror(lid)], k=0.006), nose], k=0.006)
    f = Cut(f, [cav], k=0.003)
    throat = Ellipsoid(fc + v3((0, -0.04, -0.048)), (0.04, 0.02, 0.02), part=MOUTH)
    teeth = Box(fc + v3((0, -0.058, -0.033)), (0.035, 0.008, 0.006), rr=0.004, part=TOOTH)
    hair = Clip(Inflate(Ellipsoid(fc, (0.088, 0.07, 0.105)), 0.006, part=HAIR), [Half(fc + v3((0, 0, 0.07)), (0, 0.4, -1))], k=0.004)
    drop = Union([Sphere(fc + v3((-0.066, -0.05, 0.05)), 0.007), RoundCone(fc + v3((-0.066, -0.05, 0.05)), fc + v3((-0.066, -0.048, 0.062)), 0.007, 0.001)], k=0.003, part=EYE)
    return Union([f, Mirror(eye), brows, throat, teeth, hair, drop], k=0.0)


def front_y(shape, x, z, y0=-0.6, y1=0.3):
    ys = np.linspace(y0, y1, 1801).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    return float(ys[int(np.argmax(shape.eval(P)[0] < 0))])


def glove(s=1.0):
    """a white cartoon glove in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y): three fat fingers, a thumb, a rolled cuff"""
    palm = Ellipsoid((0.0, 0.0, -0.05), (0.03, 0.05, 0.055), part=GLOVE)
    cuff = Union([CappedCone((0, 0, 0.055), (0, 0, -0.005), 0.056, 0.042, rr=0.012), Torus((0, 0, 0.05), 0.05, 0.012)], k=0.008, part=GLOVE)
    parts = [palm]
    for f, L in ((-0.03, 0.9), (0.0, 1.0), (0.03, 0.88)):
        pts = [((0.0, f, -0.088), 0.02), ((-0.008, f * 1.05, -0.088 - 0.035 * L), 0.019), ((-0.025, f * 1.08, -0.088 - 0.06 * L), 0.018)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=GLOVE, k=0.006))
    parts.append(loft([(v3((-0.015, -0.04, -0.03)), 0.021), (v3((-0.035, -0.06, -0.06)), 0.019), (v3((-0.045, -0.062, -0.082)), 0.017)], part=GLOVE, k=0.006))
    seams = Union([RoundCone(v3((0.03, f, -0.02)), v3((0.032, f, -0.06)), 0.004, 0.004, part=GLOVE) for f in (-0.016, 0.0, 0.016)])
    return Union([Union(parts, k=0.014), cuff, seams], k=0.004)


def arm():
    sl = loft([(SHOULDER, 0.066), (ELBOW, 0.06), (WRIST + (ELBOW - WRIST) * 0.12, 0.054)], part=SLEEVE, k=0.015)
    return Union([sl, place(glove(), WRIST, HAND)], k=0.0)


def leg():
    l = loft([(HIP, 0.07), (KNEE, 0.058), (ANKLE + v3((0, 0, 0.04)), 0.045)], part=TIGHTS, k=0.02)
    knee = Ellipsoid(KNEE + v3((0, -0.012, 0.0)), (0.056, 0.05, 0.06), part=TIGHTS)
    x = ANKLE[0]
    foot = Union([
        Box((x, -0.05, 0.058), (0.064, 0.13, 0.05), rr=0.046),
        Ellipsoid((x + 0.004, -0.14, 0.056), (0.068, 0.07, 0.054)),
    ], k=0.03, part=SHOE)
    collar = Union([CappedCone((x, 0.012, 0.05), (x, 0.006, 0.15), 0.064, 0.058, rr=0.014), Torus((x, 0.006, 0.146), 0.055, 0.013)], k=0.012, part=SHOE)
    upper = Clip(Union([foot, collar], k=0.03, part=SHOE), [Half((0, 0, 0.034), (0, 0, -1))], k=0.003)
    tongue = Box((x, -0.07, 0.138), (0.03, 0.012, 0.04), rr=0.011, R=rot(rx=-22), part=SHOE)
    sole = Clip(Inflate(foot, 0.009, part=SOLE), [Half((0, 0, 0.04), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)
    toe = Clip(Inflate(Ellipsoid((x + 0.004, -0.14, 0.056), (0.068, 0.07, 0.054)), 0.005, part=SOLE), [Half((0, -0.14, 0), (0, 1, -0.2))], k=0.003)
    laces = [Box((x, yy, zz), (0.032, 0.006, 0.0055), rr=0.005, R=rot(rx=-30), part=LACE) for yy, zz in ((-0.076, 0.124), (-0.094, 0.106), (-0.112, 0.088))]
    return Union([Union([l, knee], k=0.02), Union([upper, tongue], k=0.008), sole, toe] + laces, k=0.0)


def pieces():
    body = Union([Mirror(arm()), Mirror(leg())], k=0.0)
    return [("costume", costume(), 0.003), ("face", face(), 0.0015), ("body", body, 0.003)]


# ---------------------------------------------------------------------------------------------------- lettering: a little stroke font

GLYPHS = {
    "A": [[(0, 0), (0.3, 1), (0.6, 0)], [(0.12, 0.38), (0.48, 0.38)]],
    "D": [[(0, 0), (0, 1), (0.32, 1), (0.52, 0.85), (0.6, 0.5), (0.52, 0.15), (0.32, 0), (0, 0)]],
    "E": [[(0.56, 1), (0, 1), (0, 0), (0.56, 0)], [(0, 0.5), (0.42, 0.5)]],
    "F": [[(0.56, 1), (0, 1), (0, 0)], [(0, 0.5), (0.42, 0.5)]],
    "G": [[(0.58, 0.8), (0.46, 0.96), (0.3, 1.0), (0.13, 0.93), (0.03, 0.72), (0.0, 0.5), (0.03, 0.28), (0.13, 0.07), (0.3, 0.0), (0.47, 0.04), (0.6, 0.17), (0.6, 0.44), (0.36, 0.44)]],
    "H": [[(0, 0), (0, 1)], [(0.6, 0), (0.6, 1)], [(0, 0.5), (0.6, 0.5)]],
    "I": [[(0.3, 0), (0.3, 1)], [(0.12, 1), (0.48, 1)], [(0.12, 0), (0.48, 0)]],
    "N": [[(0, 0), (0, 1), (0.6, 0), (0.6, 1)]],
    "O": [[(0.3 + 0.3 * np.sin(a), 0.5 + 0.5 * np.cos(a)) for a in np.linspace(0, 2 * np.pi, 21)]],
    "R": [[(0, 0), (0, 1), (0.4, 1), (0.56, 0.92), (0.6, 0.75), (0.56, 0.58), (0.4, 0.5), (0, 0.5)], [(0.3, 0.5), (0.6, 0)]],
    "S": [[(0.58, 0.84), (0.45, 0.98), (0.28, 1.0), (0.1, 0.94), (0.02, 0.78), (0.07, 0.62), (0.26, 0.53), (0.46, 0.45), (0.58, 0.3), (0.56, 0.12), (0.42, 0.01), (0.22, 0.0), (0.06, 0.07), (0.0, 0.16)]],
    "T": [[(0, 1), (0.6, 1)], [(0.3, 1), (0.3, 0)]],
    "!": [[(0.3, 0.3), (0.3, 1)], [(0.3, 0.02), (0.3, 0.06)]],
}


def text_dist(u, v, text, h, advance=0.82, space=0.5):
    """distance (metres) from points (u, v) to the strokes of `text` set from (0, 0) along u, letters h tall, centred on u = 0"""
    segs = []
    x = 0.0
    for ch in text:
        if ch == " ":
            x += space
            continue
        for line in GLYPHS[ch]:
            for (a, b), (c_, d) in zip(line, line[1:]):
                segs.append((x + a, b, x + c_, d))
        x += advance
    w = x - (advance - 0.6)
    S = np.asarray(segs, np.float32) * h
    S[:, [0, 2]] -= w * h * 0.5
    best = np.full(len(u), 1e3, np.float32)
    for ax, ay, bx, by in S:
        ex, ey = bx - ax, by - ay
        L2 = max(ex * ex + ey * ey, 1e-9)
        t = np.clip(((u - ax) * ex + (v - ay) * ey) / L2, 0.0, 1.0)
        dx, dy = u - ax - t * ex, v - ay - t * ey
        best = np.minimum(best, np.sqrt(dx * dx + dy * dy))
    return best


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

    # the bun: golden crust, toasted darker over the crown and back, paler and floury toward the bottom and the split; foam grubby low down
    m = c.mask(BUN)
    rel = (P - BUN_C) / np.asarray(BUN_R, np.float32)
    bn = srgb(214, 140, 62) + (srgb(150, 78, 30) - srgb(214, 140, 62)) * (smooth(0.1, 0.9, rel[:, 2]) * 0.7 + smooth(0.0, 0.9, rel[:, 1]) * 0.3)[:, None]
    bn = bn + (srgb(232, 196, 136) - bn) * (smooth(-0.6, -0.95, rel[:, 2]) * 0.6 + smooth(-0.55, -0.85, rel[:, 1]) * 0.35)[:, None]
    bn *= (1.0 + 0.1 * mott)[:, None]
    grime = smooth(0.85, 0.7, z) * 0.4
    bn = bn + (srgb(110, 80, 50) - bn) * grime[:, None]
    put(m, bn, 0.72, bump=0.6)
    spk(m, (244, 222, 170), 0.22)
    # the brand, both flanks: FOINT over DOGS, red with a dark outline, set on the bun's side as seen from that side
    for s in (1.0, -1.0):
        side = m & (x * s > 0.1) & (np.abs(z - 1.44) < 0.14)
        if not side.any():
            continue
        u = (y - 0.06) * s                        # the reader's right: +Y seen from his left, -Y from his right
        for word, z0 in (("FOINT", 1.47), ("DOGS", 1.36)):
            d = text_dist(u[side], z[side] - z0, word, 0.085)
            fill = smooth(0.012, 0.007, d)
            c.col[side] = c.col[side] + (srgb(196, 28, 24) - c.col[side]) * fill[:, None]
            dd = np.full(len(P), 1e3, np.float32)
            dd[side] = np.abs(d - 0.0105)
            c.draw(side & (dd < 0.01), dd, 0.0016, 0.95)
    # the walls of the split: soft crumb, fading into the crust over the rounded lip (no hard edge)
    gd = np.abs(GROOVE.eval(P)[0])
    cr = c.mask(BUN) * smooth(0.016, 0.004, gd)
    m = cr > 0.5
    crumb = srgb(242, 222, 176) * (1.0 + 0.08 * mott)[:, None]
    c.col = c.col + (crumb - c.col) * cr[:, None]
    c.rough = c.rough + (0.92 - c.rough) * cr
    spk(m, (206, 170, 110), 0.5)
    # the sausage: glossy red-brown, darker grill marks across it, the cut ends a little lighter
    m = c.mask(SAUSAGE)
    sa = srgb(176, 62, 38) * (1.0 + 0.08 * mott)[:, None]
    sa = sa + (srgb(206, 96, 60) - sa) * (smooth(1.7, 1.86, z) * 0.4 + smooth(0.75, 0.62, z) * 0.4)[:, None]
    grill = smooth(0.012, 0.004, np.abs(((z + y * 0.5 + 0.03) % 0.16) - 0.08))
    sa = sa + (srgb(70, 20, 12) - sa) * (grill * 0.7 * (y < -0.1))[:, None]
    put(m, sa, 0.32, bump=0.3)
    spk(m, (120, 36, 20), 0.2)
    m = c.mask(SAUSAGE) & (np.abs(HOLE.eval(P)[0]) < 0.006)        # the walls of the face hole: raw foam
    put(m, srgb(222, 206, 160) * (1.0 + 0.15 * n2)[:, None], 0.95, bump=1.0)
    c.spk[m, 3] = 0.0
    m = c.mask(MUSTARD)
    put(m, srgb(246, 196, 30) * (1.0 + 0.25 * c.wear)[:, None], 0.22, bump=0.2)
    # the face: warm skin, flushed and sweaty (glossy), stubble, big brown eyes
    m = c.mask(SKIN)
    sk = srgb(232, 168, 132) * (1.0 + 0.05 * mott)[:, None]
    sk = sk + (srgb(226, 110, 100) - sk) * (smooth(0.04, 0.0, np.linalg.norm(Q - (FACE_C + v3((0.045, -0.05, -0.02))), axis=1)) * 0.6)[:, None]
    put(m, sk, 0.28, bump=0.15)
    spk(m & (z < FACE_C[2] - 0.04), (120, 90, 80), 0.35)
    m = c.mask(EYE)
    ey = np.broadcast_to(srgb(248, 246, 238), (len(P), 3)).copy()
    for s in (1.0, -1.0):
        ec = FACE_C + v3((s * 0.034, -0.052, 0.025))
        dv = P - ec
        r = np.linalg.norm(dv, axis=1)
        near = m & (r < 0.024)
        dd = dv / np.maximum(r, 1e-6)[:, None]
        ang = np.arccos(np.clip(dd @ unit((0, -1, 0.05)), -1, 1))
        ey[near] = np.where((ang < 0.62)[near, None], srgb(110, 66, 30), ey[near])
        c.draw(near, (ang - 0.33) * 0.018, 0.0)
        g = smooth(0.3, 0.18, np.arccos(np.clip(dd @ unit((0.3, -1, 0.6)), -1, 1)))
        ey[near] = ey[near] + (srgb(255, 255, 255) - ey[near]) * g[near, None]
        lm = c.mask(SKIN) & (r < 0.024) & (dv[:, 2] > 0.004)
        c.draw(lm, np.abs(r - 0.0195), 0.0011, 0.9)
    sweat = m & (np.linalg.norm(P - (FACE_C + v3((-0.066, -0.05, 0.053))), axis=1) < 0.015)
    ey[sweat] = srgb(200, 230, 246)
    put(m, ey, 0.05)
    c.spk[m, 3] = 0.0
    put(c.mask(MOUTH), srgb(70, 14, 20), 0.6)
    put(c.mask(TOOTH), srgb(244, 240, 226), 0.25)
    m = c.mask(HAIR, BROW)
    put(m, srgb(52, 30, 16) * (1.0 + 0.3 * noise3(P, 0.003))[:, None], 0.75, bump=1.0)
    # sleeves: bun-brown fleece; gloves white, smudged grey; tights red, bobbled; sneakers white with red soles and laces
    m = c.mask(SLEEVE)
    put(m, srgb(196, 126, 56) * (1.0 + 0.08 * mott)[:, None], 0.9, bump=1.0)
    m = c.mask(GLOVE)
    put(m, srgb(244, 242, 236) * (1.0 - 0.18 * smooth(0.3, 0.8, n1) - 0.2 * c.cavity)[:, None], 0.65, bump=0.6)
    m = c.mask(TIGHTS)
    put(m, srgb(186, 34, 30) * (1.0 + 0.06 * mott)[:, None], 0.75, bump=0.8)
    spk(m, (140, 20, 18), 0.25)
    m = c.mask(SHOE)
    put(m, srgb(244, 242, 236) * (1.0 - 0.2 * smooth(0.3, 0.9, n2) - 0.15 * smooth(0.08, 0.03, z))[:, None], 0.55, bump=0.6, grain=1.0)
    m = c.mask(SOLE)
    put(m, srgb(204, 40, 32) * (1.0 - 0.25 * smooth(0.02, 0.0, z))[:, None], 0.65, bump=0.3)
    put(c.mask(LACE), srgb(210, 36, 30), 0.8, bump=0.4)
    c.col *= (0.32 + 0.68 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model

GAME = {
    "budget": {"costume": 4800, "face": 1200, "body": 3200},
    "density": {"face": 2.4},
    "tex": 2048,
    "stride": {"walk": 0.9, "run": 1.5},
    "speed": 0.75,
    "look": ["chest"], "neck": "spine",
    "look_pivot": (0.0, 0.0, 1.0),
    "radius": 0.42,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.02, 0.78), (0, 0.02, 0.95), "root", 0.1),
        Bone("spine", (0, 0.02, 0.95), (0, 0.02, 1.15), "hips", 0.1),
        Bone("chest", (0, 0.02, 1.15), (0, 0.02, 1.5), "spine", 0.1),
        Bone("shoulder.L", (0.06, 0.03, 1.33), SHOULDER, "chest", 0.06),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.065),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.06),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.13, "forearm.L", 0.04),
        Bone("thigh.L", HIP, KNEE, "hips", 0.07),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.06),
        Bone("foot.L", ANKLE, (0.127, -0.18, 0.03), "shin.L", 0.05),
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
    # the costume and the face inside it: one stiff foam body on the chest, its bottom swinging a little with the hips
    cp = (piece == 0) | (piece == 1)
    allow(cp, "chest")
    rig[cp] = ix["chest"]                  # rigid: the bun and the sausage never shift against each other
    bp = piece == 2
    legs = bp & (z < 0.86) & (np.abs(x) < 0.25)
    allow(legs & (x > 0), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0), "thigh.R", "shin.R", "foot.R")
    allow(legs & (z > 0.72), "hips")
    arms = bp & ~legs
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (np.abs(x) < 0.31), "chest")
    return A, rig


def motions(rig):
    """walk: a mascot's waddle: wide planted steps, the whole bun rocking side to side over each foot and bouncing, gloved hands swinging
    out and waving a little; run: a bouncing jog, arms pumping out wide, the bun bobbing; idle: rocking on the heels, a big two-handed wave
    to the street, then a thumbs-up-ish point"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, run):
        g = dict(stride=1.5 if run else 0.9, stance=0.44 if run else 0.6, foot_x=0.16, lift=0.12 if run else 0.07, bob=0.035 if run else 0.02,
                 drop=0.05 if run else 0.03, sway=0.05, roll=0.0, yaw=6.0 if run else 4.0, counter=0.4, lean=6.0 if run else 0.0, toe_off=14.0,
                 toe_out=14.0, swing_point=6.0)
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        s = math.sin(TAU * u)
        c = math.cos(TAU * u)
        rk = (8.0 if run else 7.0) * s
        p.rot("hips", 0, rk * 0.5, 0)
        p.rot("spine", 0, rk * 0.3, 0)
        p.rot("chest", (2.0 if run else 1.5) * math.sin(2 * TAU * u - 1.0), rk * 0.2, 0)
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, sg * (18.0 if run else 12.0) * c, -sg * ((16.0 if run else 7.0) + 5.0 * max(0.0, -sg * c)), 0)       # (ry lifts an arm out, clear of the bun)
            p.rot("forearm." + side, -(60.0 if run else 22.0) - 14.0 * max(0.0, sg * c), 0, 0)
            p.rot("hand." + side, 0, 0, sg * 10.0 * math.sin(2 * TAU * u))
        return p
    walk = [walkish(i / 32.0, False) for i in range(33)]
    run = [walkish(i / 24.0, True) for i in range(25)]
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        rock = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.15, -0.1, 0.0)), 14.0), "R": (Vector((-0.15, -0.1, 0.0)), -14.0)},
              hip_shift=(0.01 * rock, 0.0, -0.012 + 0.008 * abs(rock)), roll=-2.0 * rock)
        p.rot("spine", 1.5 * math.sin(TAU * t / 1.5), 0, 0)
        wave = ease((t - 1.0) / 0.4) * (1.0 - ease((t - 3.4) / 0.5))
        point = ease((t - 4.0) / 0.3) * (1.0 - ease((t - 5.3) / 0.4))
        w = math.sin(TAU * 2.2 * t)
        # both arms up and waving side to side over the head
        p.rot("upper_arm.L", -20.0 * wave - 45.0 * point, -78.0 * wave - 6.0 * point, 0)
        p.rot("forearm.L", -30.0 * wave - 20.0 * point, -25.0 * w * wave, 0)
        p.rot("upper_arm.R", -20.0 * wave, 78.0 * wave, 0)
        p.rot("forearm.R", -30.0 * wave, 25.0 * w * wave, 0)
        p.rot("chest", 0, 3.0 * w * wave, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
