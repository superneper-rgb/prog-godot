class_name ButtonMan
extends GrayAlien
## THE BUTTON MAN (JS enemies/gray-family.js): a cloaked hitman. Beams in (a shimmer and a click), paints you with a red laser sight for 1.3 s (it tracks, then LOCKS for the last 0.35 s: step aside), fires one heavy round, lingers, cloaks and relocates. A hit while he aims spoils the shot.

const BM_HP := 90.0
const BM_AIM := 1.3
const BM_LOCK := 0.35
const BM_DMG := 18.0
const BM_SPEED := 70.0
const BM_LINGER := 1.2
const BM_CLOAK := 1.1

const BM_NAMES: Array[String] = ["THE BUTTON MAN", "MR. QUIET", "SILENT SAL"]
const BM_BARKS := {
	"pain": ["...", "Tch.", "Hm."],
	"die": ["...Nothing personal.", "Tell them... I was... quiet..."],
	"alert": ["Contract accepted.", "Hold still. This is my job.", "Somebody is paying good money for you."],
	"shoot": ["Click.", "Goodnight.", "Nothing personal."],
}

var bm_ph := &"arrive"
var bm_t := 0.0
var cloaked := false
var laser_on := false
var laser_lock := false
var laser_at := Vector3.ZERO
var spots: Array = []       # the level's perches, [x, y, z]


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super._init(w, p_id, p_x, p_z, p_y, o)
	name = BM_NAMES[p_id % BM_NAMES.size()]
	bark_set = BM_BARKS
	voice = 0.46
	max = BM_HP
	hp = BM_HP


func reset(first: bool) -> void:
	super.reset(first)
	bm_ph = &"arrive"
	bm_t = 0.0
	cloaked = false
	laser_on = false
	mind_cd = 1e9


func update(dt: float, en: Enemies, P: Player) -> void:
	mind_cd = 1e9
	if dead or state == &"dead":
		cloaked = false
		laser_on = false
	super.update(dt, en, P)


func hurt(amount: float, from: Variant, kb: float, pt: Variant, kill: bool) -> void:
	if bm_ph == &"aim":                 # a hit spoils the shot
		bm_ph = &"linger"
		bm_t = 0.5
		laser_on = false
		volley_drop()
	super.hurt(amount, from, kb, pt, kill)


func _spot(P: Player) -> Vector3:
	var W := world
	if not spots.is_empty():            # the level's perches, one away from where he was and in front of you if possible
		var opts: Array = spots.filter(func(s: Array) -> bool: return U.hyp(s[0] - x, s[2] - z) > 3.0 and U.hyp(s[0] - P.x, s[2] - P.z) > 6.0)
		var from: Array = opts if not opts.is_empty() else spots
		var s: Array = from[randi() % from.size()]
		return Vector3(s[0], s[1], s[2])
	for _k in 12:
		var a := randf() * TAU
		var d := 10.0 + randf() * 8.0
		var px := P.x + sin(a) * d
		var pz := P.z + cos(a) * d
		var py := W.ground_height(px, pz, 0.5, P.y + 4.0)
		if is_finite(py) and absf(py - P.y) < 6.0 and not W.blocked(px, pz, py, 1.6, 0.45, 0.3):
			return Vector3(px, py, pz)
	return Vector3(x, y, z)


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	bm_t += dt
	if bm_ph == &"cloak":
		cloaked = true
		laser_on = false
		_go(dt, 0.0, 0.0, true)
		if bm_t > BM_CLOAK:
			var s := _spot(P)
			x = s.x
			y = s.y
			z = s.z
			vx = 0.0
			vz = 0.0
			bm_ph = &"arrive"
			bm_t = 0.0
			E.push({"t": "summon", "x": x, "y": y + 1.0, "z": z})
		return
	cloaked = false
	_go(dt, 0.0, 0.0, true)
	_face(dt, atan2(dx, dz), 10.0)
	if bm_ph == &"arrive":
		if bm_t > 0.6:
			bm_ph = &"wait"
			bm_t = 0.0
		return
	if bm_ph == &"wait":
		if sees and not P.dead and dist > 5.0 and dist < 42.0 and on_screen() and volley_free() and CreatureGameplay.can_attack(self, &"shot"):
			bm_ph = &"aim"
			bm_t = 0.0
			volley_take(BM_AIM + 1.0)
			CreatureGameplay.claim_attack(self)
			E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "windup", "x": x, "y": y, "z": z})
			if randf() < 0.5:
				E.barks.say(self, "shoot")
		elif bm_t > 4.5:
			bm_ph = &"cloak"
			bm_t = 0.0
		return
	if bm_ph == &"aim":
		var lock := bm_t > BM_AIM - BM_LOCK
		laser_on = true
		laser_lock = lock
		if not lock:
			laser_at = Vector3(P.x, P.y + 1.15, P.z)
		volley_take(1.0)
		if bm_t >= BM_AIM:
			var s := sin(yaw)
			var c := cos(yaw)
			var o := Vector3(x + s * 0.8 - c * 0.2, y + 1.05, z + c * 0.8 + s * 0.2)
			var d := laser_at - o
			var L := d.length()
			if L == 0.0:
				L = 1.0
			E.fire(self, o.x, o.y, o.z, d.x / L, d.y / L, d.z / L, {"kind": "plasma", "speed": BM_SPEED, "dmg": BM_DMG, "r": 0.14})
			fire_t = 0.14
			laser_on = false
			bm_ph = &"linger"
			bm_t = 0.0
			volley_drop()
		return
	if bm_ph == &"linger" and bm_t > BM_LINGER:
		bm_ph = &"cloak"
		bm_t = 0.0
