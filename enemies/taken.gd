class_name Taken
extends Robot
## THE TAKEN (id "taken", user 2026-11-12): the Sigil's hive stragglers in UNDERFOINT, townsfolk it took and let rot. One of them stands or walks its beat until it sees you; then every Taken near it knows, and they come: a shamble that turns into a rush over the last few metres, and a two-armed lunge. Melee only, no voice.
## New here, not a port. The body is enemies/taken_view.gd: one of FOINT CITY's own townsfolk species (since 2026-11-15; before, assets/underfoint/taken.glb, three heads on one body). `head` picks which
## species it was (TakenView.SPECIES).

const HP := 55.0
const NOTICE := 15.0          # it sees you inside this, if it is facing you
const HIVE := 28.0            # one that wakes wakes every Taken this near
const FORGET := 42.0          # further than this for FORGET_T seconds and it goes quiet again
const FORGET_T := 6.0
const WALK := 1.9
const RUSH := 4.7
const RUSH_AT := 6.5          # the shamble becomes a rush inside this
const REACH := 1.9
const WIND := 0.45
const LUNGE := 0.3
const REST := 0.95
const DMG := 14.0

var taken := true
var head := 0
var awake := false
var wake_in := 0.0            # the moment between knowing and moving (so a group does not start as one)
var far_t := 0.0
var speed_k := 1.0            # spec `speed_k`: the ones that come off the Sigil's body in the chase run (levels/underfoint/uf_chase.gd)
var leap_t := -1.0            # >= 0: in the air, thrown at the train (leap()): nothing else moves it until it lands
var leap_dur := 0.8
var leap_wait := 0.0          # it gathers itself this long first: the moment to shoot it
var _leap_a := Vector3.ZERO
var _leap_b := Vector3.ZERO
var held := false             # the chase places it every frame (running down the moving line after the train, hanging off a girder, lying where it fell): nothing here moves it


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super._init(w, p_id, p_x, p_z, p_y, o)
	max = HP
	hp = HP
	r = 0.42
	h = 1.8
	name = "TAKEN"
	mute = true
	human = true      # they were people: none of a robot's beeps, chimes, venting steam or sparks (fx.gd bot_tick, _ev_robot_state)
	var spec: Dictionary = o.get("spawn", {})
	head = int(spec.get("head", p_id % 10))
	speed_k = float(spec.get("speed_k", 1.0))
	if spec.has("hp"):      # (the chase's are frail: one good hit, user 2026-11-12)
		max = float(spec["hp"])
		hp = max


## It knows. spread: tell the others (only the one that saw you does: the ones it tells do not tell again).
func wake(spread: bool) -> void:
	if awake or dead:
		return
	awake = true
	far_t = 0.0
	wake_in = 0.35 if spread else randf_range(0.3, 1.1)
	set_(&"alert")
	if not spread:
		return
	for o: Robot in E.robots:
		if o is Taken and o != self and U.hyp(o.x - x, o.z - z) < HIVE and absf(o.y - y) < 6.0:
			(o as Taken).wake(false)


## It throws itself at a spot (the tail of the flatcar in the chase): it gathers itself for `wait` seconds, then an arc there over `dur` seconds, arms up, and it is an ordinary Taken again where it lands
func leap(to: Vector3, dur: float, wait: float = 0.0) -> void:
	if dead or leap_t >= 0.0:
		return
	_leap_a = Vector3(x, y, z)
	_leap_b = to
	leap_dur = dur
	leap_wait = wait
	leap_t = 0.0
	slot = &""
	awake = true
	yaw = atan2(to.x - x, to.z - z)
	set_(&"windup")


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
		return
	if held:
		return
	if leap_t >= 0.0:
		leap_t += dt
		var u := clampf((leap_t - leap_wait) / leap_dur, 0.0, 1.0)
		x = lerpf(_leap_a.x, _leap_b.x, u)
		z = lerpf(_leap_a.z, _leap_b.z, u)
		y = lerpf(_leap_a.y, _leap_b.y, u) + sin(u * PI) * 1.5
		vx = 0.0
		vz = 0.0
		kvx = 0.0
		kvz = 0.0
		a_u = 1.0
		if u >= 1.0:
			leap_t = -1.0
			set_(&"pursue")
		return
	var dx := P.x - x
	var dz := P.z - z
	var d := U.hyp(dx, dz)
	var same_floor := absf(P.y - y) < 1.6
	if not awake:
		if hp < max or (d < NOTICE and same_floor and not P.dead and _look(dt, P, false)):
			wake(true)
		else:
			_patrol(dt)
		return
	if P.dead:
		_go(dt, 0.0, 0.0, true)
		return
	far_t = far_t + dt if d > FORGET else 0.0
	if far_t > FORGET_T and speed_k <= 1.0:      # lost him: quiet again, and back to its beat
		awake = false
		slot = &""
		set_(&"idle")
		return
	known = Known.at(P.x, P.z)
	if state == &"stagger":
		_go(dt, 0.0, 0.0, true)
		if state_t > 0.5:
			set_(&"pursue")
		return
	if state == &"alert":
		_go(dt, 0.0, 0.0, true)
		_face(dt, atan2(dx, dz), 7.0)
		if state_t > wake_in:
			set_(&"pursue")
		return
	if state == &"windup":
		_go(dt, 0.0, 0.0, true)
		_face(dt, atan2(dx, dz), 6.0)
		a_u = clampf(state_t / WIND, 0.0, 1.0)
		if state_t >= WIND:
			hit_done = false
			set_(&"attack")
		return
	if state == &"attack":
		_go(dt, yaw, 7.5 if state_t < 0.16 else 0.0, state_t >= 0.16)
		if not hit_done and state_t >= 0.12:
			hit_done = true
			var dd := d if d != 0.0 else 1.0
			if same_floor and d < REACH and world.ray_clear(x, y + 1.0, z, dx / dd, 0.0, dz / dd, d, 0.04) >= d - 0.2:
				E.c.hurt_player(P, DMG, x, z, "melee")
		if state_t > LUNGE:
			slot = &""
			set_(&"recover")
		return
	if state == &"recover":
		_go(dt, 0.0, 0.0, true)
		if state_t > REST:
			set_(&"pursue")
		return
	if d < REACH - 0.2 and same_floor and E.slot_free(&"melee", self):
		atk = &"melee"
		slot = &"melee"
		set_(&"windup")
		return
	if state != &"pursue":
		set_(&"pursue")
	var ang := _steer(P.x, P.z)
	_face(dt, ang, 5.0)
	_go(dt, ang, (RUSH if d < RUSH_AT or speed_k > 1.0 else WALK) * speed_k, d < 1.0)
