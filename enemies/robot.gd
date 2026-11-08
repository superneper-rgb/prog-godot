class_name Robot
extends Target
## Hostile robot, ported statement for statement from JS class Robot (index.html enemy.js). Pure simulation (no nodes): Enemies owns the list, RobotView draws it. Each Robot is a
## Target (so hitscan, rockets, punches and the hammer-fist slam already damage it) plus an AI state machine. The shopkeeper is NOT a Robot: he is a plain Target flagged `npc` and nothing here touches him.
##
##   idle (patrol) -> alert -> pursue -> windup -> attack -> recover -> pursue ...
##   pursue/search lose the player -> search (red) -> return (green) -> idle
##   any state -> stagger (heavy hit, with immunity afterwards) -> pursue;  any state -> dead (respawns after Config.ai_respawn)
##
## Alerts: only a robot that takes DIRECT damage (lethal or not) broadcasts, once per bcast_cd, to living robots inside Config.ai_alert_radius.
## Robots that are alerted by an ally never broadcast again, so an alert can never chain across the map.
## Events pushed to combat.events: robot_hit, robot_die, robot_state, robot_atk, bolt, bolt_hit, ai_alert, bark, player_hit, player_die.

## Where the robot thinks the player is (JS `this.known = { x, z }`). Written in place by _know(), so a seeing robot allocates nothing per frame.
class Known:
	static func at(px: float, pz: float) -> Known:
		var k := Known.new()
		k.x = px
		k.z = pz
		return k

	var x := 0.0
	var z := 0.0

var world: World
var E: Enemies = null
var blockout := false     # spawned by the level kit (JS r.blockout)
var gone := false         # removed by its level without dying (JS r.gone)
var num := 0
var hx := 0.0
var hz := 0.0
var hy := 0.0
var patrol := PackedVector2Array()   # one or two points; .x is x, .y is z
var ai: AiTable = AiTable.DEFAULT      # the numbers this enemy runs on (a kind can have its own)
var voice := 1.0
var aggr := 1.0
var orbit := 1.0
var side := 1.0

var yaw := 0.0
var vx := 0.0                        # velocity
var vz := 0.0
var lvx := 0.0                       # local-space speeds for the view (left / forward)
var lvz := 0.0
var state := &"idle"
var state_t := 0.0
var prev := &"idle"
var poise := 0.0
var flinch_t := 0.0
var flinch_cd := 0.0
var immune_t := 0.0
var hit_x := 0.0                     # direction the last hit pushed (world xz, unit), heavy?
var hit_z := 0.0
var hit_heavy := false
var last_dmg := 0.0
var known: Known = null
var pursue_hook := Callable()
var seen_t := 99.0
var sees := false
var los_t := 0.0
var vis_t := 0.0
var atk := &""
var a_u := 0.0
var hit_done := false
var shot_done := false
var aim := 0.0
var lock := 0.0
var shot_cd := 0.0
var slot := &""
var bcast_cd := 0.0
var ally_cd := 0.0
var bark_cd := 0.0
var last_line := ""
var wp := 0
var pause := 0.0
var scan_t := 0.0
var stuck_n := 0
var prog_t := 0.0
var prog_d := 0.0
var unstick_t := 0.0
var unstick_dir := 1.0
var stuck_at := -99.0
var last_x := 0.0
var last_z := 0.0
var dead_t := 0.0
var was_hit := false
var alert_why := ""
var ledge_t := 0.0

# optional in the JS (read with !!r.x or `!== false` there); plain fields here. Spawners and the other enemy kinds set them.
var drone := false
var no_respawn := false              # once killed it stays dead (dev console / DEV level spawns)
var look_muted := false
var entering := false                # on its way in through a door or a hatch (levels/mothership/ms_entrances.gd)
var entry: Variant = null            # what walks it in; Enemies.update asks this first
var dev_passive := false             # the DEV level's training dummy
var ledge_safe := true               # false: walks off drops
var mute := false                    # the prophet's meat followers only squelch
var bark_set: Dictionary = {}        # some enemies bring their own lines
var speech := false
var name := ""
var alien := false
var meat := false
var human := false
var follower := false
var zone: Variant = null             # the level's fighting zone (JS r.zone): { x, z, leash, ... }
var owner: Robot = null              # who summoned it (JS o.owner): the prophet's flock
var no_leash := false                # the level does not pull this one back to its zone (JS noLeash)
var corpse_t := 0.0                  # how long the level keeps its corpse; 0 = the level's default (JS corpseT)
var worm := false
var wretch := false
var crawler := false
var mimic := false
var reinf := false                   # called in by a Gun Drone
var wave := false                    # belongs to the arena's wave spawner
var counted := false
var visual_scale := 0.0              # the view's size if not 0
var heavy_kind := ""                  # which of the FOINT heavies (assault / suppression / elite): the view's batch
var foint_heavy := false             # FOINT heavies (heavy-ai.js): stride-matched walk in the view
var yaw_rate := 0.0
var hv := &""                        # FOINT heavy special pose (levels/omnisphere/heavy.js)
var fire_t := 0.0
var shield_t := 0.0                  # a Consigliere covers this enemy (set every frame it does)
var shield_by := -1

## red whenever the robot is damaged, alerted, chasing or attacking; green only at rest (idle / returning home); dark when dead
var light: StringName:
	get:
		if dead:
			return &"off"
		return &"green" if state == &"idle" or state == &"return" else &"red"
var hostile: bool:
	get:
		return light == &"red"
var token_kind: StringName:
	get:
		return atk if state == &"windup" or state == &"attack" else &""
## padK: walking flesh enemies keep a little extra clearance so their limbs and tendrils do not poke into walls
var pad_k: float:
	get:
		return 1.15 if meat and not wretch and not crawler and not mimic else 1.0


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super(p_id, p_x, p_z, p_y, {"r": ai.r, "h": ai.h, "max": ai.hp, "hp": ai.hp, "ax": float(o.get("ax", 0.0)), "az": float(o.get("az", 0.0))})
	robot = true
	world = w
	owner = o.get("owner")
	num = p_id + 1
	hx = p_x
	hz = p_z
	hy = p_y
	var a := Vector2(p_x + ax, p_z + az)
	var b := Vector2(p_x - ax, p_z - az)
	if U.hyp(ax, az) > 0.3 and not w.blocked(a.x, a.y, p_y, ai.h, ai.r, ai.step) and not w.blocked(b.x, b.y, p_y, ai.h, ai.r, ai.step):
		patrol = PackedVector2Array([a, b])
	else:
		patrol = PackedVector2Array([Vector2(p_x, p_z)])
	voice = 0.8 + randf() * 0.5
	aggr = 0.45 + randf() * 0.55
	orbit = 1.0 if randf() < 0.5 else -1.0
	side = 1.0 if randf() < 0.5 else -1.0
	reset(true)


func reset(first: bool) -> void:
	x = hx
	z = hz
	y = hy
	hp = max
	dead = false
	yaw = atan2(ax, az) + (randf() - 0.5) if first else yaw
	vx = 0.0
	vz = 0.0
	kvx = 0.0
	kvz = 0.0
	lvx = 0.0
	lvz = 0.0
	state = &"idle"
	state_t = 0.0
	prev = &"idle"
	poise = 0.0
	flinch_t = 0.0
	flinch_cd = 0.0
	immune_t = 0.0
	flash = 0.0
	hit_x = 0.0
	hit_z = 0.0
	hit_heavy = false
	last_dmg = 0.0
	known = null
	seen_t = 99.0
	sees = false
	los_t = 0.0
	vis_t = 0.0
	atk = &""
	a_u = 0.0
	hit_done = false
	shot_done = false
	aim = 0.0
	lock = 0.0
	shot_cd = 1.0 + randf() * 2.0
	slot = &""
	bcast_cd = 0.0
	ally_cd = 0.0
	bark_cd = 0.0
	last_line = ""
	wp = 0
	pause = 1.0 + randf() * 2.0
	scan_t = 0.0
	stuck_n = 0
	prog_t = 0.0
	prog_d = 0.0
	unstick_t = 0.0
	unstick_dir = 1.0
	stuck_at = -99.0
	last_x = x
	last_z = z
	dead_t = 0.0
	respawn_t = 0.0
	was_hit = false
	alert_why = ""


func set_(s: StringName) -> void:
	if state == s:
		return
	prev = state
	state = s
	state_t = 0.0
	stuck_n = 0
	prog_t = 0.0
	prog_d = 0.0
	unstick_t = 0.0
	E.push({"t": "robot_state", "id": id, "from": prev, "to": s, "x": x, "y": y, "z": z})


## JS `this.known = { x, z }`
func _know(kx_: float, kz_: float) -> void:
	if known == null:
		known = Known.new()
	known.x = kx_
	known.z = kz_


# ---------------------------------------------------------------- perception
## can this robot see the player right now?  Field of view + range + a line-of-sight ray (throttled).
func _look(dt: float, P: Player, wide: bool) -> bool:
	if look_muted:      # (levels/_kit/stealth.gd: unaware, the meter decides, not the stock instant spot)
		sees = false
		return false
	vis_t -= dt
	if vis_t > 0.0:
		return sees
	vis_t = 0.14 + randf() * 0.06
	var dx := P.x - x
	var dz := P.z - z
	var d := sqrt(dx * dx + dz * dz)
	var ok := not P.dead and d <= Config.ai_sight and absf(P.y - y) < 14.0
	if ok and not wide and d > 3.5:
		ok = absf(U.wrap_angle(atan2(dx, dz) - yaw)) < 1.25                     # ~140 degree cone; anything very close is felt regardless of facing
	if ok:
		var oy := y + 1.75
		var ty := P.y + (0.8 if P.crouching else 1.15)
		var dy := ty - oy
		var L := sqrt(dx * dx + dy * dy + dz * dz)
		if L == 0.0:
			L = 1.0
		ok = world.ray_clear(x, oy, z, dx / L, dy / L, dz / L, L, 0.04) >= L - 0.5
	sees = ok
	return ok


# ---------------------------------------------------------------- movement
func _free(px: float, pz: float) -> bool:
	return not world.blocked(px, pz, y, ai.h, ai.r * pad_k, ai.step)


func _clear(a: float, look: float, ledge: bool) -> bool:
	var s := sin(a)
	var c := cos(a)
	return _free(x + s * look, z + c * look) and _free(x + s * look * 1.9, z + c * look * 1.9) and (not ledge or _edge_ok(s, c))


## unit heading toward (tx,tz) that avoids walls by probing ahead; keeps its chosen side so it does not dither
func _steer(tx: float, tz: float) -> float:
	var base := atan2(tx - x, tz - z)
	const look := 0.85
	var ledge := ledge_safe
	var a := base
	if unstick_t > 0.0:
		a = base + unstick_dir * 1.45
	elif not _clear(base, look, ledge):
		a = base
		for off: float in [0.5, 1.0, 1.55, 2.2]:
			if _clear(base + off * side, look, ledge):
				a = base + off * side
				break
			if _clear(base - off * side, look, ledge):
				a = base - off * side
				side = -side
				break
	return a


## if the body ended up overlapping geometry (e.g. a step it stood on dropped away), slide it to the nearest free spot
func _unwedge() -> bool:
	for rad: float in [0.12, 0.25, 0.4, 0.6, 0.85, 1.2]:
		for k in 8:
			var a := k * PI / 4.0 + stuck_n
			var nx := x + sin(a) * rad
			var nz := z + cos(a) * rad
			if _free(nx, nz):
				x = nx
				z = nz
				return true
	return false


## is the ground 0.8 m ahead along (dx,dz) a safe walk (no cliff, no pit)?  A robot already airborne is never blocked.
func _edge_ok(dx: float, dz: float) -> bool:
	var s := sqrt(dx * dx + dz * dz)
	if s < 0.3:
		return true
	var W := world
	var here := W.ground_height(x, z, ai.r * 0.8, y + ai.step)
	if not (here > y - 0.35):
		return true
	var ex := x + dx / s * 0.8
	var ez := z + dz / s * 0.8
	var g := W.ground_height(ex, ez, ai.r * 0.8, y + ai.step)
	return g > -INF and g > y - 1.0


## move with velocity smoothing + axis-separated collision; follows the ground (steps up, drops down)
func _go(dt: float, ang: float, speed: float, still: bool) -> void:
	if not _free(x, z):
		_unwedge()
	var k := minf(1.0, ai.accel * dt)
	var tx := 0.0 if still else sin(ang) * speed
	var tz := 0.0 if still else cos(ang) * speed
	vx += (tx - vx) * k
	vz += (tz - vz) * k
	var kd := exp(-6.5 * dt)
	kvx *= kd
	kvz *= kd
	# Ledge guard: a walker never chooses to step off a drop. Knockback can still throw it over.
	if not still and ledge_safe and not _edge_ok(vx, vz):
		if _edge_ok(vx, 0.0):
			vz = 0.0
		elif _edge_ok(0.0, vz):
			vx = 0.0
		else:
			vx *= 0.2
			vz *= 0.2
		ledge_t = 0.5
	var mx := (vx + kvx) * dt
	var mz := (vz + kvz) * dt
	var x0 := x
	var z0 := z
	if _free(x + mx, z):
		x += mx
	else:
		vx *= 0.2
		kvx = 0.0
	if _free(x, z + mz):
		z += mz
	else:
		vz *= 0.2
		kvz = 0.0
	var g := world.ground_height(x, z, ai.r * 0.8, y + ai.step)
	if g > -INF:
		y = minf(g, y + 5.0 * dt) if g > y else maxf(g, y - 12.0 * dt)
	# stuck recovery: wanted to move but did not get anywhere -> side-step for a moment; repeated failures end the chase (see callers)
	var want := 0.0 if still else speed
	if want > 0.8 and unstick_t <= 0.0:
		prog_t += dt
		prog_d += sqrt((x - x0) * (x - x0) + (z - z0) * (z - z0))
		if prog_t >= 0.7:
			if prog_d < want * 0.7 * 0.22:
				stuck_n += 1
				unstick_t = 0.9
				unstick_dir = 1.0 if randf() < 0.5 else -1.0
				stuck_at = E.t
			elif prog_d > want * 0.7 * 0.6:
				stuck_n = maxi(0, stuck_n - 1)
			prog_t = 0.0
			prog_d = 0.0
	elif want <= 0.8:
		prog_t = 0.0
		prog_d = 0.0
	unstick_t = maxf(0.0, unstick_t - dt)
	# local-space speeds drive the walk cycle in the view
	var c := cos(yaw)
	var s := sin(yaw)
	var wx := vx + kvx
	var wz := vz + kvz
	lvz = wx * s + wz * c                                                       # forward / left
	lvx = wx * c - wz * s


func _face(dt: float, ang: float, rate: float) -> void:
	yaw = U.damp_angle(yaw, ang, rate, dt)


func _face_err(px: float, pz: float) -> float:
	return absf(U.wrap_angle(atan2(px - x, pz - z) - yaw))


# ---------------------------------------------------------------- events from combat
## called by Combat.damage after hp was reduced. `kill` = this hit was lethal.
func hurt(amount: float, from: Variant, kb: float, pt: Variant, kill: bool) -> void:
	var P: Player = E.P
	var dx: float = x - from.x
	var dz: float = z - from.z
	var l := sqrt(dx * dx + dz * dz)
	if l == 0.0:
		l = 1.0
	hit_x = dx / l
	hit_z = dz / l
	last_dmg = amount
	flash = 1.0
	var heavy_hit := amount >= Config.ai_stagger_dmg or kb >= 6.0
	E.barks.say(self, "die" if kill else "pain")                                # its own line first, so it is not crowded out by the allies' alert call-outs
	# every hit alerts nearby robots (lethal ones too); the light goes red at once even if the robot is about to die
	if bcast_cd <= 0.0 or kill:
		E.broadcast(self, kill)
		bcast_cd = 0.6
	if P != null:
		_know(P.x, P.z)
	seen_t = 0.0
	E.push({"t": "robot_hit", "id": id, "x": x, "y": y, "z": z, "dx": hit_x, "dz": hit_z, "heavy": heavy_hit, "amount": amount, "pt": pt, "kill": kill, "alien": alien, "meat": meat, "human": human})
	if kill:
		_die()
		return
	kvx += hit_x * kb * 0.9
	kvz += hit_z * kb * 0.9
	poise += amount
	if flinch_cd <= 0.0:
		flinch_t = ai.flinch
		flinch_cd = ai.flinch_cd
	if state == &"idle" or state == &"return" or state == &"search":
		alert_why = "hit"
		set_(&"alert")
		state_t = ai.alert_delay * 0.45
	var armoured := state == &"attack"                                          # the swing / shot itself cannot be cancelled, only flinched
	if not armoured and state != &"stagger" and immune_t <= 0.0 and (poise >= ai.poise_max or heavy_hit):
		hit_heavy = true
		poise = 0.0
		slot = &""
		set_(&"stagger")
		kvx += hit_x * (2.5 + kb * 0.6)
		kvz += hit_z * (2.5 + kb * 0.6)


## an ally was damaged nearby. Never rebroadcasts.
func on_ally(src: Robot, pos: Player) -> void:
	ally_cd = 1.5
	if pos != null:
		_know(pos.x, pos.z)
		seen_t = 0.0
	if state == &"idle" or state == &"return" or state == &"search":
		alert_why = "ally #" + str(src.num)
		set_(&"alert")
		E.barks.say(self, "alert")


func _die() -> void:
	dead = true
	hp = 0.0
	respawn_t = Config.ai_respawn
	dead_t = 0.0
	slot = &""
	set_(&"dead")
	E.push({"t": "robot_die", "id": id, "x": x, "y": y, "z": z, "dx": hit_x, "dz": hit_z, "heavy": hit_heavy or last_dmg >= Config.ai_stagger_dmg, "alien": alien, "meat": meat, "human": human, "follower": follower, "worm": worm})


# ---------------------------------------------------------------- the state machine
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
	poise = maxf(0.0, poise - ai.poise_regen * dt)
	if state == &"dead":
		dead_t += dt
		respawn_t -= dt
		vx = 0.0
		vz = 0.0
		_go(dt, 0.0, 0.0, true)
		if respawn_t <= 0.0 and not no_respawn and U.hyp(P.x - hx, P.z - hz) > 8.0:
			_respawn()
		return
	if Config.ai_freeze != 0 or dev_passive:                                    # dev_passive: the DEV level's training dummy
		_go(dt, 0.0, 0.0, true)
		return
	var dx := P.x - x
	var dz := P.z - z
	var dist := sqrt(dx * dx + dz * dz)
	var hostile_now := state != &"idle" and state != &"return"
	# dead player: everyone loses interest (search, then go home)
	if P.dead and hostile_now and state != &"search" and state != &"stagger":
		slot = &""
		set_(&"search")
	var need_look := state != &"idle" and state != &"return" and state != &"stagger"          # line-of-sight rays only while the robot actually cares
	var saw := need_look and not P.dead and _look(dt, P, state == &"pursue" or state == &"search" or state == &"recover")
	if not need_look:
		sees = false
	if saw:
		_know(P.x, P.z)
		seen_t = 0.0
	else:
		seen_t += dt
	match state:
		&"idle":
			# optional spotting (off by default: robots are target dummies until attacked)
			if Config.ai_notice_range > 0.0 and dist < Config.ai_notice_range and not P.dead and _look(dt, P, false):
				alert_why = "sight"
				_know(P.x, P.z)
				set_(&"alert")
				E.barks.say(self, "alert")
			else:
				_patrol(dt)
		&"alert":
			_go(dt, 0.0, 0.0, true)
			if known != null:
				_face(dt, atan2(known.x - x, known.z - z), 9.0)
			if state_t >= ai.alert_delay:
				set_(&"pursue")
		&"pursue":
			_pursue(dt, P, dx, dz, dist, saw)
		&"windup":
			_go(dt, 0.0, 0.0, true)
			var mel := atk == &"melee"
			var dur := ai.m_wind if mel else ai.s_wind
			var u := minf(1.0, state_t / dur)
			a_u = u
			if u < (0.7 if mel else 0.78):
				_face(dt, atan2(dx, dz), 3.2)                                   # tracks, then LOCKS so the player can dodge the telegraphed attack
			if atk == &"shot":
				aim = clampf(atan2(P.y + 1.1 - (y + 1.62), maxf(0.5, dist)), -0.5, 0.6)
			if u >= 1.0:
				set_(&"attack")
				E.push({"t": "robot_atk", "id": id, "kind": atk, "ph": "go", "x": x, "y": y, "z": z})
		&"attack":
			_attack(dt, P, dx, dz, dist)
		&"recover":
			var dur := ai.m_rec if atk == &"melee" else ai.s_rec
			a_u = minf(1.0, state_t / dur)
			_go(dt, 0.0, 0.0, true)
			if state_t >= dur:
				slot = &""
				set_(&"pursue" if known != null and seen_t < Config.ai_lose_time else &"search")
		&"stagger":
			_go(dt, 0.0, 0.0, true)
			if state_t >= ai.stagger:
				hit_heavy = false
				immune_t = ai.stagger_immune
				set_(&"pursue" if known != null else &"search")
		&"search":
			_search(dt, P, saw)
		&"return":
			var home_x := patrol[0].x
			var home_z := patrol[0].y
			var d := U.hyp(home_x - x, home_z - z)
			if d < 0.7:
				_go(dt, 0.0, 0.0, true)
				wp = 0
				pause = 1.2
				set_(&"idle")
			else:
				_go(dt, _steer(home_x, home_z), ai.walk, false)
				_face(dt, atan2(vx, vz), 5.0)
				if stuck_n >= 4 and not sees:                                   # last resort when the way home is blocked
					x = home_x
					z = home_z
					y = hy
					stuck_n = 0
					E.push({"t": "robot_warp", "id": id})
	# keep the shown local speeds sane even when standing
	if state != &"dead":
		last_x = x
		last_z = z


func _respawn() -> void:
	reset(false)
	flash = 1.0
	E.push({"t": "respawn", "x": x, "y": y, "z": z, "id": id})


func _patrol(dt: float) -> void:
	if patrol.size() < 2:
		_go(dt, 0.0, 0.0, true)
		scan_t += dt
		return
	if pause > 0.0:
		pause -= dt
		_go(dt, 0.0, 0.0, true)
		scan_t += dt
		return
	var w_ := patrol[wp]
	var d := U.hyp(w_.x - x, w_.y - z)
	if d < 0.6 or stuck_n >= 2:
		wp = 1 - wp
		pause = 1.2 + randf() * 2.2
		stuck_n = 0
		return
	_go(dt, _steer(w_.x, w_.y), ai.walk, false)
	_face(dt, atan2(vx, vz), 3.5)


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, saw: bool) -> void:
	if pursue_hook.is_valid():      # a level's own brain (OMNISPHERE's heavies)
		pursue_hook.call(dt, P, dx, dz, dist, saw)
		return
	var k := known
	if k == null:
		set_(&"search")
		return
	# lost the player for too long -> go to where he was last seen, then search there
	var kd := U.hyp(k.x - x, k.z - z)
	if not saw and (seen_t > Config.ai_lose_time and kd < 1.6 or seen_t > Config.ai_lose_time + 6.0 or stuck_n >= 4):
		set_(&"search")
		scan_t = 0.0
		return
	var face_ok := _face_err(P.x, P.z) < 0.45
	# choose an attack when the player is visible and a slot is free
	if saw and not P.dead:
		if dist <= ai.reach + 0.5 and face_ok and E.slot_free(&"melee", self):
			_begin(&"melee", dist)
			return
		if dist >= ai.s_min and dist <= ai.s_max and shot_cd <= 0.0 and face_ok and randf() < dt * 4.0 * aggr and E.slot_free(&"shot", self):
			_begin(&"shot", dist)
			return
	# movement: close to melee range; hold a ring when the melee slots are taken; ranged robots keep coming but pause for a shot
	var tx := k.x
	var tz := k.z
	var speed := ai.run
	var still := false
	if saw:
		if dist < ai.reach * 0.75:                                              # never walk into the player
			still = true
		elif dist < 4.2 and not E.slot_free(&"melee", self):                    # melee slots full: circle at a distance instead of piling in
			var a := atan2(x - P.x, z - P.z) + orbit * 0.9
			tx = P.x + sin(a) * 3.6
			tz = P.z + cos(a) * 3.6
			speed = ai.walk * 1.4
	_go(dt, _steer(tx, tz), speed, still)
	var face_a := atan2(dx, dz) if saw else atan2(vx, vz)
	if saw or sqrt(vx * vx + vz * vz) > 0.3:
		_face(dt, face_a, 7.5)


func _begin(kind: StringName, _dist: float) -> void:
	atk = kind
	hit_done = false
	shot_done = false
	slot = kind
	a_u = 0.0
	set_(&"windup")
	wob = 0.0
	if kind == &"shot":
		shot_cd = ai.s_cd + randf() * 1.2
	E.push({"t": "robot_atk", "id": id, "kind": kind, "ph": "windup", "x": x, "y": y, "z": z})


func _attack(dt: float, P: Player, dx: float, dz: float, dist: float) -> void:
	var mel := atk == &"melee"
	var dur := ai.m_act if mel else ai.s_act
	a_u = minf(1.0, state_t / dur)
	if mel:
		# short lunge forward during the swing
		var f := 3.2 if state_t < 0.2 else 0.0
		_go(dt, yaw, f, f == 0.0)
		# damage exactly once, at one moment in the swing: needs reach, facing, height and a clear line to the chest
		if not hit_done and state_t >= ai.m_hit:
			hit_done = true
			var reach := ai.reach + Config.radius
			var fc := absf(U.wrap_angle(atan2(dx, dz) - yaw))
			var ok := not P.dead and dist <= reach and fc < 0.85 and absf((P.y + 0.9) - (y + 1.0)) < 1.5
			if ok:
				var L := maxf(0.01, dist - 0.2)
				var oy := y + 1.2
				var dd := dist if dist != 0.0 else 1.0
				ok = world.ray_clear(x, oy, z, dx / dd, 0.0, dz / dd, L, 0.05) >= L - 0.05
			E.push({"t": "robot_atk", "id": id, "kind": "melee", "ph": "hit" if ok else "miss", "x": x + sin(yaw) * 1.4, "y": y + 1.0, "z": z + cos(yaw) * 1.4})
			if ok:
				E.c.hurt_player(P, ai.m_dmg, x, z, "melee")
	else:
		_go(dt, 0.0, 0.0, true)
		if not shot_done:                                                       # fire exactly one bolt
			shot_done = true
			var s := sin(yaw)
			var c := cos(yaw)
			var ox := x + s * 1.15 + c * 0.5
			var oz := z + c * 1.15 - s * 0.5
			var oy := y + 1.62
			var ddx := P.x - ox
			var ddy := P.y + 1.1 - oy
			var ddz := P.z - oz
			var L := sqrt(ddx * ddx + ddy * ddy + ddz * ddz)
			if L == 0.0:
				L = 1.0
			E.fire(self, ox, oy, oz, ddx / L, ddy / L, ddz / L)
	if state_t >= dur:
		set_(&"recover")


func _search(dt: float, P: Player, saw: bool) -> void:
	var k := known
	if saw and not P.dead:
		set_(&"pursue")
		return
	var kd := U.hyp(k.x - x, k.z - z) if k != null else 0.0
	if k != null and kd > 1.4 and state_t < 3.0 and stuck_n < 3:
		_go(dt, _steer(k.x, k.z), ai.walk * 1.5, false)
		_face(dt, atan2(vx, vz), 5.0)
	else:
		_go(dt, 0.0, 0.0, true)
		scan_t += dt
		_face(dt, yaw + sin(state_t * 1.4) * 0.9, 3.0)                          # stands and sweeps left / right
	if state_t >= Config.ai_search_time:
		known = null
		set_(&"return")
