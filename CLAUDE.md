# PROG on Godot: rules for anyone working in this folder

The game is moving from three.js to **Godot 4.7.2 (GDScript, Forward+, Windows .exe)**. The three.js game in `../progalpha-20261016T082732Z-1-001/progalpha/` is now the **read-only reference**: it defines what the game does, and no new features go there. `PORT_STATUS.md` says what is done and what is next. Read that first, then this.

Engine: `F:/godot/Godot_v4.7.2-stable_win64_console.exe` (console build, prints errors). Do not write Godot 3 syntax (`yield`, `onready var`, `export var`, `.connect("sig", obj, "fn")`, `KinematicBody`, `Spatial`). Check an API with the running engine rather than from memory when unsure (`ClassDB`, `get_method_list()`, or a peek eval).

## The port law
- **Same game.** Port behaviour statement for statement: same numbers, same order of operations, same edge cases, and carry over the comments that explain why. Do not "improve" tuning, simplify logic, or drop a branch because it looks unimportant. Each one is there because something once looked wrong. If the engine forces a difference, say so in a comment.
- **Names.** JS `camelCase` becomes `snake_case` with the same words (`landT` -> `land_t`, `CONFIG.runSpeed` -> `Config.run_speed`, `rig.pullEff` -> `rig.pull_eff`), so anyone can move between the two codebases with a search.
- **Static typing everywhere** (`var x := 0.0`, `func f(a: float) -> int`): it catches errors at parse time and runs faster. Inner classes rather than loose Dictionaries for structured state.
- **No new content, no cuts.** Universe, characters and tone are canon. Do not rename, reword or re-theme anything. FOINT, GOINT, Schleed and SERN stay exactly as written. Do not change what a level, enemy or weapon is.
- One-line `##` header on every script saying what it is, in plain words.
- **One exception (user, 2026-11-07): Prog V3** (`player/prog3_animator.gd`, `assets/prog3/`) is new on purpose: his model and moves were authored fresh and do not port the JS animator. Do not "fix" him back to it.

## Architecture
- **Coordinates are the same as three.js:** right-handed, Y up, metres, yaw 0 looks along +Z, `sin(yaw), cos(yaw)` is forward, `node.rotation.y = yaw`. glTF imports with no conversion. So the JS maths ports as is.
- **One frame, in the JS order.** `Game._process` (core/game.gd) runs the whole frame with variable `dt` (capped at 0.05): input, level, combat, player (its own 1/90 s sub-steps), vehicles, camera rig, animator, FX, HUD. Gameplay never uses `_physics_process`. The physics engine is the collision database plus debris.
- **Pure simulation vs view.** `Player`, `CameraRig`, combat and AI are `RefCounted` simulation classes (like the JS ones). Nodes are their views. Views read the simulation; the simulation pushes `events` the views consume.
- **Collision is `World`** (core/world.gd): `add()/box()/add_mesh()`, `ground_height`, `blocked`, `ceiling`, `surface_in`, `point_solid`, `ray_clear`. Same semantics as the JS World, answered natively by Jolt. Never loop over solids per frame. Moving solid: `s.place()` / `s.set_span()` / `s.set_off()`.
- **A level is a `Level` node** (levels/level.gd), registered in `Game.LEVELS`. Everything it makes goes under that node: leaving frees the node and disposes its World, and that is the whole unload. No monkey patches and no global state left behind. A `Config` value a level changes is restored automatically. Timers, tweens and sounds belong to nodes under the level.
- **Shared things live for the session** (autoload `Game`, its player, rig, combat, FX pools, HUD); **level things die with the level.**
- **Autoloads:** `Config` (tuning), `Inp` (input: `Inp.move`, `Inp.look_yaw`, `Inp.btn(&"jump").pressed`), `Game`, `Peek` (dev port). Add one only when something truly is global.

## Assets
- `assets/` mirrors the JS game's `assets/` folder: same relative paths. Real files only, **never base64 or text-encoded binaries** in source.
- Godot cannot play `.m4a` or `.mp4` (no ffmpeg on this machine): `.m4a` becomes `.wav` next to where it was, decoded by the browser. There is no texture size cap in Godot: keep a model's full-resolution maps (normal, roughness, etc. included) and let Godot's import compress them. The old three.js 512 px character rule is retired.
- `.godot/` is a junction to `F:\prog-godot-cache` (C: is nearly full). Never put big scratch data on C:.
- **Importing:** run `node tools/import.mjs` after adding assets. It takes a lock, so never call `--import` directly while others may be working.
- **Levels are exported, not rewritten.** `tools/export/export.mjs` boots the real three.js game, enters a level and writes what it built to `assets/levels/<id>/` (scene.glb, colliders.json, level.json, instances.bin, shaders/*.json work list), with textures in `assets/levels/_tex/`. `levels/exported_level.gd` builds a playable level from those files. `assets/levels` is a junction to `F:/prog-godot-levels` and is **not in git**. Rebuild on a fresh checkout: `node tools/export/export.mjs all` (makes the junction, copies the JS game's own `assets/levels` files, exports every level, the guns and the suits), then `node tools/import.mjs`. One level: `node tools/export/export.mjs level <id>`. A level's moving parts are found by their JS `.name` (`ExportedLevel.node_named`): to separate something new, add a `.name` in the JS and export again.
- **Packing the .exe:** the level files are read through `res://assets/levels/...` only, never an F: path. The GLBs and textures pack through their imported resources; the export preset must also carry `assets/levels/*/level.json, colliders.json, city_life.json, life.json, *.bin` and `assets/suits/*.json` in its non-resource include filter (`probes.json` and `shaders/` are dev data).

## Performance
The JS game was CPU-bound on draw calls and scene walks. GDScript is slower than V8 per statement, so put work in native calls:
- No per-object meshes for repeated props: MultiMesh, or merge per material. Share materials.
- No hot script loops over big arrays: use PackedArrays and engine calls. Crowds animate in vertex shaders on MultiMesh.
- Skeletons: player characters, bosses and live-posed enemies only.
- Create materials and shaders at level load, never mid-play; warm pipelines at load.
- Pools for bullets, sparks and decals. Never allocate per shot if a pool can do it.

## Look and UI
- Target look: late PS2 stylised (Ratchet & Clank: Up Your Arsenal, Jak and Daxter) with strong palettes and painted textures; judge against the three.js build and match or beat it.
- Overlays, terminals and minigames use the **Phosphor CRT style**: green CRT inside the SchleedTech monitor frame (`assets/ui/`), amber for danger, 90s Alien grit.
- **Diegetic cues, no HUD timers.** Comms stay lean: only significant lines.
- All NPC talk goes through one shared dialogue system; all level doors through one shared portal system. Never a one-off copy.

## Testing (do this, never ask the user to check by hand)
- Keep one game open and drive it: `node tools/peek.mjs start [level]`, `eval "<gdscript body>"`, `run file.gd`, `shot [width]`, `frames n`, `logs`, `restart`, `quit`. Several workers at once: give each its own `PEEK_PORT` environment variable. The window sits off screen, so it never bothers the user.
- `node tools/check.mjs` compiles every script and runs the project rules. It must print `all checks passed` before you call work done. New project-wide checks go in it, never a separate script.
- `node tools/check.mjs --coverage` lists what the JS game has that the port does not yet: methods per class, functions, files per folder, and the port's own notes of things left out. It is a report: a miss is something to look at, and a hit does not prove it works. Run it before calling a package done, and account for every miss in your area.
- **Screenshots are never kept in the project:** temp folder only, look once, move on. Compare against the three.js game (`tests/lib/peek.cjs` there) when judging a look or a pose.
- Bot input for tests: `Inp.bot_on = true`, `Inp.bot_move`, `Inp.bot_held[&"jump"] = true`, `Inp.bot_look`.
- Passing a check does not mean it looks right: look at the picture.

## Never
- Commit or push (the user commits), edit the three.js game beyond adding a harmless `.name` for the exporter, or leave stray files. Scratch goes in the OS temp folder.
