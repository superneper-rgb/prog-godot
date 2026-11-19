## The folk kit's mesher: turns a clay shape (kit/sdf.py) into a dense quad mesh (surface nets, then every vertex settled onto the true surface), parts as materials.
import numpy as np
import bpy
from . import sdf

F = np.float32


def _grid_eval(shape, lo, h, n):
    """the shape's distance on an n[0] x n[1] x n[2] grid of spacing h from lo, evaluated finely only near the surface"""
    C = 8
    cn = [(n[i] - 1 + C - 1) // C + 1 for i in range(3)]
    cx = [lo[i] + np.arange(cn[i], dtype=F) * h * C for i in range(3)]
    CP = np.stack(np.meshgrid(*cx, indexing="ij"), -1).reshape(-1, 3)
    cd = shape.eval(CP)[0].reshape(cn)
    # a coarse cell is near the surface if any corner is within reach of it (1.6 x its diagonal: smooth unions are not exact distances)
    reach = 1.6 * np.sqrt(3.0) * h * C
    a = np.abs(cd)
    m = a[:-1, :-1, :-1]
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                m = np.minimum(m, a[dx:dx + cn[0] - 1, dy:dy + cn[1] - 1, dz:dz + cn[2] - 1])
    near = m < reach
    nf = np.repeat(np.repeat(np.repeat(near, C, 0), C, 1), C, 2)
    nf = np.pad(nf, [(0, 1), (0, 1), (0, 1)], mode="edge")[: n[0], : n[1], : n[2]]
    # far points take the sign of the nearest coarse sample
    ci = [np.minimum(np.round(np.arange(n[i]) / C).astype(int), cn[i] - 1) for i in range(3)]
    D = np.sign(cd[np.ix_(ci[0], ci[1], ci[2])]).astype(F) * F(10.0 * h)
    idx = np.nonzero(nf)
    P = np.stack([lo[i] + idx[i].astype(F) * h for i in range(3)], -1).astype(F)
    D[idx] = shape.eval(P)[0]
    return D


def surface_nets(shape, h, pad=0.03):
    lo, hi = shape.bound()
    lo = np.asarray(lo, F) - pad
    hi = np.asarray(hi, F) + pad
    n = [int(np.ceil((hi[i] - lo[i]) / h)) + 1 for i in range(3)]
    D = _grid_eval(shape, lo, h, n)
    ins = D < 0
    # active cells: their 8 corners disagree
    c0 = ins[:-1, :-1, :-1]
    anyin = c0.copy()
    allin = c0.copy()
    offs = [(dx, dy, dz) for dx in (0, 1) for dy in (0, 1) for dz in (0, 1)]
    for o in offs[1:]:
        s = ins[o[0]: o[0] + n[0] - 1, o[1]: o[1] + n[1] - 1, o[2]: o[2] + n[2] - 1]
        anyin |= s
        allin &= s
    act = anyin & ~allin
    ai, aj, ak = np.nonzero(act)
    vid = np.full(act.shape, -1, np.int64)
    vid[ai, aj, ak] = np.arange(len(ai))
    # vertex = mean of the edge crossings in its cell
    edges = [(a, b) for a in range(8) for b in range(a + 1, 8) if sum(abs(offs[a][k] - offs[b][k]) for k in range(3)) == 1]
    acc = np.zeros((len(ai), 3), F)
    cnt = np.zeros(len(ai), F)
    for a, b in edges:
        oa, ob = offs[a], offs[b]
        da = D[ai + oa[0], aj + oa[1], ak + oa[2]]
        db = D[ai + ob[0], aj + ob[1], ak + ob[2]]
        m = (da < 0) != (db < 0)
        t = np.where(m, da / np.where(m, da - db, 1.0), 0.0)
        pa = np.stack([ai + oa[0], aj + oa[1], ak + oa[2]], -1).astype(F)
        pb = np.stack([ai + ob[0], aj + ob[1], ak + ob[2]], -1).astype(F)
        p = pa + (pb - pa) * t[:, None]
        acc += np.where(m[:, None], p, 0.0)
        cnt += m
    V = lo + acc / np.maximum(cnt, 1)[:, None] * h
    # one quad per grid edge that crosses the surface, wound so it faces out
    quads = []
    for axis in range(3):
        sl0 = [slice(0, n[0]), slice(0, n[1]), slice(0, n[2])]
        sl1 = list(sl0)
        sl0[axis] = slice(0, n[axis] - 1)
        sl1[axis] = slice(1, n[axis])
        a_in = ins[tuple(sl0)]
        b_in = ins[tuple(sl1)]
        cross = a_in != b_in
        # the edge needs its 4 neighbouring cells: drop the first row along the other two axes
        o = [i for i in range(3) if i != axis]
        sel = [slice(None)] * 3
        sel[o[0]] = slice(1, n[o[0]] - 1)
        sel[o[1]] = slice(1, n[o[1]] - 1)
        cross = cross[tuple(sel)]
        e = np.nonzero(cross)
        idx = [e[0].copy(), e[1].copy(), e[2].copy()]
        idx[o[0]] += 1
        idx[o[1]] += 1
        inside_low = ins[idx[0], idx[1], idx[2]]

        def cell(du, dv):
            c = [idx[0].copy(), idx[1].copy(), idx[2].copy()]
            c[o[0]] -= du
            c[o[1]] -= dv
            return vid[c[0], c[1], c[2]]
        q = np.stack([cell(1, 1), cell(0, 1), cell(0, 0), cell(1, 0)], -1)
        # the (u, v, axis) order above faces +axis for x and z, -axis for y: flip where the outside is the other way
        face_pos = inside_low if axis != 1 else ~inside_low
        q = np.where(face_pos[:, None], q, q[:, ::-1])
        quads.append(q)
    Q = np.concatenate(quads, 0)
    Q = Q[(Q >= 0).all(1)]
    return V.astype(F), Q


def settle(shape, V, h, iters=3, eps=0.0008):
    """move each vertex onto the zero surface along the distance gradient"""
    ex = np.array([[eps, 0, 0], [0, eps, 0], [0, 0, eps]], F)
    for _ in range(iters):
        d = shape.eval(V)[0]
        g = np.stack([(shape.eval(V + ex[i])[0] - shape.eval(V - ex[i])[0]) / (2 * eps) for i in range(3)], -1)
        gl2 = np.maximum(np.einsum("ij,ij->i", g, g), 1e-6)
        step = (d / gl2)[:, None] * g
        # never move a vertex more than half a cell in one go (thin parts, sharp creases)
        sl = np.linalg.norm(step, axis=1, keepdims=True)
        step *= np.minimum(1.0, 0.6 * h / np.maximum(sl, 1e-9))
        V = V - step
    return V


def relax(V, Q, lam=0.5):
    """pull each vertex toward the mean of its neighbours (evens out the grid's stair steps; settle puts it back on the surface)"""
    e0 = np.concatenate([Q[:, 0], Q[:, 1], Q[:, 2], Q[:, 3]])
    e1 = np.concatenate([Q[:, 1], Q[:, 2], Q[:, 3], Q[:, 0]])
    n = len(V)
    cnt = np.bincount(e0, minlength=n) + np.bincount(e1, minlength=n)
    avg = np.stack([np.bincount(e0, weights=V[e1, i], minlength=n) + np.bincount(e1, weights=V[e0, i], minlength=n) for i in range(3)], -1)
    avg /= np.maximum(cnt, 1)[:, None]
    return (V + (avg - V) * lam).astype(F)


def build(shape, name, h=0.004, mats=None, smooth_iters=3, relax_iters=4):
    """mesh `shape` into a new Blender object `name`. mats: {part id: material} (a face takes the part of its centre)."""
    V, Q = surface_nets(shape, h)
    V = settle(shape, V, h, smooth_iters)
    for _ in range(relax_iters):
        V = settle(shape, relax(V, Q), h, 2)
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(V))
    me.vertices.foreach_set("co", V.ravel())
    nq = len(Q)
    me.loops.add(nq * 4)
    me.loops.foreach_set("vertex_index", Q.ravel().astype(np.int32))
    me.polygons.add(nq)
    me.polygons.foreach_set("loop_start", (np.arange(nq) * 4).astype(np.int32))
    me.update(calc_edges=True)
    me.validate(clean_customdata=False)
    if mats:
        keys = sorted(mats)
        for k in keys:
            me.materials.append(mats[k])
        cen = np.zeros(len(me.polygons) * 3, F)
        me.polygons.foreach_get("center", cen)
        part = shape.eval(cen.reshape(-1, 3))[1]
        lut = {k: i for i, k in enumerate(keys)}
        mi = np.array([lut.get(int(p), 0) for p in part], np.int32)
        me.polygons.foreach_set("material_index", mi)
    me.polygons.foreach_set("use_smooth", np.ones(len(me.polygons), bool))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob
