class_name Beatdown
extends Cutscene
## The beat-down (JS cutscenes/beatdown.js): plays after the hub's gray alien finishes his line. Two gray aliens beat the player to the pavement (blood, bone cracks, wet hits), stomp him, laugh, climb into a flying-saucer-with-wheels that pulls up thumping a muffled rap song, and drive off while the camera stays on the player lying in the street. The game is frozen behind it like a dialogue. Layout is relative to the player's spot and the way the first alien faces ("out" = towards the street), so it works on either pavement.
## Lives under the hub level and dies with it. on_end(finished) is the hub's: the alien goes for good.

const FALL := 4.7      # JS TL, seconds on the cutscene clock
const GROUND0 := 5.95
const FINISHER := 9.3
const CAR_START := 10.4
const CAR_STOP := 12.6
const WALK := 12.4
const ENTER := 14.0
const DOME_SHUT := 16.0
const DEPART := 17.0
const FADE_OUT := 20.8
const END_T := 21.7
const HITS: Array[float] = [1.75, 2.25, 2.7, 3.1, 3.45, 3.8, 4.1, 4.4]      # standing punches (who = index % 2)
const KICKS: Array[float] = [6.2, 6.6, 6.95, 7.3, 7.6]      # kicks on the ground
const SMASHES: Array[float] = [8.0, 8.35]      # two-handed overhead pounding
const OFF := {&"punch": 0.28, &"hook": 0.3, &"kick": 0.34, &"smash": 0.42, &"stomp": 0.55}      # seconds from the start of the swing to the moment of impact
const DUR := {&"punch": 0.62, &"hook": 0.66, &"kick": 0.8, &"smash": 0.9, &"stomp": 1.15}
const BLOOD_N := {&"punch": 16, &"hook": 26, &"kick": 24, &"smash": 36, &"stomp": 44, &"finisher": 170}
const BLOOD_S := {&"punch": 3.2, &"hook": 4.0, &"kick": 3.8, &"smash": 4.4, &"stomp": 5.0, &"finisher": 8.0}
const CUTS: Array[float] = [2.2, FALL, GROUND0, FINISHER - 0.4, CAR_START + 0.2, DEPART + 0.2]
const HULL: Array[Vector2] = [Vector2(0.0, 1.13), Vector2(0.35, 1.12), Vector2(0.8, 1.06), Vector2(1.4, 0.96), Vector2(1.9, 0.82), Vector2(2.02, 0.7)]      # saucer-car.js hull profile: height above the road at a distance from its centre


class Al:
	var api: GrayAlienNpc
	var id := 0
	var mode := &"hold"
	var slot := Vector2.ZERO
	var atk := {}
	var lunge := 0.0
	var climb := {}
	var lz := 0.0
	var walk_id := 0


var on_end := Callable()
var t := 0.0
var _ei := 0
var _shake := 0.0
var _fl := 0.0
var _fl_side := 1.0
var _bump := 0.0
var _down := 0.0
var _buckle := 0.0
var _ev: Array[Dictionary] = []
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _p := Vector3.ZERO
var _o := Vector2.ZERO      # towards the street (x, z)
var _sd := Vector2.ZERO     # along the street (x, z)
var _al: Array[Al] = []
var _car: SaucerCar = null
var _rap: RapLoop = null
var _yaw0 := 0.0
var _yaw_f := 0.0
var _hp0 := 100.0
var _car_z0 := 0.0
var _car_z1 := 0.0
var _car_x := 0.0
var _dir_z := 1.0
var _dome_k := 0.0
var _snd := {}


static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


static func _rr(a: float, b: float) -> float:
	return a + randf() * (b - a)


func _ready() -> void:
	Game.cutscenes[&"beatdown"] = self
	_build_sounds()
	_car = SaucerCar.new()      # (made with the level, not when the cutscene starts: no mid-play pipelines)
	_car.visible = false
	add_child(_car)


func _exit_tree() -> void:
	Game.cutscenes.erase(&"beatdown")


## JS snd: all synthesised, rendered once. (Each is one clip: where the JS gives its layers slightly different reverb sends, this uses the largest layer's.)
func _build_sounds() -> void:
	var tr := &"triangle"
	_snd[&"hit"] = synth(0.3, [[0.0, 0.14, 135.0, 46.0, tr, 0.95, 0.003]],
		[[0.0, 0.08, &"lowpass", 2400.0, 380.0, 2.0, 0.8, 0.003], [0.02, 0.16, &"bandpass", 750.0, 220.0, 2.2, 0.45, 0.003]])      # the wet slap
	_snd[&"hook"] = synth(0.3, [[0.0, 0.14, 135.0, 46.0, tr, 0.95 * 1.15, 0.003], [0.0, 0.05, 1500.0, 480.0, &"square", 0.16, 0.003]],
		[[0.0, 0.08, &"lowpass", 2400.0, 380.0, 2.0, 0.8 * 1.15, 0.003], [0.02, 0.16, &"bandpass", 750.0, 220.0, 2.2, 0.45 * 1.15, 0.003],
		[0.01, 0.035, &"highpass", 3200.0, 600.0, 2.0, 0.9, 0.003], [0.07, 0.025, &"highpass", 3800.0, 600.0, 2.0, 0.6, 0.003]])
	for big: bool in [false, true]:
		var k := 1.5 if big else 1.0
		var ns: Array = [[0.0, 0.35, &"lowpass", 1900.0, 110.0, 2.0, 1.2 * k, 0.003], [0.04, 0.3, &"bandpass", 600.0, 160.0, 1.6, 0.7 * k, 0.003]]
		for i in (6 if big else 3):
			ns.append([0.02 + i * 0.035, 0.03, &"highpass", 2600.0 + i * 400.0, 600.0, 2.0, 0.8, 0.003])      # bones giving way
		_snd[&"stomp_big" if big else &"stomp"] = synth(0.6, [[0.0, 0.5, 92.0, 26.0, tr, 1.5 * k, 0.003]], ns)
	_snd[&"gurgle"] = synth(0.6, [[0.0, 0.55, 150.0, 60.0, &"sawtooth", 0.22, 0.003]], [[0.0, 0.55, &"bandpass", 380.0, 900.0, 3.0, 0.35, 0.003]])
	_snd[&"ring"] = synth(3.5, [[0.0, 3.4, 4100.0, 3900.0, tr, 0.05, 0.05]], [])
	_snd[&"hiss"] = synth(0.6, [[0.4, 0.12, 120.0, 60.0, tr, 0.5, 0.003]], [[0.0, 0.55, &"highpass", 2500.0, 6000.0, 2.0, 0.4, 0.003]])
	_snd[&"hop"] = synth(0.15, [[0.0, 0.12, 180.0, 90.0, tr, 0.35, 0.003]], [])
	_snd[&"tyres"] = synth(0.95, [], [[0.0, 0.9, &"bandpass", 700.0, 2400.0, 1.5, 0.5, 0.003]])


func _s(id: StringName, wet: float) -> void:
	Game.sfx.clip(_snd[id], {"gain": 1.0, "wet": wet})


## f = towards the street, r = along the street, h = up
func _rel(f: float, r: float, h: float) -> Vector3:
	return Vector3(_p.x + _o.x * f + _sd.x * r, _p.y + h, _p.z + _o.y * f + _sd.y * r)


## the aliens' cackle: a run of gurgling syllables from his mouth
func _laugh(al: Al, n: int, pitch: float) -> void:
	for i in n:
		_e(t + i * 0.17, func() -> void:
			var m := al.api.mouth_world()
			Game.sfx.play_at("alienSyl", m.x, m.y, m.z, {"range": 40.0, "ref": 3.0, "h": (i * 977 + (al.id + 1) * 131), "pitch": pitch, "last": i == n - 1})
			al.api.set_talk(true)
			_e(t + 0.11, func() -> void: al.api.set_talk(false)))


# ---- the player: reactions, the fall, the floor
func _pose_hook(a: Animator) -> void:
	var g := 1.0 - _down
	var w := _fl
	var d := _down
	var b := _buckle
	_set_p(a, &"upper_armL", -1.05, 0.3, 0.35, g)      # guard up
	_set_p(a, &"forearmL", -1.95, 0.0, 0.0, g)
	_set_p(a, &"upper_armR", -1.05, -0.3, -0.35, g)
	_set_p(a, &"forearmR", -1.95, 0.0, 0.0, g)
	add_pose(a, &"spine1", 0.22 * g + 0.4 * w, 0.0, 0.16 * _fl_side * w)
	add_pose(a, &"spine2", 0.28 * g + 0.45 * w, 0.0, 0.14 * _fl_side * w)
	add_pose(a, &"head", 0.2 * w + 0.12 * g, 0.2 * _fl_side * w, 0.2 * _fl_side * w)
	add_pose(a, &"thighL", -0.5 * b, 0.0, 0.0)      # knees going
	add_pose(a, &"thighR", -0.5 * b, 0.0, 0.0)
	add_pose(a, &"shinL", 0.9 * b, 0.0, 0.0)
	add_pose(a, &"shinR", 0.9 * b, 0.0, 0.0)
	_set_p(a, &"upper_armL", 0.5, 0.0, 1.05, d)      # flopped arms on the floor
	_set_p(a, &"forearmL", -0.5, 0.0, 0.0, d)
	_set_p(a, &"upper_armR", 0.15, 0.0, -0.55, d)
	_set_p(a, &"forearmR", -0.9, 0.0, 0.0, d)
	add_pose(a, &"thighL", -0.25 * d, 0.0, 0.18 * d)
	add_pose(a, &"shinL", 0.5 * d, 0.0, 0.0)
	add_pose(a, &"thighR", 0.1 * d, 0.0, -0.25 * d)
	add_pose(a, &"head", 0.0, 0.35 * d, 0.15 * d)


static func _set_p(an: Animator, k: StringName, x: float, y: float, z: float, m: float) -> void:
	var i := Animator.KEYS.find(k)
	if i < 0 or m <= 0.0:
		return
	an.pose[i] = (an.pose[i] as Vector3).lerp(Vector3(x, y, z), m)


func _pose_player() -> void:
	var an: Animator = Game.animator
	if an == null:
		return
	var a := an.actor
	var B := an.B
	var k := _down
	var sway := _fl * (1.0 - k)
	a.rotation = Vector3(-1.5 * k + 0.3 * sway, Game.player.yaw, _fl_side * 0.22 * sway + (_bump * 0.08 * sin(t * 40.0)) * k)
	a.position.y = Game.player.y + B.pivot * B.scale - B.dead_drop * k - 0.3 * _buckle * (1.0 - k) + 0.05 * _bump * k
	if k > 0.95:
		a.position.x += _rr(-1.0, 1.0) * 0.02 * _bump
		a.position.z += _rr(-1.0, 1.0) * 0.02 * _bump
	else:
		a.position.x += _o.x * 0.12 * _fl * (1.0 - k)
		a.position.z += _o.y * 0.12 * _fl * (1.0 - k)


## where on the player a blow lands
func _target(kind: StringName) -> Vector3:
	var fx_ := sin(_yaw_f)      # lying: head is behind him (-fwd), feet ahead
	var fz := cos(_yaw_f)
	if _down < 0.6:
		return Vector3(_p.x, _p.y + (1.6 if kind == &"hook" else 1.25), _p.z)
	var u := 0.0 if kind == &"finisher" else _rr(0.0, 0.8)      # 0 = head, 1 = feet
	var l := lerpf(0.85, -0.5, u)
	return Vector3(_p.x - fx_ * l, _p.y + 0.22, _p.z - fz * l)


# ---- blows
func _impact(who: int, kind: StringName) -> void:
	var al := _al[who]
	var R := al.api.R
	var dx := _p.x - R.x
	var dz := _p.z - R.z
	var l := sqrt(dx * dx + dz * dz)
	if l == 0.0:
		l = 1.0
	var ux := dx / l
	var uz := dz / l
	var pt := _target(kind)
	var big := kind == &"finisher" or kind == &"stomp"
	var n: int = BLOOD_N[kind]
	var spd: float = BLOOD_S[kind]
	var fx: FX = Game.fx
	fx._blood_spray(pt, ux, uz, n, spd)
	if kind == &"hook" or kind == &"smash" or big:
		fx._blood_spray(pt, -ux * 0.4, -uz * 0.4, roundi(n * 0.4), spd * 0.7)
	var splats := 6 if big else (2 if _down > 0.6 else 1)
	for i in splats:
		fx._blood_splat(pt.x + ux * _rr(0.1, 1.4 if big else 0.8) + _rr(-0.35, 0.35), _p.y, pt.z + uz * _rr(0.1, 1.4 if big else 0.8) + _rr(-0.35, 0.35), _rr(0.9, 1.7) if big else _rr(0.25, 0.7), 80.0)
	if _down > 0.6 and randf() < 0.8:      # the pool under him grows
		fx._blood_splat(pt.x + _rr(-0.15, 0.15), _p.y, pt.z + _rr(-0.15, 0.15), _rr(0.5, 1.0) + (0.8 if kind == &"finisher" else 0.0), 80.0)
	if kind == &"kick" or kind == &"smash" or big:
		_s(&"stomp_big" if kind == &"finisher" else &"stomp", 0.3)
	elif kind == &"hook":
		_s(&"hook", 0.2)
	else:
		_s(&"hit", 0.2)
	if (kind == &"hook" or kind == &"punch") and t < FALL and randf() < 0.55:
		Game.sfx.play("pain")
	if kind == &"kick" and randf() < 0.5:
		_s(&"gurgle", 0.2)
	_shake = maxf(_shake, 1.6 if big else (0.8 if kind == &"smash" else 0.45))
	_fl = 1.0
	_fl_side = -1.0 if randf() < 0.5 else 1.0
	_bump = 1.0
	al.lunge = 1.0
	if kind == &"finisher":
		_s(&"ring", 0.5)
		_shake = 2.2
	Game.player.hp = maxf(8.0, lerpf(_hp0, 8.0, clampf(t / FINISHER, 0.0, 1.0)))


# ---- the aliens
func _make_alien(api: GrayAlienNpc, id: int, slot: Vector2) -> Al:
	var al := Al.new()
	al.api = api
	al.id = id
	al.slot = slot
	api.view.gun_hidden = true
	api.view.post_hook = _post.bind(al)
	return al


## side -1 = A, +1 = B
func _slot_of(side: float) -> Vector2:
	return Vector2(_p.x + _sd.x * 0.8 * side + _o.x * 0.1, _p.z + _sd.y * 0.8 * side + _o.y * 0.1)


static func _mx(pose: CreatureModel.Pose, j: int, axis: int, w_w: float, s_w: float, w_t: float, s_t: float) -> void:
	var e := pose.rot[j].get_euler(EULER_ORDER_XYZ)
	var v := lerpf(e[axis], w_t, w_w)
	e[axis] = lerpf(v, s_t, s_w)
	pose.rot[j] = Basis.from_euler(e, EULER_ORDER_XYZ)


static func _my(pose: CreatureModel.Pose, j: int, w_w: float, s_w: float, w_t: float, s_t: float) -> void:
	var p := pose.pos[j]
	p.y = lerpf(lerpf(p.y, w_t, w_w), s_t, s_w)
	pose.pos[j] = p


static func _sx(pose: CreatureModel.Pose, j: int, axis: int, v: float) -> void:
	var e := pose.rot[j].get_euler(EULER_ORDER_XYZ)
	e[axis] = v
	pose.rot[j] = Basis.from_euler(e, EULER_ORDER_XYZ)


func _swing(al: Al) -> void:
	var a := al.atk
	if a.is_empty():
		return
	var kind: StringName = a.kind
	var tau: float = t - float(a.t0)
	var off: float = OFF[kind]
	var dur: float = DUR[kind]
	if tau > dur:
		al.atk = {}
		return
	var w := ease_(tau / (off - 0.06))
	var s := ease_((tau - (off - 0.06)) / 0.06)
	var r := ease_((tau - off) / (dur - off))
	var ww := w * (1.0 - s)
	var sw := s * (1.0 - r)
	var V := al.api.view
	var Q := V.pose
	var left: bool = a.hand == "L"
	var tw := -1.0 if left else 1.0
	var sh := V.j_sh_l if left else V.j_sh_r
	var el := V.j_el_l if left else V.j_el_r
	if kind == &"punch" or kind == &"hook":
		_mx(Q, sh, 0, ww, sw, 0.6, -1.5)
		_mx(Q, el, 0, ww, sw, -1.9, -0.15)
		_mx(Q, sh, 2, ww, sw, tw * -0.3, 0.0)
		_mx(Q, V.j_spine, 1, ww, sw, 0.45 * tw, -0.35 * tw)
		_mx(Q, V.j_spine, 0, ww, sw, -0.05, 0.3)
		_my(Q, V.j_hips, ww, sw, 0.64, 0.58)
		_mx(Q, V.j_sh_r if left else V.j_sh_l, 0, ww, sw, -1.2, -0.9)
	elif kind == &"kick":
		_mx(Q, V.j_th_l if left else V.j_th_r, 0, ww, sw, 0.6, -1.3)
		_mx(Q, V.j_kn_l if left else V.j_kn_r, 0, ww, sw, 1.1, 0.2)
		_mx(Q, V.j_spine, 0, ww, sw, -0.2, -0.12)
		_mx(Q, V.j_hips, 0, ww, sw, -0.1, 0.05)
		_mx(Q, V.j_sh_l, 0, ww, sw, -0.9, -0.4)
		_mx(Q, V.j_sh_r, 0, ww, sw, -0.9, -0.4)
	elif kind == &"smash":
		_mx(Q, V.j_sh_l, 0, ww, sw, -2.7, -0.5)
		_mx(Q, V.j_sh_r, 0, ww, sw, -2.7, -0.5)
		_mx(Q, V.j_el_l, 0, ww, sw, -0.5, -0.1)
		_mx(Q, V.j_el_r, 0, ww, sw, -0.5, -0.1)
		_mx(Q, V.j_spine, 0, ww, sw, -0.35, 0.75)
		_my(Q, V.j_hips, ww, sw, 0.64, 0.5)
		_mx(Q, V.j_head, 0, ww, sw, -0.2, 0.3)
	else:      # stomp (finisher): knee high, then down through the head
		_mx(Q, V.j_th_r, 0, ww, sw, -1.6, -0.55)
		_mx(Q, V.j_kn_r, 0, ww, sw, 1.5, 0.15)
		_mx(Q, V.j_spine, 0, ww, sw, -0.15, 0.4)
		_my(Q, V.j_hips, ww, sw, 0.66, 0.54)
		_mx(Q, V.j_sh_l, 2, ww, sw, 1.0, 0.5)
		_mx(Q, V.j_sh_r, 2, ww, sw, -1.0, -0.5)


## JS updateAlien after api.update: what it writes over the view's pose. ENGINE DIFFERENCE: the view composes and uploads inside its update, so this runs there as its post_hook.
func _post(al: Al) -> void:
	var V := al.api.view
	var Q := V.pose
	for s: String in ["L", "R"]:      # fists
		for f: Array in V.j_fingers[s]:
			_sx(Q, f[0], 0, -1.2)
			_sx(Q, f[1], 0, -1.4)
	if al.mode == &"seat" or (al.mode == &"climb" and t - float(al.climb.t0) > 1.1):      # hands on the wheel
		_sx(Q, V.j_sh_l, 0, -0.85)
		_sx(Q, V.j_el_l, 0, -0.7)
		_sx(Q, V.j_sh_l, 2, 0.12)
		_sx(Q, V.j_sh_r, 0, -0.85)
		_sx(Q, V.j_el_r, 0, -0.7)
		_sx(Q, V.j_sh_r, 2, -0.12)
		_sx(Q, V.j_spine, 0, -0.08)
	if al.mode == &"hold" and t > 0.5:
		_swing(al)


func _update_alien(al: Al, dt: float, now: float) -> void:
	var api := al.api
	var R := api.R
	if al.mode == &"hold":
		al.lunge = maxf(0.0, al.lunge - dt * 7.0)
		var l := U.hyp(_p.x - al.slot.x, _p.z - al.slot.y)
		if l == 0.0:
			l = 1.0
		var yaw := R.yaw + _wrap(atan2(_p.x - al.slot.x, _p.z - al.slot.y) - R.yaw) * minf(1.0, dt * 10.0)
		api.place(al.slot.x + (_p.x - al.slot.x) / l * 0.14 * al.lunge, _p.y, al.slot.y + (_p.z - al.slot.y) / l * 0.14 * al.lunge, yaw)
	elif al.mode == &"climb":      # hop up onto the hull, step over to his seat, sit down into the cockpit (full-size, no swap)
		var c := al.climb
		var tau: float = t - float(c.t0)
		var cp := _car.position
		var seat := _seat_world(c.lz)
		var wd := -_o
		var rim := Vector2(cp.x + wd.x * 1.75, seat.y)
		var seat_y := _p.y + 0.55
		var top_y := _p.y + _hull_y(U.hyp(seat.x - cp.x, seat.y - cp.z))
		var x: float
		var y: float
		var z: float
		var face := R.yaw
		if tau < 0.5:
			var u := ease_(tau / 0.5)
			x = lerpf(c.from.x, rim.x, u)
			z = lerpf(c.from.y, rim.y, u)
			y = lerpf(_p.y, _p.y + _hull_y(1.75), u) + sin(u * PI) * 0.3
			face = atan2(rim.x - c.from.x, rim.y - c.from.y)
			if not c.hopped and tau > 0.42:
				c.hopped = true
				_s(&"hop", 0.2)
		elif tau < 1.1:
			var u := ease_((tau - 0.5) / 0.6)
			x = lerpf(rim.x, seat.x, u)
			z = lerpf(rim.y, seat.y, u)
			y = lerpf(_p.y + _hull_y(1.75), top_y, u)
			face = atan2(seat.x - rim.x, seat.y - rim.y)
		else:
			var u := ease_((tau - 1.1) / 0.45)
			x = seat.x
			z = seat.y
			y = lerpf(top_y, seat_y, u)
			face = R.yaw + _wrap(_car_yaw() - R.yaw) * minf(1.0, dt * 8.0)
			if tau > 1.55:
				al.mode = &"seat"
		api.place(x, y, z, R.yaw + _wrap(face - R.yaw) * minf(1.0, dt * 10.0))
	elif al.mode == &"seat":      # riding along: carried with the car
		var s := _seat_world(al.climb.lz)
		api.place(s.x, _p.y + 0.55, s.y, _car_yaw())
	if al.mode == &"seat":
		api.look_at_point(_car.position.x, _car.position.z + _dir_z * 30.0)
	else:
		api.look_at_point(_p.x, _p.z)
	api.update(now, dt)


## tandem seats in the cockpit: local z +0.5 (front) / -0.5 (rear), x = 0
func _car_yaw() -> float:
	return PI if _dir_z < 0.0 else 0.0


func _seat_world(lz: float) -> Vector2:
	var f := -1.0 if _dir_z < 0.0 else 1.0
	return Vector2(_car.position.x, _car.position.z + f * lz)


static func _hull_y(r: float) -> float:
	for i in range(1, HULL.size()):
		if r <= HULL[i].x:
			return lerpf(HULL[i - 1].y, HULL[i].y, (r - HULL[i - 1].x) / (HULL[i].x - HULL[i - 1].x))
	return HULL[HULL.size() - 1].y


func _attack(t_impact: float, who: int, kind: StringName, hand: String = "") -> void:
	_e(t_impact - float(OFF[kind]), func() -> void: _al[who].atk = {"t0": t, "kind": kind, "hand": hand})
	_e(t_impact, func() -> void: _impact(who, &"finisher" if kind == &"stomp" else kind))


## events scheduled while running always lie ahead of the ones already fired
func _e(at: float, fn: Callable) -> void:
	_ev.append({"t": at, "fn": fn})
	_ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)


func _walk_to(al: Al, x: float, z: float, speed: float) -> void:
	al.walk_id += 1
	var id := al.walk_id
	al.mode = &"move"
	al.api.move_to(x, z, speed, func() -> void:      # a newer walk (or a hop) cancels this one
		if al.walk_id == id and al.mode == &"move":
			al.mode = &"hold"
			al.slot = Vector2(al.api.R.x, al.api.R.z))


# ---- camera
func _shot_cam(tt: float) -> Array[Vector3]:
	if tt < 2.2:
		var u := tt / 2.2
		return [_rel(lerpf(4.2, 3.4, u), lerpf(0.5, 0.1, u), lerpf(1.75, 1.5, u)), _rel(0.0, 0.0, 1.15)]
	if tt < FALL:
		return [_rel(3.1 - 0.15 * (tt - 2.2), 0.5 * sin(tt * 0.6) - 0.2, 1.45), _rel(0.0, 0.0, 1.2)]
	if tt < GROUND0:
		var u := (tt - FALL) / (GROUND0 - FALL)
		return [_rel(2.6, -1.1, 0.95), _rel(0.0, 0.0, lerpf(0.95, 0.3, u))]
	if tt < FINISHER - 0.4:
		var u := (tt - GROUND0) / 3.0
		return [_rel(lerpf(1.9, 1.6, u), lerpf(-2.1, -1.8, u), lerpf(2.1, 1.8, u)), _rel(0.0, 0.0, 0.1)]
	if tt < CAR_START + 0.2:
		return [_rel(1.7, -0.9, 0.95), _rel(0.85, 0.0, 0.15)]
	if tt < DEPART + 0.2:
		var c := _car.position if _car != null else _p
		return [_rel(9.0, 4.4, 1.9), Vector3(c.x, _p.y + 0.8, c.z)]
	return [_rel(0.4, -2.7, 0.5), _rel(1.0, 7.0, 0.9)]


func _update_camera(dt: float) -> void:
	var sc := _shot_cam(t)
	var p := sc[0]
	var l := sc[1]
	for c: float in CUTS:
		var u := (t - c) / 0.55
		if u >= 0.0 and u < 1.0:
			var s0 := _shot_cam(c - 0.001)
			var e := ease_(u)
			p = s0[0].lerp(p, e)
			l = s0[1].lerp(l, e)
	var e0 := ease_(t / 0.9)      # ease out of the gameplay camera at the start
	var sh := _shake * 0.05
	camera.pos = _from_pos.lerp(p, e0) + Vector3(_rr(-1.0, 1.0), _rr(-1.0, 1.0), _rr(-1.0, 1.0)) * sh
	camera.look = _from_look.lerp(l, e0)
	_shake = maxf(0.0, _shake - dt * 4.5)


# ---- the car
func _update_car(dt: float) -> void:
	_car.visible = t >= CAR_START
	var z := _car_z0
	var v := 0.0
	if t >= CAR_START and t < DEPART:
		var u := clampf((t - CAR_START) / (CAR_STOP - CAR_START), 0.0, 1.0)
		z = _car_z0 + (_car_z1 - _car_z0) * (1.0 - pow(1.0 - u, 2.2))
		v = 0.0 if u >= 1.0 else 2.2 * pow(1.0 - u, 1.2) * absf(_car_z1 - _car_z0) / (CAR_STOP - CAR_START)
	elif t >= DEPART:
		var tau := t - DEPART
		var acc := 6.5
		var vmax := 20.0
		var tv := vmax / acc
		z = _car_z1 + _dir_z * (0.5 * acc * tau * tau if tau < tv else 0.5 * acc * tv * tv + vmax * (tau - tv))
		v = minf(vmax, acc * tau)
	_car.position = Vector3(_car_x, _p.y, z)
	_car.rotation = Vector3(-0.025 * clampf(v / 8.0, 0.0, 1.0) if t >= DEPART else 0.0, PI if _dir_z < 0.0 else 0.0, 0.0)      # squats a little as it pulls off
	if t < ENTER:
		_dome_k = ease_((t - (WALK + 0.6)) / 0.5) if t > WALK + 0.6 else 0.0
	elif t < DOME_SHUT:
		_dome_k = 1.0
	else:
		_dome_k = 1.0 - ease_((t - DOME_SHUT) / 0.6)
	_car.set_dome(_dome_k)
	_car.tick(dt, v, _rap.kick_env() if _rap != null else 0.0)
	if t >= CAR_START and _rap != null:
		if not _rap.started:
			_rap.start()
			_rap.started = true
		var d := U.hyp(camera.pos.x - _car_x, camera.pos.z - z)
		var level := 1.25 / (1.0 + pow(d / 9.0, 2.0)) * (clampf(1.0 - (t - FADE_OUT) / (END_T - FADE_OUT), 0.0, 1.0) if t > FADE_OUT else 1.0)
		_rap.mix(dt, level, lerpf(950.0, 3000.0, _dome_k) / (1.0 + d / 60.0), clampf(v / 18.0, 0.0, 1.0) * 0.8 + 0.2)


# ---- run
## alien_a: the NPC that was talking: he is attacker #1, the cutscene spawns attacker #2
func play(alien_a: GrayAlienNpc) -> void:
	if on:
		return
	var an: Animator = Game.animator
	if an == null:
		if on_end.is_valid():
			on_end.call(false)
		return
	var fx: FX = Game.fx
	if fx.world == null:      # blood drops land on the pavement, not under it
		fx.world = Game.world
	var pl := Game.player
	_p = Vector3(pl.x, pl.y, pl.z)
	var ay := alien_a.R.yaw
	_o = Vector2(sin(ay), cos(ay))
	_sd = Vector2(-_o.y, _o.x)
	_yaw0 = pl.yaw
	_yaw_f = atan2(-_o.x, -_o.y)
	_hp0 = pl.hp if pl.hp != 0.0 else 100.0
	on = true
	t = 0.0
	_ei = 0
	_shake = 0.0
	_fl = 0.0
	_fl_side = 1.0
	_bump = 0.0
	_down = 0.0
	_buckle = 0.0
	_ev = []
	_from_pos = Game.rig.pos
	_from_look = Game.rig.look
	camera.pos = _from_pos
	camera.look = _from_look
	camera.fov = 0.0
	Game.ui.dialog.set_bars(true)      # (JS body.dlg)
	Game.hud.set_suppressed(true)
	an.pose_hook = _pose_hook
	# attacker A is the NPC who was just talking; attacker B sprints in along the pavement
	var api_b := GrayAlienNpc.new()
	add_child(api_b)
	var s_a := _slot_of(-1.0)
	var s_b := _slot_of(1.0)
	_al = [_make_alien(alien_a, 0, s_a), _make_alien(api_b, 1, s_b)]
	alien_a.set_pose(&"idle")
	api_b.set_pose(&"idle")
	var bs := Vector2(_p.x + _sd.x * 7.5 + _o.x * 0.4, _p.z + _sd.y * 7.5 + _o.y * 0.4)
	api_b.place(bs.x, _p.y, bs.y, atan2(s_b.x - bs.x, s_b.y - bs.y))
	_walk_to(_al[1], s_b.x, s_b.y, 6.4)
	_walk_to(_al[0], s_a.x, s_a.y, 2.2)
	# the car's lane and its run in from the far end of the street
	_car.visible = false
	_car_x = _p.x + _o.x * 3.85
	_car_z1 = _p.z
	_car_z0 = _p.z - _sd.y * 26.0
	_dir_z = signf(_sd.y)      # it drives along the street the way "r" points
	if _dir_z == 0.0:
		_dir_z = 1.0
	_rap = RapLoop.new()
	add_child(_rap)
	# the beating
	var i := 0
	for h: float in HITS:
		_attack(h, i % 2, &"hook" if (i == 2 or i == 5 or i == 7) else &"punch", "L" if i % 2 == 1 else "R")
		i += 1
	i = 0
	for k: float in KICKS:
		_attack(k, i % 2, &"kick", "L" if i % 2 == 1 else "R")
		i += 1
	_attack(SMASHES[0], 0, &"smash")
	_attack(SMASHES[1], 1, &"smash")
	_e(FALL + 0.2, func() -> void: _s(&"gurgle", 0.2))
	_e(FALL + 0.55, func() -> void: Game.sfx.play("clerkDie"))      # he goes down
	_e(8.55, func() -> void:
		var hx := _p.x - sin(_yaw_f) * 0.85 + _sd.x * 0.5
		var hz := _p.z - cos(_yaw_f) * 0.85 + _sd.y * 0.5
		_walk_to(_al[1], hx, hz, 1.8))
	_attack(FINISHER, 1, &"stomp", "R")
	# aftermath: they cackle, stroll to the car's wall-side, and climb into the two tandem seats one after the other
	_e(FINISHER + 0.9, func() -> void: _laugh(_al[0], 4, 0.78))
	_e(FINISHER + 1.25, func() -> void: _laugh(_al[1], 5, 0.7))
	_e(WALK, func() -> void:
		var front := 0 if _dir_z * (_al[0].api.R.z - _al[1].api.R.z) > 0.0 else 1      # whoever is already further along the street takes the front seat
		var n := 0
		for al: Al in _al:
			al.lz = 0.5 if n == front else -0.5
			_walk_to(al, _car_x - _o.x * 2.45, _car_z1 + _dir_z * al.lz, 2.0)
			n += 1)
	_e(WALK + 0.6, func() -> void: _s(&"hiss", 0.3))
	_e(ENTER, func() -> void: _climb(_al[0]))
	_e(ENTER + 0.45, func() -> void: _climb(_al[1]))
	_e(DOME_SHUT, func() -> void: _s(&"hiss", 0.3))
	_e(DEPART, func() -> void: _s(&"tyres", 0.2))      # tyres chirp
	_e(FADE_OUT, func() -> void: Game.ui.set_fade(true))
	_e(END_T, _finish)


func _climb(al: Al) -> void:
	al.mode = &"climb"
	al.walk_id += 1
	al.climb = {"t0": t, "from": Vector2(al.api.R.x, al.api.R.z), "lz": al.lz, "hopped": false}


func _finish() -> void:
	if not on:
		return
	on = false
	if _rap != null:
		_rap.stop()
	_rap = null
	_car.queue_free()
	_car = null
	var first := _al[0].api
	first.view.post_hook = Callable()
	_al[1].api.queue_free()
	var an: Animator = Game.animator
	if an != null:
		an.pose_hook = Callable()
	var pl := Game.player
	pl.yaw = atan2(_o.x, _o.y)
	pl.hp = minf(pl.hp, 22.0)
	pl.vx = 0.0
	pl.vz = 0.0
	pl.x = _p.x
	pl.z = _p.z
	Game.rig.snap_to(pl)
	leave_cine()
	_al = []
	if on_end.is_valid():
		on_end.call(true)
	get_tree().create_timer(0.12).timeout.connect(Game.ui.set_fade.bind(false))


func skip() -> void:
	if on:
		_finish()


func update(dt: float) -> void:
	if not on:
		return
	t += dt
	var now := Game.time
	while _ei < _ev.size() and float(_ev[_ei].t) <= t:
		var e: Dictionary = _ev[_ei]
		_ei += 1
		(e.fn as Callable).call()
		if not on:
			return
	_fl = maxf(0.0, _fl - dt * 5.5)
	_bump = maxf(0.0, _bump - dt * 6.0)
	_down = ease_((t - FALL) / 0.85)
	_buckle = 0.0 if t < FALL - 0.9 else ease_((t - (FALL - 0.9)) / 0.9) * (1.0 - _down)
	var pl := Game.player
	pl.x = _p.x
	pl.z = _p.z
	pl.yaw = _yaw0 if t < 1.5 else _yaw0 + _wrap(_yaw_f - _yaw0) * ease_((t - 1.5) / 3.2)
	pl.vx = 0.0
	pl.vz = 0.0
	pl.update(dt, Game.rig.yaw, true)
	pl.x = _p.x
	pl.z = _p.z
	var an: Animator = Game.animator
	if an != null:
		an.update(dt, pl)
		_pose_player()
	for al: Al in _al:
		_update_alien(al, dt, now)
	if _car != null:
		_update_car(dt)
	Game.fx.update(dt)
	Game.enemy_views.flush()      # (the frame's own flush is skipped while a cutscene holds the game)
	_update_camera(dt)
