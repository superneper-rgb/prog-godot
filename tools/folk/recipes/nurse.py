## FOINT CITY townsfolk: the nurse. Tall, slim and beige, a long alien face with big heavy-lidded almond eyes and a V of brow running down into the nose, red dreadlocks swept to her right; teal scrubs over a long-sleeved undershirt, an ID badge on a reel, a purple glove poking from a thigh pocket, white sneakers. Holds her clipboard to her chest.
# Concept: the user's sheet, image 4 top right (F:/prog-godot-cache/folk/refs/4.webp). Measured off it: 1.90 m to the top of the skull; the head 0.33 m tall, wide at the
# eyes (0.30) and narrowing to a small chin; a long thin neck; narrow shoulders (0.40), a small waist; long legs (crotch at 0.85); jogger cuffs gathered at 0.2.
# Rest pose = her carrying pose: the clipboard held up against her left chest by the left hand, the right arm hanging.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

F32 = np.float32
HEIGHT = 1.93
REF = ("4.webp", (840, 3, 1042, 391))

(SKIN, EYE, LIP, PLUG, DREAD, SCRUB, UNDER, SHOE, SOLE, STRIPE_P, GLOVE_P, BADGE, CARD, REEL, BOARD, PAPER, CLIP, TAB_R, TAB_Y, TAB_G,
 TAB_B, WATCH, PEN, HAIRBASE) = range(1, 25)
COLOURS = {
    SKIN: ((0.80, 0.62, 0.46), 0.55, 0.0),
    EYE: ((0.25, 0.15, 0.08), 0.15, 0.0),
    LIP: ((0.62, 0.36, 0.32), 0.4, 0.0),
    PLUG: ((0.10, 0.08, 0.08), 0.4, 0.0),
    DREAD: ((0.48, 0.10, 0.20), 0.7, 0.0),
    SCRUB: ((0.22, 0.48, 0.44), 0.8, 0.0),
    UNDER: ((0.80, 0.74, 0.66), 0.85, 0.0),
    SHOE: ((0.90, 0.88, 0.86), 0.6, 0.0),
    SOLE: ((0.82, 0.78, 0.74), 0.7, 0.0),
    STRIPE_P: ((0.45, 0.30, 0.62), 0.6, 0.0),
    GLOVE_P: ((0.55, 0.36, 0.78), 0.4, 0.0),
    BADGE: ((0.20, 0.24, 0.30), 0.4, 0.0),
    CARD: ((0.92, 0.92, 0.90), 0.4, 0.0),
    REEL: ((0.25, 0.25, 0.30), 0.4, 0.3),
    BOARD: ((0.36, 0.22, 0.14), 0.5, 0.0),
    PAPER: ((0.92, 0.90, 0.84), 0.85, 0.0),
    CLIP: ((0.70, 0.70, 0.72), 0.3, 1.0),
    TAB_R: ((0.85, 0.2, 0.2), 0.5, 0.0),
    TAB_Y: ((0.92, 0.80, 0.2), 0.5, 0.0),
    TAB_G: ((0.3, 0.7, 0.3), 0.5, 0.0),
    TAB_B: ((0.25, 0.45, 0.85), 0.5, 0.0),
    WATCH: ((0.15, 0.15, 0.17), 0.4, 0.5),
    PEN: ((0.85, 0.15, 0.15), 0.4, 0.0),
    HAIRBASE: ((0.16, 0.03, 0.07), 0.8, 0.0),
}

# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; the figure faces -Y)
HEAD_C = v3((0.0, 0.03, 1.79))
EYE_C = v3((0.07, -0.088, 1.737))
EYE_R = 0.048
EYE_FWD = v3((0.30, -1.0, 0.0)) / np.linalg.norm((0.30, -1.0, 0.0))
LID_PT = EYE_C + v3((0.0, 0.0, -0.002))
LID_N = v3((0.30, 0.0, -1.0)) / np.linalg.norm((0.30, 0.0, -1.0))       # the heavy upper lid: almost half shut, its edge rising to the outer corner
LOW_PT = EYE_C + v3((0.0, 0.0, -0.023))
LOW_N = v3((-0.28, 0.0, 1.0)) / np.linalg.norm((-0.28, 0.0, 1.0))       # the lower lid's edge, rising to the outer corner too: an almond
EAR_C = v3((0.132, 0.022, 1.69))
MOUTH_Z = 1.613
NECK0 = v3((0.0, 0.012, 1.44))
NECK1 = v3((0.0, 0.0, 1.62))

SHOULDER = v3((0.165, 0.02, 1.405))
R_ELBOW = v3((0.205, 0.04, 1.11))         # the free (right) arm, built on the left and mirrored
R_WRIST = v3((0.222, -0.012, 0.845))
R_HAND = basis(-(R_WRIST - R_ELBOW), v3((0, 1, 0)))
C_ELBOW = v3((0.225, 0.015, 1.115))        # the clipboard (left) arm: elbow by the waist, forearm up and across to the board's edge
C_WRIST = v3((0.245, -0.235, 1.235))
C_HAND = basis(v3((1.0, 0.0, -0.3)), v3((0.0, 0.0, -1.0)))          # fingers curled over the board's outer edge onto its face, thumb up
HIP = v3((0.085, 0.01, 0.90))
KNEE = v3((0.095, -0.012, 0.52))
ANKLE = v3((0.10, 0.02, 0.09))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)

BOARD_C = v3((0.10, -0.175, 1.26))
BOARD_R = rot(rx=-15.0, rz=-22.0)       # board's local X across, Y its face normal (toward -Y = out from her chest), Z up


def prism(poly_xz, y0=-0.6, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def side_prism(poly_yz, x0, x1):
    return Slab(((x0 + x1) * 0.5, 0, 0), poly_yz, (x1 - x0) * 0.5, R=np.array([[0, 0, 1], [1, 0, 0], [0, 1, 0]], np.float32))


def probe(shape, x, z, y0=-0.6, y1=0.4, step=0.0015):
    ys = np.arange(y0, y1, step, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    i = int(np.argmax(d < 0))
    if d[i] >= 0 or i == 0:
        raise ValueError("no surface at x %.3f z %.3f" % (x, z))
    return float(ys[i - 1] + (ys[i] - ys[i - 1]) * d[i - 1] / (d[i - 1] - d[i]))


def on(shape, x, z, inset=0.0):
    return v3((x, probe(shape, x, z) + inset, z))


class Crease(Shape):
    """a Bump along a polyline (mirrored to both sides) that only evaluates near the line: `amp` < 0 cuts a crease, > 0 raises a ridge"""
    def __init__(self, child, pts, width, amp, mirror=True):
        self.child, self.w, self.amp, self.mirror = child, F32(width), F32(amp), mirror
        self.pts = [v3(p) for p in pts]
        self.lo, self.hi = child.bound()
        self.part = child.part
        a = np.array(self.pts)
        self.blo, self.bhi = a.min(0) - width, a.max(0) + width

    def eval(self, P):
        d, pt = self.child.eval(P)
        Q = P.copy()
        if self.mirror:
            Q[:, 0] = np.abs(Q[:, 0])
        m = np.all((Q >= self.blo) & (Q <= self.bhi), axis=1)
        if m.any():
            q = Q[m]
            dm = np.full(len(q), 1e3, np.float32)
            for a, b in zip(self.pts[:-1], self.pts[1:]):
                ab = b - a
                t = np.clip(((q - a) @ ab) / float(ab @ ab), 0.0, 1.0)
                dm = np.minimum(dm, np.linalg.norm(q - a - np.outer(t, ab), axis=1))
            x = np.clip(1.0 - dm / self.w, 0.0, 1.0)
            d[m] -= self.amp * x * x * (3.0 - 2.0 * x)
        return d, pt

    def dist(self, P):
        return self.eval(P)[0]


class Bounded(Shape):
    """the child with a tighter box than its own: unions skip it outside the box"""
    def __init__(self, child, lo, hi):
        self.child = child
        self.lo, self.hi = v3(lo), v3(hi)
        self.part = child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.child.eval(P)[0]


# ---------------------------------------------------------------------------------------------------- the head
def skull():
    """a high domed skull, wide at the eyes, the face narrowing down a long jaw to a small chin"""
    return Union([
        Ellipsoid(HEAD_C, (0.152, 0.142, 0.14), R=rot(rx=-12)),                # cranium: a wide high bulb, wider than the jaw, leaning back (round 2)
        Ellipsoid((0.0, -0.05, 1.735), (0.142, 0.078, 0.07)),                 # the wide band of the eyes
        Mirror(Ellipsoid((0.074, -0.068, 1.66), (0.064, 0.06, 0.062))),       # full young cheeks, no hollow under the cheekbones (rounds 2-3)
        Ellipsoid((0.0, -0.058, 1.655), (0.108, 0.072, 0.074)),               # the lower face
        Ellipsoid((0.0, -0.083, 1.585), (0.04, 0.042, 0.04)),
        Ellipsoid((0.0, -0.095, 1.556), (0.022, 0.026, 0.02)),                # the small chin
    ], k=0.05, part=SKIN)


def face_shape():
    sk = skull()
    lid = Clip(Ellipsoid(EYE_C + v3((0, -0.001, 0.002)), (0.0525, 0.0515, 0.052), part=SKIN), [Half(LID_PT, LID_N)], k=0.006)
    lower = Clip(Ellipsoid(EYE_C + v3((0, -0.0005, -0.001)), (0.0508, 0.0502, 0.0505), part=SKIN), [Half(LOW_PT, LOW_N)], k=0.006)
    face = Union([sk, Mirror(lid), Mirror(lower)], k=0.01)
    # the brow: a V of two ridges from over the eyes down into a long narrow nose bridge, ending in a small rounded tip
    nose = Union([
        RoundCone((0.0, -0.1, 1.795), (0.0, -0.138, 1.678), 0.026, 0.013),
        Ellipsoid((0.0, -0.143, 1.668), (0.016, 0.014, 0.012)),
        Mirror(Ellipsoid((0.011, -0.135, 1.664), (0.009, 0.009, 0.008))),
    ], k=0.012, part=SKIN)
    face = Union([face, nose], k=0.012)
    nostrils = Mirror(Ellipsoid((0.0085, -0.144, 1.6585), (0.0035, 0.0045, 0.0028), R=rot(rx=30), part=SKIN))
    face = Cut(face, [nostrils], k=0.0015)
    return face


def ear():
    shell = Ellipsoid(EAR_C, (0.012, 0.024, 0.032), R=rot(rz=-15), part=SKIN)
    bowl = Ellipsoid(EAR_C + v3((0.01, -0.004, 0.002)), (0.008, 0.016, 0.022), R=rot(rz=-15), part=SKIN)
    e = Cut(shell, [bowl], k=0.004)
    plug = CappedCone(EAR_C + v3((0.004, -0.004, -0.02)), EAR_C + v3((0.016, -0.004, -0.02)), 0.0085, 0.0085, rr=0.002, part=PLUG)
    return Mirror(Union([e, plug], k=0.0))


def hair_cap():
    """round 4: the crown is dreadlocks, not a cap: short thick locks (2-2.5 cm, each its own rounded tube) rooted along the parting and lying back
    and out over the skull, packed in two rows a side over a dark base so no scalp shows between them; their ends lift off the head and stick up
    and out, so the top of the silhouette breaks up and the crown and the long spray read as one set of dreads"""
    Rc = rot(rx=-12)
    rad = np.array([0.152, 0.142, 0.14], np.float32)
    base = Clip(Inflate(Ellipsoid(HEAD_C, tuple(rad), R=Rc), 0.005, part=HAIRBASE), [Half(v3((0, 0, 1.83)), (0.0, -0.6, -1.0))], k=0.02)

    def on_skull(d, lift):
        d = v3(d) / np.linalg.norm(d)
        p = HEAD_C + Rc @ (d * rad)
        nrm = Rc @ (d / rad)
        nrm /= np.linalg.norm(nrm)
        return p + nrm * lift, nrm
    locks = [base]
    rng = np.random.RandomState(21)
    for side in (-1.0, 1.0):
        for row, (x0, x1) in enumerate(((0.05, 0.45), (0.38, 0.85))):
            n = 7 if row == 0 else 6
            for i in range(n):
                t = (i + 0.5 * row) / n
                yy = -0.55 + 1.25 * t
                r = 0.0115 + 0.0028 * rng.rand()
                d0 = v3((side * (x0 + 0.04 * rng.randn()), yy, 0.95 - 0.25 * t))
                d1 = v3((side * (x1 + 0.08 * rng.rand()), yy + 0.35 + 0.15 * rng.rand(), 0.55 - 0.45 * t - 0.15 * row))
                L = 0.8 + 0.4 * rng.rand()
                pts = []
                for k in range(4):
                    u = k / 3.0 * L
                    q, nrm = on_skull(d0 * (1 - min(u, 1.0)) + d1 * min(u, 1.0), r * 0.7)
                    pts.append((q, r * (1.0 - 0.06 * k)))
                q_end, nrm = pts[-1][0], on_skull(d1, 0.0)[1]
                tip = q_end + nrm * (0.022 + 0.02 * rng.rand()) + v3((side * 0.012, 0.012, 0.004))
                pts.append((tip, r * 0.9))
                locks.append(loft([(v3(q), rr) for q, rr in pts], part=DREAD, k=0.004))
                locks.append(Sphere(tip, r * 1.05, part=DREAD))
    # the front row: locks rooted at the hairline, lying back up over the brow of the skull, their ends standing up off the crown
    for i in range(10):
        xx = -0.85 + 1.7 * i / 9.0 + 0.04 * rng.randn()
        r = 0.0115 + 0.0028 * rng.rand()
        d0 = v3((xx, -0.85, 0.5 + 0.1 * abs(xx)))
        d1 = v3((xx * 1.15, -0.05 + 0.15 * rng.rand(), 1.0))
        pts = []
        for k in range(4):
            u = k / 3.0
            q, nrm = on_skull(d0 * (1 - u) + d1 * u, r * 0.7)
            pts.append((q, r * (1.0 - 0.05 * k)))
        nrm = on_skull(d1, 0.0)[1]
        tip = pts[-1][0] + nrm * (0.025 + 0.02 * rng.rand()) + v3((0.01 * xx, 0.015, 0.0))
        pts.append((tip, r * 0.9))
        locks.append(loft([(v3(q), rr) for q, rr in pts], part=DREAD, k=0.004))
        locks.append(Sphere(tip, r * 1.05, part=DREAD))
    return Union(locks, k=0.004)          # sunk into the dark base and filleted to it: one surface, so it decimates to its budget


def dreads():
    """red dreadlocks (round 3): a cap over the whole top of the skull, the locks growing from a parting along the crown and sweeping up, back and
    out to both sides in a spray, longer and fuller to her right, a few falling past the shoulders; paler fat tips"""
    Rc = rot(rx=-12)
    rad = np.array([0.152, 0.142, 0.14], np.float32)
    locks = []
    rng = np.random.RandomState(7)

    def surf(d):
        d = v3(d) / np.linalg.norm(d)
        return HEAD_C + Rc @ (d * rad), Rc @ d
    for side in (-1.0, 1.0):
        n = 13 if side < 0 else 10
        for i in range(n):
            t = i / (n - 1.0)
            # roots along the parting: from the front of the crown to its back, a little to this side
            d = v3((side * (0.22 + 0.25 * rng.rand()), -0.45 + 1.1 * t, 0.95 - 0.35 * t))
            root, nrm = surf(d)
            out = v3((side * (0.55 + 0.25 * rng.rand()), 0.45 + 0.3 * t, 0.55 - 0.3 * t))
            out /= np.linalg.norm(out)
            long_ = side < 0 and rng.rand() < 0.65 or t > 0.7
            drop = (1.47 + 0.1 * rng.rand()) if long_ else (1.64 + 0.08 * rng.rand())
            p1 = root + out * 0.035 + nrm * 0.01
            p2 = p1 + v3((side * 0.05, 0.04, -0.005))
            p3 = v3((p2[0] + side * 0.03, p2[1] + 0.02, (p2[2] + drop) * 0.5))
            p4 = v3((p3[0] + side * (0.01 + 0.02 * rng.rand()), p3[1] + 0.01, drop))
            r = 0.0108 + 0.0022 * rng.rand()
            locks.append(loft([(root, r), (p1, r), (p2, r * 0.97), (p3, r * 0.93), (p4, r)], part=DREAD, k=0.006))
            locks.append(Ellipsoid(p4 + v3((0, 0, -0.008)), (r * 1.25, r * 1.25, r * 1.8), part=DREAD))
    # a few short ones flicking up and back off the crown
    for x, yy in ((-0.03, -0.2), (0.03, 0.1), (-0.06, 0.4)):
        root, nrm = surf((x, yy, 1.0))
        locks.append(loft([(root, 0.011), (root + nrm * 0.05 + v3((0, 0.03, 0)), 0.0105), (root + nrm * 0.07 + v3((0, 0.07, -0.02)), 0.011)], part=DREAD, k=0.005))
    return Union(locks, k=0.004)


def head():
    face = Union([face_shape(), ear()], k=0.008)
    # round 2: a fuller neck, webbed up under the jaw (a thin neck under the wide head left a crease the bake missed: a white smear)
    neck = Union([RoundCone(NECK0, NECK1, 0.047, 0.042, part=SKIN), Ellipsoid((0.0, -0.035, 1.6), (0.06, 0.055, 0.045), part=SKIN),
                  Mirror(RoundCone((0.018, -0.02, 1.47), (0.012, -0.04, 1.585), 0.0065, 0.006, part=SKIN))], k=0.01)
    face = Union([face, neck], k=0.045)
    base = face
    # the brow's V: ridges raised along the top of each lid, running in to the bridge
    vbrow = [on(base, x, z, 0.003) for x, z in ((0.012, 1.775), (0.04, 1.788), (0.07, 1.79), (0.092, 1.784), (0.106, 1.772))]
    face = Crease(face, vbrow, 0.008, 0.0028)
    face = Crease(face, [p + v3((0.0, 0.0, 0.011)) for p in vbrow[1:4]], 0.004, -0.0012)
    # a small mouth with thin lips, its right corner (her left) drawn up a little
    xs = np.linspace(-0.04, 0.04, 9)
    mz = MOUTH_Z + 0.004 * (xs / 0.04) ** 2 + 0.009 * np.clip(xs / 0.04, 0, 1) ** 1.5     # round 3: a confident closed smirk, her left corner up
    pts = [on(base, x, z) for x, z in zip(xs, mz)]
    lips = Union([loft([(p + v3((0, 0.0045, 0.0034)), 0.0036 * (1 - 0.6 * (abs(p[0]) / 0.04) ** 2)) for p in pts], part=LIP, k=0.003),
                  loft([(p + v3((0, 0.004, -0.0042)), 0.0044 * (1 - 0.6 * (abs(p[0]) / 0.04) ** 2)) for p in pts], part=LIP, k=0.003)], k=0.003)
    face = Union([face, lips], k=0.004)
    slit = loft([(p + v3((0, -0.001, 0.0)), 0.0012) for p in pts], k=0.001)
    face = Cut(face, [slit], k=0.001)
    face = Crease(face, [on(base, 0.044, 1.624, 0.001), on(base, 0.048, 1.618, 0.001)], 0.0035, -0.0008, mirror=False)      # only the smirk's dimple
    ball = Mirror(Sphere(EYE_C, EYE_R, part=EYE))
    return Union([face, ball], k=0.0)


# ---------------------------------------------------------------------------------------------------- the body
def core():
    """slim: a small bust, a narrow waist, the hips (the scrubs and trousers are this grown)"""
    return Union([
        Ellipsoid((0, 0.012, 1.29), (0.135, 0.092, 0.13)),
        Ellipsoid((0, 0.02, 1.393), (0.15, 0.075, 0.052)),            # round 3: shoulders a touch higher, the neck about 10% shorter
        Mirror(Ellipsoid((0.052, -0.04, 1.27), (0.05, 0.045, 0.045))),
        Ellipsoid((0, 0.01, 1.11), (0.112, 0.08, 0.1)),
        Ellipsoid((0, 0.012, 0.96), (0.152, 0.104, 0.105)),
    ], k=0.055, part=UNDER)


def legs_core():
    return Mirror(loft([(HIP, 0.088), (KNEE, 0.076), (ANKLE + v3((0, 0, 0.17)), 0.068)], k=0.03))


def hand(curl=0.3):
    """a long-fingered hand in hand space (wrist at the origin, fingers along -Z, back +X, thumb -Y)"""
    palm = Ellipsoid((0.0, 0.0, -0.04), (0.013, 0.031, 0.042), part=SKIN)
    wrist = RoundCone((0, 0, 0.03), (0, 0, -0.02), 0.024, 0.022, part=SKIN)
    parts = [palm, wrist]
    for f in (-0.021, -0.007, 0.007, 0.021):
        L = 1.0 - abs(f) * 7
        a = -0.08 - 0.03 * L
        pts = [((0.0, f, -0.072), 0.0078), ((-0.004 * curl * 3, f * 1.05, a), 0.0072), ((-0.012 * curl * 3, f * 1.08, a - 0.026 * L), 0.0064), ((-0.02 * curl * 3, f * 1.1, a - 0.045 * L), 0.0056)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.003))
    parts.append(loft([(v3((-0.006, -0.026, -0.02)), 0.009), (v3((-0.016, -0.04, -0.05)), 0.008), (v3((-0.026, -0.038, -0.075)), 0.007)], part=SKIN, k=0.003))
    return Union(parts, k=0.007)


def arm(elbow, wrist, frame, curl):
    """(scrub sleeve, undershirt sleeve and bare forearm and hand)"""
    d = (wrist - elbow) / np.linalg.norm(wrist - elbow)
    upper = loft([(SHOULDER, 0.042), (elbow, 0.034)], part=UNDER, k=0.01)
    fore = loft([(elbow, 0.034), (elbow + (wrist - elbow) * 0.55, 0.031)], part=UNDER, k=0.01)
    push = Torus(elbow + (wrist - elbow) * 0.55, 0.031, 0.007, Rm=basis(d, v3((0, 1, 0)) if abs(d[1]) < 0.9 else v3((1, 0, 0))), part=UNDER)
    bare = RoundCone(elbow + (wrist - elbow) * 0.5, wrist, 0.027, 0.022, part=SKIN)
    ua = (elbow - SHOULDER) / np.linalg.norm(elbow - SHOULDER)
    sleeve = Clip(Inflate(loft([(SHOULDER, 0.042), (elbow, 0.034)], k=0.01), 0.011, part=SCRUB), [Half(SHOULDER + ua * 0.15, ua)], k=0.004)
    hn = place(hand(curl), wrist, frame)
    return sleeve, Union([upper, fore, push], k=0.008), Union([bare, hn], k=0.008)


def sneaker():
    heel = ANKLE + v3((0.0, 0.05, -0.05))
    toe = ANKLE + v3((0.004, -0.19, -0.06))
    foot = loft([(heel, 0.043), (ANKLE + v3((0.002, -0.09, -0.045)), 0.047), (toe, 0.034)], k=0.02)
    collar = RoundCone(ANKLE + v3((0, 0.01, -0.03)), ANKLE + v3((0, 0.0, 0.035)), 0.048, 0.044)
    up = Union([foot, collar], k=0.03, part=SHOE)
    up = Clip(up, [Half((0, 0, 0.03), (0, 0, -1)), Half(ANKLE + v3((0, 0, 0.04)), (0, 0.3, 1))], k=0.004)
    sole = Clip(Inflate(foot, 0.008, part=SOLE), [Half((0, 0, 0.038), (0, 0, 1)), Half((0, 0, 0.0), (0, 0, -1))], k=0.003)
    tongue = RoundCone(ANKLE + v3((0, -0.06, 0.0)), ANKLE + v3((0, -0.035, 0.05)), 0.024, 0.02, part=SHOE)
    laces = [Box(ANKLE + v3((0, -0.055 - 0.02 * i, -0.004 - 0.009 * i)), (0.024, 0.004, 0.003), rr=0.002, R=rot(rx=-35), part=SOLE) for i in range(4)]
    return Union([up, sole, tongue] + laces, k=0.0)


def body():
    co = core()
    sl_r, us_r, h_r = arm(R_ELBOW, R_WRIST, R_HAND, 0.25)
    sl_c, us_c, h_c = arm(C_ELBOW, C_WRIST, C_HAND, 0.55)
    under = Union([co, us_c, Move(us_r, R=FLIP)], k=0.015, part=UNDER)
    # the scrub top: V-neck, short sleeves, a hem over the hips, side slits; a chest pocket on her left
    top = Inflate(co, 0.011, part=SCRUB)
    top = Clip(top, [Half((0, 0, 0.885), (0, 0, -1))], k=0.004)
    top = Cut(top, [prism([(-0.075, 1.5), (0.075, 1.5), (0.0, 1.265)]), Ellipsoid((0, 0.02, 1.455), (0.064, 0.072, 0.05))], k=0.004)
    top = Union([top, sl_c, Move(sl_r, R=FLIP)], k=0.012, part=SCRUB)
    pocket = Clip(Inflate(co, 0.016, part=SCRUB), [prism([(0.04, 1.19), (0.115, 1.19), (0.115, 1.255), (0.04, 1.255)])], k=0.002)
    trim = Clip(Cut(Inflate(co, 0.0155, part=SCRUB), [Inflate(co, 0.009)]), [prism([(-0.088, 1.5), (0.088, 1.5), (0.0, 1.245), (0.0, 1.275), (0.062, 1.5), (-0.062, 1.5), (0.0, 1.275), (0.0, 1.245)])], k=0.002)
    # joggers: loose legs, a cargo pocket on her right thigh, gathered cuffs
    pants = Union([Clip(Inflate(co, 0.007), [Half((0, 0, 1.06), (0, 0, 1))]), legs_core()], k=0.05, part=SCRUB)
    pants = Clip(pants, [Half((0, 0, 0.165), (0, 0, -1))], k=0.004)

    def folds(P):
        return noise3(P * np.array([1.0, 1.0, 0.4], np.float32), 0.03) * (P[:, 2] < 0.85)
    pants = Bump(pants, folds, 0.004)
    cuff = Mirror(Clip(Union([RoundCone(ANKLE + v3((0, 0, 0.07)), ANKLE + v3((0, 0, 0.16)), 0.043, 0.047)]), [Half((0, 0, 0.165), (0, 0, 1)), Half((0, 0, 0.11), (0, 0, -1))], k=0.004))
    cuff = Inflate(cuff, 0.0, part=SCRUB)
    cargo = Clip(Inflate(legs_core(), 0.012, part=SCRUB), [side_prism([(-0.065, 0.56), (0.05, 0.56), (0.05, 0.74), (-0.065, 0.74)], -0.4, -0.12)], k=0.003)
    shoes = Mirror(sneaker())
    return Union([under, top, pocket, trim, pants, cuff, cargo, shoes, h_c, Move(h_r, R=FLIP)], k=0.0)


def clipboard():
    R = BOARD_R
    c = BOARD_C
    board = Box(c, (0.118, 0.006, 0.165), rr=0.005, R=R, part=BOARD)
    paper = Box(c + R @ v3((-0.004, -0.007, -0.012)), (0.105, 0.0015, 0.148), rr=0.001, R=R, part=PAPER)
    clip = Union([Box(c + R @ v3((0.0, -0.009, 0.148)), (0.042, 0.005, 0.016), rr=0.004, R=R, part=CLIP),
                  Torus(c + R @ v3((0.0, -0.012, 0.168)), 0.016, 0.0035, Rm=R @ rot(rx=90), part=CLIP)], k=0.003)
    tabs = []
    for i, part in enumerate((TAB_R, TAB_Y, TAB_G, TAB_B)):
        tabs.append(Box(c + R @ v3((0.118 + 0.006, -0.004, 0.11 - i * 0.03)), (0.009, 0.0016, 0.012), rr=0.001, R=R, part=part))
    return Union([board, paper, clip] + tabs, k=0.0)


def kit_bits(bd):
    """the ID badge on its reel (her right chest), the watch on her right wrist, the purple glove and a pen in the thigh pocket"""
    parts = []
    ry = probe(bd, -0.07, 1.345)
    reel = CappedCone((-0.07, ry + 0.002, 1.345), (-0.07, ry - 0.010, 1.345), 0.019, 0.019, rr=0.003, part=REEL)
    cord = RoundCone((-0.07, ry - 0.008, 1.33), (-0.072, ry - 0.012, 1.27), 0.0022, 0.0022, part=REEL)
    cy = probe(bd, -0.072, 1.23)
    card = Box((-0.072, cy - 0.006, 1.225), (0.03, 0.0022, 0.042), rr=0.003, R=rot(rx=-8), part=CARD)
    holder = Box((-0.072, cy - 0.004, 1.225), (0.033, 0.0016, 0.045), rr=0.003, R=rot(rx=-8), part=BADGE)
    parts += [reel, cord, card, holder]
    wd = (R_WRIST - R_ELBOW) / np.linalg.norm(R_WRIST - R_ELBOW)
    w = (R_WRIST - wd * 0.015) * np.array([-1, 1, 1], np.float32)
    wdm = wd * np.array([-1, 1, 1], np.float32)
    parts.append(Torus(w, 0.0245, 0.0045, Rm=basis(wdm, v3((0, 1, 0))), part=WATCH))
    parts.append(CappedCone(w + v3((-0.022, 0.0, 0.0)), w + v3((-0.031, 0.0, 0.0)), 0.012, 0.012, rr=0.002, part=WATCH))
    # the glove poking out of the cargo pocket, fingers flopped over its lip; a pen beside
    gx = -probe_x(bd, 0.0, 0.73)
    gl = []
    for k, (dy, ang) in enumerate(((-0.045, -20.0), (-0.03, -8.0), (-0.015, 4.0), (0.0, 16.0))):
        a = np.radians(ang)
        base = v3((gx - 0.006, dy, 0.715))
        tip = base + v3((-0.025, np.sin(a) * 0.02, -0.0 + 0.035 * np.cos(a) * 0.3 - 0.03))
        gl.append(loft([(base, 0.0075), (base + v3((-0.018, np.sin(a) * 0.01, 0.025)), 0.0072), (tip, 0.0065)], part=GLOVE_P, k=0.004))
    gl.append(Ellipsoid((gx - 0.004, -0.022, 0.72), (0.012, 0.03, 0.02), part=GLOVE_P))
    parts.append(Union(gl, k=0.006))
    parts.append(RoundCone((gx - 0.004, 0.02, 0.69), (gx - 0.006, 0.024, 0.765), 0.005, 0.0045, part=PEN))
    return Union(parts, k=0.0)


def probe_x(shape, y, z, x0=0.4, x1=0.0, step=0.0015):
    """the first surface met coming in from her right side (-X) at (y, z), returned as |x|"""
    xs = -np.arange(x1, x0, step, dtype=np.float32)[::-1]
    P = np.stack([xs, np.full_like(xs, y), np.full_like(xs, z)], 1)
    d = shape.eval(P)[0]
    i = int(np.argmax(d < 0))
    return float(-xs[i])


def pieces():
    import os
    only = os.environ.get("FOLK_ONLY", "")
    s = 1.5 if os.environ.get("FOLK_FAST") else 1.0
    if only == "head":
        return [("head", head(), 0.0018 * s), ("hair", dreads(), 0.0022 * s), ("cap", hair_cap(), 0.0022 * s)]
    bd = body()
    return [("head", head(), 0.0018 * s), ("hair", dreads(), 0.0022 * s), ("body", bd, 0.0035 * s), ("kit", kit_bits(bd), 0.0016 * s),
            ("props", clipboard(), 0.0022 * s), ("cap", hair_cap(), 0.0022 * s)]


# ---------------------------------------------------------------------------------------------------- paint
def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.01) * 0.25

    def sel(v, m):
        return v[m] if np.ndim(v) >= 1 and len(v) == n else v

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col[m] if np.ndim(col) == 2 and len(col) == n else col
        c.rough[m] = sel(rough, m)
        c.metal[m] = sel(metal, m)
        c.bump[m] = sel(bump, m)
        c.grain[m] = sel(grain, m)

    def spk(m, col, amt):
        a = np.broadcast_to(np.asarray(amt, np.float32), (n,))[m]
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), a[:, None]], 1)

    # skin: pale peach-beige, a warm blush on the cheeks, brown eyeshadow on the heavy lids, inked liner swept out into wings; freckles over the face
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(232, 200, 160), (n, 3)).copy() * (1.0 + 0.05 * mott)[:, None]
    blush = np.exp(-(((Q[:, 0] - 0.085) / 0.03) ** 2 + ((z - 1.69) / 0.022) ** 2)) * (y < -0.05)
    sk = sk + (srgb(222, 150, 128) - sk) * (0.5 * blush)[:, None]
    de = Q - EYE_C
    r = np.linalg.norm(de, axis=1)
    pd = (Q - LID_PT) @ LID_N
    lid = (r < EYE_R + 0.012) & (pd < 0.0)
    sk = sk + (srgb(176, 128, 98) - sk) * (lid * smooth(-0.03, -0.004, pd) * 0.7)[:, None]
    sk *= (1.0 - 0.15 * c.cavity)[:, None]          # round 3: softer creases (she read gaunt)
    put(m, sk, 0.5, bump=0.1)
    near = (r < EYE_R + 0.012) & (pd > -0.008) & (pd < 0.004) & (de[:, 1] < 0.014)
    c.draw(m & near, np.abs(pd + 0.0012), 0.0022)
    wing_t = (Q[:, 0] - (EYE_C[0] + 0.03)) / 0.03
    wing = (wing_t > 0) & (wing_t < 1) & (de[:, 1] < 0.03) & (r < EYE_R + 0.035) & (np.abs(pd) < 0.02)
    c.draw(m & wing, np.abs(pd + 0.0012 - 0.008 * wing_t ** 1.3), 0.0022 * (1.0 - wing_t))
    lowd = (Q - LOW_PT) @ LOW_N
    c.draw(m & (r < EYE_R + 0.008) & (np.abs(lowd) < 0.005) & (de[:, 1] < 0.0), np.abs(lowd - 0.0008), 0.0009, 0.7)
    face = m & (z > 1.55)
    spk(m, (186, 110, 84), 0.0)
    c.spk[face, 3] = 0.35 + 0.25 * np.clip(blush[face] * 2.0, 0, 1)
    put(c.mask(LIP), srgb(176, 102, 92) * (1.0 + 0.2 * c.wear)[:, None], 0.35)
    put(c.mask(PLUG), srgb(26, 22, 24), 0.3)
    # eyes: white at the corners, a big dark-brown iris glancing to her right under the lid, a glint
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    look = EYE_FWD + v3((-0.35, 0.0, 0.0))
    look /= np.linalg.norm(look)
    a = np.arccos(np.clip(d @ look, -1, 1))
    ir = srgb(122, 74, 40) + (srgb(54, 30, 16) - srgb(122, 74, 40)) * smooth(0.1, 0.36, a)[:, None]
    ir = ir + (srgb(240, 232, 222) - ir) * smooth(0.40, 0.45, a)[:, None]
    c.draw(m, (a / 0.17 - 1.0) * 0.17 * EYE_R, 0.0)
    ir *= (1.0 - 0.35 * smooth(-0.2, 0.1, d[:, 2]))[:, None]
    gl = np.zeros(n, np.float32)
    for sx in (1.0, -1.0):
        dd = P - EYE_C * np.array([sx, 1.0, 1.0], np.float32)
        dd /= np.maximum(np.linalg.norm(dd, axis=1), 1e-6)[:, None]
        gl = np.maximum(gl, smooth(0.008, 0.003, (dd[:, 0] + 0.15) ** 2 + (dd[:, 2] + 0.12) ** 2) * (dd[:, 1] < -0.5))
    ir = ir + (srgb(255, 250, 240) - ir) * gl[:, None]
    put(m, ir, 0.08)
    # dreads: deep red, twisted, the tips paler and pinker
    m = c.mask(DREAD)
    hd = np.linalg.norm((P - HEAD_C) / np.array([0.152, 0.142, 0.14], np.float32), axis=1)
    tip = np.maximum(smooth(1.62, 1.48, z), smooth(1.18, 1.38, hd) * (z > 1.75))          # the long locks' ends and the crown locks' lifted ends
    hue = noise3(P, 0.035)                                                                   # a touch of hue from lock to lock
    dr = srgb(132, 30, 62) + (srgb(150, 44, 52) - srgb(132, 30, 62)) * np.clip(hue, 0, 1)[:, None] + (srgb(112, 26, 74) - srgb(132, 30, 62)) * np.clip(-hue, 0, 1)[:, None]
    dr = dr + (srgb(196, 86, 116) - dr) * (tip * 0.7)[:, None]
    dr *= (1.0 + 0.12 * noise3(P, 0.006))[:, None]
    dr *= (1.0 - 0.55 * c.cavity)[:, None]
    put(m, dr, 0.75, bump=1.0)
    spk(m, (206, 120, 146), 0.35)                                                            # fuzz
    put(c.mask(HAIRBASE), srgb(40, 8, 18), 0.85, bump=0.5)
    # scrubs: teal cotton, worn a little paler on edges, seams and pocket stitching
    m = c.mask(SCRUB)
    sc = srgb(78, 152, 140) * (1.0 + 0.06 * mott)[:, None] * (1.0 + 0.3 * c.wear)[:, None]
    put(m, sc, 0.85, bump=0.9)
    spk(m, (52, 112, 104), 0.25)
    seam = m & (np.abs(Q[:, 0] - 0.13) < 0.004) & (z > 0.95) & (z < 1.3)
    c.draw(seam, np.abs(Q[:, 0] - 0.13), 0.0006, 0.35)
    m = c.mask(UNDER)
    put(m, srgb(214, 204, 190) * (1.0 + 0.05 * mott)[:, None], 0.85, bump=0.9)
    # sneakers: white leather, three purple stripes slanting down the outer side, a pale sole
    m = c.mask(SHOE)
    put(m, srgb(238, 234, 230) * (1.0 - 0.25 * c.cavity)[:, None] * (1.0 - 0.06 * np.clip(noise3(P, 0.01), 0, 1))[:, None], 0.55, bump=0.4, grain=1.0)
    sx = np.abs(x) - ANKLE[0]
    sv = (y - ANKLE[1]) * 0.8 + (z - 0.05) * 1.2
    stripes = (np.abs(((sv + 0.2) % 0.03) - 0.015) < 0.006) & (sx > 0.01) & (sv > -0.12) & (sv < -0.03) & (z > 0.03) & (z < 0.12)
    c.col[m & stripes] = srgb(122, 84, 168)
    put(c.mask(SOLE), srgb(214, 208, 200), 0.7, bump=0.5)
    put(c.mask(GLOVE_P), srgb(150, 100, 210) * (1.0 + 0.3 * c.wear)[:, None], 0.25)
    put(c.mask(PEN), srgb(200, 40, 40), 0.35)
    m = c.mask(CARD)
    cd = np.broadcast_to(srgb(240, 240, 236), (n, 3)).copy()
    photo = (x > -0.09) & (x < -0.078) & (z > 1.215) & (z < 1.235)
    cd[photo] = srgb(170, 96, 70)
    put(m, cd, 0.4)
    c.draw(m & (x > -0.07) & (x < -0.052) & (z > 1.205) & (z < 1.24), np.abs(np.sin(z * 600.0)) * 0.0026, 0.0004, 0.6)
    put(c.mask(BADGE), srgb(70, 80, 96), 0.3)
    put(c.mask(REEL), srgb(60, 64, 76) * (1.0 + 0.6 * c.wear)[:, None], 0.35, metal=0.3)
    put(c.mask(WATCH), srgb(40, 40, 46) * (1.0 + 0.8 * c.wear)[:, None], 0.35, metal=0.4)
    # the clipboard: a brown board, a paper of ruled lines with a blue header, a steel clip, coloured tabs
    m = c.mask(BOARD)
    put(m, srgb(104, 64, 40) * (1.0 + 0.5 * c.wear)[:, None], 0.5, bump=0.3, grain=1.0)
    m = c.mask(PAPER)
    q = (P - BOARD_C) @ BOARD_R
    pp = np.broadcast_to(srgb(238, 234, 222), (n, 3)).copy()
    head_ = (q[:, 2] > 0.105) & (q[:, 2] < 0.125)
    pp[head_] = srgb(120, 150, 210)
    put(m, pp, 0.85)
    rows = (q[:, 2] < 0.095) & (q[:, 2] > -0.14) & (np.abs(q[:, 0]) < 0.09)
    c.draw(m & rows, np.abs(((q[:, 2] + 0.2) % 0.013) - 0.0065), 0.0005, 0.5)
    put(c.mask(CLIP), srgb(196, 198, 204), 0.25, metal=1.0)
    put(c.mask(TAB_R), srgb(220, 60, 50), 0.5)
    put(c.mask(TAB_Y), srgb(240, 200, 60), 0.5)
    put(c.mask(TAB_G), srgb(90, 180, 90), 0.5)
    put(c.mask(TAB_B), srgb(70, 120, 220), 0.5)

    c.col *= (0.35 + 0.65 * c.ao)[:, None]
    c.col *= (1.0 - 0.2 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion
GAME = {
    "budget": {"head": 2500, "hair": 1000, "body": 3500, "kit": 500, "props": 500, "cap": 1400},
    "density": {"head": 1.9, "hair": 1.0, "kit": 1.3, "props": 1.2, "cap": 1.0},
    "tex": 2048,
    "stride": {"walk": 1.1, "run": 1.8},
    "speed": 1.2,
    "look": ["head", "hair"], "neck": "neck",
    "look_pivot": (0.0, 0.0, 1.62),
    "radius": 0.34,
}
BALL = v3((0.10, -0.12, 0.0))
BOARD_GRIP = C_WRIST


def rig_bones():
    from kit.rig import Bone, mirror
    f = np.array([-1, 1, 1], np.float32)
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.012, 0.92), (0, 0.012, 1.05), "root", 0.13),
        Bone("spine", (0, 0.012, 1.05), (0, 0.01, 1.2), "hips", 0.1),
        Bone("chest", (0, 0.01, 1.2), (0, 0.015, 1.40), "spine", 0.12),
        Bone("neck", NECK0, NECK1, "chest", 0.034),
        Bone("head", NECK1, (0, 0.02, 1.92), "neck", 0.15),
        Bone("hair", (-0.03, 0.05, 1.9), (-0.15, 0.1, 1.6), "head", 0.05),
        Bone("shoulder.L", (0.03, 0.015, 1.395), SHOULDER, "chest", 0.04),
        Bone("thigh.L", HIP, KNEE, "hips", 0.08),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.064),
        Bone("foot.L", ANKLE, ANKLE + v3((0.003, -0.2, -0.06)), "shin.L", 0.04),
    ])
    bones += [
        Bone("upper_arm.L", SHOULDER, C_ELBOW, "shoulder.L", 0.04),
        Bone("forearm.L", C_ELBOW, C_WRIST, "upper_arm.L", 0.032),
        Bone("hand.L", C_WRIST, C_WRIST - C_HAND[:, 2] * 0.08, "forearm.L", 0.025),
        Bone("board", BOARD_C, BOARD_C + BOARD_R[:, 2] * 0.15, "hand.L", 0.12),
        Bone("upper_arm.R", SHOULDER * f, R_ELBOW * f, "shoulder.R", 0.04),
        Bone("forearm.R", R_ELBOW * f, R_WRIST * f, "upper_arm.R", 0.032),
        Bone("hand.R", R_WRIST * f, (R_WRIST - R_HAND[:, 2] * 0.08) * f, "forearm.R", 0.025),
    ]
    return bones


def skin_rules(P, part, piece, names):
    """piece: 0 head, 1 hair (locks), 2 body, 3 kit, 4 props, 5 hair cap"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & ((z > 1.6) | ((z > 1.54) & (y < -0.06)))] = ix["head"]
    hr = piece == 1
    allow(hr, "head", "hair")
    rig[hr & (z > 1.8)] = ix["head"]
    kp = piece == 3
    allow(kp, "chest")
    rig[kp] = ix["chest"]
    rig[kp & (z < 0.9)] = ix["thigh.R"]
    rig[kp & (z < 0.9) & (x > 0)] = ix["thigh.L"]
    rig[kp & (part == WATCH)] = ix["forearm.R"]
    rig[piece == 5] = ix["head"]                    # the hair cap
    allow(piece == 5, "head")
    rig[piece == 4] = ix["board"]
    allow(piece == 4, "board")
    bp = piece == 2
    legs = bp & ((np.isin(part, (SCRUB, SHOE, SOLE)) & (z < 0.88)) | (z < 0.4))
    allow(legs, "hips")
    allow(legs & (x > -0.03), "thigh.L", "shin.L", "foot.L")
    allow(legs & (x < 0.03), "thigh.R", "shin.R", "foot.R")
    torso = bp & ~legs & (np.abs(x) < 0.15) & ~((part == SKIN) & (z < 1.25))
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & (x > 0.06) & (z > 1.3), "shoulder.L")
    allow(torso & (x < -0.06) & (z > 1.3), "shoulder.R")
    arms = bp & ~legs & ~torso
    allow(arms & (x > 0), "shoulder.L", "upper_arm.L", "forearm.L", "hand.L")
    allow(arms & (x <= 0), "shoulder.R", "upper_arm.R", "forearm.R", "hand.R")
    allow(arms & (z > 1.3), "chest")
    return A, rig


WALK = dict(stride=1.1, stance=0.56, foot_x=0.07, lift=0.06, bob=0.016, drop=0.038, sway=0.02, roll=5.0, yaw=7.0, counter=1.2,
            lean=3.0, toe_off=20.0, toe_out=5.0, swing_point=10.0)
RUN = dict(stride=1.8, stance=0.4, foot_x=0.07, lift=0.13, bob=0.03, drop=0.08, sway=0.015, roll=4.0, yaw=9.0, counter=1.4,
           lean=10.0, toe_off=28.0, toe_out=4.0, swing_point=16.0, spine_lean=3.0)
BACK = 0.11


def motions(rig):
    """her clips: walk (brisk and efficient: long quick strides, upright, the free arm swinging crisply, the clipboard held steady, dreads swinging),
    run (a hurry down the ward, the board clutched), idle (a glance down at the clipboard, a hip shift, a look round)"""
    import math
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        p.offset.y += BACK
        c = math.cos(TAU * u)
        s2 = math.sin(2 * TAU * u - 0.8)
        p.rot("upper_arm.R", -(36.0 if run else 22.0) * c, 0, 0)
        p.rot("forearm.R", -(60.0 if run else 12.0) - (14.0 if run else 10.0) * max(0.0, c), 0, 0)
        p.rot("hand.R", -5.0 * c, 0, 0)
        p.rot("upper_arm.L", (6.0 if run else 3.0) * c, 0, 0)
        p.rot("chest", 1.0 if run else 0.0, 0, 0)
        p.world["head"] = R((4.0 if run else 1.0) + 1.0 * s2, 0, 2.0 * math.sin(TAU * u))
        p.rot("hair", 0, (8.0 if run else 4.0) * math.sin(TAU * u - 1.0), (6.0 if run else 3.0) * math.sin(2 * TAU * u - 1.5))
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]
    # the left hand keeps its rest frame in the world while she walks: the board stays steady against her chest
    for p in walk + run:
        p.world["hand.L"] = R(0, 0, 0)

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        w = math.sin(TAU * t / 6.0)
        br = math.sin(TAU * t / 3.0)
        stand(rig, p, legs, {"L": (Vector((0.085, -0.12, 0.0)), 8.0), "R": (Vector((-0.12, -0.08, 0.0)), -14.0)},
              hip_shift=(0.03 + 0.008 * w, 0.0, -0.012), roll=-5.0, yaw=-4.0)
        p.rot("spine", 0.8 * br, 2.5, 3.5)
        p.rot("chest", 1.0 * br, 1.5, 2.0)
        # a look down at the clipboard (2.2-3.6 s), a look off to her right before and after
        rd = ease((t - 2.1) / 0.4) * (1.0 - ease((t - 3.6) / 0.5))
        look = -14.0 * (ease((t - 0.4) / 0.7) - ease((t - 1.6) / 0.5)) + 10.0 * (ease((t - 4.2) / 0.6) - ease((t - 5.4) / 0.5))
        p.world["head"] = R(18.0 * rd, -4.0 * rd, look + 12.0 * rd)
        p.rot("upper_arm.L", -6.0 * rd, 0, 0)
        p.rot("upper_arm.R", 1.5 * br, 0, 0)
        p.rot("forearm.R", -6.0, 0, 0)
        p.rot("hair", 0, 2.0 * br, 1.5 * w)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
