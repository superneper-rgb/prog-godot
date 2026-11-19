## Violet Starborn: builds her body cage from scratch (quad lofts measured off the reference views).
import bpy, bmesh, math
from mathutils import Vector

S = 1.72 / 1292.0          # metres per reference pixel (she stands 1.72 m in her platforms)
def fx(X): return (X - 543.0) * S
def fz(Y): return (1330.0 - Y) * S
def sy(X): return -(X - 530.0) * S   # side view faces right: image +x is her front (-Y in Blender)

def sup(c, e):
    return math.copysign(abs(c) ** (2.0 / e), c)

def ring_pts(n, hw, xb, xf, yf, yb=None, e=2.0, cx=0.0, phase=0.0):
    """Tilted superellipse ring. hw: half width px. xb/xf: back/front side-view px. yf/yb: image Y at front/back."""
    if yb is None: yb = yf
    pts = []
    mid = (xf + xb) * 0.5; half = (xf - xb) * 0.5
    for j in range(n):
        th = phase + 2.0 * math.pi * j / n
        cs = sup(math.cos(th), e); sn = sup(math.sin(th), e)
        t = (cs + 1.0) * 0.5
        pts.append(Vector((cx * S + hw * S * sn, sy(mid + half * cs), fz(yb + (yf - yb) * t))))
    return pts

# ---------------------------------------------------------------- data (reference pixels)
# torso, bottom to top: Y, half width, back x, front x, exponent
TORSO = [
    (650, 123, 472, 598, 2.3),
    (624, 119, 467, 599, 2.3),
    (598, 112, 468, 601, 2.2),
    (570, 100, 480, 604, 2.1),
    (540,  85, 501, 606, 2.0),
    (508,  66, 517, 605, 2.0),
    (474,  50, 528, 602, 2.0),   # waist
    (440,  54, 520, 605, 2.0),
    (408,  70, 500, 600, 2.1),   # under the bust
    (378,  81, 485, 596, 2.2),   # armpit            (arm hole rows 9..12)
    (352,  88, 477, 588, 2.2),
    (328,  92, 474, 578, 2.2),
    (306,  88, 478, 566, 2.2),   # shoulder top
    (288,  42, 486, 550, 2.0),   # neck base
    (270,  25, 491, 543, 2.0),
    (246,  22, 494, 538, 2.0),
    (228,  21, 497, 538, 2.0),   # neck top
]
ARM_ROWS = (9, 10, 11, 12)
# head: (front x, front Y), (back x, back Y), half width, exponent
HEAD = [
    ((562, 236), (476, 204), 30, 1.9),
    ((590, 240), (452, 186), 43, 1.8),   # chin / skull base
    ((604, 212), (438, 168), 53, 1.9),   # mouth line
    ((611, 200), (432, 150), 64, 2.0),   # nose
    ((612, 178), (430, 130), 74, 2.1),   # eyes
    ((615, 150), (431, 110), 81, 2.2),   # brow
    ((612, 120), (436,  88), 82, 2.2),
    ((600,  90), (447,  70), 76, 2.1),
    ((578,  64), (466,  54), 62, 2.0),
    ((548,  47), (490,  44), 36, 2.0),
]
# legs: Y, centre offset, half width, back x, front x
LEGS = [
    (686, 72.5, 52.5, 486, 600),
    (730, 76.0, 47.0, 491, 596),
    (790, 74.0, 40.0, 502, 585),
    (850, 74.0, 32.5, 511, 575),
    (886, 79.0, 29.0, 507, 574),   # knee
    (920, 86.0, 32.5, 495, 564),
    (952, 90.0, 40.0, 483, 564),
    (985, 91.5, 41.5, 477, 565),
    (1030, 94.0, 38.0, 479, 560),
    (1094, 98.0, 26.0, 493, 552),
    (1142, 99.5, 20.5, 502, 546),  # ankle
]
CROTCH = [(500, 664), (548, 669), (590, 662)]   # back, bottom, front (side x, Y), on the centre line
# arm: distance along the arm (px), radius (px)
ARM_J = Vector((fx(543 + 97), sy(516), fz(332)))
ARM_ANG = math.radians(31.0)
ARM = [(30, 25.0), (74, 22.0), (110, 20.5), (140, 19.2), (160, 18.6), (182, 19.6), (225, 19.0), (275, 15.5), (312, 13.0)]
PALM = [(324, 17, 13), (342, 27, 12.5), (362, 29, 11.5), (375, 28, 10)]     # t, half width, thickness
FINGER_LEN = [50, 57, 52, 41]

# ---------------------------------------------------------------- build
def build():
    bm = bmesh.new()
    lp = bm.verts.layers.int.new("part"); li = bm.verts.layers.int.new("idx")   # part: 0 torso/head, 1 leg, 2 arm+hand
    def mk(pts, part=0, idx=0):
        out = []
        for p in pts:
            v = bm.verts.new(p); v[lp] = part; v[li] = idx; out.append(v)
        return out
    def face(vs):
        try: bm.faces.new(vs)
        except ValueError: pass
    def bridge(a, b, skip=()):
        n = len(a)
        for i in range(n):
            if i in skip: continue
            face((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]))

    # torso + head rings (16 around, vert 0 = front centre, 4 = her left side, 8 = back centre)
    rings = [mk(ring_pts(16, hw, xb, xf, Y, e=e), 0, i) for i, (Y, hw, xb, xf, e) in enumerate(TORSO)]
    for (f, b, hw, e) in HEAD:
        rings.append(mk(ring_pts(16, hw, b[0], f[0], f[1] + 3, b[1] + 3, e=e), 0, len(rings)))
    arm_skip = {3, 4, 11, 12}
    for i in range(len(rings) - 1):
        bridge(rings[i], rings[i + 1], skip=arm_skip if (i in ARM_ROWS[:-1]) else ())
    # top of the head: 4x4 quad patch
    top = rings[-1]
    order = [(2,0),(3,0),(4,0),(4,1),(4,2),(4,3),(4,4),(3,4),(2,4),(1,4),(0,4),(0,3),(0,2),(0,1),(0,0),(1,0)]
    grid = {uv: top[j] for j, uv in enumerate(order)}
    def P(u, v): return grid[(u, v)].co
    for u in range(1, 4):
        for v in range(1, 4):
            s = u / 4.0; t = v / 4.0
            p = (1 - s) * P(0, v) + s * P(4, v) + (1 - t) * P(u, 0) + t * P(u, 4) \
                - ((1 - s) * (1 - t) * P(0, 0) + s * (1 - t) * P(4, 0) + (1 - s) * t * P(0, 4) + s * t * P(4, 4))
            p = p.copy(); p.z += 13 * S * (1 - (2 * s - 1) ** 2) * (1 - (2 * t - 1) ** 2)
            grid[(u, v)] = mk([p], 0, 99)[0]
    for u in range(4):
        for v in range(4):
            face((grid[(u, v)], grid[(u + 1, v)], grid[(u + 1, v + 1)], grid[(u, v + 1)]))

    # crotch + legs (12 around)
    cr = mk([Vector((0.0, sy(x), fz(y))) for (x, y) in CROTCH], 1, -1)     # back, bottom, front
    r0 = rings[0]
    for side in (1, -1):
        cols = list(range(0, 9)) if side > 0 else [0, 15, 14, 13, 12, 11, 10, 9, 8]
        loop = [r0[c] for c in cols] + [cr[0], cr[1], cr[2]]
        prev = loop
        for li_, (Y, cx, hw, xb, xf) in enumerate(LEGS):
            pts = ring_pts(12, hw, xb, xf, Y, e=2.0, phase=math.radians(-30.0))
            cur = mk([Vector((side * (p.x + cx * S), p.y, p.z)) for p in pts], 1, li_)
            bridge(prev, cur); prev = cur

    # arms + hands (10 around)
    a = Vector((math.sin(ARM_ANG), 0.0, -math.cos(ARM_ANG)))
    e1 = Vector((math.cos(ARM_ANG), 0.0, math.sin(ARM_ANG)))       # back of the hand / top of the arm
    e2 = Vector((0.0, -1.0, 0.0))                                   # front (thumb side)
    R = rings
    for side in (1, -1):
        def M(v): return Vector((side * v.x, v.y, v.z))
        c = (lambda k: k) if side > 0 else (lambda k: 16 - k)
        loop = [R[12][c(4)], R[12][c(3)], R[11][c(3)], R[10][c(3)], R[9][c(3)], R[9][c(4)], R[9][c(5)], R[10][c(5)], R[11][c(5)], R[12][c(5)]]
        # the shoulder ring: tilted further out than the arm, a little egg shaped
        sa = math.radians(58.0)
        a0 = Vector((math.sin(sa), 0.0, -math.cos(sa))); u0 = Vector((math.cos(sa), 0.0, math.sin(sa)))
        for k, v in enumerate(loop):
            ps = math.radians(36.0 * k)
            v.co = M(ARM_J - a0 * 6 * S + u0 * (33 * S * math.cos(ps)) + e2 * (29 * S * math.sin(ps)))
        prev = loop
        def aring(t, r, idx):
            C = ARM_J + a * (t * S)
            return mk([M(C + e1 * (r * S * math.cos(math.radians(36.0 * k))) + e2 * (r * S * math.sin(math.radians(36.0 * k)))) for k in range(10)], 2, idx)
        for ai, (t, r) in enumerate(ARM):
            cur = aring(t, r, ai); bridge(prev, cur); prev = cur
        # palm: k order t2 t1 t0 b0 b1 b2 b3 b4 t4 t3
        korder = [(2, 1), (1, 1), (0, 1), (0, -1), (1, -1), (2, -1), (3, -1), (4, -1), (4, 1), (3, 1)]
        rnd = [0.55, 0.95, 1.0, 0.95, 0.55]
        palms = []
        for pi, (t, W, T) in enumerate(PALM):
            C = ARM_J + a * (t * S)
            cur = mk([M(C + e2 * (W * S * (1 - i / 2.0)) + e1 * (sgn * T * 0.5 * S * rnd[i])) for (i, sgn) in korder], 2, 100)
            bridge(prev, cur, skip=(2,) if pi == 1 else ()); palms.append(cur); prev = cur
        def tube(base, c0, d, steps, curl_axis, curl):
            """base: 4 verts. steps: (distance px, width scale, thickness scale)."""
            offs = [M(v.co) - c0 for v in base]          # in the +x frame
            pr = base; dist0 = 0.0; cc = c0.copy(); dd = d.copy()
            for (dist, ws, ts) in steps:
                cc = cc + dd * ((dist - dist0) * S); dist0 = dist
                cur = []
                for o in offs:
                    w = o.dot(e2); th = o.dot(e1); al = o.dot(a)
                    cur.append(mk([M(cc + e2 * (w * ws) + e1 * (th * ts) + a * (al * 0.3))], 2, 100)[0])
                bridge(pr, cur); pr = cur
                dd = (dd + curl_axis * curl).normalized()
            face(pr)
        Tt = {i: None for i in range(5)}; Bb = {}
        last = palms[-1]
        for k, (i, sgn) in enumerate(korder):
            if sgn > 0: Tt[i] = last[k]
            else: Bb[i] = last[k]
        for i in range(4):
            base = [Tt[i], Tt[i + 1], Bb[i + 1], Bb[i]]
            c0 = sum((M(v.co) for v in base), Vector()) / 4.0
            sp = math.radians((1.5 - i) * 5.0)
            d = (a * math.cos(sp) + e2 * math.sin(sp)).normalized()
            L = FINGER_LEN[i]
            tube(base, c0, d, [(5, 0.80, 0.96), (0.40 * L, 0.78, 0.92), (0.70 * L, 0.70, 0.82), (0.93 * L, 0.60, 0.68), (L, 0.36, 0.40)], -e1, 0.07)
        # thumb from the side quad between the first two palm rings
        tb = [palms[0][2], palms[1][2], palms[1][3], palms[0][3]]
        c0 = sum((M(v.co) for v in tb), Vector()) / 4.0
        d = (e2 * 0.80 + a * 0.58 - e1 * 0.12).normalized()
        offs_fix = tb
        pr = tb; cc = c0.copy(); dist0 = 0.0
        offs = [M(v.co) - c0 for v in tb]
        for (dist, sc) in [(9, 0.86), (24, 0.78), (38, 0.66), (46, 0.36)]:
            cc = cc + d * ((dist - dist0) * S); dist0 = dist
            cur = mk([M(cc + o * sc) for o in offs], 2, 100)
            bridge(pr, cur); pr = cur
            d = (d + a * 0.10).normalized()
        face(pr)

    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='VERTS')
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm

def make_object(name="SM_Char_Violet_Body"):
    col = bpy.data.collections.get("COL_Violet")
    if not col:
        col = bpy.data.collections.new("COL_Violet"); bpy.context.scene.collection.children.link(col)
    old = bpy.data.objects.get(name)
    if old:
        me = old.data; bpy.data.objects.remove(old); bpy.data.meshes.remove(me)
    bm = build()
    me = bpy.data.meshes.new(name); bm.to_mesh(me)
    stats = {"verts": len(bm.verts), "faces": len(bm.faces), "non_quads": sum(1 for f in bm.faces if len(f.verts) != 4),
             "non_manifold_edges": sum(1 for e in bm.edges if len(e.link_faces) not in (1, 2)),
             "boundary_edges": sum(1 for e in bm.edges if len(e.link_faces) == 1)}
    bm.free()
    for p in me.polygons: p.use_smooth = True
    ob = bpy.data.objects.new(name, me); col.objects.link(ob)
    md = ob.modifiers.new("Subsurf", 'SUBSURF'); md.levels = 1; md.render_levels = 1
    return ob, stats
