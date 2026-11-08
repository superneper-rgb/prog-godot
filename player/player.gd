class_name Player
extends RefCounted
## The player's movement simulation, ported statement for statement from the three.js game's Player class (index.html player.js):
## same sub-steps, same numbers, same order, so the feel carries over. Pure simulation: no nodes. The view reads this every frame.

## In a crawlspace: crouch held, no jumping or aiming (JS crawl.js btn).
class CrawlInput:
	var src: Variant = null
	var crouch := Inp.Btn.new()
	var off := Inp.Btn.new()
	var move: Inp.Stick:
		get:
			return src.move
	func _init() -> void:
		crouch.held = true
	func btn(n: StringName) -> Inp.Btn:
		if n == &"crouch":
			return crouch
		if n == &"jump" or n == &"ads":
			return off
		return src.btn(n)

## Rooted by a move (JS levels/kame-lab/level.js rootBtn): no walking, jumping, crouching, sprinting, strafing or attacking.
class RootedInput:
	var src: Variant = null
	var off := Inp.Btn.new()
	var still := Inp.Stick.new()
	var move: Inp.Stick:
		get:
			return still
	func btn(n: StringName) -> Inp.Btn:
		if n == &"jump" or n == &"crouch" or n == &"sprint" or n == &"strafe" or n == &"attack":
			return off
		return src.btn(n)

const SUBSTEP := 1.0 / 90.0
const WALL_DIRS: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]

class WallRun:
	var nx := 0.0   # into the wall
	var nz := 0.0
	var tx := 0.0   # run direction
	var tz := 0.0
	var sp := 0.0
	var t := 0.0
	var lost := 0.0
	var side := 1.0

class Pole:
	var p: Dictionary
	var th := 0.0
	var w := 0.0
	var along := 0.0
	var sgn := 1.0
	var lc := 1.0
	var ox := 0.0
	var oy := 0.0
	var oz := 0.0
	var ovx := 0.0
	var ovy := 0.0
	var ovz := 0.0

class Ledge:
	var t := 0.0     # the lip's height (JS L.T)
	var fx := 0.0
	var fz := 0.0
	var x0 := 0.0
	var z0 := 0.0
	var y0 := 0.0

## JS P.factoryInteraction: a level's workstation pose (office operator, warehouse workstations)
class FactoryInteraction:
	var weight := 0.0
	var settle_vx := 0.0
	var settle_vz := 0.0
	var target := Vector3.ZERO
	var active := false

var world: World
var x := 0.0
var y := 0.0
var z := 0.0
var yaw := 0.0
var vx := 0.0
var vy := 0.0
var vz := 0.0
var grounded := true
var crouching := false
var strafing := false
var sprinting := false
var pad_sprint := false
var h := 1.8
var coyote_t := 0.0
var buffer_t := 0.0
var land_t := 0.0
var air_jump := false
var jumping := false
var wall_run: WallRun = null
var wall_cd := 0.0
var pole: Pole = null
var pole_cd := 0.0
var jet_on := false
var jetting := false
var jet_fuel := 0.0
var flip := -1.0              # -1 idle, else 0..1 progress of an aerial flip
var flip_type := &"front"     # front (double jump) | back | side_l | side_r (strafe jumps)
var flip_len := 0.62
var mode := &"normal"         # normal | hang | pull | pole | swim | ladder
var mode_t := 0.0
var ledge: Ledge = null
var swim_s: Variant = null    # surface height under you (null = none)
var swim_bob := 0.0
var swim_ph := 0.0
var swim_ring := 0.0
var splash_k := 0.0
var ladder: Variant = null    # { x, z, fx, fz, top }
var lad_ph := 0.0
var hop_cd := 0.0
var last_jump := &""          # jump | high | double | coyote | wall | jet | pole | ladder | back | side_l | side_r
var land_impact := 0.0
var land_dur := 0.44
var slamming := false
var slam_drop := false
var slam_t := 0.0
var slam_u := 0.0
var slam_req := false
var slam_cd := 0.0
var slam_hit: Variant = null  # Vector3 where a hammer fist landed, consumed by combat
var events: Array[StringName] = []
var ads := false
var aiming := false
var punching := false
var punch_face: Variant = null  # yaw the body turns to while punching, or null
var punch_stage := 0
var punch_u := 0.0
var recoil := 0.0
var ix := 0.0                 # impulse (a knockback), decays
var iz := 0.0
var slow_t := 0.0
var slow_mul := 1.0
var stun_t := 0.0
var armed := false
var weapon_idx := -1
var aim_pitch := 0.0
var aim_yaw := 0.0
var long_j := false
var long_spd := 0.0
var ldx := 0.0
var ldz := 0.0
var leap_cd := 0.0
var scoped := false
var scope_fov := 0.0
var rl_on := false            # reload state, written by combat, read by the animator
var rl_kind := ""
var rl_dur := 0.0
var rl_u := 0.0
var rl_ph := ""
var rl_pu := 0.0
var rl_n := -1
var rl_empty := false
var rooted := false            # a move holds him where he stands (KAME LAB)
var _rooted_inp := RootedInput.new()
var crouch_hide := false      # a level or cutscene hides the equipped gun
var crawl_contains := Callable()    # levels/_kit/crawl.gd: func(player) -> bool, the volume of its crawlspaces
var crawl_active := false
var _crawl_inp := CrawlInput.new()
var factory_interaction: FactoryInteraction = null   # a machine being worked by hand (the animator reaches for it)

var god := false              # the console's god mode: Combat.hurt_player ignores every hit
var is_ai_clone := false      # this state belongs to an AI ally (it wears no suit, its events say so)
var clone_id := 0

# survive reset() (falling out of the world must not heal)
var max_hp := 100.0
var hp := 100.0
var dead := false
var dead_t := 0.0
var invuln := 0.0
var regen_t := 0.0
var fall_dir := -1.0
var max_mana := 100.0
var mana := 100.0
var mana_t := 0.0
var power_aim := false
var shield := 0.0
var shield_max := -1.0
var shield_t := 0.0
var shield_delay := 8.0
var shield_rate := 10.0
var shield_col := ""
var shield_hex := 0
var shield_rech := false


func _init(w: World) -> void:
	world = w
	if w != null:      # (no world: a posed figure for the Animator, like the JS menu scene's plain object)
		reset()


func respawn() -> void:
	reset()
	hp = max_hp
	dead = false
	dead_t = 0.0
	invuln = 2.5
	regen_t = 0.0
	mana = max_mana
	power_aim = false
	shield = maxf(0.0, shield_max)
	shield_t = 0.0
	shield_rech = false


func reset() -> void:
	var s := world.spawn
	x = s.x
	y = s.y
	z = s.z
	yaw = s.yaw
	vx = 0.0
	vz = 0.0
	vy = 0.0
	grounded = true
	crouching = false
	strafing = false
	sprinting = false
	pad_sprint = false
	h = Config.height
	coyote_t = 0.0
	buffer_t = 0.0
	land_t = 0.0
	air_jump = false
	jumping = false
	wall_run = null
	wall_cd = 0.0
	pole = null
	pole_cd = 0.0
	jet_on = false
	jetting = false
	jet_fuel = 0.0
	flip = -1.0
	flip_type = &"front"
	flip_len = Config.flip_dur
	mode = &"normal"
	mode_t = 0.0
	ledge = null
	swim_s = null
	swim_bob = 0.0
	swim_ph = 0.0
	swim_ring = 0.0
	splash_k = 0.0
	ladder = null
	lad_ph = 0.0
	hop_cd = 0.0
	last_jump = &""
	land_impact = 0.0
	land_dur = 0.44
	slamming = false
	slam_drop = false
	slam_t = 0.0
	slam_u = 0.0
	slam_req = false
	slam_cd = 0.0
	slam_hit = null
	events = []
	ads = false
	aiming = false
	punching = false
	punch_face = null
	punch_stage = 0
	punch_u = 0.0
	recoil = 0.0
	ix = 0.0
	iz = 0.0
	slow_t = 0.0
	slow_mul = 1.0
	stun_t = 0.0
	armed = false
	weapon_idx = -1
	aim_pitch = 0.0
	aim_yaw = 0.0


func speed() -> float:
	return sqrt(vx * vx + vz * vz)


## Advance one frame: split into sub-steps of at most 1/90 s; edges (pressed / released) only on the first. dead_input: JS DEAD_INPUT (dead, stunned: no stick, no buttons).
func update(dt: float, cam_yaw: float, dead_input: bool = false) -> void:
	dt = minf(dt, 0.05)
	var n := maxi(1, ceili(dt / SUBSTEP))
	var sd := dt / n
	for i in n:
		var inp: Variant = Inp.dead if dead_input else (Inp.full if i == 0 else Inp.sub)
		if rooted:
			_rooted_inp.src = inp
			inp = _rooted_inp
		step(sd, inp, cam_yaw)


## The same frame for an AI clone: its virtual controls instead of the player's (JS state.update(dt, input, heading)).
func update_with(dt: float, inp: Variant, sub: Variant, cam_yaw: float) -> void:
	dt = minf(dt, 0.05)
	var n := maxi(1, ceili(dt / SUBSTEP))
	var sd := dt / n
	for i in n:
		step(sd, inp if i == 0 else sub, cam_yaw)


## falling and about to land: a press now is a buffered ground jump, not a double jump
func _near_ground() -> bool:
	if vy >= 0.0:
		return false
	var g := world.ground_height(x, z, Config.radius, y)
	return g > -INF and g > y - 0.7


func can_stand() -> bool:
	return not world.blocked(x, z, y, Config.height, Config.radius, Config.step_up)


func step(dt: float, inp: Variant, cam_yaw: float) -> void:
	if crawl_contains.is_valid():      # JS levels/_kit/crawl.js P.step
		crawl_active = crawl_contains.call(self) and grounded and not dead
		if crawl_active:
			buffer_t = 0.0
			crouch_hide = true
			_crawl_inp.src = inp
			inp = _crawl_inp
		else:
			crouch_hide = false
	var C := Config
	var W := world
	var b_jump: Inp.Btn = inp.btn(&"jump")
	var b_crouch: Inp.Btn = inp.btn(&"crouch")
	var b_sprint: Inp.Btn = inp.btn(&"sprint")
	var b_ads: Inp.Btn = inp.btn(&"ads")
	var b_strafe: Inp.Btn = inp.btn(&"strafe")
	var b_l3: Inp.Btn = inp.btn(&"l3")
	slow_t = maxf(0.0, slow_t - dt)
	stun_t = maxf(0.0, stun_t - dt)
	buffer_t = maxf(0.0, buffer_t - dt)
	coyote_t = maxf(0.0, coyote_t - dt)
	wall_cd = maxf(0.0, wall_cd - dt)
	pole_cd = maxf(0.0, pole_cd - dt)
	land_t = maxf(0.0, land_t - dt)
	slam_cd = maxf(0.0, slam_cd - dt)
	if b_jump.pressed:
		buffer_t = C.jump_buffer
	ads = b_ads.held and armed and mode == &"normal" and not power_aim     # power mode: the gun is lowered, no ADS / scope
	strafing = b_strafe.held and not ads

	if mode != &"normal":
		slamming = false
		jet_on = false
		jetting = false
		wall_run = null
		if mode == &"swim":
			_swim_step(dt, inp, cam_yaw)
		elif mode == &"ladder":
			_ladder_step(dt, inp)
		elif mode == &"pole":
			_pole_step(dt, inp, cam_yaw)
		else:
			_ledge_step(dt)
		return

	# ---- crouch (hold). Can't stand up under a low ceiling. ----
	if b_crouch.held and grounded:
		crouching = true
	elif crouching and (not b_crouch.held or not grounded) and can_stand():
		crouching = false
	h = C.crouch_height if crouching else C.height

	# ---- sprint: Shift holds it on keyboard; L3 toggles on pad. Both stop for strafe, crouch and ADS. ----
	if pad_sprint and not sprinting and not b_sprint.held:
		pad_sprint = false    # external cancel (reload, weapon swap, slam)
	var m: Inp.Stick = inp.move
	if b_l3.pressed:
		if pad_sprint:
			pad_sprint = false
		elif m.mag > 0.3 and not strafing and not crouching:
			pad_sprint = true
	var sprint_blocked := m.mag < 0.2 or strafing or crouching or punching or ads
	if sprint_blocked:
		pad_sprint = false
	sprinting = not sprint_blocked and (pad_sprint or b_sprint.held)

	# ---- desired horizontal velocity (camera relative) ----
	var sy := sin(cam_yaw)
	var cy := cos(cam_yaw)
	var dx := sy * m.y + (-cy) * m.x
	var dz := cy * m.y + sy * m.x
	var mag := m.mag
	var spd := C.run_speed * (C.strafe_speed_mult if strafing else 1.0) * (C.crouch_speed_mult if crouching else 1.0) * (C.sprint_speed_mult if sprinting else 1.0) * (0.5 if punching else 1.0) * (slow_mul if slow_t > 0.0 else 1.0) * (C.ads_speed_mult if ads else 1.0)
	var tx := dx * spd
	var tz := dz * spd
	var t_mag := sqrt(tx * tx + tz * tz)

	leap_cd = maxf(0.0, leap_cd - dt)
	# ---- wall run: airborne, fast, pushing into a wall => run along it (timed); A kicks off and refunds the air jump ----
	if C.wall_run > 0:
		_wall_run_step(dt, dx, dz, mag, b_crouch)
	# ---- jumping ----
	var can_ground := grounded or coyote_t > 0.0
	if wall_run != null and b_jump.pressed:
		var w := wall_run
		var run := maxf(w.sp, C.run_speed) * 0.75
		vx = w.tx * run - w.nx * C.wall_kick
		vz = w.tz * run - w.nz * C.wall_kick
		vy = C.jump_vel * 1.25
		wall_run = null
		wall_cd = 0.35
		air_jump = true
		jumping = true
		buffer_t = 0.0
		flip = -1.0
		last_jump = &"wall"
		events.append(&"wall_kick")
		yaw = atan2(vx, vz)
	elif buffer_t > 0.0 and can_ground:
		# crouch + jump: standing still = straight-up high jump; moving = low, long, fast gap leap
		var cr_j := crouching and grounded and not ads
		var mov := m.mag > 0.2 or sqrt(vx * vx + vz * vz) > 0.6
		var leap := cr_j and mov and leap_cd <= 0.0
		var high := cr_j and not mov
		vy = C.jump_vel * (1.15 if leap else (C.high_jump_mult if high else 1.0))
		last_jump = &"high" if high else (&"jump" if grounded else &"coyote")
		if leap:
			leap_cd = 99.0
		long_j = leap
		long_spd = C.run_speed * 1.5
		if leap:
			var lx := dx
			var lz := dz
			if sqrt(lx * lx + lz * lz) < 0.05:
				lx = sin(yaw)
				lz = cos(yaw)
			var dl := sqrt(lx * lx + lz * lz)
			if dl == 0.0:
				dl = 1.0
			vx = lx / dl * long_spd
			vz = lz / dl * long_spd
			ldx = lx / dl
			ldz = lz / dl
		# strafe jumps: sideways 360 flips left / right, backflip when pushing back (facing stays locked)
		var aerial := &""
		if (strafing or aiming) and not high and not ads and m.mag > 0.4:     # strafing OR hip-firing
			var back := -m.y
			var side := absf(m.x)
			if back > 0.5 and back >= side:
				aerial = &"back"
			elif side > 0.5 and side > m.y:
				aerial = &"side_l" if m.x < 0.0 else &"side_r"
		grounded = false
		coyote_t = 0.0
		buffer_t = 0.0
		jumping = true
		air_jump = not high     # the crouch high jump is a committed jump: no double jump
		flip = -1.0
		land_t = 0.0
		if aerial != &"":
			flip = 0.0
			flip_type = aerial
			flip_len = C.aerial_flip_dur
			jumping = false
			air_jump = false
			last_jump = aerial
		events.append(last_jump)
		if crouching and can_stand():
			crouching = false
		h = C.crouch_height if crouching else C.height
	elif b_jump.pressed and not ads and not slamming and not grounded and air_jump and coyote_t <= 0.0 and not _near_ground() and C.jet_fuel > 0.0:
		# jetpack equipped: the second tap lights it instead of the double jump (one tank per airtime, refilled only by landing)
		air_jump = false
		jet_on = true
		jetting = true
		jet_fuel = C.jet_fuel
		jumping = false
		flip = -1.0
		buffer_t = 0.0
		vy = maxf(vy, C.jet_boost)
		last_jump = &"jet"
		events.append(&"jet")
	elif b_jump.pressed and not ads and not slamming and not grounded and air_jump and coyote_t <= 0.0 and not _near_ground():
		vy = C.jump_vel * C.double_jump_mult
		air_jump = false
		jumping = true
		flip = 0.0
		flip_type = &"front"
		flip_len = C.flip_dur
		buffer_t = 0.0
		last_jump = &"double"
		events.append(&"double")
	# ---- jetpack burn: hold A while fuel lasts; letting go saves what is left until you land ----
	if jet_on:
		jetting = not grounded and not slamming and b_jump.held and jet_fuel > 0.0
		if jetting:
			jet_fuel = maxf(0.0, jet_fuel - dt)
			vy = minf(vy + C.jet_accel * dt, maxf(vy, C.jet_max_rise))
		if grounded:
			jet_on = false
	else:
		jetting = false
	# variable height: let go of A early => cut the rise
	if jumping and not b_jump.held and not long_j and vy > C.jump_cut_vel:
		vy = C.jump_cut_vel
		jumping = false
	if vy <= 0.0:
		jumping = false
	if flip >= 0.0:
		flip += dt / flip_len
		if flip >= 1.0:
			flip = -1.0

	# ---- hammer fist (melee during a double jump): hang with raised hands, then dive and smash the ground ----
	if slam_req:
		slam_req = false
		if not grounded and last_jump == &"double" and not slamming and slam_cd <= 0.0:
			slamming = true
			slam_t = 0.0
			slam_drop = false
			jumping = false
			sprinting = false
			if flip >= 0.0:
				flip_len = 0.16     # finish the flip quickly and come upright
			vx *= 0.3
			vz *= 0.3
			events.append(&"slam_start")
	if slamming:
		slam_t += dt
		slam_u = minf(1.0, slam_t / C.slam_windup)
		if slam_t < C.slam_windup:
			vy = 0.9
		else:
			if not slam_drop:
				slam_drop = true
				events.append(&"slam_drop")
			vy = -C.slam_speed

	# ---- horizontal velocity ----
	var vm := sqrt(vx * vx + vz * vz)
	var rate: float
	if grounded:
		if t_mag < 0.01 or t_mag < vm - 0.6:
			rate = C.ground_decel * (C.strafe_accel_mult if strafing else 1.0)
		else:
			var cosv := (vx * tx + vz * tz) / (vm * t_mag) if vm > 0.1 else 1.0
			rate = C.ground_accel * (1.0 + (1.0 - cosv) * C.turn_boost) * (1.0 + (C.start_boost - 1.0) * clampf(1.0 - vm / 2.0, 0.0, 1.0)) * (C.strafe_accel_mult if strafing else 1.0)
	elif t_mag < 0.01:
		rate = C.air_drag
	else:
		var cos_a := (vx * tx + vz * tz) / (vm * t_mag) if vm > 0.1 else 1.0
		rate = C.air_accel * (1.0 + (1.0 - cos_a) * C.air_turn_boost)
	if grounded and long_j:
		long_j = false
		leap_cd = 1.0
	var ttx := tx
	var ttz := tz
	if wall_run != null:
		var w := wall_run
		ttx = w.tx * w.sp + w.nx * 1.5
		ttz = w.tz * w.sp + w.nz * 1.5
		rate = 45.0
	if not grounded and long_j:
		rate = 7.0
		if t_mag < 0.01:
			ttx = vx
			ttz = vz
		else:
			var dl := sqrt(dx * dx + dz * dz)
			if dl == 0.0:
				dl = 1.0
			ttx = dx / dl * long_spd
			ttz = dz / dl * long_spd
	elif not grounded and last_jump == &"high":
		ttx = tx * 0.15
		ttz = tz * 0.15
		rate = 30.0
	if jetting:
		rate *= C.jet_air
	var ex := ttx - vx
	var ez := ttz - vz
	var el := sqrt(ex * ex + ez * ez)
	var maxd := rate * dt
	if el <= maxd:
		vx = ttx
		vz = ttz
	else:
		vx += ex / el * maxd
		vz += ez / el * maxd

	# ---- facing ----
	if wall_run != null:
		yaw = U.damp_angle(yaw, atan2(wall_run.tx, wall_run.tz), 22.0, dt)
	elif punch_face != null:
		yaw = U.damp_angle(yaw, float(punch_face), 34.0, dt)
	elif strafing or aiming:
		yaw = U.damp_angle(yaw, cam_yaw, 48.0 if aiming else C.strafe_turn_k, dt)    # shooting from the hip squares him up to the camera
	elif mag > 0.12:
		var ht := atan2(dx, dz)
		var hd := absf(U.wrap_angle(ht - yaw))    # bigger heading error => faster turn, so pivots stay crisp
		yaw = U.damp_angle(yaw, ht, (C.turn_k if grounded else C.air_turn_k) * (1.0 + C.turn_snap * hd / PI), dt)

	# ---- horizontal move, axis separated ----
	var r := C.radius
	ix *= exp(-9.0 * dt)
	iz *= exp(-9.0 * dt)
	var nx := x + (vx + ix) * dt
	if not W.blocked(nx, z, y, h, r, C.step_up):
		x = nx
	else:
		vx = 0.0
	var nz := z + (vz + iz) * dt
	if not W.blocked(x, nz, y, h, r, C.step_up):
		z = nz
	else:
		vz = 0.0

	# ---- vertical ----
	var prev_y := y
	if grounded:
		var g := W.ground_height(x, z, r, y + C.step_up)
		if g > -INF and g >= y - C.step_down:
			y = g
			vy = 0.0
		else:
			grounded = false
			coyote_t = C.coyote
			air_jump = true
			jumping = false
	if not grounded:
		var gr := (0.0 if wall_run != null else (C.gravity_up * 0.6 if jetting else (C.gravity_up if vy > 0.0 else C.gravity_down))) * (C.apex_grav if (not slamming and absf(vy) < C.apex_vel) else 1.0)
		var v_new := maxf(-C.max_fall, vy - gr * dt)
		var dy := (vy + v_new) * 0.5 * dt
		vy = v_new
		var head_old := y + h
		y += dy
		if dy > 0.0:
			var cb := W.ceiling(x, z, r, head_old, y + h)
			if not is_nan(cb):
				y = cb - h - 1e-3
				vy = minf(vy, 0.0)
				jumping = false
		else:
			var g2 := W.ground_height(x, z, r, maxf(prev_y, y + C.step_up))
			if g2 > -INF and y <= g2:
				land_impact = -vy
				y = g2
				vy = 0.0
				grounded = true
				flip = -1.0
				air_jump = false
				jumping = false
				wall_run = null
				if not slamming:      # heavy landings bleed speed
					var ld := 1.0 - C.land_drag * clampf((land_impact - 10.0) / 12.0, 0.0, 1.0)
					vx *= ld
					vz *= ld
				land_dur = C.land_dur * (0.8 + 0.5 * clampf(land_impact / 20.0, 0.0, 1.0))
				land_t = land_dur
				if slamming:
					slamming = false
					slam_drop = false
					slam_cd = 0.5
					land_impact = 30.0
					land_dur = 0.62
					land_t = 0.62
					slam_hit = Vector3(x, y, z)
					events.append(&"slam_land")
				events.append(&"land")
		if not grounded and not slamming:
			_try_ledge(dx, dz, mag)
	if C.pole_swing > 0 and not grounded and pole_cd <= 0.0 and not W.poles.is_empty():
		_try_pole()
	if W.water != null and not grounded and mode == &"normal":
		var s: Variant = W.water.call(&"at", x, z)
		if s != null and y < float(s) - 0.25:
			_enter_water(float(s))
	if y < W.fall_reset_y:
		reset()


# ---------------- swimming (world.water: at(x, z) -> surface height | null, level, ladders: [{ x, z, fx, fz, top }]) ----------------
func _enter_water(s: float) -> void:
	var C := Config
	var k := clampf(-vy / 26.0, 0.0, 1.0)
	mode = &"swim"
	mode_t = 0.0
	flip = -1.0
	jumping = false
	air_jump = false
	long_j = false
	slamming = false
	slam_drop = false
	crouching = false
	h = C.height
	land_t = 0.0
	punching = false
	vy *= 0.55      # the water takes most of a fall at once
	vx *= 0.5
	vz *= 0.5
	swim_s = s
	splash_k = 0.2 + 0.8 * k
	swim_ring = 0.0
	events.append(&"splash")


## in the water: stroke along the surface (camera relative, like running), bob on the swells, sink in and come back up after a plunge; swim into a ladder to climb out
func _swim_step(dt: float, inp: Variant, cam_yaw: float) -> void:
	var C := Config
	var W := world
	var m: Inp.Stick = inp.move
	var r := C.radius
	var H := 1.6      # the body's height in the water (low enough to pass under a pier deck)
	mode_t += dt
	var sv: Variant = W.water.call(&"at", x, z) if W.water != null else null
	if sv == null:
		mode = &"normal"
		grounded = false
		swim_s = null
		return    # carried off the edge of the water: fall as normal
	var s: float = sv
	swim_s = s
	var lvl: Variant = W.water.get(&"level")
	swim_bob = s - (float(lvl) if lvl != null else s)
	var rest := s - C.swim_float
	var deep := rest - y     # deep > 0: under the floating depth (just after a plunge)
	var sy := sin(cam_yaw)
	var cy := cos(cam_yaw)
	var dx := sy * m.y - cy * m.x
	var dz := cy * m.y + sy * m.x
	var mag := m.mag
	var b_l3: Inp.Btn = inp.btn(&"l3")
	var b_sprint: Inp.Btn = inp.btn(&"sprint")
	var b_jump: Inp.Btn = inp.btn(&"jump")
	if b_l3.pressed:
		pad_sprint = not pad_sprint and mag > 0.3
	if mag < 0.2:
		pad_sprint = false
	sprinting = mag > 0.3 and (pad_sprint or b_sprint.held)
	# ---- horizontal: a slow push up to stroke speed, a long glide when you stop ----
	var sp := (C.swim_sprint if sprinting else C.swim_speed) * (0.45 if deep > 0.5 else 1.0) * (slow_mul if slow_t > 0.0 else 1.0)
	var tx := dx * sp
	var tz := dz * sp
	var tm := sqrt(tx * tx + tz * tz)
	var vm := sqrt(vx * vx + vz * vz)
	var rate := C.swim_accel if (tm > 0.01 and tm >= vm - 0.3) else C.swim_drag
	var ex := tx - vx
	var ez := tz - vz
	var el := sqrt(ex * ex + ez * ez)
	var md := rate * dt
	if el <= md:
		vx = tx
		vz = tz
	else:
		vx += ex / el * md
		vz += ez / el * md
	if mag > 0.12:
		yaw = U.damp_angle(yaw, atan2(dx, dz), C.swim_turn_k, dt)
	ix *= exp(-9.0 * dt)
	iz *= exp(-9.0 * dt)
	var nx := x + (vx + ix) * dt
	if not W.blocked(nx, z, y, H, r, 0.05):
		x = nx
	else:
		vx = 0.0
	var nz := z + (vz + iz) * dt
	if not W.blocked(x, nz, y, H, r, 0.05):
		z = nz
	else:
		vz = 0.0
	# ---- vertical: buoyancy holds the body at its floating depth on the moving surface; a plunge sinks in and comes back up through the drag; a hop kicks you half out ----
	var above := y - rest
	hop_cd = maxf(0.0, hop_cd - dt)
	# a hop only from the floating depth and only once the last one has settled: mashing jump cannot stack kicks and carry you out of the water
	if b_jump.pressed and deep < 0.3 and above <= 0.02 and hop_cd <= 0.0 and mode_t > 0.3:
		vy = C.swim_hop
		hop_cd = 0.5
		events.append(&"swim_hop")
	var a := -C.gravity_down * 0.7 if above > 0.02 else clampf(-above * 38.0, -14.0, 16.0) - vy * (2.1 if deep > 0.4 else 7.0)
	var head_old := y + H
	vy += a * dt
	y += vy * dt
	if vy > 0.0:
		var cb := W.ceiling(x, z, r, head_old, y + H)
		if not is_nan(cb):
			y = cb - H - 1e-3
			vy = minf(vy, 0.0)
	y = maxf(y, s - 7.0)
	var g := W.ground_height(x, z, r, y + 0.3)     # a bottom you touch (shallows): stand up if the water is only chest deep there
	if g > -INF and y <= g:
		y = g
		vy = maxf(0.0, vy)
		if g > s - 1.1:
			mode = &"normal"
			grounded = true
			swim_s = null
			land_impact = 0.0
			events.append(&"land")
			return
	# ---- the stroke cycle (the animator draws it, the FX and sound follow its beats) ----
	var spd := sqrt(vx * vx + vz * vz)
	var p0 := swim_ph
	swim_ph = fmod(swim_ph + dt * (0.3 + spd * 0.13 if spd > 0.4 else 0.4), 1.0)
	swim_ring += dt
	if spd > 0.6 and floori(swim_ph * 2.0) != floori(p0 * 2.0):
		swim_ring = 0.0
		events.append(&"stroke")
	elif spd <= 0.6 and swim_ring > 1.4 and deep < 0.3:
		swim_ring = 0.0
		events.append(&"tread")
	# ---- a ladder in front of you, and you swimming at it: grab on ----
	var ladders: Variant = W.water.get(&"ladders")
	if deep < 0.8 and ladders != null and mag > 0.3:
		for L: Dictionary in ladders:
			var ox: float = x - L.x
			var oz: float = z - L.z
			var out: float = -(ox * L.fx + oz * L.fz)
			var side: float = absf(ox * L.fz - oz * L.fx)
			if out < 0.0 or out > 1.15 or side > 0.75 or y > L.top:
				continue
			var dl := sqrt(dx * dx + dz * dz)
			if dl == 0.0:
				dl = 1.0
			if (dx * L.fx + dz * L.fz) / dl < 0.45:
				continue
			mode = &"ladder"
			mode_t = 0.0
			ladder = L
			lad_ph = 0.0
			vx = 0.0
			vz = 0.0
			vy = 0.0
			sprinting = false
			pad_sprint = false
			events.append(&"ladder_grab")
			return


## on a quay ladder: hand over hand up out of the water, then the ledge pull-up over the top. Jump lets go.
func _ladder_step(dt: float, inp: Variant) -> void:
	var C := Config
	var L: Dictionary = ladder
	mode_t += dt
	var b_jump: Inp.Btn = inp.btn(&"jump")
	if b_jump.pressed and mode_t > 0.2:
		mode = &"normal"
		ladder = null
		grounded = false
		vx = -L.fx * 3.0
		vz = -L.fz * 3.0
		vy = 3.5
		air_jump = false
		jumping = false
		yaw = atan2(-L.fx, -L.fz)
		last_jump = &"ladder"
		events.append(&"ladder_off")
		return
	var sx: float = L.x - L.fx * (C.radius + 0.12)
	var sz: float = L.z - L.fz * (C.radius + 0.12)
	var k := 1.0 - exp(-14.0 * dt)
	x += (sx - x) * k
	z += (sz - z) * k
	yaw = U.damp_angle(yaw, atan2(L.fx, L.fz), 16.0, dt)
	if mode_t < 0.18:
		return    # the grab
	var RUNG := 0.3
	var ph0 := lad_ph
	var dy := C.swim_climb * (0.5 + 0.5 * absf(sin(lad_ph * TAU))) * dt    # a pull per rung: quick, then a breath
	y += dy
	lad_ph += dy / (2.0 * RUNG)     # one cycle = two rungs (left hand, right hand)
	if floori(lad_ph * 2.0) != floori(ph0 * 2.0):
		events.append(&"rung")
	if y >= float(L.top) - C.hang_drop:     # hands on the lip: the ledge pull-up takes you over the top
		y = float(L.top) - C.hang_drop
		x = sx
		z = sz
		yaw = atan2(L.fx, L.fz)
		var e := Ledge.new()
		e.t = L.top
		e.fx = L.fx
		e.fz = L.fz
		e.x0 = sx
		e.z0 = sz
		e.y0 = y
		ledge = e
		ladder = null
		swim_s = null
		mode = &"pull"
		mode_t = 0.0
		events.append(&"ledge")


# ---------------- wall run ----------------
## a wall touching the body: [dx, dz] points into it (axis-aligned walls only); the one best matching the preferred direction
func _wall_probe(px: float, pz: float) -> Variant:
	var r := Config.radius
	var best: Variant = null
	var bd := -9.0
	for wd in WALL_DIRS:
		if not world.blocked(x + wd.x * 0.14, z + wd.y * 0.14, y, h, r, 0.05):
			continue
		var d := wd.x * px + wd.y * pz
		if d > bd:
			bd = d
			best = [wd.x, wd.y, d]
	return best


func _wall_run_step(dt: float, dx: float, dz: float, mag: float, b_crouch: Inp.Btn) -> void:
	var C := Config
	var W := world
	var w := wall_run
	if w != null:
		w.t += dt
		var hit := W.blocked(x + w.nx * 0.14, z + w.nz * 0.14, y, h, C.radius, 0.05)
		w.lost = 0.0 if hit else w.lost + dt      # a seam in the geometry must not drop the run: it needs to stay lost for a moment
		if w.lost > 0.12 or grounded or w.t > C.wall_run_time or b_crouch.held or slamming:
			wall_run = null
			wall_cd = 0.45
			return
		var arc := 2.4 - w.t * 3.3
		var k := 1.0 - exp(-(30.0 if w.t < 0.25 else 40.0) * dt)
		vy += (arc - vy) * k       # a small rise, then a slow sink: an arc, never a free climb
		return
	if grounded or wall_cd > 0.0 or slamming or jetting or ads or mag < 0.3 or vy < -26.0:
		return
	var sp := sqrt(vx * vx + vz * vz)
	if sp < C.wall_run_min:
		return
	var g := W.ground_height(x, z, C.radius, y)
	if g > -INF and g > y - 0.9:
		return
	var dl := sqrt(dx * dx + dz * dz)
	if dl == 0.0:
		dl = 1.0
	var hit2: Variant = _wall_probe(dx / dl, dz / dl)
	if hit2 == null or float(hit2[2]) < 0.2:
		return
	var hnx: float = hit2[0]
	var hnz: float = hit2[1]
	var t1x := -hnz
	var t1z := hnx
	var along := vx * t1x + vz * t1z + (dx * t1x + dz * t1z) * 3.0
	if absf(along) < 1.5:
		return     # head-on: nothing to run along
	var sg := 1.0 if along > 0.0 else -1.0
	var fx := sin(yaw)
	var fz := cos(yaw)
	var nw := WallRun.new()
	nw.nx = hnx
	nw.nz = hnz
	nw.tx = t1x * sg
	nw.tz = t1z * sg
	nw.sp = minf(C.wall_run_speed, maxf(sp, C.run_speed * 1.1))
	nw.t = 0.0
	nw.lost = 0.0
	var side_s := U.signf0(hnx * fz - hnz * fx)
	nw.side = side_s if side_s != 0.0 else 1.0
	wall_run = nw
	jumping = false
	flip = -1.0
	events.append(&"wall_run")


# ---------------- pole swing ----------------
## hands (head height) touching a pole of world.poles { x, y, z, axis: "x" | "z", half, r } while airborne: grab it
func _try_pole() -> void:
	var C := Config
	var hy := y + h
	for p: Dictionary in world.poles:
		var ax_x: bool = p.axis == "x"
		var al: float = x - p.x if ax_x else z - p.z
		var pp: float = z - p.z if ax_x else x - p.x
		if absf(al) > p.half or absf(pp) > 0.55 or p.y - hy < -0.4 or p.y - hy > 0.6:
			continue
		var lc := C.pole_com
		var vs := vz if ax_x else vx
		var th0 := asin(clampf(pp / lc, -0.8, 0.8))
		var sgn := 1.0 if (vs if absf(vs) > 0.4 else pp) >= 0.0 else -1.0
		# the entry speed becomes swing speed along the arc's tangent (horizontal and vertical parts), so a fast approach is a fast swing
		var P := Pole.new()
		P.p = p
		P.th = th0
		P.w = clampf((vs * cos(th0) + vy * sin(th0)) / lc, -7.0, 7.0)
		P.along = al
		P.sgn = sgn
		P.lc = lc
		pole = P
		mode = &"pole"
		mode_t = 0.0
		flip = -1.0
		jumping = false
		jet_on = false
		jetting = false
		wall_run = null
		crouching = false
		h = C.height
		var v0x := vx
		var v0y := vy
		var v0z := vz
		vx = 0.0
		vz = 0.0
		vy = 0.0
		air_jump = false
		events.append(&"pole")
		var bx := x
		var by := y
		var bz := z
		_pole_place()
		# where the body was before the grab, and how fast it was moving beyond the arc's own speed: a critically damped spring eases it onto the arc (no pop, no dead stop)
		var ts := P.lc * P.w * cos(P.th)
		var ty := P.lc * P.w * sin(P.th)
		P.ox = bx - x
		P.oy = by - y
		P.oz = bz - z
		P.ovx = v0x - (0.0 if ax_x else ts)
		P.ovy = v0y - ty
		P.ovz = v0z - (ts if ax_x else 0.0)
		x = bx
		y = by
		z = bz
		return


## the body's centre of mass on the swing arc (the hands are on the pole); the feet reference sits 0.9 m under it
func _pole_place() -> void:
	var P := pole
	var p := P.p
	var s := P.lc * sin(P.th)
	var up := -P.lc * cos(P.th) - 0.9
	if p.axis == "x":
		x = float(p.x) + P.along
		z = float(p.z) + s
	else:
		z = float(p.z) + P.along
		x = float(p.x) + s
	y = float(p.y) + up
	x += P.ox
	y += P.oy
	z += P.oz


func _pole_step(dt: float, inp: Variant, cam_yaw: float) -> void:
	var C := Config
	var P := pole
	var p := P.p
	var W := world
	var m: Inp.Stick = inp.move
	var b_jump: Inp.Btn = inp.btn(&"jump")
	var b_crouch: Inp.Btn = inp.btn(&"crouch")
	mode_t += dt
	var sy := sin(cam_yaw)
	var cy := cos(cam_yaw)
	var dx := sy * m.y - cy * m.x
	var dz := cy * m.y + sy * m.x
	var ax_x: bool = p.axis == "x"
	var ps := dz if ax_x else dx
	var pa := dx if ax_x else dz
	if b_jump.pressed or b_crouch.pressed:     # let go
		var kick := b_jump.pressed
		var k := C.pole_launch if kick else 1.0
		var vsw := P.lc * P.w * cos(P.th) * k
		var vyw := P.lc * P.w * sin(P.th) * k
		if ax_x:
			vz = vsw
			vx = pa * C.pole_shimmy
		else:
			vx = vsw
			vz = pa * C.pole_shimmy
		vy = minf(14.0, vyw + (C.pole_kick if kick else 0.0))
		mode = &"normal"
		pole = null
		pole_cd = 0.5
		air_jump = kick
		jumping = false
		grounded = false
		last_jump = &"pole"
		events.append(&"pole_release")
		return
	# grab settle: critically damped spring on the offset
	var ks := 10.0
	var a1 := ks * ks * dt
	var a2 := 2.0 * ks * dt
	P.ovx -= a1 * P.ox + a2 * P.ovx
	P.ovy -= a1 * P.oy + a2 * P.ovy
	P.ovz -= a1 * P.oz + a2 * P.ovz
	P.ox += P.ovx * dt
	P.oy += P.ovy * dt
	P.oz += P.ovz * dt
	# pump: pushing with the swing adds energy, pushing against it only brakes
	var pump := C.pole_accel * ps if (ps * P.w > 0.0 or absf(P.w) < 0.5) else C.pole_accel * 0.45 * ps
	var g := 24.0
	var a := -(g / P.lc) * sin(P.th) + pump - 0.18 * P.w    # pendulum + pump - drag
	P.w += a * dt
	P.th += P.w * dt
	if absf(P.th) > 2.4:
		P.th = U.signf0(P.th) * 2.4
		P.w *= -0.3 if absf(P.th) > 2.39 else 1.0
	P.along = clampf(P.along + pa * C.pole_shimmy * dt, -float(p.half), float(p.half))
	var ox := x
	var oy := y
	var oz := z
	_pole_place()
	if W.blocked(x, z, y + 0.9, 0.8, 0.3, 0.05) and not (absf(P.ox) + absf(P.oy) + absf(P.oz) > 0.05):     # bumped something: bounce back
		x = ox
		y = oy
		z = oz
		P.th -= P.w * dt
		P.w *= -0.4
	if absf(P.w) > 0.5:
		P.sgn = 1.0 if P.w > 0.0 else -1.0
	var face := (0.0 if ax_x else PI / 2.0) + (PI if P.sgn < 0.0 else 0.0)
	yaw = U.damp_angle(yaw, face, 12.0, dt)


# ---------------- ledge grab ----------------
func _try_ledge(dx: float, dz: float, mag: float) -> void:
	var C := Config
	var W := world
	if vy > 5.0 or mag < 0.3:
		return
	var fx := sin(yaw)
	var fz := cos(yaw)
	var dl := sqrt(dx * dx + dz * dz)
	if dl == 0.0:
		dl = 1.0
	if (dx * fx + dz * fz) / dl < 0.4:
		return      # must be pushing toward the ledge
	var r := C.radius
	var lo := y + C.ledge_min
	var hi := y + C.ledge_max
	var p0x := x + fx * (r + 0.08)
	var p0z := z + fz * (r + 0.08)
	var p1x := x + fx * (r + 0.30)
	var p1z := z + fz * (r + 0.30)
	var p2x := x + fx * (r + 0.80)
	var p2z := z + fz * (r + 0.80)
	var t0 := W.surface_in(p0x, p0z, lo, hi)
	var t1 := W.surface_in(p1x, p1z, lo, hi)
	if t1 == -INF or t0 == -INF or absf(t0 - t1) > 0.25:
		return
	var T := t1
	if absf(W.surface_in(p2x, p2z, T - 0.2, T + 0.2) - T) > 0.2:
		return    # flat top beyond the lip
	if W.blocked(p2x, p2z, T, C.height, r, 0.05):
		return    # room to stand
	# grab
	mode = &"hang"
	mode_t = 0.0
	flip = -1.0
	crouching = false
	h = C.height
	vx = 0.0
	vz = 0.0
	vy = 0.0
	jumping = false
	y = T - C.hang_drop
	var s := 0.0
	while s < 0.5 and not W.blocked(x + fx * 0.02, z + fz * 0.02, y, C.height, r, C.step_up):
		x += fx * 0.02
		z += fz * 0.02
		s += 0.02
	var e := Ledge.new()
	e.t = T
	e.fx = fx
	e.fz = fz
	e.x0 = x
	e.z0 = z
	e.y0 = y
	ledge = e
	events.append(&"ledge")


func _ledge_step(dt: float) -> void:
	var C := Config
	var L := ledge
	mode_t += dt
	if mode == &"hang":
		if mode_t >= C.hang_time:
			mode = &"pull"
			mode_t = 0.0
		return
	var t := clampf(mode_t / C.pull_time, 0.0, 1.0)
	var up := U.ease_in_out(clampf(t / 0.65, 0.0, 1.0))
	var fw := U.ease_in_out(clampf((t - 0.45) / 0.55, 0.0, 1.0))
	var dist := C.radius + 0.15
	y = lerpf(L.y0, L.t, up)
	x = L.x0 + L.fx * dist * fw
	z = L.z0 + L.fz * dist * fw
	if t >= 1.0:
		mode = &"normal"
		mode_t = 0.0
		grounded = true
		vy = 0.0
		vx = 0.0
		vz = 0.0
		y = L.t
		air_jump = false
		land_t = 0.1
		ledge = null
		events.append(&"pullup")
