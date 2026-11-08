class_name EmotionCloseup
extends CanvasLayer
## A full-screen face close-up that runs through shock, rage, collapse and sobbing from a flipbook of 2D stills (JS cutscenes/emotion-closeup.js). Every frame is aligned on the eyes, crossfaded / cut by beat, with a slow push-in, shake, a sob tremor (blend with an alt frame) and tear drops drawn over the cheeks. X / Esc / Enter / click skips. Dev console: cutscene play emotion-closeup.

const DIR := "res://assets/cutscenes/emotion-closeup/"
const FRAMES := {      # eye anchor per frame, as fractions of the image: ex / ey = midpoint between the eyes, span = distance between the eyes' centres (width)
	&"shock": {"src": "f1.webp", "ex": 0.489, "ey": 0.427, "span": 0.378},
	&"rage": {"src": "f2.webp", "ex": 0.522, "ey": 0.450, "span": 0.400},
	&"collapse": {"src": "f3.webp", "ex": 0.497, "ey": 0.439, "span": 0.383},
	&"sob": {"src": "f4.webp", "ex": 0.545, "ey": 0.473, "span": 0.486},
	&"wail": {"src": "f5.webp", "ex": 0.516, "ey": 0.417, "span": 0.385},
}
const BEATS: Array = [      # the timeline: fade = seconds to blend in from the previous beat (0.08 is a hard cut); shake / tremor in eye-spans; alt + alt_hz + alt_amt pulse a second frame over this one; tears = drops per second
	{"frame": &"shock", "dur": 2.4, "fade": 0.9, "zoom": [1.00, 1.06], "shake": 0.000, "tears": 0.6},
	{"frame": &"rage", "dur": 1.7, "fade": 0.09, "zoom": [1.12, 1.22], "shake": 0.022, "tears": 0.0},
	{"frame": &"collapse", "dur": 2.1, "fade": 0.55, "zoom": [1.12, 1.18], "shake": 0.004, "tears": 1.4, "alt": &"sob", "alt_hz": 1.3, "alt_amt": 0.35},
	{"frame": &"sob", "dur": 2.3, "fade": 0.65, "zoom": [1.16, 1.26], "shake": 0.007, "tears": 2.2, "alt": &"wail", "alt_hz": 2.1, "alt_amt": 0.5, "tremor": 0.006},
	{"frame": &"wail", "dur": 3.0, "fade": 0.5, "zoom": [1.22, 1.38], "shake": 0.012, "tears": 3.2, "alt": &"sob", "alt_hz": 2.8, "alt_amt": 0.45, "tremor": 0.010},
]
const FADE_IN := 0.8
const FADE_OUT := 1.1
const BAR := 0.09      # letterbox bar height (fraction of the screen)

var on_end := Callable()
var on := false
var t := 0.0
var _imgs := {}
var _bg := {}
var _drops: Array[Dictionary] = []
var _acc := 0.0
var _total := 0.0
var _starts: Array[float] = []
var _dt := 0.016
var _page: Control
var _vig: ColorRect
var _vig_m: ShaderMaterial
var _over: Control


class Layer:
	extends Control
	var fn: Callable
	func _draw() -> void:
		fn.call(self)


static func _noise(tt: float, k: float) -> float:
	return sin(tt * 37.1 * k) * 0.5 + sin(tt * 91.7 * k + 1.3) * 0.3 + sin(tt * 163.3 * k + 2.9) * 0.2


func _init() -> void:
	layer = 110
	var a := 0.0
	for b: Dictionary in BEATS:
		_starts.append(a)
		a += float(b.dur)
	_total = a


func play() -> void:
	for k: StringName in FRAMES:
		var im: Texture2D = load(DIR + String(FRAMES[k].src))
		_imgs[k] = im
		var small := im.get_image()      # tiny dim copy, stretched over the screen as a soft backdrop behind the face
		if small.is_compressed():
			small.decompress()
		small.convert(Image.FORMAT_RGBA8)
		small.clear_mipmaps()
		small.resize(24, 44, Image.INTERPOLATE_BILINEAR)
		for y in 44:
			for x in 24:
				var c := small.get_pixel(x, y)
				small.set_pixel(x, y, Color(c.r * 0.38, c.g * 0.38, c.b * 0.38, 1.0))
		_bg[k] = ImageTexture.create_from_image(small)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := Layer.new()
	p.fn = _render_page
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(p)
	_page = p
	_vig = ColorRect.new()
	_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vig_m = ShaderMaterial.new()
	var sh := Shader.new()
	# the grade: vignette, tighter as it gets worse. radial-gradient centred at 46% of the height, H * 0.25 to H * 0.95
	sh.code = "shader_type canvas_item;\nuniform float a = 0.55;\nuniform vec2 res = vec2(1280.0, 720.0);\nvoid fragment() {\n\tfloat d = length((UV - vec2(0.5, 0.46)) * res) / res.y;\n\tCOLOR = vec4(0.0, 0.0, 0.0, a * clamp((d - 0.25) / 0.7, 0.0, 1.0));\n}\n"
	_vig_m.shader = sh
	_vig.material = _vig_m
	add_child(_vig)
	var o := Layer.new()
	o.fn = _render_over
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(o)
	_over = o
	t = 0.0
	_acc = 0.0
	_drops.clear()
	on = true


func skip() -> void:
	_finish(false)


func _finish(done: bool) -> void:
	if not on:
		return
	on = false
	queue_free()
	if on_end.is_valid():
		on_end.call(done)


func _input(e: InputEvent) -> void:
	if not on:
		return
	if (e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_X, KEY_ESCAPE, KEY_ENTER, KEY_SPACE]) or (e is InputEventMouseButton and e.pressed):
		get_viewport().set_input_as_handled()
		_finish(false)


func _process(delta: float) -> void:
	if not on:
		return
	_dt = minf(0.05, delta)
	t += _dt
	_vig_m.set_shader_parameter(&"res", _vig.size)
	_vig_m.set_shader_parameter(&"a", 0.55 + 0.15 * (t / _total))
	_page.queue_redraw()
	_over.queue_redraw()
	if t >= _total:
		_finish(true)


func _beat_i() -> int:
	for i in BEATS.size():
		if t < _starts[i] + float(BEATS[i].dur):
			return i
	return BEATS.size() - 1


## where a frame lands on screen: face scale and the eye midpoint position
func _place(k: StringName, W: float, H: float, zoom: float, ox: float, oy: float) -> Dictionary:
	var f: Dictionary = FRAMES[k]
	var im: Texture2D = _imgs[k]
	var sc: float = (0.215 * H * zoom) / (float(f.span) * im.get_width())      # eye span = 21.5% of the screen height at zoom 1
	var w := im.get_width() * sc
	var h := im.get_height() * sc
	var cx := W * 0.5 + ox
	var cy := H * 0.46 + oy
	return {"x": cx - float(f.ex) * w, "y": cy - float(f.ey) * h, "w": w, "h": h, "cx": cx, "cy": cy, "span": float(f.span) * w}


func _frame(g: Control, k: StringName, W: float, H: float, zoom: float, ox: float, oy: float, alpha: float) -> Dictionary:
	var p := _place(k, W, H, zoom, ox, oy)
	if alpha <= 0.002:
		return p
	g.draw_texture_rect(_bg[k], Rect2(0, 0, W, H), false, Color(1, 1, 1, alpha))      # soft backdrop (covers the sides of the portrait frame)
	g.draw_texture_rect(_imgs[k], Rect2(p.x, p.y, p.w, p.h), false, Color(1, 1, 1, alpha))
	return p


func _spawn_tears(rate: float, dt: float, p: Dictionary) -> void:
	_acc += rate * dt
	while _acc >= 1.0:
		_acc -= 1.0
		var side := -1.0 if randf() < 0.5 else 1.0
		var span: float = p.span
		_drops.append({"x": float(p.cx) + side * span * (0.5 + (randf() - 0.5) * 0.12), "y": float(p.cy) + span * 0.12, "side": side, "v": 0.05 + randf() * 0.06, "life": 0.0, "max": 1.4 + randf() * 1.2, "r": span * (0.018 + randf() * 0.012), "wob": randf() * 6.0})


func _draw_tears(g: Control, dt: float, p: Dictionary) -> void:
	var span: float = p.span
	var i := _drops.size() - 1
	while i >= 0:
		var d: Dictionary = _drops[i]
		d.life = float(d.life) + dt
		if float(d.life) > float(d.max):
			_drops.remove_at(i)
			i -= 1
			continue
		var u: float = float(d.life) / float(d.max)
		var vy: float = float(d.v) * span * (0.3 + u * 1.7) * 6.0      # starts slow on the lid, then runs
		d.y = float(d.y) + vy * dt
		d.x = float(d.x) + sin(float(d.life) * 3.0 + float(d.wob)) * span * 0.012 * dt * 6.0 + float(d.side) * span * 0.01 * dt
		var a := sin(PI * minf(1.0, u * 1.15)) * 0.85
		var r: float = d.r
		var len_ := r * (2.5 + u * 5.0)
		var x: float = d.x
		var y: float = d.y
		var top := Color(235.0 / 255.0, 225.0 / 255.0, 225.0 / 255.0, 0.0)
		var bot := Color(245.0 / 255.0, 235.0 / 255.0, 235.0 / 255.0, 0.28 * a)
		g.draw_polygon(PackedVector2Array([Vector2(x - r * 0.55, y - len_), Vector2(x + r * 0.55, y - len_), Vector2(x + r * 0.55, y + r), Vector2(x - r * 0.55, y + r)]), PackedColorArray([top, top, bot, bot]))      # the wet trail
		g.draw_set_transform(Vector2(x, y + r * 0.4), 0.0, Vector2(r * 0.75, r * 1.05))      # the drop
		g.draw_circle(Vector2.ZERO, 1.0, Color(250.0 / 255.0, 244.0 / 255.0, 244.0 / 255.0, 0.42 * a))
		g.draw_set_transform(Vector2.ZERO)
		g.draw_circle(Vector2(x - r * 0.25, y), r * 0.28, Color(1, 1, 1, 0.8 * a))      # its highlight
		i -= 1


func _render_page(g: Control) -> void:
	var W := g.size.x
	var H := g.size.y
	var bi := _beat_i()
	var b: Dictionary = BEATS[bi]
	var lt := t - _starts[bi]
	var u := clampf(lt / float(b.dur), 0.0, 1.0)
	# camera: one continuous push-in over the scene, plus the beat's own zoom drift
	var zoom := lerpf(b.zoom[0], b.zoom[1], Cutscene.ease_(u)) * (1.0 + 0.02 * sin(t * 0.7))
	var sp := H * 0.215 * zoom
	var shk: float = float(b.shake) * sp
	var trm: float = float(b.get("tremor", 0.0)) * sp
	var pulse := 0.5 - 0.5 * cos(t * float(b.alt_hz) * TAU) if b.has("alt") else 0.0      # sob tremor: 0..1 wave that also kicks the camera
	var ox := _noise(t, 1.0) * shk
	var oy := _noise(t, 1.7) * shk + pulse * trm * 2.0
	# outgoing beat during the blend
	var fd: float = b.fade
	var f := clampf(lt / fd, 0.0, 1.0) if fd > 0.1 else (Cutscene.ease_(lt / fd) if lt < fd else 1.0)
	if bi > 0 and f < 1.0:
		var pb: Dictionary = BEATS[bi - 1]
		_frame(g, pb.frame, W, H, pb.zoom[1], ox, oy, 1.0)
	var p := _frame(g, b.frame, W, H, zoom, ox, oy, Cutscene.ease_(f) if bi > 0 else 1.0)
	if b.has("alt"):
		_frame(g, b.alt, W, H, zoom, ox, oy, pulse * float(b.alt_amt))
	_spawn_tears(b.tears, _dt, p)
	_draw_tears(g, _dt, p)


func _render_over(g: Control) -> void:
	var W := g.size.x
	var H := g.size.y
	if BEATS[_beat_i()].frame == &"rage":
		g.draw_rect(Rect2(0, 0, W, H), Color(160.0 / 255.0, 20.0 / 255.0, 10.0 / 255.0, 0.10))
	# letterbox + black fades
	g.draw_rect(Rect2(0, 0, W, H * BAR), Color.BLACK)
	g.draw_rect(Rect2(0, H * (1.0 - BAR), W, H * BAR), Color.BLACK)
	var fa := maxf(maxf(1.0 - t / FADE_IN, 1.0 - (_total - t) / FADE_OUT), 0.0)
	if fa > 0.0:
		g.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, clampf(fa, 0.0, 1.0)))
