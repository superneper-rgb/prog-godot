class_name U
## Math helpers ported 1:1 from the three.js game's util.js: same curves at any frame rate.

const TAU_F := 6.283185307179586

static var spring_v := 0.0  # springTo's out-parameter (JS: springV)


static func damp(a: float, b: float, k: float, dt: float) -> float:
	return a + (b - a) * (1.0 - exp(-k * dt))


## Critically damped spring in closed form. Pass value and velocity, read the new velocity from U.spring_v.
## w = 2 * k trails a steady move by the same distance damp(k) does.
static func spring_to(x: float, v: float, target: float, w: float, dt: float) -> float:
	var e := x - target
	var t := (v + w * e) * dt
	var q := exp(-w * dt)
	spring_v = (v - w * t) * q
	return target + (e + t) * q


static func wrap_angle(a: float) -> float:
	while a > PI:
		a -= TAU
	while a < -PI:
		a += TAU
	return a


static func lerp_angle_u(a: float, b: float, t: float) -> float:
	return a + wrap_angle(b - a) * t


static func damp_angle(a: float, b: float, k: float, dt: float) -> float:
	return lerp_angle_u(a, b, 1.0 - exp(-k * dt))


static func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


## JS Math.sign semantics for floats (0 stays 0).
static func signf0(v: float) -> float:
	return 1.0 if v > 0.0 else (-1.0 if v < 0.0 else 0.0)


## Hypotenuse of a 2D vector.
static func hyp(x: float, y: float) -> float:
	return sqrt(x * x + y * y)
