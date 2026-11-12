# Port measurements and tables

Moved word for word from PORT_STATUS.md on 2026-11-09: proof numbers, the piece table, gun parts the exporter keeps, exported-level table, picture measurements and costs, shader work list. Read it when you touch rendering, shaders, the exporter or a gun model. Some rows are older than the code (for example the exported-levels note says assets/levels is a junction and not in git; CLAUDE.md is right: it is in git).

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
| foint-dome | 24 MB glb, 339943 tris | ? | ? | ? | look not yet compared | 0 ShaderMaterial, 0 hooks | 0 moving / toggling nodes, 0 moving solids, 12 lights |
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
