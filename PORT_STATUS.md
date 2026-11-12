# Port status

Source: `../progalpha-20261016T082732Z-1-001/progalpha/` (three.js, read only). Target: this folder. Update this file when a piece lands or a decision is made. Keep it short: the story of how something was fixed goes in `docs/port_log.md`, numbers and tables in `docs/measurements.md`.

## Where it stands (as of 2026-11-08)

Everything on the original list is ported and every level in scope boots at about 120 fps with no script errors. **Nothing has been hand-played and no sound has been heard: all of it was checked by script and by picture.**

Working: movement, camera, combat and all guns, Robot and Drone AI and views, animation for Prog and Tommy, armor, sound and FX, HUD, wheel, menus, console, render look, save, shared dialogue and doors, shops, powers, cutscenes, the main-menu backdrop, hub life and driving, the kit levels, and these levels with their logic: club, apartment, worldbackalley, kame-lab, foint-dome (FOINT DOME), warehouse, spire, mothership, visiting-hours, omnisphere, dev, blockout-demo.

## Decisions from the user (these override the JS)

- **Out, do not port:** Blood Gulch, Reality Slip, Ship Combat, the jetpack-yard and parkour-yard test levels (the kit's jetpack stays), and the Bagman enemy. Skip those branches when you meet them in the JS. Player clones and vehicles stay (the dev console and the hub use them).
- **Dead Air removed (2026-11-07):** no `dead-air` level, `Game.LEVELS` entry, menu line or look. Kept: the Boss's briefing in the hub and the alley grate (an X action in `hub_level.gd`). The old level is archived in `_archive/dead-air-old/` beside prog-godot. `levels/_kit/crawl.gd` and `gear/night_vision.gd` stay. `ventDone` is never set now.
- **Windows .exe postponed (2026-11-06):** the game runs from the project. When it comes back: export templates on F: (1 GB) and `F:\prog-builds`.
- **Lighting (2026-11-05):** baked lighting is ported as it is. The warehouse gets a simple carry-over on the shared lights (no light volume, no extra fidelity) because the user will rework it.
- **Frug showdown (2026-11-06):** the JS bug (his head and spine spin because `turn()` adds up every frame) is not copied. His head stays upright.
- **Prog (2026-11-07):** V1 is the look and feel to keep, V3 is parked. V3's animation is new on purpose (port law exception). V1 gun holds (`B.skin_fix` only) deliberately differ from the JS. Prog V2 stays the default; V3 is bench only, details in the log.
- **Night Assassin and Dirgeworm** are in but dev-only; the user may still cut them.
- **Balcony call** is not ported on purpose: the JS cannot play it either (the hub has no apartment).

## Not done

1. Nothing hand-played, no sound listened to, in any level. This is the next step and it needs the user.
2. `node tools/check.mjs` (full) fails its boot step on Godot exit-time leaks (about 800 objects, 170 resources, at a bare `--quit`). `--quick` passes. Cause unknown.
3. Console: `mode`, `perf`, `levelcycle`, `npc`, `npcs` still say they are not ported.
4. Enemies: no normal maps on creature skin; the JS side-by-side look check was only done for the alien. goint_suit, goint_undertaker and goint_warden were added with VISITING HOURS.
5. Known gaps per level (details in `docs/port_log.md`):
   - **warehouse:** roof door grind minigame (door just opens), purge arcs and sparks, Foreman and factory sound cues, drum stencils, machine screens, exterior rain and skyline, roaming work lights, arrival clip plane, Enforcer and mech tint.
   - **spire:** garden lock lamp surfaces, socket chamber ganglia pulse, letterbox bars a little thick.
   - **mothership:** cardboard cut-out uses Prog's paint for Tommy, lowrider wheels do not spin, MC keeps idle pose, saucer glow does not pulse, steam is additive.
   - **visiting-hours:** floor light pools do not dim in lockdown, prison lamp glows drawn from inside.
   - **omnisphere:** pilot seat in the lifter is empty, conduit rope coil appears whole, `envMap` reflections dropped.
   - **hub:** saucer pilots are flat models, siren uses one fixed length, car lamps are glow sprites; B-9 office lacks Shit-chan's finger curl and blink.
   - **kit:** the floating label has a plain plate (the JS has a bright frame).
   - **Prog V3:** no suits (so no Phantom Suit in VISITING HOURS), cutscenes still V2, no hair sway, face or power casts.
6. Reported by the user, not reproduced: clicking Meat Spire in the level list closed the game once (logs are kept in `%APPDATA%/Godot/app_userdata/PROG/logs`); glitching through the Meat Spire; the Visiting Hours tunnel water animating poorly.

## Traps

- A peek started without `--level=` boots through the menu and reads and writes the user's real save (`%APPDATA%/Godot/app_userdata/PROG`): give it its own APPDATA. Save slots are 1-based.
- `Inp.bot_move` forward is +Z at yaw 0.
- Never keep an AudioServer bus index across frames (a level's audio node removes its buses in `_exit_tree`, after the next level built its own).
- Changing a `*_enabled` feature on a patched StandardMaterial3D rebuilds its shader and drops the patch.
- `CityDriving.request()` in the first ~30 frames after entering the hub can make nothing.
- A named light in the export also leaves an empty node of the same name: filter for Light3D. JS level files may have CRLF line endings.
- Level moving parts: add a `.name` to the part in the JS, export the level again, find it with `node_named` in the level's script (`levels/club/club_level.gd` is the example).

## Where things are

- `docs/port_log.md`: what landed, bug hunts and root causes, per-level notes, the old wave roadmap.
- `docs/measurements.md`: golden-replay and sound numbers, JS-to-Godot piece table, gun parts the exporter keeps, exported-level table, picture measurements and GPU costs, shader work list.
