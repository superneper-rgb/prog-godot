class_name VhRush
extends RefCounted
## VISITING HOURS: section 5's machinery, the rush (JS rush.js). Once the lockdown is on, GOINT comes for you in squads through Stair A: the response team badges its 2F door open from the stairwell and spills out onto the claims floor, and once you are in the stairwell a second squad boxes you in. Nobody appears out of thin air: a squad waits behind a door you cannot see through, the door's lamp goes green with a buzz, it swings open and they run out to their spots before they fight. This file spawns them, walks them in, hides the ones on a floor that is not drawn, and despawns every one of them on a reset.

const F1 := 3.0
const F2 := 9.0
const F3 := 15.0
const F4 := 21.0
# the squads, design metres: from = where he waits (behind the door), path = the way out to his spot; door = the live door he comes through
const SQUADS := {
	"team": {"door": "saF2", "buzz": 2.2, "list": [
		{"at": 0.0, "costume": "goint_guard", "gun": "smg", "from": [192.4, F2, 969.8], "path": [[192.8, F2, 967.6], [197.8, F2, 967.7]]},
		{"at": 0.7, "costume": "goint_guard", "gun": "pistol", "from": [193.6, F2, 970.0], "path": [[193.2, F2, 967.6], [190.9, F2, 966.0]]},
		{"at": 2.4, "costume": "goint_adjuster", "gun": "smg", "from": [193.0, F2, 969.6], "path": [[193.0, F2, 967.4]], "speed": 2.6},
	]},
	"well": {"door": "saF1", "buzz": 1.2, "list": [
		{"at": 0.0, "costume": "goint_guard", "gun": "pistol", "from": [197.6, F1, 971.2], "path": [[195.0, F1, 971.6], [194.2, F1, 969.5], [191.6, F1, 969.6], [191.6, F1 + 1.6, 972.2]]},
		{"at": 0.8, "costume": "goint_guard", "gun": "smg", "from": [197.8, F1, 972.4], "path": [[195.0, F1, 971.8], [194.6, F1, 969.6]]},
		{"at": 1.6, "costume": "goint_guard", "gun": "smg", "from": [193.4, F3, 969.6], "path": [[192.0, F3, 969.6]], "door": null},
	]},
	# 3F: the tier's own two officers (one at the desk, one in the run by the gate) turn on you as you come through; once the lift is called, a third team up Stair A
	"tier": {"door": null, "buzz": 0.0, "list": [
		{"at": 0.0, "costume": "goint_guard", "gun": "pistol", "from": [196.9, F3, 964.8], "path": [[195.8, F3, 965.6]]},
		{"at": 0.4, "costume": "goint_guard", "gun": "smg", "from": [202.4, F3, 961.5], "path": [[200.0, F3, 961.5]]},
	]},
	"third": {"door": "saF3", "buzz": 1.4, "list": [
		{"at": 0.0, "costume": "goint_guard", "gun": "smg", "from": [192.6, F3, 969.9], "path": [[192.8, F3, 967.6], [194.6, F3, 965.4]]},
		{"at": 0.8, "costume": "goint_guard", "gun": "pistol", "from": [193.6, F3, 970.0], "path": [[193.3, F3, 967.6], [191.6, F3, 964.6]]},
		{"at": 8.0, "costume": "goint_adjuster", "gun": "smg", "from": [193.0, F3, 969.6], "path": [[193.0, F3, 967.2]], "speed": 2.6},
		{"at": 9.0, "costume": "goint_guard", "gun": "smg", "from": [193.6, F3, 970.0], "path": [[193.4, F3, 967.6], [196.8, F3, 966.6]]},
	]},
	# 4F: the warden's own (two GOINT XL adjusters and a guard) come out of his office into the corridor; he locks the door again behind them (relock)
	"warden": {"door": "office", "buzz": 1.0, "relock": 1.6, "list": [
		{"at": 0.0, "costume": "goint_adjuster", "gun": "smg", "from": [207.3, F4, 958.5], "path": [[204.9, F4, 958.6], [204.0, F4, 962.4]], "speed": 2.8},
		{"at": 1.2, "costume": "goint_guard", "gun": "smg", "from": [207.3, F4, 958.7], "path": [[204.9, F4, 958.6], [203.4, F4, 965.6]]},
		{"at": 2.4, "costume": "goint_adjuster", "gun": "smg", "from": [207.3, F4, 958.5], "path": [[204.9, F4, 958.6], [203.6, F4, 955.8]], "speed": 2.8},
	]},
}


class Wave:
	var id := ""
	var t := 0.0
	var queue: Array = []
	var spawned: Array = []
	var pending := 0
	var relocked := false


class Walk:
	var r: Robot
	var path: Array
	var i := 0
	var speed := 4.2
	var wait := 0.3
	var block_t := 0.0


var world: World
var admin: VhAdmin
var audio: VhAudio
var mine: Array = []
var hunt_on := {}      # id -> true
var lost := {}
var walk: Array[Walk] = []
var waves: Dictionary = {}
var ch: Array = []
var spx := 0.0
var spz := PackedFloat64Array()
var sax := PackedFloat64Array()


func _init(p_world: World, p_admin: VhAdmin, p_audio: VhAudio) -> void:
	world = p_world
	admin = p_admin
	audio = p_audio
	# the stairwell: a goon's own AI walks straight at you, and in Stair A that is into the spine. A man in the stairwell who cannot see you climbs (or comes down) the flights toward you, flight end by flight end, until he can; then he fights. CH = the way up, from 1F's door to 4F's landing (its turns well clear of the spine's ends)
	var c: Array = [[195.0, F1, 971.6]]
	for y0: float in [F1, F2, F3]:
		var yh := y0 + 3.0
		c.append_array([[193.0, y0, 969.3], [191.6, y0, 970.9], [191.6, yh, 973.8], [191.9, yh, 975.0], [194.1, yh, 975.0], [194.3, yh, 973.8], [194.3, y0 + 6.0, 970.9]])
	c.append([193.0, F4, 969.3])
	for p: Array in c:
		ch.append(_w3(p))
	spx = VhLayout.ad_x(192.95)      # (the spine: admin.js)
	spz = PackedFloat64Array([VhLayout.ad_z(970.3), VhLayout.ad_z(974.3)])
	var A: Dictionary = VhLayout.STAIR_A
	sax = PackedFloat64Array([VhLayout.ad_x(A.x0) - 1.0, VhLayout.ad_x(A.x1) + 3.0, VhLayout.ad_z(A.z0) - 0.5, VhLayout.ad_z(A.z1) + 0.5])


static func _w3(p: Array) -> Array:
	return [VhLayout.ad_x(p[0]), VhLayout.ad_y(p[1], true), VhLayout.ad_z(p[2])]


func started(id: String) -> bool:
	return waves.has(id)


## a squad is done when every man in it has come through and is down
func done(id: String) -> bool:
	var w: Wave = waves.get(id)
	if w == null or w.pending != 0:
		return false
	for r: Robot in w.spawned:
		if not r.dead and not r.gone:
			return false
	return true


## start a squad: its door buzzes green, then each man comes through at his time
func start(id: String) -> void:
	var sq: Dictionary = SQUADS.get(id, {})
	if sq.is_empty() or waves.has(id):
		return
	var w := Wave.new()
	w.id = id
	w.t = -float(sq.buzz)
	for a: Dictionary in sq.list:
		var q := a.duplicate()
		q["done"] = false
		w.queue.append(q)
	w.pending = w.queue.size()
	waves[id] = w
	if sq.door != null:
		admin.unlock(sq.door, true)
		admin.hold(sq.door, 0.01)
		audio.tone(110.0, 0.6, 0.16, &"sawtooth")
		audio.thud(0.4)


func _arrive(w: Wave, a: Dictionary) -> void:
	var p := _w3(a.from)
	var path: Array = []
	for q: Array in a.path:
		path.append(_w3(q))
	var r := Game.spawn_enemy({"x": p[0], "y": float(p[1]) + 0.05, "z": p[2], "yaw": atan2(float(path[0][0]) - float(p[0]), float(path[0][2]) - float(p[2]))}, {"kind": "goon", "costume": a.costume, "gun": a.gun, "no_respawn": true})
	w.pending -= 1
	if r == null:
		return
	mine.append(r)
	w.spawned.append(r)
	var door: Variant = a.door if a.has("door") else SQUADS[w.id].door
	if door != null:
		admin.hold(door, 3.5)
	var A := Walk.new()
	A.r = r
	A.path = path
	A.speed = float(a.get("speed", 4.2))
	r.dev_passive = true
	walk.append(A)


## the walk out is over: he is in the fight
func _release(A: Walk, P: Player) -> void:
	var r := A.r
	r.dev_passive = false
	if P != null:
		r._know(P.x, P.z)
		r.seen_t = 0.0
		r.set_(&"alert")


func _update_walk(dt: float, P: Player) -> void:
	for i in range(walk.size() - 1, -1, -1):
		var A: Walk = walk[i]
		var r := A.r
		if r.dead or r.gone:
			walk.remove_at(i)
			continue
		r.dev_passive = true
		if A.wait > 0.0:
			A.wait -= dt
			continue
		var T: Array = A.path[A.i]
		var dx := float(T[0]) - r.x
		var dz := float(T[2]) - r.z
		var d := U.hyp(dx, dz)
		if d < 0.35:
			A.i += 1
			if A.i >= A.path.size():
				walk.remove_at(i)
				_release(A, P)
			continue
		var st := minf(d, A.speed * dt)
		var nx := r.x + dx / d * st
		var nz := r.z + dz / d * st
		if world.blocked(nx, nz, r.y, 2.0, r.r + 0.05, 0.42):      # (a mate in the way: he fights from here)
			A.block_t += dt
			if A.block_t > 0.8:
				walk.remove_at(i)
				_release(A, P)
				continue
		else:
			A.block_t = 0.0
			r.x = nx
			r.z = nz
		r.vx = dx / d * A.speed
		r.vz = dz / d * A.speed
		r.yaw = atan2(dx, dz)


## which leg of the way up p is on (CH[i] -> CH[i + 1]; heights count double, so the flight above never wins)
func _leg_of(x: float, y: float, z: float) -> int:
	var bi := 0
	var bd := INF
	for i in ch.size() - 1:
		var a: Array = ch[i]
		var b: Array = ch[i + 1]
		var ax: float = a[0]
		var ay: float = a[1]
		var az: float = a[2]
		var ux := float(b[0]) - ax
		var uy := 2.0 * (float(b[1]) - ay)
		var uz := float(b[2]) - az
		var l2 := ux * ux + uy * uy + uz * uz
		if l2 == 0.0:
			l2 = 1.0
		var k := clampf(((x - ax) * ux + 2.0 * (y - ay) * uy + (z - az) * uz) / l2, 0.0, 1.0)
		var e1 := ax + ux * k - x
		var e2 := 2.0 * ay + uy * k - 2.0 * y
		var e3 := az + uz * k - z
		var d := e1 * e1 + e2 * e2 + e3 * e3
		if d < bd:
			bd = d
			bi = i
	return bi


func _in_well(r: Robot) -> bool:      # (the shaft, and the step in front of its 1F door)
	return r.x > sax[0] and r.x < sax[1] and r.z > sax[2] and r.z < sax[3] and r.y > float(VhLayout.FLW[&"f1"]) - 0.5


func _sees(r: Robot, P: Player) -> bool:
	var dx := P.x - r.x
	var dy := P.y + 1.1 - (r.y + 1.5)
	var dz := P.z - r.z
	var d := sqrt(dx * dx + dy * dy + dz * dz)
	return d < 14.0 and world.ray_clear(r.x, r.y + 1.5, r.z, dx / d, dy / d, dz / d, d, 0.05) >= d - 0.6


func _in_walk(r: Robot) -> bool:
	for A: Walk in walk:
		if A.r == r:
			return true
	return false


func _hunt(dt: float, P: Player) -> void:
	var pin := P != null and not P.dead and admin.in_stair_a(Vector3(P.x, P.y, P.z))
	var pi_ := _leg_of(P.x, P.y, P.z) if pin else -1
	for r: Robot in mine:
		if r.dead or r.gone or _in_walk(r):
			continue
		if not pin or not _in_well(r):
			if hunt_on.get(r.id, false):
				hunt_on[r.id] = false
				r.dev_passive = false
			continue
		if _sees(r, P):
			lost[r.id] = 0.0
			if hunt_on.get(r.id, false) or r.state == &"idle" or r.state == &"return":
				hunt_on[r.id] = false
				r.dev_passive = false
				r._know(P.x, P.z)
				r.seen_t = 0.0
				r.set_(&"alert")
			continue
		lost[r.id] = float(lost.get(r.id, 0.0)) + dt
		if not hunt_on.get(r.id, false) and float(lost[r.id]) < 0.8:
			continue
		if not hunt_on.get(r.id, false):
			hunt_on[r.id] = true
			r.set_(&"idle")      # (idle: his own fight logic stops steering him back to a post he cannot reach)
		r.dev_passive = true
		var ei := _leg_of(r.x, r.y, r.z)
		var up := ei < pi_
		var end := ei + 1 if up else ei
		var e: Array = ch[end]
		var at := U.hyp(float(e[0]) - r.x, float(e[2]) - r.z) < 0.45      # (same leg: straight at him; else to the end of this leg his way, then on)
		var T: Array
		if ei == pi_ or (at and (end == pi_ if up else end - 1 == pi_)):
			T = [P.x, P.y, P.z]
		elif at:
			T = ch[end + 1 if up else end - 1]
		else:
			T = e
		var dx := float(T[0]) - r.x
		var dz := float(T[2]) - r.z
		var d := U.hyp(dx, dz)
		if d < 0.2:
			continue
		var sp := 3.8
		var st := minf(d, sp * dt)
		var mx := dx / d * st
		var mz := dz / d * st
		var rr := r.r + 0.05
		if not world.blocked(r.x + mx, r.z + mz, r.y, 2.0, rr, 0.42):
			r.x += mx
			r.z += mz
		elif not world.blocked(r.x + mx, r.z, r.y, 2.0, rr, 0.42):      # (slide along the spine's nose)
			r.x += mx
		elif not world.blocked(r.x, r.z + mz, r.y, 2.0, rr, 0.42):
			r.z += mz
		else:      # (caught on it: step off it)
			var ax := 0.0 if r.z < spz[0] or r.z > spz[1] else (signf(r.x - spx) if r.x != spx else 1.0)
			var az := -1.0 if r.z < spz[0] else (1.0 if r.z > spz[1] else 0.0)
			if not world.blocked(r.x + ax * st, r.z + az * st, r.y, 2.0, rr, 0.42):
				r.x += ax * st
				r.z += az * st
		r.vx = dx / d * sp
		r.vz = dz / d * sp
		r.yaw = atan2(dx, dz)


## checkpoint: nobody left, the stairwell's doors locked again
func reset() -> void:
	_clear()
	walk.clear()
	waves.clear()
	admin.unlock("saF1", false)
	admin.unlock("saF2", false)
	admin.unlock("saF3", false)
	admin.unlock("office", false)


func _clear() -> void:
	for r: Robot in mine:
		if not r.gone:
			Game.despawn_enemy(r)
	mine.clear()
	hunt_on.clear()
	lost.clear()


func update(dt: float, P: Player) -> void:
	for id: String in waves:
		var w: Wave = waves[id]
		w.t += dt
		for a: Dictionary in w.queue:
			if not a.done and w.t >= float(a.at):
				a.done = true
				_arrive(w, a)
		var sq: Dictionary = SQUADS[id]
		if sq.has("relock") and not w.relocked and w.pending == 0:
			var last := 0.0
			for a: Dictionary in sq.list:
				last = maxf(last, float(a.at))
			if w.t > last + float(sq.relock) + 2.5:      # (the last man through: locked again)
				w.relocked = true
				admin.unlock(sq.door, false)
				audio.thud(0.3)
	_update_walk(dt, P)
	_hunt(dt, P)
	# a man on a floor that is not drawn is not drawn either (the block shows one floor at a time); in Stair A, while the stairwell is drawn
	var F: Dictionary = admin.floors
	var bots: Dictionary = Game.fx.bot_by_id if Game.fx != null else {}
	for r: Robot in mine:
		if r.dead:
			continue
		var f: Node3D = F.get(admin.floor_at(r.y + 0.5))
		var seen := (f != null and f.visible) or (admin.in_stair_a(Vector3(r.x, r.y, r.z)) and (F[&"sa"] as Node3D).visible)
		var bv: Variant = bots.get(r.id)
		if bv != null:
			(bv.g as Node3D).visible = seen


func dispose() -> void:
	_clear()
	walk.clear()
