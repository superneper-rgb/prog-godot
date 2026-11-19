class_name Dialogue
extends RefCounted
## NPC DIALOGUE (JS index.html addTalker, DLG, startDialogue, dlgTick, dlgCamera): the one way any NPC talks. The prompt appears in range; X starts it; the game freezes behind letterbox bars; the camera
## eases to a shot with the NPC centre-right and the player on the left; the text types out with a per-syllable voice and the NPC's mouth moves; X skips the typing, then moves on; the camera eases back.
## Add an NPC with add_talker({id, name, x, y, z, yaw, lines, actor}). An actor only needs look_at(x, z) (or look_away()), set_talk(bool), mouth_world() -> Vector3. Never a separate box, camera or prompt.
## `wait` (Callable() -> bool, new here, CLUB 9's man on the phone): the talk opens (letterbox, shot, the player walked to his spot) but the first line holds while it says true, the box hidden. An actor with on_line(L) hears of each line as it begins (the line's Dictionary, extra keys and all), to act it out. A line's `after` (seconds): a silent beat held once it is said, before the next line.
## Choices (new here, the hub's puppy): a line with `choices: [{label, lines, on_end, hold}]` offers them once it has been said; up / down picks, X takes it, and the talk goes on with that choice's `lines`. `on_end` runs with the talker's own when the talk closes. `hold` (Callable(d)): when the lines run out the talk does not close; the box goes, the shot and the letterbox stay, and the callable takes it from there (it ends the talk itself, or travels, which ends it).

const SHOT_DEFAULT := {"cam_dist": 3.2, "cam_side": 0.1, "cam_y": 1.35, "look_y": 0.7, "look_side": 0.45, "spot_fwd": 0.95, "spot_side": 1.05}

var talkers: Array[Dictionary] = []
var on := false
var req := false        # X: finish the line, or move on once it is complete
var npc: Dictionary = {}
var line := 0
var phase := ""
var t := 0.0
var blend := 0.0
var shown := 0
var voiced := 0
var syl := 0
var syl_n := 2
var done_t := 0.0
var slide := 0.6
var in_dur := 0.8
var from := Vector2.ZERO
var spot := Vector2.ZERO
var _shot := View.Shot.new()
var _last := ""
var _clip_p: AudioStreamPlayer = null      # a line's recording (lines with `clip`)
var _clip_len := 0.0
var _lines: Array = []                 # this talk's lines: the talker's, then a choice's
var _end_cb := Callable()              # the picked choice's on_end
var _hold := Callable()                # the picked choice's hold
var sel := 0                           # the highlighted choice
var _nav_y := 0.0                      # the stick's last up / down, for one step per push


static func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## JS addTalker. `terminal: true` (new here, the Sigil): the talk is shown on the SchleedTech terminal pulled up close, not in the box. Fields as in the JS: radius, y, yaw, color, voice, voice_pitch, type_rate, hold, active (Callable -> bool), actor, on_start, on_end, shot, lines (each a String or {text, who, voice, pitch, clip, choices}; or a Callable that returns them when the talk starts).
## `clip` (new here): a recording (res:// path) spoken for that line in place of the babble; the text types out over its length and the line holds until it has been said.
func add_talker(def: Dictionary) -> Dictionary:
	var d := {"radius": 2.6, "y": 0.0, "yaw": 0.0, "color": "#7be34a", "voice": "alienSyl", "voice_pitch": 1.0, "type_rate": 34.0, "hold": 2.6, "active": Callable(), "actor": null}
	d.merge(def, true)
	if not d.has("id") or not d.has("name") or not (d.get("lines") is Callable or (d.get("lines") is Array and not (d["lines"] as Array).is_empty())):
		push_error("add_talker needs id, name and lines")
		return d
	var s := SHOT_DEFAULT.duplicate()
	if def.has("shot"):
		s.merge(def["shot"], true)
	d["shot"] = s
	talkers.append(d)
	return d


## Talkers die with their level (JS: TALKERS.splice back to the count at entry).
func clear_level() -> void:
	if on:
		end_dialogue()
	talkers.clear()


static func _active(d: Dictionary) -> bool:
	var a: Callable = d.get("active", Callable())
	return a.is_null() or a.call()


func near_talker() -> Dictionary:
	var P := Game.player
	if P.dead:
		return {}
	for d: Dictionary in talkers:
		if _active(d) and absf(P.y - float(d["y"])) < 1.5 and U.hyp(P.x - float(d["x"]), P.z - float(d["z"])) < float(d["radius"]):
			return d
	return {}


## forward = the way the NPC faces; left = the viewer's left when looking at the NPC from the front (where the player stands in the shot)
static func _frame(d: Dictionary) -> PackedFloat32Array:
	var yaw := float(d["yaw"])
	var fx := sin(yaw)
	var fz := cos(yaw)
	return PackedFloat32Array([fx, fz, -fz, fx])


func start(d: Dictionary) -> void:
	var P := Game.player
	var S: Dictionary = d["shot"]
	var F := _frame(d)
	var sx := float(d["x"]) + F[0] * float(S["spot_fwd"]) + F[2] * float(S["spot_side"])     # the player takes the spot in front of the NPC, on the left of the shot
	var sz := float(d["z"]) + F[1] * float(S["spot_fwd"]) + F[3] * float(S["spot_side"])
	var dist := U.hyp(sx - P.x, sz - P.z)
	on = true
	npc = d
	line = 0
	phase = "in"
	t = 0.0
	blend = 0.0
	shown = 0
	voiced = 0
	syl = 0
	syl_n = 2
	done_t = 0.0
	req = false
	_last = ""
	var ls: Variant = d["lines"]
	_lines = (ls as Callable).call() if ls is Callable else (ls as Array).duplicate()
	_end_cb = Callable()
	_hold = Callable()
	sel = 0
	slide = clampf(dist / 3.2, 0.35, 1.2)
	in_dur = maxf(0.8, slide)
	from = Vector2(P.x, P.z)
	spot = Vector2(sx, sz)
	P.vx = 0.0
	P.vz = 0.0
	var A: Variant = d.get("actor")
	if A != null and A.has_method(&"look_at_point"):
		A.look_at_point(P.x, P.z)
	Game.ui.dialog.set_bars(true)
	Game.ui.dialog.set_terminal(bool(d.get("terminal", false)))
	Game.hud.set_suppressed(true)
	var cb: Callable = d.get("on_start", Callable())
	if not cb.is_null():
		cb.call(d)


func end_dialogue() -> void:
	var d := npc
	on = false
	phase = ""
	npc = {}
	Game.ui.dialog.set_bars(false)
	Game.ui.dialog.show_box(false)
	Game.ui.dialog.set_terminal(false)
	if _clip_p != null:
		_clip_p.stop()
	if Game.started:
		Game.hud.set_suppressed(false)
	if Game.animator != null:
		Game.animator.talking = false
	var A: Variant = d.get("actor")
	if A != null:
		if A.has_method(&"set_talk"):
			A.set_talk(false)
		if A.has_method(&"look_away"):
			A.look_away()
	Inp.guard_arm()
	var cb: Callable = d.get("on_end", Callable())
	var ccb := _end_cb
	_end_cb = Callable()
	_hold = Callable()
	if not cb.is_null():
		cb.call(d)
	if not ccb.is_null():
		ccb.call(d)


## the dialogue shot: a little way out in front of the NPC, looking at its chest, aimed slightly to the player's side so the NPC sits right of centre and the player sits left
func camera() -> View.Shot:
	var d := npc
	var S: Dictionary = d["shot"]
	var F := _frame(d)
	var e := _ease(clampf(blend, 0.0, 1.0))
	var rig := Game.rig
	var x := float(d["x"])
	var y := float(d["y"])
	var z := float(d["z"])
	var p := Vector3(x + F[0] * float(S["cam_dist"]) + F[2] * float(S["cam_side"]), y + float(S["cam_y"]), z + F[1] * float(S["cam_dist"]) + F[3] * float(S["cam_side"]))
	var l := Vector3(x + F[2] * float(S["look_side"]), y + float(S["look_y"]), z + F[3] * float(S["look_side"]))
	_shot.pos = rig.pos.lerp(p, e)
	_shot.look = rig.look.lerp(l, e)
	return _shot


## A line begins: if it has a recording, say it
func _begin_line(d: Dictionary) -> void:
	var L := _line_of(d, line)
	_clip_len = 0.0
	var A: Variant = d.get("actor")
	if A != null and A.has_method(&"on_line"):
		A.on_line(L)
	if L.has("who") and A != null and A.has_method(&"set_talk"):      # somebody else's line (the player's answer): the NPC's mouth is shut
		A.set_talk(false)
	if _clip_p != null:
		_clip_p.stop()
	var path := String(L.get("clip", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	if _clip_p == null:
		_clip_p = AudioStreamPlayer.new()
		_clip_p.bus = &"SFX"
		_clip_p.process_mode = Node.PROCESS_MODE_ALWAYS
		Game.add_child(_clip_p)
	_clip_p.stream = load(path)
	_clip_p.volume_db = linear_to_db(float(L.get("gain", 1.3)))
	_clip_p.play()
	_clip_len = _clip_p.stream.get_length()


func _line_of(d: Dictionary, i: int) -> Dictionary:     # a line: a String, or {text, who, voice, pitch}
	var L: Variant = _lines[i]
	return L if L is Dictionary else {"text": String(L)}


static func _is_alnum(c: int) -> bool:
	return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)


## one alien-language syllable per 2-3 newly typed letters, from the NPC's mouth; punctuation breaks the rhythm. A skipped line is not babbled all at once.
func _voice(d: Dictionary, text: String, a: int, b: int) -> void:
	var L := _line_of(d, line)
	var v: Variant = L["voice"] if L.has("voice") else d["voice"]
	var pitch: float = L.get("pitch", d["voice_pitch"])
	if v == null or String(v) == "" or b - a > 6 or L.has("clip"):      # voice: null = no babble (the talker plays its own recording in on_start)
		voiced = b
		return
	for i in range(a, b):
		var ch := text.unicode_at(i)
		if ".!?,;:".contains(char(ch)):
			if syl > 0 and i > 0:
				_say(d, String(v), pitch, text, i - 1, ".!?".contains(char(ch)))    # a half-finished syllable closes at the punctuation (longer at the end of a sentence)
			syl = 0
			continue
		if not _is_alnum(ch):
			continue
		syl += 1
		if syl < syl_n:
			continue
		syl = 0
		syl_n = 2 + (ch & 1)
		_say(d, String(v), pitch, text, i, false)
	voiced = b


func _say(d: Dictionary, v: String, pitch: float, text: String, i: int, last: bool) -> void:
	var h := (text.unicode_at(maxi(0, i - 2)) * 31 + text.unicode_at(maxi(0, i - 1)) * 17 + text.unicode_at(i) * 7 + i * 13) & 0x7fffffff
	var A: Variant = d.get("actor")
	var p := Vector3(float(d["x"]), float(d["y"]) + 1.3, float(d["z"]))
	if A != null and A.has_method(&"mouth_world"):
		p = A.mouth_world()
	Game.sfx.play_at(v, p.x, p.y, p.z, {"range": 40.0, "ref": 3.0, "h": h, "pitch": pitch, "last": last})


## JS dlgTick. Runs while the world is frozen.
func tick(dt: float) -> void:
	var d := npc
	var A: Variant = d.get("actor")
	var P := Game.player
	t += dt
	var L := _line_of(d, line)
	var text: String = L["text"]
	var n_lines := _lines.size()
	if phase == "in":
		var u := _ease(clampf(t / slide, 0.0, 1.0))
		P.x = lerpf(from.x, spot.x, u)
		P.z = lerpf(from.y, spot.y, u)
		blend = clampf(t / in_dur, 0.0, 1.0)
		if t >= in_dur:
			phase = "wait"
	if phase == "wait":
		req = false      # (nothing to skip yet)
		var w: Callable = d.get("wait", Callable())
		if w.is_null() or not w.call():
			phase = "talk"
			t = 0.0
			if A != null and A.has_method(&"set_talk"):
				A.set_talk(not _line_of(d, line).has("who"))
			Game.ui.dialog.show_box(true)
			_begin_line(d)
	elif phase == "talk":
		var rate: float = d["type_rate"]
		var n := text.length()
		if _clip_len > 0.0:      # a recorded line types out as it is said
			rate = n / maxf(0.3, _clip_len * 0.92)
		shown = mini(n, int(floorf(t * rate)))
		if req:
			req = false
			if shown < n:
				t = n / rate + 0.001
			else:
				done_t = 1e9
		shown = mini(n, int(floorf(t * rate)))
		if shown > voiced:
			_voice(d, text, voiced, shown)
		if shown >= n:
			if A != null and A.has_method(&"set_talk"):
				A.set_talk(false)
			done_t += dt
			if L.has("choices") and done_t > 0.25:      # the line is said: over to the player
				phase = "choose"
				sel = 0
				done_t = 0.0
			elif done_t > (0.45 if _clip_len > 0.0 else float(d["hold"])) + float(L.get("after", 0.0)):      # (`after`: a beat held once the line is said, before the next)
				if line < n_lines - 1:
					line += 1
					t = 0.0
					shown = 0
					voiced = 0
					syl = 0
					done_t = 0.0
					L = _line_of(d, line)
					text = L["text"]
					_begin_line(d)
					if A != null and A.has_method(&"set_talk"):
						A.set_talk(not L.has("who"))      # (a line with `who` is the player's: _begin_line shut the NPC's mouth, and it stays shut)
				else:
					_finish()
	elif phase == "choose":
		var ch: Array = L["choices"]
		var step := _nav()
		if step != 0:
			sel = posmod(sel + step, ch.size())
			if Game.sfx != null:
				Game.sfx.play("vendNav")
		if req:
			req = false
			_pick(ch[sel] as Dictionary)
			n_lines = _lines.size()
			L = _line_of(d, line)
			text = L["text"]
	elif phase == "held":
		pass
	elif phase == "out":
		Game.ui.dialog.show_box(false)
		blend -= dt / 0.7
		if blend <= 0.0:
			end_dialogue()
			return
	var done := phase != "talk" or shown >= text.length()
	var more := line < n_lines - 1
	var hint := "SKIP" if not done else ("NEXT" if more else "CLOSE")
	var who: String = L.get("who", d["name"])
	var body := text.substr(0, shown)
	if phase == "choose":      # the player's turn: the choices in the same box, under his name
		hint = "CHOOSE"
		who = player_name()
		body = ""
		var ch: Array = L["choices"]
		for i in ch.size():
			body += ("> " if i == sel else "   ") + String((ch[i] as Dictionary)["label"]) + ("
" if i < ch.size() - 1 else "")
	var key := "%s|%s|%s|%s|%s|%s" % [who, shown, hint, Inp.using_pad, phase, sel]
	if key != _last:
		_last = key
		Game.ui.dialog.set_content(who, body, hint)
	P.vx = 0.0
	P.vz = 0.0
	P.update(dt, Game.rig.yaw, true)
	P.yaw += U.wrap_angle(atan2(float(d["x"]) - P.x, float(d["z"]) - P.z) - P.yaw) * minf(1.0, dt * 9.0)     # faces the NPC
	if A != null and A.has_method(&"look_at_point"):
		A.look_at_point(P.x, P.z)
	if Game.animator != null:
		Game.animator.talking = phase == "talk" and L.has("who") and shown < text.length()      # his own line: his jaw moves while it types out
		Game.animator.update(dt, P)


## The player's name on his lines and choices
static func player_name() -> String:
	return "TOMMY" if Game.char_pick == "tommy" else "PROG"


## up / down while choosing: arrows, W / S, the d-pad, one step per push of the stick
func _nav() -> int:
	var step := 0
	if Inp.key_hit(KEY_UP) or Inp.key_hit(KEY_W) or Inp.btn(&"d_up").pressed:
		step = -1
	elif Inp.key_hit(KEY_DOWN) or Inp.key_hit(KEY_S) or Inp.btn(&"d_down").pressed:
		step = 1
	var y := Inp.raw_ly
	if step == 0 and absf(y) > 0.6 and absf(_nav_y) <= 0.6:
		step = 1 if y > 0.0 else -1
	_nav_y = y
	return step


## A choice is taken: the talk goes on with its lines
func _pick(c: Dictionary) -> void:
	_lines = _lines.slice(0, line + 1) + (c.get("lines", []) as Array)
	_end_cb = c.get("on_end", Callable())
	_hold = c.get("hold", Callable())
	var A: Variant = npc.get("actor")
	if line < _lines.size() - 1:
		line += 1
		phase = "talk"
		t = 0.0
		shown = 0
		voiced = 0
		syl = 0
		done_t = 0.0
		_begin_line(npc)
		if A != null and A.has_method(&"set_talk"):
			A.set_talk(not _line_of(npc, line).has("who"))
	else:
		_finish()


## The lines have run out: ease back out, or hand the shot to the choice's `hold`
func _finish() -> void:
	if _hold.is_null():
		phase = "out"
		return
	phase = "held"
	Game.ui.dialog.show_box(false)
	var h := _hold
	_hold = Callable()
	h.call(npc)
