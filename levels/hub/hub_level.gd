class_name HubLevel
extends ExportedLevel
## The hub street and FOINT CITY, exported from the three.js game. So far what makes it walkable and look right: which part of the map is drawn from where, the sky's slow drift and the haze that follows it
## (JS levels/hub/district-view.js, city-style.js createNightSky). What moves in it is levels/hub/hub_life.gd, its talkers' bodies levels/hub/hub_npcs.gd, the street's own bits levels/city_life.gd.

const SKY_CYCLE := 420.0    # seconds for a full there-and-back. Long enough that you notice it only if you stop and look up.
const VIOLET := {"horizon": Vector3(0.044, 0.012, 0.0375), "band": Vector3(0.024, 0.008, 0.032), "zenith": Vector3(0.0057, 0.0032, 0.0134), "fog": Color(0.026, 0.007, 0.0225), "moon": Vector3(0.42, 0.4, 0.5), "halo": Vector3(0.0175, 0.0125, 0.022), "moon_r": 0.9986, "cloud": 0.5}
const EMBER := {"horizon": Vector3(0.066, 0.0085, 0.0055), "band": Vector3(0.037, 0.004, 0.0036), "zenith": Vector3(0.011, 0.0019, 0.0029), "fog": Color(0.04, 0.005, 0.0033), "moon": Vector3(0.4, 0.39, 0.46), "halo": Vector3(0.0275, 0.009, 0.0075), "moon_r": 0.998, "cloud": 0.78}

const DYO_DIR := Vector3(0.2983, 0.20508, 0.93218)     # JS DYO_DIR, the bearing it hangs on
const DYO_DIST := 1500.0
const DYO_SIZE := 32.0
const DYO_RINGS := [["DyoRing1.3", Vector3(0.3, 0.0, 0.2), Vector3(0.1, 0.06, 0.0)], ["DyoRing1.58", Vector3(1.2, 0.5, 0.0), Vector3(-0.045, 0.0, 0.08)], ["DyoRing1.9", Vector3(0.1, 0.9, 1.4), Vector3(0.0, -0.055, 0.035)]]

var vending := {"x": 7.5 - 0.67, "z": -19.4, "prompt": {"x": 7.5 - 0.67 - 1.9, "z": -19.4, "r": 2.3}}
var vending_injector: VendingInjector = null
var shop_tv: CrtTv = null
var _beatdown: Beatdown = null
var _clerk: PalePunk = null
var _clerk_fall := 0.0
var boss_intro: BossIntro = null
var office_shutup: OfficeShutup = null
var shitchan_clap: ShitchanClap = null
var cherub_fart: CherubFart = null
const TV_SPOT := Vector2(14.09, 6.96)
var _dyo: Node3D = null
var _dyo_station: Node3D = null
var _dyo_rings: Array = []         # [node, base, spin]
var _dyo_echo: Node3D = null
var _dyo_echo_mat: BaseMaterial3D = null
var _dyo_shards: Node3D = null
var _dyo_frags: Node3D = null
var _dyo_halo: ShaderMaterial = null
var _dyo_aura: ShaderMaterial = null
const GY := -10.0                  # the district's ground level
var _district: Node3D = null
var _hub_sky: Array = []
var _street_was: Array[bool] = []
var _street: Array[Node] = []
var _far := false
var _sky_mat: ShaderMaterial = null
var _fog_hub := Color.BLACK       # the hub's own fog colour, kept to fade back to (linear)
var _fog_k := -1.0
var _sky_k := -1.0
var life: HubLife = null           # the traffic, the crowd, the street clock (levels/hub/hub_life.gd)
var actors: Dictionary = {}        # talker id -> its body (levels/hub/hub_npcs.gd)
var _targets_in := false
var _npc_t := 0.0
const CHERUB_ID := 98              # combat target id of the hub's cherub
var _cherub_at := -100000
var _cherub_last := -1
var _pain_at := -100000


func build() -> void:
	super.build()
	# where a rocket / stone / bolt hits "the floor" (Combat's floor_at): the hub street is at y 0, but down in the city the ground is GY (-10), so a flat 0.02 floor would blow every shot up at the muzzle. Past the bridge head the roads and slabs are real colliders; what is left to catch is the sea. (JS district.js; the export carries the data, not this function)
	world.projectile_floor_at = func(x: float, z: float) -> float:
		if z < 64.0:      # BRIDGE.z0
			return 0.02
		var s: Variant = world.water.call(&"at", x, z) if world.water != null else null
		return float(s) if s != null else -13.6      # WATER_Y - 1
	_doors_and_talkers()
	city = CityLife.new(self, true)
	city_ambience = true
	var d: Array = node_named("FointDistrict")
	if d.is_empty():
		push_error("hub: no FointDistrict node in the export")
		return
	_district = d[0]
	_hub_sky = node_named("HubSky")
	for c in _district.get_parent().get_children():
		if c != _district:
			_street.append(c)
	if shader_ports != null:
		_sky_mat = shader_ports.mats.get("shader_4a3f88#0")
	_dyo = _one("Dyosphere")
	_dyo_station = _one("DyoStation")
	_dyo_echo = _one("DyoEcho")
	_dyo_shards = _one("DyoShards")
	_dyo_frags = _one("DyoFrags")
	for r: Array in DYO_RINGS:
		var ring := _one(r[0])
		if ring != null:
			_prep_euler(ring)
			_dyo_rings.append([ring, r[1], r[2]])
	for n: Node3D in [_dyo_station, _dyo_echo, _dyo_shards, _dyo_frags]:
		_prep_euler(n)
	if _dyo_echo != null:
		for mi: Node in _dyo_echo.get_children():
			if mi is MeshInstance3D:
				_dyo_echo_mat = (mi as MeshInstance3D).mesh.surface_get_material(0) as BaseMaterial3D
	if shader_ports != null:
		_dyo_halo = shader_ports.mats.get("shader_34e20b#0")
		_dyo_aura = shader_ports.mats.get("shader_8dce7b#0")
	var f: Dictionary = info.get("fog", {})
	_fog_hub = Color.html(String(f.get("hex", "0a1119"))).srgb_to_linear()
	life = HubLife.load_for(self)
	if life != null:
		actors = HubNpcs.build(self, life.J, life.bin)
		_office_scenes()
		_place_clerk()
		if Game.story_get("beaten") and actors.has("gray_alien"):      # (JS: the beat-down took him for good)
			(actors["gray_alien"] as Node).queue_free()
			actors.erase("gray_alien")
		for t: Dictionary in Game.dialogue.talkers:
			if actors.has(t["id"]):
				t["actor"] = actors[t["id"]]
		_hide_baked_talkers()
		_place_vending()
		_place_shop_tv()
		life.release_bin()      # (100 MB of geometry, in the meshes by now)


## JS shopTV: the gunshop's hanging CRT. The set comes with the export; stand under it and X plays the video.
func _place_shop_tv() -> void:
	var sc := node_named("CrtScreen")
	if sc.is_empty():
		return
	var n: Node = sc[0]
	var mi: MeshInstance3D = n if n is MeshInstance3D else n.find_children("*", "MeshInstance3D", true, false)[0]
	shop_tv = CrtTv.new()
	add_child(shop_tv)
	shop_tv.position = Vector3(15.35, 4.0, 6.35)
	shop_tv.setup(mi)
	actions.append({"x": TV_SPOT.x, "z": TV_SPOT.y, "label": func() -> String: return "TURN OFF — TV" if shop_tv.playing else "WATCH — TV",
		"active": func(p: Player) -> bool: return p.y < 1.5 and U.hyp(p.x - TV_SPOT.x, p.z - TV_SPOT.y) < 1.9,
		"run": func() -> void:
			if shop_tv.playing:
				shop_tv.stop()
				Game.sfx.play("vendNav")
			else:
				shop_tv.play_once()})


## JS city.vending: the implant machine on the right wall, z -19.4. The cabinet comes with the export; its flap is named VendFlap by the JS, its arms are made here.
func _place_vending() -> void:
	vending_injector = VendingInjector.new()
	add_child(vending_injector)
	vending_injector.position = Vector3(float(vending.x), 0.0, float(vending.z))
	vending_injector.rotation.y = -PI / 2.0
	vending_injector.scale = Vector3.ONE * 1.3
	var fl := node_named("VendFlap")
	if not fl.is_empty():
		vending_injector.flap_node = fl[0] as Node3D


## The export froze the talkers where they stood; the live bodies above replace them. (Among the Gray aliens the talker is the one on the far pavement: the others are the plaza's and the saucers'.)
func _hide_baked_talkers() -> void:
	for nm: String in ["Puppy (NPC)", "Winged creature (NPC)", "Grotesque cherub (NPC)", "Green alien (Club 9)", "Armchair General", "Gray alien (NPC)", "Green alien (NPC)"]:
		for o: Node in node_named(nm):
			if o is Node3D:
				(o as Node3D).visible = false


## JS hubSpawnAt: where each door of the hub lets you out.
func apply_spawn(at: String) -> void:
	match at:
		"club9":      # out of CLUB 9: on the pavement at the club doorway, facing the street
			world.spawn = {"x": -7.5 + 1.5, "y": 0.15, "z": -36.6, "yaw": PI / 2.0}
		"foint":      # out of FOINT ARENA: in the gate hall, facing the city
			world.spawn = {"x": 0.0, "y": GY + 0.1, "z": 220.5 - 4.0, "yaw": PI}


## JS index.html ~13585-13609: the office's people and what they do: the first walk up to the Boss's desk, Shit-chan and the Cherub on X, and the talkers' Boss turns to face you.
func _office_scenes() -> void:
	var off: HubOffice = life.office
	var oa := off.actors
	oa.load_cherub(life.J, life.bin)
	for t: Dictionary in Game.dialogue.talkers:
		if String(t["id"]).begins_with("boss_vent"):
			t["actor"] = oa.boss_actor
	boss_intro = BossIntro.new()      # the first time Prog walks up to the desk: the recorded boss intro gives the DEAD AIR job in place of the boss_vent_job dialogue, once
	boss_intro.actors = oa
	boss_intro.on_end = func(_finished: bool, alt: bool) -> void:      # the intro IS the DEAD AIR job briefing: finishing or skipping it hands over the job
		if alt:
			return
		Game.story_set("bossIntro")
		if not Game.story_get("ventJob"):
			Game.story_set("ventJob")
			Game.hud.toast("WEAPONS LEFT ON THE BOSS\u2019S DESK  /  INTAKE GRATE: ALLEY, LEFT WALL", 3.2)
		Game.save_game()
	add_child(boss_intro)
	office_shutup = OfficeShutup.new()      # cutscene list only
	office_shutup.actors = oa
	add_child(office_shutup)
	shitchan_clap = ShitchanClap.new()      # Shit-chan: X next to her (as Prog) plays her short exchange with him, every time
	shitchan_clap.actors = oa
	add_child(shitchan_clap)
	actions.append({"x": 118.7, "z": 332.15, "label": "TALK \u2014 SHIT-CHAN",
		"active": func(p: Player) -> bool: return Game.char_pick == "prog" and oa.shit != null and absf(p.y - GY) < 1.0 and U.hyp(p.x - 118.7, p.z - 332.15) < 2.3,
		"run": func() -> void: shitchan_clap.play()})
	cherub_fart = CherubFart.new()      # the Cherub at his desk: X next to him (as Prog) plays his next scene: the fart and his exchange with Prog, then his files line, then round again
	cherub_fart.actors = oa
	add_child(cherub_fart)
	actions.append({"x": 120.1, "z": 328.95, "label": "TALK \u2014 CHERUB",
		"active": func(p: Player) -> bool: return Game.char_pick == "prog" and oa.cherub != null and absf(p.y - GY) < 1.0 and U.hyp(p.x - 120.1, p.z - 328.95) < 2.2,
		"run": func() -> void: cherub_fart.play_next()})


## JS: the gunshop clerk (his own asset, npcs/pale_punk.gd) behind the counter, facing the door. The export's copy of him is a statue: it goes.
func _place_clerk() -> void:
	for n: Node in node_named("Pale Punk (gunshop clerk)"):
		(n as Node3D).visible = false
	_clerk = PalePunk.new()
	add_child(_clerk)
	_clerk.position = Vector3(18.9, 0.025, 10.5)
	_clerk.rotation.y = -PI / 2.0


## JS clerkFX: the shopkeeper's hit reactions and his death fall
func _clerk_fx(now: float, dt: float) -> void:
	var T: Target = Game.combat.clerk
	if T == null:
		return
	_clerk_fall += ((1.0 if T.dead else 0.0) - _clerk_fall) * minf(1.0, dt * 5.0)
	_clerk.rotation = Vector3(-1.45 * _clerk_fall, -PI / 2.0, 0.0)
	var sh := 0.0 if T.dead else T.wob * 0.045 * sin(now * 55.0)
	_clerk.position = Vector3(18.9 + sh + 0.3 * _clerk_fall, 0.025 + 0.12 * _clerk_fall, 10.5)


func office_cine() -> bool:
	return (boss_intro != null and boss_intro.on) or (office_shutup != null and office_shutup.on) or (shitchan_clap != null and shitchan_clap.on) or (cherub_fart != null and cherub_fart.on)


## JS beatdown's onEnd: the gray alien is despawned for good: model, talker and the saved flag
func _beatdown_end(finished: bool) -> void:
	var D := Game.dialogue
	for t: Dictionary in D.talkers:
		if t["id"] == "gray_alien":
			D.talkers.erase(t)
			break
	if actors.has("gray_alien"):
		(actors["gray_alien"] as Node).queue_free()
		actors.erase("gray_alien")
	if finished:
		Game.story_set("beaten")
		Game.save_game()


## JS index.html ~13498-13584: the hub's doors and the people you can talk to: everything they say is here, their bodies are levels/hub/hub_npcs.gd.
func _doors_and_talkers() -> void:
	portals.append({"id": "club9", "label": "ENTER CLUB 9", "x": -7.0, "z": -36.6, "radius": 1.6, "to": "club"})      # the CLUB 9 doorway on the street
	portals.append({"id": "foint-arena", "label": "ENTER FOINT ARENA", "x": 0.0, "z": 220.5, "y": GY, "radius": 4.2, "to": "maktar"})      # the gate hall of the FOINT ARENA (the `maktar` level), at the end of the bridge plaza
	actions.append({"x": 108.0, "z": 327.26, "label": "PRISE OPEN THE INTAKE GRATE", "active": func(p: Player) -> bool: return Game.story_get("ventJob") and absf(p.y - GY) < 1.5 and U.hyp(p.x - 108.0, p.z - 327.26) < 1.3,      # (1.3 m: the JS portal's radius) the alley's return-air grate, open once the Boss has given the ventilation job. Only the opening is made: nothing is behind it yet (DEAD AIR is being redesigned), so the cards end on black and the alley comes back
		"run": func() -> void:
			if Game.doors.travelling:
				return
			Game.doors.travelling = true
			Game.player.vx = 0.0
			Game.player.vz = 0.0
			await VentGrate.play_it(Game.char_pick)
			Game.ui.set_fade(true)
			await get_tree().create_timer(0.8, true).timeout
			Game.doors.travelling = false
			Inp.guard_arm()
			Game.ui.set_fade(false)})
	var D := Game.dialogue
	D.add_talker({"id": "armchair_general", "name": "ARMCHAIR GENERAL", "x": -6.4, "y": 0.15, "z": 16.4, "yaw": PI / 2.0, "radius": 2.8, "color": "#d8bd8b", "voice_pitch": 0.65, "type_rate": 23.0,
		"shot": {"cam_dist": 3.0, "cam_y": 1.3, "look_y": 0.9, "spot_fwd": 1.3, "spot_side": 1.0},
		"lines": ["Do you remember? I remember...."]})
	D.add_talker({"id": "green_alien", "name": "GREEN ALIEN", "x": -7.2, "y": 0.15, "z": -39.0, "yaw": PI / 2.0, "radius": 2.6, "color": "#7be34a",
		"lines": ["You should try your luck at the Foint arena for some extra cash if you're strapped. Fuck these gray aliens man shiet."],
		"on_end": func(_t: Dictionary) -> void: Game.story_set("talkedGreen")})      # the gray alien only has his line for someone who has been seen talking to the green one
	D.add_talker({"id": "puppy", "name": "PUPPY", "x": -7.15, "y": 0.15, "z": 29.0, "yaw": PI / 2.0, "radius": 2.6, "color": "#e9b36a", "voice": "dogSyl", "voice_pitch": 1.0, "type_rate": 30.0,
		"shot": {"cam_dist": 2.7, "cam_y": 1.15, "look_y": 0.95, "spot_fwd": 0.85},
		"lines": ["Woof! ...I mean, hello! Are you a friend? I like friends. Do you have any snacks? I will be very, very good."]})
	D.add_talker({"id": "winged", "name": "WINGED THING", "x": 7.1, "y": 0.15, "z": -8.0, "yaw": -PI / 2.0, "radius": 2.6, "color": "#d9b3a3", "voice_pitch": 1.35, "type_rate": 26.0,
		"shot": {"cam_dist": 3.4, "cam_y": 1.6, "look_y": 1.4, "spot_fwd": 1.05},
		"lines": ["Oh. You can see me. Most people only see the wings.", "Please do not stare at them. ...Everyone stares at the wings."]})
	D.add_talker({"id": "cherub", "name": "CHERUB", "x": -7.05, "y": 0.15, "z": -20.5, "yaw": PI / 2.0, "radius": 2.8, "color": "#e0a9a0", "voice_pitch": 1.2, "type_rate": 24.0, "voice": null,      # no synthesized speech: his recording plays once each time you start talking to him
		"active": func() -> bool: return not (actors.has("cherub") and (actors["cherub"] as HubNpcs.Cherub).dead),
		"on_start": func(_t: Dictionary) -> void: Game.sfx.clip_at(load("res://assets/sfx/cherub-hey-tommy.wav" if Game.char_pick == "tommy" else "res://assets/sfx/cherub-hey-prog.wav"), -7.05, 1.6, -20.5, {"range": 40.0, "ref": 4.0, "wet": 0.1}),      # "hey Prog" or "hey Tommy", by who is playing
		"shot": {"cam_dist": 3.4, "cam_y": 1.6, "look_y": 1.4, "spot_fwd": 1.05},
		"lines": ["I was painted on a church ceiling once. They painted over me.", "Now I just stand here. My eyes do not close all the way anymore."]})
	if not Game.story_get("beaten"):      # the gray alien on the far pavement: he only appears once you have talked to the green alien; when his line ends the beat-down cutscene plays and he is gone for good
		D.add_talker({"id": "gray_alien", "name": "GRAY ALIEN", "x": 7.2, "y": 0.15, "z": 39.0, "yaw": -PI / 2.0, "radius": 2.6, "color": "#b9c3cc", "voice_pitch": 0.7,
			"active": func() -> bool: return Game.story_get("talkedGreen") and not (_beatdown != null and _beatdown.on),
			"lines": ["Saw you talkin to one of them greens, you know what we do to green sympathizers?"],
			"on_end": func(_t: Dictionary) -> void:
				if _beatdown != null and actors.has("gray_alien"):
					_beatdown.play(actors["gray_alien"])})
		_beatdown = Beatdown.new()
		_beatdown.on_end = _beatdown_end
		add_child(_beatdown)
	# the Boss in the B-9 office gives the ventilation job (DEAD AIR, through the alley grate) and keeps the player's guns, which will not fit down a duct. He stands behind his desk: the player takes the spot on its far side.
	var boss := {"name": "THE BOSS", "x": 127.0, "y": GY, "z": 330.0, "yaw": -PI / 2.0, "radius": 3.6, "color": "#d8bd8b", "voice_pitch": 0.65, "type_rate": 26.0,
		"shot": {"cam_dist": 5.4, "cam_side": 0.2, "cam_y": 1.55, "look_y": 1.2, "look_side": 0.5, "spot_fwd": 3.1, "spot_side": 0.55}}
	var job := boss.duplicate()
	job.merge({"id": "boss_vent_job", "active": func() -> bool: return not Game.story_get("ventJob") and Game.story_get("bossIntro"),      # fallback only: the recorded boss intro gives the job; this plays if a save has seen the intro but never got the job
		"lines": ["The ventilation's down again. Maintenance wants a call-out fee.",
			"You've got hands. You've got those goggles. That's basically qualifications.",
			"Go downstairs, pull whatever's stuck in the fan out, and restart it.",
			"And don't replace the filter. Turn it around.",
			"Way in is the intake grate in the alley. And you're not getting through it dressed like that.",
			"The guns. All of them. You'll wedge in the first bend and I'll be paying a man to cut you out.",
			"On the desk. I'll mind them. I won't play with them. Much."],
		"on_end": func(_t: Dictionary) -> void:
			Game.story_set("ventJob")
			Game.save_game()
			Game.hud.toast("WEAPONS LEFT ON THE BOSS\u2019S DESK  /  INTAKE GRATE: ALLEY, LEFT WALL", 3.2)})
	D.add_talker(job)
	var wait := boss.duplicate()
	wait.merge({"id": "boss_vent_wait", "active": func() -> bool: return Game.story_get("ventJob") and not Game.story_get("ventDone"),
		"lines": ["Grate's in the alley, left wall, by the door. Fan's at the bottom. Go.", "Your guns are fine. Stop looking at them."]})
	D.add_talker(wait)
	var done := boss.duplicate()
	done.merge({"id": "boss_vent_done", "active": func() -> bool: return Game.story_get("ventDone"),      # after DEAD AIR: the air is back on
		"lines": ["Air's back on. See? Was that so hard.", "Smells worse, though.", "...Why are you wet?", "Your guns are on the desk. I didn't touch them. Much."]})
	D.add_talker(done)


func _one(js_name: String) -> Node3D:
	var a := node_named(js_name)
	if a.is_empty():
		push_warning("hub: no node named %s in the export" % js_name)
		return null
	return a[0]


## three.js rotations are XYZ order
static func _prep_euler(n: Node3D) -> void:
	if n != null:
		n.rotation_order = EULER_ORDER_XYZ


## JS createDyosphere update: a sky prop that follows the camera at a fixed distance and bearing (so it never gets closer). It drifts; nothing holds it.
func _dyosphere(t: float, cam: Vector3) -> void:
	if _dyo == null:
		return
	_dyo.global_position = cam + DYO_DIR * DYO_DIST
	if _dyo_station != null:
		_dyo_station.rotation = Vector3(0.14, t * 0.018, -0.08)
		_dyo_station.position.y = sin(t * 0.21) * 0.1 * DYO_SIZE
	for r: Array in _dyo_rings:
		(r[0] as Node3D).rotation = (r[1] as Vector3) + (r[2] as Vector3) * t
	if _dyo_echo != null and _dyo_rings.size() == 3:
		var o: Array = _dyo_rings[2]
		var lag := 1.5 + 0.7 * sin(t * 0.27)       # the echo: where the outer arc was a moment ago, and slightly wrong
		_dyo_echo.rotation = (o[1] as Vector3) + (o[2] as Vector3) * (t - lag) + Vector3(0.05, 0.0, 0.0)
	if _dyo_echo_mat != null:
		_dyo_echo_mat.albedo_color.a = 0.12 + 0.1 * maxf(0.0, sin(t * 0.7))
	if _dyo_shards != null:
		_dyo_shards.rotation = Vector3(t * 0.07, -t * 0.11, sin(t * 0.4) * 0.3)
	if _dyo_frags != null:
		_dyo_frags.rotation = Vector3(sin(t * 0.05) * 0.1, -t * 0.028, 0.0)
	if _dyo_halo != null:
		_dyo_halo.set_shader_parameter(&"uPulse", 1.0 + 0.1 * sin(t * 1.7) + 0.05 * sin(t * 4.3))
		_dyo_halo.set_shader_parameter(&"uScale", float(get_viewport().get_visible_rect().size.y) * DYO_SIZE * 0.9)
	if _dyo_aura != null:
		_dyo_aura.set_shader_parameter(&"uPulse", 1.0 + 0.12 * sin(t * 0.55) + 0.05 * sin(t * 1.3))
		_dyo_aura.set_shader_parameter(&"uSize", DYO_SIZE * 8.0)


## JS skyMix: where in the drift we are, 0 violet, 1 ember, easing so the sky dwells at each end instead of sweeping evenly through the middle
static func sky_mix(t: float) -> float:
	var u := 0.5 - 0.5 * cos(TAU * fmod(t, SKY_CYCLE) / SKY_CYCLE)
	var e := clampf((u - 0.22) / 0.56, 0.0, 1.0)
	return e * e * (3.0 - 2.0 * e)


## JS frame end, after the camera: CityView.update, the district's life in it, then every talker (JS: t.actor.update(now, paused ? 0 : dt)).
func camera_placed(cam: Vector3, real_dt: float) -> void:
	super.camera_placed(cam, real_dt)
	if life != null and _district != null:
		life.update(real_dt, city.t, cam, _district.visible)
	var dt := 0.0 if Game.paused else real_dt
	_npc_t -= real_dt
	var check := _npc_t <= 0.0
	if check:
		_npc_t = 0.5
	for id: String in actors:
		var a: Node3D = actors[id]
		if check:      # JS NPC_FAR: past this they are a few fogged pixels, and down town they are not drawn at all
			var d := U.hyp(a.position.x - cam.x, a.position.z - cam.z)
			a.visible = not _far and d < (150.0 if a.visible else 140.0)
		if a.visible and not (_beatdown != null and _beatdown.on and id == "gray_alien"):      # (the cutscene is moving him)
			a.call(&"update", Game.time, dt)


## (The street's state refers to itself: cars to their types, people to their batches. Nothing else would free it. Also on quitting, which never says on_exit.)
## JS enterLevel: `vehicles.setOwnerActive('hub', id === 'hub')` parks the resident hub's cars. Here the hub is freed with its World, so the controller lets go of them now, while their nodes and solids still exist (`_exit_tree` would be too late: it runs after the next level has spawned its own car).
func on_exit() -> void:
	if life != null and life.driving != null:
		life.driving.release_all()
	super.on_exit()


func _exit_tree() -> void:
	if life != null:
		life.dispose()
		life = null


## JS: HUB_TARGETS go into combat whenever the hub is entered. (Game clears the list after build().) He can be shot / punched: a hit target whose hits flinch him and play three recorded cries instead of the stock NPC "pain" sound; killing him plays his death and he topples over (he gets back up when the target respawns, like the clerk does).
func _targets_once() -> void:
	if _targets_in or Game.combat == null:
		return
	_targets_in = true
	if actors.has("cherub"):
		Game.combat.targets.append(Target.new(CHERUB_ID, -7.05, -20.5, 0.15, {"r": 0.45, "h": 2.0, "max": 220.0, "hp": 220.0, "npc": true, "w": 0.0}))
	if life != null:
		for T: Target in life.crowd.targets:
			T.hp = T.max
			T.dead = false
			Game.combat.targets.append(T)


## This frame's combat events (JS index.html frame(), the hub's lines: the cherub, the crowd).
func combat_events(events: Array) -> void:
	var cherub: HubNpcs.Cherub = actors.get("cherub")
	for e: Dictionary in events:
		var tid := int(e.get("tid", -1))
		var et := String(e.get("t", ""))
		if tid == CHERUB_ID and et == "respawn" and cherub != null:
			cherub.revive()
	if life != null:
		for e: Dictionary in events:
			life.crowd.on_event(e, Game.player)
	for e: Dictionary in events:
		var tid := int(e.get("tid", -1))
		var et := String(e.get("t", ""))
		if tid == CHERUB_ID and et == "kill" and cherub != null:      # the cherub dies: his death sound, and down he goes
			cherub.die()
			_cherub_at = Time.get_ticks_msec()
			Game.sfx.clip_at(load("res://assets/sfx/cherub-death.wav"), e.x, e.y, e.z, {"range": 45.0, "ref": 4.0, "wet": 0.12})
		elif tid == CHERUB_ID and et == "hit" and cherub != null:     # a hit: flinch + one of his three recorded cries (a short cooldown so a burst is one cry)
			cherub.hurt()
			var now := Time.get_ticks_msec()
			if now - _cherub_at > 650:
				_cherub_at = now
				var k := randi() % 3
				if k == _cherub_last:
					k = (k + 1 + randi() % 2) % 3
				_cherub_last = k
				Game.sfx.clip_at(load("res://assets/sfx/cherub-hurt-%d.wav" % (k + 1)), e.x, e.y, e.z, {"range": 40.0, "ref": 4.0, "wet": 0.1})
		elif e.get("npc", false) and tid != CHERUB_ID and (et == "hit" or et == "kill"):
			var now := Time.get_ticks_msec()
			if et == "kill" or now - _pain_at > 380:
				_pain_at = now
				Game.sfx.play("clerkDie" if et == "kill" else "pain")


func tick(_dt: float) -> void:
	_targets_once()
	if _clerk != null:
		var now := Time.get_ticks_msec() / 1000.0
		_clerk.update_at(now)
		_clerk_fx(now, Game.frame_real_dt)
	if life != null and life.office != null:      # JS frame(): the office key light, on the real clock
		life.office.key_light(Game.frame_real_dt, office_cine())
	var pb := Game.player
	if boss_intro != null and not boss_intro.on and not Game.story_get("bossIntro") and Game.char_pick == "prog" and pb.x > 116.0 and pb.x < 130.0 and absf(pb.z - 330.0) < 4.0 and absf(pb.y + 10.0) < 1.0:
		if not Game.menu_open() and not pb.dead and not Game.vehicles.driving and boss_intro.zone(pb):
			boss_intro.play()
	if _district == null:
		return
	var cam: Vector3 = Game.camera.global_position
	var in_hub := cam.z < -10.0 and cam.y < 6.0                 # the district is not drawn from the hub street
	if _district.visible == in_hub:
		_district.visible = not in_hub
	var far := cam.z > 230.0                                    # the hub block is a fog-grey memory from down there
	if far != _far:      # (JS: what was hidden comes back as it was, not all of it shown)
		_far = far
		if far:
			_street_was.clear()
			for c: Node in _street:
				_street_was.append((c as Node3D).visible)
				(c as Node3D).visible = false
		else:
			for i in mini(_street.size(), _street_was.size()):
				(_street[i] as Node3D).visible = _street_was[i]
	for o: Node3D in _hub_sky:                                  # the hub's 300 m sky sphere: the smog dome replaces it out here, and it would wash out the DYOSPHERE behind it. Every frame, as in the JS: coming back from down town shows the street again, sphere and all
		o.visible = in_hub
	if not in_hub:
		_dyosphere(Game.time, cam)
	# the sky drifts, and the haze follows it: everything already fading into it comes along
	var k := sky_mix(Game.time)
	if absf(k - _sky_k) > 0.0005 and _sky_mat != null:
		_sky_k = k
		_sky_mat.set_shader_parameter(&"uHor", (VIOLET.horizon as Vector3).lerp(EMBER.horizon, k))
		_sky_mat.set_shader_parameter(&"uBand", (VIOLET.band as Vector3).lerp(EMBER.band, k))
		_sky_mat.set_shader_parameter(&"uZen", (VIOLET.zenith as Vector3).lerp(EMBER.zenith, k))
		_sky_mat.set_shader_parameter(&"uMoonCol", (VIOLET.moon as Vector3).lerp(EMBER.moon, k))
		_sky_mat.set_shader_parameter(&"uHalo", (VIOLET.halo as Vector3).lerp(EMBER.halo, k))
		_sky_mat.set_shader_parameter(&"uMoonR", lerpf(VIOLET.moon_r, EMBER.moon_r, k))
		_sky_mat.set_shader_parameter(&"uCloud", lerpf(VIOLET.cloud, EMBER.cloud, k))
		_fog_k = -1.0
	# down town the haze is the city's smog
	var fk := smoothstep(66.0, 130.0, cam.z)
	if absf(fk - _fog_k) > 0.001 or _fog_k < 0.0:
		_fog_k = fk
		var smog: Color = (VIOLET.fog as Color).lerp(EMBER.fog, k)      # (JS mixes the arrays, then reads them as sRGB)
		var sl := smog.srgb_to_linear()
		RenderingServer.global_shader_parameter_set(&"prog_smog", Vector3(sl.r, sl.g, sl.b))
		Game.view.set_fog_exp2(_fog_hub.lerp(smog.srgb_to_linear(), fk).linear_to_srgb(), lerpf(0.0145, 0.0034, fk))
