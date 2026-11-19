class_name UnderfointLevel
extends Level
## UNDERFOINT (user 2026-11-12): the old city FOINT CITY was built on top of, and the storm drain that leads down to it. The old city's streets and buildings are built for real (uf_arch.gd), and one district is finished by hand
## (uf_district.gd: the old square, the market hall, the tram line, the outcasts' camps). The sewer (uf_sewer.gd), the station (uf_station.gd) and the throne (uf_throne.gd) are built too.
##
## THE DRAIN (y 34): you come down the hub's storm drain into an ordinary, nasty sewer: a crawl pipe, a main tunnel, branches that end in rubble, a flood and a pump room. Nothing says there is more. One branch
## carries a black cable along its roof; near its barred end the floor grate is rotten and drops you 34 m through the new city's foundation slab.
## THE OLD CITY (y 0): about 200 m square under that slab, open to explore: two avenues, three cross streets, blocks of dead buildings with alleys between, FOINT's piles driven straight through the streets. Outcasts
## (not the hive) keep barrel fires in the old square and on two street corners and will talk. The Sigil's stragglers the Taken (enemies/taken.gd), wander the streets or stand in knots.
## FINDING THE SIGIL: nothing points to it. One black cable runs from where you land, round the streets, to an alley behind the station with the stopped clock; two of the outcasts tell you the same in words.
## Down the station stair: the concourse, the track tunnel with the dead train, and the chamber where the throne of bodies stands with the Sigil's television inside. Three Tethered (enemies/tethered.gd) are wired
## to the throne, two at its mouth and one in the cell: kill them or be past before they are up. When the Sigil has spoken it comes up out of the throne, and the way out is the last train, waiting in the old
## trunk line's mouth in the chamber's north wall: the run, the ride and the gate at the end of it are levels/underfoint/uf_chase.gd, the line it runs uf_route.gd, the train uf_train.gd.
##
## Stand-ins to replace, each the user's call: the outcasts' names and lines, the Sigil's lines and face, the Ticket Man's shouts on the train, where the last portal goes. ("Tethered" is a working name too.)

const SEW := 34.0                  # the sewer's floor
const SEW_TOP := 37.4              # and its roof
const SLAB := 30.0                 # underside of FOINT CITY's foundation slab: the old city's sky
const CELL := 2.0                  # the sewer is laid out on a 2 m grid: an open cell is tunnel, a closed cell beside one is wall
const GX0 := -94.0
const GZ0 := -108.0
const GNX := 34
const GNZ := 51
## the sewer's tunnels and rooms: [x0, x1, z0, z1]. In order: the chamber under the drain, the crawl pipe, the main tunnel, the flooded branch, the cross tunnel, the collapsed branch, the cabled branch, the pump room
const SEWER := [[-80, -74, -102, -96], [-74, -66, -98, -96], [-66, -62, -104, -38], [-86, -66, -72, -68], [-90, -34, -42, -38], [-90, -86, -38, -10], [-38, -34, -60, -20], [-42, -30, -66, -60]]
const HOLE := [-38.0, -34.0, -32.0, -28.0]       # the rotten grate, and the shaft through the slab under it
const SPAWN_SEWER := {"x": -76.0, "y": SEW + 0.1, "z": -97.0, "yaw": PI / 2.0}
const SPAWN_CITY := {"x": -36.0, "y": 0.2, "z": -37.0, "yaw": 0.0}
const BLOCK_X := [[-100.0, -42.0], [-30.0, 30.0], [42.0, 100.0]]      # the blocks between the two avenues (x -42..-30 and 30..42)
const BLOCK_Z := [[-100.0, -66.0], [-54.0, -6.0], [6.0, 54.0], [66.0, 100.0]]      # and between the three cross streets (z -66..-54, -6..6, 54..66)
const PILES := [[-36.0, -84.0], [36.0, -84.0], [-36.0, -46.0], [36.0, -30.0], [0.0, -60.0], [0.0, 60.0], [-36.0, 30.0], [36.0, 84.0]]      # FOINT CITY's foundation piles, 5 m square, floor to slab
const FIRES := [[-9.0, 22.0, 0.15], [8.0, 26.0, 0.15], [-2.0, 33.5, 0.15], [36.0, -44.0, 0.0], [-70.0, -60.0, 0.0], [10.0, 60.0, 0.0]]      # barrel fires: x, z, the floor's height
const STATION_Y := -7.0            # the station's and the chamber's floor
const SIGIL := Vector3(70.0, STATION_Y, 237.0)
const FLAME := preload("res://levels/shaders/uf_flame.gdshader")
const GAIN := 4.0                   # every light here is written against a sewer lamp of 1.5; this is what that takes to show on screen (found by eye, 2026-11-12)

## The look: black-green damp, little colour, the only warmth is fire
var look := {"ao": 0.9, "ao_radius": 1.4, "ao_fade": 60.0, "mist": 0.004, "mist_falloff": 0.1, "mist_y": 0.0, "mist_color": [0.11, 0.17, 0.14], "bloom": 0.5, "bloom_threshold": 0.7, "bloom_knee": 0.25,
	"scurve": 0.12, "saturation": 0.94, "shadow_tint": [0.93, 1.04, 0.97], "high_tint": [1.05, 1.0, 0.92], "vignette": 0.42, "vignette_tint": [0.0, 0.02, 0.01], "grain": 0.03}
var bo: Blockout = null
var crawl: CrawlKit = null

var _b: UfBuild
var _arch: UfArch
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _fires: Array[OmniLight3D] = []
var lamps: Array[OmniLight3D] = []      # the few street lamps and stoves still burning (levels/underfoint/uf_district.gd adds them): they waver
var _lamp_e := PackedFloat32Array()
var _flames: Array[MeshInstance3D] = []
var _flame_noise: NoiseTexture2D = null
var _outcasts: Array[OutcastNpc] = []
var _grate: World.Solid = null
var _grate_mesh: Node3D = null
var _grate_fall := -1.0          # seconds since the grate went; < 0 = it is still there
var district: UfDistrict = null
var throne: UfThrone = null       # kept: its doors and its watching heads are run from tick()
var chase: UfChase = null         # the way out: levels/underfoint/uf_chase.gd
var _grate_t := 0.0
var _screen_light: OmniLight3D = null
var _stragglers_out := false


func build() -> void:
	_rng.seed = 90210
	_b = UfBuild.new(world)
	_b.base_y = -1000.0      # (nothing is shaded toward the ground unless a builder says where the ground is)
	_arch = UfArch.new(_b, _rng)
	_materials()
	district = UfDistrict.new(self, _b, _arch, _rng)
	district.materials()
	_render_state()
	_sewer()
	_city()
	_plaza()
	_station()
	_chamber()
	_cables()
	_b.commit(self)
	chase = UfChase.new(self)
	add_child(chase)
	chase.build(_b, _arch, district)
	TakenView.warm(self)      # the Taken's bodies (FOINT's own species, enemies/taken_view.gd): made now, not when the first one is seen
	_b = null
	_arch = null
	district = null
	world.spawn = SPAWN_SEWER.duplicate()
	world.target_spots = []            # no shooting-range dummies, pods or clerk here (Combat._build_range)
	world.pickup_spots = []
	world.clerk_spot = [0.0, -400.0]
	world.projectile_floor_y = -9.0    # the station is under the streets: every floor here is a real collider, so this only has to be below all of them
	portals.append({"id": "uf_drain_up", "label": "CLIMB BACK UP TO THE STREET", "x": -78.8, "z": -100.6, "radius": 1.3, "to": "hub", "spawn_at": "sewer", "loading": "FOINT CITY",
		"active": func() -> bool: return Game.player.y > SLAB})
	portals.append({"id": "uf_ladder_up", "label": "CLIMB THE SERVICE LADDER", "x": -36.0, "z": -42.6, "radius": 1.5, "to": "hub", "spawn_at": "sewer", "loading": "FOINT CITY",
		"active": func() -> bool: return Game.player.y < 4.0})
	_talkers()
	bo = Blockout.new(self, {"id": id, "name": "STORM DRAIN", "spawn": SPAWN_SEWER, "on_enter_stage": _stage_entered, "complete_text": "OUT."})
	bo.stage({"id": "sewer", "name": "The drain", "spawn": SPAWN_SEWER, "objectives": [
		{"id": "through", "label": "The drain", "text": "See where the drain goes.", "kind": "custom", "done": func(_k: Blockout, p: Player, _c: Combat) -> bool: return p.y < 12.0},
	]})
	bo.stage({"id": "city", "name": "The old city", "spawn": SPAWN_CITY, "objectives": [
		{"id": "find", "label": "UNDERFOINT", "kind": "custom", "text": _city_text, "done": func(_k: Blockout, p: Player, _c: Combat) -> bool: return p.z > 109.0 and p.y < STATION_Y + 2.0},
	]})
	bo.stage({"id": "station", "name": "Clock Street station", "spawn": {"x": 71.0, "y": STATION_Y + 0.1, "z": 111.0, "yaw": 0.0}, "objectives": [
		{"id": "tunnel", "label": "The tunnel", "text": "Follow the cable down the line.", "at": [71.0, STATION_Y, 178.0], "radius": 3.0},
	]})
	bo.stage({"id": "throne", "name": "The throne", "spawn": {"x": 71.0, "y": STATION_Y + 0.1, "z": 184.0, "yaw": 0.0}, "objectives": [
		{"id": "sigil", "label": "The Sigil", "text": "Go in. It is waiting to speak to you.", "kind": "custom", "done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return throne.talked},
	]})
	# the run: from the burst heap to the last train, waiting in the old trunk line's mouth in the chamber's north wall (the retry starts east of the heap, facing it). The ride's three stretches go
	# on from each other without a cut; their spawns are only for a retry or a checkpoint (levels/underfoint/uf_chase.gd puts you back on the car).
	var deck := {"x": UfRoute.HOME.x, "y": STATION_Y + UfTrain.DECK + 0.1, "z": UfRoute.HOME.z - 6.0, "yaw": PI}
	bo.stage({"id": "escape", "name": "The last train", "spawn": {"x": 98.0, "y": STATION_Y + 0.1, "z": 250.0, "yaw": -0.95}, "objectives": [
		{"id": "run", "label": "Run", "text": "RUN. The last train's lamps are lit in the tunnel through the north wall.", "kind": "custom", "at": [UfChase.BOARD.x, STATION_Y, UfChase.BOARD.y],
			"on_start": func(_k: Blockout, e: Dictionary) -> void: chase.start_run(e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return chase.aboard},
		{"id": "ride1", "label": "The trunk line", "text": func(_k: Blockout) -> String: return chase.task(), "detail": chase.detail, "guide": false, "kind": "custom", "spawn": deck,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: chase.start_stretch(0, e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return chase.stretch_clear(0)},
		{"id": "ride2", "label": "The viaduct", "text": func(_k: Blockout) -> String: return chase.task(), "detail": chase.detail, "guide": false, "kind": "custom", "spawn": deck,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: chase.start_stretch(1, e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return chase.stretch_clear(1)},
		{"id": "ride3", "label": "The end of the line", "text": func(_k: Blockout) -> String: return chase.task(), "detail": chase.detail, "guide": false, "kind": "custom", "spawn": deck,
			"on_start": func(_k: Blockout, e: Dictionary) -> void: chase.start_stretch(2, e.get("retry", false)),
			"done": func(_k: Blockout, _p: Player, _c: Combat) -> bool: return chase.stretch_clear(2)},
	]})
	bo.build_checkpoints()


func apply_spawn(at: String) -> void:
	if at == "city":      # down the drain by someone who knows the way: straight to the old city
		world.spawn = SPAWN_CITY.duplicate()


func _stage_entered(b: Blockout, e: Dictionary) -> void:
	if e.stage == "sewer":
		return
	b.display_name = "UNDERFOINT"      # (the drain does not say where it goes)
	if not Game.story_get("ufFound"):
		Game.story_set("ufFound")


func _city_text(_k: Blockout) -> String:
	return "Find the old station under the stopped clock." if Game.story_get("ufStation") else "Look around. Somebody down here must talk."


func on_enter() -> void:
	bo.on_level_entered()
	crawl = CrawlKit.new(_in_pipe)


func on_exit() -> void:
	bo.dispose()
	if crawl != null:
		crawl.dispose()
		crawl = null


## the crawl pipe out of the drain chamber, and 0.9 m beyond each mouth so he is down before he is in
static func _in_pipe(p: Player) -> bool:
	return p.x > -74.9 and p.x < -65.1 and p.z > -98.1 and p.z < -95.9 and p.y > SEW - 0.5 and p.y < SEW + 1.4


## After the player's own frame (Game calls it): the chase holds him at SERN's gun on the car while he mans it
func after_player(dt: float) -> void:
	if chase != null:
		chase.after_player(dt)


func tick(dt: float) -> void:
	_t += dt
	var p := Game.player
	TakenView.warm_tick(get_viewport().get_camera_3d())
	bo.update(dt, p, Game.combat)
	if crawl != null:
		crawl.update(dt)
	if throne != null and Game.enemies != null and (chase == null or chase.mode == &"off" or chase.mode == &"run"):      # (once the train is away the throne is put away with the rest: its own tick would show its bodies again)
		throne.tick(dt, p)
	if chase != null and Game.enemies != null:
		chase.tick(dt)
	if not _stragglers_out and Game.combat != null:
		_stragglers_out = true
		_stragglers()
	# the rotten grate: it takes his weight for a moment, then goes
	if _grate != null and not _grate.off:
		var on_it := p.grounded and p.x > HOLE[0] + 0.3 and p.x < HOLE[1] - 0.3 and p.z > HOLE[2] + 0.3 and p.z < HOLE[3] - 0.3 and absf(p.y - SEW) < 0.5
		_grate_t = _grate_t + dt if on_it else 0.0
		_grate_mesh.rotation.x = minf(_grate_t, 0.3) * 0.12 * sin(_t * 38.0)
		_grate_mesh.rotation.z = minf(_grate_t, 0.3) * 0.08 * sin(_t * 29.0)
		if _grate_t > 0.3:
			_grate.set_off(true)
			_grate_fall = 0.0
	if _grate_fall >= 0.0 and _grate_mesh.position.y > 1.0:      # it goes down the shaft with him, turning over, and ends up on the heap he lands on
		_grate_fall += dt
		_grate_mesh.position.y = maxf(1.0, SEW - 11.0 * _grate_fall * _grate_fall)
		_grate_mesh.rotation.x += dt * 1.1
		_grate_mesh.rotation.z += dt * 0.6
		if _grate_mesh.position.y <= 1.0:
			_grate_mesh.position = Vector3(-35.2, 0.75, -28.6)
			_grate_mesh.rotation = Vector3(0.42, 0.5, -0.12)
	for i in _fires.size():
		var f := 0.8 + 0.2 * sin(_t * 13.0 + i * 1.7) * sin(_t * 7.3 + i * 4.1) + 0.06 * sin(_t * 31.0 + i)
		_fires[i].light_energy = 2.0 * GAIN * f
		_flames[i].scale = Vector3(1.0, 0.75 + 0.5 * f, 1.0)
	if _lamp_e.size() != lamps.size():
		_lamp_e.clear()
		for l in lamps:
			_lamp_e.append(l.light_energy)
	for i in lamps.size():      # a tired filament: mostly steady, now and then it nearly goes
		var dip := 0.25 if fmod(_t * 0.37 + i * 1.913, 7.0) < 0.12 else 1.0
		lamps[i].light_energy = _lamp_e[i] * dip * (0.92 + 0.08 * sin(_t * 23.0 + i * 2.7))
	if _screen_light != null:
		_screen_light.light_energy = GAIN * (1.6 + 0.5 * sin(_t * 2.1) + (0.6 if fmod(_t, 5.3) < 0.08 else 0.0))
	for a in _outcasts:
		a.update(_t, dt)


## the console's `cp`, and CONTINUE
var checkpoints: Array:
	get:
		return bo.checkpoints if bo != null else []


func load_checkpoint(which: Variant) -> bool:
	return bo.load_cp(which)


# ---- look -------------------------------------------------------------------------------------------------------------------------------------------------------------

func _materials() -> void:
	_b.mat("slime", Color(0.08, 0.13, 0.06), {"rough": 0.12})
	# the old city's own: photographed surfaces (Poly Haven, CC0) pulled toward this place's black-green, under the damp-and-moss shader
	_b.tex("street", "cobblestone_floor_04", {"tile": 1.9, "tint": Color(0.5, 0.52, 0.5), "puddles": 1.0, "growth": 0.8})
	_b.tex("walk", "brick_pavement_02", {"tile": 2.2, "tint": Color(0.5, 0.48, 0.45), "puddles": 0.7})
	_b.tex("brick", "brick_wall_001", {"tile": 2.4, "tint": Color(0.62, 0.5, 0.46)})
	_b.tex("brick2", "painted_brick", {"tile": 2.4, "tint": Color(0.58, 0.66, 0.6)})
	_b.tex("plaster", "blue_plaster_weathered", {"tile": 3.0, "tint": Color(0.66, 0.62, 0.5)})
	_b.tex("stone", "cracked_concrete_wall", {"tile": 3.0, "tint": Color(0.55, 0.57, 0.56)})
	_b.tex("trim", "cracked_concrete_wall", {"tile": 1.6, "tint": Color(0.78, 0.76, 0.68)})
	_b.tex("inner", "blue_plaster_weathered", {"tile": 2.5, "tint": Color(0.36, 0.4, 0.36)})
	_b.tex("roof", "concrete_debris", {"tile": 4.0, "tint": Color(0.32, 0.32, 0.32), "puddles": 1.0})
	_b.tex("debris", "concrete_debris", {"tile": 2.5, "tint": Color(0.62, 0.6, 0.56), "growth": 1.3})
	_b.tex("shutter", "rusted_shutter", {"tile": 2.7, "growth": 0.5})
	_b.tex("planks", "distressed_painted_planks", {"tile": 1.6, "tint": Color(0.5, 0.45, 0.38), "growth": 0.6})
	_b.tex("iron", "corrugated_iron_02", {"tile": 2.0, "tint": Color(0.6, 0.55, 0.5), "growth": 0.5})
	_b.tex("sign_a", "distressed_painted_planks", {"tile": 1.8, "tint": Color(0.55, 0.2, 0.15), "growth": 0.5})
	_b.tex("sign_b", "distressed_painted_planks", {"tile": 1.8, "tint": Color(0.2, 0.42, 0.4), "growth": 0.5})
	_b.tex("sign_c", "distressed_painted_planks", {"tile": 1.8, "tint": Color(0.66, 0.58, 0.36), "growth": 0.5})
	var void_m := StandardMaterial3D.new()      # what is behind a hole in a wall: nothing
	void_m.albedo_color = Color(0.004, 0.006, 0.005)
	void_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_b.mats["void"] = void_m
	_b.mat("window", Color(0.03, 0.035, 0.04), {"rough": 0.2})
	_b.mat("pile", Color(0.08, 0.07, 0.12), {"rough": 0.55, "scale": 0.05})      # FOINT CITY's own near-black violet: the new city standing in the old one
	_b.mat("rock", Color(0.1, 0.1, 0.11), {"scale": 0.06})
	_b.tex("rubble", "concrete_debris", {"tile": 2.5, "tint": Color(0.55, 0.52, 0.48), "growth": 1.2})
	_b.mat("rust", Color(0.3, 0.14, 0.07), {"rough": 0.6, "metal": 0.6, "scale": 0.5})
	_b.mat("tarp", Color(0.16, 0.2, 0.26), {"rough": 0.95})
	_b.mat("tile", Color(0.33, 0.36, 0.33), {"rough": 0.4, "scale": 0.25})
	_b.mat("train", Color(0.34, 0.3, 0.22), {"rough": 0.5, "metal": 0.3})
	_b.mat("cable", Color(0.015, 0.015, 0.018), {"rough": 0.35})
	_b.mat("flesh", Color(0.3, 0.13, 0.12), {"rough": 0.45, "scale": 0.35})
	_b.mat("flesh2", Color(0.38, 0.27, 0.22), {"rough": 0.5, "scale": 0.5})
	_b.mat("crt", Color(0.3, 0.3, 0.27), {"rough": 0.6})
	_b.glow("lamp", Color(1.0, 0.72, 0.42), 2.5)
	_b.glow("candle", Color(1.0, 0.6, 0.22), 1.2)
	_b.glow("fungus", Color(0.2, 0.9, 0.55), 0.55)
	_b.mat("stalk", Color(0.2, 0.26, 0.2), {"rough": 0.6, "scale": 1.5})
	_b.glow("screen", Color(0.35, 1.0, 0.45), 2.4)      # Phosphor green: the Sigil's colour
	_b.glow("clock", Color(1.0, 0.75, 0.4), 0.5)


func _render_state() -> void:
	# the haze is lighter than what stands in it, so a street reads as dark shapes against it however little light there is
	Game.view.apply_render_state({"background": Color("16221c"), "tone_mapping": View.TONE_ACES, "exposure": 1.35, "fog": [Color("16221c"), 0.011],
		"hemi": [Color("7f9f90"), Color("302a1e"), 3.2], "sun": [Color("ffffff"), 0.0], "sun_cast": false, "clip": [0.1, 450.0]})


func _light(at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = at
	l.light_color = color
	l.light_energy = energy * GAIN
	l.omni_range = reach * 1.3
	l.omni_attenuation = 1.3
	l.light_specular = 0.4
	l.distance_fade_enabled = true
	l.distance_fade_begin = 70.0
	l.distance_fade_length = 20.0
	add_child(l)
	return l


# ---- the sewer --------------------------------------------------------------------------------------------------------------------------------------------------------

## The storm drain: levels/underfoint/uf_sewer.gd draws and walls it from SEWER; the grate it hands back is the one tick() drops
func _sewer() -> void:
	var sw := UfSewer.new(self, _b, _arch, _rng)
	sw.build()
	_grate = sw.grate
	_grate_mesh = sw.grate_node


## a heap of broken masonry: n blocks round a point
func _rubble(cx: float, cz: float, r: float, n: int, y: float = 0.0) -> void:
	for k in n:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r
		var hx := _rng.randf_range(0.35, 1.1)
		var hz := _rng.randf_range(0.35, 1.1)
		var x := cx + cos(a) * d
		var z := cz + sin(a) * d
		_b.box("rubble", x - hx, x + hx, y, y + _rng.randf_range(0.3, 1.3) * (1.0 - 0.5 * d / r), z - hz, z + hz)


# ---- the old city ------------------------------------------------------------------------------------------------------------------------------------------------------

func _city() -> void:
	# the ground (open over the station stair), the cavern's walls, and the slab overhead with the shaft through it
	_b.box("street", -104.0, 104.0, -1.0, 0.0, -104.0, 84.0)
	_b.box("street", -104.0, 68.0, -1.0, 0.0, 84.0, 104.0)
	_b.box("street", 74.0, 104.0, -1.0, 0.0, 84.0, 104.0)
	_b.box("rock", -108.0, 108.0, 0.0, SLAB, 100.0, 108.0)
	_b.box("rock", -108.0, 108.0, 0.0, SLAB, -108.0, -100.0)
	_b.box("rock", -108.0, -100.0, 0.0, SLAB, -100.0, 100.0)
	_b.box("rock", 100.0, 108.0, 0.0, SLAB, -100.0, 100.0)
	_b.box("pile", -108.0, 108.0, SLAB, SEW - 0.6, -108.0, HOLE[2])
	_b.box("pile", -108.0, 108.0, SLAB, SEW - 0.6, HOLE[3], 108.0)
	_b.box("pile", -108.0, HOLE[0], SLAB, SEW - 0.6, HOLE[2], HOLE[3])
	_b.box("pile", HOLE[1], 108.0, SLAB, SEW - 0.6, HOLE[2], HOLE[3])
	for q: Array in PILES:
		_b.box("pile", q[0] - 2.5, q[0] + 2.5, 0.0, SLAB, q[1] - 2.5, q[1] + 2.5)
	# the blocks: all but the old square (centre column, third row) and the station's block (east column, north row), which are made by hand
	for ci in BLOCK_X.size():
		for ri in BLOCK_Z.size():
			if (ci == 1 and ri == 2) or (ci == 2 and ri == 3):
				continue
			_block(BLOCK_X[ci][0], BLOCK_X[ci][1], BLOCK_Z[ri][0], BLOCK_Z[ri][1])
			_b.commit(self, "_block%d%d" % [ci, ri])      # (a block is its own meshes: what is behind you is not drawn)
	# where you land: a heap of what came down the shaft before you, and the little light that follows you down
	_b.box("rubble", -38.2, -33.8, 0.0, 0.5, -32.2, -27.8)
	_b.box("rubble", -37.2, -34.8, 0.5, 0.9, -31.2, -28.8)
	_light(Vector3(-36.0, 5.0, -30.0), Color("8fffb0"), 1.0, 14.0)
	# the way back up: a service ladder on the pile south of the heap
	_b.box("rust", -36.4, -35.6, 0.0, SLAB, -43.5, -43.38, false)
	# fungus: the only light the old city makes for itself
	for q: Array in [[-29.0, -40.0], [-43.0, -12.0], [-30.5, 8.0], [29.0, -52.0], [43.0, 20.0], [-60.0, 5.5], [20.0, -66.5], [80.0, -5.5], [-80.0, 53.5], [43.5, 60.0], [66.5, 71.0], [-10.0, 66.5]]:
		for k in 14:      # a colony: thin stems, a flat cap on each, the big ones in the middle
			var a := _rng.randf() * TAU
			var d := _rng.randf() * _rng.randf() * 1.5
			var x: float = q[0] + cos(a) * d
			var z: float = q[1] + sin(a) * d
			var s := _rng.randf_range(0.05, 0.2) * (1.3 - d * 0.5)
			var h := _rng.randf_range(0.12, 0.75) * (1.3 - d * 0.5)
			_b.turned("stalk", x, z, s * 0.22, s * 0.22, 0.0, h, 0.0, Vector2(_rng.randf_range(-0.08, 0.08), _rng.randf_range(-0.08, 0.08)))
			_b.turned("fungus", x, z, s, s, h, h + s * 0.35, a)
			_b.turned("stalk", x, z, s * 0.7, s * 0.7, h + s * 0.35, h + s * 0.6, a)
		_light(Vector3(q[0], 0.8, q[1]), Color("4dffb0"), 0.7, 6.5)
	# television sets nobody plugged in, lit all the same: one at each turn of the cable
	for q: Array in [[-29.0, 3.0, 0.0], [28.6, 7.4, 0.15], [28.6, 67.4, 0.15], [66.2, 67.4, 0.15]]:
		_tv(q[0], q[2], q[1])
	# the outcasts' fires on the street corners (the old square's are in _plaza)
	for i in range(3, FIRES.size()):
		_fire(FIRES[i][0], FIRES[i][2], FIRES[i][1])
	_b.box("tarp", 38.6, 41.4, 0.0, 1.7, -49.0, -46.4)
	_rubble(-73.0, -62.6, 1.4, 5)
	for k in 5:      # the collector's sets, face down
		var x := -76.6 + k * 0.8
		_b.box("crt", x - 0.3, x + 0.3, 0.0, 0.5, -61.3, -60.7)


## One city block: a pavement, and on it a grid of buildings with alleys between. Now and then a lot is only rubble.
func _block(x0: float, x1: float, z0: float, z1: float) -> void:
	_b.box("walk", x0, x1, 0.0, 0.15, z0, z1)
	var nx := maxi(1, roundi((x1 - x0) / 19.0))
	var nz := maxi(1, roundi((z1 - z0) / 19.0))
	var alley := 3.0
	var wx := (x1 - x0 - 5.0 - alley * (nx - 1)) / nx
	var wz := (z1 - z0 - 5.0 - alley * (nz - 1)) / nz
	for i in nx:
		for j in nz:
			var bx := x0 + 2.5 + i * (wx + alley)
			var bz := z0 + 2.5 + j * (wz + alley)
			if _rng.randf() < 0.1:      # a lot that came down whole
				_arch.heap(bx + wx * 0.5, bz + wz * 0.5, minf(wx, wz) * 0.42, 0.15, "brick")
				_arch.heap(bx + wx * 0.3, bz + wz * 0.6, minf(wx, wz) * 0.3, 0.15, "stone")
				continue
			var shops: Array = []      # the faces on a street sold things; the ones on an alley did not
			if j == 0:
				shops.append(0)
			if j == nz - 1:
				shops.append(1)
			if i == 0:
				shops.append(2)
			if i == nx - 1:
				shops.append(3)
			_arch.building({"x0": bx, "x1": bx + wx, "z0": bz, "z1": bz + wz, "y": 0.15, "floors": [2, 3, 3, 4, 4, 5, 6, 7][_rng.randi() % 8], "wall": ["brick", "brick", "brick2", "plaster", "stone"][_rng.randi() % 5],
				"trim": "trim", "shops": shops, "ruin": _rng.randf() < 0.3, "shade": _rng.randf_range(0.72, 1.0)})


## dark windows on all four faces of a building; a rare one has a candle in it
func _windows(x0: float, x1: float, z0: float, z1: float, h: float) -> void:
	var y := 2.2
	while y + 1.6 < h - 0.6:
		var x := x0 + 1.6
		while x + 1.2 < x1 - 0.4:
			_b.box(_pane(), x, x + 1.2, y, y + 1.6, z0 - 0.06, z0, false)
			_b.box(_pane(), x, x + 1.2, y, y + 1.6, z1, z1 + 0.06, false)
			x += 3.0
		var z := z0 + 1.6
		while z + 1.2 < z1 - 0.4:
			_b.box(_pane(), x0 - 0.06, x0, y, y + 1.6, z, z + 1.2, false)
			_b.box(_pane(), x1, x1 + 0.06, y, y + 1.6, z, z + 1.2, false)
			z += 3.0
		y += 3.4


func _pane() -> String:
	return "candle" if _rng.randf() < 0.012 else "window"


## A barrel with a fire in it: the barrel is solid, the fire is a light and a flame that tick() flickers
func _fire(x: float, y: float, z: float) -> void:
	world.add({"kind": "disc", "cx": x, "cz": z, "r": 0.36, "bottom": y, "top": y + 0.9, "tag": "barrel"})
	var barrel: Node3D = (load("res://assets/third-party/polyhaven/Barrel_01/Barrel_01.gltf") as PackedScene).instantiate()
	barrel.position = Vector3(x, y, z)
	barrel.rotation.y = x * 1.7 + z
	add_child(barrel)
	if _flame_noise == null:
		var fn := FastNoiseLite.new()
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 0.02
		fn.fractal_octaves = 3
		_flame_noise = NoiseTexture2D.new()
		_flame_noise.width = 128
		_flame_noise.height = 128
		_flame_noise.seamless = true
		_flame_noise.noise = fn
	var card := QuadMesh.new()
	card.size = Vector2(0.8, 1.25)
	card.center_offset = Vector3(0.0, 0.62, 0.0)
	var fm := ShaderMaterial.new()
	fm.shader = FLAME
	fm.set_shader_parameter(&"noise_tex", _flame_noise)
	fm.set_shader_parameter(&"seed", fposmod(x * 0.37 + z * 0.11, 1.0))
	var flame := MeshInstance3D.new()
	flame.mesh = card
	flame.material_override = fm
	flame.extra_cull_margin = 1.5
	flame.position = Vector3(x, y + 0.8, z)
	add_child(flame)
	_flames.append(flame)
	_fires.append(_light(Vector3(x, y + 1.9, z), Color("ff8a3a"), 2.0, 13.0))


## A dead television that is on anyway. Faces +x.
func _tv(x: float, y: float, z: float) -> void:
	_b.box("crt", x - 0.3, x + 0.3, y, y + 0.55, z - 0.35, z + 0.35)
	_b.box("screen", x + 0.3, x + 0.32, y + 0.1, y + 0.47, z - 0.25, z + 0.25, false)
	_light(Vector3(x + 0.8, y + 0.4, z), Color("58ff7a"), 0.9, 4.5)


## The old square, the market hall, the tram line and the outcasts' camps: levels/underfoint/uf_district.gd. Only the three fires are made here, so they flicker with the rest.
func _plaza() -> void:
	district.build()
	for i in 3:
		_fire(FIRES[i][0], FIRES[i][2], FIRES[i][1])


# ---- the station and the chamber ---------------------------------------------------------------------------------------------------------------------------------------

## The station's block (x 42..100, z 66..100): two buildings with an alley between them (x 67..75) that the street does not show: rubble across its mouth, no light in it. At the alley's end the stair goes down
## under the cavern wall to the concourse, then the track tunnel north. The clock tower on the east building is what the outcasts mean by "under the stopped clock".
func _station() -> void:
	UfStation.new(self, _b, _arch, _rng).build()


## The chamber and the throne: levels/underfoint/uf_throne.gd
func _chamber() -> void:
	throne = UfThrone.new(self, _b, _arch, _rng)
	throne.build()


## One black cable from the sewer to the Sigil: along the roof of the right branch, down the shaft, round the streets to the alley, down the stair and the tunnel. It is the way, for whoever looks at it.
func _cables() -> void:
	_b.box("cable", -62.0, -34.1, SEW_TOP - 0.12, SEW_TOP, -38.3, -38.1, false)
	_b.box("cable", -34.3, -34.1, SEW_TOP - 0.12, SEW_TOP, -38.3, -28.1, false)
	_b.box("cable", -34.3, -34.1, 0.0, SEW_TOP, -28.3, -28.1, false)
	_b.box("cable", -34.3, -30.5, 0.0, 0.1, -28.3, -28.1, false)
	_b.box("cable", -30.7, -30.5, 0.0, 0.1, -28.3, 5.7, false)
	_b.box("cable", -30.7, 30.5, 0.0, 0.1, 5.5, 5.7, false)
	_b.box("cable", 30.3, 30.5, 0.0, 0.1, 5.5, 65.7, false)
	_b.box("cable", 30.3, 71.1, 0.0, 0.1, 65.5, 65.7, false)
	_b.box("cable", 70.9, 71.1, 0.15, 0.25, 66.0, 84.0, false)
	_b.box("cable", 70.9, 71.1, STATION_Y + 4.88, STATION_Y + 5.0, 108.0, 180.0, false)


# ---- who lives here ----------------------------------------------------------------------------------------------------------------------------------------------------

## The outcasts: not the hive. Each stands with a fire at their back, so the talk shot looks at them across open ground with the fire behind (facing the fire put the camera in the flames).
## Their bodies are enemies/outcast_npc.gd's five (a mole stoker, a heron in rags, a big-eared listener, a tortoise conductor, a hooded collector of sets): PROPOSALS, like their names and their lines,
## all the user's to approve or rewrite. The lines are there to try how finding the Sigil by talking works: two of them (THE LISTENER, TICKET MAN) give the station away; the others only say what is wrong down here.
func _talkers() -> void:
	_outcast("uf_firekeeper", "FIREKEEPER", -9.0, 0.15, 20.2, PI, "stoker", 0.8, [
		"New face. You came down the drain. Everybody comes down the drain.",
		"They built their city on top of ours and never said. This is UNDERFOINT. What's left.",
		"Stay near a fire. The quiet ones don't like a fire."], false)
	_outcast("uf_rag_woman", "RAG WOMAN", 8.0, 0.15, 27.8, 0.0, "ragwoman", 1.2, [
		"My husband went quiet in the spring. Stopped talking halfway through a word.",
		"Now he stands in the avenue with the others. They all turn their heads at the same time.",
		"There's a cable in the back of his neck. Don't follow the cables."], false)
	_outcast("uf_listener", "THE LISTENER", -2.0, 0.15, 35.3, 0.0, "listener", 0.95, [
		"It talks to them. I hear it if I put my teeth on the pipes.",
		"A face on a television. It calls itself the Sigil.",
		"It sits past the old station. Under the stopped clock. Every cable down here ends there."], true)
	_outcast("uf_ticket_man", "TICKET MAN", 36.0, 0.0, -45.8, PI, "ticketman", 0.65, [
		"I sold tickets at Clock Street. Trains stopped. Clock stopped. I didn't.",
		"SERN came down after it once. Twelve men and a truck. The truck's still here.",
		"Station's behind the tall building on the north street. Through the alley, down the stair. I wouldn't."], true)
	_outcast("uf_collector", "COLLECTOR", -70.0, 0.0, -58.2, 0.0, "collector", 1.1, [
		"I collect televisions. They keep turning themselves on.",
		"I put them face down now."], false)


func _outcast(tid: String, title: String, x: float, y: float, z: float, yaw: float, body: String, pitch: float, lines: Array, tells: bool) -> void:
	var a := OutcastNpc.new(body)
	add_child(a)
	a.place(x, y, z, yaw)
	_outcasts.append(a)
	var d := {"id": tid, "name": title, "x": x, "y": y, "z": z, "yaw": yaw, "actor": a, "voice_pitch": pitch, "color": "#c9b58a", "lines": lines}
	if tells:
		d["on_end"] = func(_t: Dictionary) -> void:
			if not Game.story_get("ufStation"):
				Game.story_set("ufStation")
	Game.dialogue.add_talker(d)


## The Sigil's stragglers: the Taken (enemies/taken.gd), alone on a beat or stood in a knot in the road, all facing nowhere. [x, y, z, patrol x, patrol z, yaw]; which townsperson each was goes round in turn.
## Then the Tethered (enemies/tethered.gd), each wired to the throne: one either side of its mouth, their cables into the mound's face, and one in the cell on the west wall. [home x, z, facing, anchor x, y, z, reach]
## (The two at the mouth reach 8.2 m: just into the mouth and no further, so the corridor behind them is the safe ground you run for. At 9 they followed you half way down it, their cables through the mound's corner.)
func _stragglers() -> void:
	var n := 0
	for q: Array in [[36.0, 0.0, 14.0, 0.0, 9.0, 0.0], [58.0, 0.0, 60.0, 10.0, 0.0, 1.6], [-70.0, 0.0, 0.0, 10.0, 0.0, 1.6], [18.0, 0.0, -60.0, 8.0, 0.0, -1.6], [88.0, 0.0, 0.0, 6.0, 0.0, 1.6], [-36.0, 0.0, 78.0, 0.0, 8.0, 3.1],
			[34.0, 0.0, 40.0, 0.0, 0.0, 2.2], [36.4, 0.0, 41.6, 0.0, 0.0, -0.7], [38.0, 0.0, 39.4, 0.0, 0.0, 0.4], [35.2, 0.0, 43.4, 0.0, 0.0, 3.0],      # the knot in the east avenue
			[-37.0, 0.0, -74.0, 0.0, 0.0, 1.0], [-35.0, 0.0, -72.6, 0.0, 0.0, -2.0], [-38.2, 0.0, -71.6, 0.0, 0.0, 0.2],      # and one at the south end of the west avenue
			[71.0, 0.15, 78.0, 0.0, 3.0, 3.1], [62.0, STATION_Y, 121.0, 0.0, 4.0, 3.1], [80.0, STATION_Y, 120.0, 0.0, 4.0, 3.1], [71.0, STATION_Y, 156.0, 0.0, 0.0, 3.1], [68.0, STATION_Y, 176.0, 0.0, 0.0, 3.1],
			[50.0, STATION_Y, 200.0, 8.0, 0.0, 3.1], [92.0, STATION_Y, 200.0, 8.0, 0.0, 3.1], [60.0, STATION_Y, 206.0, 0.0, 0.0, 3.1], [80.0, STATION_Y, 206.0, 0.0, 0.0, 3.1]]:
		Game.spawn_enemy({"x": q[0], "y": q[1], "z": q[2], "yaw": q[5]}, {"kind": "taken", "head": n % 3, "ax": q[3], "az": q[4], "no_respawn": true})
		n += 1
	for q: Array in [[62.0, 217.5, PI, 62.0, STATION_Y + 4.6, 219.0, 8.2], [78.0, 217.5, PI, 78.0, STATION_Y + 4.6, 219.0, 8.2], [66.4, 233.0, PI * 0.5, 65.0, STATION_Y + 3.6, 233.0, 6.0]]:
		Game.spawn_enemy({"x": q[0], "y": STATION_Y, "z": q[1], "yaw": q[2]}, {"kind": "tethered", "face": q[2], "anchor": [q[3], q[4], q[5]], "reach": q[6], "no_respawn": true})
		_light(Vector3(q[0] + sin(q[2]) * 1.2, STATION_Y + 2.6, q[1] + cos(q[2]) * 1.2), Color("58ff7a"), 0.5, 7.0)      # the socket's glow on the thing folded under it, so it is seen before it moves
