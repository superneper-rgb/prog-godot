## Renders the model from a reference view's camera and blends it over that reference, for comparison.
import bpy, os, numpy as np
from mathutils import Vector
S = 1.72 / 1292.0
OUT = os.path.dirname(__file__) if "__file__" in globals() else "."

REFS = {"front": "Faceted Gray Alien in Indigo Costume-1.png", "back": "Low-poly Zeta alien back view-2.png", "sideR": "Low-poly Zeta alien side profile-4.png"}
def load_refs(folder="C:/Users/12147/Downloads/"):
    """The user's reference views, as images ref_front / ref_back / ref_sideR (shoot() blends against them)."""
    for k, f in REFS.items():
        if not bpy.data.images.get("ref_" + k):
            bpy.data.images.load(folder + f).name = "ref_" + k

def setup_cam():
    sc = bpy.context.scene
    cam = bpy.data.objects.get("refcam")
    if not cam:
        cd = bpy.data.cameras.new("refcam"); cam = bpy.data.objects.new("refcam", cd); sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; sc.camera = cam
    return cam

def turn(az_deg, out_dir, name, z=0.86, half=0.95, res=(600, 800), el_deg=0.0, x=0.0, engine='BLENDER_WORKBENCH', transparent=False):
    """Free ortho view: az 0 = front, 90 = her left side, 180 = back. z/half in metres."""
    import math
    sc = bpy.context.scene; cam = setup_cam()
    az = math.radians(az_deg); el = math.radians(el_deg)
    d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    tgt = Vector((x, 0, z))
    cam.location = tgt + d * 6; cam.rotation_euler = (-d).to_track_quat('-Z', 'Y').to_euler()
    cam.data.ortho_scale = 2 * half * max(1.0, res[0] / res[1])
    sc.render.engine = engine
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.resolution_percentage = 100
    sc.render.film_transparent = transparent
    sc.render.image_settings.file_format = 'PNG'
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
    return sc.render.filepath

def shoot(view, out_dir, mix=0.5, zoom=None, res=(1086, 1448), name=None, engine='BLENDER_WORKBENCH'):
    """view: front | back | side. zoom: (cx_px, cy_px, half_height_px) region of the reference to frame."""
    sc = bpy.context.scene; cam = setup_cam()
    W, H = 1086, 1448
    cxp, cyp, hh = (W / 2, H / 2, H / 2) if zoom is None else zoom
    aspect = res[0] / res[1]
    cam.data.ortho_scale = 2 * hh * S * max(1.0, aspect)
    z = (1330.0 - cyp) * S
    if view == "front":
        cam.location = ((cxp - 543) * S, -6, z); look = Vector((0, 1, 0)); ref = "ref_front"
    elif view == "back":
        cam.location = (-(cxp - 543) * S, 6, z); look = Vector((0, -1, 0)); ref = "ref_back"
    else:
        cam.location = (-6, -(cxp - 530) * S, z); look = Vector((1, 0, 0)); ref = "ref_sideR"
    cam.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()
    sc.render.engine = engine
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
    path = os.path.join(out_dir, (name or ("cmp_" + view)) + ".png")
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    if mix is None: return path
    r = bpy.data.images.load(path); r.colorspace_settings.name = 'sRGB'
    a = np.array(r.pixels[:], dtype=np.float32).reshape(res[1], res[0], 4)
    bpy.data.images.remove(r)
    refimg = bpy.data.images[ref]
    b = np.array(refimg.pixels[:], dtype=np.float32).reshape(H, W, 4)
    # crop the reference to the same region (pixel rows are bottom-up)
    x0 = int(round(cxp - hh * aspect)); x1 = int(round(cxp + hh * aspect))
    y0 = int(round(H - (cyp + hh))); y1 = int(round(H - (cyp - hh)))
    crop = np.zeros((y1 - y0, x1 - x0, 4), dtype=np.float32); crop[..., 3] = 1; crop[..., :3] = 0.39
    sx0, sx1, sy0, sy1 = max(x0, 0), min(x1, W), max(y0, 0), min(y1, H)
    crop[sy0 - y0:sy1 - y0, sx0 - x0:sx1 - x0] = b[sy0:sy1, sx0:sx1]
    yi = (np.arange(res[1]) * crop.shape[0] / res[1]).astype(int); xi = (np.arange(res[0]) * crop.shape[1] / res[0]).astype(int)
    crop = crop[yi][:, xi]
    al = a[..., 3:4] * mix
    out = crop.copy(); out[..., :3] = crop[..., :3] * (1 - al) + a[..., :3] * al
    # outline of the render in red so the silhouette difference reads
    m = a[..., 3] > 0.5
    edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
    out[edge, 0] = 1.0; out[edge, 1] = 0.1; out[edge, 2] = 0.1
    o = bpy.data.images.new("cmp_tmp", res[0], res[1], alpha=True)
    o.pixels.foreach_set(out.ravel()); o.filepath_raw = path; o.file_format = 'PNG'; o.save()
    bpy.data.images.remove(o)
    return path
