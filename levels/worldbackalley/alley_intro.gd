class_name AlleyIntro
extends Node
## BACK ALLEY intro cutscene (JS levels/worldbackalley/intro.js): Prog trudges home up the street in the storm, soaked and hunched; three grays smoking under the social club's awning heckle him ("no green lovers"), he keeps walking, they get offended, one pops a warning shot past his head, he stops, turns, draws, and grays rise up from behind every dumpster and car around him. Then the fight starts where they stand (the level spawns the real enemies at the same spots).

const WALK := 0.82      # m/s: a dead man's shuffle
const TL := {"shot": 28.4, "slowEnd": 28.8, "turn": 36.0, "draw": 37.8, "fellas": 40.0, "snap": 44.0, "blend": 44.6, "end": 46.4}
const SHOTS: Array[float] = [0.0, 5.5, 9.4, 16.0, 19.2, 26.4, 28.1, 29.8, 31.4, 36.0, 40.0, 44.6]   # start times of shots A..L
const SAL := {"name": "SAL", "color": "#c7a4ff", "pitch": 0.78}
const VIN := {"name": "VINNIE", "color": "#b9b0ff", "pitch": 1.05}
const DOM := {"name": "DOM", "color": "#d8b4e8", "pitch": 0.92}
const LINES := [
	[6.5, "SAL", "Ayy. Ayy! Look what the storm dragged in."],
	[9.6, "VINNIE", "Hey pal! This side of town's got a dress code. No green lovers."],
	[13.0, "SAL", "That's you. You're the green lover. We can smell it on you."],
	[19.4, "DOM", "Yo. He's ignoring us. Sal. Sal, he's IGNORING us."],
	[22.2, "SAL", "HEY! SWAMP-HUGGER! I'm talkin' to you!"],
	[24.4, "VINNIE", "That's so disrespectful. I'm literally shaking right now."],
	[26.8, "SAL", "Okay. Okay. Warning shot."],
	[31.6, "DOM", "Ehh... that was kinda close, Sal."],
	[33.4, "SAL", "It's a WARNING shot, Dom! It's supposed to be close! That's the warning!"],
	[40.1, "SAL", "FELLAS!"],
	[42.5, "RISER", "SURPRISE, SWAMP-HUGGER!"],      # the loudest of the ones that popped up
]

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
var _club_at: Dictionary
var _ambush: Array
var _path: Dictionary
var _on_done: Callable
var _ei := 0
var _ev: Array = []
var _root: Node3D = null
var _npcs: Array[Dictionary] = []
var _cigs: Array = []
var _bolts: AlleyCine.Bolts = null
var _who := {}
var _club: Array[Dictionary] = []
var an: Animator = null
var P: Player = null
var _rig_in := false
var _slow := 0.0
var _after: Array = []


## ambush: [{kind, x, z}]. club: { x, z }. path: { x, z0, stop }.
func _init(level: Node3D, weather: Storm, club: Dictionary, ambush: Array, path: Dictionary, on_done: Callable) -> void:
	name = "AlleyIntro"
	_level = level
	_weather = weather
	_club_at = club
	_ambush = ambush
	_path = path
	_on_done = on_done


static func _gy(x: float) -> float:
	return 0.0 if absf(x) <= 4.2 else (0.15 if absf(x) <= 7.5 else 0.0)


func _unslow() -> void:
	if _slow > 0.0:
		Game.time_scale = _slow
		_slow = 0.0


func _strike(o: Dictionary) -> void:
	if _weather != null:
		_weather.strike(Game.camera.global_position, o)


# ---- cast ----
func _build() -> void:
	_root = Node3D.new()
	_root.name = "Back alley intro"
	add_child(_root)
	_bolts = AlleyCine.Bolts.new(_root)
	var i := 0
	for a: Dictionary in _ambush:
		var kind: String = a["kind"]
		var n := GrayAlienNpc.new({"pose": &"idle" if kind == "club" else &"aim"})
		var y := _gy(a["x"])
		var ax: float = float(_club_at["x"]) + 0.15 if kind == "door" else float(a["x"])
		var az: float = _club_at["z"] if kind == "door" else float(a["z"])
		_root.add_child(n)
		n.place(ax, y - 1.35 if kind == "rise" else y, az, PI / 2.0 + (i - 1) * 0.35 if kind == "club" else atan2(float(_path["x"]) - float(a["x"]), float(_path["stop"]) - float(a["z"])))
		n.set_shown(kind == "club")
		var o := {"n": n, "a": a, "y": y, "risen": 0.0 if kind == "rise" else 1.0, "rise_t": -1.0, "moving": false}
		_npcs.append(o)
		if kind == "club":
			_club.append(o)
			_cigs.append(AlleyCine.Cigarette.new(n, _root, float(i)))
		i += 1
	_who = {"SAL": _spk(SAL, _club[0]), "VINNIE": _spk(VIN, _club[1]), "DOM": _spk(DOM, _club[2])}
	for o: Dictionary in _npcs:
		if o["a"]["kind"] == "rise":
			_who["RISER"] = _spk({"name": "GRAY", "color": "#c7a4ff", "pitch": 0.7}, o)
			break


func _spk(base: Dictionary, o: Dictionary) -> Dictionary:
	var n: GrayAlienNpc = o["n"]
	var d := base.duplicate()
	d["at"] = func() -> Vector3: return n.mouth_world()
	d["talk"] = func(b: bool) -> void: n.set_talk(b)
	return d


func _head_pos() -> Vector3:
	if an != null and an.by_key.has(&"head"):
		return an.bone_world_pos(an.by_key[&"head"].bone)
	return Vector3(P.x if P != null else 0.0, (P.y if P != null else 0.0) + 1.6, P.z if P != null else 0.0)


# ---- timeline ----
func _E(tm: float, fn: Callable) -> void:
	_ev.append({"t": tm, "fn": fn, "n": _ev.size()})


func _build_events() -> void:
	_ev = []
	_E(0.01, func() -> void: Game.ui.set_fade(false))
	_E(0.8, _strike.bind({"close": true, "z": float(_path["z0"]) - 70.0, "x": 0.0}))
	for l: Array in LINES:
		_E(l[0], func() -> void: subs.say(_who[l[1]], l[2]))
	_E(26.5, func() -> void:
		var s: GrayAlienNpc = _club[0]["n"]
		s.set_pose(&"aim")
		s.look_at_point(P.x, P.z))
	_E(TL["shot"], _warning_shot)
	_E(TL["slowEnd"], func() -> void:
		_unslow()
		cam.kick(0.6))
	_E(TL["turn"], _strike.bind({"close": true}))
	_E(float(TL["turn"]) + 0.05, AlleyCine.snd_sting)
	_E(TL["draw"], AlleyCine.arm_rifle)
	var fel: float = TL["fellas"]
	_E(fel + 0.15, AlleyCine.snd_whistle)
	_E(fel + 0.3, _strike.bind({"overhead": true}))
	_E(fel + 2.5, _strike.bind({"close": true}))      # and again, so you can see how many there are
	var i := 0
	for o: Dictionary in _npcs:
		var kind: String = o["a"]["kind"]
		var n: GrayAlienNpc = o["n"]
		if kind == "club":
			_E(fel + 0.6, n.set_pose.bind(&"aim"))
		elif kind == "rise":
			_E(fel + 1.1 + i * 0.22, func() -> void:
				n.set_shown(true)
				o["rise_t"] = 0.0
				AlleyCine.snd_rise())
		elif kind == "door":
			_E(fel + 1.0, func() -> void:
				n.set_shown(true)
				o["moving"] = true
				n.move_to(o["a"]["x"], o["a"]["z"], 3.2, func() -> void: o["moving"] = false)
				AlleyCine.snd_rise())
		i += 1
	_E(TL["snap"], _snap_rig)
	_E(TL["end"], finish)
	_ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"] if a["t"] != b["t"] else a["n"] < b["n"])


## the warning shot: a bolt a hand's width past his right ear
func _warning_shot() -> void:
	var s: GrayAlienNpc = _club[0]["n"]
	var R := s.R
	R.yaw = atan2(P.x - R.x, P.z - R.z)
	s.fire()
	var tmp := s.view.muzzle_world()
	AlleyCine.snd_pistol(tmp)
	var hp := _head_pos()
	var dir := (hp - tmp).normalized()
	var side := Vector3(dir.z, 0.0, -dir.x).normalized()
	var past := hp + side * -0.28 + Vector3(0.0, 0.06, 0.0)
	var end := past + (past - tmp).normalized() * 22.0
	end.y = 0.05
	_bolts.fire(tmp, end, 40.0, func(q: Vector3) -> void:
		if Game.fx != null:
			Game.fx.sparks(q, 14, 4.0, Vector3.UP, 0x6dff8a)
		Game.sfx.play_at("boltHit", q.x, q.y, q.z, {"kind": "wall", "bk": "plasma", "range": 70.0}))
	_slow = Game.time_scale      # slow motion while it goes past (_slow = the speed to go back to)
	Game.time_scale = _slow * 0.22
	_after.append([0.26, AlleyCine.snd_whizz])      # (JS setTimeout: real time)


## where Prog is (and how he stands) at cutscene time t
func _prog_at(tm: float) -> Dictionary:
	var z: float = float(_path["z0"]) + WALK * minf(tm, TL["shot"])
	var x: float = _path["x"]
	var sal: GrayAlien = (_club[0]["n"] as GrayAlienNpc).R
	var face := atan2(sal.x - x, sal.z - z)
	var yaw := 0.0 if tm < float(TL["turn"]) else AlleyCine.wrap(face * Cutscene.ease_((tm - float(TL["turn"])) / 1.3))
	return {"x": x, "z": z, "yaw": yaw, "walking": tm < float(TL["shot"])}


# ---- camera, shot by shot ----
func _camera(dt: float, tm: float) -> void:
	var pr := _prog_at(tm)
	var px: float = pr["x"]
	var pz: float = pr["z"]
	var sal: GrayAlien = (_club[0]["n"] as GrayAlienNpc).R
	var dom: GrayAlien = (_club[2]["n"] as GrayAlienNpc).R
	var i := 0
	for k in SHOTS.size():
		if tm >= SHOTS[k]:
			i = k
	var nx: float = SHOTS[i + 1] if i + 1 < SHOTS.size() else float(TL["end"])
	var u := (tm - SHOTS[i]) / (nx - SHOTS[i])
	var cx: float = _club_at["x"]
	var cz: float = _club_at["z"]
	match i:
		0:      # behind him and above: a small wet figure, the lamps and the awning up ahead
			cam.shot(dt, &"A", Vector3(px + lerpf(2.9, 2.3, u), lerpf(4.0, 3.2, u), pz - lerpf(3.2, 2.6, u)), Vector3(px - 0.6, 0.9, pz + 7.0), 3.0, true)
		1:      # side-front, low: the slump, the rain
			cam.shot(dt, &"B", Vector3(px + 2.0, 1.05, pz + 2.6 - u * 0.4), Vector3(px, 1.25, pz), 5.0, true)
		2:      # behind the grays' shoulders, under the awning
			cam.shot(dt, &"C", Vector3(cx + 0.9, 1.85, cz - 2.4), Vector3(px, 1.2, pz), 4.0, true)
		3:      # his face: eyes front
			var h := _head_pos()
			cam.shot(dt, &"D", Vector3(px + 0.3, h.y + 0.12, pz + 1.6), Vector3(px, h.y - 0.3, pz), 7.0, true)
		4:      # two-shot from across the street
			cam.shot(dt, &"E", Vector3(5.6, 1.7, pz - 4.5 + u * 1.5), Vector3((px + sal.x) / 2.0, 1.2, (pz + sal.z) / 2.0), 3.0, true)
		5:      # Sal draws
			cam.shot(dt, &"F", Vector3(sal.x + 1.4, 1.35, sal.z + 0.9), Vector3(sal.x, 1.2, sal.z), 6.0, true)
		6:      # right behind his head as it goes past
			var h := _head_pos()
			cam.shot(dt, &"G", Vector3(px + 0.5, h.y + 0.12, pz - 0.95), Vector3(px - 0.1, h.y, pz + 6.0), 9.0, true)
		7:      # he has stopped. eyes.
			var h := _head_pos()
			cam.shot(dt, &"H", Vector3(px - 0.25, h.y + 0.1, pz + 1.5), Vector3(px, h.y - 0.3, pz), 8.0, true)
		8:      # past Dom: Prog's back, standing in the rain
			cam.shot(dt, &"I", Vector3(dom.x - 0.7, 1.6, dom.z - 1.6), Vector3(px, 1.3, pz), 4.0, true)
		9:      # he turns, straightens up, the rifle comes out: low, in front of him
			var f := atan2(sal.x - px, sal.z - pz)
			var k := Cutscene.ease_((tm - float(TL["turn"])) / 1.5)
			var dx := sin(f)
			var dz := cos(f)
			cam.shot(dt, &"J", Vector3(px + dx * lerpf(2.6, 2.1, k) + dz * 0.7, lerpf(0.85, 0.6, k), pz + dz * lerpf(2.6, 2.1, k) - dx * 0.7), Vector3(px, 1.75, pz), 5.0, true)
		10:      # crane up and round from the north-east: they are everywhere
			var a := 0.35 + u * 1.5
			var r := lerpf(4.2, 7.5, Cutscene.ease_(u))
			var h := lerpf(1.7, 4.4, Cutscene.ease_(u))
			cam.shot(dt, &"K", Vector3(px + sin(a) * r, h, pz + cos(a) * r), Vector3(px, 1.0, pz), 3.0, true)
		_:
			cam.to_rig(Game.rig, (tm - float(TL["blend"])) / (float(TL["end"]) - float(TL["blend"])))


func _snap_rig() -> void:
	var rig := Game.rig
	if rig == null or P == null:
		return
	var sal: GrayAlien = (_club[0]["n"] as GrayAlienNpc).R
	P.yaw = atan2(sal.x - P.x, sal.z - P.z)
	# Hand gameplay back to the shared shoulder camera; a set-piece pull disables hip-fire framing.
	rig.pull_t = 0.0
	rig.pull_w = 0.0
	rig.pull_eff = 0.0
	rig.snap_to(P)
	_rig_in = true


# ---- control ----
func start(p: Player) -> bool:
	if on:
		return false
	P = p
	if subs == null:
		subs = AlleyCine.Subs.new()
		skip_ = AlleyCine.Skip.new(skip)
	if _root == null:
		_build()
	_root.visible = true
	for o: Dictionary in _npcs:      # (a restart: the cast back where it began)
		_reset_npc(o)
	on = true
	t = 0.0
	_ei = 0
	st.slump = 1.0
	st.flinch = 0.0
	_rig_in = false
	_build_events()
	cam.reset()
	if Game.combat != null:      # hands in his pockets, not on a gun
		Game.combat.equip(-1)
	Game.hud.set_suppressed(true)
	skip_.start()
	_place(0.0)
	return true


func _reset_npc(o: Dictionary) -> void:
	var kind: String = o["a"]["kind"]
	var n: GrayAlienNpc = o["n"]
	var ax: float = float(_club_at["x"]) + 0.15 if kind == "door" else float(o["a"]["x"])
	var az: float = _club_at["z"] if kind == "door" else float(o["a"]["z"])
	var i := _npcs.find(o)
	var y: float = o["y"]
	n.place(ax, y - 1.35 if kind == "rise" else y, az, PI / 2.0 + (i - 1) * 0.35 if kind == "club" else atan2(float(_path["x"]) - float(o["a"]["x"]), float(_path["stop"]) - float(o["a"]["z"])))
	n.set_pose(&"idle" if kind == "club" else &"aim")
	n.set_shown(kind == "club")
	o["risen"] = 0.0 if kind == "rise" else 1.0
	o["rise_t"] = -1.0
	o["moving"] = false


## straight to the moment they pop up
func skip() -> void:
	if not on:
		return
	var to: float = float(TL["fellas"]) - 0.1
	if t >= to:
		return
	_unslow()
	subs.clear()
	t = to
	while _ei < _ev.size() and float(_ev[_ei]["t"]) < to:      # (lines, the shot, the strikes in between are dropped)
		_ei += 1
	(_club[0]["n"] as GrayAlienNpc).set_pose(&"aim")
	AlleyCine.arm_rifle()
	st.slump = 0.0
	cam.reset()
	Game.ui.set_fade(false)


## aborted = a checkpoint was loaded mid-scene: just clean up
func finish(aborted: bool = false) -> void:
	if not on:
		return
	on = false
	_unslow()
	if not _rig_in and not aborted:
		_snap_rig()
	subs.clear()
	skip_.stop()
	Game.hud.set_suppressed(false)
	Inp.guard_arm()
	if an != null:
		an.pose_hook = Callable()
		an = null
	if _root != null:      # the stand-ins go; the level spawns the real ones in their places
		_root.visible = false
		for o: Dictionary in _npcs:
			(o["n"] as GrayAlienNpc).set_shown(false)
	if P != null:
		P.vx = 0.0
		P.vz = 0.0
	AlleyCine.arm_rifle()
	if not aborted and _on_done.is_valid():
		_on_done.call()


func _place(tm: float) -> void:
	var pr := _prog_at(tm)
	P.invuln = maxf(P.invuln, 1.0)
	P.dead = false
	P.grounded = true
	P.vy = 0.0
	P.x = pr["x"]
	P.z = pr["z"]
	P.y = _gy(pr["x"])
	P.yaw = pr["yaw"]
	P.vx = 0.0
	P.vz = WALK if pr["walking"] else 0.0


func update(dt: float, p: Player) -> void:
	# (runs on real time for the two timers the JS keeps outside the game clock)
	var rdt := get_process_delta_time()
	for i in range(_after.size() - 1, -1, -1):
		_after[i][0] -= rdt
		if float(_after[i][0]) <= 0.0:
			(_after[i][1] as Callable).call()
			_after.remove_at(i)
	if subs != null:
		subs.tick(dt if on else rdt)
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
	_place(tm)
	st.t = tm
	var turn: float = TL["turn"]
	var shot_t: float = TL["shot"]
	st.slump = 1.0 - AlleyCine.win(tm, turn + 0.3, turn + 1.6)
	st.flinch = maxf(0.0, 1.0 - (tm - shot_t - 0.08) / 1.4) * minf(1.0, (tm - shot_t - 0.08) * 12.0) if tm > shot_t + 0.08 else 0.0
	# the grays: heads (and the club's bodies) follow him, the risers come up from behind their cover
	for o: Dictionary in _npcs:
		var n: GrayAlienNpc = o["n"]
		var R := n.R
		if n.is_shown():
			n.look_at_point(P.x, P.z)
		if o["a"]["kind"] == "club" and n.pose == &"idle":
			R.yaw += AlleyCine.wrap(atan2(P.x - R.x, P.z - R.z) * 0.7 + PI / 2.0 * 0.3 - R.yaw) * minf(1.0, dt * 1.5)
		elif n.pose == &"aim" and not o["moving"]:
			R.yaw += AlleyCine.wrap(atan2(P.x - R.x, P.z - R.z) - R.yaw) * minf(1.0, dt * 6.0)
		if float(o["rise_t"]) >= 0.0 and float(o["risen"]) < 1.0:
			o["rise_t"] += dt
			o["risen"] = Cutscene.ease_(float(o["rise_t"]) / 0.5)
			R.y = lerpf(float(o["y"]) - 1.35, o["y"], o["risen"])
		n.update(tm, dt)
	for c: AlleyCine.Cigarette in _cigs:
		c.update(dt)
	_bolts.update(dt)
	_camera(dt, tm)


func pose_player(a: Animator) -> void:
	if not on:
		return
	if an != a:
		an = a
		a.pose_hook = st.hook


func seek(s: float) -> void:
	if not on:
		return
	t = s
	while _ei < _ev.size() and float(_ev[_ei]["t"]) < s:
		_ei += 1
	cam.reset()


func _exit_tree() -> void:
	_unslow()
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
