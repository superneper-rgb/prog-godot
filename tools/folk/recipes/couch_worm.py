## FOINT CITY townsfolk: the couch worm (working name; the user names him). A squat ochre lump on two huge padded feet, a ringed red worm neck rising out of a floral shirt and striped tie, a small droopy buck-toothed head.
# Concept: the user's sheet, image 6 top left (F:/prog-godot-cache/folk/refs/6.webp). Measured off a 3x crop (736 px a metre): 1.40 m to the top of the lids;
# the head 0.23 tall and 0.17 wide; the neck 0.21 thick at the collar; the collar at 0.92; the bare hump behind it at 1.2; the shirt's hem at 0.29;
# the feet 0.6 long, 0.3 tall at the ankle, four toes with big pale nails. Rest pose: the long arms dangle forward of the belly, the hands by the knees.
# The remote of the concept is dropped (roster): his hands hang free. The pens in his pocket and his digital watch are costume.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.40
REF = ("6.webp", (5, 8, 402, 363))

SKIN, WORM, NAIL, EYE, TOOTH, MOUTH, SHIRT, BUTTON, TIE, PEN, PENCAP, WATCH, SCREEN = range(1, 14)
COLOURS = {
    SKIN: ((0.66, 0.40, 0.09), 0.6, 0.0),
    WORM: ((0.42, 0.10, 0.08), 0.5, 0.0),
    NAIL: ((0.62, 0.56, 0.50), 0.4, 0.0),
    EYE: ((0.78, 0.72, 0.36), 0.2, 0.0),
    TOOTH: ((0.82, 0.72, 0.46), 0.3, 0.0),
    MOUTH: ((0.08, 0.01, 0.02), 0.5, 0.0),
    SHIRT: ((0.17, 0.27, 0.46), 0.8, 0.0),
    BUTTON: ((0.76, 0.70, 0.56), 0.35, 0.0),
    TIE: ((0.45, 0.06, 0.06), 0.6, 0.0),
    PEN: ((0.40, 0.02, 0.02), 0.3, 0.0),
    PENCAP: ((0.03, 0.03, 0.03), 0.3, 0.0),
    WATCH: ((0.62, 0.42, 0.08), 0.4, 0.0),
    SCREEN: ((0.10, 0.12, 0.08), 0.15, 0.0),
}
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
UP = v3((0, 0, 1))

# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; he faces -Y)
# the feet: each points forward and 16 degrees out; FOOT_O is the ground under the ankle
FOOT_YAW = np.radians(22.0)
FWD = v3((np.sin(FOOT_YAW), -np.cos(FOOT_YAW), 0.0))
SIDE = v3((np.cos(FOOT_YAW), np.sin(FOOT_YAW), 0.0))
FR = np.stack([SIDE, FWD, UP], 1).astype(np.float32)        # foot frame: x out, y along the toes, z up
FOOT_O = v3((0.31, 0.05, 0.0))


def fp(al, sd, up):
    """a point in the left foot's frame: along the toes, out to the side, up"""
    return FOOT_O + FWD * al + SIDE * sd + UP * up


ANKLE = v3((0.30, 0.05, 0.21))
HIP = v3((0.18, 0.03, 0.56))         # deep in the sack: the stump's top must stay inside the shirt
KNEE = v3((0.25, -0.04, 0.38))
BALL = fp(0.26, 0.0, 0.0)          # the root of the toes, what the foot rolls over

# the arms hang forward of the belly, out from it
SHOULDER = v3((0.29, -0.03, 0.82))
ELBOW = v3((0.42, -0.085, 0.625))
WRIST = v3((0.50, -0.21, 0.48))          # elbows a little bent, so the hands hang over the toes, clear of the feet when they lift
HAND = basis(-v3((0.22, -0.31, -0.92)), v3((0, 1, 0)))     # the hand hangs slack: fingers down, the back of the hand out, the thumb forward

# the neck: a ringed tube from inside the collar up and forward into the back of the head
NECK = [(v3((0, -0.05, 0.80)), 0.112), (v3((0, -0.072, 0.96)), 0.102), (v3((0, -0.105, 1.075)), 0.092), (v3((0, -0.155, 1.155)), 0.083),
        (v3((0, -0.2, 1.215)), 0.077)]
RING = 0.036                                                # ring pitch along the neck
# the head: mostly two big lidded eyes on top, a bulbous snout and two great buck teeth
EYE_C = v3((0.05, -0.262, 1.352))
EYE_R = 0.036
LID_PT = EYE_C + v3((0, 0, 0.012))
LID_N = v3((-0.12, 0.15, -1.0)) / np.linalg.norm((-0.12, 0.15, -1.0))      # away from the heavy upper lid: its edge droops outward and forward
LOW_PT = EYE_C + v3((0, 0, -0.028))
LOW_N = v3((0.0, 0.15, 1.0)) / np.linalg.norm((0.0, 0.15, 1.0))


# ---------------------------------------------------------------------------------------------------- helpers

def prism(poly_xz, y0=-0.7, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from y0 to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def side_prism(poly_yz, x0=-0.7, x1=0.7):
    """a side-view outline (y, z) pushed through the figure from x0 to x1"""
    return Slab(((x0 + x1) * 0.5, 0, 0), poly_yz, (x1 - x0) * 0.5, R=np.array([[0, 0, 1], [1, 0, 0], [0, 1, 0]], np.float32))


def front_y(shape, x, z, y0=-0.8, y1=0.4):
    """where a ray from the front at (x, z) first meets the shape (probe the clay before placing things on it)"""
    ys = np.arange(y0, y1, 0.0005, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    i = int(np.argmax(d < 0))
    return float(ys[i])


def squash(child, sx=1.0, sy=1.0, sz=1.0, at=(0, 0, 0)):
    """the child shrunk by (sx, sy, sz) <= 1 about `at` (gentle squashes only: the distance stays close to true, and the bound stays safe)"""
    S = np.diag([1.0 / sx, 1.0 / sy, 1.0 / sz]).astype(np.float32)
    return Move(child, R=S, pivot=at)


# ---------------------------------------------------------------------------------------------------- framing (a kit gap, worked round here)
# kit/look.render_views frames a figure 0.62 as wide as it is tall and aims the face views at 0.9 of its height. He is nearly as wide
# as he is tall and his head sits forward of his body, so this recipe swaps in the same renderer with a wider frame and face views aimed
# at his head. Nothing else changes; the patch lives only in the Blender process that builds him.
VIEW_ASPECT = 0.9
FACE_AT = v3((0.0, -0.27, 1.29))
FACE_DIST = 1.15


def _patch_views():
    try:
        import bpy
        import math
        from kit import look
    except Exception:
        return

    def render_views(out_prefix, height=2.0, px=900, colour=False, views=("front", "q3", "side", "back"), centre_z=None):
        sc = bpy.context.scene
        look._engine(sc, colour)
        sc.render.resolution_x = int(px * VIEW_ASPECT)
        sc.render.resolution_y = px
        sc.render.film_transparent = False
        zc = height * 0.5 if centre_z is None else centre_z
        span = height * 1.08
        cams = {
            "front": ((0.0, -8.0, zc), (0.0, 0.0, zc), span),
            "side": ((8.0, 0.0, zc), (0.0, 0.0, zc), span),
            "back": ((0.0, 8.0, zc), (0.0, 0.0, zc), span),
            "q3": ((-8.0 * math.sin(math.radians(32)), -8.0 * math.cos(math.radians(32)), zc + 0.9), (0.0, 0.0, zc), span),
            "bust": ((-2.6 * math.sin(math.radians(30)), -2.6 * math.cos(math.radians(30)), height * 0.8), (0.05, 0.0, height * 0.72), None),
        }
        out = []
        for v in views:
            if v.startswith("face@"):
                a = math.radians(float(v[5:]))
                f = FACE_AT
                cams[v] = ((f[0] + FACE_DIST * math.sin(a), f[1] - FACE_DIST * math.cos(a), f[2] + 0.04), (f[0], f[1], f[2] - 0.01), None)
            loc, tgt, sp = cams[v]
            cam = look._camera("cam_" + v, loc, tgt, ortho=sp, lens=85.0)
            sc.camera = cam
            p = "%s_%s.png" % (out_prefix, v)
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            out.append(p)
        return out
    look.render_views = render_views


_patch_views()


# ---------------------------------------------------------------------------------------------------- the head and neck

def neck_rings(P):
    """1 in the grooves between the neck's rings, 0 on the rings; fades out into the collar and the head"""
    best = np.full(len(P), 1e9, np.float32)
    s = np.zeros(len(P), np.float32)
    acc = 0.0
    for i in range(len(NECK) - 1):
        a, b = NECK[i][0], NECK[i + 1][0]
        ab = b - a
        L = float(np.linalg.norm(ab))
        t = np.clip(((P - a) @ ab) / (L * L), 0.0, 1.0)
        d = np.linalg.norm(P - a - np.outer(t, ab), axis=1)
        take = d < best
        best[take] = d[take]
        s[take] = acc + t[take] * L
        acc += L
    ph = (s / RING) % 1.0
    g = np.exp(-((ph - 0.5) / 0.17) ** 2)
    x = np.clip((acc - 0.03 - s) / 0.04, 0.0, 1.0)
    return g * x * x * (3 - 2 * x)


def neck():
    tube = loft([(p, r) for p, r in NECK], part=WORM, k=0.03)
    return Bump(tube, neck_rings, -0.0048)


def head():
    skull = Ellipsoid((0, -0.215, 1.30), (0.075, 0.076, 0.072), part=WORM)
    snout = Ellipsoid((0, -0.305, 1.29), (0.062, 0.078, 0.046), R=rot(rx=8), part=WORM)     # the bulbous upper lip, pushed forward over the teeth
    cheeks = Mirror(Ellipsoid((0.054, -0.258, 1.238), (0.042, 0.05, 0.042), part=WORM))
    jaw = Ellipsoid((0, -0.262, 1.175), (0.064, 0.07, 0.034), part=WORM)            # the small lower jaw, set back under the overbite
    # the eyes sit high, frog-like, in fleshy mounds; a slot opened in each mound between the heavy upper lid and the puffy lower one
    mound = Ellipsoid(EYE_C + v3((0, 0.004, 0.001)), (0.0465, 0.046, 0.0455), part=WORM)
    look = v3((0.3, -1.0, 0.05)) / np.linalg.norm((0.3, -1.0, 0.05))
    slot = Clip(Ellipsoid(EYE_C, (0.07, 0.07, 0.07)), [Half(LID_PT, -LID_N), Half(LOW_PT, -LOW_N), Half(EYE_C + look * 0.004, -look)])
    eye_m = Cut(mound, [slot], k=0.005)
    mass = Union([skull, snout, Union([cheeks, jaw], k=0.02)], k=0.03)
    face = Union([mass, Mirror(eye_m)], k=0.016)
    # the grin: a tall open mouth under the snout, higher at the corners, a dark gullet behind it
    grin = prism([(-0.072, 1.258), (-0.06, 1.226), (-0.035, 1.205), (0.0, 1.198), (0.035, 1.205), (0.06, 1.226), (0.072, 1.258),
                  (0.064, 1.262), (0.035, 1.246), (0.0, 1.243), (-0.035, 1.246), (-0.064, 1.262)], y0=-0.5, y1=-0.262)
    face = Cut(face, [grin], k=0.005)
    gullet = Ellipsoid((0, -0.245, 1.222), (0.066, 0.04, 0.032), part=MOUTH)
    nostrils = Mirror(Ellipsoid((0.017, -0.35, 1.319), (0.0075, 0.0095, 0.005), R=rot(rx=-35), part=WORM))
    face = Cut(face, [nostrils], k=0.002)
    # two great buck teeth hanging from under the snout, a few small crooked ones on the lower jaw
    teeth = Union([Box((s * 0.0205, -0.34, 1.228), (0.0192, 0.0085, 0.042), rr=0.009, R=rot(rx=-5, rz=s * 2.5), part=TOOTH) for s in (-1, 1)])
    small = [Box((x, -0.292 + abs(x) * 0.5, 1.209), (0.0062, 0.0042, 0.0085), rr=0.002, R=rot(rz=a), part=TOOTH)
             for x, a in ((-0.042, 10), (-0.027, -6), (0.026, 8), (0.041, -12))]
    ball = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    return Union([face, gullet, ball, teeth] + small, k=0.0)


def head_piece():
    return Union([Union([neck(), head()], k=0.03)], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body: hump, belly, legs, feet, arms, shirt

HUMP = (v3((0, 0.09, 0.905)), v3((0.29, 0.18, 0.255)))          # the bare mound of his back, rising out of the shirt behind the neck


def shirt_core(flare=True):
    """the shape the shirt is cut from: the belly sack, chest and the foot of the hump, flaring at the hem (his hide is this, shrunk, without the flare)"""
    belly = Ellipsoid((0, 0.02, 0.56), (0.355, 0.275, 0.33))
    chest = Ellipsoid((0, 0.02, 0.76), (0.27, 0.21, 0.17))
    hump = Ellipsoid(HUMP[0], HUMP[1])
    kids = [belly, chest, hump]
    if flare:
        fl = squash(CappedCone((0, 0, 0.62), (0, 0, 0.28), 0.32, 0.45, rr=0.04), sy=0.76, at=(0, 0, 0))
        kids.append(Move(fl, t=(0, 0.02, 0)))
    return Union(kids, k=0.11)


def shirt_folds(P):
    """soft folds hanging from the belly to the hem, and a few creases round the arms' roots"""
    a = np.arctan2(P[:, 0], -(P[:, 1] - 0.02))
    n = noise3(P, 0.09)
    hang = 0.5 + 0.5 * np.sin(a * 11.0 + n * 2.5)
    z = P[:, 2]
    return hang * np.clip((0.58 - z) / 0.22, 0.0, 1.0) * (0.6 + 0.4 * noise3(P + 2.0, 0.05))


def yellow_body():
    """his hide: the shirt's own core shrunk a little (so it never shows through the shirt), the bottom of the sack and the leg stumps"""
    torso = Inflate(shirt_core(flare=False), -0.004, part=SKIN)
    bottom = Ellipsoid((0, 0.03, 0.34), (0.3, 0.24, 0.12), part=SKIN)
    legs = Mirror(RoundCone(HIP, ANKLE + v3((0, 0, 0.03)), 0.16, 0.15, part=SKIN))
    return Union([torso, bottom, legs], k=0.07, part=SKIN)


def foot():
    """the left foot: a broad padded dome, four fat round toes fused at the front, each shod with a flat grey hoof of a nail"""
    dome = Ellipsoid(fp(0.03, 0.0, 0.12), (0.215, 0.29, 0.16), R=FR)
    front = Ellipsoid(fp(0.24, 0.0, 0.085), (0.22, 0.17, 0.095), R=FR)
    pad = Union([dome, front], k=0.07, part=SKIN)
    toes, nails = [], []
    for sd, sc in ((-0.15, 1.0), (-0.05, 1.02), (0.05, 0.96), (0.142, 0.86)):
        c = fp(0.35 - 0.6 * sd ** 2, sd, 0.078 * sc)
        r = np.array((0.062, 0.08, 0.078)) * sc
        toes.append(Ellipsoid(c, r, R=FR, part=SKIN))
        # the nail: a broad flat plate of a shell over the toe's front, barely proud of it
        shell = Ellipsoid(c + FWD * 0.001, r + 0.0035, R=FR, part=NAIL)
        plate = Ellipsoid(c + FWD * (0.075 * sc) - UP * (0.012 * sc), np.array((0.054, 0.055, 0.052)) * sc, R=FR)
        nails.append(Clip(shell, [plate, Half(c + FWD * (0.022 * sc), -FWD)], k=0.004))
    f = Union([pad, Union(toes, k=0.022)], k=0.035)
    f = Union([f] + nails, k=0.002)
    return Clip(f, [Half((0, 0, 0.0), (0, 0, -1))], k=0.014)


def hand(s=1.15):
    """the left hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): big, slack, fingers loosely curled"""
    palm = Ellipsoid(v3((0.0, 0.0, -0.058)) * s, v3((0.024, 0.048, 0.056)) * s, part=SKIN)
    wrist = RoundCone((0, 0, 0.03), v3((0, 0, -0.02)) * s, 0.04, 0.036 * s, part=SKIN)
    parts = [palm, wrist]
    for f, L in ((-0.032, 0.86), (-0.011, 1.0), (0.011, 0.97), (0.032, 0.82)):
        pts = [((0.0, f, -0.098), 0.0145), ((-0.004, f, -0.098 - 0.035 * L), 0.0138), ((-0.018, f, -0.13 - 0.032 * L), 0.0128),
               ((-0.036, f, -0.138 - 0.026 * L), 0.0118)]
        parts.append(loft([(v3(p) * s, r * s) for p, r in pts], part=SKIN, k=0.005))
    thumb = [((-0.012, -0.038, -0.03), 0.016), ((-0.028, -0.06, -0.068), 0.014), ((-0.044, -0.058, -0.1), 0.0125)]
    parts.append(loft([(v3(p) * s, r * s) for p, r in thumb], part=SKIN, k=0.005))
    return Union(parts, k=0.01)


def arm():
    """the left arm: a long ochre arm out of a loose short sleeve, the forearm heavier than the upper arm"""
    limb = loft([(SHOULDER, 0.048), (ELBOW, 0.041), (ELBOW + (WRIST - ELBOW) * 0.45, 0.046), (WRIST, 0.04)], part=SKIN, k=0.012)
    return Union([limb, place(hand(), WRIST, HAND)], k=0.012)


def sleeve():
    """the left short sleeve: wide, set into the shoulder, hollow at the hem so the arm comes out of it"""
    d = (ELBOW - SHOULDER) / np.linalg.norm(ELBOW - SHOULDER)
    end = SHOULDER + (ELBOW - SHOULDER) * 0.72
    root = v3((0.2, -0.0, 0.84))
    s = loft([(root, 0.1), (SHOULDER + v3((0.0, 0.0, 0.01)), 0.095), (end, 0.083)], part=SHIRT, k=0.02)
    s = Clip(s, [Half(end, d)], k=0.004)
    s = Cut(s, [RoundCone(end - d * 0.07, end + d * 0.03, 0.068, 0.07)], k=0.005)
    hem = Torus(end - d * 0.01, 0.079, 0.0085, Rm=basis(d, v3((0, 0, 1))), part=SHIRT)
    return Union([s, hem], k=0.004)


def shirt():
    core = shirt_core()
    hem = Half((0, 0, 0.275), (0, 0, -1))
    back = Half((0, 0.05, 0.885), (0, 0.42, 1.0))                  # the shirt's back rides down under the hump, which rises out of it
    solid = Clip(Bump(Inflate(core, 0.012, part=SHIRT), shirt_folds, 0.006), [hem, back], k=0.005)
    hollow = Clip(Inflate(core, -0.004), [Half((0, 0, 0.37), (0, 0, 1))], k=0.02)
    s = Cut(solid, [hollow], k=0.004)
    s = Union([s, Mirror(sleeve())], k=0.02, part=SHIRT)
    neckhole = RoundCone(NECK[0][0] - v3((0, -0.01, 0.1)), NECK[1][0] + v3((0, -0.02, 0.1)), 0.112)
    s = Cut(s, [neckhole], k=0.006)
    # the breast pocket (on his right, as drawn)
    pocket = Clip(Inflate(core, 0.019, part=SHIRT), [prism([(-0.205, 0.62), (-0.085, 0.615), (-0.088, 0.775), (-0.207, 0.78)], y1=-0.05)], k=0.003)
    # the collar: a stand round the neck and two points laid down over the chest, either side of the knot
    a, b = NECK[0][0], NECK[1][0]
    stand = Cut(RoundCone(a, b, 0.128, 0.122, part=SHIRT), [RoundCone(a - v3((0, -0.02, 0.1)), b + v3((0, -0.02, 0.1)), 0.106)], k=0.003)
    stand = Clip(stand, [Half((0, 0, 0.955), (0, 0.15, 1)), Half((0, 0, 0.885), (0, -0.2, -1))], k=0.004)
    flap = Clip(Cut(Inflate(core, 0.03, part=SHIRT), [Inflate(core, 0.017)], k=0.003),
                [Mirror(prism([(0.035, 0.905), (0.125, 0.93), (0.15, 0.89), (0.09, 0.80), (0.055, 0.805), (0.03, 0.86)], y1=-0.02))], k=0.004)
    return Union([s, pocket, stand, flap], k=0.0)


def body_piece():
    feet = Mirror(foot())
    arms = Mirror(arm())
    return Union([Union([yellow_body(), feet], k=0.022), shirt(), arms], k=0.0)


# ---------------------------------------------------------------------------------------------------- trim: the tie, buttons, pens; the watch

def trim_piece():
    core = shirt_core()
    # the tie: a plate lying on the shirt, drifting off to his left as it rides the belly; the knot tucked under the collar
    blade = prism([(-0.026, 0.86), (0.04, 0.86), (0.142, 0.43), (0.098, 0.335), (0.03, 0.40)])
    tie = Clip(Cut(Inflate(core, 0.026, part=TIE), [Inflate(core, 0.009)], k=0.002), [blade], k=0.004)
    ky = front_y(core, 0.008, 0.865) - 0.018
    knot = Ellipsoid((0.008, ky, 0.866), (0.04, 0.025, 0.036), R=rot(rx=-20), part=TIE)
    parts = [Union([tie, knot], k=0.008, part=TIE)]
    # buttons down the placket (where the tie leaves it showing)
    for z in (0.37, 0.48, 0.59, 0.70):
        y = front_y(core, -0.004, z) - 0.012
        parts.append(CappedCone((-0.004, y + 0.006, z), (-0.004, y - 0.003, z), 0.0115, 0.0105, rr=0.003, part=BUTTON))
    # two pens and a pencil in the pocket
    for x, part, tilt in ((-0.125, PEN, -4), (-0.147, PENCAP, 3), (-0.178, BUTTON, 9)):
        y = front_y(core, x, 0.77) - 0.006
        a = v3((x, y + 0.004, 0.70))
        b = a + v3((np.sin(np.radians(tilt)) * 0.08, -0.012, 0.115))
        parts.append(RoundCone(a, b, 0.0075, 0.0068, part=part))
        parts.append(RoundCone(b - (b - a) * 0.28, b, 0.0083, 0.0075, part=PENCAP if part != PENCAP else PEN))
    return Union(parts, k=0.0)


def watch_piece():
    d = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    at = WRIST - d * 0.035
    M = basis(d, v3((1, 0, 0)))
    band = Torus(at, 0.0445, 0.0095, Rm=M, part=WATCH)
    out = M[:, 1]
    face = Box(at + out * 0.05, (0.009, 0.028, 0.025), rr=0.005, R=np.stack([out, np.cross(d, out), d], 1), part=WATCH)
    screen = Box(at + out * 0.0585, (0.0015, 0.021, 0.018), rr=0.0012, R=np.stack([out, np.cross(d, out), d], 1), part=SCREEN)
    return Union([band, face, screen], k=0.003)


def pieces():
    import os
    out = [("head", head_piece(), 0.0018), ("body", body_piece(), 0.004), ("trim", trim_piece(), 0.002), ("watch", watch_piece(), 0.0018)]
    only = os.environ.get("FOLK_ONLY")          # dev: build a few pieces only, to look at a face quickly
    return [p for p in out if p[0] in only.split(",")] if only else out


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.04) * 0.5 + noise3(P, 0.013) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.broadcast_to(np.float32(amt), (int(m.sum()), 1))], 1)

    # ochre hide: warm yellow, dusky at the bottom and in the folds, blotched with rusty patches and freckled with brown spots
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(214, 166, 80), (n, 3)).copy()
    sk = sk + (srgb(170, 118, 52) - sk) * (smooth(0.35, 0.0, z) * 0.45)[:, None]
    blot = smooth(0.25, 0.55, noise3(P + 3.1, 0.045) * 0.7 + noise3(P, 0.017) * 0.3)
    sk = sk + (srgb(176, 112, 56) - sk) * (blot * 0.7)[:, None]
    sk *= (1.0 + 0.07 * mott)[:, None]
    sole = smooth(0.03, 0.005, z)
    sk = sk + (srgb(150, 104, 56) - sk) * (sole * 0.6)[:, None]
    put(m, sk[m], 0.62, bump=0.5, grain=1.0)
    spk(m, (128, 78, 40), 0.7)
    m = c.mask(NAIL)
    nl = srgb(186, 170, 160) * (1.0 - 0.3 * c.cavity)[:, None] * (1.0 + 0.08 * mott)[:, None]
    nl = nl + (srgb(226, 214, 200) - nl) * (c.wear * 0.5)[:, None]
    nl = nl + (srgb(140, 112, 86) - nl) * (smooth(0.3, 0.7, noise3(P, 0.012)) * 0.45)[:, None]
    put(m, nl[m], 0.4, bump=0.3, grain=1.0)

    # the worm: dusty brick red, lighter on the rings and the snout, deep in the grooves; the lid rims darker
    m = c.mask(WORM)
    wr = np.broadcast_to(srgb(176, 82, 76), (n, 3)).copy()
    wr = wr + (srgb(204, 112, 102) - wr) * (c.wear * 0.6)[:, None]
    wr = wr * (1.0 - 0.45 * c.cavity)[:, None]
    wr *= (1.0 + 0.06 * mott)[:, None]
    de = Q - EYE_C
    r = np.linalg.norm(de, axis=1)
    rim = (r < EYE_R + 0.011) & (r > EYE_R - 0.002)
    wr = np.where(rim[:, None], wr * 0.78, wr)
    put(m, wr[m], 0.48, bump=0.25, grain=1.0)
    spk(m, (130, 52, 48), 0.25)
    # ink: the heavy lids' edges, a crease over them, wrinkles over the snout and round the mouth corners
    pd = (Q - LID_PT) @ LID_N
    c.draw(m & (r < EYE_R + 0.012) & (pd > -0.008) & (pd < 0.004) & (de[:, 1] < 0.02), np.abs(pd + 0.001), 0.0014, 0.8)
    pl = (Q - LOW_PT) @ LOW_N
    c.draw(m & (r < EYE_R + 0.01) & (np.abs(pl) < 0.004) & (de[:, 1] < 0.015), np.abs(pl + 0.0008), 0.001, 0.6)
    c.draw(m & (r > EYE_R + 0.008) & (r < EYE_R + 0.03) & (de[:, 2] > 0.012), np.abs(r - (EYE_R + 0.017)), 0.0009, 0.45)
    snout_d = np.abs(np.hypot(Q[:, 0] - 0.0, (z - 1.33)) - 0.06)
    c.draw(m & (y < -0.3) & (z > 1.27) & (Q[:, 0] < 0.04), snout_d, 0.0008, 0.35)
    # smile creases: a short arc up and back from each mouth corner into the cheek
    corner = np.linalg.norm((Q - v3((0.058, -0.262, 1.236))) * v3((1.0, 0.7, 1.0)), axis=1)
    c.draw(m & (corner < 0.03) & (z > 1.248) & (Q[:, 0] > 0.06) & (y > -0.3), np.abs(corner - 0.02), 0.0008, 0.45)

    # eyes: pale jaundiced yellow, small dark pupils under the lids, looking off to his left, a wet glint
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    look = v3((0.36, -0.9, -0.12)) / np.linalg.norm((0.36, -0.9, -0.12))      # both eyes look the same way (off to his left), as drawn
    dl = P - np.where((x > 0)[:, None], EYE_C, EYE_C * v3((-1, 1, 1)))
    dl /= np.maximum(np.linalg.norm(dl, axis=1), 1e-6)[:, None]
    ang = np.arccos(np.clip(dl @ look, -1, 1))
    sc = srgb(232, 220, 158) * (1.0 - 0.25 * smooth(0.6, 1.6, ang))[:, None]
    sc = sc + (srgb(214, 150, 120) - sc) * (smooth(0.9, 1.5, ang) * 0.35)[:, None]
    sc = sc + (srgb(96, 62, 30) - sc) * smooth(0.34, 0.26, ang)[:, None]           # a thin brown iris round the pupil
    c.draw(m, (ang - 0.25) * EYE_R, 0.0)
    put(m, sc[m], 0.08)
    gl = smooth(0.2, 0.08, np.linalg.norm(dl - v3((-0.35, -0.75, 0.55)) / np.linalg.norm((-0.35, -0.75, 0.55)), axis=1))
    c.col[m] = (c.col + (srgb(255, 252, 240) - c.col) * gl[:, None])[m]

    # teeth: old ivory, yellowing at the gum, a dark parting
    m = c.mask(TOOTH)
    tt = srgb(236, 222, 182) + (srgb(206, 174, 112) - srgb(236, 222, 182)) * (smooth(1.225, 1.25, z) * 0.7)[:, None]
    tt *= (1.0 - 0.35 * c.cavity)[:, None]
    put(m, tt[m], 0.3, bump=0.1)
    c.draw(m & (np.abs(x) < 0.004) & (z < 1.235), np.abs(x), 0.0009, 0.7)
    put(c.mask(MOUTH), srgb(66, 18, 22), 0.5)

    # the shirt: faded blue, a scatter of pale four-petal flowers, brown stains and grime
    m = c.mask(SHIRT, BUTTON)
    ms = c.mask(SHIRT)
    ang_b = np.arctan2(x, -(y - 0.02))
    u = ang_b * 0.3
    cell = 0.085
    vv = z / cell
    row = np.floor(vv)
    uu = u / cell + 0.5 * (row % 2)
    col_i = np.floor(uu)
    h = np.sin(col_i * 12.9898 + row * 78.233) * 43758.5453
    h = h - np.floor(h)
    fu, fv = uu - col_i - 0.5, vv - row - 0.5
    fu += (h - 0.5) * 0.25
    rr_ = np.hypot(fu, fv)
    th = np.arctan2(fv, fu) + h * 3.0
    petal = 0.17 + 0.17 * np.abs(np.cos(2.0 * th)) ** 0.8
    sz = 0.8 + 0.4 * h
    flower = smooth(0.02, -0.02, rr_ - petal * sz)
    centre = smooth(0.012, -0.012, rr_ - 0.06 * sz)
    sh = np.broadcast_to(srgb(98, 130, 176), (n, 3)).copy()
    sh = sh + (srgb(124, 150, 186) - sh) * (smooth(-0.2, 0.6, noise3(P + 5.0, 0.07)) * 0.5)[:, None]      # sun-faded patches
    sh *= (1.0 + 0.06 * mott)[:, None]
    fl_keep = smooth(0.05, 0.25, noise3(np.stack([col_i, row, np.zeros_like(row)], 1).astype(np.float32) * 0.37, 0.5) + 0.45)
    sh = sh + (srgb(146, 176, 214) - sh) * (flower * 0.7 * fl_keep)[:, None]
    sh = sh + (srgb(82, 110, 158) - sh) * (centre * flower * fl_keep * 0.8)[:, None]
    stain = smooth(0.25, 0.55, noise3(P + 7.3, 0.06) * 0.6 + noise3(P, 0.02) * 0.4)
    stain = np.maximum(stain, smooth(0.5, 0.28, z) * smooth(0.1, 0.5, noise3(P + 1.7, 0.035)) * 0.9)
    sh = sh + (srgb(146, 108, 66) - sh) * (stain * 0.6)[:, None]
    sh *= (1.0 - 0.35 * c.cavity)[:, None]
    put(ms, sh[ms], 0.86, bump=1.0, grain=0.0)
    spk(ms, (128, 92, 58), 0.22)
    # seams: the placket's two lines, the pocket's edge stitching, the hem
    c.draw(ms & (z > 0.3) & (z < 0.9) & (y < -0.1), np.abs(np.abs(x + 0.004) - 0.021), 0.0008, 0.5)
    m = c.mask(BUTTON)
    put(m, (srgb(226, 214, 186) * (1.0 - 0.3 * c.cavity)[:, None])[m], 0.35, bump=0.1)

    # the tie: red and cream diagonal stripes, grubby
    m = c.mask(TIE)
    s = (x * 0.62 + z * 0.78) / 0.064
    band = smooth(0.06, -0.06, np.abs((s - np.floor(s)) - 0.5) - 0.21)
    te = srgb(168, 54, 52) + (srgb(230, 208, 178) - srgb(168, 54, 52)) * band[:, None]
    te = te + (srgb(150, 110, 70) - te) * (stain * 0.4)[:, None]
    te *= (1.0 - 0.3 * c.cavity)[:, None]
    put(m, te[m], 0.75, bump=0.8)
    put(c.mask(PEN), srgb(172, 26, 24), 0.25)
    put(c.mask(PENCAP), srgb(24, 24, 26), 0.25)
    m = c.mask(WATCH)
    put(m, (srgb(206, 160, 54) * (1.0 + 0.4 * c.wear)[:, None])[m], 0.35, bump=0.1)
    m = c.mask(SCREEN)
    put(m, srgb(78, 88, 70), 0.1)

    # light the room does not give: occlusion into the creases
    c.col *= (0.3 + 0.7 * c.ao)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2600, "body": 5000, "trim": 900, "watch": 250},
    "density": {"head": 1.8, "trim": 1.2, "watch": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.62, "run": 1.0},
    "speed": 0.55,
    "look": ["head"], "neck": "neck3",
    "look_pivot": (0.0, -0.17, 1.2),
    "radius": 0.6,
}
KNOT = v3((0.008, -0.19, 0.866))
TIP = v3((0.075, -0.33, 0.37))


def rig_bones():
    from kit.rig import Bone, mirror
    toe = fp(0.36, 0.0, 0.05)
    hand_end = WRIST - HAND[:, 2] * 0.16
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.03, 0.42), (0, 0.03, 0.64), "root", 0.28),
        Bone("spine", (0, 0.03, 0.64), (0, 0.0, 0.84), "hips", 0.24),
        Bone("hump", (0, 0.10, 0.84), (0, 0.17, 1.12), "spine", 0.17),
        Bone("neck1", NECK[0][0], NECK[1][0], "spine", 0.1),
        Bone("neck2", NECK[1][0], NECK[2][0], "neck1", 0.093),
        Bone("neck3", NECK[2][0], NECK[3][0], "neck2", 0.087),
        Bone("head", NECK[3][0], (0, -0.28, 1.33), "neck3", 0.08),
        Bone("tie", KNOT, TIP, "spine", 0.02),
        Bone("shoulder.L", (0.12, -0.01, 0.82), SHOULDER, "spine", 0.06),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.05),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.042),
        Bone("hand.L", WRIST, hand_end, "forearm.L", 0.035),
        Bone("thigh.L", HIP, KNEE, "hips", 0.14),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.14),
        Bone("foot.L", ANKLE, toe, "shin.L", 0.1),
    ])


def _seg(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / float(ab @ ab), 0.0, 1.0)
    return np.linalg.norm(P - a - np.outer(t, ab), axis=1)


def skin_rules(P, part, piece, names):
    """piece: 0 head and neck, 1 body (hide, feet, arms, shirt), 2 trim (tie, buttons, pens), 3 watch"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    # head and neck: the face is rigid, the neck bends along its rings, its root sits in the collar
    hp = piece == 0
    allow(hp & (z < 0.98), "spine", "neck1")
    allow(hp & (z > 0.88) & (z < 1.12), "neck1", "neck2")
    allow(hp & (z > 1.0) & (z < 1.22), "neck2", "neck3")
    allow(hp & (z > 1.1), "neck3", "head")
    rig[hp & ((z > 1.235) | ((y < -0.235) & (z > 1.13)))] = ix["head"]
    # the body
    bp = piece == 1
    al = (Q - FOOT_O) @ FWD
    arm_d = np.minimum(_seg(Q, SHOULDER, ELBOW), _seg(Q, ELBOW, WRIST))
    along = (Q - WRIST) @ -HAND[:, 2]
    hand_d = _seg(Q, WRIST, WRIST - HAND[:, 2] * 0.2)
    in_hand = (along > -0.02) & (along < 0.24) & (hand_d < 0.1)        # the whole hand, the thumb's tip included
    arms = bp & (part == SKIN) & ((arm_d < 0.075) | in_hand) & (np.abs(x) > 0.3) & (z > 0.26)
    for s, sd in ((1, "L"), (-1, "R")):
        m = arms & (x * s > 0)
        allow(m, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        rig[m & (_seg(Q, WRIST, WRIST - HAND[:, 2] * 0.2) < 0.065) & (((Q - WRIST) @ -HAND[:, 2]) > 0.03)] = ix["hand." + sd]
    feet = bp & ~arms & (z < 0.27) & (np.abs(x) > 0.07)
    for s, sd in ((1, "L"), (-1, "R")):
        side = feet & (x * s > 0)
        allow(side, "shin." + sd, "foot." + sd)
        rig[side & (al > 0.1) & (z < 0.2)] = ix["foot." + sd]
    rest = bp & ~feet & ~arms
    legs = rest & (z < 0.5)
    allow(legs, "hips")
    allow(legs & (x > -0.05), "thigh.L", "shin.L")
    allow(legs & (x < 0.05), "thigh.R", "shin.R")
    allow(rest & (z > 0.4), "hips", "spine")
    allow(rest & (y > 0.05) & (z > 0.78), "hump")
    sleeve = rest & (part == SHIRT) & (_seg(Q, v3((0.2, 0.0, 0.84)), SHOULDER + (ELBOW - SHOULDER) * 0.75) < 0.13) & (np.abs(x) > 0.19)
    for s, sd in ((1, "L"), (-1, "R")):
        m = sleeve & (x * s > 0)
        allow(m, "shoulder." + sd, "upper_arm." + sd)
    # trim: the tie swings on its own bone from the knot; buttons and pens ride the shirt
    tp = piece == 2
    tie = tp & (part == TIE)
    allow(tie, "spine", "tie")
    rig[tie & (z < 0.8)] = ix["tie"]
    rig[tp & ~tie & (z > 0.62)] = ix["spine"]
    rig[tp & ~tie & (z <= 0.62)] = ix["hips"]
    allow(tp, "spine")
    # the watch on his left wrist
    wp = piece == 3
    rig[wp] = ix["forearm.L"]
    allow(wp, "forearm.L")
    return A, rig


WALK = dict(stride=0.62, stance=0.6, lift=0.095, sway=0.05, roll=5.0, yaw=6.0, bob=0.014, drop=0.03, stomp=0.022, lean=5.0,
            arm=9.0, peel=18.0, toes_up=14.0)
RUN = dict(stride=1.0, stance=0.42, lift=0.15, sway=0.035, roll=4.0, yaw=9.0, bob=-0.03, drop=0.05, stomp=0.03, lean=13.0,
           arm=22.0, peel=26.0, toes_up=18.0)


def motions(rig):
    """his clips: walk (a heavy stomp: each huge foot lifts, swings and slams down flat, the lump rolls over it, the hump and tie jolt,
    the neck sways behind and the droopy head nods on each stomp), run (a lumbering jog), idle (breathing, he nods off and jerks awake, looks about)"""
    import math
    from mathutils import Vector, Matrix
    from kit.gait import Pose, R, TAU, ease
    f = np.array([-1, 1, 1], np.float32)
    ball = {"L": Vector(BALL.tolist()), "R": Vector((BALL * f).tolist())}
    ankle = {"L": Vector(ANKLE.tolist()), "R": Vector((ANKLE * f).tolist())}
    axis = {"L": Vector(SIDE.tolist()), "R": Vector((SIDE * v3((1, -1, 1))).tolist())}     # each foot's pitch axis, pointing to +X

    def imp(u, at, w=0.045):
        """a jolt just after a foot lands (periodic over the cycle)"""
        d = ((u - at + 0.5) % 1.0) - 0.5
        return math.exp(-(d / w) ** 2)

    def place_foot(p, sd, fy, lift, pitch):
        s = 1.0 if sd == "L" else -1.0
        wf = Matrix.Rotation(math.radians(pitch), 3, axis[sd])
        b = Vector((ball[sd].x, ball[sd].y + fy, lift))
        a = b + wf @ (ankle[sd] - ball[sd])
        p.ik["thigh." + sd] = (a, Vector((s * 0.1, -1.0, 0.0)), "foot." + sd, wf)

    def gait(u, g, run):
        p = Pose()
        S, beta = g["stride"], g["stance"]
        up = {}
        for sd in ("L", "R"):
            uu = (u + (0.0 if sd == "L" else 0.5)) % 1.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                lift = 0.0
                pitch = g["peel"] * ease((uu - (beta - 0.16)) / 0.16)
            else:
                t = (uu - beta) / (1.0 - beta)
                fy = S * beta / 2 - S * beta * ease(min(1.0, t / 0.75))
                lift = g["lift"] * math.sin(math.pi * t ** 1.16)
                pitch = g["peel"] * (1.0 - ease(t * 2.5)) - g["toes_up"] * math.sin(math.pi * min(1.0, t / 0.85))
            place_foot(p, sd, fy, lift, pitch)
            up[sd] = lift / g["lift"]
        jolt = imp(u, 0.035) + imp(u, 0.535)
        bob = g["bob"] * math.cos(2 * TAU * (u - beta * 0.5))
        p.offset = Vector((g["sway"] * math.sin(TAU * (u - 0.04)), 0.0, -g["drop"] + bob - g["stomp"] * jolt))
        roll = g["roll"] * math.sin(TAU * (u - 0.04))
        yaw = -g["yaw"] * math.cos(TAU * u)
        p.rot("hips", g["lean"] + 2.0 * jolt, roll, yaw)
        p.rot("spine", 1.5 * jolt, -roll * 0.35, -yaw * 0.6)
        lag = math.sin(TAU * (u - 0.14))
        p.rot("hump", 3.0 * imp(u, 0.09, 0.06) + 3.0 * imp(u, 0.59, 0.06) - 1.0, -g["roll"] * 0.9 * lag, 0)
        # the neck sways behind the body, the head nods after each stomp and stays near level
        p.rot("neck1", -2.0 - 2.0 * jolt, -roll * 0.7, 0)
        p.rot("neck2", (3.0 if run else 0.0) + 2.5 * (imp(u, 0.08, 0.06) + imp(u, 0.58, 0.06)), -g["roll"] * 0.6 * lag, yaw * 0.3)
        p.rot("neck3", (6.0 if run else 1.0), -g["roll"] * 0.4 * math.sin(TAU * (u - 0.2)), 0)
        nod = imp(u, 0.1, 0.07) + imp(u, 0.6, 0.07)
        p.world["head"] = R((6.0 if run else 2.0) + 5.0 * nod, -1.5 * math.sin(TAU * (u - 0.25)), yaw * 0.2)
        # the long arms dangle and swing behind the step
        for sd, s in (("L", 1.0), ("R", -1.0)):
            c = math.cos(TAU * (u - 0.07) + (0.0 if sd == "L" else math.pi))
            p.rot("upper_arm." + sd, g["arm"] * c, s * 3.0 * math.sin(TAU * (u - 0.12)), 0)
            # the forearm lifts the hand clear as the foot under it comes up
            p.rot("forearm." + sd, -(12.0 if run else 4.0) - g["arm"] * 0.7 * max(0.0, -math.cos(TAU * (u - 0.13) + (0.0 if sd == "L" else math.pi)))
                  - 22.0 * up[sd], 0, 0)
            p.rot("hand." + sd, 4.0 * math.cos(TAU * (u - 0.2) + (0.0 if sd == "L" else math.pi)), 0, 0)
        p.rot("tie", -3.0 * jolt + (14.0 if run else 2.0) * math.sin(2 * TAU * (u - 0.1)) * (1.0 if run else 0.6), -roll * 1.2 * lag, 0)
        return p

    walk = [gait(i / 32.0, WALK, False) for i in range(33)]
    run = [gait(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        br = math.sin(TAU * t / 3.0)
        sw = math.sin(TAU * t / 6.0)
        for sd in ("L", "R"):
            p.ik["thigh." + sd] = (ankle[sd], Vector(((1.0 if sd == "L" else -1.0) * 0.1, -1.0, 0.0)), "foot." + sd, Matrix.Identity(3))
        p.offset = Vector((0.014 * sw, 0.0, -0.01 + 0.004 * br))
        p.rot("hips", 1.0, 2.0 * sw, 0)
        p.rot("spine", -1.2 * br, -0.8 * sw, 0)
        p.rot("hump", 1.5 * br, -1.0 * sw, 0)
        # he nods off: the neck sags, the head droops... then he jerks awake, overshoots, and looks about
        doze = ease((t - 1.2) / 1.6) * (1.0 - ease((t - 3.7) / 0.22))
        jerk = math.exp(-((t - 3.95) / 0.16) ** 2)
        look = math.sin(math.pi * min(1.0, max(0.0, (t - 4.3) / 1.6))) * math.sin(TAU * (t - 4.3) / 1.6)
        p.rot("neck1", 3.0 * doze - 2.0 * jerk, -1.5 * sw, 0)
        p.rot("neck2", 7.0 * doze - 3.0 * jerk, 0, 6.0 * look)
        p.rot("neck3", 6.0 * doze - 3.0 * jerk + 1.0, 0, 8.0 * look)
        p.world["head"] = R(3.0 + 24.0 * doze - 10.0 * jerk + 0.8 * br, 0, 22.0 * look)
        for sd, s in (("L", 1.0), ("R", -1.0)):
            p.rot("upper_arm." + sd, 1.5 * math.sin(TAU * t / 3.0 + s), -s * 1.5 * doze, 0)
            p.rot("forearm." + sd, -3.0 - 4.0 * jerk, 0, 0)
        p.rot("tie", 1.0 * br - 4.0 * jerk, 1.0 * sw, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
