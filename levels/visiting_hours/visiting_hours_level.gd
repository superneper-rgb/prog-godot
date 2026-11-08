class_name VisitingHoursLevel
extends KitLevel
## VISITING HOURS (JS levels/visiting-hours/level.js): GOINT Saltmarsh Correctional, a stormy night. Prog drives out to a perch above the prison to get Oswald Fenn (GOINT claims adjuster, our informant, being beaten for names in the warden's office) out before he talks. This file is the stage flow and the per-frame script; vh_*.gd are the parts (layout = every number, storm, prison, car, audio, spotter, watchers, pipe, admin / people / inside, rush, lift, jammer, sniper + finale).

const OWNER := "visiting-hours"
const CITY := Vector2(-400.0, -3200.0)      # FOINT CITY, 41 km back the way we came (its glow on the horizon behind)
const W := VhLayout.W
const F1 := 3.0
const F2 := 9.0
const F3 := 15.0
const F4 := 21.0
const SEARCH := ["look", "fenn", "wayin", "patrol"]
const OUT_IN := ["foliage", "dressing", "approach", "pipe"]
const OUT_UNDER := ["foliage", "dressing", "approach", "scenery", "prison"]
const ALL_PARTS := ["foliage", "dressing", "approach", "pipe", "scenery", "prison"]
const SNIPERS := ["sniper", "legacy_sniper"]

var loadout: Array = []
var vh: Dictionary = {}
var audio: VhAudio
var vh_storm: VhStorm
var prison: VhPrison
var pipe: VhPipe
var admin: VhAdmin
var people: VhPeople
var inside: VhInside
var rush: VhRush
var lift: VhLift
var jammer: VhJammer
var inmates: VhInmates
var sniper: VhSniper
var finale: VhFinale
var watchers: VhWatchers
var spotter: VhSpotter
var dress: VhDress
var zip: ZiplineKit
var car: Variant = null      # Vehicles.Veh
var night_k := 0.0
var catch_t := 0.0
var caught_t := -1.0
var nag_t := 0.0
var lights_said := false
var clock := 0.0
var out_state := ""
var part_nodes := {}
var sun_last := -1.0
var water_last := -1.0
var scen: Dictionary = {}
var fur: Dictionary = {}
var bag_group: Node3D
var bag_solid: World.Solid
var bag_at := Vector2.ZERO
var face_m: StandardMaterial3D
var fade_board: Array[StandardMaterial3D] = []
var fade_tarp: Array[StandardMaterial3D] = []
var board_g: Array = []
var tarp_g: Node3D
var fade_k := {"board": 1.0, "tarp": 1.0}
var tarp_span: Array = [-8.4, -4.0]
var bax := 0.0
var baz := 0.0
var bfx := 0.0
var bfz := 0.0
var rx := 0.0
var rz := 0.0
var sa: Array = [0.0, 0.0, 0.0]
var perch: Array = []
var stair: Array = []
var pois := {}
var is_spots := {}
var acts := {}
var tgt4: StealthKit.Guard = null
var tun := {"on": false, "k": 0.0, "f": 1.0, "started": false, "tp": Vector3.ZERO, "tl": Vector3.ZERO}
var tun_shot := View.Shot.new()
var w4_door: Array = []
var cut_on := 0.0


var cine: Variant:
	get:
		if inside == null:
			return null
		if inside.cine.on:
			return inside.cine
		if finale != null and finale.on:
			return finale
		return zip


func kit_options() -> Dictionary:
	vh = (info.get("data", {}) as Dictionary).get("vh", {})
	VhLayout.load_paths(vh.layout)
	var s: Array = VhLayout.spot.start
	return {"id": "visiting-hours", "name": "VISITING HOURS", "spawn": {"x": s[0], "y": 1.0, "z": s[2], "yaw": s[3]}, "compact_guides": true, "fall_reset_y": -20.0,
		"hide_guides": func() -> bool: return zip.on or inside.cine.on or finale.on,
		"on_update": func(dt: float, P: Player, _C: Combat, b: Blockout) -> void: _tick_vh(dt, P, b)}


func _obj_id() -> String:
	return String(bo.cur_obj().get("id", ""))


func _stage_id() -> String:
	return String(bo.stages[int(bo.state.stage)].get("id", ""))


func _prepare() -> void:
	VhKit.adopt_lights(self)
	VhKit.unscale_sprites(self)
	audio = VhAudio.new()
	add_child(audio)
	VhCar.register(self)
	scen = vh.scen
	fur = vh.fur
	vh_storm = VhStorm.new(self, audio)
	prison = VhPrison.new(self, vh.prison)
	pipe = VhPipe.new(self, audio)
	admin = VhAdmin.new(self, vh.admin)
	people = VhPeople.new(self, admin, fur)
	inside = VhInside.new(self, admin, people, audio, fur)
	rush = VhRush.new(world, admin, audio)
	lift = VhLift.new(self, admin, audio)
	lift.feeds_live = func() -> bool: return inside.feeds_live
	jammer = VhJammer.new(self, admin, audio)
	inmates = VhInmates.new(self, admin)
	sniper = VhSniper.new(self, VhLayout.deck)
	var ls: Dictionary = (vh.watchers as Dictionary).car
	watchers = VhWatchers.new(self, world, prison, audio, ls.lamp)
	watchers.on_caught = func(why: String) -> void:
		audio.hush()
		audio.say("b-made-car" if why == "car" else ("b-made-tower" if why == "tower" else "b-made-guard"), {"urgent": true})
	dress = VhDress.new(self, vh.dress, admin.floors[&"f2"])
	finale = VhFinale.new(self, admin, people, sniper, audio, func() -> VhStorm: return vh_storm, VhLayout.deck)
	# the exported cable stays out of it: the kit builds its own
	for nm: String in ["zipline", "zipline cable"]:
		for n: Node3D in node_named(nm):
			n.visible = false
	var ap: Dictionary = (vh.appr as Dictionary).zip
	zip = ZiplineKit.new(self, {"from": ap.from, "to": ap.to, "land": ap.land, "sag": 0.8, "label": "RIDE THE LINE DOWN", "on_land": func() -> void: bo.flag("landed", true)})
	spotter = VhSpotter.new(self)
	spotter.pois = _spot_pois
	spotter.on_find = _on_found
	spotter.on_bare = func() -> void:
		if not audio.busy:
			audio.say("b-goggles")
	inside.on_find = func(what: String) -> void:
		if what == "camera":
			audio.say("b-camera")
		if what == "fenn":
			audio.say(["p-alive", "b-move"], {"on_done": func() -> void: bo.flag("fennSaid", true)})
	inside.on_loud = func(why: String) -> void:
		if why != "radio":
			audio.hush()
			audio.say(["r-lock", "b-cut"], {"urgent": true})
		else:
			audio.say("b-cut", {"urgent": true})
	# the indoor camera (the rig's room mode: a short boom that pulls in ahead of jambs): in the block, the pump room and the pipe
	world.camera_no_swing = true
	world.camera_room_dist = 4.0
	world.camera_room_lens_max = 2.85
	world.camera_zone_weight = func(p: Variant) -> float:
		if p == null:
			return 0.0
		var q := Vector3(p.x, p.y, p.z)
		return 1.0 if admin.in_block(q) or _in_pipe_zone(q) else 0.0
	for pt: String in ALL_PARTS:
		part_nodes[pt] = node_named("vhp-" + pt)
	bag_group = VhKit.one(self, "vh-kitbag")
	var kb: Dictionary = scen.kitBag
	bag_at = Vector2(kb.at[0], kb.at[1])
	var ss: Array = VhKit.solids(world).get("kitbag", [])
	bag_solid = ss[0] if not ss.is_empty() else null
	tarp_span = scen.get("tarpSpan", tarp_span)
	perch = scen.perch
	stair = scen.stairFoot
	# ---- the billboard face fades while Prog is on the catwalk in front of it and the camera boom is behind it
	board_g = [VhKit.one(self, "vh-board-fade"), VhKit.one(self, "vh-board-face")]
	for n: Node3D in board_g:
		fade_board.append_array(VhKit.own_std(n))
	for m: StandardMaterial3D in fade_board:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	tarp_g = VhKit.one(self, "vh-tarp")
	fade_tarp = VhKit.own_std(tarp_g)
	for m: StandardMaterial3D in fade_tarp:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	var fm := VhKit.meshes(VhKit.one(self, "vh-board-face"))
	if not fm.is_empty():
		face_m = fm[0].get_active_material(0) as StandardMaterial3D
	var a0 := VhLayout.to_w(0.0, 0.0)
	var a1 := VhLayout.to_w(0.0, 1.0)
	var a2 := VhLayout.to_w(1.0, 0.0)
	bax = a0.x
	baz = a0.y
	bfx = a1.x - bax
	bfz = a1.y - baz
	rx = a2.x - bax
	rz = a2.y - baz
	sa = admin.pt(193.0, F2, 967.9)      # Stair A's door on 2F: the radio check (world)
	var off := VhLayout.office()
	pois = {
		"fenn": {"id": "fenn", "at": Vector3(off.x, off.y, off.z), "r": 3.2, "label": "ADMIN · TOP FLOOR · LIT WINDOW", "hold": 1.1},
		"gate": {"id": "gate", "at": Vector3(W - 7.0, VhLayout.PAD + 3.0, float(VhLayout.GATE.z)), "r": 8.0, "label": "WEST GATE · SALLY PORT", "hold": 1.0},
		"pipe": {"id": "pipe", "at": Vector3(VhLayout.OUTFALL.x - 0.7, 1.2, VhLayout.OUTFALL.y), "r": 2.4, "label": "CANAL · OUTFALL · DRAIN PIPE", "hold": 1.0},
		"car": {"id": "car", "at": Vector3.ZERO, "r": 4.0, "label": "LEVEE ROAD · PATROL CAR", "hold": 1.4},
	}


func _in_pipe_zone(p: Vector3) -> bool:
	return p.y < VhLayout.PAD - 0.1 and p.x > float(VhLayout.PIPE.x0) - 1.0 and p.x < float(VhLayout.PUMP.x1) + 0.5 and p.z > float(VhLayout.PUMP.z0) - 0.5 and p.z < float(VhLayout.PUMP.z1) + 0.5


func _spot_pois() -> Array:
	var id := _obj_id()
	if id == "fenn":
		return [pois.fenn]
	if id == "wayin":
		return [pois.gate, pois.pipe]
	if id == "patrol":
		pois.car.at = Vector3(watchers.car.global_position.x, VhLayout.LEVEE + 1.0, watchers.car.global_position.z)
		return [pois.car]
	return []


func _on_found(p: Dictionary) -> void:
	match String(p.id):
		"fenn":
			audio.say(["p-fenn", "b-warden"], {"on_done": func() -> void:
				prison.office.set_state("window")
				audio.say(["p-stare", "b-stare"], {"on_done": func() -> void: bo.flag("wantBlind", true)})})
		"gate":
			audio.say(["p-gate", "b-hearse", "p-box", "b-optimistic"], {"on_done": _drain_hint})
		"pipe":
			audio.say(["p-pipe", "b-pipe"], {"on_done": func() -> void: bo.flag("pipeSaid", true)})
		"car":
			audio.say(["p-car", "b-car"], {"on_done": func() -> void: bo.flag("carSaid", true)})


# the nudge toward the drain: after the gate is ruled out, or after a while with nothing found
func _drain_hint() -> void:
	if _obj_id() == "wayin" and not spotter.found.has("pipe") and not bo.flag("drainSaid"):
		bo.flag("drainSaid", true)
		audio.say("b-drain")


func _first_look() -> void:
	if not bo.flag("scoped"):
		bo.flag("scoped", true)
		audio.say(["p-breathing", "b-thermos2"])


# ---- the contact's kit bag under the tarp: the Phantom Suit (worn from here on), and a bolt sniper for a Prog who came without one
func _kit_up(equip: bool = false) -> void:
	if not ArmorStore.is_equipped("phantom_suit"):
		ArmorStore.owned["phantom_suit"] = true
		ArmorStore.equip("phantom_suit")
	var cb: Combat = Game.combat
	if cb == null:
		return
	var have := -1
	for id: String in SNIPERS:
		var i := Weapons.index_of(id)
		if i >= 0 and cb.owned.has(i):
			have = i
			break
	if have < 0:
		var i := Weapons.index_of("legacy_sniper")
		if i >= 0 and cb.give(i) >= 0:
			have = i
	if equip and have >= 0:
		cb.equip(have)


func _bag_out(out: bool) -> void:
	bag_group.visible = not out
	if bag_solid != null:
		bag_solid.set_off(out)


func _board_z(x: float, z: float) -> float:      # metres in front of the board's foot (the face is at +.2 .. +.42)
	return (x - bax) * bfx + (z - baz) * bfz


func _board_x(x: float, z: float) -> float:
	return (x - bax) * rx + (z - baz) * rz


func _ease_fade(key: String, want: float, dt: float, list: Array[StandardMaterial3D], nodes: Array) -> void:
	var k0: float = fade_k[key]
	var k := want if absf(want - k0) < 0.003 else k0 + (want - k0) * minf(1.0, dt * 9.0)
	if k == k0:
		return
	fade_k[key] = k
	for m in list:
		m.albedo_color.a = k
	for n: Node3D in nodes:
		n.visible = k > 0.02


func _board_fade(dt: float, P: Player) -> void:
	var c := Game.camera.global_position if Game.camera != null else Vector3.ZERO
	var on := Game.camera != null and P != null and P.y > VhLayout.deck - 1.5 and P.y < VhLayout.deck + 1.5
	var pz := _board_z(P.x, P.z) if on else 0.0
	var px := _board_x(P.x, P.z) if on else 0.0
	_ease_fade("board", 0.1 if on and pz > 0.3 and _board_z(c.x, c.z) < 0.55 else 1.0, dt, fade_board, board_g)
	# under the tarp (or the boom over it): it fades so the camera never sits behind a sheet of canvas
	_ease_fade("tarp", 0.15 if on and pz > 0.3 and px > float(tarp_span[0]) - 1.2 and px < float(tarp_span[1]) + 1.2 and c.y > VhLayout.deck + 1.7 else 1.0, dt, fade_tarp, [tarp_g])


## put the rental (and Prog) where a checkpoint needs them: [x, y, z, yaw], drive = Prog at the wheel, lights on/off
func _place_car(spot_: Array, drive: bool = true, lights: bool = true) -> void:
	var V: Vehicles = Game.vehicles
	if V.driving:
		V.exit(true)
	audio.hush()      # (a checkpoint: what was still to be said belongs to the old run)
	var y: float = float(spot_[1]) + 0.05
	if car == null or not V.vehicles.has(car):
		car = V.spawn(VhCar.CAR, spot_[0], spot_[2], spot_[3], y, {"owner": OWNER, "parent": self, "solid": true})
	else:
		car.x = spot_[0]
		car.y = y
		car.z = spot_[2]
		car.yaw = spot_[3]
		car.vx = 0.0
		car.vz = 0.0
		car.vy = 0.0
		car.yaw_rate = 0.0
		car.speed = 0.0
		car.f = 0.0
		car.l = 0.0
		car.steer = 0.0
		car.home = Vector4(spot_[0], spot_[1], spot_[2], spot_[3])
	car.model.set_lights.call(lights)
	catch_t = 0.0
	caught_t = -1.0
	lights_said = not lights
	if drive:
		var P: Player = Game.player
		if P != null:
			P.x = spot_[0]
			P.y = float(spot_[1]) + 0.1
			P.z = spot_[2]
			P.yaw = spot_[3]
		V.enter(car, {"instant": true})


func _fresh(retry: bool) -> bool:
	return retry or car == null


func _parked(retry: bool) -> void:
	if _fresh(retry):
		_place_car(VhLayout.spot.park, false, false)


func _start_at(s: Array, yaw: float) -> void:
	var P: Player = Game.player
	if P != null:
		P.x = s[0]
		P.y = float(s[1]) + 0.1
		P.z = s[2]
		P.yaw = yaw
		P.vx = 0.0
		P.vz = 0.0
		P.vy = 0.0


func setup() -> void:
	_prepare()
	_stage_drive()
	_stage_vantage()
	_stage_getin()
	_stage_inside()
	_stage_rush()
	_stage_holding()
	_stage_warden()
	_stage_finale()
	_actions()


func _stage_drive() -> void:
	var S: Dictionary = VhLayout.spot
	var turn: Array = S.turn
	var park: Array = S.park
	var at10 := VhLayout.at(VhLayout.track, 10.0)
	var top := VhLayout.at(VhLayout.track, VhLayout.track.len_ - 2.0)
	var thermos: Array = scen.thermos
	bo.stage({"id": "drive", "name": "The Drive", "spawn": {"x": S.start[0], "y": 1.0, "z": S.start[2], "yaw": S.start[3]}, "task": "Get to the perch above Saltmarsh Correctional.",
		"on_enter": func(_a: Variant, _o: Dictionary) -> void:
			prison.mode = "hill"
			pipe.run(false),
		"objectives": [
			{"id": "road", "label": "The causeway", "text": "Drive to the vantage point.", "at": [turn[0], VhLayout.ROAD_Y, turn[2]], "radius": 7.0,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					if _fresh(o.get("retry", false)):
						_place_car(S.start)
					audio.hush()
					audio.say(["b-onroad", "p-oneroad", "b-fenn", "p-adjuster", "b-caught", "p-lawyer", "b-fists", "p-flattered"])},
			{"id": "dark", "label": "Lights out", "text": "Kill the headlights before the hill: R (pad X).", "kind": "custom", "at": [turn[0], VhLayout.ROAD_Y, turn[2]], "radius": 4.0, "guide": false, "spawn": turn.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					if _fresh(o.get("retry", false)):
						_place_car(turn)
						audio.hush()
						bo.flag("reveal", true)
						bo.flag("track", true)
					nag_t = 7.0
					lights_said = false
					audio.say("b-lights", {"urgent": true}),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return car != null and not car.model.lights},
			{"id": "climb", "label": "Billboard Hill", "text": "Take the dirt track up the hill. Lights off.", "at": [VhLayout.PLAT.x, VhLayout.PLAT_Y, VhLayout.PLAT.z], "radius": 6.0, "via": [[at10.x, 1.0, at10.z], [top.x, VhLayout.PLAT_Y, top.z]], "spawn": turn.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					if _fresh(o.get("retry", false)):
						_place_car(turn, true, false)},
			{"id": "park", "label": "Park it", "text": "Park behind the billboard and get out: E.", "kind": "custom", "at": [park[0], VhLayout.PLAT_Y, park[2]], "radius": 4.0, "spawn": park.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					if _fresh(o.get("retry", false)):
						_place_car(park, true, false)
					audio.say("b-park"),
				"done": func(_b: Variant, P: Player, _C: Variant) -> bool: return not Game.vehicles.driving and P != null and U.hyp(P.x - float(VhLayout.PLAT.x), P.z - float(VhLayout.PLAT.z)) < float(VhLayout.PLAT.r) + 1.0 and P.y > VhLayout.PLAT_Y - 1.0},
			{"id": "perch", "label": "The perch", "text": "Climb the service stair to the catwalk.", "at": [perch[0], perch[2], perch[1]], "radius": 1.6, "via": [[stair[0], stair[2], stair[1]]], "spawn": [stair[0], float(stair[2]) + 0.1, stair[1]],
				"on_start": func(_b: Variant, o: Dictionary) -> void: _parked(o.get("retry", false)),
				"on_done": func(_b: Variant) -> void: audio.say(["p-thermos", "b-thermos"])},
			{"id": "thermos", "label": "The thermos", "text": "X: the thermos.", "kind": "custom", "at": [thermos[0], scen.thermosY, thermos[1]], "radius": 1.4, "spawn": [perch[0], float(perch[2]) + 0.1, perch[1]],
				"on_start": func(_b: Variant, o: Dictionary) -> void: _parked(o.get("retry", false)),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return bo.flag("drained") == true},
		]})


# ---- section 2: the vantage. Suit up from the contact's bag, then look before you leap: goggles on, sniper scope up, find Fenn, a way in and the patrol; then the contact's line down into the marsh
func _after(retry: bool, fn: Callable = Callable()) -> void:
	_parked(retry)
	_kit_up()
	_bag_out(true)
	if retry and fn.is_valid():
		fn.call()


func _stage_vantage() -> void:
	var ps: Array = [perch[0], float(perch[2]) + 0.1, perch[1]]
	var pa: Array = [perch[0], VhLayout.deck, perch[1]]
	var ap: Dictionary = (vh.appr as Dictionary).zip
	var closed := func() -> void:
		prison.office.set_state("closed")
		_kit_up(true)
	bo.stage({"id": "vantage", "name": "The Vantage", "spawn": {"x": ps[0], "y": ps[1], "z": ps[2], "yaw": VhLayout.board_yaw}, "task": "Scout Saltmarsh from the perch.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			prison.mode = "hill"
			pipe.run(false)
			watchers.reset(true, 0.7)
			spotter.reset()
			if o.get("retry", false):
				audio.hush(),
		"objectives": [
			{"id": "suit", "label": "The kit bag", "text": "X: the contact's kit bag under the tarp.", "kind": "custom", "at": [bag_at.x, VhLayout.deck, bag_at.y], "radius": 1.2, "spawn": ps,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_parked(o.get("retry", false))
					_bag_out(false)
					audio.say("b-suit"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return bo.flag("suited") == true},
			{"id": "look", "label": "Eyes on", "text": "Goggles on (N / D-pad down), then look down the sniper scope (right mouse / LT).", "kind": "custom", "guide": false, "at": pa, "spawn": ps,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_after(o.get("retry", false))
					_kit_up(true)
					audio.say("b-scope"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return spotter.on},
			{"id": "fenn", "label": "Find Fenn", "text": "Find Fenn: the lit window, top floor of the admin block.", "kind": "custom", "guide": false, "at": pa, "spawn": ps,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_after(o.get("retry", false), func() -> void:
						prison.office.set_state("beat")
						_kit_up(true))
					audio.say("b-findfenn"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return bo.flag("blindSaid") == true},
			{"id": "wayin", "label": "A way in", "text": "Find a way in.", "kind": "custom", "guide": false, "at": pa, "spawn": ps,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_after(o.get("retry", false), closed)
					audio.say("b-wayin"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return bo.flag("pipeSaid") == true},
			{"id": "patrol", "label": "The patrol", "text": "Watch the levee road.", "kind": "custom", "guide": false, "at": pa, "spawn": ps,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_after(o.get("retry", false), closed)
					audio.say("b-watch"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return bo.flag("carSaid") == true},
			{"id": "zip", "label": "The line down", "text": "X at the west end of the catwalk: ride the contact's line down.", "kind": "custom", "at": [ap.from[0], VhLayout.deck, ap.from[2]], "radius": 1.4, "spawn": ps,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_after(o.get("retry", false), func() -> void: prison.office.set_state("closed"))
					audio.say(["b-zip", "p-zip", "b-zip2", "p-zip2"])
					zip.reset(),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return bo.flag("landed") == true},
		]})


# ---- section 3: getting in. Under the searchlights to the levee, along the canal past the guard, up the pipe against the surges, into the pump room
func _stage_getin() -> void:
	var land: Array = (vh.appr as Dictionary).zip.land
	var canal_at: Array = [W - 18.0, 0.1, VhLayout.OUTFALL.y - 2.0]
	var mouth: Array = [W - 18.0 + 1.0, 0.1, VhLayout.OUTFALL.y]
	var corner := VhLayout.at(VhLayout.ring_road, VhLayout.nearest(VhLayout.ring_road, 158.0, 911.0).s)
	var P_: Dictionary = VhLayout.PUMP
	var pump_at: Array = [(float(P_.x0) + float(P_.x1)) / 2.0, 0.0, (float(P_.z0) + float(P_.z1)) / 2.0]
	bo.stage({"id": "getin", "name": "Getting In", "spawn": {"x": land[0], "y": 0.2, "z": land[2], "yaw": 0.0}, "task": "Get inside Saltmarsh unseen.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			var retry: bool = o.get("retry", false)
			prison.mode = "field"
			_parked(retry)
			_kit_up()
			_bag_out(true)
			watchers.reset()
			inside.reset(false)
			admin.unlock("pump", false)
			pipe.run(false)
			if retry:
				prison.office.set_state("closed"),
		"objectives": [
			{"id": "field", "label": "The field", "text": "Cross the field to the levee. Crouch in the tall reeds when a light comes.", "at": [corner.x, VhLayout.LEVEE, corner.z], "radius": 4.0, "spawn": [land[0], 0.2, land[2]],
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					if o.get("retry", false):
						_start_at(land, 0.2)
					audio.say("b-land")},
			{"id": "canal", "label": "The canal", "text": "Down into the canal. Follow it north to the drain pipe.", "at": canal_at, "radius": 2.4, "strict": true, "spawn": [corner.x, VhLayout.LEVEE + 0.1, corner.z],
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					if o.get("retry", false):
						_start_at([corner.x, VhLayout.LEVEE, corner.z], 0.0)
					audio.say("b-canal")},
			{"id": "pipe", "label": "The pipe", "text": "Up the pipe to the pump room.", "kind": "custom", "at": pump_at, "radius": 2.0, "spawn": mouth,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					if o.get("retry", false):
						_start_at(mouth, PI / 2.0)
						watchers.reset(false)
					pipe.run(true)
					audio.say(["p-bars", "b-pumps"]),
				"done": func(_b: Variant, P: Player, _C: Variant) -> bool: return P != null and P.x > float(P_.x0) + 0.8 and P.z > float(P_.z0) and P.z < float(P_.z1) and P.y < 1.5,
				"on_done": func(_b: Variant) -> void: audio.say(["p-in", "b-in", "p-visiting"])},
			{"id": "door", "label": "The basement door", "text": "The basement door.", "at": [float(P_.x1) - 0.8, 0.0, pump_at[2]], "radius": 1.2, "spawn": [float(P_.x0) + 2.0, 0.1, pump_at[2]],
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					if o.get("retry", false):
						_start_at([float(P_.x0) + 2.0, 0.0, pump_at[2]], PI / 2.0)
						watchers.reset(false)
					pipe.run(true)},
		]})


func _a3(x: float, y: float, z: float) -> Array:
	return admin.pt(x, y, z)


func _sp(k: String) -> Array:
	return (is_spots[k] as Array).slice(0, 3)


func _go(k: String) -> void:
	var q: Array = is_spots[k]
	_start_at(q, q[3])


func _reset_in(retry: bool, released: bool = false, dale_down: bool = false) -> void:
	if retry:
		audio.hush()
		inside.reset(true, released, dale_down)


# ---- section 4: inside, quiet. Up out of B1, the control room on 1F (Dale, his cameras, the door board), across the claims floor on 2F to Stair A
func _stage_inside() -> void:
	var k1 := VhLayout.ADK
	var K := {"b1": [200.8, 0.0, 961.0, PI / 2.0], "stairB1": [216.4, 0.0, 961.4, PI], "f1": [216.4, F1, 961.4, -PI / 2.0], "control": [204.2, F1, 962.0, 0.0], "console": [206.8, F1, 966.2, 0.0], "f2": [216.4, F2, 961.4, -PI / 2.0], "stairA": [193.0, F2, 967.4, 0.0]}
	var spots: Dictionary = fur.spots
	for k: String in K:
		var v: Array = K[k]
		if k == "b1":
			is_spots[k] = v
		elif k == "console":
			var st: Array = spots.stand
			is_spots[k] = [st[0], st[1], st[2], v[3]]
		else:
			var q := _a3(v[0], v[1], v[2])
			is_spots[k] = [q[0], q[1], q[2], v[3]]
	var SB: Dictionary = VhLayout.STAIR_B
	var sbx := float(SB.x0) - 0.6
	var sbd: float = SB.door
	var b1: Array = is_spots.b1
	bo.stage({"id": "inside", "name": "Inside", "spawn": {"x": b1[0], "y": float(b1[1]) + 0.1, "z": b1[2], "yaw": b1[3]}, "task": "Find Fenn. Quietly.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			var retry: bool = o.get("retry", false)
			prison.mode = "field"
			_parked(retry)
			_kit_up()
			_bag_out(true)
			pipe.run(false)
			watchers.reset(false)
			lift.reset()
			jammer.reset()
			people.surrender(false)
			finale.reset()
			if not retry:
				inside.reset(),
		"objectives": [
			{"id": "basement", "label": "B1", "text": "Find a way up out of the basement.", "at": _a3(sbx, 0.0, sbd), "radius": 1.3 * k1, "dy": 1.2, "spawn": _sp("b1"),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_reset_in(o.get("retry", false))
					if o.get("retry", false):
						_go("b1")},
			{"id": "ground", "label": "1F", "text": "Up Stair B to 1F.", "at": _a3(sbx, F1, sbd), "radius": 1.3 * k1, "dy": 1.2, "via": [VhLayout.s3(216.0, 0.0, 961.4), VhLayout.s3(217.6, 1.5, 957.4), VhLayout.s3(215.6, F1, 961.4)], "spawn": _sp("stairB1"),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_reset_in(o.get("retry", false))
					if o.get("retry", false):
						_go("stairB1")},
			{"id": "control", "label": "Control", "text": "Find the control room.", "at": _a3(204.2, F1, 963.3), "radius": 1.2 * k1, "dy": 1.2, "spawn": _sp("f1"),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_reset_in(o.get("retry", false))
					if o.get("retry", false):
						_go("f1")},
			{"id": "operator", "label": "The operator", "text": "Take out the operator. From behind: X.", "kind": "custom", "guide": false, "at": spots.dale, "spawn": _sp("control"),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_reset_in(o.get("retry", false))
					if o.get("retry", false):
						_go("control"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return inside.dale == null or inside.dale.dead},
			{"id": "cctv", "label": "The cameras", "text": "X at the console: the cameras. Find Fenn.", "kind": "custom", "at": spots.console, "radius": 1.4, "spawn": _sp("console"),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_reset_in(o.get("retry", false), false, true)
					if o.get("retry", false):
						_go("console")
					elif not inside.loud:
						audio.say("b-eyes"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return bo.flag("fennSaid") == true},
			{"id": "doors", "label": "The door board", "text": "Release Stair B at the door board: X.", "kind": "custom", "at": spots.board, "radius": 1.4, "spawn": _sp("console"),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_reset_in(o.get("retry", false), false, true)
					if o.get("retry", false):
						_go("console"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return inside.released},
			{"id": "up", "label": "2F", "text": "Up Stair B to 2F.", "at": _a3(sbx, F2, sbd), "radius": 1.3 * k1, "dy": 1.2, "via": [VhLayout.s3(215.6, F1, 961.4), VhLayout.s3(217.6, F1 + 3.0, 955.4), VhLayout.s3(215.6, F2, 961.4)], "spawn": _sp("console"),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_reset_in(o.get("retry", false), true, true)
					if o.get("retry", false):
						_go("console")},
			{"id": "stairA", "label": "Stair A", "text": "Cross the claims floor to Stair A.", "kind": "custom", "at": sa, "radius": 1.2 * k1, "spawn": _sp("f2"),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_reset_in(o.get("retry", false), true, true)
					if o.get("retry", false):
						_go("f2"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return bo.flag("lockedDown") == true},
		]})


# ---- section 5: the rush. The lockdown is on and the jammer is up (no Boss): GOINT comes for you through Stair A, which is the way up. Checkpoints here put the lockdown back on quietly
func _lockdown(retry: bool, s: Array) -> void:
	if not retry:
		return
	audio.hush()
	inside.reset(false, true, true)
	rush.reset()
	inside.go_loud("radio", null, true)
	_start_at(s, s[3])


func _stage_rush() -> void:
	var k1 := VhLayout.ADK
	var t0 := _a3(201.9, F2, 965.4)
	var team: Array = [t0[0], t0[1], t0[2], -1.18]
	var w0 := VhLayout.s3(193.4, F2, 969.6)
	var well: Array = [w0[0], w0[1], w0[2], 0.0]
	var p0 := VhLayout.s3(193.6, F3, 969.6)
	var top: Array = [p0[0], p0[1], p0[2], 0.0]
	var sa_up := [VhLayout.s3(191.6, F2, 970.4), VhLayout.s3(191.6, F2 + 3.0, 974.9), VhLayout.s3(194.4, F2 + 3.0, 974.9)]
	var sa3 := VhLayout.s3(193.6, F3, 969.5)
	var sa4 := VhLayout.s3(193.6, F4, 969.5)
	bo.stage({"id": "rush", "name": "The Rush", "spawn": {"x": team[0], "y": float(team[1]) + 0.1, "z": team[2], "yaw": team[3]}, "task": "Get to the warden's office.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			var retry: bool = o.get("retry", false)
			prison.mode = "field"
			_parked(retry)
			_kit_up()
			_bag_out(true)
			pipe.run(false)
			watchers.reset(false)
			lift.reset()
			jammer.reset()
			people.surrender(false)
			finale.reset()
			if not retry:
				rush.reset(),
		"objectives": [
			{"id": "team", "label": "Response team", "text": "Stair A is opening. Hold the claims floor.", "kind": "custom", "at": sa, "radius": 1.2 * k1, "spawn": team.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_lockdown(o.get("retry", false), team)
					rush.start("team"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return rush.done("team"),
				"on_done": func(_b: Variant) -> void: audio.say("p-door")},
			{"id": "well", "label": "Stair A", "text": "Up Stair A.", "kind": "custom", "at": sa3, "radius": 1.2 * k1, "via": sa_up, "spawn": well.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_lockdown(o.get("retry", false), well)
					if o.get("retry", false):      # (the team came through it)
						admin.unlock("saF2", true),
				"done": func(_b: Variant, P: Player, _C: Variant) -> bool: return rush.done("well") and P != null and admin.in_stair_a(Vector3(P.x, P.y, P.z)) and P.y > float(VhLayout.FLW[&"f3"]) - 0.3},
			{"id": "shutter", "label": "4F", "text": "Up to 4F.", "at": sa4, "radius": 1.2 * k1, "via": [VhLayout.s3(191.6, F3 + 3.0, 974.9), VhLayout.s3(194.4, F3 + 3.0, 974.9)], "spawn": top.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void: _lockdown(o.get("retry", false), top),
				"on_done": func(_b: Variant) -> void: audio.say("p-shutter")},
		]})


# ---- section 5, stage 2: 3F, HOLDING. The old jail's tier (the inmates stay locked in), the tier desk's override on the lift the lockdown parked on 4F, holding the tier while it crawls down, the ride up with the box
func _in3(P: Player) -> bool:      # (through the 3F door, in the station)
	return P != null and absf(P.y - float(VhLayout.FLW[&"f3"])) < 1.2 and P.z < VhLayout.ad_z(968.6) and P.x < VhLayout.ad_x(float(VhLayout.STAIR_A.x1) + 3.0)


func _hold3(retry: bool, s: Array, lift0: String) -> void:
	_lockdown(retry, s)
	if retry:
		admin.unlock("saF2", true)
		admin.unlock("saF3", true)
		lift.reset(lift0)
		jammer.reset()
		people.surrender(false)
		finale.reset()


func _stage_holding() -> void:
	var k1 := VhLayout.ADK
	var l0 := VhLayout.s3(193.6, F3, 969.8)
	var land: Array = [l0[0], l0[1], l0[2], PI]
	var dk: Array = (fur.spots as Dictionary).desk3
	var desk: Array = [dk[0], dk[1], dk[2], PI / 2.0]
	var l1 := _a3(203.2, F3, 974.1)
	var lobby: Array = [l1[0], l1[1], l1[2], PI / 2.0]
	var sa3_in := VhLayout.s3(193.0, F3, 966.6)
	var y3: float = VhLayout.FLW[&"f3"]
	bo.stage({"id": "holding", "name": "Holding", "spawn": {"x": land[0], "y": float(land[1]) + 0.1, "z": land[2], "yaw": land[3]}, "task": "Get to the warden's office.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			prison.mode = "field"
			_parked(o.get("retry", false))
			_kit_up()
			_bag_out(true)
			pipe.run(false)
			watchers.reset(false),
		"objectives": [
			{"id": "tier", "label": "3F", "text": "The 3F door.", "kind": "custom", "at": sa3_in, "radius": 1.2 * k1, "spawn": land.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_hold3(o.get("retry", false), land, "locked")
					if not o.get("retry", false):
						admin.unlock("saF3", true)
						audio.tone(110.0, 0.6, 0.16, &"sawtooth")
						audio.thud(0.4),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return _in3(Game.player),
				"on_done": func(_b: Variant) -> void: rush.start("tier")},
			{"id": "desk", "label": "The tier desk", "text": "X at the tier desk: override the lift.", "kind": "custom", "at": dk, "radius": 1.4, "spawn": desk.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_hold3(o.get("retry", false), desk, "locked")
					if o.get("retry", false):
						rush.start("tier"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return lift.state != "locked",
				"on_done": func(_b: Variant) -> void:
					rush.start("third")
					audio.say("r-lift", {"urgent": true})},
			{"id": "holdout", "label": "The lift", "text": "The lift is coming down. Hold the tier.", "kind": "custom", "at": [lift.door_at.x - 1.2, y3, lift.door_at.y], "radius": 1.2 * k1, "spawn": desk.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_hold3(o.get("retry", false), desk, "locked")
					if o.get("retry", false):
						lift.call_down()
						rush.start("third"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return lift.state == "open3" and rush.done("tier") and rush.done("third")},
			{"id": "ride", "label": "Up", "text": "Into the lift. X: ride up to 4F.", "kind": "custom", "at": [lift.door_at.x + 2.4, y3, lift.door_at.y], "radius": 1.6, "spawn": lobby.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void: _hold3(o.get("retry", false), lobby, "open3"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return lift.state == "top"},
		]})


# ---- section 5, stage 3: 4F, the warden's floor. The undertakers put their hands up; the warden sends his own out of the office and locks it behind them; the lockdown rack in 4F security behind Stair A's shutter (the jammer): wrecked, the Boss gets through; then Fenn's door
func _top4(retry: bool, s: Array, wrecked: bool = false) -> void:
	_lockdown(retry, s)
	if not retry:
		return
	admin.unlock("saF2", true)
	admin.unlock("saF3", true)
	lift.reset("top")
	people.surrender(true, true)
	if wrecked:
		jammer.wreck(true)
		audio.jam(false)
	else:
		jammer.reset()
	finale.reset()


func _stage_warden() -> void:
	var k1 := VhLayout.ADK
	var y4: float = VhLayout.FLW[&"f4"]
	var lf: Array = [lift.door_at.x + 2.6, y4, lift.door_at.y, -PI / 2.0]
	var ja: Array = jammer.at
	var rack: Array = [float(ja[0]) + 2.2, y4, ja[2], -PI / 2.0]
	w4_door = _a3(204.6, F4, 958.6)
	var door := w4_door
	bo.stage({"id": "warden", "name": "The Warden's Floor", "spawn": {"x": lf[0], "y": float(lf[1]) + 0.1, "z": lf[2], "yaw": lf[3]}, "task": "Get to the warden's office.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			prison.mode = "field"
			_parked(o.get("retry", false))
			_kit_up()
			_bag_out(true)
			pipe.run(false)
			watchers.reset(false),
		"objectives": [
			{"id": "guard", "label": "The warden's men", "text": "The warden's men.", "kind": "custom", "at": door, "radius": 1.2 * k1, "spawn": lf.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_top4(o.get("retry", false), lf)
					bo.flag("outT", 0.0)
					if not o.get("retry", false):
						people.surrender()
						audio.say("u-pickup"),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return rush.done("warden")},
			{"id": "jammer", "label": "The lockdown rack", "text": "Wreck the jammer in 4F security.", "kind": "hold", "hold": 1.8, "prompt": "WRECK THE JAMMER", "at": ja, "radius": 1.8, "spawn": rack.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void: _top4(o.get("retry", false), rack),
				"on_done": func(_b: Variant) -> void:
					jammer.wreck()
					audio._after(1.8, func() -> void:
						audio.jam(false)
						audio.say(["b-back", "p-here"], {"on_done": func() -> void: bo.flag("backSaid", true)}))},
			{"id": "fenn", "label": "Fenn", "text": "The warden's office.", "kind": "custom", "at": door, "radius": 1.2 * k1, "spawn": rack.slice(0, 3),
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_top4(o.get("retry", false), rack, true)
					if o.get("retry", false):
						bo.flag("backSaid", true),
				"done": func(_b: Variant, P: Player, _C: Variant) -> bool: return bo.flag("backSaid") == true and P != null and U.hyp(P.x - float(door[0]), P.z - float(door[2])) < 1.4 * k1 and absf(P.y - y4) < 1.2},
		]})


# ---- section 6: Fenn. The finale cutscene. LEVEL COMPLETE after it
func _stage_finale() -> void:
	var door := w4_door
	bo.stage({"id": "finale", "name": "Fenn", "spawn": {"x": door[0], "y": float(door[1]) + 0.1, "z": door[2], "yaw": PI / 2.0}, "task": "Fenn.",
		"on_enter": func(_a: Variant, o: Dictionary) -> void:
			prison.mode = "field"
			_parked(o.get("retry", false))
			_kit_up()
			_bag_out(true)
			pipe.run(false)
			watchers.reset(false),
		"objectives": [
			{"id": "shot", "label": "Fenn", "text": "Fenn.", "kind": "custom", "guide": false, "at": door, "spawn": door,
				"on_start": func(_b: Variant, o: Dictionary) -> void:
					_top4(o.get("retry", false), [door[0], door[1], door[2], PI / 2.0], true)
					finale.start(),
				"done": func(_b: Variant, _P: Variant, _C: Variant) -> bool: return finale.done},
		]})


func _near(P: Player, x: float, z: float, r: float, y: float) -> bool:
	return U.hyp(P.x - x, P.z - z) < r and absf(P.y - y) < 1.2


func _actions() -> void:
	var th: Array = scen.thermos
	var deck := VhLayout.deck
	var spots: Dictionary = fur.spots
	var d3: Array = spots.desk3
	var c4: Array = spots.console
	var b4: Array = spots.board
	var y3: float = VhLayout.FLW[&"f3"]
	var cb_dead := func() -> bool: return inside.dale == null or inside.dale.dead
	acts = {
		"zip": {"x": zip.action.x, "z": zip.action.z, "label": zip.action.label,
			"active": func(P: Player) -> bool: return _obj_id() == "zip" and zip.action.active.call(P),
			"run": func() -> void: zip.action.run.call()},
		"take": {"x": 1e9, "z": 1e9, "label": "TAKEDOWN",
			"active": func(P: Player) -> bool: return _stage_id() == "getin" and watchers.takedown_active(P),
			"run": func() -> void:
				watchers.takedown_run()
				if not bo.flag("sorry"):
					bo.flag("sorry", true)
					audio.say("p-sorry")},
		"take4": {"x": 1e9, "z": 1e9, "label": "TAKEDOWN",
			"active": func(P: Player) -> bool:
				if _stage_id() != "inside" or inside.cine.on:
					return false
				tgt4 = inside.st.takedown_target(P)
				return tgt4 != null,
			"run": func() -> void:
				inside.st.takedown(tgt4, Game.player)
				audio.thud(0.35)
				if not bo.flag("sorry"):
					bo.flag("sorry", true)
					audio.say("p-sorry")},
		"ride": {"x": 0.0, "z": 0.0, "label": "RIDE UP TO 4F",
			"active": func(P: Player) -> bool: return _stage_id() == "holding" and lift.state == "open3" and lift.in_car(P),
			"run": func() -> void: lift.ride()},
	}
	actions.assign([
		{"x": th[0], "z": th[1], "label": "DRINK THE THERMOS",
			"active": func(P: Player) -> bool: return _obj_id() == "thermos" and not bo.flag("drank") and P.y > deck - 1.0,
			"run": func() -> void:
				bo.flag("drank", true)
				audio.gulp()
				audio.say("p-drink", {"urgent": true, "on_done": func() -> void: bo.flag("drained", true)})},
		{"x": bag_at.x, "z": bag_at.y, "label": "OPEN THE KIT BAG",
			"active": func(P: Player) -> bool: return _obj_id() == "suit" and not bo.flag("suited") and P.y > deck - 1.0 and U.hyp(P.x - bag_at.x, P.z - bag_at.y) < 1.5,
			"run": func() -> void:
				_kit_up(true)
				_bag_out(true)
				Game.sfx.menu_sound("pauseConfirm")
				bo.flag("suited", true)},
		acts.zip, acts.take, acts.take4,
		{"x": c4[0], "z": c4[2], "label": "WATCH THE CAMERAS",
			"active": func(P: Player) -> bool: return _stage_id() == "inside" and not inside.cine.on and cb_dead.call() and _near(P, c4[0], c4[2], 1.6, F1),
			"run": func() -> void: inside.open_cctv()},
		{"x": b4[0], "z": b4[2], "label": "RELEASE STAIR B",
			"active": func(P: Player) -> bool: return _stage_id() == "inside" and not inside.released and not inside.cine.on and cb_dead.call() and _near(P, b4[0], b4[2], 1.5, F1),
			"run": func() -> void: inside.release()},
		{"x": d3[0], "z": d3[2], "label": "OVERRIDE THE LIFT",
			"active": func(P: Player) -> bool: return _stage_id() == "holding" and lift.state == "locked" and _near(P, d3[0], d3[2], 1.6, y3),
			"run": func() -> void: lift.call_down()},
		acts.ride,
	])


# indoors the outdoors is not drawn: the marsh's reeds, the far dressing and the approach props (over a million triangles) and the pipe from anywhere in the block, and below ground (the pipe, the pump room, B1: no windows) the drive's scenery and the prison too
func _outdoor(inn: bool, under: bool) -> void:
	var st := "under" if under else ("in" if inn else "out")
	if st == out_state:
		return
	out_state = st
	var hide_: Array = OUT_UNDER if under else (OUT_IN if inn else [])
	for pt: String in ALL_PARTS:
		var off: bool = pt in hide_
		for n: Node3D in part_nodes[pt]:
			n.visible = not off


func _tick_vh(dt: float, P: Player, api: Blockout) -> void:
	clock += dt
	var t := clock
	var V: Vehicles = Game.vehicles
	var id := _obj_id()
	var stage := _stage_id()
	var driving: bool = car != null and V.driver_v == car
	var cp: Vector3 = Game.camera.global_position if Game.camera != null else Vector3.ZERO
	# the actions that follow someone
	if watchers.tgt != null:
		acts.take.x = watchers.tgt.r.x
		acts.take.z = watchers.tgt.r.z
	if tgt4 != null:
		acts.take4.x = tgt4.r.x
		acts.take4.z = tgt4.r.z
	if P != null:
		acts.ride.x = P.x
		acts.ride.z = P.z
	# headlights: R (pad X) in the car
	if car != null and driving and (Inp.btn(&"reload").pressed or Inp.btn(&"attack").pressed):
		Inp.btn(&"reload").pressed = false
		Inp.btn(&"attack").pressed = false
		car.model.set_lights.call(not car.model.lights)
		Game.sfx.menu_sound("pauseConfirm")
	# the script along the road
	if car != null and id == "road":
		var s := VhLayout.nearest(VhLayout.road, car.x, car.z).s
		# (each beat waits for the one before it to finish: a fast driver hears it a little further on rather than piled up behind the exposition)
		if s > float(VhLayout.cue.reveal) and not api.flag("reveal") and not audio.busy:
			api.flag("reveal", true)
			vh_storm.reveal(float(VhLayout.PRISON.x) - 70.0, float(VhLayout.PRISON.z) + 30.0)
			audio.say(["b-reveal", "p-cheery"])
		if s > float(VhLayout.cue.track) and api.flag("reveal") and not api.flag("track") and not audio.busy:
			api.flag("track", true)
			audio.say("b-track")
	if id == "dark" or id == "climb":
		nag_t -= dt
		if car != null and car.model.lights and nag_t <= 0.0 and not audio.busy:
			nag_t = 9.0
			var k := int(api.flag("nagged") if api.flag("nagged") else 0) + 1
			api.flag("nagged", k)
			audio.say("b-nag1" if k == 1 else ("b-nag3" if k == 3 else "b-nag2"))
		if car != null and not car.model.lights and not lights_said:
			lights_said = true
			audio.say("p-lights")
	# tower four: headlights anywhere it can see (the track, the hilltop, the road past the turn-off) and it swings onto you; held there a moment and you're made
	var exposed := false
	if car != null and car.model.lights and caught_t < 0.0 and stage == "drive":
		var on_track := VhLayout.nearest(VhLayout.track, car.x, car.z)
		var on_road := VhLayout.nearest(VhLayout.road, car.x, car.z)
		exposed = (on_track.d < 5.0 and on_track.s > 20.0) or U.hyp(car.x - float(VhLayout.PLAT.x), car.z - float(VhLayout.PLAT.z)) < float(VhLayout.PLAT.r) + 2.0 or (on_road.d < 6.0 and on_road.s > VhLayout.turn_s + 22.0)
	catch_t = catch_t + dt if exposed else maxf(0.0, catch_t - dt * 0.7)
	var locked := catch_t > 0.5 and car != null
	if catch_t > 2.6 and caught_t < 0.0:
		caught_t = 0.0
		audio.say("b-seen", {"urgent": true})
		audio.siren()      # (JS ctx.alarm)
	if caught_t >= 0.0:
		caught_t += dt
		if caught_t > 3.2:
			caught_t = -1.0
			catch_t = 0.0
			bo.load_cp("drive.dark")
			return
	# ---- section 2: the goggles on the sniper scope, the office window, the zipline
	var in_block_c := admin.in_block(cp)
	spotter.update(dt, stage == "vantage" and id in SEARCH and P != null, vh_storm.flash * (0.3 if in_block_c else 1.0))
	zip.update(dt, P)
	_board_fade(dt, P)
	if stage == "vantage":
		if spotter.on:
			_first_look()
		if id == "wayin":
			api.flag("wayinT", float(api.flag("wayinT") if api.flag("wayinT") else 0.0) + dt)
			if float(api.flag("wayinT")) > 25.0 and not audio.busy and spotter.found.is_empty():
				_drain_hint()
		if api.flag("wantBlind") and prison.office.state == "closed" and not api.flag("blind"):
			api.flag("blind", true)
			audio.say("p-blind", {"on_done": func() -> void: bo.flag("blindSaid", true)})
	# ---- section 3: who is watching, the guards, the pipe
	var live := stage == "getin" and P != null
	watchers.update(dt, P, live and caught_t < 0.0)
	if live:
		var k := watchers.expose
		var downs := int(api.flag("downs") if api.flag("downs") else 0)
		if k > 0.3 and not api.flag("downSaid") and downs < 2:
			api.flag("downSaid", true)
			api.flag("downs", downs + 1)
			audio.say("b-down", {"urgent": true})
		if k < 0.05:
			api.flag("downSaid", false)
		if id == "canal" and not api.flag("guardSaid") and P.z > 930.0:
			api.flag("guardSaid", true)
			audio.say("b-guard")
		if watchers.caught_t > 3.2:
			bo.load_cp("getin.%s" % id)
			return
		pipe.update(dt, P if id == "pipe" or id == "door" else null, t)
	else:
		pipe.update(dt, null, t)
	var lock_t: Variant = null
	if stage == "getin":
		if watchers.caught_t >= 0.0 and P != null:
			lock_t = Vector3(P.x, P.y, P.z)
		elif watchers.lock != null:
			lock_t = watchers.lock.at
	elif (caught_t >= 0.0 or locked) and car != null:
		lock_t = Vector3(car.x, car.y, car.z)
	prison.update(dt, t, lock_t, watchers.lock_beam() if stage == "getin" else null, not in_block_c)
	admin.update(dt, cp, vh_storm.flash)
	people.update(dt, (admin.floors[&"f4"] as Node3D).visible or inside.feeds_live, (admin.floors[&"f1"] as Node3D).visible)
	# ---- section 4: the night shift, the cameras, the console; at Stair A the radio check nobody can answer
	inside.update(dt, P, t, (stage == "inside" or stage == "rush") and P != null)
	if stage == "inside" and id == "stairA" and P != null and not api.flag("radio") and U.hyp(P.x - float(sa[0]), P.z - float(sa[2])) < 1.8 * VhLayout.ADK and absf(P.y - F2) < 1.0:
		api.flag("radio", true)
		var end := func() -> void: bo.flag("endAt", clock + 3.5)
		if inside.loud:
			end.call()
		else:
			audio.hush()
			audio.say(["r-check1", "r-check2", "p-dale", "r-who", "r-lock"], {"on_done": func() -> void:
				end.call()
				inside.go_loud("radio")})
	if stage == "inside" and id == "stairA" and api.flag("radio") and inside.loud and not api.flag("endAt"):      # (seen mid-check: the alarm hushed the radio before it finished)
		api.flag("endAt", t + 3.5)
	if api.flag("endAt") and t > float(api.flag("endAt")) and not api.flag("lockedDown"):      # (the klaxons a few seconds, then section 5)
		api.flag("lockedDown", true)
	# ---- section 5: the squads; in Stair A the second team comes to box you in (Tower Four calls it on the guards' radios)
	rush.update(dt, P)
	lift.update(dt)
	inmates.update(dt, t, P)
	jammer.update(dt)
	finale.update(dt)
	# 4F: the warden's men come out of his office once you are out of the lift (or after a few seconds of you standing in it)
	if stage == "warden" and id == "guard" and P != null and not rush.started("warden"):
		api.flag("outT", float(api.flag("outT") if api.flag("outT") else 0.0) + dt)
		if not lift.in_car(P) or float(api.flag("outT")) > 6.0:
			rush.start("warden")
	# 3F: the first look down the run, the inmates at their bars; in the car, the box
	if stage == "holding" and P != null and not api.flag("heckled") and absf(P.y - float(VhLayout.FLW[&"f3"])) < 1.2 and P.x > VhLayout.ad_x(196.8) and P.z < VhLayout.ad_z(965.0):
		api.flag("heckled", true)
		audio.say(["i-fointer", "p-no"])
	if stage == "holding" and not api.flag("boxSaid") and lift.in_car(P) and lift.state == "open3":
		api.flag("boxSaid", true)
		audio.say("p-optimistic")
	if stage == "rush" and id == "well" and P != null and not rush.started("well") and admin.in_stair_a(Vector3(P.x, P.y, P.z)) and P.y > float(VhLayout.FLW[&"f2"]) - 0.5:
		rush.start("well")
		audio.say("r-team2", {"urgent": true})
	var warm := pow(clampf((cp.z - 120.0) / 560.0, 0.0, 1.0), 1.5) * 0.85      # cold behind you (FOINT CITY), sodium ahead (the prison)
	var indoors := cp.y < VhLayout.PAD - 0.1 and cp.x > float(VhLayout.PIPE.x0) - 0.4 and cp.x < float(VhLayout.PUMP.x1) + 0.5 and cp.z > float(VhLayout.PUMP.z0) - 0.5 and cp.z < float(VhLayout.PUMP.z1) + 0.5      # in the pipe or the pump room
	# from the vantage on the night is darker than the drive's (the storm closes in; no headlights now): only lamps, searchlights and the goggles show much
	night_k += ((1.0 if stage == "vantage" or stage == "getin" else 0.0) - night_k) * minf(1.0, dt * 0.5)
	var below := in_block_c and cp.y < VhLayout.PAD
	var in_pipe := indoors and cp.x < float(VhLayout.PUMP.x0)
	var amb := 0.03 if in_pipe else ((0.6 if below else 0.8) if in_block_c else 1.0 - night_k * 0.6)      # (the pipe is pitch black: goggles)
	_outdoor(in_block_c or indoors, indoors or below)      # in the admin block: the sky only through windows (none below ground)
	vh_storm.update(dt, t, {"headlights": car != null and car.model.lights, "glow_at": Vector2(VhLayout.PRISON.x, VhLayout.PRISON.z), "city_at": CITY, "warm": warm, "night": 0.0 if in_block_c else night_k, "indoors": indoors or in_block_c, "amb": amb, "flash_in": 0.0 if in_pipe else ((0.0 if below else 0.3) if in_block_c else 1.0)})
	var sun_i := 0.5 * amb
	if absf(sun_i - sun_last) > 0.003:
		sun_last = sun_i
		Game.view.set_sun(MsKit.srgb(0x9ab8ff), sun_i)
	prison.flash = vh_storm.flash
	if absf(vh_storm.flash - water_last) > 0.002:
		water_last = vh_storm.flash
		for k: String in ["shader_dbb0da#0", "shader_dbb0da#1"]:
			var wm: ShaderMaterial = shader_ports.mats.get(k)
			if wm != null:
				wm.set_shader_parameter(&"uFlash", vh_storm.flash)
		if face_m != null:
			face_m.emission_energy_multiplier = vh_storm.flash * 0.25
	dress.update(dt, t, vh_storm.flash, vh_storm.color_now, cp, car != null and car.model.lights, car.x if car != null else 0.0, car.z if car != null else 0.0, car.yaw if car != null else 0.0)
	audio.update_audio(dt, 1.0 if driving else 0.0, 1.0 if indoors or in_block_c else 0.0)
	# the block's see-through cutaway: furniture between the lens and Prog dissolves
	cut_on += ((1.0 if in_block_c and P != null and not P.dead and admin.in_block(Vector3(P.x, P.y, P.z)) else 0.0) - cut_on) * minf(1.0, dt * 8.0)
	RenderingServer.global_shader_parameter_set(&"vh_cut_on", cut_on)
	if P != null:
		RenderingServer.global_shader_parameter_set(&"vh_cut_c", cp)
		RenderingServer.global_shader_parameter_set(&"vh_cut_p", Vector3(P.x, P.y + 1.0, P.z))


# ---- the tunnel camera: the outfall pipe is 1.3 m high, too low for the follow camera. In the pipe the view rides the centreline behind Prog looking down the pipe the way he faces (rig.yaw eases onto the pipe's axis; a deliberate turn past ~100 degrees flips it). It blends in and out over half a second; while blending, the camera is held inside the pipe's bore (a straight blend from the follow view passed through the wall) and the look point swings round on a spring, so the view never whips
func camera_override(rig: Variant, P: Variant, dt: float) -> View.Shot:
	var PZ: float = VhLayout.PIPE.z
	var x0: float = VhLayout.PIPE.x0
	var x1: float = VhLayout.PIPE.x1
	var in_tube: bool = P != null and not P.dead and not Game.vehicles.driving and P.y < 1.5 and P.x > x0 - 1.8 and P.x < x1 + 0.4 and absf(P.z - PZ) < 1.0      # (a little past both ends of the crawl: its snap of the rig to Prog's head happens under the smoothing)
	if not in_tube:
		tun.on = false
		tun.k = maxf(0.0, float(tun.k) - dt / 0.5)
		if float(tun.k) <= 0.0:
			tun.started = false
			return null
	else:
		tun.k = minf(1.0, float(tun.k) + dt / 0.5)
		rig.too_close = false
		if Game.animator != null:
			Game.animator.actor.visible = true      # (the crawl kit's camera hides the body: this one sits behind it)
		rig.view_off = 0.0      # (the indoor follow's own turns would twist the controls off the pipe's axis)
		rig.vo_t = 0.0
		rig.vo_v = 0.0
		rig.trail.clear()
		var fx: float = sin(rig.yaw)
		if not tun.on:
			tun.f = 1.0 if fx >= 0.0 else -1.0
		elif fx * float(tun.f) < -0.3:
			tun.f = -float(tun.f)
		var f: float = tun.f
		rig.yaw += VhLayout.wrap_a(f * PI / 2.0 - rig.yaw) * minf(1.0, dt * 2.5)
		var room: float = P.x - (x0 - 3.0) if f > 0.0 else x1 - 0.35 - P.x
		var bk := clampf(room, 0.6, 2.1)
		var px: float = P.x - f * bk
		var lx: float = P.x + f * 3.0
		if not tun.on:
			tun.tp = Vector3(px, 0.92, PZ)
			tun.tl = Vector3(lx, 0.62, PZ)
		var e := 1.0 - exp(-dt * 12.0)
		var tp: Vector3 = tun.tp
		var tl: Vector3 = tun.tl
		tun.tp = Vector3(tp.x + (px - tp.x) * e, 0.92, PZ)
		tun.tl = Vector3(tl.x + (lx - tl.x) * e, 0.62, PZ)
		tun.on = true
	var kk: float = tun.k
	var k := kk * kk * (3.0 - 2.0 * kk)
	var wp: Vector3 = rig.pos.lerp(tun.tp, k)
	var wl: Vector3 = rig.look.lerp(tun.tl, k)
	if wp.x > x0 - 0.2 and wp.x < x1:      # (inside the bore)
		wp.y = clampf(wp.y, 0.45, 1.35)
		wp.z = PZ + clampf(wp.z - PZ, -0.45, 0.45)
	if not tun.started:
		tun_shot.pos = wp
		tun_shot.look = wl
		tun.started = true
	else:
		var e := 1.0 - exp(-dt * 10.0)
		var d0 := (tun_shot.look - tun_shot.pos).normalized()
		var d1 := (wl - wp).normalized()
		tun_shot.pos = tun_shot.pos.lerp(wp, e)
		var ang := acos(clampf(d0.dot(d1), -1.0, 1.0))
		var st := minf(ang, dt * 2.2)      # (the view turns at most 2.2 rad/s)
		var dir := d0.lerp(d1, st / ang).normalized() if ang > 1e-4 else d1
		tun_shot.look = tun_shot.pos + dir * wl.distance_to(wp)
	return tun_shot


func on_exit() -> void:
	audio.hush()
	Game.vehicles.clear(OWNER)
	pipe.dispose()
	watchers.dispose()
	inside.dispose()
	rush.dispose()
	people.dispose()
	super.on_exit()
