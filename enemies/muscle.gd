class_name Muscle
extends GristleBrute
## THE MUSCLE (JS enemies/gray-family.js): a gray in a tailored exosuit. The Gristle Brute's proven move set (front plate blocks, slow turn, charge, slam, soft back), re-dressed: the plate is riveted chest armour; a SONIC BELLOWS blast or a HAMMER FIST dive slam swings it open and the glowing reactor behind it takes full damage for a few seconds.

const MUSCLE_HP := 280.0
const MUSCLE_NAMES: Array[String] = ["BIG TONY \"THE FRIDGE\"", "BRUNO", "MEATLOCKER MIKE"]
const MUSCLE_BARKS := {
	"pain": ["Heh. That tickled.", "Watch the suit! It's rented!", "Ow. OW. Okay, now I'm mad."],
	"die": ["Tell the Godmother... I tried...", "Who turned... out... the lights..."],
	"alert": ["The boss says you go out in pieces.", "You and me, pal. Outside. ...We ARE outside? Inside, then.", "Time for your beatin'."],
	"shoot": ["C'mere!", "Hold still!", "HUP!"],
}

var muscle := true


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super._init(w, p_id, p_x, p_z, p_y, o)
	alien = true
	meat = false
	name = MUSCLE_NAMES[p_id % MUSCLE_NAMES.size()]
	bark_set = MUSCLE_BARKS
	speech = true
	mute = false
	voice = 0.48
	max = MUSCLE_HP
	hp = MUSCLE_HP


func update(dt: float, en: Enemies, P: Player) -> void:
	shield_t = maxf(0.0, shield_t - dt)
	super.update(dt, en, P)


func hurt(amount: float, from: Variant, kb: float, pt: Variant, kill: bool) -> void:
	# JS ALIEN.shieldAbsorb: a Consigliere's shield soaks most of a hit, as on a gray
	if shield_t > 0.0 and state != &"dead":
		var back := amount * (1.0 - GrayAlien.SHIELD_TAKE)
		hp += back
		amount -= back
		kb *= 0.2
		if kill and hp > 0.0:
			kill = false
			dead = false
		if E != null:
			E.push({"t": "bolt_hit", "x": x, "y": y + 1.1, "z": z, "kind": "world", "bk": "ring", "nx": 0.0, "ny": 1.0, "nz": 0.0})
	# a HAMMER FIST (bare hands, a hit far heavier than any punch: the dive slam deals up to 62) pops the plate too, like the bellows
	if amount >= 30.0 and not dead and E != null and E.c != null and E.c.weapon == null:
		exposed_t = maxf(exposed_t, GristleBrute.EXPOSED * 0.8)
		E.push({"t": "ring_hit", "x": x, "y": y + 1.5, "z": z})
	super.hurt(amount, from, kb, pt, kill)
