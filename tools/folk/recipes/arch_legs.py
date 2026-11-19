## FOINT CITY townsfolk: the arch (working name; the user names it). A green creature shaped like an arch: two thick columns joined overhead, its sly toothy toad face peering out of the zipped-up hood of a purple tracksuit top worn over the bend, little arms, leg warmers and chunky sneakers.
# Concept: the user's sheet, image 6 bottom left (F:/prog-godot-cache/folk/refs/6.webp). Measured off a 3x crop (720 px a metre): 1.50 m to the top of the hood;
# 1.5 m wide over the columns (their middles 0.48 out), the opening under the arch 0.6 wide and 1.12 high; the face in the top of the arch, its eyes 0.15 wide
# and 0.51 apart at 1.34, the grin at 1.29; the jacket's ribbed cuffs round the columns at 0.95, leg warmers 0.34-0.54, sneakers below. Bone-white spikes
# poke through the jacket and out of the columns. The little arms come out of the columns' inner fronts under the cuffs (the net bag and the list are dropped).
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.50
REF = ("6.webp", (20, 386, 392, 765))

SKIN, EYE, MOUTH, TOOTH, JACKET, RIB, ZIP, SPIKE, WARMER, SHOE, SOLE, LACE, NAIL = range(1, 14)
COLOURS = {
    SKIN: ((0.24, 0.45, 0.38), 0.55, 0.0),
    EYE: ((0.86, 0.48, 0.16), 0.15, 0.0),
    MOUTH: ((0.10, 0.02, 0.03), 0.5, 0.0),
    TOOTH: ((0.80, 0.74, 0.58), 0.3, 0.0),
    JACKET: ((0.42, 0.24, 0.50), 0.75, 0.0),
    RIB: ((0.36, 0.20, 0.44), 0.85, 0.0),
    ZIP: ((0.62, 0.62, 0.60), 0.35, 1.0),
    SPIKE: ((0.82, 0.70, 0.54), 0.5, 0.0),
    WARMER: ((0.82, 0.76, 0.64), 0.9, 0.0),
    SHOE: ((0.74, 0.70, 0.64), 0.6, 0.0),
    SOLE: ((0.80, 0.74, 0.62), 0.7, 0.0),
    LACE: ((0.86, 0.80, 0.70), 0.8, 0.0),
    NAIL: ((0.20, 0.30, 0.26), 0.4, 0.0),
}
FLIP = np.diag([-1, 1, 1]).astype(np.float32)


# ---------------------------------------------------------------------------------------------------- helpers

def prism(poly_xz, y0=-0.7, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from y0 to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def top_z(shape, x, y, z0=1.0, z1=0.0):
    """where a ray from above at (x, y) first meets the shape"""
    zs = np.arange(z0, z1, -0.0005, dtype=np.float32)
    P = np.stack([np.full_like(zs, x), np.full_like(zs, y), zs], 1)
    d = shape.eval(P)[0]
    return float(zs[int(np.argmax(d < 0))])


def front_y(shape, x, z, y0=-0.8, y1=0.4):
    ys = np.arange(y0, y1, 0.0005, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


# ---------------------------------------------------------------------------------------------------- framing (a kit gap, worked round here)
# kit/look.render_views frames a figure 0.62 as wide as it is tall and aims its face views at 0.9 of its height. The arch is as wide as it is
# tall and its face sits at 0.89 of it but 0.2 in front of its middle: the same renderer with a square frame and the face views aimed at the face.
VIEW_ASPECT = 1.0
FACE_AT = v3((0.0, -0.17, 1.31))
FACE_DIST = 1.6


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


# ---------------------------------------------------------------------------------------------------- landmarks (left side, +X; it faces -Y)
COL_X = 0.48              # the columns' middles
BEND_Z = 0.86             # where the columns start to bend over
APEX = 1.30               # the arch's centreline at its top
R_COL, R_TOP = 0.178, 0.19
CUFF_Z = 0.95
ANKLE = v3((0.48, 0.0, 0.17))
KNEE = v3((0.48, -0.03, 0.6))
HIP = v3((0.42, 0.0, 1.06))
EYE_C = v3((0.235, -0.0, 1.40))       # y found on the face (see face_piece): the eyes sit up proud on top of the arch
EYE_R = 0.078
SH = v3((0.31, -0.11, 0.86))           # the little arm, out of the column's inner front
EL = v3((0.29, -0.19, 0.73))
WR = v3((0.2, -0.25, 0.76))
HAND = basis(-v3((-0.85, -0.3, 0.3)), v3((0.31, -0.87, 0.0)))     # fingers pointing in toward the middle, the palm down, the thumb back


def centre(n=24):
    """the arch's centreline, left foot to right foot, with its radius: [(point, radius)]"""
    pts = [(v3((-COL_X, 0.0, 0.36)), R_COL - 0.02)]           # the column's foot ends inside the sneaker's collar
    for z in (0.5, BEND_Z):
        pts.append((v3((-COL_X, 0.0, z)), R_COL))
    for i in range(1, n):
        th = np.pi * i / n
        x = -COL_X * np.cos(th)
        z = BEND_Z + (APEX - BEND_Z) * np.sin(th)
        r = R_COL + (R_TOP - R_COL) * np.sin(th)
        pts.append((v3((x, 0.0, z)), r))
    for z in (BEND_Z, 0.5):
        pts.append((v3((COL_X, 0.0, z)), R_COL))
    pts.append((v3((COL_X, 0.0, 0.36)), R_COL - 0.02))
    return pts


def tube():
    return loft(centre(), part=SKIN, k=0.03)


# the zipped opening the face peers out of (front view, x z): over the brow, down the cheeks, then down the columns' inner fronts to the cuffs
# (lead review: the face was squeezed under the brim; the hood now frames it from behind and above, the whole front of the top left open)
OPENING = [(-0.37, 0.9), (-0.37, 1.2), (-0.41, 1.32), (-0.37, 1.45), (-0.2, 1.54), (0.2, 1.54), (0.37, 1.45), (0.41, 1.32), (0.37, 1.2), (0.37, 0.9)]
JACKET_Y = -0.05          # the jacket keeps what lies behind this (the hood), the face piece what lies in front of FACE_Y
FACE_Y = -0.02


def grow(poly, d):
    """the opening's outline pushed out by d (sides out, top up)"""
    return [(x + np.sign(x) * d, z + (d if z > 1.25 else 0.0) - (d if z < 0.95 else 0.0)) for x, z in poly]


def face_mass():
    return Ellipsoid((0, -0.1, 1.32), (0.4, 0.18, 0.175), part=SKIN)


def skin_top():
    """the bare skin over the arch's top: the tube with the broad face blended on its front"""
    return Union([tube(), face_mass()], k=0.07, part=SKIN)


def face_piece():
    """the face (fine voxels): the whole front of the arch's top, big and forward, its edge tucked under the jacket; two great heavy-lidded
    eyes up proud on top, a nose, a broad toothy grin"""
    sk = skin_top()
    look = v3((0.3, -1.0, 0.2)) / np.linalg.norm((0.3, -1.0, 0.2))
    ey = front_y(sk, EYE_C[0], EYE_C[2]) + 0.02
    ec = v3((EYE_C[0], ey, EYE_C[2]))
    lid_pt, lid_n = ec + v3((0, 0, 0.014)), v3((-0.2, 0.35, -1.0)) / np.linalg.norm((-0.2, 0.35, -1.0))
    low_pt, low_n = ec + v3((0, 0, -0.04)), v3((0.05, 0.2, 1.0)) / np.linalg.norm((0.05, 0.2, 1.0))
    mound = Ellipsoid(ec + v3((0, 0.01, 0.004)), (EYE_R + 0.02, 0.074, EYE_R * 0.8 + 0.022), part=SKIN)
    slot = Clip(Ellipsoid(ec, (0.14, 0.14, 0.14)), [Half(lid_pt, -lid_n), Half(low_pt, -low_n), Half(ec + look * 0.004, -look)])
    eye = Cut(mound, [slot], k=0.008)
    bag = Ellipsoid(ec + v3((0.006, -0.004, -0.066)), (0.08, 0.045, 0.028), part=SKIN)
    brow = Ellipsoid(ec + v3((-0.01, 0.02, 0.05)), (0.085, 0.05, 0.03), R=rot(ry=-12), part=SKIN)
    ball = Ellipsoid(ec, (EYE_R, 0.062, EYE_R * 0.8), part=EYE)
    nose = Ellipsoid((0, front_y(sk, 0.0, 1.345) + 0.018, 1.345), (0.045, 0.024, 0.026), part=SKIN)
    cheeks = Mirror(Ellipsoid((0.22, front_y(sk, 0.22, 1.275) + 0.028, 1.275), (0.1, 0.045, 0.055), part=SKIN))
    f = Union([sk, Mirror(eye), Mirror(bag), Mirror(brow), nose, cheeks], k=0.022)
    nostrils = Mirror(Ellipsoid((0.026, front_y(sk, 0.026, 1.352) - 0.004, 1.352), (0.009, 0.011, 0.007), R=rot(rx=-30)))
    f = Cut(f, [nostrils], k=0.002)
    # the grin: broad, its corners hooked up under the eyes, a dark mouth behind a row of small crooked teeth
    top = lambda x: 1.292 + 0.036 * (x / 0.27) ** 2
    my = front_y(f, 0.0, 1.27)
    outline = [(-0.275, 1.33), (-0.22, 1.29), (-0.12, 1.258), (0.0, 1.248), (0.12, 1.258), (0.22, 1.29), (0.275, 1.33)]
    outline += [(x, top(x)) for x in (0.262, 0.18, 0.09, 0.0, -0.09, -0.18, -0.262)]
    grin = prism(outline, y0=-0.6, y1=my + 0.05)
    teeth = []
    for i, x in enumerate(np.linspace(-0.22, 0.22, 19)):
        if i in (6, 11, 15):
            continue                          # gaps
        zt = top(x) + 0.003
        h = 0.012 + 0.005 * ((i * 7) % 3) / 2
        ty = front_y(f, x, zt - 0.004) + 0.008
        teeth.append(Gem((x, ty, zt - h * 0.45), (0.008, 0.008, 0.005, 0.005, h, 0.006), soft=0.3, R=rot(rz=((i * 37) % 11 - 5) * 2.0), part=TOOTH))
    for x in (-0.14, -0.07, 0.03, 0.1, 0.16):
        zb = 1.248 + 0.07 * (x / 0.27) ** 2
        teeth.append(Gem((x, front_y(f, x, zb + 0.004) + 0.01, zb + 0.003), (0.0065, 0.0065, 0.004, 0.004, 0.004, 0.01), soft=0.3, part=TOOTH))
    f = Cut(f, [grin], k=0.004)
    gullet = Ellipsoid((0, my + 0.065, 1.29), (0.28, 0.04, 0.05), part=MOUTH)
    zone = prism(grow(OPENING, 0.03), y0=-0.7, y1=FACE_Y)
    f = Clip(f, [zone], k=0.0)
    return Union([f, gullet, Mirror(ball)] + teeth, k=0.0)


def spike(base, d, L, r):
    d = v3(d) / np.linalg.norm(d)
    return Union([RoundCone(base - d * 0.03, base + d * L, r, 0.005, part=SPIKE)], k=0.0)


def jacket_piece():
    """the tracksuit top worn over the bend: the hood zipped round the face, open down the columns' inner fronts, each column through a sleeve
    ending in a ribbed cuff; spikes poking through"""
    t = Union([tube(), face_mass()], k=0.07)
    shell = Inflate(t, 0.026, part=JACKET)
    puff = Clip(Inflate(t, 0.045, part=JACKET), [Half((0, 0, 0.975), (0, 0, -1)), Half((0, 0, 1.13), (0, 0, 1)), Mirror(Half((0.28, 0, 0), (-1, 0, 0)))], k=0.05)
    j = Union([shell, puff], k=0.05, part=JACKET)

    def folds(P):
        """soft creases of a baggy velour top, running round the bend"""
        return 0.5 + 0.5 * np.sin(np.arctan2(P[:, 2] - BEND_Z, P[:, 0]) * 14.0 + noise3(P, 0.08) * 3.0) * (0.6 + 0.4 * noise3(P + 1.3, 0.05))
    j = Bump(j, folds, 0.007)
    j = Clip(j, [Half((0, 0, 0.975), (0, 0, -1))], k=0.004)
    j = Cut(j, [prism(OPENING, y0=-0.7, y1=JACKET_Y)], k=0.006)
    # the hood's gathered rim, lying back over the crown behind the eyes and down either side of the face
    rim_pts = [(v3((x, JACKET_Y + 0.006, top_z(t, x, JACKET_Y) + 0.006)), 0.03) for x in np.linspace(-0.39, 0.39, 13)]
    rim = loft(rim_pts, part=JACKET, k=0.02)
    cuffs = Mirror(Clip(Inflate(t, 0.038, part=RIB), [Half((0, 0, 0.995), (0, 0, 1)), Half((0, 0, 0.905), (0, 0, -1)), Half((0.27, 0, 0), (-1, 0, 0))], k=0.006))

    def ribs(P):
        a = np.arctan2(P[:, 1], np.abs(P[:, 0]) - COL_X)
        return 0.5 + 0.5 * np.cos(a * 30.0)
    cuffs = Bump(cuffs, ribs, 0.0016)
    spikes = Mirror(Union([spike(v3((0.30, 0.02, 1.44)), (0.3, 0.0, 1.0), 0.08, 0.034), spike(v3((0.6, 0.0, 1.22)), (1.0, 0.0, 0.55), 0.075, 0.034)]))
    pull = Union([Box((0.33, -0.12, 1.01), (0.012, 0.004, 0.028), rr=0.003, R=rot(rz=8), part=ZIP),
                  Box((0.33, -0.115, 1.045), (0.008, 0.006, 0.01), rr=0.002, part=ZIP)], k=0.0)
    return Union([Union([j, rim], k=0.012, part=JACKET), cuffs, spikes, pull], k=0.0)


def body_piece():
    """the arch's skin (bar the face), the leg warmers and the columns' spikes"""
    t = Cut(skin_top(), [prism(grow(OPENING, 0.012), y0=-0.7, y1=(JACKET_Y + FACE_Y) * 0.5)], k=0.0)
    col = RoundCone((COL_X, 0.0, 0.3), (COL_X, 0.0, 0.62), R_COL)      # (not wrapped in a Union: a Union culls what lies 2 cm past its bound, so inflating one further leaves holes)
    warm = Clip(Inflate(col, 0.024, part=WARMER), [Half((0, 0, 0.545), (0, 0, 1)), Half((0, 0, 0.32), (0, 0, -1))], k=0.008)

    def ribs(P):
        a = np.arctan2(P[:, 1], np.abs(P[:, 0]) - COL_X)
        return 0.5 + 0.5 * np.cos(a * 34.0)
    warm = Bump(warm, ribs, 0.0015)
    sp = Union([spike(v3((0.64, 0.0, 0.72)), (1.0, 0.0, 0.15), 0.085, 0.04), spike(v3((0.32, -0.04, 0.76)), (-1.0, -0.3, 0.2), 0.06, 0.03),
                spike(v3((0.63, 0.06, 0.62)), (1.0, 0.3, -0.1), 0.06, 0.03)])
    return Union([t, Mirror(warm), Mirror(sp)], k=0.0)


def shoe():
    """the left sneaker: a thick cupsole, a chunky upper, a padded collar round the column, laces"""
    x = COL_X
    toe = Ellipsoid((x, -0.235, 0.105), (0.165, 0.14, 0.085), part=SHOE)
    mid = Ellipsoid((x, -0.07, 0.15), (0.19, 0.2, 0.13), part=SHOE)
    heel = Ellipsoid((x, 0.1, 0.17), (0.185, 0.14, 0.16), part=SHOE)
    collar = Torus((x, 0.03, 0.3), 0.165, 0.038, part=SHOE)
    whole = Union([toe, mid, heel, collar], k=0.06, part=SHOE)
    up = Cut(whole, [RoundCone((x, 0.01, 0.25), (x, 0.01, 0.55), R_COL - 0.04)], k=0.012)
    # a chunky cupsole wrapping up round the upper's foot, a flat lugged bottom
    cup = Clip(Inflate(Union([toe, mid, heel], k=0.06), 0.014, part=SOLE), [Half((0, 0, 0.075), (0, 0, 1))], k=0.006)
    out = Box((x, -0.07, 0.028), (0.18, 0.285, 0.028), rr=0.025, part=SOLE)
    sole = Union([cup, out], k=0.02, part=SOLE)
    tongue = Box((x, -0.15, 0.27), (0.085, 0.026, 0.08), rr=0.022, R=rot(rx=-38), part=SHOE)
    # (the laces are painted on: thin modelled laces decimated into spikes and baked black holes in the game model)
    return Union([sole, Union([up, tongue], k=0.02)], k=0.0)


def shoes_piece():
    return Mirror(shoe())


def hand():
    """the little left hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y)"""
    parts = [Ellipsoid((0.0, 0.0, -0.03), (0.013, 0.027, 0.032), part=SKIN)]
    for f, L in ((-0.017, 0.85), (-0.006, 1.0), (0.006, 0.97), (0.017, 0.82)):
        pts = [((0.0, f, -0.055), 0.0072), ((-0.004, f, -0.055 - 0.025 * L), 0.0066), ((-0.014, f, -0.078 - 0.02 * L), 0.006)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.003))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((-0.002, 0, -0.003)), (0.0045, 0.005, 0.004), part=NAIL))
    parts.append(loft([(v3((-0.008, -0.022, -0.018)), 0.0085), (v3((-0.018, -0.032, -0.04)), 0.0072), (v3((-0.026, -0.03, -0.058)), 0.0062)], part=SKIN, k=0.003))
    return Union(parts, k=0.006)


def arms_piece():
    limb = loft([(SH + v3((0.03, 0.02, 0.0)), 0.042), (SH, 0.038), (EL, 0.031), (WR, 0.027)], part=SKIN, k=0.01)
    return Mirror(Union([limb, place(hand(), WR, HAND)], k=0.008))


def pieces():
    import os
    out = [("face", face_piece(), 0.0018), ("body", body_piece(), 0.0035), ("jacket", jacket_piece(), 0.003), ("shoes", shoes_piece(), 0.003),
           ("arms", arms_piece(), 0.002)]
    only = os.environ.get("FOLK_ONLY")          # dev: build a few pieces only, to look at a face quickly
    return [p for p in out if p[0] in only.split(",")] if only else out


# ---------------------------------------------------------------------------------------------------- paint

def _open_dist(x, z):
    """distance (front view) from (x, z) to the opening's outline"""
    poly = np.array(OPENING, np.float32)
    d = np.full(len(x), 1e9, np.float32)
    for i in range(len(poly) - 1):
        a, b = poly[i], poly[i + 1]
        ab = b - a
        t = np.clip(((x - a[0]) * ab[0] + (z - a[1]) * ab[1]) / float(ab @ ab), 0.0, 1.0)
        d = np.minimum(d, np.hypot(x - a[0] - t * ab[0], z - a[1] - t * ab[1]))
    return d


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

    # skin: sea green, paler on the face and the columns' fronts, a fine scale of darker freckles, rusty flecks, pink slash scars on the columns
    m = c.mask(SKIN)
    sk = np.broadcast_to(srgb(98, 158, 138), (n, 3)).copy()
    sk = sk + (srgb(132, 184, 162) - sk) * (smooth(0.0, -0.18, y) * 0.5)[:, None]
    sk *= (1.0 + 0.08 * mott)[:, None]
    sk = sk + (srgb(64, 108, 94) - sk) * (c.cavity * 0.6)[:, None]
    scale = noise3(P * v3((1, 1, 1)), 0.009)
    sk *= (1.0 - 0.06 * smooth(0.2, 0.6, scale))[:, None]
    # the scars: two X slashes on each column's front
    for (cx, cz, a, L) in ((0.47, 0.7, 40.0, 0.12), (0.5, 0.66, -35.0, 0.09), (0.45, 0.6, 30.0, 0.07)):
        u = (Q[:, 0] - cx) * np.cos(np.radians(a)) + (z - cz) * np.sin(np.radians(a))
        v = -(Q[:, 0] - cx) * np.sin(np.radians(a)) + (z - cz) * np.cos(np.radians(a))
        on = (np.abs(u) < L) & (y < -0.06)
        w = 0.006 * (1.0 - (u / L) ** 2)
        scar = on & (np.abs(v) < w + 0.004)
        sk = np.where(scar[:, None], sk + (srgb(214, 128, 116) - sk) * smooth(w + 0.003, w * 0.3, np.abs(v))[:, None], sk)
    put(m, sk[m], 0.5, bump=0.4, grain=1.0)
    spk(m, (150, 96, 70), 0.4)
    # the face's ink: heavy lids, the brow crease, the grin's line, nostrils
    m = c.mask(SKIN) & (y < -0.05) & (z > 1.2)
    de = Q - v3((EYE_C[0], 0.0, EYE_C[2]))
    re = np.hypot(de[:, 0] / (EYE_R + 0.012), de[:, 2] / (EYE_R * 0.8 + 0.01))
    c.draw(m & (re < 1.35) & (de[:, 2] > -0.01), np.abs(re - 1.05) * 0.03, 0.0012, 0.6)
    c.draw(m & (re > 1.2) & (re < 1.7) & (de[:, 2] > 0.02), np.abs(re - 1.45) * 0.03, 0.0008, 0.35)

    # eyes: amber, deeper orange at the rims, a brown pupil rolled up and off to its left (sly), a glint
    m = c.mask(EYE)
    ec = np.where((x > 0)[:, None], v3((EYE_C[0], 0, EYE_C[2])), v3((-EYE_C[0], 0, EYE_C[2])))
    dd = P - ec
    dd[:, 1] = 0.0
    pc = v3((0.016, 0.0, 0.006))
    pd = np.hypot(dd[:, 0] - pc[0], dd[:, 2] - pc[2])
    ev = srgb(236, 160, 84) + (srgb(196, 104, 44) - srgb(236, 160, 84)) * smooth(0.02, 0.06, np.hypot(dd[:, 0], dd[:, 2] * 1.3))[:, None]
    ev = ev + (srgb(92, 50, 22) - ev) * smooth(0.026, 0.018, pd)[:, None]
    c.draw(m, pd - 0.013, 0.0)
    gl = np.hypot(dd[:, 0] - 0.012, dd[:, 2] - 0.022)
    ev = ev + (srgb(255, 246, 230) - ev) * smooth(0.008, 0.004, gl)[:, None]
    put(m, ev[m], 0.08)
    m = c.mask(TOOTH)
    put(m, (srgb(222, 206, 160) * (1.0 - 0.3 * c.cavity)[:, None])[m], 0.3)
    put(c.mask(MOUTH), srgb(60, 18, 24), 0.5)

    # the jacket: plum velour, two white stripes down each side from the shoulder to the cuff, scuffed; the zip's teeth along the opening
    m = c.mask(JACKET, RIB)
    jk = np.broadcast_to(srgb(150, 100, 172), (n, 3)).copy()
    jk *= (1.0 + 0.07 * mott)[:, None]
    jk = jk + (srgb(98, 58, 118) - jk) * (c.cavity * 0.7)[:, None]
    jk = jk + (srgb(186, 150, 196) - jk) * (c.wear * 0.4)[:, None]
    # the stripes run along the arch's outer curve: distance out from the centreline, measured round the tube
    ax = np.arctan2(z - BEND_Z, Q[:, 0])
    rad_c = np.where(z > BEND_Z, np.hypot(Q[:, 0] / COL_X, (z - BEND_Z) / (APEX - BEND_Z)), Q[:, 0] / COL_X)
    side_a = np.arctan2(-y, np.where(z > BEND_Z, (rad_c - 1.0) * 0.4, Q[:, 0] - COL_X))       # 0 straight out, + toward the front
    st = (np.abs(side_a - 0.55) < 0.07) | (np.abs(side_a - 0.78) < 0.07)
    jm = c.mask(JACKET)
    jk = np.where((st & jm)[:, None], srgb(232, 226, 214) * (1.0 - 0.3 * c.cavity)[:, None], jk)
    rb = c.mask(RIB)
    rib_l = 0.5 + 0.5 * np.cos(np.arctan2(y, Q[:, 0] - COL_X) * 30.0)
    jk = np.where(rb[:, None], jk * (0.8 + 0.2 * rib_l)[:, None], jk)
    od = _open_dist(x, z)
    zipm = jm & (y < -0.02) & (od < 0.011)
    teeth = 0.5 + 0.5 * np.sign(np.sin((x + z) * 900.0))
    jk = np.where(zipm[:, None], srgb(200, 198, 190)[None, :] * (0.75 + 0.25 * teeth)[:, None], jk)
    put(m, jk[m], 0.78, bump=1.0)
    c.rough[zipm] = 0.4
    c.metal[zipm] = 0.5
    spk(jm & ~zipm, (120, 86, 70), 0.15)
    put(c.mask(ZIP), srgb(184, 184, 178), 0.3, metal=1.0)
    # spikes: old bone, darker to the tips
    m = c.mask(SPIKE)
    sp = srgb(226, 204, 168) * (1.0 - 0.3 * c.cavity)[:, None] * (1.0 + 0.08 * mott)[:, None]
    put(m, sp[m], 0.55, bump=0.4, grain=1.0)
    spk(m, (150, 120, 90), 0.3)
    # leg warmers: cream ribbing, a plum band round the middle
    m = c.mask(WARMER)
    wm = srgb(230, 218, 194) * (1.0 - 0.35 * c.cavity)[:, None]
    wm = np.where((np.abs(z - 0.44) < 0.028)[:, None], srgb(146, 96, 168) * (1.0 - 0.35 * c.cavity)[:, None], wm)
    put(m, wm[m], 0.9, bump=1.0)
    spk(m, (150, 120, 90), 0.2)
    # sneakers: scuffed off-white leather, plum and grey panels, a dirty sole, cream laces
    m = c.mask(SHOE)
    sh = srgb(214, 206, 192) * (1.0 + 0.06 * mott)[:, None]
    # a plum swoosh along each side, a grey heel panel
    sw = (np.abs(Q[:, 0] - COL_X) > 0.12) & (np.abs(z - (0.13 + 0.25 * (y + 0.05))) < 0.028) & (y > -0.22) & (y < 0.12)
    sh = np.where(sw[:, None], srgb(132, 100, 156), sh)
    sh = np.where(((np.abs(Q[:, 0] - COL_X) > 0.1) & (z > 0.17) & (y > 0.06))[:, None], srgb(128, 124, 128), sh)
    sh = sh + (srgb(140, 120, 96) - sh) * (smooth(0.3, 0.7, noise3(P + 1.1, 0.03)) * 0.4)[:, None]
    # the laces: cream criss-crosses over a grey throat down the instep, outlined in ink
    lx = Q[:, 0] - COL_X
    throat = (np.abs(lx) < 0.075) & (y > -0.28) & (y < -0.07) & (z > 0.16)
    sh = np.where(throat[:, None], srgb(120, 116, 118), sh)
    ph = (y + 0.28) / 0.05
    cross = np.minimum(np.abs(lx - (ph - np.floor(ph) - 0.5) * 0.15), np.abs(lx + (ph - np.floor(ph) - 0.5) * 0.15))
    lace = throat & (cross < 0.009)
    sh = np.where(lace[:, None], srgb(232, 222, 200), sh)
    c.draw(throat & (np.abs(cross - 0.009) < 0.003), np.abs(cross - 0.009), 0.0007, 0.5)
    sh *= (1.0 - 0.35 * c.cavity)[:, None]
    put(m, sh[m], 0.6, bump=0.6, grain=1.0)
    spk(m, (120, 100, 80), 0.4)
    m = c.mask(SOLE)
    so = srgb(222, 210, 186) + (srgb(150, 124, 94) - srgb(222, 210, 186)) * (smooth(0.03, 0.0, z) * 0.7 + smooth(0.3, 0.7, noise3(P, 0.02)) * 0.3)[:, None]
    put(m, so[m], 0.75, bump=0.6)
    spk(m, (110, 90, 70), 0.5)
    put(c.mask(LACE), (srgb(226, 216, 196) * (1.0 - 0.3 * c.cavity)[:, None])[c.mask(LACE)], 0.85, bump=0.5)
    put(c.mask(NAIL), srgb(60, 90, 80), 0.3)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"face": 2300, "body": 2700, "jacket": 2200, "shoes": 1900, "arms": 600},
    "density": {"face": 1.6, "arms": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.9, "run": 1.4},
    "speed": 0.85,
    # it has no neck: its face is the top of the arch, so it does not turn to look (no look bones)
    "look": [], "neck": "-",
    "look_pivot": (0.0, -0.1, 1.3),
    "radius": 0.72,
}


def rig_bones():
    from kit.rig import Bone, mirror
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("arch", (0, 0.0, 1.12), (0, 0.0, 1.46), "root", 0.22),
        Bone("thigh.L", HIP, KNEE, "arch", 0.18),
        Bone("shin.L", KNEE, ANKLE, "thigh.L", 0.18),
        Bone("foot.L", ANKLE, ANKLE + v3((0.0, -0.3, -0.1)), "shin.L", 0.12),
        Bone("arm.L", SH, EL, "thigh.L", 0.035),
        Bone("forearm.L", EL, WR, "arm.L", 0.03),
        Bone("hand.L", WR, WR - HAND[:, 2] * 0.08, "forearm.L", 0.02),
    ])


def skin_rules(P, part, piece, names):
    """piece: 0 face, 1 body, 2 jacket, 3 shoes, 4 arms"""
    n = len(P)
    ix = {nm: i for i, nm in enumerate(names)}
    A = np.zeros((n, len(names)), bool)
    rig = np.full(n, -1)
    x, y, z = P[:, 0], P[:, 1], P[:, 2]

    def allow(m, *bn):
        for b in bn:
            A[m, ix[b]] = True
    top = z > 1.15
    # the face rides the arch; its lower corners (the columns' inner fronts) bend with the columns
    fp = piece == 0
    rig[fp & (z > 1.2)] = ix["arch"]
    allow(fp, "arch")
    allow(fp & (z <= 1.08) & (np.abs(x) > 0.25) & (x > 0), "thigh.L")      # only the columns' inner fronts bend with the legs
    allow(fp & (z <= 1.08) & (np.abs(x) > 0.25) & (x < 0), "thigh.R")
    # skin, jacket: the arch over the top, each column below on its own leg
    for pc in (1, 2):
        m = piece == pc
        allow(m, "arch")
        for s, sd in ((1, "L"), (-1, "R")):
            side = m & (x * s > 0.12) & (z < 1.3)
            allow(side, "thigh." + sd)
            allow(side & (z < 0.8), "shin." + sd)
        rig[m & (part == SPIKE) & (z > 1.15)] = ix["arch"]
    # spikes on the columns ride their thigh
    for s, sd in ((1, "L"), (-1, "R")):
        rig[(piece == 1) & (part == SPIKE) & (x * s > 0)] = ix["thigh." + sd]
        rig[(piece == 2) & (part == ZIP) & (x * s > 0)] = ix["thigh." + sd]
    # shoes: on their feet; the collar bends with the shin
    sp = piece == 3
    for s, sd in ((1, "L"), (-1, "R")):
        m = sp & (x * s > 0)
        allow(m, "shin." + sd, "foot." + sd)
        rig[m & (z < 0.2)] = ix["foot." + sd]
    # the little arms
    ap = piece == 4
    for s, sd in ((1, "L"), (-1, "R")):
        m = ap & (x * s > 0)
        allow(m, "thigh." + sd, "arm." + sd, "forearm." + sd, "hand." + sd)
        rig[m & (np.abs(x) < WR[0] + 0.005) & (((P * v3((s, 1, 1)) - WR) @ -HAND[:, 2]) > 0.0)] = ix["hand." + sd]
    return A, rig


WALK = dict(stride=0.9, stance=0.62, lift=0.075, sway=0.07, roll=7.0, yaw=6.0, bob=0.016, drop=0.06, lean=2.0, toe_off=16.0, swing_point=8.0)
RUN = dict(stride=1.4, stance=0.44, lift=0.11, sway=0.05, roll=6.0, yaw=8.0, bob=-0.03, drop=0.075, lean=5.0, toe_off=20.0, swing_point=10.0)


def motions(rig):
    """its clips: walk (each column swings forward in turn, the whole arch rocking over onto the planted one and twisting after the stride,
    the little arms pumping), run (a bouncing lope, columns flung forward), idle (a smug sway from column to column, the little hands
    rubbing together, a pleased bounce)"""
    import math
    from mathutils import Vector, Matrix
    from kit.gait import Pose, R, TAU, ease
    f = np.array([-1, 1, 1], np.float32)
    ball = {"L": Vector((COL_X, -0.12, 0.0)), "R": Vector((-COL_X, -0.12, 0.0))}
    ank = {"L": Vector(ANKLE.tolist()), "R": Vector((ANKLE * f).tolist())}

    def leg(p, sd, fy, lift, pitch):
        s = 1.0 if sd == "L" else -1.0
        wf = R(pitch, 0, 0)
        b = Vector((ball[sd].x, ball[sd].y + fy, lift))
        a = b + wf @ (ank[sd] - ball[sd])
        p.ik["thigh." + sd] = (a, Vector((0.0, -1.0, 0.0)), "foot." + sd, wf)

    def gait(u, g, run):
        p = Pose()
        S, beta = g["stride"], g["stance"]
        for sd in ("L", "R"):
            uu = (u + (0.0 if sd == "L" else 0.5)) % 1.0
            if uu < beta:
                fy = -S * beta / 2 + S * uu
                lift, pitch = 0.0, g["toe_off"] * ease((uu - (beta - 0.18)) / 0.18)
            else:
                t = (uu - beta) / (1.0 - beta)
                fy = S * beta / 2 - S * beta * ease(t)
                lift = g["lift"] * math.sin(math.pi * t) ** 0.8
                pitch = g["toe_off"] * (1.0 - ease(t * 1.6)) - g["swing_point"] * math.sin(math.pi * t)
            leg(p, sd, fy, lift, pitch)
        # the arch rocks over the planted column (its top leaning that way), twists after the swinging one, bobs
        rock = math.sin(TAU * (u - 0.03))
        p.offset = Vector((g["sway"] * rock, 0.0, -g["drop"] + g["bob"] * math.cos(2 * TAU * (u - beta * 0.5))))
        p.rot("arch", g["lean"] + 1.5 * math.cos(2 * TAU * (u - 0.1)), g["roll"] * rock, -g["yaw"] * math.cos(TAU * u))
        for sd, s in (("L", 1.0), ("R", -1.0)):
            c = math.cos(TAU * u + (0.0 if sd == "L" else math.pi))
            p.rot("arm." + sd, (22.0 if run else 12.0) * c - (20.0 if run else 6.0), 0, s * 4.0 * rock)
            p.rot("forearm." + sd, -(25.0 if run else 10.0) - 8.0 * max(0.0, -c), 0, 0)
        return p
    walk = [gait(i / 32.0, WALK, False) for i in range(33)]
    run = [gait(i / 24.0, RUN, True) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        for sd in ("L", "R"):
            p.ik["thigh." + sd] = (ank[sd], Vector((0.0, -1.0, 0.0)), "foot." + sd, Matrix.Identity(3))
        sw = math.sin(TAU * t / 3.0)
        glee = math.exp(-((t - 4.2) / 0.25) ** 2)
        p.offset = Vector((0.03 * sw, 0.0, -0.012 - 0.03 * glee + 0.004 * math.sin(TAU * t / 1.5)))
        p.rot("arch", 1.0 + 2.0 * glee, 3.5 * sw, 3.0 * math.sin(TAU * t / 6.0))
        # the little hands rub together, slyly
        rub = math.sin(TAU * t * 2.2) * ease((t - 0.8) / 0.3) * (1.0 - ease((t - 3.4) / 0.3))
        for sd, s in (("L", 1.0), ("R", -1.0)):
            p.rot("arm." + sd, -14.0 + 6.0 * rub * s, 0, s * 10.0)
            p.rot("forearm." + sd, -20.0, 0, s * (8.0 + 3.0 * rub))
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
