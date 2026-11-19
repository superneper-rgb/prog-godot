# Builds the Tethered (assets/underfoint/tethered.glb): the Sigil's deep guards in UNDERFOINT, a body rebuilt round a steel frame and wired by three cables to the wall of the throne.
# Rigid parts on joints, like the Taken, and made with the Taken's tools (tools/taken/build_taken.py: Geo, part, joint, export, preview). enemies/tethered_view.gd poses it.
# The three cables are 10 lengths each (joints cableA_0..9, B, C): every length is a ribbed tube one metre long up its joint's +y, and the view lays them end to end from his back to the wall.
#   Headless only: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/tethered/build_tethered.py -- --build [--preview <folder>]
# Game space: metres, y up, the figure faces +z, its left is +x.
import bpy, math, random, sys, os

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "taken"))
import build_taken as T
from build_taken import Geo, part, joint, lin, strip, TAU

OUT = "F:/prog-godot/assets/underfoint/tethered.glb"
SKIN = lin("9c9a8c")       # greyer than the Taken: nothing has fed this for a long time
SKIN_M = T.SKIN_M
BONE = T.BONE
STEEL = lin("3d3a3a")      # the frame
RUST = lin("5a3a26")
EDGE = lin("b9bcc2")       # a blade's ground edge
RUBBER = T.RUBBER
DARK = T.DARK
SEGS = 10


def strut(g, pts, radii, sides, col, caps=True):
    """a tube through `pts` (any direction), a radius at each"""
    from mathutils import Vector
    vs = []
    n = len(pts)
    for i in range(n):
        p = Vector(pts[i])
        d = (Vector(pts[min(n - 1, i + 1)]) - Vector(pts[max(0, i - 1)])).normalized()
        up = Vector((0, 1, 0)) if abs(d.y) < 0.9 else Vector((1, 0, 0))
        a = d.cross(up).normalized()
        b = d.cross(a).normalized()
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        for k in range(sides):
            t = TAU * k / sides
            q = p + a * (math.cos(t) * r) + b * (math.sin(t) * r)
            vs.append((q.x, q.y, q.z))
    fs = []
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            fs.append([i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k])
    if caps:
        fs.append(list(range(sides)))
        fs.append(list(range((n - 1) * sides, n * sides)))
    return g.add(vs, fs, col)


def blade(g, root, tip, w, col, curl=0.12, n=6):
    """a scythe finger from root to tip: w wide at the root, thin, curling forward (+z) and ground to a point"""
    from mathutils import Vector
    r = Vector(root)
    t = Vector(tip)
    d = t - r
    side = d.cross(Vector((0, 0, 1))).normalized()
    if side.length < 0.5:
        side = Vector((1, 0, 0))
    vs = []
    for i in range(n + 1):
        f = i / n
        c = r + d * f + Vector((0, 0, 1)) * (curl * math.sin(f * math.pi * 0.5) ** 2 * d.length)
        ww = w * (1.0 - f) ** 0.7 + 0.002
        th = 0.007 * (1.0 - f) + 0.001
        for sx, sz in ((-1, 0), (0, -1), (1, 0), (0, 1)):
            q = c + side * (sx * ww) + Vector((0, 0, 1)) * (sz * th)
            vs.append((q.x, q.y, q.z))
    fs = []
    for i in range(n):
        for k in range(4):
            k2 = (k + 1) % 4
            fs.append([i * 4 + k, i * 4 + k2, (i + 1) * 4 + k2, (i + 1) * 4 + k])
    fs.append([0, 1, 2, 3])
    rg = g.add(vs, fs, col)
    for i in range(n + 1):      # the cutting edge (the +x side of each ring) is bright
        g.c[rg[0] + i * 4 + 2] = EDGE
    return rg


def build():
    T.MAT_DEF["cable"] = (0.35, 0.0, None)
    joint("pelvis", (0, 1.25, 0))
    joint("spine", (0, 1.4, 0), "pelvis")
    joint("chest", (0, 1.7, 0), "spine")
    joint("neck", (0, 2.14, 0.04), "chest")
    joint("head", (0, 2.24, 0.07), "neck")
    joint("jaw", (0, 2.25, 0.09), "head")
    for s, t in ((1, "L"), (-1, "R")):
        joint("upper_arm" + t, (s * 0.44, 2.04, 0), "chest")
        joint("forearm" + t, (s * 0.5, 1.46, 0), "upper_arm" + t)
        joint("hand" + t, (s * 0.54, 0.86, 0.05), "forearm" + t)
        joint("thigh" + t, (s * 0.2, 1.2, 0), "pelvis")
        joint("shin" + t, (s * 0.25, 0.74, 0.17), "thigh" + t)
        joint("foot" + t, (s * 0.25, 0.3, -0.12), "shin" + t)
    for c in "ABC":
        for i in range(SEGS):
            joint("cable%s_%d" % (c, i), (0, 0, 0))
    _trunk()
    _head()
    for s, t in ((1, "L"), (-1, "R")):
        _arm(s, t)
        _leg(s, t)
    _cables()
    return {"parts": len(T.PARTS), "joints": len(T.J), "tris": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in T.PARTS)}


def _trunk():
    # hips: a steel cradle bolted through what was a pelvis
    g = Geo()
    g.loft([((0, 1.1, 0), 0.07, 0.07), ((0, 1.17, 0), 0.17, 0.12), ((0, 1.26, 0), 0.2, 0.135), ((0, 1.34, -0.01), 0.11, 0.09)], 12, [c * 0.55 for c in SKIN])
    part("pelvis", SKIN_M, g, 0.012)
    g = Geo()
    rr = random.Random(17)
    for k in range(9):
        a = TAU * (k + rr.random() * 0.6) / 9
        out = (math.cos(a), math.sin(a))
        strip(g, (out[0] * 0.24, 1.2, out[1] * 0.16), out, 0.06 + rr.random() * 0.05, 0.12 + rr.random() ** 2 * 0.4, T.CLOTH_B if rr.random() < 0.7 else T.CLOTH_A)
    part("pelvis", "cloth", g, 0.004)
    g = Geo()
    g.arc((0, 1.22, 0), 0.235, 0.155, 0.0, TAU, 0.022, 0.035, STEEL, 14)
    for s in (1, -1):
        g.box((s * 0.25, 1.2, 0), 0.03, 0.075, 0.07, STEEL)
        g.loft([((s * 0.285, 1.2, 0), 0.03, 0.03), ((s * 0.3, 1.2, 0), 0.02, 0.02)], 6, RUST, axis="z")
    g.box((0, 1.1, -0.12), 0.07, 0.07, 0.035, RUST)
    part("pelvis", "metal", g, smooth=False)
    # the waist: nothing left but the spine, two rams, and the hoses that feed what is above
    g = Geo()
    for i in range(6):
        g.ball((0, 1.36 + i * 0.058, -0.03), 0.04, BONE, 7, 4, (1.25, 0.7, 1.0))
    part("spine", "bone", g, 0.002)
    g = Geo()
    for s in (1, -1):
        strut(g, [(s * 0.15, 1.3, -0.02), (s * 0.19, 1.68, -0.02)], 0.022, 6, STEEL)
        strut(g, [(s * 0.15, 1.3, -0.02), (s * 0.17, 1.5, -0.02)], 0.032, 7, RUST)
    part("spine", "metal", g, smooth=False)
    g = Geo()
    rr = random.Random(3)
    for k in range(5):
        x = (k - 2) * 0.045
        strut(g, [(x, 1.32, 0.07), (x * 1.6 + rr.uniform(-0.02, 0.02), 1.48, 0.1 + rr.random() * 0.04), (x * 1.3, 1.66, 0.12)], 0.014 + rr.random() * 0.006, 5, RUBBER)
    part("spine", "cable", g, shade=False)
    g = Geo()      # what is left of the belly: a web of sinew strung between the ribs and the cradle
    g.loft([((0, 1.33, -0.01), 0.1, 0.07), ((0, 1.45, 0.0), 0.062, 0.05), ((0, 1.56, 0.0), 0.075, 0.06), ((0, 1.66, 0.0), 0.2, 0.14)], 10, SKIN, caps=(False, False))
    part("spine", SKIN_M, g, 0.012)

    # the chest: no skin left on it below the collar. A cage of his own ribs round a dark hollow, the frame's hoops bolted through them, and the light where the heart was
    g = Geo()
    g.loft([((0, 1.6, -0.02), 0.1, 0.08), ((0, 1.75, -0.03), 0.2, 0.13), ((0, 1.9, -0.04), 0.24, 0.14), ((0, 2.02, -0.03), 0.22, 0.13)], 12, [c * 0.5 for c in T.WOUND], caps=(False, False))
    part("chest", SKIN_M, g, 0.012, shade=False)
    g = Geo()      # the yoke of the shoulders, the one place he is still whole
    g.loft([((0, 1.98, -0.01), 0.37, 0.24), ((0, 2.06, -0.01), 0.34, 0.22), ((0, 2.12, -0.01), 0.2, 0.15), ((0, 2.16, 0.02), 0.09, 0.09)], 16, SKIN, caps=(False, True))
    for sd in (1, -1):
        g.ball((sd * 0.43, 2.04, 0.0), 0.095, SKIN, 8, 5)
    g.ball((0, 2.08, -0.16), 0.11, SKIN, 8, 4)      # the hump the rack is bolted through
    part("chest", SKIN_M, g, 0.012)
    g = Geo()
    for i in range(7):
        y = 1.66 + i * 0.052
        k = math.sin((i + 0.6) / 7.2 * math.pi)
        ra = 0.2 + 0.17 * k
        rb = 0.15 + 0.115 * k
        g.arc((0, y, 0.0), ra, rb, math.radians(-75), math.radians(74 - i * 2), 0.024, 0.013, BONE, 9)
        g.arc((0, y, 0.0), ra, rb, math.radians(106 + i * 2), math.radians(255), 0.024, 0.013, BONE, 9)
    part("chest", "bone", g, 0.003)
    g = Geo()
    for i, y in enumerate((1.74, 1.9, 2.03)):
        g.arc((0, y, 0.0), (0.33, 0.395, 0.375)[i], (0.24, 0.285, 0.245)[i], math.radians(112), math.radians(428), 0.02, 0.016, STEEL, 16)
    for s in (1, -1):
        g.box((s * 0.075, 1.88, 0.275), 0.012, 0.17, 0.014, STEEL)       # the two bars the sternum was spread on
        for y in (1.75, 1.88, 2.01):
            g.box((s * 0.075, y, 0.292), 0.02, 0.02, 0.01, RUST)
        g.box((s * 0.45, 2.135, 0.0), 0.085, 0.012, 0.075, STEEL)       # a plate riveted down over each shoulder
        for bz in (-0.05, 0.05):
            g.box((s * 0.48, 2.15, bz), 0.014, 0.01, 0.014, RUST)
    # the rack on his back: three sockets the cables lock into
    g.box((0, 1.92, -0.28), 0.25, 0.19, 0.035, STEEL, 0.8)
    g.box((0, 1.6, -0.2), 0.03, 0.16, 0.03, STEEL)
    for (px, py) in ((0.0, 2.02), (0.18, 1.82), (-0.18, 1.82)):
        g.loft([((px, py, -0.33), 0.07, 0.07), ((px, py, -0.4), 0.07, 0.07), ((px, py, -0.42), 0.05, 0.05)], 9, RUST, axis="z")
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box((sx * 0.225, 1.92 + sy * 0.165, -0.345), 0.018, 0.018, 0.012, RUST)
    part("chest", "metal", g, smooth=False)
    g = Geo()
    g.ball((0, 1.86, 0.04), 0.085, DARK, 9, 6, (1.0, 1.25, 0.8))      # the light in the hollow
    for (px, py) in ((0.0, 2.02), (0.18, 1.82), (-0.18, 1.82)):
        g.arc((px, py, -0.36), 0.071, 0.071, 0.0, TAU, 0.006, 0.01, DARK, 10)      # (level rings: they band each socket from above)
    part("chest", "sigilGlow", g, shade=False)
    g = Geo()      # a butcher's apron of his own coat, hanging off the lowest hoop
    rr = random.Random(11)
    for k in range(11):
        a = math.radians(20 + k * 14 + rr.random() * 6)
        out = (math.cos(a), math.sin(a))
        strip(g, (out[0] * 0.34, 1.73, out[1] * 0.25), out, 0.07 + rr.random() * 0.05, 0.2 + rr.random() ** 2 * 0.55, T.CLOTH_A if rr.random() < 0.6 else T.CLOTH_B)
    part("chest", "cloth", g, 0.004)
    # the neck: hoses, and the bones showing between them
    g = Geo()
    g.loft([((0, 2.1, 0.02), 0.07, 0.07), ((0, 2.18, 0.045), 0.05, 0.055), ((0, 2.26, 0.07), 0.052, 0.06)], 9, SKIN)
    part("neck", SKIN_M, g, 0.006)
    g = Geo()
    for s in (1, -1):
        strut(g, [(s * 0.1, 2.09, -0.06), (s * 0.085, 2.2, -0.02), (s * 0.07, 2.3, -0.01)], 0.02, 6, RUBBER)
        strut(g, [(s * 0.05, 2.1, 0.11), (s * 0.05, 2.2, 0.13)], 0.012, 5, RUBBER)
    part("neck", "cable", g, shade=False)


def _head():
    """A long skull under skin drawn tight, tipped forward. No eyes: a steel band is bolted across where they were, one lens in it. The top of the skull is off, and the hoses go in."""
    def face(p, n, col):
        if p.z > 0.12 and 2.27 < p.y < 2.33:      # under the band
            col = [c * 0.45 for c in col]
        d = math.hypot(p.x, p.y - 2.305)
        if p.z > 0.2 and d < 0.03:                # the pit of the nose
            col = [c * (0.2 + 0.8 * d / 0.03) for c in col]
        if abs(p.x) > 0.07 and 2.24 < p.y < 2.31 and p.z > 0.08:      # cheeks sucked in
            col = [c * 0.65 for c in col]
        return col
    g = Geo()
    g.loft([((0, 2.225, 0.11), 0.05, 0.075), ((0, 2.27, 0.125), 0.068, 0.105), ((0, 2.31, 0.125), 0.098, 0.122), ((0, 2.37, 0.11), 0.105, 0.137), ((0, 2.46, 0.08), 0.118, 0.15), ((0, 2.55, 0.05), 0.105, 0.135), ((0, 2.6, 0.04), 0.085, 0.11)], 14, SKIN, caps=(True, False))
    for sd in (1, -1):
        g.ball((sd * 0.082, 2.305, 0.185), 0.03, SKIN, 6, 4)      # cheekbones
    part("head", SKIN_M, g, 0.006, paint=face)
    g = Geo()      # the open top: a dark well with a rim of bone
    g.loft([((0, 2.6, 0.04), 0.087, 0.112), ((0, 2.615, 0.04), 0.08, 0.104), ((0, 2.6, 0.04), 0.07, 0.092)], 12, BONE, caps=(False, False))
    for i in range(8):      # upper teeth: long, filed
        x = (i - 3.5) * 0.019
        g.box((x, 2.218, 0.205 - abs(x) * 0.5), 0.0075, 0.026, 0.006, BONE, 0.3)
    part("head", "bone", g, smooth=False)
    g = Geo()
    g.loft([((0, 2.6, 0.04), 0.07, 0.092), ((0, 2.5, 0.04), 0.03, 0.04)], 12, DARK, caps=(False, True))
    rr = random.Random(8)
    for k in range(6):      # the hoses into the skull, over the back of the head and down to the neck
        a = TAU * k / 6
        x = math.cos(a) * 0.04
        z = 0.04 + math.sin(a) * 0.055
        strut(g, [(x, 2.56, z), (x * 1.4, 2.66 + rr.random() * 0.05, z - 0.03), (x * 2.2, 2.6, -0.1 - rr.random() * 0.04), (x * 2.0, 2.4, -0.12), (x * 1.6, 2.26, -0.06)], 0.014, 5, RUBBER)
    part("head", "cable", g, shade=False)
    g = Geo()
    g.arc((0, 2.37, 0.11), 0.105, 0.137, math.radians(-25), math.radians(205), 0.014, 0.034, STEEL, 12)      # the band
    for a in (20, 60, 120, 160):
        r = math.radians(a)
        g.box((math.cos(r) * 0.123, 2.37, 0.11 + math.sin(r) * 0.156), 0.011, 0.011, 0.011, RUST)
    g.loft([((0.045, 2.37, 0.25), 0.036, 0.036), ((0.045, 2.37, 0.285), 0.032, 0.032)], 9, STEEL, axis="z", caps=(False, False))      # the lens housing, off centre
    g.box((-0.11, 2.47, 0.06), 0.012, 0.05, 0.06, STEEL)
    part("head", "metal", g, smooth=False)
    g = Geo()
    g.loft([((0.045, 2.37, 0.268), 0.03, 0.03), ((0.045, 2.37, 0.276), 0.02, 0.02)], 9, DARK, axis="z", caps=(False, True))
    part("head", "sigilGlow", g, shade=False)
    # the jaw: longer than a jaw should be, hinged on steel, steel teeth in it
    g = Geo()
    g.arc((0, 2.19, 0.09), 0.062, 0.115, math.radians(-12), math.radians(192), 0.018, 0.02, SKIN, 9)
    g.box((0, 2.175, 0.212), 0.03, 0.018, 0.016, SKIN)
    part("jaw", SKIN_M, g, 0.003)
    g = Geo()
    for i in range(7):
        x = (i - 3) * 0.02
        g.box((x, 2.215, 0.2 - abs(x) * 0.5), 0.0065, 0.022, 0.0055, EDGE, 0.25)
    for s in (1, -1):
        g.loft([((s * 0.085, 2.2, 0.08), 0.022, 0.022), ((s * 0.1, 2.2, 0.08), 0.015, 0.015)], 6, RUST, axis="z")
    part("jaw", "metal", g, smooth=False)


def _arm(s, t):
    """Arms a third too long. The upper arm is his own, a ram riveted along it; below the elbow there is no hand, only the three scythes the frame ends in."""
    g = Geo()
    g.loft([((s * 0.44, 2.05, 0), 0.075, 0.075), ((s * 0.46, 1.85, 0), 0.06, 0.064), ((s * 0.485, 1.62, 0), 0.045, 0.048), ((s * 0.5, 1.47, 0), 0.04, 0.042)], 9, SKIN)
    part("upper_arm" + t, SKIN_M, g, 0.007)
    g = Geo()
    strut(g, [(s * 0.5, 1.98, -0.07), (s * 0.535, 1.5, -0.05)], 0.018, 6, STEEL)
    strut(g, [(s * 0.5, 1.98, -0.07), (s * 0.52, 1.72, -0.06)], 0.03, 7, RUST)
    g.ball((s * 0.5, 1.46, 0), 0.066, STEEL, 8, 5)      # the elbow
    g.loft([((s * 0.5, 1.46, 0.055), 0.035, 0.035), ((s * 0.5, 1.46, 0.075), 0.022, 0.022)], 7, RUST, axis="z")
    part("upper_arm" + t, "metal", g, smooth=False)
    g = Geo()
    g.loft([((s * 0.5, 1.45, 0), 0.042, 0.044), ((s * 0.51, 1.3, 0.01), 0.05, 0.054), ((s * 0.525, 1.08, 0.03), 0.036, 0.038), ((s * 0.535, 0.95, 0.045), 0.03, 0.03)], 9, SKIN)
    part("forearm" + t, SKIN_M, g, 0.007)
    g = Geo()
    for dz in (-0.045, 0.05):
        strut(g, [(s * 0.5, 1.44, dz), (s * 0.525, 1.14, 0.03 + dz * 0.8), (s * 0.54, 0.88, 0.05 + dz * 0.5)], 0.013, 5, STEEL)
    g.arc((s * 0.527, 1.02, 0.037), 0.04, 0.042, 0.0, TAU, 0.012, 0.018, RUST, 8)      # the cuff where flesh stops
    g.arc((s * 0.512, 1.26, 0.012), 0.052, 0.056, 0.0, TAU, 0.01, 0.014, STEEL, 8)
    part("forearm" + t, "metal", g, smooth=False)
    g = Geo()
    g.box((s * 0.54, 0.86, 0.05), 0.045, 0.05, 0.035, STEEL, 0.8)      # the knuckle block
    for k, dx in enumerate((-0.036, 0.0, 0.036)):
        ln = (0.5, 0.62, 0.54)[k]
        blade(g, (s * 0.54 + dx, 0.83, 0.05), (s * 0.54 + dx * 2.2, 0.83 - ln, 0.07), 0.02, STEEL, 0.22)
    blade(g, (s * 0.54 - s * 0.045, 0.87, 0.07), (s * 0.54 - s * 0.16, 0.62, 0.2), 0.016, STEEL, 0.1)      # the thumb
    part("hand" + t, "metal", g, smooth=False, shade=False)


def _leg(s, t):
    """Legs: the thigh is his; below the knee it is all frame, a strut back to a hock and a strut down to three steel toes, so he stands like a dog"""
    g = Geo()
    g.loft([((s * 0.2, 1.24, 0), 0.1, 0.1), ((s * 0.215, 1.05, 0.06), 0.085, 0.09), ((s * 0.24, 0.85, 0.14), 0.06, 0.064), ((s * 0.25, 0.75, 0.17), 0.05, 0.052)], 10, SKIN)
    rr = random.Random(31 + s)
    for k in range(4):
        a = TAU * k / 4 + 0.3
        out = (math.cos(a), math.sin(a))
        strip(g, (s * 0.21 + out[0] * 0.09, 1.12, 0.04 + out[1] * 0.09), out, 0.07, 0.12 + rr.random() * 0.2, T.CLOTH_B)
    part("thigh" + t, SKIN_M, g, 0.008)
    g = Geo()
    g.ball((s * 0.25, 0.74, 0.17), 0.075, STEEL, 8, 5)      # the knee
    g.loft([((s * 0.25, 0.74, 0.235), 0.04, 0.04), ((s * 0.25, 0.74, 0.255), 0.025, 0.025)], 7, RUST, axis="z")
    strut(g, [(s * 0.2, 1.14, -0.09), (s * 0.25, 0.8, 0.1)], 0.02, 6, STEEL)
    part("thigh" + t, "metal", g, smooth=False)
    g = Geo()
    for dx in (-0.035, 0.035):
        strut(g, [(s * 0.25 + dx, 0.74, 0.17), (s * 0.25 + dx, 0.3, -0.12)], 0.018, 6, STEEL)
    strut(g, [(s * 0.25, 0.66, 0.16), (s * 0.25, 0.44, 0.02)], 0.034, 7, RUST)      # the ram between them
    strut(g, [(s * 0.25, 0.44, 0.02), (s * 0.25, 0.32, -0.08)], 0.016, 6, EDGE)
    g.ball((s * 0.25, 0.3, -0.12), 0.06, STEEL, 8, 4)      # the hock
    part("shin" + t, "metal", g, smooth=False)
    g = Geo()
    strut(g, [(s * 0.25, 0.3, -0.12), (s * 0.25, 0.07, 0.04)], [0.03, 0.04], 7, STEEL)
    g.box((s * 0.25, 0.045, 0.05), 0.06, 0.04, 0.06, RUST, 0.8)
    for dx in (-0.055, 0.0, 0.055):
        blade(g, (s * 0.25 + dx, 0.05, 0.09), (s * 0.25 + dx * 2.0, 0.012, 0.3), 0.02, STEEL, -0.1, 4)
    blade(g, (s * 0.25, 0.06, 0.0), (s * 0.25, 0.015, -0.14), 0.018, STEEL, 0.0, 3)      # the spur
    part("foot" + t, "metal", g, smooth=False)


def _cables():
    """One length of cable, thirty times: a ribbed tube from its joint up +y for a metre, a band of light round the near end"""
    for c in "ABC":
        for i in range(SEGS):
            g = Geo()
            n = 10
            strut(g, [(0, k / n, 0) for k in range(n + 1)], [0.044 if k % 2 else 0.036 for k in range(n + 1)], 7, RUBBER, caps=False)
            part("cable%s_%d" % (c, i), "cable", g, shade=False)
            g = Geo()
            strut(g, [(0, 0.0, 0), (0, 0.025, 0)], 0.05, 7, DARK, caps=False)
            part("cable%s_%d" % (c, i), "sigilGlow", g, shade=False)


if "--build" in sys.argv:
    T.SCENE = bpy.context.scene.name
    for o in list(bpy.context.scene.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    print("tethered:", build())
    if "--preview" in sys.argv:
        d = sys.argv[sys.argv.index("--preview") + 1]
        cab = [T.J[k][0] for k in T.J if k.startswith("cable")]      # (the cable lengths all lie at the origin in the file: shrunk to nothing for the picture)
        for e in cab:
            e.scale = (0, 0, 0)
        for nm, view in (("front", (1.9, 1.9, 4.2)), ("back", (-2.2, 2.2, -3.8)), ("side", (4.4, 1.6, 0.6))):
            T.preview(os.path.join(d, "tethered_%s.png" % nm), "x", view, (0.0, 1.4, 0.0), (720, 960))
        for e in cab:
            e.scale = (1, 1, 1)
        for nm in ("TakenCam", "TakenKey", "TakenRim", "TakenFill"):
            o = bpy.data.objects.get(nm)
            if o is not None:
                bpy.data.objects.remove(o, do_unlink=True)
    print("wrote", T.export(OUT))
