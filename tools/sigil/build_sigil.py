# Builds the Sigil's chase body (assets/underfoint/sigil/sigil.glb): the SERN machine the Sigil took over, long and low on ten blade legs, its small 90s CRT head carried out on a raised neck,
# two mantis scythes, six weak-point screens built into recessed housings, armour plates that tear off. Silhouette "A Strider", picked by the user on 2026-11-15 from three blockouts.
# One skinned mesh (rigid parts on their bones, cables and bellows blended), three materials: the baked body atlas, the weak-point glass, the CRT glass. enemies/sigil_beast_view.gd drives it.
#   Headless only: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/sigil/build_sigil.py -- [--preview DIR] [--bake] [--export]
#   --bake re-bakes the texture atlas into F:/prog-godot-cache/sigil/tex (slow); without it the cached maps are used.
# Blender space here: metres, Z up, the beast faces +Y, its own left is -X. glTF turns that into Y up facing -Z; the view turns the model round so it faces +Z.
import bpy, bmesh, math, os, sys, random
from mathutils import Vector as V, Matrix, Euler, Quaternion

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def opt(name, default=None):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default

ROOT = "F:/prog-godot"
OUT_GLB = ROOT + "/assets/underfoint/sigil/sigil.glb"
CACHE = "F:/prog-godot-cache/sigil"
TEX_DIR = CACHE + "/tex"
TEX = 4096
random.seed(7)

KINDS = ["enamel", "enamel_dark", "steel", "edge", "rubber", "copper", "housing", "crt_plastic", "paint_black", "paint_red", "glass", "crt"]
BAKED = KINDS[:10]       # what goes into the body atlas; glass and crt keep their own materials

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# the rig's layout: everything below is placed from these
SEG = [  # y, z, width, height, length, pitch: the five body segments, chest first
    (4.4, 5.9, 3.0, 2.6, 3.0, 0.16),
    (1.0, 5.4, 3.6, 2.7, 3.1, 0.07),
    (-2.5, 4.9, 3.5, 2.5, 3.1, 0.0),
    (-6.0, 4.4, 3.1, 2.3, 2.9, -0.05),
    (-9.3, 3.9, 2.5, 2.0, 2.7, -0.1),
]
SPAN = [5.9, 6.4, 6.5, 6.2, 5.6]
NECK = [V(p) for p in [(0, 6.0, 6.7), (0, 7.1, 8.3), (0, 8.4, 9.5), (0, 9.9, 10.0), (0, 11.3, 9.7), (0, 12.4, 9.0)]]
HEAD_DIR = V((0, 1.3, -0.65)).normalized()
TAIL = [V(p) for p in [(0, -10.6, 3.7), (0, -12.6, 2.9), (0, -14.6, 2.0), (0, -16.4, 1.2)]]
SIDES = (("L", -1.0), ("R", 1.0))      # the beast's own left is -X


def seg_frame(k):
    y, z, w, h, L, p = SEG[k]
    return V((0, y, z)), Matrix.Rotation(p, 3, 'X')


def seg_dir(k):
    return seg_frame(k)[1] @ V((0, 1, 0))


def hip(k, s):
    c, R = seg_frame(k)
    return c + R @ V((s * (SEG[k][2] * 0.5 + 0.1), 0.1, -0.35))


def knee(k, s):
    y, z = SEG[k][0], SEG[k][1]
    return V((s * SPAN[k] * 0.68, y + 0.6 + (2 - k) * 0.45, z + 2.6 - 0.2 * k))


def foot(k, s):
    """(splayed like a spider's: the front feet reach forward, the back ones back)"""
    return V((s * SPAN[k], SEG[k][0] + 0.3 + (2 - k) * 1.0, 0.0))


def shoulder(s):
    return V((s * 1.6, 5.3, 6.9))


ELBOW = lambda s: V((s * 2.6, 6.6, 9.3))
WRIST = lambda s: V((s * 2.4, 9.3, 7.5))
BLADE_TIP = lambda s: V((s * 2.1, 11.6, 3.6))

# the weak points: [centre, outward normal, size, bone]. Index meaning kept from the old body (levels/underfoint/uf_chase.gd arms 0..1 head-on, 0..3 from the side, 1..5 from behind):
# 0 throat, 1 chest, 2/3 the chest's lower flanks (left, right), 4/5 the second segment's belly (left, right). It turns to face you and rears to strike, so its belly and chest are what you see.
_n1 = (NECK[2] - NECK[1]).normalized()
_throat_n = V((0, _n1.z, -_n1.y))
POINTS = [
    ((NECK[1] + NECK[2]) * 0.5 + _throat_n * 0.62, _throat_n, (0.95, 0.72), "neck_1"),
    (V((0, 6.0, 5.3)), V((0, 0.8, -0.6)).normalized(), (1.25, 0.95), "body_0"),
    (V((-1.42, 4.8, 5.0)), V((-0.72, 0.5, -0.48)).normalized(), (1.1, 0.85), "body_0"),
    (V((1.42, 4.8, 5.0)), V((0.72, 0.5, -0.48)).normalized(), (1.1, 0.85), "body_0"),
    (V((-0.85, 2.3, 4.15)), V((-0.3, 0.62, -0.72)).normalized(), (1.1, 0.85), "body_1"),
    (V((0.85, 2.3, 4.15)), V((0.3, 0.62, -0.72)).normalized(), (1.1, 0.85), "body_1"),
]
PLATES = ["plate_b0", "plate_b1", "plate_b2", "plate_b3", "plate_b4", "plate_sh_L", "plate_sh_R"]


def bones():
    """name -> (head, tail, parent)"""
    b = {"root": (V((0, 0, 0)), V((0, 1.5, 0)), None)}
    par = {0: "body_1", 1: "body_2", 2: "root", 3: "body_2", 4: "body_3"}
    for k in range(5):
        c, R = seg_frame(k)
        d = seg_dir(k) * SEG[k][4] * 0.5
        b["body_%d" % k] = (c - d, c + d, par[k])
        b["plate_b%d" % k] = (c + R @ V((0, -0.4, SEG[k][3] * 0.5)), c + R @ V((0, 0.4, SEG[k][3] * 0.5)), "body_%d" % k)
    for i in range(5):
        b["neck_%d" % i] = (NECK[i], NECK[i + 1], "body_0" if i == 0 else "neck_%d" % (i - 1))
    b["head"] = (NECK[5], NECK[5] + HEAD_DIR * 1.3, "neck_4")
    hx = head_frame()
    b["shell_t"] = (hx @ V((0, 0.05, 0.62)), hx @ V((0, 0.85, 0.62)), "head")
    for sn, s in SIDES:
        b["shell_" + sn] = (hx @ V((s * 0.74, 0.15, 0.0)), hx @ V((s * 0.74, 0.95, 0.0)), "head")
        b["plate_sh_" + sn] = (V((s * 1.45, 4.2, 6.6)), V((s * 1.45, 5.0, 6.6)), "body_0")
    for i in range(3):
        b["tail_%d" % i] = (TAIL[i], TAIL[i + 1], "body_4" if i == 0 else "tail_%d" % (i - 1))
    for k in range(5):
        for sn, s in SIDES:
            b["leg_%d_%s_0" % (k, sn)] = (hip(k, s), knee(k, s), "body_%d" % k)
            b["leg_%d_%s_1" % (k, sn)] = (knee(k, s), foot(k, s), "leg_%d_%s_0" % (k, sn))
    for sn, s in SIDES:
        b["arm_%s_0" % sn] = (shoulder(s), ELBOW(s), "body_0")
        b["arm_%s_1" % sn] = (ELBOW(s), WRIST(s), "arm_%s_0" % sn)
        b["arm_%s_2" % sn] = (WRIST(s), BLADE_TIP(s), "arm_%s_1" % sn)
    return b


def head_frame():
    """the head's frame: origin at the head bone's root, Y along the head (the screen's normal), Z its up"""
    y = HEAD_DIR
    x = y.cross(V((0, 0, 1))).normalized()
    z = x.cross(y)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = NECK[5]
    return m

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# the mesh builder: one list of vertices (each with its bone weights) and faces (each with its kind, its hard-edge angle and bevel factor, glass id and loop UVs)

class Mesh:
    v = []
    w = []
    f = []        # (indices, kind, ang, bw, gid, uvs)


def W(spec, p):
    if isinstance(spec, str):
        return {spec: 1.0}
    if isinstance(spec, dict):
        return spec
    return spec(p)


def addv(p, wt):
    Mesh.v.append(V(p))
    Mesh.w.append(W(wt, V(p)))
    return len(Mesh.v) - 1


def addf(idx, kind, ang=30.0, bw=1.0, gid=0, uvs=None):
    Mesh.f.append((tuple(idx), kind, ang, bw, gid, uvs))


def basis(fwd, up=V((0, 0, 1))):
    """a 3x3 whose Y is fwd and whose Z is as near `up` as it can be"""
    y = V(fwd).normalized()
    x = y.cross(V(up))
    if x.length < 1e-5:
        x = y.cross(V((1, 0, 0)))
    x.normalize()
    z = x.cross(y)
    return Matrix((x, y, z)).transposed()


def box(c, size, R=None, kind="enamel", wt="root", ang=30.0, bw=1.0, taper=(1.0, 1.0)):
    """a box centred on c, size (x, y, z) in R's frame; taper scales x, z at its +y end"""
    R = R or Matrix.Identity(3)
    sx, sy, sz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    idx = []
    for yy in (-1, 1):
        tx, tz = (taper if yy > 0 else (1.0, 1.0))
        for zz in (-1, 1):
            for xx in (-1, 1):
                p = V(c) + R @ V((xx * sx * tx, yy * sy, zz * sz * tz))
                idx.append(addv(p, wt))
    # corners: index = (yy>0)*4 + (zz>0)*2 + (xx>0)
    q = lambda a, b, c_, d: addf([idx[a], idx[b], idx[c_], idx[d]], kind, ang, bw)
    q(0, 1, 3, 2)          # -y
    q(4, 6, 7, 5)          # +y
    q(0, 4, 5, 1)          # -z
    q(2, 3, 7, 6)          # +z
    q(0, 2, 6, 4)          # -x
    q(1, 5, 7, 3)          # +x
    return idx


def beam(a, b, w0, h0, w1=None, h1=None, up=V((0, 0, 1)), kind="enamel", wt="root", bw=1.0, inset=0.0):
    a, b = V(a), V(b)
    d = b - a
    R = basis(d, up)
    L = d.length - inset * 2
    w1 = w0 if w1 is None else w1
    h1 = h0 if h1 is None else h1
    return box((a + b) * 0.5, (w0, L, h0), R, kind, wt, 30.0, bw, (w1 / w0, h1 / h0))


def catmull(pts, sub):
    pts = [V(p) for p in pts]
    if sub <= 1 or len(pts) < 3:
        return pts
    out = []
    n = len(pts)
    for i in range(n - 1):
        p0 = pts[max(0, i - 1)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(n - 1, i + 2)]
        for j in range(sub):
            t = j / sub
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def tube(pts, radii, sides=10, kind="rubber", wt="root", caps=True, sub=3, rib=None, ang=55.0, bw=0.5, shape=(1.0, 1.0)):
    """a tube along pts (smoothed), radius interpolated from radii; rib(t) multiplies the radius (bellows)"""
    path = catmull(pts, sub)
    n = len(path)
    if isinstance(radii, (int, float)):
        radii = [radii, radii]
    # parallel-transported frames
    tans = []
    for i in range(n):
        t = (path[min(n - 1, i + 1)] - path[max(0, i - 1)]).normalized()
        tans.append(t)
    ref = V((0, 0, 1)) if abs(tans[0].z) < 0.9 else V((1, 0, 0))
    nrm = tans[0].cross(ref).normalized()
    rings = []
    total = sum((path[i + 1] - path[i]).length for i in range(n - 1)) or 1.0
    acc = 0.0
    for i in range(n):
        if i > 0:
            acc += (path[i] - path[i - 1]).length
            axis = tans[i - 1].cross(tans[i])
            if axis.length > 1e-6:
                ang_ = tans[i - 1].angle(tans[i])
                nrm = Matrix.Rotation(ang_, 3, axis.normalized()) @ nrm
        u = acc / total
        fr = u * (len(radii) - 1)
        k = min(len(radii) - 2, int(fr))
        r = radii[k] + (radii[k + 1] - radii[k]) * (fr - k)
        if rib:
            r *= rib(u, acc)
        bi = tans[i].cross(nrm)
        ring = []
        for j in range(sides):
            a = 2 * math.pi * j / sides
            p = path[i] + (nrm * math.cos(a) * shape[0] + bi * math.sin(a) * shape[1]) * r
            ring.append(addv(p, wt))
        rings.append(ring)
    for i in range(n - 1):
        for j in range(sides):
            j2 = (j + 1) % sides
            addf([rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]], kind, ang, bw)
    if caps:
        addf(list(reversed(rings[0])), kind, ang, bw)
        addf(rings[-1], kind, ang, bw)
    return path


def cyl(a, b, r, sides=12, kind="housing", wt="root", bw=0.6, r1=None):
    return tube([a, b], [r, r if r1 is None else r1], sides, kind, wt, True, 1, None, 40.0, bw)


def superellipse(t, a, b, e=2.6):
    s, c = math.sin(t), math.cos(t)
    return (a * math.copysign(abs(s) ** (2.0 / e), s), b * math.copysign(abs(c) ** (2.0 / e), c))


def shell(k, th0, th1, scale=1.0, lens=(-0.5, 0.5), nth=10, nl=4, thick=0.1, kind="enamel", wt=None, e=2.6, bw=1.0, end_taper=0.94):
    """a patch of segment k's skin from angle th0 to th1 (0 = top, + toward +X), over lens of its length, given thickness"""
    c, R = seg_frame(k)
    y_, z_, w, h, L, p = SEG[k]
    wt = wt or "body_%d" % k
    grid = []
    for i in range(nl + 1):
        u = lens[0] + (lens[1] - lens[0]) * i / nl
        tap = 1.0 - (1.0 - end_taper) * (2 * abs(u)) ** 4
        row = []
        for j in range(nth + 1):
            t = th0 + (th1 - th0) * j / nth
            x, z = superellipse(t, w * 0.5 * scale * tap, h * 0.5 * scale * tap, e)
            row.append(c + R @ V((x, u * L, z)))
        grid.append(row)
    return sheet(grid, thick, kind, wt, bw)


def sheet(grid, thick, kind, wt, bw=1.0, ang=30.0):
    """a curved sheet from a grid of points (rows x cols), thickened outward on its convex side"""
    nr, nc = len(grid), len(grid[0])
    cen = sum((p for row in grid for p in row), V()) / (nr * nc)
    outer, inner = [], []
    for i in range(nr):
        ro, ri = [], []
        for j in range(nc):
            p = grid[i][j]
            du = grid[min(nr - 1, i + 1)][j] - grid[max(0, i - 1)][j]
            dv = grid[i][min(nc - 1, j + 1)] - grid[i][max(0, j - 1)]
            n = du.cross(dv).normalized()
            if n.dot(p - cen) < 0:
                n = -n
            ro.append(addv(p + n * thick * 0.5, wt))
            ri.append(addv(p - n * thick * 0.5, wt))
        outer.append(ro)
        inner.append(ri)
    flip = False
    # winding: outer faces must face out; test the first quad
    a, b, c_ = Mesh.v[outer[0][0]], Mesh.v[outer[0][1]], Mesh.v[outer[1][1]]
    if (b - a).cross(c_ - b).dot(a - cen) < 0:
        flip = True
    def quad(q):
        addf(list(reversed(q)) if flip else q, kind, ang, bw)
    for i in range(nr - 1):
        for j in range(nc - 1):
            quad([outer[i][j], outer[i][j + 1], outer[i + 1][j + 1], outer[i + 1][j]])
            quad([inner[i][j], inner[i + 1][j], inner[i + 1][j + 1], inner[i][j + 1]])
    for i in range(nr - 1):     # rims
        quad([outer[i][0], outer[i + 1][0], inner[i + 1][0], inner[i][0]])
        quad([outer[i][-1], inner[i][-1], inner[i + 1][-1], outer[i + 1][-1]])
    for j in range(nc - 1):
        quad([outer[0][j], inner[0][j], inner[0][j + 1], outer[0][j + 1]])
        quad([outer[-1][j], outer[-1][j + 1], inner[-1][j + 1], inner[-1][j]])
    return outer


def glass_patch(c, R, w, h, bulge, kind, gid, wt, nx=8, ny=6):
    """a curved glass face, centred on c, facing R's +Y, with planar UVs (v up)"""
    idx = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            x, z = (u - 0.5) * w, (v - 0.5) * h
            d = bulge * (1.0 - (2 * u - 1) ** 2) * (1.0 - (2 * v - 1) ** 2)
            row.append((addv(V(c) + R @ V((x, d, z)), wt), (u, v)))
        idx.append(row)
    for j in range(ny):
        for i in range(nx):
            q = [idx[j][i], idx[j][i + 1], idx[j + 1][i + 1], idx[j + 1][i]]
            # facing +Y in R: with x right and z up, (x, z) counter-clockwise seen from +Y means order (0,0)->(0,1 in z)... use x then z reversed
            q = [q[0], q[3], q[2], q[1]]
            addf([p[0] for p in q], kind, 89.0, 0.0, gid, [p[1] for p in q])


def housing(i, c, n, size, bone):
    """weak point i: a recessed steel housing with curved glass, a rubber gasket, copper bolts and the cables that feed it"""
    w, h = size
    R = basis(n, V((0, 0, 1)) if abs(n.z) < 0.85 else V((0, 1, 0)))
    # the box: front face at c + n*0.08, 0.7 deep
    d = 0.7
    fw, fh = w * 1.32, h * 1.38
    front = c + n * 0.08
    # frame as four bars round the glass, then a back plate: a real recess
    t = 0.16
    for (ox, oz, sx, sz) in ((0, (fh - t) / 2, fw, t), (0, -(fh - t) / 2, fw, t), ((fw - t) / 2, 0, t, fh - 2 * t), (-(fw - t) / 2, 0, t, fh - 2 * t)):
        box(front - n * d * 0.5 + R @ V((ox, 0, oz)), (sx, d, sz), R, "housing", bone, 30.0, 0.8)
    box(front - n * (d - 0.06), (fw, 0.12, fh), R, "housing", bone, 30.0, 0.6)
    # the gasket round the glass and the glass, set in 0.22
    gs = front - n * 0.22
    for (ox, oz, sx, sz) in ((0, h / 2 + 0.03, w + 0.1, 0.06), (0, -h / 2 - 0.03, w + 0.1, 0.06), (w / 2 + 0.03, 0, 0.06, h), (-w / 2 - 0.03, 0, 0.06, h)):
        box(gs + R @ V((ox, 0, oz)), (sx, 0.1, sz), R, "rubber", bone, 30.0, 0.3)
    glass_patch(gs, R, w, h, 0.07, "glass", i + 1, bone)
    for (sx, sz) in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        cyl(front + R @ V((sx * (fw / 2 - 0.08), 0.0, sz * (fh / 2 - 0.08))), front + R @ V((sx * (fw / 2 - 0.08), 0.05, sz * (fh / 2 - 0.08))), 0.045, 6, "copper", bone, 0.3)
    # cables out of its back into the body
    back = front - n * d
    for k in range(3):
        o = R @ V(((k - 1) * w * 0.3, 0, -h * 0.25))
        p0 = back + o
        p1 = back - n * 0.5 + o * 1.3 + V((0, 0, -0.25))
        p2 = back - n * 1.0 + o * 0.6
        tube([p0, p1, p2], [0.075, 0.075], 7, "rubber", bone, True, 3)
    return front


def seg_body(k):
    """segment k: dark chassis, cables in it, dorsal plate (tears off), side plates, belly ribs, coxae"""
    c, R = seg_frame(k)
    y_, z_, w, h, L, p = SEG[k]
    bn = "body_%d" % k
    # chassis: a closed superellipse drum at 0.8, steel
    shell(k, -math.pi, math.pi, 0.8, (-0.48, 0.48), 16, 3, 0.0001, "steel", bn, 2.4, 0.4, 0.85)
    for e in (-1, 1):      # its end rings
        tube([c + R @ V((0, e * L * 0.47, 0)), c + R @ V((0, e * L * 0.5, 0))], [min(w, h) * 0.42, min(w, h) * 0.4], 14, "enamel_dark", bn, True, 1, None, 40.0, 0.6)
    # cables along the chassis top, under the dorsal plate (seen when it is torn off)
    for j in range(4):
        x = (j - 1.5) * w * 0.12
        a = c + R @ V((x, -L * 0.48, h * 0.38))
        b = c + R @ V((x, L * 0.48, h * 0.38))
        tube([a, (a + b) * 0.5 + R @ V((0, 0, 0.06 * (j % 2))), b], 0.09 + 0.02 * (j % 2), 7, "rubber" if j % 3 else "copper", bn, False, 2)
    # the dorsal plate: two halves along its length and a spine ridge, bolted; its own bone (torn off at big beats)
    pb = "plate_b%d" % k
    for (l0, l1) in ((-0.47, -0.02), (0.02, 0.47)):
        shell(k, -0.95, 0.95, 1.0, (l0, l1), 10, 2, 0.1, "enamel", pb, 2.6, 1.0)
    ridge0 = c + R @ V((0, -L * 0.44, h * 0.5 + 0.06))
    ridge1 = c + R @ V((0, L * 0.44, h * 0.5 + 0.06))
    beam(ridge0, ridge1, 0.34, 0.2, 0.3, 0.16, R @ V((0, 0, 1)), "enamel_dark", pb, 0.6)
    for (bx, by) in ((-0.32, -0.42), (0.32, -0.42), (-0.32, 0.42), (0.32, 0.42)):
        q = c + R @ V((bx * w, by * L, 0))
        top = q + R @ V((0, 0, h * 0.5 * 0.97 + 0.05))
        cyl(top, top + R @ V((0, 0, 0.05)), 0.07, 6, "copper", pb, 0.3)
    if k in (1, 2, 3):      # heat-sink fins on the plates behind the chest
        for j in range(5):
            yy = (j - 2) * L * 0.15
            for sx in (-1, 1):
                base = c + R @ V((sx * w * 0.22, yy, h * 0.5 + 0.05))
                box(base + R @ V((0, 0, 0.18)), (0.07, L * 0.11, 0.42), R, "copper", pb, 30.0, 0.3)
    # side plates; on the chest they are the shoulder plates (tear off) and leave room below for the flank screens
    for sn, s in SIDES:
        wt = ("plate_sh_" + sn) if k == 0 else bn
        th = (1.02, 1.75) if k == 0 else (1.02, 2.15)
        a0, a1 = (th[0], th[1]) if s > 0 else (-th[1], -th[0])
        shell(k, a0, a1, 1.0, (-0.45, 0.45), 5, 3, 0.09, "enamel", wt, 2.6, 1.0)
        # a trim strip along the plate's lower edge
        x, z = superellipse(s * th[1], w * 0.5, h * 0.5)
        a = c + R @ V((x, -L * 0.42, z))
        b = c + R @ V((x, L * 0.42, z))
        beam(a, b, 0.14, 0.14, up=R @ V((0, 0, 1)), kind="enamel_dark", wt=wt, bw=0.4)
    # belly: dark ribs across the underside
    for j in range(4):
        yy = (j - 1.5) * L * 0.24
        x0, z0 = superellipse(math.pi * 0.75, w * 0.5 * 0.86, h * 0.5 * 0.86)
        pts = [c + R @ V((x0, yy, z0)), c + R @ V((0, yy, -h * 0.5 * 0.93)), c + R @ V((-x0, yy, z0))]
        tube(pts, 0.12, 6, "enamel_dark", bn, True, 3)
    # coxae: the actuator drums the legs hang from
    for sn, s in SIDES:
        hp = hip(k, s)
        ax = V((s, 0, 0))
        cyl(hp - ax * 0.75, hp + ax * 0.05, 0.58 - 0.03 * k, 14, "housing", bn, 0.7)
        cyl(hp - ax * 0.45, hp - ax * 0.25, 0.64 - 0.03 * k, 14, "copper", bn, 0.4)
        cyl(hp + ax * 0.05, hp + ax * 0.15, 0.36, 10, "enamel_dark", bn, 0.4)
        for j in range(2):
            a = hp - ax * 0.6 + V((0, (j - 0.5) * 0.6, 0.45))
            tube([a, a + V((0, 0, 0.5)) - ax * 0.2, c + R @ V((s * w * 0.25, (j - 0.5) * 0.8, h * 0.3))], 0.08, 7, "rubber", bn, False, 3)


def flex(chain_pts, names, zone=0.3):
    """weights along a chain of bones: rigid inside each, blended over +-zone (fraction of a bone) at each joint"""
    def f(p):
        best, bi, bt = 1e9, 0, 0.0
        for i in range(len(names)):
            a, b = chain_pts[i], chain_pts[i + 1]
            ab = b - a
            if ab.length_squared < 1e-9:
                continue
            t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
            d = (a + ab * t - p).length
            if d < best:
                best, bi, bt = d, i, t
        tt = bi + bt
        j = round(tt)
        if 0 < j < len(names) and abs(tt - j) < zone:
            u = (tt - (j - zone)) / (2 * zone)
            u = u * u * (3 - 2 * u)
            return {names[j - 1]: 1.0 - u, names[j]: u}
        return {names[min(len(names) - 1, int(tt))]: 1.0}
    return f


def body_chain():
    pts = [seg_frame(k)[0] for k in (4, 3, 2, 1, 0)]
    return pts, ["body_3", "body_2", "body_1", "body_0"][::1]


def build_body():
    for k in range(5):
        seg_body(k)
    # bellows between segments
    for k in range(4):
        ca, Ra = seg_frame(k)
        cb, Rb = seg_frame(k + 1)
        a = ca - seg_dir(k) * SEG[k][4] * 0.47
        b = cb + seg_dir(k + 1) * SEG[k + 1][4] * 0.47
        r = min(SEG[k][3], SEG[k + 1][3]) * 0.36
        tube([a, b], r, 16, "rubber", flex([cb, (a + b) * 0.5, ca], ["body_%d" % (k + 1), "body_%d" % k], 0.5), True, 6, lambda u, s: 1.0 + 0.08 * math.cos(u * math.pi * 10), 60.0, 0.3)
    # the long cable bundles down each flank, sagging between segments
    chain = [seg_frame(k)[0] for k in range(5)][::-1]
    names = ["body_%d" % k for k in range(5)][::-1]
    def fl(p):
        best = min(range(5), key=lambda k: abs(p.y - SEG[k][0]))
        # blend between the two nearest segments by y
        ys = [SEG[k][0] for k in range(5)]
        for k in range(4):
            if ys[k + 1] <= p.y <= ys[k]:
                u = (p.y - ys[k + 1]) / (ys[k] - ys[k + 1])
                u = max(0.0, min(1.0, (u - 0.35) / 0.3))
                return {"body_%d" % (k + 1): 1.0 - u, "body_%d" % k: u}
        return {"body_%d" % best: 1.0}
    for sn, s in SIDES:
        for j in range(3):
            pts = []
            for k in range(5):
                c, R = seg_frame(k)
                x, z = superellipse(s * (2.2 + j * 0.12), SEG[k][2] * 0.5 * 0.92, SEG[k][3] * 0.5 * 0.92)
                pts.append(c + R @ V((x, 0, z)))
                if k < 4:
                    c2, R2 = seg_frame(k + 1)
                    x2, z2 = superellipse(s * (2.2 + j * 0.12), SEG[k + 1][2] * 0.5 * 0.92, SEG[k + 1][3] * 0.5 * 0.92)
                    mid = (c + R @ V((x, 0, z)) + c2 + R2 @ V((x2, 0, z2))) * 0.5
                    pts.append(mid + V((s * 0.1, 0, -0.35 - 0.1 * j)))
            tube(pts, 0.11 - j * 0.015, 7, "rubber" if j != 1 else "copper", fl, True, 3)
    # SERN's markings on the flanks
    for k in (1, 2):
        c, R = seg_frame(k)
        for sn, s in SIDES:
            x, z = superellipse(s * 1.45, SEG[k][2] * 0.5 + 0.05, SEG[k][3] * 0.5 + 0.05)
            text("SERN", c + R @ V((x + s * 0.02, 0.0, z)), V((s, 0, 0.25)).normalized(), 0.55, "paint_black", "body_%d" % k)
    # a hazard band round the chest's front ring
    c, R = seg_frame(0)
    for j in range(8):
        a = -math.pi * 0.42 + j * math.pi * 0.105
        x, z = superellipse(a, SEG[0][2] * 0.43, SEG[0][3] * 0.43)
        box(c + R @ V((x, SEG[0][4] * 0.5 + 0.02, z)), (0.22, 0.06, 0.12), R @ Matrix.Rotation(a, 3, 'Y'), "paint_red" if j % 2 else "paint_black", "body_0", 30.0, 0.2)


def text(s, at, normal, size, kind, wt):
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = s
    cu.size = size
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    ob = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    # the text lies in its XY plane facing +Z: stand it on the surface facing `normal`, reading along the body (its x along -Y on the left flank, +Y on the right)
    side = 1.0 if normal.x > 0 else -1.0
    xa = V((0, side, 0))
    za = normal.normalized()
    ya = za.cross(xa).normalized()
    xa = ya.cross(za)
    M = Matrix((xa, ya, za)).transposed()
    base = len(Mesh.v)
    for vv in me.vertices:
        addv(V(at) + M @ vv.co, wt)
    for p in me.polygons:
        addf([base + i for i in p.vertices], kind, 89.0, 0.0)
    ob.to_mesh_clear()
    bpy.data.objects.remove(ob)


def build_legs():
    for k in range(5):
        for sn, s in SIDES:
            H, K, F = hip(k, s), knee(k, s), foot(k, s)
            fe, ti = "leg_%d_%s_0" % (k, sn), "leg_%d_%s_1" % (k, sn)
            sc = 1.12 if k == 0 else 1.0
            plane_n = (K - H).cross(F - K).normalized()      # the leg's hinge axis
            up = (K - H).cross(plane_n)
            # femur: an enamel box beam with a ridge, a piston along it
            beam(H + (K - H).normalized() * 0.2, K, 0.62 * sc, 0.82 * sc, 0.48 * sc, 0.62 * sc, plane_n.cross(K - H), "enamel", fe, 1.0)
            beam(H + (K - H) * 0.15 + up.normalized() * -0.0, H + (K - H) * 0.85, 0.2, 0.3, 0.16, 0.24, plane_n.cross(K - H), "enamel_dark", fe, 0.5, 0.0)
            pd = (plane_n.cross(K - H)).normalized()
            if pd.z < 0:
                pd = -pd
            pa, pb_ = H + (K - H) * 0.2 - pd * 0.5, H + (K - H) * 0.8 - pd * 0.42
            cyl(pa, (pa + pb_) * 0.5, 0.15, 10, "housing", fe, 0.4)
            cyl((pa + pb_) * 0.5 - (pb_ - pa).normalized() * 0.1, pb_, 0.09, 8, "edge", fe, 0.3)
            # knee: a drum on the hinge axis with a copper winding
            cyl(K - plane_n * 0.45, K + plane_n * 0.45, 0.4 * sc, 14, "housing", fe, 0.7)
            cyl(K - plane_n * 0.18, K + plane_n * 0.18, 0.46 * sc, 14, "copper", fe, 0.4)
            # tibia: a long tapering steel blade with an enamel cuff
            dd = (F - K).normalized()
            beam(K + dd * 0.25, F + dd * -0.55, 0.42 * sc, 0.62 * sc, 0.1, 0.16, plane_n.cross(dd), "steel", ti, 0.8)
            beam(K + dd * 0.2, K + dd * 1.9, 0.56 * sc, 0.78 * sc, 0.48 * sc, 0.66 * sc, plane_n.cross(dd), "enamel", ti, 1.0)
            beam(K + dd * 1.95, K + dd * 2.15, 0.5 * sc, 0.7 * sc, 0.46 * sc, 0.62 * sc, plane_n.cross(dd), "enamel_dark", ti, 0.4)
            # the foot: a spike and two claws
            tube([F - dd * 0.75, F + V((0, 0, 0.02))], [0.14, 0.03], 6, "edge", ti, True, 1, None, 40.0, 0.2)
            for cl in (-1, 1):
                q = F - dd * 0.6
                tube([q, q + V((cl * 0.0, 0.45, 0.1)) + plane_n * cl * 0.25, q + V((0, 0.7, -0.5)) + plane_n * cl * 0.35], [0.08, 0.02], 6, "steel", ti, True, 2)
            # a cable down the femur
            tube([H + up.normalized() * 0.1 - plane_n * 0.25, (H + K) * 0.5 + pd * 0.45 - plane_n * 0.3, K - plane_n * 0.5], 0.07, 6, "rubber", fe, True, 3)


def build_neck_head():
    names = ["neck_%d" % i for i in range(5)]
    core = flex(NECK, names, 0.35)
    tube(NECK + [NECK[5] + HEAD_DIR * 0.3], [0.62, 0.55, 0.5, 0.46, 0.42], 14, "rubber", core, False, 4, lambda u, s: 1.0 + 0.1 * math.cos(s * 2 * math.pi / 0.32), 70.0, 0.0)
    # cable bundles under and beside the neck
    for j, (ox, oz) in enumerate(((-0.45, -0.35), (0.45, -0.35), (0.0, -0.55), (-0.2, 0.5))):
        pts = []
        for i, p in enumerate(NECK):
            t = (NECK[min(5, i + 1)] - NECK[max(0, i - 1)]).normalized()
            side = V((1, 0, 0))
            dn = side.cross(t)
            sag = 0.12 * math.sin(i * 1.7 + j)
            pts.append(p + side * ox + dn * (oz - sag))
        tube(pts, 0.1 if j < 3 else 0.07, 7, "copper" if j == 2 else "rubber", core, True, 3)
    # armour collars, one on each neck bone, and a fin along its top
    for i in range(5):
        a, b = NECK[i], NECK[i + 1]
        d = (b - a)
        R = basis(d, V((0, 0, 1)))
        m = a + d * 0.5
        r = 0.86 - i * 0.07
        tube([m - d.normalized() * 0.42, m + d.normalized() * 0.42], [r, r * 0.9], 16, "enamel", names[i], True, 1, None, 40.0, 1.0)
        tube([m - d.normalized() * 0.46, m - d.normalized() * 0.36], [r * 1.04, r * 1.04], 16, "enamel_dark", names[i], True, 1, None, 40.0, 0.4)
        fin_dir = R @ V((0, 0, 1))
        box(m + fin_dir * (r + 0.18), (0.16, d.length * 0.62, 0.42), R, "enamel_dark", names[i], 30.0, 0.5, (1.0, 0.5))
        if i == 1:      # a red hazard ring on the throat collar
            tube([m + d.normalized() * 0.1, m + d.normalized() * 0.22], [r * 1.02, r * 1.0], 16, "paint_red", names[i], True, 1, None, 40.0, 0.2)
    # the head: a 90s CRT, yellowed plastic, its glass the Sigil's face
    hx = head_frame()
    H = lambda p: hx @ V(p)
    R = hx.to_3x3()
    # the bezel: a rounded frame round the screen's opening (1.02 x 0.78), the glass set in it
    for (ox, oz, sx, sz) in ((0, 0.46, 1.36, 0.14), (0, -0.46, 1.36, 0.14), (0.595, 0, 0.17, 0.8), (-0.595, 0, 0.17, 0.8)):
        box(H((ox, 1.04, oz)), (sx, 0.3, sz), R, "crt_plastic", "head", 30.0, 0.9)
    for (ox, oz, sx, sz) in ((0, 0.4, 1.04, 0.03), (0, -0.4, 1.04, 0.03), (0.52, 0, 0.03, 0.8), (-0.52, 0, 0.03, 0.8)):
        box(H((ox, 0.99, oz)), (sx, 0.12, sz), R, "housing", "head", 30.0, 0.0)
    glass_patch(H((0, 0.98, 0.0)), R, 1.04, 0.8, 0.08, "crt", 0, "head", 10, 8)
    # the tube's back
    box(H((0, 0.5, 0.0)), (1.22, 0.9, 0.96), R, "crt_plastic", "head", 30.0, 1.4, (1.0, 1.0))
    box(H((0, -0.15, 0.0)), (0.66, 0.5, 0.52), R, "crt_plastic", "head", 30.0, 1.2, (1.6, 1.6))
    for j in range(5):      # vents
        box(H(((j - 2) * 0.2, 0.42, 0.49)), (0.07, 0.6, 0.03), R, "housing", "head", 30.0, 0.2)
    for j in range(2):      # knobs and the brand plate
        cyl(H((0.48 - j * 0.16, 1.2, -0.46)), H((0.48 - j * 0.16, 1.24, -0.46)), 0.045, 10, "housing", "head", 0.2)
    box(H((-0.35, 1.195, -0.47)), (0.3, 0.02, 0.05), R, "copper", "head", 30.0, 0.1)
    # the neck's socket and the mandibles under the set
    cyl(H((0, -0.5, -0.05)), H((0, 0.1, -0.05)), 0.46, 14, "housing", "head", 0.6)
    for s in (-1, 1):
        beam(H((s * 0.5, 0.55, -0.48)), H((s * 0.34, 1.75, -1.15)), 0.22, 0.3, 0.06, 0.08, R @ V((0, 0, 1)), "steel", "head", 0.5)
        beam(H((s * 0.62, 0.2, -0.3)), H((s * 0.5, 0.75, -0.55)), 0.26, 0.3, 0.22, 0.26, R @ V((0, 0, 1)), "enamel_dark", "head", 0.6)
    for j in range(3):
        a = H(((j - 1) * 0.25, -0.3, -0.25))
        tube([a, a + V((0, -0.4, -0.3)), NECK[4] + (NECK[5] - NECK[4]) * 0.6 + V(((j - 1) * 0.3, 0, -0.4))], 0.08, 7, "rubber", flex([NECK[4], NECK[5], H((0, 0.8, 0))], ["neck_4", "head"], 0.4), True, 3)
    # the armour round it, on three hinged bones: a top plate and two cheeks that close it to a visor slit; they open for the finale
    # (angular plates, beveled: the first try lofted them as sheets and they came out pillowy)
    Rt = R @ Matrix.Rotation(-0.08, 3, 'X')
    box(H((0, 0.62, 0.66)), (1.66, 1.3, 0.1), Rt, "enamel", "shell_t", 30.0, 1.0, (1.0, 1.0))
    Rv = R @ Matrix.Rotation(-0.95, 3, 'X')      # the visor lip, down over the top of the glass
    box(H((0, 1.36, 0.47)), (1.5, 0.34, 0.09), Rv, "enamel", "shell_t", 30.0, 1.0)
    box(H((0, 0.62, 0.74)), (0.22, 1.1, 0.12), Rt, "enamel_dark", "shell_t", 30.0, 0.5, (0.6, 0.6))
    for sn, s in SIDES:
        Rs = R @ Matrix.Rotation(s * 0.06, 3, 'Z')
        box(H((s * 0.82, 0.62, 0.0)), (0.1, 1.24, 1.14), Rs, "enamel", "shell_" + sn, 30.0, 1.0, (1.0, 0.85))
        Rc = R @ Matrix.Rotation(-s * 0.85, 3, 'Z')      # the cheek's lip, in over the side of the glass
        box(H((s * 0.7, 1.32, -0.02)), (0.09, 0.36, 0.98), Rc, "enamel", "shell_" + sn, 30.0, 1.0)
        box(H((s * 0.88, 0.5, -0.3)), (0.08, 0.6, 0.22), Rs, "enamel_dark", "shell_" + sn, 30.0, 0.4)
        cyl(H((s * 0.78, 0.15, -0.3)), H((s * 0.78, 0.15, 0.3)), 0.1, 8, "copper", "shell_" + sn, 0.3)
    cyl(H((-0.4, 0.05, 0.64)), H((0.4, 0.05, 0.64)), 0.09, 8, "copper", "shell_t", 0.3)


def build_arms():
    for sn, s in SIDES:
        S, E, Wr, T = shoulder(s), ELBOW(s), WRIST(s), BLADE_TIP(s)
        a0, a1, a2 = "arm_%s_0" % sn, "arm_%s_1" % sn, "arm_%s_2" % sn
        hn = (E - S).cross(Wr - E).normalized()       # the arm's hinge axis
        cyl(S - V((s * 0.5, 0, 0)), S + V((s * 0.3, 0, 0)), 0.55, 14, "housing", "body_0", 0.7)
        cyl(S - V((s * 0.1, 0, 0)), S + V((s * 0.12, 0, 0)), 0.62, 14, "copper", a0, 0.4)
        beam(S + (E - S).normalized() * 0.3, E, 0.6, 0.72, 0.48, 0.58, hn.cross(E - S), "enamel", a0, 1.0)
        pd = hn.cross(E - S).normalized()
        cyl(S + (E - S) * 0.15 + pd * 0.45, S + (E - S) * 0.6 + pd * 0.45, 0.13, 8, "housing", a0, 0.3)
        cyl(S + (E - S) * 0.55 + pd * 0.45, S + (E - S) * 0.92 + pd * 0.4, 0.08, 8, "edge", a0, 0.3)
        cyl(E - hn * 0.42, E + hn * 0.42, 0.42, 14, "housing", a0, 0.6)
        cyl(E - hn * 0.15, E + hn * 0.15, 0.47, 14, "copper", a0, 0.3)
        beam(E + (Wr - E).normalized() * 0.3, Wr, 0.5, 0.6, 0.4, 0.5, hn.cross(Wr - E), "enamel", a1, 1.0)
        tube([S + V((0, -0.2, 0.5)), (S + E) * 0.5 + pd * -0.5, E + pd * -0.3, (E + Wr) * 0.5 + pd * -0.4, Wr + pd * -0.2], 0.08, 7, "rubber",
             flex([S, E, Wr], [a0, a1], 0.25), True, 3)
        cyl(Wr - hn * 0.32, Wr + hn * 0.32, 0.3, 12, "housing", a1, 0.5)
        # the scythe: a long hooked blade, steel spine and a ground edge, its edge facing down and in
        n = 14
        dirv = (T - Wr)
        L = dirv.length
        R = basis(dirv, hn.cross(dirv) if hn.cross(dirv).z > 0 else -hn.cross(dirv))
        spine, edge_ = [], []
        for i in range(n + 1):
            u = i / n
            y = u * L
            hook = -u * u * 1.6 + math.sin(u * math.pi) * 0.6
            wide = 0.8 * (1 - u ** 1.6) + 0.05
            spine.append((y, hook + wide * 0.35))
            edge_.append((y, hook - wide * 0.65))
        th = 0.13
        def P(y, z, x):
            return Wr + R @ V((x, y, z))
        ids = []
        for i in range(n + 1):
            y, zs = spine[i]
            _, ze = edge_[i]
            zm = zs + (ze - zs) * 0.7
            t = th * (1 - 0.8 * i / n)
            ids.append([addv(P(y, zs, -t), a2), addv(P(y, zs, t), a2), addv(P(y, zm, t), a2), addv(P(y, ze, 0.0), a2), addv(P(y, zm, -t), a2)])
        for i in range(n):
            A, B = ids[i], ids[i + 1]
            addf([A[0], A[1], B[1], B[0]], "steel", 30.0, 0.3)       # spine top
            addf([A[1], A[2], B[2], B[1]], "steel", 30.0, 0.3)       # side +
            addf([A[2], A[3], B[3], B[2]], "edge", 30.0, 0.0)        # bevel +
            addf([A[3], A[4], B[4], B[3]], "edge", 30.0, 0.0)        # bevel -
            addf([A[4], A[0], B[0], B[4]], "steel", 30.0, 0.3)       # side -
        addf([ids[0][4], ids[0][3], ids[0][2], ids[0][1], ids[0][0]], "steel", 30.0, 0.0)
        # its root collar
        cyl(Wr + dirv.normalized() * -0.1, Wr + dirv.normalized() * 0.5, 0.36, 12, "enamel_dark", a2, 0.5)


def build_tail():
    names = ["tail_%d" % i for i in range(3)]
    f = flex(TAIL, names, 0.35)
    tube([SEG[4] and seg_frame(4)[0] + V((0, -0.5, 0))] + TAIL, [0.48, 0.42, 0.3, 0.2, 0.12], 12, "rubber", flex([seg_frame(4)[0]] + TAIL, ["body_4"] + names, 0.3), True, 4,
         lambda u, s: 1.0 + 0.09 * math.cos(s * 2 * math.pi / 0.3), 70.0, 0.0)
    for i in range(3):
        a, b = TAIL[i], TAIL[i + 1]
        m = (a + b) * 0.5
        d = (b - a).normalized()
        r = 0.55 - i * 0.12
        tube([m - d * 0.25, m + d * 0.25], [r, r * 0.92], 12, "enamel", names[i], True, 1, None, 40.0, 0.8)
    # the plug at its end: a copper connector with prongs
    e = TAIL[3]
    d = (TAIL[3] - TAIL[2]).normalized()
    cyl(e - d * 0.2, e + d * 0.4, 0.2, 10, "housing", "tail_2", 0.4)
    for j in range(3):
        o = basis(d) @ V((math.cos(j * 2.1) * 0.1, 0, math.sin(j * 2.1) * 0.1))
        cyl(e + d * 0.4 + o, e + d * 0.7 + o, 0.03, 6, "copper", "tail_2", 0.1)


def build_points():
    for i, (c, n, size, bone) in enumerate(POINTS):
        housing(i, c, n, size, bone)

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# turning the builder into a Blender object

def materials():
    cols = {
        "enamel": ((0.62, 0.62, 0.58), 0.0, 0.42), "enamel_dark": ((0.16, 0.17, 0.18), 0.0, 0.5), "steel": ((0.09, 0.09, 0.1), 0.9, 0.38),
        "edge": ((0.6, 0.61, 0.63), 1.0, 0.18), "rubber": ((0.022, 0.022, 0.025), 0.0, 0.72), "copper": ((0.55, 0.26, 0.13), 1.0, 0.35),
        "housing": ((0.045, 0.045, 0.05), 0.2, 0.5), "crt_plastic": ((0.5, 0.45, 0.34), 0.0, 0.55), "paint_black": ((0.02, 0.02, 0.02), 0.0, 0.6),
        "paint_red": ((0.42, 0.03, 0.02), 0.0, 0.5), "glass": ((0.0, 0.0, 0.0), 0.0, 0.05), "crt": ((0.02, 0.1, 0.03), 0.0, 0.05),
    }
    out = []
    for k in KINDS:
        m = bpy.data.materials.get("k_" + k) or bpy.data.materials.new("k_" + k)
        m.use_nodes = True
        bs = m.node_tree.nodes.get("Principled BSDF")
        c, met, rough = cols[k]
        bs.inputs["Base Color"].default_value = (*c, 1)
        bs.inputs["Metallic"].default_value = met
        bs.inputs["Roughness"].default_value = rough
        if k == "glass":
            bs.inputs["Emission Color"].default_value = (1.0, 0.55, 0.1, 1)
            bs.inputs["Emission Strength"].default_value = 0.0
        if k == "crt":
            bs.inputs["Emission Color"].default_value = (0.3, 1.0, 0.4, 1)
            bs.inputs["Emission Strength"].default_value = 2.0
        out.append(m)
    return out


def make_object():
    me = bpy.data.meshes.new("sigil")
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in Mesh.v]
    bm.verts.ensure_lookup_table()
    uv = bm.loops.layers.uv.new("UVMap")
    uvid = bm.loops.layers.uv.new("UVid")      # which weak point a glass face belongs to: u = (index + 1.5) / 8 (UV2 in Godot; vertex colours would be colour-converted)
    kinds = {k: i for i, k in enumerate(KINDS)}
    face_info = []
    for (idx, kind, ang, bw, gid, uvs) in Mesh.f:
        if len(set(idx)) < 3:
            continue
        try:
            f = bm.faces.new([vs[i] for i in idx])
        except ValueError:
            continue
        f.material_index = kinds[kind]
        f.smooth = True
        for li, l in enumerate(f.loops):
            l[uvid].uv = ((gid + 0.5) / 8.0, 0.5) if kind == "glass" else (0.0, 0.0)
            if uvs:
                l[uv].uv = uvs[li]
        face_info.append((f, ang, bw, kind))
    bm.faces.ensure_lookup_table()
    # hard edges: sharp and bevelled where the faces meet at more than their part's angle
    bwl = bm.edges.layers.float.new("bevel_weight_edge")
    info = {f: (a, b) for f, a, b, k in face_info}
    for e in bm.edges:
        if len(e.link_faces) != 2:
            continue
        f0, f1 = e.link_faces
        a0, b0 = info.get(f0, (30.0, 1.0))
        a1, b1 = info.get(f1, (30.0, 1.0))
        ang = math.degrees(f0.normal.angle(f1.normal, 0.0))
        if ang > min(a0, a1):
            e.smooth = False
            e[bwl] = max(0.0, min(1.0, min(b0, b1) / 3.0))
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("sigil", me)
    bpy.context.scene.collection.objects.link(ob)
    for m in materials():
        me.materials.append(m)
    # weights
    for i, wd in enumerate(Mesh.w):
        for bn, wv in wd.items():
            if wv <= 0.0:
                continue
            g = ob.vertex_groups.get(bn) or ob.vertex_groups.new(name=bn)
            g.add([i], wv, 'REPLACE')
    # bevel by weight (max 0.12 m), hardened normals
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.limit_method = 'WEIGHT'
    mod.width = 0.12
    mod.segments = 2
    mod.harden_normals = True
    mod.miter_outer = 'MITER_ARC'
    mod.use_clamp_overlap = True
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="bevel")
    return ob


def build_all():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    Mesh.v, Mesh.w, Mesh.f = [], [], []
    build_body()
    build_legs()
    build_neck_head()
    build_arms()
    build_tail()
    build_points()
    ob = make_object()
    return ob

# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# preview renders (Cycles, a dark set and three lights)

def preview(ob, folder, views=None, res=(960, 600), samples=24, tag=""):
    os.makedirs(folder, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = res
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.01, 0.014, 0.012, 1)
    sc.world = w
    def light(name, kind, loc, energy, col=(1, 1, 1), size=4.0):
        ld = bpy.data.lights.new(name, kind)
        ld.energy = energy
        ld.color = col
        if kind == "AREA":
            ld.size = size
        lo = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(lo)
        lo.location = loc
        d = V((0, 0, 5)) - V(loc)
        lo.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    light("key", "AREA", (14, 28, 18), 30000, (1.0, 0.97, 0.92), 10)
    light("rim", "AREA", (-12, -20, 14), 22000, (0.55, 0.9, 0.7), 10)
    light("fill", "AREA", (-16, 20, 4), 6000, (0.6, 0.7, 1.0), 10)
    g = bpy.data.objects.get("ground")
    if g is None:
        bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, 0))
        g = bpy.context.object
        g.name = "ground"
        gm = bpy.data.materials.new("ground")
        gm.use_nodes = True
        gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.03, 0.035, 0.03, 1)
        g.data.materials.append(gm)
    cam_d = bpy.data.cameras.new("cam")
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    views = views or {
        "car": ((3.0, 26.0, 3.2), (0, 2, 6.5), 20),
        "side": ((34.0, 2.0, 7.0), (0, -1.5, 5.0), 24),
        "high": ((-18.0, 20.0, 18.0), (0, 0, 4.0), 24),
        "head": ((2.5, 19.5, 7.0), (0, 12.8, 8.4), 45),
    }
    out = []
    for name, (at, look, lens) in views.items():
        cam.location = at
        cam.rotation_euler = (V(look) - V(at)).to_track_quat('-Z', 'Y').to_euler()
        cam_d.lens = lens
        p = os.path.join(folder, "%s%s.png" % (tag, name))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        out.append(p)
    return out


def gpu_on():
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for dev in ("OPTIX", "CUDA"):
            try:
                prefs.compute_device_type = dev
                prefs.get_devices()
                if any(d.type == dev for d in prefs.devices):
                    for d in prefs.devices:
                        d.use = d.type == dev
                    bpy.context.scene.cycles.device = 'GPU'
                    print("CYCLES GPU", dev)
                    return
            except TypeError:
                pass
    except Exception as e:
        print("no gpu", e)


def unwrap(ob):
    """the body's faces smart-projected and packed into one atlas; the glass keeps its own planar UVs"""
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    ob.data.uv_layers.active = ob.data.uv_layers["UVMap"]
    ob.data.uv_layers["UVMap"].active_render = True
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(ob.data)
    for f in bm.faces:
        f.select = f.material_index < len(BAKED)
    bmesh.update_edit_mesh(ob.data)
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0015, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(rotate=True, margin=0.0015)
    bpy.ops.object.mode_set(mode='OBJECT')


def final_materials(ob):
    """the kinds merged into three materials: the baked body, the weak points' glass, the CRT's glass"""
    me = ob.data
    idx = [0] * len(me.polygons)
    me.polygons.foreach_get("material_index", idx)
    remap = [0 if k in BAKED else (1 if k == "glass" else 2) for k in KINDS]
    idx = [remap[i] for i in idx]
    me.materials.clear()
    body = bpy.data.materials.new("sigil_body")
    body.use_nodes = True
    bs = body.node_tree.nodes["Principled BSDF"]
    nt = body.node_tree
    paths = {k: os.path.join(TEX_DIR, "sigil_%s.png" % k) for k in ("albedo", "orm", "normal")}
    if all(os.path.exists(p) for p in paths.values()):
        def img(k, non_color):
            n = nt.nodes.new("ShaderNodeTexImage")
            n.image = bpy.data.images.load(paths[k])
            if non_color:
                n.image.colorspace_settings.name = "Non-Color"
            return n
        a = img("albedo", False)
        nt.links.new(a.outputs["Color"], bs.inputs["Base Color"])
        o = img("orm", True)
        sep = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(o.outputs["Color"], sep.inputs["Color"])
        nt.links.new(sep.outputs["Green"], bs.inputs["Roughness"])
        nt.links.new(sep.outputs["Blue"], bs.inputs["Metallic"])
        g = bpy.data.node_groups.get("glTF Material Output") or bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        if "Occlusion" not in [i.name for i in g.interface.items_tree]:
            g.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
        gn = nt.nodes.new("ShaderNodeGroup")
        gn.node_tree = g
        nt.links.new(sep.outputs["Red"], gn.inputs["Occlusion"])
        nm = img("normal", True)
        nmap = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(nm.outputs["Color"], nmap.inputs["Color"])
        nt.links.new(nmap.outputs["Normal"], bs.inputs["Normal"])
    else:
        bs.inputs["Base Color"].default_value = (0.6, 0.6, 0.57, 1)
        print("NO BAKED MAPS: body exported flat")
    me.materials.append(body)
    for name in ("sigil_glass", "sigil_crt"):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.0, 0.0, 0.0, 1)
        m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.05
        me.materials.append(m)
    me.polygons.foreach_set("material_index", idx)
    me.update()


def pose_sheet(rig, folder, shots):
    """workbench stills of named clips at given times, tiled into one sheet"""
    import numpy as np
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'MATERIAL'
    sh.show_cavity = True
    sc.render.resolution_x, sc.render.resolution_y = 640, 400
    cam = sc.camera
    if cam is None:
        cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
        sc.collection.objects.link(cam)
        sc.camera = cam
    cam.location = (60.0, 4.0, 6.0)
    cam.rotation_euler = (V((0, 4.0, 6.0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 38.0
    refm = bpy.data.materials.new("ref")
    refm.diffuse_color = (0.9, 0.3, 0.1, 1)
    for (c, sz) in (((0, 4, 11.8), (0.1, 60, 0.08)), ((0, 4, 0), (0.1, 60, 0.05)), ((0, 25, 0.6), (2.8, 18, 1.2)), ((0, 17, 2.1), (0.5, 0.5, 1.8))):
        bpy.ops.mesh.primitive_cube_add(size=1, location=c)
        r = bpy.context.object
        r.scale = sz
        r.data.materials.append(refm)
    for t in []:
        pass
    for t in rig.animation_data.nla_tracks:
        t.mute = True
    tiles = []
    for (name, u) in shots:
        act = bpy.data.actions[name]
        rig.animation_data.action = act
        try:
            rig.animation_data.action_slot = act.slots[0]
        except Exception:
            pass
        f0, f1 = act.frame_range
        sc.frame_set(int(round(f0 + (f1 - f0) * u)))
        p = os.path.join(folder, "pose_%s_%d.png" % (name, int(u * 100)))
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(p)
        tiles.append(np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4))
    rig.animation_data.action = None
    for t in rig.animation_data.nla_tracks:
        t.mute = False
    cols = 4
    while len(tiles) % cols:
        tiles.append(np.zeros_like(tiles[0]))
    rows = [np.concatenate(tiles[i:i + cols], axis=1) for i in range(0, len(tiles), cols)]
    sheet = np.concatenate(rows[::-1], axis=0)
    out = bpy.data.images.new("poses", sheet.shape[1], sheet.shape[0])
    out.pixels = sheet.ravel()
    out.filepath_raw = os.path.join(folder, "poses.png")
    out.file_format = 'PNG'
    out.save()


if __name__ == "__main__":
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import sigil_rig as RG
    ob = build_all()
    print("SIGIL tris", sum(len(p.vertices) - 2 for p in ob.data.polygons), "verts", len(ob.data.vertices))
    gpu_on()
    unwrap(ob)
    if "--bake" in ARGS:
        import sigil_bake
        sigil_bake.bake(ob, TEX_DIR, TEX)
    rig = RG.build_rig(ob)
    RG.markers(rig)
    if "--export" in ARGS or "--poses" in ARGS or "--measure" in ARGS:
        RG.setup_ik(rig)
        RG.write_actions(rig, RG.capture(rig))
    final_materials(ob)
    if "--measure" in ARGS:
        RG.measure(rig, ob, opt("--measure-clips", "idle,run,rear,swipe_l,roar,idle_low,run_low,swipe_l_low,swipe_r_low,roar_low,strike,lunge,hit,reel,land").split(","))
    pv = opt("--preview")
    if pv:
        preview(ob, pv)
    if opt("--poses"):
        pose_sheet(rig, opt("--poses"), [("idle", 0.3), ("run", 0.0), ("run", 0.5), ("rear", 0.38), ("swipe_l", 0.38), ("swipe_l", 0.55), ("strike", 1.0), ("roar", 0.5),
                                         ("reel", 0.3), ("land", 0.15), ("climb", 0.25), ("grab", 0.3), ("fall", 0.4), ("defeat", 1.0), ("wall_run", 0.25), ("lunge", 0.4)])
    os.makedirs(CACHE, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=CACHE + "/sigil.blend")
    if "--export" in ARGS:
        RG.export(OUT_GLB)
        print("EXPORTED", OUT_GLB)
