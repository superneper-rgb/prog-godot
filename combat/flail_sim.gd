class_name FlailSim
extends RefCounted
## SCORPION FLAIL swing simulation and its live state (JS weapons/scorpion-flail.js: FlailSim + FLAIL): a ball and chain after Ratchet: Deadlocked's Scorpion Flail.
## Attack: 0.20 s low coil, 0.20 s pelvis -> chest -> arm whip, 0.10 s grounded slam (hit at 0.45 s), 0.20 s motor recovery.
## The head lags the hand then overtakes it overhead; the impact bursts two metres ahead, with a slack chain and a small rebound.
## Holding fire keeps swinging; each swing costs a round (20 carried, no reload: ammo pods refill it). Light flyers are mostly out of reach.
## Absolute attack clock: independent hip, chest, hand and head curves retain their timing across frame boundaries. Combat writes the state (step), the handle's pose hook
## and the ball / chain view read it.

## JS FLAIL: tunables + the live swing state.
class State:
	var side := 0.22         # the swing pivots on the right shoulder: this far to the right of the body, this far above muzzle height (the character build's muz_y)
	var pivot_up := 0.02
	var rho := 2.15
	var chain := 1.78
	var ball_r := 0.28
	var reach := 2.0
	var wind := 0.20
	var accel := 0.20
	var hold := 0.10
	var rec := 0.20
	var hit_at := 0.45
	var duration := 0.70
	var th_rest := 2.1       # unwrapped hand angle: up = 2 pi, forward/down = 2 pi + pi * 0.75
	var th_back := 3.55
	var th_apex := 6.65
	var th_max := 8.65
	var coil := -PI / 6.0
	var uncoil := 0.16
	var fold := 0.65
	var aoe := 2.25          # blast radius (m), damage lost at its rim, knockback (robots / heavy ones x / practice dummies), extra shove on robots
	var falloff := 0.45
	var kb := 12.0
	var kb_heavy := 0.45
	var kb_plain := 3.5
	var push := 11.0
	# ---- live ----
	var on := false
	var st := "idle"
	var t := 0.0
	var elapsed := 0.0
	var th := 2.1
	var dx := 0.0
	var dz := 1.0
	var psi := 0.0
	var hip := 0.0
	var lean := 0.0
	var drop := 0.0
	var weight := 0.0
	var settle := 0.0
	var s := 1.0
	var head_th := 0.0
	var ball := Vector3.ZERO
	var ball_ok := false
	var hand := Vector3.ZERO
	var hand_ok := false


## Where the slam lands.
class Landing:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var kind := "ground"     # ground | air | wall


static var FLAIL := State.new()

var c: Combat
var st := "idle"
var t := 0.0
var dx := 0.0
var dz := 1.0
var imp: Landing = null
var rest := Vector3.ZERO
var build: Builds.Build = null


func _init(combat: Combat) -> void:
	c = combat


static func sm(x: float) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else x * x * (3.0 - 2.0 * x))


func reset() -> void:
	st = "idle"
	t = 0.0
	imp = null
	var F := FLAIL
	F.st = "idle"
	F.t = 0.0
	F.elapsed = 0.0
	F.on = false
	F.psi = 0.0
	F.hip = 0.0
	F.lean = 0.0
	F.drop = 0.0
	F.weight = 0.0
	F.settle = 0.0
	F.th = F.th_rest
	F.hand_ok = false
	F.ball_ok = false


var busy: bool:
	get:
		return st != "idle"


func _the_build() -> Builds.Build:
	return build if build != null else c.build


## a smaller body swings a smaller flail
func _scale() -> float:
	var b := _the_build()
	return 0.6 + 0.4 * b.scale if (b != null and b.scale != 0.0) else 1.0


func _floor(P: Player, x: float, z: float) -> float:
	var y := c.world.ground_height(x, z, 0.25, P.y + 0.6)
	return y if is_finite(y) else P.y


func _arc(P: Player, u: float) -> Vector3:
	var F := FLAIL
	var s := F.s
	var b := _the_build()
	var lag := clampf((u - 0.425) / 0.575, 0.0, 1.0)
	var th := lerpf(PI + asin(0.7 / (F.rho * s)), 7.4, pow(lag, 1.2))
	F.head_th = th                       # the head starts after the hand, then catches and passes it at the overhead apex
	var f := F.rho * s * sin(th)
	var x := P.x - dz * F.side * s + dx * f
	var z := P.z + dx * F.side * s + dz * f
	var muz_y := b.muz_y if (b != null and b.muz_y != 0.0) else 1.4
	var y := maxf(_floor(P, x, z) + F.ball_r * s, P.y + muz_y + 2.25 * s * cos(th))
	return Vector3(x, y, z)


## Obstructions shorten the slam, but never move the damage event earlier than 0.45 s.
func _landing(P: Player) -> Landing:
	var F := FLAIL
	var W := c.world
	var R := F.ball_r * F.s
	var reach := F.reach
	var out := Landing.new()
	out.x = P.x + dx * reach
	out.z = P.z + dz * reach
	var floor_y := W.ground_height(out.x, out.z, 0.25, P.y + 0.6)
	out.y = floor_y + R if is_finite(floor_y) else P.y + R
	if not is_finite(floor_y):
		out.kind = "air"
	var d := 0.12
	while d <= reach:
		var x := P.x + dx * d
		var z := P.z + dz * d
		if W.point_solid(x, P.y + R + 0.08, z):
			out.x = P.x + dx * maxf(0.0, d - R)
			out.z = P.z + dz * maxf(0.0, d - R)
			var gy := _floor(P, out.x, out.z)
			out.y = gy + R
			out.kind = "wall"
			break
		d += 0.08
	return out


func _pose(p_t: float) -> void:
	var F := FLAIL
	var a := sm(p_t / F.wind)
	var acc := F.wind + F.accel
	var end := acc + F.hold
	var r := sm((p_t - end) / F.rec)
	var drive := sm((p_t - acc) / (F.hit_at - acc))
	F.hip = lerpf(F.coil * a, F.uncoil, sm((p_t - F.wind) / 0.10)) * (1.0 - r)
	F.psi = lerpf(-0.74 * a, 0.12, sm((p_t - F.wind - 0.035) / 0.13)) * (1.0 - r)
	F.lean = lerpf(-0.12 * a, F.fold, drive) * (1.0 - r)
	# The loaded rear leg lifts the hips into acceleration before both knees absorb the slam.
	F.drop = lerpf(lerpf(0.15 * a, 0.07, sm((p_t - F.wind) / 0.13)), 0.38, drive) * (1.0 - r)
	F.weight = a * (1.0 - r)
	F.settle = sin((p_t - end) * 42.0) * exp(-(p_t - end) * 14.0) * (1.0 - r) if p_t > end else 0.0
	F.lean -= F.settle * 0.18
	var lift := sm((p_t - F.wind - 0.06) / 0.14)
	F.th = lerpf(lerpf(F.th_rest, F.th_back, a), F.th_apex, lift)
	F.th = lerpf(F.th, F.th_max, drive)
	F.th = lerpf(F.th, F.th_rest + PI * 2.0, r)


## the trigger (Combat._shoot): spends a round and starts the swing
func start(_w: Weapons.Def, P: Player) -> bool:
	var F := FLAIL
	if busy or c.ammo[c.cur] <= 0.0 or P.dead or P.mode != &"normal":
		return false
	c.cool = F.duration
	c.buffer = 0.0
	c.ammo[c.cur] -= 1.0
	c.aim_t = maxf(c.aim_t, 0.5)
	P.sprinting = false
	dx = sin(P.yaw)
	dz = cos(P.yaw)
	st = "wind"
	t = 0.0
	imp = null
	F.s = _scale()
	rest = F.ball if F.ball_ok else Vector3(P.x + dx * 0.7, P.y + F.ball_r * F.s, P.z + dz * 0.7)
	_publish(P)
	c.events.append({"t": "flail_swing", "x": P.x, "y": P.y + 1.2, "z": P.z})
	return true


func step(dt: float, P: Player, w: Weapons.Def, p_build: Builds.Build = null) -> void:
	var F := FLAIL
	build = p_build if p_build != null else c.build
	if w == null or w.special != "flail" or P.dead or P.mode != &"normal":
		if st != "idle" or F.on:
			reset()
		return
	F.on = true
	F.s = _scale()
	if st == "idle":
		_pose(0.0)
		F.st = "idle"
		F.t = 0.0
		F.elapsed = 0.0
		return
	c.aim_t = maxf(c.aim_t, 0.3)                  # the body keeps facing the aim through the whole swing
	t = minf(F.duration, t + maxf(0.0, dt))
	if imp == null and t + 1e-9 >= F.hit_at:
		imp = _landing(P)
		_impact(P, w, imp)
	var clock := t + 1e-9
	st = "idle" if clock >= F.duration else ("wind" if clock < F.wind else ("accel" if clock < F.wind + F.accel else ("impact" if clock < F.wind + F.accel + F.hold else "rec")))
	_publish(P)


func _publish(P: Player) -> void:
	var F := FLAIL
	var p_t := t
	var acc := F.wind + F.accel
	var end := acc + F.hold
	_pose(p_t)
	F.on = true
	F.st = st
	F.t = p_t
	F.elapsed = p_t
	F.dx = dx
	F.dz = dz
	var out := F.ball
	if p_t < F.wind:
		var u := sm(p_t / F.wind)
		var x := P.x - dx * 0.7 - dz * F.side * F.s
		var z := P.z - dz * 0.7 + dx * F.side * F.s
		out.x = lerpf(rest.x, x, u)
		out.z = lerpf(rest.z, z, u)
		out.y = lerpf(rest.y, _floor(P, x, z) + F.ball_r * F.s, u)
	elif p_t < acc:
		out = _arc(P, (p_t - F.wind) / F.accel)
	else:
		var hit := imp if imp != null else _landing(P)
		if p_t < F.hit_at:
			out = _arc(P, 1.0)
			var u := sm((p_t - acc) / (F.hit_at - acc))
			out.x = lerpf(out.x, hit.x, u)
			out.y = lerpf(out.y, hit.y, u)
			out.z = lerpf(out.z, hit.z, u)
		else:
			out = Vector3(hit.x, hit.y, hit.z)
			var rebound := clampf((p_t - F.hit_at) / 0.11, 0.0, 1.0)
			out.y += sin(rebound * PI) * 0.24 * F.s
			if p_t >= end:
				var u := sm((p_t - end) / F.rec)
				var x := P.x + dx * 0.7 - dz * F.side * F.s
				var z := P.z + dz * 0.7 + dx * F.side * F.s
				out.x = lerpf(out.x, x, u)
				out.z = lerpf(out.z, z, u)
				out.y = lerpf(out.y, _floor(P, x, z) + F.ball_r * F.s, u)
	F.ball = out
	F.ball_ok = true


func _impact(_P: Player, w: Weapons.Def, b: Landing) -> void:
	var F := FLAIL
	var kind := b.kind
	var R := F.aoe * F.s
	var hits := 0
	var kills := 0
	for T: Target in c.targets:
		if T.dead or T.npc or kind == "air":
			continue
		var tx := T.x - b.x
		var tz := T.z - b.z
		var d := U.hyp(tx, tz)
		if d > R + T.r or b.y < T.y - 0.7 or b.y > T.y + T.h + 0.5:
			continue
		# The cylindrical blast is blocked by solid walls.
		var ty := T.y + T.h * 0.5 - b.y
		var ln := sqrt(tx * tx + ty * ty + tz * tz)
		if ln > 0.0 and c.world.ray_clear(b.x, b.y, b.z, tx / ln, ty / ln, tz / ln, ln, 0.01) < ln - T.r:
			continue
		var k := clampf(d / (R + T.r), 0.0, 1.0)
		var l := d if d != 0.0 else 1.0
		var ux := tx / l if d > 0.05 else dx
		var uz := tz / l if d > 0.05 else dz
		var heavy := T.heavy
		c.damage(T, w.dmg * (1.0 - F.falloff * k), Vector3(b.x, b.y, b.z), (F.kb * (F.kb_heavy if heavy else 1.0)) if T.robot else F.kb_plain,
			{"x": T.x, "y": T.y + T.h * 0.5, "z": T.z, "kind": "target", "nx": -ux, "ny": 0.0, "nz": -uz}, true)
		if T.dead:
			kills += 1
		if T.robot and not T.dead:
			var e := F.push * (F.kb_heavy if heavy else 1.0) * (1.0 - 0.5 * k)
			T.kvx += ux * e
			T.kvz += uz * e
		hits += 1
	c.events.append({"t": "flail_impact", "x": b.x, "y": b.y, "z": b.z, "ground_y": null if kind == "air" else b.y - F.ball_r * F.s, "hits": hits, "kills": kills, "kind": kind, "s": F.s, "radius": F.aoe, "at": F.hit_at})
