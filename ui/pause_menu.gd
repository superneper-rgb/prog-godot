class_name PauseMenu
extends Control
## The pause terminal: resume, inventory, music volume, controls diagrams, in the green phosphor CRT inside the SchleedTech monitor (assets/ui/pausecrt-2400.png, the glass cut out by tools/build_ui_art.py).
## Ported from index.html (pause menu section) with its CSS. The controls page zooms the monitor in until its glass fills the window, and the diagram fills the glass.
## INVENTORY (ui/inventory.gd, added here) zooms the same way and takes the whole glass, at its own 960-wide page size.

const KEYBOARD_IMG := "res://assets/ui/cut/controls-keyboard.png"     # the SVG's live text does not survive Godot's SVG import: rendered once in a browser, see PORT_STATUS
const GAMEPAD_IMG := "res://assets/ui/controls-gamepad.webp"

## The page on the terminal's glass, laid out at (at least) 600 x 440 and scaled to it.
class PageView extends Control:
	var m: PauseMenu
	func _draw() -> void:
		if m != null:
			m._draw_page(self)


var ctl_pad := false
var pause_focus := "pResume"
var _nav_dir := 0
var _nav_t := 0.0
var _controls := false
var _inv: Inventory
var _inv_open := false
var _bg: ColorRect
var _stage: Control
var _view: CrtScreen
var _page: PageView
var _img: TextureRect
var _art: TextureRect
var _glow_mul: ColorRect
var _glow_add: ColorRect
var _rects := {}             # target id -> Rect2 in page px
var _sw := 1000.0
var _sh := 810.0
var _gx := 0.0
var _gy := 0.0
var _gw := 600.0
var _gh := 440.0
var _k := 1.0
var _zoom := 1.0
var _t := Vector2.ZERO
var _z_from := 0.0
var _z_to := 0.0
var _z_u := 1.0
var _z := 0.0                # 0 = the monitor whole, 1 = zoomed
var _time := 0.0
var _dragging := false
var _tex_kb: Texture2D
var _tex_pad: Texture2D


func _init() -> void:
	name = "Pause"
	CrtTheme.full(self, false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 20


func _ready() -> void:
	_tex_kb = load(KEYBOARD_IMG)
	_tex_pad = load(GAMEPAD_IMG)
	# #pause: radial-gradient(ellipse at center, rgba(0,8,3,.5), rgba(0,0,0,.88)); backdrop-filter: blur(3px)
	_bg = ColorRect.new()
	_bg.color = Color.WHITE
	CrtTheme.full(_bg)
	_bg.material = CrtTheme.mat("res://ui/backdrop.gdshader")
	add_child(_bg)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_view = CrtScreen.new(Vector2(600, 440))
	_view.param(&"glow_tint", Vector3(80.0 / 255.0, 1.0, 140.0 / 255.0))
	_view.param(&"glow_amount", 0.62)
	_view.param(&"glow_radius", 7.0)
	_stage.add_child(_view)
	_page = PageView.new()
	_page.m = self
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.content.add_child(_page)
	_img = TextureRect.new()
	_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_img.material = CrtTheme.mat("res://ui/css_filter.gdshader")
	_img.visible = false
	_view.content.add_child(_img)
	_inv = Inventory.new()
	_inv.back = func() -> void:
		show_inventory(false)
		set_pause_focus("pInventory", true)
	_view.content.add_child(_inv)
	_art =TextureRect.new()
	_art.texture = load("res://assets/ui/cut/pausecrt.png")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stage.add_child(_art)
	_glow_mul = _glow_rect("res://ui/box_glow_mul.gdshader")
	_glow_add = _glow_rect("res://ui/box_glow.gdshader")
	_stage.add_child(_glow_mul)
	_stage.add_child(_glow_add)
	get_viewport().size_changed.connect(pc_layout)
	pc_layout()
	set_process(false)


func _glow_rect(shader: String) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color.WHITE
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.material = CrtTheme.mat(shader)
	return c


## Fit the monitor to the window (pcLayout).
func pc_layout() -> void:
	var vp := get_viewport_rect().size
	var h: Array = UiArt.PAUSE_HOLE
	_sw = minf(vp.x * 0.98, vp.y * 0.98 * UiArt.PAUSE_RATIO)
	_sh = _sw / UiArt.PAUSE_RATIO
	_gx = h[0] * _sw
	_gy = h[1] * _sh
	_gw = (h[2] - h[0]) * _sw
	_gh = (h[3] - h[1]) * _sh
	_k = minf(_gw / 600.0, _gh / 440.0)      # the menu is laid out at (at least) 600 x 440, then scaled to the glass
	# the controls page zooms the monitor in until the glass fills the window, so the diagram is big enough to read
	_zoom = maxf(1.0, minf(vp.x * 0.97 / _gw, vp.y * 0.97 / _gh))
	_t = Vector2(_sw * 0.5 - (h[0] + h[2]) * 0.5 * _sw, _sh * 0.5 - (h[1] + h[3]) * 0.5 * _sh)
	_stage.size = Vector2(_sw, _sh)
	_stage.pivot_offset = Vector2(_gx + _gw * 0.5, _gy + _gh * 0.5)
	_art.size = Vector2(_sw, _sh)
	_view.position = Vector2(_gx, _gy)
	_view.size = Vector2(_gw, _gh)
	_page.size = Vector2(_gw / _k, _gh / _k)
	_view.set_logical(Vector2(Inventory.W, Inventory.W * _gh / _gw) if _inv_open else _page.size)
	_inv.size = _view.logical
	_inv.layout()
	if _controls or _inv_open:
		_view.fit(_zoom)
	var pad := Vector2(_sw * 0.06, _sw * 0.06)
	var sw := _sw
	for c: ColorRect in [_glow_mul, _glow_add]:
		c.position = Vector2(_gx, _gy) - pad
		c.size = Vector2(_gw, _gh) + pad * 2.0
		var m := c.material as ShaderMaterial
		m.set_shader_parameter(&"box_css", Vector2(_gw, _gh))
		m.set_shader_parameter(&"pad", pad)
		m.set_shader_parameter(&"radius", Vector2(_gw * 0.04, _gh * 0.05))
		# box-shadow: 0 0 (sw*.03) (sw*.005) rgba(90,255,150,.5), inset 0 0 (sw*.055) rgba(80,255,140,.5), inset 0 0 (sw*.012) rgba(160,255,200,.5)
		m.set_shader_parameter(&"outer", Color(90.0 / 255.0, 1.0, 150.0 / 255.0, 0.5))
		m.set_shader_parameter(&"outer_blur", sw * 0.03)
		m.set_shader_parameter(&"outer_spread", sw * 0.005)
		m.set_shader_parameter(&"in_a", Color(80.0 / 255.0, 1.0, 140.0 / 255.0, 0.5))
		m.set_shader_parameter(&"in_a_blur", sw * 0.055)
		m.set_shader_parameter(&"in_b", Color(160.0 / 255.0, 1.0, 200.0 / 255.0, 0.5))
		m.set_shader_parameter(&"in_b_blur", sw * 0.012)
	_place_stage()
	_layout_page()


func _place_stage() -> void:
	var vp := get_viewport_rect().size
	var base := (vp - Vector2(_sw, _sh)) * 0.5
	var e := _z
	_stage.scale = Vector2.ONE * lerpf(1.0, _zoom, e)
	_stage.position = base + _t * e
	var sc := lerpf(1.0, _zoom, e)
	var f := CrtTheme.px(self)
	_view.param(&"rect_px", Vector2(_gw, _gh) * f * sc)
	_view.param(&"px_scale", f * sc)
	_view.param(&"overlay", lerpf(1.0, 0.45, e))


## The page's buttons (CSS #pause .pc-stage ...), in page px.
func _layout_page() -> void:
	_rects.clear()
	var cw := _page.size.x
	var ch := _page.size.y
	if not _controls:
		# padding: 30px 64px 22px, centred column
		var x := 64.0
		var w := cw - 128.0
		var music: bool = Game.music != null
		var h1 := 30.0 * 1.15 + 12.0
		var btn := 24.0 * 1.1 + 14.0 + 2.0
		var f := CrtTheme.font(&"vt323")
		var lines := CrtTheme.wrap(f, HELP_TEXT, 17, w, 17.0 * 0.06).size()
		var total := h1 + 6.0 + btn * 3.0 + 9.0 * 2.0 + 10.0 + btn + (12.0 + 10.0 + 1.0 + 26.0 if music else 0.0) + 12.0 + lines * 17.0 * 1.5
		var y := 30.0 + maxf(0.0, (ch - 30.0 - 22.0 - total) * 0.5) + h1 + 6.0
		_rects["pResume"] = Rect2(x, y, w, btn)
		y += btn + 9.0
		_rects["pInventory"] = Rect2(x, y, w, btn)
		y += btn + 9.0
		_rects["pControls"] = Rect2(x, y, w, btn)
		y += btn + 10.0
		_rects["pMenu"] = Rect2(x, y, w, btn)
		y += btn
		if music:
			y += 12.0 + 10.0 + 1.0
			_rects["musicVol"] = Rect2(x + 100.0, y, minf(200.0, w * 0.6), 26.0)
			_rects["_musicRow"] = Rect2(x, y, w, 26.0)
			y += 26.0
		_rects["_help"] = Rect2(x, y + 12.0, w, lines * 17.0 * 1.5)
		_rects["_h1"] = Rect2(x, 30.0 + maxf(0.0, (ch - 30.0 - 22.0 - total) * 0.5), w, 30.0 * 1.15)
		_img.visible = false
	else:
		# #pause.pc-zoom .card: padding 10px 22px 8px; tabs, the diagram, BACK
		var x := 22.0
		var w := cw - 44.0
		var y := 10.0
		var tab_h := 17.0 * 1.1 + 10.0 + 2.0
		var tw := (w - 10.0) * 0.5
		_rects["tabKb"] = Rect2(x, y, tw, tab_h)
		_rects["tabPad"] = Rect2(x + tw + 10.0, y, tw, tab_h)
		y += tab_h + 6.0
		_rects["pInvert"] = Rect2(x, y, w, tab_h)      # the camera-invert toggle (Config.invert_y), a row under the tabs
		y += tab_h + 6.0
		var back_h := 20.0 * 1.1 + 10.0 + 2.0
		var img_h := ch - 8.0 - back_h - 6.0 - y
		_rects["_img"] = Rect2(x, y, w, img_h)
		_rects["pBack"] = Rect2(x, y + img_h + 6.0, w, back_h)
		_img.position = Vector2(x + 1.0, y + 1.0)
		_img.size = Vector2(w - 2.0, img_h - 2.0)
		_img.texture = _tex_pad if ctl_pad else _tex_kb
		_img.visible = true
	_page.queue_redraw()
	_view.refresh()


const HELP_TEXT := "Click outside, or press Start / Esc to resume.\nPress I for the inventory, C / Y for the controls."


func _draw_page(v: Control) -> void:
	var f := CrtTheme.font(&"vt323b")
	var f2 := CrtTheme.font(&"vt323")
	if not _controls:
		# h1: C:\> PAUSED_
		var r: Rect2 = _rects.get("_h1", Rect2())
		var y := CrtTheme.baseline(f, 30, r.position.y, r.size.y)
		var x := CrtTheme.draw_text(v, f, r.position.x, y, "C:\\> ", 30, CrtTheme.PH_DIM, 30.0 * 0.05)
		x = CrtTheme.draw_text(v, f, x, y, "PAUSED", 30, CrtTheme.PH_HI, 30.0 * 0.2)
		if fmod(_time, 1.0) < 0.5:
			CrtTheme.draw_text(v, f, x + 30.0 * 0.12, y, "_", 30, CrtTheme.PH_HI, 30.0 * 0.2)
		_button(v, "pResume", "RESUME", 24, 40.0, 0.16)
		_button(v, "pInventory", "INVENTORY", 24, 40.0, 0.16)
		_button(v, "pControls", "CONTROLS", 24, 40.0, 0.16)
		_button(v, "pMenu", "RETURN TO MENU", 24, 40.0, 0.16)
		if _rects.has("musicVol"):
			var row: Rect2 = _rects["_musicRow"]
			var ly := row.position.y - 10.0 - 0.5
			var dx := row.position.x
			while dx < row.end.x:
				v.draw_line(Vector2(dx, ly), Vector2(minf(dx + 4.0, row.end.x), ly), Color(110.0 / 255.0, 1.0, 170.0 / 255.0, 0.4), 1.0)
				dx += 8.0
			CrtTheme.draw_text(v, f, row.position.x, CrtTheme.baseline(f, 20, row.position.y, row.size.y), "MUSIC", 20, Color("6ee79a"), 3.6)
			var s: Rect2 = _rects["musicVol"]
			var val: float = clampf(float(Game.music.volume), 0.0, 1.0)
			var my := s.position.y + s.size.y * 0.5
			var focused := pause_focus == "musicVol"
			if focused:
				v.draw_rect(s.grow(6.0), CrtTheme.PH_HI, false, 2.0)
			v.draw_rect(Rect2(s.position.x, my - 2.0, s.size.x, 4.0), Color(110.0 / 255.0, 1.0, 170.0 / 255.0, 0.25))
			v.draw_rect(Rect2(s.position.x, my - 2.0, s.size.x * val, 4.0), Color("6dffa8"))
			v.draw_circle(Vector2(s.position.x + s.size.x * val, my), 7.0, Color("6dffa8"), true, -1.0, true)
		var hr: Rect2 = _rects.get("_help", Rect2())
		var ly2 := hr.position.y
		for l in CrtTheme.wrap(f2, HELP_TEXT, 17, hr.size.x, 17.0 * 0.06):
			CrtTheme.draw_text(v, f2, hr.position.x, CrtTheme.baseline(f2, 17, ly2, 17.0 * 1.5), l, 17, CrtTheme.PH_LOW, 17.0 * 0.06)
			ly2 += 17.0 * 1.5
	else:
		_button(v, "tabKb", "KEYBOARD & MOUSE", 17, 26.0, 0.1, not ctl_pad)
		_button(v, "tabPad", "CONTROLLER", 17, 26.0, 0.1, ctl_pad)
		_button(v, "pInvert", "INVERT CAMERA (UP / DOWN LOOK): " + ("ON" if Config.invert_y else "OFF"), 17, 26.0, 0.1, Config.invert_y)
		var im: Rect2 = _rects.get("_img", Rect2())
		v.draw_rect(im, Color(2.0 / 255.0, 18.0 / 255.0, 8.0 / 255.0))
		v.draw_rect(im, Color(110.0 / 255.0, 1.0, 170.0 / 255.0, 0.45), false, 1.0)
		_button(v, "pBack", "BACK", 20, 40.0, 0.16)


func _button(v: Control, id: String, text: String, fs: int, pad_l: float, sp_em: float, on: bool = false) -> void:
	var r: Rect2 = _rects.get(id, Rect2())
	var focus := pause_focus == id or on
	var f := CrtTheme.font(&"vt323b")
	var bg := Color(40.0 / 255.0, 160.0 / 255.0, 86.0 / 255.0, 0.52) if focus else Color(8.0 / 255.0, 56.0 / 255.0, 28.0 / 255.0, 0.4)
	var bd := Color(CrtTheme.PH_HI.r, CrtTheme.PH_HI.g, CrtTheme.PH_HI.b, 0.8) if focus else Color(110.0 / 255.0, 1.0, 170.0 / 255.0, 0.6)
	var col := CrtTheme.PH_WHITE if focus else CrtTheme.PH_BTN
	if focus:
		CrtTheme.glow_box(v, r, Color(110.0 / 255.0, 1.0, 170.0 / 255.0, 0.75), 22.0)
		CrtTheme.glow_box(v, r, Color(190.0 / 255.0, 1.0, 215.0 / 255.0, 0.35), 4.0)
	else:
		CrtTheme.glow_box(v, r, Color(80.0 / 255.0, 1.0, 140.0 / 255.0, 0.3), 12.0)
	v.draw_rect(r, bg)
	CrtTheme.glow_box(v, r, Color(110.0 / 255.0, 1.0, 170.0 / 255.0, 0.4) if focus else Color(80.0 / 255.0, 1.0, 140.0 / 255.0, 0.16), 16.0 if focus else 10.0, true)
	v.draw_rect(r, bd, false, 1.0)
	var y := CrtTheme.baseline(f, fs, r.position.y, r.size.y)
	if (not focus) or fmod(_time, 0.9) < 0.45:
		var a := 1.0 if focus else 0.4
		CrtTheme.draw_text(v, f, r.position.x + (15.0 if pad_l >= 40.0 else 10.0), y, ">", fs, Color(col.r, col.g, col.b, a))
	CrtTheme.draw_text(v, f, r.position.x + pad_l, y, text, fs, col, fs * sp_em)


# ---- JS functions ----

func show_controls(on: bool, pad: Variant = null) -> void:
	if pad != null:
		ctl_pad = pad
	if on != _controls:
		_controls = on
		_z_from = _z
		_z_to = 1.0 if on else 0.0
		_z_u = 0.0
		if on:
			_view.fit(_zoom)     # the page is about to be magnified: render it at that size
	_layout_page()


## The inventory page: the monitor zooms in as for the controls, and the glass takes the inventory's page size while it is up.
func show_inventory(on: bool) -> void:
	if on == _inv_open:
		return
	_inv_open = on
	_controls = false
	_z_from = _z
	_z_to = 1.0 if on else 0.0
	_z_u = 0.0
	_page.visible = not on
	_view.logical = Vector2(Inventory.W, Inventory.W * _gh / _gw) if on else _page.size
	_view.fit(_zoom)      # (zooming out, the page stays at the magnified size until the zoom is done)
	_inv.size = _view.logical
	if on:
		_inv.open()
	else:
		_inv.close()
	_layout_page()


func inventory_open() -> bool:
	return _inv_open


## Boot warm-up: the inventory page drawn once on the glass.
func warm_inventory(on: bool) -> void:
	_inv.warm(on)
	_view.refresh()


func controls_open() -> bool:
	return _controls


func pause_targets() -> Array:
	if _controls:
		return ["tabKb", "tabPad", "pInvert", "pBack"]
	var t := ["pResume", "pInventory", "pControls", "pMenu"]
	if Game.music != null:
		t.append("musicVol")
	return t


func set_pause_focus(id: String, quiet: bool = false) -> void:
	var targets := pause_targets()
	if not targets.has(id):
		id = targets[0]
	var changed := id != pause_focus
	pause_focus = id
	if changed:
		_page.queue_redraw()
		_view.refresh()
		if not quiet:
			CrtTheme.menu_sound("pauseNav")


## The pad and keyboard, every frame while paused (updatePausePad + the keydown handlers).
func update_pause_pad(dt: float) -> void:
	if _inv_open:
		_inv.update(dt)
		return
	if Inp.key_hit(KEY_I):
		_press("pInventory")
		return
	if Inp.btn(&"quick").pressed:
		show_controls(not controls_open(), true)
		set_pause_focus("tabPad" if controls_open() else "pResume")
		CrtTheme.menu_sound("pauseConfirm")
		return
	if Inp.key_hit(KEY_C):
		show_controls(not controls_open(), false)
		set_pause_focus("tabKb" if controls_open() else "pResume")
	var targets := pause_targets()
	if not targets.has(pause_focus):
		set_pause_focus(targets[0])
	var dpad := 1 if Inp.btn(&"d_down").pressed else (-1 if Inp.btn(&"d_up").pressed else 0)
	var stick := 0
	if absf(Inp.raw_ly) > 0.3:
		stick = int(signf(Inp.raw_ly))
	var dir := dpad
	if dir == 0 and stick != 0:
		if stick != _nav_dir:
			dir = stick
			_nav_t = 0.28
		else:
			_nav_t -= dt
			if _nav_t <= 0.0:
				dir = stick
				_nav_t = 0.1
	else:
		_nav_dir = 0
		_nav_t = 0.0
	# keyboard: W / S / arrows move the highlight (a key-press sound per step), Enter presses it
	if Inp.key_hit(KEY_DOWN, true) or Inp.key_hit(KEY_S, true):
		dir = 1
	elif Inp.key_hit(KEY_UP, true) or Inp.key_hit(KEY_W, true):
		dir = -1
	if dir != 0:
		set_pause_focus(targets[posmod(targets.find(pause_focus) + dir, targets.size())])
	_nav_dir = stick
	var left: bool = Inp.btn(&"d_left").pressed or Inp.key_hit(KEY_LEFT)
	var right: bool = Inp.btn(&"d_right").pressed or Inp.key_hit(KEY_RIGHT)
	if controls_open() and (left or right):
		if pause_focus == "tabKb" or pause_focus == "tabPad":
			var pad := right
			show_controls(true, pad)
			set_pause_focus("tabPad" if pad else "tabKb")
	elif not controls_open() and pause_focus == "musicVol":
		var delta := -5.0 if left else (5.0 if right else 0.0)
		if delta != 0.0:
			_set_music(float(Game.music.volume) * 100.0 + delta)
	if Inp.btn(&"b").pressed:
		if controls_open():
			show_controls(false)
			set_pause_focus("pResume")
			CrtTheme.menu_sound("pauseConfirm")
		else:
			Game.ui.set_paused(false)
			Game.ui.lock()
		return
	if Inp.btn(&"jump").pressed:
		if pause_focus == "musicVol":
			_set_music(float(Game.music.volume) * 100.0 + 5.0)
		else:
			_press(pause_focus)
	elif Inp.key_hit(KEY_ENTER) or Inp.key_hit(KEY_KP_ENTER):
		if pause_focus != "musicVol":
			_press(pause_focus)


func _set_music(v: float) -> void:
	Game.music.volume = clampf(v, 0.0, 100.0) * 0.01
	_page.queue_redraw()
	_view.refresh()


func _press(id: String) -> void:
	if id != "pResume":
		CrtTheme.menu_sound("pauseConfirm")   # Gamepad-generated clicks and mouse/keyboard activations share the same UI sound
	match id:
		"pResume":
			Game.ui.set_paused(false)
			Game.ui.lock()
		"pMenu":
			Game.ui.back_to_menu()
		"pInventory":
			show_inventory(true)
		"pControls":
			show_controls(true, Inp.using_pad)
			set_pause_focus("tabPad" if ctl_pad else "tabKb", true)
		"pBack":
			show_controls(false)
			set_pause_focus("pResume", true)
		"pInvert":
			Config.invert_y = not Config.invert_y
			_layout_page()
		"tabKb":
			show_controls(true, false)
			set_pause_focus("tabKb", true)
		"tabPad":
			show_controls(true, true)
			set_pause_focus("tabPad", true)


func on_pause(p: bool) -> void:
	visible = p
	set_process(p)
	_view.live = p
	if p:
		_z = 0.0
		_z_u = 1.0
		_controls = false
	if _inv_open or not p:
		_inv_open = false
		_inv.close()
		_page.visible = true
	if p:
		pc_layout()
		pause_focus = "pResume"
	_view.arm_glitch(p)


func _process(delta: float) -> void:
	_time += delta
	# the zoom: transform .4s cubic-bezier(.2,.8,.2,1)
	if _z_u < 1.0:
		_z_u = minf(1.0, _z_u + delta / 0.4)
		_z = lerpf(_z_from, _z_to, CrtTheme.bezier(_z_u, 0.2, 0.8, 0.2, 1.0))
		_place_stage()
		if _z_u >= 1.0 and _z_to == 0.0:
			_view.fit(1.0)
			_place_stage()
	# pzGlow 4s ease-in-out: .82 -> 1 -> .82
	var g := lerpf(0.82, 1.0, 0.5 - 0.5 * cos(_time / 4.0 * TAU))
	(_glow_add.material as ShaderMaterial).set_shader_parameter(&"opacity", g)
	(_glow_mul.material as ShaderMaterial).set_shader_parameter(&"opacity", g)
	_page.queue_redraw()
	if _inv_open:
		_inv.frame(delta)


# ---- the mouse ----

func _to_page(p: Vector2) -> Vector2:
	var l: Vector2 = _view.get_global_transform().affine_inverse() * p
	return l * (_view.logical.x / _view.size.x)


func _target_at(p: Vector2) -> String:
	for id: String in _rects:
		if not id.begins_with("_") and (_rects[id] as Rect2).grow(4.0 if id == "musicVol" else 0.0).has_point(p):
			return id
	return ""


func _gui_input(event: InputEvent) -> void:
	if _inv_open:
		if event is InputEventMouseMotion:
			_inv.mouse_move(_to_page((event as InputEventMouseMotion).global_position))
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_inv.mouse_click(_to_page((event as InputEventMouseButton).global_position))
		return
	if event is InputEventMouseMotion:
		var p := _to_page((event as InputEventMouseMotion).global_position)
		if _dragging:
			_music_at(p)
			return
		var id := _target_at(p)
		if id != "" and id != pause_focus and id != "musicVol":
			set_pause_focus(id, true)      # mouse hover also "presses a key"
			CrtTheme.menu_sound("pauseNav")
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index != MOUSE_BUTTON_LEFT:
			return
		if not b.pressed:
			_dragging = false
			return
		var gp := b.global_position
		var p := _to_page(gp)
		var id := _target_at(p)
		if id == "musicVol":
			_dragging = true
			set_pause_focus(id, true)
			_music_at(p)
		elif id != "":
			_press(id)
		else:
			# clicking the monitor does nothing; clicking outside it resumes
			var st: Vector2 = _stage.get_global_transform().affine_inverse() * gp
			if not Rect2(Vector2.ZERO, _stage.size).has_point(st):
				Game.ui.set_paused(false)
				Game.ui.lock()


func _music_at(p: Vector2) -> void:
	var s: Rect2 = _rects.get("musicVol", Rect2())
	if s.size.x > 0.0:
		_set_music((p.x - s.position.x) / s.size.x * 100.0)
