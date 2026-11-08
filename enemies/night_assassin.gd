class_name NightAssassin
extends Robot
## NIGHT ASSASSIN (JS enemies/night-assassin.js): a human contract killer: black stealth suit, ninja hood and mask, four-tube night vision goggles (green glow).
##   Pistol   a suppressed Beretta. He keeps 8-15 m, circle-strafing; plants, raises the pistol (the goggles brighten) and DOUBLE-TAPS: two quiet, fast rounds.
##   Knife    get inside ~5 m and he draws a tanto from his chest sheath, drops into a crouch (the goggles flare) and DASHES at you in a straight line. A hit cuts and STUNS you for 1 s (no moving, jumping, shooting or powers); he kicks off you into a BACKFLIP and lands ~4 m away. A miss: he skids past, off balance and open for a moment. While the knife is on cooldown he backs off to pistol range.
##   Flips    every 3.5-6.5 s he may reposition with a side aerial (~3.8 m left or right, whichever is clear), and 35 % of the time he flips out of the way when shot. Crowded while the knife recharges, he backflips away instead.
##   Silent   no barks, no beeps. He spots you on his own (view cone + line of sight) inside 24 m.
## MOVE SET -- telegraph > commit > strike > recovery (seconds):
##   DOUBLE TAP  windup 0.45 (pistol up, tracks you) > attack (shots at 0 and 0.16) > recover 0.35.
##   KNIFE DASH  windup 0.40 (knife drawn by 0.18, crouch, tracks until 78 % then LOCKS) > dash 17 m/s up to 7 m > hit: 14 damage + 1 s stun, backflip 0.55 s > land, recover 0.3 | miss: skid, recover 0.9. Cooldown 3.2 s.
## The JS swaps its numbers into the shared AI table around each update; he holds his own table here, kept current in update().

const ASSASSIN_HP := 90.0
const ASSASSIN_SPEED := 5.2
const ASSASSIN_NOTICE := 24.0
const ASSASSIN_KEEP_MIN := 8.0
const ASSASSIN_KEEP_MAX := 15.0
const ASSASSIN_SHOT_WIND := 0.45
const ASSASSIN_SHOT_GAP := 0.16
const ASSASSIN_SHOT_DMG := 6.0
const ASSASSIN_SHOT_SPEED := 44.0
const ASSASSIN_SHOT_CD_MIN := 2.4
const ASSASSIN_SHOT_CD_MAX := 3.6
const ASSASSIN_SHOT_MIN := 4.5
const ASSASSIN_SHOT_MAX := 26.0
const ASSASSIN_DASH_RANGE := 5.0
const ASSASSIN_DASH_WIND := 0.4
const ASSASSIN_DASH_SPEED := 17.0
const ASSASSIN_DASH_DIST := 7.0
const ASSASSIN_DASH_DMG := 14.0
const ASSASSIN_STUN := 1.0
const ASSASSIN_DASH_CD := 3.2
const ASSASSIN_FLIP_TIME := 0.55
const ASSASSIN_FLIP_DIST := 4.2
const ASSASSIN_FLIP_HEIGHT := 1.2
const ASSASSIN_MISS_REC := 0.9
const ASSASSIN_STRAFE_SPEED := 4.4
const ASSASSIN_EVADE_CD_MIN := 3.5
const ASSASSIN_EVADE_CD_MAX := 6.5
const ASSASSIN_EVADE_DIST := 3.8
const ASSASSIN_EVADE_TIME := 0.6
const ASSASSIN_DODGE_CHANCE := 0.35
const A_R := 0.45
const A_H := 1.85


## JS this.dash
class Dash:
	var ph := &"dash"
	var d := 0.0
	var t := 0.0
	var hit := false
	var missed := false
	var dx := 0.0
	var dz := 0.0
	var bx := 0.0
	var bz := 0.0


var assassin := true
var dash: Dash = null
var dash_cd := 0.8
var flip_u := 0.0
var flip_kind := &""
var shots := 0
var recoil_t := 0.0
var ev_dx := 0.0
var ev_dz := 0.0
var ev_t := 0.0
var evade_cd := 0.0
var strafe := 1.0
var strafe_t := 0.0


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = A_R
	ai.h = A_H
	ai.walk = 1.8
	ai.run = ASSASSIN_SPEED
	ai.accel = 16.0
	ai.alert_delay = 0.25
	ai.reach = 1.2
	ai.s_act = 99.0
	ai.flinch = 0.2
	ai.stagger = 0.6
	ai.stagger_immune = 1.4
	ai.poise_max = 45.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	human = true
	name = "NIGHT ASSASSIN"
	mute = true
	speech = false
	r = A_R
	h = A_H
	max = ASSASSIN_HP
	hp = ASSASSIN_HP


func reset(first: bool) -> void:
	super.reset(first)
	dash = null
	dash_cd = 0.8
	flip_u = 0.0
	flip_kind = &""
	shots = 0
	recoil_t = 0.0
	evade_cd = _rnd(2.0, 4.0)
	strafe = 1.0 if randf() < 0.5 else -1.0
	strafe_t = _rnd(1.0, 2.2)
	shot_cd = _rnd(0.8, 1.6)


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	dash_cd -= dt
	evade_cd -= dt
	recoil_t = maxf(0.0, recoil_t - dt)
	if state != &"attack":
		flip_u = 0.0
		flip_kind = &""
	# he hunts: spots the player on his own (the stock robots wait to be shot at)
	if state == &"idle" and P != null and not P.dead and Config.ai_freeze == 0 and not dev_passive and Vector2(P.x - x, P.z - z).length() < ASSASSIN_NOTICE and _look(dt, P, false):
		known = Known.at(P.x, P.z)
		seen_t = 0.0
		alert_why = "sight"
		set_(&"alert")
	var dashing := atk == &"dash"
	ai.s_wind = ASSASSIN_DASH_WIND if dashing else ASSASSIN_SHOT_WIND
	ai.s_rec = (ASSASSIN_MISS_REC if dash != null and dash.missed else 0.3) if dashing else (0.22 if atk == &"evade" else 0.35)
	super.update(dt, en, P)


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	var k := known
	if k == null:
		set_(&"search")
		return
	var kd := Vector2(k.x - x, k.z - z).length()
	if not sees and ((seen_t > Config.ai_lose_time and kd < 1.6) or seen_t > Config.ai_lose_time + 6.0 or stuck_n >= 4):
		set_(&"search")
		scan_t = 0.0
		return
	var err := _face_err(P.x, P.z)
	if sees and not P.dead:
		if dist <= ASSASSIN_DASH_RANGE and dash_cd <= 0.0 and err < 0.6 and absf(P.y - y) < 1.5 and E.slot_free(&"melee", self):
			_begin(&"dash", dist)
			return
		if dist >= ASSASSIN_SHOT_MIN and dist <= ASSASSIN_SHOT_MAX and shot_cd <= 0.0 and err < 0.35 and E.slot_free(&"shot", self):
			_begin(&"shot", dist)
			return
		if evade_cd <= 0.0:      # reposition with a flip: back off when crowded and the knife is out of play, else a side aerial now and then
			if dist < ASSASSIN_DASH_RANGE + 1.5 and dash_cd > 0.0:
				if _evade(P, true):
					return
			elif dist > 4.0 and randf() < dt * 0.9 and _evade(P, false):
				return
	var tx := k.x
	var tz := k.z
	var speed := ASSASSIN_SPEED
	if sees:
		var away := atan2(x - P.x, z - P.z)
		if dist < ASSASSIN_DASH_RANGE + 1.5 and dash_cd > 0.0:      # knife on cooldown: back off to pistol range, angled to one side
			var a := away + strafe * 0.6
			tx = x + sin(a) * 3.0
			tz = z + cos(a) * 3.0
			speed = ASSASSIN_SPEED * 0.85
		elif dist < ASSASSIN_DASH_RANGE + 1.5:      # you came close: close the last metres for the knife
			speed = ASSASSIN_SPEED
		elif dist <= ASSASSIN_KEEP_MAX + 2.0:      # in his band: circle-strafe, drifting to keepMin..keepMax
			strafe_t -= dt
			if strafe_t <= 0.0:
				strafe = -strafe
				strafe_t = _rnd(1.2, 2.6)
			var a := away + strafe * 0.4
			var rr := clampf(dist, ASSASSIN_KEEP_MIN, ASSASSIN_KEEP_MAX)
			tx = P.x + sin(a) * rr
			tz = P.z + cos(a) * rr
			speed = ASSASSIN_STRAFE_SPEED
			if not _free(x + sin(a + strafe * 1.57) * 0.9, z + cos(a + strafe * 1.57) * 0.9):      # a wall that way: go the other way
				strafe = -strafe
	var ang := _steer(tx, tz)
	_go(dt, ang, speed, Vector2(tx - x, tz - z).length() < 0.3)
	_face(dt, atan2(dx, dz) if sees else atan2(vx, vz), 9.0)


func _begin(kind: StringName, dist: float) -> void:
	if kind == &"shot":
		super._begin(&"shot", dist)
		shot_cd = _rnd(ASSASSIN_SHOT_CD_MIN, maxf(ASSASSIN_SHOT_CD_MIN, ASSASSIN_SHOT_CD_MAX))
		shots = 0
		return
	atk = &"dash"
	slot = &"melee"
	a_u = 0.0
	dash = null
	hit_done = false
	set_(&"windup")
	wob = 0.0
	E.push({"t": "robot_atk", "id": id, "kind": "dash", "ph": "windup", "x": x, "y": y, "z": z})


## reposition: a side aerial (left or right, whichever is clear of walls and drops) or a backflip straight away from the player. No windup: it is a dodge.
func _evade(P: Player, back: bool) -> bool:
	var ax := x - P.x
	var az := z - P.z
	var l := Vector2(ax, az).length()
	if l == 0.0:
		l = 1.0
	var ux := ax / l
	var uz := az / l
	var opts: Array = []
	if back:
		opts = [[ux, uz, &"back"]]
	else:
		for s: float in ([1.0, -1.0] if randf() < 0.5 else [-1.0, 1.0]):      # (-uz, ux) = his left while he faces the player
			opts.append([-uz * s, ux * s, &"sideL" if s > 0.0 else &"sideR"])
	for o: Array in opts:
		var odx: float = o[0]
		var odz: float = o[1]
		var ok := true
		for d: float in [1.0, 2.0, ASSASSIN_EVADE_DIST]:
			if not _free(x + odx * d, z + odz * d):
				ok = false
				break
		var g: float = world.ground_height(x + odx * ASSASSIN_EVADE_DIST, z + odz * ASSASSIN_EVADE_DIST, A_R * 0.6, y + 0.6) if ok else -INF
		if not ok or not (g > y - 0.6):
			continue
		atk = &"evade"
		slot = &""
		ev_dx = odx
		ev_dz = odz
		ev_t = 0.0
		flip_kind = o[2]
		flip_u = 0.0
		yaw = atan2(-ux, -uz)
		evade_cd = _rnd(ASSASSIN_EVADE_CD_MIN, maxf(ASSASSIN_EVADE_CD_MIN, ASSASSIN_EVADE_CD_MAX))
		set_(&"attack")
		E.push({"t": "robot_atk", "id": id, "kind": "flip", "ph": "go", "x": x, "y": y, "z": z})
		return true
	evade_cd = 0.5      # boxed in: try again in a moment
	return false


func hurt(amount: float, from: Variant, kb: float, pt: Variant, kill: bool) -> void:
	super.hurt(amount, from, kb, pt, kill)
	var P: Player = E.P if E != null else null      # shot while moving or recovering: sometimes flips out of the line of fire
	if not dead and P != null and not P.dead and (state == &"pursue" or (state == &"recover" and atk != &"dash")) and evade_cd <= 0.0 and randf() < ASSASSIN_DODGE_CHANCE:
		_evade(P, false)


## one suppressed round from the right hand at the player's chest
func _shoot(P: Player) -> void:
	var s := sin(yaw)
	var c := cos(yaw)
	var ox := x + s * 0.7 - c * 0.2
	var oz := z + c * 0.7 + s * 0.2
	var oy := y + 1.42
	var dx := P.x - ox
	var dy := P.y + (0.7 if P.crouching else 1.1) - oy
	var dz := P.z - oz
	var L := Vector3(dx, dy, dz).length()
	if L == 0.0:
		L = 1.0
	dx = dx / L + (randf() - 0.5) * 0.03
	dy = dy / L + (randf() - 0.5) * 0.02
	dz = dz / L + (randf() - 0.5) * 0.03
	var l2 := Vector3(dx, dy, dz).length()
	if l2 == 0.0:
		l2 = 1.0
	E.fire(self, ox, oy, oz, dx / l2, dy / l2, dz / l2, {"kind": "silenced", "speed": ASSASSIN_SHOT_SPEED, "dmg": ASSASSIN_SHOT_DMG, "r": 0.12})
	recoil_t = 0.12


func _attack(dt: float, P: Player, dx: float, dz: float, _dist: float) -> void:
	if atk == &"shot":
		_go(dt, 0.0, 0.0, true)
		_face(dt, atan2(dx, dz), 6.0)
		if shots < 2 and state_t >= shots * ASSASSIN_SHOT_GAP:
			shots += 1
			if not P.dead:
				_shoot(P)
		var dur := ASSASSIN_SHOT_GAP + 0.16
		a_u = minf(1.0, state_t / dur)
		if state_t >= dur:
			set_(&"recover")
		return
	if atk == &"evade":      # the reposition flip: travels evadeDist in evadeTime, still facing the player
		ev_t += dt
		flip_u = minf(1.0, ev_t / ASSASSIN_EVADE_TIME)
		var st := ASSASSIN_EVADE_DIST / ASSASSIN_EVADE_TIME * dt
		var ex := x + ev_dx * st
		var ez := z + ev_dz * st
		var eg: float = world.ground_height(ex, ez, A_R * 0.6, y + 0.6)
		if eg > y - 1.5:
			if _free(ex, z):
				x = ex
			if _free(x, ez):
				z = ez
			var gy: float = world.ground_height(x, z, A_R * 0.6, y + 0.6)
			if gy > -INF:
				y = gy
		vx = 0.0
		vz = 0.0
		lvx = 0.0
		lvz = 0.0
		if not P.dead:
			_face(dt, atan2(dx, dz), 10.0)
		if flip_u >= 1.0:
			flip_u = 0.0
			E.push({"t": "robot_atk", "id": id, "kind": "flip", "ph": "land", "x": x, "y": y, "z": z})
			set_(&"recover")
		return
	if dash == null:
		dash = Dash.new()
		dash.dx = sin(yaw)
		dash.dz = cos(yaw)
		dash_cd = ASSASSIN_DASH_CD
	var D := dash
	D.t += dt
	if D.ph == &"dash":
		var st := ASSASSIN_DASH_SPEED * dt
		var nx := x + D.dx * st
		var nz := z + D.dz * st
		var ground: float = world.ground_height(nx + D.dx * 0.5, nz + D.dz * 0.5, A_R * 0.6, y + 0.5)
		var stop := D.d >= ASSASSIN_DASH_DIST or not _free(nx, nz) or ground < y - 0.6      # walls and ledge edges stop the dash
		if not stop:
			x = nx
			z = nz
			D.d += st
			if ground > -INF:
				y = ground
		vx = 0.0
		vz = 0.0
		lvz = 0.0 if stop else ASSASSIN_DASH_SPEED
		lvx = 0.0
		a_u = minf(1.0, D.d / ASSASSIN_DASH_DIST)
		if not P.dead and Vector2(P.x - x, P.z - z).length() < A_R + Config.radius + 0.55 and absf(P.y - y) < 1.6:
			D.hit = true
			if E.c.hurt_player(P, ASSASSIN_DASH_DMG, x, z, "melee") and not P.dead and ASSASSIN_STUN > 0.0:
				P.stun_t = maxf(P.stun_t, ASSASSIN_STUN)
				var ev := {"t": "player_stun", "x": P.x, "y": P.y + 1.1, "z": P.z, "dur": ASSASSIN_STUN}
				if P.is_ai_clone:
					ev["clone_id"] = P.clone_id
				E.push(ev)
			E.push({"t": "robot_atk", "id": id, "kind": "dash", "ph": "hit", "x": x + D.dx * 0.7, "y": y + 1.2, "z": z + D.dz * 0.7})
			var ax := x - P.x      # kick off the player: backflip straight away from him, still facing him
			var az := z - P.z
			var l := Vector2(ax, az).length()
			if l == 0.0:
				l = 1.0
			D.bx = ax / l
			D.bz = az / l
			yaw = atan2(-D.bx, -D.bz)
			D.ph = &"flip"
			D.t = 0.0
			flip_kind = &"back"
			E.push({"t": "robot_atk", "id": id, "kind": "flip", "ph": "go", "x": x, "y": y, "z": z})
			return
		if stop:
			D.missed = true
			kvx = D.dx * 5.0
			kvz = D.dz * 5.0
			E.push({"t": "robot_atk", "id": id, "kind": "dash", "ph": "miss", "x": x, "y": y, "z": z})
			set_(&"recover")
		return
	# the backflip: an arc away from the player (the height is the view's; the body stays on the ground for collision)
	flip_u = minf(1.0, D.t / ASSASSIN_FLIP_TIME)
	var bs := ASSASSIN_FLIP_DIST / ASSASSIN_FLIP_TIME * dt
	var bx := x + D.bx * bs
	var bz := z + D.bz * bs
	var g: float = world.ground_height(bx, bz, A_R * 0.6, y + 0.6)
	if g > y - 1.5:      # never flips off a big drop
		if _free(bx, z):
			x = bx
		if _free(x, bz):
			z = bz
		var gy: float = world.ground_height(x, z, A_R * 0.6, y + 0.6)
		if gy > -INF:
			y = gy
	vx = 0.0
	vz = 0.0
	lvz = -ASSASSIN_FLIP_DIST / ASSASSIN_FLIP_TIME
	lvx = 0.0
	if flip_u >= 1.0:
		flip_u = 0.0
		lvz = 0.0
		E.push({"t": "robot_atk", "id": id, "kind": "flip", "ph": "land", "x": x, "y": y, "z": z})
		set_(&"recover")
