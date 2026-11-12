class_name ForgeEdits
extends RefCounted
## FORGE (the in-game level editor; new on purpose, not a port): one level's edits, kept in assets/levels/<id>/edits.json next to the exported level. A level is its export plus this file; the exporter never writes it.
## Every change is an op, applied by apply_op() and nowhere else: {op: "create", uid, fields} / {op: "update", uid, fields (only the ones that change)} / {op: "delete", uid} / {op: "batch", ops}.
## apply_op returns the op that undoes it. Undo, redo and a future co-op editor (the same ops sent over the network) all go through this one path. Uids are "<author>-<n>", so two editors never make the same one.

const VERSION := 1
const FIELDS := ["type", "id", "pos", "rot", "size", "color", "collide", "hidden", "params", "held_by"]


## one placed thing, or one edit of the original level. rot is degrees (pitch, yaw, roll), the order DevProps and Node3D.rotation use; size is metres; pos is the centre.
## type "piece" / "inst" (uid "o:" + the piece's id): an original piece of the level (forge/forge_pieces.gd): pos is how far it moved, rot.y how far it turned, hidden = deleted.
class Obj:
	var uid := ""
	var type := ""          # catalogue tab: shape, prop, model, copy; or piece / inst for the original level
	var id := ""            # catalogue id inside that tab
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	var size := Vector3.ONE
	var color := ""
	var collide := true
	var hidden := false     # (an original piece: deleted)
	var params := {}        # kind-specific settings (later: an enemy's patrol, a door's destination)
	var held_by := ""       # (co-op, not used yet: who is carrying it)

	func get_field(k: String) -> Variant:
		match k:
			"pos":
				return ForgeEdits.arr3(pos)
			"rot":
				return ForgeEdits.arr3(rot)
			"size":
				return ForgeEdits.arr3(size)
			"params":
				return params.duplicate(true)
		return get(k)

	func set_field(k: String, v: Variant) -> void:
		match k:
			"pos":
				pos = ForgeEdits.vec3(v)
			"rot":
				rot = ForgeEdits.vec3(v)
			"size":
				size = ForgeEdits.vec3(v)
			"params":
				params = (v as Dictionary).duplicate(true) if v is Dictionary else {}
			"type", "id", "color", "held_by":
				set(k, String(v))
			"collide":
				collide = bool(v)
			"hidden":
				hidden = bool(v)

	func set_fields(f: Dictionary) -> void:
		for k: String in f:
			set_field(k, f[k])

	func to_fields() -> Dictionary:
		var out := {}
		for k: String in ForgeEdits.FIELDS:
			out[k] = get_field(k)
		if held_by == "":
			out.erase("held_by")
		if params.is_empty():
			out.erase("params")
		if not hidden:
			out.erase("hidden")
		return out


var level_id := ""
var objects: Dictionary = {}     # uid -> Obj
var author := "local"
var dirty := false
var _counter := 0


static func path_for(id: String) -> String:
	return "res://assets/levels/%s/edits.json" % id


static func arr3(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]


static func vec3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() >= 3:
		return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return Vector3.ZERO


static func load_for(id: String) -> ForgeEdits:
	var e := ForgeEdits.new()
	e.level_id = id
	var p := path_for(id)
	if not FileAccess.file_exists(p):
		return e
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not data is Dictionary:
		push_error("forge: %s is not readable JSON: the level loads without its edits" % p)
		return e
	for d: Variant in (data as Dictionary).get("objects", []):
		if not d is Dictionary or not (d as Dictionary).has("uid"):
			continue
		var o := Obj.new()
		o.uid = String(d.uid)
		o.set_fields(d)
		e.objects[o.uid] = o
		e._note_uid(o.uid)
	return e


## Write edits.json into the project. A packed .exe cannot write its own files: the edits stay live but are not saved (false).
func save() -> bool:
	if OS.has_feature("template"):
		return false
	var p := path_for(level_id)
	if objects.is_empty() and not FileAccess.file_exists(p):
		dirty = false
		return true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var list: Array = []
	for uid: String in objects:
		var d: Dictionary = (objects[uid] as Obj).to_fields()
		d["uid"] = uid
		list.append(d)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		push_error("forge: cannot write %s (%s)" % [p, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify({"v": VERSION, "level": level_id, "objects": list}, "\t") + "\n")
	f.close()
	dirty = false
	return true


func new_uid() -> String:
	_counter += 1
	return "%s-%d" % [author, _counter]


func _note_uid(uid: String) -> void:
	var cut := uid.rfind("-")
	if cut > 0 and uid.substr(0, cut) == author:
		_counter = maxi(_counter, int(uid.substr(cut + 1)))


## THE way this data changes. Returns the op that undoes it.
func apply_op(op: Dictionary) -> Dictionary:
	var kind := String(op.get("op", ""))
	if kind == "batch":
		var inv: Array = []
		for sub: Dictionary in op.get("ops", []):
			inv.push_front(apply_op(sub))
		return {"op": "batch", "ops": inv}
	var uid := String(op.get("uid", ""))
	var o: Obj = objects.get(uid)
	match kind:
		"create":
			if o != null:
				push_warning("forge: create of an existing uid " + uid)
				return {"op": "batch", "ops": []}
			o = Obj.new()
			o.uid = uid
			o.set_fields(op.get("fields", {}))
			objects[uid] = o
			_note_uid(uid)
			dirty = true
			return {"op": "delete", "uid": uid}
		"delete":
			if o == null:
				return {"op": "batch", "ops": []}
			objects.erase(uid)
			dirty = true
			return {"op": "create", "uid": uid, "fields": o.to_fields()}
		"update":
			if o == null:
				return {"op": "batch", "ops": []}
			var old := {}
			var f: Dictionary = op.get("fields", {})
			for k: String in f:
				old[k] = o.get_field(k)
			o.set_fields(f)
			dirty = true
			return {"op": "update", "uid": uid, "fields": old}
	push_warning("forge: unknown op " + kind)
	return {"op": "batch", "ops": []}


## every uid an op touches
static func op_uids(op: Dictionary, out: Array[String] = []) -> Array[String]:
	if String(op.get("op", "")) == "batch":
		for sub: Dictionary in op.get("ops", []):
			op_uids(sub, out)
	elif op.has("uid"):
		out.append(String(op.uid))
	return out
