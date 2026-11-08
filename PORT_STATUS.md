# Port status

Source: `../progalpha-20261016T082732Z-1-001/progalpha/` (three.js, read only). Target: this folder. Update this file when a piece lands.

## Where it stands (update this first)

**As of 2026-11-06 everything on the list is ported and all 15 levels boot at 120 fps with no script errors. Nothing has been hand-played and no sound has been heard: all of it was checked by script and by picture.** What is open is at "Not done" below.

Working in the game: movement, camera, combat and all guns, Robot and Drone AI and views, animation for Prog and Tommy, armor, sound and FX, HUD, wheel, menus, console, render look.

Bug hunt against the JS, 2026-11-08 (bot smoke tests of movement, guns, enemies, doors, dialogue, shops, cars, pause, wheel, death, save; a tour of every level and a hop from each level back to the hub, reading the log after each). Fixed:
- A level left half way (a door, the level list, dying in a set piece) left its patches on the shared session objects: OMNISPHERE's freefall pose hook stayed on the animator and its aim override on Combat, so from then on Prog stood with his arms up, no gun in hand and the aim point frozen, in every level. The JS had `takeSharedSnapshots` / `restoreShared`; now `Game.take_shared_snapshots()` (first entry) and `Game.restore_shared()` (every `leave_level`): Callable / null / bool fields of Combat and Enemies, the plain fields of Player (god kept), `animator.pose_hook`, `hud.hide_xhair`, `Inp.orbit_btn` / `capture_blocked`, `time_scale`, `input_dead`, `arena_blocked`, `overlay`. `leave_level` also exits a driven car (JS enterLevel).
- `audio/city_sound.gd` read a bus by its index every frame; a level's audio node removes its buses in `_exit_tree`, after the next level has built its own (queue_free is deferred), so coming to the hub from OMNISPHERE hit "Index p_effect = 1 is out of bounds" every frame. Effects are kept as references now. Rule: never keep an AudioServer bus index across frames.
- `Game.DEFAULT_LEVEL` was "arena", the movement test ground: a new game, CONTINUE with nothing saved and the world behind the main menu all started there. The JS starts in the hub (START_LEVEL); so does the port now. Menu boot takes about 20 s.
Checked and the same as the JS (not bugs): the Config numbers (131 keys identical); the golden replay (body 0.133 m worst; the camera's 5.4 m is the boom collapsing 8 frames earlier at a tunnel mouth); robots idle until hit (`ai_notice_range` 0); fists punch on fire, not attack; the "No controller" pill always showing; arriving in the hub unarmed after a level that ended with no gun equipped (`gear.equip` null); the SPIRE "nothing exported as Spm*_body / SpbHorn*" warnings (the JS has no body on 4 of 5 arena lock walls either, and bakes 8 of 9 horns), so they are noise.
Test traps: a peek started without `--level=` boots through the menu and reads and writes the user's real save (`%APPDATA%/Godot/app_userdata/PROG`): give it its own APPDATA. `Inp.bot_move` forward is +Z at yaw 0. The hub peek on 9241 once quit cleanly between two runs with nothing in its log; not explained.

**VISITING HOURS spawn bug (user report, 2026-11-08): a floating camera and an invisible Prog instead of the storm drive.** Root cause in the user's log: `Vehicles._apply_pose` on a 'previously freed' node every frame. The hub's drivable cars are vehicles of the shared controller with their nodes under the hub level; the JS hub is resident and `enterLevel` parks them with `setOwnerActive('hub', false)`, but the port frees the hub, so a car taken in the hub (E on a parked one, RETURN TO MENU, LOAD a save in VISITING HOURS) left a `Veh` pointing at freed nodes. The pose loop aborted on it before reaching the rental, so the rental's sim (and the chase camera) drove off while its model and the seated Prog stayed at the spawn. Fixes: `HubLevel.on_exit` -> `CityDriving.release_all()` removes the hub's vehicles while their nodes and World still exist (`_exit_tree` is too late: the next level has already spawned its car), and `Vehicles.update` drops any vehicle whose root is gone with a warning (Godot only; the JS has no freed nodes). Verified on peeks: hub car held -> VISITING HOURS, and menu CONTINUE on a copy of the user's save: 1 vehicle, no dead roots, model within 0.2 m of the sim, camera 8.4 m behind, no errors. Second bug found on the way: `CityDriving.detach()` ran at the hub's deferred `_exit_tree` and erased every hub car type from `Vehicles.SPECS`, including the ones the next hub (RETURN TO MENU, any hub -> hub) had just registered, so no city car could be taken again (`spawn` returned null). `detach()` now erases only the specs this instance registered (`is_same`) and runs from `release_all()` at `on_exit`. Verified: NEW GAME hub -> E on a parked car -> RETURN TO MENU -> LOAD a VISITING HOURS save: the hub's car is released, the rental drives, no errors. Trap: `CityDriving.request()` in the first frames after entering the hub can make nothing; wait ~30 frames first. Save slots are 1-based: `fresh(0)` writes slot.0.json but does not select it.

Done and tested with bot input:
- `core/dialogue.gd`, `ui/dialog_box.gd`: the shared dialogue (X, skip, camera, letterbox). `core/doors.gd`: level doors, world actions, what X acts on, the fade between levels. Tested: the hub's Club 9 door both ways, a full conversation. The hub's talkers and doors are in `levels/hub/hub_level.gd`.
- `levels/shader_ports.gd`, `levels/shaders/`: the hand ports of the three.js shaders. A surface finds its port by the name and variant in its material's extras. `tools/export/port_shader.mjs` drafts a port from a level's work list (read the result: it is a draft). Per-point data: `ShaderPorts.FIELDS` (MultiMesh) or `EXPANDED` (one mesh, attributes in CUSTOM0..). Small onBeforeCompile hooks: `ShaderPorts._hook`, patched into Godot's own generated shader by `core/material_look.gd`.
- `levels/_kit/blockout.gd`, `blockout_hud.gd`, `kit_level.gd`: stages, objectives, checkpoints, guidance, HUD, death and respawn, boss bar. Tested on `blockout-demo`. A kit level subclasses KitLevel, returns its options from kit_options() and describes its flow in setup().

Hub life (levels/city_life.gd, levels/hub/): the data comes from `node tools/export/export.mjs life` (about a minute; also part of `level hub`): `city_life.json` (every street sprite with its job, what moves) and `life.json` + `life.bin` (lane graph, the cars and people as built, the townsfolk's geometry with the attributes glTF cannot carry, the talkers' rigs). CityView.update's sprites, signal lenses, sky traffic and folk poses all run in shaders on one clock uniform. Traffic rules checked against the JS over 8 simulated minutes: junctions entered 932 / 951, signal waits 43246 / 43178, none off lane. Back Alley gets its neon and steam when it is next exported (until then it has no city_life.json and keeps what it had).

Levels with logic so far:
- `club` (levels/club/): the whole show, side by side with the JS it is nearly identical. Music on.
- `apartment` (levels/apartment/): complete: the door, bed, rain, TV, closet terminal, roaches, room sounds, a real mirror, the wake-up cutscene (`apt_wakeup.gd`, `cutscenes/hand_pose.gd`, `phone_voice.gd`; the photo is printed from real models in a SubViewport).
- `worldbackalley` (levels/worldbackalley/): complete: the flow with real gray aliens and the storm, intro, outro, subtitles, cigarettes, the corpse heap and moving set pieces (`alley_*.gd`).
- `kame-lab` (levels/kame_lab/): `kamehameha.gd`, `kame_lab_level.gd`; particles computed in the shader (`cutscenes/cine_puffs`).
- `blockout-demo`: complete.

Pattern for a level's moving parts: add a `.name` to the part in the JS, export the level again, find it with node_named in the level's script (levels/club/club_level.gd is the example). A named light also leaves an empty node of the same name: filter for Light3D. JS level files may have CRLF line endings.

Enemies ported, each spawned and fought live with no script errors: gray alien, Tommy-Gun Gray, Button Man, Probe Butler, Consigliere, Gristle Brute, Muscle, Sinew Crawler, Blister Bloat, Wall Wretch, Maw Ledge, Maw Nest, Flayed Prophet, Follower, Marrow Warden, FOINT Goon (security pistol and SMG, hazmat, labcoat, GOINT guard, GOINT adjuster). Looks checked by eye in the port; the JS side-by-side has only been done for the alien, so colours of the flesh creatures still want one comparison.
How a creature is made: `tools/export/enemy_family.expr.js` names the JS view's moving parts `J_<name>` and hands wetSkin's rim and glow over as a material name (`wet_<hex>_<percent>_<source>`, `glow_<source>`); run it with `node tools/export/export.mjs object "$(grep -v '^//' tools/export/enemy_family.expr.js | sed s/__KIND__/<kind>/)" <glb name> --level=worldbackalley`. `enemies/creature_model.gd` turns the GLB into one RigidBatch, `enemies/creature_view.gd` is the base of a view, `enemies/anim_kit.gd` is JS anim-kit, `enemies/fx_beam.gd` holds the world-space extras (lasers, rings, puddles, floor cracks). A new kind also goes in `Game._kind_script` and `EnemyViews.add_for`.
Known gaps in those enemies: no normal maps on creature skin, the Wall Wretch's wall slab (dev spawns only), level props the kinds expect (zones, cling, surface_at) are set by the levels when they are ported.

Also new: `levels/city_life.gd` (the camera's fill light, sky, rain, lamps on the hub and Back Alley), `levels/worldbackalley/storm.gd` (lightning, thunder, gusts, splashes), `audio/city_ambience.gd` (traffic, rain, shop and club music through the wall).

Night Assassin and Dirgeworm are in (`enemies/night_assassin*.gd`, `phoniworm*.gd`; models `tools/export/enemy_assassin.expr.js`, `enemy_worm.expr.js` with `--level=dev`; spawn kinds `assassin`, `worm`). Dev-only: the user may still cut them.

The FOINT Goon is the one live-posed skinned enemy: `enemies/foint_goon.gd` (AI), `foint_goon_view.gd` (own FK and IK per goon, the pose handed to a Skeleton3D at the end of the frame, one shared re-weighted ArrayMesh per body), `foint_goon_face.gd`, `foint_goon_dress.gd` (GOINT dye in `goon_recolour.gdshader`; pieces and guns exported by `tools/export/goon_gear.expr.js`, run per piece as gun_pistol, gun_smg, gun_acid, dress_goint_guard, dress_goint_adjuster). goint_suit, goint_undertaker and goint_warden (VISITING HOURS people) are not exported yet: add them with that level. Maintenance Spider: `enemies/maintenance_spider.gd`, `maintenance_spider_view.gd`, model `assets/objects/enemy_spider.glb` from enemy_family.expr.js.

FOINT ARENA (`levels/maktar/`): played end to end: menu on the giant screen, camera flight, gates, rounds, spawning from the bullpens, prize and save, moving colliders, fans, moat, lightning (a vertex shader in place of the JS morph targets), commentary, crowd bed, gate motors, music. Compared with the JS by picture. Audio not listened to. The screen's GUNS & AMMO button says the armory is closed until the shops are ported.

WAREHOUSE (`levels/warehouse/`): runs: all ten rooms by checkpoint, waves through the shutters, navigation graph, consoles, drives, gates, boards, set pieces, the Compactor, the Foreman (moves, phases, lockdown, floor telegraphs), checklist HUD, comms, alarm theme, route arrows. `wh_data.gd` is generated from the JS tables by `tools/export/warehouse-data.mjs`; moving parts are found by the `Wh*` / `Fm*` names added to the JS. Played by bot only (god mode, enemies fought by script): not yet played through by hand from roof to van. Known gaps, all in this level:
- The roof door's grind minigame (`minigames/grind`, 110 KB, and `levels/_kit/minigame-door.js`): the panel opens the door straight away for now.
- Purge lane arcs and sparks, the eye's hit arcs (`foreman-electricity.js`, `foreman-eye-hit.js`): the lanes light up without them.
- Foreman and factory sound cues (`foreman-audio.js`, `factory-audio.js`, room tone): silent until `boss_cue` has them. Audio not listened to.
- Drum stencil lettering; signs on the pads and tug; the machine status screens (`machine-theatre.js` screens); the exterior's rain, water and skyline update (`exterior.js`); the five roaming work lights (the exported lights stay where they are: the user will rework this level's lighting anyway).
- The arrival's clip plane at the shutter is left out: the dark threshold panel hides the walk-out the same way.
- Enforcer and mech colour tint (needs a tint on RobotView).

DEAD AIR: **level removed 2026-11-07 by the user's decision** (a new experience will be built). There is no `dead-air` level, entry in `Game.LEVELS`, menu line or look. Kept: the Boss's briefing in the hub (boss intro, `ventJob`) and the alley grate, now an X action in `hub_level.gd` that plays the VentGrate cards and fades back to the alley. The old level (all `da_*` scripts, shaders, world export) is archived in `_archive/dead-air-old/` beside prog-godot. `levels/_kit/crawl.gd` and `gear/night_vision.gd` stay. `ventDone` is never set now.
- The kit's floating label has a plain plate, the JS has a bright frame (all kit levels).

MEAT SPIRE (`levels/spire/`): the climb's systems and the whole Mawmother fight run by script: every room by checkpoint, movers and their carry (measured riding the elevator tick: the player's height matches the platform's to 0.01 m), arena locks, eggs, eyes, secrets, checkpoints and the safety net, the fight through its phases, her entrance cutscene. Compared with the JS by picture (foot, flank, her roar, the fight's layout). Not played by hand from foot to crown, audio not listened to. The JS layout comes from a seeded random sequence that mesh building also draws on, so nothing is laid out again here: each mover keeps its numbers (`m.spec`, level.json `data.movers`), mechs' solids carry id `mech` and are rebuilt from the spec, parts are named `Spm<index>_<part>`, `Spb*` for her. Parts: `spire_level.gd` (systems + rooms.js closures), `spire_mechs.gd` (the mover system, reusable), `spire_boss.gd` (fight), `spire_boss_view.gd` (pose), `spire_arena_intro.gd` (cutscene), `spire_flesh.gd` (flesh, wet skin, bile, spores and drips), `spire_hud.gd`, `spire_ambience.gd`. The exporter now carries the flesh attribute as UV and UV2, and reads a level's `allSolids` when it culls `world.solids`. Trap: changing a *_enabled feature on a patched StandardMaterial3D rebuilds its shader and drops the patch. Known gaps:
- Garden lock's "the lamps die": fog, carried light and glow lamps go dark; the lamp surfaces themselves do not change colour.
- The socket chamber's ganglia do not pulse.
- Cutscene letterbox bars are a little thicker than the JS.

THE MOTHERSHIP (`levels/mothership/`): all fourteen stages run by checkpoint and script, with no errors: the disguise and the receiving line's remarks, the wedding crowd (the export's instanced meshes, moved here), the band reading the song's beat map with its record scratch, the light show and LED wall, the toast into the brawl (mask flies, guests scatter, gear from the cake), entrances through doors and ceiling hatches, tractor beams (lift, rail, carry and abduction, ridden by bot), the laundry vents, the kitchen vats, the casino's crossing rails and turning roulette floor, the lounge reels, the conservatory, the gallery, the chapel, the climb, the Godmother through all three phases (forced by respect), the truce cutscene and the saucer home. The hall, laundry and boss room were compared with the JS pictures. Its talking NPCs come from a new export file, `rigs.json` + `rigs.bin` (a level's `rigPrefix`), built by HubNpcs. Not hand-played; audio not listened to. Small gaps: the cardboard cut-out shows Prog's paint for Tommy too; the lowrider's wheels do not spin; the MC keeps his idle pose when the cover blows; the saucer's belly glow does not pulse; steam puffs are additive (normal blend in the JS); the mask has not been looked at on Tommy. The counting room has its caged bookkeeper and no bagmen (Bagman is cut). Abduction beams do not lift you off the floor, in the JS too (their 20 m/s² is less than gravity): kept.

Fixed on the way: `enemies/fx_beam.gdshader` wrote POSITION on one path only, which in Godot hides everything on the others: every additive tube and shield of the gray family's views was invisible until now.

VISITING HOURS (`levels/visiting_hours/`): every stage runs by checkpoint and script, with no script errors: the drive (the rental on the shared `vehicles/` core, headlights, tower four catching lit headlights and sending you back), thermos, kit bag, the goggles on the scope (rangefinder finds Fenn's window), the zipline, searchlights and patrol car catching you in the field, the pipe crawl with the tunnel camera, Dale's takedown, the CCTV console (green feed, CAM 08 finds Fenn), the live monitor wall (eight small viewports pasted into one atlas; each floor sits on its own render layer so a feed can draw a floor the player's camera does not), door board, radio check and lockdown, the squads through Stair A, the service lift, the warden's floor, the jammer, and the whole finale to LEVEL COMPLETE (also skipped). 13 checkpoints compared with the JS picture side by side: near identical. The painted finish (world-space photo detail, grade, grime, cool edge, furniture cutaway, reeds in the wind) is ported in `ShaderPorts._vh_restyle`. Fenn, the warden and the undertakers' suits are new exports (`goon_dress_goint_suit`, `_undertaker`, `_warden`).
- Not hand-played. Sound runs on the right cues but has not been listened to. Performance looked fine in the checkpoint tour (mostly 100 to 120 fps, one dip to about 50) but was not measured in a real play-through.
- Not ported: the light pools painted on the floors do not dim in the lockdown (`poolM.opacity`); the prison's lamp glows stay drawn from inside the block (JS hides them for speed).
- JS bug fixed rather than copied: starting the finale from its checkpoint measured the line of fire from a body never yet posed, so the round and the window shots landed about 50 m off. `pose_fenn()` poses him first. In a normal run the JS is right, and this matches it.
- The three.js game gained more than `.name`s here: `vhId` tags on some solids, and `level.vh` / `admin` / `dress` returning extra data (road points, wall lines, stair bounds, flicker info) for the exporter. No effect on how it plays. `tools/export/page.js` now bakes an atlas pick (`aCard`) into the UVs.

OMNISPHERE (`levels/omnisphere/`, `levels/_kit/jetpack.gd`): the whole level runs from the opening drop to home, by checkpoint and script, with no script errors in the real log across all 44 checkpoints. Checked one by one: the freefall (Tug 9, the fall line, hornets / wasps / mule / gunship / SAMs / flak, reticle and soft lock, landing), the dockhand, the yard and bridge waves, the Draw, pylon 4, the tram's whole loop to the crash, the shift room and gate, the Assembly Line (presses, haywire), the docks gunship, the bridge lock, the cuffs and belt, Juniper's full breakout (his own rig: IK legs, the haul, the face), the climb, the conduit and the catch, the lift, the ring, the emitters, the jump, the fly-off and the fireball. Heavies have their AI, their black and silver look and plating. The jetpack has its pack, plume, trail and rings. Pictures compared with the JS at the checkpoints that matter.
- Not hand-played. Sound runs on the right cues but has not been listened to. Not measured in a real play-through; the checkpoint tour ran at 65 to 120 fps.
- Not ported: the pilot sitting in the lifter's seat (the name is right, the seat is empty); the conduit's rope coil appears whole half way through the wrap instead of being drawn on; bracket and ring reflections of `envMap` (dropped by the exporter).
- Puffs (`om_puffs.gd`) fly in the vertex shader from one write per emit, so the drop's 1400 puffs cost no script loop. The cloud deck is not sorted far to near, as the JS does: its soft edges hide it.
- The three.js game gained names and `vhId`s on its moving parts, `level.omni_data` (paths sampled at equal arc length, the Draw's decks and lamps), and `window.__expBoot` branches that make hidden template bodies for the exporter and give it Juniper's seated hoses without the sculpt. `__expBoot` is only set by `tools/export/export.mjs`, so nothing changes when the game runs.

DEV level (`levels/dev/`): the F2 sandbox works: all five tools, shapes and props with their colliders, enemies, weapons, NPCs from the manifest, ghost, selection, mid-air placing, drag modes, save and load (`user://dev_layout.json`). Tested by script and synthetic input, not hand-played.
- In too: the VENDORS tab (`props/arms_depot.gd`, `assets/objects/depot_*.glb`, export with `--level=dev --tm=none`), the mirror (JS `.name` DevMirror), the implant machine, the full NPC catalogue (`levels/dev/dev_npcs.gd`, `npcs/pale_punk.gd`), the procedural idle and walk on The Boss and Shit-chan. PROG V2 is left out of the catalogue until Prog is allowed in. Picking uses each object's oriented box instead of its mesh.

Minigame door + RAILJACK (`levels/_kit/minigame_door.gd`, `minigames/grind/`, `minigames/shared/crt_kit.gd`): the door, the terminal with its live screen, the prompt and the whole minigame. Routes come out number for number the same as the JS (gate, rails, obstacles, bits, same seeds). Tested in the running game by the JS's own autopilot: a full clear at the hardest ICE, an abort, a lockout, the door's opening and collision, the return to the panel, at OMNISPHERE's CONTAINMENT 01 and the warehouse roof. The sounds are baked out of the JS synth (`assets/sfx/grind/fx/*.wav`), not heard yet. The ASCII re-read is one shader pass, not a pixel read-back. Not hand-played.

Shops (`ui/shop/`): the gun counter, the Goint fitting bay and the four arms depots, in their machines' art with the coloured CRT, the neon breathing, the glitch, the 3D preview (guns, the real Prog and Tommy in the suit), the carousel, prices, buying, ammo, max-out, equip, fitting, prompts by device, mouse and keyboard and pad. Same measures as the CSS. Tested by real key input at the hub clerk and OMNISPHERE's pods, against JS pictures. As in the JS, at 1080p the gun shop's info column is taller than its panel, so its buttons and purchase message sit below the fold (the JS shows a scrollbar there: 490 px of content in 275): keys still work. Not hand-played.
- The DORBATELEPHINIUM implant machine (`ui/shop/plasmid_shop.gd`): its art has its screen cut out by `tools/export/render-ui-cut.mjs` (JS: at load). The scan-in is a screen reveal, not a clip plane.

Hub driving and street sound (`levels/hub/city_driving.gd`, `city_traffic.gd`, `city_drivers.gd`, `audio/city_sound.gd`): every street car and parked car can be taken: E beside a parked one and you get in; E beside a moving one and it pulls over, its driver climbs out through the real door and you take the seat. Left alone a car goes back to the lanes or stays parked. Ramming, a bullet or a blast turns a street car into a vehicle on the spot, and its driver bails out and runs. Tested by script in the running game: parked, moving, ram, shot, bail-out, getting out. Models per type: `assets/objects/car_<kind>.glb` (`tools/export/city_car.expr.js`), numbers in life.json. Street sound: engines of the three nearest cars, horns, signal ticks, steam, the dome's crowd, a siren: JS voices baked to `assets/sfx/city/`, levels running. Not heard.
- Differences: the saucers' pilots step out as flat models and vanish after 1.6 s (the alien views' waddle is not there); a siren uses one fixed roll of its length (the JS rolls 7 to 11 s); a car's lamps are glow sprites.
- `node tools/check.mjs` fails on some boots with "resources still in use at exit" (20 to 53 objects leaked, GDScript objects in the verbose log). No gameplay error comes with it. It first showed before this work and now fails every full check. See "Not done".

B-9 office (`levels/hub/hub_office.gd`, `hub_office_actors.gd`, `office_tv.gdshader`): the push button with the hand reaching it, the scanner arm with its laser fan and stripe, the sliding door and its solid, the exit sensor, the interior drawn only when it can be seen, the room's dimmed sun, hemisphere and fill, the desk monitor, the nineteen televisions on three live CCTV feeds at the JS's rate, the room's music, The Boss and Shit-chan on their own skeletons (bind pose, idle rig, swings, two-bone arms, the coat fix) and Cherub's typing hands. Tested by script in the running game and against a JS picture from the same spot; 120 fps with the feeds on. Cutscene poses (attend, talk, anger, look, hit, dead) and the soft key light are in; the Boss turns to face you when you talk; the Cherub is a live body in his chair. Not here: Shit-chan's stock-hand finger curl and eyelid blink, the haze's fade by distance.

Main menu backdrop (`ui/menu_scene/`, `gear/goggles.gd`, `tools/export/render-menu-assets.mjs`): the rainy yard, Prog in the Phantom Suit with the fitted goggles, towers, searchlight, fence, mist, rain, water beads on him, lightning at its three spots, thunder, the whine and the rain loop, the opening that holds the list back 1.7 s. It has its own world in an HDR viewport, tone mapped by `menu_tone.gdshader`; the game's world is off while it is up. The menu itself is back to the JS look: grey and white text, the gradient, no CRT and no blurred feed; the title image is gone, as the JS has none. Tested by script: the opening, panels, a strike at each spot, going back from a game, Continue into play, 120 fps. Compared with a JS picture at the same size: near identical. Bloom and the wall's bump strength are set by eye. Not heard. Differences: no PRESS ANY BUTTON (only a browser's audio lock needs it); thunder picks from three baked takes per kind; no blur behind the panels (CSS backdrop-filter) and no dark shadow on the menu text.

Powers (`powers/`): Swarm, Incinerate and Frost seen working (cast, charge and release, spray and the ice shell). Goggles in play (`gear/night_vision.gd`, `goggles.gd`): model on the head bone, left arm IK, per character. AI clones (`player/player_clones.gd`, `combat/clone_combat.gd`, console `clone`, `cloneclear`). Foint pods (`props/foint_pod.gd`, `assets/objects/pod_*.glb`). The gunshop clerk is the live Pale Punk with his hit reactions and death fall. Shop TV (`props/crt_tv.gd`, video baked by `tools/export/render-video.mjs`). Mirrors (`props/mirror_view.gd`): a square camera with its near plane on the glass, in place of the JS's oblique clip.

Cutscenes (`cutscenes/`, all on `cutscene.gd`): beat-down (`beatdown.gd`, `saucer_car.gd`, `rap_loop.gd`, loop baked by `tools/export/render-rap-loop.mjs`), boss intro and its alt ending, office shut-up, Shit-chan, Cherub (`fart_synth.gd` renders on a worker thread), implant injection, firefight, Frug showdown, Tommy ascension, vent grate, emotion close-up, the old alley opening (`ui/intro/intro_alley.gd`), console `cutscene list | play` (`ui/console_cutscenes.gd`). Compared frame by frame with the JS: beat-down, boss intro's look, Cherub, shut-up, implant. Firefight was only run in Godot (the JS harness cannot boot it). Frug and Tommy were run by seeking, not to their natural end.
- Balcony call: not ported, on purpose: the JS cannot play it either, the hub has no apartment (`city.aptBox` is never set). The console says so, as the JS does.
- Frug showdown: the JS has a bug: Frug's head and spine spin and fold because the Idle clip does not rewrite those bones, so `turn()` adds up every frame. The port poses what the code asks for, so his head stays upright. The user chose this (2026-11-06): keep it fixed, do not copy the bug.
- MAKTAR's music: `death-lessons.ogg` is Opus, which Godot cannot read, so that level was silent. `tools/export/render-music.mjs` re-encodes it to Vorbis through Blender's `aud`.

Reported by the user, not reproduced: clicking Meat Spire in the level list closed the game once. Tried from a fresh menu, after the Mothership, with dynamic resolution on and as Tommy, all fine, and Windows has no crash record for it. `run/flush_stdout_on_print` and 40 kept logs are on so the next one leaves its last lines in `%APPDATA%/Godot/app_userdata/PROG/logs`.

Reported by the user, not reproduced in scripted play: glitching through the Meat Spire (24 runs into the solid column stayed out; the one bug found was `L.T` in spire_mechs.gd, which froze every mover while hanging from a ledge), and the Mawmother's open mouth not hurting more (measured x2 open, x0.2 shut, as the JS; her damage numbers show the hit before the multiplier, also as the JS). The console key could not be made to fail with injected input: it is now also polled, and one press toggles once.

Third playtest list (2026-11-07). Not reproduced: the Visiting Hours tunnel water animating poorly (same shader and values as the JS, ripples live while crawling, same look from one free camera). Not built: an authored lever-pull clip for Prog at Checkpoint Gamma (no such clip exists on either rig; the JS has none): the handle follows the hold and Prog turns to it. Known: suits are not fitted to Prog V3, so he shows no Phantom Suit in Visiting Hours.

Prog V1 gun holds (user, 2026-11-07: V1 is the look and feel to keep, V3 parked): for `B.skin_fix` only, `_weapon` points the elbows down and out from the body instead of through the JS `_q3` quirk, and `_ik`'s body avoidance swings at most 3 steps. A deliberate difference from the JS. Rifle checked by picture; other guns and reloads not yet.

Rebuilt Prog, bench only (user go-ahead 2026-11-07): `assets/prog3/` (model, 237 authored clips, gun sockets, copied from `../progalpha-20261016T082732Z-1-001/progalpha/blender/prog3/`), `tools/prog3_bench/` (`node tools/prog3_bench/run.mjs check`, or `shots <list.json>`). He is playable as the "Prog V3" costume at the character select (`player/prog3_animator.gd`, `Builds.play_build`, created through `Prog3Animator.create`); Prog V2 stays the default. Clips run from the player's state, the gun rides his hand socket, WeaponView still runs parts, flash and kick. Not his yet: cutscene stand-ins (still V2), cutscene poses, seats and machine work (old Animator code on his bones through pose_hook), suits (he wears none), hair sway, face and blink, power casts, body-aware gun tuning. Ledge, ladder, pole, swim and wall run have only been run by script, not in real geometry. After re-exporting: copy into `assets/prog3/` and run import. His import settings must keep `animation/remove_immutable_tracks=false`. Measured: every clip within 1.71 cm of the file. Planned exception to the port law: his animation is new on purpose, not a port of the JS animator.

Not done:
1. Nothing has been hand-played and no sound has been heard, in any level. That is the next step, and it needs the user.
2. `node tools/check.mjs` (the full one) fails its boot step: about 800 objects and 170 resources stay alive at exit, in Godot's script shutdown. `--quick` passes, no gameplay error comes with it. It happens on a bare `--quit`, before any level loads. Ruled out: `Cutscene`'s and clones' classes built on `Inp.InputView`, the dev vendor table, quitting mid-boot, player clones.
3. Warehouse gaps listed above stay, because the level will be reworked: purge arcs, Foreman and factory audio, stencils, machine screens.
4. Console: `mode`, `perf`, `levelcycle`, `npc`, `npcs` still say they are not ported (`mirror`, `go`, `vehicle`, `cutscene` are in).
5. The small gaps listed per level above.

The Windows .exe is off the list for now (user, 2026-11-06): the game is in alpha and this is an engine port, so it runs from the project.

Rules from the user that override the roadmap below: Blood Gulch, Reality Slip, Ship Combat and the jetpack and parkour test levels are out. The Bagman enemy is out too (skip it when porting enemies/gray-family.js). Enemies still to port: Tommy-Gun Gray, Muscle, Consigliere, Button Man, Probe Butler, Sinew Crawler, Blister Bloat, Wall Wretch, Gristle Brute, Mawledge, Maw Nest, Meatball Prophet, Follower, Marrow Warden, FOINT Goon, Maintenance Spider, Night Assassin, Dirgeworm (the last two are dev-only, the user may still cut them). Baked lighting is ported as it is. The warehouse gets a simple carry-over, because it will be reworked.

## Roadmap

**Wave 1 (running or done, see table):** characters + animator, combat + weapons, base enemies, audio + FX, HUD / wheel / menus / console, render look, level exporter (static worlds of every level).

**Wave 2, the systems levels stand on:**
- Save system, money, story flags, loadouts (`save/save-game.js`, index.html `saveGame`, `applyLoadout`, `SAVEGAME`).
- Dialogue (index.html ~12609), level doors / portals / world actions (~12730, `nearInteract`, `travel`), shared interact prompt.
- Blockout kit (`levels/_kit/blockout.js` + README, `stealth.js`, `zipline.js`, `crawl.js`, `jetpack.js`, `minigame-door.js`, `control-approach.js`): stages, objectives, checkpoints, rings, arrows, ambushes. Every kit level depends on it.
- Shops and terminals (index.html ~11797-12609, ~373), arms depots (`props/`), minigames (`minigames/`).
- Powers (`powers/`, index.html ~14145) and night vision (`gear/`), flail (`weapons/scorpion-flail.js`), starter arms.
- Vehicles and damage (`vehicles/`), swimming water plan (`levels/hub/harbour.js`).
- Remaining enemies (`enemies/`: ~40 kinds), NPCs (`npcs/`), player clones (`player-clones.js`), level-specific hand ports of ShaderMaterials from the exporter's work list.

**Wave 3, levels (logic on top of exported worlds), smallest first:** club, apartment, kame-lab, worldbackalley, dead-air, warehouse, maktar (arena, TV, commentary), spire, mothership, visiting-hours, omnisphere, dev.

**Not ported, by the user's decision:** Reality Slip, Ship Combat, the jetpack and parkour test levels (`jetpack-yard`, `parkour-yard`; the kit's jetpack stays, other levels use it) and Blood Gulch (`levels/bloodgulch/`, its team match, `RELOAD_ONLY`, the world's `customQueries` terrain path, and the JS sessionStorage reload into it). Skip those branches when you meet them in the JS. Player clones and vehicles are still ported, because the dev console and the hub use them.

**Lighting (user, 2026-11-05):** baked lighting is ported as it is, in the hub and every other level. The warehouse will be reworked later, so it gets a simple carry-over on the shared lights: no light volume, no extra fidelity work.

**Wave 4, hub:** street, shops, FOINT CITY (traffic, crowd on MultiMesh, harbour water, Deck, Dome, Dyosphere, B-9 office), door network.

**Wave 5:** cutscenes (`cutscenes/`, intro), menu backdrop, full play-through. Windows `.exe` postponed by the user; when it comes back: export templates (put them on F:, they are 1 GB) and `F:\prog-builds`.

## Numbers that prove the port
- `tools/golden/` replays 22 scripted movement and camera scenarios through the JS and Godot code at a fixed 60 fps. Body position matched to 0.000 m on 19 of 22 (worst 0.133 m, a rotated wall where the old code sampled 8 points and the new one uses a true cylinder). Camera ends in the same place; it can touch an edge a few frames earlier (sphere cast vs 12 cm stepped points).

## Numbers that prove the port
- Sound mix: each sound through Godot's whole bus chain, captured on Master, against the JS graph rendered offline with its compressor settled (12 sounds, pistol to sniper): RMS within 1.1 dB, peak within 1.1 dB except where the JS passes full scale and clips (ours stops at -0.3 dB). Reverb: Godot's bus reverb set to the same energy as the JS convolver (L2 0.063 per channel), with T60 1.5 s against 1.15 s, because Freeverb decays exponentially and cannot match the convolver's curve exactly.
- Animator: 2318 scripted player frames (idle, walk, run, sprint, jump, flips, crouch, strafe, ledge, punches, hammer fist, wall run, swim, ladder, pole, fatigue, aim, power, seat) fed to the JS and Godot animators at a fixed 60 fps: every bone within 0.2 mm (Prog) and 0.05 mm (Tommy), hair included. All 17 guns carried, aimed, flipped with and reloaded: Prog within 2 cm on the six base guns and 6 cm on the rest, Tommy within 8 cm; the leftovers are the pistol's clock-driven sway and elbow-search steps.

| Piece | JS source | Godot file | State |
|---|---|---|---|
| Math helpers | index.html util.js | core/util.gd | done |
| Config | index.html config.js | core/config.gd | done |
| Input | index.html input.js | core/game_input.gd | done |
| Collision world | index.html world.js | core/world.gd | done (Jolt-backed) |
| Player movement | index.html player.js | player/player.gd | done |
| Camera rig | index.html camera.js | player/camera_rig.gd | done |
| The picture: camera FOV, shake, sun, hemisphere, fog, background, tone map, blob, mirror, dynamic resolution, camera override order | index.html class View, frame end ~14425 | core/view.gd | done |
| Looks: LOOK_BASE and all 15 level entries, `look` console command | post-looks.js, devtools/commands.js | core/looks.gd, View.look_command | done |
| Post: tone map, contact shadows, mist, bloom, streak, grade, sharpen, grain (one CompositorEffect, compute) | post-fx.js | core/post_fx.gd | done, see picture notes |
| Metal reflection on PBR materials | material-look.js | core/material_look.gd (patches StandardMaterial3D in place, automatically, from `node_added`) | done |
| Soft sun shadows | material-look.js | sun light_angular_distance 2, filter quality 3 | done |
| Light pool, sun shadow cache, single pass glow | index.html, sun-shadow-cache.js | not needed: Forward+ is clustered, no static directional cache exists, cascades cost little (below) | not ported, on purpose |
| Frame loop | index.html main.js frame() | core/game.gd | started |
| Playable characters | index.html BUILDS, PROG_HOLDS, FLIP_HOLD | player/builds.gd | done |
| Gait | index.html GAIT | player/gait.gd | done |
| Animator | index.html class Animator | player/animator.gd + tank_fx / eye_fx / skin_fx gdshaders, gun_hulls.json + body_shapes.json (numbers the JS measured from its own meshes) | done. The old prog.glb's skinFix mesh edits are in `player/prog_v1_fix.gd` (nose normals smooth, not flat), and that costume is "Prog V1" in the menu |
| Hair spring | hair-spring.js | player/hair_spring.gd | done |
| Peek / check tools | tests/lib/peek.cjs, devtools/check.mjs | tools/ | done |
| Robot AI, barks, population | index.html enemy.js (Robot, Barks, Enemies) | enemies/ai.gd, barks.gd, robot.gd, enemies.gd | done (range robots idle until hit, as the JS: `ai_notice_range` is 0) |
| Gun Drone | index.html enemy.js (Drone) | enemies/drone.gd | done |
| Robot + drone views | index.html RobotView, DroneView, enemies/robot-visuals.js, rigid-merge.js | enemies/robot_view.gd, drone_view.gd, robot_gfx.gd, mesh_build.gd, rigid_batch.gd + 3 shaders, enemy_views.gd | done: one instanced draw per model and layer (30 robots add 2 draw calls); `spider` view not ported |
| spawnEnemy, despawnEnemy, onReinforce | index.html ~11698 | core/game.gd spawn_enemy, despawn_enemy, _on_reinforce | done for robot + drone; other `kind`s join when ported; WAVE spawner goes with the arena level |
| Weapon table | index.html WEAPONS, weapons/starter-arms.js, weapons/scorpion-flail.js | combat/weapons.gd | done (18 guns, same order) |
| Armor | index.html ARMOR_CATALOG, ArmorStore | combat/armor.gd | done (PowerStore, MANA, the fitting bay's preview models belong to powers / shops) |
| Combat sim | index.html Target, Combat | combat/target.gd, combat/combat.gd | done: event logs of JS and Godot match line for line over every gun, swap, dry fire, shell interrupt, punches, hammer fist, hits taken, pod, drop |
| Flail swing | weapons/scorpion-flail.js FlailSim | combat/flail_sim.gd | done; the ball and chain are fx/flail_view.gd. Compared with the JS frame by frame through a swing: swing curves equal, ball within 3 mm, bones within 12 mm |
| Gun in the hand | index.html WeaponView + every BUILD's tick / post / rack / mag | combat/weapon_view.gd, combat/hush_matcap.gdshader | done; models come from `node tools/export/export.mjs weapons`. Compared with the JS frame by frame through a reload and a shot on 15 of the 18 guns (not the flail, arc or yoke): same phases, parts within about 2 cm |
| Armor suits on the character | phantom-suit.js, syncArmor | player/phantom_suit.gd, player/suit_cloth.gdshader, player/suit_paint.gdshader | done, Prog and Tommy; pieces come from `node tools/export/export.mjs suits`. Checked beside the JS on Prog, front and back, all four suits |
| Rendered sounds | index.html class Sfx (129 s_* methods, menuSound, crtHum, ambients, adverts, clips), enemies/robot-sounds.js, creature-audio.js, scorpion-flail FLAIL_SFX, vehicles/damage.js | tools/export/render-sfx.mjs, assets/sfx/synth/, audio/sfx_bank.gd (generated) | done: 668 keys, 1749 WAVs, 53 MB, none silent, none clipped; `assets/sfx/*.m4a` decoded to .wav. A level's own inline `sfx.tone()` / `sfx.noise()` calls are not rendered: add them to EXTRA in the tool when that level is ported |
| Sfx | index.html class Sfx, audio/synth-audio.js, robot-audio.js, CreatureAudio | audio/sfx.gd, synth_audio.gd, robot_audio.gd, creature_audio.gd, music_track.gd, default_bus_layout.tres | done: JS mix matched within about 1 dB RMS on 12 sounds, see below |
| FX | index.html class FX, updatePlayerFootsteps | fx/fx.gd, fx_mesh.gd, part*, tracer, boom*, blood_* gdshaders, tools/export/render-fx-tex.mjs, assets/fx/ | done: particles, tracers, booms, droplets and splats live entirely in vertex shaders on MultiMesh rings |
| Gadgets, flail in the world | index.html class Gadgets, weapons/scorpion-flail.js FlailView, flail-impact-fx.js, flail-voice.js | fx/gadgets.gd, flail_view.gd, flail_* gdshaders, tex_add, tex_mix, well_points, glow_sprite | done |

Gun parts the exporter must keep (`.name` on the JS BUILD object; a node is `n<idx>_<name>`). All guns: `mag` + `slide` / `bolt` / `pump` / `latch` / `pull` / `lever` (the rack), `spare`, `hatch` as the gun has them. Plus: deagle `hopper balls ball0-7 gear_axis gear_big0-1 gear_sml0-1 pour0-4 glow`; rifle `body counterweight`; smg `gnat0-13 can_gnat0-5 cell0-5`; sniper `band porthole gloss prong_top prong_bot point`; rocket `carousel chamber0-5 key spring0-1 glow`; saw `pulley front_pulley disc`; yoke `cage core halo stone0-7 counterweight`; arc `orb halo ring0-5 cell_l0-4 cell_r0-4`; bellows `bellows knob0-2 glow`; dual_silenced `gun_r gun_l gun_r_slide gun_l_slide gun_r_mag gun_l_mag`; flail `display`.

## Exported levels (tools/export/export.mjs -> levels/exported_level.gd)

Static world only: no level logic, enemies or doors yet. Data path in every case: `res://assets/levels/<id>/` (assets/levels is a junction to F:/prog-godot-levels, not in git; `node tools/export/export.mjs all`, then `node tools/import.mjs`, rebuilds it). "ground" = World answers against the JS World on 3000 recorded points.

| Level | Size | Load | Draw calls | ground | Look beside three.js | Shaders to hand port (shaders/*.json) | Logic will need |
|---|---|---|---|---|---|---|---|
| club | 3 MB glb, 68972 tris | 0.6 s | 102 | 0 of 3000 off | matches: signs, lamps, floor | 0 ShaderMaterial, 0 hooks | 11 moving / toggling nodes, 0 moving solids, 17 lights |
| apartment | 3 MB glb, 35468 tris | ? | ? | ? | look not yet compared | 2 ShaderMaterial, 0 hooks | 37 moving / toggling nodes, 0 moving solids, 8 lights |
| warehouse | 21 MB glb, 247816 tris | ? | ? | ? | look not yet compared | 3 ShaderMaterial, 9 hooks | 199 moving / toggling nodes, 6 moving solids, 6 lights |
| kame-lab | 0 MB glb, 4312 tris | ? | ? | ? | look not yet compared | 3 ShaderMaterial, 0 hooks | 2 moving / toggling nodes, 0 moving solids, 3 lights |
| omnisphere | 68 MB glb, 663181 tris | ? | ? | ? | look not yet compared | 12 ShaderMaterial, 2 hooks | 1009 moving / toggling nodes, 54 moving solids, 16 lights |
| visiting-hours | 95 MB glb, 1110552 tris | 8.9 s | 854 | 1 of 3000 off | warmer than three.js; beam and sky are placeholders | 13 ShaderMaterial, 3 hooks | 402 moving / toggling nodes, 12 moving solids, 87 lights |
| spire | 17 MB glb, 561539 tris | ? | ? | ? | look not yet compared | 1 ShaderMaterial, 5 hooks | 199 moving / toggling nodes, 21 moving solids, 4 lights |
| mothership | 50 MB glb, 1241368 tris | 5.1 s | 423 | 1 of 3000 off | matches closely | 0 ShaderMaterial, 0 hooks | 565 moving / toggling nodes, 17 moving solids, 94 lights |
| dead-air | 5 MB glb, 78975 tris | 3.3 s | 230 | 0 of 3000 off | darker than three.js near the spawn | 0 ShaderMaterial, 2 hooks | 56 moving / toggling nodes, 6 moving solids, 49 lights |
| maktar | 24 MB glb, 339943 tris | ? | ? | ? | look not yet compared | 0 ShaderMaterial, 0 hooks | 0 moving / toggling nodes, 0 moving solids, 12 lights |
| hub | 120 MB glb, 2475663 tris | ? | ? | ? | look not yet compared | 14 ShaderMaterial, 8 hooks | 84 moving / toggling nodes, 0 moving solids, 24 lights |
| dev | 0 MB glb, 7654 tris | ? | ? | ? | look not yet compared | 1 ShaderMaterial, 0 hooks | 0 moving / toggling nodes, 0 moving solids, 2 lights |
| blockout-demo | 0 MB glb, 118 tris | ? | ? | ? | look not yet compared | 0 ShaderMaterial, 0 hooks | 0 moving / toggling nodes, 0 moving solids, 0 lights |
| worldbackalley | 19 MB glb, 630116 tris | 10 s | 718 | 0 of 3000 off | right lights and props; rain streaks are static lines | 1 ShaderMaterial, 1 hooks | 188 moving / toggling nodes, 0 moving solids, 15 lights |
| reality-slip | 3 MB glb, 76903 tris | ? | ? | ? | look not yet compared | 3 ShaderMaterial, 1 hooks | 14 moving / toggling nodes, 0 moving solids, 2 lights |
| ship-combat | 42 MB glb, 345445 tris | ? | ? | ? | look not yet compared | 9 ShaderMaterial, 1 hooks | 63 moving / toggling nodes, 0 moving solids, 3 lights |

## The picture: what was measured
Calibration chart drawn in both games (boxes, PBR spheres, emitters, a pole, distance columns; 279 sampled points, 0-255 on screen). Mean error of the largest channel, JS vs Godot: bare materials 1.0, LOOK_BASE 1.8, spire 2.1, hub 3.9, worldbackalley 5.2, bloodgulch 5.3, club 5.9. Skin, shirt and boots on Prog in the same light: within 1-4.

Known differences left, none fixable with StandardMaterial3D:
- **Additive and blended materials.** three.js blends in display space, Godot in linear: `#404040` added over a mid grey is 127 in the JS, 89 here. FX and exported glass may want a stronger colour by hand.
- **Fog.** three.js mixes it into the finished display value, Godot into radiance, per material. `View._fog_curve` picks Godot's depth curve to match half way in; a dark box in a pale fog is still up to 47 too light, a bright sign in a dark fog up to about 40 too bright, and glowing a little more for it. Fog is also radial here, view depth in the JS.
- **Godot's `roughness limiter` is left on** because it does the job of three.js's geometry roughness; sharp highlights are within about 8, on small glossy metal up to 21.

Coverage misses in this area, on purpose: `View.resize` (Godot resizes the camera and the post textures itself), `View._buildWorld` (core/solid_view.gd), `View.buildLevelVisuals` (levels/exported_level.gd), `LightPool` (see the table).

Rules for whoever makes materials: Lambert means `metallic_specular = 0` (no reflection, no highlight). `fog: false` means `disable_fog`. `force_lambert_over_burley` is on project-wide. Colours for `toneMapped: false` go through `View.display_to_radiance` or the exporter's `untonemap`. A sky dome must not write depth, or it gets contact shadows and mist. Give a mesh its material before `add_child`, or call `Game.view.material_look.adapt_tree(node)`: otherwise it gets no reflection. Level look: `Looks.get_look(id)` / a `look` Dictionary on the Level; render state: `Game.view.apply_render_state(dict)`.

Costs, GTX 1660 Ti, 1920x1061, arena, vsync off, other GPU work running (GPU ms / render CPU ms):
- Without post 3.21 / 0.52. With LOOK_BASE 4.13 / 0.58: **0.92 ms GPU, 73 us CPU**. Hub look (mist, streak) 4.14. Passes: display 0.11, contact shadows 0.24, bloom 0.15 (0.16 with streak), final 0.28.
- Could Godot's environment replace a pass? No pass gives the same picture. SSAO: contact shadow error 5.5 against 1.2, and 0.19 ms dearer. Glow: emitter and halo error 9.1 against 0.2, and 0.75 ms dearer. Mist: Godot's height fog is not integrated along the ray and has no glow toward a light; volumetric fog would be a different effect at far more cost, and mist costs almost nothing here (not measurable beside noise).
- MSAA off 3.83, 2x 3.94, 4x 4.20: kept at 4x, as in the JS. TAA and FSR 2 off: the JS has neither. Roughness limiter +0.11.
- Sun: no shadow 2.70, cascades 1 / 2 / 4 about 3.8-4.2, same within noise. With 2500 extra casters CPU 0.81 / 0.78 / 0.85. Soft filter quality 1-5: 3.41, 4.01, 4.14, 6.49, 8.03 (kept 3). Angular distance 0 against 2: 2.45 against 4.11, so soft shadows are the dearest single choice, 1.66 ms; first thing to reduce if a level is GPU-limited.
- Hemisphere colour changed every frame: no measurable cost at radiance 64. Intensity only: free.
- FSR 1 at 0.8 / 0.6: GPU 3.12 / 2.00. A scale change hitches 5-11 ms, like the JS. Vsync on at 120 Hz holds 118 fps here, `run/max_fps` stays 0.

## Shader work list (assets/levels/<id>/shaders/<name>.json)

GLSL does not run in Godot, so these files are reference for hand ports; nothing converts them. Until a port lands, the node draws a placeholder (unlit, in the colour its uniforms suggest, transparent ones capped at 0.2 alpha). Names are content hashes, so the same shader in two levels is one job.

| ShaderMaterial | Levels | Objects | What it becomes |
|---|---|---|---|
| ReflectorShader_c6f6b0 | apartment, dev | PROG'S APARTMENT | three.js Reflector, internal: Godot has no node for it; SubViewport with a mirrored Camera3D drawn on the mesh |
| rain_streaks_e3b913 | apartment | rain outside | transparent effect: spatial shader, blend_add |
| shader_0da48b | hub | RoofSmoke | transparent effect: spatial shader |
| shader_1d0ffe | hub | B-9 / light shafts in suspended dust | transparent effect: spatial shader, blend_add |
| shader_20ce0d | hub | CityPlaza, CityRoads, CitySidewalks | surface: spatial shader |
| shader_34e20b | hub | uniforms: map, uPulse, uScale, uSkyNear | point / sprite field: MultiMesh of billboards in a spatial shader |
| shader_4a3f88 | hub | NightSky | sky: Sky shader or dome |
| shader_60a91f | hub | Vintage TV 0 / curved glass, Vintage TV 1 / curved glass, Vintage TV 10 / curved glass | surface: spatial shader |
| shader_65916e | hub | Alley weathered brick, CityShops, CityWalls0 | surface: spatial shader |
| shader_8dce7b | hub | Dyosphere | transparent effect: spatial shader, blend_add |
| shader_9ae872 | hub | DistrictWater | surface: spatial shader |
| shader_b13e22 | hub, worldbackalley | sprite field | point / sprite field: MultiMesh of billboards in a spatial shader |
| shader_b17ba4 | hub | WetReflections | point / sprite field: MultiMesh of billboards in a spatial shader |
| shader_d61eee | hub | crt-tv | surface: spatial shader |
| shader_e12192 | hub | CityBeacons | point / sprite field: MultiMesh of billboards in a spatial shader |
| shader_e36887 | hub | ManholeSteam | transparent effect: spatial shader |
| shader_d57960 | omnisphere | uniforms: uMap, uScale | point / sprite field: MultiMesh of billboards in a spatial shader |
| shader_88d62b | kame-lab | kame-dust, kame-ki | point / sprite field: MultiMesh of billboards in a spatial shader |
| shader_970543 | kame-lab | uniforms: uAlpha, uColor, uFill, uHot | transparent effect: spatial shader, blend_add |
| shader_fbf9e3 | kame-lab | uniforms: uAlpha, uColor, uFill, uHot | transparent effect: spatial shader, blend_add |
| shader_20ab12 | omnisphere | ash sky | sky: Sky shader or dome |
| shader_26122d | omnisphere | uniforms: fogColor, fogDensity, fogFar, fogNear | point / sprite field: MultiMesh of billboards in a spatial shader |
| shader_473d95 | omnisphere, ship-combat | glow field | point / sprite field: MultiMesh of billboards in a spatial shader |
| shader_9750ed | omnisphere, ship-combat | volcano cone | surface: spatial shader |
| shader_a09ff2 | omnisphere, ship-combat | uniforms: map, uAlive, uCol, uH | transparent effect: spatial shader |
| shader_a19d8a | omnisphere, ship-combat | lava bursts | transparent effect: spatial shader, blend_add |
| shader_a92da8 | omnisphere, ship-combat | lava sea | surface: spatial shader |
| shader_af7477 | omnisphere | freefall air | transparent effect: spatial shader |
| shader_b2d790 | omnisphere, ship-combat | volcano plumes | transparent effect: spatial shader |
| shader_c6108c | omnisphere, ship-combat | omnisphere landmarks | surface: spatial shader |
| shader_f5b5f4 | omnisphere | ash | transparent effect: spatial shader |
| shader_1a9005 | reality-slip | Liquid feedback tunnel | transparent effect: spatial shader |
| shader_8ef0d9 | reality-slip | Foint City home vista | surface: spatial shader |
| shader_9daa80 | reality-slip | uniforms: uT | transparent effect: spatial shader |
| shader_b0ac94 | ship-combat | ash sky | sky: Sky shader or dome |
| shader_c14834 | ship-combat | ash | transparent effect: spatial shader |
| shader_75102a | spire | spire-sky | sky: Sky shader or dome |
| shader_0c99d2 | visiting-hours | admin-f1 | surface: spatial shader |
| shader_149d8e | visiting-hours | uniforms: fogColor, fogDensity, fogFar, fogNear | transparent effect: spatial shader |
| shader_2a7ca1 | visiting-hours | uniforms: uCityDir, uFlash, uFog, uGlowDir | surface: spatial shader |
| shader_312693 | visiting-hours | uniforms: uCam, uFlash, uLit, uTime | transparent effect: spatial shader |
| shader_36eaf6 | visiting-hours | admin-f1, admin-f2, admin-f3 | transparent effect: spatial shader |
| shader_6c1b3c | visiting-hours | uniforms: uCar, uFlash, uFwd, uOn | surface: spatial shader |
| shader_7b858d | visiting-hours | uniforms: uC | transparent effect: spatial shader |
| shader_7cdfd9 | visiting-hours | uniforms: uA, uCol | transparent effect: spatial shader, blend_add |
| shader_832553 | visiting-hours | uniforms: uA, uCol | transparent effect: spatial shader, blend_add |
| shader_89ebf4 | visiting-hours | uniforms: uA | transparent effect: spatial shader, blend_add |
| shader_ce694a | visiting-hours | uniforms: uCol | transparent effect: spatial shader, blend_add |
| shader_dbb0da | visiting-hours | uniforms: fogColor, fogDensity, fogFar, fogNear | transparent effect: spatial shader |
| shader_ea8496 | visiting-hours | uniforms: uCam, uCol, uTime | transparent effect: spatial shader |
| shader_700d26 | warehouse | East river / rain surface | surface: spatial shader |
| shader_9fb716 | warehouse | Storm cloud skybox | sky: Sky shader or dome |
| shader_b79949 | warehouse | Foreman eye impact electricity, Purge electrical discharge | transparent effect: spatial shader, blend_add |

onBeforeCompile hooks: the mesh keeps its real material and only loses the hook's extra (grime, swell, wetness).

| Hook | Levels | Meshes | Objects |
|---|---|---|---|
| obc_5871597abd_5871 | dead-air | 8 | Dead Air deep batched |
| obc_df1a976032_df1a | dead-air | 5 | Bellows / body into the shaft, Bellows / coil |
| obc_5546464f20_5546 | hub | 138 | Cars-bus, Cars-hatch |
| obc_67047db111_6704 | hub | 1 | PalePunk |
| obc_68268baacb_6826 | hub, worldbackalley | 57 | static-batch |
| obc_a465045101_a465 | hub | 227 | Benches |
| obc_a7e129a18c_a7e1 | hub | 1 | Club 9 bat-wing neon marquee |
| obc_b8223c0d30_b822 | hub | 9 | Dyosphere |
| obc_e3980ab25c_e398 | hub | 40 | Folk-agent, Folk-binocular |
| obc_f7d9d0fb24_f7d9 | hub | 138 | CarsTrim-hatch, CarsTrim-sedan |
| obc_4ac892b32f_4ac8 | omnisphere, reality-slip, ship-combat | 470 | FOINT gunship, cargo tug |
| obc_Juniper_75cd | omnisphere | 1 | Juniper |
| obc_09d90332ca_09d9 | spire | 595 | foot |
| obc_1b6e823e36_1b6e | spire | 1 | bile-liquid |
| obc_78d17a04b4_78d1 | spire | 82 | - |
| obc_9ba9e4cbe7_9ba9 | spire | 14 | - |
| obc_b1a429bca9_b1a4 | spire | 4 | - |
| obc_Material_0_6e89 | visiting-hours | 5 | goon_security_1 |
| obc_b083e30fcc_b083 | visiting-hours | 106122 | instanced |
| obc_c33fcd44bd_c33f | visiting-hours | 45 | admin-b1, admin-f1 |
| obc_044ac526b5_044a | warehouse | 1131 | Retracting security shutter, Security entrance / racks/0 |
| obc_06f9cb0003_06f9 | warehouse | 203 | Retracting security shutter, Security entrance / racks/0 |
| obc_286ff639bb_286f | warehouse | 146 | The Foreman |
| obc_5f7079e785_5f70 | warehouse | 3 | - |
| obc_Hero_atlas_metal_044a | warehouse | 1 | Dorbat / authored industrial fittings / metal |
| obc_Hero_atlas_metal_f610 | warehouse | 4 | Hero / crane cassette / metal, Hero / crane trolley / metal |
| obc_Hero_atlas_painted_044a | warehouse | 1 | Dorbat / authored industrial fittings / paint |
| obc_Hero_atlas_painted_f610 | warehouse | 4 | Hero / crane cassette / paint, Hero / crane trolley / paint |
| obc_f61029f49c_f610 | warehouse | 1927 | Warehouse / outdoor visibility, Warehouse sign / BROKEN FEED / JUMP OR SIDE LANE |
