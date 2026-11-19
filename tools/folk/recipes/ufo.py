## FOINT CITY townsfolk: the little grey in a hover pod (ufo). A dented chrome saucer hovering off the ground on a glowing thruster, running lights round its rim, and in its open cockpit one of the game's grey aliens, small and grumpy, hands on the yoke.
# Upgrade of the three.js folk species "ufo" (progalpha levels/hub/folk-species-d.js; old render refs/old/ufo.png): kept the grey saucer with its darker rim, the
# alternating red and yellow rim lights, the glowing cyan thruster under it, the cockpit coaming, the antenna with a red ball, and the little grey with its
# bald egg head, huge black slanted eyes and a small mouth, sitting in the seat. The grey takes the look of the game's own grey aliens (assets/objects/gray_alien.glb:
# big black eyes in thick lids, a scowl, wrinkles, a little nose and a frown). 1.20 m to the antenna's ball.
# Moves: a bobbing hovering glide, the pod tilting into its way and wobbling, the pilot leaning with it and glancing about.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.20
REF = ("old/ufo.png", None)

HULL, RIM, LAMP_R, LAMP_Y, THRUST, GLOW, PAD, SEAT, YOKE, KNOB, ANT, SKIN, EYE, LID, MOUTH, SUIT = range(1, 17)
COLOURS = {
    HULL: ((0.62, 0.64, 0.66), 0.3, 1.0),
    RIM: ((0.3, 0.32, 0.35), 0.4, 1.0),
    LAMP_R: ((1.0, 0.3, 0.2), 0.2, 0.0),
    LAMP_Y: ((1.0, 0.8, 0.3), 0.2, 0.0),
    THRUST: ((0.15, 0.16, 0.18), 0.5, 1.0),
    GLOW: ((0.4, 0.95, 1.0), 0.2, 0.0),
    PAD: ((0.25, 0.2, 0.32), 0.7, 0.0),
    SEAT: ((0.2, 0.16, 0.26), 0.6, 0.0),
    YOKE: ((0.15, 0.15, 0.17), 0.4, 1.0),
    KNOB: ((0.9, 0.2, 0.15), 0.3, 0.0),
    ANT: ((0.5, 0.5, 0.52), 0.3, 1.0),
    SKIN: ((0.6, 0.62, 0.62), 0.6, 0.0),
    EYE: ((0.02, 0.02, 0.025), 0.05, 0.0),
    LID: ((0.55, 0.57, 0.57), 0.6, 0.0),
    MOUTH: ((0.25, 0.2, 0.22), 0.5, 0.0),
    SUIT: ((0.32, 0.3, 0.42), 0.6, 0.0),
}

POD_Z = 0.55               # the saucer's mid-plane
HULL_R = 0.5
WELL_R = 0.235             # the cockpit's opening
HEAD_C = v3((0.0, 0.0, 1.0))
HEAD_R = 0.125
EYE_C = v3((0.052, -0.098, 0.975))
SHOULDER = v3((0.085, -0.005, 0.79))
ELBOW = v3((0.13, -0.075, 0.69))
WRIST = v3((0.085, -0.17, 0.71))
YOKE_Z = 0.7
ANT_ROOT = v3((-0.22, 0.25, 0.64))
ANT_TIP = v3((-0.29, 0.34, 1.16))


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


# ---------------------------------------------------------------------------------------------------- the pod

def pod():
    disc = Ellipsoid((0, 0, POD_Z), (HULL_R, HULL_R, 0.085), part=HULL)
    top = Ellipsoid((0, 0, POD_Z + 0.02), (0.36, 0.36, 0.09), part=HULL)
    belly = Ellipsoid((0, 0, POD_Z - 0.04), (0.32, 0.32, 0.1), part=HULL)
    hull = Union([disc, top, belly], k=0.06, part=HULL)
    # a dent or two, panel seams painted
    hull = Bump(hull, lambda P: -np.exp(-((P[:, 0] - 0.28) ** 2 + (P[:, 1] + 0.2) ** 2) / 0.003) - 0.6 * np.exp(-((P[:, 0] + 0.33) ** 2 + (P[:, 1] - 0.05) ** 2) / 0.002), 0.008)
    # the cockpit: a well cut into the top, a padded coaming round it, a seat back inside
    well = CappedCone((0, 0.0, POD_Z - 0.02), (0, 0.0, POD_Z + 0.3), WELL_R, WELL_R, rr=0.0)
    hull = Cut(hull, [well], k=0.02)
    floor = CappedCone((0, 0.0, POD_Z - 0.04), (0, 0.0, POD_Z - 0.0), WELL_R + 0.01, WELL_R + 0.01, rr=0.004, part=SEAT)
    coaming = Torus((0, 0.0, POD_Z + 0.105), WELL_R + 0.012, 0.03, part=PAD)
    seat = Clip(Ellipsoid((0, 0.13, POD_Z + 0.12), (0.17, 0.08, 0.2), part=SEAT), [Half((0, 0, POD_Z), (0, 0, -1))], k=0.004)
    rim = Torus((0, 0, POD_Z), HULL_R - 0.01, 0.024, part=RIM)
    lamps = []
    for i in range(10):
        a = i / 10 * 2 * np.pi + np.pi / 10
        lamps.append(Sphere((np.sin(a) * (HULL_R + 0.008), -np.cos(a) * (HULL_R + 0.008), POD_Z), 0.022, part=LAMP_R if i % 2 else LAMP_Y))
    # the thruster underneath: a dark ring, the glow inside it
    # (the thruster stands proud of the belly: level with it, their coplanar faces fought and baked in blotches)
    ring = Torus((0, 0, POD_Z - 0.16), 0.125, 0.028, part=THRUST)
    nozzle = CappedCone((0, 0, POD_Z - 0.09), (0, 0, POD_Z - 0.175), 0.15, 0.115, rr=0.012, part=THRUST)
    glow = Ellipsoid((0, 0, POD_Z - 0.178), (0.1, 0.1, 0.018), part=GLOW)
    # the yoke on its column in front of the pilot
    column = RoundCone((0, -0.17, POD_Z - 0.0), (0, -0.175, YOKE_Z - 0.01), 0.018, 0.014, part=YOKE)
    bar = RoundCone((-0.09, -0.18, YOKE_Z), (0.09, -0.18, YOKE_Z), 0.012, 0.012, part=YOKE)
    grips = Mirror(RoundCone((0.075, -0.18, YOKE_Z), (0.1, -0.18, YOKE_Z + 0.04), 0.016, 0.015, part=KNOB))
    dash = Clip(Ellipsoid((0, -0.2, POD_Z + 0.06), (0.14, 0.05, 0.05), part=RIM), [Half((0, 0, POD_Z + 0.05), (0, 0, -1))], k=0.004)
    # (two pieces: the big smooth hull meshed coarser on its own, the cockpit's small parts on theirs; as one piece decimated to under
    # 1% the hull came out with flipped faces that rendered as white streaks on its underside)
    return Union([hull, rim, ring, nozzle, glow] + lamps, k=0.0), Union([floor, coaming, seat, column, bar, grips, dash], k=0.0)


def antenna():
    rod = RoundCone(ANT_ROOT, ANT_TIP, 0.008, 0.005, part=ANT)
    base = CappedCone(ANT_ROOT + v3((0, 0, -0.02)), ANT_ROOT + v3((0, 0, 0.02)), 0.022, 0.016, rr=0.005, part=RIM)
    ball = Sphere(ANT_TIP + (ANT_TIP - ANT_ROOT) / np.linalg.norm(ANT_TIP - ANT_ROOT) * 0.015, 0.026, part=KNOB)
    return Union([rod, base, ball], k=0.004)


# ---------------------------------------------------------------------------------------------------- the grey

def grey_head():
    skull = Union([Sphere(HEAD_C + v3((0, 0.01, 0.02)), HEAD_R), Ellipsoid(HEAD_C + v3((0, -0.03, -0.075)), (0.08, 0.075, 0.06)),
                   Ellipsoid(HEAD_C + v3((0, -0.055, -0.1)), (0.04, 0.035, 0.032))], k=0.06, part=SKIN)
    # the eyes: big black almonds slanting up at their outer corners, set in thick lids; the upper lid heavy (the greys scowl)
    R = rot(ry=-20, rz=-14)
    ball = Ellipsoid(EYE_C, (0.042, 0.03, 0.028), R=R, part=EYE)
    lid_shell = Ellipsoid(EYE_C + v3((0, 0.002, 0)), (0.05, 0.036, 0.036), R=R, part=LID)
    upper = Clip(lid_shell, [Half(EYE_C + v3((0, 0, 0.008)), (-0.25, 0.1, -1.0))], k=0.004)
    lower = Clip(Ellipsoid(EYE_C + v3((0, 0.002, 0)), (0.048, 0.034, 0.034), R=R, part=LID), [Half(EYE_C + v3((0, 0, -0.016)), (0.1, 0.2, 1.0))], k=0.004)
    socket = Cut(Union([skull], part=SKIN), [Mirror(Ellipsoid(EYE_C + v3((0, -0.004, 0)), (0.042, 0.03, 0.028), R=R))], k=0.006)      # (the ball fills it: no thin gaps)
    brow = Mirror(Ellipsoid(EYE_C + v3((-0.012, 0.008, 0.035)), (0.04, 0.02, 0.012), R=rot(ry=-25), part=SKIN))
    nose = Ellipsoid(HEAD_C + v3((0, -0.118, -0.06)), (0.009, 0.01, 0.012), part=SKIN)
    face = Union([socket, Mirror(upper), Mirror(lower), brow, nose], k=0.008)
    face = Cut(face, [Ellipsoid(HEAD_C + v3((0, -0.1, -0.113)), (0.02, 0.012, 0.0035))], k=0.003)        # the mouth: a short frown pressed in (inked)
    ears = Mirror(Ellipsoid(HEAD_C + v3((0.118, 0.02, -0.03)), (0.012, 0.022, 0.03), part=SKIN))
    return Union([Union([face, ears], k=0.01), Mirror(ball)], k=0.0)


def grey_body():
    torso = Union([Ellipsoid((0, 0.02, 0.72), (0.095, 0.08, 0.11)), Ellipsoid((0, 0.02, 0.79), (0.1, 0.07, 0.04))], k=0.04, part=SUIT)
    neck = RoundCone((0, 0.02, 0.78), (0, 0.01, 0.92), 0.028, 0.024, part=SKIN)
    collar = Torus((0, 0.02, 0.825), 0.035, 0.012, part=SUIT)
    arm = loft([(SHOULDER, 0.024), (ELBOW, 0.019), (WRIST, 0.017)], part=SUIT, k=0.01)
    # long three-fingered grey hands wrapped round the yoke's grips
    hand = Union([Ellipsoid(WRIST + v3((-0.004, -0.012, 0.004)), (0.017, 0.02, 0.014), part=SKIN)] +
                 [loft([(WRIST + v3((-0.005, -0.015, 0.01 - j * 0.012)), 0.0065), (WRIST + v3((-0.01, -0.035, 0.008 - j * 0.012)), 0.006), (WRIST + v3((-0.008, -0.04, -0.008 - j * 0.012)), 0.0055)], part=SKIN, k=0.004) for j in range(3)], k=0.006)
    return Union([torso, neck, collar, Mirror(Union([arm, hand], k=0.006))], k=0.01)


def pieces():
    hull, cockpit = pod()
    return [("pod", hull, 0.0035), ("ant", antenna(), 0.0014), ("head", grey_head(), 0.0013), ("body", grey_body(), 0.0016),
            ("cockpit", cockpit, 0.0024)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    mott = noise3(P, 0.04) * 0.5 + noise3(P, 0.012) * 0.25
    grime = np.clip(noise3(P + 3.1, 0.04) * 0.8 + 0.25, 0, 1)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = rough[m] if np.ndim(rough) == 1 and np.size(rough) == n else rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, np.float32)], 1)

    # the hull: brushed chrome gone dull, panel seams and rivets inked, scorched dark round the thruster, a stripe of violet paint round its shoulder
    m = c.mask(HULL)
    r = np.sqrt(x ** 2 + y ** 2)
    ang = np.arctan2(x, -y)
    hc = srgb(196, 202, 210) * (1.0 + 0.08 * mott)[:, None]
    hc = hc * (1.0 - 0.5 * smooth(POD_Z - 0.02, POD_Z - 0.12, z) * smooth(0.36, 0.15, r))[:, None]
    hc = hc * (1.0 - 0.2 * grime * smooth(POD_Z, POD_Z - 0.08, z))[:, None]
    stripe = (np.abs(r - 0.42) < 0.018) & (z > POD_Z)
    hc[stripe] = srgb(92, 70, 150)
    put(m, hc, 0.36 + 0.15 * grime, metal=0.65, bump=0.15, grain=1.0)        # (fully metallic it read black against the dark street)
    c.metal[m & stripe] = 0.2
    # the belly: duller, sooty, less metallic. Glossy, its downward faces caught the preview rig's low rim light in big white streaks
    # (the maps were right; a glossy belly would flare the same under any low light in the street)
    belly = m & (z < POD_Z - 0.005)
    bk = smooth(POD_Z - 0.005, POD_Z - 0.09, z)
    c.col[belly] = (c.col * (1.0 - 0.35 * bk)[:, None])[belly] * 0.85
    c.rough[belly] = (0.55 + 0.25 * bk)[belly]
    c.metal[belly] = (0.45 - 0.25 * bk)[belly]
    spk(m, (110, 100, 90), 0.15)
    fr = (ang * 12 / (2 * np.pi)) % 1.0
    c.draw(m & (z > POD_Z - 0.01), np.minimum(fr, 1.0 - fr) * r * 2 * np.pi / 12 + 1.0 * (r < 0.27), 0.0008, 0.5)        # panel seams, twelve round
    c.draw(m & (z > POD_Z - 0.01), np.abs(r - 0.31), 0.0008, 0.5)
    for k in range(24):
        a = k / 24 * 2 * np.pi
        rv = np.sqrt((x - np.sin(a) * 0.45) ** 2 + (y + np.cos(a) * 0.45) ** 2)
        c.draw(m & (z > POD_Z), rv - 0.004, 0.0, 0.6)
    m = c.mask(RIM)
    put(m, srgb(80, 84, 92) + (srgb(170, 172, 176) - srgb(80, 84, 92)) * (c.wear * 0.6)[:, None], 0.38, metal=1.0, grain=1.0)
    m = c.mask(LAMP_R)
    put(m, srgb(255, 90, 60) + (srgb(255, 220, 200) - srgb(255, 90, 60)) * smooth(0.0, 0.8, c.wear)[:, None], 0.15)
    m = c.mask(LAMP_Y)
    put(m, srgb(255, 200, 70) + (srgb(255, 250, 220) - srgb(255, 200, 70)) * smooth(0.0, 0.8, c.wear)[:, None], 0.15)
    m = c.mask(THRUST)
    put(m, srgb(46, 46, 52) * (1.0 - 0.3 * c.cavity)[:, None], 0.45, metal=1.0, grain=1.0)
    m = c.mask(GLOW)
    rg = np.sqrt(x ** 2 + y ** 2) / 0.11
    put(m, srgb(120, 250, 255) + (srgb(240, 255, 255) - srgb(120, 250, 255)) * smooth(0.8, 0.1, rg)[:, None], 0.2)
    m = c.mask(PAD)
    put(m, srgb(84, 66, 110) * (1.0 + 0.1 * mott)[:, None] * (1.0 - 0.3 * c.cavity)[:, None], 0.55, bump=0.6, grain=1.0)
    c.draw(m, np.abs(((ang / (2 * np.pi) * 16.0) % 1.0) - 0.5) * 0.09, 0.0007, 0.45)
    m = c.mask(SEAT)
    put(m, srgb(62, 50, 84) * (1.0 + 0.1 * mott)[:, None], 0.5, bump=0.6, grain=1.0)
    m = c.mask(YOKE)
    put(m, srgb(60, 60, 66), 0.35, metal=1.0, grain=1.0)
    m = c.mask(KNOB)
    put(m, srgb(220, 50, 36) * (1.0 + 0.4 * c.wear)[:, None], 0.25)
    m = c.mask(ANT)
    put(m, srgb(170, 172, 178), 0.3, metal=1.0)

    # the grey: cool grey skin, mottled, darker in the creases; wrinkles inked over the brow and round the eyes, as on the game's greys
    m = c.mask(SKIN, LID)
    sk = srgb(150, 156, 158) * (1.0 + 0.07 * mott)[:, None]
    sk = sk + (srgb(96, 100, 108) - sk) * (smooth(0.0, 0.6, c.cavity) * 0.6)[:, None]
    sk = sk + (srgb(190, 196, 196) - sk) * (c.wear * 0.25)[:, None]
    put(m, sk, 0.55, bump=0.3, grain=1.0)
    spk(m, (110, 116, 120), 0.35)
    hd = P - HEAD_C
    fore = m & (hd[:, 2] > 0.05) & (hd[:, 1] < -0.04)
    for k, zz in enumerate((0.075, 0.09)):
        c.draw(fore, np.abs(hd[:, 2] - zz - 0.006 * np.cos(hd[:, 0] * 40.0)) + 1.0 * (np.abs(hd[:, 0]) > 0.05 - k * 0.012), 0.0009, 0.65)
    for xx in (-0.012, 0.0, 0.012):
        c.draw(m & (hd[:, 1] < -0.08), np.abs(hd[:, 0] - xx) + 1.0 * ((hd[:, 2] < 0.035) | (hd[:, 2] > 0.06)), 0.0008, 0.6)
    crow = m & (np.abs(Q[:, 0] - (EYE_C[0] + 0.05)) < 0.012) & (np.abs(z - EYE_C[2]) < 0.02)
    c.draw(crow, np.abs(np.abs(z - EYE_C[2] - 0.004) - 0.007 * np.abs(Q[:, 0] - EYE_C[0] - 0.038) / 0.012), 0.0007, 0.6)
    c.draw(m & (np.abs(hd[:, 1] + 0.1) < 0.03) & (np.abs(hd[:, 2] + 0.113) < 0.012),
           np.abs(hd[:, 2] + 0.113 + 0.006 * (hd[:, 0] / 0.02) ** 2) + 1.0 * (np.abs(hd[:, 0]) > 0.022), 0.0011)
    m = c.mask(EYE)
    de = Q - EYE_C
    ec = np.broadcast_to(srgb(10, 10, 14), (n, 3)).copy()
    gl = smooth(0.008, 0.004, np.sqrt((de[:, 0] + 0.012) ** 2 + (de[:, 2] - 0.01) ** 2))
    ec = ec + (srgb(255, 255, 255) - ec) * gl[:, None]
    ec = ec + (srgb(60, 40, 90) - ec) * (smooth(0.03, 0.04, np.linalg.norm(de, axis=1)) * 0.4)[:, None]
    put(m, ec, 0.03)
    m = c.mask(MOUTH)
    put(m, srgb(70, 50, 56), 0.5)
    m = c.mask(SUIT)
    put(m, srgb(76, 72, 104) * (1.0 + 0.08 * mott)[:, None], 0.6, bump=0.8)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    gm = c.mask(GLOW, LAMP_R, LAMP_Y)
    c.col[gm] /= (0.35 + 0.65 * c.ao[gm])[:, None] ** 0.8
    c.col *= (1.0 - 0.25 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model

GAME = {
    "budget": {"pod": 3000, "ant": 300, "head": 2800, "body": 1600, "cockpit": 1600},
    "density": {"head": 2.2, "body": 1.2},
    "tex": 2048,
    "stride": {"walk": 1.3, "run": 2.2},
    "speed": 0.85,
    "look": ["head"], "neck": "spine",
    "look_pivot": (0.0, 0.01, 0.9),
    "radius": 0.52,
}


def rig_bones():
    from kit.rig import Bone, mirror
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("pod", (0, 0, POD_Z - 0.15), (0, 0, POD_Z + 0.1), "root", 0.3),
        Bone("ant", ANT_ROOT, ANT_TIP, "pod", 0.02),
        Bone("spine", (0, 0.02, 0.62), (0, 0.02, 0.84), "pod", 0.09),
        Bone("head", (0, 0.01, 0.9), (0, 0.0, 1.12), "spine", 0.13),
        Bone("upper_arm.L", SHOULDER, ELBOW, "spine", 0.02),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.018),
        Bone("hand.L", WRIST, WRIST + v3((0, -0.05, 0)), "forearm.L", 0.02),
    ])


def skin_rules(P, part, piece, names):
    """piece: 0 pod (the hull), 1 antenna, 2 head, 3 body (torso, neck, arms, hands), 4 cockpit"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]
    A[:, ix["pod"]] = True
    rig[(piece == 0) | (piece == 4)] = ix["pod"]
    ap = piece == 1
    A[ap, ix["ant"]] = True
    rig[ap & (part != RIM)] = ix["ant"]
    rig[piece == 2] = ix["head"]
    bp = piece == 3
    A[bp, ix["spine"]] = True
    A[bp, ix["head"]] = True
    rig[bp & (z > 0.9)] = ix["head"]
    arms = bp & (np.abs(x) > 0.06) & (z < 0.8)
    for s, sx in (("L", 1), ("R", -1)):
        sm = arms & (sx * x > 0)
        A[sm, ix["upper_arm.%s" % s]] = True
        A[sm, ix["forearm.%s" % s]] = True
        A[sm, ix["head"]] = False
        # the hands stay on the yoke's grips (an IK keeps the wrists there)
        hm = bp & (sx * x > 0.04) & (P[:, 1] < -0.15)
        rig[hm] = ix["hand.%s" % s]
    return A, rig


def motions(rig):
    """walk: a hovering glide (the pod tilted into its way, bobbing and wobbling, the pilot leaning with it, glancing about, the antenna whipping);
    run: tilted hard, bobbing quicker; idle: a slow hover, the pod drifting round, the pilot looking about and drumming on the yoke"""
    import math
    from kit.gait import Pose, R, TAU, ease
    from mathutils import Vector, Matrix

    def fly(u, tilt, bob, wob, look, spd):
        p = Pose()
        p.offset = Vector((0.01 * math.sin(TAU * u), 0.0, bob * math.sin(2 * TAU * u)))
        p.rot("pod", tilt + wob * math.sin(2 * TAU * u - 0.6), wob * 0.8 * math.sin(TAU * u), 0)
        p.rot("spine", -tilt * 0.5 + 2.0 * math.sin(2 * TAU * u - 1.4), 0, look * 0.3)
        p.world["head"] = R(-1.0 + 2.0 * math.sin(2 * TAU * u - 2.0), 0, look)
        p.rot("ant", -(6.0 + spd * 8.0) - 6.0 * math.sin(2 * TAU * u - 1.6), 0, 5.0 * math.sin(TAU * u - 1.0))
        grips(p)
        return p

    def grips(p):
        """the wrists kept on the yoke, wherever the pod has gone"""
        Rp = p.delta.get("pod", Matrix.Identity(3))
        ph = Vector((0.0, 0.0, POD_Z - 0.15))
        for s, sx in (("L", 1.0), ("R", -1.0)):
            w = Vector((sx * WRIST[0], WRIST[1], WRIST[2]))
            tgt = p.offset + ph + Rp @ (w - ph)
            p.ik["upper_arm.%s" % s] = (tgt, Vector((sx * 0.8, 0.2, -0.5)).normalized(), "hand.%s" % s, Rp)

    walk = [fly(i / 32.0, 7.0, 0.018, 1.5, 14.0 * math.sin(TAU * i / 32.0), 0.0) for i in range(33)]
    run = [fly(i / 24.0, 14.0, 0.025, 2.5, 0.0, 1.0) for i in range(25)]
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        p.offset = Vector((0.0, 0.0, 0.025 * math.sin(TAU * t / 2.0)))
        p.rot("pod", 2.0 * math.sin(TAU * t / 3.0), 2.5 * math.sin(TAU * t / 2.0 + 0.5), 10.0 * math.sin(TAU * t / 6.0))
        look = 35.0 * ease((t - 0.8) / 0.5) * (1.0 - ease((t - 2.2) / 0.4)) - 30.0 * ease((t - 3.2) / 0.5) * (1.0 - ease((t - 4.6) / 0.6))
        p.rot("spine", 1.5 * math.sin(TAU * t / 3.0), 0, look * 0.25 - 10.0 * math.sin(TAU * t / 6.0) * 0.5)
        p.world["head"] = R(-2.0 + 3.0 * ease((t - 4.8) / 0.3) * (1.0 - ease((t - 5.6) / 0.3)), 0, look)
        p.rot("ant", -4.0 * math.sin(TAU * t / 2.0 - 1.2), 0, 3.0 * math.sin(TAU * t / 3.0))
        grips(p)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
