class_name TetheredView
extends CreatureView
## The Tethered on screen: assets/underfoint/tethered.glb (tools/tethered/build_tethered.py) posed here, joint by joint, and its three cables laid from the rack on its back to the wall every frame.
## Folded it squats against its wall with its scythes crossed over its chest and one dim light. It comes up screaming, runs bent low with its arms swept back, and at the end of its cables it hangs
## off them, reaching. A cable is ten one-metre lengths of the model (joints cable<A..C>_<0..9>) set end to end along a hanging curve: slack it lies on the floor, taut it is a straight line that shakes.

const GREEN := 0x2fe060
const AMBER := 0xffb02e
const SEGS := 10
const PORTS: Array[Vector3] = [Vector3(0.0, 0.32, -0.42), Vector3(0.18, 0.12, -0.42), Vector3(-0.18, 0.12, -0.42)]      # the rack's sockets, from the chest joint
const SPARE: Array[float] = [0.8, 1.2, 1.7]      # how much longer than `reach` each cable is: at its limit the first is a straight line to the wall, the others nearly (3.0+ left all three on the floor even then)

static var _model: CreatureModel = null

var seed_ := 0.0
var size := 1.0
var phase_ := 0.0
var last_x := 0.0
var last_z := 0.0
var j: Dictionary = {}
var cab: Array[PackedInt32Array] = []
var ends: Array[Vector3] = []      # where each cable meets the wall
var side := Vector3.RIGHT


static func get_model() -> CreatureModel:
	if _model == null:
		_model = CreatureModel.build("res://assets/underfoint/tethered.glb", Callable(), {}, {"sigilGlow": 1})
		_model.drop_emission("sigilGlow")
	return _model


func _init(p_r: Robot) -> void:
	super._init(p_r, get_model())
	j = model.names
	j_spine = j["chest"]
	j_el_l = j["forearmL"]
	j_muzzle = j["head"]
	seed_ = fposmod(R.id * 0.6180339, 1.0)
	size = 1.0 + seed_ * 0.08
	last_x = R.x
	last_z = R.z
	var tk := R as Tethered
	var out := Vector3(tk.home.x - tk.anchor.x, 0.0, tk.home.y - tk.anchor.z)
	side = out.cross(Vector3.UP).normalized() if out.length() > 0.05 else Vector3.RIGHT
	ends = [tk.anchor + Vector3(0.0, 0.45, 0.0), tk.anchor + side * 0.6, tk.anchor - side * 0.6]
	for c: String in ["A", "B", "C"]:
		var ids := PackedInt32Array()
		for i in SEGS:
			ids.append(j["cable%s_%d" % [c, i]])
		cab.append(ids)


func update(dt: float, _now: float, _fx: Variant) -> void:
	dt = minf(0.05, maxf(0.0, dt))
	var tk := R as Tethered
	var t := R.t + seed_ * 40.0
	var moved := U.hyp(R.x - last_x, R.z - last_z)
	last_x = R.x
	last_z = R.z
	if not R.dead and moved < 1.0:
		phase_ += moved * 2.1 / size
	var speed := U.hyp(R.vx, R.vz)
	var run := _qq(&"run", clampf(speed / 4.0, 0.0, 1.0) if not R.dead else 0.0, 7.0, dt)
	var fall := _ease(_n(R.dead_t / 0.7)) if R.dead else 0.0
	var fold := _ease(_qq(&"fold", maxf(tk.fold, fall * 0.8), 9.0, dt))
	var strain := _qq(&"strain", tk.strain if not R.dead else 0.0, 9.0, dt)
	var wind := _ease(_n(R.state_t / Tethered.WIND)) if R.state == &"windup" else 0.0
	var hit := _n(R.state_t / (Tethered.LUNGE * 0.45)) if R.state == &"attack" else 0.0
	var after := 1.0 - _ease(_n(R.state_t / Tethered.REST)) if R.state == &"recover" else 0.0
	var reel := sin(_n(R.state_t / 0.35) * PI) if R.state == &"stagger" else 0.0
	var scream := sin(_n(R.state_t / tk.unfold) * PI) if R.state == &"alert" else 0.0
	var up := 1.0 - fold
	var s := sin(phase_)
	var c := cos(phase_)
	var breath := sin(t * 1.1)
	var shake := sin(t * 31.0) * strain
	# ---- trunk: hunched; low and level in a run; hung forward off the cables at their end; folded right down on its haunches against the wall
	var bend := 0.34 + run * 0.42 + strain * 0.35 - wind * 0.45 + hit * 0.7 + after * 0.5 - reel * 0.45 + breath * 0.025 + fold * 0.55
	var p := pose.model.rest[j["pelvis"]].origin
	p.y += -0.08 - run * 0.14 - fold * 0.62 + absf(s) * 0.07 * run - wind * 0.05
	p.z += -fold * 0.1 + strain * 0.12
	pose.pos[j["pelvis"]] = p
	pose.euler(j["pelvis"], 0.1 + run * 0.22 + strain * 0.3, s * 0.1 * run, c * 0.07 * run + shake * 0.03)
	pose.euler(j["spine"], bend * 0.8, -s * 0.14 * run + (wind - hit) * 0.3, sin(t * 0.6) * 0.03 * up)
	pose.euler(j["chest"], bend * 0.75, -s * 0.16 * run + (wind - hit - after * 0.5) * 0.55, sin(t * 0.8) * 0.03 * up + shake * 0.04)
	# ---- head: down on its chest folded; up it never leaves you, and it twitches
	var to_p := 0.0
	var P := Game.player
	if P != null and tk.awake and not R.dead:
		to_p = clampf(U.wrap_angle(atan2(P.x - R.x, P.z - R.z) - R.yaw), -1.1, 1.1)
	var hy := _qq(&"hy", to_p, 12.0, dt)
	var twitch := (0.3 if fmod(t * 2.3 + seed_ * 9.0, 2.3) < 0.08 else 0.0) * up
	var hx := -bend * 1.25 * up + fold * 0.5 - scream * 0.35 - wind * 0.2 + hit * 0.3
	pose.euler(j["neck"], hx * 0.5, hy * 0.5, twitch + shake * 0.1)
	pose.euler(j["head"], hx * 0.5, hy * 0.5, -twitch * 0.6 + sin(t * 0.45) * 0.05 * up)
	pose.euler(j["jaw"], 0.06 + scream * 0.95 + wind * 0.7 + hit * 0.5 + strain * (0.55 + 0.2 * sin(t * 17.0)) + twitch * 0.5, 0.0, 0.0)
	# ---- arms and legs
	for sd: float in [1.0, -1.0]:
		var tag := "L" if sd > 0.0 else "R"
		var sw := s * sd
		var claw := sin(t * 8.5 + sd * 1.6) * strain      # at the cables' end the arms take turns raking the air
		# up: hanging, a little out, the blades trailing | run: swept back | strain: out in front, raking | wind: both back over the shoulders | hit: down and across | fold: crossed on the chest
		var ux := (-0.12 - bend * 0.55 + sw * 0.18 * run + run * 0.95 - strain * (1.75 + claw * 0.5) - wind * 2.5 + hit * 2.1 - after * 0.5 + reel * 0.6) * up - fold * 1.05
		var uz := sd * ((0.16 + run * 0.2 + wind * 0.5 - hit * 0.3 + scream * 0.7) * up - fold * 0.5)
		pose.euler(j["upper_arm" + tag], ux, sd * fold * 0.5, uz)
		pose.euler(j["forearm" + tag], (-0.3 - run * 0.35 - strain * 0.3 * (1.0 - claw) - wind * 0.9 + hit * 0.7 - scream * 0.5) * up - fold * 2.0, 0.0, -sd * fold * 0.5)
		pose.euler(j["hand" + tag], (-0.15 + run * 0.4 - wind * 0.5 + hit * 0.6 + sin(t * 2.6 + sd) * 0.06) * up - fold * 0.3, 0.0, sd * 0.1)
		var st := s * -sd
		var lift := maxf(0.0, cos(phase_) * -sd)
		pose.euler(j["thigh" + tag], -0.1 - run * 0.25 + st * 0.75 * run - lift * 0.3 * run - fold * 1.15 - strain * 0.15 * sd, 0.0, sd * (0.06 + fold * 0.22))
		pose.euler(j["shin" + tag], 0.1 + run * 0.2 + lift * 0.85 * run + fold * 1.55, 0.0, 0.0)
		pose.euler(j["foot" + tag], -run * 0.1 - st * 0.3 * run - lift * 0.4 * run - fold * 0.45, 0.0, 0.0)
	# ---- lights: one dim point folded; green up; amber for the wind-up and the blow; they stutter out when it dies
	var d := batch.data
	var o := row * batch.stride
	d[o] = R.flash * 0.6
	if R.dead:
		_col(d, o + 4, 0x06140a)
		d[o + 7] = maxf(0.0, 1.0 - R.dead_t * 1.2) * (1.0 if fmod(R.dead_t * 13.0, 1.0) < 0.5 else 0.15)
	elif wind > 0.0 or hit > 0.0:
		_col(d, o + 4, AMBER)
		d[o + 7] = 0.9 + wind * 0.5
	else:
		_col(d, o + 4, GREEN)
		var wake_flick := 1.0 if R.state != &"alert" or fmod(R.state_t * 14.0, 1.0) < 0.55 else 0.1
		d[o + 7] = (0.07 + 0.05 * sin(t * 1.3) + up * 0.75) * wake_flick * (1.0 - 0.35 * absf(shake))
	update_bar(dt, 2.95 * size - fold * 0.8, 1.1)
	# ---- down: it goes onto its knees and its face, and hangs there on the cables
	var root := Basis(Vector3.UP, R.yaw) * Basis(Vector3.RIGHT, fall * 0.55)
	pose.compose(Transform3D(root.scaled_local(Vector3(size, size, size)), Vector3(R.x, R.y - fall * 0.1, R.z)))
	# ---- the cables
	var chest := pose.world[j["chest"]]
	var floor_y := R.y + 0.05
	for k in 3:
		var a := chest * PORTS[k]
		var b := ends[k]
		var span := a.distance_to(b)
		var length := tk.reach + SPARE[k]
		var sag := 0.42 * sqrt(maxf(0.0, length * length - span * span))
		var slack := clampf(sag / 1.5, 0.0, 1.0)
		var prev := a
		for i in SEGS:
			var u := float(i + 1) / SEGS
			var q := a.lerp(b, u)
			var hang := 4.0 * u * (1.0 - u)
			q.y = maxf(q.y - sag * hang, minf(floor_y, lerpf(a.y, b.y, u)))
			q += side * (sin(t * 1.3 + i * 0.7 + k * 2.1) * 0.06 * slack * hang)
			q.y += sin(t * 37.0 + i * 1.9 + k) * 0.02 * strain * hang      # taut, it shakes
			var y := q - prev
			if y.length_squared() < 0.0001:
				y = Vector3(0.0, 0.01, 0.0)
			var yn := y.normalized()
			var x := yn.cross(Vector3.UP if absf(yn.y) < 0.95 else Vector3.RIGHT).normalized()
			pose.world[cab[k][i]] = Transform3D(Basis(x, y, x.cross(yn)), prev)
			prev = q
	upload()
