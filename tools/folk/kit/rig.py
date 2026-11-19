## The folk kit's rig: an armature from a recipe's joints, skin weights from distance to each bone (kept to the bones a region may use, then smoothed over the mesh), at most four bones a vertex.
import bpy
import numpy as np
from mathutils import Vector


class Bone:
    def __init__(self, name, head, tail, parent=None, radius=0.05):
        self.name, self.head, self.tail, self.parent, self.radius = name, np.asarray(head, np.float32), np.asarray(tail, np.float32), parent, radius


def mirror(bones):
    """the .L bones copied to .R across X = 0 (parents renamed to match)"""
    out = list(bones)
    for b in bones:
        if b.name.endswith(".L"):
            f = np.array([-1, 1, 1], np.float32)
            p = b.parent[:-2] + ".R" if b.parent and b.parent.endswith(".L") else b.parent
            out.append(Bone(b.name[:-2] + ".R", b.head * f, b.tail * f, p, b.radius))
    return out


def armature(name, bones):
    ad = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, ad)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.view_layer.objects:
        o.select_set(o == ob)
    bpy.ops.object.mode_set(mode="EDIT")
    for b in bones:
        eb = ad.edit_bones.new(b.name)
        eb.head = Vector(b.head.tolist())
        eb.tail = Vector(b.tail.tolist())
        eb.roll = 0.0
    for b in bones:
        if b.parent:
            eb = ad.edit_bones[b.name]
            eb.parent = ad.edit_bones[b.parent]
            eb.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def _seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(float(ab @ ab), 1e-9), 0.0, 1.0)
    return np.linalg.norm(P - a - np.outer(t, ab), axis=1)


def skin(low, arm, bones, A, rig_b, falloff=0.012, smooth_iters=8):
    """weights for `low`: A (N, B) bool, the bones each vertex may take; rig_b (N,) a bone index for vertices bound wholly to one bone, else -1"""
    me = low.data
    n = len(me.vertices)
    P = np.zeros(n * 3, np.float32)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    B = len(bones)
    D = np.stack([_seg_dist(P, b.head, b.tail) - b.radius for b in bones], 1)
    D = np.where(A, D, np.inf)
    dmin = D.min(1, keepdims=True)
    W = np.where(A, np.exp(-np.clip(D - dmin, 0, None) / falloff), 0.0)
    W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    fixed = rig_b >= 0
    W[fixed] = 0.0
    W[fixed, rig_b[fixed]] = 1.0
    # smooth over the mesh's edges (rigid vertices stay put)
    e = np.zeros(len(me.edges) * 2, np.int32)
    me.edges.foreach_get("vertices", e)
    e = e.reshape(-1, 2)
    for _ in range(smooth_iters):
        acc = np.zeros_like(W)
        cnt = np.zeros(n)
        np.add.at(acc, e[:, 0], W[e[:, 1]])
        np.add.at(acc, e[:, 1], W[e[:, 0]])
        np.add.at(cnt, e[:, 0], 1)
        np.add.at(cnt, e[:, 1], 1)
        avg = acc / np.maximum(cnt, 1)[:, None]
        Wn = W * 0.5 + avg * 0.5
        Wn = np.where(A, Wn, 0.0)
        Wn /= np.maximum(Wn.sum(1, keepdims=True), 1e-9)
        W = np.where(fixed[:, None], W, Wn)
    # four strongest
    top = np.argsort(-W, axis=1)[:, :4]
    keep = np.zeros_like(W)
    rows = np.arange(n)[:, None]
    keep[rows, top] = W[rows, top]
    keep[keep < 0.02] = 0.0
    keep /= np.maximum(keep.sum(1, keepdims=True), 1e-9)
    low.vertex_groups.clear()
    groups = [low.vertex_groups.new(name=b.name) for b in bones]
    for bi in range(B):
        idx = np.nonzero(keep[:, bi] > 0)[0]
        if len(idx) == 0:
            continue
        vals = keep[idx, bi]
        q = np.round(vals * 200).astype(int)
        for qv in np.unique(q):
            sel = idx[q == qv]
            groups[bi].add(sel.tolist(), float(qv) / 200.0, "REPLACE")
    low.parent = arm
    mod = low.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return keep
