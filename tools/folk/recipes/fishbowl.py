## FOINT CITY townsfolk: the fishbowl astronaut (fishbowl). A small puffy spacesuit with a water-filled fishbowl for a helmet; the pilot is the goldfish swimming in it.
# Upgrade of the three.js folk species "fishbowl" (progalpha levels/hub/folk-species-b.js; old render refs/old/fishbowl.png): kept the cream puffy suit, the
# burnt-orange collar and arms, the blue chest panel with its green light, the grey life-support pack, the brown-grey boots, the round water-filled bowl
# with an orange goldfish and the fish food sprinkled on the water at the open top. The carried box is dropped. 1.20 m to the bowl's lip.
# Glass is opaque in the game (no transparency in the folk shader): the bowl is painted with the water, gravel and weed inside it (rays cast in from the
# glass), and the goldfish is a thin relief riding just proud of the glass on its own bone, so it really swims round the bowl.
# Moves: a bouncy low-gravity lope (long floaty hangs between steps, arms drifting out for balance); the fish sloshes, circles the bowl when idle.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.20
REF = ("old/fishbowl.png", None)

GLASS, WATER, FISH, FIN, SUIT, ORANGE, PANEL, LIGHT, STEEL, BRASS, PACK, TANK, HOSE, BOOT, SOLE, GLOVE, BELT = range(1, 18)
COLOURS = {
    GLASS: ((0.55, 0.8, 0.85), 0.05, 0.0),
    WATER: ((0.4, 0.7, 0.75), 0.1, 0.0),
    FISH: ((1.0, 0.45, 0.08), 0.3, 0.0),
    FIN: ((1.0, 0.35, 0.05), 0.3, 0.0),
    SUIT: ((0.80, 0.75, 0.63), 0.8, 0.0),
    ORANGE: ((0.65, 0.3, 0.14), 0.75, 0.0),
    PANEL: ((0.18, 0.3, 0.45), 0.4, 0.0),
    LIGHT: ((0.3, 1.0, 0.5), 0.2, 0.0),
    STEEL: ((0.6, 0.62, 0.64), 0.3, 1.0),
    BRASS: ((0.75, 0.55, 0.25), 0.3, 1.0),
    PACK: ((0.45, 0.46, 0.47), 0.5, 0.0),
    TANK: ((0.75, 0.76, 0.78), 0.25, 1.0),
    HOSE: ((0.15, 0.15, 0.16), 0.6, 0.0),
    BOOT: ((0.42, 0.36, 0.26), 0.8, 0.0),
    SOLE: ((0.12, 0.11, 0.1), 0.9, 0.0),
    GLOVE: ((0.85, 0.8, 0.68), 0.7, 0.0),
    BELT: ((0.15, 0.15, 0.17), 0.5, 0.0),
}

HC = v3((0.0, -0.005, 0.985))         # the bowl's centre
RG = 0.205                            # its radius
TOP = 1.166                           # the open top (the water's surface, up to the brim)
SHOULDER = v3((0.205, 0.012, 0.735))
ELBOW = v3((0.268, 0.024, 0.585))
WRIST = v3((0.29, -0.012, 0.455))
HIP = v3((0.088, 0.01, 0.40))
KNEE = v3((0.092, -0.008, 0.245))
ANKLE = v3((0.094, 0.012, 0.098))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
# the goldfish: where it rests on the bowl (its centre's direction from HC), its frame (x along its body to its head, y up, z out of the glass)
FISH_DIR = v3((0.36, -0.93, 0.06)) / np.linalg.norm((0.36, -0.93, 0.06))
_t = -np.cross(v3((0, 0, 1)), FISH_DIR)
_t /= np.linalg.norm(_t)
_v = np.cross(FISH_DIR, _t)
FISH_R = np.stack([_t, -_v if _v[2] < 0 else _v, FISH_DIR], 1).astype(np.float32)
FISH_C = HC + FISH_DIR * RG


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


class Scaled(Shape):
    """a shape scaled uniformly about the origin (the kit has no scale; exact for a uniform factor)"""
    def __init__(self, child, s):
        self.child, self.s = child, np.float32(s)
        lo, hi = child.bound()
        self.lo, self.hi = lo * self.s, hi * self.s
        self.part = child.part

    def eval(self, P):
        d, pt = self.child.eval(P / self.s)
        return d * self.s, pt

    def dist(self, P):
        return self.eval(P)[0]


# ---------------------------------------------------------------------------------------------------- the bowl and the fish

def bowl():
    glass = Clip(Sphere(HC, RG, part=GLASS), [Half((0, 0, TOP), (0, 0, 1))], k=0.004)
    water = Clip(Sphere(HC, RG - 0.006, part=WATER), [Half((0, 0, TOP + 0.002), (0, 0, 1))], k=0.0)
    glass = Union([glass, water], k=0.0)
    ro = float(np.sqrt(RG ** 2 - (TOP - HC[2]) ** 2))
    lip = Torus((0, HC[1], TOP + 0.002), ro - 0.004, 0.0115, part=GLASS)
    return Union([glass, lip], k=0.006)


def fish_outline():
    """the goldfish's outline in its own frame (metres): a plump body, a forked fan tail, a dorsal fin, a belly fin"""
    a = np.linspace(0, 2 * np.pi, 22, endpoint=False)
    body = [(0.012 + 0.052 * np.cos(t) * (1.0 if np.cos(t) > 0 else 0.92), 0.0 + 0.036 * np.sin(t) * (1.0 if np.sin(t) > 0 else 0.92)) for t in a]
    tail = [(-0.03, 0.01), (-0.075, 0.05), (-0.098, 0.044), (-0.08, 0.004), (-0.1, -0.04), (-0.074, -0.044), (-0.03, -0.012)]
    dorsal = [(0.022, 0.03), (-0.004, 0.056), (-0.03, 0.05), (-0.032, 0.022)]
    belly = [(-0.004, -0.028), (-0.022, -0.05), (-0.036, -0.044), (-0.03, -0.022)]
    return body, tail, dorsal, belly


def fish():
    """a relief of the goldfish riding 2-8 mm proud of the glass (its back buried in it): plump in the body, flat in the fins"""
    body, tail, dorsal, belly = fish_outline()
    out = []
    for poly, part in ((body, FISH), (tail, FIN), (dorsal, FIN), (belly, FIN)):
        out.append(Slab(FISH_C, poly, 0.03, rr=0.002, R=FISH_R, part=part))
    plate = Union(out, k=0.004)

    def dome(P):
        q = (P - FISH_C) @ FISH_R
        e = 1.0 - ((q[:, 0] - 0.012) / 0.052) ** 2 - (q[:, 1] / 0.036) ** 2
        return np.sqrt(np.clip(e, 0.0, 1.0))
    top = Bump(Sphere(HC, RG + 0.0028), dome, 0.0055)
    shell = Cut(Clip(plate, [top], k=0.0015), [Sphere(HC, RG - 0.003)], k=0.0)
    # the eye: a little bead near its head; the lips: a pout at its nose
    eye_at = FISH_C + FISH_R @ v3((0.038, 0.008, 0.0))
    eye = Sphere(eye_at + FISH_DIR * (0.0072), 0.0068, part=FISH)
    lips = Ellipsoid(FISH_C + FISH_R @ v3((0.062, -0.004, 0.0)) + FISH_DIR * 0.0035, (0.007, 0.006, 0.006), part=FISH)
    return Union([shell, eye, lips], k=0.002)


# ---------------------------------------------------------------------------------------------------- the suit

def torso_core():
    return Union([
        Ellipsoid((0, 0.012, 0.6), (0.198, 0.165, 0.2)),
        Ellipsoid((0, 0.015, 0.73), (0.205, 0.15, 0.075)),
        Ellipsoid((0, 0.008, 0.47), (0.17, 0.14, 0.08)),
    ], k=0.05, part=SUIT)


def quilt(P):
    """puffy quilting: soft pillows between horizontal seams every 7 cm (soft valleys: sharp sculpted creases decimate badly)"""
    return 0.5 - 0.5 * np.cos((P[:, 2] - 0.43) * np.pi * 2 / 0.07)


def torso():
    core = Bump(torso_core(), quilt, 0.004)
    collar = Union([CappedCone((0, 0.0, 0.775), (0, 0.0, 0.83), 0.165, 0.158, rr=0.012, part=STEEL),
                    Torus((0, 0.0, 0.79), 0.168, 0.03, part=ORANGE)], k=0.0)
    panel = Box((0, -0.168, 0.615), (0.088, 0.024, 0.062), rr=0.016, R=rot(rx=-8), part=PANEL)
    light = Sphere((0.05, -0.19, 0.645), 0.0115, part=LIGHT)
    button = CappedCone((-0.05, -0.183, 0.645), (-0.05, -0.198, 0.645), 0.011, 0.01, rr=0.003, part=ORANGE)
    dials = [CappedCone((x, -0.18, 0.592), (x, -0.196, 0.592), 0.016, 0.014, rr=0.004, part=STEEL) for x in (-0.042, 0.0, 0.042)]
    belt = Clip(Inflate(Ellipsoid((0, 0.008, 0.47), (0.17, 0.14, 0.08)), 0.012, part=BELT), [Half((0, 0, 0.495), (0, 0, 1)), Half((0, 0, 0.452), (0, 0, -1))], k=0.003)
    buckle = Box((0, -0.162, 0.474), (0.03, 0.008, 0.022), rr=0.006, part=BRASS)
    return Union([core, collar, panel, light, button, belt, buckle] + dials, k=0.0)


def sleeves():
    s = loft([(SHOULDER, 0.062), (ELBOW, 0.057), (WRIST + (ELBOW - WRIST) * 0.12, 0.054)], part=ORANGE, k=0.02)
    s = Bump(s, lambda P: np.exp(-(np.linalg.norm(np.abs(P) * np.array([1, 1, 1], np.float32) - ELBOW, axis=1) / 0.06) ** 2) * (0.5 - 0.5 * np.cos(((np.abs(P) - ELBOW) @ ((WRIST - SHOULDER) / np.linalg.norm(WRIST - SHOULDER))) * np.pi * 2 / 0.04)), 0.004)
    d = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    ring = CappedCone(WRIST + (ELBOW - WRIST) * 0.16, WRIST + d * 0.008, 0.058, 0.058, rr=0.006, part=STEEL)
    return s, ring


def glove():
    """a chunky glove in hand space (wrist at the origin, fingers -Z, back of the hand +X, thumb -Y), the fingers loosely curled"""
    cuff = CappedCone((0, 0, 0.012), (0, 0, -0.03), 0.042, 0.038, rr=0.01, part=GLOVE)
    palm = Ellipsoid((0.0, 0.0, -0.058), (0.026, 0.044, 0.042), part=GLOVE)
    parts = [cuff, palm]
    for f in (-0.03, -0.01, 0.01, 0.03):
        L = 1.0 - abs(f) * 5
        pts = [(v3((0.0, f, -0.085)), 0.0125), (v3((-0.004, f, -0.11 - 0.008 * L)), 0.012), (v3((-0.02, f * 1.02, -0.13 - 0.006 * L)), 0.0112)]
        parts.append(loft(pts, part=GLOVE, k=0.004))
    parts.append(loft([(v3((-0.006, -0.038, -0.035)), 0.014), (v3((-0.022, -0.056, -0.065)), 0.0125), (v3((-0.034, -0.05, -0.088)), 0.0115)], part=GLOVE, k=0.004))
    return Union(parts, k=0.008)


def legs():
    hips = Union([Ellipsoid((0, 0.01, 0.43), (0.16, 0.13, 0.07)), Mirror(loft([(HIP, 0.072), (KNEE, 0.066), (ANKLE + v3((0, 0, 0.06)), 0.064)]))], k=0.04, part=SUIT)
    pad = Mirror(Clip(Inflate(Ellipsoid(KNEE + v3((0, -0.03, 0.0)), (0.06, 0.05, 0.05)), 0.0, part=ORANGE), [Half(KNEE + v3((0, -0.02, 0)), (0, 1, 0))], k=0.004))
    shaft = CappedCone(ANKLE + v3((0, 0.0, 0.11)), ANKLE + v3((0, 0.0, -0.02)), 0.074, 0.08, rr=0.014, part=BOOT)
    top = Torus(ANKLE + v3((0, 0, 0.108)), 0.074, 0.012, part=BOOT)
    foot = Union([Ellipsoid(v3((ANKLE[0], -0.035, 0.065)), (0.08, 0.125, 0.065), part=BOOT), shaft], k=0.03)
    foot = Clip(foot, [Half((0, 0, 0.024), (0, 0, -1))], k=0.004)
    sole = Box((ANKLE[0], -0.032, 0.014), (0.086, 0.135, 0.015), rr=0.012, part=SOLE)
    boot = Mirror(Union([foot, top, sole], k=0.0))
    return Union([hips, pad, boot], k=0.0)


def pack():
    box = Box((0, 0.205, 0.64), (0.15, 0.065, 0.15), rr=0.04, part=PACK)
    box = Bump(box, lambda P: 1.0 - (P[:, 0] / 0.17) ** 2 - ((P[:, 1] - 0.205) / 0.08) ** 2 - ((P[:, 2] - 0.64) / 0.17) ** 2, 0.005)      # (no dead-flat faces)
    tanks = [CappedCone((sx * 0.072, 0.275, 0.5), (sx * 0.072, 0.275, 0.79), 0.046, 0.046, rr=0.02, part=TANK) for sx in (-1, 1)]
    valves = [Union([CappedCone((sx * 0.072, 0.275, 0.79), (sx * 0.072, 0.275, 0.82), 0.016, 0.014, rr=0.004, part=BRASS),
                     CappedCone((sx * 0.072 - 0.02, 0.275, 0.815), (sx * 0.072 + 0.02, 0.275, 0.815), 0.008, 0.008, rr=0.003, part=BRASS)]) for sx in (-1, 1)]
    straps = [Box((sx * 0.072, 0.275, z), (0.05, 0.05, 0.01), rr=0.006, part=BELT) for sx in (-1, 1) for z in (0.56, 0.73)]
    hose = loft([(v3((-0.13, 0.2, 0.74)), 0.017), (v3((-0.2, 0.17, 0.8)), 0.017), (v3((-0.19, 0.08, 0.85)), 0.017), (v3((-0.13, 0.035, 0.82)), 0.017)], part=HOSE, k=0.02)
    return Union([box, hose] + tanks + valves + straps, k=0.0)


def pieces():
    s, ring = sleeves()
    hand = Union([ring, place(Scaled(glove(), 1.2), WRIST, HAND)], k=0.0)
    upper = Union([torso(), s, Move(s, R=FLIP)], k=0.018)
    return [("bowl", bowl(), 0.0018), ("fish", fish(), 0.0009), ("torso", upper, 0.003), ("hands", Mirror(hand), 0.0022),
            ("legs", legs(), 0.0028), ("pack", pack(), 0.0026)]


# ---------------------------------------------------------------------------------------------------- paint

def bowl_inside():
    """what is in the water (paint only): aquarium gravel in the bottom of the bowl, a sprig of weed at the back"""
    gravel = Bump(Half((0, 0, 0.865), (0, 0, 1)), lambda P: noise3(P, 0.008), 0.004)
    weed = []
    for i, (bx, by, h, lean) in enumerate(((-0.06, 0.09, 0.18, 0.04), (-0.03, 0.11, 0.14, -0.03), (-0.09, 0.07, 0.11, 0.05))):
        pts = [(v3((bx, by, 0.86)), 0.009), (v3((bx + lean * 0.5, by - 0.01, 0.86 + h * 0.5)), 0.008), (v3((bx + lean, by + 0.005, 0.86 + h)), 0.004)]
        weed.append(loft(pts, k=0.004))
    return gravel, Union(weed, k=0.01)


def paint(c):
    from kit.paint import srgb, smooth
    P, N = c.P, c.N
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.04) * 0.5 + noise3(P, 0.012) * 0.25
    grime = np.clip(noise3(P + 3.1, 0.035) * 0.8 + 0.25, 0, 1)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = rough[m] if np.ndim(rough) == 1 and np.size(rough) == n else rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, np.float32)], 1)

    # the bowl: rays in from the glass find the gravel and the weed, or cross the water to the far side; bubbles rising from the weed; highlights
    m = c.mask(GLASS)
    if m.any():
        G = P[m]
        Nn = N[m]
        Nh = Nn.copy()
        Nh[:, 2] = 0.0
        gravel, weed = bowl_inside()
        pebbles = np.array([srgb(70, 120, 220), srgb(230, 110, 150), srgb(240, 210, 90), srgb(240, 240, 230), srgb(90, 200, 160)])
        acc = np.zeros((len(G), 3), np.float32)
        wsum = np.zeros(len(G), np.float32)
        # level rays across the bowl from four sides (front, back, left, right), blended by which way the glass faces, and straight down for its
        # bottom: so the gravel shows only low in the bowl and the weed at its own height, whatever side it is seen from
        for ax in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, -1)):
            a_ = v3(ax)
            w = np.clip((Nh if ax[2] == 0 else Nn) @ a_, 0.0, 1.0) ** 3
            sel = w > 0.01
            if not sel.any():
                continue
            O = G[sel]
            D = np.broadcast_to(-a_, O.shape).astype(np.float32)
            t = np.full(len(O), 0.003, np.float32)
            hit = np.zeros(len(O), np.int8)
            for _ in range(50):
                p = O + D * t[:, None]
                dg = gravel.eval(p)[0]
                dw = weed.eval(p)[0]
                d = np.minimum(dg, dw)
                new = (hit == 0) & (d < 0.001)
                hit[new & (dg <= dw)] = 1
                hit[new & (dw < dg)] = 2
                t = np.where(hit > 0, t, t + np.clip(d * 0.85, 0.002, 0.012))      # (capped: far from every part the field reads 1000)
                if ((hit > 0) | (t > 2 * RG)).all():
                    break
            inside = np.linalg.norm(O + D * t[:, None] - HC, axis=1) < RG
            hit[~inside] = 0
            H = O + D * t[:, None]
            depth = np.clip(t / (2 * RG), 0, 1)
            water = srgb(150, 222, 236) + (srgb(50, 150, 180) - srgb(150, 222, 236)) * smooth(0.0, 1.0, depth)[:, None]
            cell = np.floor(H / 0.007).astype(np.int64)
            hsh = ((cell[:, 0] * 73856093) ^ (cell[:, 1] * 19349663) ^ (cell[:, 2] * 83492791)) % 5
            gcol = pebbles[hsh] * (0.6 + 0.4 * np.clip(noise3(H, 0.004), 0, 1))[:, None]
            wcol = srgb(60, 150, 60) * (0.7 + 0.3 * smooth(0.86, 1.0, H[:, 2]))[:, None]
            col = np.where((hit == 1)[:, None], gcol, np.where((hit == 2)[:, None], wcol, water))
            col = np.where((hit > 0)[:, None], col + (water * 0.7 - col) * (0.2 + 0.6 * depth)[:, None], col)
            acc[sel] += col * w[sel, None]
            wsum[sel] += w[sel]
        col = acc / np.maximum(wsum, 1e-6)[:, None]
        bub = np.zeros(len(G), np.float32)
        rng = np.random.default_rng(11)
        for _ in range(24):
            a = rng.uniform(-2.6, -0.6) if rng.uniform() < 0.6 else rng.uniform(0, 2 * np.pi)
            bz = rng.uniform(0.88, TOP - 0.03)
            el = np.arcsin(np.clip((bz - HC[2]) / RG, -1, 1))
            bc = HC + v3((RG * np.cos(el) * np.cos(a), RG * np.cos(el) * np.sin(a), RG * np.sin(el)))
            rr = rng.uniform(0.004, 0.009)
            dd = np.linalg.norm(G - bc, axis=1)
            bub = np.maximum(bub, smooth(rr, rr * 0.55, dd) - smooth(rr * 0.6, rr * 0.2, dd) * 0.6)
        col = col + (srgb(235, 255, 255) - col) * (bub * 0.8)[:, None]
        # the glass: a window highlight up on its left, a rim light low on its right, the meniscus under the lip
        dn = (G - HC) / RG
        hl = smooth(0.16, 0.0, np.sqrt(((dn[:, 0] + 0.45) / 0.55) ** 2 + ((dn[:, 2] - 0.5) / 1.0) ** 2)) * (dn[:, 1] < 0.2) * 0.7
        hl += smooth(0.06, 0.0, np.sqrt((dn[:, 0] + 0.2) ** 2 + (dn[:, 2] - 0.62) ** 2)) * (dn[:, 1] < 0.0) * 0.6
        rim = smooth(0.85, 0.98, -dn[:, 1] * 0.2 + dn[:, 0] * 0.5 - dn[:, 2] * 0.5) * 0.4
        col = col + (srgb(240, 255, 255) - col) * np.clip(hl + rim, 0, 1)[:, None]
        lipz = G[:, 2] > TOP - 0.008
        col[lipz] = srgb(200, 236, 240)
        c.col[m] = col
        c.rough[m] = 0.04
        c.metal[m] = 0.0
        c.bump[m] = 0.0
    # the water's surface in the open top: ripple rings, flakes of fish food floating
    m = c.mask(WATER)
    rr = np.sqrt((x - HC[0]) ** 2 + (y - HC[1]) ** 2)
    wc = srgb(90, 180, 200) * (1.0 + 0.15 * np.sin(rr * 260.0))[:, None]
    flakes = (noise3(P, 0.006) > 0.55) & (rr < 0.08)
    wc[flakes] = srgb(214, 150, 70)
    put(m, wc, 0.05)

    # the goldfish: orange going gold on the back, a pale belly, fins redder and streaked; scales (speckles), its bead eye inked, the water's tint over all
    m = c.mask(FISH, FIN)
    q = (P - FISH_C) @ FISH_R            # (rest pose frame: x along it, y up)
    fu, fv = q[:, 0], q[:, 1]
    fc = srgb(255, 128, 26) + (srgb(255, 190, 60) - srgb(255, 128, 26)) * smooth(0.0, 0.03, fv)[:, None]
    fc = fc + (srgb(255, 236, 200) - fc) * (smooth(-0.005, -0.03, fv) * (fu > -0.03))[:, None]
    fin = c.mask(FIN)
    fc[fin] = (srgb(250, 96, 20) * (0.85 + 0.15 * np.sin(np.arctan2(fv, fu + 0.03) * 30.0))[:, None])[fin]
    tint = srgb(150, 222, 236)
    fc = fc * 0.82 + fc * tint * 0.25
    put(m, fc, 0.18, bump=0.3)
    spk(c.mask(FISH), (255, 200, 90), 0.35)
    ed = np.sqrt((fu - 0.038) ** 2 + (fv - 0.008) ** 2)
    gl = np.sqrt((fu - 0.0398) ** 2 + (fv - 0.0105) ** 2)
    c.col[m & (gl < 0.0022)] = srgb(255, 255, 255)
    c.draw(m, np.maximum(ed - 0.0058, 0.0019 - gl), 0.0)          # the pupil, a glint left in it
    c.draw(m & (ed > 0.0058), np.abs(ed - 0.0075), 0.0006, 0.5)
    # gill line, mouth crease
    c.draw(m & c.mask(FISH), np.abs(np.sqrt((fu - 0.05) ** 2 + (fv + 0.0) ** 2) - 0.026) + 1.0 * (fu > 0.04) + 1.0 * (np.abs(fv) > 0.022), 0.0007, 0.6)
    c.draw(m & (fu > 0.055), np.abs(fv + 0.004), 0.0006, 0.7)

    # the suit: cream twill, puffy, grubby; quilting seams inked; a fish mission patch on the left shoulder; the orange bits faded and scuffed
    m = c.mask(SUIT)
    sc = srgb(222, 210, 182) * (1.0 + 0.05 * mott)[:, None]
    sc = sc * (1.0 - 0.28 * grime * smooth(0.5, 0.2, z))[:, None]
    sc = sc + (srgb(240, 232, 214) - sc) * (c.wear * 0.3)[:, None]
    put(m, sc, 0.85, bump=1.0)
    spk(m, (150, 130, 100), 0.18)
    sm = (z - 0.43) % 0.07
    c.draw(m & (z > 0.44) & (z < 0.76), np.minimum(sm, 0.07 - sm), 0.0009, 0.55)
    pm = m & (x > 0.12) & (z > 0.66)
    pc = P - v3((0.175, -0.07, 0.71))
    pd = np.linalg.norm(pc, axis=1)
    patch = pm & (pd < 0.038)
    c.col[patch] = srgb(40, 70, 130)
    fishy = patch & (((pc[:, 1] + 0.004) / 0.022) ** 2 + ((pc[:, 2]) / 0.013) ** 2 < 1.0)
    c.col[fishy] = srgb(250, 140, 40)
    tailp = patch & (pc[:, 1] > 0.016) & (pc[:, 1] < 0.03) & (np.abs(pc[:, 2]) < (pc[:, 1] - 0.012) * 0.8)
    c.col[tailp] = srgb(250, 140, 40)
    c.draw(pm & (pd < 0.044), np.abs(pd - 0.038), 0.0012, 0.8)
    m = c.mask(ORANGE)
    oc = srgb(196, 104, 52) * (1.0 + 0.08 * mott)[:, None]
    oc = oc + (srgb(230, 160, 110) - oc) * (c.wear * 0.4)[:, None]
    put(m, oc, 0.8, bump=1.0)
    spk(m, (140, 70, 34), 0.35)
    m = c.mask(GLOVE)
    gc = srgb(226, 214, 186) * (1.0 + 0.05 * mott)[:, None]
    gc = gc * (1.0 - 0.3 * c.cavity * grime)[:, None]
    put(m, gc, 0.75, bump=0.9, grain=0.5)
    m = c.mask(PANEL)
    put(m, srgb(52, 86, 124) + (srgb(130, 150, 170) - srgb(52, 86, 124)) * (c.wear * 0.6)[:, None], 0.45, bump=0.2, grain=1.0)
    m = c.mask(LIGHT)
    put(m, srgb(140, 255, 160), 0.1)
    for part, base, metal, rough in ((STEEL, (170, 174, 180), 1.0, 0.3), (TANK, (196, 200, 206), 1.0, 0.25), (BRASS, (214, 160, 76), 1.0, 0.3)):
        m = c.mask(part)
        st = srgb(*base) * (1.0 - 0.45 * c.cavity)[:, None] * (1.0 - 0.15 * grime)[:, None]
        put(m, st, rough + 0.15 * grime, metal=metal, bump=0.1, grain=1.0)
    m = c.mask(TANK)
    band = m & (np.abs(z - 0.645) < 0.015)
    c.col[band] = srgb(220, 60, 40)
    c.metal[band] = 0.0
    m = c.mask(PACK)
    pk = srgb(118, 120, 122) + (srgb(190, 190, 186) - srgb(118, 120, 122)) * (c.wear * 0.5)[:, None]
    put(m, pk * (1.0 - 0.3 * grime)[:, None], 0.55, bump=0.3, grain=1.0)
    m = c.mask(HOSE)
    put(m, srgb(44, 44, 48), 0.55, bump=0.3, grain=1.0)
    c.strp[m, 0] = ((x + z) * 1.8)[m]
    c.strp[m, 1] = 1.0
    m = c.mask(BELT)
    put(m, srgb(40, 40, 46) + (srgb(100, 100, 104) - srgb(40, 40, 46)) * (c.wear * 0.5)[:, None], 0.5, bump=0.6, grain=1.0)
    m = c.mask(BOOT)
    bc = srgb(116, 98, 70) * (1.0 + 0.08 * mott)[:, None]
    bc = bc + (srgb(160, 140, 110) - bc) * (c.wear * 0.5)[:, None]
    bc = bc * (1.0 - 0.3 * smooth(0.12, 0.02, z))[:, None]
    put(m, bc, 0.75, bump=0.8, grain=0.4)
    m = c.mask(SOLE)
    put(m, srgb(40, 36, 32), 0.9, bump=0.8, grain=1.0)
    c.strp[m, 0] = (y * 3.0)[m]
    c.strp[m, 1] = 1.0

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    gm = c.mask(GLASS, WATER, FISH, FIN, LIGHT)
    c.col[gm] /= (0.35 + 0.65 * c.ao[gm])[:, None] ** 0.6
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"bowl": 1300, "fish": 600, "torso": 3000, "hands": 1600, "legs": 2000, "pack": 1300},
    "density": {"bowl": 2.0, "fish": 2.5},
    "tex": 2048,
    "stride": {"walk": 0.7, "run": 1.15},
    "speed": 0.75,
    "look": ["helmet", "fish"], "neck": "neck",
    "look_pivot": (0.0, -0.005, 0.83),
    "radius": 0.3,
}
BALL = v3((0.094, 0.0, 0.0))


def rig_bones():
    from kit.rig import Bone, mirror
    hand_end = WRIST - HAND[:, 2] * 0.13
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.01, 0.41), (0, 0.01, 0.5), "root", 0.15),
        Bone("spine", (0, 0.01, 0.5), (0, 0.01, 0.62), "hips", 0.17),
        Bone("chest", (0, 0.01, 0.62), (0, 0.01, 0.76), "spine", 0.18),
        Bone("pack", (0, 0.2, 0.5), (0, 0.2, 0.8), "chest", 0.12),
        Bone("neck", (0, 0.0, 0.76), (0, 0.0, 0.83), "chest", 0.05),
        Bone("helmet", (0, 0.0, 0.83), HC + v3((0, 0, 0.2)), "neck", 0.2),
        Bone("fish", HC, FISH_C, "helmet", 0.03),
        Bone("shoulder.L", (0.07, 0.012, 0.73), SHOULDER, "chest", 0.06),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.06),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.055),
        Bone("hand.L", WRIST, hand_end, "forearm.L", 0.04),
        Bone("thigh.L", HIP, KNEE, "hips", 0.07),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.065),
        Bone("foot.L", ANKLE, (0.094, -0.13, 0.03), "shin.L", 0.06),
    ])


def skin_rules(P, part, piece, names):
    """piece: 0 bowl, 1 fish, 2 torso (and sleeves), 3 hands, 4 legs, 5 pack"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    allow(piece == 0, "helmet")
    rig[piece == 0] = ix["helmet"]
    allow(piece == 1, "fish")
    rig[piece == 1] = ix["fish"]
    tp = piece == 2
    body = tp & (np.abs(x) < 0.2)
    allow(body, "hips", "spine", "chest")
    rig[body & (z > 0.76)] = ix["chest"]          # the collar ring is rigid
    allow(body & (x > 0.15) & (z > 0.66), "shoulder.L", "upper_arm.L")
    allow(body & (x < -0.15) & (z > 0.66), "shoulder.R", "upper_arm.R")
    sl = tp & ~body
    allow(sl & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L")
    allow(sl & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R")
    hp = piece == 3
    allow(hp & (x > 0), "forearm.L", "hand.L")
    allow(hp & (x <= 0), "forearm.R", "hand.R")
    rig[hp & (x > 0) & (part == GLOVE)] = ix["hand.L"]
    rig[hp & (x <= 0) & (part == GLOVE)] = ix["hand.R"]
    rig[hp & (x > 0) & (part == STEEL)] = ix["forearm.L"]
    rig[hp & (x <= 0) & (part == STEEL)] = ix["forearm.R"]
    lp = piece == 4
    allow(lp, "hips")
    allow(lp & (x > -0.02), "thigh.L", "shin.L", "foot.L")
    allow(lp & (x < 0.02), "thigh.R", "shin.R", "foot.R")
    rig[lp & (z < 0.1) & np.isin(part, (SOLE, BOOT)) & (x > 0)] = ix["foot.L"]
    rig[lp & (z < 0.1) & np.isin(part, (SOLE, BOOT)) & (x <= 0)] = ix["foot.R"]
    pp = piece == 5
    allow(pp, "pack", "chest")
    rig[pp & (part != HOSE)] = ix["pack"]
    return A, rig


def motions(rig):
    """walk: a low-gravity lope (a push, a long floaty hang with both boots up, a soft landing), arms drifting out for balance, the fish sloshing;
    run: bigger bounds, arms paddling; idle: swaying, the fish swims a lap of the bowl, the astronaut taps the glass and the fish darts"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    n_axis = Vector(FISH_DIR.tolist())
    t_axis = Vector(FISH_R[:, 0].tolist())

    def fish_at(p, yaw, lat, spin):
        """the fish swims round the bowl: yaw about the bowl's upright, lat up or down the glass, spin about its own centre (nose up / down)"""
        up = n_axis.cross(t_axis).normalized()
        p.delta["fish"] = Matrix.Rotation(math.radians(yaw), 3, "Z") @ Matrix.Rotation(math.radians(-lat), 3, t_axis) @ Matrix.Rotation(math.radians(spin), 3, n_axis)

    def lope(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        # a bound: the hips low through each stance, floating up between (biped_walk's bob is a walk's, inverted here)
        b = math.cos(2 * TAU * (u - g["stance"] * 0.5))
        p.offset = Vector((g["sway"] * math.sin(TAU * u), 0.0, -g["drop"] - g["bob"] * b))
        c = math.cos(TAU * u)
        float_up = -b
        for s, sx in (("L", 1.0), ("R", -1.0)):
            # swinging against the legs, and drifting out from the sides as it floats (abduction: about Y, out is -Y for the left arm)
            p.rot("upper_arm.%s" % s, sx * (12.0 if run else 7.0) * c, -sx * (12.0 + 9.0 * float_up), 0)
            p.rot("forearm.%s" % s, -(22.0 if run else 14.0) - 8.0 * float_up, 0, 0)
        p.world["helmet"] = R((5.0 if run else 2.0) - 2.0 * float_up, 0, 0)
        fish_at(p, (6.0 if run else 3.0) * math.sin(TAU * u), 7.0 * math.cos(2 * TAU * (u - g["stance"] * 0.5) - 1.0), 8.0 * math.sin(2 * TAU * u))
        return p
    WALK = dict(stride=0.7, stance=0.3, foot_x=0.1, lift=0.07, bob=0.055, drop=0.05, sway=0.02, roll=4.0, yaw=5.0, counter=1.0,
                lean=2.0, toe_off=10.0, toe_out=5.0, swing_point=8.0)
    RUN = dict(stride=1.15, stance=0.24, foot_x=0.1, lift=0.1, bob=0.08, drop=0.07, sway=0.015, roll=4.0, yaw=6.0, counter=1.0,
               lean=8.0, toe_off=16.0, toe_out=5.0, swing_point=14.0, spine_lean=3.0)
    walk = [lope(i / 32.0, WALK, False) for i in range(33)]
    run = [lope(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    sh = Vector(SHOULDER.tolist())
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sw = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.1, 0.0, 0.0)), 6.0), "R": (Vector((-0.1, 0.0, 0.0)), -6.0)},
              hip_shift=(0.008 * sw, 0.0, -0.012 + 0.004 * math.sin(TAU * t / 2.0)), roll=-1.5 * sw, yaw=0.0)
        p.rot("spine", 1.5 * math.sin(TAU * t / 3.0 + 1.0), 0, 0)
        # the tap: the left glove comes up to the glass at 2.4-3.5 s, two taps; the head tips to watch
        tap = ease((t - 2.2) / 0.4) * (1.0 - ease((t - 3.6) / 0.5))
        knock = max(0.0, math.sin(TAU * (t - 2.65) / 0.3)) * (2.65 < t < 3.25)
        if tap > 0.01:
            # fingertips to the glass low on its front-left, pointing in at it; the knock pulls back and taps
            nrm = Vector((0.5, -0.7, -0.5)).normalized()
            contact = Vector(HC.tolist()) + nrm * RG
            tgt = contact + nrm * (0.15 + 0.02 * (1.0 - knock))
            wr = Vector(WRIST.tolist())
            target = wr.lerp(tgt, tap)
            rest_f = Vector((WRIST - ELBOW).tolist()).normalized()
            hand_rot = rest_f.rotation_difference(rest_f.lerp(-nrm, tap).normalized()).to_matrix()
            p.ik["upper_arm.L"] = (target, Vector((0.7, 0.4, -0.6)).normalized(), "hand.L", hand_rot)
        else:
            p.rot("upper_arm.L", 0, -2.0 * sw, 0)
        p.rot("upper_arm.R", 1.5 * sw, 2.0, 0)
        p.world["helmet"] = R(-4.0 * tap, 0, 6.0 * tap + 4.0 * math.sin(TAU * t / 6.0) * (1.0 - tap))
        # the fish: a lazy lap of the bowl (6 s), darting away when the glass is knocked
        dart = ease((t - 2.7) / 0.2) * (1.0 - ease((t - 3.8) / 0.8))
        yaw = -360.0 * (t / 6.0) - 40.0 * dart
        fish_at(p, yaw, 6.0 * math.sin(TAU * t / 3.0) + 8.0 * dart, 10.0 * math.sin(TAU * t / 1.5))
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
