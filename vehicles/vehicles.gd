class_name Vehicles
extends Node
## Drivable vehicles (JS vehicles/vehicles.js): arcade-fluid physics on the game's World, enter/exit, chase camera, engine audio, run-over damage, the seated driver.
##   Shared by every level: a level spawns vehicles with its own parent group, handling and surface rules (spawn(type, x, z, yaw, y, opts)), groups them under an `owner` tag and removes them with clear(owner). Nothing here knows about any level.
##   Fixed simulation: the physics runs in STEP-second steps whatever the frame rate (bounded per frame), the pose drawn is interpolated between the last two steps.
##   Getting in and out is played, not cut: the character walks round to the driver's door, the door opens, it turns its back to the seat, sits down on the sill facing out, swings its legs in and the door shuts; out is the same backwards.
##   Crashes: walls glance, vehicles trade impulses by mass. Impacts, bullets and blasts cost hit points and dent the body (vehicle_damage.gd); a car that blows up hurts and shoves what is near and can set off the next one.
## ENGINE DIFFERENCE: World answers ground and wall probes natively, so there is no gather / groundFast / rayFast list. The engine's oscillators are looped waves with a moving pitch and filter. Not ported yet: the Mustang and the Scorpion's models and tail, and traffic cars handed over (addSource exists, knock does not).

const STEP := 1.0 / 60.0
const MAX_STEPS := 6
const SHIFT_T := 0.1
const RAYS := 12
const PLAYER_MASS := 1.5
const CAR_E := 0.18
const CAR_MU := 0.3
const TC := 1.3
const TCAP := 0.92
const GEARS := [0.24, 0.42, 0.62, 0.82, 1.06]
const CAM_BASE := {"dist": 8.2, "height": 1.9, "pitch": 0.3, "side": 0.0, "dist_gain": 2.2, "fov_gain": 7.0, "look": 0.12}
const AUDIO_RATE := 24000


## Handling, one block per vehicle (JS HANDLING). Units: metres, seconds, radians. A spec overrides what it changes.
class Handling:
	var top_speed := 30.0
	var boost_speed := 30.0
	var reverse_speed := 9.0
	var accel := 14.0
	var accel_curve := 1.7
	var accel_at_top := 0.18
	var brake := 34.0
	var coast := 1.3
	var rolling := 6.0
	var drag := 0.0018
	var reverse_delay := 0.28
	var steer_low := 0.58
	var steer_high := 0.11
	var steer_fade := 0.85
	var steer_in := 2.7
	var steer_in_fast := 1.5
	var steer_out := 5.5
	var steer_counter := 8.0
	var pad_response := 16.0
	var assist := 0.55
	var mu := 1.6
	var g_tyre := 9.8
	var cg_h := 0.5
	var drive := "all"
	var brake_bias := 0.62
	var slip_peak_f := 0.22
	var slip_peak_r := 0.15
	var yaw_inertia := 1.0
	var yaw_damp := 0.5
	var rear_grip := 1.15
	var hb_mu := 0.38
	var slide_recover := 3.2
	var handbrake_decel := 7.0
	var gravity := 26.0
	var hill_gravity := 0.85
	var suspension := 9.0
	var bounce := 0.22
	var body_freq := 11.0
	var body_damp := 0.42
	var slide_max := 0.6
	var stab := 34.0
	var drift_grip := 0.74
	var drift_push := 0.5
	var mass := 1400.0
	var hp := 900.0
	var crash := 4.6


class VWheel:
	var pivot: Node3D
	var spin: Node3D
	var front := false


## What a type's build gives: root (+Z forward, +X left, origin under the middle of the car), chassis, wheels, sizes, the seat, and callables.
class VModel:
	var root: Node3D
	var chassis: Node3D
	var wheels: Array[VWheel] = []
	var wheel_r := 0.33
	var hl := 2.2
	var hw := 1.0
	var wheelbase := 2.8
	var axle_f := 1.4
	var axle_r := -1.4
	var track := 0.85
	var height := 1.4
	var seat: Variant = null      # {x, y, z, scale, roof, recline, wheel: {x, y, z, tilt, r}} (roof: the inside of the roof / canopy over the head; recline: a low sports seat, rad)
	var cb: Variant = null        # {hw, hl, ox}: the footprint of everything you can see
	var door := Callable()
	var door_info: Variant = null
	var brake := Callable()
	var set_lights := Callable()
	var steer_wheel := Callable()
	var update := Callable()
	var lights := false


class Prev:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var spin := 0.0
	var c_pitch := 0.0
	var c_roll := 0.0
	var c_y := 0.0
	var steer_ang := 0.0


class Veh:
	var type := ""
	var spec: Dictionary = {}
	var h: Handling
	var model: VModel
	var owner_ := "default"
	var world: World
	var parent: Node3D
	var surface := Callable()
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var yaw := 0.0
	var pitch := 0.0
	var roll := 0.0
	var vx := 0.0
	var vz := 0.0
	var vy := 0.0
	var pvx := 0.0
	var pvz := 0.0
	var yaw_rate := 0.0
	var steer := 0.0
	var grounded := true
	var gvy := 0.0
	var nitro := 1.0
	var nitro_cd := 0.0
	var ax_s := 0.0
	var ay_s := 0.0
	var c_pv := 0.0
	var c_rv := 0.0
	var spin_up := 0.0
	var lock_up := 0.0
	var slide := 0.0
	var c_pitch := 0.0
	var c_roll := 0.0
	var c_y := 0.0
	var c_yv := 0.0
	var speed := 0.0
	var f := 0.0
	var l := 0.0
	var spin := 0.0
	var hb := 0.0
	var hb_t := 0.0
	var rev_lock := 0.0
	var trac := 1.0
	var skid := 0.0
	var bump := 0.0
	var last_hit := 0.0
	var hit_dir: Variant = null
	var home := Vector4.ZERO      # x, y, z, yaw
	var driver := false
	var hit_cd: Dictionary = {}
	var skid_t := 0.0
	var hit_feel := 0.0
	var lit_t := -1.0
	var steer_ang := 0.0
	var on_enter := Callable()
	var on_exit := Callable()
	var on_clear := Callable()
	var on_wreck := Callable()
	var data: Dictionary = {}
	var prev := Prev.new()
	var solid_on := false
	var solid: World.Solid = null
	var drift := 0.0
	var wall_s := 0.0
	var wall_x := 0.0
	var wall_z := 0.0
	var wall_ux := 0.0
	var wall_uz := 0.0
	var wall_hn := 0.0
	var dent_t := 0.0
	var shift_t := 0.0
	var thr := 0.0
	var pw_s := 1.0
	var boosting := false
	var braking := false
	var pedal := 0.0
	var gear := 0
	var rpm := 0.16
	var blip := 0.0
	var thr_was := 0.0
	var pop_n := 0
	var crash_t := -9.0
	var crash_sum := 0.0
	var door_want := 0.0
	var door_k := 0.0
	var door_shut_at := 0.0
	var door_clear := false
	# damage
	var max_hp := 0.0
	var hp := 0.0
	var fire := 0.0
	var fuse := 0.0
	var wrecked := false
	var burn_t := 0.0
	var sag := 0.0
	var puff_t := 0.0
	var pop_t := 0.0
	var dents := 0
	var body_cache: Array = []


class Trans:
	var dir := "in"
	var v: Veh
	var t := 0.0
	var side := 1.0
	var path: Array = []
	var len_ := 0.0
	var tw := 0.0
	var stand: Array = []
	var wait: Variant = null
	var sill: Array = []
	var y := 0.0
	var w := 0.0
	var k := 0.0
	var yaw_off := 0.0
	var duck := 0.0
	var hands := 0.0
	var pos := Vector3.ZERO
	var yaw := 0.0
	var latched := false
	var shut := false
	var sw := NAN


class Ctl:
	var thr := 0.0
	var steer := 0.0
	var hand := false
	var boost := false
	var analog := false


static var SPECS: Dictionary = {}

var vehicles: Array[Veh] = []
var sources: Array = []
var owners: Dictionary = {}
var driver_v: Veh = null
var trans: Trans = null
var sim_t := 0.0
var acc := 0.0
var cam_saved: Variant = null
var cam_y := 0.0
var cam_fov := 0.0
var cam_kick := 0.0
var cam_ax := 0.0
var cam_off := 0.0
var exit_msg_t := 0.0
var damage := VehicleDamage.new()
var seat_ := Animator.Seat.new()
var seat_wheel_ := Animator.SeatWheel.new()
var sit_h := 0.0
var frame_ctl := Ctl.new()
var own_ctl := Ctl.new()
var no_ctl := Ctl.new()
var hold_ctl := Ctl.new()
var _tb := tan(PI / (2.0 * TC))
var _pen := PackedFloat32Array()
var hud_box: Control = null
var hud_name: Label
var hud_spd: Label
var hud_nitro: ColorRect
var hud_nbox: Control
var hud_prompt: Label
# the engine's sound
var eng_on := false
var eng_saw: AudioStreamPlayer
var eng_whine: AudioStreamPlayer
var eng_slide: AudioStreamPlayer
var eng_squeal: AudioStreamPlayer
var eng_lp: AudioEffectLowPassFilter
var eng_kb: AudioEffectBandPassFilter
var eng_g := 0.0
var eng_sg := 0.0
var eng_kg := 0.0
var eng_w := 0.0
var eng_spec: Dictionary = {}
var _buses_made := false


func _ready() -> void:
	hold_ctl.hand = true
	_pen.resize(RAYS * 3)


func driving_now() -> bool:
	return driver_v != null


var driving: bool:
	get:
		return driver_v != null


var seated: bool:
	get:
		return driver_v != null and (driver_v.model.seat != null or driver_v.spec.get("seat") != null)


var transition: String:
	get:
		return trans.dir if trans != null else ""


## add a vehicle type: {build(opts) -> VModel, label, handling, cam, engine, seat, nitro}
static func register_type(id: String, spec: Dictionary) -> Dictionary:
	SPECS[id] = spec
	return spec


func _owner_of(tag: String) -> Dictionary:
	if not owners.has(tag):
		owners[tag] = {"active": true}
	return owners[tag]


func _live(v: Veh) -> bool:
	return _owner_of(v.owner_).active


func _world() -> World:
	return Game.level.world if Game.level != null else null


# ------------------------------------------------------------------ spawning
func _apply_pose(v: Veh, a: float) -> void:
	var r := v.model.root
	var p := v.prev
	r.position = Vector3(lerpf(p.x, v.x, a), lerpf(p.y, v.y, a), lerpf(p.z, v.z, a))
	r.rotation_order = EULER_ORDER_YXZ
	r.rotation = Vector3(-lerpf(p.pitch, v.pitch, a), p.yaw + U.wrap_angle(v.yaw - p.yaw) * a, lerpf(p.roll, v.roll, a))


func _snap(v: Veh) -> void:
	var p := v.prev
	p.x = v.x
	p.y = v.y
	p.z = v.z
	p.yaw = v.yaw
	p.pitch = v.pitch
	p.roll = v.roll
	p.spin = v.spin
	p.c_pitch = v.c_pitch
	p.c_roll = v.c_roll
	p.c_y = v.c_y
	p.steer_ang = v.steer_ang


## opts: owner, parent, world, handling (overrides), surface (x, z, y) -> {grip, rolling}, model (already built), solid (the parked vehicle is a box in the world), on_enter / on_exit / on_clear, data
func spawn(type: String, x: float, z: float, yaw: float, y: Variant = null, opts: Dictionary = {}) -> Veh:
	if not SPECS.has(type):
		return null
	var spec: Dictionary = SPECS[type]
	var w: World = opts.get("world", _world())
	var gy: float = y if y != null else w.ground_height(x, z, 0.05, 400.0)
	if not is_finite(gy):
		return null
	var model: VModel = opts.get("model", (spec.build as Callable).call(opts.get("build", {})))
	var v := Veh.new()
	v.type = type
	v.spec = spec
	v.h = Handling.new()
	for src: Dictionary in [spec.get("handling", {}), opts.get("handling", {})]:
		for k: String in src:
			v.h.set(k, src[k])
	v.model = model
	v.owner_ = opts.get("owner", "default")
	v.world = w
	v.parent = opts.get("parent", Game.level)
	v.surface = opts.get("surface", Callable())
	v.x = x
	v.y = gy
	v.z = z
	v.yaw = yaw
	v.home = Vector4(x, gy, z, yaw)
	v.on_enter = opts.get("on_enter", Callable())
	v.on_exit = opts.get("on_exit", Callable())
	v.on_clear = opts.get("on_clear", Callable())
	v.on_wreck = opts.get("on_wreck", Callable())
	v.data = opts.get("data", {})
	v.solid_on = opts.get("solid", false)
	if model.root.get_parent() == null:
		v.parent.add_child(model.root)
	vehicles.append(v)
	_owner_of(v.owner_)
	_sample_pose(v, true)
	_snap(v)
	_apply_pose(v, 1.0)      # (the pose history must exist before the first frame: applyPose lerps from v.prev)
	damage.init(v)
	if v.solid_on:
		v.solid = w.add({"kind": "box", "cx": x, "cz": z, "hx": model.hw, "hz": model.hl, "yaw": yaw, "bottom": gy - 0.2, "top": gy + model.height, "tag": "bound", "no_cam": true})
		_place_solid(v)
	return v


## a vehicle's box in the world follows it while nobody drives it (and is off while somebody does)
func _place_solid(v: Veh) -> void:
	var s := v.solid
	if s == null:
		return
	var off := v.driver or not _live(v)
	s.set_off(off)
	if off:
		return
	var cb: Variant = v.model.cb
	if cb != null:
		s.place(v.x + sin(v.yaw) * float(cb.ox), v.z + cos(v.yaw) * float(cb.ox), v.yaw, cb.hw, cb.hl)
	else:
		s.place(v.x, v.z, v.yaw, v.model.hw, v.model.hl)
	if absf(s.bottom - (v.y - 0.2)) > 0.01:
		s.set_span(v.y - 0.2, v.y + v.model.height)


## take one vehicle out
func remove(v: Veh) -> void:
	if driver_v == v:
		exit(true)
	if v.solid != null:
		v.solid.set_off(true)
		v.solid = null
	if is_instance_valid(v.model.root):
		v.model.root.queue_free()
	if v.on_clear.is_valid():
		v.on_clear.call(v)
	vehicles.erase(v)


## remove every vehicle of an owner (all vehicles with no argument)
func clear(owner_tag: Variant = null) -> void:
	for v: Veh in vehicles.duplicate():
		if owner_tag == null or v.owner_ == owner_tag:
			remove(v)


## an owner whose level is not being played: its vehicles stop (and hide); driving one ends
func set_owner_active(owner_tag: String, on: bool) -> void:
	var o := _owner_of(owner_tag)
	if o.active == on:
		return
	o.active = on
	for v: Veh in vehicles:
		if v.owner_ == owner_tag:
			if not on and driver_v == v:
				exit(true)
			v.model.root.visible = on
			_place_solid(v)


# ------------------------------------------------------------------ physics
var _smp_has := false
var _smp_avg := 0.0
var _smp_slope := 0.0
var _smp_roll := 0.0


## the four wheel contacts -> body height + attitude (each wheel looks at a small footprint, not a point, so a kerb edge does not flicker)
func _sample_pose(v: Veh, snap_now: bool) -> void:
	var s := sin(v.yaw)
	var c := cos(v.yaw)
	var m := v.model
	var r := minf(0.32, m.wheel_r * 0.8)
	var pts := [Vector2(m.track, m.axle_f), Vector2(-m.track, m.axle_f), Vector2(m.track, m.axle_r), Vector2(-m.track, m.axle_r)]
	var hs := [0.0, 0.0, 0.0, 0.0]
	var n := 0
	var sum := 0.0
	for i in 4:
		var q: Vector2 = pts[i]
		var px := v.x + s * q.y + c * q.x
		var pz := v.z + c * q.y - s * q.x
		var h: float = v.world.ground_height(px, pz, r, v.y + 1.15)
		hs[i] = h
		if is_finite(h):
			sum += h
			n += 1
	if n == 0:
		_smp_has = false
		return
	var avg := sum / n
	for i in 4:
		if not is_finite(hs[i]):
			hs[i] = avg
	_smp_has = true
	_smp_avg = avg
	_smp_slope = atan2((hs[0] + hs[1]) / 2.0 - (hs[2] + hs[3]) / 2.0, m.axle_f - m.axle_r)
	_smp_roll = atan2((hs[0] + hs[2]) / 2.0 - (hs[1] + hs[3]) / 2.0, m.track * 2.0)
	if snap_now:
		v.y = avg
		v.pitch = _smp_slope
		v.roll = _smp_roll


## Walls: rays from the middle out to the edge of the body (a rectangle) at kerb height; the push is the sum of the penetrations, the contact normal their direction. The velocity into the wall is removed with a little bounce, what slides along it stays, and an off-centre hit kicks the yaw. Called after every movement sub-step, so a fast car cannot cross a wall between two checks.
func _collide(v: Veh) -> float:
	var W := v.world
	var s := sin(v.yaw)
	var c := cos(v.yaw)
	var hl := v.model.hl
	var hw := v.model.hw
	var base := v.y + 0.42
	var tp := absf(tan(v.pitch))
	var tr := absf(tan(v.roll))
	var nx := 0.0
	var nz := 0.0
	var wsum := 0.0
	var worst := 0.0
	var wrx := 0.0
	var wrz := 0.0
	var wq := 0.0
	var wy := base
	var np := 0
	for k in RAYS:
		var lx := sin(k * TAU / RAYS)      # local direction (x = left, z = forward)
		var lz := cos(k * TAU / RAYS)
		var e := minf(hl / maxf(1e-3, absf(lz)), hw / maxf(1e-3, absf(lx))) * 0.96      # distance to the edge of the rectangle
		var dx := s * lz + c * lx
		var dz := c * lz - s * lx
		var oy := base + e * maxf(tp * absf(lz), tr * absf(lx))      # (the ground rises along a slope: the probe rises with it, so a ramp is never a wall)
		var d: float = W.ray_clear(v.x, oy, v.z, dx, 0.0, dz, e + 0.12, 0.0)
		var pen := e - d
		if pen > 0.0:
			nx -= dx * pen
			nz -= dz * pen
			wsum += pen
			_pen[np * 3] = dx
			_pen[np * 3 + 1] = dz
			_pen[np * 3 + 2] = pen
			np += 1
			if pen > worst:
				worst = pen
				wrx = dx * e
				wrz = dz * e
				wq = d
				wy = oy
	if wsum <= 0.0:
		return 0.0
	# The surface's own normal, found by probing round the deepest contact: points a little beyond it that the car's centre can see are on the open side. (The penetration rays alone follow the car's axes: a front corner touching a wall at a shallow angle would read as a head-on hit and kill the speed.)
	var ux := 0.0
	var uz := 0.0
	var el := U.hyp(wrx, wrz)
	if el == 0.0:
		el = 1.0
	var qx := v.x + wrx / el * (wq + 0.06)
	var qz := v.z + wrz / el * (wq + 0.06)
	var free := 0
	for j in 8:
		var cx := cos(j * PI / 4.0)
		var cz := sin(j * PI / 4.0)
		var px := qx + cx * 0.32
		var pz := qz + cz * 0.32
		var ddx := px - v.x
		var ddz := pz - v.z
		var L := U.hyp(ddx, ddz)
		if L == 0.0:
			L = 1.0
		var d: float = W.ray_clear(v.x, wy, v.z, ddx / L, 0.0, ddz / L, L, 0.0)
		if d >= L - 0.13:
			ux += cx
			uz += cz
			free += 1
	var ul := U.hyp(ux, uz)
	if free == 0 or free == 8 or ul < 0.3:
		var nl := U.hyp(nx, nz)
		if nl == 0.0:
			nl = 1.0
		ux = nx / nl
		uz = nz / nl
	else:
		ux /= ul
		uz /= ul
	var depth := 0.0
	for k in np:
		depth = maxf(depth, _pen[k * 3 + 2] * maxf(0.15, -(_pen[k * 3] * ux + _pen[k * 3 + 1] * uz)))
	var pl := minf(0.6, depth + 0.002)
	v.x += ux * pl
	v.z += uz * pl
	var vn := v.vx * ux + v.vz * uz      # negative = into the wall
	var hit := 0.0
	if vn < 0.0:
		hit = -vn
		var e2 := v.h.bounce * clampf(hit / 8.0, 0.25, 1.0)
		v.vx -= ux * vn * (1.0 + e2)
		v.vz -= uz * vn * (1.0 + e2)
		var tx := -uz
		var tz := ux
		var vt := v.vx * tx + v.vz * tz
		var fr := minf(absf(vt), hit * 0.05)      # scraping costs a little speed
		var sv := -1.0 if vt < 0.0 else 1.0
		v.vx -= tx * sv * fr
		v.vz -= tz * sv * fr
		# a glancing hit swings the car round to run along the wall instead of digging its nose in and scrubbing all its speed off sideways (Burnout / GTA): the shallower the hit, the more
		var hx := sin(v.yaw)
		var hz := cos(v.yaw)
		var hn := hx * ux + hz * uz      # < 0: the nose points into the wall
		if hn < 0.0 and hn > -0.85 and absf(vt) > 3.0:
			var ax := hx - hn * ux + ux * 0.03      # the wall's line, turned a hair away from it
			var az := hz - hn * uz + uz * 0.03
			var al := U.hyp(ax, az)
			if al == 0.0:
				al = 1.0
			var d := U.wrap_angle(atan2(ax / al, az / al) - v.yaw)
			var k2 := clampf(0.35 + 0.6 * (1.0 - -hn / 0.85), 0.0, 0.9)
			v.yaw_rate = lerpf(v.yaw_rate, clampf(d / 0.2, -4.0, 4.0), k2)
		else:      # head on: torque about Y of the contact point
			var I := (hl * hl + hw * hw) / 3.0
			var kick := (wrz * ux - wrx * uz) * hit * (1.0 + e2) / (I * 6.0)
			v.yaw_rate = clampf(v.yaw_rate + clampf(kick, -2.2, 2.2), -3.5, 3.5)
		v.hit_dir = Vector2(ux, uz)
		if hit > v.wall_s:
			v.wall_s = hit
			v.wall_x = v.x + wrx
			v.wall_z = v.z + wrz
			v.wall_ux = ux
			v.wall_uz = uz
			v.wall_hn = hn
	return hit


static func _taper(x: float, p: float) -> float:
	return clampf(1.0 - pow(clampf(x, 0.0, 1.2), p), 0.0, 1.0)


static func _sgn(v: float) -> float:
	return -1.0 if v < 0.0 else 1.0


static func _sstep(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _damp(a: float, b: float, k: float, dt: float) -> float:
	return a + (b - a) * (1.0 - exp(-k * dt))


static func _toward(a: float, b: float, d: float) -> float:
	return b if absf(b - a) <= d else a + signf(b - a) * d


## Two-axle tyre model (the idea of Rapier / Bullet's ray-cast vehicle: load on each wheel, a friction circle per wheel, slip decides what is left for cornering), in mass-free units (accelerations). Per axle: load = weight share + longitudinal weight transfer; drive / brake force limited by mu * load; what the circle leaves is the cornering force, a function of the slip angle. The handbrake cuts the rear's grip and locks it; power on a rear-driven car eats the rear's cornering force (power oversteer); braking hard unloads the rear and loads the front.
func _step(v: Veh, dt: float, ctl: Ctl) -> void:
	var h := v.h
	var m := v.model
	v.pvx = v.vx
	v.pvz = v.vz
	v.wall_s = 0.0
	v.dent_t = maxf(0.0, v.dent_t - dt)
	v.shift_t = maxf(0.0, v.shift_t - dt)
	# 0) the ground under us decides the traction (smoothed, so crossing a kerb or a verge is not a hard switch)
	var trac := 1.0
	var rough := 1.0
	if v.surface.is_valid() and v.grounded:
		var sf: Variant = v.surface.call(v.x, v.z, v.y)
		if sf != null:
			trac = sf.get("grip", 1.0)
			rough = sf.get("rolling", 1.0)
	v.trac = _damp(v.trac, trac, 10.0, dt)
	trac = v.trac
	var af0 := absf(v.f)
	var sf0 := clampf(af0 / h.top_speed, 0.0, 1.3)
	# 1) steering: keyboard slews (turn in slower with speed, come back quickly, countersteer fastest), a stick follows its position
	var tgt := ctl.steer
	var s0 := v.steer
	if ctl.analog:
		v.steer = _damp(s0, tgt, h.pad_response, dt)
	else:
		var rate: float
		if tgt == 0.0 or (tgt * s0 >= 0.0 and absf(tgt) < absf(s0)):
			rate = h.steer_out
		elif s0 * tgt < 0.0:
			rate = h.steer_counter
		else:
			rate = lerpf(h.steer_in, h.steer_in_fast, _sstep(0.0, 0.8, sf0))
		v.steer = _toward(s0, tgt, rate * dt)
	v.hb = _damp(v.hb, 1.0 if ctl.hand else 0.0, 14.0 if ctl.hand else h.slide_recover, dt)
	var lock := lerpf(h.steer_low, h.steer_high, _sstep(0.0, h.steer_fade, sf0))
	var steer_ang := v.steer * lock
	if v.grounded and v.f > 3.0 and h.assist > 0.0:      # (a slide is caught by the wheels turning toward where the car goes, unless the driver asks for something else)
		steer_ang = clampf(steer_ang + clampf(atan2(v.l, v.f), -0.7, 0.7) * h.assist * (1.0 - 0.85 * absf(v.steer)) * _sstep(3.0, 9.0, v.f) * lock / maxf(0.1, lock + 0.05), -lock * 1.35, lock * 1.35)
	v.steer_ang = steer_ang
	# 1b) pedals: a key is all or nothing, a foot is not. Keyboard throttle and brake build up and let go over a fraction of a second (a pad's triggers are analog already: barely smoothed), so pressing or lifting never lurches the car
	var t_in := ctl.thr
	var t0 := v.thr
	v.thr = _damp(t0, t_in, 20.0, dt) if ctl.analog else _toward(t0, t_in, (6.0 if absf(t_in) > absf(t0) and t_in * t0 >= 0.0 else 9.0) * dt)
	# 2) velocity in the body frame: f forward, l to the left
	var fx_ := sin(v.yaw)
	var fz_ := cos(v.yaw)
	var lx := cos(v.yaw)
	var lz := -sin(v.yaw)
	var f := v.vx * fx_ + v.vz * fz_
	var l := v.vx * lx + v.vz * lz
	v.pw_s = _damp(v.pw_s, damage.power(v, sim_t), 9.0, dt)      # (power changes - damage, misfires, fire - ease in: no steps)
	var thr := v.thr
	var pw := v.pw_s
	var boosting: bool = ctl.boost and v.spec.get("nitro", false) and v.nitro > 0.02 and f > 2.0 and thr > 0.2 and pw > 0.5
	var vmax := (h.boost_speed if boosting else h.top_speed) * (0.55 + 0.45 * pw)
	var ax := 0.0
	var ay := 0.0
	var spin_up := 0.0
	var lock_up := 0.0
	var slide_f := 0.0
	var slide_r := 0.0
	if v.grounded:
		var af := absf(f)
		var mu := h.mu * maxf(0.2, trac)
		var g := h.g_tyre
		var L_ := m.wheelbase
		var cg := lerpf(m.axle_r, m.axle_f, 0.46)
		var a := m.axle_f - cg
		var b := cg - m.axle_r
		var Iz := h.yaw_inertia * a * b
		var eff_f := 1.0 / (1.0 + a * a / Iz)
		var eff_r := 1.0 / (1.0 + b * b / Iz)
		# engine and brake demand (m/s^2 at the road), before the tyres have their say
		var drive := 0.0
		var brake := 0.0
		if thr > 0.02:
			v.rev_lock = 0.0
			if f < -0.5:      # forward from reverse: brake first
				brake = h.brake * thr
			else:
				drive = h.accel * pw * (1.0 - 0.3 * sin(PI * clampf(v.shift_t / SHIFT_T, 0.0, 1.0))) * (1.9 if boosting else 1.0) * thr * (h.accel_at_top + (1.0 - h.accel_at_top) * _taper(f / vmax, h.accel_curve))
		elif thr < -0.02:
			if f > 0.5:      # reverse from forward: brake to a stop, hold a moment, then back up
				brake = h.brake * -thr
				v.rev_lock = h.reverse_delay
			elif v.rev_lock > 0.0:
				v.rev_lock -= dt
				brake = minf(af / dt, 40.0)
			else:
				drive = -h.accel * pw * 0.6 * -thr * _taper(-f / h.reverse_speed, h.accel_curve)
		else:
			v.rev_lock = 0.0
		var sg := _sgn(f)
		var hbk := h.handbrake_decel * v.hb
		# load on each axle: weight share, plus what acceleration moves (the nose lifts under power, dives under the brakes)
		var tr := clampf(v.ax_s * h.cg_h / L_, -0.45 * g, 0.45 * g)
		var s_f := g * b / L_
		var s_r := g * a / L_
		var Fz_f := s_f * pow(maxf(0.2, 1.0 - tr / s_f), 0.8)      # (tyres gain less grip from extra load than they lose from less: transfer is felt, not decisive)
		var Fz_r := s_r * pow(maxf(0.2, 1.0 + tr / s_r), 0.8)
		# a drift: started by a flick of the handbrake at speed, held by staying on the throttle with the car sideways; while it lasts the rear lets go a little and the throttle keeps it moving
		var beta := atan2(l, maxf(2.0, af))
		v.hb_t = 0.7 if v.hb > 0.5 else maxf(0.0, v.hb_t - dt)
		if v.hb_t > 0.0 and af > 8.0 and absf(beta) > 0.12 and thr > 0.15:
			v.drift = 1.0
		elif v.drift > 0.0:
			var hold := absf(beta) > 0.07 and af > 6.0 and (thr > 0.15 or v.hb > 0.2)
			v.drift = minf(1.0, v.drift + dt * 4.0) if hold else maxf(0.0, v.drift - dt * (6.0 if absf(beta) < 0.07 else 2.5))
		var mu_f := mu
		var mu_r := mu * h.rear_grip * lerpf(1.0, h.hb_mu, v.hb) * lerpf(1.0, h.drift_grip, v.drift * (1.0 - v.hb))
		var d_f := 0.0 if h.drive == "rear" else (1.0 if h.drive == "front" else 0.5)
		var d_r := 1.0 - d_f
		var cap_f := mu_f * Fz_f * TCAP
		var cap_r := mu_r * Fz_r * TCAP
		# longitudinal force per axle (positive = forward)
		var Fx_f := 0.0
		var Fx_r := 0.0
		if drive != 0.0:
			Fx_f = clampf(drive * d_f, -cap_f, cap_f)
			Fx_r = clampf(drive * d_r, -cap_r, cap_r)
			spin_up = maxf(absf(drive * d_f) / cap_f if d_f != 0.0 else 0.0, absf(drive * d_r) / cap_r if d_r != 0.0 else 0.0)
		if brake > 0.0 or hbk > 0.0:
			var b_f := brake * h.brake_bias
			var b_r := brake * (1.0 - h.brake_bias) + hbk
			var k_f := minf(b_f, cap_f)
			var k_r := minf(b_r, cap_r)
			lock_up = maxf(maxf(b_f / cap_f, b_r / cap_r), v.hb)
			var tot := minf(k_f + k_r, af / dt)
			var sc := tot / (k_f + k_r) if k_f + k_r > 1e-6 else 0.0
			Fx_f -= sg * k_f * sc
			Fx_r -= sg * k_r * sc
		cap_f = maxf(0.0, cap_f)
		cap_r = maxf(0.0, cap_r)
		# what is left of each friction circle corners the car: force from the slip angle of the axle
		var cd := cos(steer_ang)
		var sd := sin(steer_ang)
		var l_f := l + a * v.yaw_rate
		var l_r := l - b * v.yaw_rate
		var vlat_f := l_f * cd - f * sd
		var vlon_f := f * cd + l_f * sd
		var vlat_r := l_r
		var al_f := atan2(vlat_f, absf(vlon_f) + 1.2)
		var al_r := atan2(vlat_r, absf(f) + 1.2)
		var lim_f := sqrt(maxf(0.0, pow(mu_f * Fz_f, 2.0) - Fx_f * Fx_f))
		var lim_r := sqrt(maxf(0.0, pow(mu_r * Fz_r, 2.0) - Fx_r * Fx_r))
		var Fy_f := -lim_f * sin(TC * atan(_tb * al_f / h.slip_peak_f))
		var Fy_r := -lim_r * sin(TC * atan(_tb * al_r / h.slip_peak_r))
		var cl_f := absf(vlat_f) * eff_f / dt * 0.9
		var cl_r := absf(vlat_r) * eff_r / dt * 0.9
		Fy_f = clampf(Fy_f, -cl_f, cl_f)
		Fy_r = clampf(Fy_r, -cl_r, cl_r)
		slide_f = _sstep(h.slip_peak_f, h.slip_peak_f * 2.2, absf(al_f))
		slide_r = _sstep(h.slip_peak_r, h.slip_peak_r * 2.2, absf(al_r))
		# resultant on the body
		var Fxb := Fx_f * cd - Fy_f * sd + Fx_r
		var Fyb := Fy_f * cd + Fx_f * sd + Fy_r
		var torque := a * (Fy_f * cd + Fx_f * sd) - b * Fy_r
		f += Fxb * dt
		l += Fyb * dt
		ax = Fxb
		ay = Fyb
		v.yaw_rate += torque / Iz * dt
		v.yaw_rate *= exp(-h.yaw_damp * dt)
		if v.drift > 0.0 and thr > 0.1 and f > 4.0:      # (a held drift keeps its speed)
			var push := h.drift_push * h.accel * pw * thr * v.drift * minf(1.0, absf(beta) / 0.35) * _taper(f / vmax, 2.0)
			f += push * dt
			ax += push
		# stability: past slideMax (more while drifting) the car is pulled back toward where it is going, and a car still rotating deeper into the slide is damped. You can throw it sideways and hold it there; you cannot spin it by accident. The handbrake turns this off (handbrake turns, 180s).
		# (it eases in from half of slideMax, so a lift-off mid-corner tucks the nose in instead of building a slide nobody asked for)
		var b_max := h.slide_max * (1.0 + 0.3 * v.drift)
		var b_soft := b_max * (0.5 + 0.4 * v.drift)
		var ab := absf(beta)
		var ex := _sgn(beta) * ((minf(ab, b_max) - b_soft) * 0.45 + maxf(0.0, ab - b_max)) if ab > b_soft else 0.0
		if ex != 0.0 and af > 4.0:
			var k := 1.0 - v.hb
			v.yaw_rate += ex * h.stab * k * dt
			if v.yaw_rate * beta < 0.0:
				v.yaw_rate *= exp(-9.0 * minf(1.0, absf(ex) / 0.25) * k * dt)
		# what is not tyre: air and rolling resistance, engine braking, slopes, rough ground
		var af2 := absf(f)
		var lift := 1.0 - clampf(absf(thr) / 0.3, 0.0, 1.0)      # off the pedals (blended in as they come up, so letting go is a smooth ease into engine braking, not a step)
		if lift > 0.0:
			var dec := ((h.rolling if af2 < 2.0 or not v.driver else h.coast) + h.drag * f * f) * lift
			var sf_ := _sgn(f)
			f -= sf_ * minf(af2, dec * dt)
			ax -= sf_ * minf(af2 / dt, dec)
		if rough > 1.0:
			f -= _sgn(f) * minf(absf(f), (rough - 1.0) * 3.0 * dt * clampf(af2 / 3.0, 0.0, 1.0))
		if absf(f) > vmax + 0.5:
			f = _damp(f, _sgn(f) * vmax, 1.6, dt)
		if absf(thr) > 0.02 or af2 > 3.0:      # hills slow the climb, speed the descent (a parked / idling car holds)
			f -= 9.8 * sin(v.pitch) * h.hill_gravity * dt
		if af2 < 0.35 and absf(thr) < 0.02 and not v.driver:      # an empty car comes to rest
			f *= exp(-6.0 * dt)
	else:
		l *= exp(-0.15 * dt)
		f *= exp(-0.03 * dt)
		v.yaw_rate = _damp(v.yaw_rate, 0.0, 0.6, dt)
	v.ax_s = _damp(v.ax_s, ax, 9.0, dt)
	v.ay_s = _damp(v.ay_s, ay, 9.0, dt)
	v.spin_up = spin_up
	v.lock_up = lock_up
	v.slide = maxf(slide_f, slide_r)
	v.vx = fx_ * f + lx * l
	v.vz = fz_ * f + lz * l
	v.yaw_rate = clampf(v.yaw_rate, -4.5, 4.5)
	v.yaw = U.wrap_angle(v.yaw + v.yaw_rate * dt)
	fx_ = sin(v.yaw)
	fz_ = cos(v.yaw)
	lx = cos(v.yaw)
	lz = -sin(v.yaw)
	f = v.vx * fx_ + v.vz * fz_
	l = v.vx * lx + v.vz * lz
	v.f = f
	v.l = l
	v.nitro_cd = 1.4 if boosting else maxf(0.0, v.nitro_cd - dt)
	v.nitro = clampf(v.nitro + (-0.26 if boosting else (0.0 if v.nitro_cd > 0.0 else 0.14)) * dt, 0.0, 1.0)
	v.boosting = boosting
	v.spin += (f + (_sgn(thr) * 6.0 * (v.spin_up - 1.0) if v.spin_up > 1.0 else 0.0)) / m.wheel_r * dt
	# 3) move in bounded sub-steps (never more than ~a third of a metre between two wall checks) and push out of walls
	var sp := U.hyp(v.vx, v.vz)
	var n := clampi(ceili(sp * dt / 0.32), 1, 4)
	var sdt := dt / n
	var hit := 0.0
	for k in n:
		v.x += v.vx * sdt
		v.z += v.vz * sdt
		hit = maxf(hit, _collide(v))
	if hit > 0.0:
		v.f = v.vx * fx_ + v.vz * fz_
		v.l = v.vx * lx + v.vz * lz
		v.last_hit = maxf(v.last_hit, hit)
	# 4) height: follow the four contacts, or fly
	_sample_pose(v, false)
	var g2 := h.gravity
	if not _smp_has:
		v.grounded = false
		v.vy -= g2 * dt
		v.y += v.vy * dt
	elif v.grounded:
		var rise := _smp_avg - v.y
		if rise < -0.2 - absf(v.f) * 0.004:
			v.grounded = false
			v.vy = clampf(v.gvy, -4.0, 14.0)
		else:
			v.gvy = _damp(v.gvy, rise / maxf(dt, 1e-3), 14.0, dt)
			v.y = _smp_avg if rise > 0.0 else _damp(v.y, _smp_avg, 28.0, dt)
			if rise > 0.07 and absf(v.f) > 2.5:      # a kerb is a bump, not a ramp
				var k := clampf(rise / 0.3, 0.0, 1.0)
				v.c_yv -= k * minf(2.5, absf(v.f) * 0.12)
				v.c_pitch += k * 0.02
				v.f *= 1.0 - minf(0.04, rise * 0.25)
				v.bump = maxf(v.bump, k)
	if not v.grounded and _smp_has:
		v.vy -= g2 * dt
		v.y += v.vy * dt
		if v.y <= _smp_avg:
			var impact_ := -v.vy
			v.y = _smp_avg
			v.vy = 0.0
			v.grounded = true
			_landed(v, impact_)
	var tp := _smp_slope if v.grounded and _smp_has else clampf(atan2(v.vy, maxf(6.0, absf(v.f))) * 0.7, -0.5, 0.5)
	var tr2 := _smp_roll if v.grounded and _smp_has else 0.0
	v.pitch = _damp(v.pitch, clampf(tp, -0.9, 0.9), 14.0 if v.grounded else 3.0, dt)
	v.roll = _damp(v.roll, clampf(tr2, -0.8, 0.8), 14.0 if v.grounded else 3.0, dt)
	# chassis body motion: squat / dive, lean, and a sprung bounce (visual only; the camera follows the clean height)
	var w_b := h.body_freq
	var k_b := w_b * w_b
	var c_b := 2.0 * h.body_damp * w_b      # body lean: a spring-damper pulled by the loads (acceleration, cornering), so it rocks and settles instead of easing
	v.c_pv += (k_b * (clampf(-v.ax_s * 0.0042, -0.09, 0.11) - v.c_pitch) - c_b * v.c_pv) * dt
	v.c_pitch = clampf(v.c_pitch + v.c_pv * dt, -0.14, 0.16)
	v.c_rv += (k_b * (clampf(v.ay_s * 0.0042, -0.1, 0.1) - v.c_roll) - c_b * v.c_rv) * dt
	v.c_roll = clampf(v.c_roll + v.c_rv * dt, -0.15, 0.15)
	var ks := h.suspension * h.suspension
	v.c_yv += (-ks * v.c_y - 2.0 * 0.55 * h.suspension * v.c_yv) * dt
	v.c_y = clampf(v.c_y + v.c_yv * dt, -0.12, 0.12)
	v.speed = U.hyp(v.vx, v.vz)
	if v.wall_s > 0.0 and not _knock_at(v):
		_impact(v, v.wall_s, v.wall_x, v.y + 0.55, v.wall_z, -v.wall_ux, -v.wall_uz, 1.0, v.wall_hn)
	v.skid = clampf(maxf(maxf(v.slide * clampf(v.speed / 5.0, 0.0, 1.0), (v.spin_up - 0.9) * 3.0 * clampf(1.2 - v.speed / 14.0, 0.0, 1.0)), maxf((v.lock_up - 0.95) * 2.4 * clampf(v.speed / 8.0, 0.0, 1.0), v.hb * clampf(v.speed / 10.0, 0.0, 1.0) * 0.9)), 0.0, 1.0) if v.grounded else 0.0
	if v.bump > 0.0:
		v.bump = maxf(0.0, v.bump - dt * 3.0)


## one impact on a vehicle: closing speed sp (m/s) at a world point, dir (dx, dz) pointing into the car, heavy = the other side's mass factor (1 = a wall / an equal car)
func _impact(v: Veh, sp: float, px: float, py: float, pz: float, dx: float, dz: float, heavy: float = 1.0, hn: float = -1.0) -> void:
	if sp > v.hit_feel:
		v.hit_feel = sp
	if sp < 3.5:
		return
	var glance := clampf(-hn, 0.25, 1.0)
	var dmg := v.h.crash * pow(maxf(0.0, sp - 4.0), 1.5) * heavy * (0.45 + 0.55 * glance)
	if sim_t - v.crash_t > 0.6:      # one crash (its contacts over a few steps count together) takes at most 70%, however fast,
		v.crash_sum = 0.0
	v.crash_t = sim_t
	var take := minf(dmg, maxf(0.0, v.max_hp * 0.7 - v.crash_sum))      # and never blows a car up on the spot: it smokes, and only a car worn down by earlier hits catches fire
	v.crash_sum += take
	var lit := damage.hurt(v, take, false, true)
	if lit and v.driver and v == driver_v:
		v.lit_t = 0.0
	if v.dent_t <= 0.0:
		v.dent_t = 0.1
		damage.dent(v, Vector3(px, py, pz), Vector3(dx, 0.0, dz), clampf((sp - 3.0) * 0.011, 0.0, 0.16) * (0.5 + 0.5 * glance))


func _landed(v: Veh, imp: float) -> void:
	if imp > 13.0:
		damage.hurt(v, v.h.crash * pow(imp - 13.0, 1.5) * 0.6)
	if imp < 7.0:
		v.c_pitch += 0.03
		return
	v.c_pitch += minf(0.12, imp * 0.006)
	v.c_yv -= minf(2.5, imp * 0.12)
	if v.driver:
		Game.fx.shake = maxf(Game.fx.shake, minf(0.5, imp / 40.0))
	Game.fx.dust(Vector3(v.x, v.y, v.z), mini(14, 4 + int(imp)), 3.0)
	_thud(minf(1.0, imp / 22.0))


# ------------------------------------------------------------------ vehicles hitting vehicles
# Every pair of live vehicles is tested as two boxes (the standing footprint, 2D separating axes, within a height band); a contact separates them by mass and exchanges an impulse at the contact point, so a ram shoves and spins the other car, a parked car is pushed. The driven car counts heavier (PLAYER_MASS).
func _mass_of(v: Veh) -> float:
	return v.h.mass * (PLAYER_MASS if v == driver_v else 1.0) * (1.3 if v.wrecked else 1.0)


func _footprint(v: Veh) -> Vector3:      # hw, hl, ox: the one its collider box uses
	var cb: Variant = v.model.cb
	return Vector3(cb.hw, cb.hl, cb.ox) if cb != null else Vector3(v.model.hw, v.model.hl, 0.0)


func _inertia_of(v: Veh, M: float) -> float:
	var F := _footprint(v)
	return M * (F.y * F.y + F.x * F.x) / 3.0 * v.h.yaw_inertia


func _obb(v: Veh) -> Dictionary:
	var F := _footprint(v)
	var s := sin(v.yaw)
	var c := cos(v.yaw)
	return {"cx": v.x + s * F.z, "cz": v.z + c * F.z, "fx": s, "fz": c, "lx": c, "lz": -s, "hl": F.y, "hw": F.x}


static func _rad(o: Dictionary, ax: float, az: float) -> float:
	return float(o.hl) * absf(float(o.fx) * ax + float(o.fz) * az) + float(o.hw) * absf(float(o.lx) * ax + float(o.lz) * az)


static func _corner(O: Dictionary, sgn_: float, bx: float, bz: float) -> Vector2:
	var a := -1.0 if sgn_ * (float(O.fx) * bx + float(O.fz) * bz) > 0.0 else 1.0
	var b := -1.0 if sgn_ * (float(O.lx) * bx + float(O.lz) * bz) > 0.0 else 1.0
	return Vector2(float(O.cx) + float(O.fx) * float(O.hl) * a + float(O.lx) * float(O.hw) * b, float(O.cz) + float(O.fz) * float(O.hl) * a + float(O.lz) * float(O.hw) * b)


## separating axes of two boxes: null when apart, else the overlap depth, the normal from A to B and a contact point
func _sat(A: Dictionary, B: Dictionary) -> Variant:
	var best := INF
	var bx := 0.0
	var bz := 0.0
	var dx: float = float(B.cx) - float(A.cx)
	var dz: float = float(B.cz) - float(A.cz)
	for ax_: Vector2 in [Vector2(A.fx, A.fz), Vector2(A.lx, A.lz), Vector2(B.fx, B.fz), Vector2(B.lx, B.lz)]:
		var d := dx * ax_.x + dz * ax_.y
		var ov := _rad(A, ax_.x, ax_.y) + _rad(B, ax_.x, ax_.y) - absf(d)
		if ov <= 0.0:
			return null
		if ov < best:
			best = ov
			var sg := -1.0 if d < 0.0 else 1.0
			bx = ax_.x * sg
			bz = ax_.y * sg
	# contact: B's corner deepest toward A if it lies inside A, else A's corner deepest toward B
	var cb := _corner(B, 1.0, bx, bz)
	var ca := _corner(A, -1.0, bx, bz)
	var in_a := absf((cb.x - float(A.cx)) * float(A.fx) + (cb.y - float(A.cz)) * float(A.fz)) <= float(A.hl) + 0.05 and absf((cb.x - float(A.cx)) * float(A.lx) + (cb.y - float(A.cz)) * float(A.lz)) <= float(A.hw) + 0.05
	var p := cb if in_a else ca
	return {"d": best, "nx": bx, "nz": bz, "px": p.x, "pz": p.y}


## the impulse between A and B at a contact (n from A to B); returns the closing speed it removed
func _exchange(A: Veh, B: Veh, nx: float, nz: float, px: float, pz: float) -> float:
	var mA := _mass_of(A)
	var mB := _mass_of(B)
	var IA := _inertia_of(A, mA)
	var IB := _inertia_of(B, mB)
	var rax := px - A.x
	var raz := pz - A.z
	var rbx := px - B.x
	var rbz := pz - B.z
	var vax := A.vx + A.yaw_rate * raz      # (a point's velocity: v + yawRate x r, yaw turning +Z toward +X)
	var vaz := A.vz - A.yaw_rate * rax
	var vbx := B.vx + B.yaw_rate * rbz
	var vbz := B.vz - B.yaw_rate * rbx
	var rvx := vbx - vax
	var rvz := vbz - vaz
	var vn := rvx * nx + rvz * nz
	if vn >= 0.0:
		return 0.0
	var cA := raz * nx - rax * nz
	var cB := rbz * nx - rbx * nz
	var j := -(1.0 + CAR_E) * vn / (1.0 / mA + 1.0 / mB + cA * cA / IA + cB * cB / IB)
	var tx := -nz
	var tz := nx
	var vt := rvx * tx + rvz * tz
	var tA := raz * tx - rax * tz
	var tB := rbz * tx - rbx * tz
	var jt := clampf(-vt / (1.0 / mA + 1.0 / mB + tA * tA / IA + tB * tB / IB), -CAR_MU * j, CAR_MU * j)
	var Jx := nx * j + tx * jt
	var Jz := nz * j + tz * jt
	A.vx -= Jx / mA
	A.vz -= Jz / mA
	A.yaw_rate = clampf(A.yaw_rate - (raz * Jx - rax * Jz) / IA, -4.5, 4.5)
	B.vx += Jx / mB
	B.vz += Jz / mB
	B.yaw_rate = clampf(B.yaw_rate + (rbz * Jx - rbx * Jz) / IB, -4.5, 4.5)
	for V: Veh in [A, B]:
		V.speed = U.hyp(V.vx, V.vz)
		var s_ := sin(V.yaw)
		var c_ := cos(V.yaw)
		V.f = V.vx * s_ + V.vz * c_
		V.l = V.vx * c_ - V.vz * s_
	return -vn


## a hit between two vehicles: the damage each takes (the lighter one more), dents where they met, the feel
func _car_hit(A: Veh, B: Veh, sp: float, nx: float, nz: float, px: float, pz: float) -> void:
	var mA := _mass_of(A)
	var mB := _mass_of(B)
	var py := minf(A.y, B.y) + 0.55
	_impact(A, sp, px, py, pz, -nx, -nz, 2.0 * mB / (mA + mB))
	_impact(B, sp, px, py, pz, nx, nz, 2.0 * mA / (mA + mB))
	A.last_hit = maxf(A.last_hit, sp)
	B.last_hit = maxf(B.last_hit, sp)
	A.hit_dir = Vector2(-nx, -nz)
	B.hit_dir = Vector2(nx, nz)


func _car_pairs() -> void:
	var n := vehicles.size()
	for i in n:
		var A: Veh = vehicles[i]
		if not _live(A):
			continue
		for k in range(i + 1, n):
			var B: Veh = vehicles[k]
			if not _live(B) or A.world != B.world or absf(A.y - B.y) > 1.6:
				continue
			if A.speed < 0.05 and B.speed < 0.05:
				continue
			var rr := U.hyp(A.model.hl, A.model.hw) + U.hyp(B.model.hl, B.model.hw) + 0.6
			if pow(A.x - B.x, 2.0) + pow(A.z - B.z, 2.0) > rr * rr:
				continue
			var c: Variant = _sat(_obb(A), _obb(B))
			if c == null:
				continue
			var mA := _mass_of(A)
			var mB := _mass_of(B)
			var push := minf(0.6, float(c.d) + 0.005)
			A.x -= float(c.nx) * push * mB / (mA + mB)
			A.z -= float(c.nz) * push * mB / (mA + mB)
			B.x += float(c.nx) * push * mA / (mA + mB)
			B.z += float(c.nz) * push * mA / (mA + mB)
			var sp := _exchange(A, B, c.nx, c.nz, c.px, c.pz)
			if sp > 0.5:
				_car_hit(A, B, sp, c.nx, c.nz, c.px, c.pz)


# ------------------------------------------------------------------ audio
func _thud(k: float) -> void:
	MsSound.play([["tone", 0.0, {"type": &"sine", "f0": 120.0, "f1": 40.0, "gain": snappedf(0.7 * k, 0.05), "dur": 0.3}], ["noise", 0.0, {"type": &"lowpass", "f0": 1400.0, "f1": 200.0, "gain": snappedf(0.5 * k, 0.05), "dur": 0.2}]], 0.2)


func _s_latch() -> void:
	MsSound.play([["noise", 0.0, {"type": &"bandpass", "f0": 2600.0, "q": 3.0, "gain": 0.22, "dur": 0.05}], ["tone", 0.02, {"type": &"square", "f0": 900.0, "f1": 500.0, "gain": 0.05, "dur": 0.06}]], 0.08)


func _s_door() -> void:
	MsSound.play([["tone", 0.0, {"type": &"square", "f0": 180.0, "f1": 90.0, "gain": 0.16, "dur": 0.16}], ["noise", 0.0, {"type": &"lowpass", "f0": 1800.0, "f1": 400.0, "gain": 0.35, "dur": 0.09}]], 0.12)


func _s_ram() -> void:
	_thud(0.9)
	MsSound.noise(0.1, &"bandpass", 1200.0, 1200.0, 0.5, 2.0, 0.1)


func _track(st: AudioStream, nm: String, fx: AudioEffect) -> AudioStreamPlayer:
	var ix := AudioServer.get_bus_index(StringName("Veh" + nm))
	if ix < 0:
		AudioServer.add_bus()
		ix = AudioServer.bus_count - 1
		AudioServer.set_bus_name(ix, StringName("Veh" + nm))
		AudioServer.set_bus_send(ix, &"SFX")
		if fx != null:
			AudioServer.add_bus_effect(ix, fx)
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = StringName("Veh" + nm)
	p.volume_db = -80.0
	add_child(p)
	return p


func _audio_make() -> void:
	if _buses_made:
		return
	_buses_made = true
	# one second of the engine's two oscillators (a saw and a square an octave down) at 55 Hz; pitch_scale moves it
	var buf := OfflineSynth.make(1.0, AUDIO_RATE)
	var buf_s := OfflineSynth.make(1.0, AUDIO_RATE)
	var buf_t := OfflineSynth.make(1.0, AUDIO_RATE)
	for i in buf.size():
		var ph := 55.0 * i / AUDIO_RATE
		var saw := 2.0 * (ph - floorf(ph)) - 1.0
		var sq := 1.0 if fmod(ph * 0.5, 1.0) < 0.5 else -1.0
		buf[i] = (saw + 0.55 * sq) * 0.5
		buf_s[i] = sin(TAU * 55.0 * i / AUDIO_RATE)
		buf_t[i] = (2.0 * (fmod(ph, 1.0)) - 1.0) * 0.0 + randf_range(-1.0, 1.0)
	eng_lp = AudioEffectLowPassFilter.new()
	eng_lp.resonance = 1.3
	eng_saw = _track(OfflineSynth.wav(buf, AUDIO_RATE, true), "Eng", eng_lp)
	eng_whine = _track(OfflineSynth.wav(buf_s, AUDIO_RATE, true), "Whine", null)
	var sl := AudioEffectBandPassFilter.new()
	sl.cutoff_hz = 1900.0
	sl.resonance = 0.7
	var noise := OfflineSynth.wav(buf_t, AUDIO_RATE, true)
	eng_slide = _track(noise, "Slide", sl)
	eng_kb = AudioEffectBandPassFilter.new()
	eng_kb.cutoff_hz = 1500.0
	eng_kb.resonance = 2.2
	eng_squeal = _track(noise, "Squeal", eng_kb)


func _engine_start(v: Veh) -> void:
	if eng_on:
		return
	_audio_make()
	eng_on = true
	eng_spec = v.spec.get("engine", {"base": 30.0, "span": 120.0, "whine": 0.0})
	eng_g = 0.0
	eng_w = float(eng_spec.get("whine", 0.0))
	for p: AudioStreamPlayer in [eng_saw, eng_whine, eng_slide, eng_squeal]:
		p.play()


func _engine_stop() -> void:
	if not eng_on:
		return
	eng_on = false
	for p: AudioStreamPlayer in [eng_saw, eng_whine, eng_slide, eng_squeal]:
		p.stop()


## five gears by road speed with hysteresis: up near the redline under power (earlier when cruising), down when the revs sag. An upshift eases the drive off for a moment (v.shift_t) and nods the body
func _gearbox(v: Veh, ctl: Ctl, dt: float) -> void:
	var sp := absf(v.f)
	var top := v.h.top_speed
	var g := v.gear
	var thr := maxf(0.0, ctl.thr)
	if v.f < -0.5:
		g = 0
	elif g < GEARS.size() - 1 and clampf(sp / (top * float(GEARS[g])), 0.0, 1.08) > (0.94 if thr > 0.5 else 0.72) and v.grounded:
		g += 1
		v.shift_t = SHIFT_T
		v.c_pv += 0.12
	elif g > 0 and clampf(sp / (top * float(GEARS[g])), 0.0, 1.08) < 0.36:
		g -= 1
		v.blip = 0.18
	v.gear = g
	var rpm_g := clampf(sp / (top * float(GEARS[g])), 0.0, 1.08)
	var tgt := maxf(0.16, rpm_g * 0.92 + thr * 0.08 + (0.12 if v.spin_up > 1.0 else 0.0))
	v.rpm = _damp(v.rpm, tgt * 0.82 if v.shift_t > 0.0 else tgt + (0.15 if v.blip > 0.0 else 0.0), 30.0 if v.shift_t > 0.0 else 10.0, dt)
	v.blip = maxf(0.0, v.blip - dt)
	if v.thr_was > 0.6 and thr < 0.1 and v.rpm > 0.62:      # lifting off at high revs: the exhaust crackles
		v.pop_n = 2 + randi() % 4
	v.thr_was = thr


func _engine_update(v: Veh, ctl: Ctl, dt: float) -> void:
	_gearbox(v, ctl, dt)
	if not eng_on:
		return
	var T := sim_t
	var limiter := 0.55 + 0.45 * signf(sin(T * 110.0)) if v.rpm > 1.0 and ctl.thr > 0.8 else 1.0
	var pw := damage.power(v, sim_t)
	var miss := 0.4 + 0.6 * pw if pw < 0.95 else 1.0
	var base: float = eng_spec.get("base", 30.0)
	var span: float = eng_spec.get("span", 120.0)
	var fr := base + span * v.rpm * (0.97 + 0.03 * limiter if limiter < 1.0 else 1.0)
	eng_saw.pitch_scale = maxf(0.05, fr / 55.0)
	eng_whine.pitch_scale = maxf(0.05, fr * 5.0 / 55.0)
	eng_lp.cutoff_hz = lerpf(eng_lp.cutoff_hz, (260.0 + v.rpm * 1500.0 + maxf(0.0, ctl.thr) * 500.0) * (0.8 if v.shift_t > 0.0 else 1.0), 1.0 - exp(-dt / 0.04))
	var want := miss * limiter * (0.06 + 0.07 * maxf(0.0, ctl.thr) * (0.6 if v.shift_t > 0.0 else 1.0) + 0.05 * v.rpm + (0.04 if v.boosting else 0.0))
	eng_g += (want - eng_g) * (1.0 - exp(-dt / 0.04))
	eng_saw.volume_db = linear_to_db(maxf(eng_g, 1e-5))
	eng_whine.volume_db = linear_to_db(maxf(eng_g * 0.12 * eng_w, 1e-5))
	if v.pop_n > 0 and randf() < dt * 9.0:
		v.pop_n -= 1
		MsSound.play([["noise", 0.0, {"type": &"bandpass", "f0": 700.0, "q": 1.2, "gain": 0.3, "dur": 0.05}], ["tone", 0.0, {"type": &"sine", "f0": 140.0, "f1": 60.0, "gain": 0.18, "dur": 0.06}]], 0.12)
	eng_sg += ((clampf((absf(v.l) - 4.0) / 14.0, 0.0, 1.0) * 0.1 * clampf(v.speed / 8.0, 0.0, 1.0) if v.grounded else 0.0) - eng_sg) * (1.0 - exp(-dt / 0.05))
	eng_slide.volume_db = linear_to_db(maxf(eng_sg * 0.65, 1e-5))
	eng_kg += (v.skid * 0.07 - eng_kg) * (1.0 - exp(-dt / 0.04))
	eng_squeal.volume_db = linear_to_db(maxf(eng_kg * 0.42, 1e-5))
	eng_kb.cutoff_hz = lerpf(eng_kb.cutoff_hz, 1200.0 + v.speed * 28.0, 1.0 - exp(-dt / 0.08))


# ------------------------------------------------------------------ run over
func _run_over(v: Veh) -> void:
	if v.speed < 4.5 or not v.driver or Game.combat == null:
		return
	var s := sin(v.yaw)
	var c := cos(v.yaw)
	for k: Robot in Game.combat.enemies.robots:
		if k.dead:
			continue
		var dx := k.x - v.x
		var dz := k.z - v.z
		var lz := dx * s + dz * c
		var lx := dx * c - dz * s
		if absf(lz) > v.model.hl + 0.3 or absf(lx) > v.model.hw + 0.4 or absf(k.y - v.y) > 2.0:
			continue
		var now := Time.get_ticks_msec()
		if int(v.hit_cd.get(k, 0)) > now:
			continue
		v.hit_cd[k] = now + 450
		Game.combat.damage(k, clampf(v.speed * 55.0, 140.0, 1400.0), Game.player, 8.0, null)
		k.kvx += v.vx * 0.45
		k.kvz += v.vz * 0.45
		Game.fx.sparks(Vector3(k.x, k.y + 1.0, k.z), 10, 4.0, null, 0xffb050)
		Game.fx.shake = maxf(Game.fx.shake, 0.5)
		_s_ram()
		v.vx *= 0.93
		v.vz *= 0.93


# ------------------------------------------------------------------ driver
## one frame of driver input (read once per frame, however many physics steps it feeds)
func _read_input() -> Ctl:
	var m: Variant = Inp.move
	var thr: float = m.y
	if Inp.rt > 0.05 or Inp.lt > 0.05:
		thr = Inp.rt - Inp.lt
	var sx: float = m.x
	if not Inp.using_pad and m.mag > 0.99 and absf(m.x) > 0.1 and absf(m.y) > 0.1:      # keyboard diagonals are normalised: W+D must still be full throttle + full steer
		var k := 1.0 / maxf(absf(m.x), absf(m.y))
		sx *= k
		thr = m.y * k
	own_ctl.thr = clampf(thr, -1.0, 1.0)
	own_ctl.steer = clampf(-sx, -1.0, 1.0)
	own_ctl.hand = Inp.btn(&"jump").held
	own_ctl.boost = Inp.btn(&"strafe").held or Inp.btn(&"l3").held
	own_ctl.analog = Inp.using_pad
	return own_ctl


## the nearest vehicle (or source) the player could get into
func _candidate(max_d: float) -> Variant:
	var best: Variant = null
	var bd := max_d
	var P := Game.player
	for v: Veh in vehicles:
		if v.driver or not _live(v) or v.data.get("no_enter", false) or v.wrecked or v.speed >= 4.0:
			continue
		var d := U.hyp(v.x - P.x, v.z - P.z)
		if d < bd and absf(v.y - P.y) < 3.5:
			bd = d
			best = {"d": d, "label": "DRIVE " + String(v.spec.get("label", "")), "act": enter.bind(v, {})}
	for s: Variant in sources:
		if not _owner_of(s.get("owner", "default")).active:
			continue
		var c: Variant = (s.nearest as Callable).call(P)
		if c != null and float(c.d) < bd:
			bd = c.d
			best = c
	return best


func _seat_of(v: Veh) -> Variant:
	return v.model.seat if v.model.seat != null else v.spec.get("seat")


## get in (opts.instant: straight into the seat, nothing played: scripts, tests, cutscenes)
func enter(v: Veh, opts: Dictionary = {}) -> bool:
	if v == null or driver_v != null or v.driver or not _live(v) or trans != null:
		return false
	_sit_height()      # (measured standing, before any seat pose: instant entries fit the cabin too)
	driver_v = v
	v.driver = true
	if cam_saved == null:
		cam_saved = {"cam_dist": Config.cam_dist, "cam_height": Config.cam_height, "cam_pos_k": Config.cam_pos_k, "cam_lead": Config.cam_lead}
	_place_solid(v)
	acc = 0.0
	_snap(v)
	cam_y = v.y
	if v.on_enter.is_valid():
		v.on_enter.call(v)
	var seat: Variant = _seat_of(v)
	if seat != null and Game.animator != null and not Game.player.dead and not opts.get("instant", false):
		_begin_in(v, seat)
	else:
		_seated(v)
	return true


## in the seat: the engine turns over, the hands are on the wheel
func _seated(v: Veh) -> void:
	trans = null
	_engine_start(v)
	Game.hud.toast(String(v.spec.get("label", "")) + " - W/S DRIVE  A/D STEER  SPACE HANDBRAKE" + ("  SHIFT NITRO" if v.spec.get("nitro", false) else "") + "  E EXIT")
	_seat_player(v, true)
	_thud(0.3)
	if not v.model.door.is_valid():
		_s_door()


## where the player can step out: either side of the doors, then the ends, on ground that is close to the car's and clear of walls
func _exit_spot(v: Veh) -> Variant:
	var s := sin(v.yaw)
	var c := cos(v.yaw)
	var F := _footprint(v)
	var hw := F.x
	var hl := F.y
	for t: Array in [[hw + 0.95, 0.2], [-(hw + 0.95), 0.2], [hw + 1.35, -0.8], [-(hw + 1.35), -0.8], [0.0, -(hl + 1.0)], [0.0, hl + 1.0], [hw + 1.2, 1.2], [-(hw + 1.2), 1.2]]:
		var side: float = t[0]
		var along: float = t[1]
		var x := v.x + c * side + s * (along + F.z)
		var z := v.z - s * side + c * (along + F.z)
		var g: float = v.world.ground_height(x, z, 0.05, v.y + 2.2)
		if is_finite(g) and absf(g - v.y) < 1.6 and not v.world.blocked(x, z, g, Config.height, Config.radius, Config.step_up):
			return Vector3(x, g, z)
	return null


## get out: refused when the car is going too fast or there is no room (force = death, level change, menu: always works). Slow enough and room at the door: played (begin_out)
func exit(force: bool = false) -> bool:
	var v := driver_v
	if v == null:
		return false
	if trans != null and not force:      # (already getting in or out)
		return false
	if not force:
		var now := Time.get_ticks_msec() / 1000.0
		if v.speed > 6.0:
			if v.fire > 0.0 and v.speed < 22.0:      # on fire: you can throw yourself out
				return _bail(v)
			if now > exit_msg_t:
				exit_msg_t = now + 1.4
				Game.hud.toast("SLOW DOWN TO GET OUT")
			return false
		var seat: Variant = _seat_of(v)
		var door: Variant = _door_spot(v, seat) if seat != null and v.speed < 1.6 and Game.animator != null else null
		if door != null:
			return _begin_out(v, seat, door)
	var spot: Variant = _exit_spot(v)
	if not force and spot == null:
		var now := Time.get_ticks_msec() / 1000.0
		if now > exit_msg_t:
			exit_msg_t = now + 1.4
			Game.hud.toast("NO ROOM TO GET OUT")
		return false
	if spot == null:
		spot = Vector3(v.x, v.y + 2.4, v.z)
	var P := Game.player
	P.x = spot.x
	P.y = spot.y
	P.z = spot.z
	P.vx = 0.0
	P.vy = 0.0
	P.vz = 0.0
	P.yaw = v.yaw
	P.grounded = spot.y <= v.y + 2.2
	P.mode = &"normal"
	trans = null
	v.door_want = 0.0
	v.driver = false
	driver_v = null
	_engine_stop()
	_seat_player(v, false)
	_place_solid(v)
	if not force:
		_s_door()
	if v.on_exit.is_valid():
		v.on_exit.call(v, force)
	return true


## out of a burning car at speed: dropped beside it carrying some of its speed, hurt by the fall when it was fast
func _bail(v: Veh) -> bool:
	if _exit_spot(v) == null:
		return false
	var vx := v.vx * 0.5
	var vz := v.vz * 0.5
	var sp := v.speed
	exit(true)
	var P := Game.player
	P.vx = vx
	P.vz = vz
	P.vy = 2.5
	P.grounded = false
	if sp > 9.0 and Game.combat != null:
		Game.combat.hurt_player(P, (sp - 9.0) * 2.5, P.x - vx, P.z - vz, "melee")
	return true


# ------------------------------------------------------------------ getting in and out, played
func _to_local(v: Veh, x: float, z: float) -> Vector2:
	var s := sin(v.yaw)
	var c := cos(v.yaw)
	var dx := x - v.x
	var dz := z - v.z
	return Vector2(c * dx - s * dz, s * dx + c * dz)


func _to_world(v: Veh, lx: float, lz: float) -> Vector2:
	var s := sin(v.yaw)
	var c := cos(v.yaw)
	return Vector2(v.x + c * lx + s * lz, v.z - s * lx + c * lz)


## the spot by the driver's door where the character stands to get in or out, or null when something is in the way
func _door_spot(v: Veh, seat: Dictionary) -> Variant:
	var side := signf(float(seat.x))
	if side == 0.0:
		side = 1.0
	var lx := side * (_footprint(v).x + 0.5)
	var lz: float = float(seat.z) - 0.3
	var w := _to_world(v, lx, lz)
	var g: float = v.world.ground_height(w.x, w.y, 0.05, v.y + 2.2)
	if not is_finite(g) or absf(g - v.y) > 1.2 or v.world.blocked(w.x, w.y, g, Config.height, Config.radius, Config.step_up):
		return null
	return {"lx": lx, "lz": lz, "side": side, "y": g}


func _begin_in(v: Veh, seat: Dictionary) -> void:
	var F := _footprint(v)
	var side := signf(float(seat.x))
	if side == 0.0:
		side = 1.0
	var hw := F.x
	var hl := F.y
	var stand := [side * (hw + 0.5), float(seat.z) - 0.3]
	var di: Variant = v.model.door_info if v.model.door.is_valid() else null
	var wait: Variant = [side * (hw + 0.42), minf(stand[1], float(di.z0) - 0.45)] if di != null else null      # (a door swings through the stand spot: he waits clear of its arc behind its back edge, then steps in)
	var P := Game.player
	var pl := _to_local(v, P.x, P.z)
	var pts: Array = [[pl.x, pl.y]]
	var end_: float = F.z + hl + 0.75 if pl.y >= float(seat.z) else F.z - (hl + 0.75)
	if pl.x * side < hw + 0.15:      # not beside the driver's door: round the nearer end of the car
		if absf(pl.y) < hl + 0.3:
			pts.append([-side * (hw + 0.75), end_])
		pts.append([side * (hw + 0.75), end_])
	pts.append(wait if wait != null else stand)
	var len_ := 0.0
	for i in range(1, pts.size()):
		len_ += U.hyp(float(pts[i][0]) - float(pts[i - 1][0]), float(pts[i][1]) - float(pts[i - 1][1]))
	var sw := _to_world(v, stand[0], stand[1])
	var g: float = v.world.ground_height(sw.x, sw.y, 0.05, v.y + 2.2)
	var T := Trans.new()
	T.dir = "in"
	T.v = v
	T.side = side
	T.path = pts
	T.len_ = len_
	T.tw = 0.0 if len_ < 0.05 else maxf(0.3, len_ / 2.7)
	T.stand = stand
	T.wait = wait
	T.sill = [float(seat.x) + side * 0.3, float(seat.z) - 0.04]
	T.y = g if is_finite(g) else P.y
	T.pos = Vector3(P.x, P.y, P.z)
	T.yaw = P.yaw
	trans = T
	_seat_player(v, true)


func _begin_out(v: Veh, seat: Dictionary, spot: Dictionary) -> bool:
	var T := Trans.new()
	T.dir = "out"
	T.v = v
	T.side = spot.side
	T.stand = [spot.lx, spot.lz]
	T.sill = [float(seat.x) + float(spot.side) * 0.3, float(seat.z) - 0.04]
	T.y = spot.y
	T.w = 1.0
	T.k = 1.0
	T.hands = 1.0
	T.pos = Vector3(v.x, spot.y, v.z)
	T.yaw = v.yaw
	trans = T
	_engine_stop()
	_seat_player(v, true)
	return true


func _player_body(x: float, y: float, z: float, vx: float, vz: float, yaw: float) -> void:
	var P := Game.player
	P.x = x
	P.y = y
	P.z = z
	P.vx = vx
	P.vz = vz
	P.vy = 0.0
	P.yaw = yaw
	P.grounded = true
	P.mode = &"normal"
	P.crouching = false
	P.aiming = false
	P.ads = false
	P.strafing = false
	P.sprinting = false
	P.punching = false
	P.slamming = false
	P.land_t = 0.0
	P.scoped = false
	P.armed = false
	P.power_aim = false


## one frame of getting in / out: moves the feet (trans.pos) and sets the seat blend that _pose_seat hands the animator
func _trans_step(dt: float) -> void:
	var T := trans
	var v := T.v
	var has_door := v.model.door.is_valid()
	var out := PI / 2.0 * T.side
	T.t += dt
	var sw := _to_world(v, T.stand[0], T.stand[1])
	var out_yaw := v.yaw + out
	var vx := 0.0
	var vz := 0.0
	if T.dir == "in":
		var t := T.t
		var tw := T.tw
		var a := tw + (0.52 if T.wait != null else (0.32 if has_door else 0.12))      # a: the turn is done, the sitting starts
		if t < tw:      # walking round to the door, along the path (kept in the car's frame: it may roll a little)
			var d := (t / tw) * T.len_
			var i := 1
			while i < T.path.size() - 1:
				var seg := U.hyp(float(T.path[i][0]) - float(T.path[i - 1][0]), float(T.path[i][1]) - float(T.path[i - 1][1]))
				if d <= seg:
					break
				d -= seg
				i += 1
			var A: Array = T.path[i - 1]
			var B: Array = T.path[i]
			var sl := U.hyp(float(B[0]) - float(A[0]), float(B[1]) - float(A[1]))
			if sl == 0.0:
				sl = 1.0
			var u := minf(1.0, d / sl)
			var w := _to_world(v, float(A[0]) + (float(B[0]) - float(A[0])) * u, float(A[1]) + (float(B[1]) - float(A[1])) * u)
			vx = (w.x - T.pos.x) / maxf(dt, 1e-3)
			vz = (w.y - T.pos.z) / maxf(dt, 1e-3)
			T.pos.x = w.x
			T.pos.z = w.y
			var gy: float = v.world.ground_height(w.x, w.y, 0.05, v.y + 2.2)
			if is_finite(gy):
				T.pos.y = _damp(T.pos.y, gy, 18.0, dt)
			if U.hyp(vx, vz) > 0.2:
				T.yaw += U.wrap_angle(atan2(vx, vz) - T.yaw) * (1.0 - exp(-12.0 * dt))
		elif T.wait != null:      # the door swings past him, then he steps round it into the gap
			var u := _sstep(tw + 0.18, tw + 0.5, t)
			var w := _to_world(v, float(T.wait[0]) + (float(T.stand[0]) - float(T.wait[0])) * u, float(T.wait[1]) + (float(T.stand[1]) - float(T.wait[1])) * u)
			vx = (w.x - T.pos.x) / maxf(dt, 1e-3)
			vz = (w.y - T.pos.z) / maxf(dt, 1e-3)
			T.pos.x = w.x
			T.pos.z = w.y
			T.pos.y = _damp(T.pos.y, T.y, 18.0, dt)
		else:
			T.pos.x = sw.x
			T.pos.z = sw.y
			T.pos.y = _damp(T.pos.y, T.y, 18.0, dt)
		if has_door and not T.latched and t > tw - 0.15:      # a hand on the handle as he arrives
			T.latched = true
			v.door_want = 1.0
			_s_latch()
		if t >= tw + (0.22 if T.wait != null else 0.0):      # turns his back to the seat
			T.yaw += U.wrap_angle(out_yaw - T.yaw) * (1.0 - exp(-11.0 * dt))
		T.w = _sstep(a, a + 0.42, t)
		T.duck = _sstep(a, a + 0.35, t) * (1.0 - _sstep(a + 0.6, a + 0.95, t)) * 0.9
		T.k = _sstep(a + 0.42, a + 0.88, t)      # sits on the sill facing out, then swings the legs in
		T.yaw_off = out * (1.0 - T.k)
		T.hands = _sstep(a + 0.72, a + 1.0, t)
		T.sw = _sstep(0.0, a + 0.88, t)      # (the size change runs under the whole walk and sit, never as one visible shrink)
		if has_door and not T.shut and t > a + 0.72:
			T.shut = true
			v.door_want = 0.0
		if t > a + 1.0 and (not has_door or v.door_k <= 0.001):
			T.w = 1.0
			T.k = 1.0
			T.yaw_off = 0.0
			T.hands = 1.0
			T.sw = 1.0
			_seated(v)
			return
	else:
		var t := T.t
		var s0 := 0.18 if has_door else 0.05
		if has_door and not T.latched:
			T.latched = true
			v.door_want = 1.0
			_s_latch()
		T.hands = 1.0 - _sstep(0.0, 0.25, t)
		T.k = 1.0 - _sstep(s0, s0 + 0.42, t)      # swings the legs out onto the sill
		T.yaw_off = out * (1.0 - T.k)
		T.duck = _sstep(s0 + 0.1, s0 + 0.4, t) * (1.0 - _sstep(s0 + 0.55, s0 + 0.85, t)) * 0.9
		T.w = 1.0 - _sstep(s0 + 0.42, s0 + 0.85, t)      # and stands up at the door
		T.sw = 1.0 - _sstep(0.0, s0 + 0.85, t)
		T.pos = Vector3(sw.x, T.y, sw.y)
		T.yaw = out_yaw
		if t > s0 + 0.85:
			_player_body(sw.x, T.y, sw.y, 0.0, 0.0, out_yaw)
			v.door_clear = true
			trans = null
			v.driver = false
			driver_v = null
			_seat_player(v, false)
			_place_solid(v)
			if v.on_exit.is_valid():
				v.on_exit.call(v, false)
			return
	_player_body(T.pos.x, T.pos.y, T.pos.z, vx, vz, T.yaw)


## p is outside the arc the driver's door sweeps (it can shut without passing through them)
func _clear_of_door(v: Veh, p: Player) -> bool:
	var di: Variant = v.model.door_info
	if di == null or p.dead:
		return true
	var l := _to_local(v, p.x, p.z)
	var sd := signf(float(di.x))
	if sd == 0.0:
		sd = 1.0
	return l.y > float(di.z1) + 0.35 or l.x * sd < absf(float(di.x)) - 0.2 or U.hyp(l.x - float(di.x), l.y - float(di.z1)) > float(di.z1) - float(di.z0) + 0.4 or absf(p.y - v.y) > 2.5


## the doors: eased toward v.door_want every frame (a door left open shuts by itself after v.door_shut_at seconds); a shut door slams
func _door_step(v: Veh, dt: float) -> void:
	if not v.model.door.is_valid():
		return
	if v.door_clear:      # (left open behind you until you are out of its arc)
		if v.driver:
			v.door_clear = false
		elif _clear_of_door(v, Game.player):
			v.door_clear = false
			v.door_shut_at = 0.12
	if v.door_shut_at > 0.0:
		v.door_shut_at -= dt
		if v.door_shut_at <= 0.0:
			v.door_want = 0.0
	var want := v.door_want
	var k0 := v.door_k
	if k0 == want:
		return
	var k := _toward(k0, want, dt * (2.4 if want > k0 else 3.6))
	v.door_k = k
	v.model.door.call(1.0 - (1.0 - k) * (1.0 - k) if want > k0 else k * k)      # swings out quick and slows; swings in slow and speeds up to the slam
	if k == 0.0 and k0 > 0.0:
		_s_door()
		_thud(0.18)


## the player's character sits in the car (Animator.seat); out of it the normal animation takes over again
func _seat_player(v: Veh, on: bool) -> void:
	var an := Game.animator
	if an == null:
		return
	var s: Variant = _seat_of(v)
	if not on or s == null:
		an.seat = null
		seat_.w = NAN
		return
	an.seat = seat_
	var sw: Variant = s.get("wheel")
	if sw != null:
		seat_wheel_.tilt = sw.tilt
		seat_wheel_.r = sw.r
		seat_.wheel = seat_wheel_
	else:
		seat_.wheel = null


## how tall the character sits: the top of the model above the hips, measured once per character (the skinned vertices at rest)
func _sit_height() -> float:
	if sit_h > 0.0:
		return sit_h
	var an := Game.animator
	if an == null or an.skel == null:
		return 0.0
	var rec: Variant = an.by_key.get(&"pelvis")
	if rec == null:
		return 0.0
	var hip: float = an.skel.get_bone_global_rest(rec.bone).origin.y
	var top := -INF
	var walk: Array[Node] = [an.actor]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null and (n as MeshInstance3D).is_visible_in_tree():
			top = maxf(top, (n as MeshInstance3D).mesh.get_aabb().end.y)
	var h := (top - hip) * an.skel.global_basis.get_scale().y / maxf(an.actor.scale.y, 1e-3)
	if h > 0.3 and h < 3.0:
		sit_h = h
	return sit_h


## the seat's scale for this character: as large as the roof over the seat allows (never above full size, never below the type's own `scale`)
func _seat_scale(v: Veh, s: Dictionary) -> float:
	if sit_h == 0.0:
		return s.scale
	var room: float = float(s.get("roof", v.model.height)) - 0.05 - float(s.y)
	return clampf(room / (sit_h * cos(float(s.get("recline", 0.0)))), s.scale, 1.0)      # (a reclined seat sits him lower: the head comes down by the tip back)


func _pose_seat(v: Veh) -> void:
	var an := Game.animator
	if an == null or an.seat != seat_:
		return
	var s: Dictionary = _seat_of(v)
	var T: Trans = trans if trans != null and trans.v == v else null
	var sv := Vector3(s.x, s.y, s.z)
	if T != null:
		sv = Vector3(lerpf(T.sill[0], s.x, T.k), s.y, lerpf(T.sill[1], s.z, T.k))
	var cw := v.model.chassis.global_transform
	var w := cw * sv
	seat_.x = w.x
	seat_.y = w.y
	seat_.z = w.z
	seat_.quat = cw.basis.get_rotation_quaternion()
	seat_.scale = _seat_scale(v, s)
	seat_.recline = float(s.get("recline", 0.0))
	seat_.steer = 0.0 if T != null else v.steer
	if T != null:
		seat_.quat = seat_.quat * Quaternion(Vector3.UP, T.yaw_off)
		seat_.w = T.w
		seat_.duck = T.duck
		seat_.hands = T.hands
		seat_.sw = T.sw
	else:
		seat_.w = NAN
		seat_.duck = 0.0
		seat_.hands = 1.0
		seat_.sw = NAN
	var sw: Variant = s.get("wheel")
	if sw != null:
		seat_.wheel_pos = cw * Vector3(sw.x, sw.y, sw.z)
	if v.model.steer_wheel.is_valid():
		v.model.steer_wheel.call(v.steer)


func update(dt: float) -> void:
	for v: Veh in vehicles.duplicate():      # (Godot only: a node freed under a vehicle (its level gone) would abort this frame's pose loop on it, every frame, before the vehicles that are alive. The JS has no freed nodes.)
		if not is_instance_valid(v.model.root):
			push_warning("vehicle '%s' (owner '%s') lost its nodes: dropped" % [v.type, v.owner_])
			v.on_clear = Callable()
			remove(v)
	var P := Game.player
	var time := sim_t
	# sources hand over their own cars (traffic) and report what they need
	for s: Variant in sources:
		if s.has("tick") and _owner_of(s.get("owner", "default")).active:
			(s.tick as Callable).call(dt, driver_v, P)
	# enter / exit
	var free := not P.dead and driver_v == null
	var prompt := ""
	if driver_v != null:
		if not _live(driver_v):
			exit(true)
		elif driver_v.y < driver_v.home.y - 70.0:
			var D := driver_v
			D.x = D.home.x
			D.y = D.home.y
			D.z = D.home.z
			D.yaw = D.home.w
			D.vx = 0.0
			D.vz = 0.0
			D.vy = 0.0
			D.f = 0.0
			D.l = 0.0
			D.grounded = true
		if driver_v != null and P.dead:
			exit(true)
		elif driver_v != null and Inp.btn(&"b").pressed:
			Inp.btn(&"b").pressed = false
			if trans == null:
				exit()
	elif free:
		var c: Variant = _candidate(6.0)
		if c != null:
			prompt = ("B" if Inp.using_pad else "E") + "  " + String(c.label)
			if Inp.btn(&"b").pressed:
				Inp.btn(&"b").pressed = false
				(c.act as Callable).call()
	# fixed simulation
	var dr := driver_v
	var ctl_now: Ctl = null
	if dr != null:
		ctl_now = _read_input() if trans == null else hold_ctl
		frame_ctl.thr = ctl_now.thr
		frame_ctl.steer = ctl_now.steer
		frame_ctl.hand = ctl_now.hand
		frame_ctl.boost = ctl_now.boost
		frame_ctl.analog = ctl_now.analog
	acc += minf(dt, 0.1)
	var n := 0
	while acc >= STEP:
		for v: Veh in vehicles:
			if _live(v):
				_snap(v)
		for v: Veh in vehicles:
			if not _live(v):
				continue
			var driven := v == dr
			var idle := not driven and v.grounded and v.speed < 0.15 and absf(v.yaw_rate) < 0.02
			if not idle:
				_step(v, STEP, frame_ctl if driven else no_ctl)
		_car_pairs()
		sim_t += STEP
		acc -= STEP
		n += 1
		if n >= MAX_STEPS:
			acc = 0.0
			break
	var alpha := acc / STEP
	# frame: pose (interpolated), wheels, chassis, effects
	for v: Veh in vehicles:
		if not _live(v):
			continue
		var driven := v == dr
		_apply_pose(v, alpha)
		var p := v.prev
		var ch := v.model.chassis
		ch.rotation = Vector3(lerpf(p.c_pitch, v.c_pitch, alpha), 0.0, lerpf(p.c_roll, v.c_roll, alpha))
		ch.position.y = lerpf(p.c_y, v.c_y, alpha) - v.sag
		var spin := lerpf(p.spin, v.spin, alpha)
		var ang := lerpf(p.steer_ang, v.steer_ang, alpha)
		for w: VWheel in v.model.wheels:
			w.spin.rotation.x = spin
			if w.front:
				w.pivot.rotation.y = ang
		if driven:
			var braking := (frame_ctl.thr < -0.02 and v.f > 0.5) or (frame_ctl.thr > 0.02 and v.f < -0.5) or frame_ctl.hand
			if v.model.brake.is_valid() and braking != v.braking:
				v.braking = braking
				v.model.brake.call(braking)
			v.pedal = clampf(frame_ctl.thr, -1.0, 1.0)
			_run_over(v)
			if v.skid > 0.2 and v.grounded:
				v.skid_t -= dt
				if v.skid_t <= 0.0:
					v.skid_t = 0.06 - v.skid * 0.03
					var sy := sin(v.yaw)
					var cy := cos(v.yaw)
					for sx: float in [-1.0, 1.0]:
						Game.fx.dust(Vector3(v.x + sy * v.model.axle_r + cy * sx * v.model.track, v.y + 0.1, v.z + cy * v.model.axle_r - sy * sx * v.model.track), 1, 1.4)
			_engine_update(v, frame_ctl, dt)
		elif v.model.brake.is_valid() and v.braking:
			v.braking = false
			v.model.brake.call(false)
		if v.hit_feel > 3.0:
			_crash_feel(v, driven)
		v.hit_feel = 0.0
		v.last_hit = 0.0
		if damage.tick(v, dt, time):
			_explode(v)
		if v.solid != null:
			_place_solid(v)
		if v.model.update.is_valid():
			v.model.update.call(dt, v, driven)
		_door_step(v, dt)
	# the driver IS the player for the rest of the game (camera, enemies, HUD)
	var rig := Game.rig
	if dr != null and trans != null:      # getting in / out: the character is still the body the camera follows
		var dir := trans.dir
		_trans_step(dt)
		_pose_seat(dr)
		cam_y = dr.y
		if dir == "out" or driver_v != dr:
			_release_camera(dt)
	elif dr != null and driver_v == dr:      # (unless this frame threw him out: a blast, a death)
		var v := dr
		var p := v.prev
		var ry := p.yaw + U.wrap_angle(v.yaw - p.yaw) * alpha      # (the yaw drawn, between two steps: what the camera follows, so it turns as smoothly as the car)
		cam_y = _damp(cam_y, lerpf(p.y, v.y, alpha), 12.0 if v.grounded else 5.0, dt)      # the camera follows a calmed height, not every bump of the wheels
		_player_body(lerpf(p.x, v.x, alpha), cam_y + 0.15, lerpf(p.z, v.z, alpha), v.vx, v.vz, ry)
		P.vy = v.vy
		_pose_seat(v)
		_drive_camera(v, dt, ry)
	elif cam_saved != null or rig.fov != 0.0:
		_release_camera(dt)
	_hud_update(driver_v, prompt)


# ------------------------------------------------------------------ crashes, fire, explosions
## what an impact sounds and feels like: a crunch from where it happened (louder and glassier the harder), sparks off the struck side; the driver's camera jolts
func _crash_feel(v: Veh, driven: bool) -> void:
	var k := clampf((v.hit_feel - 3.0) / 22.0, 0.0, 1.0)
	var d: Vector2 = v.hit_dir if v.hit_dir != null else Vector2.ZERO
	var hx := v.x - d.x * v.model.hw
	var hz := v.z - d.y * v.model.hw
	if Game.sfx != null:
		Game.sfx.play_at("vehCrash", hx, v.y + 0.6, hz, {"k": k, "range": 70.0})
	var q := Vector3(hx, v.y + 0.6, hz)
	Game.fx.sparks(q, 3 + int(k * 14.0), 3.0 + k * 4.0, null, 0xffc070)
	if k > 0.4:      # glass
		Game.fx.sparks(q, 4 + int(k * 8.0), 3.0, null, 0xdfe8ee)
	if driven:
		Game.fx.shake = maxf(Game.fx.shake, 0.1 + 0.5 * k)
		Input.start_joy_vibration(0, 0.35 + 0.65 * k, 0.2 + 0.8 * k, (90.0 + 260.0 * k) / 1000.0)
		cam_kick += 0.25 + k * 0.9


## the fuse ran out: a fireball, the wreck is thrown up and spun, everything near is hurt and shoved (other vehicles too: they can go up in turn)
func _explode(v: Veh) -> void:
	var was := v == driver_v
	var R := 7.5
	damage.wreck(v)
	damage.blast_fx(v)
	v.data["no_enter"] = true
	v.boosting = false
	if v.model.brake.is_valid():
		v.model.brake.call(false)
	v.vy = 6.5 + randf() * 2.5
	v.grounded = false
	v.yaw_rate += (randf() - 0.5) * 2.6
	v.c_pv -= 1.2
	v.c_rv += (randf() - 0.5) * 3.0
	var P := Game.player
	if was:      # (thrown clear of the fireball)
		exit(true)
		var dx := P.x - v.x
		var dz := P.z - v.z
		var d := U.hyp(dx, dz)
		if d == 0.0:
			d = 1.0
		P.vx = dx / d * 6.0
		P.vz = dz / d * 6.0
		P.vy = 5.5
		P.grounded = false
		Game.combat.hurt_player(P, 150.0, v.x, v.z, "blast")
	for k: Robot in Game.combat.enemies.robots:
		if k.dead:
			continue
		var d := U.hyp(k.x - v.x, k.z - v.z)
		if d > R or absf(k.y - v.y) > 4.0:
			continue
		Game.combat.damage(k, 900.0 * (1.0 - d / R) + 60.0, P, 6.0, null)
		var dd := d if d != 0.0 else 1.0
		k.kvx += (k.x - v.x) / dd * 8.0 * (1.0 - d / R)
		k.kvz += (k.z - v.z) / dd * 8.0 * (1.0 - d / R)
	if not was and not P.dead:
		var d := U.hyp(P.x - v.x, P.z - v.z)
		if d < R and absf(P.y - v.y) < 4.0:
			if driver_v != null:
				damage.hurt(driver_v, 500.0 * (1.0 - d / R))
			else:
				Game.combat.hurt_player(P, 90.0 * (1.0 - d / R) + 12.0, v.x, v.z, "blast")
		Game.fx.shake = maxf(Game.fx.shake, clampf(1.4 - d / 30.0, 0.0, 1.2))
	for o: Veh in vehicles:
		if o == v or not _live(o):
			continue
		var dx := o.x - v.x
		var dz := o.z - v.z
		var d := U.hyp(dx, dz)
		if d == 0.0:
			d = 1.0
		if d > R + 1.5 or absf(o.y - v.y) > 3.0:
			continue
		var k := 1.0 - d / (R + 1.5)
		damage.hurt(o, 1350.0 * k, k > 0.55)
		var kick := 9.0 * k * 1400.0 / o.h.mass
		o.vx += dx / d * kick
		o.vz += dz / d * kick
		o.yaw_rate += (randf() - 0.5) * 3.0 * k
		if o.grounded and k > 0.3:
			o.vy = 3.0 * k * 1400.0 / o.h.mass
			o.grounded = false
	if v.on_wreck.is_valid():
		v.on_wreck.call(v)


## the vehicle whose body contains a world point (a bullet's end), or null
func _vehicle_at(x: float, y: float, z: float, m: float = 0.2) -> Veh:
	for v: Veh in vehicles:
		if not _live(v):
			continue
		var F := _footprint(v)
		var s := sin(v.yaw)
		var c := cos(v.yaw)
		var dx := x - v.x
		var dz := z - v.z
		var lz := dx * s + dz * c - F.z
		var lx := dx * c - dz * s
		if absf(lz) < F.y + m and absf(lx) < F.x + m and y > v.y - 0.2 and y < v.y + v.model.height + m:
			return v
	return null


## the traffic's own cars (solids that can be knocked, see _run_knocks) in a blast or under fire: they become vehicles of ours and take the hit. (The sources list them: the World has no box query for a script.)
func _blast_solids(x: float, y: float, z: float, R: float, dmg: float, single: bool = false) -> Veh:
	var got: Veh = null
	for s: Variant in sources:
		if not s.has("knockable") or not _owner_of(s.get("owner", "default")).active:
			continue
		for e: Variant in (s.knockable as Callable).call(x, y, z, R + 1.0):
			var d: float = e.d
			var nv: Veh = (e.knock as Callable).call(null)
			if nv == null:
				continue
			got = nv
			var k := 1.0 if single else clampf(1.0 - d / (R + 1.0), 0.0, 1.0)
			damage.hurt(nv, dmg * k, not single and k > 0.55)
			if not single:
				var dl := d if d != 0.0 else 1.0
				var kick := 8.0 * k * 1400.0 / nv.h.mass
				nv.vx += (nv.x - x) / dl * kick
				nv.vz += (nv.z - z) / dl * kick
				nv.yaw_rate += (randf() - 0.5) * 2.0 * k
			if single:
				return got
	return got


## a traffic car (a solid with knock) was hit by a vehicle: it becomes a vehicle of ours where it stands, moving as it was, and the hit is played out as two bodies. ENGINE DIFFERENCE: the World does not say which solid a wall probe stopped at, so a source is asked who stands at the contact.
func _knock_at(v: Veh) -> bool:
	if v.wall_s <= 1.2 or v.wrecked:
		return false
	for s: Variant in sources:
		if not s.has("knockable") or not _owner_of(s.get("owner", "default")).active:
			continue
		for e: Variant in (s.knockable as Callable).call(v.wall_x, v.y + 0.5, v.wall_z, 0.8):
			var nv: Veh = (e.knock as Callable).call(v)
			if nv == null:
				_impact(v, 6.0, v.wall_x, v.y + 0.55, v.wall_z, -v.wall_ux, -v.wall_uz, 1.0)
				return true
			v.vx = v.pvx
			v.vz = v.pvz      # the wall bounce of this step is undone: it was a car, not a wall
			var cl: Variant = _sat(_obb(v), _obb(nv))
			var nx: float = cl.nx if cl != null else -v.wall_ux
			var nz: float = cl.nz if cl != null else -v.wall_uz
			var px: float = cl.px if cl != null else v.wall_x
			var pz: float = cl.pz if cl != null else v.wall_z
			var sp := _exchange(v, nv, nx, nz, px, pz)
			if sp > 0.5:
				_car_hit(v, nv, sp, nx, nz, px, pz)
			return true
	return false


## weapons: a bullet that stops on a vehicle hurts it (more in the engine bay), a blast hurts every vehicle in reach, and while you drive the car's body takes most of what is shot at you
func bind_combat(C: Combat) -> void:
	C.on_world_shot = func(hp: Variant, dmg: float) -> void:
		var v := _vehicle_at(hp.x, hp.y, hp.z)
		if v == null:
			v = _blast_solids(hp.x, hp.y, hp.z, 0.6, 0.0, true)
		if v == null or v.wrecked:
			return
		var s := sin(v.yaw)
		var c := cos(v.yaw)
		var front: bool = (float(hp.x) - v.x) * s + (float(hp.z) - v.z) * c > v.model.axle_f * 0.5
		damage.hurt(v, dmg * (1.35 if front else 0.9))
		Game.fx.sparks(Vector3(hp.x, hp.y, hp.z), 3, 2.5, null, 0xffd080)
	C.on_blast = func(x: float, y: float, z: float, R: float, dmg: float) -> void:
		for v: Veh in vehicles:
			if not _live(v) or v.wrecked:
				continue
			var dx := v.x - x
			var dz := v.z - z
			var d := maxf(0.0, U.hyp(dx, dz) - v.model.hw)
			var r := R + 1.0
			if d > r or absf(v.y - y) > 3.0:
				continue
			var k := 1.0 - d / r
			damage.hurt(v, dmg * 2.4 * k, k > 0.6)
			var l := U.hyp(dx, dz)
			if l == 0.0:
				l = 1.0
			var kick := 7.0 * k * 1400.0 / v.h.mass
			v.vx += dx / l * kick
			v.vz += dz / l * kick
		_blast_solids(x, y, z, R, dmg * 2.4)
	C.vehicle_armor = func(P: Player, amount: float, _sx: float, _sz: float, kind: String) -> float:
		if P != Game.player or driver_v == null or trans != null or driver_v.wrecked:
			return amount
		damage.hurt(driver_v, amount * 5.0)
		return amount * (0.25 if kind == "melee" else 0.35)


## camera while driving: farther back and wider with speed, yaw follows the car and leans into the corner, manual look wins
func _drive_camera(v: Veh, dt: float, yaw: float) -> void:
	var rig := Game.rig
	var cam := CAM_BASE.duplicate()
	cam.merge(v.spec.get("cam", {}), true)
	var k := clampf(v.speed / v.h.top_speed, 0.0, 1.3)
	if rig.manual_t > 1.5:
		rig.pitch = _damp(rig.pitch, cam.pitch, 1.4, dt)
	# the lens lags under hard acceleration and closes in under braking (the car pulls away from it / rushes toward it), and an impact shoves it
	cam_ax = _damp(cam_ax, v.ax_s if v.grounded else 0.0, 3.5, dt)
	cam_kick = _damp(cam_kick, 0.0, 5.0, dt)
	var lag := clampf(cam_ax * 0.045, -0.55, 0.75) * clampf(v.speed / 6.0, 0.0, 1.0) + cam_kick * 0.35
	Config.cam_dist = _damp(Config.cam_dist, float(cam.dist) + _sstep(0.0, 1.0, k) * float(cam.dist_gain) + lag, 2.6, dt)
	Config.cam_height = _damp(Config.cam_height, cam.height, 3.0, dt)
	Config.cam_pos_k = _damp(Config.cam_pos_k, 24.0, 3.0, dt)
	Config.cam_lead = _damp(Config.cam_lead, 0.05, 3.0, dt)
	var base := Config.fov
	cam_fov = _damp(cam_fov if cam_fov != 0.0 else base, base + float(cam.fov_gain) * _sstep(0.0, 1.0, k) + (5.0 if v.boosting else 0.0), 3.0 if v.boosting else 2.2, dt)
	rig.fov = cam_fov
	if rig.manual_t > 0.9 and v.speed > 1.5:
		# behind the car, leaning into the turn; in a slide it swings partway toward where the car is actually going, so a drift shows the road ahead and not the kerb
		var vel_yaw := atan2(v.vx, v.vz)
		var slide := 0.45 * _sstep(4.0, 10.0, v.speed) if v.f > 3.0 else 0.0
		var want := yaw + U.wrap_angle(vel_yaw - yaw) * slide + clampf(v.yaw_rate * float(cam.look), -0.3, 0.3) * clampf(v.speed / 10.0, 0.0, 1.0)
		rig.yaw += U.wrap_angle(want - rig.yaw) * (1.0 - exp(-(2.4 + v.speed * 0.06) * dt))


func _release_camera(dt: float) -> void:
	var rig := Game.rig
	if cam_saved != null:
		var base: Dictionary = cam_saved
		Config.cam_dist = _damp(Config.cam_dist, base.cam_dist, 4.0, dt)
		Config.cam_height = _damp(Config.cam_height, base.cam_height, 4.0, dt)
		Config.cam_pos_k = _damp(Config.cam_pos_k, base.cam_pos_k, 4.0, dt)
		Config.cam_lead = _damp(Config.cam_lead, base.cam_lead, 4.0, dt)
		if absf(Config.cam_dist - float(base.cam_dist)) < 0.01:
			Config.cam_dist = base.cam_dist
			Config.cam_height = base.cam_height
			Config.cam_pos_k = base.cam_pos_k
			Config.cam_lead = base.cam_lead
			cam_saved = null
	if rig.fov != 0.0:
		cam_fov = _damp(cam_fov, Config.fov, 4.0, dt)
		rig.fov = 0.0 if absf(cam_fov - Config.fov) < 0.05 else cam_fov
		if rig.fov == 0.0:
			cam_fov = 0.0


# ------------------------------------------------------------------ HUD
func _hud_make() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	var f: Font = load("res://assets/fonts/Rajdhani-Bold.ttf")
	hud_box = VBoxContainer.new()
	hud_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hud_box.offset_left = -260.0
	hud_box.offset_right = -34.0
	hud_box.offset_top = -130.0
	hud_box.offset_bottom = -30.0
	hud_box.alignment = BoxContainer.ALIGNMENT_END
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.visible = false
	layer.add_child(hud_box)
	hud_name = Label.new()
	hud_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_name.add_theme_font_override(&"font", f)
	hud_name.add_theme_font_size_override(&"font_size", 13)
	hud_name.modulate.a = 0.75
	hud_box.add_child(hud_name)
	hud_spd = Label.new()
	hud_spd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_spd.add_theme_font_override(&"font", f)
	hud_spd.add_theme_font_size_override(&"font_size", 44)
	hud_box.add_child(hud_spd)
	hud_nbox = ColorRect.new()
	(hud_nbox as ColorRect).color = Color("#0a101dcc")
	hud_nbox.custom_minimum_size = Vector2(190.0, 6.0)
	hud_box.add_child(hud_nbox)
	hud_nitro = ColorRect.new()
	hud_nitro.color = Color("#58d4ff")
	hud_nbox.add_child(hud_nitro)
	hud_prompt = Label.new()
	hud_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hud_prompt.offset_top = -170.0
	hud_prompt.offset_bottom = -140.0
	hud_prompt.offset_left = -200.0
	hud_prompt.offset_right = 200.0
	hud_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_prompt.add_theme_font_override(&"font", f)
	hud_prompt.add_theme_font_size_override(&"font_size", 15)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#0a101dd8")
	bg.set_border_width_all(1)
	bg.border_color = Color("#6e829c")
	hud_prompt.add_theme_stylebox_override(&"normal", bg)
	hud_prompt.visible = false
	layer.add_child(hud_prompt)


func _hud_update(v: Veh, prompt: String) -> void:
	if hud_box == null:
		_hud_make()
	hud_prompt.visible = prompt != ""
	if prompt != "":
		hud_prompt.text = prompt
	hud_box.visible = v != null
	if v == null:
		return
	hud_name.text = String(v.spec.get("label", ""))
	hud_spd.text = "%03d KM/H" % roundi(v.speed * 3.6)
	var nb: bool = v.spec.get("nitro", false)
	hud_nbox.visible = nb
	if nb:
		hud_nitro.size = Vector2(190.0 * v.nitro, 6.0)


## called right after rig.update: slide the finished camera sideways for a type with a side offset
func camera_adjust(dt: float) -> void:
	var rig := Game.rig
	var side: float = (driver_v.spec.get("cam", {}) as Dictionary).get("side", 0.0) if driver_v != null else 0.0
	cam_off = _damp(cam_off, side, 4.0, dt)
	if absf(cam_off) < 0.005:
		return
	var rx := -cos(rig.yaw) * cam_off
	var rz := sin(rig.yaw) * cam_off
	rig.pos.x += rx
	rig.pos.z += rz
	rig.look.x += rx
	rig.look.z += rz


func hurt(v: Veh, amount: float, big: bool = false) -> bool:
	return damage.hurt(v, amount, big)


func explode(v: Veh) -> void:
	if not v.wrecked:
		_explode(v)
