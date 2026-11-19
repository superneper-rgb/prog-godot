## FOINT CITY townsfolk: the fin-headed executive (working name; the user names her). Tall blue businesswoman: diamond head, webbed fin ears, cream suit, coffee and briefcase.
# Concept: the user's sheet, image 2 top (F:/prog-godot-cache/folk/refs/2.png). Measured off it: 1.95 m tall in heels, head 19% of that.
# Rest pose = her carrying pose: the coffee arm (left) is raised with the cup up, as she always holds it; the briefcase arm (right) hangs.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place)

HEIGHT = 1.95
REF = ("2.png", (0, 0, 377, 395))

SKIN, FIN, EYE, PUPIL, LIP, BLAZER, BLOUSE, TROUSERS, BELT, GOLD, SHOE, NAIL, RIB, CASE, CUP, SLEEVE = range(1, 17)
COLOURS = {
    SKIN: ((0.50, 0.58, 0.76), 0.55, 0.0),
    FIN: ((0.62, 0.42, 0.68), 0.5, 0.0),
    RIB: ((0.42, 0.26, 0.50), 0.5, 0.0),
    EYE: ((0.98, 0.72, 0.16), 0.2, 0.0),
    PUPIL: ((0.05, 0.03, 0.02), 0.2, 0.0),
    LIP: ((0.42, 0.22, 0.38), 0.4, 0.0),
    BLAZER: ((0.80, 0.70, 0.58), 0.75, 0.0),
    BLOUSE: ((0.10, 0.30, 0.17), 0.35, 0.0),
    TROUSERS: ((0.84, 0.75, 0.63), 0.75, 0.0),
    BELT: ((0.30, 0.17, 0.09), 0.5, 0.0),
    GOLD: ((0.95, 0.68, 0.25), 0.3, 1.0),
    SHOE: ((0.17, 0.09, 0.07), 0.35, 0.0),
    NAIL: ((0.10, 0.10, 0.16), 0.25, 0.0),
    CASE: ((0.13, 0.17, 0.12), 0.45, 0.0),
    CUP: ((0.92, 0.88, 0.80), 0.5, 0.0),
    SLEEVE: ((0.48, 0.32, 0.20), 0.7, 0.0),
}

# landmarks, left side (+X); the figure faces -Y
HEAD_C = v3((0.0, -0.015, 1.765))
SHOULDER = v3((0.185, 0.0, 1.44))
HIP = v3((0.085, 0.01, 0.95))
KNEE = v3((0.10, 0.0, 0.52))
HEM = v3((0.11, 0.0, 0.15))
ANKLE = v3((0.115, 0.02, 0.11))
# the coffee arm (left): elbow down by the waist, forearm up and forward, the hand turned flat round an upright cup at chest height
C_ELBOW = v3((0.27, 0.045, 1.16))
C_WRIST = v3((0.335, -0.075, 1.385))
C_HAND = basis(-v3((0.22, -1.0, 0.08)), v3((0, 0, -1)))       # hand points forward and a little out; the cup's axis (hand -Y) points up
# the briefcase arm, built on the left and mirrored to the right
B_ELBOW = v3((0.25, 0.015, 1.17))
B_WRIST = v3((0.30, -0.01, 0.93))
B_HAND = basis(-(B_WRIST - B_ELBOW), v3((0, 1, 0)))           # hangs along the forearm; the handle (hand Y) runs front to back
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
# the left eye (the right is its mirror): eyeball, where it looks, the plane the heavy upper lid stops at
EYE_C = v3((0.097, -0.06, 1.79))
EYE_R = 0.046
EYE_FWD = v3((0.0, -0.98, 0.19)) / np.linalg.norm((0.0, -0.98, 0.19))
LID_PT = EYE_C + v3((0, 0, 0.008))
LID_N = v3((0.2, 0.0, -1.0)) / np.linalg.norm((0.2, 0.0, -1.0))      # points away from the lid (down, in)
FIN_ROOT = v3((0.215, 0.02, 1.762))
FIN_U = v3((0.6, 1.0, -0.08)) / np.linalg.norm((0.6, 1.0, -0.08))      # along the fin, root to tips


def head():
    # her face is planes (user, 2026-11-15: "she's angular, not a rounded blob"): the diamond's facets meet in a ridge down the middle of the face
    skull = Gem(HEAD_C, (0.235, 0.235, 0.12, 0.21, 0.18, 0.165), soft=0.2, edge=0.007, part=SKIN)
    neck = RoundCone((0, 0.03, 1.455), (0, 0.025, 1.65), 0.037, 0.030, part=SKIN)
    eye_c = EYE_C
    # heavy upper lid: the top of a shell over the eyeball, its edge slanting up to the outer corner; a thin lower lid
    lid = Clip(Ellipsoid(eye_c + v3((0, -0.001, 0.002)), (0.053, 0.051, 0.051), part=SKIN), [Half(LID_PT, LID_N)], k=0.004)
    lower = Clip(Ellipsoid(eye_c + v3((0, -0.002, -0.002)), (0.051, 0.049, 0.049), part=SKIN), [Half(eye_c + v3((0, 0, -0.031)), (0.0, 0.0, 1.0))], k=0.004)
    # the nose, faceted like the head: a narrow bridge down the face's ridge from between the eyes, out to a small pointed tip over the lip, back in under it
    nose = Gem((0, -0.117, 1.728), (0.0105, 0.0105, 0.027, 0.01, 0.013, 0.05), soft=0.15, edge=0.003, part=SKIN)
    face = Union([Union([skull, neck], k=0.03), Mirror(lid), Mirror(lower)], k=0.008)
    face = Union([face, nose], k=0.007)
    ball = Mirror(Sphere(eye_c, EYE_R, part=EYE))      # iris and pupil are painted (paint() below)
    nostrils = Mirror(Ellipsoid((0.0072, -0.129, 1.7175), (0.0042, 0.006, 0.0038), R=rot(rx=35), part=SKIN))
    face = Cut(face, [nostrils], k=0.002)
    lips = Union([
        Ellipsoid((0.0, -0.076, 1.671), (0.04, 0.018, 0.0125), part=LIP),
        Ellipsoid((0.0, -0.074, 1.652), (0.035, 0.019, 0.014), part=LIP),
    ], k=0.005)
    lips = Cut(lips, [Box((0, -0.093, 1.662), (0.05, 0.03, 0.0013), rr=0.0009)], k=0.002)
    return Union([face, ball, lips], k=0.0)


def fins():
    # webbed fin ear: a plate sweeping back, out and a little down from the cheek corner, three ribs to its points
    root = FIN_ROOT
    u = FIN_U
    vv = v3((0, 0, 1)) - u * u[2]
    vv /= np.linalg.norm(vv)
    n = np.cross(u, vv)
    R = np.stack([u, vv, n], 1)
    s = 1.45
    poly = [(0.0, 0.035), (0.19, 0.05), (0.135, 0.01), (0.16, -0.022), (0.10, -0.022), (0.11, -0.06), (0.04, -0.04), (0.0, -0.028)]
    poly = [(a * s, b * s) for a, b in poly]
    plate = Slab(root, poly, 0.004, rr=0.002, R=R, part=FIN)
    ribs = []
    for tip, r in (((0.19, 0.05), 0.0065), ((0.16, -0.022), 0.006), ((0.11, -0.06), 0.0055)):
        ribs.append(RoundCone(root, root + u * tip[0] * s + vv * tip[1] * s, r, 0.002, part=RIB))
    ear = Union([plate] + ribs, k=0.003)
    ring = Torus((0.226, 0.0, 1.728), 0.007, 0.002, Rm=rot(ry=90), part=GOLD)
    drop = Box((0.228, 0.0, 1.698), (0.0075, 0.0045, 0.025), rr=0.003, part=GOLD)
    return Mirror(Union([ear, ring, drop]))


def torso_core():
    """the blouse: chest, bust, waist (the blazer is this grown and cut)"""
    return Union([
        Ellipsoid((0, 0.005, 1.36), (0.13, 0.093, 0.13)),
        Ellipsoid((0, 0.015, 1.445), (0.145, 0.078, 0.055)),
        Mirror(Ellipsoid((0.06, -0.05, 1.335), (0.056, 0.05, 0.052))),
        Ellipsoid((0, 0.008, 1.205), (0.094, 0.076, 0.085)),
    ], k=0.06, part=BLOUSE)


def prism(poly_xz, y0=-0.5, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from the front (y0) to the middle (y1)"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def jacket(sleeves):
    core = torso_core()
    shell = Union([
        Inflate(core, 0.012, part=BLAZER),
        Mirror(Box((0.17, 0.0, 1.452), (0.062, 0.064, 0.03), rr=0.025, part=BLAZER)),        # square padded shoulders
        Ellipsoid((0, 0.012, 0.985), (0.19, 0.14, 0.2), part=BLAZER),       # the skirt of the jacket, flaring from the waist
    ], k=0.035, part=BLAZER)
    shell = Clip(shell, [Half((0, 0, 0.94), (0.0, 0.0, -1.0))], k=0.004)
    shell = Union([shell] + sleeves, k=0.018, part=BLAZER)      # sleeves set into the shoulders, no crease
    opening = prism([(-0.066, 1.53), (0.066, 1.53), (0.044, 1.30), (0.058, 1.2), (0.13, 0.90), (-0.13, 0.90), (-0.058, 1.2), (-0.044, 1.30)])
    shell = Cut(shell, [opening], k=0.009)
    # lapels: folded-back flaps along the opening, notched at the top; a thicker layer of the jacket inside their outline, so they follow the chest
    lapel = Clip(Inflate(core, 0.021, part=BLAZER), [Mirror(prism([(0.067, 1.51), (0.045, 1.30), (0.125, 1.41), (0.137, 1.44), (0.112, 1.452), (0.14, 1.485), (0.10, 1.52)]))], k=0.006)
    shell = Union([shell, lapel], k=0.0, part=BLAZER)
    # the blouse collar: a thin flap (6 mm) lying out over the lapels, not a block
    collar = Clip(Cut(Inflate(core, 0.027, part=BLOUSE), [Inflate(core, 0.021)], k=0.002), [Mirror(prism([(0.012, 1.478), (0.064, 1.52), (0.082, 1.472), (0.036, 1.42)]))], k=0.005)
    belt = Clip(Inflate(Ellipsoid((0, 0.008, 1.205), (0.094, 0.076, 0.085)), 0.009, part=BELT), [Half((0, 0, 1.228), (0, 0, 1)), Half((0, 0, 1.186), (0, 0, -1))], k=0.002)
    buckle = Box((0, -0.088, 1.207), (0.026, 0.006, 0.019), rr=0.004, part=GOLD)
    pin = Mirror(Box((0.105, -0.115, 1.43), (0.012, 0.004, 0.009), rr=0.003, R=rot(rx=-14), part=GOLD))
    return Union([core, shell, collar, belt, buckle, pin], k=0.0)


def legs():
    hips = Union([
        Ellipsoid((0, 0.01, 1.045), (0.16, 0.116, 0.15)),
        Ellipsoid((0, 0.008, 1.2), (0.098, 0.078, 0.05)),
        Mirror(loft([(HIP, 0.088), (KNEE, 0.072), (HEM, 0.098)])),
    ], k=0.05, part=TROUSERS)
    ridge = ridge_line((0.085, -0.079, 0.92), (0.11, -0.099, 0.16), 0.013)

    def crease(P):
        Q = P.copy()
        Q[:, 0] = np.abs(Q[:, 0])
        return ridge(Q)
    hips = Bump(hips, crease, 0.0035)
    trousers = Clip(hips, [Half((0, 0, 0.142), (0.0, -0.25, -1.0))], k=0.003)
    ankle = RoundCone(ANKLE + v3((0, -0.01, 0.12)), ANKLE, 0.031, 0.028, part=SKIN)
    foot = loft([(ANKLE + v3((0, 0.014, -0.005)), 0.031), (v3((0.12, -0.08, 0.031)), 0.036), (v3((0.125, -0.175, 0.016)), 0.011)], part=SKIN, k=0.01)
    # a pump: the heel counter sloping down to the vamp, the toe box closed, the instep bare
    shell = Inflate(foot, 0.004, part=SHOE)
    shoe = Union([Clip(shell, [Half((0, -0.08, 0.058), (0.0, -0.85, 1.0))], k=0.003), Clip(shell, [Half((0, -0.08, 0.0), (0.0, 1.0, 0.0))], k=0.003)])
    heel = RoundCone((0.115, 0.045, 0.085), (0.115, 0.053, 0.004), 0.013, 0.005, part=GOLD)
    vamp = Box((0.121, -0.098, 0.055), (0.013, 0.006, 0.009), rr=0.003, R=rot(rx=40), part=GOLD)
    return Union([trousers, Mirror(Union([ankle, foot, shoe, heel, vamp], k=0.0))], k=0.0)


def hand_hook():
    """the briefcase grip, in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): fingers hooked round a handle along Y"""
    palm = Ellipsoid((0.0, 0.0, -0.05), (0.017, 0.039, 0.049), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.03, 0.026, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.027, -0.009, 0.009, 0.027):
        L = 1.0 - abs(f) * 4
        pts = [((0.0, f, -0.085), 0.0105), ((0.0, f, -0.085 - 0.032 * L), 0.0098), ((-0.02, f, -0.105 - 0.03 * L), 0.009), ((-0.04, f, -0.098 - 0.025 * L), 0.0082)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((-0.004, 0, 0.004)), (0.007, 0.007, 0.0055), part=NAIL))
    parts.append(loft([(v3((-0.008, -0.03, -0.03)), 0.012), (v3((-0.022, -0.045, -0.065)), 0.0105), (v3((-0.034, -0.035, -0.088)), 0.009)], part=SKIN, k=0.004))
    return Union(parts, k=0.008)


CUP_AT = v3((-0.06, 0.0, -0.078))      # the cup's centre in hand space; its axis is hand Y, the lid toward -Y


def hand_cup():
    """the coffee grip, in hand space: fingers wrapped round the cup at CUP_AT, thumb over the near side"""
    rc = 0.054
    palm = Ellipsoid((0.0, 0.0, -0.05), (0.017, 0.039, 0.049), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.03, 0.026, part=SKIN)
    parts = [palm, wrist]
    a0 = np.arctan2(-0.085 - CUP_AT[2], 0.0 - CUP_AT[0])
    for f in (-0.027, -0.009, 0.009, 0.027):
        L = 1.0 - abs(f) * 4
        pts = [(v3((0.0, f, -0.07)), 0.0105)]
        for k, a in enumerate(np.linspace(a0, a0 - 1.9 * L, 4)):
            pts.append((v3((CUP_AT[0] + rc * np.cos(a), f, CUP_AT[2] + rc * np.sin(a))), 0.0105 - 0.0007 * k))
        parts.append(loft(pts, part=SKIN, k=0.004))
        parts.append(Ellipsoid(pts[-1][0], (0.0065, 0.007, 0.006), part=NAIL))
    parts.append(loft([(v3((-0.008, -0.03, -0.03)), 0.012), (v3((-0.03, -0.05, -0.04)), 0.0105), (v3((-0.055, -0.056, -0.03)), 0.009)], part=SKIN, k=0.004))
    return Union(parts, k=0.008)


def cup():
    """the takeaway cup in hand space: tapered, a card sleeve round its middle, a domed lid"""
    bot, top = CUP_AT + v3((0, 0.062, 0)), CUP_AT + v3((0, -0.065, 0))
    body = CappedCone(bot, top, 0.034, 0.044, rr=0.004, part=CUP)
    band = Clip(Inflate(CappedCone(bot, top, 0.034, 0.044, rr=0.004), 0.003, part=SLEEVE), [Half(CUP_AT + v3((0, 0.03, 0)), (0, 1, 0)), Half(CUP_AT + v3((0, -0.03, 0)), (0, -1, 0))])
    lid = CappedCone(top + v3((0, 0.004, 0)), top + v3((0, -0.012, 0)), 0.048, 0.042, rr=0.004, part=CUP)
    return Union([body, band, lid], k=0.002)


def sleeve(elbow, wrist):
    """(the sleeve, its gold bracelet): the sleeve joins the jacket smoothly, the bracelet stays crisp"""
    s = Clip(loft([(SHOULDER, 0.058), (elbow, 0.051), (wrist, 0.046)], part=BLAZER, k=0.012), [Half(wrist, (wrist - elbow))], k=0.003)
    d = (wrist - elbow) / np.linalg.norm(wrist - elbow)
    cuff = Torus(wrist - d * 0.012, 0.035, 0.0055, Rm=basis(d, v3((0, 0, 1)) if abs(d[2]) < 0.9 else v3((0, 1, 0))), part=GOLD)
    return s, cuff


def coffee_arm():
    s, cuff = sleeve(C_ELBOW, C_WRIST)
    return s, Union([cuff, place(hand_cup(), C_WRIST, C_HAND)])


def briefcase_arm():
    """built on the left, mirrored to the right by the caller; the case hangs plumb from the hooked fingers"""
    grip = B_WRIST + B_HAND @ v3((-0.022, 0.0, -0.112))
    top = grip[2] - 0.044
    cx = grip[0]
    case = Box((cx, grip[1], top - 0.155), (0.047, 0.21, 0.155), rr=0.014, part=CASE)
    flap = Box((cx + 0.049, grip[1], top - 0.062), (0.004, 0.2, 0.067), rr=0.003, part=CASE)
    clasp = Box((cx + 0.055, grip[1], top - 0.118), (0.005, 0.026, 0.021), rr=0.003, part=GOLD)
    corners = [Box((cx + sx * 0.042, grip[1] + sy * 0.195, top - 0.155 + sz * 0.14), (0.012, 0.021, 0.021), rr=0.006, part=GOLD)
               for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
    handle = loft([(grip + v3((0, -0.066, -0.047)), 0.0095), (grip + v3((0, -0.056, 0.0)), 0.0095), (grip + v3((0, 0.056, 0.0)), 0.0095), (grip + v3((0, 0.066, -0.047)), 0.0095)], part=CASE, k=0.01)
    lugs = [Box((cx, grip[1] + s * 0.066, top - 0.004), (0.009, 0.012, 0.008), rr=0.003, part=GOLD) for s in (-1, 1)]
    brief = Union([case, flap, clasp, handle] + corners + lugs, k=0.0)
    s, cuff = sleeve(B_ELBOW, B_WRIST)
    return s, Union([cuff, place(hand_hook(), B_WRIST, B_HAND)]), brief


def pieces():
    c_sleeve, c_hand = coffee_arm()
    b_sleeve, b_hand, brief = briefcase_arm()
    body = Union([jacket([c_sleeve, Move(b_sleeve, R=FLIP)]), legs(), c_hand, Move(b_hand, R=FLIP)], k=0.0)
    props = Union([place(cup(), C_WRIST, C_HAND), Move(brief, R=FLIP)])
    return [("head", head(), 0.0018), ("body", body, 0.0035), ("fins", fins(), 0.0015), ("props", props, 0.0025)]


# ---------------------------------------------------------------------------------------------------- paint (kit/paint.py fills the shader's layers from these)

def paint(c):
    from kit.paint import srgb, smooth
    from kit.sdf import noise3
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])          # her left and right painted alike
    z = P[:, 2]
    mott = noise3(P, 0.035) * 0.5 + noise3(P, 0.011) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    # skin: periwinkle, cooler and lighter up the crest, deeper blue down the jaw and neck, softly mottled, pink freckles
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(158, 174, 212), (len(P), 3)).copy()
    sk = sk + (srgb(176, 168, 222) - sk) * smooth(1.80, 1.94, z)[:, None]
    sk = sk + (srgb(124, 140, 190) - sk) * (smooth(1.70, 1.52, z) * 0.4)[:, None]
    sk *= (1.0 + 0.06 * mott)[:, None]
    # eyeshadow over the upper lid; inked: a liner along the lid's edge swept up past the outer corner, a faint crease above the lid
    de = Q - EYE_C
    r = np.linalg.norm(de, axis=1)
    pd = (Q - LID_PT) @ LID_N                       # < 0 on the lid
    on_lid = (r < EYE_R + 0.012) & (pd < 0.0)
    shadow = on_lid * smooth(-0.03, -0.004, pd)
    sk = sk + (srgb(122, 106, 176) - sk) * (shadow * 0.55)[:, None]
    near_eye = (r < EYE_R + 0.012) & (pd > -0.009) & (pd < 0.004) & (de[:, 1] < 0.015)
    c.draw(near_eye, np.abs(pd + 0.0012), 0.0021)
    wing_t = (Q[:, 0] - (EYE_C[0] + 0.03)) / 0.04
    wing = (wing_t > 0) & (wing_t < 1) & (de[:, 1] < 0.02) & (r < EYE_R + 0.04) & (np.abs(pd) < 0.02)
    c.draw(wing, np.abs(pd + 0.0012 - 0.009 * wing_t ** 1.4), 0.0021 * (1.0 - wing_t))
    crease = (pd < -0.005) & (r > EYE_R + 0.004) & (r < EYE_R + 0.022) & (de[:, 1] < 0.006)
    c.draw(crease, np.abs(r - (EYE_R + 0.0125)), 0.0008, 0.3)
    under = (r < EYE_R + 0.009) & (r > EYE_R - 0.004) & (de[:, 2] < -0.022)
    sk = np.where(under[:, None], sk * 0.88, sk)
    put(m, sk[m], 0.5, bump=0.12)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(204, 104, 130), (m.sum(), 3)), (0.5 * smooth(1.58, 1.66, z[m]))[:, None]], 1)
    hands = m & (z < 1.5)
    c.spk[hands, 3] = 0.15

    # eyes: all iris (no white), gold going amber to a dark rim; an inked pupil right under the lid, a glint up and to her right
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    fwd = v3((0.0, -1.0, 0.0))
    ang = np.arccos(np.clip(d @ fwd, -1, 1))
    up = v3((0.0, 0.0, 1.0))
    ah, av = d[:, 0], d @ up
    ir = srgb(250, 204, 62) + (srgb(222, 136, 28) - srgb(250, 204, 62)) * smooth(0.2, 0.7, ang)[:, None]
    ir = ir + (srgb(92, 48, 12) - ir) * smooth(0.72, 0.92, ang)[:, None]
    pup = np.sqrt((ah / 0.25) ** 2 + ((av - 0.04) / 0.21) ** 2)
    c.draw(m, (pup - 1.0) * 0.25 * EYE_R, 0.0)
    ir *= (1.0 - 0.5 * smooth(0.06, 0.2, av))[:, None]           # the lid's shadow on the top of the eye
    gl = np.zeros(len(P), np.float32)
    for sx in (1.0, -1.0):
        ec = EYE_C * np.array([sx, 1.0, 1.0], np.float32)
        dd = P - ec
        dd /= np.maximum(np.linalg.norm(dd, axis=1), 1e-6)[:, None]
        fw = EYE_FWD * np.array([sx, 1.0, 1.0], np.float32)
        side = (dd[:, 0] + 0.30) ** 2 + ((dd @ up) - 0.05) ** 2
        gl = np.maximum(gl, smooth(0.012, 0.004, side) * (dd @ fw > 0.5))
    ir = ir + (srgb(255, 250, 236) - ir) * gl[:, None]
    put(m, ir[m], 0.08)

    # lips: mauve, the parting darker, the lower lip catching a little light
    m = c.mask(LIP)
    lp = np.broadcast_to(srgb(132, 74, 108), (len(P), 3)).copy()
    lp = np.where((z < 1.662)[:, None], lp * 1.12, lp)
    lp *= (1.0 - 0.5 * smooth(0.004, 0.0, np.abs(z - 1.662)))[:, None]
    put(m, lp[m], 0.28)

    # fins: lilac membrane going pink toward the scalloped edge, darker ribs, a few spots
    m = c.mask(FIN)
    t = np.clip(((Q - FIN_ROOT) @ FIN_U) / 0.27, 0, 1)
    fn = srgb(166, 122, 186) + (srgb(226, 168, 204) - srgb(166, 122, 186)) * smooth(0.25, 1.0, t)[:, None]
    put(m, fn[m], 0.45, bump=0.2)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(232, 148, 186), (m.sum(), 3)), np.full((m.sum(), 1), 0.3, np.float32)], 1)
    put(c.mask(RIB), srgb(112, 70, 140), 0.45)
    put(c.mask(NAIL), srgb(30, 30, 52), 0.22)
    put(c.mask(PUPIL), srgb(14, 8, 6), 0.08)

    # the suit: warm cream, a scattered gold fleck print; the trousers pinstriped round each leg
    m = c.mask(BLAZER)
    bz = srgb(224, 194, 162) * (1.0 + 0.035 * mott)[:, None]
    put(m, bz[m], 0.82, bump=1.0, grain=0.0)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(208, 154, 78), (m.sum(), 3)), np.full((m.sum(), 1), 0.34, np.float32)], 1)
    m = c.mask(TROUSERS)
    tr = srgb(226, 199, 168) * (1.0 + 0.035 * mott)[:, None]
    put(m, tr[m], 0.82, bump=1.0, grain=0.0)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(196, 132, 62), (m.sum(), 3)), np.full((m.sum(), 1), 0.3, np.float32)], 1)
    ax = (HEM - HIP) / np.linalg.norm(HEM - HIP)
    rel = Q - HIP
    rad = rel - np.outer(rel @ ax, ax)
    e_out = v3((1, 0, 0)) - ax * ax[0]
    e_out /= np.linalg.norm(e_out)
    e_fwd = np.cross(ax, e_out)
    phi = np.arctan2(rad @ e_out, -(rad @ e_fwd))
    c.strp[m, 0] = (phi * 0.09)[m]
    c.strp[m, 1] = 0.42

    # blouse: deep green satin, sheen on what stands out
    m = c.mask(BLOUSE)
    bl = srgb(30, 96, 58) * (1.0 + 0.35 * c.wear)[:, None]
    put(m, bl[m], 0.3, bump=0.25)
    # leather, gold, patent shoes, the case, the cup
    m = c.mask(BELT)
    put(m, (srgb(84, 46, 26) * (1.0 + 0.6 * c.wear)[:, None])[m], 0.45, bump=0.8, grain=1.0)
    m = c.mask(GOLD)
    put(m, (srgb(240, 182, 88) * (1.0 - 0.45 * c.cavity)[:, None])[m], 0.26, metal=1.0, bump=0.05, grain=1.0)
    m = c.mask(SHOE)
    put(m, (srgb(42, 22, 18) * (1.0 + 0.8 * c.wear)[:, None])[m], 0.16, bump=0.15, grain=1.0)
    m = c.mask(CASE)
    cs = srgb(32, 46, 34) + (srgb(76, 92, 70) - srgb(32, 46, 34)) * (c.wear * 0.7)[:, None]
    put(m, cs[m], 0.5, bump=1.0, grain=1.0)
    put(c.mask(CUP), srgb(234, 230, 220), 0.55, bump=0.1)
    m = c.mask(SLEEVE)
    put(m, srgb(150, 98, 58), 0.85, bump=0.6)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(118, 74, 40), (m.sum(), 3)), np.full((m.sum(), 1), 0.6, np.float32)], 1)

    # light that the room does not give: occlusion into the creases, dirt in the cavities
    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]



# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2600, "body": 4800, "fins": 520, "props": 1300},       # triangles per piece
    "density": {"head": 1.8, "fins": 1.4},                                    # texture resolution against the rest
    "tex": 2048,
    "stride": {"walk": 1.1, "run": 1.9},                                      # metres per cycle (two steps): the game turns speed into phase with these
    "speed": 1.05,                                                            # her walking pace against the crowd's (brisk)
    "look": ["head", "fin.L", "fin.R"], "neck": "neck",                      # what turns when she looks at Prog
    "look_pivot": (0.0, 0.02, 1.62),                                          # where the head turns (Blender space)
    "radius": 0.36,
}
GRIP = B_WRIST + B_HAND @ v3((-0.022, 0.0, -0.112))       # where the case's handle sits in the right hand (built on the left)
BALL = v3((0.12, -0.08, 0.0))                             # the ball of her left foot, what she stands and rolls on


def rig_bones():
    from kit.rig import Bone, mirror
    f = np.array([-1, 1, 1], np.float32)
    c_hand_end = C_WRIST - C_HAND[:, 2] * 0.09
    b_hand_end = B_WRIST - B_HAND[:, 2] * 0.09
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.01, 0.99), (0, 0.01, 1.12), "root", 0.13),
        Bone("spine", (0, 0.01, 1.12), (0, 0.005, 1.28), "hips", 0.10),
        Bone("chest", (0, 0.005, 1.28), (0, 0.02, 1.44), "spine", 0.12),
        Bone("neck", (0, 0.025, 1.45), (0, 0.025, 1.62), "chest", 0.034),
        Bone("head", (0, 0.02, 1.62), (0, 0.0, 1.93), "neck", 0.15),
        Bone("fin.L", FIN_ROOT, FIN_ROOT + FIN_U * 0.2, "head", 0.03),
        Bone("shoulder.L", (0.035, 0.01, 1.43), SHOULDER, "chest", 0.05),
        Bone("thigh.L", (0.085, 0.01, 0.97), KNEE, "hips", 0.088),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.072),
        Bone("foot.L", ANKLE, (0.125, -0.15, 0.016), "shin.L", 0.035),
    ])
    bones += [
        Bone("upper_arm.L", SHOULDER, C_ELBOW, "shoulder.L", 0.056),
        Bone("forearm.L", C_ELBOW, C_WRIST, "upper_arm.L", 0.048),
        Bone("hand.L", C_WRIST, c_hand_end, "forearm.L", 0.03),
        Bone("upper_arm.R", SHOULDER * f, B_ELBOW * f, "shoulder.R", 0.056),
        Bone("forearm.R", B_ELBOW * f, B_WRIST * f, "upper_arm.R", 0.048),
        Bone("hand.R", B_WRIST * f, b_hand_end * f, "forearm.R", 0.03),
        Bone("case", GRIP * f, (GRIP - v3((0, 0, 0.3))) * f, "hand.R", 0.1),
    ]
    return bones


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for vertices that move rigidly). piece: 0 head, 1 body, 2 fins, 3 props"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    # head: rigid above the jaw, the neck bends from the collar
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 1.66)] = ix["head"]
    # fins ride their own bones; the earrings hang from the head
    fp = piece == 2
    rig[fp & (part == GOLD)] = ix["head"]
    rig[fp & (part != GOLD) & (x > 0)] = ix["fin.L"]
    rig[fp & (part != GOLD) & (x <= 0)] = ix["fin.R"]
    allow(fp, "head")
    # props: the cup in her left hand, the case on its own swinging bone
    pp = piece == 3
    rig[pp & (x > 0)] = ix["hand.L"]
    rig[pp & (x <= 0)] = ix["case"]
    allow(pp, "head")
    # the body: legs, torso (the jacket's skirt follows the hips, never the thighs), arms by side
    bp = piece == 1
    legs = bp & (np.isin(part, (TROUSERS, SHOE)) | (z < 0.3))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs & (np.isin(part, (BLAZER, BLOUSE, BELT)) | ((part == GOLD) & (np.abs(x) < 0.15) & (z > 1.1)))
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.05), "shoulder.L", "upper_arm.L", "forearm.L")
    allow(torso & (x < -0.05), "shoulder.R", "upper_arm.R", "forearm.R")
    arms = bp & ~legs & ~torso
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "upper_arm.R", "forearm.R", "hand.R")
    return A, rig


WALK = dict(stride=1.1, stance=0.6, foot_x=0.03, lift=0.055, bob=0.012, drop=0.03, sway=0.03, roll=7.0, yaw=7.0, counter=1.2,
            lean=3.0, toe_off=16.0, toe_out=6.0, swing_point=8.0)
RUN = dict(stride=1.9, stance=0.42, foot_x=0.05, lift=0.13, bob=0.032, drop=0.07, sway=0.02, roll=5.0, yaw=10.0, counter=1.4,
           lean=11.0, toe_off=26.0, toe_out=6.0, swing_point=16.0, spine_lean=4.0)


def motions(rig):
    """her clips: walk (a runway walk: feet in one line, hips popping, head level and aloof, the coffee steady, the case swinging),
    run (a panicked trot in heels), idle (weight on one hip, breathing, a sip of coffee)"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, g, arm_r, arm_l, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        c = math.cos(TAU * u)
        p.rot("upper_arm.R", -arm_r * c, 0, 0)
        p.rot("forearm.R", -6.0 - (18.0 if run else 4.0) * max(0.0, -c), 0, 0)
        p.world["case"] = R(-(9.0 if not run else 22.0) * math.cos(TAU * u - 0.8), 3.0 * math.sin(TAU * u), 0)
        p.rot("upper_arm.L", arm_l * c, 0, 0)
        p.rot("forearm.L", -arm_l * 0.8 * c, 0, 0)
        p.world["hand.L"] = R(1.5 * math.sin(2 * TAU * u), 0, 0)          # the cup kept upright
        p.rot("shoulder.R", 0, 0, 2.0 * c)
        p.rot("neck", (6.0 if run else 1.0), 0, 0)
        p.world["head"] = R((4.0 if run else -2.0) + 1.2 * math.sin(2 * TAU * u), 0, 0)
        fl = (-22.0 if run else 0.0) + 6.0 * math.sin(2 * TAU * u + 0.6)
        p.rot("fin.L", 0, 0, fl)
        p.rot("fin.R", 0, 0, -fl)
        return p
    walk = [walkish(i / 32.0, WALK, 13.0, 3.0, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, 34.0, 8.0, True) for i in range(25)]

    # the sip: the cup's lid brought to her lips, tipped toward her, the elbow out
    sh, el, wr = Vector(SHOULDER.tolist()), Vector(C_ELBOW.tolist()), Vector(C_WRIST.tolist())
    line = (wr - sh).normalized()
    pole_rest = (el - sh) - line * (el - sh).dot(line)
    lid = Vector((C_WRIST + C_HAND @ (CUP_AT + v3((0, -0.075, 0)))).tolist())
    lips = Vector((0.0, -0.118, 1.672))
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sw = 0.006 * math.sin(TAU * t / 6.0)
        stand(rig, p, legs, {"L": (Vector((0.07, -0.06, 0.0)), 6.0), "R": (Vector((-0.095, 0.0, 0.0)), -16.0)},
              hip_shift=(0.028 + sw, 0.0, -0.014), roll=-4.0, yaw=-5.0)
        p.rot("spine", 1.0 * math.sin(TAU * t / 3.0), 2.0, 3.0)
        p.rot("chest", 1.2 * math.sin(TAU * t / 3.0), 1.5, 2.0)
        s = ease((t - 2.0) / 0.7) * (1.0 - ease((t - 3.6) / 0.8))
        rot_h = R(-24.0 * s, 0, 30.0 * s)
        tgt = wr.lerp(lips - rot_h @ (lid - wr), s)
        p.ik["upper_arm.L"] = (tgt, pole_rest + Vector((0.05, 0.0, -0.05)) * s, "hand.L", rot_h)
        p.rot("upper_arm.R", 1.5 * math.sin(TAU * t / 6.0), 0, 0)
        p.world["case"] = R(1.2 * math.sin(TAU * t / 3.0), 0, 0)
        p.world["head"] = R(-7.0 * s, 0, 7.0 * math.sin(TAU * t / 6.0) * (1.0 - s))
        fl = 4.0 * math.sin(TAU * t / 2.0)
        p.rot("fin.L", 0, 0, fl)
        p.rot("fin.R", 0, 0, -fl)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
