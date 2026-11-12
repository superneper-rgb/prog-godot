# PROG on Godot: rules for anyone working in this folder

PROG is made in **Godot 4.7.2 (GDScript, Forward+, Windows .exe)**. The port from three.js is finished (user, 2026-11-10): this is now the game, and anything in it can change: tuning, logic, looks, levels, content. The three.js game in `../progalpha-20261016T082732Z-1-001/progalpha/` is history. Read it when its code explains why something here is the way it is, but it no longer decides anything, and no work goes there. `PORT_STATUS.md` is the record of the port.

Engine: `F:/godot/Godot_v4.7.2-stable_win64_console.exe` (console build, prints errors). Do not write Godot 3 syntax (`yield`, `onready var`, `export var`, `.connect("sig", obj, "fn")`, `KinematicBody`, `Spatial`). Check an API with the running engine rather than from memory when unsure (`ClassDB`, `get_method_list()`, or a peek eval).

## Code and content
- **Changes are welcome.** Improve tuning, rework logic, raise the quality of a level, add content. When you change something that came from the port, say what and why in its comment. The old comments explaining why something is the way it is are still worth reading before you change it.
- **Big content calls are the user's.** The universe, characters and tone belong to the user: a new level, enemy or weapon, a rename or a re-theme is proposed first, not done unasked. Spell the canon names as written: FOINT, GOINT, Schleed, SERN.
- **Static typing everywhere** (`var x := 0.0`, `func f(a: float) -> int`): it catches errors at parse time and runs faster. Inner classes rather than loose Dictionaries for structured state. `snake_case` names.
- One-line `##` header on every script saying what it is, in plain words.
- **Prog V3** (`player/prog3_animator.gd`, `assets/prog3/`): his model and moves are authored here, not the JS animator.
- **FORGE** (`forge/`, F8 in a level) is the in-game level editor. A level is its export plus `assets/levels/<id>/edits.json`, which only Forge writes and the exporter never touches. What is saved there ships. Forge edits the level piece by piece through `pieces.json` (stable ids by JS scene path; `tools/check.mjs` flags an edit whose piece a re-export lost). Every edit goes through one op path (`ForgeLayer.apply`) so undo, redo and a future co-op editor share it.

## Architecture
- **Coordinates:** right-handed, Y up, metres, yaw 0 looks along +Z, `sin(yaw), cos(yaw)` is forward, `node.rotation.y = yaw`. glTF imports with no conversion.
- **One frame, in one order.** `Game._process` (core/game.gd) runs the whole frame with variable `dt` (capped at 0.05): input, level, combat, player (its own 1/90 s sub-steps), vehicles, camera rig, animator, FX, HUD. Gameplay never uses `_physics_process`. The physics engine is the collision database plus debris.
- **Pure simulation vs view.** `Player`, `CameraRig`, combat and AI are `RefCounted` simulation classes. Nodes are their views. Views read the simulation; the simulation pushes `events` the views consume.
- **Collision is `World`** (core/world.gd): `add()/box()/add_mesh()`, `ground_height`, `blocked`, `ceiling`, `surface_in`, `point_solid`, `ray_clear`, answered natively by Jolt. Never loop over solids per frame. Moving solid: `s.place()` / `s.set_span()` / `s.set_off()`.
- **A level is a `Level` node** (levels/level.gd), registered in `Game.LEVELS`. Everything it makes goes under that node: leaving frees the node and disposes its World, and that is the whole unload. No monkey patches and no global state left behind. A `Config` value a level changes is restored automatically. Timers, tweens and sounds belong to nodes under the level.
- **Shared things live for the session** (autoload `Game`, its player, rig, combat, FX pools, HUD); **level things die with the level.**
- **Autoloads:** `Config` (tuning), `Inp` (input: `Inp.move`, `Inp.look_yaw`, `Inp.btn(&"jump").pressed`), `Game`, `Peek` (dev port). Add one only when something truly is global.

## Assets
- `assets/` started as a mirror of the JS game's `assets/` folder (same relative paths); new assets go wherever they fit. Real files only, **never base64 or text-encoded binaries** in source.
- Godot cannot play `.m4a` or `.mp4` (no ffmpeg on this machine): `.m4a` becomes `.wav` next to where it was, decoded by the browser. There is no texture size cap in Godot: keep a model's full-resolution maps (normal, roughness, etc. included) and let Godot's import compress them. The old three.js 512 px character rule is retired.
- This project is its own git repo at `F:\prog-godot` (github.com/superneper-rgb/prog-godot, big files in Git LFS). The copy inside `progectalp2/prog-godot` is old: work here. `.godot/` is a real, git-ignored folder here. Scratch data goes in `F:\prog-godot-cache`, never on C: (nearly full).
- **Importing:** run `node tools/import.mjs` after adding assets. It takes a lock, so never call `--import` directly while others may be working.
- **Level geometry came from the three.js game.** `tools/export/export.mjs` boots the real three.js game, enters a level and writes what it built to `assets/levels/<id>/` (scene.glb, colliders.json, level.json, instances.bin, pieces.json for FORGE, shaders/*.json work list), with textures in `assets/levels/_tex/`. `levels/exported_level.gd` builds a playable level from those files. `assets/levels` is a real folder and **in git** (LFS), so a fresh checkout already has every level; `F:/prog-godot-levels` is the old, no longer used copy. The exporter reads the JS game from `progectalp2` (or `PROG_JS_ROOT`). Re-export everything: `node tools/export/export.mjs all`, then `node tools/import.mjs`. One level: `node tools/export/export.mjs level <id>`. A level's moving parts are found by their JS `.name` (`ExportedLevel.node_named`): to separate something new, add a `.name` in the JS and export again. A re-export overwrites that level's exported files, so improve a level here (in its Godot scripts, its own assets, or through Forge), and never re-export a level without the user's go-ahead.
- **Packing the .exe:** the level files are read through `res://assets/levels/...` only, never an F: path. The GLBs and textures pack through their imported resources; the export preset must also carry `assets/levels/*/level.json, colliders.json, city_life.json, life.json, *.bin` and `assets/suits/*.json` in its non-resource include filter (`probes.json` and `shaders/` are dev data).

## Performance
The JS game was CPU-bound on draw calls and scene walks. GDScript is slower than V8 per statement, so put work in native calls:
- No per-object meshes for repeated props: MultiMesh, or merge per material. Share materials.
- No hot script loops over big arrays: use PackedArrays and engine calls. Crowds animate in vertex shaders on MultiMesh.
- Skeletons: player characters, bosses and live-posed enemies only.
- Create materials and shaders at level load, never mid-play; warm pipelines at load.
- Pools for bullets, sparks and decals. Never allocate per shot if a pool can do it.

## Look and UI
- Target look (user, 2026-11-10): a modern 3D game at AAA quality: real material response, depth, wet surfaces, detail that holds up close. Strong stylised palettes, as in Ratchet & Clank and Jak. Reference art (e.g. Batman Beyond's painted backgrounds for FOINT CITY) sets palette and shape language, never the rendering: never flat or cel-shaded because a reference is. The three.js build is the floor, not the target: beat it.
- **Frame rate and lighting (user, 2026-11-11).** Never below 60 fps on a GTX 1660 Ti, not even in a dip (more is welcome), and ideally not on weaker hardware either. Lighting at the level of 2005-2010 games (Xbox 360, PC of that time), never more: the art style (PS2-era Ratchet) comes first. Use whatever modern method gets there cheapest; don't copy old methods for their own sake. FOINT CITY stays on its painted light. Moving it onto Godot's full live lighting (every lamp a light, SSR, SSIL, reflection probes) was tried and rolled back the same day: it lost the art style and the cars' look and ran at 33-45 fps at 1080p.
- **FOINT CITY is Neo-Gotham (Batman Beyond), read as 60 / 30 / 10:** 60% the near-black violet mass of buildings, road and structure; 30% the sky, the haze and the wet ground carrying it; 10% light. A skyscraper burns with dense runs of cyan and blue-white strip windows; red beacons on the tops; amber is the exception (FOINT's own signage, the odd window). Street and Deck lamps lean violet- or red-white by area (user, 2026-11-04). Tops, trim and roof plant stay in the mass's values, never lighter. The Batman Beyond reference frames (`F:/prog-godot-cache/neo_gotham_references.zip`) are the judge: where the city and they disagree, change the city, and this line with it; no colour rule here or in an old comment outranks them. This palette rule is FOINT CITY's only: other levels keep their own palettes. The AAA bar above is for everything.
- Overlays, terminals and minigames use the **Phosphor CRT style**: green CRT inside the SchleedTech monitor frame (`assets/ui/`), amber for danger, 90s Alien grit.
- **Diegetic cues, no HUD timers.** Comms stay lean: only significant lines.
- All NPC talk goes through one shared dialogue system; all level doors through one shared portal system. Never a one-off copy.

## Testing (do this, never ask the user to check by hand)
- **Match the testing to the size of the change.** Small fix (one function, a value, a typo, a comment, a rule or doc edit, nothing you can see or play): run `node tools/check.mjs --quick` and stop. No game launch, no screenshots. Behaviour change in code that runs in play: also drive it once with the peek. Visible change (look, pose, UI, shader) or a new feature or package: the full routine below. When unsure which it is, take the lighter one and say what you did not test.
- Keep one game open and drive it: `node tools/peek.mjs start [level]`, `eval "<gdscript body>"`, `run file.gd`, `shot [width]`, `frames n`, `logs`, `restart`, `quit`. Several workers at once: give each its own `PEEK_PORT` environment variable. The window sits off screen, so it never bothers the user.
- `node tools/check.mjs` compiles every script and runs the project rules. It must print `all checks passed` before you call work done. New project-wide checks go in it, never a separate script.
- **Screenshots are never kept in the project:** temp folder only, look once, move on.
- Bot input for tests: `Inp.bot_on = true`, `Inp.bot_move`, `Inp.bot_held[&"jump"] = true`, `Inp.bot_look`.
- Passing a check does not mean it looks right: look at the picture.

## Never
- Commit or push (the user commits), edit the three.js game beyond adding a harmless `.name` for the exporter, re-export a level unasked, or leave stray files. Scratch goes in the OS temp folder.
