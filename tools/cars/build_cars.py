# FOINT CITY's fleet, built procedurally: this script, more_cars.py and sky_cars.py are the source of assets/vehicles/city/*.glb.
# One car:  blender -b --factory-startup --python tools/cars/build_cars.py -- <kind> <outdir> [lod] [render]     (Blender 5.2; node tools/cars/build_all.mjs does all of them)
#   kind: sedan hatch taxi van truck bus saucerG saucerN saucerB, and the flying cars skyLimo skyDart (sky_cars.py).  lod: the lighter mesh the street's MultiMesh draws (<kind>_street.glb).  render: preview pictures, no game surfaces.
# What the game gets: Body, Glass and one Wheel_<n> per wheel (origin at its centre), every mesh in at most four surfaces: CarPaint (takes the car's colour), CarParts (vertex colour = albedo,
# UV = metallic, roughness), CarGlass (or CarDome: the alien craft's clear bubbles), CarLights (vertex colour = the light's colour, UV.x = strength / 16). levels/shaders/car_*.gdshader draw them.
# The wheeled cars also get Door (the driver's door, cut out of the body with its glass and trim; origin at its hinge) and Steer (the steering wheel; origin at its centre), over a cabin
# hollowed out of the body with a seat in it (more_cars.py door_split; the street's lighter mesh keeps the body whole). levels/hub/city_cars.gd DOORS and SEATS say where the game expects them.
# Car frame: f forward, s side (left +), u up, metres, origin on the ground under the middle. Blender: (s, -f, u), so the GLB has +Z forward.
import bpy, bmesh, math, sys, os
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ARGS = sys.argv[sys.argv.index('--') + 1:]
CAR = ARGS[0]
OUT = ARGS[1]
RENDER = 'render' in ARGS[2:]
LOD = 1 if 'lod' in ARGS[2:] else 0


def P(f, s, u):
    return Vector((s, -f, u))


# ---------------------------------------------------------------- materials
def mat(name, color, metallic=0.0, rough=0.5, emit=None, strength=0.0, alpha=1.0, coat=0.0):
    m = bpy.data.materials.new(name)
    try:
        m.use_nodes = True
    except Exception:
        pass
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value = (*color, 1.0)
    b.inputs['Metallic'].default_value = metallic
    b.inputs['Roughness'].default_value = rough
    if emit is not None:
        b.inputs['Emission Color'].default_value = (*emit, 1.0)
        b.inputs['Emission Strength'].default_value = strength
    if coat > 0.0:
        b.inputs['Coat Weight'].default_value = coat
        b.inputs['Coat Roughness'].default_value = 0.04
    if alpha < 1.0:
        b.inputs['Alpha'].default_value = alpha
        try:
            m.surface_render_method = 'BLENDED'
        except Exception:
            pass
    return m


def srgb(hexv):
    def lin(c):
        c /= 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (lin((hexv >> 16) & 255), lin((hexv >> 8) & 255), lin(hexv & 255))


# ---------------------------------------------------------------- mesh helpers
def mesh_obj(name, verts, faces, material, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.update()
    if material is not None:
        me.materials.append(material)
    me.polygons.foreach_set('use_smooth', [smooth] * len(me.polygons))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def apply_mods(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)


def subsurf(ob, levels):
    levels = max(1, levels - LOD)
    m = ob.modifiers.new('ss', 'SUBSURF')
    m.levels = levels
    m.render_levels = levels
    apply_mods(ob)


def outward(ob, center=None, sharp_deg=None):
    """consistent normals facing away from center; optionally mark edges sharper than sharp_deg"""
    me = ob.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if center is not None:
        tot = 0.0
        for f in bm.faces:
            tot += f.normal.dot(f.calc_center_median() - center) * f.calc_area()
        if tot < 0.0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
    if sharp_deg is not None:
        lim = math.radians(sharp_deg)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                e.smooth = e.calc_face_angle(0.0) < lim
    for f in bm.faces:
        f.smooth = True
    bm.to_mesh(me)
    bm.free()
    me.update()


def set_creases(me, pairs, value):
    lut = {}
    for e in me.edges:
        a, b = e.vertices
        lut[(min(a, b), max(a, b))] = e.index
    at = me.attributes.get('crease_edge') or me.attributes.new('crease_edge', 'FLOAT', 'EDGE')
    for a, b in pairs:
        i = lut.get((min(a, b), max(a, b)))
        if i is not None:
            at.data[i].value = value


def loft(name, rings, material, closed=True, cap_start=False, cap_end=False):
    n = len(rings[0])
    verts = [v for r in rings for v in r]
    faces = []
    for i in range(len(rings) - 1):
        for j in range(n if closed else n - 1):
            a = i * n + j
            b = i * n + (j + 1) % n
            faces.append((a, b, b + n, a + n))
    if cap_start:
        faces.append(tuple(range(n - 1, -1, -1)))
    if cap_end:
        o = (len(rings) - 1) * n
        faces.append(tuple(range(o, o + n)))
    return mesh_obj(name, verts, faces, material)


def bvh_of(ob):
    me = ob.data
    return BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])


def boolean(ob, cutter, op='DIFFERENCE'):
    m = ob.modifiers.new('b', 'BOOLEAN')
    m.operation = op
    m.object = cutter
    m.solver = 'EXACT'
    try:
        m.material_mode = 'TRANSFER'
    except Exception:
        pass
    apply_mods(ob)
    bpy.data.objects.remove(cutter)


def join(name, obs):
    obs = [o for o in obs if o is not None]
    bm = bmesh.new()
    mats = []
    for o in obs:
        me = o.data
        remap = []
        for m in me.materials:
            if m not in mats:
                mats.append(m)
            remap.append(mats.index(m))
        start = len(bm.faces)
        tmp = me.copy()
        tmp.transform(o.matrix_world)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
        bm.faces.ensure_lookup_table()
        for f in bm.faces[start:]:
            f.material_index = remap[f.material_index] if remap else 0
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    for o in obs:
        bpy.data.objects.remove(o)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def interp(table, f, col):
    """table rows sorted by descending or ascending first column"""
    rows = sorted(table, key=lambda r: r[0])
    if f <= rows[0][0]:
        return rows[0][col]
    for a, b in zip(rows, rows[1:]):
        if f <= b[0]:
            k = (f - a[0]) / (b[0] - a[0])
            k = k * k * (3 - 2 * k)
            return a[col] + (b[col] - a[col]) * k
    return rows[-1][col]


# ---------------------------------------------------------------- car parts
def build_body(name, stations, material, shoulder=0.9, sill=0.75, levels=2, ends=0.7):
    """stations: (f, w, zb, zs, zt[, tuck]) from tail to nose. Ring of 16: bottom centre, up the left side, top centre, down the right.
    shoulder, sill: how hard the belt line and the rocker are creased (2026-11-11: hard, they were soap bars); ends: the edge round the nose and tail faces."""
    rings = []
    for st in stations:
        f, w, zb, zs, zt = st[:5]
        wb = w * (st[5] if len(st) > 5 else 0.88)
        half = [(0, zb), (wb * 0.55, zb), (wb, zb + 0.015), (w * 0.985, zb + 0.42 * (zs - zb)), (w, zs - 0.12 * (zs - zb)),
                (w * 0.965, zs), (w * 0.80, zs + 0.62 * (zt - zs)), (w * 0.42, zt - 0.05 * (zt - zs)), (0, zt)]
        rings.append([P(f, s, u) for s, u in half] + [P(f, -s, u) for s, u in half[-2:0:-1]])
    ob = loft(name, rings, material, cap_start=True, cap_end=True)
    n = 16
    for j, val in ((5, shoulder), (11, shoulder), (2, sill), (14, sill)):
        set_creases(ob.data, [(i * n + j, (i + 1) * n + j) for i in range(len(rings) - 1)], val)
    if ends > 0.0:
        for i in (1, len(rings) - 2):
            set_creases(ob.data, [(i * n + j, i * n + (j + 1) % n) for j in range(n)], ends)
    subsurf(ob, levels)
    outward(ob, Vector((0, 0, 0.5)))
    return ob


def build_canopy(name, stations, material, expo=2.6, sink=0.12, levels=2):
    """stations: (f, wc, base, top) front to back: a superellipse arch over the body, its feet sunk into it"""
    rings = []
    N = 12
    for f, wc, base, top in stations:
        ring = [P(f, wc, base - sink)]
        for k in range(N + 1):
            a = math.pi * k / N
            c, s_ = math.cos(a), math.sin(a)
            ring.append(P(f, wc * math.copysign(abs(c) ** (2 / expo), c), base + (top - base) * abs(s_) ** (2 / expo)))
        ring.append(P(f, -wc, base - sink))
        rings.append(ring)
    ob = loft(name, rings, material, closed=False)
    subsurf(ob, levels)
    mid = stations[len(stations) // 2]
    outward(ob, P(mid[0], 0, mid[2] - 0.3))
    return ob


def ribbon(name, bvh, rays, width, offset, material, across=1, snap=0.1):
    """a strip lying on a surface: rays (origin, direction) find its centre line, width may be a function of 0..1 along it"""
    hits = []
    for o, d in rays:
        loc, nrm, _i, _d = bvh.ray_cast(o, d.normalized())
        if loc is not None:
            hits.append((loc, nrm))
    if len(hits) < 2:
        print('ribbon', name, 'missed')
        return None
    cols = across + 1
    verts = []
    last = len(hits) - 1
    for i, (p, n) in enumerate(hits):
        t = (hits[min(i + 1, last)][0] - hits[max(i - 1, 0)][0]).normalized()
        b = n.cross(t).normalized()
        wv = width(i / last) if callable(width) else width
        for c in range(cols):
            q = p + b * ((c / across - 0.5) * wv)
            r = bvh.find_nearest(q)
            if r[0] is not None and (r[0] - q).length < snap:
                verts.append(r[0] + r[1] * offset)
            else:
                verts.append(q + n * offset)
    faces = []
    for i in range(last):
        for c in range(across):
            a = i * cols + c
            faces.append((a, a + cols, a + cols + 1, a + 1))
    return mesh_obj(name, verts, faces, material)


def tube(name, bvh, rays, radius, lift, material, segs=8, squash=1.0):
    """a rounded bar following a surface (bumpers, mouldings): radius across, squash flattens it against the body"""
    hits = []
    for o, d in rays:
        loc, nrm, _i, _d = bvh.ray_cast(o, d.normalized())
        if loc is not None:
            hits.append((loc, nrm))
    if len(hits) < 2:
        print('tube', name, 'missed')
        return None
    rings = []
    last = len(hits) - 1
    for i, (p, n) in enumerate(hits):
        t = (hits[min(i + 1, last)][0] - hits[max(i - 1, 0)][0]).normalized()
        b = n.cross(t).normalized()
        k = min(1.0, min(i, last - i) / 2.0 + 0.35)      # taper the ends
        rings.append([p + n * (lift + radius * squash * k * math.cos(a)) + b * (radius * k * math.sin(a)) for a in [math.tau * q / segs for q in range(segs)]])
    ob = loft(name, rings, material, cap_start=True, cap_end=True)
    outward(ob, None, 50)
    return ob


def side_rays(pts, side, step=0.04):
    """(f, u) polyline seen from the side -> rays"""
    step *= 1 + LOD
    out = []
    for (f0, u0), (f1, u1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(f1 - f0, u1 - u0) / step))
        for k in range(n):
            q = k / n
            out.append((P(f0 + (f1 - f0) * q, side * 3.0, u0 + (u1 - u0) * q), Vector((-side, 0, 0))))
    out.append((P(pts[-1][0], side * 3.0, pts[-1][1]), Vector((-side, 0, 0))))
    return out


def top_rays(pts, step=0.04):
    """(f, s) polyline seen from above -> rays"""
    step *= 1 + LOD
    out = []
    for (f0, s0), (f1, s1) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(f1 - f0, s1 - s0) / step))
        for k in range(n):
            q = k / n
            out.append((P(f0 + (f1 - f0) * q, s0 + (s1 - s0) * q, 4.0), Vector((0, 0, -1))))
    out.append((P(pts[-1][0], pts[-1][1], 4.0), Vector((0, 0, -1))))
    return out


def water_rays(f0, u, a0, a1, n=48, radius=4.0, u_fn=None):
    """a line round the body at height u, seen from a point on the centre line: angle 0 is dead ahead, degrees"""
    n = n // (1 + LOD)
    out = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        uu = u_fn(k / n) if u_fn else u
        o = P(f0 + radius * math.cos(a), radius * math.sin(a), uu)
        out.append((o, P(f0, 0, uu) - o))
    return out


def cyl_cutter(f, u, r, s0, s1, material, segs=40, clip_top=None):
    """a cutter along the side axis from s0 to s1: a cylinder, or with clip_top a cylinder cut flat at that height (a skirted arch)"""
    prof = []
    for k in range(segs):
        a = math.tau * k / segs
        prof.append((f + r * math.cos(a), min(u + r * math.sin(a), clip_top) if clip_top is not None else u + r * math.sin(a)))
    ob = loft('cut', [[P(pf, s0, pu) for pf, pu in prof], [P(pf, s1, pu) for pf, pu in prof]], material, cap_start=True, cap_end=True)
    outward(ob, P(f, (s0 + s1) / 2, u))
    return ob


def arch_lip(name, f, u, r, s, material, a0=-12.0, a1=192.0, radial=0.035, axial=0.05, segs=28):
    """the flare round a wheel arch: a chunky rounded band"""
    segs = segs // (1 + LOD)
    sec = [(-radial, -axial), (radial * 0.6, -axial), (radial, -axial * 0.5), (radial, axial * 0.55), (radial * 0.45, axial), (-radial, axial * 0.8)]
    rings = []
    sg = 1.0 if s > 0 else -1.0
    for k in range(segs + 1):
        a = math.radians(a0 + (a1 - a0) * k / segs)
        rings.append([P(f + (r + dr) * math.cos(a), s + sg * da, u + (r + dr) * math.sin(a)) for dr, da in sec])
    ob = loft(name, rings, material, cap_start=True, cap_end=True)
    outward(ob, None, 40)
    return ob


def lathe(name, profile, f, s, u, material, segs=32, side=1.0, cap_first=False, cap_last=False, sharp=35):
    """profile: (axial, radius) pairs revolved about the side axis through (f, u); axial + points outward on that side"""
    segs = max(12, segs * 5 // 8) if LOD else segs
    rings = []
    for a_, r_ in profile:
        rings.append([P(f + r_ * math.cos(math.tau * k / segs), s + side * a_, u + r_ * math.sin(math.tau * k / segs)) for k in range(segs)])
    ob = loft(name, rings, material, cap_start=cap_first, cap_end=cap_last)
    outward(ob, P(f, s, u), sharp)
    return ob


def wheel(name, f, s, u, r, w, M, blades=9):
    """a fat tyre, a deep dished turbine rim and a lit ring. s is the wheel's centre plane, + is the left side"""
    side = 1.0 if s > 0 else -1.0
    hw = w / 2
    parts = []
    tyre = [(-hw * 0.86, r * 0.60), (-hw, r * 0.78), (-hw, r * 0.92), (-hw * 0.80, r), (hw * 0.80, r), (hw, r * 0.92), (hw, r * 0.78), (hw * 0.86, r * 0.60)]
    parts.append(lathe('tyre', tyre, f, s, u, M['tyre'], side=side))
    for k in range(-1, 2 - 3 * LOD):      # tread grooves
        parts.append(lathe('groove', [(k * hw * 0.42 - 0.012, r + 0.002), (k * hw * 0.42 + 0.012, r + 0.002)], f, s, u, M['trim'], side=side))
    rim = [(hw * 0.86, r * 0.61), (hw * 0.95, r * 0.60), (hw * 0.95, r * 0.555), (hw * 0.30, r * 0.50), (hw * 0.22, r * 0.24), (hw * 0.62, r * 0.20), (hw * 0.70, r * 0.10), (hw * 0.70, 0.0005)]
    parts.append(lathe('rim', rim, f, s, u, M['rim'], side=side))
    parts.append(lathe('back', [(-hw * 0.86, r * 0.61), (-hw * 0.5, r * 0.3), (-hw * 0.5, 0.0005)], f, s, u, M['trim'], side=side))
    parts.append(lathe('ring', [(hw * 0.955, r * 0.595), (hw * 0.975, r * 0.585), (hw * 0.975, r * 0.565), (hw * 0.955, r * 0.558)], f, s, u, M['neon'], side=side))
    parts.append(lathe('hub', [(hw * 0.705, r * 0.085), (hw * 0.72, r * 0.075), (hw * 0.72, r * 0.03)], f, s, u, M['neon'], side=side))
    # turbine blades in the dish
    verts, faces = [], []
    for b in range(blades):
        a = math.tau * b / blades
        for (rr, da, ax) in ((r * 0.25, -0.16, hw * 0.50), (r * 0.25, 0.10, hw * 0.34), (r * 0.52, 0.34, hw * 0.52), (r * 0.52, 0.06, hw * 0.78)):
            verts.append(P(f + rr * math.cos(a + da), s + side * ax, u + rr * math.sin(a + da)))
        o = b * 4
        faces.append((o, o + 1, o + 2, o + 3))
    bl = mesh_obj('blades', verts, faces, M['rim2'], smooth=False)
    outward(bl, P(f, s - side * 0.5, u))
    parts.append(bl)
    ob = join(name, parts)
    # origin at the wheel's centre, so it can spin and steer
    c = P(f, s, u)
    ob.data.transform(__import__('mathutils').Matrix.Translation(-c))
    ob.location = c
    return ob


def nozzle(name, bvh, s, u, r, M, depth=0.16):
    """a round thruster / lamp looking back: collar, dark throat, lit core"""
    f = -bvh.ray_cast(P(-6.0, s, u), Vector((0, -1, 0)))[0].y
    def back_lathe(nm, prof, m, cap=False):
        rings = [[P(f - a_, s + r_ * math.cos(math.tau * k / 24), u + r_ * math.sin(math.tau * k / 24)) for k in range(24)] for a_, r_ in prof]
        ob = loft(nm, rings, m, cap_end=cap)
        outward(ob, P(f + 0.3, s, u) if not cap else None, 35)
        return ob
    # (axial + is backwards from f, the body's own surface: the collar stands proud of it, the core sits a little way down its throat)
    col = back_lathe('collar', [(-depth, r * 1.0), (0.05, r * 1.18), (0.066, r * 1.10), (0.066, r * 0.90), (0.015, r * 0.76)], M['chrome'] if name.startswith('lamp') else M['trim'])
    outward(col, None, 35)
    core = back_lathe('core', [(0.015, r * 0.76), (0.015, 0.0005)], M['tail'] if name.startswith('lamp') else M['neon'], cap=False)
    bm = bmesh.new(); bm.from_mesh(core.data)      # face it backwards
    for fc in bm.faces:
        if fc.normal.y < 0:      # blender -y is forward
            fc.normal_flip()
    bm.to_mesh(core.data); bm.free()
    return [col, core]


def blade(name, stations, material, creased=True):
    """a thin fin: stations (f, u0, u1, t_base, t_tip)"""
    rings = []
    for f, u0, u1, tb, tt in stations:
        um = u0 + (u1 - u0) * 0.55
        rings.append([P(f, tb, u0), P(f, tb * 0.7, um), P(f, tt, u1), P(f, -tt, u1), P(f, -tb * 0.7, um), P(f, -tb, u0)])
    ob = loft(name, rings, material, cap_start=True, cap_end=True)
    n = 6
    set_creases(ob.data, [(i * n + 2, (i + 1) * n + 2) for i in range(len(rings) - 1)] + [(i * n + 3, (i + 1) * n + 3) for i in range(len(rings) - 1)], 0.6)
    subsurf(ob, 2)
    outward(ob, None)
    return ob


# ---------------------------------------------------------------- the cars
def materials(paint_hex, accent_hex, lit=False):
    """lit: the accent lines glow (the alien craft). On the city's cars they are chrome mouldings: the only light a car carries is its lamps (2026-11-11: the glowing pin lines and wheel rings read as toys)."""
    return {
        'paint': mat('Paint', srgb(paint_hex), metallic=0.75, rough=0.32, coat=1.0),
        'trim': mat('Trim', (0.012, 0.011, 0.016), metallic=0.2, rough=0.55),
        'gap': mat('Gap', (0.002, 0.002, 0.003), metallic=0.0, rough=0.9),
        'glass': mat('Glass', (0.012, 0.014, 0.028), metallic=0.9, rough=0.04, alpha=0.88),
        'head': mat('LightHead', (0.9, 0.93, 1.0), emit=(0.80, 0.88, 1.0), strength=14.0),
        'tail': mat('LightTail', (1.0, 0.05, 0.03), emit=(1.0, 0.02, 0.012), strength=4.5),      # (lamp blocks, not the old thin bar: at 9 the bloom turned them orange)
        'neon': mat('Neon', srgb(accent_hex), emit=srgb(accent_hex), strength=7.0) if lit else mat('Moulding', (0.42, 0.43, 0.48), metallic=1.0, rough=0.2),
        'dome': mat('Dome', (0.012, 0.014, 0.028), metallic=0.9, rough=0.04, alpha=0.4),
        'plate': mat('Plate', (0.55, 0.55, 0.50), metallic=0.0, rough=0.45),
        'seat': mat('Seat', (0.045, 0.02, 0.028), metallic=0.0, rough=0.62),
        'cabin': mat('Cabin', (0.010, 0.009, 0.013), metallic=0.0, rough=0.8),
        'amber': mat('LightAmber', (1.0, 0.45, 0.05), emit=(1.0, 0.42, 0.04), strength=3.0),
        'tyre': mat('Tyre', (0.014, 0.014, 0.016), rough=0.82),
        'rim': mat('Rim', (0.16, 0.16, 0.18), metallic=1.0, rough=0.34),
        'rim2': mat('RimBlade', (0.22, 0.22, 0.25), metallic=1.0, rough=0.22),
        'chrome': mat('Chrome', (0.55, 0.56, 0.62), metallic=1.0, rough=0.12),
    }


def cruiser():
    """SEDAN: long, low, wedge nose, wraparound canopy with a painted spine running into a dorsal fin, skirted rear wheels"""
    M = materials(0x2a0a2e, 0xff2ad0)
    AX_F, AX_R, TRACK, WR, WW = 1.42, -1.42, 0.80, 0.35, 0.25
    body_st = [
        (-2.31, 0.60, 0.44, 0.70, 0.78, 0.80),
        (-2.20, 0.84, 0.33, 0.76, 0.86, 0.84),
        (-1.85, 0.94, 0.23, 0.82, 0.92),
        (-1.42, 0.975, 0.20, 0.86, 0.95),
        (-0.80, 0.965, 0.20, 0.86, 0.96),
        (0.00, 0.945, 0.20, 0.84, 0.93),
        (0.70, 0.94, 0.20, 0.82, 0.86),
        (1.10, 0.955, 0.20, 0.85, 0.82),      # the front wings stand above the bonnet from here on
        (1.42, 0.965, 0.21, 0.865, 0.79),
        (1.80, 0.93, 0.23, 0.79, 0.70),
        (2.08, 0.84, 0.28, 0.62, 0.60, 0.86),
        (2.24, 0.68, 0.34, 0.52, 0.535, 0.84),
        (2.32, 0.46, 0.39, 0.47, 0.49, 0.80),
    ]
    body = build_body('body', body_st, M['paint'])
    # arches: round and flared at the front, skirted at the back
    for sd in (1, -1):
        boolean(body, cyl_cutter(AX_F, WR, WR + 0.07, sd * 0.66, sd * 1.4, M['trim']))
        boolean(body, cyl_cutter(AX_R, WR, WR + 0.075, sd * 0.52, sd * 1.4, M['trim'], clip_top=0.47))
    outward(body, None, 38)
    bvh = bvh_of(body)
    parts = new_parts(body)
    for sd in (1, -1):
        parts['trim'].append(arch_lip('lip', AX_F, WR, WR + 0.07, sd * 0.935, M['trim']))
    # the glasshouse: a low wedge of glass under a painted roof that runs back into the fin, on pillars
    can_st = [(1.04, 0.22, 0.80, 0.80), (0.86, 0.52, 0.82, 0.95), (0.50, 0.68, 0.85, 1.13), (0.05, 0.735, 0.87, 1.245), (-0.42, 0.74, 0.89, 1.27),
              (-0.92, 0.69, 0.90, 1.22), (-1.38, 0.55, 0.90, 1.11), (-1.74, 0.34, 0.89, 0.985), (-1.92, 0.16, 0.86, 0.90)]
    canopy = build_canopy('glass', can_st, M['glass'], expo=3.6)
    canopy.name = 'Glass'
    cb = bvh_of(canopy)
    greenhouse(parts, cb, M, (0.30, -1.50, 1.02, 0.34, 0.3), [(0.62, 0.25, 0.10), (-0.50, -0.56, 0.11), (-1.62, -1.20, 0.16)], 0.80)
    fin = blade('fin', [(-0.70, 1.20, 1.262, 0.035, 0.02), (-1.20, 1.05, 1.20, 0.035, 0.010), (-1.65, 0.90, 1.11, 0.03, 0.006), (-2.05, 0.80, 1.03, 0.025, 0.005), (-2.33, 0.86, 0.99, 0.010, 0.004)], M['paint'])
    parts['paint'].append(fin)
    # the face: lamp blocks either side of a slatted grille over a heavy bumper; the tail: two red blocks and the plate between
    front_face(parts, bvh, M, 1.0, 0.478, 58, 0.075, bumper=0.335)
    rear_face(parts, bvh, M, -1.0, 0.72, 121, 0.085, bumper=0.40)
    for sd in (1, -1):
        parts['neon'].append(ribbon('pin', bvh, side_rays([(0.94, 0.765), (0.0, 0.775), (-1.2, 0.775), (-2.05, 0.725)], sd), 0.022, 0.006, M['neon']))
        parts['trim'].append(ribbon('sill', bvh, side_rays([(0.98, 0.27), (-0.98, 0.265)], sd), 0.12, 0.004, M['trim'], across=2))
        # panel gaps: one long door, the bonnet's edge, the boot
        parts['gap'].append(ribbon('door_f', bvh, side_rays([(0.60, 0.33), (0.60, 0.88)], sd, 0.03), 0.012, 0.0025, M['gap']))
        parts['gap'].append(ribbon('door_r', bvh, side_rays([(-0.58, 0.33), (-0.58, 0.88)], sd, 0.03), 0.012, 0.0025, M['gap']))
        parts['gap'].append(ribbon('bonnet', bvh, top_rays([(0.98, sd * 0.02), (1.00, sd * 0.55), (1.20, sd * 0.74), (1.95, sd * 0.70), (2.16, sd * 0.50), (2.20, sd * 0.02)], 0.03), 0.012, 0.0025, M['gap']))
        parts['gap'].append(ribbon('skirt', bvh, side_rays([(-0.90, 0.52), (-1.95, 0.52)], sd, 0.03), 0.012, 0.0025, M['gap']))
        for i in range(3):      # gills behind the front wheel
            parts['gap'].append(ribbon('gill', bvh, side_rays([(0.90 - i * 0.075, 0.40), (0.935 - i * 0.075, 0.63)], sd, 0.03), 0.03, 0.003, M['gap']))
    fittings(parts, bvh, M, mirror=(0.80, 0.80), handles=[(0.02, 0.70)], antenna=(-1.75, 0.62), exhaust=(0.42, 0.30))
    door = {'f0': -0.58, 'f1': 0.60, 'u0': 0.33, 'u1': 3.0, 's_in': 0.80, 's_out': 0.95, 'belt': 0.84, 'cab': (-0.95, 0.95, 0.27, 3.0),
            'seat': (0.10, 0.42, 0.43), 'wheel': (0.50, 0.42, 0.85, 0.55, 0.17)}
    wl = [(AX_F, TRACK, WR, WW), (AX_F, -TRACK, WR, WW), (AX_R, TRACK, WR, WW), (AX_R, -TRACK, WR, WW)]
    return finish(parts, [canopy], wl, M, blades=11, door=door)


def pod():
    """HATCH: a chunky one-box city pod: bubble canopy, wheels in pontoons at the corners, round afterburner lamps"""
    M = materials(0x0e2a3a, 0x22d8ff)
    AX_F, AX_R, TRACK, WR, WW = 1.22, -1.22, 0.79, 0.33, 0.27
    body_st = [
        (-1.96, 0.66, 0.42, 0.80, 0.96, 0.82),
        (-1.84, 0.82, 0.30, 0.84, 1.06, 0.86),
        (-1.25, 0.875, 0.22, 0.87, 1.10),
        (-0.50, 0.875, 0.21, 0.87, 1.04),
        (0.30, 0.865, 0.21, 0.85, 0.97),
        (1.00, 0.85, 0.22, 0.79, 0.89),
        (1.55, 0.80, 0.26, 0.70, 0.79),
        (1.86, 0.64, 0.33, 0.60, 0.67, 0.84),
        (1.96, 0.44, 0.39, 0.54, 0.58, 0.80),
    ]
    body = build_body('body', body_st, M['paint'], shoulder=0.8)
    # pontoons over the wheels
    for f in (AX_F, AX_R):
        for sd in (1, -1):
            rings = []
            for k in range(9):
                a = math.pi * k / 8
                ff = f - 0.66 * math.cos(a)
                rr = max(0.02, math.sin(a) ** 0.6)
                rings.append([P(ff, sd * (0.70 + 0.30 * rr * max(0.0, math.cos(b)) ** 0.7 * (1 if math.cos(b) > 0 else 0) - 0.25 * (math.cos(b) < 0) * abs(math.cos(b))), 0.40 + 0.38 * rr * math.sin(b)) for b in [math.tau * q / 10 for q in range(10)]])
            pn = loft('pontoon', rings, M['paint'], cap_start=True, cap_end=True)
            subsurf(pn, 2)
            outward(pn, P(f, sd * 0.7, 0.4))
            boolean(body, pn, 'UNION')
    for f in (AX_F, AX_R):
        for sd in (1, -1):
            boolean(body, cyl_cutter(f, WR, WR + 0.08, sd * 0.50, sd * 1.4, M['trim']))
    outward(body, None, 38)
    bvh = bvh_of(body)
    parts = new_parts(body)
    for f in (AX_F, AX_R):
        for sd in (1, -1):
            parts['trim'].append(arch_lip('lip', f, WR, WR + 0.08, sd * 0.955, M['trim'], radial=0.04, axial=0.05))
    can_st = [(1.42, 0.25, 0.80, 0.80), (1.22, 0.56, 0.82, 0.98), (0.80, 0.72, 0.85, 1.24), (0.25, 0.77, 0.88, 1.43), (-0.40, 0.775, 0.90, 1.50),
              (-1.05, 0.76, 0.92, 1.47), (-1.55, 0.72, 0.93, 1.38), (-1.86, 0.62, 0.92, 1.20), (-1.97, 0.50, 0.90, 1.02)]
    canopy = build_canopy('glass', can_st, M['glass'], expo=3.2)
    canopy.name = 'Glass'
    cb = bvh_of(canopy)
    greenhouse(parts, cb, M, (0.42, -1.92, 1.20, 0.25, 0.4), [(0.95, 0.50, 0.10), (-0.30, -0.36, 0.12), (-1.50, -1.42, 0.22)], 0.82)
    parts['trim'].append(blade('fin', [(-1.10, 1.44, 1.475, 0.016, 0.008), (-1.40, 1.40, 1.56, 0.014, 0.005), (-1.68, 1.34, 1.62, 0.012, 0.004), (-1.82, 1.42, 1.63, 0.006, 0.003)], M['trim']))
    # round lamps in a dark visor over a chunky bumper; round afterburner lamps behind
    parts['trim'].append(ribbon('head_bezel', bvh, water_rays(0.9, 0.615, -50, 50, 70), 0.16, 0.003, M['trim'], across=2))
    for sd in (1, -1):
        parts['head'].append(ribbon('head', bvh, water_rays(0.9, 0.62, sd * 24, sd * 46, 24), 0.105, 0.006, M['head'], across=2))
        parts['head'].append(ribbon('ind', bvh, water_rays(0.9, 0.62, sd * 17, sd * 22, 8), 0.105, 0.006, M['amber'], across=2))
    for i in range(3):
        parts['chrome'].append(ribbon('slat', bvh, water_rays(0.9, 0.585 + i * 0.035, -14, 14, 24), 0.016, 0.006, M['chrome']))
    parts['trim'].append(tube('bump_f', bvh, water_rays(0.9, 0.40, -56, 56, 40), 0.075, 0.012, M['trim'], squash=0.8))
    parts['trim'].append(tube('bump_r', bvh, water_rays(-0.9, 0.44, 124, 236, 40), 0.075, 0.012, M['trim'], squash=0.8))
    parts['chrome'].append(ribbon('plate_f', bvh, water_rays(0.9, 0.40, -6, 6, 8), 0.10, 0.085, M['plate']))
    parts['trim'].append(ribbon('tail_panel', bvh, water_rays(-0.9, 0.72, 150, 210, 50), 0.30, 0.003, M['trim'], across=4))
    parts['chrome'].append(ribbon('plate_r', bvh, water_rays(-0.9, 0.72, 174, 186, 8), 0.11, 0.006, M['plate']))
    for sd in (1, -1):
        parts['trim'] += nozzle('lamp', bvh, sd * 0.40, 0.72, 0.105, M, depth=0.10)
        parts['neon'].append(ribbon('pin', bvh, side_rays([(0.72, 0.80), (-0.70, 0.83)], sd), 0.022, 0.006, M['neon']))
        parts['trim'].append(ribbon('sill', bvh, side_rays([(0.72, 0.28), (-0.72, 0.28)], sd), 0.13, 0.004, M['trim'], across=2))
        parts['gap'].append(ribbon('door_f', bvh, side_rays([(0.62, 0.36), (0.62, 0.86)], sd, 0.03), 0.012, 0.0025, M['gap']))
        parts['gap'].append(ribbon('door_r', bvh, side_rays([(-0.44, 0.36), (-0.44, 0.88)], sd, 0.03), 0.012, 0.0025, M['gap']))
    parts['gap'].append(ribbon('bonnet', bvh, top_rays([(1.30, -0.60), (1.36, 0.0), (1.30, 0.60)], 0.03), 0.012, 0.0025, M['gap']))
    fittings(parts, bvh, M, mirror=(0.86, 0.80), handles=[(0.10, 0.72)], antenna=(1.05, 0.55), exhaust=(-0.45, 0.30), roof_rack=(cb, 0.15, -1.25, 0.50))
    door = {'f0': -0.44, 'f1': 0.62, 'u0': 0.36, 'u1': 3.0, 's_in': 0.72, 's_out': 0.87, 'belt': 0.86, 'cab': (-0.78, 0.78, 0.28, 3.0),
            'seat': (0.06, 0.40, 0.53), 'wheel': (0.46, 0.40, 0.95, 0.55, 0.17)}
    wl = [(AX_F, TRACK, WR, WW), (AX_F, -TRACK, WR, WW), (AX_R, TRACK, WR, WW), (AX_R, -TRACK, WR, WW)]
    return finish(parts, [canopy], wl, M, blades=7, door=door)


# ---------------------------------------------------------------- run
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o)
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'more_cars.py')).read())
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sky_cars.py')).read())
objs = {'sedan': cruiser, 'hatch': pod, 'taxi': taxi, 'van': van, 'truck': truck, 'bus': bus, 'saucerG': saucer_g, 'saucerN': saucer_n, 'saucerB': saucer_b, 'skyLimo': sky_limo, 'skyDart': sky_dart}[CAR]()
root = bpy.data.objects.new('Car_' + CAR, None)
bpy.context.scene.collection.objects.link(root)
tris = 0
for o in objs:
    o.parent = root
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
print('TRIS', CAR, 'lod' if LOD else 'full', tris)
os.makedirs(OUT, exist_ok=True)

GROUP = {'Paint': 'CarPaint', 'Glass': 'CarGlass', 'Dome': 'CarDome', 'LightHead': 'CarLights', 'LightTail': 'CarLights', 'LightAmber': 'CarLights', 'Neon': 'CarLights', 'Sign': 'CarLights'}
GAME_MATS = {}


def bake(ob):
    """the game's surfaces: what each material was goes into vertex colour and UV, and the mesh keeps four materials at most"""
    me = ob.data
    info = []
    groups = []
    for m in me.materials:
        b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
        g = GROUP.get(m.name.split('.')[0], 'CarParts')
        if g == 'CarLights':
            c = tuple(b.inputs['Emission Color'].default_value[:3])
            uv = (min(1.0, b.inputs['Emission Strength'].default_value / 16.0), 0.0)
        else:
            c = (1.0, 1.0, 1.0) if g == 'CarPaint' else tuple(b.inputs['Base Color'].default_value[:3])      # (the paint takes the car's own colour in the game)
            uv = (b.inputs['Metallic'].default_value, b.inputs['Roughness'].default_value)
        if g not in groups:
            groups.append(g)
        info.append((groups.index(g), c, uv))
    col = me.color_attributes.new('Col', 'FLOAT_COLOR', 'CORNER')
    uvl = me.uv_layers.new(name='UVMap')
    slot = []
    for p in me.polygons:
        gi, c, uv = info[p.material_index]
        for li in p.loop_indices:
            col.data[li].color = (c[0], c[1], c[2], 1.0)
            uvl.data[li].uv = (uv[0], 1.0 - uv[1])      # (the exporter flips V)
        slot.append(gi)
    me.materials.clear()      # (this resets every polygon's slot: they are set after it)
    for g in groups:
        if g not in GAME_MATS:
            GAME_MATS[g] = bpy.data.materials.new(g)
        me.materials.append(GAME_MATS[g])
    me.polygons.foreach_set('material_index', slot)
    me.color_attributes.active_color = col


if not RENDER:
    for o in objs:
        bake(o)
for o in bpy.data.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, CAR + ('_street' if LOD else '') + '.glb'), export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_vertex_color='ACTIVE', export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True)

if RENDER:
    sc = bpy.context.scene
    for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
        try:
            sc.render.engine = eng
            break
        except Exception:
            pass
    sc.render.resolution_x = 1200
    sc.render.resolution_y = 675
    w = bpy.data.worlds.new('w')
    sc.world = w
    try:
        w.use_nodes = True
    except Exception:
        pass
    bg = next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs[0].default_value = (0.05, 0.03, 0.09, 1)
    bg.inputs[1].default_value = 1.0
    g = mesh_obj('ground', [(-40, -40, 0), (40, -40, 0), (40, 40, 0), (-40, 40, 0)], [(0, 1, 2, 3)], mat('ground', (0.02, 0.018, 0.03), rough=0.22), smooth=False)

    def light(name, loc, energy, color, size):
        ld = bpy.data.lights.new(name, 'AREA')
        ld.energy = energy
        ld.color = color
        ld.size = size
        lo = bpy.data.objects.new(name, ld)
        lo.location = loc
        sc.collection.objects.link(lo)
        d = Vector((0, 0, 0.6)) - Vector(loc)
        lo.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    K = VIEW_K
    light('key', (3.5 * K, -5.0 * K, 5.0 * K), 2600 * K * K, (0.75, 0.72, 1.0), 5.0 * K)
    light('rim', (-4.5 * K, 5.0 * K, 3.0 * K), 2200 * K * K, (1.0, 0.35, 0.6), 4.0 * K)
    light('top', (0.0, 0.0, 7.0 * K), 1500 * K * K, (0.6, 0.65, 1.0), 9.0 * K)
    cd = bpy.data.cameras.new('cam')
    cd.lens = 50
    co = bpy.data.objects.new('cam', cd)
    sc.collection.objects.link(co)
    sc.camera = co
    views = {'front34': (4.2, -5.6, 1.7), 'rear34': (-4.4, 5.4, 1.9)}
    for nm, loc in views.items():
        co.location = Vector(loc) * K
        co.rotation_euler = (Vector((0, 0, 0.6 * K)) - Vector(loc) * K).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(OUT, '%s_%s.png' % (CAR, nm))
        bpy.ops.render.render(write_still=True)
