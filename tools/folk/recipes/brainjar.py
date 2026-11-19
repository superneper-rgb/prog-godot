## FOINT CITY townsfolk: the brain in a jar (brainjar). A specimen jar of green fluid with a brain floating in it, carried on a little reverse-jointed walker; one eye up on a fleshy stalk, looking about.
# Upgrade of the three.js folk species "brainjar" (progalpha levels/hub/folk-species-c.js; old render refs/old/brainjar.png): kept the dark walker base with its
# green status light, the two legs with flat feet and two little arms, the jar of pale cyan fluid with a pink brain, the four rods to a grey lid, the pink stalk
# with a green-eyed eyeball on top. 1.40 m to the top of the eye.
# Glass in the game is opaque (the folk shader has no transparency): the jar is painted with what is inside it, seen through the fluid (paint() casts a ray in
# from every point of the glass into a brain that exists only for the paint), so the brain reads from every side and costs no triangles.
# Moves: quick little mech steps on reverse knees, the jar sloshing behind the beat, the stalk swaying, the eye glancing about and blinking (its upper lid has a bone).
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.40
REF = ("old/brainjar.png", None)

GLASS, STEEL, BRASS, PAINT, LIGHT, HOSE, LEG, JOINT, RUBBER, FLESH, EYE, LID, CLAW, HAZARD, BOLT = range(1, 16)
COLOURS = {
    GLASS: ((0.45, 0.75, 0.7), 0.05, 0.0),
    STEEL: ((0.45, 0.47, 0.5), 0.3, 1.0),
    BRASS: ((0.75, 0.55, 0.25), 0.3, 1.0),
    PAINT: ((0.24, 0.28, 0.32), 0.5, 0.0),
    LIGHT: ((0.3, 1.0, 0.5), 0.2, 0.0),
    HOSE: ((0.12, 0.12, 0.13), 0.6, 0.0),
    LEG: ((0.3, 0.32, 0.35), 0.4, 1.0),
    JOINT: ((0.55, 0.56, 0.58), 0.3, 1.0),
    RUBBER: ((0.04, 0.04, 0.04), 0.8, 0.0),
    FLESH: ((0.8, 0.45, 0.5), 0.5, 0.0),
    EYE: ((0.95, 0.93, 0.88), 0.15, 0.0),
    LID: ((0.78, 0.42, 0.48), 0.5, 0.0),
    CLAW: ((0.35, 0.36, 0.38), 0.35, 1.0),
    HAZARD: ((0.9, 0.7, 0.1), 0.5, 0.0),
    BOLT: ((0.6, 0.6, 0.62), 0.3, 1.0),
}

# the walker's body (the chassis) and the jar on it
CH_C = v3((0.0, 0.0, 0.5))
CH_H = v3((0.175, 0.15, 0.068))
JAR_A, JAR_B, JAR_R = 0.6, 1.08, 0.163        # glass bottom, top, radius
LID_Z = 1.12
# the eye on its stalk
STALK = [v3((0.0, 0.0, 1.15)), v3((0.0, 0.004, 1.215)), v3((0.0, -0.012, 1.265))]
EYE_C = v3((0.0, -0.03, 1.322))
EYE_R = 0.066
# legs (left side): hip on the chassis side, the knee bending backward, the ankle under the hip
HIP = v3((0.152, 0.005, 0.468))
KNEE = v3((0.168, 0.095, 0.272))
ANKLE = v3((0.168, 0.0, 0.074))
# arms (left side): from the chassis's front corner, hanging forward and down to a claw
SHOULDER = v3((0.19, -0.075, 0.5))
ELBOW = v3((0.235, -0.1, 0.39))
WRIST = v3((0.235, -0.135, 0.3))


def frame_along(a, b, up=(0, 0, 1)):
    """rotation whose local Z runs from a to b (local Y leans to `up`)"""
    return basis(b - a, v3(up) if abs((v3(b) - v3(a))[2]) < 0.9 * np.linalg.norm(v3(b) - v3(a)) else v3((0, 1, 0)))


def strut(a, b, w, d, rr, part):
    """a flat-sided strut from a to b, w wide (across X), d deep"""
    a, b = v3(a), v3(b)
    L = float(np.linalg.norm(b - a))
    zd = (b - a) / L
    R = basis(zd, v3((0, 1, 0)) if abs(zd[1]) < 0.9 else v3((1, 0, 0)))
    return Box((a + b) * 0.5, (w, d, L * 0.5 + rr), rr=rr, R=R, part=part)


def hinge(c, r, half_w, part):
    """a hinge drum along X"""
    return CappedCone(v3(c) - v3((half_w, 0, 0)), v3(c) + v3((half_w, 0, 0)), r, r, rr=min(0.006, r * 0.3), part=part)


# ---------------------------------------------------------------------------------------------------- the jar and its frame

def jar():
    return CappedCone((0, 0, JAR_A - 0.02), (0, 0, JAR_B), JAR_R, JAR_R, rr=0.045, part=GLASS)


def frame():
    chassis = Box(CH_C, CH_H, rr=0.045, part=PAINT)
    chassis = Bump(chassis, lambda P: 1.0 - (P[:, 0] / 0.19) ** 2 - (P[:, 1] / 0.17) ** 2 - ((P[:, 2] - CH_C[2]) / 0.08) ** 2, 0.004)      # (no dead-flat faces: the decimator flips them)
    skirt = Clip(Inflate(Box(CH_C, CH_H, rr=0.045), 0.006, part=HAZARD), [Half((0, 0, 0.462), (0, 0, 1))], k=0.003)
    chassis = Union([chassis, skirt], k=0.0)
    # a front panel: the status light strip and two little gauges
    panel = Box((0.0, -0.152, 0.51), (0.11, 0.012, 0.032), rr=0.01, part=STEEL)
    light = Box((0.0, -0.163, 0.515), (0.055, 0.006, 0.0085), rr=0.005, part=LIGHT)
    gauges = Mirror(CappedCone((0.085, -0.155, 0.505), (0.085, -0.17, 0.505), 0.018, 0.016, rr=0.004, part=BRASS))
    # the jar's collar: a bolted steel ring; the lid: a domed cap with a brass rim and bolts
    collar = CappedCone((0, 0, 0.555), (0, 0, 0.62), 0.198, 0.19, rr=0.012, part=STEEL)
    bolts = [Sphere((0.2 * np.cos(a), 0.2 * np.sin(a), 0.59), 0.009, part=BOLT) for a in np.linspace(0, 2 * np.pi, 12, endpoint=False)]
    lid = Union([CappedCone((0, 0, 1.065), (0, 0, 1.125), 0.188, 0.182, rr=0.012, part=STEEL),
                 Ellipsoid((0, 0, 1.12), (0.15, 0.15, 0.042), part=STEEL)], k=0.012)
    rim = Torus((0, 0, 1.09), 0.188, 0.008, part=BRASS)
    lbolts = [Sphere((0.182 * np.cos(a), 0.182 * np.sin(a), 1.115), 0.008, part=BOLT) for a in np.linspace(0, 2 * np.pi, 12, endpoint=False)]
    grommet = Torus((0, 0, 1.158), 0.03, 0.01, part=BRASS)
    # four rods outside the glass, collar to lid
    rods = [RoundCone((0.192 * np.cos(a), 0.192 * np.sin(a), 0.6), (0.192 * np.cos(a), 0.192 * np.sin(a), 1.075), 0.0095, 0.0095, part=STEEL)
            for a in np.radians([45, 135, 225, 315])]
    collar = Union([collar] + rods + [lid], k=0.012, part=STEEL)          # the rods filleted into the collar and the lid
    rods = []
    # two ribbed hoses from the chassis's back up behind the jar to the lid
    hoses = []
    for sx in (-1, 1):
        pts = [(v3((sx * 0.085, 0.14, 0.53)), 0.017), (v3((sx * 0.1, 0.235, 0.62)), 0.017), (v3((sx * 0.105, 0.245, 0.84)), 0.017),
               (v3((sx * 0.095, 0.215, 1.02)), 0.017), (v3((sx * 0.085, 0.165, 1.1)), 0.017)]
        hoses.append(loft(pts, part=HOSE, k=0.02))
    hose = Union(hoses)          # (its ribs are painted)
    cuffs = [CappedCone(v3((sx * 0.085, 0.13, 0.52)), v3((sx * 0.086, 0.15, 0.545)), 0.024, 0.024, rr=0.004, part=BRASS) for sx in (-1, 1)]
    cuffs += [CappedCone(v3((sx * 0.083, 0.175, 1.095)), v3((sx * 0.085, 0.155, 1.105)), 0.024, 0.024, rr=0.004, part=BRASS) for sx in (-1, 1)]
    # hip and shoulder mounts
    mounts = Mirror(Union([hinge(HIP, 0.04, 0.03, JOINT), hinge(SHOULDER, 0.022, 0.02, JOINT)]))
    return Union([chassis, panel, light, gauges, collar, rim, grommet, hose, mounts] + bolts + lbolts + rods + cuffs, k=0.0)


# ---------------------------------------------------------------------------------------------------- the walker's limbs

def leg():
    thigh = strut(HIP, KNEE, 0.022, 0.03, 0.012, LEG)
    piston = RoundCone(HIP + v3((0.022, -0.035, -0.02)), KNEE + v3((0.022, -0.03, 0.03)), 0.012, 0.009, part=JOINT)      # (overlapping the strut: a thin gap bakes black)
    shin = strut(KNEE, ANKLE, 0.018, 0.024, 0.01, LEG)
    knee = hinge(KNEE, 0.034, 0.028, JOINT)
    ankle = hinge(ANKLE, 0.026, 0.025, JOINT)
    # a three-toed foot: two toes forward, a spur back, rubber pads under them
    toes = [loft([(ANKLE + v3((0.0, 0.0, -0.02)), 0.018), (v3((ANKLE[0] + sx * 0.03, -0.075, 0.022)), 0.015), (v3((ANKLE[0] + sx * 0.04, -0.115, 0.016)), 0.013)], part=LEG, k=0.008)
            for sx in (-1, 1)]
    spur = loft([(ANKLE + v3((0.0, 0.0, -0.02)), 0.017), (v3((ANKLE[0], 0.06, 0.02)), 0.013)], part=LEG, k=0.008)
    pads = [Clip(Ellipsoid(v3((ANKLE[0] + sx * 0.04, -0.105, 0.012)), (0.022, 0.03, 0.016), part=RUBBER), [Half((0, 0, 0), (0, 0, -1))], k=0.003) for sx in (-1, 1)]
    pads.append(Clip(Ellipsoid(v3((ANKLE[0], 0.055, 0.012)), (0.02, 0.024, 0.015), part=RUBBER), [Half((0, 0, 0), (0, 0, -1))], k=0.003))
    foot = Union(toes + [spur], k=0.012, part=LEG)
    return Union([Union([thigh, shin], k=0.0), piston, knee, ankle, foot] + pads, k=0.0)


def claw():
    """a two-fingered pincer in hand space (wrist at the origin, fingers down -Z, the pincers opening in Y)"""
    hub = Union([CappedCone((0, 0, 0.012), (0, 0, -0.03), 0.022, 0.02, rr=0.006, part=CLAW), hinge((0, 0, -0.035), 0.016, 0.022, JOINT)], k=0.0)
    fingers = []
    for sy in (-1, 1):
        pts = [(v3((0, sy * 0.012, -0.035)), 0.011), (v3((0, sy * 0.03, -0.065)), 0.0095), (v3((0, sy * 0.022, -0.095)), 0.008), (v3((0, sy * 0.006, -0.11)), 0.006)]
        fingers.append(loft(pts, part=CLAW, k=0.006))
    return Union([hub] + fingers, k=0.004)


def arm():
    upper = RoundCone(SHOULDER, ELBOW, 0.015, 0.013, part=LEG)
    fore = RoundCone(ELBOW, WRIST, 0.013, 0.012, part=LEG)
    elbow = Sphere(ELBOW, 0.02, part=JOINT)
    R = basis(-(WRIST - ELBOW), v3((1, 0, 0)))
    return Union([upper, fore, elbow, place(claw(), WRIST, R)], k=0.0)


# ---------------------------------------------------------------------------------------------------- the eye

LID_OPEN = 0.004          # where the upper lid's edge plane crosses above the eye's centre: its edge just over the iris (a sceptical look)


def stalk():
    s = loft([(STALK[0], 0.028), (STALK[1], 0.023), (STALK[2], 0.02), (EYE_C + v3((0, 0.03, -0.035)), 0.022)], part=FLESH, k=0.02)
    s = Bump(s, lambda P: noise3(P, 0.02), 0.0012)
    # the socket: a fleshy cup round the back of the eyeball where the stalk holds it; the lower lid a crescent under its front
    shell = Ellipsoid(EYE_C, (EYE_R + 0.0065, EYE_R + 0.0065, EYE_R + 0.0065), part=FLESH)
    back = Clip(shell, [Half(EYE_C + v3((0, 0.008, 0.0)), (0, -1, 0.2)), Half(EYE_C + v3((0, 0, 0.012)), (0, 0.3, 1.0))], k=0.008)      # (below the lid's reach)
    lower = Clip(Ellipsoid(EYE_C, (EYE_R + 0.0055, EYE_R + 0.0055, EYE_R + 0.005), part=FLESH), [Half(EYE_C + v3((0, 0, -0.038)), (0, 0.3, 1.0))], k=0.006)
    # (solid, its inside hidden in the eyeball: a thin gap between two surfaces of one piece breaks the mesher and the decimator)
    return Union([s, back, lower], k=0.012)


def eyeball():
    return Sphere(EYE_C, EYE_R, part=EYE)


def lid():
    """the upper lid: a shell over the top of the eyeball, on its own bone (it blinks)"""
    shell = Cut(Ellipsoid(EYE_C, (EYE_R + 0.0072, EYE_R + 0.0072, EYE_R + 0.0072), part=LID), [Sphere(EYE_C, EYE_R + 0.0024)], k=0.0)
    # a thin hood over the top, its edge across the front of the eye (lashes inked along it), rounded
    return Clip(shell, [Half(EYE_C + v3((0, 0, LID_OPEN)), (0, -0.45, -1.0))], k=0.006)


def pieces():
    limbs = Mirror(Union([leg(), arm()]))
    return [("jar", jar(), 0.0018), ("frame", frame(), 0.0024), ("limbs", limbs, 0.002), ("stalk", stalk(), 0.0016), ("eyeball", eyeball(), 0.0015),
            ("lid", lid(), 0.0013)]


# ---------------------------------------------------------------------------------------------------- paint

BRAIN_C = v3((0.0, 0.0, 0.84))


def brain_sdf():
    """the brain in the jar (paint only): two hemispheres split by their fissure, temporal lobes, the cerebellum, the stem down to the base, folded all over"""
    hemis = Union([Ellipsoid(BRAIN_C + v3((sx * 0.04, 0.0, 0.0)), (0.048, 0.1, 0.07)) for sx in (-1, 1)], k=0.012)
    temporal = Union([Ellipsoid(BRAIN_C + v3((sx * 0.052, -0.018, -0.045)), (0.036, 0.066, 0.036)) for sx in (-1, 1)], k=0.01)
    cer = Ellipsoid(BRAIN_C + v3((0, 0.075, -0.06)), (0.066, 0.04, 0.034))
    stem = RoundCone(BRAIN_C + v3((0, 0.035, -0.055)), v3((0, 0.03, JAR_A + 0.02)), 0.024, 0.017)
    b = Union([hemis, temporal, cer, stem], k=0.018)
    b = Cut(b, [Box(BRAIN_C + v3((0, -0.01, 0.05)), (0.0035, 0.12, 0.06), rr=0.002)], k=0.006)
    return Bump(b, gyri, -0.0055)


def gyri(P):
    """worm-like gyri with narrow sulci between: 1 in the crevices (the bump pushes in there)"""
    q = noise3(P, 0.035) * 12.0 + noise3(P + 5.0, 0.012) * 1.5
    return np.clip(1.0 - np.abs(np.sin(q)) * 4.0, 0.0, 1.0)


def paint(c):
    from kit.paint import srgb, smooth
    P, N = c.P, c.N
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
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

    # the jar: cast a ray in from each point of the glass (along its inward normal) through the fluid; where it meets the brain, the brain's colour lit
    # from above, fogged by the fluid it went through; elsewhere the fluid, deeper toward the middle; bubbles; two studio highlights on the glass
    m = c.mask(GLASS)
    if m.any():
        G = P[m]
        Nh = N[m].copy()
        Nh[:, 2] = 0.0
        br = brain_sdf()
        fluid = srgb(70, 200, 168)
        deep = srgb(16, 96, 92)
        acc = np.zeros((len(G), 3), np.float32)
        wsum = np.zeros(len(G), np.float32)
        # four parallel projections (from the front, back, left and right), blended by which way the glass faces: through a cylinder of fluid the
        # brain shows as a rounded thing with its own outline from any side (rays to the axis would smear it into a band all round)
        for ax in ((1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0)):
            a = v3(ax)
            w = np.clip(Nh @ a, 0.0, 1.0) ** 6
            sel = w > 0.01
            if not sel.any():
                continue
            O = G[sel]
            D = np.broadcast_to(-a, O.shape).astype(np.float32)
            t = np.full(len(O), 0.003, np.float32)
            hit = np.zeros(len(O), bool)
            for _ in range(60):
                d = br.eval(O + D * t[:, None])[0]
                hit |= d < 0.0008
                t = np.where(hit, t, t + np.clip(d * 0.85, 0.0015, 0.01))      # (capped: far from every part the field reads 1000)
                if (hit | (t > 0.4)).all():
                    break
            hit &= t < 0.36
            H = O + D * t[:, None]
            e = 0.002
            gx = np.stack([br.eval(H + v3(o))[0] - br.eval(H - v3(o))[0] for o in ((e, 0, 0), (0, e, 0), (0, 0, e))], 1)
            Nb = gx / np.maximum(np.linalg.norm(gx, axis=1, keepdims=True), 1e-6)
            L = -a * 0.55 + v3((0.25, 0.0, 0.8))
            L /= np.linalg.norm(L)
            lam = np.clip(Nb @ L, 0, 1)
            fold = gyri(H)
            bcol = srgb(240, 160, 168) * (0.35 + 0.75 * lam)[:, None]
            bcol = bcol * (1.0 - 0.5 * np.clip(1.0 - np.abs(Nb @ a), 0, 1) ** 2)[:, None]
            bcol = bcol + (srgb(120, 40, 70) - bcol) * (0.65 * fold)[:, None]
            stem = H[:, 2] < BRAIN_C[2] - 0.085
            bcol[stem] = srgb(206, 130, 140) * (0.45 + 0.55 * lam[stem])[:, None]
            depth = np.clip(t / 0.33, 0, 1)
            fcol = fluid + (deep - fluid) * smooth(0.0, 1.0, depth)[:, None]
            col = np.where(hit[:, None], bcol + (fluid * 0.5 - bcol) * (0.2 + 0.45 * smooth(0.05, 0.25, t))[:, None], fcol)
            acc[sel] += col * w[sel, None]
            wsum[sel] += w[sel]
        col = np.where((wsum > 0.05)[:, None], acc / np.maximum(wsum, 1e-6)[:, None], fluid * 0.8)
        # bubbles: little rings rising, a few clusters
        bub = np.zeros(len(G), np.float32)
        rng = np.random.default_rng(7)
        for _ in range(26):
            a_ = rng.uniform(0, 2 * np.pi)
            bz = rng.uniform(JAR_A + 0.04, JAR_B - 0.04)
            bc = v3((JAR_R * np.cos(a_), JAR_R * np.sin(a_), bz))
            rr = rng.uniform(0.004, 0.011)
            dd = np.linalg.norm(G - bc, axis=1)
            bub = np.maximum(bub, smooth(rr, rr * 0.55, dd) - smooth(rr * 0.6, rr * 0.25, dd) * 0.6)
        col = col + (srgb(220, 255, 240) - col) * (bub * 0.75)[:, None]
        # the glass: two vertical highlights, the meniscus under the lid, an air gap above it, grime at the bottom
        ang = np.arctan2(G[:, 1], G[:, 0])
        hl = smooth(0.11, 0.02, np.abs(np.angle(np.exp(1j * (ang - np.radians(-125)))))) * 0.55
        hl += smooth(0.05, 0.0, np.abs(np.angle(np.exp(1j * (ang - np.radians(-62)))))) * 0.3
        hl *= smooth(JAR_A + 0.02, JAR_A + 0.1, G[:, 2]) * smooth(JAR_B - 0.0, JAR_B - 0.08, G[:, 2])
        col = col + (srgb(235, 255, 250) - col) * np.clip(hl, 0, 1)[:, None]
        men = smooth(0.012, 0.0, np.abs(G[:, 2] - (JAR_B - 0.045)))
        col = col + (srgb(200, 255, 230) - col) * (men * 0.5)[:, None]
        top = G[:, 2] > JAR_B - 0.045
        col[top] = col[top] * 0.5 + srgb(60, 90, 86) * 0.5
        col = col * (1.0 - 0.3 * smooth(JAR_A + 0.06, JAR_A - 0.01, G[:, 2]))[:, None]
        c.col[m] = col
        c.rough[m] = 0.05
        c.metal[m] = 0.0
        c.bump[m] = 0.0

    # the walker: dark gunmetal paint chipped to steel, hazard stripes round the skirt, grime from the street
    m = c.mask(PAINT)
    pc = srgb(64, 74, 84) * (1.0 + 0.08 * mott)[:, None]
    pc = pc + (srgb(150, 152, 156) - pc) * (c.wear * 0.6)[:, None]
    pc = pc * (1.0 - 0.3 * c.cavity)[:, None]
    put(m, pc, 0.5, metal=0.3, bump=0.2, grain=1.0)
    spk(m, (40, 34, 30), 0.2)
    # vent slots on its back (painted: cut in, small slots cost the decimator dearly)
    vm = m & (y > 0.14) & (np.abs(x) < 0.09) & (np.abs(z - 0.51) < 0.03)
    c.draw(vm, np.abs(((x + 0.08 + 0.016) % 0.032) - 0.016), 0.005, 0.95)
    m = c.mask(HAZARD)
    stripe = ((x + y + z * 0.8) / 0.03) % 2.0 < 1.0
    hz = np.where(stripe[:, None], srgb(232, 176, 30)[None, :], srgb(26, 24, 22)[None, :])
    hz = hz + (srgb(150, 140, 120) - hz) * (c.wear * 0.5)[:, None]
    hz = hz * (1.0 - 0.3 * grime)[:, None]
    put(m, hz, 0.6, bump=0.2, grain=1.0)
    for part, base, metal, rough in ((STEEL, (150, 154, 160), 1.0, 0.32), (LEG, (92, 98, 106), 1.0, 0.38), (CLAW, (110, 112, 118), 1.0, 0.35)):
        m = c.mask(part)
        st = srgb(*base) * (1.0 + 0.1 * mott)[:, None]
        st = st + (srgb(200, 200, 204) - st) * (c.wear * 0.4)[:, None]
        st = st * (1.0 - 0.45 * c.cavity)[:, None]
        st = st + (srgb(110, 70, 40) - st) * (smooth(0.3, 0.8, c.cavity) * grime * 0.5)[:, None]
        put(m, st, rough + 0.15 * grime, metal=metal, bump=0.1, grain=1.0)
    m = c.mask(JOINT)
    put(m, srgb(170, 172, 178) * (1.0 - 0.5 * c.cavity)[:, None], 0.25, metal=1.0, grain=1.0)
    m = c.mask(BOLT)
    put(m, srgb(190, 190, 194) * (1.0 - 0.4 * c.cavity)[:, None], 0.3, metal=1.0)
    m = c.mask(BRASS)
    put(m, srgb(214, 160, 76) * (1.0 - 0.5 * c.cavity)[:, None] * (1.0 - 0.25 * grime)[:, None], 0.3, metal=1.0, bump=0.1, grain=1.0)
    m = c.mask(LIGHT)
    lc = srgb(120, 255, 150) + (srgb(230, 255, 230) - srgb(120, 255, 150)) * smooth(0.006, 0.0, np.abs(z - 0.515))[:, None]
    put(m, lc, 0.1)
    m = c.mask(HOSE)
    put(m, srgb(40, 40, 44) * (0.6 + 0.4 * c.ao)[:, None], 0.55, bump=0.3, grain=1.0)
    c.strp[m, 0] = ((z + 0.4 * y) * 2.0)[m]
    c.strp[m, 1] = 1.0
    m = c.mask(RUBBER)
    put(m, srgb(30, 30, 32) + (srgb(90, 88, 84) - srgb(30, 30, 32)) * (c.wear * 0.6)[:, None], 0.8, bump=0.5, grain=1.0)

    # the stalk and lids: pink flesh, wet, darker in the folds, faint veins
    for part in (FLESH, LID):
        m = c.mask(part)
        fl = srgb(214, 128, 140) * (1.0 + 0.1 * mott)[:, None]
        fl = fl + (srgb(150, 70, 96) - fl) * (smooth(0.0, 0.6, c.cavity) * 0.6)[:, None]
        fl = fl + (srgb(240, 170, 170) - fl) * (c.wear * 0.25)[:, None]
        put(m, fl, 0.3, bump=0.25, grain=1.0)
        spk(m, (176, 84, 108), 0.35)
    m = c.mask(LID)
    ln = v3((0, -0.45, -1.0)) / np.linalg.norm((0, -0.45, -1.0))
    pd = (P - (EYE_C + v3((0, 0, LID_OPEN)))) @ ln
    c.draw(m & (y < EYE_C[1] + 0.01) & (pd > -0.006), np.abs(pd + 0.0015), 0.0016)
    # the eye: a veined white, a big green iris looking straight out, an inked pupil, the lid's shadow over its top, a glint
    m = c.mask(EYE)
    de = P - EYE_C
    r = np.linalg.norm(de, axis=1)
    d = de / np.maximum(r, 1e-6)[:, None]
    fwd = v3((0.0, -1.0, 0.0))
    ang = np.arccos(np.clip(d @ fwd, -1, 1))
    ec = np.broadcast_to(srgb(240, 234, 222), (n, 3)).copy()
    vein = np.abs(np.sin(np.arctan2(d[:, 2], d[:, 0]) * 9.0 + noise3(P, 0.01) * 3.0)) < 0.12
    ec = np.where((vein & (ang > 0.75))[:, None], ec * 0.6 + srgb(200, 60, 60) * 0.4, ec)
    ec = ec + (srgb(200, 170, 170) - ec) * smooth(0.9, 1.6, ang)[:, None]
    iris = smooth(0.52, 0.49, ang)
    ic = srgb(120, 196, 70) + (srgb(30, 96, 40) - srgb(120, 196, 70)) * smooth(0.1, 0.48, ang)[:, None]
    rays = 0.85 + 0.15 * np.sin(np.arctan2(d[:, 2], d[:, 0]) * 26.0)
    ic = ic * rays[:, None]
    ec = ec + (ic - ec) * iris[:, None]
    c.draw(m, (ang - 0.2) * EYE_R, 0.0)
    c.draw(m, np.abs(ang - 0.505) * EYE_R, 0.0005, 0.6)
    ec *= (1.0 - 0.45 * smooth(0.2, 0.5, d[:, 2]))[:, None]
    gl = smooth(0.012, 0.005, (d[:, 0] + 0.25) ** 2 + (d[:, 2] - 0.22) ** 2)
    ec = ec + (srgb(255, 255, 250) - ec) * gl[:, None]
    put(m, ec, 0.06)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    gm = c.mask(GLASS, LIGHT)
    c.col[gm] /= (0.35 + 0.65 * c.ao[gm])[:, None] ** 0.6
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"jar": 1400, "frame": 3200, "limbs": 3000, "stalk": 1000, "eyeball": 600, "lid": 400},
    "density": {"jar": 2.0, "stalk": 1.3, "eyeball": 2.4, "lid": 1.5},
    "tex": 2048,
    "stride": {"walk": 0.62, "run": 1.1},
    "speed": 0.85,
    "look": ["eye", "lid", "stalk_2"], "neck": "stalk_1",
    "look_pivot": (0.0, 0.0, 1.16),
    "radius": 0.3,
}
BALL = v3((0.168, -0.01, 0.0))


def rig_bones():
    from kit.rig import Bone, mirror
    bones = [
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("body", (0, 0, 0.47), (0, 0, 0.6), "root", 0.2),
        Bone("jar", (0, 0, 0.6), (0, 0, 1.12), "body", 0.2),
        Bone("stalk_1", STALK[0], STALK[1], "jar", 0.025),
        Bone("stalk_2", STALK[1], STALK[2], "stalk_1", 0.022),
        Bone("eye", STALK[2], EYE_C + v3((0, -0.05, 0.0)), "stalk_2", 0.07),
        Bone("lid", EYE_C, EYE_C + v3((0, -0.08, 0.0)), "eye", 0.02),
    ]
    limbs = [
        Bone("thigh.L", HIP, KNEE, "body", 0.03),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.03),
        Bone("foot.L", ANKLE, ANKLE + v3((0, -0.1, -0.05)), "shin.L", 0.04),
        Bone("arm.L", SHOULDER, ELBOW, "body", 0.015),
        Bone("fore.L", ELBOW, WRIST, "arm.L", 0.014),
        Bone("claw.L", WRIST, WRIST + (WRIST - ELBOW) * 1.2, "fore.L", 0.02),
    ]
    return bones + mirror(limbs)


def skin_rules(P, part, piece, names):
    """piece: 0 jar, 1 frame, 2 limbs, 3 stalk (with its socket and lower lid), 4 eyeball, 5 lid"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    rig[piece == 0] = ix["jar"]
    fp = piece == 1
    allow(fp, "body", "jar")
    rig[fp & (z < 0.6)] = ix["body"]
    rig[fp & (z >= 0.6) & (part != HOSE)] = ix["jar"]
    # (the hoses bend between the chassis and the lid)
    lp = piece == 2
    for s, sx in (("L", 1), ("R", -1)):
        side = lp & (sx * x > 0)
        arm = side & (y < -0.05) & (z > 0.25) & (sx * x > 0.17)
        leg = side & ~arm
        allow(leg, "body", "thigh.%s" % s, "shin.%s" % s, "foot.%s" % s)
        rig[leg & (z < 0.06)] = ix["foot.%s" % s]
        rig[leg & (z > 0.45)] = ix["body"]
        allow(arm, "body", "arm.%s" % s, "fore.%s" % s, "claw.%s" % s)
        beyond = (P - (WRIST * np.array([sx, 1, 1], np.float32))) @ (v3((0, 0, -1)))
        rig[arm & (beyond > -0.004)] = ix["claw.%s" % s]
    ep = piece == 3
    allow(ep, "jar", "stalk_1", "stalk_2", "eye")
    rig[ep & (np.linalg.norm(P - EYE_C, axis=1) < EYE_R + 0.03)] = ix["eye"]
    rig[ep & (z < 1.165)] = ix["jar"]
    rig[piece == 4] = ix["eye"]
    rig[piece == 5] = ix["lid"]
    return A, rig


def motions(rig):
    """walk: quick short mech steps on reverse knees, the chassis bobbing, the jar sloshing behind the beat, the stalk swaying, the eye glancing;
    run: a scurry, leaning in; idle: the eye looks about (left, up, down at its feet, at you), blinks twice, the claws twitch"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def mech_legs(p, u, g):
        """biped_walk's feet, but the knees bend backward (pole behind)"""
        biped_walk(rig, p, u, g, legs)
        for lg in legs:
            tgt, pole, end, wf = p.ik[lg.thigh]
            p.ik[lg.thigh] = (tgt, Vector((pole[0], 1.0, 0.0)), end, wf)

    def eye_look(p, yaw, pitch, lid_close):
        p.rot("stalk_1", pitch * 0.3, 0, yaw * 0.3)
        p.rot("stalk_2", pitch * 0.3, 0, yaw * 0.3)
        p.rot("eye", pitch * 0.4, 0, yaw * 0.4)
        p.rot("lid", lid_close, 0, 0)          # (about +X: the lid's front edge comes down over the eye)

    WALK = dict(stride=0.62, stance=0.56, foot_x=0.16, lift=0.07, bob=0.016, drop=0.03, sway=0.018, roll=3.0, yaw=4.0, counter=0.4,
                lean=0.0, toe_off=0.0, toe_out=4.0, swing_point=10.0)
    RUN = dict(stride=1.1, stance=0.4, foot_x=0.16, lift=0.11, bob=0.025, drop=0.06, sway=0.012, roll=3.0, yaw=5.0, counter=0.4,
               lean=7.0, toe_off=0.0, toe_out=4.0, swing_point=18.0)

    def walkish(u, g, run):
        p = Pose()
        mech_legs(p, u, g)
        c = math.cos(TAU * u)
        slosh = math.cos(2 * TAU * u - 1.4)
        p.rot("jar", (2.5 if run else 1.5) * slosh, 1.5 * math.sin(TAU * u - 1.0), 0)
        sway = math.sin(TAU * u - 1.6)
        glance = 18.0 * math.sin(TAU * u * 1.0 + 0.4) if not run else 4.0 * sway
        eye_look(p, glance, (8.0 if run else 2.0) - 4.0 * math.cos(2 * TAU * u - 2.0), 8.0 if run else 0.0)
        p.rot("stalk_1", -4.0 * slosh, 3.0 * sway, 0)
        for s, sx in (("L", 1), ("R", -1)):
            p.rot("arm.%s" % s, -sx * 8.0 * c * (1.6 if run else 1.0) + (-20.0 if run else 0.0), 0, 0)
            p.rot("fore.%s" % s, -10.0 - 6.0 * max(0.0, sx * c), 0, 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    keys = [(0.0, 0, 0), (0.6, 0, 0), (0.9, 38, 4), (1.8, 38, 4), (2.1, -30, 14), (2.9, -30, 14), (3.2, 10, -26), (4.0, 10, -26), (4.3, 0, 2), (6.0, 0, 0)]

    def look_at(t):
        for (t0, y0, p0), (t1, y1, p1) in zip(keys[:-1], keys[1:]):
            if t0 <= t <= t1:
                k = ease((t - t0) / max(t1 - t0, 1e-6))
                return y0 + (y1 - y0) * k, p0 + (p1 - p0) * k
        return 0.0, 0.0
    for i in range(181):
        t = i / 30.0
        p = Pose()
        stand(rig, p, legs, {"L": (Vector(BALL.tolist()), 4.0), "R": (Vector((BALL * f).tolist()), -4.0)},
              hip_shift=(0.0, 0.0, -0.022 + 0.004 * math.sin(TAU * t / 3.0)), roll=0.0, yaw=0.0)
        for lg in legs:
            tgt, pole, end, wf = p.ik[lg.thigh]
            p.ik[lg.thigh] = (tgt, Vector((pole[0], 1.0, 0.0)), end, wf)
        yw, pt = look_at(t)
        blink = 0.0
        for tb in (1.95, 4.15, 4.45):
            dt = (t - tb) / 0.09
            if -1.0 < dt < 1.0:
                blink = max(blink, 1.0 - abs(dt))
        eye_look(p, yw, pt, 62.0 * blink + (10.0 if pt < -10 else 0.0) * ease((t - 3.2) / 0.3) * (1 - ease((t - 4.0) / 0.3)))
        p.rot("jar", 0.8 * math.sin(TAU * t / 3.0), 0, 0)
        for s, sx in (("L", 1), ("R", -1)):
            tw = math.sin(TAU * t / 2.0 + (0 if sx > 0 else 1.7))
            p.rot("arm.%s" % s, 3.0 * tw, 0, 0)
            p.rot("claw.%s" % s, 0, 25.0 * max(0.0, math.sin(TAU * (t - (2.4 if sx > 0 else 5.0)) / 0.6)) * (abs(t - (2.55 if sx > 0 else 5.15)) < 0.3), 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
