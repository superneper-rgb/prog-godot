class_name Gait
extends RefCounted
## Pure gait maths (no nodes, no state): the duty-cycle foot trajectory used by Animator (JS GAIT). Phase p in [0,1): stance for p < d (foot slides back
## linearly at ground speed v, which makes rs = v*d/rate), then a swing along a Hermite curve whose end velocities equal the stance velocity (so touchdown and
## lift-off are smooth and the planted foot never skates). Stance foot z runs +rs/2 -> -rs/2, swing -rs/2 -> +rs/2; z is metres forward of the hip.

class Params:
	var d := 0.0       # fraction of the cycle a foot is on the ground
	var rate := 0.0    # cadence (cycles / s)
	var rs := 0.0      # stance sweep (m)

class Foot:
	var z := 0.0
	var b := 0.0
	var phi := 0.0
	var st := 0


static func smooth01(x: float) -> float:
	return 0.0 if x <= 0.0 else (1.0 if x >= 1.0 else x * x * (3.0 - 2.0 * x))


static func sstep(a: float, b: float, x: float) -> float:
	return smooth01((x - a) / (b - a))


## fraction of the cycle a foot is on the ground
static func duty(v: float, wsp: float = 0.0) -> float:
	return lerpf(0.62, 0.38, clampf((v - 1.5) / 4.5, 0.0, 1.0)) - 0.04 * wsp


static func params(v: float, wsp: float = 0.0, w_cr: float = 0.0, B: Builds.Build = null) -> Params:
	var q := Params.new()
	q.d = duty(v, wsp)
	q.rate = (0.9 + 1.4 * smooth01(clampf(v / 6.2, 0.0, 1.0))) * (1.0 + 0.1 * wsp) * (B.cad if B != null else 1.0)     # calm cadence (cycles / s): ~2.3 at full run, ~1.2 walking (Prog)
	var rs_max := lerpf(0.8, 0.95, wsp) * (1.0 - 0.45 * w_cr) * (B.stride if B != null else 1.0)                       # the legs can only sweep so far
	q.rs = minf(rs_max, v * q.d / q.rate)     # rs = stance sweep (m); stance foot speed = rs * rate / d: = v up to the sweep cap, ~75-85 % of v at top speed
	return q


static func foot(p: float, q: Params, o: Foot) -> void:
	p -= floorf(p)
	var d := q.d
	var rate := q.rate
	var rs := q.rs
	if p < d:
		var u := p / d
		o.z = rs * (0.5 - u)
		o.b = 0.0
		o.phi = PI * u
		o.st = 1
		return
	var s := (p - d) / (1.0 - d)
	var s2 := s * s
	var s3 := s2 * s
	var m := -(rs * rate / d) * ((1.0 - d) / rate)     # Hermite tangent (per unit s) = -v * swing time
	o.z = -0.5 * rs * (2.0 * s3 - 3.0 * s2 + 1.0) + m * (s3 - 2.0 * s2 + s) + 0.5 * rs * (-2.0 * s3 + 3.0 * s2) + m * (s3 - s2)
	o.b = pow(sin(PI * s), 1.3)
	o.phi = PI + PI * s
	o.st = 0
