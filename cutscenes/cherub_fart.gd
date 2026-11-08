class_name CherubFart
extends Cutscene
## X next to the Cherub at his desk in the B-9 office (JS cutscenes/cherub-fart.js) plays his next scene, round and round. 'files' / 'halo': the camera pans onto him, he turns to Prog and talks, then back into play; a long line cuts between his close-up, a wider shot of the two of them and Prog listening. 'fart': he stops typing, grips the desk, tips his head back and strains; the fart (a push-in, a low cut on the rattling chair, his face as it putters out); he turns to Prog and talks; pan onto Prog for his reaction, then back into play. The game is frozen behind it like a dialogue. X skips.

const X0 := 116.5      # the office inside, a little in from the walls
const X1 := 129.5
const Z0 := 326.6
const Z1 := 332.9
const FLOOR := -10.0
const SEAT := Vector2(120.1, 328.95)      # his seat (he faces -z, his desk in front of him)
const SCENES: Array[StringName] = [&"fart", &"files", &"halo"]      # his scenes in the order X plays them; after the last one it starts again
const TALKS := {&"files": "files", &"halo": "halo"}      # the talking visits: scene -> his clip
const FRONT := Vector3(121.95, FLOOR + 1.6, 327.95)      # front 3/4, from beside the end of his desk
const CLOSE := Vector3(1.55, 0.1, -0.95)      # his face from the end of the desk (he is a big lad: keep the lens back)
const CLOSE2 := Vector3(1.7, 0.16, -0.5)
const SEG := 6.5      # a long line cuts every SEG seconds
const FART_LEN := 6.4

var actors: HubOfficeActors
var on_end := Callable()
var t := 0.0
var _bi := 0
var _bt := 0.0
var _lvl := 0.0
var _strain := 0.0
var _buzz := 0.0
var _shake := 0.0
var _look := false
var _skipping := false
var _beats: Array[Dictionary] = []
var _vc: VoiceClips
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _from_fov := 50.0
var _face := Vector3.ZERO
var _prog_face := Vector3.ZERO
var _d := Vector3.ZERO
var _side := Vector3.ZERO
var _fart: FartSynth = null
var _fart_at := 0.0
var _low_x := 121.9
var _played := 0
var _next_fart: FartSynth = null
var _fart_task := -1


func _ready() -> void:
	Game.cutscenes[&"cherub_fart"] = self
	_vc = VoiceClips.new("res://assets/sfx/cherub-office/", {"cherub": "cherub-talking-1.mp3", "prog": "prog-cherub-reaction.mp3", "files": "cherub-mess-with-files.mp3", "halo": "cherub-halo.mp3"})
	add_child(_vc)
	preload_fart()


func _exit_tree() -> void:
	Game.cutscenes.erase(&"cherub_fart")
	if _fart_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_fart_task)
		_fart_task = -1


## different every time: the next one is written ahead of time, on a worker thread (JS: built live when it plays)
func preload_fart() -> void:
	if _next_fart != null or _fart_task >= 0:
		return
	var seed_ := randi()
	_fart_task = WorkerThreadPool.add_task(func() -> void:
		_next_fart = FartSynth.render(seed_, FART_LEN))


func _take_fart() -> FartSynth:
	if _fart_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_fart_task)
		_fart_task = -1
	if _next_fart == null:
		_next_fart = FartSynth.render(randi(), FART_LEN)
	var f := _next_fart
	_next_fart = null
	preload_fart()
	return f


func _update_faces() -> void:
	var c := actors.cherub
	_face = c.mouth_world() + Vector3(0.0, 0.12, 0.0) if c != null else Vector3(SEAT.x, FLOOR + 1.45, SEAT.y)
	_prog_face = face_of_player()
	_d = Vector3(_face.x - _prog_face.x, 0.0, _face.z - _prog_face.z).normalized()      # from Prog to him
	_side = Vector3(-_d.z, 0.0, _d.x)


func _in_room(v: Vector3) -> Vector3:
	return Vector3(clampf(v.x, X0, X1), v.y, clampf(v.z, Z0, Z1))


## the whole room shakes with the blast
func _shot(pos: Vector3, look: Vector3, fov: float) -> void:
	var k := _shake
	shot(pos + Vector3(k * 0.03 * (sin(t * 47.0) + sin(t * 31.0)), k * 0.03 * (sin(t * 53.0) + sin(t * 29.0)), k * 0.02 * sin(t * 41.0)), look, fov)


func _pose_hook(a: Animator) -> void:
	var talk := _lvl if _vc.who == "prog" else 0.0
	var recoil := _buzz
	add_pose(a, &"head", 0.05 * sin(t * 6.8) * talk - 0.18 * recoil, 0.05 * sin(t * 2.4) * talk + 0.12 * recoil, 0.0)      # leans away from it, nods along with his own words
	add_pose(a, &"spine2", -0.12 * recoil + 0.02 * talk, 0.0, 0.0)


func _drive_cherub() -> void:
	if actors.cherub == null:
		return
	if not on:
		actors.cherub_cine = null
		return
	var c := {"strain": _strain, "buzz": _buzz, "talk": _lvl if _vc.who == "cherub" else 0.0}
	if _look:
		c["look"] = Vector2(Game.player.x, Game.player.z)
	actors.cherub_cine = c


func _out() -> Dictionary:
	return {"id": &"out", "len": func() -> float: return 1.4,
		"enter": func() -> void:
			_look = false
			leave_cine()
			Game.rig.snap_to(Game.player)
			_from_pos = camera.pos
			_from_look = camera.look
			_from_fov = camera.fov,
		"cam": func(u: float) -> void:
			var k := ease_(u / 1.3)
			_shot(_from_pos.lerp(Game.rig.pos, k), _from_look.lerp(Game.rig.look, k), lerpf(_from_fov, Config.fov, k))}


## a talking shot for long lines: cut every SEG seconds between his close-up, a wider look at the two of them, and Prog listening over his head
func _talk_shot(u: float, len_: float) -> void:
	_update_faces()
	var long_ := len_ > SEG * 1.4
	var sg := int(floorf(u / SEG)) % 3 if long_ else 0
	var v := fmod(u, SEG) / SEG if long_ else u / len_
	var k := ease_(v)
	if sg == 0:
		_shot(_face + CLOSE.lerp(CLOSE2, k), _face, lerpf(33.0, 27.0, k))
	elif sg == 1:
		_shot(FRONT + Vector3(0.15 * k, 0.1, -0.2 + 0.1 * k), _face.lerp(_prog_face, 0.4), lerpf(46.0, 41.0, k))
	else:
		_shot(_in_room(_face + _d * 0.35 - _side * 0.45 + Vector3(0.0, 0.18, 0.0)), _prog_face.lerp(_face, 0.15), lerpf(34.0, 30.0, k))


func _build_beats(scene: StringName) -> void:
	if TALKS.has(scene):      # a talking visit: he turns from his screen to Prog and says his piece
		var clip: String = TALKS[scene]
		_beats = [
			{"id": &"turn", "len": func() -> float: return 1.1, "enter": func() -> void: _look = true,
				"cam": func(u: float) -> void:
					var k := ease_(u / 1.1)
					_update_faces()
					_shot(_from_pos.lerp(_face + CLOSE, k), _from_look.lerp(_face, k), lerpf(_from_fov, 33.0, k))},
			{"id": scene, "at": 0.15, "clip": clip, "who": "cherub", "len": func() -> float: return 0.15 + _vc.dur(clip) + 0.45,
				"cam": func(u: float) -> void: _talk_shot(u, _vc.dur(clip) + 0.6)},
			_out(),
		]
		return
	_beats = [
		{"id": &"wind", "len": func() -> float: return 1.6,
			"cam": func(u: float) -> void:
				var k := ease_(u / 1.4)
				_update_faces()
				_shot(_from_pos.lerp(FRONT, k), _from_look.lerp(_face, k), lerpf(_from_fov, 40.0, k))},
		{"id": &"fart", "len": func() -> float: return (_fart.duration if _fart != null else 8.0) + 0.5,
			"enter": func() -> void:
				_fart = _take_fart()
				Game.sfx.clip(_fart.stream, {"gain": 1.0, "wet": 0.16})
				_fart_at = t
				_low_x = 118.3 if Game.player.x > SEAT.x else 121.9,
			"cam": func(u: float) -> void:
				_update_faces()
				var D := FART_LEN
				if u < D * 0.42:
					var k := ease_(u / (D * 0.42))
					_shot(FRONT.lerp(_face + CLOSE, k * 0.6), _face, lerpf(40.0, 30.0, k))
				elif u < D:      # low on the floor, the chair rattling on its casters
					var k := ease_((u - D * 0.42) / (D * 0.58))
					_shot(Vector3(_low_x, FLOOR + 0.32 + 0.1 * k, 329.75 - 0.15 * k), Vector3(SEAT.x, FLOOR + 0.75 + 0.15 * k, SEAT.y), lerpf(48.0, 40.0, k))
				else:      # his face as it putters out
					var k := ease_((u - D) / 2.0)
					_shot(_face + CLOSE, _face, lerpf(36.0, 31.0, k))},
		{"id": &"cherub", "at": 0.6, "clip": "cherub", "who": "cherub", "len": func() -> float: return 0.6 + _vc.dur("cherub") + 0.35,
			"enter": func() -> void: _look = true,
			"cam": func(u: float) -> void:      # hold on him as his head comes round to Prog, drifting in
				_update_faces()
				var k := ease_(u / (_vc.dur("cherub") + 0.9))
				_shot(_face + CLOSE.lerp(CLOSE2, k), _face, lerpf(31.0, 28.0, k))},
		{"id": &"prog", "at": 0.55, "clip": "prog", "who": "prog", "len": func() -> float: return 0.55 + _vc.dur("prog") + 0.45,
			"cam": func(u: float) -> void:      # pan onto Prog, over the Cherub's head
				_update_faces()
				var k := ease_(u / 1.2)
				var a := _face + CLOSE2
				var b := _in_room(_face + _d * 0.35 - _side * 0.45 + Vector3(0.0, 0.18, 0.0))
				_shot(a.lerp(b, k), _face.lerp(_prog_face, k), lerpf(28.0, 32.0, k) - 4.0 * ease_((u - 1.2) / (_vc.dur("prog") + 0.5)))},
		_out(),
	]


## each X plays his next scene, round and round
func play_next() -> void:
	if on:
		return
	play(SCENES[_played % SCENES.size()])
	_played += 1


func play(scene: StringName = &"fart") -> void:
	if on:
		return
	var an: Animator = Game.animator
	if an == null or actors.cherub == null:
		if on_end.is_valid():
			on_end.call(false)
		return
	on = true
	t = 0.0
	_bi = 0
	_bt = 0.0
	_lvl = 0.0
	_strain = 0.0
	_buzz = 0.0
	_shake = 0.0
	_look = false
	_skipping = false
	_fart = null
	var pl := Game.player
	pl.sprinting = false
	pl.crouching = false
	_from_pos = Game.rig.pos
	_from_look = Game.rig.look
	_from_fov = Config.fov
	shot(_from_pos, _from_look, _from_fov)
	enter_cine()
	an.pose_hook = _pose_hook
	_build_beats(scene)
	if _beats[0].has("enter"):
		(_beats[0].enter as Callable).call()


func skip() -> void:
	if not on or _skipping or _beats[_bi].id == &"out":
		return
	_skipping = true
	_vc.stop()
	_bi = _beats.size() - 1
	_bt = 0.0
	(_beats[_bi].enter as Callable).call()      # (a fart already let go carries on: it cannot be taken back)


func _finish() -> void:
	if not on:
		return
	on = false
	_vc.stop()
	_drive_cherub()
	var an: Animator = Game.animator
	if an != null:
		an.pose_hook = Callable()
	leave_cine()
	var pl := Game.player
	pl.vx = 0.0
	pl.vz = 0.0
	Game.rig.snap_to(pl)
	if on_end.is_valid():
		on_end.call(true)


func update(dt: float) -> void:
	if not on:
		return
	dt = minf(dt, 0.05)
	t += dt
	_bt += dt
	var beat: Dictionary = _beats[_bi]
	if beat.has("clip") and not beat.get("fired", false) and _bt >= float(beat.at):
		beat["fired"] = true
		_vc.speak(beat.clip, beat.who, 0.06)
	if _bt >= float((beat.len as Callable).call()):
		if _bi == _beats.size() - 1:
			_finish()
			return
		_bi += 1
		_bt = 0.0
		beat = _beats[_bi]
		if beat.has("enter"):
			(beat.enter as Callable).call()
	# effort builds through the wind-up, holds through the blast, lets go with the putter
	var ft := t - _fart_at if _fart != null else -1.0
	var lv := _fart.level(ft) if _fart != null else 0.0
	var want := ease_(_bt / 1.2) if beat.id == &"wind" else (1.0 if beat.id == &"fart" and ft < FART_LEN else 0.0)
	_strain += (want - _strain) * minf(1.0, dt * (6.0 if want > _strain else 2.0))
	_buzz += (lv - _buzz) * minf(1.0, dt * 25.0)
	_shake = maxf(0.0, _shake - dt * 3.0) if beat.id == &"out" else _buzz * 0.9
	_lvl += (_vc.level() - _lvl) * minf(1.0, dt * 18.0)
	var pl := Game.player
	var c := actors.cherub
	if c != null and beat.id != &"out":      # Prog faces him
		pl.yaw += _wrap(atan2(c.position.x - pl.x, c.position.z - pl.z) - pl.yaw) * minf(1.0, dt * 5.0)
	player_step(dt, 0.0, pl.yaw)
	_drive_cherub()
	var an: Animator = Game.animator
	if an != null:
		an.update(dt, pl)
	(beat.cam as Callable).call(_bt)
