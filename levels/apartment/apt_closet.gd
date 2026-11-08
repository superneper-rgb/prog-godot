class_name AptCloset
extends Node
## PROG'S APARTMENT: THE CLOSET (JS levels/apartment/closet.js, a placeholder there too): a wardrobe in the bedroom; X opens it, the doors swing back and the camera pushes in on the green CRT built into its back panel, which lists Prog's stuff. Storing / taking items is not built yet (the menu says so). The wardrobe and its doors come with the export.

const OPEN_T := 0.55      # seconds: doors, push-in, pull-back
const ZOOM_T := 1.05
const BACK_T := 0.8
const GREEN := Color("#5dff8f")
const DIM := Color("#1f6a3a")
const BG := Color("#031208")
const SW := 0.44
const SH := 0.33
const SY := 1.18


class Screen:
	extends Control
	var o: AptCloset
	func _draw() -> void:
		o._draw_screen(self)


var state := &"idle"
var t := 0.0
var sel := 0
var msg := ""
var msg_t := 0.0
var cool := 0.0
var items: Array = []
var roll := 0.0
var redraw := 0.0
var camera := View.Shot.new()
var action: Dictionary = {}
var _level: ExportedLevel
var _doors: Array = []
var _glow: OmniLight3D
var _vp: SubViewport
var _view: Screen
var _front := 0.0
var _back := 0.0
var _zc := 0.0
var _from_pos := Vector3.ZERO
var _from_look := Vector3.ZERO
var _from_fov := 60.0
var _mid_pos := Vector3.ZERO
var _mid_look := Vector3.ZERO
var _end_pos := Vector3.ZERO
var _end_look := Vector3.ZERO
var _thunked := false
var _nav_dir := 0
var _nav_t := 0.0
var _s: Dictionary = {}


## at: the closet's footprint { x0, x1, z0, z1 }
func _init(level: ExportedLevel, at: Dictionary) -> void:
	name = "AptCloset"
	_level = level
	_front = at.x0
	_back = float(at.x1) - 0.03
	_zc = (float(at.z0) + float(at.z1)) / 2.0
	_mid_pos = Vector3(_front - 1.05, 1.45, _zc)
	_mid_look = Vector3(_back, SY + 0.05, _zc)
	_end_pos = Vector3(_back - 0.9, SY, _zc)
	_end_look = Vector3(_back, SY, _zc)
	action = {"x": _front - 0.75 + 0.3, "z": _zc, "label": "OPEN — CLOSET",
		"active": func(p: Player) -> bool: return state == &"idle" and cool <= 0.0 and U.hyp(p.x - (_front - 0.5), p.z - _zc) < 1.1,
		"run": open_it}


func _ready() -> void:
	for i in 2:
		var a: Array = _level.node_named("AptClosetDoor%d" % i)
		if not a.is_empty():
			_doors.append([a[0], 1.0 if i == 0 else -1.0])
	for o: Node in _level.node_named("AptClosetGlow"):
		if o is OmniLight3D:
			_glow = o
	if _glow != null:
		_glow.light_energy = 0.0
	# the menu, drawn on the screen (JS: a canvas)
	_vp = SubViewport.new()
	_vp.size = Vector2i(512, 384)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.transparent_bg = false
	_vp.disable_3d = true
	add_child(_vp)
	_view = Screen.new()
	_view.o = self
	_view.size = Vector2(512, 384)
	_vp.add_child(_view)
	var scr: Array = _level.node_named("AptClosetScreen")
	if not scr.is_empty():
		var n: Node = scr[0]
		var mi: MeshInstance3D = n if n is MeshInstance3D else n.find_children("*", "MeshInstance3D", true, false)[0]
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = _vp.get_texture()
		mi.material_override = m


func _inventory() -> Array:
	var d: Dictionary = Game.save_data
	var out: Array = []
	var nice := func(id: Variant) -> String: return String(id).replace("-", " ").replace("_", " ").to_upper()
	var gear: Dictionary = d.get("gear", {})
	for id: Variant in gear.get("slots", []):
		if id != null and id != "":
			var w: Variant = Game.combat.weapon_by_id(id) if Game.combat != null and Game.combat.has_method(&"weapon_by_id") else null
			out.append({"group": "WEAPON", "name": String(w.name if w != null else nice.call(id)).to_upper()})
	for id: Variant in (d.get("armor", {}) as Dictionary).get("owned", []):
		out.append({"group": "ARMOR", "name": nice.call(id)})
	for id: Variant in (d.get("powers", {}) as Dictionary).get("owned", []):
		out.append({"group": "IMPLANT", "name": nice.call(id)})
	return out


func _snd(key: String, dur: float, tones: Array, noises: Array, wet: float, gain: float = 1.0) -> void:
	if not _s.has(key):
		_s[key] = Cutscene.synth(dur, tones, noises)
	Game.sfx.clip(_s[key], {"gain": gain, "wet": wet})


func _beep(f0: float, f1: float, dur: float, gain: float = 0.03, type: StringName = &"square") -> void:
	_snd("b%d_%d_%d" % [roundi(f0), roundi(f1), roundi(dur * 100.0)], dur + 0.02, [[0.0, dur, f0, f1, type, 1.0, 0.002]], [], 0.05, gain)


func _creak() -> void:
	_snd("creak", 0.5, [[0.05, 0.4, 210.0, 160.0, &"sawtooth", 0.012, 0.01]], [[0.0, 0.5, &"bandpass", 900.0, 500.0, 9.0, 0.05, 0.01]], 0.2)


func _thunk() -> void:
	_snd("thunk", 0.15, [[0.0, 0.12, 140.0, 60.0, &"sine", 0.08, 0.002]], [[0.0, 0.08, &"lowpass", 1500.0, 1500.0, 0.7, 0.04, 0.002]], 0.1)


# ---- the menu (drawn on the screen canvas) ----

func _draw_screen(c: Control) -> void:
	var W := 512.0
	var H := 384.0
	c.draw_rect(Rect2(0, 0, W, H), BG)
	var f := CrtTheme.font(&"vt323")
	var on := state != &"idle"
	var line := func(txt: String, x: float, y: float, col: Color = GREEN) -> void: c.draw_string(f, Vector2(x, y + 20.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, col)
	if on:
		line.call("PROG//CLOSET", 18.0, 12.0)
		line.call("SCHLEEDTECH", 345.0, 12.0, DIM)
		c.draw_rect(Rect2(18, 44, W - 36.0, 2), DIM)
		line.call("ON YOU", 18.0, 54.0, DIM)
		line.call("IN CLOSET", 300.0, 54.0, DIM)
		var top := 84.0
		var rows := 8
		var first := clampi(sel - rows + 1, 0, maxi(0, items.size() - rows))
		if items.is_empty():
			line.call("  (nothing)", 18.0, top, DIM)
		for i in range(first, mini(items.size(), first + rows)):
			var y := top + (i - first) * 28.0
			var sel_row := i == sel
			if sel_row:
				c.draw_rect(Rect2(14, y - 2.0, 262, 27), GREEN)
			line.call(("> " if sel_row else "  ") + String(items[i]["name"]).substr(0, 15), 18.0, y, BG if sel_row else GREEN)
			line.call(String(items[i]["group"]).substr(0, 3), 236.0, y, BG if sel_row else DIM)
		line.call("(empty)", 300.0, top, DIM)
		line.call("roach shells", 300.0, top + 28.0, Color("#164d2a"))
		c.draw_rect(Rect2(18, 320, W - 36.0, 2), DIM)
		line.call("A STORE   B CLOSE   STICK MOVE" if Inp.using_pad else "E STORE   X CLOSE   W/S MOVE", 18.0, 330.0)
		if msg_t > 0.0 and int(msg_t * 4.0) % 2 == 0:
			line.call(msg, 18.0, 354.0, Color("#ffcc66"))
		else:
			line.call("STORAGE MODULE: NOT INSTALLED", 18.0, 354.0, DIM)
	else:
		line.call("READY_", 18.0, 12.0, DIM)
	var y2 := 0.0      # scanlines + the rolling bar
	while y2 < H:
		c.draw_rect(Rect2(0, y2, W, 1), Color(0, 0, 0, 0.28))
		y2 += 3.0
	var rb := fmod(roll, 1.4) / 1.4 * (H + 80.0) - 40.0
	for i in 16:
		var a := 0.07 * (1.0 - absf(i - 7.5) / 8.0)
		c.draw_rect(Rect2(0, rb - 40.0 + i * 5.0, W, 5), Color(93.0 / 255.0, 1.0, 143.0 / 255.0, a))


func _redraw() -> void:
	_view.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# ---- control ----

func open_it() -> void:
	if state != &"idle":
		return
	items = _inventory()
	sel = 0
	msg = ""
	msg_t = 0.0
	var c := Game.camera
	_from_pos = c.global_position
	_from_look = c.global_position - c.global_basis.z * 3.0
	_from_fov = c.fov
	state = &"opening"
	t = 0.0
	_thunked = false
	_creak()
	Game.ui.dialog.set_bars(true)
	Game.hud.set_suppressed(true)


func _move(d: int) -> void:
	if items.is_empty():
		return
	sel = posmod(sel + d, items.size())
	_beep(880.0, 880.0, 0.04, 0.02)
	_redraw()


func _select() -> void:
	msg = "STORAGE MODULE NOT INSTALLED"
	msg_t = 1.6
	_beep(180.0, 120.0, 0.25, 0.04, &"sawtooth")
	_redraw()


func close_it() -> void:
	if state != &"menu" and state != &"opening":
		return
	state = &"closing"
	t = 0.0
	_beep(600.0, 200.0, 0.12, 0.02)


func _finish() -> void:
	state = &"idle"
	cool = 0.35
	if _glow != null:
		_glow.light_energy = 0.0
	Game.ui.dialog.set_bars(false)
	Game.hud.set_suppressed(false)
	Inp.guard_arm()
	_redraw()
	for d: Array in _doors:
		(d[0] as Node3D).rotation.y = 0.0
	_creak()


## (user, 2026-11-07: the left stick moves the list too, with the pause menu's numbers: a push steps once, holding it repeats.)
func _stick_nav(dt: float) -> void:
	var stick := int(signf(Inp.raw_ly)) if absf(Inp.raw_ly) > 0.3 else 0
	if stick == 0:
		_nav_dir = 0
		_nav_t = 0.0
		return
	if stick != _nav_dir:
		_nav_dir = stick
		_nav_t = 0.28
		_move(stick)
		return
	_nav_t -= dt
	if _nav_t <= 0.0:
		_nav_t = 0.1
		_move(stick)


func is_on() -> bool:
	return state != &"idle"


func update_closet(dt: float) -> void:
	cool = maxf(0.0, cool - dt)
	if state == &"idle":
		return
	t += dt
	roll += dt
	msg_t = maxf(0.0, msg_t - dt)
	if state == &"menu":
		if Inp.key_hit(KEY_W) or Inp.key_hit(KEY_UP) or Inp.btn(&"d_up").pressed:
			_move(-1)
		elif Inp.key_hit(KEY_S) or Inp.key_hit(KEY_DOWN) or Inp.btn(&"d_down").pressed:
			_move(1)
		_stick_nav(dt)
		if Inp.key_hit(KEY_E) or Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_SPACE) or (Inp.using_pad and Inp.btn(&"jump").pressed):
			_select()
		if Inp.key_hit(KEY_X) or Inp.key_hit(KEY_BACKSPACE) or (Inp.using_pad and (Inp.btn(&"b").pressed or Inp.btn(&"attack").pressed)):
			close_it()
	var door_k := 1.0
	var k := 1.0
	if state == &"opening":
		door_k = Cutscene.ease_(t / OPEN_T)
		k = Cutscene.ease_(t / (OPEN_T + ZOOM_T))
		if t > OPEN_T * 0.6 and not _thunked:
			_thunked = true
			_thunk()
		if t >= OPEN_T + ZOOM_T:
			state = &"menu"
			t = 0.0
			_beep(1200.0, 1200.0, 0.05, 0.015)
			_redraw()
	elif state == &"closing":
		k = 1.0 - Cutscene.ease_(t / BACK_T)
		door_k = 1.0 - Cutscene.ease_((t - BACK_T * 0.45) / (BACK_T * 0.55))
		if t >= BACK_T:
			_finish()
			return
	for d: Array in _doors:      # ~100 degrees out, into the room
		(d[0] as Node3D).rotation.y = -float(d[1]) * door_k * 1.75
	if _glow != null:
		_glow.light_energy = (k if state == &"closing" else clampf((t - OPEN_T * 0.6) * 3.0, 0.0, 1.0)) * 0.3 / PI
	# camera: from where it was, via a spot in front of the doors, to the screen
	var A_pos := Game.rig.pos if state == &"closing" else _from_pos
	var A_look := Game.rig.look if state == &"closing" else _from_look
	if k < 0.5:
		var u := Cutscene.ease_(k / 0.5)
		camera.pos = A_pos.lerp(_mid_pos, u)
		camera.look = A_look.lerp(_mid_look, u)
	else:
		var u := Cutscene.ease_((k - 0.5) / 0.5)
		camera.pos = _mid_pos.lerp(_end_pos, u)
		camera.look = _mid_look.lerp(_end_look, u)
	# the push-in's last fov: the whole bezel in frame whatever the window's shape (the letterbox bars take ~25% of the height)
	var dd := _end_look.x - _end_pos.x - 0.077
	var vs := get_viewport().get_visible_rect().size
	var half := maxf((SH + 0.2) / 2.0 / 0.75, (SW + 0.16) / 2.0 / (vs.x / vs.y))
	var end_fov := rad_to_deg(2.0 * atan(half / dd))
	camera.fov = _from_fov + (end_fov - _from_fov) * Cutscene.ease_(k)
	redraw -= dt
	if redraw <= 0.0 or msg_t > 0.0:
		_redraw()
		redraw = 1.0 / 15.0


func pose_player(an: Animator) -> void:
	var P := Game.player
	if an != null:
		an.actor.visible = not (state != &"idle" and U.hyp(camera.pos.x - P.x, camera.pos.z - P.z) < 0.7)


## for a cutscene: swing the doors open by a radians (0 shut; the terminal opens them 1.75, flat back is 3) while the terminal is not in use
func set_doors(a: float) -> void:
	if state != &"idle":
		return
	for d: Array in _doors:
		(d[0] as Node3D).rotation.y = -float(d[1]) * clampf(a, 0.0, 3.0)
