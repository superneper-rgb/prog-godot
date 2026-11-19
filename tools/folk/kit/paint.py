## The folk kit's paint: per-vertex colour from the recipe (parts, gradients, eyes, occlusion and wear worked out from the clay itself) plus a shared shader for the fine layers (speckles, prints, pinstripes, fabric and leather grain).
# Attributes written on every mesh, all linear:
#   Col   rgb base colour (occlusion and wear already in), a unused
#   RM    r roughness, g metallic, b grain bump weight, a grain kind (0 fabric weave .. 1 leather)
#   Spk   rgb speckle colour, a speckle amount (0 = none)
#   Strp  r stripe coordinate (metres across the stripes), g stripe strength, b stripe darkening
#   Ink   r distance to a drawn line or (negative inside) a filled shape, g its half width, b strength: drawn crisp per pixel in near-black (eyeliner, pupils, creases)
import bpy
import numpy as np

F = np.float32


class Ctx:
    """what a recipe's paint function gets for one mesh: positions, normals, parts, occlusion, edge wear, and buffers to fill"""
    def __init__(self, P, N, part, ao, wear, cavity):
        n = len(P)
        self.P, self.N, self.part, self.ao, self.wear, self.cavity = P, N, part, ao, wear, cavity
        self.col = np.ones((n, 3), F) * 0.5
        self.rough = np.full(n, 0.6, F)
        self.metal = np.zeros(n, F)
        self.bump = np.zeros(n, F)
        self.grain = np.zeros(n, F)
        self.spk = np.zeros((n, 4), F)
        self.strp = np.zeros((n, 4), F)
        self.ink = np.zeros((n, 4), F)
        self.ink[:, 0] = 1.0

    def mask(self, *parts):
        return np.isin(self.part, parts)

    def draw(self, m, dist, w, strength=1.0):
        """ink a line (dist = distance to it, w its half width) or a filled shape (dist < 0 inside, w = 0) where m; the nearest drawing wins"""
        dist = np.broadcast_to(np.asarray(dist, F), m.shape)
        w = np.broadcast_to(np.asarray(w, F), m.shape)
        s = np.broadcast_to(np.asarray(strength, F), m.shape)
        take = m & ((dist - w) < (self.ink[:, 0] - self.ink[:, 1]))
        self.ink[take, 0] = dist[take]
        self.ink[take, 1] = w[take]
        self.ink[take, 2] = s[take]


def srgb(*c):
    """an sRGB colour (0..255 or 0..1) as linear floats"""
    c = np.asarray(c, F)
    if c.max() > 1.0:
        c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4).astype(F)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def occlusion(shape, P, N, steps=(0.006, 0.016, 0.034, 0.064, 0.11)):
    """ambient occlusion straight from the distance field: how much of each step out along the normal is already inside something"""
    occ = np.zeros(len(P), F)
    w = 1.0
    tot = 0.0
    for h in steps:
        d = shape.eval(P + N * h)[0]
        occ += w * np.clip((h - d) / h, 0.0, 1.0)
        tot += w
        w *= 0.75
    return np.clip(1.0 - occ / tot, 0.0, 1.0).astype(F)


def edges(shape, P, N, h=0.004):
    """(wear, cavity): 1 on convex edges (rubbed light) / 1 in concave creases (dirt and shadow), from stepping in and out along the normal"""
    din = shape.eval(P - N * h)[0]
    dout = shape.eval(P + N * h)[0]
    wear = np.clip((din + h) / h * 1.5, 0.0, 1.0)
    cav = np.clip((h - dout) / h * 1.5, 0.0, 1.0)
    return wear.astype(F), cav.astype(F)


def _attr(me, name, data):
    a = me.color_attributes.get(name) or me.color_attributes.new(name, "FLOAT_COLOR", "POINT")
    a.data.foreach_set("color", np.ascontiguousarray(data, F).ravel())


def paint(ob, shape, world, fn, mat):
    """paint one mesh: `shape` its own clay (for parts), `world` every piece together (for occlusion), fn(ctx) the recipe's painter"""
    me = ob.data
    n = len(me.vertices)
    P = np.zeros(n * 3, F)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    N = np.zeros(n * 3, F)
    me.vertex_normals.foreach_get("vector", N)
    N = N.reshape(-1, 3)
    part = shape.eval(P)[1]
    ao = occlusion(world, P, N)
    wear, cav = edges(world, P, N)
    c = Ctx(P, N, part, ao, wear, cav)
    fn(c)
    _attr(me, "Col", np.concatenate([c.col, np.ones((n, 1), F)], 1))
    _attr(me, "RM", np.stack([c.rough, c.metal, c.bump, c.grain], 1))
    _attr(me, "Spk", c.spk)
    _attr(me, "Strp", c.strp)
    _attr(me, "Ink", c.ink)
    me.materials.clear()
    me.materials.append(mat)
    me.polygons.foreach_set("material_index", np.zeros(len(me.polygons), np.int32))


# ---------------------------------------------------------------------------------------------------- the shared shader

def _sock(sockets, name, kind=None):
    for s in sockets:
        if s.name == name and (kind is None or s.type == kind) and getattr(s, "enabled", True):
            return s
    raise KeyError(name)


def material(name="M_folk_paint", spk_scale=55.0, spk_size=0.16, stripe_w=0.0012, weave=1100.0, leather=260.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    L = nt.links.new
    out = N("ShaderNodeOutputMaterial")
    bsdf = N("ShaderNodeBsdfPrincipled")
    L(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def attr(nm):
        a = N("ShaderNodeAttribute")
        a.attribute_name = nm
        a.attribute_type = "GEOMETRY"
        return a

    def sep(sock):
        s = N("ShaderNodeSeparateColor")
        L(sock, s.inputs[0])
        return s

    def math(op, a, b=None, clamp=False):
        n = N("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                L(v, n.inputs[i])
        return n.outputs[0]

    def maprange(v, a, b, c, d):
        n = N("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        L(v, n.inputs["Value"])
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        n.inputs["To Min"].default_value = c
        n.inputs["To Max"].default_value = d
        return n.outputs["Result"]

    def mix(fac, a, b):
        n = N("ShaderNodeMix")
        n.data_type = "RGBA"
        L(fac, _sock(n.inputs, "Factor", "VALUE"))
        L(a, _sock(n.inputs, "A", "RGBA"))
        L(b, _sock(n.inputs, "B", "RGBA"))
        return _sock(n.outputs, "Result", "RGBA")

    tc = N("ShaderNodeTexCoord")
    obj = tc.outputs["Object"]
    col, rm, spk, strp = attr("Col"), attr("RM"), attr("Spk"), attr("Strp")
    rms = sep(rm.outputs["Color"])
    base = col.outputs["Color"]
    # speckles / prints: Voronoi dots, a random share of the cells
    vor = N("ShaderNodeTexVoronoi")
    vor.feature = "F1"
    vor.inputs["Scale"].default_value = spk_scale
    L(obj, vor.inputs["Vector"])
    dot = maprange(vor.outputs["Distance"], spk_size * 0.55, spk_size, 1.0, 0.0)
    cellr = sep(vor.outputs["Color"]).outputs["Red"]
    there = math("LESS_THAN", cellr, spk.outputs["Alpha"])
    fac = math("MULTIPLY", dot, there)
    base = mix(fac, base, spk.outputs["Color"])
    # a second, smaller and sparser size of the same, for variety
    vor2 = N("ShaderNodeTexVoronoi")
    vor2.feature = "F1"
    vor2.inputs["Scale"].default_value = spk_scale * 2.3
    vor2.inputs["Randomness"].default_value = 0.9
    L(obj, vor2.inputs["Vector"])
    dot2 = maprange(vor2.outputs["Distance"], spk_size * 0.5, spk_size * 0.9, 1.0, 0.0)
    there2 = math("LESS_THAN", sep(vor2.outputs["Color"]).outputs["Green"], math("MULTIPLY", spk.outputs["Alpha"], 0.7))
    base = mix(math("MULTIPLY", dot2, there2), base, spk.outputs["Color"])
    # pinstripes: a thin dark line every so often across Strp.r
    sts = sep(strp.outputs["Color"])
    u = math("DIVIDE", sts.outputs["Red"], 0.024)
    f = math("ABSOLUTE", math("SUBTRACT", math("FRACT", u), 0.5))
    line = maprange(math("SUBTRACT", 0.5, f), 0.0, stripe_w / 0.024 * 1.8, 1.0, 0.0)
    sfac = math("MULTIPLY", line, sts.outputs["Green"])
    dark = N("ShaderNodeMix")
    dark.data_type = "RGBA"
    dark.blend_type = "MULTIPLY"
    _sock(dark.inputs, "Factor", "VALUE").default_value = 1.0
    L(base, _sock(dark.inputs, "A", "RGBA"))
    _sock(dark.inputs, "B", "RGBA").default_value = (0.72, 0.68, 0.66, 1.0)
    base = mix(sfac, base, _sock(dark.outputs, "Result", "RGBA"))
    # ink: lines and filled shapes from an interpolated distance field, so their edges stay sharp however coarse the mesh
    ink = sep(attr("Ink").outputs["Color"])
    edge = N("ShaderNodeMapRange")
    edge.interpolation_type = "SMOOTHSTEP"
    L(ink.outputs["Red"], edge.inputs["Value"])
    L(ink.outputs["Green"], edge.inputs["From Min"])
    L(math("ADD", ink.outputs["Green"], 0.0007), edge.inputs["From Max"])
    edge.inputs["To Min"].default_value = 1.0
    edge.inputs["To Max"].default_value = 0.0
    ifac = math("MULTIPLY", edge.outputs["Result"], ink.outputs["Blue"])
    inkc = N("ShaderNodeRGB")
    inkc.outputs[0].default_value = (0.008, 0.006, 0.014, 1.0)
    base = mix(ifac, base, inkc.outputs[0])
    L(base, bsdf.inputs["Base Color"])
    L(rms.outputs["Red"], bsdf.inputs["Roughness"])
    L(rms.outputs["Green"], bsdf.inputs["Metallic"])
    # grain: a fine weave for cloth, a coarser pebble for leather, mixed by RM.a, scaled by RM.b
    nz1 = N("ShaderNodeTexNoise")
    nz1.inputs["Scale"].default_value = weave
    nz1.inputs["Detail"].default_value = 1.0
    L(obj, nz1.inputs["Vector"])
    nz2 = N("ShaderNodeTexVoronoi")
    nz2.feature = "F1"
    nz2.inputs["Scale"].default_value = leather
    L(obj, nz2.inputs["Vector"])
    a = rm.outputs["Alpha"]
    h = math("ADD", math("MULTIPLY", nz1.outputs["Fac"], math("SUBTRACT", 1.0, a)), math("MULTIPLY", nz2.outputs["Distance"], a))
    h = math("MULTIPLY", h, rms.outputs["Blue"])
    bump = N("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    bump.inputs["Distance"].default_value = 0.0006
    L(h, bump.inputs["Height"])
    L(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m
