class_name MaintenanceSpiderView
extends CreatureView
## The maintenance spider on screen (JS enemies/robot-visuals.js buildSpiderView): an armoured hull on eight stepping legs, each leg three rods drawn between its joints, eyes that go red on the wind-up. No health bar, as in the JS (it clears the stock view).

const UP := Vector3(0.0, 1.0, 0.0)

static var _model: CreatureModel = null

var phase_ := 0.0
var last_x := 0.0
var last_z := 0.0
var j_hull := 0
var eyes: Array[int] = []
var legs: Array[Dictionary] = []


static func get_model() -> CreatureModel:
	if _model == null:
		_model = CreatureModel.build("res://assets/objects/enemy_spider.glb", Callable(), {}, {"spiderEye": 1})
	return _model


func _init(p_r: Robot) -> void:
	super._init(p_r, get_model())
	last_x = R.x
	last_z = R.z
	var n: Dictionary = model.names
	j_hull = n["hull"]
	j_spine = j_hull
	j_el_l = j_hull
	j_muzzle = n["muzzle"]
	for i in 3:
		eyes.append(n["eye%d" % i])
	var k := 0
	for side: float in [-1.0, 1.0]:
		for i in 4:
			legs.append({"side": side, "i": i, "p0": n["L%d_p0" % k], "p1": n["L%d_p1" % k], "p2": n["L%d_p2" % k], "armor": n["L%d_armor" % k], "hip": n["L%d_hip" % k], "knee": n["L%d_knee" % k], "foot": n["L%d_foot" % k]})
			k += 1


func _segment(j: int, a: Vector3, b: Vector3) -> Basis:
	var delta := b - a
	pose.pos[j] = (a + b) * 0.5
	var s := pose.scl[j]
	s.y = delta.length()
	pose.scl[j] = s
	var q := Basis(Quaternion(UP, delta.normalized()))
	pose.rot[j] = q
	return q


func update(dt: float, _now: float, _fx: Variant) -> void:
	dt = minf(0.05, maxf(0.0, dt))
	var distance := U.hyp(R.x - last_x, R.z - last_z)
	last_x = R.x
	last_z = R.z
	if not R.dead and distance < 1.0:
		phase_ += distance * 5.8
	var speed := U.hyp(R.vx, R.vz)
	var moving := not R.dead and speed > 0.3
	var charge := minf(1.0, R.state_t / 0.35) if R.state == &"windup" else 0.0
	var attack := sin(minf(1.0, R.state_t / 0.3) * PI) if R.state == &"attack" else 0.0
	var p := pose.pos[j_hull]
	p.y = -0.09 if R.dead else -charge * 0.055 + attack * 0.035 + (sin(phase_ * 2.0) * 0.012 if moving else sin(R.t * 2.0) * 0.005)
	pose.pos[j_hull] = p
	pose.euler(j_hull, 0.25 if R.dead else -charge * 0.1 + attack * 0.18, 0.0, 0.65 if R.dead else (sin(phase_) * 0.035 if moving else 0.0))
	for l: Dictionary in legs:
		var li: int = l.i
		var side: float = l.side
		var z := (li - 1.5) * 0.205
		var tt := fposmod(phase_ / PI / 2.0 + (li % 2) * 0.5 + (0.5 if side > 0.0 else 0.0), 1.0)
		var swing := (tt - 0.62) / 0.38 if tt > 0.62 else 0.0
		var travel := (0.11 - tt / 0.62 * 0.22 if tt < 0.62 else -0.11 + swing * 0.22) if moving else 0.0
		var lift := sin(swing * PI) * 0.12 if moving and tt > 0.62 else 0.0
		var spread := 0.5 if R.dead else 0.75 - charge * 0.08
		var A := Vector3(side * 0.27, 0.25 - charge * 0.035, z)
		var B := Vector3(side * 0.49, 0.29 - charge * 0.06, z + (li - 1.5) * 0.045)
		var C := Vector3(side * (spread - 0.04), 0.15 + lift * 0.5, z + travel)
		var D := Vector3(side * spread, 0.025 if R.dead else 0.025 + lift, z + travel + (li - 1.5) * 0.075)
		if R.dead:
			B.y = 0.1
			C.y = 0.06
			D.z = z
		var q0 := _segment(l.p0, A, B)
		_segment(l.p1, B, C)
		_segment(l.p2, C, D)
		pose.pos[l.hip] = A
		pose.pos[l.knee] = B
		pose.pos[l.foot] = D
		pose.pos[l.armor] = A.lerp(B, 0.55)
		pose.rot[l.armor] = q0
		pose.euler(l.foot, -lift * 2.0 if moving else 0.0, 0.0, 0.0)
	var d := batch.data
	var o := row * batch.stride
	d[o] = R.flash * 0.6
	_col(d, o + 4, 0x18232b if R.dead else (0xff4b2b if R.state == &"windup" else (0xffbd68 if R.state == &"attack" else 0x75dbe7)))
	for e: int in eyes:
		var s := pose.scl[e]
		s.z = 0.035 if R.state == &"windup" else 0.025
		pose.scl[e] = s
	pose.compose(Transform3D(Basis(Vector3.UP, R.yaw), Vector3(R.x, R.y, R.z)))
	upload()
