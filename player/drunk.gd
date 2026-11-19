class_name Drunk
extends RefCounted
## Prog's drinks (CLUB 9's bar, levels/club/club_bar.gd): how drunk he is and what it does to him, in any level, until it wears off.
## One drink: the world a little more colourful. Two: more colour and a soft blur. Three: he stumbles in his low-health slouch, the picture smears behind every move and the
## camera lurches with him. Four: all of it harder. Five: everything at full, and 20-30 seconds later he goes down face first, and wakes face down in the gutter by the
## Armchair General's burger stand on the home strip, and gets himself up.
## Game owns one for the session: tick() before the player (the stumble goes into the stick, the pass-out holds the controls), pose() after the animator (the drink in his hand,
## the fall, lying there, getting up). What it shows goes to View.sway and PostFx.drunk / drunk2.

const SOBER_EVERY := 90.0           # one drink wears off this often (s)
const MAX := 5
const KICK_DELAY := 1.0             # from the glass coming down to feeling it (s)
# per whole drink: saturation, blur (px at 1080p), ghost (at 60 fps), double vision, wobble, tunnel, hue drift, camera sway (rad), stumble, slouch
const STEPS := [
	[1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[1.32, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	[1.55, 1.3, 0.38, 0.0018, 0.0014, 0.08, 0.06, 0.014, 0.0, 0.0],
	[1.75, 2.1, 0.64, 0.0045, 0.0042, 0.18, 0.13, 0.04, 0.45, 0.45],
	[1.95, 3.1, 0.76, 0.0085, 0.0072, 0.28, 0.22, 0.065, 0.72, 1.0],
	[2.25, 4.6, 0.85, 0.0135, 0.0115, 0.42, 0.34, 0.095, 1.0, 1.0],
]

var drinks := 0                     # drinks in him (0..5)
var level := 0.0                    # what the effects show: eases toward drinks (plus a hangover after waking)
var hangover := 0.0
var state := &""                    # "", &"drinking", &"falling", &"out", &"waking"
var t := 0.0
var _st := 0.0                      # seconds in the state
var _sober := 0.0
var _out_at := -1.0                 # when five drinks put him down
var _drink: Dictionary = {}         # the one in his hand
var _kick: Dictionary = {}          # the one he has just downed, not yet felt
var _kick_at := -1.0                # when it hits (t)
var _glass: Node3D = null
var _lurch := Vector2.ZERO
var _lurch_t := 0.0
var _lurch_next := 3.0
var _fall := 0.0                    # 0 standing .. 1 face down
var _head := -2                     # Prog's head bone (found once)
var _rng := RandomNumberGenerator.new()


## A drink bought at the bar: he takes it in his left hand and downs it. `d` is the bar's catalogue entry ({name, color, strength}).
func drink(d: Dictionary) -> void:
	if state != &"":
		return
	_drink = d
	_go(&"drinking")


func busy() -> bool:
	return state != &"" or not _kick.is_empty()


## Back to sober at once (death, a new game).
func reset() -> void:
	drinks = 0
	level = 0.0
	hangover = 0.0
	_out_at = -1.0
	_fall = 0.0
	_kick = {}
	if state == &"drinking" or state == &"falling" or state == &"out" or state == &"waking":
		state = &""
	_drop_glass()
	_show(0.0)


func _go(s: StringName) -> void:
	state = s
	_st = 0.0


## Before the player: the stumble in the stick, the controls held while he is down, the clock that puts him down.
func tick(dt: float) -> void:
	var P := Game.player
	if P == null:
		return
	if P.dead:
		if drinks > 0 or level > 0.0:
			reset()
		return
	t += dt
	_st += dt
	if state == &"":
		if drinks > 0:
			_sober += dt
			if _sober >= SOBER_EVERY:
				_sober = 0.0
				drinks -= 1
		hangover = maxf(0.0, hangover - dt / 25.0)
		if drinks >= MAX:
			if _out_at < 0.0:
				_out_at = t + _rng.randf_range(20.0, 30.0)
			elif t >= _out_at and not Game.doors.travelling and Game.dialogue != null and not Game.dialogue.on:
				_go(&"falling")
				Game.sfx.play("playerHurt", {"k": 0.35})
		else:
			_out_at = -1.0
	var goal := float(drinks) + hangover
	level = move_toward(level, goal, dt * (0.6 if goal > level else 0.12))
	match state:
		&"drinking":
			if _st >= 1.9:      # the glass comes down; the drink hits a moment later (was counted mid-swallow, at 1.25 s: it read as felt before he had drunk it)
				_kick = _drink
				_kick_at = t + KICK_DELAY
				_drink = {}
				_drop_glass()
				_go(&"")
		&"falling", &"out", &"waking":
			P.stun_t = maxf(P.stun_t, 0.15)      # down: no moving, jumping, shooting or powers
			P.vx = 0.0
			P.vz = 0.0
			_fall_tick(dt)
	if not _kick.is_empty() and t >= _kick_at and state == &"":
		drinks = mini(MAX, maxi(0, drinks + int(_kick.get("strength", 1))))
		_sober = 0.0
		if int(_kick.get("strength", 1)) > 0:
			level = maxf(level, minf(float(drinks), level + 0.6))      # it hits all at once, then eases the rest of the way
		_kick = {}
	_stumble(dt)
	_show(dt)


## The stumble, from three drinks on: the stick wanders, and every few seconds a lurch shoves him a step or two (even standing still, from four).
func _stumble(dt: float) -> void:
	var k := _step(8)
	if state != &"" and state != &"drinking":
		Inp.move.x = 0.0
		Inp.move.y = 0.0
		Inp.move.mag = 0.0
		return
	if k <= 0.0:
		return
	_lurch_next -= dt
	if _lurch_next <= 0.0:
		_lurch_next = _rng.randf_range(1.6, 4.6) / (0.6 + k)
		_lurch_t = _rng.randf_range(0.3, 0.6)
		var a := _rng.randf() * TAU
		_lurch = Vector2(cos(a), sin(a)) * _rng.randf_range(0.55, 1.0) * k
	_lurch_t = maxf(0.0, _lurch_t - dt)
	var mv := Vector2(Inp.move.x, Inp.move.y)
	var wander := k * (0.55 * sin(t * 0.9) + 0.35 * sin(t * 2.3 + 1.0) + 0.15 * sin(t * 5.1))
	mv = mv.rotated(wander)
	if _lurch_t > 0.0 and (mv.length() > 0.1 or k > 0.6):
		mv += _lurch * sin(PI * _lurch_t / 0.6)
	mv = mv.limit_length(1.0)
	Inp.move.x = mv.x
	Inp.move.y = mv.y
	Inp.move.mag = mv.length()


## The table at the current level, column c.
func _step(c: int) -> float:
	var l := clampf(level, 0.0, float(MAX))
	var i := mini(int(floorf(l)), MAX - 1)
	return lerpf(float(STEPS[i][c]), float(STEPS[i + 1][c]), l - i)


## What it looks like: the post pass, the camera's lurch, his slouch.
func _show(dt: float) -> void:
	var v: View = Game.view
	if v == null or v.post == null:
		return
	var l := level
	var out_k := 0.0              # going down / coming round pushes it all to the top
	match state:
		&"falling":
			out_k = clampf(_st / 1.5, 0.0, 1.0)
		&"out":
			out_k = 1.0
		&"waking":
			out_k = clampf(1.0 - _st / 4.5, 0.0, 1.0)
	if l <= 0.001 and out_k <= 0.0:
		v.post.drunk = Vector4.ZERO
		v.post.drunk2 = Vector4(0.0, 1.0, 0.0, 0.0)
		v.sway = Vector3.ZERO
		v.sway_pos = Vector3.ZERO
		if Game.animator != null:
			Game.animator.drunk_fat = 0.0
		return
	var m := func(c: int) -> float: return lerpf(_step(c), float(STEPS[MAX][c]), out_k)
	v.post.drunk = Vector4(m.call(2), m.call(1), m.call(3), t)
	v.post.drunk2 = Vector4(m.call(4), m.call(0), minf(0.95, m.call(5) + 0.5 * out_k), m.call(6))
	var s: float = m.call(7) * (1.0 - out_k * 0.6)
	var lr := _lurch.x * sin(PI * _lurch_t / 0.6) if _lurch_t > 0.0 else 0.0
	v.sway = Vector3(0.45 * s * sin(t * 0.83 + 0.4), 0.3 * s * sin(t * 0.51), s * (sin(t * 0.62) + 0.5 * sin(t * 1.37 + 2.0)) + 0.06 * lr)
	v.sway_pos = Vector3(0.9 * s * sin(t * 0.7), 0.55 * s * sin(t * 1.1 + 1.0), 0.0)
	if Game.animator != null:
		Game.animator.drunk_fat = maxf(m.call(9), out_k)


# ---- the fall, lying there, getting up --------------------------------------------------------------------------------------------------------------------------

func _fall_tick(_dt: float) -> void:
	match state:
		&"falling":      # he sways, his knees go, and he pitches forward onto his face
			if _st < 1.3:
				_fall = 0.0
			else:
				var u := clampf((_st - 1.3) / 0.55, 0.0, 1.0)
				_fall = u * u
				if u >= 1.0 and _st - 1.3 - 0.55 < 0.05:
					Game.sfx.play("land", {"k": 1.2})
					if Game.fx != null:
						Game.fx.shake = maxf(Game.fx.shake, 0.6)
			if _st >= 2.0 and not Game.doors.travelling:
				_go(&"out")
				_go_home()
		&"out":
			_fall = 1.0
		&"waking":       # face down a while, then he pushes up onto his hands, gets a knee under him and stands, swaying
			if _st < 2.2:
				_fall = 1.0
			elif _st < 3.2:
				_fall = lerpf(1.0, 0.62, Gait.sstep(0.0, 1.0, (_st - 2.2) / 1.0))
			elif _st < 3.8:
				_fall = 0.62 + 0.04 * sin((_st - 3.2) * 9.0)
			else:
				_fall = lerpf(0.62, 0.0, Gait.sstep(0.0, 1.0, (_st - 3.8) / 1.2))
			if _st >= 5.0:
				_fall = 0.0
				hangover = 1.6
				level = maxf(level, 1.6)
				_go(&"")


## Black, then the home strip: the door system takes him there (the screen is already dark), and he comes round where he lands.
func _go_home() -> void:
	drinks = 0
	_out_at = -1.0
	var tree := Game.get_tree()
	var before := func() -> void:
		Game.ui.set_fade(true)
		await tree.create_timer(1.6, true).timeout
	await Game.doors.travel({"id": "blackout", "to": "hub", "spawn_at": "passout", "loading": "...", "before": before})
	if Game.level != null and Game.level.id == "hub":
		_go(&"waking")
		Game.rig.snap_to(Game.player)
	else:
		_go(&"")
		_fall = 0.0


## After the animator: the glass in his left hand on the way to his mouth, and the body tipped onto its face while he is down.
func pose(an: Animator, P: Player) -> void:
	if an == null or P.dead:
		return
	if state == &"drinking":
		_drink_pose(an)
	if _fall > 0.0:
		var k := _fall
		an.actor.rotation = Vector3(1.5 * k, P.yaw, 0.0)
		an.actor.position.y = P.y + an.B.pivot * an.B.scale - an.B.dead_drop * k


func _drink_pose(an: Animator) -> void:
	var u := _st
	var w := Gait.sstep(0.0, 0.35, u) * (1.0 - Gait.sstep(1.55, 1.9, u))
	if w <= 0.002:
		_place_glass(an, 0.0)
		return
	if _head == -2:
		_head = -1
		_neck = -1
		for i in an.skel.get_bone_count():
			var bn := Animator.san(an.skel.get_bone_name(i))
			if bn == "head":
				_head = i
			elif bn == "neck":
				_neck = i
	an._refresh_xf()
	var fwd := Vector3(sin(Game.player.yaw), 0.0, cos(Game.player.yaw))
	var side := Vector3(fwd.z, 0.0, -fwd.x)       # his left
	var tip := Gait.sstep(0.45, 0.8, u) * (1.0 - Gait.sstep(1.3, 1.55, u))      # the glass up to his lips and tipped back
	# 2026-11-16 (user: "he puts it up to his forehead"): he tips his head back a little as the glass comes up, and the glass is now aimed at his lips, read off the mesh,
	# instead of at a guess above the head bone, which put it at eye and forehead height.
	var tilt := Gait.sstep(0.35, 0.8, u) * (1.0 - Gait.sstep(1.3, 1.65, u)) * w
	_tilt(an, _neck, -0.1 * tilt, side)
	_tilt(an, _head, -0.24 * tilt, side)
	if an._jaw >= 0:      # lips part a touch for the sip
		an.skel.set_bone_pose_rotation(an._jaw, an._jaw_rest * Animator.q_axis(Vector3.RIGHT, 0.06 * tip))
	_place_glass(an, tip)      # (makes the glass and sets its tilt)
	if _glass == null:
		return
	# The glass is placed first, its rim on his lower lip, and the hand goes to it: the wrist under and outside the glass, the elbow down and out. (Aiming the
	# wrist itself at the face raised the forearm across it.)
	var hx := _head_xf(an)
	var s := _glass.global_basis.x.length()
	var k: Array = BarGlass.KINDS.get(_drink.get("glass", "tumbler"), BarGlass.KINDS["tumbler"])
	var tall := (float(k[4]) + float(k[2])) * s
	var r := float(k[0]) * s
	var ax := _glass.global_basis.y.normalized()
	var upp := (Vector3.UP - ax * ax.dot(Vector3.UP)).normalized()
	var rim := hx * MOUTH + upp * r * 0.75 + fwd * 0.012      # the rim's lower edge on the lower lip, its top up under the mustache
	var hold := hx.origin + fwd * 0.3 + side * 0.1 + Vector3(0.0, -0.22, 0.0)      # before the lift: the glass's foot in front of his chest
	var foot := hold.lerp(rim - ax * tall, tip)
	var wrist := foot + ax * tall * 0.3 + side * (r + 0.05) - fwd * 0.01 + Vector3(0.0, -0.02, 0.0)
	an._ik(0, wrist, side * 0.6 + Vector3(0.0, -1.0, 0.0) - fwd * 0.2, w)      # (the pole is a direction: it was passed a world point, which threw the elbow up over his head)
	if _finger < 0:
		_finger = an.skel.find_bone("middle_01.L")
	var ih: int = an._arm_h[0]
	if _finger >= 0 and ih >= 0:      # the hand turned so the fingers wrap round the glass's front (his fingers hang from the wrist: left alone, the wrist had to sit above the glass)
		var fd := (an.bone_world_pos(_finger) - an.bone_world_pos(ih)).normalized()
		an._turn(ih, fd, (-side * 0.5 + fwd * 0.85).normalized(), w)
	_place_glass(an, tip)
	_glass.global_position = _glass.global_position.lerp(foot, w)      # in his hand at the ends, on the mark while he drinks


## The lower lip in the head bone's frame (measured off the jaw-skinned vertices of assets/prog.glb, 2026-11-16).
const MOUTH := Vector3(0.0, 0.03, 0.15)
var _neck := -2
var _finger := -1


func _head_xf(an: Animator) -> Transform3D:
	if _head < 0:
		return Transform3D(Basis(), an.actor.global_position + Vector3(0.0, 1.6, 0.0))
	return an.actor.global_transform * an._model_xf * an.skel.get_bone_global_pose(_head)


## Turn a bone by `ang` about a world axis (on top of the animator's pose).
func _tilt(an: Animator, b: int, ang: float, axis_w: Vector3) -> void:
	if b < 0 or absf(ang) < 1e-4:
		return
	var A := (an.actor.global_transform * an._model_xf).basis.orthonormalized()
	var par := an.skel.get_bone_parent(b)
	var P := an.skel.get_bone_global_pose(par).basis.orthonormalized() if par >= 0 else Basis()
	var ax := (P.inverse() * (A.inverse() * axis_w)).normalized()
	an.skel.set_bone_pose_rotation(b, Animator.q_axis(ax, ang) * an.skel.get_bone_pose_rotation(b))


func _place_glass(an: Animator, tip: float) -> void:
	if _glass == null:
		if _drink.is_empty() and state != &"drinking":
			return
		_glass = BarGlass.make(_drink.get("glass", "tumbler"), int(_drink.get("color", 0x6dff4a)))
		Game.level.add_child(_glass)
		_glass.set_meta(&"s", an.B.scale * 1.35)      # (his hands are big: a bar glass in them is made to read)
	var ih: int = an._arm_h[0]
	if ih < 0:
		return
	var q := an.bone_world_quat(ih)
	var pos := an.bone_world_pos(ih)
	var fwd := Vector3(sin(Game.player.yaw), 0.0, cos(Game.player.yaw))
	var sip := clampf((_st - 0.8) / 0.5, 0.0, 1.0)
	var ang := tip * (1.05 + 0.5 * sip)      # tipped up to his lips, then further as it empties (was 1.9 rad at once: past what his tilted head needs)
	_glass.global_transform = Transform3D(Basis(Vector3(fwd.z, 0.0, -fwd.x), -ang).scaled(Vector3.ONE * float(_glass.get_meta(&"s", 1.0))), pos + q * Vector3(0.0, 0.08, 0.04))
	_glass.set_meta(&"fill", 1.0 - clampf((_st - 0.8) / 0.5, 0.0, 1.0))
	BarGlass.set_fill(_glass, _glass.get_meta(&"fill"))


func _drop_glass() -> void:
	if _glass != null and is_instance_valid(_glass):
		_glass.queue_free()
	_glass = null
