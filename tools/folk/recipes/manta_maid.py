## FOINT CITY townsfolk: the manta maid (working name; the user names her). A stout red woman under a wide flat diamond of a head with four lidded eyes and a sour little frown, in a blue maid's dress and a stained apron.
# Concept: the user's sheet, image 6 top right (F:/prog-godot-cache/folk/refs/6.webp). Measured off a 3x crop (603 px a metre): 1.75 m to the head's apex;
# the head a diamond 0.88 wide and 0.53 tall (its side points at 1.52), its lower corners rolled back into two fleshy flaps that drape the shoulders;
# four eyes (the concept has four, in two rows, though the brief said three) 0.10 wide; the mouth at 1.42; the collar at 1.22, the waist at 0.95,
# the A-line skirt's hem at 0.41, block heels. Rest pose = her stance: right fist planted on her hip, the left arm hanging (the dry cleaning is dropped).
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.75
REF = ("6.webp", (419, 0, 796, 360))

SKIN, FLAP, EYE, LIP, DRESS, WHITE, APRON, BUTTON, BADGE, SHOE, GOLD, TOWEL, PEG, NAIL = range(1, 15)
COLOURS = {
    SKIN: ((0.52, 0.16, 0.13), 0.55, 0.0),
    FLAP: ((0.45, 0.11, 0.10), 0.55, 0.0),
    EYE: ((0.86, 0.80, 0.62), 0.15, 0.0),
    LIP: ((0.42, 0.10, 0.10), 0.45, 0.0),
    DRESS: ((0.30, 0.45, 0.58), 0.8, 0.0),
    WHITE: ((0.82, 0.78, 0.68), 0.75, 0.0),
    APRON: ((0.80, 0.74, 0.62), 0.8, 0.0),
    BUTTON: ((0.80, 0.76, 0.66), 0.4, 0.0),
    BADGE: ((0.82, 0.62, 0.18), 0.35, 0.6),
    SHOE: ((0.30, 0.05, 0.08), 0.3, 0.0),
    GOLD: ((0.85, 0.62, 0.22), 0.3, 1.0),
    TOWEL: ((0.86, 0.82, 0.78), 0.85, 0.0),
    PEG: ((0.62, 0.44, 0.24), 0.6, 0.0),
    NAIL: ((0.40, 0.12, 0.12), 0.3, 0.0),
}
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


# ---------------------------------------------------------------------------------------------------- helpers (kit gaps worked round in this recipe)

def prism(poly_xz, y0=-0.7, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from y0 to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def front_y(shape, x, z, y0=-0.8, y1=0.4):
    """where a ray from the front at (x, z) first meets the shape"""
    ys = np.arange(y0, y1, 0.0005, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


def squash(child, sx=1.0, sy=1.0, sz=1.0, at=(0, 0, 0)):
    """the child shrunk by (sx, sy, sz) <= 1 about `at` (gentle squashes: the distance stays near true, the bound stays safe)"""
    return Move(child, R=np.diag([1.0 / sx, 1.0 / sy, 1.0 / sz]).astype(np.float32), pivot=at)


class Pillow(Shape):
    """a plate cut to a front-view outline (x, z) and puffed: hf thick in front of y = yc and hb behind, thinning to nothing at the outline
    over the last w metres with a rounded edge, and a soft ridge down its middle (ridge = extra front thickness at x = 0)"""
    def __init__(self, poly_xz, yc, hf, hb, w, ridge=0.0, part=0):
        self.slab = prism(poly_xz, y0=-5.0, y1=5.0)
        self.yc, self.hf, self.hb, self.w, self.ridge = np.float32(yc), np.float32(hf), np.float32(hb), np.float32(w), np.float32(ridge)
        p = np.asarray(poly_xz, np.float32)
        m = max(hf + ridge, hb) + 0.01
        self.lo = np.array([p[:, 0].min() - 0.01, yc - m, p[:, 1].min() - 0.01], np.float32)
        self.hi = np.array([p[:, 0].max() + 0.01, yc + m, p[:, 1].max() + 0.01], np.float32)
        self.part = part

    def dist(self, P):
        Q = P.copy()
        Q[:, 1] = 0.0
        d2 = self.slab.eval(Q)[0]
        t = np.clip(-d2 / self.w, 0.0, 1.0)
        f = np.sqrt(t * (2.0 - t))
        dy = P[:, 1] - self.yc
        h = np.where(dy < 0, self.hf + self.ridge * np.exp(-(P[:, 0] / 0.07) ** 2), self.hb) * f
        return np.maximum(d2, np.abs(dy) - h) * 0.9


class SweepBack(Shape):
    """the child bent so its sides sweep back: a point x out from the middle moves back (+Y) by k x^2 (a manta's wings)"""
    def __init__(self, child, k, pad=0.1):
        self.child, self.k = child, np.float32(k)
        lo, hi = child.bound()
        w = max(abs(lo[0]), abs(hi[0]))
        self.lo, self.hi = lo - pad, hi + np.array([pad, pad + k * w * w, pad], np.float32)
        self.part = child.part

    def eval(self, P):
        Q = P.copy()
        Q[:, 1] -= self.k * Q[:, 0] ** 2
        return self.child.eval(Q)

    def dist(self, P):
        return self.eval(P)[0]


# ---------------------------------------------------------------------------------------------------- framing (a kit gap, worked round here)
# kit/look.render_views aims its face views at 0.9 of the figure's height; her face sits lower (her eyes and mouth at 0.81-0.92 of it) under
# the broad diamond, which also overflows the standard frame. The same renderer, with a wider frame and the face views aimed at her face.
VIEW_ASPECT = 0.8
FACE_AT = v3((0.0, -0.05, 1.47))
FACE_DIST = 2.5


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
                cams[v] = ((f[0] + FACE_DIST * math.sin(a), f[1] - FACE_DIST * math.cos(a), f[2] + 0.05), (f[0], f[1], f[2] - 0.01), None)
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


# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; she faces -Y)
HEAD_C = v3((0.0, 0.0, 1.52))                   # the diamond's middle: its side points are level with this
HEAD_EXT = (0.44, 0.44, 0.10, 0.13, 0.30, 0.23)
SWEEP = 0.26                                     # how far the diamond's sides sweep back (k x^2)
EYES = [(0.074, 1.617), (0.074, 1.523)]          # (x, z) of the left column; the right is its mirror
EYE_RAD = (0.049, 0.026, 0.028)
MOUTH_Z = 1.415

HIP = v3((0.10, 0.03, 0.85))
KNEE = v3((0.175, -0.01, 0.47))
ANKLE = v3((0.205, 0.04, 0.095))
FOOT_YAW = np.radians(26.0)
FFWD = v3((np.sin(FOOT_YAW), -np.cos(FOOT_YAW), 0.0))
BALL = ANKLE + FFWD * 0.12 + v3((0, 0, -0.095))

SH_L = v3((0.30, 0.04, 1.20))
EL_L = v3((0.39, 0.07, 0.915))
WR_L = v3((0.42, 0.032, 0.67))
SH_R = v3((-0.30, 0.04, 1.20))
EL_R = v3((-0.556, 0.085, 1.05))
WR_R = v3((-0.373, 0.052, 0.883))
HAND_L = basis(-(WR_L - EL_L), v3((0, 1, 0)))                      # hanging: fingers down the forearm's line, back of the hand out, thumb forward
HAND_R = basis(-v3((0.55, -0.1, -0.83)), v3((0.0, 1.0, 0.25)))      # the fist on the hip: knuckles down and in, the back of the hand facing out


# ---------------------------------------------------------------------------------------------------- the head

def diamond():
    # a smooth domed plate cut to the diamond's outline (its edges a little hollow, its points sharp): thick in the middle, thin at the tips
    outline = [(0.0, 1.755), (0.21, 1.627), (0.447, 1.515), (0.25, 1.37), (0.0, 1.2), (-0.25, 1.37), (-0.447, 1.515), (-0.21, 1.627)]
    plate = Pillow(outline, 0.0, 0.085, 0.1, 0.16, ridge=0.012, part=SKIN)
    return SweepBack(plate, SWEEP)


def flaps():
    """the diamond's lower edges rolled back into a great fleshy stand-up collar: a barrel of a frill round the neck, resting on the shoulders,
    widest below the head's points, open at the front so its hollow shows either side of the face"""
    c = v3((0.0, 0.07, 1.40))
    outer = Ellipsoid(c, (0.57, 0.17, 0.2), part=FLAP)
    inner = Ellipsoid(c + v3((0.0, -0.006, 0.01)), (0.542, 0.146, 0.186))
    shell = Cut(outer, [inner], k=0.01)
    shell = Clip(shell, [Half((0, 0, 1.262), (0, 0, -1)), Half((0, 0, 1.53), (0, 0, 1))], k=0.012)
    front = prism([(-0.24, 1.2), (0.24, 1.2), (0.4, 1.42), (0.4, 1.6), (-0.4, 1.6), (-0.4, 1.42)], y0=-0.6, y1=0.0)
    return Cut(shell, [front], k=0.03)


def head():
    face = diamond()
    neck = RoundCone((0, 0.04, 1.40), (0, 0.035, 1.17), 0.105, 0.115, part=SKIN)
    mass = Union([face, neck, flaps()], k=0.04)
    # four lidded eyes: a fleshy rim round each pale oval eyeball
    eyes, balls = [], []
    for x, z in EYES:
        fy = front_y(face, x, z)
        c = v3((x, fy + 0.003, z))
        rim = Ellipsoid(c + v3((0, 0.004, 0)), (EYE_RAD[0] + 0.011, EYE_RAD[1] + 0.008, EYE_RAD[2] + 0.011), part=SKIN)
        slot = Ellipsoid(c + v3((0, -0.032, 0)), (EYE_RAD[0] - 0.003, 0.034, EYE_RAD[2] - 0.004))
        eyes.append(Cut(rim, [slot], k=0.004))
        balls.append(Ellipsoid(c, EYE_RAD, part=EYE))
    mass = Union([mass] + [Mirror(e) for e in eyes], k=0.012)
    # the frown: an arched crease over a full lower lip that follows it down at the corners
    my = front_y(face, 0.0, MOUTH_Z)
    arch = Move(squash(Torus((0, 0, 0), 0.084, 0.0055, Rm=rot(rx=90)), sz=0.42), t=(0, my + 0.002, MOUTH_Z - 0.02))
    arch = Clip(arch, [Half((0, 0, MOUTH_Z - 0.018), (0, 0, -1))])
    mass = Cut(mass, [arch], k=0.003)
    lip = Move(squash(Torus((0, 0, 0), 0.072, 0.018, Rm=rot(rx=90)), sz=0.42), t=(0, my + 0.012, MOUTH_Z - 0.026))
    lip = Clip(lip, [Half((0, 0, MOUTH_Z - 0.022), (0, 0, -1))], k=0.01)
    lip = Union([lip], k=0.0, part=LIP)
    mass = Union([mass, lip], k=0.012)
    return Union([mass] + [Mirror(b) for b in balls], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body: dress, apron, legs, shoes

def bodice_core():
    return Union([
        Ellipsoid((0, 0.03, 1.13), (0.25, 0.16, 0.16)),
        Ellipsoid((0, 0.045, 1.225), (0.285, 0.13, 0.065)),
        Mirror(Ellipsoid((0.105, -0.06, 1.085), (0.105, 0.09, 0.09))),
        Ellipsoid((0, 0.03, 0.96), (0.22, 0.15, 0.1)),
        Ellipsoid((0, -0.005, 0.985), (0.2, 0.15, 0.1)),
    ], k=0.07)


def skirt_core():
    hips = Ellipsoid((0, 0.03, 0.85), (0.29, 0.2, 0.16))
    flare = Move(squash(CappedCone((0, 0, 0.93), (0, 0, 0.40), 0.25, 0.44, rr=0.03), sy=0.72), t=(0, 0.03, 0))
    return Union([hips, flare], k=0.08)


def dress():
    core = Union([bodice_core(), skirt_core()], k=0.06)
    shell = Inflate(core, 0.008, part=DRESS)
    shell = Clip(shell, [Half((0, 0, 0.41), (0, 0, -1))], k=0.004)
    hollow = Clip(Inflate(skirt_core(), -0.006), [Half((0, 0, 0.5), (0, 0, 1))], k=0.02)
    shell = Cut(shell, [hollow], k=0.004)
    # the neckline: a V opened down the front, the neck coming up out of it
    v = prism([(-0.12, 1.36), (0.12, 1.36), (0.045, 1.15), (-0.045, 1.15)], y1=0.02)
    shell = Cut(shell, [v], k=0.006)
    sleeves = []
    for sh, el, s in ((SH_L, EL_L, 1), (SH_R, EL_R, -1)):
        d = (el - sh) / np.linalg.norm(el - sh)
        end = sh + d * 0.15
        root = v3((s * 0.2, 0.04, 1.22))
        sl = loft([(root, 0.092), (sh, 0.092), (end, 0.083)], part=DRESS, k=0.02)
        sl = Clip(sl, [Half(end, d)], k=0.004)
        sl = Cut(sl, [RoundCone(end - d * 0.06, end + d * 0.03, 0.066)], k=0.004)
        cuff = Torus(end - d * 0.01, 0.079, 0.012, Rm=basis(d, v3((0, 0, 1))), part=WHITE)
        sleeves.append(Union([sl, cuff], k=0.004))
    shell = Union([shell] + sleeves, k=0.02, part=DRESS)
    # the white collar: two pointed flaps lying either side of the V
    collar = Clip(Cut(Inflate(bodice_core(), 0.02, part=WHITE), [Inflate(bodice_core(), 0.008)], k=0.002),
                  [Mirror(prism([(0.04, 1.155), (0.12, 1.31), (0.185, 1.29), (0.16, 1.2), (0.105, 1.13)], y1=0.05))], k=0.004)
    return Union([shell, collar], k=0.0), core


def apron(core):
    sk = skirt_core()
    outline = prism([(-0.25, 0.96), (0.25, 0.96), (0.27, 0.53), (0.24, 0.49), (-0.24, 0.49), (-0.27, 0.53)], y1=-0.02)
    a = Clip(Cut(Inflate(sk, 0.02, part=APRON), [Inflate(sk, 0.004)], k=0.002), [outline], k=0.005)
    band = Clip(Inflate(Ellipsoid((0, 0.03, 0.955), (0.225, 0.155, 0.1)), 0.02, part=APRON),
                [Half((0, 0, 0.978), (0, 0, 1)), Half((0, 0, 0.932), (0, 0, -1))], k=0.003)
    bow = Union([Ellipsoid((s * 0.045, 0.19, 0.955), (0.045, 0.014, 0.026), R=rot(ry=s * 20), part=APRON) for s in (-1, 1)]
                + [Ellipsoid((0, 0.188, 0.955), (0.016, 0.014, 0.018), part=APRON)]
                + [Box((s * 0.03, 0.188, 0.88), (0.017, 0.005, 0.06), rr=0.004, R=rot(ry=s * 10), part=APRON) for s in (-1, 1)], k=0.006)
    pocket = Clip(Inflate(sk, 0.028, part=APRON), [prism([(-0.215, 0.6), (-0.05, 0.6), (-0.055, 0.79), (-0.22, 0.79)], y1=-0.05)], k=0.004)
    return Union([a, band, bow, pocket], k=0.0)


def legs():
    calf = KNEE + (ANKLE - KNEE) * 0.3 + v3((0, 0.016, 0))
    leg = loft([(HIP, 0.075), (KNEE + v3((0, 0, 0.12)), 0.058), (KNEE, 0.047), (calf, 0.053), (ANKLE + v3((0, 0, 0.05)), 0.033), (ANKLE, 0.031)],
               part=SKIN, k=0.02)
    # the pump: a pointed toe box, the heel counter, a block heel and a gold buckle on the vamp
    heel_pt = ANKLE + v3((0, 0.03, -0.055)) - FFWD * 0.0
    foot = loft([(heel_pt, 0.032), (ANKLE + FFWD * 0.06 + v3((0, 0, -0.05)), 0.036), (ANKLE + FFWD * 0.14 + v3((0, 0, -0.074)), 0.03),
                 (ANKLE + FFWD * 0.245 + v3((0, 0, -0.086)), 0.008)], part=SKIN, k=0.015)
    shell = Inflate(foot, 0.004, part=SHOE)
    topline = Half(ANKLE + FFWD * 0.06 + v3((0, 0, -0.035)), FFWD * 0.55 + v3((0, 0, 1.0)))
    shoe = Clip(shell, [topline], k=0.004)
    hb = heel_pt + v3((0, 0.012, 0))
    heel = CappedCone(hb + v3((0, 0, -0.005)), v3((hb[0], hb[1] + 0.006, 0.0)), 0.026, 0.02, rr=0.004, part=SHOE)
    bc = ANKLE + FFWD * 0.105 + v3((0, 0, -0.037))
    M = basis(FFWD * 0.6 + v3((0, 0, 1.0)), FFWD)
    buckle = Cut(Box(bc, (0.022, 0.017, 0.006), rr=0.003, R=M, part=GOLD), [Box(bc, (0.013, 0.009, 0.02), R=M)])
    strap = Box(bc, (0.03, 0.012, 0.004), rr=0.002, R=M, part=SHOE)
    sole_cut = Half((0, 0, 0.0), (0, 0, -1))
    shoe = Clip(Union([shoe, heel, strap], k=0.006, part=SHOE), [sole_cut])
    return Mirror(Union([leg, foot, shoe, buckle], k=0.0))


def body_piece():
    d, core = dress()
    return Union([d, apron(core), legs()], k=0.0)


# ---------------------------------------------------------------------------------------------------- arms

def hand_open(s=1.0):
    """relaxed hanging hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): long fingers, softly curled"""
    parts = [Ellipsoid((0.0, 0.0, -0.046), (0.017, 0.039, 0.048), part=SKIN), RoundCone((0, 0, 0.03), (0, 0, -0.015), 0.032, 0.029, part=SKIN)]
    for f, L in ((-0.026, 0.84), (-0.009, 1.0), (0.009, 0.96), (0.026, 0.8)):
        pts = [((0.0, f, -0.082), 0.0098), ((-0.006, f, -0.082 - 0.036 * L), 0.009), ((-0.02, f, -0.115 - 0.03 * L), 0.0082), ((-0.034, f, -0.125 - 0.022 * L), 0.0075)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((-0.003, 0, 0.004)), (0.006, 0.0068, 0.005), part=NAIL))
    parts.append(loft([(v3((-0.01, -0.03, -0.025)), 0.012), (v3((-0.024, -0.047, -0.058)), 0.0105), (v3((-0.036, -0.046, -0.085)), 0.0092)], part=SKIN, k=0.004))
    return Union(parts, k=0.008)


def hand_fist():
    """a fist in hand space: fingers rolled into the palm, knuckles along -Z, the thumb folded over the front"""
    parts = [Ellipsoid((0.0, 0.0, -0.045), (0.022, 0.04, 0.046), part=SKIN), RoundCone((0, 0, 0.03), (0, 0, -0.015), 0.032, 0.029, part=SKIN)]
    for f in (-0.027, -0.009, 0.009, 0.027):
        pts = [((0.0, f, -0.08), 0.0115), ((-0.012, f, -0.1), 0.011), ((-0.032, f, -0.096), 0.0105), ((-0.036, f, -0.074), 0.01)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.005))
    parts.append(loft([(v3((-0.012, -0.034, -0.03)), 0.0125), (v3((-0.03, -0.048, -0.058)), 0.011), (v3((-0.044, -0.03, -0.074)), 0.0095)], part=SKIN, k=0.005))
    return Union(parts, k=0.009)


def arm(sh, el, wr, hand, H):
    fa = el + (wr - el) * 0.38
    limb = loft([(sh, 0.058), (el, 0.047), (fa, 0.054), (wr, 0.037)], part=SKIN, k=0.014)
    return Union([limb, place(hand, wr, H)], k=0.01)


def arms_piece():
    return Union([arm(SH_L, EL_L, WR_L, hand_open(), HAND_L), arm(SH_R, EL_R, WR_R, hand_fist(), HAND_R)], k=0.0)


# ---------------------------------------------------------------------------------------------------- trim: buttons, the name badge, the towel tucked in her apron, clothes pegs in its pocket

def trim_piece(core=None):
    bc = bodice_core()
    parts = []
    for z in (1.12, 1.06, 1.0):
        y = front_y(Inflate(bc, 0.008), 0.0, z)
        parts.append(CappedCone((0, y + 0.004, z), (0, y - 0.005, z), 0.0105, 0.0095, rr=0.003, part=BUTTON))
    by = front_y(Inflate(bc, 0.008), 0.15, 1.165)
    parts.append(Box((0.15, by - 0.002, 1.165), (0.04, 0.005, 0.014), rr=0.003, R=rot(rz=-8, rx=-20), part=BADGE))
    sk = skirt_core()
    towel = Clip(Cut(Inflate(sk, 0.036, part=TOWEL), [Inflate(sk, 0.022)], k=0.002),
                 [prism([(-0.235, 0.975), (-0.105, 0.975), (-0.098, 0.58), (-0.17, 0.56), (-0.243, 0.585)], y1=-0.04)], k=0.004)

    def folds(P):
        return 0.5 + 0.5 * np.sin(P[:, 0] * 120.0 + noise3(P, 0.05) * 1.5)
    parts.append(Bump(towel, folds, 0.004))
    parts.append(Clip(Inflate(Ellipsoid((0, 0.03, 0.955), (0.225, 0.155, 0.1)), 0.031, part=TOWEL),
                      [prism([(-0.24, 0.99), (-0.1, 0.99), (-0.1, 0.935), (-0.24, 0.935)], y1=-0.02)], k=0.004))
    for x, tilt in ((-0.085, -8), (-0.11, 6)):
        y = front_y(Inflate(sk, 0.028), x, 0.78)
        a = v3((x, y + 0.012, 0.74))
        b = a + v3((np.sin(np.radians(tilt)) * 0.09, -0.004, 0.09))
        parts.append(Box((a + b) * 0.5, (0.0075, 0.0055, 0.048), rr=0.002, R=rot(ry=tilt), part=PEG))
    return Union(parts, k=0.0)


def pieces():
    import os
    out = [("head", head(), 0.0022), ("body", body_piece(), 0.0035), ("arms", arms_piece(), 0.0025), ("trim", trim_piece(), 0.002)]
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

    # skin: coral red, warmer and lighter down the middle of the face, mottled, freckled with dark red spots; the flaps' hollows marbled darker
    m = c.mask(SKIN, FLAP, LIP)
    sk = np.broadcast_to(srgb(216, 112, 98), (n, 3)).copy()
    sk = sk + (srgb(232, 140, 122) - sk) * (smooth(0.2, 0.0, Q[:, 0]) * smooth(1.3, 1.45, z) * 0.5)[:, None]
    sk *= (1.0 + 0.08 * mott)[:, None]
    marble = smooth(0.1, 0.5, noise3(P * v3((1.0, 1.0, 2.2)) + 4.0, 0.05) * 0.7 + noise3(P, 0.015) * 0.3)
    fl = c.mask(FLAP)
    sk = np.where(fl[:, None], sk * (0.82 - 0.22 * marble)[:, None], sk)
    sk = sk + (srgb(168, 76, 70) - sk) * (c.cavity * 0.5)[:, None]
    put(m, sk[m], 0.5, bump=0.35, grain=1.0)
    spk(m, (122, 40, 38), 0.45)
    m = c.mask(LIP)
    put(m, (sk * v3((0.86, 0.78, 0.78)))[m], 0.4, bump=0.2)
    # inked: a rim round each eye, the creases from the eyes down to the frown, the frown's own line
    for ex, ez in EYES:
        d = (Q - v3((ex, 0.0, ez)))[:, [0, 2]] / np.array([EYE_RAD[0] + 0.004, EYE_RAD[2] + 0.004], np.float32)
        rr = np.sqrt((d ** 2).sum(1))
        c.draw(c.mask(SKIN) & (y < 0.0) & (rr < 1.25), np.abs(rr - 1.0) * 0.03, 0.0009, 0.55)
    gro = c.mask(SKIN) & (y < -0.02) & (z > MOUTH_Z + 0.01) & (z < 1.5)
    c.draw(gro, np.abs(Q[:, 0] - 0.0) + 0.0 * z, 0.0007, 0.25)
    nl = np.abs(Q[:, 0] - (0.035 + (1.505 - z) * 0.55))
    c.draw(c.mask(SKIN) & (y < -0.02) & (z > MOUTH_Z + 0.005) & (z < 1.49), nl, 0.0006, 0.18)
    arch_d = np.abs(np.hypot(x / 1.0, (z - (MOUTH_Z - 0.012)) / 0.32) - 0.084) * 0.32
    c.draw(c.mask(SKIN, LIP) & (y < -0.02) & (z > MOUTH_Z - 0.012) & (np.abs(x) < 0.09), arch_d, 0.0011, 0.8)

    # eyes: pale cream, a glint, dark corners at either end (as drawn), a faint shadow under the lid
    m = c.mask(EYE)
    ev = srgb(236, 226, 196) * (1.0 - 0.18 * smooth(0.0, 0.03, Q[:, 0] * 0 + np.abs(z - np.round((z - 1.523) / 0.094) * 0.094 - 1.523 - 0.01)))[:, None]
    put(m, ev[m], 0.06)
    for ex, ez in EYES:
        for cx in (ex - EYE_RAD[0] + 0.011, ex + EYE_RAD[0] - 0.011):
            d = np.hypot((Q[:, 0] - cx) / 0.7, z - ez)
            c.draw(m & (np.abs(z - ez) < 0.03), d - 0.0055, 0.0)
        gd = np.hypot(Q[:, 0] - (ex - 0.012), z - (ez + 0.011))
        c.col[m & (gd < 0.008)] = srgb(255, 252, 244)

    # the dress: powder blue, a faint diamond print, faded and stained
    m = c.mask(DRESS)
    a = np.arctan2(x, -(y - 0.03)) * 0.3
    du, dv = a / 0.045, z / 0.045
    dia = np.abs((du - np.floor(du)) - 0.5) + np.abs((dv - np.floor(dv)) - 0.5)
    dr = np.broadcast_to(srgb(132, 166, 190), (n, 3)).copy()
    dr = dr + (srgb(156, 186, 206) - dr) * (smooth(0.4, 0.35, dia) * 0.35)[:, None]
    dr *= (1.0 + 0.06 * mott)[:, None]
    stain = smooth(0.22, 0.55, noise3(P + 7.3, 0.04) * 0.6 + noise3(P, 0.012) * 0.4)
    stain = np.maximum(stain, smooth(0.62, 0.42, z) * smooth(0.15, 0.5, noise3(P + 2.9, 0.03)) * 0.8)
    dr = dr + (srgb(150, 118, 74) - dr) * (stain * 0.6)[:, None]
    dr *= (1.0 - 0.3 * c.cavity)[:, None]
    put(m, dr[m], 0.82, bump=1.0)
    spk(m, (134, 104, 66), 0.25)
    m = c.mask(WHITE)
    wt = srgb(228, 220, 198) * (1.0 - 0.3 * c.cavity)[:, None] * (1.0 + 0.04 * mott)[:, None]
    wt = wt + (srgb(170, 140, 100) - wt) * (stain * 0.35)[:, None]
    put(m, wt[m], 0.8, bump=0.9)
    spk(m, (150, 118, 80), 0.2)

    # the apron: cream, spattered and blotched with old sauce and grease, worst low down the middle
    m = c.mask(APRON)
    ap = srgb(226, 214, 186) * (1.0 + 0.05 * mott)[:, None]
    blot = smooth(0.2, 0.55, noise3(P + 2.2, 0.035) * 0.6 + noise3(P, 0.011) * 0.4) * (0.5 + 0.5 * smooth(0.9, 0.6, z))
    ap = ap + (srgb(168, 120, 60) - ap) * (blot * 0.75)[:, None]
    ap *= (1.0 - 0.35 * c.cavity)[:, None]
    put(m, ap[m], 0.85, bump=0.9)
    spk(m, (140, 92, 40), 0.55)
    # the towel: white, three pink stripes near its foot
    m = c.mask(TOWEL)
    tw = srgb(236, 230, 224) * (1.0 - 0.3 * c.cavity)[:, None]
    stripe = (smooth(0.004, 0.0, np.abs(z - 0.63) - 0.006) + smooth(0.004, 0.0, np.abs(z - 0.655) - 0.003)
              + smooth(0.004, 0.0, np.abs(z - 0.605) - 0.003))
    tw = tw + (srgb(222, 128, 158) - tw) * np.clip(stripe, 0, 1)[:, None]
    put(m, tw[m], 0.9, bump=1.0)
    put(c.mask(BUTTON), srgb(228, 220, 200), 0.35, bump=0.1)
    m = c.mask(BADGE)
    put(m, srgb(226, 176, 60), 0.3, metal=0.7)
    c.draw(m & (y < -0.02), np.abs(z - 1.165) + 0.0 * x, 0.0018, 0.6)
    m = c.mask(SHOE)
    put(m, (srgb(112, 26, 36) * (1.0 + 0.6 * c.wear)[:, None])[m], 0.2, bump=0.15, grain=1.0)
    m = c.mask(GOLD)
    put(m, (srgb(232, 178, 80) * (1.0 - 0.4 * c.cavity)[:, None])[m], 0.25, metal=1.0)
    put(c.mask(PEG), srgb(176, 128, 76), 0.6, bump=0.4)
    put(c.mask(NAIL), srgb(120, 38, 40), 0.3)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 3200, "body": 4000, "arms": 1400, "trim": 600},
    "density": {"head": 1.6, "trim": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.82, "run": 1.4},
    "speed": 1.1,
    "look": ["head", "flap.L", "flap.R"], "neck": "neck",
    "look_pivot": (0.0, 0.035, 1.36),
    "radius": 0.55,
}
FLAP_ROOT = v3((0.2, 0.06, 1.42))
FLAP_TIP = v3((0.52, 0.06, 1.33))


def rig_bones():
    from kit.rig import Bone, mirror
    toe = ANKLE + FFWD * 0.24 + v3((0, 0, -0.08))
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.03, 0.86), (0, 0.03, 0.98), "root", 0.2),
        Bone("spine", (0, 0.03, 0.98), (0, 0.03, 1.1), "hips", 0.17),
        Bone("chest", (0, 0.03, 1.1), (0, 0.04, 1.24), "spine", 0.19),
        Bone("neck", (0, 0.04, 1.2), (0, 0.035, 1.36), "chest", 0.11),
        Bone("head", (0, 0.035, 1.36), (0, 0.0, 1.72), "neck", 0.12),
        Bone("flap.L", FLAP_ROOT, FLAP_TIP, "head", 0.07),
        Bone("thigh.L", HIP, KNEE, "hips", 0.07),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.05),
        Bone("foot.L", ANKLE, toe, "shin.L", 0.035),
    ])
    bones += [
        Bone("shoulder.L", (0.08, 0.04, 1.2), SH_L, "chest", 0.06),
        Bone("upper_arm.L", SH_L, EL_L, "shoulder.L", 0.05),
        Bone("forearm.L", EL_L, WR_L, "upper_arm.L", 0.045),
        Bone("hand.L", WR_L, WR_L - HAND_L[:, 2] * 0.13, "forearm.L", 0.03),
        Bone("shoulder.R", (-0.08, 0.04, 1.2), SH_R, "chest", 0.06),
        Bone("upper_arm.R", SH_R, EL_R, "shoulder.R", 0.05),
        Bone("forearm.R", EL_R, WR_R, "upper_arm.R", 0.045),
        Bone("hand.R", WR_R, WR_R - HAND_R[:, 2] * 0.1, "forearm.R", 0.035),
    ]
    return bones


def _seg(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / float(ab @ ab), 0.0, 1.0)
    return np.linalg.norm(P - a - np.outer(t, ab), axis=1)


def skin_rules(P, part, piece, names):
    """piece: 0 head (diamond, flaps, neck), 1 body (dress, apron, legs, shoes), 2 arms, 3 trim"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    # head: the diamond rigid, the flaps on their own bones from the head, the neck from the collar
    hp = piece == 0
    fl = hp & (part == FLAP)
    allow(fl, "head")
    allow(fl & (x > 0), "flap.L")
    allow(fl & (x <= 0), "flap.R")
    allow(hp & ~fl & (z < 1.36), "chest", "neck", "head")
    rig[hp & ~fl & (z >= 1.36)] = ix["head"]
    allow(hp & ~fl & (z >= 1.36), "head")
    # the body
    bp = piece == 1
    legs = bp & (np.isin(part, (SKIN, SHOE, GOLD)) | (z < 0.4))
    for s, sd in ((1, "L"), (-1, "R")):
        m = legs & (x * s > 0)
        allow(m, "thigh." + sd, "shin." + sd, "foot." + sd)
        rig[m & (z < 0.07) & (np.isin(part, (SHOE, GOLD)))] = ix["foot." + sd]
    # the A-line skirt swings with the hips alone: it is wide enough that the knees never reach it (riding the thighs, it buckled)
    skirt = bp & ~legs & (z < 0.93)
    allow(skirt, "hips")
    top = bp & ~legs & ~skirt
    allow(top, "hips", "spine", "chest")
    allow(top & (z > 1.15) & (np.abs(x) < 0.16), "neck")
    for s, sd, sh, el in ((1, "L", SH_L, EL_L), (-1, "R", SH_R, EL_R)):
        m = top & (x * s > 0.17)
        allow(m, "shoulder." + sd, "upper_arm." + sd)
    # arms
    ap = piece == 2
    for s, sd, wr, H in ((1, "L", WR_L, HAND_L), (-1, "R", WR_R, HAND_R)):
        m = ap & (x * s > 0)
        allow(m, "shoulder." + sd, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        rig[m & (((P - wr) @ -H[:, 2]) > 0.02)] = ix["hand." + sd]
    # trim: buttons and badge on the chest, the towel and pegs on the hips
    tp = piece == 3
    rig[tp & (z > 0.99)] = ix["chest"]
    rig[tp & (z <= 0.99) & (part != TOWEL)] = ix["hips"]
    rig[tp & (part == TOWEL)] = ix["hips"]
    allow(tp, "hips", "chest")
    return A, rig


WALK = dict(stride=0.82, stance=0.6, foot_x=0.07, lift=0.05, bob=0.014, drop=0.045, sway=0.035, roll=6.0, yaw=7.0, counter=1.1,
            lean=-2.0, toe_off=14.0, toe_out=-16.0, swing_point=6.0)
RUN = dict(stride=1.4, stance=0.42, foot_x=0.08, lift=0.1, bob=0.03, drop=0.06, sway=0.025, roll=5.0, yaw=9.0, counter=1.3,
           lean=7.0, toe_off=22.0, toe_out=-16.0, swing_point=12.0, spine_lean=3.0)


def motions(rig):
    """her clips: walk (prim, quick, short steps along a line, hips swinging, the fist kept on her hip, the free arm swinging briskly, the head
    held high and level, the flaps bouncing), run (a hurried trot, still with the fist on her hip), idle (weight on one hip, the left foot
    tapping impatiently, a huff, a disapproving tilt of the head)"""
    import math
    from mathutils import Vector
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    hips_h = Vector((0.0, 0.03, 0.86))
    sh, el, wr = Vector(SH_R.tolist()), Vector(EL_R.tolist()), Vector(WR_R.tolist())
    line = (wr - sh).normalized()
    pole_rest = ((el - sh) - line * (el - sh).dot(line)).normalized()

    def akimbo(p, Rh):
        """keep the right fist planted on the hip: its wrist rides the hips' motion"""
        tgt = Vector(p.offset) + hips_h + Rh @ (wr - hips_h)
        p.ik["upper_arm.R"] = (tgt, Rh @ pole_rest, "hand.R", Rh)

    def imp(u, at, w=0.05):
        d = ((u - at + 0.5) % 1.0) - 0.5
        return math.exp(-(d / w) ** 2)

    def walkish(u, g, run):
        p = Pose()
        roll, yaw = biped_walk(rig, p, u, g, legs)
        akimbo(p, R(g["lean"], roll, yaw))
        c = math.cos(TAU * u)
        p.rot("upper_arm.L", (30.0 if run else 14.0) * c, 0, 0)
        p.rot("forearm.L", -(30.0 if run else 12.0) - (16.0 if run else 8.0) * max(0.0, -c), 0, 0)
        p.rot("hand.L", 6.0 * math.cos(TAU * (u - 0.1)), 0, 0)
        p.rot("chest", -1.5, 0, 0)
        bounce = imp(u, 0.06) + imp(u, 0.56)
        p.rot("neck", -2.0 + 1.5 * bounce, 0, 0)
        p.world["head"] = R((2.0 if run else -4.0) + 1.5 * math.sin(2 * TAU * (u - 0.1)), 0, -yaw * 0.15)
        fl = -3.0 + 7.0 * (imp(u, 0.1, 0.07) + imp(u, 0.6, 0.07)) + (6.0 if run else 0.0)
        p.rot("flap.L", 0, fl, 0)
        p.rot("flap.R", 0, -fl, 0)
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    heel = Vector((ANKLE + v3((0, 0.03, -0.095))).tolist())
    ank = Vector(ANKLE.tolist())
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sw = math.sin(TAU * t / 6.0)
        stand(rig, p, legs, {"L": (Vector(BALL.tolist()), 0.0), "R": (Vector((BALL * f).tolist()), 0.0)},
              hip_shift=(-0.025 + 0.006 * sw, 0.0, -0.012), roll=4.0, yaw=3.0)
        # the left foot taps: four quick taps, a pause, four more (toes lifting off the planted heel)
        tap = 0.0
        for start in (0.6, 3.6):
            if start <= t < start + 1.6:
                tap = max(0.0, math.sin(TAU * (t - start) / 0.4)) * ease((t - start) / 0.1) * ease((start + 1.6 - t) / 0.1)
        wf = R(-16.0 * tap, 0, 0)
        p.ik["thigh.L"] = (heel + wf @ (ank - heel), Vector((0.15, -1.0, 0.0)), "foot.L", wf)
        huff = math.exp(-((t - 2.6) / 0.35) ** 2)
        p.rot("spine", -1.0 * huff, 0, 0)
        p.rot("chest", -2.5 * huff + 0.8 * math.sin(TAU * t / 3.0), 0, 0)
        akimbo(p, R(0, 4.0, 3.0))
        p.rot("upper_arm.L", 1.5 * math.sin(TAU * t / 3.0), 0, 0)
        p.rot("forearm.L", -4.0 - 3.0 * huff, 0, 0)
        tilt = math.sin(math.pi * min(1.0, max(0.0, (t - 2.9) / 2.4)))
        p.world["head"] = R(-3.0 - 4.0 * huff, 0, 0) @ R(0, -9.0 * tilt, 6.0 * tilt)
        fl = -2.0 + 6.0 * huff + 1.5 * math.sin(TAU * t / 2.0)
        p.rot("flap.L", 0, fl, 0)
        p.rot("flap.R", 0, -fl, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
