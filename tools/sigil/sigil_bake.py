# The Sigil's body atlas (tools/sigil/build_sigil.py --bake): each kind of surface gets a Cycles material (scuffed SERN enamel worn to steel at its edges, grime in its creases from AO,
# oxidised copper going green in the cavities, dusty black rubber, yellowed CRT plastic), and those are baked into one albedo, one ORM (AO, roughness, metal) and one tangent normal map
# (rounded edges from the Bevel node, pitting from noise) at TEX x TEX. Only the body's faces are baked; the glass keeps its own materials.
import bpy, bmesh, os
import numpy as np

KIND = {   # base colour, wear colour, roughness, metal, worn roughness, worn metal
    "enamel": ((0.60, 0.60, 0.56), (0.11, 0.11, 0.115), 0.42, 0.0, 0.32, 1.0),
    "enamel_dark": ((0.15, 0.16, 0.17), (0.2, 0.2, 0.21), 0.5, 0.0, 0.35, 1.0),
    "steel": ((0.09, 0.09, 0.1), (0.32, 0.32, 0.34), 0.4, 0.9, 0.25, 1.0),
    "edge": ((0.55, 0.56, 0.58), (0.7, 0.7, 0.72), 0.2, 1.0, 0.12, 1.0),
    "rubber": ((0.02, 0.02, 0.022), (0.06, 0.058, 0.055), 0.75, 0.0, 0.9, 0.0),
    "copper": ((0.6, 0.3, 0.15), (0.16, 0.4, 0.32), 0.33, 1.0, 0.8, 0.0),
    "housing": ((0.04, 0.04, 0.045), (0.22, 0.22, 0.23), 0.5, 0.3, 0.3, 1.0),
    "crt_plastic": ((0.5, 0.45, 0.33), (0.3, 0.26, 0.18), 0.55, 0.0, 0.7, 0.0),
    "paint_black": ((0.02, 0.02, 0.02), (0.55, 0.55, 0.52), 0.6, 0.0, 0.42, 0.0),
    "paint_red": ((0.42, 0.03, 0.02), (0.55, 0.55, 0.52), 0.5, 0.0, 0.42, 0.0),
}


def _mat(kind, ao_img=None):
    base, wear, rough, metal, wrough, wmetal = KIND[kind]
    m = bpy.data.materials["k_" + kind]
    nt = m.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    L = nt.links.new
    out = N("ShaderNodeOutputMaterial")
    bs = N("ShaderNodeBsdfPrincipled")
    tc = N("ShaderNodeTexCoord")
    geo = N("ShaderNodeNewGeometry")
    # edges: where the bevelled normal leaves the true one
    bev = N("ShaderNodeBevel")
    bev.samples = 4
    bev.inputs["Radius"].default_value = 0.035
    dot = N("ShaderNodeVectorMath")
    dot.operation = 'DOT_PRODUCT'
    L(bev.outputs["Normal"], dot.inputs[0])
    L(geo.outputs["Normal"], dot.inputs[1])
    edge = N("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.996
    edge.inputs["From Max"].default_value = 0.955
    L(dot.outputs["Value"], edge.inputs["Value"])
    # breakup noise in object space (metres)
    n1 = N("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = 2.2
    n1.inputs["Detail"].default_value = 8.0
    n1.inputs["Roughness"].default_value = 0.65
    L(tc.outputs["Object"], n1.inputs["Vector"])
    wear_m = N("ShaderNodeMath")
    wear_m.operation = 'MULTIPLY'
    L(edge.outputs["Result"], wear_m.inputs[0])
    nm = N("ShaderNodeMapRange")
    nm.inputs["From Min"].default_value = 0.35
    nm.inputs["From Max"].default_value = 0.65
    nm.inputs["To Min"].default_value = 0.0
    nm.inputs["To Max"].default_value = 1.6
    L(n1.outputs["Fac"], nm.inputs["Value"])
    L(nm.outputs["Result"], wear_m.inputs[1])
    # scuffs: thin stretched noise lines over flat areas
    sc = N("ShaderNodeTexNoise")
    sc.inputs["Scale"].default_value = 4.0
    sc.inputs["Detail"].default_value = 2.0
    mp = N("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1.0, 16.0, 1.0)
    L(tc.outputs["Object"], mp.inputs["Vector"])
    L(mp.outputs["Vector"], sc.inputs["Vector"])
    scr = N("ShaderNodeMapRange")
    scr.inputs["From Min"].default_value = 0.71      # (0.6 made dalmatian spots all over the enamel)
    scr.inputs["From Max"].default_value = 0.73
    scr.inputs["To Max"].default_value = 0.4
    L(sc.outputs["Fac"], scr.inputs["Value"])
    wear_all = N("ShaderNodeMath")
    wear_all.operation = 'MAXIMUM'
    wear_all.use_clamp = True
    L(wear_m.outputs["Value"], wear_all.inputs[0])
    L(scr.outputs["Result"], wear_all.inputs[1])
    # grime: from the AO baked first (a live AO node in every pass made the 4K bake crawl), with a low-frequency stain
    grime = N("ShaderNodeMapRange")
    grime.inputs["From Min"].default_value = 1.0
    grime.inputs["From Max"].default_value = 0.35
    if ao_img is not None:
        aon = N("ShaderNodeTexImage")
        aon.image = ao_img
        L(aon.outputs["Color"], grime.inputs["Value"])
    else:
        grime.inputs["Value"].default_value = 1.0
    n2 = N("ShaderNodeTexNoise")
    n2.inputs["Scale"].default_value = 0.35
    n2.inputs["Detail"].default_value = 4.0
    L(tc.outputs["Object"], n2.inputs["Vector"])
    stain = N("ShaderNodeMapRange")
    stain.inputs["From Min"].default_value = 0.45
    stain.inputs["From Max"].default_value = 0.7
    stain.inputs["To Max"].default_value = 0.35
    L(n2.outputs["Fac"], stain.inputs["Value"])
    gsum = N("ShaderNodeMath")
    gsum.operation = 'ADD'
    gsum.use_clamp = True
    L(grime.outputs["Result"], gsum.inputs[0])
    L(stain.outputs["Result"], gsum.inputs[1])
    # colour
    c_base = N("ShaderNodeRGB")
    c_base.outputs[0].default_value = (*base, 1)
    c_wear = N("ShaderNodeRGB")
    c_wear.outputs[0].default_value = (*wear, 1)
    mix_w = N("ShaderNodeMix")
    mix_w.data_type = 'RGBA'
    L(wear_all.outputs["Value"], mix_w.inputs["Factor"])
    L(c_base.outputs[0], mix_w.inputs[6])
    L(c_wear.outputs[0], mix_w.inputs[7])
    if kind == "copper":      # verdigris lives in the creases, not on the worn edges
        L(gsum.outputs["Value"], mix_w.inputs["Factor"])
    if kind == "rubber":      # dust settles on what faces up
        up = N("ShaderNodeSeparateXYZ")
        L(geo.outputs["Normal"], up.inputs[0])
        dust = N("ShaderNodeMapRange")
        dust.inputs["From Min"].default_value = 0.3
        dust.inputs["From Max"].default_value = 0.9
        dust.inputs["To Max"].default_value = 0.8
        L(up.outputs["Z"], dust.inputs["Value"])
        L(dust.outputs["Result"], mix_w.inputs["Factor"])
    c_grime = N("ShaderNodeRGB")
    c_grime.outputs[0].default_value = (0.09, 0.075, 0.05, 1)
    mix_g = N("ShaderNodeMix")
    mix_g.data_type = 'RGBA'
    mix_g.blend_type = 'MULTIPLY'
    gk = N("ShaderNodeMath")
    gk.operation = 'MULTIPLY'
    gk.inputs[1].default_value = 0.85 if kind in ("enamel", "crt_plastic", "edge") else 0.5
    L(gsum.outputs["Value"], gk.inputs[0])
    L(gk.outputs["Value"], mix_g.inputs["Factor"])
    L(mix_w.outputs[2], mix_g.inputs[6])
    gcol = N("ShaderNodeMix")
    gcol.data_type = 'RGBA'
    gcol.inputs["Factor"].default_value = 1.0
    gcol.inputs[6].default_value = (1, 1, 1, 1)
    gcol.inputs[7].default_value = (0.35, 0.3, 0.24, 1)
    L(gcol.outputs[2], mix_g.inputs[7])
    L(mix_g.outputs[2], bs.inputs["Base Color"])
    # roughness and metal
    def val_mix(a, b, fac_out):
        m_ = N("ShaderNodeMix")
        m_.data_type = 'FLOAT'
        m_.inputs[2].default_value = a
        m_.inputs[3].default_value = b
        L(fac_out, m_.inputs["Factor"])
        return m_.outputs[0]
    wf = gsum.outputs["Value"] if kind == "copper" else wear_all.outputs["Value"]
    r = val_mix(rough, wrough, wf)
    rr = N("ShaderNodeMath")
    rr.operation = 'MULTIPLY_ADD'
    L(r, rr.inputs[0])
    rr.inputs[1].default_value = 1.0
    L(gsum.outputs["Value"], rr.inputs[2])      # grime is rough
    rc = N("ShaderNodeMath")
    rc.operation = 'MINIMUM'
    rc.inputs[1].default_value = 0.95
    rq = N("ShaderNodeMath")
    rq.operation = 'MULTIPLY'
    rq.inputs[1].default_value = 0.35
    L(gsum.outputs["Value"], rq.inputs[0])
    ra = N("ShaderNodeMath")
    ra.operation = 'ADD'
    L(r, ra.inputs[0])
    L(rq.outputs["Value"], ra.inputs[1])
    L(ra.outputs["Value"], rc.inputs[0])
    L(rc.outputs["Value"], bs.inputs["Roughness"])
    met = val_mix(metal, wmetal, wf)
    L(met, bs.inputs["Metallic"])
    # normal: bevelled edges plus fine pitting
    pit = N("ShaderNodeTexNoise")
    pit.inputs["Scale"].default_value = 60.0
    pit.inputs["Detail"].default_value = 4.0
    L(tc.outputs["Object"], pit.inputs["Vector"])
    bump = N("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.08 if kind not in ("rubber", "crt_plastic") else 0.04
    bump.inputs["Distance"].default_value = 0.01
    L(pit.outputs["Fac"], bump.inputs["Height"])
    L(bev.outputs["Normal"], bump.inputs["Normal"])
    L(bump.outputs["Normal"], bs.inputs["Normal"])
    L(bs.outputs[0], out.inputs["Surface"])
    # what the metal pass bakes through: an emission of the metal value
    em = N("ShaderNodeEmission")
    em.name = "metal_emit"
    L(met, em.inputs["Color"])
    img = N("ShaderNodeTexImage")
    img.name = "bake_target"
    nt.nodes.active = img
    return m


def bake(ob, folder, size):
    os.makedirs(folder, exist_ok=True)
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 12
    sc.render.bake.use_selected_to_active = False
    # a copy with only the body's faces (the glass has no bake target)
    dup = ob.copy()
    dup.data = ob.data.copy()
    sc.collection.objects.link(dup)
    bm = bmesh.new()
    bm.from_mesh(dup.data)
    import build_sigil as B
    nb = len(B.BAKED)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index >= nb], context='FACES')
    bm.to_mesh(dup.data)
    bm.free()
    for k in B.BAKED:
        _mat(k)
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active = dup
    dup.select_set(True)
    ob.hide_render = True
    imgs = {}

    def target(name, colour):
        im = bpy.data.images.new("bake_" + name, size, size, alpha=False, float_buffer=False)
        im.colorspace_settings.name = "sRGB" if colour else "Non-Color"
        for k in B.BAKED:
            bpy.data.materials["k_" + k].node_tree.nodes["bake_target"].image = im
        imgs[name] = im
        return im

    def run(name, kind, colour, samples, **kw):
        target(name, colour)
        sc.cycles.samples = samples
        bpy.ops.object.bake(type=kind, **kw)
        print("baked", name)

    run("ao", "AO", False, 32)
    ao_img = imgs["ao"]
    for k in B.BAKED:      # now the materials again, their grime read from that AO
        _mat(k, ao_img)
    run("normal", "NORMAL", False, 6, normal_space='TANGENT')
    run("albedo", "DIFFUSE", True, 4, pass_filter={'COLOR'})
    run("rough", "ROUGHNESS", False, 4)
    for k in B.BAKED:      # the metal value through an emission
        nt = bpy.data.materials["k_" + k].node_tree
        out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
        nt.links.new(nt.nodes["metal_emit"].outputs[0], out.inputs["Surface"])
    run("metal", "EMIT", False, 4)
    px = lambda im: np.array(im.pixels[:], dtype=np.float32).reshape(size, size, 4)
    orm = np.ones((size, size, 4), dtype=np.float32)
    orm[..., 0] = np.clip(px(imgs["ao"])[..., 0] * 0.8 + 0.2, 0, 1)      # (a softened AO: the engine has its own)
    orm[..., 1] = px(imgs["rough"])[..., 0]
    orm[..., 2] = px(imgs["metal"])[..., 0]

    def save(arr_or_img, name, colour):
        if isinstance(arr_or_img, np.ndarray):
            im = bpy.data.images.new("o_" + name, size, size, alpha=False)
            im.colorspace_settings.name = "Non-Color"
            im.pixels = arr_or_img.ravel()
        else:
            im = arr_or_img
        im.filepath_raw = os.path.join(folder, "sigil_%s.png" % name)
        im.file_format = 'PNG'
        im.save()
    save(imgs["albedo"], "albedo", True)
    save(imgs["normal"], "normal", False)
    save(orm, "orm", False)
    bpy.data.objects.remove(dup)
    ob.hide_render = False
