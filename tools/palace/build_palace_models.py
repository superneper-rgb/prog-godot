# PALACE: the hero models of the SAMBO FENRIR episode, built in headless Blender and written to assets/palace/:
#   sambo_mech.glb  the luxury mech his parents drop him, the boss. Rigid parts, each its own node with its origin on its joint, so the game animates it by turning nodes.
#   drop_pod.glb    the Faberge-egg drop pod it comes down in: a scorched heat-shield base with retro thrusters, four petals that open like a flower, a cap that blows off first.
#   yacht.glb       the parents' space yacht, seen over Earth from mid distance in one cutscene shot.
# Run headless, never in the user's live Blender:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/palace/build_palace_models.py -- [--preview DIR] [--export] [--only mech,pod,yacht] [--retex]
#   --preview renders Eevee stills into DIR (three-quarter, front, side; the mech and the pod also opened). --export writes the GLBs. --retex remakes the leather maps.
# Blender space here: metres, Z up, every model faces -Y, its own left is +X. glTF's Y-up conversion makes that the game's +Z forward, +Y up, +X the model's left.
# No node is turned at rest except the pod's petals (each yawed to face out over its hinge, so every petal opens with the same +X turn). Every hard edge is filleted in the geometry
# itself and the normals are face-weighted, so the speculars run along the edges. Style: gaudy new money in PS2-era Ratchet & Clank shapes: pearl enamel, gold, chrome, quilted cream leather.
# The quilted leather's maps are generated here (numpy) into F:/prog-godot-cache/palace/tex and packed into the GLBs.
import bpy, bmesh, math, os, sys, bisect, zlib, struct
import numpy as np
from mathutils import Vector as V, Matrix

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def opt(name, default=None):
    if name in ARGS:
        i = ARGS.index(name)
        if i + 1 < len(ARGS) and not ARGS[i + 1].startswith("--"):
            return ARGS[i + 1]
    return default


PREVIEW = opt("--preview")
EXPORT = "--export" in ARGS
ONLY = (opt("--only") or "mech,pod,yacht").split(",")
ROOT = "F:/prog-godot"
OUT = ROOT + "/assets/palace"
TEX = "F:/prog-godot-cache/palace/tex"
TAU = math.tau
I3 = Matrix.Identity(3)
SHARP = math.radians(46)      # faces meeting at more than this are split in the shading (fillets are built to stay under it)
UV_TILE = 0.36                # metres per UV unit where a part gets the default box projection


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# small maths

def sgnpow(x, p):
    return math.copysign(abs(x) ** p, x)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def newell(pts):
    n = V((0, 0, 0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n += V(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    return n


def frame(z, yref=(0, 1, 0)):
    """a right-handed 3x3 (columns X, Y, Z) with Z along z and Y as near yref as it can be"""
    z = V(z).normalized()
    yr = V(yref)
    y = yr - z * yr.dot(z)
    if y.length < 1e-6:
        y = V((0, 0, 1)) - z * z.z
        if y.length < 1e-6:
            y = V((0, 1, 0)) - z * z.y
    y.normalize()
    x = y.cross(z)
    return Matrix((x, y, z)).transposed()


def rot(axis, ang):
    return Matrix.Rotation(ang, 3, axis)


def mir(p, s):
    return V((p[0] * s, p[1], p[2]))


class Mono:
    """monotone cubic interpolation (Fritsch-Carlson): smooth through the knots, never overshooting them"""

    def __init__(self, xs, ys):
        self.x, self.y = list(xs), list(ys)
        n = len(xs)
        d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
        m = [d[0]] + [0.0 if d[i - 1] * d[i] <= 0 else (d[i - 1] + d[i]) * 0.5 for i in range(1, n - 1)] + [d[-1]]
        for i in range(n - 1):
            if d[i] == 0:
                m[i] = m[i + 1] = 0.0
                continue
            a, b = m[i] / d[i], m[i + 1] / d[i]
            s = a * a + b * b
            if s > 9:
                k = 3 / math.sqrt(s)
                m[i], m[i + 1] = k * a * d[i], k * b * d[i]
        self.m = m

    def __call__(self, x):
        xs, ys, m = self.x, self.y, self.m
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = bisect.bisect_right(xs, x) - 1
        h = xs[i + 1] - xs[i]
        t = (x - xs[i]) / h
        t2, t3 = t * t, t * t * t
        return (2 * t3 - 3 * t2 + 1) * ys[i] + (t3 - 2 * t2 + t) * h * m[i] + (-2 * t3 + 3 * t2) * ys[i + 1] + (t3 - t2) * h * m[i + 1]


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# a part: faces in model space, made into an object whose origin is its pivot

class Part:
    def __init__(self, name):
        self.name, self.v, self.f = name, [], []

    def vt(self, p):
        self.v.append(V(p))
        return len(self.v) - 1

    def face(self, idx, mat, uv=None, out=None, smooth=True):
        """one face; out, when given, is a direction it must face (the winding is turned to match)"""
        keep = [k for k in range(len(idx)) if idx[k] != idx[k - 1]]
        idx = [idx[k] for k in keep]
        if uv:
            uv = [uv[k] for k in keep]
        if len(set(idx)) < 3:
            return
        if out is not None and newell([self.v[i] for i in idx]).dot(V(out)) < 0:
            idx.reverse()
            if uv:
                uv = uv[::-1]
        self.f.append((idx, mat, uv, smooth))

    def tris(self):
        return sum(len(f[0]) - 2 for f in self.f)


MATS = {}
WORLD = {}     # object name -> its world matrix (kept here: parenting needs it before any depsgraph update)
TRI_LOG = []


def place(ob, pivot, R, parent):
    W = Matrix.Translation(V(pivot)) @ (R or I3).to_4x4()
    WORLD[ob.name] = W
    if parent is not None:
        ob.parent = parent
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.matrix_basis = WORLD[parent.name].inverted() @ W
    else:
        ob.matrix_basis = W


def obj(P, pivot=(0, 0, 0), parent=None, R=None):
    R = R or I3
    piv, Ri = V(pivot), R.transposed()
    me = bpy.data.meshes.new(P.name)
    bm = bmesh.new()
    bv = [bm.verts.new(Ri @ (p - piv)) for p in P.v]
    uvl = bm.loops.layers.uv.new("UVMap")
    slots = []
    for idx, mat, uv, sm in P.f:
        try:
            f = bm.faces.new([bv[i] for i in idx])
        except ValueError:
            continue
        if mat not in slots:
            slots.append(mat)
        f.material_index = slots.index(mat)
        f.smooth = sm
        f.normal_update()
        if uv:
            for lo, c in zip(f.loops, uv):
                lo[uvl].uv = c
        else:
            n = f.normal
            ax = max(range(3), key=lambda k: abs(n[k]))
            for lo in f.loops:
                c = [lo.vert.co[k] for k in range(3) if k != ax]
                lo[uvl].uv = (c[0] / UV_TILE, c[1] / UV_TILE)
    for e in bm.edges:
        lf = e.link_faces
        if len(lf) != 2 or lf[0].material_index != lf[1].material_index or lf[0].normal.angle(lf[1].normal, 0.0) > SHARP:
            e.smooth = False
    bm.to_mesh(me)
    bm.free()
    for m in slots:
        me.materials.append(MATS[m])
    ob = bpy.data.objects.new(P.name, me)
    bpy.context.scene.collection.objects.link(ob)
    place(ob, piv, R, parent)
    wn = ob.modifiers.new("weighted", "WEIGHTED_NORMAL")
    wn.keep_sharp = True
    wn.weight = 50
    tr = ob.modifiers.new("triangulate", "TRIANGULATE")       # after the normals are set: the exporter can then write tangents for every mesh
    tr.quad_method, tr.ngon_method = 'BEAUTY', 'BEAUTY'
    if hasattr(tr, "keep_custom_normals"):
        tr.keep_custom_normals = True
    TRI_LOG.append((P.name, P.tris()))
    return ob


def empty(name, pivot, parent=None, R=None, size=0.25):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = 'ARROWS'
    ob.empty_display_size = size
    bpy.context.scene.collection.objects.link(ob)
    place(ob, pivot, R, parent)
    return ob


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# primitives

def lathe(P, O, axis, prof, n=24, mat="gold", mats=None, a0=0.0, a1=None, yref=None, closed=False, uvt=None):
    """prof [(r, h)] turned about axis through O. The surface faces the right of the profile's direction drawn with r to the right and h up,
    so a solid's outline runs from its bottom centre out, up the side and in over the top. mats[i] paints segment i (None leaves it out)."""
    ax = V(axis).normalized()
    F = frame(ax, yref if yref is not None else ((0, 0, 1) if abs(ax.z) < 0.9 else (0, 1, 0)))
    X, Y, Z = F.col[0], F.col[1], F.col[2]
    O = V(O)
    full = a1 is None
    cols = n if full else n + 1
    a1v = a0 + TAU if full else a1
    cs = [(math.cos(a0 + (a1v - a0) * j / n), math.sin(a0 + (a1v - a0) * j / n)) for j in range(cols)]
    rings = []
    for r, h in prof:
        if abs(r) < 1e-7:
            k = P.vt(O + Z * h)
            rings.append([k] * cols)
        else:
            rings.append([P.vt(O + (X * c + Y * s) * r + Z * h) for c, s in cs])
    segs = len(prof) if closed else len(prof) - 1
    sl = [0.0]
    for i in range(1, len(prof)):
        sl.append(sl[-1] + math.hypot(prof[i][0] - prof[i - 1][0], prof[i][1] - prof[i - 1][1]))
    for i in range(segs):
        m = mats[i] if mats else mat
        if m is None:
            continue
        i2 = (i + 1) % len(prof)
        for j in range(n):
            j2 = (j + 1) % cols
            uv = None
            if uvt:
                ang = lambda jj: a0 + (a1v - a0) * jj / n
                uv = [(ang(jj) * prof[ii][0] / uvt, sl[ii] / uvt) for ii, jj in ((i, j), (i, j + 1), (i2, j + 1), (i2, j))]
            P.face([rings[i][j], rings[i][j2], rings[i2][j2], rings[i2][j]], m, uv=uv)
    return rings


def torus(P, O, axis, R, r, n=24, m=8, mat="gold", yref=None):
    prof = [(R + r * math.cos(TAU * k / m), r * math.sin(TAU * k / m)) for k in range(m)]
    lathe(P, O, axis, prof, n, mat, closed=True, yref=yref)


def sphere(P, c, r, n=24, rings=12, mat="chrome", axis=(0, 0, 1), squash=1.0):
    prof = [(r * math.sin(math.pi * i / rings), -r * squash * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
    lathe(P, c, axis, prof, n, mat)


def cyl(P, a, b, r, n=16, mat="chrome", r1=None, fil=0.0, caps=True, mats=None):
    """a cylinder from a to b, its rims filleted by fil"""
    a, b = V(a), V(b)
    L = (b - a).length
    r1 = r if r1 is None else r1
    f = min(fil, 0.4 * min(r, r1), 0.4 * L)
    prof = []
    if caps:
        prof.append((0.0, 0.0))
    if f > 0:
        prof += [(r - f, 0.0), (r - f * 0.29, f * 0.29), (r, f), (r1, L - f), (r1 - f * 0.29, L - f * 0.29), (r1 - f, L)]
    else:
        prof += [(r, 0.0), (r1, L)]
    if caps:
        prof.append((0.0, L))
    lathe(P, a, b - a, prof, n, mat, mats=mats)


def stud(P, p, n, r=0.022, h=0.014, mat="gold", sides=8):
    lathe(P, p, n, [(r, -0.006), (r, h * 0.35), (r * 0.72, h * 0.85), (0.0, h)], sides, mat)


def rbox(P, c, size, r=0.03, seg=2, mat="enamel", R=None, mats=None, deform=None):
    """a box of size (x, y, z) with its edges rounded by r; deform(p) bends it in its own frame first; mats {'+z': name, ...} paints the faces facing that way"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    for v in bm.verts:
        v.co = V((v.co.x * sx, v.co.y * sy, v.co.z * sz))
    r = min(r, 0.45 * min(size))
    if r > 1e-4:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=r, offset_type='OFFSET', segments=seg, profile=0.5, affect='EDGES', clamp_overlap=True)
    bm.normal_update()
    R = R or I3
    c = V(c)
    idx = {}
    for v in bm.verts:
        p = v.co.copy()
        if deform:
            p = deform(p)
        idx[v] = P.vt(c + R @ p)
    for f in bm.faces:
        m = mat
        if mats:
            for key, mm in mats.items():
                k = "xyz".index(key[1])
                if f.normal[k] * (1 if key[0] == "+" else -1) > 0.7:
                    m = mm
        P.face([idx[v] for v in f.verts], m)
    bm.free()


def catmull(pts, sub):
    pts = [V(p) for p in pts]
    if sub <= 1 or len(pts) < 3:
        return pts
    out, n = [], len(pts)
    for i in range(n - 1):
        p0, p1, p2, p3 = pts[max(0, i - 1)], pts[i], pts[i + 1], pts[min(n - 1, i + 2)]
        for j in range(sub):
            t = j / sub
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def tube(P, pts, radii, sides=12, mat="gold", cap0=True, cap1=True, sub=4, nref=None):
    """a round tube along pts (smoothed); radii is one radius or a list spread along its length"""
    path = catmull(pts, sub)
    n = len(path)
    if isinstance(radii, (int, float)):
        radii = [radii, radii]
    tans = [(path[min(n - 1, i + 1)] - path[max(0, i - 1)]).normalized() for i in range(n)]
    ref = V(nref) if nref else (V((0, 0, 1)) if abs(tans[0].z) < 0.9 else V((1, 0, 0)))
    nrm = (ref - tans[0] * ref.dot(tans[0])).normalized()
    total = sum((path[i + 1] - path[i]).length for i in range(n - 1)) or 1.0
    acc, rings = 0.0, []
    for i in range(n):
        if i > 0:
            acc += (path[i] - path[i - 1]).length
            axis = tans[i - 1].cross(tans[i])
            if axis.length > 1e-7:
                nrm = rot(axis.normalized(), tans[i - 1].angle(tans[i])) @ nrm
        fr = acc / total * (len(radii) - 1)
        k = min(len(radii) - 2, int(fr))
        r = radii[k] + (radii[k + 1] - radii[k]) * (fr - k)
        bi = tans[i].cross(nrm)
        rings.append([P.vt(path[i] + (nrm * math.cos(TAU * j / sides) + bi * math.sin(TAU * j / sides)) * r) for j in range(sides)])
    for i in range(n - 1):
        for j in range(sides):
            j2 = (j + 1) % sides
            P.face([rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]], mat)
    if cap0:
        P.face(list(reversed(rings[0])), mat)
    if cap1:
        P.face(rings[-1], mat)
    return path


def inset(pts, d, fixed=None):
    """the 2D polygon pts (counter-clockwise) with each edge moved in by d, except the edges fixed(p, q) says stay; miters clamped"""
    n, out = len(pts), []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        e0, e1 = p1 - p0, p2 - p1
        if e0.length < 1e-9 or e1.length < 1e-9:
            out.append(p1.copy())
            continue
        n0, n1 = V((-e0.y, e0.x)).normalized(), V((-e1.y, e1.x)).normalized()
        d0 = 0.0 if fixed and fixed(p0, p1) else d
        d1 = 0.0 if fixed and fixed(p1, p2) else d
        A, B = p1 + n0 * d0, p1 + n1 * d1
        den = e0.x * e1.y - e0.y * e1.x
        if abs(den) < 1e-9 * e0.length * e1.length:
            q = p1 + n1 * max(d0, d1)
        else:
            w = B - A
            q = A + e0 * ((w.x * e1.y - w.y * e1.x) / den)
        off = q - p1
        if off.length > 2.5 * max(d, 1e-9):
            q = p1 + off.normalized() * 2.5 * d
        out.append(q)
    return out


def on_axis(p, q):
    return abs(p.x) < 1e-6 and abs(q.x) < 1e-6


def prism(P, pts, O, X, Y, depth, ch=0.0, mat="gold", side=None, back=None, fixed=on_axis, z0=-0.004, uvt=None):
    """the 2D outline pts (counter-clockwise, metres) in the plane (X, Y) at O, raised depth along X x Y, a chamfer ch round its top"""
    X, Y, O = V(X), V(Y), V(O)
    N = X.cross(Y)
    pts = [V((p[0], p[1])) for p in pts]
    to3 = lambda q, z: O + X * q.x + Y * q.y + N * z
    tp = inset(pts, ch, fixed) if ch > 0 else pts
    bot = [P.vt(to3(p, z0)) for p in pts]
    mid = [P.vt(to3(p, depth - ch)) for p in pts] if ch > 0 else None
    top = [P.vt(to3(p, depth)) for p in tp]
    uv = [(p.x / uvt, p.y / uvt) for p in tp] if uvt else None
    P.face(top, mat, uv=uv)
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        if ch > 0:
            P.face([bot[i], bot[j], mid[j], mid[i]], side or mat)
            P.face([mid[i], mid[j], top[j], top[i]], mat)
        else:
            P.face([bot[i], bot[j], top[j], top[i]], side or mat)
    if back:
        P.face(list(reversed(bot)), back, uv=[(p.x / uvt, p.y / uvt) for p in reversed(pts)] if uvt else None)


def arc(cx, cy, r, a0, a1, n):
    return [V((cx + r * math.cos(a0 + (a1 - a0) * k / n), cy + r * math.sin(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def rrect_half(hx, hy, r, seg=4, r_in=None):
    """the right half (x >= 0) of a rounded rectangle, from its bottom centre round to its top centre"""
    r = min(r, hx * 0.99, hy * 0.99)
    pts = [V((0.0, -hy))]
    pts += arc(hx - r, -hy + r, r, -math.pi / 2, 0.0, seg)
    pts += arc(hx - r, hy - r, r, 0.0, math.pi / 2, seg)
    pts.append(V((0.0, hy)))
    return pts


def full_from_half(half):
    """a whole symmetric outline (counter-clockwise) from its right half running bottom centre to top centre"""
    left = [V((-p.x, p.y)) for p in reversed(half) if abs(p.x) > 1e-9]
    right = [p for p in half]
    return right + left


def ring_half(outer_half, inner_half):
    """a C-shaped half band between two right halves (both bottom to top): outer up, inner back down"""
    return [p for p in outer_half] + [p for p in reversed(inner_half)]


def mirror2(pts):
    return [V((-p.x, p.y)) for p in reversed(pts)]


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# lofted surfaces: superellipse sections along a spine. h runs along the frame's Z (metres), t round the section: 0 at the frame's -Y side, pi/2 at +X.
# The mesh, the armour plates (filleted, raised off it) and the bands all come off the same surface, so they fit it exactly.

class Surf:
    def __init__(self, O, F, secs):
        """secs: (h, half width along X, half depth along Y, centre x, centre y, squareness 2 = ellipse .. 6 = nearly a box[, squareness of the +Y half])"""
        self.O, self.F = V(O), F
        hs = [s[0] for s in secs]
        self.h0, self.h1 = hs[0], hs[-1]
        self.fn = [Mono(hs, [s[k] for s in secs]) for k in range(1, len(secs[0]))]

    def par(self, h):
        return [f(h) for f in self.fn]

    def local(self, t, h):
        p = self.par(h)
        a, b, cx, cy, e = p[:5]
        if len(p) > 5 and math.cos(t) < 0:
            e = p[5]
        k = 2.0 / e
        return V((cx + a * sgnpow(math.sin(t), k), cy - b * sgnpow(math.cos(t), k), h))

    def base(self, t, h):
        return self.O + self.F @ self.local(t, h)

    def nrm(self, t, h):
        e = 1e-4
        dt = self.base(t + e, h) - self.base(t - e, h)
        lo, hi = max(self.h0, h - e), min(self.h1, h + e)
        dh = self.base(t, hi) - self.base(t, lo)
        n = dt.cross(dh)
        if n.length < 1e-12:
            return (self.base(t, h) - (self.O + self.F @ V((0, 0, h)))).normalized()
        return n.normalized()

    def pt(self, t, h, off=0.0):
        p = self.base(t, h)
        return p + self.nrm(t, h) * off if off else p

    def tan(self, t, h):
        """unit tangents round (t) and along (h) the surface"""
        e = 1e-4
        dt = (self.base(t + e, h) - self.base(t - e, h)).normalized()
        n = self.nrm(t, h)
        return dt, n.cross(dt).normalized()

    def t_of_x(self, h, x, back=False):
        a, b, cx, cy, e = self.par(h)[:5]
        t = math.asin(sgnpow(max(-1.0, min(1.0, (x - cx) / a)), e / 2.0))
        return math.pi - t if back else t

    def speed(self, t, h):
        """metres per radian of t, metres per unit of h"""
        e = 1e-3
        a = (self.base(t + e, h) - self.base(t - e, h)).length / (2 * e)
        lo, hi = max(self.h0, h - e), min(self.h1, h + e)
        b = (self.base(t, hi) - self.base(t, lo)).length / max(hi - lo, 1e-9)
        return max(a, 1e-6), max(b, 1e-6)

    def mesh(self, P, ts, rows, mat="rubber", skip=None, mats=None, cap0=None, cap1=None):
        """the surface over the closed loop ts (ascending in [0, tau)) and rows [h or (h, offset)]; skip(t, h) drops a quad; mats(t, h, row) paints one"""
        rows = [r if isinstance(r, tuple) else (r, 0.0) for r in rows]
        grid = [[P.vt(self.pt(t, h, off)) for t in ts] for h, off in rows]
        n = len(ts)
        for i in range(len(rows) - 1):
            hm = (rows[i][0] + rows[i + 1][0]) * 0.5
            for j in range(n):
                j2 = (j + 1) % n
                dt = (ts[j2] - ts[j]) % TAU
                tm = (ts[j] + dt * 0.5) % TAU
                if skip and skip(tm, hm):
                    continue
                m = mats(tm, hm, i) if mats else mat
                if m:
                    P.face([grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]], m)
        if cap0:
            P.face(list(reversed(grid[0])), cap0)
        if cap1:
            P.face(grid[-1], cap1)
        return grid

    def plate(self, P, t0, t1, h0, h1, th=0.035, fil=0.014, nt=8, nh=4, mat="enamel", side=None, sink=0.012, uvt=None, seg=1):
        """an armour plate over [t0, t1] x [h0, h1], raised th off the surface, its border chamfered (seg 1) or filleted (seg 2)"""
        tc, hc = (t0 + t1) * 0.5, (h0 + h1) * 0.5
        st, sh = self.speed(tc, hc)
        fil = min(fil, th * 0.9)
        ft = min(fil / st, (t1 - t0) * 0.3)
        fh = min(fil / sh, (h1 - h0) * 0.3)
        ti = [t0 + ft + (t1 - t0 - 2 * ft) * k / nt for k in range(nt + 1)]
        hi = [h0 + fh + (h1 - h0 - 2 * fh) * k / nh for k in range(nh + 1)]
        top = [[P.vt(self.pt(t, h, th)) for t in ti] for h in hi]

        def uvof(t, h):
            return ((t - tc) * st / uvt, (h - hc) * sh / uvt) if uvt else None
        for i in range(nh):
            for j in range(nt):
                q = [(i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)]
                P.face([top[a][b] for a, b in q], mat, uv=[uvof(ti[b], hi[a]) for a, b in q] if uvt else None)
        loop = []      # (t, h, outward dt sign, outward dh sign, top vertex)
        for j in range(nt):
            loop.append((ti[j], hi[0], -1 if j == 0 else 0, -1, top[0][j]))
        for i in range(nh):
            loop.append((ti[nt], hi[i], 1, -1 if i == 0 else 0, top[i][nt]))
        for j in range(nt, 0, -1):
            loop.append((ti[j], hi[nh], 1 if j == nt else 0, 1, top[nh][j]))
        for i in range(nh, 0, -1):
            loop.append((ti[0], hi[i], -1, 1 if i == nh else 0, top[i][0]))
        rings = []
        for t, h, sx, sy, g in loop:
            ta, ha = t + sx * ft * 0.707, h + sy * fh * 0.707
            tb, hb = t + sx * ft, h + sy * fh
            a = P.vt(self.pt(ta, ha, th - fil * 0.293)) if fil > 0 and seg > 1 else g
            b = P.vt(self.pt(tb, hb, th - fil)) if fil > 0 else g
            r = P.vt(self.pt(tb, hb, -sink))
            od = self.pt(tb, hb) - self.pt(t, h)
            if od.length < 1e-9:
                od = self.pt(t + sx * 0.01, h + sy * 0.01) - self.pt(t, h)
            rings.append((g, a, b, r, od.normalized() + self.nrm(t, h) * 0.3))
        L = len(rings)
        for k in range(L):
            g0, a0, b0, r0, o0 = rings[k]
            g1, a1, b1, r1, o1 = rings[(k + 1) % L]
            o = o0 + o1
            if fil > 0:
                if seg > 1:
                    P.face([g0, g1, a1, a0], mat, out=o)
                P.face([a0, a1, b1, b0], mat, out=o)
            P.face([b0, b1, r1, r0], side or mat, out=o)

    def band(self, P, h0, h1, th=0.03, fil=0.012, ts=None, n=40, mat="gold", sink=0.012):
        """a raised band all round between heights h0 and h1, filleted at both edges"""
        ts = ts or [TAU * k / n for k in range(n)]
        st, sh = self.speed(0.0, (h0 + h1) * 0.5)
        fil = min(fil, th * 0.9)
        fh = min(fil / sh, (h1 - h0) * 0.3)
        if fil > 0:
            rows = [(h0, -sink), (h0, th - fil), (h0 + fh, th), (h1 - fh, th), (h1, th - fil), (h1, -sink)]
        else:
            rows = [(h0, -sink), (h0, th), (h1, th), (h1, -sink)]
        self.mesh(P, ts, rows, mat)

    def stripe(self, P, h0, h1, tf, wf, th=0.05, n=24, mat="gold", sink=0.02):
        """a raised strip along the surface from h0 to h1, centred on t = tf(h), wf(h) radians wide, its long edges chamfered"""
        hs = [h0 + (h1 - h0) * k / n for k in range(n + 1)]
        cols = [(-1.0, -sink), (-0.7, th), (0.7, th), (1.0, -sink)]
        grid = [[P.vt(self.pt(tf(h) + c * wf(h) * 0.5, h, off)) for c, off in cols] for h in hs]
        for i in range(n):
            for j in range(3):
                P.face([grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]], mat, out=self.nrm(tf(hs[i]), hs[i]))
        P.face([grid[0][j] for j in range(4)], mat, out=self.tan(tf(h0), h0)[1] * -1)
        P.face([grid[-1][j] for j in range(4)], mat, out=self.tan(tf(h1), h1)[1])

    def place(self, t, h, off=0.0):
        """a point on the surface and its frame: (point, X round, Y along, N out)"""
        dt, dh = self.tan(t, h)
        return self.pt(t, h, off), dt, dh, self.nrm(t, h)


def limb(A, B, secs, yref=(0, 1, 0)):
    """a surface whose spine runs from A to B (h in metres from A), its front (t = 0) toward -yref"""
    A, B = V(A), V(B)
    return Surf(A, frame(B - A, yref), secs)


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# the Fenrir crest: a gold-rimmed heater shield with a gold wolf's head, front on, its eyes lit. Outlines are right halves, bottom centre to top centre, in shield heights.

SHIELD_HALF = [(0.0, -0.62), (0.2, -0.52), (0.36, -0.34), (0.45, -0.1), (0.48, 0.18), (0.48, 0.52), (0.36, 0.52), (0.3, 0.58), (0.0, 0.58)]
SHIELD_IN_HALF = [(0.0, -0.53), (0.17, -0.45), (0.31, -0.29), (0.39, -0.07), (0.415, 0.18), (0.415, 0.46), (0.33, 0.46), (0.27, 0.51), (0.0, 0.51)]
WOLF_HALF = [(0.0, -0.44), (0.045, -0.43), (0.075, -0.37), (0.1, -0.27), (0.135, -0.19), (0.215, -0.15), (0.2, -0.08), (0.29, -0.04), (0.235, 0.03), (0.32, 0.09), (0.24, 0.13),
             (0.255, 0.23), (0.2, 0.25), (0.205, 0.43), (0.15, 0.33), (0.085, 0.26), (0.0, 0.25)]
MASK_HALF = [(0.0, -0.42), (0.04, -0.4), (0.065, -0.3), (0.08, -0.18), (0.075, -0.06), (0.05, 0.04), (0.045, 0.14), (0.07, 0.2), (0.0, 0.22)]
EYE_R = [(0.07, 0.03), (0.18, 0.06), (0.2, 0.11), (0.085, 0.08)]
EAR_R = [(0.16, 0.27), (0.195, 0.26), (0.195, 0.38)]
NOSE_HALF = [(0.0, -0.44), (0.045, -0.43), (0.06, -0.38), (0.035, -0.35), (0.0, -0.35)]


def crest(P, O, X, Y, size, half=0, depth=0.02, field=None, detail=None, z0=-0.004, gold="gold"):
    """the crest, size metres tall, on the plane (X, Y) at O facing X x Y; half +1 / -1 builds only that side (the chest doors split it).
    detail 2: chamfered, with nose and inner ears; 1: flat-topped, with them; 0: flat, without (by default from the size)"""
    sc = lambda pts: [V((p[0] * size, p[1] * size)) for p in pts]
    sides = [1, -1] if half == 0 else [half]
    if detail is None:
        detail = 2 if size >= 0.5 else (1 if size >= 0.28 else 0)
    small = detail == 0
    ch = depth * 0.45 if detail == 2 else 0.0
    for s in sides:
        def S(pts):
            q = sc(pts)
            return q if s > 0 else mirror2(q)
        rim = ring_half(sc(SHIELD_HALF), sc(SHIELD_IN_HALF))
        prism(P, rim if s > 0 else mirror2(rim), O, X, Y, depth, ch, gold, z0=z0)
        if field:
            prism(P, S(SHIELD_IN_HALF), O, X, Y, depth * 0.3, 0.0, field, z0=z0)
    if half == 0:
        head, mask = full_from_half(sc(WOLF_HALF)), full_from_half(sc(MASK_HALF))
        prism(P, head, O, X, Y, depth * 1.3, ch, gold, z0=z0)
        prism(P, mask, O, X, Y, depth * 1.75, ch * 0.8, gold)
        if not small:
            prism(P, full_from_half(sc(NOSE_HALF)), O, X, Y, depth * 2.0, ch * 0.5, "rubber")
    else:
        q = sc(WOLF_HALF) if half > 0 else mirror2(sc(WOLF_HALF))
        prism(P, q, O, X, Y, depth * 1.3, ch, gold, z0=z0)
        q = sc(MASK_HALF) if half > 0 else mirror2(sc(MASK_HALF))
        prism(P, q, O, X, Y, depth * 1.75, ch * 0.8, gold)
        q = sc(NOSE_HALF) if half > 0 else mirror2(sc(NOSE_HALF))
        prism(P, q, O, X, Y, depth * 2.0, ch * 0.5, "rubber")
    for s in sides:
        eye = sc(EYE_R) if s > 0 else mirror2(sc(EYE_R))
        prism(P, eye, O, X, Y, depth * 1.42, 0.0, "glow")
        if not small:
            ear = sc(EAR_R) if s > 0 else mirror2(sc(EAR_R))
            prism(P, ear, O, X, Y, depth * 1.38, 0.0, "rubber")


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# materials

def write_png(path, rgb):
    """rgb: H x W x 3 uint8, row 0 the top of the picture"""
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def leather_maps():
    """quilted cream leather, one tile of 4 x 4 diamonds: albedo (with its own seam shading) and an OpenGL normal map"""
    os.makedirs(TEX, exist_ok=True)
    pa, pn = TEX + "/leather_cream_albedo.png", TEX + "/leather_cream_normal.png"
    if os.path.exists(pa) and os.path.exists(pn) and "--retex" not in ARGS:
        return pa, pn
    N, n = 1024, 4
    u = (np.arange(N) + 0.5) / N
    U, W = np.meshgrid(u, u)                       # row index = v, bottom up (flipped when written)
    a, b = (U + W) * n, (U - W) * n
    fa, fb = a - np.floor(a), b - np.floor(b)
    da, db = np.minimum(fa, 1 - fa), np.minimum(fb, 1 - fb)
    pillow = (np.sin(np.pi * fa) * np.sin(np.pi * fb)) ** 0.42
    cr = np.sqrt(da * da + db * db)
    dimple = np.clip(1 - cr / 0.24, 0, 1) ** 2
    button = np.clip(1 - cr / 0.06, 0, 1) ** 0.5
    seam = np.minimum(da, db)
    along = np.where(da < db, fb, fa)              # position along the nearest seam, for the stitches' dashes
    stitch = ((np.abs(seam - 0.075) < 0.012) & (np.mod(along * 14, 1.0) < 0.62)).astype(np.float64)
    h = pillow - 0.42 * dimple + 0.34 * button - 0.04 * stitch
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * N / n
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * N / n
    k = 0.11
    nx, ny, nz = -gx * k, -gy * k, np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    nmap = np.stack([nx / ln, ny / ln, nz / ln], -1) * 0.5 + 0.5
    base = np.array([0.93, 0.86, 0.73])
    shade = 0.62 + 0.38 * np.clip(pillow, 0, 1) ** 0.7 - 0.18 * dimple
    alb = base[None, None, :] * shade[..., None]
    alb = alb * (1 - button[..., None] * 0.25) + button[..., None] * np.array([0.08, 0.06, 0.03])
    alb = alb * (1 - stitch[..., None]) + stitch[..., None] * np.array([0.99, 0.95, 0.86])
    write_png(pa, np.flipud(np.clip(alb * 255 + 0.5, 0, 255).astype(np.uint8)))
    write_png(pn, np.flipud(np.clip(nmap * 255 + 0.5, 0, 255).astype(np.uint8)))
    return pa, pn


MAT_DEF = {   # key: (material name, base colour (linear), metallic, roughness, emission colour, emission strength, alpha)
    "enamel": ("enamel_white", (0.80, 0.775, 0.725), 0.0, 0.17, None, 0, 1),
    "gold": ("gold", (1.0, 0.69, 0.30), 1.0, 0.22, None, 0, 1),
    "satin": ("gold_satin", (1.0, 0.7, 0.32), 1.0, 0.38, None, 0, 1),         # the yacht's gold: broad sun highlights, so it still reads gold against black space
    "chrome": ("chrome", (0.64, 0.645, 0.66), 1.0, 0.07, None, 0, 1),
    "leather": ("leather_cream", (1.0, 1.0, 1.0), 0.0, 0.52, None, 0, 1),
    "rubber": ("rubber_black", (0.016, 0.015, 0.018), 0.0, 0.66, None, 0, 1),
    "glow": ("glow_warm", (1.0, 0.88, 0.72), 0.0, 0.4, (1.0, 0.84, 0.64), 4.0, 1),
    "core": ("core_glow", (1.0, 0.85, 0.55), 0.0, 0.3, (1.0, 0.8, 0.45), 6.0, 1),
    "glass": ("glass", (0.85, 0.88, 0.9), 0.0, 0.03, None, 0, 0.14),
    "shield": ("heat_shield", (0.16, 0.09, 0.05), 0.75, 0.62, None, 0, 1),
    "soot": ("heat_shield_soot", (0.03, 0.022, 0.018), 0.3, 0.8, None, 0, 1),
    "engine": ("engine_glow", (0.55, 0.78, 1.0), 0.0, 0.3, (0.38, 0.66, 1.0), 6.0, 1),
    "navred": ("nav_red", (1.0, 0.1, 0.06), 0.0, 0.3, (1.0, 0.06, 0.03), 8.0, 1),
    "navgreen": ("nav_green", (0.1, 1.0, 0.25), 0.0, 0.3, (0.05, 1.0, 0.2), 8.0, 1),
    "navwhite": ("nav_white", (1.0, 1.0, 1.0), 0.0, 0.3, (1.0, 0.97, 0.92), 8.0, 1),
    "window": ("window_dark", (0.012, 0.012, 0.018), 0.0, 0.05, None, 0, 1),
    "lit": ("window_lit", (1.0, 0.72, 0.42), 0.0, 0.3, (1.0, 0.66, 0.34), 2.5, 1),
    "skin": ("preview_skin", (0.72, 0.52, 0.45), 0.0, 0.45, None, 0, 1),        # the previews' stand-in head only
}


def make_materials():
    MATS.clear()
    pa, pn = leather_maps()
    for key, (name, col, met, rough, ecol, estr, alpha) in MAT_DEF.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        m.use_backface_culling = True
        nt = m.node_tree
        bs = next(nd for nd in nt.nodes if nd.type == 'BSDF_PRINCIPLED')
        bs.inputs["Base Color"].default_value = (*col, 1.0)
        bs.inputs["Metallic"].default_value = met
        bs.inputs["Roughness"].default_value = rough
        if ecol:
            bs.inputs["Emission Color"].default_value = (*ecol, 1.0)
            bs.inputs["Emission Strength"].default_value = estr
        if alpha < 1:
            bs.inputs["Alpha"].default_value = alpha
            m.surface_render_method = 'BLENDED'
        if key == "leather":
            ti = nt.nodes.new("ShaderNodeTexImage")
            ti.image = bpy.data.images.load(pa)
            nt.links.new(ti.outputs["Color"], bs.inputs["Base Color"])
            tn = nt.nodes.new("ShaderNodeTexImage")
            tn.image = bpy.data.images.load(pn)
            tn.image.colorspace_settings.name = "Non-Color"
            nm = nt.nodes.new("ShaderNodeNormalMap")
            nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
            nt.links.new(nm.outputs["Normal"], bs.inputs["Normal"])
        m.diffuse_color = (*col, 1.0)
        MATS[key] = m


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# the mech. Its layout: every joint, from which every part is placed (Blender space, the left side; the right mirrors x)

HIP = V((0.62, 0.0, 2.2))
KNEE = V((0.8, -0.12, 1.28))
ANKLE = V((0.95, 0.0, 0.46))
PELVIS = V((0.0, 0.0, 2.3))
WAIST = V((0.0, 0.0, 2.62))
CORE = V((0.0, -0.3, 3.62))
SOCKET = V((0.0, 0.02, 4.8))
SHOULDER = V((1.0, 0.02, 4.0))
ARM = V((1.42, 0.02, 3.86))
ELBOW = V((1.54, -0.04, 3.08))
WRIST = V((1.54, -1.0, 3.04))
PAUL = V((1.46, 0.02, 0.0))                         # the pauldron's centre line
POD = V((1.47, 0.1, 4.53))
POD_SIZE = (0.56, 0.8, 0.38)
OPEN_X, OPEN_Z0, OPEN_Z1 = 0.42, 3.2, 4.04         # the core's opening: half width, bottom, top
OPEN_ZC = (OPEN_Z0 + OPEN_Z1) * 0.5
CHEST_FRONT = -0.70                                 # the chest's flat front, where the bezel and the doors sit
DOOR_Y = CHEST_FRONT - 0.075                        # the doors' front face
EXH = V((0.0, 0.7, 3.32))
CANNON_AX = V((-1.54, 0.0, 3.03))                   # the gatling's axis (it runs along -y)

TORSO = [  # z, half width, half depth, centre x, centre y, squareness. The front stays flat at y = -0.70 from 3.15 to 4.12 for the doors; the pecs jut out over them.
    (2.86, 0.40, 0.36, 0, 0.03, 2.2),
    (3.00, 0.64, 0.52, 0, 0.00, 2.8),
    (3.15, 0.82, 0.66, 0, -0.04, 3.4),
    (3.45, 0.93, 0.69, 0, -0.01, 3.8),
    (3.80, 1.00, 0.70, 0, 0.00, 4.0),
    (4.12, 1.05, 0.69, 0, -0.01, 4.2),
    (4.28, 1.07, 0.72, 0, -0.07, 4.4),
    (4.42, 1.03, 0.67, 0, -0.04, 4.0),
    (4.53, 0.86, 0.56, 0, 0.00, 3.2),
    (4.6, 0.62, 0.47, 0, 0.02, 2.6),
    (4.63, 0.5, 0.44, 0, 0.02, 2.2),
]

PAULDRON = [  # z, half width, half depth, centre x, centre y, squareness: a dome over each shoulder
    (3.64, 0.45, 0.5, 0, 0.0, 3.0),
    (3.7, 0.54, 0.6, 0, 0.0, 3.2),
    (3.9, 0.58, 0.63, 0, 0.0, 3.4),
    (4.18, 0.57, 0.61, 0, 0.0, 3.4),
    (4.4, 0.48, 0.53, 0, 0.0, 3.0),
    (4.52, 0.35, 0.4, 0, 0.0, 2.6),
    (4.57, 0.18, 0.22, 0, 0.0, 2.2),
]


def mech_torso():
    P = Part("torso")
    S = Surf(V((0, 0, 0)), I3, TORSO)
    tx = lambda x, z=OPEN_ZC: S.t_of_x(z, x)
    hole = OPEN_X + 0.05
    th = tx(hole)
    ts = sorted(set([round(TAU * k / 32, 6) for k in range(32)] + [th, TAU - th, tx(0.25), TAU - tx(0.25)]))
    rows = sorted(set([s[0] for s in TORSO] + [OPEN_Z0 - 0.05, OPEN_Z1 + 0.05] + [round(2.86 + (4.63 - 2.86) * k / 9, 4) for k in range(10)]))

    def skip(t, h):
        x = S.local(t, h).x
        return math.cos(t) > 0 and abs(x) < hole and OPEN_Z0 - 0.06 < h < OPEN_Z1 + 0.06
    S.mesh(P, ts, rows, "rubber", skip=skip, cap0="rubber", cap1="rubber")

    # the core's cavity: a quilted-leather box behind the opening, lit round its mouth
    hx, hz = OPEN_X + 0.006, (OPEN_Z1 - OPEN_Z0) * 0.5 + 0.006
    rr = full_from_half(rrect_half(hx, hz, 0.1, 3))
    yf, yb = CHEST_FRONT + 0.02, 0.05
    f_ = [P.vt((p.x, yf, OPEN_ZC + p.y)) for p in rr]
    b_ = [P.vt((p.x, yb, OPEN_ZC + p.y)) for p in rr]
    for i in range(len(rr)):
        j = (i + 1) % len(rr)
        mid = (rr[i] + rr[j]) * 0.5
        P.face([f_[i], f_[j], b_[j], b_[i]], "leather", out=V((-mid.x, 0, -mid.y)))
    P.face(b_, "leather", out=V((0, -1, 0)), uv=[(p.x / 0.36, p.y / 0.36) for p in rr])
    for z in (OPEN_ZC + hz - 0.009, OPEN_ZC - hz + 0.009):                                        # light strips along the mouth's top and bottom
        rbox(P, (0, yf + 0.07, z), ((OPEN_X - 0.1) * 2, 0.03, 0.018), 0.006, 1, "glow")
    for s in (1, -1):
        rbox(P, (s * (hx - 0.009), yf + 0.07, OPEN_ZC), (0.018, 0.03, (hz - 0.1) * 2), 0.006, 1, "glow")
    # the core's mount: a chrome ring on four gold arms
    torus(P, CORE, (0, 1, 0), 0.37, 0.022, 24, 5, "chrome")
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        d = V((math.cos(a), 0, math.sin(a)))
        p0 = CORE + d * 0.38
        p1 = V((math.copysign(hx - 0.01, d.x), CORE.y + 0.12, OPEN_ZC + math.copysign(hz - 0.01, d.z)))
        tube(P, [p0, p1], 0.022, 6, "gold", sub=1)
    # the bezel round the opening: a gold frame standing proud of the chest
    out_h = rrect_half(OPEN_X + 0.1, (OPEN_Z1 - OPEN_Z0) * 0.5 + 0.1, 0.2, 4)
    in_h = rrect_half(OPEN_X, (OPEN_Z1 - OPEN_Z0) * 0.5, 0.1, 4)
    band = ring_half(out_h, in_h)
    for s in (1, -1):
        prism(P, band if s > 0 else mirror2(band), (0, CHEST_FRONT + 0.05, OPEN_ZC), (1, 0, 0), (0, 0, 1), 0.13, 0.022, "gold")
    for s in (1, -1):
        for z in (OPEN_Z0 + 0.12, OPEN_ZC, OPEN_Z1 - 0.12):
            stud(P, V((s * (OPEN_X + 0.05), CHEST_FRONT - 0.08, z)), (0, -1, 0), 0.02, 0.014, "chrome", 6)
    # armour: pecs, ribs, flanks, back, the yoke over the shoulders; the gaps between them are the panel lines
    for s in (1, -1):
        def T(t):
            return t if s > 0 else -t

        def plate(t0, t1, h0, h1, th=0.045, fil=0.018, nt=10, nh=5, mat="enamel"):
            S.plate(P, min(T(t0), T(t1)), max(T(t0), T(t1)), h0, h1, th, fil, nt, nh, mat)
        t_rib = tx(OPEN_X + 0.13, OPEN_ZC)
        plate(tx(0.036, 4.3), 1.25, 4.18, 4.47, 0.05, 0.02, 10, 5)           # the pec
        plate(tx(0.05, 4.2), 1.2, 4.192, 4.212, 0.064, 0.006, 6, 1, "gold")    # a gold edge along its foot
        plate(t_rib, 1.24, 3.07, 4.13, 0.045, 0.018, 8, 7)                   # the rib beside the bezel
        plate(1.3, 2.14, 2.98, 4.36, 0.045, 0.018, 8, 7)                     # the flank under the arm
        plate(0.3, 1.3, 4.5, 4.6, 0.035, 0.012, 8, 2)                        # the yoke
        plate(2.2, 2.9, 4.44, 4.56, 0.035, 0.012, 6, 2)                      # the yoke's back
        for k in range(3):                                                    # three gold speed lines on the rib (art deco)
            z = 3.42 + k * 0.075
            plate(tx(OPEN_X + 0.2, z), 1.1, z, z + 0.026, 0.058, 0.008, 5, 1, "gold")
        plate(tx(0.07, 4.17), 1.14, 4.155, 4.176, 0.024, 0.0, 10, 1, "glow")   # a warm light line under the pec
        plate(1.27, 1.29, 3.1, 4.3, 0.03, 0.0, 1, 6, "glow")                 # and one down the flank's seam
    S.plate(P, TAU / 2 - 0.86, TAU / 2 + 0.86, 3.0, 4.4, 0.045, 0.018, 12, 6, "enamel")                # the back
    t_tie = tx(0.032, 4.3)
    S.plate(P, -t_tie, t_tie, 4.17, 4.45, 0.065, 0.012, 2, 4, "gold")                                   # the gold tie between the pecs
    S.band(P, 2.88, 3.03, 0.03, 0.012, n=32, mat="gold")                                                # the belt line
    for k in range(4):
        p, X, Y, N = S.place(0.0, 4.23 + k * 0.08, 0.065)
        stud(P, p, N, 0.02, 0.016, "chrome", 6)
    # the waist: a narrow ribbed gold column into the pelvis
    prof, mats = [], []
    z = 2.46
    for k in range(5):
        prof += [(0.3, z), (0.345, z + 0.022), (0.345, z + 0.068), (0.3, z + 0.09)]
        mats += ["gold"] * 3 + ["rubber"]
        z += 0.09
    lathe(P, (0, 0.02, 0), (0, 0, 1), prof, 18, mats=mats[:-1])
    return P


def mech_collar():
    P = Part("collar")
    c = SOCKET
    prof = [(0.44, -0.3), (0.44, -0.2), (0.455, -0.17), (0.455, -0.12), (0.49, -0.1), (0.52, -0.07), (0.52, -0.04), (0.505, -0.018), (0.47, -0.01), (0.38, -0.01),
            (0.33, 0.01), (0.3, 0.035), (0.275, 0.045), (0.25, 0.04), (0.21, 0.015), (0.18, -0.005), (0.17, -0.03), (0.17, -0.2)]
    mats = ["gold", "chrome", "chrome", "chrome"] + ["gold"] * 13
    lathe(P, c, (0, 0, 1), prof, 24, mats=mats)
    lathe(P, c, (0, 0, 1), [(0.165, -0.14), (0.165, -0.02), (0.14, -0.015), (0.0, -0.015)], 20, "chrome")       # the socket's floor, where the neck stump plugs in
    for k in range(4):
        a = TAU * k / 4
        stud(P, c + V((math.cos(a) * 0.09, math.sin(a) * 0.09, -0.015)), (0, 0, 1), 0.016, 0.02, "gold", 5)
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        stud(P, c + V((math.cos(a) * 0.48, math.sin(a) * 0.48, -0.012)), (0, 0, 1), 0.018, 0.012, "chrome", 5)
    return P


def mech_dome():
    P = Part("dome")
    c = SOCKET
    n = 10
    prof = [(0.4 * math.cos(math.pi / 2 * k / n), 0.4 * math.sin(math.pi / 2 * k / n)) for k in range(n + 1)]
    lathe(P, c, (0, 0, 1), prof, 32, "glass")
    lathe(P, c, (0, 0, 1), [(0.385, -0.01), (0.44, -0.01), (0.445, 0.0), (0.445, 0.025), (0.43, 0.04), (0.398, 0.045), (0.398, 0.03)], 28, "gold")
    lathe(P, c + V((0, 0, 0.398)), (0, 0, 1), [(0.04, -0.01), (0.04, 0.0), (0.03, 0.02), (0.012, 0.03), (0.008, 0.06), (0.0, 0.075)], 12, "gold")   # the finial
    hinge = c + V((0, 0.445, 0.01))
    cyl(P, hinge + V((-0.09, 0, 0)), hinge + V((0.09, 0, 0)), 0.026, 10, "gold", fil=0.006)
    return P, hinge


def mech_core():
    P = Part("core")
    sphere(P, CORE, 0.32, 20, 10, "core")
    torus(P, CORE, (0, 0, 1), 0.33, 0.014, 28, 5, "gold")
    for a in (math.pi / 4, -math.pi / 4):
        torus(P, CORE, rot((0, 0, 1), a) @ V((1, 0, 0)), 0.335, 0.01, 24, 4, "chrome")
    return P


def mech_door(s):
    """a chest door: s = 1 the mech's left (its hinge on the outer edge at +x), -1 the right"""
    name = "chest_door_L" if s > 0 else "chest_door_R"
    P = Part(name)
    w, hz, gap = OPEN_X - 0.006, (OPEN_Z1 - OPEN_Z0) * 0.5 - 0.006, 0.004
    out = [V((gap, -hz)), *arc(w - 0.094, -hz + 0.094, 0.094, -math.pi / 2, 0, 4), *arc(w - 0.094, hz - 0.094, 0.094, 0, math.pi / 2, 4), V((gap, hz))]
    if s < 0:
        out = mirror2(out)
    fixed = lambda p, q: abs(abs(p.x) - gap) < 1e-6 and abs(abs(q.x) - gap) < 1e-6
    yb = CHEST_FRONT
    prism(P, out, (0, yb, OPEN_ZC), (1, 0, 0), (0, 0, 1), yb - DOOR_Y, 0.012, "enamel", back="leather", fixed=fixed, z0=0.0, uvt=0.3)
    crest(P, V((0, DOOR_Y, OPEN_ZC + 0.02)), (1, 0, 0), (0, 0, 1), 0.7, half=s, depth=0.016)
    hinge = V((s * (OPEN_X + 0.01), DOOR_Y + 0.012, OPEN_ZC))
    for dz in (-0.28, 0.28):
        cyl(P, hinge + V((0, 0, dz - 0.07)), hinge + V((0, 0, dz + 0.07)), 0.022, 10, "gold", fil=0.005)
    return P, hinge


def mech_pelvis():
    P = Part("pelvis")
    rbox(P, (0, 0.02, 2.33), (1.02, 0.72, 0.5), 0.14, 2, "rubber", deform=lambda p: V((p.x * lerp(0.62, 1.0, p.z / 0.5 + 0.5), p.y * lerp(0.8, 1.0, p.z / 0.5 + 0.5), p.z)))
    Rf = rot((1, 0, 0), 0.16)              # the front plate leans forward at the top, tucking in between the legs
    fc = V((0, -0.34, 2.28))
    rbox(P, fc, (0.74, 0.16, 0.54), 0.07, 3, "enamel", R=Rf, deform=lambda p: V((p.x * lerp(0.42, 1.0, p.z / 0.54 + 0.5), p.y, p.z)))
    rbox(P, fc + Rf @ V((0, -0.02, 0.23)), (0.76, 0.16, 0.07), 0.025, 2, "gold", R=Rf)
    crest(P, fc + Rf @ V((0, -0.08, 0.04)), (1, 0, 0), Rf @ V((0, 0, 1)), 0.3, 0, 0.016, detail=1)
    rbox(P, (0, 0.38, 2.34), (0.76, 0.16, 0.44), 0.07, 2, "enamel", R=rot((1, 0, 0), -0.2), deform=lambda p: V((p.x * lerp(0.6, 1.0, p.z / 0.44 + 0.5), p.y, p.z)))
    lathe(P, (0, 0.02, 2.5), (0, 0, 1), [(0.44, 0.0), (0.46, 0.02), (0.46, 0.07), (0.44, 0.09), (0.33, 0.09), (0.33, 0.05)], 24, "gold")      # the ring the waist turns in
    for s in (1, -1):
        cyl(P, mir((0.4, 0, HIP.z), s), mir((0.56, 0, HIP.z), s), 0.2, 16, "chrome", fil=0.02, caps=False)
        lathe(P, mir((0.56, 0, HIP.z), s), (s, 0, 0), [(0.2, -0.03), (0.17, -0.01), (0.12, 0.0), (0.0, 0.0)], 16, "gold")
        R = rot((0, 1, 0), -s * 0.22)       # the tasset's foot flares out
        tc = mir((0.88, -0.02, 2.2), s)
        rbox(P, tc, (0.12, 0.7, 0.6), 0.05, 2, "enamel", R=R, deform=lambda p: V((p.x, p.y * lerp(0.72, 1.0, p.z / 0.6 + 0.5), p.z)))
        rbox(P, tc + R @ V((0, 0, -0.29)), (0.15, 0.52, 0.05), 0.02, 2, "gold", R=R)
        rbox(P, tc + R @ V((s * 0.064, 0, 0.1)), (0.012, 0.44, 0.014), 0.005, 1, "glow", R=R)
        for dy in (-0.2, 0.0, 0.2):
            stud(P, tc + R @ V((s * 0.06, dy, 0.2)), R @ V((s, 0, 0)), 0.018, 0.012, "gold", 6)
    return P


def mech_thigh(s):
    P = Part("thigh_L" if s > 0 else "thigh_R")
    A, B = mir(HIP, s), mir(KNEE, s)
    sphere(P, A, 0.21, 16, 8, "chrome")
    S = limb(A, B, [(0.02, 0.21, 0.21, 0, 0.0, 2.4), (0.2, 0.3, 0.29, 0, 0.0, 2.8), (0.55, 0.3, 0.3, 0, 0.02, 3.0), (0.8, 0.24, 0.25, 0, 0.0, 2.6), (0.9, 0.17, 0.18, 0, 0.0, 2.2)])
    S.mesh(P, [TAU * k / 18 for k in range(18)], [0.02 + 0.88 * k / 6 for k in range(7)], "rubber", cap0="rubber", cap1="rubber")
    X = S.F.col[0]
    o = 1 if X.x * s > 0 else -1               # which way t turns toward the mech's outside
    S.plate(P, min(-2.1 * o, 0.85 * o), max(-2.1 * o, 0.85 * o), 0.22, 0.76, 0.05, 0.02, 10, 4, "enamel")
    S.plate(P, min(-0.75 * o, -0.95 * o), max(-0.75 * o, -0.95 * o), 0.28, 0.7, 0.07, 0.01, 1, 4, "gold")      # a gold stripe down the front
    S.plate(P, math.pi - 0.62 * o - 0.55, math.pi - 0.62 * o + 0.55, 0.26, 0.72, 0.045, 0.018, 6, 4, "enamel")       # the hamstring plate
    S.band(P, 0.12, 0.2, 0.035, 0.012, n=24, mat="gold")
    S.plate(P, -0.5, 0.5, 0.79, 0.83, 0.03, 0.0, 6, 1, "glow")
    p0, p1 = S.pt(o * 1.55, 0.2, 0.06), S.pt(o * 1.55, 0.8, 0.05)        # a chrome piston down the inside
    cyl(P, p0, p0 + (p1 - p0) * 0.55, 0.05, 10, "rubber", fil=0.01)
    cyl(P, p0 + (p1 - p0) * 0.45, p1, 0.03, 8, "chrome", fil=0.006)
    return P


def mech_shin(s):
    P = Part("shin_L" if s > 0 else "shin_R")
    A, B = mir(KNEE, s), mir(ANKLE, s)
    X = frame(B - A).col[0]
    cyl(P, A - X * 0.24, A + X * 0.24, 0.17, 16, "chrome", fil=0.02, caps=False)            # the knee joint
    for d in (-1, 1):
        lathe(P, A + X * (0.24 * d), X * d, [(0.17, -0.025), (0.15, -0.01), (0.11, 0.0), (0.0, 0.0)], 16, "gold")
    S = limb(A, B, [(0.1, 0.27, 0.26, 0, 0.0, 2.6), (0.28, 0.34, 0.36, 0, 0.05, 3.0), (0.55, 0.36, 0.38, 0, 0.05, 3.2), (0.72, 0.33, 0.33, 0, 0.02, 3.0),
                    (0.8, 0.29, 0.29, 0, 0.0, 2.6), (0.84, 0.24, 0.24, 0, 0.0, 2.4)])
    S.mesh(P, [TAU * k / 20 for k in range(20)], [0.1 + 0.74 * k / 7 for k in range(8)], "rubber", cap0="rubber", cap1="rubber")
    S.plate(P, -1.05, 1.05, 0.22, 0.7, 0.05, 0.02, 8, 4, "enamel")                # the shin guard
    for d in (1, -1):
        S.plate(P, min(d * 1.18, d * 2.55), max(d * 1.18, d * 2.55), 0.24, 0.66, 0.045, 0.018, 6, 3, "enamel")      # the calf's sides
        S.plate(P, min(d * 1.1, d * 1.13), max(d * 1.1, d * 1.13), 0.24, 0.68, 0.03, 0.0, 1, 5, "glow")              # light lines down the guard's edges
    S.plate(P, 2.66, TAU - 2.66, 0.2, 0.68, 0.05, 0.018, 4, 5, "gold")             # a gold calf plate
    S.band(P, 0.72, 0.78, 0.04, 0.014, n=24, mat="gold")
    # the knee guard: a pointed gold plate over the joint, the crest on it
    kp, kx, ky, kn = S.place(0.0, 0.16, 0.0)
    up = -ky
    across = up.cross(kn).normalized()
    guard = [V((0.0, -0.2)), V((0.17, -0.16)), V((0.21, 0.06)), V((0.12, 0.24)), V((0.0, 0.31))]
    prism(P, full_from_half(guard), kp + kn * 0.03 + up * 0.06, across, up, 0.08, 0.025, "gold")
    crest(P, kp + kn * 0.11 + up * 0.07, across, up, 0.22, 0, 0.012)
    return P


def boot(q):
    """the foot's shape, in its own space (x across, y forward-negative from under the ankle, z up): the top falls toward the toe, which narrows"""
    f = smooth((-0.2 - q.y) / 0.52)
    z = 0.2 + (q.z - 0.2) * lerp(1.0, 0.24, f) if q.z > 0.2 else q.z
    return V((q.x * lerp(1.0, 0.84, f), q.y, z))


def mech_foot(s):
    P = Part("foot_L" if s > 0 else "foot_R")
    A = mir(ANKLE, s)
    sphere(P, A, 0.17, 16, 8, "chrome")
    b = V((A.x, 0.0, 0.0))

    def shaped(c):
        return lambda p: boot(p + c) - c
    c = V((0, -0.14, 0.3))
    rbox(P, b + c, (0.72, 1.2, 0.42), 0.12, 2, "enamel", deform=shaped(c))                                     # the boot
    c = V((0, -0.58, 0.3))
    rbox(P, b + c, (0.75, 0.38, 0.45), 0.1, 2, "gold", deform=shaped(c))                                      # its gold toe cap
    c = V((0, -0.16, 0.055))
    rbox(P, b + c, (0.8, 1.26, 0.11), 0.04, 2, "rubber", deform=lambda p: V((p.x * lerp(1.0, 0.86, smooth((-0.2 - p.y - 0.16) / 0.52)), p.y, p.z)))   # the sole
    rbox(P, b + V((0, 0.5, 0.22)), (0.4, 0.12, 0.28), 0.05, 2, "chrome")                                     # the heel spur
    for d in (1, -1):
        rbox(P, A + V((d * 0.25, 0.0, -0.06)), (0.08, 0.36, 0.3), 0.035, 2, "gold")                            # ankle guards
        lathe(P, A + V((d * 0.29, 0, -0.04)), (d, 0, 0), [(0.1, -0.01), (0.08, 0.0), (0.0, 0.0)], 10, "chrome")
        rbox(P, b + V((d * 0.362, 0.1, 0.24)), (0.012, 0.46, 0.022), 0.005, 1, "glow")                          # side lights
    for k in range(3):
        stud(P, b + V((0, -0.47 + k * 0.1, boot(V((0, -0.47 + k * 0.1, 0.52))).z)), (0, 0, 1), 0.02, 0.014, "chrome", 6)
    return P


def mech_shoulder(s):
    P = Part("shoulder_L" if s > 0 else "shoulder_R")
    O = mir(SHOULDER, s)
    cyl(P, mir((0.82, 0.02, 4.0), s), O + V((s * 0.14, 0, 0)), 0.17, 12, "chrome", caps=False)
    S = Surf(mir(PAUL, s), I3, PAULDRON)
    S.mesh(P, [TAU * k / 32 for k in range(32)], [PAULDRON[0][0]] + [3.66 + (4.57 - 3.66) * k / 8 for k in range(1, 9)], "enamel", cap0="enamel", cap1="enamel")
    S.band(P, 3.66, 3.75, 0.035, 0.014, n=32, mat="gold")
    S.band(P, 3.77, 3.785, 0.014, 0.0, n=32, mat="glow")
    to = s * math.pi / 2                       # the outer side
    S.plate(P, to - 1.0, to + 1.0, 3.92, 4.38, 0.045, 0.018, 8, 4, "enamel")
    S.plate(P, to - 1.04, to + 1.04, 4.4, 4.44, 0.05, 0.01, 10, 1, "gold")
    p, X, Y, N = S.place(to, 4.15, 0.045)
    crest(P, p, X, Y, 0.34, 0, 0.016, detail=1)
    for k in (-1, 1):
        q, X2, Y2, N2 = S.place(to + k * 0.82, 4.15, 0.045)
        stud(P, q, N2, 0.022, 0.016, "gold", 6)
    lathe(P, mir(POD, s) + V((0, 0, -0.1)), (0, 0, 1), [(0.2, 0.0), (0.2, 0.08), (0.17, 0.1), (0.0, 0.1)], 16, "chrome")    # the pod's turret ring
    return P


POD_SLOPE = math.atan2(0.13, POD_SIZE[1])          # the pod's top falls 9 cm to its front, so the missiles leave up and forward


def pod_top(p):
    """the pod's casing with its top sloped (its own frame, z up from its base centre)"""
    w, d, h = POD_SIZE
    if p.z > 0:
        return V((p.x * lerp(0.9, 1.0, p.z / h + 0.5), p.y, p.z + (p.y / d - 0.5) * 0.13 * (p.z / (h * 0.5))))
    return V((p.x * lerp(0.9, 1.0, p.z / h + 0.5), p.y, p.z))


def mech_pod(s):
    P = Part("pod_L" if s > 0 else "pod_R")
    O = mir(POD, s)
    w, d, h = POD_SIZE
    Rt = rot((1, 0, 0), POD_SLOPE)
    rbox(P, O + V((0, 0, h * 0.5)), (w, d, h), 0.06, 2, "enamel", deform=pod_top)
    rbox(P, O + V((0, 0, 0.07)), (w * 0.9 + 0.016, d + 0.016, 0.03), 0.012, 2, "gold")
    rbox(P, O + V((0, -0.01, h - 0.065)), (w + 0.012, d - 0.04, 0.03), 0.012, 2, "gold", R=Rt)
    rbox(P, O + V((0, 0.0, h - 0.07)), (w - 0.06, d - 0.06, 0.02), 0.01, 1, "rubber", R=Rt)
    for k in range(3):                                   # a chrome grille on its nose
        rbox(P, O + V((0, -d * 0.5 - 0.004, 0.11 + k * 0.06)), (w * 0.62, 0.02, 0.025), 0.008, 1, "chrome")
    for e in (1, -1):                                    # gold fins down its flanks
        rbox(P, O + V((e * (w * 0.47 + 0.02), 0.12, h * 0.62)), (0.03, d * 0.56, 0.05), 0.012, 1, "gold")
    rbox(P, O + V((s * (w * 0.47 + 0.004), 0.0, h * 0.45)), (0.012, d - 0.2, 0.012), 0.004, 1, "glow")
    rbox(P, O + V((0, -d * 0.5 - 0.004, h * 0.42)), (w * 0.6, 0.012, 0.012), 0.004, 1, "glow")
    up = Rt @ V((0, 0, 1))
    for ix in (-0.5, 0.5):          # the six tubes: chrome mouths, dark bores, gold missile noses
        for iy in (-1, 0, 1):
            c = O + V((ix * 0.25, iy * 0.235, h - 0.065 + iy * 0.235 * 0.13 / d + 0.004))
            lathe(P, c, up, [(0.105, -0.004), (0.105, 0.012), (0.095, 0.02), (0.075, 0.02), (0.075, -0.03), (0.0, -0.03)], 10, mats=["chrome"] * 4 + ["rubber"], yref=(0, 1, 0))
            lathe(P, c - up * 0.03, up, [(0.06, 0.0), (0.05, 0.03), (0.026, 0.055), (0.0, 0.065)], 6, "gold", yref=(0, 1, 0))
    return P


def mech_pod_lid(s):
    P = Part("pod_lid_L" if s > 0 else "pod_lid_R")
    O = mir(POD, s)
    w, d, h = POD_SIZE
    Rt = rot((1, 0, 0), POD_SLOPE)
    c = O + V((0, 0, h - 0.065)) + Rt @ V((0, 0, 0.046))
    rbox(P, c, (w + 0.02, d + 0.03, 0.09), 0.04, 3, "enamel", R=Rt, deform=lambda p: V((p.x, p.y, p.z + (0.03 if p.z > 0 else 0) * (1 - (2 * p.x / w) ** 2))))
    rbox(P, c + Rt @ V((0, -0.02, 0.07)), (0.07, d - 0.12, 0.03), 0.012, 2, "gold", R=Rt)
    for dx in (-1, 1):
        rbox(P, c + Rt @ V((dx * (w * 0.5 + 0.006), 0, 0.0)), (0.02, d - 0.05, 0.05), 0.008, 1, "gold", R=Rt)
    hinge = c + Rt @ V((0, d * 0.5 + 0.02, -0.04))
    cyl(P, hinge + V((-w * 0.4, 0, 0)), hinge + V((w * 0.4, 0, 0)), 0.03, 10, "gold", fil=0.008)
    return P, hinge


def mech_upper_arm(s):
    P = Part("upper_arm_L" if s > 0 else "upper_arm_R")
    A, B = mir(ARM, s), mir(ELBOW, s)
    sphere(P, A, 0.21, 16, 8, "chrome")
    S = limb(A, B, [(0.08, 0.2, 0.2, 0, 0, 2.4), (0.3, 0.26, 0.25, 0, 0, 2.8), (0.58, 0.25, 0.24, 0, 0, 2.8), (0.72, 0.19, 0.19, 0, 0, 2.4)])
    S.mesh(P, [TAU * k / 18 for k in range(18)], [0.08 + 0.64 * k / 5 for k in range(6)], "rubber", cap0="rubber", cap1="rubber")
    X = S.F.col[0]
    o = 1 if X.x * s > 0 else -1
    S.plate(P, min(-2.7 * o, 0.9 * o), max(-2.7 * o, 0.9 * o), 0.2, 0.6, 0.05, 0.02, 10, 3, "enamel")      # the bicep's shell, front and outside
    S.band(P, 0.62, 0.68, 0.035, 0.012, n=24, mat="gold")
    for d in (1, -1):          # the elbow's clevis: gold cheeks either side of the forearm's lug
        rbox(P, B + V((d * 0.21, 0.0, 0.1)), (0.07, 0.28, 0.38), 0.03, 2, "gold")
    return P


def mech_forearm(s):
    P = Part("forearm_L" if s > 0 else "forearm_R")
    A, B = mir(ELBOW, s), mir(WRIST, s)
    cyl(P, A + V((-0.17, 0, 0)), A + V((0.17, 0, 0)), 0.15, 14, "chrome", fil=0.02)
    S = limb(A, B, [(0.1, 0.18, 0.17, 0, 0, 2.4), (0.24, 0.25, 0.22, 0, 0.02, 2.8), (0.55, 0.32, 0.28, 0, 0.0, 3.2), (0.84, 0.35, 0.31, 0, 0.0, 3.2), (0.93, 0.31, 0.28, 0, 0, 2.8)],
             yref=(0, 0, -1))
    S.mesh(P, [TAU * k / 20 for k in range(20)], [0.1 + 0.83 * k / 7 for k in range(8)], "rubber", cap0="rubber", cap1="rubber")
    S.plate(P, -1.3, 1.3, 0.24, 0.78, 0.05, 0.02, 10, 4, "enamel")
    S.plate(P, -0.035, 0.035, 0.28, 0.74, 0.056, 0.0, 1, 5, "glow")
    S.band(P, 0.8, 0.92, 0.045, 0.016, n=24, mat="gold")
    for k in range(5):
        p, X, Y, N = S.place(-math.pi * 0.5 * s, 0.32 + k * 0.1, 0.0)
        stud(P, p, N, 0.02, 0.014, "gold", 6)
    return P


def mech_fist(s):
    """a big clenched fist punching forward (-y): back of the hand up, four fingers folded down the front, gold knuckle-dusters across them"""
    P = Part("fist_L" if s > 0 else "fist_R")
    W = mir(WRIST, s)
    rbox(P, W + V((0, -0.2, 0.04)), (0.54, 0.4, 0.44), 0.1, 2, "enamel", mats={"-z": "chrome"})        # the hand
    rbox(P, W + V((0, -0.2, 0.27)), (0.36, 0.28, 0.04), 0.015, 2, "gold")                               # a gold plate on its back
    crest(P, W + V((0, -0.2, 0.29)), (1, 0, 0), (0, -1, 0), 0.2, 0, 0.012)
    for k in range(4):
        x = (k - 1.5) * 0.128
        rbox(P, W + V((x, -0.47, 0.03)), (0.118, 0.17, 0.32), 0.045, 2, "enamel")                       # proximal: down the front
        rbox(P, W + V((x, -0.42, -0.19)), (0.112, 0.24, 0.12), 0.045, 2, "enamel")                      # middle: folded back under
        rbox(P, W + V((x, -0.47, 0.03)) + V((0, 0, -0.1)), (0.124, 0.176, 0.03), 0.01, 1, "gold")       # a gold ring on each
    rbox(P, W + V((0, -0.57, 0.15)), (0.56, 0.08, 0.16), 0.03, 2, "gold")                               # the knuckle-duster
    for k in range(4):
        x = (k - 1.5) * 0.128
        sphere(P, W + V((x, -0.612, 0.15)), 0.05, 8, 4, "gold", axis=(0, -1, 0), squash=0.75)
    rbox(P, W + V((-s * 0.08, -0.55, -0.12)), (0.3, 0.12, 0.13), 0.05, 2, "enamel", R=rot((0, 0, 1), -s * 0.12))   # the thumb across the front
    rbox(P, W + V((-s * 0.25, -0.38, -0.12)), (0.12, 0.2, 0.14), 0.05, 2, "enamel")
    cyl(P, W + V((0, 0.02, 0.04)), W + V((0, -0.06, 0.04)), 0.2, 14, "rubber", caps=False)                # the wrist
    return P


def mech_cannon():
    P = Part("cannon_R")
    A = mir(ELBOW, -1)
    ax = CANNON_AX
    cyl(P, A + V((-0.17, 0, 0)), A + V((0.17, 0, 0)), 0.15, 14, "chrome", fil=0.02)
    rbox(P, A + V((0, -0.16, -0.02)), (0.28, 0.28, 0.26), 0.06, 2, "gold")
    # the housing: a gold drum along -y with chrome cooling rings, the barrels coming out of its shroud
    prof = [(0.0, 0.16), (0.2, 0.175), (0.33, 0.26), (0.33, 0.42), (0.35, 0.435), (0.35, 0.465), (0.33, 0.48), (0.33, 0.6), (0.35, 0.615), (0.35, 0.645), (0.33, 0.66),
            (0.33, 0.86), (0.37, 0.9), (0.37, 0.98), (0.33, 1.01), (0.21, 1.01), (0.21, 0.97)]
    mats = ["gold"] * 3 + ["chrome"] * 3 + ["gold"] + ["chrome"] * 3 + ["gold"] * 6
    lathe(P, ax, (0, -1, 0), prof, 24, mats=mats)
    dc = V((ax.x, -0.52, ax.z - 0.38))         # the ammo drum under it, the crest on its outer face
    cyl(P, dc + V((-0.18, 0, 0)), dc + V((0.18, 0, 0)), 0.22, 20, "gold", fil=0.03, caps=False)
    for d in (1, -1):
        lathe(P, dc + V((d * 0.18, 0, 0)), (d, 0, 0), [(0.22, -0.002), (0.16, 0.0), (0.13, 0.004), (0.0, 0.004)], 20, mats=["gold", "chrome", "chrome"])
    crest(P, dc + V((-0.184, 0, 0)), (0, -1, 0), (0, 0, 1), 0.22, 0, 0.012)
    rbox(P, V((ax.x, -0.56, ax.z + 0.31)), (0.03, 0.46, 0.02), 0.008, 1, "glow")
    for k in range(5):
        rbox(P, V((ax.x, -0.3 - k * 0.11, ax.z + 0.28)), (0.36, 0.035, 0.05), 0.012, 1, "chrome")        # heat sink fins on top
    return P, ax


def mech_barrels(ax):
    P = Part("barrels_R")
    y0, y1 = -0.62, -1.7
    L = y0 - y1
    for k in range(6):
        a = TAU * k / 6
        c = ax + V((math.cos(a) * 0.13, 0, math.sin(a) * 0.13))
        lathe(P, V((c.x, y0, c.z)), (0, -1, 0), [(0.048, 0.0), (0.048, L - 0.02), (0.043, L), (0.024, L), (0.024, L - 0.03), (0.0, L - 0.03)], 8,
              mats=["chrome", "chrome", "chrome", "rubber", "rubber"])
    cyl(P, V((ax.x, y0, ax.z)), V((ax.x, y1 + 0.1, ax.z)), 0.065, 8, "chrome", caps=False)
    for y in (-1.1, -1.62):
        cyl(P, V((ax.x, y + 0.04, ax.z)), V((ax.x, y - 0.04, ax.z)), 0.2, 16, "gold", fil=0.012)
    return P


def mech_exhaust():
    """a gold blower bolted to the back, chrome-finned, its two stacks rising past the shoulders with lit tips"""
    P = Part("exhaust")
    c = V((0.0, 0.84, 3.72))
    rbox(P, c, (0.66, 0.3, 0.7), 0.1, 2, "gold", deform=lambda p: V((p.x * lerp(0.82, 1.0, p.z / 0.7 + 0.5), p.y, p.z)))
    for k in range(6):
        rbox(P, c + V((0, 0.13, -0.26 + k * 0.1)), (0.5 - 0.02 * abs(k - 2.5), 0.08, 0.03), 0.012, 1, "chrome")
    rbox(P, c + V((0, -0.12, -0.3)), (0.4, 0.12, 0.12), 0.04, 2, "chrome")
    for s in (1, -1):
        pts = [mir((0.2, 0.86, 4.0), s), mir((0.22, 0.89, 4.45), s), mir((0.25, 0.95, 5.02), s)]
        tube(P, pts, [0.075, 0.082, 0.09], 12, "gold", cap0=True, cap1=False, sub=3)
        top = V(pts[-1])
        d = (V(pts[-1]) - V(pts[-2])).normalized()
        lathe(P, top, d, [(0.09, -0.01), (0.12, 0.06), (0.125, 0.09), (0.11, 0.09), (0.085, 0.03), (0.0, 0.03)], 12, mats=["gold", "gold", "gold", "gold", "core"])
        tube(P, [mir((0.2, 0.86, 4.04), s), mir((0.215, 0.88, 4.36), s)], 0.098, 12, "chrome", sub=1)
        for zz in (4.12, 4.28):
            lathe(P, mir((0.205, 0.866 + (zz - 4.0) * 0.067, zz), s), (0, 0.06, 1), [(0.1, -0.012), (0.106, 0.0), (0.1, 0.012)], 12, "gold")
    return P


def build_mech():
    root = empty("mech_root", (0, 0, 0), size=0.6)
    pelvis = obj(mech_pelvis(), PELVIS, root)
    torso = obj(mech_torso(), WAIST, pelvis)
    obj(mech_core(), CORE, torso)
    for s in (1, -1):
        P, hinge = mech_door(s)
        obj(P, hinge, torso)
    collar = obj(mech_collar(), SOCKET, torso)
    empty("head_socket", SOCKET, collar, size=0.15)
    P, hinge = mech_dome()
    obj(P, hinge, collar)
    obj(mech_exhaust(), EXH, torso)
    for s in (1, -1):
        sh = obj(mech_shoulder(s), mir(SHOULDER, s), torso)
        pod = obj(mech_pod(s), mir(POD, s), sh)
        P, hinge = mech_pod_lid(s)
        obj(P, hinge, pod)
        ua = obj(mech_upper_arm(s), mir(ARM, s), sh)
        if s > 0:
            fa = obj(mech_forearm(s), mir(ELBOW, s), ua)
            obj(mech_fist(s), mir(WRIST, s), fa)
        else:
            P, ax = mech_cannon()
            can = obj(P, mir(ELBOW, s), ua)
            obj(mech_barrels(ax), V((ax.x, -0.62, ax.z)), can)
            empty("muzzle_R", V((ax.x, -1.73, ax.z)), can, size=0.2)
        th = obj(mech_thigh(s), mir(HIP, s), pelvis)
        sn = obj(mech_shin(s), mir(KNEE, s), th)
        obj(mech_foot(s), mir(ANKLE, s), sn)
    return root


def stand_in_head():
    """preview only (never exported): Sambo's little rubber head on its neck stump in the socket, to judge the dome"""
    P = Part("stand_in_head")
    c = SOCKET + V((0, 0, 0.17))
    sphere(P, c, 0.13, 20, 10, "skin", squash=1.15)
    cyl(P, SOCKET + V((0, 0, -0.02)), SOCKET + V((0, 0, 0.06)), 0.07, 12, "skin")
    for d in (1, -1):
        sphere(P, c + V((d * 0.05, -0.115, 0.03)), 0.022, 10, 5, "rubber")
    return obj(P, SOCKET)


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# the drop pod: a Faberge egg in pearl and gold. Its scorched heat-shield base lands first on retro thrusters and four legs; the cap blows; four petals fall
# open like a flower, quilted cream leather inside lit along their edges; the mech stands on the floor in the middle. Petal k's centre faces azimuth k * 90 degrees
# (petal_1 the front, -y; petal_2 the pod's left, +x; petal_3 the back; petal_4 the right).

POD_FLOOR = 0.3                 # the deck the mech stands on
POD_HINGE = (2.45, 1.0)         # the petals' hinge line: radius, height
POD_TOP = 6.46                  # where the petals meet the cap
POD_SHELL = [(2.42, 1.0), (2.53, 1.5), (2.595, 2.2), (2.6, 3.0), (2.56, 3.8), (2.43, 4.5), (2.22, 5.1), (1.91, 5.6), (1.5, 6.0), (1.02, 6.3), (0.6, POD_TOP)]
PETAL_TH = 0.12
PETAL_GAP = 0.012               # half the gap between two petals, metres


def pod_dir(psi):
    """the outward direction at azimuth psi (0 the front, -y; pi/2 the pod's left, +x)"""
    return V((math.sin(psi), -math.cos(psi), 0.0))


def shell_profiles():
    pts = catmull([V((r, z, 0)) for r, z in POD_SHELL], 2)
    out = [(p.x, p.y) for p in pts]
    inn = []
    for i, (r, z) in enumerate(out):
        a, b = V(out[max(0, i - 1)]), V(out[min(len(out) - 1, i + 1)])
        d = (b - a).normalized()
        inn.append((r - d.y * PETAL_TH, z + d.x * PETAL_TH))
    return out, inn


SHELL_R = Mono([z for r, z in POD_SHELL], [r for r, z in POD_SHELL])


def pod_petal(k):
    phi = k * math.pi / 2
    P = Part("petal_%d" % (k + 1))
    out, inn = shell_profiles()
    m = len(out)
    ga = PETAL_GAP / 2.5
    a0, a1 = phi - math.pi / 4 + ga - math.pi / 2, phi + math.pi / 4 - ga - math.pi / 2       # lathe angles (0 = +x)
    n = 12
    O = V((0, 0, 0))
    ro = lathe(P, O, (0, 0, 1), out, n, "enamel", a0=a0, a1=a1)
    ri = lathe(P, O, (0, 0, 1), list(reversed(inn)), n, "leather", a0=a0, a1=a1, uvt=0.9)
    tang = lambda a: V((-math.sin(a), math.cos(a), 0))
    for i in range(m - 1):                                   # the rims: both sides, then the foot and the top
        P.face([ro[i][0], ro[i + 1][0], ri[m - 2 - i][0], ri[m - 1 - i][0]], "gold", out=-tang(a0))
        P.face([ro[i][n], ro[i + 1][n], ri[m - 2 - i][n], ri[m - 1 - i][n]], "gold", out=tang(a1))
    for j in range(n):
        P.face([ro[0][j], ro[0][j + 1], ri[m - 1][j + 1], ri[m - 1][j]], "gold", out=V((0, 0, -1)))
        P.face([ro[m - 1][j], ro[m - 1][j + 1], ri[0][j + 1], ri[0][j]], "gold", out=V((0, 0, 1)))
    # gold piping down both seams, gold bands round the egg, studs on the equator band
    for a in (a0 + 0.012, a1 - 0.012):
        path = [V((math.cos(a) * r, math.sin(a) * r, z)) for r, z in out[::2]] + ([V((math.cos(a) * out[-1][0], math.sin(a) * out[-1][0], out[-1][1]))] if len(out) % 2 == 0 else [])
        tube(P, path, 0.032, 6, "gold", sub=1)
    # the Faberge trellis: a gold X over each panel between the bands, a jewel where they cross
    on = lambda a, z, lift: V((math.cos(a), math.sin(a), 0)) * (SHELL_R(z) + lift) + V((0, 0, z))
    for z0, z1 in ((1.42, 2.82), (3.18, 4.62)):
        for e in (0, 1):
            path = [on(lerp(a0 + 0.04, a1 - 0.04, (q / 8) if e == 0 else 1 - q / 8), lerp(z0, z1, q / 8), 0.012) for q in range(9)]
            tube(P, path, 0.022, 5, "gold", sub=1, cap0=False, cap1=False)
        am, zm = (a0 + a1) * 0.5, (z0 + z1) * 0.5
        d = V((math.cos(am), math.sin(am), 0))
        if not (k in (0, 2) and z0 > 3):
            stud(P, on(am, zm, 0.02), d, 0.07, 0.06, "chrome", 6)
            lathe(P, on(am, zm, 0.0), d, [(0.095, -0.01), (0.095, 0.025), (0.075, 0.035), (0.0, 0.035)], 10, "gold")
    for z0, z1, hgt in ((2.86, 3.14, 0.035), (1.3, 1.38, 0.025), (4.66, 4.74, 0.025)):
        prof = [(SHELL_R(z0) - 0.01, z0 - 0.02), (SHELL_R(z0) + hgt, z0), (SHELL_R(z1) + hgt, z1), (SHELL_R(z1) - 0.01, z1 + 0.02)]
        lathe(P, O, (0, 0, 1), prof, n, "gold", a0=a0, a1=a1)
    for q in range(4):
        a = a0 + (a1 - a0) * (q + 0.5) / 4
        d = V((math.cos(a), math.sin(a), 0))
        stud(P, d * (SHELL_R(3.0) + 0.03) + V((0, 0, 3.0)), d, 0.05, 0.045, "chrome", 6)
    # warm light along the inside edges
    for a in (a0 + 0.02, a1 - 0.035):
        lathe(P, O, (0, 0, 1), [(r - 0.006, z) for r, z in reversed(inn[1:-2])], 2, "glow", a0=a, a1=a + 0.015)
    lathe(P, O, (0, 0, 1), [(inn[2][0] - 0.006, inn[2][1] + 0.04), (inn[2][0] - 0.006, inn[2][1])], n, "glow", a0=a0 + 0.04, a1=a1 - 0.04)
    # the crest, front and back
    if k in (0, 2):
        d = pod_dir(phi)
        X = V((math.cos(phi), math.sin(phi), 0))
        crest(P, d * (SHELL_R(3.62) + 0.035) + V((0, 0, 3.62)), X, (0, 0, 1), 1.5, 0, 0.05, field="enamel", z0=-0.16)
    # its hinge barrel
    hinge = pod_dir(phi) * POD_HINGE[0] + V((0, 0, POD_HINGE[1]))
    t = X = V((math.cos(phi), math.sin(phi), 0))
    cyl(P, hinge - t * 0.45, hinge + t * 0.45, 0.06, 10, "gold", fil=0.012)
    return P, hinge, phi


def pod_base():
    P = Part("pod_base")
    prof = [(0.0, 0.2), (0.8, 0.185), (1.5, 0.15), (2.0, 0.12), (2.3, 0.13), (2.45, 0.2), (2.52, 0.3), (2.54, 0.45), (2.54, 0.55),
            (2.5, 0.62), (2.5, 0.85), (2.47, 0.95), (2.42, 1.0), (2.3, 1.0), (2.26, 0.98), (2.26, 0.34), (2.22, POD_FLOOR), (0.0, POD_FLOOR)]
    mats = ["shield"] * 6 + ["gold"] * 3 + ["enamel"] * 2 + ["gold"] * 3 + ["enamel", "chrome", "rubber"]
    lathe(P, (0, 0, 0), (0, 0, 1), prof, 48, mats=mats)
    for r0, r1 in ((1.35, 1.4), (2.0, 2.06)):                               # gold rings inlaid in the deck
        lathe(P, (0, 0, POD_FLOOR), (0, 0, 1), [(r1, 0.0), (r1, 0.012), (r0, 0.012), (r0, 0.0)], 32, "gold")
    for r0, z0 in ((0.6, 0.19), (1.2, 0.17), (1.75, 0.135)):                # seams between the heat shield's ablative rings
        lathe(P, (0, 0, 0), (0, 0, 1), [(r0 - 0.02, z0 - 0.004), (r0 + 0.02, z0 - 0.006)], 32, "soot")
    lathe(P, (0, 0, 0), (0, 0, 1), [(2.506, 0.72), (2.506, 0.75)], 48, "glow")                        # a band of warm light round the base
    crest(P, V((0, 0, POD_FLOOR + 0.012)), (1, 0, 0), (0, 1, 0), 1.3, 0, 0.02, detail=1)
    for k in range(8):                       # retro thrusters under the ring, pointing down and out
        psi = (k + 0.5) * math.pi / 4
        d = pod_dir(psi)
        c = d * 2.36 + V((0, 0, 0.44))
        ax = (d * 0.45 + V((0, 0, -1))).normalized()
        lathe(P, c, ax, [(0.16, -0.12), (0.16, 0.0), (0.24, 0.2), (0.27, 0.27), (0.23, 0.27), (0.14, 0.12), (0.0, 0.08)], 10,
              mats=["gold", "gold", "gold", "gold", "soot", "soot"])
    for k in range(4):                       # landing legs at the seams
        psi = math.pi / 4 + k * math.pi / 2
        d = pod_dir(psi)
        top, foot = d * 2.3 + V((0, 0, 0.52)), d * 2.86 + V((0, 0, 0.1))
        tube(P, [top, foot], 0.075, 8, "gold", sub=1)
        tube(P, [top + (foot - top) * 0.15, top + (foot - top) * 0.6], 0.095, 8, "chrome", sub=1)
        lathe(P, foot + V((0, 0, -0.1)), (0, 0, 1), [(0.0, 0.0), (0.32, 0.0), (0.34, 0.03), (0.3, 0.08), (0.12, 0.12), (0.0, 0.12)], 12, "chrome")
        tube(P, [d * 2.05 + V((0, 0, 0.16)), foot + V((0, 0, 0.02))], 0.045, 6, "gold", sub=1)
    for k in range(4):                       # the hinge knuckles each petal turns on
        phi = k * math.pi / 2
        h = pod_dir(phi) * POD_HINGE[0] + V((0, 0, POD_HINGE[1]))
        t = V((math.cos(phi), math.sin(phi), 0))
        for e in (-1, 1):
            rbox(P, h + t * (e * 0.56) + pod_dir(phi) * -0.04 + V((0, 0, -0.06)), (0.2, 0.12, 0.14), 0.03, 1, "gold", R=rot((0, 0, 1), phi))
    return P


def pod_cap():
    P = Part("pod_cap")
    c = V((0, 0, POD_TOP))
    lathe(P, c, (0, 0, 1), [(0.6, -0.05), (0.64, -0.02), (0.64, 0.05), (0.6, 0.08), (0.52, 0.12), (0.4, 0.18), (0.26, 0.24), (0.14, 0.29), (0.07, 0.31), (0.05, 0.31),
                            (0.045, 0.33), (0.0, 0.34)], 24, mats=["chrome"] * 3 + ["gold"] * 6 + ["gold", "glow", "glow"])
    for k in range(8):
        a = TAU * (k + 0.5) / 8
        d = V((math.cos(a), math.sin(a), 0))
        stud(P, c + d * 0.64 + V((0, 0, 0.015)), d, 0.03, 0.025, "gold", 6)
    return P


def build_pod():
    root = empty("pod_root", (0, 0, 0), size=1.0)
    base = obj(pod_base(), (0, 0, 0), root)
    for k in range(4):
        P, hinge, phi = pod_petal(k)
        obj(P, hinge, base, R=rot((0, 0, 1), phi))
    obj(pod_cap(), (0, 0, POD_TOP), base)
    return root


def preview_pod(folder):
    cam = render_setup()
    night_set(1.35)
    shoot(cam, folder, "pod_34", (9.5, -15.0, 3.6), (0, 0, 3.2), 40)
    shoot(cam, folder, "pod_front", (0, -18.5, 3.5), (0, 0, 3.3), 40)
    shoot(cam, folder, "pod_side", (18.5, 0, 3.5), (0, 0, 3.3), 40)
    TRI_LOG.clear()
    mech = build_mech()
    mech.location.z = POD_FLOOR
    stand_in_head().location.z += POD_FLOOR
    clearance(mech)
    ob = bpy.data.objects
    for k in range(4):
        ob["petal_%d" % (k + 1)].rotation_euler.x = math.radians(100)
    ob["pod_cap"].location.z += 3.0
    ob["pod_cap"].rotation_euler = (0.6, 0.3, 0.0)
    shoot(cam, folder, "pod_open", (10.0, -16.0, 6.0), (0, 0, 2.4), 36)


def clearance(mech):
    """how close the mech, standing on the deck, comes to the closed petals' inner skin"""
    out, inn = shell_profiles()
    zs = [z for r, z in reversed(inn)]
    rs = [r for r, z in reversed(inn)]
    if zs != sorted(zs):
        zs, rs = zip(*sorted(zip(zs, rs)))
    inner = Mono(list(zs), list(rs))
    bpy.context.view_layer.update()
    worst = []
    for o in bpy.data.objects:
        if o.type != 'MESH' or o.name.startswith(("petal", "pod_", "ground", "stand_in")):
            continue
        p = o
        while p.parent is not None:
            p = p.parent
        if p.name != "mech_root":
            continue
        M = o.matrix_world
        best = 9.0
        for v in o.data.vertices:
            w = M @ v.co
            if w.z < POD_HINGE[1]:
                continue
            best = min(best, inner(w.z) - math.hypot(w.x, w.y))
        worst.append((best, o.name))
    worst.sort()
    print("CLEARANCE (m, mech part to the closed petals' inner skin):", ", ".join("%s %.3f" % (n, b) for b, n in worst[:6]))


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# the yacht: the Fenrirs' 140 m space yacht, seen over Earth from 100 to 300 m in one cutscene shot. A pearl hull with gold pinstripes and lit portholes, a stepped
# superstructure banded with dark glass and warm windows, the glass penthouse dome on top, swept wings carrying two of the three engines, the crest on both bow
# sides, nav lights (red to port, the yacht's left, +x; green to starboard), and a launch bay under the keel whose doors carry the crest split down the middle.
# Surfaces here run along the hull: h metres toward the bow (-y), t = 0 the top, pi/2 starboard (-x), -pi/2 port (+x), pi the keel.

YF = frame((0, -1, 0), (0, 0, -1))
HULL = [  # h, half beam, half height, centre x, centre y (= -z), squareness above, squareness below
    (-66.0, 9.0, 5.6, 0, -1.0, 3.0, 2.4),
    (-60.0, 11.4, 6.8, 0, -0.8, 3.4, 2.8),
    (-40.0, 12.5, 7.4, 0, -0.6, 3.6, 3.2),
    (-10.0, 12.6, 7.4, 0, -0.4, 3.6, 3.2),
    (15.0, 11.6, 6.8, 0, -0.4, 3.4, 2.8),
    (35.0, 9.2, 5.6, 0, -0.6, 3.0, 2.3),
    (50.0, 6.0, 4.2, 0, -1.0, 2.6, 2.0),
    (60.0, 3.4, 2.8, 0, -1.6, 2.4, 1.9),
    (66.0, 1.6, 1.6, 0, -2.2, 2.2, 1.9),
    (70.0, 0.35, 0.45, 0, -2.6, 2.0, 2.0),
]
TIERS = [  # the superstructure, three decks stepping up and back, their fronts raked; each sits deep in the one below
    [(-44.0, 8.0, 3.0, 0, -9.0, 4.0, 6.0), (-36.0, 9.4, 3.0, 0, -9.0, 5.0, 6.0), (6.0, 9.4, 3.0, 0, -9.0, 5.0, 6.0), (20.0, 8.0, 2.6, 0, -8.6, 4.4, 6.0),
     (28.0, 5.6, 1.9, 0, -7.9, 3.4, 6.0), (31.0, 2.4, 1.2, 0, -7.2, 2.4, 6.0)],
    [(-32.0, 6.0, 1.8, 0, -12.8, 4.0, 6.0), (-26.0, 7.6, 1.8, 0, -12.8, 5.0, 6.0), (4.0, 7.6, 1.8, 0, -12.8, 5.0, 6.0), (14.0, 6.4, 1.6, 0, -12.6, 4.2, 6.0),
     (19.0, 3.6, 1.0, 0, -12.0, 3.0, 6.0)],
    [(-22.0, 5.0, 1.1, 0, -15.3, 4.0, 6.0), (-18.0, 6.4, 1.1, 0, -15.3, 5.0, 6.0), (0.0, 6.4, 1.1, 0, -15.3, 5.0, 6.0), (6.0, 4.6, 1.0, 0, -15.2, 4.0, 6.0),
     (9.0, 2.0, 0.6, 0, -15.0, 3.0, 6.0)],
]
DOME_C = V((0.0, 8.0, 16.35))        # the penthouse dome's centre, on the top deck
DOME_R = 6.0
BAY_C = V((0.0, 2.0, -7.02))         # the launch bay: the centre of its doors (the pod hangs above this point, base down)
BAY_HX, BAY_HY = 5.2, 8.2            # its half width and half length
WING_DIHEDRAL = math.radians(14.0)
WING_TIP = 25.0                      # the wings' span from the keel line, along the wing
_tip = lambda s: V((s * WING_TIP * math.cos(WING_DIHEDRAL), 0.0, -1.0 + WING_TIP * math.sin(WING_DIHEDRAL)))
ENGINES = [(V((0.0, 64.0, 0.6)), 5.4, 13.0), (_tip(1) + V((0, 52.0, 0)), 3.4, 12.0), (_tip(-1) + V((0, 52.0, 0)), 3.4, 12.0)]   # nacelle start, radius, length (they run aft, +y)


def hash01(*k):
    x = math.sin(sum((i + 1) * 12.9898 * v for i, v in enumerate(k))) * 43758.5453
    return x - math.floor(x)


def yacht_hull():
    P = Part("hull")
    S = Surf(V((0, 0, 0)), YF, HULL)
    ts = [TAU * k / 48 for k in range(48)]
    hs = sorted(set([h for h, *_ in HULL] + [-66 + 4 * k for k in range(34)] + [-BAY_C.y - BAY_HY - 0.3, -BAY_C.y + BAY_HY + 0.3]))

    def skip(t, h):          # the bay's mouth
        p = S.base(t, h)
        return math.cos(t) < -0.5 and abs(p.x) < BAY_HX + 0.3 and abs(p.y - BAY_C.y) < BAY_HY + 0.3
    S.mesh(P, ts, hs, "enamel", skip=skip, cap0="chrome")
    # gold pinstripes along both flanks, a boot stripe below, a gold band round the stern
    for side in (1, -1):
        for t, w in ((1.17, 0.022), (1.25, 0.008), (1.8, 0.02)):
            S.plate(P, side * t - w, side * t + w, -63.0, 62.0, 0.12, 0.04, 1, 40, "satin")
        S.stripe(P, -40.0, 66.0, lambda h, side=side: side * lerp(1.62, 1.95, smooth((h + 40.0) / 70.0)) if h < 30 else side * lerp(1.95, 2.3, smooth((h - 30) / 36.0)),
                 lambda h: lerp(0.02, 0.07, smooth((h + 40.0) / 90.0)), 0.14, 36, "satin")
        for row, t in enumerate((1.36, 1.5)):                    # lit portholes
            for q in range(26):
                h = -52.0 + q * 3.7 + row * 1.85
                if h > 50 or hash01(q, row, side) < 0.18:
                    continue
                p, X, Y, N = S.place(side * t, h, 0.04)
                prism(P, [V((0.42 * math.cos(TAU * k / 6), 0.42 * math.sin(TAU * k / 6))) for k in range(6)], p, X, Y, 0.05, 0.0, "glow", z0=-0.05)
    S.band(P, -64.0, -62.6, 0.12, 0.05, n=48, mat="satin")
    # the crest on both bow sides
    for side in (1, -1):
        p, X, Y, N = S.place(-side * math.pi / 2, 41.0, 0.05)
        up = (V((0, 0, 1)) - N * N.z).normalized()
        crest(P, p, up.cross(N), up, 8.6, 0, 0.35, field="enamel", z0=-1.2, gold="satin")
    # the superstructure: dark glass bands with warm windows, gold rails between the decks
    for k, secs in enumerate(TIERS):
        T = Surf(V((0, 0, 0)), YF, secs)
        h0, h1 = secs[0][0], secs[-1][0]
        rows = [h0 + (h1 - h0) * q / int((h1 - h0) / 2.4) for q in range(int((h1 - h0) / 2.4) + 1)]
        zc, half = -secs[1][4], secs[1][2]
        z_lo, z_hi = zc + half * (0.05 if k else -0.05), zc + half * (0.62 if k else 0.55)

        def mats(t, h, i, T=T, z_lo=z_lo, z_hi=z_hi, k=k):
            p = T.base(t, h)
            if abs(math.sin(t)) > 0.5 and z_lo < p.z < z_hi:
                return "lit" if hash01(i, k, round(math.sin(t))) > 0.66 else "window"
            if math.cos(t) > 0.2 and h > secs[-2][0] - 1.0:
                return "window"                               # the raked front is glass
            return "enamel"
        T.mesh(P, [TAU * q / 36 for q in range(36)], rows, mats=mats, cap0="enamel", cap1="enamel")
        for side in (1, -1):
            T.plate(P, side * 1.0 - 0.05, side * 1.0 + 0.05, h0 + 3.0, secs[-2][0] - 1.0, 0.14, 0.05, 1, 14, "satin")
    # a gold radar arch over the upper deck, swept back
    arch = [V((x, y, z)) for x, y, z in ((6.0, -14.0, 14.2), (5.8, -11.5, 17.4), (3.8, -9.0, 19.8), (0.0, -8.0, 20.5))]
    path = arch + [V((-q.x, q.y, q.z)) for q in reversed(arch[:-1])]
    tube(P, path, 0.55, 10, "satin", sub=3)
    for q in (0.2, 0.5, 0.8):
        a0 = catmull(path, 3)[int(q * (len(catmull(path, 3)) - 1))]
        sphere(P, a0 + V((0, -0.6, 0)), 0.3, 8, 4, "lit")
    # the penthouse floor's warm light and its furniture, under the dome
    lathe(P, DOME_C + V((0, 0, 0.05)), (0, 0, 1), [(DOME_R - 0.1, 0.0), (0.0, 0.0)], 32, "glow")
    for q in range(5):
        a = TAU * q / 5 + 0.3
        rbox(P, DOME_C + V((math.cos(a) * 3.6, math.sin(a) * 3.6, 0.45)), (2.2, 0.9, 0.8), 0.25, 1, "rubber", R=rot((0, 0, 1), a + math.pi / 2))
    cyl(P, DOME_C + V((0, 0, 0.05)), DOME_C + V((0, 0, 1.1)), 1.1, 16, "satin")                        # a gold bar in the middle
    torus(P, DOME_C + V((0, 0, 4.0)), (0, 0, 1), 1.5, 0.08, 20, 4, "satin")                             # the chandelier
    torus(P, DOME_C + V((0, 0, 3.4)), (0, 0, 1), 0.9, 0.06, 16, 4, "satin")
    sphere(P, DOME_C + V((0, 0, 3.7)), 0.55, 12, 6, "glow")
    cyl(P, DOME_C + V((0, 0, 4.0)), DOME_C + V((0, 0, DOME_R - 0.1)), 0.05, 6, "satin", caps=False)
    # the mast with its radome, a strobe on top
    m0 = V((0, -4.5, 16.0))
    cyl(P, m0, m0 + V((0, 0, 6.0)), 0.25, 8, "chrome")
    sphere(P, m0 + V((0, 0, 6.6)), 0.9, 14, 7, "enamel")
    torus(P, m0 + V((0, 0, 6.6)), (0, 0, 1), 0.92, 0.07, 16, 4, "satin")
    cyl(P, m0 + V((-2.0, 0, 4.6)), m0 + V((2.0, 0, 4.6)), 0.1, 6, "chrome")
    # wings: swept back from the hull to the outer engines, gold leading edges; a dorsal fin aft
    for side in (1, -1):
        span = V((side * math.cos(WING_DIHEDRAL), 0, math.sin(WING_DIHEDRAL)))
        Yv = V((0, side, 0))                     # so that span x Yv points up on both sides
        O = V((0, 0, -1.0)) - span.cross(Yv) * 0.8
        wing = [V((11.0 / math.cos(WING_DIHEDRAL), -18.0)), V((WING_TIP, 44.0)), V((WING_TIP, 64.0)), V((11.0 / math.cos(WING_DIHEDRAL), 57.0))]
        pts = wing if side > 0 else [V((q.x, -q.y)) for q in reversed(wing)]
        prism(P, pts, O, span, Yv, 1.6, 0.5, "enamel", back="enamel", fixed=None)
        inlay = [V((13.5, 6.0)), V((WING_TIP - 1.6, 50.0)), V((WING_TIP - 1.6, 58.0)), V((13.5, 40.0))]       # a gold panel let into the wing's top
        prism(P, inlay if side > 0 else [V((q.x, -q.y)) for q in reversed(inlay)], O + span.cross(Yv) * 1.6, span, Yv, 0.08, 0.04, "satin", fixed=None, z0=-0.02)
        le0, le1 = V((0, -18.0, -1.0)) + span * (11.4 / math.cos(WING_DIHEDRAL)), V((0, 44.0, -1.0)) + span * (WING_TIP - 0.4)
        tube(P, [le0, le1], 0.45, 8, "satin", sub=1)
        tube(P, [le0 + V((0, 6.0, 0.82)), le1 + V((0, 4.0, 0.82))], 0.1, 5, "glow", sub=1)
    fin = [V((38.0, 7.4)), V((66.0, 5.8)), V((71.0, 17.6)), V((64.0, 17.2))]
    prism(P, fin, (-0.65, 0, 0), (0, 1, 0), (0, 0, 1), 1.3, 0.35, "enamel", back="enamel", fixed=None)
    tube(P, [V((0, 39.5, 8.0)), V((0, 64.4, 17.3))], 0.3, 8, "satin", sub=1)
    # the engines' nacelles: pearl cowls, gold lips, chrome throats (their glowing faces are engines_glow)
    for q, (c, r, L) in enumerate(ENGINES):
        prof = [(r * 0.55, -1.0), (r * 0.92, 0.6), (r, L * 0.25), (r * 1.02, L * 0.6), (r * 0.98, L * 0.86), (r * 1.06, L * 0.9), (r * 1.06, L * 0.97), (r * 0.98, L),
                (r * 0.8, L), (r * 0.78, L * 0.9), (r * 0.62, L * 0.82)]
        cowl = ["enamel", "satin", "enamel", "enamel"] if q == 0 else ["satin"] * 4                # the outer engines in gold, the big one pearl with a gold collar
        lathe(P, c, (0, 1, 0), prof, 28, mats=cowl + ["satin"] * 4 + ["chrome", "chrome"])
        lathe(P, c + V((0, L * 0.82, 0)), (0, 1, 0), [(r * 0.62, 0.0), (r * 0.3, 0.06 * L), (0.0, 0.06 * L)], 20, "rubber")
    # nav lights: red to port (+x), green to starboard, white strobes on the fin, the bow and the mast
    for p, m in ((_tip(1) + V((0.5, 44.0, 0)), "navred"), (_tip(-1) + V((-0.5, 44.0, 0)), "navgreen"), (V((5.6, -50.0, 3.4)), "navred"), (V((-5.6, -50.0, 3.4)), "navgreen"),
                 (V((0, 71.4, 17.9)), "navwhite"), (V((0, -70.6, 2.75)), "navwhite"), (m0 + V((0, 0, 7.65)), "navwhite"), (V((0, 66.0, -6.2)), "navwhite")):
        sphere(P, p, 0.6, 10, 5, m)
    # the bay inside: dark walls lit along the top, a gold clamp ring in the roof
    hx, hy, z0, z1 = BAY_HX + 0.05, BAY_HY + 0.05, BAY_C.z - 0.2, BAY_C.z + 8.6
    rr = [V((hx, -hy)), V((hx, hy)), V((-hx, hy)), V((-hx, -hy))]
    lo = [P.vt((p.x, BAY_C.y + p.y, z0)) for p in rr]
    hi = [P.vt((p.x, BAY_C.y + p.y, z1)) for p in rr]
    for i in range(4):
        j = (i + 1) % 4
        mid = (rr[i] + rr[j]) * 0.5
        P.face([lo[i], lo[j], hi[j], hi[i]], "rubber", out=V((-mid.x, -mid.y, 0)))
    P.face(hi, "rubber", out=V((0, 0, -1)))
    for p, sz in ((V((0, BAY_C.y + hy - 0.15, z1 - 0.6)), (2 * hx - 0.6, 0.12, 0.25)), (V((0, BAY_C.y - hy + 0.15, z1 - 0.6)), (2 * hx - 0.6, 0.12, 0.25)),
                  (V((hx - 0.15, BAY_C.y, z1 - 0.6)), (0.12, 2 * hy - 0.6, 0.25)), (V((-hx + 0.15, BAY_C.y, z1 - 0.6)), (0.12, 2 * hy - 0.6, 0.25))):
        rbox(P, p, sz, 0.04, 1, "glow")
    torus(P, V((0, BAY_C.y, z1 - 0.3)), (0, 0, 1), 2.7, 0.22, 24, 6, "satin")
    out_h = rrect_half(BAY_HX + 0.75, BAY_HY + 0.75, 0.6, 2)
    in_h = rrect_half(BAY_HX + 0.02, BAY_HY + 0.02, 0.05, 1)
    band = ring_half(out_h, in_h)
    for side in (1, -1):        # the bay's gold frame, facing down
        prism(P, band if side > 0 else mirror2(band), (0, BAY_C.y, BAY_C.z + 0.35), (1, 0, 0), (0, -1, 0), 0.5, 0.12, "satin")
    return P


def yacht_bay_door(side):
    P = Part("bay_door_L" if side > 0 else "bay_door_R")
    gap = 0.03
    out = [V((gap, -BAY_HY)), V((BAY_HX, -BAY_HY)), V((BAY_HX, BAY_HY)), V((gap, BAY_HY))]
    if side < 0:
        out = mirror2(out)
    # facing down: X along +x, Y along -y (toward the bow), so the crest's top points forward
    prism(P, out, (0, BAY_C.y, BAY_C.z + 0.02), (1, 0, 0), (0, -1, 0), 0.32, 0.08, "enamel", back="rubber", fixed=lambda p, q: abs(abs(p.x) - gap) < 1e-6 and abs(abs(q.x) - gap) < 1e-6)
    crest(P, V((0, BAY_C.y, BAY_C.z - 0.3)), (1, 0, 0), (0, -1, 0), 9.0, half=side, depth=0.18, detail=1, gold="satin")
    hinge = V((side * BAY_HX, BAY_C.y, BAY_C.z))
    return P, hinge


def yacht_engines_glow():
    P = Part("engines_glow")
    for c, r, L in ENGINES:
        e = c + V((0, L * 0.82 + 0.02, 0))
        lathe(P, e, (0, 1, 0), [(r * 0.6, 0.06 * L - 0.01), (r * 0.28, 0.06 * L + 0.02), (0.0, 0.06 * L + 0.02)], 24, "engine")      # the core of the jet
        lathe(P, c + V((0, L * 0.97, 0)), (0, 1, 0), [(r * 0.77, 0.0), (r * 0.77, -0.05 * L)], 24, "engine")                      # a lit ring inside the lip
    return P


def yacht_dome(P):
    """the penthouse's glass dome, gold-ribbed, on the top deck (part of the hull's mesh)"""
    lathe(P, DOME_C, (0, 0, 1), [(DOME_R * math.cos(math.pi / 2 * k / 10), DOME_R * math.sin(math.pi / 2 * k / 10)) for k in range(11)], 40, "glass")
    lathe(P, DOME_C, (0, 0, 1), [(DOME_R - 0.1, -0.3), (DOME_R + 0.35, -0.3), (DOME_R + 0.4, 0.0), (DOME_R + 0.3, 0.25), (DOME_R - 0.02, 0.3), (DOME_R - 0.02, 0.1)], 40, "satin")
    for q in range(8):
        a = TAU * q / 8
        path = [DOME_C + V((math.cos(a) * math.cos(b) * (DOME_R + 0.06), math.sin(a) * math.cos(b) * (DOME_R + 0.06), math.sin(b) * (DOME_R + 0.06)))
                for b in [math.pi / 2 * k / 8 for k in range(8)]]
        tube(P, path, 0.12, 5, "satin", sub=1)
    sphere(P, DOME_C + V((0, 0, DOME_R + 0.1)), 0.45, 12, 6, "satin")


def build_yacht():
    root = empty("yacht_root", (0, 0, 0), size=6.0)
    hull_part = yacht_hull()
    yacht_dome(hull_part)
    hull = obj(hull_part, (0, 0, 0), root)
    for side in (1, -1):
        P, hinge = yacht_bay_door(side)
        obj(P, hinge, hull)
    empty("bay", BAY_C, hull, size=3.0)
    c, r, L = ENGINES[0]
    obj(yacht_engines_glow(), c + V((0, L * 0.82, 0)), hull)
    return root


def preview_yacht(folder):
    cam = render_setup()
    sc = bpy.context.scene
    world((0.0, 0.0, 0.0), (0.05, 0.14, 0.34), (0.006, 0.018, 0.045), [((0.6, -0.5, -0.62), (0.2, 0.45, 1.0), 0.75, 0.98, 0.35)], 1.0)
    nt = sc.world.node_tree
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = 260.0
    tc = next(nd for nd in nt.nodes if nd.type == 'TEX_COORD')
    nt.links.new(tc.outputs["Generated"], vor.inputs["Vector"])
    st = nt.nodes.new("ShaderNodeMapRange")
    st.inputs["From Min"].default_value = 0.035
    st.inputs["From Max"].default_value = 0.0
    st.inputs["To Max"].default_value = 2.0
    st.clamp = True
    nt.links.new(vor.outputs["Distance"], st.inputs["Value"])
    bg = next(nd for nd in nt.nodes if nd.type == 'BACKGROUND')
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = 'RGBA'
    mix.blend_type = 'ADD'
    mix.inputs["Factor"].default_value = 1.0
    nt.links.new(bg.inputs["Color"].links[0].from_socket, mix.inputs["A"])
    nt.links.new(st.outputs["Result"], mix.inputs["B"])
    nt.links.new(mix.outputs["Result"], bg.inputs["Color"])
    sun = bpy.data.lights.new("sun", 'SUN')
    sun.energy = 4.5
    sun.color = (1.0, 0.97, 0.92)
    so = bpy.data.objects.new("sun", sun)
    sc.collection.objects.link(so)
    so.rotation_euler = (V((0, 0, 0)) - V((80, -60, 70))).to_track_quat('-Z', 'Y').to_euler()
    light("earthshine", 'AREA', (40, -40, -160), (0, 0, 0), 1.2e5, (0.35, 0.6, 1.0), 120)
    shoot(cam, folder, "yacht_34", (150.0, -170.0, 55.0), (0, 2, 2), 45)
    shoot(cam, folder, "yacht_front", (0.0, -240.0, 20.0), (0, 0, 3), 45)
    shoot(cam, folder, "yacht_side", (240.0, 0.0, 12.0), (0, 4, 3), 45)
    shoot(cam, folder, "yacht_rear34", (-150.0, 190.0, 40.0), (0, 10, 2), 45)
    ob = bpy.data.objects
    ob["bay_door_L"].rotation_euler.y = math.radians(-100)
    ob["bay_door_R"].rotation_euler.y = math.radians(100)
    shoot(cam, folder, "yacht_bay_open", (70.0, -95.0, -60.0), (0, 2, -6), 40)


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# previews (Eevee): a dark violet set with softboxes in the sky for the metals to reflect, a warm key, a cyan rim, a violet fill

def world(sky, horizon, ground, boxes, strength=1.0):
    sc = bpy.context.scene
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    nt = w.node_tree
    bg = next(nd for nd in nt.nodes if nd.type == 'BACKGROUND')
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nv = nt.nodes.new("ShaderNodeVectorMath")
    nv.operation = 'NORMALIZE'
    nt.links.new(tc.outputs["Generated"], nv.inputs[0])
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(nv.outputs["Vector"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = -1.0
    mr.inputs["From Max"].default_value = 1.0
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    els[0].position, els[0].color = 0.0, (*ground, 1)
    els[1].position, els[1].color = 1.0, (*sky, 1)
    e = els.new(0.5)
    e.color = (*horizon, 1)
    e = els.new(0.47)
    e.color = (*ground, 1)
    e = els.new(0.56)
    e.color = (*[lerp(horizon[k], sky[k], 0.5) for k in range(3)], 1)
    nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
    last = ramp.outputs["Color"]
    for d, col, c0, c1, k in boxes:
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = 'DOT_PRODUCT'
        dot.inputs[1].default_value = V(d).normalized()
        nt.links.new(nv.outputs["Vector"], dot.inputs[0])
        m2 = nt.nodes.new("ShaderNodeMapRange")
        m2.inputs["From Min"].default_value = c0
        m2.inputs["From Max"].default_value = c1
        m2.inputs["To Max"].default_value = k
        m2.clamp = True
        nt.links.new(dot.outputs["Value"], m2.inputs["Value"])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = 'RGBA'
        mix.blend_type = 'ADD'
        mix.inputs["Factor"].default_value = 1.0
        nt.links.new(last, mix.inputs["A"])
        cm = nt.nodes.new("ShaderNodeMix")
        cm.data_type = 'RGBA'
        cm.blend_type = 'MULTIPLY'
        cm.inputs["Factor"].default_value = 1.0
        cm.inputs["A"].default_value = (*col, 1)
        nt.links.new(m2.outputs["Result"], cm.inputs["B"])
        nt.links.new(cm.outputs["Result"], mix.inputs["B"])
        last = mix.outputs["Result"]
    nt.links.new(last, bg.inputs["Color"])
    bg.inputs["Strength"].default_value = strength


def light(name, kind, loc, look, energy, col, size=2.0):
    sc = bpy.context.scene
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    ld.color = col
    if kind == 'AREA':
        ld.size = size
    lo = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(lo)
    lo.location = loc
    lo.rotation_euler = (V(look) - V(loc)).to_track_quat('-Z', 'Y').to_euler()
    return lo


def render_setup(res=(1200, 900)):
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = 48
    try:
        sc.eevee.use_raytracing = True
        sc.eevee.ray_tracing_options.resolution_scale = '1'
    except Exception:
        pass
    sc.eevee.use_shadows = True
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'AgX'
    try:
        sc.view_settings.look = 'AgX - Medium High Contrast'
    except Exception:
        pass
    cd = bpy.data.cameras.new("cam")
    cd.clip_end = 5000
    cam = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    return cam


def shoot(cam, folder, name, at, look, lens=50):
    cam.location = at
    cam.rotation_euler = (V(look) - V(at)).to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = lens
    sc = bpy.context.scene
    sc.render.filepath = os.path.join(folder, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", sc.render.filepath)


def ground_plane(size, col=(0.02, 0.018, 0.026), rough=0.3):
    me = bpy.data.meshes.new("ground")
    me.from_pydata([(-size, -size, 0), (size, -size, 0), (size, size, 0), (-size, size, 0)], [], [(0, 1, 2, 3)])
    m = bpy.data.materials.new("ground")
    m.use_nodes = True
    bs = next(nd for nd in m.node_tree.nodes if nd.type == 'BSDF_PRINCIPLED')
    bs.inputs["Base Color"].default_value = (*col, 1)
    bs.inputs["Roughness"].default_value = rough
    me.materials.append(m)
    g = bpy.data.objects.new("ground", me)
    bpy.context.scene.collection.objects.link(g)
    return g


def night_set(scale=1.0):
    world((0.004, 0.004, 0.01), (0.016, 0.01, 0.026), (0.002, 0.002, 0.003), [
        ((-0.6, -0.8, 0.5), (1.0, 0.88, 0.74), 0.88, 0.95, 2.4),       # a big warm softbox front right
        ((0.9, 0.35, 0.35), (0.35, 0.85, 1.0), 0.94, 0.985, 2.0),      # a cyan strip on the left
        ((0.0, 0.0, 1.0), (0.9, 0.88, 1.0), 0.9, 0.97, 1.0),           # a top light
        ((0.2, 0.95, 0.05), (0.6, 0.25, 1.0), 0.86, 0.95, 0.06),       # violet glow behind
        ((-0.95, 0.2, 0.15), (1.0, 0.7, 0.85), 0.95, 0.99, 1.2),       # a pink strip on the right
    ])
    ground_plane(60 * scale, (0.012, 0.011, 0.016), 0.35)
    k = scale * scale
    light("key", 'AREA', V((-7, -9, 10)) * scale, (0, 0, 2.8 * scale), 2400 * k, (1.0, 0.92, 0.82), 4 * scale)
    light("rim", 'AREA', V((7, 8, 7)) * scale, (0, 0, 3.0 * scale), 2600 * k, (0.4, 0.85, 1.0), 4 * scale)
    light("rim2", 'AREA', V((-8, 7, 5)) * scale, (0, 0, 3.0 * scale), 1200 * k, (0.75, 0.4, 1.0), 4 * scale)
    light("fill", 'AREA', V((9, -8, 3)) * scale, (0, 0, 2.5 * scale), 900 * k, (0.7, 0.72, 1.0), 6 * scale)


def preview_mech(folder):
    cam = render_setup()
    night_set()
    stand_in_head()
    shoot(cam, folder, "mech_34", (6.8, -10.5, 3.0), (0.1, 0, 2.75), 50)
    shoot(cam, folder, "mech_front", (0, -12.8, 2.9), (0, 0, 2.7), 50)
    shoot(cam, folder, "mech_side", (12.8, -0.3, 2.9), (0, -0.3, 2.7), 50)
    shoot(cam, folder, "mech_back34", (-7.5, 9.5, 3.6), (0, 0, 2.9), 50)
    ob = bpy.data.objects
    ob["chest_door_L"].rotation_euler.z = math.radians(105)
    ob["chest_door_R"].rotation_euler.z = math.radians(-105)
    ob["pod_lid_L"].rotation_euler.x = math.radians(-110)
    ob["pod_lid_R"].rotation_euler.x = math.radians(-110)
    ob["dome"].rotation_euler.x = math.radians(-70)
    shoot(cam, folder, "mech_open", (3.4, -6.6, 4.4), (0.15, -0.3, 3.85), 50)
    for n in ("chest_door_L", "chest_door_R", "pod_lid_L", "pod_lid_R", "dome"):
        ob[n].rotation_euler = (0, 0, 0)


# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# export and main

def export(root, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    stack = [root]
    while stack:
        o = stack.pop()
        o.select_set(True)
        stack.extend(o.children)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_normals=True, export_tangents=True,
                              export_texcoords=True, export_materials='EXPORT', export_vertex_color='NONE', export_cameras=False, export_lights=False, export_animations=False,
                              export_extras=False, export_image_format='AUTO')
    print("WROTE", path)


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    WORLD.clear()
    TRI_LOG.clear()
    make_materials()


def report(label):
    total = sum(t for _, t in TRI_LOG)
    print("TRIS %s total %d" % (label, total))
    for n, t in TRI_LOG:
        print("   %-16s %6d" % (n, t))


def main():
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
    if "mech" in ONLY:
        fresh()
        root = build_mech()
        report("mech")
        if EXPORT:
            export(root, OUT + "/sambo_mech.glb")
        if PREVIEW:
            preview_mech(PREVIEW)
    if "pod" in ONLY:
        fresh()
        root = build_pod()
        report("pod")
        if EXPORT:
            export(root, OUT + "/drop_pod.glb")
        if PREVIEW:
            preview_pod(PREVIEW)
    if "yacht" in ONLY:
        fresh()
        root = build_yacht()
        report("yacht")
        if EXPORT:
            export(root, OUT + "/yacht.glb")
        if PREVIEW:
            preview_yacht(PREVIEW)


main()
