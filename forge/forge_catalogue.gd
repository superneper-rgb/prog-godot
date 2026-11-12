class_name ForgeCatalogue
extends RefCounted
## FORGE's palette: what can be placed, one tab per kind, built from the lists the game already has (nothing copied).
## An entry is a DevProps-style definition: {id, name, note, base [w, h, d] metres, color, col (box / disc / ramp / stairs / ""), kind, file?}.
## SHAPES and PROPS are the dev level's (levels/dev/dev_props.gd); MODELS are the polyfork props listed in assets/third-party/CREDITS.json (originals only: the "-mod" copies are their 512 px versions, and rigged ones are skipped).

const TABS := [["shape", "SHAPES"], ["prop", "PROPS"], ["model", "MODELS"]]
const CREDITS := "res://assets/third-party/CREDITS.json"
const MODEL_DIR := "res://assets/third-party/"

static var _models: Array = []
static var _models_read := false
static var _copies := {}      # "<level>|<piece id>" -> entry: a piece of the original level, stamped as a new thing (type "copy")


static func items(cat: String) -> Array:
	match cat:
		"shape":
			return DevProps.SHAPES
		"prop":
			return DevProps.PROPS
		"model":
			return models()
	return []


static func find(cat: String, id: String) -> Variant:
	if cat == "copy":      # (made by copy_entry, for the level that is open)
		return _copies.get("%s|%s" % [Game.level.id if Game.level != null else "", id])
	for d: Dictionary in items(cat):
		if d.id == id:
			return d
	return null


static func tab_name(cat: String) -> String:
	for t: Array in TABS:
		if t[0] == cat:
			return t[1]
	return cat.to_upper()


static func models() -> Array:
	if _models_read:
		return _models
	_models_read = true
	if not FileAccess.file_exists(CREDITS):
		return _models
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS))
	if not data is Dictionary:
		return _models
	var keys: Array = (data as Dictionary).keys()
	keys.sort()
	for k: String in keys:
		var c: Dictionary = data[k]
		if not k.begins_with("polyfork/") or not k.ends_with(".glb") or k.ends_with("-mod.glb") or c.has("derivedFrom") or bool(c.get("rigged", false)):
			continue
		var file := MODEL_DIR + k
		if not ResourceLoader.exists(file):
			continue
		var sz: Dictionary = c.get("size_m", {"x": 1.0, "y": 1.0, "z": 1.0})
		_models.append({"id": k.get_file().get_basename(), "name": String(c.get("title", k)).to_upper(), "note": "%d tris" % int(c.get("tris", 0)),
				"base": [float(sz.x), float(sz.y), float(sz.z)], "color": "", "col": "box", "kind": "model", "file": file})
	return _models


## a copy of an original level piece as a placeable entry (its mesh cut from the level once, kept for the session); null if the piece is not on this level
static func copy_entry(L: ForgeLayer, id: String) -> Variant:
	var lv := L.get_parent() as Level
	var k := "%s|%s" % [lv.id if lv != null else "", id]
	if _copies.has(k):
		return _copies[k]
	var P := L.get_pieces()
	if P == null or P.obj(id) == null:
		return null
	var m := P.copy_mesh(id)
	if m.is_empty() or (m[0] as ArrayMesh).get_surface_count() == 0:
		return null
	var sz: Vector3 = m[1]
	var o := P.obj(id)
	var e := {"id": id, "name": (o.name if o.name != "" else id.get_file()).to_upper(), "note": "a piece of this level", "base": [sz.x, sz.y, sz.z], "color": "", "col": "box", "kind": "copy", "mesh": m[0], "key": k}
	_copies[k] = e
	return e

