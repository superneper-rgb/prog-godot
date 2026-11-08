class_name Doors
extends RefCounted
## LEVEL DOORS and world actions (JS index.html addPortal, WORLD_ACTIONS, nearInteract, travel): the one way between levels. X at a doorway shows "X <LABEL>", fades to black, swaps the level in and fades back.
## A level lists its own: `portals` ({id, label, x, z, radius, to, spawn_at, active, before}) and `actions` ({x, z, label, active(player), run()}) on its Level node; both die with the level. X picks the nearest of talkers, doors and actions.

var portals: Array[Dictionary] = []
var actions: Array[Dictionary] = []
var travelling := false


func add_portal(def: Dictionary) -> Dictionary:
	var p := {"y": 0.0, "radius": 1.7, "active": Callable()}
	p.merge(def, true)
	if p.has("spawnAt") and not p.has("spawn_at"):      # (as level.json spells it)
		p["spawn_at"] = p["spawnAt"]
	if not p.has("id") or not p.has("label") or not p.has("to"):
		push_error("add_portal needs id, label and to")
		return p
	portals.append(p)
	return p


func add_action(a: Dictionary) -> void:
	actions.append(a)


## JS leaveLevel: its doors and actions go with it.
func clear_level() -> void:
	portals.clear()
	actions.clear()


## JS enterLevel: a level's own doors and actions come in with it.
func enter_level(lv: Level) -> void:
	for p: Dictionary in lv.portals:
		add_portal(p)
	for a: Dictionary in lv.actions:
		add_action(a)


func near_portal() -> Dictionary:
	var P := Game.player
	if P.dead:
		return {}
	for p: Dictionary in portals:
		var act: Callable = p.get("active", Callable())
		if (act.is_null() or act.call()) and U.hyp(P.x - float(p["x"]), P.z - float(p["z"])) < float(p["radius"]):
			return p
	return {}


## what X would act on right now: the nearest talker, level door or action. {} when nothing; else one of {portal}, {talker}, {action}.
func near_interact() -> Dictionary:
	if Game.vehicles != null and Game.vehicles.driving:     # (in a car: no dialogue, doors or buttons)
		return {}
	var P := Game.player
	var t: Dictionary = Game.dialogue.near_talker()
	var p := near_portal()
	var dt := U.hyp(P.x - float(t["x"]), P.z - float(t["z"])) if not t.is_empty() else INF
	var dp := U.hyp(P.x - float(p["x"]), P.z - float(p["z"])) if not p.is_empty() else INF
	var best := {}
	if not p.is_empty() and dp <= dt:
		best = {"portal": p}
	elif not t.is_empty():
		best = {"talker": t}
	var distance := minf(dt, dp)
	if not P.dead:
		for a: Dictionary in actions:
			var act: Callable = a.get("active", Callable())
			if act.is_null() or act.call(P):
				var d := U.hyp(P.x - float(a["x"]), P.z - float(a["z"]))
				if d < distance:
					best = {"action": a}
					distance = d
	return best


## What the prompt says (GameUi.interact_hint).
func hint() -> Dictionary:
	var it := near_interact()
	if it.is_empty():
		return {}
	var text := ""
	if it.has("action"):
		var l: Variant = it["action"].get("label", "")
		text = String(l.call()) if l is Callable else String(l)
	elif it.has("portal"):
		text = String(it["portal"]["label"])
	else:
		text = "TALK — " + String(it["talker"]["name"])
	return {"key": "X", "text": text, "cls": "talk"}


## X: do what near_interact found.
func use(it: Dictionary) -> void:
	if it.has("action"):
		(it["action"]["run"] as Callable).call()
	elif it.has("portal"):
		travel(it["portal"])
	else:
		Game.dialogue.start(it["talker"])


## through a level door (or any in-game level change): fade to black, swap the level, fade back in
func travel(p: Dictionary) -> void:
	if travelling:
		return
	var to := String(p["to"])
	if not Game.LEVELS.has(to):                 # a door to a level that is not in this build says so, rather than breaking the game
		Game.hud.toast("THIS DOOR ISN'T OPEN YET", 1.6)
		return
	travelling = true
	if Game.night_vision.on and not Game.night_vision.busy:
		Game.night_vision.toggle()
	Game.save_game()
	var P := Game.player
	P.vx = 0.0
	P.vz = 0.0
	var tree := Game.get_tree()
	var before: Callable = p.get("before", Callable())
	if not before.is_null():                     # a door with its own intro (the DEAD AIR grate's cards) ends on black
		await before.call()
		Game.ui.set_fade(true)
	else:
		Game.ui.set_fade(true)
		await tree.create_timer(0.48, true).timeout
	Game.ui.set_fade(true, "LOADING %s ..." % MainMenu.level_name(to).to_upper())
	await tree.process_frame
	await Game.enter_level(to, String(p.get("spawn_at", "")))
	Game.ui.set_fade(true)
	travelling = false
	Inp.guard_arm()
	await tree.create_timer(0.12, true).timeout
	Game.ui.set_fade(false)
