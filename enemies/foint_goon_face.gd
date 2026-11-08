class_name FointGoonFace
extends RefCounted
## FOINT GOON face (JS enemies/foint-goon-face.js): the toads' eyes, lids, brows, cheeks, jaw and throat, driven by the AI state. One per goon view: the view calls think(dt) before the body pose (it reads head_at / tilt / nod / lean) and apply_face(dt) after it.
##   attention  what he looks at: you, a mate going down, the post he waves at, the gun's magwell while he reloads, patrol glances (ahead, a sweep, a mate nearby, the floor). The eyes jump there first (a saccade, both eyes together), the head follows behind; a fixation holds for seconds, with a rare tiny shift. Stagger and death leave the eyes unfocused (a slow drift, no saccades).
##   mood       a base expression per state, eased in over a few tenths of a second: calm, off duty, suspicious (search), focused (pursue), sighting (aim), firing (squint, cheeks up, jaw shut), rage (a mate died), exertion (running, juking, reloading: a pant, the throat pumping), panic and cornered (labcoat), pressing the alarm, stoic / rattled (the adjuster with / without his shield), dazed (stagger), dead (slack)
##   reactions  short overlays with an attack, a hold and a settle: startle on first sight, pain on a hit (sized by the damage), shock when a mate drops, alarm when the adjuster's shield fails, a squint on every shot
##   speech     the jaw shapes syllables only while one of his barks is playing (shouts open wider and nod the head)
##   blinks     on a timer set by the mood (a stare blinks rarely, panic often), and with most big gaze shifts; never once he is dead
##   temper     restrained per-goon variation, seeded by his id: lid heaviness, brow set, blink rate, reaction speed, glance timing, head tilt, posture lean
## Lids pivot on the eye centre (pitch closes them, roll slants them: inner corners down = anger, up = worry); brows and cheeks slide a centimetre.

const FACE_BONES: Array[StringName] = [&"jaw", &"throat", &"eye.L", &"eye.R", &"lid_up.L", &"lid_up.R", &"lid_lo.L", &"lid_lo.R", &"brow.L", &"brow.R", &"cheek.L", &"cheek.R"]
const CH: Array[StringName] = [&"lid_u", &"lid_l", &"roll", &"brow", &"asym", &"cheek", &"jaw", &"throat", &"tilt"]
const AX := Vector3(1.0, 0.0, 0.0)
const AY := Vector3(0.0, 1.0, 0.0)
const JAW_MAX := 0.3                  # radians: jaw fully open, upper lid open -> shut, lower lid rest -> raised
const LID_UP_SPAN := 0.6
const LID_LO_SPAN := 0.24
const SHOUT := {"alert": 0.62, "mate": 0.6, "exposed": 0.55, "shieldUp": 0.5, "shoot": 0.5, "pain": 0.55, "die": 0.35}
# reactions: channel offsets, attack / hold / settle (s)
const REACT := {
	"startle": {"d": {&"lid_u": -0.45, &"lid_l": -0.2, &"brow": -0.5, &"roll": -0.2, &"jaw": 0.16}, "a": 0.06, "h": 0.25, "s": 0.5},
	"pain": {"d": {&"lid_u": 1.0, &"lid_l": 0.8, &"roll": -0.5, &"brow": 0.25, &"cheek": -0.7, &"jaw": 0.5}, "a": 0.04, "h": 0.12, "s": 0.55},
	"shock": {"d": {&"lid_u": -0.4, &"lid_l": -0.15, &"brow": -0.45, &"roll": -0.3, &"jaw": 0.2}, "a": 0.08, "h": 0.3, "s": 0.55},
	"shot": {"d": {&"lid_u": 0.22, &"lid_l": 0.2, &"cheek": 0.15}, "a": 0.02, "h": 0.03, "s": 0.15},
}

var view: FointGoonView
var R: FointGoon
var seed_ := 0
# the temper
var t_heavy := 0.0
var t_brow := 0.0
var t_blink := 1.0
var t_speed := 1.0
var t_hold := 1.0
var t_tilt := 0.0
var t_lean := 0.0
var t_breath := 1.0
var t_side := 1.0
var t_nphase := 0.0
var cur: Dictionary = {}
var tgt: Dictionary = {}
var out_: Dictionary = {}
var f0_l := Vector3.ZERO
var f0_r := Vector3.ZERO
var lid_ax_l := Vector3.ZERO
var lid_ax_r := Vector3.ZERO
var eye_mid := Vector3.ZERO
var head_rest_inv := Quaternion.IDENTITY
var head_at: Variant = null           # Vector3
var head_rate := 3.0
var tilt := 0.0
var nod := 0.0
var lean := 0.0
var t := 0.0
var gaze_y := 0.0
var gaze_p := 0.0
var gaze_ty := 0.0
var gaze_tp := 0.0
var micro_y := 0.0
var micro_p := 0.0
var micro_t := 1.0
var att: Variant = null               # Vector3
var att_key := ""
var hold_t := 0.0
var focus := true
var dart := false
var eye_at: Variant = null
var eye_key := ""
var bl_u := -1.0
var bl_next := 1.0
var blink_range: Variant = null       # Vector2, or null: never again
var reacts: Array[Dictionary] = []
var p_state := &"idle"
var p_hit_t := 9.0
var p_recoil := 0.0
var p_mate_t := 0.0
var p_shield_down := 0.0
var p_drag := 0.0
var bark_a: Barks.Active = null
var bark_t0 := 0.0
var bark_kind := ""
var bark_seed := 0.0
var exhale := 0.0
var cue := 0.0                        # a cutscene's jaw
var hang := 0.0


static func has_rig(v: FointGoonView) -> bool:
	for n: StringName in FACE_BONES:
		if n != &"throat" and not v.B.i.has(n):      # the hazmat's head sits in the gasket: no throat sac
			return false
	return true


func _init(v: FointGoonView) -> void:
	view = v
	R = v.R
	seed_ = (R.id * 7919 + 1013) % 233280
	t_heavy = _rnd() * 0.15
	t_brow = -0.12 + _rnd() * 0.35
	t_blink = 0.75 + _rnd() * 0.6
	t_speed = 0.8 + _rnd() * 0.45
	t_hold = 0.7 + _rnd() * 0.7
	t_tilt = (_rnd() - 0.5) * 0.1
	t_lean = (_rnd() - 0.4) * 0.06
	t_breath = 0.85 + _rnd() * 0.35
	t_side = -1.0 if _rnd() < 0.5 else 1.0
	t_nphase = _rnd() * 50.0
	lean = t_lean
	bl_next = 1.0 + _rnd() * 3.0
	for k: StringName in CH:
		cur[k] = 0.0
		tgt[k] = 0.0
		out_[k] = 0.0
	var B := v.B
	f0_l = v.rest_dir_of(&"eye.L")
	f0_r = v.rest_dir_of(&"eye.R")
	lid_ax_l = f0_l.cross(Vector3(0.0, -1.0, 0.0)).normalized()
	lid_ax_r = f0_r.cross(Vector3(0.0, -1.0, 0.0)).normalized()
	eye_mid = (B.rest_mp[B.i[&"eye.L"]] + B.rest_mp[B.i[&"eye.R"]]) * 0.5
	head_rest_inv = B.rest_mq[B.i[&"head"]].inverse()
	p_state = R.state
	p_hit_t = R.hit_t


func _rnd() -> float:
	seed_ = (seed_ * 9301 + 49297) % 233280
	return seed_ / 233280.0


static func _sat(u: float) -> float:
	return clampf(u, 0.0, 1.0)


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


func _react(k: String, amp: float = 1.0, hold: float = 0.0) -> void:
	var i := reacts.size() - 1
	while i >= 0:
		if reacts[i].k == k:
			reacts.remove_at(i)
		i -= 1
	reacts.append({"k": k, "t": 0.0, "amp": amp, "hold": hold})


func _trigger_blink() -> void:
	if bl_u < 0.0:
		bl_u = 0.0


# ------------------------------------------------------------------------------------------------ what he looks at
func _ahead(d: float, off: float, y: float) -> Vector3:
	var a := R.yaw
	return Vector3(R.x + sin(a + off) * d, R.y + y, R.z + cos(a + off) * d)


func _glance(kind: String) -> Vector3:
	var mates: Array[Robot] = []
	if R.E != null:
		for o: Robot in R.E.robots:
			if o != R and o is FointGoon and not o.dead and U.hyp(o.x - R.x, o.z - R.z) < 9.0:
				mates.append(o)
	var roll := _rnd()
	if kind == "search":
		hold_t = (0.7 + _rnd() * 0.9) * t_hold
		return _ahead(7.0, (roll - 0.5) * 2.8, 0.9 + _rnd() * 0.5)
	if kind == "break":
		hold_t = (2.0 + _rnd() * 3.0) * t_hold
		if mates.size() > 0 and roll < 0.35:
			return Vector3(mates[0].x, mates[0].y + 1.4, mates[0].z)
		return _ahead(6.0, (_rnd() - 0.5) * 1.6, 1.0 + _rnd() * 0.6)
	hold_t = (1.4 + _rnd() * 2.6) * t_hold
	var walking: bool = float(view.q.get(&"spd", 0.0)) > 0.5
	if mates.size() > 0 and roll < 0.2:
		var o: Robot = mates[int(_rnd() * mates.size())]
		return Vector3(o.x, o.y + 1.4, o.z)
	if roll < 0.3:                         # a look at the floor
		hold_t *= 0.5
		return _ahead(2.0, (_rnd() - 0.5) * 0.6, 0.05)
	if walking and roll < 0.75:
		return _ahead(6.0, (_rnd() - 0.5) * 0.4, 1.0)
	return _ahead(7.0, (-1.0 if _rnd() < 0.5 else 1.0) * (0.45 + _rnd() * 0.6), 1.1 + _rnd() * 0.3)


## sets eye_at / eye_key, returns the head's rate
func _attention(dt: float) -> float:
	var st := R.state
	var P: Player = R.E.P if R.E != null else null
	var lab := R.role == "labcoat"
	focus = st != &"stagger"
	if R.reload_t > 0.0 and view.gun != null and R.look_at != null:      # eyes on the magwell, one look up at you halfway through
		var u := _sat(1.0 - R.reload_t / maxf(0.1, R.reload_dur))
		if u > 0.45 and u < 0.62:
			eye_key = "you"
			eye_at = R.look_at
			return 6.0
		var g := view.gun_world()
		eye_key = "gun"
		eye_at = Vector3(g.x, g.y - 0.05, g.z)
		return 5.0
	if R.pressing:
		eye_key = "panel"
		eye_at = Vector3(R.x + sin(R.yaw) * 0.7, R.y + 1.3, R.z + cos(R.yaw) * 0.7)
		return 8.0
	if lab and st != &"idle" and st != &"return" and not R.cornered and P != null:      # panic: darting between you and the way out
		hold_t -= dt
		if hold_t <= 0.0:
			hold_t = 0.25 + _rnd() * 0.35
			dart = not dart
		if dart:
			eye_key = "out"
			eye_at = Vector3(R.alarm_at.x, R.y + 1.2, R.alarm_at.y) if R.alarm_at != null else Vector3(R.x + sin(R.yaw) * 5.0, R.y + 1.1, R.z + cos(R.yaw) * 5.0)
		else:
			eye_key = "you"
			eye_at = Vector3(P.x, P.y + 1.2, P.z)
		return 9.0
	if R.signal_t > 0.4 and R.signal_at != null:
		eye_key = "post"
		eye_at = Vector3(R.signal_at.x, R.y + 0.4, R.signal_at.y)
		return 8.0
	if R.look_at != null:
		eye_key = "mate" if R.mate_t > 0.45 else "you"
		eye_at = R.look_at
		return 10.0 if R.mate_t > 0.45 else 6.0
	var kind := "break" if R.on_break else ("search" if st == &"search" else "idle")
	hold_t -= dt
	if att == null or att_key != kind or hold_t <= 0.0:
		att = _glance(kind)
		att_key = kind
	eye_key = kind
	eye_at = att
	return 4.5 * t_speed if kind == "search" else 2.6 * t_speed


# ------------------------------------------------------------------------------------------------ the mood: base channel targets for the state
func _mood(dead: bool) -> void:
	var st := R.state
	var hostile := st != &"idle" and st != &"return" and not dead
	var lab := R.role == "labcoat"
	var tank := R.role == "adjuster"
	var spd: float = view.q.get(&"spd", 0.0)
	var Fi := R.fire
	var m := tgt
	m[&"lid_u"] = 0.12 + t_heavy
	m[&"lid_l"] = 0.05
	m[&"roll"] = 0.0
	m[&"brow"] = t_brow * 0.3
	m[&"asym"] = 0.0
	m[&"cheek"] = 0.0
	m[&"jaw"] = 0.0
	m[&"throat"] = 0.0
	m[&"tilt"] = t_tilt * 0.5
	var blink: Variant = Vector2(3.0, 6.0)
	if dead:
		m.merge({&"lid_u": 0.55, &"lid_l": 0.18, &"roll": -0.15, &"brow": -0.05, &"cheek": -0.25, &"jaw": 0.38, &"throat": -1.0, &"tilt": 0.0}, true)
		blink = null
	elif R.on_break:
		var d: float = view.q.get(&"drag", 0.0)
		m.merge({&"lid_u": 0.35 + t_heavy + d * 0.2, &"lid_l": 0.12 + d * 0.1, &"brow": -0.05 + t_brow * 0.2, &"jaw": exhale * 0.1}, true)
		blink = Vector2(3.5, 7.0)
	elif st == &"search":
		m.merge({&"lid_u": 0.3 + t_heavy * 0.5, &"lid_l": 0.28, &"roll": 0.25, &"brow": 0.3 + t_brow * 0.3, &"asym": 0.55 * t_side, &"cheek": 0.05, &"tilt": t_tilt + 0.07 * t_side}, true)
		blink = Vector2(2.5, 5.0)
	elif hostile and lab:
		if R.pressing:
			m.merge({&"lid_u": -0.15, &"lid_l": -0.1, &"roll": -0.5, &"brow": -0.4, &"cheek": -0.2, &"jaw": 0.18, &"throat": 0.6}, true)
		elif R.cornered:
			m.merge({&"lid_u": -0.3, &"lid_l": -0.2, &"roll": -0.55, &"brow": -0.45, &"cheek": -0.35, &"jaw": 0.03, &"throat": 0.7}, true)
		else:
			m.merge({&"lid_u": -0.35, &"lid_l": -0.22, &"roll": -0.7, &"brow": -0.55, &"cheek": -0.3, &"jaw": 0.26, &"throat": 0.8}, true)
		blink = Vector2(1.0, 2.5)
	elif st == &"stagger":
		m.merge({&"lid_u": 0.5, &"lid_l": 0.12, &"roll": -0.25, &"brow": -0.1, &"cheek": -0.2, &"jaw": 0.3, &"throat": 0.3}, true)
		blink = Vector2(1.2, 2.5)
	elif hostile:
		m.merge({&"lid_u": 0.2 + t_heavy * 0.5, &"lid_l": 0.15, &"roll": 0.5, &"brow": 0.45 + t_brow * 0.4, &"cheek": 0.15}, true)
		blink = Vector2(3.5, 7.0)
		if tank:
			if R.shield_down_t > 0.0:
				m.merge({&"lid_u": -0.1, &"lid_l": 0.0, &"roll": -0.35, &"brow": -0.3, &"cheek": -0.15, &"jaw": 0.12, &"throat": 0.5}, true)
			else:
				m.merge({&"lid_u": 0.28, &"roll": 0.35, &"brow": 0.3, &"cheek": 0.05}, true)
		if Fi.ph == &"aim":
			m[&"lid_u"] += 0.1
			m[&"lid_l"] += 0.15
			m[&"brow"] += 0.1
			m[&"cheek"] += 0.1
			blink = Vector2(5.0, 9.0)
		if Fi.ph == &"burst" or R.recoil > 0.1:
			m.merge({&"lid_u": 0.32, &"lid_l": 0.3, &"cheek": 0.3, &"jaw": 0.0}, true)
		if R.rage_t > 0.0:
			var w := _sat(R.rage_t / 1.5)
			var rg := {&"lid_u": 0.22, &"lid_l": 0.2, &"roll": 0.8, &"brow": 0.75, &"cheek": 0.5, &"jaw": 0.04, &"throat": 0.35}
			for k: StringName in rg:
				m[k] = lerpf(m[k], rg[k], w)
		if R.reload_t > 0.0:
			m.merge({&"brow": 0.35, &"roll": 0.2, &"lid_u": 0.28}, true)
		var ex := maxf(maxf(_sat((spd - 2.6) / 2.0), 1.0 if R.juke > 0.0 else 0.0), 0.4 if R.reload_t > 0.0 else 0.0)
		if ex > 0.0:
			m[&"jaw"] += 0.12 * ex * (0.55 + 0.45 * sin(t * PI * 2.0 * 2.4))
			m[&"roll"] -= 0.25 * ex
			m[&"throat"] = maxf(m[&"throat"], 0.6 * ex)
			m[&"lid_u"] -= 0.05 * ex
			blink = Vector2(2.0, 4.0)
	blink_range = blink


# ------------------------------------------------------------------------------------------------ events that start reactions
func _events(dt: float, dead: bool) -> void:
	var st := R.state
	if st != p_state:
		if st == &"alert" and (p_state == &"idle" or p_state == &"return" or p_state == &"search"):
			_react("startle", 1.0)
			_trigger_blink()
		if st == &"dead":
			_react("pain", 1.3, 0.2)
		p_state = st
	if R.hit_t < p_hit_t - 0.01 and not dead:
		var am := R.hit_amt if R.hit_amt != 0.0 else 0.6
		_react("pain", clampf(am, 0.45, 1.3), 0.15 * am)
	p_hit_t = R.hit_t
	if R.recoil > p_recoil + 0.5:
		_react("shot", 1.0)
	p_recoil = R.recoil
	if R.mate_t > p_mate_t + 0.5:
		_react("shock", 1.0)
	p_mate_t = R.mate_t
	if R.shield_down_t > p_shield_down + 0.5:
		_react("shock", 1.1)
	p_shield_down = R.shield_down_t
	var dr: float = view.q.get(&"drag", 0.0)
	exhale = minf(1.0, exhale + dt * 6.0) if dr < p_drag - 0.002 else maxf(0.0, exhale - dt * 0.8)
	p_drag = dr


# ------------------------------------------------------------------------------------------------ speech: the jaw while a bark plays
func _speech() -> float:
	var Bk: Barks = R.E.barks if R.E != null else null
	var a: Barks.Active = null
	if Bk != null:
		for x: Barks.Active in Bk.active:
			if x.r == R and x.end > Bk.t:
				a = x
				break
	if a == null:
		bark_a = null
		return 0.0
	if bark_a != a:
		bark_a = a
		bark_t0 = Bk.t
		bark_kind = R.last_line.rstrip("0123456789")
		bark_seed = _rnd() * 100.0
	var dur := maxf(0.3, a.end - bark_t0)
	var u := _sat((Bk.t - bark_t0) / dur)
	var n := maxi(2, roundi(dur * 4.6))
	var ph := u * n
	var syl := floorf(ph)
	var w := ph - syl
	var h := fposmod(absf(sin((syl + 1.0) * 12.9898 + bark_seed) * 43758.5453), 1.0)
	var amp: float = (0.3 if h < 0.15 else 0.6 + 0.4 * h) * float(SHOUT.get(bark_kind, 0.35)) * ((1.0 - u) / 0.08 if u > 0.92 else 1.0)
	return pow(sin(PI * w), 0.8) * amp


# ------------------------------------------------------------------------------------------------ per frame
func think(dt: float, dead: bool) -> void:
	t += dt
	_events(dt, dead)
	_mood(dead)
	if dead:
		head_at = null
		att = null
		return
	var rate := _attention(dt)
	head_at = null if R.look_at != null else eye_at
	head_rate = rate
	tilt = float(cur[&"tilt"]) + sin(t * 0.31 + t_nphase) * 0.012
	nod = 0.0


func apply_face(dt: float, dead: bool, far: bool) -> void:
	view.throat_scale = 1.0
	if far:
		return
	var r := 1.0 - exp(-7.0 * t_speed * dt)
	var rl := 1.0 - exp(-14.0 * t_speed * dt)
	for k: StringName in CH:
		cur[k] = float(cur[k]) + (float(tgt[k]) - float(cur[k])) * (rl if k == &"lid_u" or k == &"lid_l" else r)
		out_[k] = cur[k]
	var i := reacts.size() - 1
	while i >= 0:
		var x: Dictionary = reacts[i]
		x.t = float(x.t) + dt
		var D: Dictionary = REACT[x.k]
		var h: float = float(D.h) + float(x.hold)
		var xt: float = x.t
		var e: float = xt / float(D.a) if xt < float(D.a) else (1.0 if xt < float(D.a) + h else 1.0 - _ease(_sat((xt - float(D.a) - h) / float(D.s))))
		var dd: Dictionary = D.d
		for k: StringName in dd:
			out_[k] = float(out_[k]) + float(dd[k]) * float(x.amp) * e
		if xt >= float(D.a) + h + float(D.s):
			reacts.remove_at(i)
		i -= 1
	var talk: float = 0.0 if dead else maxf(_speech(), cue)
	out_[&"jaw"] = float(out_[&"jaw"]) + talk + hang
	out_[&"brow"] = float(out_[&"brow"]) + talk * (0.25 if float(SHOUT.get(bark_kind, 0.0)) > 0.5 and bark_a != null else 0.0)
	out_[&"cheek"] = float(out_[&"cheek"]) + talk * 0.15
	nod = talk * 0.05
	# ---- gaze: yaw / pitch of the attention point from between the eyes, in the head's rest frame (both eyes together)
	var B := view.B
	var ihead: int = B.i[&"head"]
	var dq := view.mq(ihead) * head_rest_inv
	var di := dq.inverse()
	if not dead and eye_at != null:
		var hp := view.mp(ihead)
		var mid := dq * (eye_mid - B.rest_mp[ihead]) + hp
		var p := di * (view.to_model(eye_at) - mid)
		var y := clampf(atan2(p.x, p.z), -0.5, 0.5)
		var pt := clampf(atan2(p.y, U.hyp(p.x, p.z)), -0.38, 0.32)
		if not focus:
			y = sin(t * 0.7 + t_nphase) * 0.18
			pt = -0.1 + sin(t * 0.53) * 0.08
		var jump := U.hyp(y - gaze_ty, pt - gaze_tp)
		if not focus:
			gaze_ty = y
			gaze_tp = pt
		elif jump > 0.06:
			gaze_ty = y
			gaze_tp = pt
			if jump > 0.35 and _rnd() < 0.55:
				_trigger_blink()
			micro_y = 0.0
			micro_p = 0.0
		micro_t -= dt
		if micro_t <= 0.0:
			micro_t = 0.9 + _rnd() * 1.6
			micro_y = (_rnd() - 0.5) * 0.03
			micro_p = (_rnd() - 0.5) * 0.02
	elif dead:
		gaze_tp = lerpf(gaze_tp, -0.15, 1.0 - exp(-dt))
	var gr := 1.0 - exp(-38.0 * dt) if focus and not dead else 1.0 - exp(-3.0 * dt)
	gaze_y += (gaze_ty + micro_y - gaze_y) * gr
	gaze_p += (gaze_tp + micro_p - gaze_p) * gr
	var eq := Quaternion(AY, gaze_y) * Quaternion(AX, -gaze_p)
	view.rot(&"eye.L", eq)
	view.rot(&"eye.R", eq)
	# ---- blinks
	if bl_u >= 0.0:
		bl_u += dt / 0.2
		if bl_u >= 1.0:
			bl_u = -1.0
			if blink_range != null:
				var br: Vector2 = blink_range
				bl_next = (br.x + _rnd() * (br.y - br.x)) * t_blink * (0.12 if _rnd() < 0.15 else 1.0)
			else:
				bl_next = 99.0
	elif blink_range != null:
		bl_next -= dt
		if bl_next <= 0.0:
			bl_u = 0.0
	var bl := 0.0 if bl_u < 0.0 else (_ease(bl_u / 0.3) if bl_u < 0.3 else (1.0 if bl_u < 0.42 else 1.0 - _ease((bl_u - 0.42) / 0.58)))
	# ---- lids: closing pitch (they follow the eyes up and down), roll for the slant; the upper lid never passes the lower
	var close_u := lerpf(clampf(out_[&"lid_u"], -0.4, 1.05), 1.02, bl)
	var close_l := lerpf(clampf(out_[&"lid_l"], -0.3, 1.0), maxf(0.45, out_[&"lid_l"]), bl)
	var lo_e := -0.42 + close_l * LID_LO_SPAN + gaze_p * 0.25
	var up_e := maxf(0.32 - close_u * LID_UP_SPAN + gaze_p * 0.45, lo_e - 0.03)
	var roll := clampf(out_[&"roll"], -1.0, 1.0)
	view.rot(&"lid_up.L", Quaternion(f0_l, roll * 0.35) * Quaternion(lid_ax_l, 0.32 - up_e))
	view.rot(&"lid_lo.L", Quaternion(f0_l, roll * 0.12) * Quaternion(lid_ax_l, -0.42 - lo_e))
	view.rot(&"lid_up.R", Quaternion(f0_r, -roll * 0.35) * Quaternion(lid_ax_r, 0.32 - up_e))
	view.rot(&"lid_lo.R", Quaternion(f0_r, -roll * 0.12) * Quaternion(lid_ax_r, -0.42 - lo_e))
	# brows: down and in for a scowl, up for worry / surprise (asym: one lower than the other); cheeks lift a little for a sneer
	var c := clampf(out_[&"cheek"], -1.0, 1.0)
	for sd: float in [1.0, -1.0]:
		var b := clampf(float(out_[&"brow"]) + float(out_[&"asym"]) * 0.5 * sd + roll * 0.25, -1.0, 1.0)
		view.offset(&"brow.L" if sd > 0.0 else &"brow.R", Vector3(-sd * 0.004 * maxf(0.0, b), -0.011 * b, 0.0))
		view.offset(&"cheek.L" if sd > 0.0 else &"cheek.R", Vector3(0.0, 0.008 * c, 0.0))      # a lift, never a pull: the mouth corners stay closed
	# ---- jaw and throat (toads pump the throat to breathe: a small quick flutter, harder when worked up; it stops when he dies)
	view.rot(&"jaw", Quaternion(AX, clampf(out_[&"jaw"], 0.0, 1.0) * JAW_MAX))
	if not dead and B.i.has(&"throat"):
		var th := clampf(out_[&"throat"], 0.0, 1.0)
		var rate := (1.3 + 1.6 * th) * t_breath
		var pulse := pow(maxf(0.0, sin(t * PI * 2.0 * rate)), 2.0)
		view.throat_scale = 1.0 + (0.02 + 0.045 * th) * pulse + 0.03 * maxf(0.0, float(out_[&"throat"]) - 0.3)
