class_name Prophet
extends Robot
## FLAYED PROPHET (id 'prophet'; JS enemies/meatball-prophet.js): a hovering flayed summoner of the Meat Spire.
##   Ranged    hovers on a ring around you and flings fans of blood globs (3 red globs, slow enough to dodge; the projectile kind is still 'sauce').
##   Summons   every ~11 s it stops, throws its arms wide and births up to 2 brood (skinless finger-legged followers that rush you and bite); max 4 alive.
##   Explodes  when it dies it swells for 0.7 s and bursts: blood, meat chunks and area damage + shove to the player; its brood die with it.
##   He attacks the moment he spawns (first sauce blast in ~0.3 s) and never loses interest.

const HP := 260.0
const SPEED := 3.4             # hover speed (m/s)
const ACCEL := 9.0
const RING_MIN := 7.0          # backs away when you are closer than this ...
const RING_MAX := 13.0         # ... and drifts in when you are further than this
const BLAST_MAX := 28.0
const BLAST_CD := 1.5          # seconds between sauce volleys
const BLAST_WIND := 0.5        # telegraph
const BLAST_REC := 0.45
const BLAST_COUNT := 3         # globs per volley (fan)
const BLAST_SPREAD := 0.14     # radians between globs
const BLAST_DMG := 7.0
const BLAST_SPEED := 16.0
const SUMMON_CD := 11.0
const SUMMON_WIND := 1.0
const SUMMON_REC := 0.8
const SUMMON_COUNT := 2
const MAX_FOLLOWERS := 4
const BOOM_DELAY := 0.7        # swell time after death before the burst
const BOOM_RADIUS := 4.5
const BOOM_DMG := 30.0         # at the centre, falls off with distance
const BOOM_PUSH := 13.0
const P_R := 0.6
const P_H := 1.9
const F_R := 0.28
const F_H := 0.6

var prophet := true
var boom_t := 0.0
var boomed := false
var blast_cd := 0.0
var summon_cd := 5.0
var strafe_dir := 1.0
var strafe_t := 0.0
var summon_t := 0.0
var oriented := false


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = P_R
	ai.h = P_H
	ai.walk = SPEED * 0.6
	ai.run = SPEED
	ai.accel = ACCEL
	ai.alert_delay = 0.12
	ai.s_act = 0.2
	ai.flinch = 0.2
	ai.flinch_cd = 0.3
	ai.stagger = 0.6
	ai.stagger_immune = 2.5
	ai.poise_max = 200.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	meat = true
	name = "FLAYED PROPHET"
	bark_set = {}
	speech = false
	mute = true
	voice = 0.4 + randf() * 0.08
	r = P_R
	h = P_H
	max = HP
	hp = HP


func reset(first: bool) -> void:
	super.reset(first)
	boom_t = 0.0
	boomed = false
	blast_cd = 0.0
	summon_cd = 5.0
	strafe_dir = -1.0 if randf() < 0.5 else 1.0
	strafe_t = _rnd(2.0, 4.0)
	fire_t = 0.0
	summon_t = 0.0
	aim = 0.0
	oriented = false


func followers() -> int:
	var n := 0
	for o: Robot in E.robots:
		if o.owner == self and not o.dead:
			n += 1
	return n


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	fire_t = maxf(0.0, fire_t - dt)
	summon_t = maxf(0.0, summon_t - dt)
	if state == &"dead":
		if not boomed:      # death swell, then BOOM
			boom_t -= dt
			if boom_t <= 0.0:
				_explode(P)
	elif P != null:
		if not P.dead and (state == &"idle" or state == &"return" or state == &"search"):      # a hunter never stands down
			known = Known.at(P.x, P.z)
			seen_t = 0.0
			alert_why = "spawn"
			set_(&"pursue")
		if not oriented and not P.dead:
			_face(dt, atan2(P.x - x, P.z - z), 4.0)
			if _face_err(P.x, P.z) < 0.1:
				oriented = true
	ai.s_wind = SUMMON_WIND if atk == &"summon" else BLAST_WIND
	ai.s_rec = SUMMON_REC if atk == &"summon" else BLAST_REC
	super.update(dt, en, P)


func _die() -> void:
	super._die()
	boom_t = BOOM_DELAY
	boomed = false
	respawn_t = maxf(respawn_t, BOOM_DELAY + 20.0)


func _explode(P: Player) -> void:
	boomed = true
	E.push({"t": "meat_boom", "id": id, "x": x, "y": y + 1.2, "z": z, "r": BOOM_RADIUS, "big": true})
	for o: Robot in E.robots:      # the flock goes with him
		if o.owner == self and not o.dead:
			E.c.damage(o, 1e4, self, 0.0, null)
	if P != null and not P.dead:
		var dx := P.x - x
		var dz := P.z - z
		var dv := (P.y + 1.0 - (y + 1.2)) * 0.5
		var d := sqrt(dx * dx + dz * dz + dv * dv)
		var l := U.hyp(dx, dz)
		if l == 0.0:
			l = 1.0
		if d < BOOM_RADIUS:
			var k := 1.0 - 0.7 * d / BOOM_RADIUS
			if E.c.hurt_player(P, BOOM_DMG * k, x, z, "bolt"):
				P.ix += dx / l * BOOM_PUSH * k
				P.iz += dz / l * BOOM_PUSH * k


# ---- hunting: hover on a ring, blast, summon ----
func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	known = Known.at(P.x, P.z)      # never loses you
	seen_t = 0.0
	blast_cd -= dt
	summon_cd -= dt
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_dir = -strafe_dir
		strafe_t = _rnd(2.0, 4.5)
	var face_ok := _face_err(P.x, P.z) < 0.4
	_face(dt, atan2(dx, dz), 6.0)
	if not P.dead:
		if summon_cd <= 0.0 and MAX_FOLLOWERS > 0 and followers() < MAX_FOLLOWERS:
			summon_cd = SUMMON_CD * _rnd(0.9, 1.2)
			_begin(&"summon", dist)
			return
		if sees and blast_cd <= 0.0 and face_ok and dist >= 2.5 and dist <= BLAST_MAX:
			blast_cd = BLAST_CD * _rnd(0.8, 1.3)
			_begin(&"shot", dist)
			return
	var tx := P.x
	var tz := P.z
	var speed: float = ai.run
	if sees:
		var base := atan2(dx, dz)
		var perp := base + strafe_dir * PI / 2.0
		var rad := -1.0 if dist < RING_MIN else (1.0 if dist > RING_MAX else 0.0)
		tx = x + (sin(perp) * 0.6 + sin(base) * rad) * 3.0
		tz = z + (cos(perp) * 0.6 + cos(base) * rad) * 3.0
		if rad == 0.0:
			speed *= 0.6
	_go(dt, _steer(tx, tz), speed, false)


func _begin(kind: StringName, _dist: float) -> void:
	atk = kind
	hit_done = false
	shot_done = false
	slot = &""
	a_u = 0.0
	set_(&"windup")
	wob = 0.0
	E.push({"t": "robot_atk", "id": id, "kind": "summon" if kind == &"summon" else "sauce", "ph": "windup", "x": x, "y": y, "z": z})
	E.barks.say(self, "summon" if kind == &"summon" else ("shoot" if randf() < 0.5 else "alert"))
	if kind == &"summon":
		summon_t = SUMMON_WIND + 0.3


func _attack(dt: float, P: Player, _dx: float, _dz: float, _dist: float) -> void:
	a_u = minf(1.0, state_t / ai.s_act)
	_go(dt, 0.0, 0.0, true)
	if not shot_done:
		shot_done = true
		if atk == &"summon":
			_summon()
		else:
			_volley(P)
	if state_t >= ai.s_act:
		set_(&"recover")


func _volley(P: Player) -> void:
	var s := sin(yaw)
	var c := cos(yaw)
	var n := maxi(1, BLAST_COUNT)
	var o := Vector3(x + s * 0.8 + c * 0.62, y + 1.2, z + c * 0.8 - s * 0.62)      # the pale (left, +x) hand
	var d := Vector3(P.x - o.x, P.y + 1.0 - o.y, P.z - o.z)
	var L := d.length()
	if L == 0.0:
		L = 1.0
	d /= L
	for i in n:
		var a := (i - (n - 1) / 2.0) * BLAST_SPREAD
		var ca := cos(a)
		var sa := sin(a)
		E.fire(self, o.x, o.y, o.z, d.x * ca + d.z * sa, d.y, -d.x * sa + d.z * ca, {"kind": "sauce", "speed": BLAST_SPEED, "dmg": BLAST_DMG, "r": 0.3})
	fire_t = 0.25


func _summon() -> void:
	if not E.spawn_hook.is_valid():
		return
	var want := mini(SUMMON_COUNT, MAX_FOLLOWERS - followers())
	for i in want:
		var placed := false
		var tries := 0
		while tries < 8 and not placed:
			var a := yaw + (1.0 if i % 2 == 1 else -1.0) * (0.9 + tries * 0.45) + _rnd(-0.2, 0.2)
			var px := x + sin(a) * 1.5
			var pz := z + cos(a) * 1.5
			var floor_y := world.ground_height(px, pz, F_R, y + 0.4)
			if absf(floor_y - y) < 0.6 and not world.blocked(px, pz, floor_y, F_H, F_R, 0.4):
				E.spawn_hook.call({"x": px, "y": floor_y, "z": pz, "yaw": yaw}, {"kind": "follower", "owner": self})
				E.push({"t": "summon", "x": px, "y": floor_y + 0.3, "z": pz})
				placed = true
			tries += 1
