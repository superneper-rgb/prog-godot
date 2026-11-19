## Violet Starborn: splits the cage into body / head / gloves / boot shafts, subdivides, sculpts forms, cuts the mouth, builds the eyes.
import bpy, bmesh, math, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
vb = sys.modules["violet_body"]
S = vb.S
PX = lambda v: (v.co.x / S, 1330.0 - v.co.z / S, 530.0 - v.co.y / S)     # (X from centre, image Y, side-view x)

def col():
    c = bpy.data.collections.get("COL_Violet")
    if not c:
        c = bpy.data.collections.new("COL_Violet"); bpy.context.scene.collection.children.link(c)
    return c

def drop(name):
    o = bpy.data.objects.get(name)
    if o:
        me = o.data; bpy.data.objects.remove(o)
        if me and me.users == 0: bpy.data.batch_remove([me])

def obj_from_bm(bm, name, levels):
    """New object from a bmesh, Catmull-Clark subdivided `levels` times and applied."""
    drop(name)
    me = bpy.data.meshes.new(name); bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me); col().objects.link(ob)
    if levels:
        md = ob.modifiers.new("ss", 'SUBSURF'); md.levels = levels
        dg = bpy.context.evaluated_depsgraph_get()
        me2 = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
        ob.modifiers.clear(); ob.data = me2; bpy.data.meshes.remove(me); me2.name = name
    for p in ob.data.polygons: p.use_smooth = True
    return ob

def split(pred):
    """Copy of the cage keeping only faces for which pred(list of (part, idx)) is true."""
    bm = vb.build()
    lp = bm.verts.layers.int["part"]; li = bm.verts.layers.int["idx"]
    kill = [f for f in bm.faces if not pred([(v[lp], v[li]) for v in f.verts])]
    bmesh.ops.delete(bm, geom=kill, context='FACES')
    return bm

def edit(ob, fn):
    bm = bmesh.new(); bm.from_mesh(ob.data); bm.verts.ensure_lookup_table()
    r = fn(bm)
    bm.normal_update(); bm.to_mesh(ob.data); bm.free(); ob.data.update()
    return r

def smooth01(t):
    t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)

# ---------------------------------------------------------------- body
def sculpt_body(bm):
    for v in bm.verts:
        X, Y, D = PX(v)
        front = smooth01((D - 540.0) / 30.0); back = smooth01((520.0 - D) / 30.0)
        sgn = 1.0 if X >= 0 else -1.0
        # bust: teardrop, fuller below
        dx = (abs(X) - 43.0) / 41.0; dz = (Y - 388.0) / (58.0 if Y < 388.0 else 34.0)
        r = math.sqrt(dx * dx + dz * dz)
        f = (math.cos(min(r, 1.0) * math.pi / 2) ** 0.75) * front
        v.co.y -= 46.0 * S * f; v.co.z -= 6.0 * S * f; v.co.x += sgn * 6.0 * S * f
        # cleft between the glutes, spine groove
        win = smooth01((Y - 575.0) / 25.0) * smooth01((676.0 - Y) / 12.0)
        v.co.y -= 13.0 * S * math.exp(-(X / 9.0) ** 2) * win * back
        win = smooth01((Y - 300.0) / 30.0) * smooth01((575.0 - Y) / 40.0)
        v.co.y -= 4.0 * S * math.exp(-(X / 11.0) ** 2) * win * back
        # glutes: round each cheek a little
        dx = (abs(X) - 50.0) / 40.0; dz = (Y - 618.0) / 40.0
        v.co.y += 7.0 * S * math.exp(-(dx * dx + dz * dz)) * back
        # belly line
        win = smooth01((Y - 430.0) / 25.0) * smooth01((560.0 - Y) / 25.0)
        v.co.y += 2.0 * S * math.exp(-(X / 9.0) ** 2) * win * front

# ---------------------------------------------------------------- head (its cage, face and eyes are in violet_head.py)
def cut_mouth(bm, mouth_y, half_w=12.5):
    """Slits the mouth along the grid row nearest mouth_y, builds lips and a mouth bag. Returns info for the shape key."""
    bm.verts.ensure_lookup_table()
    cands = [v for v in bm.verts if abs(v.co.x) < 1e-5 and PX(v)[2] > 580 and 205 < PX(v)[1] < 230]
    v0 = min(cands, key=lambda v: abs(PX(v)[1] - mouth_y))
    def walk(v, sgn):
        out = []
        while abs(v.co.x) / S < half_w - 1.0:
            nb = [e.other_vert(v) for e in v.link_edges if (e.other_vert(v).co.x - v.co.x) * sgn > 1e-5]
            v = min(nb, key=lambda o: abs(o.co.z - v.co.z)); out.append(v)
        return out
    R = walk(v0, 1); L = walk(v0, -1)
    half_cols = len(R)
    row = L[::-1] + [v0] + R                       # left corner ... right corner
    rowY = PX(v0)[1]
    inner = row[1:-1]
    dup = {}
    for v in inner:
        d = bm.verts.new(v.co); dup[v] = d
    faces = set()
    for v in inner:
        for f in v.link_faces:
            if f.calc_center_median().z < v.co.z: faces.add(f)
    for f in list(faces):
        vs = [dup.get(v, v) for v in f.verts]
        bm.faces.remove(f); nf = bm.faces.new(vs); nf.smooth = True
    loose = [e for e in bm.edges if not e.link_faces]
    bmesh.ops.delete(bm, geom=loose, context='EDGES')
    lower = [dup[v] for v in inner]
    ring = row + lower[::-1]                       # closed loop round the slit
    n = len(ring)
    cx = Vector((0.0, v0.co.y, v0.co.z))
    def inset(depth, sc, gap):
        out = []
        for i, v in enumerate(ring):
            up = 1.0 if i < len(row) else -1.0
            edge = 0.0 if (i == 0 or i == len(row) - 1) else 1.0
            p = cx + (v.co - cx) * sc; p.y = v.co.y + depth * S; p.z += up * edge * gap * S
            out.append(bm.verts.new(p))
        return out
    r1 = inset(5.0, 0.92, 0.6); r2 = inset(14.0, 1.0, 5.0); r3 = inset(26.0, 0.8, 6.0)
    bag = []
    for a, b in ((ring, r1), (r1, r2), (r2, r3)):
        for i in range(n):
            bag.append(bm.faces.new((a[i], a[(i + 1) % n], b[(i + 1) % n], b[i])))
    # close the back: strip of quads between the upper and lower runs
    m = len(row)
    up = r3[:m]; lo = [r3[0]] + r3[m:][::-1] + [r3[m - 1]]       # same left-to-right order, ends shared
    for i in range(1, m - 2):
        bag.append(bm.faces.new((up[i], up[i + 1], lo[i + 1], lo[i])))
    bag.append(bm.faces.new((up[0], up[1], lo[1])));                # the two corners are triangles, deep inside the mouth
    bag.append(bm.faces.new((up[m - 2], up[m - 1], lo[m - 2])))
    for f in bag:
        if f: f.material_index = 1; f.smooth = True
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.verts.index_update()
    lower_set = set(lower)
    for i, v in enumerate(r1 + r2 + r3):
        if (i % n) >= m: lower_set.add(v)
    return {"rowY": rowY, "lower": lower_set, "row": row}

def make_all():
    body = obj_from_bm(split(lambda t: not all(p == 0 and i >= 15 for p, i in t)
                             and not all(p == 2 and i >= 2 for p, i in t)
                             and not all(p == 1 and i >= 8 for p, i in t)), "SM_Char_Violet_Body", 1)
    edit(body, sculpt_body)
    vh = sys.modules["violet_head"]
    head, m0 = vh.make_head(sys.modules[__name__])
    info = edit(head, lambda bm: {k: (v if k == "rowY" else [x.index for x in v]) for k, v in cut_mouth(bm, m0).items()})
    gl = obj_from_bm(split(lambda t: all(p == 2 and i >= 1 for p, i in t)), "SM_Char_Violet_Cloth_Gloves", 1)
    def inflate(bm, d):
        for v in bm.verts: v.co += v.normal * d
    edit(gl, lambda bm: inflate(bm, 1.6 * S))
    eyes = [vh.build_eye(sys.modules[__name__], head, 1, "SM_Char_Violet_Eye_L"), vh.build_eye(sys.modules[__name__], head, -1, "SM_Char_Violet_Eye_R")]
    return {"body": body, "head": head, "gloves": gl, "eyes": eyes, "mouth": info}
