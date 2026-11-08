class_name CreatureGameplay
extends RefCounted
## Who may attack right now (JS enemies/creature-gameplay.js canCreatureAttack, claimCreatureAttack): so a crowd of creatures takes turns instead of unloading at once. Stock Robots and Drones do not use it.

const HARD: Array[StringName] = [&"charge", &"drop", &"tongue", &"mind", &"ring", &"slam", &"burst"]
const MELEE: Array[StringName] = [&"melee", &"whip", &"bite"]


static func lane_of(kind: StringName) -> String:
	if HARD.has(kind):
		return "heavy"
	return "melee" if MELEE.has(kind) else "ranged"


static func can_attack(r: Robot, attack: StringName) -> bool:
	var E: Enemies = r.E
	if E == null or r.dead or float(r.get("wake_grace") if r.get("wake_grace") != null else 0.0) > 0.0:
		return false
	if r.get("mimic") == true or r.get("warden") == true:
		return true
	var lane := lane_of(attack)
	var total := 0
	var heavy := 0
	var melee := 0
	var ranged := 0
	for other: Robot in E.robots:
		if other == r or other.dead or absf(other.y - r.y) > 6.0 or U.hyp(other.x - r.x, other.z - r.z) > 24.0:
			continue
		var pending: bool = other.get("plasma_pending") == true
		var warden_busy: bool = other.get("warden") == true and other.get("mv") in [&"leap", &"roll", &"spray", &"sweep"]
		if other.state != &"windup" and other.state != &"attack" and not pending and not warden_busy:
			continue
		total += 1
		var l := "heavy" if other.get("warden") == true else lane_of(&"shot" if pending else other.atk)
		if l == "heavy":
			heavy += 1
		elif l == "melee":
			melee += 1
		else:
			ranged += 1
	if total >= 3 or (lane == "heavy" and heavy >= 1) or (lane == "melee" and melee >= 2) or (lane == "ranged" and ranged >= 2):
		return false
	var last: Dictionary = E.creature_last_attack
	return last.is_empty() or E.t - float(last["t"]) >= 0.18 or absf(float(last["y"]) - r.y) > 6.0 or U.hyp(float(last["x"]) - r.x, float(last["z"]) - r.z) > 24.0


static func claim_attack(r: Robot) -> void:
	if r.E != null:
		r.E.creature_last_attack = {"t": r.E.t, "x": r.x, "y": r.y, "z": r.z}
