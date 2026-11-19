## FOINT CITY townsfolk: cyclops. One big eye under a heavy brow, a broad green head with fat cheeks and a lopsided smirk with two little tusks, a red tracksuit with white stripes zipped over a white tee, a chunky gold chain and medallion, white high-tops; he swaggers.
# Upgrade of the three.js game's cyclops (folk-species-d.js; old render refs/old/cyclops.png): same idea (green, one big blue eye, heavy brow, fat
# cheeks, wide mouth with two teeth, small ears, a bump of hair, red tracksuit with the white stripe, white collar, gold chain and medallion,
# white shoes), lifted to the new sheets (refs 4/6/7): a half-lidded too-cool eye, a smirk, chunky gold, a slouchy worn tracksuit.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 1.70
REF = ("old/cyclops.png", None)

SKIN, EYE, LIP, MOUTH, TOOTH, HAIR, TRACK, STRIPE, TEE, GOLD, SHOE, SOLE, LACE, NAIL, ZIP = range(1, 16)
COLOURS = {
    SKIN: ((0.28, 0.5, 0.2), 0.5, 0.0),
    EYE: ((0.9, 0.9, 0.86), 0.15, 0.0),
    LIP: ((0.2, 0.33, 0.14), 0.4, 0.0),
    MOUTH: ((0.1, 0.04, 0.04), 0.6, 0.0),
    TOOTH: ((0.92, 0.88, 0.76), 0.3, 0.0),
    HAIR: ((0.08, 0.14, 0.06), 0.8, 0.0),
    TRACK: ((0.6, 0.05, 0.05), 0.6, 0.0),
    STRIPE: ((0.9, 0.9, 0.88), 0.6, 0.0),
    TEE: ((0.9, 0.9, 0.88), 0.8, 0.0),
    GOLD: ((0.95, 0.7, 0.25), 0.25, 1.0),
    SHOE: ((0.92, 0.92, 0.9), 0.5, 0.0),
    SOLE: ((0.85, 0.85, 0.82), 0.7, 0.0),
    LACE: ((0.9, 0.9, 0.88), 0.8, 0.0),
    NAIL: ((0.2, 0.36, 0.14), 0.3, 0.0),
    ZIP: ((0.8, 0.8, 0.8), 0.3, 1.0),
}
UP = v3((0, 0, 1))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# landmarks, left side (+X); the figure faces -Y
HIP = v3((0.11, 0.012, 0.82))
KNEE = v3((0.12, -0.012, 0.455))
ANKLE = v3((0.125, 0.03, 0.095))
BALL = v3((0.128, -0.09, 0.0))
SHOULDER = v3((0.27, 0.008, 1.235))
ELBOW = v3((0.39, 0.03, 0.995))
WRIST = v3((0.41, -0.005, 0.78))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
HEAD_C = v3((0.0, -0.01, 1.5))
EYE_C = v3((0.0, -0.118, 1.532))
EYE_R = 0.074
LOOK = unit((0.08, -1.0, -0.06))
NECK_A, NECK_B = v3((0, 0.02, 1.22)), v3((0, 0.005, 1.37))


def head():
    skull = Union([
        Ellipsoid(HEAD_C, (0.148, 0.138, 0.158)),
        Ellipsoid(HEAD_C + v3((0, -0.022, -0.105)), (0.165, 0.128, 0.105)),
        Mirror(Ellipsoid(HEAD_C + v3((0.088, -0.06, -0.085)), (0.07, 0.065, 0.06))),
    ], k=0.05, part=SKIN)
    neck = RoundCone(NECK_A, NECK_B, 0.092, 0.085, part=SKIN)
    brow = Union([Ellipsoid(EYE_C + v3((0, 0.012, 0.085)), (0.11, 0.05, 0.032)), Mirror(Ellipsoid(EYE_C + v3((0.07, 0.01, 0.07)), (0.05, 0.045, 0.03), R=rot(ry=18)))], k=0.03, part=SKIN)
    # the eye: an eyeball pushed out of the face, a heavy upper lid down over its top third (cool), a thick lower lid
    lid = Clip(Ellipsoid(EYE_C + v3((0, -0.001, 0.002)), (EYE_R + 0.008, EYE_R + 0.006, EYE_R + 0.008), part=SKIN), [Half(EYE_C + v3((0, 0, EYE_R * 0.22)), unit((0.06, -0.3, -1.0)))], k=0.004)
    lower = Clip(Ellipsoid(EYE_C, (EYE_R + 0.007, EYE_R + 0.005, EYE_R + 0.007), part=SKIN), [Half(EYE_C - v3((0, 0, EYE_R * 0.55)), (0, 0, 1))], k=0.004)
    ball = Sphere(EYE_C, EYE_R, part=EYE)
    nose = Union([Ellipsoid(HEAD_C + v3((0, -0.155, -0.075)), (0.035, 0.022, 0.018)), Mirror(Sphere(HEAD_C + v3((0.022, -0.148, -0.082)), 0.013))], k=0.01, part=SKIN)
    ears = Mirror(Cut(Ellipsoid(HEAD_C + v3((0.15, 0.01, -0.01)), (0.022, 0.034, 0.044), part=SKIN), [Ellipsoid(HEAD_C + v3((0.17, 0.004, -0.01)), (0.012, 0.022, 0.03))], k=0.004))
    face = Union([Union([skull, neck, brow, ears], k=0.03), lid, lower, nose], k=0.01)
    # a lopsided smirk: a slot rising toward his left corner; two little tusks up from the lower lip
    lo = Ellipsoid(HEAD_C + v3((0.01, -0.13, -0.135)), (0.085, 0.07, 0.022), R=rot(ry=-7))
    hi = Ellipsoid(HEAD_C + v3((-0.02, -0.15, -0.117)), (0.11, 0.08, 0.02), R=rot(ry=-15))
    slot = Cut(lo, [hi], k=0.005)
    lips = Clip(Inflate(slot, 0.009, part=LIP), [Inflate(skull, 0.007)], k=0.003)
    face = Cut(Union([face, lips], k=0.005), [slot], k=0.003)
    throat = Ellipsoid(HEAD_C + v3((0.0, -0.1, -0.135)), (0.08, 0.03, 0.02), part=MOUTH)
    tusks = [RoundCone(HEAD_C + v3((s * 0.042, -0.142, -0.15)), HEAD_C + v3((s * 0.046, -0.152, -0.12 + 0.004 * s)), 0.009, 0.004, part=TOOTH) for s in (1.0, -1.0)]
    # hair: a short slicked tuft on the crown
    tuft = Union([Ellipsoid(HEAD_C + v3((0, 0.0, 0.15)), (0.06, 0.08, 0.03), R=rot(rx=-14)), Ellipsoid(HEAD_C + v3((0, -0.05, 0.168)), (0.035, 0.04, 0.02), R=rot(rx=-30))], k=0.02, part=HAIR)
    return Union([face, ball, throat, tuft] + tusks, k=0.0)


def torso_core():
    return Union([
        Ellipsoid((0, 0.0, 1.11), (0.22, 0.165, 0.2)),
        Ellipsoid((0, 0.008, 1.245), (0.27, 0.125, 0.06)),
        Ellipsoid((0, -0.02, 0.95), (0.215, 0.165, 0.13)),
    ], k=0.07, part=TEE)


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def front_y(shape, x, z, y0=-0.5, y1=0.3):
    ys = np.linspace(y0, y1, 1601).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    return float(ys[int(np.argmax(shape.eval(P)[0] < 0))])


def jacket(sleeves):
    core = torso_core()
    shell = Union([Inflate(core, 0.018, part=TRACK), Mirror(Ellipsoid((0.2, 0.008, 1.24), (0.09, 0.11, 0.06), part=TRACK))], k=0.04, part=TRACK)
    shell = Clip(shell, [Half((0, 0, 0.87), (0, 0, -1))], k=0.004)
    band = Clip(Inflate(core, 0.026, part=TRACK), [Half((0, 0, 0.87), (0, 0, -1)), Half((0, 0, 0.92), (0, 0, 1))], k=0.006)
    shell = Union([shell] + sleeves, k=0.014, part=TRACK)
    shell = Union([shell, band], k=0.006)
    # unzipped from the collar to mid-chest: a V showing the tee
    opening = prism([(-0.07, 1.33), (0.07, 1.33), (0.012, 1.09), (-0.012, 1.09)])
    shell = Cut(shell, [opening], k=0.008)
    # the stand-up track collar round the neck, open at the front
    collar = Clip(Union([CappedCone((0, 0.02, 1.22), (0, 0.016, 1.3), 0.112, 0.104, rr=0.012), Torus((0, 0.016, 1.295), 0.1, 0.012)], k=0.01, part=TRACK),
                  [Union([Half((0, -0.04, 0), (0, -1, 0)), Mirror(Half((0.05, 0, 0), (-1, 0, 0)))])], k=0.004)
    collar = Cut(collar, [RoundCone((0, 0.02, 1.2), (0, 0.016, 1.34), 0.094, 0.09)], k=0.003)
    zipper = Mirror(Clip(Inflate(core, 0.021, part=ZIP), [prism([(0.012, 1.09), (0.02, 1.09), (0.075, 1.32), (0.066, 1.32)]), ], k=0.002))
    zip_lo = Clip(Inflate(core, 0.021, part=ZIP), [prism([(-0.005, 0.88), (0.005, 0.88), (0.005, 1.09), (-0.005, 1.09)])], k=0.002)
    pull = Box((0.0, front_y(core, 0, 1.08) - 0.026, 1.075), (0.008, 0.004, 0.016), rr=0.003, part=ZIP)
    return Union([core, shell, collar, zipper, zip_lo, pull], k=0.0)


def chain():
    """chunky gold links round the neck, hanging over the tee to a medallion with an eye on it"""
    core = Inflate(torso_core(), 0.024)
    parts = []
    n = 26
    pts = []
    for i in range(n + 1):
        t = i / n
        a = (t - 0.5) * np.pi * 1.05
        x = 0.115 * np.sin(a)
        z = 1.255 - 0.15 * np.abs(np.cos(a)) ** 2.2
        pts.append((x, z))
    prev = None
    for i, (x, z) in enumerate(pts):
        y = front_y(core, x, z) - 0.006 if abs(x) < 0.1 else front_y(core, x, z) - 0.002
        p = v3((x, y, z))
        if prev is not None:
            mid = (p + prev) * 0.5
            d = unit(p - prev)
            nrm = unit(np.cross(d, v3((0, 1, 0))) if i % 2 else v3((0, -1, 0)))
            Rm = basis(np.cross(d, nrm), d)
            parts.append(Torus(mid, 0.0115, 0.0042, Rm=Rm, part=GOLD))
        prev = p
    mz = 1.065
    my = front_y(core, 0, mz) - 0.012
    med = Union([CappedCone((0, my + 0.006, mz), (0, my - 0.008, mz), 0.04, 0.038, rr=0.005, part=GOLD),
                 Torus((0, my - 0.008, mz), 0.036, 0.004, Rm=basis(v3((0, -1, 0)), v3((0, 0, 1))), part=GOLD),
                 Ellipsoid((0, my - 0.01, mz), (0.022, 0.006, 0.013), part=GOLD),
                 Torus((0, my + 0.0, mz + 0.046), 0.009, 0.003, Rm=basis(v3((1, 0, 0)), v3((0, 0, 1))), part=GOLD)], k=0.002)
    return Union(parts + [med], k=0.0)


def legs():
    hips = Union([
        Ellipsoid((0, 0.012, 0.86), (0.215, 0.15, 0.11)),
        Mirror(loft([(HIP, 0.108), (KNEE, 0.094), (v3((0.125, 0.02, 0.17)), 0.092)])),
    ], k=0.05, part=TRACK)
    pants = Clip(hips, [Half((0, 0, 0.13), (0, 0, -1)), Half((0, 0, 0.9), (0, 0, 1))], k=0.004)
    cuff = Mirror(Clip(RoundCone(v3((0.125, 0.025, 0.2)), v3((0.125, 0.028, 0.12)), 0.082, 0.07, part=TRACK), [Half((0, 0, 0.11), (0, 0, -1))], k=0.004))
    return Union([pants, cuff, Mirror(shoe())], k=0.0)


def shoe():
    """a chunky white high-top: a padded collar, a thick cupsole, a toe cap"""
    x = ANKLE[0]
    foot = Union([
        Box((x, -0.045, 0.06), (0.066, 0.125, 0.052), rr=0.046),
        Ellipsoid((x + 0.004, -0.13, 0.058), (0.07, 0.068, 0.054)),
    ], k=0.03, part=SHOE)
    collar = Union([CappedCone((x, 0.016, 0.05), (x, 0.01, 0.17), 0.07, 0.064, rr=0.016), Torus((x, 0.01, 0.164), 0.06, 0.015)], k=0.012, part=SHOE)
    upper = Clip(Union([foot, collar], k=0.03, part=SHOE), [Half((0, 0, 0.036), (0, 0, -1))], k=0.003)
    tongue = Box((x, -0.066, 0.16), (0.032, 0.012, 0.045), rr=0.012, R=rot(rx=-18), part=SHOE)
    sole = Clip(Inflate(foot, 0.01, part=SOLE), [Half((0, 0, 0.044), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)
    toe = Clip(Inflate(Ellipsoid((x + 0.004, -0.13, 0.058), (0.07, 0.068, 0.054)), 0.006, part=SOLE), [Half((0, -0.135, 0), (0, 1, -0.2))], k=0.003)
    swoosh = Clip(Inflate(foot, 0.003, part=STRIPE), [Half((x + 0.03, 0, 0), (-1, 0, 0)), Half((0, 0, 0.09), (0, 0.5, 1)), Half((0, 0, 0.06), (0, 0.3, -1))], k=0.002)
    laces = [Box((x, yy, zz), (0.033, 0.006, 0.0055), rr=0.005, R=rot(rx=-30), part=LACE) for yy, zz in ((-0.07, 0.136), (-0.088, 0.118), (-0.106, 0.1), (-0.124, 0.083))]
    return Union([Union([upper, tongue], k=0.008), sole, toe, swoosh] + laces, k=0.0)


def hand(s=1.08):
    """a thick green relaxed hand in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y), a gold ring on the middle finger"""
    palm = Ellipsoid(v3((0.0, 0.0, -0.05)) * s, v3((0.022, 0.045, 0.05)) * s, part=SKIN)
    wrist = RoundCone(v3((0, 0, 0.03)) * s, v3((0, 0, -0.02)) * s, 0.036 * s, 0.032 * s, part=SKIN)
    parts = [palm, wrist]
    rings = []
    for i, (f, L) in enumerate(((-0.03, 0.85), (-0.01, 1.0), (0.01, 0.96), (0.03, 0.8))):
        pts = [((0.0, f, -0.09), 0.012), ((-0.008, f * 1.04, -0.09 - 0.03 * L), 0.0115), ((-0.022, f * 1.06, -0.09 - 0.054 * L), 0.0105), ((-0.036, f * 1.08, -0.09 - 0.064 * L), 0.0095)]
        parts.append(loft([(v3(p) * s, r * s) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Ellipsoid(v3(pts[-1][0]) * s + v3((0.004, 0, 0.003)), (0.0055, 0.0075, 0.007), part=NAIL))
        if i == 1:
            rc = (v3(pts[0][0]) + v3(pts[1][0])) * 0.5 * s
            rings.append(Torus(rc, 0.0125 * s, 0.0035, Rm=basis(unit(v3(pts[1][0]) - v3(pts[0][0])), v3((1, 0, 0))), part=GOLD))
    parts.append(loft([(v3((-0.01, -0.034, -0.03)) * s, 0.015 * s), (v3((-0.028, -0.052, -0.06)) * s, 0.013 * s), (v3((-0.04, -0.054, -0.084)) * s, 0.0115 * s)], part=SKIN, k=0.004))
    return Union([Union(parts, k=0.008)] + rings, k=0.0)


def sleeve():
    s = Clip(loft([(SHOULDER, 0.076), (ELBOW, 0.068), (WRIST + (ELBOW - WRIST) * 0.1, 0.06)], part=TRACK, k=0.012), [Half(WRIST + (ELBOW - WRIST) * 0.06, (WRIST - ELBOW))], k=0.004)
    d = unit(WRIST - ELBOW)
    cuff = Clip(RoundCone(WRIST + (ELBOW - WRIST) * 0.12, WRIST + d * 0.005, 0.058, 0.046, part=TRACK), [Half(WRIST + d * 0.006, d)], k=0.003)
    return Union([s, cuff], k=0.008), place(hand(), WRIST, HAND)


def pieces():
    sl, hd = sleeve()
    body = Union([jacket([sl, Move(sl, R=FLIP)]), legs(), hd, Move(hd, R=FLIP)], k=0.0)
    return [("head", head(), 0.0018), ("body", body, 0.0035), ("chain", chain(), 0.0015)]


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

    # skin: leaf green, darker olive over the brow and crown and down the neck, warty speckles, a flush across the cheeks
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(112, 168, 84), (len(P), 3)).copy()
    sk = sk + (srgb(68, 112, 52) - sk) * (smooth(1.58, 1.68, z) * 0.6 + smooth(1.32, 1.24, z) * 0.5)[:, None]
    sk = sk + (srgb(140, 186, 96) - sk) * (smooth(-0.1, -0.16, y) * smooth(1.3, 1.45, z) * 0.4)[:, None]
    cheek = smooth(0.06, 0.0, np.linalg.norm(Q - (HEAD_C + v3((0.1, -0.09, -0.08))), axis=1))
    sk = sk + (srgb(176, 150, 90) - sk) * (cheek * 0.35)[:, None]
    sk *= (1.0 + 0.1 * mott)[:, None]
    put(m, sk, 0.48, bump=0.35)
    spk(m, (70, 110, 48), 0.35)
    # the eye: a white with red veins near the rim, a big blue iris looking a little to his left, inked pupil and ring, a hard glint; liners
    m = c.mask(EYE)
    dv = P - EYE_C
    r = np.linalg.norm(dv, axis=1)
    dd = dv / np.maximum(r, 1e-6)[:, None]
    ang = np.arccos(np.clip(dd @ LOOK, -1, 1))
    ey = np.broadcast_to(srgb(246, 242, 232), (len(P), 3)).copy()
    vein = smooth(0.5, 0.9, noise3(P * np.array([1, 1, 1], np.float32), 0.004)) * smooth(0.8, 1.3, ang)
    ey = ey + (srgb(210, 100, 100) - ey) * (vein * 0.6)[:, None]
    ir = srgb(80, 150, 220) + (srgb(30, 70, 140) - srgb(80, 150, 220)) * smooth(0.12, 0.42, ang)[:, None]
    ey = np.where((ang < 0.44)[:, None], ir, ey)
    c.draw(m, (ang - 0.19) * EYE_R, 0.0)
    c.draw(m & (ang < 0.6), np.abs(ang - 0.44) * EYE_R, 0.0008, 0.8)
    g = smooth(0.13, 0.07, np.arccos(np.clip(dd @ unit(LOOK + v3((0.3, 0, 0.45))), -1, 1)))
    ey = ey + (srgb(255, 255, 250) - ey) * g[:, None]
    ey *= (1.0 - 0.35 * smooth(0.0, 0.5, dd[:, 2]))[:, None]
    put(m, ey, 0.06)
    c.spk[m, 3] = 0.0
    lm = c.mask(SKIN) & (r < EYE_R + 0.014) & (dv[:, 1] < 0.02)
    lidp = (P - (EYE_C + v3((0, 0, EYE_R * 0.22)))) @ unit((0.06, -0.3, -1.0))
    c.draw(lm & (dv[:, 2] > 0.0) & (lidp > -0.004), np.abs(lidp - 0.0005), 0.0022, 0.95)
    c.draw(lm & (dv[:, 2] < -EYE_R * 0.4), np.abs(r - EYE_R - 0.004), 0.0014, 0.7)
    put(c.mask(LIP), srgb(70, 108, 52), 0.35, bump=0.2)
    put(c.mask(MOUTH), srgb(44, 14, 16), 0.6)
    put(c.mask(TOOTH), srgb(240, 230, 200) * (1.0 - 0.25 * smooth(HEAD_C[2] - 0.14, HEAD_C[2] - 0.15, z))[:, None], 0.3)
    m = c.mask(HAIR)
    put(m, srgb(30, 44, 22) * (1.0 + 0.3 * noise3(P, 0.003))[:, None], 0.5, bump=1.0)
    c.strp[m, 0] = (x * 2.0)[m]
    c.strp[m, 1] = 0.8
    put(c.mask(NAIL), srgb(80, 120, 60), 0.3)
    # the tracksuit: red nylon tricot, sheen on the folds, two white stripes down the outside of each arm and leg
    m = c.mask(TRACK)
    tr = srgb(190, 30, 32) * (1.0 + 0.06 * mott + 0.25 * c.wear)[:, None]
    stripe = np.zeros(len(P), bool)
    legs = (z < 0.88)
    ldist = np.abs(np.arctan2(Q[:, 1] - 0.0, Q[:, 0] - 0.12))          # 0 at the outer side of each leg
    stripe |= legs & (np.abs(ldist) < 0.33) & ((np.abs(ldist) < 0.11) | (np.abs(ldist) > 0.2))
    ad = unit(WRIST - SHOULDER)
    rel = Q - SHOULDER
    along = rel @ ad
    radial = rel - np.outer(along, ad)
    ox = v3((1, 0, 0)) - ad * float(ad[0])
    ox = ox / np.linalg.norm(ox)                    # the arm's outer side
    oy = np.cross(ad, ox)
    aa = np.abs(np.arctan2(radial @ oy, radial @ ox))
    arms = (Q[:, 0] > 0.24) & (along > 0.02) & (z < 1.26)
    stripe |= arms & (aa < 0.33) & ((aa < 0.11) | (aa > 0.2))
    tr = np.where(stripe[:, None], srgb(240, 238, 230) * (1.0 + 0.04 * mott)[:, None], tr)
    put(m, tr, 0.5, bump=0.5)
    m = c.mask(TEE)
    put(m, srgb(240, 238, 232) * (1.0 + 0.04 * mott)[:, None], 0.85, bump=0.7)
    m = c.mask(GOLD)
    put(m, srgb(246, 190, 80) * (1.0 - 0.5 * c.cavity)[:, None], 0.2, metal=1.0, bump=0.04, grain=1.0)
    put(c.mask(ZIP), srgb(200, 200, 204), 0.3, metal=1.0)
    # high-tops: white leather scuffed grey, a red stripe, red-tinted soles at the heel
    m = c.mask(SHOE)
    put(m, srgb(244, 242, 236) * (1.0 - 0.18 * smooth(0.3, 0.9, n2) - 0.15 * smooth(0.07, 0.03, z))[:, None], 0.45, bump=0.6, grain=1.0)
    m = c.mask(STRIPE)
    put(m, srgb(200, 36, 36), 0.45, bump=0.4, grain=1.0)
    m = c.mask(SOLE)
    put(m, srgb(232, 228, 216) * (1.0 - 0.3 * smooth(0.02, 0.0, z) - 0.2 * smooth(0.3, 0.8, n2))[:, None], 0.7, bump=0.3)
    c.draw(m & (np.abs(z - 0.022) < 0.012), np.abs(z - 0.022), 0.0008, 0.5)
    put(c.mask(LACE), srgb(240, 238, 230), 0.8, bump=0.4)
    c.col *= (0.32 + 0.68 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model

GAME = {
    "budget": {"head": 2600, "body": 4600, "chain": 1200},
    "density": {"head": 1.7, "chain": 1.4},
    "tex": 2048,
    "stride": {"walk": 1.12, "run": 1.9},
    "speed": 0.85,
    "look": ["head"], "neck": "neck",
    "look_pivot": (0.0, 0.01, 1.32),
    "radius": 0.4,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.012, 0.84), (0, 0.012, 0.97), "root", 0.15),
        Bone("spine", (0, 0.012, 0.97), (0, 0.005, 1.1), "hips", 0.16),
        Bone("chest", (0, 0.005, 1.1), (0, 0.01, 1.24), "spine", 0.18),
        Bone("neck", NECK_A, NECK_B, "chest", 0.085),
        Bone("head", NECK_B, HEAD_C + v3((0, 0, 0.18)), "neck", 0.15),
        Bone("shoulder.L", (0.05, 0.01, 1.235), SHOULDER, "chest", 0.08),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.08),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.065),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.13, "forearm.L", 0.04),
        Bone("thigh.L", HIP, KNEE, "hips", 0.1),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.09),
        Bone("foot.L", ANKLE, (0.13, -0.17, 0.03), "shin.L", 0.05),
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
    rig[hp & (z > 1.36)] = ix["head"]
    cp = piece == 2
    allow(cp, "chest")
    rig[cp] = ix["chest"]
    bp = piece == 1
    # the trousers below the jacket's ribbed hem (0.87) and the shoes; the hem itself stays with the torso
    legs = bp & (z < 0.835) & ~np.isin(part, (TEE, ZIP))
    allow(legs & (z > 0.68), "hips")
    allow(legs & (x > -0.04), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.04), "thigh.R", "shin.R", "foot.R")
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])

    def seg(a, b):
        ab = b - a
        t = np.clip(((Q - a) @ ab) / float(ab @ ab), 0.0, 1.0)
        return np.linalg.norm(Q - a - np.outer(t, ab), axis=1)
    arm_d = np.minimum(np.minimum(seg(SHOULDER, ELBOW) - 0.085, seg(ELBOW, WRIST) - 0.07), seg(WRIST, WRIST - HAND[:, 2] * 0.15) - 0.05)
    body_d = torso_core().eval(P)[0] - 0.018
    arms = bp & ~legs & (Q[:, 0] > 0.2) & (arm_d < body_d)
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "upper_arm.R", "forearm.R", "hand.R")
    root = arms & (arm_d > body_d - 0.03)               # where the sleeve meets the jacket
    allow(root, "chest")
    allow(root & (x > 0), "shoulder.L")
    allow(root & (x <= 0), "shoulder.R")
    torso = bp & ~legs & ~arms
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.12) & (z > 1.12), "shoulder.L", "upper_arm.L")
    allow(torso & (x < -0.12) & (z > 1.12), "shoulder.R", "upper_arm.R")
    return A, rig


WALK = dict(stride=1.12, stance=0.6, foot_x=0.12, lift=0.07, bob=0.024, drop=0.04, sway=0.035, roll=8.0, yaw=9.0, counter=1.6,
            lean=-3.0, toe_off=16.0, toe_out=12.0, swing_point=8.0)
RUN = dict(stride=1.9, stance=0.42, foot_x=0.12, lift=0.14, bob=0.035, drop=0.07, sway=0.03, roll=5.0, yaw=10.0, counter=1.4,
           lean=10.0, toe_off=26.0, toe_out=8.0, swing_point=16.0, spine_lean=4.0)


def motions(rig):
    """walk: a swagger: leaning back, chest out, the shoulders rolling hard against the hips, a dip on every left step, the right arm swinging
    wide and loose, the left hanging cool, the head nodding to a beat; run: a heavy jog; idle: weight on one leg, nodding to music in his
    head, a hand up to straighten the medallion, a look round"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        s = math.sin(TAU * u)
        c = math.cos(TAU * u)
        if not run:
            dip = max(0.0, math.sin(TAU * (u - 0.05))) ** 2
            p.offset = p.offset + Vector((0.0, 0.0, -0.022 * dip))
            p.rot("chest", -4.0, 0, 0)
        p.rot("upper_arm.R", -(40.0 if run else 26.0) * c, 0, (8.0 if run else 14.0) + 6.0 * max(0.0, -c))
        p.rot("forearm.R", -(55.0 if run else 18.0) - 14.0 * max(0.0, -c), 0, 0)
        p.rot("upper_arm.L", (40.0 if run else 10.0) * c, 0, -(8.0 if run else 6.0))
        p.rot("forearm.L", -(55.0 if run else 12.0), 0, 0)
        p.rot("neck", (6.0 if run else 0.0) + 4.0 * math.sin(2 * TAU * u - 0.5), 0, 0)
        p.world["head"] = R((4.0 if run else 0.0) + 5.0 * math.sin(2 * TAU * u - 1.2), (0.0 if run else 6.0), (0.0 if run else -6.0) + 3.0 * s)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]
    lips = Vector((0.0, -0.12, 1.08))
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        beat = math.sin(TAU * 1.6 * t)
        stand(rig, p, legs, {"L": (Vector((0.15, -0.09, 0.0)), 16.0), "R": (Vector((-0.12, -0.02, 0.0)), -22.0)},
              hip_shift=(0.032, 0.0, -0.018 + 0.006 * abs(beat)), roll=-5.0, yaw=-4.0)
        p.rot("spine", -2.0, 2.0, 3.0)
        p.rot("chest", -3.0 + 1.0 * beat, 1.5, 3.0)
        fix = ease((t - 2.4) / 0.4) * (1.0 - ease((t - 3.6) / 0.4))
        look = ease((t - 4.2) / 0.4) * (1.0 - ease((t - 5.4) / 0.4))
        p.rot("neck", 4.0 * max(0.0, beat), 0, 0)
        p.world["head"] = R(5.0 * max(0.0, beat) - 6.0 * fix, 5.0, -5.0 + 30.0 * look)
        # the right hand comes up to the medallion and straightens it
        p.rot("upper_arm.R", -30.0 * fix, 0, -10.0 * fix + 6.0)
        p.rot("forearm.R", -95.0 * fix - 8.0, 0, -25.0 * fix)
        p.rot("upper_arm.L", 2.0 * beat, 0, -4.0)
        p.rot("forearm.L", -10.0, 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
