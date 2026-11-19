## Builds one FOINT CITY townsfolk character from its recipe (tools/folk/recipes/<id>.py) with the folk kit, and renders it next to its concept.
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python tools/folk/build.py -- <id> [--colour|--paint|--game] [--views front,q3,side,back,face@-45,bust]
#   --colour  the clay in flat part colours      --paint  the painted clay      --game  the painted clay baked onto a light, rigged, animated model,
#             exported to assets/folk/<id>/ (<id>.gltf + .bin + its 1024 maps + <id>.json; then node tools/import.mjs), with renders of it and strips of its moves
#   --meta    only rewrite assets/folk/<id>/<id>.json from the recipe's GAME (stride, speed, look bones...)
# Working files (the .blend, baked maps, renders, sheets) go to F:/prog-godot-cache/folk/<id>/.
import bpy, sys, os, time, importlib.util
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from kit import mesher, look, paint, sdf  # noqa: E402

CACHE = "F:/prog-godot-cache/folk"
REFS = CACHE + "/refs"
ASSETS = os.path.join(HERE, "..", "..", "assets", "folk")


def recipe(cid):
    spec = importlib.util.spec_from_file_location("recipe_" + cid, os.path.join(HERE, "recipes", cid + ".py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def game_model(R, cid, pieces, highs, pmat, out):
    from kit import game, rig, gait
    t = time.time()
    names = [n for n, _, _ in pieces]
    low = game.make_low([(n, ob) for n, ob in zip(names, highs)], R.GAME["budget"], cid)
    game.unwrap(low, names, R.GAME["density"])
    baked = game.bake(low, highs, pmat, os.path.join(out, "tex"), cid, R.GAME["tex"])
    game.game_material(low, baked, "M_" + cid)
    print("GAME low %d tris, baked in %.1f s" % (game._tris(low.data), time.time() - t), flush=True)
    # which piece and which part each vertex belongs to
    me = low.data
    nv, nf = len(me.vertices), len(me.polygons)
    fp = np.zeros(nf, np.int32)
    me.attributes["piece"].data.foreach_get("value", fp)
    lt = np.zeros(nf, np.int32)
    me.polygons.foreach_get("loop_total", lt)
    lv = np.zeros(len(me.loops), np.int32)
    me.loops.foreach_get("vertex_index", lv)
    piece = np.zeros(nv, np.int32)
    piece[lv] = np.repeat(fp, lt)
    P = np.zeros(nv * 3, np.float32)
    me.vertices.foreach_get("co", P)
    P = P.reshape(-1, 3)
    part = np.zeros(nv, np.int16)
    for i, (_, shape, _) in enumerate(pieces):
        m = piece == i
        if m.any():
            part[m] = shape.eval(P[m])[1]
    bones = R.rig_bones()
    arm = rig.armature(cid + "_rig", bones)
    A, rigid = R.skin_rules(P, part, piece, [b.name for b in bones])
    rig.skin(low, arm, bones, A, rigid)
    rg = gait.Rig(arm)
    bpy.context.scene.render.fps = 30          # keys are 30 a second (the idle is 6 s; walk and run play by phase)
    acts = {nm: gait.write_action(rg, poses, nm) for nm, poses in R.motions(rg).items()}
    print("GAME rigged %d bones, clips %s, %.1f s" % (len(bones), {k: len(v.fcurves) if hasattr(v, "fcurves") else "?" for k, v in acts.items()}, time.time() - t), flush=True)
    # export
    # glTF with its textures as files beside it (a GLB's embedded maps would be extracted again by Godot's import: two copies in the repository)
    folder = os.path.abspath(os.path.join(ASSETS, cid))
    os.makedirs(folder, exist_ok=True)
    for f in os.listdir(folder):
        if f.startswith(cid) and f.split(".")[-1] in ("gltf", "bin", "png"):
            os.remove(os.path.join(folder, f))
    for f in (cid + ".glb", cid + ".glb.import"):        # (the first exports were GLBs in assets/folk itself)
        if os.path.exists(os.path.join(ASSETS, f)):
            os.remove(os.path.join(ASSETS, f))
    glb = os.path.join(folder, cid + ".gltf")
    for o in bpy.context.view_layer.objects:
        o.select_set(o in (low, arm))
    bpy.context.view_layer.objects.active = arm
    arm.animation_data.action = None
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLTF_SEPARATE", export_texture_dir="", use_selection=True, export_animations=True, export_animation_mode="ACTIONS",
                              export_skins=True, export_influence_nb=4, export_tangents=True, export_yup=True, export_def_bones=False,
                              export_leaf_bone=False, export_force_sampling=True, export_optimize_animation_size=False, export_rest_position_armature=True)
    # a build stamp in the glTF: a rebuild that only changes the .bin (weights, keys) leaves the .gltf text byte for byte the same, and Godot, which
    # tracks only the .gltf's md5, would keep its old import (2026-11-16: a weights fix that never reached the game)
    import json
    with open(glb, encoding="utf-8") as f:
        gl = json.load(f)
    gl.setdefault("asset", {}).setdefault("extras", {})["built"] = time.strftime("%Y-%m-%d %H:%M:%S")
    with open(glb, "w", encoding="utf-8") as f:
        json.dump(gl, f, indent=1)
    print("GLB", glb, flush=True)
    write_meta(R, cid)
    return low, arm, acts


def write_meta(R, cid):
    """assets/folk/<id>.json: what the game needs to know of the species (levels/hub/folk_skin.gd reads it). Godot space: Y up, the figure faces +Z."""
    import json
    g = R.GAME
    lp = g.get("look_pivot", (0.0, 0.0, R.HEIGHT * 0.83))
    meta = {
        "height": R.HEIGHT,
        "stride_walk": g["stride"]["walk"],
        "stride_run": g["stride"]["run"],
        "speed": g.get("speed", 1.0),
        "look": list(g.get("look", ["head"]))[:3],
        "neck": g.get("neck", "neck"),
        "pivot": [float(lp[0]), float(lp[2]), -float(lp[1])],
        "radius": g.get("radius", 0.4),
    }
    os.makedirs(os.path.join(ASSETS, cid), exist_ok=True)
    path = os.path.abspath(os.path.join(ASSETS, cid, cid + ".json"))
    if os.path.exists(os.path.join(ASSETS, cid + ".json")):
        os.remove(os.path.join(ASSETS, cid + ".json"))
    with open(path, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=1)
    print("META", path, meta, flush=True)
    import_settings(cid)


def import_settings(cid):
    """the maps' Godot import settings, written before Godot sees them (it keeps what is there): VRAM-compressed with mipmaps, the normal map as a normal map.
    A loose PNG would otherwise import lossless: 46 species of that is most of a 6 GB card."""
    folder = os.path.join(ASSETS, cid)
    for kind in ("albedo", "normal", "orm"):
        png = os.path.join(folder, "%s_%s.png" % (cid, kind))
        imp = png + ".import"
        want = {"compress/mode": "2", "compress/normal_map": "1" if kind == "normal" else "2", "mipmaps/generate": "true",
                "compress/high_quality": "false", "detect_3d/compress_to": "0"}
        if os.path.exists(imp):
            lines = open(imp, encoding="utf-8").read().splitlines()
            out = []
            for ln in lines:
                k = ln.split("=", 1)[0]
                out.append("%s=%s" % (k, want.pop(k)) if k in want else ln)
            if want:
                i = out.index("[params]") + 1 if "[params]" in out else len(out)
                out[i:i] = ["%s=%s" % kv for kv in want.items()]
            text = "\n".join(out) + "\n"
        else:
            head = ['[remap]', '', 'importer="texture"', 'type="CompressedTexture2D"', '', '[params]', '']
            text = "\n".join(head + ["%s=%s" % kv for kv in want.items()]) + "\n"
        with open(imp, "w", encoding="utf-8") as f:
            f.write(text)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    cid = argv[0]
    colour = "--colour" in argv
    views = ("front", "q3", "side", "back")
    if "--views" in argv:
        views = tuple(argv[argv.index("--views") + 1].split(","))
    R = recipe(cid)
    if "--meta" in argv:
        write_meta(R, cid)
        return
    out = os.path.join(CACHE, cid)
    os.makedirs(out, exist_ok=True)
    look.reset()
    mats = {p: look.mat("M_%s_%d" % (cid, p), *c) for p, c in R.COLOURS.items()}
    gamemode = "--game" in argv and hasattr(R, "GAME")
    painted = ("--paint" in argv or gamemode) and hasattr(R, "paint")
    if painted:
        colour = True
    pieces = R.pieces()
    world = sdf.Union([s for _, s, _ in pieces])
    pmat = paint.material("M_%s_paint" % cid) if painted else None
    highs = []
    for name, shape, h in pieces:
        t = time.time()
        ob = mesher.build(shape, "%s_%s" % (cid, name), h=h, mats=mats)
        if painted:
            paint.paint(ob, shape, world, R.paint, pmat)
        highs.append(ob)
        print("PIECE %s: %d faces, %.1f s" % (name, len(ob.data.polygons), time.time() - t), flush=True)
    ref, box = getattr(R, "REF", (None, None)) or (None, None)
    ref = os.path.join(REFS, ref) if ref and os.path.exists(os.path.join(REFS, ref)) else None
    if gamemode:
        low, arm, acts = game_model(R, cid, pieces, highs, pmat, out)
        for h in highs:
            h.hide_render = True
        paths = look.render_views(os.path.join(out, "game"), height=R.HEIGHT, colour=True, views=views)
        sheet = look.sheet(paths, os.path.join(out, "sheet_game.png"), ref=ref, ref_box=box)
        print("SHEET", sheet, flush=True)
        # the walk, eight frames from the side and from the three-quarter; then idle and run moments
        strip = []
        sc = bpy.context.scene
        for clip, frames, view in (("walk", [0, 4, 8, 12, 16, 20, 24, 28], "side"), ("walk", [0, 8, 16, 24], "q3"), ("idle", [0, 75, 90, 105], "q3"), ("run", [0, 6, 12, 18], "side")):
            arm.animation_data.action = acts[clip]
            for fr in frames:
                sc.frame_set(fr)
                strip += look.render_views(os.path.join(out, "anim_%s_%03d" % (clip, fr)), height=R.HEIGHT, colour=True, views=(view,), px=520)
        look.sheet(strip[:8], os.path.join(out, "strip_walk_side.png"), h=520)
        look.sheet(strip[8:], os.path.join(out, "strip_moves.png"), h=520)
        print("STRIP", os.path.join(out, "strip_walk_side.png"), flush=True)
    else:
        paths = look.render_views(os.path.join(out, "view"), height=R.HEIGHT, colour=colour, views=views)
        sheet = look.sheet(paths, os.path.join(out, "sheet%s.png" % ("_paint" if painted else "_colour" if colour else "")), ref=ref, ref_box=box)
        print("SHEET", sheet, flush=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, cid + ".blend"))


main()
