class_name AnimNpc
extends RefCounted
## One NPC on the animation viewer's stage (tools/anim_viewer/anim_cast.gd): what the DEV level's NPC maker builds, or one of UNDERFOINT's outcasts, with the moves it has.

var v: AnimViewer
var id := ""
var inst: DevNpcs.Inst = null
var outcast: OutcastNpc = null
var root: Node3D
var action := "idle"
var body_h := 1.8
var _clock := 0.0
var _list: Array = []

func _init(p_v: AnimViewer, p_id: String) -> void:
	v = p_v
	id = p_id
	if id.begins_with("outcast:"):
		outcast = OutcastNpc.new(id.substr(8))
		root = outcast
		v.add_child(root)
		body_h = 1.7
	else:
		var def: Dictionary = {}
		for d: Dictionary in DevNpcs.BUILT_IN:
			if d.id == id:
				def = d
		inst = DevNpcs.make(def, v)
		root = inst.root
		body_h = float(def.get("height", 1.8))
		if inst.alien != null:
			inst.alien.place(0.0, 0.0, 0.0, 0.0)
	_list = _make_list()
	set_action("idle")

func _make_list() -> Array:
	var l: Array = [["idle", "Idle"]]
	if inst != null and inst.has_move:
		l.append(["walk", "Walk"])
		l.append(["run", "Run"])
	if inst != null and inst.alien != null:
		l.append(["alert", "Pose: alert"])
		l.append(["aim", "Pose: aim"])
		l.append(["search", "Pose: search"])
		l.append(["dead", "Pose: dead"])
	if root.has_method(&"set_talk"):
		l.append(["talk", "Talking (mouth moves)"])
	return l

func actions() -> Array:
	return _list

func set_action(a: String) -> void:
	action = a
	if inst != null and inst.has_move:
		inst.set_move(0.0 if a == "idle" or a == "talk" else (1.4 if a == "walk" else 4.5))
	if inst != null and inst.alien != null:
		inst.alien.set_pose(StringName(a) if a in ["idle", "alert", "aim", "search", "dead"] else &"idle")
	if root.has_method(&"set_talk"):
		root.call(&"set_talk", a == "talk")

func tick(dt: float) -> void:
	_clock += dt
	if outcast != null:
		outcast.update(_clock, dt)
	else:
		inst.update(_clock, dt)

func dispose() -> void:
	if is_instance_valid(root):
		root.queue_free()

func readout() -> String:
	return action

func focus() -> Vector3:
	return root.global_position
