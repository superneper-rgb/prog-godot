class_name DevNotice
extends Control
## Developer note, shown after the logo sting and before the main menu (intro/dev-notice.js), in the same green-phosphor CRT look: the set powers on, the note types itself out with a block cursor,
## "PRESS ANY BUTTON" blinks, and the next key / click / pad button switches the set off and hands over to the menu. Any input while it is still typing just finishes the text. Temporary: the note goes once the game is finished.

const TITLE := "A NOTE FROM THE DEVELOPERS"
const MESSAGE: Array[String] = [
	"This is a work in progress development of a game that we have designed in our heads over the years. AI is at a point where it is possible to make this a reality. We do not code, and we are stupid Neanderthals.",
	"Our goal was simply to see what we could make with the help of AI and how far we could get. We think, personally, that we got pretty far. We would draw out what we wanted physically, as well as designed the characters by drawing them before allowing some AI to work their magic. We influenced the art direction of what we wanted through 100's of prompts and drawing and art. We let AI do ALL of the heavy lifting. Essentially using AI as a huge glorified gamemaker or RPG maker tool. This is a work in progress, and work is still currently ongoing. Thank you for being one of the people who were interested in playing and touching the game.",
]
const CPS := 110.0                       # characters typed per second
const ON_A := 0.15                       # power on, then typing starts
const ON_LINE := 0.4
const ON_B := 0.75
const TYPE_T := 1.0
const OFF_LINE := 0.3                    # power off, timed from the press that ends it
const OFF_B := 0.55
const OFF_DOT := 1.05
const OFF_END := 1.3

var on_done := Callable()
var t := 0.0
var shown := 0.0
var off_at := -1.0
var _done := false
var _last_tick := 0
var _quad: ColorRect
var _m: ShaderMaterial
var _vp: SubViewport
var _page: Page
var _pad_held := true                    # a pad button still held from skipping the logo must be let go first
var _tick: AudioStreamPlayer
var _thunk: AudioStreamPlayer


## The text page: drawn into a viewport the size of the screen (so the letters are pixel sharp), laid out again on resize.
class Page extends Control:
	var lines: PackedStringArray = []
	var x0 := 0.0
	var y0 := 0.0
	var fs := 24
	var lh := 34
	var total := 0
	var shown := 0
	var blink := false
	var prompt := false
	func relayout() -> void:
		var W := size.x
		var H := size.y
		var f := CrtTheme.font(&"lucida")
		var max_w := minf(W * 0.74, H * 1.45)
		fs = roundi(H * 0.034)
		while true:          # shrink until the whole note fits in the middle of the screen
			lh = roundi(fs * 1.42)
			lines = PackedStringArray()
			for k in DevNotice.MESSAGE.size():
				if k > 0:
					lines.append("")
				var cur := ""
				for w in DevNotice.MESSAGE[k].split(" "):
					var next := w if cur == "" else cur + " " + w
					if CrtTheme.text_w(f, next, fs) > max_w and cur != "":
						lines.append(cur)
						cur = w
					else:
						cur = next
				if cur != "":
					lines.append(cur)
			if lines.size() * lh <= H * 0.6 or fs <= 12:
				break
			fs -= 1
		x0 = roundf((W - max_w) * 0.5)
		y0 = roundf((H - lines.size() * lh) * 0.5 + H * 0.03)
		total = 0
		for l in lines:
			total += l.length()
	func _draw() -> void:
		var W := size.x
		var H := size.y
		var f := CrtTheme.font(&"lucida")
		var fb := CrtTheme.font(&"lucidab")
		var c := Color.WHITE
		var ts := roundi(fs * 1.05)
		CrtTheme.draw_text(self, fb, x0, y0 - lh * 2.2 + fb.get_ascent(ts), DevNotice.TITLE, ts, c)
		draw_rect(Rect2(x0, y0 - lh * 0.95, minf(W - 2.0 * x0, CrtTheme.text_w(fb, DevNotice.TITLE, ts) * 1.3), maxf(2.0, roundf(fs * 0.08))), c)
		var left := shown
		var cx := x0
		var cy := y0
		var asc := f.get_ascent(fs)
		for i in lines.size():
			if left <= 0:
				break
			var s := lines[i].substr(0, left)
			left -= s.length()
			cy = y0 + i * lh
			CrtTheme.draw_text(self, f, x0, cy + asc, s, fs, c)
			cx = x0 + CrtTheme.text_w(f, s, fs)
		if shown < total or blink:
			draw_rect(Rect2(cx + fs * 0.15, cy + fs * 0.05, fs * 0.55, fs * 0.95), c)          # block cursor
		var m := roundf(H * 0.075)                                                             # VCR on-screen display, as on the logo
		var os := roundi(fs * 0.95)
		var oa := fb.get_ascent(os)
		CrtTheme.draw_text(self, fb, m, m + oa, "NOTE", os, c)
		CrtTheme.draw_right(self, fb, W - m, m + oa, "CH 03", os, c)
		if prompt and blink:
			var ps := roundi(fs * 1.1)
			CrtTheme.draw_center(self, fb, W * 0.5, H - m - fs * 1.2 + fb.get_ascent(ps), "PRESS ANY BUTTON", ps, c)


func _init() -> void:
	name = "DevNotice"
	CrtTheme.full(self, false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60


func _ready() -> void:
	_quad = ColorRect.new()
	_quad.color = Color.WHITE
	CrtTheme.full(_quad)
	_m = CrtTheme.mat("res://ui/intro/dev_notice.gdshader")
	_quad.material = _m
	add_child(_quad)
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.transparent_bg = true
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_page = Page.new()
	_vp.add_child(_page)
	add_child(_vp)
	_m.set_shader_parameter(&"text_tex", _vp.get_texture())
	_tick = _player(_tone(1800.0, 0.02, 0.02, true))
	_thunk = _player(_tone(140.0, 0.3, 0.08, false))
	get_viewport().size_changed.connect(_resize)
	_resize()


func _player(s: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = s
	add_child(p)
	return p


## The note's two little sounds (JS blip: an oscillator gliding down an octave, an exponential fade): a key tick while it types, a thunk when the set switches off.
static func _tone(hz: float, dur: float, gain: float, square: bool) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var u := float(i) / float(n)
		ph += TAU * hz * pow(0.5, u) / rate
		var w := (1.0 if sin(ph) >= 0.0 else -1.0) if square else sin(ph)
		data.encode_s16(i * 2, int(clampf(w * gain * pow(0.0001 / gain, u), -1.0, 1.0) * 32767.0))
	var a := AudioStreamWAV.new()
	a.format = AudioStreamWAV.FORMAT_16_BITS
	a.mix_rate = rate
	a.data = data
	return a


func _resize() -> void:
	var f := CrtTheme.px(self)
	var real := get_viewport_rect().size * f
	var W := int(minf(2560.0, maxf(640.0, roundf(real.x))))
	var H := int(maxf(360.0, roundf(W * real.y / real.x)))
	_vp.size = Vector2i(W, H)
	_page.size = Vector2(W, H)
	_page.relayout()
	_page.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_m.set_shader_parameter(&"res", real)


static func _seg(v: float, a: float, b: float) -> float:
	return clampf((v - a) / (b - a), 0.0, 1.0)


static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)


static func _ease_in(u: float) -> float:
	return u * u * u


func simulate(dt: float) -> void:
	t += dt
	var typing := t >= TYPE_T and shown < _page.total
	if typing:
		var before := int(shown)
		shown = minf(_page.total, shown + CPS * dt)
		if int(shown) - _last_tick >= 3 and int(shown) != before:
			_last_tick = int(shown)
			_tick.pitch_scale = 1.0 + randf() * 0.28
			_tick.play()
	var sx := 0.0 if t < ON_A else _ease_out(_seg(t, ON_A, ON_LINE))
	var sy := 0.0 if t < ON_A else lerpf(0.004, 1.0, _ease_out(_seg(t, ON_LINE, ON_B)))
	var dot_v := 0.0
	if off_at >= 0.0:      # switching off: the picture collapses to a line, the line to a dot, the dot fades
		var k := t - off_at
		sy = lerpf(1.0, 0.004, _ease_in(_seg(k, 0.0, OFF_LINE)))
		sx = 1.0 - _ease_in(_seg(k, OFF_LINE, OFF_B))
		if k >= OFF_B:
			sx = 0.0
		dot_v = _seg(k, OFF_LINE + 0.1, OFF_B) * (1.0 - _seg(k, OFF_B, OFF_DOT))
		if k > OFF_END:
			finish()
			return
	_m.set_shader_parameter(&"sx_u", sx)
	_m.set_shader_parameter(&"sy_u", sy)
	_m.set_shader_parameter(&"dot_u", dot_v)
	_m.set_shader_parameter(&"static_u", 0.5 if t < ON_B + 0.15 else 0.03)
	_m.set_shader_parameter(&"glitch", 0.6 * (1.0 - _seg(t, ON_B, TYPE_T)) if t < TYPE_T else 0.02)
	_m.set_shader_parameter(&"time_s", t)
	var n_shown := int(shown)
	var blink := int(t * 1.7) % 2 == 0
	var prompt := shown >= _page.total and off_at < 0.0
	if n_shown != _page.shown or blink != _page.blink or prompt != _page.prompt:
		_page.shown = n_shown
		_page.blink = blink
		_page.prompt = prompt
		_page.queue_redraw()
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	if _done:
		return
	simulate(minf(0.05, maxf(0.001, delta)))
	var any := false
	for id: int in ([] as Array[int] if Inp.real_off else Input.get_connected_joypads()):
		for b in 16:
			if Input.is_joy_button_pressed(id, b):
				any = true
	if any and not _pad_held:
		press()
	_pad_held = any


## A key / click / pad button: finish the typing, or (once it is all on screen) switch the set off.
func press() -> void:
	if _done or off_at >= 0.0 or t < ON_B:
		return
	if shown < _page.total:
		shown = _page.total
		return
	off_at = t
	_thunk.play()


func finish() -> void:
	if _done:
		return
	_done = true
	queue_free()
	if on_done.is_valid():
		on_done.call()


func _input(event: InputEvent) -> void:
	if Inp.real_off:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.physical_keycode != KEY_QUOTELEFT:
			press()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		press()
		get_viewport().set_input_as_handled()
