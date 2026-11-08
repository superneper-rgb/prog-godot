class_name PlasmidCatalog
extends RefCounted
## PLASMIDS (JS powers/plasmid-catalog.js): the catalogue shared by the DORBATELEPHINIUM IMPLANTS vending machine and its menu. SWARM, INCINERATE and FROST are implemented; the rest are `available: false` placeholders the menu cannot sell yet.
## Entry: id, name, tag, color (0xRRGGBB, the vial / menu accent), price (null = not for sale yet), available, mana (cost per cast; the minimum for a charged power), mana_max (charged powers: cost at a full charge), drain (channelled powers: mana per second while held), desc, icon (SVG paths).

const PLASMIDS: Array[Dictionary] = [
	{"id": "grasp", "name": "GRASP", "tag": "KINETIC IMPLANT", "color": 0xff3b30, "price": null, "available": false,
		"icon": ["M34 54V34h32v20z", "M38 34V16M46 34V10M54 34V10M62 34V16", "M34 42l-10-8"]},
	{"id": "shock", "name": "SHOCK", "tag": "ELECTRIC IMPLANT", "color": 0x3a8dff, "price": null, "available": false,
		"icon": ["M58 4L34 34h14l-6 22 26-32H54z"]},
	# powers/fireball.gd: tap for a small fireball (mana), hold to grow it; the cost rises with the charge up to mana_max
	{"id": "incinerate", "name": "INCINERATE", "tag": "THERMAL IMPLANT", "color": 0xff8a1f, "price": 2000, "available": true, "mana": 15.0, "mana_max": 45.0,
		"desc": "Burners threaded through the left palm. Tap to throw a fireball. Hold to feed it: the ball swells and burns hotter until you let go, and a charged one bursts on impact, burning everything around it. Bigger balls drink more mana.",
		"icon": ["M50 4c3 10 18 16 18 32a18 18 0 0 1-36 0c0-9 5-13 8-21 4 4 7 8 7 13 2-8 2-16 3-24z"]},
	{"id": "vortex", "name": "VORTEX", "tag": "GRAVITIC IMPLANT", "color": 0xa65bff, "price": null, "available": false,
		"icon": ["M50 30a4 4 0 1 1 4 4 8 8 0 1 1-12-6 12 12 0 1 1 20 12 16 16 0 1 1-24-20"]},
	# the first working power: powers/wasp_swarm.gd (mana = cost per cast)
	{"id": "swarm", "name": "SWARM", "tag": "LIVING IMPLANT", "color": 0x58d94a, "price": 1500, "available": true, "mana": 30.0,
		"desc": "A hive grown into the left forearm. Point and release: the swarm covers the nearest enemy and stings until it drops, then hunts down the next one. The swarm lives about ten seconds.",
		"icon": ["M50 22l5-10 4 9 18-9-4 18-10 6-5 14-8-14-10-6-4-18 18 9 4-9z"]},
	# powers/frost.gd: hold to spray (drain = mana per second, mana = the minimum to start); chills, then freezes; punch a frozen enemy to shatter it
	{"id": "frost", "name": "FROST", "tag": "CRYO IMPLANT", "color": 0x39d6e8, "price": 1800, "available": true, "mana": 5.0, "drain": 20.0,
		"desc": "Coolant lines run down the left arm. Hold to spray a cone of freezing mist: enemies in it slow down, and if you keep it on them they freeze solid. A punch or hammer fist shatters a frozen enemy outright. Drains mana for as long as you spray.",
		"icon": ["M50 4v52M26 17l48 26M26 43l48-26", "M42 8l8 6 8-6M42 52l8-6 8 6"]},
	{"id": "mend", "name": "MEND", "tag": "VITAL IMPLANT", "color": 0xf5d442, "price": null, "available": false,
		"icon": ["M50 54S20 38 20 20a15 15 0 0 1 30-4 15 15 0 0 1 30 4c0 18-30 34-30 34z"]},
	{"id": "surge", "name": "SURGE", "tag": "ENERGY IMPLANT", "color": 0xff4fb8, "price": null, "available": false,
		"icon": ["M50 30m-21 0a21 21 0 1 0 42 0 21 21 0 1 0-42 0", "M50 6v48M26 30h48"]},
	{"id": "focus", "name": "FOCUS", "tag": "TARGETING IMPLANT", "color": 0xff9a2e, "price": null, "available": false,
		"icon": ["M50 30m-16 0a16 16 0 1 0 32 0 16 16 0 1 0-32 0", "M50 4v16M50 40v16M22 30h16M62 30h16"]},
	{"id": "insight", "name": "INSIGHT", "tag": "SENSORY IMPLANT", "color": 0x9b59ff, "price": null, "available": false,
		"icon": ["M8 30q42-34 84 0q-42 34-84 0z", "M50 30m-9 0a9 9 0 1 0 18 0 9 9 0 1 0-18 0"]},
	{"id": "brute", "name": "BRUTE", "tag": "MUSCULAR IMPLANT", "color": 0x6fe35a, "price": null, "available": false,
		"icon": ["M50 4l30 14v22L50 56 20 40V18z", "M50 14v32M36 26h28"]},
	{"id": "stasis", "name": "STASIS", "tag": "TEMPORAL IMPLANT", "color": 0x3c7bd9, "price": null, "available": false,
		"icon": ["M50 30m-23 0a23 23 0 1 0 46 0 23 23 0 1 0-46 0", "M50 14v16l12 8"]},
]


static func by_id(id: String) -> Variant:
	for p: Dictionary in PLASMIDS:
		if p["id"] == id:
			return p
	return null
