## FOINT CITY townsfolk: sandwich. A weary street prophet in a sandwich board that reads THE END IS NEAR: grey knit beanie, bushy grey brows and beard, a big red nose, a baggy darned sweater, two hand-lettered plywood boards hung front and back from straps over his shoulders, corduroys and cracked boots; he trudges.
# Upgrade of the three.js game's sandwich (folk-species-c.js; old render refs/old/sandwich.png): same idea (grey beanie, stubbly grey beard, a
# grey knit, cream boards front and back with black lettering and a red exclamation mark, straps over the shoulders, dark trousers, brown
# shoes), lifted to the new sheets (refs 4/6/7): a real face under the beanie, the message actually lettered, plywood worn at the edges.
# The board is part of the costume.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 1.75
REF = ("old/sandwich.png", None)

SKIN, EYE, LIP, BEARD, BEANIE, KNIT, TROUSERS, BOOT, SOLE, BOARD, STRAP, BRASS, NAIL, MOUTH = range(1, 15)
COLOURS = {
    SKIN: ((0.72, 0.48, 0.38), 0.55, 0.0),
    EYE: ((0.85, 0.83, 0.78), 0.2, 0.0),
    LIP: ((0.55, 0.3, 0.28), 0.4, 0.0),
    BEARD: ((0.55, 0.54, 0.52), 0.85, 0.0),
    BEANIE: ((0.35, 0.36, 0.38), 0.9, 0.0),
    KNIT: ((0.25, 0.26, 0.27), 0.9, 0.0),
    TROUSERS: ((0.3, 0.2, 0.12), 0.85, 0.0),
    BOOT: ((0.2, 0.12, 0.07), 0.5, 0.0),
    SOLE: ((0.08, 0.06, 0.05), 0.7, 0.0),
    BOARD: ((0.85, 0.8, 0.62), 0.75, 0.0),
    STRAP: ((0.3, 0.18, 0.1), 0.6, 0.0),
    BRASS: ((0.7, 0.55, 0.25), 0.35, 1.0),
    NAIL: ((0.6, 0.45, 0.38), 0.4, 0.0),
    MOUTH: ((0.15, 0.05, 0.05), 0.6, 0.0),
}
UP = v3((0, 0, 1))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# landmarks, left side (+X); the figure faces -Y; a stoop: the chest and head carried forward
HIP = v3((0.1, 0.02, 0.86))
KNEE = v3((0.11, -0.012, 0.475))
ANKLE = v3((0.115, 0.03, 0.095))
HEM = v3((0.115, 0.025, 0.125))
BALL = v3((0.118, -0.09, 0.0))
SHOULDER = v3((0.215, 0.025, 1.335))
ELBOW = v3((0.295, 0.05, 1.07))
WRIST = v3((0.31, 0.015, 0.83))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
NECK_A, NECK_B = v3((0, 0.035, 1.37)), v3((0, -0.005, 1.48))
HEAD_C = v3((0.0, -0.035, 1.585))
EYE_C = v3((0.04, -0.118, 1.6))
EYE_R = 0.019
LOOK = unit((0.0, -1.0, -0.35))
BOARD_W, BOARD_T = 0.27, 0.011                     # half width, half thickness
BOARD_F = (v3((0.0, -0.19, 1.0)), -5.0)            # (centre, lean in degrees about X: each board's top tipped in against him)
BOARD_B = (v3((0.0, 0.205, 1.0)), 5.0)
BOARD_H = 0.39                                     # half height


def head():
    skull = Union([
        Ellipsoid(HEAD_C, (0.1, 0.11, 0.125)),
        Ellipsoid(HEAD_C + v3((0, -0.03, -0.07)), (0.085, 0.085, 0.07)),
    ], k=0.04, part=SKIN)
    neck = RoundCone(NECK_A, NECK_B, 0.055, 0.05, part=SKIN)
    brow = Ellipsoid(HEAD_C + v3((0, -0.078, 0.03)), (0.08, 0.035, 0.02), part=SKIN)
    # tired eyes: heavy lids half shut, bags under them
    lid = Clip(Ellipsoid(EYE_C, (EYE_R + 0.005, EYE_R + 0.004, EYE_R + 0.005), part=SKIN), [Half(EYE_C + v3((0, 0, EYE_R * 0.3)), unit((0.1, -0.35, -1.0)))], k=0.003)
    bag = Clip(Ellipsoid(EYE_C + v3((0, -0.002, -0.006)), (EYE_R + 0.008, EYE_R + 0.004, EYE_R + 0.006), part=SKIN), [Half(EYE_C - v3((0, 0, EYE_R * 0.5)), (0, 0.1, 1))], k=0.004)
    ball = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    # a big bulbous nose; ears sticking out under the beanie
    nose = Union([RoundCone(HEAD_C + v3((0, -0.1, 0.0)), HEAD_C + v3((0, -0.128, -0.035)), 0.015, 0.024), Sphere(HEAD_C + v3((0, -0.13, -0.045)), 0.029),
                  Mirror(Sphere(HEAD_C + v3((0.022, -0.115, -0.052)), 0.016))], k=0.012, part=SKIN)
    ears = Mirror(Cut(Ellipsoid(HEAD_C + v3((0.1, 0.012, -0.005)), (0.026, 0.02, 0.042), R=rot(rz=-25), part=SKIN),
                      [Ellipsoid(HEAD_C + v3((0.112, 0.004, -0.005)), (0.014, 0.012, 0.03), R=rot(rz=-25))], k=0.004))
    face = Union([Union([skull, neck, brow, ears], k=0.025), Mirror(lid), Mirror(bag)], k=0.008)
    face = Union([face, nose], k=0.01)
    # the beard: a scruffy grey mass over the jaw and chin, a drooping moustache, a slot of a mouth just visible
    beard = Union([
        Clip(Inflate(Ellipsoid(HEAD_C + v3((0, -0.03, -0.07)), (0.085, 0.085, 0.07)), 0.016), [Half(HEAD_C + v3((0, 0, -0.04)), (0, -0.4, 1))], k=0.01),
        Ellipsoid(HEAD_C + v3((0, -0.072, -0.13)), (0.06, 0.05, 0.055)),
        Mirror(Ellipsoid(HEAD_C + v3((0.06, -0.04, -0.06)), (0.035, 0.045, 0.06))),
    ], k=0.03, part=BEARD)
    beard = Bump(beard, lambda P: noise3(P, 0.009), 0.004)
    mous = Mirror(loft([(HEAD_C + v3((0.0, -0.118, -0.066)), 0.014), (HEAD_C + v3((0.03, -0.11, -0.074)), 0.014), (HEAD_C + v3((0.05, -0.095, -0.095)), 0.008)], part=BEARD, k=0.008))
    slot = Ellipsoid(HEAD_C + v3((0, -0.108, -0.088)), (0.026, 0.02, 0.005))
    hair = Union([beard, mous], k=0.01)
    hair = Cut(hair, [slot], k=0.002)
    mouth = Ellipsoid(HEAD_C + v3((0, -0.095, -0.088)), (0.024, 0.012, 0.006), part=MOUTH)
    brows = Mirror(Union([Ellipsoid(EYE_C + v3((0.004, -0.008, 0.026)), (0.028, 0.014, 0.01), R=rot(ry=10)), Ellipsoid(EYE_C + v3((0.026, -0.004, 0.022)), (0.014, 0.012, 0.009))], k=0.006, part=BEARD))
    brows = Bump(brows, lambda P: noise3(P, 0.004), 0.0025)
    # the beanie: grey knit over the crown, a thick turned-up cuff, a knob on top
    crown = Ellipsoid(HEAD_C + v3((0, 0.0, 0.0)), (0.1, 0.11, 0.125))
    cap = Clip(Inflate(crown, 0.014, part=BEANIE), [Half(HEAD_C + v3((0, 0, 0.035)), (0, -0.25, -1))], k=0.004)
    cuff = Clip(Inflate(crown, 0.026, part=BEANIE), [Half(HEAD_C + v3((0, 0, 0.035)), (0, -0.25, -1)), Half(HEAD_C + v3((0, 0, 0.078)), (0, 0.25, 1))], k=0.008)
    peak = Ellipsoid(HEAD_C + v3((0, 0.01, 0.12)), (0.065, 0.07, 0.04), part=BEANIE)
    knob = Sphere(HEAD_C + v3((0.0, 0.014, 0.165)), 0.02, part=BEANIE)
    hat = Union([Union([cap, peak], k=0.03), cuff, knob], k=0.004)
    return Union([face, ball, hair, mouth, brows, hat], k=0.0)


def torso_core():
    return Union([
        Ellipsoid((0, 0.015, 1.21), (0.185, 0.125, 0.18)),
        Ellipsoid((0, 0.03, 1.345), (0.215, 0.105, 0.06)),
        Ellipsoid((0, 0.0, 1.03), (0.17, 0.125, 0.13)),
    ], k=0.07, part=KNIT)


def body():
    core = torso_core()
    sweater = Union([Inflate(core, 0.014, part=KNIT), Ellipsoid((0, 0.01, 0.94), (0.18, 0.14, 0.08), part=KNIT)], k=0.03)
    sweater = Clip(sweater, [Half((0, 0, 0.885), (0, 0, -1))], k=0.004)
    hem = Clip(Inflate(core, 0.02, part=KNIT), [Half((0, 0, 0.885), (0, 0, -1)), Half((0, 0, 0.93), (0, 0, 1))], k=0.005)
    collar = Union([Torus((0, 0.03, 1.375), 0.065, 0.02), Torus((0, 0.026, 1.395), 0.06, 0.016)], k=0.01, part=KNIT)
    d = unit(WRIST - ELBOW)
    sleeve = loft([(SHOULDER, 0.066), (ELBOW, 0.06), (WRIST + (ELBOW - WRIST) * 0.12, 0.055)], part=KNIT, k=0.014)
    sleeve = Clip(sleeve, [Half(WRIST + (ELBOW - WRIST) * 0.06, d)], k=0.004)
    cuff = Clip(RoundCone(WRIST + (ELBOW - WRIST) * 0.14, WRIST + d * 0.004, 0.056, 0.046, part=KNIT), [Half(WRIST + d * 0.005, d)], k=0.003)
    top = Union([sweater, Mirror(sleeve)], k=0.02, part=KNIT)
    top = Union([top, hem, collar, Mirror(cuff)], k=0.006)
    hips = Union([
        Ellipsoid((0, 0.02, 0.9), (0.19, 0.135, 0.1)),
        Mirror(loft([(HIP, 0.095), (KNEE, 0.084), (HEM, 0.08)])),
    ], k=0.05, part=TROUSERS)
    trousers = Clip(hips, [Half((0, 0, 0.115), (0.0, -0.2, -1.0))], k=0.003)
    return Union([core, top, trousers], k=0.0)


def boot():
    x = ANKLE[0]
    foot = Union([
        Box((x, -0.04, 0.056), (0.058, 0.12, 0.048), rr=0.042),
        Ellipsoid((x + 0.004, -0.125, 0.052), (0.06, 0.062, 0.05)),
    ], k=0.03, part=BOOT)
    shaft = Union([CappedCone((x, 0.01, 0.05), (x, 0.004, 0.16), 0.064, 0.06, rr=0.012), Torus((x, 0.004, 0.156), 0.056, 0.01)], k=0.01, part=BOOT)
    upper = Clip(Union([foot, shaft], k=0.025, part=BOOT), [Half((0, 0, 0.03), (0, 0, -1))], k=0.003)
    sole = Clip(Inflate(foot, 0.008, part=SOLE), [Half((0, 0, 0.032), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)
    laces = [Box((x, yy, zz), (0.03, 0.005, 0.005), rr=0.0045, R=rot(rx=-35), part=SOLE) for yy, zz in ((-0.062, 0.13), (-0.076, 0.11), (-0.09, 0.092))]
    return Union([upper, sole] + laces, k=0.0)


def hand(s=1.0):
    """a big knuckly relaxed hand in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y)"""
    palm = Ellipsoid((0.0, 0.0, -0.05), (0.02, 0.044, 0.05), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.034, 0.03, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.029, 0.85), (-0.01, 1.0), (0.01, 0.96), (0.029, 0.8)):
        pts = [((0.0, f, -0.09), 0.0115), ((-0.006, f, -0.09 - 0.03 * L), 0.0108), ((-0.02, f * 1.04, -0.09 - 0.056 * L), 0.0098), ((-0.034, f * 1.06, -0.09 - 0.068 * L), 0.009)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Sphere(v3((0.002, f, -0.09)), 0.0125, part=SKIN))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((0.004, 0, 0.003)), (0.0055, 0.007, 0.0065), part=NAIL))
    parts.append(loft([(v3((-0.01, -0.033, -0.03)), 0.0135), (v3((-0.027, -0.05, -0.06)), 0.012), (v3((-0.038, -0.052, -0.084)), 0.0105)], part=SKIN, k=0.004))
    return Union(parts, k=0.008)


def board_shape(c, lean):
    """a plywood board centred at c, its top tipped `lean` degrees (about X); a lip of a frame round its edge"""
    R = rot(rx=lean)
    panel = Box(c, (BOARD_W, BOARD_T, BOARD_H), rr=0.006, R=R, part=BOARD)
    chip = Box(c + R @ v3((BOARD_W - 0.01, 0, BOARD_H - 0.012)), (0.03, 0.03, 0.02), rr=0.004, R=R @ rot(ry=35))
    return Cut(panel, [chip], k=0.003)


def boards():
    """both boards, the straps over the shoulders joining their tops, a brass ring at each corner of each strap"""
    parts = []
    tops = []
    for (c, lean), s in ((BOARD_F, -1.0), (BOARD_B, 1.0)):
        parts.append(board_shape(c, lean))
        R = rot(rx=lean)
        for sx in (1.0, -1.0):
            p = c + R @ v3((sx * 0.155, -s * (BOARD_T + 0.004) * 0.0, BOARD_H - 0.03))
            tops.append(p)
            parts.append(Torus(p + R @ v3((0, s * (BOARD_T + 0.004), 0.0)), 0.012, 0.0035, Rm=basis(R @ v3((1, 0, 0)), R @ v3((0, 0, 1))), part=BRASS))
    # straps: front ring, up over the shoulder (following the sweater), down to the back ring
    core = Inflate(torso_core(), 0.03)
    for sx in (1.0, -1.0):
        x = sx * 0.155
        f = BOARD_F[0] + rot(rx=BOARD_F[1]) @ v3((x, -(BOARD_T + 0.004), BOARD_H - 0.03))
        b = BOARD_B[0] + rot(rx=BOARD_B[1]) @ v3((x, (BOARD_T + 0.004), BOARD_H - 0.03))
        pts = [(f, 0.008)]
        for t in np.linspace(0.15, 0.85, 7):
            y = f[1] + (b[1] - f[1]) * t
            zs = np.linspace(1.7, 1.2, 501).astype(np.float32)
            Pz = np.stack([np.full_like(zs, x), np.full_like(zs, y), zs], 1)
            hit = core.eval(Pz)[0] < 0
            if not hit.any():
                continue                      # off the shoulder: the strap runs straight on to the board
            zt = float(zs[int(np.argmax(hit))])
            pts.append((v3((x, y, zt + 0.006)), 0.008))
        pts.append((b, 0.008))
        strap = loft(pts, part=STRAP, k=0.02)
        parts.append(strap)
    return Union(parts, k=0.0)


def pieces():
    arm = Union([loft([(WRIST + (ELBOW - WRIST) * 0.1, 0.04), (WRIST, 0.034)], part=SKIN), place(hand(), WRIST, HAND)], k=0.01)
    b = Union([body(), Mirror(boot()), Mirror(arm)], k=0.0)
    return [("head", head(), 0.0018), ("body", b, 0.0035), ("boards", boards(), 0.0025)]


# ---------------------------------------------------------------------------------------------------- lettering: a little stroke font

GLYPHS = {
    "A": [[(0, 0), (0.3, 1), (0.6, 0)], [(0.12, 0.38), (0.48, 0.38)]],
    "D": [[(0, 0), (0, 1), (0.32, 1), (0.52, 0.85), (0.6, 0.5), (0.52, 0.15), (0.32, 0), (0, 0)]],
    "E": [[(0.56, 1), (0, 1), (0, 0), (0.56, 0)], [(0, 0.5), (0.42, 0.5)]],
    "H": [[(0, 0), (0, 1)], [(0.6, 0), (0.6, 1)], [(0, 0.5), (0.6, 0.5)]],
    "I": [[(0.3, 0), (0.3, 1)], [(0.12, 1), (0.48, 1)], [(0.12, 0), (0.48, 0)]],
    "N": [[(0, 0), (0, 1), (0.6, 0), (0.6, 1)]],
    "R": [[(0, 0), (0, 1), (0.4, 1), (0.56, 0.92), (0.6, 0.75), (0.56, 0.58), (0.4, 0.5), (0, 0.5)], [(0.3, 0.5), (0.6, 0)]],
    "S": [[(0.58, 0.84), (0.45, 0.98), (0.28, 1.0), (0.1, 0.94), (0.02, 0.78), (0.07, 0.62), (0.26, 0.53), (0.46, 0.45), (0.58, 0.3), (0.56, 0.12), (0.42, 0.01), (0.22, 0.0), (0.06, 0.07), (0.0, 0.16)]],
    "T": [[(0, 1), (0.6, 1)], [(0.3, 1), (0.3, 0)]],
}


def text_dist(u, v, text, h, advance=0.82, space=0.55, wobble=0.0):
    """distance (metres) from points (u, v) to the strokes of `text`, letters h tall, the line centred on u = 0 with its baseline at v = 0;
    wobble tips each letter a little, as a hand would"""
    segs = []
    x = 0.0
    for i, ch in enumerate(text):
        if ch == " ":
            x += space
            continue
        tilt = wobble * np.sin(i * 2.7 + 0.4)
        lift = wobble * 0.4 * np.sin(i * 1.9 + 1.1)
        for line in GLYPHS[ch]:
            q = [(x + a + tilt * (b - 0.5), b + lift) for a, b in line]
            for (a, b), (c_, d) in zip(q, q[1:]):
                segs.append((a, b, c_, d))
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

    # skin: weathered, ruddy at the nose and cheeks, liver spots, bags under the eyes
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(214, 156, 124), (len(P), 3)).copy()
    sk *= (1.0 + 0.1 * mott)[:, None]
    nose = smooth(0.05, 0.015, np.linalg.norm(P - (HEAD_C + v3((0, -0.128, -0.04))), axis=1))
    sk = sk + (srgb(206, 92, 84) - sk) * (nose * 0.8)[:, None]
    cheek = smooth(0.05, 0.0, np.linalg.norm(Q - (HEAD_C + v3((0.065, -0.08, -0.03))), axis=1))
    sk = sk + (srgb(206, 118, 100) - sk) * (cheek * 0.45)[:, None]
    bags = smooth(0.03, 0.01, np.linalg.norm(Q - (EYE_C + v3((0, -0.004, -0.022))), axis=1))
    sk = sk + (srgb(150, 104, 104) - sk) * (bags * 0.45)[:, None]
    put(m, sk, 0.55, bump=0.35)
    spk(m & (z > 1.45), (150, 96, 70), 0.3)
    # eyes: watery pale blue, half hidden under the lids, looking down at the pavement
    m = c.mask(EYE)
    ey = np.broadcast_to(srgb(236, 228, 214), (len(P), 3)).copy()
    for s in (1.0, -1.0):
        ec = EYE_C * np.array([s, 1, 1], np.float32)
        dv = P - ec
        r = np.linalg.norm(dv, axis=1)
        near = m & (r < EYE_R * 1.3)
        dd = dv / np.maximum(r, 1e-6)[:, None]
        ang = np.arccos(np.clip(dd @ LOOK, -1, 1))
        ey[near] = np.where((ang < 0.62)[near, None], srgb(120, 150, 170), ey[near])
        c.draw(near, (ang - 0.3) * EYE_R, 0.0)
        g = smooth(0.3, 0.18, np.arccos(np.clip(dd @ unit(LOOK + v3((0.3, 0, 0.8))), -1, 1)))
        ey[near] = ey[near] + (srgb(255, 255, 250) - ey[near]) * g[near, None]
        lm = c.mask(SKIN) & (r < EYE_R + 0.008) & (dv[:, 1] < 0.006)
        c.draw(lm & (dv[:, 2] > -0.006), np.abs(r - EYE_R - 0.0012), 0.0011, 0.9)
    put(m, ey, 0.1)
    c.spk[m, 3] = 0.0
    put(c.mask(MOUTH), srgb(60, 20, 20), 0.6)
    # beard and brows: grey streaked white and nicotine-yellow, wiry
    m = c.mask(BEARD)
    bd = srgb(150, 148, 144) + (srgb(226, 224, 216) - srgb(150, 148, 144)) * smooth(-0.2, 0.6, noise3(P * np.array([4, 4, 1], np.float32), 0.02))[:, None]
    bd = bd + (srgb(176, 150, 96) - bd) * (smooth(0.03, 0.0, np.linalg.norm(P - (HEAD_C + v3((0, -0.118, -0.07))), axis=1)) * 0.5)[:, None]
    put(m, bd, 0.85, bump=1.0)
    c.strp[m, 0] = ((x * 2.0 + z * 0.3) * 0.6)[m]
    c.strp[m, 1] = 0.7
    # the beanie: charcoal-grey rib knit
    m = c.mask(BEANIE)
    rel = P - HEAD_C
    put(m, srgb(96, 98, 104) * (1.0 + 0.1 * mott)[:, None], 0.95, bump=1.0)
    c.strp[m, 0] = (np.arctan2(rel[:, 0], -rel[:, 1]) * 0.13 * 0.4 * 2.0)[m]
    c.strp[m, 1] = 0.75
    # the sweater: dark grey knit, ribbed cuffs and hem, a darn on the chest and the elbows gone thin
    m = c.mask(KNIT)
    kn = srgb(70, 72, 76) * (1.0 + 0.1 * mott + 0.35 * c.wear)[:, None]
    elbow = smooth(0.06, 0.0, np.linalg.norm(Q - (ELBOW + v3((0.0, 0.05, 0.0))), axis=1))
    kn = kn + (srgb(110, 100, 90) - kn) * (elbow * 0.6)[:, None]
    put(m, kn, 0.95, bump=1.0)
    rib = m & ((z < 0.94) | (np.linalg.norm(Q - WRIST, axis=1) < 0.07) | (z > 1.36))
    c.strp[rib, 0] = (np.arctan2(x, -y) * 0.15 * 0.4)[rib]
    c.strp[rib, 1] = 0.7
    spk(m, (110, 104, 96), 0.15)
    # corduroys: brown, worn pale at the knees, frayed at the hems; boots: cracked dark leather
    m = c.mask(TROUSERS)
    tr = srgb(96, 66, 40) * (1.0 + 0.08 * mott + 0.4 * c.wear)[:, None]
    knee = smooth(0.07, 0.0, np.linalg.norm(Q - (KNEE + v3((0, -0.06, 0))), axis=1))
    tr = tr + (srgb(140, 110, 80) - tr) * (knee * 0.5 + smooth(0.16, 0.12, z) * 0.4)[:, None]
    put(m, tr, 0.9, bump=1.0)
    c.strp[m, 0] = (np.arctan2(Q[:, 0] - 0.11, -y) * 0.07 * 0.4 * 2.0)[m]
    c.strp[m, 1] = 0.5
    m = c.mask(BOOT)
    put(m, srgb(70, 44, 26) * (1.0 + 1.0 * c.wear + 0.1 * mott)[:, None], 0.55, bump=1.0, grain=1.0)
    put(c.mask(SOLE), srgb(30, 24, 20), 0.7, bump=0.3)
    put(c.mask(NAIL), srgb(196, 160, 130), 0.45)
    m = c.mask(STRAP)
    put(m, srgb(96, 60, 32) * (1.0 + 0.6 * c.wear)[:, None], 0.55, bump=0.8, grain=1.0)
    m = c.mask(BRASS)
    put(m, srgb(190, 150, 80) * (1.0 - 0.4 * c.cavity)[:, None], 0.35, metal=1.0, grain=1.0)
    # the boards: cream house paint over plywood, grimy toward the edges and the bottom, chipped through to the wood at the corners;
    # the message hand-lettered in black, a red exclamation mark; the same on the back board (as read from behind)
    m = c.mask(BOARD)
    bo = srgb(232, 220, 182) * (1.0 + 0.06 * mott)[:, None]
    for (cc, lean), s in ((BOARD_F, -1.0), (BOARD_B, 1.0)):
        R = rot(rx=lean)
        L = (P - cc) @ R                         # in the board's own frame: x across, y through, z up
        on = m & (np.abs(L[:, 1]) < BOARD_T + 0.004) & (np.abs(L[:, 0]) < BOARD_W + 0.004) & (np.abs(L[:, 2]) < BOARD_H + 0.004)
        edge = np.minimum(BOARD_W - np.abs(L[:, 0]), BOARD_H - np.abs(L[:, 2]))
        grime = smooth(0.06, 0.0, edge) * 0.5 + smooth(-0.15, -0.38, L[:, 2]) * 0.35
        bo[on] = bo[on] + (srgb(130, 112, 80) - bo[on]) * grime[on, None]
        wood = on & ((edge < 0.012) & (noise3(P, 0.02) > 0.1) | (np.abs(L[:, 1]) < BOARD_T - 0.002))
        bo[wood] = srgb(176, 130, 80) * (1.0 + 0.2 * noise3(P[wood] * np.array([1, 1, 6], np.float32), 0.01))[:, None]
        face = on & (L[:, 1] * s > BOARD_T - 0.003) & (edge > 0.01)
        u = L[:, 0] * (-s)                       # the reader's right: +X from the front, -X from behind
        v = L[:, 2]
        best = np.full(len(P), 1e3, np.float32)
        for word, v0 in (("THE END", 0.2), ("IS NEAR", 0.05)):
            d = text_dist(u[face], v[face] - v0, word, 0.095, wobble=0.06)
            best[face] = np.minimum(best[face], d)
        c.draw(face & (best < 0.03), best, 0.0075, 0.95)
        # the exclamation mark, big and red, with a drip
        ex = np.full(len(P), 1e3, np.float32)
        ex_d = np.minimum(np.hypot(u - 0.0, np.clip(v + 0.12, -0.0, 0.11) - (v + 0.12)) - 0.016 + 0.006 * (v + 0.12) / 0.11,
                          np.hypot(u, v + 0.19) - 0.017)
        ex[face] = ex_d[face]
        red = face & (ex < 0.002)
        bo[red] = srgb(196, 26, 22)
        drip = face & (np.abs(u - 0.008) < 0.003) & (v < -0.205) & (v > -0.26)
        bo[drip] = srgb(176, 30, 24)
    put(m, bo, 0.75, bump=0.4)
    spk(m, (150, 130, 96), 0.18)
    c.col *= (0.32 + 0.68 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model

GAME = {
    "budget": {"head": 2800, "body": 4400, "boards": 1200},
    "density": {"head": 1.7, "boards": 1.8},
    "tex": 2048,
    "stride": {"walk": 0.9, "run": 1.5},
    "speed": 0.6,
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.0, 1.45),
    "radius": 0.38,
}
BF_PIVOT = BOARD_F[0] + rot(rx=BOARD_F[1]) @ v3((0, 0, BOARD_H - 0.03))
BB_PIVOT = BOARD_B[0] + rot(rx=BOARD_B[1]) @ v3((0, 0, BOARD_H - 0.03))


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.02, 0.88), (0, 0.02, 1.0), "root", 0.14),
        Bone("spine", (0, 0.02, 1.0), (0, 0.015, 1.16), "hips", 0.14),
        Bone("chest", (0, 0.015, 1.16), (0, 0.03, 1.36), "spine", 0.15),
        Bone("neck", NECK_A, NECK_B, "chest", 0.05),
        Bone("head", NECK_B, HEAD_C + v3((0, 0, 0.15)), "neck", 0.12),
        Bone("board_f", BF_PIVOT, BOARD_F[0], "chest", 0.05),
        Bone("board_b", BB_PIVOT, BOARD_B[0], "chest", 0.05),
        Bone("shoulder.L", (0.05, 0.02, 1.34), SHOULDER, "chest", 0.06),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.065),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.058),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.13, "forearm.L", 0.035),
        Bone("thigh.L", HIP, KNEE, "hips", 0.095),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.085),
        Bone("foot.L", ANKLE, (0.12, -0.17, 0.03), "shin.L", 0.045),
    ])
    return bones


def skin_rules(P, part, piece, names):
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True

    def seg(a, b):
        ab = b - a
        t = np.clip(((Q - a) @ ab) / float(ab @ ab), 0.0, 1.0)
        return np.linalg.norm(Q - a - np.outer(t, ab), axis=1)
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 1.47)] = ix["head"]
    # the boards hang from their own bones; the straps ride the shoulders
    gp = piece == 2
    rig[gp & (part == BOARD) & (y < 0)] = ix["board_f"]
    rig[gp & (part == BOARD) & (y >= 0)] = ix["board_b"]
    rig[gp & (part == BRASS) & (y < 0)] = ix["board_f"]
    rig[gp & (part == BRASS) & (y >= 0)] = ix["board_b"]
    st = gp & (part == STRAP)
    allow(st, "chest")
    allow(st & (y < -0.13), "board_f")
    allow(st & (y > 0.15), "board_b")
    bp = piece == 1
    legs = bp & ((z < 0.87) | np.isin(part, (TROUSERS,)) & (z < 0.95) & (np.abs(x) > 0.0)) & ~((part == KNIT))
    allow(legs & (z > 0.75), "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    arm_d = np.minimum(np.minimum(seg(SHOULDER, ELBOW) - 0.066, seg(ELBOW, WRIST) - 0.06), seg(WRIST, WRIST - HAND[:, 2] * 0.15) - 0.05)
    body_d = torso_core().eval(P)[0] - 0.014
    arms = bp & ~legs & (Q[:, 0] > 0.15) & (arm_d < body_d)
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "upper_arm.R", "forearm.R", "hand.R")
    root = arms & (arm_d > body_d - 0.03)
    allow(root, "chest")
    allow(root & (x > 0), "shoulder.L")
    allow(root & (x <= 0), "shoulder.R")
    torso = bp & ~legs & ~arms
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.1) & (z > 1.2), "shoulder.L", "upper_arm.L")
    allow(torso & (x < -0.1) & (z > 1.2), "shoulder.R", "upper_arm.R")
    return A, rig


WALK = dict(stride=0.9, stance=0.64, foot_x=0.11, lift=0.035, bob=0.012, drop=0.04, sway=0.03, roll=5.0, yaw=4.0, counter=0.8,
            lean=6.0, toe_off=8.0, toe_out=8.0, swing_point=2.0, spine_lean=3.0)
RUN = dict(stride=1.5, stance=0.45, foot_x=0.11, lift=0.1, bob=0.03, drop=0.07, sway=0.03, roll=4.0, yaw=7.0, counter=1.1,
           lean=14.0, toe_off=20.0, toe_out=6.0, swing_point=12.0, spine_lean=5.0)


def motions(rig):
    """walk: a trudge: bent forward under the boards, short dragging steps, the head hung, arms dead at the sides, the boards knocking
    out and back as his knees bump the front one; run: a hunched shamble at a pace, the boards flapping; idle: standing slumped, a long
    sigh that lifts and drops the shoulders, a slow look up at the sky, then back down"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        c = math.cos(TAU * u)
        s = math.sin(TAU * u)
        a = 28.0 if run else 7.0
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, sg * a * c, 0, 0)
            p.rot("forearm." + side, -(40.0 if run else 4.0) - 4.0 * max(0.0, sg * c), 0, 0)
        p.rot("neck", 10.0 if not run else 4.0, 0, 0)
        p.world["head"] = R((16.0 if not run else 8.0) + 2.0 * math.sin(2 * TAU * u - 0.8), 0, 2.0 * s)
        knee = abs(math.sin(TAU * u + 0.4))
        # the boards hang from the shoulders and keep near plumb whatever his stoop (world rotations), knocked out by the knees, lagging when running
        p.world["board_f"] = R(-(4.0 if not run else 10.0) * knee - (3.0 if not run else 10.0), 2.0 * s, 0)
        p.world["board_b"] = R((2.0 if not run else 8.0) * abs(math.sin(TAU * u + 1.6)) + (1.0 if not run else 4.0), -2.0 * s, 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sigh = math.exp(-((t - 1.6) / 0.5) ** 2)
        up = ease((t - 3.2) / 0.8) * (1.0 - ease((t - 4.8) / 0.8))
        stand(rig, p, legs, {"L": (Vector((0.12, -0.08, 0.0)), 8.0), "R": (Vector((-0.12, -0.05, 0.0)), -8.0)},
              hip_shift=(0.01 * math.sin(TAU * t / 6.0), 0.0, -0.02), roll=-1.5 * math.sin(TAU * t / 6.0))
        p.rot("spine", 4.0 - 3.0 * sigh, 0, 0)
        p.rot("chest", 3.0 - 4.0 * sigh + 1.0 * math.sin(TAU * t / 4.0), 0, 0)
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("shoulder." + side, 0, -sg * 7.0 * sigh, 0)            # a shrug: ry lifts the shoulder
            p.rot("upper_arm." + side, 1.0 * math.sin(TAU * t / 4.0), 0, 0)
            p.rot("forearm." + side, -4.0, 0, 0)
        p.rot("neck", 12.0 - 10.0 * up, 0, 0)
        p.world["head"] = R(18.0 - 34.0 * up, 0, 6.0 * up)
        p.world["board_f"] = R(-2.0 - 1.0 * math.sin(TAU * t / 3.0), 0, 0)
        p.world["board_b"] = R(1.0 * math.sin(TAU * t / 3.0), 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
