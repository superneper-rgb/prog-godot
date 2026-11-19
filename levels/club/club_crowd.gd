class_name ClubCrowd
extends Node3D
## CLUB 9's people. The city goths (tools/folk species) dance on the floor, each species one MultiMesh skinned on the GPU from a dance baked at load (club_dance.gd); green
## aliens dance among them on their own batched rigs. At the bar the bartender works through a routine that never stops (shake, pour, slide, pull a pint, a bottle off the shelf,
## a flip, wipe down) and makes Prog's drinks when he orders; a snake-necked goth leans on the bar flirting with an alien on a stool; outside the men's room an alien in
## party clothes sits on the floor being sick.
## (2026-11-16: rebuilt. The first crowd's dance swung the goths' arms through their bodies; there are now twice as many goths, and the scene round the bar is new.)

const BEAT := 1.0 / ClubLevel.BEAT_HZ
const DJ := Vector2(0.0, 12.6)

## The dance floor: species, x, z, facing (a point to face, or DJ), beats into the phrase, hue turn, brightness (copies of a species are tinted apart).
const FLOOR := [
	["lilac_spider", -3.4, 8.3, DJ, 0, 0.0, 1.0],
	["snakeneck", -1.6, 9.0, DJ, 8, 0.0, 1.0],
	["manta_goth", 2.0, 8.7, DJ, 16, 0.0, 1.0],
	["naga", 3.7, 8.0, DJ, 4, 0.0, 1.0],
	["demon_tail", 0.6, 7.3, Vector2(-1.0, 9.5), 12, 0.0, 1.0],
	["fish_biker", -4.6, 5.7, Vector2(-3.2, 4.7), 0, 0.0, 1.0],
	["lilac_spider", -3.2, 4.7, Vector2(-4.6, 5.7), 20, 0.45, 0.95],
	["snakeneck", 4.1, 5.4, Vector2(2.8, 4.2), 24, 0.6, 1.0],
	["demon_tail", 2.8, 4.2, Vector2(4.1, 5.4), 6, 0.32, 0.92],
	["naga", -0.8, 5.7, DJ, 28, 0.55, 1.0],
	["manta_goth", 1.0, 5.1, DJ, 10, 0.25, 1.0],
	["fish_biker", -1.5, 2.7, DJ, 18, 0.5, 0.95],
	# in the go-go cages at the stage corners (club_dressing.gd), up on their plinths
	["lilac_spider", -5.6, 10.3, Vector2(-1.0, 4.0), 14, 0.82, 1.05, ClubDressing.PLINTH_H],
	["snakeneck", 5.6, 10.3, Vector2(1.0, 4.0), 2, 0.3, 1.0, ClubDressing.PLINTH_H],
]
## Green aliens on the floor: outfit, x, z, dance style.
const ALIENS := [["goth", -2.4, 7.0, 0], ["punk", -4.9, 3.4, 1], ["punk", 4.8, 3.1, 2], ["goth", 1.7, 2.5, 3]]

# the bar (JS levels/club/level.js: the counter is x 10.0..10.9, z -2.6..8.4, its top at 1.1; the back bar's cabinet x 11.9..12.4; taps at z 0.3, 3.7, 6.9)
const BAR_X := 11.35          # where the bartender works, on the duckboard
const BOARD_Y := 0.24         # the duckboard: a short alien reaches the 1.1 m counter from it
const TOP_Y := 1.1
const LIP_X := 10.04          # a glass slid to the customer's side
const SET_X := 10.5           # a glass being made
## The bartender's routine, round and round: job, seconds (walks: 0, timed by distance), where along the bar.
const ROUTINE := [
	[&"walk", 0.0, 1.0], [&"shake", 2.4, 1.0], [&"pour", 1.5, 1.0], [&"slide", 0.8, 1.0],
	[&"walk", 0.0, 3.76], [&"tap", 2.2, 3.76], [&"slide", 0.8, 3.76],
	[&"back", 0.45, 3.76], [&"reach", 1.3, 3.76], [&"front", 0.45, 3.76],
	[&"walk", 0.0, 2.4], [&"flair", 2.2, 2.4], [&"pour", 1.4, 2.4], [&"slide", 0.8, 2.4],
	[&"wipe", 3.4, -0.4],
]
const SPOUT := Vector3(0.0, 0.17, 0.0)
## Ordering (levels/club/bar_order.gd): he steps up to the counter, brings the drinks pad (bar_pad.gd) up from under it and holds it out to Prog at his eye line.
const HOLD_X := BAR_X         # where he holds it out from: his own spot on the duckboard (stepping up to 11.0 put his belly through the counter, which ends at 10.9)
const PAD_SIDE := 0.12        # his left hand holds the pad this far along the bar (+z) from his middle: he stands that much to his right of where it goes
const TAPS: Array[float] = [0.3, 3.7, 6.9]      # the beer towers on the counter (z): the pad is never held out inside one
const TAP_CLEAR := 0.42
const PAD_TILT := 0.4         # the pad's face tipped up toward the customer (rad): held up and angled, it hides his face from the camera that lands on it
## His left arm for the pad: down under the counter to held out over it. [shoulder x, shoulder z, spine, elbow, hand x]
const PAD_LOW := [-0.45, 0.05, 0.3, -1.1, 0.3]
const PAD_UP := [-1.8, 0.4, 0.34, -0.3, 0.1]

var skins: Array[FolkSkin] = []
var aliens: Array[GrayAlienNpc] = []
var bartender: GrayAlienNpc
var flirt_alien: GrayAlienNpc
var sick: GrayAlienNpc
var _time := 0.0
var _rng := RandomNumberGenerator.new()
# the bartender's props and work
var _shaker: Node3D
var _bottle: Node3D
var _rag: MeshInstance3D
var _stream: MeshInstance3D
var _glasses: Array[Node3D] = []        # the bar's glasses in play (oldest reused first)
var _gi := 0
var _jobs: Array = []                   # what he does next: [job, seconds, z, drink]
var _job: Array = []
var _jt := 0.0                          # seconds into the job
var _bz := 1.0                          # where he stands along the bar
var _byaw := -PI / 2.0                  # facing the customers (-x)
var _ri := 0                            # place in the routine
var _cur_glass: Node3D = null
var _held := &""                        # what is in his right hand: shaker / bottle / ""
var _bx := BAR_X                        # how far he is from the back bar (he steps up to the counter to hold the pad out)
var pad: BarPad                         # the drinks pad, under the counter until Prog orders
var _pad_hold := Transform3D()          # where it stays while held out (fixed, so the 2D menu lands on it exactly)
var _hand_scl := Vector3.ONE            # his left hand's own scale (the painted hand on the pad stands in for it while he holds it)
# the sick one
var _heave_t := 3.0                     # seconds to his next heave
var _heave_u := 0.0                     # through it (0 = not heaving)
var _heave := 0.0                       # how hard, 0..1


func build() -> void:
	name = "ClubCrowd"
	_rng.seed = 9
	_build_floor()
	for i in ALIENS.size():
		var a: Array = ALIENS[i]
		_add_alien(a[0], Vector3(a[1], 0.0, a[2]), _face(Vector2(a[1], a[2]), DJ), a[3])
	_build_bar()
	_build_flirt()
	_build_sick()
	tick(0.0, 0.0)


func _face(at: Vector2, to: Vector2) -> float:
	return atan2(to.x - at.x, to.y - at.y)


# ---- the dance floor -------------------------------------------------------------------------------------------------------------------------------------------

func _build_floor() -> void:
	var by_species := {}
	for e: Array in FLOOR:
		if not by_species.has(e[0]):
			by_species[e[0]] = []
		by_species[e[0]].append(e)
	for sid: String in by_species:
		if not FolkSkin.available(sid):
			push_error("CLUB 9: missing city goth " + sid)
			continue
		var dance := ClubDance.new(sid)
		var skin := FolkSkin.make(sid, self, dance.sample, ClubDance.phrase_seconds(), ClubDance.rows())
		skins.append(skin)
		var list: Array = by_species[sid]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = skin.mesh
		mm.instance_count = list.size()
		for i in list.size():
			var e: Array = list[i]
			var at := Vector2(e[1], e[2])
			var yaw := _face(at, e[3]) + _rng.randf_range(-0.12, 0.12)      # (the folk models face +z: a yaw turns them to face its direction)
			var y: float = e[7] if e.size() > 7 else 0.0
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, y, at.y)))
			mm.set_instance_color(i, Color(0.0, e[5], e[6], 1.0))
			mm.set_instance_custom_data(i, Color(0.0, 0.0, float(e[4]) * BEAT, 0.0))
			if y == 0.0:
				_body(at, 0.3)      # (a caged dancer is inside the cage's own solid)
		var mi := MultiMeshInstance3D.new()
		mi.name = "Dancers_" + sid
		mi.multimesh = mm
		mi.material_override = skin.material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1.0
		add_child(mi)


## Someone standing here: the player walks round them, the camera does not mind them.
func _body(at: Vector2, r: float) -> void:
	Game.world.add({"kind": "disc", "cx": at.x, "cz": at.y, "r": r, "top": 1.8, "tag": "npc", "no_cam": true})


func _add_alien(outfit: String, at: Vector3, yaw: float, style: int) -> GrayAlienNpc:
	var a := GrayAlienNpc.new({"green": true, "outfit": outfit})
	a.name = "GreenAlien%d_%s" % [style, outfit]
	a.view.gun_hidden = true
	a.place(at.x, at.y, at.z, yaw)
	a.view.post_hook = _alien_dance.bind(a, style)
	add_child(a)
	aliens.append(a)
	if style >= 0:
		_body(Vector2(at.x, at.z), 0.3)
	return a


## On the beat: 1 on it, 0 between.
static func _hit(b: float) -> float:
	return pow(0.5 + 0.5 * cos(TAU * b), 2.0)


## The aliens' dances on their own rigs (joint angles, the JS rig's axes: x pitches a limb forward/up with negative values, z swings an arm out). Each changes move every 8 beats.
func _alien_dance(a: GrayAlienNpc, style: int) -> void:
	var v := a.view
	var q := v.pose
	var b := _time * ClubLevel.BEAT_HZ + style * 3.0
	var move := (style + int(floorf(b / 8.0))) % 4
	var hit := _hit(b)
	var sw := sin(PI * b)
	var s2 := sin(PI * b / 2.0)
	# the bounce every move shares: knees give on the beat, hips sway, head nods
	q.pos[v.j_hips] += Vector3(0.03 * s2, -0.02 - 0.035 * hit, 0.0)
	q.euler(v.j_hips, 0.03 * hit, 0.12 * s2, 0.05 * s2)
	q.euler(v.j_spine, 0.1 * hit, -0.14 * s2, -0.05 * s2)
	q.euler(v.j_head, -0.1 + 0.22 * hit, 0.18 * sin(PI * b / 4.0), 0.06 * s2)
	q.euler(v.j_th_l, -0.16 - 0.1 * hit, 0.0, 0.05)
	q.euler(v.j_th_r, -0.16 - 0.1 * hit, 0.0, -0.05)
	q.euler(v.j_kn_l, 0.32 + 0.2 * hit, 0.0, 0.0)
	q.euler(v.j_kn_r, 0.32 + 0.2 * hit, 0.0, 0.0)
	q.euler(v.j_ank_l, -0.16 - 0.1 * hit, 0.0, 0.0)
	q.euler(v.j_ank_r, -0.16 - 0.1 * hit, 0.0, 0.0)
	match move:
		0:      # fist pump: the right fist punches up on the beat, the left guards
			var p := pow(0.5 + 0.5 * cos(TAU * b), 1.5)
			q.euler(v.j_sh_r, lerpf(-1.0, -2.7, p), 0.0, -0.25)
			q.euler(v.j_el_r, lerpf(-1.3, -0.25, p), 0.0, 0.0)
			q.euler(v.j_sh_l, -0.7, 0.0, 0.35)
			q.euler(v.j_el_l, -1.45 + 0.15 * hit, 0.0, 0.0)
		1:      # both arms up, waving together side to side
			q.euler(v.j_sh_l, -2.5 + 0.15 * hit, 0.2 * s2, 0.45 + 0.3 * s2)
			q.euler(v.j_sh_r, -2.5 + 0.15 * hit, 0.2 * s2, -0.45 + 0.3 * s2)
			q.euler(v.j_el_l, -0.45, 0.0, 0.0)
			q.euler(v.j_el_r, -0.45, 0.0, 0.0)
			q.euler(v.j_hd_l, 0.0, 0.0, 0.4 * s2)
			q.euler(v.j_hd_r, 0.0, 0.0, 0.4 * s2)
		2:      # the march: bent arms swing against the stamping feet
			var lift_l := pow(maxf(0.0, sin(PI * b)), 2.0)
			var lift_r := pow(maxf(0.0, -sin(PI * b)), 2.0)
			q.euler(v.j_th_l, -0.16 - 0.75 * lift_l, 0.0, 0.05)
			q.euler(v.j_kn_l, 0.32 + 1.0 * lift_l, 0.0, 0.0)
			q.euler(v.j_th_r, -0.16 - 0.75 * lift_r, 0.0, -0.05)
			q.euler(v.j_kn_r, 0.32 + 1.0 * lift_r, 0.0, 0.0)
			q.euler(v.j_sh_l, -0.6 - 0.55 * sw, 0.0, 0.3)
			q.euler(v.j_sh_r, -0.6 + 0.55 * sw, 0.0, -0.3)
			q.euler(v.j_el_l, -1.5, 0.0, 0.0)
			q.euler(v.j_el_r, -1.5, 0.0, 0.0)
		3:      # clap on two and four, stepping side to side
			var clap := pow(maxf(0.0, cos(PI * (b - 1.0))), 6.0)
			q.euler(v.j_sh_l, -1.25, 0.0, 0.75 - 0.6 * clap)
			q.euler(v.j_sh_r, -1.25, 0.0, -0.75 + 0.6 * clap)
			q.euler(v.j_el_l, -0.9, 0.0, 0.0)
			q.euler(v.j_el_r, -0.9, 0.0, 0.0)
			q.pos[v.j_hips] += Vector3(0.05 * s2, 0.0, 0.0)


# ---- the bar ---------------------------------------------------------------------------------------------------------------------------------------------------

func _build_bar() -> void:
	BarGlass.warm(BarMenu.colors())
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color.hex(0x17131fff)
	rubber.roughness = 0.95
	var board := MeshInstance3D.new()      # a duckboard the length of the bar (was a 1.4 m step under one spot)
	board.name = "BarDuckboard"
	var box := BoxMesh.new()
	box.size = Vector3(0.9, BOARD_Y, 10.6)
	board.mesh = box
	board.material_override = rubber
	board.position = Vector3(11.4, BOARD_Y * 0.5, 2.9)
	add_child(board)
	Game.world.box(11.4, 2.9, 0.9, 10.6, BOARD_Y, {"bottom": 0.0, "tag": "furn"})
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color.hex(0xaeb6c5ff)
	steel.metallic = 0.85
	steel.roughness = 0.28
	_shaker = Node3D.new()
	_shaker.name = "CocktailShaker"
	add_child(_shaker)
	for i in 2:
		var cylinder := CylinderMesh.new()
		cylinder.bottom_radius = 0.043 if i == 0 else 0.044
		cylinder.top_radius = 0.052 if i == 0 else 0.025
		cylinder.height = 0.17 if i == 0 else 0.055
		cylinder.radial_segments = 12
		var part := MeshInstance3D.new()
		part.mesh = cylinder
		part.material_override = steel
		part.position.y = 0.0 if i == 0 else 0.1125
		_shaker.add_child(part)
	var bottle_m := StandardMaterial3D.new()
	bottle_m.albedo_color = Color(0.2, 0.75, 0.35, 0.75)
	bottle_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bottle_m.roughness = 0.08
	bottle_m.metallic = 0.3
	_bottle = Node3D.new()
	_bottle.name = "Bottle"
	add_child(_bottle)
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.036
	bm.bottom_radius = 0.036
	bm.height = 0.2
	bm.radial_segments = 10
	body.mesh = bm
	body.material_override = bottle_m
	body.position.y = 0.0
	_bottle.add_child(body)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.013
	nm.bottom_radius = 0.03
	nm.height = 0.11
	nm.radial_segments = 8
	neck.mesh = nm
	neck.material_override = bottle_m
	neck.position.y = 0.155
	_bottle.add_child(neck)
	_bottle.visible = false
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color.hex(0x8a1f33ff)
	cloth.roughness = 1.0
	_rag = MeshInstance3D.new()
	_rag.name = "Rag"
	var rb := BoxMesh.new()
	rb.size = Vector3(0.16, 0.02, 0.12)
	_rag.mesh = rb
	_rag.material_override = cloth
	add_child(_rag)
	_stream = MeshInstance3D.new()
	_stream.name = "PourStream"
	var sm := CylinderMesh.new()
	sm.top_radius = 0.006
	sm.bottom_radius = 0.004
	sm.height = 1.0
	sm.radial_segments = 6
	_stream.mesh = sm
	_stream.material_override = BarGlass.liquid(0x6dff4a)
	_stream.visible = false
	add_child(_stream)
	for k: String in ["coupe", "pint", "tumbler"]:
		var g := BarGlass.make(k, int(BarMenu.DRINKS[_rng.randi() % BarMenu.DRINKS.size()]["color"]))
		g.visible = false
		add_child(g)
		_glasses.append(g)
	bartender = _add_alien("goth", Vector3(BAR_X, BOARD_Y, _bz), _byaw, -1)
	bartender.name = "GreenAlienBartender"
	bartender.view.post_hook = _bartender_pose.bind(bartender)
	_hand_scl = bartender.view.pose.scl[bartender.view.j_hd_l]
	pad = BarPad.new()
	pad.visible = false
	add_child(pad)
	# a drink in front of each regular further down, already poured
	for e: Array in [["tumbler", 0xe8a530, 10.08, 4.3], ["pint", 0x3a0b1e, 10.12, 6.4], ["shot", 0x6dff4a, 10.1, 6.55]]:
		var g := BarGlass.make(e[0], e[1])
		g.position = Vector3(e[2], TOP_Y, e[3])
		add_child(g)


## Prog ordered: the bartender drops what he is doing, comes over, pours it and slides it to him; he takes it (player/drunk.gd) when it arrives. (Ordered off the pad: it goes back under the counter first.)
func serve(d: Dictionary) -> void:
	var z := clampf(Game.player.z, -2.2, 8.0)
	_jobs = [[&"walk", 0.0, z, d], [&"pour", 1.4, z, d], [&"slide", 0.7, z, d], [&"give", 0.2, z, d]]
	if pad_out():
		_jobs.push_front([&"stow", 0.6, _bz, {}])
	_next_job()


## X at the bar (bar_order.gd): he puts down what he has, comes over, and brings the pad up from under the counter to hold it out; he holds it until release().
func summon() -> void:
	var pz := clampf(Game.player.z, -2.2, 8.0)      # where the pad goes: in front of the customer, clear of the taps
	for tz: float in TAPS:
		if absf(pz - tz) < TAP_CLEAR:
			pz = tz + (TAP_CLEAR if pz >= tz else -TAP_CLEAR)
	var z := pz - PAD_SIDE
	_jobs = [[&"come", 0.0, z, {}], [&"lift", 1.35, z, {}], [&"hold", 1e9, z, {}]]
	_next_job()


## The menu closed without an order: the pad goes back under the counter and he gets back to work.
func release() -> void:
	if pad_out():
		_jobs = [[&"stow", 0.6, _bz, {}]]
		_next_job()


func pad_out() -> bool:
	return not _job.is_empty() and _job[0] in [&"come", &"lift", &"hold"]


## what he is doing with the pad: come / lift / hold / stow, or "" (back at work)
func pad_job() -> StringName:
	return _job[0] if not _job.is_empty() and _job[0] in [&"come", &"lift", &"hold", &"stow"] else &""


## how far through that (0..1)
func pad_u() -> float:
	return clampf(_jt / maxf(float(_job[1]), 0.01), 0.0, 1.0) if not _job.is_empty() else 1.0


## the pad held out: its face toward the customer (-x), tipped up a little
static func pad_basis() -> Basis:
	return Basis(Vector3.UP, -PI / 2.0) * Basis(Vector3.RIGHT, -PAD_TILT)


func _next_job() -> void:
	if _jobs.is_empty():
		var r: Array = ROUTINE[_ri]
		_ri = (_ri + 1) % ROUTINE.size()
		_jobs.append([r[0], r[1], r[2], {}])
	_job = _jobs.pop_front()
	_jt = 0.0
	var kind: StringName = _job[0]
	var d: Dictionary = _job[3]
	match kind:
		&"walk":
			_job[1] = maxf(0.25, absf(float(_job[2]) - _bz) / 1.3)
		&"come":       # quicker than his rounds: a customer is waiting
			_job[1] = maxf(0.75, absf(float(_job[2]) - _bz) / 2.4)      # (at least long enough to turn round from the back bar)
			_held = &""
		&"wipe":
			_job[1] = maxf(1.6, absf(float(_job[2]) - _bz) / 0.9)
		&"shake":
			_held = &"shaker"
		&"tap":
			_cur_glass = _take_glass("pint", 0xe8a530)
			_held = &""
		&"reach":
			_held = &""
		&"flair":
			_held = &"bottle"
		&"pour":
			if not d.is_empty():
				_held = &"bottle"
				_cur_glass = _take_glass(String(d["glass"]), int(d["color"]))
			else:
				_cur_glass = _take_glass("coupe" if _held == &"shaker" else "tumbler", int(BarMenu.DRINKS[_rng.randi() % 5]["color"]))
			if _cur_glass != null:
				_cur_glass.position = Vector3(SET_X, TOP_Y, _bz - 0.12)
				BarGlass.set_fill(_cur_glass, 0.0)
		&"give":
			if _cur_glass != null:
				_cur_glass.visible = false      # Prog has it now
			if Game.player != null and absf(Game.player.x - 9.2) < 2.0:
				Game.player.yaw = PI / 2.0      # he turns to the bar to take it
			Game.drunk.drink(d)
			_cur_glass = null


## A glass for the drink being made: the oldest on the bar, filled with this one.
func _take_glass(kind: String, c: int) -> Node3D:
	var g := _glasses[_gi]
	_gi = (_gi + 1) % _glasses.size()
	if not g.name.ends_with(kind) or g.get_meta(&"c", -1) != c:
		var at := g.get_index()
		g.queue_free()
		g = BarGlass.make(kind, c)
		g.set_meta(&"c", c)
		add_child(g)
		move_child(g, at)
		_glasses[(_gi - 1 + _glasses.size()) % _glasses.size()] = g
	g.visible = true
	return g


func _bar_tick(dt: float) -> void:
	if _job.is_empty():
		_next_job()
	_jt += dt
	var kind: StringName = _job[0]
	var dur: float = _job[1]
	var u := clampf(_jt / maxf(dur, 0.01), 0.0, 1.0)
	match kind:
		&"walk", &"wipe", &"come":
			if _job.size() < 6:
				_job.append(_bz)      # (where the walk started)
				_job.append(_bx)
				_job.append(_byaw)
			_bz = lerpf(float(_job[4]), float(_job[2]), Gait.sstep(0.0, 1.0, u))
			if kind == &"come":
				_bx = lerpf(float(_job[5]), HOLD_X, Gait.sstep(0.0, 1.0, u))
				# called while facing the back bar (a bottle off the shelf): he turns round to the customer on the way, so the pad comes out in front of him
				_byaw = lerp_angle(float(_job[6]), -PI / 2.0, Gait.sstep(0.0, 0.6, u))
		&"stow":
			_bx = lerpf(HOLD_X, BAR_X, Gait.sstep(0.3, 1.0, u))
		&"back":
			_byaw = lerpf(-PI / 2.0, PI / 2.0, Gait.sstep(0.0, 1.0, u))
		&"front":
			_byaw = lerpf(PI / 2.0, -PI / 2.0 + TAU, Gait.sstep(0.0, 1.0, u))
			if u >= 1.0:
				_byaw = -PI / 2.0
		&"pour":
			if _cur_glass != null:
				BarGlass.set_fill(_cur_glass, Gait.sstep(0.25, 0.85, u))
		&"tap":
			if _cur_glass != null:
				BarGlass.set_fill(_cur_glass, Gait.sstep(0.3, 0.9, u))
		&"slide":
			if _cur_glass != null:
				_cur_glass.position.x = lerpf(SET_X, LIP_X, Gait.sstep(0.15, 0.9, u))
		&"reach":
			if u > 0.55:
				_held = &"bottle"
	bartender.place(_bx, BOARD_Y, _bz, _byaw)
	if _jt >= dur:
		if kind == &"slide" and _job[3].is_empty():
			_held = &""      # (the shaker goes back on the mat between drinks)
		_next_job()


## The bartender's arms for the job in hand, over his own idle (he faces the customers, so his "forward" is over the counter).
func _bartender_pose(a: GrayAlienNpc) -> void:
	var v := a.view
	var q := v.pose
	if _job.is_empty():
		return
	var kind: StringName = _job[0]
	var u := clampf(_jt / maxf(float(_job[1]), 0.01), 0.0, 1.0)
	var t := _time
	q.euler(v.j_spine, 0.1, 0.0, 0.0)
	q.euler(v.j_head, 0.05, 0.0, 0.0)
	# the pad's painted hand stands in for his own while he has it out
	q.scl[v.j_hd_l] = _hand_scl * 0.05 if pad.visible else _hand_scl
	match kind:
		&"come":        # over to the customer, his left hand going down under the counter for the pad
			var ph := _jt * 11.0
			var r := Gait.sstep(0.4, 1.0, u)
			q.euler(v.j_th_l, -0.3 * sin(ph), 0.0, 0.05)
			q.euler(v.j_th_r, 0.3 * sin(ph), 0.0, -0.05)
			q.euler(v.j_kn_l, 0.35 * maxf(0.0, sin(ph)), 0.0, 0.0)
			q.euler(v.j_kn_r, 0.35 * maxf(0.0, -sin(ph)), 0.0, 0.0)
			q.euler(v.j_sh_r, -0.4, 0.0, -0.2)
			q.euler(v.j_el_r, -0.5, 0.0, 0.0)
			_pad_arm(v, 0.0, r)
			q.euler(v.j_spine, lerpf(0.1, PAD_LOW[2], r), 0.0, 0.0)
			q.euler(v.j_head, 0.15, 0.0, 0.0)
		&"lift", &"hold", &"stow":
			var up := 1.0
			if kind == &"lift":
				up = u
			elif kind == &"stow":
				up = 1.0 - Gait.sstep(0.0, 0.7, u)
			_pad_arm(v, up, 1.0)
			var s := Gait.sstep(0.0, 1.0, up)
			q.euler(v.j_spine, lerpf(PAD_LOW[2], PAD_UP[2], s), 0.0, 0.0)
			q.euler(v.j_head, lerpf(0.15, 0.02, s) + 0.015 * sin(t * 1.7), 0.0, 0.0)      # (eyes on the customer)
			q.euler(v.j_sh_r, -0.35, 0.0, -0.25)
			q.euler(v.j_el_r, -0.6, 0.0, 0.0)
		&"walk", &"back", &"front":
			var ph := _jt * 9.0
			q.euler(v.j_th_l, -0.35 * sin(ph), 0.0, 0.05)
			q.euler(v.j_th_r, 0.35 * sin(ph), 0.0, -0.05)
			q.euler(v.j_kn_l, 0.4 * maxf(0.0, sin(ph)), 0.0, 0.0)
			q.euler(v.j_kn_r, 0.4 * maxf(0.0, -sin(ph)), 0.0, 0.0)
			q.euler(v.j_sh_l, -0.4, 0.0, 0.2)
			q.euler(v.j_sh_r, -0.9 if _held != &"" else -0.4, 0.0, -0.2)
			q.euler(v.j_el_l, -0.5, 0.0, 0.0)
			q.euler(v.j_el_r, -1.2 if _held != &"" else -0.5, 0.0, 0.0)
		&"shake":       # the shaker at his shoulder, rattling hard; the other hand braces the counter
			var k := sin(t * TAU * 5.5)
			q.euler(v.j_sh_r, -1.8 + 0.22 * k, 0.0, -0.35)
			q.euler(v.j_el_r, -1.5 + 0.3 * k, 0.0, 0.0)
			q.euler(v.j_hd_r, 0.25 * k, 0.0, 0.0)
			q.euler(v.j_sh_l, -1.15, 0.0, 0.2)
			q.euler(v.j_el_l, -0.5, 0.0, 0.0)
			q.euler(v.j_head, -0.05, 0.25, 0.08 * k)
			q.pos[v.j_hips] += Vector3(0.0, -0.01 * absf(k), 0.0)
		&"pour":        # over the glass, tipping the shaker or bottle
			var tip := Gait.sstep(0.0, 0.25, u) * (1.0 - Gait.sstep(0.88, 1.0, u))
			q.euler(v.j_sh_r, -1.45, 0.0, -0.05)
			q.euler(v.j_el_r, -0.75, 0.0, 0.0)
			q.euler(v.j_hd_r, -1.3 * tip, 0.0, 0.0)
			q.euler(v.j_sh_l, -1.0, 0.0, 0.35)
			q.euler(v.j_el_l, -0.9, 0.0, 0.0)
			q.euler(v.j_head, 0.25, 0.0, 0.0)
		&"slide":       # the glass pushed across to the customer
			var p := Gait.sstep(0.1, 0.9, u)
			q.euler(v.j_sh_l, lerpf(-1.05, -1.5, p), 0.0, 0.05)
			q.euler(v.j_el_l, lerpf(-1.0, -0.15, p), 0.0, 0.0)
			q.euler(v.j_sh_r, -0.5, 0.0, -0.2)
			q.euler(v.j_el_r, -1.1 if _held != &"" else -0.5, 0.0, 0.0)
			q.euler(v.j_spine, 0.1 + 0.15 * p, 0.0, 0.0)
		&"tap":         # a pint under the tap in one hand, the handle pulled down with the other
			var pull := Gait.sstep(0.1, 0.3, u) * (1.0 - Gait.sstep(0.85, 1.0, u))
			q.euler(v.j_sh_r, lerpf(-2.0, -1.55, pull), 0.0, -0.1)
			q.euler(v.j_el_r, -0.6, 0.0, 0.0)
			q.euler(v.j_sh_l, -1.2, 0.0, 0.25)
			q.euler(v.j_el_l, -1.0, 0.0, 0.0)
			q.euler(v.j_head, 0.3, 0.0, 0.0)
		&"reach":       # up to the top shelf for a bottle, on his toes
			var r := sin(PI * u)
			q.euler(v.j_sh_r, lerpf(-0.5, -2.6, r), 0.0, -0.15)
			q.euler(v.j_el_r, lerpf(-0.6, -0.15, r), 0.0, 0.0)
			q.euler(v.j_head, -0.35 * r, 0.0, 0.0)
			q.pos[v.j_hips] += Vector3(0.0, 0.04 * r, 0.0)
		&"flair":       # the bottle goes up spinning and comes down in his hand
			var air := Gait.sstep(0.2, 0.3, u) * (1.0 - Gait.sstep(0.7, 0.8, u))
			q.euler(v.j_sh_r, lerpf(-1.1, -1.6, air), 0.0, -0.3)
			q.euler(v.j_el_r, lerpf(-1.3, -0.6, air), 0.0, 0.0)
			q.euler(v.j_head, -0.4 * air, 0.0, 0.0)
			q.euler(v.j_sh_l, -0.8, 0.0, 0.5)
			q.euler(v.j_el_l, -1.2, 0.0, 0.0)
		&"wipe":        # the rag round in circles as he works his way down the bar
			var w := t * 7.0
			q.euler(v.j_sh_l, -1.2 + 0.12 * sin(w), 0.0, 0.25 + 0.2 * cos(w))
			q.euler(v.j_el_l, -0.55, 0.0, 0.0)
			q.euler(v.j_sh_r, -0.3, 0.0, -0.35)
			q.euler(v.j_el_r, -1.2, 0.0, 0.0)
			q.euler(v.j_spine, 0.22, 0.12 * sin(w), 0.0)
			q.euler(v.j_head, 0.3, 0.0, 0.0)


## His left arm for the pad (the painted hand is a left hand: its thumb is on his far side): down under the counter (up 0) to held out over it (up 1); w blends that in
## over his walking arm. (The shoulder's z swing is the right arm's mirrored.)
func _pad_arm(v: AlienView, up: float, w: float) -> void:
	var q := v.pose
	var s := Gait.sstep(0.0, 1.0, up)
	q.euler(v.j_sh_l, lerpf(-0.4, lerpf(PAD_LOW[0], PAD_UP[0], s), w), 0.0, lerpf(0.2, -lerpf(PAD_LOW[1], PAD_UP[1], s), w))
	q.euler(v.j_el_l, lerpf(-0.5, lerpf(PAD_LOW[3], PAD_UP[3], s), w), 0.0, 0.0)
	q.euler(v.j_hd_l, lerpf(PAD_LOW[4], PAD_UP[4], s) * w, 0.0, 0.0)


## The pad rides his hand: lying flat as it comes up from under the counter, turning to face the customer as it rises; held still once it is out.
func _pad_prop(kind: StringName, u: float) -> void:
	pad.visible = kind in [&"lift", &"hold", &"stow"] and not (kind == &"stow" and u > 0.75)
	if not pad.visible:
		return
	if kind == &"hold":
		pad.global_transform = _pad_hold
		return
	var hr: Transform3D = bartender.view.pose.world[bartender.view.j_hd_l]
	var up := Gait.sstep(0.0, 1.0, u) if kind == &"lift" else 1.0 - Gait.sstep(0.0, 0.7, u)
	var flat := Basis(Vector3.UP, -PI / 2.0) * Basis(Vector3.RIGHT, -PI / 2.0)      # face up, top toward the customer
	var b := Basis(flat.get_rotation_quaternion().slerp(pad_basis().get_rotation_quaternion(), Gait.sstep(0.15, 1.0, up)))
	pad.global_transform = Transform3D(b, hr.origin - b * BarPad.WRIST)
	if kind == &"lift":
		_pad_hold = pad.global_transform      # (the last frame of the lift is where it is held)


## The props follow his hands after he is posed.
func _bar_props() -> void:
	var w := bartender.view.pose.world
	var hr: Transform3D = w[bartender.view.j_hd_r]
	var hl: Transform3D = w[bartender.view.j_hd_l]
	var kind: StringName = _job[0] if not _job.is_empty() else &""
	var u := clampf(_jt / maxf(float(_job[1]) if not _job.is_empty() else 1.0, 0.01), 0.0, 1.0)
	_pad_prop(kind, u)
	_shaker.visible = true
	if _held == &"shaker":
		_shaker.global_transform = Transform3D(hr.basis.orthonormalized(), hr.origin + hr.basis.orthonormalized() * Vector3(0.0, -0.04, 0.05))
	else:
		_shaker.global_transform = Transform3D(Basis.IDENTITY, Vector3(10.6, TOP_Y + 0.085, 1.45))      # on its mat
	_bottle.visible = _held == &"bottle"
	if _bottle.visible:
		var bt := Transform3D(hr.basis.orthonormalized(), hr.origin + hr.basis.orthonormalized() * Vector3(0.0, -0.02, 0.06))
		if kind == &"flair":
			var air := Gait.sstep(0.2, 0.3, u) * (1.0 - Gait.sstep(0.7, 0.8, u))
			var up := sin(PI * clampf((u - 0.2) / 0.6, 0.0, 1.0)) * 0.55
			bt = Transform3D(Basis(Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, _byaw), u * TAU * 2.0 * air) * bt.basis, bt.origin + Vector3(0.0, up, 0.0))
		_bottle.global_transform = bt
	_rag.visible = true
	if kind == &"wipe":
		_rag.global_transform = Transform3D(Basis(Vector3.UP, _byaw), Vector3(hl.origin.x, TOP_Y + 0.012, hl.origin.z))
	else:
		_rag.global_transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(10.7, TOP_Y + 0.012, 0.6))
	_stream.visible = false
	if kind == &"pour" and _cur_glass != null and u > 0.22 and u < 0.88:
		var src: Node3D = _shaker if _held == &"shaker" else _bottle
		var lip := src.global_transform * (SPOUT if _held == &"shaker" else Vector3(0.0, 0.21, 0.0))
		var dst := _cur_glass.global_position + Vector3(0.0, 0.03, 0.0)
		var d := lip.distance_to(dst)
		if d > 0.02:
			var dir := (dst - lip) / d
			var bx := dir.cross(Vector3.FORWARD).normalized() if absf(dir.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
			_stream.global_transform = Transform3D(Basis(bx, dir, bx.cross(dir)).scaled(Vector3(1.0, d, 1.0)), (lip + dst) * 0.5)
			var d2: Dictionary = _job[3]
			_stream.material_override = BarGlass.liquid(int(d2.get("color", 0xe8a530)) if not d2.is_empty() else 0x6dff4a)
			_stream.visible = true


## Is Prog at the bar? (CLUB 9's level answers Shops.near_bar with this.)
static func near_bar(p: Player) -> bool:
	return p.y < 0.6 and p.x > 8.3 and p.x < 9.98 and p.z > -2.5 and p.z < 8.3


# ---- the couple at the end of the bar ------------------------------------------------------------------------------------------------------------------------

func _build_flirt() -> void:
	if FolkSkin.available("snakeneck"):
		var dance := ClubDance.new("snakeneck", [ClubDance.FLIRT, ClubDance.FLIRT, ClubDance.FLIRT, ClubDance.FLIRT])
		var skin := FolkSkin.make("snakeneck", self, dance.sample, ClubDance.phrase_seconds() * 1.6, ClubDance.rows())
		skins.append(skin)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = skin.mesh
		mm.instance_count = 1
		# her left side to the counter, turned toward him on his stool up the bar
		mm.set_instance_transform(0, Transform3D(Basis(Vector3.UP, 0.25), Vector3(9.42, 0.0, -1.35)))
		mm.set_instance_color(0, Color(0.0, 0.85, 1.0, 1.0))
		mm.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
		var mi := MultiMeshInstance3D.new()
		mi.name = "BarFlirt_snakeneck"
		mi.multimesh = mm
		mi.material_override = skin.material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1.0
		add_child(mi)
		_body(Vector2(9.42, -1.35), 0.3)
	flirt_alien = _add_alien("punk", Vector3(9.35, 0.0, -0.4), PI - 0.15, -2)
	flirt_alien.name = "GreenAlienAtTheBar"
	flirt_alien.view.post_hook = _flirt_pose.bind(flirt_alien)
	_body(Vector2(9.35, -0.4), 0.3)
	for e: Array in [["coupe", 0xffc23a, 10.06, -1.2], ["tumbler", 0x38c8ff, 10.08, -0.55]]:
		var g := BarGlass.make(e[0], e[1])
		g.position = Vector3(e[2], TOP_Y, e[3])
		add_child(g)


## Him: up on the stool, side-on to the bar, an elbow on it, leaning in to her; talking with his free hand, then listening while she laughs.
func _flirt_pose(a: GrayAlienNpc) -> void:
	var v := a.view
	var q := v.pose
	var t := _time
	var turn := fmod(t, 7.0)
	var talking := turn < 4.2
	a.set_talk(talking)
	var g := sin(t * 3.1) * (1.0 if talking else 0.2)
	q.pos[v.j_hips] += Vector3(0.0, 0.2, -0.04)       # sat on the stool (seat 0.75)
	q.euler(v.j_hips, -0.05, 0.0, 0.0)
	q.euler(v.j_th_l, -1.45, 0.0, 0.12)
	q.euler(v.j_th_r, -1.45, 0.0, -0.12)
	q.euler(v.j_kn_l, 1.55, 0.0, 0.0)
	q.euler(v.j_kn_r, 1.3, 0.0, 0.0)
	q.euler(v.j_ank_l, -0.1, 0.0, 0.0)
	q.euler(v.j_ank_r, -0.25, 0.0, 0.0)
	q.euler(v.j_spine, 0.18 + 0.03 * sin(t * 0.8), 0.08, 0.16)       # leaning in, weight on the bar
	q.euler(v.j_head, -0.22 + 0.05 * sin(t * 1.3), -0.15 + 0.08 * sin(t * 0.6), -0.1 + (0.0 if talking else 0.08 * sin(t * 6.0) * 0.3))
	q.euler(v.j_sh_r, -0.55, 0.0, -1.05)       # elbow out on the counter
	q.euler(v.j_el_r, -1.35, 0.0, 0.0)
	q.euler(v.j_hd_r, 0.2, 0.0, 0.0)
	q.euler(v.j_sh_l, -0.9 + 0.12 * g, 0.15 * g, 0.25 + 0.1 * g)      # the talking hand
	q.euler(v.j_el_l, -1.25 + 0.2 * g, 0.0, 0.0)
	q.euler(v.j_hd_l, 0.2 * sin(t * 2.3), 0.0, 0.3 * g)


# ---- the sick one outside the men's room ----------------------------------------------------------------------------------------------------------------------

func _build_sick() -> void:
	sick = _add_alien("grunge", Vector3(13.45, 0.0, 10.42), 0.0, -3)      # the only grunge outfit in the club, and a party hat
	sick.name = "GreenAlienBeingSick"
	sick.view.post_hook = _sick_pose.bind(sick)
	_body(Vector2(13.45, 10.6), 0.32)
	var hat_m := StandardMaterial3D.new()
	hat_m.albedo_color = Color.hex(0xff2fb0ff)
	hat_m.roughness = 0.6
	hat_m.emission_enabled = true
	hat_m.emission = Color.hex(0xff2fb0ff)
	hat_m.emission_energy_multiplier = 0.25
	var hat := MeshInstance3D.new()
	hat.name = "PartyHat"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.07
	cone.height = 0.19
	cone.radial_segments = 12
	hat.mesh = cone
	hat.material_override = hat_m
	add_child(hat)
	sick.set_meta(&"hat", hat)
	var mess_m := StandardMaterial3D.new()      # wet, dark and a little too green
	mess_m.albedo_color = Color.hex(0x4f6a16ff)
	mess_m.roughness = 0.04
	mess_m.metallic = 0.15
	mess_m.emission_enabled = true
	mess_m.emission = Color.hex(0x1c2c06ff)
	mess_m.emission_energy_multiplier = 0.2
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.005
	disc.radial_segments = 14
	for e: Array in [[13.48, 11.0, 0.2, 0.7, 0.3], [13.64, 11.16, 0.12, 0.8, 1.2], [13.33, 11.13, 0.08, 0.9, 0.4], [13.56, 10.86, 0.07, 1.0, 0.0], [13.74, 11.3, 0.035, 1.0, 0.0]]:
		var mess := MeshInstance3D.new()
		mess.name = "Sick"
		mess.mesh = disc
		mess.material_override = mess_m
		mess.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mess.transform = Transform3D(Basis(Vector3.UP, e[4]).scaled(Vector3(e[2], 1.0, e[2] * e[3])), Vector3(e[0], 0.004, e[1]))
		add_child(mess)


## Sat on the floor against the wall, knees up, arms over them, head hung between; every few seconds he heaves.
func _sick_pose(a: GrayAlienNpc) -> void:
	var v := a.view
	var q := v.pose
	var t := _time
	var h := _heave
	var breath := sin(t * 2.2)
	q.pos[v.j_hips] += Vector3(0.0, -0.43, -0.06)
	q.euler(v.j_hips, -0.25, 0.0, 0.0)
	q.euler(v.j_th_l, -1.95, 0.0, 0.18)
	q.euler(v.j_th_r, -1.85, 0.0, -0.22)
	q.euler(v.j_kn_l, 2.05, 0.0, 0.0)
	q.euler(v.j_kn_r, 1.9, 0.0, 0.0)
	q.euler(v.j_ank_l, -0.2, 0.0, 0.0)
	q.euler(v.j_ank_r, -0.25, 0.0, 0.0)
	q.euler(v.j_spine, 0.95 + 0.03 * breath + 0.28 * h, 0.0, 0.06)
	q.euler(v.j_head, 0.7 + 0.35 * h + 0.04 * breath, 0.1 * sin(t * 0.4), 0.14)
	q.euler(v.j_sh_l, -0.45 - 0.3 * h, 0.0, 0.32)       # forearms over the knees
	q.euler(v.j_sh_r, -0.5 - 0.3 * h, 0.0, -0.36)
	q.euler(v.j_el_l, -1.35 + 0.2 * h, 0.0, 0.0)
	q.euler(v.j_el_r, -1.25 + 0.2 * h, 0.0, 0.0)
	q.euler(v.j_hd_l, 0.5, 0.0, -0.2)
	q.euler(v.j_hd_r, 0.6, 0.0, 0.2)
	var hat: MeshInstance3D = a.get_meta(&"hat")
	var hw: Transform3D = v.pose.world[v.j_head]
	var hb := hw.basis.orthonormalized()
	hat.global_transform = Transform3D(hb * Basis(Vector3(0.0, 0.0, 1.0), 0.35), hw.origin + hb * Vector3(0.07, 0.43, -0.03))      # (askew, on the top of that big head)


func _sick_tick(dt: float) -> void:
	_heave_t -= dt
	if _heave_t <= 0.0:
		_heave_t = _rng.randf_range(3.5, 7.0)
		_heave_u = 0.001
	if _heave_u > 0.0:
		_heave_u += dt / 0.9
		if _heave_u >= 1.0:
			_heave_u = 0.0
	_heave = sin(PI * _heave_u) if _heave_u > 0.0 else 0.0


# ---- the frame -------------------------------------------------------------------------------------------------------------------------------------------------

func tick(time: float, dt: float) -> void:
	_time = time
	for skin in skins:
		skin.material.set_shader_parameter(&"uTime", time)
	if bartender != null:
		_bar_tick(dt)
	if sick != null:
		_sick_tick(dt)
	for a in aliens:
		a.update(time, dt)
	if bartender != null:
		_bar_props()


func dispose() -> void:
	# Break the pose callbacks' references to their owner before the level frees the NPC nodes.
	for a in aliens:
		a.view.post_hook = Callable()
