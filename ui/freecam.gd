class_name Freecam
extends RefCounted
## DEV FREE CAM (devtools/freecam.js): a fly camera for the dev console ("freecam"): freezes the game and lets you look around with WASD + right-mouse drag.
## The console turns it on; the game is held still while `on`, and core/view.gd renders `camera`. Pad: left stick move, right stick look, RT / A up, LT / B down, RB fast, LB slow, D-pad up / down = speed.

var on := false
var speed := 12.0
var yaw := 0.0
var pitch := 0.0
var fov := 62.0
var camera := View.Shot.new()
var _dpad_prev := 0.0


func enable(from: CameraRig) -> void:
	if from != null:
		camera.pos = from.pos
		var d: Vector3 = from.look - from.pos
		yaw = atan2(d.x, d.z)
		pitch = atan2(-d.y, Vector2(d.x, d.z).length())
	fov = Config.fov
	on = true
	_aim()


func disable() -> void:
	on = false


# yaw 0 looks along +Z, increasing = turn left (the player / CameraRig convention); pitch > 0 looks down
func _aim() -> void:
	var cp := cos(pitch)
	camera.look = camera.pos + Vector3(sin(yaw) * cp, -sin(pitch), cos(yaw) * cp)


static func _dz(v: float) -> float:
	return 0.0 if absf(v) < 0.15 else (v - signf(v) * 0.15) / 0.85


## Every frame with the real (unscaled) dt while on.
func update(dt: float) -> void:
	if not on:
		return
	var con: bool = (Game.ui != null and Game.ui.console.is_open) or Inp.real_off
	var k := func(c: int) -> bool: return Input.is_physical_key_pressed(c) and not con
	var fast := 4.0 if k.call(KEY_SHIFT) else (0.25 if k.call(KEY_CTRL) else 1.0)
	var f := (1.0 if k.call(KEY_W) else 0.0) - (1.0 if k.call(KEY_S) else 0.0)
	var s := (1.0 if k.call(KEY_A) else 0.0) - (1.0 if k.call(KEY_D) else 0.0)
	var u := (1.0 if (k.call(KEY_SPACE) or k.call(KEY_E)) else 0.0) - (1.0 if (k.call(KEY_Q) or k.call(KEY_C)) else 0.0)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not con:
		var rel := Input.get_last_mouse_screen_velocity() * dt
		yaw -= rel.x * 0.003
		pitch = clampf(pitch + rel.y * 0.003, -1.5, 1.5)
	var pads := Input.get_connected_joypads()
	if pads.size() > 0 and not Inp.real_off:
		var id: int = pads[0]
		s -= _dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_X))
		f -= _dz(Input.get_joy_axis(id, JOY_AXIS_LEFT_Y))
		u += Input.get_joy_axis(id, JOY_AXIS_TRIGGER_RIGHT) + (1.0 if Input.is_joy_button_pressed(id, JOY_BUTTON_A) else 0.0) - Input.get_joy_axis(id, JOY_AXIS_TRIGGER_LEFT) - (1.0 if Input.is_joy_button_pressed(id, JOY_BUTTON_B) else 0.0)
		yaw -= _dz(Input.get_joy_axis(id, JOY_AXIS_RIGHT_X)) * 2.2 * minf(dt, 0.1)
		pitch = clampf(pitch + _dz(Input.get_joy_axis(id, JOY_AXIS_RIGHT_Y)) * 1.6 * minf(dt, 0.1), -1.5, 1.5)
		if Input.is_joy_button_pressed(id, JOY_BUTTON_RIGHT_SHOULDER):
			fast = 4.0
		elif Input.is_joy_button_pressed(id, JOY_BUTTON_LEFT_SHOULDER):
			fast = 0.25
		var dpad := (1.0 if Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_UP) else 0.0) - (1.0 if Input.is_joy_button_pressed(id, JOY_BUTTON_DPAD_DOWN) else 0.0)
		if dpad != 0.0 and _dpad_prev == 0.0:
			speed = clampf(speed * (1.4 if dpad > 0.0 else 1.0 / 1.4), 0.5, 200.0)
		_dpad_prev = dpad
	var v := speed * fast * minf(dt, 0.1)
	var cp := cos(pitch)
	var fx := sin(yaw) * cp
	var fy := -sin(pitch)
	var fz := cos(yaw) * cp
	camera.pos += Vector3((fx * f + cos(yaw) * s) * v, (fy * f + u) * v, (fz * f - sin(yaw) * s) * v)
	_aim()
