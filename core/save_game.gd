class_name SaveGame
extends RefCounted
## SAVE GAME (JS save/save-game.js): three autosave slots, one plain-JSON record per slot holding everything the player has earned (where they are, money, weapons + ammo, armor, implants, story).
## Storage: user://slot.1.json .. user://slot.3.json = the records, user://slot.txt = the slot in use. The game keeps ONE live record (`data`), changes it in place and calls write().
## Record: where {level, spawn_at, cp}, money, gear {slots, ammo, reserve, equip}, granted {level: [weapon ids]}, armor {owned, equipped}, powers {owned, equipped}, story {flag: true}, arena {wins}, done {level: true}, play_ms, created_at, saved_at.
## A game started with --level= (tests, the dev's quick launch) keeps its record in memory only, so it never overwrites a real slot.

const SLOT_COUNT := 3
const VERSION := 1
const START_MONEY := 10000

var active := 1
var data: Dictionary = {}
var disk := true
var _switching := false     # set by select() / erase(): the record about to be replaced must not be written over the new slot
var _mem := {}              # the stand-in when disk is off


func _init(p_disk: bool = true) -> void:
	disk = p_disk
	var a := 1
	if disk and FileAccess.file_exists("user://slot.txt"):
		a = int(FileAccess.get_file_as_string("user://slot.txt").strip_edges())
	active = a if (a >= 1 and a <= SLOT_COUNT) else 1
	var r: Variant = _read(active)
	data = r if r != null else blank_save()


static func _now() -> float:
	return Time.get_unix_time_from_system() * 1000.0


## A new game's record.
static func blank_save() -> Dictionary:
	return {"v": VERSION, "created_at": _now(), "saved_at": 0.0, "play_ms": 0.0, "where": {"level": "", "spawn_at": "", "cp": null}, "money": START_MONEY,
		"gear": {"slots": [], "ammo": {}, "reserve": {}, "equip": null}, "granted": {}, "armor": {"owned": ["standard"], "equipped": "standard"},
		"powers": {"owned": [], "equipped": null}, "story": {}, "arena": {}, "done": {}}


static func _obj(o: Variant) -> Dictionary:
	return o if o is Dictionary else {}


static func _arr(a: Variant) -> Array:
	return a if a is Array else []


## A stored record made safe to use: every field present and the right type (a damaged or older record keeps what it can).
static func clean(r: Variant) -> Dictionary:
	var b := blank_save()
	var d := _obj(r)
	var w := _obj(d.get("where"))
	var g := _obj(d.get("gear"))
	var cp: Variant = null
	var wcp: Variant = w.get("cp")
	if wcp is Dictionary and (wcp.get("stage") is float or wcp.get("stage") is int):
		cp = {"stage": wcp.stage, "obj": float(wcp.get("obj", 0.0))}
	var slots := []
	for id: Variant in _arr(g.get("slots")):
		slots.append(id if id is String else null)
	var granted := {}
	for k: Variant in _obj(d.get("granted")):
		granted[k] = _arr(d.granted[k])
	var created: float = float(d.get("created_at", 0.0))
	var money_v: Variant = d.get("money")
	var armor := _obj(d.get("armor"))
	var powers := _obj(d.get("powers"))
	return {"v": VERSION, "created_at": created if created != 0.0 else b.created_at, "saved_at": float(d.get("saved_at", 0.0)), "play_ms": maxf(0.0, float(d.get("play_ms", 0.0))),
		"where": {"level": w.get("level", "") if w.get("level") is String else "", "spawn_at": w.get("spawn_at", "") if w.get("spawn_at") is String else "", "cp": cp},
		"money": maxf(0.0, money_v) if (money_v is float or money_v is int) else START_MONEY,
		"gear": {"slots": slots, "ammo": _obj(g.get("ammo")), "reserve": _obj(g.get("reserve")), "equip": g.get("equip") if g.get("equip") is String else null},
		"granted": granted,
		"armor": {"owned": _arr(armor.get("owned")), "equipped": armor.get("equipped", "standard") if armor.get("equipped") else "standard"},
		"powers": {"owned": _arr(powers.get("owned")), "equipped": powers.get("equipped") if powers.get("equipped") else null},
		"story": _obj(d.get("story")), "arena": _obj(d.get("arena")), "done": _obj(d.get("done"))}


func _path(n: int) -> String:
	return "user://slot.%d.json" % n


func _read(n: int) -> Variant:
	var t := ""
	if disk:
		if not FileAccess.file_exists(_path(n)):
			return null
		t = FileAccess.get_file_as_string(_path(n))
	else:
		if not _mem.has(n):
			return null
		t = _mem[n]
	var r: Variant = JSON.parse_string(t)
	return clean(r) if r is Dictionary else null


func _write_raw(n: int, txt: String) -> bool:
	if not disk:
		_mem[n] = txt
		return true
	var f := FileAccess.open(_path(n), FileAccess.WRITE)
	if f == null:
		push_warning("Could not save the game: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(txt)
	f.close()
	var a := FileAccess.open("user://slot.txt", FileAccess.WRITE)
	if a != null:
		a.store_string(str(active))
		a.close()
	return true


## True once the slot in use holds a saved game.
func exists() -> bool:
	return FileAccess.file_exists(_path(active)) if disk else _mem.has(active)


## Store the live record in its slot. Returns false when storage refused it.
func write() -> bool:
	if _switching:
		return false
	data.saved_at = _now()
	return _write_raw(active, JSON.stringify(data))


## What each slot holds, for the LOAD / NEW GAME menus: [{n, empty, level, money, play_ms, saved_at}]
func slots() -> Array:
	var out := []
	for i in SLOT_COUNT:
		var r: Variant = _read(i + 1)
		if r != null:
			out.append({"n": i + 1, "empty": false, "level": r.where.level, "money": r.money, "play_ms": r.play_ms, "saved_at": r.saved_at})
		else:
			out.append({"n": i + 1, "empty": true})
	return out


## Make slot n the one in use: its record becomes the live one.
func select(n: int) -> void:
	if n >= 1 and n <= SLOT_COUNT:
		active = n
		var r: Variant = _read(n)
		data = r if r != null else blank_save()
		if disk:
			var a := FileAccess.open("user://slot.txt", FileAccess.WRITE)
			if a != null:
				a.store_string(str(n))
				a.close()


## Start a new game in slot n (its old record is replaced) and make it the one in use.
func fresh(n: int) -> void:
	var b := blank_save()
	b.saved_at = _now()
	_write_raw(n, JSON.stringify(b))
	select(n)


## Empty slot n.
func erase(n: int) -> void:
	if disk:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(n)))
	else:
		_mem.erase(n)
	if n == active:
		data = blank_save()
