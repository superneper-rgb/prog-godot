class_name Wheel
extends Control
## The weapon wheel inside the handheld terminal, ported from class Wheel (index.html hud.js) and its CSS. It has N = 12 equal positions, clockwise from the top: 0 = FISTS (permanent),
## 1..n = weapon slots 0..n-1 (right side), 6 = unused gap at the bottom, 7..11 = POWER slots (left side, reserved for powers: shown as locked placeholders, not selectable yet).
## Items are addressed by a logical index i: 0..n-1 weapons, n fists, n+1..n+POWERS powers. pos_of / logical_at convert between that and the wheel position.
## Hold Y / Q to open; the game is frozen while it is open (frame logic in core/game.gd). E / B presses the terminal's button: the inventory page <-> the wheel.

const N := 12
const POWERS := 5
const ART := "res://assets/ui/cut/"

## The disc, slots and centre text (CSS .wh-stage), in stage px with the wheel's centre at the middle of the view.
class StageView extends Control:
	var w: Wheel
	func _draw() -> void:
		if w != null:
			w._draw_stage(self)


## The inventory page (CSS .invbox), a 520 x 380 design.
class InvView extends Control:
	var w: Wheel
	func _draw() -> void:
		if w != null:
			w._draw_inv(self)


var n := Weapons.WHEEL_WEAPONS
var powers_on := false       # powers_on: flip to true when powers exist (and give item() / refresh() their content)
var open_ := false
var sel := 0
var cx := 0.0
var cy := 0.0
var arc_a := 0.0
var mode := "wheel"          # "wheel" | "inv" (the terminal's inventory page)
var busy := false
var info := Callable()       # info() -> {money, hp, max_hp} for the inventory header
var pip := true              # the terminal art is there (it always is here: baked files)
var combat_ref: Combat = null

var is_open: bool:
	get:
		return open_

var _dim: ColorRect
var _pip_root: Control       # .wh-pip: the art, offset for the slide-in
var _frame: TextureRect
var _frame_mat: ShaderMaterial
var _frame_tex: Array[Texture2D] = []
var _hand_tex: Array[Texture2D] = []
var _press_tex: Array[Texture2D] = []
var _press_hand: Array[Texture2D] = []
var _crt: ColorRect
var _bloom: Array[ColorRect] = []
var _glow: ColorRect
var _stage: CrtScreen
var _stage_view: StageView
var _inv: CrtScreen
var _inv_view: InvView
var _s := 1.0
var _wu := 0.5
var _iu := 0.5
var _center := Vector2.ZERO
var _frame_shown := -1
var _press_shown := -1
var _live := false
var _t_open := -1.0
var _t_press := -1.0
var _to_inv := false
var _op := 0.0
var _stage_scale := 0.94
var _stage_op := 0.0
var _slide := 70.0
var _anim := 0.0
var _arc_from := 0.0
var _arc_to := 0.0
var _arc_t := 1.0
var _sel_k: PackedFloat32Array = []  # each slot's selection scale, easing to 1.08
var _gone: PackedFloat32Array = []   # flash left on a slot that lost its weapon
var _flick_t := 0.0
var _white_hands := false


func _init() -> void:
	name = "Wheel"
	CrtTheme.full(self)
	visible = false
	z_index = 15
	sel = n
	_sel_k.resize(n + POWERS + 1)
	_gone.resize(n + POWERS + 1)
	for i in _sel_k.size():
		_sel_k[i] = 1.0
		_gone[i] = 0.0


## The handheld terminal behind the wheel: the 3 frames. (The JS cut the sheet in the browser at boot: flood fills, the arm continued, the glass painted. tools/build_ui_art.py does those same steps once, into assets/ui/cut.)
func _build_pip() -> void:
	for i in 3:
		_frame_tex.append(load(ART + "pip-%d.png" % i))
		_hand_tex.append(load(ART + "pip-hand-%d.png" % i))


## The button-press frames (a finger pressing a button, 4 frames), baked the same way.
func _build_press() -> void:
	for i in 4:
		_press_tex.append(load(ART + "press-%d.png" % i))
		_press_hand.append(load(ART + "press-hand-%d.png" % i))


func _ready() -> void:
	_build_pip()
	_build_press()
	# #wheel.pip::before: no live blur of the game behind the terminal; a dark tint (the JS found the blur stalled its compositor, and it reads the same)
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 6.0 / 255.0, 2.0 / 255.0, 0.78)
	CrtTheme.full(_dim)
	add_child(_dim)
	_pip_root = Control.new()
	_pip_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pip_root)
	_frame = TextureRect.new()
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_frame_mat = CrtTheme.mat("res://ui/pip_frame.gdshader")
	_frame.material = _frame_mat
	_pip_root.add_child(_frame)
	var glass: Texture2D = load(ART + "pip-glass.png")
	_crt = ColorRect.new()
	_crt.color = Color.WHITE
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cm := CrtTheme.mat("res://ui/pip_crt.gdshader")
	cm.set_shader_parameter(&"glass_tex", glass)
	_crt.material = cm
	_pip_root.add_child(_crt)
	# the bloom: the wide halo steady, the tight one flickering
	for spec: Array in [["pip-bloom.png", 0.85], ["pip-bloom-wide.png", 0.7]]:
		for sh: String in ["res://ui/pip_bloom_mul.gdshader", "res://ui/pip_bloom.gdshader"]:
			var b := ColorRect.new()
			b.color = Color.WHITE
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var m := CrtTheme.mat(sh)
			m.set_shader_parameter(&"blur_tex", load(ART + spec[0]))
			m.set_shader_parameter(&"glass_tex", glass)
			m.set_shader_parameter(&"opacity", spec[1])
			b.material = m
			_pip_root.add_child(b)
			_bloom.append(b)
	_glow = ColorRect.new()
	_glow.color = Color.WHITE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.material = CrtTheme.mat("res://ui/pip_glow.gdshader")
	add_child(_glow)
	_stage = _make_screen()
	_stage_view = StageView.new()
	_stage_view.w = self
	_stage_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.content.add_child(_stage_view)
	_inv = _make_screen()
	_inv_view = InvView.new()
	_inv_view.w = self
	_inv_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inv.content.add_child(_inv_view)
	_prewarm()
	set_process(false)


func _make_screen() -> CrtScreen:
	var s := CrtScreen.new(Vector2(500, 500))
	# the stage floats on the art's own green glass: nothing behind it, no scanlines of its own (the art has them), a faint phosphor glow
	s.param(&"bg_center", Color(0, 0, 0, 0))
	s.param(&"bg_edge", Color(0, 0, 0, 0))
	s.param(&"vig_inner", Color(0, 0, 0, 0))
	s.param(&"vig_outer", Color(0, 0, 0, 0))
	s.param(&"scan", 0.14)
	s.param(&"roll_alpha", 0.0)
	s.param(&"flick_period", 0.0)
	s.param(&"glow_tint", Vector3(0.314, 1.0, 0.51))
	s.param(&"glow_amount", 0.45)
	s.param(&"glow_radius", 5.0)
	s.param(&"glow_floor", 0.3)
	s.viewport.msaa_2d = Viewport.MSAA_4X      # the stage's circles (the browser antialiases its own)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = false
	add_child(s)
	return s


## Fit to the window now and on every resize. ENGINE DIFFERENCE: the JS resampled and sharpened every frame to the window's size on a worker (_hiSwap, _hiList, _swapIn, _resampler, _sendSources), because a browser
## downscales a canvas poorly. Here the frames carry mipmaps and ui/pip_frame.gdshader does the same light unsharp mask per pixel, so nothing needs resampling, on resize or on a character change (Tommy's hands are a mask).
func _prewarm() -> void:
	_layout_pip()
	var vp := get_viewport()
	if not vp.size_changed.is_connected(_layout_pip):
		vp.size_changed.connect(_layout_pip)


## Boot warm-up: the frames are already in video memory (loaded in _ready); nothing to do but fit them to this window.
func warm() -> void:
	_layout_pip()


## Boot warm-up, after warm(): show the open terminal (frames, CRT, bloom, glow, stage, page) for a few frames behind the boot screen, so its shaders and viewports are made then instead of on the first real open.
func prerender(frames: int = 3) -> void:
	if open_:
		return
	visible = true
	modulate.a = 1.0
	_frame_shown = 2
	_show_current_frame()
	for c: Control in [_crt, _glow, _stage, _inv] + _bloom:
		c.visible = true
	_stage.refresh()
	_inv.refresh()
	for i in frames:
		await get_tree().process_frame
	for c: Control in [_crt, _glow, _stage, _inv] + _bloom:
		c.visible = false
	_frame_shown = -1
	_frame.visible = false
	modulate.a = 0.0
	visible = false


## Size the terminal to the window and centre the final frame's screen on the wheel.
func _layout_pip() -> void:
	var vp := get_viewport_rect().size
	_center = vp * 0.5
	_s = vp.y * 1.0 / float(UiArt.PIP_FH)
	var scr := UiArt.PIP_SCR
	# the whole wheel sits inside the glass. (JS 0.84 of its height; 0.92 here so its small print stays readable at 720p.)
	_wu = maxf(0.4, minf(0.95, scr.size.y * _s * 0.92 / 500.0))
	_iu = minf(scr.size.x * _s * 0.92 / 520.0, scr.size.y * _s * 0.92 / 380.0)    # the inventory page: a 520 x 380 design scaled to fit the glass
	_pip_root.position = _center + Vector2(0.0, _slide)
	var fw := float(UiArt.PIP_FW) * _s
	var fh := float(UiArt.PIP_FH) * _s
	var at := Vector2(-scr.position.x * _s, -scr.position.y * _s)
	for c: Control in [_crt] + _bloom:
		c.position = at
		c.size = Vector2(fw, fh)
	var K := 1.0 / 667.0
	var y0 := maxf(0.0, scr.position.y - scr.size.y * 0.5 - 4.0) / float(UiArt.PIP_FH)
	var hh := (scr.size.y + 8.0) / float(UiArt.PIP_FH)
	(_crt.material as ShaderMaterial).set_shader_parameter(&"glass_box", Vector4(y0, hh, K, 0.0))
	var gw := scr.size.x * _s * 1.08
	var gh := scr.size.y * _s * 1.08
	_glow.size = Vector2(gw, gh)
	_glow.position = _center - _glow.size * 0.5
	# the stage and the page are as big as the glass (it clips them), their logical px scaled by --u / --iu
	var gs := scr.size * _s * 0.96
	for s: CrtScreen in [_stage, _inv]:
		s.size = gs
		s.position = _center - gs * 0.5
		s.pivot_offset = gs * 0.5
	_stage.set_logical(gs / _wu)
	_stage_view.size = _stage.logical
	_inv.set_logical(gs / _iu)
	_inv_view.size = _inv.logical
	_show_current_frame()


func _show_current_frame() -> void:
	var scr := UiArt.PIP_SCR
	if _press_shown >= 0:
		# button-press frames: scaled so their screen matches the main terminal's screen, each pinned by its own screen centre
		var r := scr.size.x / UiArt.PRESS_SCR[3].size.x
		var k := _s * r
		var sz := UiArt.PRESS_SIZE[_press_shown] * k
		_frame.texture = _press_tex[_press_shown]
		_frame_mat.set_shader_parameter(&"hand_tex", _press_hand[_press_shown])
		_frame.size = sz
		_frame.position = -UiArt.PRESS_SCR[_press_shown].position * k
	elif _frame_shown >= 0:
		_frame.texture = _frame_tex[_frame_shown]
		_frame_mat.set_shader_parameter(&"hand_tex", _hand_tex[_frame_shown])
		_frame.size = Vector2(UiArt.PIP_FW, UiArt.PIP_FH) * _s
		_frame.position = -scr.position * _s
	_frame.visible = _frame_shown >= 0 or _press_shown >= 0
	_frame_mat.set_shader_parameter(&"white_hands", 1.0 if _white_hands else 0.0)


## Tommy's hands are white.
func set_character(id: String) -> void:
	_white_hands = id == "tommy"
	_frame_mat.set_shader_parameter(&"white_hands", 1.0 if _white_hands else 0.0)


# ---- logic, as JS ----

## wheel position (0..11, clockwise from the top) of logical item i
func pos_of(i: int) -> int:
	return 0 if i == n else (i + 1 if i < n else 7 + (i - n - 1))


## logical item at wheel position p, or -1 for the unused bottom gap
func logical_at(p: int) -> int:
	return n if p == 0 else (p - 1 if p <= n else (n + 1 + (p - 7) if p >= 7 else -1))


## can the selection land on item i? (weapons + fists always; powers once powers_on)
func selectable(i: int) -> bool:
	return i >= 0 and (i <= n or powers_on)


## what wheel position i holds: -1 fists, null an empty slot, else a weapon index (a power slot: null until powers exist)
func item(i: int, combat: Combat) -> Variant:
	if i == n:
		return -1
	if i < n:
		return combat.slots[i] if combat != null else null
	return null


func slot_of(combat: Combat) -> int:
	if combat == null or combat.cur < 0:
		return n
	var s := combat.slots.find(combat.cur)
	return n if s < 0 else s


func open(combat: Combat) -> void:
	open_ = true
	combat_ref = combat
	sel = slot_of(combat)
	cx = 0.0
	cy = 0.0
	visible = true
	set_process(true)
	_pip_start()
	_stage_scale = 0.94
	for i in _sel_k.size():
		_sel_k[i] = 1.08 if i == sel else 1.0
	_arc_to = float(pos_of(sel)) * 360.0 / N
	arc_a = _arc_to
	_arc_from = arc_a
	_arc_t = 1.0
	refresh(combat)
	CrtTheme.sfx("wheelOpen")


func close() -> void:
	open_ = false
	_pip_stop()
	CrtTheme.sfx("wheelClose")


## Frame 1 -> 2 -> 3, then the wheel + glow switch on (the timing itself runs in _process).
func _pip_start() -> void:
	_pip_stop()
	_layout_pip()
	if Game.hud != null:
		Game.hud.set_wheel_pip(true)
	Game.ui.set_ver_hidden(true)
	if Game.sfx != null:
		Game.sfx.crt_hum(true)
	_slide = 70.0
	_t_open = 0.0
	_frame_shown = 0
	_press_shown = -1
	_show_current_frame()


func _pip_stop() -> void:
	_t_open = -1.0
	_t_press = -1.0
	mode = "wheel"
	busy = false
	_press_shown = -1
	_stage.visible = false
	_inv.visible = false
	_live = false
	_stage_op = 0.0
	if Game.hud != null:
		Game.hud.set_wheel_pip(false)
	if Game.ui != null:
		Game.ui.set_ver_hidden(false)
	if Game.sfx != null:
		Game.sfx.crt_hum(false)


## The live CRT effects on the glass switch on (the rolling band and the flicker are ui/pip_crt.gdshader; _process hands it a new flicker level every frame).
func _crt_start() -> void:
	_crt.visible = true
	_glow.visible = true
	for b in _bloom:
		b.visible = true


## The inventory page shown on the terminal: cash, health, and every carried weapon with its ammo.
func _refresh_inv(combat: Combat) -> void:
	combat_ref = combat
	_inv_view.queue_redraw()
	_inv.refresh()


## The pick on release: -1 fists, a weapon index, or null (an empty slot: keep what is in hand).
func choice(combat: Combat) -> Variant:
	return item(sel, combat)


func select(i: int, combat: Combat) -> void:
	if i != sel:
		sel = i
		CrtTheme.sfx("tick")
		refresh(combat)


## Flash a slot that just lost its weapon.
func flash(i: int) -> void:
	if i >= 0 and i < _gone.size():
		_gone[i] = 1.0
		_anim = maxf(_anim, 0.36)


func refresh(combat: Combat) -> void:
	combat_ref = combat
	# the highlight arc follows the selection the short way round
	var t := float(pos_of(sel)) * 360.0 / N
	var dlt := fposmod(fposmod(t - arc_a, 360.0) + 540.0, 360.0) - 180.0
	_arc_from = arc_a
	_arc_to = arc_a + dlt
	_arc_t = 0.0
	_anim = maxf(_anim, 0.2)
	_stage_view.queue_redraw()
	_stage.refresh()


## E with the wheel up: the finger presses a button (4 frames, left to right), the device settles back to the held pose and the screen switches between the wheel and the inventory page.
func toggle_inv(combat: Combat) -> void:
	if busy or not open_ or not _live:
		return
	busy = true
	combat_ref = combat
	_to_inv = mode == "wheel"
	CrtTheme.sfx("tick")
	_frame_shown = -1
	_press_shown = 0
	_t_press = 0.0
	_show_current_frame()
	_stage.visible = false
	_inv.visible = false


## Returns after reading stick / mouse; the game is paused while this is open.
func update(dt: float, combat: Combat) -> void:
	combat_ref = combat
	if mode != "wheel":       # the inventory page does not move the selection
		return
	var l := Inp.look
	var m := Inp.move
	var vx := 0.0
	var vy := 0.0
	if l.mag > 0.35:
		vx = l.x
		vy = l.y
	elif m.mag > 0.35:
		vx = m.x
		vy = -m.y
	var inv := -1.0 if Config.invert_y else 1.0
	cx = clampf(cx - Inp.look_yaw * 4.5, -1.4, 1.4)
	cy = clampf(cy + Inp.look_pitch * inv * 4.5, -1.4, 1.4)
	if Vector2(vx, vy).length() <= 0.35:
		vx = cx
		vy = cy
	if Vector2(vx, vy).length() > 0.45:
		var ang := atan2(vx, -vy)
		var p := posmod(roundi(ang / (TAU / N)), N)
		var i := logical_at(p)
		if selectable(i):     # the power slots and the bottom gap are not selectable yet
			select(i, combat)


func _process(delta: float) -> void:
	# #wheel opacity .14s, the terminal sliding up .32s cubic-bezier(.2,.9,.3,1)
	_op = move_toward(_op, 1.0 if open_ else 0.0, delta / 0.14)
	modulate.a = _op
	if not open_ and _op <= 0.0:
		visible = false
		_frame_shown = -1
		set_process(false)
		return
	if open_ and _t_open >= 0.0:
		_t_open += delta
		var u := minf(1.0, _t_open / 0.32)
		_slide = 70.0 * (1.0 - CrtTheme.bezier(u, 0.2, 0.9, 0.3, 1.0))
		_pip_root.position = _center + Vector2(0.0, _slide)
		if not _live:
			if _t_open >= 0.19:
				_frame_shown = 2
				_show_current_frame()
				_live = true
				_crt_start()
				_stage.visible = mode == "wheel"
				_stage.refresh()
			elif _t_open >= 0.09 and _frame_shown != 1:
				_frame_shown = 1
				_show_current_frame()
		if u >= 1.0 and _live:
			_t_open = -1.0
	if not _live:
		_crt.visible = false
		_glow.visible = false
		for b in _bloom:
			b.visible = false
	else:
		# pipFlicker 3.1s on the tight bloom and the glow
		var f := _pip_flicker(fmod(Time.get_ticks_msec() / 1000.0, 3.1) / 3.1)
		(_glow.material as ShaderMaterial).set_shader_parameter(&"opacity", f)
		(_bloom[0].material as ShaderMaterial).set_shader_parameter(&"opacity", 0.85 * f)
		(_bloom[1].material as ShaderMaterial).set_shader_parameter(&"opacity", 0.85 * f)
		(_crt.material as ShaderMaterial).set_shader_parameter(&"flicker", 0.02 + randf() * 0.05)
		# the stage: scale(--u) over .2s cubic-bezier(.2,1.1,.4,1), opacity .18s
		_stage_scale = move_toward(_stage_scale, 1.0, delta / 0.2 * 0.06)
		_stage_op = move_toward(_stage_op, 1.0, delta / 0.18)
		_stage.scale = Vector2.ONE * _stage_scale
		_stage.modulate.a = _stage_op
		_inv.modulate.a = _stage_op
	if _t_press >= 0.0:
		_t_press += delta
		var fr := 0
		if _t_press >= 0.24:
			fr = 3
		elif _t_press >= 0.16:
			fr = 2
		elif _t_press >= 0.08:
			fr = 1
		if fr != _press_shown:
			_press_shown = fr
			_show_current_frame()
		if _t_press >= 0.38:
			_t_press = -1.0
			_press_shown = -1
			_frame_shown = 2
			_show_current_frame()
			mode = "inv" if _to_inv else "wheel"
			_stage.visible = mode == "wheel"
			_inv.visible = mode == "inv"
			if _to_inv:
				_refresh_inv(combat_ref)
			else:
				refresh(combat_ref)
			busy = false
			CrtTheme.sfx("tick")
	# the arc (.14s cubic-bezier(.3,.9,.4,1)), the selected slot's scale (.12s), a lost weapon's red flash (.35s): the picture only redraws while something moves
	if _arc_t < 1.0:
		_arc_t = minf(1.0, _arc_t + delta / 0.14)
		arc_a = lerpf(_arc_from, _arc_to, CrtTheme.bezier(_arc_t, 0.3, 0.9, 0.4, 1.0))
	var moving := _arc_t < 1.0
	for i in _sel_k.size():
		var want := 1.08 if i == sel else 1.0
		if _sel_k[i] != want:
			_sel_k[i] = move_toward(_sel_k[i], want, delta / 0.12 * 0.08)
			moving = true
		if _gone[i] > 0.0:
			_gone[i] = maxf(0.0, _gone[i] - delta / 0.35)
			moving = true
	if moving and _stage.visible:
		_stage_view.queue_redraw()
		_stage.refresh()


static func _pip_flicker(p: float) -> float:
	var keys := [[0.0, 0.85], [0.08, 1.0], [0.12, 0.7], [0.30, 0.95], [0.55, 0.8], [0.57, 1.0], [1.0, 0.85]]
	for i in keys.size() - 1:
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if p >= float(a[0]) and p < float(b[0]):
			var u := (p - float(a[0])) / (float(b[0]) - float(a[0]))
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(a[1], b[1], u)
	return 0.85


# ---- drawing ----

const C_DISC := Color(3.0 / 255.0, 26.0 / 255.0, 11.0 / 255.0)
const C_LINE := Color(110.0 / 255.0, 1.0, 160.0 / 255.0)


func _draw_stage(v: Control) -> void:
	var c := v.size * 0.5
	var combat := combat_ref
	# .wh-disc: the ring, r 130..250, with its 2 px inset edge
	v.draw_arc(c, 190.0, 0.0, TAU, 180, C_DISC, 120.0, false)
	v.draw_arc(c, 249.0, 0.0, TAU, 180, Color(C_LINE.r, C_LINE.g, C_LINE.b, 0.55), 2.0, false)
	# .wh-arc: the faint sector and the bright outer rim of the selection
	var w := deg_to_rad(180.0 / N - 3.0)
	var ca := deg_to_rad(arc_a) - PI * 0.5
	v.draw_arc(c, 190.5, ca - w, ca + w, 24, Color(1, 1, 1, 0.055), 119.0, false)
	v.draw_arc(c, 248.0, ca - w, ca + w, 24, Color(120.0 / 255.0, 1.0, 160.0 / 255.0, 0.8), 2.0, false)
	for i in n + POWERS + 1:
		_draw_slot(v, c, i, combat)
	_draw_center(v, c, combat)


func _draw_slot(v: Control, c: Vector2, i: int, combat: Combat) -> void:
	var a := float(pos_of(i)) * TAU / N
	var p := c + Vector2(sin(a) * 190.0, -cos(a) * 190.0)
	var is_sel := i == sel
	var k: float = _sel_k[i]
	var r := 44.0 * k
	var power := i > n
	var it: Variant = item(i, combat) if not power else null
	var empty := power or it == null
	var fade := 0.5 if power else 1.0
	var col := Color("5fe08a")
	var bg := Color(40.0 / 255.0, 160.0 / 255.0, 80.0 / 255.0, 0.06)
	var bd := Color(90.0 / 255.0, 1.0, 140.0 / 255.0, 0.2)
	if empty:
		col = Color(95.0 / 255.0, 224.0 / 255.0, 138.0 / 255.0, 0.3)
		bg = Color(0, 0, 0, 0)
		bd = Color(90.0 / 255.0, 1.0, 140.0 / 255.0, 0.15)
	if is_sel:
		col = Color("d6ffe2")
		bg = Color(16.0 / 255.0, 84.0 / 255.0, 38.0 / 255.0)
		bd = Color(120.0 / 255.0, 1.0, 160.0 / 255.0, 0.65)
		for g in 4:      # box-shadow: 0 0 14px rgba(70,255,120,.35)
			v.draw_circle(p, r + 1.0 + g * 2.4, Color(70.0 / 255.0, 1.0, 120.0 / 255.0, 0.07), true, -1.0, false)
	if _gone[i] > 0.0:        # whGone: a red flash fading out
		var gk: float = _gone[i]
		bg = bg.lerp(Color(1.0, 90.0 / 255.0, 74.0 / 255.0, 0.28), gk)
		bd = bd.lerp(Color(1.0, 90.0 / 255.0, 74.0 / 255.0, 0.7), gk)
	bg.a *= fade
	bd.a *= fade
	col.a *= fade
	if bg.a > 0.0:
		v.draw_circle(p, r, bg, true, -1.0, false)
	if empty and not is_sel:
		# border-style: dashed
		var dashes := 22
		for d in dashes:
			var a0 := TAU * d / dashes
			v.draw_arc(p, r - 0.5, a0, a0 + TAU / dashes * 0.55, 4, bd, 1.5, false)
	else:
		v.draw_arc(p, r - 0.5, 0.0, TAU, 64, bd, 1.5, false)
	if empty:
		var f := CrtTheme.font(&"raj600")
		var t := "POWER" if power else "EMPTY"
		CrtTheme.draw_center(v, f, p.x, CrtTheme.baseline(f, 14, p.y - 8.0, 16.0), t, 14, col, 14.0 * 0.24)
		return
	var iw := 60.0 * k
	var ih := 30.0 * k
	var wid: int = it
	var icon := WeaponIcons.tex("fists") if wid < 0 else WeaponIcons.tex(Weapons.WEAPONS[wid].id)
	var has_bar := wid >= 0
	var oy := -5.0 * k if has_bar else 0.0
	v.draw_texture_rect(icon, Rect2(p.x - iw * 0.5, p.y - ih * 0.5 + oy, iw, ih), false, col)
	if has_bar:
		var we := Weapons.WEAPONS[wid]
		var f := (combat.ammo[wid] + combat.reserve[wid]) / float(we.max)
		var bw := 40.0 * k
		var bx := p.x - bw * 0.5
		var by := p.y + ih * 0.5 + oy + 7.0 * k
		v.draw_rect(Rect2(bx, by, bw, 3.0), Color(1, 1, 1, 0.12))
		v.draw_rect(Rect2(bx, by, bw * clampf(f, 0.0, 1.0), 3.0), Color("ff5a4a") if f < 0.25 else Color("8bffac"))
	if combat != null and wid == combat.cur:
		# .slot.cur::after: the small dot of what is in hand
		v.draw_circle(Vector2(p.x, p.y - r + 12.0), 2.0, Color("e6eef6"), true, -1.0, false)
		v.draw_circle(Vector2(p.x, p.y - r + 12.0), 4.5, Color(1, 1, 1, 0.18), true, -1.0, false)


func _draw_center(v: Control, c: Vector2, combat: Combat) -> void:
	# .wh-center: 248 px circle
	v.draw_circle(c, 124.0, C_DISC, true, -1.0, false)
	v.draw_arc(c, 123.5, 0.0, TAU, 96, Color(C_LINE.r, C_LINE.g, C_LINE.b, 0.5), 1.0, false)
	var it: Variant = item(sel, combat)
	var carried := 0
	if combat != null:
		for k: Variant in combat.slots:
			if k != null:
				carried += 1
	var lbl := "SLOT %d / %d" % [sel + 1, n]
	var small := lbl
	var title := "EMPTY"
	var tg := "BUY OR PICK UP A WEAPON"
	var am := ""
	var am_i := ""
	var hk := false
	if sel > n:
		small = "LOCKED"
		title = "POWER"
		tg = ""
	elif it == null:
		pass
	elif int(it) < 0:
		small = "UNARMED"
		title = "FISTS"
		tg = "3-HIT COMBO"
	else:
		var w := Weapons.WEAPONS[int(it)]
		title = w.name
		tg = w.tag
		am = str(roundi(combat.ammo[int(it)]))
		am_i = "%" if w.energy else "/ %d" % int(combat.reserve[int(it)])
		hk = true
	# (sizes: the JS's #wheel.pip .wh-center, its small print a touch bigger so it reads at 720p, where --u is small)
	const S_SMALL := 16
	const S_H2 := 27
	const S_TG := 16
	const S_AM := 38
	const S_AMI := 20
	const S_HK := 15
	const S_CAP := 14
	var fw := CrtTheme.font(&"raj600")
	var fb := CrtTheme.font(&"raj700")
	var w_in := 200.0
	var title_lines := CrtTheme.wrap(fb, title, S_H2, w_in, S_H2 * 0.1)
	var tg_lines := CrtTheme.wrap(fw, tg, S_TG, w_in, S_TG * 0.18) if tg != "" else PackedStringArray()
	var lh_small := S_SMALL * 1.2
	var lh_h2 := S_H2 * 1.05
	var lh_tg := S_TG * 1.2
	var total := lh_small + 5.0 + lh_h2 * title_lines.size() + (3.0 + lh_tg * tg_lines.size() if tg != "" else 0.0)
	if am != "":
		total += 9.0 + S_AM
	if hk:
		total += 11.0 + S_HK * 1.2
	var y := c.y - total * 0.5 - 6.0
	CrtTheme.draw_center(v, fw, c.x + S_SMALL * 0.12, CrtTheme.baseline(fw, S_SMALL, y, lh_small), small, S_SMALL, Color("4fcf78"), S_SMALL * 0.24)
	y += lh_small + 5.0
	for l in title_lines:
		CrtTheme.draw_center(v, fb, c.x, CrtTheme.baseline(fb, S_H2, y, lh_h2), l, S_H2, Color("b8ffcb"), S_H2 * 0.1)
		y += lh_h2
	if tg != "":
		y += 3.0
		for l in tg_lines:
			CrtTheme.draw_center(v, fw, c.x, CrtTheme.baseline(fw, S_TG, y, lh_tg), l, S_TG, Color("4fcf78"), S_TG * 0.18)
			y += lh_tg
	if am != "":
		y += 9.0
		var aw := CrtTheme.text_w(fb, am, S_AM, S_AM * 0.04) + 3.0 + CrtTheme.text_w(fb, am_i, S_AMI, S_AM * 0.04)
		var ax := c.x - aw * 0.5
		var ab := CrtTheme.baseline(fb, S_AM, y, S_AM)
		ax = CrtTheme.draw_text(v, fb, ax, ab, am, S_AM, Color("b8ffcb"), S_AM * 0.04)
		CrtTheme.draw_text(v, fb, ax + 3.0, ab, am_i, S_AMI, Color("4fcf78"), S_AM * 0.04)
		y += S_AM
	if hk:
		y += 11.0
		_draw_hk(v, c.x, y, "X", "DISCARD", S_HK)
	var cap := "%d / %d CARRIED" % [carried, n]
	CrtTheme.draw_center(v, fw, c.x + S_CAP * 0.12, c.y + 124.0 - 27.0, cap, S_CAP, Color(79.0 / 255.0, 207.0 / 255.0, 120.0 / 255.0, 0.85), S_CAP * 0.24)


## .hk: a key chip and its word.
func _draw_hk(v: Control, cx_: float, top: float, key: String, word: String, fs: int) -> void:
	var f := CrtTheme.font(&"raj700")
	var kw := maxf(16.0, CrtTheme.text_w(f, key, fs) + 10.0)
	var tw := CrtTheme.text_w(f, word, fs, fs * 0.2)
	var x := cx_ - (kw + 7.0 + tw) * 0.5
	var h := fs * 1.3
	v.draw_style_box(CrtTheme.panel(Color(0, 0, 0, 0), 5, Color(90.0 / 255.0, 1.0, 140.0 / 255.0, 0.45)), Rect2(x, top, kw, h))
	v.draw_string(f, Vector2(x + (kw - CrtTheme.text_w(f, key, fs)) * 0.5, CrtTheme.baseline(f, fs, top, h)), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("b8ffcb"))
	CrtTheme.draw_text(v, f, x + kw + 7.0, CrtTheme.baseline(f, fs, top, h), word, fs, Color("4fcf78"), fs * 0.2)


## The inventory page shown on the terminal: cash, health, and every carried weapon with its ammo.
func _draw_inv(v: Control) -> void:
	var combat := combat_ref
	var inf: Dictionary = info.call() if info.is_valid() else {}
	var hp: float = inf.get("hp", 0.0)
	var mhp: float = inf.get("max_hp", 100.0)
	var pct := clampf(hp / (mhp if mhp != 0.0 else 100.0), 0.0, 1.0)
	var org := (v.size - Vector2(520, 380)) * 0.5
	var fb := CrtTheme.font(&"raj700")
	var fw := CrtTheme.font(&"raj600")
	var x0 := org.x + 22.0
	var x1 := org.x + 520.0 - 22.0
	var y := org.y + 14.0
	var line := Color(110.0 / 255.0, 1.0, 160.0 / 255.0, 0.35)
	var ink := Color("c8ffd8")
	var dim := Color("4fcf78")
	# .ih
	var by := CrtTheme.baseline(fb, 26, y, 26.0)
	CrtTheme.draw_text(v, fb, x0, by, "INVENTORY", 26, ink, 26.0 * 0.28)
	var cash := CrtTheme.money(float(inf.get("money", 0)))
	var cw := CrtTheme.text_w(fb, cash, 20, 1.2)
	CrtTheme.draw_text(v, fb, x1 - cw, by, cash, 20, ink, 1.2)
	CrtTheme.draw_right(v, fw, x1 - cw - 6.0, by, "CASH", 15, dim, 3.0)
	y += 26.0 + 6.0
	v.draw_rect(Rect2(x0, y, x1 - x0, 1.0), line)
	y += 1.0 + 9.0
	# .ihp
	var lh := 18.0
	var ly := CrtTheme.baseline(fw, 13, y, lh)
	var e := CrtTheme.draw_text(v, fw, x0, ly, "INTEGRITY", 13, dim, 2.6)
	var hp_s := str(roundi(hp))
	var bar := Rect2(e + 12.0, y + (lh - 8.0) * 0.5, x1 - 42.0 - (e + 12.0), 8.0)
	v.draw_rect(bar, Color(110.0 / 255.0, 1.0, 160.0 / 255.0, 0.5), false, 1.0)
	v.draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4.0) * pct, bar.size.y - 4.0)), Color("7dff9a"))
	CrtTheme.draw_right(v, fb, x1, CrtTheme.baseline(fb, 16, y, lh), hp_s, 16, ink, 0.8)
	y += lh + 9.0
	# .ipw and .if sit under the grid
	var foot_h := 18.0 + 6.0 + 1.0
	var ipw_h := 20.0
	var grid_h := (org.y + 380.0 - 12.0) - y - foot_h - 9.0 - ipw_h - 9.0
	var rows := int(ceil((n + 1) / 2.0))
	var gap_y := 7.0
	var gap_x := 12.0
	var cw_ := (x1 - x0 - gap_x) * 0.5
	var ch_ := (grid_h - gap_y * (rows - 1)) / rows
	# .igrid: fists first, then the slots
	var carried := 0
	for i in n + 1:
		var col := i % 2
		var row := i / 2
		var r := Rect2(x0 + col * (cw_ + gap_x), y + row * (ch_ + gap_y), cw_, ch_)
		if i == 0:
			_chip(v, r, "fists", "FISTS", "PERMANENT", combat != null and combat.cur < 0 and false, false)
			continue
		var idx: Variant = combat.slots[i - 1] if combat != null else null
		if idx == null:
			_chip(v, r, "", "EMPTY SLOT", "—", false, true)
			continue
		carried += 1
		var we := Weapons.WEAPONS[int(idx)]
		var ammo := ("%d%%" % roundi(combat.ammo[int(idx)])) if we.energy else "%d / %d" % [roundi(combat.ammo[int(idx)]), int(combat.reserve[int(idx)])]
		_chip(v, r, we.id, we.name, ammo, int(idx) == combat.cur, false)
	y += grid_h + 9.0
	# .ipw: the five power sockets
	var py := CrtTheme.baseline(fw, 13, y, ipw_h)
	var px := CrtTheme.draw_text(v, fw, x0, py, "POWERS", 13, dim, 2.6) + 8.0
	for i in POWERS:
		_dashed_box(v, Rect2(px, y, 30.0, ipw_h), Color(110.0 / 255.0, 1.0, 160.0 / 255.0, 0.3))
		px += 38.0
	var pw_name := "NONE INSTALLED"
	var ps = Game.get("power_store")
	if ps != null and ps.equipped() != null:
		pw_name = String(ps.equipped().get("name")) + " — Z"
	CrtTheme.draw_right(v, fw, x1, py, pw_name, 13, Color(125.0 / 255.0, 1.0, 154.0 / 255.0, 0.45), 2.08)
	y += ipw_h + 9.0
	# .if
	v.draw_rect(Rect2(x0, y, x1 - x0, 1.0), Color(110.0 / 255.0, 1.0, 160.0 / 255.0, 0.25))
	y += 7.0
	var fy := CrtTheme.baseline(fw, 13, y, 18.0)
	CrtTheme.draw_text(v, fw, x0, fy, "%d / %d WEAPONS" % [carried, n], 13, dim, 2.6)
	var bt := "BACK TO WHEEL"
	var btw := CrtTheme.text_w(fw, bt, 13, 2.6)
	CrtTheme.draw_text(v, fw, x1 - btw, fy, bt, 13, dim, 2.6)
	var kx := x1 - btw - 6.0 - 16.0
	v.draw_style_box(CrtTheme.panel(Color(0, 0, 0, 0), 5, Color(110.0 / 255.0, 1.0, 160.0 / 255.0, 0.5)), Rect2(kx, y, 16.0, 17.0))
	CrtTheme.draw_center(v, fb, kx + 8.0, CrtTheme.baseline(fb, 11, y, 17.0), "E", 11, ink)


func _chip(v: Control, r: Rect2, icon_id: String, title: String, sub: String, cur: bool, empty: bool) -> void:
	var fb := CrtTheme.font(&"raj700")
	var fw := CrtTheme.font(&"raj600")
	var ink := Color("c8ffd8")
	var col := Color("7dff9a")
	if empty:
		_dashed_box(v, r, Color(110.0 / 255.0, 1.0, 160.0 / 255.0, 0.28))
		ink = Color(125.0 / 255.0, 1.0, 154.0 / 255.0, 0.3)
		col = ink
	else:
		var bg := Color(20.0 / 255.0, 100.0 / 255.0, 46.0 / 255.0, 0.6) if cur else Color(8.0 / 255.0, 48.0 / 255.0, 20.0 / 255.0, 0.55)
		var bd := Color(160.0 / 255.0, 1.0, 190.0 / 255.0, 0.9) if cur else Color(110.0 / 255.0, 1.0, 160.0 / 255.0, 0.28)
		v.draw_style_box(CrtTheme.panel(bg, 6, bd), r)
	var x := r.position.x + 10.0
	if icon_id != "":
		v.draw_texture_rect(WeaponIcons.tex(icon_id), Rect2(x, r.position.y + (r.size.y - 26.0) * 0.5, 52.0, 26.0), false, col)
	x += 52.0 + 10.0
	var my := r.position.y + r.size.y * 0.5
	var title_size := 15
	var tw := CrtTheme.text_w(fb, title, title_size, 1.5)
	var room := r.end.x - x - 6.0
	if tw > room:      # text-overflow: ellipsis
		while title.length() > 1 and CrtTheme.text_w(fb, title + "…", title_size, 1.5) > room:
			title = title.substr(0, title.length() - 1)
		title += "…"
	CrtTheme.draw_text(v, fb, x, my - 1.5, title, title_size, ink, 1.5)
	CrtTheme.draw_text(v, fw, x, my + 15.0, sub, 14, Color("4fcf78") if not empty else col, 1.68)


func _dashed_box(v: Control, r: Rect2, c: Color) -> void:
	var dash := 4.0
	var gap := 3.0
	var x := r.position.x
	while x < r.end.x:
		var xe := minf(x + dash, r.end.x)
		v.draw_line(Vector2(x, r.position.y), Vector2(xe, r.position.y), c, 1.0)
		v.draw_line(Vector2(x, r.end.y), Vector2(xe, r.end.y), c, 1.0)
		x += dash + gap
	var y := r.position.y
	while y < r.end.y:
		var ye := minf(y + dash, r.end.y)
		v.draw_line(Vector2(r.position.x, y), Vector2(r.position.x, ye), c, 1.0)
		v.draw_line(Vector2(r.end.x, y), Vector2(r.end.x, ye), c, 1.0)
		y += dash + gap
