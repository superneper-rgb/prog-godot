class_name GrayAlienNpc
extends Node3D
## GRAY ALIEN NPC (JS enemies/gray-alien-npc.js): the fat gray mafioso alien, or the green one in goth, grunge or punk clothes, as a harmless, directable character for cutscenes and level placement (no AI, no hit logic). It runs the very same AlienView as the enemy on a plain state object, so it always matches the enemy.
## Under a level: add_child, then each frame update(time, dt). place, set_pose (idle / alert / aim / search / dead), set_talk, look_at_point / look_away, move_to, turn_to, fire, blast, mouth_world. move_to, turn_to and blast take a Callable where the JS returns a Promise, and also emit `arrived`, `turned` and `blasted`.

signal arrived
signal turned
signal blasted

const MOUTH := Vector3(0.0, 0.1, 0.16)

static var _green_outfit_index := 0

var R: GrayAlien
var view: AlienView
var pose := &"idle"
var _look := false
var _look_x := 0.0
var _look_z := 0.0
var _move := {}
var _turn := {}
var _seq := {}
var _shown := true


static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


## opt.green: true builds the green alien; opt.outfit selects goth, grunge or punk clothing. opt.pose: the first pose.
func _init(opt: Dictionary = {}) -> void:
	name = "Green alien (NPC)" if opt.get("green", false) else "Gray alien (NPC)"
	R = GrayAlien.new(Game.world, 0, 0.0, 0.0, 0.0)
	R.state = &"idle"
	if opt.get("green", false):
		var outfit: String = opt.get("outfit", "")
		if outfit == "":
			outfit = ["goth", "grunge", "punk"][_green_outfit_index % 3]
			_green_outfit_index += 1
		view = AlienView.new(R, "green_alien_" + outfit, 0x3ff08a, true)
	else:
		view = AlienView.new(R)
	view.run_speed = 7.6      # (JS: CONFIG.alienRun, 7.6 when the caller has none)
	set_pose(opt.get("pose", &"idle"))


func _ready() -> void:
	visibility_changed.connect(func() -> void: view.set_culled(not is_visible_in_tree()))
	if Game.enemy_views != null:
		Game.enemy_views.add_batch(view.batch)
		Game.enemy_views.npc_views.append(view)


func _exit_tree() -> void:
	if Game.enemy_views != null:
		Game.enemy_views.npc_views.erase(view)
	view.dispose()


func place(x: float, y: float, z: float, yaw: float = NAN) -> void:
	R.x = x
	R.y = y
	R.z = z
	if not is_nan(yaw):
		R.yaw = yaw
	position = Vector3(x, y, z)


func set_pose(p: StringName) -> void:
	pose = p
	R.state_t = 0.0
	R.sees = false
	R.dead = false
	if p == &"aim":
		R.state = &"pursue"
		R.sees = true
	elif p == &"dead":
		R.state = &"dead"
		R.dead_t = 0.0
		R.dead = true
	else:
		R.state = p if (p == &"alert" or p == &"search") else &"idle"


## (JS R.state = 'lean' on the Club 9 leaner, or any state a caller sets by hand)
func set_state(s: StringName) -> void:
	R.state = s
	R.state_t = 0.0


func set_talk(v: bool) -> void:
	view.talk = v


func look_at_point(x: float, z: float) -> void:
	_look = true
	_look_x = x
	_look_z = z


func look_away() -> void:
	_look = false


func move_to(x: float, z: float, speed: float = 1.6, done: Callable = Callable()) -> void:
	if not _move.is_empty():
		_finish(_move, arrived)
	_move = {"x": x, "z": z, "speed": speed, "done": done}


func turn_to(yaw: float, seconds: float = 0.5, done: Callable = Callable()) -> void:
	if not _turn.is_empty():
		_finish(_turn, turned)
	_turn = {"from": R.yaw, "d": _wrap(yaw - R.yaw), "t": 0.0, "dur": maxf(0.05, seconds), "done": done}


func fire() -> void:
	R.fire_t = 0.14


func blast(done: Callable = Callable()) -> void:
	if not _seq.is_empty():
		_finish(_seq, blasted)
	_seq = {"prev": pose, "step": 0, "t": 0.0, "done": done}
	R.state = &"windup"
	R.a_u = 0.0
	R.state_t = 0.0


func _finish(job: Dictionary, sig: Signal) -> void:
	var d: Callable = job.get("done", Callable())
	if d.is_valid():
		d.call()
	sig.emit()


func mouth_world() -> Vector3:
	return view.pose.world[view.j_head] * MOUTH


func head_world() -> Transform3D:
	return view.pose.world[view.j_head]


## keep R.known / the view's look in step with the look target and the body's yaw (the view reads them)
func _aim_head() -> void:
	if not _look:
		view.has_look = false
		if pose == &"aim" or pose == &"alert" or pose == &"search":
			_known(R.x + sin(R.yaw) * 10.0, R.z + cos(R.yaw) * 10.0)
		else:
			R.known = null
		return
	view.has_look = true
	view.look_yaw = _wrap(atan2(_look_x - R.x, _look_z - R.z) - R.yaw)
	_known(_look_x, _look_z)


func _known(x: float, z: float) -> void:
	if R.known == null:
		R.known = Robot.Known.new()
	R.known.x = x
	R.known.z = z


## JS root.visible: a hidden one is not drawn, and the caller stops calling update
func set_shown(on: bool) -> void:
	_shown = on
	view.set_culled(not on)


func is_shown() -> bool:
	return _shown


func update(time: float, dt: float) -> void:
	dt = minf(maxf(dt, 0.0), 0.05)
	R.state_t += dt
	if R.dead:
		R.dead_t += dt
	if R.fire_t > 0.0:
		R.fire_t = maxf(0.0, R.fire_t - dt)
	if not _turn.is_empty():
		_turn.t += dt
		var u: float = minf(1.0, _turn.t / _turn.dur)
		var e := u * u * (3.0 - 2.0 * u)
		R.yaw = _turn.from + _turn.d * e
		if u >= 1.0:
			var j := _turn
			_turn = {}
			_finish(j, turned)
	if not _move.is_empty() and dt > 0.0:
		var dx: float = _move.x - R.x
		var dz: float = _move.z - R.z
		var d := sqrt(dx * dx + dz * dz)
		var step := minf(d, float(_move.speed) * dt)
		if d < 0.02:
			var j := _move
			_move = {}
			_finish(j, arrived)
		else:
			R.yaw += _wrap(atan2(dx, dz) - R.yaw) * minf(1.0, dt * 9.0)
			R.x += dx / d * step
			R.z += dz / d * step
	if not _seq.is_empty():      # mind blast: windup 0.8 s -> throw 0.35 s -> recover 0.5 s
		var dur: float = [0.8, 0.35, 0.5][_seq.step]
		_seq.t += dt
		R.a_u = minf(1.0, _seq.t / dur)
		if _seq.t >= dur:
			_seq.step += 1
			_seq.t = 0.0
			R.a_u = 0.0
			R.state_t = 0.0
			if _seq.step == 1:
				R.state = &"attack"
			elif _seq.step == 2:
				R.state = &"recover"
			else:
				var j := _seq
				_seq = {}
				set_pose(j.prev)
				_finish(j, blasted)
	_aim_head()
	position = Vector3(R.x, R.y, R.z)
	view.update(dt, time, null)
