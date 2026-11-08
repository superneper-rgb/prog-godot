class_name ShitchanClap
extends Cutscene
## X next to Shit-chan in the B-9 office (JS cutscenes/shitchan-clap.js) plays it, every time. Two recorded lines: the camera pans off the gameplay view onto Prog, over Shit-chan's shoulder, and he says his piece; it pans across to Shit-chan, over Prog's shoulder, for her comeback; she turns her head to him, then the camera eases back into play. The game is frozen behind it like a dialogue. X skips.

const X0 := 116.5      # the office's inside, a little in from the walls, so the camera never ends up behind one
const X1 := 129.5
const Z0 := 326.6
const Z1 := 332.9
const FLOOR := -10.0

var actors: HubOfficeActors
var on_end := Callable()
var t := 0.0
var _bi := 0
var _bt := 0.0
var _lvl := 0.0
var _attend := 0.0
var _skipping := false
var _beats: Array[Dictionary] = []
var _vc: VoiceClips
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _from_fov := 50.0
var _her_face := Vector3.ZERO
var _prog_face := Vector3.ZERO
var _d := Vector3.ZERO
var _side := Vector3.ZERO


func _ready() -> void:
	Game.cutscenes[&"shitchan_clap"] = self
	_vc = VoiceClips.new("res://assets/sfx/shitchan/", {"prog": "prog-mean-girl-1.mp3", "shit": "shitchan-clap.mp3"})
	add_child(_vc)


func _exit_tree() -> void:
	Game.cutscenes.erase(&"shitchan_clap")


func _update_faces() -> void:
	var s := actors.shit
	if s != null and s.b.has("Head"):
		_her_face = s.bone_world("Head") + Vector3(0.0, 0.07, 0.0)
	elif s != null:
		_her_face = Vector3(s.root.position.x, FLOOR + 1.6, s.root.position.z)
	_prog_face = face_of_player()
	_d = Vector3(_her_face.x - _prog_face.x, 0.0, _her_face.z - _prog_face.z).normalized()      # from Prog to her
	_side = Vector3(-_d.z, 0.0, _d.x)      # to Prog's left


func _in_room(v: Vector3) -> Vector3:
	return Vector3(clampf(v.x, X0, X1), v.y, clampf(v.z, Z0, Z1))


## over her shoulder, on Prog
func _on_prog() -> Vector3:
	return _in_room(_her_face + _d * 0.6 + _side * 0.42 + Vector3(0.0, 0.06, 0.0))


## over his shoulder, on her
func _on_her() -> Vector3:
	return _in_room(_prog_face - _d * 0.65 + _side * 0.4 + Vector3(0.0, 0.1, 0.0))


func _pose_hook(a: Animator) -> void:
	var talk := _lvl if _vc.who == "prog" else 0.0
	var hit := _lvl if _vc.who == "shit" else 0.0
	add_pose(a, &"head", 0.05 * sin(t * 7.1) * talk + 0.05 * hit, 0.04 * sin(t * 2.7) * talk, 0.0)      # nods with his own words, ducks a little under hers
	add_pose(a, &"spine2", 0.02 * talk - 0.04 * hit, 0.0, 0.0)


## her pose layer (office-actors reads actor.cine): eyes on Prog, head moving with her voice
func _drive_her() -> void:
	var s := actors.shit
	if s == null:
		return
	var look := _wrap(atan2(Game.player.x - s.root.position.x, Game.player.z - s.root.position.z) - s.root.rotation.y)
	s.cine = {"attend": _attend, "look": clampf(look, -1.1, 1.1), "talk": _lvl if _vc.who == "shit" else 0.0, "t": t} if on else null


func _build_beats() -> void:
	_beats = [
		{"id": &"prog", "at": 0.7, "clip": "prog", "len": func() -> float: return 0.7 + _vc.dur("prog") + 0.35,
			"cam": func(u: float) -> void:
				var k := ease_(u / 1.3)
				_update_faces()
				shot(_on_prog().lerp(_from_pos, 1.0 - k), _from_look.lerp(_prog_face, k), lerpf(_from_fov, 32.0, k) - 3.0 * ease_((u - 1.3) / (_vc.dur("prog") + 0.5)))},
		{"id": &"shit", "at": 0.55, "clip": "shit", "len": func() -> float: return 0.55 + _vc.dur("shit") + 0.5,
			"cam": func(u: float) -> void:      # pan across the two of them onto her
				var k := ease_(u / 1.2)
				_update_faces()
				var a := _on_prog().lerp(_on_her(), k) + _side * (sin(k * PI) * 0.35)
				shot(_in_room(a), _prog_face.lerp(_her_face, k), lerpf(29.0, 32.0, k) - 5.0 * ease_((u - 1.2) / (_vc.dur("shit") + 0.5)))},
		{"id": &"out", "len": func() -> float: return 1.4,
			"enter": func() -> void:
				leave_cine()
				Game.rig.snap_to(Game.player)
				_from_pos = camera.pos
				_from_look = camera.look
				_from_fov = camera.fov,
			"cam": func(u: float) -> void:
				var k := ease_(u / 1.3)
				shot(_from_pos.lerp(Game.rig.pos, k), _from_look.lerp(Game.rig.look, k), lerpf(_from_fov, Config.fov, k))},
	]


func play() -> void:
	if on:
		return
	var an: Animator = Game.animator
	if an == null or actors.shit == null:
		if on_end.is_valid():
			on_end.call(false)
		return
	on = true
	t = 0.0
	_bi = 0
	_bt = 0.0
	_lvl = 0.0
	_attend = 0.0
	_skipping = false
	var pl := Game.player
	pl.sprinting = false
	pl.crouching = false
	_from_pos = Game.rig.pos
	_from_look = Game.rig.look
	_from_fov = Config.fov
	shot(_from_pos, _from_look, _from_fov)
	enter_cine()
	an.pose_hook = _pose_hook
	_build_beats()


func skip() -> void:
	if not on or _skipping or _beats[_bi].id == &"out":
		return
	_skipping = true
	_vc.stop()
	_bi = _beats.size() - 1
	_bt = 0.0
	(_beats[_bi].enter as Callable).call()


func _finish() -> void:
	if not on:
		return
	on = false
	_vc.stop()
	_drive_her()
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
		_vc.speak(beat.clip, beat.clip, 0.06)
	if _bt >= float((beat.len as Callable).call()):
		if _bi == _beats.size() - 1:
			_finish()
			return
		_bi += 1
		_bt = 0.0
		beat = _beats[_bi]
		if beat.has("enter"):
			(beat.enter as Callable).call()
	_attend = clampf(_attend + dt * (-1.5 if beat.id == &"out" else 1.4), 0.0, 1.0)
	_lvl += (_vc.level() - _lvl) * minf(1.0, dt * 18.0)
	var pl := Game.player
	var s := actors.shit
	if s != null and beat.id != &"out":      # Prog squares up to her
		pl.yaw += _wrap(atan2(s.root.position.x - pl.x, s.root.position.z - pl.z) - pl.yaw) * minf(1.0, dt * 5.0)
	player_step(dt, 0.0, pl.yaw)
	_drive_her()
	var an: Animator = Game.animator
	if an != null:
		an.update(dt, pl)
	(beat.cam as Callable).call(_bt)
