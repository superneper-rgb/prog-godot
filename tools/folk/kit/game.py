## The folk kit's game model: the painted clay decimated to a light mesh, unwrapped (faces get more texture than trousers), and the paint, normals and roughness/metal baked onto it in Cycles.
import bpy
import bmesh
import math
import os
import numpy as np


def _tris(me):
    n = np.zeros(len(me.polygons), np.int32)
    me.polygons.foreach_get("loop_total", n)
    return int((n - 2).sum())


def make_low(highs, budget, name):
    """highs: [(piece name, high object)], budget: {piece name: triangles}. One joined, decimated object; a face attribute 'piece' says which piece each face came from."""
    dg = bpy.context.evaluated_depsgraph_get()
    parts = []
    for i, (pn, ob) in enumerate(highs):
        cp = ob.copy()
        cp.data = ob.data.copy()
        bpy.context.scene.collection.objects.link(cp)
        mod = cp.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = min(1.0, budget[pn] / max(1, _tris(cp.data)))
        mod.use_symmetry = True
        mod.symmetry_axis = "X"
        dg.update()
        me = bpy.data.meshes.new_from_object(cp.evaluated_get(dg))
        bpy.data.objects.remove(cp)
        for a in list(me.color_attributes):
            me.color_attributes.remove(a)
        at = me.attributes.new("piece", "INT", "FACE")
        at.data.foreach_set("value", np.full(len(me.polygons), i, np.int32))
        parts.append(me)
    bm = bmesh.new()
    for me in parts:
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), bool))
    me.materials.clear()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def unwrap(low, piece_names, density):
    """smart-project, then grow the islands of the pieces that deserve more texture (density: {piece: linear scale}) and pack"""
    bpy.context.view_layer.objects.active = low
    for o in bpy.context.view_layer.objects:
        o.select_set(o == low)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(56), island_margin=0.003, area_weight=0.0, scale_to_bounds=False)
    bm = bmesh.from_edit_mesh(low.data)
    uv = bm.loops.layers.uv.active
    pl = bm.faces.layers.int.get("piece")
    for f in bm.faces:
        s = density.get(piece_names[f[pl]], 1.0)
        if s != 1.0:
            for lp in f.loops:
                lp[uv].uv *= s          # scaled about the origin: pack below re-places every island anyway
    bmesh.update_edit_mesh(low.data)
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")


def _gpu(sc):
    sc.render.engine = "CYCLES"
    try:
        p = bpy.context.preferences.addons["cycles"].preferences
        p.compute_device_type = "CUDA"
        p.get_devices()
        for d in p.devices:
            d.use = d.type == "CUDA"
        sc.cycles.device = "GPU"
    except Exception:
        sc.cycles.device = "CPU"
    sc.cycles.samples = 6
    sc.cycles.use_denoising = False


def _rewire(mat, mode):
    """the high material for one bake pass: 'albedo' or 'rm' routes those values into an emission; 'normal' restores the shader"""
    nt = mat.node_tree
    out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    em = nt.nodes.get("bake_emit") or nt.nodes.new("ShaderNodeEmission")
    em.name = "bake_emit"
    if mode == "normal":
        nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
        return
    if mode == "albedo":
        src = bsdf.inputs["Base Color"].links[0].from_socket
    else:
        comb = nt.nodes.get("bake_rm") or nt.nodes.new("ShaderNodeCombineColor")
        comb.name = "bake_rm"
        comb.inputs["Red"].default_value = 1.0
        nt.links.new(bsdf.inputs["Roughness"].links[0].from_socket, comb.inputs["Green"])
        nt.links.new(bsdf.inputs["Metallic"].links[0].from_socket, comb.inputs["Blue"])
        src = comb.outputs["Color"]
    nt.links.new(src, em.inputs["Color"])
    em.inputs["Strength"].default_value = 1.0
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])


LOCK = "F:/prog-godot-cache/folk/bake.lock"
SHIP = 1024        # the maps' size in the game


def _lock():
    """one bake on the GPU at a time across every build running on the machine (several builders work in parallel); a lock older than 15 minutes is stale"""
    import time
    while True:
        try:
            fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            os.write(fd, str(os.getpid()).encode())
            os.close(fd)
            return
        except FileExistsError:
            try:
                if time.time() - os.path.getmtime(LOCK) > 900:
                    os.remove(LOCK)
                    continue
            except OSError:
                pass
            time.sleep(2.0)


def _unlock():
    try:
        os.remove(LOCK)
    except OSError:
        pass


def bake(low, highs, high_mat, out_dir, prefix, size=2048):
    """bake the painted highs onto the low's UVs; returns {'albedo', 'normal', 'orm'} image paths. Takes the machine-wide bake lock; falls back to the CPU if the GPU fails."""
    _lock()
    try:
        return _bake(low, highs, high_mat, out_dir, prefix, size)
    except RuntimeError:
        bpy.context.scene.cycles.device = "CPU"
        return _bake(low, highs, high_mat, out_dir, prefix, size, gpu=False)
    finally:
        _unlock()


def _bake(low, highs, high_mat, out_dir, prefix, size, gpu=True):
    sc = bpy.context.scene
    if gpu:
        _gpu(sc)
    os.makedirs(out_dir, exist_ok=True)
    m = bpy.data.materials.new(prefix + "_bake")
    m.use_nodes = True
    low.data.materials.clear()
    low.data.materials.append(m)
    tex = m.node_tree.nodes.new("ShaderNodeTexImage")
    m.node_tree.nodes.active = tex
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    for h in highs:
        h.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    paths = {}
    bk = sc.render.bake
    bk.use_selected_to_active = True
    bk.cage_extrusion = 0.008
    bk.max_ray_distance = 0.03
    bk.margin = 8
    for kind, btype, cs in (("albedo", "EMIT", "sRGB"), ("orm", "EMIT", "Non-Color"), ("normal", "NORMAL", "Non-Color")):
        img = bpy.data.images.new("%s_%s" % (prefix, kind), size, size, alpha=False)
        img.colorspace_settings.name = cs
        tex.image = img
        _rewire(high_mat, {"albedo": "albedo", "orm": "rm", "normal": "normal"}[kind])
        if btype == "NORMAL":
            bk.normal_space = "TANGENT"
            bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=0.008, max_ray_distance=0.03, margin=8)
        else:
            bpy.ops.object.bake(type="EMIT", use_selected_to_active=True, cage_extrusion=0.008, max_ray_distance=0.03, margin=8)
        if size > SHIP:          # baked large (antialiased), shipped at SHIP: a crowd NPC needs no more, and 46 species share a 6 GB card
            img.scale(SHIP, SHIP)
        p = os.path.join(out_dir, "%s_%s.png" % (prefix, kind))
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
        paths[kind] = (p, img)
    _rewire(high_mat, "normal")
    bpy.data.materials.remove(m)
    return paths


def game_material(low, baked, name):
    """the low model's own material: the baked maps on a Principled BSDF, wired the way the glTF exporter reads them"""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes.get("Principled BSDF")
    L = nt.links.new

    def tex(kind):
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = baked[kind][1]
        return t
    L(tex("albedo").outputs["Color"], b.inputs["Base Color"])
    orm = nt.nodes.new("ShaderNodeSeparateColor")
    L(tex("orm").outputs["Color"], orm.inputs[0])
    L(orm.outputs["Green"], b.inputs["Roughness"])
    L(orm.outputs["Blue"], b.inputs["Metallic"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    L(tex("normal").outputs["Color"], nm.inputs["Color"])
    L(nm.outputs["Normal"], b.inputs["Normal"])
    low.data.materials.clear()
    low.data.materials.append(m)
    return m
