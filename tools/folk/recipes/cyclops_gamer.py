## FOINT CITY townsfolk: the cyclops gamer (working name; the user names it). A small blue cyclops: its head a chiselled block that is one big eye, a wide toothy mouth on its belly, a skull t-shirt, a tool apron, star high-tops, a handheld console held up in both hands.
# Concept: the user's sheet, image 7 top left (F:/prog-godot-cache/folk/refs/7.webp). Measured off it (1x px = 3.55 mm at 1.20 m): the head block is 0.46 m tall and the
# eye 80% of that (0.36 m); the mouth (0.28 m wide, 0.14 tall with its lips) sits on the belly just under the shirt's torn hem; the legs are thick, short and splayed
# wide in a crouch (the stance about 0.9 m across), the high-tops 0.22 m tall and 0.32 long, toes turned out. Everything is chiselled into planes.
# Rest pose = its gaming pose: crouched, the console held up in both hands in front of the chest, the eye looking down at it.
# Kit gaps filled here: ERing (an elliptical torus: the eye socket's rim), hull() (a box cut by planes: the chamfered head), chisel_*() (planar facets cut into a
# blob or a limb), Bounded (a tight bound for clipped long shapes), hit() / normal() (probe the clay to seat features on it).
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.20
REF = ("7.webp", (41, 9, 340, 366))

(SKIN, EYE, LIP_U, LIP_L, TOOTH_U, TOOTH_L, SHIRT, CANVAS, METAL, RED, RAG, SHOE, RUBBER, LACE, CONSOLE, SCREEN, BUTTON, DPAD) = range(1, 19)
COLOURS = {
    SKIN: ((0.11, 0.10, 0.45), 0.55, 0.0),
    EYE: ((0.85, 0.52, 0.27), 0.15, 0.0),
    LIP_U: ((0.55, 0.13, 0.20), 0.3, 0.0),
    LIP_L: ((0.55, 0.13, 0.20), 0.3, 0.0),
    TOOTH_U: ((0.74, 0.58, 0.22), 0.4, 0.0),
    TOOTH_L: ((0.74, 0.58, 0.22), 0.4, 0.0),
    SHIRT: ((0.70, 0.64, 0.55), 0.85, 0.0),
    CANVAS: ((0.40, 0.25, 0.10), 0.8, 0.0),
    METAL: ((0.6, 0.6, 0.62), 0.35, 1.0),
    RED: ((0.45, 0.02, 0.02), 0.3, 0.0),
    RAG: ((0.8, 0.7, 0.68), 0.9, 0.0),
    SHOE: ((0.05, 0.06, 0.15), 0.8, 0.0),
    RUBBER: ((0.72, 0.62, 0.50), 0.7, 0.0),
    LACE: ((0.85, 0.82, 0.74), 0.8, 0.0),
    CONSOLE: ((0.42, 0.38, 0.33), 0.55, 0.0),
    SCREEN: ((0.02, 0.04, 0.01), 0.15, 0.0),
    BUTTON: ((0.55, 0.05, 0.05), 0.35, 0.0),
    DPAD: ((0.03, 0.03, 0.035), 0.5, 0.0),
}
F32 = np.float32


# ---------------------------------------------------------------------------------------------------- helpers the kit lacks

class ERing(Shape):
    """a torus whose centre line is an ellipse: semi-axes a (local x) and b (local y) in the local XY plane of R, tube radius r"""
    def __init__(self, c, a, b, r, R=None, part=0):
        self.c, self.e, self.r, self.part = v3(c), np.array([a, b], F32), F32(r), part
        self.R = np.eye(3, dtype=F32) if R is None else np.asarray(R, F32)
        m = max(a, b) + r
        self.lo, self.hi = self.c - m, self.c + m

    def dist(self, P):
        q = (P - self.c) @ self.R
        q2 = q[:, :2]
        k0 = np.sqrt(((q2 / self.e) ** 2).sum(1))
        k1 = np.sqrt(((q2 / (self.e * self.e)) ** 2).sum(1))
        rho = np.where(k0 < 1e-6, -float(self.e.min()), k0 * (k0 - 1.0) / np.maximum(k1, 1e-9))
        return np.sqrt(rho * rho + q[:, 2] ** 2) - self.r


class Bounded(Shape):
    """the child with a tighter bound than it works out itself (clips of half-spaces and long cylinders keep their child's huge bound)"""
    def __init__(self, child, lo, hi):
        self.child, self.lo, self.hi, self.part = child, v3(lo), v3(hi), child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.child.eval(P)[0]


def hull(planes, k, lo, hi, part=0):
    """a convex block inside the box lo..hi, cut down by planes [(point, outward normal)], its edges rounded by k"""
    lo, hi = v3(lo), v3(hi)
    return Clip(Box((lo + hi) * 0.5, (hi - lo) * 0.5, part=part), [Half(c, n) for c, n in planes], k=k)


def chamfer(E, n1, n2, w):
    """the plane that bevels the edge E between faces of normals n1, n2 by w along each face"""
    n1, n2 = v3(n1) / np.linalg.norm(n1), v3(n2) / np.linalg.norm(n2)
    return (v3(E) - n2 * w, n1 + n2)


def _dirs(n, seed, jitter=0.5):
    rng = np.random.default_rng(seed)
    i = np.arange(n) + 0.5
    phi = np.arccos(1.0 - 2.0 * i / n)
    th = np.pi * (1.0 + 5 ** 0.5) * i
    d = np.stack([np.cos(th) * np.sin(phi), np.sin(th) * np.sin(phi), np.cos(phi)], 1)
    d += rng.normal(0.0, jitter * 1.8 / np.sqrt(n), d.shape)
    return (d / np.linalg.norm(d, axis=1, keepdims=True)).astype(F32), rng


def chisel_ell(c, rad, n, depth, seed, part=SKIN, k=0.004):
    """an ellipsoid with hand-cut planar facets (depth: how deep each plane cuts, varied)"""
    c, rad = v3(c), v3(rad)
    dirs, rng = _dirs(n, seed)
    planes = [Half(c + d * (np.sqrt(((rad * d) ** 2).sum()) - depth * (0.45 + 1.1 * rng.random())), d) for d in dirs]
    return Clip(Ellipsoid(c, rad, part=part), planes, k=k)


def chisel_cap(a, b, r1, r2, n, depth, seed, part=SKIN, k=0.004):
    """a limb segment (round cone) with planar facets cut along it"""
    a, b = v3(a), v3(b)
    dirs, rng = _dirs(n, seed)
    planes = [Half(d * (max(float(a @ d) + r1, float(b @ d) + r2) - depth * (0.45 + 1.1 * rng.random())), d) for d in dirs]
    return Clip(RoundCone(a, b, r1, r2, part=part), planes, k=k)


def hit(shape, start, direction, far=0.6, n=240):
    """where a ray from `start` first enters `shape` (probing the clay to seat a feature on it)"""
    d = v3(direction) / np.linalg.norm(direction)
    s = v3(start)
    ts = np.linspace(0.0, far, n).astype(F32)
    dd = shape.eval((s[None, :] + ts[:, None] * d[None, :]).astype(F32))[0]
    i = int(np.argmax(dd < 0))
    if dd[i] >= 0 or i == 0:
        raise ValueError("hit: no surface along the ray from %s" % (s,))
    a, b = float(ts[i - 1]), float(ts[i])
    for _ in range(30):
        m = 0.5 * (a + b)
        if shape.eval((s + d * m)[None, :].astype(F32))[0][0] < 0:
            b = m
        else:
            a = m
    return s + d * F32(0.5 * (a + b))


def normal(shape, p, e=0.0015):
    ex = np.eye(3, dtype=F32) * e
    g = np.array([shape.eval((p + ex[i])[None, :])[0][0] - shape.eval((p - ex[i])[None, :])[0][0] for i in range(3)], F32)
    return g / np.linalg.norm(g)


# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; the figure faces -Y)

HB = v3((0.0, 0.05, 0.781))              # the head block's bottom centre: it turns about here
HEAD_R = rot(rx=10.0)                     # the block leans 10 degrees forward over the console


def hw(p):
    """head space (upright, origin at the block's bottom centre) to world"""
    return HB + HEAD_R @ v3(p)


HF = -0.15                               # the eye face (head space y)
EYE_L = v3((0.0, -0.114, 0.226))         # the eyeball's centre in head space
EYE_RAD = v3((0.122, 0.092, 0.168))
EYE_C = hw(EYE_L)
CON = v3((0.0, -0.345, 0.775))           # the console's centre; it faces the eye
CON_N = (EYE_C - CON) / np.linalg.norm(EYE_C - CON)
CON_R = basis(CON_N, v3((0, 0, 1)))      # console space as its player sees it: x to the player's right (-X), y up the face, z out of the screen toward the eye
SHOULDER = v3((0.19, 0.03, 0.625))
ELBOW = v3((0.31, -0.07, 0.53))
WRIST_C = v3((-0.15, -0.05, -0.012))     # the left wrist in console space (the left end is -x)
WRIST = CON + CON_R @ WRIST_C
HIP = v3((0.13, 0.03, 0.375))
KNEE = v3((0.32, -0.045, 0.30))
ANKLE = v3((0.30, 0.0, 0.12))
TOE_OUT = 22.0
FWD = v3((np.sin(np.radians(TOE_OUT)), -np.cos(np.radians(TOE_OUT)), 0.0))
BALL = ANKLE + FWD * 0.13 - v3((0, 0, ANKLE[2]))
MZ = 0.432                               # the mouth's line on the belly
MW = 0.145                               # half its width


# ---------------------------------------------------------------------------------------------------- the head: a chamfered block holding one big eye

def head_block():
    """head space, the figure's left half (mirrored): a wedge, deep at the bottom, its top sloping back, every edge bevelled, the faces hand-cut"""
    F_, B_, T_, Bo, S_ = (0, -1, 0), (0, 0.959, 0.283), (0, 0.3, 1.0), (0, 0, -1), (1, 0, 0.1)
    planes = [
        ((0, HF, 0.2), F_),                    # the eye face
        ((0, 0.165, 0.0), B_),                 # the back, leaning in toward the top
        ((0, HF, 0.46), T_),                   # the top, sloping down to the back
        ((0, 0, 0.0), Bo),
        ((0.162, 0, 0.0), S_),                 # the sides, leaning in toward the top
        chamfer((0, HF, 0.46), F_, T_, 0.075),
        chamfer((0, 0.06, 0.40), T_, B_, 0.075),
        chamfer((0, 0.165, 0.0), B_, Bo, 0.05),
        chamfer((0, HF, 0.0), F_, Bo, 0.02),
        chamfer((0.162, HF, 0.2), S_, F_, 0.03),
        chamfer((0.162, 0.106, 0.2), S_, B_, 0.05),
        chamfer((0.122, 0.0, 0.43), S_, T_, 0.06),
        chamfer((0.162, 0.0, 0.0), S_, Bo, 0.035),
        # hand-cut facets: the side, back and top each broken into a few planes
        ((0.155, -0.06, 0.12), (1, -0.14, -0.18)),
        ((0.142, 0.05, 0.32), (1, 0.16, 0.18)),
        ((0.142, -0.08, 0.34), (1, -0.12, 0.26)),
        ((0.0, 0.135, 0.1), (0.18, 0.96, 0.15)),
        ((0.06, -0.05, 0.445), (0.14, 0.1, 1.0)),
        ((0.1, -0.12, 0.43), (0.5, -0.5, 1.0)),
    ]
    block = hull(planes, 0.011, (-0.01, -0.17, -0.01), (0.18, 0.2, 0.5), part=SKIN)
    rim = ERing((0, HF - 0.002, EYE_L[2]), 0.128, 0.172, 0.0165, R=basis(v3((0, -1, 0)), v3((0, 0, 1))), part=SKIN)
    block = Union([block, rim], k=0.011)
    socket = Ellipsoid(EYE_L, EYE_RAD + 0.007)
    return Cut(block, [socket], k=0.004)


def head():
    block = Move(Mirror(head_block()), R=HEAD_R, t=HB)
    neck = RoundCone((0.0, 0.025, 0.60), hw((0, 0.02, 0.07)), 0.074, 0.08, part=SKIN)
    ball = Ellipsoid(EYE_C, EYE_RAD, R=HEAD_R, part=EYE)
    return Union([Union([block, neck], k=0.035), ball], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body: a pear of a belly with the mouth on it, the shirt, the legs

def core(cut=True):
    """the trunk, chiselled; cut=False gives the smooth trunk (what the shirt and the mouth are fitted to)"""
    sh = [((0, 0.03, 0.585), (0.205, 0.158, 0.13)), ((0, 0.035, 0.655), (0.185, 0.115, 0.06)),
          ((0, 0.0, 0.43), (0.25, 0.2, 0.165)), ((0, 0.035, 0.34), (0.195, 0.165, 0.09))]
    if not cut:
        return Union([Ellipsoid(c, r) for c, r in sh], k=0.06, part=SKIN)
    return Union([chisel_ell(c, r, 44, 0.013, 11 + i) for i, (c, r) in enumerate(sh)], k=0.05, part=SKIN)


def prism(poly_xz, y0=-0.6, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from the front (y0) to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], F32))


def torn(P):
    return noise3(P, 0.022) * 0.7 + noise3(P, 0.008) * 0.3


def shirt():
    up = Union([Ellipsoid((0, 0.03, 0.585), (0.205, 0.158, 0.13)), Ellipsoid((0, 0.035, 0.655), (0.185, 0.115, 0.06)),
                Ellipsoid((0, 0.0, 0.43), (0.25, 0.2, 0.165))], k=0.06)
    du = (ELBOW - SHOULDER) / np.linalg.norm(ELBOW - SHOULDER)
    end = SHOULDER + du * 0.09
    sleeve = Clip(loft([(SHOULDER - du * 0.045, 0.064), (end, 0.054)], part=SHIRT), [Half(end, du)], k=0.004)
    sleeve = Cut(sleeve, [RoundCone(end - du * 0.035, end + du * 0.02, 0.038, 0.043)], k=0.003)
    shell = Union([Inflate(up, 0.013, part=SHIRT), Mirror(sleeve)], k=0.022, part=SHIRT)
    folds = lambda P: noise3(P * v3((1.6, 1.0, 0.45)), 0.05) * 0.7 + noise3(P, 0.02) * 0.3          # soft draped folds, running down
    shell = Bump(shell, folds, 0.005)
    hem = Bump(Half((0, 0, 0.49), (0, -0.075, -1.0)), torn, 0.013)
    shell = Clip(shell, [hem], k=0.003)
    shell = Cut(shell, [CappedCone((0, 0.03, 0.58), (0, 0.06, 0.9), 0.086, 0.086)], k=0.004)
    collar = Torus((0, 0.035, 0.698), 0.089, 0.0085, part=SHIRT)
    return Union([shell, collar], k=0.006)


def leg():
    k1 = HIP + v3((-0.05, 0.0, 0.015))
    a = chisel_cap(k1, KNEE, 0.094, 0.082, 22, 0.011, 31)
    b = chisel_cap(KNEE, ANKLE + v3((0, 0, 0.05)), 0.082, 0.056, 18, 0.009, 37)
    return Union([a, b], k=0.03, part=SKIN)


def body():
    b = Union([core(), Mirror(leg())], k=0.045, part=SKIN)
    return Cut(b, [Ellipsoid((0, -0.185, MZ), (0.122, 0.06, 0.019))], k=0.006)      # the mouth's slot, behind the lips


# ---------------------------------------------------------------------------------------------------- the mouth: big glossy lips round the belly, a row of square yellow teeth

def mouth():
    bc = core(cut=False)
    lips = []
    ts = np.linspace(-1.0, 1.0, 15)
    for sgn, out in ((1.0, LIP_U), (-1.0, LIP_L)):
        pts = []
        for t in ts:
            w = max(0.0, 1.0 - t * t)
            if sgn > 0:
                z = MZ + 0.004 + 0.034 * w ** 0.85 - 0.0045 * np.exp(-(t / 0.13) ** 2)
                r = 0.005 + 0.0175 * w ** 0.55
            else:
                z = MZ - 0.004 - 0.040 * w ** 0.85
                r = 0.005 + 0.0225 * w ** 0.55
            s = hit(bc, (MW * t, -0.5, z), (0, 1, 0))
            nn = normal(bc, s)
            pts.append((s + nn * (r * 0.42), r))
        lips.append(loft(pts, part=out, k=0.012))
    teeth = []
    rng = np.random.default_rng(5)
    # big uneven teeth, a gap where one is missing; the lower row mostly behind the lip
    for ts_, half, zc, out in (((-0.66, -0.4, -0.13, 0.13, 0.43, 0.66), (0.0165, 0.015, 0.008), MZ + 0.002, TOOTH_U),
                               ((-0.5, -0.24, 0.02, 0.26, 0.5), (0.0125, 0.011, 0.007), MZ - 0.021, TOOTH_L)):
        for t in ts_:
            s = hit(bc, (MW * t, -0.5, zc), (0, 1, 0))
            nn = normal(bc, s)
            nn[2] = 0.0
            nn /= np.linalg.norm(nn)
            j = 1.0 + rng.uniform(-0.12, 0.12)
            hh = (half[0] * (1.0 - 0.2 * abs(t)) * j, half[1] * (1.0 - 0.25 * abs(t)) * (2.0 - j), half[2])
            R = basis(nn, v3((0, 0, 1))) @ rot(rz=rng.uniform(-5, 5))
            teeth.append(Box(s - nn * 0.005, hh, rr=0.004, R=R, part=out))
    return Union(lips + teeth, k=0.0)


# ---------------------------------------------------------------------------------------------------- the tool apron

def gear():
    cyl = Ellipsoid((0, 0.02, 0.34), (0.245, 0.205, 2.0))
    sag = lambda P: np.exp(-(P[:, 0] / 0.09) ** 2) * np.clip((0.3 - P[:, 2]) / 0.15, 0, 1)     # the pocket bellies out with its load
    # a heavy canvas apron (solid, 16 mm: thin shells will not decimate or bake), the pocket a raised panel on it, open at the top
    apron = Clip(Cut(Inflate(cyl, 0.016, part=CANVAS), [Inflate(cyl, 0.0)]), [
        prism([(-0.2, 0.345), (0.2, 0.345), (0.19, 0.15), (0.15, 0.11), (0.0, 0.098), (-0.15, 0.11), (-0.19, 0.15)]),
        Half((0, -0.02, 0), (0, 1, 0))], k=0.004)
    pocket = Clip(Cut(Bump(Inflate(cyl, 0.027, part=CANVAS), sag, 0.012), [Inflate(cyl, 0.008)]), [
        prism([(-0.125, 0.268), (0.125, 0.274), (0.12, 0.15), (0.1, 0.128), (-0.1, 0.128), (-0.12, 0.15)]),
        Half((0, -0.02, 0), (0, 1, 0))], k=0.004)
    slot = Bounded(Clip(Cut(Inflate(cyl, 0.022), [Inflate(cyl, 0.015)]), [prism([(-0.11, 0.29), (0.11, 0.29), (0.11, 0.24), (-0.11, 0.24)]),
                                                                       Half((0, -0.02, 0), (0, 1, 0))]), (-0.13, -0.27, 0.2), (0.13, 0.0, 0.3))
    pocket = Cut(pocket, [slot], k=0.002)
    band = Clip(Inflate(core(), 0.01, part=CANVAS), [Half((0, 0, 0.352), (0.0, 0.0, 1.0)), Half((0, 0, 0.315), (0.0, 0.0, -1.0))], k=0.003)     # hugs the chiselled trunk
    # what's in the pocket: two screwdrivers, a wrench, a rag hanging over the edge
    yp = -0.212
    tools = []
    for x, z1, lean in ((-0.07, 0.37, -9.0), (-0.03, 0.39, 6.0)):
        a = v3((x, yp, 0.25))
        d = rot(ry=lean) @ v3((0, 0, 1))
        b = a + d * (z1 - 0.25)
        tools.append(CappedCone(a + d * 0.027, b, 0.0128, 0.0118, rr=0.005, part=RED))
        tools.append(CappedCone(a, a + d * 0.029, 0.0075, 0.009, rr=0.002, part=METAL))
    wa, wb = v3((0.035, yp + 0.002, 0.235)), v3((0.048, yp - 0.002, 0.33))
    jaw = Cut(Torus(wb + v3((0, 0, 0.014)), 0.019, 0.007, Rm=basis(v3((0, -1, 0)), v3((0, 0, 1))), part=METAL),
              [Box(wb + v3((0, 0, 0.032)), (0.009, 0.03, 0.016))], k=0.002)
    tools.append(Union([RoundCone(wa, wb, 0.008, 0.0085, part=METAL), jaw], k=0.004))
    rag = Bump(Box((0.1, yp - 0.012, 0.21), (0.03, 0.007, 0.064), rr=0.006, R=rot(ry=-8, rx=-6), part=RAG), lambda P: noise3(P, 0.014), 0.004)
    cloth = Union([Bounded(apron, (-0.23, -0.27, 0.08), (0.23, 0.0, 0.37)), Bounded(pocket, (-0.16, -0.27, 0.11), (0.16, 0.0, 0.3)), band], k=0.004, part=CANVAS)
    return Union([cloth] + tools + [rag], k=0.0)


# ---------------------------------------------------------------------------------------------------- star high-tops

def shoe():
    f = FWD
    side = np.cross(v3((0, 0, 1)), f)          # out of the foot's left side
    a = v3((ANKLE[0], ANKLE[1], 0.0))
    upper = loft([(a - f * 0.04 + v3((0, 0, 0.066)), 0.064), (a + f * 0.07 + v3((0, 0, 0.066)), 0.069), (a + f * 0.17 + v3((0, 0, 0.05)), 0.051)], part=SHOE, k=0.03)
    shaft = CappedCone(a + v3((0, 0, 0.05)), a + v3((0, 0.004, 0.218)), 0.076, 0.072, rr=0.012, part=SHOE)
    up = Union([upper, shaft], k=0.03, part=SHOE)
    up = Clip(up, [Half((0, 0, 0.012), (0, 0, -1))])
    sole = Clip(Inflate(upper, 0.007, part=RUBBER), [Half((0, 0, 0.036), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.002)
    cap = Clip(Inflate(upper, 0.004, part=RUBBER), [Half(a + f * 0.13, -f), Half((0, 0, 0.0), (0, 0, -1))], k=0.004)
    collar = Torus(a + v3((0, 0.004, 0.216)), 0.07, 0.0145, part=RUBBER)
    tongue = Box(a + f * 0.062 + v3((0, 0, 0.215)), (0.034, 0.008, 0.032), rr=0.007, R=basis(f, v3((0, 0, 1))) @ rot(rx=-90), part=SHOE)
    laces = []
    for i in range(5):
        p = a + f * (0.125 - 0.024 * i)
        s = hit(up, p + v3((0, 0, 0.35)), (0, 0, -1))
        for sg in (-1.0, 1.0):
            d = side * 0.028 * sg + f * 0.009
            laces.append(RoundCone(s - d + v3((0, 0, 0.003)), s + d + v3((0, 0, 0.003)), 0.0048, part=LACE))
    return Union([up, sole, cap, collar, tongue] + laces, k=0.0)


# ---------------------------------------------------------------------------------------------------- arms, hands and the console

def hand():
    """console space, the left hand round the console's left end (-x): palm on the end, four long fingers over the back, the thumb on the d-pad"""
    X = v3((-1.0, 1.0, 1.0))
    w = WRIST_C
    parts = [RoundCone(w + v3((-0.01, -0.03, 0.002)), w, 0.021, 0.02, part=SKIN),
             Ellipsoid(X * v3((0.137, -0.014, -0.004)), (0.016, 0.033, 0.024), part=SKIN)]
    for v0 in (-0.032, -0.011, 0.01, 0.03):
        L = 1.0 - abs(v0 + 0.001) * 6.0
        pts = [((0.137, v0, -0.018), 0.0088), ((0.118, v0 + 0.004, -0.031), 0.0085), ((0.096, v0 + 0.008, -0.031), 0.008),
               ((0.096 - 0.026 * L, v0 + 0.011, -0.029), 0.0072)]
        parts.append(loft([(X * v3(p), r) for p, r in pts], part=SKIN, k=0.004))
        parts.append(Sphere(X * v3(pts[1][0]), 0.0095, part=SKIN))           # a knobbly knuckle
    parts.append(loft([(X * v3((0.142, -0.036, 0.008)), 0.011), (X * v3((0.13, -0.022, 0.026)), 0.0098), (X * v3((0.106, -0.007, 0.029)), 0.009),
                       (X * v3((0.088, -0.001, 0.027)), 0.0082)], part=SKIN, k=0.004))
    return Union(parts, k=0.007)


def arms():
    arm = loft([(SHOULDER - (ELBOW - SHOULDER) * 0.15, 0.031), (ELBOW, 0.026), (ELBOW + (WRIST - ELBOW) * 0.3, 0.028), (WRIST, 0.021)], part=SKIN, k=0.02)
    elbow = Sphere(ELBOW + v3((0.004, 0.006, -0.006)), 0.028, part=SKIN)
    return Mirror(Union([arm, elbow, place(hand(), CON, CON_R)], k=0.012))


def console():
    """console space: a battered handheld, screen and buttons toward the eye"""
    shell = Box((0, 0, 0), (0.12, 0.064, 0.019), rr=0.016, part=CONSOLE)
    shell = Cut(shell, [Box((0, 0.012, 0.021), (0.056, 0.043, 0.005), rr=0.004)], k=0.002)
    screen = Box((0, 0.012, 0.015), (0.052, 0.039, 0.002), rr=0.002, part=SCREEN)
    dpad = Union([Box((-0.082, -0.002, 0.019), (0.022, 0.0075, 0.004), rr=0.002), Box((-0.082, -0.002, 0.019), (0.0075, 0.022, 0.004), rr=0.002)], part=DPAD)
    buttons = [Ellipsoid(p, (0.0095, 0.0095, 0.006), part=BUTTON) for p in ((0.072, 0.014, 0.019), (0.092, -0.004, 0.019), (0.066, -0.016, 0.019))]
    hatch = Box((0, -0.004, -0.019), (0.05, 0.03, 0.002), rr=0.002, part=CONSOLE)
    return place(Union([shell, screen, dpad, hatch] + buttons, k=0.0), CON, CON_R)


def pieces():
    import os
    q = float(os.environ.get("FOLK_DRAFT", "1"))          # a draft clay: coarser voxels, quicker looks (FOLK_DRAFT=1.7)
    return [("head", head(), 0.0024 * q), ("mouth", mouth(), 0.0015 * q), ("body", body(), 0.0035 * q), ("shirt", shirt(), 0.0026 * q),
            ("gear", gear(), 0.0022 * q), ("arms", arms(), 0.002 * q), ("shoes", Mirror(shoe()), 0.0025 * q), ("console", console(), 0.0016 * q)]


# ---------------------------------------------------------------------------------------------------- paint

INVADER = ["..X.....X..", "...X...X...", "..XXXXXXX..", ".XX.XXX.XX.", "XXXXXXXXXXX", "X.XXXXXXX.X", "X.X.....X.X", "...XX.XX..."]


def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.01) * 0.25
    c.col[:] = srgb(128, 128, 128)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 else col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def spk(m, col, amt):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.full((int(m.sum()), 1), amt, F32)], 1)

    def lerp(a, b, t):
        t = np.asarray(t, F32)
        return a + (b - a) * (t[:, None] if t.ndim else t)

    # skin: periwinkle, lighter on the planes that face up, the chiselled edges rubbed light, coral paint splotches
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(96, 94, 192), (n, 3)).copy()
    sk = lerp(sk, srgb(124, 120, 214), smooth(0.2, 0.9, c.N[:, 2]) * 0.6)
    sk *= (1.0 + 0.07 * mott)[:, None]
    sk = lerp(sk, srgb(150, 146, 226), c.wear * 0.5)
    wq = Q + np.stack([noise3(Q + 1.7, 0.06), noise3(Q + 4.2, 0.06), noise3(Q + 8.9, 0.06)], 1) * 0.03
    spl = noise3(wq + 3.1, 0.045) * 0.75 + noise3(Q, 0.007) * 0.25
    splotch = smooth(0.31, 0.35, spl) * smooth(-0.25, 0.2, noise3(Q + 11.0, 0.14))
    sk = lerp(sk, srgb(222, 112, 104), splotch * 0.9)
    sk = lerp(sk, srgb(70, 60, 110), smooth(0.2, 0.9, noise3(P + 7.0, 0.05)) * 0.25)          # grime
    # the mouth's inside: dark
    inside = m & (np.abs(x) < 0.13) & (np.abs(z - MZ) < 0.03) & (y > -0.205) & (y < -0.1)
    sk[inside] = srgb(46, 14, 24)
    put(m, sk, 0.55, bump=0.15)
    spk(m, (232, 132, 112), 0.18)

    # the eye: cream going peach to the rim, red veins, a tall black pupil aimed at the screen, a glint
    m = c.mask(EYE)
    el = ((P - EYE_C) @ HEAD_R) / EYE_RAD
    d = el / np.maximum(np.linalg.norm(el, axis=1), 1e-6)[:, None]
    g = HEAD_R.T @ ((CON + CON_R @ v3((0, 0.01, 0))) - EYE_C)
    g = g / EYE_RAD
    g /= np.linalg.norm(g)
    g = g * 0.45 + v3((0.0, -1.0, 0.0)) * 0.55          # the pupil sits low and centred: it reads as looking down at the screen, not as a mouth
    g /= np.linalg.norm(g)
    ang = np.arccos(np.clip(d @ g, -1, 1))
    fwd = np.arccos(np.clip(d @ v3((0, -1, 0)), -1, 1))
    ey = lerp(np.broadcast_to(srgb(244, 214, 160), (n, 3)), srgb(236, 176, 124), smooth(0.4, 1.1, fwd))
    ey = lerp(ey, srgb(214, 120, 96), smooth(0.85, 1.3, fwd))
    ey = lerp(ey, srgb(150, 66, 50), smooth(1.25, 1.5, fwd) * 0.8)
    vein = 1.0 - np.abs(noise3(P * v3((1, 1, 0.7)), 0.02) * 0.8 + noise3(P, 0.007) * 0.2)
    ey = lerp(ey, srgb(196, 52, 44), smooth(0.93, 0.985, vein) * smooth(0.55, 1.1, fwd) * 0.85)
    e1 = np.cross(v3((0, 0, 1)), g)
    e1 /= np.linalg.norm(e1)
    e2 = np.cross(g, e1)
    a_, b_ = d @ e1, d @ e2
    pup = np.sqrt((a_ / 0.12) ** 2 + (b_ / 0.3) ** 2)
    c.draw(m & (d @ g > 0.4), (pup - 1.0) * 0.012, 0.0)
    ring = m & (d @ g > 0.4) & (pup < 1.6)
    ey = np.where(ring[:, None], ey * (0.75 + 0.25 * smooth(1.05, 1.6, pup))[:, None], ey)
    gl = smooth(0.012, 0.003, (d[:, 0] - 0.30) ** 2 + (d[:, 2] - 0.45) ** 2) * (d[:, 1] < 0)
    gl2 = smooth(0.0016, 0.0005, (a_ - 0.035) ** 2 + (b_ - 0.13) ** 2)          # the glint on the pupil itself: it reads as a wet eye
    c.ink[m & (gl2 > 0.35), 2] = 0.0                       # lift the pupil's ink where the glint sits
    ey = lerp(ey, srgb(255, 252, 240), np.maximum(gl, gl2))
    put(m, ey, 0.08)

    # lips: rose pink, darker into the parting and the corners, the lower lip catching the light
    m = c.mask(LIP_U, LIP_L)
    lp = np.broadcast_to(srgb(222, 112, 146), (n, 3)).copy()
    lp = lerp(lp, srgb(150, 56, 90), smooth(0.012, 0.0, np.abs(z - MZ)) * 0.7)
    lp = lerp(lp, srgb(170, 70, 104), smooth(0.09, 0.145, np.abs(x)))
    lp = lerp(lp, srgb(246, 170, 190), c.mask(LIP_L) * smooth(MZ - 0.035, MZ - 0.022, z) * smooth(MZ - 0.005, MZ - 0.02, z) * 0.6)
    put(m, lp, 0.22, bump=0.1)
    m = c.mask(TOOTH_U, TOOTH_L)
    tt = lerp(np.broadcast_to(srgb(232, 208, 130), (n, 3)), srgb(160, 120, 60), smooth(0.4, 0.9, noise3(P, 0.008)) * 0.35)
    put(m, tt, 0.35)

    # the shirt: worn cream cotton, grubby, paint-flecked, the skull print cracked; its torn hem dirtier
    m = c.mask(SHIRT)
    st = np.broadcast_to(srgb(226, 216, 198), (n, 3)).copy()
    st *= (1.0 + 0.05 * mott)[:, None]
    st = lerp(st, srgb(170, 140, 108), smooth(0.25, 0.75, noise3(P + 2.0, 0.045)) * 0.45)
    st = lerp(st, srgb(150, 120, 92), smooth(0.56, 0.5, z) * 0.5)
    pz = 0.585
    r = np.sqrt(x ** 2 + (z - pz) ** 2)
    th = np.arctan2(z - pz, x)
    front = (y < -0.05)
    cog = 0.076 + 0.007 * np.clip(np.sin(th * 12.0) * 3.0, -1.0, 1.0)
    disk = front & (r < cog)
    skull = (np.sqrt(x ** 2 + ((z - pz - 0.01) / 1.05) ** 2) < 0.033) | ((np.abs(x) < 0.021) & (z > pz - 0.031) & (z < pz - 0.006))
    sockets = (np.sqrt((np.abs(x) - 0.0135) ** 2 + (z - pz - 0.005) ** 2) < 0.0105) | ((np.abs(x) < 0.005) & (z < pz - 0.006) & (z > pz - 0.016))
    bone = np.minimum(np.abs((x - (z - pz)) / 1.414), np.abs((x + (z - pz)) / 1.414))
    bones = (bone < 0.0075) & (r > 0.036) & (r < 0.06)
    white = (skull & ~sockets) | bones
    crack = smooth(0.3, 0.42, noise3(P * v3((1, 1, 1)), 0.006) * 0.6 + noise3(P, 0.02) * 0.4)
    st = np.where((disk & ~white)[:, None], lerp(srgb(176, 44, 40) * np.ones((n, 3), F32), st, crack * 0.6), st)
    st = np.where((front & white & (r < 0.07))[:, None], lerp(srgb(240, 232, 214) * np.ones((n, 3), F32), st, crack * 0.4), st)
    put(m, st, 0.88, bump=1.0, grain=0.0)
    spk(m, (196, 138, 64), 0.32)

    # the apron: tan canvas, stained, splashed with yellow-orange paint; the tools
    m = c.mask(CANVAS)
    cv = np.broadcast_to(srgb(176, 132, 82), (n, 3)).copy()
    cv *= (1.0 + 0.08 * mott)[:, None]
    cv = lerp(cv, srgb(110, 78, 44), smooth(0.2, 0.8, noise3(P + 5.0, 0.04)) * 0.5)
    cv = lerp(cv, srgb(214, 178, 128), c.wear * 0.5)
    pnt = smooth(0.38, 0.44, noise3(P + 9.0, 0.02) * 0.7 + noise3(P, 0.006) * 0.3)
    cv = lerp(cv, srgb(232, 170, 50), pnt * 0.9)
    put(m, cv, 0.85, bump=1.0, grain=0.0)
    spk(m, (226, 168, 52), 0.4)
    put(c.mask(METAL), (srgb(196, 198, 204) * (1.0 - 0.5 * c.cavity)[:, None]), 0.3, metal=1.0, grain=1.0, bump=0.05)
    m = c.mask(RED)
    rd = np.broadcast_to(srgb(182, 26, 30), (n, 3)).copy()
    rd = np.where((np.abs(np.sin(z * 260.0)) > 0.92)[:, None], rd * 0.4, rd)
    put(m, rd, 0.25)
    m = c.mask(RAG)
    put(m, lerp(np.broadcast_to(srgb(234, 224, 216), (n, 3)), srgb(196, 120, 120), smooth(0.2, 0.6, noise3(P + 4.0, 0.015)) * 0.6), 0.9, bump=1.0)

    # the high-tops: navy canvas, a cream star on the outside of the ankle, cream rubber, all of it muddy
    m = c.mask(SHOE)
    sh = np.broadcast_to(srgb(58, 66, 118), (n, 3)).copy()
    sh *= (1.0 + 0.1 * mott)[:, None]
    sh = lerp(sh, srgb(120, 120, 150), c.wear * 0.6)
    an = v3((ANKLE[0], ANKLE[1], 0.0))
    rel = Q - an
    outv = np.cross(FWD, v3((0, 0, 1)))
    outv = -outv if outv[0] < 0 else outv
    u = rel @ np.cross(v3((0, 0, 1)), outv)
    zz = z - 0.135
    sr = np.sqrt(u ** 2 + zz ** 2)
    sa = np.arctan2(zz, u)
    star = sr < 0.032 * (0.55 + 0.45 * np.cos(5 * (sa - np.pi / 2))) ** 2.2 + 0.012
    star &= (rel @ outv > 0.03)
    sh = np.where(star[:, None], srgb(232, 222, 200), sh)
    put(m, sh, 0.85, bump=1.0)
    spk(m, (132, 96, 62), 0.35)
    m = c.mask(RUBBER)
    rb = np.broadcast_to(srgb(228, 216, 192), (n, 3)).copy()
    rb = lerp(rb, srgb(150, 118, 84), smooth(0.03, 0.0, z) * 0.6 + smooth(0.3, 0.7, noise3(P + 1.0, 0.025)) * 0.3)
    put(m, rb, 0.7, bump=0.3, grain=1.0)
    spk(m, (138, 92, 56), 0.55)
    put(c.mask(LACE), srgb(236, 228, 208), 0.8, bump=0.6)

    # the console: grey-beige plastic, grimy, rust-brown blotches; the screen's invader; red buttons
    cl = (P - CON) @ CON_R
    m = c.mask(CONSOLE)
    co = np.broadcast_to(srgb(176, 168, 154), (n, 3)).copy()
    co = lerp(co, srgb(132, 86, 56), smooth(0.36, 0.44, noise3(P + 6.0, 0.012)) * 0.7)
    co = lerp(co, srgb(214, 208, 196), c.wear * 0.5)
    put(m, co, 0.5, bump=0.2, grain=1.0)
    spk(m, (110, 70, 44), 0.3)
    m = c.mask(SCREEN)
    sc = np.broadcast_to(srgb(36, 52, 26), (n, 3)).copy()
    px, py = 0.0058, 0.0058
    gx = np.floor((cl[:, 0] + 5.5 * px) / px).astype(int)
    gy = np.floor((-(cl[:, 1] - 0.012) + 4.0 * py) / py).astype(int)
    lit = np.zeros(n, bool)
    ok = (gx >= 0) & (gx < 11) & (gy >= 0) & (gy < 8)
    for k in np.nonzero(ok)[0]:
        lit[k] = INVADER[gy[k]][gx[k]] == "X"
    sc = np.where(lit[:, None], srgb(206, 214, 60), sc)
    put(m, sc, 0.1)
    put(c.mask(BUTTON), srgb(196, 44, 40) * np.ones((n, 3), F32), 0.3)
    put(c.mask(DPAD), srgb(40, 40, 44) * np.ones((n, 3), F32), 0.5)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 1700, "mouth": 650, "body": 2100, "shirt": 1000, "gear": 900, "arms": 850, "shoes": 1000, "console": 420},
    "density": {"head": 1.6, "mouth": 1.6, "shirt": 1.2, "console": 1.4},
    "tex": 2048,
    "stride": {"walk": 0.56, "run": 0.95},
    "speed": 0.72,
    "look": ["head"], "neck": "neck",
    "look_pivot": tuple(HB.tolist()),
    "radius": 0.36,
}


def rig_bones():
    from kit.rig import Bone, mirror
    hand_end = CON + CON_R @ v3((-0.135, -0.012, -0.004))
    toe = v3((ANKLE[0], ANKLE[1], 0.03)) + FWD * 0.2
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.035, 0.34), (0, 0.02, 0.45), "root", 0.17),
        Bone("spine", (0, 0.02, 0.45), (0, 0.03, 0.57), "hips", 0.18),
        Bone("jaw", (0, -0.13, MZ), (0, -0.22, MZ - 0.02), "spine", 0.02),
        Bone("chest", (0, 0.03, 0.57), (0, 0.04, 0.67), "spine", 0.16),
        Bone("neck", (0, 0.035, 0.65), hw((0, 0.02, 0.02)), "chest", 0.07),
        Bone("head", HB, hw((0, -0.02, 0.42)), "neck", 0.15),
        Bone("console", (0, 0.03, 0.62), CON, "chest", 0.03),          # swings the console about the chest: raise it, tip it
        Bone("shoulder.L", (0.05, 0.03, 0.635), SHOULDER, "chest", 0.05),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.03),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.025),
        Bone("hand.L", WRIST, hand_end, "forearm.L", 0.02),
        Bone("thigh.L", HIP, KNEE, "hips", 0.085),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.07),
        Bone("foot.L", ANKLE, toe, "shin.L", 0.05),
    ])


def skin_rules(P, part, piece, names):
    """pieces: 0 head, 1 mouth, 2 body, 3 shirt, 4 gear, 5 arms, 6 shoes, 7 console"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, z = P[:, 0], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    # head: the block rigid, the neck bends from the collar
    hp = piece == 0
    hl = (P - HB) @ HEAD_R
    allow(hp, "chest", "neck", "head")
    rig[hp & (hl[:, 2] > 0.02)] = ix["head"]
    # mouth: the upper lip and teeth ride the belly, the lower ones the jaw
    mp = piece == 1
    allow(mp, "spine")
    rig[mp & np.isin(part, (LIP_U, TOOTH_U))] = ix["spine"]
    rig[mp & np.isin(part, (LIP_L, TOOTH_L))] = ix["jaw"]
    # body: legs and trunk
    bp = piece == 2
    legs = bp & (((np.abs(x) > 0.12) & (z < 0.40)) | (z < 0.28))
    allow(legs, "hips")
    allow(legs & (x > -0.02), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.02), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs
    allow(torso, "hips", "spine", "chest", "neck")
    # the shirt: on the trunk, its sleeves on the arms
    sp = piece == 3
    allow(sp, "spine", "chest", "neck")
    allow(sp & (z < 0.54), "hips")
    allow(sp & (x > 0.15) & (z > 0.52), "shoulder.L", "upper_arm.L")
    allow(sp & (x < -0.15) & (z > 0.52), "shoulder.R", "upper_arm.R")
    # the apron and its tools hang from the hips
    gp = piece == 4
    allow(gp, "hips", "spine")
    rig[gp & (z < 0.31)] = ix["hips"]
    # arms: the hands rigid round the console
    ap = piece == 5
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    ql = (Q - CON) @ CON_R
    for s, sd in ((1, "L"), (-1, "R")):
        m = ap & (x * s > 0)
        allow(m, "shoulder." + sd, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        rig[m & (ql[:, 1] > WRIST_C[1] + 0.006)] = ix["hand." + sd]
    # shoes: the sole and toe rigid on the foot, the high-top shaft bends with the shin
    shp = piece == 6
    for s, sd in ((1, "L"), (-1, "R")):
        m = shp & (x * s > 0)
        allow(m, "foot." + sd)
        rig[m] = ix["foot." + sd]
    rig[piece == 7] = ix["console"]
    allow(piece == 7, "console")
    return A, rig


WALK = dict(stride=0.56, stance=0.6, foot_x=0.33, foot_y=-0.07, lift=0.05, out=0.025, bob=0.016, drop=0.02, sway=0.034, roll=7.0, yaw=6.0,
            lean=4.0, toe_off=10.0, swing_point=4.0)
RUN = dict(stride=0.95, stance=0.42, foot_x=0.31, foot_y=-0.05, lift=0.10, out=0.03, bob=0.035, drop=0.045, sway=0.03, roll=9.0, yaw=8.0,
           lean=13.0, toe_off=18.0, swing_point=8.0)


def motions(rig):
    """walk: a hunched, wide waddle, the body rocking over each foot, the eye locked on the console held up in both hands;
    run: the same at a scurry, leaning in; idle: crouched, mashing buttons, a little win half way through (console up, mouth open)"""
    import math
    from kit.gait import Pose, Leg, R, solve, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], F32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    yr = math.radians(TOE_OUT)

    def foot(p, lg, ball, pitch):
        s = 1.0 if lg.side == "L" else -1.0
        fw = Vector((s * math.sin(yr), -math.cos(yr), 0.0))
        wf = Matrix.Rotation(math.radians(pitch), 3, Vector((0, 0, 1)).cross(fw))
        ankle = ball + wf @ (rig.head[lg.foot] - lg.ball)
        p.ik[lg.thigh] = (ankle, Vector((s * 0.85, -0.5, 0.0)), lg.foot, wf)

    def upper(p, con, head, jaw):
        p.rot("console", *con)
        p.world["head"] = head
        p.rot("jaw", jaw, 0, 0)
        A = solve(rig, p)
        Ac = A["console"]
        W = Ac.to_3x3()
        for s, sd in ((1.0, "L"), (-1.0, "R")):
            w = Vector((WRIST * np.array([s, 1, 1], F32)).tolist())
            p.ik["upper_arm." + sd] = (Ac @ w, Vector((s * 0.9, 0.25, -0.45)), "hand." + sd, W)
        return p

    def waddle(u, g, run):
        p = Pose()
        S, beta = g["stride"], g["stance"]
        p.offset = Vector((g["sway"] * math.sin(TAU * u), 0.0, -g["drop"] + g["bob"] * math.cos(2 * TAU * (u - beta * 0.5))))
        roll = g["roll"] * math.sin(TAU * u)            # the body leans over the foot it stands on
        yaw = -g["yaw"] * math.cos(TAU * u)
        p.rot("hips", g["lean"], roll, yaw)
        p.rot("spine", 0.0, -roll * 0.3, -yaw * 0.45)
        p.rot("chest", 0.0, -roll * 0.2, -yaw * 0.4)
        for lg in legs:
            s = 1.0 if lg.side == "L" else -1.0
            uu = (u + (0.0 if s > 0 else 0.5)) % 1.0
            out = 0.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                lift = 0.0
                pitch = g["toe_off"] * ease((uu - (beta - 0.15)) / 0.15)
            else:
                t = (uu - beta) / (1.0 - beta)
                fy = S * beta / 2 - S * beta * ease(t)
                lift = g["lift"] * math.sin(math.pi * t) ** 0.8
                out = g["out"] * math.sin(math.pi * t)           # the swing foot circles out round the belly: the waddle
                pitch = g["toe_off"] * (1.0 - ease(t * 1.8)) - g["swing_point"] * math.sin(math.pi * t)
            foot(p, lg, Vector((s * (g["foot_x"] + out), fy + g["foot_y"], lift)), pitch)
        b = math.sin(2 * TAU * u + 0.6)
        con = ((4.0 if run else 1.5) * b, -roll * 0.4, 0.0)
        head = R((6.0 if run else 0.0) + (2.0 if run else 1.0) * b, -roll * 0.25, 0.0)
        return upper(p, con, head, 3.0 + 2.5 * math.sin(2 * TAU * u))

    walk = [waddle(i / 32.0, WALK, False) for i in range(33)]
    run = [waddle(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        win = ease((t - 2.3) / 0.35) * (1.0 - ease((t - 3.4) / 0.6))           # a little win: the console up, leaning back, mouth open
        focus = ease((t - 4.2) / 0.5) * (1.0 - ease((t - 5.4) / 0.5))          # a hard bit: leaning right in
        p.offset = Vector((0.012 * math.sin(TAU * t / 6.0), 0.01 * win - 0.008 * focus, -0.006 + 0.004 * math.sin(TAU * t / 1.5) + 0.012 * win))
        p.rot("hips", 2.0 * math.sin(TAU * t / 3.0) - 6.0 * win + 4.0 * focus, 2.0 * math.sin(TAU * t / 6.0), 0.0)
        p.rot("spine", 0.0, -1.0 * math.sin(TAU * t / 6.0), 0.0)
        for lg in legs:
            foot(p, lg, Vector((lg.ball.x, lg.ball.y, 0.0)), 0.0)
        mash = 1.6 * math.sin(TAU * t * 2.6) * math.sin(TAU * t / 6.0 * 3.0) ** 2 * (1.0 - win)
        con = (mash - 14.0 * win + 3.0 * focus, 1.2 * math.sin(TAU * t * 1.3) * (1.0 - win), 0.0)
        head = R(-6.0 * win + 7.0 * focus + 0.8 * math.sin(TAU * t / 3.0), 0.0, 2.0 * math.sin(TAU * t / 6.0))
        idle.append(upper(p, con, head, 2.0 + 16.0 * win + 1.5 * math.sin(TAU * t * 2.0) * (1.0 - win)))
    return {"walk": walk, "run": run, "idle": idle}
