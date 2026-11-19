class_name VendorMenu
extends Control
## The vendor terminals' shared shell (JS class VendorMenu): the menu inside the screen of a picture of a machine, behind a coloured CRT, with a staged open / close, a carousel with its bracket, a balance tween, messages, device-aware prompts and input routing. The JS lays this out with HTML and CSS; here `MenuPage` draws the same boxes at the same measures (the CSS numbers, in the design pixels of `design_h`), and the subclasses fill in the panels. The JS's own SVG frame is hidden on every machine (.vd.pz), so it is not here.

const THEMES := {
	"weapon": {"edge": "#ff443e", "edge2": "#ae1525", "steel": "#8c919b", "steel_hi": "#f4f0e8", "steel_lo": "#303039", "ink": "#fff1d8", "ink2": "#e8d4c2", "dim": "#c0aaa7", "glass": Color8(56, 9, 17, 224), "glass2": Color8(17, 5, 10, 240), "well": Color8(27, 7, 13, 217), "sel": "#75edff", "sel2": "#2bc6e8", "bad": "#ff9b80", "good": "#8ce9d1", "hl": Color8(255, 45, 54, 46), "dimbg": Color8(12, 2, 6, 173),
		"pzr": [255, 56, 48], "sat": 5.5, "hue": -40.0, "bright": 1.05, "contrast": 1.12, "bg1": "#2c0609", "bg2": "#0b0203"},
	"armor": {"edge": "#ffc23a", "edge2": "#d88a14", "steel": "#a87a3e", "steel_hi": "#e6c48a", "steel_lo": "#4a3218", "ink": "#fff3dc", "ink2": "#ead2a6", "dim": "#bf9a62", "glass": Color8(30, 22, 12, 209), "glass2": Color8(14, 11, 8, 235), "well": Color8(12, 9, 6, 189), "sel": "#fff5b0", "sel2": "#ffd23a", "bad": "#ff6a4a", "good": "#c8f08a", "hl": Color8(255, 194, 58, 41), "dimbg": Color8(10, 6, 2, 153),
		"pzr": [255, 176, 40], "sat": 4.4, "hue": -4.0, "bright": 1.04, "contrast": 1.12, "bg1": "#2a1a04", "bg2": "#0b0701"},
	"plasmid": {"edge": "#ff9a2e", "edge2": "#e0680f", "steel": "#a85a1a", "steel_hi": "#ffb866", "steel_lo": "#4a2406", "ink": "#ffe2b8", "ink2": "#f3b56e", "dim": "#c27a36", "glass": Color8(26, 11, 2, 199), "glass2": Color8(14, 6, 1, 230), "well": Color8(16, 7, 1, 179), "sel": "#ffe6a8", "sel2": "#ffb43a", "bad": "#ff5a36", "good": "#ffd070", "hl": Color8(255, 150, 40, 51), "dimbg": Color8(8, 3, 0, 184),
		"pzr": [255, 140, 30], "sat": 4.2, "hue": -16.0, "bright": 1.02, "contrast": 1.12, "bg1": "#2a1204", "bg2": "#0b0401"},
	# CLUB 9's bar terminal (levels/club/club_bar.gd): the house green phosphor, amber for what you cannot have
	"bar": {"edge": "#5fd88a", "edge2": "#2f9c5a", "steel": "#3f7a55", "steel_hi": "#a8ffc8", "steel_lo": "#16301f", "ink": "#c2ffd8", "ink2": "#8dffb4", "dim": "#4fbf78", "glass": Color8(6, 26, 14, 214), "glass2": Color8(3, 14, 8, 238), "well": Color8(4, 18, 10, 200), "sel": "#f0fff5", "sel2": "#8dffb4", "bad": "#ffb02e", "good": "#8dffb4", "hl": Color8(80, 255, 140, 40), "dimbg": Color8(2, 10, 5, 175),
		"pzr": [70, 255, 130], "sat": 3.6, "hue": 95.0, "bright": 1.03, "contrast": 1.12, "bg1": "#062a14", "bg2": "#020b05"},
}
const NAV := {KEY_LEFT: -1, KEY_A: -1, KEY_UP: -1, KEY_W: -1, KEY_RIGHT: 1, KEY_D: 1, KEY_DOWN: 1, KEY_S: 1}
# the pzSign keyframes: time (%), value
const SIGN: Array[Array] = [[0.0, 0.15], [8.0, 0.45], [16.0, 0.1], [30.0, 0.38], [44.0, 0.05], [50.0, 0.9], [52.0, 0.12], [54.0, 0.75], [58.0, 0.1], [72.0, 0.42], [86.0, 0.2], [100.0, 0.15]]
# pzGlitch's keyframes (steps(1, end): each holds until the next): time %, x, y, skew deg, bright, contrast, hue deg, sat, clip top %, clip bottom %
const GLITCH: Array[Array] = [[0.0, 0, 0, 0, 1.0, 1.0, 0, 1.0, 0, 0], [12.0, -9, 0, 4, 1.7, 1.4, 0, 1.0, 10, 58], [24.0, 12, 0, 0, 1.3, 1.0, -24, 1.0, 52, 18], [30.0, -4, 2, -3, 1.0, 1.0, 0, 1.0, 0, 0], [46.0, 7, -2, 0, 2.1, 1.0, 0, 2.0, 0, 40], [60.0, -11, 0, 0, 1.0, 1.6, 0, 1.0, 30, 34], [74.0, 3, 0, 0, 1.3, 1.0, 0, 1.0, 0, 0], [100.0, 0, 0, 0, 1.0, 1.0, 0, 1.0, 0, 0]]
const TEAR: Array[Array] = [[0.0, 0.0], [14.0, 1.0], [28.0, 0.0], [48.0, 0.9], [62.0, 0.0], [78.0, 0.6], [90.0, 0.0], [100.0, 0.0]]

static var stage: VendorStage = null

var o := {}
var theme_id := "weapon"
var mode := "w"
var sub_a := ""        # the subtitle, either side of its bright <b>
var sub_b := ""
var sub_c := ""
var items: Array = []
var n := 0
var sel := 0
var open_ := false
var vis := false
var dev := "kb"
var busy_until := 0
var bal_shown := 0.0
var bal: Dictionary = {}
var _nav_t := 0
var _rep := {"d": 0, "t": 0.0}
var _hide_t := -1.0
var _built := false
var _last_mx := Vector2.ZERO
# the art
var art_cfg := {}
var hole := {"x1": 0.14, "y1": 0.26, "x2": 0.88, "y2": 0.82}
var art_ratio := 1.6
var design_h := 540.0
var portrait := false     # a tall picture (CLUB 9's handheld pad): MenuPage stacks the page for a narrow screen
# nodes
var dim: ColorRect = null
var art: ColorRect = null
var view: ColorRect = null
var crt: ColorRect = null
var glow: Control = null
var vp: SubViewport = null
var page: MenuPage = null
var _view_m: ShaderMaterial = null
var _crt_m: ShaderMaterial = null
var _art_m: ShaderMaterial = null
var _glow_box := Rect2()
# stage geometry
var g := Rect2()
var k := 1.0
var fw := 1000.0
var u := 1.0
# timers (s): the open / close staging and the one-shot CSS animations
var open_t := 0.0
var close_t := 0.0
var _clock := 0.0
var anim := {}          # name -> seconds since it (re)started
var msg_text := ""
var msg_kind := ""
var _gl_t := -1.0
var _gl_next := 0.0
var _tear_a := Vector2(0.4, 0.02)
var _tear_b := Vector2(0.7, 0.01)
var slots_s: Array[float] = []       # each slot's eased selection (0 rest, 1 selected)
var track_x := 0.0
var track_to := 0.0
var bracket_x := 0.0
var _car_snap := true
var flick_t := 0.0


func _init(p_o: Dictionary = {}) -> void:
	o = p_o
	theme_id = o.get("theme", "weapon")
	mode = o.get("mode", "w")
	items = o.get("items", [])
	n = items.size()
	var parts: PackedStringArray = String(o.get("sub", "")).split("<b>//</b>")
	sub_a = parts[0].strip_edges() if parts.size() > 0 else ""
	sub_c = parts[1].strip_edges() if parts.size() > 1 else ""
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func th(key: String) -> Color:
	var v: Variant = THEMES[theme_id][key]
	return v if v is Color else Color(v)


## mix(c, b, a%): color-mix(in srgb, a 12%, transparent) and friends
func cm(key: String, pct: float) -> Color:
	var c := th(key)
	return Color(c.r, c.g, c.b, c.a * pct / 100.0)


## The one 3D preview view, made on first use (the shops and the pause terminal's inventory share it and its cache of built subjects).
static func ensure_stage() -> VendorStage:
	if stage == null:
		stage = VendorStage.new()
		Game.add_child(stage)
	return stage


func _build() -> void:
	if _built:
		return
	_built = true
	ensure_stage()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 60      # above the HUD, under the version line (.vd z-index 40)
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dm := ShaderMaterial.new()
	var ds := Shader.new()
	ds.code = "shader_type canvas_item; uniform vec4 c0; uniform float op = 0.0; void fragment() { float d = clamp(length((UV - 0.5) / vec2(0.7, 0.65)) * 2.0 * 0.5, 0.0, 1.0); vec4 c = mix(c0, vec4(0.0, 0.0, 0.0, 0.86), d); COLOR = vec4(c.rgb, c.a * op); }"
	dm.shader = ds
	var dc := th("dimbg")
	dm.set_shader_parameter(&"c0", dc)
	dim.material = dm
	add_child(dim)
	vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.gui_disable_input = true
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	page = MenuPage.new()
	page.M = self
	vp.add_child(page)
	add_child(vp)
	view = ColorRect.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view_m = ShaderMaterial.new()
	_view_m.shader = load("res://ui/shop/vendor_view.gdshader")
	_view_m.set_shader_parameter(&"menu", vp.get_texture())
	var T: Dictionary = THEMES[theme_id]
	_view_m.set_shader_parameter(&"sat", T.sat)
	_view_m.set_shader_parameter(&"hue", deg_to_rad(T.hue))
	_view_m.set_shader_parameter(&"bright", T.bright)
	_view_m.set_shader_parameter(&"contrast", T.contrast)
	var pzr := CrtKit.c8(T.pzr)
	_view_m.set_shader_parameter(&"pzr", Vector3(pzr.r, pzr.g, pzr.b))
	var b1 := Color(T.bg1)
	var b2 := Color(T.bg2)
	_view_m.set_shader_parameter(&"bg1", Vector3(b1.r, b1.g, b1.b))
	_view_m.set_shader_parameter(&"bg2", Vector3(b2.r, b2.g, b2.b))
	view.material = _view_m
	add_child(view)
	crt = ColorRect.new()
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt_m = ShaderMaterial.new()
	_crt_m.shader = load("res://ui/shop/vendor_crt.gdshader")
	_crt_m.set_shader_parameter(&"pzr", Vector3(pzr.r, pzr.g, pzr.b))
	crt.material = _crt_m
	add_child(crt)
	art = ColorRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_m = ShaderMaterial.new()
	_art_m.shader = load("res://ui/shop/vendor_art.gdshader")
	var tex: Texture2D = load(art_cfg.url)
	_art_m.set_shader_parameter(&"art", tex)
	var rg: Dictionary = art_cfg.get("neon_region", {"x1": 0.0, "y1": 0.0, "x2": 1.0, "y2": 0.25})
	_art_m.set_shader_parameter(&"region", Vector4(rg.x1, rg.y1, rg.x2, rg.y2))
	_art_m.set_shader_parameter(&"neon_white", art_cfg.get("neon_white", true))
	art.material = _art_m
	add_child(art)
	glow = Control.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.draw.connect(_draw_glow)
	add_child(glow)
	get_viewport().size_changed.connect(func() -> void:
		if vis:
			_layout_stage())


## Put the whole menu inside the screen of a picture of a machine. cfg: { url, hole (screen rectangle, fractions of the picture), ratio (picture w / h), design_h (menu layout height in px, scaled to the glass), neon_region, neon_white }
func wrap_art(cfg: Dictionary) -> void:
	art_cfg = cfg
	hole = cfg.hole
	art_ratio = cfg.ratio
	design_h = cfg.get("design_h", 540.0)
	portrait = art_ratio < 1.0


## where the picture of the machine sits on a screen of this size: as big as fits, centred (CLUB 9's order cutscene frames the 3D pad to land on it)
func stage_rect(sz: Vector2) -> Rect2:
	var sw := minf(sz.x * 0.99, sz.y * 0.99 * art_ratio)
	var sh := sw / art_ratio
	return Rect2((sz - Vector2(sw, sh)) / 2.0, Vector2(sw, sh))


func _layout_stage() -> void:
	var sz := get_viewport().get_visible_rect().size
	var sr := stage_rect(sz)
	var sw := sr.size.x
	var sh := sr.size.y
	var stage_pos := sr.position
	var gx: float = hole.x1 * sw
	var gy: float = hole.y1 * sh
	var gw: float = (hole.x2 - hole.x1) * sw
	var gh: float = (hole.y2 - hole.y1) * sh
	k = gh / design_h      # the menu is laid out at design_h px tall, then scaled to the glass
	fw = gw / k
	g = Rect2(stage_pos + Vector2(gx, gy), Vector2(gw, gh))
	art.position = stage_pos
	art.size = Vector2(sw, sh)
	view.position = g.position
	view.size = g.size
	crt.position = g.position
	crt.size = g.size
	_crt_m.set_shader_parameter(&"css_h", gh)
	vp.size = Vector2i(ceili(gw), ceili(gh))
	vp.size_2d_override = Vector2i(roundi(fw), roundi(design_h))
	page.size = Vector2(fw, design_h)
	_view_m.set_shader_parameter(&"px", Vector2(3.0 / gw, 3.0 / gh))
	# (the media queries: the same layout, scaled)
	u = 1.0
	if sz.y <= 540.0 or sz.x <= 720.0:
		u = 0.64
	elif sz.y <= 620.0 or sz.x <= 960.0:
		u = 0.74
	elif sz.y <= 720.0 or sz.x <= 1180.0:
		u = 0.82
	elif sz.y <= 820.0:
		u = 0.9
	page.small = sz.y <= 620.0
	page.tiny = sz.y <= 540.0
	if portrait:      # (a portrait page is drawn at its own measures and scaled to the glass whole: the screen-size steps are for the wide terminals' CSS)
		u = 1.0
		page.small = false
		page.tiny = false
	_glow_box = g
	_car_snap = true
	page.layout()


var is_open: bool:
	get:
		return open_


# ---- open / close ----
func open() -> void:
	if open_:
		return
	if get_parent() == null:
		Game.ui_root.add_child(self)
	_build()
	_layout_stage()
	_hide_t = -1.0
	open_ = true
	vis = true
	visible = true
	busy_until = Time.get_ticks_msec() + 220
	msg("", "")
	dev = "pad" if Inp.using_pad else "kb"
	bal_shown = Game.money
	bal = {}
	on_open()
	open_t = 0.0
	close_t = -1.0
	_car_snap = true
	slots_s.resize(n)
	for i in n:
		slots_s[i] = 1.0 if i == sel else 0.0
	stage.attach(mode)
	show_item(true)
	Game.sfx.play("vendOpen")
	_gl_next = 2.2 + randf() * 3.0
	_gl_t = -1.0
	if Inp.pointer_locked:
		Game.ui.unlock()
	set_process(true)


func close(via_esc: bool = false) -> void:
	if not open_:
		return
	open_ = false
	Inp.guard_arm()
	Game.sfx.play("vendClose")
	_gl_t = -1.0
	close_t = 0.0
	_hide_t = 0.3
	if Game.started and not Game.paused:
		if via_esc:
			Game.get_tree().create_timer(0.4).timeout.connect(func() -> void:
				if Game.started and not Game.paused and not Game.menu_open():
					Game.ui.lock())
		else:
			Game.ui.lock()


func on_open() -> void:
	pass


# ---- browsing ----
func skip_item(_it: Variant) -> bool:
	return false


func move(d: int, rep: bool = false) -> void:
	var i := sel
	while true:
		i = (i + d + n) % n
		if not (skip_item(items[i]) and i != sel):
			break
	select(i, false, rep)
	anim["kick%d" % (0 if d < 0 else 1)] = 0.0


func select(i: int, quiet: bool = false, _rep_: bool = false) -> void:
	if i == sel and not quiet:
		return
	sel = i
	msg("", "")
	var now := Time.get_ticks_msec()
	if not quiet and now - _nav_t > 45:
		_nav_t = now
		Game.sfx.play("vendNav")
	show_item(false)
	anim["swap"] = 0.0
	anim["scan"] = 0.0
	anim["snap"] = 0.0


func show_item(instant: bool) -> void:
	var it: Variant = items[sel]
	stage.show_subject(mode + ":" + String(it.id), func() -> Node3D: return build_subject(it), instant)


func build_subject(_it: Variant) -> Node3D:
	return Node3D.new()


# ---- feedback ----
func msg(t: String, kind: String) -> void:
	msg_text = t
	msg_kind = kind
	if t != "":
		anim["msg"] = 0.0


func busy() -> bool:
	return Time.get_ticks_msec() < busy_until


func deny(t: String) -> void:
	msg(t, "bad")
	Game.sfx.play("vendDeny")
	anim.erase("paid")
	anim["deny"] = 0.0


func paid(stamp_top: String, stamp_sub: String, line: String) -> void:
	busy_until = Time.get_ticks_msec() + 320      # no double submission from a double click / bounce
	bal = {"from": bal_shown, "to": float(Game.money), "t": 0.0}
	Game.sfx.play("vendBuy")
	anim["flash"] = 0.0
	anim["sweep"] = 0.0
	anim.erase("deny")
	anim["paid"] = 0.0
	anim["stamp"] = 0.0
	page.stamp_top = stamp_top
	page.stamp_sub = stamp_sub
	msg(line, "")


func prompts(_d: String) -> Array:
	return []


func act(_a: String) -> void:
	pass


# ---- the page's panels (subclasses) ----
func draw_main(_p: MenuPage, _r: Rect2) -> void:
	pass


func draw_slot(_p: MenuPage, _it: Variant, _i: int, _r: Rect2) -> void:
	pass


func slot_label() -> String:
	return String(items[sel].name)


func slot_hidden(_i: int) -> bool:
	return false


func _sign_level(t: float) -> float:
	var pct := fposmod(t + 2.0, 8.0) / 8.0 * 100.0      # (animation 8s, delay -2s)
	for i in range(1, SIGN.size()):
		if pct <= SIGN[i][0]:
			var a: Array = SIGN[i - 1]
			var b: Array = SIGN[i]
			var f: float = (pct - float(a[0])) / (float(b[0]) - float(a[0]))
			f = f * f * (3.0 - 2.0 * f)      # ease-in-out
			return lerpf(a[1], b[1], f)
	return 0.15


func _draw_glow() -> void:
	# .pz-glow: the screen's phosphor glowing onto the bezel, mix-blend-mode screen, pulsing 4.3 s
	var op := lerpf(0.82, 1.0, 0.5 - 0.5 * cos(_clock / 4.3 * TAU))
	var c := CrtKit.c8(THEMES[theme_id].pzr, 0.5 * op * _stage_alpha())
	var sw := art.size.x
	var bl := sw * 0.028
	for i in 4:
		var a := (4 - i) / 4.0
		glow.draw_rect(_glow_box.grow(bl * (i + 1) / 4.0), Color(c.r, c.g, c.b, c.a * 0.22 * a), false, bl / 4.0)
	var inner := sw * 0.05
	var c2 := Color(c.r, c.g, c.b, 0.4 * op * _stage_alpha())
	for i in 5:
		var a := (5 - i) / 5.0
		glow.draw_rect(_glow_box.grow(-inner * i / 5.0), Color(c2.r, c2.g, c2.b, c2.a * 0.14 * a), false, inner / 5.0)


func _stage_alpha() -> float:
	if open_:
		return clampf(open_t / 0.16, 0.0, 1.0)
	return 1.0 - clampf(close_t / 0.24, 0.0, 1.0)


func _trans(t: float, delay: float, dur: float) -> float:
	return clampf((t - delay) / dur, 0.0, 1.0)


func _process(delta: float) -> void:
	if not vis:
		set_process(false)
		return
	var dt := minf(0.05, delta)
	_clock += dt
	if open_:
		open_t += dt
	else:
		close_t += dt
		if _hide_t >= 0.0:
			_hide_t -= dt
			if _hide_t <= 0.0:
				_hide_t = -1.0
				vis = false
				visible = false
				stage.render_target_update_mode = SubViewport.UPDATE_DISABLED
				return
	for a: String in anim.keys():
		anim[a] += dt
	if not bal.is_empty():
		bal.t = minf(1.0, float(bal.t) + dt / 0.45)
		var e := 1.0 - pow(1.0 - float(bal.t), 3.0)
		bal_shown = lerpf(bal.from, bal.to, e)
		if bal.t >= 1.0:
			bal = {}
	else:
		bal_shown = Game.money
	# the carousel eases
	var ke := 1.0 - exp(-dt / 0.05)
	for i in slots_s.size():
		slots_s[i] += ((1.0 if i == sel else 0.0) - slots_s[i]) * ke
	track_x += (track_to - track_x) * ke
	bracket_x += ((track_to + page.slot_x(sel)) - bracket_x) * ke
	stage.frame(dt)
	_staged()
	_crt_frame(dt)
	page.queue_redraw()
	glow.queue_redraw()


## the staged open: dim, header, panels, then carousel (~420 ms); faster reverse on close
func _staged() -> void:
	var dm: ShaderMaterial = dim.material
	var t := open_t if open_ else close_t
	if open_:
		dm.set_shader_parameter(&"op", _trans(t, 0.0, 0.16))
		page.head_a = _trans(t, 0.03, 0.16)
		page.head_y = -16.0 * (1.0 - CrtTheme.bezier(_trans(t, 0.03, 0.2), 0.2, 0.9, 0.3, 1.1))
		page.main_a = _trans(t, 0.12, 0.12)
		_view_m.set_shader_parameter(&"band_open", CrtTheme.bezier(_trans(t, 0.1, 0.26), 0.2, 0.8, 0.25, 1.0))
		page.car_a = _trans(t, 0.22, 0.16)
		page.car_y = 18.0 * (1.0 - CrtTheme.bezier(_trans(t, 0.22, 0.2), 0.2, 0.9, 0.3, 1.08))
		page.prompt_a = _trans(t, 0.27, 0.16)
		page.prompt_y = 18.0 * (1.0 - _trans(t, 0.27, 0.16))
	else:
		dm.set_shader_parameter(&"op", 1.0 - _trans(t, 0.1, 0.14))
		page.head_a = 1.0 - _trans(t, 0.08, 0.12)
		page.head_y = -16.0 * _trans(t, 0.08, 0.14)
		page.main_a = 1.0 - _trans(t, 0.08, 0.12)
		_view_m.set_shader_parameter(&"band_open", 1.0 - CrtTheme.bezier(_trans(t, 0.04, 0.16), 0.5, 0.0, 0.8, 0.4))
		page.car_a = 1.0 - _trans(t, 0.0, 0.1)
		page.car_y = 18.0 * _trans(t, 0.0, 0.12)
		page.prompt_a = page.car_a
		page.prompt_y = page.car_y
	var fade := _stage_alpha()
	art.modulate.a = fade
	view.modulate.a = fade
	crt.modulate.a = fade
	_art_m.set_shader_parameter(&"level", _sign_level(_clock))


func _key_at(tbl: Array, pct: float) -> Array:
	var r: Array = tbl[0]
	for e: Array in tbl:
		if e[0] <= pct:
			r = e
	return r


func _crt_frame(dt: float) -> void:
	# pzFlick: 3.7 s steps
	var pct := fmod(_clock, 3.7) / 3.7 * 100.0
	var fl := 1.0
	if pct >= 9.0 and pct < 10.0:
		fl = 0.93
	elif pct >= 47.0 and pct < 48.0:
		fl = 0.95
	elif pct >= 71.0 and pct < 72.0:
		fl = 0.9
	_crt_m.set_shader_parameter(&"flick", fl)
	_crt_m.set_shader_parameter(&"roll", fmod(_clock, 6.5) / 6.5 * 1.22 - 0.22)
	# every few seconds while the menu sits idle: a short glitch (the screen tears, jumps and flashes)
	if open_:
		_gl_next -= dt
		if _gl_next <= 0.0:
			_glitch()
			_gl_next = 3.5 + randf() * 6.5
	var off := Vector2.ZERO
	var sk := 0.0
	var br := 1.0
	var co := 1.0
	var hu := 0.0
	var sa := 1.0
	var c0 := 0.0
	var c1 := 1.0
	var ta := 0.0
	if _gl_t >= 0.0:
		_gl_t += dt
		if _gl_t > 0.38:
			_gl_t = -1.0
		else:
			var p := _gl_t / 0.38 * 100.0
			var e := _key_at(GLITCH, p)
			off = Vector2(float(e[1]) / g.size.x, float(e[2]) / g.size.y)
			sk = tan(deg_to_rad(float(e[3]))) * g.size.y / g.size.x
			br = e[4]
			co = e[5]
			hu = deg_to_rad(float(e[6]))
			sa = e[7]
			c0 = float(e[8]) / 100.0
			c1 = 1.0 - float(e[9]) / 100.0
			ta = _key_at(TEAR, p)[1]
	_view_m.set_shader_parameter(&"gl_off", off)
	_view_m.set_shader_parameter(&"gl_skew", sk)
	_view_m.set_shader_parameter(&"gl_bright", br)
	_view_m.set_shader_parameter(&"gl_contrast", co)
	_view_m.set_shader_parameter(&"gl_hue", hu)
	_view_m.set_shader_parameter(&"gl_sat", sa)
	_view_m.set_shader_parameter(&"gl_clip", Vector2(c0, c1))
	_crt_m.set_shader_parameter(&"tear_a", Vector3(_tear_a.x, _tear_a.y, ta))
	_crt_m.set_shader_parameter(&"tear_b", Vector3(_tear_b.x, _tear_b.y, ta))


func _glitch() -> void:
	_tear_a = Vector2((10.0 + randf() * 70.0) / 100.0, (4.0 + randf() * 14.0) / g.size.y)
	_tear_b = Vector2((10.0 + randf() * 80.0) / 100.0, (2.0 + randf() * 8.0) / g.size.y)
	_gl_t = 0.0
	Game.sfx.play("mechRelay")


## gamepad and keyboard: d-pad / left stick browse (with hold-repeat), face buttons per menu, B exits. Called by the game's frame while the menu is open.
func update(dt: float) -> void:
	# the keyboard (the JS's capture-phase keydown handler)
	if not Inp.keys_pressed.is_empty() or not Inp.keys_echo.is_empty():
		if dev != "kb":
			dev = "kb"
		for code: int in NAV:
			if Inp.key_hit(code, true):
				move(NAV[code], not Inp.key_hit(code))
				break
		if Inp.key_hit(KEY_ESCAPE):
			close(true)
			return
		if Inp.key_hit(KEY_E) or Inp.key_hit(KEY_X) or Inp.key_hit(KEY_BACKSPACE):
			close()
			return
		var keys: Dictionary = o.get("keys", {})
		for code: int in keys:
			if Inp.key_hit(code):
				act(keys[code])
				break
	# the pad
	if Inp.using_pad and dev != "pad":
		dev = "pad"
	var d := 0
	if Inp.btn(&"d_left").held or Inp.btn(&"d_up").held:
		d = -1
	elif Inp.btn(&"d_right").held or Inp.btn(&"d_down").held:
		d = 1
	var lx := Inp.raw_lx
	var ly := Inp.raw_ly
	if d == 0 and Vector2(lx, ly).length() > 0.55:
		d = int(signf(lx)) if absf(lx) >= absf(ly) else int(signf(ly))
	var r := _rep
	if d != r.d:
		r.d = d
		r.t = 0.28
		if d != 0:
			move(d)
	elif d != 0:
		r.t -= dt
		if r.t <= 0.0:
			r.t = 0.09
			move(d, true)
	if Inp.btn(&"b").pressed:
		close()
		return
	for pk: Array in o.get("pad_keys", []):
		if Inp.btn(pk[0]).pressed:
			act(pk[1])
			break


func _gui_input(event: InputEvent) -> void:
	if not open_:
		return
	if event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > 2.0 and dev != "kb":
			dev = "kb"
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if not b.pressed:
			return
		if b.button_index == MOUSE_BUTTON_WHEEL_DOWN or b.button_index == MOUSE_BUTTON_WHEEL_UP:
			dev = "kb"
			move(1 if b.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			return
		if b.button_index != MOUSE_BUTTON_LEFT:
			return
		dev = "kb"
		var hit: Dictionary = page.hit_at((b.position - g.position) / k)
		if hit.is_empty():
			return
		var a: String = hit.a
		if a == "slot":
			select(int(hit.v))
		elif a == "prev":
			move(-1)
		elif a == "next":
			move(1)
		else:
			act(a)
