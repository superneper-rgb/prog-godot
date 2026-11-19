class_name PalaceLevel
extends Level
## THE FOINT PERVERT PALACE (user, 2026-11-19): Sambo Fenrir's stream. FOINT's tower going up on its own lot in the bay off FOINT CITY's east quay (levels/palace/palace_site.gd; the city round
## it, palace_city.gd). The level is the mission, as the user wrote it:
##   gate     it opens with the site's arrival shot (palace_cines.gd: the second half of the cutscene that stands in for the loading screen) and the talk with the foreman at the gate (his own
##            babble; Prog's and Sambo's lines recorded). He says no. Sambo says "watch this" and runs past him; the stream's chat comes up on the side of the screen (ui/stream_chat.gd:
##            WeFoint) and the crew come at both of them (FOINT goons in site gear: enemies/foint_goon*.gd "crew", "crew_hod", "foreman"); the foreman runs for the air horn on his hut.
##   scaffold up the west scaffold's lifts after Sambo (palace_sambo.gd runs his route and takes the crew's shots at him); steel: floor 3's beam and the swing over its gap; bundle: crane B's
##            beam bundle up to floor 6 (palace_ride.gd); slab: the fight on floor 6, the second foreman's horn calls more up the hoist; hoist: the cage to the top, shot at from the
##            north scaffold; top: the top slab's last crew, into crane A's man-basket; crane: the basket goes up to the jib and the finale plays (palace_finale.gd: the hanging seen through
##            the stream camera, the suit snapping at the neck, the fit, the red button, Earth and his parents' yacht, the drop pod, the head on robot legs climbing into the mech).
##   boss     the mech (sambo_mech.gd) on the top slab, the chat on Prog's side now; end: palace_ending.gd (the little alien, his begging, Prog walking away), then back to the street.
## Checkpoints are the stages (the console's `cp`, F6). Falling off the climb puts you back at the stage's start.

const SPAWN_GATE := {"x": 129.2, "y": -9.95, "z": 201.0, "yaw": PI / 2.0}      # on the quay at the gate, facing the lot
const Y0 := PalaceSite.Y0
const NF_ := PalaceSite.NF
const FOREMAN_AT := Vector3(135.6, Y0, 201.2)
const HORN_AT := Vector2(134.5, 207.4)      # the air horn on the gate hut's wall
const HORN2_AT := Vector2(156.0, 216.6)     # floor 6's, by the hoist
const DONE := "samboDone"
const MET := "samboMet"

## The look: the city's (core/looks.gd "hub"), the haze over the bay a touch thicker
var look := {"ao": 0.85, "ao_radius": 1.3, "ao_fade": 55.0, "mist": 0.006, "mist_falloff": 0.06, "mist_y": -10.0, "mist_gain": 1.3, "mist_glow": [0.07, 0.05, 0.1], "mist_glow_pow": 5.0,
	"bloom": 0.45, "bloom_threshold": 0.7, "bloom_knee": 0.22, "streak": 0.12, "streak_cut": 0.42, "saturation": 1.05, "vibrance": 0.25, "scurve": 0.1, "shadow_tint": [0.95, 0.97, 1.08],
	"high_tint": [1.03, 1.0, 0.96], "vignette": 0.32, "vignette_tint": [0.01, 0.0, 0.05], "grain": 0.024}
var site: PalaceSite
var city: PalaceCity
var bo: Blockout
var sambo: PalaceSambo
var chat: StreamChat
var bundle: PalaceRide
var hoist: PalaceRide
var basket: PalaceRide
var cines: PalaceCines
var finale: PalaceFinale
var mech: SamboMech
var ending: PalaceEnding
var stream_cam: StreamCam = null
var foreman: FointGoon = null
var gate_crew: Array[Robot] = []
var talker: Dictionary = {}
var flags := {}
var _t := 0.0
var _stage := ""
var _horn_done := false
var _horn2_done := false
var _horn_snd: AudioStreamPlayer3D = null
var _fall_y := -100.0
var _fall_t := 0.0
var _kills := 0
var _last_dead := 0
var _rng := RandomNumberGenerator.new()

## The level's cutscene while one runs (core/view.gd, Game._process): the arrival, the finale, the ending
var cine: Variant:
	get:
		for c: Variant in [cines, finale, ending]:
			if c != null and c.on:
				return c
		return null


func build() -> void:
	_rng.seed = 6
	city = PalaceCity.new()
	city.build(self, world)
	site = PalaceSite.new()
	site.build(self, world, true)
	site.set_gate(1.0)
	for l: Light3D in site.floods:
		city.add_water_light(l.global_position, 0.0)
	for bc: Node3D in site.beacons:
		city.add_water_light(bc.global_position, 1.0)
	_work_lights()
	_render_state()
	world.spawn = SPAWN_GATE.duplicate()
	world.target_spots = []            # no shooting-range dummies or clerk here (Combat._build_range); ammo pods at the foot of the climb, on floor 3, floor 6 and the top
	world.pickup_spots = [[139.0, 213.0], [150.5, 199.0, PalaceSite.ly(3)], [168.0, 205.0, PalaceSite.ly(6)], [150.0, 205.0, PalaceSite.ly(NF_)]]
	world.clerk_spot = [0.0, -400.0]
	world.fall_reset_y = -14.0
	world.projectile_floor_y = -10.6
	Config.pole_swing = 1              # (floor 3's swing; Config is put back when the level is left)
	city_ambience = true
	storm = false
	portals.append({"id": "palace_out", "label": "BACK TO THE STREET", "x": 128.4, "z": 201.0, "radius": 1.3, "to": "hub", "spawn_at": "palace", "loading": "FOINT CITY",
		"active": func() -> bool: return _stage == "gate" and not flags.get("ran", false) and not cines.on})
	# the rides: crane B's beam bundle, the hoist cage, crane A's man-basket (floors and walls that carry whoever is on them)
	var pb: Array = PalaceSite.PALLET
	bundle = PalaceRide.new(site.pallet, world, Vector3((pb[0] + pb[1]) * 0.5, PalaceSite.PALLET_LO, (pb[2] + pb[3]) * 0.5), Vector2((pb[1] - pb[0]) * 0.5, (pb[3] - pb[2]) * 0.5))
	var hb: Array = PalaceSite.HOIST
	var hw: float = (hb[1] - hb[0]) * 0.5
	var hd: float = (hb[3] - hb[2]) * 0.5
	hoist = PalaceRide.new(site.hoist_cage, world, Vector3((hb[0] + hb[1]) * 0.5, PalaceSite.ly(6), (hb[2] + hb[3]) * 0.5), Vector2(hw, hd))
	hoist.wall(-hw, 0.0, 0.06, hd, 2.4)
	hoist.wall(hw, 0.0, 0.06, hd, 2.4)
	hoist.wall(0.0, hd, hw, 0.06, 2.4)
	hoist.wall(0.0, -hd, hw, 0.06, 2.4, true)      # its door: open at a landing
	hoist.set_gate(true)
	var kb: Array = PalaceSite.BASKET
	var bw: float = (kb[1] - kb[0]) * 0.5
	var bd: float = (kb[3] - kb[2]) * 0.5
	basket = PalaceRide.new(site.basket, world, Vector3((kb[0] + kb[1]) * 0.5, PalaceSite.ly(NF_), (kb[2] + kb[3]) * 0.5), Vector2(bw, bd))
	basket.wall(bw, 0.0, 0.05, bd, 1.1)
	basket.wall(0.0, bd, bw, 0.05, 1.1)
	basket.wall(0.0, -bd, bw, 0.05, 1.1)
	basket.wall(-bw, 0.0, 0.05, bd, 1.1, true)      # its gate, toward the slab
	basket.set_gate(true)
	sambo = PalaceSambo.new()
	add_child(sambo)
	sambo.place(Vector3(133.4, Y0, 202.4), PI / 2.0)
	chat = StreamChat.new()
	add_child(chat)
	cines = PalaceCines.new()
	add_child(cines)
	cines.setup(self)
	finale = PalaceFinale.new()
	add_child(finale)
	finale.setup(self)
	mech = SamboMech.new()
	add_child(mech)
	mech.setup(self)
	ending = PalaceEnding.new()
	add_child(ending)
	ending.setup(self)
	_air_horn()
	_stages()


# ---------------------------------------------------------------------------------------------- look

func _render_state() -> void:
	# the city's own night (assets/levels/hub/level.json): its hemisphere, its moon, ACES at 1.5; the bay's haze the sky's own horizon so the far water meets it
	var haze := Color(0.15, 0.055, 0.15)
	Game.view.apply_render_state({"background": haze, "tone_mapping": View.TONE_ACES, "exposure": 1.5, "fog": [haze, 0.0017],
		"hemi": [Color(0.04231, 0.08866, 0.18782).linear_to_srgb(), Color(0.012, 0.01, 0.018).linear_to_srgb(), 2.2],
		"sun": [Color(0.14413, 0.2462, 0.47932).linear_to_srgb(), 0.62], "sun_cast": true, "sun_lean": true, "clip": [0.1, 2200.0]})


## Back to the site's own night after the space shot (palace_finale.gd)
func restore_render_state() -> void:
	_render_state()


## The site's own work lights along the climb (the festoon strings and the floods are the look; these are what the climb is lit by): cold blue-white, shadowless, short
func _work_lights() -> void:
	for q: Array in [
			[Vector3(138.0, Y0 + 3.2, 201.0), 1.6, 14.0],      # the gate yard
			[Vector3(146.0, PalaceSite.ly(1) + 2.2, 190.0), 1.3, 10.0], [Vector3(146.0, PalaceSite.ly(1) + 2.2, 210.0), 1.3, 10.0],      # the scaffold's lifts
			[Vector3(146.0, PalaceSite.ly(2) + 2.2, 200.0), 1.3, 11.0], [Vector3(146.0, PalaceSite.ly(3) + 2.2, 192.0), 1.3, 10.0],
			[Vector3(156.0, PalaceSite.ly(3) + 2.4, 196.0), 1.4, 12.0], [Vector3(169.0, PalaceSite.ly(3) + 2.6, 190.8), 1.6, 12.0],     # floor 3: the deck, the beam and the swing
			[Vector3(175.0, PalaceSite.ly(3) + 2.4, 186.0), 1.4, 10.0], [Vector3(175.0, PalaceSite.ly(5), 182.0), 1.5, 14.0],          # the beam bundle's ride
			[Vector3(152.0, PalaceSite.ly(6) + 2.6, 192.0), 1.6, 14.0], [Vector3(172.0, PalaceSite.ly(6) + 2.6, 192.0), 1.6, 14.0], [Vector3(152.0, PalaceSite.ly(6) + 2.6, 212.0), 1.6, 14.0], [Vector3(172.0, PalaceSite.ly(6) + 2.6, 212.0), 1.6, 14.0],
			[Vector3(161.5, PalaceSite.ly(8), 220.0), 1.5, 14.0],     # the hoist
			[Vector3(152.0, PalaceSite.ly(10) + 2.6, 192.0), 1.6, 15.0], [Vector3(172.0, PalaceSite.ly(10) + 2.6, 192.0), 1.6, 15.0], [Vector3(152.0, PalaceSite.ly(10) + 2.6, 212.0), 1.6, 15.0], [Vector3(172.0, PalaceSite.ly(10) + 2.6, 212.0), 1.6, 15.0],
		]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.8, 0.9, 1.0)
		l.light_energy = q[1]
		l.omni_range = q[2]
		l.omni_attenuation = 1.2
		l.shadow_enabled = false
		l.light_specular = 0.5
		l.distance_fade_enabled = true
		l.distance_fade_begin = 70.0
		l.distance_fade_length = 20.0
		l.position = q[0]
		add_child(l)


## The site's air horn: a blast that carries over the bay (a rendered tone: two detuned saws, a long swell)
func _air_horn() -> void:
	_horn_snd = AudioStreamPlayer3D.new()
	_horn_snd.stream = Cutscene.synth(2.6, [[0.0, 2.4, 233.0, 228.0, &"sawtooth", 0.22, 0.04], [0.0, 2.4, 293.0, 288.0, &"sawtooth", 0.18, 0.04], [0.0, 2.4, 349.0, 344.0, &"square", 0.06, 0.05]], [])
	_horn_snd.bus = &"SFX"
	_horn_snd.unit_size = 30.0
	_horn_snd.max_distance = 220.0
	add_child(_horn_snd)


func _blow_horn(at: Vector2, y: float) -> void:
	_horn_snd.global_position = Vector3(at.x, y + 2.4, at.y)
	_horn_snd.play()
	Game.fx.shake = maxf(Game.fx.shake, 0.08)


# ---------------------------------------------------------------------------------------------- the mission

func _stages() -> void:
	bo = Blockout.new(self, {"id": id, "name": "PERVERT PALACE", "spawn": SPAWN_GATE, "on_enter_stage": _stage_entered, "complete_text": "STREAM ENDED."})
	bo.stage({"id": "gate", "name": "The gate", "spawn": SPAWN_GATE, "objectives": [
		{"id": "talk", "label": "The foreman", "text": "Get Sambo past the crew at the gate.", "kind": "custom", "guide": false,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _gate_start(e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return flags.get("ran", false)},
	]})
	bo.stage({"id": "scaffold", "name": "The scaffold", "spawn": {"x": 139.5, "y": Y0 + 0.05, "z": 191.0, "yaw": 2.6}, "objectives": [
		{"id": "climb", "label": "The scaffold", "text": "Follow Sambo up the scaffold. Keep him in frame.", "kind": "custom", "at": [146.0, PalaceSite.ly(3), 196.0],
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _scaffold_start(e.get("retry", false)),
			"done": func(_k: Blockout, p: Player, _c: Combat) -> bool: return p.y > PalaceSite.ly(3) - 0.6 and p.x > PalaceSite.SX1 - 0.4},
	]})
	bo.stage({"id": "steel", "name": "The steel", "spawn": {"x": 151.0, "y": PalaceSite.ly(3) + 0.05, "z": 194.0, "yaw": PI / 2.0}, "objectives": [
		{"id": "beam", "label": "The steel", "text": "Cross the steel to the beam bundle.", "kind": "custom", "at": [175.0, PalaceSite.ly(3), 182.1],
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _steel_start(e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return bundle.player_on()},
	]})
	bo.stage({"id": "bundle", "name": "The bundle", "spawn": {"x": 175.6, "y": PalaceSite.ly(3) + 0.05, "z": 182.1, "yaw": 0.0}, "objectives": [
		{"id": "ride", "label": "The bundle", "text": "Ride the beam bundle up.", "kind": "custom", "guide": false,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _bundle_start(e.get("retry", false)),
			"done": func(_k: Blockout, p: Player, _c: Combat) -> bool: return flags.get("bundle_up", false) and p.y > PalaceSite.ly(6) - 0.6 and p.z > 183.6},
	]})
	bo.stage({"id": "slab", "name": "Floor six", "spawn": {"x": 175.0, "y": PalaceSite.ly(6) + 0.05, "z": 186.5, "yaw": 0.0}, "objectives": [
		{"id": "fight", "label": "Floor six", "text": "The crew have you on floor six. Hold them off.", "kind": "custom", "guide": false,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _slab_start(e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return _slab_clear()},
	]})
	bo.stage({"id": "hoist", "name": "The hoist", "spawn": {"x": 161.5, "y": PalaceSite.ly(6) + 0.05, "z": 214.5, "yaw": 0.0}, "objectives": [
		{"id": "lift", "label": "The hoist", "text": "Get in the hoist with Sambo.", "kind": "custom", "at": [161.5, PalaceSite.ly(6), 220.3],
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _hoist_start(e.get("retry", false)),
			"done": func(_k: Blockout, p: Player, _c: Combat) -> bool: return flags.get("hoist_up", false) and p.y > PalaceSite.ly(NF_) - 0.6 and p.z < 218.4},
	]})
	bo.stage({"id": "top", "name": "The top", "spawn": {"x": 161.5, "y": PalaceSite.ly(NF_) + 0.05, "z": 214.5, "yaw": PI}, "objectives": [
		{"id": "basket", "label": "The crane", "text": "Get into the crane's man-basket.", "kind": "custom", "at": [180.05, PalaceSite.ly(NF_), 201.0],
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _top_start(e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return basket.player_on() and _top_clear()},
	]})
	bo.stage({"id": "crane", "name": "The crane", "spawn": {"x": 179.6, "y": PalaceSite.ly(NF_) + 0.05, "z": 200.4, "yaw": -PI / 2.0}, "objectives": [
		{"id": "up", "label": "The jib", "text": "", "kind": "custom", "guide": false,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _crane_start(e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return flags.get("finale_done", false)},
	]})
	bo.stage({"id": "boss", "name": "Sambo 2.0", "spawn": {"x": 163.0, "y": PalaceSite.ly(NF_) + 0.05, "z": 187.5, "yaw": 0.0}, "objectives": [
		{"id": "mech", "label": "Sambo 2.0", "text": "Take the mech apart. Hit the core when the doors open.", "kind": "custom", "guide": false,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _boss_start(e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return mech.destroyed},
	]})
	bo.stage({"id": "end", "name": "Off air", "spawn": {"x": 163.0, "y": PalaceSite.ly(NF_) + 0.05, "z": 200.0, "yaw": 0.0}, "objectives": [
		{"id": "spare", "label": "Sambo", "text": "", "kind": "custom", "guide": false,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: _end_start(e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return flags.get("ended", false)},
	]})
	bo.build_checkpoints()


func _stage_entered(_b: Blockout, e: Dictionary) -> void:
	_stage = String(e.stage)
	var floors := {"gate": Y0, "scaffold": Y0, "steel": PalaceSite.ly(3), "bundle": PalaceSite.ly(3), "slab": PalaceSite.ly(6), "hoist": PalaceSite.ly(6), "top": PalaceSite.ly(NF_),
		"crane": PalaceSite.ly(NF_), "boss": PalaceSite.ly(NF_), "end": PalaceSite.ly(NF_)}
	_fall_y = float(floors.get(_stage, Y0)) - 5.0
	if _stage in ["scaffold", "steel", "bundle", "slab", "hoist", "top", "crane"]:
		chat.show_chat(true)
		if chat.mood != &"hype":
			chat.set_mood(&"hype", 3.2)
	if stream_cam == null and Game.animator != null:
		stream_cam = StreamCam.wear(Game.animator)


func apply_spawn(_at: String) -> void:
	world.spawn = SPAWN_GATE.duplicate()


func on_enter() -> void:
	bo.on_level_entered()
	if Game.animator != null and stream_cam == null:
		stream_cam = StreamCam.wear(Game.animator)


func on_exit() -> void:
	bo.dispose()
	if not talker.is_empty():
		Game.dialogue.talkers.erase(talker)
	if stream_cam != null:
		stream_cam.remove()
		stream_cam = null


## the console's `cp`, and CONTINUE
var checkpoints: Array:
	get:
		return bo.checkpoints if bo != null else []


func load_checkpoint(which: Variant) -> bool:
	return bo.load_cp(which)


# ---------------------------------------------------------------------------------------------- gate

func _gate_start(retry: bool) -> void:
	flags.erase("ran")
	_clear_gate_crew()
	sambo.held = false
	sambo.legs.clear()
	sambo.leg = -1
	sambo.place(Vector3(133.4, Y0, 202.4), PI / 2.0)
	sambo.body.selfie = 1.0
	chat.show_chat(false)
	# the foreman by the gate, two of his crew by the drum fire and the hut: on their break until Sambo runs (they do not see you yet)
	foreman = Game.spawn_enemy({"x": FOREMAN_AT.x, "y": Y0, "z": FOREMAN_AT.z, "yaw": -PI / 2.0}, {"kind": "goon", "costume": "foreman", "no_respawn": true, "alarm": [HORN_AT.x, HORN_AT.y]}) as FointGoon
	gate_crew.append(foreman)
	gate_crew.append(Game.spawn_enemy({"x": 138.4, "y": Y0, "z": 204.8, "yaw": -1.0}, {"kind": "goon", "costume": "crew", "gun": "pistol", "no_respawn": true}))
	for r: Robot in gate_crew:
		r.dev_passive = true
		if r is FointGoon:
			(r as FointGoon).on_break = true
	_add_talker()
	if not retry:
		cines.arrive()      # the arrival shot; the talk starts when it ends
	else:
		Game.player.x = 133.0
		Game.player.z = 200.2
		_start_talk()


func _clear_gate_crew() -> void:
	for r: Robot in gate_crew:
		if r != null and Game.enemies.robots.has(r):
			Game.despawn_enemy(r)
	gate_crew.clear()


func _add_talker() -> void:
	if not talker.is_empty():
		Game.dialogue.talkers.erase(talker)
	var me := Dialogue.player_name()
	var lines: Array = [
		{"text": "Whoa, whoa. Site's closed. Hard hats only."},
		{"text": SamboLines.text("p_site_01"), "who": me, "clip": SamboLines.DIR + "p_site_01.wav"},
		{"text": "Up the crane. Sure. You and the guy in the... what is that? A skin suit?"},
		{"text": SamboLines.text("s_site_01"), "who": "SAMBO", "clip": SamboLines.DIR + "s_site_01.wav", "sambo": true},
		{"text": "No cameras, no civilians, no rubber guys. Union rule. Turn around."},
		{"text": SamboLines.text("p_site_02"), "who": me, "clip": SamboLines.DIR + "p_site_02.wav"},
		{"text": SamboLines.text("s_site_02"), "who": "SAMBO", "clip": SamboLines.DIR + "s_site_02.wav", "sambo": true},
	]
	talker = Game.dialogue.add_talker({"id": "palace_foreman", "name": "THE FOREMAN", "x": FOREMAN_AT.x, "y": Y0, "z": FOREMAN_AT.z, "yaw": -PI / 2.0, "radius": 2.6,
		"color": "#ffd23c", "voice_pitch": 0.55, "type_rate": 30.0, "lines": lines, "actor": self,
		"active": func() -> bool: return _stage == "gate" and not flags.get("ran", false) and not cines.on,
		"shot": {"cam_dist": 3.6, "cam_y": 1.25, "look_y": 0.9, "look_side": 0.6, "spot_fwd": 1.6, "spot_side": 0.75},
		"on_end": func(_d: Dictionary) -> void: _sambo_runs()})


## Dialogue actor (the talk is the foreman's; Sambo stands by): Sambo looks at whoever talks, his lid flaps on his own lines
func look_at_point(x: float, z: float) -> void:
	sambo.body.look_at_point(x, z)


func look_away() -> void:
	sambo.body.look_away()


func set_talk(_v: bool) -> void:
	pass


func on_line(L: Dictionary) -> void:
	sambo.body.talking = L.get("sambo", false)
	if L.get("sambo", false):
		sambo.body.look_on = false
	else:
		sambo.body.look_at_point(FOREMAN_AT.x, FOREMAN_AT.z)


func mouth_world() -> Vector3:
	return FOREMAN_AT + Vector3(0.0, 1.45, 0.0)


func _start_talk() -> void:
	if not talker.is_empty() and not Game.dialogue.on:
		Game.dialogue.start(talker)


## The talk is over: Sambo runs past the foreman and up the site; the stream's chat comes up; the crew come for both of you; the foreman runs for his horn
func _sambo_runs() -> void:
	if flags.get("ran", false):
		return
	flags["ran"] = true
	sambo.body.talking = false
	sambo.go([{"to": Vector3(136.6, Y0, 199.6)}, {"to": Vector3(140.0, Y0, 193.0)}, {"to": Vector3(143.0, Y0, 185.4)}])
	for r: Robot in gate_crew:      # (the foreman goes for his horn at once; his crewman turns on Prog a beat later, once Sambo is past him)
		if r == null or r.dead:
			continue
		var wake := func() -> void:
			if r.dead or not Game.enemies.robots.has(r):
				return
			r.dev_passive = false
			if r is FointGoon:
				(r as FointGoon).on_break = false
			r._know(Game.player.x, Game.player.z)
			r.seen_t = 0.0
			r.set_(&"alert")
		if r == foreman:
			wake.call()
		else:
			get_tree().create_timer(1.6, false).timeout.connect(wake)
	if foreman != null:
		Game.hud.subtitle({"name": "THE FOREMAN", "text": "HEY! GET OFF MY SCAFFOLD!", "dur": 1.8})
	chat.show_chat(true)
	chat.set_mood(&"start", 4.0)
	get_tree().create_timer(3.5, false).timeout.connect(func() -> void:
		if chat.mood == &"start":
			chat.set_mood(&"hype", 3.2)
			chat.add_viewers(2400.0))


# ---------------------------------------------------------------------------------------------- the climb

## [x, y, z, yaw, costume, gun]: crew straight into the fight (Blockout's spawn: they know where you are)
func _spawn(list: Array) -> void:
	for q: Array in list:
		var o := {"kind": "goon", "costume": q[4]}
		if q.size() > 5:
			o["gun"] = q[5]
		bo.spawn({"x": q[0], "y": q[1], "z": q[2], "yaw": q[3]}, o)


func _scaffold_start(retry: bool) -> void:
	var y1 := PalaceSite.ly(1)
	var y2 := PalaceSite.ly(2)
	var y3 := PalaceSite.ly(3)
	if retry:
		bo.clear_enemies()
		_clear_gate_crew()
		sambo.place(Vector3(143.0, Y0, 185.4), 0.0)
	_spawn([[146.4, y1, 207.0, PI, "crew", "pistol"], [146.6, y1, 213.0, PI, "crew", "smg"], [146.6, y2, 201.0, 0.0, "crew_hod"], [146.8, y3, 206.0, PI, "crew", "pistol"]])
	var mid := PalaceSite.SX0 + 0.72
	var inn := PalaceSite.SX1 - 0.9
	sambo.go([
		{"to": Vector3(143.0, Y0, 185.4), "say": "s_climb_01"},
		{"to": Vector3(143.0, y1, 193.0)}, {"to": Vector3(143.0, y1, 194.0)}, {"to": Vector3(inn, y1, 194.2)},
		{"to": Vector3(inn, y1, 199.3)}, {"to": Vector3(inn, y1, 202.3), "hop": true}, {"to": Vector3(inn, y1, 214.6), "wait": 7.0, "say": "s_climb_04"},
		{"to": Vector3(mid, y1, 217.6)}, {"to": Vector3(mid, y2, 207.4)}, {"to": Vector3(inn, y2, 206.4)},
		{"to": Vector3(inn, y2, 196.4), "say": "s_climb_02"}, {"to": Vector3(inn, y2, 193.8), "hop": true}, {"to": Vector3(inn, y2, 187.4), "wait": 7.0},
		{"to": Vector3(mid, y2, 185.4)}, {"to": Vector3(mid, y3, 195.2)}, {"to": Vector3(inn, y3, 196.2)}, {"to": Vector3(150.5, y3, 196.2), "say": "s_climb_11"},
		{"to": Vector3(159.4, y3, 191.0), "wait": 6.0},
	])


func _steel_start(retry: bool) -> void:
	var y3 := PalaceSite.ly(3)
	if retry:
		bo.clear_enemies()
		sambo.place(Vector3(159.4, y3, 191.0), PI / 2.0)
		_reset_rides()
	_spawn([[151.5, y3, 206.0, PI, "crew", "smg"], [156.5, y3, 213.0, PI, "crew", "pistol"], [175.0, PalaceSite.ly(4), 187.5, -PI / 2.0, "crew_hod"]])
	sambo.go([
		{"to": Vector3(159.6, y3 - 0.1, PalaceSite.BEAM_Z)}, {"to": Vector3(165.7, y3 - 0.1, PalaceSite.BEAM_Z), "say": "s_climb_08"},
		{"to": Vector3(172.4, y3 - 0.1, PalaceSite.BEAM_Z), "hop": true}, {"to": Vector3(176.5, y3 - 0.1, PalaceSite.BEAM_Z)},
		{"to": Vector3(175.0, y3, 186.6)}, {"to": Vector3(174.2, y3, 182.1), "wait": 3.0},
	])


func _bundle_start(retry: bool) -> void:
	flags.erase("bundle_up")
	flags["bundle_t"] = -1.0
	if retry:
		bo.clear_enemies()
		_reset_rides()
		sambo.legs.clear()
		sambo.leg = -1
		sambo.place(Vector3(174.2, PalaceSite.PALLET_LO, 182.1), 0.0)
	_spawn([[176.0, PalaceSite.ly(5), 187.5, PI, "crew", "pistol"], [152.0, PalaceSite.ly(6), 188.0, PI / 2.0, "crew_hod"], [172.0, PalaceSite.ly(4), 189.5, PI, "crew", "smg"]])


func _slab_start(retry: bool) -> void:
	var y6 := PalaceSite.ly(6)
	_horn2_done = false
	if retry:
		bo.clear_enemies()
		_reset_rides()
		bundle.move_to(Vector3(bundle.pos.x, PalaceSite.PALLET_HI, bundle.pos.z))
		flags["bundle_up"] = true
		sambo.place(Vector3(175.0, y6, 186.0), 0.0)
	_spawn([[156.0, y6, 205.0, PI, "crew", "smg"], [168.0, y6, 209.0, PI, "crew", "pistol"], [150.0, y6, 193.0, PI / 2.0, "crew_hod"], [164.0, y6, 214.0, PI, "crew", "pistol"]])
	bo.spawn({"x": 158.0, "y": y6, "z": 213.0, "yaw": PI}, {"kind": "goon", "costume": "foreman", "alarm": [HORN2_AT.x, HORN2_AT.y]})
	sambo.go([{"to": Vector3(175.0, y6, 186.0)}, {"to": Vector3(173.8, y6, 205.0), "say": "s_climb_10"}, {"to": Vector3(174.6, y6, 217.4)}])


func _slab_clear() -> bool:
	if not _horn2_done:
		return false
	for r: Robot in bo.spawned:
		if not r.dead and not r.gone:
			return false
	return true


func _hoist_start(retry: bool) -> void:
	flags.erase("hoist_up")
	flags["hoist_t"] = -1.0
	var y6 := PalaceSite.ly(6)
	if retry:
		bo.clear_enemies()
		_reset_rides()
		bundle.move_to(Vector3(bundle.pos.x, PalaceSite.PALLET_HI, bundle.pos.z))
		sambo.place(Vector3(174.6, y6, 217.4), PI)
	_spawn([[154.2, PalaceSite.ly(7), 219.8, PI / 2.0, "crew", "pistol"], [169.0, PalaceSite.ly(8), 219.8, -PI / 2.0, "crew", "smg"], [154.2, PalaceSite.ly(9), 219.8, PI / 2.0, "crew_hod"], [169.0, PalaceSite.ly(9), 219.8, -PI / 2.0, "crew", "pistol"]])
	sambo.go([{"to": Vector3(170.0, y6, 216.0)}, {"to": Vector3(161.5, y6, 216.6)}, {"to": Vector3(161.0, y6, 220.4), "wait": 2.2, "say": "s_climb_09"}])


func _top_start(retry: bool) -> void:
	var yt := PalaceSite.ly(NF_)
	if retry:
		bo.clear_enemies()
		_reset_rides()
		hoist.move_to(Vector3(hoist.pos.x, yt, hoist.pos.z))
		sambo.place(Vector3(161.5, yt, 216.0), PI)
	_spawn([[152.0, yt, 190.0, 0.0, "crew", "smg"], [170.0, yt, 194.0, 0.0, "crew", "pistol"], [155.0, yt, 212.0, PI, "crew", "pistol"], [172.0, yt, 211.0, PI, "crew_hod"]])
	sambo.go([{"to": Vector3(161.5, yt, 215.6)}, {"to": Vector3(172.0, yt, 213.0)}, {"to": Vector3(177.0, yt, 201.0)}, {"to": Vector3(180.4, yt, 201.8), "wait": 1.6, "say": "s_climb_04"}])


func _top_clear() -> bool:
	for r: Robot in bo.spawned:
		if not r.dead and not r.gone and Vector2(r.x - 180.0, r.z - 201.0).length() < 26.0:
			return false
	return true


func _crane_start(retry: bool) -> void:
	flags.erase("finale_done")
	flags.erase("finale_started")
	flags["basket_t"] = 0.0
	bo.clear_enemies()
	if retry:
		_reset_rides()
		sambo.place(Vector3(180.4, PalaceSite.ly(NF_), 201.8), -PI / 2.0)
	basket.set_gate(false)
	sambo.legs.clear()
	sambo.leg = -1


func _boss_start(retry: bool) -> void:
	bo.clear_enemies()
	chat.show_chat(true)
	chat.set_mood(&"boss", 3.6)
	mech.begin(retry)


func _end_start(_retry: bool) -> void:
	flags.erase("ended")
	ending.start()


## Put the rides back where the climb finds them
func _reset_rides() -> void:
	bundle.tilt = Vector2.ZERO
	basket.tilt = Vector2.ZERO
	bundle.move_to(Vector3(bundle.pos.x, PalaceSite.PALLET_LO, bundle.pos.z))
	hoist.move_to(Vector3(hoist.pos.x, PalaceSite.ly(6), hoist.pos.z))
	hoist.set_gate(true)
	basket.move_to(Vector3(basket.pos.x, PalaceSite.ly(NF_), basket.pos.z))
	basket.set_gate(true)


# ---------------------------------------------------------------------------------------------- the frame

func tick(dt: float) -> void:
	_t += dt
	var P := Game.player
	bo.update(dt, P, Game.combat)
	for i in site.beacons.size():      # the red lamps blink, out of step
		site.beacons[i].visible = fmod(_t * 0.8 + i * 0.37, 1.6) < 1.1
	if dt <= 0.0:
		return
	cines.update(dt)
	finale.update(dt)
	ending.update(dt)
	_rides(dt)
	sambo.crew_shots(dt, _stage in ["scaffold", "steel", "bundle", "slab", "hoist", "top"])
	if not ((finale != null and finale.on) or (ending != null and ending.on) or (cines != null and cines.on)):
		sambo.tick(dt, P)
	_horns()
	_falls(dt, P)
	_chat_events()
	if mech != null:
		mech.tick(dt)
	_cables()


## The rides' motion: the bundle goes up with you on it; the hoist when you are both in; the basket when you are in it
func _rides(dt: float) -> void:
	var P := Game.player
	if _stage == "bundle":
		var bt: float = flags.get("bundle_t", -1.0)
		if bt < 0.0 and bundle.player_on() and bundle.on(sambo.pos.x, sambo.pos.y, sambo.pos.z):
			bt = 0.0
			Game.fx.shake = maxf(Game.fx.shake, 0.12)
			sambo.say_one(["s_climb_08", "s_climb_02"])
		if bt >= 0.0:
			bt += dt
			var u := Cutscene.ease_(bt / 9.0)
			bundle.tilt = Vector2(sin(bt * 1.3) * 0.03, sin(bt * 0.9 + 1.0) * 0.04) * (1.0 - u * 0.6)
			bundle.move_to(Vector3(bundle.pos.x, lerpf(PalaceSite.PALLET_LO, PalaceSite.PALLET_HI, u), bundle.pos.z), sambo)
			if bt >= 9.0 and not flags.get("bundle_up", false):
				flags["bundle_up"] = true
				bundle.tilt = Vector2.ZERO
				sambo.go([{"to": Vector3(175.0, PalaceSite.ly(6), 186.0)}])
			flags["bundle_t"] = bt
	elif _stage == "hoist":
		var ht: float = flags.get("hoist_t", -1.0)
		if ht < 0.0 and hoist.player_on() and sambo.waiting and hoist.on(sambo.pos.x, sambo.pos.y, sambo.pos.z):
			ht = 0.0
			hoist.set_gate(false)
		if ht >= 0.0:
			ht += dt
			var u := Cutscene.ease_(ht / 10.0)
			hoist.move_to(Vector3(hoist.pos.x, lerpf(PalaceSite.ly(6), PalaceSite.ly(NF_), u), hoist.pos.z), sambo)
			if ht >= 10.0 and not flags.get("hoist_up", false):
				flags["hoist_up"] = true
				hoist.set_gate(true)
				sambo.go([{"to": Vector3(161.5, PalaceSite.ly(NF_), 216.0)}])
			flags["hoist_t"] = ht
	elif _stage == "crane" and not flags.get("finale_started", false):
		var kt: float = float(flags.get("basket_t", 0.0)) + dt
		flags["basket_t"] = kt
		var u := Cutscene.ease_((kt - 0.6) / 7.0)
		basket.tilt = Vector2(sin(kt * 1.1) * 0.025, sin(kt * 0.8) * 0.03)
		basket.move_to(Vector3(basket.pos.x, lerpf(PalaceSite.ly(NF_), PalaceFinale.TOP_Y, u), basket.pos.z), sambo)
		if P != null and not basket.player_on():      # (held in the basket on the way up)
			P.x = basket.pos.x - 0.6
			P.z = basket.pos.z - 0.7
			P.y = basket.pos.y
		if kt > 7.8:
			flags["finale_started"] = true
			finale.start()


## The cables down to the bundle and the basket, from their trolleys
func _cables() -> void:
	PalaceSite.stretch(site.pallet_cable, Vector3(bundle.pos.x, PalaceSite.JIB_B_Y - 0.4, bundle.pos.z), bundle.pos + Vector3(0.0, 3.6, 0.0), 0.02)
	PalaceSite.stretch(site.basket_cable, site.trolley_a.global_position, basket.pos + Vector3(0.0, 4.05, 0.0), 0.02)


## The horns: when a foreman gets to one it blares and more of the crew come
func _horns() -> void:
	for r: Robot in Game.enemies.robots:
		if not (r is FointGoon) or r.dead:
			continue
		var g := r as FointGoon
		if g.costume != "foreman" or not g.alarm_done or g.alarm_at == null:
			continue
		var at: Vector2 = g.alarm_at
		if at.distance_to(HORN_AT) < 0.1 and not _horn_done:
			_horn_done = true
			_blow_horn(HORN_AT, Y0)
		elif at.distance_to(HORN2_AT) < 0.1 and not _horn2_done:
			_horn2_done = true
			_reinforce()
	if _stage == "slab" and not _horn2_done:      # (the foreman down before he got there: somebody else hits it)
		var alive := false
		for r: Robot in bo.spawned:
			if r is FointGoon and (r as FointGoon).costume == "foreman" and not r.dead:
				alive = true
		if not alive:
			_horn2_done = true
			_reinforce()


## Floor six's horn: more of the crew up the hoist and the stairs
func _reinforce() -> void:
	_blow_horn(HORN2_AT, PalaceSite.ly(6))
	var y6 := PalaceSite.ly(6)
	_spawn([[161.0, y6, 217.0, PI, "crew", "smg"], [150.0, y6, 216.0, PI, "crew", "pistol"], [172.0, y6, 216.5, PI, "crew_hod"]])
	sambo.say("s_climb_10")
	chat.add_viewers(1500.0)


## Off the climb (fell a floor or more): back to the stage's start after a moment
func _falls(dt: float, P: Player) -> void:
	if P == null or P.dead or cine != null:
		return
	if P.y < _fall_y and P.grounded:
		_fall_t += dt
		if _fall_t > 0.6:
			_fall_t = 0.0
			Game.hud.toast("BACK UP YOU GO", 1.4)
			var sp: Variant = bo.cur().get("spawn")
			if sp is Dictionary:
				bo.teleport(sp, P)
	else:
		_fall_t = 0.0


## What the chat reacts to: a crewman down
func _chat_events() -> void:
	var dead := 0
	for r: Robot in bo.spawned:
		if r.dead:
			dead += 1
	for r: Robot in gate_crew:
		if r != null and r.dead:
			dead += 1
	if dead > _last_dead:
		_kills += dead - _last_dead
		chat.add_viewers(350.0 * (dead - _last_dead))
		if _rng.randf() < 0.6:
			chat.push(StreamChat.USERS[_rng.randi() % StreamChat.USERS.size()], ["TOAD DOWN", "unc folded him LMAO", "W CAMERAMAN", "he dropped the nail gun lmao", "workplace incident"][_rng.randi() % 5])
		if _kills == 3 or _kills == 9:
			sambo.say("s_climb_06")
	_last_dead = dead


## The cutscenes (palace_finale.gd, palace_ending.gd) say when they are done
func finale_done() -> void:
	flags["finale_done"] = true


func ended() -> void:
	flags["ended"] = true
