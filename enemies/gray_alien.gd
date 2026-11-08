class_name GrayAlien
extends Robot
## GRAY ALIEN ("Don Grayleone", JS enemies/gray-alien.js): a fat little gray alien who talks like a mafioso. Same senses / alert / search / stagger / death state machine as Robot. He circle-strafes at a comfortable range and fires a plasma pistol in short, telegraphed bursts.
## Fair-fight rules: slower than the player, staggerable, a readable glow before each bolt, he only opens fire while he is on the player's screen, and grays take turns (one burst at a time per fight). Every 16-24 s he stops for a mind blast: a slow purple orb that shoves and briefly slows.

const ALIEN_HP := 85.0
const RUN := 5.4            # m/s (the player runs at 6.2: you can always outrun or close on him)
const WALK := 2.2
const ACCEL := 20.0         # how fast he changes direction
const SHOT_DMG := 4.0       # per plasma bolt (x ai_damage)
const SHOT_SPEED := 24.0    # slow enough to sidestep at range
const SHOT_WIND := 0.4      # glowing-pistol telegraph before every bolt
const SHOT_CD := 0.34       # seconds between shots inside a burst
const BURST := 3            # shots per burst (+0 or +1 at random)
const BURST_PAUSE := 1.5    # pause between bursts
const SHOT_SPREAD := 0.07   # radians of random aim error
const SHOT_MIN := 2.0
const SHOT_MAX := 30.0
const RING_MIN := 6.0       # he backs off when you are closer than this ...
const RING_MAX := 11.0      # ... and closes in when you are further than this
const MIND_CD_MIN := 16.0   # mind blast cool-down (s), random in [min, max]
const MIND_CD_MAX := 24.0
const MIND_WIND := 0.85     # telegraph (s)
const MIND_REC := 0.75
const MIND_DMG := 6.0
const MIND_SPEED := 15.0
const MIND_PUSH := 11.0     # shove (m/s impulse, decays in ~0.3 s: roughly 1.3 m)
const MIND_SLOW_T := 1.5    # seconds the player stays slowed
const MIND_SLOW_MUL := 0.7  # player speed multiplier while slowed
const MIND_MIN := 4.0
const MIND_MAX := 20.0
const POISE := 90.0         # stagger threshold (stock robot 70): heavy hits and combos interrupt him
const SCREEN_MARGIN := 0.15 # rad outside the camera's view in which he still holds fire
const R_HIT := 0.42         # hit capsule: fat but short (the model's belly is ~0.3 m radius)
const H_HIT := 1.55
const SHIELD_TAKE := 0.15

# what the TRANSLATOR makes of their language (it renders grays as fast-talking wiseguys, "Don Grayleone")
const NAMES: Array[String] = ["DON GRAYLEONE", "VINNY THE PROBE", "SAL \"TWO-BEAMS\"", "TONY BALONEY", "BIG PAULIE"]
const BARKS := {
	"pain": ["OW! Whaddaya, crazy?!", "Hey! Not the face! I got a reputation!", "Ya shot me! In MY own neighborhood!", "Madonna mia, that stung!", "You're makin' a big mistake, pal!",
		"That's gonna cost ya, capisce?", "Right in the cannoli! Ya animal!", "I'm tellin' my cousin from Zeta Reticuli!", "Hey, hey, hey! Watch the shirt! It is SILK!"],
	"die": ["Tell my mother... I love... her cooking...", "Fuhgeddaboudit...", "Ya got me... but the family... remembers...", "I'm sleepin'... with the star fishes...", "Ahh... that is the thanks I get..."],
	"alert": ["Hey! You! This is a private abduction!", "Well, well, well. Look who walked in.", "You lost, pal? 'Cause I can show ya the way out.", "Ya come to MY planet? With THAT haircut?",
		"Nice day for a shakedown, eh?", "Hey, Earth guy! You got a permit for that?", "You're in the wrong neighborhood, friend."],
	"shoot": ["Eat plasma, ya mook!", "Stand still, will ya?! I ain't gonna hurt ya much!", "Say hello to my little friend!", "Ya want some? Ya want some?!", "It's nothin' personal, kid!",
		"Take it like a man!", "Capisce?!", "Where ya goin?! Come back here!", "Ya makin' me work for it!", "Fuhgeddaboudit!"],
	"mind": ["Let's talk about this... in MY head!", "Relax, relax. Let me get in your head!", "I'm gonna make ya an offer ya can't refuse!", "Hey, calm down. I just wanna rearrange ya brain!", "Siddown! SIDDOWN!"],
}

static var TABLE: AiTable = _table()

var plasma_aim := 0.0
var plasma_pending := false
var plasma_target: Variant = null
var burst_left := 3
var mind_cd := 0.0
var strafe_dir := 1.0
var strafe_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0


static func _table() -> AiTable:
	var t := AiTable.new()
	t.r = R_HIT
	t.h = H_HIT
	t.walk = WALK
	t.run = RUN
	t.accel = ACCEL
	t.alert_delay = 0.22
	t.s_wind = MIND_WIND
	t.s_act = 0.22
	t.s_rec = MIND_REC
	t.flinch = 0.2
	t.flinch_cd = 0.4
	t.stagger = 0.7
	t.stagger_immune = 1.6
	t.poise_max = POISE
	return t


static func _rnd(a: float, b: float) -> float:
	return a + randf() * (b - a)


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	ai = TABLE
	super._init(w, p_id, p_x, p_z, p_y, o)
	name = NAMES[p_id % NAMES.size()]
	bark_set = BARKS
	alien = true
	speech = true      # speech: gray tongue + translated subtitle
	voice = 0.55 + randf() * 0.12
	r = R_HIT
	h = H_HIT
	max = ALIEN_HP
	hp = ALIEN_HP


func reset(first: bool) -> void:
	super.reset(first)
	plasma_aim = 0.0
	plasma_pending = false
	plasma_target = null
	burst_left = maxi(1, BURST)
	mind_cd = _rnd(5.0, 9.0)
	strafe_dir = -1.0 if randf() < 0.5 else 1.0
	strafe_t = _rnd(0.4, 1.2)
	dash_t = 0.0
	dash_cd = _rnd(3.0, 5.0)
	fire_t = 0.0
	shot_cd = _rnd(0.8, 1.6)
	aim = 0.0


## true while this alien is inside the game camera's view (+ margin): grays never open fire from off screen
func on_screen() -> bool:
	var cam := Game.camera
	if cam == null:
		return true
	var v := Vector3(x, y + 1.0, z) - cam.global_position
	var L := v.length()
	if L < 4.0:      # right next to you: always counts as seen
		return true
	var f := -cam.global_transform.basis.z
	var vp := cam.get_viewport().get_visible_rect().size
	var half := atan(tan(deg_to_rad(cam.fov) * 0.5) * (vp.x / maxf(vp.y, 1.0)))      # horizontal half-angle
	return acos(clampf(v.dot(f) / L, -1.0, 1.0)) < half + SCREEN_MARGIN


## a Consigliere's shield (gray-family.js sets shield_t every frame it covers this gray): it soaks most of a hit. Combat has already taken the hp: give the rest back, and undo a kill the shield stopped.
func hurt(amount: float, from: Variant, kb: float, pt: Variant, kill: bool) -> void:
	if shield_t > 0.0 and state != &"dead":
		var back := amount * (1.0 - SHIELD_TAKE)
		hp += back
		amount -= back
		kb *= 0.2
		if kill and hp > 0.0:
			kill = false
			dead = false
		if E != null:
			E.push({"t": "bolt_hit", "x": x, "y": y + 1.1, "z": z, "kind": "world", "bk": "ring", "nx": 0.0, "ny": 1.0, "nz": 0.0})
	super.hurt(amount, from, kb, pt, kill)


## grays take turns: one burst at a time per fight (a token on the enemy manager, released at the end of a burst or when it goes stale)
func volley_free() -> bool:
	if E == null:
		return true
	var v: Dictionary = E.gray_volley
	if v.is_empty() or int(v["id"]) == id or E.t > float(v["until"]):
		return true
	for o: Robot in E.robots:
		if o.id == int(v["id"]) and not o.dead and o.state != &"dead":
			return false
	return true


func volley_take(hold: float) -> void:
	if E != null:
		E.gray_volley = {"id": id, "until": E.t + hold}


func volley_drop() -> void:
	if E != null and not E.gray_volley.is_empty() and int(E.gray_volley["id"]) == id:
		E.gray_volley = {}


func update(dt: float, en: Enemies, P: Player) -> void:
	shield_t = maxf(0.0, shield_t - dt)
	plasma_aim = maxf(0.0, plasma_aim - dt)
	if state != &"pursue":
		plasma_pending = false
	if state == &"dead" or dead or state == &"stagger":
		volley_drop()
	if P != null and plasma_pending and plasma_aim > 0.07:
		plasma_target = {"x": P.x, "y": P.y, "z": P.z, "vx": 0.0, "vz": 0.0}
	if state != &"dead" and P != null:
		fire_t = maxf(0.0, fire_t - dt)
		mind_cd = maxf(0.0, mind_cd - dt)
		dash_t = maxf(0.0, dash_t - dt)
		dash_cd -= dt
		aim = clampf(atan2(P.y + 1.0 - (y + 1.1), maxf(0.5, U.hyp(P.x - x, P.z - z))), -0.5, 0.6)
	super.update(dt, en, P)


# ---- hunting: strafe on a ring, spam the pistol, rarely blast ----
func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	if known == null:
		set_(&"search")
		return
	var kd := U.hyp(known.x - x, known.z - z)
	if not sees and ((seen_t > Config.ai_lose_time and kd < 1.6) or seen_t > Config.ai_lose_time + 6.0 or stuck_n >= 4):
		set_(&"search")
		scan_t = 0.0
		return
	strafe_t -= dt
	if strafe_t <= 0.0:
		strafe_dir = strafe_dir if randf() < 0.35 else -strafe_dir
		strafe_t = _rnd(0.5, 1.6)
	if sees and dash_cd <= 0.0 and randf() < dt * 0.6:      # the odd side-hop
		dash_t = 0.3
		dash_cd = _rnd(3.5, 6.0)
		strafe_dir = -strafe_dir
	var face_ok := _face_err(P.x, P.z) < 0.5
	var face_a := atan2(dx, dz) if sees else atan2(vx, vz)
	if sees or U.hyp(vx, vz) > 0.3:
		_face(dt, face_a, 14.0)
	if sees and not P.dead:
		if mind_cd <= 0.0 and dist >= MIND_MIN and dist <= MIND_MAX and face_ok and randf() < dt * 0.6:
			mind_cd = _rnd(MIND_CD_MIN, maxf(MIND_CD_MIN, MIND_CD_MAX))
			_begin(&"mind", dist)
			return
		_plasma(P, dist, face_ok)
	var tx := known.x
	var tz := known.z
	var speed: float = ai.run
	if sees:
		var base := atan2(dx, dz)
		var perp := base + strafe_dir * PI / 2.0
		var rad := -1.0 if dist < RING_MIN else (1.0 if dist > RING_MAX else 0.0)      # back off / close in / hold the ring
		var side := 1.0 if rad == 0.0 else 0.75
		var mx := sin(perp) * side + sin(base) * rad
		var mz := cos(perp) * side + cos(base) * rad
		tx = x + mx * 3.0
		tz = z + mz * 3.0
		if dash_t > 0.0:
			speed *= 1.25
	_go(dt, _steer(tx, tz), speed, false)


## one plasma bolt per call, in bursts; he keeps moving the whole time
func _plasma(P: Player, dist: float, face_ok: bool) -> void:
	if shot_cd > 0.0 or not face_ok or dist < SHOT_MIN or dist > SHOT_MAX:
		return
	if not plasma_pending:
		if not on_screen() or not volley_free() or not CreatureGameplay.can_attack(self, &"shot"):
			return
		volley_take(2.5)
		CreatureGameplay.claim_attack(self)
		plasma_pending = true
		plasma_aim = SHOT_WIND
		plasma_target = {"x": P.x, "y": P.y, "z": P.z, "vx": 0.0, "vz": 0.0}
		E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "windup", "x": x, "y": y, "z": z})
		return
	if plasma_aim > 0.0:
		return
	plasma_pending = false
	var T: Dictionary = plasma_target if plasma_target != null else {"x": P.x, "y": P.y, "z": P.z, "vx": P.vx, "vz": P.vz}
	var s := sin(yaw)
	var c := cos(yaw)
	var ox := x + s * 0.55 - c * 0.22      # the pistol hand is his right (-x) side
	var oz := z + c * 0.55 + s * 0.22
	var oy := y + 1.0
	var t := dist / SHOT_SPEED
	var tx: float = float(T["x"]) + float(T["vx"]) * t * 0.6
	var tz: float = float(T["z"]) + float(T["vz"]) * t * 0.6
	var ty: float = float(T["y"]) + 1.1
	var d := Vector3(tx - ox, ty - oy, tz - oz)
	var L := d.length()
	if L == 0.0:
		L = 1.0
	d /= L
	var a := (randf() - 0.5) * 2.0 * SHOT_SPREAD
	var b := (randf() - 0.5) * 2.0 * SHOT_SPREAD
	var ca := cos(a)
	var sa := sin(a)
	var rx := d.x * ca + d.z * sa      # yaw jitter, then a little pitch jitter
	var rz := -d.x * sa + d.z * ca
	E.fire(self, ox, oy, oz, rx, d.y + b, rz, {"kind": "plasma", "speed": SHOT_SPEED, "dmg": SHOT_DMG, "r": 0.16})
	fire_t = 0.14
	burst_left -= 1
	if burst_left <= 0:
		shot_cd = BURST_PAUSE * _rnd(0.8, 1.3)
		burst_left = maxi(1, BURST + (0 if randf() < 0.5 else 1))
		volley_drop()
		if randf() < 0.25:
			E.barks.say(self, "shoot")
	else:
		shot_cd = SHOT_CD * _rnd(0.85, 1.15)
		volley_take(1.5)


# ---- the mind blast uses the stock windup -> attack -> recover states ----
func _begin(_kind: StringName, _dist: float) -> void:
	atk = &"mind"
	hit_done = false
	shot_done = false
	slot = &""
	a_u = 0.0
	set_(&"windup")
	wob = 0.0
	E.push({"t": "robot_atk", "id": id, "kind": "mind", "ph": "windup", "x": x, "y": y, "z": z})
	E.barks.say(self, "mind")


func _attack(dt: float, P: Player, _dx: float, _dz: float, _dist: float) -> void:
	a_u = minf(1.0, state_t / ai.s_act)
	_go(dt, 0.0, 0.0, true)
	if not shot_done:
		shot_done = true
		var s := sin(yaw)
		var c := cos(yaw)
		var ox := x + s * 0.7 + c * 0.3      # his left (+x) hand
		var oz := z + c * 0.7 - s * 0.3
		var oy := y + 1.05
		var d := Vector3(P.x - ox, P.y + 1.0 - oy, P.z - oz)
		var L := d.length()
		if L == 0.0:
			L = 1.0
		E.fire(self, ox, oy, oz, d.x / L, d.y / L, d.z / L, {"kind": "mind", "speed": MIND_SPEED, "dmg": MIND_DMG, "r": 0.55, "push": MIND_PUSH, "slow_t": MIND_SLOW_T, "slow_mul": MIND_SLOW_MUL})
	if state_t >= ai.s_act:
		set_(&"recover")
		shot_cd = maxf(shot_cd, 1.6)      # no plasma straight after a blast: the slow is never a set-up
