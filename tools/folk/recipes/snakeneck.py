## FOINT CITY townsfolk: the snakeneck (working name; the user names them). A very tall pale goth, 2.30 m: a long serpent neck rising out of a cropped leather jacket and hooking over into a long paddle of a head, five eyes and full ringed lips on its face; mesh shirt, purple sash, pinstriped flares, heeled boots.
# Concept: the user's sheet 5.webp, bottom left (F:/prog-godot-cache/folk/refs/5.webp, box 83,381,354,781). Measured off it (crook top to heel 389 px, 5.9 mm a pixel):
# the neck 12-13 cm thick, rising from a cuff at 1.69 m, leaning to their right as it climbs, hooking over at 2.29 m; the head hangs from the hook out to
# their left, a flattened paddle 0.57 m long and 0.22 thick, its face to the front: two rows of eyes (two over three; the brief said four, the concept shows
# five, so five), full mauve lips low on its far end with a ring through the lower lip. Wide padded shoulders (jacket 1.75), a slim mesh-shirted torso,
# the jacket cropped at 1.42, the sash 1.31, belt 1.24, crotch 1.06, knees 0.67, trouser hems over the boots at 0.30, heels 8 cm.
# Rest pose = the walking pose: arms hanging long and loose a little off the jacket, the neck in the concept's hook.
import math
import os
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3, ridge_line)

HEIGHT = 2.30
REF = ("5.webp", (83, 381, 354, 781))

SKIN, EYE, LIP, NAIL, MESH, JACKET, SASH, TROUSERS, BELT, SILVER, BOOT, SOLE, LEATHER, NECK = range(1, 15)
COLOURS = {
    SKIN: ((0.62, 0.55, 0.56), 0.5, 0.0),
    NECK: ((0.62, 0.55, 0.56), 0.5, 0.0),
    EYE: ((0.08, 0.10, 0.09), 0.1, 0.0),
    LIP: ((0.50, 0.20, 0.30), 0.3, 0.0),
    NAIL: ((0.10, 0.07, 0.08), 0.2, 0.0),
    MESH: ((0.10, 0.06, 0.07), 0.6, 0.0),
    JACKET: ((0.05, 0.04, 0.045), 0.35, 0.0),
    SASH: ((0.30, 0.10, 0.32), 0.6, 0.0),
    TROUSERS: ((0.06, 0.045, 0.05), 0.7, 0.0),
    BELT: ((0.03, 0.025, 0.03), 0.4, 0.0),
    SILVER: ((0.78, 0.78, 0.80), 0.25, 1.0),
    BOOT: ((0.05, 0.035, 0.04), 0.2, 0.0),
    SOLE: ((0.02, 0.02, 0.02), 0.5, 0.0),
    LEATHER: ((0.06, 0.04, 0.04), 0.4, 0.0),
}

# landmarks, left side (+X); the figure faces -Y
NECK_PTS = [v3((0.0, 0.03, 1.62)), v3((-0.03, 0.035, 1.80)), v3((-0.085, 0.03, 1.98)), v3((-0.10, 0.02, 2.13)), v3((-0.06, 0.0, 2.205)), v3((0.03, -0.015, 2.225))]
HEAD_A = v3((0.06, -0.025, 2.19))       # where the head leaves the hook
HEAD_B = v3((0.61, -0.073, 2.011))       # the far, rounded end of the paddle (round 2: the paddle 38% longer, as long as the shoulders are wide)
SHOULDER = v3((0.21, 0.02, 1.70))
ELBOW = v3((0.29, 0.06, 1.37))
WRIST = v3((0.32, 0.0, 1.06))
HIP = v3((0.10, 0.015, 1.11))
KNEE = v3((0.12, -0.01, 0.67))
ANKLE = v3((0.135, 0.035, 0.14))
BALL = v3((0.14, -0.085, 0.0))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
H1 = basis(-(v3((0.04, -0.10, -1.0))), v3((0, 1, 0)))


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


# ---------------------------------------------------------------------------------------------------- the neck and head

def head_base():
    """the neck: a thick smooth tube from the cuff up, hooking over; the head: a flattened paddle hung from the hook, its face on the front"""
    neck = loft([(p, r) for p, r in zip(NECK_PTS, (0.058, 0.06, 0.062, 0.064, 0.066, 0.07))], k=0.03)
    ax = (HEAD_B - HEAD_A) / np.linalg.norm(HEAD_B - HEAD_A)
    Rh = basis(v3((0, -1, 0.15)), ax)              # local Y along the paddle, local Z out of the face, local X across it (up)
    mid = (HEAD_A + HEAD_B) * 0.5
    paddle = Ellipsoid(mid, (0.18, 0.385, 0.13), R=Rh)
    tip = Ellipsoid(HEAD_B - ax * 0.07, (0.165, 0.12, 0.125), R=Rh)
    return Union([Union([neck], k=0.0, part=NECK), Union([paddle, tip], k=0.05, part=SKIN)], k=0.07)


HEAD0 = head_base()
_AX = (HEAD_B - HEAD_A) / np.linalg.norm(HEAD_B - HEAD_A)


class Eye:
    def __init__(self, c, f, r, lid, low):
        self.c, self.f, self.r = c, f, r
        up = np.cross(f, _AX)
        if up[2] < 0:
            up = -up
        self.up = up / np.linalg.norm(up)
        self.lid_pt = c + self.up * (lid * r)
        self.lid_n = -self.up
        self.low = low


def _eye(t, h, r):
    """an eye at fraction t along the paddle, h above its middle line, set into the face"""
    o = HEAD_A + (HEAD_B - HEAD_A) * t
    up = np.cross(v3((0, -1, 0)), _AX)
    up = up / np.linalg.norm(up) * (1 if up[2] > 0 else -1)
    o = o + up * h + v3((0, -0.4, 0))
    p, n = hit(HEAD0, o, (0, 1, 0))
    return Eye(p - n * r * 0.4, n, r, 0.18, 0.55)


EYES = [_eye(0.33, 0.085, 0.034), _eye(0.56, 0.075, 0.034), _eye(0.30, -0.005, 0.034), _eye(0.53, -0.012, 0.034), _eye(0.75, -0.005, 0.033)]
MOUTH = (0.80, -0.10)          # fraction along the paddle, height below its middle line


def lip_line(dh, inset, half=0.11, n=15):
    pts = []
    for s in np.linspace(-1.0, 1.0, n):
        t = MOUTH[0] + s * half / np.linalg.norm(HEAD_B - HEAD_A)
        o = HEAD_A + (HEAD_B - HEAD_A) * t
        up = np.cross(v3((0, -1, 0)), _AX)
        up = up / np.linalg.norm(up) * (1 if up[2] > 0 else -1)
        smile = 0.018 * max(0.0, -s) ** 2.0 + 0.006 * s * s
        o = o + up * (MOUTH[1] + dh + smile) + v3((0, -0.4, 0))
        p, nn = hit(HEAD0, o, (0, 1, 0))
        pts.append((p + nn * inset, s))
    return pts


def head():
    face = HEAD0
    rims, balls = [], []
    for e in EYES:
        lid = Clip(Sphere(e.c, e.r + 0.0045, part=SKIN), [Half(e.lid_pt, e.lid_n)], k=0.003)
        lower = Clip(Sphere(e.c, e.r + 0.0035, part=SKIN), [Half(e.c - e.up * (e.r * e.low), e.up)], k=0.003)
        rims += [lid, lower]
        balls.append(Sphere(e.c, e.r, part=EYE))
    face = Union([face] + rims, k=0.006)
    up = lip_line(0.018, -0.001)
    lo = lip_line(-0.018, 0.0, half=0.10)
    lips = Union([loft([(p, 0.010 + 0.016 * (1 - s * s)) for p, s in up], part=LIP, k=0.005),
                  loft([(p, 0.010 + 0.022 * (1 - s * s) ** 0.7) for p, s in lo], part=LIP, k=0.005)], k=0.005)
    part_line = lip_line(0.0, 0.006, half=0.106)
    lips = Cut(lips, [loft([(p, 0.003) for p, s in part_line])], k=0.002)
    face = Union([face, lips], k=0.009)
    return Union([face] + balls, k=0.0)


def lip_ring():
    p, s = lip_line(-0.018, 0.0, half=0.10)[9]
    return Torus(p + v3((0, -0.014, -0.026)), 0.025, 0.0042, Rm=rot(ry=90) @ rot(rx=-25), part=SILVER)


# ---------------------------------------------------------------------------------------------------- the body

def torso_core():
    """slim: a narrow chest under wide shoulders, a slim waist, narrow hips"""
    return Union([
        Ellipsoid((0, 0.025, 1.665), (0.185, 0.075, 0.05)),
        Ellipsoid((0, 0.015, 1.55), (0.13, 0.085, 0.15)),
        Ellipsoid((0, 0.015, 1.33), (0.10, 0.07, 0.11)),
        Ellipsoid((0, 0.015, 1.18), (0.14, 0.10, 0.10)),
    ], k=0.06, part=MESH)


def prism(poly_xz, y0=-0.5, y1=0.0):
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def sleeve():
    S, E, W = SHOULDER, ELBOW, WRIST
    d = (W - E) / np.linalg.norm(W - E)
    s = loft([(S, 0.058), (S + (E - S) * 0.5, 0.05), (E, 0.046), (W - d * 0.02, 0.042)], part=JACKET, k=0.015)
    return Clip(s, [Half(W - d * 0.02, d)], k=0.003)


def jacket(core):
    """the cropped leather jacket: pointed padded shoulders, notched lapels, open over the mesh shirt, sleeves to the wrist"""
    shell = Union([Inflate(core, 0.018), Mirror(Box((0.19, 0.02, 1.705), (0.055, 0.07, 0.03), rr=0.025))], k=0.03, part=JACKET)
    shell = Clip(shell, [Half((0, 0, 1.42), (0, 0, -1))], k=0.004)
    shell = Union([shell, Mirror(sleeve())], k=0.02, part=JACKET)
    opening = prism([(-0.05, 1.74), (0.05, 1.74), (0.07, 1.55), (0.11, 1.40), (-0.11, 1.40), (-0.07, 1.55)])
    shell = Cut(shell, [opening], k=0.008)
    lapel = Clip(Inflate(core, 0.028, part=JACKET), [Mirror(prism([(0.052, 1.72), (0.07, 1.53), (0.13, 1.62), (0.14, 1.66), (0.115, 1.672), (0.13, 1.71)]))], k=0.006)
    collar = CappedCone((0, 0.03, 1.615), (0, 0.03, 1.68), 0.075, 0.068, rr=0.008, part=LEATHER)
    return Union([shell, lapel, collar], k=0.0)


def sash():
    """the purple sash: wound twice round the waist, knotted on the right hip, its long end hanging to the knee"""
    wrap = Clip(Inflate(Ellipsoid((0, 0.015, 1.30), (0.11, 0.08, 0.06)), 0.018, part=SASH), [Half((0, 0, 1.275), (0.1, 0, -1)), Half((0, 0, 1.335), (-0.1, 0, 1))], k=0.004)
    knot = Ellipsoid((-0.12, -0.045, 1.29), (0.04, 0.035, 0.035), part=SASH)
    R = basis(v3((0.2, -1.0, 0.0)), v3((0, 0, 1)))
    tail = Slab((-0.15, -0.035, 1.07), [(-0.05, 0.21), (0.05, 0.21), (0.065, -0.05), (0.02, -0.21), (-0.07, -0.16)], 0.008, rr=0.006, R=R, part=SASH)

    def folds(P):
        return np.sin(P[:, 0] * 140.0 + P[:, 2] * 12.0)
    tail = Bump(tail, folds, 0.004)
    return Union([wrap, knot, tail], k=0.012)


def legs():
    hips = Ellipsoid((0, 0.015, 1.17), (0.145, 0.105, 0.105), part=TROUSERS)
    leg = loft([(HIP, 0.085), (v3((0.11, 0.0, 0.90)), 0.07), (KNEE, 0.058), (v3((0.13, 0.015, 0.45)), 0.07), (v3((0.135, 0.025, 0.30)), 0.10)], part=TROUSERS, k=0.03)
    leg = Clip(leg, [Half((0, 0, 0.30), (0, -0.2, -1))], k=0.004)
    trousers = Union([hips, Mirror(leg)], k=0.04)
    return Clip(trousers, [Half((0, 0, 1.25), (0, 0, 1))], k=0.003)


def belt():
    hipcore = Ellipsoid((0, 0.015, 1.17), (0.145, 0.105, 0.105))
    return Clip(Inflate(hipcore, 0.009, part=BELT), [Half((0, 0, 1.257), (0, 0, 1)), Half((0, 0, 1.228), (0, 0, -1))], k=0.002)


def boot():
    shaft = RoundCone(ANKLE + v3((0, 0.005, 0.12)), ANKLE, 0.048, 0.042, part=BOOT)
    foot = loft([(ANKLE + v3((0, 0.012, -0.012)), 0.04), (BALL + v3((0, 0, 0.036)), 0.036), (v3((0.142, -0.16, 0.022)), 0.02), (v3((0.143, -0.215, 0.013)), 0.006)], part=BOOT, k=0.012)
    heel = Box((0.135, 0.055, 0.04), (0.026, 0.026, 0.04), rr=0.004, part=SOLE)
    return Union([Union([shaft, foot], k=0.015), heel], k=0.004)


def body():
    core = torso_core()
    arm = loft([(SHOULDER, 0.045), (ELBOW, 0.037), (WRIST, 0.025)], part=SKIN, k=0.01)
    return Union([core, Mirror(arm), jacket(core), sash(), legs(), belt(), Mirror(boot())], k=0.0)


def hand():
    """a long hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): slim, the fingers long and a little curled"""
    parts = [Sphere((0, 0, 0), 0.024, part=SKIN), Ellipsoid((0.0, 0.0, -0.05), (0.014, 0.033, 0.052), part=SKIN)]
    nails = []
    for i, (fy, L) in enumerate(((-0.024, 0.9), (-0.008, 1.0), (0.008, 0.96), (0.023, 0.8))):
        base = v3((0.0, fy, -0.095))
        pts = [(base, 0.0085)]
        a = 0.0
        p = base.copy()
        d = v3((0, 0, -1))
        for k, ln in enumerate((0.045, 0.035, 0.028)):
            a += math.radians(10 + 7 * k)
            d = v3((-math.sin(a), 0.0, -math.cos(a)))
            p = p + d * ln * L
            pts.append((p.copy(), 0.0078 - 0.0008 * k))
        parts.append(loft(pts, part=SKIN, k=0.004))
        parts.append(Sphere(pts[1][0] + v3((0.002, 0, 0)), 0.0088, part=SKIN))
        nails.append(RoundCone(pts[-1][0] - d * 0.006 + v3((0.0018, 0, 0)), pts[-1][0] + d * 0.006, 0.0058, 0.0025, part=NAIL))
    th = [(v3((-0.006, -0.028, -0.026)), 0.01), (v3((-0.016, -0.044, -0.058)), 0.0085), (v3((-0.022, -0.05, -0.086)), 0.0074)]
    parts.append(loft(th, part=SKIN, k=0.004))
    return Union([Union(parts, k=0.007)] + nails, k=0.002)


def hands():
    return Mirror(place(hand(), WRIST, H1))


def jewels():
    out = [lip_ring()]
    # two chains on the mesh shirt, the lower with a triangle pendant
    core = Inflate(torso_core(), 0.004)
    for drop, r in ((0.08, 0.0022), (0.15, 0.0026)):
        pts = []
        for t in np.linspace(0.0, 1.0, 8):
            x = 0.06 * (1.0 - t)
            z = 1.62 - drop * t ** 1.3
            p, n = hit(core, (x, -0.4, z), (0, 1, 0))
            pts.append((p + n * 0.003, r))
        out.append(Mirror(loft(pts, part=SILVER, k=0.002)))
    end = pts[-1][0]
    out.append(Slab(end + v3((0, -0.004, -0.028)), [(-0.017, 0.02), (0.017, 0.02), (0.0, -0.022)], 0.003, rr=0.001, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32), part=SILVER))
    # the belt's O-ring, front left
    out.append(Torus((0.03, -0.112, 1.215), 0.016, 0.0035, Rm=rot(rx=90), part=SILVER))
    # buttons on the cuffs
    d = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    side = np.cross(d, v3((0, 1, 0)))
    side /= np.linalg.norm(side)
    for k in range(3):
        out.append(Mirror(Sphere(WRIST - d * (0.035 + 0.02 * k) + side * 0.043, 0.006, part=SILVER)))
    # rings on two fingers of each hand
    return Union(out, k=0.0)


def pieces():
    only = os.environ.get("FOLK_ONLY", "")
    out = [("head", head, 0.0021), ("body", body, 0.0038), ("hands", hands, 0.0021), ("jewels", jewels, 0.0015)]
    shift = float(os.environ.get("FOLK_SHIFT", "0"))     # check renders only: slide the figure so the head hangs under the face cameras (they aim at x = 0)
    return [(n, (Move(f(), t=(-shift, 0, 0)) if shift else f()), h) for n, f, h in out if not only or n in only.split(",")]


# ---------------------------------------------------------------------------------------------------- paint

def neck_coords(P):
    """(arc length along the neck from its base, angle round it) for each point, from the nearest point of the neck's centre line"""
    best = np.full(len(P), 1e9, np.float32)
    s_out = np.zeros(len(P), np.float32)
    a_out = np.zeros(len(P), np.float32)
    s0 = 0.0
    for a, b in zip(NECK_PTS[:-1], NECK_PTS[1:]):
        ab = b - a
        L = float(np.linalg.norm(ab))
        t = np.clip(((P - a) @ ab) / (L * L), 0, 1)
        q = P - a - np.outer(t, ab)
        d = np.linalg.norm(q, axis=1)
        take = d < best
        best[take] = d[take]
        s_out[take] = (s0 + t * L)[take]
        u = ab / L
        e1 = np.cross(u, v3((1, 0, 0)))
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(u, e1)
        a_out[take] = np.arctan2(q @ e2, q @ e1)[take]
        s0 += L
    return s_out, a_out


def paint(c):
    from kit.paint import srgb, smooth
    P = c.P + v3((float(os.environ.get("FOLK_SHIFT", "0")), 0, 0))
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.009) * 0.25

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def mix(a, b, t):
        return a + (b - a) * np.asarray(t, np.float32)[:, None]

    # skin: pale grey-pink, the neck laid in rows of square scales, each its own shade
    m = c.mask(SKIN, NECK)
    sk = np.broadcast_to(srgb(214, 198, 198), (len(P), 3)).copy() * (1.0 + 0.05 * mott)[:, None]
    nm = c.mask(NECK)
    s, a = neck_coords(P)
    row = np.floor(s / 0.032).astype(np.int64)
    colm = np.floor(a / (2 * math.pi / 14) + 0.5 * (row % 2)).astype(np.int64)
    h = (row * 73856093) ^ (colm * 19349663)
    tone = (((h ^ (h >> 13)) * 1274126177) >> 8 & 1023).astype(np.float32) / 1023.0
    sk = np.where(nm[:, None], mix(sk, srgb(176, 150, 156), tone * 0.5), sk)
    fr = s / 0.032 - np.floor(s / 0.032)
    c.draw(nm, np.minimum(fr, 1 - fr) * 0.032, 0.0007, 0.4)
    fa = a / (2 * math.pi / 14) + 0.5 * (row % 2)
    fa = fa - np.floor(fa)
    c.draw(nm & (np.minimum(fa, 1 - fa) < 0.12), np.minimum(fa, 1 - fa) * 0.06 * 2 * math.pi / 14 * 2, 0.0006, 0.3)
    # round the eyes: a dusky lid, a dark liner, the lower rim pinker
    for e in EYES:
        de = P - e.c
        r = np.linalg.norm(de, axis=1)
        pd = (P - e.lid_pt) @ e.lid_n
        sk = mix(sk, srgb(150, 118, 130), ((r < e.r + 0.01) & (pd < 0)) * 0.6)
        sk = mix(sk, srgb(190, 150, 160), smooth(e.r + 0.012, e.r + 0.003, r) * 0.4)
        c.draw((r < e.r + 0.01) & (pd > -0.006) & (pd < 0.003) & (de @ e.f > -0.006), np.abs(pd + 0.001), 0.0016)
    put(m, sk[m], 0.45, bump=0.25)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(160, 130, 136), (int(m.sum()), 3)), np.full((int(m.sum()), 1), 0.18, np.float32)], 1)
    # eyes: a pale white, a big dark grey-green iris, a black pupil, a glint
    m = c.mask(EYE)
    ec = np.zeros((len(P), 3), np.float32)
    for e in EYES:
        de = P - e.c
        r = np.linalg.norm(de, axis=1)
        mine = m & (np.abs(r - e.r) < 0.003)
        d = de / np.maximum(r, 1e-6)[:, None]
        g = e.f * 0.7 + v3((0, -1, 0)) * 0.3
        g /= np.linalg.norm(g)
        ang = np.arccos(np.clip(d @ g, -1, 1))
        col = mix(np.broadcast_to(srgb(64, 84, 70), (len(P), 3)), srgb(228, 220, 214), smooth(0.48, 0.56, ang))
        col *= (1.0 - 0.35 * smooth(0.0, 0.4, d @ e.up))[:, None]
        c.draw(mine, (ang - 0.22) * e.r, 0.0)
        gd = g + e.up * 0.4
        gd /= np.linalg.norm(gd)
        col = mix(col, srgb(255, 255, 250), smooth(0.985, 0.993, d @ gd))
        ec[mine] = col[mine]
    put(m, ec[m], 0.06)
    m = c.mask(LIP)
    put(m, (srgb(190, 90, 126) * (1.0 + 0.45 * c.wear)[:, None])[m], 0.12, bump=0.15)
    put(c.mask(NAIL), srgb(40, 30, 34), 0.15)
    # the mesh shirt: pale skin through a fine dark net
    m = c.mask(MESH)
    put(m, (srgb(170, 146, 150) * (1.0 + 0.05 * mott)[:, None])[m], 0.5, bump=0.2)
    sp = 0.009
    u1 = (P[:, 0] + z) / sp
    u2 = (P[:, 0] - z) / sp
    d1 = np.abs(u1 - np.round(u1)) * sp * 0.7071
    d2 = np.abs(u2 - np.round(u2)) * sp * 0.7071
    c.draw(m, np.minimum(d1, d2), 0.0008, 0.9)
    # leather: the jacket, the collar cuff, the belt, the boots; rubbed brown on the edges
    for parts, base, rough in (((JACKET,), (34, 28, 32), 0.36), ((LEATHER,), (70, 46, 40), 0.45), ((BELT,), (24, 20, 24), 0.35), ((BOOT,), (40, 30, 34), 0.18)):
        m = c.mask(*parts)
        put(m, (srgb(*base) * (1.0 + 1.3 * c.wear + 0.05 * mott)[:, None])[m], rough, bump=0.5, grain=1.0)
    put(c.mask(SOLE), srgb(20, 16, 18), 0.5)
    # the sash: plum satin, dark in its folds, bright on them
    m = c.mask(SASH)
    put(m, (srgb(122, 50, 118) * (1.0 + 0.6 * c.wear - 0.4 * c.cavity)[:, None])[m], 0.4, bump=0.3)
    # the trousers: charcoal with a pale pinstripe round each leg
    m = c.mask(TROUSERS)
    put(m, (srgb(52, 42, 48) * (1.0 + 0.5 * c.wear + 0.05 * mott)[:, None])[m], 0.78, bump=0.9)
    kx = np.interp(z, [0.3, 0.67, 1.11], [0.135, 0.12, 0.10])
    phi = np.arctan2(Q[:, 0] - kx, -(y - 0.0))
    rad = np.hypot(Q[:, 0] - kx, y)
    c.strp[m, 0] = (phi * np.maximum(rad, 0.03) * 1.2)[m]
    c.strp[m, 1] = -0.5
    c.strp[m, 2] = 0.0
    m = c.mask(SILVER)
    put(m, (srgb(210, 208, 214) * (1.0 - 0.5 * c.cavity)[:, None])[m], 0.22, metal=1.0, bump=0.05, grain=1.0)
    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 3200, "body": 4300, "hands": 900, "jewels": 700},
    "density": {"head": 1.6, "hands": 1.2, "jewels": 1.2},
    "tex": 2048,
    "stride": {"walk": 1.3, "run": 2.0},
    "speed": 0.95,
    "look": ["head", "neck3", "neck2"], "neck": "neck1",          # the whole periscope turns from its base to look
    "look_pivot": (0.0, 0.03, 1.66),
    "radius": 0.45,
}
SASH_A, SASH_B = v3((-0.14, -0.045, 1.28)), v3((-0.15, -0.04, 0.86))


def rig_bones():
    from kit.rig import Bone, mirror
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.015, 1.11), (0, 0.015, 1.26), "root", 0.12),
        Bone("spine", (0, 0.015, 1.26), (0, 0.015, 1.45), "hips", 0.09),
        Bone("chest", (0, 0.015, 1.45), (0, 0.025, 1.66), "spine", 0.12),
        Bone("neck1", NECK_PTS[0], NECK_PTS[2], "chest", 0.06),
        Bone("neck2", NECK_PTS[2], NECK_PTS[4], "neck1", 0.06),
        Bone("neck3", NECK_PTS[4], HEAD_A, "neck2", 0.065),
        Bone("head", HEAD_A, HEAD_B, "neck3", 0.08),
        Bone("sash", SASH_A, SASH_B, "hips", 0.04),
        Bone("shoulder.L", (0.04, 0.02, 1.66), SHOULDER, "chest", 0.05),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.05),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.042),
        Bone("hand.L", WRIST, WRIST - H1[:, 2] * 0.2, "forearm.L", 0.03),
        Bone("thigh.L", HIP, KNEE, "hips", 0.085),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.06),
        Bone("foot.L", ANKLE, (0.142, -0.17, 0.022), "shin.L", 0.035),
    ])


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for vertices that move rigidly). piece: 0 head, 1 body, 2 hands, 3 jewels"""
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
    neck = hp & (part == NECK)
    allow(neck, "neck1", "neck2", "neck3", "head")
    allow(neck & (z < 1.72), "chest")
    face = hp & ~neck
    allow(face, "head", "neck3")
    rig[face & (seg(HEAD_A, HEAD_B) < 0.3) & ((P - HEAD_A) @ (HEAD_B - HEAD_A) > 0.02)] = ix["head"]
    bp = piece == 1
    armd = np.minimum(np.minimum(seg(SHOULDER, ELBOW), seg(ELBOW, WRIST)), np.minimum(seg(SHOULDER * fl, ELBOW * fl), seg(ELBOW * fl, WRIST * fl)))
    arm = bp & (armd < 0.07) & (np.abs(x) > 0.2)
    allow(arm & L, "shoulder.L", "upper_arm.L", "forearm.L")
    allow(arm & Rt, "shoulder.R", "upper_arm.R", "forearm.R")
    allow(arm & (z > 1.6), "chest")
    below = arm & (z < ELBOW[2] - 0.06)             # past the elbow the sleeve is the forearm's alone (smoothing had carried the upper arm down to the cuff, which creased it)
    A[below, ix["upper_arm.L"]] = False
    A[below, ix["upper_arm.R"]] = False
    A[below, ix["shoulder.L"]] = False
    A[below, ix["shoulder.R"]] = False
    sash = bp & ~arm & (part == SASH)
    tail = sash & (z < 1.25)
    allow(sash, "hips", "spine")
    allow(tail, "sash")
    rig[sash & (z < 1.1)] = ix["sash"]
    legs = bp & ~arm & ~sash & (part == TROUSERS)
    allow(legs, "hips")
    allow(legs & (x > -0.04), "thigh.L", "shin.L")
    allow(legs & (x < 0.04), "thigh.R", "shin.R")
    boots = bp & ~arm & np.isin(part, (BOOT, SOLE))
    allow(boots & L, "shin.L", "foot.L")
    allow(boots & Rt, "shin.R", "foot.R")
    collar = bp & (part == LEATHER)
    allow(collar, "chest", "neck1")
    torso = bp & ~arm & ~sash & ~legs & ~boots & ~collar
    allow(torso, "hips", "spine", "chest")
    allow(torso & L & (x > 0.1) & (z > 1.55), "shoulder.L")
    allow(torso & Rt & (x < -0.1) & (z > 1.55), "shoulder.R")
    # the jacket over the shoulder and down the side to the armpit blends into the arm (it went from chest to arm in one step, and opened there on a raised arm)
    allow(torso & L & (x > 0.12) & (z > 1.42), "shoulder.L", "upper_arm.L")
    allow(torso & Rt & (x < -0.12) & (z > 1.42), "shoulder.R", "upper_arm.R")
    hd = piece == 2
    allow(hd & L, "hand.L")
    allow(hd & Rt, "hand.R")
    rig[hd & L] = ix["hand.L"]
    rig[hd & Rt] = ix["hand.R"]
    jp = piece == 3
    ring = jp & ((z > 1.9) | (seg(HEAD_A, HEAD_B) < 0.3))      # the lip ring hangs below 1.9 at the far end of the paddle: by distance to the head too (it was on the chest)
    allow(ring, "head")
    rig[ring] = ix["head"]
    cuffs = jp & ~ring & (np.minimum(np.linalg.norm(P - WRIST, axis=1), np.linalg.norm(P - WRIST * fl, axis=1)) < 0.12)
    allow(cuffs & L, "forearm.L")
    allow(cuffs & Rt, "forearm.R")
    rig[cuffs & L] = ix["forearm.L"]
    rig[cuffs & Rt] = ix["forearm.R"]
    oring = jp & ~ring & ~cuffs & (z < 1.3)
    allow(oring, "hips")
    rig[oring] = ix["hips"]
    rest = jp & ~ring & ~cuffs & ~oring
    allow(rest, "chest")
    rig[rest] = ix["chest"]
    return A, rig


WALK = dict(stride=1.3, stance=0.6, foot_x=0.13, lift=0.065, bob=0.018, drop=0.06, sway=0.03, roll=6.0, yaw=8.0, counter=1.2,
            lean=1.0, toe_off=28.0, toe_out=8.0, swing_point=6.0)
RUN = dict(stride=2.0, stance=0.38, foot_x=0.13, lift=0.15, bob=0.035, drop=0.09, sway=0.02, roll=5.0, yaw=11.0, counter=1.3,
           lean=10.0, toe_off=30.0, toe_out=8.0, swing_point=14.0, spine_lean=4.0)


def motions(rig):
    """their clips: walk (long slinky strides, loose arms, and the neck swaying like a periscope: each joint of it following the last a beat late, the
    head scanning a little side to side as it goes), run (a lanky lope, the neck bowed forward and whipping), idle (a hand on the hip, the neck
    craning slowly about, a long look one way, a nod)"""
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], np.float32)
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def periscope(p, u, amp, bow):
        for k, nb in enumerate(("neck1", "neck2", "neck3")):
            lag = 0.65 * (k + 1)
            p.rot(nb, bow[k] + amp * 0.6 * math.sin(2 * TAU * u - lag), amp * 1.3 * math.sin(TAU * u - lag), amp * (1.6 if k == 0 else 0.8) * math.sin(TAU * u - lag - 0.4))
        p.rot("head", amp * 0.5 * math.sin(2 * TAU * u - 2.6), 0, 0)

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        A = 32.0 if run else 14.0
        for side, s, ph0 in (("L", 1.0, 0.0), ("R", -1.0, math.pi)):
            ph = TAU * u + ph0
            p.rot("upper_arm." + side, A * math.cos(ph), -s * (3.0 + (6.0 if run else 0.0)), 0)
            p.rot("forearm." + side, -(55.0 if run else 8.0) + A * 0.5 * (math.cos(ph - 0.8) - math.cos(ph)), 0, 0)
            p.rot("hand." + side, A * 0.5 * (math.cos(ph - 1.5) - math.cos(ph - 0.8)), 0, 0)
        periscope(p, u, 5.0 if run else 3.2, (8.0, 4.0, -4.0) if run else (2.0, 0.0, 0.0))
        p.rot("sash", (14.0 if run else 4.0) + 6.0 * math.cos(TAU * u - 1.2), 0, 4.0 * math.sin(TAU * u - 1.0))
        return p
    walk = [walkish(i / 32.0, WALK, False) for i in range(33)]
    run = [walkish(i / 24.0, RUN, True) for i in range(25)]

    def hand_rot(fingers, back):
        zz = -np.asarray(fingers, np.float64)
        zz /= np.linalg.norm(zz)
        xx = np.asarray(back, np.float64)
        xx = xx - zz * (xx @ zz)
        xx /= np.linalg.norm(xx)
        D = np.stack([xx, np.cross(zz, xx), zz], 1)
        return Matrix((D @ H1.T.astype(np.float64)).tolist())
    hip_rot = hand_rot((-0.25, -0.55, -0.8), (0.9, 0.1, 0.4))
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        sw = math.sin(TAU * t / 6.0)
        stand(rig, p, legs, {"L": (Vector((0.17, -0.07, 0.0)), 14.0), "R": (Vector((-0.16, 0.0, 0.0)), -16.0)},
              hip_shift=(0.03 + 0.01 * sw, 0.0, -0.02), roll=-4.0, yaw=-3.0)
        p.rot("spine", 1.0 * math.sin(TAU * t / 3.0), 2.0, 0)
        p.ik["upper_arm.L"] = (Vector((0.215, 0.02, 1.25)), Vector((1.0, 0.4, 0.1)), "hand.L", hip_rot)
        p.rot("upper_arm.R", 2.0 * math.sin(TAU * t / 6.0), 0, 0)
        crane = ease((t - 1.5) / 0.9) * (1.0 - ease((t - 4.0) / 1.0))
        nod = math.sin(TAU * max(0.0, t - 4.4) / 0.8) * ease((t - 4.4) / 0.2) * (1.0 - ease((t - 5.2) / 0.2))
        for k, nb in enumerate(("neck1", "neck2", "neck3")):
            lag = 0.7 * k
            p.rot(nb, 3.0 * math.sin(TAU * t / 3.0 - lag) + 6.0 * nod * (k == 2), 4.0 * math.sin(TAU * t / 6.0 - lag), (16.0 if k == 0 else 4.0) * crane + 3.0 * math.sin(TAU * t / 6.0 - lag))
        p.rot("sash", 2.0 * math.sin(TAU * t / 3.0), 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
