class_name CrtTheme
extends RefCounted
## The shared phosphor look in one place: the fonts (the CSS families), the colours, text drawn with CSS letter-spacing, the window scale, and the little helpers every UI piece uses.
## Sizes everywhere in ui/ are css px, as in the three.js game's stylesheet: fit_window() makes one Control unit one css px, one real pixel up to 1080p and scaled above it.

# ---- the phosphor terminal (#pause .pc-stage, #warm) ----
const PH := Color("8dffb4")          # text
const PH_HI := Color("c2ffd8")       # headings
const PH_DIM := Color("5fd88a")      # the C:\> prompt
const PH_LOW := Color("4fbf78")      # small print
const PH_BTN := Color("a8ffc8")
const PH_WHITE := Color("f0fff5")
const GLOW := Color(0.314, 1.0, 0.549)
# ---- danger ----
const AMBER := Color("ffb02e")
const RED := Color("ff2a2a")

const FONT_DIR := "res://assets/fonts/"
static var _fonts := {}
static var _tools: Theme = null


## A CSS font family + weight: vt323, raj500, raj600, raj700, orb700, orb800, sys (system-ui), sysb, mono (Consolas), monob.
static func font(key: StringName) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var f: Font
	match key:
		&"vt323":
			f = load(FONT_DIR + "VT323-Regular.ttf")
		&"vt323b":      # the browser's synthetic bold on font-weight 700 (VT323 has one weight)
			var v := FontVariation.new()
			v.base_font = load(FONT_DIR + "VT323-Regular.ttf")
			v.variation_embolden = 0.55
			f = v
		&"raj500":
			f = load(FONT_DIR + "Rajdhani-Medium.ttf")
		&"raj600":
			f = load(FONT_DIR + "Rajdhani-SemiBold.ttf")
		&"raj700":
			f = load(FONT_DIR + "Rajdhani-Bold.ttf")
		&"orb700", &"orb800":
			var v := FontVariation.new()
			v.base_font = load(FONT_DIR + "Orbitron-Variable.ttf")
			v.variation_opentype = {"wght": 700 if key == &"orb700" else 800}
			f = v
		&"sys", &"sysb":
			var s := SystemFont.new()
			s.font_names = PackedStringArray(["Segoe UI", "Roboto", "Arial"])
			s.font_weight = 700 if key == &"sysb" else 400
			s.fallbacks = [load(FONT_DIR + "Rajdhani-SemiBold.ttf")]
			f = s
		&"lucida":      # the note's and the OSD's font in a browser ("VCR OSD Mono" was never loaded, so Lucida Console it was)
			var ls := SystemFont.new()
			ls.font_names = PackedStringArray(["Lucida Console", "Consolas", "Courier New"])
			ls.fallbacks = [load(FONT_DIR + "VT323-Regular.ttf")]
			f = ls
		&"lucidab":     # its synthetic bold
			var v := FontVariation.new()
			v.base_font = font(&"lucida")
			v.variation_embolden = 0.6
			f = v
		&"mono", &"monob":
			var s := SystemFont.new()
			s.font_names = PackedStringArray(["Consolas", "Cascadia Mono", "Courier New"])
			s.font_weight = 700 if key == &"monob" else 400
			s.fallbacks = [load(FONT_DIR + "Inconsolata-Variable.ttf")]
			f = s
		_:
			push_error("no font " + String(key))
			f = load(FONT_DIR + "Rajdhani-SemiBold.ttf")
	_fonts[key] = f
	return f


## One Control unit = one css px from here on, as the browser had it (the window's 2D no longer stretches as one picture; 3D is untouched).
static func fit_window(w: Window) -> void:
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var apply := func() -> void:
		w.content_scale_factor = maxf(1.0, float(w.size.y) / 1080.0)
	apply.call()
	if not w.size_changed.is_connected(apply):
		w.size_changed.connect(apply)


## Real pixels per css px.
static func px(n: Node) -> float:
	var w := n.get_window()
	return w.content_scale_factor if w != null else 1.0


# ---- text ----

## The width of a run of text with CSS letter-spacing (sp in px, added after every glyph as a browser does).
static func text_w(f: Font, text: String, size: int, sp: float = 0.0) -> float:
	if sp == 0.0:
		return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var w := 0.0
	for i in text.length():
		w += f.get_char_size(text.unicode_at(i), size).x + sp
	return w


## Draw a run of text on a CanvasItem from its draw function. y is the baseline. Returns the x where it ended.
static func draw_text(ci: CanvasItem, f: Font, x: float, y: float, text: String, size: int, color: Color, sp: float = 0.0) -> float:
	if sp == 0.0:
		ci.draw_string(f, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		return x + f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var rid := ci.get_canvas_item()
	var cx := x
	for i in text.length():
		var ch := text.unicode_at(i)
		f.draw_char(rid, Vector2(cx, y), ch, size, color)
		cx += f.get_char_size(ch, size).x + sp
	return cx


static func draw_center(ci: CanvasItem, f: Font, cx: float, y: float, text: String, size: int, color: Color, sp: float = 0.0) -> void:
	# (CSS centres the box, whose last letter still carries its spacing: the "padding-left: .24em" trick in the stylesheet takes care of that where it mattered)
	draw_text(ci, f, cx - text_w(f, text, size, sp) * 0.5, y, text, size, color, sp)


static func draw_right(ci: CanvasItem, f: Font, rx: float, y: float, text: String, size: int, color: Color, sp: float = 0.0) -> void:
	draw_text(ci, f, rx - text_w(f, text, size, sp), y, text, size, color, sp)


## The baseline that vertically centres a line in a box (top, height), as a CSS line box does.
static func baseline(f: Font, size: int, top: float, h: float) -> float:
	var a := f.get_ascent(size)
	var d := f.get_descent(size)
	return top + (h - (a + d)) * 0.5 + a


## Word wrap by px width (the browser's <p>).
static func wrap(f: Font, text: String, size: int, width: float, sp: float = 0.0) -> PackedStringArray:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var cur := ""
		for w in para.split(" "):
			var next := w if cur == "" else cur + " " + w
			if cur != "" and text_w(f, next, size, sp) > width:
				out.append(cur)
				cur = w
			else:
				cur = next
		out.append(cur)
	return out


# ---- little pieces ----

## A plain Label with its font and colour, for the HUD's pills.
static func label(text: String, key: StringName, size: int, color: Color, sp: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ls := LabelSettings.new()
	var f: Font = font(key)
	if sp != 0:
		var v := FontVariation.new()
		v.base_font = f
		v.spacing_glyph = sp
		f = v
	ls.font = f
	ls.font_size = size
	ls.font_color = color
	l.label_settings = ls
	return l


## The shared Theme for the real Controls of the dev tools (console, tuning panel): Consolas, green on dark glass.
static func tools_theme() -> Theme:
	if _tools != null:
		return _tools
	var t := Theme.new()
	t.default_font = font(&"mono")
	t.default_font_size = 12
	var green := Color("5dff8f")
	var line := Color("2f6b3c")
	t.set_color(&"font_color", &"Label", Color("9df5b0"))
	for st: Array in [[&"normal", Color(30.0 / 255.0, 80.0 / 255.0, 45.0 / 255.0, 0.35)], [&"hover", Color(40.0 / 255.0, 120.0 / 255.0, 66.0 / 255.0, 0.55)], [&"pressed", Color(60.0 / 255.0, 160.0 / 255.0, 90.0 / 255.0, 0.6)], [&"focus", Color(0, 0, 0, 0)]]:
		t.set_stylebox(st[0], &"Button", panel(st[1], 4, line, 10, 5))
	t.set_color(&"font_color", &"Button", Color("c8ffd4"))
	t.set_color(&"font_hover_color", &"Button", Color("e8ffe9"))
	t.set_color(&"font_pressed_color", &"Button", Color("e8ffe9"))
	t.set_color(&"font_color", &"CheckBox", Color("9df5b0"))
	t.set_color(&"font_hover_color", &"CheckBox", Color("c8ffd4"))
	t.set_color(&"font_pressed_color", &"CheckBox", Color("c8ffd4"))
	# the slider: a thin track, a filled part, a round grabber
	var track := panel(Color(30.0 / 255.0, 80.0 / 255.0, 45.0 / 255.0, 0.6), 2)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := panel(green, 2)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	var g := _dot_tex(green)
	t.set_icon(&"grabber", &"HSlider", g)
	t.set_icon(&"grabber_highlight", &"HSlider", _dot_tex(Color("c8ffd4")))
	t.set_icon(&"grabber_disabled", &"HSlider", g)
	# scroll bars
	var sc := panel(Color(0, 0, 0, 0.25), 3)
	sc.content_margin_left = 3
	sc.content_margin_right = 3
	var gr := panel(line, 3)
	var gh := panel(Color("3f8a55"), 3)
	for bar: StringName in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", bar, sc)
		t.set_stylebox(&"grabber", bar, gr)
		t.set_stylebox(&"grabber_highlight", bar, gh)
		t.set_stylebox(&"grabber_pressed", bar, gh)
	_tools = t
	return t


static func _dot_tex(c: Color) -> ImageTexture:
	var n := 14
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var mid := (n - 1) * 0.5
	for y in n:
		for x in n:
			var a := clampf(n * 0.5 - 0.5 - Vector2(x - mid, y - mid).length() + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)


## A flat rounded panel style (the HUD's dark glass pills).
static func panel(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), pad_x: int = 0, pad_y: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	if border.a > 0.0:
		s.set_border_width_all(1)
		s.border_color = border
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


## A soft CSS box-shadow drawn from the draw function: stacked outlines around (or, inset, inside) a rectangle. Cheap, and at these small radii it reads as a blur.
static func glow_box(ci: CanvasItem, r: Rect2, c: Color, blur: float, inset: bool = false) -> void:
	var steps := clampi(int(blur * 0.5), 2, 6)
	var step_px := blur / float(steps)
	# a gaussian's falloff, split over the rings
	var norm := 0.0
	for i in steps:
		norm += exp(-pow(float(i) / float(steps) * 2.0, 2.0))
	for i in steps:
		var a := c.a * exp(-pow(float(i) / float(steps) * 2.0, 2.0)) / norm * 1.6
		var g := (float(i) + 0.5) * step_px
		var rr := r.grow(-g) if inset else r.grow(g)
		if rr.size.x <= 0.0 or rr.size.y <= 0.0:
			break
		ci.draw_rect(rr, Color(c.r, c.g, c.b, a), false, step_px)


## Fill the parent: the usual anchor preset, with the input ignored unless asked for.
static func full(c: Control, ignore: bool = true) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	if ignore:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A shader material from a file (shaders are created once, when the UI is built, never mid-play).
static func mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


## One sound of the shared bank, if it has been ported yet.
static func sfx(id: String, o: Dictionary = {}) -> void:
	var s = Game.sfx
	if s != null:
		s.play(id, o)


static func menu_sound(kind: String) -> void:
	var s = Game.sfx
	if s != null:
		s.menu_sound(kind)


## JS fmt$: dollars with thousands separators.
static func money(n: float) -> String:
	var v := int(round(absf(n)))
	var t := str(v)
	var o := ""
	while t.length() > 3:
		o = "," + t.substr(t.length() - 3) + o
		t = t.substr(0, t.length() - 3)
	return ("-$" if n < 0.0 else "$") + t + o


## cubic-bezier(x1, y1, x2, y2) at time u, as a CSS transition eases.
static func bezier(u: float, x1: float, y1: float, x2: float, y2: float) -> float:
	if u <= 0.0:
		return 0.0
	if u >= 1.0:
		return 1.0
	var t := u
	for i in 6:
		var x := 3.0 * (1.0 - t) * (1.0 - t) * t * x1 + 3.0 * (1.0 - t) * t * t * x2 + t * t * t
		var dx := 3.0 * (1.0 - t) * (1.0 - t) * x1 + 6.0 * (1.0 - t) * t * (x2 - x1) + 3.0 * t * t * (1.0 - x2)
		if absf(dx) < 0.0001:
			break
		t = clampf(t - (x - u) / dx, 0.0, 1.0)
	return 3.0 * (1.0 - t) * (1.0 - t) * t * y1 + 3.0 * (1.0 - t) * t * t * y2 + t * t * t
