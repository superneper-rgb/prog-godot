class_name CreatureView
extends RefCounted
## What every enemy view built on a CreatureModel has in common: its row in the batch, its pose, the JS `Q` easing, the health bar, and the same hooks as RobotView (R / T, spine_world, el_l_world, sprite_world, muzzle_world) so the game's FX can reach it.

var R: Robot
var T: Robot
var model: CreatureModel
var batch: RigidBatch
var pose: CreatureModel.Pose
var row := 0
var row_gen := 0      # the batch's clear_all count when this view took its row
var culled := false
var _row_saved := PackedFloat32Array()
var smoke_t := 0.0
var spark_t := 0.0
var vent_t := 0.0
var q: Dictionary = {}
var bar_t := 0.0
var j_spine := 0
var j_el_l := 0
var j_muzzle := 0


func _init(p_r: Robot, p_model: CreatureModel) -> void:
	R = p_r
	T = p_r
	model = p_model
	batch = model.batch
	row = batch.acquire()
	row_gen = batch.gen
	pose = CreatureModel.Pose.new(model)
	var d := batch.data
	var o := row * batch.stride
	d[o + 1] = 1.0
	d[o + 7] = 1.0
	d[o + 43] = -1.0


## (ENGINE DIFFERENCE: an NPC of the level being left is freed at the end of the frame, after the batch was cleared and the next level took rows. Its old row is not its own: giving it back would hand the next level's enemies rows that are never drawn.)
func dispose() -> void:
	if row_gen == batch.gen:
		batch.release(row)


func spine_world() -> Vector3:
	return pose.world[j_spine].origin


func el_l_world() -> Vector3:
	return pose.world[j_el_l].origin


func sprite_world(_i: int) -> Vector3:
	return pose.world[j_spine].origin


func muzzle_world(_kind: String = "") -> Vector3:
	return pose.world[j_muzzle].origin


func set_culled(on: bool) -> void:
	if on == culled or row_gen != batch.gen:
		return
	culled = on
	var o := row * batch.stride
	if on:      # (the row also holds the colours set once at the start: they come back with it)
		_row_saved = batch.data.slice(o, o + batch.stride)
		batch.clear_row(row)
	elif _row_saved.size() == batch.stride:
		for i in batch.stride:
			batch.data[o + i] = _row_saved[i]


## JS `Q(key, value, rate)`: the first call takes the value, later ones ease towards it.
func _qq(k: StringName, v: float, rate: float, dt: float) -> float:
	var c: float = q.get(k, v)
	if q.has(k):
		c += (v - c) * (1.0 - exp(-rate * dt))
	q[k] = c
	return c


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


static func _n(x: float) -> float:
	return clampf(x, 0.0, 1.0)


## JS Color.setHSL, in the linear values the batch holds
static func _hsl(h: float, s: float, l: float) -> Color:
	var c := (1.0 - absf(2.0 * l - 1.0)) * s
	var x := c * (1.0 - absf(fmod(h * 6.0, 2.0) - 1.0))
	var m := l - c / 2.0
	var r := Vector3(c, x, 0.0) if h < 1.0 / 6.0 else (Vector3(x, c, 0.0) if h < 2.0 / 6.0 else Vector3(0.0, c, x))
	return Color(r.x + m, r.y + m, r.z + m).srgb_to_linear()


static func _col(d: PackedFloat32Array, at: int, hex: int) -> void:
	var c := RigidBatch.lin(hex)
	d[at] = c.r
	d[at + 1] = c.g
	d[at + 2] = c.b


## JS barT + bar.position.y: `hold` seconds after a hard hit, as long as he is hurt. width: the JS fill's width over the stock 0.86.
func update_bar(dt: float, top_y: float, width: float, bar_scale: float = 1.0, slow_fade: bool = false) -> void:
	var d := batch.data
	var o := row * batch.stride
	if R.flash > 0.5:
		bar_t = 2.5
	else:
		bar_t = maxf(0.0, bar_t - dt * (0.7 if slow_fade and R.hp < R.max else 1.0))
	if R.state != &"dead" and bar_t > 0.0 and R.hp < R.max:
		var f := maxf(0.0, R.hp / R.max)
		var bc := _hsl(0.02 + 0.3 * f, 0.85, 0.55)
		d[o + 36] = R.x
		d[o + 37] = R.y + top_y
		d[o + 38] = R.z
		d[o + 39] = R.yaw
		d[o + 40] = bc.r
		d[o + 41] = bc.g
		d[o + 42] = bc.b
		d[o + 43] = f
		d[o + 3] = width * bar_scale
	else:
		d[o + 43] = -1.0


## All joints to the batch.
func upload() -> void:
	for j in pose.world.size():
		batch.set_slot(row, j, pose.world[j])
