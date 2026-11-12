class_name BriarDervish
extends Robot
## THE BRIAR DERVISH: a carnivorous pitcher-bulb on a springy stem, over a knot of thorned root legs. A turret that walks on its roots and whirls. Mid-boss, one per fight.
##   DROP       it falls out of the canopy as a root ball (a ring on the ground says where), slams down, and its roots punch out of the ball.
##   VOLLEY     two seed pods either side of the bulb spit sap, left, right, left... but only once it is lined up on you. It turns slowly, and only when you are well off to its side
##              (it starts turning past 45 degrees and settles inside 10), so circling it buys you time.
##   STOMP      stand under it and the roots stamp.
##   WHIRL      every so often the stem coils and it whirls on its taproot, thorned roots flailing, and crawls after you. Then a faster last spin (from phase 2 it throws off a ring of
##              thorns) and a dizzy beat when it takes extra damage.
##   WOUND UP   enough damage twists its stem round (it reels with every hit) and stops whatever it was doing. Stop shooting and it unwinds into a WHIRL, harder and longer for every
##              hit it took while twisted. Pour it on, then get clear.
##   BURROW     at 2/3 and 1/3 health it pulls its roots up and goes under; a bulge crosses the clearing and it bursts up somewhere else (a ring warns first). Each third it turns,
##              fires and whirls faster.
##   WILT       dying, it shrinks and wilts while its seed pods pop one by one, and the bulb drops off (briar_dervish_view.gd).
## `mv` is the move, `mt` its clock. `spin_a` / `spin_v`, `twist`, `drop_h`, `coil` and `dizzy` are what the view poses from; gameplay never reads the view.

const HP := 2600.0                # (tuned in the jungle test: at 1300 a rifle ended it in about three wound cycles, at 2000 phases 2 and 3 lasted 4 s each)
const D_R := 1.5
const SWEEP_H := 0.6              # the whirl hits feet below this: a plain jump (peak ~1.7 m) clears it for about half a second
const VAULT_T := 0.7              # after you are seen over the roots, this long before the whirl can hit you again
const D_H := 4.4
const P2 := 0.66
const P3 := 0.33
const TURN := 1.25                 # rad/s, phase 1 (x PHASE_K)
const TURN_ON := 0.785             # starts turning past 45 degrees off ...
const TURN_OFF := 0.175            # ... and settles inside 10
const NEAR := 8.0                  # stance distance band: it creeps in beyond FAR
const FAR := 15.0
const CREEP := 1.4
const VOLLEY_N := 6
const VOLLEY_GAP := 0.2
const VOLLEY_REST := 1.6
const VOLLEY_CONE := 0.35          # only fires lined up (20 degrees: at 12, just past where its turn settles, a circling player got two volleys in 20 s)
const SAP_DMG := 7.0
const SAP_SPEED := 19.0
const POD_SIDE := 1.15             # the seed pods' mouths (metres right / up / forward of the root), measured off the view's posed stance (briar_dervish_view.gd, BULB_SCALE 1.3)
const POD_UP := 3.15
const POD_FWD := 1.1
const WHIRL_EVERY := Vector2(9.0, 14.0)
const WHIRL_WIND := 1.0
const WHIRL_T := 4.0
const WHIRL_SPEED := 4.4
const WHIRL_STEER := 1.5
const WHIRL_DMG := 16.0
const WHIRL_PUSH := 12.0
const BURST_T := 1.1
const BURST_SPEED := 7.6
const BURST_DMG := 22.0
const RING_N := [0, 0, 10, 14]     # thorns thrown off at the end of the burst, by phase
const THORN_DMG := 6.0
const THORN_SPEED := 15.0
const DIZZY_T := 1.7
const DIZZY_MULT := 1.5
const KNOCK := 200.0               # damage (decaying) that twists it into WOUND UP: about 1.5 s of steady rifle fire (110 took 0.8 s, so a player who never stopped shooting never saw a volley)
const KNOCK_DECAY := 50.0
const WOUND_CD := 6.0              # after a whirl (and half that after it erupts) hits do not wind it up: the stance kit (volleys, the whirl clock) gets its turn
const REEL := 0.19                 # each hit while twisted turns it this far
const UNWIND_AFTER := 1.4          # seconds without a hit
const WOUND_MAX := 3.2             # it unwinds by itself after this long however much it is hit
const STOMP_R := 3.0
const STOMP_WIND := 0.55
const STOMP_DMG := 12.0
const STOMP_PUSH := 9.0
const STOMP_CD := 2.4
const DROP_H := 18.0
const DROP_WARN := 1.4
const DROP_FALL := 0.55
const ROOT_OUT := 1.3
const LAND_R := 3.2
const LAND_DMG := 25.0
const SINK_T := 1.1
const TUNNEL_SPEED := 8.0
const ERUPT_WARN := 0.9
const RISE_T := 1.1
const ERUPT_R := 3.4
const ERUPT_DMG := 20.0
const PHASE_K := [1.0, 1.0, 1.2, 1.45]
const LEAD := [0.0, 0.0, 0.5, 0.8]   # how far ahead of you the sap is aimed, by phase (a fraction of where you will have got to while it flies): phase 1 learnable, later ones punish plain circling


var dervish := true
var heavy_boss := true
var boss_bar := "THE BRIAR DERVISH"
var mv := &"drop"
var mt := 0.0
var phase := 1
var gy := 0.0                      # the ground under it (y drops below the floor while it is underground, so nothing can shoot it)
var spin_a := 0.0                  # the root crown's spin, and its speed (rad/s)
var spin_v := 0.0
var twist := 0.0                   # how far the stem is wound round (rad): reeling while WOUND UP, coiled before a WHIRL
var wound_dmg := 0.0               # what it took while wound: the next whirl's power
var power := 1.0
var knock := 0.0
var wound_cd := 0.0
var last_hit := 99.0
var turning := false
var whirl_t := 0.0                 # time to the next WHIRL
var vol_left := 0
var vol_t := 0.0
var pod := 0                       # which pod fires next: 0 left, 1 right
var fired_pod := -1                # the pod that fired this frame (the view kicks it)
var near_t := 0.0
var stomp_cd := 0.0
var wdir := 0.0                    # the whirl's heading
var contact_cd := 0.0
var drop_h := 0.0                  # height above the ground while falling in
var dizzy := false
var under := false
var burrow_to := Vector2.ZERO
var mark := Vector3.ZERO           # a ring on the ground: where it will land / erupt (mark_on)
var mark_on := false
var phase_due := 0                 # a third was crossed: burrow at the next chance


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = D_R
	ai.h = D_H
	ai.walk = CREEP
	ai.run = CREEP
	ai.accel = 4.0
	ai.alert_delay = 0.2
	ai.flinch = 0.05
	ai.flinch_cd = 0.5
	ai.stagger = 0.1
	ai.stagger_immune = 99.0
	ai.poise_max = 1e9
	super._init(w, p_id, p_x, p_z, p_y, o)
	heavy = true
	name = "THE BRIAR DERVISH"
	bark_set = {}
	speech = false
	mute = true
	r = D_R
	h = D_H
	max = HP
	hp = HP


func reset(first: bool) -> void:
	super.reset(first)
	gy = hy
	mv = &"drop"
	mt = 0.0
	phase = 1
	spin_a = 0.0
	spin_v = 0.0
	twist = 0.0
	wound_dmg = 0.0
	power = 1.0
	knock = 0.0
	wound_cd = 0.0
	last_hit = 99.0
	turning = false
	whirl_t = randf_range(WHIRL_EVERY.x, WHIRL_EVERY.y)
	vol_left = 0
	vol_t = 1.2
	pod = 0
	fired_pod = -1
	near_t = 0.0
	stomp_cd = 0.0
	contact_cd = 0.0
	drop_h = DROP_H
	dizzy = false
	under = false
	mark = Vector3(x, gy, z)
	mark_on = false
	phase_due = 0
	shot_cd = 1e9


func _k() -> float:
	return PHASE_K[phase]


func _shielded() -> bool:
	return mv == &"drop" and mt < DROP_WARN + DROP_FALL or under


func hurt(amount: float, from: Variant, _kb: float, pt: Variant, kill: bool) -> void:
	if _shielded():      # in the canopy or underground: nothing lands
		hp += amount
		if kill:
			dead = false
		return
	if dizzy and not kill:
		var extra := amount * (DIZZY_MULT - 1.0)
		hp -= extra
		amount += extra
		if hp <= 0.0:
			kill = true
			dead = true
	# a third can't be skipped: it holds just under the line until it has burrowed and come up in the next phase (the jungle test's rifle went from 1/3 to dead
	# during one wound and dizzy, and phase 3 was never seen)
	var gate: float = [0.0, P2, P3, 0.0][phase] - 0.04
	if gate > 0.0 and hp < max * gate:
		amount = maxf(0.0, amount - (max * gate - hp))
		hp = max * gate
		kill = false
		dead = false
	last_hit = 0.0
	if not kill:
		if mv == &"wound":      # every hit turns it further round, away from the hit
			var side := signf(U.wrap_angle(atan2(from.x - x, from.z - z) - yaw))
			yaw -= (side if side != 0.0 else 1.0) * REEL
			twist += REEL * 1.4
			wound_dmg += amount
		elif mv in [&"stance", &"stomp", &"whirl", &"wind"] and wound_cd <= 0.0:
			knock += amount
			if knock >= KNOCK:
				_wound()
	super.hurt(amount, from, 0.0, pt, kill)


func _go(dt: float, ang: float, speed: float, still: bool) -> void:
	if under or mv in [&"drop", &"whirl", &"burst", &"wind", &"dizzy", &"burrow", &"erupt"]:
		lvx = 0.0
		lvz = 0.0
		return
	super._go(dt, ang, speed, still)
	gy = y


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	immune_t = 99.0
	shot_cd = 1e9
	fired_pod = -1
	last_hit += dt
	knock = maxf(0.0, knock - KNOCK_DECAY * dt)
	wound_cd = maxf(0.0, wound_cd - dt)
	contact_cd = maxf(0.0, contact_cd - dt)
	stomp_cd = maxf(0.0, stomp_cd - dt)
	spin_a = fmod(spin_a + spin_v * dt, TAU * 64.0)
	if state == &"dead":
		spin_v = maxf(0.0, spin_v - 10.0 * dt)
		twist *= exp(-2.0 * dt)
		mark_on = false
		dizzy = false
	elif P != null:
		if not P.dead and (state == &"idle" or state == &"return" or state == &"search" or state == &"alert"):      # it came here for a fight
			known = Known.at(P.x, P.z)
			seen_t = 0.0
			alert_why = "spawn"
			set_(&"pursue")
		var f := hp / max
		var want := 3 if f < P3 else (2 if f < P2 else 1)
		if want > phase and phase_due < want:
			phase_due = want
	super.update(dt, en, P)
	if under:
		y = gy - D_H - 2.0
	elif mv == &"drop":
		y = gy + drop_h


func _die() -> void:
	super._die()
	respawn_t = 1e9
	corpse_t = 9.0
	mv = &""
	under = false
	y = gy
	mark_on = false


## the leash: its zone (the level's clearing), or 14 m round where it was put
func _leash() -> Vector3:
	if zone != null:
		return Vector3(float(zone["x"]), float(zone["z"]), maxf(3.0, float(zone["leash"]) - D_R))
	return Vector3(hx, hz, 14.0)


func _in_leash(px: float, pz: float) -> bool:
	var L := _leash()
	return U.hyp(px - L.x, pz - L.y) <= L.z


func _mv_to(m: StringName) -> void:
	mv = m
	mt = 0.0


func _wound() -> void:
	knock = 0.0
	wound_dmg = 0.0
	dizzy = false
	_mv_to(&"wound")
	E.push({"t": "robot_atk", "id": id, "kind": "ring", "ph": "windup", "x": x, "y": y, "z": z})


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, _sees: bool) -> void:
	known = Known.at(P.x, P.z)
	seen_t = 0.0
	mt += dt
	var k := _k()
	match mv:
		&"drop":
			_drop(dt, P)
		&"stance":
			_stance(dt, P, dx, dz, dist)
		&"stomp":
			spin_v = 0.0
			if mt >= STOMP_WIND:
				E.push({"t": "worm_slam", "x": x, "y": gy, "z": z, "r": STOMP_R})
				var d := U.hyp(P.x - x, P.z - z)
				if d < STOMP_R + 0.3 and absf(P.y - gy) < 1.6:
					_shove(P, STOMP_DMG, STOMP_PUSH, 5.0)
				stomp_cd = STOMP_CD
				_mv_to(&"stance")
		&"wind":      # the stem coils and the roots splay: a WHIRL is coming
			spin_v = lerpf(0.0, 3.5, minf(1.0, mt / WHIRL_WIND))      # (spin speeds roughly halved: 14 and 26 rad/s read as a blur)
			twist = lerpf(twist, -1.4, minf(1.0, dt * 3.0))
			if mt >= WHIRL_WIND:
				wdir = atan2(dx, dz)
				_mv_to(&"whirl")
				E.push({"t": "robot_atk", "id": id, "kind": "extend", "ph": "windup", "x": x, "y": y, "z": z})
		&"whirl":
			twist = lerpf(twist, 0.0, minf(1.0, dt * 2.5))
			spin_v = lerpf(spin_v, 8.0 * power, minf(1.0, dt * 4.0))
			var steer := WHIRL_STEER * k
			wdir += clampf(U.wrap_angle(atan2(dx, dz) - wdir), -steer * dt, steer * dt)
			_roll(dt, WHIRL_SPEED * k * (0.85 + 0.15 * power), P, WHIRL_DMG * power)
			if mt >= WHIRL_T * power:      # (a third crossed meanwhile waits for the next stance: cutting the whirl short for it threw away the unwind that the wound-up damage had just paid for)
				_mv_to(&"burst")
		&"burst":      # the last, faster spin
			spin_v = lerpf(spin_v, 13.0, minf(1.0, dt * 6.0))
			wdir += clampf(U.wrap_angle(atan2(dx, dz) - wdir), -0.8 * dt, 0.8 * dt)
			_roll(dt, BURST_SPEED, P, BURST_DMG * power)
			if mt >= BURST_T:
				var n: int = RING_N[phase]
				for i in n:
					var a := spin_a + TAU * i / n
					E.fire(self, x + sin(a) * (D_R + 0.4), gy + 1.0, z + cos(a) * (D_R + 0.4), sin(a), 0.0, cos(a), {"kind": "dart", "speed": THORN_SPEED, "dmg": THORN_DMG, "r": 0.22})
				if n > 0:
					E.push({"t": "robot_atk", "id": id, "kind": "dart", "ph": "windup", "x": x, "y": y, "z": z})
				power = 1.0
				dizzy = true
				_mv_to(&"dizzy")
		&"dizzy":      # wobbling to a stop: hit it now
			spin_v = maxf(0.0, spin_v - 22.0 * dt)
			if mt >= DIZZY_T:
				dizzy = false
				whirl_t = randf_range(WHIRL_EVERY.x, WHIRL_EVERY.y) / k
				wound_cd = WOUND_CD
				_mv_to(&"stance")
		&"wound":     # twisted round; it lets go when the hits stop
			spin_v = 0.0
			_go(dt, 0.0, 0.0, true)
			if last_hit >= UNWIND_AFTER or mt >= WOUND_MAX:
				power = 1.0 + minf(0.6, wound_dmg / 600.0)      # (was / 260: one rifle burst always maxed it, so pouring more on changed nothing)
				twist = 0.0
				wdir = atan2(dx, dz)
				spin_v = 5.0
				_mv_to(&"whirl")      # it unwinds straight into the spin
				E.push({"t": "robot_atk", "id": id, "kind": "extend", "ph": "windup", "x": x, "y": y, "z": z})
		&"burrow":    # roots up, down it goes
			spin_v = lerpf(spin_v, 3.0, minf(1.0, dt * 3.0))
			if mt >= SINK_T:
				under = true
				var L := _leash()
				var away := Vector2(P.x - L.x, P.z - L.y)
				var a := (atan2(-away.x, -away.y) if away.length() > 1.0 else randf() * TAU) + randf_range(-0.7, 0.7)
				var rad := L.z * randf_range(0.35, 0.7)
				burrow_to = Vector2(L.x + sin(a) * rad, L.y + cos(a) * rad)
				_mv_to(&"tunnel")
				E.push({"t": "worm_slam", "x": x, "y": gy, "z": z, "r": 2.0})
		&"tunnel":    # a bulge crosses the clearing
			spin_v = 0.0
			var to := Vector2(burrow_to.x - x, burrow_to.y - z)
			var L2 := to.length()
			var st := TUNNEL_SPEED * dt
			if L2 > st:
				x += to.x / L2 * st
				z += to.y / L2 * st
			else:
				x = burrow_to.x
				z = burrow_to.y
				var g := world.ground_height(x, z, 1.0, gy + 3.0)
				if g > -INF:
					gy = g
				mark = Vector3(x, gy, z)
				mark_on = true
				_mv_to(&"erupt")
				E.push({"t": "robot_atk", "id": id, "kind": "slam", "ph": "windup", "x": x, "y": gy, "z": z})
		&"erupt":     # a ring warns, then it bursts up
			if under and mt >= ERUPT_WARN:
				under = false
				y = gy
				mark_on = false
				phase = maxi(phase, phase_due)
				E.push({"t": "worm_slam", "x": x, "y": gy, "z": z, "r": ERUPT_R})
				E.push({"t": "meat_boom", "id": id, "x": x, "y": gy + 1.0, "z": z, "r": 2.5, "big": phase == 3})
				var d := U.hyp(P.x - x, P.z - z)
				if d < ERUPT_R and absf(P.y - gy) < 2.0:
					_shove(P, ERUPT_DMG, 11.0, 7.0)
			if not under:
				yaw = U.damp_angle(yaw, atan2(dx, dz), 4.0, dt)
			if mt >= ERUPT_WARN + RISE_T:
				whirl_t = randf_range(WHIRL_EVERY.x, WHIRL_EVERY.y) / k * 0.6
				vol_t = 0.6
				wound_cd = WOUND_CD * 0.5
				_mv_to(&"stance")
		_:
			_mv_to(&"stance")


## falling out of the canopy: a ring tracks you for a moment, locks, and the root ball comes down on it
func _drop(dt: float, P: Player) -> void:
	spin_v = 0.0
	if mt < DROP_WARN:
		mark = Vector3(x, gy, z)
		mark_on = true
		drop_h = DROP_H
		return
	if mt < DROP_WARN + DROP_FALL:
		var u := (mt - DROP_WARN) / DROP_FALL
		drop_h = DROP_H * (1.0 - u * u)
		return
	if drop_h > 0.0:      # landed
		drop_h = 0.0
		mark_on = false
		E.push({"t": "worm_slam", "x": x, "y": gy, "z": z, "r": LAND_R})
		var d := U.hyp(P.x - x, P.z - z)
		if d < LAND_R and absf(P.y - gy) < 2.2:
			_shove(P, LAND_DMG, 12.0, 6.0)
	yaw = U.damp_angle(yaw, atan2(P.x - x, P.z - z), 1.5, dt)
	if mt >= DROP_WARN + DROP_FALL + ROOT_OUT:
		_mv_to(&"stance")


func _stance(dt: float, P: Player, dx: float, dz: float, dist: float) -> void:
	var k := _k()
	spin_v = lerpf(spin_v, 0.0, minf(1.0, dt * 6.0))
	twist = lerpf(twist, 0.0, minf(1.0, dt * 3.0))
	if phase_due > phase and not P.dead:
		_mv_to(&"burrow")
		E.push({"t": "robot_atk", "id": id, "kind": "summon", "ph": "windup", "x": x, "y": y, "z": z})
		return
	# facing with hysteresis: starts turning when you are well off its side, settles when it is nearly on you
	var err := U.wrap_angle(atan2(dx, dz) - yaw)
	if absf(err) > TURN_ON:
		turning = true
	elif absf(err) < TURN_OFF:
		turning = false
	if turning:
		yaw += clampf(err, -TURN * k * dt, TURN * k * dt)
	# distance: creeps in when you are far, holds when you are in its band
	var go := dist > FAR and not turning
	_go(dt, _steer(P.x, P.z) if go else yaw, CREEP * k if go else 0.0, not go)
	# under it: the roots stamp
	near_t = near_t + dt if dist < STOMP_R - 0.4 else 0.0
	if near_t > 0.5 and stomp_cd <= 0.0 and not P.dead:
		near_t = 0.0
		_mv_to(&"stomp")
		E.push({"t": "robot_atk", "id": id, "kind": "slam", "ph": "windup", "x": x, "y": y, "z": z})
		return
	# the WHIRL clock
	whirl_t -= dt
	if whirl_t <= 0.0 and not P.dead:
		power = 1.0
		_mv_to(&"wind")
		E.push({"t": "robot_atk", "id": id, "kind": "ring", "ph": "windup", "x": x, "y": y, "z": z})
		return
	# volleys, only lined up
	vol_t -= dt
	if vol_left <= 0 and vol_t <= 0.0 and absf(err) < VOLLEY_CONE and dist < 34.0 and not P.dead:
		vol_left = VOLLEY_N + (phase - 1) * 2
		vol_t = 0.0
		E.push({"t": "robot_atk", "id": id, "kind": "sauce", "ph": "windup", "x": x, "y": y, "z": z})
	if vol_left > 0 and vol_t <= 0.0:
		_spit(P)
		vol_left -= 1
		vol_t = VOLLEY_GAP / k if vol_left > 0 else VOLLEY_REST / k


## where a seed pod's mouth is (side -1 left, +1 right)
func pod_mouth(side: float) -> Vector3:
	var s := sin(yaw)
	var c := cos(yaw)
	return Vector3(x + s * POD_FWD - c * side * POD_SIDE, gy + POD_UP, z + c * POD_FWD + s * side * POD_SIDE)


func _spit(P: Player) -> void:
	var side := -1.0 if pod == 0 else 1.0
	fired_pod = pod
	pod = 1 - pod
	var o := pod_mouth(side)
	var d := Vector3(P.x - o.x, P.y + 1.0 - o.y, P.z - o.z)
	var ahead: float = LEAD[phase] * d.length() / SAP_SPEED      # (in the jungle test a circling player took no sap at all)
	d += Vector3(P.vx, 0.0, P.vz) * ahead
	d += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * d.length() * 0.04
	d = d.normalized()
	E.fire(self, o.x, o.y, o.z, d.x, d.y, d.z, {"kind": "bile", "speed": SAP_SPEED, "dmg": SAP_DMG, "r": 0.3})


## whirling along wdir: bounces off walls and the clearing's edge, hurts what it touches
func _roll(dt: float, speed: float, P: Player, dmg: float) -> void:
	var st := speed * dt
	var nx := x + sin(wdir) * st
	var nz := z + cos(wdir) * st
	if _free(nx, nz) and _in_leash(nx, nz):
		x = nx
		z = nz
	else:      # glance off: turn back towards the middle
		var L := _leash()
		wdir = atan2(L.x - x, L.y - z) + randf_range(-0.6, 0.6)
	var g := world.ground_height(x, z, 1.0, gy + 1.0)
	if g > -INF:
		gy = g
		y = g
	lvz = speed
	# the roots sweep flat along the floor (the view plants it), so it is jumped: only feet below SWEEP_H are hit (was |dy| < 1.7, which no jump cleared)
	# The disc (4.8 m across) is wider than any jump carries you, so a player seen above the roots inside it has vaulted this pass: the contact clock holds off until it has gone by.
	var near := U.hyp(P.x - x, P.z - z) < D_R + 0.9
	if near and P.y - gy >= SWEEP_H:
		contact_cd = maxf(contact_cd, VAULT_T)
	if contact_cd <= 0.0 and not P.dead and near and P.y - gy < SWEEP_H and P.y - gy > -1.0:
		contact_cd = 0.8
		_shove(P, dmg, WHIRL_PUSH, 5.0)
		E.push({"t": "robot_atk", "id": id, "kind": "melee", "ph": "hit", "x": P.x, "y": P.y + 1.0, "z": P.z})


func _shove(P: Player, dmg: float, push: float, up: float) -> void:
	if not E.c.hurt_player(P, dmg, x, z, "melee"):
		return
	var dx := P.x - x
	var dz := P.z - z
	var l := U.hyp(dx, dz)
	if l < 0.01:
		dx = sin(yaw)
		dz = cos(yaw)
		l = 1.0
	P.ix += dx / l * push
	P.iz += dz / l * push
	P.vy = maxf(P.vy, up)
	P.grounded = false
	P.mode = &"normal"
	P.ledge = null
