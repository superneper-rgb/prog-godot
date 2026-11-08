class_name SpireArenaIntro
extends RefCounted
## THE MAWMOTHER'S ENTRANCE (JS levels/spire/arena-intro.js). Plays once, the first time the player steps through the gate into her arena: WALK (he walks in towards her), SWIPE (one tendril whips across the floor and hits him side-on), THROWN (flung across the arena, the camera chasing him), RISE (hands and knees, kneeling, one foot under him, standing, looking up), SCREAM (she rears, a massive scream, a cut to her face, then the camera sweeps back to the gameplay camera and the fight begins). The game is not frozen behind it; everything is a function of the cutscene clock except the camera smoothing.
## ENGINE DIFFERENCE: the sounds are rendered once by audio/offline_synth.gd in place of live Web Audio nodes.

const WALK := 3.3
const R_SWIPE := 13.2
const FLIGHT := 1.05
const SLIDE := 0.9
const LIE := 1.3
const R1 := 1.6
const R2 := 1.4
const R3 := 1.7
const LOOK := 1.2
const HOLD := 0.35
const SWIPE_WIND := 0.5
const SWIPE_FAST := 0.28
const SWIPE_BACK := 0.8
const A_WIND := 0.8
const A_FOLLOW := 0.7
const DA := 1.2
const R_LAND := 20.5
const SLIDE_DIST := 2.6
const HIP_STAND := 0.95
const HIP_PRONE := 0.3
const ROAR_UP := 0.9
const ROAR_HOLD := 2.6
const ROAR_DOWN := 1.0
const T_FACE := 1.9
const T_BLEND := 1.9
const T_END := 4.1

var L: SpireLevel
var on := false
var play := false
var t_ := 0.0
var camera := View.Shot.new()
var _ei := 0
var _shake := 0.0
var _ap := 0.0
var _r0 := 0.0
var _yaw0 := 0.0
var _arm := 0
var _ev: Array[Array] = []
var _tl := {}
var _st := {}
var _cp := Vector3.ZERO
var _cl := Vector3.ZERO
var _cam_init := false
var _from_p: Variant = null
var _from_l := Vector3.ZERO
var _rig_snapped := false
var _pose_an: Variant = null
var _hook := Callable()
var _hint: Label = null
var _hint_layer: CanvasLayer = null
var _snd: Dictionary = {}
var _player: Player = null


func _init(level: SpireLevel) -> void:
	L = level
	_hook = _pose_hook


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


static func _win(t: float, a: float, b: float) -> float:
	return _ease((t - a) / (b - a))


static func _polar(a: float, r: float) -> Vector2:
	return Vector2(sin(a) * r, cos(a) * r)


func _layout() -> void:
	var p0 := _polar(_ap, _r0)
	var p1 := _polar(_ap, R_SWIPE)
	var tc := maxf(2.4, p0.distance_to(p1) / WALK)      # contact
	_tl = {"hit": tc, "land": tc + FLIGHT}
	_tl.stop = float(_tl.land) + SLIDE
	_tl.rise = float(_tl.stop) + LIE
	_tl.k2 = float(_tl.rise) + R1
	_tl.k3 = float(_tl.k2) + R2
	_tl.stand = float(_tl.k3) + R3
	_tl.look = float(_tl.stand) + HOLD
	_tl.roar = float(_tl.look) + LOOK
	_tl.blend = float(_tl.roar) + T_FACE
	_tl.end = float(_tl.roar) + T_END
	_tl.wind = tc - (SWIPE_WIND + SWIPE_FAST * (A_WIND / (A_WIND + A_FOLLOW)))


## where the player is (centre of the hips) and how he is turned, at cutscene time t
func _pose_at(t: float) -> Dictionary:
	var o := {"x": 0.0, "z": 0.0, "hip": HIP_STAND, "yaw": _wrap(_ap + PI), "pitch": 0.0, "roll": 0.0, "mode": "walk", "u": 0.0}
	var p0 := _polar(_ap, _r0)
	var p1 := _polar(_ap, R_SWIPE)
	var hit: float = _tl.hit
	if t < hit:
		var k := t / hit
		o.x = lerpf(p0.x, p1.x, k)
		o.z = lerpf(p0.y, p1.y, k)
		o.yaw = _wrap(_yaw0 + _wrap(_ap + PI - _yaw0) * _ease(t / 0.6))
		return o
	var tg := Vector2(cos(_ap), -sin(_ap))      # +tangent (the way the tendril sweeps)
	var land := _polar(_ap + DA, R_LAND)
	var head_yaw := atan2(tg.x, tg.y)
	if t < float(_tl.land):      # THROWN: a long arc, tumbling
		var u := (t - hit) / FLIGHT
		var s := u * (1.12 - 0.12 * u)
		var q := _polar(_ap + DA * s, lerpf(R_SWIPE, R_LAND, s))
		o.mode = "fly"
		o.u = u
		o.x = q.x
		o.z = q.y
		o.hip = lerpf(1.15, HIP_PRONE, u * u) + 3.3 * sin(PI * u)
		o.pitch = (1.5 - PI * 2.0) * _ease(u * 1.05)
		o.roll = 0.5 * sin(PI * u * 2.0)
		o.yaw = _wrap(_ap + PI + _wrap(head_yaw - (_ap + PI)) * 0.55 * _ease(u))
		return o
	var yaw1 := _wrap(_ap + PI + _wrap(head_yaw - (_ap + PI)) * 0.55)      # face down, head the way he flew (roughly)
	var a1 := _ap + DA
	var e := Vector2(cos(a1), -sin(a1))
	if t < float(_tl.stop):      # landed: skids a few metres on his front
		var k := (t - float(_tl.land)) / SLIDE
		var s := 1.0 - (1.0 - k) * (1.0 - k)
		o.mode = "slide"
		o.x = land.x + e.x * SLIDE_DIST * s
		o.z = land.y + e.y * SLIDE_DIST * s
		o.hip = HIP_PRONE + 0.06 * sin(minf(1.0, k * 2.4) * PI) * (1.0 - k)
		o.pitch = 1.5
		o.yaw = yaw1
		o.u = k
		return o
	var sx := land.x + e.x * SLIDE_DIST
	var sz := land.y + e.y * SLIDE_DIST
	o.x = sx
	o.z = sz
	o.yaw = yaw1
	o.pitch = 1.5
	o.hip = HIP_PRONE
	o.mode = "lie"
	if t < float(_tl.rise):
		o.u = (t - float(_tl.stop)) / LIE
		o.hip = HIP_PRONE + 0.012 * sin(t * 2.2)
		return o
	# RISE: face the arena centre again while getting up
	var face_c := _wrap(atan2(-sx, -sz))
	if t < float(_tl.k2):
		var k := _ease((t - float(_tl.rise)) / R1)
		o.mode = "push"
		o.u = k
		o.pitch = lerpf(1.5, 1.0, k)
		o.hip = lerpf(HIP_PRONE, 0.5, k)
		o.yaw = _wrap(yaw1 + _wrap(face_c - yaw1) * 0.25 * k)
		return o
	if t < float(_tl.k3):
		var k := _ease((t - float(_tl.k2)) / R2)
		o.mode = "kneel"
		o.u = k
		o.pitch = lerpf(1.0, 0.2, k)
		o.hip = lerpf(0.5, 0.62, k)
		o.yaw = _wrap(yaw1 + _wrap(face_c - yaw1) * lerpf(0.25, 0.85, k))
		return o
	if t < float(_tl.stand):
		var k := _ease((t - float(_tl.k3)) / R3)
		o.mode = "stand"
		o.u = k
		o.pitch = lerpf(0.2, 0.04, k)
		o.hip = lerpf(0.62, HIP_STAND, k)
		o.yaw = _wrap(yaw1 + _wrap(face_c - yaw1) * lerpf(0.85, 1.0, k))
		return o
	o.mode = "up"
	o.u = clampf((t - float(_tl.stand)) / (float(_tl.roar) - float(_tl.stand) + 3.0), 0.0, 1.0)
	o.pitch = 0.0
	o.hip = HIP_STAND
	o.yaw = face_c
	return o


## the Mawmother's side: tendril swipe, scream
func _boss_pose(t: float, P: Player, dt: float) -> void:
	var B := L.boss
	if B.cine == null:
		B.cine = {}
	var age: float = t - float(_tl.wind)
	(B.cine as Dictionary)["sw"] = {"arm": _arm, "age": age, "a0": _ap - A_WIND, "a1": _ap + A_FOLLOW, "r": R_SWIPE, "y": L.TOP_Y + 1.3, "ap": _ap} if (age >= 0.0 and age < SWIPE_WIND + SWIPE_FAST + SWIPE_BACK + 0.6) else null
	var ru: float = t - float(_tl.roar)
	var k := 0.0 if ru < 0.0 else (_ease(ru / ROAR_UP) if ru < ROAR_UP else (1.0 if ru < ROAR_UP + ROAR_HOLD else 1.0 - _ease((ru - ROAR_UP - ROAR_HOLD) / ROAR_DOWN)))
	B.cine_roar = k
	B.raise = k
	B.jaw = 1.0 if k > 0.05 else 0.0
	B.lift = k * 0.75
	B.yaw += _wrap(atan2(P.x, P.z) - B.yaw) * minf(1.0, dt * 3.0)


# ---------------------------------------------------------------------------------------------- camera
func _shot(t: float, st: Dictionary) -> Dictionary:
	var px: float = st.x
	var pz: float = st.z
	var pa := atan2(px, pz)
	var nx := sin(pa)
	var nz := cos(pa)
	var tx := cos(pa)
	var tz := -sin(pa)
	var fy := L.TOP_Y
	var ix := -nx      # towards the arena centre: the camera stays on this side, so she is behind the lens until he gets up
	var iz := -nz
	var hit: float = _tl.hit
	var hip: float = st.hip
	if t < hit + 0.001:      # FRONT of him, walking towards us; only the rim and the gate behind him, no Mawmother
		var k := _ease(t / hit)
		var dist := lerpf(6.4, 4.8, k)
		var h := lerpf(2.2, 1.5, k)
		var side := lerpf(-1.2, 0.6, k)
		return {"pos": Vector3(px + ix * dist + tx * side, fy + h, pz + iz * dist + tz * side), "look": Vector3(px, fy + 1.3, pz), "rate": 7.0}
	if t < float(_tl.stop):      # the throw: still from the inside, looking outwards at him, lagging
		var k := _ease((t - hit) / FLIGHT)
		return {"pos": Vector3(px + ix * 7.5 - tx * 1.5, fy + 2.2 + hip * 0.35, pz + iz * 7.5 - tz * 1.5), "look": Vector3(px, fy + hip + 0.3, pz), "rate": 3.4 + 2.0 * k}
	if t < float(_tl.rise):      # he lies there, low, from the front
		var k := _ease((t - float(_tl.stop)) / LIE)
		var d := lerpf(4.4, 4.0, k)
		return {"pos": Vector3(px + ix * d + tx * 1.2, fy + 0.55, pz + iz * d + tz * 1.2), "look": Vector3(px, fy + 0.4, pz), "rate": 2.5}
	if t < float(_tl.stand):      # as he starts to get up the camera swings round behind him: the Mawmother comes into view over his shoulder
		var rs: float = _tl.rise
		var k := _ease((t - rs) / (float(_tl.k3) - rs + 0.4))
		var phi := PI * k
		var dist := lerpf(4.0, 5.6, k)
		var lk := _ease((t - rs) / (float(_tl.stand) - rs))
		var h := lerpf(0.55, 1.5, lk)
		var dx := ix * cos(phi) + tx * sin(phi)
		var dz := iz * cos(phi) + tz * sin(phi)
		return {"pos": Vector3(px + dx * dist, fy + h, pz + dz * dist), "look": Vector3(px - nx * lerpf(0.0, 2.0, lk), fy + lerpf(0.5, 1.5, lk), pz - nz * lerpf(0.0, 2.0, lk)), "rate": 4.0}
	var roar: float = _tl.roar
	if t < roar + 0.12:      # he looks up; the lens tilts up her body to her head
		var k := clampf(_ease((t - float(_tl.look)) / LOOK), 0.0, 1.0)
		return {"pos": Vector3(px + nx * lerpf(5.6, 6.2, k), fy + lerpf(1.5, 0.9, k), pz + nz * lerpf(5.6, 6.2, k)), "look": Vector3(px - nx * lerpf(2.0, 14.0, k), fy + lerpf(1.5, 8.2, k), pz - nz * lerpf(2.0, 14.0, k)), "rate": 2.6}
	var ru := t - roar
	if ru < T_FACE:      # CUT: low in front of her face, creeping in as she screams
		var k := clampf(ru / T_FACE, 0.0, 1.0)
		var yb := L.boss.yaw
		var d := lerpf(15.5, 12.0, k)
		return {"pos": Vector3(sin(yb) * d, fy + 4.2 + k * 0.6, cos(yb) * d), "look": Vector3(0.0, fy + 10.6 + L.boss.raise * 0.8, 0.0), "rate": 40.0, "cut": ru < 0.2}
	return {}      # sweeping back to the gameplay camera


func _update_camera(dt: float, t: float) -> void:
	var tgt := _shot(t, _pose_at(t))
	var rg: CameraRig = Game.rig
	if not tgt.is_empty():
		if not _cam_init or tgt.get("cut", false):
			_cp = tgt.pos
			_cl = tgt.look
			_cam_init = true
		var f := 1.0 - exp(-float(tgt.rate) * dt)
		_cp += (tgt.pos - _cp) * f
		_cl += (tgt.look - _cl) * f
		_from_p = null
	else:      # blend into the real camera, which has been tracking him since he stood up
		if _from_p == null:
			_from_p = _cp
			_from_l = _cl
		var k := _ease((t - float(_tl.blend)) / T_BLEND)
		var q := _ease(k)
		_cp = (_from_p as Vector3).lerp(rg.pos, q) + Vector3(0.0, sin(PI * k) * 1.8, 0.0)
		_cl = _from_l.lerp(rg.look, q)
	_shake = maxf(0.0, _shake - dt * 3.0)
	var ru: float = t - float(_tl.roar)
	var scream := L.boss.cine_roar if ru > 0.0 else 0.0
	var a := 0.09 * _shake + 0.1 * scream * (1.0 if ru < T_FACE else 0.45)
	var tt := Time.get_ticks_msec() * 0.001
	var j := func(s: float) -> float: return (sin(tt * 47.3 + s) + sin(tt * 31.7 + s * 2.1)) * 0.5 * a
	camera.pos = _cp + Vector3(j.call(0.0), j.call(1.7), j.call(3.1))
	camera.look = _cl + Vector3(j.call(4.4), j.call(5.9), j.call(7.3)) * 0.6


# ---------------------------------------------------------------------------------------------- sound
func _hit_sound(dur: float, parts: Array) -> AudioStreamWAV:
	var rate := 24000
	var b := OfflineSynth.make(dur, rate)
	for p: Array in parts:
		if p[0] == &"n":
			OfflineSynth.noise(b, rate, p[1], p[2])
		else:
			OfflineSynth.tone(b, rate, p[1], p[2])
	return OfflineSynth.wav(b, rate)


func _render_sounds() -> void:
	if not _snd.is_empty():
		return
	_snd.drone = _hit_sound(5.5, [[&"t", 0.0, {"type": &"sawtooth", "f0": 34.0, "f1": 52.0, "gain": 0.22, "dur": 5.5, "attack": 1.2}], [&"n", 0.0, {"type": &"lowpass", "f0": 160.0, "f1": 90.0, "q": 1.0, "gain": 0.3, "dur": 5.0, "attack": 1.5}]])
	_snd.swipe = _hit_sound(0.6, [[&"n", 0.0, {"type": &"bandpass", "f0": 250.0, "f1": 1700.0, "q": 0.9, "gain": 0.8, "dur": 0.5, "attack": 0.28}], [&"t", 0.0, {"type": &"sawtooth", "f0": 90.0, "f1": 38.0, "gain": 0.25, "dur": 0.55, "attack": 0.25}]])
	var hit: Array = [[&"t", 0.0, {"f0": 135.0, "f1": 34.0, "gain": 1.0, "dur": 0.45}], [&"n", 0.0, {"type": &"bandpass", "f0": 1400.0, "f1": 1400.0, "q": 1.2, "gain": 0.9, "dur": 0.12}], [&"n", 0.02, {"type": &"lowpass", "f0": 700.0, "f1": 160.0, "q": 2.0, "gain": 0.7, "dur": 0.35}]]
	for i in 4:
		hit.append([&"n", 0.03 + i * 0.045, {"type": &"highpass", "f0": 3000.0 + i * 600.0, "f1": 3000.0 + i * 600.0, "q": 0.0, "gain": 0.25, "dur": 0.04}])
	_snd.hit = _hit_sound(0.5, hit)
	_snd.grunt = _hit_sound(0.32, [[&"t", 0.0, {"type": &"sawtooth", "f0": 190.0, "f1": 90.0, "gain": 0.22, "dur": 0.3, "attack": 0.03}], [&"n", 0.0, {"type": &"bandpass", "f0": 700.0, "f1": 400.0, "q": 1.3, "gain": 0.25, "dur": 0.25, "attack": 0.04}]])
	_snd.thud = _hit_sound(0.32, [[&"t", 0.0, {"f0": 95.0, "f1": 30.0, "gain": 0.9, "dur": 0.3}], [&"n", 0.0, {"type": &"lowpass", "f0": 900.0, "f1": 200.0, "q": 2.0, "gain": 0.7, "dur": 0.18}]])
	_snd.skid = _hit_sound(SLIDE, [[&"n", 0.0, {"type": &"bandpass", "f0": 1300.0, "f1": 300.0, "q": 0.6, "gain": 0.5, "dur": SLIDE, "attack": 0.05}]])
	_snd.rustle = _hit_sound(0.42, [[&"n", 0.0, {"type": &"bandpass", "f0": 1200.0, "f1": 700.0, "q": 0.8, "gain": 0.14, "dur": 0.4, "attack": 0.1}]])
	_snd.breath = _hit_sound(0.92, [[&"n", 0.0, {"type": &"bandpass", "f0": 1100.0, "f1": 700.0, "q": 0.8, "gain": 0.14, "dur": 0.9, "attack": 0.3}]])
	_snd.inhale = _hit_sound(0.82, [[&"n", 0.0, {"type": &"bandpass", "f0": 500.0, "f1": 2200.0, "q": 0.8, "gain": 0.5, "dur": 0.8, "attack": 0.7}], [&"t", 0.0, {"type": &"sawtooth", "f0": 60.0, "f1": 120.0, "gain": 0.2, "dur": 0.8, "attack": 0.7}]])
	_snd.gate = _hit_sound(0.62, [[&"t", 0.0, {"f0": 70.0, "f1": 25.0, "gain": 1.0, "dur": 0.6}], [&"n", 0.0, {"type": &"lowpass", "f0": 800.0, "f1": 150.0, "q": 2.0, "gain": 0.8, "dur": 0.4}]])
	_snd.scream = _render_scream()


## THE SCREAM: detuned saws through shifting vowel formants with a shaky vibrato, a shrieking top, noise and a sub boom
func _render_scream() -> AudioStreamWAV:
	var rate := 24000
	var D := ROAR_UP + ROAR_HOLD + ROAR_DOWN
	var voices := [[78.0, 160.0, 0.5, 0.0], [78.0, 164.0, 0.4, 14.0], [156.0, 330.0, 0.28, -9.0], [520.0, 940.0, 0.12, 0.0]]
	var n := ceili(D * rate)
	var mix := PackedFloat32Array()
	mix.resize(n)
	for v: Array in voices:
		var ph := 0.0
		var det := pow(2.0, float(v[3]) / 1200.0)
		for i in n:
			var u := float(i) / rate
			var f: float = float(v[0]) * pow(float(v[1]) / float(v[0]), u / 0.9) if u < 0.9 else float(v[1]) * pow(0.78, (u - 0.9) / (D - 0.9))
			f = f * det + sin(TAU * 6.2 * u) * 9.0
			ph = fposmod(ph + f / rate, 1.0)
			mix[i] += (2.0 * ph - 1.0) * float(v[2]) * 0.55
	var out := PackedFloat32Array()
	out.resize(n)
	for fm: Array in [[700.0, 1.0], [1150.0, 0.7], [2700.0, 0.25]]:      # the formants
		var x1 := 0.0
		var x2 := 0.0
		var y1 := 0.0
		var y2 := 0.0
		var a1 := 0.0
		var a2 := 0.0
		var b0 := 0.0
		for i in n:
			var u := float(i) / rate
			if i % 32 == 0:
				var fc: float = float(fm[0]) * (lerpf(0.6, 1.15, u) if u < 1.0 else lerpf(1.15, 0.8, (u - 1.0) / (D - 1.0)))
				var w := TAU * fc / rate
				var alpha := sin(w) / (2.0 * 4.5)
				var a0 := 1.0 + alpha
				a1 = -2.0 * cos(w) / a0
				a2 = (1.0 - alpha) / a0
				b0 = alpha / a0
			var x: float = mix[i]
			var y := b0 * x - b0 * x2 - a1 * y1 - a2 * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			out[i] += y * float(fm[1])
	for i in n:      # the waveshaper + the envelope
		var u := float(i) / rate
		var e := u / 0.5 if u < 0.5 else (1.0 if u < ROAR_UP + ROAR_HOLD - 0.3 else pow(0.0001, (u - (ROAR_UP + ROAR_HOLD - 0.3)) / (D - (ROAR_UP + ROAR_HOLD - 0.3))))
		var x := out[i]
		var sh := (exp(x * 3.2) - exp(-x * 3.2)) / (exp(x * 3.2) + exp(-x * 3.2))
		out[i] = sh * 0.9 * e * 0.45
	OfflineSynth.noise(out, rate, 0.0, {"type": &"bandpass", "f0": 1800.0, "f1": 700.0, "q": 0.9, "gain": 0.55, "dur": D, "attack": 0.4})
	OfflineSynth.tone(out, rate, 0.0, {"f0": 52.0, "f1": 24.0, "gain": 1.0, "dur": 1.6, "attack": 0.05, "type": &"sine"})
	OfflineSynth.tone(out, rate, 0.1, {"type": &"sawtooth", "f0": 44.0, "f1": 30.0, "gain": 0.22, "dur": D - 0.1, "attack": 0.5})
	return OfflineSynth.wav(out, rate)


func _play(id: String, g: float = 1.0) -> void:
	Game.sfx.clip(_snd[id], {"gain": g, "wet": 0.3})


func _e(t: float, fn: Callable) -> void:
	_ev.append([t, fn])


func _build_events() -> void:
	_ev.clear()
	var ev_boss := func(x: float, y: float, z: float) -> void: L.event({"t": &"boltHit", "x": x, "y": y, "z": z, "kind": "world", "bk": "sauce", "nx": 0.0, "ny": 1.0, "nz": 0.0})
	_e(0.2, _play.bind("drone"))
	_e(float(_tl.wind) + 0.05, _play.bind("swipe"))
	_e(_tl.hit, func() -> void:
		_play("hit")
		_play("grunt")
		_shake = 1.4
		var q := _polar(_ap, R_SWIPE)
		ev_boss.call(q.x, L.TOP_Y + 1.2, q.y)
		ev_boss.call(q.x, L.TOP_Y + 1.4, q.y))
	_e(_tl.land, func() -> void:
		_play("thud")
		_shake = 1.0
		var q := _polar(_ap + DA, R_LAND)
		L.event({"t": &"wormSlam", "x": q.x, "y": L.TOP_Y, "z": q.y, "r": 1.6}))
	_e(float(_tl.land) + 0.1, _play.bind("skid"))
	_e(float(_tl.land) + 0.35, _play.bind("thud", 0.45))
	_e(float(_tl.stop) + 0.45, _play.bind("breath"))
	_e(float(_tl.stop) + 1.1, _play.bind("grunt"))
	_e(float(_tl.rise) + 0.2, _play.bind("rustle"))
	_e(float(_tl.k2) + 0.2, _play.bind("rustle"))
	_e(float(_tl.k3) + 0.3, func() -> void:
		_play("rustle")
		_play("grunt"))
	_e(float(_tl.stand) - 0.3, _play.bind("breath"))
	_e(float(_tl.roar) - 0.55, _play.bind("inhale"))
	_e(float(_tl.roar) + 0.05, func() -> void:
		_play("scream")
		_shake = 1.2
		L.event({"t": &"meatBoom", "id": 9000, "x": 0.0, "y": L.TOP_Y + 6.0, "z": 0.0, "r": 6.0, "big": true}))
	_e(float(_tl.roar) + 0.5, func() -> void:
		L.boss.close_gate()
		_play("gate"))
	_e(_tl.end, _finish)
	_ev.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


# ---------------------------------------------------------------------------------------------- the player's body
func _set_p(a: Variant, k: StringName, x: float, y: float, z: float, m: float = 1.0) -> void:
	var i: int = Animator.KEYS.find(k)
	if i < 0 or m <= 0.0:
		return
	var q: Vector3 = a.pose[i]
	a.pose[i] = q.lerp(Vector3(x, y, z), m)


func _add_p(a: Variant, k: StringName, x: float, y: float, z: float, m: float = 1.0) -> void:
	var i: int = Animator.KEYS.find(k)
	if i < 0:
		return
	a.pose[i] = (a.pose[i] as Vector3) + Vector3(x, y, z) * m


func _pose_hook(a: Variant) -> void:
	if not on:
		return
	var st := _st
	var t := t_
	var mode: String = st.mode
	var u: float = st.u
	var x: float = st.pitch
	match mode:
		"walk":      # tense: shoulders up, head moving a little
			var m := _win(t, 0.5, 2.0) * (1.0 - _win(t, _tl.wind, _tl.hit))
			_add_p(a, &"head", 0.0, 0.25 * sin(t * 0.9), 0.0, m)
			_add_p(a, &"spine1", 0.06, 0.0, 0.0, m)
			_set_p(a, &"head", 0.1, 0.9, 0.1, _win(t, float(_tl.wind) + 0.1, _tl.hit) * 0.7)      # he hears something: head turns toward the sweep
		"fly":      # flailing: arms thrown out and whirling, legs kicking, back arched
			var m := _win(t, _tl.hit, float(_tl.hit) + 0.08)
			var w := t * 21.0
			_set_p(a, &"upper_armL", -0.7 + 0.5 * sin(w), 0.0, 1.5 + 0.3 * sin(w * 0.7), m)
			_set_p(a, &"upper_armR", -0.9 + 0.5 * sin(w + 2.0), 0.0, -1.5 - 0.3 * sin(w * 0.8), m)
			_set_p(a, &"forearmL", -0.5 - 0.3 * sin(w + 1.0), 0.0, 0.0, m)
			_set_p(a, &"forearmR", -0.6 - 0.3 * sin(w + 3.0), 0.0, 0.0, m)
			_set_p(a, &"thighL", -0.8 + 0.35 * sin(w * 0.8), 0.0, 0.25, m)
			_set_p(a, &"thighR", -0.3 + 0.35 * sin(w * 0.8 + 2.5), 0.0, -0.25, m)
			_set_p(a, &"shinL", 1.1 + 0.3 * sin(w), 0.0, 0.0, m)
			_set_p(a, &"shinR", 0.7 + 0.3 * sin(w + 1.7), 0.0, 0.0, m)
			_set_p(a, &"spine1", -0.3, 0.1 * sin(w * 0.6), 0.0, m)
			_set_p(a, &"spine2", -0.25, 0.0, 0.1, m)
			_set_p(a, &"head", -0.45, 0.35 * sin(w * 0.5), 0.15, m)
			var land := _win(t, float(_tl.land) - 0.2, _tl.land)
			_set_p(a, &"upper_armL", -0.3, 0.0, 0.7, land * 0.8)
			_set_p(a, &"upper_armR", -0.3, 0.0, -0.7, land * 0.8)
		"slide", "lie":
			var breath := sin(t * 2.4) * 0.02
			_set_p(a, &"upper_armL", -0.35, 0.0, 0.75)
			_set_p(a, &"upper_armR", -0.25, 0.0, -0.65)
			_set_p(a, &"forearmL", -0.5, 0.0, 0.0)
			_set_p(a, &"forearmR", -0.35, 0.0, 0.0)
			_set_p(a, &"thighL", 0.05, 0.0, 0.2)
			_set_p(a, &"thighR", 0.12, 0.0, -0.18)
			_set_p(a, &"shinL", 0.12, 0.0, 0.0)
			_set_p(a, &"shinR", 0.05, 0.0, 0.0)
			_set_p(a, &"spine1", -0.1 + breath, 0.0, 0.0)
			_set_p(a, &"spine2", -0.12, 0.0, 0.0)
			_set_p(a, &"head", -0.3, 0.7, 0.12)      # head turned to the side, chin up off the floor
		"push":      # pushes up on his hands, drags a knee under him
			var k := u
			var sh := sin(t * 14.0) * 0.03 * (1.0 - k)
			_set_p(a, &"upper_armL", -x - 0.1, 0.0, 0.3)
			_set_p(a, &"upper_armR", -x - 0.1, 0.0, -0.3)
			_set_p(a, &"forearmL", -0.1 + sh, 0.0, 0.0)
			_set_p(a, &"forearmR", -0.1 - sh, 0.0, 0.0)
			_set_p(a, &"thighL", -x * k * 0.95, 0.0, 0.12)
			_set_p(a, &"thighR", -x * k * 0.7, 0.0, -0.12)
			_set_p(a, &"shinL", 1.55 * k, 0.0, 0.0)
			_set_p(a, &"shinR", 1.4 * k, 0.0, 0.0)
			_set_p(a, &"spine1", -0.22, 0.0, 0.0)
			_set_p(a, &"spine2", -0.2, 0.0, 0.0)
			_set_p(a, &"head", -0.2 + 0.4 * (1.0 - k), 0.3 * (1.0 - k), 0.0)      # head hangs between his arms
		"kneel":      # on his knees, one arm still braced, the other hand coming up to his ribs
			var k := u
			var hang := 0.45 * (1.0 - k)
			_set_p(a, &"thighL", -x, 0.0, 0.1)
			_set_p(a, &"thighR", -x, 0.0, -0.1)
			_set_p(a, &"shinL", 1.55, 0.0, 0.0)
			_set_p(a, &"shinR", 1.55, 0.0, 0.0)
			_set_p(a, &"upper_armL", lerpf(-x - 0.1, -0.15, k), 0.0, 0.2)
			_set_p(a, &"forearmL", lerpf(-0.1, -0.5, k), 0.0, 0.0)
			_set_p(a, &"upper_armR", lerpf(-x - 0.1, -0.5, k), 0.0, -0.25)
			_set_p(a, &"forearmR", lerpf(-0.1, -1.6, k), 0.0, 0.0)      # hand to his side
			_set_p(a, &"spine1", 0.35 * hang + 0.1, 0.0, 0.0)
			_set_p(a, &"spine2", 0.4 * hang + 0.1, 0.0, 0.0)
			_set_p(a, &"head", 0.5 * hang + 0.05, 0.1, 0.0)
		"stand":      # right foot planted forward, hand on that knee, shoves himself upright, swaying
			var f := 1.0 - u
			var sway := sin(t * 2.3) * 0.04 * f
			_set_p(a, &"thighL", lerpf(0.0, -1.35, f), 0.0, 0.12)
			_set_p(a, &"shinL", lerpf(0.05, 1.5, f), 0.0, 0.0)
			_set_p(a, &"thighR", lerpf(-0.05, 0.0, f), 0.0, -0.1)
			_set_p(a, &"shinR", lerpf(0.05, 1.55, f), 0.0, 0.0)
			_set_p(a, &"upper_armL", lerpf(-0.1, -0.85, f), 0.0, 0.2)
			_set_p(a, &"forearmL", lerpf(-0.12, -0.2, f), 0.0, 0.0)      # hand on his knee
			_set_p(a, &"upper_armR", lerpf(-0.1, -0.25, f), 0.0, -0.4)
			_set_p(a, &"forearmR", lerpf(-0.15, -0.9, f), 0.0, 0.0)
			_set_p(a, &"spine1", 0.4 * f + sway, 0.0, 0.0)
			_set_p(a, &"spine2", 0.34 * f, 0.0, 0.05 * f)
			_set_p(a, &"head", 0.35 * f - 0.05, 0.2 * f, 0.0)
		"up":      # standing, shaking, one arm hanging; the head comes up and up
			var look := _win(t, _tl.look, float(_tl.look) + LOOK)
			var sway := sin(t * 1.9) * 0.03
			var brace := _win(t, float(_tl.roar) - 0.1, float(_tl.roar) + 0.5)
			_set_p(a, &"spine1", 0.08 - 0.12 * look + sway, 0.0, 0.0)
			_set_p(a, &"spine2", 0.04 - 0.1 * look, 0.0, 0.0)
			_set_p(a, &"neck", -0.2 * look, 0.0, 0.0)
			_set_p(a, &"head", 0.05 - 0.6 * look, 0.04 * sin(t * 0.8), 0.0)
			_set_p(a, &"upper_armL", -0.2, 0.0, 0.35)
			_set_p(a, &"forearmL", -0.3, 0.0, 0.0)
			_set_p(a, &"upper_armR", lerpf(-0.2, -1.85, brace), lerpf(0.0, 0.3, brace), lerpf(-0.3, 0.1, brace))      # an arm comes up against the noise
			_set_p(a, &"forearmR", lerpf(-0.3, -1.4, brace), 0.0, 0.0)
			_set_p(a, &"thighL", 0.12 * brace, 0.0, 0.14)
			_set_p(a, &"thighR", -0.12 * brace, 0.0, -0.14)
			_set_p(a, &"shinL", 0.05, 0.0, 0.0)
			_set_p(a, &"shinR", 0.05 + 0.2 * brace, 0.0, 0.0)
			_add_p(a, &"spine1", -0.14 * brace, 0.0, 0.0)
			_add_p(a, &"spine2", -0.1 * brace, 0.0, 0.0)


## right after animator.update(): the actor's origin IS the hips (the model hangs below it), so tumbling, lying and kneeling just move and turn that one point
func pose_player(an: Variant) -> void:
	if not on:
		return
	if _pose_an == null:
		_pose_an = an
		an.pose_hook = _hook
	if _st.is_empty() or _st.mode == "walk":
		return
	var a: Node3D = an.actor
	var k: float = (an.B.pivot * an.B.scale) / HIP_STAND
	a.rotation_order = EULER_ORDER_YXZ
	a.rotation = Vector3(_st.pitch, _st.yaw, _st.roll)
	a.position = Vector3(_st.x, L.TOP_Y + float(_st.hip) * k, _st.z)


# ---------------------------------------------------------------------------------------------- control
func start(P: Player) -> bool:
	if on or P == null:
		return false
	_ap = atan2(P.x, P.z)
	_r0 = clampf(U.hyp(P.x, P.z), 0.0, L.ARENA_R - 2.2)
	if _r0 < 20.0:
		_r0 = L.ARENA_R - 2.2
	_yaw0 = P.yaw
	var pr := _polar(_ap, _r0)
	P.x = pr.x
	P.z = pr.y
	P.y = L.TOP_Y
	_arm = 0
	var bd := 9.0
	var arms: Array[Dictionary] = L.boss.view.arms
	for i in arms.size():
		var d := absf(_wrap(_ap - A_WIND * 0.5 - float(arms[i].base)))
		if d < bd:
			bd = d
			_arm = i
	_render_sounds()
	_layout()
	_build_events()
	on = true
	t_ = 0.0
	_ei = 0
	_shake = 0.0
	_cam_init = false
	_from_p = null
	_rig_snapped = false
	_st = _pose_at(0.0)
	Game.ui.dialog.set_bars(true, true)
	Game.hud.set_suppressed(true)
	if _hint_layer == null:
		_hint_layer = CanvasLayer.new()
		_hint_layer.layer = 40
		L.add_child(_hint_layer)
		_hint = Label.new()
		_hint.text = "ENTER  SKIP"
		_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_hint.offset_left = -150.0
		_hint.offset_top = -110.0
		_hint.offset_right = -22.0
		_hint.offset_bottom = -80.0
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_hint.add_theme_font_override(&"font", load("res://assets/fonts/Rajdhani-SemiBold.ttf"))
		_hint.add_theme_font_size_override(&"font_size", 15)
		_hint.add_theme_color_override(&"font_color", Color(1.0, 0.847, 0.816, 0.7))
		_hint_layer.add_child(_hint)
	_hint_layer.visible = true
	_update_camera(0.0, 0.0)
	_cp = camera.pos
	return true


func _skip() -> void:
	var to: float = float(_tl.roar) - 0.6      # straight to just before the scream
	if t_ < to:
		t_ = to
		while _ei < _ev.size() and float(_ev[_ei][0]) < t_:
			_ei += 1
		_cam_init = false
		_from_p = null
		_snap_rig(_st)


func _snap_rig(st: Dictionary) -> void:
	var P := _player
	if P == null:
		return
	_rig_snapped = true
	P.yaw = st.yaw
	var rg: CameraRig = Game.rig
	rg.snap_to(P)
	rg.pull_w = 1.0
	rg.pull_t = 1.0


func _finish() -> void:
	if not on:
		return
	on = false
	if _pose_an != null:
		_pose_an.pose_hook = Callable()
		_pose_an = null
	Game.ui.dialog.set_bars(false)
	Game.hud.set_suppressed(false)
	if _hint_layer != null:
		_hint_layer.visible = false
	L.boss.end_cine()
	if _player != null:
		_player.vx = 0.0
		_player.vz = 0.0


func update(dt: float, P: Player) -> void:
	if not on or P == null:
		return
	_player = P
	if Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_KP_ENTER) or Inp.key_hit(KEY_SPACE):
		_skip()
	t_ += dt
	var t := t_
	while _ei < _ev.size() and float(_ev[_ei][0]) <= t:
		var fn: Callable = _ev[_ei][1]
		_ei += 1
		fn.call()
		if not on:
			return
	_st = _pose_at(t)
	var st := _st
	P.invuln = maxf(P.invuln, 1.0)
	P.dead = false
	P.grounded = true
	P.vy = 0.0
	P.x = st.x
	P.z = st.z
	P.y = L.TOP_Y
	P.yaw = st.yaw
	if st.mode == "walk":
		P.vx = sin(_ap + PI) * WALK
		P.vz = cos(_ap + PI) * WALK
	else:
		P.vx = 0.0
		P.vz = 0.0
	if not _rig_snapped and t >= float(_tl.stand) - 0.2:      # from here the real camera is placed behind him, looking at her: it is where the sweep-back ends
		_snap_rig(st)
	_boss_pose(t, P, dt)
	_update_camera(dt, t)
	L.boss.rim_mesh.visible = not (U.hyp(camera.pos.x, camera.pos.z) > L.ARENA_R - 2.5)
