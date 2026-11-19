class_name OutcastNpc
extends Node3D
## One of UNDERFOINT's outcasts (assets/underfoint/outcast_<kind>.glb, tools/outcasts/build_outcasts.py): the people of the old city who are not the Sigil's. A harmless character a level places and
## the dialogue system talks to: add_child, place, then update(time, dt) each frame. It has what a talker's actor needs: look_at_point / look_away, set_talk, mouth_world.
## The five share joint names, so one pose serves them all; `STYLE` is how each one holds itself. No AI and nothing to hit: they are not in the enemy list.

## bend: the stoop. arm: upper arm forward, out; forearm: the elbow's bend [left, right]. tilt: the head on one side. size, and where the mouth is from the head joint.
const STYLE := {
	"stoker": {"bend": 0.1, "arm": [0.5, 0.2], "fore": [1.25, 1.25], "tilt": 0.0, "mouth": Vector3(0.0, 0.0, 0.3)},          # hands folded on his belly
	"ragwoman": {"bend": 0.3, "arm": [0.3, 0.05], "fore": [1.7, 1.5], "tilt": 0.12, "mouth": Vector3(0.0, 0.02, 0.3)},     # wringing them
	"listener": {"bend": 0.16, "arm": [0.1, 0.12], "fore": [0.25, 0.25], "tilt": 0.3, "mouth": Vector3(0.0, 0.03, 0.2)},   # head cocked, sleeves hanging
	"ticketman": {"bend": 0.32, "arm": [0.25, 0.1], "fore": [0.3, 1.35], "tilt": 0.0, "mouth": Vector3(0.0, 0.0, 0.2)},    # his right hand on the machine
	"collector": {"bend": 0.4, "arm": [0.45, 0.1], "fore": [0.3, 0.75], "tilt": 0.0, "mouth": Vector3(0.0, 0.05, 0.2)},    # bent under the pack, on his staff
}

static var _models: Dictionary = {}      # kind -> CreatureModel

var kind := "stoker"
var R: Robot
var view: CreatureView
var _talk := false
var _look := false
var _look_x := 0.0
var _look_z := 0.0
var _seed := 0.0
var _j: Dictionary = {}


static func model_of(k: String) -> CreatureModel:
	if not _models.has(k):
		_models[k] = CreatureModel.build("res://assets/underfoint/outcast_%s.glb" % k)
	return _models[k]


func _init(p_kind: String) -> void:
	kind = p_kind
	name = "Outcast (%s)" % p_kind
	R = Robot.new(Game.world, 0, 0.0, 0.0, 0.0)      # (a plain state object, as the alien NPC has: where it is, for the batch's box)
	view = CreatureView.new(R, model_of(p_kind))
	_j = view.model.names
	view.j_spine = _j["chest"]
	view.j_muzzle = _j["head"]
	_seed = fposmod(float(hash(p_kind) % 1000) * 0.618, 1.0)


func _ready() -> void:
	if Game.enemy_views != null:
		Game.enemy_views.add_batch(view.batch)
		Game.enemy_views.npc_views.append(view)


func _exit_tree() -> void:
	if Game.enemy_views != null:
		Game.enemy_views.npc_views.erase(view)
	view.dispose()


func place(x: float, y: float, z: float, yaw: float = 0.0) -> void:
	R.x = x
	R.y = y
	R.z = z
	R.yaw = yaw
	position = Vector3(x, y, z)


func set_talk(v: bool) -> void:
	_talk = v


func look_at_point(x: float, z: float) -> void:
	_look = true
	_look_x = x
	_look_z = z


func look_away() -> void:
	_look = false


func mouth_world() -> Vector3:
	return view.pose.world[_j["head"]] * (STYLE[kind]["mouth"] as Vector3)


func update(time: float, dt: float) -> void:
	dt = minf(0.05, maxf(0.0, dt))
	var st: Dictionary = STYLE[kind]
	var pose := view.pose
	var t := time + _seed * 40.0
	var breath := sin(t * 1.25)
	var talk := view._qq(&"talk", 1.0 if _talk else 0.0, 6.0, dt)
	var beat := absf(sin(t * 9.5)) * (0.55 + 0.45 * sin(t * 3.1))      # the jaw going, in bursts
	var to_p := 0.0
	if _look:
		to_p = clampf(U.wrap_angle(atan2(_look_x - R.x, _look_z - R.z) - R.yaw), -1.1, 1.1)
	var hy := view._qq(&"hy", to_p if _look else sin(t * 0.23) * 0.35, 5.0 if _look else 1.2, dt)
	var bend: float = st["bend"]
	var p := pose.model.rest[_j["pelvis"]].origin
	p.y += breath * 0.006 - 0.01
	pose.pos[_j["pelvis"]] = p
	pose.euler(_j["pelvis"], 0.03, hy * 0.12, sin(t * 0.5) * 0.02)
	pose.euler(_j["spine"], bend * 0.55 + breath * 0.012, hy * 0.15, sin(t * 0.43 + 1.0) * 0.02)
	pose.euler(_j["chest"], bend * 0.45 + breath * 0.02 + talk * 0.04 * sin(t * 2.7), hy * 0.15, 0.0)
	var tilt: float = st["tilt"]
	pose.euler(_j["neck"], -bend * 0.5 + talk * 0.05 * sin(t * 3.3), hy * 0.3, tilt * 0.5)
	pose.euler(_j["head"], -bend * 0.4 + 0.05 + talk * 0.07 * sin(t * 4.1 + 1.0) + sin(t * 0.37) * 0.03, hy * 0.3, tilt * 0.5 + sin(t * 0.31) * 0.03)
	pose.euler(_j["jaw"], 0.03 + talk * beat * 0.45, 0.0, 0.0)
	var arm: Array = st["arm"]
	var fore: Array = st["fore"]
	var k := 0
	for sd: float in [1.0, -1.0]:
		var tag := "L" if sd > 0.0 else "R"
		var wave := talk * (0.18 * sin(t * 2.3 + sd * 1.4) if k == 0 else 0.07 * sin(t * 1.9))      # the left hand does the talking
		pose.euler(_j["upper_arm" + tag], -float(arm[0]) - bend * 0.4 - wave + breath * 0.015, 0.0, sd * float(arm[1]))
		pose.euler(_j["forearm" + tag], -float(fore[k]) - wave * 1.2 + sin(t * 0.8 + sd) * 0.03, 0.0, -sd * 0.25 * minf(1.0, float(fore[k])))
		pose.euler(_j["hand" + tag], -0.15 + sin(t * 1.1 + sd * 2.0) * 0.06, 0.0, 0.0)
		pose.euler(_j["thigh" + tag], -0.12 - bend * 0.3, 0.0, sd * 0.03)
		pose.euler(_j["shin" + tag], 0.22 + bend * 0.25, 0.0, 0.0)
		pose.euler(_j["foot" + tag], -0.1, 0.0, 0.0)
		if _j.has("ear" + tag):      # the Listener's ears never stop: one swivels to you, both flick
			var flick := 0.35 if fmod(t * 1.3 + sd * 0.8 + _seed * 5.0, 2.7) < 0.09 else 0.0
			pose.euler(_j["ear" + tag], flick * 0.4 - talk * 0.1, hy * 0.5 + sin(t * 0.7 + sd) * 0.12, sd * (0.12 + flick) + sin(t * 0.9 + sd * 2.0) * 0.06)
		k += 1
	if _j.has("pack"):
		pose.euler(_j["pack"], -bend * 0.3, 0.0, sin(t * 0.5) * 0.015)
	pose.compose(Transform3D(Basis(Vector3.UP, R.yaw), Vector3(R.x, R.y, R.z)))
	view.upload()
	var d := view.batch.data
	d[view.row * view.batch.stride + 43] = -1.0      # (no health bar: nothing here can be hurt)
