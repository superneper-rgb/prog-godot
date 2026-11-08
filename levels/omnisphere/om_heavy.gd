class_name OmHeavy
extends RefCounted
## FOINT HEAVY AI (JS levels/omnisphere/heavy-ai.js, heavy.js): the combat brain of the black-and-silver heavies (assault / suppression / elite), hooked over the stock Robot's chase. Stock Robot keeps everything outside the chase (alert, stagger, search, return, death, melee swing, single bolt). MOVE context steering, acceleration-limited velocity, a turn-rate-capped body, a strafe that commits for seconds. RANGE each variant holds a ring around you. ATTACK gun line: snap / volley / sweep / lane bursts, each with a laser that LOCKS 0.22 s before the first bolt (a sidestep beats them); at most one heavy aims at a time. Ram: wind-up that locks its line late, a charge that ramps up and skids to a stop, a stun on a wall; two rams never charge together.

# ring = [near, far] metres the heavy tries to hold; close / back / strafe = walking speeds m/s; mood weights decide how often the ram presses in
const TUNE := {
	"assault": {"ring": [7.0, 11.0], "close": 4.1, "back": 2.6, "strafe": 2.5, "press": 0.45, "charge": true, "gun": false},
	"suppression": {"ring": [10.0, 16.5], "close": 3.9, "back": 3.0, "strafe": 2.7, "press": 0.0, "charge": false, "gun": true},
	"elite": {"ring": [8.0, 13.0], "close": 4.2, "back": 3.0, "strafe": 2.8, "press": 0.25, "charge": true, "gun": true},
}
# burst kinds: n bolts, gap between bolts, aim time (laser on), spread (radians, 1 sigma-ish), lead (how far ahead of a moving player the lock leads), sweep (half-arc)
const BURSTS := {
	"snap": {"n": 3, "gap": 0.1, "aim": 0.45, "spread": 0.022, "lead": 1.0, "sweep": 0.0},
	"volley": {"n": 6, "gap": 0.13, "aim": 0.75, "spread": 0.045, "lead": 1.0, "sweep": 0.0},
	"sweep": {"n": 9, "gap": 0.095, "aim": 0.7, "spread": 0.015, "lead": 0.0, "sweep": 0.2},
	"lane": {"n": 4, "gap": 0.12, "aim": 0.6, "spread": 0.03, "lead": 2.3, "sweep": 0.0},
}
const BOLT_SPEED := 34.0
const LOCK_T := 0.22
const MAX_TURN := 4.4
const VARIANTS := {"assault": {"hp": 300.0, "scale": 1.4}, "suppression": {"hp": 220.0, "scale": 1.3}, "elite": {"hp": 500.0, "scale": 1.55}}
const BARKS := {
	"pain": ["DAMAGE IS BILLABLE.", "ARMOUR AT SIXTY PERCENT. ACCEPTABLE.", "LOGGED.", "THAT PANEL WAS NEW."],
	"die": ["DECOMMISSIONED...", "TELL... THE SHAREHOLDERS...", "WARRANTY... VOID..."],
	"alert": ["ASSET THREAT.", "UNSCHEDULED VISITOR.", "ENGAGING. NO REFUNDS.", "YOU ARE TRESPASSING ON A GROWTH OPPORTUNITY."],
	"shoot": ["CLEARING THE LANE.", "BRACE.", "SUPPRESSING.", "HOLD STILL FOR PROCESSING.", "MOVE."],
}

var r: Robot
var variant := "assault"
var T: Dictionary
var t := 0.0
var active := false
var vx := 0.0
var vz := 0.0
var head := NAN
var dir := 1.0
var dir_t := 0.0
var hold_t := 0.0
var flip_lock := 0.0
var mood := "stalk"
var mood_t := 0.0
var fade_t := 0.0
var fade_cd := 0.0
var poke_cd := 0.0
var post_t := 0.0
var block_t := 0.0
var corner_t := 0.0
var melee_cd := 0.0
var skid := false
var since_sees := 9.0
var pvx := 0.0
var pvz := 0.0
var lpx := NAN
var lpz := 0.0
var last_kind := ""
var last_burst := ""
var bursts := 0
var burst: Dictionary = {}
var lock_yaw := NAN
var spark_t := 0.0
var hv_t := 0.0
var hv_t0 := 0.0
var hv_cd := 0.0
var hv_s_cd := 0.0
var hv_locked := false
var hv_lock: Variant = null      # Vector3
var hv_hit := false
var hv_dir := Vector2.ZERO
var hv_n := 0
var hv_tot := 0
var hv_gloat := false
var yaw_rate := 0.0
var last_yaw := 0.0
var laser: MeshInstance3D = null
var laser_mesh: ImmediateMesh = null
var laser_mat: StandardMaterial3D = null
var dot: MeshInstance3D = null


static func wrap_a(a: float) -> float:
	return atan2(sin(a), cos(a))


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


## the stock robot turned into FOINT's corporate killing machine at spawn time (JS fointHeavy)
static func install(p_r: Robot, p_variant: String, root: Node3D) -> OmHeavy:
	var v: Dictionary = VARIANTS.get(p_variant, VARIANTS.assault)
	var o := OmHeavy.new()
	o.r = p_r
	o.variant = p_variant if VARIANTS.has(p_variant) else "assault"
	o.T = TUNE[o.variant]
	p_r.heavy = true
	p_r.heavy_kind = o.variant
	p_r.max = v.hp
	p_r.hp = v.hp
	p_r.r = 0.72 * float(v.scale) / 1.3
	p_r.h = (p_r.h if p_r.h != 0.0 else 1.8) * float(v.scale)
	p_r.visual_scale = v.scale
	p_r.bark_set = BARKS
	p_r.voice = 0.55 + randf() * 0.15
	o.hv_cd = 1.5 + randf() * 2.0
	o.hv_s_cd = 1.0 + randf() * 2.0
	o.dir = 1.0 if randf() < 0.5 else -1.0
	o.dir_t = _rnd(0.5, 1.5)
	o.mood_t = _rnd(1.0, 3.0)
	o.poke_cd = _rnd(2.0, 5.0)
	o.last_yaw = p_r.yaw
	p_r.pursue_hook = o.brain
	# the suppression laser: a red line from the left cannon to the player while it aims
	if o.variant != "assault":
		o.laser_mesh = ImmediateMesh.new()
		o.laser = MeshInstance3D.new()
		o.laser.mesh = o.laser_mesh
		o.laser_mat = VhKit.unlit(0xff2020, 0.9)
		o.laser.material_override = o.laser_mat
		o.laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		o.laser.extra_cull_margin = 200.0
		o.laser.visible = false
		root.add_child(o.laser)
		o.dot = MsKit.sprite8(root, 0xff3020, 0.9, 0.35)
		o.dot.visible = false
	return o


## per frame from the level: drop a special the stock states interrupted, the yaw rate for the view, the laser (JS the update wrapper and updateHeavies)
func tick(dt: float, P: Player) -> void:
	if r.hv != &"" and (r.state != &"pursue" or r.dead):      # stagger / death / search / a stock attack in progress: drop the special
		abort()
	if dt > 0.0:
		yaw_rate += (wrap_a(r.yaw - last_yaw) / dt - yaw_rate) * minf(1.0, dt * 12.0)
		r.yaw_rate = yaw_rate
		last_yaw = r.yaw
	if r.state != &"pursue":
		active = false
	if laser == null:
		return
	var on := not r.dead and (r.hv == &"aimS" or (r.hv == &"burst" and hv_lock != null)) and P != null
	laser.visible = on
	dot.visible = on
	if not on:
		return
	var s := sin(r.yaw)
	var c := cos(r.yaw)
	var from := Vector3(r.x + s * 1.1 + c * 0.5, r.y + 1.55 * ((r.h if r.h != 0.0 else 2.0) / 2.0), r.z + c * 1.1 - s * 0.5)
	var to: Vector3 = hv_lock if hv_locked and hv_lock != null else Vector3(P.x, P.y + 1.05, P.z)
	laser_mesh.clear_surfaces()
	laser_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	laser_mesh.surface_add_vertex(from)
	laser_mesh.surface_add_vertex(to)
	laser_mesh.surface_end()
	dot.global_position = to
	laser_mat.albedo_color = Color.hex(0xffe8d0ff if hv_locked else 0xff2020ff)
	laser_mat.albedo_color.a = 1.0 if hv_locked else 0.5 + 0.5 * absf(sin(Time.get_ticks_msec() * 0.02))      # white = locked, it fires where the dot is
	MsKit.tint(dot, MsKit.lin(0xffe8d0 if hv_locked else 0xff3020))
	dot.scale = Vector3.ONE * (0.5 if hv_locked else 0.35)


func dispose() -> void:
	if laser != null:
		laser.queue_free()
		dot.queue_free()


## advance yaw toward ang: eased (rate k), and never faster than max_w rad/s, so a heavy swings round like a heavy
func _turn_to(ang: float, k: float, dt: float, max_w: float = MAX_TURN) -> void:
	var e := wrap_a(ang - r.yaw)
	r.yaw = wrap_a(r.yaw + clampf(e * (1.0 - exp(-k * dt)), -max_w * dt, max_w * dt))


## distance (0-3.6 m) a heavy can walk along (dx, dz) before something blocks it: probes at 0.8 / 1.7 / 2.7 / 3.6 m, ledges checked on the first two
func _clear_dist(dx: float, dz: float) -> float:
	var d := 0.0
	for m: float in [0.8, 1.7, 2.7, 3.6]:
		if not r._free(r.x + dx * m, r.z + dz * m):
			return d
		if m < 2.0 and r.ledge_safe and not r._edge_ok(dx, dz):
			return d
		d = m
	return d


## pick a walkable heading for the wanted world velocity: the wish itself when it is clear; otherwise the best of 16 headings by agreement and free room, favouring the last one. [x, z, k, blocked]
func _steer(wx: float, wz: float) -> Array:
	var m := U.hyp(wx, wz)
	if m < 0.05:
		return [0.0, 0.0, 1.0, false]
	var ux := wx / m
	var uz := wz / m
	if r.unstick_t > 0.0:
		var a := r.unstick_dir * 1.3
		var c := cos(a)
		var s := sin(a)
		var nx := ux * c - uz * s
		uz = ux * s + uz * c
		ux = nx
	if _clear_dist(ux, uz) >= 2.7:
		head = atan2(ux, uz)
		return [ux, uz, 1.0, false]
	var has := false
	var bx := 0.0
	var bz := 0.0
	var ba := 0.0
	var bdot := 0.0
	var bcl := 0.0
	var best_s := -9.0
	for i in 16:
		var a := i * PI / 8.0
		var dx := sin(a)
		var dz := cos(a)
		var d_ := dx * ux + dz * uz
		if d_ < -0.1:
			continue
		var cl := _clear_dist(dx, dz)
		if cl < 0.8:
			continue
		var near := 0.14 if not is_nan(head) and absf(wrap_a(a - head)) < 0.4 else 0.0
		var sc := maxf(d_, 0.0) * (0.5 + 0.5 * cl / 3.6) + near
		if sc > best_s:
			best_s = sc
			has = true
			bx = dx
			bz = dz
			ba = a
			bdot = d_
			bcl = cl
	if not has or bdot < 0.15:
		return [0.0, 0.0, 0.0, true]
	head = ba
	return [bx, bz, clampf(0.45 + bcl / 3.6 * 0.55, 0.45, 1.0) * clampf(bdot * 1.15, 0.4, 1.0), true]


## accelerate the smoothed velocity toward (tx, tz): 6.5 m/s^2 up, 9 m/s^2 down, so a reversal passes through a standstill instead of snapping
func _ease(tx: float, tz: float, dt: float, acc: float, dec: float) -> void:
	var ex := tx - vx
	var ez := tz - vz
	var e := U.hyp(ex, ez)
	if e < 1e-4:
		return
	var slowing := U.hyp(tx, tz) < U.hyp(vx, vz)
	var f := minf(1.0, (dec if slowing else acc) * dt / e)
	vx += ex * f
	vz += ez * f


func _walk(dt: float, tx: float, tz: float, acc: float = 6.5, dec: float = 9.0) -> void:
	_ease(tx, tz, dt, acc, dec)
	var sp := U.hyp(vx, vz)
	r.vx = vx      # _go then has nothing to lerp: this file owns the acceleration
	r.vz = vz
	r._go(dt, atan2(vx, vz), sp, sp < 0.04)
	vx = r.vx      # the body (collision, ledge guard) has the last word
	vz = r.vz


func _others(test: Callable) -> int:
	var n := 0
	for o: Robot in r.E.robots:
		if o != r and not o.dead and o.pursue_hook.is_valid() and test.call(o):
			n += 1
	return n


func _gun_busy() -> bool:
	return _others(func(o: Robot) -> bool: return o.hv == &"aimS" or o.hv == &"burst") > 0


func _ram_busy() -> bool:
	return _others(func(o: Robot) -> bool: return o.hv == &"wind" or o.hv == &"go") > 0


## end whatever special the heavy was in (stagger, death, losing the player): nothing is left half done
func abort() -> void:
	if r.hv == &"" and not hv_locked:
		return
	r.hv = &""
	hv_locked = false
	hv_lock = null
	if r.slot == &"shot":
		r.slot = &""
	hv_cd = maxf(hv_cd, 1.2)
	hv_s_cd = maxf(hv_s_cd, 1.0)


## the muzzle of the cannon that fires next (cannons alternate)
func _muzzle(side: float) -> Vector3:
	var s := sin(r.yaw)
	var c := cos(r.yaw)
	return Vector3(r.x + s * 1.1 + c * 0.5 * side, r.y + 1.55 * ((r.h if r.h != 0.0 else 2.0) / 2.0), r.z + c * 1.1 - s * 0.5 * side)


# ------------------------------------------------------------------------------------------------ the chase
func brain(dt: float, P: Player, _dx0: float, _dz0: float, _dist0: float, sees: bool) -> void:
	var k: Robot.Known = r.known
	t += dt
	hv_cd = maxf(0.0, hv_cd - dt)
	hv_s_cd = maxf(0.0, hv_s_cd - dt)
	hv_t -= dt
	dir_t -= dt
	hold_t -= dt
	flip_lock -= dt
	mood_t -= dt
	fade_t -= dt
	fade_cd -= dt
	poke_cd -= dt
	melee_cd -= dt
	post_t -= dt
	since_sees = 0.0 if sees else since_sees + dt
	if r.state_t < 0.05 and r.prev == &"recover":      # just finished a stock swing / shot: fade back instead of standing in its face
		post_t = 0.9
	# player velocity (smoothed finite difference: the player object's own vx is not always set)
	if not is_nan(lpx) and dt > 0.0:
		var kv := minf(1.0, dt * 8.0)
		pvx += ((P.x - lpx) / dt - pvx) * kv
		pvz += ((P.z - lpz) / dt - pvz) * kv
		if absf(P.x - lpx) > 6.0:
			pvx = 0.0
			pvz = 0.0
	lpx = P.x
	lpz = P.z
	var eng := sees or r.seen_t < 0.45 or r.hv != &""
	if not active:
		active = true
		vx = r.vx
		vz = r.vz
		head = NAN
	if not eng:      # lost him: walk to where he was last seen (same give-up rules as the stock chase), then search
		if k == null:
			r.set_(&"search")
			return
		var kd := U.hyp(k.x - r.x, k.z - r.z)
		var lose: float = Config.ai_lose_time
		if (r.seen_t > lose and kd < 1.6) or r.seen_t > lose + 6.0 or r.stuck_n >= 4:
			r.set_(&"search")
			r.scan_t = 0.0
			return
		var st0 := _steer(k.x - r.x, k.z - r.z)
		var sp0: float = 2.2 if kd < 3.0 else float(T.close)
		_walk(dt, float(st0[0]) * sp0 * float(st0[2]), float(st0[1]) * sp0 * float(st0[2]))
		_turn_to(atan2(vx, vz) if U.hyp(vx, vz) > 0.4 else atan2(k.x - r.x, k.z - r.z), 5.0, dt)
		return
	var tpx: float = P.x if sees or k == null else k.x
	var tpz: float = P.z if sees or k == null else k.z
	var dx := tpx - r.x
	var dz := tpz - r.z
	var dist := U.hyp(dx, dz)
	if dist == 0.0:
		dist = 0.01
	var ux := dx / dist
	var uz := dz / dist
	var bearing := atan2(dx, dz)
	var closing := -(pvx * ux + pvz * uz)      # + closing: he runs at us
	var lat := pvx * uz - pvz * ux      # lat: his sideways speed across our view
	if r.hv != &"":
		_act(dt, P, tpx, tpz, dx, dz, dist, bearing)
		return
	# ---------------------------------------------------------------- choose an attack
	var face_err := absf(wrap_a(bearing - r.yaw))
	var face := face_err < 0.5
	if sees and not P.dead and r.state_t > 0.35:
		# the ram: needs a clear lane, a ring-and-a-bit of room, and no other ram already coming
		if T.charge and dist > 4.5 and dist < 19.0 and hv_cd <= 0.0 and not _ram_busy() and r.world.ray_clear(r.x, r.y + 1.0, r.z, ux, 0.0, uz, dist, 0.55) >= dist - 1.0:
			if not T.gun or last_kind != "ram" or randf() < 0.35:
				_start_ram()
				return
		if T.gun and dist > 7.0 and dist < 26.0 and hv_s_cd <= 0.0:
			if _gun_busy():      # volleys are staggered: one heavy aims at a time
				hv_s_cd = _rnd(0.4, 0.9)
			elif face or face_err < 0.9:
				var m := _muzzle(1.0)
				var lim := minf(dist, 8.0)
				if r.world.ray_clear(m.x, m.y, m.z, ux, 0.0, uz, lim, 0.2) >= lim - 0.2:
					_start_gun(dist, closing)
					return
				hv_s_cd = 0.3
				dir = -dir
		# stock single bolt: the ram's only ranged attack (a poke while its charge recharges), and an emergency shot for anyone
		if not T.gun and dist > 8.0 and dist < 22.0 and hv_cd > 1.2 and poke_cd <= 0.0 and face and r.E.slot_free(&"shot", r):
			poke_cd = _rnd(4.5, 7.0)
			r._begin(&"shot", dist)
			return
		# stock melee: whoever finds you inside its reach hits you; the gun line only does it cornered (below)
		if dist <= 2.65 and face and r.E.slot_free(&"melee", r) and (T.charge or corner_t > 1.2) and melee_cd <= 0.0:
			corner_t = 0.0
			melee_cd = 2.5
			r._begin(&"melee", dist)
			return
	# ---------------------------------------------------------------- where to stand
	if mood_t <= 0.0:
		mood = "press" if randf() < float(T.press) else "stalk"
		mood_t = _rnd(3.0, 5.0) if mood == "press" else _rnd(3.5, 6.5)
	var near: float = T.ring[0]
	var far: float = T.ring[1]
	if mood == "press":
		near = 1.8
		far = 2.5
	# reactions to what the player does: rush the gun line and it fades (and bursts as it goes); run away from it and it closes at a trot
	var back_boost := 1.0
	if not T.charge and dist < 8.0 and closing > 2.5 and fade_cd <= 0.0:
		fade_t = _rnd(0.7, 1.0)
		fade_cd = 3.8
		if hv_s_cd > 1.1:
			hv_s_cd = _rnd(0.5, 0.9)
	if fade_t > 0.0 or post_t > 0.0:
		back_boost = 1.45 if fade_t > 0.0 else 1.15
		near = maxf(near, dist + 3.0)
	var radial := 0.0
	if dist > far:
		radial = clampf((dist - far) / 4.0, 0.0, 1.0)
	elif dist < near:
		radial = -clampf((near - dist) / 2.5, 0.0, 1.0)
	if sees and not T.charge and dist < 4.0 and radial < 0.0:
		corner_t += dt
	else:
		corner_t = maxf(0.0, corner_t - dt * 2.0)
	var vr: float = radial * float(T.close) * (1.15 if closing < -1.5 else 1.0) if radial > 0.0 else radial * float(T.back) * back_boost
	# strafe: commits for seconds, mirrors a runner now and then, never flips twice inside 0.8 s, flips when the lane is blocked
	var tx := uz      # tangent: dir +1 circles to the right of the line to him
	var tz := -ux
	if dir_t <= 0.0:
		dir_t = _rnd(1.5, 3.4)
		if absf(lat) > 3.0:
			dir = 1.0 if lat > 0.0 else -1.0
		elif randf() < 0.6:
			dir = -dir
			hold_t = 0.22      # a beat of stillness when it changes its mind
		flip_lock = 0.8
	if flip_lock <= 0.0 and _clear_dist(tx * dir, tz * dir) < 1.6:
		dir = -dir
		flip_lock = 0.8
		dir_t = _rnd(1.2, 2.4)
	var lat_spd: float = 0.0 if hold_t > 0.0 else float(T.strafe) * (1.0 - 0.5 * absf(radial)) * (0.7 if mood == "press" else 1.0)
	var wx := ux * vr + tx * dir * lat_spd
	var wz := uz * vr + tz * dir * lat_spd
	var st := _steer(wx, wz)
	var want := U.hyp(wx, wz)
	if st[3]:
		block_t += dt
	else:
		block_t = maxf(0.0, block_t - dt * 2.0)
	if block_t > 0.35 and flip_lock <= 0.0:
		dir = -dir
		flip_lock = 0.8
		block_t = 0.0
	_walk(dt, float(st[0]) * want * float(st[2]), float(st[1]) * want * float(st[2]))
	# face him (a heavy turns at most MAX_TURN rad/s); when it cannot see him it looks where it is going
	_turn_to(bearing if sees or since_sees < 0.6 else atan2(vx, vz), 6.0 if sees else 4.0, dt)


# ------------------------------------------------------------------------------------------------ the ram
func _start_ram() -> void:
	r.hv = &"wind"
	hv_t = 0.7
	hv_cd = _rnd(5.0, 7.5)
	last_kind = "ram"
	lock_yaw = NAN
	spark_t = 0.0
	r.E.barks.say(r, "shoot")
	r.E.push({"t": "robotAtk", "id": r.id, "kind": "melee", "ph": "windup", "x": r.x, "y": r.y, "z": r.z})


func _charge(dt: float, P: Player, dx: float, dz: float, bearing: float) -> void:
	var E := r.E
	var fx: Variant = Game.fx
	if r.hv == &"wind":
		_walk(dt, 0.0, 0.0, 5.0, 14.0)      # plants smoothly instead of stopping dead
		if hv_t > LOCK_T:
			_turn_to(bearing, 8.0, dt, 6.5)
		else:      # tracks, then LOCKS: sidestep after the strobe speeds up
			if is_nan(lock_yaw):
				lock_yaw = r.yaw
			_turn_to(lock_yaw, 20.0, dt, 8.0)
		spark_t -= dt
		if fx != null and spark_t <= 0.0:      # pawing the deck
			spark_t = 0.11
			fx.sparks(Vector3(r.x + sin(r.yaw) * 0.6, r.y + 0.1, r.z + cos(r.yaw) * 0.6), 3, 2.2, null, 0xffd080)
		if hv_t <= 0.0:
			r.hv = &"go"
			hv_t = 1.3
			hv_t0 = hv_t
			hv_hit = false
			r.slot = &"melee"
			hv_dir = Vector2(sin(r.yaw), cos(r.yaw))
			E.push({"t": "robotAtk", "id": r.id, "kind": "melee", "ph": "go", "x": r.x, "y": r.y, "z": r.z})
		return
	var el := hv_t0 - hv_t
	var u := clampf(el / 0.38, 0.0, 1.0)
	var spd := 15.5 * u * (2.0 - u)      # ramps up over 0.38 s: you see it get going
	if el < 0.5:      # a little steering early on, none once it is up to speed
		var cur := atan2(hv_dir.x, hv_dir.y)
		var a := cur + clampf(wrap_a(atan2(dx, dz) - cur), -0.65 * dt, 0.65 * dt)
		hv_dir = Vector2(sin(a), cos(a))
	r._go(dt, atan2(hv_dir.x, hv_dir.y), spd, false)
	r.yaw = atan2(hv_dir.x, hv_dir.y)
	var sp := U.hyp(r.vx, r.vz)
	var pdx := P.x - r.x
	var pdz := P.z - r.z
	if not hv_hit and U.hyp(pdx, pdz) < (r.r if r.r != 0.0 else 0.7) + 1.3 and absf(wrap_a(atan2(pdx, pdz) - r.yaw)) < 1.1 and absf(P.y - r.y) < 2.0:
		hv_hit = true
		E.push({"t": "robotAtk", "id": r.id, "kind": "melee", "ph": "hit", "x": P.x, "y": P.y + 1.0, "z": P.z})
		if not P.dead:
			E.c.hurt_player(P, 34.0, r.x, r.z, "melee")
			P.vx += hv_dir.x * 14.0
			P.vz += hv_dir.y * 14.0
			P.vy = maxf(P.vy, 7.0)
			P.grounded = false
		if fx != null:
			fx.shake = maxf(fx.shake, 0.9)
		r.slot = &""
		r.hv = &"rest"
		hv_t = 0.8
		vx = r.vx
		vz = r.vz
		skid = true
		hv_gloat = true      # it hit: skids on, then turns to look at what it did
		return
	if el > 0.45 and sp < 0.45 * spd:      # ran into something: stunned against it (the opening)
		r.hv = &"stuck"
		hv_t = 1.15
		r.slot = &""
		E.push({"t": "robotAtk", "id": r.id, "kind": "melee", "ph": "miss", "x": r.x + hv_dir.x * 1.2, "y": r.y + 1.0, "z": r.z + hv_dir.y * 1.2})
		if fx != null:
			fx.shake = maxf(fx.shake, 0.5)
			fx.sparks(Vector3(r.x + hv_dir.x * 1.2, r.y + 1.2, r.z + hv_dir.y * 1.2), 18, 5.0, null, 0xffd080)
		return
	if hv_t <= 0.0:
		r.hv = &"rest"
		hv_t = 0.75
		r.slot = &""
		vx = r.vx
		vz = r.vz
		skid = true


# ------------------------------------------------------------------------------------------------ the gun line
func _start_gun(dist: float, closing: float) -> void:
	var kinds: Array = ["snap", "volley", "sweep", "lane"].filter(func(n: String) -> bool: return n != last_burst)
	var kind: String = kinds[randi() % kinds.size()]
	if bursts == 0:
		kind = "snap"
	elif closing > 2.5 and dist < 12.0:      # an opening burst is a warning; a rush gets the quick one; a runner the lane burst
		kind = "snap"
	elif closing < -2.5:
		kind = "lane"
	burst = (BURSTS[kind] as Dictionary).duplicate()
	burst["kind"] = kind
	burst["warn"] = bursts == 0
	last_burst = kind
	last_kind = "gun"
	bursts += 1
	r.hv = &"aimS"
	hv_t = burst.aim
	r.slot = &"shot"
	hv_locked = false
	hv_lock = null
	if randf() < 0.5:
		r.E.barks.say(r, "shoot")
	r.E.push({"t": "robotAtk", "id": r.id, "kind": "shot", "ph": "windup", "x": r.x, "y": r.y, "z": r.z})


func _gun(dt: float, P: Player, tpx: float, tpz: float, dx: float, dz: float, dist: float, bearing: float) -> void:
	if r.hv == &"aimS":
		_walk(dt, 0.0, 0.0, 5.0, 12.0)
		if not hv_locked:
			_turn_to(bearing, 5.5, dt)
			r.aim = clampf(atan2(P.y + 1.0 - (r.y + 1.6), maxf(0.5, U.hyp(tpx - r.x, tpz - r.z))), -0.5, 0.6)
			if hv_t <= LOCK_T:      # lock: the laser freezes (and goes white) on where he WILL be when the first bolt arrives
				var flight := dist / BOLT_SPEED
				var ld := float(burst.lead) * (flight + 0.12)
				hv_locked = true
				var lock := Vector3(tpx + pvx * ld, P.y + 1.05, tpz + pvz * ld)
				if burst.warn:      # the first burst of a fight goes wide: a warning, not a hit
					var dd := dist if dist != 0.0 else 1.0
					var o := 1.5 * (dir if dir != 0.0 else 1.0)
					lock.x += dz / dd * o
					lock.z -= dx / dd * o
				var m := _muzzle(1.0)
				var ddx := lock.x - m.x
				var ddz := lock.z - m.z
				var d2 := U.hyp(ddx, ddz)
				if d2 == 0.0:
					d2 = 1.0
				if r.world.ray_clear(m.x, m.y, m.z, ddx / d2, 0.0, ddz / d2, d2, 0.15) < d2 - 0.5:      # never lead him through a wall
					lock.x = tpx
					lock.z = tpz
				hv_lock = lock
		else:
			var l0: Vector3 = hv_lock
			_turn_to(atan2(l0.x - r.x, l0.z - r.z), 9.0, dt, 6.0)
		if hv_t <= 0.0:
			r.hv = &"burst"
			hv_n = burst.n
			hv_tot = burst.n
			hv_t = 0.0
		return
	# burst
	_walk(dt, 0.0, 0.0, 5.0, 12.0)
	var lk: Vector3 = hv_lock
	var sweep_a: float = (-1.0 + 2.0 * (1.0 - float(hv_n) / float(hv_tot))) * float(burst.sweep) if float(burst.sweep) != 0.0 else 0.0
	_turn_to(atan2(lk.x - r.x, lk.z - r.z) + sweep_a, 10.0, dt, 7.0)
	if hv_t <= 0.0 and hv_n > 0:
		hv_n -= 1
		hv_t = burst.gap
		var side := 1.0 if hv_n % 2 == 1 else -1.0
		var m := _muzzle(side)
		var d := lk - m
		var ln := d.length()
		if ln == 0.0:
			ln = 1.0
		d /= ln
		var sp := float(burst.spread) * (0.65 + dist / 40.0)
		var a := sweep_a + (randf() + randf() - 1.0) * sp
		var ca := cos(a)
		var sa := sin(a)
		r.E.fire(r, m.x, m.y, m.z, d.x * ca + d.z * sa, d.y + (randf() - 0.5) * sp, -d.x * sa + d.z * ca, {"kind": "plasma", "speed": BOLT_SPEED, "dmg": 7.0, "r": 0.18})
		r.fire_t = 0.12
		if hv_n == 0:
			r.hv = &"rest"
			hv_t = _rnd(0.6, 0.95)
			hv_locked = false
			r.slot = &""
			hv_s_cd = _rnd(2.4, 4.2)
			hv_lock = null
			if randf() < 0.22 and burst.kind != "volley":      # now and then a second burst right behind the first
				hv_s_cd = _rnd(0.3, 0.5)


## a special in progress: ram and gun line actions, the rest pause (kept moving at a drift so it does not freeze between bursts)
func _act(dt: float, P: Player, tpx: float, tpz: float, dx: float, dz: float, dist: float, bearing: float) -> void:
	if r.hv == &"wind" or r.hv == &"go":
		_charge(dt, P, dx, dz, bearing)
		return
	if r.hv == &"aimS" or r.hv == &"burst":
		_gun(dt, P, tpx, tpz, dx, dz, dist, bearing)
		return
	if r.hv == &"rest" or r.hv == &"stuck":
		r.fire_t = 0.0
		if r.hv == &"stuck":
			_walk(dt, 0.0, 0.0, 5.0, 14.0)
		elif skid:      # a charge skids to a stop
			var f := exp(-4.2 * dt)
			vx *= f
			vz *= f
			_walk(dt, vx, vz)
		else:      # between bursts: a slow drift sideways, eyes on him
			var dd := U.hyp(dx, dz)
			if dd == 0.0:
				dd = 1.0
			var v := float(T.strafe) * 0.4 * dir
			var st := _steer(dz / dd * v, -dx / dd * v)
			_walk(dt, float(st[0]) * absf(v) * float(st[2]), float(st[1]) * absf(v) * float(st[2]), 4.0, 8.0)
		_turn_to(bearing, 4.0 if hv_gloat else 5.0, dt)
		if hv_t <= 0.0:
			r.hv = &""
			hv_gloat = false
			skid = false
			dir_t = minf(dir_t, _rnd(0.2, 0.8))
		return
	abort()
