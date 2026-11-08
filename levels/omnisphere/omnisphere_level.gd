class_name OmnisphereLevel
extends KitLevel
## OMNISPHERE (JS levels/omnisphere/level.js): FOINT's top-secret plant, where the company is building its own answer to SERN's Dyosphere out of power siphoned from a captive electrical being, Juniper. This file: the render look, the stage flow and the per-frame orchestration. om_* files hold the pieces. The art is the export; the moving parts are found by name.

const A := {"spawn": {"x": 2.5, "y": 6.0, "z": 5.5, "yaw": -2.5}, "pad": [0.0, 6.0, 0.0], "ramp_top": [21.0, 13.0, -76.0], "tower_door_e": [-38.8, 13.0, -76.0], "tower_door_w": [-53.2, 13.0, -76.0], "p1": [-73.0, 13.0, -72.0], "p2": [-86.0, 15.0, -64.0], "p3": [-99.0, 15.0, -55.0]}
const FOG := 0x24120e
const LOADOUT := ["deagle", "rifle", "shotgun", "rocket"]      # (the AEROLIFT-7 is on his back from the start: he jumps in wearing it)
const EQUIP := "rifle"

var loadout: Array = LOADOUT
var equip: String = EQUIP
var audio: OmAudio
var jet: JetpackKit
var marks: OmMarks
var draw: OmDraw
var sets: OmSets
var sec: OmSecurity
var craft: OmCraft
var act2: OmAct2
var esc: OmEscape
var summit: OmSummit
var chamber: OmChamber
var towers: OmTowers
var tram: OmTram
var sky: OmSkyFoes
var ff: OmFreefall
var dock: OmDockhand
var dive: OmDive
var fly: OmFlyoff
var shift: OmSecurity.Door
var alarm_t := 0.0
var alarm_v := 0.0
var said_draw := false
var cur_stage := ""
var touched := false
var data := {}
var vault: MinigameDoor = null
var _pods: Array[FointPod] = []
var _pods_t := 0.0
var vendors: Array = []      # FOINT's dispensary pods on the route (JS levels/omnisphere/depots.js): where X works; their solids come with the export, their bodies are _pods
var view_done := false
var heavies: Array[OmHeavy] = []


class CineChain:
	var L: OmnisphereLevel
	func cur() -> Variant:
		if L.fly != null and L.fly.on:
			return L.fly.cine
		if L.dive != null and L.dive.st_on:
			return L.dive.cine
		if L.summit != null and L.summit.ins.on:
			return L.summit_cine
		if L.ff != null and L.ff.on:
			return L.ff.cine
		return null
	var on: bool:
		get:
			return cur() != null
	var play: bool:
		get:
			var c: Variant = cur()
			return c != null and c.play == true
	var camera: View.Shot:
		get:
			var c: Variant = cur()
			return c.camera if c != null else null
	func pose_player(a: Variant) -> void:
		var c: Variant = cur()
		if c != null and c.has_method(&"pose_player"):
			c.pose_player(a)


class SummitCine:
	var S: OmSummit
	var on: bool:
		get:
			return S.ins.on
	var play := false
	var camera: View.Shot:
		get:
			return S.cine_cam


var cine_chain := CineChain.new()
var summit_cine := SummitCine.new()
var cine: Variant:
	get:
		return cine_chain


func kit_options() -> Dictionary:
	data = (info.get("data", {}) as Dictionary).get("omni_data", {})
	return {"id": "omnisphere", "name": "OMNISPHERE", "spawn": A.spawn, "fall_reset_y": 1.5, "drone_leash": true,
		"on_enter_stage": _enter_stage,
		"on_spawn": func(r: Robot, spec: Dictionary, _b: Blockout) -> void:
			if spec.get("heavy", "") != "":
				heavies.append(OmHeavy.install(r, spec.heavy, self)),
		"on_update": func(dt: float, P: Player, C: Combat, b: Blockout) -> void: _tick(dt, P, C, b),
		"on_complete": _complete}


func _enter_stage(_b: Blockout, o: Dictionary) -> void:
	var stage: String = o.stage
	var objective: int = o.objective
	var retry: bool = o.retry
	var fresh: bool = retry or o.get("restoring", false)      # a checkpoint load, not straight on from the release (Juniper is placed, not left mid-walk)
	cur_stage = stage
	sets.reset(stage, objective, retry)
	sec.reset()
	act2.reset(stage, objective, fresh)
	esc.reset(stage, objective, fresh)
	fly.stop()
	dive.stop()
	summit.reset(stage, objective, retry)
	chamber.reset(stage)
	towers.reset(stage, objective)
	tram.reset(stage, objective)
	var dead := stage == "escape"
	draw.stop(dead)
	if dead:      # Juniper is out: nothing feeds the sphere and it runs wild
		marks.unstable()
	else:
		marks.relight()
	if stage == "gamma":
		sec.arm_gate()
	var hacked := stage == "drum" or stage == "escape" or (stage == "docks" and objective > 3)      # (docks objective 3 = the hack)
	if vault != null:
		if hacked:
			vault.open(true)
		else:
			vault.reset()
	act2.door_s.lock(stage == "escape" or not hacked)
	if stage != "arrival":
		ff.stop()
		dock.reset()
	jet.equip(true)
	alarm_t = 0.0
	alarm_v = 0.0
	RenderingServer.global_shader_parameter_set(&"omni_alarm", 0.0)


func _alarm(s: float) -> void:      # (a short alarm never cuts a long one short)
	alarm_t = maxf(alarm_t, s)


func _pa_in(s: float, key: String) -> void:
	sets.after(s, func() -> void: audio.pa(key))


## ENGINE DIFFERENCE: the export keeps the JS's walls in separate meshes that lie on exactly the same planes (the assembly line's walls overlap over 570 m2; the freight door's panels share the wall's faces), and they fought for depth every frame. Each mesh moves a hair, under 5 mm, its own way, so one of two such faces always wins. Decals keep their place: they sit 5 mm off the wall they are on, which stays in front. Colliders do not move.
func _split_coplanar() -> void:
	var i := 0
	var walk: Array[Node] = [self]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var decal := false
		for sf in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(sf)
			if m != null and m.has_meta("extras") and (m.get_meta("extras") as Dictionary).has("poly_off"):
				decal = true
		if decal:
			continue
		mi.position += mi.get_parent_node_3d().global_basis.inverse() * (Vector3(1.0 + i % 5, 1.0 + i % 7, 1.0 + i % 11) * 0.0004) if mi.get_parent_node_3d() != null else Vector3.ZERO
		i += 1


func setup() -> void:
	_split_coplanar()
	# (hemi, sun, exposure: the export's own look, as the JS onMount set them. The density is put back: the export's tour ends on the opening drop's thin haze)
	Game.view.set_fog_exp2(Game.view.fog_color, .0017)
	Game.camera.far = 2400.0
	VhKit.adopt_lights(self)
	VhKit.unscale_sprites(self)
	for n: Node3D in node_named("om-hide"):
		n.visible = false
	for n: Node3D in node_named("freefall air"):
		n.visible = false
	for v: String in ["assault", "suppression", "elite"]:      # (the heavies' art, while the level loads)
		Game.enemy_views.add_batch(RobotGfx.heavy_gfx(v).batch)
	audio = OmAudio.new()
	add_child(audio)
	jet = JetpackKit.new(self, 1.0)
	craft = OmCraft.new(self)
	marks = OmMarks.new(self)
	sets = OmSets.new(self, audio, data.tanks)
	sec = OmSecurity.new(self, bo, audio, craft)
	var lamps: Array[OmDraw.Lamp] = []
	for q: Dictionary in data.lamps:
		var L := OmDraw.Lamp.new()
		L.base = q.base
		if q.has("light"):
			L.light = VhKit.light(self, q.light)
		else:
			for mi in VhKit.meshes(VhKit.one(self, q.cone)):
				L.cone = mi.get_active_material(0).duplicate()
				mi.material_override = L.cone
		lamps.append(L)
	var fields: Array[ShaderMaterial] = []
	for n: Node3D in node_named("om-glow"):
		for mi in VhKit.meshes(n):
			var m := mi.get_active_material(0) as ShaderMaterial
			if m != null:
				fields.append(m)
	draw = OmDraw.new(self, data.live_decks, lamps, fields, _on_draw_phase)
	act2 = OmAct2.new(self, bo, sec, sets, craft, audio, draw, marks, _alarm)
	chamber = OmChamber.new(self, OmAct2.J, sets, audio)
	act2.on_cuff = chamber.cuff
	act2.on_release = chamber.release
	esc = OmEscape.new(self, sec, sets, craft, audio, marks, act2, _alarm)
	summit = OmSummit.new(self, sec, sets, craft, audio, marks, act2, _alarm)
	summit_cine.S = summit
	cine_chain.L = self
	fly = OmFlyoff.new(self, summit, marks, act2.jun, audio, act2, _go_home)
	dive = OmDive.new(self, summit, audio, func(P: Player) -> void: fly.start(P))
	tram = OmTram.new(self, bo, sets, sec, audio, _alarm)
	towers = OmTowers.new(self, sec, sets, audio, marks, esc.bridge, _alarm)
	sky = OmSkyFoes.new(self, craft, audio)
	ff = OmFreefall.new(self, bo, craft, audio, sky)
	dock = OmDockhand.new(self, audio, _alarm)
	var pod := func(kind: String, x: float, y: float, z: float, yaw: float) -> void:
		var reach := 0.86 * 1.2 + 0.9      # X works standing in front of its face
		vendors.append({"kind": kind, "x": x, "y": y, "z": z, "prompt": {"x": x + sin(yaw) * reach, "z": z + cos(yaw) * reach, "r": 1.6}})
		var m := FointPod.build("armor" if kind == "foint-armor" else "ammo")      # (the export froze a copy of it: that one goes, below)
		m.scale = Vector3.ONE * 1.2
		m.position = Vector3(x, y, z)
		m.rotation.y = yaw
		add_child(m)
		_pods.append(m)
	for nm: String in ["foint-pod:ammo", "foint-pod:armor"]:
		for o: Node in node_named(nm):
			(o as Node3D).visible = false
	pod.call("foint-ammo", 12.0, 13.0, -82.7, 0.0)      # upper walkway, back to the north rail
	pod.call("foint-ammo", -156.9, 18.0, -59.5, PI / 2.0)      # shift room, west wall
	pod.call("foint-armor", -147.1, 18.0, -59.0, -PI / 2.0)      # shift room, east wall
	var pa := deg_to_rad(105.0)      # containment walkway, back to the outer rail, facing the plinth
	pod.call("foint-ammo", -200.0 + cos(pa) * 32.8, 18.0 + 4.5, -265.0 + sin(pa) * 32.8, atan2(-cos(pa), -sin(pa)))
	# CONTAINMENT 01's door is sealed: a SchleedTech terminal at the bridge end runs RAILJACK at its hardest (the plant is on alert); cracking it frees the drum's own blast door
	vault = bo.minigame_door({"game": "grind", "difficulty": 4, "length": 1200, "title": "CONTAINMENT 01", "seed": "omnisphere-containment-01", "door": false, "panel": {"x": -203.0, "y": 18.0, "z": -215.2, "yaw": 0.0},
		"on_open": func(quiet: bool) -> void:
			act2.door_s.lock(false)
			if not quiet:
				Game.hud.toast("CONTAINMENT 01  -  UNLOCKED")
				audio.play_at("kiosk", Vector3(-200, 19, -218))})
	# ---- security: the tower's two blast doors, the shift room door, drone bays, and the waves that come through them
	sec.blast_door(-39.35, -76.0, 13.0, 2.4, 3.2, "z", {"no_beacon": true})
	sec.blast_door(-52.65, -76.0, 13.0, 2.4, 3.2, "z", {"no_beacon": true})
	shift = sec.blast_door(-152.0, -54.75, 18.0, 2.4, 3.2, "x", {"auto": false})
	var bay := {
		"stack": sec.drone_bay(-3.0, 13.2, -35.0), "yard": sec.drone_bay(14.0, 8.0, -38.5), "up_a": sec.drone_bay(-13.0, 13.0, -82.4), "up_b": sec.drone_bay(10.0, 13.0, -82.4), "up_c": sec.drone_bay(-4.0, 13.0, -82.4), "roof": sec.drone_bay(-150.0, 24.6, -58.0),
		"dock_a": sec.drone_bay(-222.0, 18.0, -117.0), "dock_b": sec.drone_bay(-190.0, 18.0, -117.0),      # the north end of the freight docks, beyond the emitters
	}
	sec.build_gate(-161.0, 18.0, -46.0, -36.0, 12.0)
	# Travel waves (the player runs on while they play) name a goal: a drone bay behind him is never used, and a body left far behind stops holding up the objective.
	# yard1: the drones, and the dropship sets the goons down in the east yard at the same time (they are there before you can be: never behind you)
	sec.wave("yard1", [{"at": .4, "via": "bay", "bay": bay.stack, "rise": 5.0}, {"at": 1.6, "via": "bay", "bay": bay.yard, "rise": 6.0}, {"at": 0.0, "via": "ship", "in_t": 3.7, "from": [90.0, 42.0, -20.0], "hover": [22.0, 17.0, -54.0], "leave": [-30.0, 70.0, -150.0],
		"squad": [{"kind": "goon", "costume": "security", "gun": "smg", "land": [18.0, 8.5, -58.0]}, {"kind": "goon", "costume": "security", "gun": "pistol", "land": [27.0, 8.5, -52.0]}, {"kind": "goon", "costume": "hazmat", "land": [26.0, 8.5, -56.0]}]}],      # (landing spots on clear deck: the old ones were on the hauler's roof and a bollard)
		{"goal": A.ramp_top, "travel": true})
	sec.wave("yard2", [{"at": .5, "via": "bay", "bay": [bay.up_b, bay.up_a], "rise": 6.0}, {"at": 2.5, "via": "bay", "bay": [bay.up_b, bay.up_a], "rise": 5.0}], {"goal": A.ramp_top, "travel": true})      # (the yard's own bays are south of the ramp: behind him)
	sec.wave("bridge", [{"at": .3, "via": "bay", "bay": [bay.up_a, bay.up_c], "rise": 6.0}, {"at": 1.0, "via": "bay", "bay": [bay.up_b, bay.up_a, bay.up_c], "rise": 7.0}, {"at": 3.0, "via": "bay", "bay": [bay.up_c, bay.up_a], "rise": 5.0}, {"at": 4.5, "via": "bay", "bay": [bay.up_c, bay.up_a, bay.up_b], "rise": 6.0}], {"goal": A.tower_door_e, "travel": true})
	sec.wave("gamma", [
		{"at": .8, "via": "door", "door": shift, "kind": "robot", "heavy": "assault", "from": [-152.0, 18.0, -59.0], "path": [[-152.0, 18.0, -53.0], [-149.0, 18.0, -46.5]], "speed": 3.0},
		{"at": 2.6, "via": "door", "door": shift, "kind": "robot", "heavy": "suppression", "from": [-152.0, 18.0, -59.0], "path": [[-152.0, 18.0, -53.0], [-156.0, 18.0, -44.0]], "speed": 3.0},
		{"at": 7.0, "via": "bay", "bay": bay.roof, "rise": 6.0},
		{"at": 11.0, "via": "door", "door": shift, "kind": "robot", "heavy": "elite", "from": [-152.0, 18.0, -59.0], "path": [[-152.0, 18.0, -53.0], [-150.0, 18.0, -40.0]], "speed": 2.6},
		{"at": 4.0, "via": "door", "door": shift, "kind": "goon", "costume": "security", "gun": "pistol", "from": [-152.0, 18.0, -59.0], "path": [[-152.0, 18.0, -52.5], [-146.0, 18.0, -50.0]], "speed": 4.0},
		{"at": 4.8, "via": "door", "door": shift, "kind": "goon", "costume": "security", "gun": "smg", "from": [-152.0, 18.0, -59.0], "path": [[-152.0, 18.0, -52.5], [-158.0, 18.0, -48.0]], "speed": 4.0},
		{"at": 13.0, "via": "door", "door": shift, "kind": "goon", "costume": "hazmat", "from": [-152.0, 18.0, -59.0], "path": [[-152.0, 18.0, -53.0], [-148.5, 18.0, -49.5]], "speed": 3.0},
	])
	bo.stage({"id": "arrival", "name": "Receiving Pad 3", "spawn": A.spawn, "task": "Get into the facility.", "objectives": [
		{"id": "bail", "label": "Bail out", "kind": "custom", "text": "Tug 9 is being shot down with you in it. Out the back and down onto Receiving Pad 3. Steer, shoot what comes up at you, and roll (jump) out of the way of missiles.", "at": A.pad, "radius": 6.0, "guide": false,
			"on_start": func(_b: Blockout, _o: Dictionary) -> void:
				touched = false
				dock.spawn()
				ff.start(0.0, ff.died),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return ff.t >= OmFreefall.T_REPO or ff.landed},
		{"id": "repo", "label": "Repo-Man", "kind": "custom", "text": "The gunship came down after you. Shoot it down or ride it out: when the missile warning goes, roll.", "at": A.pad, "radius": 6.0, "guide": false, "spawn": [0.0, 6.1, 0.0],
			"on_start": func(_b: Blockout, o: Dictionary) -> void:
				if o.get("retry", false) or not ff.on:
					touched = false
					dock.spawn()
					ff.start(OmFreefall.T_REPO, true),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return ff.landed},
		{"id": "dockhand", "label": "Pad crew", "kind": "custom", "text": "Somebody was on a smoke break out here. He is going for the alarm.", "at": A.pad, "radius": 6.0, "guide": false, "spawn": [1.5, 6.1, 1.5],
			"on_start": func(_b: Blockout, o: Dictionary) -> void:
				if o.get("retry", false) or dock.R == null or dock.R.dead:
					touched = true
					ff.stop()
					dock.spawn(true),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return dock.dead},
		{"id": "gangway", "label": "Up the gangway", "text": "FOINT keeps something enormous in there, and it is plugged into everything. Head up the gangway.", "at": [0.0, 8.0, -25.0], "radius": 3.0,
			"on_start": func(_b: Blockout, o: Dictionary) -> void:
				if not o.get("retry", false):
					_pa_in(4.2, "arrival")
					Game.hud.toast("AEROLIFT-7: JUMP, THEN TAP A AGAIN AND HOLD IT TO BURN")},
	]})
	bo.stage({"id": "yard", "name": "Inspection Yard", "task": "Fight through the yard.", "objectives": [
		_wave_obj("yard1", "Yard security", "Drone bays are opening and a dropship is setting security down in the east yard. Shoot the drones down. The red fuel cells blow.", [6.0, 8.0, -31.0]),
		{"id": "gap", "label": "Jump the crevasse", "text": "Jump the crevasse to the east yard.", "at": [12.0, 8.5, -48.0], "radius": 3.0},
		_wave_obj("yard2", "Freight hauler", "More drones coming up by the stairs. Use the freight hauler for cover. Shoot the fuel cells when they bunch up.", [16.0, 8.5, -53.0]),
		{"id": "up", "label": "Upper walkway", "text": "Take the stairs up to the north walkway.", "at": A.ramp_top, "radius": 3.0, "via": [[21.5, 8.5, -64.0]]},
	]})
	bo.stage({"id": "bridge", "name": "Crane Bridge", "task": "Cross to the crane tower.", "spawn": {"x": 20.0, "y": 13.1, "z": -78.0, "yaw": -PI / 2.0}, "objectives": [
		_wave_obj("bridge", "Walkway drones", "More drone bays on the walkway. Clear them, then cross the bridge.", [0.0, 13.0, -79.0]),
		{"id": "door", "label": "Crane tower", "text": "Cross the bridge and get into the crane tower.", "at": A.tower_door_e, "radius": 2.5, "via": [[-30.0, 13.0, -76.0]]},
	]})
	bo.stage({"id": "bay", "name": "Inspection Bay", "task": "Through the crane tower.", "objectives": [
		{"id": "out", "label": "West door", "text": "Through the inspection bay and out the west door to the cableway. Jump, tap A again in the air and hold it to burn.", "at": A.tower_door_w, "radius": 2.5, "spawn": [-46.0, 13.1, -75.0]},
	]})
	bo.stage({"id": "cableway", "name": "Dead Cableway", "task": "Cross the magma to Checkpoint Gamma.", "spawn": {"x": -59.0, "y": 13.1, "z": -74.0, "yaw": -1.9}, "objectives": [
		{"id": "p1", "label": "Pylon 1", "text": "The old cableway. Burn across to the first pylon.", "at": A.p1, "radius": 2.6},
		{"id": "p2", "label": "Pylon 2 (live)", "text": "The next deck is wired into the Draw: when the lights stutter, get off it.", "at": A.p2, "radius": 2.6},
		{"id": "p3", "label": "Pylon 3", "text": "Keep moving.", "at": A.p3, "radius": 2.6, "on_done": func(_b: Blockout) -> void: sets.blow_p4()},
		{"id": "tram", "label": "The tram", "kind": "custom", "text": "Pylon 4 is gone and the cable with it. There is a freight tram at the Loop 2 siding beside this pylon: step onto its bed.", "at": tram.spots.board, "radius": 3.0,
			"on_start": func(_b: Blockout, _o: Dictionary) -> void: tram.arm(), "done": func(_b: Blockout, P: Player, _C: Combat) -> bool: return tram.riding(P)},
		{"id": "ride", "label": "The loop", "kind": "custom", "text": "The brakes are gone and it is not stopping. Drones off the pylons, goons on the signal gantry, a heavy on the rail. Stay on the bed.", "at": tram.spots.after_jump, "radius": 6.0, "guide": false, "spawn": tram.spots.board,
			"on_start": func(_b: Blockout, _o: Dictionary) -> void: tram.arm(), "done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return tram.past_jump()},
		{"id": "station", "label": "Checkpoint Gamma", "kind": "custom", "text": "It is coming in through the railing at Gamma and it will not stop. Get off before it hits the frame.", "at": [-132.0, 18.0, -44.0], "radius": 4.5, "spawn": tram.spots.after_jump,
			"on_start": func(_b: Blockout, _o: Dictionary) -> void: tram.arm(),
			"done": func(_b: Blockout, P: Player, _C: Combat) -> bool: return P.grounded and P.y > 17.8 and P.y < 18.5 and P.x < -125.0 and P.x > -162.0 and P.z < -21.0 and P.z > -61.0},
	]})
	var gw := _wave_obj("gamma", "Checkpoint security", "The shift room is emptying. Lure the heavies onto the green plates and let the Draw cook them. The goons wear rubber boots: the plates do nothing to them.", [-146.0, 18.0, -44.0])
	gw.on_start = func(_b: Blockout, _o: Dictionary) -> void:
		_alarm(8.0)
		sec.start_wave("gamma")
		_staff([[-140.0, -29.0], [-136.0, -55.0]])
	bo.stage({"id": "gamma", "name": "Checkpoint Gamma", "task": "Take the checkpoint.", "spawn": {"x": -129.0, "y": 18.1, "z": -46.0, "yaw": -1.6},
		"on_enter": func(_b: Blockout, _o: Dictionary) -> void: _pa_in(1.2, "gamma"), "objectives": [
		gw,
		{"id": "valves", "label": "Gate clamps", "kind": "custom", "text": "The gate is clamped shut. Shoot out the two glowing pressure valves on the lock rams.", "at": [-159.0, 18.0, -41.0], "radius": 3.0, "guide": false,
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return sec.gate_free()},
		{"id": "lever", "label": "Manual release", "kind": "hold", "text": "Clamps are off. Pull the manual release lever.", "prompt": "PULL THE RELEASE", "at": sec.gate.lever, "radius": 1.6, "hold": 2.2, "keep": true,
			"rate": func(_b: Blockout) -> float: return 1.0 if sec.gate_free() else 0.0,
			"on_start": func(_b: Blockout, o: Dictionary) -> void:
				if o.get("retry", false):
					sec.blow_clamps(),
			"on_done": func(_b: Blockout) -> void:
				sec.lever(1.0)
				sec.open_gate()
				_alarm(6.0)},
		{"id": "enter", "label": "Omnisphere access", "text": "The gate is open. Get inside.", "at": [-169.0, 18.0, -41.0], "radius": 3.0, "spawn": [-157.0, 18.1, -40.0],
			"on_start": func(_b: Blockout, _o: Dictionary) -> void:
				sec.blow_clamps()
				sec.open_gate()},
	]})
	# ---- act two: the line, the docks, containment, the collapse
	var rv: Array = []
	var q4 := [["assault", -44.3, -226.0, -50.0], ["assault", -37.7, -226.0, -32.0], ["suppression", -44.3, -221.0, -55.0], ["elite", -37.7, -219.0, -27.0]]
	for i in 4:      # two lanes either side of the belt, then they fan out
		var q: Array = q4[i]
		rv.append({"at": 1.0 + i * 1.1, "via": "door", "door": act2.freight, "kind": "robot", "heavy": q[0], "from": [-246.0, 18.0, q[1]], "path": [[-233.0, 18.0, q[1]], [-231.0, 18.0, q[3]], [q[2], 18.0, q[3]]], "speed": 2.8})
	rv.append_array([{"at": 8.0, "via": "bay", "bay": act2.bay_hall, "rise": 4.0},
		{"at": 14.0, "via": "door", "door": act2.freight, "kind": "robot", "heavy": "suppression", "from": [-246.0, 18.0, -41.0], "path": [[-233.0, 18.0, -41.0], [-225.0, 18.0, -36.0]], "speed": 2.8},
		{"at": 5.0, "via": "door", "door": act2.freight, "kind": "goon", "costume": "security", "gun": "smg", "from": [-246.0, 18.0, -44.3], "path": [[-233.0, 18.0, -44.3], [-222.0, 18.0, -52.0]], "speed": 4.2},
		{"at": 5.6, "via": "door", "door": act2.freight, "kind": "goon", "costume": "security", "gun": "smg", "from": [-246.0, 18.0, -37.7], "path": [[-233.0, 18.0, -37.7], [-222.0, 18.0, -30.0]], "speed": 4.2},
		{"at": 11.0, "via": "door", "door": act2.freight, "kind": "goon", "costume": "hazmat", "from": [-246.0, 18.0, -41.0], "path": [[-233.0, 18.0, -41.0], [-228.0, 18.0, -44.0]], "speed": 3.0}])
	sec.wave("review", rv)
	# the relay masts: a second dropship sets security down at the north end of the docks, between you and the bridge (never out of the hall door you just came through)
	sec.wave("relays", [{"at": .5, "via": "ship", "from": [-120.0, 58.0, -190.0], "hover": [-201.0, 26.5, -108.0], "leave": [-280.0, 80.0, -200.0],
		"squad": [{"kind": "goon", "costume": "security", "gun": "smg", "land": [-212.0, 18.0, -112.0]}, {"kind": "goon", "costume": "security", "gun": "pistol", "land": [-192.0, 18.0, -112.0]}, {"kind": "robot", "heavy": "assault", "land": [-202.0, 18.0, -110.0]}, {"kind": "goon", "costume": "hazmat", "land": [-208.0, 18.0, -106.0]}]}],
		{"goal": [-200.0, -118.0], "travel": true})
	# the docks: while the gunship works you over, more drones lift out of the bays at the north end (the hall door is behind you)
	sec.wave("dockside", [{"at": 12.0, "via": "bay", "bay": [bay.dock_a, bay.dock_b], "rise": 6.0}, {"at": 14.0, "via": "bay", "bay": [bay.dock_b, bay.dock_a], "rise": 7.0}], {"goal": [-200.0, -118.0], "travel": true})
	var rvo := _wave_obj("review", "Quarterly review", "The freight door is opening: a heavy formation. Mind the presses: they flatten anything on the belt. When the line goes haywire, the bodies on the hooks swing across the floor: time your crossings.", [-207.0, 18.0, -48.0])
	rvo.on_start = func(_b: Blockout, _o: Dictionary) -> void:
		_alarm(6.0)
		sec.start_wave("review")
		act2.haywire_in(7.0)
	rvo.on_done = func(_b: Blockout) -> void: act2.haywire_stop()
	bo.stage({"id": "line", "name": "Assembly Line", "task": "Get through the line.", "spawn": {"x": -181.0, "y": 18.1, "z": -41.0, "yaw": -PI / 2.0},
		"on_enter": func(_b: Blockout, _o: Dictionary) -> void: _pa_in(1.5, "review"), "objectives": [
		rvo,
		{"id": "exit", "label": "To the docks", "text": "North door, out to the freight docks.", "at": [-206.0, 18.0, -64.5], "radius": 2.8},
	]})
	bo.stage({"id": "docks", "name": "Freight Docks", "task": "Get to containment.", "spawn": {"x": -206.0, "y": 18.1, "z": -66.5, "yaw": PI},
		"on_enter": func(_b: Blockout, _o: Dictionary) -> void: _pa_in(.8, "docks"), "objectives": [
		{"id": "ship1", "label": "Gunship", "kind": "custom", "text": "GUNSHIP. Rockets do the job; the FOINT-N-SHOOT station at the west end of the dock restocks them. Red rings mark where its missiles land. Use the containers.", "at": [-205.0, 18.0, -92.0], "radius": 4.0, "guide": false,
			"on_start": func(_b: Blockout, _o: Dictionary) -> void:
				act2.launch_ship(0)
				sec.start_wave("dockside"),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return act2.ships_down(1)},
		{"id": "relays", "label": "Bridge lock", "kind": "custom", "text": "The bridge north is raised. Three glowing yellow emitters hold its lock: shoot all three and it comes down.", "at": [-200.0, 18.0, -118.0], "radius": 6.0, "guide": false, "spawn": [-205.0, 18.1, -92.0],
			"on_start": func(_b: Blockout, _o: Dictionary) -> void:
				towers.start()
				sec.start_wave("relays"),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return towers.done},
		{"id": "cross", "label": "The bridge", "text": "Bridge is down. Cross to containment.", "at": [-200.0, 18.0, -209.0], "radius": 5.0, "spawn": [-200.0, 18.1, -117.0]},
		{"id": "hack", "label": "Containment door", "kind": "custom", "text": "CONTAINMENT 01 is sealed behind SCHLEEDTECH BLACK ICE. Jack into the terminal beside the door (E / pad B) and ride the data line to the core: hop, jump, duck, and do not fall off.", "at": [vault.target.x, 18.0, vault.target.z], "radius": 2.5, "spawn": [-200.0, 18.1, -208.0],
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return not vault.locked},
		{"id": "bridge", "label": "Containment", "text": "Juniper is through that door.", "at": [-200.0, 18.0, -214.0], "radius": 3.5, "spawn": [-200.0, 18.1, -211.0]},
	]})
	bo.stage({"id": "drum", "name": "Containment", "task": "Free Juniper.", "spawn": {"x": -200.0, "y": 18.1, "z": -216.0, "yaw": PI},
		"on_enter": func(_b: Blockout, _o: Dictionary) -> void: _pa_in(.6, "drum"), "objectives": [
		{"id": "see", "label": "Juniper", "text": "There he is. Somebody is sitting with him: press X to talk, or walk up to the plinth to start.", "at": [-200.0, 18.0, -238.0], "radius": 4.0, "on_done": func(_b: Blockout) -> void: act2.say("hi")},
		{"id": "cuffs", "label": "Wrist cuffs", "kind": "custom", "text": "Shoot both glowing seals on each of his four wrist cuffs. Security will keep coming: every arm you free fights with you. Every cuff that comes off lets his current loose across the floor: get up on the plinth or in the air. It cooks the robots; the goons wear rubber boots.", "at": [-200.0, 18.0, -250.0], "radius": 4.0, "guide": false,
			"on_start": func(_b: Blockout, _o: Dictionary) -> void:
				sec.open_wave("finale")
				act2.arm_seals(false)
				act2.finale(true)
				_alarm(30.0),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return act2.arms_free()},
		{"id": "belt", "label": "The belt", "kind": "custom", "text": "The belt. Shoot its two seals.", "at": [-200.0, 18.0, -250.0], "radius": 4.0, "guide": false,
			"on_start": func(_b: Blockout, o: Dictionary) -> void:
				if o.get("retry", false):
					sec.open_wave("finale")
					act2.finale(true)
					for c: OmJuniper.Cuff in act2.jun.cuffs:
						if c.name != "belt":
							act2.jun.open_cuff(c)
				act2.arm_seals(true),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return act2.belt_free(),
			"on_done": func(_b: Blockout) -> void:
				act2.release()
				esc.release()},
	]})
	var SP: Dictionary = esc.spots
	var SM: Dictionary = summit.spots
	var at3 := func(p: Variant) -> Array:
		if p is Vector3:
			return [p.x, p.y, p.z]
		return [p.x, p.y, p.z]
	var sp3 := func(p: Vector3) -> Array: return [p.x, p.y + .1, p.z]
	var OX := OmMarks.OMNI.x
	var OZ := OmMarks.OMNI.z
	var on_podium := func(P: Player) -> bool: return U.hyp(P.x - OX, P.z - OZ) < 66.0 and P.y > 26.0 and P.y < 40.0      # fell off the conduit onto the podium
	var em_obj := func(n: int, label: String, text: String) -> Dictionary:
		var d := {"id": "em%d" % n, "label": label, "kind": "custom", "text": text, "at": at3.call(SM.ring_drop), "radius": 4.0, "guide": false,
			"on_start": func(_b: Blockout, _o: Dictionary) -> void:
				summit.ring(true)
				if n == 1:
					Game.hud.toast("SHOOT THE CAPACITORS WHEN THE SHUTTERS OPEN", 3.0),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return summit.ems_dead() >= n}
		if n == 1:
			d["spawn"] = sp3.call(SM.ring_drop)
		return d
	var pad: Dictionary = SP.pad
	bo.stage({"id": "escape", "name": "Collapse", "task": "Get out.", "spawn": {"x": -200.0, "y": 18.1, "z": -240.0, "yaw": -PI / 2.0},
		"on_enter": func(_b: Blockout, _o: Dictionary) -> void:
			esc.start()
			summit.start()
			_alarm(999.0), "objectives": [
		{"id": "out", "label": "The breach", "text": "The bridge is gone. He made his own door: through the hole in the west wall, and keep out from under him.", "at": [pad.x, pad.y, pad.z], "radius": 4.0},
		{"id": "climb", "label": "Up the outside", "text": "Maintenance brackets up the shell to the conduit gantry. The rusted ones tear loose: land, jump, burn.", "at": at3.call(SP.gantry), "radius": 3.6, "spawn": sp3.call(SP.climb_spawn)},
		{"id": "conduit", "label": "The siphon conduit", "text": "Run the top of the conduit to the sphere. When the line flares and the whine climbs, a surge is coming down it: be in the air when it passes you.", "at": at3.call(SP.corner), "radius": 4.5, "spawn": sp3.call(SP.gantry),
			"on_start": func(_b: Blockout, o: Dictionary) -> void:
				esc.conduit()
				if not o.get("retry", false):
					_pa_in(1.5, "draw")},
		{"id": "catch", "label": "Over the podium", "kind": "custom", "text": "The line over the podium is shearing off its supports. Keep running. He is right under it.", "at": at3.call(SP.catch_end), "radius": 2.4, "spawn": sp3.call(SP.corner),
			"on_start": func(_b: Blockout, _o: Dictionary) -> void: esc.conduit(),
			"done": func(_b: Blockout, P: Player, _C: Combat) -> bool:
				var ce: Vector3 = SP.catch_end
				return (U.hyp(P.x - ce.x, P.z - ce.z) < 4.5 and absf(P.y - ce.y) < 3.0) or on_podium.call(P)},
		{"id": "end", "label": "The feed riser", "text": "The conduit feeds the riser on the far side of the sphere: that tower lifts his current up to the ring round the sphere. Follow it.", "at": at3.call(SM.station), "radius": 4.0, "spawn": sp3.call(SP.catch_end), "on_start": func(_b: Blockout, _o: Dictionary) -> void: esc.conduit()},
		{"id": "lift", "label": "The service lift", "kind": "custom", "text": "Step into the lift cage. It goes all the way up. Hold on.", "at": at3.call(SM.cage), "radius": 2.6, "spawn": sp3.call(SM.station),
			"done": func(_b: Blockout, P: Player, _C: Combat) -> bool:
				summit.try_ride(P)
				return summit.jammed()},
		{"id": "ledges", "label": "Up the riser", "text": "The hoist is gone. Maintenance ledges up the tower: jump, burn, keep going.", "at": at3.call(SM.top), "radius": 4.0, "spawn": sp3.call(SM.jam)},
		{"id": "ring", "label": "The containment ring", "kind": "custom", "text": "Across the feed bridge and drop onto the ring. It turns: it carries you with it.", "at": at3.call(SM.ring_drop), "radius": 4.0, "spawn": sp3.call(SM.top),
			"done": func(_b: Blockout, P: Player, _C: Combat) -> bool: return summit.on_ring(P)},
		em_obj.call(1, "Field emitters", "Three field emitters hold his current in the core. Their shutters open to vent: shoot the capacitor bank inside while they are open."),
		em_obj.call(2, "Field emitters", "One down. Two to go."),
		em_obj.call(3, "Field emitters", "The last emitter. Then the whole thing lets go."),
		{"id": "jump", "label": "Jump", "kind": "custom", "text": "The ring is going. Your ride is right under you: over the railing and jump.", "at": at3.call(SM.ring_drop), "radius": 4.0, "guide": false, "spawn": sp3.call(SM.ring_drop),
			"on_start": func(_b: Blockout, o: Dictionary) -> void:
				summit.ring(true)
				if o.get("retry", false) or float(summit.st.final) < 0.0:
					summit.finale(),
			"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return fly.done},
	]})


func _wave_obj(id: String, label: String, text: String, at: Array) -> Dictionary:
	return {"id": id, "label": label, "kind": "custom", "text": text, "at": at, "radius": 4.0, "guide": false,
		"on_start": func(_b: Blockout, _o: Dictionary) -> void: sec.start_wave(id),
		"done": func(_b: Blockout, _P: Player, _C: Combat) -> bool: return sec.wave_done(id)}


## lab staff on the floor (FOINT goons in lab coats, not part of the kill wave): they panic and run for the alarm panel on the shift-room wall, east of the door (clear of its lane); slapping it sounds the plant alarm and calls every goon nearby. Not counted by the wave, so a tech who got away never holds up the objective.
func _staff(spots: Array) -> void:
	var E: Variant = Game.combat.enemies
	if E != null:
		E.goon_alarms = func() -> Array: return [[-147.4, -53.9]]
		E.on_goon_alarm = func(r: Variant) -> void:
			_alarm(8.0)
			audio.play_at("alarmShort", Vector3(shift.x, shift.y, shift.z))
			for o: Robot in E.robots:
				if not o.dead and o is FointGoon and o != r and (o.state == &"idle" or o.state == &"search"):
					o.known = Robot.Known.at(E.P.x, E.P.z) if E.P != null else null
					o.set_(&"alert")
	for q: Array in spots:
		bo.spawn({"x": q[0], "y": 18.0, "z": q[1]}, {"kind": "goon", "costume": "labcoat"})


func _on_draw_phase(ph: String) -> void:
	var P: Player = Game.player
	if ph == "warn":
		audio.play("draw")
		if not said_draw and cur_stage == "cableway":
			said_draw = true
			audio.pa("draw")
	if ph == "surge":
		marks.flare(1.0)
		var best: Variant = null
		var bd := 70.0
		for L: Dictionary in draw.live_decks:
			var d: float = U.hyp((float(L.x0) + float(L.x1)) / 2.0 - P.x, (float(L.z0) + float(L.z1)) / 2.0 - P.z) if P != null else 1e9
			if d < bd:
				bd = d
				best = L
		if best != null:
			audio.play_at("arc", Vector3((float(best.x0) + float(best.x1)) / 2.0, float(best.top) + 1.0, (float(best.z0) + float(best.z1)) / 2.0))


func _tick(dt: float, P: Player, C: Combat, b: Blockout) -> void:
	ff.update(dt, P)
	dock.update(dt, P)
	if ff.stalling:
		dock.notice()
	if ff.landed and not touched:
		touched = true
		dock.landed()
	jet.update(dt, P)
	if jet.on:      # (JS body.ffall:not(.ffstall) #jet-fuel: hidden through the drop and the jump; the cutscenes have the screen)
		jet.layer.visible = not ((ff.on and ff.phase != "stall") or dive.st_on or fly.on or summit.ins.on or Game.dialogue.on)
	marks.update(dt)
	var cam: Vector3 = Game.camera.global_position
	draw.update(dt, P, C, cam)
	sets.update(dt, P, C)
	sec.update(dt, P, C)
	act2.update(dt, P, C)
	esc.update(dt, P, C)
	summit.update(dt, P, C)
	chamber.update(dt)
	if float(summit.st.final) >= 0.0 and not dive.st_on and not dive.done and not fly.on and P != null and not P.dead and not summit.on_ring(P) and P.y < OmSummit.DECK - 1.2 and P.y > 20.0:      # off the ring once the containment is gone: the jump
		summit.snap_lifter(P)
		dive.start(P)
	dive.update(dt, P)
	fly.update(dt, P)
	towers.update(dt, P, C)
	for i in range(heavies.size() - 1, -1, -1):      # (JS updateHeavies: the lasers follow their robots, one whose robot was despawned goes)
		var h := heavies[i]
		if C == null or not C.enemies.robots.has(h.r):
			h.dispose()
			heavies.remove_at(i)
		else:
			h.tick(dt, P)
	var oid := String(b.cur_obj().get("id", ""))
	if oid == "lever":
		sec.lever(float(b.state.progress))
	if shift != null:      # the shift room (its gear machines) lets you in once the shift is dead
		shift.auto = cur_stage != "gamma" or oid != "gamma"
	alarm_t = maxf(0.0, alarm_t - dt)
	alarm_v = 1.0 if alarm_t > 0.0 else maxf(0.0, alarm_v - dt)
	RenderingServer.global_shader_parameter_set(&"omni_alarm", alarm_v)
	var alive := false
	if C != null and P != null:
		for r: Robot in C.enemies.robots:
			if not r.dead and U.hyp(r.x - P.x, r.z - P.z) < 70.0:
				alive = true
				break
	audio.combat = 1.0 if alive or alarm_t > 0.0 else 0.0
	audio.update_audio(dt, alarm_v)


func _complete(_b: Blockout) -> void:
	Game.hud.toast("OMNISPHERE  -  CANCELLED")
	sets.after(3.2, _go_home)


func _go_home() -> void:
	Game.doors.travel({"id": "omnisphere-home", "to": "hub", "label": "HOME"})


func tick_level(dt: float) -> void:
	_pods_t += dt
	var cam := Game.camera.global_position if Game.camera != null else Vector3.ZERO
	for m: FointPod in _pods:      # each pod animates only while near the camera and is hidden past CULL (JS levels/omnisphere/depots.js)
		var near := cam.distance_to(m.position) < 60.0
		m.visible = near
		if near:
			m.update_at(_pods_t, dt, Game.player)
