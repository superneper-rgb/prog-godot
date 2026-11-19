## The folk kit's eyes: materials, preview renders (front, three-quarter, side, back) and a sheet that puts them next to the concept art.
import bpy
import math
import numpy as np


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    return sc


def mat(name, color, rough=0.6, metal=0.0, emit=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = tuple(color) + (1.0,)
    b.inputs["Base Color"].default_value = c
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit is not None:
        b.inputs["Emission Color"].default_value = tuple(emit) + (1.0,)
        b.inputs["Emission Strength"].default_value = 1.0
    m.diffuse_color = c
    m.roughness = rough
    m.metallic = metal
    return m


def _camera(name, loc, target, ortho=None, lens=70.0):
    cd = bpy.data.cameras.new(name)
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    cd.clip_end = 100.0
    ob = bpy.data.objects.new(name, cd)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    d = np.array(target) - np.array(loc)
    ob.rotation_euler = (math.atan2(math.hypot(d[0], d[1]), -d[2]), 0.0, math.atan2(d[1], d[0]) - math.pi / 2)
    return ob


def _engine(sc, colour):
    sc.render.engine = "BLENDER_EEVEE" if colour else "BLENDER_WORKBENCH"
    if colour and bpy.data.worlds.get("look_world") is None:
        w = bpy.data.worlds.new("look_world")
        w.use_nodes = True
        bg = w.node_tree.nodes["Background"]
        bg.inputs["Color"].default_value = (0.05, 0.05, 0.06, 1.0)
        bg.inputs["Strength"].default_value = 1.0
        sc.world = w
        for nm, rot, e, col in (("key", (50, 0, 35), 3.2, (1.0, 0.96, 0.9)), ("fill", (60, 0, -120), 1.0, (0.75, 0.8, 1.0)), ("rim", (110, 0, 170), 2.5, (1.0, 1.0, 1.0))):
            ld = bpy.data.lights.new(nm, "SUN")
            ld.energy = e
            ld.color = col
            lo = bpy.data.objects.new(nm, ld)
            lo.rotation_euler = tuple(math.radians(a) for a in rot)
            sc.collection.objects.link(lo)
    else:
        sh = sc.display.shading
        sh.light = "STUDIO"
        sh.color_type = "MATERIAL"
        sh.show_cavity = True
        sh.cavity_type = "BOTH"
        sh.show_shadows = True
        sh.shadow_intensity = 0.4
        sh.background_type = "VIEWPORT"
        sh.background_color = (0.05, 0.05, 0.06)
        sc.display.render_aa = "16"


def render_views(out_prefix, height=2.0, px=900, colour=False, views=("front", "q3", "side", "back"), centre_z=None):
    """render the scene from the standard views into out_prefix_<view>.png; returns the paths"""
    sc = bpy.context.scene
    _engine(sc, colour)
    sc.render.resolution_x = int(px * 0.62)
    sc.render.resolution_y = px
    sc.render.film_transparent = False
    zc = height * 0.5 if centre_z is None else centre_z
    span = height * 1.08
    cams = {
        "front": ((0.0, -8.0, zc), (0.0, 0.0, zc), span),
        "side": ((8.0, 0.0, zc), (0.0, 0.0, zc), span),
        "back": ((0.0, 8.0, zc), (0.0, 0.0, zc), span),
        "q3": ((-8.0 * math.sin(math.radians(32)), -8.0 * math.cos(math.radians(32)), zc + 0.9), (0.0, 0.0, zc), span),
        "face": ((-1.6 * math.sin(math.radians(25)), -1.6 * math.cos(math.radians(25)), height * 0.9), (0.0, 0.0, height * 0.88), None),
        "bust": ((-2.6 * math.sin(math.radians(30)), -2.6 * math.cos(math.radians(30)), height * 0.8), (0.05, 0.0, height * 0.72), None),
        "bust_l": ((2.6 * math.sin(math.radians(40)), -2.6 * math.cos(math.radians(40)), height * 0.78), (0.1, 0.0, height * 0.72), None),
    }
    out = []
    for v in views:
        if v.startswith("face@"):      # the head from any side: face@0 front, face@-45 her right three-quarter, face@90 her left profile
            a = math.radians(float(v[5:]))
            hz = height * 0.9
            cams[v] = ((1.5 * math.sin(a), -1.5 * math.cos(a), hz + 0.05), (0.0, 0.0, hz - 0.02), None)
        loc, tgt, sp = cams[v]
        cam = _camera("cam_" + v, loc, tgt, ortho=sp, lens=85.0)
        sc.camera = cam
        p = "%s_%s.png" % (out_prefix, v)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        out.append(p)
    return out


def _load_rgba(path):
    im = bpy.data.images.load(path, check_existing=False)
    W, H = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)
    bpy.data.images.remove(im)
    return a


def _resize(a, h):
    H, W = a.shape[:2]
    w = max(1, int(round(W * h / H)))
    yi = np.clip((np.arange(h) * H / h).astype(int), 0, H - 1)
    xi = np.clip((np.arange(w) * W / w).astype(int), 0, W - 1)
    return a[yi][:, xi]


def sheet(paths, out, ref=None, ref_box=None, h=900):
    """lay the renders side by side (the concept crop first, if given) into one PNG"""
    tiles = []
    if ref:
        r = _load_rgba(ref)
        if ref_box:
            x0, y0, x1, y1 = ref_box
            H = r.shape[0]
            r = r[H - y1: H - y0, x0:x1]
        tiles.append(_resize(r, h))
    for p in paths:
        tiles.append(_resize(_load_rgba(p), h))
    W = sum(t.shape[1] for t in tiles) + 8 * (len(tiles) - 1)
    img = np.zeros((h, W, 4), np.float32)
    img[..., 3] = 1.0
    x = 0
    for t in tiles:
        img[:, x: x + t.shape[1]] = t
        x += t.shape[1] + 8
    o = bpy.data.images.new("sheet", W, h, alpha=True)
    o.pixels[:] = img.ravel()
    o.filepath_raw = out
    o.file_format = "PNG"
    o.save()
    return out
