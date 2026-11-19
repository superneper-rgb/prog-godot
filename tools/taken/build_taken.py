# Builds the Taken (assets/underfoint/taken.glb): the Sigil's hive stragglers in UNDERFOINT, townsfolk gone wrong. One jointed body with three heads (a husk, a frog-folk, a TV-head);
# enemies/taken_view.gd shows one head per copy and poses the joints. Rigid parts only: every mesh hangs on one joint (an Empty whose custom property js_name is "J_<joint>", which
# enemies/creature_model.gd reads), so any number of Taken is a handful of draws.
#   Run inside Blender (the Blender MCP): exec(open("F:/prog-godot/tools/taken/build_taken.py").read()); build(); export()      preview(path, head) renders a look.
#   Or headless: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/taken/build_taken.py -- --export
#   It works in a scene of its own ("Taken") and touches nothing else in the open file; cleanup() removes everything it made.
# Written in the game's space: metres, y up, the figure faces +z, its left is +x. Blender's is (x, -z, y), converted when a mesh is made.
# All colour is vertex colour (linear), multiplied by a white material: a part's own tone, darker underneath and in hollows, mottled with rot. The material names are what the game
# reads: "wet_<rim hex>_<strength>_0" gives skin its clammy rim, "sigilGlow" follows the copy's glow colour (phosphor green, amber on the wind-up).
import bpy, bmesh, math, random
from mathutils import Vector, noise

OUT = "F:/prog-godot/assets/underfoint/taken.glb"
SCENE = "Taken"
RNG = random.Random(1337)
TAU = math.pi * 2


def lin(hexs):
    c = [int(hexs[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c]


SKIN = lin("a3a585")      # the pallor
BRUISE = lin("5a3f5c")
ROT = lin("2c3222")
WOUND = lin("6e2018")
BONE = lin("cfc5a4")
CLOTH_A = lin("7a6a44")   # what is left of a coat
CLOTH_B = lin("3c4c5c")   # and of trousers
RUBBER = lin("0d0d0f")
METAL = lin("6d5a48")
PLASTIC = lin("8c8672")
DARK = lin("070707")

SKIN_M = "wet_7a8a6a_38_0"
MATS = {}      # name -> material
MAT_DEF = {
    "wet_7a8a6a_38_0": (0.62, 0.0, None),      # skin
    "cloth": (0.95, 0.0, None),
    "bone": (0.55, 0.0, None),
    "cable": (0.3, 0.0, None),
    "metal": (0.45, 0.8, None),
    "plastic": (0.5, 0.0, None),
    "sigilGlow": (1.0, 0.0, (0.35, 1.0, 0.45)),
}
J = {}         # joint name -> (Empty, world position in game space)
PARTS = []


def G(v):
    return Vector((v[0], -v[2], v[1]))


def mat(name):
    full = name + "_0"      # (the game drops the last _<index>, as the three.js exporter adds one)
    if full in MATS:
        return MATS[full]
    r, m, e = MAT_DEF[name]
    old = bpy.data.materials.get(full)      # (one left by an earlier run would push this one's name to "<name>.001")
    if old is not None:
        bpy.data.materials.remove(old)
    mt = bpy.data.materials.new(full)
    mt.use_nodes = True
    b = mt.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (1, 1, 1, 1)
    b.inputs["Roughness"].default_value = r
    b.inputs["Metallic"].default_value = m
    if e:
        b.inputs["Emission Color"].default_value = (*e, 1)
        b.inputs["Emission Strength"].default_value = 2.0
    vc = mt.node_tree.nodes.new("ShaderNodeVertexColor")      # (for the preview render only: the game multiplies the vertex colour itself)
    vc.layer_name = "Col"
    mt.node_tree.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    MATS[full] = mt
    return mt


def joint(name, pos, parent=None):
    e = bpy.data.objects.new("J_" + name, None)
    e.empty_display_size = 0.03
    e["js_name"] = "J_" + name
    bpy.data.scenes[SCENE].collection.objects.link(e)
    pw = J[parent][1] if parent else (0.0, 0.0, 0.0)
    if parent:
        e.parent = J[parent][0]
    e.location = G((pos[0] - pw[0], pos[1] - pw[1], pos[2] - pw[2]))
    J[name] = (e, pos)
    return e


class Geo:
    """Vertices in game space (world), faces, a base colour per vertex."""

    def __init__(self):
        self.v = []
        self.f = []
        self.c = []

    def add(self, verts, faces, col):
        b = len(self.v)
        self.v += verts
        self.c += [col] * len(verts)
        self.f += [[b + i for i in f] for f in faces]
        return range(b, b + len(verts))

    def loft(self, rings, sides, col, axis="y", caps=(True, True), shape=None):
        """rings: (centre, r_a, r_b) stacked along `axis`; a ring lies across it (y: x/z, z: x/y). shape(i, a) -> radius multiplier."""
        if len(rings) > 2 and max(r[1] for r in rings) > 0.02:      # a body part, not a wire: smooth it (rings interpolated Catmull-Rom, half as many sides again)
            rings = _smooth_rings(rings, 3)
            sides = int(round(sides * 1.5))
        vs = []
        for i, (c, ra, rb) in enumerate(rings):
            for k in range(sides):
                a = TAU * k / sides
                m = shape(i, a) if shape else 1.0
                ca = math.cos(a) * ra * m
                sa = math.sin(a) * rb * m
                vs.append((c[0] + ca, c[1], c[2] + sa) if axis == "y" else (c[0] + ca, c[1] + sa, c[2]))
        fs = []
        for i in range(len(rings) - 1):
            for k in range(sides):
                k2 = (k + 1) % sides
                fs.append([i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k])
        if caps[0]:
            fs.append(list(range(sides)))
        if caps[1]:
            fs.append(list(range((len(rings) - 1) * sides, len(rings) * sides)))
        return self.add(vs, fs, col)

    def box(self, c, hx, hy, hz, col, taper=1.0):
        """taper: the top face's size against the bottom's"""
        vs = []
        for sy in (-1, 1):
            t = taper if sy > 0 else 1.0
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                vs.append((c[0] + sx * hx * t, c[1] + sy * hy, c[2] + sz * hz * t))
        return self.add(vs, [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]], col)

    def ball(self, c, r, col, sides=8, rings=5, squash=(1.0, 1.0, 1.0)):
        rs = []
        for i in range(rings + 1):
            t = math.pi * i / rings
            rr = max(0.0005, math.sin(t) * r)
            rs.append(((c[0], c[1] - math.cos(t) * r * squash[1], c[2]), rr * squash[0], rr * squash[2]))
        return self.loft(rs, sides, col)

    def arc(self, c, ra, rb, a0, a1, w, h, col, n=7):
        """a bar bent round a level ellipse from angle a0 to a1 (0 = +x, 90 deg = +z): w thick outward, h tall"""
        rs = []
        vs = []
        for i in range(n + 1):
            a = a0 + (a1 - a0) * i / n
            for dr, dy in ((0, -h), (w, -h), (w, h), (0, h)):
                vs.append((c[0] + math.cos(a) * (ra + dr), c[1] + dy, c[2] + math.sin(a) * (rb + dr)))
        fs = []
        for i in range(n):
            for k in range(4):
                k2 = (k + 1) % 4
                fs.append([i * 4 + k, i * 4 + k2, (i + 1) * 4 + k2, (i + 1) * 4 + k])
        fs += [[0, 1, 2, 3], [n * 4, n * 4 + 1, n * 4 + 2, n * 4 + 3]]
        return self.add(vs, fs, col)


def _smooth_rings(rings, n):
    out = []
    flat = [(r[0][0], r[0][1], r[0][2], r[1], r[2]) for r in rings]
    for i in range(len(flat) - 1):
        p0 = flat[max(0, i - 1)]
        p1 = flat[i]
        p2 = flat[i + 1]
        p3 = flat[min(len(flat) - 1, i + 2)]
        for k in range(n):
            t = k / n
            v = [0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t * t * t) for j in range(5)]
            out.append(((v[0], v[1], v[2]), max(0.001, v[3]), max(0.001, v[4])))
    out.append(rings[-1])
    return out


def strip(g, top, out, w, ln, col, sway=0.0):
    """a rag hanging from `top`: `out` is the level direction it faces, w its width, ln its length; it narrows and curls out a little as it falls"""
    tx, tz = -out[1], out[0]
    vs = []
    for i, (f, wk) in enumerate(((0.0, 1.0), (0.45, 0.85), (0.8, 0.6), (1.0, 0.25))):
        push = 0.012 + 0.03 * f * f + sway * f
        for side in (-1, 1):
            for th in (0.0, 0.006):
                vs.append((top[0] + tx * side * w * 0.5 * wk + out[0] * (push + th), top[1] - ln * f, top[2] + tz * side * w * 0.5 * wk + out[1] * (push + th)))
    fs = []
    for i in range(3):
        a = i * 4
        b = a + 4
        fs += [[a, a + 2, b + 2, b], [a + 1, b + 1, b + 3, a + 3], [a, b, b + 1, a + 1], [a + 2, a + 3, b + 3, b + 2]]
    fs += [[0, 1, 3, 2], [12, 14, 15, 13]]
    return g.add(vs, fs, col)


def part(jname, mname, geo, lumpy=0.0, smooth=True, shade=True, paint=None):
    """Make the mesh of `geo` on joint `jname` with material `mname`. lumpy: how far rot pushes the surface about. paint(p, n, col) -> col recolours a vertex."""
    jo, jp = J[jname]
    me = bpy.data.meshes.new("%s_%s_%d" % (jname, mname.split("_")[0], len(PARTS)))
    bm = bmesh.new()
    vs = [bm.verts.new(G((p[0] - jp[0], p[1] - jp[1], p[2] - jp[2]))) for p in geo.v]
    lay = bm.loops.layers.float_color.new("Col")
    for f in geo.f:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    if lumpy > 0.0:
        for i, v in enumerate(bm.verts):
            p = Vector(geo.v[i])
            v.co += v.normal * (noise.noise(p * 14.0) * lumpy)
        bm.normal_update()
    cols = []
    for i, v in enumerate(bm.verts):
        p = Vector(geo.v[i])
        col = list(geo.c[i])
        n_up = v.normal.z      # (Blender's z is up)
        if shade:
            mott = 0.5 + 0.5 * noise.noise(p * 13.0 + Vector((3.1, 7.7, 1.3)))
            rot = max(0.0, min(1.0, (noise.noise(p * 6.0 + Vector((11.0, 2.0, 5.0))) + 0.02) * 3.0))
            sore = max(0.0, min(1.0, (noise.noise(p * 8.5 + Vector((1.0, 9.0, 21.0))) - 0.38) * 7.0))
            vein = 1.0 - min(1.0, abs(noise.noise(p * 19.0 + Vector((7.0, 3.0, 2.0)))) * 9.0)
            if mname.startswith("wet"):
                col = [col[k] + (BRUISE[k] - col[k]) * 0.7 * (1.0 - mott) for k in range(3)]
                col = [col[k] + (ROT[k] - col[k]) * 0.85 * rot for k in range(3)]
                col = [col[k] + (BRUISE[k] * 0.6 - col[k]) * 0.6 * vein for k in range(3)]
                col = [col[k] + (WOUND[k] - col[k]) * 0.8 * sore for k in range(3)]
            else:
                col = [col[k] * (0.6 + 0.6 * mott) * (1.0 - 0.6 * rot) for k in range(3)]
            occ = 0.45 + 0.55 * max(0.0, min(1.0, n_up * 0.5 + 0.5))      # darker underneath: a cheap stand-in for occlusion
            col = [c * occ for c in col]
        if paint:
            col = paint(p, v.normal, col)
        cols.append(col)
    for f in bm.faces:
        f.smooth = smooth
        for lp in f.loops:
            c = cols[lp.vert.index]
            lp[lay] = (c[0], c[1], c[2], 1.0)
    bm.to_mesh(me)
    bm.free()
    me.color_attributes.active_color = me.color_attributes["Col"]      # (the exporter writes the ACTIVE colour: unset, the GLB has none)
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    me.materials.append(mat(mname))
    ob = bpy.data.objects.new(me.name, me)
    bpy.data.scenes[SCENE].collection.objects.link(ob)
    ob.parent = jo
    PARTS.append(ob)
    return ob


def scene():
    sc = bpy.data.scenes.get(SCENE)
    if sc is None:
        sc = bpy.data.scenes.new(SCENE)
    return sc


def cleanup():
    """Everything build() made, gone: the open file is left as it was."""
    sc = bpy.data.scenes.get(SCENE)
    if sc is not None:
        for o in list(sc.collection.all_objects):
            d = o.data
            bpy.data.objects.remove(o, do_unlink=True)
            if d is not None and d.users == 0:
                if isinstance(d, bpy.types.Mesh):
                    bpy.data.meshes.remove(d)
                elif isinstance(d, bpy.types.Camera):
                    bpy.data.cameras.remove(d)
                elif isinstance(d, bpy.types.Light):
                    bpy.data.lights.remove(d)
        if sc.world is not None and sc.world.name == "TakenWorld":
            bpy.data.worlds.remove(sc.world)
        bpy.data.scenes.remove(sc)
    for m in list(MATS.values()):
        try:
            bpy.data.materials.remove(m)
        except ReferenceError:
            pass
    for name in MAT_DEF:
        old = bpy.data.materials.get(name + "_0")
        if old is not None and old.users == 0:
            bpy.data.materials.remove(old)
    MATS.clear()
    J.clear()
    PARTS.clear()


# ---- the figure ---------------------------------------------------------------------------------------------------------------------------------------------------------

def build():
    cleanup()
    scene()
    joint("pelvis", (0, 0.95, 0))
    joint("spine", (0, 1.06, 0), "pelvis")
    joint("chest", (0, 1.24, 0), "spine")
    joint("neck", (0, 1.49, 0.01), "chest")
    for h in ("head_a", "head_b", "head_c"):
        joint(h, (0, 1.58, 0.03), "neck")
    joint("jaw_a", (0, 1.60, 0.03), "head_a")
    joint("jaw_b", (0, 1.60, 0.02), "head_b")
    for i in range(4):
        joint("cable%d" % i, (0, 1.56 - i * 0.3, -0.1), "neck" if i == 0 else "cable%d" % (i - 1))
    for s, t in ((1, "L"), (-1, "R")):
        joint("upper_arm" + t, (s * 0.215, 1.44, 0), "chest")
        joint("forearm" + t, (s * 0.25, 1.15, 0), "upper_arm" + t)
        joint("hand" + t, (s * 0.275, 0.805, 0.04), "forearm" + t)
        joint("thigh" + t, (s * 0.1, 0.92, 0), "pelvis")
        joint("shin" + t, (s * 0.11, 0.5, 0.01), "thigh" + t)
        joint("foot" + t, (s * 0.11, 0.09, 0), "shin" + t)
    _torso()
    _head_husk()
    _head_frog()
    _head_tv()
    _cable()
    for s, t in ((1, "L"), (-1, "R")):
        _arm(s, t)
        _leg(s, t)
    return {"parts": len(PARTS), "joints": len(J), "tris": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in PARTS)}


def _ragged(depth, seed):
    """a hem that hangs in tatters: the lowest ring's points drop by a random amount"""
    r = random.Random(seed)
    drops = [r.random() * depth for _ in range(64)]
    return drops


def _torso():
    # hips: what is left of his trousers, the waistband torn
    g = Geo()
    g.loft([((0, 0.83, 0), 0.12, 0.09), ((0, 0.9, 0), 0.165, 0.115), ((0, 0.98, 0), 0.168, 0.11), ((0, 1.04, -0.005), 0.132, 0.09)], 12, CLOTH_B)
    part("pelvis", "cloth", g, 0.004)
    # belly: sunk in under the ribs, the spine's knuckles standing out behind
    g = Geo()
    g.loft([((0, 1.0, -0.005), 0.125, 0.085), ((0, 1.07, -0.012), 0.104, 0.07), ((0, 1.15, -0.012), 0.108, 0.074), ((0, 1.22, -0.005), 0.135, 0.092)], 12, SKIN, caps=(True, True))
    for i in range(4):
        g.ball((0, 1.03 + i * 0.055, -0.082), 0.018, BONE, 6, 3)
    part("spine", SKIN_M, g, 0.006)
    # ribcage: narrow, every rib showing (painted), the skin gone on his left side where three ribs stand clear
    def ribs(p, n, col):
        front = max(0.0, n.x * (1.0 if p.x > 0 else -1.0) * 0.6 + (-n.y) * 0.8)      # sides and front (Blender -y is the front)
        if 1.19 < p.y < 1.44:
            groove = 0.5 + 0.5 * math.sin((p.y - 1.19) * TAU / 0.042)
            col = [c * (1.0 - 0.42 * groove * min(1.0, front + 0.35)) for c in col]
        if p.x > 0.07 and 1.2 < p.y < 1.37 and p.z > -0.02:      # the wound
            k = min(1.0, (p.x - 0.07) * 14.0)
            col = [col[i] + (WOUND[i] * 0.55 - col[i]) * k for i in range(3)]
        return col
    g = Geo()
    g.loft([((0, 1.17, -0.005), 0.134, 0.092), ((0, 1.25, 0), 0.172, 0.112), ((0, 1.35, -0.005), 0.186, 0.118), ((0, 1.43, -0.012), 0.17, 0.102), ((0, 1.485, -0.005), 0.085, 0.066), ((0, 1.5, 0.005), 0.05, 0.048)], 14, SKIN)
    for s in (1, -1):
        g.ball((s * 0.212, 1.44, -0.005), 0.062, SKIN, 8, 4)
    g.ball((0, 1.47, -0.075), 0.03, SKIN, 6, 3)      # the hump of the top vertebra
    part("chest", SKIN_M, g, 0.006, paint=ribs)
    g = Geo()
    for i in range(3):
        y = 1.225 + i * 0.045
        g.arc((0, y, 0), 0.172 + i * 0.005, 0.113, math.radians(8), math.radians(78), 0.014, 0.008, BONE, 6)
    part("chest", "bone", g)
    # what is left of a coat: a collar round the shoulders and the strips still hanging off it, each a different length
    g = Geo()
    g.loft([((0, 1.475, -0.004), 0.1, 0.082), ((0, 1.45, -0.006), 0.165, 0.112), ((0, 1.415, -0.008), 0.205, 0.13)], 12, CLOTH_A, caps=(False, False))
    rr = random.Random(5)
    for k in range(13):
        a = TAU * (k + rr.random() * 0.5) / 13
        out = (math.cos(a), math.sin(a))
        strip(g, (out[0] * 0.203, 1.42, out[1] * 0.128 - 0.008), out, 0.05 + rr.random() * 0.045, 0.07 + rr.random() ** 2 * 0.36, CLOTH_A if rr.random() < 0.7 else CLOTH_B)
    part("chest", "cloth", g, 0.004)
    # the port they put in his breastbone: a plate, four bolts, and the light in it
    g = Geo()
    g.box((-0.035, 1.32, 0.116), 0.036, 0.042, 0.008, METAL)
    for sx in (-1, 1):
        for sy in (-1, 1):
            g.box((-0.035 + sx * 0.027, 1.32 + sy * 0.033, 0.126), 0.006, 0.006, 0.004, METAL)
    part("chest", "metal", g, smooth=False)
    g = Geo()
    g.loft([((-0.035, 1.32, 0.125), 0.016, 0.016), ((-0.035, 1.32, 0.129), 0.012, 0.012)], 8, DARK, axis="z", caps=(False, True))
    part("chest", "sigilGlow", g, shade=False)
    # neck, and the socket at the nape the cable runs from
    g = Geo()
    g.loft([((0, 1.46, 0.0), 0.052, 0.05), ((0, 1.53, 0.012), 0.043, 0.045), ((0, 1.6, 0.03), 0.045, 0.048)], 9, SKIN)
    part("neck", SKIN_M, g, 0.004)
    g = Geo()
    g.loft([((0, 1.56, -0.03), 0.034, 0.034), ((0, 1.56, -0.075), 0.034, 0.034), ((0, 1.56, -0.085), 0.026, 0.026)], 8, METAL, axis="z")
    g.arc((0, 1.5, 0.008), 0.05, 0.05, 0.0, TAU, 0.008, 0.012, METAL, 10)      # a collar bolted on under it
    part("neck", "metal", g, smooth=False)


def _sockets(g, pts, r, col):
    for (x, y, z) in pts:
        g.loft([((x, y, z), r, r * 1.15), ((x, y, z - 0.012), r * 0.55, r * 0.6)], 8, col, axis="z", caps=(False, True))


def _head_husk():
    """A man's head with most of the man gone: skull under tight skin, the eyes holes with a point of light in each, the nose a pit, a plate bolted to the temple"""
    def face(p, n, col):
        for ex in (-0.036, 0.036):      # hollows round the eyes and the nose, and the cheeks sucked in
            d = math.hypot(p.x - ex, p.y - 1.672)
            if p.z > 0.06 and d < 0.04:
                col = [c * (0.3 + 0.7 * d / 0.04) for c in col]
        d = math.hypot(p.x, p.y - 1.632)
        if p.z > 0.09 and d < 0.022:
            col = [c * (0.25 + 0.75 * d / 0.022) for c in col]
        if p.z > 0.02 and 1.585 < p.y < 1.64 and abs(p.x) > 0.045:
            col = [c * 0.7 for c in col]
        return col
    g = Geo()
    g.loft([((0, 1.575, 0.04), 0.05, 0.06), ((0, 1.61, 0.045), 0.074, 0.084), ((0, 1.665, 0.04), 0.086, 0.097), ((0, 1.735, 0.022), 0.086, 0.102), ((0, 1.795, 0.012), 0.064, 0.078), ((0, 1.825, 0.01), 0.022, 0.028)], 12, SKIN)
    g.arc((0, 1.693, 0.04), 0.078, 0.092, math.radians(35), math.radians(145), 0.012, 0.009, SKIN, 6)      # the brow
    part("head_a", SKIN_M, g, 0.004, paint=face)
    g = Geo()
    _sockets(g, [(-0.036, 1.672, 0.136), (0.036, 1.672, 0.136)], 0.026, DARK)
    g.loft([((0, 1.632, 0.142), 0.011, 0.016), ((0, 1.632, 0.128), 0.005, 0.008)], 6, DARK, axis="z", caps=(False, True))
    part("head_a", "cable", g, shade=False, smooth=False)
    g = Geo()
    for ex in (-0.036, 0.036):
        g.loft([((ex, 1.672, 0.127), 0.0065, 0.0065), ((ex, 1.672, 0.13), 0.004, 0.004)], 6, DARK, axis="z", caps=(False, True))
    g.loft([((0.092, 1.735, 0.03), 0.009, 0.009), ((0.096, 1.735, 0.03), 0.006, 0.006)], 6, DARK, axis="z", caps=(False, True))
    part("head_a", "sigilGlow", g, shade=False)
    g = Geo()
    for i in range(7):      # the upper teeth
        x = (i - 3) * 0.0125
        g.box((x, 1.588, 0.118 - abs(x) * 0.35), 0.0052, 0.011, 0.005, BONE, 0.8)
    part("head_a", "bone", g, smooth=False)
    g = Geo()
    g.box((0.086, 1.735, 0.03), 0.007, 0.042, 0.05, METAL)
    for sy, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        g.box((0.094, 1.735 + sy * 0.032, 0.03 + sz * 0.04), 0.004, 0.006, 0.006, METAL)
    part("head_a", "metal", g, smooth=False)
    # the jaw: it hangs, and swings when he walks
    g = Geo()
    g.arc((0, 1.556, 0.04), 0.052, 0.07, math.radians(-15), math.radians(195), 0.014, 0.014, SKIN, 8)
    g.box((0, 1.548, 0.112), 0.022, 0.012, 0.012, SKIN)
    part("jaw_a", SKIN_M, g, 0.002)
    g = Geo()
    for i in range(6):
        x = (i - 2.5) * 0.0125
        g.box((x, 1.577, 0.112 - abs(x) * 0.35), 0.005, 0.009, 0.0045, BONE, 0.7)
    part("jaw_a", "bone", g, smooth=False)


def _head_frog():
    """One of the frog-folk: a head wider than its shoulders, eyes on top (one burst), and the mouth stapled shut right across"""
    def face(p, n, col):
        if p.z > 0.0 and abs(p.y - 1.607) < 0.012:      # the seam of the mouth
            col = [c * 0.3 for c in col]
        if p.y < 1.59:                                  # the pale throat sac
            col = [min(1.0, c * 1.25) for c in col]
        return col
    g = Geo()
    g.loft([((0, 1.55, 0.03), 0.07, 0.065), ((0, 1.585, 0.045), 0.142, 0.118), ((0, 1.607, 0.05), 0.158, 0.128), ((0, 1.65, 0.045), 0.152, 0.122), ((0, 1.7, 0.035), 0.118, 0.098), ((0, 1.728, 0.03), 0.05, 0.045)], 14, lin("7f8f6a"))
    for s in (1, -1):
        g.ball((s * 0.082, 1.722, 0.07), 0.052, lin("8a9a70"), 8, 5)
    part("head_b", SKIN_M, g, 0.005, paint=face)
    g = Geo()
    g.loft([((0.082, 1.728, 0.118), 0.024, 0.024), ((0.082, 1.728, 0.124), 0.016, 0.016)], 8, DARK, axis="z", caps=(False, True))
    part("head_b", "sigilGlow", g, shade=False)
    g = Geo()
    g.loft([((-0.082, 1.728, 0.118), 0.03, 0.03), ((-0.082, 1.728, 0.1), 0.012, 0.012)], 7, DARK, axis="z", caps=(False, True))      # the burst one: a hole
    part("head_b", "cable", g, shade=False, smooth=False)
    g = Geo()
    for i in range(9):      # the staples
        a = math.radians(90 + (i - 4) * 15.5)
        x = math.cos(a) * 0.163
        z = 0.05 + math.sin(a) * 0.133
        g.box((x, 1.607, z), 0.0035, 0.02, 0.0035, METAL)
    g.box((-0.1, 1.67, -0.04), 0.03, 0.03, 0.006, METAL)      # the plate at the back of the skull
    part("head_b", "metal", g, smooth=False)
    # the lower jaw is one piece with the head here (stapled): jaw_b only carries the throat sac, which the view swells
    g = Geo()
    g.ball((0, 1.565, 0.085), 0.06, lin("a9ac86"), 8, 4, (1.25, 0.6, 1.0))
    part("jaw_b", SKIN_M, g, 0.002)


def _head_tv():
    """A TV-head: one of the city's set-headed folk. The set is his head; the Sigil is on it now."""
    g = Geo()
    g.box((0, 1.7, 0.02), 0.135, 0.108, 0.105, PLASTIC, 0.94)
    g.box((0, 1.7, -0.11), 0.085, 0.07, 0.04, PLASTIC, 0.9)      # the tube's back
    g.loft([((0, 1.55, 0.02), 0.04, 0.04), ((0, 1.6, 0.02), 0.05, 0.05)], 8, PLASTIC)
    for i, y in enumerate((1.735, 1.7, 1.665)):      # the bezel round the glass, and three knobs down the side of it
        g.loft([((0.115, y, 0.126), 0.0085, 0.0085), ((0.115, y, 0.136), 0.007, 0.007)], 7, lin("2a2a26"), axis="z", caps=(False, True))
    g.box((-0.022, 1.805, 0.126), 0.098, 0.006, 0.006, PLASTIC)
    g.box((-0.022, 1.615, 0.126), 0.098, 0.006, 0.006, PLASTIC)
    g.box((-0.118, 1.71, 0.126), 0.006, 0.09, 0.006, PLASTIC)
    g.box((0.076, 1.71, 0.126), 0.006, 0.09, 0.006, PLASTIC)
    part("head_c", "plastic", g, smooth=False)
    g = Geo()
    n = 6      # the glass, bulged a little
    vs = []
    for iy in range(n + 1):
        for ix in range(n + 1):
            u = ix / n * 2 - 1
            v = iy / n * 2 - 1
            vs.append((-0.021 + u * 0.09, 1.71 + v * 0.086, 0.127 + 0.012 * (1 - u * u) * (1 - v * v)))
    fs = [[iy * (n + 1) + ix, iy * (n + 1) + ix + 1, (iy + 1) * (n + 1) + ix + 1, (iy + 1) * (n + 1) + ix] for iy in range(n) for ix in range(n)]
    g.add(vs, fs, DARK)
    part("head_c", "sigilGlow", g, shade=False)
    g = Geo()
    g.loft([((0.05, 1.808, -0.02), 0.004, 0.004), ((0.085, 1.93, -0.04), 0.003, 0.003), ((0.12, 2.0, -0.03), 0.002, 0.002)], 5, METAL)      # aerials, one bent double
    g.loft([((-0.05, 1.808, -0.02), 0.004, 0.004), ((-0.08, 1.9, -0.03), 0.003, 0.003), ((-0.14, 1.885, 0.0), 0.002, 0.002)], 5, METAL)
    for i in range(4):      # vent slots along the top
        g.box((-0.06 + i * 0.03, 1.809, -0.04), 0.009, 0.002, 0.03, lin("1a1a18"))
    part("head_c", "metal", g, smooth=False)


def _cable():
    """The cable out of the nape, cut: four ribbed lengths that drag behind him, bare wire and a spit of light at the end"""
    for i in range(4):
        y0 = 1.56 - i * 0.3
        g = Geo()
        rs = []
        for k in range(7):
            rs.append(((0, y0 - k * 0.05, -0.1), 0.021 if k % 2 == 0 else 0.026, 0.021 if k % 2 == 0 else 0.026))
        g.loft(rs, 7, RUBBER)
        if i == 0:
            g.loft([((0, 1.56, -0.08), 0.03, 0.03), ((0, 1.56, -0.12), 0.024, 0.024)], 7, RUBBER, axis="z")
        part("cable%d" % i, "cable", g, shade=False)
        if i == 3:
            g = Geo()
            for dx, dz, ln in ((0.008, 0.004, 0.07), (-0.007, 0.008, 0.05), (0.0, -0.009, 0.085)):
                g.loft([((dx, y0 - 0.3, -0.1 + dz), 0.004, 0.004), ((dx * 2.4, y0 - 0.3 - ln, -0.1 + dz * 2.4), 0.002, 0.002)], 4, lin("b87333"))
            part("cable3", "metal", g, shade=False, smooth=False)
            g = Geo()
            g.ball((0, y0 - 0.385, -0.1), 0.012, DARK, 6, 3)
            part("cable3", "sigilGlow", g, shade=False)


def _arm(s, t):
    """Arms gone to string and too long: the hands hang at the knee. His left keeps a sleeve; on his right the forearm is two bare bones."""
    g = Geo()
    g.loft([((s * 0.215, 1.45, 0), 0.05, 0.05), ((s * 0.226, 1.36, 0), 0.043, 0.045), ((s * 0.24, 1.25, 0), 0.033, 0.035), ((s * 0.25, 1.16, 0), 0.029, 0.03)], 8, CLOTH_A if s > 0 else SKIN)
    if s > 0:
        rr = random.Random(21)
        for k in range(5):
            a = TAU * k / 5 + 0.4
            out = (math.cos(a), math.sin(a))
            strip(g, (s * 0.25 + out[0] * 0.03, 1.17, out[1] * 0.031), out, 0.035, 0.05 + rr.random() * 0.12, CLOTH_A)
    part("upper_arm" + t, "cloth" if s > 0 else SKIN_M, g, 0.004)
    g = Geo()
    g.ball((s * 0.25, 1.15, 0), 0.036, SKIN, 7, 4)
    if s > 0:
        g.loft([((s * 0.25, 1.15, 0), 0.031, 0.032), ((s * 0.254, 1.07, 0.005), 0.034, 0.036), ((s * 0.264, 0.94, 0.022), 0.025, 0.027), ((s * 0.275, 0.805, 0.04), 0.02, 0.022)], 8, SKIN)
    else:
        g.loft([((s * 0.25, 1.15, 0), 0.031, 0.032), ((s * 0.254, 1.08, 0.005), 0.032, 0.033), ((s * 0.256, 1.045, 0.008), 0.026, 0.027), ((s * 0.257, 1.02, 0.01), 0.012, 0.014)], 8, SKIN)
    part("forearm" + t, SKIN_M, g, 0.004)
    if s < 0:
        g = Geo()
        for dz in (-0.012, 0.013):
            g.loft([((s * 0.256, 1.05, 0.008 + dz), 0.009, 0.009), ((s * 0.262, 0.99, 0.016 + dz), 0.0065, 0.0065), ((s * 0.27, 0.87, 0.032 + dz), 0.0065, 0.0065), ((s * 0.275, 0.805, 0.04 + dz * 0.8), 0.01, 0.01)], 6, BONE)
        part("forearm" + t, "bone", g)
    # the hand: a long palm and three fingers gone to claws, and a thumb
    def nails(p, n, col):
        return [c * 0.3 for c in col] if p.y < 0.6 else col
    g = Geo()
    g.loft([((s * 0.275, 0.815, 0.04), 0.018, 0.026), ((s * 0.278, 0.76, 0.046), 0.018, 0.046), ((s * 0.28, 0.7, 0.05), 0.015, 0.05)], 8, SKIN)
    for k, dz in enumerate((-0.034, 0.0, 0.034)):
        ln = (0.135, 0.16, 0.14)[k]
        g.loft([((s * 0.28, 0.705, 0.05 + dz), 0.0125, 0.0125), ((s * 0.287, 0.705 - ln * 0.5, 0.056 + dz * 1.3), 0.01, 0.01), ((s * 0.28, 0.705 - ln * 0.82, 0.066 + dz * 1.45), 0.007, 0.007), ((s * 0.27, 0.705 - ln, 0.078 + dz * 1.5), 0.002, 0.002)], 5, SKIN)
    g.loft([((s * 0.272, 0.775, 0.085), 0.013, 0.013), ((s * 0.264, 0.725, 0.116), 0.01, 0.01), ((s * 0.258, 0.68, 0.125), 0.003, 0.003)], 5, SKIN)
    part("hand" + t, SKIN_M, g, 0.002, paint=nails)


def _leg(s, t):
    """Legs: his left still in a trouser leg torn off at the knee, his right bare and gone the colour of the rest of him"""
    drops = _ragged(0.07, 9)
    g = Geo()
    if s > 0:
        n = 10
        vs = []
        for i, (y, cx, ra, rb) in enumerate(((0.95, 0.1, 0.078, 0.084), (0.76, 0.105, 0.07, 0.076), (0.57, 0.11, 0.062, 0.066))):
            for k in range(n):
                a = TAU * k / n
                vs.append((s * cx + math.cos(a) * ra, y - (drops[k] if i == 2 else 0.0), math.sin(a) * rb))
        fs = [[i * n + k, i * n + (k + 1) % n, (i + 1) * n + (k + 1) % n, (i + 1) * n + k] for i in range(2) for k in range(n)]
        fs.append(list(range(n)))
        g.add(vs, fs, CLOTH_B)
        part("thigh" + t, "cloth", g, 0.005)
        g = Geo()
        g.loft([((s * 0.105, 0.7, 0), 0.05, 0.054), ((s * 0.11, 0.52, 0.005), 0.043, 0.046)], 8, SKIN)
        g.ball((s * 0.11, 0.5, 0.012), 0.046, SKIN, 7, 4)
        part("thigh" + t, SKIN_M, g, 0.004)
    else:
        g.loft([((s * 0.1, 0.95, 0), 0.07, 0.076), ((s * 0.105, 0.76, 0), 0.058, 0.064), ((s * 0.11, 0.52, 0.005), 0.043, 0.046)], 9, SKIN)
        g.ball((s * 0.11, 0.5, 0.012), 0.046, SKIN, 7, 4)
        part("thigh" + t, SKIN_M, g, 0.006)
    g = Geo()
    g.loft([((s * 0.11, 0.5, 0.01), 0.042, 0.044), ((s * 0.112, 0.4, -0.006), 0.045, 0.052), ((s * 0.112, 0.22, 0.0), 0.03, 0.032), ((s * 0.11, 0.1, 0.0), 0.027, 0.029)], 8, SKIN)
    g.ball((s * 0.11, 0.09, 0.0), 0.031, SKIN, 6, 3)
    part("shin" + t, SKIN_M, g, 0.005)
    if s < 0:      # a rag knotted round the shin
        g = Geo()
        g.loft([((s * 0.112, 0.36, -0.004), 0.05, 0.056), ((s * 0.112, 0.3, -0.002), 0.043, 0.047), ((s * 0.112, 0.25, 0.0), 0.037, 0.039)], 8, CLOTH_A, caps=(False, False))
        part("shin" + t, "cloth", g, 0.004)
    def toes(p, n, col):
        return [c * 0.5 for c in col] if p.z > 0.15 else col
    g = Geo()
    g.loft([((s * 0.11, 0.045, -0.055), 0.03, 0.04), ((s * 0.11, 0.05, 0.0), 0.037, 0.046), ((s * 0.112, 0.036, 0.08), 0.045, 0.032), ((s * 0.114, 0.022, 0.15), 0.05, 0.019), ((s * 0.114, 0.014, 0.185), 0.04, 0.01)], 8, SKIN, axis="z")
    part("foot" + t, SKIN_M, g, 0.003, paint=toes)


# ---- out --------------------------------------------------------------------------------------------------------------------------------------------------------------

def export(path=OUT):
    import os
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sc = bpy.data.scenes[SCENE]
    # Only this scene's objects (`use_selection` was tried and took whatever was selected in the file's own scene with it), and with this scene really the active one:
    # a temp_override onto a scene that has never been shown crashes Blender 5.2 in the dependency graph (BKE_base_eval_flags).
    kw = dict(filepath=path, export_format="GLB", use_selection=False, use_active_scene=True, export_apply=True, export_yup=True, export_normals=True, export_tangents=False,
              export_materials="EXPORT", export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True,
              export_extras=True, export_cameras=False, export_lights=False, export_animations=False)
    win = bpy.context.window
    if bpy.context.scene == sc or win is None:
        bpy.ops.export_scene.gltf(**kw)
    else:
        was = win.scene
        win.scene = sc
        try:
            bpy.ops.export_scene.gltf(**kw)
        finally:
            win.scene = was
    return path


def preview(path, head="a", view=(1.6, 1.25, 2.6), look=(0.0, 0.98, 0.0), res=(720, 900)):
    """Render the figure with one head showing. view / look in game space."""
    sc = bpy.data.scenes[SCENE]
    for o in sc.collection.all_objects:
        if o.type == "MESH":
            p = o.parent.name
            hide = (p.startswith("J_head_") and p != "J_head_" + head) or (p.startswith("J_jaw_") and p != "J_jaw_" + head)
            o.hide_render = hide
    cam = bpy.data.objects.get("TakenCam")
    if cam is None:
        cam = bpy.data.objects.new("TakenCam", bpy.data.cameras.new("TakenCam"))
        sc.collection.objects.link(cam)
        for nm, pos, e, colr in (("TakenKey", (2.0, 2.6, 2.4), 420.0, (0.75, 1.0, 0.82)), ("TakenRim", (-2.2, 2.0, -2.0), 300.0, (1.0, 0.6, 0.35)), ("TakenFill", (-1.5, 0.8, 2.5), 90.0, (0.6, 0.7, 1.0))):
            l = bpy.data.objects.new(nm, bpy.data.lights.new(nm, "POINT"))
            l.data.energy = e
            l.data.color = colr
            l.location = G(pos)
            sc.collection.objects.link(l)
        w = bpy.data.worlds.new("TakenWorld")
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.016, 0.014, 1)
        sc.world = w
    cam.data.lens = 50
    cam.location = G(view)
    d = G(look) - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng
            break
        except TypeError:
            pass
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.filepath = path
    sc.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True, scene=SCENE)
    for o in sc.collection.all_objects:
        o.hide_render = False
    return path


if "--export" in __import__("sys").argv:      # headless: build in the startup scene (emptied), write the GLB, say what was made
    SCENE = bpy.context.scene.name
    for o in list(bpy.context.scene.collection.all_objects):
        bpy.data.objects.remove(o, do_unlink=True)
    cleanup = lambda: None      # (nothing of anyone's to put back in a headless run, and the scene in use cannot be removed)
    print("taken:", build())
    print("wrote", export())
