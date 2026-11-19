extends Node
## Autoload Inp: input abstraction ported from the three.js game's Input class. Game logic only ever sees:
##   Inp.move  (x right, y forward, mag: curved + deadzoned)
##   Inp.look_yaw / look_pitch (radians this frame), Inp.look_active
##   Inp.btn(name) -> Btn (held, pressed, released, value)
## It never touches raw devices. Call step(dt) once per frame, before the simulation.

class Btn:
	var held := false
	var pressed := false
	var released := false
	var value := 0.0

class Stick:
	var x := 0.0
	var y := 0.0
	var mag := 0.0

## The view handed to a physics sub-step: same held state, edges only on the first sub-step (JS input.sub).
class InputView:
	var move: Stick
	var btns: Dictionary = {}
	func btn(n: StringName) -> Btn:
		return btns[n]

const BUTTONS: Array[StringName] = [&"jump", &"b", &"attack", &"quick", &"strafe", &"sprint", &"crouch", &"recenter",
	&"fire", &"reload", &"ads", &"debug", &"pause", &"d_up", &"d_down", &"d_left", &"d_right", &"l3", &"r3", &"power", &"nvg", &"map"]

# Xbox "standard" mapping, by Godot's SDL button indices (JoyButton).
const PAD_BTN := {
	&"jump": JOY_BUTTON_A, &"b": JOY_BUTTON_B, &"attack": JOY_BUTTON_X, &"quick": JOY_BUTTON_Y,
	&"strafe": JOY_BUTTON_LEFT_SHOULDER, &"crouch": JOY_BUTTON_RIGHT_SHOULDER, &"recenter": JOY_BUTTON_RIGHT_STICK,
	&"map": JOY_BUTTON_BACK, &"pause": JOY_BUTTON_START, &"l3": JOY_BUTTON_LEFT_STICK, &"r3": JOY_BUTTON_RIGHT_STICK,
	&"d_up": JOY_BUTTON_DPAD_UP, &"d_down": JOY_BUTTON_DPAD_DOWN, &"d_left": JOY_BUTTON_DPAD_LEFT, &"d_right": JOY_BUTTON_DPAD_RIGHT,
	&"power": JOY_BUTTON_DPAD_UP, &"nvg": JOY_BUTTON_DPAD_DOWN,
}

const KEY_MAP := {
	&"jump": [KEY_SPACE], &"crouch": [KEY_C], &"strafe": [KEY_F], &"sprint": [KEY_SHIFT], &"recenter": [KEY_G], &"reload": [KEY_R],
	&"debug": [KEY_F3], &"pause": [KEY_ESCAPE, KEY_P], &"quick": [KEY_Q], &"b": [KEY_E], &"attack": [KEY_V], &"power": [KEY_Z], &"nvg": [KEY_N], &"map": [KEY_M],
}
const MOUSE_MAP := {&"ads": MOUSE_BUTTON_RIGHT, &"fire": MOUSE_BUTTON_LEFT}

var move := Stick.new()
var look := Stick.new()
var look_yaw := 0.0
var look_pitch := 0.0
var look_active := false
var look_tight := false       # set by the camera rig while aiming: crosshair work keeps the stick direct
var lt := 0.0
var rt := 0.0
var pad_connected := false
var using_pad := false
var orbit_btn := 0             # JS input.orbitBtn: a mouse button that turns the camera while the pointer is free (the DEV tools' right-drag)
var capture_blocked := false   # a level's tools own the mouse: a click does not re-capture it
var pointer_locked := false   # mouse captured: gameplay owns the mouse
var real_off := false         # started with --peek: real pad, keyboard and mouse are ignored, so a controller on the desk cannot disturb a test. Never true in normal play.
var text_capture := false     # the dev console has the keyboard
var keys_pressed: Dictionary = {}   # physical keys that went down since the last frame (see key_hit)
var keys_echo: Dictionary = {}      # the same for the OS key repeat
var raw_lx := 0.0             # the left stick before its deadzone (JS input.raw: the pause menu's stick navigation)
var raw_ly := 0.0
var _echo_down: Dictionary = {}

var sub := InputView.new()         # edge-less view for physics sub-steps
var full := InputView.new()        # the frame's view, with edges
var dead := InputView.new()        # JS DEAD_INPUT: nothing moved, nothing held (dead, stunned, driving, in a cutscene)

var _btns: Dictionary = {}
var _sub_btns: Dictionary = {}
var _dead_btns: Dictionary = {}
var _prev: Dictionary = {}
var _keys_down: Dictionary = {}
var _latch_down: Dictionary = {}
var _latch_up: Dictionary = {}
var _mouse_down: Dictionary = {}
var _mouse_latch_down: Dictionary = {}
var _mouse_latch_up: Dictionary = {}
var _mdx := 0.0
var _mdy := 0.0
var _lt_held := false
var _pad_lx := 0.0
var _pad_ly := 0.0
var _pad_lxv := 0.0
var _pad_lyv := 0.0
var _pad_id := -1
var _kb_activity := false

## Scripted input for tests and the bot (see tools/): when non-empty these names read as held, and `move` is taken from bot_move.
var bot_on := false
var _guard: Dictionary = {}     # held buttons that count for nothing until released
var bot_held: Dictionary = {}
var bot_move := Vector2.ZERO
var bot_look := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--peek="):
			real_off = true
	for n in BUTTONS:
		_btns[n] = Btn.new()
		_sub_btns[n] = Btn.new()
		_dead_btns[n] = Btn.new()
		_prev[n] = false
	full.btns = _btns
	full.move = move
	sub.btns = _sub_btns
	sub.move = move
	dead.btns = _dead_btns
	dead.move = Stick.new()


## JS inputGuard.arm: after a dialogue or a door, whatever is still held does nothing until it is let go, so the X that closed a line does not also reload or punch.
func guard_arm() -> void:
	for n: StringName in BUTTONS:
		if btn(n).held:
			_guard[n] = true


## JS inputGuard.apply
func _guard_apply() -> void:
	for n: StringName in _guard.keys():
		var o := btn(n)
		if o.held:
			o.held = false
			o.pressed = false
			o.value = 0.0
			var v: Btn = sub.btn(n)
			v.held = false
			v.pressed = false
			v.value = 0.0
		else:
			_guard.erase(n)
			o.pressed = false


func btn(n: StringName) -> Btn:
	return _btns[n]


## A test presses a key: it reads as down for one frame, for key_hit and the buttons mapped to it.
func bot_key(code: int) -> void:
	_latch_down[code] = true


## Is this physical key down? (a full-screen minigame reads the keyboard itself)
func key_down(code: int) -> bool:
	return _keys_down.has(code)


## Did this physical key go down since the last frame? (the menus' keydown handlers; repeat: count the OS key repeat too, as the JS menus did for the arrows)
func key_hit(code: int, repeat: bool = false) -> bool:
	return keys_pressed.has(code) or (repeat and keys_echo.has(code))


## The dev console is taking the keyboard: nothing held stays held behind it.
func set_text_capture(on: bool) -> void:
	text_capture = on
	if on:
		_keys_down.clear()


func _input(event: InputEvent) -> void:
	if real_off:      # under --peek the game answers the test driver only, not whoever is sitting at the machine
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if text_capture:      # the dev console is typing: the game never sees these keys
			return
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		if k.echo:
			if k.pressed:
				_echo_down[code] = true
			return
		if k.pressed:
			_keys_down[code] = true
			_latch_down[code] = true
			_kb_activity = true
		else:
			_keys_down.erase(code)
			_latch_up[code] = true
	elif event is InputEventMouseMotion:
		if pointer_locked or (orbit_btn != 0 and Input.is_mouse_button_pressed(orbit_btn)):
			var m := event as InputEventMouseMotion
			# screen_relative: raw pointer pixels, unaffected by the window's stretch mode (the JS game read movementX / Y).
			_mdx += m.screen_relative.x
			_mdy += m.screen_relative.y
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.pressed:
			if pointer_locked:
				_mouse_down[b.button_index] = true
				_mouse_latch_down[b.button_index] = true
		else:
			_mouse_down.erase(b.button_index)
			_mouse_latch_up[b.button_index] = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_keys_down.clear()
		_mouse_down.clear()


## Capture or free the mouse (the JS game's pointer lock).
func set_pointer_lock(on: bool) -> void:
	pointer_locked = on
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
	if not on:
		_mouse_down.clear()


func _radial(x: float, y: float, dz: float, e: float, out: Stick) -> void:
	var m := sqrt(x * x + y * y)
	if m <= dz:
		out.x = 0.0
		out.y = 0.0
		out.mag = 0.0
		return
	var s := minf(1.0, (m - dz) / (1.0 - dz))
	var c := pow(s, e)
	out.x = x / m * c
	out.y = y / m * c
	out.mag = c


var _ls := Stick.new()


## Once per frame, before the simulation (JS Input.update).
func step(dt: float) -> void:
	var C := Config
	var pads: Array[int] = []
	if not real_off:
		pads = Input.get_connected_joypads()
	pad_connected = pads.size() > 0
	_pad_id = pads[0] if pad_connected else -1

	# ---- sticks (radial deadzone; Godot's axes are already -1..1, stick up = -1, as in the browser's API) ----
	var lx := Input.get_joy_axis(_pad_id, JOY_AXIS_LEFT_X) if pad_connected else 0.0
	var ly := Input.get_joy_axis(_pad_id, JOY_AXIS_LEFT_Y) if pad_connected else 0.0
	raw_lx = lx
	raw_ly = ly
	var rx := Input.get_joy_axis(_pad_id, JOY_AXIS_RIGHT_X) if pad_connected else 0.0
	var ry := Input.get_joy_axis(_pad_id, JOY_AXIS_RIGHT_Y) if pad_connected else 0.0
	_radial(lx, ly, C.deadzone, C.move_exp, _ls)
	_radial(rx, ry, C.deadzone, C.cam_exp, look)

	# ---- keyboard move ----
	var kx := (1.0 if _keys_down.has(KEY_D) else 0.0) - (1.0 if _keys_down.has(KEY_A) else 0.0)
	var ky := (1.0 if _keys_down.has(KEY_W) else 0.0) - (1.0 if _keys_down.has(KEY_S) else 0.0)
	var kl := sqrt(kx * kx + ky * ky)
	if kl > 1.0:
		kx /= kl
		ky /= kl
	var kb_move := kl > 0.0
	if bot_on:
		move.x = bot_move.x
		move.y = bot_move.y
		move.mag = minf(1.0, bot_move.length())
	elif kb_move:
		move.x = kx
		move.y = ky
		move.mag = 1.0
	else:
		move.x = _ls.x
		move.y = -_ls.y       # stick up (-1) = forward
		move.mag = _ls.mag

	# ---- look ----
	var inv := -1.0 if C.invert_y else 1.0
	if look_tight or not (C.pad_look_ease > 0.0):
		_pad_lx = look.x
		_pad_ly = look.y
		_pad_lxv = 0.0
		_pad_lyv = 0.0
	else:
		_pad_lx = U.spring_to(_pad_lx, _pad_lxv, look.x, C.pad_look_ease, dt)
		_pad_lxv = U.spring_v
		_pad_ly = U.spring_to(_pad_ly, _pad_lyv, look.y, C.pad_look_ease, dt)
		_pad_lyv = U.spring_v
		if look.mag == 0.0 and sqrt(_pad_lx * _pad_lx + _pad_ly * _pad_ly) < 0.004:
			_pad_lx = 0.0
			_pad_ly = 0.0
			_pad_lxv = 0.0
			_pad_lyv = 0.0
	look_yaw = -_pad_lx * C.pad_look_speed * dt - _mdx * C.mouse_sens
	look_pitch = _pad_ly * inv * C.pad_look_speed * dt + _mdy * C.mouse_sens * inv
	look_active = look.mag > 0.0 or _pad_lx != 0.0 or _pad_ly != 0.0 or _mdx != 0.0 or _mdy != 0.0
	if bot_on and bot_look != Vector2.ZERO:
		look_yaw += bot_look.x
		look_pitch += bot_look.y
		look_active = true
	_mdx = 0.0
	_mdy = 0.0

	# ---- triggers ----
	lt = Input.get_joy_axis(_pad_id, JOY_AXIS_TRIGGER_LEFT) if pad_connected else 0.0
	rt = Input.get_joy_axis(_pad_id, JOY_AXIS_TRIGGER_RIGHT) if pad_connected else 0.0
	_lt_held = lt > 0.35 if _lt_held else lt > 0.5

	# ---- buttons with press / hold / release edges ----
	var pad_any := false
	for n in BUTTONS:
		var pad_held := false
		var val := 0.0
		if pad_connected:
			if n == &"ads":
				pad_held = _lt_held
				val = lt
			elif n == &"fire":
				pad_held = rt > 0.5
				val = rt
			elif PAD_BTN.has(n):
				pad_held = Input.is_joy_button_pressed(_pad_id, PAD_BTN[n])
				val = 1.0 if pad_held else 0.0
		if pad_held:
			pad_any = true
		var kb_held := false
		var kb_down := false
		var kb_up := false
		if KEY_MAP.has(n):
			for c: int in KEY_MAP[n]:
				if _keys_down.has(c):
					kb_held = true
				if _latch_down.has(c):
					kb_down = true
				if _latch_up.has(c):
					kb_up = true
		if MOUSE_MAP.has(n):
			var mb: int = MOUSE_MAP[n]
			if _mouse_down.has(mb):
				kb_held = true
			if _mouse_latch_down.has(mb):
				kb_down = true
			if _mouse_latch_up.has(mb):
				kb_up = true
		if bot_on and bot_held.has(n):
			kb_held = true
		var held := pad_held or kb_held
		var prev: bool = _prev[n]
		var o: Btn = _btns[n]
		o.held = held
		o.pressed = (held and not prev) or kb_down
		o.released = (not held and prev) or kb_up
		o.value = (maxf(val, 1.0) if (kb_held or pad_held) else 0.0)
		if n == &"ads" or n == &"fire":
			o.value = maxf(val, 1.0 if kb_held else 0.0)
		_prev[n] = held
		var s: Btn = _sub_btns[n]
		s.held = o.held
		s.value = o.value
		s.pressed = false
		s.released = false
	var kp := keys_pressed    # swapped, not copied: the menus read this frame's edges after step()
	keys_pressed = _latch_down
	_latch_down = kp
	_latch_down.clear()
	var ke := keys_echo
	keys_echo = _echo_down
	_echo_down = ke
	_echo_down.clear()
	_latch_up.clear()
	_mouse_latch_down.clear()
	_mouse_latch_up.clear()

	if pad_any or _ls.mag > 0.0 or look.mag > 0.0:
		using_pad = true
	if kb_move or _kb_activity:
		if kb_move:
			using_pad = false
	_kb_activity = false
