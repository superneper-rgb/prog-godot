class_name Drone
extends Robot
## Gun Drone, a flying shooter, ported statement for statement from JS class Drone (index.html enemy.js).
## Round purple chassis, one red eye, four blade fins. It hovers about 2.7 m up, strafes in a ring around the player (8 - 14 m), fires 3-bolt bursts after a short
## eye-charge telegraph, and now and then stops dead to call ground reinforcements. It is a Robot (same hurt() / alerts / state names), but it never touches the ground:
## knockback sends it sliding through the air, and when it dies it falls out of the sky and crashes. Fragile (50 hp), so one Bellows Beast blast flings it without killing it.

class DRONE:
	const hp := 50.0
	const r := 0.5
	const h := 0.9
	const hover := 2.7
	const notice := 22.0
	const sight := 40.0
	const speed := 5.4
	const accel := 5.0
	const kv_decay := 4.0
	const min_d := 8.0
	const max_d := 14.0
	const wind := 0.6
	const burst := 3
	const gap := 0.14
	const cd := 2.4
	const dmg := 6.0
	const bolt_speed := 27.0
	const spread := 0.04
	const call_after := 5.0
	const call_time := 1.4
	const call_cd := 24.0
	const call_max := 2
	const call_count := 2
	const alive_cap := 4

var hover := DRONE.hover
var vy := 0.0
var crashed := false
var spin_v := 0.0
var call_cd := 0.0
var calls := 0
var called := false
var burst_n := 0
var burst_t := 0.0
var strafe := 1.0
var strafe_t := 0.0
var bob_ph := 0.0
var last_gy := NAN                  # the last floor height seen under it (JS lastGy, undefined until then)
var burst_aim := Vector3.ZERO
var has_burst_aim := false          # JS this.burstAim is an object or null

# the gray family's variants change these (JS `this.shotCooldown ?? DRONE.cd` and friends)
var shot_cooldown := DRONE.cd
var shot_windup := DRONE.wind
var shot_gap := DRONE.gap
var shot_damage := DRONE.dmg
var shot_recovery := 0.4
var recovery_strafe := 0.8
var lock_burst_aim := false


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super(w, p_id, p_x, p_z, p_y, o)
	drone = true
	hover = DRONE.hover
	r = DRONE.r
	h = DRONE.h
	max = DRONE.hp
	hp = DRONE.hp
	voice = 1.5 + randf() * 0.3


func reset(first: bool) -> void:
	super(first)
	y = hy + 1.2                                                                # starts a little off the ground and lifts to its hover height
	vy = 0.0
	crashed = false
	spin_v = 0.0
	call_cd = DRONE.call_after + randf() * 3.0
	calls = 0
	called = false
	burst_n = 0
	burst_t = 0.0
	strafe = 1.0 if randf() < 0.5 else -1.0
	strafe_t = 1.0 + randf() * 2.0
	bob_ph = randf() * 6.0


func _free(px: float, pz: float) -> bool:
	if world.blocked(px, pz, y, h, r, 0.05):
		return false
	# world.drone_leash (levels over a void / magma): open air with no floor under it counts as a wall, so a drone never strays off the map
	return not (world.drone_leash and not is_nan(last_gy) and not (world.ground_height(px, pz, r, y + 0.2) > -INF))


func _die() -> void:
	super()
	vy = 2.5
	crashed = false
	kvx += hit_x * 5.0
	kvz += hit_z * 5.0
	spin_v = (-1.0 if randf() < 0.5 else 1.0) * (6.0 + randf() * 5.0)


## 360 degree sensor: range and a clear line from the middle of the body to the player's chest
func _look(dt: float, P: Player, _wide: bool) -> bool:
	vis_t -= dt
	if vis_t > 0.0:
		return sees
	vis_t = 0.14 + randf() * 0.06
	var dx := P.x - x
	var dz := P.z - z
	var d := sqrt(dx * dx + dz * dz)
	var oy := y + 0.45
	var dy := P.y + (0.8 if P.crouching else 1.15) - oy
	var ok := not P.dead and d <= DRONE.sight
	if ok:
		var L := sqrt(dx * dx + dy * dy + dz * dz)
		if L == 0.0:
			L = 1.0
		ok = world.ray_clear(x, oy, z, dx / L, dy / L, dz / L, L, 0.04) >= L - 0.5
	sees = ok
	return ok


## hold hover height above whatever is underneath (never into a ceiling)
func _alt(dt: float) -> void:
	var g := world.ground_height(x, z, r, y + 0.2)
	if g > -INF:
		last_gy = maxf(0.0, g)
	var gy := 0.0
	if g > -INF:
		gy = maxf(0.0, g)
	elif world.drone_leash:                                                     # leashed: over a gap it holds the last floor's height
		gy = 0.0 if is_nan(last_gy) else last_gy
	var want := gy + hover + sin(t * 1.7 + bob_ph) * 0.18
	vy += (clampf((want - y) * 2.2, -4.0, 4.0) - vy) * minf(1.0, 6.0 * dt)
	var ny := y + vy * dt
	if vy > 0.0 and world.blocked(x, z, ny, h, r, 0.05):
		vy = 0.0
	else:
		y = maxf(gy + 0.6, ny)


func _fly(dt: float, ang: float, speed: float, still: bool) -> void:
	if not _free(x, z):
		_unwedge()
	var k := minf(1.0, DRONE.accel * dt)
	var tx := 0.0 if still else sin(ang) * speed
	var tz := 0.0 if still else cos(ang) * speed
	vx += (tx - vx) * k
	vz += (tz - vz) * k
	var kd := exp(-DRONE.kv_decay * dt)
	kvx *= kd
	kvz *= kd
	var mx := (vx + kvx) * dt
	var mz := (vz + kvz) * dt
	if _free(x + mx, z):
		x += mx
	else:
		vx *= 0.2
		kvx *= -0.3
	if _free(x, z + mz):
		z += mz
	else:
		vz *= 0.2
		kvz *= -0.3
	var c := cos(yaw)
	var s := sin(yaw)
	var wx := vx + kvx
	var wz := vz + kvz
	lvz = wx * s + wz * c
	lvx = wx * c - wz * s


## keep a ring around the player and circle it, flipping direction every second or two; k scales the speed (slower while shooting)
func _strafe_move(dt: float, _P: Player, dx: float, dz: float, dist: float, k: float) -> void:
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe = -strafe
		strafe_t = 1.3 + randf() * 2.0
	var dd := dist if dist != 0.0 else 1.0
	var ux := dx / dd
	var uz := dz / dd
	var mid := (DRONE.min_d + DRONE.max_d) / 2.0
	var rv := clampf((dist - mid) * 0.9, -DRONE.speed, DRONE.speed)
	var tv := DRONE.speed * 0.8 * strafe
	var mx := ux * rv - uz * tv
	var mz := uz * rv + ux * tv
	var sp := sqrt(mx * mx + mz * mz)
	if sp == 0.0:
		sp = 1.0
	var ang := _steer(x + mx / sp * 3.0, z + mz / sp * 3.0)
	if not _free(x + sin(ang), z + cos(ang)):                                   # a wall ahead: circle the other way
		strafe = -strafe
	_fly(dt, ang, minf(DRONE.speed, sp) * k, false)


func _begin(_kind: StringName, _dist: float) -> void:
	atk = &"shot"
	shot_done = false
	slot = &"shot"
	a_u = 0.0
	has_burst_aim = false
	set_(&"windup")
	shot_cd = shot_cooldown + randf() * 1.2
	E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "windup", "x": x, "y": y, "z": z})


func _shoot(P: Player) -> void:
	var tx := P.x
	var ty := P.y
	var tz := P.z
	if lock_burst_aim and has_burst_aim:
		tx = burst_aim.x
		ty = burst_aim.y
		tz = burst_aim.z
	var s := sin(yaw)
	var c := cos(yaw)
	var sd := (1.0 if burst_n % 2 != 0 else -1.0) * 0.17
	var ox := x + s * 0.5 + c * sd
	var oz := z + c * 0.5 - s * sd
	var oy := y + 0.25
	var dx := tx - ox + (randf() - 0.5) * 0.3
	var dy := ty + 1.1 - oy
	var dz := tz - oz + (randf() - 0.5) * 0.3
	var l := sqrt(dx * dx + dy * dy + dz * dz)
	if l == 0.0:
		l = 1.0
	dx = dx / l + (randf() - 0.5) * DRONE.spread * 2.0
	dy = dy / l + (randf() - 0.5) * DRONE.spread * 2.0
	dz = dz / l + (randf() - 0.5) * DRONE.spread * 2.0
	var l2 := sqrt(dx * dx + dy * dy + dz * dz)
	if l2 == 0.0:
		l2 = 1.0
	E.fire(self, ox, oy, oz, dx / l2, dy / l2, dz / l2, {"dmg": shot_damage, "speed": DRONE.bolt_speed})


func _combat(dt: float, P: Player, dx: float, dz: float, dist: float, saw: bool) -> void:
	if known == null:
		set_(&"search")
		return
	if not saw and seen_t > Config.ai_lose_time + 3.0:
		set_(&"search")
		scan_t = 0.0
		return
	call_cd -= dt
	if saw and not P.dead and call_cd <= 0.0 and calls < DRONE.call_max and E.reinforce_room():       # stop and call for backup
		call_cd = DRONE.call_cd
		calls += 1
		called = false
		set_(&"call")
		E.push({"t": "drone_call", "id": id, "ph": "start", "x": x, "y": y, "z": z})
		return
	if saw and not P.dead and dist >= 4.0 and shot_cd <= 0.0 and E.slot_free(&"shot", self):
		_begin(&"shot", dist)
		return
	_strafe_move(dt, P, dx, dz, dist, 1.0)
	_face(dt, atan2(dx, dz) if saw else atan2(vx, vz), 6.0)


func _dead_step(dt: float, P: Player) -> void:
	dead_t += dt
	respawn_t -= dt
	lvx = 0.0
	lvz = 0.0
	if not crashed:                                                             # spinning down out of the sky
		vy -= 24.0 * dt
		y += vy * dt
		var kd := exp(-1.2 * dt)
		kvx *= kd
		kvz *= kd
		if _free(x + kvx * dt, z):
			x += kvx * dt
		if _free(x, z + kvz * dt):
			z += kvz * dt
		var g := world.ground_height(x, z, r, y + 0.6)
		var gy := g if g > -INF else -9.0
		if y <= gy or y < -8.0:
			y = maxf(gy, -8.0)
			crashed = true
			vy = 0.0
	else:
		# BUG-109 (tracker): a wreck that crashed onto a moving solid (the OMNISPHERE tram) stayed where it landed and hung in the air once the tram drove off. A crashed wreck now looks at the ground under it and falls on when it is gone. Godot only.
		var g2 := world.ground_height(x, z, r, y + 0.6)
		if y > -7.5 and (g2 if g2 > -INF else -9.0) < y - 0.3:      # (the -8 floor of a drone over nothing stays crashed)
			crashed = false
			vy = 0.0
	if respawn_t <= 0.0 and not no_respawn and U.hyp(P.x - hx, P.z - hz) > 8.0:
		_respawn()


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	state_t += dt
	flash = maxf(0.0, flash - dt * 5.0)
	wob = maxf(0.0, wob - dt * 2.5)
	t += dt
	flinch_t = maxf(0.0, flinch_t - dt)
	flinch_cd = maxf(0.0, flinch_cd - dt)
	immune_t = maxf(0.0, immune_t - dt)
	bcast_cd = maxf(0.0, bcast_cd - dt)
	ally_cd = maxf(0.0, ally_cd - dt)
	bark_cd = maxf(0.0, bark_cd - dt)
	shot_cd = maxf(0.0, shot_cd - dt)
	poise = maxf(0.0, poise - AI.poise_regen * dt)
	if state == &"dead":
		_dead_step(dt, P)
		return
	if Config.ai_freeze != 0 or dev_passive:
		_fly(dt, 0.0, 0.0, true)
		_alt(dt)
		return
	var dx := P.x - x
	var dz := P.z - z
	var dist := sqrt(dx * dx + dz * dz)
	var hostile_now := state != &"idle" and state != &"return"
	if P.dead and hostile_now and state != &"search" and state != &"stagger":
		slot = &""
		set_(&"search")
	var need_look := hostile_now and state != &"stagger"
	var saw := need_look and not P.dead and _look(dt, P, false)
	if not need_look:
		sees = false
	if saw:
		_know(P.x, P.z)
		seen_t = 0.0
	else:
		seen_t += dt
	match state:
		&"idle":
			if dist < maxf(Config.ai_notice_range, DRONE.notice) and not P.dead and _look(dt, P, false):
				alert_why = "sight"
				_know(P.x, P.z)
				set_(&"alert")
				E.barks.say(self, "alert")
			else:
				_fly(dt, 0.0, 0.0, true)
				_face(dt, yaw + sin(t * 0.6) * 0.5, 1.5)
		&"alert":
			_fly(dt, 0.0, 0.0, true)
			if known != null:
				_face(dt, atan2(known.x - x, known.z - z), 9.0)
			if state_t >= 0.45:
				set_(&"pursue")
		&"pursue":
			_combat(dt, P, dx, dz, dist, saw)
		&"windup":
			var u := minf(1.0, state_t / shot_windup)
			a_u = u
			if lock_burst_aim and u >= 0.65 and not has_burst_aim:
				burst_aim = Vector3(P.x, P.y, P.z)
				has_burst_aim = true
			_strafe_move(dt, P, dx, dz, dist, 0.35)
			if u < 0.8:                                                         # eye glow signals the aim lock
				var ax_ := burst_aim.x if has_burst_aim else P.x
				var az_ := burst_aim.z if has_burst_aim else P.z
				_face(dt, atan2(ax_ - x, az_ - z), 6.0)
			if u >= 1.0:
				burst_n = 0
				burst_t = 0.0
				set_(&"attack")
				E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "go", "x": x, "y": y, "z": z})
		&"attack":
			_strafe_move(dt, P, dx, dz, dist, 0.35)
			var ax_ := burst_aim.x if has_burst_aim else P.x
			var az_ := burst_aim.z if has_burst_aim else P.z
			_face(dt, atan2(ax_ - x, az_ - z), 3.0)
			burst_t -= dt
			a_u = float(burst_n) / float(DRONE.burst)
			if burst_n < DRONE.burst and burst_t <= 0.0:
				burst_n += 1
				burst_t = shot_gap
				_shoot(P)
			if burst_n >= DRONE.burst and burst_t <= -0.12:
				slot = &""
				set_(&"recover")
		&"recover":
			a_u = minf(1.0, state_t / shot_recovery)
			_strafe_move(dt, P, dx, dz, dist, recovery_strafe)
			if state_t >= shot_recovery:
				set_(&"pursue" if known != null and seen_t < Config.ai_lose_time else &"search")
		&"call":
			_fly(dt, 0.0, 0.0, true)
			_face(dt, atan2(dx, dz), 4.0)
			a_u = minf(1.0, state_t / DRONE.call_time)
			if not called and state_t >= DRONE.call_time * 0.5:
				called = true
				E.push({"t": "drone_call", "id": id, "ph": "arrive", "x": x, "y": y, "z": z, "pts": E.reinforce(self)})
			if state_t >= DRONE.call_time:
				set_(&"pursue")
		&"stagger":
			_fly(dt, 0.0, 0.0, true)
			if state_t >= 0.7:
				hit_heavy = false
				immune_t = AI.stagger_immune
				set_(&"pursue" if known != null else &"search")
		&"search":
			if saw and not P.dead:
				set_(&"pursue")
			else:
				var k := known
				var kd := U.hyp(k.x - x, k.z - z) if k != null else 0.0
				if k != null and kd > 2.0 and state_t < 4.0:
					_fly(dt, _steer(k.x, k.z), DRONE.speed * 0.6, false)
					_face(dt, atan2(vx, vz), 4.0)
				else:
					_fly(dt, 0.0, 0.0, true)
					_face(dt, yaw + sin(state_t * 1.4) * 0.9, 3.0)
				if state_t >= Config.ai_search_time:
					known = null
					set_(&"return")
		&"return":
			var d := U.hyp(hx - x, hz - z)
			if d < 0.8:
				_fly(dt, 0.0, 0.0, true)
				set_(&"idle")
			else:
				_fly(dt, _steer(hx, hz), DRONE.speed * 0.5, false)
				_face(dt, atan2(vx, vz), 4.0)
	_alt(dt)
