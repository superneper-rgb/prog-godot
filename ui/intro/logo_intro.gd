class_name LogoIntro
extends Control
## Opening logo sting (intro/logo-intro.js): the SHIT HOUSE logo (assets/intro/logo.webp) on an old green-phosphor CRT. The set powers on (a bright line that opens up into snow), the logo pops in
## with a glitch burst and a flash, sits there with scanlines, a rolling bar, ghosting, tracking glitches and a VCR on-screen display, then the set switches off and it hands over. Any key, click or pad button skips it.

const LOGO := "res://assets/intro/logo.webp"
const SONG := "res://assets/intro/logo-intro.wav"    # rendered on this timeline (started in sync with the clock)
# timeline (seconds). The sound is rendered on these times.
const ON_A := 0.35        # power on: a dot stretches into a line, the line opens into the picture
const ON_LINE := 0.6
const ON_B := 0.95
const POP := 2.0          # the logo pops in (snow and the reversed swell until then)
const OFF_A := 7.2        # power off: the picture collapses to a line, the line to a dot
const OFF_LINE := 7.5
const OFF_B := 7.75
const DOT_END := 8.25     # the dot fades, hand over to the menu
const END := 8.6
# tracking glitches while the logo sits there: [start, length, strength]
const GLITCHES: Array = [[3.25, 0.12, 0.6], [4.2, 0.22, 0.9], [5.1, 0.08, 0.5], [5.95, 0.28, 1.0], [7.05, 0.15, 0.7]]

var on_done := Callable()
var t := 0.0
var skipping := 0.0
var _done := false
var _quad: ColorRect
var _m: ShaderMaterial
var _osd_vp: SubViewport
var _osd: OsdView
var _hint: Label
var _song: AudioStreamPlayer
var _pad_prev := true


class OsdView extends Control:
	var play := false
	var tc := ""
	func _draw() -> void:
		var f := CrtTheme.font(&"lucidab")
		var fs := 34
		var top := 58.0 + f.get_ascent(fs)
		var bot := size.y - 92.0 + f.get_ascent(fs)
		if play:
			CrtTheme.draw_text(self, f, 72.0, top, "PLAY ▶", fs, Color.WHITE)
		CrtTheme.draw_right(self, f, size.x - 72.0, top, "CH 03", fs, Color.WHITE)
		CrtTheme.draw_text(self, f, 72.0, bot, "SP", fs, Color.WHITE)
		CrtTheme.draw_right(self, f, size.x - 72.0, bot, tc, fs, Color.WHITE)


func _init() -> void:
	name = "LogoIntro"
	CrtTheme.full(self, false)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 60


func _ready() -> void:
	_quad = ColorRect.new()
	_quad.color = Color.WHITE
	CrtTheme.full(_quad)
	_m = CrtTheme.mat("res://ui/intro/logo_intro.gdshader")
	var tex: Texture2D = load(LOGO)
	_m.set_shader_parameter(&"logo_tex", tex)
	_m.set_shader_parameter(&"logo_aspect", float(tex.get_width()) / float(tex.get_height()))
	_quad.material = _m
	add_child(_quad)
	# the VCR on-screen display, drawn into a viewport the shader samples through the same tube
	_osd_vp = SubViewport.new()
	_osd_vp.size = Vector2i(960, 540)
	_osd_vp.disable_3d = true
	_osd_vp.transparent_bg = true
	_osd_vp.gui_disable_input = true
	_osd_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_osd = OsdView.new()
	_osd.size = Vector2(960, 540)
	_osd_vp.add_child(_osd)
	add_child(_osd_vp)
	_m.set_shader_parameter(&"osd_tex", _osd_vp.get_texture())
	_hint = CrtTheme.label("PRESS ANY KEY TO SKIP", &"sys", 11, Color("5f8f6a"), 2)
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_right = -22.0
	_hint.offset_left = -22.0
	_hint.offset_bottom = -16.0
	_hint.offset_top = -16.0
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.modulate.a = 0.0
	add_child(_hint)
	_song = AudioStreamPlayer.new()
	_song.stream = load(SONG)
	_song.volume_db = linear_to_db(0.55)
	add_child(_song)
	_song.play()


static func _seg(v: float, a: float, b: float) -> float:
	return clampf((v - a) / (b - a), 0.0, 1.0)


static func _ease_out(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)


static func _ease_in(u: float) -> float:
	return u * u * u


func simulate(dt: float) -> void:
	t += dt
	# power on / off
	var sx := 0.0
	var sy := 0.0
	if t >= ON_A and t < OFF_B:
		sx = _ease_out(_seg(t, ON_A, ON_LINE)) if t < OFF_LINE else 1.0 - _ease_in(_seg(t, OFF_LINE, OFF_B))
		sy = lerpf(0.004, 1.0, _ease_out(_seg(t, ON_LINE, ON_B))) if t < OFF_A else lerpf(1.0, 0.004, _ease_in(_seg(t, OFF_A, OFF_LINE)))
	_m.set_shader_parameter(&"sx_u", sx)
	_m.set_shader_parameter(&"sy_u", sy)
	_m.set_shader_parameter(&"dot_u", _seg(t, OFF_LINE + 0.1, OFF_B) * (1.0 - _seg(t, OFF_B, DOT_END)) if t >= OFF_LINE else 0.0)
	# the pop: a springy overshoot, a touch out of step between width and height so it squashes and stretches
	var u := t - POP
	_m.set_shader_parameter(&"logo_on", 1.0 if u > 0.0 else 0.0)
	_m.set_shader_parameter(&"pop_x", (1.0 - exp(-5.0 * u) * cos(13.0 * u)) * (1.0 + 0.012 * sin(t * 2.2)) if u > 0.0 else 0.0)
	_m.set_shader_parameter(&"pop_y", (1.0 - exp(-5.0 * u) * cos(10.5 * u)) * (1.0 + 0.012 * sin(t * 2.2)) if u > 0.0 else 0.0)
	_m.set_shader_parameter(&"flash", exp(-u * 7.0) if u > 0.0 else 0.0)
	var g := 0.03 + (maxf(0.0, 1.0 - u / 0.4) if u > 0.0 else 0.0)
	for gl: Array in GLITCHES:
		var a: float = gl[0]
		var d: float = gl[1]
		var s: float = gl[2]
		if t >= a and t < a + d:
			g = maxf(g, s * (1.0 - (t - a) / d * 0.5))
	_m.set_shader_parameter(&"glitch", g)
	_m.set_shader_parameter(&"static_u", (1.0 if t >= ON_LINE else 0.0) if t < POP else 0.05 + g * 0.35)
	var sh := exp(-u * 9.0) * 0.02 if u > 0.0 else 0.0
	_m.set_shader_parameter(&"shake", Vector2((randf() - 0.5) * sh, (randf() - 0.5) * sh))
	_m.set_shader_parameter(&"osd_a", 0.85 if (t > ON_B + 0.25 and t < OFF_A) else 0.0)
	_m.set_shader_parameter(&"time_s", t)
	var fr := int(t * 30.0)
	var tc := "00:00:%02d:%02d" % [int(t), fr % 30]
	var blink := int(t * 1.6) % 2 == 0
	if tc != _osd.tc or blink != _osd.play:
		_osd.tc = tc
		_osd.play = blink
		_osd.queue_redraw()
	# skip: fade out quickly
	var fade := 0.0
	if skipping > 0.0:
		skipping += dt
		fade = clampf(skipping / 0.35, 0.0, 1.0)
	_m.set_shader_parameter(&"fade", fade)
	_song.volume_db = linear_to_db(maxf(0.0001, 0.55 * (1.0 - fade)))
	if t > END or skipping > 0.4:
		finish()


func _process(delta: float) -> void:
	if _done:
		return
	var f := CrtTheme.px(self)
	_m.set_shader_parameter(&"res", get_viewport_rect().size * f)
	simulate(minf(0.05, maxf(0.001, delta)))
	_hint.modulate.a = move_toward(_hint.modulate.a, 1.0 if t > 1.2 else 0.0, delta / 0.6)
	# a pad button skips too
	var any := false
	for id: int in ([] as Array[int] if Inp.real_off else Input.get_connected_joypads()):
		for b in 16:
			if Input.is_joy_button_pressed(id, b):
				any = true
	if any and not _pad_prev:
		skip()
	_pad_prev = any


func skip() -> void:
	if skipping == 0.0:
		skipping = 0.0001


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
			skip()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		skip()
		get_viewport().set_input_as_handled()
