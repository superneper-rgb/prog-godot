## FOINT CITY townsfolk: the binocular-faced snoop (binocular). A tall figure in a belted trench coat, collar up, a long pale neck, and a pair of binoculars for a face over a little pale chin.
# Upgrade of the three.js folk species "binocular" (progalpha levels/hub/folk-species-b.js; old render refs/old/binocular.png): kept the tan long coat with its dark
# belt and the belt line down the front, the collar, the long bone-pale neck and pale hands, the black binocular barrels with blue lenses on a bridge, the chin
# under the glass, the notebook at the hip, dark trousers and brown shoes. 2.00 m to the top of the binoculars.
# Rest pose: its sneaking pose, the forearms up in front of the chest, the hands hanging limp from the wrists. Moves: a slow sneaky stalk on tiptoe (each foot
# lifted high, held, set down toe first), hunched forward, the binoculars sweeping side to side; idle, it scans and fiddles with the focus wheel.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 2.00
REF = ("old/binocular.png", None)

COAT, BELT, BRASS, BUTTON, SKIN, LIP, BARREL, CHROME, LENS, CUP, TROUSERS, SHOE, SOLE, NOTE, PAPER = range(1, 16)
COLOURS = {
    COAT: ((0.72, 0.56, 0.36), 0.8, 0.0),
    BELT: ((0.36, 0.24, 0.13), 0.55, 0.0),
    BRASS: ((0.8, 0.6, 0.28), 0.3, 1.0),
    BUTTON: ((0.25, 0.16, 0.09), 0.4, 0.0),
    SKIN: ((0.86, 0.82, 0.74), 0.55, 0.0),
    LIP: ((0.6, 0.45, 0.45), 0.45, 0.0),
    BARREL: ((0.05, 0.05, 0.055), 0.6, 0.0),
    CHROME: ((0.75, 0.76, 0.78), 0.25, 1.0),
    LENS: ((0.1, 0.25, 0.45), 0.05, 0.0),
    CUP: ((0.03, 0.03, 0.03), 0.8, 0.0),
    TROUSERS: ((0.12, 0.12, 0.14), 0.8, 0.0),
    SHOE: ((0.33, 0.18, 0.09), 0.4, 0.0),
    SOLE: ((0.1, 0.08, 0.06), 0.8, 0.0),
    NOTE: ((0.3, 0.2, 0.12), 0.6, 0.0),
    PAPER: ((0.9, 0.87, 0.78), 0.8, 0.0),
}

# the head (left side +X): the barrels' axis, the lenses at their front
BZ = 1.893
BX = 0.067
B_FRONT, B_BACK = -0.135, 0.058
CHIN_C = v3((0.0, -0.045, 1.812))
SHOULDER = v3((0.198, 0.012, 1.5))
ELBOW = v3((0.272, 0.075, 1.255))
WRIST = v3((0.19, -0.215, 1.215))
FINGERS = v3((-0.16, -0.42, -0.89)) / np.linalg.norm((-0.16, -0.42, -0.89))      # the limp hand's direction from the wrist
HAND = basis(-FINGERS, v3((1, 0, 0)))                                             # fingers -Z, back of the hand +X (forward and up), thumb -Y (in)
HIP = v3((0.09, 0.01, 0.98))
KNEE = v3((0.095, -0.012, 0.54))
ANKLE = v3((0.098, 0.02, 0.095))
HEM = 0.56


class Stretch(Shape):
    """the child scaled by (sx, sy, sz) about the origin; the distance is scaled by the smallest factor (conservative, fine for meshing)"""
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


# ---------------------------------------------------------------------------------------------------- the head: binoculars over a chin

def head():
    parts = []
    for sx in (1,):
        c0, c1 = v3((sx * BX, B_BACK, BZ)), v3((sx * BX, B_FRONT, BZ))
        barrel = CappedCone(c0, c1, 0.044, 0.057, rr=0.012, part=BARREL)
        # the rubber armour's grip ribs, the chrome ring and the deep-set lens at the front, a rubber eyecup at the back
        ring = Torus(c1 + v3((0, 0.004, 0)), 0.053, 0.0055, Rm=rot(rx=90), part=CHROME)
        lens = Cut(Ellipsoid(c1 + v3((0, 0.012, 0)), (0.05, 0.012, 0.05), part=LENS), [], k=0.0)
        recess = CappedCone(c1 + v3((0, -0.02, 0)), c1 + v3((0, 0.006, 0)), 0.049, 0.049, rr=0.002)
        barrel = Cut(barrel, [recess], k=0.002)
        cup = CappedCone(c0 + v3((0, -0.01, 0)), c0 + v3((0, 0.03, 0)), 0.04, 0.038, rr=0.012, part=CUP)
        cup = Cut(cup, [CappedCone(c0 + v3((0, 0.01, 0)), c0 + v3((0, 0.05, 0)), 0.026, 0.026)], k=0.004)
        parts += [barrel, ring, lens, cup]
    eyes = Mirror(Union(parts, k=0.0))
    # the bridge: a hinge between the barrels, the ridged focus wheel on top
    hinge = CappedCone((0, 0.03, BZ + 0.028), (0, -0.09, BZ + 0.028), 0.022, 0.022, rr=0.006, part=CHROME)
    plates = Box((0, -0.03, BZ + 0.02), (0.06, 0.05, 0.012), rr=0.008, part=BARREL)
    wheel = CappedCone((-0.016, -0.02, BZ + 0.062), (0.016, -0.02, BZ + 0.062), 0.019, 0.019, rr=0.004, part=CHROME)
    # (its grip ridges are painted: sculpted ridges decimate badly)
    post = Box((0, -0.02, BZ + 0.045), (0.006, 0.01, 0.012), rr=0.003, part=CHROME)
    # the chin: pale, a little pointed, a pursed mouth; it carries the binoculars on a short stalk at the back
    chin = Union([Ellipsoid(CHIN_C + v3((0, 0.012, 0.004)), (0.05, 0.05, 0.046)), Ellipsoid(CHIN_C + v3((0, -0.026, -0.026)), (0.024, 0.026, 0.024)),
                  RoundCone(CHIN_C + v3((0, 0.03, 0.0)), (0, 0.0, BZ - 0.01), 0.038, 0.03)], k=0.03, part=SKIN)
    mouth = Union([Ellipsoid(CHIN_C + v3((0.0, -0.046, -0.004)), (0.017, 0.008, 0.0062), part=LIP),
                   Ellipsoid(CHIN_C + v3((0.0, -0.044, -0.013)), (0.014, 0.008, 0.0058), part=LIP)], k=0.004)
    mouth = Cut(mouth, [Box(CHIN_C + v3((0, -0.06, -0.0085)), (0.03, 0.02, 0.0011), rr=0.0008)], k=0.0015)
    face = Union([chin, mouth], k=0.006)
    return Union([eyes, hinge, plates, wheel, post], k=0.0), face


def neck():
    n = loft([(v3((0, 0.03, 1.56)), 0.05), (v3((0, 0.02, 1.68)), 0.044), (v3((0, -0.01, 1.79)), 0.041)], part=SKIN, k=0.02)
    adam = Ellipsoid((0, -0.035, 1.7), (0.016, 0.018, 0.022), part=SKIN)
    return Union([n, adam], k=0.02)


# ---------------------------------------------------------------------------------------------------- the coat

def torso_core():
    return Union([
        Ellipsoid((0, 0.012, 1.36), (0.168, 0.12, 0.2)),
        Ellipsoid((0, 0.016, 1.49), (0.198, 0.108, 0.06)),
        Ellipsoid((0, 0.01, 1.13), (0.15, 0.11, 0.1)),
    ], k=0.06, part=COAT)


def sleeve(elbow, wrist):
    s = Clip(loft([(SHOULDER, 0.056), (elbow, 0.05), (wrist, 0.047)], part=COAT, k=0.015), [Half(wrist, wrist - elbow)], k=0.003)
    d = (wrist - elbow) / np.linalg.norm(wrist - elbow)
    strap = Clip(Inflate(RoundCone(wrist - d * 0.08, wrist, 0.05, 0.047), 0.004, part=COAT), [Half(wrist - d * 0.03, d), Half(wrist - d * 0.055, -d)], k=0.002)
    return s, strap


def coat():
    core = torso_core()
    upper = Clip(Inflate(core, 0.016, part=COAT), [Half((0, 0, 1.07), (0, 0, -1))], k=0.006)
    pads = Mirror(Box((0.165, 0.01, 1.505), (0.05, 0.07, 0.024), rr=0.02, part=COAT))
    skirt = Stretch(CappedCone((0, 0, HEM), (0, 0, 1.18), 0.245, 0.168, rr=0.018), (1.0, 0.76, 1.0))
    skirt.part = COAT
    skirt = Clip(Union([skirt], part=COAT), [Half((0, 0, HEM), (0, 0, -1))], k=0.004)
    # the front parts below the last button: a slit up to the crotch, opening into a V at the hem
    vent = prism([(-0.006, 0.88), (0.006, 0.88), (0.055, HEM - 0.01), (-0.055, HEM - 0.01)], y0=-0.5, y1=-0.05)
    skirt = Cut(skirt, [vent], k=0.006)
    s, strap = sleeve(ELBOW, WRIST)
    sl = [s, Move(s, R=np.diag([-1, 1, 1]).astype(np.float32))]
    body = Union([upper, pads, skirt] + sl, k=0.03, part=COAT)
    body = Bump(body, lambda P: noise3(np.abs(P) * np.array([1, 1, 0.35], np.float32), 0.06), 0.003)
    # lapels: wide, notched, a thicker layer of the coat over the chest; the collar turned up round the neck
    lapel = Clip(Inflate(core, 0.026, part=COAT), [Mirror(prism([(0.01, 1.47), (0.012, 1.2), (0.13, 1.37), (0.15, 1.46), (0.125, 1.475), (0.14, 1.52), (0.06, 1.53)]))], k=0.006)
    col_out = CappedCone((0, 0.02, 1.48), (0, 0.025, 1.68), 0.115, 0.098, rr=0.012)
    col_in = CappedCone((0, 0.02, 1.4), (0, 0.025, 1.75), 0.085, 0.072, rr=0.0)
    collar = Cut(Union([col_out], part=COAT), [col_in, prism([(-0.035, 1.75), (0.035, 1.75), (0.0, 1.52)], y0=-0.5, y1=0.0)], k=0.006)
    belt = Clip(Inflate(Ellipsoid((0, 0.01, 1.13), (0.15, 0.11, 0.1)), 0.027, part=BELT), [Half((0, 0, 1.152), (0, 0, 1)), Half((0, 0, 1.108), (0, 0, -1))], k=0.003)
    buckle = Cut(Box((0, -0.14, 1.13), (0.032, 0.008, 0.028), rr=0.005, part=BRASS), [Box((0, -0.15, 1.13), (0.022, 0.02, 0.018), rr=0.003)], k=0.002)
    tail = Box((0.045, -0.14, 1.09), (0.012, 0.006, 0.05), rr=0.004, R=rot(ry=-14), part=BELT)
    epaulettes = Mirror(Union([Box((0.13, 0.01, 1.535), (0.07, 0.022, 0.006), rr=0.004, R=rot(ry=-14), part=COAT), Sphere((0.075, 0.0, 1.548), 0.009, part=BUTTON)]))
    buttons = []
    for z in (1.4, 1.3, 1.2, 0.98):
        for sx in (1, -1):
            y = float(probe_front(Inflate(core, 0.026) if z > 1.05 else skirt, sx * 0.075, z)) - 0.002
            buttons.append(CappedCone((sx * 0.075, y + 0.01, z), (sx * 0.075, y - 0.006, z), 0.014, 0.013, rr=0.004, part=BUTTON))
    flaps = Mirror(Clip(Inflate(skirt, 0.006, part=COAT), [prism([(0.1, 0.99), (0.2, 1.01), (0.205, 0.96), (0.105, 0.94)], y0=-0.5, y1=0.0)], k=0.004))
    # the notebook in the left pocket, a pencil clipped to it
    note = Box((0.205, -0.08, 0.99), (0.012, 0.045, 0.06), rr=0.005, R=rot(rx=-10, ry=-12), part=NOTE)
    pages = Box((0.205, -0.08, 0.992), (0.009, 0.043, 0.058), rr=0.002, R=rot(rx=-10, ry=-12), part=PAPER)
    pencil = RoundCone((0.215, -0.04, 0.95), (0.215, -0.05, 1.06), 0.005, 0.004, part=BRASS)
    return Union([body, lapel, collar, belt, buckle, tail, epaulettes, flaps, Mirror(strap), note, pages, pencil] + buttons, k=0.0)


def probe_front(shape, x, z, y_from=-0.5):
    ys = np.linspace(y_from, 0.2, 1400).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return ys[int(np.argmax(d < 0))]


# ---------------------------------------------------------------------------------------------------- hands and legs

def hand():
    """a long pale hand hanging limp, in hand space (wrist at the origin, fingers -Z, back of the hand +X, thumb -Y)"""
    palm = Ellipsoid((0.0, 0.0, -0.05), (0.014, 0.036, 0.05), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.024, 0.022, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.024, -0.008, 0.008, 0.024):
        L = 1.0 - abs(f) * 6
        pts = [(v3((0.0, f, -0.09)), 0.0085), (v3((-0.006, f * 1.05, -0.125 - 0.012 * L)), 0.0078), (v3((-0.018, f * 1.08, -0.155 - 0.018 * L)), 0.0068),
               (v3((-0.032, f * 1.1, -0.17 - 0.018 * L)), 0.0058)]
        parts.append(loft(pts, part=SKIN, k=0.004))
    parts.append(loft([(v3((-0.008, -0.03, -0.03)), 0.01), (v3((-0.024, -0.042, -0.065)), 0.0085), (v3((-0.036, -0.038, -0.09)), 0.007)], part=SKIN, k=0.004))
    return Union(parts, k=0.007)


def hands():
    return Mirror(place(hand(), WRIST, HAND))


def legs():
    leg = loft([(HIP, 0.07), (KNEE, 0.056), (ANKLE + v3((0, 0, 0.05)), 0.05)], part=TROUSERS, k=0.02)
    hips = Ellipsoid((0, 0.01, 1.0), (0.14, 0.1, 0.1), part=TROUSERS)
    ax = ANKLE[0]
    shoe = Union([Ellipsoid((ax, -0.06, 0.045), (0.05, 0.145, 0.045)), Ellipsoid((ax, 0.012, 0.055), (0.048, 0.07, 0.055))], k=0.03, part=SHOE)
    shoe = Clip(shoe, [Half((0, 0, 0.012), (0, 0, -1))], k=0.003)
    sole = Box((ax, -0.055, 0.008), (0.052, 0.152, 0.009), rr=0.007, part=SOLE)
    heel = Box((ax, 0.06, 0.016), (0.045, 0.04, 0.016), rr=0.006, part=SOLE)
    return Union([hips, Mirror(Union([leg, shoe, sole, heel], k=0.0))], k=0.0)


def pieces():
    glass, chin = head()        # (the pale chin is its own piece: decimated with the hard binoculars it baked black blotches)
    return [("head", glass, 0.0015), ("neck", neck(), 0.0022), ("coat", coat(), 0.003), ("hands", hands(), 0.0014), ("legs", legs(), 0.003),
            ("chin", chin, 0.0014)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    mott = noise3(P, 0.05) * 0.5 + noise3(P, 0.015) * 0.25
    grime = np.clip(noise3(P + 3.1, 0.04) * 0.8 + 0.25, 0, 1)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = rough[m] if np.ndim(rough) == 1 and np.size(rough) == n else rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, np.float32)], 1)

    # the coat: tan gabardine (a diagonal twill in the stripes), rain-spotted, darker and grubby toward the hem, seams inked, a coffee stain
    m = c.mask(COAT)
    cc = srgb(196, 152, 98) * (1.0 + 0.06 * mott)[:, None]
    cc = cc * (1.0 - 0.25 * grime * smooth(0.85, 0.56, z))[:, None]
    cc = cc + (srgb(222, 190, 140) - cc) * (c.wear * 0.3)[:, None]
    stain = np.sqrt(((x + 0.09) / 0.03) ** 2 + ((z - 1.27) / 0.024) ** 2) + 0.3 * noise3(P, 0.01)
    cc = cc + (srgb(120, 80, 44) - cc) * (smooth(1.0, 0.7, stain) * 0.45 * (y < 0))[:, None]
    put(m, cc, 0.82, bump=1.0)
    spk(m, (150, 108, 64), 0.25)
    c.strp[m, 0] = ((x + z) * 4.5)[m]
    c.strp[m, 1] = 0.22
    # seams: the skirt's front edges, the yoke across the back, a centre-back vent
    edge = m & (np.abs(Q[:, 0] - 0.006) < 0.01) & (y < -0.1) & (z < 0.88)
    c.draw(m & (y < -0.05) & (z < 1.05), np.abs(Q[:, 0] - (0.006 + (0.88 - z) * 0.18)) + 1.0 * (z > 0.88), 0.0012, 0.6)
    c.draw(m & (y > 0.05), np.abs(z - 1.42) + 1.0 * (np.abs(x) > 0.18), 0.0008, 0.5)
    c.draw(m & (y > 0.05) & (z < 0.95), np.abs(x) + 1.0 * (z > 0.95), 0.0009, 0.6)
    m = c.mask(BELT)
    put(m, srgb(96, 62, 34) + (srgb(160, 120, 80) - srgb(96, 62, 34)) * (c.wear * 0.6)[:, None], 0.5, bump=0.8, grain=1.0)
    for part, base in ((BRASS, (214, 160, 76)), (CHROME, (196, 198, 204))):
        m = c.mask(part)
        put(m, srgb(*base) * (1.0 - 0.45 * c.cavity)[:, None] * (1.0 - 0.2 * grime)[:, None], 0.28, metal=1.0, bump=0.1, grain=1.0)
    wm = c.mask(CHROME) & (z > BZ + 0.04) & (np.abs(x) < 0.02)
    c.strp[wm, 0] = (np.arctan2(z - (BZ + 0.062), y + 0.02) * 0.019 * 6.0)[wm]
    c.strp[wm, 1] = 1.0
    m = c.mask(BUTTON)
    put(m, srgb(64, 42, 26) * (1.0 + 0.5 * c.wear)[:, None], 0.35, bump=0.3, grain=1.0)
    # skin: bone-pale with a cool grey in the creases, faint freckles; the lips a dusty mauve
    m = c.mask(SKIN)
    sk = srgb(226, 216, 196) * (1.0 + 0.05 * mott)[:, None]
    sk = sk + (srgb(160, 150, 150) - sk) * (smooth(0.0, 0.6, c.cavity) * 0.5)[:, None]
    put(m, sk, 0.5, bump=0.15)
    spk(m, (190, 150, 130), 0.2)
    # knuckle creases on the fingers
    m = c.mask(LIP)
    put(m, srgb(160, 118, 120), 0.4, bump=0.1)
    cm = c.mask(SKIN, LIP) & (np.abs(z - (CHIN_C[2] - 0.0085)) < 0.004) & (y < CHIN_C[1] - 0.04) & (np.abs(x) < 0.022)
    c.draw(cm, np.abs(z - (CHIN_C[2] - 0.0085 + 0.004 * smooth(0.0, 0.02, x))), 0.0009)
    # the binoculars: black rubber armour (pebbled), chrome rings, the coated glass: deep blue going violet, an inked iris-like aperture, two glints
    m = c.mask(BARREL)
    br = srgb(26, 26, 28) + (srgb(80, 80, 84) - srgb(26, 26, 28)) * (c.wear * 0.6)[:, None]
    put(m, br, 0.65, bump=1.0, grain=1.0)
    m = c.mask(CUP)
    put(m, srgb(20, 20, 22), 0.75, bump=0.6, grain=1.0)
    m = c.mask(LENS)
    lu = Q[:, 0] - BX
    lv = z - BZ
    rr = np.sqrt(lu ** 2 + lv ** 2)
    lc = srgb(40, 70, 150) + (srgb(90, 40, 140) - srgb(40, 70, 150)) * smooth(0.0, 0.05, rr)[:, None]
    lc = lc * (1.0 - 0.5 * smooth(0.035, 0.05, rr))[:, None]
    # inside each lens: a dark pupil of the prisms, ringed by a paler iris, looking a touch to its left and down: the snoop's eyes
    pu = lu - 0.006 * np.sign(x) * 0 - 0.006
    pr = np.sqrt((lu + np.where(x > 0, -0.006, 0.006)) ** 2 + (lv + 0.004) ** 2)
    lc = lc + (srgb(120, 170, 230) - lc) * (smooth(0.03, 0.024, pr) * smooth(0.012, 0.018, pr) * 0.5)[:, None]
    c.draw(m, pr - 0.0125, 0.0)
    for gx, gz, gr in ((-0.02, 0.022, 0.009), (0.018, -0.02, 0.004)):
        gd = np.sqrt((lu * np.sign(x) - gx) ** 2 + (lv - gz) ** 2)
        lc = lc + (srgb(240, 248, 255) - lc) * smooth(gr, gr * 0.5, gd)[:, None]
    put(m, lc, 0.04)
    # trousers: charcoal wool, a crease; shoes: brown brogues, scuffed, a punched pattern on the toe
    m = c.mask(TROUSERS)
    put(m, srgb(40, 40, 46) * (1.0 + 0.08 * mott)[:, None], 0.85, bump=1.0)
    c.strp[m, 0] = (np.arctan2(y, Q[:, 0] - 0.09) * 0.06 * 3.0)[m]
    c.strp[m, 1] = 0.3
    m = c.mask(SHOE)
    sh = srgb(110, 60, 30) + (srgb(176, 122, 76) - srgb(110, 60, 30)) * (c.wear * 0.6)[:, None]
    put(m, sh, 0.35, bump=0.6, grain=1.0)
    toe = m & (y < -0.12) & (z > 0.05)
    spk(m, (60, 30, 14), 0.0)
    c.spk[toe, 3] = 0.5
    m = c.mask(SOLE)
    put(m, srgb(40, 30, 22), 0.8, bump=0.5, grain=1.0)
    m = c.mask(NOTE)
    put(m, srgb(120, 74, 40) * (1.0 + 0.4 * c.wear)[:, None], 0.6, bump=0.6, grain=1.0)
    m = c.mask(PAPER)
    put(m, srgb(232, 222, 196), 0.85, bump=0.3)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    lm = c.mask(LENS)
    c.col[lm] /= (0.35 + 0.65 * c.ao[lm])[:, None] ** 0.5
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"head": 1700, "neck": 400, "coat": 3600, "hands": 1200, "legs": 2000, "chin": 800},
    "density": {"head": 1.8, "hands": 1.2, "chin": 1.6},
    "tex": 2048,
    "stride": {"walk": 1.05, "run": 1.4},
    "speed": 0.55,
    "look": ["head"], "neck": "neck_2",
    "look_pivot": (0.0, 0.0, 1.8),
    "radius": 0.33,
}
BALL = v3((0.1, -0.1, 0.0))


def rig_bones():
    from kit.rig import Bone, mirror
    hand_end = WRIST + FINGERS * 0.18
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.01, 0.98), (0, 0.01, 1.12), "root", 0.15),
        Bone("spine", (0, 0.01, 1.12), (0, 0.012, 1.3), "hips", 0.14),
        Bone("chest", (0, 0.012, 1.3), (0, 0.02, 1.5), "spine", 0.16),
        Bone("neck_1", (0, 0.03, 1.52), (0, 0.02, 1.66), "chest", 0.045),
        Bone("neck_2", (0, 0.02, 1.66), (0, -0.005, 1.79), "neck_1", 0.042),
        Bone("head", (0, -0.005, 1.79), (0, -0.02, 1.98), "neck_2", 0.12),
        Bone("shoulder.L", (0.06, 0.012, 1.49), SHOULDER, "chest", 0.05),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.052),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.047),
        Bone("hand.L", WRIST, hand_end, "forearm.L", 0.03),
        Bone("thigh.L", HIP, KNEE, "hips", 0.07),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.055),
        Bone("foot.L", ANKLE, (0.1, -0.17, 0.02), "shin.L", 0.04),
    ])


def skin_rules(P, part, piece, names):
    """piece: 0 head (the binoculars), 1 neck, 2 coat, 3 hands, 4 legs, 5 chin"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    hp = (piece == 0) | (piece == 5)
    allow(hp, "head")
    rig[hp] = ix["head"]
    npc = piece == 1
    allow(npc, "chest", "neck_1", "neck_2", "head")
    rig[npc & (z > 1.785)] = ix["head"]
    cp = piece == 2
    torso = cp & (np.abs(x) < 0.2) & (z > 1.0)
    allow(torso, "hips", "spine", "chest")
    allow(torso & (z > 1.5) & (np.abs(x) < 0.12), "neck_1")
    allow(torso & (x > 0.15) & (z > 1.38), "shoulder.L", "upper_arm.L")
    allow(torso & (x < -0.15) & (z > 1.38), "shoulder.R", "upper_arm.R")
    # the skirt: the back and sides ride the hips; the front parts below the slit follow their thigh
    skirt = cp & (z <= 1.0) & (np.abs(x) < 0.26)
    allow(skirt, "hips")
    front = skirt & (y < -0.02) & (z < 0.9)
    allow(front & (x > 0.0), "thigh.L")
    allow(front & (x <= 0.0), "thigh.R")
    sl = cp & ~torso & ~skirt
    allow(sl & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L")
    allow(sl & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R")
    rig[cp & np.isin(part, (NOTE, PAPER))] = ix["hips"]
    hp = piece == 3
    allow(hp & (x > 0), "forearm.L", "hand.L")
    allow(hp & (x <= 0), "forearm.R", "hand.R")
    f = np.array([-1, 1, 1], np.float32)
    rig[hp & (x > 0) & ((P - WRIST) @ FINGERS > -0.004)] = ix["hand.L"]
    rig[hp & (x <= 0) & ((P - WRIST * f) @ (FINGERS * f) > -0.004)] = ix["hand.R"]
    lp = piece == 4
    allow(lp, "hips")
    allow(lp & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(lp & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    rig[lp & np.isin(part, (SHOE, SOLE)) & (z < 0.07) & (x > 0)] = ix["foot.L"]
    rig[lp & np.isin(part, (SHOE, SOLE)) & (z < 0.07) & (x <= 0)] = ix["foot.R"]
    return A, rig


def motions(rig):
    """walk: a slow sneak on tiptoe (a foot lifted high and held, carried over, set down toe first), hunched, the binoculars sweeping, the limp hands bobbing;
    run: a quick tiptoe scurry, lower; idle: crouched, scanning (a slow sweep, a stop, a double-take), fiddling with the focus wheel"""
    import math
    from kit.gait import Pose, R, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    ball_l = Vector(BALL.tolist())
    ankle_rest = Vector(ANKLE.tolist())

    def feet(p, u, S, beta, lift, tip, carry):
        """each foot by its phase: on tiptoe through the stance (heel up `tip` degrees), lifted high and held through the swing, set down toe first"""
        for s, sx in (("L", 1.0), ("R", -1.0)):
            uu = (u + (0.0 if s == "L" else 0.5)) % 1.0
            if uu < beta:
                k = uu / beta
                fy = -S * beta / 2 + S * uu
                lz = 0.0
                pitch = tip + 10.0 * (1.0 - ease(k / 0.25))
            else:
                k = (uu - beta) / (1.0 - beta)
                prog = ease((k - carry[0]) / (carry[1] - carry[0]))
                fy = S * beta / 2 - S * prog
                lz = lift * math.sin(math.pi * min(1.0, k * 1.15)) ** 0.6
                pitch = tip + 24.0 * math.sin(math.pi * k)
            wf = R(pitch, 0, sx * 4.0)
            b = Vector((sx * BALL[0], fy, lz))
            ankle = b + wf @ (Vector((sx * ANKLE[0], ANKLE[1], ANKLE[2])) - Vector((sx * BALL[0], BALL[1], BALL[2])))
            p.ik["thigh.%s" % s] = (ankle, Vector((sx * 0.15, -1.0, 0.0)), "foot.%s" % s, wf)

    def upper(p, u, hunch, sweep, bob_arm, run):
        p.rot("hips", hunch * 0.5, 0, 0)
        p.rot("spine", hunch * 0.6, 0, 0)
        p.rot("chest", hunch * 0.4, 0, 0)
        # the neck reaches forward, the binoculars kept level and sweeping
        p.rot("neck_1", -hunch * 0.6, 0, 0)
        p.world["head"] = R(-2.0, 0, sweep)
        for s, sx in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm.%s" % s, -bob_arm * sx * 0.3 - (8.0 if run else 0.0), 0, 0)
            p.rot("forearm.%s" % s, 4.0 * bob_arm * 0.2, 0, 0)
            p.rot("hand.%s" % s, 6.0 * math.sin(TAU * u * 2.0 + (0.0 if sx > 0 else 1.0)), 0, 0)

    def stalk(u):
        p = Pose()
        S, beta = 1.05, 0.55
        feet(p, u, S, beta, 0.2, 16.0, (0.15, 0.85))
        b = math.cos(2 * TAU * (u - beta * 0.5))
        p.offset = Vector((0.018 * math.sin(TAU * u), 0.0, -0.09 + 0.012 * b))
        p.rot("hips", 0, -2.0 * math.sin(TAU * u), -3.0 * math.cos(TAU * u))
        upper(p, u, 16.0, 26.0 * math.sin(TAU * u), 6.0 * math.cos(TAU * u), False)
        return p

    def scurry(u):
        p = Pose()
        S, beta = 1.4, 0.42
        feet(p, u, S, beta, 0.13, 26.0, (0.1, 0.9))
        b = math.cos(2 * TAU * (u - beta * 0.5))
        p.offset = Vector((0.012 * math.sin(TAU * u), 0.0, -0.13 + 0.02 * b))
        upper(p, u, 26.0, 8.0 * math.sin(TAU * u), 10.0 * math.cos(TAU * u), True)
        return p

    walk = [stalk(i / 32.0) for i in range(33)]
    run = [scurry(i / 24.0) for i in range(25)]

    idle = []
    sweep_keys = [(0.0, 0.0), (0.8, 0.0), (1.8, 42.0), (2.3, 42.0), (2.7, -30.0), (2.85, -30.0), (2.95, -36.0), (3.6, -36.0), (4.4, 0.0), (6.0, 0.0)]

    def sweep_at(t):
        for (t0, a0), (t1, a1) in zip(sweep_keys[:-1], sweep_keys[1:]):
            if t0 <= t <= t1:
                return a0 + (a1 - a0) * ease((t - t0) / max(t1 - t0, 1e-6))
        return 0.0
    for i in range(181):
        t = i / 30.0
        p = Pose()
        for s, sx in (("L", 1.0), ("R", -1.0)):
            wf = R(0, 0, sx * 6.0)
            b = Vector((sx * 0.13, -0.1 if s == "L" else 0.02, 0.0))
            ankle = b + wf @ (Vector((sx * ANKLE[0], ANKLE[1], ANKLE[2])) - Vector((sx * BALL[0], BALL[1], BALL[2])))
            p.ik["thigh.%s" % s] = (ankle, Vector((sx * 0.25, -1.0, 0.0)), "foot.%s" % s, wf)
        p.offset = Vector((0.0, 0.0, -0.06 + 0.006 * math.sin(TAU * t / 3.0)))
        sw = sweep_at(t)
        upper(p, t, 12.0 + 2.0 * math.sin(TAU * t / 3.0), sw, 2.0 * math.sin(TAU * t / 3.0), False)
        p.world["head"] = R(-3.0 + 4.0 * math.sin(TAU * t / 6.0), 0, sw)
        # the right hand goes up to the focus wheel (4.4-5.6 s) and turns it
        fz = ease((t - 4.3) / 0.4) * (1.0 - ease((t - 5.4) / 0.5))
        if fz > 0.01:
            wheel = Vector((0.0, -0.02, BZ + 0.062))
            hw = R(0, 0, sw) @ (wheel - Vector((0.0, -0.005, 1.79))) + Vector((0.0, -0.005, 1.79))
            wr_rest = Vector((WRIST * f).tolist())
            tgt = wr_rest.lerp(hw + Vector((-0.06, -0.09, 0.03)), fz) + Vector((0.0, 0.0, 0.006 * math.sin(TAU * t * 3.0) * fz))
            p.ik["upper_arm.R"] = (tgt, Vector((-0.8, 0.3, -0.5)).normalized(), "hand.R", None)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
