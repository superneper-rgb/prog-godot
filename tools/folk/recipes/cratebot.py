## FOINT CITY townsfolk: the crate robot (cratebot). A wooden shipping crate on four little steel legs, a CRT face set into its front, a burlap bundle strapped on top, a whip antenna wagging like a tail.
# Upgrade of the three.js folk species "cratebot" (progalpha levels/hub/folk-species-a.js; old render refs/old/cratebot.png): kept the pale wooden crate with
# darker bands and pale corner studs, the dark screen with cyan oval eyes and a red mouth, the four dark legs with grey knee rings and black feet, the brown
# sack on top (now a rolled army blanket in the same browns, strapped down: the lumpy sack read as a roast chicken). The rabbit banner is dropped (roster);
# its pole's place at the back corner is now a short wagging antenna. 1.00 m to the top of the bedroll.
# Moves: a skittery diagonal trot like a small dog, the bundle bouncing behind the beat, the antenna wagging; it runs in an excited bounding gallop.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.00
REF = ("old/cratebot.png", None)

WOOD, BAND, STEEL, RIVET, BEZEL, SCREEN, SACK, ROPE, LEG, JOINT, GAITER, RUBBER, ANT, BALL, LABEL = range(1, 16)
COLOURS = {
    WOOD: ((0.62, 0.46, 0.27), 0.7, 0.0),
    BAND: ((0.36, 0.24, 0.13), 0.7, 0.0),
    STEEL: ((0.25, 0.26, 0.27), 0.4, 1.0),
    RIVET: ((0.6, 0.6, 0.6), 0.3, 1.0),
    BEZEL: ((0.08, 0.08, 0.09), 0.4, 0.0),
    SCREEN: ((0.02, 0.04, 0.05), 0.08, 0.0),
    SACK: ((0.45, 0.33, 0.18), 0.9, 0.0),
    ROPE: ((0.66, 0.55, 0.36), 0.9, 0.0),
    LEG: ((0.22, 0.23, 0.25), 0.35, 1.0),
    JOINT: ((0.5, 0.5, 0.52), 0.3, 1.0),
    GAITER: ((0.05, 0.05, 0.05), 0.7, 0.0),
    RUBBER: ((0.03, 0.03, 0.03), 0.8, 0.0),
    ANT: ((0.7, 0.7, 0.72), 0.25, 1.0),
    BALL: ((0.95, 0.5, 0.1), 0.3, 0.0),
    LABEL: ((0.9, 0.86, 0.74), 0.7, 0.0),
}

# the crate (faces -Y)
CR_C = v3((0.0, 0.0, 0.6))
CR_H = v3((0.27, 0.27, 0.2))          # half size: 0.54 x 0.54 x 0.40, bottom at 0.40, top at 0.80
SCR_C = v3((0.0, -0.302, 0.6))        # the screen's centre on its glass
SCR_HALF = (0.172, 0.11)
# the legs, left side, front (f) and back (b): hip under the crate's corner, knees bending in toward the middle
HIP_F = v3((0.2, -0.2, 0.39))
KNEE_F = v3((0.214, -0.172, 0.218))
ANK_F = v3((0.214, -0.2, 0.062))
HIP_B = HIP_F * np.array([1, -1, 1], np.float32)
KNEE_B = KNEE_F * np.array([1, -1, 1], np.float32)
ANK_B = ANK_F * np.array([1, -1, 1], np.float32)
# the tail antenna at the back right corner of the lid
TAIL_ROOT = v3((-0.205, 0.205, 0.81))
TAIL_MID = v3((-0.225, 0.255, 0.93))
TAIL_TIP = v3((-0.25, 0.315, 1.02))
SACK_C = v3((0.0, 0.03, 0.895))       # the bedroll's centre; it lies across the lid along X
ROLL_R, ROLL_L = 0.095, 0.215


class Bounded(Shape):
    """the child with a tighter box than the kit's spheres give it (keeps the mesher's grid small)"""
    def __init__(self, child, lo, hi):
        self.child, self.lo, self.hi, self.part = child, v3(lo), v3(hi), child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.eval(P)[0]


# ---------------------------------------------------------------------------------------------------- the crate

def crate():
    box = Box(CR_C, CR_H, rr=0.012, part=WOOD)
    # the sides bow out a little (a chunky, well-stuffed crate; and dead-flat faces made the decimator flip triangles, which bake black)
    box = Bump(box, lambda P: 1.0 - (P[:, 0] / 0.3) ** 2 - (P[:, 1] / 0.3) ** 2 - ((P[:, 2] - CR_C[2]) / 0.22) ** 2, 0.006)
    # (plank seams, wood grain, rope twist and gaiter ribs are painted, never sculpted: fine sculpted detail makes the decimator starve the rest
    # and flip faces, which bake black)
    # rims round the top and bottom, corner posts up the four edges (darker, rougher wood)
    rims = [Box((0, 0, z), (CR_H[0] + 0.012, CR_H[1] + 0.012, 0.024), rr=0.008, part=BAND) for z in (0.425, 0.775)]
    posts = [Box((sx * (CR_H[0] - 0.008), sy * (CR_H[1] - 0.008), 0.6), (0.026, 0.026, 0.19), rr=0.008, part=BAND) for sx in (-1, 1) for sy in (-1, 1)]
    bands = Union(rims + posts, k=0.0, part=BAND)
    # steel corner caps with rivets
    caps = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                cc = v3((sx * (CR_H[0] + 0.004), sy * (CR_H[1] + 0.004), CR_C[2] + sz * (CR_H[2] - 0.016)))
                caps.append(Box(cc, (0.04, 0.04, 0.032), rr=0.01, part=STEEL))
                for d in ((sx * 0.044, -sy * 0.016 * 0, 0.0),):
                    pass
                caps.append(Sphere(cc + v3((sx * 0.038, -sy * 0.022, -sz * 0.006)), 0.0065, part=RIVET))
                caps.append(Sphere(cc + v3((-sx * 0.022, sy * 0.038, -sz * 0.006)), 0.0065, part=RIVET))
    # the face: a steel bezel bolted to the front, the screen bulging inside it
    bezel = Box((0.0, -0.284, SCR_C[2]), (SCR_HALF[0] + 0.026, 0.02, SCR_HALF[1] + 0.024), rr=0.022, part=BEZEL)
    bezel = Cut(bezel, [Box((0.0, -0.31, SCR_C[2]), (SCR_HALF[0], 0.03, SCR_HALF[1]), rr=0.02)], k=0.004)
    glass = Clip(Box((0.0, -0.25, SCR_C[2]), (SCR_HALF[0] + 0.006, 0.06, SCR_HALF[1] + 0.006), rr=0.022, part=SCREEN),
                 [Sphere((0.0, SCR_C[1] + 0.9, SCR_C[2]), 0.9)], k=0.003)
    screws = [Sphere((sx * (SCR_HALF[0] + 0.012), -0.304, SCR_C[2] + sz * (SCR_HALF[1] + 0.011)), 0.0075, part=RIVET) for sx in (-1, 1) for sz in (-1, 1)]
    # hip mounts under the corners
    mounts = [CappedCone((sx * 0.2, sy * 0.2, 0.41), (sx * 0.2, sy * 0.2, 0.37), 0.046, 0.04, rr=0.008, part=STEEL) for sx in (-1, 1) for sy in (-1, 1)]
    # the antenna's spring base
    tb = CappedCone(TAIL_ROOT + v3((0, 0, -0.012)), TAIL_ROOT + v3((0, 0, 0.012)), 0.022, 0.018, rr=0.005, part=STEEL)
    return Union([Union([box, bands], k=0.0), bezel, glass, tb] + caps + screws + mounts, k=0.0)


def sack():
    """a rolled wool blanket lying across the lid, two leather straps round it, lashed down to the lid's front and back edges"""
    roll = CappedCone(SACK_C - v3((ROLL_L, 0, 0)), SACK_C + v3((ROLL_L, 0, 0)), ROLL_R, ROLL_R, rr=0.035, part=SACK)
    roll = Clip(roll, [Half((0, 0, 0.8), (0, 0, -1))], k=0.03)          # flattened a little where it sits on the lid
    roll = Bump(roll, lambda P: noise3(np.abs(P) * np.array([0.4, 1, 1], np.float32), 0.04), 0.004)
    straps = []
    for x in (-0.12, 0.12):
        band = Cut(CappedCone(v3((x - 0.017, SACK_C[1], SACK_C[2])), v3((x + 0.017, SACK_C[1], SACK_C[2])), ROLL_R + 0.007, ROLL_R + 0.007, rr=0.003, part=ROPE),
                   [CappedCone(v3((x - 0.03, SACK_C[1], SACK_C[2])), v3((x + 0.03, SACK_C[1], SACK_C[2])), ROLL_R - 0.01, ROLL_R - 0.01)], k=0.0)
        buckle = Box(v3((x, SACK_C[1] - ROLL_R - 0.006, SACK_C[2] - 0.02)), (0.022, 0.006, 0.018), rr=0.004, part=STEEL)
        lash_f = loft([(v3((x, SACK_C[1] - 0.06, 0.82)), 0.006), (v3((x, -0.2, 0.805)), 0.006), (v3((x, -0.268, 0.79)), 0.006)], part=ROPE, k=0.01)
        lash_b = loft([(v3((x, SACK_C[1] + 0.06, 0.82)), 0.006), (v3((x, 0.2, 0.805)), 0.006), (v3((x, 0.268, 0.79)), 0.006)], part=ROPE, k=0.01)
        straps += [band, buckle, lash_f, lash_b]
    return Union([roll] + straps, k=0.0)


def tail():
    coil = [CappedCone(TAIL_ROOT + v3((0, 0, 0.01)), TAIL_ROOT + v3((0, 0, 0.055)), 0.013, 0.012, rr=0.004, part=STEEL)]      # a spring (its coils painted)
    rod = loft([(TAIL_ROOT + v3((0, 0, 0.05)), 0.0055), (TAIL_MID, 0.0048), (TAIL_TIP, 0.004)], part=ANT, k=0.01)
    d = (TAIL_TIP - TAIL_MID) / np.linalg.norm(TAIL_TIP - TAIL_MID)
    ball = Sphere(TAIL_TIP + d * 0.018, 0.022, part=BALL)
    return Union(coil + [rod, ball], k=0.002)


def leg(hip, knee, ank):
    thigh = RoundCone(hip, knee, 0.027, 0.024, part=LEG)
    shin = RoundCone(knee, ank, 0.024, 0.022, part=LEG)
    hipj = Sphere(hip + v3((0, 0, -0.012)), 0.034, part=JOINT)
    kj = Sphere(knee, 0.03, part=JOINT)
    # a ribbed rubber gaiter round the knee (the old model's grey ring), a piston down the front of the shin
    g0, g1 = knee + (hip - knee) * 0.35, knee + (ank - knee) * 0.32
    gaiter = RoundCone(g0, g1, 0.037, 0.035, part=GAITER)
    aj = Sphere(ank, 0.026, part=JOINT)
    pad = Clip(Ellipsoid(ank + v3((0.0, -0.008, -0.03)), (0.05, 0.058, 0.04), part=RUBBER), [Half((0, 0, 0.0), (0, 0, -1))], k=0.004)
    tread = Clip(Inflate(Ellipsoid(ank + v3((0.0, -0.008, -0.03)), (0.05, 0.058, 0.04)), 0.003, part=RUBBER), [Half((0, 0, 0.014), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    return Union([Union([thigh, shin], k=0.006), hipj, kj, gaiter, aj, pad, tread], k=0.0)


def pieces():
    legs = Mirror(Union([leg(HIP_F, KNEE_F, ANK_F), leg(HIP_B, KNEE_B, ANK_B)]))
    return [("crate", Bounded(crate(), (-0.33, -0.34, 0.33), (0.33, 0.34, 0.86)), 0.0028), ("sack", sack(), 0.0026), ("legs", legs, 0.0018), ("tail", tail(), 0.0013)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
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

    def hash1(k):
        return (np.sin(k * 127.1 + 311.7) * 43758.5453) % 1.0

    # pine planks: each plank its own tint, grain lines along it (Strp), dirt rising from the bottom, edges rubbed pale, nail heads by the posts
    m = c.mask(WOOD)
    side = np.abs(x) > np.abs(y)
    top = z > 0.795
    plank = np.where(top, np.floor((x + 0.27) / 0.135), np.floor((z - 0.4) / 0.1))
    tint = hash1(plank + np.where(side, 10.0, 0.0) + np.where(y > 0, 20.0, 0.0))
    wd = srgb(196, 152, 98) + (srgb(176, 128, 78) - srgb(196, 152, 98)) * tint[:, None]
    wd *= (1.0 + 0.08 * mott)[:, None]
    wd = wd + (srgb(222, 190, 140) - wd) * (c.wear * 0.45)[:, None]
    wd = wd * (1.0 - 0.4 * smooth(0.58, 0.40, z) * grime)[:, None]
    put(m, wd, 0.78, bump=0.5)
    # the seams between the planks, inked
    seam = np.where(top, np.abs(((x + 0.27) % 0.135) - 0.0675) - 0.0675, np.abs(((z - 0.4) % 0.1) - 0.05) - 0.05)
    c.draw(m, np.abs(seam), 0.0013, 0.85)
    gcoord = np.where(top, x + 0.01 * noise3(P, 0.05), z + 0.008 * noise3(P * np.array([0.3, 0.3, 1], np.float32), 0.03))
    c.strp[m, 0] = (gcoord * 2.6)[m]
    c.strp[m, 1] = 0.55
    spk(m, (110, 76, 44), 0.12)
    # stencils (inked): an up-arrow pair on each side, a stencilled glass on the back, a shipping label on the left side with a barcode
    for sx in (1, -1):
        sm = m & (sx * x > 0.26)
        for ay in (-0.075, 0.075):
            u, v = y - ay, z - 0.585
            shaft = np.maximum(np.abs(u) - 0.011, np.abs(v + 0.012) - 0.045)
            head = np.maximum(np.maximum(-(v - 0.025), (v - 0.07)), np.abs(u) - (0.07 - v) * 0.75)
            arrow = np.minimum(shaft, head)
            bar = np.maximum(np.abs(u) - 0.034, np.abs(v + 0.072) - 0.006)
            c.draw(sm, np.minimum(arrow, bar) + 0.0015 * noise3(P, 0.004), 0.0, 0.85)
    bm = m & (y > 0.26)
    u, v = x, z - 0.6
    bowl = np.sqrt((u / 0.04) ** 2 + ((v - 0.035) / 0.03) ** 2) - 1.0
    bowl = np.where(v < 0.035, bowl, np.maximum(np.abs(u) - 0.04, (v - 0.065)))
    stem = np.maximum(np.abs(u) - 0.006, np.abs(v + 0.02) - 0.03)
    foot = np.maximum(np.abs(u) - 0.03, np.abs(v + 0.05) - 0.006)
    crack = np.abs(u + 0.012 - 0.4 * (v - 0.04)) - 0.0018
    glass = np.maximum(np.minimum(np.minimum(bowl * 0.03, stem), foot), -crack)
    c.draw(bm, glass, 0.0, 0.85)
    lm = m & (x > 0.26) & (np.abs(y - 0.0) < 0.07) & (np.abs(z - 0.695) < 0.04)
    c.col[lm] = (srgb(226, 214, 184) * (1.0 + 0.05 * mott)[:, None])[lm]
    c.rough[lm] = 0.7
    c.strp[lm, 1] = 0.0
    lab = m & (x > 0.26) & (np.abs(y) < 0.075) & (np.abs(z - 0.695) < 0.045)
    c.draw(lab, np.abs(np.maximum(np.abs(y) - 0.07, np.abs(z - 0.695) - 0.04)), 0.0007, 0.6)
    bars = m & (x > 0.26) & (np.abs(y + 0.02) < 0.04) & (z > 0.668) & (z < 0.7)
    bw = 0.0012 + 0.0014 * (hash1(np.floor((y + 0.06) / 0.0045)) > 0.5)
    c.draw(bars, np.abs(((y + 0.06) % 0.0045) - 0.00225) - bw * 0.5 + 0.0, 0.0, 0.9)
    lines = m & (x > 0.26) & (np.abs(y) < 0.06) & (z > 0.705) & (z < 0.728)
    c.draw(lines, np.abs(((z - 0.705) % 0.008) - 0.004), 0.0008, 0.6)
    # nail heads near the posts, two to a plank
    for sx in (1, -1):
        for sy in (1, -1):
            pass

    m = c.mask(BAND)
    bd = srgb(116, 78, 44) * (1.0 + 0.1 * mott)[:, None]
    bd = bd + (srgb(170, 128, 82) - bd) * (c.wear * 0.5)[:, None]
    bd = bd * (1.0 - 0.35 * smooth(0.5, 0.4, z) * grime)[:, None]
    put(m, bd, 0.82, bump=0.6)
    c.strp[m, 0] = (np.where(np.abs(z - 0.6) > 0.15, z, z * 0.0 + x + y) * 2.6 + 0.01 * noise3(P, 0.03))[m]
    c.strp[m, 1] = 0.5
    # steel: dark painted, chipped bright, rust in the seams
    for part, base in ((STEEL, (74, 76, 80)), (LEG, (86, 88, 94))):
        m = c.mask(part)
        st = srgb(*base) * (1.0 + 0.1 * mott)[:, None]
        st = st + (srgb(170, 170, 172) - st) * (c.wear * 0.55)[:, None]
        st = st + (srgb(120, 64, 30) - st) * (smooth(0.2, 0.7, c.cavity) * grime * 0.7)[:, None]
        put(m, st, 0.42 + 0.2 * grime, metal=0.85, bump=0.15, grain=1.0)
        spk(m, (112, 60, 28), 0.22)
    m = c.mask(RIVET)
    put(m, srgb(176, 176, 180) * (1.0 - 0.4 * c.cavity)[:, None], 0.3, metal=1.0)
    m = c.mask(JOINT)
    put(m, srgb(150, 152, 158) * (1.0 - 0.5 * c.cavity)[:, None], 0.28, metal=1.0, bump=0.05, grain=1.0)
    m = c.mask(BEZEL)
    put(m, srgb(30, 31, 34) + (srgb(90, 90, 96) - srgb(30, 31, 34)) * (c.wear * 0.7)[:, None], 0.4, metal=0.3, bump=0.1, grain=1.0)
    m = c.mask(GAITER)
    put(m, srgb(36, 36, 38) * (0.6 + 0.4 * c.ao)[:, None], 0.6, bump=0.3, grain=1.0)
    c.strp[m, 0] = (z * 1.9)[m]
    c.strp[m, 1] = 1.0
    m = c.mask(RUBBER)
    rb = srgb(32, 32, 34) + (srgb(96, 92, 86) - srgb(32, 32, 34)) * (c.wear * 0.6)[:, None]
    put(m, rb, 0.8, bump=0.5, grain=1.0)
    m = c.mask(ANT)
    put(m, srgb(196, 198, 206), 0.22, metal=1.0)
    spr = c.mask(STEEL) & (np.linalg.norm(P[:, :2] - TAIL_ROOT[:2], axis=1) < 0.02) & (z > TAIL_ROOT[2] + 0.012)
    c.strp[spr, 0] = (z * 2.6)[spr]
    c.strp[spr, 1] = 1.0
    m = c.mask(BALL)
    put(m, srgb(240, 120, 24) * (1.0 + 0.3 * c.wear)[:, None], 0.25)

    # the bundle: coarse burlap (weave), patched, darker in its folds; the rope pale and fibrous
    # the bedroll: olive-brown army wool, cream and red stripes near its ends, the rolled layers inked in a spiral on each end; leather straps
    m = c.mask(SACK)
    sk = srgb(120, 96, 60) * (1.0 + 0.1 * mott)[:, None]
    ax_ = np.abs(x)
    sk = np.where(((np.abs(ax_ - 0.17) < 0.012) | (np.abs(ax_ - 0.145) < 0.005))[:, None], srgb(220, 206, 170)[None, :], sk)
    sk = np.where((np.abs(ax_ - 0.157) < 0.004)[:, None], srgb(170, 50, 36)[None, :], sk)
    sk = sk + (srgb(170, 150, 110) - sk) * (c.wear * 0.3)[:, None]
    put(m, sk, 0.95, bump=1.0)
    spk(m, (84, 64, 40), 0.35)
    ends = m & (ax_ > ROLL_L - 0.012)
    rr_ = np.sqrt((y - SACK_C[1]) ** 2 + (z - SACK_C[2]) ** 2)
    th = np.arctan2(z - SACK_C[2], y - SACK_C[1])
    spiral = np.abs(((rr_ - 0.012 * th / (2 * np.pi)) % 0.012) - 0.006)
    c.draw(ends & (rr_ < ROLL_R - 0.004), spiral, 0.0012, 0.75)
    m = c.mask(ROPE)
    put(m, srgb(96, 60, 32) + (srgb(160, 120, 80) - srgb(96, 60, 32)) * (c.wear * 0.6)[:, None], 0.5, bump=0.8, grain=1.0)

    # the screen: a cyan face on a dark blue-green tube: two big oval eyes looking up a little, a red smile; bloom, scanlines, vignette, a reflection
    m = c.mask(SCREEN)
    u = x - SCR_C[0]
    v = z - SCR_C[2]
    col = np.broadcast_to(srgb(10, 22, 28), (n, 3)).copy()
    corner = np.sqrt((u / SCR_HALF[0]) ** 4 + (v / SCR_HALF[1]) ** 4)
    col = col * (1.0 - 0.6 * smooth(0.55, 1.0, corner))[:, None]
    col = col + (srgb(24, 50, 60) - col) * (smooth(0.9, 0.2, corner) * 0.6)[:, None]

    def oval(cx, cz, rx, rz):
        return (np.sqrt(((u - cx) / rx) ** 2 + ((v - cz) / rz) ** 2) - 1.0) * min(rx, rz)

    def arc(cx, cz, r, a0, a1, w):
        a = np.arctan2(v - cz, u - cx)
        mid, half = (a0 + a1) * 0.5, (a1 - a0) * 0.5
        da = np.angle(np.exp(1j * (a - mid)))
        on = np.abs(da) <= half
        dr = np.abs(np.sqrt((u - cx) ** 2 + (v - cz) ** 2) - r)
        e0 = np.sqrt((u - cx - r * np.cos(a0)) ** 2 + (v - cz - r * np.sin(a0)) ** 2)
        e1 = np.sqrt((u - cx - r * np.cos(a1)) ** 2 + (v - cz - r * np.sin(a1)) ** 2)
        return np.where(on, dr, np.minimum(e0, e1)) - w
    eyes = np.minimum(oval(0.062, 0.018, 0.034, 0.044), oval(-0.062, 0.018, 0.034, 0.044))
    pupils = np.minimum(oval(0.058, 0.03, 0.014, 0.02), oval(-0.066, 0.03, 0.014, 0.02))
    smile = arc(0.0, -0.012, 0.03, np.radians(-150), np.radians(-30), 0.0055)
    glow = smooth(0.02, 0.0, np.minimum(eyes, smile))
    col = col + (srgb(40, 120, 140) - col) * (glow * 0.5)[:, None]
    eye_c = srgb(150, 236, 255) + (srgb(230, 252, 255) - srgb(150, 236, 255)) * smooth(-0.004, -0.02, eyes)[:, None]
    col = col + (eye_c - col) * smooth(0.0012, -0.0012, eyes)[:, None]
    col = col + (srgb(16, 60, 80) - col) * smooth(0.0012, -0.0012, np.maximum(pupils, eyes))[:, None]
    for sx in (1, -1):
        gd = np.sqrt((u - sx * 0.062 + 0.012 - (0.004 if sx < 0 else 0.0)) ** 2 + (v - 0.04) ** 2)
        col = col + (srgb(255, 255, 255) - col) * smooth(0.0075, 0.0045, gd)[:, None]
    col = col + (srgb(255, 70, 60) - col) * smooth(0.0012, -0.0012, smile)[:, None]
    col = col + (srgb(140, 30, 26) - col) * (smooth(0.016, 0.0, smile) * 0.4 * (smile > 0.0012))[:, None]
    # pink cheeks
    for sx in (1, -1):
        ck = np.sqrt(((u - sx * 0.108) / 0.022) ** 2 + ((v + 0.022) / 0.011) ** 2)
        col = col + (srgb(200, 80, 110) - col) * (smooth(1.0, 0.4, ck) * 0.55)[:, None]
    refl = smooth(0.03, 0.0, np.abs((u + 0.05) * 0.55 + (v - 0.05))) * smooth(-0.17, -0.07, u) * smooth(0.0, 0.07, v)
    col = col + (srgb(130, 160, 170) - col) * (refl * 0.35)[:, None]
    put(m, col, 0.06)
    c.strp[m, 0] = (v * 2.4)[m]
    c.strp[m, 1] = 0.55

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    scr = c.mask(SCREEN)
    c.col[scr] /= (0.35 + 0.65 * c.ao[scr])[:, None] ** 0.7
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"crate": 3600, "sack": 1300, "legs": 3200, "tail": 300},
    "density": {"crate": 1.4, "tail": 0.6},
    "tex": 2048,
    "stride": {"walk": 0.55, "run": 0.9},
    "speed": 0.9,
    "look": [], "neck": "none",           # its face is the crate itself: it turns its whole body to look, never a part of it
    "look_pivot": (0.0, 0.0, 0.6),
    "radius": 0.36,
}
LEGS = (("f", HIP_F, KNEE_F, ANK_F), ("b", HIP_B, KNEE_B, ANK_B))


def rig_bones():
    from kit.rig import Bone, mirror
    bones = [
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("body", (0, 0, 0.4), (0, 0, 0.8), "root", 0.3),
        Bone("sack", (0.0, 0.03, 0.8), (0.0, 0.03, 0.99), "body", 0.15),
        Bone("tail", TAIL_ROOT, TAIL_MID, "body", 0.01),
        Bone("tail_tip", TAIL_MID, TAIL_TIP + (TAIL_TIP - TAIL_MID) * 0.3, "tail", 0.02),
    ]
    legs = []
    for k, h, kn, a in LEGS:
        legs += [Bone("thigh_%s.L" % k, h, kn, "body", 0.027), Bone("shin_%s.L" % k, kn, a, "thigh_%s.L" % k, 0.024),
                 Bone("foot_%s.L" % k, a, a + v3((0, -0.06, -0.03)), "shin_%s.L" % k, 0.04)]
    return bones + mirror(legs)


def skin_rules(P, part, piece, names):
    """piece: 0 crate, 1 sack, 2 legs, 3 tail"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    A[:, ix["body"]] = True
    rig[piece == 0] = ix["body"]
    rig[piece == 1] = ix["sack"]
    tp = piece == 3
    rig[tp & (np.isin(part, (STEEL,)))] = ix["body"]
    A[tp, ix["tail"]] = True
    A[tp, ix["tail_tip"]] = True
    lp = piece == 2
    for k, sy in (("f", -1), ("b", 1)):
        for s, sx in (("L", 1), ("R", -1)):
            mm = lp & (sx * x > 0) & (sy * y > 0)
            for b in ("thigh", "shin", "foot"):
                A[mm, ix["%s_%s.%s" % (b, k, s)]] = True
            rig[mm & (z > 0.36)] = ix["body"]
            rig[mm & (z < 0.055)] = ix["foot_%s.%s" % (k, s)]
    return A, rig


def motions(rig):
    """walk: a skittery trot (diagonal pairs), the crate bobbing twice a cycle and rocking a little, the bundle bouncing behind the beat, the antenna wagging;
    run: a bounding gallop (front pair, then back pair), the crate pitching; idle: weight shifts, a happy double bounce, a curious tilt, the antenna wagging"""
    import math
    from kit.gait import Pose, R, TAU, ease
    from mathutils import Vector

    def legs_at(p, u, S, beta, lift, phases, flat=0.0):
        """each leg's foot by phase: planted and sliding back through its stance, lifted forward through its swing"""
        for k, h, kn, a in LEGS:
            for s, sx in (("L", 1.0), ("R", -1.0)):
                ph = phases[(k, s)]
                uu = (u + ph) % 1.0
                rest = Vector((sx * a[0], a[1], a[2]))
                if uu < beta:
                    fy = -S * beta / 2 + S * uu
                    lz = 0.0
                    pitch = 0.0
                else:
                    t = (uu - beta) / (1.0 - beta)
                    fy = S * beta / 2 - S * beta * ease(t)
                    lz = lift * math.sin(math.pi * t) ** 0.8
                    pitch = -flat * math.sin(math.pi * t)
                tgt = rest + Vector((0.0, fy, lz))
                pole = Vector((0.0, 1.0 if k == "f" else -1.0, 0.0))
                p.ik["thigh_%s.%s" % (k, s)] = (tgt, pole, "foot_%s.%s" % (k, s), R(pitch, 0, 0))

    trot = {("f", "L"): 0.0, ("b", "R"): 0.0, ("f", "R"): 0.5, ("b", "L"): 0.5}

    def walk_pose(u):
        p = Pose()
        legs_at(p, u, 0.55, 0.5, 0.06, trot, 18.0)
        bob = math.cos(2 * TAU * (u - 0.25))
        p.offset = Vector((0.006 * math.sin(TAU * u), 0.0, -0.045 + 0.014 * bob))
        p.rot("body", 1.5 * math.sin(2 * TAU * u), 2.2 * math.sin(TAU * u), 2.0 * math.cos(TAU * u))
        lag = math.cos(2 * TAU * (u - 0.25) - 1.3)
        p.rot("sack", -3.0 * lag, 2.0 * math.sin(TAU * u - 1.0), 0)
        wag = math.sin(TAU * u * 2.0)
        p.rot("tail", -8.0, 0, 26.0 * wag)
        p.rot("tail_tip", 0, 0, 22.0 * math.sin(TAU * u * 2.0 - 1.1))
        return p

    gallop = {("f", "L"): 0.0, ("f", "R"): 0.08, ("b", "L"): 0.5, ("b", "R"): 0.58}

    def run_pose(u):
        p = Pose()
        legs_at(p, u, 0.9, 0.36, 0.1, gallop, 25.0)
        p.offset = Vector((0.0, 0.0, -0.05 + 0.03 * math.cos(2 * TAU * (u - 0.2))))
        p.rot("body", 7.0 * math.sin(TAU * u + 0.6) + 3.0, 0, 0)
        p.rot("sack", -9.0 * math.cos(TAU * u - 0.7), 0, 0)
        p.rot("tail", -25.0 + 10.0 * math.sin(TAU * u), 0, 14.0 * math.sin(2 * TAU * u))
        p.rot("tail_tip", -12.0 * math.sin(TAU * u - 1.0), 0, 0)
        return p

    walk = [walk_pose(i / 32.0) for i in range(33)]
    run = [run_pose(i / 24.0) for i in range(25)]

    still = {k: 0.0 for k in trot}
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        legs_at(p, 0.25, 0.0, 1.0, 0.0, still)          # stance at its middle, nothing sliding: every foot planted at rest
        # a happy double bounce at 1.6 s, a curious tilt at 3.6 s, settling; breathing-like hum otherwise
        b = 0.0
        for t0 in (1.6, 1.95):
            dt = (t - t0) / 0.32
            if 0.0 < dt < 1.0:
                b += math.sin(math.pi * dt)
        tilt = ease((t - 3.4) / 0.35) * (1.0 - ease((t - 4.9) / 0.5))
        sway = math.sin(TAU * t / 6.0)
        p.offset = Vector((0.006 * sway, 0.0, -0.035 - 0.03 * b + 0.003 * math.sin(TAU * t / 2.0)))
        p.rot("body", -3.0 * b + 2.5 * tilt, 7.0 * tilt + 1.0 * sway, -4.0 * tilt)
        p.rot("sack", 4.0 * math.sin(TAU * max(0.0, t - 1.6) / 0.35) * math.exp(-max(0.0, t - 1.6) * 2.5) * (t > 1.6), 0, 0)
        wag = (0.4 + 0.6 * ease((t - 1.3) / 0.3) * (1.0 - ease((t - 2.8) / 0.6))) * math.sin(TAU * t * 2.2)
        wag = wag * (1.0 - tilt * 0.7) + 0.3 * tilt * math.sin(TAU * t * 0.7)
        # make the wag loop cleanly over the 6 s clip (2.2 Hz does not: fade it to the slow wave at the ends)
        edge = ease(t / 0.4) * (1.0 - ease((t - 5.6) / 0.4))
        wag = wag * edge + (1.0 - edge) * 0.4 * math.sin(TAU * t / 0.5)
        p.rot("tail", -6.0, 0, 24.0 * wag)
        p.rot("tail_tip", 0, 0, 18.0 * wag)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
