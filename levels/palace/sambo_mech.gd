class_name SamboMech
extends Node3D
## SAMBO 2.0 (user, 2026-11-19: the replacement mech his rich parents drop; picked the "rich-kid luxury mech": white and gold, chrome, the family crest, his mannequin head on top). The model is
## assets/palace/sambo_mech.glb (tools/palace/build_palace_models.py: rigid parts on their pivots), delivered in assets/palace/drop_pod.glb. Here: the pod's fall and opening and the mech's
## power-up for the finale (levels/palace/palace_finale.gd), the head seated in the collar (Sambo's own SamboBody, the suit's head with the little alien in it, its robot legs tucked), and the
## boss fight on the top slab (levels/palace/palace_level.gd "boss"):
##   walk      it stalks Prog at 9-13 m, round the core; every step a thud
##   gatling   the right arm's gold gatling spins up (the muzzle glows), then sweeps a stream of rounds at him
##   stomp     a foot goes up, comes down: a ring of force runs out over the slab (jump it)
##   missiles  (from 60%) the shoulder pods open and fire; red rings mark where they land
##   slam      up close the gold fist comes down in front of it
##   charge    (under 30%) it runs at him; into the core and it staggers
## Its plating takes little (x0.12). After a stomp or a salvo, or a charge into the core, the chest doors swing open to vent and the CORE takes full damage for a few seconds; the dome over
## his head takes a little and makes him yelp. The chat is on Prog's side: donations come in as it breaks (they pay Prog). At zero it shakes itself apart and blows up (`destroyed`).

const MODEL := "res://assets/palace/sambo_mech.glb"
const POD := "res://assets/palace/drop_pod.glb"
const HP := 1600.0
const BIG := 1.0e7
const ARMOUR := 0.12
const DOME_K := 0.3
const POD_AT := Vector3(166.0, 30.0, 211.0)      # where the pod comes down: the top slab's north half, clear of the core
const START := Vector3(166.0, 30.0, 207.6)       # where the mech steps out to
const BOUNDS := Rect2(149.6, 185.6, 27.0, 31.0)  # the slab it keeps to (x, z, w, d)
const CORE_R := Rect2(156.4, 194.4, 13.2, 13.2)  # the core it walks round (with room)
const SPEED := 2.6
const TURN := 1.6
const GAT_WIND := 0.95
const GAT_FIRE := 2.3
const GAT_GAP := 0.075
const STOMP_WIND := 0.8
const RING_V := 13.0
const RING_MAX := 19.0
const RING_DMG := 14.0
const MISSILE_DMG := 16.0
const SLAM_DMG := 22.0
const CHARGE_DMG := 18.0
const VENT_T := 3.6

var lv: PalaceLevel
var mech: Node3D
var pod: Node3D
var P_ := {}                     # part name -> Node3D
var R_ := {}                     # part name -> its rest Transform3D (local)
var petals: Array[Node3D] = []
var cap: Node3D
var head: SamboBody = null
var legs: HeadLegs = null
var mode := &"off"               # off | pod | idle | fight | dying | dead
var destroyed := false
var x := START.x
var z := START.z
var y := START.y
var yaw := PI
var hp := HP
var phase := 1
var mv := &"walk"
var mv_t := 0.0
var cd := 2.0
var doors := 0.0
var vent := 0.0
var glow := 0.0
var flash := 0.0
var step_ph := 0.0
var speed := 0.0
var barrel_spin := 0.0
var lids := 0.0
var fist := 0.0
var stomp_lift := 0.0
var lean := 0.0
var dying_t := 0.0
var mercy := 0.0
var t_body: Target
var t_core: Target
var t_dome: Target
var solid: World.Solid = null
var _registered := false
var _glow_mats: Array[StandardMaterial3D] = []
var _glow_base: Array[float] = []
var _core_mats: Array[StandardMaterial3D] = []
var _ring: MeshInstance3D
var _ring_r := -1.0
var _ring_c := Vector3.ZERO
var _ring_hit := false
var _missiles: Array[Dictionary] = []      # {from, at, t, dur, node, mark}
var _miss_pool: Array[MeshInstance3D] = []
var _mark_pool: Array[MeshInstance3D] = []
var _gat_t := 0.0
var _gat_n := 0
var _aim := Vector3.ZERO
var _said := {}
var _say_t := 0.0
var _donated := 0
var _trail: MeshInstance3D
var _thud: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func setup(level: PalaceLevel) -> void:
	lv = level
	name = "SamboMech"
	_rng.seed = 2
	mech = (load(MODEL) as PackedScene).instantiate()
	add_child(mech)
	for n: Node in mech.find_children("*", "Node3D", true, false):
		P_[String(n.name)] = n
		R_[String(n.name)] = (n as Node3D).transform
	pod = (load(POD) as PackedScene).instantiate()
	add_child(pod)
	for i in 4:
		var p := pod.find_child("petal_%d" % (i + 1), true, false) as Node3D
		if p != null:
			petals.append(p)
			R_["petal_%d" % (i + 1)] = p.transform
	cap = pod.find_child("pod_cap", true, false) as Node3D
	if cap != null:
		R_["pod_cap"] = cap.transform
	# its lights and its core: own copies of their materials, so they can be dimmed and brought up
	for mi: Node in mech.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s) as StandardMaterial3D
			if src == null:
				continue
			var nm := src.resource_name
			if nm.contains("glow_warm") or nm.contains("core_glow"):
				var c := src.duplicate() as StandardMaterial3D
				m.set_surface_override_material(s, c)
				_glow_mats.append(c)
				_glow_base.append(c.emission_energy_multiplier)
				if nm.contains("core_glow"):
					_core_mats.append(c)
	t_body = Target.new(9300, x, z, y + 1.4, {"r": 1.15, "h": 2.9, "max": BIG, "hp": BIG, "boss": true, "heavy": true})
	t_core = Target.new(9301, x, z, y + 3.2, {"r": 0.55, "h": 0.9, "max": BIG, "hp": BIG, "boss": true})
	t_dome = Target.new(9302, x, z, y + 4.55, {"r": 0.5, "h": 0.75, "max": BIG, "hp": BIG, "boss": true})
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 64
	tm.ring_segments = 6
	_ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(1.0, 0.72, 0.25, 0.9)
	_ring.material_override = rm
	_ring.visible = false
	add_child(_ring)
	var tr := CylinderMesh.new()      # the pod's fire on the way down
	tr.top_radius = 0.0
	tr.bottom_radius = 1.0
	tr.height = 1.0
	tr.radial_segments = 12
	var trm := StandardMaterial3D.new()
	trm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	trm.albedo_color = Color(1.0, 0.5, 0.15, 0.85)
	trm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail = MeshInstance3D.new()
	_trail.mesh = tr
	_trail.material_override = trm
	_trail.visible = false
	add_child(_trail)
	_thud = AudioStreamPlayer3D.new()
	_thud.stream = Cutscene.synth(0.7, [[0.0, 0.5, 70.0, 32.0, &"sine", 0.6, 0.004], [0.0, 0.12, 180.0, 60.0, &"triangle", 0.25, 0.002]], [[0.0, 0.25, &"lowpass", 400.0, 120.0, 0.7, 0.35, 0.002]])
	_thud.bus = &"SFX"
	_thud.unit_size = 16.0
	add_child(_thud)
	for i in 10:
		var mm := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.12
		cm.height = 0.7
		mm.mesh = cm
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.95, 0.74, 0.3)
		gm.metallic = 1.0
		gm.roughness = 0.25
		gm.emission_enabled = true
		gm.emission = Color(1.0, 0.5, 0.15)
		gm.emission_energy_multiplier = 1.5
		mm.material_override = gm
		mm.visible = false
		add_child(mm)
		_miss_pool.append(mm)
		var mk := MeshInstance3D.new()
		var mt := TorusMesh.new()
		mt.inner_radius = 2.2
		mt.outer_radius = 2.6
		mt.rings = 40
		mt.ring_segments = 4
		mk.mesh = mt
		var mkm := StandardMaterial3D.new()
		mkm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mkm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mkm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mkm.albedo_color = Color(1.0, 0.1, 0.06, 0.8)
		mk.material_override = mkm
		mk.visible = false
		add_child(mk)
		_mark_pool.append(mk)
	_set_power(0.0)
	_show(false)


func _show(v: bool) -> void:
	mech.visible = v
	pod.visible = v


# ---------------------------------------------------------------------------------------------- the finale's beats

## The pod on its way down: f 0 high in the sky .. 1 on the slab
func pod_fall(f: float) -> void:
	mode = &"pod"
	_show(true)
	var hi := POD_AT + Vector3(-60.0, 260.0, 140.0)
	var at := hi.lerp(POD_AT, clampf(f, 0.0, 1.0))
	pod.global_transform = Transform3D(Basis(Vector3.UP, 0.4), at)
	_place_in_pod()
	_trail.visible = f < 1.0
	if _trail.visible:
		var back := (hi - POD_AT).normalized()
		_trail.global_transform = PalaceKit.span(at + back * 1.0, at + back * (12.0 + 30.0 * (1.0 - f)), 3.0, 3.0)


## The pod opens: the cap blows off, the petals fold down (u 0..1)
func pod_open(u: float) -> void:
	if cap != null:
		var c := Cutscene.seg(u, 0.0, 0.4)
		var rest: Transform3D = R_["pod_cap"]
		cap.transform = rest.translated(Vector3(0.0, c * 9.0 - c * c * 6.0, c * 3.0)).rotated_local(Vector3.RIGHT, c * 2.4)
		cap.visible = c < 0.98
	for i in petals.size():
		var rest: Transform3D = R_["petal_%d" % (i + 1)]
		var k := Cutscene.ease_out(Cutscene.seg(u, 0.18 + i * 0.04, 0.75 + i * 0.05))
		petals[i].transform = rest * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(100.0) * k), Vector3.ZERO)


func _place_in_pod() -> void:
	x = pod.global_position.x
	z = pod.global_position.z
	y = pod.global_position.y + 0.3
	yaw = pod.global_rotation.y + PI
	_pose_root()


## The mech's lights and core (0 dead .. 1 on)
func _set_power(u: float) -> void:
	glow = u
	for i in _glow_mats.size():
		_glow_mats[i].emission_energy_multiplier = _glow_base[i] * u * (1.0 + 0.6 * flash)


## The head, onto the collar: the suit's head with the little alien in it (Sambo's SamboBody, cut to its head), its legs tucked
func seat_head(sb: SamboBody, hl: HeadLegs) -> void:
	head = sb
	legs = hl
	head.split(&"head")


## Where the head sits: the collar's socket, world space (the neck stump on it)
func socket_xf() -> Transform3D:
	var s := P_.get("head_socket") as Node3D
	return s.global_transform if s != null else global_transform


## The head at the socket (its rest neck stump on the socket, facing the mech's way)
func head_to_socket(u: float = 1.0, from: Transform3D = Transform3D.IDENTITY) -> void:
	if head == null:
		return
	var sx := socket_xf()
	var b := Basis(Vector3.UP, yaw)
	var seated := Transform3D(b, sx.origin - b * Vector3(0.0, HeadLegs.HIP_Y - 0.02, 0.0))
	head.global_transform = from.interpolate_with(seated, u) if u < 1.0 else seated


# ---------------------------------------------------------------------------------------------- the fight

## The fight begins (the finale is over, or a checkpoint): out of the pod, powered, his head on
func begin(retry: bool) -> void:
	destroyed = false
	hp = HP
	phase = 1
	mv = &"walk"
	mv_t = 0.0
	cd = 2.2
	doors = 0.0
	vent = 0.0
	dying_t = 0.0
	_donated = 0
	_said.clear()
	_clear_missiles()
	_show(true)
	mech.visible = true
	if retry or mode != &"idle":
		pod.global_transform = Transform3D(Basis(Vector3.UP, 0.4), POD_AT)
		pod_open(1.0)
		x = START.x
		z = START.z
		y = START.y
		yaw = PI
		if head == null:
			var sb := lv.sambo.body
			var hl := HeadLegs.fit(sb)
			seat_head(sb, hl)
		lv.sambo.held = true
		if legs != null:
			legs.out = 1.0
			legs.tuck = 1.0
			legs.pose()
	_set_power(1.0)
	mode = &"fight"
	if solid == null:
		solid = lv.world.add({"kind": "disc", "cx": x, "cz": z, "r": 1.3, "bottom": y, "top": y + 4.6, "tag": "mech", "no_cam": true})
	solid.set_off(false)
	_register()
	_bar()


func _register() -> void:
	if _registered or Game.combat == null:
		return
	_registered = true
	for t: Target in [t_body, t_core, t_dome]:
		t.hp = BIG
		t.dead = false
		Game.combat.targets.append(t)


func _unregister() -> void:
	if not _registered or Game.combat == null:
		return
	_registered = false
	for t: Target in [t_body, t_core, t_dome]:
		Game.combat.targets.erase(t)


func _exit_tree() -> void:
	_unregister()


func _bar() -> void:
	if lv.bo != null:
		lv.bo.boss_bar({"name": "SAMBO 2.0", "f": hp / HP, "label": "CORE EXPOSED" if vent > 0.0 else ("PHASE %d" % phase), "hot": vent > 0.0})


func say(id: String) -> void:
	if lv.sambo.talking() or _say_t > 0.0:
		return
	_said[id] = int(_said.get(id, 0)) + 1
	_say_t = lv.sambo.say(id) + 1.5


func say_once(id: String) -> void:
	if not _said.has(id):
		say(id)


func tick(dt: float) -> void:
	if mode == &"off" or not mech.visible:
		return
	_say_t = maxf(0.0, _say_t - dt)
	flash = maxf(0.0, flash - dt * 4.0)
	if mode == &"fight":
		_fight(dt)
	elif mode == &"dying":
		_dying(dt)
	if mode == &"fight" or mode == &"dying" or mode == &"idle":
		_pose(dt)
		if head != null and mode != &"dead":
			head_to_socket()
			head.speed = 0.0
			head.update(dt)
			if legs != null:
				legs.pose()
	_missiles_tick(dt)
	_ring_tick(dt)


func _fight(dt: float) -> void:
	var P := Game.player
	if P == null:
		return
	mercy = maxf(0.0, mercy - dt)
	# damage in
	var body_d := BIG - t_body.hp
	var core_d := BIG - t_core.hp
	var dome_d := BIG - t_dome.hp
	for t: Target in [t_body, t_core, t_dome]:
		t.hp = BIG
		t.dead = false
	var dmg := body_d * ARMOUR + dome_d * DOME_K
	if core_d > 0.0:
		if doors > 0.6:
			dmg += core_d
			flash = 1.0
			if _rng.randf() < 0.25:
				say_once("s_mech_05")
		else:
			dmg += core_d * ARMOUR
	if dome_d > 0.0 and _rng.randf() < 0.3:
		say("s_mech_04")
	if body_d > 0.0 and _rng.randf() < 0.05:
		say("s_mech_04")
	if dmg > 0.0:
		hp = maxf(0.0, hp - dmg)
		flash = maxf(flash, 0.5)
		_donations()
		_bar()
	var f := hp / HP
	if phase == 1 and f < 0.6:
		phase = 2
		say("s_mech_08")
		lv.chat.add_viewers(30000.0)
	elif phase == 2 and f < 0.3:
		phase = 3
		say("s_mech_10")
		lv.chat.add_viewers(40000.0)
	if hp <= 0.0:
		_die()
		return
	vent = maxf(0.0, vent - dt)
	doors = move_toward(doors, 1.0 if vent > 0.0 else 0.0, dt * (3.0 if vent > 0.0 else 1.6))
	mv_t += dt
	var to_p := Vector2(P.x - x, P.z - z)
	var dist := to_p.length()
	var want := atan2(to_p.x, to_p.y)
	match mv:
		&"walk":
			cd -= dt
			var desired := 0.0
			if dist > 13.0:
				desired = 1.0
			elif dist < 8.0:
				desired = -0.6
			var d := Vector2(sin(yaw), cos(yaw))
			_turn_to(want, dt)
			speed = move_toward(speed, SPEED * desired, dt * 3.0)
			_walk(d * speed * dt + Vector2(cos(yaw), -sin(yaw)) * (0.8 * dt if dist < 12.0 else 0.0))
			if cd <= 0.0:
				_pick(dist)
		&"gatling":
			_turn_to(want, dt * 0.7)
			barrel_spin += dt * (6.0 + 30.0 * minf(1.0, mv_t / GAT_WIND))
			if mv_t > GAT_WIND and mv_t < GAT_WIND + GAT_FIRE:
				_gat_t -= dt
				while _gat_t <= 0.0:
					_gat_t += GAT_GAP * (0.8 if phase == 3 else 1.0)
					_fire_round(P)
				if not _said.has("s_mech_02") and mv_t > GAT_WIND + 0.5:
					say("s_mech_02")
			if mv_t > GAT_WIND + GAT_FIRE + 0.5:
				_end_move(1.4)
		&"stomp":
			stomp_lift = Cutscene.ease_(minf(1.0, mv_t / STOMP_WIND)) if mv_t < STOMP_WIND else maxf(0.0, 1.0 - (mv_t - STOMP_WIND) * 8.0)
			if mv_t >= STOMP_WIND and _ring_r < 0.0 and stomp_lift < 0.5:
				_stomp()
			if mv_t > STOMP_WIND + 1.4:
				vent = VENT_T
				_end_move(1.0)
		&"missiles":
			lids = move_toward(lids, 1.0, dt * 2.5)
			_turn_to(want, dt * 0.5)
			if mv_t > 0.6 and _gat_n == 0:
				_gat_n = 1
				_salvo(P)
			if mv_t > 3.4:
				lids = 0.0
				vent = VENT_T * 0.8
				_end_move(1.2)
		&"slam":
			fist = Cutscene.ease_(minf(1.0, mv_t / 0.65)) if mv_t < 0.65 else maxf(0.0, 1.0 - (mv_t - 0.65) * 6.0)
			_turn_to(want, dt * 1.2)
			if mv_t >= 0.65 and _gat_n == 0:
				_gat_n = 1
				_slam(P)
			if mv_t > 1.6:
				_end_move(1.0)
		&"charge":
			if mv_t < 0.7:
				_turn_to(want, dt * 2.0)
				lean = Cutscene.ease_(mv_t / 0.7) * 0.25
			else:
				var d2 := Vector2(sin(yaw), cos(yaw))
				speed = 9.0
				var before := Vector2(x, z)
				_walk(d2 * speed * dt)
				if Vector2(x, z).distance_to(before) < speed * dt * 0.3 or _in_core(Vector2(x, z) + d2 * 2.2):      # into the core (or stopped by the slab's edge): it staggers, the doors fly open
					lean = 0.0
					Game.fx.shake = maxf(Game.fx.shake, 0.4)
					_thud_at(Vector3(x, y, z))
					vent = VENT_T * 1.2
					_end_move(1.6)
				elif mercy <= 0.0 and Vector2(P.x - x, P.z - z).length() < 2.2 and absf(P.y - y) < 2.0:
					_hit(P, CHARGE_DMG, 9.0)
				if mv_t > 2.6:
					lean = 0.0
					_end_move(1.2)
	if _rng.randf() < dt * 0.05:
		say(["s_mech_01", "s_mech_03", "s_mech_06", "s_mech_07", "s_mech_09"][_rng.randi() % 5])
	_targets()
	if solid != null:
		solid.place(x, z)
	if phase >= 2 and _rng.randf() < dt * (1.5 if phase == 3 else 0.5):      # damaged: sparks from the joints
		Game.fx.sparks(Vector3(x, y + 2.5 + _rng.randf() * 1.5, z) + Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)), 6, 4.0, null, 0xffc060)


func _pick(dist: float) -> void:
	mv_t = 0.0
	_gat_n = 0
	_gat_t = 0.0
	var r := _rng.randf()
	if dist < 5.5:
		mv = &"slam"
	elif phase == 3 and r < 0.3:
		mv = &"charge"
	elif phase >= 2 and r < 0.6:
		mv = &"missiles"
	elif r < 0.55:
		mv = &"gatling"
	else:
		mv = &"stomp"
	speed = 0.0


func _end_move(rest: float) -> void:
	mv = &"walk"
	mv_t = 0.0
	cd = rest * (0.7 if phase == 3 else 1.0)
	stomp_lift = 0.0
	fist = 0.0


func _turn_to(want: float, dt: float) -> void:
	yaw += clampf(wrapf(want - yaw, -PI, PI), -TURN * dt, TURN * dt)


func _in_core(p: Vector2) -> bool:
	return CORE_R.has_point(p)


## A step on the slab: kept in bounds and out of the core (slides along it)
func _walk(d: Vector2) -> void:
	var p := Vector2(x, z) + d
	if _in_core(p):
		var px := Vector2(p.x, z)
		var pz := Vector2(x, p.y)
		p = px if not _in_core(px) else (pz if not _in_core(pz) else Vector2(x, z))
	p.x = clampf(p.x, BOUNDS.position.x, BOUNDS.end.x)
	p.y = clampf(p.y, BOUNDS.position.y, BOUNDS.end.y)
	var moved := p.distance_to(Vector2(x, z))
	x = p.x
	z = p.y
	var before := step_ph
	step_ph += moved / 1.8
	if floor(step_ph * 2.0) != floor(before * 2.0):      # a foot down
		_thud_at(Vector3(x, y, z))
		Game.fx.shake = maxf(Game.fx.shake, 0.06)


func _thud_at(p: Vector3) -> void:
	_thud.global_position = p
	_thud.pitch_scale = _rng.randf_range(0.85, 1.1)
	_thud.play()


func _muzzle() -> Vector3:
	var m := P_.get("muzzle_R") as Node3D
	return m.global_position if m != null else Vector3(x, y + 3.0, z)


## One round from the gatling: led a little ahead of him, sprayed, sweeping across
func _fire_round(P: Player) -> void:
	var from := _muzzle()
	var lead := Vector3(P.vx, 0.0, P.vz) * 0.25
	var sweep := Vector3(cos(yaw), 0.0, -sin(yaw)) * sin((mv_t - GAT_WIND) * 3.2) * 1.4
	var at := Vector3(P.x, P.y + 1.0, P.z) + lead + sweep + Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.3, 0.4), _rng.randf_range(-0.5, 0.5))
	var dir := (at - from).normalized()
	Game.enemies.fire_from(t_body.id, from.x, from.y, from.z, dir.x, dir.y, dir.z, {"kind": "bolt", "speed": 40.0, "dmg": 3.2, "r": 0.13})
	if _rng.randf() < 0.5:
		Game.fx.sparks(from, 2, 3.0, dir, 0xffd070)


## The stomp lands: a ring of force runs out over the slab from the foot
func _stomp() -> void:
	var foot := P_.get("foot_R") as Node3D
	_ring_c = foot.global_position if foot != null else Vector3(x, y, z)
	_ring_c.y = y + 0.05
	_ring_r = 0.5
	_ring_hit = false
	Game.fx.shake = maxf(Game.fx.shake, 0.6)
	Game.fx.dust(_ring_c, 26, 5.0)
	_thud_at(_ring_c)


func _ring_tick(dt: float) -> void:
	if _ring_r < 0.0:
		_ring.visible = false
		return
	_ring_r += RING_V * dt
	_ring.visible = true
	_ring.global_transform = Transform3D(Basis().scaled(Vector3(_ring_r, 0.6, _ring_r)), _ring_c)
	(_ring.material_override as StandardMaterial3D).albedo_color.a = 0.9 * (1.0 - _ring_r / RING_MAX)
	var P := Game.player
	if not _ring_hit and P != null and not P.dead and P.grounded and absf(P.y - _ring_c.y) < 0.8:
		var d := Vector2(P.x - _ring_c.x, P.z - _ring_c.z).length()
		if absf(d - _ring_r) < 0.7:
			_ring_hit = true
			_hit(P, RING_DMG, 6.0)
			if _rng.randf() < 0.5:
				say("s_mech_01")
	if _ring_r >= RING_MAX:
		_ring_r = -1.0


## Missiles: up out of the shoulder pods, then down on the marked spots round him
func _salvo(P: Player) -> void:
	var n := 6 if phase == 2 else 8
	for i in n:
		var a := TAU * i / n + _rng.randf() * 0.5
		var r := 0.0 if i == 0 else _rng.randf_range(2.5, 7.0)
		var at := Vector3(P.x + sin(a) * r, y + 0.05, P.z + cos(a) * r)
		at.x = clampf(at.x, BOUNDS.position.x + 1.0, BOUNDS.end.x - 1.0)
		at.z = clampf(at.z, BOUNDS.position.y + 1.0, BOUNDS.end.y - 1.0)
		var pod_n := P_.get("pod_L" if i % 2 == 0 else "pod_R") as Node3D
		var from := pod_n.global_position + Vector3(0.0, 0.5, 0.0) if pod_n != null else Vector3(x, y + 4.5, z)
		_missiles.append({"from": from, "at": at, "t": -i * 0.12, "dur": 1.9 + _rng.randf() * 0.4, "node": null, "mark": null})


func _missiles_tick(dt: float) -> void:
	var i := _missiles.size() - 1
	while i >= 0:
		var m: Dictionary = _missiles[i]
		m.t = float(m.t) + dt
		var tt: float = m.t
		if tt >= 0.0 and m.node == null:
			m.node = _take(_miss_pool)
			m.mark = _take(_mark_pool)
		var node: MeshInstance3D = m.node
		var mark: MeshInstance3D = m.mark
		if node != null:
			var u := clampf(tt / float(m.dur), 0.0, 1.0)
			var from: Vector3 = m.from
			var at: Vector3 = m.at
			var top := from + Vector3(0.0, 14.0, 0.0)
			var p := from.lerp(top, minf(1.0, u * 2.0)) if u < 0.5 else top.lerp(at, (u - 0.5) * 2.0)
			var ahead := from.lerp(top, minf(1.0, (u + 0.02) * 2.0)) if u + 0.02 < 0.5 else top.lerp(at, (u + 0.02 - 0.5) * 2.0)
			node.visible = true
			node.global_transform = PalaceKit.span(p, p + (ahead - p).normalized() * 0.7, 1.0, 1.0)
			if _rng.randf() < 0.5:
				Game.fx.sparks(p, 1, 1.5, null, 0xff9040)
			mark.visible = u > 0.35
			mark.global_transform = Transform3D(Basis().scaled(Vector3.ONE * (0.6 + 0.4 * sin(tt * 18.0) * 0.2)), at + Vector3(0.0, 0.06, 0.0))
			if u >= 1.0:
				Game.fx.explosion(at, 2.4)
				Game.fx.shake = maxf(Game.fx.shake, 0.35)
				var P := Game.player
				if P != null and not P.dead and Vector2(P.x - at.x, P.z - at.z).length() < 2.7 and absf(P.y - at.y) < 2.5:
					_hit(P, MISSILE_DMG, 5.0)
				node.visible = false
				mark.visible = false
				_missiles.remove_at(i)
		i -= 1


func _take(pool: Array[MeshInstance3D]) -> MeshInstance3D:
	for n in pool:
		if not n.visible:
			n.visible = true
			return n
	return null


func _clear_missiles() -> void:
	for m: Dictionary in _missiles:
		if m.node != null:
			(m.node as MeshInstance3D).visible = false
		if m.mark != null:
			(m.mark as MeshInstance3D).visible = false
	_missiles.clear()
	_ring_r = -1.0


## The gold fist comes down in front of it
func _slam(P: Player) -> void:
	var f := Vector3(sin(yaw), 0.0, cos(yaw))
	var at := Vector3(x, y, z) + f * 3.0
	Game.fx.shake = maxf(Game.fx.shake, 0.5)
	Game.fx.dust(at, 20, 3.5)
	Game.fx.sparks(at + Vector3(0.0, 0.3, 0.0), 18, 6.0, Vector3.UP, 0xffd070)
	_thud_at(at)
	if Vector2(P.x - at.x, P.z - at.z).length() < 3.3 and absf(P.y - y) < 2.0:
		_hit(P, SLAM_DMG, 8.0)


func _hit(P: Player, dmg: float, push: float) -> void:
	if mercy > 0.0:
		return
	mercy = 0.6
	if Game.combat.hurt_player(P, dmg, x, z, "bolt") and push > 0.0:
		var d := Vector2(P.x - x, P.z - z)
		if d.length() < 0.01:
			d = Vector2(sin(yaw), cos(yaw))
		d = d.normalized()
		P.ix += d.x * push
		P.iz += d.y * push
		P.vy = maxf(P.vy, 5.0)
		P.grounded = false


## Where its targets are this frame: the body round the torso, the core on the chest's front, the dome over his head
func _targets() -> void:
	var core := P_.get("core") as Node3D
	var f := Vector3(sin(yaw), 0.0, cos(yaw))
	var cp := core.global_position + f * 0.45 if core != null else Vector3(x, y + 3.6, z)
	t_body.x = x
	t_body.z = z
	t_body.y = y + 1.4
	t_core.x = cp.x
	t_core.z = cp.z
	t_core.y = cp.y - 0.45
	var d := P_.get("dome") as Node3D
	var dp := d.global_position + Vector3(0.0, 0.0, 0.0) if d != null else Vector3(x, y + 4.8, z)
	t_dome.x = x + f.x * 0.2
	t_dome.z = z + f.z * 0.2
	t_dome.y = dp.y - 0.2


## Donations come in as it breaks: the chat pays the cameraman (Sambo's five grand, from his viewers instead)
func _donations() -> void:
	var f := hp / HP
	var steps := [[0.8, 500, "skullet_enjoyer", "for the cameraman"], [0.55, 1000, "bald_is_beautiful", "BALD GOD. buy unc a gym membership"], [0.3, 1500, "dave_wants_refund", "here's sambo's refund. its yours now"], [0.1, 2000, "DaddyPastafar", "RASTA PASTA SAYS FINISH HIM MON"]]
	while _donated < steps.size() and f <= float(steps[_donated][0]):
		var s: Array = steps[_donated]
		lv.chat.donate(String(s[2]), int(s[1]), String(s[3]))
		Game.add_money(float(s[1]))
		_donated += 1


# ---------------------------------------------------------------------------------------------- the end of it

func _die() -> void:
	mode = &"dying"
	dying_t = 0.0
	mv = &"walk"
	speed = 0.0
	_clear_missiles()
	_unregister()
	if lv.bo != null:
		lv.bo.boss_bar(null)
	say("s_mech_10")
	lv.chat.set_mood(&"boss", 6.0)
	lv.chat.add_viewers(80000.0)


func _dying(dt: float) -> void:
	dying_t += dt
	lean = minf(0.5, dying_t * 0.12)
	vent = 1.0
	doors = 1.0
	if _rng.randf() < dt * 7.0:      # it shakes itself apart: sparks and little blasts all over it
		var p := Vector3(x, y + _rng.randf_range(1.0, 4.5), z) + Vector3(_rng.randf_range(-1.4, 1.4), 0.0, _rng.randf_range(-1.4, 1.4))
		Game.fx.sparks(p, 14, 7.0, null, 0xffc060)
		if _rng.randf() < 0.35:
			Game.fx.explosion(p, 1.0)
	Game.fx.shake = maxf(Game.fx.shake, 0.15)
	_set_power(1.0 if fmod(dying_t, 0.2) < 0.1 else 0.2)
	if dying_t > 3.6:
		Game.fx.explosion(Vector3(x, y + 2.8, z), 5.5)
		Game.fx.explosion(Vector3(x, y + 1.2, z), 4.0)
		Game.fx.shake = maxf(Game.fx.shake, 1.0)
		mode = &"dead"
		destroyed = true
		mech.visible = false
		if solid != null:
			solid.set_off(true)


# ---------------------------------------------------------------------------------------------- pose

func _pose_root() -> void:
	var m := P_.get("mech_root") as Node3D
	var root := m if m != null else mech
	mech.global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(x, y, z))
	if root != mech:
		root.transform = R_[String(root.name)]


func _part(nm: String, rot: Vector3, off: Vector3 = Vector3.ZERO) -> void:
	var n := P_.get(nm) as Node3D
	if n == null:
		return
	var rest: Transform3D = R_[nm]
	n.transform = Transform3D(rest.basis * Basis.from_euler(rot), rest.origin + off)


## Every part from the moment: the walk (thighs, shins and feet in turn, the hips bobbing), the gatling's spin, the stomp's raised foot, the fist, the doors, the pod lids, the lean
func _pose(_dt: float) -> void:
	_pose_root()
	var s := sin(step_ph * TAU)
	var c := cos(step_ph * TAU)
	var walking := absf(speed) > 0.1 or mv == &"charge"
	var amp := 0.32 if walking else 0.0
	var bob := absf(s) * 0.08 * (1.0 if walking else 0.0)
	_part("pelvis", Vector3(lean * 0.3, 0.0, s * 0.03 * amp * 3.0), Vector3(0.0, -bob, 0.0))
	_part("torso", Vector3(lean, 0.0, -s * 0.04 * amp * 3.0))
	_part("thigh_L", Vector3(-s * amp, 0.0, 0.0))
	_part("shin_L", Vector3(maxf(0.0, c) * amp * 1.3, 0.0, 0.0))
	_part("foot_L", Vector3(s * amp * 0.5, 0.0, 0.0))
	var lift := stomp_lift
	_part("thigh_R", Vector3(s * amp - lift * 0.9, 0.0, 0.0))
	_part("shin_R", Vector3(maxf(0.0, -c) * amp * 1.3 + lift * 1.1, 0.0, 0.0))
	_part("foot_R", Vector3(-s * amp * 0.5 - lift * 0.2, 0.0, 0.0))
	var aim := -0.15 if mv == &"gatling" else 0.0
	_part("upper_arm_R", Vector3(aim + (-c * 0.15 if walking else 0.0), 0.0, 0.0))
	_part("upper_arm_L", Vector3(-fist * 1.5 + (c * 0.15 if walking else 0.0), 0.0, 0.0))
	_part("forearm_L", Vector3(-fist * 0.6, 0.0, 0.0))
	_part("barrels_R", Vector3(0.0, 0.0, barrel_spin))
	var dr := deg_to_rad(100.0) * Cutscene.ease_(doors)
	_part("chest_door_L", Vector3(0.0, dr, 0.0))
	_part("chest_door_R", Vector3(0.0, -dr, 0.0))
	_part("pod_lid_L", Vector3(-deg_to_rad(110.0) * lids, 0.0, 0.0))
	_part("pod_lid_R", Vector3(-deg_to_rad(110.0) * lids, 0.0, 0.0))
	for m in _core_mats:
		m.emission_energy_multiplier = 6.0 * glow * (1.0 + 1.5 * doors + flash * 2.0)
