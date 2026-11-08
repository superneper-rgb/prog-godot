class_name MothershipLevel
extends KitLevel
## THE MOTHERSHIP (JS levels/mothership/level.js): the assault on the grays' base, a mob family's villa built on top of a flying saucer. Act one is this file; act two (the casino to the Godmother and home) is ms_act2.gd.
##   01 ARRIVAL        the greens drop you on the valet deck at dusk, in a terrible rubber gray mask. No gun: you are a wedding guest.
##   02 RECEIVING LINE the family gives you the once-over (translated remarks); sign the guestbook, take a canape from the probe butler.
##   03 RECEPTION      the wedding: 100+ guests, the band (0002pxr and his little copies), the cake in the Spine Beam. The MC calls you up for a toast (X).
##   04 THE BRAWL      the mask comes off, the record scratches, everyone dives. Your gear is in the cake. Two waves; the tommy-gun gray you watched practising on your cut-out comes down off the gallery's rail. Then the service door opens.
##   05 SERVICE        the Muscle bursts out of the pantry.
##   06 LAUNDRY        LIFT BEAMS: show (a towel basket rides one) -> try -> test (over the steam vents) -> twist (a timed beam).
##   07 KITCHEN        RAIL BEAMS: show (a cake slice rides one) -> try -> test (over the hot sauce vats with the cooks shooting up at you).

const FLOOR := 2.0
const LOADOUT_ := ["deagle", "shotgun", "smg", "bellows"]
const EQUIP_ := "smg"
const DISGUISED := ["arrival", "line", "reception"]
const STAGES := ["arrival", "line", "reception", "brawl", "corridor", "laundry", "kitchen", "casino", "conservatory", "gallery", "chapel", "climb", "godmother", "home"]
const BAND := {"drums": [-25.0, 3.0, -3.3], "singer": [-22.6, 3.0, 0.0], "keys": [-24.4, 3.0, 3.3]}
const CAKE_TOP := [0.0, 8.8, 0.0]
const VENTS := [[59.0, -12.2], [62.5, -9.0], [61.0, -4.5], [64.2, -6.5]]
const VENT_Y := -4.0
const VATS := [[40.5, 30.6, 1.9], [47.5, 30.4, 1.9], [54.0, 25.0, 1.6]]
const VAT_TOP := 14.5
const FOLD := [2, 7, 9]
const TABLES := MsGuests.TABLES
# colour-keyed zones: the sky light, sun and fog blend to each part of the house as you walk through it
const LOOKS := {
	"out": {"sky": 0xb79ad0, "ground": 0x3a2420, "hemi": 1.05, "sun": 0xffb98a, "sun_i": 0.9, "fog": 0x3a2048, "dens": 0.0032},      # dusk over the bay: lilac and peach
	"grand": {"sky": 0xffd4a0, "ground": 0x4a2414, "hemi": 0.72, "sun": 0xffc080, "sun_i": 0.25, "fog": 0x2a140c, "dens": 0.0055},      # the wedding: candle gold and wine red
	"service": {"sky": 0xd6f0dc, "ground": 0x2c3830, "hemi": 0.78, "sun": 0xe8fff0, "sun_i": 0.15, "fog": 0x18221c, "dens": 0.009},      # staff corridor: sickly green tile light
	"laundry": {"sky": 0xc8e6ff, "ground": 0x1e2c38, "hemi": 0.95, "sun": 0xd8f0ff, "sun_i": 0.2, "fog": 0x1c2a36, "dens": 0.0065},      # the drying hall: cold blue steam
	"kitchen": {"sky": 0xffdcb0, "ground": 0x40200e, "hemi": 0.85, "sun": 0xffd0a0, "sun_i": 0.2, "fog": 0x2c1a10, "dens": 0.0065},      # the kitchen: hot copper and sauce
	"casino": {"sky": 0xd6a0ff, "ground": 0x2a0f3a, "hemi": 0.8, "sun": 0xff90d0, "sun_i": 0.15, "fog": 0x1c0a26, "dens": 0.0055},      # La Luna: plum, neon pink and green
	"conserv": {"sky": 0x9adcc0, "ground": 0x10241a, "hemi": 0.7, "sun": 0xc8ffe0, "sun_i": 0.12, "fog": 0x0c1c18, "dens": 0.008},      # the grow-house: fake moonlight, glowing crops
	"gallery": {"sky": 0xb8c8e8, "ground": 0x2a2030, "hemi": 0.72, "sun": 0xd8e4ff, "sun_i": 0.15, "fog": 0x141824, "dens": 0.0065},      # the portraits: cold blue, gold frames
	"chapel": {"sky": 0xffb8c8, "ground": 0x2a1030, "hemi": 0.7, "sun": 0xffa0b0, "sun_i": 0.12, "fog": 0x1e0c18, "dens": 0.0065},      # stained glass: rose and cobalt
	"cellar": {"sky": 0xc8f0ff, "ground": 0x1a2a38, "hemi": 0.8, "sun": 0xe0f8ff, "sun_i": 0.1, "fog": 0x14222c, "dens": 0.009},      # the freezer: ice blue
	"counting": {"sky": 0xb0f0b0, "ground": 0x182a18, "hemi": 0.75, "sun": 0xd0ffd0, "sun_i": 0.1, "fog": 0x0e1a10, "dens": 0.009},      # bankers' lamps: money green
	"pent": {"sky": 0xffb8d8, "ground": 0x3a1a2a, "hemi": 0.85, "sun": 0xffc8e0, "sun_i": 0.25, "fog": 0x2a1222, "dens": 0.004},      # her boudoir: blush pink and gold
}


class FoldTable:
	var x := 0.0
	var z := 0.0
	var s: World.Solid
	var g: Node3D
	var fold := false
	var stand_t := 0.0
	var down := 0.0


class Vent:
	var x := 0.0
	var z := 0.0
	var s: MeshInstance3D
	var off := 0.0


class PantryDoor:
	var g: Node3D
	var sx := 1.0
	var flying := false
	var vx := 0.0
	var vy := 0.0
	var vz := 0.0
	var spin := 0.0


var loadout: Array = []      # (no gun: you are a wedding guest; the gear comes out of the cake)
var act2: MsAct2
var beams: MsBeams
var ent: MsEntrances
var guests: MsGuests
var audio: MsAudio
var band: MsBand
var hall_lights: MsHallLights
var disguise := MsDisguise.new()
var cine: MsTruce = null
var fx_root: Node3D
var zones: Dictionary = {}
var dome_cap: World.Solid
var service_door: World.Solid
var pantry_door: World.Solid
var service_leaves: Array[Node3D] = []
var pantry_doors: Array[PantryDoor] = []
var front_leaves: Array[Node3D] = []
var front_open := 0.0
var tables: Array[FoldTable] = []
var exterior: Array = []
var drums: Array = []
var lines_: Array = []
var paddles: Array = []
var vents: Array[Vent] = []
var basket: Node3D
var tray: Node3D
var bride: Node3D
var gun_prop: Node3D
var gun_flash: MeshInstance3D
var laser: MeshInstance3D
var topper: Node3D
var topper_home_ := Vector3.ZERO
var cutout: Node3D
var cutout_card: Node3D
var cutout_holes: Array = []
var cutout_shake := 0.0
var green_ride: Node3D
var pilot_arm: Node3D
var lowrider: Node3D
var lowrider_dome: Node3D
var rigs: Dictionary = {}
var rig_actors: Array = []      # [actor, zone]
var head_table: Array = []
var clock := 0.0
var stage_id := ""
var cur_obj := ""
var look_cur: Dictionary = {}
var saucer_t := 0.0
var unmask: Variant = null      # {t, gave}
var cake_burst: Variant = null      # {t, vy, vx}
var gun_t := 0.0
var gun_holes := 0
var gun_flash_o := 0.0
var vent_cd := 0.0
var vat_cd := 0.0
var cooks: Array = []
var cook_hats: Array = []
var decor_butlers: Array = []
var _dummy: Node3D = null
var _solids_by_id: Dictionary = {}
var _beam_pts := PackedVector2Array()


func kit_options() -> Dictionary:
	return {"id": "mothership", "name": "THE MOTHERSHIP", "spawn": {"x": 0.0, "y": 0.0, "z": -95.0, "yaw": 0.0}, "fall_reset_y": -60.0,
		"complete_text": "A TRUCE. FOR NOW. -- THE GREENS ARE TAKING YOU HOME",
		"on_enter_stage": func(b: Blockout, o: Dictionary) -> void:
			_apply_state(b, o.stage, o.get("retry", false) or o.get("restoring", false))
			act2.state(b, o.stage, o),
		"on_update": func(dt: float, P: Player, C: Combat, b: Blockout) -> void: _tick_ms(dt, P, C, b),
		"on_complete": func(_b: Blockout) -> void: act2.on_complete(),
		# every gray the kit sends comes in through somewhere real (a door, the cellar stairs, a ceiling hatch): the spec's `from` / `hatch`
		"on_spawn": func(r: Robot, o: Dictionary, _b: Blockout) -> void:
			if o.has("from") or o.has("hatch"):
				var path: Array = (o.get("from", []) as Array).duplicate()
				path.append([r.x, r.y, r.z])
				ent.enter(r, path, o),
	}


# ---- small tools
func one(nm: String) -> Node3D:
	for n: Node3D in node_named(nm):
		return n
	push_warning("MOTHERSHIP: nothing exported as " + nm)
	if _dummy == null:
		_dummy = Node3D.new()
		add_child(_dummy)
	return _dummy


func solid_id(sid: String) -> World.Solid:
	if _solids_by_id.is_empty():
		for s: World.Solid in world.solids:
			var ex: Variant = s.data.get("extra")
			if ex is Dictionary and (ex as Dictionary).has("id"):
				_solids_by_id[(ex as Dictionary)["id"]] = s
	var f: World.Solid = _solids_by_id.get(sid)
	if f == null:
		push_warning("MOTHERSHIP: no solid " + sid)
		return world.add({"kind": "box", "cx": 0.0, "cz": -500.0, "hx": 0.1, "hz": 0.1, "top": -500.0, "bottom": -501.0, "tag": "wall"})
	return f


func own_mats(root: Node3D) -> Array:
	var out: Array = []
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s) as StandardMaterial3D
				if m != null:
					var d := m.duplicate() as StandardMaterial3D
					mi.set_surface_override_material(s, d)
					out.append(d)
	return out


func set_alpha(list: Array, a: float) -> void:
	for m: StandardMaterial3D in list:
		m.albedo_color.a = a


func to_zone(n: Node3D, z: String) -> void:
	var zn: Node3D = zones.get(z)
	if zn != null and n.get_parent() != zn:
		n.reparent(zn)


func toast(m: String) -> void:
	Game.hud.toast(m)


func sparks(p: Vector3, n: int, sp: float, nrm: Variant, col: int) -> void:
	if Game.fx != null:
		Game.fx.sparks(p, n, sp, nrm, col)


func char_id() -> String:
	if Game.animator != null and Game.animator.B != null:
		return Game.animator.B.id
	return "prog"


func radio(text: String) -> void:
	Game.hud.subtitle({"id": 0, "num": 0, "text": text, "dur": minf(4.0, 0.8 + text.length() * 0.05), "name": ("PROG" if char_id() == "tommy" else "TOMMY") + " (RADIO)", "speech": false})
	MsSound.play([["tone", 0.0, {"type": &"square", "f0": 1800.0, "f1": 1800.0, "gain": 0.05, "dur": 0.05}], ["noise", 0.0, {"type": &"bandpass", "f0": 2000.0, "q": 1.0, "gain": 0.08, "dur": 0.12}]], 0.0)


## the greens' saucer: its rim bulbs chase (JS setLights)
func set_saucer_lights(root: Node3D, t: float) -> void:
	var bulbs: Array = root.get_meta("bulbs", [])
	var i := 0
	for b: Array in bulbs:
		var hue := 0.42 if posmod(i + floori(t * 10.0), 4) < 2 else 0.12
		for m: StandardMaterial3D in b:
			m.albedo_color = Color.from_hsv(hue, 0.9, 1.0)
		i += 1


func saucer_prep(root: Node3D) -> void:
	var bulbs: Array = []
	for n: Node in root.get_children():
		if n is Node3D and _has_js_name(n, "ms_bulb"):
			bulbs.append(own_mats(n as Node3D))
	root.set_meta("bulbs", bulbs)


func _has_js_name(n: Node, nm: String) -> bool:
	var x: Dictionary = n.get_meta("extras", {})
	return x.get("js_name", "") == nm


# ================================================================== build
## (KitLevel.build calls setup() once the export is in: the pieces the stages talk to are made first)
func _prepare() -> void:
	# what is rebuilt here goes from the export (ms_x, the talkers' frozen bodies, the frozen Godmother)
	for nm: String in ["ms_x", "Gray alien (NPC)", "Green alien (NPC)", "THE GODMOTHER", "service hatch"]:
		for n: Variant in node_named(nm):
			if is_instance_valid(n):
				(n as Node).get_parent().remove_child(n)
				(n as Node).queue_free()
		by_name.erase(nm)
	fx_root = Node3D.new()
	fx_root.name = "MothershipFx"
	add_child(fx_root)
	for k: String in ["out", "vest", "hall", "service", "casino", "pent"]:
		zones[k] = one("zone " + k)
	dome_cap = solid_id("ms_dome_cap")
	service_door = solid_id("ms_service_door")
	pantry_door = solid_id("ms_pantry_door")
	for n: Node3D in node_named("ms_service_leaf"):
		service_leaves.append(n)
	service_leaves[0].set_meta("open", 1.45)      # (JS -sz * 1.45, in the order [-1, 1])
	service_leaves[1].set_meta("open", -1.45)
	var sx := -1.0
	for n: Node3D in node_named("ms_pantry_leaf"):
		var d := PantryDoor.new()
		d.g = n
		d.sx = sx
		sx = 1.0
		pantry_doors.append(d)
	for n: Node3D in node_named("ms_front_leaf"):
		front_leaves.append(n)
	front_leaves[0].set_meta("open", -1.5)      # swings inward (+z)
	front_leaves[1].set_meta("open", 1.5)
	for i in TABLES.size():
		var tb := FoldTable.new()
		tb.x = TABLES[i][0]
		tb.z = TABLES[i][1]
		tb.s = solid_id("ms_table_%d" % i)
		tb.g = one("ms_table_%d" % i)
		tb.fold = FOLD.has(i)
		tables.append(tb)
	exterior = node_named("ms_exterior")
	drums = node_named("ms_drum")
	lines_ = node_named("ms_line")
	paddles = node_named("ms_paddle")
	basket = one("ms_basket")
	tray = one("ms_tray")
	bride = one("ms_bride")
	gun_prop = one("ms_gun_prop")
	topper = one("ms_topper")
	topper_home_ = topper.position
	cutout = one("ms_cutout")
	cutout_card = one("ms_cutout_card")
	cutout_holes = node_named("ms_cutout_hole")
	green_ride = one("ms_ride_saucer")
	saucer_prep(green_ride)
	pilot_arm = one("ms_pilot_arm")
	lowrider = one("ms_lowrider")
	lowrider_dome = lowrider.find_child("*saucer_dome*", true, false) as Node3D
	# the beams: the laundry's and the kitchen's live in the service zone
	beams = MsBeams.new(zones["service"])
	ent = MsEntrances.new(world, fx_root)
	# laundry: A (try), B (test, over the vents), C (twist: a cycle: on 5.2 s, flickers its last second, off 1.6 s); a decor beam with a towel basket (show)
	beams.lift({"x": 50.6, "z": -12.1, "y0": VENT_Y, "y1": 4.6, "r": 1.3})
	beams.lift({"x": 64.3, "z": -12.1, "y0": VENT_Y, "y1": 8.6, "r": 1.3})
	var cyc := 7.0
	beams.lift({"x": 64.3, "z": -2.8, "y0": VENT_Y, "y1": 13.6, "r": 1.3,
		"on": func(t: float) -> float:
			var m := fmod(t, cyc)
			if m < 5.2:
				return 1.0
			if m < 5.45:
				return 1.0 - (m - 5.2) / 0.25
			if m < 6.75:
				return 0.0
			return (m - 6.75) / 0.25,
		"warn_at": func(t: float) -> float:
			var m := fmod(t, cyc)
			return 1.0 if m > 4.2 and m < 5.45 else 0.0})
	beams.lift({"x": 54.5, "z": 8.5, "y0": VENT_Y + 1.0, "y1": 14.0, "r": 0.9, "decor": true})
	# kitchen rails: R1 (show + try) carries a slice of wedding cake on a tray when you arrive; R2 (test) slower, over the vats
	var r1 := beams.rail({"a": [58.6, 17.4], "b": [58.6, 30.4], "y": 18.4, "ride": 14.05, "wait": 1.8, "travel": 2.4})
	beams.rail({"a": [57.4, 30.6], "b": [34.2, 30.6], "y": 18.4, "ride": 14.05, "wait": 1.6, "travel": 3.9, "phase": 2.0})
	r1.cargo = tray
	for i in VENTS.size():
		var v := Vent.new()
		v.x = VENTS[i][0]
		v.z = VENTS[i][1]
		v.off = i * 0.8
		v.s = MsKit.sprite(zones["service"], 0xe8f4ff, 0.0, 1.6)
		v.s.position = Vector3(v.x, VENT_Y + 1.2, v.z)
		vents.append(v)
	act2 = MsAct2.new(self, beams, fx_root)
	guests = MsGuests.new(self)
	# the band on the stage: 0002pxr sings, his little copies play keys and drums, all of it read off the song
	band = MsBand.new(self, BAND, zones["hall"])
	# the grays' light show
	var wash: OmniLight3D = _light_named("ms_wash")
	var stage_wash: OmniLight3D = _light_named("ms_stage_wash")
	hall_lights = MsHallLights.new(zones["hall"], wash, BAND, stage_wash)
	gun_flash = MsKit.sprite(gun_prop, 0xff7040, 0.0, 0.5)
	gun_flash.position = Vector3(-0.55, 0.0, 0.0)
	laser = MsKit.glow(fx_root, MsKit.cone_z(0.02, 0.02, 1.0, 5), 0, 0xff2a1a, 0.85)
	laser.visible = false
	audio = MsAudio.new()
	add_child(audio)
	_setup_people()
	cine = act2.truce


func _light_named(nm: String) -> OmniLight3D:
	for n: Variant in node_named(nm):
		if n is OmniLight3D:
			return n
	return null


func _rigs() -> void:
	var dir := DIR + "mothership/"
	var txt := FileAccess.get_file_as_string(dir + "rigs.json")
	if txt == "":
		push_warning("MOTHERSHIP: no rigs.json")
		return
	var J: Variant = JSON.parse_string(txt)
	if J is Dictionary:
		rigs = HubNpcs.build(self, J, FileAccess.get_file_as_bytes(dir + "rigs.bin"))


func _setup_people() -> void:
	_rigs()
	var D: Dialogue = Game.dialogue
	var me := "TOMMY" if char_id() == "tommy" else "PROG"
	# valet (forecourt)
	var valet: NpcRig = rigs.get("ms_valet")
	if valet != null:
		to_zone(valet, "out")
		rig_actors.append([valet, "out"])
	D.add_talker({"id": "ms_valet", "name": "VALET", "x": -5.5, "y": 0.0, "z": -88.0, "yaw": PI, "actor": valet, "voice_pitch": 0.62, "shot": {"spot_fwd": 2.0}, "active": func() -> bool: return DISGUISED.has(stage_id),
		"lines": ["Valet parking, sir? ...Where is your saucer?", {"who": me, "text": "...It's circling.", "voice": null}, "Circling. Sure. Enjoy the wedding, uh... sir."]})
	# coat check (vestibule)
	var coat: NpcRig = rigs.get("ms_coat")
	if coat != null:
		to_zone(coat, "vest")
		rig_actors.append([coat, "vest"])
	D.add_talker({"id": "ms_coat", "name": "COAT CHECK", "x": -6.5, "y": FLOOR, "z": -66.0, "yaw": PI / 2.0, "actor": coat, "voice_pitch": 0.7, "shot": {"spot_fwd": 2.1}, "active": func() -> bool: return DISGUISED.has(stage_id),
		"lines": ["Welcome to the Grayleone wedding. May I take your coat? ...Your mask?", {"who": me, "text": "It's my FACE.", "voice": null}, "Of course it is. My apologies. Enjoy the party... gorgeous."]})
	# the MC at the microphone (the toast): the one wedding guest you meet face to face, so a full model
	var mc: NpcRig = rigs.get("ms_toast")
	if mc != null:
		to_zone(mc, "hall")
		rig_actors.append([mc, "hall"])
		head_table.append(mc)
	var tom := char_id() == "tommy"
	var sal := "LITTLE VITO" if tom else "UNCLE SAL"
	D.add_talker({"id": "ms_toast", "name": "THE MC", "x": 0.0, "y": FLOOR + 1.2, "z": 18.2, "yaw": PI, "actor": mc, "voice_pitch": 0.6, "radius": 3.2, "active": func() -> bool: return stage_id == "reception" and cur_obj == "toast",
		"lines": [
			"Ladies and gentlegrays! Before the Godmother joins us upstairs... a toast to the happy couple!",
			"From the bride's little cousin Vito, who... got real short since the last reunion... LITTLE VITO!" if tom else "From the bride's dear cousin, all the way from Zeta Reticuli... UNCLE SAL!",
			{"who": sal, "text": "Yo. Hi. I am Vito. A gray. Very gray. Congratulations on the... wedding thing." if tom else "Ahem. Greetings, fellow grays. I, a normal gray, love... the mob. And crime. And... probing?", "voice": null},
			"Since when does Vito got a PROPELLER?" if tom else "...Sal? Since when do you got EARS?",
			{"who": sal, "text": "...It's for the breeze." if tom else "...Since the accident.", "voice": null},
			"Hey. HEY. That ain't family! That's the green-lover from the street!",
		],
		"on_end": func(_t: Dictionary) -> void: bo.flag("toasted", true)})
	act2.setup_people(rigs)


# ================================================================== stage state (anything the checkpoints must put back)
func _ensure_gear(C: Combat) -> void:
	if C == null:
		return
	for id_: String in LOADOUT_:
		var i := _wi(id_)
		if i >= 0:
			C.give(i)
	if C.cur < 0:
		C.equip(_wi(EQUIP_))


func _wi(id_: String) -> int:
	for i in Weapons.WEAPONS.size():
		if Weapons.WEAPONS[i].id == id_:
			return i
	return -1


# the kitchen's cooks: put out when the kitchen stage starts (before the balcony), chef-hatted grays that stand at their stoves, passive until one of them sees you (or is hurt)
func _live_foe(r: Variant) -> bool:
	return Game.combat != null and Game.combat.enemies.robots.has(r)


func _cooks_on(on: bool, fresh: bool) -> void:
	if on and not fresh and not cooks.is_empty():      # already at their stoves (spawned while you were in the laundry): no pop-in
		var all_ok := true
		for r: Variant in cooks:
			if not _live_foe(r) or r.dead:
				all_ok = false
		if all_ok:
			return
	for r: Variant in cooks:
		if _live_foe(r):
			Game.despawn_enemy(r)
	cooks = []
	for h: Node3D in cook_hats:
		h.queue_free()
	cook_hats = []
	if not on:
		return
	var hat_m := MsKit.cyl(0.16, 0.13, 0.28, 12)
	var hat_s := MsKit.std(0xffffff, 0.8)
	for p: Array in [[38.0, 23.5], [45.0, 25.5], [52.0, 28.0]]:
		var r: Robot = Game.spawn_enemy({"x": p[0], "y": 6.0, "z": p[1], "yaw": atan2(58.0 - float(p[0]), 16.0 - float(p[1]))}, {"kind": "alien", "no_respawn": true})
		if r == null:
			continue
		r.dev_passive = true
		cooks.append(r)
		cook_hats.append(MsKit.part(fx_root, hat_m, hat_s))


func _cooks_watch(dt: float, P: Player) -> void:
	# the chefs' hats ride their heads (the crowd of enemies draws in one batch: a hat is its own node)
	for i in mini(cooks.size(), cook_hats.size()):
		var r: Robot = cooks[i]
		var h: Node3D = cook_hats[i]
		h.visible = _live_foe(r) and not r.dead
		if h.visible and Game.fx != null:
			var bv: Variant = Game.fx.bot_by_id.get(r.id)
			if bv != null and bv.get(&"j_head") != null and bv.pose != null:
				h.global_transform = (bv.pose.world[bv.j_head] as Transform3D) * Transform3D(Basis(), Vector3(0.0, 0.48, 0.0))
	if cooks.is_empty() or P == null or P.dead or not cooks[0].dev_passive:
		return
	var woke := false
	for r: Robot in cooks:
		if r.hp < r.max or (U.hyp(P.x - r.x, P.z - r.z) < 26.0 and absf(P.y - r.y) < 9.0 and r._look(dt, P, false)):
			woke = true
	if not woke:
		return
	for r: Robot in cooks:
		r.dev_passive = false
		r._know(P.x, P.z)
		r.seen_t = 0.0
		r.set_(&"alert")


func _decor_butlers_on(on: bool, fresh: bool) -> void:
	if on and not fresh and not decor_butlers.is_empty():      # the same two butlers from the arrival on: they never pop in
		var all_ok := true
		for r: Variant in decor_butlers:
			if not _live_foe(r) or r.dead:
				all_ok = false
		if all_ok:
			return
	for r: Variant in decor_butlers:
		if _live_foe(r):
			Game.despawn_enemy(r)
	decor_butlers = []
	if not on:
		return
	for p: Array in [[-3.4, FLOOR, -36.0], [6.0, FLOOR, -7.0]]:
		var r: Robot = Game.spawn_enemy({"x": p[0], "y": p[1], "z": p[2], "yaw": 0.0}, {"kind": "butler", "no_respawn": true})
		if r != null:
			r.dev_passive = true
			decor_butlers.append(r)


static func _past(id_: String, ref: String) -> bool:
	return STAGES.find(id_) >= STAGES.find(ref)


func _apply_state(b: Blockout, id_: String, instant: bool) -> void:
	stage_id = id_
	ent.clear()
	_cooks_on(id_ == "laundry" or id_ == "kitchen", instant)
	var disguised := DISGUISED.has(id_)
	var C := Game.combat
	# fresh from the toast: blowCover (the stage's on_enter, right after this) plays the unmasking, so leave the mask, guests and gear to it
	var animate: bool = id_ == "brawl" and not instant and b.flag("toasted") == true and not guests.scattered
	if disguised:
		if C != null:
			if C.cur >= 0:
				C.equip(-1)
			C.load_slots([])
		guests.reset()
		audio.set_mode("play")
		for a: Node3D in head_table:
			a.visible = true
		bride.visible = true
		gun_prop.visible = true
		cutout.visible = true
		_topper_home()
	elif not animate:
		_ensure_gear(C)
		disguise.remove()
		guests.scatter()
		guests.all_gone()
		audio.set_mode("panic")
		for a: Node3D in head_table:
			a.visible = false
		bride.visible = false
		topper.visible = false
	if not disguised:
		gun_prop.visible = false
		laser.visible = false
		cutout.visible = false
	_decor_butlers_on(disguised, instant)
	var door_open: bool = _past(id_, "corridor") or (id_ == "brawl" and b.flag("doorOpen") == true)
	b.set_solid(service_door, not door_open)
	for l: Node3D in service_leaves:
		l.rotation.y = float(l.get_meta("open")) if door_open else 0.0
		l.set_meta("swing", false)
	var pantry_open: bool = _past(id_, "laundry") or (id_ == "corridor" and b.flag("pantryOpen") == true)
	b.set_solid(pantry_door, not pantry_open)
	for d: PantryDoor in pantry_doors:
		d.flying = false
		d.g.position = Vector3(37.4 + d.sx * 1.9, FLOOR, 2.5)
		d.g.rotation = Vector3.ZERO
		d.g.visible = not pantry_open
	for tb: FoldTable in tables:
		tb.down = 0.0
		tb.stand_t = 0.0
		tb.s.set_off(false)
		tb.g.rotation = Vector3.ZERO
		tb.g.position.y = FLOOR
	if id_ == "arrival":
		saucer_t = 0.0


func _topper_home() -> void:
	topper.position = topper_home_
	topper.rotation = Vector3.ZERO
	topper.visible = true
	cake_burst = null


func _ground(x: float, z: float, y: float) -> float:
	var h: float = world.ground_height(x, z, 0.1, y + 0.5)
	return h if is_finite(h) else FLOOR


## the toast went wrong: mask off, record scratch, everyone dives, the cake gives your gear back
func _blow_cover(_b: Blockout) -> void:
	audio.set_mode("scratch")
	disguise.knock_off(fx_root)
	guests.scatter()
	unmask = {"t": 0.0, "gave": false}
	if Game.fx != null:
		Game.fx.shake = maxf(Game.fx.shake, 0.35)
	guests.say("THE MC", "GET HIM!", 0.0, FLOOR + 2.6, 18.2, 0.6, "alert")


# ================================================================== per frame
func _look_key(P: Player) -> String:
	if P.y > 29.0 and P.x < -45.0:      # the roof garden, outside under the dusk sky
		return "out"
	if P.y > 39.5:
		return "pent"
	if P.z < -72.5:
		return "out"
	if P.x > -25.4 and P.x < 26.0 and P.z > 28.2 and P.z < 62.4 and P.y > 4.0:
		return "casino"
	if P.x < -28.8 and P.x > -52.4 and P.z > 3.8 and P.z < 46.4:
		return "conserv"
	if P.x < -30.8 and P.x > -64.4 and P.z > -30.4 and P.z <= 3.8:
		return "gallery"
	if P.x < -21.8 and P.x > -44.4 and P.z < -31.8 and P.z > -54.4:
		return "chapel"
	if P.x > 43.6 and P.z < -14.3 and P.y < 1.0:
		return "counting"
	if P.x > 7.4 and P.x < 28.4 and P.z < -29.8 and P.z > -50.4:
		return "cellar"
	if P.x < 27.0:
		return "grand"
	if P.z >= 14.2 and P.x > 29.0:
		return "kitchen"
	return "laundry" if P.x >= 44.0 else "service"


func _blend_look(dt: float, P: Player) -> void:
	var l: Dictionary = LOOKS[_look_key(P)]
	var k := 1.0 - exp(-dt * 2.5) if not look_cur.is_empty() else 1.0
	if look_cur.is_empty():
		look_cur = {"sky": Color(), "ground": Color(), "hemi": 0.0, "sun": Color(), "sun_i": 0.0, "fog": Color(), "dens": 0.0}
	look_cur.sky = (look_cur.sky as Color).lerp(MsKit.srgb(l.sky), k)
	look_cur.ground = (look_cur.ground as Color).lerp(MsKit.srgb(l.ground), k)
	look_cur.hemi = float(look_cur.hemi) + (float(l.hemi) - float(look_cur.hemi)) * k
	look_cur.sun = (look_cur.sun as Color).lerp(MsKit.srgb(l.sun), k)
	look_cur.sun_i = float(look_cur.sun_i) + (float(l.sun_i) - float(look_cur.sun_i)) * k
	look_cur.fog = (look_cur.fog as Color).lerp(MsKit.srgb(l.fog), k)
	look_cur.dens = float(look_cur.dens) + (float(l.dens) - float(look_cur.dens)) * k
	Game.view.set_hemi(look_cur.sky, look_cur.ground, look_cur.hemi)
	Game.view.set_sun(look_cur.sun, look_cur.sun_i)
	Game.view.set_fog_exp2(look_cur.fog, look_cur.dens)


func _tick_ms(dt: float, P: Player, C: Combat, _b: Blockout) -> void:
	clock += dt
	var t := clock
	# zones: things only draw (and animate) while you are near their part of the house
	if P != null:
		(zones["out"] as Node3D).visible = P.z < -55.0
		(zones["vest"] as Node3D).visible = P.z > -80.0 and P.z < -46.0 and P.x < 8.0
		(zones["hall"] as Node3D).visible = (U.hyp(P.x, P.z) < 31.0 and P.y < 42.0) or (absf(P.x) < 8.0 and P.z < -27.0 and P.z > -62.0)
		(zones["service"] as Node3D).visible = P.x > 22.0 and P.z < 36.0      # (the JS stops at z 28.2, which hides the rail you ride and the paddles over the vats at z 30: kept in sight here)
		(zones["casino"] as Node3D).visible = P.z > 26.0 and P.x > -30.0 and P.x < 30.0 and P.y < 23.0
		(zones["pent"] as Node3D).visible = P.y > 30.0 and U.hyp(P.x, P.z) < 30.0
		var outside := P.z < -48.0 or (P.y > 29.0 and P.x < -45.0)      # the villa's outside (most of the triangles) is not drawn from deep inside
		for m: Node3D in exterior:
			m.visible = outside
		_blend_look(dt, P)
	for a: Array in rig_actors:
		if (zones[a[1]] as Node3D).visible:
			(a[0] as NpcRig).update(t, dt)
	var disguised := DISGUISED.has(stage_id)
	if P != null and disguised and not disguise.worn:
		disguise.wear(Game.animator, char_id())
	disguise.update(dt, _ground)
	guests.update(dt, P, disguised)
	beams.update(t, dt, P)
	ent.update(dt, Game.combat.enemies.robots if Game.combat != null else [])
	# ---- the greens' saucer: hovers, the pilot waves, then it lifts off over the rail and away
	saucer_t += dt
	var u := maxf(0.0, saucer_t - 5.5)
	green_ride.position = Vector3(5.0 + u * u * 1.4, 3.2 + sin(t * 2.0) * 0.12 + u * u * 1.8, -93.0 - u * u * 3.2)
	green_ride.rotation.z = sin(t * 1.5) * 0.05 + u * 0.08
	green_ride.visible = u < 14.0
	if green_ride.visible and (zones["out"] as Node3D).visible:
		set_saucer_lights(green_ride, t)
		pilot_arm.rotation.z = -2.2 + sin(t * 9.0) * 0.5
	if stage_id == "arrival" and saucer_t > 0.8 and saucer_t - dt <= 0.8:
		radio("You're in. Remember: you're a gray now. Act gray.")
	if stage_id == "arrival" and saucer_t > 5.0 and saucer_t - dt <= 5.0:
		radio("The greens hid your gear in the wedding cake. Get to the cake, then get to the Godmother.")
	if stage_id == "arrival" and saucer_t > 10.0 and saucer_t - dt <= 10.0:
		radio("And whatever you do... don't let anybody look at you too long.")
	# ---- a guest's lowrider saucer comes in to land on the left pad, sits, and goes (every 24 s)
	var m_ := fmod(t, 24.0)
	var ly := 0.15
	var lk := 0.0
	if m_ < 5.0:
		lk = 1.0 - m_ / 5.0
		ly = 0.15 + lk * lk * 30.0
	elif m_ > 14.0:
		lk = (m_ - 14.0) / 6.0
		ly = 0.15 + lk * lk * 30.0
	lowrider.position = Vector3(-14.0 - lk * 40.0, ly, -91.0 - lk * 10.0)
	lowrider.rotation.y = 0.6 + lk
	lowrider.visible = m_ < 19.5
	if lowrider_dome != null:
		lowrider_dome.rotation.x = -1.0 if m_ > 6.0 and m_ < 13.0 else 0.0
	# ---- the front doors open while the player is near the doorway (either side), close when they have gone
	if P != null:
		var want := 1.0 if absf(P.x) < 6.0 and P.z > -82.0 and P.z < -63.0 else 0.0
		front_open += (want - front_open) * minf(1.0, dt * (3.0 if want != 0.0 else 1.6))
		var fk := front_open * front_open * (3.0 - 2.0 * front_open)
		for h: Node3D in front_leaves:
			h.rotation.y = -float(h.get_meta("open")) * fk
	# ---- band: they play along with the record (frozen when it scratches, fast once the fight starts)
	var hall_on: bool = (zones["hall"] as Node3D).visible
	hall_lights.set_shown(hall_on)
	if hall_on:
		band.update(audio.song_time(), dt)
		hall_lights.update(dt, band.feel, audio.mode, t)
	# ---- the tommy-gun show on the gallery: paint the cut-out with the laser, then a burst into it (every 6 s)
	if gun_prop.visible and hall_on:
		gun_t += dt
		var m := fmod(gun_t, 6.0)
		var mz := gun_flash.global_position
		gun_flash_o = maxf(0.0, gun_flash_o - dt * 12.0)
		MsKit.opa(gun_flash, gun_flash_o)
		if m > 3.0 and m < 5.0:
			var fire := m > 4.0
			var uu := m - 4.0 if fire else m - 3.0
			var p := Vector3(cutout.position.x + 0.05, 8.0 + sin(uu * 3.0) * 0.3, cutout.position.z - 0.45 + 0.9 * uu)
			laser.visible = true
			laser.position = mz
			if mz.distance_squared_to(p) > 1e-4:
				laser.look_at(p, Vector3.UP, true)
			laser.scale = Vector3(0.5 if fire else 1.0, 0.5 if fire else 1.0, mz.distance_to(p))
			if fire and floori(m * 13.0) != floori((m - dt) * 13.0):
				gun_flash_o = 1.0
				gun_holes = mini(14, gun_holes + 1)
				_holes(gun_holes)
				cutout_shake = 1.0
				if P != null and U.hyp(P.x - 5.0, P.z - 25.0) < 40.0 and Game.sfx != null:
					Game.sfx.play_at("plasma", mz.x, mz.y, mz.z, {"range": 40.0})
		else:
			laser.visible = false
		if m < dt and gun_holes >= 14:
			gun_holes = 0
			_holes(0)
		cutout_shake = maxf(0.0, cutout_shake - dt * 4.0)
		cutout_card.rotation.z = sin(t * 60.0) * 0.05 * cutout_shake
	# ---- unmasking sequence (after the toast)
	if unmask != null:
		unmask.t = float(unmask.t) + dt
		if float(unmask.t) > 0.6 and not unmask.gave:
			unmask.gave = true
			_ensure_gear(C)
			cake_burst = {"t": 0.0, "vy": 9.0, "vx": 1.5}
			var cp := Vector3(CAKE_TOP[0], CAKE_TOP[1], CAKE_TOP[2])
			for c: int in [0xffffff, 0xff8ab0, 0xffd060]:
				sparks(cp, 26, 7.0, Vector3.UP, c)
			toast("YOUR GEAR WAS IN THE CAKE!")
			guests.say("0002PXR", "The cake! Your stuff's in the CAKE! ...We keep playin'!", BAND.singer[0], BAND.singer[1] + 1.6, BAND.singer[2], 0.85, "alert")
		if float(unmask.t) > 1.4:
			for a: Node3D in head_table:
				a.visible = false
		if float(unmask.t) > 3.0:
			unmask = null
	if cake_burst != null:
		cake_burst.t = float(cake_burst.t) + dt
		cake_burst.vy = float(cake_burst.vy) - 18.0 * dt
		topper.position.y = maxf(FLOOR + 0.3, topper.position.y + float(cake_burst.vy) * dt)
		topper.position.x += float(cake_burst.vx) * dt
		topper.rotation.x += dt * 6.0
		if topper.position.y <= FLOOR + 0.31:
			cake_burst = null
	# ---- folding tables: stand on one of the rickety ones and it gives way
	if P != null and not P.dead:
		for tb: FoldTable in tables:
			if not tb.fold or tb.s.off:
				if tb.s.off:
					tb.down = minf(1.0, tb.down + dt * 3.0)
					tb.g.rotation.z = tb.down * 0.9
					tb.g.position.y = FLOOR - tb.down * 0.35
				continue
			var on := P.grounded and U.hyp(P.x - tb.x, P.z - tb.z) < 1.05 and absf(P.y - (FLOOR + 0.85)) < 0.1
			tb.stand_t = tb.stand_t + dt if on else maxf(0.0, tb.stand_t - dt)
			tb.g.rotation.z = sin(t * 40.0) * 0.02 if on else 0.0
			if tb.stand_t > 0.45:
				tb.s.set_off(true)
				MsSound.play([["noise", 0.0, {"type": &"lowpass", "f0": 900.0, "f1": 200.0, "gain": 0.6, "dur": 0.25}], ["tone", 0.0, {"type": &"sine", "f0": 180.0, "f1": 60.0, "gain": 0.5, "dur": 0.2}]], 0.3)
	# ---- the doors the stage hooks only start
	for l: Node3D in service_leaves:
		if l.get_meta("swing", false):
			var op: float = l.get_meta("open")
			l.rotation.y += (op - l.rotation.y) * minf(1.0, dt * 4.0)
			if absf(l.rotation.y - op) < 0.01:
				l.set_meta("swing", false)
	for d: PantryDoor in pantry_doors:      # pantry doors fly when the Muscle comes through
		if d.flying:
			d.vy -= 18.0 * dt
			d.g.position.x += d.vx * dt
			d.g.position.y = maxf(FLOOR, d.g.position.y + d.vy * dt)
			d.g.position.z += d.vz * dt
			d.g.rotation.y += d.spin * dt
			d.g.rotation.z += d.spin * 0.3 * dt
			if d.g.position.y <= FLOOR and d.vy < 0.0:
				d.vy = 0.0
				d.vx *= 0.5
				d.vz *= 0.5
				d.spin *= 0.5
				if absf(d.vz) < 0.3:
					d.flying = false
			d.g.position.z = maxf(-2.0, d.g.position.z)
	# ---- laundry: drums spin, clothes sway, the decor basket rides its beam, vents puff (scalding)
	if (zones["service"] as Node3D).visible:
		for dr: Node3D in drums:
			dr.rotate_object_local(Vector3.BACK, dt * 5.0)
		var cam_p: Vector3 = Game.view.camera.global_position
		for i in lines_.size():
			var ln: Node3D = lines_[i]
			ln.rotation.x = sin(t * 0.9 + i) * 0.12
			if ln.get_child_count() > 0:      # a hanging suit the camera is inside goes away (no cloth filling the screen)
				(ln.get_child(0) as Node3D).visible = not (absf(cam_p.x - ln.position.x) < 1.4 and absf(cam_p.y - ln.position.y + 0.85) < 1.5 and absf(cam_p.z - ln.position.z) < 1.1)
		var bu := (sin(t * 0.45) + 1.0) / 2.0
		basket.position = Vector3(54.5, VENT_Y + 1.0 + 0.4 + bu * (14.0 - (VENT_Y + 1.0) - 1.5), 8.5)
		basket.rotation.y = t * 0.6
		for pd: Node3D in paddles:
			pd.rotation.y = t * 1.2
	vent_cd = maxf(0.0, vent_cd - dt)
	vat_cd = maxf(0.0, vat_cd - dt)
	for v: Vent in vents:
		var m := fmod(t + v.off, 3.4)
		var puff := sin((m - 2.4) / 1.0 * PI) if m > 2.4 else 0.0
		var warn := m > 1.8 and m < 2.4
		MsKit.opa(v.s, puff * 0.7 + (0.12 * (1.0 if sin(t * 30.0) > 0.0 else 0.0) if warn else 0.0))
		v.s.scale = Vector3(1.4 + puff, 1.0 + puff * 3.2, 1.0)
		v.s.position.y = VENT_Y + 0.5 + puff * 1.6
		if P != null and not P.dead and puff > 0.3 and vent_cd <= 0.0 and U.hyp(P.x - v.x, P.z - v.z) < 1.15 and P.y < VENT_Y + 3.0 and C != null:
			vent_cd = 0.8
			C.hurt_player(P, 8.0, v.x, v.z, "bolt")
			P.vy = maxf(P.vy, 5.0)
		if warn and floori(m * 8.0) != floori((m - dt) * 8.0) and P != null and U.hyp(P.x - v.x, P.z - v.z) < 12.0:
			MsSound.noise(0.06, &"bandpass", 3200.0, 3200.0, 0.08, 3.0, 0.2)
	# ---- kitchen: the vats are HOT (land in one and it throws you out)
	for vt: Array in VATS:
		if P != null and not P.dead and C != null and vat_cd <= 0.0 and U.hyp(P.x - float(vt[0]), P.z - float(vt[1])) < float(vt[2]) and absf(P.y - VAT_TOP) < 0.25:
			vat_cd = 0.6
			C.hurt_player(P, 10.0, vt[0], vt[1], "bolt")
			P.vy = 9.0
			P.grounded = false
			toast("HOT SAUCE!")
	if stage_id == "kitchen" or stage_id == "laundry":
		_cooks_watch(dt if stage_id == "kitchen" else 0.0, P if stage_id == "kitchen" else null)
	act2.update(dt, P, C, t)
	# ---- sound: band near the stage, crowd while there are guests, beams, laundry machines
	if P != null:
		var nb := 999.0
		for l: MsBeams.Lift in beams.lifts:
			if not l.decor:
				nb = minf(nb, U.hyp(P.x - l.x, P.z - l.z))
		for r: MsBeams.Rail in beams.rails:
			nb = minf(nb, U.hyp(P.x - r.x, P.z - r.z))
		var in_hall := absf(P.x) < 29.0 and absf(P.z) < 29.0
		var in_villa := P.z > -72.2 and U.hyp(P.x, P.z) < 72.0
		audio.update_audio(dt, {"band": U.hyp(P.x - float(BAND.singer[0]), P.z - float(BAND.singer[2])), "inside": in_villa and P.x < 30.0, "hall": in_hall, "guests": 0.0 if guests.scattered else (1.0 if in_hall else (0.1 if P.z > -62.0 else 0.03)), "beam": nb, "laundry": 1.0 if P.x > 43.0 and P.z < 14.5 else 0.0})


func _holes(n: int) -> void:
	for i in cutout_holes.size():
		(cutout_holes[i] as Node3D).visible = i < n


# ================================================================== stages + objectives
func _mark(id_: String) -> Callable:
	return func(_b: Variant = null, _o: Variant = null) -> void: cur_obj = id_; act2.cur_obj = id_


func _soldier(x: float, y: float, z: float, more: Dictionary = {}) -> Dictionary:
	var d := {"x": x, "y": y, "z": z, "kind": "alien"}
	d.merge(more)
	return d


# the ways into the hall: the receiving line's doorway (south), and the wine cellar's stairs behind the open cellar door (the family's guards come up them)
func _from_line(x: float, delay: float) -> Dictionary:
	return {"from": [[x, FLOOR, -44.0], [x, FLOOR, -28.0]], "delay": delay}


func _from_cellar(x: float, delay: float) -> Dictionary:
	return {"from": [[x, -2.0, -41.0], [x, -2.0, -36.4], [x, FLOOR, -29.8], [x, FLOOR, -26.5]], "delay": delay}


func setup() -> void:
	_prepare()
	var alias_ := "LITTLE VITO" if char_id() == "tommy" else "UNCLE SAL"
	bo.stage({"id": "arrival", "name": "Arrival", "spawn": {"x": 0.0, "y": 0.0, "z": -95.0, "yaw": 0.0}, "task": "You are a gray now. Walk in like you own the place.",
		"objectives": [{"id": "stairs", "label": "The front door", "text": "Up the stairs and through the front door. Walk, don't run: grays don't run.", "at": [0.0, FLOOR, -74.0], "radius": 3.5, "on_start": _mark("stairs")}]})
	bo.stage({"id": "line", "name": "The Receiving Line", "spawn": {"x": 0.0, "y": FLOOR, "z": -73.0, "yaw": 0.0}, "task": "Get past the family. Everybody is looking at you.",
		"objectives": [
			{"id": "coat", "label": "Vestibule", "text": "Through the vestibule. (The coat check wants a word: X.)", "at": [0.0, FLOOR, -61.0], "radius": 2.6, "on_start": _mark("coat")},
			{"id": "guestbook", "label": "Sign the guestbook", "kind": "hold", "hold": 1.3, "text": "Down the receiving line. Sign the guestbook as \"" + alias_ + "\".", "at": [3.2, FLOOR, -30.4], "prompt": "SIGN THE GUESTBOOK", "on_start": _mark("guestbook")},
			{"id": "canape", "label": "Take a canapé", "kind": "hold", "hold": 1.0, "text": "Blend in: take a canapé from the butler.", "at": [-3.4, FLOOR, -34.6], "prompt": "TAKE A CANAPÉ", "on_start": _mark("canape"), "on_done": func(_b: Variant = null) -> void: toast("...IT'S A MEATBALL WITH AN EYE. DELICIOUS.")},
		]})
	bo.stage({"id": "reception", "name": "The Reception", "spawn": {"x": 0.0, "y": FLOOR, "z": -30.0, "yaw": 0.0}, "task": "The cake is in the middle of the hall. Your gear is inside it.",
		"objectives": [
			{"id": "enter", "label": "The reception", "text": "Into the reception. Don't stare at the cake.", "at": [0.0, FLOOR, -21.0], "radius": 3.0, "on_start": _mark("enter")},
			{"id": "toast", "label": "The toast", "kind": "custom", "text": "The MC is calling for a toast... from YOU. Go to the microphone and talk (X).", "at": [0.0, FLOOR + 1.2, 16.8], "radius": 2.2, "on_start": _mark("toast"), "done": func(_a: Variant = null, _P: Variant = null, _c: Variant = null) -> bool: return bo.flag("toasted") == true},
		]})
	bo.stage({"id": "brawl", "name": "The Wedding Brawl", "spawn": {"x": 0.0, "y": FLOOR + 1.2, "z": 15.5, "yaw": PI}, "task": "Your cover is blown. The family wants you dead.",
		"on_enter": func(b: Blockout, o: Dictionary) -> void:
			if not o.get("retry", false) and b.flag("toasted") == true:
				_blow_cover(b),
		"objectives": [
			{"id": "wave1", "label": "The guests", "kind": "kill", "text": "Fight! The tables are cover (some of them won't hold your weight).", "on_start": _mark("wave1"),
				"spawns": [_soldier(-3.5, FLOOR, -19.0, _from_line(-1.4, 0.0)), _soldier(3.5, FLOOR, -18.0, _from_line(1.4, 0.7)), _soldier(9.5, FLOOR, -21.0, _from_cellar(9.0, 0.4)), _soldier(12.0, FLOOR, -15.0, _from_cellar(9.6, 1.5)),
					{"x": -6.0, "y": FLOOR + 2.5, "z": -12.0, "kind": "butler", "from": [[-0.6, FLOOR + 2.5, -44.0], [-0.6, FLOOR + 2.5, -27.0]], "delay": 1.2}, {"x": 6.0, "y": FLOOR + 2.5, "z": -12.0, "kind": "butler", "from": [[0.6, FLOOR + 2.5, -45.0], [0.6, FLOOR + 2.5, -27.0]], "delay": 2.0}]},
			{"id": "wave2", "label": "The tommy gun", "kind": "kill", "spawn": {"x": -8.0, "y": FLOOR, "z": -5.0, "yaw": 0.3}, "text": "The tommy-gun gray is on the dais, behind the head table. He PAINTS his sweep with a red laser first. Get behind cover or jump the line.", "on_start": _mark("wave2"),
				# the gunner you watched practising up on the gallery hops down off its rail onto the dais; three more come in from the receiving line
				"spawns": [{"x": 4.5, "y": FLOOR + 1.2, "z": 22.4, "kind": "tommygun", "from": [[5.5, 7.5, 25.6, "air"], [5.2, 8.5, 24.6, "air"], [4.8, 6.2, 23.3, "air"]], "speed": 4.5},
					_soldier(-1.5, FLOOR, -23.0, _from_line(-1.5, 0.6)), _soldier(1.5, FLOOR, -22.0, _from_line(1.5, 1.3)), _soldier(0.0, FLOOR, -20.0, _from_line(0.0, 2.0))]},
			{"id": "door", "label": "Service door", "spawn": [12.0, FLOOR, 2.0], "text": "The service door is open. Through the kitchens -- the Godmother is upstairs.", "at": [24.5, FLOOR, 0.0], "radius": 2.6, "on_start": func(b: Blockout, _o: Variant = null) -> void:
				cur_obj = "door"
				act2.cur_obj = "door"
				b.flag("doorOpen", true)
				b.set_solid(service_door, false)
				for l: Node3D in service_leaves:
					l.set_meta("swing", true)},
		]})
	bo.stage({"id": "corridor", "name": "Service Corridor", "spawn": {"x": 24.5, "y": FLOOR, "z": 0.0, "yaw": PI / 2.0}, "task": "Staff only. Solo personale.",
		"objectives": [
			{"id": "in", "label": "Corridor", "text": "Down the service corridor.", "at": [31.5, FLOOR, 0.0], "radius": 2.2, "on_start": _mark("in")},
			{"id": "muscle", "label": "The Muscle", "kind": "kill", "spawn": [31.5, FLOOR, 0.0], "text": "THE MUSCLE. His chest plate blocks bullets: blast it open with the BELLOWS (or a hammer fist), then shoot the glow.",
				# the Muscle charges out through the pantry's swing doors; two more come up the laundry stairs at the end of the corridor
				"spawns": [{"x": 37.4, "y": FLOOR, "z": 0.6, "kind": "muscle", "from": [[37.4, FLOOR, 6.4]], "speed": 6.5},
					_soldier(43.5, FLOOR, 1.2, {"from": [[45.8, -4.0, -13.0], [45.8, FLOOR, -3.2], [46.2, FLOOR, 0.5]], "delay": 1.2}), _soldier(43.0, FLOOR, -1.3, {"from": [[45.8, -4.0, -14.5], [45.8, FLOOR, -3.2], [46.2, FLOOR, -1.2]], "delay": 2.0})],
				"on_start": func(b: Blockout, o: Variant = null) -> void:
					cur_obj = "muscle"
					act2.cur_obj = "muscle"
					b.flag("pantryOpen", true)
					b.set_solid(pantry_door, false)
					var retry: bool = o is Dictionary and (o as Dictionary).get("retry", false)
					for d: PantryDoor in pantry_doors:
						if retry:
							d.g.visible = false
							continue
						d.flying = true
						d.vx = d.sx * 2.5
						d.vy = 4.0
						d.vz = -9.0
						d.spin = d.sx * 8.0
					if Game.fx != null:
						Game.fx.shake = 0.5},
			{"id": "landing", "label": "Laundry landing", "spawn": [36.0, FLOOR, 0.0], "text": "Through to the laundry.", "at": [47.0, FLOOR, 0.0], "radius": 2.2, "on_start": _mark("landing")},
		]})
	bo.stage({"id": "laundry", "name": "The Laundry", "spawn": {"x": 47.0, "y": FLOOR, "z": 0.0, "yaw": PI / 2.0}, "task": "The house runs on tractor beams. So do you.",
		"objectives": [
			{"id": "lift", "label": "Lift beam", "text": "See the basket riding the blue beam? Down the stairs and step into the LIFT BEAM.", "at": [50.6, -4.0, -12.1], "radius": 1.4, "via": [[45.8, FLOOR, -2.8], [45.8, -3.4, -12.4], [48.4, -4.0, -12.4]], "on_start": _mark("lift")},
			{"id": "c1", "label": "Catwalk", "text": "Ride it up, then steer out onto the catwalk.", "at": [57.5, 4.0, -12.1], "radius": 2.0, "on_start": _mark("c1")},
			{"id": "b", "label": "Over the vents", "text": "Hop into the next beam. Don't fall: the steam vents below are scalding.", "at": [63.8, 8.0, -7.0], "radius": 2.0, "on_start": _mark("b")},
			{"id": "c", "label": "The timed beam", "text": "This beam runs on the wash cycle: it FLICKERS before it cuts out. Wait for it to come back, then ride it up.", "at": [61.5, 13.0, 5.0], "radius": 2.4, "spawns": [{"x": 60.0, "y": 15.5, "z": 8.0, "kind": "butler", "from": [[60.1, 14.8, 20.0], [60.1, 14.8, 14.2]]}], "on_start": _mark("c")},      # out of the kitchen's door, over the timed beam
		]})
	bo.stage({"id": "kitchen", "name": "The Kitchen", "spawn": {"x": 61.5, "y": 13.0, "z": 9.0, "yaw": 0.0}, "task": "The kitchen ceiling is all rails.",
		"objectives": [
			{"id": "balcony", "label": "Kitchen balcony", "text": "Into the kitchen.", "at": [59.0, 13.0, 17.4], "radius": 2.2, "on_start": _mark("balcony")},
			{"id": "r1", "label": "Rail beam", "text": "Step under the RAIL BEAM (cyan) when it comes back. It carries you. Jump to let go.", "at": [58.6, 13.0, 30.6], "radius": 2.2, "on_start": _mark("r1")},
			{"id": "r2", "label": "Over the vats", "text": "Ride the next rail over the sauce vats. The cooks will shoot -- shoot back.", "at": [33.0, 13.0, 30.0], "radius": 2.4, "on_start": _mark("r2")},
			{"id": "exit", "label": "To the casino", "spawn": [30.0, 13.0, 30.4], "text": "Through the door: CASINO LA LUNA.", "at": [27.6, 13.0, 30.0], "radius": 1.8, "on_start": _mark("exit")},
		]})
	act2.stages()


func on_exit() -> void:
	disguise.remove()
	super.on_exit()
