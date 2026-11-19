# Builds the FOINT DOME's model (assets/foint_dome/foint_dome.glb) in headless Blender, to the user's concept art: a stepped mound of thick riveted armour plate, each tier
# a sloped plate roof over a recessed band of red windows; buttresses that climb it as jointed limbs (a steep leg, a cap plate over each tier, a fang at the top) with the red
# light set into a channel on every leg; a crown of curved fangs round a tall spike; the gate under its sign, with FOINT's curved thorn marks in metal.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/dome/build_foint_dome.py -- [--preview a.png [b.png]] [--fast] [--no-export]
# Everything is written in the dome's own space, the one the three.js game used (levels/hub/dome-plan.js): origin at the dome's centre on the street, y up, metres,
# -z towards the bridge (the gate), an angle th measured with 0 = +z and PI = the gate, so a point is (sin th * r, y, cos th * r). The footprint (tier radii, gate,
# buttress footings, lantern posts) is kept from dome-plan.js, because the hub's colliders were made from it.
# Vertex colours carry the painted light for levels/shaders/foint_dome_plate.gdshader: R = the plate's own tone / 1.6, G = occlusion (ray cast here), B = how much of the
# red light reaches it.
import bpy, bmesh, math, os, random, sys
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

TAU = math.pi * 2
BAYS = 24
STEP = TAU / BAYS
HALF = STEP / 2
PI = math.pi
R = random.Random(4646)

# the stepped mound, bottom up: radius of the wall, foot, top (the terrace), windows a bay, plates a bay. The lower three radii are dome-plan.js's (the colliders);
# the upper two step in further, so the outline rounds over like the concept's instead of running up a straight cone.
TIERS = [
    dict(r=46.0, y0=0.0, top=8.7, win=8, plates=3, pb=0.72, wr=0.42),
    dict(r=41.8, y0=8.7, top=15.3, win=4, plates=3, pb=0.5, wr=0.72),
    dict(r=37.2, y0=15.3, top=21.1, win=4, plates=2, pb=0.62, wr=0.66),
    dict(r=31.8, y0=21.1, top=25.9, win=3, plates=2, pb=0.68, wr=0.6),
    dict(r=25.6, y0=25.9, top=29.7, win=2, plates=1, pb=0.55, wr=0.6),
]
ROOF_Y = 29.7
DRUM_R = 19.4
GATE = dict(half=4.9, front=-50.6, back=-37.3, h=11.0)
BUTTRESS_SET = [(0.45, 55.0, 3, 5.2), (0.98, 54.5, 2, 4.4), (1.5, 55.0, 3, 4.8), (2.03, 54.5, 2, 4.4), (2.56, 54.5, 2, 4.4)]
BUTTRESSES = [b for o, rf, tk, w in BUTTRESS_SET for b in ((PI - o, rf, tk, w), (PI + o, rf, tk, w))] + [(0.0, 55.0, 3, 5.2)]
LANTERNS = [(34.45, -39.6), (-34.45, -39.6), (49.69, -17.04), (-49.69, -17.04), (51.55, 10.12), (-51.55, 10.12), (39.36, 34.77), (-39.36, 34.77),
            (15.13, 50.3), (-15.13, 50.3), (-6.56, -64.0), (6.56, -64.0)]      # where the exported flames burn (DomeFlames)
EMBLEM_BAYS = {2: [9, 15, 5, 19, 0], 4: [12, 9, 15, 6, 18, 3, 21, 0]}          # tier -> bays that carry a thorn mark instead of windows

PLATE, RED, SIGN, AMBER, HAZARD = range(5)
MAT_NAMES = ["dome_plate", "dome_red", "dome_sign", "dome_amber", "dome_hazard"]
MAT_VIEW = [(0.2, 0.2, 0.22, 1), (0.9, 0.05, 0.05, 1), (1.0, 0.1, 0.1, 1), (1.0, 0.6, 0.15, 1), (0.6, 0.45, 0.05, 1)]

VERTS = []                                # every vertex (Vector), dome space
FACES = [[] for _ in MAT_NAMES]           # per material: (indices, tone, uvs or None)
EMIT = []                                 # red light for the bounce bake: (centre, normal, area * tone)
TIPS = []                                 # spire tips, for the red beacons
YV = Vector((0, 1, 0))


def V3(x, y, z):
    return Vector((x, y, z))


def P(th, r, y, s=0.0):
    """a point at angle th, radius r, height y, and s metres along the tangent"""
    return Vector((math.sin(th) * r + math.cos(th) * s, y, math.cos(th) * r - math.sin(th) * s))


def wrap(a):
    return math.atan2(math.sin(a), math.cos(a))


def newell(pts):
    n = Vector((0, 0, 0))
    for i, a in enumerate(pts):
        b = pts[(i + 1) % len(pts)]
        n += Vector(((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)))
    return n


def face(pts, out, mat=PLATE, tone=1.0, uv=None):
    """one loose face, turned to face `out`"""
    pts = [Vector(p) for p in pts]
    if newell(pts).dot(out) < 0:
        pts.reverse()
        if uv:
            uv = uv[::-1]
    i0 = len(VERTS)
    VERTS.extend(pts)
    FACES[mat].append((list(range(i0, i0 + len(pts))), tone, uv))
    if mat in (RED, SIGN):
        n = newell(pts)
        c = sum(pts, Vector((0, 0, 0))) / len(pts)
        EMIT.append((c, n.normalized(), n.length * 0.5 * tone))


def emit(bm, mat, tone, edge_faces=()):
    bm.verts.index_update()
    i0 = len(VERTS)
    VERTS.extend(v.co.copy() for v in bm.verts)
    worn = set(edge_faces)
    for f in bm.faces:
        FACES[mat].append(([i0 + v.index for v in f.verts], min(tone * 1.32 + 0.06, 1.6) if f in worn else tone, None))


def finish(bm, bevel=0.0, tone=1.0, mat=PLATE):
    """outward normals, a chamfer on every hard edge (its faces lighter: the worn edge of a plate), then into the pile"""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    new = ()
    if bevel > 0:
        edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > 0.3]
        if edges:
            before = set(bm.faces)
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type='OFFSET', segments=1, profile=0.5, affect='EDGES', clamp_overlap=True)
            new = [f for f in bm.faces if f not in before and len(f.verts) <= 4 and min(e.calc_length() for e in f.edges) < bevel * 2.2]
    emit(bm, mat, tone, new)
    bm.free()


def hull(pts, bevel=0.0, tone=1.0, mat=PLATE):
    bm = bmesh.new()
    for p in pts:
        bm.verts.new(p)
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bmesh.ops.dissolve_limit(bm, angle_limit=0.02, verts=bm.verts[:], edges=bm.edges[:])
    finish(bm, bevel, tone, mat)


def prism(prof, O, U, V, W, w, bevel=0.0, tone=1.0, mat=PLATE):
    """a 2D profile [(u, v)...] in the plane (U, V) at O, extruded w along W, centred. Returns the point function (u, v, s)."""
    pt = lambda u, v, s: O + U * u + V * v + W * s
    bm = bmesh.new()
    a = [bm.verts.new(pt(u, v, -w / 2)) for u, v in prof]
    b = [bm.verts.new(pt(u, v, w / 2)) for u, v in prof]
    bm.faces.new(a)
    bm.faces.new(b[::-1])
    for i in range(len(prof)):
        j = (i + 1) % len(prof)
        bm.faces.new((a[i], a[j], b[j], b[i]))
    finish(bm, bevel, tone, mat)
    return pt


def obox(O, X, Y, Z, hx, hy, hz, bevel=0.0, tone=1.0, mat=PLATE):
    prism([(-hx, -hy), (hx, -hy), (hx, hy), (-hx, hy)], O, X, Y, Z, hz * 2, bevel, tone, mat)


def box(cx, cy, cz, sx, sy, sz, bevel=0.0, tone=1.0, yaw=0.0):
    c, s = math.cos(yaw), math.sin(yaw)
    obox(V3(cx, cy, cz), V3(c, 0, -s), V3(0, 1, 0), V3(s, 0, c), sx / 2, sy / 2, sz / 2, bevel, tone)


def lathe(prof, th0, th1, n, bevel=0.0, tone=1.0, mat=PLATE):
    """a closed profile [(r, y)...] swept round the dome from th0 to th1 in n facets; capped, or a whole ring when it goes all the way round"""
    closed = abs((th1 - th0) - TAU) < 1e-6
    bm = bmesh.new()
    rings = [[bm.verts.new(P(th0 + (th1 - th0) * i / n, r, y)) for r, y in prof] for i in range(n if closed else n + 1)]
    m = len(prof)
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % len(rings)]
        for j in range(m):
            k = (j + 1) % m
            bm.faces.new((a[j], a[k], b[k], b[j]))
    if not closed:
        bm.faces.new(rings[0])
        bm.faces.new(rings[-1][::-1])
    finish(bm, bevel, tone, mat)


def bolt(C, n, r=0.17, h=0.09, tone=1.3):
    n = n.normalized()
    t = n.cross(V3(0, 1, 0))
    if t.length < 0.1:
        t = n.cross(V3(1, 0, 0))
    t.normalize()
    b = n.cross(t)
    lo = [C + (t * math.cos(i * TAU / 6) + b * math.sin(i * TAU / 6)) * r for i in range(6)]
    hi = [C + (p - C) * 0.78 + n * h for p in lo]
    for i in range(6):
        j = (i + 1) % 6
        face([lo[i], lo[j], hi[j], hi[i]], (lo[i] + lo[j]) / 2 - C, PLATE, tone * 0.8)
    face(hi, n, PLATE, tone)


def rivet(C, n, r=0.1, h=0.07, tone=1.35):
    """a small square-headed rivet: the rows that edge every plate in the concept (five faces: cheap enough to use by the hundred)"""
    n = n.normalized()
    t = n.cross(V3(0, 1, 0))
    if t.length < 0.1:
        t = n.cross(V3(1, 0, 0))
    t.normalize()
    b = n.cross(t)
    lo = [C + t * (sx * r) + b * (sy * r) for sx, sy in ((1, 1), (-1, 1), (-1, -1), (1, -1))]
    hi = [C + (p - C) * 0.6 + n * h for p in lo]
    for i in range(4):
        j = (i + 1) % 4
        face([lo[i], lo[j], hi[j], hi[i]], (lo[i] + lo[j]) / 2 - C, PLATE, tone * 0.75)
    face(hi, n, PLATE, tone)


def rivets(a, b, n, step=1.0, inset=0.4, r=0.1):
    """a row of rivets from a to b on a face whose normal is n"""
    d = b - a
    L = d.length
    if L < inset * 2:
        return
    k = max(1, int((L - inset * 2) / step))
    for i in range(k + 1):
        rivet(a + d * ((inset + (L - inset * 2) * i / k) / L), n, r)


def strip(a, b, wdir, w, out, mat=RED, tone=1.0, lift=0.03):
    """a lit strip from a to b, w wide across wdir, standing `lift` proud of the face it lies on"""
    o = out.normalized() * lift
    h = wdir.normalized() * (w / 2)
    face([a - h + o, b - h + o, b + h + o, a + h + o], out, mat, tone)


def blade(p0, p1, p2, s, b0, t0, n=7, pw=0.8, tone=0.95, seam=0.0, beacon=False):
    """A fang: the concept's blades. A centre line curving from p0 through the pull of p1 to the point p2, a sword section (flat flanks, a bevel down to each knife
    edge, the bevels worn lighter) that narrows to the point. s: the way its thickness faces; b0: half its breadth at the root; t0: half its thickness there.
    seam: how far up (0..1) a red seam runs on both flanks."""
    s = s.normalized()
    rings, cs, es, sds, bs = [], [], [], [], []
    for i in range(n):
        u = i / n * 0.96
        c = p0 * (1 - u) ** 2 + p1 * (2 * u * (1 - u)) + p2 * (u * u)
        tan = ((p1 - p0) * (2 * (1 - u)) + (p2 - p1) * (2 * u)).normalized()
        e = s.cross(tan).normalized()
        sd = tan.cross(e).normalized()
        if sd.dot(s) < 0:
            sd = -sd
        b = b0 * ((1 - u) ** pw) + b0 * 0.05
        t = t0 * (1 - 0.72 * u)
        rings.append([c + e * b, c + e * (b * 0.5) + sd * t, c - e * (b * 0.5) + sd * t, c - e * b, c - e * (b * 0.5) - sd * t, c + e * (b * 0.5) - sd * t])
        cs.append(c)
        es.append(e)
        sds.append(sd)
        bs.append(b)
    for i in range(n - 1):
        mid = (cs[i] + cs[i + 1]) / 2
        for j in range(6):
            k = (j + 1) % 6
            q = [rings[i][j], rings[i][k], rings[i + 1][k], rings[i + 1][j]]
            face(q, sum(q, Vector((0, 0, 0))) / 4 - mid, PLATE, tone * 1.34 if j in (0, 2, 3, 5) else tone)
        if seam > 0 and (i + 1) / n <= seam and i >= 1:
            for sg, (ja, jb) in ((1, (1, 2)), (-1, (4, 5))):
                m0, m1 = (rings[i][ja] + rings[i][jb]) / 2, (rings[i + 1][ja] + rings[i + 1][jb]) / 2
                w0, w1 = bs[i] * 0.13, bs[i + 1] * 0.13
                o0, o1 = sds[i] * (sg * 0.04), sds[i + 1] * (sg * 0.04)
                face([m0 - es[i] * w0 + o0, m0 + es[i] * w0 + o0, m1 + es[i + 1] * w1 + o1, m1 - es[i + 1] * w1 + o1], sds[i] * sg, RED, 1.0)
    for j in range(6):
        k = (j + 1) % 6
        q = [rings[-1][j], rings[-1][k], p2]
        face(q, sum(q, Vector((0, 0, 0))) / 3 - cs[-1], PLATE, tone * 1.34 if j in (0, 2, 3, 5) else tone)
    face(rings[0], p0 - p1, PLATE, tone * 0.6)
    if beacon:
        TIPS.append(Vector(p2))


def knife(O, X, Y, Z, w, h, t, apex=0.2, shoulder=0.2, tone=0.95, seam=0.0, beacon=False):
    """The concept's blade: a rigid straight-edged slab cut to a point. Its back edge runs straight up (Y) almost to the tip, its other edge is one long slant from a low
    shoulder to the point, a raised plate on both faces, rivets along its root. O: the middle of its root; X: from the back edge towards the slanted one; Z: its
    thickness. apex: where the point sits across the width (0 = over the back edge); seam: how far up a red seam runs beside the back edge (0 = none)."""
    X, Y, Z = X.normalized(), Y.normalized(), Z.normalized()
    ax = -w / 2 + w * apex
    prism([(-w / 2, 0), (w / 2, 0), (w / 2, h * shoulder), (ax, h), (-w / 2, h * 0.9)], O, X, Y, Z, t, min(0.24, t * 0.18), tone)
    prism([(-w / 2 + 0.4, 0.45), (w / 2 - 0.55, 0.45), (w / 2 - 0.6, h * shoulder + 0.15), (ax + 0.03, h * 0.9), (-w / 2 + 0.4, h * 0.83)], O, X, Y, Z, t + 0.26, 0.07, tone * 1.14)
    for sg in (-1, 1):
        rivets(O + X * (-w / 2 + 0.3) + Y * 0.22 + Z * (sg * t / 2), O + X * (w / 2 - 0.3) + Y * 0.22 + Z * (sg * t / 2), Z * sg, 0.7, 0.0)
        if seam > 0:
            strip(O + X * (-w / 2 + 0.85) + Y * (h * 0.1) + Z * (sg * (t / 2 + 0.13)), O + X * (-w / 2 + 0.8) + Y * (h * seam) + Z * (sg * (t / 2 + 0.13)), X, 0.28, Z * sg, RED, 1.0)
    if beacon:
        TIPS.append(O + X * ax + Y * h)


def thorn(C, out, right, up, size, tone=1.3, n=5):
    """FOINT's thorn mark in metal, as the concept draws it: a tall spike out of a heart, two great horns sweeping out and hooking up, a shorter pair inside them, curls
    hooking down underneath, a long thin spike to each side and one hanging below. A red plate glows behind it."""
    out, right, up = out.normalized(), right.normalized(), up.normalized()
    pt = lambda a, b, d=0.12: C + right * (a * size) + up * (b * size) + out * (d + 0.03 * size)
    bw, bt = 0.085 * size, 0.06 * size
    blade(pt(0, 0.05), pt(0, 0.5), pt(0, 1.05, 0.2), out, bw * 1.15, bt * 1.2, n, 0.9, tone)
    blade(pt(0, -0.05), pt(0, -0.45), pt(0, -0.86, 0.2), out, bw, bt, n, 0.9, tone)
    for sg in (-1, 1):
        blade(pt(sg * 0.06, 0.0), pt(sg * 0.78, -0.06), pt(sg * 0.86, 0.8, 0.2), out, bw, bt, n + 1, 0.75, tone)            # the great horns
        blade(pt(sg * 0.05, 0.1), pt(sg * 0.4, 0.14), pt(sg * 0.38, 0.66, 0.2), out, bw * 0.8, bt * 0.8, n, 0.75, tone)     # the inner pair
        blade(pt(sg * 0.07, -0.06), pt(sg * 0.5, -0.04), pt(sg * 0.6, -0.5, 0.2), out, bw * 0.8, bt * 0.8, n, 0.75, tone)   # the curls hooking down and out
        blade(pt(sg * 0.1, 0.0), pt(sg * 0.6, 0.02), pt(sg * 1.12, 0.03, 0.2), out, bw * 0.6, bt * 0.7, n - 1, 0.9, tone)   # the long side spike
    s = size
    hull([C + right * 0.17 * s, C - right * 0.17 * s, C + up * 0.28 * s, C - up * 0.28 * s, C + out * (0.2 * s + 0.14), C - out * 0.1], 0.0, tone * 1.05)
    face([C + up * 0.7 * s + out * 0.03, C + right * 0.46 * s + out * 0.03, C - up * 0.56 * s + out * 0.03, C - right * 0.46 * s + out * 0.03], out, RED, 0.6)


def panel(O, X, Y, N, hx, hy, tone=1.08, rise=0.1, riv=0.9):
    """what makes a face read as armour: a raised inner plate standing `rise` proud of it, and a row of rivets round it on the border left over (riv: their spacing, 0 = none)"""
    obox(O + N * (rise / 2), X, Y, N, hx, hy, rise / 2, 0.045, tone)
    if riv > 0:
        m = 0.24
        for sg in (-1, 1):
            rivets(O + X * (-hx - m) + Y * (sg * (hy + m)), O + X * (hx + m) + Y * (sg * (hy + m)), N, riv, 0.0)
            rivets(O + X * (sg * (hx + m)) + Y * (-hy + riv * 0.6), O + X * (sg * (hx + m)) + Y * (hy - riv * 0.6), N, riv, 0.0)


# ============================================================================================================== the mound
def roof_rise(k):
    """how far the plate roof of the tier under tier k climbs up tier k's wall"""
    return 0.0 if k == 0 else min(1.5, 0.22 * (TIERS[k]["top"] - TIERS[k]["y0"]))


def tier_profile(k):
    T = TIERS[k]
    H = T["top"] - T["y0"]
    yp = T["y0"] + (0.19 * H if k == 0 else roof_rise(k) + 0.2)
    return T["r"], T["y0"], T["top"], H, yp, T["y0"] + T["pb"] * H      # radius, foot, top, height, foot of the window band, underside of the parapet


def in_gate(k, th, margin=0.0):
    return k < 2 and abs(wrap(th - PI)) < HALF + margin


def build_mound():
    IN = 0.9                                                                       # how deep the window band sits behind the armour
    for k in range(len(TIERS)):
        Rk, y0, top, H, yp, yb = tier_profile(k)
        nxt = TIERS[k + 1]["r"] if k + 1 < len(TIERS) else DRUM_R - 0.4
        rise = roof_rise(k + 1) if k + 1 < len(TIERS) else 0.9
        gate = k < 2
        a0, a1 = (PI + HALF, PI - HALF + TAU) if gate else (0.0, TAU)
        n_core = 92 if gate else 96
        # the body behind the armour: the dark wall of the window band, and the deck under the roof plates
        lathe([(nxt - IN - 0.4, y0), (Rk - IN, y0), (Rk - IN, top), (nxt - IN - 0.4, top)], a0, a1, n_core, 0.0, 0.3)
        # the armour, plate by plate with a joint between: the plinth at the street, the heavy parapet over the windows (a raised inner plate on its face, a rivet at
        # each corner), and the tier's roof: sloped plates from the parapet up to the next wall, which is what rounds the mound over
        n_pl = BAYS * TIERS[k]["plates"]
        gap = 0.16 / Rk
        for i in range(n_pl):
            t0, t1 = i * TAU / n_pl - HALF, (i + 1) * TAU / n_pl - HALF
            if gate and in_gate(k, (t0 + t1) / 2):
                continue
            tone = 0.86 + R.random() * 0.2
            sub = 2 if TIERS[k]["plates"] > 1 else 4
            if k == 0:
                lathe([(Rk - IN, y0), (Rk + 0.4, y0), (Rk + 0.4, yp - 0.35), (Rk + 0.05, yp), (Rk - IN, yp)], t0 + gap, t1 - gap, sub, 0.07, tone * 0.92)
            lathe([(Rk - IN, yb), (Rk + 0.25, yb), (Rk + 0.95, yb + 0.6), (Rk + 0.95, top - 0.45), (Rk + 0.35, top + 0.32), (Rk - IN - 0.5, top + 0.32), (Rk - IN - 0.5, top - 0.2), (Rk - IN, top - 0.2)],
                  t0 + gap, t1 - gap, sub, 0.1, tone)
            ya, yc = yb + 1.0, top - 0.85
            if yc - ya > 0.5:
                pin = 0.42 / Rk
                lathe([(Rk + 0.9, ya), (Rk + 1.07, ya + 0.1), (Rk + 1.07, yc - 0.1), (Rk + 0.9, yc)], t0 + gap + pin, t1 - gap - pin, sub, 0.0, tone * 1.12)
            tm = (t0 + t1) / 2
            for sgn in (-1, 1):
                s = sgn * ((t1 - t0) * Rk / 2 - 0.3)
                for yy in (yb + 0.82, top - 0.66):
                    rivet(P(tm, Rk + 0.95, yy, s), P(tm, 1, 0))
            rtone = 0.8 + R.random() * 0.22
            ro, ri = Rk - IN - 0.42, nxt + 0.5
            lathe([(ro, top + 0.05), (ro, top + 0.42), (ri, top + rise + 0.3), (ri, top + rise - 0.05)], t0 + gap * 1.3, t1 - gap * 1.3, sub, 0.05, rtone)
            if k < 3:                                                              # a raised rib down the middle of each roof plate
                lathe([(ro - 0.25, top + 0.4), (ro - 0.25, top + 0.6), (ri + 0.2, top + rise + 0.46), (ri + 0.2, top + rise + 0.26)], tm - 0.22 / Rk, tm + 0.22 / Rk, 1, 0.04, rtone * 1.15)
        # the clamps: a block gripping the parapet over every joint between bays, on a pier that runs down through the window band
        cw = 0.95 if k < 3 else 0.75
        for b in range(BAYS):
            th = (b + 0.5) * STEP
            if gate and in_gate(k, th, 0.02):
                continue
            U, W = P(th, 1, 0), P(th, 0, 0, 1)
            O = V3(0, 0, 0)
            prism([(Rk + 0.1, yb - 0.55), (Rk + 1.3, yb + 0.35), (Rk + 1.3, top - 0.3), (Rk + 0.7, top + 0.75), (Rk - IN - 0.7, top + 0.75), (Rk - IN - 0.7, yb - 0.55)], O, U, YV, W, cw * 2, 0.13, 1.02)
            prism([(Rk - IN - 0.2, yp - 0.1), (Rk + 0.3, yp - 0.1), (Rk + 0.3, yb + 0.1), (Rk - IN - 0.2, yb + 0.1)], O, U, YV, W, cw * 2 + 0.5, 0.1, 0.8)
            fh = (top - 0.3 - (yb + 0.35)) / 2
            if fh > 0.75:
                panel(P(th, Rk + 1.3, (yb + top) / 2 + 0.02), W, YV, U, cw - 0.42, fh - 0.4, 1.12, 0.09, 0.0)
            for s in (-cw + 0.2, cw - 0.2):
                for yy in (yb + 0.62, top - 0.56):
                    rivet(P(th, Rk + 1.3, yy, s), U)
        # the window band: red slots between dark mullions (each slot burning low and fading up), a sill and a head bar; a bay that carries a thorn is plated over
        wins = TIERS[k]["win"]
        Rr = Rk - IN
        y_lo, y_hi = yp + 0.3, yb - 0.3
        for b in range(BAYS):
            th = b * STEP
            if gate and in_gate(k, th):
                continue
            half_arc = STEP * Rr / 2 - cw - 0.5                                    # metres either side of the bay's middle, clear of the piers
            if b in EMBLEM_BAYS.get(k, ()):
                da = half_arc / Rr
                lathe([(Rr - 0.1, yp), (Rr + 0.42, yp), (Rr + 0.42, yb), (Rr - 0.1, yb)], th - da, th + da, 2, 0.08, 0.92)
                thorn(P(th, Rr + 0.44, (yp + yb) / 2 - 0.1), P(th, 1, 0), P(th, 0, 0, 1), YV, min(2.1, (yb - yp) * 0.5), 1.3, 4)
                continue
            if wins == 0:
                continue
            slot = half_arc * 2 / wins
            ww = slot * TIERS[k]["wr"]
            ym = y_lo + (y_hi - y_lo) * 0.55
            for j in range(wins):
                s = -half_arc + (j + 0.5) * slot
                tn = 0.82 + 0.18 * R.random()
                face([P(th, Rr + 0.07, y_lo, s - ww / 2), P(th, Rr + 0.07, y_lo, s + ww / 2), P(th, Rr + 0.07, ym, s + ww / 2), P(th, Rr + 0.07, ym, s - ww / 2)], P(th, 1, 0), RED, tn)
                face([P(th, Rr + 0.07, ym, s - ww / 2), P(th, Rr + 0.07, ym, s + ww / 2), P(th, Rr + 0.07, y_hi, s + ww / 2), P(th, Rr + 0.07, y_hi, s - ww / 2)], P(th, 1, 0), RED, tn * 0.5)
            for j in range(wins + 1):                                              # mullions, the middle one heavier: two groups of windows a bay
                s = -half_arc + j * slot
                mw = (slot - ww) * (1.25 if j == wins // 2 and wins >= 4 else 0.5) + 0.06
                obox(P(th, Rr + 0.24, (y_lo + y_hi) / 2, s), P(th, 0, 0, 1), YV, P(th, 1, 0), mw / 2 + 0.04, (y_hi - y_lo) / 2 + 0.2, 0.3, 0.05, 0.62)
            da = (half_arc + 0.1) / Rr
            for ya, yc in ((yp, y_lo + 0.02), (y_hi - 0.02, yb)):                  # sill and head
                lathe([(Rr - 0.05, ya), (Rr + 0.5, ya), (Rr + 0.5, yc), (Rr - 0.05, yc)], th - da, th + da, 2, 0.05, 0.7)
    # the drum the crown stands in, its clamps, the deck inside it
    lathe([(15.6, ROOF_Y - 0.2), (DRUM_R, ROOF_Y - 0.2), (DRUM_R, ROOF_Y + 1.7), (DRUM_R - 0.7, ROOF_Y + 2.5), (15.6, ROOF_Y + 2.5)], 0.0, TAU, 48, 0.12, 0.95)
    lathe([(2.0, ROOF_Y - 0.4), (16.0, ROOF_Y - 0.4), (16.0, ROOF_Y + 0.9), (2.0, ROOF_Y + 0.9)], 0.0, TAU, 24, 0.0, 0.4)
    for i in range(12):
        th = i * TAU / 12
        obox(P(th, DRUM_R - 0.2, ROOF_Y + 1.3), P(th, 0, 0, 1), YV, P(th, 1, 0), 0.8, 1.5, 0.6, 0.12, 1.05)
        for s in (-0.45, 0.45):
            rivet(P(th, DRUM_R + 0.4, ROOF_Y + 1.5, s), P(th, 1, 0))
    # the big thorn up the front, over the gate
    thorn(P(PI, TIERS[3]["r"] + 1.05, 24.0), V3(0, 0, -1), V3(-1, 0, 0), YV, 2.7)


# ============================================================================================================== the buttresses
def edge_normal(prof, i):
    area = sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(prof, prof[1:] + prof[:1]))
    (u0, v0), (u1, v1) = prof[i], prof[(i + 1) % len(prof)]
    L = math.hypot(u1 - u0, v1 - v0) or 1
    return ((v1 - v0) / L, -(u1 - u0) / L) if area > 0 else (-(v1 - v0) / L, (u1 - u0) / L)


def louvres(at, out, hs, y0, y1, glow=0.5):
    """a louvred vent glowing red from inside. at(s, y, d) -> point (d out of the face); hs: half its width"""
    face([at(-hs, y0, 0.02), at(hs, y0, 0.02), at(hs, y1, 0.02), at(-hs, y1, 0.02)], out, RED, glow)
    y = y0
    while y < y1 - 0.05:
        hull([at(-hs - 0.08, y, 0), at(hs + 0.08, y, 0), at(-hs - 0.08, y + 0.15, 0), at(hs + 0.08, y + 0.15, 0), at(-hs - 0.08, y - 0.04, 0.2), at(hs + 0.08, y - 0.04, 0.2), at(-hs - 0.08, y + 0.08, 0.2), at(hs + 0.08, y + 0.08, 0.2)], 0.0, 0.55)
        y += 0.27
    for sgn in (-1, 1):
        obox((at(sgn * (hs + 0.22), y0, 0.08) + at(sgn * (hs + 0.22), y1, 0.08)) / 2, (at(1, y0, 0) - at(0, y0, 0)), YV, out.normalized(), 0.1, (y1 - y0) / 2 + 0.12, 0.1, 0.03, 0.9)


def hazard(at, out, hs, v0, v1, vlen):
    """the hazard band in its frame. at(s, v, d): s across, v up the face (0..1), d out of it; vlen: the face's length in metres"""
    face([at(-hs, v0, 0.04), at(hs, v0, 0.04), at(hs, v1, 0.04), at(-hs, v1, 0.04)], out, HAZARD, 1.0, [(-hs, 0.0), (hs, 0.0), (hs, (v1 - v0) * vlen), (-hs, (v1 - v0) * vlen)])
    dv = 0.1 / vlen
    for v in (v0, v1):
        hull([at(-hs - 0.12, v - dv, 0), at(hs + 0.12, v - dv, 0), at(hs + 0.12, v + dv, 0), at(-hs - 0.12, v + dv, 0), at(-hs - 0.12, v - dv, 0.15), at(hs + 0.12, v - dv, 0.15), at(hs + 0.12, v + dv, 0.15), at(-hs - 0.12, v + dv, 0.15)], 0.03, 0.95)
    for sg in (-1, 1):
        hull([at(sg * (hs + 0.02), v0, 0), at(sg * (hs + 0.2), v0, 0), at(sg * (hs + 0.2), v1, 0), at(sg * (hs + 0.02), v1, 0), at(sg * (hs + 0.02), v0, 0.15), at(sg * (hs + 0.2), v0, 0.15), at(sg * (hs + 0.2), v1, 0.15), at(sg * (hs + 0.02), v1, 0.15)], 0.03, 0.95)


def buttress(O, U, W, w, A, B, tall, web_foot=None):
    """One buttress, as the concept builds it: a single straight diagonal from A (the top of its footing) to B (where it lands on a tier), made of four different
    pieces, bottom to top. 1: a rectangular arch (two rails and a post at each end) with the red light lying in the middle of the recess it frames, on both flanks.
    2: a big riveted plate that comes over the top of the arch and runs on up the lean, a plain body under it. 3: a smaller hood lying flat on the plate's top end,
    reaching back onto the tier. 4, on the tall ones only: a straight blade standing out of the hood; the short ones end flat. Under all of it a wall down to the street."""
    du, dv = B[0] - A[0], B[1] - A[1]
    L = math.hypot(du, dv)
    D = (U * du + YV * dv).normalized()
    nu, nv = -dv / L, du / L
    if nv < 0:
        nu, nv = -nu, -nv
    N = (U * nu + YV * nv).normalized()
    at = lambda f, n=0.0, s=0.0: O + U * (A[0] + du * f) + YV * (A[1] + dv * f) + N * n + W * s
    sec = lambda f0, f1, n0, n1, hw, bevel, tone: prism([(-hw, n0), (hw, n0), (hw, n1), (-hw, n1)], at((f0 + f1) / 2), W, N, D, (f1 - f0) * L, bevel, tone)
    if web_foot:
        prism(web_foot + [(A[0] - nu * 0.6, A[1] - nv * 0.6), (B[0] - nu * 0.6, B[1] - nv * 0.6), (B[0] - 2.5, B[1] - 1.5)], O, U, YV, W, w * 0.5, 0.1, 0.6)
    # 1: the arch
    sec(0.0, 0.46, -3.6, -2.8, w / 2, 0.12, 0.94)
    sec(0.02, 0.46, -1.0, -0.1, w / 2, 0.12, 1.0)
    for f in (0.035, 0.445):
        obox(at(f, -1.85), W, N, D, w / 2, 1.75, 0.42, 0.12, 0.97)
    for sg in (-1, 1):
        s = sg * (w * 0.25 + 0.02)
        face([at(0.07, -2.8, s), at(0.41, -2.8, s), at(0.41, -1.0, s), at(0.07, -1.0, s)], W * sg, PLATE, 0.22)
        strip(at(0.1, -1.9, s), at(0.39, -1.9, s), N, 0.42, W * sg, RED, 1.0, 0.04)
        rivets(at(0.06, -0.1, sg * w * 0.38), at(0.42, -0.1, sg * w * 0.38), N, 0.8, 0.0)
        rivets(at(0.06, -3.2, sg * w / 2), at(0.42, -3.2, sg * w / 2), W * sg, 0.8, 0.0)
        rivets(at(0.06, -0.55, sg * w / 2), at(0.42, -0.55, sg * w / 2), W * sg, 0.8, 0.0)
    # 2: the plate over it, and the body under the plate
    f0, f1 = 0.36, 0.93
    hl = (f1 - f0) * L / 2
    prism([(-hl, -0.9), (hl, -0.9), (hl, 0.5), (-hl + 1.0, 0.5), (-hl, -0.25)], at((f0 + f1) / 2), D, N, W, w + 0.5, 0.17, 1.0)
    for sgd in (-1, 1):
        panel(at((f0 + f1) / 2, 0.5) + D * (sgd * hl * 0.5 + 0.25), D, W, N, hl * 0.5 - 0.6, w / 2 - 0.2, 1.1, 0.1, 0.8)
    sec(0.46, 0.93, -3.3, -0.9, w * 0.4, 0.1, 0.84)
    for sg in (-1, 1):
        panel(at(0.7, -2.1, sg * w * 0.4), D, N, W * sg, L * 0.17, 0.62, 1.04, 0.08, 0.9)
        rivets(at(f0 + 0.03, -0.3, sg * (w / 2 + 0.25)), at(f1 - 0.02, -0.3, sg * (w / 2 + 0.25)), W * sg, 0.9, 0.0, 0.12)
    # 3: the hood
    prism([(B[0] + 2.3, B[1] + 0.15), (B[0] + 2.7, B[1] + 0.7), (B[0] + 2.0, B[1] + 1.5), (B[0] - 2.8, B[1] + 1.5), (B[0] - 2.8, B[1] + 0.15)], O, U, YV, W, w * 0.8, 0.17, 1.04)
    panel(O + U * (B[0] - 0.4) + YV * (B[1] + 1.5), U, W, YV, 1.75, w * 0.4 - 0.4, 1.1, 0.1, 0.7)
    # 4: the blade: the buttress's own diagonal carried on past the hood, its top edge the plate's line, cut to a point from underneath
    if tall:
        knife(at(0.99, -1.1), -N, D, W, 2.7, 9.5, w * 0.5, 0.1, 0.22, 0.95, 0.0, True)

def build_buttresses():
    for th, rf, tk, w in BUTTRESSES:
        U, W, O = P(th, 1, 0), P(th, 0, 0, 1), V3(0, 0, 0)
        # tall and short alternate round the dome, the pair by the gate short (as the concept has them): a short one lands flat on the second tier, a tall one climbs to
        # the third and carries a blade
        tall = tk == 2 or th == 0.0
        Tl = TIERS[2 if tall else 1]
        buttress(O, U, W, w, (rf - 2.6, 5.5), (Tl["r"] + 1.2, Tl["top"] + 1.3), tall, [(TIERS[0]["r"] - 0.6, 0), (rf - 3.0, 0)])
        # the footing: a wide plinth, on it a wedge with a sloped brow that carries the hazard band; a red bar low on the plinth, a vent in each flank
        wf = w / 2 + 0.9
        prism([(rf - 6.8, 0), (rf + 0.5, 0), (rf + 0.5, 0.95), (rf + 0.1, 1.35), (rf - 6.8, 1.35)], O, U, YV, W, wf * 2 + 0.8, 0.16, 0.9)
        prism([(rf - 6.4, 1.3), (rf, 1.3), (rf, 2.7), (rf - 2.4, 5.7), (rf - 6.4, 5.7)], O, U, YV, W, wf * 2, 0.26, 0.97)
        sn = (U * 3.0 + YV * 2.4).normalized()
        sl = lambda s, v, d: P(th, rf - 2.4 * v, 2.7 + 3.0 * v, s) + sn * d
        hazard(sl, sn, wf - 0.75, 0.1, 0.5, 3.84)
        panel(sl(0, 0.76, 0), W, (U * -2.4 + YV * 3.0).normalized(), sn, wf - 0.9, 0.48, 1.1, 0.1, 0.7)
        strip(P(th, rf + 0.5, 0.62, -wf + 0.3), P(th, rf + 0.5, 0.62, wf - 0.3), YV, 0.24, U, RED, 0.9)
        panel(P(th, rf, 2.0), W, YV, U, wf - 0.7, 0.36, 1.08, 0.08, 0.0)
        rivets(P(th, rf, 1.56, -wf + 0.3), P(th, rf, 1.56, wf - 0.3), U, 0.7, 0.0)
        for sg in (-1, 1):
            side = lambda s, y, d, sg=sg: P(th, rf - 4.3 + s, y, sg * (wf + d))
            louvres(side, W * sg, 1.0, 2.5, 4.3, 0.5)
            rivets(P(th, rf - 6.1, 1.75, sg * wf), P(th, rf - 0.5, 1.75, sg * wf), W * sg, 0.8, 0.0)
            rivets(P(th, rf - 6.1, 5.2, sg * wf), P(th, rf - 2.6, 5.2, sg * wf), W * sg, 0.8, 0.0)


# ============================================================================================================== the gate
def text_mesh(txt, font):
    cu = bpy.data.curves.new("txt", 'FONT')
    cu.body = txt
    cu.font = font
    cu.size = 1.0
    cu.extrude = 0.06
    cu.space_character = 1.06
    ob = bpy.data.objects.new("txt", cu)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    vs = [v.co.copy() for v in me.vertices]
    fs = [list(p.vertices) for p in me.polygons]
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    return vs, fs


def build_gate():
    """The entrance, to the concept's front elevation. Bottom to top: the door in a mouth with cut top corners, a slim riveted jamb and one heavy leg each side running
    down and out to a blocky foot with a marker light; the sign in a thick angular frame; a yoke of two flat shoulders stepping up to the middle; and on it two straight
    knives standing upright and close together either side of a dark column with a red slit. The banners hang outside the legs, each over a vent box."""
    Y, X, ZP, FZ = YV, V3(1, 0, 0), V3(0, 0, 1), V3(0, 0, -1)
    for s in (-1, 1):
        XS = V3(s, 0, 0)
        prism([(37.3, 0), (50.4, 0), (50.4, 11.2), (37.3, 11.4)], V3(s * 6.7, 0, 0), FZ, Y, X, 3.6, 0.2, 0.7)                 # the hall's wall, behind the legs
        # the jamb beside the mouth, rivets down its face
        prism([(4.9, 0), (6.5, 0), (6.3, 11.1), (4.9, 11.1)], V3(0, 0, -50.6), XS, Y, ZP, 1.6, 0.14, 0.92)
        rivets(V3(s * 5.6, 1.0, -51.4), V3(s * 5.6, 10.4, -51.4), FZ, 1.05, 0.0)
        prism([(4.9, 11.05), (4.9, 8.1), (2.1, 11.05)], V3(0, 0, -50.0), XS, Y, ZP, 1.3, 0.1, 0.88)                             # the mouth's cut corner
        # the leg: from under the sign's corner down and out to its foot; a raised plate up its face, a knee plate lapped over the top of it
        prism([(6.9, 1.8), (10.0, 1.8), (8.4, 11.3), (6.1, 11.3)], V3(0, 0, -51.2), XS, Y, ZP, 2.4, 0.22, 0.97)
        LD = V3(s * -0.125, 0.992, 0)
        LX = V3(s * 0.992, 0.125, 0)
        panel(V3(s * 7.95, 5.9, -52.4), LX, LD, FZ, 0.95, 3.3, 1.1, 0.1, 0.85)
        obox(V3(s * 7.35, 10.2, -52.55), LX, LD, FZ, 1.5, 0.8, 0.25, 0.1, 1.05)
        for dx in (-1.1, 1.1):
            for dy in (-0.45, 0.45):
                rivet(V3(s * 7.35, 10.2, -52.8) + LX * dx + LD * dy, FZ, 0.12)
        # its foot: a base step, a block with a chamfered brow, the red marker on its face
        prism([(6.0, 0), (11.0, 0), (11.0, 0.6), (6.0, 0.6)], V3(0, 0, -51.4), XS, Y, ZP, 4.3, 0.1, 0.88)
        prism([(6.3, 0.55), (10.7, 0.55), (10.7, 1.6), (10.2, 2.4), (6.6, 2.4), (6.3, 2.0)], V3(0, 0, -51.4), XS, Y, ZP, 3.6, 0.2, 0.96)
        face([V3(s * 7.6, 1.05, -53.23), V3(s * 9.4, 1.05, -53.23), V3(s * 9.4, 1.42, -53.23), V3(s * 7.6, 1.42, -53.23)], FZ, RED, 1.0)
        rivets(V3(s * 6.8, 2.05, -53.2), V3(s * 10.2, 2.05, -53.2), FZ, 0.7, 0.0)
        # the hall: three ribs down each wall with a red light in the reveal beside each, a low light along the floor
        for i, z in enumerate((-49.0, -45.4, -41.6)):
            obox(V3(s * (4.9 - 0.14), 5.4 - i * 0.2, z), ZP, Y, X, 0.4, 5.4 - i * 0.2, 0.16, 0.06, 0.9)
            strip(V3(s * (4.9 - 0.02), 1.2, z + 0.75), V3(s * (4.9 - 0.02), 9.2 - i * 0.4, z + 0.75), ZP, 0.2, V3(-s, 0, 0), RED, 0.75)
        strip(V3(s * (4.9 - 0.02), 0.5, -49.6), V3(s * (4.9 - 0.02), 0.5, -38.0), Y, 0.24, V3(-s, 0, 0), RED, 0.6)
        # the flanks: a riveted plate on the housing's side and one on the hall wall under it
        panel(V3(s * 9.4, 14.7, -45.6), ZP, Y, XS, 3.8, 1.05, 1.06, 0.1, 0.9)
        panel(V3(s * 8.5, 5.4, -43.6), ZP, Y, XS, 5.0, 4.2, 0.82, 0.1, 1.0)
        # the vent box under the banner, against the wall
        box(s * 12.9, 1.3, -46.3, 3.3, 2.6, 2.6, 0.14, 0.9)
        box(s * 12.9, 2.75, -46.3, 3.7, 0.36, 3.0, 0.08, 1.0)
        louvres(lambda ss, y, d, s=s: V3(s * 12.9 + ss, y, -47.6 - d), FZ, 1.05, 0.6, 2.0, 0.35)
    for i, z in enumerate((-49.0, -45.4, -41.6)):                                  # the ribs' lintels, each a little lower than the one in front: the frames nest towards the door
        box(0, 10.75 - i * 0.4, z, 9.8, 0.5 + i * 0.8, 0.8, 0.08, 0.9)
    # the sign's housing: not a box but the plaque's own shape made heavy, its corners cut top and bottom
    prism([(-9.4, 13.2), (-7.4, 11.0), (7.4, 11.0), (9.4, 13.2), (9.4, 16.2), (7.6, 18.6), (-7.6, 18.6), (-9.4, 16.2)], V3(0, 0, -45.8), X, Y, ZP, 9.6, 0.28, 0.9)
    rivets(V3(-7.0, 17.75, -50.6), V3(7.0, 17.75, -50.6), FZ, 0.8, 0.0)
    face([V3(-4.9, 11.0, -41.0), V3(4.9, 11.0, -41.0), V3(4.9, 11.0, -37.3), V3(-4.9, 11.0, -37.3)], V3(0, -1, 0), PLATE, 0.25)
    strip(V3(-6.9, 11.2, -50.6), V3(6.9, 11.2, -50.6), Y, 0.2, FZ, RED, 0.9)                                                     # a line of light under the sign, over the mouth
    # the door: a dark plate behind a rank of red-lit slats, in a heavy frame
    zb = GATE["back"]
    face([V3(-4.9, 0, zb), V3(4.9, 0, zb), V3(4.9, 11, zb), V3(-4.9, 11, zb)], V3(0, 0, -1), PLATE, 0.14)
    x = -4.9 + 0.5
    while x < 4.9 - 0.3:
        face([V3(x - 0.14, 0.5, zb - 0.03), V3(x + 0.14, 0.5, zb - 0.03), V3(x + 0.14, 5.0, zb - 0.03), V3(x - 0.14, 5.0, zb - 0.03)], V3(0, 0, -1), RED, 1.0)
        face([V3(x - 0.14, 5.0, zb - 0.03), V3(x + 0.14, 5.0, zb - 0.03), V3(x + 0.14, 9.6, zb - 0.03), V3(x - 0.14, 9.6, zb - 0.03)], V3(0, 0, -1), RED, 0.55)
        if x + 0.37 < 4.9 - 0.2:
            box(x + 0.37, 5.2, zb - 0.2, 0.34, 10.0, 0.34, 0.06, 0.62)
        x += 0.74
    box(0, 10.1, zb - 0.35, 9.8, 0.9, 0.7, 0.1, 0.8)
    box(0, 0.2, zb - 0.35, 9.8, 0.4, 0.7, 0.08, 0.8)
    # the sign: a long plaque with pointed ends in a heavy frame with a finer one inside it, the name in red letters, a red lamp set in each point, thorns round it
    zf, cy, hx, hy, tipx = -50.6, 14.25, 6.5, 2.35, 8.7
    outer = [(-tipx, cy), (-hx, cy + hy), (hx, cy + hy), (tipx, cy), (hx, cy - hy), (-hx, cy - hy)]
    inner = [(-tipx + 0.75, cy), (-hx + 0.2, cy + hy - 0.5), (hx - 0.2, cy + hy - 0.5), (tipx - 0.75, cy), (hx - 0.2, cy - hy + 0.5), (-hx + 0.2, cy - hy + 0.5)]
    fine_o = [(-tipx + 1.0, cy), (-hx + 0.3, cy + hy - 0.66), (hx - 0.3, cy + hy - 0.66), (tipx - 1.0, cy), (hx - 0.3, cy - hy + 0.66), (-hx + 0.3, cy - hy + 0.66)]
    fine_i = [(-tipx + 1.22, cy), (-hx + 0.38, cy + hy - 0.82), (hx - 0.38, cy + hy - 0.82), (tipx - 1.22, cy), (hx - 0.38, cy - hy + 0.82), (-hx + 0.38, cy - hy + 0.82)]
    prism(outer, V3(0, 0, zf - 0.2), V3(1, 0, 0), Y, V3(0, 0, 1), 0.4, 0.0, 0.2)
    for i in range(6):
        j = (i + 1) % 6
        pts, pts2 = [], []
        for (x0, y0) in (outer[i], outer[j], inner[i], inner[j]):
            pts += [V3(x0, y0, zf - 0.3), V3(x0, y0, zf - 0.9)]
        for (x0, y0) in (fine_o[i], fine_o[j], fine_i[i], fine_i[j]):
            pts2 += [V3(x0, y0, zf - 0.3), V3(x0, y0, zf - 0.56)]
        hull(pts, 0.09, 1.08)
        hull(pts2, 0.0, 1.25)
        (ax, ay), (bx, by) = outer[i], outer[j]
        rivets(V3(ax * 0.955, cy + (ay - cy) * 0.9, zf - 0.9), V3(bx * 0.955, cy + (by - cy) * 0.9, zf - 0.9), V3(0, 0, -1), 0.9, 0.5, 0.09)
    for s in (-1, 1):
        obox(V3(s * (tipx - 0.3), cy, zf - 0.75), V3(1, 0, 0), Y, V3(0, 0, 1), 0.62, 0.42, 0.3, 0.06, 1.1)
        face([V3(s * (tipx - 0.72), cy - 0.17, zf - 1.07), V3(s * (tipx + 0.12), cy - 0.17, zf - 1.07), V3(s * (tipx + 0.12), cy + 0.17, zf - 1.07), V3(s * (tipx - 0.72), cy + 0.17, zf - 1.07)], V3(0, 0, -1), RED, 1.0)
    font = bpy.data.fonts.load("C:/Windows/Fonts/timesbd.ttf")
    words = [text_mesh(t, font) for t in ("FOINT", "DOME")]
    spans = [(min(v.x for v in vs), max(v.x for v in vs), max(v.y for v in vs)) for vs, _ in words]
    k = min(5.3 / max(b - a for a, b, _ in spans), 2.5 / max(c for _, _, c in spans))
    for (vs, fs), (a, b, cap_h), side in zip(words, spans, (-1, 1)):
        x0 = (-0.8 - (b - a) * k) if side < 0 else 0.8                             # (in the sign's own frame, x to the reader's right)
        i0 = len(VERTS)
        for v in vs:
            VERTS.append(V3(-(x0 + (v.x - a) * k), cy - cap_h * k / 2 + v.y * k, zf - 0.4 - v.z * k - 0.02))
        for f in fs:
            FACES[SIGN].append(([i0 + i for i in f], 1.0, None))
    EMIT.append((V3(0, cy, zf - 0.6), V3(0, 0, -1), 14.0))
    thorn(V3(0, cy + hy + 0.75, zf - 0.8), V3(0, 0, -1), V3(-1, 0, 0), Y, 2.7, 1.35, 7)      # the great thorn over the sign: its horns along the frame's top, its lower spike down between the two words
    thorn(V3(0, cy - hy - 0.3, zf - 0.8), V3(0, 0, -1), V3(-1, 0, 0), -Y, 2.3, 1.3, 6)       # and the one hanging under it, over the mouth
    # the yoke over the sign: two flat shoulders stepping up to the middle
    prism([(-7.2, 18.5), (7.2, 18.5), (7.2, 19.4), (5.8, 20.6), (-5.8, 20.6), (-7.2, 19.4)], V3(0, 0, -47.9), X, Y, ZP, 4.6, 0.22, 0.96)
    rivets(V3(-6.6, 19.0, -50.2), V3(6.6, 19.0, -50.2), FZ, 0.8, 0.0)
    prism([(-4.8, 20.5), (4.8, 20.5), (4.8, 21.5), (3.5, 22.7), (-3.5, 22.7), (-4.8, 21.5)], V3(0, 0, -47.6), X, Y, ZP, 3.8, 0.22, 1.0)
    rivets(V3(-4.2, 21.0, -49.5), V3(4.2, 21.0, -49.5), FZ, 0.8, 0.0)
    # the column between the knives: dark, a red slit up it, a small red point at its head, a pointed cap
    box(0, 27.0, -47.4, 2.2, 9.6, 2.6, 0.14, 0.55)
    face([V3(-0.2, 23.4, -48.73), V3(0.2, 23.4, -48.73), V3(0.2, 29.4, -48.73), V3(-0.2, 29.4, -48.73)], FZ, RED, 1.0)
    face([V3(0, 31.0, -48.73), V3(0.5, 30.4, -48.73), V3(0, 29.9, -48.73), V3(-0.5, 30.4, -48.73)], FZ, RED, 1.0)
    hull([V3(-1.1, 31.7, -48.7), V3(1.1, 31.7, -48.7), V3(1.1, 31.7, -46.1), V3(-1.1, 31.7, -46.1), V3(0, 33.2, -47.4)], 0.0, 0.8)
    # the two knives: upright, parallel, close in to the column; the back edge of each is the inner one, the long slant falls outward
    for s in (-1, 1):
        box(s * 2.75, 23.0, -48.3, 3.5, 1.3, 2.2, 0.12, 1.03)
        knife(V3(s * 2.75, 22.6, -48.3), V3(s, 0, 0), Y, FZ, 3.1, 10.6, 1.7, 0.2, 0.2, 0.95, 0.0, True)
    # the banner arms: out of the housing's shoulders, a pointed knob on the end and a point under each banner (the banners themselves are the exported ones)
    for s in (-1, 1):
        box(s * 12.3, 17.95, -47.3, 8.4, 0.34, 0.34, 0.06, 1.1)
        box(s * 16.5, 17.95, -47.3, 0.6, 0.6, 0.6, 0.1, 1.2)
        box(s * 10.5, 18.0, -47.3, 0.5, 0.7, 0.7, 0.08, 1.0)
        blade(V3(s * 16.7, 17.95, -47.3), V3(s * 17.3, 17.95, -47.3), V3(s * 18.0, 17.95, -47.3), FZ, 0.22, 0.2, 3, 0.9, 1.25)


# ============================================================================================================== the crown
def build_crown():
    Y = YV
    Rn = random.Random(5150)
    # the ring of great knives: each stands on a radius in its socket, leaning out a little, its back edge towards the spike and its long slant falling outward, a red
    # seam up both faces beside the back edge
    for i in range(12):
        th = PI + (i + 0.5) / 12 * TAU
        back = (1 - math.cos(wrap(th - PI))) / 2
        h = 13.0 + 6.0 * back + Rn.random() * 1.5
        U, W, y = P(th, 1, 0), P(th, 0, 0, 1), ROOF_Y + 0.6
        knife(U * 16.4 + Y * y, U, (Y + U * 0.16).normalized(), W, 5.6, h, 1.8, 0.16, 0.24, 0.93, 0.5, True)
        prism([(12.6, y), (19.2, y), (18.6, y + 2.3), (13.2, y + 2.3)], V3(0, 0, 0), U, Y, W, 2.9, 0.18, 1.02)       # the socket it stands in
        for s in (-1, 1):
            rivets(U * 13.2 + Y * (y + 1.1) + W * (s * 1.45), U * 18.4 + Y * (y + 1.1) + W * (s * 1.45), W * s, 0.9, 0.0, 0.12)
    # six taller ones inside them, face out, and the spike rising out of the middle on its collar
    for i in range(6):
        th = PI + (i + 0.5) / 6 * TAU
        U, W, hh = P(th, 1, 0), P(th, 0, 0, 1), 20.0 + Rn.random() * 4.0
        knife(P(th, 8.6, ROOF_Y + 0.8), W * (1 if wrap(th - PI) > 0 else -1), (Y + U * 0.05).normalized(), U, 3.4, hh, 1.5, 0.3, 0.3, 0.9, 0.5, True)
    y0, h = ROOF_Y + 0.4, 35.0
    for (r0, r1, ya, yb_, tone) in ((5.2, 4.6, 0.0, 3.2, 1.0), (4.0, 3.5, 3.2, 5.4, 0.94)):
        pts = []
        for j in range(8):
            a = (j + 0.5) * TAU / 8
            pts += [V3(math.sin(a) * r0, y0 + ya, math.cos(a) * r0), V3(math.sin(a) * r1, y0 + yb_, math.cos(a) * r1)]
        hull(pts, 0.2, tone)
    for j in range(8):
        a = j * TAU / 8
        rivet(P(a, 4.5, y0 + 1.6), P(a, 1, 0), 0.16)
    pts = []
    for sx, sz in ((1, 1), (1, -1), (-1, -1), (-1, 1)):
        pts += [V3(sx * 2.1, y0 + 5.0, sz * 2.1), V3(sx * 1.25, y0 + h * 0.74, sz * 1.25)]
    pts.append(V3(0, y0 + h, 0))
    hull(pts, 0.22, 0.9)
    for dx, dz in ((0, -1), (0, 1), (1, 0), (-1, 0)):                              # the red seam down each face of the spike
        o, t = V3(dx, 0, dz), V3(-dz, 0, dx)
        a = V3(dx * 2.02, y0 + 6.0, dz * 2.02)
        b = V3(dx * 1.34, y0 + h * 0.7, dz * 1.34)
        face([a - t * 0.36, a + t * 0.36, b + t * 0.2, b - t * 0.2], o, RED, 1.0)
        prism([(-0.9, 0), (0.9, 0), (0.6, 1.9), (-0.6, 1.9)], V3(dx * 2.3, y0 + 5.2, dz * 2.3), t, Y, o, 0.5, 0.08, 1.1)
    TIPS.append(V3(0, y0 + h, 0))


# ============================================================================================================== the forecourt
def build_lanterns():
    for x, z in LANTERNS:
        box(x, 0.28, z, 0.7, 0.56, 0.7, 0.06, 0.8)
        box(x, 2.25, z, 0.24, 3.5, 0.24, 0.03, 0.7)
        box(x, 3.96, z, 0.7, 0.12, 0.7, 0.03, 0.8)
        y0, y1, h = 4.02, 4.76, 0.27
        for dx, dz in ((0, -1), (0, 1), (-1, 0), (1, 0)):
            o, t = V3(dx, 0, dz), V3(-dz, 0, dx)
            c = V3(x + dx * h, 0, z + dz * h)
            face([c - t * h + V3(0, y0, 0), c + t * h + V3(0, y0, 0), c + t * h + V3(0, y1, 0), c - t * h + V3(0, y1, 0)], o, AMBER, 1.0)
            box(x + dx * h + (-dz) * h, (y0 + y1) / 2, z + dz * h + dx * h, 0.07, y1 - y0, 0.07, 0.0, 0.6)
        box(x, y1 + 0.07, z, 0.74, 0.14, 0.74, 0.03, 0.8)
        hull([V3(x - 0.3, y1 + 0.14, z - 0.3), V3(x + 0.3, y1 + 0.14, z - 0.3), V3(x + 0.3, y1 + 0.14, z + 0.3), V3(x - 0.3, y1 + 0.14, z + 0.3), V3(x, y1 + 0.75, z)], 0.0, 0.7)


# ============================================================================================================== bake and write
def bake():
    """per face corner: occlusion by ray casting against everything built, and the red light that reaches it"""
    polys = []
    for m in (PLATE, HAZARD, AMBER, RED, SIGN):
        for idx, _, _ in FACES[m]:
            polys.append(idx)
    g = len(VERTS)
    all_v = VERTS + [V3(-200, -0.02, -200), V3(200, -0.02, -200), V3(200, -0.02, 200), V3(-200, -0.02, 200)]
    polys.append([g, g + 1, g + 2, g + 3])
    tree = BVHTree.FromPolygons(all_v, polys, all_triangles=False, epsilon=0.0)
    dirs = []
    for i in range(14):                                                            # a fixed fan over the hemisphere, the same for every corner (no noise)
        z = 1 - (i + 0.5) / 14 * 0.92
        a = i * 2.39996
        rr = math.sqrt(max(0.0, 1 - z * z))
        dirs.append((math.cos(a) * rr, math.sin(a) * rr, z))
    MAXD = 4.5
    wsum = sum(d[2] for d in dirs)
    out = []
    pos, nrm = [], []
    for idx, tone, _ in FACES[PLATE]:
        pts = [VERTS[i] for i in idx]
        n = newell(pts)
        if n.length < 1e-9:
            out.append([1.0] * len(idx))
            for p in pts:
                pos.append(p)
                nrm.append(V3(0, 1, 0))
            continue
        n.normalize()
        t = n.cross(V3(0, 1, 0))
        if t.length < 0.05:
            t = n.cross(V3(1, 0, 0))
        t.normalize()
        b = n.cross(t)
        c = sum(pts, Vector((0, 0, 0))) / len(pts)
        small = len(idx) <= 4 and (pts[0] - c).length < 0.3                        # a rivet's face: one sample does for all its corners
        ao = []
        for p in pts:
            if small and ao:
                ao.append(ao[0])
                pos.append(pos[-1])
                nrm.append(n)
                continue
            o = p + (c - p) * 0.1 + n * 0.05
            occ = 0.0
            for dx, dy, dz in dirs:
                hit = tree.ray_cast(o, t * dx + b * dy + n * dz, MAXD)
                if hit[0] is not None:
                    occ += (1.0 - hit[3] / MAXD) * dz
            ao.append(max(0.0, 1.0 - 0.9 * occ / wsum))
            pos.append(o)
            nrm.append(n)
        out.append(ao)
    # the red light: every lit face is a small lamp
    Pn, Nn = np.array(pos, dtype=np.float32), np.array(nrm, dtype=np.float32)
    Ec = np.array([e[0] for e in EMIT], dtype=np.float32)
    En = np.array([e[1] for e in EMIT], dtype=np.float32)
    Ew = np.array([e[2] for e in EMIT], dtype=np.float32)
    red = np.zeros(len(pos), dtype=np.float32)
    CH = 1500
    for i in range(0, len(pos), CH):
        d = Ec[None, :, :] - Pn[i:i + CH, None, :]
        d2 = (d * d).sum(-1) + 0.6
        inv = 1.0 / np.sqrt(d2)
        cos_s = np.clip((d * Nn[i:i + CH, None, :]).sum(-1) * inv + 0.15, 0.0, 1.0)
        cos_e = np.clip(-(d * En[None, :, :]).sum(-1) * inv, 0.0, 1.0) * 0.85 + 0.15
        red[i:i + CH] = (Ew[None, :] * cos_s * cos_e / d2).sum(-1)
    red = np.clip(red * 0.12, 0.0, 1.0) ** 0.75                                    # (a window a metre away is about half; five metres away, a trace)
    return out, red


def make_objects(ao, red):
    col = bpy.data.collections.new("COL_FointDome")
    bpy.context.scene.collection.children.link(col)
    obs = []
    ri = 0
    for m, name in enumerate(MAT_NAMES):
        if not FACES[m]:
            continue
        remap, verts, faces = {}, [], []
        for idx, _, _ in FACES[m]:
            f = []
            for i in idx:
                if i not in remap:
                    remap[i] = len(verts)
                    v = VERTS[i]
                    verts.append((v.x, -v.z, v.y))                                 # dome space (y up) -> Blender (z up); the exporter turns it back
                f.append(remap[i])
            faces.append(f)
        me = bpy.data.meshes.new("SM_" + name)
        me.from_pydata(verts, [], faces)
        cols = np.ones((len(me.loops), 4), dtype=np.float32)
        uvs = np.zeros((len(me.loops), 2), dtype=np.float32)
        li = 0
        for fi, (idx, tone, uv) in enumerate(FACES[m]):
            for c in range(len(idx)):
                if m == PLATE:
                    cols[li] = (min(tone / 1.6, 1.0), ao[fi][c], red[ri], 1.0)
                    ri += 1
                else:
                    cols[li] = (tone, 1.0, 0.0, 1.0)
                if uv:
                    uvs[li] = uv[c]
                li += 1
        ca = me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
        ca.data.foreach_set("color", cols.ravel())
        me.color_attributes.active_color = ca
        me.color_attributes.render_color_index = 0
        uvl = me.uv_layers.new(name="UVMap")
        uvl.data.foreach_set("uv", uvs.ravel())
        for p in me.polygons:
            p.use_smooth = True
        me.set_sharp_from_angle(angle=math.radians(24))
        me.update()
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = MAT_VIEW[m]
        me.materials.append(mat)
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        obs.append(ob)
        print("  %-12s %7d tris" % (name, sum(len(p.vertices) - 2 for p in me.polygons)))
    for i, t in enumerate(TIPS):
        e = bpy.data.objects.new("Tip_%02d" % i, None)
        e.location = (t.x, -t.z, t.y)
        col.objects.link(e)
        obs.append(e)
    return obs


def preview(path, cam=(-14, 62, -132), look=(0, 15, -6), lens=42):
    sc = bpy.context.scene
    cd = bpy.data.cameras.new("cam")
    cd.lens = lens
    cd.clip_end = 2000
    co = bpy.data.objects.new("cam", cd)
    sc.collection.objects.link(co)
    loc, tgt = Vector((cam[0], -cam[2], cam[1])), Vector((look[0], -look[2], look[1]))
    co.location = loc
    co.rotation_euler = (tgt - loc).to_track_quat('-Z', 'Y').to_euler()
    sc.camera = co
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'
    sh.color_type = 'MATERIAL'
    sh.show_cavity = True
    sh.cavity_type = 'BOTH'
    sh.show_shadows = True
    sh.shadow_intensity = 0.45
    sc.display.light_direction = (0.4, 0.5, 0.75)
    if sc.world is None:
        sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.03, 0.02, 0.04)
    sc.render.resolution_x, sc.render.resolution_y = 1400, 1050
    sc.render.filepath = path
    sc.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    build_mound()
    build_buttresses()
    build_gate()
    build_crown()
    build_lanterns()
    print("built: %d faces, %d red lamps, %d tips" % (sum(len(f) for f in FACES), len(EMIT), len(TIPS)))
    if "--fast" in argv:
        ao = [[1.0] * len(idx) for idx, _, _ in FACES[PLATE]]
        red = np.zeros(sum(len(idx) for idx, _, _ in FACES[PLATE]), dtype=np.float32)
    else:
        ao, red = bake()
    obs = make_objects(ao, red)
    if "--preview" in argv:
        i = argv.index("--preview")
        preview(argv[i + 1])
        if len(argv) > i + 2 and not argv[i + 2].startswith("--"):
            preview(argv[i + 2], (-58, 22, -98), (-14, 12, -42), 50)              # the concept's close crop: the gate's left flank and its buttresses
    if "--no-export" not in argv:
        out = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "foint_dome", "foint_dome.glb"))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        for o in bpy.data.objects:
            o.select_set(o in obs)
        bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_normals=True, export_tangents=False,
                                  export_materials='EXPORT', export_vertex_color='ACTIVE', export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True,
                                  export_cameras=False, export_lights=False, export_animations=False)
        print("wrote", out)


main()
