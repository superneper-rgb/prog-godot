class_name RobotView
extends RefCounted
## One hostile robot on screen: its procedural animation, ported statement for statement from JS class RobotView (index.html). Reads the Robot, poses the 17 joints by hand every frame
## (walk cycle, windups, swings, flinch, stagger, topple and twitch in the death) and writes the result into its row of the shared RigidBatch. No nodes per robot, no materials per robot.
## FX asks a view: R / T, smoke_t, spark_t, vent_t, popped, spine_world(), el_l_world(), sprite_world(i), muzzle_world().

const ROBOT_COL_GREEN := Color(0.035601, 1.0, 0.187821)     # 0x35ff78, linear
const ROBOT_COL_RED := Color(1.0, 0.0231534, 0.0103298)     # 0xff2a1a, linear
const ROBOT_COL_OFF := Color(0.00749903, 0.00913406, 0.00802885)   # 0x151816, linear
const MUZ_COL := Color(1.0, 0.102242, 0.0231534)            # 0xff5a2a, linear

# eased joint values, in the order the JS touches them
const Q_HIPS_Y := 0
const Q_HIPS_P := 1
const Q_HIPS_YAW := 2
const Q_HIPS_R := 3
const Q_SP_P := 4
const Q_SP_Y := 5
const Q_SP_R := 6
const Q_NK_P := 7
const Q_HD_P := 8
const Q_HD_Y := 9
const Q_HD_R := 10
const Q_TH_L := 11
const Q_TH_L_Z := 12
const Q_TH_R := 13
const Q_TH_R_Z := 14
const Q_KN_L := 15
const Q_KN_R := 16
const Q_SH_L_X := 17
const Q_SH_L_Z := 18
const Q_SH_R_X := 19
const Q_SH_R_Z := 20
const Q_EL_L_X := 21
const Q_EL_R_X := 22
const Q_COUNT := 23

# fixed joint offsets (JS jn(...))
const OFF_SPINE := Vector3(0.0, 0.12, 0.0)
const OFF_NECK := Vector3(0.0, 0.82, 0.0)
const OFF_HEAD := Vector3(0.0, 0.1, 0.0)
const OFF_DISH := Vector3(0.2, 0.05, 0.0)
const OFF_SH_L := Vector3(0.54, 0.62, 0.0)
const OFF_SH_R := Vector3(-0.54, 0.62, 0.0)
const OFF_EL := Vector3(0.0, -0.36, 0.0)
const OFF_TH_L := Vector3(0.26, -0.06, 0.0)
const OFF_TH_R := Vector3(-0.26, -0.06, 0.0)
const OFF_LEG := Vector3(0.0, -0.42, 0.0)


## A knocked-off piece tumbling on its own (JS this.deb)
class Debris:
	var slot := 0
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var v := Vector3.ZERO
	var w := Vector3.ZERO
	var rest := false


var T: Robot
var R: Robot
var batch: RigidBatch
var row := -1
var bar_t := 0.0
var pop := 1.0
var col := ROBOT_COL_GREEN
var phase := 0.0
var q := PackedFloat32Array()
var q_fresh := true
var deb: Array[Debris] = []
var deb_batch: RigidBatch
var deb_row := -1
var last_state := &"idle"
var fall := 0.0
var sink_y := 0.0
var smoke_t := 0.0
var spark_t := 0.0
var vent_t := 0.0
var muz_t := 0.0
var strobe := 1.0
var popped := false
var walk_ph := 0.0
var step_idx := -1
var has_step_idx := false
var hv_eff := 0.0
var intensity := 1.0
var culled := false
var tint := 1.0
var _heavy_batch := false
var _body_hidden := false
var _detached := false
var _dbg: Label3D = null
var _ring: MeshInstance3D = null
var _dsig := ""


func _init(p_r: Robot) -> void:
	T = p_r
	R = p_r
	var G := RobotGfx.get_shared()
	batch = G.batch
	row = batch.acquire()
	tint = 0.9 + float((R.id * 37) % 11) / 55.0        # each unit is weathered a little differently
	phase = randf() * 6.0
	q.resize(Q_COUNT)
	last_state = R.state
	_write_constants()


## the values of a row that never change. A cull or a release zeroes only what they are written with.
func _write_constants() -> void:
	var d := batch.data
	var o := row * batch.stride
	d[o + 1] = tint
	d[o + 2] = R.num
	d[o + 12] = 1.0     # sprite channel sizes: all as built
	d[o + 13] = 1.0
	d[o + 43] = -1.0    # the bar starts hidden
	d[o + 20] = MUZ_COL.r
	d[o + 21] = MUZ_COL.g
	d[o + 22] = MUZ_COL.b


## JS despawnEnemy: the robot's row goes back. Its knocked-off pieces stay where they fell until the level ends, as the JS clones do.
func dispose() -> void:
	if row < 0:
		return
	batch.release(row)
	row = -1
	if deb_row >= 0:
		deb_batch.data[deb_row * deb_batch.stride] = 0.0
	if _dbg != null:
		_dbg.queue_free()
		_ring.queue_free()


func spine_world() -> Vector3:
	return batch.slot_point(row, RobotGfx.J_SPINE, Vector3.ZERO)


func el_l_world() -> Vector3:
	return batch.slot_point(row, RobotGfx.J_EL_L, Vector3.ZERO)


func sprite_world(i: int) -> Vector3:
	return batch.slot_point(row, RobotGfx.SPRITE_JOINT[i], RobotGfx.SPRITE_POS[i])


func muzzle_world(_kind: String = "") -> Vector3:
	return batch.slot_point(row, RobotGfx.J_EL_L, RobotGfx.MUZZLE)


## FX.update's far cull: hidden and not animated while it is too far from the camera to matter
func set_culled(on: bool) -> void:
	culled = on
	if on:
		_hide_body()


func _hide_body() -> void:
	if _body_hidden:
		return
	_body_hidden = true
	var d := batch.data
	var o := row * batch.stride
	for i in range(o + RigidBatch.PARAMS * 4, o + batch.stride):
		d[i] = 0.0
	d[o + 43] = -1.0


## the right pauldron and the sensor dish are knocked off and tumble away
func on_die() -> void:
	var s := sin(R.yaw)
	var c := cos(R.yaw)
	var G := RobotGfx.get_shared()
	deb_batch = G.debris
	if deb_row < 0:
		deb_row = deb_batch.acquire()
	deb_batch.data[deb_row * deb_batch.stride + 1] = tint
	for k in 2:
		var src_slot := RobotGfx.J_PAU_R if k == 0 else RobotGfx.J_DISH
		var sx := -1.0 if k == 0 else 1.0
		var d := Debris.new()
		d.slot = RobotGfx.D_PAU_R if k == 0 else RobotGfx.D_DISH
		var xf := _slot_xf(src_slot)
		d.pos = xf.origin
		d.rot = xf.basis.orthonormalized().get_euler(EULER_ORDER_XYZ)
		var side_ := Vector3(c * sx, 0.0, -s * sx)
		var push := Vector3(R.hit_x, 0.0, R.hit_z)
		d.v = side_ * 2.2 + push * 2.5 + Vector3(0.0, 3.2 + randf() * 1.5, 0.0)
		d.w = Vector3(randf() * 8.0 - 4.0, randf() * 6.0 - 3.0, randf() * 8.0 - 4.0)
		deb.append(d)
		deb_batch.set_slot(deb_row, d.slot, Transform3D(Basis.from_euler(d.rot, EULER_ORDER_XYZ), d.pos))
		batch.hide_slot(row, src_slot)
	_detached = true


func _slot_xf(slot: int) -> Transform3D:
	var o := row * batch.stride + (RigidBatch.PARAMS + slot * 3) * 4
	var d := batch.data
	return Transform3D(Vector3(d[o], d[o + 4], d[o + 8]), Vector3(d[o + 1], d[o + 5], d[o + 9]), Vector3(d[o + 2], d[o + 6], d[o + 10]), Vector3(d[o + 3], d[o + 7], d[o + 11]))


func on_respawn() -> void:
	if deb_row >= 0:
		deb_batch.release(deb_row)
		deb_row = -1
	deb.clear()
	_detached = false
	fall = 0.0
	q_fresh = true
	popped = false
	pop = 0.0


func update(dt: float, now: float, fx: Variant) -> void:
	var t := now + phase
	var state := R.state
	if state != last_state:
		if state == &"dead":
			on_die()
		elif last_state == &"dead":
			on_respawn()
		last_state = state
	var dead := state == &"dead"
	var st := R.state_t
	# ---- placement ----
	sink_y = (R.dead_t - 9.0) * 0.3 if dead and R.dead_t > 9.0 else 0.0
	var g_visible := not (dead and sink_y > 0.95)
	pop = 0.0 if dead else minf(1.0, pop + dt * 4.0)
	if R.heavy_kind != "" and not _heavy_batch:      # (the level dresses a heavy a moment after it spawns: the row moves to its variant's batch)
		_heavy_batch = true
		batch.release(row)
		batch = RobotGfx.heavy_gfx(R.heavy_kind).batch
		Game.enemy_views.add_batch(batch)
		row = batch.acquire()
		_write_constants()
	var vis_scale := R.visual_scale if R.visual_scale != 0.0 else (1.3 if R.heavy else 1.0)
	var g_scale := (1.0 if dead else 0.4 + 0.6 * pop) * vis_scale
	# ---- locomotion ----
	var fwd := R.lvz
	var lat := R.lvx
	var spd := sqrt(fwd * fwd + lat * lat)
	var s_n := clampf(spd / AI.run, 0.0, 1.0)
	# FOINT heavies (heavy-ai.js): the walk cycle is stride-matched, so a planted foot does not slide. Per leg the foot must travel back along the body at exactly the
	# leg's own ground speed; the cadence follows the fastest leg (turning on the spot counts: the feet are 0.26 m off the axis) and each leg's swing is sized to fit.
	var HV := R.foint_heavy
	var hv_cad := 0.0
	var hv_leg := 0.0
	var hv_turn := 0.0
	if HV:
		hv_turn = clampf(R.yaw_rate, -7.0, 7.0)
		var turn_v := absf(hv_turn) * 0.26
		hv_eff = hv_eff + (maxf(spd, turn_v * 1.15) - hv_eff) * (1.0 - exp(-10.0 * dt))
		var S_ := clampf(0.35 + 0.34 * hv_eff, 0.5, 1.55)                  # step length (one foot plant to the next)
		hv_cad = PI * hv_eff / S_ if hv_eff > 0.12 else 0.0
		hv_leg = 2.0 * 0.9 * (R.visual_scale if R.visual_scale != 0.0 else 1.3)     # a swing of +-amp moves the foot 2 * leg length * visual scale * sin(amp)
	walk_ph += dt * (hv_cad if HV else (spd / 0.46 * (0.8 if fwd < -0.2 else 1.0) if spd > 0.15 else 0.0)) * 1.0
	var new_step := floori(walk_ph / PI)
	if not has_step_idx:
		has_step_idx = true
		step_idx = new_step
	if new_step != step_idx:
		step_idx = new_step
		if spd > 0.9 and not dead and fx != null:
			fx.robot_step(self, spd)
	var ph := walk_ph
	var amp := clampf(0.18 + spd * 0.13, 0.0, 0.78) * (1.0 if spd > 0.15 else 0.0)
	var run := s_n
	var s_l := sin(ph)
	var s_r := sin(ph + PI)
	var c_l := cos(ph)
	var c_r := cos(ph + PI)
	# target pose (radians / metres); everything is eased below
	var tg_hips_y := 1.0 - 0.03 * run + 0.018 * amp * cos(2.0 * ph + 0.4)
	var tg_hips_p := 0.16 * run * (1.0 if fwd > 0.0 else -0.3)
	var tg_hips_r := -0.05 * amp * s_l
	var tg_hips_yaw := 0.1 * amp * s_l
	var tg_sp_p := 0.05 * run
	var tg_sp_y := -0.1 * amp * s_l
	var tg_sp_r := 0.0
	var tg_nk_p := 0.0
	var tg_hd_y := 0.0
	var tg_hd_p := 0.0
	var tg_hd_r := 0.0
	var tg_th_l := -amp * s_l
	var tg_th_r := -amp * s_r
	var tg_kn_l := amp * 1.15 * maxf(0.0, c_l) + 0.05
	var tg_kn_r := amp * 1.15 * maxf(0.0, c_r) + 0.05
	var tg_th_l_z := 0.14 if lat > 0.3 else 0.0
	var tg_th_r_z := -0.14 if lat < -0.3 else 0.0
	if HV and hv_cad > 0.0:                                                # per-leg ground speed -> swing: forward / back about X, sideways about Z, knees lift in the swing
		var k_asn := PI / (hv_cad * hv_leg)
		var vf_l := fwd - 0.26 * hv_turn
		var vf_r := fwd + 0.26 * hv_turn
		var a_l := asin(clampf(vf_l * k_asn, -0.78, 0.78))
		var a_r := asin(clampf(vf_r * k_asn, -0.78, 0.78))
		var a_lat := asin(clampf(lat * k_asn, -0.78, 0.78))
		tg_th_l = -a_l * s_l
		tg_th_r = -a_r * s_r
		tg_th_l_z = a_lat * s_l + (0.06 if lat > 0.3 else 0.03)
		tg_th_r_z = a_lat * s_r - (0.06 if lat < -0.3 else 0.03)
		var sw_l := maxf(absf(a_l), absf(a_lat))
		var sw_r := maxf(absf(a_r), absf(a_lat))
		tg_kn_l = sw_l * 1.2 * maxf(0.0, c_l) + 0.05
		tg_kn_r = sw_r * 1.2 * maxf(0.0, c_r) + 0.05
		tg_hips_y = 1.0 - 0.03 * run + 0.014 * maxf(sw_l, sw_r) * cos(2.0 * ph + 0.4)
		tg_hips_r = -0.04 * maxf(sw_l, sw_r) * s_l * (1.0 if lat > 0.3 else 0.4)
		tg_hips_yaw = 0.08 * (a_l - a_r) * 0.5 * s_l
		# (the JS sets the heavies' shoulders here too, and overwrites them on the next line)
	var tg_sh_l_x := -0.18 + 0.28 * amp * s_r
	var tg_sh_r_x := -0.1 + 0.34 * amp * s_l
	var tg_el_l_x := -0.45
	var tg_el_r_x := -0.35
	var tg_sh_l_z := 0.12
	var tg_sh_r_z := -0.12
	var tg_dish := t * 1.4
	var rate := 12.0
	var light_phase := &"rest"
	var a_u := R.a_u
	match state:
		&"idle", &"return":
			var scan := 1.0 if state == &"idle" and R.pause > 0.0 else 0.35
			tg_hd_y = sin(t * 0.55) * 0.55 * scan
			tg_hd_p = sin(t * 0.37) * 0.05
			tg_sp_p += sin(t * 1.6) * 0.012
			tg_hips_y += sin(t * 1.6) * 0.004
			tg_dish = t * 1.1
		&"alert":
			var u := clampf(st / 0.3, 0.0, 1.0)
			var k := sin(u * PI)                                           # startle: snap up, scanner whirs, arms come up
			tg_sp_p -= 0.2 * k
			tg_nk_p = -0.2 * k
			tg_hips_y += 0.05 * k
			tg_sh_l_x = -0.7 * u
			tg_sh_r_x = -0.55 * u
			tg_el_l_x = -0.8 * u
			tg_el_r_x = -0.7 * u
			tg_dish = t * 9.0
			tg_hd_p = -0.12 * u
			rate = 18.0
			light_phase = &"alert"
		&"pursue":
			tg_sp_p += 0.14
			tg_hd_p = 0.1
			tg_sh_l_x = -0.55 + 0.1 * amp * s_r
			tg_el_l_x = -0.9
			tg_sh_r_x = -0.2 + 0.7 * amp * s_l
			tg_el_r_x = -1.1
			tg_dish = t * 5.0
			light_phase = &"chase"
		&"windup":
			var u := clampf(a_u, 0.0, 1.0)
			var e := u * u * (3.0 - 2.0 * u)
			if R.atk == &"melee":                                          # ram fist hauled up and back over the shoulder, body winds up, strobe speeds up
				tg_sh_r_x = -0.1 - 3.35 * e
				tg_sh_r_z = -0.12 - 0.3 * e
				tg_el_r_x = -0.35 - 0.5 * e
				tg_sh_l_x = -0.7 * e
				tg_el_l_x = -1.0 * e
				tg_sp_p = -0.35 * e
				tg_sp_y = -0.55 * e
				tg_hips_y = 1.0 - 0.07 * e
				tg_hips_yaw = -0.25 * e
				tg_hd_p = 0.12 * e
				tg_th_l = -0.25 * e
				tg_th_r = 0.3 * e
				tg_sh_r_x += sin(t * 55.0) * 0.025 * u
			else:                                                          # cannon arm swings out to aim and the muzzle charges; stance braces
				tg_sh_l_x = -(1.5 + R.aim) * e - 0.18 * (1.0 - e)
				tg_el_l_x = -0.1 * e
				tg_sh_l_z = 0.05
				tg_sp_y = 0.3 * e
				tg_sp_p = -0.08 * e
				tg_hips_yaw = 0.2 * e
				tg_hips_y = 1.0 - 0.05 * e
				tg_sh_r_x = -0.6 * e
				tg_el_r_x = -1.0 * e
				tg_th_l = 0.25 * e
				tg_th_r = -0.3 * e
				tg_hd_p = -0.05
				tg_hd_y = -0.25 * e
				tg_sh_l_x += sin(t * 70.0) * 0.012 * u
			tg_dish = t * (4.0 + 14.0 * u)
			rate = 16.0
			light_phase = &"windup"
		&"attack":
			var u := clampf(a_u, 0.0, 1.0)
			if R.atk == &"melee":                                          # overhead slam: fast down and forward, shoulders and torso follow through
				var w_ := clampf(u / 0.45, 0.0, 1.0)
				var e := w_ * w_ * (3.0 - 2.0 * w_)
				var over := sin((u - 0.45) * 9.0) * 0.05 * (1.0 - u) if u > 0.45 else 0.0
				tg_sh_r_x = lerpf(-3.45, -0.25, e) + over
				tg_sh_r_z = lerpf(-0.42, -0.12, e)
				tg_el_r_x = lerpf(-0.85, -0.15, e)
				tg_sp_p = lerpf(-0.35, 0.38, e)
				tg_sp_y = lerpf(-0.55, 0.2, e)
				tg_hips_p = 0.2 * e
				tg_hips_y = 1.0 - 0.1 * e
				tg_hips_yaw = lerpf(-0.25, 0.2, e)
				tg_th_l = -0.5 * e
				tg_th_r = 0.2 * e
				tg_sh_l_x = lerpf(-0.7, 0.2, e)
				tg_hd_p = 0.3 * e
			else:                                                          # recoil kick back
				var k := 1.0 - u
				tg_sh_l_x = -(1.5 + R.aim) + 0.42 * k
				tg_el_l_x = -0.1 - 0.15 * k
				tg_sp_p = -0.08 - 0.22 * k
				tg_sp_y = 0.3
				tg_hips_yaw = 0.2
				tg_hips_y = 1.0 - 0.05
				tg_th_l = 0.25
				tg_th_r = -0.3
				tg_hd_y = -0.25
				tg_hd_p = -0.12 * k
				tg_sh_r_x = -0.6
				tg_el_r_x = -1.0
			rate = 40.0
			light_phase = &"atk"
		&"recover":
			var u := clampf(a_u, 0.0, 1.0)
			var e := u * u * (3.0 - 2.0 * u)
			if R.atk == &"melee":                                          # stuck low after the swing: slumped, arm heavy, slowly resetting (the opening for the player)
				tg_sh_r_x = lerpf(-0.3, -0.1, e)
				tg_el_r_x = -0.25
				tg_sp_p = lerpf(0.42, 0.05, e)
				tg_sp_y = lerpf(0.15, 0.0, e)
				tg_hips_y = 1.0 - 0.09 * (1.0 - e)
				tg_hips_p = 0.2 * (1.0 - e)
				tg_hd_p = 0.32 * (1.0 - e)
				tg_th_l = -0.4 * (1.0 - e)
				tg_th_r = 0.2 * (1.0 - e)
			else:
				tg_sh_l_x = lerpf(-1.65, -0.18, e)
				tg_el_l_x = lerpf(-0.1, -0.45, e)
				tg_sp_y = 0.3 * (1.0 - e)
				tg_hips_yaw = 0.2 * (1.0 - e)
				tg_hips_y = 1.0 - 0.05 * (1.0 - e)
				tg_sh_r_x = -0.6 * (1.0 - e) - 0.1 * e
				tg_el_r_x = -1.0 * (1.0 - e) - 0.35 * e
				tg_th_l = 0.2 * (1.0 - e)
				tg_th_r = -0.25 * (1.0 - e)
				tg_hd_y = -0.2 * (1.0 - e)
			tg_dish = t * 2.0
			rate = 9.0
			light_phase = &"cool"
		&"stagger":
			var u := clampf(st / AI.stagger, 0.0, 1.0)
			var env := u / 0.12 if u < 0.12 else 1.0 - (u - 0.12) / 0.88
			var s := sin(R.yaw)
			var c := cos(R.yaw)
			var f := R.hit_x * s + R.hit_z * c
			var l := R.hit_x * c - R.hit_z * s
			var e2 := env * env * 0.5 + env * 0.5
			tg_sp_p = f * 0.65 * e2
			tg_sp_r = -l * 0.4 * e2
			tg_hips_p = f * 0.3 * e2
			tg_hips_r = -l * 0.2 * e2
			tg_hd_p = f * 0.7 * e2 + sin(t * 40.0) * 0.03 * env
			tg_hd_y = l * 0.3 * e2
			tg_hips_y = 1.0 - 0.1 * env
			tg_sh_l_x = -0.5 + f * 1.0 * e2
			tg_sh_r_x = -0.4 + f * 1.0 * e2
			tg_sh_l_z = 0.12 + 0.6 * env
			tg_sh_r_z = -0.12 - 0.6 * env
			tg_el_l_x = -0.9 * env
			tg_el_r_x = -0.9 * env
			tg_th_l = f * 0.45 * e2 - 0.1
			tg_th_r = -f * 0.3 * e2 + 0.15
			tg_kn_l = 0.4 * env
			tg_kn_r = 0.5 * env
			tg_dish = t * 20.0
			rate = 24.0
			light_phase = &"flicker"
		&"search":
			var moving := spd > 0.4
			tg_hd_y = sin(t * 1.1) * 0.9 * (0.4 if moving else 1.0)
			tg_hd_p = 0.05 + sin(t * 0.7) * 0.06
			tg_sp_p += 0.06
			tg_sh_l_x = -0.55
			tg_el_l_x = -0.7
			tg_dish = t * 6.0
			light_phase = &"search"
		&"dead":
			light_phase = &"dead"
	# ---- FOINT heavy specials (levels/omnisphere/heavy.js sets R.hv): the ram's wind-up / charge / stunned-on-a-wall, the gun line's two-arm aim ----
	if R.hv != &"" and not dead:
		match R.hv:
			&"wind":
				tg_hips_y = 0.84
				tg_sp_p = 0.35
				tg_hd_p = -0.15
				tg_sh_l_x = 0.75
				tg_sh_r_x = 0.75
				tg_sh_l_z = 0.35
				tg_sh_r_z = -0.35
				tg_el_l_x = -0.3
				tg_el_r_x = -0.3
				tg_kn_l = 0.5
				tg_kn_r = 0.5
				tg_th_l = -0.3
				tg_th_r = -0.3
				tg_sp_p += sin(t * 50.0) * 0.02
				rate = 18.0
				light_phase = &"windup"
			&"go":
				tg_sp_p = 0.55
				tg_hips_p = 0.3
				tg_hd_p = -0.35
				tg_sh_l_x = 0.95
				tg_sh_r_x = 0.95
				tg_sh_l_z = 0.5
				tg_sh_r_z = -0.5
				tg_el_l_x = -0.2
				tg_el_r_x = -0.2
				rate = 20.0
				light_phase = &"atk"
			&"stuck":
				tg_sp_p = -0.45
				tg_hd_p = -0.4 + sin(t * 30.0) * 0.05
				tg_sh_l_x = -1.4
				tg_sh_r_x = -1.4
				tg_sh_l_z = 0.7
				tg_sh_r_z = -0.7
				tg_el_l_x = -1.2
				tg_el_r_x = -1.2
				tg_hips_y = 0.92
				rate = 10.0
				light_phase = &"flicker"
			&"aimS", &"burst":
				var a := -(1.5 + R.aim)
				tg_sh_l_x = a
				tg_sh_r_x = a
				tg_el_l_x = -0.1
				tg_el_r_x = -0.1
				tg_sh_l_z = 0.15
				tg_sh_r_z = -0.15
				tg_sp_p = -0.06
				tg_hips_y = 0.95
				tg_th_l = 0.22
				tg_th_r = -0.22
				tg_hd_p = -0.05
				if R.hv == &"burst" and R.fire_t > 0.0:
					tg_sh_l_x += 0.3 * R.fire_t / 0.12
					tg_sh_r_x += 0.3 * R.fire_t / 0.12
					tg_sp_p -= 0.1
				rate = 40.0 if R.hv == &"burst" else 16.0
				light_phase = &"atk" if R.hv == &"burst" else &"windup"
			&"rest":
				tg_sp_p = 0.2
				tg_hd_p = 0.15
				rate = 9.0
				light_phase = &"cool"
	# ---- brief flinch (additive, on top of any state, never blocks it) ----
	if R.flinch_t > 0.0 and not dead:
		var p := R.flinch_t / AI.flinch
		var k := p * p
		var s := sin(R.yaw)
		var c := cos(R.yaw)
		var f := R.hit_x * s + R.hit_z * c
		var l := R.hit_x * c - R.hit_z * s
		tg_sp_p += f * 0.24 * k
		tg_sp_r += -l * 0.18 * k
		tg_hd_p += f * 0.35 * k
		tg_hd_y += l * 0.25 * k
		tg_sh_l_x += f * 0.25 * k
		tg_sh_r_x += f * 0.25 * k
		tg_hips_y -= 0.025 * k
	# ---- death: knees buckle, head droops, a pop inside the chest, then the whole frame topples and twitches ----
	var fall_rx := 0.0
	var fall_y := 0.0
	if dead:
		var D := R.dead_t
		var s := sin(R.yaw)
		var c := cos(R.yaw)
		var f := R.hit_x * s + R.hit_z * c
		var dirn := -1.0 if f <= 0.0 else 1.0                              # hit from the front -> falls backwards
		var k1u := clampf(D / 0.75, 0.0, 1.0)
		var k1 := k1u * k1u * (3.0 - 2.0 * k1u)
		var k2 := clampf((D - 0.55) / 0.7, 0.0, 1.0)
		var k2e := k2 * k2
		var bounce := sin((D - 1.25) * 11.0) * 0.05 * exp(-(D - 1.25) * 3.5) if D > 1.25 else 0.0
		fall = minf(1.45, k2e * 1.45) + bounce
		var tw := maxf(0.0, 1.0 - (D - 1.3) / 3.2) * (1.0 if sin(D * 31.0) * sin(D * 7.3) > 0.2 else 0.0) if D > 1.3 else 0.0
		tg_hips_y = 1.0 - 0.34 * k1 - 0.1 * k2
		tg_th_l = -0.95 * k1
		tg_th_r = -0.7 * k1
		tg_kn_l = 1.55 * k1
		tg_kn_r = 1.35 * k1
		tg_sp_p = 0.5 * k1 * dirn * -0.3
		tg_hd_p = 0.5 * k1 + dirn * -0.2 * k2
		tg_hd_y = 0.35 * k1
		tg_hd_r = 0.25 * k1
		tg_sh_l_x = -0.1 + 0.5 * k1 + tw * 0.5
		tg_sh_r_x = -0.1 + 0.2 * k1 - tw * 0.4
		tg_sh_l_z = 0.12 + 0.5 * k1
		tg_sh_r_z = -0.12 - 0.7 * k1
		tg_el_l_x = -0.4 - 0.5 * k1 + tw * 0.4
		tg_el_r_x = -0.3 - 0.9 * k1
		tg_dish = 0.0
		rate = 14.0
		fall_rx = dirn * -fall * 0.99 * 1.0                                # topple about the feet (pivot is at the ground)
		fall_y = 0.12 * (fall - 0.9) if fall > 0.9 else 0.0
		if not popped and D > 0.5:
			popped = true
			if fx != null:
				fx.robot_pop(self)
	# ---- apply (eased) ----
	var k_r := 1.0 if q_fresh else 1.0 - exp(-rate * dt)
	var k_h := 1.0 if q_fresh else 1.0 - exp(-14.0 * dt)
	q_fresh = false
	var v := q
	var hips_y := v[Q_HIPS_Y] + (tg_hips_y - v[Q_HIPS_Y]) * k_h
	v[Q_HIPS_Y] = hips_y
	var hips_p := v[Q_HIPS_P] + (tg_hips_p - v[Q_HIPS_P]) * k_r
	v[Q_HIPS_P] = hips_p
	var hips_yaw := v[Q_HIPS_YAW] + (tg_hips_yaw - v[Q_HIPS_YAW]) * k_r
	v[Q_HIPS_YAW] = hips_yaw
	var hips_r := v[Q_HIPS_R] + (tg_hips_r - v[Q_HIPS_R]) * k_r
	v[Q_HIPS_R] = hips_r
	var sp_p := v[Q_SP_P] + (tg_sp_p - v[Q_SP_P]) * k_r
	v[Q_SP_P] = sp_p
	var sp_y := v[Q_SP_Y] + (tg_sp_y - v[Q_SP_Y]) * k_r
	v[Q_SP_Y] = sp_y
	var sp_r := v[Q_SP_R] + (tg_sp_r - v[Q_SP_R]) * k_r
	v[Q_SP_R] = sp_r
	var nk_p := v[Q_NK_P] + (tg_nk_p - v[Q_NK_P]) * k_r
	v[Q_NK_P] = nk_p
	var hd_p := v[Q_HD_P] + (tg_hd_p - v[Q_HD_P]) * k_r
	v[Q_HD_P] = hd_p
	var hd_y := v[Q_HD_Y] + (tg_hd_y - v[Q_HD_Y]) * k_r
	v[Q_HD_Y] = hd_y
	var hd_r := v[Q_HD_R] + (tg_hd_r - v[Q_HD_R]) * k_r
	v[Q_HD_R] = hd_r
	var th_l := v[Q_TH_L] + (tg_th_l - v[Q_TH_L]) * k_r
	v[Q_TH_L] = th_l
	var th_l_z := v[Q_TH_L_Z] + (tg_th_l_z - v[Q_TH_L_Z]) * k_r
	v[Q_TH_L_Z] = th_l_z
	var th_r := v[Q_TH_R] + (tg_th_r - v[Q_TH_R]) * k_r
	v[Q_TH_R] = th_r
	var th_r_z := v[Q_TH_R_Z] + (tg_th_r_z - v[Q_TH_R_Z]) * k_r
	v[Q_TH_R_Z] = th_r_z
	var kn_l := v[Q_KN_L] + (tg_kn_l - v[Q_KN_L]) * k_r
	v[Q_KN_L] = kn_l
	var kn_r := v[Q_KN_R] + (tg_kn_r - v[Q_KN_R]) * k_r
	v[Q_KN_R] = kn_r
	var sh_l_x := v[Q_SH_L_X] + (tg_sh_l_x - v[Q_SH_L_X]) * k_r
	v[Q_SH_L_X] = sh_l_x
	var sh_l_z := v[Q_SH_L_Z] + (tg_sh_l_z - v[Q_SH_L_Z]) * k_r
	v[Q_SH_L_Z] = sh_l_z
	var sh_r_x := v[Q_SH_R_X] + (tg_sh_r_x - v[Q_SH_R_X]) * k_r
	v[Q_SH_R_X] = sh_r_x
	var sh_r_z := v[Q_SH_R_Z] + (tg_sh_r_z - v[Q_SH_R_Z]) * k_r
	v[Q_SH_R_Z] = sh_r_z
	var el_l_x := v[Q_EL_L_X] + (tg_el_l_x - v[Q_EL_L_X]) * k_r
	v[Q_EL_L_X] = el_l_x
	var el_r_x := v[Q_EL_R_X] + (tg_el_r_x - v[Q_EL_R_X]) * k_r
	v[Q_EL_R_X] = el_r_x
	var ank_l := clampf(-(th_l + kn_l) - hips_p, -0.7, 0.7)
	var ank_r := clampf(-(th_r + kn_r) - hips_p, -0.7, 0.7)
	# ---- status lights: green only at rest; red when damaged / alerted / chasing / attacking; dark when dead ----
	var lt := R.light
	var target := ROBOT_COL_RED if lt == &"red" else (ROBOT_COL_GREEN if lt == &"green" else ROBOT_COL_OFF)
	col = col.lerp(target, 1.0 - exp(-(30.0 if lt == &"red" else 8.0) * dt))
	var I := 1.0
	match light_phase:
		&"rest":
			I = 0.75 + 0.25 * sin(t * 2.2)
		&"alert":
			I = 1.15 if sin(t * 30.0) > 0.0 else 0.35
		&"chase":
			I = 0.85 + 0.2 * sin(t * 9.0)
		&"windup":
			var u := clampf(a_u, 0.0, 1.0)
			var f := 6.0 + 20.0 * u
			I = 1.2 if sin(t * f * 2.0) > -0.1 else 0.25
		&"atk":
			I = 1.5
		&"cool":
			I = 0.5 + 0.25 * sin(t * 6.0)
		&"flicker":
			I = 1.1 if sin(t * 83.0) * sin(t * 47.0) > -0.2 else 0.05
		&"search":
			I = 0.55 + 0.45 * (1.0 if sin(t * 3.2) > 0.0 else 0.3)
		&"dead":
			var D := R.dead_t
			if D < 0.15:
				I = 1.6
			elif D < 1.9:
				I = (0.9 if sin(D * 47.0) * sin(D * 19.0) > 0.0 else 0.04) * maxf(0.0, 1.0 - D / 1.9)
			else:
				I = 0.5 if D < 3.2 and sin(D * 29.0) > 0.93 else 0.0
	intensity = I
	# muzzle charge light: ramps up through the ranged windup, flashes on the shot
	var ch := 0.0
	var shot_atk := state == &"attack"
	if state == &"windup" and R.atk == &"shot":
		ch = clampf(a_u, 0.0, 1.0)
	elif shot_atk and R.atk == &"shot":
		ch = 2.0 - clampf(a_u, 0.0, 1.0)
	# ---- the row ----
	var d := batch.data
	var o := row * batch.stride
	d[o] = R.flash
	d[o + 4] = col.r
	d[o + 5] = col.g
	d[o + 6] = col.b
	d[o + 7] = I
	d[o + 8] = 0.15 + ch * 0.85
	d[o + 9] = 0.05 + ch * (0.6 if shot_atk else 0.12)
	d[o + 10] = 0.05 + (ch * 0.4 if shot_atk else 0.0)
	d[o + 16] = col.r                                                      # glow sprites
	d[o + 17] = col.g
	d[o + 18] = col.b
	d[o + 19] = minf(0.9, 0.55 * I)
	d[o + 23] = 0.0 if R.dead else minf(1.0, ch * 0.9)                      # muzzle sprite
	# ---- debris ----
	if not deb.is_empty():
		deb_batch.data[deb_row * deb_batch.stride] = R.flash
		for b in deb:
			if b.rest:
				continue
			b.v.y -= 15.0 * dt
			b.pos += b.v * dt
			b.rot += b.w * dt
			var gy := maxf(0.0, R.world.ground_height(b.pos.x, b.pos.z, 0.1, b.pos.y + 0.5))
			if b.pos.y < gy + 0.06:
				b.pos.y = gy + 0.06
				if b.v.y < -2.5:
					b.v.y *= -0.35
					b.v.x *= 0.6
					b.v.z *= 0.6
					b.w *= 0.6
				else:
					b.rest = true
			deb_batch.set_slot(deb_row, b.slot, Transform3D(Basis.from_euler(b.rot, EULER_ORDER_XYZ), b.pos))
	# ---- health bar ----
	if R.flash > 0.5:
		bar_t = 2.5
	elif R.hp < R.max:
		bar_t = maxf(0.0, bar_t - dt * 0.7)
	else:
		bar_t = maxf(0.0, bar_t - dt)
	var sn := sin(R.yaw)
	var cs := cos(R.yaw)
	if not dead and bar_t > 0.0 and R.hp < R.max:
		var f := maxf(0.0, R.hp / R.max)
		var c_b := hsl(0.02 + 0.3 * f, 0.85, 0.55)
		d[o + 36] = R.x
		d[o + 37] = R.y - sink_y + 2.75 * g_scale
		d[o + 38] = R.z
		d[o + 39] = R.yaw
		d[o + 40] = c_b.r
		d[o + 41] = c_b.g
		d[o + 42] = c_b.b
		d[o + 43] = f
		d[o + 3] = g_scale / maxf(0.5, g_scale)
	else:
		d[o + 43] = -1.0
	_debug()
	if not g_visible or culled or (R.shattered and dead):
		_hide_body()
		return
	_body_hidden = false
	# ---- the joints, parent to child (JS leaves this to the scene graph; a joint at the same place in the same order) ----
	var bat := batch
	var g_xf := Transform3D(Basis(Vector3(cs * g_scale, 0.0, -sn * g_scale), Vector3(0.0, g_scale, 0.0), Vector3(sn * g_scale, 0.0, cs * g_scale)), Vector3(R.x, R.y - sink_y, R.z))
	var fall_xf := g_xf * Transform3D(Basis(Vector3.RIGHT, fall_rx), Vector3(0.0, fall_y, 0.0)) if dead else g_xf
	var hips_xf := fall_xf * Transform3D(Basis.from_euler(Vector3(hips_p, hips_yaw, hips_r), EULER_ORDER_XYZ), Vector3(0.0, hips_y, 0.0))
	bat.set_slot(row, RobotGfx.J_HIPS, hips_xf)
	var spine_xf := hips_xf * Transform3D(Basis.from_euler(Vector3(sp_p, sp_y, sp_r), EULER_ORDER_XYZ), OFF_SPINE)
	bat.set_slot(row, RobotGfx.J_SPINE, spine_xf)
	var neck_xf := spine_xf * Transform3D(Basis(Vector3.RIGHT, nk_p), OFF_NECK)
	var head_xf := neck_xf * Transform3D(Basis.from_euler(Vector3(hd_p, hd_y, hd_r), EULER_ORDER_XYZ), OFF_HEAD)
	bat.set_slot(row, RobotGfx.J_HEAD, head_xf)
	var sh_l_xf := spine_xf * Transform3D(Basis.from_euler(Vector3(sh_l_x, 0.0, sh_l_z), EULER_ORDER_XYZ), OFF_SH_L)
	bat.set_slot(row, RobotGfx.J_SH_L, sh_l_xf)
	bat.set_slot(row, RobotGfx.J_EL_L, sh_l_xf * Transform3D(Basis(Vector3.RIGHT, el_l_x), OFF_EL))
	var sh_r_xf := spine_xf * Transform3D(Basis.from_euler(Vector3(sh_r_x, 0.0, sh_r_z), EULER_ORDER_XYZ), OFF_SH_R)
	bat.set_slot(row, RobotGfx.J_SH_R, sh_r_xf)
	bat.set_slot(row, RobotGfx.J_EL_R, sh_r_xf * Transform3D(Basis(Vector3.RIGHT, el_r_x), OFF_EL))
	if not _detached:
		bat.set_slot(row, RobotGfx.J_DISH, head_xf * Transform3D(Basis(Vector3.RIGHT, tg_dish), OFF_DISH))
		bat.set_slot(row, RobotGfx.J_PAU_R, sh_r_xf)
	var th_l_xf := hips_xf * Transform3D(Basis.from_euler(Vector3(th_l, 0.0, th_l_z), EULER_ORDER_XYZ), OFF_TH_L)
	bat.set_slot(row, RobotGfx.J_TH_L, th_l_xf)
	var kn_l_xf := th_l_xf * Transform3D(Basis(Vector3.RIGHT, kn_l), OFF_LEG)
	bat.set_slot(row, RobotGfx.J_KN_L, kn_l_xf)
	bat.set_slot(row, RobotGfx.J_ANK_L, kn_l_xf * Transform3D(Basis(Vector3.RIGHT, ank_l), OFF_LEG))
	var th_r_xf := hips_xf * Transform3D(Basis.from_euler(Vector3(th_r, 0.0, th_r_z), EULER_ORDER_XYZ), OFF_TH_R)
	bat.set_slot(row, RobotGfx.J_TH_R, th_r_xf)
	var kn_r_xf := th_r_xf * Transform3D(Basis(Vector3.RIGHT, kn_r), OFF_LEG)
	bat.set_slot(row, RobotGfx.J_KN_R, kn_r_xf)
	bat.set_slot(row, RobotGfx.J_ANK_R, kn_r_xf * Transform3D(Basis(Vector3.RIGHT, ank_r), OFF_LEG))


## THREE.Color.setHSL
static func hsl(h: float, s: float, l: float) -> Color:
	var q2 := l * (1.0 + s) if l <= 0.5 else l + s - l * s
	var p := 2.0 * l - q2
	return Color(_hue(p, q2, h + 1.0 / 3.0), _hue(p, q2, h), _hue(p, q2, h - 1.0 / 3.0))


static func _hue(p: float, q2: float, t: float) -> float:
	if t < 0.0:
		t += 1.0
	if t > 1.0:
		t -= 1.0
	if t < 1.0 / 6.0:
		return p + (q2 - p) * 6.0 * t
	if t < 0.5:
		return q2
	if t < 2.0 / 3.0:
		return p + (q2 - p) * 6.0 * (2.0 / 3.0 - t)
	return p


## AI debug overlay: state label above the robot and the alert-radius ring on the ground (Config.ai_debug). Nodes only while it is on: it is a dev tool.
func _debug() -> void:
	var on := Config.ai_debug != 0
	if on and _dbg == null:
		_dbg = Label3D.new()
		_dbg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_dbg.no_depth_test = true
		_dbg.pixel_size = 0.006
		_dbg.font_size = 28
		_dbg.outline_size = 8
		_dbg.render_priority = 20
		Game.level.add_child(_dbg)
		_ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.985
		tm.outer_radius = 1.0
		tm.rings = 96
		tm.ring_segments = 3
		_ring.mesh = tm
		var rm := StandardMaterial3D.new()
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.cull_mode = BaseMaterial3D.CULL_DISABLED
		_ring.material_override = rm
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Game.level.add_child(_ring)
	if _dbg == null:
		return
	_dbg.visible = on
	_ring.visible = on
	if not on:
		return
	_dbg.position = Vector3(R.x, R.y + 3.2, R.z)
	_ring.position = Vector3(R.x, R.y + 0.06, R.z)
	_ring.scale = Vector3(Config.ai_alert_radius, Config.ai_alert_radius, Config.ai_alert_radius)
	var rm2: StandardMaterial3D = _ring.material_override
	rm2.albedo_color = Color(ROBOT_COL_RED if R.light == &"red" else ROBOT_COL_GREEN, 0.12 if R.dead else 0.5)
	var sig := "%s%s%d%d%s%s" % [R.state, R.light, roundi(R.hp), roundi(R.poise / 10.0), R.slot, str(floori(R.state_t)) if R.state_t < 9.0 else "9"]
	if sig != _dsig:
		_dsig = sig
		_dbg.modulate = Color(1.0, 0.35, 0.29) if R.light == &"red" else (Color(0.43, 1.0, 0.6) if R.light == &"green" else Color(0.47, 0.47, 0.47))
		_dbg.text = "#%s %s\nhp %d  light %s\npoise %d%s  t %.1f" % [str(R.num).pad_zeros(2), String(R.state).to_upper(), roundi(R.hp), R.light, roundi(R.poise), ("  slot " + R.slot) if R.slot != &"" else "", R.state_t]
