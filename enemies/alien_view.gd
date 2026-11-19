class_name AlienView
extends CreatureView
## The gray alien on screen (JS enemies/gray-alien-view.js, alien-locomotion.js): the same animation, statement for statement, on a CreatureModel exported from the JS game. Same hooks as RobotView (R / T, spine_world, el_l_world, sprite_world, muzzle_world) so the game's FX can reach him. Kinds in the same body (Tommy-Gun Gray, Button Man) export their own model and subclass this.

static var _models: Dictionary = {}        # export name -> CreatureModel

# the NPC wrapper's hand on the view (JS R.talk, R.lookYaw, R.arm, view.gun.visible): enemies/gray_alien_npc.gd
var is_green := false      # JS green-alien-view.js: the same rig and update, with its plain walk and no foot planner
var talk := false
var has_look := false
var look_yaw := 0.0
var arm := 0.0
var gun_hidden := false
var post_hook := Callable()      # (a cutscene writes over the finished pose: the JS's caller does this after view.update, and here the pose is uploaded inside update)
var run_speed := GrayAlien.RUN
var tilt := Basis.IDENTITY      # (a body thrown on the Back Alley's heap: JS npc.root.rotation)
var _walk_ph := 0.0

const CH_EYE := 0
const CH_MUZZLE := 1
const CH_GUN := 2
const CH_PALM := 3
const CH_RING := 4
const GLOW_JOINTS := {"palmRing": CH_RING, "mote0": CH_RING, "mote1": CH_RING, "mote2": CH_RING, "mote3": CH_RING}      # ENGINE DIFFERENCE: the batch has 5 glow channels, so the motes (JS 0xe2b8ff, opacity = charge) share the ring's

var phase := 0.0
var last_state: StringName = &""
var pop := 1.0
var fall := 0.0
var puddle: MeshInstance3D = null      # the ichor under a dead alien
var sink_y := 0.0
var bj := 0.0
var bjv := 0.0
var pvy := 0.0
var hy_prev := 0.64
var thump := false
var step_idx := -999999
# foot planner state (alien-locomotion.js)
var lo_phase := 0.0
var lo_vx := 0.0
var lo_vz := 0.0
var lo_speed := 0.0
var lo_blend := 0.0
var lean_x := 0.0
var lean_z := 0.0
var lo_last: Variant = null
var feet: Array[Dictionary] = [{"side": 1.0}, {"side": -1.0}]
var _w: Variant = null
# joints
var j_fall: int
var j_hips: int
var j_neck: int
var j_head: int
var j_sh_l: int
var j_hd_l: int
var j_sh_r: int
var j_el_r: int
var j_hd_r: int
var j_th_l: int
var j_kn_l: int
var j_ank_l: int
var j_th_r: int
var j_kn_r: int
var j_ank_r: int
var j_belly: int
var j_gun: int
var j_palm: int
var j_ring: int
var j_orbit: int
var j_mouth: int
var j_motes: Array[int] = []
var j_fingers := {"L": [], "R": []}
var j_thumb_l: int
var j_thumb_r: int


## glb: assets/objects/<glb>.glb, exported by tools/export/enemy_alien.expr.js (one per kind, same joints).
static func get_model(glb: String) -> CreatureModel:
	if not _models.has(glb):
		_models[glb] = CreatureModel.build("res://assets/objects/%s.glb" % glb, _fill_glow, GLOW_JOINTS)
	return _models[glb]


## A model dressed in code from an exported one (enemies/green_alien_boston.gd: the punk alien in other clothes), kept under its own name for get_model. Frees `root` if the name is already built.
static func put_model(glb: String, root: Node3D) -> void:
	if _models.has(glb):
		root.free()
		return
	_models[glb] = CreatureModel.build_from(root, glb, _fill_glow, GLOW_JOINTS)


static func _fill_glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
	var head: int = m.names["head"]
	s.sprite(head, CH_EYE, Vector3(-0.085, 0.205, 0.17), 1.0)
	s.sprite(head, CH_EYE, Vector3(0.085, 0.205, 0.17), 1.0)
	s.sprite(m.names["muzzle"], CH_MUZZLE, Vector3.ZERO, 1.0)
	s.sprite(m.names["gun"], CH_GUN, Vector3(0.0, -0.14, 0.0), 1.0)
	s.sprite(m.names["palm"], CH_PALM, Vector3.ZERO, 1.0)


func _init(p_r: GrayAlien, glb: String = "gray_alien", gun_glow: int = 0x3ff08a, p_green: bool = false) -> void:
	super._init(p_r, get_model(glb))
	is_green = p_green
	phase = randf() * 6.0
	last_state = R.state
	var n: Dictionary = model.names
	j_fall = n["fall"]
	j_hips = n["hips"]
	j_spine = n["spine"]
	j_neck = n["neck"]
	j_head = n["head"]
	j_sh_l = n["shL"]
	j_el_l = n["elL"]
	j_hd_l = n["hdL"]
	j_sh_r = n["shR"]
	j_el_r = n["elR"]
	j_hd_r = n["hdR"]
	j_th_l = n["thL"]
	j_kn_l = n["knL"]
	j_ank_l = n["ankL"]
	j_th_r = n["thR"]
	j_kn_r = n["knR"]
	j_ank_r = n["ankR"]
	j_belly = n["belly"]
	j_gun = n["gun"]
	j_palm = n["palm"]
	j_ring = n["palmRing"]
	j_orbit = n["orbit"]
	j_muzzle = n["muzzle"]
	j_mouth = n["mouthHole"]
	for i in 4:
		j_motes.append(n["mote%d" % i])
	for s: String in ["L", "R"]:
		for i in 3:
			j_fingers[s].append([n["f%s%db" % [s, i]], n["f%s%dm" % [s, i]]])
	j_thumb_l = n["fLT"]
	j_thumb_r = n["fRT"]
	var d := batch.data
	var o := row * batch.stride
	d[o + 1] = 1.0
	d[o + 7] = 1.0
	_col(d, o + 16, 0xb860ff)
	_col(d, o + 20, 0x5dff9a)
	_col(d, o + 24, gun_glow)
	_col(d, o + 28, 0xb455ff)
	_col(d, o + 32, 0xd39bff)


func sprite_world(_i: int) -> Vector3:
	return pose.world[j_spine] * Vector3(0.0, 0.3, -0.3)      # the back sprite: FX anchors steam / smoke here


func muzzle_world(kind: String = "") -> Vector3:
	return pose.world[j_palm].origin if kind == "mind" else pose.world[j_muzzle].origin


func _sample(dt: float) -> Dictionary:
	dt = clampf(dt, 0.001, 0.05)
	var px: float = R.x if lo_last == null else lo_last["x"]
	var pz: float = R.z if lo_last == null else lo_last["z"]
	var pyaw: float = R.yaw if lo_last == null else lo_last["yaw"]
	var moved := U.hyp(R.x - px, R.z - pz)
	if moved > 1.5:
		for f: Dictionary in feet:
			f.erase("position")
	var wx := clampf((R.x - px) / dt, -14.0, 14.0)
	var wz := clampf((R.z - pz) / dt, -14.0, 14.0)
	var k := 1.0 - exp(-12.0 * dt)
	var ox := lo_vx
	var oz := lo_vz
	lo_vx += (wx - lo_vx) * k
	lo_vz += (wz - lo_vz) * k
	lo_speed = U.hyp(lo_vx, lo_vz)
	lo_blend += ((minf(1.0, lo_speed / 0.75) if lo_speed > 0.12 else 0.0) - lo_blend) * (1.0 - exp(-10.0 * dt))
	var c := cos(R.yaw)
	var s := sin(R.yaw)
	var ax := (lo_vx - ox) / dt
	var az := (lo_vz - oz) / dt
	var turn := atan2(sin(R.yaw - pyaw), cos(R.yaw - pyaw)) / dt
	lean_x += (clampf(-(ax * c - az * s) * 0.008 - turn * lo_speed * 0.006, -0.11, 0.11) - lean_x) * k
	lean_z += (clampf((ax * s + az * c) * 0.007, -0.10, 0.10) - lean_z) * k
	var stride := 0.64 + minf(1.0, lo_speed / 7.6) * 1.25
	lo_phase += lo_speed / stride * PI * 2.0 * dt
	lo_last = {"x": R.x, "z": R.z, "yaw": R.yaw}
	return {"fwd": lo_vx * s + lo_vz * c, "lat": lo_vx * c - lo_vz * s, "speed": lo_speed, "phase": lo_phase}


func update(dt: float, now: float, fx: Variant) -> void:
	var t := now + phase
	var tg := {}
	if R.state != last_state:
		if R.state == &"dead":
			thump = false
			if puddle == null:
				puddle = FxBeam.puddle(0x6fd14a)
		elif last_state == &"dead":
			fall = 0.0
			if puddle != null:
				puddle.visible = false
			q.clear()
			pop = 0.0
		last_state = R.state
	var dead := R.state == &"dead"
	if dead and puddle != null:
		var pd := R.dead_t
		FxBeam.place_puddle(puddle, Vector3(R.x, R.y + 0.014, R.z), minf(0.62, 0.01 + maxf(0.0, pd - 0.9) * 0.22), maxf(0.0, 0.85 - (pd - 12.0) * 0.2) if pd > 12.0 else 0.85)
	var st := R.state_t
	# ---- placement ----
	sink_y = (R.dead_t - 9.0) * 0.3 if dead and R.dead_t > 9.0 else 0.0
	if dead and sink_y > 0.95:
		batch.clear_row(row)
		return
	pop = 0.0 if dead else minf(1.0, pop + dt * 4.0)
	var gs := 1.0 if dead else 0.4 + 0.6 * pop
	var sn := sin(R.yaw)
	var cs := cos(R.yaw)
	var root := Transform3D(Basis(Vector3(cs * gs, 0.0, -sn * gs), Vector3(0.0, gs, 0.0), Vector3(sn * gs, 0.0, cs * gs)), Vector3(R.x, R.y - sink_y, R.z))
	if tilt != Basis.IDENTITY:
		root.basis = tilt * root.basis
	var d := batch.data
	var o := row * batch.stride
	d[o] = R.flash * 0.55
	# ---- locomotion ----
	var fwd: float
	var lat: float
	var spd: float
	var ph: float
	if is_green:
		fwd = R.lvz
		lat = R.lvx
		spd = U.hyp(fwd, lat)
		_walk_ph += dt * ((spd / 0.5 * (0.85 if fwd < -0.2 else 1.0)) if spd > 0.15 else 0.0)
		ph = _walk_ph
	else:
		var motion := _sample(dt)
		fwd = motion["fwd"]
		lat = motion["lat"]
		spd = motion["speed"]
		ph = motion["phase"]
	var run := _n(spd / run_speed)
	var si := int(floorf(ph / PI))
	if step_idx == -999999:
		step_idx = si
	if si != step_idx:
		step_idx = si
		if spd > 0.9 and not dead and fx != null and fx.has_method(&"alien_step"):
			fx.alien_step(self, spd)
	var amp := clampf(0.16 + spd * 0.07, 0.0, 0.78) * (1.0 if spd > 0.15 else 0.0)
	var s_l := sin(ph)
	var s_r := sin(ph + PI)
	var c_l := cos(ph)
	var c_r := cos(ph + PI)
	var gaze := clampf(U.wrap_angle(atan2(R.known.x - R.x, R.known.z - R.z) - R.yaw), -0.8, 0.8) if R.known != null else 0.0
	var talking := not dead and (talk or (R.E != null and R.E.barks != null and R.E.barks.is_talking(R)))      # talk: set by the NPC wrapper while it speaks
	var hips_y := 0.64 - 0.03 * run + 0.03 * run * absf(s_l)
	var hips_p := 0.1 * run * (1.0 if fwd > 0.0 else -0.3)
	var hips_r := 0.1 * amp * s_l
	var hips_yaw := 0.12 * amp * s_l
	var sp_p := 0.06 * run
	var sp_y := -0.12 * amp * s_l
	var sp_r := -0.06 * amp * s_l
	var hd_y := 0.0
	var hd_p := 0.0
	var hd_r := 0.0
	var th_l := -amp * s_l
	var th_r := -amp * s_r
	var kn_l := amp * 1.1 * maxf(0.0, c_l) + 0.05
	var kn_r := amp * 1.1 * maxf(0.0, c_r) + 0.05
	var th_lz := 0.16 if lat > 0.3 else 0.03
	var th_rz := -0.16 if lat < -0.3 else -0.03
	var sh_lx := -0.1 + 0.55 * amp * s_r
	var sh_lz := 0.14
	var sh_ly := 0.0
	var el_lx := -0.5
	var hd_lx := 0.0
	var sh_rx := -0.1 + 0.5 * amp * s_l
	var sh_rz := -0.14
	var sh_ry := 0.0
	var el_rx := -0.5
	var hd_rx := 0.0
	var hd_ry := 1.25
	var curl_l := 0.7
	var curl_r := 1.0
	var charge := 0.0
	var rate := 12.0
	var aim_up := -(1.5 + R.aim)
	match R.state:
		&"idle", &"return":
			hd_y = clampf(look_yaw, -0.9, 0.9) if (has_look and not is_green) else sin(t * 0.5) * 0.45
			hd_p = sin(t * 0.33) * 0.05
			hips_r += sin(t * 0.4) * 0.03
			sp_p += sin(t * 1.5) * 0.01
			sh_rx = -0.25
			el_rx = -1.25
			sh_lx = -0.1 + 0.55 * amp * s_r
		&"alert":
			var u := _n(st / 0.25)
			var k := sin(u * PI)
			hips_y += 0.05 * k
			sp_p -= 0.16 * k
			hd_p = -0.1 * u
			hd_y = gaze
			sh_lx = -0.9 * u
			sh_lz = 0.5 * u
			el_lx = -1.1 * u
			hd_lx = 1.2 * u
			curl_l = 0.1
			sh_rx = aim_up * 0.6 * u - 0.1
			el_rx = -0.5 - 0.3 * u
			rate = 18.0
		&"pursue":
			hd_y = gaze
			hd_p = -R.aim * 0.4
			sp_p += 0.1
			if R.sees:
				sh_rx = aim_up
				el_rx = -0.1
				sp_y += 0.25
				hips_yaw += 0.1
				sh_ry = 0.06
			else:
				sh_rx = -0.8
				el_rx = -0.9
			sh_lx = -0.25 + 0.8 * amp * s_r
			el_lx = -0.75
			rate = 14.0
		&"windup":      # winding up the mind blast: left hand rises high, torso arches back, eyes and palm glow purple
			var u := _n(R.a_u)
			var e := _ease(u)
			charge = u
			sh_lx = -2.5 * e
			sh_lz = 0.55 * e + 0.14 * (1.0 - e)
			el_lx = -0.7 * e
			hd_lx = 0.6 * e
			curl_l = 0.7 - 0.6 * e
			sp_p = -0.2 * e
			hd_p = -0.22 * e
			hips_y = 0.64 - 0.05 * e
			th_l = 0.2 * e
			th_r = -0.2 * e
			kn_l = 0.2 * e
			kn_r = 0.2 * e
			sh_rx = -0.6
			el_rx = -0.8
			sp_r = sin(t * 60.0) * 0.012 * u
			hd_y = gaze
			rate = 16.0
		&"attack":      # the throw: arm snaps forward, palm out
			var u := _n(R.a_u)
			var e := _ease(_n(u / 0.5))
			charge = 1.4 - u * 0.6
			sh_lx = lerpf(-2.5, -1.5, e)
			sh_lz = lerpf(0.55, 0.06, e)
			el_lx = lerpf(-0.7, -0.08, e)
			hd_lx = lerpf(0.6, 1.45, e)
			curl_l = 0.05
			sp_p = lerpf(-0.2, 0.32, e)
			hd_p = lerpf(-0.22, 0.12, e)
			hips_y = 0.64 - 0.06
			th_l = 0.35
			th_r = -0.25
			sh_rx = -0.4
			el_rx = -0.9
			hd_y = gaze
			rate = 36.0
		&"recover":
			var u := _n(R.a_u)
			var e := _ease(u)
			charge = maxf(0.0, 0.8 * (1.0 - u))
			sh_lx = lerpf(-1.5, -0.2, e)
			sh_lz = lerpf(0.06, 0.14, e)
			el_lx = lerpf(-0.08, -0.6, e)
			hd_lx = lerpf(1.45, 0.0, e)
			curl_l = 0.05 + 0.65 * e
			sp_p = lerpf(0.32, 0.04, e)
			hips_y = 0.64 - 0.05 * (1.0 - e)
			sh_rx = -0.6
			el_rx = -0.9
			hd_y = gaze
			rate = 9.0
		&"stagger":
			var u := _n(st / 0.55)
			var env := u / 0.12 if u < 0.12 else 1.0 - (u - 0.12) / 0.88
			var f := R.hit_x * sn + R.hit_z * cs
			var l := R.hit_x * cs - R.hit_z * sn
			var e2 := env * env * 0.5 + env * 0.5
			sp_p = f * 0.5 * e2
			sp_r = -l * 0.35 * e2
			hips_p = f * 0.25 * e2
			hd_p = f * 0.6 * e2
			hd_y = l * 0.3 * e2
			hips_y = 0.64 - 0.06 * env
			sh_lx = -0.4 + f * 0.9 * e2
			sh_rx = -0.4 + f * 0.9 * e2
			sh_lz = 0.14 + 0.6 * env
			sh_rz = -0.14 - 0.6 * env
			el_lx = -0.9 * env
			el_rx = -0.9 * env
			th_l = f * 0.4 * e2
			th_r = -f * 0.3 * e2
			rate = 24.0
		&"lean":      # hub NPC: back flat on the wall, one foot up on it, a cigarette in the right hand (arm 0 = hand down, 1 = at the mouth)
			var a := _ease(_n(arm))
			var tk := 1.0 if talk else 0.0
			hips_y = 0.64
			hips_p = 0.0
			hips_r = 0.03 * sin(t * 0.4)
			hips_yaw = 0.0
			sp_p = -0.07 + 0.01 * sin(t * 1.5)
			sp_y = 0.0
			sp_r = 0.0
			th_l = 0.0
			kn_l = 0.04
			th_lz = 0.03
			th_r = -0.3
			kn_r = 1.55
			th_rz = -0.12      # left leg takes the weight; right foot is flat on the wall behind him
			hd_y = clampf(look_yaw, -0.9, 0.9) + (1.0 - tk) * sin(t * 0.5) * 0.18
			hd_p = 0.05 - 0.1 * a + 0.03 * tk * sin(t * 9.0)
			hd_r = 0.04
			sh_lx = -0.1
			sh_lz = 0.14
			el_lx = -0.35
			hd_lx = 0.0
			curl_l = 0.6      # left arm hanging loose
			sh_rx = lerpf(-0.12, -1.0, a)
			sh_rz = lerpf(-0.2, -0.1, a)
			sh_ry = lerpf(0.0, 0.5, a)
			el_rx = lerpf(-0.45, -2.15, a)
			hd_rx = lerpf(0.0, -0.2, a)
			hd_ry = 0.3
			curl_r = 0.75
			rate = 8.0
		&"search":
			hd_y = sin(t * 1.1) * 0.8
			hd_p = 0.04
			sh_rx = -1.05
			el_rx = -0.45
			sh_lx = -0.4 + 0.5 * amp * s_r
			el_lx = -0.9
			sp_y += sin(t * 1.1) * 0.25
	# ---- flinch (additive, never blocks anything), recoil from each shot ----
	if R.flinch_t > 0.0 and not dead:
		var p := R.flinch_t / 0.18
		var k := p * p
		var f := R.hit_x * sn + R.hit_z * cs
		var l := R.hit_x * cs - R.hit_z * sn
		sp_p += f * 0.22 * k
		sp_r += -l * 0.16 * k
		hd_p += f * 0.32 * k
		hd_y += l * 0.22 * k
		hips_y -= 0.02 * k
		bjv -= 0.4 * k * dt * 60.0 * 0.02
	if R.fire_t > 0.0 and not dead:
		var k := R.fire_t / 0.14
		sh_rx += 0.28 * k
		el_rx -= 0.12 * k
		sp_p -= 0.05 * k
		bjv += 0.35 * k * dt * 4.0
	# ---- death: staggers, topples backwards (belly up), arms and legs flop, the belly wobbles ----
	if dead:
		var D := R.dead_t
		var f := R.hit_x * sn + R.hit_z * cs
		var dirn := -1.0 if f <= 0.0 else 1.0
		var k1 := _ease(_n(D / 0.5))
		var k2 := _n((D - 0.2) / 0.7)
		var bounce := sin((D - 0.95) * 13.0) * 0.06 * exp(-(D - 0.95) * 3.2) if D > 0.95 else 0.0
		fall = minf(1.5, k2 * k2 * 1.5) + bounce
		hips_y = 0.64 - 0.05 * k1
		th_l = -0.6 * k1
		th_r = -0.3 * k1
		kn_l = 0.9 * k1
		kn_r = 0.5 * k1
		th_lz = 0.3 * k1
		th_rz = -0.25 * k1
		sp_p = 0.2 * k1 * -dirn
		hd_p = -0.35 * k1 * dirn
		hd_y = 0.3 * k1
		hd_r = 0.2 * k1
		sh_lx = -0.3 * k1
		sh_rx = -0.5 * k1
		sh_lz = 0.14 + 1.1 * k1
		sh_rz = -0.14 - 1.0 * k1
		el_lx = -0.5 * k1
		el_rx = -0.3 * k1
		curl_l = 0.1
		curl_r = 0.2
		rate = 14.0
		pose.euler(j_fall, dirn * minf(fall, 1.5) * 0.99, 0.0, 0.0)
		pose.pos[j_fall] = Vector3(0.0, 0.27 * sin(minf(fall, 1.5)), 0.0)
		if not thump and fall > 1.4:
			thump = true
			bjv += 1.2
	else:
		pose.rot[j_fall] = Basis.IDENTITY
		pose.pos[j_fall] = Vector3.ZERO
	# ---- apply (eased) ----
	var r := rate
	var hy := _qq(&"hipsY", hips_y, 16.0, dt)
	var hx_rot := _qq(&"hipsP", hips_p, r, dt)
	var hz_rot := _qq(&"hipsR", hips_r, r, dt)
	var hy_rot := _qq(&"hipsYaw", hips_yaw, r, dt)
	var spr_x := _qq(&"spP", sp_p, r, dt)
	var spr_y := _qq(&"spY", sp_y, r, dt)
	var spr_z := _qq(&"spR", sp_r, r, dt)
	var hdr_x := _qq(&"hdP", hd_p, r, dt)
	var hdr_y := _qq(&"hdY", hd_y, r, dt)
	var hdr_z := _qq(&"hdR", hd_r, r, dt)
	var t_l := _qq(&"thL", th_l, r, dt)
	var t_r := _qq(&"thR", th_r, r, dt)
	var k_l := _qq(&"knL", kn_l, r, dt)
	var k_r := _qq(&"knR", kn_r, r, dt)
	var hip_pos := pose.pos[j_hips]
	hip_pos.y = hy
	hip_pos.x = 0.0
	pose.pos[j_hips] = hip_pos
	pose.euler(j_neck, _qq(&"nkP", 0.0, r, dt), 0.0, 0.0)
	pose.euler(j_th_l, t_l, 0.0, _qq(&"thLz", th_lz, r, dt))
	pose.euler(j_th_r, t_r, 0.0, _qq(&"thRz", th_rz, r, dt))
	pose.euler(j_kn_l, k_l, 0.0, 0.0)
	pose.euler(j_kn_r, k_r, 0.0, 0.0)
	pose.euler(j_ank_l, clampf(-(t_l + k_l) - hx_rot, -0.7, 0.7), 0.0, 0.0)
	pose.euler(j_ank_r, clampf(-(t_r + k_r) - hx_rot, -0.7, 0.7), 0.0, 0.0)
	pose.euler(j_sh_l, _qq(&"shLx", sh_lx, r, dt), _qq(&"shLy", sh_ly, r, dt), _qq(&"shLz", sh_lz, r, dt))
	pose.euler(j_sh_r, _qq(&"shRx", sh_rx, r, dt), _qq(&"shRy", sh_ry, r, dt), _qq(&"shRz", sh_rz, r, dt))
	pose.euler(j_el_l, _qq(&"elLx", el_lx, r, dt), 0.0, 0.0)
	pose.euler(j_el_r, _qq(&"elRx", el_rx, r, dt), 0.0, 0.0)
	pose.euler(j_hd_l, _qq(&"hdLx", hd_lx, r, dt), 0.0, 0.0)
	pose.euler(j_hd_r, _qq(&"hdRx", hd_rx, r, dt), _qq(&"hdRy", hd_ry, r, dt) if is_green else 1.25, 0.0)      # pistol hand rolled so the palm faces inward (thumb up when aiming)
	if R.state == &"lean":
		pose.euler(j_ank_r, PI / 2.0 - (t_r + k_r), 0.0, 0.0)      # sole flat against the wall behind him
	var cl := _qq(&"curlL", curl_l, r, dt)
	var cr := _qq(&"curlR", curl_r, r, dt)
	for f: Array in j_fingers["L"]:
		pose.euler(f[0], -cl * 1.1, 0.0, 0.0)
		pose.euler(f[1], -cl * 1.3, 0.0, 0.0)
	for f: Array in j_fingers["R"]:
		pose.euler(f[0], -cr * 0.95, 0.0, 0.0)
		pose.euler(f[1], -cr * 1.25, 0.0, 0.0)
	pose.euler(j_thumb_l, -cl * 0.4, 0.0, -0.7)
	pose.euler(j_thumb_r, -cr * 0.3, 0.0, 0.7)
	# ---- belly: breathing + a springy wobble that lags the body's bounce ----
	var vy := (hy - hy_prev) / maxf(dt, 1e-3)
	hy_prev = hy
	var ay := clampf((vy - pvy) / maxf(dt, 1e-3), -60.0, 60.0)
	pvy = vy
	bjv += (-150.0 * bj - 9.0 * bjv - 0.0016 * ay) * dt
	bj = clampf(bj + bjv * dt, -0.045, 0.045)
	var br := 1.0 + 0.012 * sin(t * 1.8) * (0.0 if dead else 1.0)
	pose.pos[j_belly] = Vector3(0.0, bj, 0.0)
	pose.scl[j_belly] = Vector3(1.0 + bj * 0.8, br * (1.0 - bj * 2.2), br * (1.0 + bj * 1.4))
	# ---- face: mouth opens while he is talking, eyes glow with the mind-blast charge ----
	var open := 0.35 + 0.65 * absf(sin(t * 13.0)) if (talking or R.state == &"stagger" or dead) else 0.0
	var ms := pose.scl[j_mouth]
	ms.y = 0.001 + open * 0.016
	pose.scl[j_mouth] = ms
	d[o + 16 + 3] = minf(0.95, charge * 0.9)
	d[o + 12 + CH_EYE] = 0.12 + 0.1 * charge
	var ch := _n(charge)
	var ch2 := charge > 0.02
	d[o + 28 + 3] = minf(1.0, ch * 1.1) * (0.0 if dead else 1.0)
	d[o + 12 + CH_PALM] = 0.08 + 0.5 * charge
	d[o + 32 + 3] = minf(0.9, ch * 1.2)
	var rs := 0.35 + 0.9 * ch
	pose.scl[j_ring] = Vector3(rs, rs, rs)
	pose.euler(j_ring, 0.0, 0.0, t * 6.0)
	pose.euler(j_orbit, 0.0, 0.0, t * 7.0)
	var i := 0
	for m: int in j_motes:
		var a := i * PI / 2.0
		var rad := 0.2 * (1.1 - 0.5 * ch)
		pose.pos[m] = Vector3(cos(a) * rad, sin(a) * rad, 0.0)
		i += 1
	var fl := R.fire_t / 0.14 if R.fire_t > 0.0 else 0.0
	d[o + 20 + 3] = fl * 0.95
	d[o + 12 + CH_MUZZLE] = 0.25 + 0.3 * fl
	d[o + 24 + 3] = 0.25 + 0.18 * sin(t * 5.0) + 0.4 * fl
	d[o + 12 + CH_GUN] = 0.16
	if gun_hidden:      # (JS view.gun.visible = false: both hands are for leaning and smoking)
		d[o + 20 + 3] = 0.0
		d[o + 24 + 3] = 0.0
		pose.scl[j_gun] = Vector3.ZERO
	# ---- health bar ----
	update_bar(dt, 1.9 * gs, 1.0, 1.0, true)
	# ---- the foot planner + IK (alien-locomotion.js solve): hips first, then the world pose, then the legs ----
	var legs_on := not (is_green or R.dead or pop < 0.98 or R.state == &"stagger")
	var lift := 0.0
	var side_x := 0.0
	var extra_z := 0.0
	var extra_x := 0.0
	if legs_on:
		var moving := lo_blend
		lift = 0.035 + moving * 0.025
		side_x = sin(lo_phase) * 0.015 * moving
		extra_z = lean_x + sin(lo_phase) * 0.025 * moving
		extra_x = lean_z
	else:
		for f: Dictionary in feet:
			f.erase("position")
	pose.pos[j_hips] = Vector3(side_x, hy - lift, 0.0)
	pose.euler(j_hips, hx_rot + extra_x, hy_rot, hz_rot + extra_z)
	pose.euler(j_spine, spr_x, spr_y, spr_z - lean_x * 0.55 if legs_on else spr_z)
	pose.euler(j_head, hdr_x, hdr_y, hdr_z - lean_x * 0.45 if legs_on else hdr_z)
	pose.compose(root)
	if legs_on:
		_solve_feet(dt, root)
		pose.compose(root)
	if post_hook.is_valid():
		post_hook.call()
		pose.compose(root)
	upload()


static func _from_to(a: Vector3, b: Vector3) -> Basis:
	return Basis(Quaternion(a, b.normalized()))


func _solve_feet(dt: float, root: Transform3D) -> void:
	var ox := root.origin.x
	var oy := root.origin.y
	var oz := root.origin.z
	var wyaw := R.yaw
	if _w != null and U.hyp(ox - float(_w[0]), oz - float(_w[1])) > 1.5:      # the whole model was moved (dragged / teleported): replant the feet
		for f: Dictionary in feet:
			f.erase("position")
	_w = [ox, oz]
	var c := cos(wyaw)
	var s := sin(wyaw)
	var run := minf(1.0, lo_speed / 6.0)
	var moving := lo_blend
	for i in 2:
		var foot: Dictionary = feet[i]
		var th := j_th_r if i == 1 else j_th_l
		var kn := j_kn_r if i == 1 else j_kn_l
		var ank := j_ank_r if i == 1 else j_ank_l
		var ph := fposmod(lo_phase / TAU + i * 0.5, 1.0)
		var stance := 0.62 - run * 0.30
		var hip: Vector3 = pose.world[th].origin
		var head_x: float = lo_vx / lo_speed if lo_speed > 0.1 else s
		var head_z: float = lo_vz / lo_speed if lo_speed > 0.1 else c
		var lead := minf(0.23, 0.07 + lo_speed * 0.026) * moving
		var side: float = foot["side"]
		var landing := Vector3(ox + side * 0.14 * c + head_x * lead, oy + 0.081, oz - side * 0.14 * s + head_z * lead)
		var support := R.world.ground_height(landing.x, landing.z, 0.065, oy + 0.35)
		if is_finite(support) and absf(support - oy) < 0.32:
			landing.y = support + 0.081
		if not foot.has("position"):
			foot["position"] = landing
			foot["from"] = landing
			foot["to"] = landing
			foot["yaw"] = wyaw
			foot["swing"] = false
			foot["progress"] = 0.0
		var fp: Vector3 = foot["position"]
		var overreach := U.hyp(fp.x - hip.x, fp.z - hip.z) > 0.32
		var was_swing: bool = foot["swing"]
		var swing: bool = moving > 0.08 and (ph >= stance or overreach or (was_swing and float(foot["progress"]) < 1.0))
		if swing:
			if not was_swing:
				foot["from"] = fp
				foot["to"] = landing
				foot["progress"] = 0.0
			foot["to"] = (foot["to"] as Vector3).lerp(landing, 1.0 - exp(-14.0 * dt))      # replan toward movement during a swing; stance contacts never move
			foot["progress"] = minf(1.0, float(foot["progress"]) + dt * (2.8 + lo_speed * 1.6))
			var u := _ease(float(foot["progress"]))
			fp = (foot["from"] as Vector3).lerp(foot["to"], u)
			fp.y += sin(u * PI) * (0.075 + run * 0.065)
			foot["position"] = fp
			var fy: float = foot["yaw"]
			foot["yaw"] = fy + atan2(sin(wyaw - fy), cos(wyaw - fy)) * (1.0 - exp(-12.0 * dt))
		elif was_swing:
			fp = foot["to"]
			foot["position"] = fp
			foot["yaw"] = wyaw
		foot["swing"] = swing
		var delta := fp - hip
		const L1 := 0.22
		const L2 := 0.29
		var dist := clampf(delta.length(), 0.12, L1 + L2 - 0.001)
		delta = delta.normalized()
		var along := (L1 * L1 - L2 * L2 + dist * dist) / (2.0 * dist)
		var height := sqrt(maxf(0.0, L1 * L1 - along * along))
		var pole := Vector3(s, 0.0, c)
		pole = (pole - delta * pole.dot(delta)).normalized()
		var knee := hip + delta * along + pole * height
		var par: int = model.parent[th]
		var pb: Basis = pose.world[par].basis.orthonormalized()
		var upper := (pb.inverse() * (knee - hip)).normalized()
		pose.rot[th] = _from_to(Vector3.DOWN, upper)
		var th_w: Transform3D = pose.world[par] * Transform3D(pose.rot[th], pose.pos[th])
		var kn_w_parent := th_w
		var reach_w := hip + delta * dist
		var reach := (kn_w_parent.affine_inverse() * reach_w - pose.pos[kn]).normalized()
		pose.rot[kn] = _from_to(Vector3.DOWN, reach)
		var kn_w := kn_w_parent * Transform3D(pose.rot[kn], pose.pos[kn])
		var flat := Basis(Vector3.UP, float(foot["yaw"]))
		var ank_b := kn_w.basis.orthonormalized().inverse() * flat
		if swing:
			ank_b = ank_b * Basis(Vector3.RIGHT, sin(float(foot["progress"]) * PI) * -0.22)
		pose.rot[ank] = ank_b


func dispose() -> void:
	super.dispose()
	if puddle != null and is_instance_valid(puddle):
		puddle.queue_free()
