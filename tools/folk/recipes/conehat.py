## FOINT CITY townsfolk: the cloaked glider under the cone hat (conehat). A heavy patched wool cloak to the ground, a hood with nothing in it but two red glowing eye slits, a tall red cone hat with a floppy brim and a bent tip; black-gloved hands clasped in the cloak's opening.
# Upgrade of the three.js folk species "conehat" (progalpha levels/hub/folk-species-b.js; old render refs/old/conehat.png): kept the taupe knit bell of a cloak and
# its broad shoulders, the darker plaid trim at the hem, the black hood with two red eye slits, the wide red brim and the tall red cone with a white patch
# on its front, the black hands. The old model's feet are gone: it glides. 1.80 m to the hat's tip.
# Moves: a glide, bobbing gently, the cloak's hem rippling and trailing behind (eight hem bones, a wave running round them), the hat's tip lagging.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.80
REF = ("old/conehat.png", None)

WOOL, PLAID, HOOD, VOID, GLOW, FELT, BRIM, BAND, PATCH, GLOVE, CLASP = range(1, 12)
COLOURS = {
    WOOL: ((0.36, 0.3, 0.27), 0.9, 0.0),
    PLAID: ((0.28, 0.22, 0.2), 0.9, 0.0),
    HOOD: ((0.08, 0.08, 0.09), 0.9, 0.0),
    VOID: ((0.01, 0.01, 0.012), 0.9, 0.0),
    GLOW: ((1.0, 0.15, 0.1), 0.3, 0.0),
    FELT: ((0.62, 0.12, 0.1), 0.85, 0.0),
    BRIM: ((0.52, 0.1, 0.08), 0.85, 0.0),
    BAND: ((0.15, 0.08, 0.06), 0.6, 0.0),
    PATCH: ((0.92, 0.9, 0.84), 0.8, 0.0),
    GLOVE: ((0.04, 0.04, 0.045), 0.5, 0.0),
    CLASP: ((0.75, 0.55, 0.25), 0.3, 1.0),
}

HEAD_C = v3((0.0, 0.0, 1.14))
EYE_Z = 1.13
HAT_Z = 1.285
TIP = [v3((0.0, 0.0, HAT_Z)), v3((0.0, 0.01, 1.48)), v3((0.0, 0.04, 1.63)), v3((0.0, 0.1, 1.74)), v3((0.0, 0.165, 1.775))]
N_HEM = 8
HEM_TOP = 0.62


class Stretch(Shape):
    """the child scaled by (sx, sy, sz) about the origin; distance scaled by the smallest factor (conservative)"""
    def __init__(self, child, s):
        self.child, self.s = child, np.asarray(s, np.float32)
        lo, hi = child.bound()
        self.lo, self.hi = lo * self.s, hi * self.s
        self.part = child.part

    def eval(self, P):
        d, pt = self.child.eval(P / self.s)
        return d * float(self.s.min()), pt

    def dist(self, P):
        return self.eval(P)[0]


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def bell():
    """the cloak's volume: a bell from the shoulders to the ground, a little flattened front to back"""
    b = loft([(v3((0, 0, 0.12)), 0.35), (v3((0, 0, 0.45)), 0.315), (v3((0, 0, 0.72)), 0.26), (v3((0, 0, 0.9)), 0.17)], k=0.08)
    sh = Ellipsoid((0, 0.0, 0.9), (0.24, 0.2, 0.09))
    return Stretch(Union([b, sh], k=0.08), (1.0, 0.86, 1.0))


def folds(P):
    """big drapery folds running down the cloak, deeper toward the hem (seven round it: broad, so the decimator keeps them)"""
    a = np.arctan2(P[:, 0], -P[:, 1])
    a = np.abs(a)
    return (0.5 + 0.5 * np.cos(a * 7.0 / 2.0 * 2.0)) * np.clip((0.75 - P[:, 2]) / 0.6, 0.0, 1.0)


def cloak():
    c = Clip(Union([bell()], part=WOOL), [Half((0, 0, 0.012), (0, 0, -1))], k=0.006)
    c = Bump(c, folds, 0.016)
    # (no opening: the hands come out of two bell-sleeve cuffs clasped in front; a dark slit read as a necktie)
    trim = Clip(Inflate(bell(), 0.006, part=PLAID), [Half((0, 0, 0.11), (0, 0, 1)), Half((0, 0, 0.012), (0, 0, -1))], k=0.004)
    trim = Bump(trim, folds, 0.016)
    clasp = Union([Sphere((0.0, -0.205, 0.86), 0.02, part=CLASP), Mirror(Torus((0.03, -0.2, 0.86), 0.014, 0.004, Rm=rot(rx=90), part=CLASP))], k=0.0)
    # the hood: a heavy cowl round a black void
    hood = Union([Ellipsoid(HEAD_C + v3((0, 0.02, 0.0)), (0.16, 0.165, 0.17)), Ellipsoid((0, 0.02, 0.985), (0.22, 0.18, 0.07))], k=0.07, part=HOOD)
    face_cut = Ellipsoid(HEAD_C + v3((0, -0.14, -0.01)), (0.105, 0.1, 0.12))
    hood = Cut(hood, [face_cut], k=0.012)
    void = Ellipsoid(HEAD_C + v3((0, 0.03, -0.01)), (0.1, 0.1, 0.12), part=VOID)          # deep in the hood: the dark it looks out of
    eyes = Mirror(Ellipsoid((0.045, -0.062, EYE_Z), (0.026, 0.01, 0.0075), R=rot(ry=-12, rz=-6), part=GLOW))
    return Union([c, trim, clasp, Union([hood, void], k=0.0), eyes], k=0.0)


def hat():
    cone = loft([(TIP[0], 0.2), (TIP[1], 0.135), (TIP[2], 0.075), (TIP[3], 0.032), (TIP[4], 0.018)], part=FELT, k=0.03)
    cone = Clip(cone, [Half((0, 0, HAT_Z - 0.01), (0, 0, -1))], k=0.004)

    def dents(P):
        return noise3(P, 0.06)
    cone = Bump(cone, dents, 0.003)
    band = Clip(Inflate(loft([(TIP[0], 0.2), (TIP[1], 0.135)]), 0.008, part=BAND), [Half((0, 0, HAT_Z + 0.055), (0, 0, 1)), Half((0, 0, HAT_Z + 0.008), (0, 0, -1))], k=0.003)
    return Union([droop_brim(), cone, band], k=0.0)


def droop_brim():
    """the floppy brim: a disc whose edge sags (the sag a function of the radius, applied by bending the distance field)"""
    class Sag(Shape):
        def __init__(self):
            self.lo, self.hi = v3((-0.36, -0.36, HAT_Z - 0.1)), v3((0.36, 0.36, HAT_Z + 0.05))
            self.part = BRIM

        def eval(self, P):
            r = np.sqrt(P[:, 0] ** 2 + P[:, 1] ** 2)
            a = np.arctan2(P[:, 1], P[:, 0])
            sag = 0.055 * np.clip((r - 0.17) / 0.16, 0, 1) ** 2 * (1.0 + 0.35 * np.cos(a * 3.0 + 0.5))
            Q = P.copy()
            Q[:, 2] = P[:, 2] + sag
            d = (np.sqrt(np.maximum(r - 0.315, 0.0) ** 2 + np.maximum(np.abs(Q[:, 2] - HAT_Z) - 0.0045, 0.0) ** 2)
                 + np.minimum(np.maximum(r - 0.315, np.abs(Q[:, 2] - HAT_Z) - 0.0045), 0.0)) - 0.004
            return d * 0.85, np.full(len(P), BRIM, np.int16)

        def dist(self, P):
            return self.eval(P)[0]
    return Sag()


def hands():
    """two black-gloved hands clasped in the cloak's opening, the right over the left"""
    parts = []
    for sx, dz in ((1, -0.004), (-1, 0.012)):
        palm = Ellipsoid((sx * 0.03, -0.235, 0.62 + dz), (0.035, 0.028, 0.03), R=rot(rz=sx * 20), part=GLOVE)
        fingers = loft([(v3((sx * 0.01, -0.255, 0.625 + dz)), 0.014), (v3((-sx * 0.03, -0.26, 0.62 + dz)), 0.013), (v3((-sx * 0.05, -0.245, 0.612 + dz)), 0.012)], part=GLOVE, k=0.006)
        cuff = Cut(CappedCone((sx * 0.1, -0.19, 0.645), (sx * 0.05, -0.235, 0.63), 0.05, 0.056, rr=0.01, part=WOOL),
                   [CappedCone((sx * 0.07, -0.215, 0.638), (sx * 0.04, -0.25, 0.63), 0.035, 0.04)], k=0.006)        # a bell-sleeve cuff
        parts += [palm, fingers, cuff]
    return Union(parts, k=0.008)


def pieces():
    return [("cloak", cloak(), 0.003), ("hat", hat(), 0.0022), ("hands", Move(hands(), t=(0.0, -0.045, 0.0)), 0.0016)]      # (out in front of the cloak)


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.05) * 0.5 + noise3(P, 0.015) * 0.25
    grime = np.clip(noise3(P + 3.1, 0.05) * 0.8 + 0.25, 0, 1)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = rough[m] if np.ndim(rough) == 1 and np.size(rough) == n else rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, np.float32)], 1)

    # wool: taupe, heathered, darker in the folds' valleys, dust and mud rising from the hem; two darned patches; a frayed, darker hem
    m = c.mask(WOOL)
    wc = srgb(118, 100, 90) * (1.0 + 0.08 * mott)[:, None]
    wc = wc * (1.0 - 0.35 * grime * smooth(0.4, 0.05, z))[:, None]
    wc = wc + (srgb(160, 140, 128) - wc) * (c.wear * 0.35)[:, None]
    put(m, wc, 0.95, bump=1.0)
    spk(m, (84, 70, 64), 0.35)
    for (px, pz, pw, ph, col) in ((0.2, 0.42, 0.05, 0.06, (92, 96, 70)), (-0.17, 0.7, 0.045, 0.04, (110, 80, 70))):
        pm = m & (np.abs(x - px) < pw) & (np.abs(z - pz) < ph) & (y < 0.05)
        c.col[pm] = (srgb(*col) * (1.0 + 0.08 * mott)[:, None])[pm]
        c.strp[pm, 0] = (z * 3.0)[pm]
        c.strp[pm, 1] = 0.6
        c.draw(m & (np.abs(x - px) < pw + 0.006) & (np.abs(z - pz) < ph + 0.006) & (y < 0.05),
               np.abs(np.maximum(np.abs(x - px) - pw, np.abs(z - pz) - ph)) + 0.0012 * (np.sin((x + z) * 700) > 0.3), 0.0007, 0.7)
    # the plaid: a dark brown tartan, frayed at its edge
    m = c.mask(PLAID)
    a = np.arctan2(x, -y) * 0.33
    pl = srgb(82, 64, 56)
    pl = pl + (srgb(130, 60, 48) - pl) * ((np.abs(((a * 1.0) % 0.06) - 0.03) < 0.006) | (np.abs(((z) % 0.06) - 0.03) < 0.006))[:, None] * 0.6
    pl = pl + (srgb(40, 34, 30) - pl) * ((np.abs(((a + 0.015) % 0.06) - 0.03) < 0.012) & (np.abs(((z + 0.015) % 0.06) - 0.03) < 0.012))[:, None] * 0.5
    put(m, pl * (1.0 - 0.3 * grime)[:, None], 0.95, bump=1.0)
    c.draw(m, np.abs(z - 0.106) + 0.003 * np.abs(np.sin(a * 300)), 0.0012, 0.6)
    # the hood and the void: black wool, and inside it nothing; the eyes burn red-orange, white at the core, a red bloom round them
    m = c.mask(HOOD)
    hc = srgb(74, 62, 58) * (1.0 + 0.08 * mott)[:, None]
    hc = hc * (1.0 - 0.6 * smooth(0.0, 0.5, c.cavity))[:, None] * (0.4 + 0.6 * c.ao)[:, None]
    put(m, hc + (srgb(120, 104, 96) - hc) * (c.wear * 0.4)[:, None], 0.95, bump=1.0)
    spk(m, (50, 42, 40), 0.3)
    m = c.mask(VOID)
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    ed = np.sqrt(((Q[:, 0] - 0.045) / 0.042) ** 2 + ((z - EYE_Z) / 0.022) ** 2)
    vc = srgb(4, 3, 4) + (srgb(120, 12, 8) - srgb(4, 3, 4)) * (smooth(1.6, 0.6, ed) * 0.8)[:, None]
    put(m, vc, 0.95)
    m = c.mask(GLOW)
    gd = np.sqrt(((Q[:, 0] - 0.045) / 0.026) ** 2 + ((z - EYE_Z) / 0.0075) ** 2)
    gc = srgb(255, 60, 30) + (srgb(255, 236, 200) - srgb(255, 60, 30)) * smooth(0.9, 0.2, gd)[:, None]
    put(m, gc, 0.3)
    # the hat: red felt, crushed and faded on the crown and the tip, a dark band, the white patch sewn on its front with big stitches
    m = c.mask(FELT, BRIM)
    fc = srgb(170, 34, 28) * (1.0 + 0.1 * mott)[:, None]
    fc = fc + (srgb(200, 90, 70) - fc) * (c.wear * 0.4 + smooth(1.6, 1.78, z) * 0.25)[:, None]
    fc = fc * (1.0 - 0.3 * c.cavity)[:, None]
    put(m, fc, 0.9, bump=0.9)
    spk(m, (120, 22, 18), 0.3)
    m = c.mask(FELT)
    pq = np.sqrt((x / 0.05) ** 2 + ((z - 1.44) / 0.04) ** 2)
    patch = m & (pq < 1.0) & (y < 0)
    c.col[patch] = srgb(236, 230, 214)
    c.draw(m & (pq < 1.25) & (y < 0), np.abs(pq - 1.0) * 0.04 + 0.002 * (np.sin(np.arctan2(z - 1.44, x) * 12.0) > 0.0), 0.0012, 0.75)
    m = c.mask(BAND)
    put(m, srgb(44, 24, 18) + (srgb(90, 60, 40) - srgb(44, 24, 18)) * (c.wear * 0.6)[:, None], 0.6, bump=0.5, grain=1.0)
    m = c.mask(GLOVE)
    put(m, srgb(24, 24, 28) + (srgb(90, 90, 96) - srgb(24, 24, 28)) * (c.wear * 0.6)[:, None], 0.45, bump=0.6, grain=1.0)
    m = c.mask(CLASP)
    put(m, srgb(214, 160, 76) * (1.0 - 0.45 * c.cavity)[:, None], 0.3, metal=1.0)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    gm = c.mask(GLOW, VOID)
    c.col[gm] /= (0.35 + 0.65 * c.ao[gm])[:, None] ** 0.9
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"cloak": 5200, "hat": 2400, "hands": 900},
    "density": {"cloak": 0.9, "hat": 1.1, "hands": 1.0},
    "tex": 2048,
    "stride": {"walk": 1.2, "run": 2.0},
    "speed": 0.8,
    "look": ["head", "hat", "hat_tip"], "neck": "neck",
    "look_pivot": (0.0, 0.0, 1.0),
    "radius": 0.36,
}


def hem_dir(i):
    a = i / N_HEM * 2 * np.pi
    return v3((np.sin(a), -np.cos(a), 0.0))          # i = 0 is the front (-Y), counting toward its left (+X)


def rig_bones():
    from kit.rig import Bone
    bones = [
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0, 0.5), (0, 0, 0.75), "root", 0.25),
        Bone("chest", (0, 0, 0.75), (0, 0, 0.95), "hips", 0.22),
        Bone("hands", (0, -0.2, 0.62), (0, -0.3, 0.62), "chest", 0.04),
        Bone("neck", (0, 0, 0.95), (0, 0, 1.03), "chest", 0.1),
        Bone("head", (0, 0, 1.03), (0, 0, HAT_Z), "neck", 0.15),
        Bone("hat", TIP[0], TIP[2], "head", 0.1),
        Bone("hat_tip", TIP[2], TIP[4], "hat", 0.04),
    ]
    for i in range(N_HEM):
        d = hem_dir(i)
        bones.append(Bone("hem_%d" % i, d * np.array([0.25, 0.22, 0], np.float32) + v3((0, 0, HEM_TOP)), d * np.array([0.35, 0.3, 0], np.float32) + v3((0, 0, 0.02)), "hips", 0.02))
    return bones


def skin_rules(P, part, piece, names):
    """piece: 0 cloak (with hood and eyes), 1 hat, 2 hands"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    cp = piece == 0
    head = cp & np.isin(part, (HOOD, VOID, GLOW))
    allow(head, "neck", "head", "chest")
    rig[head & (z > 1.04)] = ix["head"]
    rig[cp & np.isin(part, (VOID, GLOW))] = ix["head"]
    body = cp & ~head
    allow(body & (z > 0.45), "hips", "chest")
    rig[body & np.isin(part, (CLASP,))] = ix["chest"]
    # the lower cloak: its two nearest hem bones by angle, and the hips above
    ang = np.arctan2(x, -y) % (2 * np.pi)
    k = ang / (2 * np.pi) * N_HEM
    i0 = np.floor(k).astype(int) % N_HEM
    i1 = (i0 + 1) % N_HEM
    low = body & (z < HEM_TOP + 0.12)
    allow(low, "hips")
    for i in range(N_HEM):
        A[low & ((i0 == i) | (i1 == i)), ix["hem_%d" % i]] = True
    hp = piece == 1
    allow(hp, "head", "hat", "hat_tip")
    rig[hp & (z < HAT_Z + 0.06)] = ix["head"]
    rig[hp & (z > 1.66)] = ix["hat_tip"]
    rig[piece == 2] = ix["hands"]
    return A, rig


def motions(rig):
    """walk: a glide (bobbing, leaning a little in, the hem trailing and a ripple running round it, the hat's tip lagging);
    run: a swift glide, low and leaning, the hem streaming; idle: hovering, breathing, looking about, the hem stirring"""
    import math
    from kit.gait import Pose, R, TAU, ease
    from mathutils import Vector, Matrix

    def hem(p, u, trail, wave, freq):
        """each hem bone flares out by the travelling wave and is swept back by the trail"""
        for i in range(N_HEM):
            d = hem_dir(i)
            t = Vector((-d[1], d[0], 0.0))       # its tangent: rotating about it flares the hem bone out
            phase = TAU * (u * freq) - i * TAU / N_HEM * 2.0
            flare = wave * math.sin(phase)
            back = trail * (-d[1])                # the front bones fold in under, the back ones flare out: the hem streams behind
            p.delta["hem_%d" % i] = Matrix.Rotation(math.radians(flare + back), 3, t)

    def glide(u, run):
        p = Pose()
        bob = math.sin(2 * TAU * u)
        p.offset = Vector((0.006 * math.sin(TAU * u), 0.0, 0.012 + (0.02 if run else 0.014) * bob))
        lean = 9.0 if run else 4.0
        p.rot("hips", lean + 1.5 * math.cos(2 * TAU * u), 2.0 * math.sin(TAU * u), 0)
        p.rot("chest", 1.0 * math.sin(2 * TAU * u - 0.8), 0, 0)
        p.world["head"] = R((3.0 if run else 0.0) + 1.5 * math.sin(2 * TAU * u - 1.2), 0, 2.0 * math.sin(TAU * u))
        p.rot("hat", -(8.0 if run else 3.0) - 3.0 * math.sin(2 * TAU * u - 1.8), 0, 0)
        p.rot("hat_tip", -(16.0 if run else 6.0) - 6.0 * math.sin(2 * TAU * u - 2.4), 0, 4.0 * math.sin(TAU * u - 1.0))
        hem(p, u, 14.0 if run else 7.0, 6.0 if run else 4.0, 2.0)
        p.rot("hands", 2.0 * math.sin(2 * TAU * u), 0, 0)
        return p

    walk = [glide(i / 32.0, False) for i in range(33)]
    run = [glide(i / 24.0, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        p.offset = Vector((0.0, 0.0, 0.012 + 0.012 * math.sin(TAU * t / 2.0)))
        p.rot("hips", 0.8 * math.sin(TAU * t / 3.0), 0, 0)
        p.rot("chest", 1.2 * math.sin(TAU * t / 3.0 + 0.6), 0, 0)
        look = 30.0 * ease((t - 1.0) / 0.8) * (1.0 - ease((t - 2.6) / 0.6)) - 24.0 * ease((t - 3.3) / 0.7) * (1.0 - ease((t - 5.0) / 0.8))
        tilt = 8.0 * ease((t - 3.8) / 0.4) * (1.0 - ease((t - 4.8) / 0.4))
        p.world["head"] = R(0, tilt, look)
        p.rot("hat", -2.0 * math.sin(TAU * t / 3.0 - 1.0), 0, 0)
        p.rot("hat_tip", -4.0 * math.sin(TAU * t / 3.0 - 1.6), 0, 3.0 * math.sin(TAU * t / 6.0))
        hem(p, t / 6.0, 0.0, 3.0, 3.0)
        p.rot("hands", 1.5 * math.sin(TAU * t / 3.0), 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
