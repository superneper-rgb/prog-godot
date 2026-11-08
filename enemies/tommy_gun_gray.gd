class_name TommyGunGray
extends GrayAlien
## TOMMY-GUN GRAY (JS enemies/gray-family.js): a gray in a pinstripe suit and fedora with a drum-fed plasma tommy gun. He never sprays blind: he plants his feet, PAINTS the sweep first with a red laser line (one pass across the arc, ~1 s), re-aims, then fires a long burst along exactly that line. Bolts fly at chest height, so you duck behind cover or JUMP the line. One sweep at a time per fight (the grays' volley token), and only while he is on your screen.

const TOMMY_HP := 100.0
const CD_MIN := 3.6
const CD_MAX := 5.2
const PAINT := 1.05
const AIM := 0.3
const FIRE := 1.1
const RATE := 13.0
const DMG := 3.0
const ARC := 0.5
const MIN := 4.0
const MAXD := 26.0
const BOLT_SPEED := 30.0

const TOMMY_NAMES: Array[String] = ["JOEY DRUMS", "RICO \"RAT-A-TAT\"", "LITTLE NICKY", "FRANKIE FINGERS", "SONNY CHICAGO"]
const TOMMY_BARKS := {
	"pain": ["Hey! I just had this pressed!", "Ow! My good side!", "You're gonna regret that, pal!", "Ya put a hole in my fedora!", "Madonna! Right in the pinstripes!"],
	"die": ["Tell Ma... the sauce... needs salt...", "Rosebud... no wait, wrong movie...", "I shoulda... stayed... in Chicago..."],
	"alert": ["It's the green-lovers! Get the drum!", "Well look who crashed the wedding.", "Nobody leaves this party breathin'!", "You got a lotta nerve showin' your face here!"],
	"shoot": ["Rat-a-tat-tat!", "Hold still, I wanna paint ya!", "Dance for me!", "Say goodnight!", "Here comes the band!"],
}

## JS this.sweep
class Sweep:
	var t := 0.0
	var acc := 0.0
	var a0 := 0.0
	var a1 := 0.0
	var pitch := 0.0
	var len := 0.0

var sweep: Sweep = null
var laser_on := false
var laser_fire := false
var laser_dir := Vector3(0.0, 0.0, 1.0)
var laser_len := 10.0


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super._init(w, p_id, p_x, p_z, p_y, o)
	name = TOMMY_NAMES[p_id % TOMMY_NAMES.size()]
	bark_set = TOMMY_BARKS
	voice = 0.5 + randf() * 0.08
	max = TOMMY_HP
	hp = TOMMY_HP


func reset(first: bool) -> void:
	super.reset(first)
	sweep = null
	laser_on = false
	laser_fire = false
	mind_cd = 1e9
	shot_cd = _rnd(1.4, 2.6)


func update(dt: float, en: Enemies, P: Player) -> void:
	mind_cd = 1e9                                     # no mind blast: the drum is his whole act
	if sweep != null and (state != &"pursue" or dead):
		_end_sweep()
	super.update(dt, en, P)


func _end_sweep() -> void:
	sweep = null
	laser_on = false
	laser_fire = false
	volley_drop()


func _pursue(dt: float, P: Player, dx: float, dz: float, dist: float, sees: bool) -> void:
	if sweep == null:
		super._pursue(dt, P, dx, dz, dist, sees)
		return
	var S := sweep
	S.t += dt
	_go(dt, 0.0, 0.0, true)                          # feet planted for the whole sweep
	var u: float
	var firing := false
	if S.t < PAINT:
		u = S.t / PAINT                              # 1. paint the arc with the laser
	elif S.t < PAINT + AIM:
		u = 1.0 - (S.t - PAINT) / AIM                # 2. swing back to the start (the laser goes with it)
	elif S.t < PAINT + AIM + FIRE:
		u = (S.t - PAINT - AIM) / FIRE               # 3. fire along exactly that line
		firing = true
	else:
		_end_sweep()
		shot_cd = _rnd(CD_MIN, maxf(CD_MIN, CD_MAX))
		if randf() < 0.3:
			E.barks.say(self, "shoot")
		return
	var ang := lerpf(S.a0, S.a1, u * u * (3.0 - 2.0 * u))
	yaw = ang
	var cp := cos(S.pitch)
	laser_on = true
	laser_fire = firing
	laser_dir = Vector3(sin(ang) * cp, sin(S.pitch), cos(ang) * cp)
	laser_len = S.len
	volley_take(1.5)
	if firing:
		S.acc += dt * RATE
		while S.acc >= 1.0:
			S.acc -= 1.0
			var s := sin(ang)
			var c := cos(ang)
			var ox := x + s * 0.75 - c * 0.2
			var oz := z + c * 0.75 + s * 0.2
			var oy := y + 1.0
			var jit := (randf() - 0.5) * 0.03
			E.fire(self, ox, oy, oz, sin(ang + jit) * cp, laser_dir.y, cos(ang + jit) * cp, {"kind": "plasma", "speed": BOLT_SPEED, "dmg": DMG, "r": 0.15})
			fire_t = 0.09


func _plasma(P: Player, dist: float, face_ok: bool) -> void:
	if shot_cd > 0.0 or not face_ok or dist < MIN or dist > MAXD:
		return
	if not on_screen() or not volley_free() or not CreatureGameplay.can_attack(self, &"shot"):
		return
	volley_take(3.0)
	CreatureGameplay.claim_attack(self)
	var base := atan2(P.x - x, P.z - z)
	var dir := -1.0 if randf() < 0.5 else 1.0
	sweep = Sweep.new()
	sweep.a0 = base - dir * ARC
	sweep.a1 = base + dir * ARC
	sweep.pitch = atan2(P.y + 1.1 - (y + 1.0), maxf(1.0, dist))
	sweep.len = dist + 6.0
	E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "windup", "x": x, "y": y, "z": z})
