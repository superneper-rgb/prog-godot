class_name ProbeButler
extends Drone
## PROBE BUTLER (JS enemies/gray-family.js): the house's robot butler. Hovers with a silver tray, then the cloche lifts, a probe drill spins up (eye flares, whine) and it DIVES at where you stood. Dodge sideways and it overshoots, then floats back up, open to a few hits.

const BUTLER_HP := 40.0
const WIND := 0.75
const DIVE_SPEED := 13.0
const DIVE_TIME := 0.75
const DMG := 8.0
const REC := 1.1
const CD := 2.6

const BUTLER_BARKS := {
	"pain": ["MY WAXED FINISH.", "HOW UNCOUTH.", "THIS WILL BE ON YOUR BILL.", "SIR HAS SCUFFED ME."],
	"die": ["DINNER... IS... SERVED...", "I... TENDER... MY... RESIGNATION...", "THE SILVER... POLISH IT..."],
	"alert": ["SIR IS NOT ON THE GUEST LIST.", "PLEASE REMAIN STILL FOR YOUR PROBE.", "ONE MOMENT, SIR.", "THE FAMILY SENDS ITS REGARDS."],
	"shoot": ["PROBE COURSE.", "COMPLIMENTS OF THE CHEF.", "MIND THE TRAY."],
}

## JS this.dive
class Dive:
	var tx := 0.0
	var ty := 0.0
	var tz := 0.0
	var t := 0.0
	var hit := false
	func _init(x: float, y: float, z: float) -> void:
		tx = x
		ty = y
		tz = z

var dive: Dive = null
var probe_u := 0.0


func _init(w: World, p_id: int, p_x: float, p_z: float, p_y: float, o: Dictionary = {}) -> void:
	super._init(w, p_id, p_x, p_z, p_y, o)
	name = "PROBE BUTLER"
	bark_set = BUTLER_BARKS
	voice = 1.25
	hover = 2.3
	max = BUTLER_HP
	hp = BUTLER_HP


func reset(first: bool) -> void:
	super.reset(first)
	calls = 99
	dive = null
	probe_u = 0.0
	shot_cd = 0.8 + randf()


func _begin(_kind: StringName, _dist: float) -> void:
	atk = &"dive"
	slot = &""
	a_u = 0.0
	dive = null
	set_(&"windup")
	shot_cd = CD + randf()
	E.push({"t": "robot_atk", "id": id, "kind": "shot", "ph": "windup", "x": x, "y": y, "z": z})


func update(dt: float, en: Enemies, P: Player) -> void:
	if atk != &"dive" or not (state == &"windup" or state == &"attack" or state == &"recover") or P == null:
		probe_u = maxf(0.0, probe_u - dt * 2.0)
		super.update(dt, en, P)
		return
	E = en
	state_t += dt
	flash = maxf(0.0, flash - dt * 5.0)
	t += dt
	flinch_t = maxf(0.0, flinch_t - dt)
	bark_cd = maxf(0.0, bark_cd - dt)
	shot_cd = maxf(0.0, shot_cd - dt)
	poise = maxf(0.0, poise - AI.poise_regen * dt)
	immune_t = maxf(0.0, immune_t - dt)
	if state == &"windup":
		var u := minf(1.0, state_t / WIND)
		a_u = u
		probe_u = u
		_fly(dt, 0.0, 0.0, true)
		_alt(dt)
		if u < 0.75:
			_face(dt, atan2(P.x - x, P.z - z), 8.0)
		if u >= 0.75 and dive == null:
			dive = Dive.new(P.x, P.y + 1.0, P.z)
		if u >= 1.0:
			set_(&"attack")
			if randf() < 0.4:
				en.barks.say(self, "shoot")
		return
	if state == &"attack":
		var D: Dive = dive if dive != null else Dive.new(P.x, P.y + 1.0, P.z)
		D.t += dt
		probe_u = 1.0
		var d := Vector3(D.tx - x, D.ty - y, D.tz - z)
		var L := d.length()
		if L == 0.0:
			L = 1.0
		var step := DIVE_SPEED * dt
		var nx := x + d.x / L * step
		var nz := z + d.z / L * step
		if _free(nx, nz):
			x = nx
			z = nz
		else:
			D.t = 99.0
		y = maxf(world.ground_height(x, z, r, y + 0.3) + 0.4, y + d.y / L * step)
		lvz = DIVE_SPEED
		if not D.hit and not P.dead and U.hyp(P.x - x, P.z - z) < 1.0 and y > P.y - 0.3 and y < P.y + 2.1:
			D.hit = true
			if en.c.hurt_player(P, DMG, x, z, "melee"):
				P.ix += d.x / L * 6.0
				P.iz += d.z / L * 6.0
			en.push({"t": "robot_atk", "id": id, "kind": "melee", "ph": "hit", "x": x, "y": y, "z": z})
		if D.hit or D.t > DIVE_TIME or L < 0.4:
			set_(&"recover")
			lvz = 0.0
		return
	# recover: floats back up to hover height, open to a few hits
	a_u = minf(1.0, state_t / REC)
	probe_u = maxf(0.0, 1.0 - a_u * 1.5)
	_fly(dt, 0.0, 0.0, true)
	_alt(dt)
	if state_t >= REC:
		atk = &""
		set_(&"pursue")
