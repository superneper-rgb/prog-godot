## Violet Starborn: her head. Its own dense cage (finer over the face), the sculpted face forms, and the eye lenses.
import bpy, bmesh, math, sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
vb = sys.modules["violet_body"]
S = vb.S
NCOL = 24

# ---------------------------------------------------------------- cage (reference pixels, side view x / image Y)
# front (x, Y), back (x, Y), half width, exponent, rings to insert before the next one
RINGS = [
    ((543, 270), (491, 270), 25, 2.0, 0),
    ((538, 250), (494, 250), 22, 2.0, 0),
    ((540, 233), (497, 222), 22, 2.0, 0),      # neck top
    ((564, 244), (478, 206), 25, 1.9, 0),      # under the jaw
    ((593, 246), (456, 188), 33, 1.75, 3),     # chin and jaw line
    ((604, 217), (440, 170), 49, 1.9, 3),      # mouth
    ((608, 202), (433, 152), 62, 2.0, 1),      # nose
    ((609, 180), (430, 132), 73, 2.1, 2),      # eyes
    ((614, 152), (431, 112), 81, 2.2, 1),      # brow
    ((616, 128), (434, 92), 83, 2.2, 0),
    ((609, 100), (444, 74), 75, 2.1, 0),
    ((590, 72), (462, 56), 57, 2.0, 0),
    ((556, 51), (488, 46), 34, 2.0, 0),
]
MOUTH_Y = 217.0
EYE = dict(cx=38.0, cy=159.0, a=31.0, bt=10.0, bb=18.0, tilt=math.radians(25.0))
BROW = [(7.0, 144.0), (22.0, 135.0), (38.0, 129.0), (56.0, 125.5), (74.0, 123.0)]

def col_angle(j):
    """Columns crowd the face: about two thirds of them sit in the front half."""
    s = j / NCOL * 2.0
    if s > 1.0: s -= 2.0
    return math.pi * (0.45 * s + 0.55 * s * abs(s) ** 0.8)

def ring_pts(f, b, hw, e):
    pts = []
    mid = (f[0] + b[0]) * 0.5; half = (f[0] - b[0]) * 0.5
    for j in range(NCOL):
        th = col_angle(j)
        cs = vb.sup(math.cos(th), e); sn = vb.sup(math.sin(th), e)
        pts.append(Vector((hw * S * sn, vb.sy(mid + half * cs), vb.fz(b[1] + (f[1] - b[1]) * (cs + 1.0) * 0.5))))
    return pts

def cage():
    rows = []
    for (a, b) in zip(RINGS, RINGS[1:] + [None]):
        rows.append(a[:4])
        if b is None: break
        n = a[4]
        for k in range(1, n + 1):
            t = k / (n + 1.0); L = lambda p, q: p + (q - p) * t
            rows.append(((L(a[0][0], b[0][0]), L(a[0][1], b[0][1])), (L(a[1][0], b[1][0]), L(a[1][1], b[1][1])), L(a[2], b[2]), L(a[3], b[3])))
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in ring_pts(*r)] for r in rows]
    for a, b in zip(rings, rings[1:]):
        for i in range(NCOL):
            bm.faces.new((a[i], a[(i + 1) % NCOL], b[(i + 1) % NCOL], b[i]))
    # top of the head: 6 x 6 quad patch
    top = rings[-1]; m = NCOL // 4; r = top[m // 2:] + top[:m // 2]
    g = {}
    for i in range(m): g[(i, 0)] = r[i]
    for i in range(m): g[(m, i)] = r[m + i]
    for i in range(m): g[(m - i, m)] = r[2 * m + i]
    for i in range(m): g[(0, m - i)] = r[3 * m + i]
    co = lambda u, v: g[(u, v)].co
    for u in range(1, m):
        for v in range(1, m):
            s = u / m; t = v / m
            p = (1 - s) * co(0, v) + s * co(m, v) + (1 - t) * co(u, 0) + t * co(u, m) \
                - ((1 - s) * (1 - t) * co(0, 0) + s * (1 - t) * co(m, 0) + (1 - s) * t * co(0, m) + s * t * co(m, m))
            p = p.copy(); p.z += 11 * S * (1 - (2 * s - 1) ** 2) * (1 - (2 * t - 1) ** 2)
            g[(u, v)] = bm.verts.new(p)
    for u in range(m):
        for v in range(m):
            bm.faces.new((g[(u, v)], g[(u + 1, v)], g[(u + 1, v + 1)], g[(u, v + 1)]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

# ---------------------------------------------------------------- face fields (numpy; X from centre, image Y)
def gauss(X, Y, cx, cy, sx, sy_):
    return np.exp(-(((X - cx) / sx) ** 2 + ((Y - cy) / sy_) ** 2))
def gauss2(X, Y, cx, cy, sx, sy_):                     # mirrored pair
    return gauss(np.abs(X), Y, cx, cy, sx, sy_)
def sstep(t):
    t = np.clip(t, 0.0, 1.0); return t * t * (3.0 - 2.0 * t)

def eye_local(X, Y):
    dx = np.abs(X) - EYE["cx"]; dy = -(Y - EYE["cy"])
    c, s = math.cos(EYE["tilt"]), math.sin(EYE["tilt"])
    return dx * c + dy * s, -dx * s + dy * c            # u: inner (-) to outer (+) corner, w: up
def eye_top(un):
    return EYE["bt"] * np.clip(1.0 - np.abs(un) ** 2.4, 0.0, 1.0) ** 0.55
def eye_bot(un):
    return EYE["bb"] * np.cos(np.clip(un, -1.0, 1.0) * math.pi / 2) ** 0.8
def eye_dist(X, Y):
    """Rough distance in pixels outside the eye outline (negative inside)."""
    u, w = eye_local(X, Y); un = u / EYE["a"]
    ext = np.where(w >= 0, eye_top(un), eye_bot(un))
    inside = np.abs(w) - ext
    beyond = np.hypot((np.abs(un) - 1.0) * EYE["a"], w)
    return np.where(np.abs(un) < 1.0, inside, beyond), w

def poly_dist(X, Y, pts):
    d = np.full(X.shape, 1e9)
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        px = X - ax; py = Y - ay; vx = bx - ax; vy = by - ay
        t = np.clip((px * vx + py * vy) / (vx * vx + vy * vy), 0, 1)
        d = np.minimum(d, np.hypot(px - t * vx, py - t * vy))
    return d

def lips_upper(X, Y, m0):
    return np.maximum(gauss2(X, Y, 4.4, m0 - 3.4, 5.6, 2.6), 0.55 * gauss(X, Y, 0.0, m0 - 2.6, 3.2, 2.2)) * sstep((13.5 - np.abs(X)) / 4.0)
def lips_lower(X, Y, m0):
    return gauss(X, Y, 0.0, m0 + 4.2, 8.8, 3.3) * sstep((13.5 - np.abs(X)) / 4.0)

def face_push(X, Y, m0):
    """How far (pixels) the face surface moves forward at a front-projected point."""
    aX = np.abs(X)
    d, w = eye_dist(X, Y)
    P = -6.8 * sstep((2.5 - d) / 5.0)                                         # socket
    P += 1.7 * np.exp(-((d - 2.2) / 2.0) ** 2)                                # lid rim
    P += 3.4 * np.exp(-(poly_dist(aX, Y, BROW) / 5.0) ** 2)                   # brow ridge
    win = sstep((Y - 140.0) / 8.0) * sstep((201.0 - Y) / 5.0)
    P += 3.2 * np.exp(-(X / (4.2 + 1.6 * sstep((Y - 170.0) / 30.0))) ** 2) * win   # nose bridge
    P += 5.6 * gauss(X, Y, 0.0, 200.5, 6.2, 5.2)                              # tip
    P += 2.2 * gauss2(X, Y, 6.6, 203.5, 3.3, 3.2)                             # wings
    P -= 1.8 * gauss(X, Y, 0.0, 208.0, 8.0, 2.4)                              # under the nose
    P -= 0.9 * gauss(X, Y, 0.0, 209.5, 2.0, 3.0)                              # philtrum
    P += 3.1 * lips_upper(X, Y, m0) + 3.9 * lips_lower(X, Y, m0)
    P -= 1.6 * gauss2(X, Y, 13.5, m0, 3.0, 3.0)                               # mouth corners
    P -= 1.7 * gauss(X, Y, 0.0, m0 + 10.5, 9.0, 3.0)                          # under the lower lip
    P += 2.6 * gauss(X, Y, 0.0, m0 + 19.5, 10.0, 6.5)                         # chin
    P += 2.8 * gauss2(X, Y, 52.0, 178.0, 15.0, 9.0)                           # cheek bones
    P -= 2.2 * gauss2(X, Y, 36.0, 206.0, 12.0, 11.0)                          # hollow under them
    return P

def coords(ob):
    n = len(ob.data.vertices); co = np.empty(n * 3, dtype=np.float64); ob.data.vertices.foreach_get("co", co)
    return co.reshape(n, 3)

def sculpt(ob, m0):
    co = coords(ob)
    X = co[:, 0] / S; Y = 1330.0 - co[:, 2] / S; D = 530.0 - co[:, 1] / S
    front = sstep((D - 562.0) / 28.0)
    co[:, 1] -= face_push(X, Y, m0) * front * S
    ob.data.vertices.foreach_set("co", co.ravel()); ob.data.update()

def mouth_row_y(ob):
    co = coords(ob)
    X = co[:, 0] / S; Y = 1330.0 - co[:, 2] / S; D = 530.0 - co[:, 1] / S
    m = (np.abs(X) < 1e-3) & (D > 580.0) & (Y > 205.0) & (Y < 230.0)
    ys = Y[m]
    return float(ys[np.argmin(np.abs(ys - MOUTH_Y))])

def make_head(vp):
    bm = cage()
    head = vp.obj_from_bm(bm, "SM_Char_Violet_Head", 2); bm.free()
    m0 = mouth_row_y(head)
    sculpt(head, m0)
    return head, m0

def build_eye(vp, head, side, name):
    """Glossy lens: a quad disc bent to the eye outline, laid in the socket and domed."""
    dg = bpy.context.evaluated_depsgraph_get()
    bvh = BVHTree.FromObject(head, dg)
    K = 7
    bm = bmesh.new(); grid = {}
    c, s = math.cos(EYE["tilt"]), math.sin(EYE["tilt"])
    for i in range(-K, K + 1):
        for j in range(-K, K + 1):
            a = i / K; b = j / K
            if a == 0 and b == 0: da = db = 0.0
            elif abs(a) > abs(b):
                r = a; ph = (math.pi / 4) * (b / a); da = r * math.cos(ph); db = r * math.sin(ph)
            else:
                r = b; ph = (math.pi / 2) - (math.pi / 4) * (a / b); da = r * math.cos(ph); db = r * math.sin(ph)
            rho = min(1.0, math.hypot(da, db))
            brel = max(-1.0, min(1.0, db / math.sqrt(max(1e-9, 1.0 - min(da * da, 0.999999)))))
            u = EYE["a"] * da * 1.02
            ext = float(eye_top(np.array(da))) if brel >= 0 else float(eye_bot(np.array(da)))
            w = brel * (ext + 0.8)
            dx = u * c - w * s; dy = u * s + w * c
            X = EYE["cx"] + dx; Y = EYE["cy"] - dy
            o = Vector((side * X * S, -1.0, (1330.0 - Y) * S))
            hit, nrm, _, _ = bvh.ray_cast(o, Vector((0, 1, 0)))
            if hit is None:
                hit, nrm, _, _ = bvh.find_nearest(o + Vector((0, 0.9, 0)))
            off = (5.2 * (1.0 - rho * rho) ** 0.65 - 0.9) * S
            grid[(i, j)] = bm.verts.new(hit + nrm * off)
    for i in range(-K, K):
        for j in range(-K, K):
            bm.faces.new((grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if sum(f.normal.y for f in bm.faces) > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    ob = vp.obj_from_bm(bm, name, 0); bm.free()
    return ob
