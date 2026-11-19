# tools/folk: FOINT CITY's townsfolk

Every person walking FOINT CITY's sidewalks is built here, by script, in background Blender, from the user's concept art:
sculpted as clay, painted, baked onto a light game model, rigged, animated and exported to `assets/folk/<id>/` (`<id>.gltf` + `.bin`,
its three maps baked at 2048 and shipped at 1024, and `<id>.json`).
In the game, `levels/hub/folk_skin.gd` samples each species' clips into a bone texture and `levels/shaders/folk_skinned.gdshader` skins
the whole crowd of that species on the GPU as one MultiMesh (`levels/hub/city_crowd.gd` walks them).

The reference character is **`recipes/fin_exec.py`** (the fin-headed businesswoman). Read it end to end before writing a recipe: it is
the shape of every recipe and shows each kit feature in use.

## The quality bar (the user's words and judgements, 2026-11-15/16)

- "PS2 triple A quality. Smooth edges, quality walking animations, good sculpt", and each species "somewhat unique from each other when it
  comes to their height and their movements: they are different creatures." Ratchet & Clank / Jak era characters: strong silhouettes,
  readable faces, rich materials. The concept sheets are film-quality renders: hit their shapes, palette, costume and personality.
- **Their own species, never Earth animals.** Animal shapes are fine, a frog in a tie is not.
- **Match the concept's shape language exactly.** Angular stays angular, round stays round, a pointed chin stays pointed. Never "fix" a
  feature that looks odd to you: crop the concept, zoom in, and match it. (The user stopped a rounded muzzle on fin_exec's angular face:
  "she's angular, not a rounded blob".)
- **Faces first.** Eyes, nose, mouth placement and their construction are judged before anything else. (A missing nose was the user's
  "primary concern".) Judge faces from front, three-quarter and profile: `--views face@0,face@-45,face@-90`.
- **Props are the exception.** "They don't all have to keep their in-image props, if anything too many might have props." The roster
  below says which few keep one; everyone else walks with free hands (worn things like a walkman clipped on, a rope coil over a shoulder or
  a tool vest are costume, not props).
- The paint carries a lot of the look: fabric weave, leather grain, worn edges, dirt in creases, freckles, prints, crisp ink lines.

## The build loop, per character

All commands from `F:/prog-godot`, Blender is `"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"` (call it `B` below).

1. **Study.** Enlarge the concept crop (roster box) 3x, and the face 8x:
   `B --background --factory-startup --python tools/folk/crop.py -- F:/prog-godot-cache/folk/refs/<image> x0 y0 x1 y1 3 F:/prog-godot-cache/folk/<id>/ref.png`
   Measure proportions off it: total height, head height and width, where shoulders, waist, crotch, knees sit (see fin_exec's header).
2. **Clay.** Write `recipes/<id>.py`, then loop on
   `B --background --factory-startup --python tools/folk/build.py -- <id> --colour --views front,q3,side,face@-45`
   and look at `F:/prog-godot-cache/folk/<id>/sheet_colour.png` (concept on the left) every time. Iterate until the silhouette,
   proportions and face match.
3. **Paint.** `... -- <id> --paint --views q3,face@-45,face@0,bust` → `sheet_paint.png`.
4. **Game.** `... -- <id> --game --views front,q3,side,face@-45` (about 3 minutes) → `sheet_game.png` (the baked game model),
   `strip_walk_side.png` (eight walk frames from the side), `strip_moves.png` (walk from the three-quarter, idle at keys 0/75/90/105,
   run). Check: feet planted (the stance foot slides back at a steady speed, never skates or pops), knees and elbows bend the right way,
   nothing passes through the body, the clothes deform cleanly, the motion has the character's personality.
5. Done when all three sheets hold up next to the concept. The model, maps and JSON are written to `assets/folk/<id>/` by `--game`.

A clay build takes 30-90 s, a game build about 3 minutes. Run one Blender build at a time; GPU bakes queue on a machine-wide lock.

## Recipe contents (see fin_exec.py)

- `HEIGHT` (metres, in the rest pose), `REF = (image under refs/, (x0, y0, x1, y1) or None)`.
- Part ids and `COLOURS` (flat clay colours for `--colour`).
- Landmarks as module constants (left side, +X), then shape functions, then `pieces()` → `[(name, shape, voxel size)]`.
  Pieces are meshed separately and never blend: e.g. `head` (h 0.0018: fine faces and sharp facets), `body` (0.0035), thin plates such as
  fins, ears, collars of jewellery (0.0015), props (0.0025). A thin feature needs at least three voxels of thickness.
- `paint(c)`: fills `c.col`, `c.rough`, `c.metal`, `c.bump`, `c.grain`, `c.spk`, `c.strp` per vertex (see `kit/paint.py`), and draws crisp
  lines and shapes with `c.draw(mask, dist, half_width, strength)` (eyeliner, pupils, seams, stitching). `c.ao`, `c.wear`, `c.cavity`
  come from the clay itself.
- `GAME = {"budget": {piece: triangles}, "density": {piece: texture scale}, "tex": 2048, "stride": {"walk": m, "run": m}, "speed": x,
  "look": [up to 3 bones that turn fully], "neck": bone that turns half, "look_pivot": (x, y, z) Blender space, "radius": m}`.
  Total budget 6-10k triangles. `stride` is metres per cycle (two steps) and must equal the clip's own foot travel (the stride you give
  `biped_walk`), or the feet slide in game. `speed` scales the crowd's pace (base about 1.2 m/s; 0.6 a slow shuffler, 1.3 a brisk walker).
- `rig_bones()` → `[kit.rig.Bone(name, head, tail, parent, radius)]`; `kit.rig.mirror()` copies `.L` bones to `.R`.
- `skin_rules(P, part, piece, names)` → `(A, rigid)`: which bones each vertex may take (by piece, part, side, height), and a single bone
  for vertices that must move rigidly (heads, props, hard shells).
- `motions(rig)` → `{"idle": [181 poses, 6 s at 30 fps, periodic], "walk": [33 poses, one cycle, left foot down at 0 and 32],
  "run": [25 poses, one cycle]}`. All three are required, whatever the creature (a hoverer's walk is its glide).

## Kit notes

- **Space:** Blender, metres, Z up, the figure faces **-Y**, its left is **+X**. Build the left side and `Mirror` it.
- **sdf.py:** `Sphere, Ellipsoid, RoundCone` (capsule-ended: limbs, necks), `CappedCone` (flat-ended: cups, cans, boots' shafts),
  `Box` (rounded), `Torus`, `Gem` (faceted double pyramid with per-axis extents, `soft` and `edge` rounding: angular heads, beaks, crests),
  `Slab` (a 2D polygon extruded: fins, soles, buckles), `Half` (half-space); combos `Union(k)` (k = clay fillet), `Cut`, `Clip`, `Mirror`,
  `Move`/`place`/`basis`, `Inflate`, `Bump`; fields `noise3`, `ridge_line`; `loft([(point, radius), ...])`.
- **Lessons from fin_exec:**
  - Eyes: an eyeball sphere pushed forward of the face, a lid shell (an ellipsoid a few mm larger) `Clip`ped by a plane, blended into
    the face with a small k (0.008). Paint iris colour per vertex; ink the pupil and the liner. Probe the SDF to know where a surface
    is before placing features on it (fin_exec's nose was buried until probed).
  - Garments that follow the body: `Inflate(core, t)` of the body shape, then `Clip`/`Cut` openings and hems. Lapels and collars are a
    thicker layer of the same, clipped by a front-view outline (`prism`), or a thin shell (`Cut(Inflate(core, a), [Inflate(core, b)])`).
    Flat slabs float off curved bodies.
  - Sleeves join the jacket with a smooth union (k about 0.018); a hard union leaves lumps at the shoulder.
  - Arms must not touch the torso in the rest pose (the voxel mesher fuses them). The rest pose is the pose the character holds most.
  - Sharp facets want `edge` rounding (0.003-0.007) and a fine voxel (0.0018) or they come out sawtoothed.
- **paint.py:** speckles are Voronoi dots in the shader (`c.spk` = colour + amount per vertex, size shared); pinstripes from a coordinate
  you write into `c.strp[:, 0]` (metres across the stripes); grain 0 = fabric weave, 1 = leather pebble.
- **gait.py:** `Pose.rot(bone, rx, ry, rz)` rotates a joint (degrees, in the rest pose's world axes, applied in its parent's moved frame);
  `Pose.world[bone]` sets a bone's absolute rotation (keep a head level, a cup upright); `Pose.offset` moves the hips;
  `Pose.ik[top] = (target, pole, end_bone, end_rotation)` places a two-bone chain. `biped_walk(rig, pose, u, g, legs)` gives a full biped
  body (feet planted by IK, hips bob/sway/roll/twist, counter-rotation); `stand(...)` plants feet for an idle. Anything else (four legs,
  a serpent tail, a pogo hop, a glide) is written in the recipe with `Pose`: legs by IK at phase offsets, chains by FK sine waves.
  Give every creature its own rhythm and attitude: the strip renders show it.
- **Lessons from the first 45 (the builders' reports, 2026-11-16):**
  - `Move(child, R=I/s)` draws the child s times bigger (R maps world into the child). Its bound is right for any R since the fix of
    2026-11-16; the distance stays the child's own (an `Inflate` or blend inside a scaled child is in its units).
  - Raising an arm out to the side is `ry` (negative for .L, positive for .R); `rz` on a hanging arm swings it forward or back.
  - To pin a hand with `Pose.ik`, the chain end is a bone whose head sits at the wrist (add an unweighted `hand` bone if need be);
    naming the forearm targets the elbow. A hand in a pocket or on a hip is IK that rides the hips.
  - `biped_walk` centres the ball of the foot under the hips: flat-footed characters want `p.offset.y += BACK` to bring the hips back
    over the ankles, and big shoes want the ball pivot near the toe or the toe sinks at toe-off.
  - The decimator (`game.make_low`, X-symmetric) breaks on: layers thinner than about four voxels (floating collars, loose bangles:
    make them solid raised layers or sink them in), touching chain links (make links solid ovals), thin cloth shells full of holes,
    grooves that converge to a point, tiny loose islands (tie teeth into gums), dead-flat faces, and any piece with many handles (a
    thin shell or a pleated skirt meshed full of holes; check V - E + F of the high mesh: a solid piece is near 2 per closed part).
    Lopsided pieces decimate fine. It can then starve or delete whole regions: check the game sheet for missing feet or arms.
    It lands 0-20% over a piece's budget.
  - Touching legs in the rest pose bake their insides dark, which shows once they stride apart: keep them apart below the seat.
  - Bake misses come out black. White or bright streaks (a jaw to neck crease, a collar, a saucer's belly) were, on the ufo, flipped
    faces from a piece decimated too hard (under about 1% kept) catching the preview rig's low rim light on a glossy surface: split
    the piece so each part keeps more of its faces, and keep skin and cloth from being too glossy. Sample the baked maps there before
    blaming the bake. Look at the game sheet's bust view for streaks before calling a character done.
  - The folk shader has no transparency or emission: glass, jelly and screens are painted (insides on the glass, glows as bright
    albedo). The pinstripe term only darkens; light stripes are vertex paint. Bone scale (squash and stretch) needs a recipe-local
    writer, since `gait.write_action` keys rotation and location.
  - Large round bodies at 3 mm voxels can run numpy out of memory with several builds going: use 3-3.5 mm.
  - The face@ views centre on 0.9 x HEIGHT and miss faces set low or very large: pass a view list that frames the face.

## Rules for builders

- Write only `tools/folk/recipes/<id>.py`, `assets/folk/<id>/` (by `--game`) and `F:/prog-godot-cache/folk/<id>/`. Never edit the kit,
  `build.py`, another builder's recipe, Godot files or anything else in the project. If the kit lacks something, build it inside your
  recipe and say so in your report.
- Nothing on C: (nearly full). No commits. Don't run `tools/import.mjs` or the game: the lead imports and integrates.
- Report per character: id, height, how it moves, strides and speed, props kept, triangle count, anything unresolved, sheet paths.

## The roster

Concept images are in `F:/prog-godot-cache/folk/refs/` (boxes are x0, y0, x1, y1 in pixels, top-left origin). The upgraded old species
have a front + three-quarter render of the old model in `refs/old/<id>.png` and their JS source (colours, gag, details) in
`C:/Users/12147/Documents/GitHub/progectalp2/progalpha-20261016T082732Z-1-001/progalpha/levels/hub/folk-species-{a,b,c,d}.js`
(read only). An upgrade keeps the character's identity (silhouette idea, colours, gag) and lifts it to the new sheets' art direction.
Heights are for variety across the city: keep within about 5 cm.

| id | source | height | moves | props |
|---|---|---|---|---|
| fin_exec | 2.png (0,0,377,395) | 1.95 | runway walk in heels, aloof | coffee, briefcase (done) |
| veg_granny | 1.png (75,6,364,378) | 1.35 | slow rocking waddle | none (crate dropped) |
| grocery_dad | 1.png (31,380,319,765) | 1.90 | heavy plod, belly leads, leans back | none |
| walkman | 2.png (29,383,334,779) | 1.60 | bouncy groove, head bobbing to music | walkman clipped on, earphones |
| lounge_singer | 3.png (27,2,250,389) | 1.85 | slinky hip sway in heels | none |
| mob_boss | 3.png (14,393,321,782) | 1.75 | slow wide swagger, one hand in pocket | none |
| gardener | 4.webp (80,3,370,388) | 1.45 | stooped pottering amble | none |
| mechanic | 4.webp (411,3,750,388) | 2.20 | heavy lumbering, arms wide | toolbox |
| nurse | 4.webp (840,3,1042,391) | 1.90 | brisk, efficient | clipboard |
| accountant | 4.webp (119,382,347,782) | 1.55 | hurried nervous little steps, hunched | none |
| climber | 4.webp (460,385,672,782) | 1.65 | springy, confident | rope coil over shoulder (worn) |
| cook | 4.webp (771,393,1076,782) | 1.60 | relaxed shuffle in crocs | none |
| lilac_spider | 5.webp (118,0,360,388) | 2.10 | languid long-limbed, arms dangling | none |
| fish_biker | 5.webp (431,2,695,386) | 1.90 | slouchy swagger, hands in pockets | none |
| manta_goth | 5.webp (775,4,1055,392) | 1.70 | stompy platform boots | none |
| snakeneck | 5.webp (83,381,354,781) | 2.30 | neck sways like a periscope | none |
| naga | 5.webp (413,388,690,779) | 1.80 | slithers, tail S-wave, no legs | none |
| demon_tail | 5.webp (790,380,1090,783) | 1.85 | cocky stroll, tail swishing | jacket over shoulder (worn) |
| couch_worm | 6.webp (5,8,402,363) | 1.40 | stomping big-foot waddle | none |
| manta_maid | 6.webp (419,0,796,360) | 1.75 | prim quick steps | none |
| arch_legs | 6.webp (20,386,392,765) | 1.50 | the arch's two columns stride, the arch rocks | none |
| heart_tech | 6.webp (425,372,798,764) | 1.30 | one leg: pogo hops, tail for balance | none (tool vest worn) |
| cyclops_gamer | 7.webp (41,9,340,366) | 1.20 | hunched waddle, eye on the handheld | handheld console |
| jelly_drill | 7.webp (392,9,756,362) | 1.40 | skittery four-legged trot, jelly wobble | none (headset worn) |
| hole_chest | 7.webp (772,5,1142,368) | 2.00 | heavy barefoot shuffle | none |
| mop_fringe | 7.webp (31,380,386,775) | 1.50 | shuffly bounce, fringe swinging | none (headphones worn) |
| spiral_rain | 7.webp (385,366,747,775) | 1.60 | lilting limp on mismatched boots | closed umbrella as a cane |
| bean_clock | 7.webp (761,367,1161,775) | 1.10 | hurried waddle on short legs | none |
| tvbot | old/tvbot.png | 1.70 | stiff robotic stride, head screen | none |
| cratebot | old/cratebot.png | 1.00 | four-legged box robot trot | none (banner dropped) |
| brainjar | old/brainjar.png | 1.40 | jar on a little mech walker, eye stalk looking about | none |
| fishbowl | old/fishbowl.png | 1.20 | small astronaut bounce, fish swimming in the helmet | none |
| binocular | old/binocular.png | 2.00 | tall coat, slow sneaky stalk | none |
| conehat | old/conehat.png | 1.80 | cloaked, glides | none |
| cone | old/cone.png | 0.90 | a traffic cone that hops | none |
| slime | old/slime.png | 0.80 | jelly cube squash-and-slide | boot and bone inside (costume) |
| ufo | old/ufo.png | 1.20 | the game's grey alien in a hover pod: bobbing glide | none |
| blob | old/blob.png | 1.30 | round many-eyed fellow in overalls, waddle | none |
| twohead | old/twohead.png | 1.85 | one suit, two heads arguing as it walks | none |
| stilts | old/stilts.png | 2.60 | three-eyed visitor on long thin legs, careful steps | none |
| noodle | old/noodle.png | 2.20 | tall teal fellow, mostly head, head bobs | none |
| disguised | old/disguised.png | 1.80 | cheap human suit walking stiffly, the real driver in a hatch in the head | none |
| hotdog | old/hotdog.png | 1.90 | the FOINT DOGS mascot costume, waddle | none |
| cyclops | old/cyclops.png | 1.70 | one big eye, red tracksuit, gold chain, swagger | none |
| grinbuddy | old/grinbuddy.png | 1.10 | short round fellow, always delighted, skippy | none |
| sandwich | old/sandwich.png | 1.75 | sandwich board ("the end is near"), trudge | the board (costume) |
