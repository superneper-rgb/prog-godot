class_name RaceCar
extends RefCounted
## One Overcurrent racing craft as a rigid body on four hover pads (levels/sky_sphere/). Springs and dampers hold the pads off the deck; each
## pad's grip follows a slip-angle curve and the load on it, so the weight moves under braking, throttle and turns, it slides when pushed past
## the limit, and it really flies off a jump. Walls push back with an impulse at the corner that hit them. A wreck is the same body with no grip,
## tumbling. Replaces the old track-locked ride (user, 2026-11-18: "feels way too much like its on an automatic track ... handle like a proper
## car not some floaty shit"). Pure simulation: sky_race.gd draws it.
## Units: metres, seconds, mass 1 (a force is an acceleration). Frame: basis columns x left, y up, z forward (as CityCars.CarModel). pos is the
## centre of mass; the model's root sits RIDE below it.

const G := 24.0                 # heavier than Earth: jumps land and the car sits down hard (as vehicles.gd's 26)
const RIDE := 0.45              # centre of mass above the pads' plane
const PAD_REST := 0.66          # suspension length: pad to deck at full extension
const SPRING := 36.0            # per pad (whole car: ~1.9 Hz)
const SPRING_SAG := G / (SPRING * 4.0)
const DAMP := 3.4               # per pad (about 0.6 of critical)
const BUMP_AT := 0.42           # compression where the bump stop starts
const BUMP := 420.0
const ANTI_ROLL := 26.0         # per unit of left-right compression difference, per axle
const ROLL_CENTRE := 0.75       # the side forces act this share of the way up from the pads to the centre of mass (a low roll moment, as a real car's roll centre and bars give)
const MIN_GAP := 0.1            # nothing gets a pad closer than this to the deck
const MU := 2.05                # (was 1.18: the craft needed 100 km/h for a 30 m hairpin. The magnetic decks, at 3.1, were what the user called almost perfect)
const PEAK_F := 0.16            # slip angle of most grip, rad
const PEAK_R := 0.13
const SLIDE := 0.72             # grip left when sliding well past the peak
const REAR_GRIP := 1.06         # the rear holds a little more than the front: it pushes before it spins (vehicles.gd's rear_grip)
const DRIFT_CARVE := 10.0       # m/s^2 the line bends toward the inside of a drift, plus DRIFT_TIGHT times how hard the stick is into it
const DRIFT_TIGHT := 11.0
const STAB := 7.0               # yaw torque per radian of slide past STAB_FROM that turns the nose back toward where the craft is going (not in a drift)
const STAB_FROM := 0.22         # (a real slide only: from 0.06 it fought every ordinary corner)
const DOWNFORCE := 0.0052       # per (m/s)^2: the deck pulls a fast craft down (more grip at speed)
const DRAG := 0.00034
const ROLLING := 0.9
const V_TOP := 82.0             # 295 km/h
const V_BOOST := 113.0          # 407 km/h
const ACCEL := 27.0
const ACCEL_BOOST := 24.0
const BRAKE := 58.0
const V_REVERSE := 16.0
const STEER_LOW := 0.56
const STEER_HIGH := 0.16
const ASSIST := 0.5
const MAG_MIN := 16.0           # slower than this a magnetic deck lets go
const HANDBRAKE := 16.0         # m/s^2 the e-brake (drift button) takes off through the rear pads, which lose most of their side grip
const WALL_E := 0.06            # walls barely bounce: a glancing hit slides you along them
const WALL_MU := 0.12
const WALL_REACH := 6.0         # a wall stops a craft up to this high over the deck (an invisible barrier over the drawn one: boosted off The Drop, craft sailed over a corner's wall)
const WALL_ALIGN := 6.0         # yaw a wall contact gives toward running along it (rad/s per unit of nose-into-wall)
const INERTIA := Vector3(1.55, 1.55, 0.8)    # about x (pitch), y (yaw), z (roll)
const MAG_GRIP := 1.5           # ... and holds its line: in a fast roll a craft off the centre must be swung round the twist, which tyres alone cannot do


class Controls:
	var throttle := 0.0
	var brake := 0.0
	var steer := 0.0          # -1..1, + left
	var drift := false
	var boost := false
	var aftertouch := Vector2.ZERO    # a wreck being steered (x: + left, y: + forward)


## What happened to this car in a step, for the race to score and show.
class Hit:
	var kind := 0             # WALL, CAR, FLOOR
	var speed := 0.0          # closing speed along the normal
	var at := Vector3.ZERO
	var normal := Vector3.UP
	var other: RaceCar = null

const WALL := 0
const CAR := 1
const FLOOR := 2

# tuning per craft (sky_race.gd sets these)
var mass := 1.0
var top := V_TOP
var accel := ACCEL
var grip := 1.0
var half := Vector3(1.0, 0.6, 1.95)     # the body's half extents for walls and other craft
var pads: Array[Vector3] = []

# state
var pos := Vector3.ZERO
var basis := Basis.IDENTITY
var vel := Vector3.ZERO
var spin := Vector3.ZERO
var held := true                   # on the grid: does not move
var path := SkyCourse.MAIN
var index := 0
var road := Transform3D.IDENTITY   # the road frame at index
var local := Vector3.ZERO          # pos in that frame
var on_road := true                # within the deck's width (or close above it)
var grounded := false
var pads_down := 0
var air := 0.0                     # seconds with no pad down
var last_air := 0.0                # how long the last flight was (read on landing)
var compress: Array[float] = [0.0, 0.0, 0.0, 0.0]
var steer := 0.0                   # the front pads' angle, rad
var slip := 0.0                    # the body's slip angle, rad (+ the velocity points left of the nose)
var speed := 0.0                   # along the nose
var drifting := false
var drift_dir := 0.0
var drift_charge := 0.0            # seconds of good slide this drift
var turbo := 0.0                   # seconds of boost owed (pads, mini-turbos, a rocket start, a trick)
var boosting := false              # burning the meter (the race decides)
var boost_amt := 0.0               # 0..1, how much boost is in the engine right now
var stagger := 0.0                 # seconds of lost grip after being slammed
var wrecked := false
var mag := false
var hits: Array[Hit] = []
var scrape := 0.0                  # wall contact this step, for sparks and sound
var landed := 0.0                  # vertical speed of the last hard landing, consumed by the race
var mini := 0                      # a mini-turbo tier just fired (consumed by the race)


func setup(scale: Vector3) -> void:
	half = Vector3(0.98, 0.6, 1.9) * scale
	var px := 0.86 * scale.x
	var pz := 1.32 * scale.z
	pads = [Vector3(px, -RIDE, pz), Vector3(-px, -RIDE, pz), Vector3(px, -RIDE, -pz), Vector3(-px, -RIDE, -pz)]


## Put the car on the road at a frame, `lift` above the pads' resting height, moving forward at `v`.
func place(course: SkyCourse, p: int, i: int, across: float, v: float) -> void:
	path = p
	index = i
	road = course.frame(p, i)
	basis = road.basis
	pos = road * Vector3(across, PAD_REST - SPRING_SAG + RIDE, 0.0)
	vel = road.basis.z * v
	spin = Vector3.ZERO
	wrecked = false
	drifting = false
	drift_charge = 0.0
	stagger = 0.0
	air = 0.0
	turbo = 0.0
	boost_amt = 0.0
	local = Vector3(across, 0.0, 0.0)
	on_road = true


## Where the visible model's root goes.
func model_transform() -> Transform3D:
	return Transform3D(basis, pos - basis.y * RIDE)


func point_velocity(p: Vector3) -> Vector3:
	return vel + spin.cross(p - pos)


func _apply(force: Vector3, at: Vector3, dt: float) -> void:
	vel += force * dt
	_torque((at - pos).cross(force), dt)


func _torque(t: Vector3, dt: float) -> void:
	var l := basis.transposed() * t
	spin += basis * Vector3(l.x / INERTIA.x, l.y / INERTIA.y, l.z / INERTIA.z) * dt


## An instantaneous push at a point (for walls and other craft): velocity change through the body's inverse mass and inertia.
func impulse(j: Vector3, at: Vector3) -> void:
	vel += j / mass
	var l := basis.transposed() * (at - pos).cross(j)
	spin += basis * Vector3(l.x / INERTIA.x, l.y / INERTIA.y, l.z / INERTIA.z) / mass


## How much a unit push along n at a point moves that point (1 / effective mass).
func give(at: Vector3, n: Vector3) -> float:
	var r := at - pos
	var l := basis.transposed() * r.cross(n)
	var w := basis * Vector3(l.x / INERTIA.x, l.y / INERTIA.y, l.z / INERTIA.z)
	return (1.0 + w.cross(r).dot(n)) / mass


# ------------------------------------------------------------------- step ----

func step(dt: float, c: Controls, course: SkyCourse) -> void:
	hits.clear()
	scrape = 0.0
	if held:
		return
	_track(course)
	stagger = maxf(0.0, stagger - dt)
	turbo = maxf(0.0, turbo - dt)
	var want := 1.0 if (turbo > 0.0 or boosting) and not wrecked else 0.0
	boost_amt = move_toward(boost_amt, want, dt * (5.0 if want > 0.0 else 1.6))
	if wrecked:
		_wreck_step(dt, c, course)
	else:
		_drive_step(dt, c, course)
	_walls(course, dt)
	pos += vel * dt
	var w := spin.length()
	if w > 0.00001:
		basis = Basis(spin / w, w * dt) * basis
	basis = basis.orthonormalized()


func _track(course: SkyCourse) -> void:
	index = course.locate(path, index, pos, 4, 10)
	local = course.q_local
	var p := course.paths[path]
	# a branch's two junctions: whichever deck the car is over takes it
	var other := course.junction(path, index)
	var to := course.q_path
	var side := course.junction_side()
	var past_edge := local.x > p.wl[index] - 0.25 if side > 0.0 else local.x < -p.wr[index] + 0.25
	if other >= 0 and past_edge:
		var j := course.locate(to, other, pos, 12, 12)
		var l2 := course.q_local
		if course.on_deck(to, j, l2) and absf(l2.y) < 3.0:
			path = to
			index = j
			local = l2
	elif path != SkyCourse.MAIN and index >= p.size() - 1 and local.z > 0.5:
		# off the end of the taper: back to the main road
		var br := course.branch_of(path)
		path = SkyCourse.MAIN
		index = course.locate(SkyCourse.MAIN, course.paths[SkyCourse.MAIN].wrap(br.merge_i + br.taper_n), pos, 10, 10)
		local = course.q_local
	road = _smooth_road(course)
	on_road = course.on_deck(path, index, local) and local.y > -2.5


## The road frame at the craft itself, blended between the samples either side: one sample's frame steps every 1.6 m, and through a loop
## those steps were felt as jags.
func _smooth_road(course: SkyCourse) -> Transform3D:
	var p := course.paths[path]
	var a := p.frames[index]
	var j := p.wrap(index + (1 if local.z >= 0.0 else -1))
	if j == index:
		return a
	var b := p.frames[j]
	var t := clampf(absf(local.z) / maxf(a.origin.distance_to(b.origin), 0.01), 0.0, 1.0)
	return a.interpolate_with(b, t)


## The deck under a point: on this car's road, or across the seam on the other one at a junction. Fills _sp_path, _sp_i, _sp_local.
func _support(course: SkyCourse, wp: Vector3) -> bool:
	_sp_path = path
	_sp_i = course.locate(path, index, wp, 3, 3)
	_sp_local = course.q_local
	if course.on_deck(path, _sp_i, _sp_local):
		return true
	var other := course.junction(path, index)
	if other < 0:
		return false
	var to := course.q_path
	var j := course.locate(to, other, wp, 12, 12)
	if course.on_deck(to, j, course.q_local):
		_sp_path = to
		_sp_i = j
		_sp_local = course.q_local
		return true
	return false

var _sp_path := 0
var _sp_i := 0
var _sp_local := Vector3.ZERO


func _drive_step(dt: float, c: Controls, course: SkyCourse) -> void:
	var up := basis.y
	var fwd := basis.z
	var p := course.paths[path]
	var flat_v := vel - up * vel.dot(up)
	speed = vel.dot(fwd)
	var v_abs := flat_v.length()
	slip = atan2(vel.dot(basis.x), absf(speed)) if v_abs > 3.0 else 0.0
	mag = p.mag[index] == 1 and on_road and v_abs > MAG_MIN and (grounded or air < 0.25)
	var glued := mag and absf(local.y) < 4.0
	var gravity := -road.basis.y * G if mag else Vector3.DOWN * G
	vel += gravity * dt
	# --- drift: rear grip goes, a yaw controller holds the angle the stick asks for
	var steer_in := clampf(c.steer, -1.0, 1.0)
	var turning := spin.dot(up)
	if not drifting and c.drift and grounded and speed > 18.0 and (absf(steer_in) > 0.15 or absf(turning) > 0.25):
		drifting = true
		drift_dir = signf(steer_in) if absf(steer_in) > 0.15 else signf(turning)
		drift_charge = 0.0
		spin += up * (drift_dir * 1.1)
		if not glued:
			vel += up * 2.4      # the hop
	if drifting and (not c.drift or speed < 14.0 or absf(slip) > 1.25 or wrecked):
		drifting = false
		_straighten = 0.4
		if drift_charge >= 3.0:
			mini = 3
			turbo = maxf(turbo, 1.9)
		elif drift_charge >= 1.8:
			mini = 2
			turbo = maxf(turbo, 1.3)
		elif drift_charge >= 0.8:
			mini = 1
			turbo = maxf(turbo, 0.8)
		drift_charge = 0.0
	# --- steering: less lock at speed; the front pads follow the slide back unless drifting
	var lock := lerpf(STEER_LOW, STEER_HIGH, smoothstep(6.0, 78.0, absf(speed)))
	var target := steer_in * lock
	if drifting:
		target = steer_in * 0.32
	elif grounded and speed > 5.0:
		target += clampf(-slip, -0.5, 0.5) * ASSIST
	steer = move_toward(steer, target, dt * (4.5 if absf(target) > absf(steer) else 7.0))
	# --- engine
	var vmax := lerpf(top, V_BOOST * top / V_TOP, boost_amt)
	var throttle := 1.0 if boost_amt > 0.5 else clampf(c.throttle, 0.0, 1.0)
	var drive := 0.0
	if speed >= -1.0 or c.brake < 0.1:
		var r := clampf(speed / vmax, 0.0, 1.3)
		drive = (accel + ACCEL_BOOST * boost_amt) * (1.0 - pow(r, 1.7)) * throttle
		if r > 1.0:
			drive = minf(drive, -5.0 * (r - 1.0))
	var reversing := c.brake > 0.5 and speed < 2.0 and c.throttle < 0.1
	if reversing:
		drive = -12.0 * (1.0 - clampf(-speed / V_REVERSE, 0.0, 1.0))
	var braking := 0.0 if reversing else clampf(c.brake, 0.0, 1.0)
	var handbrake := c.drift and not drifting and grounded and absf(speed) > 3.0
	# --- pads
	pads_down = 0
	var normal_sum := Vector3.ZERO
	var grip_k := grip * (0.42 if stagger > 0.0 else 1.0)
	var loads: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var contact: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
	var normals: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]
	var gaps: Array[float] = [INF, INF, INF, INF]
	if glued:
		# on a loop or the roll the craft rides the deck at its own height (_glue below): every pad is down, carrying the deck's pull
		var n_road := road.basis.y
		for k in 4:
			compress[k] = SPRING_SAG
			normals[k] = n_road
			contact[k] = pos + basis * pads[k]
			loads[k] = (G + DOWNFORCE * v_abs * v_abs) * 0.25
			normal_sum += n_road
		pads_down = 4
	for k in (0 if glued else 4):
		var wp := pos + basis * pads[k]
		compress[k] = 0.0
		if not _support(course, wp):
			continue
		var lp := _sp_local
		var n: Vector3 = course.paths[_sp_path].frames[_sp_i].basis.y
		var facing := up.dot(n)
		if facing < 0.35 or lp.y < -0.9:
			continue
		var d := lp.y / facing
		var cmp := PAD_REST - d
		if cmp <= 0.0:
			continue
		compress[k] = cmp
		gaps[k] = d
		normals[k] = n
		contact[k] = wp
	for k in (0 if glued else 4):
		var cmp: float = compress[k]
		if gaps[k] == INF:
			continue
		var wp: Vector3 = contact[k]
		var n: Vector3 = normals[k]
		var d: float = gaps[k]
		var pv := point_velocity(wp)
		var vn := pv.dot(n)
		var f := SPRING * cmp - DAMP * vn
		if cmp > BUMP_AT:
			f += BUMP * (cmp - BUMP_AT)
		# the anti-roll bar: the pad across the axle pulls this one toward its own compression
		var mate: int = k ^ 1
		f += ANTI_ROLL * (cmp - maxf(0.0, compress[mate]))
		f = maxf(0.0, f)
		if d < MIN_GAP:
			# bottomed out: no further in, and the push into the deck is gone
			pos += n * ((MIN_GAP - d) * 0.9)
			if vn < 0.0:
				var j := -vn / give(wp, n)
				impulse(n * j, wp)
				if -vn > landed:
					landed = -vn
		_apply(n * f, wp, dt)
		pads_down += 1
		normal_sum += n
		loads[k] = f
	grounded = pads_down >= 2
	if pads_down == 0:
		air += dt
	else:
		if air > 0.3:
			last_air = air
		air = 0.0
	if pads_down > 0 and not glued:
		var n_avg := normal_sum.normalized()
		var plane_v := vel - n_avg * vel.dot(n_avg)
		vel -= n_avg * (DOWNFORCE * plane_v.length_squared() * dt)
	# --- grip at each pad that is down
	for k in 4:
		if loads[k] <= 0.0:
			continue
		var n: Vector3 = normals[k]
		var wp: Vector3 = contact[k]
		var front := k < 2
		var pf := fwd
		if front:
			pf = fwd.rotated(up, steer)
		pf = (pf - n * pf.dot(n)).normalized()
		var ps := n.cross(pf)
		var pv := point_velocity(wp)
		var v_long := pv.dot(pf)
		var v_lat := pv.dot(ps)
		var mu := MU * grip_k * (MAG_GRIP if mag else 1.0)
		if not front:
			if drifting:
				mu *= 0.5
			elif handbrake:
				mu *= 0.55
			else:
				mu *= REAR_GRIP + 0.35 * braking      # (the brakes alone never swing the tail: the user found braking "instantly" drifted)
		var limit := mu * loads[k]
		var alpha := atan2(absf(v_lat), maxf(absf(v_long), 5.0))
		var peak := PEAK_F if front else PEAK_R
		var shape := sin(minf(alpha / peak, 1.0) * PI * 0.5)
		if alpha > peak:
			shape = lerpf(1.0, SLIDE, smoothstep(peak, peak * 3.5, alpha))
		var f_lat := -signf(v_lat) * limit * shape
		var stop := absf(v_lat) * 0.25 / dt
		f_lat = clampf(f_lat, -stop, stop)
		var share := 0.46 if front else 0.54
		var f_long := 0.0 if drifting else drive * share * 2.0 / maxf(1.0, float(pads_down))
		if braking > 0.0:
			var b := -signf(v_long) * BRAKE * braking * (0.68 if front else 0.32) * 0.5
			var hold := absf(v_long) * 0.25 / dt
			f_long += clampf(b, -hold, hold)
		if handbrake and not front:
			f_long += clampf(-signf(v_long) * HANDBRAKE * 0.5, -absf(v_long) * 0.25 / dt, absf(v_long) * 0.25 / dt)
		elif absf(drive) < 0.01:
			f_long += -signf(v_long) * minf(ROLLING * 0.25, absf(v_long) * 0.25 / dt)
		var total := sqrt(f_lat * f_lat + f_long * f_long)
		if total > limit and total > 0.0:
			if drifting and not front:
				# in a drift the throttle eats the rear's side grip: power oversteer, the angle grows on the gas
				var keep := clampf(absf(f_long) / limit, 0.0, 0.8)
				f_long = signf(f_long) * minf(absf(f_long), limit * keep)
				f_lat = signf(f_lat) * minf(absf(f_lat), sqrt(maxf(0.0, limit * limit - f_long * f_long)))
			else:
				# otherwise the side force comes first (traction control and ABS): throttle and brakes take what grip is left
				f_lat = clampf(f_lat, -limit, limit)
				f_long = signf(f_long) * minf(absf(f_long), sqrt(maxf(0.0, limit * limit - f_lat * f_lat)))
		_apply(pf * f_long, wp + up * (RIDE * 0.5), dt)      # (half the pitch: hard braking dipped the nose and lifted the tail out)
		_apply(ps * f_lat, wp + up * (RIDE * ROLL_CENTRE), dt)
	# --- out of a drift, a slide wants to straighten: the nose is turned back toward the way the craft is going (sooner under the brakes)
	var stab_from := lerpf(STAB_FROM, 0.08, braking)
	if not drifting and not handbrake and grounded and v_abs > 8.0 and absf(slip) > stab_from:
		var over := signf(slip) * (absf(slip) - stab_from)
		_torque(up * clampf(over * STAB * smoothstep(8.0, 25.0, v_abs), -9.0, 9.0), dt)
	# --- drift (arcade): the yaw is driven to hold the slide at the angle the stick asks for (into the turn: tighter and more angle;
	# counter-steer: wider and less), a carving force bends the line, and the slide keeps its speed. Left to the tyres alone the
	# halved rear grip spun the craft out every time (tested 2026-11-18).
	var flat := vel - up * vel.dot(up)
	var turn := 0.0
	if flat.length() > 3.0:
		var dir := flat.normalized()
		if _vdir_fresh:
			turn = atan2(_vdir_was.cross(dir).dot(up), _vdir_was.dot(dir)) / maxf(dt, 0.0001)
		_vdir_was = dir
		_vdir_fresh = true
	else:
		_vdir_fresh = false
	_straighten = maxf(0.0, _straighten - dt)
	if drifting and grounded:
		var tight := steer_in * drift_dir
		var want := -drift_dir * (0.36 + 0.2 * tight)
		var yaw_now := spin.dot(up)
		var yaw_want := turn - 5.0 * (want - slip)
		spin += up * ((yaw_want - yaw_now) * minf(1.0, 14.0 * dt))
		if flat.length() > 3.0:
			var inward := up.cross(flat.normalized()) * drift_dir
			vel += inward * ((DRIFT_CARVE + DRIFT_TIGHT * tight) * dt)
		# in a drift the engine drives the craft the way it is going, not the way it points (pushing along the nose, sideways to the
		# travel, made drifting slower than gripping round: tested 2026-11-18), and the slide scrubs no speed of its own
		if flat.length() > 3.0:
			vel += flat.normalized() * (drive * dt)
			vel += flat.normalized() * (absf(vel.dot(basis.x)) * 0.5 * dt) if speed < top else Vector3.ZERO
		if absf(slip) > 0.15:
			drift_charge += dt * (1.15 + 0.6 * maxf(0.0, tight))
	elif _straighten > 0.0 and grounded:
		# coming out of a drift the nose is brought round to the way the craft is going, without snapping past it
		var yaw_now := spin.dot(up)
		spin += up * ((turn + 4.0 * slip - yaw_now) * minf(1.0, 12.0 * dt))
	# --- air: settle toward the road's tilt so a landing lands, and the stick turns a little
	if pads_down == 0:
		var target_up := road.basis.y if absf(local.y) < 60.0 else Vector3.UP
		var axis := up.cross(target_up)
		_torque(axis * 9.0, dt)
		var tumble := spin - up * spin.dot(up)
		spin -= tumble * (2.2 * dt)
		spin += up * (steer_in * 2.2 * dt)
		spin -= up * (spin.dot(up) * 1.5 * dt)
	else:
		spin *= exp(-0.8 * dt)
	vel -= vel * (vel.length() * DRAG * dt)
	if glued:
		_glue(dt)
		_glue_t += dt
	else:
		_glue_t = 0.0
	_slip_was = slip


## Glued to a loop or the barrel roll (user, 2026-11-18: "I should be glued to the spiral"): held at riding height on the deck's smoothed
## surface, square to it, with nothing moving it off the deck, and its speed kept as the deck curves. Steering, grip and walls still
## work as anywhere else: the deck holds the craft, it does not drive it. (Before this the springs and a tilt lock did it, and at boost
## speed in a loop they let the craft fly off or sink through.)
func _glue(dt: float) -> void:
	var n := road.basis.y
	var ride := PAD_REST - SPRING_SAG + RIDE
	var h := (pos - road.origin).dot(n)
	# eased on over the first tenth of a second, then held exactly: chasing the surface, the craft lagged a fast twist and caught up in jerks
	var hold := 1.0 if _glue_t > 0.12 else minf(1.0, 40.0 * dt)
	pos += n * ((ride - h) * hold)
	var v := vel.length()
	var along := vel - n * vel.dot(n)
	if along.length_squared() > 0.01:
		vel = along.normalized() * v
	var f := basis.z - n * basis.z.dot(n)
	if f.length_squared() > 0.01:
		f = f.normalized()
		basis = basis.slerp(Basis(n.cross(f), n, f), 1.0 if _glue_t > 0.12 else minf(1.0, 30.0 * dt)).orthonormalized()
	spin = n * spin.dot(n)

var _slip_was := 0.0
var _glue_t := 0.0
var _straighten := 0.0
var _vdir_was := Vector3.FORWARD
var _vdir_fresh := false


func _wreck_step(dt: float, c: Controls, course: SkyCourse) -> void:
	vel += Vector3.DOWN * G * dt
	speed = vel.length()
	drifting = false
	grounded = false
	# aftertouch: the wreck can be leaned on a little
	if c.aftertouch != Vector2.ZERO:
		var f := road.basis.x * c.aftertouch.x + road.basis.z * c.aftertouch.y
		vel += f * (14.0 * dt)
	# the body's eight corners against the deck: bounce, scrape and tumble
	var p := course.paths[path]
	for k in 8:
		var corner := Vector3(half.x * (1.0 if k & 1 else -1.0), half.y * (0.8 if k & 2 else -0.8), half.z * (1.0 if k & 4 else -1.0))
		var wp := pos + basis * corner
		var i := course.locate(path, index, wp, 3, 4)
		var lp := course.q_local
		if not course.on_deck(path, i, lp) or lp.y > 0.0 or lp.y < -1.6:
			continue
		var n: Vector3 = p.frames[i].basis.y
		pos += n * (-lp.y * 0.8)
		var pv := point_velocity(wp)
		var vn := pv.dot(n)
		if vn < 0.0:
			var j := -(1.0 + 0.28) * vn / give(wp, n)
			var tv := pv - n * vn
			var tl := tv.length()
			var jt := Vector3.ZERO
			if tl > 0.001:
				jt = -tv / tl * minf(0.55 * j, tl / give(wp, tv / tl))
			impulse(n * j + jt, wp)
			if -vn > 6.0:
				var h := Hit.new()
				h.kind = FLOOR
				h.speed = -vn
				h.at = wp
				h.normal = n
				hits.append(h)
	spin *= exp(-0.35 * dt)


## The walls: each corner of the body against the wall on its side, if there is one there and it is under the corner.
func _walls(course: SkyCourse, dt: float) -> void:
	var p := course.paths[path]
	for k in 4:
		var corner := Vector3(half.x * (1.0 if k & 1 else -1.0), -0.15, half.z * (1.0 if k & 2 else -1.0))
		var wp := pos + basis * corner
		var i := course.locate(path, index, wp, 3, 3)
		var lp := course.q_local
		if p.deck[i] == 0 or lp.y > WALL_REACH or lp.y < -1.4:
			continue
		var side := 1.0 if lp.x > 0.0 else -1.0
		var walled := (p.wall_l[i] if side > 0.0 else p.wall_r[i]) == 1
		if not walled:
			continue
		var face := (p.wl[i] if side > 0.0 else p.wr[i]) - 0.3
		var depth := absf(lp.x) - face
		if depth <= 0.0 or depth > 3.0:
			continue
		var n: Vector3 = p.frames[i].basis.x * -side
		pos += n * depth
		var pv := point_velocity(wp)
		var vn := pv.dot(n)
		var tv := pv - n * vn
		var tl := tv.length()
		scrape = maxf(scrape, maxf(0.0, -vn) + tl * 0.05)
		if vn >= 0.0:
			continue
		# pushed back at the height of the centre of mass: a wall turns the craft and slows it, but cannot roll it over
		var at := wp + basis.y * 0.15
		var j := -(1.0 + WALL_E) * vn / give(at, n)
		var jt := Vector3.ZERO
		if tl > 0.001:
			jt = -tv / tl * minf(WALL_MU * j, tl / give(at, tv / tl) * 0.5)
		impulse(n * j + jt, at)
		var into_wall := -basis.z.dot(n)
		if into_wall > 0.0 and not wrecked:
			var along := (basis.z - n * basis.z.dot(n)).normalized()
			spin += basis.y * (signf(basis.z.cross(along).dot(basis.y)) * minf(into_wall * WALL_ALIGN, 2.5))
		if -vn > 4.0:
			var h := Hit.new()
			h.kind = WALL
			h.speed = -vn
			h.at = wp
			h.normal = n
			hits.append(h)
		if drifting and -vn > 8.0:
			drifting = false
			drift_charge = 0.0
