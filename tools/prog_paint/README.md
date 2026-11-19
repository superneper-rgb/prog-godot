# Prog's model and texture

`assets/prog.glb` + `assets/prog_paint.png` are made here (user, 2026-11-15): V1's body, skeleton and moves, V3's head (chin, jaw, mouth with
teeth and tongue on a new `jaw` bone), V1's long back hair, one painted texture. The skeleton is never written by Blender's glTF exporter (it turns
the bones and every pose with them): the tools copy V1's nodes and skin as they are and add only the jaw.

Sources (no longer in the project; take them from git history with `git show 3c1b326:<path> | git lfs smudge > <file>`, or the copies in
`F:/prog-godot-cache/prog_paint/src/`): V1 `assets/prog.glb` (as prog_v1_original.glb), V3 `assets/prog3/prog3.glb` and
`assets/prog3/prog3_prog3_atlas_full.jpg` (as prog3_atlas.jpg). Work files go in `F:/prog-godot-cache/prog_paint/`.

1. **Head, limbs and clothes** (Blender, headless: `blender --background --factory-startup --python tools/prog_paint/build.py -- src/prog_v1_original.glb src/prog3.glb work/prog_head.glb`
   runs all of the below; use absolute paths; or live through the MCP): `head_swap.run(v1_original, prog3)` builds the object "Prog";
   `limbs.run(ob, v1_original)` fuses his arms into his torso and his palms onto his forearms (one skin, rounded shoulders and wrists, weights blended
   across the seams); `jorts.run(ob)` replaces V1's shorts with baggy frayed jorts built ring by ring round his hips and thighs (2026-11-16; their
   shape is the constants at its top); `tank.run(ob)` replaces V1's bib-like tank with a ribbed A-shirt cast round his torso (scoop neck, straps, deep
   armholes, the hem over the jorts; 2026-11-16); `boots.run(ob)` replaces V1's boots with moc-toe work boots (welt and lug sole, collar, tongue, eyelets,
   speed hooks, laces; 2026-11-16; paint.py keeps a copy of the constants it needs); `glb_out.write(ob, v1_original, work/prog_head.glb)` writes it with V1's skeleton plus the jaw. To see the skin
   deform before exporting, give "Prog" an Armature modifier on V1's rig imported from the same file and pose it.
2. **Bake** (Blender, headless): `blender --background --factory-startup --python tools/prog_paint/bake.py -- work/prog_head.glb work 2048 src/prog3_atlas.jpg`
   lays out the UVs (uv.npz) and bakes the maps the painter reads (maps.npz), V3's painted face carried over among them.
3. **Paint**: `python tools/prog_paint/paint.py work assets/prog_paint.png` (numpy; every stroke is a function of the bind-pose position).
4. **Write**: `python tools/prog_paint/write_glb.py work/prog_head.glb work/uv.npz prog_paint.png assets/prog.glb`, then `node tools/import.mjs`.

A repaint only needs steps 3 and 4 (with the same work folder). `prog_mesh.py` is the shared reader; in a live Blender, `Model(glb).make_object(name, uv.npz)`
shows the model with the layout, and a timer reloading `paint.png` shows each paint pass as it lands.
