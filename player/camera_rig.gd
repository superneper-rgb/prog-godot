class_name CameraRig
extends RefCounted
## The third-person camera, ported statement for statement from the three.js game's CameraRig (index.html camera.js).
## Pure math: Game copies pos / look to the Camera3D each frame. yaw uses the player's convention (0 looks along +Z; increasing =
## turn left); pitch > 0 means the camera sits above the focus looking down.

class Boom:
	var dx := 0.0
	var dy := 0.0
	var dz := 0.0
	var ox := 0.0
	var oz := 0.0
	var free := 0.0

var world: World
var yaw := 0.0
var pitch := 0.0
var fx := 0.0        # smoothed focus point
var fy := 0.0
var fz := 0.0
var dist := 0.0
var clear_dist := 0.0
var vert_k := 0.0
var pos := Vector3.ZERO
var look := Vector3.ZERO
var auto_following := false
var aim_w := 0.0
var ads_w := 0.0
var scope_w := 0.0   # 0 = normal third-person, 1 = looking through a scope
var pow_w := 0.0
var fov := 0.0       # the driving camera widens the lens (vehicles/vehicles.gd); 0 = the game's own
var manual_t := 99.0 # seconds since the last manual look input
var yaw_vel := 0.0   # smoothed auto-follow swing (rad/s)
var follow_t := 0.0  # how long the travel heading has been steady
var head_prev := 0.0
var lead_x := 0.0    # smoothed look-ahead offset
var lead_z := 0.0
var lift := 0.0      # extra pitch used to get over a blocked boom (smoothed / target / release timer)
var lift_t := 0.0
var lift_hold := 0.0
var obs_t := 99.0    # seconds since the boom was last obstructed
var side := 0.0      # smoothed shoulder offset
var swing_ok := false
var swing_to := NAN  # the yaw the view is turning to when boxed in (NAN = none)
var lift_acc := 0.0
var too_close := false
var squeezed := false   # indoors: the lens is pinned on the body (see update)
var squeeze_t := 0.0    # how long the lens has been pinned with the body not walking out of it
const SQUEEZE_WAIT := 0.4
var fy_v := 0.0
var lift_v := 0.0
var leash_vx := 0.0
var leash_vz := 0.0
var strafe_w := 0.0
var strafe_v := 0.0
var hold_y := 0.0    # the height a jump holds the view at
var air_t := 0.0     # time in the air
var run_at_w := 0.0  # how much the player is running at the camera
var run_at_v := 0.0
var kick_p := 0.0    # scoped shot: the view jumps up and settles back
var room_w := 0.0
var room_travel_x := 0.0
var room_travel_z := 0.0
var trail: Array[Vector2] = []
var trail_y := NAN
var pull_w := 0.0    # a level pulling the camera back for a set piece (pull_t 0..1 with pull_dist / pull_fov)
var pull_t := 0.0
var pull_eff := 0.0
var pull_dist := 0.0
var pull_fov := 0.0
var pull_lock := false    # JS pullCx !== undefined: a lock point
var pull_cx := 0.0
var pull_cz := 0.0
var pull_aim_y := 0.0     # height shots lift to while locked on (0 = none; Combat's set-piece aim)
var pull_pitch_on := false
var pull_pitch := 0.0
var lock_off := 0.0
var lock_idle := 0.0
var wr_w := 0.0
var yaw_rate := 0.0
var foot_y := NAN
var view_off := 0.0
var vo_t := 0.0
var vo_v := 0.0
var vo_acc := 0.0
var last_tgt := NAN
var cd_v := 0.0
var occ_t := 0.0
var boom: Boom = null


func _init(w: World) -> void:
	world = w
	pitch = Config.cam_pitch_default
	fy = Config.cam_height
	dist = Config.cam_dist
	clear_dist = Config.cam_dist
	vert_k = Config.cam_vert_k
	snap_to(null)


func snap_to(p: Player) -> void:
	var C := Config
	aim_w = 1.0 if (p != null and p.aiming) else 0.0
	ads_w = 1.0 if (p != null and p.ads) else 0.0
	scope_w = 1.0 if (p != null and p.scoped) else 0.0
	pow_w = 1.0 if (p != null and p.power_aim) else 0.0
	kick_p = 0.0
	yaw_vel = 0.0
	lift_acc = 0.0
	lift_hold = 0.0
	squeeze_t = 0.0
	squeezed = false
	room_w = float(world.camera_zone_weight.call(p)) if (p != null and world.camera_zone_weight.is_valid()) else 0.0
	room_travel_x = 0.0
	room_travel_z = 0.0
	trail.clear()
	if p != null:
		yaw = p.yaw
		pitch = C.cam_pitch_default
		fx = p.x
		fy = p.y + C.cam_height
		fz = p.z
		dist = C.cam_dist
		clear_dist = C.cam_dist
	manual_t = 99.0
	follow_t = 0.0
	lead_x = 0.0
	lead_z = 0.0
	lift = 0.0
	lift_t = 0.0
	swing_to = NAN
	obs_t = 99.0
	side = 0.0
	leash_vx = p.vx if p != null else 0.0
	leash_vz = p.vz if p != null else 0.0
	fy_v = 0.0
	lift_v = 0.0
	strafe_w = 1.0 if (p != null and p.strafing) else 0.0
	strafe_v = 0.0
	hold_y = p.y if p != null else 0.0
	air_t = 0.0
	run_at_w = 0.0
	run_at_v = 0.0
	_place(0.0, true)


## JS levels/_kit/crawl.js: the camera stays inside the duct, just behind the hands. No boom outside the shell.
func crawl_view(p: Player) -> void:
	var sy := sin(yaw)
	var cy := cos(yaw)
	pos = Vector3(p.x - sy * 0.25, p.y + 0.87, p.z - cy * 0.25)
	look = Vector3(p.x + sy * 2.0, p.y + 0.78 - sin(pitch) * 0.6, p.z + cy * 2.0)
	too_close = true


func update(dt: float, p: Player) -> void:
	var C := Config
	var W := world
	dt = minf(dt, 0.05)
	room_w = U.damp(room_w, float(W.camera_zone_weight.call(p)) if W.camera_zone_weight.is_valid() else 0.0, 5.0, dt)
	# (smoothed: the body's velocity flickers while it slides along a wall or a prop, and the look-ahead origins jumped with it)
	var ttx := clampf(p.vx * 0.4, -1.2, 1.2)
	var ttz := clampf(p.vz * 0.4, -1.2, 1.2)
	room_travel_x = U.damp(room_travel_x, ttx, 30.0 if absf(ttx) > absf(room_travel_x) else 6.0, dt)
	room_travel_z = U.damp(room_travel_z, ttz, 30.0 if absf(ttz) > absf(room_travel_z) else 6.0, dt)
	var yaw_in := yaw
	var strafing := p.strafing
	var look_active := Inp.look_active
	Inp.look_tight = p.aiming or p.ads or p.scoped
	if C.cam_leash_smooth > 0.0:
		leash_vx = U.damp(leash_vx, p.vx, C.cam_leash_smooth, dt)
		leash_vz = U.damp(leash_vz, p.vz, C.cam_leash_smooth, dt)
	else:
		leash_vx = p.vx
		leash_vz = p.vz
	strafe_w = U.spring_to(strafe_w, strafe_v, 1.0 if strafing else 0.0, 16.0, dt)   # (the boom's strafe length eases in: a stepped length snapped the lens in one frame)
	strafe_v = U.spring_v
	var sp0 := sqrt(p.vx * p.vx + p.vz * p.vz)
	var rel0 := absf(U.wrap_angle(atan2(p.vx, p.vz) - yaw)) if sp0 > 1.5 else 0.0     # running at the camera: slow boom out, so it never reads as a lurch
	var run_at_tgt := clampf((rel0 - 1.9) / 0.7, 0.0, 1.0) * clampf(sp0 / C.run_speed, 0.0, 1.0) if (p.mode == &"normal" and not strafing and not p.aiming) else 0.0
	run_at_w = U.spring_to(run_at_w, run_at_v, run_at_tgt, 2.5, dt)
	run_at_v = U.spring_v

	# ---- manual orbit (right stick / mouse): always wins, and holds off auto-follow for cam_manual_hold ----
	# looking through a scope: the zoom narrows the view, so the look speed is scaled by the same ratio
	pull_w = U.damp(pull_w, pull_t, 1.6, dt)
	# a level can pull the camera back for a set piece. A pull without a lock point also gives way while hip-firing.
	pull_eff = pull_w * (1.0 - ads_w) * (1.0 - (aim_w if not pull_lock else 0.0))
	scope_w = U.damp(scope_w, 1.0 if p.scoped else 0.0, 12.0, dt)
	kick_p = U.damp(kick_p, 0.0, 5.0, dt)
	var sk := 1.0
	if scope_w > 0.001 and p.scope_fov > 0.0:
		sk = lerpf(1.0, clampf(tan(p.scope_fov * PI / 360.0) / tan(C.fov * PI / 360.0), 0.12, 1.0), scope_w)
	if look_active:
		yaw += Inp.look_yaw * sk
		pitch += Inp.look_pitch * sk
		manual_t = 0.0
	else:
		manual_t += dt
	auto_following = false

	# ---- recenter: the only snap ----
	if Inp.btn(&"recenter").pressed:
		yaw = p.yaw
		pitch = C.cam_pitch_default
		fx = p.x
		fz = p.z
		manual_t = 99.0
		follow_t = 0.0
		yaw_vel = 0.0
		lead_x = 0.0
		lead_z = 0.0
	elif not look_active and not strafing and not p.aiming and not p.punching and (p.mode == &"normal" or p.mode == &"swim") and p.wall_run == null and not (pull_eff > 0.3):
		_follow(dt, p)
	elif p.mode == &"pole" or p.wall_run != null:
		follow_t = 0.0      # no snap of the auto-follow swing when a grab / wall run takes over
		yaw_vel = U.damp(yaw_vel, 0.0, 9.0, dt)
		yaw += yaw_vel * dt
	else:
		follow_t = 0.0      # an auto-swing cut short by a punch, a strafe or the stick eases out; aiming stops it dead
		yaw_vel = 0.0 if (p.aiming or p.ads) else U.damp(yaw_vel, 0.0, 25.0 if look_active else 12.0, dt)
		yaw += yaw_vel * dt
	# wall run: the camera slides round to a spot behind the run, on the open side, at a limited turn rate
	wr_w = U.damp(wr_w, 1.0 if p.wall_run != null else 0.0, 4.0 if p.wall_run != null else 2.5, dt)
	if wr_w > 0.002 and p.wall_run != null and not look_active:
		var w := p.wall_run
		var want_yaw := atan2(w.tx, w.tz) + w.side * 0.5
		var kw := 1.0 - exp(-3.2 * dt)
		yaw += clampf(U.wrap_angle(want_yaw - yaw) * kw * wr_w, -2.2 * dt, 2.2 * dt)
	pitch = clampf(pitch, lerpf(C.cam_pitch_min, -0.85, scope_w), C.cam_pitch_max)    # a scope can look well above the horizon
	yaw = U.wrap_angle(yaw)
	# set piece (the Mawmother arena): a fixed high angle and a soft lock. The camera sits behind you on the far side from her; looking around nudges it off that line and it drifts back.
	var pw := pull_eff
	if pw > 0.001 and pull_lock:
		var tx := pull_cx - p.x
		var tz := pull_cz - p.z
		var near := sqrt(tx * tx + tz * tz) > 2.5
		var kk := 1.0 - exp(-8.0 * dt)
		if near:
			var boss_yaw := atan2(tx, tz)
			if pw < 0.05:
				lock_off = U.wrap_angle(yaw - boss_yaw)     # before the lock engages, remember where the camera already is
			else:
				if look_active:
					lock_off = U.wrap_angle(lock_off + Inp.look_yaw * sk)
					lock_idle = 0.0
				else:
					lock_idle += dt
					if lock_idle > 2.5 and not p.aiming:
						lock_off *= exp(-0.7 * dt)
				yaw = U.wrap_angle(yaw + U.wrap_angle(boss_yaw + lock_off - yaw) * kk * pw)
		pitch = lerpf(pitch, pull_pitch if pull_pitch_on else pitch, kk * pw)

	# ---- focus point smoothing (frame-rate independent) ----
	aim_w = U.damp(aim_w, 1.0 if p.aiming else 0.0, 9.0 if p.aiming else 14.0, dt)    # leaves the shoulder view a bit faster than it enters
	ads_w = U.damp(ads_w, 1.0 if p.ads else 0.0, 10.0, dt)
	pow_w = U.damp(pow_w, 1.0 if p.power_aim else 0.0, 9.0, dt)      # power mode: the shoulder view moves over to the LEFT shoulder
	var rw := room_w
	# indoors the focus keeps close to the body (no lag, no look-ahead): the boom starts from it
	var hk := lerpf((C.cam_strafe_k if (strafing or p.aiming) else C.cam_pos_k) * (0.6 if p.mode == &"pole" else 1.0), 45.0, rw)

	# look-ahead along the travel direction (off while aiming so the crosshair view stays steady); never leads into a wall
	var lx := 0.0
	var lz := 0.0
	if C.cam_lead > 0.0 and not strafing and not p.aiming and not p.ads and (p.mode == &"normal" or p.mode == &"swim") and rw < 0.99:
		lx = p.vx * C.cam_lead * (1.0 - rw)
		lz = p.vz * C.cam_lead * (1.0 - rw)
		var ll := sqrt(lx * lx + lz * lz)
		if ll > 0.05:
			var room := W.ray_clear(p.x, p.y + C.cam_height, p.z, lx / ll, 0.0, lz / ll, ll + 0.35, 0.2) - 0.35
			var k := clampf(room, 0.0, ll) / ll
			lx *= k
			lz *= k
	# (first-order on purpose: a sprung focus carries speed past the body when it stops at a wall, and the boom collapses)
	lead_x = U.damp(lead_x, lx, C.cam_lead_k, dt)
	lead_z = U.damp(lead_z, lz, C.cam_lead_k, dt)
	fx = U.damp(fx, p.x + lead_x, hk, dt)
	fz = U.damp(fz, p.z + lead_z, hk, dt)
	var crouch_drop := 0.55 if p.crouching else 0.0
	var dip := minf(0.3, p.land_impact * C.cam_land_dip) * clampf(p.land_t / (p.land_dur if p.land_dur > 0.0 else 0.44), 0.0, 1.0) if (p.grounded and p.land_t > 0.0) else 0.0     # small settle on landing
	# swimming: the focus sits at the floating depth, a little higher and calm, and it stays at the surface while a plunge takes the body under
	var foot_f := float(p.swim_s) - C.swim_float + 0.45 - 0.8 * p.swim_bob if (p.mode == &"swim" and p.swim_s != null) else p.y
	# a jump does not move the view: the focus keeps the height you took off from. It follows you down at once, up only past the band that keeps the body in frame,
	# and rises early for ground you are about to land on. Anything that lasts in the air (a jet) lets go of the hold after a moment.
	var airborne := p.mode == &"normal" and not p.grounded
	var under := minf(p.y, W.ground_height(p.x, p.z, 0.36, p.y + 0.42)) if airborne else p.y
	var holding := airborne and C.cam_jump_band > 0.0 and not strafing and not p.aiming and not p.ads and p.wall_run == null
	if not holding:
		hold_y = minf(foot_f, hold_y + 9.0 * dt) if (airborne and foot_f > hold_y) else foot_f    # (aiming mid-jump: catches up at a set speed, not in one lurch)
		air_t = 0.0
	else:
		air_t += dt
		var ahead := minf(p.y, W.ground_height(p.x + p.vx * 0.3, p.z + p.vz * 0.3, 0.36, p.y + 0.42))
		var ledge := maxf(under, ahead)
		hold_y = maxf(minf(hold_y, p.y), p.y - maxf(0.4, dist * C.cam_jump_band - 0.35))
		if ledge > hold_y:     # a ledge coming up: rise for it at a set speed, there before the feet are
			hold_y = minf(ledge, hold_y + 7.0 * dt)
			vert_k = maxf(vert_k, C.cam_vert_k)
		if air_t > 1.4:
			hold_y = U.damp(hold_y, p.y, 1.5, dt)
	var want_y := hold_y + C.cam_height - crouch_drop - dip
	# loose in the air, tighter the further it falls behind (a long fall stays in frame)
	var want_v := C.cam_vert_k if (p.grounded or (p.mode != &"normal" and p.mode != &"pole")) else lerpf(C.cam_vert_air_k, C.cam_vert_k, clampf(absf(fy - want_y) / 2.0, 0.0, 1.0))
	vert_k = U.damp(vert_k, want_v, 8.0, dt)     # re-settles on landing
	fy = U.spring_to(fy, fy_v, want_y, (maxf(vert_k, 14.0) if (strafing or p.aiming) else vert_k) * 2.0, dt)
	fy_v = U.spring_v
	# Keep the boom origin above the ground under the player, so it cannot enter a platform the player has just cleared and collapse the view.
	var fl := under + (C.cam_probe + 0.15 if airborne else maxf(C.cam_probe + 0.15, C.cam_height * 0.6))
	if fy < fl:
		fy = fl
		fy_v = maxf(fy_v, 0.0)

	# the smoothed focus may not lag through geometry (pillar corners, doorframes): clip it to what the player can see
	var ex := fx - p.x
	var ez := fz - p.z
	var el := sqrt(ex * ex + ez * ez)
	if el > 0.05:
		var free := W.ray_clear(p.x, fy, p.z, ex / el, 0.0, ez / el, el, 0.15)
		if free < el - 0.02:
			fx = p.x + ex / el * free
			fz = p.z + ez / el * free

	# (Not in the JS, user 2026-11-09.) A no-swing room (Visiting Hours' block) could neither rise nor turn, so a boom squeezed onto the body stayed there:
	# first person for as long as you stood with your back near a wall. Once the lens is that close the turn is the lesser evil, and it is allowed until it is done.
	# The same goes for the rise (user 2026-11-09, after seeing both views side by side): squeezed, the lens goes up over his head and looks down, and comes back as soon as
	# there is room behind him. It stays on while the rise is still up, so the boom's limits do not change under it.
	# (User 2026-11-10: the rise yanked the view up to a bird's eye at every doorway, the jambs pinch the boom for a moment as he walks through.) So the pinch
	# only counts once it has lasted (SQUEEZE_WAIT) with the body not walking away from the lens: a doorway passed through lets go by itself, a wall at his back does not.
	var away := room_travel_x * sin(yaw) + room_travel_z * cos(yaw)     # metres per 0.4 s along the view, away from the lens
	if clear_dist < 1.3 and away < 0.25:
		squeeze_t += dt
	else:
		squeeze_t = 0.0
	var rising := not is_nan(swing_to) or lift_t > 0.0 or lift > 0.02
	squeezed = room_w > 0.5 and (squeeze_t > SQUEEZE_WAIT or (squeezed and rising))
	swing_ok = not look_active and not p.ads and not p.scoped and (p.mode == &"normal" or p.mode == &"swim") and not (pull_eff > 0.05) and not (W.camera_no_swing and room_w > 0.5 and not squeezed)
	foot_y = hold_y if holding else p.y
	# indoors: the last few metres walked (the indoor boom can look back along them, see _place)
	if room_w > 0.3:
		var last: Vector2 = trail.back() if not trail.is_empty() else Vector2(INF, INF)
		if trail.is_empty() or Vector2(p.x, p.z).distance_to(last) > 0.2:
			trail.append(Vector2(p.x, p.z))
			if trail.size() > 20:
				trail.pop_front()
		if not is_nan(trail_y) and absf(p.y - trail_y) > 1.2:
			trail.clear()
		trail_y = p.y
	else:
		trail.clear()
	if dt > 1e-3:
		yaw_rate = U.damp(yaw_rate, U.wrap_angle(yaw - yaw_in) / dt, 12.0, dt)     # how fast the view is turning (the indoor boom looks ahead along it)
	_place(dt, false)


## automatic swing behind the travel direction. Strength = speed x (not running at/across the camera) x (heading steady for a moment) x (time since manual input).
func _follow(dt: float, p: Player) -> void:
	var C := Config
	var sp := sqrt(p.vx * p.vx + p.vz * p.vz)
	var vr := 0.0      # wanted swing rate (rad/s); the actual swing eases towards it so starts / stops never jerk
	if sp > 1.5:
		var h := atan2(p.vx, p.vz)
		follow_t = follow_t + dt if absf(U.wrap_angle(h - head_prev)) < C.cam_steady_rate * dt else 0.0   # a pivot or reversal restarts the wait
		head_prev = h
		var rel := absf(U.wrap_angle(h - yaw))     # 0 = running away from the camera, pi = running at it
		var sd := 1.0 if rel <= 0.8 else (lerpf(1.0, C.cam_follow_side, (rel - 0.8) / 0.8) if rel <= 1.6 else (lerpf(C.cam_follow_side, 0.0, (rel - 1.6) / 1.0) if rel <= 2.6 else 0.0))
		var mr := U.ease_in_out(clampf((manual_t - C.cam_manual_hold) / C.cam_follow_ramp, 0.0, 1.0))
		var ramp := U.ease_in_out(clampf((follow_t - C.cam_follow_delay) / C.cam_follow_ramp, 0.0, 1.0)) * mr
		var w := clampf(sp / C.run_speed, 0.0, 1.0) * sd * ramp * (1.0 if p.grounded else C.cam_follow_air)
		if w > 0.001:
			vr = clampf(U.wrap_angle(h - yaw) * C.cam_follow_k * w, -C.cam_follow_max, C.cam_follow_max)
		if C.cam_follow_leash > 0.0:
			vr = lerpf(vr, clampf((leash_vx * cos(yaw) - leash_vz * sin(yaw)) / C.cam_dist * mr * (1.0 if p.grounded else C.cam_follow_air), -C.cam_follow_max, C.cam_follow_max), C.cam_follow_leash * lerpf(1.0, C.cam_follow_leash_room, room_w))
		if p.grounded and manual_t > C.cam_manual_hold:
			pitch = U.damp(pitch, C.cam_pitch_default, 0.35 * clampf(sp / C.run_speed, 0.0, 1.0), dt)    # settle pitch gently while running
	else:
		follow_t = 0.0
	yaw_vel = U.damp(yaw_vel, vr, C.cam_follow_smooth, dt)
	yaw += yaw_vel * dt
	auto_following = absf(yaw_vel) > 0.02


# boom along (yaw, pitch): the free length, from the origin the shoulder offset gives that yaw
func _cast(ppitch: float, cyaw: float, sk: float, oy: float, want: float, probe: float, fine: bool, sx: float = 0.0, sz: float = 0.0) -> Boom:
	var cp := cos(ppitch)
	var sp := sin(ppitch)
	var b := Boom.new()
	b.dx = -sin(cyaw) * cp
	b.dy = sp
	b.dz = -cos(cyaw) * cp
	b.ox = fx + sx - cos(cyaw) * sk      # the shoulder offset turns with the yaw, so every probe starts from its own origin
	b.oz = fz + sz + sin(cyaw) * sk
	b.free = maxf(0.0, _free(b.ox, oy, b.oz, b.dx, b.dy, b.dz, want + 0.3, probe, fine) - _gap)
	return b

var _gap := 0.0

const NEAR := 1.3     # the first stretch of the boom, probed slim (see _free)
const SLIM := 0.13    # the slim probe (the indoor boom's own radius)


## Free length of a boom. (Not in the JS, user 2026-11-09: the camera kept dropping into the body beside walls.) The body is 0.36 m wide and the fat
## probe 0.22 m, so with the player against a wall a boom running along it grazed the wall at its very start and read as no room at all: the lens
## jumped inside the body. The first stretch is now probed slim (a wall there is one the boom really points into), the rest fat as before (where
## the fat probe has no room to start because the wall is still alongside, World.ray_clear slims it by itself).
func _free(ox: float, oy: float, oz: float, dx: float, dy: float, dz: float, max_d: float, probe: float, fine: bool) -> float:
	var W := world
	var slim := minf(probe, SLIM)
	if probe <= slim:
		return W.ray_clear(ox, oy, oz, dx, dy, dz, max_d, probe, fine)
	var near := minf(NEAR, max_d * 0.5)
	var a := W.ray_clear(ox, oy, oz, dx, dy, dz, near, slim, fine)
	if a < near - 0.01:
		return a
	var bx := ox + dx * near
	var by := oy + dy * near
	var bz := oz + dz * near
	return near + W.ray_clear(bx, by, bz, dx, dy, dz, max_d - near, probe, fine)


func _place(dt: float, instant: bool) -> void:
	var C := Config
	var W := world
	var pw := pull_eff      # set-piece pull-out strength: shooting never changes it, ADS only closes it up a little
	var pull_k := pw
	var aw := aim_w * (1.0 - pw)   # in a set piece the shoulder view, free-aim look and aim distance are off
	var ad := ads_w
	var pitch0 := pitch
	pitch -= kick_p * scope_w      # scoped shot: the view jumps up and settles back (restored at the end)
	# set piece: shooting / ADS stop part-way in, not a lurch from the far boom down to the tight shoulder view
	var pw_full := pull_w
	var far_k := pull_dist
	var aim_d := maxf(C.cam_dist_aim, far_k * 0.36)
	var ads_d := maxf(C.ads_dist, far_k * 0.3)
	var outdoor := lerpf(C.cam_dist + C.cam_run_at_dist * run_at_w, C.cam_dist_strafe, strafe_w * (1.0 - pw)) * (1.0 - aw) + lerpf(C.cam_dist_aim, aim_d, pw_full) * aw
	var base_d := lerpf(outdoor, minf(outdoor, W.camera_room_dist if W.camera_room_dist > 0.0 else 3.05), room_w)     # (a world's own indoor boom: camera_room_dist)
	var pulled := lerpf(base_d, maxf(base_d, pull_dist if pull_dist > 0.0 else base_d), pw) if pw > 0.001 else base_d
	var want := pulled * (1.0 - ad) + lerpf(C.ads_dist, ads_d, pw_full) * ad

	# over-the-shoulder: shift the boom ORIGIN (and the look point) sideways first, so the boom collision starts from where the camera really is
	var ox := fx
	var oy := fy
	var oz := fz
	var focus_y := oy
	var ads_rise := 0.32 * ad * (1.0 - scope_w)
	oy += ads_rise      # collision must include the final ADS height, including overhead ramps
	var rx := -cos(yaw)
	var rz := sin(yaw)
	var side_t := 0.0
	var sg := lerpf(1.0, -1.0, pow_w)     # +1 right shoulder, -1 left (power mode); in between while it swings across
	if aw > 0.001:
		var sh := C.cam_shoulder * (1.0 - ad) + C.ads_shoulder * ad
		var sd := -1.0 if sg < 0.0 else 1.0
		side_t = sg * minf(sh, maxf(0.0, W.ray_clear(ox, oy, oz, rx * sd, 0.0, rz * sd, sh + 0.3, 0.2) - 0.3)) * aw
	if instant:
		side = side_t      # slides out gently, in at once (a wall on that side)
	else:
		var nd := U.damp(side, side_t, 28.0 if (absf(side_t) < absf(side) and side_t * side >= 0.0) else 7.0, dt)
		side = side_t if (side_t * nd > 0.0 and absf(side_t) < absf(nd)) else nd
	var sc := scope_w      # scope: the boom shrinks to the eye and the shoulder offset goes away
	ox += rx * side * (1.0 - sc)
	oz += rz * side * (1.0 - sc)

	# indoors: a slimmer probe (threads 1 m doors at an angle), a smaller gap
	var rw := room_w
	var probe := lerpf(C.cam_probe, 0.13, rw)
	_gap = lerpf(C.cam_wall_gap, 0.2, rw)
	var fine := rw > 0.01
	# indoors the boom stays flat enough for the lens to pass under the door heads (camera_room_lens_max above the feet)
	var lens_max := W.camera_room_lens_max
	var fy_ref := foot_y if not is_nan(foot_y) else oy - C.cam_height
	var room_pmax := asin(clampf((lens_max - probe - (oy - fy_ref)) / want, -0.3, 0.9)) if (lens_max > 0.0 and want > 0.3) else 1.5
	var PMAX := lerpf(1.5, minf(1.5, room_pmax), rw)     # (caps the pitch the player set; the lift goes on top of it, up to 1.5: a rise indoors is not held under the door heads)
	var lift_max := C.cam_lift_max * (1.0 - (pull_k if pull_lock else 0.0)) * ((1.0 if squeezed else 1.0 - rw) if lens_max > 0.0 else 1.0)     # a set piece keeps its angle; a low-lens room rises only when squeezed
	# indoors the view may turn up to 0.4 rad off the controls' heading (vo) to look through a doorway instead of into its jamb; it eases back once the way is clear
	var vo := view_off
	var sk := side * (1.0 - sc)
	if W.camera_no_swing and rw > 0.5 and not instant and aw < 0.05 and ad < 0.05 and sc < 0.01:
		vo_acc += dt
		if vo_acc >= 0.05:      # a handful of boom casts: 20x a second
			vo_acc = 0.0
			var pc := minf(minf(pitch, PMAX) + lift, 1.5)
			var tl := sqrt(room_travel_x * room_travel_x + room_travel_z * room_travel_z)
			var ahead := minf(0.5, maxf(0.0, W.ray_clear(fx, oy, fz, room_travel_x / tl, 0.0, room_travel_z / tl, tl * 0.5 + probe, probe, true) - probe) / tl) if tl > 0.05 else 0.0
			var room_f := func(o: float) -> float:
				var a0 := _cast(pc, yaw + o, sk, oy, want, probe, fine).free
				return minf(a0, _cast(pc, yaw + o, sk, oy, want, probe, fine, room_travel_x * ahead, room_travel_z * ahead).free if ahead > 0.0 else want)
			# the way you came (a point on your trail a boom's length back) is a cheap direction: open by construction, threads the doorway you just walked through
			var tro := NAN
			if manual_t > 0.4:
				var n := trail.size()
				var L := 0.0
				var tx := NAN
				var tz := NAN
				var ax := fx
				var az := fz
				var i := n - 1
				while i >= 0 and L < want:
					var q: Vector2 = trail[i]
					L += sqrt((q.x - ax) * (q.x - ax) + (q.y - az) * (q.y - az))
					ax = q.x
					az = q.y
					tx = ax
					tz = az
					i -= 1
				if not is_nan(tx) and L > 0.8:
					var o0 := U.wrap_angle(atan2(-(tx - fx), -(tz - fz)) - yaw)
					if absf(o0) <= 1.3:
						tro = o0
			var score := func(o: float, f: float) -> float:
				return minf(want, f) - (0.8 if (not is_nan(tro) and absf(o - tro) < 0.05) else 1.4) * absf(o)
			var best := 0.0
			var best_s: float = score.call(0.0, room_f.call(0.0))
			var cur: float = room_f.call(vo)
			if vo != 0.0 and float(score.call(vo, cur)) > best_s + 0.05:
				best = vo
				best_s = score.call(vo, cur)     # (keep the turn already made unless straight is as good)
			if minf(cur, last_tgt if not is_nan(last_tgt) else want) < want * 0.85:
				var offs: Array[float] = [0.14, -0.14, 0.27, -0.27, 0.4, -0.4]
				if not is_nan(tro):
					offs.append(tro)
					offs.append(tro * 0.5)
				for o in offs:
					var s: float = score.call(o, room_f.call(o))
					if s > best_s + 0.15:
						best_s = s
						best = o
			vo_t = best
		# (a spring with a top speed: the trail turns are up to 1.3 rad, and an exponential ease swung the view at 4 rad/s on its first frames)
		var w := 11.0
		vo_v = clampf(vo_v + (w * w * (vo_t - vo) - 2.0 * w * vo_v) * dt, -2.4, 2.4)
		vo = vo + vo_v * dt
		view_off = vo
		# not looking with the mouse / stick: the turn the view made becomes the heading, so it settles behind you
		if manual_t > 0.4 and absf(vo) > 1e-3:
			var tt := vo * (1.0 - exp(-2.5 * dt))
			yaw = U.wrap_angle(yaw + tt)
			vo -= tt
			view_off = vo
			vo_t -= tt
	else:
		vo = 0.0 if instant else U.damp(vo, 0.0, 12.0, dt)
		view_off = vo
		vo_t = 0.0
		vo_v = 0.0
	var hit := _cast(minf(minf(pitch, PMAX) + (0.0 if instant else lift), 1.5), yaw + vo, sk, oy, want, probe, fine)
	if not instant:
		# blocked boom: get round it before the camera has to crawl in against the player. The cheapest way out wins (boom length minus a cost for each radian of tilt-up / turn):
		# first rise over the obstacle; if that needs a near top-down view turn the view towards the open side instead. Never more than ~90 deg; manual look / ADS / scopes are left alone.
		lift_acc += dt
		if lift_acc >= 0.05:      # the search is several boom casts: run it 20x a second
			var ldt := lift_acc
			lift_acc = 0.0
			# (Not in the JS, user 2026-11-09.) Running at the lens with a wall behind it squeezes the boom faster than the view can turn. So while the body
			# is heading for the lens every boom here is also judged from where it will be in about half a second (never through a wall), and the way out starts that much sooner.
			var ax := room_travel_x * 1.5
			var az := room_travel_z * 1.5
			var al := sqrt(ax * ax + az * az)
			if al > 0.3:
				var ak := clampf(W.ray_clear(fx, oy, fz, ax / al, 0.0, az / al, al + 0.35, 0.2) - 0.35, 0.0, al) / al
				ax *= ak
				az *= ak
			var pre := -(ax * sin(yaw + vo) + az * cos(yaw + vo)) > 0.3
			var free_at := func(pp: float, cy: float) -> float:
				var f := _cast(pp, cy, sk, oy, want, probe, fine).free
				return minf(f, _cast(pp, cy, sk, oy, want, probe, fine, ax, az).free) if pre else f
			var bs_free: float = free_at.call(pitch, yaw + vo)
			if bs_free >= want * 0.92:
				lift_hold += ldt
				if lift_hold > C.cam_clear_hold:
					lift_t = 0.0
				swing_to = NAN
			else:
				lift_hold = 0.0
				var COST := 2.2     # metres of boom a radian of tilt (or 0.6 rad of turn per rad) is worth
				var TURN := COST
				var need := 0.0     # a rise has to reach this far to count: under a low ceiling (the block's basement) it only hovered on top of his head, worse than staying put
				if squeezed and lens_max > 0.0:
					need = 1.25
					COST = 0.5      # (a squeezed low-lens room: ceilings give a metre or two at most, so the rise has to be cheap to be taken at all)
				var best_l := 0.0
				var best_f := bs_free
				var best_s := minf(bs_free, want)
				var best_y := NAN
				if lift_max > 0.0:
					for k in range(1, 7):
						var l := lift_max * k / 6.0
						var cf: float = free_at.call(minf(minf(pitch, PMAX) + l, 1.5), yaw + vo)
						var s := minf(cf, want) - COST * l
						if s > best_s + 0.05 and cf >= need:
							best_s = s
							best_f = cf
							best_l = l
				var lift_here := best_l
				# rising alone leaves a near top-down view or a short boom: also try turning towards the open side (hip-aiming: only when really squeezed)
				if swing_ok and not (best_f >= want * 0.85 and best_l <= lift_max * 0.5) and (aw <= 0.3 or best_f < want * 0.5):
					var offs: Array[float] = [0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.6, -1.6]
					if not is_nan(swing_to):
						offs.append(U.wrap_angle(swing_to - yaw))    # keep heading for the target already chosen (no dithering between two similar sides)
					var s0 := best_s
					var turn_k := 0.3 if (W.camera_no_swing and rw > 0.5) else 0.6     # (a squeezed no-swing room: rooms are small, so a turn has to be cheap to be worth anything)
					for off in offs:
						for l: float in [0.0, lift_max * 0.5]:
							var cf: float = free_at.call(minf(minf(pitch, PMAX) + l, 1.5), yaw + off)
							var s := minf(cf, want) - COST * l - TURN * turn_k * absf(off)
							if s > maxf(best_s, s0 + 0.4):
								best_s = s
								best_f = cf
								best_l = l
								best_y = yaw + off
				# (Not in the JS, user 2026-11-09.) Until a turn has got there the boom still points at the wall: keep the rise this heading needs meanwhile,
				# or the lens is driven into the body half-way round. It lets go by itself as the heading opens up. (No more than the half rise a turn may use: never the top-down view the turn is there to avoid.)
				lift_t = best_l if is_nan(best_y) else maxf(best_l, minf(lift_here, lift_max * 0.5))
				swing_to = best_y
		var nl := maxf(0.0, U.spring_to(lift, lift_v, lift_t, 20.0 if lift_t > lift else 5.0, dt))
		lift_v = U.spring_v
		if absf(nl - lift) > 1e-4:
			lift = nl
			hit = _cast(minf(minf(pitch, PMAX) + lift, 1.5), yaw + vo, sk, oy, want, probe, fine)
		if not is_nan(swing_to):
			yaw = U.wrap_angle(yaw + clampf(U.wrap_angle(swing_to - yaw) * 6.0, -C.cam_swing_max, C.cam_swing_max) * dt)
			hit = _cast(minf(minf(pitch, PMAX) + lift, 1.5), yaw + vo, sk, oy, want, probe, fine)

	# distance: pull in at once (never clips), ease back out only after the obstruction has been gone for cam_clear_hold -> no pumping along pillars
	var target := minf(want, hit.free)
	if rw > 0.01 and not instant:
		# Anticipate jambs and desk corners along the travel direction, so the boom has time to contract before its mandatory no-clipping limit changes.
		var tl := sqrt(room_travel_x * room_travel_x + room_travel_z * room_travel_z)
		var reach := minf(1.0, maxf(0.0, W.ray_clear(hit.ox, oy, hit.oz, room_travel_x / tl, 0.0, room_travel_z / tl, tl + probe, probe, true) - probe) / tl) if tl > 0.05 else 0.0
		# (Not in the JS, user 2026-11-09: these looks ahead stopped at 0.6 m, which is inside the body, so walking along a wall or turning the view sent the camera
		# into first person with the boom itself free. A guess about the next wall never brings the lens closer than SEEN, where the body is still in view; a real wall still does.)
		const SEEN := 1.25
		for ahead: float in [0.33, 0.67, 1.0]:
			var a := minf(ahead, reach)
			var future := W.ray_clear(hit.ox + room_travel_x * a, oy, hit.oz + room_travel_z * a, hit.dx, hit.dy, hit.dz, want + 0.2, probe, true)
			target = minf(target, maxf(SEEN, future - _gap))
		# ...and along the way the view is turning (a jamb it swings onto), and a little either side of the boom (a corner closing on it): the boom starts in early and eases
		var p_now := minf(minf(pitch, PMAX) + lift, 1.5)
		var yr := clampf(yaw_rate * 0.22, -0.6, 0.6)
		if absf(yr) > 0.03:
			target = minf(target, maxf(SEEN, _cast(p_now, yaw + vo + yr, sk, oy, want, probe, fine).free))
		for s: float in [-0.22, 0.22]:
			target = minf(target, maxf(SEEN, _cast(p_now, yaw + vo + s, sk, oy, want, probe, fine).free + 0.5))
	last_tgt = target
	var obstructed := hit.free < minf(want - 0.02, clear_dist + 0.04)   # geometry is holding the boom at (or inside) its current length
	var room := rw > 0.5 and not instant
	if instant:
		clear_dist = target
		cd_v = 0.0
		occ_t = 0.0
		obs_t = 99.0
	else:
		if obstructed:
			obs_t = 0.0
		else:
			obs_t += dt
		# (Not in the JS, user 2026-11-09.) A lens squeezed in on the body does not wait to back out: the hold and the slow start are there to stop pumping
		# along pillars at a distance, and up close they left the view inside the character for most of a second with the way clear.
		var cramped := clampf((1.6 - clear_dist) / 0.8, 0.0, 1.0)
		var hold := lerpf(C.cam_clear_hold, 0.15, rw) * (1.0 - cramped)
		var out_k := lerpf(lerpf(C.cam_clear_out_k, 5.0, rw), 9.0, cramped)     # indoors walls come and go every metre: the boom goes back out sooner and quicker
		if room:
			# indoors the boom length is a critically damped spring, in quick and out slow
			var going_in := target < clear_dist
			var w := 20.0 if going_in else (lerpf(6.0, 12.0, cramped) if obs_t > hold else 0.0)     # (squeezed onto the body: back out twice as fast)
			cd_v = cd_v + (w * w * (target - clear_dist) - 2.0 * w * cd_v) * dt if w > 0.0 else U.damp(cd_v, 0.0, 20.0, dt)
			clear_dist += cd_v * dt
			if w > 0.0 and (clear_dist < target if going_in else clear_dist > target):     # (no overshoot past the target it was heading for)
				clear_dist = target
				cd_v = 0.0
			clear_dist = minf(clear_dist, want)
		else:
			if target < clear_dist:
				cd_v = 0.0
				clear_dist = U.damp(clear_dist, target, lerpf(C.cam_clear_in_k, 10.0, rw), dt)
			elif obs_t > hold:
				clear_dist = U.spring_to(clear_dist, cd_v, target, 2.0 * (out_k if obs_t < hold + 1.0 else 9.0) * (1.0 + 1.2 * clampf((target - clear_dist) / 2.5, 0.0, 1.0)), dt)    # a long way to go (just got out of a tight spot): faster
				cd_v = U.spring_v
			else:
				cd_v = 0.0
	var d := minf(clear_dist, hit.free)
	# Indoors a wall end or a door jamb that comes BETWEEN the lens and the player (the lens itself still in the open) is crossed by the spring above in a swift move,
	# the view blocked for a few frames, instead of the lens jumping in one frame. A lens that would be in a solid is pulled in at once, and nothing is hidden for more than a quarter second.
	if room and clear_dist > hit.free + 0.02:
		var lx := hit.ox + hit.dx * clear_dist
		var ly := oy + hit.dy * clear_dist
		var lz := hit.oz + hit.dz * clear_dist
		occ_t += dt
		if occ_t < 0.25 and W.ray_clear(lx, ly, lz, -hit.dx, -hit.dy, -hit.dz, 0.01, probe) > 0.0:
			d = clear_dist
	else:
		occ_t = 0.0
	pos = Vector3(hit.ox + hit.dx * d, oy + hit.dy * d, hit.oz + hit.dz * d)
	var i := 0
	# (Not in the JS, user 2026-11-09.) The guard is no help when the boom's own origin is inside camera-only scenery, which the body can walk into (MEAT SPIRE's
	# core is wrapped in a camera volume 8.1 m wide and the gastric arena's floor reaches inside it): every step in is still "solid", so it dragged the lens
	# all the way into the body. There the boom's own cast places the lens.
	var guard := not W.point_solid(hit.ox, oy, hit.oz, true)
	while guard and i < 6 and d > 0.0 and W.point_solid(pos.x, pos.y, pos.z, true):     # last-resort guard includes camera-only scenery
		d = maxf(0.0, d - 0.15)
		pos = Vector3(hit.ox + hit.dx * d, oy + hit.dy * d, hit.oz + hit.dz * d)
		i += 1
	var wat: Variant = W.water.call(&"at", pos.x, pos.z) if W.water != null else null    # a world with water: the lens never goes under it (the boom shortens, like on a floor)
	if wat != null and pos.y < float(wat) + 0.35:
		if hit.dy < -1e-3:
			d = clampf((oy - float(wat) - 0.35) / -hit.dy, 0.0, d)
			pos = Vector3(hit.ox + hit.dx * d, oy + hit.dy * d, hit.oz + hit.dz * d)
		pos.y = maxf(pos.y, float(wat) + 0.35)
	if sc > 0.001:
		# looking through a scope: slide the camera in along the boom to the eye and look straight ahead (the boom points backwards, so forward = -boom)
		d *= 1.0 - 0.97 * sc
		pos = Vector3(hit.ox + hit.dx * d, oy + hit.dy * d, hit.oz + hit.dz * d)
	look = Vector3(hit.ox, focus_y + 0.15 + 0.1 * ad, hit.oz)
	# a boom squeezed short (a door jamb, a wall at the lens) keeps looking the way the boom points.
	# (The JS did this indoors only. Everywhere now, user 2026-11-09: outdoors a boom squeezed to nothing left the lens on the focus looking at a point
	# 15 cm above itself, so the view swung straight up and rolled over: the camera "flip" against walls.)
	var lm := 1.2 * (1.0 - sc)
	if d < lm:
		var k := d - lm
		look += Vector3(hit.dx * k, hit.dy * k, hit.dz * k)
	# free aim: while aiming the view direction is the camera yaw/pitch itself (-boom), not "towards the player", so the ground / walls shortening the boom can't stop you looking up
	var fa := maxf(sc, aw)
	if fa > 0.001:
		# use the raw yaw/pitch (not the lifted boom): the lift would otherwise push the view back down and stall the upward look
		var vc := cos(pitch)
		var vdx := -sin(yaw) * vc
		var vdy := sin(pitch)
		var vdz := -cos(yaw) * vc
		look = look.lerp(Vector3(pos.x - vdx * 10.0, pos.y - vdy * 10.0, pos.z - vdz * 10.0), fa)
	dist = d
	pitch = pitch0
	boom = hit       # (the boom actually cast; for audits)
	too_close = sc < 0.01 and (d < 1.15 if too_close else d < 0.85)    # the lens is inside the character: the main loop hides the body (hysteresis, no flicker)
