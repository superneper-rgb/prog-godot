## FOINT CITY townsfolk: the mop (working name; the user names it). A haystack of maroon ribbon-fringe on thin olive legs: a toothy mouth on top, two green slit eyes peeking out low through the fringe, a patched denim vest with pin badges, pink headphones round its "neck", striped socks and checkered slip-ons.
# Concept: the user's sheet, image 7 bottom left (F:/prog-godot-cache/folk/refs/7.webp). Measured off it (3x crop, 1.29 mm a pixel at 1.50 m): the fringe is a bell from the mouth at the
# top (0.45 m wide, lips 1.33-1.45) to a ragged hem about 1.1 m across at 0.45-0.5 m; the eyes at 0.67 m near the silhouette's edges; the vest 1.15-0.72 m; the legs come out
# of the hem 0.26 m apart, knees at 0.36, striped crew socks to 0.3, slip-ons 0.28 m long. No props (the coffee is dropped).
# Rest pose: standing, its left hand up and open (the concept's chatty wave), the right hand loose. The fringe has its own ring of bones that swing.
# Kit gaps filled here: hit() / normal(), a ribbon-fringe field (strands, grooves, shingled layers, a ragged hem), hands, the coiled cord.
import numpy as np
from kit.sdf import (Shape, Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.50
REF = ("7.webp", (31, 380, 386, 775))

(FRINGE, LIP, LIP_L, TOOTH, TOOTH_L, EYE, DENIM, BADGE, PAPER, PENCIL, RIVET, PHONE, CORD, SKIN, SOCK, SHOE, SOLE) = range(1, 18)
COLOURS = {
    FRINGE: ((0.35, 0.05, 0.1), 0.7, 0.0),
    LIP: ((0.4, 0.08, 0.15), 0.4, 0.0),
    LIP_L: ((0.4, 0.08, 0.15), 0.4, 0.0),
    TOOTH: ((0.78, 0.68, 0.45), 0.4, 0.0),
    TOOTH_L: ((0.78, 0.68, 0.45), 0.4, 0.0),
    EYE: ((0.45, 0.65, 0.2), 0.15, 0.0),
    DENIM: ((0.18, 0.28, 0.45), 0.85, 0.0),
    BADGE: ((0.85, 0.3, 0.02), 0.3, 0.0),
    PAPER: ((0.85, 0.82, 0.75), 0.8, 0.0),
    PENCIL: ((0.05, 0.05, 0.05), 0.5, 0.0),
    RIVET: ((0.7, 0.45, 0.15), 0.35, 1.0),
    PHONE: ((0.8, 0.3, 0.4), 0.4, 0.0),
    CORD: ((0.85, 0.4, 0.5), 0.4, 0.0),
    SKIN: ((0.4, 0.38, 0.1), 0.6, 0.0),
    SOCK: ((0.8, 0.78, 0.74), 0.9, 0.0),
    SHOE: ((0.1, 0.1, 0.1), 0.7, 0.0),
    SOLE: ((0.75, 0.68, 0.58), 0.8, 0.0),
}
F32 = np.float32
UP = np.array((0, 0, 1), F32)


def hit(shape, start, direction, far=1.5, n=500):
    """where a ray from `start` first enters `shape`"""
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


def frame(z_dir, x_dir):
    """columns x, y, z: local +Z along z_dir, local +X leaning to x_dir"""
    z = v3(z_dir) / np.linalg.norm(z_dir)
    x = v3(x_dir) - z * float(v3(x_dir) @ z)
    x /= np.linalg.norm(x)
    return np.stack([x, np.cross(z, x), z], 1).astype(F32)


def azi(deg, r=1.0, z=0.0):
    a = np.radians(deg)
    return v3((np.sin(a) * r, -np.cos(a) * r, z))


class Bounded(Shape):
    def __init__(self, child, lo, hi):
        self.child, self.lo, self.hi, self.part = child, v3(lo), v3(hi), child.part

    def eval(self, P):
        return self.child.eval(P)

    def dist(self, P):
        return self.child.eval(P)[0]


# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; it faces -Y)

MZ = 1.375                     # the mouth's line
MW = 0.175                     # half its width
EYE_AZ, EYE_Z, EYE_R = 60.0, 0.675, 0.03
HIP = v3((0.13, 0.02, 0.6))
KNEE = v3((0.165, -0.03, 0.36))
ANKLE = v3((0.195, 0.01, 0.115))
TOE_OUT = 10.0
FWD = v3((np.sin(np.radians(TOE_OUT)), -np.cos(np.radians(TOE_OUT)), 0.0))
BALL = v3((ANKLE[0], ANKLE[1], 0.0)) + FWD * 0.14
SH = v3((0.37, 0.0, 1.0))
# its left arm (+X): up and open, chatting; its right (built on the left, mirrored): loose
L_EL, L_WR = v3((0.53, -0.02, 0.86)), v3((0.64, -0.13, 1.03))
L_HAND = frame(-v3((0.3, -0.25, 1.0)), v3((0.25, 1.0, 0.0)))
R_EL, R_WR = v3((0.5, -0.07, 0.8)), v3((0.55, -0.22, 0.9))
R_HAND = frame(-v3((0.1, -0.7, 0.6)), v3((1.0, 0.1, 0.2)))
FLIP = np.diag([-1.0, 1.0, 1.0]).astype(F32)
SECTORS = 8


# ---------------------------------------------------------------------------------------------------- the fringe

def bell():
    """the haystack's smooth core: narrow at the mouth, flaring to the hem"""
    return Union([
        Ellipsoid((0, 0.0, 1.34), (0.24, 0.21, 0.12)),
        Ellipsoid((0, 0.0, 1.05), (0.38, 0.33, 0.3)),
        Ellipsoid((0, 0.02, 0.62), (0.57, 0.47, 0.3)),
        CappedCone((0, 0.02, 0.45), (0, 0.01, 1.2), 0.55, 0.2, rr=0.05),          # a haystack: the hem the widest part, never tucked in
    ], k=0.16, part=FRINGE)


def strand_paths():
    """the shag: [(segment points, width, thickness, layer)] for each ribbon strand: two staggered layers hanging from round the top
    (below the lips at the front), each strand following the bell down with its own sideways curl and twist, ending at its own length
    with the tip flicked out"""
    rng = np.random.default_rng(12)
    core = bell()
    out = []
    for layer, (n, off, w) in enumerate(((36, 0.004, 0.1), (18, -0.008, 0.07), (16, 0.006, 0.08))):      # (broad clusters that split into tips: every separate strand costs UV islands)
        for i in range(n):
            az = (i + 0.5 * layer + rng.uniform(-0.3, 0.3)) * 360.0 / n
            a = ((az + 180.0) % 360.0) - 180.0
            front = abs(a) < 44.0
            if layer == 2:                                   # the crown: short strands from the very top, falling over the others (not over the lips)
                if abs(a) < 58.0:
                    continue
                z0, z1 = 1.452, rng.uniform(1.19, 1.28)         # ending above the vest's collar, never through it
            else:
                z0 = (1.31 if front else 1.42 - 0.05 * abs(np.cos(np.radians(a)))) - rng.uniform(0.0, 0.05) - 0.03 * layer
                z1 = rng.uniform(0.37, 0.52) + 0.04 * layer
            ph = rng.uniform(0, 2 * np.pi)
            curl = rng.uniform(3.0, 8.0)
            pts = []
            for k in range(6):
                t = k / 5.0
                z = z0 + (z1 - z0) * t
                d = azi(az + curl * np.sin(ph + t * 3.5) * t)
                sp = hit(core, d * 1.3 + v3((0, 0, z)), -d)
                flick = 0.06 * max(0.0, (t - 0.72) / 0.28) ** 1.6
                pts.append(sp + d * (off + 0.007 + flick) + UP * (0.02 * max(0.0, (t - 0.8) / 0.2) ** 2))
            out.append((pts, w * rng.uniform(0.8, 1.15), 0.0145, layer, ph))
    return out


def fringe():
    """a dark core under a shag of separate ribbon strands, each fused into the core near the top (and thicker than four voxels: no hair-thin
    parts, or the mesh goes non-manifold and will not decimate)"""
    core = Inflate(bell(), -0.004, part=FRINGE)                        # under the strands: the dark in the gaps
    core = Clip(core, [Half((0, 0, 0.6), (0, 0, -1))], k=0.04)            # the core stops short: the strands make the hem
    groups = {}
    for pts, w, th, layer, ph in strand_paths():
        segs = []
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            ax = b - a
            L = float(np.linalg.norm(ax))
            side = np.cross(UP, (a + b) * 0.5 * v3((1, 1, 0)))
            side /= max(np.linalg.norm(side), 1e-6)
            R = frame(ax, side) @ rot(rz=6.0 * np.sin(ph + k * 0.9))           # each ribbon twists a little as it falls
            taper = 1.0 - 0.25 * (k / (len(pts) - 2))
            if k < len(pts) - 3 or layer == 2:
                segs.append(Box((a + b) * 0.5, (w * 0.5 * taper, th * 0.5, L * 0.5 + 0.008), rr=th * 0.5 - 0.0008, R=R, part=FRINGE))
            else:                                   # the cluster parts into two tips of different lengths
                for sg, ln in ((1.0, 1.0), (-1.0, 0.62 + 0.2 * np.sin(ph * 3.0))):
                    if k == len(pts) - 2:
                        b2 = a + (b - a) * ln
                    else:
                        b2 = b
                    o = R[:, 0] * (sg * w * 0.26 * (1.0 + 0.4 * (k - (len(pts) - 3))))
                    L2 = float(np.linalg.norm(b2 - a))
                    segs.append(Box((a + b2) * 0.5 + o, (w * 0.22, th * 0.5, L2 * 0.5 + 0.008), rr=th * 0.5 - 0.0008, R=R, part=FRINGE))
        az = np.degrees(np.arctan2(pts[0][0], -pts[0][1])) % 360.0
        groups.setdefault(int(az // 30.0), []).append(Union(segs, k=0.006, part=FRINGE))
    # everything smooth-unioned: strands that only graze each other leave non-manifold slivers that stall the decimator
    shag = Union([Union(g, k=0.008, part=FRINGE) for g in groups.values()], k=0.008, part=FRINGE)
    b = Union([core, shag], k=0.02, part=FRINGE)                       # (k bridges the few mm to the core: every strand fused, none floating)
    # the mouth's slot cut into the top front; gaps in the shag for the eyes to peek through and the arms to come out of
    b = Cut(b, [Ellipsoid((0, -0.2, MZ), (MW - 0.01, 0.07, 0.022))], k=0.008)
    holes = []
    for sx in (1.0, -1.0):
        c, n = eye_place(sx)
        holes.append(Sphere(c + n * 0.01, EYE_R + 0.03))
        holes.append(Sphere(SH * v3((sx, 1, 1)) + v3((sx * 0.02, -0.01, 0)), 0.045))
    return Cut(b, holes, k=0.01)


def tuft():
    """a spiky tuft on top, behind the mouth: its own piece (hair-thin spikes in the fringe left it non-manifold, and it would not decimate)"""
    rng = np.random.default_rng(7)
    sm = bell()
    tuft = []
    for i in range(34):
        a = rng.uniform(0, 2 * np.pi)
        r = rng.uniform(0.0, 0.2)
        x, y = r * np.cos(a), r * np.sin(a) * 0.85 + 0.02
        if y < -0.08:
            y = -0.08 + rng.uniform(0, 0.03)
        s = hit(sm, (x, y, 1.8), (0, 0, -1))
        n = normal(sm, s)
        d = n * 0.6 + v3((rng.normal(0, 0.4), rng.normal(0, 0.4), 0.7))
        d /= np.linalg.norm(d)
        tuft.append(RoundCone(s - n * 0.012, s + d * rng.uniform(0.035, 0.07), 0.008, 0.0035, part=FRINGE))
    return Union(tuft, k=0.004, part=FRINGE)


def eye_place(sx):
    sm = bell()
    d = azi(EYE_AZ * sx)
    s = hit(sm, d * 1.0 + v3((0, 0, EYE_Z)), -d)
    n = normal(sm, s)
    return s + n * 0.01, n                                   # out in the gap it peeks through, just under the strands' faces


def mouth():
    """big lips across the top, a row of square cream teeth with one missing, crooked bottom ones"""
    sm = bell()
    lips, teeth = [], []
    for sgn, part in ((1.0, LIP), (-1.0, LIP_L)):
        pts = []
        for t in np.linspace(-1.0, 1.0, 15):
            w = max(0.0, 1.0 - t * t)
            if sgn > 0:
                z = MZ + 0.006 + 0.026 * w ** 0.7
                r = 0.008 + 0.017 * w ** 0.45
            else:
                z = MZ - 0.006 - 0.03 * w ** 0.7
                r = 0.008 + 0.02 * w ** 0.45
            s = hit(sm, (MW * t * 1.02, -0.6, z), (0, 1, 0))
            pts.append((s + normal(sm, s) * r * 0.35, r))
        lips.append(loft(pts, part=part, k=0.012))
    rng = np.random.default_rng(4)
    for ts, half, zc, part in (((-0.66, -0.4, -0.13, 0.13, 0.4, 0.66), (0.0185, 0.017, 0.008), MZ + 0.006, TOOTH),
                               ((-0.5, -0.22, 0.05, 0.3, 0.52), (0.0135, 0.012, 0.007), MZ - 0.02, TOOTH_L)):
        for t in ts:
            if part == TOOTH and abs(t - 0.4) < 0.01:
                continue                                 # the missing one
            s = hit(sm, (MW * t, -0.6, zc), (0, 1, 0))
            n = normal(sm, s)
            n[2] = 0.0
            n /= np.linalg.norm(n)
            R = basis(n, UP) @ rot(rz=rng.uniform(-6, 6), rx=rng.uniform(-6, 6))
            teeth.append(Box(s - n * 0.012, half, rr=0.004, R=R, part=part))
    return Union(lips + teeth, k=0.0)


def eyes():
    out = []
    for sx in (1.0, -1.0):
        c, n = eye_place(sx)
        out.append(Sphere(c, EYE_R, part=EYE))
    return Union(out)


# ---------------------------------------------------------------------------------------------------- the denim vest, the headphones

def prism(poly_xz, y0=-0.8, y1=0.05):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], F32))


def fray(P):
    return noise3(P, 0.02) * 0.7 + noise3(P, 0.045) * 0.3            # (no finer: fine fray slivers will not decimate; the fraying is painted)


def vest():
    core = bell()
    shell = Cut(Inflate(core, 0.052, part=DENIM), [Inflate(core, 0.032)])     # worn over the shag: 20 mm (a thin shell tears when decimated)
    folds = lambda P: noise3(P * v3((1.0, 1.0, 0.4)), 0.07) * 0.7 + noise3(P, 0.025) * 0.3
    shell = Bump(shell, folds, 0.005)
    # a vest that wraps right round: whole across the back, open down the front (left of centre), small armholes where the arms come out,
    # its hem and armholes frayed and ragged where they sink into the shag
    band = Clip(shell, [Bump(Half((0, 0, 1.17), (0, 0, 1)), fray, 0.006), Bump(Half((0, 0, 0.76), (0.1, 0, -1)), fray, 0.008)], k=0.006)
    front = Box((0.035, -0.5, 0.95), (0.06, 0.3, 0.3), rr=0.02)
    arm_h = Mirror(Ellipsoid((0.4, -0.01, 1.0), (0.13, 0.11, 0.13)))
    v = Bounded(Cut(band, [front, Bump(arm_h, fray, 0.008)], k=0.01), (-0.65, -0.6, 0.65), (0.65, 0.6, 1.25))
    # the pocket on its right panel, a notepad and two pencils in it; badges; brass rivets and buttons
    sp = hit(core, (-0.2, -0.8, 0.86), (0, 1, 0))
    n = normal(core, sp)
    sp = sp + n * 0.052                                       # the vest's outer face
    R = frame(n, np.cross(UP, n))
    pocket = Box(sp + n * 0.004, (0.085, 0.055, 0.006), rr=0.004, R=R, part=DENIM)
    flap = Box(sp + n * 0.01 + UP * 0.05, (0.088, 0.016, 0.005), rr=0.004, R=R, part=DENIM)
    pad = Box(sp + n * 0.012 + UP * 0.075 + R[:, 0] * 0.005, (0.04, 0.045, 0.004), rr=0.002, R=R @ rot(rz=-3), part=PAPER)
    rings = [Torus(sp + n * 0.014 + UP * 0.12 + R[:, 0] * (o * 0.012), 0.005, 0.0016, Rm=frame(R[:, 0], UP), part=RIVET) for o in range(-3, 4)]
    pencils = [RoundCone(sp + n * 0.012 + UP * 0.02 + R[:, 0] * ox, sp + n * 0.012 + UP * 0.14 + R[:, 0] * (ox + lean), 0.0055, 0.004, part=pt)
               for ox, lean, pt in ((-0.055, -0.012, PENCIL), (0.06, 0.008, BADGE))]
    parts = [v, pocket, flap, pad] + rings + pencils
    for (bx, bz, r, part) in ((-0.2, 1.0, 0.033, BADGE), (-0.24, 1.08, 0.026, PAPER)):
        q = hit(core, (bx, -0.8, bz), (0, 1, 0))
        qn = normal(core, q)
        q = q + qn * 0.052
        parts.append(CappedCone(q - qn * 0.004, q + qn * 0.008, r, r * 0.95, rr=0.004, part=part))
    for (bx, bz) in ((-0.07, 0.79), (-0.065, 0.9), (-0.08, 1.02), (0.14, 0.82), (0.14, 0.95), (-0.31, 0.77), (0.37, 0.82)):
        try:
            q = hit(v, (bx, -0.8, bz), (0, 1, 0))
        except ValueError:
            continue
        parts.append(Sphere(q + normal(v, q) * 0.002, 0.008, part=RIVET))
    return Union(parts, k=0.0)


def headphones():
    """worn round the neck: a wide pink band across the front from its right shoulder, one big cup on its left front, the coiled cord hanging"""
    sm = bell()
    pts = []
    for t in np.linspace(0.0, 1.0, 12):
        az = -55.0 + 72.0 * t
        z = 1.29 - 0.22 * t
        q = hit(sm, azi(az, 1.2, z), -azi(az))
        pts.append(q + normal(sm, q) * 0.072)
    band = loft([(p, 0.02) for p in pts], part=PHONE, k=0.02)
    slider = Box(pts[3], (0.026, 0.03, 0.014), rr=0.005, R=frame(normal(sm, pts[3]), pts[4] - pts[2]), part=RIVET)
    cq = hit(sm, azi(20.0, 1.2, 1.0), -azi(20.0))
    cn = normal(sm, cq)
    cc = cq + cn * 0.075
    cup = CappedCone(cc - cn * 0.03, cc + cn * 0.02, 0.085, 0.08, rr=0.014, part=PHONE)
    rim = Torus(cc - cn * 0.012, 0.086, 0.007, Rm=basis(cn, UP), part=RIVET)
    yoke = loft([(pts[-1], 0.012), (cc + UP * 0.07 - cn * 0.01, 0.012), (cc + UP * 0.06 + np.cross(UP, cn) * 0.06, 0.01)], part=PHONE, k=0.01)
    # the coiled cord, then hanging
    top = cc - UP * 0.08 + cn * 0.0
    coil = []
    for i in range(70):
        a = i * 0.55
        coil.append((top - UP * (0.0033 * i) + cn * (0.012 * np.cos(a)) + np.cross(UP, cn) * (0.012 * np.sin(a)), 0.0042))
    end = coil[-1][0]
    coil += [(end - UP * 0.1 + cn * 0.01, 0.0042), (end - UP * 0.26 + cn * 0.02, 0.0042)]
    cord = loft(coil, part=CORD, k=0.004)
    plug = RoundCone(top + UP * 0.012, top - UP * 0.01, 0.009, 0.006, part=PHONE)
    return Union([band, slider, cup, rim, yoke, cord, plug], k=0.0)


# ---------------------------------------------------------------------------------------------------- arms, legs, socks, slip-ons

def hand(curl, spread, thumb):
    """hand space: the wrist at the origin, fingers along -Z, back of the hand +X, thumb toward -Y; four long knobbly fingers"""
    parts = [RoundCone((0, 0, 0.012), (0, 0, -0.01), 0.017, 0.018, part=SKIN), Ellipsoid((0, 0, -0.03), (0.011, 0.026, 0.028), part=SKIN)]
    for i, fy in enumerate((-0.016, -0.005, 0.006, 0.017)):
        sp = np.radians(spread * (i - 1.5))
        a = np.radians(curl[i])
        p = v3((0.0, fy, -0.052))
        pts = [(p, 0.0075)]
        for k, seg in enumerate((0.03, 0.022, 0.018)):
            ang = a * (k + 1) / 2.0
            p = p + v3((-np.sin(ang), np.sin(sp), -np.cos(ang))) * seg
            pts.append((p, 0.0068 - 0.0007 * k))
        parts.append(loft(pts, part=SKIN, k=0.003))
        parts += [Sphere(pts[1][0], 0.0085, part=SKIN), Sphere(pts[2][0], 0.0075, part=SKIN)]          # knobbly knuckles
    ta = np.radians(thumb)
    t0 = v3((-0.005, -0.02, -0.015))
    t1 = t0 + v3((-0.006, -0.02, -0.014))
    t2 = t1 + v3((-0.012 * np.sin(ta), -0.01, -0.02 * np.cos(ta)))
    parts.append(loft([(t0, 0.009), (t1, 0.0078), (t2, 0.007)], part=SKIN, k=0.003))
    return Union(parts, k=0.005)


def limb_arm(el, wr, R, curl, spread, thumb):
    a = loft([(SH - (el - SH) * 0.15, 0.024), (el, 0.02), (wr, 0.017)], part=SKIN, k=0.01)
    return Union([a, Sphere(el, 0.026, part=SKIN), place(hand(curl, spread, thumb), wr, R)], k=0.008)


def limbs():
    left = limb_arm(L_EL, L_WR, L_HAND, (8.0, 4.0, 10.0, 16.0), 9.0, 30.0)
    right = Move(limb_arm(R_EL, R_WR, R_HAND, (40.0, 50.0, 55.0, 60.0), 3.0, 20.0), R=FLIP)
    leg = Union([loft([(HIP, 0.028), (KNEE, 0.025), (ANKLE + v3((0, 0, 0.05)), 0.023)], part=SKIN, k=0.01), Sphere(KNEE + v3((0, -0.006, 0)), 0.035, part=SKIN)], k=0.012)
    return Union([left, right, Mirror(leg)], k=0.0)


def feet():
    f = FWD
    side = np.cross(UP, f)
    a = v3((ANKLE[0], ANKLE[1], 0.0))
    sock = Union([CappedCone(a + UP * 0.06, a + UP * 0.27, 0.036, 0.035, rr=0.01, part=SOCK),
                  Torus(a + UP * 0.27, 0.035, 0.008, part=SOCK)], k=0.008)
    upper = loft([(a - f * 0.07 + UP * 0.062, 0.058), (a + f * 0.07 + UP * 0.058, 0.066), (a + f * 0.18 + UP * 0.05, 0.055)], part=SHOE, k=0.03)
    upper = Clip(upper, [Half(UP * 0.02, -UP), Half(a + UP * 0.105, (0.0, 0.0, 1.0))], k=0.006)
    collar = Cut(Clip(Inflate(upper, 0.004, part=SHOE), [Half(a + UP * 0.103, UP)]), [CappedCone(a + UP * 0.05, a + UP * 0.14, 0.042, 0.042)], k=0.004)
    sole = Clip(Inflate(Union([upper]), 0.009, part=SOLE), [Half(UP * 0.04, UP), Half((0, 0, 0), -UP)], k=0.003)
    return Union([Union([upper, collar], k=0.004, part=SHOE), sole, sock], k=0.0)


def pieces():
    import os
    q = float(os.environ.get("FOLK_DRAFT", "1"))
    return [("fringe", fringe(), 0.0032 * q), ("tuft", tuft(), 0.0017 * q), ("mouth", mouth(), 0.0015 * q), ("eyes", eyes(), 0.0012 * q), ("vest", vest(), 0.002 * q),
            ("phones", headphones(), 0.0016 * q), ("limbs", limbs(), 0.0016 * q), ("feet", Mirror(feet()), 0.0022 * q)]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    n = len(P)
    mott = noise3(P, 0.04) * 0.5 + noise3(P, 0.012) * 0.25

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

    def full(col):
        return np.broadcast_to(srgb(*col), (n, 3)).copy()

    # fringe: raspberry-maroon ribbons, each its own shade, lighter worn tips and edges; the core under them near black-maroon,
    # so the gaps between strands read deep
    m = c.mask(FRINGE)
    th = np.arctan2(x, -y)
    hue = (noise3(v3((1.0, 1.0, 0.08)) * P + 3.0, 0.03) * 0.5 + 0.5)
    fr = lerp(full((146, 40, 66)), srgb(184, 64, 92), hue)
    fr = lerp(fr, srgb(206, 104, 124), c.wear * 0.45)
    fr = lerp(fr, srgb(206, 104, 124), smooth(0.56, 0.42, z) * 0.35)                 # sun-faded tips
    fr *= (1.0 + 0.06 * mott)[:, None]
    coreness = smooth(0.006, 0.0, np.abs(bell().eval(P)[0] + 0.002)) * smooth(1.3, 1.2, z)     # on the dark core, not a strand (the crown stays maroon)
    fr = lerp(fr, srgb(46, 10, 22), np.maximum(coreness * 0.9, c.cavity * 0.75))
    fr = lerp(fr, srgb(40, 8, 18), (1.0 - c.ao) * 0.5)
    for sx in (1.0, -1.0):
        ce, cn = eye_place(sx)
        dd = np.linalg.norm(P - ce, axis=1)
        fr = lerp(fr, srgb(30, 8, 14), smooth(EYE_R + 0.035, EYE_R + 0.01, dd) * 0.85)
    inside = m & (np.abs(x) < MW) & (np.abs(z - MZ) < 0.03) & (y > -0.21) & (y < -0.08)        # (only the front: not a band round the back)
    fr[inside] = srgb(40, 8, 16)
    put(m, fr, 0.7, bump=0.6, grain=0.0)
    c.strp[m, 0] = (z * 0.4)[m]
    c.strp[m, 1] = 0.0
    spk(m, (214, 120, 140), 0.12)

    m = c.mask(LIP, LIP_L)
    lp = lerp(full((178, 70, 96)), srgb(110, 30, 52), smooth(0.014, 0.0, np.abs(z - MZ)) * 0.7)
    lp = lerp(lp, srgb(214, 120, 136), c.wear * 0.4)
    put(m, lp, 0.3, bump=0.2)
    m = c.mask(TOOTH, TOOTH_L)
    put(m, lerp(full((232, 216, 166)), srgb(170, 140, 80), smooth(0.4, 0.9, noise3(P, 0.008)) * 0.35), 0.35)

    # eyes: pale green, a tall black slit, a glint
    m = c.mask(EYE)
    ey = full((176, 210, 120))
    for sx in (1.0, -1.0):
        ce, cn = eye_place(sx)
        d = P - ce
        dl = np.maximum(np.linalg.norm(d, axis=1), 1e-6)
        dn = d / dl[:, None]
        g = cn * 0.6 + v3((0, -1, 0)) * 0.4
        g /= np.linalg.norm(g)
        mine = m & (dl < EYE_R * 1.3)
        e1 = np.cross(UP, g)
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(g, e1)
        a_, b_ = dn @ e1, dn @ e2
        ey[mine] = lerp(ey, srgb(110, 150, 60), smooth(0.6, 1.3, np.arccos(np.clip(dn @ g, -1, 1))))[mine]
        c.draw(mine & (dn @ g > 0.3), (np.sqrt((a_ / 0.09) ** 2 + (b_ / 0.42) ** 2) - 1.0) * 0.004, 0.0)
        gl = smooth(0.02, 0.006, (a_ + 0.25) ** 2 + (b_ - 0.3) ** 2) * mine
        ey = lerp(ey, srgb(250, 255, 240), gl)
    put(m, ey, 0.08)

    # denim: faded blue, paler on the worn edges and seams, frayed white edges, brass
    m = c.mask(DENIM)
    dn_ = full((104, 134, 176))
    dn_ *= (1.0 + 0.1 * mott)[:, None]
    dn_ = lerp(dn_, srgb(182, 200, 218), c.wear * 0.7)
    dn_ = lerp(dn_, srgb(60, 80, 116), c.cavity * 0.5)
    put(m, dn_, 0.9, bump=1.0)
    spk(m, (190, 150, 90), 0.2)
    c.strp[m, 0] = ((x + z) * 0.7)[m]
    c.strp[m, 1] = 0.25
    m = c.mask(BADGE)
    put(m, srgb(234, 128, 40), 0.3, bump=0.1)
    put(c.mask(PAPER), srgb(234, 228, 212), 0.85, bump=0.4)
    put(c.mask(PENCIL), srgb(40, 38, 40), 0.5)
    put(c.mask(RIVET), srgb(196, 150, 80) * (1.0 - 0.4 * c.cavity)[:, None], 0.35, metal=1.0, grain=1.0, bump=0.1)

    # headphones: bubblegum pink, scuffed, a cream lightning bolt on the cup
    m = c.mask(PHONE, CORD)
    ph = lerp(full((228, 112, 140)), srgb(250, 180, 196), c.wear * 0.5)
    ph = lerp(ph, srgb(170, 80, 96), smooth(0.3, 0.8, noise3(P + 2.0, 0.015)) * 0.25)
    cq = hit(bell(), azi(20.0, 1.2, 1.0), -azi(20.0))
    cn = normal(bell(), cq)
    cc = cq + cn * 0.095
    R = frame(cn, np.cross(UP, cn))
    lc = (P - cc) @ R
    u, v = lc[:, 0] / 0.05, lc[:, 1] / 0.05
    bolt = (np.abs(u + v * 0.35) < 0.22) & (np.abs(v) < 0.9) & (lc[:, 2] > -0.01)
    bolt |= (np.abs(u - 0.0 + (v - 0.0) * 0.35) < 0.4) & (np.abs(v) < 0.12) & (lc[:, 2] > -0.01)
    ph = np.where((bolt & m)[:, None], srgb(240, 214, 150), ph)
    put(m, ph, 0.35, bump=0.15, grain=1.0)

    # olive skin, darker at the knuckles and knees
    m = c.mask(SKIN)
    sk = lerp(full((164, 156, 76)), srgb(112, 104, 46), c.cavity * 0.6)
    sk = lerp(sk, srgb(196, 186, 110), c.wear * 0.35)
    sk *= (1.0 + 0.08 * mott)[:, None]
    put(m, sk, 0.55, bump=0.3)
    spk(m, (126, 112, 50), 0.3)

    # socks: white, two red stripes round the top; slip-ons: black and cream checkerboard, cream soles, mud
    m = c.mask(SOCK)
    so = full((232, 226, 214))
    so = np.where(((np.abs(z - 0.235) < 0.008) | (np.abs(z - 0.212) < 0.008))[:, None], srgb(184, 44, 46), so)
    put(m, lerp(so, srgb(170, 150, 120), smooth(0.12, 0.06, z) * 0.5), 0.9, bump=1.0)
    m = c.mask(SHOE)
    a = v3((ANKLE[0], ANKLE[1], 0.0))
    rel = Q - a
    fu = rel @ (FWD * v3((1, 1, 1)))
    su = rel @ np.cross(UP, FWD)
    chk = ((np.floor(fu / 0.032) + np.floor((su + z) / 0.032)) % 2) == 0
    sh = np.where(chk[:, None], srgb(34, 32, 34), srgb(226, 214, 190))
    sh = lerp(sh, srgb(140, 110, 80), smooth(0.4, 0.8, noise3(P, 0.012)) * 0.3)
    put(m, sh, 0.75, bump=0.8)
    m = c.mask(SOLE)
    put(m, lerp(full((228, 216, 192)), srgb(150, 120, 86), smooth(0.03, 0.0, z) * 0.5), 0.8, bump=0.5, grain=1.0)
    spk(m, (150, 106, 70), 0.55)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"fringe": 4800, "tuft": 300, "mouth": 800, "eyes": 150, "vest": 1400, "phones": 450, "limbs": 750, "feet": 750},
    "density": {"mouth": 1.5, "eyes": 1.5, "vest": 1.2, "phones": 1.1},
    "tex": 2048,
    "stride": {"walk": 0.6, "run": 1.05},
    "speed": 0.85,
    "look": ["top"], "neck": "body",
    "look_pivot": (0.0, 0.0, 1.2),
    "radius": 0.55,
}


def rig_bones():
    from kit.rig import Bone, mirror
    bones = mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.0, 0.6), (0, 0.0, 0.85), "root", 0.2),
        Bone("body", (0, 0.0, 0.85), (0, 0.0, 1.15), "hips", 0.36),
        Bone("top", (0, 0.0, 1.15), (0, 0.0, 1.5), "body", 0.22),
        Bone("jaw", (0, -0.1, MZ), (0, -0.25, MZ - 0.02), "top", 0.03),
        Bone("thigh.L", HIP, KNEE, "hips", 0.03),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.028),
        Bone("foot.L", ANKLE, v3((ANKLE[0], ANKLE[1], 0.03)) + FWD * 0.2, "shin.L", 0.05),
    ])
    for i in range(SECTORS):
        a = i * 360.0 / SECTORS
        bones.append(Bone("fringe.%d" % i, azi(a, 0.32, 0.82), azi(a, 0.56, 0.45), "hips", 0.08))
    for sd, el, wr, R, f in (("L", L_EL, L_WR, L_HAND, np.eye(3, dtype=F32)), ("R", R_EL, R_WR, R_HAND, FLIP)):
        hend = wr - R[:, 2] * 0.05
        bones += [Bone("upper_arm." + sd, f @ SH, f @ el, "body", 0.022), Bone("forearm." + sd, f @ el, f @ wr, "upper_arm." + sd, 0.02),
                  Bone("hand." + sd, f @ wr, f @ hend, "forearm." + sd, 0.018)]
    return bones


def skin_rules(P, part, piece, names):
    """pieces: 0 fringe, 1 tuft, 2 mouth, 3 eyes, 4 vest, 5 phones, 6 limbs, 7 feet"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    az = np.degrees(np.arctan2(x, -y)) % 360.0

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True

    def sector(m, zlo=0.0):
        for i in range(SECTORS):
            da = np.abs((az - i * 360.0 / SECTORS + 180.0) % 360.0 - 180.0)
            allow(m & (da < 360.0 / SECTORS * 1.05) & (z < 0.8), "fringe.%d" % i)
    fp = (piece == 0) | (piece == 1)
    allow(fp, "body")
    allow(fp & (z > 1.1), "top")
    allow(fp & (z < 0.95), "hips")
    sector(fp)
    rig[fp & (z > 1.25)] = ix["top"]
    mp = piece == 2
    rig[mp & np.isin(part, (LIP, TOOTH))] = ix["top"]
    rig[mp & np.isin(part, (LIP_L, TOOTH_L))] = ix["jaw"]
    allow(mp, "top")
    ep = piece == 3
    for i in range(SECTORS):
        da = np.abs((az - i * 360.0 / SECTORS + 180.0) % 360.0 - 180.0)
        rig[ep & (da <= 180.0 / SECTORS + 0.01) & (rig < 0)] = ix["fringe.%d" % i]
    vp = piece == 4
    allow(vp, "body", "hips")
    rig[piece == 5] = ix["body"]
    allow(piece == 5, "body")
    lp = piece == 6
    for s, sd, wr, R in ((1, "L", L_WR, L_HAND), (-1, "R", R_WR * v3((-1, 1, 1)), FLIP @ R_HAND)):
        arm = lp & (x * s > 0) & (z > 0.7)
        allow(arm, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        rig[arm & (((P - wr) @ (-R[:, 2])) > 0.006)] = ix["hand." + sd]
        leg = lp & (x * s > 0) & (z <= 0.7)
        allow(leg, "thigh." + sd, "shin." + sd)
        allow(leg & (z > 0.55), "hips")
    fe = piece == 7
    for s, sd in ((1, "L"), (-1, "R")):
        m = fe & (x * s > 0)
        allow(m, "shin." + sd, "foot." + sd)
        rig[m & ((z < 0.1) | np.isin(part, (SHOE, SOLE)))] = ix["foot." + sd]
    return A, rig


WALK = dict(stride=0.6, stance=0.6, lift=0.06, bob=0.035, drop=0.03, sway=0.02, roll=4.0, yaw=6.0, lean=2.0, toe_off=12.0, swing=6.0)
RUN = dict(stride=1.05, stance=0.42, lift=0.11, bob=0.06, drop=0.05, sway=0.02, roll=4.0, yaw=8.0, lean=8.0, toe_off=20.0, swing=12.0)


def motions(rig):
    """walk: a shuffly bounce, short steps with the knees giving on each landing, the whole haystack bobbing and its fringe swinging and flaring
    a beat behind; run: the same, bouncier; idle: bobbing to the music in its headphones, mouthing the words, the open hand keeping time"""
    import math
    from kit.gait import Pose, Leg, R, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], F32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]
    yr = math.radians(TOE_OUT)

    def foot(p, lg, ball, pitch):
        s = 1.0 if lg.side == "L" else -1.0
        fw = Vector((s * math.sin(yr), -math.cos(yr), 0.0))
        wf = Matrix.Rotation(math.radians(pitch), 3, Vector((0, 0, 1)).cross(fw))
        ankle = ball + wf @ (rig.head[lg.foot] - lg.ball)
        p.ik[lg.thigh] = (ankle, Vector((s * 0.2, -1.0, 0.0)), lg.foot, wf)

    def swing(p, sw_x, sw_y, flare, wave=0.0, ph=0.0):
        """the fringe's ring: tipped as a whole by (sw_x, sw_y) degrees, flared out by `flare`, a wave running round it"""
        for i in range(SECTORS):
            a = math.radians(i * 360.0 / SECTORS)
            d = Vector((math.sin(a), -math.cos(a), 0.0))
            tangent = Vector((math.cos(a), math.sin(a), 0.0))
            out = flare + wave * math.sin(ph - a * 2.0)
            M = Matrix.Rotation(math.radians(out), 3, tangent) @ R(sw_x, sw_y, 0.0)
            p.delta["fringe.%d" % i] = M

    def walkish(u, g, run):
        p = Pose()
        S, beta = g["stride"], g["stance"]
        b2 = math.cos(2 * TAU * (u - 0.08))                 # the bounce: down just after each landing
        p.offset = Vector((g["sway"] * math.sin(TAU * u), 0.0, -g["drop"] - g["bob"] * max(0.0, b2) * 0.6 + g["bob"] * 0.4 * min(0.0, b2) * -1.0))
        roll = g["roll"] * math.sin(TAU * u)
        yaw = -g["yaw"] * math.cos(TAU * u)
        p.rot("hips", g["lean"], roll, yaw)
        p.rot("body", 1.5 * b2, -roll * 0.5, -yaw * 0.6)
        p.rot("top", -2.0 * math.sin(2 * TAU * u - 0.6), -roll * 0.3, 0.0)
        for lg in legs:
            s = 1.0 if lg.side == "L" else -1.0
            uu = (u + (0.0 if s > 0 else 0.5)) % 1.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                lift, pitch = 0.0, g["toe_off"] * ease((uu - (beta - 0.15)) / 0.15)
            else:
                t = (uu - beta) / (1.0 - beta)
                fy = S * beta / 2 - S * beta * ease(t)
                lift = g["lift"] * math.sin(math.pi * t) ** 0.8
                pitch = g["toe_off"] * (1.0 - ease(t * 1.6)) - g["swing"] * math.sin(math.pi * t)
            foot(p, lg, Vector((lg.ball.x, fy - 0.02, lift)), pitch)
        lag = 2 * TAU * u - 1.3
        swing(p, (5.0 if run else 3.0) * math.sin(lag), (4.0 if run else 2.5) * math.sin(TAU * u - 1.0), (7.0 if run else 4.0) * max(0.0, math.cos(lag)), 2.5, TAU * u)
        c = math.cos(TAU * u)
        for s, sd in ((1.0, "L"), (-1.0, "R")):
            p.rot("upper_arm." + sd, (22.0 if run else 12.0) * c * s, 0.0, 4.0 * math.sin(2 * TAU * u))
            p.rot("forearm." + sd, (10.0 if run else 5.0) * math.sin(2 * TAU * u - 1.0), 0.0, 0.0)
        p.rot("jaw", 3.0 + 2.0 * math.sin(2 * TAU * u), 0.0, 0.0)
        return p

    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        beat = TAU * t * 1.5                                   # nodding along at 90 bpm
        bb = math.sin(beat)
        p.offset = Vector((0.01 * math.sin(TAU * t / 6.0), 0.0, -0.012 - 0.012 * max(0.0, bb)))
        p.rot("hips", 0.0, 2.0 * math.sin(beat / 2.0), 0.0)
        p.rot("body", 2.0 * max(0.0, bb), -1.5 * math.sin(beat / 2.0), 0.0)
        p.rot("top", -4.0 * max(0.0, math.sin(beat - 0.5)), 0.0, 4.0 * math.sin(TAU * t / 6.0))
        for lg in legs:
            foot(p, lg, Vector((lg.ball.x, lg.ball.y - 0.02, 0.0)), 0.0)
        swing(p, 2.0 * math.sin(beat - 1.2), 1.5 * math.sin(beat / 2.0 - 1.0), 2.5 * max(0.0, math.cos(beat - 1.2)), 1.5, beat * 0.5)
        sing = 0.5 + 0.5 * math.sin(TAU * t / 3.0)
        p.rot("jaw", 3.0 + 9.0 * sing * max(0.0, math.sin(beat * 2.0)), 0.0, 0.0)
        p.rot("hand.L", 0.0, 0.0, 12.0 * math.sin(beat))
        p.rot("forearm.L", -5.0 * max(0.0, bb), 0.0, 0.0)
        p.rot("upper_arm.R", 3.0 * math.sin(beat / 2.0), 0.0, 0.0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
