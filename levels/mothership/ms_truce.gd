class_name MsTruce
extends RefCounted
## THE TRUCE, a cutscene (JS levels/mothership/truce.js): after "Enough." the Godmother and Prog / Tommy settle it, in the live penthouse (she keeps animating). It is a list of lines, each with its camera shot: a line moves on by itself once it has had time to be read, or on X / Enter / Space (the first press finishes the typing). Short on purpose: the joke is how little anybody says.

const NAME := "THE GODMOTHER"

var L: MothershipLevel
var gm: MsGodmother
var PF: float
var on := false
var play := false
var camera := View.Shot.new()
var i := 0
var t_ := 0.0
var lt := 0.0
var shown := 0
var voiced := 0
var syl := 0
var reach := 0.0
var look_up := 0.0
var shake := false
var roofed := false
var cut := true
var cp := Vector3.ZERO
var cl := Vector3.ZERO
var P0: Player = null
var mark := Vector2(0.0, 7.4)
var shake_at: Variant = null
var lines: Array = []
var _pose_an: Variant = null
var _i_arm := Animator.KEYS.find(&"upper_armR")
var _i_fore := Animator.KEYS.find(&"forearmR")
var _i_head := Animator.KEYS.find(&"head")


func _init(level: MothershipLevel, p_gm: MsGodmother, p_pf: float) -> void:
	L = level
	gm = p_gm
	PF = p_pf


func _me() -> String:
	return "TOMMY" if L.char_id() == "tommy" else "PROG"


## [who, text, shot, extra]. who: gm or me. shot: where the camera is for the line.
func _script() -> Array:
	var alias_ := "Little Vito" if L.char_id() == "tommy" else "Uncle Sal"
	return [
		["gm", "Four hundred years this family's been in business. You know how many people ever made it up here?", "wide", {}],
		["me", "...Counting me?", "herSide", {}],
		["gm", "Counting you. One.", "lowHer", {}],
		["gm", "Mittens. Manners.", "cat", {"puff": 1}],
		["gm", "Here's how it goes. The greens' neighborhood is off the menu. Nobody touches it.", "otsMe", {}],
		["me", "And what do you get?", "herSide", {}],
		["gm", "I get you never coming back. And somebody pays for the cake.", "lowHer", {}],
		["me", "...Put it on " + alias_ + ".", "herSide", {}],
		["gm", "We shake on it.", "hands", {"offer": 1}],
		["me", "...Your hand's wet.", "hands", {"offer": 1, "shake": 1}],
		["gm", "It's tea.", "hands", {"offer": 1, "shake": 1}],
		["gm", "Now get off my saucer. ...Use the roof this time.", "finale", {"roof": 1}],
	]


# ---- voice + subtitles (the shared box)
func _voice(text: String, from: int, to: int) -> void:
	for k in range(from, to):
		var ch := text[k]
		if ".!?,;:".contains(ch):
			if syl > 0 and k > 0:
				_syllable(text, k - 1, ".!?".contains(ch))
			syl = 0
			continue
		if not (ch.to_lower() >= "a" and ch.to_lower() <= "z") and not (ch >= "0" and ch <= "9"):
			continue
		syl += 1
		if syl < 2:
			continue
		syl = 0
		_syllable(text, k, false)
	voiced = to


func _syllable(text: String, k: int, last: bool) -> void:
	var h := (text.unicode_at(maxi(0, k - 2)) * 31 + text.unicode_at(maxi(0, k - 1)) * 17 + text.unicode_at(k) * 7 + k * 13) & 0x7fffffff
	var v := gm.head.global_position
	if Game.sfx != null:
		Game.sfx.play_at("alienSyl", v.x, v.y - 0.6, v.z, {"range": 60.0, "ref": 6.0, "h": h, "pitch": 0.42, "last": last})


func _draw(l: Array) -> void:
	var who: String = NAME if l[0] == "gm" else _me()
	var txt: String = l[1]
	var done := shown >= txt.length()
	var hint := ("X  NEXT" if i < lines.size() - 1 else "X  CLOSE") if done else "X  SKIP"
	Game.ui.dialog.set_content(who, txt.substr(0, shown), hint)


# ---- the shots (she sits north at (0, 14) facing south; you stand at the mark). The subtitle box covers the lower part of the frame: every shot looks a little BELOW its subject, so the faces sit in the clear upper half
func _shot(nm: String, P: Player, t: float) -> Array:
	var gx := gm.x
	var gz := gm.z
	var drift := minf(1.0, t / 6.0)
	var H := gm.head.global_position
	match nm:
		"wide":      # side-on: you, small, and all of her
			return [Vector3(11.5 - drift * 1.5, PF + 2.4, P.z - 3.5), Vector3(lerpf(P.x, gx, 0.35), PF + 1.6, lerpf(P.z, gz, 0.4))]
		"herSide":      # from up by her knee, down at you
			return [Vector3(P.x + 2.4, PF + 4.6, P.z + 3.6), Vector3(P.x, PF + 0.3, P.z - 0.4)]
		"lowHer":      # past your shoulder, low, up at her face
			return [Vector3(P.x + 1.1, PF + 1.4, P.z - 1.7 + drift * 0.5), Vector3(H.x, H.y - 1.6, H.z)]
		"otsMe":
			return [Vector3(P.x - 1.3, PF + 2.0, P.z - 2.6), Vector3(H.x, H.y - 1.8, H.z)]
		"cat":
			var V := gm.cat.global_position
			return [Vector3(V.x + 2.4, V.y + 1.1, V.z - 4.4), Vector3(V.x, V.y - 0.7, V.z)]
		"hands":
			var V := gm.arm_r.hand.global_position
			return [Vector3(V.x + 3.0, PF + 1.7, V.z - 3.1), Vector3(lerpf(V.x, P.x, 0.5), PF + 0.75, lerpf(V.z, P.z, 0.5))]
	return [Vector3(0.0, PF + 7.5 + drift * 2.0, P.z - 11.0), Vector3(0.0, PF + 3.5 + drift * 3.0, gz - 2.0)]      # the finale: wide and rising, the petals opening


# ---- your body: walk up to her hand, take a finger, shake it
func _hook(a: Variant) -> void:
	if not on:
		return
	var sh := sin(t_ * 13.0) * 0.16 if shake else 0.0
	_put(a, _i_arm, Vector3(-1.25 + sh, 0.05, -0.12), reach)
	_put(a, _i_fore, Vector3(-0.35 - sh * 0.5, 0.0, 0.0), reach)
	_put(a, _i_head, Vector3(-0.38, 0.0, 0.0), minf(1.0, look_up))      # arm out, chin up (she is six metres tall)


func _put(a: Variant, k: int, v: Vector3, m: float) -> void:
	if k < 0 or m <= 0.0:
		return
	a.pose[k] = (a.pose[k] as Vector3).lerp(v, m)


func pose_player(an: Variant) -> void:
	if on and _pose_an != an:
		_pose_an = an
		an.pose_hook = _hook


# ---- control
func start(P: Player) -> bool:
	if on or P == null:
		return false
	lines = _script()
	P0 = P
	on = true
	i = 0
	t_ = 0.0
	lt = 0.0
	shown = 0
	voiced = 0
	syl = 0
	reach = 0.0
	look_up = 1.0
	shake = false
	roofed = false
	cut = true
	# cut straight to the two of you: you on your mark in front of her, facing her
	P.x = mark.x
	P.z = mark.y
	P.y = PF
	P.vx = 0.0
	P.vz = 0.0
	P.vy = 0.0
	P.yaw = atan2(gm.x - P.x, gm.z - P.z)
	shake_at = null
	gm.look_x = P.x
	gm.look_z = P.z
	Game.ui.dialog.set_bars(true, true)
	Game.ui.dialog.show_box(true)
	Game.hud.set_suppressed(true)
	return true


func _next() -> void:
	if i >= lines.size():
		return
	var l: Array = lines[i]
	if shown < String(l[1]).length():
		shown = String(l[1]).length()
		voiced = shown
		return
	_advance()


func _advance() -> void:
	i += 1
	lt = 0.0
	shown = 0
	voiced = 0
	syl = 0
	cut = true
	if i >= lines.size():
		finish()


func finish(silent: bool = false) -> void:
	if not on:
		return
	on = false
	if _pose_an != null:
		_pose_an.pose_hook = Callable()
		_pose_an = null
	Game.ui.dialog.show_box(false)
	Game.ui.dialog.set_bars(false)
	Game.hud.set_suppressed(false)
	gm.cine_puff = 0
	gm.talk = false
	if P0 != null:
		P0.vx = 0.0
		P0.vz = 0.0
		Game.rig.snap_to(P0)
	if not silent:
		L.act2.truce_done()


func abort() -> void:
	finish(true)


func update(dt: float, P: Player) -> void:
	if not on or P == null:
		return
	t_ += dt
	lt += dt
	if i >= lines.size():
		finish()
		return
	if Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_KP_ENTER) or Inp.key_hit(KEY_SPACE) or Inp.key_hit(KEY_X) or (Inp.using_pad and Inp.btn(&"attack").pressed):
		_next()
		if not on:
			return
		if i >= lines.size():
			return
	var l: Array = lines[i]
	var ex: Dictionary = l[3]
	var txt: String = l[1]
	var n := mini(txt.length(), floori(lt * 32.0))
	if n > shown:      # type the line; it moves on by itself once it has been up long enough to read
		shown = n
	if l[0] == "gm" and shown > voiced:
		_voice(txt, voiced, shown)
	gm.talk = l[0] == "gm" and shown < txt.length()
	gm.cine_puff = 1 if ex.has("puff") else 0
	gm.shake_ = ex.has("offer")
	if shown >= txt.length() and lt > txt.length() / 32.0 + 1.1 + txt.length() * 0.035:
		_advance()
	if not on or i >= lines.size():
		return
	l = lines[i]
	_draw(l)
	if ex.has("roof") and not roofed:
		roofed = true
		L.act2.open_roof()
	# you: hold the mark, then walk up to her offered hand and take a finger
	P.invuln = maxf(P.invuln, 1.0)
	P.dead = false
	P.grounded = true
	P.vy = 0.0
	P.y = PF
	if ex.has("offer"):
		if shake_at == null:
			var V := gm.arm_r.hand.global_position
			shake_at = Vector2(V.x, V.z - 0.75)
		var at: Vector2 = shake_at
		var dx := at.x - P.x
		var dz := at.y - P.z
		var d := U.hyp(dx, dz)
		var st := minf(d, 2.2 * dt)
		if d > 0.05:
			P.x += dx / d * st
			P.z += dz / d * st
			P.vx = dx / d * 2.2
			P.vz = dz / d * 2.2
		else:
			P.vx = 0.0
			P.vz = 0.0
		P.yaw = atan2(gm.x - P.x, gm.z - P.z)
		reach = minf(1.0, reach + dt * (2.0 if d < 0.6 else 0.0))
		shake = ex.has("shake")
	else:
		P.vx = 0.0
		P.vz = 0.0
		reach = maxf(0.0, reach - dt * 2.0)
		shake = false
	gm.look_x = P.x
	gm.look_z = P.z
	# the camera: a cut on every new shot, then a slow drift
	var s := _shot(l[2], P, lt)
	if cut and (i == 0 or l[2] != lines[i - 1][2]):
		cp = s[0]
		cl = s[1]
	else:
		var k := minf(1.0, dt * 2.5)
		cp += ((s[0] as Vector3) - cp) * k
		cl += ((s[1] as Vector3) - cl) * k
	cut = false
	camera.pos = cp
	camera.look = cl
