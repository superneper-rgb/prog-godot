## FOINT CITY townsfolk: the hole-chested hulk (working name; the user names it). A huge pale headless brute: a tuft of black hair where a head would be, his face peering out of a round hole in his chest, violet floral tattoos on the shoulders, purple sweatpants, bare feet, a yellow digital wristwatch.
# Concept: the user's sheet, image 7 top right (F:/prog-godot-cache/folk/refs/7.webp). Measured off it (3x crop, 1.92 mm a pixel, 2.00 m to the top of the hair): torso top 1.81,
# shoulders 1.66, the hole 0.54 m across centred at 1.40 with the face filling its lower half (0.5 m wide, 1.11-1.40), waistband 0.98-1.08, crotch 0.65, cuffs 0.2-0.27,
# feet 0.33 long; the arms enormous (upper arm 0.28 thick). The width is pulled in about 8% (elbows at +-0.8 m, inside the crowd's culling box).
# Rest pose: his right fist on his hip (kept all the time: his attitude), the left arm hanging out over the bulk. No props (the shopping bag is dropped).
# The skin is pale with a fine crazed-glaze crackle (drawn as ink) and rusty grime. Kit gaps filled here: hit() / normal(), hand(), a Voronoi crackle in paint().
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 2.00
REF = ("7.webp", (772, 5, 1142, 368))

(SKIN, EYE, HAIR, PANTS, CORD, NAIL, STRAP, WATCH, DIAL, GUM) = range(1, 11)
COLOURS = {
    SKIN: ((0.62, 0.45, 0.33), 0.55, 0.0),
    EYE: ((0.7, 0.55, 0.2), 0.2, 0.0),
    HAIR: ((0.01, 0.01, 0.01), 0.6, 0.0),
    PANTS: ((0.17, 0.07, 0.2), 0.85, 0.0),
    CORD: ((0.75, 0.68, 0.58), 0.8, 0.0),
    NAIL: ((0.7, 0.4, 0.38), 0.3, 0.0),
    STRAP: ((0.04, 0.03, 0.03), 0.6, 0.0),
    WATCH: ((0.8, 0.55, 0.05), 0.35, 0.0),
    DIAL: ((0.15, 0.17, 0.12), 0.2, 0.0),
    GUM: ((0.3, 0.08, 0.08), 0.5, 0.0),
}
F32 = np.float32
UP = np.array((0, 0, 1), F32)


def hit(shape, start, direction, far=1.5, n=500):
    """where a ray from `start` first enters `shape`"""
    d = v3(direction) / np.linalg.norm(direction)
    s = v3(start)
    ts = np.linspace(0.0, far, n).astype(F32)
    dd = shape.eval((s[None, :] + ts[:, None] * d[None, :]).astype(F32))[0]
    i = int(np.argmax(dd < 0))
    if dd[i] >= 0 or i == 0:
        raise ValueError("hit: no surface along the ray from %s" % (s,))
    a, b = float(ts[i - 1]), float(ts[i])
    for _ in range(30):
        m = 0.5 * (a + b)
        if shape.eval((s + d * m)[None, :].astype(F32))[0][0] < 0:
            b = m
        else:
            a = m
    return s + d * F32(0.5 * (a + b))


def normal(shape, p, e=0.0015):
    ex = np.eye(3, dtype=F32) * e
    g = np.array([shape.eval((p + ex[i])[None, :])[0][0] - shape.eval((p - ex[i])[None, :])[0][0] for i in range(3)], F32)
    return g / np.linalg.norm(g)


def frame(z_dir, x_dir):
    """columns x, y, z: local +Z along z_dir, local +X leaning to x_dir"""
    z = v3(z_dir) / np.linalg.norm(z_dir)
    x = v3(x_dir) - z * float(v3(x_dir) @ z)
    x /= np.linalg.norm(x)
    return np.stack([x, np.cross(z, x), z], 1).astype(F32)


# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; he faces -Y)

HOLE_C = v3((0.0, 0.0, 1.40))
HOLE_R = 0.25
FACE_C = v3((0.0, -0.075, 1.255))        # the face's head, sitting in the bottom of the hole and filling its width
FACE_R = v3((0.232, 0.2, 0.185))
SHOULDER = v3((0.5, 0.02, 1.52))
# his right arm (built on the left, mirrored): akimbo, the fist on the hip
R_EL, R_WR = v3((0.77, 0.05, 1.19)), v3((0.60, -0.02, 0.93))
R_HAND = frame(-v3((-0.25, 0.05, -1.0)), v3((1.0, 0.35, 0.1)))
# his left arm: hanging out over the bulk, the hand loose
L_EL, L_WR = v3((0.765, 0.0, 1.16)), v3((0.75, -0.06, 0.82))
L_HAND = frame(-v3((-0.12, -0.12, -1.0)), v3((1.0, 0.0, 0.1)))
HIP = v3((0.2, 0.02, 0.88))
KNEE = v3((0.29, -0.035, 0.50))
ANKLE = v3((0.345, 0.03, 0.115))
TOE_OUT = 12.0
FWD = v3((np.sin(np.radians(TOE_OUT)), -np.cos(np.radians(TOE_OUT)), 0.0))
BALL = v3((ANKLE[0], ANKLE[1], 0.0)) + FWD * 0.15
FLIP = np.diag([-1.0, 1.0, 1.0]).astype(F32)


# ---------------------------------------------------------------------------------------------------- the trunk, the hole, the arms

def trunk_core():
    return Union([
        Ellipsoid((0, 0.02, 1.42), (0.47, 0.32, 0.33)),
        Ellipsoid((0, 0.0, 1.12), (0.43, 0.31, 0.2)),
        Ellipsoid((0, 0.03, 1.70), (0.22, 0.19, 0.14)),                   # the stump where a head would be
        Mirror(RoundCone((0.1, 0.04, 1.70), (0.4, 0.04, 1.60), 0.12, 0.12)),      # the traps sloping to the shoulders
        Mirror(Ellipsoid((0.2, -0.16, 1.5), (0.2, 0.15, 0.14))),          # pecs
        Mirror(Ellipsoid((0.33, 0.08, 1.3), (0.13, 0.2, 0.22))),          # lats
    ], k=0.09, part=SKIN)


def trunk():
    t = Bump(trunk_core(), lambda P: noise3(P, 0.08) * 0.6 + noise3(P, 0.03) * 0.4, 0.006)
    hole = CappedCone(HOLE_C + v3((0, 0.06, 0)), HOLE_C + v3((0, -0.6, 0)), HOLE_R, HOLE_R, rr=0.07)
    return Cut(t, [hole], k=0.05)


def hand(curl, thumb, fist=False):
    """hand space: the wrist at the origin, fingers along -Z, the back of the hand +X, the thumb toward -Y. Big, thick fingers."""
    parts = [RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.075, 0.068, part=SKIN), Ellipsoid((0.0, 0.0, -0.062), (0.04, 0.066, 0.064), part=SKIN)]
    for i, (fy, L) in enumerate(((-0.042, 0.9), (-0.014, 1.0), (0.014, 0.96), (0.041, 0.8))):
        p = v3((0.006, fy, -0.112))
        pts = [(p, 0.021)]
        for k, seg in enumerate((0.05, 0.034, 0.028)):
            ang = np.radians(curl[i]) * (k + 1) * (0.9 if fist else 0.55)
            p = p + v3((-np.sin(ang), 0.0, -np.cos(ang))) * seg * L
            pts.append((p, 0.02 - 0.0018 * k))
        parts.append(loft(pts, part=SKIN, k=0.008))
        parts.append(Sphere(pts[0][0] + v3((0.008, 0, 0.004)), 0.022, part=SKIN))      # knuckles
    ta = np.radians(thumb)
    t0 = v3((-0.012, -0.05, -0.035))
    t1 = t0 + v3((-0.02, -0.03, -0.04))
    t2 = t1 + v3((-0.035 * np.sin(ta), 0.02 * np.sin(ta), -0.04 * np.cos(ta)))
    parts.append(loft([(t0, 0.026), (t1, 0.022), (t2, 0.019)], part=SKIN, k=0.008))
    return Union(parts, k=0.012)


def arm(el, wr, R, curl, thumb, fist):
    """built on the left: the deltoid cap, a huge bicep, a Popeye forearm, the hand"""
    delt = Ellipsoid((0.53, 0.03, 1.56), (0.21, 0.2, 0.19), part=SKIN)
    up = loft([(SHOULDER, 0.15), (SHOULDER + (el - SHOULDER) * 0.45 + v3((0.0, -0.02, 0.0)), 0.145), (el, 0.115)], part=SKIN, k=0.05)
    fore = loft([(el, 0.115), (el + (wr - el) * 0.35, 0.128), (wr, 0.08)], part=SKIN, k=0.05)
    return Union([delt, up, fore, place(hand(curl, thumb, fist), wr, R)], k=0.05, part=SKIN)


def arms():
    left = arm(L_EL, L_WR, L_HAND, (22.0, 28.0, 34.0, 40.0), 25.0, False)
    right = Move(arm(R_EL, R_WR, R_HAND, (90.0, 95.0, 95.0, 92.0), 70.0, True), R=FLIP)
    return Union([left, right], k=0.0)


def hair():
    """a tuft of short black spikes on the stump"""
    rng = np.random.default_rng(3)
    t = trunk_core()
    spikes = []
    for i in range(46):
        a = rng.uniform(0, 2 * np.pi)
        r = 0.19 * np.sqrt(rng.uniform(0, 1))
        x, y = r * np.cos(a), 0.03 + r * np.sin(a) * 0.85
        s = hit(t, (x, y, 2.2), (0, 0, -1))
        n = normal(t, s)
        d = n + v3((rng.normal(0, 0.5), rng.normal(0, 0.5), 0.15))
        d /= np.linalg.norm(d)
        L = rng.uniform(0.07, 0.19) * (1.0 - 0.35 * r / 0.19)
        mid = s + d * L * 0.55 + v3((rng.normal(0, 0.012), rng.normal(0, 0.012), rng.normal(0, 0.008)))          # each wiry hair kinks
        spikes.append(((x, y), loft([(s - n * 0.008, 0.011), (mid, 0.0065), (mid + (mid - s) * 0.8 + v3((rng.normal(0, 0.015), rng.normal(0, 0.015), 0)), 0.002)], part=HAIR, k=0.003)))      # wiry clumps (single hairs will not decimate)
    # grouped in cells so a point only tests the hairs near it (250 loose children made the mesher crawl)
    # the mass of the shock under the stray clumps: a dome of tufts
    mass = Bump(Ellipsoid((0, 0.03, 1.79), (0.2, 0.17, 0.075), part=HAIR),
                lambda P: (1.0 - np.abs(noise3(P * v3((1.0, 1.0, 0.4)), 0.03))) ** 2 * 0.9 + noise3(P, 0.05) * 0.4, 0.018)      # (gentle enough to stay one piece: islands will not decimate)
    mass = Clip(mass, [Half((0, 0, 1.76), (0, 0, -1))], k=0.01)
    spikes.append(((0.0, 0.0), mass))
    cells = {}
    for (x, y), sh in spikes:
        cells.setdefault((int(np.floor(x / 0.08)), int(np.floor(y / 0.08))), []).append(sh)
    return Union([Union(v, k=0.003, part=HAIR) for v in cells.values()], k=0.003, part=HAIR)


# ---------------------------------------------------------------------------------------------------- the face in the hole

def face():
    """a wide, smug, toad-like face: heavy sleepy lids over yellow eyes, a small nose, a long thin smirk"""
    head = Ellipsoid(FACE_C, FACE_R, part=SKIN)
    cheeks = Mirror(Ellipsoid(FACE_C + v3((0.12, -0.115, -0.045)), (0.095, 0.075, 0.07), part=SKIN))
    brow = Ellipsoid(FACE_C + v3((0.0, -0.105, 0.085)), (0.19, 0.085, 0.055), part=SKIN)
    f = Union([head, cheeks, brow], k=0.05, part=SKIN)
    eyes, lids = [], []
    for sx in (1.0,):
        p = hit(f, (0.095 * sx, -0.6, FACE_C[2] + 0.075), (0, 1, 0))
        n = normal(f, p)
        ec = p + n * 0.006
        er = 0.037
        eyes.append(Sphere(ec, er, part=EYE))
        lids.append(Clip(Ellipsoid(ec + n * 0.001, (er + 0.008, er + 0.008, er + 0.007), part=SKIN), [Half(ec + UP * 0.007, (0.0, 0.25, -1.0))], k=0.004))   # the heavy upper lid, down to the middle
        lids.append(Clip(Ellipsoid(ec - UP * 0.012, (er + 0.009, er + 0.005, er + 0.004), part=SKIN), [Half(ec - UP * 0.027, (0, 0, 1))], k=0.004))       # the bag under it
    ns = hit(f, (0.0, -0.6, FACE_C[2] + 0.02), (0, 1, 0))
    nose = Union([Ellipsoid(ns + v3((0, -0.012, 0.004)), (0.022, 0.016, 0.022), part=SKIN), Mirror(Ellipsoid(ns + v3((0.014, -0.006, -0.006)), (0.012, 0.011, 0.01), part=SKIN))], k=0.01)
    f = Union([f, Mirror(Union(lids, k=0.0)), nose], k=0.008)
    nostrils = Mirror(Ellipsoid(ns + v3((0.011, -0.022, -0.009)), (0.006, 0.006, 0.004), part=SKIN))
    # the smirk: a long thin mouth line, its corners curling up (his left one a little higher), a lip roll under it
    pts = []
    for t in np.linspace(-1.0, 1.0, 15):
        x = 0.17 * t
        z = FACE_C[2] - 0.045 + 0.026 * t * t + 0.007 * t
        s = hit(f, (x, -0.6, z), (0, 1, 0))
        pts.append(s)
    groove = loft([(p, 0.0045) for p in pts], k=0.004)
    lip = loft([(p - UP * 0.011 + normal(f, p) * -0.002, 0.007 * (1.0 - 0.6 * abs(t))) for p, t in zip(pts, np.linspace(-1, 1, 15))], part=SKIN, k=0.006)
    f = Union([f, lip], k=0.006)
    f = Cut(f, [groove, nostrils], k=0.003)
    return Union([f] + [Mirror(e) for e in eyes], k=0.0)


# ---------------------------------------------------------------------------------------------------- sweatpants, cord, bare feet, watch

def pants():
    seat = Ellipsoid((0, 0.05, 0.86), (0.44, 0.31, 0.22))
    waist = Ellipsoid((0, 0.0, 1.03), (0.45, 0.33, 0.1))
    leg = loft([(HIP + v3((0.0, 0.0, 0.05)), 0.235), (KNEE + v3((0.01, 0.0, 0.0)), 0.2), (v3((ANKLE[0], ANKLE[1] - 0.01, 0.33)), 0.185)], k=0.05)
    body = Union([seat, waist, Mirror(leg)], k=0.07, part=PANTS)
    folds = lambda P: noise3(P * v3((0.9, 0.9, 2.4)), 0.09) * 0.8 + noise3(P * v3((1, 1, 2)), 0.04) * 0.2        # baggy folds, bunching round the legs
    body = Bump(body, folds, 0.014)
    body = Clip(body, [Half((0, 0, 1.075), (0, 0, 1)), Half((0, 0, 0.26), (0, 0, -1))], k=0.02)
    band = Clip(Inflate(Ellipsoid((0, 0.0, 1.03), (0.45, 0.33, 0.1)), 0.012, part=PANTS), [Half((0, 0, 1.08), (0, 0, 1)), Half((0, 0, 0.995), (0, 0, -1))], k=0.008)
    cuff = Mirror(CappedCone(v3((ANKLE[0], ANKLE[1] - 0.005, 0.2)), v3((ANKLE[0], ANKLE[1] - 0.008, 0.29)), 0.105, 0.125, rr=0.02, part=PANTS))
    # the drawstring: a bow at the front of the waistband, its two ends hanging
    s = hit(band, (0.0, -0.8, 1.035), (0, 1, 0))
    k1 = s + v3((0, -0.012, 0))
    bow = [loft([(k1, 0.009), (k1 + v3((sx * 0.035, -0.012, 0.022)), 0.008), (k1 + v3((sx * 0.06, -0.01, 0.0)), 0.008), (k1 + v3((sx * 0.03, -0.012, -0.014)), 0.008), (k1, 0.009)], part=CORD, k=0.006)
           for sx in (-1.0, 1.0)]
    ends = [loft([(k1, 0.008), (k1 + v3((sx * 0.012, -0.012, -0.06)), 0.0075), (k1 + v3((sx * 0.02, -0.02, -0.15)), 0.007)], part=CORD, k=0.006) for sx in (-1.0, 1.0)]
    tips = [CappedCone(k1 + v3((sx * 0.02, -0.02, -0.15)), k1 + v3((sx * 0.022, -0.021, -0.175)), 0.008, 0.007, rr=0.002, part=CORD) for sx in (-1.0, 1.0)]
    return Union([body, band, cuff] + bow + ends + tips + [Sphere(k1, 0.014, part=CORD)], k=0.0)


def foot():
    """built on the left: a big flat bare foot, five toes with pink nails"""
    f = FWD
    side = np.cross(UP, f)
    a = v3((ANKLE[0], ANKLE[1], 0.0))
    sole = loft([(a - f * 0.075 + UP * 0.05, 0.05), (a + f * 0.06 + UP * 0.048, 0.07), (a + f * 0.15 + UP * 0.035, 0.065)], part=SKIN, k=0.04)
    ankle = RoundCone(a + UP * 0.25, a + UP * 0.06, 0.075, 0.07, part=SKIN)
    bones = Mirror(Ellipsoid(a + UP * 0.1 + side * 0.0, (0.0, 0.0, 0.0), part=SKIN)) if False else None
    toes = []
    nails = []
    for i, (o, r, L) in enumerate(((-0.045, 0.03, 0.06), (-0.008, 0.022, 0.055), (0.018, 0.02, 0.05), (0.04, 0.018, 0.043), (0.059, 0.016, 0.036))):
        base = a + f * 0.17 + side * (-o) + UP * 0.03
        tip = base + f * L - UP * 0.008
        toes.append(RoundCone(base, tip, r, r * 0.9, part=SKIN))
        nails.append(Ellipsoid(tip + UP * (r * 0.62) - f * 0.004, (r * 0.75, r * 0.6, r * 0.3), R=basis(UP, f), part=NAIL))
    f_ = Union([sole, ankle] + toes, k=0.02, part=SKIN)
    f_ = Clip(f_, [Half((0, 0, 0.0), (0, 0, -1))], k=0.01)
    return Union([f_] + nails, k=0.0)


def watch():
    """on his left wrist: a black strap, a chunky yellow digital case on the outside"""
    d = (L_EL - L_WR) / np.linalg.norm(L_EL - L_WR)
    c = L_WR + d * 0.06
    out = v3((1.0, 0.0, 0.0)) - d * d[0]
    out /= np.linalg.norm(out)
    R = frame(out, d)
    strap = Torus(c, 0.085, 0.012, Rm=basis(d, out), part=STRAP)
    case = Box(c + out * 0.09, (0.032, 0.036, 0.014), rr=0.007, R=R @ rot(rz=90), part=WATCH)
    dial = Box(c + out * 0.103, (0.022, 0.025, 0.003), rr=0.003, R=R @ rot(rz=90), part=DIAL)
    return Union([strap, case, dial], k=0.0)


def pieces():
    import os
    q = float(os.environ.get("FOLK_DRAFT", "1"))
    return [("trunk", trunk(), 0.004 * q), ("face", face(), 0.0016 * q), ("arms", arms(), 0.0038 * q), ("hair", hair(), 0.0021 * q),
            ("pants", pants(), 0.0035 * q), ("feet", Mirror(foot()), 0.0025 * q), ("watch", watch(), 0.0015 * q)]


# ---------------------------------------------------------------------------------------------------- paint

def crackle(P, cell):
    """distance to the nearest edge of a jittered Voronoi tiling (the crazed glaze of his skin)"""
    q = P / cell
    base = np.floor(q).astype(np.int64)
    d1 = np.full(len(P), 9.0, F32)
    d2 = np.full(len(P), 9.0, F32)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                c = base + np.array([dx, dy, dz])
                h = (c[:, 0] * 73856093) ^ (c[:, 1] * 19349663) ^ (c[:, 2] * 83492791)
                jit = np.stack([((h >> s) & 1023) / 1023.0 for s in (0, 10, 20)], 1).astype(F32)
                d = np.linalg.norm(q - (c + 0.15 + 0.7 * jit), axis=1)
                d2 = np.where(d < d1, d1, np.minimum(d2, d))
                d1 = np.minimum(d1, d)
    return (d2 - d1) * 0.5 * cell


def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.04) * 0.5 + noise3(P, 0.012) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, F32)], 1)

    def lerp(a, b, t):
        t = np.asarray(t, F32)
        return a + (b - a) * (t[:, None] if t.ndim else t)

    def full(col):
        return np.broadcast_to(srgb(*col), (n, 3)).copy()

    # skin: pale clay-cream, rusty grime in patches (heaviest across the chest), the crazed crackle, violet floral tattoos on the shoulders
    m = c.mask(SKIN)
    sk = full((226, 196, 166))
    sk = lerp(sk, srgb(236, 214, 188), smooth(0.2, 0.9, c.N[:, 2]) * 0.4)
    sk *= (1.0 + 0.06 * mott)[:, None]
    rust = smooth(0.15, 0.55, noise3(P + 5.0, 0.07) * 0.6 + noise3(P, 0.012) * 0.4) * (0.45 + 0.55 * smooth(1.15, 1.6, z) * smooth(0.55, 0.15, np.abs(x)))
    sk = lerp(sk, srgb(140, 82, 38), np.clip(rust * 1.2, 0, 1) * 0.75)
    inside = (np.hypot(x - HOLE_C[0], z - HOLE_C[2]) < HOLE_R + 0.01) & (y > -0.27) & (c.mask(SKIN)) & (np.abs(x) < 0.3)
    deep = smooth(-0.25, 0.05, y) * inside
    sk = lerp(sk, srgb(46, 32, 26), deep * 0.9 * (1.0 - smooth(1.36, 1.2, z) * 0.0))        # the hole's inside falls away into the dark
    # tattoos: vines curling over each deltoid and down the upper arm, five-petal flowers on them
    # tattoos, laid out in a chart round each deltoid: u runs front (-) to back (+), v up (+) and down the arm (-), in radians
    dc = v3((0.53, 0.03, 1.56))
    d = Q - dc
    dl = np.maximum(np.linalg.norm(d, axis=1), 1e-6)
    tu = np.arctan2(d[:, 1], d[:, 0])
    tv = np.arcsin(np.clip(d[:, 2] / dl, -1, 1))
    t_on = (dl < 0.42) & (np.abs(x) > 0.36) & (tu > -1.6) & (tu < 1.0) & (tv > -1.45) & (tv < 1.05)
    vine = np.abs(tv - (0.32 * np.sin(tu * 3.2 + 0.4) - 0.15 + 0.5 * tu)) * 0.75
    vine2 = np.abs(tu - (-0.55 + 0.25 * np.sin(tv * 4.0)))
    tat = (vine < 0.032) | ((vine2 < 0.028) & (tv < 0.0) & (tv > -1.3))
    leaf = np.zeros(n, bool)
    for lu, lv in ((-1.0, -0.55), (-0.3, -0.2), (0.35, 0.15), (-0.75, -0.95), (-0.35, -1.15), (0.6, 0.35)):
        leaf |= np.hypot((tu - lu) * 1.0, (tv - lv) * 2.2) < 0.09
    flower = np.zeros(n, bool)
    hole_ = np.zeros(n, bool)
    for fu, fv, fr in ((-0.55, 0.45, 0.19), (0.05, 0.6, 0.15), (-1.05, -0.15, 0.17), (-0.2, -0.5, 0.16), (-0.6, -1.0, 0.15), (0.5, -0.2, 0.13)):
        r = np.hypot(tu - fu, tv - fv)
        a = np.arctan2(tv - fv, tu - fu)
        flower |= r < fr * (0.5 + 0.5 * np.abs(np.cos(2.5 * a)))
        hole_ |= r < fr * 0.22
    ink_t = (tat | leaf | (flower & ~hole_)) & t_on & m
    sk = np.where(ink_t[:, None], lerp(sk, srgb(112, 98, 204), 0.85 - 0.25 * smooth(0.0, 0.5, noise3(P, 0.008))), sk)
    # the face: a touch pinker, the sleepy lids violet, a dark mouth line
    fm = m & (np.linalg.norm((P - FACE_C) / (FACE_R + 0.05), axis=1) < 1.05) & (y < -0.12)
    sk = np.where(fm[:, None], lerp(sk, srgb(232, 192, 172), 0.6), sk)
    lid = fm & (z > FACE_C[2] + 0.06) & (z < FACE_C[2] + 0.13) & (np.abs(np.abs(x) - 0.095) < 0.055)
    sk = np.where(lid[:, None], lerp(sk, srgb(176, 108, 150), smooth(FACE_C[2] + 0.125, FACE_C[2] + 0.08, z)), sk)
    put(m, sk, 0.5, bump=0.25)
    spk(m, (150, 92, 50), 0.35)
    # crackle: crisp thin glaze lines over the skin (lighter on the face)
    cr = crackle(P, 0.045)
    c.draw(m & ~inside, cr, 0.0011, np.where(fm, 0.2, 0.42))
    c.draw(fm & (np.abs(z - (FACE_C[2] - 0.045 + 0.026 * (x / 0.17) ** 2 + 0.007 * x / 0.17)) < 0.01) & (np.abs(x) < 0.175),
           np.abs(z - (FACE_C[2] - 0.045 + 0.026 * (x / 0.17) ** 2 + 0.007 * x / 0.17)), 0.0022, 0.85)          # the smirk's line

    # eyes: tired yellow, a small dark pupil low under the lid, bloodshot edges
    m = c.mask(EYE)
    ey = full((228, 196, 92))
    for sx in (1.0, -1.0):
        ce = v3((0.095 * sx, -0.27, FACE_C[2] + 0.075))
        d = P - ce
        mine = m & (np.linalg.norm(d, axis=1) < 0.06)
        c.draw(mine, np.hypot(d[:, 0] - 0.003 * sx, (d[:, 2] + 0.006) * 0.85) - 0.012, 0.0)
    put(m, ey, 0.15)

    # sweatpants: faded purple fleece, two cream stripes down the outside of each leg, dusty at the cuffs
    m = c.mask(PANTS)
    pt = full((110, 66, 124))
    pt *= (1.0 + 0.1 * mott)[:, None]
    pt = lerp(pt, srgb(70, 40, 80), c.cavity * 0.6)
    pt = lerp(pt, srgb(150, 110, 150), c.wear * 0.4)
    pt = lerp(pt, srgb(150, 120, 110), smooth(0.4, 0.22, z) * 0.35)
    leg_c = np.where(z < 0.75, ANKLE[0] + (HIP[0] - ANKLE[0]) * np.clip((z - 0.12) / 0.76, 0, 1), 0.0)
    ang = np.degrees(np.arctan2(np.abs(x) - leg_c, y - 0.0))          # 90 = the outside of the leg
    for a0 in (122.0, 136.0):                                       # (0 is the back of the leg, 180 its front: the stripes run down the front-outer side)
        stripe = m & (np.abs(ang - a0) < 5.5) & (z < 1.0) & (z > 0.27) & (np.abs(x) > 0.18)
        pt = np.where(stripe[:, None], srgb(226, 206, 178), pt)
    put(m, pt, 0.9, bump=1.0)
    spk(m, (186, 140, 110), 0.22)
    put(c.mask(CORD), srgb(226, 214, 196) * (1.0 - 0.2 * c.cavity)[:, None], 0.8, bump=0.7)
    put(c.mask(HAIR), srgb(22, 18, 16), 0.55)
    m = c.mask(NAIL)
    put(m, srgb(228, 150, 150), 0.25)
    put(c.mask(STRAP), srgb(46, 40, 36), 0.55, bump=0.6, grain=1.0)
    put(c.mask(WATCH), srgb(238, 176, 30) * (1.0 + 0.4 * c.wear)[:, None], 0.35, bump=0.1)
    put(c.mask(DIAL), srgb(150, 176, 150), 0.15)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"trunk": 2100, "face": 1200, "arms": 1900, "hair": 900, "pants": 1700, "feet": 1000, "watch": 200},
    "density": {"face": 1.7, "watch": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.92, "run": 1.5},
    "speed": 0.7,
    "look": ["face"], "neck": "none",
    "look_pivot": tuple(FACE_C.tolist()),
    "radius": 0.75,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.02, 0.86), (0, 0.0, 1.1), "root", 0.3),
        Bone("spine", (0, 0.0, 1.1), (0, 0.01, 1.35), "hips", 0.32),
        Bone("chest", (0, 0.01, 1.35), (0, 0.03, 1.8), "spine", 0.36),
        Bone("face", FACE_C + v3((0, 0.06, 0)), FACE_C + v3((0, -0.2, 0)), "chest", 0.16),
        Bone("shoulder.L", (0.12, 0.03, 1.62), SHOULDER, "chest", 0.12),
        Bone("thigh.L", HIP, KNEE, "hips", 0.2),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.17),
        Bone("foot.L", ANKLE, v3((ANKLE[0], ANKLE[1], 0.03)) + FWD * 0.24, "shin.L", 0.06),
    ])
    for sd, el, wr, R, f in (("L", L_EL, L_WR, L_HAND, np.eye(3, dtype=F32)), ("R", R_EL, R_WR, R_HAND, FLIP)):
        hend = wr - R[:, 2] * 0.12
        bones += [Bone("upper_arm." + sd, f @ SHOULDER, f @ el, "shoulder." + sd, 0.13), Bone("forearm." + sd, f @ el, f @ wr, "upper_arm." + sd, 0.1),
                  Bone("hand." + sd, f @ wr, f @ hend, "forearm." + sd, 0.06)]
    return bones


def skin_rules(P, part, piece, names):
    """pieces: 0 trunk, 1 face, 2 arms, 3 hair, 4 pants, 5 feet, 6 watch"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    tp = piece == 0
    allow(tp, "hips", "spine", "chest")
    allow(tp & (x > 0.3) & (z > 1.3), "shoulder.L")
    allow(tp & (x < -0.3) & (z > 1.3), "shoulder.R")
    rig[piece == 1] = ix["face"]
    allow(piece == 1, "face")
    rig[piece == 3] = ix["chest"]
    allow(piece == 3, "chest")
    ap = piece == 2
    for s, sd, wr, R in ((1, "L", L_WR, L_HAND), (-1, "R", R_WR * v3((-1, 1, 1)), FLIP @ R_HAND)):
        m = ap & (x * s > 0)
        allow(m, "shoulder." + sd, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        allow(m & (z > 1.45) & (np.abs(x) < 0.6), "chest")
        rig[m & (((P - wr) @ (-R[:, 2])) > 0.03)] = ix["hand." + sd]
    pp = piece == 4
    allow(pp, "hips")
    allow(pp & (z > 0.95), "spine")
    legs = pp & (z < 0.9)
    allow(legs & (x > -0.05), "thigh.L", "shin.L")
    allow(legs & (x < 0.05), "thigh.R", "shin.R")
    allow(legs & (z < 0.35) & (x > 0), "foot.L")
    allow(legs & (z < 0.35) & (x < 0), "foot.R")
    rig[pp & (part == CORD)] = ix["hips"]
    fp = piece == 5
    for s, sd in ((1, "L"), (-1, "R")):
        m = fp & (x * s > 0)
        allow(m, "shin." + sd, "foot." + sd)
        rig[m & (z < 0.1)] = ix["foot." + sd]
    rig[piece == 6] = ix["forearm.L"]
    allow(piece == 6, "forearm.L")
    return A, rig


WALK = dict(stride=0.92, stance=0.66, lift=0.035, bob=0.022, drop=0.03, sway=0.055, roll=5.0, yaw=9.0, lean=-3.0, toe_off=8.0, swing=6.0)
RUN = dict(stride=1.5, stance=0.45, lift=0.09, bob=0.05, drop=0.06, sway=0.04, roll=4.0, yaw=11.0, lean=6.0, toe_off=16.0, swing=12.0)


def motions(rig):
    """walk: a heavy barefoot shuffle, feet barely leaving the ground, the bulk rolling from side to side and twisting, his fist kept on his hip,
    the free arm swinging like a weight, the face jostled in its hole; run: a lumbering jog; idle: shifting his weight, breathing,
    the face looking about, the free hand scratching his belly"""
    import math
    from kit.gait import Pose, Leg, R, solve, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], F32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    yr = math.radians(TOE_OUT)

    def foot(p, lg, ball, pitch):
        s = 1.0 if lg.side == "L" else -1.0
        fw = Vector((s * math.sin(yr), -math.cos(yr), 0.0))
        wf = Matrix.Rotation(math.radians(pitch), 3, Vector((0, 0, 1)).cross(fw))
        ankle = ball + wf @ (rig.head[lg.foot] - lg.ball)
        p.ik[lg.thigh] = (ankle, Vector((s * 0.3, -1.0, 0.0)), lg.foot, wf)

    def fist_on_hip(p):
        """his right fist stays on his hip whatever the body does"""
        A = solve(rig, p)
        Ah = A["hips"]
        w = Vector((R_WR * f).tolist())
        p.ik["upper_arm.R"] = (Ah @ w, Vector((-1.0, 0.4, 0.2)), "hand.R", Ah.to_3x3())

    def walkish(u, g, run):
        p = Pose()
        S, beta = g["stride"], g["stance"]
        sw = math.sin(TAU * u)
        p.offset = Vector((g["sway"] * sw, 0.0, -g["drop"] + g["bob"] * math.cos(2 * TAU * (u - beta * 0.5))))
        roll = g["roll"] * sw                              # the bulk rolls over the foot it stands on
        yaw = -g["yaw"] * math.cos(TAU * u)
        p.rot("hips", g["lean"] * 0.5, roll * 0.6, yaw)
        p.rot("spine", g["lean"] * 0.5, roll * 0.3, -yaw * 0.3)
        p.rot("chest", 0.0, 0.0, -yaw * 0.3)
        for lg in legs:
            s = 1.0 if lg.side == "L" else -1.0
            uu = (u + (0.0 if s > 0 else 0.5)) % 1.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                lift, pitch = 0.0, g["toe_off"] * ease((uu - (beta - 0.15)) / 0.15)
            else:
                t = (uu - beta) / (1.0 - beta)
                fy = S * beta / 2 - S * beta * ease(t)
                lift = g["lift"] * math.sin(math.pi * t) ** 0.9
                pitch = g["toe_off"] * (1.0 - ease(t * 1.6)) - g["swing"] * math.sin(math.pi * t)
            foot(p, lg, Vector((lg.ball.x * 0.95, fy - 0.03, lift)), pitch)
        # the free arm swings heavily, lagging the step; the shoulders roll
        c = math.cos(TAU * u - 0.5)
        p.rot("shoulder.L", 0.0, 0.0, 0.0)
        p.rot("upper_arm.L", (22.0 if run else 13.0) * c, 0.0, -2.0 * sw)
        p.rot("forearm.L", -(20.0 if run else 8.0) * max(0.0, c) - 4.0, 0.0, 0.0)
        p.rot("face", 2.0 * math.sin(2 * TAU * u - 1.2) + (4.0 if run else 0.0), 0.0, 3.0 * math.sin(TAU * u - 0.6))
        fist_on_hip(p)
        return p

    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    def win(t, a, b, e=0.4):
        return ease((t - a) / e) * (1.0 - ease((t - b) / e))

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        p.offset = Vector((0.035 * w, 0.0, -0.01 + 0.006 * math.sin(TAU * t / 3.0)))
        p.rot("hips", 0.0, 3.0 * w, 2.0 * math.sin(TAU * t / 6.0 + 1.0))
        p.rot("spine", 1.5 * math.sin(TAU * t / 3.0), -1.5 * w, 0.0)
        p.rot("chest", 1.0 * math.sin(TAU * t / 3.0 + 0.5), 0.0, 0.0)
        for lg in legs:
            foot(p, lg, Vector((lg.ball.x * 0.95, lg.ball.y - 0.03, 0.0)), 0.0)
        sc = win(t, 1.6, 3.2)                             # a scratch of the belly with the free hand
        p.rot("upper_arm.L", 14.0 * sc, 0.0, 16.0 * sc)
        p.rot("forearm.L", -40.0 * sc + 6.0 * sc * math.sin(TAU * t * 3.0), 0.0, 25.0 * sc)
        p.rot("face", -3.0 * win(t, 3.8, 5.0) + 1.5 * math.sin(TAU * t / 3.0), 0.0, 14.0 * win(t, 0.4, 1.4) - 12.0 * win(t, 3.8, 5.2))
        fist_on_hip(p)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
