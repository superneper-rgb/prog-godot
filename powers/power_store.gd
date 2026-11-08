class_name PowerStore
extends RefCounted
## Which implants the player owns and has equipped (JS PowerStore), kept in the save.

var owned: Array[String] = []
var equipped_id_v: Variant = null
var on_change := Callable()


func _entry(id: Variant) -> Variant:
	return PlasmidCatalog.by_id(String(id)) if id != null else null


func load_save() -> void:
	owned.clear()
	equipped_id_v = null
	var p: Dictionary = Game.save_data.get("powers", {})
	for id: Variant in p.get("owned", []):
		var e: Variant = _entry(id)
		if e != null and e["available"]:
			owned.append(String(id))
	var eq: Variant = p.get("equipped")
	equipped_id_v = eq if (eq != null and owned.has(String(eq))) else null


func save() -> void:
	Game.save_data["powers"] = {"owned": owned.duplicate(), "equipped": equipped_id_v}
	Game.save_game(true)


func is_owned(id: String) -> bool:
	return owned.has(id)


func is_equipped(id: String) -> bool:
	return equipped_id_v == id


func equipped_id() -> Variant:
	return equipped_id_v


func equipped() -> Variant:
	return _entry(equipped_id_v)


func purchase(id: String) -> Dictionary:
	var p: Variant = _entry(id)
	if p == null:
		return {"ok": false, "reason": "unknown"}
	if not p["available"]:
		return {"ok": false, "reason": "unavailable"}
	if owned.has(id):
		return equip(id)
	if Game.money < int(p["price"]):
		return {"ok": false, "reason": "funds"}
	Game.add_money(-int(p["price"]))
	owned.append(id)
	return equip(id)


func equip(id: String) -> Dictionary:
	if _entry(id) == null:
		return {"ok": false, "reason": "unknown"}
	if not owned.has(id):
		return {"ok": false, "reason": "not owned"}
	equipped_id_v = id
	save()
	if on_change.is_valid():
		on_change.call(id)
	return {"ok": true}
