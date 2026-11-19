## Builds Violet Starborn from scratch in Blender and exports assets/violet/violet.glb. Run inside Blender 5.2 (Blender MCP, or blender --python).
##   exec(open("F:/prog-godot/tools/violet/build_violet.py").read()); build()
## Stages: violet_body (quad cage measured off the reference views) + violet_head (her head and face) -> violet_parts (split, subdivide, sculpt, mouth)
## -> violet_outfit (top, shorts, boots, belt, trim) -> violet_skin (UVs + painted skin) -> violet_rig (skeleton, weights, mouth_open, GLB).
## The working .blend and the skin PNGs live in F:/prog-godot-cache/violet; violet_view has the reference-overlay renders.
import bpy, importlib.util, os, sys

HERE = "F:/prog-godot/tools/violet"
GLB = "F:/prog-godot/assets/violet/violet.glb"
BLEND = "F:/prog-godot-cache/violet/violet.blend"

def load(name):
    spec = importlib.util.spec_from_file_location(name, HERE + "/" + name + ".py")
    m = importlib.util.module_from_spec(spec); sys.modules[name] = m; spec.loader.exec_module(m)
    return m

def build(export=True):
    load("violet_body"); load("violet_head"); vp = load("violet_parts"); vo = load("violet_outfit"); vs = load("violet_skin"); vr = load("violet_rig")
    col = bpy.data.collections.get("COL_Violet")
    for o in (list(col.objects) if col else []):
        vp.drop(o.name)
    parts = vp.make_all()
    vo.make_all(parts)
    vs.make(parts)
    arm, missed = vr.rig_all(parts)
    if export:
        os.makedirs(os.path.dirname(GLB), exist_ok=True)
        vr.export(GLB)
        bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    return parts, arm, missed
