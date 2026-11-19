## FOINT CITY townsfolk: the manta goth (working name; the user names her). A red goth woman, 1.70 m, whose head is two great domed lobes like a manta or a heart; big sly green eyes, a toothy smirk, diamond earrings; red puffed-sleeve bolero, buckled corset, pleated leather skirt, fishnets, platform boots.
# Concept: the user's sheet 5.webp, top right (F:/prog-godot-cache/folk/refs/5.webp, box 775,4,1055,392). Measured off it (lobe tops to soles 369 px, 4.6 mm a pixel):
# the head 1.15-1.2 m across its lobes and 0.37 m tall: a narrow face in the middle (eyes 1.53, mouth 1.44, pointed chin 1.38) between two domed caps whose
# rims curl down to 1.40 at their ends, ridged underneath like a mushroom's gills, a dip between them over the brow; a thin neck under a choker (1.33);
# a small body under it: shoulders 1.26, bust 1.20, a corseted waist 1.01, the skirt from 0.95 flaring to 0.68, thick thighs in fishnets, knees 0.46,
# boots to 0.44 on a 7 cm platform and 17 cm block heels.
# Rest pose = her walking pose: arms hanging a little out from the puffed sleeves, elbows soft.
# (2026-11-16: the arms hang 4-7 cm further out than at first. At first the cuffs and forearm sleeves sat 2 cm inside the flared skirt, so the body piece meshed them
# into one surface: triangles ran from skirt to cuff and tore into sheets the moment an arm or leg moved (seen on CLUB 9's dance floor). Now 2.7 cm clear.)
import math
import os
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3, ridge_line)

HEIGHT = 1.70
REF = ("5.webp", (775, 4, 1055, 392))

SKIN, EYE, LIP, TOOTH, MOUTH, NAIL, JACKET, CORSET, SKIRT, NET, STRAP, SILVER, BOOT, SOLE, LEATHER, LOBE = range(1, 17)
COLOURS = {
    SKIN: ((0.62, 0.17, 0.18), 0.5, 0.0),
    LOBE: ((0.62, 0.17, 0.18), 0.5, 0.0),
    EYE: ((0.55, 0.85, 0.45), 0.15, 0.0),
    LIP: ((0.12, 0.02, 0.04), 0.3, 0.0),
    TOOTH: ((0.9, 0.86, 0.76), 0.3, 0.0),
    MOUTH: ((0.08, 0.01, 0.02), 0.6, 0.0),
    NAIL: ((0.05, 0.02, 0.03), 0.2, 0.0),
    JACKET: ((0.36, 0.05, 0.10), 0.7, 0.0),
    CORSET: ((0.03, 0.025, 0.03), 0.35, 0.0),
    SKIRT: ((0.03, 0.025, 0.03), 0.4, 0.0),
    NET: ((0.45, 0.12, 0.14), 0.6, 0.0),
    STRAP: ((0.03, 0.025, 0.03), 0.35, 0.0),
    SILVER: ((0.78, 0.78, 0.80), 0.25, 1.0),
    BOOT: ((0.03, 0.025, 0.03), 0.25, 0.0),
    SOLE: ((0.02, 0.018, 0.02), 0.5, 0.0),
    LEATHER: ((0.03, 0.025, 0.03), 0.35, 0.0),
}

# landmarks, left side (+X); the figure faces -Y
NECK_TOP = v3((0.0, 0.0, 1.40))
SHOULDER = v3((0.155, 0.015, 1.235))
ELBOW = v3((0.275, 0.04, 0.995))
WRIST = v3((0.335, -0.015, 0.79))
HIP = v3((0.09, 0.015, 0.80))
KNEE = v3((0.105, -0.01, 0.46))
ANKLE = v3((0.11, 0.035, 0.20))
BALL = v3((0.112, -0.095, 0.0))
LOBE_C = v3((0.25, 0.02, 1.57))
FLIP = np.diag([-1, 1, 1]).astype(np.float32)
H1 = basis(-(v3((0.16, -0.12, -1.0))), v3((0, 1, 0)))      # (the hand follows the forearm's angle out, the wrist a touch relaxed back in)


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

def lobe():
    """her left lobe: a broad dome reaching out from the side of her face, its far end drooping into a curled rim, hollowed underneath like an umbrella,
    with the gill ridges of the underside running out from the face"""
    # a thick dome grown out of the side of her face from eye level, its crown 0.22 m over its underside, the far end bowed down into a curled rim
    # (a Gem, not an ellipsoid: the concept's caps have a ridge along their crowns and a thin lip of a rim, not a pillow's roundness)
    # round 2 (lead: "thin flat pancakes"): the cap's middle moved in toward the face so the root is its thickest part (a Gem thins to its ends),
    # a block of mass at the root, a smaller hollow kept low, a raised ridge along the crown, a heavier rim curling down
    cap = Gem(LOBE_C, (0.25, 0.33, 0.165, 0.165, 0.11, 0.135), soft=0.6, edge=0.02, R=rot(ry=9))
    root = Ellipsoid((0.12, 0.02, 1.64), (0.10, 0.13, 0.08))
    brim = Gem((0.51, 0.02, 1.47), (0.10, 0.07, 0.155, 0.155, 0.06, 0.075), soft=0.5, edge=0.012, R=rot(ry=45))
    dome = Union([cap, root, brim], k=0.06)
    dome = Bump(dome, ridge_line((0.08, 0.02, 1.705), (0.50, 0.02, 1.625), 0.065), 0.02)
    hollow = Ellipsoid((0.41, 0.02, 1.385), (0.19, 0.11, 0.08), R=rot(ry=14))
    dome = Cut(dome, [hollow], k=0.025)
    # the gills: ridges along the underside, found by probing up into it, fanning out from the face to the rim
    ridges = []
    for k in range(-3, 4):
        pts = []
        for x in np.linspace(0.16, 0.54, 6):
            y = 0.02 + k * 0.022 * (0.4 + (x - 0.15) / 0.4)
            p, n = hit(dome, (x, y, 1.15), (0, 0, 1), t1=0.7, n=700)
            pts.append((p + v3((0, 0, 0.0025)), 0.0065))
        ridges.append(loft(pts, k=0.004))
    return Union([dome] + ridges, k=0.006, part=LOBE)


def head_base():
    face = Ellipsoid((0, -0.03, 1.505), (0.088, 0.08, 0.12))
    cheeks = Mirror(Ellipsoid((0.05, -0.07, 1.47), (0.05, 0.05, 0.045)))
    chin = Gem((0, -0.045, 1.43), (0.05, 0.05, 0.06, 0.05, 0.06, 0.02), soft=0.6, edge=0.006)
    neck = loft([(v3((0, 0.02, 1.27)), 0.031), (v3((0, 0.015, 1.36)), 0.03), (NECK_TOP, 0.04)])
    nose = Ellipsoid((0, -0.104, 1.49), (0.016, 0.014, 0.022))
    core = Union([face, cheeks, chin, neck], k=0.04)
    core = Union([core, nose], k=0.012, part=SKIN)
    return Union([core, Mirror(lobe())], k=0.05)


HEAD0 = head_base()
HEAD_C = v3((0.0, -0.02, 1.50))


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
    d = v3((0.5, -1.0, 0.25))
    d /= np.linalg.norm(d)
    p, n = hit(HEAD0, HEAD_C + v3((0.03, 0, 0.03)) + d * 0.4, -d)
    f = n * 0.5 + d * 0.5
    f /= np.linalg.norm(f)
    r = 0.033
    return Eye(p - f * (r * 0.45), f, r, 0.22, 0.38, 0.55)


EYE_L = _eye()
MOUTH_Z = 1.445


def lip_line(dz, inset, half=0.072, n=13):
    """across the face at mouth height + dz; both corners curl up into her smirk, her left more"""
    pts = []
    for x in np.linspace(-half, half, n):
        t = x / half
        z = MOUTH_Z + dz + 0.012 * abs(t) ** 2.2 + (0.006 * max(0.0, t) ** 2)
        p, nn = hit(HEAD0, (x, -0.4, z), (0, 1, 0))
        pts.append((p + nn * inset, t))
    return pts


def head():
    e = EYE_L
    lid = Clip(Sphere(e.c, e.r + 0.005, part=SKIN), [Half(e.lid_pt, e.lid_n)], k=0.003)
    lower = Clip(Sphere(e.c, e.r + 0.004, part=SKIN), [Half(e.c - e.up * (e.r * e.low), e.up)], k=0.003)
    face = Union([HEAD0, Mirror(Union([lid, lower]))], k=0.006)
    nostrils = Mirror(Ellipsoid((0.007, -0.117, 1.482), (0.004, 0.006, 0.003), R=rot(rx=30)))
    face = Cut(face, [nostrils], k=0.002)
    # the smirk: dark lips parted on a row of teeth
    up = lip_line(0.007, -0.001)
    lo = lip_line(-0.009, -0.0005, half=0.064)
    lips = Union([loft([(p, 0.005 + 0.006 * (1 - t * t)) for p, t in up], part=LIP, k=0.003),
                  loft([(p, 0.005 + 0.0085 * (1 - t * t) ** 0.7) for p, t in lo], part=LIP, k=0.003)], k=0.003)
    gap = loft([(p, 0.002 + 0.0065 * (1 - t * t)) for p, t in lip_line(-0.001, 0.0, half=0.066)], k=0.002)
    face = Cut(Union([face, lips], k=0.007), [gap], k=0.0015)
    mouth = loft([(p, 0.002 + 0.006 * (1 - t * t)) for p, t in lip_line(-0.001, -0.008, half=0.062)], part=MOUTH, k=0.002)
    teeth = []
    for p, t in lip_line(0.0015, -0.005, half=0.042, n=7):
        teeth.append(Box(p, (0.0058, 0.004, 0.0048), rr=0.002, part=TOOTH))
    ball = Mirror(Sphere(e.c, e.r, part=EYE))
    lashes = []
    for k in range(3):
        a = 0.55 + 0.18 * k
        root = e.c + (e.up * math.cos(a * 1.2) + e.out * math.sin(a * 1.2)) * (e.r + 0.004)
        tipd = e.up * 0.6 + e.out * 0.8 + e.f * 0.25
        tipd /= np.linalg.norm(tipd)
        lashes.append(Mirror(RoundCone(root, root + tipd * (0.014 + 0.004 * k), 0.0028, 0.0012, part=LIP)))
    return Union([face, mouth, ball] + teeth + lashes, k=0.0)


# ---------------------------------------------------------------------------------------------------- the body

def torso_core():
    """bare skin under it all: shoulders, chest, bust, a waist the corset pulls in, round hips"""
    return Union([
        Ellipsoid((0, 0.02, 1.245), (0.15, 0.065, 0.04)),
        Ellipsoid((0, 0.01, 1.175), (0.115, 0.08, 0.095)),
        Mirror(Ellipsoid((0.052, -0.046, 1.19), (0.053, 0.049, 0.047))),
        Ellipsoid((0, 0.012, 1.03), (0.078, 0.062, 0.08)),
        Ellipsoid((0, 0.015, 0.895), (0.15, 0.11, 0.095)),
    ], k=0.05, part=SKIN)


def prism(poly_xz, y0=-0.5, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from the front (y0) to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def corset(core):
    c = Clip(Inflate(core, 0.008, part=CORSET), [Half((0, 0, 0.95), (0, 0, -1)), Half((0, 0, 1.228), (0, 0, 1))], k=0.003)
    c = Cut(c, [prism([(-0.02, 1.25), (0.02, 1.25), (0.0, 1.19)])], k=0.006)
    straps = []
    for zz in (1.125, 1.07, 1.015):
        straps.append(Clip(Inflate(core, 0.0145, part=STRAP), [Half((0, 0, zz - 0.0095), (0, 0, -1)), Half((0, 0, zz + 0.0095), (0, 0, 1))], k=0.002))
    return Union([c] + straps, k=0.0)


def sleeve():
    S, E, W = SHOULDER, ELBOW, WRIST
    puff = loft([(S + v3((0.0, 0, 0.01)), 0.064), (S + (E - S) * 0.45, 0.074), (E, 0.054), (E + (W - E) * 0.45, 0.06), (W + (E - W) * 0.13, 0.045)], part=JACKET, k=0.025)
    ax = (E - S) / np.linalg.norm(E - S)

    def gathers(P):
        t = (P - S) @ ax
        return 0.5 + 0.5 * np.cos(np.arctan2(P[:, 1] - S[1], P[:, 0] - S[0]) * 9.0 + t * 40.0)
    puff = Bump(puff, gathers, 0.004)
    d = (W - E) / np.linalg.norm(W - E)
    cuff = CappedCone(W - d * 0.05, W - d * 0.008, 0.041, 0.038, rr=0.005, part=JACKET)
    band = CappedCone(S + (E - S) * 0.5, S + (E - S) * 0.62, 0.086, 0.083, rr=0.004, part=STRAP)
    return Union([Union([puff, cuff], k=0.01), band], k=0.0)


def jacket(core):
    """the bolero: a red shrug over her shoulders and back, its fronts cut away either side of the bust, the puffed sleeves set in"""
    shell = Clip(Inflate(core, 0.014, part=JACKET), [Half((0, 0, 1.11), (0, 0, -1))], k=0.004)
    front = prism([(-0.095, 1.30), (0.095, 1.30), (0.10, 1.19), (0.16, 1.11), (-0.16, 1.11), (-0.10, 1.19)])
    shell = Cut(shell, [front], k=0.01)
    return Union([shell, Mirror(sleeve())], k=0.02)


def hand():
    """a hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y), relaxed, fingers a little curled, pointed nails"""
    parts = [Sphere((0, 0, 0), 0.026, part=SKIN), Ellipsoid((0.0, 0.0, -0.045), (0.016, 0.037, 0.045), part=SKIN)]
    nails = []
    for i, (fy, L) in enumerate(((-0.026, 0.88), (-0.009, 1.0), (0.008, 0.96), (0.024, 0.8))):
        base = v3((0.0, fy, -0.084))
        pts = [(base, 0.0095)]
        a = 0.0
        p = base.copy()
        d = v3((0, 0, -1))
        for k, ln in enumerate((0.034, 0.027, 0.022)):
            a += math.radians(14 + 8 * k)
            d = v3((-math.sin(a), 0.0, -math.cos(a)))
            p = p + d * ln * L
            pts.append((p.copy(), 0.0088 - 0.0009 * k))
        parts.append(loft(pts, part=SKIN, k=0.004))
        nails.append(RoundCone(pts[-1][0] - d * 0.006 + v3((0.002, 0, 0)), pts[-1][0] + d * 0.008, 0.0062, 0.002, part=NAIL))
    th = [(v3((-0.006, -0.03, -0.024)), 0.011), (v3((-0.016, -0.047, -0.052)), 0.0095), (v3((-0.024, -0.052, -0.078)), 0.0082)]
    parts.append(loft(th, part=SKIN, k=0.004))
    return Union([Union(parts, k=0.008)] + nails, k=0.002)


def skirt():
    """the pleated leather mini: from her waist flaring to mid-thigh, a little shorter in front"""
    outer = CappedCone((0, 0.015, 0.975), (0, 0.02, 0.66), 0.158, 0.275)

    def pleats(P):
        f = (np.arctan2(P[:, 0], -(P[:, 1] - 0.015)) * 16.0 / (2 * np.pi)) % 1.0      # knife pleats (round 2: the cosine ripple read as a smooth cone)
        return (np.abs(f - 0.5) * 4.0 - 1.0) * np.clip((0.975 - P[:, 2]) / 0.06, 0, 1)
    shell = Bump(Cut(outer, [Inflate(outer, -0.016)], k=0.0), pleats, 0.013)      # the pleats move both faces of the shell, so it never thins through
    shell = Move(shell, R=np.diag([1.0, 1 / 0.8, 1.0]).astype(np.float32), pivot=(0, 0.015, 0))
    shell = Clip(shell, [Half((0, 0, 0.67), (0, 0.15, -1)), Half((0, 0, 0.972), (0, 0, 1))], k=0.003)
    band = Clip(Inflate(Ellipsoid((0, 0.015, 0.97), (0.152, 0.112, 0.05)), 0.006, part=STRAP), [Half((0, 0, 0.955), (0, 0, -1)), Half((0, 0, 0.99), (0, 0, 1))], k=0.002)
    return Union([Inflate(shell, 0.0, part=SKIRT), band], k=0.0)


def legs():
    hips = Ellipsoid((0, 0.015, 0.895), (0.15, 0.11, 0.095), part=NET)
    leg = loft([(HIP, 0.088), (v3((0.10, 0.0, 0.62)), 0.08), (KNEE, 0.056), (v3((0.108, 0.02, 0.36)), 0.05), (v3((0.11, 0.03, 0.30)), 0.047)], part=NET, k=0.03)
    garter = Clip(Inflate(leg, 0.008, part=STRAP), [Half((0, 0, 0.655), (0, 0, -1)), Half((0, 0, 0.68), (0, 0, 1))], k=0.002)
    hook = Clip(Inflate(leg, 0.006, part=STRAP), [Half((0, 0, 0.67), (0, 0, -1)), Half((0.08, 0, 0), (-1, 0, 0)), Half((0.115, 0, 0), (1, 0, 0)), Half((0, 0.0, 0), (0, 1, 0))], k=0.002)
    return Union([hips, Mirror(Union([leg, garter, hook], k=0.0))], k=0.04)


def boot():
    shaft = RoundCone(v3((0.11, 0.025, 0.44)), ANKLE, 0.066, 0.057, part=BOOT)
    foot = Box((0.112, -0.035, 0.16), (0.054, 0.10, 0.048), rr=0.034, R=rot(rx=-14), part=BOOT)
    toe = Ellipsoid((0.112, -0.13, 0.108), (0.054, 0.064, 0.04), part=BOOT)
    plat = Box((0.112, -0.10, 0.036), (0.064, 0.09, 0.036), rr=0.008, part=SOLE)
    heel = Box((0.112, 0.055, 0.086), (0.056, 0.048, 0.086), rr=0.007, part=SOLE)
    straps = [CappedCone((0.11, 0.025, z - 0.011), (0.11, 0.025, z + 0.011), r, r - 0.001, rr=0.004, part=STRAP) for z, r in ((0.40, 0.073), (0.35, 0.071))]
    b = Union([shaft, Union([foot, toe], k=0.03)], k=0.03)
    return Union([b, plat, heel] + straps, k=0.004)


def body():
    core = torso_core()
    neckband = CappedCone((0, 0.022, 1.312), (0, 0.022, 1.348), 0.038, 0.036, rr=0.005, part=LEATHER)
    arm = loft([(SHOULDER, 0.045), (ELBOW, 0.036), (WRIST, 0.027)], part=SKIN, k=0.01)
    return Union([core, corset(core), jacket(core), Mirror(arm), neckband, skirt(), legs(), Mirror(boot())], k=0.0)


def hands():
    return Mirror(place(hand(), WRIST, H1))


def earring():
    R = np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32)
    ring = Torus((0, 0, -0.006), 0.006, 0.002, Rm=rot(ry=90), part=SILVER)
    link = RoundCone((0, 0, -0.012), (0, 0, -0.035), 0.0025, 0.0025, part=SILVER)
    c = v3((0, 0, -0.085))
    outer = Slab(c, [(0, 0.05), (0.028, 0), (0, -0.05), (-0.028, 0)], 0.003, rr=0.001, R=R, part=SILVER)
    inner = Slab(c, [(0, 0.04), (0.019, 0), (0, -0.04), (-0.019, 0)], 0.006, R=R)
    stone = Gem(c, (0.007, 0.007, 0.004, 0.004, 0.014, 0.014), soft=0.1, part=SILVER)
    spike = RoundCone((0, 0, -0.14), (0, 0, -0.18), 0.0075, 0.001, part=SILVER)
    cap = Sphere((0, 0, -0.137), 0.0055, part=SILVER)
    return Union([ring, link, Cut(outer, [inner], k=0.001), stone, spike, cap], k=0.0015)


def ear_hook():
    p, n = hit(HEAD0, (0.43, 0.02, 1.2), (0, 0, 1))
    return p


def jewels():
    out = [Mirror(Move(earring(), t=ear_hook()))]
    # bangles
    d = (WRIST - ELBOW) / np.linalg.norm(WRIST - ELBOW)
    for i in range(3):
        Rm = basis(d, v3((0, 1, 0))) @ rot(rx=8 * (1 if i % 2 else -1))
        out.append(Mirror(Torus(WRIST - d * (0.012 + 0.009 * i), 0.031 + 0.001 * i, 0.0036, Rm=Rm, part=SILVER)))

    # buckles on the corset straps (at her left front), the garters, the boot straps; the choker's triangle; the boots' lace eyelets
    def frame(c, w, h, Rm, t=0.0025):
        return Cut(Box(c, (w, t, h), rr=0.0015, R=Rm, part=SILVER), [Box(c, (w - 0.004, t * 3, h - 0.004), R=Rm)], k=0.0)
    core = Inflate(torso_core(), 0.0145)
    for zz in (1.125, 1.07, 1.015):
        p, n = hit(core, (0.04, -0.4, zz), (0, 1, 0))
        out.append(frame(p + n * 0.002, 0.013, 0.011, basis(v3((0, 0, 1)), n)))
    p, n = hit(Inflate(loft([(HIP, 0.088), (v3((0.10, 0.0, 0.62)), 0.08), (KNEE, 0.056)]), 0.008), (0.10, -0.4, 0.668), (0, 1, 0))
    out.append(Mirror(frame(p + n * 0.002, 0.012, 0.011, basis(v3((0, 0, 1)), n))))
    for z, r in ((0.40, 0.073), (0.35, 0.071)):
        out.append(Mirror(frame(v3((0.11 + r + 0.003, 0.025, z)), 0.013, 0.012, basis(v3((0, 0, 1)), v3((1, 0, 0))))))
    tri = Slab((0, -0.017, 1.33), [(-0.012, 0.012), (0.012, 0.012), (0.0, -0.01)], 0.003, rr=0.001, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32), part=SILVER)
    out.append(tri)
    return Union(out, k=0.0)


def pieces():
    only = os.environ.get("FOLK_ONLY", "")
    out = [("head", head, 0.0021), ("body", body, 0.0036), ("hands", hands, 0.002), ("jewels", jewels, 0.0015)]
    return [(n, f(), h) for n, f, h in out if not only or n in only.split(",")]


# ---------------------------------------------------------------------------------------------------- paint

def paint(c):
    from kit.paint import srgb, smooth
    P = c.P
    Q = P.copy()
    Q[:, 0] = np.abs(Q[:, 0])
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    mott = noise3(P, 0.03) * 0.5 + noise3(P, 0.009) * 0.25
    n3 = noise3(P + 2.3, 0.06)

    def put(m, col, rough, metal=0.0, bump=0.0, grain=0.0):
        c.col[m] = col
        c.rough[m] = rough
        c.metal[m] = metal
        c.bump[m] = bump
        c.grain[m] = grain

    def mix(a, b, t):
        return a + (b - a) * np.asarray(t, np.float32)[:, None]

    def hash2(i, j):
        h = (i * 73856093) ^ (j * 19349663)
        h = (h ^ (h >> 13)) * 1274126177
        return ((h ^ (h >> 16)) & 0xFFFF).astype(np.float32) / 65535.0

    # skin: coral red, dappled darker; the lobes' tops laid in rows of tile-like scales, each its own shade, the gills underneath darker
    m = c.mask(SKIN, LOBE)
    sk = np.broadcast_to(srgb(200, 82, 86), (len(P), 3)).copy() * (1.0 + 0.06 * mott)[:, None]
    sk = mix(sk, srgb(160, 56, 66), smooth(0.25, 0.65, n3) * 0.45)
    lob = c.mask(LOBE)
    rr = np.hypot(Q[:, 0] - 0.02, (z - 1.50) * 1.4)
    row = np.floor(rr / 0.034).astype(np.int64)
    off = (row % 2) * 0.5
    col_i = np.floor(y / 0.04 + off).astype(np.int64)
    tone = hash2(row, col_i)
    sk = np.where(lob[:, None], mix(sk, srgb(222, 112, 104), tone * 0.55), sk)
    top = lob & (c.N[:, 2] > -0.2)
    fr = rr / 0.034 - np.floor(rr / 0.034)
    c.draw(top, np.minimum(fr, 1.0 - fr) * 0.034, 0.0007, 0.45)
    fc = y / 0.04 + off - np.floor(y / 0.04 + off)
    c.draw(top & (np.minimum(fc, 1.0 - fc) * 0.04 < 0.004), np.minimum(fc, 1.0 - fc) * 0.04, 0.0006, 0.35)
    under = lob & (c.N[:, 2] < -0.2)
    sk = np.where(under[:, None], mix(sk, srgb(120, 36, 46), np.full(len(P), 0.6)), sk)
    sk = mix(sk, srgb(236, 136, 120), c.wear * 0.3)
    # the eyes' lids: a plum shadow, a black liner flicked up at the outer corner
    e = EYE_L
    de = Q - e.c
    r = np.linalg.norm(de, axis=1)
    pd = (Q - e.lid_pt) @ e.lid_n
    sk = mix(sk, srgb(120, 40, 70), ((r < e.r + 0.012) & (pd < 0)) * smooth(-0.03, -0.004, pd) * 0.7)
    sk = mix(sk, srgb(130, 46, 58), smooth(e.r + 0.016, e.r + 0.004, r) * (de @ e.f > -0.02) * 0.5)
    c.draw((r < e.r + 0.012) & (pd > -0.008) & (pd < 0.004) & (de @ e.f > -0.01), np.abs(pd + 0.001), 0.0024)
    wt = ((de @ e.out) - e.r * 0.75) / 0.03
    c.draw((wt > 0) & (wt < 1) & (r < e.r + 0.04) & (np.abs(pd) < 0.02), np.abs(pd + 0.001 - 0.01 * np.clip(wt, 0, 1)), 0.0024 * (1 - np.clip(wt, 0, 1)) + 0.0002)
    pl = (Q - (e.c - e.up * (e.r * e.low))) @ e.up
    c.draw((r < e.r + 0.01) & (np.abs(pl) < 0.005) & (de @ e.f > -0.006), np.abs(pl - 0.0008), 0.0009, 0.7)
    put(m, sk[m], 0.5, bump=0.25)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(150, 50, 60), (int(m.sum()), 3)), np.full((int(m.sum()), 1), 0.2, np.float32)], 1)

    # the eyes: pale lime, greener to the rim, small dark pupils glancing to her left, a glint
    m = c.mask(EYE)
    ec = np.zeros((len(P), 3), np.float32)
    gaze = v3((0.5, -1.0, 0.0))
    gaze /= np.linalg.norm(gaze)
    for cc in (e.c, e.c * FLIP.diagonal()):
        dd = P - cc
        rad = np.linalg.norm(dd, axis=1)
        mine = m & (np.abs(rad - e.r) < 0.004)
        d = dd / np.maximum(rad, 1e-6)[:, None]
        ang = np.arccos(np.clip(d @ gaze, -1, 1))
        col = mix(np.broadcast_to(srgb(222, 244, 190), (len(P), 3)), srgb(150, 210, 110), smooth(0.25, 0.7, ang))
        col = mix(col, srgb(70, 120, 50), smooth(0.75, 1.05, ang))
        col *= (1.0 - 0.4 * smooth(0.0, 0.35, d @ e.up))[:, None]
        c.draw(mine, (ang - 0.19) * e.r, 0.0)
        gd = gaze + e.up * 0.35 - v3((0.2, 0, 0))
        gd /= np.linalg.norm(gd)
        col = mix(col, srgb(255, 255, 245), smooth(0.986, 0.994, d @ gd))
        ec[mine] = col[mine]
    put(m, ec[m], 0.06)
    put(c.mask(LIP), srgb(52, 16, 30), 0.25, bump=0.2)
    put(c.mask(MOUTH), srgb(40, 8, 16), 0.6)
    m = c.mask(TOOTH)
    put(m, (srgb(240, 232, 214) * (1.0 - 0.3 * c.cavity)[:, None])[m], 0.25)
    put(c.mask(NAIL), srgb(30, 14, 22), 0.15)

    # the bolero: crimson, a satin sheen, shadowed in the gathers
    m = c.mask(JACKET)
    jc = srgb(150, 34, 56) * (1.0 + 0.4 * c.wear - 0.2 * c.cavity + 0.04 * mott)[:, None]
    put(m, jc[m], 0.45, bump=0.4)
    # leather: corset, straps, skirt, choker, boots; rubbed lighter on the edges
    for parts, base, rough in (((CORSET,), (30, 26, 32), 0.3), ((STRAP, LEATHER), (24, 21, 26), 0.32), ((SKIRT,), (34, 28, 34), 0.38), ((BOOT,), (26, 22, 26), 0.18)):
        m = c.mask(*parts)
        lc = srgb(*base) * (1.0 + 1.3 * c.wear + 0.06 * mott)[:, None]
        put(m, lc[m], rough, bump=0.5, grain=1.0)
    m = c.mask(SKIRT)
    c.spk[m] = np.concatenate([np.broadcast_to(srgb(190, 188, 196), (int(m.sum()), 3)), (0.35 * smooth(0.74, 0.70, z[m]))[:, None]], 1)
    c.draw(m & (np.abs(z - (0.69 - 0.15 * np.minimum(y, 0))) < 0.006), np.abs(z - (0.69 - 0.15 * np.minimum(y, 0)) - 0.0), 0.0007, 0.4)
    m = c.mask(SOLE)
    put(m, (srgb(22, 18, 22) * (1.0 + 1.6 * c.wear)[:, None])[m], 0.55, bump=0.5)
    # the boots' laces: a criss-cross up the front of each shaft
    bl = c.mask(BOOT) & (y < 0.0) & (z > 0.2) & (z < 0.42)
    lx = np.abs(Q[:, 0] - 0.11)
    u = (z - 0.2) / 0.03
    zig = np.abs((u - np.floor(u)) - 0.5) * 2.0 * 0.02
    c.draw(bl & (lx < 0.03), np.abs(lx - zig), 0.0014, 0.9)
    # fishnet: red skin seen through a dark diamond net; the stockings' tops banded
    m = c.mask(NET)
    nc = srgb(178, 66, 72) * (1.0 + 0.05 * mott)[:, None]
    put(m, nc[m], 0.55, bump=0.2)
    lc_x = np.interp(z, [0.2, 0.46, 0.8], [0.11, 0.105, 0.09])
    phi = np.arctan2(Q[:, 0] - lc_x, -(y - 0.0))
    radl = np.hypot(Q[:, 0] - lc_x, y)
    uu = phi * radl
    s = 0.011
    d1 = np.abs(((uu + z) / s + 0.5) % 1.0 - 0.5) * s * 0.7071
    d2 = np.abs(((uu - z) / s + 0.5) % 1.0 - 0.5) * s * 0.7071
    c.draw(m, np.minimum(d1, d2), 0.0007, 0.85)
    # metal
    m = c.mask(SILVER)
    put(m, (srgb(212, 210, 218) * (1.0 - 0.5 * c.cavity)[:, None])[m], 0.22, metal=1.0, bump=0.05, grain=1.0)
    c.col *= (0.3 + 0.7 * c.ao)[:, None]
    c.col *= (1.0 - 0.3 * c.cavity)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"head": 3300, "body": 4600, "hands": 800, "jewels": 900},
    "density": {"head": 1.4, "hands": 1.2, "jewels": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.84, "run": 1.4},
    "speed": 0.95,                                                   # short legs on platforms: quick heavy stomps
    "look": ["head", "lobe.L", "lobe.R"], "neck": "neck",
    "look_pivot": (0.0, 0.0, 1.40),
    "radius": 0.6,
}
LOBE_TIP = v3((0.58, 0.02, 1.47))


def rig_bones():
    from kit.rig import Bone, mirror
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("hips", (0, 0.015, 0.80), (0, 0.015, 0.97), "root", 0.13),
        Bone("spine", (0, 0.015, 0.97), (0, 0.012, 1.10), "hips", 0.08),
        Bone("chest", (0, 0.012, 1.10), (0, 0.02, 1.27), "spine", 0.1),
        Bone("neck", (0, 0.02, 1.28), NECK_TOP, "chest", 0.03),
        Bone("head", NECK_TOP, (0, -0.02, 1.62), "neck", 0.04),
        Bone("lobe.L", (0.10, 0.02, 1.58), LOBE_TIP, "head", 0.05),
        Bone("shoulder.L", (0.03, 0.02, 1.24), SHOULDER, "chest", 0.04),
        Bone("upper_arm.L", SHOULDER, ELBOW, "shoulder.L", 0.045),
        Bone("forearm.L", ELBOW, WRIST, "upper_arm.L", 0.04),
        Bone("hand.L", WRIST, WRIST - H1[:, 2] * 0.17, "forearm.L", 0.03),
        Bone("thigh.L", HIP, KNEE, "hips", 0.085),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.055),
        Bone("foot.L", ANKLE, (0.112, -0.17, 0.06), "shin.L", 0.05),
    ])


def skin_rules(P, part, piece, names):
    """(allowed bones per vertex, a single bone for vertices that move rigidly). piece: 0 head, 1 body, 2 hands, 3 jewels"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    L, Rt = x > 0, x <= 0

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True

    def seg(a, b):
        ab = b - a
        t = np.clip(((P - a) @ ab) / float(ab @ ab), 0, 1)
        return np.linalg.norm(P - a - np.outer(t, ab), axis=1)
    # head: the face rigid, the lobes bend from where they leave it, the neck from the choker
    hp = piece == 0
    allow(hp, "chest", "neck", "head")
    rig[hp & (z > 1.40) & (np.abs(x) < 0.09)] = ix["head"]
    lob = hp & (np.abs(x) >= 0.09) & (z > 1.2)
    wr = hp & (z <= 1.2)        # skin of the head piece down at her wrists (her bare wrists are fused into it): the forearms carry it, never the lobes (149x stretch in CLUB 9)
    A[wr] = False
    allow(wr & L, "forearm.L")
    allow(wr & Rt, "forearm.R")
    rig[wr & L] = ix["forearm.L"]
    rig[wr & Rt] = ix["forearm.R"]
    A[lob, ix["chest"]] = False
    A[lob, ix["neck"]] = False
    allow(lob & L, "lobe.L")
    allow(lob & Rt, "lobe.R")
    rig[lob & L & (x > 0.2)] = ix["lobe.L"]
    rig[lob & Rt & (x < -0.2)] = ix["lobe.R"]
    bp = piece == 1
    # sleeves and the arms inside them
    fl = FLIP.diagonal()
    armd = np.minimum(np.minimum(seg(SHOULDER, ELBOW), seg(ELBOW, WRIST)), np.minimum(seg(SHOULDER * fl, ELBOW * fl), seg(ELBOW * fl, WRIST * fl)))
    arm = bp & (armd < 0.095) & (np.abs(x) > 0.135) & (z > 0.7) & np.isin(part, (JACKET, SKIN, STRAP)) & ~((part == STRAP) & (z < 1.0))
    allow(arm & L, "shoulder.L", "upper_arm.L", "forearm.L")
    allow(arm & Rt, "shoulder.R", "upper_arm.R", "forearm.R")
    allow(arm & (z > 1.15), "chest")
    legs = bp & ~arm & (np.isin(part, (NET, SKIRT)) | ((part == STRAP) & (z < 0.99)))
    allow(legs, "hips")
    allow(legs & (x > -0.04), "thigh.L")
    allow(legs & (x < 0.04), "thigh.R")
    allow(legs & L & (z < 0.6), "shin.L")
    allow(legs & Rt & (z < 0.6), "shin.R")
    allow(bp & ~arm & (part == SKIRT), "spine")
    boots = bp & ~arm & (np.isin(part, (BOOT, SOLE)) | ((part == STRAP) & (z < 0.5)))
    A[boots] = False
    allow(boots & L, "shin.L", "foot.L")
    allow(boots & Rt, "shin.R", "foot.R")
    choker = bp & (part == LEATHER)
    allow(choker, "neck")
    rig[choker] = ix["neck"]
    torso = bp & ~arm & ~legs & ~boots & ~choker
    allow(torso, "hips", "spine", "chest", "neck")
    allow(torso & L & (x > 0.09) & (z > 1.15), "shoulder.L")
    allow(torso & Rt & (x < -0.09) & (z > 1.15), "shoulder.R")
    # hands rigid
    hd = piece == 2
    allow(hd & L, "hand.L")
    allow(hd & Rt, "hand.R")
    rig[hd & L] = ix["hand.L"]
    rig[hd & Rt] = ix["hand.R"]
    # jewellery
    jp = piece == 3
    ear = jp & (np.abs(x) > 0.3) & (z > 1.0)        # (by height too: the bracelets hang past x 0.3 since the arms were set further out)
    allow(ear & L, "lobe.L")
    allow(ear & Rt, "lobe.R")
    rig[ear & L] = ix["lobe.L"]
    rig[ear & Rt] = ix["lobe.R"]
    near_w = jp & ~ear & (np.minimum(np.linalg.norm(P - WRIST, axis=1), np.linalg.norm(P - WRIST * fl, axis=1)) < 0.06)
    allow(near_w & L, "forearm.L")
    allow(near_w & Rt, "forearm.R")
    rig[near_w & L] = ix["forearm.L"]
    rig[near_w & Rt] = ix["forearm.R"]
    bootj = jp & ~ear & ~near_w & (z < 0.5)
    allow(bootj & L, "shin.L")
    allow(bootj & Rt, "shin.R")
    rig[bootj & L] = ix["shin.L"]
    rig[bootj & Rt] = ix["shin.R"]
    garter = jp & ~ear & ~near_w & (z >= 0.5) & (z < 0.8)
    allow(garter & L, "thigh.L")
    allow(garter & Rt, "thigh.R")
    rig[garter & L] = ix["thigh.L"]
    rig[garter & Rt] = ix["thigh.R"]
    tri = jp & ~ear & ~near_w & (z > 1.28)
    allow(tri, "neck")
    rig[tri] = ix["neck"]
    rest = jp & ~ear & ~near_w & ~bootj & ~garter & ~tri
    allow(rest, "spine", "chest")
    rig[rest] = ix["spine"]
    return A, rig


WALK = dict(stride=0.84, stance=0.6, foot_x=0.118, lift=0.10, bob=0.028, drop=0.06, sway=0.03, roll=7.0, yaw=9.0, counter=1.3,
            lean=3.0, toe_off=8.0, toe_out=6.0, swing_point=0.0)
RUN = dict(stride=1.4, stance=0.38, foot_x=0.12, lift=0.15, bob=0.038, drop=0.09, sway=0.022, roll=5.0, yaw=11.0, counter=1.3,
           lean=9.0, toe_off=20.0, toe_out=6.0, swing_point=8.0, spine_lean=4.0)


def motions(rig):
    """her clips: walk (stomping in her platforms: high knees, the feet coming down flat and hard, a jolt through her at each stomp that sets the
    lobes flopping, arms swinging with attitude, a sassy tilt of the head), run (a clattering trot, lobes bouncing), idle (hands on hips as in the
    concept, a hip pop, a tap of the foot, a slow sly look round)"""
    from kit.gait import Pose, Leg, R, biped_walk, stand, TAU, ease
    from mathutils import Vector, Matrix
    f = np.array([-1, 1, 1], np.float32)
    F3 = Matrix(FLIP.tolist())
    legs = [Leg("thigh.L", "shin.L", "foot.L", BALL.tolist(), "L"), Leg("thigh.R", "shin.R", "foot.R", (BALL * f).tolist(), "R")]

    def flop(u):
        """the lobes' answer to the last stomp (one every half cycle): a dip and a damped wobble"""
        ph = (2.0 * u) % 1.0
        return math.exp(-ph * 5.0) * math.cos(ph * TAU * 1.6)

    def walkish(u, g, run):
        p = Pose()
        biped_walk(rig, p, u, g, legs)
        ph = (2.0 * u) % 1.0
        p.offset.z -= (0.022 if run else 0.016) * math.exp(-((ph - 0.04) / 0.06) ** 2)
        A = 30.0 if run else 20.0
        c = math.cos(TAU * u)
        for side, s, sg in (("L", 1.0, 1.0), ("R", -1.0, -1.0)):
            sw = c * sg
            p.rot("upper_arm." + side, A * sw, -s * (4.0 + (6.0 if run else 0.0)), 0)
            p.rot("forearm." + side, -(55.0 if run else 14.0) - 10.0 * max(0.0, -sw), 0, 0)
            p.rot("hand." + side, 8.0 * math.cos(TAU * u * sg - 1.2), 0, 0)
            dip = (12.0 if run else 9.0) * flop(u)
            p.rot("lobe." + side, 0, s * dip, 0)
        p.rot("neck", 2.0, 0, 0)
        p.world["head"] = R((4.0 if run else -2.0) + 2.0 * flop(u), 4.0 * math.sin(TAU * u - 0.4), 4.0 * math.sin(TAU * u - 0.7))
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
    hip_wr, hip_pole = Vector((0.15, 0.03, 1.02)), Vector((1.0, 0.35, 0.1))
    hip_rot = hand_rot((-0.3, -0.75, -0.55), (0.85, 0.0, 0.5))
    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        pop = math.sin(TAU * t / 6.0)
        tap = ease((t - 3.0) / 0.2) * (1.0 - ease((t - 4.2) / 0.2)) * max(0.0, math.sin(TAU * (t - 3.0) * 2.5))
        stand(rig, p, legs, {"L": (Vector((0.14, -0.05, 0.0)), 8.0), "R": (Vector((-0.15, 0.0, 0.0)), -12.0)},
              hip_shift=(0.03 * pop, 0.0, -0.02 + 0.006 * abs(pop)), roll=-5.0 * pop, yaw=3.0 * pop)
        if tap > 0:
            # her right heel lifts and stamps, the foot rolling on its ball
            wf = R(0, 0, -12.0) @ R(16.0 * tap, 0, 0)
            ball = Vector((-0.15, 0.0, 0.0))
            ankle = ball + wf @ (rig.head["foot.R"] - Vector((BALL * f).tolist()))
            p.ik["thigh.R"] = (ankle, Vector((-0.15, -1.0, 0.0)), "foot.R", wf)
        p.rot("spine", 0, 3.0 * pop, 0)
        p.rot("chest", 1.0 * math.sin(TAU * t / 3.0), -2.0 * pop, 0)
        for side, s in (("L", 1.0), ("R", -1.0)):
            w = Vector((s * hip_wr.x, hip_wr.y, hip_wr.z)) + Vector((0.03 * pop, 0, -0.006 * abs(pop)))
            pole = Vector((s * hip_pole.x, hip_pole.y, hip_pole.z))
            rq = hip_rot if s > 0 else F3 @ hip_rot @ F3
            p.ik["upper_arm." + side] = (w, pole, "hand." + side, rq)
            p.rot("lobe." + side, 0, s * 2.5 * math.sin(TAU * t / 3.0 + s), 0)
        look = math.sin(TAU * t / 6.0 + 0.8)
        p.world["head"] = R(-3.0 + 1.5 * math.sin(TAU * t / 3.0), 5.0 * pop, 14.0 * look)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
