class_name AnimKit
extends RefCounted
## Shared animation helpers for the creature views (JS enemies/anim-kit.js): easing, springs, one-shot beats and additive reactions. Views drive everything from simulation time and AI state; nothing here allocates per frame once constructed.

const SUB := 1.0 / 120.0


static func clamp01(u: float) -> float:
	return 0.0 if u < 0.0 else (1.0 if u > 1.0 else u)


static func smooth(u: float) -> float:
	u = clamp01(u)
	return u * u * (3.0 - 2.0 * u)


static func in_cubic(u: float) -> float:
	u = clamp01(u)
	return u * u * u


static func out_cubic(u: float) -> float:
	u = 1.0 - clamp01(u)
	return 1.0 - u * u * u


static func in_out_cubic(u: float) -> float:
	u = clamp01(u)
	return 4.0 * u * u * u if u < 0.5 else 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0


static func in_out_sine(u: float) -> float:
	return -(cos(PI * clamp01(u)) - 1.0) / 2.0


static func out_back(u: float, s: float = 1.70158) -> float:
	u = clamp01(u) - 1.0
	return 1.0 + (s + 1.0) * u * u * u + s * u * u


static func in_back(u: float, s: float = 1.70158) -> float:
	u = clamp01(u)
	return (s + 1.0) * u * u * u - s * u * u


static func out_elastic(u: float) -> float:
	u = clamp01(u)
	if u == 0.0 or u == 1.0:
		return u
	return pow(2.0, -10.0 * u) * sin((u * 10.0 - 0.75) * (2.0 * PI / 3.0)) + 1.0


## fast in, long settle: strikes
static func snap(u: float) -> float:
	u = clamp01(u)
	return 1.0 - pow(1.0 - u, 4.0)


## wind back by `back` (0.25 = a quarter of the travel), then whip forward past the target and settle
static func anticipate(u: float, back: float = 0.25, split: float = 0.45) -> float:
	u = clamp01(u)
	if u < split:
		return -back * sin((u / split) * PI * 0.5)
	return lerpf(-back, 1.0, out_back((u - split) / (1.0 - split), 2.2))


## a smooth bell around c (width w): 0 outside, 1 at c
static func pulse(t: float, c: float, w: float) -> float:
	var d := (t - c) / (w if w != 0.0 else 1e-6)
	return 0.0 if d <= -1.0 or d >= 1.0 else 0.5 + 0.5 * cos(d * PI)


## 0 before a, ramps to 1 at b (smoothstep): the usual "how far through this phase" helper
static func win(t: float, a: float, b: float) -> float:
	return smooth((t - a) / ((b - a) if b != a else 1e-6))


## 0 -> 1 over [a-i, a], held to b, back to 0 over [b, b+o]
static func hold(t: float, a: float, b: float, i: float = 0.1, o: float = 0.1) -> float:
	if t < a:
		return win(t, a - i, a)
	return 1.0 if t <= b else 1.0 - win(t, b, b + o)


static func damp(cur: float, target: float, rate: float, dt: float) -> float:
	return cur + (target - cur) * (1.0 - exp(-rate * dt))


static func damp_angle(cur: float, target: float, rate: float, dt: float) -> float:
	var d := target - cur
	d = atan2(sin(d), cos(d))
	return cur + d * (1.0 - exp(-rate * dt))


## true once when a timer passes `at` this frame: fire one-shot beats (sound, dust, shake) on exact animation frames
static func crossed(prev: float, now: float, at: float) -> bool:
	return prev < at and now >= at


## play a creature audio beat through the game's FX object (the third arg views get in update); silent in tests
static func cue(fx: Variant, R: Robot, nm: String, dur: float = 0.0) -> void:
	if fx != null and fx.creature_audio != null and Game.sfx != null:
		fx.creature_audio.play(Game.sfx, R, nm, dur)


## shake through the same FX object; no-op when absent
static func fx_shake(fx: Variant, R: Robot, amt: float, range_m: float = 14.0) -> void:
	if fx == null or fx.world == null:
		return
	var P: Player = fx.last_player
	var d := U.hyp(P.x - R.x, P.z - R.z) if P != null else 0.0
	if d < range_m:
		fx.shake = maxf(fx.shake, amt * (1.0 - d / range_m * 0.6))


## a damped scalar spring. k = stiffness (rad/s)^2, zeta = damping ratio (1 = critical, 0.3 = bouncy). Stepped in fixed sub-steps so it is stable at low fps.
class Spring:
	var k := 120.0
	var z := 0.5
	var x := 0.0
	var v := 0.0
	var inited := false

	func _init(p_k: float = 120.0, zeta: float = 0.5, p_x: float = 0.0) -> void:
		k = p_k
		z = zeta
		x = p_x

	func step(target: float, dt: float) -> float:
		if not inited:
			x = target
			inited = true
			return x
		var c := 2.0 * sqrt(k) * z
		var left := minf(dt, 0.1)
		while left > 1e-6:
			var h := minf(AnimKit.SUB, left)
			v += ((target - x) * k - v * c) * h
			x += v * h
			left -= h
		return x

	func kick(p_v: float) -> Spring:
		v += p_v
		return self

	func snap(p_x: float) -> Spring:
		x = p_x
		v = 0.0
		inited = true
		return self


## three springs sharing constants: secondary motion of a point (dangling sacs, tendril tips, head bob)
class Spring3:
	var x: Spring
	var y: Spring
	var z: Spring

	func _init(k: float = 120.0, zeta: float = 0.5) -> void:
		x = Spring.new(k, zeta)
		y = Spring.new(k, zeta)
		z = Spring.new(k, zeta)

	func step(tx: float, ty: float, tz: float, dt: float) -> Spring3:
		x.step(tx, dt)
		y.step(ty, dt)
		z.step(tz, dt)
		return self

	func kick(vx: float, vy: float, vz: float) -> Spring3:
		x.v += vx
		y.v += vy
		z.v += vz
		return self


## additive directional flinch: a pitch/roll spring pair kicked away from the hit, plus a decaying 'jolt' scalar
class Reaction:
	var pitch: Spring
	var roll: Spring
	var jolt := 0.0

	func _init(k: float = 160.0, zeta: float = 0.35) -> void:
		pitch = Spring.new(k, zeta)
		roll = Spring.new(k, zeta)
		pitch.snap(0.0)
		roll.snap(0.0)

	## lx / lz: hit direction in the creature's local frame (+z forward). k ~ damage scale (0.2 small .. 1 huge)
	func hit(lx: float, lz: float, k: float = 0.5) -> void:
		var l := U.hyp(lx, lz)
		if l == 0.0:
			l = 1.0
		pitch.kick(-lz / l * 6.0 * k)
		roll.kick(lx / l * 6.0 * k)
		jolt = minf(1.5, jolt + k)

	func step(dt: float) -> void:
		pitch.step(0.0, dt)
		roll.step(0.0, dt)
		jolt = maxf(0.0, jolt - dt * 4.0)


## random blinks: value in [0, 1], 1 = shut. Double blinks now and then
class Blink:
	var mn := 1.8
	var mx := 5.0
	var dur := 0.14
	var r := 0.0
	var t := 0.0
	var next := 0.0
	var v := 0.0

	func _init(p_min: float = 1.8, p_max: float = 5.0, p_dur: float = 0.14, seed_: float = -1.0) -> void:
		mn = p_min
		mx = p_max
		dur = p_dur
		r = randf() if seed_ < 0.0 else seed_
		next = mn + (mx - mn) * _rnd()

	func _rnd() -> float:
		r = fmod(r * 9301.0 + 49297.0, 233280.0)
		return r / 233280.0

	func step(dt: float) -> float:
		t += dt
		if t > next + dur:
			t = 0.0
			next = dur * 1.4 if _rnd() < 0.2 else mn + (mx - mn) * _rnd()
		var u := (t - next) / dur
		v = 0.0 if u < 0.0 or u > 1.0 else sin(u * PI)
		return v


## idle fidgets: every few seconds picks one of n variants (never the same twice in a row) and plays it for its duration
class Fidget:
	var durs: Array
	var mn := 3.0
	var mx := 7.0
	var r := 0.0
	var which := -1
	var last := -1
	var u := 0.0
	var t := 0.0
	var wait := 0.0

	func _init(p_durs: Array, p_min: float = 3.0, p_max: float = 7.0, seed_: float = -1.0) -> void:
		durs = p_durs
		mn = p_min
		mx = p_max
		r = randf() if seed_ < 0.0 else seed_
		wait = _w()

	func _rnd() -> float:
		r = fmod(r * 9301.0 + 49297.0, 233280.0)
		return r / 233280.0

	func _w() -> float:
		return mn + (mx - mn) * _rnd()

	## active = false (busy fighting) cancels fidgets and resets the timer
	func step(dt: float, active: bool = true) -> void:
		if not active:
			which = -1
			t = 0.0
			wait = _w()
			u = 0.0
			return
		if which < 0:
			t += dt
			if t > wait:
				var w := int(floorf(_rnd() * durs.size()))
				if w == last and durs.size() > 1:
					w = (w + 1) % durs.size()
				which = w
				last = w
				t = 0.0
			u = 0.0
			return
		t += dt
		u = t / float(durs[which])
		if u >= 1.0:
			which = -1
			t = 0.0
			wait = _w()
			u = 0.0

	## 0..1..0 envelope of fidget i (0 when another one plays)
	func env(i: int, edge: float = 0.25) -> float:
		return 0.0 if which != i else AnimKit.hold(u, edge, 1.0 - edge, edge, edge)
