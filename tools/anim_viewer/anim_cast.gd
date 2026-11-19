class_name AnimCast
extends RefCounted
## Everyone the animation viewer shows besides the playable Progs (dev tool, never part of the game): the enemies and the NPCs, each with its own real model, view and animation.
## An enemy is the game's own Robot class run by the game's own AI (Enemies.update) against a stand-in target the viewer holds, and drawn by the game's own view, so what it does here is what it does in play:
## the viewer only picks the state (stand, patrol, alert, chase, fight, one kind of attack on a loop, a hit, a death) and where the target is. An NPC is whatever the DEV level's NPC maker (DevNpcs) builds, and
## the outcasts of UNDERFOINT. What the views would draw through FX (bolts, sparks, hit flashes) is not drawn: the viewer runs without it.

## kind (Game.spawn_enemy's), label. An empty kind is a heading.
const ENEMIES: Array = [
	["", "ROBOTS"],
	["robot", "Robot"],
	["heavy", "Heavy Robot"],
	["drone", "Gun Drone"],
	["spider", "Maintenance Spider"],
	["", "THE GRAYS"],
	["alien", "Gray Alien"],
	["tommygun", "Tommy-Gun Gray"],
	["buttonman", "The Button Man"],
	["muscle", "The Muscle"],
	["butler", "Probe Butler"],
	["consigliere", "The Consigliere"],
	["", "THE MEAT SPIRE"],
	["prophet", "Flayed Prophet"],
	["follower", "Prophet's Follower"],
	["crawler", "Sinewcrawler"],
	["spore", "Blisterbloat"],
	["tongue", "Wallwretch"],
	["brute", "Gristle Brute"],
	["mimic", "Mawledge"],
	["scream", "Mawnest"],
	["worm", "Dirgeworm"],
	["warden", "The Marrow Warden"],
	["dervish", "The Briar Dervish"],
	["", "PEOPLE"],
	["assassin", "Night Assassin"],
	["goon", "FOINT Goon"],
	["", "UNDERFOINT"],
	["taken", "The Taken"],
	["tethered", "The Tethered"],
]

## id, label, default target distance (0: keep the last), what the target does: "far" (out of sight), "ahead" (keeps its distance in front of the enemy, so it never arrives), "fixed" (stays where it is)
const FOE_ACTIONS: Array = [
	["", "STANCE", 0.0, ""],
	["stand", "Stand (AI off)", 0.0, "fixed"],
	["patrol", "Patrol its own beat", 0.0, "far"],
	["alert", "Alert (held)", 6.0, "ahead"],
	["", "MOVING", 0.0, ""],
	["chase", "Chase the target", 12.0, "ahead"],
	["", "FIGHTING", 0.0, ""],
	["fight", "Fight (the game's own AI)", 6.0, "fixed"],
	["melee", "Melee attack (loop)", 1.6, "fixed"],
	["shot", "Ranged attack (loop)", 9.0, "fixed"],
	["", "REACTIONS", 0.0, ""],
	["flinch", "Hit, light (loop)", 4.0, "fixed"],
	["stagger", "Hit, heavy (loop)", 4.0, "fixed"],
	["death", "Death and revive (loop)", 4.0, "fixed"],
]

const NPC_IDS: Array = [
	["", "THE HUB AND DEV LEVEL"],
	["shit-chan", ""], ["pale_punk", ""], ["gray_alien", ""], ["green_alien", ""], ["puppy", ""], ["winged", ""], ["cherub", ""], ["the_boss", ""], ["frug", ""], ["frug_suit", ""],
	["", "UNDERFOINT OUTCASTS"],
	["outcast:stoker", "Stoker"], ["outcast:ragwoman", "Ragwoman"], ["outcast:listener", "Listener"], ["outcast:ticketman", "Ticket Man"], ["outcast:collector", "Collector"],
]

static var next_id := 7000


static func foe_label(kind: String) -> String:
	for e: Array in ENEMIES:
		if e[0] == kind:
			return e[1]
	return kind


static func npc_label(id: String) -> String:
	for e: Array in NPC_IDS:
		if e[0] == id and e[1] != "":
			return e[1]
	if id.begins_with("outcast:"):
		return id.substr(8).capitalize()
	for d: Dictionary in DevNpcs.BUILT_IN:
		if d.id == id:
			return String(d.name).capitalize()
	return id


static func foe_action(id: String) -> Array:
	for a: Array in FOE_ACTIONS:
		if a[0] == id:
			return a
	return FOE_ACTIONS[1]
