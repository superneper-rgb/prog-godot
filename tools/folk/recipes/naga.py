## FOINT CITY townsfolk: the naga (working name; the user names her). A blue serpent woman, 1.80 m: a woman's body from the hips up on a thick serpent's tail; a wide mask-shaped head with two great gold eyes, small purple lips, bullet earrings, swept purple hair; mesh-and-corset top, a big buckled belt, a ruffled maroon panel down her left side.
# Concept: the user's sheet 5.webp, bottom middle (F:/prog-godot-cache/folk/refs/5.webp, box 413,388,690,779). Measured off it (head top to the coil's floor 373 px, 4.8 mm a pixel):
# the head 0.6 m wide and 0.24 tall, a domino mask: two raised lobes each holding a heavy-lidded gold eye (1.69 m), joined by a pinched bridge with the lips
# (1.645) and narrowing to a point into a thin neck; a buckled choker at 1.48; shoulders 1.37, bust 1.27, corset 1.04-1.25, the belt 0.98; the tail leaves
# her hips 0.32 m wide and comes down to the floor. The concept coils it beside her; for a walker it trails behind her along the ground in an S and curls
# at its tip (kept inside the crowd's culling box, 0.9 m round her).
# Rest pose = her travelling pose: upright on the tail, arms hanging loose a little off her hips.
import math
import os
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3, ridge_line)

HEIGHT = 1.80
REF = ("5.webp", (413, 388, 690, 779))

SKIN, EYE, LIP, NAIL, HAIR, MESH, CORSET, STRAP, GLOVE, RUFFLE, SILVER, LEATHER, TAILP, BELLY = range(1, 15)
COLOURS = {
    SKIN: ((0.22, 0.27, 0.62), 0.5, 0.0),
    TAILP: ((0.16, 0.18, 0.45), 0.5, 0.0),
    BELLY: ((0.30, 0.32, 0.60), 0.5, 0.0),
    EYE: ((0.95, 0.70, 0.20), 0.15, 0.0),
    LIP: ((0.35, 0.08, 0.22), 0.3, 0.0),
    NAIL: ((0.12, 0.05, 0.12), 0.2, 0.0),
    HAIR: ((0.28, 0.10, 0.30), 0.45, 0.0),
    MESH: ((0.05, 0.04, 0.06), 0.6, 0.0),
    CORSET: ((0.03, 0.025, 0.035), 0.35, 0.0),
    STRAP: ((0.03, 0.025, 0.03), 0.35, 0.0),
    GLOVE: ((0.04, 0.035, 0.045), 0.35, 0.0),
    RUFFLE: ((0.30, 0.05, 0.12), 0.65, 0.0),
    SILVER: ((0.78, 0.78, 0.80), 0.25, 1.0),
    LEATHER: ((0.03, 0.025, 0.03), 0.35, 0.0),
}

# landmarks, left side (+X); the figure faces -Y
NECK_TOP = v3((0.0, 0.0, 1.58))
SHOULDER = v3((0.155, 0.015, 1.36))
ELBOW = v3((0.235, 0.05, 1.105))
WRIST = v3((0.265, -0.005, 0.87))
H1 = basis(-(v3((0.04, -0.12, -1.0))), v3((0, 1, 0)))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
# the tail's centre line and radius: down from her hips to the floor, back along it in an S, curling at the tip
TAIL = [(v3((0.0, 0.02, 0.92)), 0.155), (v3((0.0, 0.05, 0.64)), 0.145), (v3((0.0, 0.12, 0.34)), 0.13), (v3((0.0, 0.24, 0.125)), 0.118),
        (v3((0.06, 0.42, 0.10)), 0.10), (v3((-0.03, 0.59, 0.085)), 0.085), (v3((-0.16, 0.70, 0.07)), 0.07), (v3((-0.29, 0.66, 0.055)), 0.055),
        (v3((-0.34, 0.54, 0.04)), 0.04), (v3((-0.29, 0.45, 0.025)), 0.022)]
LAMBDA = 1.0            # the S-wave's length on the ground: one wave cycle carries her this far (her stride)


def hit(shape, o, d, t1=0.8, n=800):
    """where a ray from o along d first enters `shape`, and the surface normal there"""
    o = v3(o)
    d = v3(d) / np.linalg.norm(d)
    ts = np.linspace(0.0, t1, n).astype(np.float32)
    dd = shape.eval(o[None] + ts[:, None] * d[None])[0]
    i = int(np.argmax(dd < 0))
    a, b = float(ts[max(i - 1, 0)]), float(ts[i])
    for _ in range(30):
        m = (a + b) * 0.5
        if shape.eval((o + m * d)[None].astype(np.float32))[0][0] < 0:
            b = m
        else:
            a = m
    p = (o + b * d).astype(np.float32)
    e = 2e-4
    g = np.array([shape.eval((p + ex)[None])[0][0] - shape.eval((p - ex)[None])[0][0] for ex in np.eye(3, dtype=np.float32) * e], np.float32)
    return p, g / np.linalg.norm(g)


# ---------------------------------------------------------------------------------------------------- the head

def head_base():
    """a domino mask of a head: two raised lobes angled up and out, each round a great eye, joined over a pinched bridge, narrowing to a point into the neck"""
    lobes = Mirror(Ellipsoid((0.14, -0.005, 1.695), (0.15, 0.085, 0.085), R=rot(ry=-14)))
    bridge = Ellipsoid((0, -0.02, 1.655), (0.06, 0.07, 0.07))
    chin = Gem((0, 0.0, 1.62), (0.05, 0.05, 0.055, 0.045, 0.07, 0.03), soft=0.6, edge=0.006)
    neck = loft([(v3((0, 0.015, 1.40)), 0.037), (v3((0, 0.01, 1.50)), 0.033), (NECK_TOP, 0.035)])
    core = Union([lobes, bridge, chin], k=0.05)
    return Union([core, neck], k=0.04, part=SKIN)


HEAD0 = head_base()


class Eye:
    def __init__(self, c, f, r, lid, slant, low):
        self.c, self.f, self.r = c, f, r
        up = v3((0, 0, 1)) - f * float(f[2])
        self.up = up / np.linalg.norm(up)
        out = np.cross(self.up, f)
        self.out = out / np.linalg.norm(out)
        self.lid_pt = c + self.up * (lid * r)
        n = -self.up + self.out * slant
        self.lid_n = n / np.linalg.norm(n)
        self.low = low


def _eye():
    d = v3((0.35, -1.0, 0.0))
    d /= np.linalg.norm(d)
    p, n = hit(HEAD0, v3((0.15, -0.0, 1.70)) + d * 0.4, -d)
    f = n * 0.5 + d * 0.5
    f /= np.linalg.norm(f)
    r = 0.045
    return Eye(p - f * (r * 0.45), f, r, 0.3, 0.3, 0.6)


EYE_L = _eye()
MOUTH_Z = 1.645


def head():
    e = EYE_L
    lid = Clip(Sphere(e.c, e.r + 0.006, part=SKIN), [Half(e.lid_pt, e.lid_n)], k=0.004)
    lower = Clip(Sphere(e.c, e.r + 0.0045, part=SKIN), [Half(e.c - e.up * (e.r * e.low), e.up)], k=0.004)
    face = Union([HEAD0, Mirror(Union([lid, lower]))], k=0.008)
    # small full lips on the bridge
    def line(dz, inset, half):
        pts = []
        for xx in np.linspace(-half, half, 9):
            t = xx / half
            p, n = hit(HEAD0, (xx, -0.4, MOUTH_Z + dz + 0.004 * t * t), (0, 1, 0))
            pts.append((p + n * inset, t))
        return pts
    lips = Union([loft([(p, 0.004 + 0.0062 * (1 - t * t)) for p, t in line(0.006, -0.0005, 0.032)], part=LIP, k=0.003),
                  loft([(p, 0.004 + 0.0078 * (1 - t * t) ** 0.7) for p, t in line(-0.0075, 0.0, 0.029)], part=LIP, k=0.003)], k=0.003)
    lips = Cut(lips, [loft([(p, 0.0015) for p, t in line(-0.0005, 0.004, 0.031)])], k=0.0012)
    face = Union([face, lips], k=0.006)
    ball = Mirror(Sphere(e.c, e.r, part=EYE))
    return Union([face, ball], k=0.0)


def hair():
    """the swept purple hair: broad ribbon locks from the crown and the back of the head, falling down her back and curling at their ends"""
    locks = []
    for k, (x, ang, L, W, curl) in enumerate(((0.0, 72, 0.55, 0.10, 0.18), (0.05, 66, 0.62, 0.10, 0.22), (-0.05, 66, 0.62, 0.10, 0.22), (0.09, 60, 0.55, 0.09, 0.26),
                                              (-0.09, 60, 0.55, 0.09, 0.26), (0.025, 80, 0.48, 0.09, 0.15), (-0.025, 80, 0.48, 0.09, 0.15))):
        root = v3((x, 0.03, 1.735))
        a = math.radians(ang)
        eu = v3((x * 0.4, math.cos(a) * 0.6, -math.sin(a)))       # down her back, a little out; the ribbons sweep to her right as they fall
        eu /= np.linalg.norm(eu)
        en = np.cross(eu, v3((1, 0, 0)))
        en /= np.linalg.norm(en)
        ev = np.cross(en, eu)
        R = np.stack([eu, ev, en], 1).astype(np.float32)
        us = np.linspace(0, 1, 7)
        vc = [-curl * L * u ** 2.2 for u in us]
        w = [W * 0.5 * (1 - u ** 1.5) ** 0.7 * (0.8 + 0.2 * min(1.0, u * 4)) for u in us]
        poly = [(u * L, vc[i] + w[i]) for i, u in enumerate(us)] + [(u * L, vc[i] - w[i]) for i, u in enumerate(us)][::-1][1:]
        locks.append(Slab(root, poly, 0.007, rr=0.004, R=R, part=HAIR))
    cap = Clip(Inflate(Ellipsoid((0, 0.03, 1.70), (0.10, 0.08, 0.075)), 0.008, part=HAIR), [Half((0, -0.02, 0), (0, -1, 0))], k=0.01)
    return Union([cap] + locks, k=0.01)


# ---------------------------------------------------------------------------------------------------- the body

def torso_core():
    return Union([
        Ellipsoid((0, 0.02, 1.355), (0.15, 0.065, 0.04)),
        Ellipsoid((0, 0.01, 1.285), (0.115, 0.08, 0.10)),
        Mirror(Ellipsoid((0.054, -0.047, 1.27), (0.056, 0.05, 0.05))),
        Ellipsoid((0, 0.012, 1.09), (0.08, 0.062, 0.09)),
        Ellipsoid((0, 0.02, 0.95), (0.16, 0.125, 0.10)),
    ], k=0.06, part=SKIN)


def tail():
    """the serpent: a thick tube down from her hips and back along the floor, its underside a band of pale belly plates"""
    t = loft([(p, r) for p, r in TAIL], part=TAILP, k=0.04)
    return t


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def top(core):
    """the mesh top over her shoulders and down her upper arms, the corset over it from bust to belt, buckled straps down its front"""
    mesh = Clip(Inflate(core, 0.004, part=MESH), [Half((0, 0, 1.20), (0, 0, -1)), Half((0, 0, 1.43), (0, 0, 1))], k=0.003)
    corset = Clip(Inflate(core, 0.009, part=CORSET), [Half((0, 0, 1.0), (0, 0, -1)), Half((0, 0, 1.30), (0, 0, 1))], k=0.003)
    corset = Cut(corset, [prism([(-0.075, 1.32), (0.075, 1.32), (0.0, 1.25)])], k=0.008)
    belt = Clip(Inflate(Ellipsoid((0, 0.02, 0.98), (0.135, 0.105, 0.06)), 0.012, part=STRAP), [Half((0, 0, 0.958), (0, 0, -1)), Half((0, 0, 1.005), (0, 0, 1))], k=0.002)
    choker = CappedCone((0, 0.015, 1.465), (0, 0.013, 1.50), 0.043, 0.041, rr=0.005, part=LEATHER)
    return Union([mesh, corset, belt, choker], k=0.0)


def arm():
    S, E, W = SHOULDER, ELBOW, WRIST
    up = loft([(S, 0.044), (S + (E - S) * 0.5, 0.037), (E, 0.031)], part=SKIN, k=0.01)
    fore = loft([(E, 0.031), (E + (W - E) * 0.35, 0.033), (W, 0.024)], part=GLOVE, k=0.01)
    glove = Clip(Inflate(up, 0.004, part=GLOVE), [Half(S + (E - S) * 0.55, -(E - S))], k=0.004)
    meshsl = Clip(Inflate(up, 0.003, part=MESH), [Half(S + (E - S) * 0.55, (E - S))], k=0.003)
    return Union([up, fore, glove, meshsl], k=0.008)


def ruffle():
    """the maroon panel down her left side: four tiers of pleated ruffles from the belt to the floor"""
    # a shell wrapped round the left front of the tail's trunk (so it moves with it), flaring toward the floor, stepped into four tiers, pleated.
    # (First built as four flat plates: they read as a floating stair, not a cascade.)
    trunk = loft([(p, r) for p, r in TAIL[:4]], k=0.04)

    def shape(P):
        z = P[:, 2]
        t = np.clip((0.96 - z) / 0.93, 0, 1)
        tier = ((0.96 - z) / 0.235) % 1.0
        ang = np.arctan2(P[:, 0], -(P[:, 1] - 0.05))
        return (0.045 * t + 0.022 * tier + 0.007 * np.sin(ang * 34.0)) / 0.075
    panel = Bump(Inflate(trunk, 0.02), shape, 0.075)
    shell = Cut(panel, [Inflate(trunk, 0.006)], k=0.003)
    shell = Clip(shell, [Half((0.035, 0, 0), (-1, 0, 0)), Half((0, 0.10, 0.9), (0, 1, 0.3)), Half((0, 0, 0.965), (0, 0, 1)), Half((0, 0, 0.02), (0, 0, -1))], k=0.008)
    return Inflate(shell, 0.0, part=RUFFLE)


def body():
    core = torso_core()
    skin = Union([core, tail()], k=0.05)
    return Union([skin, top(core), Mirror(arm()), ruffle()], k=0.0)


def hand():
    parts = [Sphere((0, 0, 0), 0.025, part=SKIN), Ellipsoid((0.0, 0.0, -0.045), (0.016, 0.036, 0.045), part=SKIN)]
    nails = []
    for i, (fy, L) in enumerate(((-0.025, 0.88), (-0.0085, 1.0), (0.008, 0.96), (0.023, 0.8))):
        base = v3((0.0, fy, -0.084))
        pts = [(base, 0.009)]
        a = 0.0
        p = base.copy()
        d = v3((0, 0, -1))
        for k, ln in enumerate((0.034, 0.027, 0.022)):
            a += math.radians(14 + 8 * k)
            d = v3((-math.sin(a), 0.0, -math.cos(a)))
            p = p + d * ln * L
            pts.append((p.copy(), 0.0084 - 0.0009 * k))
        parts.append(loft(pts, part=SKIN, k=0.004))
        nails.append(RoundCone(pts[-1][0] - d * 0.006 + v3((0.002, 0, 0)), pts[-1][0] + d * 0.009, 0.0058, 0.0016, part=NAIL))
    th = [(v3((-0.006, -0.029, -0.024)), 0.0105), (v3((-0.016, -0.045, -0.052)), 0.009), (v3((-0.024, -0.05, -0.078)), 0.0078)]
    parts.append(loft(th, part=SKIN, k=0.004))
    return Union([Union(parts, k=0.008)] + nails, k=0.002)


def hands():
    return Mirror(place(hand(), WRIST, H1))


def jewels():
    out = []
    # bullet earrings from the lobes' lower outer corners
    p, n = hit(HEAD0, (0.25, -0.01, 1.4), (0, 0, 1))
    ear = Union([Torus(p + v3((0, 0, -0.006)), 0.006, 0.002, Rm=rot(ry=90), part=SILVER),
                 CappedCone(p + v3((0, 0, -0.014)), p + v3((0, 0, -0.06)), 0.007, 0.007, rr=0.002, part=SILVER),
                 RoundCone(p + v3((0, 0, -0.06)), p + v3((0, 0, -0.085)), 0.007, 0.001, part=SILVER)], k=0.001)
    out.append(Mirror(ear))
    # bangles: a stack on each wrist
    d = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    for i in range(5):
        Rm = basis(d, v3((0, 1, 0))) @ rot(rx=6 * (1 if i % 2 else -1))
        out.append(Mirror(Torus(WRIST - d * (0.01 + 0.0085 * i), 0.029 + 0.0007 * i, 0.0036, Rm=Rm, part=SILVER)))

    def frame(c, w, h, Rm, t=0.0028):
        return Cut(Box(c, (w, t, h), rr=0.0015, R=Rm, part=SILVER), [Box(c, (w - 0.0045, t * 3, h - 0.0045), R=Rm)], k=0.0)
    # the corset's buckles down its front, the belt's big buckle at her left front, the choker's buckle
    core = Inflate(torso_core(), 0.009)
    for zz in (1.23, 1.17, 1.11, 1.05):
        p, n = hit(core, (0.035, -0.4, zz), (0, 1, 0))
        out.append(frame(p + n * 0.003, 0.012, 0.012, basis(v3((0, 0, 1)), n)))
    p, n = hit(Inflate(Ellipsoid((0, 0.02, 0.98), (0.135, 0.105, 0.06)), 0.012), (0.08, -0.4, 0.982), (0, 1, 0))
    out.append(frame(p + n * 0.004, 0.032, 0.03, basis(v3((0, 0, 1)), n), t=0.004))
    out.append(Torus(p + n * 0.006 + v3((0.0, 0, -0.04)), 0.01, 0.0025, Rm=basis(n, v3((0, 0, 1))), part=SILVER))
    out.append(frame(v3((0, -0.03, 1.483)), 0.012, 0.012, np.eye(3, dtype=np.float32)))
    return Union(out, k=0.0)


def pieces():
    only = os.environ.get("FOLK_ONLY", "")
    out = [("head", head, 0.0018), ("hair", hair, 0.003), ("body", body, 0.0036), ("hands", hands, 0.002), ("jewels", jewels, 0.0015)]
    return [(n, f(), h) for n, f, h in out if not only or n in only.split(",")]


# ---------------------------------------------------------------------------------------------------- paint

def tail_coords(P):
    """(arc length down the tail from her hips, angle round it measured from its underside, distance from its centre line) for each point"""
    best = np.full(len(P), 1e9, np.float32)
    s_out = np.zeros(len(P), np.float32)
    a_out = np.zeros(len(P), np.float32)
    s0 = 0.0
    for (a, _), (b, _) in zip(TAIL[:-1], TAIL[1:]):
        ab = b - a
        L = float(np.linalg.norm(ab))
        t = np.clip(((P - a) @ ab) / (L * L), 0, 1)
        q = P - a - np.outer(t, ab)
        d = np.linalg.norm(q, axis=1)
        take = d < best
        best[take] = d[take]
        s_out[take] = (s0 + t * L)[take]
        u = ab / L
        dn = v3((0, 0, -1)) if abs(u[2]) < 0.7 else v3((0, 1, 0))
        e1 = dn - u * float(dn @ u)
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(u, e1)
        a_out[take] = np.arctan2(q @ e2, q @ e1)[take]
        s0 += L
    return s_out, a_out, best


def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.009) * 0.25
    n3 = noise3(P + 4.1, 0.05)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def mix(a, b, t):
        return a + (b - a) * np.asarray(t, np.float32)[:, None]

    def spk(m, col, amount):
        c.spk[m] = np.concatenate([np.broadcast_to(srgb(*col), (int(m.sum()), 3)), np.broadcast_to(np.float32(amount), (int(m.sum()), 1))], 1)

    # skin: periwinkle, dappled, with fine dark freckles; the eyes' lids a heavy purple, inked, flicked out at the corners
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(92, 108, 196), (len(P), 3)).copy() * (1.0 + 0.07 * mott)[:, None]
    sk = mix(sk, srgb(124, 142, 220), c.wear * 0.4)
    e = EYE_L
    de = Q - e.c
    r = np.linalg.norm(de, axis=1)
    pd = (Q - e.lid_pt) @ e.lid_n
    sk = mix(sk, srgb(104, 52, 132), ((r < e.r + 0.018) & (pd < 0.0)) * smooth(-0.04, -0.004, pd) * 0.85)
    sk = mix(sk, srgb(70, 60, 140), smooth(e.r + 0.02, e.r + 0.006, r) * (de @ e.f > -0.02) * 0.5)
    c.draw((r < e.r + 0.014) & (pd > -0.01) & (pd < 0.005) & (de @ e.f > -0.012), np.abs(pd + 0.0012), 0.003)
    wt = ((de @ e.out) - e.r * 0.75) / 0.04
    c.draw((wt > 0) & (wt < 1) & (r < e.r + 0.05) & (np.abs(pd) < 0.02), np.abs(pd + 0.0012 - 0.012 * np.clip(wt, 0, 1) ** 1.2), 0.003 * (1 - np.clip(wt, 0, 1)) + 0.0002)
    pl = (Q - (e.c - e.up * (e.r * e.low))) @ e.up
    c.draw((r < e.r + 0.012) & (np.abs(pl) < 0.006) & (de @ e.f > -0.008), np.abs(pl - 0.001), 0.0012, 0.8)
    put(m, sk[m], 0.45, bump=0.2)
    spk(m, (30, 30, 70), 0.3)
    # eyes: gold, amber to the rim, a dark round pupil looking ahead, a glint
    m = c.mask(EYE)
    d = de / np.maximum(r, 1e-6)[:, None]
    g = e.f * 0.5 + v3((0, -1, 0)) * 0.5
    g /= np.linalg.norm(g)
    ang = np.arccos(np.clip(d @ g, -1, 1))
    ec = mix(np.broadcast_to(srgb(255, 214, 96), (len(P), 3)), srgb(230, 150, 40), smooth(0.2, 0.7, ang))
    ec = mix(ec, srgb(130, 70, 20), smooth(0.75, 1.05, ang))
    ec *= (1.0 - 0.45 * smooth(-0.05, 0.3, d @ e.up))[:, None]
    c.draw(m, (ang - 0.17) * e.r, 0.0)
    gd = g + e.up * 0.35 - e.out * 0.2
    gd /= np.linalg.norm(gd)
    ec = mix(ec, srgb(255, 252, 236), smooth(0.985, 0.993, d @ gd))
    put(m, ec[m], 0.06)
    put(c.mask(LIP), srgb(112, 32, 74), 0.25, bump=0.2)
    put(c.mask(NAIL), srgb(60, 24, 64), 0.15)
    # hair: plum-purple ribbons, bright along their edges, darker at the roots
    m = c.mask(HAIR)
    hc = mix(np.broadcast_to(srgb(96, 40, 100), (len(P), 3)), srgb(150, 76, 150), c.wear * 0.6 + smooth(1.6, 1.2, z) * 0.2)
    put(m, (hc * (1.0 + 0.1 * noise3(P, 0.006))[:, None])[m], 0.4, bump=0.3)
    # the tail: indigo scales in rows, each plate its own shade, scuffed orange-brown in patches; a paler belly
    m = c.mask(TAILP)
    s, a, dist = tail_coords(P)
    row = np.floor(s / 0.07).astype(np.int64)
    col_i = np.floor(a / (2 * math.pi / 9) + 0.5 * (row % 2)).astype(np.int64)
    h = (row * 73856093) ^ (col_i * 19349663)
    tone = (((h ^ (h >> 13)) * 1274126177) >> 8 & 1023).astype(np.float32) / 1023.0
    tc = mix(np.broadcast_to(srgb(66, 74, 150), (len(P), 3)), srgb(92, 98, 176), tone * 0.7)
    tc = mix(tc, srgb(178, 108, 64), smooth(0.35, 0.75, n3 + noise3(P, 0.012) * 0.4) * 0.65)
    belly = smooth(0.9, 0.5, np.abs(a))
    tc = mix(tc, srgb(110, 120, 190), belly * 0.6)
    put(m, tc[m], 0.42, bump=0.6, grain=1.0)
    fr = s / 0.07 - np.floor(s / 0.07)
    c.draw(m, np.minimum(fr, 1 - fr) * 0.07, 0.0011, 0.55)
    fa = a / (2 * math.pi / 9) + 0.5 * (row % 2)
    fa = fa - np.floor(fa)
    c.draw(m & (np.minimum(fa, 1 - fa) < 0.15), np.minimum(fa, 1 - fa) * dist * 2 * math.pi / 9, 0.0009, 0.45)
    # the mesh: a fine dark net over blue skin
    m = c.mask(MESH)
    put(m, (srgb(70, 80, 150) * (1.0 + 0.05 * mott)[:, None])[m], 0.5, bump=0.2)
    sp = 0.009
    u1 = (P[:, 0] + z) / sp
    u2 = (P[:, 0] - z) / sp
    c.draw(m, np.minimum(np.abs(u1 - np.round(u1)), np.abs(u2 - np.round(u2))) * sp * 0.7071, 0.0008, 0.9)
    # leather, satin gloves, the ruffle
    for parts, base, rough in (((CORSET,), (30, 26, 34), 0.3), ((STRAP, LEATHER), (24, 21, 26), 0.32), ((GLOVE,), (26, 24, 30), 0.28)):
        m = c.mask(*parts)
        put(m, (srgb(*base) * (1.0 + 1.3 * c.wear + 0.06 * mott)[:, None])[m], rough, bump=0.5, grain=1.0 if parts[0] != GLOVE else 0.0)
    m = c.mask(CORSET)
    c.draw(m & (np.abs(Q[:, 0] - 0.06) < 0.006), np.abs(Q[:, 0] - 0.06), 0.0008, 0.5)
    m = c.mask(RUFFLE)
    put(m, (srgb(128, 34, 72) * (1.0 + 0.6 * c.wear - 0.45 * c.cavity + 0.05 * mott)[:, None])[m], 0.6, bump=0.6)
    m = c.mask(SILVER)
    put(m, (srgb(212, 210, 218) * (1.0 - 0.5 * c.cavity)[:, None])[m], 0.22, metal=1.0, bump=0.05, grain=1.0)
    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 2000, "hair": 1000, "body": 5000, "hands": 900, "jewels": 800},
    "density": {"head": 1.7, "hands": 1.2, "jewels": 1.2},
    "tex": 2048,
    "stride": {"walk": LAMBDA, "run": 1.6},            # one S-wave cycle carries her one wavelength
    "speed": 0.85,
    "look": ["head", "hair"], "neck": "neck",
    "look_pivot": (0.0, 0.0, 1.58),
    "radius": 0.45,
}
TAIL_BONES = ["tail1", "tail2", "tail3", "tail4", "tail5", "tail6", "tail7", "tail8"]
RUFFLE_A, RUFFLE_B = v3((0.16, -0.075, 0.95)), v3((0.18, -0.06, 0.06))


def rig_bones():
    from kit.rig import Bone, mirror
    bones = [
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", TAIL[0][0], (0, 0.015, 1.05), "root", 0.15),
        Bone("spine", (0, 0.015, 1.05), (0, 0.012, 1.20), "hips", 0.08),
        Bone("chest", (0, 0.012, 1.20), (0, 0.02, 1.38), "spine", 0.1),
        Bone("neck", (0, 0.015, 1.42), NECK_TOP, "chest", 0.035),
        Bone("head", NECK_TOP, (0, 0.0, 1.79), "neck", 0.05),
        Bone("hair", (0, 0.05, 1.70), (0, 0.17, 1.25), "head", 0.05),
        Bone("ruffle", RUFFLE_A, RUFFLE_B, "hips", 0.05),
        Bone("shoulder.L", (0.03, 0.02, 1.36), SHOULDER, "chest", 0.04),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.04),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.032),
        Bone("hand.L", WRIST, WRIST - H1[:, 2] * 0.17, "forearm.L", 0.03),
    ]
    ends = [0, 1, 2, 3, 4, 5, 6, 7, 9]
    for k, nm in enumerate(TAIL_BONES):
        a, b = TAIL[ends[k]], TAIL[ends[k + 1]]
        bones.append(Bone(nm, a[0], b[0], "hips" if k == 0 else TAIL_BONES[k - 1], a[1] * 0.85))
    return mirror(bones)


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for vertices that move rigidly). piece: 0 head, 1 hair, 2 body, 3 hands, 4 jewels"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    L, Rt = x > 0, x <= 0
    fl = FLIP.diagonal()

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True

    def seg(a, b):
        ab = b - a
        t = np.clip(((P - a) @ ab) / float(ab @ ab), 0, 1)
        return np.linalg.norm(P - a - np.outer(t, ab), axis=1)
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 1.57)] = ix["head"]
    hr = piece == 1
    allow(hr, "head", "hair")
    rig[hr & (z > 1.66) & (y < 0.08)] = ix["head"]
    bp = piece == 2
    # the tail: each vertex may take the segment it lies on and its neighbours
    ends = [0, 1, 2, 3, 4, 5, 6, 7, 9]
    D = np.stack([seg(TAIL[ends[k]][0], TAIL[ends[k + 1]][0]) for k in range(8)], 1)
    near = np.argmin(D, 1)
    tl = bp & np.isin(part, (TAILP, RUFFLE))      # the ruffle wraps the trunk and goes with it
    for k, nm in enumerate(TAIL_BONES):
        m = tl & (np.abs(near - k) <= 1)
        allow(m, nm)
    allow(tl & (near <= 0), "hips")
    armd = np.minimum(np.minimum(seg(SHOULDER, ELBOW), seg(ELBOW, WRIST)), np.minimum(seg(SHOULDER * fl, ELBOW * fl), seg(ELBOW * fl, WRIST * fl)))
    arm = bp & ~tl & (armd < 0.05) & (np.abs(x) > 0.15)
    allow(arm & L, "shoulder.L", "upper_arm.L", "forearm.L")
    allow(arm & Rt, "shoulder.R", "upper_arm.R", "forearm.R")
    allow(arm & (z > 1.3), "chest")
    ruf = np.zeros(n, bool)                         # (the ruffle is skinned with the tail above)
    allow(ruf, "ruffle", "hips")
    rig[ruf & (z < 0.85)] = ix["ruffle"]
    choker = bp & (part == LEATHER)
    allow(choker, "neck")
    rig[choker] = ix["neck"]
    torso = bp & ~tl & ~arm & ~ruf & ~choker
    allow(torso, "hips", "spine", "chest")
    allow(torso & (z < 1.0), "tail1")
    allow(torso & L & (x > 0.09) & (z > 1.28), "shoulder.L")
    allow(torso & Rt & (x < -0.09) & (z > 1.28), "shoulder.R")
    hd = piece == 3
    allow(hd & L, "hand.L")
    allow(hd & Rt, "hand.R")
    rig[hd & L] = ix["hand.L"]
    rig[hd & Rt] = ix["hand.R"]
    jp = piece == 4
    ear = jp & (z > 1.5) & (np.abs(x) > 0.15)
    allow(ear, "head")
    rig[ear] = ix["head"]
    bang = jp & ~ear & (np.minimum(np.linalg.norm(P - WRIST, axis=1), np.linalg.norm(P - WRIST * fl, axis=1)) < 0.07)
    allow(bang & L, "forearm.L")
    allow(bang & Rt, "forearm.R")
    rig[bang & L] = ix["forearm.L"]
    rig[bang & Rt] = ix["forearm.R"]
    chk = jp & ~ear & ~bang & (z > 1.44)
    allow(chk, "neck")
    rig[chk] = ix["neck"]
    belt = jp & ~ear & ~bang & ~chk & (z < 1.02)
    allow(belt, "hips")
    rig[belt] = ix["hips"]
    rest = jp & ~ear & ~bang & ~chk & ~belt
    allow(rest, "spine", "chest")
    rig[rest] = ix["chest"]
    return A, rig


def motions(rig):
    """her clips: walk (she slithers: an S-wave runs back along the tail on the floor as fast as she goes forward, so the tail slides along its own
    track; the trunk under her hips sways with it and her upright body counters it, hips rolling, arms loose, head level; one wave cycle is one stride),
    run (a faster, wider wave, the body bent forward, the hair streaming), idle (the concept's pose: one hand behind her head, one on her hip, the
    tail's tip curling and flicking, a slow sway)"""
    from kit.gait import Pose, R, TAU, ease
    from mathutils import Vector, Matrix
    F3 = Matrix(FLIP.tolist())
    ground = [3, 4, 5, 6, 7]                      # the bones that lie along the floor (tail4..tail8)
    sk = [0.0]
    for (a, _), (b, _) in zip(TAIL[3:-1], TAIL[4:]):
        sk.append(sk[-1] + float(np.linalg.norm((b - a)[:2])))
    ends = [3, 4, 5, 6, 7, 9]
    s_at = [sk[min(ends[i] - 3, len(sk) - 1)] for i in range(len(ends))]

    def slither(p, u, th0, lam, sway, lean, run):
        th = lambda s: th0 * math.sin(TAU * (s / lam - u))
        prev = 0.0
        for i, k in enumerate(ground):
            ang = th(s_at[i])
            p.rot(TAIL_BONES[k], 0, 0, ang - prev)
            prev = ang
        # the trunk sways with the wave where it meets the floor; her body above counters it
        tw = th(-0.15)
        p.rot("tail1", 0, -0.35 * tw, 0)
        p.rot("tail2", 0, -0.25 * tw, 0)
        p.rot("tail3", 0, 0.6 * tw, 0.3 * tw)
        p.offset = Vector((sway * math.sin(TAU * (0.15 / lam - u) + 0.6), 0.0, 0.006 * math.sin(2 * TAU * u)))
        p.rot("hips", 0.0, 0.25 * tw, -0.2 * tw)
        p.rot("spine", lean * 0.6, 0.3 * tw, 0.25 * tw)
        p.rot("chest", lean * 0.4, 0.2 * tw, 0.2 * tw)
        A = 26.0 if run else 10.0
        for side, s in (("L", 1.0), ("R", -1.0)):
            ph = TAU * u + (0.0 if s > 0 else math.pi)
            p.rot("upper_arm." + side, A * math.cos(ph), -s * (4.0 + (8.0 if run else 0.0)), 0)
            p.rot("forearm." + side, -(50.0 if run else 12.0) + A * 0.4 * (math.cos(ph - 0.8) - math.cos(ph)), 0, 0)
            p.rot("hand." + side, 6.0 * math.cos(ph - 1.5), 0, 0)
        p.rot("neck", -0.5 * lean + 2.0 * math.sin(2 * TAU * u - 1.0), 0, 0)
        p.world["head"] = R(-2.0 + 1.5 * math.sin(2 * TAU * u - 1.6), 0, 4.0 * math.sin(TAU * u - 0.8))
        p.rot("hair", (22.0 if run else 6.0) + 5.0 * math.sin(2 * TAU * u - 2.0), 0, 6.0 * math.sin(TAU * u - 1.6))
        p.rot("ruffle", (10.0 if run else 3.0) + 4.0 * math.sin(2 * TAU * u - 1.2), 0, 3.0 * math.sin(TAU * u - 1.0))
        return p
    walk = [slither(Pose(), i / 32.0, 24.0, LAMBDA, 0.03, 2.0, False) for i in range(33)]
    run = [slither(Pose(), i / 24.0, 32.0, 1.6, 0.045, 14.0, True) for i in range(25)]

    def hand_rot(fingers, back):
        zz = -np.asarray(fingers, np.float64)
        zz /= np.linalg.norm(zz)
        xx = np.asarray(back, np.float64)
        xx = xx - zz * (xx @ zz)
        xx /= np.linalg.norm(xx)
        D = np.stack([xx, np.cross(zz, xx), zz], 1)
        return Matrix((D @ H1.T.astype(np.float64)).tolist())
    behind = hand_rot((-0.6, 0.3, 0.75), (0.0, 0.6, -0.8))
    onhip = hand_rot((-0.3, -0.7, -0.6), (0.85, 0.0, 0.5))
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sw = math.sin(TAU * t / 6.0)
        p.offset = Vector((0.02 * sw, 0.0, 0.004 * math.sin(TAU * t / 3.0)))
        p.rot("hips", 0, 3.0 * sw, -4.0)
        p.rot("tail1", 0, -2.5 * sw, 0)
        p.rot("spine", 0, -2.0 * sw, 3.0)
        p.rot("chest", 1.0 * math.sin(TAU * t / 3.0), -1.5 * sw, 2.0)
        # her left hand behind her head, her right on her hip
        p.ik["upper_arm.L"] = (Vector((0.07, 0.09, 1.665)), Vector((1.0, 0.2, 0.9)), "hand.L", behind)
        p.ik["upper_arm.R"] = (F3 @ Vector((0.18, 0.005, 1.0)), F3 @ Vector((1.0, 0.4, 0.1)), "hand.R", F3 @ onhip @ F3)
        # the tail's end curls and flicks
        for k, amp, lag in ((5, 4.0, 0.0), (6, 8.0, 0.6), (7, 14.0, 1.2)):
            p.rot(TAIL_BONES[k], 0, 0, amp * math.sin(TAU * t / 3.0 - lag) + (10.0 if k == 7 else 0.0) * math.sin(TAU * t * 2.0) * ease((t - 3.5) / 0.2) * (1 - ease((t - 4.4) / 0.3)))
        p.world["head"] = R(-4.0 + 1.5 * math.sin(TAU * t / 3.0), 6.0, 8.0 * math.sin(TAU * t / 6.0 + 0.7))
        p.rot("hair", 2.0 * math.sin(TAU * t / 3.0 - 0.8), 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
