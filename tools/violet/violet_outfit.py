## Violet Starborn: her outfit, each piece its own mesh laid over the finished body (top, shorts, boots, belt, choker, chrome and gold trim).
import bpy, bmesh, math, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
vb = sys.modules["violet_body"]; vp = sys.modules["violet_parts"]
S = vb.S
Z = lambda Y: (1330.0 - Y) * S
sy = vb.sy

def lerp_rows(rows, Y):
    """rows sorted by Y (first column); linear interpolation of the remaining numeric columns."""
    rows = sorted(rows, key=lambda r: r[0])
    if Y <= rows[0][0]: return rows[0][1:]
    for a, b in zip(rows, rows[1:]):
        if a[0] <= Y <= b[0]:
            t = (Y - a[0]) / (b[0] - a[0]); return tuple(x + (y - x) * t for x, y in zip(a[1:], b[1:]))
    return rows[-1][1:]

def torso_c(Y, xmid=None):
    hw, xb, xf, e = lerp_rows(vb.TORSO, Y)
    return Vector((0.0, sy((xb + xf) * 0.5 if xmid is None else xmid), Z(Y)))
def leg_c(Y, side=1):
    cx, hw, xb, xf = lerp_rows(vb.LEGS, Y)
    return Vector((side * cx * S, sy((xb + xf) * 0.5), Z(Y)))

def bvh_of(*obs):
    bm = bmesh.new()
    for o in obs: bm.from_mesh(o.data)
    t = BVHTree.FromBMesh(bm); bm.free(); return t

def mat(name, color, metallic=0.0, rough=0.5):
    m = bpy.data.materials.get(name)
    if not m:
        m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1); b.inputs["Metallic"].default_value = metallic; b.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*color, 1); m.metallic = metallic; m.roughness = rough
    return m

class Piece:
    """Collects outward-facing quads; finish() turns them into an object (optionally with real thickness)."""
    def __init__(self):
        self.bm = bmesh.new(); self.out = {}
    def v(self, p, n):
        x = self.bm.verts.new(p); self.out[x] = n; return x
    def quad(self, vs, mat_index=0):
        f = self.bm.faces.new(vs); f.smooth = True; f.material_index = mat_index
        n = sum((self.out.get(q, Vector()) for q in vs), Vector())
        f.normal_update()
        if n.length > 0 and f.normal.dot(n) < 0: f.normal_flip()
        return f
    def grid(self, rows, wrap=False, mat_index=0):
        for a, b in zip(rows, rows[1:]):
            n = len(a)
            for i in range(n if wrap else n - 1):
                self.quad((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]), mat_index)
    def cast_ring(self, bvh, C, U, V, n, off, phase=0.0, squash=1.0):
        out = []
        for k in range(n):
            a = phase + 2 * math.pi * k / n
            d = (U * math.cos(a) + V * math.sin(a)).normalized()
            hit, nrm, _, _ = bvh.ray_cast(C, d)
            if hit is None:
                hit, nrm, _, _ = bvh.find_nearest(C + d * 0.05)
            if nrm.dot(d) < 0: nrm = -nrm
            nn = (nrm + d).normalized()
            out.append(self.v(hit + nn * off * S, nn))
        return out
    def mirror(self):
        geom = bmesh.ops.duplicate(self.bm, geom=self.bm.verts[:] + self.bm.edges[:] + self.bm.faces[:])["geom"]
        nf = [g for g in geom if isinstance(g, bmesh.types.BMFace)]
        for g in geom:
            if isinstance(g, bmesh.types.BMVert): g.co.x = -g.co.x
        bmesh.ops.reverse_faces(self.bm, faces=nf)
    def finish(self, name, mats, thick=0.0, levels=0):
        vp.drop(name)
        me = bpy.data.meshes.new(name); self.bm.normal_update(); self.bm.to_mesh(me); self.bm.free()
        for m in mats: me.materials.append(m)
        ob = bpy.data.objects.new(name, me); vp.col().objects.link(ob)
        if thick or levels:
            if levels:
                md = ob.modifiers.new("ss", 'SUBSURF'); md.levels = levels
            if thick:
                md = ob.modifiers.new("solid", 'SOLIDIFY'); md.thickness = thick * S; md.offset = -1.0; md.use_even_offset = True
            dg = bpy.context.evaluated_depsgraph_get()
            me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
            ob.modifiers.clear(); ob.data = me2; bpy.data.meshes.remove(me); me2.name = name
        for p in ob.data.polygons: p.use_smooth = True
        return ob

FWD = Vector((0, -1, 0)); LEFT = Vector((1, 0, 0)); UP = Vector((0, 0, 1))

# ---------------------------------------------------------------- top
def make_top(body, M):
    bvh = bvh_of(body); P = Piece()
    # cups: one patch in (angle, height), cast out from the chest axis
    NS, NT = 40, 11; TH = 80.0; YB = 440.0
    def ytop(th):
        a = abs(th)
        hs = lambda t: (1.0 - math.cos(math.pi * t)) * 0.5
        if a < 38.0:
            return 404.0 + (336.0 - 404.0) * hs(a / 38.0)
        return 336.0 + (384.0 - 336.0) * hs((a - 38.0) / (TH - 38.0))
    rows = []
    for j in range(NT + 1):
        row = []
        for i in range(NS + 1):
            th = -TH + 2 * TH * i / NS; Y = YB + (ytop(th) - YB) * (j / NT)
            a = math.radians(th); d = Vector((math.sin(a), -math.cos(a), 0.0))
            C = torso_c(Y, 536.0)
            hit, nrm, _, _ = bvh.ray_cast(C, d)
            if nrm.dot(d) < 0: nrm = -nrm
            nn = (nrm + d * 0.6).normalized()
            row.append(P.v(hit + nn * 2.4 * S, nn))
        rows.append(row)
    P.grid(rows)
    # relax the cups so the body's facets do not print through (edges stay put)
    P.bm.verts.ensure_lookup_table()
    inner = [v for v in P.bm.verts if not v.is_boundary]
    for _ in range(4): bmesh.ops.smooth_vert(P.bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    for v in inner:                                 # smoothing sinks the dome: lay it back on the body
        loc, nrm, _, _ = bvh.find_nearest(v.co)
        v.co = loc + nrm * 2.6 * S
    bmesh.ops.smooth_vert(P.bm, verts=inner, factor=0.35, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    for v in inner:
        loc, nrm, _, _ = bvh.find_nearest(v.co)
        if (v.co - loc).dot(nrm) < 2.0 * S: v.co = loc + nrm * 2.0 * S
    # band under the bust, round the back from one cup edge to the other
    band = []
    for Y in (418.0, 425.0, 432.5, 440.0):
        row = []
        for i in range(25):
            a = math.radians(TH + (360.0 - 2 * TH) * i / 24.0); d = Vector((math.sin(a), -math.cos(a), 0.0))
            C = torso_c(Y, 536.0); hit, nrm, _, _ = bvh.ray_cast(C, d)
            if nrm.dot(d) < 0: nrm = -nrm
            nn = (nrm + d * 0.6).normalized(); row.append(P.v(hit + nn * 2.4 * S, nn))
        band.append(row)
    P.grid(band)
    # straps over the shoulders: cup apex to the back of the band
    apx = abs(max(rows[-1], key=lambda q: q.co.z).co.x) / S
    for side in (1, -1):
        rows = []
        N = 26
        for k in range(N + 1):
            t = k / N; al = math.radians(27.0 + (226.0 - 27.0) * t)
            x0 = (apx + (66.0 - apx) * min(1.0, t * 2.5)) * S * side
            Pv = Vector((x0, sy(535.0), Z(372.0)))
            d = Vector((0.0, -math.cos(al), math.sin(al)))
            row = []
            wd = 6.5 + 4.0 * max(0.0, 1.0 - k / 5.0)
            for dxp in (-wd, 0.0, wd):
                o = Pv + Vector((dxp * S, 0, 0))
                hit, nrm, _, _ = bvh.ray_cast(o, d)
                if nrm.dot(d) < 0: nrm = -nrm
                nn = (nrm + d).normalized()
                row.append(P.v(hit + nn * ((3.0 if 1 < k < N - 1 else 0.6) + (0.8 if dxp == 0.0 else 0.0)) * S, nn))
            rows.append(row)
        P.grid(rows)
    return P.finish("SM_Char_Violet_Cloth_Top", [M["latex"]], thick=2.0)

# ---------------------------------------------------------------- shorts
def make_shorts(body, M):
    bm = bmesh.new(); bm.from_mesh(body.data)
    bvh = bvh_of(body)
    kill = []
    for f in bm.faces:
        Y = 1330.0 - f.calc_center_median().z / S
        if not (548.0 < Y < 688.0): kill.append(f)
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    bm.normal_update()
    for v in bm.verts: v.co += v.normal * 2.4 * S
    # leg openings cut high on the hip, low at the crotch
    for v in bm.verts:
        X = v.co.x / S; Y = 1330.0 - v.co.z / S
        rel = (abs(X) - 72.0) / 52.0
        lift = 34.0 * vp.smooth01((rel + 0.45) / 1.35) * max(0.0, min(1.0, (Y - 628.0) / 58.0))
        if lift > 0.0:
            p = v.co + Vector((0, 0, lift * S))
            loc, nrm, _, _ = bvh.find_nearest(p)
            v.co = loc + nrm * 2.4 * S
    P = Piece(); P.bm.free(); P.bm = bm
    return P.finish("SM_Char_Violet_Cloth_Shorts", [M["latex"]], thick=2.2)

# ---------------------------------------------------------------- trim: belt, choker, garter, cuffs, studs, buckle
def dome(P, C, n, r, h, mat_index=0, segs=8):
    """Small stud: two rings and a top quad patch standing on C along n."""
    t = n.cross(UP) if abs(n.z) < 0.9 else n.cross(FWD)
    t.normalize(); b = n.cross(t).normalized()
    rings = []
    for (rr, hh) in ((1.0, 0.0), (0.92, 0.55), (0.55, 0.95)):
        rings.append([P.v(C + (t * math.cos(2 * math.pi * k / segs) + b * math.sin(2 * math.pi * k / segs)) * r * rr * S + n * h * hh * S, n) for k in range(segs)])
    P.grid(rings, wrap=True, mat_index=mat_index)
    top = rings[-1]; c = [top[1], top[3], top[5], top[7]]
    P.quad(c, mat_index)
    # corner fill between the octagon and the inner quad
    for i in range(4):
        a_ = top[2 * i + 1]; m_ = top[(2 * i + 2) % 8]; b_ = top[(2 * i + 3) % 8]
        f = P.bm.faces.new((a_, m_, b_)); f.smooth = True; f.material_index = mat_index
        if f.normal.dot(n) < 0: f.normal_flip()

def torus(P, C, n, R, r, mat_index=0, seg=20, sides=8):
    t = n.cross(UP).normalized(); b = n.cross(t).normalized()
    rows = []
    for i in range(seg):
        a = 2 * math.pi * i / seg; dirv = t * math.cos(a) + b * math.sin(a); cc = C + dirv * R * S
        rows.append([P.v(cc + (dirv * math.cos(2 * math.pi * k / sides) + n * math.sin(2 * math.pi * k / sides)) * r * S,
                         dirv * math.cos(2 * math.pi * k / sides) + n * math.sin(2 * math.pi * k / sides)) for k in range(sides)])
    for i in range(seg):
        a_, b_ = rows[i], rows[(i + 1) % seg]
        for k in range(sides):
            P.quad((a_[k], a_[(k + 1) % sides], b_[(k + 1) % sides], b_[k]), mat_index)

def make_trim(body, head, gloves, M):
    bvh = bvh_of(body); bvh_n = bvh_of(body, head); bvh_g = bvh_of(gloves)
    # violet bands
    L = Piece()
    L.grid([L.cast_ring(bvh, torso_c(Y), FWD, LEFT, 40, 5.0) for Y in (545.0, 551.0, 559.0, 566.0)], wrap=True)          # belt
    L.grid([L.cast_ring(bvh_n, Vector((0, sy(516.0), Z(Y))), FWD, LEFT, 24, 2.6) for Y in (251.0, 257.0, 264.0, 270.0)], wrap=True)   # choker
    L.grid([L.cast_ring(bvh, leg_c(Y), FWD, LEFT, 24, 2.4) for Y in (737.0, 745.0, 753.0)], wrap=True)                 # garter
    latex = L.finish("SM_Char_Violet_Cloth_Bands", [M["latex"]], thick=2.2)
    # metal: slot 0 chrome, slot 1 gold
    P = Piece()
    P.grid([P.cast_ring(bvh_n, Vector((0, sy(516.0), Z(Y))), FWD, LEFT, 24, 3.6) for Y in (255.5, 261.0, 266.5)], wrap=True)
    for (ya, yb) in ((732.0, 737.5), (752.5, 758.0)):
        P.grid([P.cast_ring(bvh, leg_c(Y), FWD, LEFT, 24, 3.2) for Y in (ya, (ya + yb) / 2, yb)], wrap=True, mat_index=1)
    metal_thick = P;
    ob_a = metal_thick.finish("SM_Char_Violet_Acc_MetalBands", [M["chrome"], M["gold"]], thick=1.6)
    # cuffs on the gloves (built on her left arm, mirrored)
    C2 = Piece()
    a = Vector((math.sin(vb.ARM_ANG), 0.0, -math.cos(vb.ARM_ANG))); e1 = Vector((math.cos(vb.ARM_ANG), 0.0, math.sin(vb.ARM_ANG)))
    for ts in ((75.5, 81.0, 87.0), (288.0, 295.0, 302.0)):
        C2.grid([C2.cast_ring(bvh_g, vb.ARM_J + a * (t * S), e1, FWD, 20, 2.2) for t in ts], wrap=True)
    C2.mirror()
    ob_b = C2.finish("SM_Char_Violet_Acc_Cuffs", [M["chrome"]], thick=1.8)
    # studs and the ring buckle on the belt
    D = Piece(); bb = bvh_of(latex)
    def on_belt(th, Y=555.5):
        a_ = math.radians(th); d = Vector((math.sin(a_), -math.cos(a_), 0.0))
        C = torso_c(Y); hit, nrm, _, _ = bb.ray_cast(C + d * 0.5, -d)
        return hit, d
    BUCKLE = -30.0
    for th in range(-180, 180, 15):
        if abs(th - BUCKLE) < 20: continue
        hit, d = on_belt(th); dome(D, hit, d, 2.6, 2.2, 0)
    hit, d = on_belt(BUCKLE, 557.0)
    torus(D, hit + d * 1.8 * S, d, 11.5, 2.8, 1)
    ob_c = D.finish("SM_Char_Violet_Acc_Studs", [M["chrome"], M["gold"]])
    return [latex, ob_a, ob_b, ob_c]

# ---------------------------------------------------------------- boots
def cap_ring(P, ring, corners, bulge=Vector((0, 0, 0)), mat_index=0):
    """Fills a closed ring of 4m verts with an m x m quad patch; corners = index of the first corner."""
    n = len(ring); m = n // 4
    r = ring[corners:] + ring[:corners]
    g = {}
    for i in range(m): g[(i, 0)] = r[i]
    for i in range(m): g[(m, i)] = r[m + i]
    for i in range(m): g[(m - i, m)] = r[2 * m + i]
    for i in range(m): g[(0, m - i)] = r[3 * m + i]
    co = lambda u, v: g[(u, v)].co
    nrm = P.out.get(ring[0], Vector((0, 0, -1)))
    for u in range(1, m):
        for v in range(1, m):
            s = u / m; t = v / m
            p = (1 - s) * co(0, v) + s * co(m, v) + (1 - t) * co(u, 0) + t * co(u, m) \
                - ((1 - s) * (1 - t) * co(0, 0) + s * (1 - t) * co(m, 0) + (1 - s) * t * co(0, m) + s * t * co(m, m))
            g[(u, v)] = P.v(p + bulge * (1 - (2 * s - 1) ** 2) * (1 - (2 * t - 1) ** 2), nrm)
    for u in range(m):
        for v in range(m):
            P.quad((g[(u, v)], g[(u + 1, v)], g[(u + 1, v + 1)], g[(u, v + 1)]), mat_index)

FOOT = [  # front (x, Y), back (x, Y), half width, centre offset, exponent
    ((552, 1175), (499, 1170), 22.5, 101.0, 2.0),
    ((563, 1203), (491, 1198), 25.5, 102.5, 2.0),
    ((575, 1226), (486, 1222), 29.5, 104.0, 2.1),
    ((592, 1250), (484, 1240), 33.5, 105.5, 2.2),
    ((629, 1266), (484, 1250), 37.0, 107.0, 2.4),
    ((641, 1289), (484, 1258), 38.0, 107.5, 2.6),
]
def make_boots(M):
    P = Piece()
    ph = math.radians(-30.0)
    def ring(hw, xb, xf, yf, yb, cx, e=2.0, n=12, phase=ph, nrm=None):
        pts = vb.ring_pts(n, hw, xb, xf, yf, yb, e=e, cx=cx, phase=phase)
        c = sum(pts, Vector()) / len(pts)
        return [P.v(p, (p - c).normalized() if nrm is None else nrm) for p in pts]
    rows = []
    cx, hw, xb, xf = lerp_rows(vb.LEGS, 985.0)
    rows.append(ring(hw - 1.5, xb + 1.5, xf - 1.5, 989.0, 989.0, cx))            # lip turned in against the leg
    rows.append(ring(hw + 3.0, xb - 3.0, xf + 3.0, 984.0, 984.0, cx))
    for Y in (1000.0, 1030.0, 1062.0, 1094.0, 1120.0, 1142.0):
        cx, hw, xb, xf = lerp_rows(vb.LEGS, Y)
        rows.append(ring(hw + 3.0, xb - 3.0, xf + 3.0, Y, Y, cx))
    for (f, b, hw, cx, e) in FOOT:
        rows.append(ring(hw, b[0], f[0], f[1], b[1], cx, e=e))
    P.grid(rows, wrap=True)
    cap_ring(P, rows[-1], 0)
    P.mirror()
    upper = P.finish("SM_Char_Violet_Cloth_Boots", [M["latex"]], levels=1)
    # platform and block heel: hard pieces, bevelled by hand
    Q = Piece()
    def block(xb, xf, hw, cx, e, ytop, ybot):
        rows = []
        for (Y, sc) in ((ytop, 0.93), (ytop + 3.5, 1.0), (ybot - 4.0, 1.0), (ybot, 0.94)):
            mid = (xb + xf) / 2; h = (xf - xb) / 2 * sc
            rows.append(ring(hw * sc, mid - h, mid + h, Y, Y, cx, e=e, n=16, phase=0.0))
        return rows
    P = Q
    for args in ((548, 643, 39.0, 107.5, 3.2, 1281.0, 1330.0), (482, 535, 31.0, 106.5, 3.6, 1249.0, 1330.0)):
        rows = block(*args)
        Q.grid(rows, wrap=True)
        for v in rows[0]: Q.out[v] = Vector((0, 0, 1))
        cap_ring(Q, rows[0], 2)
        for v in rows[-1]: Q.out[v] = Vector((0, 0, -1))
        cap_ring(Q, rows[-1], 2)
    Q.mirror()
    soles = Q.finish("SM_Char_Violet_Cloth_Soles", [M["latex"]])
    # chrome straps on the shafts
    bvh = bvh_of(upper); T = Piece()
    for ys in ((990.0, 996.0, 1002.0), (1064.0, 1071.0, 1078.0), (1136.0, 1143.0, 1150.0)):
        T.grid([T.cast_ring(bvh, leg_c(Y), FWD, LEFT, 24, 1.8) for Y in ys], wrap=True)
    T.mirror()
    straps = T.finish("SM_Char_Violet_Acc_BootStraps", [M["chrome"]], thick=1.6)
    return [upper, soles, straps]

def make_all(parts):
    M = {
        "skin": mat("MAT_Violet_Skin", (0.62, 0.60, 0.61), 0.0, 0.55),
        "latex": mat("MAT_Violet_Latex", (0.115, 0.10, 0.37), 0.0, 0.18),
        "chrome": mat("MAT_Violet_Chrome", (0.86, 0.87, 0.92), 1.0, 0.18),
        "gold": mat("MAT_Violet_Gold", (0.95, 0.66, 0.22), 1.0, 0.25),
        "eye": mat("MAT_Violet_Eye", (0.006, 0.006, 0.010), 0.0, 0.04),
        "mouth": mat("MAT_Violet_Mouth", (0.10, 0.05, 0.09), 0.0, 0.6),
    }
    body, head, gloves = parts["body"], parts["head"], parts["gloves"]
    for o, ms in ((body, ["skin"]), (head, ["skin", "mouth"]), (gloves, ["latex"])):
        for m in ms:                                  # never clear(): that resets the mouth faces' slot
            if M[m].name not in o.data.materials: o.data.materials.append(M[m])
    for e in parts["eyes"]:
        e.data.materials.clear(); e.data.materials.append(M["eye"])
    out = [make_top(body, M), make_shorts(body, M)] + make_trim(body, head, gloves, M) + make_boots(M)
    return out
