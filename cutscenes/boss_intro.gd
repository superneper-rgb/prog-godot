class_name BossIntro
extends Cutscene
## The first time Prog walks up to the Boss's desk in the B-9 office (JS cutscenes/boss-intro.js). Six recorded lines, each with its own shot: from above, Prog walks up to the desk; the Boss turns from his screens and speaks. The camera swings round to Prog for his answer. A side-on two-shot across the desk, then a slow zoom into the Boss's face. A low arc around the Boss, the television wall flickering behind him. A pan off the Boss, over his shoulder, onto Prog. The Boss loses it: he slams the desk, crash zoom over Prog's shoulder; then the camera eases back into play.
## ALT ENDING (cutscene list only, never triggered by play): play(true) runs the same six beats, then Prog stands still, draws and shoots the Boss in the face; the Cherub and Shit-chan swivel round in shock and he shoots them both too, lowers the gun and walks out; fade to black, everything put back. The game is frozen behind it like a dialogue. X skips.

const DIR := "res://assets/sfx/boss-intro/"
const CLIPS := {"boss1": "boss-1.mp3", "prog1": "prog-1.mp3", "boss2": "boss-2.mp3", "boss3": "boss-3-dead.mp3", "prog2": "prog-2-dead-air.mp3", "boss4": "boss-4-angry.mp3"}
const FLOOR := -10.0      # office numbers: the Boss stands at (127, 330) behind his desk (x 124.4..125.8, z 328.45..331.55)
const BOSS_AT := Vector2(127.0, 330.0)
const SPOT := Vector2(123.75, 329.7)
const BOSS_HOME_YAW := PI / 2.0      # facing his screens
const FALL := {"boss": 0.9, "shitchan": 0.75, "cherub": 0.85}

var actors: HubOfficeActors
var on_end := Callable()      # (finished, alt)
var t := 0.0
var alt := false
var _bi := 0
var _bt := 0.0
var _lvl := 0.0
var _anger := 0.0
var _anger_t := -1.0
var _attend := 0.0
var _shake := 0.0
var _facing := false
var _skipping := false
var _slammed := false
var _beats: Array[Dictionary] = []
var _vc: VoiceClips
var _snd := {}
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _from_fov := 50.0
var _boss_face := Vector3.ZERO
var _prog_face := Vector3.ZERO
var _prev_armed := false
var _prev_idx := -1
# the walk
var _path: Array[Vector2] = []
var _face_to: Variant = null
var _w_done := false
var _w_speed := 1.3
var _w_turn := 5.0
# the alt ending
var _fall := {}
var _dead := {}
var _thud := {}
var _react_t := -1.0
var _aim := 0.0
var _aim_to := false
var _aim_pt: Variant = null
var _kick := 0.0
var _hit := 0.0
var _fade := 0.0
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null


func _ready() -> void:
	Game.cutscenes[&"boss_intro"] = self
	_vc = VoiceClips.new(DIR, CLIPS)
	add_child(_vc)
	var slam_n: Array = [["n", 0.0, 0.12, {"type": "lowpass", "f0": 1600.0, "f1": 200.0, "gain": 0.9, "wet": 0.25}], ["n", 0.02, 0.35, {"type": "bandpass", "f0": 420.0, "f1": 180.0, "q": 1.4, "gain": 0.5, "wet": 0.3}], ["t", 0.0, 0.32, 120.0, 42.0, {"type": "triangle", "gain": 1.1, "wet": 0.25}]]
	for i in 6:
		slam_n.append(["n", 0.05 + i * 0.045 + randf() * 0.02, 0.03, {"type": "highpass", "f0": 2800.0 + randf() * 2000.0, "f1": 600.0, "gain": 0.18, "wet": 0.15}])
	_snd["slam"] = CineParts.sound("bossintro_slam", slam_n)      # both palms on the desk: a wooden boom, papers and the desk lamp rattling
	_snd["whoosh"] = CineParts.sound("bossintro_whoosh", [["n", 0.0, 0.45, {"type": "bandpass", "f0": 500.0, "f1": 1500.0, "q": 0.8, "gain": 0.12, "attack": 0.18, "wet": 0.2}]])
	_snd["gasp1"] = CineParts.sound("bossintro_gasp1", [["n", 0.0, 0.38, {"type": "bandpass", "f0": 900.0, "f1": 2100.0, "q": 1.6, "gain": 0.13, "attack": 0.06, "wet": 0.2}], ["t", 0.0, 0.3, 380.0, 640.0, {"type": "triangle", "gain": 0.03, "attack": 0.08, "wet": 0.3}]])      # a sharp in-breath
	_snd["gasp2"] = CineParts.sound("bossintro_gasp2", [["n", 0.0, 0.38, {"type": "bandpass", "f0": 900.0 * 1.25, "f1": 2100.0 * 1.25, "q": 1.6, "gain": 0.13, "attack": 0.06, "wet": 0.2}], ["t", 0.0, 0.3, 380.0 * 1.25, 640.0 * 1.25, {"type": "triangle", "gain": 0.03, "attack": 0.08, "wet": 0.3}]])
	_snd["thud"] = CineParts.sound("bossintro_thud", [["t", 0.0, 0.22, 80.0, 38.0, {"type": "triangle", "gain": 0.7, "wet": 0.2}], ["n", 0.0, 0.1, {"type": "lowpass", "f0": 900.0, "f1": 150.0, "gain": 0.5, "wet": 0.2}]])
	_snd["sting"] = CineParts.sound("bossintro_sting", [["t", 0.0, 2.6, 55.0, 52.0, {"type": "sawtooth", "gain": 0.07, "attack": 0.6, "wet": 0.5}], ["t", 0.0, 2.6, 82.4, 80.0, {"type": "triangle", "gain": 0.08, "attack": 0.8, "wet": 0.5}]])      # a low drone under the Boss turning round


func _exit_tree() -> void:
	Game.cutscenes.erase(&"boss_intro")


func _s(k: String, gain: float = 1.0) -> void:
	CineParts.play(_snd[k], gain)


## JS cs.zone(p): is p close enough to the desk to start it
func zone(p: Player) -> bool:
	return absf(p.y - FLOOR) < 1.0 and p.x > 121.9 and p.x < 128.5 and p.z > 326.6 and p.z < 333.4 and U.hyp(p.x - BOSS_AT.x, p.z - BOSS_AT.y) < 6.2


# ---- the two of them
func _update_faces() -> void:
	var b := actors.boss
	_boss_face = b.root.global_transform * Vector3(0.0, 1.66, 0.08) if b != null else Vector3(BOSS_AT.x, FLOOR + 1.66, BOSS_AT.y)
	_prog_face = face_of_player()


func _boss_fwd() -> Vector3:
	var y: float = actors.boss.root.rotation.y if actors.boss != null else -PI / 2.0
	return Vector3(sin(y), 0.0, cos(y))


func _pose_hook(a: Animator) -> void:
	var talk := _lvl if _vc.who == "prog" else 0.0
	var flinch := _anger * (1.0 if _vc.who == "boss" else 0.4)
	add_pose(a, &"head", 0.05 * sin(t * 7.3) * talk - 0.06 * _attend - 0.08 * flinch, 0.03 * sin(t * 3.1) * talk, 0.0)      # nods along with his own words; chin up at the Boss; leans back from the outburst
	add_pose(a, &"spine2", 0.02 * talk - 0.06 * flinch, 0.0, 0.0)


## the Boss: his yaw (the talker's own easing is held off while cine_hold is set) and the pose layer the office actors read from body.cine
func _drive_boss(dt: float) -> void:
	var b := actors.boss
	if b == null:
		return
	b.cine_hold = on
	var c: Dictionary = b.cine if b.cine != null else {}
	c["attend"] = _attend
	c["talk"] = _lvl if _vc.who == "boss" else 0.0
	c["anger"] = _anger
	c["t"] = t
	b.cine = c
	var want: float = atan2(SPOT.x - b.root.position.x, SPOT.y - b.root.position.z) if _facing else BOSS_HOME_YAW
	b.root.rotation.y += _wrap(want - b.root.rotation.y) * minf(1.0, dt * (2.1 if _facing else 3.0))


# ---- the alt ending: the gun, the three victims, the fade
func _victim(k: String) -> Vector3:
	if k == "cherub":
		return actors.cherub.joint_point("head", Vector3.ZERO) + Vector3(0.0, 0.05, 0.0)
	if actors.shit != null and actors.shit.b.has("Head"):
		return actors.shit.bone_world("Head") + Vector3(0.0, 0.05, 0.0)
	return actors.shit.root.position + Vector3(0.0, 1.4, 0.0)


## one round from the Jawbreaker at a world point; the victim starts to go down
func _shoot_at(target: Vector3, who: String) -> void:
	var an: Animator = Game.animator
	if an == null or an.wv == null:
		return
	an.wv.fire("deagle", 5.0)
	an.wv.flash(1.15, "deagle")
	Game.sfx.play("deagle")
	var m := an.wv.muzzle_world()
	var d := (target - m).normalized()
	Game.fx.tracer(m, target, 0.02, 0.06)
	Game.fx.sparks(target, 16, 3.6, d, 0xa30d0d)
	Game.fx.sparks(target, 6, 2.0, -d, 0xd8b0a0)
	_kick = 1.0
	_hit = 1.0
	_fall[who] = t + 0.1


func _aim_at(pt: Variant) -> void:
	_aim_pt = pt
	if pt != null:
		var p: Vector3 = pt
		_face_to = atan2(p.x - Game.player.x, p.z - Game.player.z)


func _drive_alt(dt: float) -> void:
	var b := actors.boss
	for k: String in FALL:
		var f: float = _fall[k]
		var d := 0.0 if f < 0.0 else ease_((t - f) / float(FALL[k]))
		_dead[k] = d
		if d >= 0.92 and not _thud.get(k, false):
			_thud[k] = true
			_s("thud")
	_hit = maxf(0.0, _hit - dt * 5.0)
	_kick = maxf(0.0, _kick - dt * 3.0)
	if float(_fall["boss"]) >= 0.0:
		_anger = 1.0 - float(_dead["boss"])
	if b != null and b.cine != null:
		b.cine["dead"] = _dead["boss"]
		b.cine["hit"] = _hit
	var rt := _react_t
	var e_s := ease_(rt / 0.4)
	var e_c := ease_((rt - 0.15) / 0.55)
	var pl := Game.player
	var ch := actors.cherub
	if ch != null and (rt >= 0.0 or float(_fall["cherub"]) >= 0.0):
		actors.cherub_cine = {"look": Vector2(pl.x, pl.z), "yaw": PI + _wrap(atan2(pl.x - ch.position.x, pl.z - ch.position.z) - PI) * e_c, "dead": _dead["cherub"], "flinch": _hit, "strain": 0.0, "buzz": 0.0}
	var sh := actors.shit
	if sh != null and (rt >= 0.0 or float(_fall["shitchan"]) >= 0.0):
		sh.cine = {"attend": e_s, "look": 0.0, "yaw": -2.6 + _wrap(atan2(pl.x - sh.root.position.x, pl.z - sh.root.position.z) + 2.6) * e_s, "dead": _dead["shitchan"], "flinch": _hit}
	if _react_t >= 0.0:
		_react_t += dt
	# Prog: gun up / down, aimed at whoever is next
	_aim = clampf(_aim + (1.0 if _aim_to else -1.0) * dt * 3.5, 0.0, 1.0)
	pl.armed = _aim > 0.01
	if pl.armed:
		pl.weapon_idx = Weapons.index_of("deagle")
	pl.aiming = _aim > 0.4
	if _aim_pt != null:
		var ap: Vector3 = _aim_pt
		pl.aim_pitch = atan2(ap.y - _prog_face.y, U.hyp(ap.x - pl.x, ap.z - pl.z)) * 0.9
	else:
		pl.aim_pitch = 0.0
	if _beats[_bi].id == &"out":
		_fade = maxf(0.0, 1.0 - _bt / 1.1)
	if _fade_rect != null:
		_fade_rect.color.a = _fade


## under black: everyone gets up, Prog is just inside the door, the gun is away
func _alt_reset() -> void:
	_fall = {"boss": -1.0, "shitchan": -1.0, "cherub": -1.0}
	_dead = {"boss": 0.0, "shitchan": 0.0, "cherub": 0.0}
	_react_t = -1.0
	_aim = 0.0
	_aim_to = false
	_aim_pt = null
	_anger = 0.0
	_anger_t = -1.0
	actors.cherub_cine = null
	if actors.shit != null:
		actors.shit.cine = null
	var b := actors.boss
	if b != null and b.cine != null:
		b.cine["dead"] = 0.0
		b.cine["hit"] = 0.0
	var pl := Game.player
	pl.armed = _prev_armed
	pl.weapon_idx = _prev_idx
	pl.aiming = false
	pl.aim_pitch = 0.0
	pl.x = 121.9
	pl.z = 330.2
	pl.y = FLOOR
	pl.yaw = PI / 2.0
	pl.vx = 0.0
	pl.vz = 0.0
	pl.vy = 0.0
	_path = []
	_face_to = PI / 2.0


# ---- walking (the real player physics, driven like a thumbstick)
func _step_walker(dt: float) -> void:
	var pl := Game.player
	var rs := maxf(1.0, Config.run_speed)
	if not _path.is_empty():
		var tgt: Vector2 = _path[0]
		var dx := tgt.x - pl.x
		var dz := tgt.y - pl.z
		var d := U.hyp(dx, dz)
		if d < 0.08:
			_path.pop_front()
			player_step(dt, 0.0, pl.yaw)
			if _path.is_empty():
				_w_done = true
		else:
			var v := _w_speed / rs
			player_step(dt, minf(v, maxf(v * 0.4, d * 0.6 / rs)), atan2(dx, dz))
	else:
		player_step(dt, 0.0, pl.yaw)
		if _face_to != null:
			pl.yaw += _wrap(float(_face_to) - pl.yaw) * minf(1.0, dt * _w_turn)


# ---- shots. Each beat: how long it lasts, what happens as it starts, and where the camera is (u = seconds into the beat)
## the alt ending's beats: ev = [seconds into the beat, fn] events, each fired once
func _alt_beats() -> Array[Dictionary]:
	var EAST := Vector3(126.0, FLOOR + 2.05, 328.6)
	var WEST_LOOK := Vector3(120.2, FLOOR + 1.25, 330.4)
	return [
		{"id": &"still", "len": func() -> float: return 2.1, "enter": func() -> void: _s("sting"),
			"ev": [[1.4, func() -> void:
				_aim_to = true
				_aim_at(_boss_face)]],
			"cam": func(u: float) -> void:      # push in on Prog's face; he does not move
				_update_faces()
				var k := ease_(u / 2.1)
				var f := Vector3(_boss_face.x - _prog_face.x, 0.0, _boss_face.z - _prog_face.z).normalized()
				var side := Vector3(-f.z, 0.0, f.x)
				var pos := _prog_face + f * (1.3 - 0.35 * k) + side * 0.3 + Vector3(0.0, 0.04, 0.0)
				shot(pos, _prog_face - side * 0.02, lerpf(32.0, 20.0, k))},
		{"id": &"shot1", "len": func() -> float: return 1.5, "enter": func() -> void: _s("whoosh", 0.4),
			"ev": [[0.35, func() -> void:
				_update_faces()
				_shoot_at(_boss_face, "boss")]],
			"cam": func(u: float) -> void:      # side-on across the desk
				_update_faces()
				var mid := _prog_face.lerp(_boss_face, 0.5) - Vector3(0.0, 0.1, 0.0)
				shot(Vector3(125.3, FLOOR + 2.2, 327.1) + Vector3(0.15 * u / 1.5, -0.1 * u / 1.5, 0.1 * u / 1.5), mid, 44.0)},
		{"id": &"turn", "len": func() -> float: return 1.9,
			"enter": func() -> void:
				_react_t = 0.0
				_s("gasp1"),
			"ev": [[0.2, func() -> void: _s("gasp2")], [0.85, func() -> void:
				_aim_at(_victim("shitchan"))
				_w_turn = 10.0]],
			"cam": func(u: float) -> void:      # from behind the desk, looking back down the room: Prog in front, the two behind him swivelling round
				var k := ease_(u / 1.9)
				shot(EAST + Vector3(-0.25 * k, -0.1 * k, 0.1 * k), WEST_LOOK, lerpf(50.0, 44.0, k))},
		{"id": &"shots", "len": func() -> float: return 2.5, "enter": func() -> void: _w_turn = 10.0,
			"ev": [[0.3, func() -> void: _aim_at(_victim("shitchan"))], [0.45, func() -> void: _shoot_at(_victim("shitchan"), "shitchan")],
				[0.7, func() -> void: _aim_at(_victim("cherub"))], [0.95, func() -> void: _shoot_at(_victim("cherub"), "cherub")], [1.9, func() -> void:
					_aim_to = false
					_aim_at(null)
					_w_turn = 5.0]],
			"cam": func(u: float) -> void:      # high from the south end of the room (over the desk's paper stacks): Prog, Shit-chan and the Cherub all in view
				var k := ease_(u / 2.5)
				shot(Vector3(125.4 - 0.4 * k, FLOOR + 3.0, 332.9), Vector3(121.0, FLOOR + 1.1, 329.8), lerpf(58.0, 50.0, k))},
		{"id": &"leave", "len": func() -> float: return 4.7,
			"enter": func() -> void:
				_aim_to = false
				_w_turn = 5.0
				_w_speed = 1.9
				_path = [Vector2(121.4, 330.6), Vector2(117.6, 330.0)]
				_w_done = false
				_face_to = null,
			"cam": func(u: float) -> void:      # from behind the desk, down the room after him as he walks out, pulling the lens in as he shrinks
				var k := ease_(u / 4.4)
				var pl := Game.player
				shot(Vector3(126.4, FLOOR + 2.3, 328.6), Vector3(pl.x, FLOOR + 1.1, pl.z), lerpf(52.0, 28.0, k))
				_fade = ease_((u - 3.5) / 0.9)},
	]


func _build_beats() -> void:
	var OVER_A := Vector3(120.4, FLOOR + 4.15, 327.6)      # overhead, behind and above Prog, craning in as he walks up
	var OVER_B := Vector3(121.9, FLOOR + 4.25, 328.3)
	var OVER_C := Vector3(126.6, FLOOR + 4.2, 331.9)      # overhead from behind the Boss, looking down on Prog
	var TWO := Vector3(125.3, FLOOR + 2.25, 327.08)      # side-on two-shot from the filing cabinets, high enough to clear the desk's paper stacks
	var S2 := Vector3(122.6, FLOOR + 4.1, 328.7)
	_beats = [
		{"id": &"approach", "len": func() -> float: return maxf(1.4, _bt) if _w_done else 7.0, "enter": func() -> void: _s("whoosh", 0.6),
			"cam": func(u: float) -> void:
				var k := ease_(u / 4.5)
				_update_faces()
				var pl := Game.player
				var c := Vector3(pl.x, pl.y + 0.9, pl.z).lerp(Vector3((pl.x + BOSS_AT.x) / 2.0, FLOOR + 1.1, BOSS_AT.y), k)
				shot(OVER_A.lerp(OVER_B, k), c, lerpf(52.0, 46.0, k))},
		{"id": &"boss1", "at": 0.75, "clip": "boss1", "who": "boss", "len": func() -> float: return 0.75 + _vc.dur("boss1") + 0.35,
			"enter": func() -> void:
				_facing = true
				_s("sting"),
			"cam": func(u: float) -> void:
				var k := ease_(u / 3.0)
				_update_faces()
				var c := _boss_face.lerp(Vector3(BOSS_AT.x - 0.4, FLOOR + 1.2, BOSS_AT.y), 0.35)
				shot(OVER_B.lerp(S2, k), c, lerpf(46.0, 38.0, ease_(u / (_vc.dur("boss1") + 0.75))))},
		{"id": &"prog1", "at": 0.25, "clip": "prog1", "who": "prog", "len": func() -> float: return 0.25 + _vc.dur("prog1") + 0.35, "enter": func() -> void: _s("whoosh", 0.8),
			"cam": func(u: float) -> void:      # the overhead camera swings round the room to Prog, keeping its height
				var k := ease_(u / 1.6)
				_update_faces()
				var ang := k
				var mid := Vector3((S2.x + OVER_C.x) / 2.0 + 1.0 * sin(ang * PI), FLOOR + 4.3, (S2.z + OVER_C.z) / 2.0 - 0.4 * sin(ang * PI))
				var p := S2.lerp(OVER_C, k).lerp(mid, sin(k * PI) * 0.25)
				shot(p, _boss_face.lerp(_prog_face, k), lerpf(38.0, 34.0, ease_(u / (_vc.dur("prog1") + 0.25))))},
		{"id": &"boss2", "at": 1.2, "clip": "boss2", "who": "boss", "len": func() -> float: return 1.2 + _vc.dur("boss2") + 0.4,
			"cam": func(u: float) -> void:      # both of them across the desk, then the zoom into his face
				_update_faces()
				var z := ease_((u - 1.0) / maxf(1.5, _vc.dur("boss2") * 0.85))
				var mid := _prog_face.lerp(_boss_face, 0.5) - Vector3(0.0, 0.2, 0.0)
				shot(TWO + Vector3(0.35 * z, -0.45 * z, 0.3 * z), mid.lerp(_boss_face, z), lerpf(60.0, 15.0, z))},
		{"id": &"boss3", "at": 0.35, "clip": "boss3", "who": "boss", "len": func() -> float: return 0.35 + _vc.dur("boss3") + 0.35, "enter": func() -> void: _s("whoosh", 0.5),
			"cam": func(u: float) -> void:      # a slow low arc round him, the screens behind
				_update_faces()
				var k := ease_(u / (_vc.dur("boss3") + 0.7))
				var f := _boss_fwd()
				var a := lerpf(0.85, 0.12, k)
				var r := lerpf(1.55, 1.3, k)
				var dx := f.x * cos(a) + f.z * sin(a)
				var dz := -f.x * sin(a) + f.z * cos(a)
				shot(Vector3(_boss_face.x + dx * r, _boss_face.y - lerpf(0.22, 0.08, k), _boss_face.z + dz * r), _boss_face, lerpf(36.0, 30.0, k))},
		{"id": &"prog2", "at": 0.9, "clip": "prog2", "who": "prog", "len": func() -> float: return 0.9 + _vc.dur("prog2") + 0.4, "enter": func() -> void: _s("whoosh", 0.7),
			"cam": func(u: float) -> void:      # pan off him onto Prog, over the Boss's shoulder
				_update_faces()
				var k := ease_(u / 1.5)
				var f := _boss_fwd()
				var side := Vector3(f.z, 0.0, -f.x)
				var a0 := 0.12
				var dx := f.x * cos(a0) + f.z * sin(a0)
				var dz := -f.x * sin(a0) + f.z * cos(a0)
				var start := Vector3(_boss_face.x + dx * 1.3, _boss_face.y - 0.08, _boss_face.z + dz * 1.3)
				var end_ := Vector3(_boss_face.x + f.x * 0.55 - side.x * 0.48, _boss_face.y + 0.04, _boss_face.z + f.z * 0.55 - side.z * 0.48)
				var look := _boss_face.lerp(_prog_face, k)
				look.y = lerpf(_boss_face.y, _prog_face.y - 0.05, k)
				shot(start.lerp(end_, k), look, lerpf(30.0, 27.0, k) - 5.0 * ease_((u - 1.5) / (_vc.dur("prog2") + 0.9)))},
		{"id": &"boss4", "at": 0.45, "clip": "boss4", "who": "boss", "len": func() -> float: return 0.45 + _vc.dur("boss4") + 0.6,
			"enter": func() -> void:
				_anger_t = t
				_slammed = false,
			"cam": func(u: float) -> void:      # over Prog's shoulder, a crash zoom on the slam
				_update_faces()
				var pl := Game.player
				var pf := Vector3(sin(pl.yaw), 0.0, cos(pl.yaw))
				var side := Vector3(-pf.z, 0.0, pf.x)
				var pos := _prog_face - pf * 0.8 - side * 0.45 + Vector3(0.0, 0.1, 0.0)
				var z := 1.0 - pow(1.0 - clampf((u - 0.35) / 0.35, 0.0, 1.0), 3.0)
				pos.x += (sin(t * 47.0) + sin(t * 31.0)) * 0.012 * _shake
				pos.y += (sin(t * 53.0) + sin(t * 29.0)) * 0.012 * _shake
				var look := _boss_face - Vector3(0.0, 0.12 * (1.0 - z), 0.0)
				shot(pos, look, lerpf(44.0, 22.0, z) + 2.0 * sin(u * 0.6))},
	]
	if alt:
		_beats.append_array(_alt_beats())
	_beats.append({"id": &"out", "len": func() -> float: return 1.5,
		"enter": func() -> void:
			if alt:
				_alt_reset()
			leave_cine()
			_facing = false
			var pl := Game.player
			pl.yaw = atan2(BOSS_AT.x - pl.x, BOSS_AT.y - pl.z)
			Game.rig.snap_to(pl)
			_from_pos = camera.pos
			_from_look = camera.look
			_from_fov = camera.fov,
		"cam": func(u: float) -> void:      # ease back to the gameplay camera
			var k := ease_(u / 1.4)
			shot(_from_pos.lerp(Game.rig.pos, k), _from_look.lerp(Game.rig.look, k), lerpf(_from_fov, Config.fov, k))})


# ---- run
func play(p_alt: bool = false) -> void:
	if on:
		return
	var an: Animator = Game.animator
	if an == null:
		if on_end.is_valid():
			on_end.call(false, false)
		return
	on = true
	alt = p_alt
	_fall = {"boss": -1.0, "shitchan": -1.0, "cherub": -1.0}
	_dead = {"boss": 0.0, "shitchan": 0.0, "cherub": 0.0}
	_thud = {}
	_react_t = -1.0
	_aim = 0.0
	_aim_to = false
	_aim_pt = null
	_kick = 0.0
	_hit = 0.0
	_fade = 0.0
	t = 0.0
	_bi = 0
	_bt = 0.0
	_lvl = 0.0
	_anger = 0.0
	_attend = 0.0
	_shake = 0.0
	_facing = false
	_anger_t = -1.0
	_skipping = false
	_path = []
	_w_done = false
	_face_to = PI / 2.0
	_w_speed = 1.3
	_w_turn = 5.0
	var pl := Game.player
	if pl.x > SPOT.x + 0.5:      # came round the side of the desk: back out in front of it first
		_path.append(Vector2(SPOT.x + 0.1, clampf(pl.z, 327.3, 333.0)))
	_path.append(SPOT)
	_prev_armed = pl.armed
	_prev_idx = pl.weapon_idx
	pl.sprinting = false
	pl.crouching = false
	_from_pos = Game.rig.pos
	_from_look = Game.rig.look
	shot(_from_pos, _from_look, Config.fov)
	enter_cine()
	if alt:
		_fade_layer = CanvasLayer.new()
		_fade_layer.layer = 50
		add_child(_fade_layer)
		_fade_rect = ColorRect.new()
		_fade_rect.color = Color(0, 0, 0, 0)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade_layer.add_child(_fade_rect)
	an.pose_hook = _pose_hook
	_build_beats()
	(_beats[0].enter as Callable).call()


func skip() -> void:
	if not on or _skipping or _beats[_bi].id == &"out":
		return
	_skipping = true
	_vc.stop()
	_anger = 0.0
	if not _w_done:
		Game.player.x = SPOT.x
		Game.player.z = SPOT.y
		_path = []
		_w_done = true
	_bi = _beats.size() - 1
	_bt = 0.0
	(_beats[_bi].enter as Callable).call()


func _finish() -> void:
	if not on:
		return
	on = false
	_vc.stop()
	if _fade_layer != null:
		_fade_layer.queue_free()
		_fade_layer = null
		_fade_rect = null
	if alt:
		_alt_reset()
	var an: Animator = Game.animator
	if an != null:
		an.pose_hook = Callable()
	var b := actors.boss
	if b != null:
		b.cine_hold = false
		b.cine = null
	leave_cine()
	var pl := Game.player
	pl.vx = 0.0
	pl.vz = 0.0
	Game.rig.snap_to(pl)
	if on_end.is_valid():
		on_end.call(true, alt)


func update(dt: float) -> void:
	if not on:
		return
	dt = minf(dt, 0.05)
	t += dt
	_bt += dt
	var beat: Dictionary = _beats[_bi]
	if beat.has("clip") and not beat.get("fired", false) and _bt >= float(beat.get("at", 0.0)):
		beat["fired"] = true
		_vc.speak(beat.clip, beat.who, 0.07 if beat.who == "boss" else 0.05)
	if beat.has("ev"):
		for e: Array in beat.ev:
			if e.size() < 3 and _bt >= float(e[0]):
				e.append(true)
				(e[1] as Callable).call()
	if _bt >= float((beat.len as Callable).call()):
		if _bi == _beats.size() - 1:
			_finish()
			return
		_bi += 1
		_bt = 0.0
		beat = _beats[_bi]
		if beat.has("enter"):
			(beat.enter as Callable).call()
	# the Boss: attention once he has turned, anger from the slam to the end of the last line
	_attend = clampf(_attend + dt * (1.2 if _facing else -2.0), 0.0, 1.0)
	if _anger_t >= 0.0:
		var u := t - _anger_t
		if not (alt and float(_fall["boss"]) >= 0.0):
			_anger = maxf(0.0, _anger - dt * 2.0) if beat.id == &"out" else ease_(u / 0.32)
		if not _slammed and u > 0.3:
			_slammed = true
			_s("slam")
			_shake = 1.0
	_shake = maxf(0.0, _shake - dt * 1.6)
	_lvl += (_vc.level() - _lvl) * minf(1.0, dt * 18.0)
	_step_walker(dt)
	_drive_boss(dt)
	if alt:
		_drive_alt(dt)
	var pl := Game.player
	if _w_done and beat.id == &"approach":
		_face_to = atan2(BOSS_AT.x - pl.x, BOSS_AT.y - pl.z)
	var an: Animator = Game.animator
	if an != null:
		an.update(dt, pl)
	(beat.cam as Callable).call(_bt)
	if _kick > 0.0:
		camera.pos.x += (sin(t * 61.0) + sin(t * 37.0)) * 0.012 * _kick
		camera.pos.y += (sin(t * 67.0) + sin(t * 41.0)) * 0.012 * _kick
