class_name Tethered
extends Robot
## THE TETHERED (id "tethered", user 2026-11-12; the name is a working one): the Sigil's deep guards in UNDERFOINT. A body rebuilt round a steel frame and wired by three cables to the wall of the throne.
## It hangs folded against its wall until you come inside its cables' length, takes a moment to unfold (the moment you have to run past it), then it is faster than you: but only as far as the cables let it.
## At their end it strains and swings, and its arms are long. Kill it or be through before it is up. `anchor` is where the cables meet the wall, `reach` how far from there its feet can get.
## New here, not a port. The body is enemies/tethered_view.gd (assets/underfoint/tethered.glb, tools/tethered/build_tethered.py).

const HP := 240.0
const WAKE_PAD := 2.5         # it wakes when you are this far outside its reach, if it can see you
const UNFOLD := 1.15          # seconds from knowing to moving: the gap you run through
const SPEED := 7.6            # (the player runs at 6.2, sprints at 8.7)
const HOME_SPEED := 2.2
const ARM := 2.9              # how far from its middle the scythes reach
const WIND := 0.42
const LUNGE := 0.34
const REST := 0.75
const DMG := 24.0
const LOSE := 9.0             # further than this outside its reach for LOSE_T seconds: it goes back to its wall and folds
const LOSE_T := 3.5
const HIVE := 22.0            # one that wakes wakes the others this near that it can see

var tethered := true
var anchor := Vector3.ZERO
var reach := 9.0
var home := Vector2.ZERO      # where it hangs (x, z)
var home_yaw := 0.0
var awake := false
var far_t := 0.0
var strain := 0.0             # 0..1: how hard it is pulling at the end of its cables (the view leans it and draws them taut)
var fold := 1.0               # 1 folded against the wall .. 0 up (the view)
var unfold := UNFOLD           # its own: two side by side do not get up as one


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super._init(w, p_id, p_x, p_z, p_y, o)
	max = HP
	hp = HP
	r = 0.6
	h = 2.5
	name = "TETHERED"
	mute = true
	human = true      # (none of a robot's beeps, venting steam or sparks: fx.gd bot_tick)
	ledge_safe = true
	var spec: Dictionary = o.get("spawn", {})
	var a: Array = spec.get("anchor", [p_x, p_y + 4.0, p_z])
	anchor = Vector3(a[0], a[1], a[2])
	reach = float(spec.get("reach", 9.0))
	home = Vector2(p_x, p_z)
	unfold = UNFOLD + fposmod(p_id * 0.37, 1.0) * 0.3
	home_yaw = float(spec.get("face", 0.0))      # (Game.spawn_enemy sets yaw after this)


## It knows. spread: so does every other Tethered that can see this one (the one in the cell cannot see the two at the mouth, and keeps its surprise).
func wake(spread: bool) -> void:
	if awake or dead:
		return
	awake = true
	far_t = 0.0
	set_(&"alert")
	if not spread:
		return
	for o: Robot in E.robots:
		if o is Tethered and o != self and absf(o.y - y) < 4.0:
			var dx := o.x - x
			var dz := o.z - z
			var d := U.hyp(dx, dz)
			if d > 0.1 and d < HIVE and world.ray_clear(x, y + 1.6, z, dx / d, 0.0, dz / d, d, 0.04) >= d - 1.0:
				(o as Tethered).wake(false)


func update(dt: float, en: Enemies, P: Player) -> void:
	E = en
	t += dt
	state_t += dt
	flash = maxf(0.0, flash - dt * 6.0)
	flinch_t = maxf(0.0, flinch_t - dt)
	flinch_cd = maxf(0.0, flinch_cd - dt)
	immune_t = maxf(0.0, immune_t - dt)
	bcast_cd = maxf(0.0, bcast_cd - dt)
	if dead:
		dead_t += dt
		slot = &""
		strain = maxf(0.0, strain - dt * 3.0)
		return
	var dx := P.x - x
	var dz := P.z - z
	var d := U.hyp(dx, dz)
	var from_anchor := U.hyp(P.x - anchor.x, P.z - anchor.z)
	var same_floor := absf(P.y - y) < 2.2
	if not awake:
		fold = minf(1.0, fold + dt * 1.2)
		strain = maxf(0.0, strain - dt * 3.0)
		var back := U.hyp(home.x - x, home.y - z)
		if back > 0.35:      # walking back to its wall
			var ang := _steer(home.x, home.y)
			_face(dt, ang, 4.0)
			_go(dt, ang, HOME_SPEED, false)
			fold = minf(fold, 0.35)
		else:
			_go(dt, 0.0, 0.0, true)
			_face(dt, home_yaw, 3.0)
		if hp < max or (from_anchor < reach + WAKE_PAD and same_floor and not P.dead and _look(dt, P, true)):
			wake(true)
		return
	fold = maxf(0.0, fold - dt / unfold)
	if P.dead:
		_go(dt, 0.0, 0.0, true)
		_tether(dt)
		return
	far_t = far_t + dt if from_anchor > reach + LOSE or not same_floor else 0.0
	if far_t > LOSE_T:
		awake = false
		slot = &""
		hp = max      # (asleep it wakes on `hp < max`; the cables feed it while it hangs)
		set_(&"idle")
		return
	known = Known.at(P.x, P.z)
	var to_p := atan2(dx, dz)
	if state == &"alert":      # unfolding
		_go(dt, 0.0, 0.0, true)
		_face(dt, to_p, 3.0)
		if state_t > unfold:
			set_(&"pursue")
	elif state == &"stagger":
		_go(dt, 0.0, 0.0, true)
		if state_t > 0.35:
			immune_t = 2.5      # (it cannot be held down by fast fire)
			set_(&"pursue")
	elif state == &"windup":
		_go(dt, 0.0, 0.0, true)
		_face(dt, to_p, 7.0)
		a_u = clampf(state_t / WIND, 0.0, 1.0)
		if state_t >= WIND:
			hit_done = false
			set_(&"attack")
	elif state == &"attack":
		_go(dt, yaw, 8.0 if state_t < 0.14 else 0.0, state_t >= 0.14)
		if not hit_done and state_t >= 0.13:
			hit_done = true
			var dd := d if d != 0.0 else 1.0
			if same_floor and d < ARM and absf(U.wrap_angle(to_p - yaw)) < 1.2 and world.ray_clear(x, y + 1.3, z, dx / dd, 0.0, dz / dd, d, 0.04) >= d - 0.3:
				E.c.hurt_player(P, DMG, x, z, "melee")
		if state_t > LUNGE:
			slot = &""
			set_(&"recover")
	elif state == &"recover":
		_go(dt, 0.0, 0.0, true)
		_face(dt, to_p, 2.5)
		if state_t > REST:
			set_(&"pursue")
	elif d < ARM - 0.5 and same_floor and not _other_swinging():
		atk = &"melee"
		set_(&"windup")
	else:
		if state != &"pursue":
			set_(&"pursue")
		var ang := _steer(P.x, P.z)
		_face(dt, ang, 8.0)
		_go(dt, ang, SPEED, d < 1.4)
	_tether(dt)


## Two on you take turns: both blows landing in one frame was half your health gone at once.
func _other_swinging() -> bool:
	for o: Robot in E.robots:
		if o is Tethered and o != self and not o.dead and (o.state == &"windup" or o.state == &"attack"):
			return true
	return false


## The cables: its feet go no further than `reach` from the anchor. At the end of them it is pulled up short, and `strain` says how hard it is still trying.
func _tether(dt: float) -> void:
	var ax := x - anchor.x
	var az := z - anchor.z
	var d := U.hyp(ax, az)
	var pull := 0.0
	if d > reach:
		var k := reach / d
		var nx := anchor.x + ax * k
		var nz := anchor.z + az * k
		if _free(nx, nz):
			x = nx
			z = nz
		var out := (vx * ax + vz * az) / d      # the part of its speed that was along the cable is gone
		if out > 0.0:
			vx -= ax / d * out
			vz -= az / d * out
		kvx = 0.0
		kvz = 0.0
		pull = 1.0
	elif d > reach - 0.6:
		pull = (d - (reach - 0.6)) / 0.6
	if state != &"pursue" and state != &"windup" and state != &"attack":
		pull *= 0.4
	strain += (pull - strain) * minf(1.0, dt * 7.0)
