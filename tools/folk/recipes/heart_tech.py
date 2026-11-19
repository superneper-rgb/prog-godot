## FOINT CITY townsfolk: the heart tech (working name; the user names it). A pale pink heart of a creature: big glossy black eyes and buck teeth in the lower lobe, the two upper lobes grown into huge floppy ears that taper down into thin arms, one leg in a great buckled boot, a long thin tail with a bulb, a mustard tool vest and glasses pushed up on its head.
# Concept: the user's sheet, image 6 bottom right (F:/prog-godot-cache/folk/refs/6.webp). Measured off a 3x crop (830 px a metre): 1.30 m to the tops of the
# ears; the heart 0.7 wide at the eyes, 1.05 across the ears, narrowing to its point at 0.56; eyes 0.13 wide, tilted, at 0.85; the teeth at 0.75; the boot
# 0.48 tall and 0.42 long under a thin stalk of a leg; the tail's bulb at 0.29. Rest pose = its fidgety stance: elbows low, forearms up, hands open by
# its sides (the soldering iron and the cable are dropped). It gets about by pogo hops on its one leg, the tail swinging for balance.
import numpy as np
from kit.sdf import (Sphere, Ellipsoid, RoundCone, CappedCone, Box, Torus, Gem, Slab, Half, Union, Cut, Clip, Mirror, Move, Inflate, Bump,
                     loft, rot, v3, basis, place, noise3)

HEIGHT = 1.30
REF = ("6.webp", (425, 372, 798, 764))

SKIN, EYE, TOOTH, LIP, VEST, STRAP, TOOL, TOOLRED, FRAME, LENS, BOOT, SOLE, BUCKLE, CUFF, NAIL = range(1, 16)
COLOURS = {
    SKIN: ((0.80, 0.56, 0.48), 0.55, 0.0),
    EYE: ((0.01, 0.01, 0.015), 0.05, 0.0),
    TOOTH: ((0.84, 0.78, 0.62), 0.3, 0.0),
    LIP: ((0.66, 0.36, 0.34), 0.45, 0.0),
    VEST: ((0.62, 0.42, 0.12), 0.8, 0.0),
    STRAP: ((0.50, 0.32, 0.10), 0.75, 0.0),
    TOOL: ((0.55, 0.56, 0.58), 0.35, 1.0),
    TOOLRED: ((0.55, 0.06, 0.05), 0.35, 0.0),
    FRAME: ((0.03, 0.03, 0.03), 0.3, 0.0),
    LENS: ((0.6, 0.65, 0.7), 0.05, 0.0),
    BOOT: ((0.34, 0.12, 0.13), 0.5, 0.0),
    SOLE: ((0.20, 0.17, 0.15), 0.8, 0.0),
    BUCKLE: ((0.55, 0.55, 0.52), 0.35, 1.0),
    CUFF: ((0.78, 0.72, 0.62), 0.9, 0.0),
    NAIL: ((0.75, 0.50, 0.45), 0.35, 0.0),
}


# ---------------------------------------------------------------------------------------------------- helpers

def prism(poly_xz, y0=-0.7, y1=0.0):
    """a front-view outline (x, z) pushed through the figure from y0 to y1"""
    return Slab((0, (y0 + y1) * 0.5, 0), poly_xz, (y1 - y0) * 0.5, R=np.array([[1, 0, 0], [0, 0, 1], [0, 1, 0]], np.float32))


def front_y(shape, x, z, y0=-0.8, y1=0.4):
    ys = np.arange(y0, y1, 0.0005, dtype=np.float32)
    P = np.stack([np.full_like(ys, x), ys, np.full_like(ys, z)], 1)
    d = shape.eval(P)[0]
    return float(ys[int(np.argmax(d < 0))])


# ---------------------------------------------------------------------------------------------------- framing (a kit gap, worked round here)
# kit/look.render_views frames a figure 0.62 as wide as it is tall and aims its face views at 0.9 of its height: its ears are 1.05 across and its
# face sits at 0.62 of its height, in the heart's lower lobe. The same renderer with a wider frame and the face views aimed at its face.
VIEW_ASPECT = 0.95
FACE_AT = v3((0.0, -0.17, 0.84))
FACE_DIST = 1.35


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
            "bust": ((-2.2 * math.sin(math.radians(30)), -2.2 * math.cos(math.radians(30)), 1.05), (0.05, 0.0, 0.9), None),
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
POINT = v3((0.0, 0.02, 0.56))          # the heart's point, where the leg stalk begins
KNEE = v3((0.0, 0.0, 0.445))           # the top of the boot, where the stalk goes in
ANKLE = v3((0.0, 0.035, 0.105))
TOE = v3((0.0, -0.3, 0.05))
EYE_C = v3((0.122, 0.0, 0.855))        # its y is found on the face
EYE_TILT = 34.0                        # the eyes' outer corners raised
# the ear: from the crown out and up, over, and down into the arm
EAR = [(v3((0.10, 0.03, 1.11)), 0.17), (v3((0.27, 0.04, 1.205)), 0.15), (v3((0.43, 0.05, 1.215)), 0.115), (v3((0.55, 0.06, 1.15)), 0.08),
       (v3((0.575, 0.06, 1.05)), 0.052), (v3((0.54, 0.05, 0.96)), 0.034)]
SH = EAR[-1][0]
EL = v3((0.5, 0.0, 0.64))
WR = v3((0.6, -0.08, 0.83))
HAND = basis(-v3((0.3, -0.15, 1.0)), v3((-0.95, 0.0, 0.3)))      # the open hand, fingers up and a little out, palm in toward the body
TAIL = [(v3((0.0, 0.13, 0.62)), 0.02), (v3((0.08, 0.24, 0.58)), 0.016), (v3((0.17, 0.27, 0.48)), 0.013), (v3((0.2, 0.25, 0.38)), 0.012),
        (v3((0.19, 0.22, 0.33)), 0.012)]
BULB = (v3((0.185, 0.215, 0.255)), v3((0.048, 0.048, 0.07)))


def squash(child, sx=1.0, sy=1.0, sz=1.0, at=(0, 0, 0)):
    """the child shrunk by (sx, sy, sz) <= 1 about `at` (gentle squashes: the distance stays near true, the bound stays safe)"""
    return Move(child, R=np.diag([1.0 / sx, 1.0 / sy, 1.0 / sz]).astype(np.float32), pivot=at)


def heart_core():
    """the heart without its ears: two lobes over a broad front narrowing in straight sides to the point"""
    lobes = Mirror(Ellipsoid((0.155, 0.0, 1.0), (0.215, 0.18, 0.2)))
    fill = Ellipsoid((0.0, 0.0, 0.95), (0.3, 0.18, 0.17))
    cone = squash(RoundCone((0.0, 0.0, 0.9), POINT + v3((0, 0, 0.02)), 0.31, 0.035), sy=0.6)
    return Union([lobes, fill, cone], k=0.08, part=SKIN)


def ear():
    """a flat floppy ear: the lobe's tube squashed front to back"""
    return squash(loft(EAR, part=SKIN, k=0.04), sy=0.55, at=(0.0, 0.05, 0.0))


def hand():
    """the open left hand in hand space (wrist at the origin, fingers along -Z, back of the hand +X, thumb -Y): long thin fingers, gently curled"""
    parts = [Ellipsoid((0.0, 0.0, -0.034), (0.012, 0.028, 0.036), part=SKIN), RoundCone((0, 0, 0.02), (0, 0, -0.01), 0.022, 0.02, part=SKIN)]
    for f, L in ((-0.019, 0.85), (-0.0065, 1.0), (0.0065, 0.97), (0.019, 0.82)):
        pts = [((0.0, f, -0.062), 0.0072), ((-0.004, f, -0.062 - 0.03 * L), 0.0066), ((-0.012, f, -0.09 - 0.025 * L), 0.006), ((-0.022, f, -0.1 - 0.018 * L), 0.0055)]
        parts.append(loft([(v3(p), r) for p, r in pts], part=SKIN, k=0.003))
        parts.append(Ellipsoid(v3(pts[-1][0]) + v3((0.0, 0, -0.003)), (0.0042, 0.0048, 0.0042), part=NAIL))
    parts.append(loft([(v3((-0.008, -0.022, -0.016)), 0.0085), (v3((-0.02, -0.036, -0.04)), 0.0072), (v3((-0.03, -0.034, -0.062)), 0.0062)], part=SKIN, k=0.003))
    return Union(parts, k=0.006)


def arm():
    limb = loft([(EAR[-2][0], 0.05), (SH, 0.034), (EL, 0.026), (WR, 0.022)], part=SKIN, k=0.012)
    return Union([limb, place(hand(), WR, HAND)], k=0.006)


def body():
    """the heart, its ears grown out of its lobes and down into the arms, the stalk of a leg, the tail"""
    h = Union([heart_core(), Mirror(ear())], k=0.06, part=SKIN)
    stalk = loft([(POINT + v3((0, 0, 0.04)), 0.045), (POINT, 0.04), (KNEE, 0.036), (KNEE + v3((0, 0.01, -0.06)), 0.035)], part=SKIN, k=0.02)
    tail = loft(TAIL, part=SKIN, k=0.01)
    bulb = Ellipsoid(BULB[0], BULB[1], part=SKIN)
    b = Union([h, stalk], k=0.05, part=SKIN)
    b = Union([b, Mirror(arm()), Union([tail, bulb], k=0.02)], k=0.012)
    return b


def eye_frame():
    """the left eye's frame (rotation) and centre on the face: tilted, turned a little outward with the face"""
    Rm = rot(ry=-EYE_TILT, rz=-14.0)
    return Rm


def face_detail(b):
    """lidded sockets for the eyes, brows, cheeks, the smile, nostrils: sculpted into the heart"""
    Rm = eye_frame()
    ey = front_y(b, EYE_C[0], EYE_C[2])
    ec = v3((EYE_C[0], ey + 0.01, EYE_C[2]))
    mound = Ellipsoid(ec + v3((0, 0.004, 0)), (0.09, 0.045, 0.046), R=Rm, part=SKIN)
    slot = Ellipsoid(ec + v3((0.0, -0.036, 0.0)), (0.078, 0.045, 0.031), R=Rm)       # an almond opening, pointed at the corners
    sock = Cut(mound, [slot], k=0.006)
    brow = Ellipsoid(ec + v3((-0.006, 0.006, 0.062)), (0.07, 0.02, 0.012), R=rot(ry=-EYE_TILT * 0.7, rz=-14.0), part=SKIN)
    cheek = Ellipsoid(ec + v3((0.012, 0.012, -0.058)), (0.05, 0.022, 0.028), R=Rm, part=SKIN)
    f = Union([b, Mirror(sock), Mirror(brow), Mirror(cheek)], k=0.018)
    my = front_y(b, 0.0, 0.752)
    smile = prism([(-0.078, 0.77), (-0.06, 0.752), (-0.03, 0.742), (0.0, 0.74), (0.03, 0.742), (0.058, 0.75), (0.068, 0.758),
                   (0.06, 0.762), (0.03, 0.755), (0.0, 0.754), (-0.03, 0.756), (-0.06, 0.763), (-0.074, 0.776)], y0=-0.6, y1=my + 0.03)
    f = Cut(f, [smile], k=0.004)
    lip = Ellipsoid((0.0, my + 0.006, 0.764), (0.045, 0.012, 0.008), part=LIP)
    nost = Mirror(Ellipsoid((0.012, front_y(b, 0.012, 0.79) - 0.002, 0.79), (0.004, 0.006, 0.003), R=rot(rx=-30)))
    f = Cut(Union([f, lip], k=0.01), [nost], k=0.002)
    return f, ec, Rm, my


def body_piece():
    f, _, _, _ = face_detail(body())
    return f


def face_piece():
    """the eyes (glossy black almonds in their sockets) and the two buck teeth (fine voxels)"""
    _, ec, Rm, my = face_detail(body())
    ball = Ellipsoid(ec, (0.075, 0.038, 0.034), R=Rm, part=EYE)
    teeth = [Box((s * 0.0145, my + 0.006, 0.733), (0.0135, 0.0065, 0.027), rr=0.0045, R=rot(rx=-6, rz=s * 2.0), part=TOOTH) for s in (-1, 1)]
    return Union([Mirror(ball)] + teeth, k=0.0)


def surface_frame(shape, x, z, out=0.0):
    """(point on the front of the shape at (x, z), a frame lying on it there: x across, y up the surface, z out of it)"""
    y = front_y(shape, x, z)
    p = v3((x, y, z))
    e = 0.002
    g = np.array([shape.eval(np.array([p + d, p - d], np.float32))[0] @ np.array([1.0, -1.0]) for d in np.eye(3, dtype=np.float32) * e], np.float32)
    n = g / np.linalg.norm(g)
    across = np.cross(v3((0, 0, 1)), n)
    across /= np.linalg.norm(across)
    up = np.cross(n, across)
    return p + n * out, np.stack([across, up, n], 1).astype(np.float32)


def vest_piece():
    """the mustard tool vest: worn round the upper heart from the back and sides, open armholes where the ear-arms leave, an open front,
    the left panel loaded with pockets of tools, a narrow right panel; the glasses pushed up on its forehead
    (lead review: it read as a beanie over the crown; now a garment, lower, open in front)"""
    b = heart_core()
    w = Union([b, Mirror(squash(loft(EAR[:2], k=0.0), sy=0.55, at=(0.0, 0.05, 0.0)))], k=0.06)      # the crown and the ears' roots: its shoulders
    shell = Cut(Inflate(w, 0.022, part=VEST), [Inflate(w, 0.006)], k=0.002)
    # it covers the crown between the ears like a vest's shoulders, down to the heart's widest at the back and sides
    shell = Clip(shell, [Half((0, 0, 0.9), (0, 0.0, -1.0))], k=0.01)
    # armholes round the ears' roots, an open front between the panels over the forehead
    holes = Mirror(Ellipsoid((0.42, 0.05, 1.17), (0.13, 0.26, 0.2)))
    front = prism([(-0.07, 0.8), (0.17, 0.8), (0.17, 0.98), (0.2, 1.4), (-0.03, 1.4), (-0.07, 1.06)], y0=-0.7, y1=-0.02)
    brow = prism([(-0.4, 0.8), (0.4, 0.8), (0.4, 0.94), (0.17, 0.98), (-0.07, 0.98), (-0.25, 0.92), (-0.4, 0.9)], y0=-0.7, y1=-0.08)
    shell = Cut(shell, [holes, front, brow], k=0.008)
    # the left panel: a deep pocket of tools and a flap pocket below it; the right panel: a strip with a pen loop
    pp, pM = surface_frame(Inflate(b, 0.022), -0.2, 1.05, 0.012)
    pocket = Box(pp, (0.07, 0.06, 0.016), rr=0.012, R=pM, part=VEST)
    fp_, fM = surface_frame(Inflate(b, 0.022), -0.32, 0.97, 0.01)
    flap = Box(fp_, (0.045, 0.04, 0.013), rr=0.01, R=fM, part=VEST)
    tp = pp + pM[:, 2] * 0.006
    up = pM[:, 1]
    tools = [
        RoundCone(tp + v3((-0.035, 0, 0)), tp + v3((-0.04, 0, 0)) + up * 0.12, 0.007, 0.007, part=TOOL),           # pliers' handles
        RoundCone(tp + v3((-0.022, 0, 0)), tp + v3((-0.015, 0, 0)) + up * 0.12, 0.007, 0.007, part=TOOL),
        Box(tp + v3((-0.027, 0, 0)) + up * 0.128, (0.012, 0.014, 0.006), rr=0.003, R=pM, part=TOOL),
        RoundCone(tp + v3((0.012, 0, 0)), tp + v3((0.016, 0, 0)) + up * 0.105, 0.011, 0.011, part=TOOLRED),     # two screwdrivers
        RoundCone(tp + v3((0.016, 0, 0)) + up * 0.105, tp + v3((0.017, 0, 0)) + up * 0.14, 0.004, 0.003, part=TOOL),
        RoundCone(tp + v3((0.04, 0, 0)), tp + v3((0.045, 0, 0)) + up * 0.095, 0.01, 0.01, part=TOOLRED),
        RoundCone(tp + v3((0.045, 0, 0)) + up * 0.095, tp + v3((0.046, 0, 0)) + up * 0.13, 0.004, 0.003, part=TOOL),
    ]
    vest = Union([shell, pocket, flap], k=0.01, part=VEST)
    # the glasses, pushed up on the forehead between the panels: frames lying on the skin, the arms back over the head into the vest
    gl = []
    lenses = []
    for cx in (0.012, 0.13):
        c, M = surface_frame(b, cx, 1.035, 0.006)
        M = M @ rot(rz=-4.0)
        gl.append(Cut(Box(c, (0.05, 0.032, 0.006), rr=0.004, R=M, part=FRAME), [Box(c, (0.042, 0.024, 0.03), rr=0.004, R=M)]))
        gl.append(Box(c, (0.043, 0.025, 0.0016), rr=0.001, R=M, part=LENS))
        lenses.append((c, M))
    (c0, M0), (c1, M1) = lenses
    gl.append(RoundCone(c0 + M0[:, 0] * 0.048, c1 - M1[:, 0] * 0.048, 0.004, part=FRAME))
    for c, M, s in ((c0, M0, -1.0), (c1, M1, 1.0)):
        end = c + M[:, 0] * s * 0.05
        mid, _ = surface_frame(b, end[0] + s * 0.05, end[2] + 0.02, 0.006)
        gl.append(loft([(end, 0.0035), (mid, 0.0035), (mid + v3((s * 0.02, 0.09, 0.02)), 0.0035)], part=FRAME))
    return Union([vest] + tools + gl, k=0.0)


def boot_piece():
    """the great boot: a tall shaft with a padded cuff, a round toe, a lugged sole, three buckled straps"""
    shaft = CappedCone((0, 0.03, 0.1), (0, 0.02, 0.445), 0.086, 0.08, rr=0.02, part=BOOT)
    toe = Ellipsoid((0, -0.2, 0.082), (0.098, 0.12, 0.072), part=BOOT)
    mid = Ellipsoid((0, -0.06, 0.095), (0.1, 0.15, 0.085), part=BOOT)
    heel = Ellipsoid((0, 0.075, 0.1), (0.09, 0.075, 0.09), part=BOOT)
    up = Union([shaft, toe, mid, heel], k=0.04, part=BOOT)
    up = Cut(up, [RoundCone((0, 0.02, 0.35), (0, 0.02, 0.6), 0.055)], k=0.008)
    cuff = Union([Torus((0, 0.02, 0.45), 0.068, 0.024, part=CUFF), Clip(Inflate(shaft, 0.006, part=CUFF), [Half((0, 0, 0.395), (0, 0, -1))])], k=0.01)
    sole = Box((0, -0.065, 0.032), (0.112, 0.245, 0.033), rr=0.018, part=SOLE)
    lugs = [Box((s * 0.115, yy, 0.022), (0.012, 0.016, 0.018), rr=0.002) for s in (-1, 1) for yy in np.linspace(-0.27, 0.15, 9)]
    sole = Cut(sole, lugs, k=0.002)
    welt = Clip(Inflate(Union([toe, mid, heel], k=0.04), 0.008, part=SOLE), [Half((0, 0, 0.075), (0, 0, 1)), Half((0, 0, 0.06), (0, 0, -1))], k=0.003)
    straps, buckles = [], []
    for z in (0.39, 0.27):
        straps.append(Clip(Inflate(shaft, 0.008, part=STRAP), [Half((0, 0, z + 0.018), (0, 0, 1)), Half((0, 0, z - 0.018), (0, 0, -1))], k=0.003))
        bx = Box((0.09, 0.0, z), (0.008, 0.022, 0.02), rr=0.003, part=BUCKLE)
        buckles.append(Cut(bx, [Box((0.09, 0.0, z), (0.02, 0.013, 0.011))]))
    instep = Clip(Inflate(Union([toe, mid], k=0.04), 0.008, part=STRAP), [Half((0, -0.1, 0.0), (0, -1.0, 0.25)), Half((0, -0.055, 0.0), (0, 1.0, -0.25))], k=0.003)
    instep = Clip(instep, [Half((0, 0, 0.1), (0, 0, -1))])
    buckles.append(Cut(Box((0.08, -0.08, 0.14), (0.008, 0.02, 0.018), rr=0.003, R=rot(ry=-35), part=BUCKLE), [Box((0.08, -0.08, 0.14), (0.02, 0.012, 0.01), R=rot(ry=-35))]))
    return Union([up, cuff, sole, welt, instep] + straps + buckles, k=0.0)


def pieces():
    import os
    out = [("body", body_piece(), 0.0026), ("face", face_piece(), 0.0016), ("vest", vest_piece(), 0.0022), ("boot", boot_piece(), 0.0025)]
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

    # skin: pale peach, flushed pink on the cheeks and lids, the ears' outer halves and the bulb patterned in rose-pink patches; freckled all over
    m = c.mask(SKIN, LIP)
    sk = np.broadcast_to(srgb(238, 188, 164), (n, 3)).copy()
    sk *= (1.0 + 0.05 * mott)[:, None]
    cheek = smooth(0.09, 0.03, np.hypot(Q[:, 0] - (EYE_C[0] + 0.01), z - (EYE_C[2] - 0.065))) * (y < -0.05)
    lidf = smooth(0.1, 0.075, np.hypot((Q[:, 0] - EYE_C[0]) / 1.0, (z - EYE_C[2]) / 0.6)) * (y < -0.05)
    sk = sk + (srgb(222, 140, 128) - sk) * (np.maximum(cheek * 0.65, lidf * 0.35))[:, None]
    # (lead review) a warm flush deepening toward the lobes, the ear-arms and the tail's bulb; a few small darker patches, mostly on the ears
    lobes = np.maximum(smooth(0.98, 1.2, z) * smooth(0.05, 0.25, Q[:, 0]), smooth(0.3, 0.5, Q[:, 0]))
    bulb_f = smooth(1.6, 1.0, np.linalg.norm((P - BULB[0]) / BULB[1], axis=1))
    flush = np.maximum(lobes, bulb_f) * (0.75 + 0.25 * noise3(P + 5.5, 0.03))
    sk = sk + (srgb(228, 150, 132) - sk) * (flush * 0.55)[:, None]
    blot = smooth(0.25, 0.45, noise3(P + 8.1, 0.017) * 0.7 + noise3(P + 2.2, 0.006) * 0.3)
    sk = sk + (srgb(206, 112, 102) - sk) * (blot * (0.12 + 0.28 * lobes))[:, None]
    # the ears' patches: a few small rose-pink shapes over their outer halves (a third the size, half the contrast they were: they read as camo)
    out_ear = smooth(0.3, 0.45, Q[:, 0]) * (z > 0.95)
    cell = noise3(P * v3((1.0, 1.0, 1.0)), 0.02) + 0.35 * noise3(P + 3.0, 0.008)
    patch = smooth(0.12, 0.24, cell) * out_ear
    bulb_d = np.linalg.norm((P - BULB[0] * v3((1, 1, 1))) / BULB[1], axis=1)
    on_bulb = bulb_d < 1.25
    spots = smooth(0.25, 0.15, np.abs(noise3(P, 0.02)))
    sk = sk + (srgb(226, 128, 132) - sk) * (patch * 0.45)[:, None]
    sk = np.where(on_bulb[:, None], (srgb(220, 132, 132) + (srgb(244, 214, 204) - srgb(220, 132, 132)) * spots[:, None]), sk)
    sk = sk + (srgb(200, 140, 120) - sk) * (c.cavity * 0.5)[:, None]
    put(m, sk[m], 0.5, bump=0.35, grain=1.0)
    spk(m, (168, 66, 54), 0.7)
    m = c.mask(LIP)
    put(m, (sk * v3((0.9, 0.78, 0.76)))[m], 0.4, bump=0.2)
    # ink: the lids' edges, the brows' crease
    Rm = eye_frame()
    loc = (Q - v3((EYE_C[0], 0, EYE_C[2]))) @ Rm
    re = np.hypot(loc[:, 0] / 0.07, loc[:, 2] / 0.038)
    sm = c.mask(SKIN) & (y < -0.06) & (np.abs(z - EYE_C[2]) < 0.08)
    c.draw(sm & (re > 1.45) & (re < 1.9) & (loc[:, 2] > 0.02), np.abs(re - 1.65) * 0.035, 0.0006, 0.22)
    put(c.mask(TOOTH), srgb(236, 226, 196), 0.3, bump=0.1)
    m = c.mask(TOOTH)
    c.draw(m & (np.abs(x) < 0.003), np.abs(x), 0.0007, 0.6)
    # eyes: glossy black, a deep plum sheen, two sharp glints
    m = c.mask(EYE)
    put(m, srgb(14, 10, 18), 0.03)
    for gx, gz, r in ((-0.02, 0.016, 0.0075), (0.024, -0.012, 0.004)):
        loc2 = (Q - v3((EYE_C[0] + gx, 0, EYE_C[2] + gz)))
        g = smooth(r, r * 0.6, np.hypot(loc2[:, 0], loc2[:, 2]))
        c.col[m] = (c.col + (srgb(250, 250, 255) - c.col) * g[:, None])[m]

    # the vest: mustard canvas, worn pale at the edges, grimy, top-stitched
    m = c.mask(VEST, STRAP)
    vs = srgb(196, 146, 52) * (1.0 + 0.07 * mott)[:, None]
    vs = vs + (srgb(230, 196, 120) - vs) * (c.wear * 0.5)[:, None]
    vs = vs + (srgb(110, 76, 30) - vs) * (c.cavity * 0.6)[:, None]
    vs = vs + (srgb(120, 90, 50) - vs) * (smooth(0.3, 0.7, noise3(P + 4.0, 0.04)) * 0.35)[:, None]
    put(m, vs[m], 0.85, bump=1.0)
    spk(m, (110, 80, 40), 0.3)
    put(c.mask(TOOL), (srgb(170, 172, 176) * (1.0 - 0.4 * c.cavity)[:, None])[c.mask(TOOL)], 0.3, metal=1.0)
    put(c.mask(TOOLRED), srgb(176, 26, 22), 0.3)
    put(c.mask(FRAME), srgb(16, 14, 14), 0.25)
    m = c.mask(LENS)
    put(m, (srgb(60, 70, 80) + (srgb(200, 210, 220) - srgb(60, 70, 80)) * smooth(0.4, 0.9, noise3(P * v3((1, 1, 3)), 0.02))[:, None])[m], 0.05)
    # the boot: oxblood leather, scuffed pale at the toe and creases, specks of paint; a dark lugged sole with a red welt stitch; worn steel buckles
    m = c.mask(BOOT)
    bt = srgb(122, 48, 52) * (1.0 + 0.08 * mott)[:, None]
    bt = bt + (srgb(170, 110, 100) - bt) * (c.wear * 0.6)[:, None]
    bt *= (1.0 - 0.35 * c.cavity)[:, None]
    put(m, bt[m], 0.45, bump=0.7, grain=1.0)
    spk(m, (210, 160, 90), 0.35)
    m = c.mask(SOLE)
    so = srgb(64, 54, 48) + (srgb(130, 112, 92) - srgb(64, 54, 48)) * (c.wear * 0.6)[:, None]
    put(m, so[m], 0.85, bump=0.8)
    c.draw(m & (np.abs(z - 0.067) < 0.006), np.abs(z - 0.067), 0.0012, 0.7)
    m = c.mask(STRAP)
    put(m, (srgb(150, 140, 126) * (1.0 - 0.35 * c.cavity)[:, None])[m], 0.7, bump=0.8)
    m = c.mask(BUCKLE)
    put(m, (srgb(150, 150, 146) * (1.0 - 0.45 * c.cavity)[:, None])[m], 0.4, metal=1.0, bump=0.3)
    m = c.mask(CUFF)
    put(m, (srgb(220, 206, 184) * (1.0 - 0.35 * c.cavity)[:, None])[m], 0.9, bump=1.0)
    put(c.mask(NAIL), srgb(226, 170, 160), 0.3)

    c.col *= (0.3 + 0.7 * c.ao)[:, None]


# ---------------------------------------------------------------------------------------------------- the game model: budget, rig, motion

GAME = {
    "budget": {"body": 4200, "face": 700, "vest": 1900, "boot": 1600},
    "density": {"face": 1.6, "vest": 1.2},
    "tex": 2048,
    "stride": {"walk": 0.55, "run": 1.0},           # metres one hop carries it
    "speed": 0.8,
    # its face is the front of its whole body (heart, ears and arms in one), so it does not turn to look (no look bones)
    "look": [], "neck": "-",
    "look_pivot": (0.0, 0.0, 0.9),
    "radius": 0.6,
}
TAIL_J = [TAIL[0][0], TAIL[2][0], TAIL[4][0]]


def rig_bones():
    from kit.rig import Bone, mirror
    return mirror([
        Bone("root", (0, 0, 0), (0, 0.15, 0), None, 0.0),
        Bone("body", POINT, (0.0, 0.0, 1.15), "root", 0.3),
        Bone("ear.L", EAR[0][0], EAR[3][0], "body", 0.12),
        Bone("ear_tip.L", EAR[3][0], SH, "ear.L", 0.06),
        Bone("upper_arm.L", SH, EL, "ear_tip.L", 0.03),
        Bone("forearm.L", EL, WR, "upper_arm.L", 0.025),
        Bone("hand.L", WR, WR - HAND[:, 2] * 0.11, "forearm.L", 0.02),
        Bone("leg", POINT, KNEE, "body", 0.04),
        Bone("shin", KNEE, ANKLE, "leg", 0.09),
        Bone("foot", ANKLE, TOE, "shin", 0.08),
        Bone("tail1", TAIL_J[0], TAIL_J[1], "body", 0.02),
        Bone("tail2", TAIL_J[1], TAIL_J[2], "tail1", 0.015),
        Bone("bulb", TAIL_J[2], BULB[0] + v3((0, 0, -0.07)), "tail2", 0.05),
    ])


def _seg(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / float(ab @ ab), 0.0, 1.0)
    return np.linalg.norm(P - a - np.outer(t, ab), axis=1)


def skin_rules(P, part, piece, names):
    """piece: 0 body (heart, ears, arms, stalk, tail), 1 face (eyes, teeth), 2 vest and glasses, 3 boot"""
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
    bp = piece == 0
    tail_d = np.minimum(_seg(P, TAIL_J[0], TAIL_J[1]), _seg(P, TAIL_J[1], TAIL_J[2]))
    bulb = np.linalg.norm((P - BULB[0]) / (BULB[1] + 0.01), axis=1) < 1.0
    tail = bp & ((tail_d < 0.03) | bulb) & (y > 0.1)
    allow(tail, "body", "tail1", "tail2", "bulb")
    rig[tail & bulb] = ix["bulb"]
    stalk = bp & ~tail & (z < 0.6) & (np.abs(x) < 0.08)
    allow(stalk, "body", "leg", "shin")
    arm_d = np.minimum(_seg(Q, SH, EL), np.minimum(_seg(Q, EL, WR), _seg(Q, WR, WR - HAND[:, 2] * 0.13)))
    arms = bp & ~tail & ~stalk & (arm_d < 0.06) & (z < 1.0)
    rest = bp & ~tail & ~stalk & ~arms
    for s, sd in ((1, "L"), (-1, "R")):
        m = arms & (x * s > 0)
        allow(m, "ear_tip." + sd, "upper_arm." + sd, "forearm." + sd, "hand." + sd)
        rig[m & (((Q - WR) @ -HAND[:, 2]) > 0.015)] = ix["hand." + sd]
        e = rest & (x * s > 0.2)
        allow(e, "ear." + sd, "ear_tip." + sd)
    allow(rest, "body")
    rig[rest & (np.abs(x) < 0.2)] = ix["body"]
    # eyes and teeth, vest and glasses ride the body
    rig[(piece == 1) | (piece == 2)] = ix["body"]
    allow((piece == 1) | (piece == 2), "body")
    vp = (piece == 2) & (part == VEST) & (np.abs(x) > 0.15) & (z > 1.0)      # the vest's shoulders ride the ears' roots
    rig[vp] = -1
    for s, sd in ((1, "L"), (-1, "R")):
        allow(vp & (x * s > 0), "ear." + sd)
    # the boot: the shaft on the shin, the foot rigid on the foot, the cuff where the stalk goes in
    kp = piece == 3
    allow(kp, "shin", "foot")
    rig[kp & (z < 0.15) & (y < -0.02)] = ix["foot"]
    return A, rig


WALK = dict(stride=0.55, stance=0.45, hop=0.075, squat=0.045, lean=7.0, tuck=0.02)
RUN = dict(stride=1.0, stance=0.36, hop=0.13, squat=0.06, lean=14.0, tuck=0.05)


def motions(rig):
    """its clips: walk (pogo hops: the boot lands, the heart sinks onto the stalk, springs off, sails forward with its tail swinging down for
    balance and its ears flopping), run (longer, higher bounds, leaning into them), idle (bouncing gently on the boot, tail swaying, a
    curious tilt, one hop on the spot, fidgety hands)"""
    import math
    from mathutils import Vector, Matrix
    from kit.gait import Pose, R, TAU, ease
    ank = Vector(ANKLE.tolist())
    ball = Vector((0.0, -0.17, 0.0))

    def boot(p, fy, lift, pitch):
        wf = R(pitch, 0, 0)
        b = Vector((ball.x, ball.y + fy, lift))
        p.ik["leg"] = (b + wf @ (ank - ball), Vector((0.0, -1.0, 0.0)), "foot", wf)

    def lag(u, at):
        return math.sin(TAU * (u - at))

    def hop(u, g):
        p = Pose()
        S, beta = g["stride"], g["stance"]
        if u < beta:
            s = u / beta
            fy = -S * beta / 2 + S * u
            body_z = -g["squat"] * math.sin(math.pi * s)
            lift = 0.0
            pitch = 22.0 * ease((s - 0.75) / 0.25)                       # the heel peels as it springs off
            lean = g["lean"] * (0.4 + 0.6 * s)
        else:
            t = (u - beta) / (1.0 - beta)
            fy = S * beta / 2 - S * beta * ease(t)
            body_z = g["hop"] * math.sin(math.pi * t)
            lift = max(0.0, g["hop"] * math.sin(math.pi * t) - g["tuck"] * math.sin(math.pi * t) * 0.0)
            pitch = 22.0 * (1.0 - ease(t * 2.0)) - 8.0 * math.sin(math.pi * t)
            lean = g["lean"] * (1.0 - 0.6 * ease(t))
        boot(p, fy, lift, pitch)
        p.offset = Vector((0.0, 0.0, body_z - 0.01))
        p.rot("body", lean, 2.0 * math.sin(TAU * u), 0)
        # ears flop after the bounce, the arms fling up for balance in the air and down on landing
        flop = 9.0 * lag(u, 0.2)
        for sd, s in (("L", 1.0), ("R", -1.0)):
            p.rot("ear." + sd, 0, s * (flop - 2.0), 0)
            p.rot("ear_tip." + sd, 0, s * 6.0 * lag(u, 0.3), 0)
            p.rot("upper_arm." + sd, -6.0 * lag(u, 0.25), s * -10.0 * lag(u, 0.15), 0)
            p.rot("forearm." + sd, -8.0 * lag(u, 0.3), 0, 0)
            p.rot("hand." + sd, 10.0 * lag(u, 0.35), 0, 0)
        # the tail swings down and back to balance the bound, whips up on landing
        # (held up and back by 16 degrees on top, so the bulb stays clear of the boot as it swings forward under the body)
        p.rot("tail1", 16.0 - 12.0 * lag(u, 0.1), 0, 8.0 * lag(u, 0.2))
        p.rot("tail2", 6.0 - 16.0 * lag(u, 0.2), 0, 10.0 * lag(u, 0.3))
        p.rot("bulb", -14.0 * lag(u, 0.3), 0, 0)
        return p
    walk = [hop(i / 32.0, WALK) for i in range(33)]
    run = [hop(i / 24.0, RUN) for i in range(25)]

    idle = []
    for i in range(181):
        t = i / 30.0
        p = Pose()
        # one little hop on the spot at 3.4 s, otherwise a gentle springing on the boot
        h = 0.0
        if 3.2 <= t < 3.95:
            h = math.sin(math.pi * (t - 3.2) / 0.75)
        squat = 0.012 * (0.5 + 0.5 * math.sin(TAU * t / 1.5)) + 0.04 * math.exp(-((t - 3.15) / 0.12) ** 2) + 0.04 * math.exp(-((t - 4.0) / 0.1) ** 2)
        body_z = -squat + 0.06 * h
        boot(p, 0.0, 0.055 * h, 8.0 * h)
        p.offset = Vector((0.0, 0.0, body_z))
        tilt = math.sin(math.pi * min(1.0, max(0.0, (t - 0.6) / 2.2)))
        p.world["body"] = R(2.0 + 6.0 * h, 10.0 * tilt, 6.0 * tilt + 3.0 * math.sin(TAU * t / 6.0))
        for sd, s in (("L", 1.0), ("R", -1.0)):
            p.rot("ear." + sd, 0, s * (3.0 * math.sin(TAU * t / 2.0 + s) + 6.0 * h), 0)
            p.rot("ear_tip." + sd, 0, s * 3.0 * math.sin(TAU * t / 1.5 + s), 0)
            fid = math.sin(TAU * t * 1.3 + s) * ease((t - 4.4) / 0.2) * (1.0 - ease((t - 5.6) / 0.2))
            p.rot("upper_arm." + sd, 2.0 * math.sin(TAU * t / 3.0 + s) - 10.0 * h, 0, 0)
            p.rot("forearm." + sd, -6.0 * fid, 0, 0)
            p.rot("hand." + sd, 12.0 * fid, 0, 0)
        p.rot("tail1", 6.0 * math.sin(TAU * t / 3.0), 0, 8.0 * math.sin(TAU * t / 6.0))
        p.rot("tail2", 8.0 * math.sin(TAU * (t - 0.3) / 3.0) - 20.0 * h, 0, 10.0 * math.sin(TAU * (t - 0.5) / 6.0))
        p.rot("bulb", 8.0 * math.sin(TAU * (t - 0.6) / 3.0), 0, 0)
        idle.append(p)
    return {"walk": walk, "run": run, "idle": idle}
