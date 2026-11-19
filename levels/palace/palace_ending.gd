class_name PalaceEnding
extends Cutscene
## The end of Sambo's stream (user, 2026-11-19): "The mech blows up his little body falls out he begs for mercy while still being a condescending prick. prog rolls his eyes and lets him go.
## as progs walking away he says he'll let him know if he needs help with another stream that was fucking sick." As the level's `cine`: the suit's head flies off the wreck and lands on the
## slab, the little alien (npcs/sambo/sambo_pilot.gd) tumbles out of its hatch, rolls over, gets up on his knees; then the talk (the shared dialogue: his three lines and Prog's "...Go.",
## recorded); then Prog walks away toward the hoist, the little guy on his feet behind him calling after him, and the screen goes to black: back to the street at the site's gate.
## The mission is done (story flag samboDone); the stream's chat has paid Prog as the mech broke (sambo_mech.gd donations).

const T_LAND := 1.3
const T_OUT := 2.6
const T_TALK := 3.6
const WALK := 6.4
const FLAG := "samboDone"

var lv: PalaceLevel
var play := false      # (core/view.gd: not a playable cutscene)
var t := 0.0
var _prev := 0.0
var phase := &""                 # fly | talk | walk | out
var pilot: SamboPilot
var talker: Dictionary = {}
var _head0 := Transform3D.IDENTITY
var _land := Vector3.ZERO
var _walk_t := 0.0
var _said_last := false


func setup(level: PalaceLevel) -> void:
	lv = level
	pilot = SamboPilot.new()
	lv.add_child(pilot)
	pilot.visible = false


func start() -> void:
	on = true
	t = 0.0
	_prev = 0.0
	phase = &"fly"
	_said_last = false
	enter_cine(true)
	var m := lv.mech
	_head0 = lv.sambo.body.global_transform
	var f := Vector3(sin(m.yaw), 0.0, cos(m.yaw))
	_land = Vector3(m.x, PalaceSite.ly(PalaceSite.NF), m.z) + f * 3.2 + Vector3(1.4, 0.0, 0.0)
	_land.x = clampf(_land.x, 151.0, 175.5)
	_land.z = clampf(_land.z, 187.0, 214.0)
	if lv.mech.legs != null:
		lv.mech.legs.out = 0.0
		lv.mech.legs.pose()
	lv.chat.set_mood(&"end", 4.5)
	lv.chat.add_viewers(25000.0)
	update(0.0)


func skip() -> void:
	if not on:
		return
	if phase == &"fly":
		t = T_TALK
	elif phase == &"walk":
		_walk_t = WALK
	update(0.0)


func _crossed(at: float) -> bool:
	return _prev < at and t >= at


func update(dt: float) -> void:
	if not on:
		return
	if phase != &"talk" and (Game.ui.dlg_req or (Inp.using_pad and Inp.btn(&"attack").pressed)):
		Game.ui.dlg_req = false
		Inp.btn(&"attack").pressed = false
		skip()
	_prev = t
	t += dt
	var P := Game.player
	var floor_y := PalaceSite.ly(PalaceSite.NF)
	match phase:
		&"fly":      # the head off the wreck in an arc, bouncing on the slab; he tumbles out of the hatch
			var u := seg(t, 0.0, T_LAND)
			var p := _head0.origin.lerp(_land - Vector3(0.0, HeadLegs.HIP_Y - 0.2, 0.0), u) + Vector3(0.0, sin(u * PI) * 2.6, 0.0)
			var b := _head0.basis.rotated(Vector3.RIGHT, u * 7.0).rotated(Vector3.FORWARD, u * 3.0)
			if t >= T_LAND:      # down on its side, its middle on the slab
				b = Basis(Vector3.UP, 0.8) * Basis(Vector3.FORWARD, PI / 2.0)
				p = _land - b * Vector3(0.0, 1.55, 0.0) + Vector3(0.0, 0.13, 0.0)
			lv.sambo.body.global_transform = Transform3D(b.orthonormalized(), p)
			lv.sambo.body.talking = false
			lv.sambo.body.update(dt)
			if _crossed(T_LAND):
				Game.fx.dust(_land, 10, 1.4)
				Game.fx.shake = maxf(Game.fx.shake, 0.2)
			# the little guy out of the hatch, rolling over, up onto his knees
			pilot.visible = t >= T_LAND + 0.4
			if pilot.visible:
				var k := seg(t, T_LAND + 0.4, T_OUT)
				var from := _land + Vector3(-0.25, 0.08, 0.1)
				var to := _land + Vector3(-0.9, 0.0, -0.6)
				var pp := from.lerp(to, ease_out(k))
				pp.y = floor_y + sin(k * PI) * 0.12
				pilot.global_position = pp
				pilot.rotation = Vector3(0.0, atan2(P.x - pp.x, P.z - pp.z), (1.0 - k) * TAU * 1.5)
				pilot.kneel = smoothstep(0.6, 1.0, k)
				pilot.update(dt)
			# Prog walks up to him
			if t > T_OUT - 0.4:
				var to_p := Vector2(_land.x - 0.9 - P.x, _land.z - 0.6 + 1.5 - P.z)
				if to_p.length() > 1.4:
					player_step(dt, 0.45, atan2(to_p.x, to_p.y))
			shot(_land + Vector3(-3.2, 1.2, -2.6), _land + Vector3(-0.5, 0.25, -0.3), 46.0)
			if t >= T_TALK:
				_start_talk()
		&"talk":
			pilot.update(dt)
		&"walk":      # Prog walks off toward the hoist; behind him the little guy gets up and calls after him
			_walk_t += dt
			var go := Vector2(161.5 - P.x, 214.5 - P.z)
			if go.length() > 0.6:
				player_step(dt, 0.5, atan2(go.x, go.y))
			pilot.kneel = 1.0 - seg(_walk_t, 0.6, 1.4)
			pilot.plead = 0.0
			pilot.wave = seg(_walk_t, 1.2, 1.8)
			pilot.look_on = true
			pilot.look_target = Vector3(P.x, P.y + 1.4, P.z)
			pilot.update(dt)
			if not _said_last and _walk_t > 1.2:
				_said_last = true
				_say_from_pilot("s_end_04")
			var pp := pilot.global_position
			shot(pp + Vector3(0.0, 0.3, 0.0) - (Vector3(P.x, pp.y, P.z) - pp).normalized() * 1.1 + Vector3(0.35, 0.0, 0.0), Vector3(P.x, P.y + 1.2, P.z), 50.0)
			if _walk_t > WALK:
				phase = &"out"
				Game.ui.set_fade(true)
				_walk_t = 0.0
		&"out":
			_walk_t += dt
			pilot.update(dt)
			if _walk_t > 0.9:
				_done()


## The talk: his three lines (begging, and talking down to Prog while he does it) and Prog's sigh, recorded
func _start_talk() -> void:
	phase = &"talk"
	pilot.kneel = 1.0
	pilot.plead = 1.0
	pilot.look_on = true
	var P := Game.player
	pilot.look_target = Vector3(P.x, P.y + 1.6, P.z)
	var me := Dialogue.player_name()
	var lines: Array = [
		{"text": SamboLines.text("s_end_01"), "clip": SamboLines.DIR + "s_end_01.wav"},
		{"text": SamboLines.text("s_end_02"), "clip": SamboLines.DIR + "s_end_02.wav"},
		{"text": SamboLines.text("s_end_03"), "clip": SamboLines.DIR + "s_end_03.wav"},
		{"text": SamboLines.text("p_end_01"), "who": me, "clip": SamboLines.DIR + "p_end_01.wav"},
	]
	var pp := pilot.global_position
	var yaw := atan2(P.x - pp.x, P.z - pp.z)
	if not talker.is_empty():
		Game.dialogue.talkers.erase(talker)
	talker = Game.dialogue.add_talker({"id": "palace_sambo_end", "name": "SAMBO", "x": pp.x, "y": pp.y, "z": pp.z, "yaw": yaw, "radius": 0.1, "color": "#7be34a", "voice": "",
		"lines": lines, "actor": self, "active": func() -> bool: return false,
		"shot": {"cam_dist": 1.7, "cam_side": 0.25, "cam_y": 0.55, "look_y": 0.45, "look_side": 0.35, "spot_fwd": 1.25, "spot_side": 0.55},
		"on_end": func(_d: Dictionary) -> void: _walk_off()})
	on = false      # (the dialogue has the camera now; the walk-off takes it back)
	leave_cine()
	Game.dialogue.start(talker)


## Dialogue actor
func look_at_point(x: float, z: float) -> void:
	pilot.look_on = true
	pilot.look_target = Vector3(x, pilot.global_position.y + 1.6, z)


func look_away() -> void:
	pass


func set_talk(v: bool) -> void:
	pilot.talking = v


func on_line(L: Dictionary) -> void:
	pilot.talking = not L.has("who")
	pilot.plead = 1.0 if not L.has("who") else 0.7


func mouth_world() -> Vector3:
	return pilot.head_world()


func _walk_off() -> void:
	if not talker.is_empty():
		Game.dialogue.talkers.erase(talker)
		talker = {}
	on = true
	phase = &"walk"
	_walk_t = 0.0
	enter_cine(false)
	lv.chat.push("uncle_vibes", "unc rolled his eyes so hard i felt it")


func _say_from_pilot(id: String) -> void:
	var st := SamboLines.clip(id)
	if st == null:
		return
	var m := pilot.head_world()
	Game.sfx.clip_at(st, m.x, m.y, m.z, {"range": 60.0, "ref": 8.0, "gain": 1.5, "voice": true})
	Game.hud.subtitle({"name": "SAMBO", "text": SamboLines.text(id), "dur": st.get_length()})
	pilot.talking = true
	get_tree().create_timer(st.get_length(), false).timeout.connect(func() -> void: pilot.talking = false)


## The stream is over: the story remembers it, and it is back to the street at the site's gate
func _done() -> void:
	on = false
	leave_cine()
	Game.story_set(FLAG)
	lv.chat.show_chat(false)
	lv.ended()
	Game.doors.travel({"id": "palace_done", "label": "", "to": "hub", "spawn_at": "palace", "loading": "FOINT CITY", "before": func() -> void: pass})
