class_name MarrowWarden
extends Robot
## THE MARROW WARDEN (JS enemies/marrow-warden.js): the Spire mid-boss, bellowing through a loose cage of bone. A car-sized, bloated flesh tick on six bone-spiked legs. It fights in three PHASES (at 100 %, 66 % and 33 % health); every move is telegraphed and the order inside a phase never changes:
##   RUPTURE LEAP   red wound rings mark the floor under you (they follow you, then lock), and it leaps onto each one: slam + shockwave (3, 4 in phase 3)
##   BILE SPRAY     it rears and retches fans of bile; strafe through the gaps
##   BROOD CALL     it vomits meat followers
##   BONE ROLL      it curls into a spiked ball, a red streak shows its path (the path locks before it goes), and rolls across the pit, twice
##   SCOURGE SWEEP  (phase 2+) a barbed tendril rises from the floor and sweeps the whole pit once round (twice, in opposite directions, in phase 3): JUMP it
##   HEART EXPOSED  the rib cage splits open: it sits there, dazed, and every hit counts double. Your window.
## Crossing a phase line it rears up and roars (a short pause, a shockwave of light and sound, and it heals nothing). Immovable: no knockback, no stagger. Giant health bar.

const HP := 2400.0
const SPEED := 2.6
const GAP := 0.9
const P2 := 0.66
const P3 := 0.33
const LEAP_N := 3
const LEAP_PER := 1.6
const LEAP_LEAD := 1.25
const LEAP_AIR := 0.65
const LEAP_R := 2.6
const LEAP_DMG := 26.0
const LEAP_PUSH := 10.0
const SPRAY_V := 4
const SPRAY_WIND := 0.9
const SPRAY_GAP := 1.0
const SPRAY_FAN := 5
const SPRAY_SPREAD := 0.17
const SPRAY_DMG := 8.0
const SPRAY_SPEED := 14.0
const BROOD_N := 3
const BROOD_MAX := 5
const ROLLS := 2
const ROLL_WIND := 0.9
const ROLL_LOCK := 0.3
const ROLL_SPEED := 11.0
const ROLL_DIST := 14.0
const ROLL_DMG := 24.0
const ROLL_PUSH := 12.0
const SWEEP_WIND := 1.0
const SWEEP_T := 1.5
const SWEEP_LEN := 7.4
const SWEEP_IN := 1.6
const SWEEP_DMG := 26.0
const SWEEP_PUSH := 9.0
const SWEEP_JUMP := 1.1
const EXPOSE_T := 5.5
const EXPOSE_MULT := 2.0
const N_R := 2.0
const N_H := 4.4
const LABEL := {&"leap": "RUPTURE LEAP", &"spray": "BILE SPRAY", &"brood": "BROOD CALL", &"roll": "BONE ROLL", &"sweep": "SCOURGE SWEEP - JUMP", &"expose": "HEART EXPOSED - STRIKE", &"roar": ""}
const SEQS := {1: [&"leap", &"spray", &"brood", &"roll", &"expose"], 2: [&"leap", &"sweep", &"spray", &"roll", &"leap", &"brood", &"expose"], 3: [&"leap", &"sweep", &"spray", &"roll", &"brood", &"leap", &"sweep", &"expose"]}

## JS this.marks
class Mark:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var t0 := 0.0
	var hit := false
	var locked := false
	var jump := false

## JS this.fly
class Fly:
	var from: Vector3
	var to: Vector3
	var t0 := 0.0
	var dur := 0.0

## JS this.roll
class Roll:
	var k := 0
	var hit := false
	var d := 0.0
	var has_dir := false
	var dir := Vector2.ZERO
	var path := 0.0

## JS this.sweep
class Sweep:
	var k := 0
	var ang := 0.0
	var a0 := 0.0
	var dir := 1.0
	var state := &"wind"
	var u := 0.0
	var hit := false

var warden := true
var heavy_boss := true
var boss_bar := "THE MARROW WARDEN"
var mv := &""
var mt := 0.0
var idx := 0
var gap := 1.6
var step := 0
var marks: Array[Mark] = []
var phase := 1
var enraged := false
var exposed := false
var move_label := ""
var fly: Fly = null
var roll: Roll = null
var sweep: Sweep = null
var boomed := false
var hop := 0.0
var curl := 0.0


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = N_R
	ai.h = N_H
	ai.walk = SPEED * 0.7
	ai.run = SPEED
	ai.accel = 5.0
	ai.alert_delay = 0.6
	ai.flinch = 0.05
	ai.flinch_cd = 0.5
	ai.stagger = 0.1
	ai.stagger_immune = 99.0
	ai.poise_max = 1e9
	super._init(w, p_id, p_x, p_z, p_y, o)
	meat = true
	heavy = true
	name = "THE MARROW WARDEN"
	bark_set = {}
	speech = false
	mute = true
	voice = 0.3
	r = N_R
	h = N_H
	max = HP
	hp = HP


func reset(first: bool) -> void:
	super.reset(first)
	mv = &""
	mt = 0.0
	idx = 0
	gap = 1.6
	step = 0
	marks.clear()
	phase = 1
	enraged = false
	exposed = false
	move_label = ""
	fly = null
	roll = null
	boomed = false
	shot_cd = 1e9
	sweep = null


func hurt(amount: float, from: Variant, _kb: float, pt: Variant, kill: bool) -> void:
	if exposed and not kill:
		var extra := amount * (EXPOSE_MULT - 1.0)
		hp -= extra
		amount += extra
		if hp <= 0.0:
			kill = true
			dead = true
	super.hurt(amount, from, 0.0, pt, kill)


func _go(dt: float, ang: float, speed: float, still: bool) -> void:
	if fly != null or roll != null:
		return
	super._go(dt, ang, speed, still)


func _leash() -> Vector3:      # x, z, r
	if zone != null:
		return Vector3(float(zone["x"]), float(zone["z"]), maxf(2.0, float(zone["leash"]) - 1.5))
	return Vector3(hx, hz, 9.0)


func _clamp_in(m: Mark) -> void:
	var L := _leash()
	var dx := m.x - L.x
	var dz := m.z - L.y
	var d := U.hyp(dx, dz)
	if d > L.z:
		m.x = L.x + dx / d * L.z
		m.z = L.y + dz / d * L.z


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	immune_t = 99.0
	shot_cd = 1e9
	if state == &"dead":
		move_label = ""
		exposed = false
		sweep = null
		if not boomed and dead_t > 0.8:
			_boom()
	elif P != null:
		if not P.dead and (state == &"idle" or state == &"return" or state == &"search"):      # JS aggro
			known = Known.at(P.x, P.z)
			seen_t = 0.0
			alert_why = "spawn"
			set_(&"pursue")
		var f := hp / max
		var want := 3 if f < P3 else (2 if f < P2 else 1)
		if want > phase and mv == &"":      # the roar happens between moves, never in the middle of one
			_phase_up(want)
	super.update(dt, en, P)


func _phase_up(p: int) -> void:
	phase = p
	enraged = p >= 2
	idx = 0
	mv = &"roar"
	mt = 0.0
	step = 0
	move_label = ""
	E.barks.say(self, "pain")
	E.push({"t": "meat_boom", "id": id, "x": x, "y": y + 3.0, "z": z, "r": 3.5, "big": p == 3})


func _boom() -> void:
	boomed = true
	E.push({"t": "meat_boom", "id": id, "x": x, "y": y + 2.0, "z": z, "r": 5.0, "big": true})
	for o: Robot in E.robots:
		if o.owner == self and not o.dead:
			E.c.damage(o, 1e4, self, 0.0, null)


func _die() -> void:
	super._die()
	respawn_t = 1e9
	corpse_t = 7.0
	fly = null
	roll = null
	sweep = null
	marks.clear()


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, _sees: bool) -> void:
	known = Known.at(P.x, P.z)
	seen_t = 0.0
	if P.dead:
		mv = &""
		move_label = ""
		exposed = false
		marks.clear()
		fly = null
		roll = null
		sweep = null
		_go(dt, 0.0, 0.0, true)
		return
	if mv == &"":
		gap -= dt
		move_label = ""
		_go(dt, _steer(P.x, P.z), ai.run if dist > 6.0 else 0.0, dist <= 6.0)
		_face(dt, atan2(dx, dz), 3.0)
		if gap <= 0.0:
			var seq: Array = SEQS.get(phase, SEQS[1])
			mv = seq[idx % seq.size()]
			idx += 1
			mt = 0.0
			step = 0
			move_label = LABEL[mv]
			E.barks.say(self, "summon" if mv == &"brood" else "shoot")
			if mv == &"expose":
				E.push({"t": "meat_boom", "id": id, "x": x, "y": y + 3.4, "z": z, "r": 1.4, "big": false})
		return
	mt += dt
	var ph := phase
	var hard := ph >= 3
	match mv:
		&"roar":
			_go(dt, 0.0, 0.0, true)
			_face(dt, atan2(dx, dz), 3.0)
			if mt > 1.6:
				_end()
		&"leap":
			var N := LEAP_N + (1 if hard else 0)
			var per := LEAP_PER * (0.88 if ph >= 2 else 1.0) * (0.92 if hard else 1.0)
			var lead := LEAP_LEAD * (0.9 if ph >= 2 else 1.0)
			var air := LEAP_AIR
			while step < N and mt >= step * per:
				var nm := Mark.new()
				nm.x = P.x
				nm.y = y
				nm.z = P.z
				nm.t0 = mt
				_clamp_in(nm)
				marks.append(nm)
				step += 1
			for m: Mark in marks:
				var age := mt - m.t0
				if age < lead * 0.55:
					m.x += (P.x - m.x) * minf(1.0, dt * 8.0)
					m.z += (P.z - m.z) * minf(1.0, dt * 8.0)
					_clamp_in(m)
				else:
					m.locked = true
				if not m.jump and age >= lead - air:
					m.jump = true
					fly = Fly.new()
					fly.from = Vector3(x, y, z)
					fly.to = Vector3(m.x, 0.0, m.z)
					fly.t0 = mt
					fly.dur = air
					E.push({"t": "robot_atk", "id": id, "kind": "slam", "ph": "windup", "x": x, "y": y, "z": z})
				if not m.hit and age >= lead:
					m.hit = true
					fly = null
					x = m.x
					z = m.z
					var g := world.ground_height(x, z, 1.0, y + 2.0)
					if g > -INF:
						y = g
					E.push({"t": "worm_slam", "x": m.x, "y": y, "z": m.z, "r": LEAP_R})
					var d := U.hyp(P.x - m.x, P.z - m.z)
					if d < LEAP_R and absf(P.y - y) < 2.2 and E.c.hurt_player(P, LEAP_DMG, m.x, m.z, "melee"):
						var l := d if d != 0.0 else 1.0
						P.ix += (P.x - m.x) / l * LEAP_PUSH
						P.iz += (P.z - m.z) / l * LEAP_PUSH
						P.vy = maxf(P.vy, 6.0)
						P.grounded = false
						P.mode = &"normal"
			if fly != null:
				var f := fly
				var u := minf(1.0, (mt - f.t0) / f.dur)
				x = f.from.x + (f.to.x - f.from.x) * u
				z = f.from.z + (f.to.z - f.from.z) * u
				hop = 4.5 * 4.0 * u * (1.0 - u)
				_face(dt, atan2(f.to.x - f.from.x, f.to.z - f.from.z), 8.0)
			else:
				hop = 0.0
			if step >= N and mt > (N - 1) * per + lead + 1.0:
				_end()
		&"spray":
			var V := SPRAY_V + (1 if hard else 0)
			var sgap := SPRAY_GAP * (0.85 if ph >= 2 else 1.0)
			var fan := SPRAY_FAN + (ph - 1)
			var wind := SPRAY_WIND
			_face(dt, atan2(dx, dz), 4.0)
			_go(dt, 0.0, 0.0, true)
			if step == 0 and mt < 0.05:
				E.push({"t": "robot_atk", "id": id, "kind": "sauce", "ph": "windup", "x": x, "y": y, "z": z})
			while step < V and mt >= wind + step * sgap:
				step += 1
				var s := sin(yaw)
				var c := cos(yaw)
				var o := Vector3(x + s * 1.6, y + 3.6, z + c * 1.6)
				var d := Vector3(P.x - o.x, P.y + 1.0 - o.y, P.z - o.z)
				var L := d.length()
				if L == 0.0:
					L = 1.0
				d /= L
				for i in fan:
					var a := (i - (fan - 1) / 2.0) * SPRAY_SPREAD
					var ca := cos(a)
					var sa := sin(a)
					E.fire(self, o.x, o.y, o.z, d.x * ca + d.z * sa, d.y, -d.x * sa + d.z * ca, {"kind": "bile", "speed": SPRAY_SPEED, "dmg": SPRAY_DMG, "r": 0.35})
			if step >= V and mt > wind + (V - 1) * sgap + 0.8:
				_end()
		&"brood":
			_go(dt, 0.0, 0.0, true)
			_face(dt, atan2(dx, dz), 3.0)
			if step == 0 and mt < 0.05:
				E.push({"t": "robot_atk", "id": id, "kind": "summon", "ph": "windup", "x": x, "y": y, "z": z})
			if step == 0 and mt >= 1.2:
				step = 1
				var alive := 0
				for o: Robot in E.robots:
					if o.owner == self and not o.dead:
						alive += 1
				var want := mini(BROOD_N + (1 if hard else 0), BROOD_MAX - alive)
				for i in want:
					if not E.spawn_hook.is_valid():
						break
					for tries in 8:
						var a := yaw + (1.0 if i % 2 == 1 else -1.0) * (1.2 + tries * 0.4)
						var px := x + sin(a) * 2.8
						var pz := z + cos(a) * 2.8
						if world.blocked(px, pz, y, 0.6, 0.28, 0.4):
							continue
						var rb: Variant = E.spawn_hook.call({"x": px, "y": y, "z": pz, "yaw": yaw}, {"kind": "follower", "owner": self})
						if rb != null:
							rb.zone = zone
							rb.respawn_t = 1e9
						E.push({"t": "summon", "x": px, "y": y + 0.3, "z": pz})
						break
			if mt > 3.0:
				_end()
		&"roll":
			var R := ROLLS + (1 if hard else 0)
			var cyc := ROLL_WIND + ROLL_DIST / ROLL_SPEED + 0.6
			var k := int(floorf(mt / cyc))
			var m := mt - k * cyc
			if k >= R:
				roll = null
				curl = maxf(0.0, curl - dt * 3.0)
				if mt > R * cyc + 0.6:
					_end()
				return
			if roll == null or roll.k != k:
				roll = Roll.new()
				roll.k = k
				E.push({"t": "robot_atk", "id": id, "kind": "ring", "ph": "windup", "x": x, "y": y, "z": z})
			var ro := roll
			curl = minf(1.0, curl + dt * 4.0)
			if m < ROLL_WIND:      # curl up and aim (the streak follows you, then locks)
				if m < ROLL_WIND - ROLL_LOCK or not ro.has_dir:
					var ax := P.x - x
					var az := P.z - z
					var l := U.hyp(ax, az)
					if l == 0.0:
						l = 1.0
					ro.dir = Vector2(ax / l, az / l)
					ro.has_dir = true
				_face(dt, atan2(ro.dir.x, ro.dir.y), 6.0)
				ro.path = _path(ro.dir)
			elif ro.d < ro.path:   # ROLL
				var st := minf(ROLL_SPEED * dt, ro.path - ro.d)
				x += ro.dir.x * st
				z += ro.dir.y * st
				ro.d += st
				lvz = ROLL_SPEED
				var g := world.ground_height(x, z, 1.0, y + 1.0)
				if g > -INF:
					y = g
				if not ro.hit and U.hyp(P.x - x, P.z - z) < N_R + 0.5 and absf(P.y - y) < 1.6:
					ro.hit = true
					if E.c.hurt_player(P, ROLL_DMG, x, z, "melee"):
						var sx := -ro.dir.y
						var sz := ro.dir.x
						var side := 1.0 if (P.x - x) * sx + (P.z - z) * sz >= 0.0 else -1.0
						P.ix += sx * side * ROLL_PUSH
						P.iz += sz * side * ROLL_PUSH
						P.vy = maxf(P.vy, 5.0)
						P.grounded = false
						P.mode = &"normal"
			else:
				lvz = 0.0
		&"sweep":
			# a barbed scourge rises out of the floor (telegraphed: the pit rim pulses red and the tendril lifts), then sweeps once round the whole pit. Jump it.
			var wind := SWEEP_WIND * (0.9 if ph >= 2 else 1.0)
			var T := SWEEP_T * (0.85 if hard else 1.0)
			var sweeps := 2 if hard else 1
			var per := wind + T + 0.5
			_go(dt, 0.0, 0.0, true)
			_face(dt, atan2(dx, dz), 2.0)
			var k := int(floorf(mt / per))
			var m := mt - k * per
			if k >= sweeps:
				sweep = null
				if mt > sweeps * per:
					_end()
				return
			if sweep == null or sweep.k != k:
				sweep = Sweep.new()
				sweep.k = k
				sweep.a0 = atan2(P.x - x, P.z - z)
				sweep.dir = -1.0 if k % 2 == 1 else 1.0
				E.push({"t": "robot_atk", "id": id, "kind": "ring", "ph": "windup", "x": x, "y": y, "z": z})
			var sw := sweep
			if m < wind:
				sw.state = &"wind"
				sw.u = m / wind
				sw.ang = sw.a0
			elif m < wind + T:
				sw.state = &"go"
				sw.u = (m - wind) / T
				var prev := sw.ang
				sw.ang = sw.a0 + sw.dir * sw.u * TAU
				var dxp := P.x - x
				var dzp := P.z - z
				var d := U.hyp(dxp, dzp)
				if not sw.hit and d > SWEEP_IN and d < SWEEP_LEN + 0.4 and P.y - y < SWEEP_JUMP:      # the player is in the band and not jumping
					var pa := atan2(dxp, dzp)
					var a := U.wrap_angle(pa - sw.ang)
					var b := U.wrap_angle(pa - prev)
					var hit_now := absf(a) < maxf(0.2, 1.3 / d) or (a * b < 0.0 and absf(a - b) < 1.0)
					if hit_now:
						sw.hit = true
						if E.c.hurt_player(P, SWEEP_DMG, x, z, "melee"):
							var l := d if d != 0.0 else 1.0
							P.ix += (dxp / l) * SWEEP_PUSH
							P.iz += (dzp / l) * SWEEP_PUSH
							P.vy = maxf(P.vy, 4.5)
							P.grounded = false
							P.mode = &"normal"
			else:
				sw.state = &"rest"
				sw.u = 1.0
		&"expose":
			var T0 := EXPOSE_T * (0.8 if hard else 1.0)
			exposed = mt > 0.4 and mt < T0 + 0.4
			_go(dt, 0.0, 0.0, true)
			if mt > T0 + 0.9:
				_end()
		_:
			_end()


## how far it can roll along dir before leaving its pit
func _path(dir: Vector2) -> float:
	var L := _leash()
	var d := 0.0
	while d < ROLL_DIST:
		var px := x + dir.x * (d + 0.5)
		var pz := z + dir.y * (d + 0.5)
		if U.hyp(px - L.x, pz - L.y) > L.z:
			break
		d += 0.5
	return d


func _end() -> void:
	mv = &""
	move_label = ""
	exposed = false
	marks.clear()
	fly = null
	roll = null
	sweep = null
	hop = 0.0
	gap = GAP * (0.6 if phase >= 3 else (0.8 if phase == 2 else 1.0))
