class_name VentGrate
extends CanvasLayer
## The short first-person card sequence at the alley intake grate before DEAD AIR loads (JS cutscenes/vent-grate.js). Five painted frames: the closed grate, hands on it, prising it out, setting it down, the open black duct. Tommy gets the white-handed copies of the three hand frames. It cross-fades frame to frame with a slow push, plays synthesised metal sounds on each beat and ends by pushing into the dark of the duct while the duct breathes out once. Emits `black` when the screen is black, so the door can swap the level in behind it; it removes itself after the level fade has covered it. X / Enter / Esc skip to the end.

signal black

const DIR := "res://assets/cutscenes/vent-grate/"
const SHOTS: Array = [      # frame, seconds on screen, scale at the start and end of its hold (the push), sound cue when it appears
	{"f": 0, "hold": 1.25, "s0": 1.0, "s1": 1.035, "cue": "still"},
	{"f": 1, "hold": 0.95, "s0": 1.035, "s1": 1.05, "cue": "grip"},
	{"f": 2, "hold": 0.85, "s0": 1.05, "s1": 1.07, "cue": "prise"},
	{"f": 3, "hold": 0.95, "s0": 1.07, "s1": 1.08, "cue": "set"},
	{"f": 4, "hold": 1.35, "s0": 1.08, "s1": 1.12, "cue": "open"},
]
const FADE := 0.16      # cross-fade between frames
const PUSH := 1.5       # the final push into the duct

var t := 0.0
var _cue := -1
var _done := false
var _skip := false
var _total := 0.0
var _starts: Array[float] = []
var _texs: Array[Texture2D] = []
var _view: Control
var _over: ColorRect
var _over_m: ShaderMaterial
var _in := 0.0
var _exhale: AudioStreamPlayer
var _snd := {}


class Pics:
	extends Control
	var o: VentGrate
	func _draw() -> void:
		o._draw_frames(self)


## the door's `before`: await VentGrate.play_it(character)
static func play_it(character: String) -> void:
	var v := VentGrate.new()
	v._setup(character)
	Game.add_child(v)
	await v.black


func _setup(character: String) -> void:
	layer = 100
	var tommy := character == "tommy"
	var a := 0.0
	for s: Dictionary in SHOTS:
		var f: int = s.f
		_texs.append(load(DIR + ("tommy-" if tommy and f >= 1 and f <= 3 else "frame-") + str(f) + ".webp"))
		_starts.append(a)
		a += float(s.hold)
	_total = a + PUSH
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_view = Pics.new()
	(_view as Pics).o = self
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fm := ShaderMaterial.new()      # (filter: contrast(1.06) brightness(.94))
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tCOLOR = vec4(clamp((c.rgb - 0.5) * 1.06 + 0.5, 0.0, 1.0) * 0.94, c.a);\n}\n"
	fm.shader = sh
	_view.material = fm
	add_child(_view)
	_over = ColorRect.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_over_m = ShaderMaterial.new()
	_over_m.shader = load("res://cutscenes/vent_grate.gdshader")
	_over.material = _over_m
	add_child(_over)
	_build_sounds()


static func _clank(at: float, f: float, g: float) -> Array:
	return [["t", at, 0.22, f, f * 0.42, {"type": "triangle", "gain": g, "wet": 0.35}], ["n", at, 0.09, {"type": "bandpass", "f0": 3200.0, "f1": 1400.0, "q": 2.4, "gain": g * 0.8, "wet": 0.3}]]


static func _scrape(at: float, dur: float, g: float = 0.09) -> Array:
	return [["n", at, dur, {"type": "bandpass", "f0": 900.0, "f1": 2600.0, "q": 5.0, "gain": g, "attack": 0.04, "wet": 0.35}], ["t", at, dur, 180.0, 240.0, {"type": "sawtooth", "gain": g * 0.18, "attack": 0.05, "wet": 0.2}]]


func _build_sounds() -> void:
	_snd["still"] = CineParts.sound("vent_still", [["n", 0.0, 1.2, {"type": "lowpass", "f0": 500.0, "f1": 300.0, "gain": 0.05, "attack": 0.4, "wet": 0.2}]])
	_snd["grip"] = CineParts.sound("vent_grip", _clank(0.0, 380.0, 0.1) + [["n", 0.05, 0.12, {"type": "highpass", "f0": 2500.0, "f1": 600.0, "gain": 0.05, "wet": 0.1}]])
	_snd["prise"] = CineParts.sound("vent_prise", _clank(0.0, 520.0, 0.14) + _scrape(0.06, 0.6) + _clank(0.5, 300.0, 0.12))
	_snd["set"] = CineParts.sound("vent_set", _scrape(0.0, 0.25, 0.06) + _clank(0.22, 240.0, 0.2) + _clank(0.36, 330.0, 0.08))
	_snd["rumble"] = CineParts.sound("vent_rumble", [["t", 0.0, 2.6, 46.0, 34.0, {"type": "sine", "gain": 0.3, "attack": 0.7, "wet": 0.1}]])
	_exhale = AudioStreamPlayer.new()
	_exhale.bus = &"SFX"
	_exhale.stream = _exhale_stream()
	add_child(_exhale)


## the duct breathing out: a long low exhale of air (the filter opens 260 -> 900 Hz over 1.1 s, closes to 180 by 2.6 s; the level rises to 0.42 by 0.9 s, falls away by 2.8 s), a rumble under it
static func _exhale_stream() -> AudioStreamWAV:
	var R := FartSynth.R
	var n := int(2.9 * R)
	var b := PackedByteArray()
	b.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var c := FartSynth._hz_q(260.0, pow(10.0, 0.9 / 20.0))
	for i in n:
		var tt := float(i) / float(R)
		if i % 16 == 0:
			var f := lerpf(260.0, 900.0, tt / 1.1) if tt < 1.1 else lerpf(900.0, 180.0, minf(1.0, (tt - 1.1) / 1.5))
			c = FartSynth._hz_q(f, pow(10.0, 0.9 / 20.0))
		var g := 0.42 * tt / 0.9 if tt < 0.9 else 0.42 * pow(0.0001 / 0.42, minf(1.0, (tt - 0.9) / 1.9))
		var v := rng.randf() * 2.0 - 1.0
		var y := c[0] * v + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = v
		y2 = y1
		y1 = y
		b.encode_s16(i * 2, int(clampf(y * g, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = R
	w.data = b
	return w


func _play_cue(id: String) -> void:
	if id == "open":
		get_tree().create_timer(0.5).timeout.connect(_breathe)
		return
	CineParts.play(_snd[id])


func _breathe() -> void:
	if _skip or not is_instance_valid(_exhale):
		return
	_exhale.play()
	CineParts.play(_snd["rumble"])


func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_X, KEY_ENTER, KEY_ESCAPE, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		_skip = true


func _process(delta: float) -> void:
	if _done:
		return
	var dt := minf(0.05, delta)
	t += dt
	_in = minf(1.0, _in + dt / 0.35)      # (#ventcs.on: opacity .35s)
	if _skip and t < _total - 0.35:
		t = _total - 0.35
		_exhale.stop()
	# which shot is up
	var k := SHOTS.size() - 1
	for i in SHOTS.size():
		if t < _starts[i] + float(SHOTS[i].hold):
			k = i
			break
	if k != _cue and not _skip:
		_cue = k
		_play_cue(SHOTS[k].cue)
	_view.modulate.a = _in
	_view.queue_redraw()
	_over_m.set_shader_parameter(&"shade", Cutscene.ease_((t - (_total - PUSH * 0.75)) / (PUSH * 0.7)))
	_over_m.set_shader_parameter(&"time", t)
	_over_m.set_shader_parameter(&"res", _over.size)
	_over_m.set_shader_parameter(&"fade", _in)
	if t >= _total:
		_done = true
		black.emit()
		get_tree().create_timer(1.2).timeout.connect(queue_free)      # the level fade is opaque by then


func _draw_frames(c: Control) -> void:
	var sz := c.size
	var w := minf(sz.x, sz.y * 1.5)      # width: min(100vw, 150vh)
	var last := SHOTS.size() - 1
	for i in SHOTS.size():
		var s: Dictionary = SHOTS[i]
		var tex := _texs[i]
		var hold: float = s.hold
		var u := (t - _starts[i]) / hold
		var o := 1.0 if i == 0 else Cutscene.ease_((t - _starts[i] + FADE) / FADE)
		if t < _starts[i] - FADE:
			o = 0.0
		if o <= 0.0:
			continue
		var scale_: float = float(s.s0) + (float(s.s1) - float(s.s0)) * Cutscene.ease_(u)
		if i == last and t > _starts[i] + hold:      # push into the duct
			scale_ = float(s.s1) + 1.7 * pow(Cutscene.ease_((t - _starts[i] - hold) / PUSH), 1.6)
		var h := w * float(tex.get_height()) / float(tex.get_width())
		var up := 4.0 * Cutscene.ease_((t - _starts[i] - hold) / PUSH) if i == last else 0.0      # (translate -(50 + up)% of its own height)
		var sw := w * scale_
		var sh := h * scale_
		var cx := sz.x * 0.5
		var cy := sz.y * 0.5 - h * up / 100.0
		c.draw_texture_rect(tex, Rect2(cx - sw * 0.5, cy - sh * 0.5, sw, sh), false, Color(1.0, 1.0, 1.0, o))
