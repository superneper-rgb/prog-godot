class_name WallWretch
extends Robot
## WALLWRETCH (JS enemies/wall-wretch.js): a choking, saliva-soaked tongue launcher.
##   Anchored  a screaming, eyeless figure fused into the wall by its own tendons. It turns to follow you.
##   Tongue    it opens its jaw and aims (the barbed tip glows and a drool line shows the aim; the aim LOCKS 0.25 s before it fires), then shoots its tongue. If the tip catches you it hurts, yanks you towards it (off your ledge if you are standing on one) and stuns you for a moment; reeled in close, it bites down on you.
##   Counter   side-step after the lock, or SHOOT THE TONGUE TIP while it is out: it snaps back and the wretch reels, stunned.
## The tongue tip is a separate shootable target registered with the game while it is out.

const HP := 90.0
const RANGE := 17.0
const WIND := 0.95
const LOCK := 0.25
const SPEED := 26.0
const PULL := 7.5
const PULL_TIME := 0.9
const STUN := 0.55
const STUN_MUL := 0.2
const DMG := 8.0
const BITE_DMG := 14.0
const CD := 3.0
const TIP_HP := 16.0
const SEVER := 2.2
const TURN := 2.4
const S_R := 0.85
const S_H := 2.6
const MOUTH := 2.16      # the wall figure is tall: its head sits about 2.3 m up


var tg_st := &"in"
var tg_len := 0.0
var tg_dir := Vector3(0.0, 0.0, 1.0)
var tg_t := 0.0
var tg_at := Vector3.ZERO      # the tip (JS tx, ty, tz)
var cd := 0.0
var sever := 0.0
var has_aim := false
var aim_pt := Vector3.ZERO
var tip: Target = null
var mounted := false
var unmounted := false
var has_home := false
var home_yaw := 0.0


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = S_R
	ai.h = S_H
	ai.walk = 0.0
	ai.run = 0.0
	ai.accel = 1.0
	ai.alert_delay = 0.2
	ai.s_wind = WIND
	ai.s_act = 99.0
	ai.s_rec = 0.6
	ai.reach = 0.0
	ai.flinch = 0.2
	ai.stagger_immune = 1.2
	ai.poise_max = 150.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	meat = true
	wretch = true
	name = "WALLWRETCH"
	bark_set = {}
	speech = false
	mute = true
	voice = 0.7 + randf() * 0.15
	r = S_R
	h = S_H
	max = HP
	hp = HP
	no_leash = true


func reset(first: bool) -> void:
	super.reset(first)
	tg_st = &"in"
	tg_len = 0.0
	tg_t = 0.0
	cd = 1.2 + randf()
	sever = 0.0
	has_aim = false
	_drop_tip()


func mouth() -> Vector3:
	return Vector3(x + sin(yaw) * 0.7, y + MOUTH, z + cos(yaw) * 0.7)


func _go(_dt: float, _ang: float, _speed: float, _still: bool) -> void:
	x = hx
	z = hz
	y = hy
	vx = 0.0
	vz = 0.0
	kvx = 0.0
	kvz = 0.0
	lvx = 0.0
	lvz = 0.0


## the body is part of the wall: it can only look a little to either side of the way it faces, so it never swings out of the wall
func _face(dt: float, ang: float, _rate: float = 0.0) -> void:
	if not has_home:
		has_home = true
		home_yaw = yaw
	var want := home_yaw + clampf(U.wrap_angle(ang - home_yaw), -0.5, 0.5)
	yaw += clampf(U.wrap_angle(want - yaw), -TURN * dt, TURN * dt)


## once, on the first frame: find the wall behind it and sit flush against it (it is never left standing in the open)
func _mount() -> void:
	mounted = true
	has_home = true
	home_yaw = yaw
	var bx := -sin(yaw)
	var bz := -cos(yaw)
	var clear := world.ray_clear(hx, hy + 1.3, hz, bx, 0.0, bz, 3.5, 0.01)
	if clear >= 3.5:
		unmounted = true
		push_warning("wall wretch has no wall behind it at %.1f %.1f %.1f" % [hx, hy, hz])
		return
	var k := maxf(-0.2, clear - 0.55)      # the back of the body just touches the wall
	hx += bx * k
	hz += bz * k
	x = hx
	z = hz


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	cd -= dt
	sever = maxf(0.0, sever - dt)
	if not mounted:
		_mount()
	_go(dt, 0.0, 0.0, true)
	if state != &"dead" and P != null and not P.dead and (state == &"idle" or state == &"return" or state == &"search"):      # JS aggro
		known = Known.at(P.x, P.z)
		seen_t = 0.0
		alert_why = "spawn"
		set_(&"pursue")
	if state == &"windup" and atk == &"tongue" and P != null:      # aim, then lock
		if state_t < WIND - LOCK:
			aim_pt = Vector3(P.x, P.y + 1.0, P.z)
			has_aim = true
	_tongue(dt, P)
	ai.stagger = SEVER if sever > 0.0 else 0.6
	super.update(dt, en, P)


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	known = Known.at(P.x, P.z)
	seen_t = 0.0
	shot_cd = 1e9
	_face(dt, atan2(dx, dz))
	if not P.dead and sees and tg_st == &"in" and cd <= 0.0 and dist <= RANGE and _face_err(P.x, P.z) < 0.5 and CreatureGameplay.can_attack(self, &"tongue"):
		CreatureGameplay.claim_attack(self)
		atk = &"tongue"
		slot = &""
		a_u = 0.0
		shot_done = false
		set_(&"windup")
		aim_pt = Vector3(P.x, P.y + 1.0, P.z)
		has_aim = true
		E.push({"t": "robot_atk", "id": id, "kind": "whip", "ph": "windup", "x": x, "y": y, "z": z})
		E.barks.say(self, "alert")


func _attack(_dt: float, P: Player, _dx: float, _dz: float, _dist: float) -> void:
	if tg_st == &"in" and not shot_done:      # FIRE
		shot_done = true
		var o := mouth()
		var a := aim_pt if has_aim else Vector3(P.x, P.y + 1.0, P.z)
		var d := a - o
		var L := d.length()
		if L == 0.0:
			L = 1.0
		tg_st = &"out"
		tg_len = 0.3
		tg_dir = d / L
		tg_t = 0.0
		_add_tip()
		E.barks.say(self, "shoot")
	if shot_done and tg_st == &"in":
		cd = CD * (0.85 + randf() * 0.3)
		set_(&"recover")


func _add_tip() -> void:
	if tip != null or E == null or E.c == null:
		return
	tip = Target.new(id + 70000, x, z, y, {"r": 0.45, "h": 0.9, "max": TIP_HP, "hp": TIP_HP, "ax": 0.0, "az": 0.0})
	tip.respawn_t = 1e9
	tip.data["tongue_tip"] = true
	E.c.targets.append(tip)


func _drop_tip() -> void:
	if tip == null:
		return
	if E != null and E.c != null:
		E.c.targets.erase(tip)
	tip = null


func _tongue(dt: float, P: Player) -> void:
	if tg_st == &"in":
		return
	var o := mouth()
	# shot in the tip: it snaps back, the wretch reels
	if tip != null and (tip.dead or tip.hp < tip.max) and tg_st != &"back":
		tg_st = &"back"
		sever = SEVER
		_drop_tip()
		E.push({"t": "tongue_lash", "id": id, "x": tg_at.x, "y": tg_at.y, "z": tg_at.z, "hit": false})
		E.barks.say(self, "pain")
		if state != &"dead":
			slot = &""
			set_(&"stagger")
	if tg_st == &"out":
		tg_len += SPEED * dt
		tg_at = o + tg_dir * tg_len
		var hd := U.hyp(P.x - tg_at.x, P.z - tg_at.z)
		var vy := P.y - tg_at.y if tg_at.y < P.y else (tg_at.y - P.y - 1.8 if tg_at.y > P.y + 1.8 else 0.0)
		if not P.dead and hd < 0.75 and vy < 0.4:
			tg_st = &"latch"
			tg_t = 0.0
			E.c.hurt_player(P, DMG, o.x, o.z, "bolt")
			E.barks.say(self, "mind")
			E.push({"t": "tongue_lash", "id": id, "x": tg_at.x, "y": tg_at.y, "z": tg_at.z, "hit": true})
		elif tg_len >= RANGE or world.point_solid(tg_at.x, tg_at.y, tg_at.z):
			tg_st = &"back"
	elif tg_st == &"latch":
		tg_t += dt
		tg_at = Vector3(P.x, P.y + 1.0, P.z)
		var dx := o.x - P.x
		var dz := o.z - P.z
		var d := U.hyp(dx, dz)
		if d == 0.0:
			d = 1.0
		if not P.dead and not (P.invuln > 0.6):
			P.ix = dx / d * PULL
			P.iz = dz / d * PULL
			if P.grounded and P.mode == &"normal":
				P.vy = maxf(P.vy, 3.4)
				P.grounded = false
			P.slow_t = maxf(P.slow_t, STUN)
			P.slow_mul = STUN_MUL
			if P.mode != &"normal":
				P.mode = &"normal"
				P.ledge = null
		if P.dead or tg_t >= PULL_TIME or d < 2.0:
			if not P.dead and d < 2.6:
				E.c.hurt_player(P, BITE_DMG, o.x, o.z, "melee")
				E.push({"t": "robot_atk", "id": id, "kind": "melee", "ph": "hit", "x": o.x, "y": o.y, "z": o.z})
			tg_st = &"back"
	elif tg_st == &"back":
		var d := tg_at - o
		var L := d.length()
		var step := SPEED * 1.3 * dt
		if L <= step + 0.3:
			tg_st = &"in"
			tg_len = 0.0
			_drop_tip()
		else:
			tg_at -= d / L * step
	if tip != null:
		tip.x = tg_at.x
		tip.bx = tg_at.x
		tip.z = tg_at.z
		tip.bz = tg_at.z
		tip.y = tg_at.y - 0.45
		tip.kx = 0.0
		tip.kz = 0.0


func _die() -> void:
	super._die()
	respawn_t = 1e9
	if tg_st != &"in":
		tg_st = &"back"
	_drop_tip()
