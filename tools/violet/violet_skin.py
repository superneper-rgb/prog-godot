## Violet Starborn: UVs for her skin meshes and the painted skin textures (eye shadow, lips, navel...), computed from positions.
import bpy, bmesh, math, sys, os
import numpy as np
vb = sys.modules["violet_body"]; vp = sys.modules["violet_parts"]
S = vb.S
OUT = "F:/prog-godot-cache/violet"
BASE = np.array([0.775, 0.765, 0.795])

def unwrap_cyl(ob, yc, zmin, zmax, bag_mat=None):
    """Cylinder UVs round the vertical axis through (0, yc); front centre lands on u = 0.5."""
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        us = []
        for l in f.loops:
            c = l.vert.co
            us.append(0.5 + math.atan2(c.x, -(c.y - yc)) / (2 * math.pi))
        if max(us) - min(us) > 0.5:
            us = [u + 1.0 if u < 0.5 else u for u in us]
        for l, u in zip(f.loops, us):
            v = (l.vert.co.z - zmin) / (zmax - zmin)
            if bag_mat is not None and f.material_index == bag_mat:
                l[uvl].uv = (0.01, 0.01)
            else:
                l[uvl].uv = (u, min(0.995, max(0.005, v)))
    bm.to_mesh(me); bm.free()

def bake(ob, fn, size, path, skip_mat=None):
    """Rasterise fn(X, Y, D) -> rgb over the mesh's UV triangles (u wraps, so the back seam is seamless)."""
    me = ob.data
    img = np.zeros((size, size, 3), dtype=np.float32); filled = np.zeros((size, size), dtype=bool)
    uv = me.uv_layers.active.data
    me.calc_loop_triangles()
    for t in me.loop_triangles:
        if skip_mat is not None and t.material_index == skip_mat: continue
        P = np.array([me.vertices[i].co[:] for i in t.vertices], dtype=np.float64)
        U = np.array([uv[i].uv[:] for i in t.loops], dtype=np.float64) * size
        x0 = int(math.floor(U[:, 0].min())) - 1; x1 = int(math.ceil(U[:, 0].max())) + 1
        y0 = int(math.floor(U[:, 1].min())) - 1; y1 = int(math.ceil(U[:, 1].max())) + 1
        if x1 - x0 > size * 0.6: continue
        xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        d = (U[1, 1] - U[2, 1]) * (U[0, 0] - U[2, 0]) + (U[2, 0] - U[1, 0]) * (U[0, 1] - U[2, 1])
        if abs(d) < 1e-12: continue
        w0 = ((U[1, 1] - U[2, 1]) * (xs - U[2, 0]) + (U[2, 0] - U[1, 0]) * (ys - U[2, 1])) / d
        w1 = ((U[2, 1] - U[0, 1]) * (xs - U[2, 0]) + (U[0, 0] - U[2, 0]) * (ys - U[2, 1])) / d
        w2 = 1.0 - w0 - w1
        eps = -0.6 / max(1.0, math.sqrt(abs(d)))
        m = (w0 >= eps) & (w1 >= eps) & (w2 >= eps)
        if not m.any(): continue
        pos = w0[m][:, None] * P[0] + w1[m][:, None] * P[1] + w2[m][:, None] * P[2]
        col = fn(pos[:, 0] / S, 1330.0 - pos[:, 2] / S, 530.0 - pos[:, 1] / S)
        px = np.floor(xs[m]).astype(int) % size; py = np.clip(np.floor(ys[m]).astype(int), 0, size - 1)
        img[py, px] = col; filled[py, px] = True
    for _ in range(12):                              # bleed past the island edges
        if filled.all(): break
        acc = np.zeros_like(img); cnt = np.zeros((size, size), dtype=np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            f2 = np.roll(filled, (dy, dx), (0, 1)); acc += np.roll(img, (dy, dx), (0, 1)) * f2[..., None]; cnt += f2
        new = (~filled) & (cnt > 0)
        img[new] = acc[new] / cnt[new][:, None]; filled |= new
    img[~filled] = BASE
    rgba = np.concatenate([np.clip(img, 0, 1), np.ones((size, size, 1), dtype=np.float32)], axis=2)
    name = os.path.basename(path)
    old = bpy.data.images.get(name)
    if old: bpy.data.images.remove(old)
    im = bpy.data.images.new(name, size, size, alpha=False); im.colorspace_settings.name = 'sRGB'
    im.pixels.foreach_set(rgba.ravel()); im.filepath_raw = path; im.file_format = 'PNG'; im.save()
    return im

def mix(c, col, k):
    return c * (1.0 - k[:, None]) + np.array(col)[None, :] * k[:, None]

def paint_head(m0):
    vh = sys.modules["violet_head"]
    def fn(X, Y, D):
        c = np.tile(BASE, (len(X), 1))
        front = np.clip((D - 555.0) / 25.0, 0, 1)
        d, w = vh.eye_dist(X, Y)
        dp = np.maximum(d, 0.0)
        reach = np.where(w > 0, 9.5, 5.5)                                     # the shadow runs further up the lid, towards the brow
        k = np.exp(-(dp / reach) ** 2) * 0.92 * front
        c = mix(c, (0.63, 0.53, 0.82), k)                                     # lilac lids
        k = np.exp(-(dp / 2.0) ** 2) * 0.7 * front
        c = mix(c, (0.30, 0.22, 0.45), k)                                     # darker at the lash line
        k = np.exp(-(vh.poly_dist(np.abs(X), Y - 4.5, vh.BROW) / 3.5) ** 2) * 0.09 * front
        c = c * (1.0 - k[:, None])                                            # shade under the brow
        up = np.clip(vh.lips_upper(X, Y, m0) * 1.7, 0, 1); lo = np.clip(vh.lips_lower(X, Y, m0) * 1.6, 0, 1)
        c = mix(c, (0.55, 0.40, 0.57), up * 0.85 * front)                     # lips: the upper one a shade darker
        c = mix(c, (0.62, 0.46, 0.63), lo * 0.85 * front)
        k = vh.gauss(X, Y, 0.0, m0 + 3.6, 4.5, 1.6) * 0.35 * front
        c = c * (1.0 + k[:, None] * 0.5)                                      # soft light on the lower lip
        k = np.exp(-((Y - m0) / 0.9) ** 2) * np.clip((13.0 - np.abs(X)) / 3.0, 0, 1) * 0.8 * front
        c = mix(c, (0.24, 0.15, 0.27), k)                                     # the line between them
        k = vh.gauss2(X, Y, 4.6, 205.0, 1.7, 1.4) * 0.8 * front
        c = mix(c, (0.30, 0.25, 0.32), k)                                     # nostrils
        k = (vh.gauss(X, Y, 0.0, 208.5, 7.0, 2.0) * 0.10 + vh.gauss(X, Y, 0.0, m0 + 10.5, 8.0, 2.4) * 0.10
             + vh.gauss2(X, Y, 8.0, 186.0, 3.0, 14.0) * 0.06 + vh.gauss2(X, Y, 36.0, 207.0, 12.0, 11.0) * 0.05) * front
        c = c * (1.0 - k[:, None])                                            # under the nose, under the lip, nose sides, cheek hollows
        k = (vh.gauss2(X, Y, 52.0, 178.0, 14.0, 8.0) * 0.05 + vh.gauss(X, Y, 0.0, 190.0, 2.5, 14.0) * 0.05) * front
        c = c * (1.0 + k[:, None])                                            # light on the cheek bones and the nose bridge
        k = np.clip((Y - 238.0) / 22.0, 0, 1) * 0.14                           # under the chin, down the neck
        c = c * (1.0 - k[:, None])
        return c
    return fn

def seg_dist(X, Y, ax, ay, bx, by):
    px = X - ax; py = Y - ay; vx = bx - ax; vy = by - ay
    t = np.clip((px * vx + py * vy) / (vx * vx + vy * vy), 0, 1)
    return np.hypot(px - t * vx, py - t * vy)

def paint_body(X, Y, D):
    c = np.tile(BASE, (len(X), 1))
    front = np.clip((D - 545.0) / 25.0, 0, 1); back = np.clip((520.0 - D) / 25.0, 0, 1)
    aX = np.abs(X)
    k = np.exp(-((X / 9.0) ** 2 + ((Y - 537.0) / 11.0) ** 2)) * 0.07 * front; c = c * (1 - k[:, None])
    k = np.exp(-((X / 2.3) ** 2 + ((Y - 537.0) / 4.4) ** 2)) * 0.85 * front; c = mix(c, (0.36, 0.32, 0.37), k)      # navel
    win = np.clip((Y - 440.0) / 20.0, 0, 1) * np.clip((528.0 - Y) / 14.0, 0, 1)
    k = np.exp(-(X / 4.5) ** 2) * 0.06 * win * front; c = c * (1 - k[:, None])
    for off, amt in ((0.0, 0.07), (5.5, -0.09)):                                                                    # collar bones
        d = seg_dist(aX, Y, 13.0, 304.0 + off, 70.0, 294.0 + off)
        k = np.exp(-(d / 3.2) ** 2) * amt * front; c = c * (1 + k[:, None])
    win = np.clip((Y - 345.0) / 20.0, 0, 1) * np.clip((415.0 - Y) / 14.0, 0, 1)
    k = np.exp(-(X / 7.0) ** 2) * 0.10 * win * front; c = c * (1 - k[:, None])                                      # between the breasts
    win = np.clip((Y - 300.0) / 30.0, 0, 1) * np.clip((565.0 - Y) / 30.0, 0, 1)
    k = np.exp(-(X / 5.0) ** 2) * 0.08 * win * back; c = c * (1 - k[:, None])                                       # spine
    k = np.exp(-(((aX - 79.0) / 14.0) ** 2 + ((Y - 884.0) / 16.0) ** 2)) * 0.05 * front; c = c * (1 + k[:, None])   # knees
    return c

def skin_mat(name, img, rough=0.5):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True; nt = m.node_tree; nt.nodes.clear()
    o = nt.nodes.new("ShaderNodeOutputMaterial"); b = nt.nodes.new("ShaderNodeBsdfPrincipled"); t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img; b.inputs["Roughness"].default_value = rough
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"]); nt.links.new(b.outputs["BSDF"], o.inputs["Surface"])
    t.location = (-400, 0); o.location = (300, 0)
    return m

def make(parts):
    os.makedirs(OUT, exist_ok=True)
    head, body = parts["head"], parts["body"]
    zs = [v.co.z for v in head.data.vertices]
    unwrap_cyl(head, vb.sy(523.0), min(zs), max(zs), bag_mat=1)
    zs = [v.co.z for v in body.data.vertices]
    unwrap_cyl(body, vb.sy(545.0), min(zs), max(zs))
    ih = bake(head, paint_head(parts["mouth"]["rowY"]), 2048, OUT + "/violet_skin_head.png", skip_mat=1)
    ib = bake(body, paint_body, 1024, OUT + "/violet_skin_body.png")
    mh = skin_mat("MAT_Violet_Skin_Head", ih); mb = skin_mat("MAT_Violet_Skin_Body", ib)
    head.data.materials[0] = mh; body.data.materials[0] = mb
    return ih, ib
