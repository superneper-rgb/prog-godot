class_name ArmorStore
extends RefCounted
## The armor catalogue + the armor store: which suits are owned and which one is worn, saved in the save slot under `armor` (JS ARMOR_CATALOG, ArmorStore).
## `dr` is the rated damage reduction in percent: while a suit is equipped, Combat.hurt_player scales the damage the player takes by (1 - dr / 100).
## `soon: true` marks suits that only have a preview model so far: they can be browsed in the fitting bay but not bought. A suit that is worn on the real characters
## (the PHANTOM SUIT, SCHLEEDTECH COMBAT SUIT, GOINT GEAR XL and O.M.E.N.) has no `soon` flag.
## The fitting bay talks to this class: is_owned(id), is_equipped(id), equipped_id(), purchase(id) -> { ok, reason }, equip(id) -> { ok, reason } (reason: "funds" | "unavailable" | "not owned" | "unknown").
## purchase() charges the money (Game.add_money) and equips; every change is saved, and `on_change(id)` lets the game dress the character.

## The equipped suit's rechargeable energy shield: max, delay (s without damage before it recharges), rate (per second), col, hex. It sits on top of normal health.
class ShieldDef:
	var max := 0.0
	var delay := 0.0
	var rate := 0.0
	var col := ""
	var hex := 0

	func _init(p_max: float, p_delay: float, p_rate: float, p_col: String, p_hex: int) -> void:
		max = p_max
		delay = p_delay
		rate = p_rate
		col = p_col
		hex = p_hex


class Suit:
	var id := ""
	var name := ""
	var tag := ""
	var maker := ""
	var price := 0
	var dr := 0.0
	var shield: ShieldDef = null
	var desc := ""
	var soon := false

	func _init(p_id: String, p_name: String, p_tag: String, p_maker: String, p_price: int, p_dr: float, p_shield: ShieldDef, p_desc: String) -> void:
		id = p_id
		name = p_name
		tag = p_tag
		maker = p_maker
		price = p_price
		dr = p_dr
		shield = p_shield
		desc = p_desc


static var ARMOR_CATALOG: Array[Suit] = _make()
static var ARMOR_BY_ID: Dictionary = _index()

static var live := true
static var owned := {"standard": true}
static var equipped := "standard"
static var on_change: Callable


static func _make() -> Array[Suit]:
	return [
		Suit.new("standard", "STANDARD OUTFIT", "FACTORY ISSUE", "HELIX OUTFITTERS", 0, 0.0, null,
			"Factory-issue utility suit. Comfortable, breathable and rated for absolutely nothing."),
		Suit.new("phantom_suit", "PHANTOM SUIT", "COVERT FIELD SUIT", "GOINT LIFE ASSURANCE", 500, 10.0, null,
			"Navy field bodysuit with a black tactical harness, plated shoulders and knee guards. Light, quiet, and the cheapest way to look like you mean it."),
		Suit.new("goint_gear_xl", "GOINT GEAR XL", "ASSURED FIELD SUIT", "GOINT LIFE ASSURANCE", 2500, 25.0, ShieldDef.new(25.0, 7.0, 9.0, "blue", 0x4db8ff),
			"The flagship Goint field suit: moulded chest plate, a live-monitored hex core and cuff telemetry. Its core projects a thin blue energy shield (+25) that recharges when you stay out of trouble. Your policy has never looked this good."),
		Suit.new("schleedtech_combat", "SCHLEEDTECH COMBAT SUIT", "HEAVY ASSAULT PLATE", "SCHLEEDTECH", 6000, 40.0, ShieldDef.new(40.0, 8.0, 10.0, "orange", 0xff8a1e),
			"Spiked red war plate over a ribbed black undersuit, with a heat-lit Schleedtech crest and an orange energy shield (+40) that recharges after a quiet spell. Loud, heavy, and very hard to put down."),
		Suit.new("omen", "O.M.E.N.", "OFFENSIVE MECHANIZED EXOSKELETAL NEXUS", "SCHLEEDTECH", 15000, 50.0, ShieldDef.new(60.0, 8.0, 12.0, "orange", 0xff8a1e),
			"Schleedtech's prototype war frame: black plate over a live amber reactor, crescent pauldrons and taloned gauntlets, with their strongest orange energy shield yet (+60). Technically still in testing. The test is you."),
	]


static func _index() -> Dictionary:
	var d := {}
	for a: Suit in ARMOR_CATALOG:
		d[a.id] = a
	return d


## JS ArmorStore.load(): a missing or unreadable save just means the standard outfit.
static func load_save() -> void:
	var a: Variant = Game.save_data.get("armor")
	if not (a is Dictionary):
		return
	var new_owned := {"standard": true}
	if a.get("owned") is Array:
		for id: Variant in a.get("owned"):
			if id is String and ARMOR_BY_ID.has(id) and not ARMOR_BY_ID[id].soon:
				new_owned[id] = true
	owned = new_owned
	var e: Variant = a.get("equipped")
	equipped = e if (e is String and owned.has(e)) else "standard"


static func save() -> void:
	Game.save_data.armor = {"owned": owned.keys(), "equipped": equipped}
	Game.save_game(true)


static func is_owned(id: String) -> bool:
	return owned.has(id)


static func is_equipped(id: String) -> bool:
	return equipped == id


static func equipped_id() -> String:
	return equipped


## damage the equipped suit absorbs, 0..1
static func dr() -> float:
	var a: Suit = ARMOR_BY_ID.get(equipped)
	return clampf(a.dr / 100.0, 0.0, 0.9) if a != null else 0.0


## the equipped suit's rechargeable energy shield, or null
static func shield() -> ShieldDef:
	var a: Suit = ARMOR_BY_ID.get(equipped)
	return a.shield if a != null else null


## price: what this vendor charges (an arms depot may undercut the catalogue); negative = the catalogue price
static func purchase(id: String, price: int = -1) -> Dictionary:
	var a: Suit = ARMOR_BY_ID.get(id)
	if a == null:
		return {"ok": false, "reason": "unknown"}
	if a.soon:
		return {"ok": false, "reason": "unavailable"}
	if owned.has(id):
		return equip(id)
	var cost := price if price >= 0 else a.price
	if Game.money < cost:
		return {"ok": false, "reason": "funds"}
	Game.add_money(-cost)
	owned[id] = true
	return equip(id)


static func equip(id: String) -> Dictionary:
	var a: Suit = ARMOR_BY_ID.get(id)
	if a == null:
		return {"ok": false, "reason": "unknown"}
	if a.soon:
		return {"ok": false, "reason": "unavailable"}
	if not owned.has(id):
		return {"ok": false, "reason": "not owned"}
	equipped = id
	save()
	if on_change.is_valid():
		on_change.call(id)
	return {"ok": true}
