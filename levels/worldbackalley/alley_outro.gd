class_name AlleyOutro
extends Node
## BACK ALLEY ending cutscene (JS levels/worldbackalley/outro.js): the last gray drops, fade, and Prog staggers the final few metres to his building's stoop with a heap of dead grays behind him in the street. He looks up at the door, his knees go, he falls flat on his face in the puddle at the kerb and stays there. The camera cranes up and back over the pile in the lightning; one of the grays on top of it twitches. Fade out, then home to the hub.

const WALK := 0.75
const T0 := 0.8      # the scene is set up behind the fade
const TL := {"stop": T0 + 4.9, "look": T0 + 5.2, "kneel": T0 + 7.4, "fall": T0 + 9.7, "land": T0 + 10.15, "crane": T0 + 15.0, "twitch": T0 + 19.0, "fade": T0 + 22.6, "end": T0 + 24.2}
const FACE_SIDE := -1.0      # which side of him the face-in-the-puddle shot sits (+1 / -1)

var on := false
var t := 0.0
var camera: View.Shot:
	get:
		return cam.camera
var cam := AlleyCine.Cam.new()
var subs: AlleyCine.Subs = null
var skip_: AlleyCine.Skip = null
var st := AlleyCine.ProgState.new()
var _level: Node3D
var _weather: Storm
var _props: AlleyProps
var _puddle: Dictionary
var _pile: Dictionary
var _on_done: Callable
var _ei := 0
var _ev: Array = []
var _root: Node3D = null
var _corpses: Array[GrayAlienNpc] = []
var _twitcher: GrayAlienNpc = null
var an: Animator = null
var P: Player = null
var _from: Variant = null
var _pose: Variant = null
var _start_at: Vector2
var _stop_at: Vector2


func _init(level: Node3D, weather: Storm, props: AlleyProps, puddle: Dictionary, pile: Dictionary, on_done: Callable) -> void:
	name = "AlleyOutro"
	_level = level
	_weather = weather
	_props = props
	_puddle = puddle
	_pile = pile
	_on_done = on_done
	_start_at = Vector2(float(puddle["x"]) - 1.0, float(puddle["z"]) - 4.5)
	_stop_at = Vector2(float(puddle["x"]) - 0.25, float(puddle["z"]) - 1.3)      # he stops short so his face lands in the middle of it


static func _gy(x: float) -> float:
	return AlleyIntro._gy(x)


func _strike(o: Dictionary) -> void:
	if _weather != null:
		_weather.strike(Game.camera.global_position, o)


# ---- the pile: dead grays thrown in a heap, settled once, then left still ----
func _build_pile() -> void:
	_root = Node3D.new()
	_root.name = "Back alley pile"
	add_child(_root)
	var sd := [913]      # (in an array: a lambda captures a plain int by value)
	var R := func() -> float:
		sd[0] = (int(sd[0]) * 1664525 + 1013904223) & 0xffffffff
		return float(sd[0]) / 4294967296.0
	var gpy := _gy(_pile["x"])
	for layer: Array in [[9, 2.9, 0.0], [7, 2.1, 0.42], [5, 1.4, 0.82], [3, 0.8, 1.2], [1, 0.0, 1.55]]:
		var n: int = layer[0]
		var r: float = layer[1]
		var y: float = layer[2]
		for i in n:
			var npc := GrayAlienNpc.new({"pose": &"idle"})
			var a: float = (float(i) / n) * TAU + float(R.call()) * 0.6
			var rad: float = r * (0.75 + float(R.call()) * 0.35)
			npc.R.hit_x = float(R.call()) - 0.5
			npc.R.hit_z = float(R.call()) - 0.5
			_root.add_child(npc)
			var yaw: float = float(R.call()) * TAU
			npc.set_pose(&"dead")
			# (JS: settled at the origin, then its root moved and turned. Here the place comes first and the turn is the view's tilt.)
			var rx: float = (float(R.call()) - 0.5) * 0.5 * (1.0 if y > 0.0 else 0.2)
			var ry: float = float(R.call()) * TAU
			var rz: float = (float(R.call()) - 0.5) * 0.5 * (1.0 if y > 0.0 else 0.2)
			npc.place(float(_pile["x"]) + cos(a) * rad, gpy + y, float(_pile["z"]) + sin(a) * rad * 0.8, yaw)
			npc.view.tilt = Basis.from_euler(Vector3(rx, ry, rz), EULER_ORDER_XYZ)
			for k in 70:      # topple and settle, then never touched again
				npc.update(k * 0.05, 0.05)
			if y > 0.0 and npc.view.puddle != null:
				npc.view.puddle.visible = false
			_corpses.append(npc)
	_twitcher = _corpses[_corpses.size() - 1]


func _head_pos() -> Vector3:
	if an != null and an.by_key.has(&"head"):
		return an.bone_world_pos(an.by_key[&"head"].bone)
	return Vector3(P.x, P.y + 1.6, P.z)


# ---- where Prog is at time t ----
func _prog_at(tm: float) -> Dictionary:
	var yaw0 := atan2(_stop_at.x - _start_at.x, _stop_at.y - _start_at.y)
	var d := _start_at.distance_to(_stop_at)
	var w := minf(maxf(0.0, tm - T0) * WALK, d)
	var sway := sin(tm * 2.2) * 0.12 * (1.0 if tm < float(TL["stop"]) else 0.4)      # a drunk-tired weave
	var o := {"x": _start_at.x + sin(yaw0) * w + cos(yaw0) * sway, "z": _start_at.y + cos(yaw0) * w - sin(yaw0) * sway, "yaw": yaw0 + sin(tm * 1.1) * 0.08, "hip": 0.95, "pitch": 0.0, "mode": &"walk" if tm < float(TL["stop"]) else &"stand", "u": 0.0, "walking": tm > T0 and tm < float(TL["stop"])}
	var yw: float = o["yaw"]
	if tm >= float(TL["kneel"]):
		var k := Cutscene.ease_((tm - float(TL["kneel"])) / 0.55)
		o["mode"] = &"kneel"
		o["u"] = k
		o["hip"] = lerpf(0.95, 0.58, k)
		o["pitch"] = 0.12 * k
	if tm >= float(TL["fall"]):
		var k := minf(1.0, (tm - float(TL["fall"])) / (float(TL["land"]) - float(TL["fall"])))
		var kk := k * k
		o["mode"] = &"fall"
		o["u"] = kk
		o["hip"] = lerpf(0.58, 0.28, kk)
		o["pitch"] = lerpf(0.12, 1.52, kk)
		o["x"] += sin(yw) * 0.55 * kk
		o["z"] += cos(yw) * 0.55 * kk
	if tm >= float(TL["land"]):
		o["mode"] = &"lie"
		o["u"] = 1.0
		o["hip"] = 0.28 + sin(tm * 1.6) * 0.006
		o["pitch"] = 1.52
		o["x"] += sin(yw) * 0.55
		o["z"] += cos(yw) * 0.55
	return o


func _E(tm: float, fn: Callable) -> void:
	_ev.append({"t": tm, "fn": fn, "n": _ev.size()})


func _build_events() -> void:
	_ev = []
	_E(T0 - 0.05, func() -> void:
		if _root == null:
			_build_pile()
		_root.visible = true
		_place(T0)
		cam.reset()
		Game.ui.set_fade(false))
	_E(T0 + 0.6, _strike.bind({"close": true}))
	var tw: float = TL["twitch"]
	_E(tw + 0.7, func() -> void:
		subs.say({"name": "GRAY", "color": "#c7a4ff", "pitch": 0.6, "at": func() -> Vector3: return _twitcher.mouth_world()}, "...ow."))
	_E(TL["look"], AlleyCine.snd_breath)
	_E(float(TL["kneel"]) + 0.5, AlleyCine.snd_thud)
	var land: float = TL["land"]
	_E(land, func() -> void:
		var p := _prog_at(land)
		var x: float = float(p["x"]) + sin(float(p["yaw"])) * 0.6
		var z: float = float(p["z"]) + cos(float(p["yaw"])) * 0.6
		AlleyCine.snd_splash_big()
		if _props != null:
			_props.splash(x, z, 1.4)
		if Game.fx != null:
			Game.fx.sparks(Vector3(x, 0.1, z), 26, 3.2, Vector3(0.0, 1.6, 0.0), 0x9cb8d8)
		cam.kick(0.5)
		subs.clear())
	_E(land + 1.4, AlleyCine.snd_bubbles)
	_E(float(TL["crane"]) + 2.0, _strike.bind({"overhead": true}))
	_E(tw, AlleyCine.snd_groan)
	_E(TL["fade"], func() -> void:
		subs.clear()
		Game.ui.set_fade(true))
	_E(TL["end"], finish)
	_ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"] if a["t"] != b["t"] else a["n"] < b["n"])


# ---- camera ----
func _camera(dt: float, tm: float) -> void:
	if tm < T0:
		var rig := Game.rig
		if _from == null and rig != null:
			_from = {"pos": rig.pos, "look": rig.look}
		if _from != null:
			cam.shot(dt, &"pre", _from["pos"], _from["look"], 1.0, true)
		return
	var p := _prog_at(tm)
	var px: float = p["x"]
	var pz: float = p["z"]
	var pdx: float = _puddle["x"]
	var pdz: float = _puddle["z"]
	var plx: float = _pile["x"]
	var plz: float = _pile["z"]
	if tm < T0 + 4.2:      # low, from the stoop: him coming, the heap behind him
		cam.shot(dt, &"A", Vector3(pdx + 0.9, 0.55, pdz + 2.6), Vector3(px, 1.25, pz), 3.0, true)
	elif tm < float(TL["kneel"]):      # side: he stops, looks up at the door
		cam.shot(dt, &"B", Vector3(px - 2.6, 1.35, pz + 1.2), Vector3(px + 0.4, 1.45, pz + 0.3), 3.0, true)
	elif tm < float(TL["land"]) + 0.4:      # low side: knees, then down
		cam.shot(dt, &"C", Vector3(px - 2.2, 0.75, pz + 1.6), Vector3(px, 0.75, pz + 0.4), 4.0, true)
	elif tm < float(TL["crane"]):      # down in the puddle, on the side his face is turned to
		var h := _head_pos()
		var fx_ := sin(float(p["yaw"]))
		var fz := cos(float(p["yaw"]))
		cam.shot(dt, &"D", Vector3(h.x + fx_ * 0.45 + fz * FACE_SIDE * 1.4, 0.26, h.z + fz * 0.45 - fx_ * FACE_SIDE * 1.4), Vector3(h.x, 0.1, h.z), 6.0, true)
	else:      # crane up and back over the pile: ends with the heap in front, him in the puddle beyond it
		var u := Cutscene.ease_((tm - float(TL["crane"])) / (float(TL["fade"]) - float(TL["crane"]) + 1.2))
		cam.shot(dt, &"E", Vector3(lerpf(px - 1.4, plx - 3.2, u), lerpf(1.0, 6.2, u), lerpf(pz + 0.6, plz - 7.0, u)), Vector3(lerpf(px, plx + 0.3, u), lerpf(0.4, 0.9, u), lerpf(pz, plz + 3.0, u)), 2.2, true)


func _place(tm: float) -> void:
	var o := _prog_at(tm)
	_pose = o
	P.invuln = maxf(P.invuln, 1.0)
	P.dead = false
	P.grounded = true
	P.vy = 0.0
	P.x = o["x"]
	P.z = o["z"]
	P.y = _gy(o["x"])
	P.yaw = o["yaw"]
	P.vx = sin(float(o["yaw"])) * WALK if o["walking"] else 0.0
	P.vz = cos(float(o["yaw"])) * WALK if o["walking"] else 0.0


func start(p: Player) -> bool:
	if on:
		return false
	P = p
	if subs == null:
		subs = AlleyCine.Subs.new()
		skip_ = AlleyCine.Skip.new(skip)
	on = true
	t = 0.0
	_ei = 0
	_from = null
	_pose = null
	_build_events()
	cam.reset()
	if Game.combat != null:
		Game.combat.equip(-1)
	Game.hud.set_suppressed(true)
	skip_.start()
	Game.ui.set_fade(true)
	return true


func skip() -> void:
	if not on or t < T0:
		return
	var to: float = float(TL["fade"]) - 0.1
	if t >= to:
		return
	subs.clear()
	t = to
	while _ei < _ev.size() and float(_ev[_ei]["t"]) < to:
		_ei += 1


## aborted = a checkpoint was loaded mid-scene: clean up, lift the fade, no trip home
func finish(aborted: bool = false) -> void:
	if not on:
		return
	on = false
	subs.clear()
	skip_.stop()
	Game.hud.set_suppressed(false)
	Inp.guard_arm()
	if an != null:
		an.pose_hook = Callable()
		an = null
	if _twitcher != null:
		_twitcher.view.post_hook = Callable()
	if aborted:
		Game.ui.set_fade(false)
		AlleyCine.arm_rifle()
		if _root != null:
			_root.visible = false
			for c: GrayAlienNpc in _corpses:
				c.set_shown(false)
	elif _on_done.is_valid():
		_on_done.call()


func update(dt: float, p: Player) -> void:
	if subs != null:
		subs.tick(dt if on else get_process_delta_time())
	if skip_ != null:
		skip_.poll()
	if not on:
		return
	P = p if p != null else P
	if P == null:
		return
	t += dt
	var tm := t
	while _ei < _ev.size() and float(_ev[_ei]["t"]) <= tm:
		var e: Dictionary = _ev[_ei]
		_ei += 1
		(e["fn"] as Callable).call()
		if not on:
			return
	if tm >= T0:
		_place(tm)
	else:
		P.invuln = maxf(P.invuln, 1.0)
		P.vx = 0.0
		P.vz = 0.0
	st.t = tm
	st.slump = 1.0 if tm < float(TL["land"]) else 0.0
	var mode: StringName = _pose["mode"] if _pose != null else &""
	st.mode = mode if mode != &"walk" and mode != &"stand" else &""
	st.u = float(_pose["u"]) if _pose != null else 0.0
	var lk: float = TL["look"]
	var kn: float = TL["kneel"]
	if tm > lk and tm < kn:      # his head comes up to the door for a moment
		st.slump = 1.0 - 0.7 * AlleyCine.win(tm, lk, lk + 0.8) * (1.0 - AlleyCine.win(tm, kn - 0.6, kn))
	var tw: float = TL["twitch"]
	if _twitcher != null and tm > tw and tm < tw + 1.6:      # the one on top is not quite gone: a jerk of the head, an arm lifts, flops back
		var k := sin(minf(1.0, (tm - tw) / 1.6) * PI)
		var v := _twitcher.view
		v.post_hook = func() -> void:
			var eh := v.pose.rot[v.j_head].get_euler(EULER_ORDER_XYZ)
			v.pose.euler(v.j_head, 0.4 * k * sin(tm * 25.0) * 0.3 + 0.25 * k, eh.y, eh.z)
			var es := v.pose.rot[v.j_sh_r].get_euler(EULER_ORDER_XYZ)
			v.pose.euler(v.j_sh_r, -1.2 * k, es.y, es.z)
		_twitcher.update(tm, 0.0)
	_camera(dt, tm)


func pose_player(a: Animator) -> void:
	if not on:
		return
	if an != a:
		an = a
		a.pose_hook = st.hook
	if _pose != null and t >= T0:
		var m: StringName = _pose["mode"]
		if m == &"kneel" or m == &"fall" or m == &"lie":
			AlleyCine.place_actor(a, _pose["x"], _gy(_pose["x"]), _pose["z"], _pose["yaw"], _pose["hip"], _pose["pitch"])


func seek(s: float) -> void:
	if not on:
		return
	t = s
	while _ei < _ev.size() and float(_ev[_ei]["t"]) < s:
		var e: Dictionary = _ev[_ei]
		_ei += 1
		if float(e["t"]) < T0:
			(e["fn"] as Callable).call()
	cam.reset()


func _exit_tree() -> void:
	if an != null:
		an.pose_hook = Callable()
		an = null
	if on:
		on = false
		Game.hud.set_suppressed(false)
	if subs != null:
		subs.dispose()
	if skip_ != null:
		skip_.dispose()
