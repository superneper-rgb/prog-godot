class_name PhoneGuy
extends Node3D
## CLUB 9's man on the phone, PAULY (2026-11-17, the user's scene, recording and name): a green alien in Boston / Brooklyn clothes (enemies/green_alien_boston.gd) on the payphone across the
## hallway from STAFF ONLY, losing it at his wife Marie over the music. The call plays once, from when Prog first comes near the hallway, and stops at "...hear all that."; it can't be
## heard from the floor, and comes through clearer the closer Prog gets (a low-pass and a level on its own bus). X on him starts the talk at any point: during the call the talk opens
## and waits (Dialogue `wait`) while he finishes it and hangs up, then it begins with Prog's first line. His lines are acted: normal lines with a hand put out now and then, yelled
## ones with both hands up, the ones he is ashamed of with his head and shoulders down. When the talk ends he walks out of the club to the street (his rig is outside: levels/hub/hub_race_rig.gd).
## Recording: Gemini TTS (Puck for him, Algenib for Prog), one take of the whole scene, cut per line into assets/sfx/club9-green/ at its silences (ChatGPT's Whisper alignment, checked).

const FLAG := "club9_green_met"      # story: the talk with Pauly was had (he has gone out to his rig)
const DIR := "res://assets/sfx/club9-green/"
const STAND := Vector3(19.0, 0.0, 11.7)      # at the phone (the hallway is z 10..12.4, its north wall's face at 12.275)
const CALL_YAW := -0.65                          # facing the wall, turned a little toward the club, so the hallway sees his face
const TALK_YAW := -PI / 2.0                     # the talk's frame (Dialogue's shot): down the hallway toward the club, the camera standing back in it
const UNIT := Vector3(18.62, 1.16, 12.23)       # the payphone's middle, on the wall at his right (the side the hallway sees: the handset in his right hand)
const CRADLE := Vector3(18.5, 1.16, 12.19)      # the handset hung on its side
const CORD_FROM := Vector3(18.56, 1.0, 12.2)
const CORD_SEGS := 14
const HEAR := 8.5          # beyond this he can't be heard over the music (from the floor: the hallway's mouth is ~6.6 m off)
const START := 9.5         # the call starts when Prog first comes this near
const CALL_CUES: Array[float] = [0.0, 4.75, 8.11, 11.21, 20.53, 26.07, 29.39, 33.41]      # where each of the call's eight lines begins in club_001.wav
const CALL_MOODS: Array[StringName] = [&"s", &"s", &"s", &"n", &"n", &"a", &"plead", &"s"]
## when he is actually speaking in the call (his mouth): start, end pairs in club_001.wav
const CALL_SPEECH: Array[float] = [0.05, 0.62, 0.91, 1.43, 1.83, 4.07, 4.75, 5.76, 5.88, 6.19, 6.60, 7.24, 8.11, 10.38, 11.21, 12.92, 13.12, 15.52, 15.90, 17.48, 18.17, 18.36,
	18.49, 19.55, 20.53, 22.64, 23.31, 24.43, 24.58, 25.84, 26.07, 26.26, 26.60, 28.12, 29.39, 29.71, 29.88, 30.74, 30.97, 32.10, 33.41, 34.32]
const HANG_S := 1.8        # the slow hang-up after the line
## Out of the club: down the hallway along its north wall (clear of the sick one's mess), across the top of the room, down between the dance floor and the bar, out through the vestibule.
const WAY_OUT: Array[Vector2] = [Vector2(13.6, 11.65), Vector2(11.6, 11.3), Vector2(8.6, 9.4), Vector2(8.3, -2.8), Vector2(1.0, -4.6), Vector2(0.4, -7.0), Vector2(0.0, -10.9)]

## The talk: [id, speaker (G him, P Prog), mood or act]. Moods: n (talking, a hand out now and then), a (yelling: hands up), s (ashamed: head and shoulders down), plead (both hands out);
## acts: tag (holds the entry tag up), reach (for the phone), pockets (pats them for the keys). Extras: after (a silent beat held once the line is said: Dialogue), then (his mood
## once the line has been said, through that beat).
const TALK := [
	["club_002", "P", "What’d the greys do?", &""],
	["club_003", "G", "You listening to my fucking phone call?", &"a"],
	["club_004", "P", "Hard not to.", &""],
	["club_005", "G", "That was private.", &"n"],
	["club_006", "P", "You were louder than the speakers.", &""],
	["club_007", "G", "…Yeah. Well. Bad night.", &"s"],
	["club_008", "P", "What happened?", &""],
	["club_009", "G", "They run the races under the freightway. I had a good night. Then I had a bad race. Then I needed one good race to fix the bad race.", &"n"],
	["club_010", "P", "How many bad races?", &""],
	["club_011", "G", "You my wife?", &"a"],
	["club_012", "P", "No.", &""],
	["club_013", "G", "Then four.", &"s"],
	["club_014", "G", "Still got this, though. Final heat. Bought my entry before everything went to shit.", &"tag"],
	["club_015", "P", "So race.", &""],
	["club_016", "G", "They won’t let me drive.", &"s"],
	["club_017", "P", "Why?", &""],
	["club_018", "G", "Had an argument with the starter.", &"s"],
	["club_019", "P", "About what?", &""],
	["club_020", "G", "Whether he was a fucking thief.", &"a"],
	["club_021", "P", "And?", &""],
	["club_022", "G", "He said no. I called him one again. Now somebody else has to drive.", &"n"],
	["club_023", "G", "You drive?", &"n"],
	["club_024", "P", "Sometimes.", &""],
	["club_025", "G", "Fast?", &"n"],
	["club_026", "P", "When something’s behind me.", &""],
	["club_027", "G", "Good. That’s most of a race.", &"n"],
	["club_028", "P", "What’s left of your vehicle?", &""],
	["club_029", "G", "Whole thing. Outside. Blue one.", &"n"],
	["club_030", "P", "The one with the wheel against the door?", &""],
	["club_031", "G", "Spare.", &"s"],
	["club_032", "P", "It’s still got an axle on it.", &""],
	["club_033", "G", "It’s a very complete spare.", &"s"],
	["club_034", "G", "Look. Please. The rig runs. I can show you. Win that heat, there’s enough in the purse to get my money back.", &"plead"],
	["club_035", "P", "Your money?", &""],
	["club_036", "G", "Our money. The house money. I know what I said.", &"s"],
	["club_037", "G", "Half. You drive, you get half the purse. They pay at the finish. We stand there together, you take yours first.", &"n"],
	["club_038", "P", "And you take the rest home.", &""],
	["club_039", "G", "Yeah.", &"n"],
	["club_040", "P", "You don’t put it on another race.", &"", {"after": 1.6, "then": &"s"}],      # (a beat before his "No.": "You took a while to say that")
	["club_041", "G", "No.", &"s"],
	["club_042", "P", "You took a while to say that.", &""],
	["club_043", "G", "I’m trying to give you an honest answer.", &"s"],
	["club_044", "P", "All right. Show me the rig. If it runs, I’ll do the race.", &"take_tag"],
	["club_045", "G", "…Yeah?", &"n"],
	["club_046", "P", "One race.", &""],
	["club_047", "G", "One race. Absolutely. Thank you.", &"plead", {"after": 2.0, "then": &"reach"}],      # (then he goes for the phone, and Prog asks what he is doing)
	["club_048", "P", "What are you doing?", &""],
	["club_049", "G", "Telling Marie.", &"reach"],
	["club_050", "P", "We haven’t won anything yet.", &""],
	["club_051", "G", "Yeah. Right.", &"s"],
	["club_052", "G", "Blue one’s got a red door, by the way.", &"pockets"],
	["club_053", "P", "The door on the ground?", &""],
	["club_054", "G", "That’s ours, yeah.", &"n"],
]

enum Stage { WAIT, CALL, HANG, IDLE, TALK, LEAVE, GONE }

var npc: GrayAlienNpc
var stage := Stage.WAIT
var talker: Dictionary = {}
var _t := 0.0                 # the level's clock
var _st := 0.0                # seconds in this stage
var _call: AudioStreamPlayer
var _bus := -1
var _lp: AudioEffectLowPassFilter
var _cue := 0
var _mood := &"s"
var _mood_t := 0.0            # seconds into the mood
var _phone_u := 1.0           # 1: the handset is at his ear, 0: on its hook
var _reach := 0.0             # his hand on the hung-up handset (Telling Marie)
var _has_tag := false
var _gest_t := 0.0            # the next hand put out (normal talking)
var _gest_u := -1.0           # through it (-1: none)
var _gest_side := 0.0
var _rng := RandomNumberGenerator.new()
var _w_l := 0.0               # how far each arm is on its target (0: its own idle swing)
var _w_r := 0.0
var _tl := Vector3.ZERO       # the arms' targets, body frame (x his left, y up, z forward)
var _tr := Vector3.ZERO
var _lean := 0.0              # spine forward (ashamed), negative: back (yelling)
var _nod := 0.0               # head down
var _talking := false
var _quiet_t := 0.0          # seconds since he last spoke in the talk
var _then := &""             # the mood the line in hand leaves him in once it has been said
var _then_line := -1
var _turn_back := false
var _walk_i := -1
var _solid: World.Solid = null
# the props
var _unit: Node3D
var _handset: MeshInstance3D
var _cord: Array[MeshInstance3D] = []
var _tag: Node3D
var _hs_xf := Transform3D.IDENTITY


func build(_level: Node3D) -> void:
	name = "PhoneGuy"
	_rng.seed = 23
	npc = GreenAlienBoston.make()
	npc.name = "PaulyOnThePhone"
	add_child(npc)
	npc.place(STAND.x, STAND.y, STAND.z, CALL_YAW)
	npc.view.post_hook = _pose
	_solid = Game.world.add({"kind": "disc", "cx": STAND.x, "cz": STAND.z, "r": 0.32, "top": 1.6, "tag": "npc", "no_cam": true})
	_build_phone()
	_build_tag()
	# the call's own bus: its level and how muffled it is follow the distance
	AudioServer.add_bus()
	_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_bus, &"PhoneGuyCall")
	AudioServer.set_bus_send(_bus, &"SFX")
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 400.0
	AudioServer.add_bus_effect(_bus, _lp)
	_call = AudioStreamPlayer.new()
	_call.name = "Call"
	_call.stream = load(DIR + "club_001.wav")
	_call.bus = &"PhoneGuyCall"
	_call.volume_db = -80.0
	add_child(_call)
	talker = Game.dialogue.add_talker({"id": "club9_phone_guy", "name": "PAULY", "x": STAND.x, "y": 0.0, "z": STAND.z, "yaw": TALK_YAW, "radius": 2.4,
		"actor": self, "voice": "", "lines": _lines, "wait": _busy, "active": func() -> bool: return stage >= Stage.CALL and stage <= Stage.IDLE,
		"on_start": func(_d: Dictionary) -> void: _engaged(), "on_end": func(_d: Dictionary) -> void: _done(),
		"shot": {"cam_dist": 3.0, "cam_y": 1.28, "look_y": 0.64, "look_side": 0.35}})


func _exit_tree() -> void:
	npc.view.post_hook = Callable()
	var i := AudioServer.get_bus_index(&"PhoneGuyCall")
	if i >= 0:
		AudioServer.remove_bus(i)


## Is the music to sit back while he can be heard? (ClubLevel lowers it)
func hush() -> float:
	if stage == Stage.TALK or (Game.dialogue.on and Game.dialogue.npc == talker):
		return 1.0
	if stage == Stage.CALL and Game.player != null:
		return clampf((HEAR - _dist()) / HEAR, 0.0, 1.0) * 0.6
	return 0.0


func _dist() -> float:
	return Vector2(Game.player.x - npc.R.x, Game.player.z - npc.R.z).length()


# ---------------------------------------------------------------- the talk (core/dialogue.gd)

func _lines() -> Array:
	var me := Dialogue.player_name()
	var out: Array = []
	for e: Array in TALK:
		var L := {"text": e[2], "clip": DIR + String(e[0]) + ".wav", "act": e[3]}
		if e.size() > 4:
			L.merge(e[4])
		if e[1] == "P":
			L["who"] = me
		out.append(L)
	return out


## the talk holds its first line while he is still on the call or hanging up
func _busy() -> bool:
	if stage == Stage.WAIT:
		_start_call()
	return stage == Stage.CALL or stage == Stage.HANG


func _engaged() -> void:
	if stage == Stage.WAIT:
		_start_call()


## Dialogue: a line begins
func on_line(L: Dictionary) -> void:
	if stage != Stage.TALK:
		_go(Stage.TALK)
		npc.turn_to(atan2(Game.player.x - npc.R.x, Game.player.z - npc.R.z), 0.7)
	var act: StringName = L.get("act", &"")
	if _then != &"":      # (the last line was skipped before its beat: what it leaves him doing still happens)
		_set_mood(_then)
	_then = L.get("then", &"")
	_then_line = Game.dialogue.line
	if act == &"take_tag":
		_has_tag = false      # (Prog picks it up)
		return
	if L.has("who") or act == &"":
		return      # Prog's line: he keeps the last one's feeling a moment, then listens
	_set_mood(act)
	_gest_t = _rng.randf_range(0.2, 0.7)
	if act == &"tag":
		_has_tag = true


func _set_mood(m: StringName) -> void:
	_mood = m
	_mood_t = 0.0
	if m == &"reach":      # a step to the phone, the receiver at his right hand
		npc.move_to(STAND.x - 0.2, STAND.z + 0.12, 0.9, func() -> void: npc.turn_to(atan2(CRADLE.x - npc.R.x, CRADLE.z - npc.R.z) + 0.6, 0.4))
	elif _reach > 0.0:
		_turn_back = true      # (he lets go of the receiver first, then turns back to Prog)


func set_talk(v: bool) -> void:
	_talking = v
	if stage == Stage.TALK:
		npc.set_talk(v)


func look_at_point(x: float, z: float) -> void:
	if stage == Stage.TALK and _mood != &"reach":
		npc.look_at_point(x, z)


func look_away() -> void:
	npc.look_away()


func mouth_world() -> Vector3:
	return npc.mouth_world()


func _done() -> void:
	Game.story_set(FLAG)
	_go(Stage.LEAVE)
	_mood = &"pockets"
	_mood_t = 0.0
	npc.look_away()


# ---------------------------------------------------------------- the frame

func _go(s: Stage) -> void:
	stage = s
	_st = 0.0


func _start_call() -> void:
	_go(Stage.CALL)
	_call.play()


func tick(time: float, dt: float) -> void:
	_t = time
	_st += dt
	_mood_t += dt
	var P := Game.player
	match stage:
		Stage.WAIT:
			if P != null and _dist() < START:
				_start_call()
		Stage.CALL:
			var at := _call.get_playback_position() if _call.playing else 999.0
			while _cue < CALL_CUES.size() - 1 and at >= CALL_CUES[_cue + 1]:
				_cue += 1
			if _mood != CALL_MOODS[_cue]:
				_mood = CALL_MOODS[_cue]
				_mood_t = 0.0
				var loud := _mood == &"a" or _mood == &"plead"
				npc.turn_to(CALL_YAW - (0.6 if loud else 0.0), 0.35 if loud else 0.8)      # yelling, he wheels round from the wall toward the hallway
			npc.set_talk(_speaking(at))
			if not _call.playing and _st > 1.0:
				npc.set_talk(false)
				_mood = &"s"
				_go(Stage.HANG)
		Stage.HANG:
			_phone_u = 1.0 - smoothstep(0.35, HANG_S, _st)
			if _st >= HANG_S + 0.4:
				_phone_u = 0.0
				_go(Stage.IDLE)
		Stage.IDLE:
			pass
		Stage.TALK:
			if _then != &"" and Game.dialogue.line == _then_line and Game.dialogue.done_t > 0.25:
				_set_mood(_then)
				_then = &""
			_reach = move_toward(_reach, 1.0 if _mood == &"reach" else 0.0, dt / (0.6 if _mood == &"reach" else 1.6))
			if _turn_back and _reach < 0.15:
				_turn_back = false
				npc.turn_to(atan2(Game.player.x - npc.R.x, Game.player.z - npc.R.z), 0.9)
		Stage.LEAVE:
			_reach = move_toward(_reach, 0.0, dt)
			if _walk_i < 0 and _st > 1.4:      # (a pat of the pockets for the keys, then off)
				_walk_i = 0
				_mood = &""
				_next_leg()
			if _solid != null:
				_solid.place(npc.R.x, npc.R.z)
	if stage == Stage.GONE:
		return
	_call_level()
	_act(dt)
	npc.update(time, dt)
	_props()


func _speaking(at: float) -> bool:
	var i := 0
	while i < CALL_SPEECH.size():
		if at >= CALL_SPEECH[i] and at < CALL_SPEECH[i + 1]:
			return true
		i += 2
	return false


func _next_leg() -> void:
	if _walk_i >= WAY_OUT.size():
		_go(Stage.GONE)
		npc.set_shown(false)
		if _solid != null:
			Game.world.remove(_solid)
			_solid = null
		return
	var w := WAY_OUT[_walk_i]
	_walk_i += 1
	npc.move_to(w.x, w.y, 1.35, _next_leg)


## The call's loudness and muffle from where Prog is: silent past HEAR, a dull thump at the hallway's mouth, clear beside him. From the main room (out of the hallway) it is duller still.
func _call_level() -> void:
	if not _call.playing or Game.player == null:
		return
	var d := _dist()
	var k := clampf((HEAR - d) / (HEAR - 1.8), 0.0, 1.0)
	var hall := Game.player.x > 12.4
	var g := pow(k, 1.6) * (1.0 if hall else 0.55)
	_call.volume_db = linear_to_db(maxf(g * 1.35, 1e-4))
	_lp.cutoff_hz = 320.0 * pow(18000.0 / 320.0, k * (1.0 if hall else 0.7))


# ---------------------------------------------------------------- acting

## Where his arms go this frame (body frame) and how far, how he holds his back and head: from the stage, the mood and the gestures of normal talk.
func _act(dt: float) -> void:
	var tl := Vector3(0.3, 0.62, 0.12)
	var tr := Vector3(-0.3, 0.62, 0.12)
	var wl := 0.0
	var wr := 0.0
	var lean := 0.0
	var nod := 0.0
	var on_phone := stage == Stage.CALL or stage == Stage.HANG or stage == Stage.WAIT
	var talking := _talking if stage == Stage.TALK else (stage == Stage.CALL)
	var m := _mood
	var e := minf(1.0, _mood_t / 0.35)
	if on_phone:
		lean = 0.1      # hunched into the phone
		nod = 0.06
		wl = 1.0      # the free hand flat on the wall beside him
		tl = _to_body(Vector3(STAND.x + 0.32, 1.22, 12.17))
	match m:
		&"a":
			var sh := sin(_t * 11.0) * 0.025 * (1.0 if talking else 0.3)
			tl = Vector3(0.36, 1.3 - sh, 0.28) if not on_phone else Vector3(0.26, 1.46 - sh, 0.12)      # (on the phone the free hand goes up over his head: the hallway sees it)
			wl = e
			if not on_phone:
				tr = Vector3(-0.36, 1.3 + sh, 0.28)
				wr = e
			lean = -0.12
			nod = -0.2
		&"s":
			lean += (0.1 if on_phone else 0.24) * e
			nod += 0.42 * e
			if not on_phone:
				var wring := sin(_t * 3.0) * 0.02
				tr = Vector3(-0.07, 0.6 + wring, 0.38)
				tl = Vector3(0.07, 0.6 - wring, 0.38)
				wr = e
				wl = e
		&"plead":
			var b := sin(_t * 4.0) * 0.02
			tl = Vector3(0.3, 0.86 - b, 0.4)
			wl = e
			if not on_phone:
				tr = Vector3(-0.3, 0.86 + b, 0.4)
				wr = e
			lean = 0.08
		&"tag":      # (in his left hand: the rig's palm joint is that one's)
			tl = Vector3(0.16, 1.04, 0.4)
			wl = e
		&"reach":
			tr = _to_body(CRADLE + Vector3(0.04, 0.0, -0.05))
			wr = _reach
			nod = 0.12
		&"pockets":
			var pat := absf(sin(_t * 7.0)) * 0.05
			tr = Vector3(-0.33, 0.6 + pat, 0.06)
			tl = Vector3(0.33, 0.6 + absf(sin(_t * 7.0 + 1.3)) * 0.05, 0.06)
			wr = e
			wl = e
			nod = 0.3
	if m == &"n" and talking:      # a hand put out now and then to make his point (on the phone: the free one, off the wall)
		_gest_t -= dt
		if _gest_u < 0.0 and _gest_t <= 0.0:
			_gest_u = 0.0
			_gest_side = 1.0 if (on_phone or _rng.randf() < 0.3) else -1.0      # (on the phone: the left, the right holds it)
	if _gest_u >= 0.0:
		_gest_u += dt / 1.15
		var g := sin(PI * minf(1.0, _gest_u))
		var out := Vector3(_gest_side * 0.31, 0.88 + 0.04 * sin(_gest_u * 9.0), 0.4)
		if _gest_side < 0.0:
			tr = tr.lerp(out, g)
			wr = maxf(wr, g)
		else:
			tl = tl.lerp(out, g)
			wl = maxf(wl, g)
		if _gest_u >= 1.0:
			_gest_u = -1.0
			_gest_t = _rng.randf_range(0.6, 2.2)
	_quiet_t = 0.0 if talking else _quiet_t + dt
	if stage == Stage.TALK and _quiet_t > 0.7 and m != &"reach" and m != &"tag" and m != &"s":
		wl = 0.0      # listening: his arms come down (shame stays put)
		wr = 0.0
	if _has_tag and wl < 0.5:      # the entry tag in his hand: held in front of him
		tl = Vector3(0.2, 0.78, 0.36)
		wl = 0.7
	if stage == Stage.LEAVE and _walk_i >= 0:
		wl = 0.0
		wr = 0.0
		lean = 0.05
	var k := 1.0 - exp(-dt * 8.0)
	_tl = _tl.lerp(tl, k) if _w_l > 0.02 else tl
	_tr = _tr.lerp(tr, k) if _w_r > 0.02 else tr
	_w_l = lerpf(_w_l, wl, k)
	_w_r = lerpf(_w_r, wr, k)
	_lean = lerpf(_lean, lean, k * 0.7)
	_nod = lerpf(_nod, nod, k * 0.7)


func _body() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, npc.R.yaw), Vector3(npc.R.x, npc.R.y, npc.R.z))


func _to_body(w: Vector3) -> Vector3:
	return _body().affine_inverse() * w


## AlienView's post hook: the view has posed and composed him; lean and nod, then put the arms where _act says (two-bone IK, blended), the phone arm on the handset.
func _pose() -> void:
	var v := npc.view
	var q := v.pose
	var root := q.world[v.j_fall] * Transform3D(q.rot[v.j_fall].scaled_local(q.scl[v.j_fall]), q.pos[v.j_fall]).affine_inverse()
	q.rot[v.j_spine] = q.rot[v.j_spine] * Basis.from_euler(Vector3(_lean, 0.0, 0.0))
	q.rot[v.j_head] = q.rot[v.j_head] * Basis.from_euler(Vector3(_nod - _lean * 0.4, 0.0, 0.0))
	q.compose(root)
	var B := _body()
	# the handset: at his ear, or on its hook, or between
	var hw := q.world[v.j_head]
	var hb := hw.basis.orthonormalized()
	var ear := hw * Vector3(-0.2, 0.18, 0.0)      # (his right: the model's -x; the big head is round, so the handset rides out along his cheek)
	var mouth := hw * Vector3(-0.18, 0.05, 0.1)
	var ax := (ear - mouth).normalized()
	var at_ear := Transform3D(Basis.looking_at(-hb.x, ax).orthonormalized(), (ear + mouth) * 0.5 - hb.x * 0.07)
	var hung := Transform3D(Basis.IDENTITY, CRADLE)
	var u := smoothstep(0.0, 1.0, _phone_u)
	_hs_xf = hung.interpolate_with(at_ear, u)
	var held := u > 0.0 or _reach > 0.0
	if held:
		var grip := _hs_xf.origin - _hs_xf.basis.z * 0.04 - _hs_xf.basis.y * 0.01      # (its back, away from his head)
		var w := 1.0 if u > 0.0 else _reach
		_ik(v.j_sh_r, v.j_el_r, v.j_hd_r, grip - _hs_xf.basis.y * 0.045, B.basis * Vector3(-1.0, -0.6, -0.3), w)      # (the wrist just under its middle: the hand closes round it)
	elif _w_r > 0.01:
		_ik(v.j_sh_r, v.j_el_r, v.j_hd_r, B * _tr, B.basis * Vector3(-1.0, -1.0, -0.2), _w_r)
	if _w_l > 0.01:
		_ik(v.j_sh_l, v.j_el_l, v.j_hd_l, B * _tl, B.basis * Vector3(1.0, -1.0, -0.2), _w_l)


## Two-bone IK on an arm: shoulder and elbow turned (by the least rotation from where the view put them) so the wrist reaches `target`, the elbow toward `pole`; blended in by w.
func _ik(sh: int, el: int, hd: int, target: Vector3, pole: Vector3, w: float) -> void:
	var v := npc.view
	var q := v.pose
	var par: Transform3D = q.world[v.model.parent[sh]]
	var ws: Transform3D = q.world[sh]
	var we: Transform3D = q.world[el]
	var wh: Transform3D = q.world[hd]
	var S := ws.origin
	var l1 := S.distance_to(we.origin)
	var l2 := we.origin.distance_to(wh.origin)
	var d := target - S
	var dl := clampf(d.length(), 0.05, (l1 + l2) * 0.995)
	var dn := d.normalized()
	var a := (l1 * l1 - l2 * l2 + dl * dl) / (2.0 * dl)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var pn := pole - dn * pole.dot(dn)
	pn = pn.normalized() if pn.length() > 1e-4 else Vector3.DOWN
	var E := S + dn * a + pn * h
	var T := S + dn * dl
	var b1 := Basis(Quaternion((we.origin - S).normalized(), (E - S).normalized())) * ws.basis.orthonormalized()
	q.rot[sh] = q.rot[sh].slerp((par.basis.orthonormalized().inverse() * b1).orthonormalized(), w)
	ws = par * Transform3D(q.rot[sh].scaled_local(q.scl[sh]), q.pos[sh])
	we = ws * Transform3D(q.rot[el].scaled_local(q.scl[el]), q.pos[el])
	wh = we * Transform3D(q.rot[hd].scaled_local(q.scl[hd]), q.pos[hd])
	var b2 := Basis(Quaternion((wh.origin - we.origin).normalized(), (T - we.origin).normalized())) * we.basis.orthonormalized()
	q.rot[el] = q.rot[el].slerp((ws.basis.orthonormalized().inverse() * b2).orthonormalized(), w)
	ws = par * Transform3D(q.rot[sh].scaled_local(q.scl[sh]), q.pos[sh])
	q.world[sh] = ws
	q.world[el] = ws * Transform3D(q.rot[el].scaled_local(q.scl[el]), q.pos[el])


# ---------------------------------------------------------------- the props

static func _m(hex: int, rough: float, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((hex << 8) | 0xff)
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = emit
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A beaten public payphone: a steel box on the wall, a little green readout, a keypad, a coin slot, the handset hung on its side on a steel hook, and a cord.
func _build_phone() -> void:
	var steel := _m(0x3b3e46, 0.42, 0.75)
	var dark := _m(0x111216, 0.7, 0.2)
	var key := _m(0x8b8f99, 0.35, 0.9)
	var lcd := _m(0x3cff7a, 0.4, 0.0, 1.4)
	_unit = Node3D.new()
	_unit.name = "Payphone"
	add_child(_unit)
	_unit.position = UNIT
	_box(_unit, Vector3(0.21, 0.36, 0.09), Vector3.ZERO, steel)
	_box(_unit, Vector3(0.17, 0.05, 0.01), Vector3(0.0, 0.12, -0.046), dark)
	_box(_unit, Vector3(0.12, 0.022, 0.004), Vector3(0.0, 0.12, -0.052), lcd)
	_box(_unit, Vector3(0.05, 0.008, 0.01), Vector3(0.05, 0.075, -0.046), dark)      # the coin slot
	for r in 4:
		for c in 3:
			_box(_unit, Vector3(0.028, 0.022, 0.012), Vector3(-0.045 + c * 0.04, 0.03 - r * 0.034, -0.05), key)
	_box(_unit, Vector3(0.025, 0.05, 0.03), Vector3(0.115, 0.07, -0.02), key)      # the hook
	_box(_unit, Vector3(0.14, 0.02, 0.06), Vector3(0.0, -0.17, -0.02), steel)        # the little shelf
	var hs := BoxMesh.new()
	hs.size = Vector3(0.045, 0.21, 0.05)
	_handset = MeshInstance3D.new()
	_handset.name = "Handset"
	_handset.mesh = hs
	_handset.material_override = _m(0x16171b, 0.5, 0.3)
	_handset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_handset)
	for y: float in [0.085, -0.085]:      # the ear and mouth cups
		var cup := CylinderMesh.new()
		cup.top_radius = 0.034
		cup.bottom_radius = 0.03
		cup.height = 0.03
		cup.radial_segments = 10
		var c := MeshInstance3D.new()
		c.mesh = cup
		c.material_override = _handset.material_override
		c.position = Vector3(0.0, y, 0.025)
		c.rotation.x = -PI / 2.0
		_handset.add_child(c)
	var seg := CylinderMesh.new()
	seg.top_radius = 0.007
	seg.bottom_radius = 0.007
	seg.height = 1.0
	seg.radial_segments = 5
	var cord_m := _m(0x0e0e10, 0.6)
	for i in CORD_SEGS:
		var c := MeshInstance3D.new()
		c.mesh = seg
		c.material_override = cord_m
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c)
		_cord.append(c)


## The bent entry tag for the final heat (club_014: "Still got this, though").
func _build_tag() -> void:
	_tag = Node3D.new()
	_tag.name = "EntryTag"
	add_child(_tag)
	var card := _m(0xe0782c, 0.6)
	var ink := _m(0x1c1410, 0.8)
	var a := _box(_tag, Vector3(0.07, 0.055, 0.004), Vector3(0.0, 0.028, 0.0), card)
	a.rotation.x = 0.25      # (bent)
	_box(_tag, Vector3(0.07, 0.05, 0.004), Vector3(0.0, -0.024, 0.0), card)
	_box(_tag, Vector3(0.05, 0.012, 0.005), Vector3(0.0, -0.02, 0.0), ink)
	_box(_tag, Vector3(0.012, 0.012, 0.006), Vector3(0.0, 0.045, 0.006), ink)      # its punched hole
	_tag.visible = false


func _props() -> void:
	_handset.global_transform = _hs_xf
	var a := CORD_FROM
	var b := _hs_xf * Vector3(0.0, -0.1, 0.0)
	var sag := 0.08 + 0.25 * maxf(0.0, 0.8 - a.distance_to(b))
	var prev := a
	for i in CORD_SEGS:
		var u := float(i + 1) / CORD_SEGS
		var p := a.lerp(b, u) + Vector3(0.0, -sag * 4.0 * u * (1.0 - u), 0.0) + Vector3(0.0, 0.0, -0.01) * sin(u * PI)
		var c := _cord[i]
		var dv := p - prev
		var len := dv.length()
		if len > 1e-4:
			var y := dv / len
			var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
			c.global_transform = Transform3D(Basis(x, y, x.cross(y)).scaled_local(Vector3(1.0, len, 1.0)), (prev + p) * 0.5)
		prev = p
	_tag.visible = _has_tag and npc.is_shown()
	if _tag.visible:
		var v := npc.view
		var pw: Transform3D = v.pose.world[v.j_palm]
		_tag.global_transform = Transform3D(pw.basis.orthonormalized(), pw.origin + pw.basis.orthonormalized() * Vector3(-0.02, 0.0, 0.03))
