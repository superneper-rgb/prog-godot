class_name Phoniworm
extends Robot
## DIRGEWORM (id "worm"; was the Phoniworm; JS enemies/phoniworm.js): a segmented lane-denial gut-worm of the Meat Spire.
##   Melee   SLAM: rears up, then hammers its petalled head down in front of it (area hit + shove).
##   Ranged  HOWL: its neck sacs balloon, the head peels open and it screams a fan of 5 pressure rings that shove you back.
##   Grows   EXTEND: every ~13 s it stretches itself 2 segments longer (and slowly grows by itself every ~16 s), up to 22. A longer worm slams further out and harder.
##   It attacks the moment it spawns and never loses interest.
## The JS swaps its numbers into the shared AI table around each update; it holds its own table here, kept current in update().

const WORM_HP := 320.0
const WORM_SPEED := 4.8      # slither speed (m/s)
const WORM_ACCEL := 11.0
const WORM_SEG_START := 9    # body segments when it spawns
const WORM_SEG_MAX := 22
const WORM_GROW_EVERY := 16.0      # seconds between free growth steps (+1 segment)
const WORM_EXTEND_CD := 13.0       # seconds between EXTEND attacks (+WORM_EXTEND_ADD segments)
const WORM_EXTEND_ADD := 2
const WORM_SLAM_WIND := 0.75       # telegraph: rears up
const WORM_SLAM_REC := 0.9
const WORM_SLAM_CD := 1.2
const WORM_SLAM_DMG := 18.0        # +0.6 per segment beyond the starting length
const WORM_SLAM_REACH := 2.6       # how far in front of the head the slam lands (+0.05 per extra segment, max +1)
const WORM_SLAM_RAD := 2.3
const WORM_SLAM_PUSH := 9.0
const WORM_RING_CD := 3.4
const WORM_RING_WIND := 0.6
const WORM_RING_REC := 0.6
const WORM_RING_COUNT := 5         # sound-wave rings per blast (fan)
const WORM_RING_SPREAD := 0.11
const WORM_RING_DMG := 5.0
const WORM_RING_SPEED := 21.0
const WORM_RING_PUSH := 7.0
const WORM_RING_MIN := 4.5
const WORM_RING_MAX := 26.0
const W_R := 0.85
const W_H := 2.2

var segs := WORM_SEG_START
var grow_t := WORM_GROW_EVERY
var extend_cd := 6.0
var ring_cd := 0.0
var slam_cd := 0.0
var weave := 0.0
var oriented := false


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = AiTable.new()
	ai.r = W_R
	ai.h = W_H
	ai.walk = WORM_SPEED * 0.6
	ai.run = WORM_SPEED
	ai.accel = WORM_ACCEL
	ai.alert_delay = 0.1
	ai.flinch = 0.2
	ai.flinch_cd = 0.35
	ai.stagger = 0.6
	ai.stagger_immune = 2.5
	ai.poise_max = 260.0
	super._init(w, p_id, p_x, p_z, p_y, o)
	worm = true
	meat = true
	name = "DIRGEWORM"
	bark_set = {}      # Nonverbal creature: lifecycle and attack events drive creature audio.
	speech = false
	mute = true
	voice = 0.5 + randf() * 0.06
	r = W_R
	h = W_H
	max = WORM_HP
	hp = WORM_HP


func reset(first: bool) -> void:
	super.reset(first)
	segs = WORM_SEG_START
	grow_t = WORM_GROW_EVERY
	extend_cd = 6.0
	ring_cd = 0.0
	slam_cd = 0.0
	weave = randf() * 6.0
	oriented = false


func slam_dist() -> float:
	return WORM_SLAM_REACH + clampf(0.05 * (segs - WORM_SEG_START), 0.0, 1.0)


func slam_dmg() -> float:
	return WORM_SLAM_DMG + 0.6 * maxi(0, segs - WORM_SEG_START)


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	if state != &"dead":
		if P != null:
			# a hunter never stands down: it knows where the player is from the moment it exists
			if not P.dead and (state == &"idle" or state == &"return" or state == &"search"):
				known = Known.at(P.x, P.z)
				seen_t = 0.0
				alert_why = "spawn"
				set_(&"pursue")
			if not oriented and not P.dead:      # spawns already facing you
				oriented = true
				yaw = atan2(P.x - x, P.z - z)
		grow_t -= dt
		if grow_t <= 0.0:
			grow_t = WORM_GROW_EVERY
			if segs < WORM_SEG_MAX:
				segs += 1
				E.push({"t": "worm_grow", "id": id, "x": x, "y": y + 1.2, "z": z, "quiet": true})
	var a := atk
	ai.s_wind = WORM_SLAM_WIND if a == &"slam" else (0.7 if a == &"extend" else WORM_RING_WIND)
	ai.s_act = 0.5 if a == &"slam" else 0.35
	ai.s_rec = WORM_SLAM_REC if a == &"slam" else (0.6 if a == &"extend" else WORM_RING_REC)
	super.update(dt, en, P)


# ---- hunting: weave in, slam up close, ring from afar, extend now and then
func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	known = Known.at(P.x, P.z)      # never loses you
	seen_t = 0.0
	ring_cd -= dt
	slam_cd -= dt
	extend_cd -= dt
	var face_ok := _face_err(P.x, P.z) < 0.45
	_face(dt, atan2(dx, dz), 6.0)
	if not P.dead:
		if slam_cd <= 0.0 and face_ok and dist <= slam_dist() + WORM_SLAM_RAD * 0.7:
			slam_cd = WORM_SLAM_CD
			_begin(&"slam", dist)
			return
		if extend_cd <= 0.0 and segs < WORM_SEG_MAX and dist > 5.0:
			extend_cd = WORM_EXTEND_CD * _rnd(0.9, 1.15)
			_begin(&"extend", dist)
			return
		if sees and ring_cd <= 0.0 and face_ok and dist >= WORM_RING_MIN and dist <= WORM_RING_MAX:
			ring_cd = WORM_RING_CD * _rnd(0.85, 1.3)
			_begin(&"ring", dist)
			return
	var a := atan2(dx, dz) + sin(t * 1.6 + weave) * (0.35 if dist > 6.0 else 0.1)      # slithers side to side
	var speed: float = ai.run * 0.5 if dist < 3.0 else ai.run
	var tx := x + sin(a) * 3.0
	var tz := z + cos(a) * 3.0
	_go(dt, _steer(tx, tz), speed, false)


func _begin(kind: StringName, _dist: float) -> void:
	atk = kind
	hit_done = false
	shot_done = false
	slot = &""
	a_u = 0.0
	set_(&"windup")
	wob = 0.0
	E.push({"t": "robot_atk", "id": id, "kind": kind, "ph": "windup", "x": x, "y": y, "z": z})
	E.barks.say(self, "mind" if kind == &"slam" else ("shoot" if kind == &"ring" else "summon"))


func _attack(dt: float, P: Player, _dx: float, _dz: float, _dist: float) -> void:
	a_u = minf(1.0, state_t / ai.s_act)
	_go(dt, 0.0, 0.0, true)
	if not shot_done and (atk != &"slam" or state_t >= 0.1):      # the slam lands a beat into the swing, once the head is on its way down
		shot_done = true
		if atk == &"slam":
			_slam(P)
		elif atk == &"extend":
			_extend()
		else:
			_ring(P)
	if state_t >= ai.s_act:
		set_(&"recover")


func _slam(P: Player) -> void:
	var f := slam_dist()
	var ix := x + sin(yaw) * f
	var iz := z + cos(yaw) * f
	var hit := false
	if P != null and not P.dead and Vector2(P.x - ix, P.z - iz).length() < WORM_SLAM_RAD and absf(P.y - y) < 1.8:
		hit = E.c.hurt_player(P, slam_dmg(), x, z, "melee")
		if hit:
			var l := Vector2(P.x - x, P.z - z).length()
			if l == 0.0:
				l = 1.0
			P.ix += (P.x - x) / l * WORM_SLAM_PUSH
			P.iz += (P.z - z) / l * WORM_SLAM_PUSH
	E.push({"t": "worm_slam", "id": id, "x": ix, "y": y, "z": iz, "hit": hit, "r": WORM_SLAM_RAD})


func _ring(P: Player) -> void:
	var s := sin(yaw)
	var c := cos(yaw)
	var n := maxi(1, WORM_RING_COUNT)
	var ox := x + s * 1.0
	var oz := z + c * 1.0
	var oy := y + 1.5
	var ddx := P.x - ox
	var ddy := P.y + 1.0 - oy
	var ddz := P.z - oz
	var L := Vector3(ddx, ddy, ddz).length()
	if L == 0.0:
		L = 1.0
	ddx /= L
	ddy /= L
	ddz /= L
	for i in n:
		var a := (i - (n - 1) / 2.0) * WORM_RING_SPREAD
		var ca := cos(a)
		var sa := sin(a)
		E.fire(self, ox, oy, oz, ddx * ca + ddz * sa, ddy, -ddx * sa + ddz * ca, {"kind": "ring", "speed": WORM_RING_SPEED, "dmg": WORM_RING_DMG, "r": 0.5, "push": WORM_RING_PUSH})
	fire_t = 0.3


func _extend() -> void:
	segs = mini(WORM_SEG_MAX, segs + WORM_EXTEND_ADD)
	E.push({"t": "worm_grow", "id": id, "x": x, "y": y + 1.2, "z": z, "quiet": false})
