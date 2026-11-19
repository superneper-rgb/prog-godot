class_name AutoAim
extends RefCounted
## Hip-fire auto-aim: picks the enemy the crosshair is nearest to inside a cone that is wide close up and narrow far away, and holds it.
## Combat aims the shot at the lock's centre; the HUD slides the reticle onto it. ADS, the scope and set pieces stay free aim (Combat decides).
## The idea is a shooter-platformer aim cone: a box cone (yaw and pitch tested apart) whose half-angles ease from near to far with
## 1 - (1 - d/R)^3, a score led by yaw error, a line-of-sight ray only for a candidate that would win, and a short dwell before switching.

var lock: Target = null       # the enemy shots go to (null = free aim)
var aim := Vector3.ZERO       # the lock's aim point this frame
var dist := 0.0               # metres from the cone's origin to `aim`

var _cand: Target = null      # the best enemy that is not the lock, and how long it has stayed best
var _cand_t := 0.0
var _best: Target = null      # per-frame scratch of pick()
var _best_aim := Vector3.ZERO
var _best_d := 0.0


## Drops the lock (weapon away, ADS, set piece, dead...).
func clear() -> void:
	lock = null
	_cand = null
	_cand_t = 0.0


## One frame. o = cone origin (his chest), (dx, dy, dz) = the crosshair direction (unit), rng = the gun's reach,
## under = the target the crosshair ray already hits (or null): pointing straight at an enemy always takes it at once.
func step(dt: float, world: World, targets: Array[Target], o: Vector3, dx: float, dy: float, dz: float, rng: float, under: Target) -> void:
	var C := Config
	if C.auto_aim == 0 or rng <= 0.0:
		clear()
		return
	if under != null and eligible(under):
		_take(under, o)
		return
	var yaw0 := atan2(dx, dz)
	var pitch0 := asin(clampf(dy, -1.0, 1.0))
	var near_y := deg_to_rad(C.aim_cone_near_yaw)
	var near_p := deg_to_rad(C.aim_cone_near_pitch)
	var far_a := deg_to_rad(C.aim_cone_far)
	# is the current lock still inside the cone and in sight? (it keeps its place until something else has been better for the dwell)
	var lock_ok := false
	var lock_score := INF
	if lock != null and eligible(lock):
		var ls := _score(lock, o, yaw0, pitch0, rng, near_y, near_p, far_a)
		if ls < INF and _clear(world, o, lock):
			lock_ok = true
			lock_score = ls
	# the best candidate; the sight ray is only cast for one that would win
	_best = null
	var best_s := INF
	var r2 := rng * rng
	for T: Target in targets:
		if T == lock or not eligible(T):
			continue
		var ex := T.x - o.x
		var ez := T.z - o.z
		if ex * ex + ez * ez > r2:
			continue
		var s := _score(T, o, yaw0, pitch0, rng, near_y, near_p, far_a)
		if s < best_s and s < lock_score and _clear(world, o, T):
			best_s = s
			_best = T
	if not lock_ok:
		_cand = null
		_cand_t = 0.0
		if _best != null:
			_take(_best, o)
		else:
			lock = null
		return
	if _best == null:
		_cand = null
		_cand_t = 0.0
	elif _best == _cand:
		_cand_t += dt
		if _cand_t >= C.aim_lock_dwell:
			_take(_best, o)
			return
	else:
		_cand = _best
		_cand_t = 0.0
	_take(lock, o)


## Something auto-aim may lock: a live enemy (robots, bosses, practice dummies), never an NPC, a crowd member or an ally clone.
static func eligible(T: Target) -> bool:
	return not T.dead and not T.npc and not T.crowd and not T.shattered and T.actor_state == null and T.hp > 0.0


## Where shots at T go: its middle (a boss's centre of mass, a robot's chest).
static func aim_point(T: Target) -> Vector3:
	return Vector3(T.x, T.y + T.h * 0.55, T.z)


func _take(T: Target, o: Vector3) -> void:
	if T != lock:
		_cand = null
		_cand_t = 0.0
	lock = T
	aim = aim_point(T)
	dist = o.distance_to(aim)


## Lower is better; INF = outside the cone or the range. Yaw error leads (3 per radian), then pitch error and distance.
## The cone's half-angles ease from near to far with distance, plus the angle the target's own radius covers (a boss is easier to hold).
func _score(T: Target, o: Vector3, yaw0: float, pitch0: float, rng: float, near_y: float, near_p: float, far_a: float) -> float:
	var c := aim_point(T)
	var ex := c.x - o.x
	var ey := c.y - o.y
	var ez := c.z - o.z
	var hd := sqrt(ex * ex + ez * ez)
	var d := sqrt(hd * hd + ey * ey)
	if d < 0.3 or d > rng:
		return INF
	var ye := absf(U.wrap_angle(atan2(ex, ez) - yaw0))
	var pe := absf(atan2(ey, hd) - pitch0)
	var u := 1.0 - d / rng
	var f := 1.0 - u * u * u
	var body := atan2(T.r, d)
	if ye > lerpf(near_y, far_a, f) + body or pe > lerpf(near_p, far_a, f) + body:
		return INF
	return 3.0 * ye + 0.2 * pe * d + 0.1 * d


## A clear line from o to T's aim point (walls only: other enemies do not block a lock).
func _clear(world: World, o: Vector3, T: Target) -> bool:
	var c := aim_point(T)
	var v := c - o
	var d := v.length()
	if d < 0.01:
		return true
	v /= d
	var hit := world.ray_clear(o.x, o.y, o.z, v.x, v.y, v.z, d, 0.01)
	return hit >= d - T.r - 0.15
