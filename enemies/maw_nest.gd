class_name MawNest
extends Robot
## MAW NEST (JS enemies/maw-nest.js): a brood caller with torn, screaming airways.
##   Melee    TONGUE WHIP: a mass of tongues lashes out of its mouth (damage + yanks you toward it).
##   Ranged   SPIT DARTS: spits a fan of 3 barbed meat darts.
##   Support  CALL FOR HELP: rears up, bloats its throat and screams; alerts every enemy nearby.
##   It attacks the moment it spawns and never loses interest.

const HP := 240.0
const SPEED := 5.4              # skitter speed (m/s)
const ACCEL := 12.0
const HOLD := 5.5               # it likes to hold this distance (m), skittering sideways, and dives in for tongue whips
const WHIP_REACH := 4.2         # tongue reach (m)
const WHIP_WIND := 0.45
const WHIP_REC := 0.55
const WHIP_CD := 0.9
const WHIP_DMG := 14.0
const WHIP_PULL := 6.0          # m/s yank toward it when a whip lands
const DART_CD := 2.2
const DART_WIND := 0.5
const DART_REC := 0.5
const DART_COUNT := 3           # envelopes per spit (fan)
const DART_SPREAD := 0.13
const DART_DMG := 6.0
const DART_SPEED := 17.0
const DART_MIN := 4.5
const DART_MAX := 26.0
const CALL_CD := 16.0
const CALL_WIND := 1.0
const CALL_REC := 0.7
const MAX_HELPERS := 4
const FIRST_CALL := 7.0         # seconds after spawning before the first call for help
const S_R := 0.9
const S_H := 1.9

var scream := true
var dart_cd := 0.0
var whip_cd := 0.0
var call_cd := 0.0
var strafe_dir := 1.0
var strafe_t := 0.0
var oriented := false


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = S_R
	ai.h = S_H
	ai.walk = SPEED * 0.6
	ai.run = SPEED
	ai.accel = ACCEL
	ai.alert_delay = 0.08
	ai.flinch = 0.18
	ai.flinch_cd = 0.3
	ai.stagger = 0.55
	ai.stagger_immune = 2.2
	ai.poise_max = 160.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	name = "MAWNEST"
	bark_set = {}
	speech = false
	mute = true
	voice = 0.85 + randf() * 0.1
	r = S_R
	h = S_H
	max = HP
	hp = HP


func reset(first: bool) -> void:
	super.reset(first)
	dart_cd = 0.0
	whip_cd = 0.0
	call_cd = FIRST_CALL
	strafe_dir = -1.0 if randf() < 0.5 else 1.0
	strafe_t = _rnd(1.2, 2.8)
	oriented = false
	fire_t = 0.0


func helpers() -> int:
	var n := 0
	for o: Robot in E.robots:
		if o.owner == self and not o.dead:
			n += 1
	return n


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	if state != &"dead" and P != null:
		if not P.dead and (state == &"idle" or state == &"return" or state == &"search"):      # a hunter never stands down: it knows where the player is from the moment it exists
			known = Known.at(P.x, P.z)
			seen_t = 0.0
			alert_why = "spawn"
			set_(&"pursue")
		if not oriented and not P.dead:                                                       # spawns already facing you
			oriented = true
			yaw = atan2(P.x - x, P.z - z)
	fire_t = maxf(0.0, fire_t - dt)
	dart_cd -= dt                                                                             # cool-downs tick through every state
	whip_cd -= dt
	call_cd -= dt
	var a := atk
	ai.s_wind = WHIP_WIND if a == &"whip" else (CALL_WIND if a == &"call" else DART_WIND)
	ai.s_act = 0.4 if a == &"call" else 0.35
	ai.s_rec = WHIP_REC if a == &"whip" else (CALL_REC if a == &"call" else DART_REC)
	super.update(dt, en, P)


# ---- hunting: skitter around at mid range, spit darts, dive in to whip, call for help now and then ----
func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	known = Known.at(P.x, P.z)                                                                # never loses you
	seen_t = 0.0
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_dir = -strafe_dir
		strafe_t = _rnd(1.2, 3.0)
	var face_ok := _face_err(P.x, P.z) < 0.5
	_face(dt, atan2(dx, dz), 8.0)
	if not P.dead:
		if call_cd <= 0.0 and sees and helpers() < MAX_HELPERS:
			call_cd = CALL_CD * _rnd(0.9, 1.15)
			_begin(&"call", dist)
			return
		if whip_cd <= 0.0 and face_ok and dist <= WHIP_REACH:
			whip_cd = WHIP_CD * _rnd(0.9, 1.3)
			_begin(&"whip", dist)
			return
		if sees and dart_cd <= 0.0 and face_ok and dist >= DART_MIN and dist <= DART_MAX:
			dart_cd = DART_CD * _rnd(0.8, 1.3)
			_begin(&"dart", dist)
			return
	# movement: close the gap when far, dive in when the whip is ready, otherwise circle at the hold distance
	var base := atan2(dx, dz)
	var tx := P.x
	var tz := P.z
	if sees and dist < HOLD * 1.4 and not (whip_cd <= 0.3 and dist < HOLD * 1.4):
		var perp := base + strafe_dir * PI / 2.0
		var rad := -0.8 if dist < HOLD - 1.2 else (0.8 if dist > HOLD + 1.2 else 0.1)
		tx = x + (sin(perp) + sin(base) * rad) * 3.0
		tz = z + (cos(perp) + cos(base) * rad) * 3.0
	_go(dt, _steer(tx, tz), ai.run, dist < 1.8)


func _begin(kind: StringName, _dist: float) -> void:
	atk = kind
	hit_done = false
	shot_done = false
	slot = &""
	a_u = 0.0
	set_(&"windup")
	wob = 0.0
	E.push({"t": "robot_atk", "id": id, "kind": String(kind), "ph": "windup", "x": x, "y": y, "z": z})
	E.barks.say(self, "mind" if kind == &"whip" else ("shoot" if kind == &"dart" else "summon"))


func _attack(dt: float, P: Player, _dx: float, _dz: float, dist: float) -> void:
	a_u = minf(1.0, state_t / ai.s_act)
	_go(dt, 0.0, 0.0, true)
	if not shot_done and (atk != &"whip" or state_t >= 0.08):
		shot_done = true
		if atk == &"whip":
			_whip(P, dist)
		elif atk == &"call":
			_call()
		else:
			_dart(P)
	if state_t >= ai.s_act:
		set_(&"recover")


func _whip(P: Player, dist: float) -> void:
	var hit := false
	var face := absf(U.wrap_angle(atan2(P.x - x, P.z - z) - yaw))
	if not P.dead and dist <= WHIP_REACH + Config.radius and face < 0.95 and absf(P.y - y) < 1.8:
		hit = E.c.hurt_player(P, WHIP_DMG, x, z, "melee")
		if hit:      # yanked toward the mouth
			var l := U.hyp(P.x - x, P.z - z)
			if l == 0.0:
				l = 1.0
			P.ix -= (P.x - x) / l * WHIP_PULL
			P.iz -= (P.z - z) / l * WHIP_PULL
	E.push({"t": "tongue_lash", "id": id, "x": x + sin(yaw) * 2.2, "y": y + 1.1, "z": z + cos(yaw) * 2.2, "hit": hit})


func _dart(P: Player) -> void:
	var s := sin(yaw)
	var c := cos(yaw)
	var n := maxi(1, DART_COUNT)
	var o := Vector3(x + s * 1.3, y + 1.75, z + c * 1.3)
	var d := Vector3(P.x - o.x, P.y + 1.0 - o.y, P.z - o.z)
	var L := d.length()
	if L == 0.0:
		L = 1.0
	d /= L
	for i in n:
		var a := (i - (n - 1) / 2.0) * DART_SPREAD
		var ca := cos(a)
		var sa := sin(a)
		E.fire(self, o.x, o.y, o.z, d.x * ca + d.z * sa, d.y, -d.x * sa + d.z * ca, {"kind": "dart", "speed": DART_SPEED, "dmg": DART_DMG, "r": 0.3})
	fire_t = 0.3


func _call() -> void:
	E.push({"t": "scream_call", "id": id, "x": x, "y": y + 1.4, "z": z})
	E.broadcast(self, false)      # everything nearby is alerted; the MawNest only calls, it no longer spawns robots
