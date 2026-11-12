class_name Weapons
extends RefCounted
## Weapon definitions, pure data (JS WEAPONS + the arena prototype weapons + weapons/starter-arms.js + weapons/scorpion-flail.js, in that order: one list for the whole
## session, and an index means the same weapon everywhere). Slot 'fists' (index -1) is the unarmed three-punch combo. Same ids, same numbers.
##
## pierce (snipers): a killing round goes on into the next body in line, its damage cut by pierce x the victim's hp (Combat._shoot): 1 = plain overkill, lower = cleaner
## penetration. Bolt Sniper 1.0 (140 -> 80 -> 20: two robots), Last Word 0.8 (170 -> 122 -> 74 -> 26: three). max bodies per shot, min damage worth carrying.
## Damage is the same against every enemy (no per-type multipliers): enemies resist through their own rules (armour plates, shields, weak points). The FointX guns
## out-hit their plain pre-FointX twins (weapons/starter-arms.js, legacy_*).

## One weapon. A field that a JS entry left out reads as the default here (undefined was falsy there).
class Def:
	var id := ""
	var name := ""
	var tag := ""
	var mode := "semi"           # semi | auto
	var rate := 1.0              # shots per second
	var dmg := 0.0
	var pellets := 1
	var spread := 0.0            # rad
	var bloom_add := 0.0
	var bloom_max := 0.0
	var range := 0.0             # m
	var max := 0                 # total rounds carried (mag + reserve)
	var mag_size := 0
	var reload_kind := "mag"     # mag | shell | rocket
	var reload_time := 0.0
	var kick := 0.0
	var shake := 0.0
	var two_hand := false
	var proj := false
	var speed := 0.0             # proj only: rocket speed
	var radius := 0.0            # proj only: blast radius
	var pierce := 0.0
	var scope := false           # ADS looks through a zoomed scope (first-person, FOV = scope_fov, look speed scaled to the zoom, scope overlay). Hip fire is deliberately loose.
	var scope_fov := 0.0
	var scope_spread := 0.0
	var special := ""            # saw | yoke | arc | bellows | flail ("" = plain gun)
	var energy := false          # ammo = charge in % (mag_size 100, no reserve)
	var silenced := false
	var melee := false

	func _init(o: Dictionary) -> void:
		for k: String in o:
			set(k, o[k])


## JS NEWW: shared with the weapon models (spin speed, orbiting stones, ...). Combat writes it every frame, WeaponView's model animations read it.
class Live:
	var charge := 0.0
	var ammo := 0.0
	var t := 0.0
	var arc := 0.0
	var mag := 0
	var reserve := 0.0
	var o := 0.0
	var o2 := 0.0
	var o3 := 0.0


const PIERCE_MAX := 4           # PIERCE.max
const PIERCE_MIN := 15.0        # PIERCE.min

# max = total rounds carried (mag + reserve). Reload phases (fractions of reload_time) shared by the sim and the animator.
const RL_PH: Array = [["grab", 0.14], ["pull", 0.30], ["pouch", 0.50], ["fetch", 0.68], ["insert", 0.78], ["rack", 0.92], ["ready", 1.01]]
# shotgun: seconds (open, per shell, final pump)
const SHELL_OPEN := 0.28
const SHELL_PER := 0.38
const SHELL_PUMP := 0.40
# The weapon wheel is an inventory: WHEEL_WEAPONS weapon slots (Combat.slots, filled in pick-up / purchase order) plus fists, which are permanent. The left half of the wheel is reserved for powers (see class Wheel).
const WHEEL_WEAPONS := 5

const PRICE := {
	"deagle": {"buy": 450, "rd": 6.0}, "shotgun": {"buy": 700, "rd": 4.0}, "rifle": {"buy": 1200, "rd": 1.2}, "smg": {"buy": 900, "rd": 0.8}, "rocket": {"buy": 2500, "rd": 120.0}, "sniper": {"buy": 3200, "rd": 25.0},
	"saw": {"buy": 1800, "rd": 8.0}, "yoke": {"buy": 2800, "rd": 30.0}, "arc": {"buy": 2200, "rd": 0.0}, "bellows": {"buy": 3400, "rd": 140.0},
	"pistol": {"buy": 100, "rd": 0.4}, "legacy_smg": {"buy": 700, "rd": 0.8}, "dual_silenced": {"buy": 1100, "rd": 0.5},
	"legacy_deagle": {"buy": 320, "rd": 5.0}, "legacy_rifle": {"buy": 850, "rd": 1.0}, "legacy_rocket": {"buy": 1800, "rd": 100.0}, "legacy_sniper": {"buy": 2300, "rd": 20.0},
	"flail": {"buy": 2600, "rd": 24.0},
}

# Arena prototype weapons: Saw-Loop, Moon Yoke, Electranator, Bellows Beast. Always in WEAPONS (one list for the whole session: levels are swapped in one page, and weapon
# indexes must mean the same weapon everywhere), but only sold / handed out where a level says so (JS arenaWeaponsHere: FOINT DOME = `foint-dome`, the dev level, the Meat Spire).
const ARENA_IDS: Array[String] = ["saw", "yoke", "arc", "bellows"]

# Saw-Loop tuning (JS SAW)
const SAW_SPEED0 := 24.0
const SAW_SPEED_MAX := 50.0
const SAW_GAIN := 1.17
const SAW_DMG0 := 26.0
const SAW_DMG_GAIN := 0.3
const SAW_DMG_MAX := 80.0
const SAW_MAX_BOUNCE := 9
const SAW_SEEK_R := 20.0
const SAW_R := 0.28
const SAW_LIFE := 9.0
const SAW_TURN := 5.5
const SAW_RET_SPEED := 30.0
const SAW_SLICE := 0.94
const SAW_CATCH_R := 1.25
const SAW_HIT_CD := 0.32
const SAW_HEAVY_DMG := 0.45

# Moon Yoke tuning (JS YOKE)
const YOKE_CHARGE_TIME := 1.5
const YOKE_MIN_CHARGE := 0.14
const YOKE_SPEED0 := 32.0
const YOKE_SPEED1 := 21.0
const YOKE_GRAV := 13.0
const YOKE_DMG0 := 80.0
const YOKE_DMG1 := 280.0
const YOKE_SPLASH := 2.4
const YOKE_WELL_R0 := 6.5
const YOKE_WELL_R1 := 10.5
const YOKE_WELL_T0 := 3.2
const YOKE_WELL_T1 := 5.6
const YOKE_PULL := 52.0
const YOKE_HEAVY_PULL := 0.18
const YOKE_POISE := 170.0
const YOKE_BEND := 3.2

# Electranator: short-range chain lightning. range = beam length (m), cone = aim forgiveness (rad per m), chain_r = jump distance, chains = extra targets (3 in total),
# dps = damage per second on the first target (chained targets take chain_dmg of it), tick = seconds between zaps, drain / regen = charge % per second, restart = charge fraction needed after a burn-out (JS ARC)
const ARC_RANGE := 12.0
const ARC_CONE := 0.12
const ARC_CHAIN_R := 6.5
const ARC_CHAINS := 2
const ARC_DPS := 60.0
const ARC_CHAIN_DMG := 0.7
const ARC_TICK := 0.2
const ARC_DRAIN := 30.0
const ARC_REGEN := 28.0
const ARC_REGEN_DELAY := 0.6
const ARC_RESTART := 0.3

# Bellows Beast: the blast is instant and pierces. It is a shove first and a damage dealer second (48 dmg leaves a normal 60 hp robot alive, so it gets thrown aside rather than dropped). Lane = cone from w0 (m, half width at the muzzle) to w1 at `range`; damage fades by `falloff` over the range.
# kb = knockback on robots (heavy ones take kb_heavy x of it), push = extra sideways shove (m/s) that opens the path, fwd = how much of the shove goes down the lane, kb_plain = practice targets / NPCs (JS BELL)
const BELL_RANGE := 28.0
const BELL_W0 := 1.6
const BELL_W1 := 3.6
const BELL_FALLOFF := 0.4
const BELL_KB := 14.0
const BELL_KB_HEAVY := 0.5
const BELL_PUSH := 20.0
const BELL_FWD := 0.35
const BELL_KB_PLAIN := 6.0

# Saved weapon slots are kept by weapon id. The oldest saves kept indexes into this order (the hub's list before the arena weapons existed): the save code uses it once, when it copies a pre-slot save into slot 1.
const LEGACY_HUB_ORDER: Array[String] = ["deagle", "shotgun", "rifle", "smg", "rocket", "sniper", "pistol", "legacy_smg", "legacy_deagle", "legacy_rifle", "legacy_rocket", "legacy_sniper", "dual_silenced"]

## WEAPONS: index = weapon number everywhere. Built once for the session.
static var WEAPONS: Array[Def] = _make()
static var NEWW := Live.new()
static var _by_id: Dictionary = _index()


static func _make() -> Array[Def]:
	var a: Array[Def] = []
	for o: Dictionary in [
		{"id": "deagle", "name": "JAWBREAKER", "tag": "HEAVY PISTOL", "mode": "semi", "rate": 2.6, "dmg": 70.0, "pellets": 1, "spread": 0.003, "bloom_add": 0.0, "range": 120.0,
			"max": 48, "mag_size": 8, "reload_kind": "mag", "reload_time": 1.45, "kick": 1.1, "shake": 0.45, "two_hand": false, "proj": false},
		{"id": "shotgun", "name": "PUMP SHOTGUN", "tag": "CLOSE-RANGE DEVASTATION", "mode": "semi", "rate": 1.15, "dmg": 11.0, "pellets": 10, "spread": 0.07, "bloom_add": 0.0, "range": 45.0,
			"max": 24, "mag_size": 6, "reload_kind": "shell", "reload_time": 0.0, "kick": 1.8, "shake": 0.9, "two_hand": true, "proj": false},
		{"id": "rifle", "name": "LEAD ZEPPELIN", "tag": "CONTROLLED FULL-AUTO", "mode": "auto", "rate": 9.5, "dmg": 20.0, "pellets": 1, "spread": 0.007, "bloom_add": 0.004, "bloom_max": 0.03, "range": 140.0,
			"max": 210, "mag_size": 30, "reload_kind": "mag", "reload_time": 1.9, "kick": 0.38, "shake": 0.18, "two_hand": true, "proj": false},
		{"id": "smg", "name": "THE SWARM", "tag": "RAPID AUTOMATIC FIRE", "mode": "auto", "rate": 17.0, "dmg": 11.0, "pellets": 1, "spread": 0.02, "bloom_add": 0.004, "bloom_max": 0.05, "range": 90.0,
			"max": 360, "mag_size": 40, "reload_kind": "mag", "reload_time": 1.65, "kick": 0.2, "shake": 0.1, "two_hand": true, "proj": false},
		{"id": "rocket", "name": "HEAVY ROTATION", "tag": "ONE ROCKET PER SHOT", "mode": "semi", "rate": 0.75, "dmg": 400.0, "pellets": 1, "spread": 0.002, "bloom_add": 0.0, "range": 160.0,
			"max": 12, "mag_size": 1, "reload_kind": "rocket", "reload_time": 1.4, "kick": 2.2, "shake": 1.2, "two_hand": true, "proj": true, "speed": 30.0, "radius": 4.8},
		{"id": "sniper", "name": "THE LAST WORD", "tag": "SCOPED LONG-RANGE PRECISION", "mode": "semi", "rate": 0.8, "dmg": 170.0, "pierce": 0.8, "pellets": 1, "spread": 0.03, "bloom_add": 0.0, "range": 400.0,
			"max": 30, "mag_size": 5, "reload_kind": "mag", "reload_time": 2.4, "kick": 2.0, "shake": 0.6, "two_hand": true, "proj": false, "scope": true, "scope_fov": 13.0, "scope_spread": 0.0008},
		# special: 'saw' -> ricochet disc (Combat._saw_launch / _saw_step); 'yoke' -> hold to gather, release to sling (Combat._yoke_hold / _yoke_launch)
		{"id": "saw", "name": "SAW-LOOP", "tag": "RICOCHET DISC LAUNCHER", "mode": "semi", "rate": 1.7, "dmg": 26.0, "pellets": 1, "spread": 0.0, "bloom_add": 0.0, "range": 120.0,
			"max": 20, "mag_size": 4, "reload_kind": "mag", "reload_time": 1.6, "kick": 0.5, "shake": 0.2, "two_hand": true, "proj": false, "special": "saw"},
		{"id": "yoke", "name": "MOON YOKE", "tag": "GRAVITY SLING", "mode": "semi", "rate": 1.0, "dmg": 70.0, "pellets": 1, "spread": 0.0, "bloom_add": 0.0, "range": 80.0,
			"max": 12, "mag_size": 3, "reload_kind": "mag", "reload_time": 2.3, "kick": 1.2, "shake": 0.5, "two_hand": true, "proj": false, "special": "yoke"},
		# energy weapon: ammo = charge in % (mag_size 100, no reserve). Drains while the trigger is held, refills by itself (Combat._arc_step / _arc_beam / _arc_zap)
		{"id": "arc", "name": "ELECTRANATOR", "tag": "SELF-CHARGING ARC PYLON", "mode": "auto", "rate": 5.0, "dmg": 60.0, "pellets": 1, "spread": 0.0, "bloom_add": 0.0, "range": 12.0,
			"max": 100, "mag_size": 100, "reload_kind": "mag", "reload_time": 1.0, "kick": 0.0, "shake": 0.0, "two_hand": true, "proj": false, "special": "arc", "energy": true},
		# sonic cannon: one fat blast that pierces everything in a widening lane, hits hard and shoves enemies out of the lane (Combat._bellows_fire). Very little ammo.
		{"id": "bellows", "name": "BELLOWS BEAST", "tag": "SONIC PATH-CLEARER", "mode": "semi", "rate": 0.55, "dmg": 48.0, "pellets": 1, "spread": 0.0, "bloom_add": 0.0, "range": 28.0,
			"max": 8, "mag_size": 2, "reload_kind": "mag", "reload_time": 2.6, "kick": 2.1, "shake": 0.9, "two_hand": true, "proj": false, "special": "bellows"},
		# ---- weapons/starter-arms.js: append-only catalogue entries, existing weapon ids, indices and models stay intact ----
		{"id": "pistol", "name": "SERVICE PISTOL", "tag": "COMPACT SEMI-AUTO", "mode": "semi", "rate": 6.0, "dmg": 12.0,
			"pellets": 1, "spread": 0.005, "bloom_add": 0.002, "bloom_max": 0.018, "range": 65.0, "max": 150, "mag_size": 15,
			"reload_kind": "mag", "reload_time": 1.25, "kick": 0.22, "shake": 0.06, "two_hand": false, "proj": false},
		# Original starting SMG tuning, restored separately from the newer Swarm.
		{"id": "legacy_smg", "name": "SUBMACHINE GUN", "tag": "CLASSIC COMPACT AUTOMATIC", "mode": "auto", "rate": 17.0, "dmg": 9.0,
			"pellets": 1, "spread": 0.02, "bloom_add": 0.004, "bloom_max": 0.05, "range": 90.0, "max": 360, "mag_size": 40,
			"reload_kind": "mag", "reload_time": 1.65, "kick": 0.2, "shake": 0.1, "two_hand": true, "proj": false},
		# The pre-FointX arsenal, restored beside the renamed ones: original names, original models, plain bullets / rockets. Weaker and cheaper than
		# their FointX twins (lower dmg, smaller blast, weaker penetration); legacy_smg keeps the original tuning because the warehouse is balanced around it.
		{"id": "legacy_deagle", "name": "DESERT EAGLE", "tag": ".50 HAND CANNON", "mode": "semi", "rate": 2.6, "dmg": 52.0, "pellets": 1, "spread": 0.003, "bloom_add": 0.0, "range": 120.0,
			"max": 48, "mag_size": 8, "reload_kind": "mag", "reload_time": 1.45, "kick": 1.1, "shake": 0.45, "two_hand": false, "proj": false},
		{"id": "legacy_rifle", "name": "ASSAULT RIFLE", "tag": "FULL-AUTO RELIABLE", "mode": "auto", "rate": 9.5, "dmg": 15.0, "pellets": 1, "spread": 0.007, "bloom_add": 0.004, "bloom_max": 0.03, "range": 140.0,
			"max": 210, "mag_size": 30, "reload_kind": "mag", "reload_time": 1.9, "kick": 0.38, "shake": 0.18, "two_hand": true, "proj": false},
		{"id": "legacy_rocket", "name": "ROCKET LAUNCHER", "tag": "AREA DENIAL", "mode": "semi", "rate": 0.75, "dmg": 320.0, "pellets": 1, "spread": 0.002, "bloom_add": 0.0, "range": 160.0,
			"max": 12, "mag_size": 1, "reload_kind": "rocket", "reload_time": 1.4, "kick": 2.2, "shake": 1.2, "two_hand": true, "proj": true, "speed": 30.0, "radius": 4.0},
		{"id": "legacy_sniper", "name": "BOLT SNIPER", "tag": "ONE SHOT, LONG RANGE", "mode": "semi", "rate": 0.8, "dmg": 140.0, "pierce": 1.0, "pellets": 1, "spread": 0.03, "bloom_add": 0.0, "range": 400.0,
			"max": 30, "mag_size": 5, "reload_kind": "mag", "reload_time": 2.4, "kick": 2.0, "shake": 0.6, "two_hand": true, "proj": false, "scope": true, "scope_fov": 13.0, "scope_spread": 0.0008},
		# Two suppressed service pistols, one per hand, fired alternately. One shared 30-round count (15 per gun).
		{"id": "dual_silenced", "name": "HUSH TWINS", "tag": "SUPPRESSED DUAL PISTOLS", "mode": "semi", "rate": 8.0, "dmg": 11.0,
			"pellets": 1, "spread": 0.008, "bloom_add": 0.002, "bloom_max": 0.022, "range": 60.0, "max": 240, "mag_size": 30,
			"reload_kind": "mag", "reload_time": 2.1, "kick": 0.14, "shake": 0.03, "two_hand": false, "proj": false, "silenced": true},
		# ---- weapons/scorpion-flail.js: the SCORPION FLAIL (melee): after the starter arms so no earlier index moves. Combat owns the trigger, ammo and cooldown; the entire attack lasts 0.70 s. ----
		{"id": "flail", "name": "SCORPION FLAIL", "tag": "BALL AND CHAIN", "mode": "auto", "rate": 1.0 / 0.70, "dmg": 85.0, "pellets": 1, "spread": 0.0, "bloom_add": 0.0, "range": 4.0,
			"max": 20, "mag_size": 20, "reload_kind": "mag", "reload_time": 1.0, "kick": 0.0, "shake": 0.0, "two_hand": false, "proj": false, "special": "flail", "melee": true},
	]:
		a.append(Def.new(o))
	return a


static func _index() -> Dictionary:
	var d := {}
	for i in WEAPONS.size():
		d[WEAPONS[i].id] = i
	return d


## JS arenaWeaponsHere: where the arena prototype weapons are sold / handed out.
static func arena_weapons_here() -> bool:
	var lv := Game.level
	return lv != null and (lv.id == "foint-dome" or lv.id == "dev" or lv.id == "spire")


## Weapon number for an id, -1 if there is none (JS WEAPONS.findIndex).
static func index_of(id: String) -> int:
	return _by_id.get(id, -1)


## The definition for an id, null if there is none.
static func by_id(id: String) -> Def:
	var i: int = _by_id.get(id, -1)
	return WEAPONS[i] if i >= 0 else null
