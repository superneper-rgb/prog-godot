## FOINT CITY townsfolk: the blob. A round purple many-eyed fellow in worn canvas overalls: five eyes up on stalks, each with a mind of its own, a gap-toothed grin, stumpy legs in work boots; he waddles.
# Upgrade of the three.js game's blob (folk-species-a.js; old render refs/old/blob.png): same idea (purple ball, five eye stalks, beige
# overalls with brown straps and brass buttons, a toothy mouth over the bib, brown shoes), lifted to the new sheets (refs 4/6/7):
# chunky pear body, heavy-lidded eyes looking every which way, a crescent grin with three teeth and a tongue, canvas worn and dirty.
# 1.30 m to the top of the tallest eye; the body is 0.80 m of it.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, ridge_line, v3, basis, place, noise3)

HEIGHT = 1.30
REF = ("old/blob.png", None)

SKIN, EYE, MOUTH, TOOTH, TONGUE, OVERALL, STRAP, BRASS, BOOT, SOLE, LACE, PENCIL, ERASER = range(1, 14)
COLOURS = {
    SKIN: ((0.24, 0.08, 0.42), 0.55, 0.0),
    EYE: ((0.9, 0.86, 0.78), 0.2, 0.0),
    MOUTH: ((0.06, 0.01, 0.03), 0.6, 0.0),
    TOOTH: ((0.86, 0.8, 0.66), 0.35, 0.0),
    TONGUE: ((0.66, 0.2, 0.3), 0.4, 0.0),
    OVERALL: ((0.58, 0.48, 0.32), 0.85, 0.0),
    STRAP: ((0.22, 0.12, 0.06), 0.55, 0.0),
    BRASS: ((0.8, 0.56, 0.2), 0.3, 1.0),
    BOOT: ((0.2, 0.1, 0.05), 0.5, 0.0),
    SOLE: ((0.7, 0.62, 0.48), 0.8, 0.0),
    LACE: ((0.8, 0.74, 0.6), 0.8, 0.0),
    PENCIL: ((0.86, 0.6, 0.08), 0.5, 0.0),
    ERASER: ((0.85, 0.4, 0.45), 0.7, 0.0),
}

# landmarks, left side (+X); the figure faces -Y
HIP = v3((0.165, 0.0, 0.40))
KNEE = v3((0.17, -0.012, 0.255))
ANKLE = v3((0.175, 0.0, 0.115))
BALL = v3((0.175, -0.065, 0.0))           # what the boot stands and rolls on
SHOULDER = v3((0.30, 0.0, 0.75))
ELBOW = v3((0.495, -0.005, 0.635))
WRIST = v3((0.55, -0.04, 0.505))
HAND = basis(-(WRIST - ELBOW), v3((0, 1, 0)))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
UP = v3((0, 0, 1))


def unit(x):
    x = v3(x)
    return x / np.linalg.norm(x)


# the five eyes: (bone, stalk base, eye centre, eyeball radius, where it looks, how heavy its lid is 0..1)
STALKS = [
    ("stalk0", v3((0.0, -0.05, 0.975)), v3((0.0, -0.085, 1.232)), 0.058, unit((0.0, -1.0, 0.05)), 0.35),
    ("stalk1.L", v3((0.25, -0.03, 0.905)), v3((0.37, -0.07, 1.12)), 0.05, unit((0.5, -1.0, 0.15)), 0.6),
    ("stalk1.R", v3((-0.25, -0.04, 0.905)), v3((-0.35, -0.11, 1.16)), 0.052, unit((-0.15, -1.0, -0.2)), 0.1),
    ("stalk2.L", v3((0.10, 0.15, 0.955)), v3((0.17, 0.19, 1.17)), 0.045, unit((0.65, -0.2, 0.75)), 0.45),
    ("stalk2.R", v3((-0.11, 0.14, 0.955)), v3((-0.205, 0.22, 1.13)), 0.046, unit((-0.95, 0.15, 0.2)), 0.75),
]


def core():
    """the round purple body: a pear, broad below"""
    return Union([
        Ellipsoid((0, 0.0, 0.665), (0.372, 0.35, 0.335)),
        Ellipsoid((0, 0.012, 0.54), (0.402, 0.365, 0.25)),
    ], k=0.13, part=SKIN)


def front_y(shape, x, z, y0=-0.8, y1=0.4):
    """where a ray from the front at (x, z) first meets the shape"""
    ys = np.linspace(y0, y1, 2401).astype(np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


def prism(poly_xz, y0=-0.8, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from y0 to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


# the grin: a crescent cut into the front of the body above the bib (the lower ellipsoid less an upper one, so the corners turn up)
MZ = 0.835                       # the mouth's height
MY = -0.30                       # the body's front there (probed)
MOUTH_LO = Ellipsoid((0, MY - 0.005, MZ), (0.15, 0.11, 0.07))
MOUTH_HI = Ellipsoid((0, MY - 0.055, MZ + 0.077), (0.21, 0.16, 0.075))
BIB_TOP = 0.72
BIB = [(-0.185, 0.48), (0.185, 0.48), (0.165, BIB_TOP), (-0.165, BIB_TOP)]
POCKET = [(-0.09, 0.555), (0.09, 0.555), (0.10, 0.665), (-0.10, 0.665)]


def mouth_cavity():
    return Cut(MOUTH_LO, [MOUTH_HI], k=0.012)


def body_skin():
    c = core()
    cav = mouth_cavity()
    lips = Clip(Inflate(cav, 0.016, part=SKIN), [Inflate(c, 0.011)], k=0.006)
    b = Union([c, lips], k=0.012, part=SKIN)
    b = Cut(b, [cav], k=0.006)
    # the mouth's inside: a dark throat behind the opening, the tongue lolling on the lower lip, three teeth from the upper
    throat = Ellipsoid((0, MY + 0.10, MZ - 0.005), (0.15, 0.06, 0.07), part=MOUTH)
    tongue = Union([Ellipsoid((0.012, MY + 0.03, MZ - 0.05), (0.075, 0.05, 0.03)), Ellipsoid((0.03, MY - 0.01, MZ - 0.042), (0.04, 0.035, 0.02))], k=0.02, part=TONGUE)
    teeth = []
    for x, w, h, tilt in ((-0.052, 0.021, 0.028, -6), (0.0, 0.025, 0.033, 2), (0.056, 0.02, 0.025, 9)):
        top = MZ + 0.077 - 0.075 * np.sqrt(max(0.0, 1.0 - (x / 0.21) ** 2)) + 0.01
        y = front_y(c, x, top - 0.02) + 0.014
        teeth.append(Box((x, y, top - h * 0.5), (w * 0.5, 0.012, h * 0.5 + 0.006), rr=0.006, R=rot(ry=tilt), part=TOOTH))
    return Union([b, throat, tongue] + teeth, k=0.0)


def overalls():
    c = core()
    shell = Inflate(c, 0.013, part=OVERALL)
    keep = Union([
        Half((0, 0, 0.555), (0, 0, 1)),                                                       # the trousers' seat, all round below the waist
        prism(BIB, -0.8, 0.0),                                                                 # the bib
        prism([(-0.2, 0.50), (0.2, 0.50), (0.17, 0.70), (-0.17, 0.70)], 0.0, 0.8),            # the back panel
    ])
    ov = Clip(shell, [keep], k=0.004)
    # the bib pocket: a thicker layer of the canvas inside its outline, a pencil in it
    pocket = Clip(Inflate(c, 0.021, part=OVERALL), [prism(POCKET, -0.8, -0.1)], k=0.004)
    py = front_y(c, 0.055, 0.64)
    pencil = Union([
        RoundCone((0.05, py - 0.012, 0.60), (0.066, py - 0.02, 0.705), 0.0085, 0.0085, part=PENCIL),
        RoundCone((0.066, py - 0.02, 0.705), (0.068, py - 0.021, 0.72), 0.009, 0.009, part=ERASER),
    ])
    # straps up over the dome to the back panel, buckled at the bib, brass buttons at the hips
    band = Mirror(Clip(Inflate(c, 0.019, part=STRAP), [Half((0.166, 0, 0), (-1, 0, 0)), Half((0.214, 0, 0), (1, 0, 0)), Half((0, 0, BIB_TOP - 0.06), (0, 0, -1))], k=0.003))
    parts = [ov, pocket, band, pencil]
    bz = BIB_TOP - 0.022
    by = front_y(c, 0.19, bz)
    parts.append(Mirror(Union([
        Box((0.19, by - 0.022, bz), (0.03, 0.007, 0.024), rr=0.006, part=BRASS),
        Box((0.19, by - 0.028, bz), (0.012, 0.004, 0.026), rr=0.003, part=BRASS),
    ])))
    hy = front_y(c, 0.36, 0.53)
    parts.append(Mirror(Ellipsoid((0.355, hy - 0.004, 0.53), (0.014, 0.024, 0.024), R=rot(rz=-50), part=BRASS)))
    return Union(parts, k=0.0)


def leg():
    """left leg from under the body: the overalls' short leg with a rolled cuff, a purple ankle, a work boot"""
    trouser = loft([(HIP + v3((0, 0, 0.0)), 0.095), (KNEE, 0.092), (v3((0.175, -0.004, 0.205)), 0.094)], part=OVERALL, k=0.02)
    trouser = Clip(trouser, [Half((0, 0, 0.19), (0, 0, -1))], k=0.004)
    cuff = Torus((0.175, -0.004, 0.198), 0.088, 0.02, part=OVERALL)
    ankle = RoundCone((0.175, -0.004, 0.21), (0.175, 0.0, 0.12), 0.06, 0.056, part=SKIN)
    return Union([trouser, cuff, ankle], k=0.0), boot()


def boot():
    """a chunky work boot: a rounded block of a foot with a bulbous toe, a short shaft with a padded collar, a lugged sole the shape of the foot"""
    a = ANKLE
    x = a[0]
    foot = Union([
        Box((x, -0.035, 0.058), (0.062, 0.118, 0.05), rr=0.045),
        Ellipsoid((x + 0.004, -0.112, 0.056), (0.068, 0.07, 0.054)),
    ], k=0.03, part=BOOT)
    shaft = CappedCone((x, 0.008, 0.05), (x, 0.0, 0.175), 0.068, 0.064, rr=0.014, part=BOOT)
    collar = Torus((x, 0.002, 0.172), 0.058, 0.014, part=BOOT)
    upper = Clip(Union([foot, shaft], k=0.03, part=BOOT), [Half((0, 0, 0.03), (0, 0, -1))], k=0.004)
    tongue = Box((x, -0.06, 0.15), (0.032, 0.012, 0.04), rr=0.011, R=rot(rx=-18), part=BOOT)
    sole = Clip(Inflate(foot, 0.008, part=SOLE), [Half((0, 0, 0.034), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)
    laces = []
    for yy, zz in ((-0.058, 0.142), (-0.074, 0.118), (-0.092, 0.096)):
        laces.append(Box((x, yy, zz), (0.034, 0.006, 0.0055), rr=0.005, R=rot(rx=-40), part=LACE))
    return Union([Union([upper, collar, tongue], k=0.01), sole] + laces, k=0.0)


def hand(s=1.15):
    """a relaxed chunky hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): three fingers and a thumb; s scales it"""
    palm = Ellipsoid(v3((0.0, 0.0, -0.045)) * s, v3((0.026, 0.046, 0.048)) * s, part=SKIN)
    wrist = RoundCone(v3((0, 0, 0.04)) * s, v3((0, 0, -0.01)) * s, 0.04 * s, 0.036 * s, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.027, 0.9), (0.0, 1.0), (0.027, 0.86)):
        pts = [((0.0, f, -0.075), 0.018), ((-0.006, f * 1.05, -0.075 - 0.032 * L), 0.0165), ((-0.02, f * 1.08, -0.075 - 0.056 * L), 0.015)]
        parts.append(loft([(v3(p) * s, r * s) for p, r in pts], part=SKIN, k=0.006))
    parts.append(loft([(v3((-0.012, -0.034, -0.03)) * s, 0.019 * s), (v3((-0.03, -0.055, -0.058)) * s, 0.0165 * s), (v3((-0.04, -0.058, -0.08)) * s, 0.0145 * s)], part=SKIN, k=0.006))
    return Union(parts, k=0.012)


def arm():
    a = loft([(SHOULDER, 0.07), (ELBOW, 0.06), (WRIST, 0.052)], part=SKIN, k=0.02)
    return Union([a, place(hand(), WRIST, HAND)], k=0.015)


def lid_dir(fwd):
    """the way a lid's edge plane faces: up and a little back from where the eye looks"""
    return unit(UP - fwd * 0.35)


def lid_t(lid):
    """how far (in eyeball radii, along lid_dir) the lid's edge sits from the eye's centre"""
    return 0.62 - 0.85 * lid


def eyes():
    """the stalks, eyeballs and lids"""
    parts = []
    for name, base, ec, re, fwd, lid in STALKS:
        back = ec - fwd * re * 0.55
        out = unit(v3((base[0], base[1], 0.0)) + v3((0, -0.01, 0)))
        m1 = base + (back - base) * 0.35 + out * 0.012
        m2 = base + (back - base) * 0.7 - out * 0.01
        stalk = Union([Sphere(base - v3((0, 0, 0.022)), 0.042, part=SKIN),
                       loft([(base, 0.03), (m1, 0.021), (m2, 0.0175), (back, 0.019)], part=SKIN, k=0.02)], k=0.03)
        # the lid: a skin shell over the top and back of the eyeball, coming down the front as far as `lid` says (0 just the crown, 1 sleepy)
        mm = lid_dir(fwd)
        shell = Clip(Sphere(ec, re + 0.0065, part=SKIN), [Half(ec + mm * re * lid_t(lid), -mm)], k=0.004)
        lower = Clip(Sphere(ec, re + 0.004, part=SKIN), [Half(ec - UP * re * 0.62, UP)], k=0.003)
        ball = Sphere(ec, re, part=EYE)
        parts.append(Union([Union([stalk, shell, lower], k=0.014), ball], k=0.0))
    return Union(parts, k=0.0)


def pieces():
    lg, bt = leg()
    body = Union([body_skin(), overalls(), Mirror(Union([lg, bt])), Mirror(arm())], k=0.0)
    return [("body", body, 0.0035), ("eyes", eyes(), 0.0018)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n1 = noise3(P, 0.06)
    n2 = noise3(P, 0.017)
    mott = n1 * 0.5 + n2 * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (m.sum(), 3)), np.broadcast_to(np.asarray(amt, np.float32), (m.sum(),))[:, None]], 1)

    # skin: grape purple, lighter lilac up the dome, deep plum underneath and in the folds, mottled, pale speckles
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(122, 62, 172), (len(P), 3)).copy()
    sk = sk + (srgb(158, 104, 206) - sk) * (smooth(0.86, 1.12, z) * 0.7)[:, None]
    sk = sk + (srgb(78, 34, 118) - sk) * (smooth(0.62, 0.3, z) * 0.55)[:, None]
    sk *= (1.0 + 0.10 * mott)[:, None]
    blot = smooth(0.15, 0.6, noise3(P + 3.1, 0.04))
    sk = sk + (srgb(92, 40, 146) - sk) * (blot * 0.5)[:, None]
    fine = smooth(0.3, 0.8, noise3(P + 9.7, 0.008))
    sk = sk + (srgb(176, 128, 214) - sk) * (fine * 0.18)[:, None]
    put(m, sk, 0.5, bump=0.35)
    spk(m, (196, 160, 232), 0.32)
    # the mouth: a dark throat, the lips' inner edge a deep plum, the tongue, the teeth (yellowed toward the gums)
    inside = m & (mouth_cavity().eval(P)[0] < 0.004)
    c.col[inside] = srgb(64, 16, 44)
    m = c.mask(MOUTH)
    put(m, srgb(40, 8, 22), 0.6)
    m = c.mask(TONGUE)
    tg = srgb(206, 92, 124) * (1.0 + 0.12 * n2)[:, None]
    put(m, tg, 0.32, bump=0.3)
    c.draw(m & (np.abs(x - 0.02) < 0.01) & (y < MY + 0.01), np.abs(x - 0.02), 0.0012, 0.35)
    m = c.mask(TOOTH)
    th = srgb(238, 228, 200) + (srgb(196, 170, 110) - srgb(238, 228, 200)) * smooth(MZ - 0.03, MZ + 0.015, z)[:, None] * 0.6
    put(m, th, 0.3, bump=0.1)

    # eyes: cream whites, amber-yellow irises looking where their stalk points, inked pupils, a hard glint each
    m = c.mask(EYE)
    ey = np.broadcast_to(srgb(240, 232, 212), (len(P), 3)).copy()
    for name, base, ec, re, fwd, lid in STALKS:
        dv = P - ec
        r = np.linalg.norm(dv, axis=1)
        near = m & (r < re * 1.25)
        d = dv / np.maximum(r, 1e-6)[:, None]
        ang = np.arccos(np.clip(d @ fwd, -1, 1))
        ir = srgb(246, 204, 64) + (srgb(214, 128, 26) - srgb(246, 204, 64)) * smooth(0.1, 0.5, ang)[:, None]
        ey[near] = np.where((ang < 0.55)[near, None], ir[near], ey[near])
        ey[near] = np.where(((ang > 0.5) & (ang < 0.6))[near, None], srgb(120, 66, 20), ey[near])
        ey[near] *= (1.0 - 0.25 * smooth(0.9, 1.6, ang[near]))[:, None]       # veined, shadowed toward the stalk
        c.draw(near, (ang - 0.27) * re, 0.0)
        c.draw(near & (ang < 0.7), np.abs(ang - 0.56) * re, 0.0007, 0.6)
        side = np.cross(fwd, UP)
        side /= max(np.linalg.norm(side), 1e-6)
        gdir = unit(fwd + UP * 0.45 - side * 0.35)
        g = smooth(0.2, 0.12, np.arccos(np.clip(d @ gdir, -1, 1)))
        ey[near] = ey[near] + (srgb(255, 252, 240) - ey[near]) * g[near, None]
        # a liner where the lid meets the eyeball
        lm = c.mask(SKIN) & (r < re + 0.012)
        mm = lid_dir(fwd)
        pd = (P - (ec + mm * re * lid_t(lid))) @ mm          # > 0 on the lid
        c.draw(lm & (pd > -0.006) & (pd < 0.012), np.abs(pd - 0.001), 0.0016, 0.9)
    put(m, ey, 0.08)
    c.spk[m, 3] = 0.0

    # overalls: sand canvas, darker and dirtier toward the cuffs, stains, double stitching along the bib, pocket and cuffs, a patch on the right leg
    m = c.mask(OVERALL)
    ov = np.broadcast_to(srgb(196, 172, 128), (len(P), 3)).copy()
    ov *= (1.0 + 0.08 * mott)[:, None]
    dirt = smooth(0.42, 0.18, z) * 0.55 + smooth(0.35, 0.75, noise3(P + 7.3, 0.05)) * 0.45
    ov = ov + (srgb(118, 92, 62) - ov) * dirt[:, None]
    # a patch sewn over the seat's front right: faded blue-grey canvas, tilted, big running stitches round it
    pu, pv = ((x + 0.2) * 0.97 + (z - 0.43) * 0.24) / 0.06, (-(x + 0.2) * 0.24 + (z - 0.43) * 0.97) / 0.048
    pdist = np.maximum(np.abs(pu), np.abs(pv))
    inp = m & (pdist < 1.0) & (y < 0.0)
    ov[inp] = srgb(98, 112, 128) * (1.0 + 0.12 * mott[inp])[:, None]
    put(m, ov, 0.88, bump=1.0, grain=0.0)
    spk(m, (92, 70, 46), 0.3)
    run = np.sin((pu + pv) * 9.0) > 0.0
    c.draw(inp & run, np.abs(pdist - 0.82) * 0.055, 0.0017, 0.85)
    # stitching: dashed lines just inside the bib's edges and the pocket's
    dash = np.sin((x + z) * 260.0) > -0.1
    bib_edge = m & (y < -0.1) & (z > 0.55)
    ex = np.minimum(np.abs(np.abs(x) - (0.185 - (z - 0.48) * 0.02 / (BIB_TOP - 0.48))), np.abs(z - BIB_TOP))
    c.draw(bib_edge & dash & (z < BIB_TOP + 0.015), np.abs(ex - 0.011), 0.0011, 0.75)
    (x0, z0), (x1, z1) = POCKET[1], POCKET[2]
    pk = m & (y < -0.22) & (np.abs(x) < x1 + 0.02) & (z > z0 - 0.015) & (z < z1 + 0.015)
    pe = np.minimum(np.abs(np.abs(x) - (x0 + (z - z0) * (x1 - x0) / (z1 - z0))), np.abs(z - z1))
    c.draw(pk & dash, np.abs(pe - 0.008), 0.0011, 0.75)
    c.draw(m & (np.abs(z - 0.555) < 0.02) & dash, np.abs(z - 0.567), 0.0011, 0.6)
    m = c.mask(STRAP)
    st = srgb(112, 66, 36) * (1.0 + 0.5 * c.wear)[:, None] * (1.0 + 0.1 * mott)[:, None]
    put(m, st, 0.5, bump=0.8, grain=1.0)
    c.draw(m & dash, np.abs(np.abs(Q[:, 0] - 0.19) - 0.014), 0.0009, 0.6)
    m = c.mask(BRASS)
    put(m, srgb(214, 160, 72) * (1.0 - 0.5 * c.cavity)[:, None], 0.3, metal=1.0, bump=0.1, grain=1.0)
    m = c.mask(PENCIL)
    put(m, srgb(232, 170, 30), 0.45)
    m = c.mask(ERASER)
    put(m, srgb(220, 120, 130), 0.7)
    # boots: brown leather rubbed light at the toes and edges, cream soles muddied, cream laces
    m = c.mask(BOOT)
    bt = srgb(104, 62, 34) * (1.0 + 0.8 * c.wear)[:, None] * (1.0 + 0.1 * mott)[:, None]
    put(m, bt, 0.45, bump=0.9, grain=1.0)
    c.draw(m & (np.abs(z - 0.05) < 0.01), np.abs(z - 0.048), 0.0012, 0.55)
    m = c.mask(SOLE)
    so = srgb(222, 206, 170) + (srgb(120, 100, 70) - srgb(222, 206, 170)) * (smooth(0.03, 0.0, z) * 0.7 + 0.25 * smooth(0.3, 0.8, n2))[:, None]
    put(m, so, 0.85, bump=0.4)
    c.draw(m & (np.abs(z - 0.022) < 0.01), np.abs(z - 0.022), 0.0008, 0.5)
    m = c.mask(LACE)
    put(m, srgb(226, 214, 180), 0.8, bump=0.5)

    # occlusion, except the shadow the hanging arms throw on the body's flanks (the arms swing away from it in every clip)
    ao = c.ao.copy()
    ab = np.linalg.norm(Q - (SHOULDER + ELBOW) * 0.5, axis=1) < 0.2
    flank = ab & (core().eval(P)[0] < 0.02) & (Q[:, 0] > 0.25)
    ao[flank] = 1.0 - (1.0 - ao[flank]) * 0.3
    c.col *= (0.32 + 0.68 * ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- game model: budget, rig, motion

GAME = {
    "budget": {"body": 5600, "eyes": 2600},
    "density": {"eyes": 1.6},
    "tex": 2048,
    "stride": {"walk": 0.44, "run": 0.7},
    "speed": 0.55,
    "look": ["stalk0", "stalk1.L", "stalk1.R"], "neck": "chest",
    "look_pivot": (0.0, -0.02, 0.95),
    "radius": 0.45,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.0, 0.40), (0, 0.0, 0.58), "root", 0.33),
        Bone("spine", (0, 0.0, 0.58), (0, 0.0, 0.74), "hips", 0.33),
        Bone("chest", (0, 0.0, 0.74), (0, 0.0, 0.98), "spine", 0.3),
        Bone("thigh.L", HIP, KNEE, "hips", 0.09),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.07),
        Bone("foot.L", ANKLE, (0.175, -0.15, 0.03), "shin.L", 0.05),
        Bone("upper_arm.L", SHOULDER, ELBOW, "chest", 0.06),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.05),
        Bone("hand.L", WRIST, WRIST - HAND[:, 2] * 0.12, "forearm.L", 0.04),
    ])
    for name, base, ec, re, fwd, lid in STALKS:
        bones.append(Bone(name, base - v3((0, 0, 0.02)), ec, "chest", 0.03))
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
    bp = piece == 0
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])

    def seg(a, b):
        ab = b - a
        t = np.clip(((Q - a) @ ab) / float(ab @ ab), 0.0, 1.0)
        return np.linalg.norm(Q - a - np.outer(t, ab), axis=1)
    # a leg is the overalls' short leg, cuff and boot (near the leg's axis, under the body); its top blends into the hips
    leg_d = np.minimum(seg(HIP, KNEE), seg(KNEE, ANKLE))
    legs = bp & ((z < 0.2) | (z < 0.34) & (leg_d < 0.125))
    allow(legs & (z > 0.27), "hips")
    allow(legs & (x > 0), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0), "thigh.R", "shin.R", "foot.R")
    # an arm is what lies nearer the arm's bones than the body's clay
    hand_end = WRIST - HAND[:, 2] * 0.14
    arm_d = np.minimum(np.minimum(seg(SHOULDER, ELBOW) - 0.07, seg(ELBOW, WRIST) - 0.06), seg(WRIST, hand_end) - 0.05)
    body_d = core().eval(P)[0] - 0.013
    arms = bp & ~legs & (Q[:, 0] > 0.28) & (arm_d < body_d)
    allow(arms & (x > 0), "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x < 0), "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (arm_d > body_d - 0.03), "chest")
    trunk = bp & ~legs & ~arms
    allow(trunk, "hips", "spine", "chest")
    rig[trunk & (z > 0.84)] = ix["chest"]
    # each eye rides its stalk bone; the stalk's root melts into the dome
    ep = piece == 1
    best = np.full(n, 1e9)
    which = np.full(n, -1)
    for name, base, ec, re, fwd, lid in STALKS:
        d = np.linalg.norm(P - (base + ec) * 0.5, axis=1)
        t = d < best
        best = np.where(t, d, best)
        which = np.where(t, ix[name], which)
    for name, base, ec, re, fwd, lid in STALKS:
        mine = ep & (which == ix[name])
        h = (P - base) @ unit(ec - base)
        rig[mine & (h > 0.03)] = ix[name]
        allow(mine & (h <= 0.03), "chest", name)
    return A, rig


def motions(rig):
    """walk: a rocking waddle, the whole ball leaning over each planted boot, arms paddling out, the stalks swinging behind the beat;
    run: a hurried bouncing waddle, stalks streaming back; idle: breathing, the five eyes each looking about on its own, now and then all at once"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    phase = {"stalk0": 0.0, "stalk1.L": 0.7, "stalk1.R": 1.3, "stalk2.L": 2.1, "stalk2.R": 2.8}

    def waddle(u, run):
        g = dict(stride=0.70 if run else 0.44, stance=0.46 if run else 0.6, foot_x=0.16, lift=0.075 if run else 0.05,
                 bob=0.03 if run else 0.016, drop=0.035 if run else 0.025, sway=0.05 if run else 0.042, roll=0.0, yaw=8.0 if run else 6.0,
                 counter=0.3, lean=9.0 if run else 3.0, toe_off=10.0, toe_out=12.0, swing_point=4.0)
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.offset = p.offset + Vector((0.0, 0.035, 0.0))                 # centre the hips over the boots' travel (the ball is ahead of the ankle)
        s = math.sin(TAU * u)
        c = math.cos(TAU * u)
        rk = (11.0 if run else 9.0) * s                                  # the whole ball leans over the planted boot
        p.rot("hips", 0, rk * 0.6, 0)
        p.rot("spine", 0, rk * 0.25, 0)
        p.rot("chest", 2.0 * math.sin(2 * TAU * u + 1.0), rk * 0.15, 0)
        a = 22.0 if run else 12.0
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, a * c * sg, 0, -sg * ((26.0 if run else 10.0) + 6.0 * math.sin(2 * TAU * u)))
            p.rot("forearm." + side, -(30.0 if run else 10.0) - 6.0 * max(0.0, sg * c), 0, 0)
        for name, ph in phase.items():
            lag = 2 * TAU * u - 1.2 - ph * 0.3
            sw = (14.0 if run else 7.0)
            p.rot(name, (16.0 if run else 3.0) + sw * math.sin(lag), -rk * 0.9 + 3.0 * math.sin(TAU * u + ph), 4.0 * math.sin(TAU * u * 1.0 + ph))
        return p
    walk = [waddle(i / 32.0, False) for i in range(33)]
    run = [waddle(i / 24.0, True) for i in range(25)]

    # idle: each eye looks about on its own (yaw, pitch keyed in a little loop), and at 2.4-3.4 s all five swing round to the same spot
    looks = {
        "stalk0": [(0.0, 0, 0), (1.2, 18, 4), (3.0, -10, -6), (4.6, 4, 8)],
        "stalk1.L": [(0.0, 20, -4), (1.6, -6, 10), (3.6, 30, 0), (5.0, 10, -8)],
        "stalk1.R": [(0.0, -15, 6), (0.8, -30, -4), (2.0, 8, 12), (4.2, -18, 0)],
        "stalk2.L": [(0.0, 30, 10), (1.9, 50, -6), (3.8, 10, 4), (5.2, 40, 14)],
        "stalk2.R": [(0.0, -35, 0), (1.0, -10, 14), (3.2, -50, -4), (4.8, -25, 6)],
    }

    def keyed(keys, t):
        ks = keys + [(6.0, keys[0][1], keys[0][2])]
        for (t0, a0, b0), (t1, a1, b1) in zip(ks, ks[1:]):
            if t0 <= t < t1:
                w = ease((t - t0) / min(0.35, t1 - t0))
                return a0 + (a1 - a0) * w, b0 + (b1 - b0) * w
        return ks[-1][1], ks[-1][2]

    def prev_val(keys, t):
        return keyed(keys, t)
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        br = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.18, -0.06, 0.0)), 14.0), "R": (Vector((-0.17, -0.03, 0.0)), -10.0)},
              hip_shift=(0.008 * math.sin(TAU * t / 6.0), 0.035, -0.012 + 0.006 * br), roll=1.5 * math.sin(TAU * t / 6.0))
        p.rot("spine", 1.2 * br, 0, 0)
        p.rot("chest", 1.5 * br, 0, 2.0 * math.sin(TAU * t / 6.0))
        for side, sg in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + side, 2.0 * math.sin(TAU * t / 3.0 + sg), 0, -sg * (4.0 + 2.5 * br))
            p.rot("forearm." + side, -6.0, 0, 0)
        together = ease((t - 2.4) / 0.25) * (1.0 - ease((t - 3.4) / 0.3))
        for name, keys in looks.items():
            yw, pt = keyed(keys, t)
            yw = yw + (-12.0 - yw) * together
            pt = pt + (6.0 - pt) * together
            p.rot(name, -pt + 2.0 * math.sin(TAU * t / 3.0 + phase[name]), 0, yw)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
