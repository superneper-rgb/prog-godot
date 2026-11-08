class_name OmDockhand
extends RefCounted
## OMNISPHERE: the pad dockhand (JS dockhand.js). A FOINT security goon on a smoke break at Receiving Pad 3, his back to the landing ring. The jet roar turns him round; when PROG touches down he jumps out of his skin and drops the cigarette, runs for the alarm box on its post by the west railing with his arms going, slaps it (the plant alarm, the PA), then remembers the pistol and fights. The box and its post are exported art.

const POST := Vector2(-8.9, -1.6)
const SPOT := {"x": -5.4, "y": 6.0, "z": -3.9, "yaw": -1.85}

var audio: OmAudio
var alarm: Callable
var ALARM_AT: Array
var box_pos := Vector3(POST.x, 7.25, POST.y)
var cig: Node3D
var ember: MeshInstance3D
var puffs: OmPuffs
var R: Robot = null
var ph := "off"
var t := 0.0
var fall_on := false
var fall_v := Vector3.ZERO
var fall_w := Vector3.ZERO
var fall_t := 0.0


static func _rr(a: float, c: float) -> float:
	return a + randf() * (c - a)


func _init(lv: ExportedLevel, p_audio: OmAudio, p_alarm: Callable) -> void:
	audio = p_audio
	alarm = p_alarm
	var toc := Vector2(-POST.x, -POST.y).normalized()
	ALARM_AT = [POST.x + toc.x * .9, POST.y + toc.y * .9]
	var root := Node3D.new()
	root.name = "OmDockhand"
	lv.add_child(root)
	# ---- the cigarette (in his left hand: a world-space prop that follows the hand bone) and the smoke off it
	cig = Node3D.new()
	root.add_child(cig)
	cig.visible = false
	var pm := MsKit.cyl(.009, .009, .085, 6)
	MsKit.part(cig, pm, MsKit.std(0xece6da, .8), Vector3(0, .048, 0), false)
	MsKit.part(cig, MsKit.cyl(.0095, .0095, .025, 6), MsKit.std(0xc7864a, .8), Vector3.ZERO, false)
	ember = MsKit.sprite8(cig, 0xff6a20, 1.0, .06)
	ember.position.y = .095
	puffs = OmPuffs.new(root, 120, false)


func _despawn() -> void:
	if R != null:
		Game.despawn_enemy(R)
	R = null


## he is on the pad. alerted: skip the smoke break (a checkpoint after the landing)
func spawn(alerted: bool = false) -> Robot:
	_despawn()
	fall_on = false
	var r: Robot = Game.spawn_enemy({"x": SPOT.x, "y": SPOT.y, "z": SPOT.z, "yaw": SPOT.yaw}, {"kind": "goon", "costume": "security", "gun": "pistol", "alarm": ALARM_AT, "no_respawn": true})
	if r == null:
		return null
	R = r
	r.no_respawn = true
	t = 0.0
	var E: Variant = Game.combat.enemies
	if E != null:
		E.on_goon_alarm = _raised
	if alerted:
		ph = "run"
		_panic(r)
	else:
		ph = "break"
		r.dev_passive = true
		r.set(&"on_break", true)
		r.set(&"drag", 0.0)
		cig.visible = true
	return r


func _panic(r: Robot) -> void:      # the panic run (arms going) to the box
	var P: Player = Game.player
	r.dev_passive = false
	r.set(&"on_break", false)
	r.set(&"drag", 0.0)
	r.set(&"costume", "labcoat")
	r.known = Robot.Known.at(P.x, P.z) if P != null else null
	r.seen_t = 0.0
	r.alert_why = "sight"
	r.set_(&"alert")


## the alarm box got slapped: the plant knows. He has a gun, it occurs to him
func _raised(who: Variant) -> void:
	if who != R:
		return
	alarm.call(10.0)
	audio.play_at("alarmShort", box_pos)
	audio.pa("pad")
	who.set(&"costume", "security")
	who.set(&"pressing", false)
	who.set(&"alarm_t", 0.0)
	who.set(&"panic", 0.0)
	ph = "fight"
	who.bark_set = null
	who.set_(&"alert")


## the jet roar overhead: he turns round to look
func notice() -> void:
	if ph == "break":
		ph = "look"


## PROG is down: the shock (a hop back, the cigarette goes), then the run
func landed() -> void:
	var r := R
	if r == null or r.dead or (ph != "break" and ph != "look"):
		return
	ph = "shock"
	t = 0.0
	r.set(&"drag", 0.0)
	r.bark_set = {"alert": ["That is not a scheduled arrival.", "Nope. No. Absolutely not."]}
	Game.combat.enemies.barks.say(r, "alert")
	fall_on = true
	fall_t = 0.0
	fall_v = Vector3(_rr(-1, 1), 2.4, _rr(-1, 1))
	fall_w = Vector3(_rr(-9, 9), _rr(-9, 9), _rr(-9, 9))


var dead: bool:
	get:
		return R != null and R.dead


func reset() -> void:
	_despawn()
	ph = "off"
	cig.visible = false
	fall_on = false
	puffs.clear()


func _bone(view: Variant, n: StringName) -> Variant:
	if view == null or not view.B.i.has(n):
		return null
	return view.mw * (view.mp(view.B.i[n]) * view.g.scale.x)


func update(dt: float, P: Player) -> void:
	puffs.update(dt)
	var r := R
	if r == null:
		return
	t += dt
	var view: Variant = Game.fx.bot_by_id.get(r.id) if Game.fx != null else null
	if ph == "break" or ph == "look":
		# a drag every six seconds, the exhale after it
		var c := fmod(t + 4.0, 6.0)
		r.set(&"drag", 1.0 if c < 1.4 else 0.0)
		if c > 1.6 and c < 2.6 and randf() < dt * 12.0:
			var m: Variant = _bone(view, &"head")
			if m != null:
				puffs.emit(m.x + sin(r.yaw) * .17, m.y, m.z + cos(r.yaw) * .17, {"vx": sin(r.yaw) * .5, "vy": .25, "vz": cos(r.yaw) * .5, "size": .12, "grow": 5.0, "life": _rr(1.4, 2.2), "col": 0xa8b0b8, "alpha": .35})
		if ph == "look" and P != null:
			var want := atan2(P.x - r.x, P.z - r.z)
			var d := atan2(sin(want - r.yaw), cos(want - r.yaw))
			r.yaw += clampf(d, -dt * 2.5, dt * 2.5)
			r.set(&"drag", 0.0)
	if ph == "shock":      # a startled hop back from the ring, then he runs for it
		var away := atan2(r.x, r.z)
		var k := 1.0 if t < .25 else 0.0
		r.x += sin(away) * k * dt * 2.4
		r.z += cos(away) * k * dt * 2.4
		r.y = float(SPOT.y) + maxf(0.0, sin(minf(1.0, t / .35) * PI)) * .28
		if t > .7:
			r.y = SPOT.y
			ph = "run"
			_panic(r)
	# the cigarette: in his hand, or bouncing across the deck
	if fall_on:
		fall_t += dt
		fall_v.y -= 9.8 * dt
		cig.position += fall_v * dt
		cig.rotation.x += fall_w.x * dt
		cig.rotation.z += fall_w.z * dt
		if cig.position.y < 6.02:
			cig.position.y = 6.02
			fall_v.y = absf(fall_v.y) * .3
			fall_v.x *= .5
			fall_v.z *= .5
			fall_w *= .4
		MsKit.opa(ember, maxf(0.0, 1.0 - fall_t / 9.0))
		if randf() < dt * 3.0 and fall_t < 8.0:
			puffs.emit(cig.position.x, cig.position.y + .1, cig.position.z, {"vy": .3, "size": .05, "grow": 4.0, "life": 1.6, "col": 0x9aa4b0, "alpha": .2})
	elif cig.visible:
		var h: Variant = _bone(view, &"hand.L")
		if h != null:
			cig.position = h
			MsKit.opa(ember, .7 + .3 * sin(t * 9.0) * (1.6 if r.get(&"drag") != 0.0 else .4))
			if randf() < dt * 4.0:
				var tp := ember.global_position
				puffs.emit(tp.x, tp.y, tp.z, {"vx": .1, "vy": .3, "size": .04, "grow": 5.0, "life": _rr(1, 1.6), "col": 0x9aa4b0, "alpha": .22})
