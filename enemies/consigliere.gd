class_name Consigliere
extends Drone
## THE CONSIGLIERE (JS enemies/gray-family.js): a brain in a floating jar. Never fights: it hides behind its family and SHIELDS up to three grays within 9 m (purple tethers, a bubble round each: they take 15 % damage). Fragile: pop the jar and every shield drops.

const CONSIG_HP := 45.0
const RANGE := 9.0
const MAX_SHIELDS := 3

const CONSIG_NAMES: Array[String] = ["CONSIGLIERE CARLO", "THE BRAIN", "UNCLE EINSTEIN"]
const CONSIG_BARKS := {
	"pain": ["My jar! Do you know what a jar like this costs?", "Careful! I am all brains!", "Ow. Ow. Cerebral ow."],
	"die": ["I... should have... seen that... coming...", "Tell the Godmother... my advice... was good..."],
	"alert": ["Boys! Stand close to me. Closer!", "I advise... protecting the family.", "Huddle up, gentlemen. I got you covered."],
	"shoot": ["Stay in my light, Vinny!", "You are covered. Mostly."],
}

var shielded: Array[Robot] = []


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super._init(w, p_id, p_x, p_z, p_y, o)
	name = CONSIG_NAMES[p_id % CONSIG_NAMES.size()]
	bark_set = CONSIG_BARKS
	speech = true
	voice = 0.72
	hover = 3.3
	max = CONSIG_HP
	hp = CONSIG_HP


func reset(first: bool) -> void:
	super.reset(first)
	calls = 99
	shot_cd = 1e9
	shielded = []


func _combat(dt: float, P: Player, dx: float, dz: float, dist: float, _saw: bool) -> void:
	var count := 0
	var cx := 0.0
	var cz := 0.0
	for o: Robot in E.robots:
		if o != self and not o.dead and o.state != &"dead" and o.alien and U.hyp(o.x - x, o.z - z) < 18.0:
			count += 1
			cx += o.x
			cz += o.z
	var tx: float
	var tz: float
	if count > 0:                                    # behind the family: their centre, pushed away from you
		cx /= count
		cz /= count
		var ax := cx - P.x
		var az := cz - P.z
		var al := U.hyp(ax, az)
		if al == 0.0:
			al = 1.0
		tx = cx + ax / al * 3.2
		tz = cz + az / al * 3.2
	else:
		var l := dist if dist != 0.0 else 1.0
		tx = x - dx / l * 4.0
		tz = z - dz / l * 4.0
	var d := U.hyp(tx - x, tz - z)
	_fly(dt, _steer(tx, tz), minf(DRONE.speed * 0.8, d * 1.5), d < 0.5)
	_face(dt, atan2(dx, dz), 4.0)


func update(dt: float, en: Enemies, P: Player) -> void:
	super.update(dt, en, P)
	shielded = []
	if dead or state == &"dead" or en == null:
		return
	var near: Array[Robot] = []
	for o: Robot in en.robots:
		if o != self and not o.dead and o.state != &"dead" and o.alien and U.hyp(o.x - x, o.z - z) < RANGE:
			near.append(o)
	near.sort_custom(func(a: Robot, b: Robot) -> bool: return U.hyp(a.x - x, a.z - z) < U.hyp(b.x - x, b.z - z))
	for i in mini(near.size(), MAX_SHIELDS):
		near[i].shield_t = 0.25
		near[i].shield_by = id
		shielded.append(near[i])
