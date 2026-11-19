## Violet Starborn: skeleton (Prog V3 bone names), skin weights, the mouth shape key and the GLB export.
import bpy, bmesh, math, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
vb = sys.modules["violet_body"]; vp = sys.modules["violet_parts"]
S = vb.S
def P(X, Y, D): return Vector((X * S, -(D - 530.0) * S, (1330.0 - Y) * S))

def bones():
    """name -> (head, tail, parent, connected). Her left side (+X); the right is mirrored."""
    a = Vector((math.sin(vb.ARM_ANG), 0.0, -math.cos(vb.ARM_ANG))); e1 = Vector((math.cos(vb.ARM_ANG), 0.0, math.sin(vb.ARM_ANG))); e2 = Vector((0, -1, 0))
    J = vb.ARM_J
    B = {}
    B["root"] = (Vector((0, 0, 0)), Vector((0, 0.12, 0)), None, False)
    B["hips"] = (P(0, 640, 540), P(0, 575, 548), "root", False)
    B["spine_1"] = (P(0, 575, 548), P(0, 505, 560), "hips", True)
    B["spine_2"] = (P(0, 505, 560), P(0, 430, 560), "spine_1", True)
    B["chest"] = (P(0, 430, 560), P(0, 298, 520), "spine_2", True)
    B["neck"] = (P(0, 298, 520), P(0, 236, 517), "chest", True)
    B["head"] = (P(0, 236, 517), P(0, 70, 525), "neck", True)
    L = {}
    L["clavicle"] = (P(14, 306, 522), J.copy(), "chest", False)
    L["upper_arm"] = (J.copy(), J + a * 160 * S, "clavicle", True)
    L["forearm"] = (J + a * 160 * S, J + a * 312 * S, "upper_arm", True)
    L["hand"] = (J + a * 312 * S, J + a * 368 * S, "forearm", True)
    for i, nm in enumerate(("index", "middle", "ring", "pinky")):
        sp = math.radians((1.5 - i) * 5.0); d = (a * math.cos(sp) + e2 * math.sin(sp)).normalized()
        base = J + a * 375 * S + e2 * (28.0 * (0.75 - 0.5 * i)) * S; Ln = vb.FINGER_LEN[i]
        pts = [base, base + d * 0.40 * Ln * S, base + d * 0.70 * Ln * S - e1 * 1.5 * S, base + d * Ln * S - e1 * 4.0 * S]
        for k in range(3):
            L[f"{nm}_{k + 1}"] = (pts[k], pts[k + 1], "hand" if k == 0 else f"{nm}_{k}", k > 0)
    d = (e2 * 0.80 + a * 0.58 - e1 * 0.12).normalized()
    c0 = J + a * 333 * S + e2 * 20 * S
    pts = [J + a * 322 * S + e2 * 9 * S, c0 + d * 9 * S, c0 + d * 26 * S, c0 + d * 46 * S]
    for k in range(3):
        L[f"thumb_{k + 1}"] = (pts[k], pts[k + 1], "hand" if k == 0 else f"thumb_{k}", k > 0)
    L["thigh"] = (P(73, 662, 545), P(79, 886, 541), "hips", False)
    L["shin"] = (P(79, 886, 541), P(99.5, 1142, 524), "thigh", True)
    L["foot"] = (P(99.5, 1142, 524), P(106, 1285, 610), "shin", True)
    for nm, (h, t, par, con) in L.items():
        for sfx, sg in ((".L", 1), (".R", -1)):
            m = lambda v: Vector((sg * v.x, v.y, v.z))
            B[nm + sfx] = (m(h), m(t), par if par in ("chest", "hips") else par + sfx, con)
    return B

def make_armature():
    old = bpy.data.objects.get("ARM_Violet")
    if old:
        d = old.data; bpy.data.objects.remove(old); bpy.data.armatures.remove(d)
    arm = bpy.data.armatures.new("ARM_Violet"); ob = bpy.data.objects.new("ARM_Violet", arm)
    vp.col().objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects: o.select_set(False)
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    B = bones(); eb = {}
    for nm, (h, t, par, con) in B.items():
        b = arm.edit_bones.new(nm); b.head = h; b.tail = t; eb[nm] = b
    for nm, (h, t, par, con) in B.items():
        if par: eb[nm].parent = eb[par]; eb[nm].use_connect = con
    for nm in eb:
        if nm.split(".")[0] in ("upper_arm", "forearm", "hand", "clavicle") or "_" in nm and nm[0] in "imrpt":
            eb[nm].roll = 0.0
    bpy.ops.armature.calculate_roll(type='GLOBAL_NEG_Y')
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.bones["root"].use_deform = False
    return ob

def auto_weight(arm, meshes):
    for o in bpy.context.selected_objects: o.select_set(False)
    for m in meshes:
        m.vertex_groups.clear(); m.select_set(True)
    arm.select_set(True); bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    return {m.name: sum(1 for v in m.data.vertices if not v.groups) for m in meshes}

def weights_of(ob):
    names = [g.name for g in ob.vertex_groups]
    return [{names[g.group]: g.weight for g in v.groups if g.weight > 1e-4} for v in ob.data.vertices]

def set_weights(ob, W):
    ob.vertex_groups.clear(); groups = {}
    for i, w in enumerate(W):
        top = sorted(w.items(), key=lambda kv: -kv[1])[:4]; tot = sum(x for _, x in top) or 1.0
        for nm, x in top:
            g = groups.get(nm)
            if g is None: g = groups[nm] = ob.vertex_groups.new(name=nm)
            g.add([i], x / tot, 'REPLACE')

def skin_to(arm, ob):
    ob.parent = arm; ob.matrix_parent_inverse.identity()
    for m in list(ob.modifiers):
        if m.type == 'ARMATURE': ob.modifiers.remove(m)
    md = ob.modifiers.new("Armature", 'ARMATURE'); md.object = arm

def transfer(arm, srcs, dst):
    """Copy skin weights onto dst from the nearest surface point of the source meshes."""
    bm = bmesh.new(); W = []
    for s in srcs:
        bm.from_mesh(s.data); W += weights_of(s)
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    tree = BVHTree.FromBMesh(bm)
    out = []
    for v in dst.data.vertices:
        loc, nrm, fi, dist = tree.find_nearest(v.co)
        f = bm.faces[fi]; acc = {}; tot = 0.0
        for fv in f.verts:
            k = 1.0 / max(1e-6, (fv.co - loc).length) ** 2; tot += k
            for nm, x in W[fv.index].items(): acc[nm] = acc.get(nm, 0.0) + x * k
        out.append({nm: x / tot for nm, x in acc.items()})
    bm.free()
    set_weights(dst, out); skin_to(arm, dst)

def fix_head(head, eyes, arm):
    W = []
    for v in head.data.vertices:
        X = v.co.x / S; Y = 1330.0 - v.co.z / S; D = 530.0 - v.co.y / S
        rad = math.hypot(X, D - 516.0)
        n = vp.smooth01((Y - 230.0) / 30.0) * vp.smooth01((40.0 - rad) / 10.0)
        W.append({"neck": n, "head": 1.0 - n} if n > 1e-3 else {"head": 1.0})
    set_weights(head, W); skin_to(arm, head)
    for e in eyes:
        set_weights(e, [{"head": 1.0} for _ in e.data.vertices]); skin_to(arm, e)

def rigid_feet(boots, soles, arm):
    """Platform boots do not bend: everything from the ankle down follows the foot."""
    W = weights_of(boots)
    for i, v in enumerate(boots.data.vertices):
        Y = 1330.0 - v.co.z / S; side = ".L" if v.co.x > 0 else ".R"
        k = vp.smooth01((Y - 1120.0) / 50.0)
        w = {nm: x * (1.0 - k) for nm, x in W[i].items()}; w["foot" + side] = w.get("foot" + side, 0.0) + k
        W[i] = w
    set_weights(boots, W)
    set_weights(soles, [{"foot" + (".L" if v.co.x > 0 else ".R"): 1.0} for v in soles.data.vertices]); skin_to(arm, soles)

def mouth_key(head, info):
    if head.data.shape_keys:
        head.shape_key_clear()
    head.shape_key_add(name="Basis")
    sk = head.shape_key_add(name="mouth_open")
    rowY = info["rowY"]; lower = set(info["lower"])
    for i, v in enumerate(head.data.vertices):
        X = v.co.x / S; Y = 1330.0 - v.co.z / S; D = 530.0 - v.co.y / S
        if D < 560.0: continue
        below = i in lower or Y > rowY + 0.6
        if not below: continue
        k = math.exp(-(X / 15.0) ** 2) * (1.0 - 0.75 * vp.smooth01((Y - rowY - 3.0) / 22.0))
        sk.data[i].co = v.co + Vector((0.0, 1.5 * S * k, -8.0 * S * k))
    sk.value = 0.0

def rig_all(parts):
    C = bpy.data.objects
    arm = make_armature()
    body, head, gloves = parts["body"], parts["head"], parts["gloves"]
    boots = C["SM_Char_Violet_Cloth_Boots"]; soles = C["SM_Char_Violet_Cloth_Soles"]
    missed = auto_weight(arm, [body, gloves, boots])
    fix_head(head, parts["eyes"], arm)
    rigid_feet(boots, soles, arm)
    for o in (body, gloves, boots):
        set_weights(o, weights_of(o))                 # 4 influences, normalised
    for nm in ("SM_Char_Violet_Cloth_Top", "SM_Char_Violet_Cloth_Shorts", "SM_Char_Violet_Cloth_Bands", "SM_Char_Violet_Acc_MetalBands", "SM_Char_Violet_Acc_Studs"):
        transfer(arm, [body, head], C[nm])
    transfer(arm, [gloves], C["SM_Char_Violet_Acc_Cuffs"])
    transfer(arm, [boots], C["SM_Char_Violet_Acc_BootStraps"])
    mouth_key(head, parts["mouth"])
    return arm, missed

EXPORT_GROUPS = {   # the pieces stay separate in the .blend; the game gets four meshes, seven surfaces
    "Violet_Head": ["Head", "Eye_L", "Eye_R"],
    "Violet_Body": ["Body"],
    "Violet_Latex": ["Cloth_Top", "Cloth_Shorts", "Cloth_Bands", "Cloth_Gloves", "Cloth_Boots", "Cloth_Soles"],
    "Violet_Metal": ["Acc_MetalBands", "Acc_Cuffs", "Acc_Studs", "Acc_BootStraps"],
}
def export(path):
    arm = bpy.data.objects["ARM_Violet"]
    tmp = bpy.data.collections.new("COL_VioletExport"); bpy.context.scene.collection.children.link(tmp)
    made = []
    for name, srcs in EXPORT_GROUPS.items():
        for o in bpy.context.selected_objects: o.select_set(False)
        dups = []
        for s in srcs:
            src = bpy.data.objects["SM_Char_Violet_" + s]
            d = src.copy(); d.data = src.data.copy(); tmp.objects.link(d); d.select_set(True); dups.append(d)
        bpy.context.view_layer.objects.active = dups[0]
        if len(dups) > 1: bpy.ops.object.join()
        dups[0].name = name; dups[0].data.name = name; made.append(dups[0])
    for o in bpy.context.selected_objects: o.select_set(False)
    for o in made: o.select_set(True)
    was = arm.hide_viewport; arm.hide_viewport = False
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    try:
        _export(path)
    finally:
        arm.hide_viewport = was
        for o in made:
            me = o.data; bpy.data.objects.remove(o); bpy.data.meshes.remove(me)
        bpy.data.collections.remove(tmp)

def _export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_yup=True, export_apply=False,
                              export_skins=True, export_morph=True, export_morph_normal=True, export_animations=False,
                              export_materials='EXPORT', export_image_format='AUTO', export_tangents=False)
