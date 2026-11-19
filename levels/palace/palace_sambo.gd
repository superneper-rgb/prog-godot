class_name PalaceSambo
extends Node3D
## Sambo Fenrir on the Pervert Palace site (levels/palace/palace_level.gd): his body (npcs/sambo/sambo_body.gd), the route he runs up the site ahead of Prog, his voice, and the crew taking shots
## at him too (user: "the workers freak out and start chasing and attacking both of you"). The crew's AI only fights the player, so their shots at Sambo are scripted here: now and then a
## crewman near him who can see him puts a nail past him or lobs a brick at him, and he yelps.
## The route is a list of legs: run to a point (y follows the leg in a straight line: every leg is on one floor or one stair flight), hop to a point (an arc), or hold until Prog is near
## (`wait`), a line said as a leg starts (`say`). The director sets the legs for each stage; a cutscene can take him over (`held`: he only poses).

const RUN := 3.6
const WALK := 1.0
const HOP_H := 1.1
const HOP_S := 0.75             # seconds a hop takes

var body: SamboBody
var legs: Array[Dictionary] = []
var leg := -1
var _from := Vector3.ZERO
var _u := 0.0
var _wait := 0.0
var held := false               # a cutscene has him
var yaw := 0.0
var pos := Vector3.ZERO
var waiting := false            # holding for Prog at the end of a leg
var on_arrive := Callable()     # called with the leg's id when he finishes a leg that has one
var _voice: Sfx.SpatialVoice = null
var _said := {}                 # line id -> times said (so the climb's lines go round)
var _shot_t := 5.0
var _nag_t := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Sambo"
	_rng.seed = 77
	body = SamboBody.new()
	add_child(body)


func place(p: Vector3, y_: float) -> void:
	pos = p
	yaw = y_
	_apply()


func _apply() -> void:
	body.global_position = pos
	body.rotation.y = yaw


## A new route: [{to: Vector3, hop: bool, run: bool, wait: float (hold for Prog within this many metres), say: line id, id: name}]
func go(route: Array) -> void:
	legs.assign(route)
	leg = -1
	_next_leg()


func done() -> bool:
	return leg >= legs.size()


func _next_leg() -> void:
	leg += 1
	_u = 0.0
	_from = pos
	waiting = false
	if leg >= legs.size():
		return
	var L: Dictionary = legs[leg]
	if L.has("say"):
		say(String(L.say))


# ---------------------------------------------------------------------------------------------- the frame

func tick(dt: float, P: Player) -> void:
	_t += dt
	if not held and leg >= 0 and leg < legs.size():
		var L: Dictionary = legs[leg]
		var to: Vector3 = L.to
		var d := to - _from
		var flat := Vector2(d.x, d.z).length()
		if L.get("hop", false):
			_u += dt / HOP_S
			var u := minf(_u, 1.0)
			pos = _from.lerp(to, u) + Vector3(0.0, HOP_H * 4.0 * u * (1.0 - u) + maxf(0.0, d.y) * 0.0, 0.0)
			body.speed = RUN
			body.gesture = &"fists" if u < 0.85 else &""
			if flat > 0.05:
				yaw = atan2(d.x, d.z)
			if _u >= 1.0:
				pos = to
				body.gesture = &""
				_arrive(L, P)
		else:
			var sp: float = RUN if L.get("run", true) else WALK
			var step := sp * dt / maxf(0.01, d.length())
			_u = minf(1.0, _u + step)
			pos = _from.lerp(to, _u)
			body.speed = sp if _u < 1.0 else 0.0
			if flat > 0.05:
				yaw = lerp_angle(yaw, atan2(d.x, d.z), 1.0 - exp(-dt * 10.0))
			if _u >= 1.0:
				_arrive(L, P)
	elif not held:
		body.speed = 0.0
	if waiting and P != null:      # hold for Prog; nag him now and then; face him
		_nag_t -= dt
		var to_p := Vector2(P.x - pos.x, P.z - pos.z)
		yaw = lerp_angle(yaw, atan2(to_p.x, to_p.y), 1.0 - exp(-dt * 4.0))
		body.speed = 0.0
		if _nag_t <= 0.0:
			_nag_t = _rng.randf_range(9.0, 14.0)
			if to_p.length() > 6.0:
				say_one(["s_climb_12", "s_climb_07", "s_climb_09"])
		var L: Dictionary = legs[leg]
		if to_p.length() < float(L.get("wait", 4.0)) and absf(P.y - pos.y) < 3.0:
			_next_leg()
	_apply()
	body.update(dt)


func _arrive(L: Dictionary, _P: Player) -> void:
	if L.has("id") and on_arrive.is_valid():
		on_arrive.call(String(L.id))
	if float(L.get("wait", 0.0)) > 0.0:
		waiting = true
		_nag_t = _rng.randf_range(4.0, 7.0)
	else:
		_next_leg()


# ---------------------------------------------------------------------------------------------- voice

## Say a line (assets/sfx/sambo/<id>.wav) from where he is, with its subtitle; his lid flaps while it plays. A line of Prog's (p_*) comes from Prog, under his name.
func say(id: String, gain: float = 1.4) -> float:
	var st := SamboLines.clip(id)
	if st == null:
		return 0.0
	var prog := SamboLines.who(id) == "PROG"
	if not prog and _voice != null and _voice.player != null and _voice.player.playing:
		_voice.player.stop()
	var P := Game.player
	var m := Vector3(P.x, P.y + 1.6, P.z) if prog and P != null else body.mouth_world()
	var v: Sfx.SpatialVoice = Game.sfx.clip_at(st, m.x, m.y, m.z, {"range": 60.0, "ref": 6.0, "gain": gain, "voice": true})
	var dur := st.get_length()
	if Game.hud != null and P != null and m.distance_to(Vector3(P.x, P.y, P.z)) < 45.0:
		Game.hud.subtitle({"name": Dialogue.player_name() if prog else "SAMBO", "text": SamboLines.text(id), "dur": dur})
	if prog:
		return dur
	_voice = v
	body.talking = true
	_said[id] = int(_said.get(id, 0)) + 1
	get_tree().create_timer(dur, false).timeout.connect(func() -> void:
		if is_instance_valid(body):
			body.talking = false)
	return dur


## One of these, the least said first
func say_one(ids: Array) -> float:
	var best := ""
	var n := 1 << 20
	for id: String in ids:
		var k := int(_said.get(id, 0))
		if k < n:
			n = k
			best = id
	return say(best) if best != "" else 0.0


func talking() -> bool:
	return _voice != null and _voice.player != null and _voice.player.playing


# ---------------------------------------------------------------------------------------------- the crew's shots at him

## Every few seconds a crewman who is near him and sees him has a go: a nail past him, or a brick (he yelps; a brick that lands makes him say so)
func crew_shots(dt: float, active: bool) -> void:
	_shot_t -= dt
	if not active or _shot_t > 0.0 or held or Game.enemies == null:
		return
	_shot_t = _rng.randf_range(3.5, 7.0)
	var at := pos + Vector3(0.0, 1.2, 0.0)
	var best: Robot = null
	var bd := 22.0
	for r: Robot in Game.enemies.robots:
		if r.dead or not (r is FointGoon) or r.state == &"idle":
			continue
		var d := Vector3(r.x - at.x, r.y + 1.2 - at.y, r.z - at.z).length()
		if d < bd and Game.world.ray_clear(r.x, r.y + 1.3, r.z, at.x - r.x, at.y - r.y - 1.3, at.z - r.z, d, 0.05) >= d - 0.5:
			bd = d
			best = r
	if best == null:
		return
	var g := best as FointGoon
	var from := Vector3(g.x, g.y + 1.3, g.z)
	if g.costume == "crew_hod":      # a brick, high, onto him
		var T := clampf(bd / 11.0, 0.6, 1.6)
		var vy := (at.y - from.y) / T + 0.5 * FointGoon.ACID_G * T
		var A: FointGoon.AcidState = Game.enemies.goon_acid
		if A != null:
			A.globs.append({"x": from.x, "y": from.y, "z": from.z, "vx": (at.x - from.x) / T, "vy": vy, "vz": (at.z - from.z) / T, "life": 0.0, "owner": g.id, "brick": true})
			get_tree().create_timer(T, false).timeout.connect(func() -> void: _hit("brick"))
	else:      # a nail past him
		var miss := Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.3, 0.6), _rng.randf_range(-0.5, 0.5))
		var dir := (at + miss - from).normalized()
		Game.enemies.fire_from(g.id, from.x, from.y, from.z, dir.x, dir.y, dir.z, {"kind": "bolt", "speed": 32.0, "dmg": 0.0, "r": 0.08})
		if _rng.randf() < 0.35:
			get_tree().create_timer(bd / 32.0, false).timeout.connect(func() -> void: _hit("nail"))


func _hit(kind: String) -> void:
	if held or not is_inside_tree():
		return
	body.gesture = &"fists"
	get_tree().create_timer(0.7, false).timeout.connect(func() -> void:
		if is_instance_valid(body) and body.gesture == &"fists":
			body.gesture = &"")
	if talking():
		return
	if kind == "brick" and int(_said.get("s_climb_05", 0)) < 2:
		say("s_climb_05")
	elif _rng.randf() < 0.5:
		say_one(["s_climb_03", "s_climb_10", "s_climb_09"])
