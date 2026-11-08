class_name GristleBruteView
extends CreatureView
## GRISTLE BRUTE on screen (JS enemies/gristle-brute-view.js): a hunched, bull-necked mass of fused torsos on short, thick legs, hiding behind a huge fanged rib shield gripped by four arms. Hooves stay planted in world space (2-bone IK with a forward pole), the shield bobs on every step, it paws the floor like a bull before a charge, and every slam ends with the shield stuck in the floor for a vulnerable beat. Same animation as the JS, statement for statement.

const HIP_Y := 1.05
const TH := 0.62
const SH_L := 0.64
const UA := 0.5
const FA := 0.55
const CH_SPINE := 0
const CH_BACK := 1
const SPINE_Y: Array[float] = [0.3, 0.7, 1.1]

static var _model: CreatureModel = null

## JS this.legs
class Leg:
	var th: int
	var sh: int
	var hoof: int
	var sx: float
	var plant := Vector3.ZERO
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var cur := Vector3.ZERO
	var step_t := -1.0
	var init := false

## JS this.arms
class Arm:
	var u: int
	var f: int
	var hand: int
	var sx: float
	var sh: Vector3
	var gi: int

var j_body: int
var j_torso: int
var j_shield: int
var j_plate_l: int
var j_plate_r: int
var j_head: Array[int] = []
var j_jaw: Array[int] = []
var j_eye: Array = []
var head_base: Array[Transform3D] = []
var head_yaw0: Array[float] = [0.0, 0.5]
var legs: Array[Leg] = []
var arms: Array[Arm] = []
var ribs: Array = []       # [joint, sx, i]
var grips: Array[Vector3] = []

var t := 0.0
var age := 0.0
var hold_t := 0.0
var prev_state: StringName
var prev_st := 0.0
var prev_flash := 0.0
var prev_block := 0.0
var notice_t := 9.0
var last_pos: Vector3
var vel := Vector3.ZERO
var yaw_prev := 0.0
var yaw_rate := 0.0
var prev_dead := 0.0
var stride_ph := 0.0
var sf: Array = []
var cracks: FxBeam.Cracks

var sp_lean := AnimKit.Spring.new(110.0, 0.5)
var sp_y := AnimKit.Spring.new(160.0, 0.45)
var sp_sq := AnimKit.Spring.new(260.0, 0.3)
var sp_roll := AnimKit.Spring.new(110.0, 0.5)
var sp_twist := AnimKit.Spring.new(130.0, 0.5)
var sp_raise := AnimKit.Spring.new(150.0, 0.45)
var sp_tilt := AnimKit.Spring.new(150.0, 0.4)
var sp_fwd := AnimKit.Spring.new(200.0, 0.4)
var sp_side := AnimKit.Spring.new(90.0, 0.55)
var sp_open := AnimKit.Spring.new(90.0, 0.45)
var sp_head := AnimKit.Spring.new(140.0, 0.45)
var sp_jaw := AnimKit.Spring.new(300.0, 0.3)
var sp_look := AnimKit.Spring.new(70.0, 0.7)
var sp_kneel := AnimKit.Spring.new(70.0, 0.6)
var react := AnimKit.Reaction.new(170.0, 0.32)
var blink: AnimKit.Blink
var fidget: AnimKit.Fidget


static func get_model() -> CreatureModel:
	if _model == null:
		_model = CreatureModel.build("res://assets/objects/enemy_brute.glb", _glow, {}, {"bruteEye": 1})
		_model.body_mat.set_shader_parameter(&"flash_tint", Vector3(0.7, 0.35, 0.2))
	return _model


static func _glow(s: RobotGfx.SpriteSoup, m: CreatureModel) -> void:
	var torso: int = m.names["torso"]
	for i in 3:
		s.sprite(torso, CH_SPINE, Vector3(0.0, 0.3 + i * 0.4, -0.98), 0.7)
	s.sprite(torso, CH_BACK, Vector3(0.0, 0.6, -1.05), 1.7)


func _init(p_r: GristleBrute) -> void:
	super._init(p_r, get_model())
	var n: Dictionary = model.names
	j_body = n["body"]
	j_torso = n["torso"]
	j_shield = n["shield"]
	j_plate_l = n["plateL"]
	j_plate_r = n["plateR"]
	j_spine = j_torso
	j_el_l = j_shield
	for i in 2:
		j_head.append(n["head%d" % i])
		j_jaw.append(n["jaw%d" % i])
		j_eye.append([n["eye%d0" % i], n["eye%d1" % i]])
	j_muzzle = j_head[0]
	var side := 0
	for sx: float in [-1.0, 1.0]:
		var L := Leg.new()
		L.sx = sx
		L.th = n["th%d" % side]
		L.sh = n["sh%d" % side]
		L.hoof = n["hoof%d" % side]
		legs.append(L)
		for i in 3:
			ribs.append([n["rib%d%d" % [side, i]], sx, i])
		side += 1
	for g: Array in [[-1.0, 0.62, 0.62], [1.0, 0.62, 0.62], [-1.0, -0.55, 0.6], [1.0, -0.55, 0.6]]:
		grips.append(Vector3(g[0] * (0.15 + g[2]), g[1], -0.06))
	var ai_ := 0
	for a: Array in [[-1.0, 0.95, 0.25, 0], [1.0, 0.95, 0.25, 1], [-1.0, 0.42, 0.3, 2], [1.0, 0.45, 0.3, 3]]:
		var A := Arm.new()
		A.sx = a[0]
		A.sh = Vector3(a[0] * 0.72, a[1], a[2])
		A.gi = a[3]
		A.u = n["u%d" % ai_]
		A.f = n["f%d" % ai_]
		A.hand = n["hand%d" % ai_]
		arms.append(A)
		ai_ += 1
	prev_state = R.state
	last_pos = Vector3(R.x, R.y, R.z)
	yaw_prev = R.yaw
	blink = AnimKit.Blink.new(2.0, 5.0, 0.12, fmod(R.id * 0.37, 1.0))
	fidget = AnimKit.Fidget.new([1.4, 1.2, 1.8, 1.4], 3.5, 8.0, fmod(R.id * 0.53, 1.0))
	var d := batch.data
	var o := row * batch.stride
	_col(d, o + 16, 0xff6a40)
	_col(d, o + 20, 0xff5030)
	d[o + 12 + CH_SPINE] = 1.0
	d[o + 12 + CH_BACK] = 1.0
	cracks = FxBeam.Cracks.new(2, 3.0)


func dispose() -> void:
	super.dispose()
	cracks.free_all()


func sprite_world(_i: int) -> Vector3:
	return pose.world[j_torso] * Vector3(0.0, 0.6, -1.05)      # the back glow


## JS ik2: 2-bone IK with a pole. Place upper bone `a` (length la, points -y at rest) at A and lower bone `b` so it ends at F; the knee bends toward pole
func _ik2(a: int, b: int, A: Vector3, F: Vector3, la: float, lb: float, p: Vector3) -> Vector3:
	var nv := F - A
	var D := nv.length()
	var max_d := la + lb - 0.002
	if D > max_d:
		D = max_d
	if D < 0.05:
		nv = Vector3.DOWN
		D = 0.05
	var nn := nv.normalized()
	var x := (la * la - lb * lb + D * D) / (2.0 * D)
	var h := sqrt(maxf(0.0, la * la - x * x))
	var i2 := p - nn * p.dot(nn)
	if i2.length_squared() < 1e-6:
		i2 = Vector3(0.0, 0.0, 1.0)
	i2 = i2.normalized()
	var K := A + nn * x + i2 * h
	pose.pos[a] = A
	pose.rot[a] = _from_down((K - A).normalized())
	pose.pos[b] = K
	pose.rot[b] = _from_down((A + nn * D - K).normalized())
	return K


## JS quaternion.setFromUnitVectors(DOWN, v)
static func _from_down(v: Vector3) -> Basis:
	if v.dot(Vector3.DOWN) < -0.99999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.DOWN, v))


## three.js 'YXZ' rotation
static func _yxz(x: float, y: float, z: float) -> Basis:
	return Basis.from_euler(Vector3(x, y, z), EULER_ORDER_YXZ)


func update(dt: float, _now: float, fx: Variant) -> void:
	var B := R as GristleBrute
	var st := B.state
	var dead := st == &"dead"
	var s_t := B.state_t
	t += dt
	age += dt
	var charge := B.atk == &"charge"
	var melee := B.atk == &"melee"
	var ch := B.ch
	var missed := ch != null and ch.missed
	var exposed := B.exposed_t > 0.0
	# ---- events ----
	if B.flash > prev_flash + 0.2 and not dead:
		var c0 := cos(B.yaw)
		var s0 := sin(B.yaw)
		react.hit(B.hit_x * c0 - B.hit_z * s0, B.hit_x * s0 + B.hit_z * c0, minf(1.0, (B.last_dmg if B.last_dmg != 0.0 else 15.0) / 40.0) * 0.6)
	prev_flash = B.flash
	if B.block_t > prev_block + 0.1:      # a blocked hit knocks the shield back into its chest
		sp_fwd.kick(-4.0)
		sp_tilt.kick(-3.0)
		sp_lean.kick(-1.5)
	prev_block = B.block_t
	var was_idle := prev_state == &"idle" or prev_state == &"return" or prev_state == &"search"
	if was_idle and (st == &"pursue" or st == &"alert"):
		notice_t = 0.0
		AnimKit.cue(fx, B, "roar", 0.7)
	var prev_s := prev_st if st == prev_state else -1.0
	prev_state = st
	prev_st = s_t
	notice_t += dt
	if prev_dead != 0.0 and not dead:
		age = 0.0
		for L: Leg in legs:
			L.init = false
	var spawn_u := age
	var emerging := not dead and spawn_u < 1.3
	hold_t = maxf(0.0, hold_t - dt)
	var sdt := 0.0 if hold_t > 0.0 else dt
	var vv := Vector3(B.x - last_pos.x, 0.0, B.z - last_pos.z) / maxf(dt, 1e-4)
	if vv.length_squared() > 900.0:
		vv = Vector3.ZERO
	vel = vel.lerp(vv, 1.0 - exp(-10.0 * dt))
	last_pos = Vector3(B.x, B.y, B.z)
	var yr := B.yaw - yaw_prev
	yr = atan2(sin(yr), cos(yr))
	yaw_rate += (yr / maxf(dt, 1e-4) - yaw_rate) * (1.0 - exp(-6.0 * dt))
	yaw_prev = B.yaw
	var speed := U.hyp(vel.x, vel.z)
	var cs := cos(B.yaw)
	var sn := sin(B.yaw)
	var fwd_v := vel.x * sn + vel.z * cs
	# ---- target pose ----
	var br := 0.5 + 0.5 * sin(t * 1.6)
	var lean := 0.12 + _n(fwd_v / 3.0) * 0.12
	var y := -0.03 * br
	var sq := 0.0
	var roll := -yaw_rate * 0.08
	var twist := 0.0
	var s_raise := 0.0
	var s_tilt := 0.0
	var s_fwd := 0.0
	var s_side := 0.0
	var open := 1.0 if exposed or dead else 0.0
	var head_p := 0.05 * sin(t * 1.1)
	var jaw := 0.08 + 0.05 * br
	var look := 1.0
	var red := 0.0
	var squint := 0.0
	var kneel := 0.0
	var paw := 0.0
	var shiver := 0.0
	var dizzy := 0.0
	var direct := false
	fidget.step(dt, st == &"pursue" and speed < 0.3 and not dead and notice_t > 1.0 and not exposed)
	var f0 := fidget.env(0)
	var f1 := fidget.env(1)
	var f2 := fidget.env(2)
	var f3 := fidget.env(3)
	var fu := fidget.u
	s_raise += 0.25 * f0 * sin(fu * PI)
	if AnimKit.crossed(fu - dt / 1.4, fu, 0.62) and f0 > 0.5:
		AnimKit.cue(fx, B, "thud")                                       # shield adjust: hefts and drops it
	var snap := f1 * maxf(0.0, sin(fu * PI * 4.0))                       # the heads snap at each other
	head_p += 0.3 * f3
	jaw += 0.4 * f3 * absf(sin(fu * 20.0))
	shiver += f2 * 0.5                                                   # snort / shake
	if notice_t < 1.0 and not dead:
		var nh := AnimKit.hold(notice_t, 0.1, 0.55, 0.1, 0.3)
		s_raise += 0.5 * nh
		lean -= 0.25 * nh
		jaw = maxf(jaw, nh)
		red = nh
		if notice_t > 0.55:
			s_raise -= 0.9 * AnimKit.pulse(notice_t, 0.7, 0.18)
	if melee and st == &"windup":                                        # SHIELD SLAM: dip, heave the shield overhead, lean back, tremble at the lock
		var u := s_t / GristleBrute.SLAM_WIND
		var up := AnimKit.out_back(AnimKit.win(u, 0.15, 0.75), 1.2)
		sf = []
		y -= 0.12 * AnimKit.pulse(u, 0.08, 0.12)
		s_raise = 1.25 * up
		s_tilt = -0.6 * up
		lean = 0.1 - 0.35 * up
		head_p -= 0.25 * up
		jaw = 0.5 * up
		squint = up
		red = up
		shiver += AnimKit.win(u, 0.7, 1.0)
	elif melee and st == &"attack":                                      # ...the smash lands at m_hit (0.15 s) and stays planted
		var u := _n(s_t / 0.15)
		var de := AnimKit.in_cubic(u)
		if prev_s < 0.0 or sf.is_empty():
			sf = [sp_raise.x, sp_tilt.x, sp_lean.x, sp_fwd.x]            # swing from wherever the wind-up left it
		s_raise = lerpf(sf[0], -0.55, de)
		s_tilt = lerpf(sf[1], 0.9, de)
		s_fwd = lerpf(sf[3], 0.35, de)
		lean = lerpf(sf[2], 0.55, de)
		y -= 0.25 * de
		head_p += 0.3 * de
		jaw = 0.9
		red = 1.0
		direct = true                                                    # the smash itself is driven frame-exact (springs snapped) so the shield is on the floor at the damage frame
		if AnimKit.crossed(prev_s, s_t, 0.15):
			hold_t = 0.07
			sp_sq.kick(6.0)
			sp_y.kick(-2.0)
			AnimKit.cue(fx, B, "thud")
			AnimKit.fx_shake(fx, B, 0.35, 12.0)
			cracks.place(B.x + sn * 1.4, B.y, B.z + cs * 1.4, 2.2)
			if fx != null:
				fx.dust(Vector3(B.x + sn * 1.3, B.y + 0.05, B.z + cs * 1.3), 10, 1.6)
	elif melee and st == &"recover":
		sf = []                                                          # stuck in the floor, then wrenched free: the back is wide open
		var u := s_t / 0.9
		var free := AnimKit.win(u, 0.45, 0.95)
		s_raise = lerpf(-0.55, 0.0, free) + 0.06 * sin(t * 30.0) * AnimKit.win(u, 0.35, 0.55) * (1.0 - free)
		s_tilt = lerpf(0.9, 0.0, free)
		s_fwd = lerpf(0.35, 0.0, free)
		lean = lerpf(0.55, 0.12, free)
		y -= 0.25 * (1.0 - free)
		jaw = 0.4 * (1.0 - free) + 0.1
		if AnimKit.crossed(prev_s, s_t, 0.5):
			AnimKit.cue(fx, B, "wheeze")
	elif charge and st == &"windup":                                     # CHARGE: plants, paws the floor twice, lowers the heads, roars; locks and shivers
		var u := s_t / GristleBrute.CHARGE_WIND
		paw = maxf(0.0, sin(u / 0.75 * PI * 2.0)) if u < 0.75 else 0.0
		lean = 0.12 + 0.3 * AnimKit.win(u, 0.0, 0.4)
		y -= 0.12 * AnimKit.win(u, 0.0, 0.3)
		s_raise = 0.25 * AnimKit.win(u, 0.0, 0.3)
		s_fwd = 0.15
		head_p += 0.35 * AnimKit.win(u, 0.0, 0.4)
		jaw = 0.85 * AnimKit.hold(u, 0.25, 0.65, 0.1, 0.15)
		red = AnimKit.win(u, 0.0, 0.3)
		squint = AnimKit.win(u, 0.75, 0.9)
		shiver += AnimKit.win(u, 0.75, 0.95)
		if AnimKit.crossed(prev_s, s_t, 0.1):
			AnimKit.cue(fx, B, "inhale", GristleBrute.CHARGE_WIND)
	elif charge and st == &"attack":                                     # ...head down, all in
		lean = 0.6
		s_fwd = 0.3
		s_raise = 0.1
		head_p += 0.3
		jaw = 0.6
		red = 1.0
		y -= 0.08
	elif charge and st == &"recover":
		if missed:                                                       # missed: skids, stumbles, the shield sags to one side, dizzy
			var u := s_t / GristleBrute.SKID
			lean = lerpf(-0.35, 0.2, AnimKit.win(u, 0.1, 0.5))
			y -= 0.15 * AnimKit.pulse(u, 0.25, 0.25)
			s_side = 0.55 * AnimKit.hold(u, 0.15, 0.85, 0.15, 0.15)
			s_raise = -0.35 * AnimKit.hold(u, 0.15, 0.85, 0.15, 0.15)
			dizzy = AnimKit.hold(u, 0.25, 0.85, 0.15, 0.15)
			jaw = 0.35
			if AnimKit.crossed(prev_s, s_t, 0.02):
				sp_lean.kick(-3.0)
				AnimKit.cue(fx, B, "crack")
				if fx != null:
					fx.dust(Vector3(B.x, B.y + 0.05, B.z), 12, 2.2)
		else:                                                            # hit: recoils off the impact
			var u := s_t / 0.7
			lean = lerpf(-0.25, 0.12, AnimKit.win(u, 0.0, 0.7))
			jaw = 0.5 * (1.0 - u)
			if AnimKit.crossed(prev_s, s_t, 0.02):
				sp_lean.kick(-4.0)
				hold_t = 0.06
	if st == &"stagger":
		var u := s_t / 0.6
		lean -= 0.35 * AnimKit.hold(u, 0.05, 0.6, 0.05, 0.3)
		s_side = 0.3 * sin(t * 9.0)
		dizzy = 1.0 - AnimKit.win(u, 0.6, 1.0)
		jaw = 0.5
	if exposed and not dead and not (charge and st == &"recover"):
		shiver += 0.4
		dizzy = maxf(dizzy, 0.5)
		lean += 0.15
		jaw = maxf(jaw, 0.4)
	# death: roars and staggers back, drops the shield, kneels, topples onto its face, twitches, sinks
	var d_t := B.dead_t if dead else 0.0
	if dead:
		var back := AnimKit.hold(d_t, 0.1, 0.45, 0.1, 0.2)
		var drop := AnimKit.win(d_t, 0.5, 0.8)
		var kn := AnimKit.win(d_t, 0.9, 1.4)
		var top := AnimKit.win(d_t, 1.5, 2.2)
		var sink := AnimKit.win(d_t, 4.6, 6.0)
		lean = -0.3 * back + 0.5 * kn + 1.0 * top
		jaw = back + 0.5 * top
		red = 1.0 - AnimKit.win(d_t, 1.2, 2.6)
		s_raise = -0.8 * drop
		s_fwd = 0.5 * drop
		s_tilt = 1.3 * drop
		open = 1.0
		kneel = kn
		y -= 0.25 * kn + 0.45 * top + 1.2 * sink
		head_p += 0.6 * top
		roll = 0.2 * top
		if AnimKit.crossed(prev_dead, d_t, 0.75):
			AnimKit.cue(fx, B, "thud")
		if AnimKit.crossed(prev_dead, d_t, 2.1):
			AnimKit.cue(fx, B, "thud")
			AnimKit.fx_shake(fx, B, 0.3, 10.0)
		if d_t > 2.4 and d_t < 4.0:
			shiver += 0.6 * AnimKit.pulse(fmod(d_t, 0.8), 0.15, 0.12)
	prev_dead = d_t
	if emerging:
		var u := spawn_u
		y -= 0.9 * (1.0 - AnimKit.out_back(AnimKit.win(u, 0.0, 0.8), 1.3))
		lean += 0.4 * (1.0 - AnimKit.win(u, 0.3, 0.9))
		jaw = maxf(jaw, AnimKit.hold(u, 0.7, 1.05, 0.1, 0.2))
		s_raise += 0.4 * AnimKit.hold(u, 0.75, 1.0, 0.1, 0.2)
	# ---- springs ----
	var lean_t := lean
	lean = sp_lean.step(lean, sdt)
	if direct:
		sp_lean.snap(lean_t)
		lean = lean_t
	y = sp_y.step(y, sdt)
	sq = sp_sq.step(sq, sdt)
	roll = sp_roll.step(roll, sdt)
	twist = sp_twist.step(twist, sdt)
	if direct:
		sp_raise.snap(s_raise)
		sp_tilt.snap(s_tilt)
		sp_fwd.snap(s_fwd)
	else:
		s_raise = sp_raise.step(s_raise, sdt)
		s_tilt = sp_tilt.step(s_tilt, sdt)
		s_fwd = sp_fwd.step(s_fwd, sdt)
	s_side = sp_side.step(s_side, sdt)
	open = sp_open.step(open, sdt)
	head_p = sp_head.step(head_p, sdt)
	jaw = sp_jaw.step(jaw, sdt)
	kneel = sp_kneel.step(kneel, sdt)
	react.step(dt)
	var rp := react.pitch.x
	var rr := react.roll.x
	var shv := sin(t * 53.0) * 0.02 * shiver if shiver > 0.0 else 0.0
	# ---- body ----
	var lift := 0.0
	for L: Leg in legs:
		if L.step_t >= 0.0:
			lift = maxf(lift, sin(PI * L.step_t))
	var root := Transform3D(Basis(Vector3(cs, 0.0, -sn), Vector3.UP, Vector3(sn, 0.0, cs)), Vector3(B.x, B.y, B.z))
	pose.pos[j_body] = Vector3(shv + 0.04 * sin(stride_ph) * _n(speed), HIP_Y + y + 0.05 * lift - 0.04, 0.0)
	pose.rot[j_body] = _yxz(0.0, twist, roll + rr * 0.6 + 0.05 * sin(stride_ph) * _n(speed) + dizzy * 0.08 * sin(t * 4.0))
	pose.scl[j_body] = Vector3(1.0 + sq * 0.3, 1.0 - sq * 0.4, 1.0 + sq * 0.3)
	pose.euler(j_torso, lean - rp * 0.6 + dizzy * 0.06 * sin(t * 3.1), shv * 2.0, 0.0)
	# shield: raise (up/over), tilt (top toward the floor), forward push, sag sideways; plates swing open when blown / skidding / dead
	pose.pos[j_shield] = Vector3(0.5 * s_side, 0.35 + 0.75 * maxf(0.0, s_raise) + 0.45 * minf(0.0, s_raise), 0.95 + 0.25 * s_fwd - 0.35 * maxf(0.0, s_raise) - 0.2 * open)
	pose.euler(j_shield, -0.15 - s_tilt * 0.9 + 0.5 * maxf(0.0, s_raise) + rp * 0.4, 0.0, 0.6 * s_side + open * 0.25 + 0.05 * sin(stride_ph) * _n(speed) + shv * 3.0)
	pose.euler(j_plate_l, 0.0, -open * 1.15, 0.0)
	pose.euler(j_plate_r, 0.0, open * 1.15, 0.0)
	# heads: look at the player (the stunted one lags), squint and roar, the two snap at each other when idle
	var look_t := 0.0
	var P: Variant = fx.last_player if fx != null and fx.last_player != null else null
	if P != null and not dead:
		var da := atan2(float(P.x) - B.x, float(P.z) - B.z) - B.yaw
		da = atan2(sin(da), cos(da))
		look_t = clampf(da, -0.7, 0.7) * look
	if AnimKit.crossed(notice_t - dt, notice_t, 0.06):
		sp_look.kick((look_t - sp_look.x) * 12.0)
	var lk := sp_look.step(look_t + 0.3 * fidget.env(0) * sin(fu * 6.0), dt)
	var bl := blink.step(dt)
	for i in 2:
		var lag := 0.6 if i == 1 else 1.0
		var m := float(i)
		pose.rot[j_head[i]] = _yxz(head_p * (0.7 if i == 1 else 1.0) + rp * 0.4 + (0.25 * sin(t * 0.9) if i == 1 else 0.0) - (0.2 * snap if i == 1 else 0.0), head_yaw0[i] + lk * lag - (0.45 * snap if i == 1 else -0.25 * snap), (0.2 if i == 1 else 0.0) + rr + dizzy * 0.2 * sin(t * 5.0 + m))
		pose.euler(j_jaw[i], maxf(0.0, jaw + (0.3 * snap if i == 1 else 0.0)) * 0.7, 0.0, 0.0)
		var eye_y := maxf(0.05, 1.0 - AnimKit.win(d_t, 1.2, 2.4)) if dead else maxf(0.12, 1.0 - bl - 0.6 * squint)
		for e: int in j_eye[i]:
			pose.scl[e] = Vector3(0.04, 0.035 * eye_y, 0.03)
	var eye_k := maxf(0.0, 1.0 - AnimKit.win(d_t, 1.2, 2.6)) if dead else 1.0
	var d := batch.data
	var o := row * batch.stride
	d[o] = B.flash
	d[o + 4] = 1.0 * eye_k
	d[o + 5] = (0.62 - 0.52 * _n(red)) * eye_k
	d[o + 6] = (0.25 - 0.2 * _n(red)) * eye_k
	# weak point: the raw back pulses, much harder when it is exposed (blown open / stuck after a slam / skidding)
	var vuln := 1.0 if exposed or (melee and st == &"recover") else 0.0
	var beat := pow(0.5 + 0.5 * sin(t * (5.0 + 3.0 * vuln)), 4.0)
	d[o + 16 + 3] = 0.0 if dead else (0.3 + 0.35 * beat) * (2.0 if vuln > 0.0 else 1.0)
	d[o + 20 + 3] = 0.0 if dead else (0.6 + 0.35 * beat if vuln > 0.0 else 0.12 + 0.08 * beat)
	d[o + 8] = 0.2 * (1.0 - AnimKit.win(d_t, 0.5, 2.5)) if dead else 0.06 + 0.04 * beat + 0.6 * vuln * beat + B.flash * 0.8      # JS glow value (hide, raw)
	d[o + 9] = 0.12 + 2.2 * _n(B.block_t / 0.25) + 0.6 * (1.0 - _n(B.hp / B.max)) + 0.5 * red * 0.3                              # JS boneM.emissiveIntensity
	# damage states: the shield's ribs break off as it weakens, the left plate cracks open
	var hp_f := _n(B.hp / B.max)
	for rb: Array in ribs:
		var sx: float = rb[1]
		var ri: int = rb[2]
		var gone := (hp_f < 0.6 and sx < 0.0 and ri == 1) or (hp_f < 0.35 and sx > 0.0 and ri == 2) or (hp_f < 0.2 and ri == 0)
		pose.scl[rb[0]] = Vector3.ONE * (0.0001 if gone else 1.0)
	# ---- legs: biped stepping with world-planted hooves, IK with a forward pole; kneel / paw / emerge override in body space ----
	var airborne := dead or emerging
	var step_dur := 0.16 if speed > 5.0 else (0.24 if speed > 2.0 else 0.3)
	stride_ph += dt * speed * 2.2
	var busy := false
	for L: Leg in legs:
		if L.step_t >= 0.0:
			busy = true
	var want: Leg = null
	var want_err := 0.0
	for L: Leg in legs:
		var V := root * Vector3(L.sx * 0.42, 0.0, 0.05)
		V.y = B.y
		V += vel * (0.12 if speed > 5.0 else 0.22)
		if not L.init or airborne:
			L.plant = V
			L.cur = V
			L.step_t = -1.0
			L.init = true
		elif L.step_t >= 0.0:
			L.step_t += sdt / step_dur
			L.to = V
			var u := AnimKit.in_out_sine(minf(1.0, L.step_t))
			L.cur = L.from.lerp(L.to, u)
			L.cur.y += sin(PI * minf(1.0, L.step_t)) * (0.18 + 0.03 * speed)
			if L.step_t >= 1.0:
				L.step_t = -1.0
				L.plant = L.to
				L.cur = L.to
				if speed > 0.5:
					AnimKit.cue(fx, B, "step")
					if speed > 5.0 and fx != null:
						fx.dust(L.cur, 2, 0.6)
		else:
			L.cur = L.plant
			var err := U.hyp(V.x - L.plant.x, V.z - L.plant.z)
			if not busy and err > (0.35 if charge and st == &"attack" else 0.42) and err > want_err:
				want_err = err
				want = L
	if want != null:
		want.step_t = 0.0
		want.from = want.plant
	pose.compose(root)
	var inv := root.affine_inverse()
	for L: Leg in legs:
		var foot := inv * L.cur                                            # hoof in creature space
		if L.sx > 0.0 and paw > 0.0:                                       # the bull paw (right hoof scrapes back)
			foot.z -= 0.35 * paw
			foot.y += 0.12 * paw
		if kneel > 0.01:                                                   # drops to its knees (one forward, one back)
			foot = foot.lerp(Vector3(L.sx * 0.45, 0.05, 0.55 if L.sx < 0.0 else -0.45), kneel)
		foot.y = maxf(foot.y, 0.0) + 0.02
		var hip := inv * (pose.world[j_body] * Vector3(L.sx * 0.42, 0.0, 0.0))      # the hip rides with the body; IK in creature space (the leg groups are children of g)
		_ik2(L.th, L.sh, hip, foot, TH, SH_L, Vector3(0.0, 0.0, 1.0))
		pose.pos[L.hoof] = foot - Vector3(0.0, 0.02, 0.0)
		pose.euler(L.hoof, -0.35 * sin(PI * L.step_t) if L.step_t >= 0.0 else 0.0, 0.0, 0.0)
	# ---- arms: shoulders (torso) to grips on the shield edge, elbows out and down ----
	pose.compose(root)
	var torso_inv := pose.world[j_torso].affine_inverse()
	var shield_rot := pose.rot[j_shield]
	for A: Arm in arms:
		var grip := torso_inv * (pose.world[j_shield] * grips[A.gi])       # the grip, in torso space
		_ik2(A.u, A.f, A.sh, grip, UA, FA, Vector3(A.sx, -0.6, -0.3))
		pose.pos[A.hand] = grip
		pose.rot[A.hand] = shield_rot
	cracks.update(dt)
	if dead and d_t > 6.0:
		batch.clear_row(row)
		return
	update_bar(dt, 3.1, 1.16 / 0.86, 1.0, true)
	pose.compose(root)
	upload()

