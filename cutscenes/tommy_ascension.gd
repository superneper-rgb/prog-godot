class_name TommyAscension
extends Cutscene
## TOMMY ASCENSION CUTSCENE (JS cutscenes/tommy-ascension.js): Cargo Depot 9, a FOINT freight yard at night. A crowd of FOINT security robots closes in until Prog and Tommy have their backs to the stacked containers; Prog rambles through his ideas while Tommy stands silent, head bowed. Then Tommy says it ("I'm not supposed to do this. My creator would be so disappointed..."): the ground cracks, a golden aura and lightning pour off him, his hair grows out long and gold, his brows go and his eyes turn piercing blue (Super Saiyan 3), the robots open fire on the aura in vain, and he fires the game's Kamehameha (levels/kame_lab/kamehameha.gd, used as is) in a sweep that wipes the whole crowd out. Prog is in awe.
## A test cutscene: nothing in a level plays it (dev console: "cutscene play tommy-ascension"; X skips). The set is built 3 km above the world (FY) so it shares no space with whatever level is loaded; the scene look (fog, background, sun, hemisphere light) and the player's position (the sun's shadow follows him) are borrowed for the length of it and put back. The game is frozen behind it.
## Sound is all synthesized (a score + voice blips) apart from the Kamehameha's own recorded clips. ENGINE DIFFERENCE: the JS's sustained chords are live oscillators; here each is a loop rendered once, its gain and (the swell's) cutoff eased the same way.

const FY := 3000.0
const WALL_R := 27.0
const BACK_Z := -4.4
const PROG_X := -0.95
const TOMMY_X := 0.95
const HEAD_Y := 1.45      # Tommy's head bone height in his model space (hair and hat are placed in it)
const HAIR_GOLD := 0xffc81e
const SWEEP_FROM := -0.75      # the beam's heading (rad from +z) at its start and its end
const SWEEP_TO := 0.75
const RINGS: Array[float] = [9.0, 11.8, 14.6, 17.4]
const VOICES := {"PROG": {"color": "#9fd8ff", "rate": 19.0, "pitch": 102.0}, "TOMMY": {"color": "#ffd36b", "rate": 9.0, "pitch": 130.0}, "FOINT SECURITY": {"color": "#ff7a6a", "rate": 17.0, "pitch": 92.0, "robot": true}}
const VOWEL := {"a": [730.0, 1090.0], "e": [530.0, 1840.0], "i": [300.0, 2290.0], "o": [570.0, 840.0], "u": [325.0, 700.0]}
const B_LP := &"AscLp"


static func _L(who: String, text: String, rate: float = -1.0, hold: float = 0.6) -> Dictionary:
	return {"who": who, "text": text, "rate": rate if rate > 0.0 else float(VOICES[who]["rate"]), "hold": hold}


static func _dur(l: Dictionary) -> float:
	return String(l["text"]).length() / float(l["rate"]) + float(l["hold"])


var RAMBLE := [
	_L("PROG", "Okay. Okay okay okay. Nobody panic.", 19.0, 0.55),
	_L("PROG", "Idea! We run. ...Where? Okay, no. New idea.", 19.0, 0.55),
	_L("PROG", "We play dead! Robots don't shoot dead guys. That's a rule. I think that's a rule.", 19.0, 0.6),
	_L("PROG", "Or we apologize! Sorry! Our bad! We'll pay for... whatever this is!", 19.0, 0.5),
	_L("PROG", "I do the dance, you flank! ...You can't flank. They're everywhere.", 19.0, 0.6),
	_L("PROG", "Tommy. Tommy, buddy. Any ideas? ...Tommy?", 14.0, 1.5),
]
var PA1 := _L("FOINT SECURITY", "ATTENTION. YOU ARE TRESPASSING ON FOINT PROPERTY. TERMS AND CONDITIONS APPLY.", 17.0, 0.4)
var SAY1 := _L("TOMMY", "I'm not supposed to do this.", 9.0, 1.0)
var SAY2 := _L("TOMMY", "My creator would be so disappointed...", 8.0, 1.2)
var AWE := _L("PROG", "...Tommy?", 7.0, 0.5)
var PA2 := _L("FOINT SECURITY", "POWER LEVEL... ERROR. ERROR. ERROR.", 12.0, 0.3)
var END_P := _L("PROG", "Tommy... how long have you been able to do that?", 15.0, 0.9)
var END_T := _L("TOMMY", "...Since the gunshop.", 9.0, 1.4)
var T := {}

var t := -1.0
var real := 0.0
var hold := false      # (tests)
var _ei := 0
var _shake := 0.0
var _aura := 0.0
var _xf := 0.0
var _flash := 0.0
var _dome_at := -1.0
var _ev: Array = []
var _order := 0
var _root: Node3D = null
var _line: Variant = null
var _saved: Variant = null
var H: Variant = null
var bots: Array[Dictionary] = []
var _bot_of := {}
var K: Variant = null
var _set_p: Variant = null
var vfx := {}
var _flash_el: ColorRect = null
var _wait := 0.0
var _acc := 0.0
var _players: Array[AudioStreamPlayer] = []
var _stacks := {}
var _ramps: Array[Dictionary] = []
var _rise_cut := {"cur": 300.0, "t0": -1.0}
var _yells := {}
var _next_id := 9000


func _init() -> void:
	name = "TommyAscension"
	var c := 9.4
	var tt := {"fadeIn": 0.9, "pa": 3.0, "aim": 8.2, "ramble": 9.4, "rl": []}
	for l: Dictionary in RAMBLE:
		tt["rl"].append(c)
		c += _dur(l)
	tt["quiet"] = c
	tt["breath"] = c + 0.8
	tt["l1"] = c + 0.8 + 1.6
	tt["l2"] = float(tt["l1"]) + _dur(SAY1) + 0.3
	tt["rise"] = float(tt["l2"]) + _dur(SAY2)
	var rise: float = tt["rise"]
	tt["hatOff"] = rise + 3.3
	tt["flash"] = rise + 6.6
	tt["reveal"] = rise + 6.6 + 0.5
	tt["awe"] = float(tt["reveal"]) + 2.2
	tt["pa2"] = float(tt["awe"]) + _dur(AWE) + 0.3
	tt["barrage"] = float(tt["pa2"]) + 1.0
	tt["kame"] = float(tt["pa2"]) + 3.4
	tt["rel"] = float(tt["kame"]) + 2.9
	tt["beam"] = float(tt["rel"]) + 0.13
	tt["dome"] = float(tt["rel"]) + 3.1
	tt["after"] = float(tt["dome"]) + 3.6
	tt["endP"] = float(tt["after"]) + 0.5
	tt["endT"] = float(tt["endP"]) + _dur(END_P) + 0.3
	tt["fadeOut"] = float(tt["endT"]) + _dur(END_T) + 0.6
	tt["end"] = float(tt["fadeOut"]) + 2.0
	T = tt


func _E(tm: float, fn: Callable) -> void:
	_order += 1
	_ev.append({"t": tm, "fn": fn, "n": _order})
	_ev.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] < b["t"] if a["t"] != b["t"] else a["n"] < b["n"])


static func _win(tm: float, a: float, b: float, fi: float = 0.25, fo: float = 0.25) -> float:      # 0 -> 1 -> 0 envelope over [a, b]
	return Cutscene.ease_((tm - a) / fi) * (1.0 - Cutscene.ease_((tm - b) / fo))


static func rr(a: float, b: float) -> float:
	return a + randf() * (b - a)


# ---- sound: the level's beds fall silent, the score and the voices on their own bus ----
static func _lp_coef(fc: float, R: float) -> float:
	return 1.0 - exp(-TAU * fc / R)


## a sustained chord: detuned oscillators through a low-pass, a seamless loop (each oscillator a whole number of cycles in it)
static func _stack_wav(freqs: Array, wave: StringName, cutoff: float) -> AudioStreamWAV:
	const R := 22050
	const LEN := 4.0
	var n := int(R * LEN)
	var b := PackedFloat32Array()
	b.resize(n)
	var co := _lp_coef(cutoff, R)
	for fr: float in freqs:
		for d: float in [-0.004, 0.004]:
			var f := roundf(fr * (1.0 + d) * LEN) / LEN
			var ph := randf()
			var inc := f / R
			var y := 0.0
			var y2 := 0.0
			for pass_ in 2:      # (twice round: the filter is settled when the loop is written)
				for i in n:
					ph = fposmod(ph + inc, 1.0)
					var s := 2.0 * ph - 1.0 if wave == &"sawtooth" else (1.0 if ph < 0.5 else -1.0)
					y += (s - y) * co
					y2 += (y - y2) * co
					if pass_ == 1:
						b[i] += y2 / (freqs.size() * 2.0)      # (kept in range: _stack's gain gives the count back)
	var w := OfflineSynth.wav(b, R)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


## JS: a triangle at 690 Hz, 0.55 Hz of vibrato 130 wide
static func _siren_wav() -> AudioStreamWAV:
	const R := 22050
	var per := 1.0 / 0.55
	var n := int(R * per)
	var b := PackedFloat32Array()
	b.resize(n)
	var ph := 0.0
	for i in n:
		var tm := float(i) / R
		ph = fposmod(ph + (690.0 + 130.0 * sin(TAU * 0.55 * tm)) / R, 1.0)
		b[i] = (1.0 - 4.0 * absf(ph - 0.5)) * 0.9
	var w := OfflineSynth.wav(b, R)
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = n
	return w


static func _bq(x: PackedFloat32Array, f: float, q: float, R: float) -> PackedFloat32Array:
	var w := TAU * f / R
	var cw := cos(w)
	var al := sin(w) / (2.0 * q)
	var a0 := 1.0 + al
	var b0 := al / a0
	var a1 := -2.0 * cw / a0
	var a2 := (1.0 - al) / a0
	var o := PackedFloat32Array()
	o.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in x.size():
		var v := x[i]
		var y := b0 * v - b0 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = v
		y2 = y1
		y1 = y
		o[i] = y
	return o


## a voiced yell: a sawtooth through the vowel's formants with vibrato, gliding f0 -> f1
static func _yell_wav(dr: float, f0: float, f1: float, gain: float, vowel: String) -> AudioStreamWAV:
	const R := 22050
	var n := int((dr + 0.05) * R)
	var saw := PackedFloat32Array()
	saw.resize(n)
	var ph := 0.0
	for i in n:
		var tm := float(i) / R
		var u := minf(tm / (dr * 0.8), 1.0)
		var f := f0 * pow(f1 / f0, u) + f0 * 0.03 * sin(TAU * 6.5 * tm)
		ph = fposmod(ph + f / R, 1.0)
		saw[i] = 2.0 * ph - 1.0
	var fs: Array = VOWEL.get(vowel, VOWEL["a"])
	var a := _bq(saw, fs[0], 4.0, R)
	var b := _bq(saw, fs[1], 4.0, R)
	for i in n:
		var tm := float(i) / R
		var e := gain * minf(tm / 0.12, 1.0) if tm < dr - 0.25 else gain * pow(0.0001 / gain, clampf((tm - (dr - 0.25)) / 0.25, 0.0, 1.0))
		saw[i] = (a[i] + b[i] * 0.5) * e
	return OfflineSynth.wav(saw, R)


func _bus(bn: StringName, send: StringName, g: float) -> void:
	var i := AudioServer.get_bus_index(bn)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bn)
		AudioServer.set_bus_send(i, send)
	AudioServer.set_bus_volume_db(i, linear_to_db(g))


func _audio_on() -> void:
	_bus(B_LP, &"SFX", 0.9)
	var i := AudioServer.get_bus_index(&"AscRise")
	if i < 0:
		_bus(&"AscRise", B_LP, 1.0)
		i = AudioServer.get_bus_index(&"AscRise")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 300.0
		AudioServer.add_bus_effect(i, lp)
	(AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter).cutoff_hz = 300.0
	_stacks = {
		"drone": _stack(_stack_wav([55.0, 82.4], &"sawtooth", 220.0), 0.2 * 4.0, B_LP),      # the dread under everything
		"rise": _stack(_stack_wav([110.0, 164.8], &"sawtooth", 11000.0), 0.2 * 4.0, &"AscRise"),      # the power-up swell (its cutoff is swept by the update)
		"hero": _stack(_stack_wav([110.0, 164.8, 220.0, 277.2, 329.6], &"sawtooth", 1500.0), 0.1 * 10.0, B_LP),      # the bright chord after the flash
		"hum": _stack(_stack_wav([138.0, 207.0], &"square", 420.0), 0.05 * 4.0, B_LP),      # the crowd's servo hum
		"siren": _stack(_siren_wav(), 1.0 / 0.9, B_LP),
	}
	_yells = {"rise": _yell_wav(5.6, 140.0, 520.0, 0.7, "a"), "rel": _yell_wav(2.2, 260.0, 330.0, 0.8, "a")}
	for b: StringName in Game.level_beds():
		var bi := AudioServer.get_bus_index(b)
		if bi >= 0:
			AudioServer.set_bus_mute(bi, true)


func _stack(w: AudioStreamWAV, gain: float, bus_: StringName) -> Dictionary:
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.bus = bus_
	p.volume_db = -80.0
	add_child(p)
	p.play()
	_players.append(p)
	return {"p": p, "gain": gain, "cur": 0.0}


func _audio_off() -> void:
	for p: AudioStreamPlayer in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()
	_ramps.clear()
	_stacks = {}
	for b: StringName in Game.level_beds():
		var bi := AudioServer.get_bus_index(b)
		if bi >= 0:
			AudioServer.set_bus_mute(bi, false)


func _level(n: String, to: float, tau: float = 0.4) -> void:
	if not _stacks.has(n):
		return
	var s: Dictionary = _stacks[n]
	_ramps = _ramps.filter(func(r: Dictionary) -> bool: return r["n"] != n)
	_ramps.append({"n": n, "s": s, "to": to * float(s["gain"]), "tau": tau})


func _ramp_step(dt: float) -> void:
	for r: Dictionary in _ramps:
		var s: Dictionary = r["s"]
		s["cur"] = float(r["to"]) + (float(s["cur"]) - float(r["to"])) * exp(-dt / float(r["tau"]))
		if is_instance_valid(s["p"]):
			(s["p"] as AudioStreamPlayer).volume_db = linear_to_db(maxf(float(s["cur"]), 1e-5))
	if float(_rise_cut["t0"]) >= 0.0:      # JS exponentialRamp 300 -> 2600 over 6.4 s
		var u := clampf((real - float(_rise_cut["t0"])) / 6.4, 0.0, 1.0)
		var i := AudioServer.get_bus_index(&"AscRise")
		(AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter).cutoff_hz = 300.0 * pow(2600.0 / 300.0, u)


func _clip_bus(w: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = w
	p.bus = B_LP
	add_child(p)
	p.play()
	_players.append(p)
	p.finished.connect(func() -> void:
		_players.erase(p)
		p.queue_free())


func _tone(key: String, d: float, f0: float, f1: float, o: Dictionary) -> void:
	var e: Dictionary = o.duplicate()
	var dr: float = e.get("dur", 0.5)
	CineParts.play(CineParts.sound("asc." + key, [["t", d, dr, f0, f1, e]]))


func _noise(key: String, d: float, dr: float, o: Dictionary) -> void:
	CineParts.play(CineParts.sound("asc." + key, [["n", d, dr, o]]))


# ---- subtitles + voices (the shared box) ----
func _say(L: Dictionary) -> void:
	_line = {"who": L["who"], "text": L["text"], "rate": L["rate"], "t0": t, "shown": 0, "voiced": 0}
	var text: String = L["text"]
	_E(t + text.length() / float(L["rate"]) + float(L["hold"]), func() -> void:
		if _line != null and _line["text"] == text:
			_end_line())
	Game.ui.dialog.show_box(true)
	Game.ui.dialog.set_content("", "", "")


func _end_line() -> void:
	_line = null
	Game.ui.dialog.show_box(false)


func _tick_line() -> void:
	if _line == null:
		return
	var text: String = _line["text"]
	var who: String = _line["who"]
	var n := mini(text.length(), floori((t - float(_line["t0"])) * float(_line["rate"])))
	var V: Dictionary = VOICES[who]
	for i in range(int(_line["voiced"]), n):
		var ch := text[i].to_lower()
		var prev := text[i - 1].to_lower() if i > 0 else " "
		if "aeiou".contains(ch) and not "aeiou".contains(prev):
			var robot: bool = V.get("robot", false)
			PhoneVoice.own_syllable(V["pitch"], 0.8 if robot else (0.92 if who == "PROG" else 1.08), 0.3 if robot else 0.55, 0.1, 0.22, 1.04, 0.76, 0.8, ch, i, PhoneVoice.last_syllable(text, i), robot)
	_line["voiced"] = n
	if n != int(_line["shown"]):
		_line["shown"] = n
		Game.ui.dialog.set_content(who, text.substr(0, n), "")


# ---- textures ----
static func _noise_img(w: int, h: int, base: Color, n: int, f: Callable) -> Image:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(base)
	for i in n:
		f.call(im)
	return im


static func _tarmac_tex() -> ImageTexture:
	var im := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	im.fill(Color("#34363a"))
	for i in 2600:
		var v := (40.0 + randf() * 40.0) / 255.0
		var r := Rect2i(randi() % 256, randi() % 256, 1 + randi() % 3, 1 + randi() % 3)
		im.fill_rect(r, Color(v * 0.55 + 0.2 * 0.45, v * 0.55 + 0.21 * 0.45, (v + 4.0 / 255.0) * 0.55 + 0.23 * 0.45))
	im.fill_rect(Rect2i(0, 127, 256, 2), Color("#242528"))
	im.fill_rect(Rect2i(127, 0, 2, 256), Color("#242528"))
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)


static func _container_tex() -> ImageTexture:
	var im := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	im.fill(Color("#d8d8d8"))
	var x := 4
	while x < 128:
		im.fill_rect(Rect2i(x, 8, 3, 112), Color(0.72 * 0.85, 0.72 * 0.85, 0.72 * 0.85))
		im.fill_rect(Rect2i(x + 3, 8, 2, 112), Color(0.9, 0.9, 0.9))
		x += 8
	im.fill_rect(Rect2i(0, 0, 128, 8), Color(0.47, 0.47, 0.47))
	im.fill_rect(Rect2i(0, 120, 128, 8), Color(0.47, 0.47, 0.47))
	for i in 300:
		var a := randf() * 0.2
		var c := Color(0.85, 0.85, 0.85).lerp(Color(90.0 / 255.0, 50.0 / 255.0, 20.0 / 255.0), a)
		im.fill_rect(Rect2i(randi() % 128, randi() % 128, 2 + randi() % 6, 1 + randi() % 3), c)
	im.generate_mipmaps()
	return ImageTexture.create_from_image(im)


## the sign's text, drawn once
class SignCard:
	extends Control
	var mono: Array = []

	func _f(names: Array, weight: int) -> SystemFont:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(names)
		f.font_weight = weight
		mono.append(f)
		return f

	func _fit(txt: String, x: float, y: float, px: int, max_w: float, f: Font, c: Color) -> void:
		while f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w and px > 12:
			px -= 2
		draw_string(f, Vector2(x, y + px * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, px, c)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color("#10141a"))
		draw_rect(Rect2(10, 10, w - 20, h - 20), Color("#e8502a"), false, 8.0)
		_fit("FOINT", 50.0, 120.0, 150, 390.0, _f(["Impact", "Arial Black", "sans-serif"], 700), Color("#e8502a"))
		_fit("CARGO DEPOT 9", 470.0, 74.0, 64, 510.0, _f(["Arial Black", "sans-serif"], 700), Color("#ffd36b"))
		var ar := _f(["Arial", "sans-serif"], 400)
		_fit("TOMORROW BELONGS TO WHOEVER BUYS IT.", 470.0, 150.0, 34, 510.0, ar, Color("#c8c0a8"))
		_fit("TERMS AND CONDITIONS APPLY.", 470.0, 200.0, 34, 510.0, ar, Color("#c8c0a8"))


# ---- the set: Cargo Depot 9 ----
func _mat(color: int, o: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((color << 8) | 0xff)
	m.roughness = float(o.get("r", 0.8))
	m.metallic = float(o.get("m", 0.0))
	if o.has("e"):
		m.emission_enabled = true
		m.emission = Color.hex((int(o["e"]) << 8) | 0xff)
		m.emission_energy_multiplier = float(o.get("ei", 1.0))
	return m


func _mm(par: Node3D, mesh: Mesh, m: Material, n: int, colors: bool = false, shadow: bool = true) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	par.add_child(mi)
	return mm


func _build_set() -> Dictionary:
	var g := Node3D.new()
	g.name = "depot"
	_root.add_child(g)
	var pl := PlaneMesh.new()
	pl.size = Vector2(190, 190)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = _tarmac_tex()
	fm.roughness = 0.9
	fm.uv1_scale = Vector3(18, 18, 1)
	fm.texture_repeat = true
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	CineParts.mesh(g, pl, fm, 0.0, FY, 0.0)
	# containers: a flat wall behind the heroes and an arc in front, two or three high
	var cols: Array[int] = [0xb4412c, 0x2f5a86, 0x3d7a4a, 0xc8922a, 0x7a2f2f, 0x4a5a66]
	var list := []
	for i in range(-5, 6):
		for k in 3:
			list.append([i * 6.1, k, BACK_Z - 1.3, 0.0])
	var a := -1.82
	while a <= 1.83:
		var h := 1 + int(randf() * 2.4)
		for k in h:
			list.append([sin(a) * (WALL_R + 1.3), k, cos(a) * (WALL_R + 1.3), a])
		a += 6.1 / WALL_R
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = _container_tex()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 0.8
	cm.metallic = 0.2
	cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var cmm := _mm(g, MenuScene._uv_box(Vector3(6.0, 2.6, 2.5)), cm, list.size(), true)
	for i in list.size():
		var e: Array = list[i]
		cmm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, e[3]), Vector3(e[0], FY + 1.3 + int(e[1]) * 2.6, e[2])))
		cmm.set_instance_color(i, Color.hex((cols[(i * 7 + int(e[1]) * 3) % cols.size()] << 8) | 0xff))
	# the sign
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 284)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_root.add_child(vp)
	var card := SignCard.new()
	card.size = Vector2(1024, 284)
	vp.add_child(card)
	var sq := QuadMesh.new()
	sq.size = Vector2(13.0, 3.6)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = vp.get_texture()
	CineParts.mesh(g, sq, sm, 0.0, FY + 6.1, BACK_Z - 1.3 + 1.28)
	# yard dressing: barrels and pallets against the wall, lamps on poles
	var bc := CylinderMesh.new()
	bc.top_radius = 0.34
	bc.bottom_radius = 0.34
	bc.height = 0.95
	bc.radial_segments = 10
	var barrels := _mm(g, bc, _mat(0x7a2a1c, {"r": 0.6, "m": 0.3}), 14)
	for i in 14:
		barrels.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3((i % 7 - 3) * 1.05 + (-5.5 if i < 7 else 5.5), FY + 0.48, BACK_Z + 0.55 + (i % 3) * 0.04 + (0.3 if i >= 7 else 0.0))))
	var cb := BoxMesh.new()
	cb.size = Vector3(1.3, 1.1, 1.3)
	var crates := _mm(g, cb, _mat(0x8a6a3c, {"r": 0.9}), 6)
	var ci := 0
	for e: Array in [[-9.5, 0.0], [-9.5, 1.2], [10.0, 0.0], [11.4, 0.0], [-11.4, 0.6], [10.7, 1.1]]:
		crates.set_instance_transform(ci, Transform3D(Basis.IDENTITY, Vector3(e[0], FY + 0.55 + (float(e[1]) if ci % 2 == 1 else 0.0), BACK_Z + 1.2)))
		ci += 1
	var lamps: Array[MeshInstance3D] = []
	for e: Array in [[-13.0, BACK_Z + 0.4], [13.0, BACK_Z + 0.4], [-24.0, 14.0], [24.0, 14.0], [-12.0, 22.0], [12.0, 22.0]]:
		CineParts.cyl(g, 0.1, 0.14, 9.0, e[0], FY + 4.5, e[1], _mat(0x22252a), 6)
		CineParts.box(g, 1.5, 0.22, 0.7, e[0], FY + 9.05, e[1], CineParts.basic(0xffd9a0))
		var s := CineParts.glow(g, 0xffb060, 7.0, true, 0.9)
		s.position = Vector3(e[0], FY + 8.8, e[1])
		lamps.append(s)
	var beacons: Array[MeshInstance3D] = []
	for x: float in [-17.0, 17.0]:
		var s := CineParts.glow(g, 0xff2a1a, 3.2, true, 0.0)
		s.position = Vector3(x, FY + 8.2, BACK_Z - 0.1)
		beacons.append(s)
	for x: float in [-13.0, 13.0]:
		CineParts.light(g, 0xffa860, 60.0, 34.0, x, FY + 8.6, BACK_Z + 2.0, 1.7)
	# far skyline: dark towers with lit windows, fogged
	var tb := BoxMesh.new()
	var tw := _mm(g, tb, CineParts.basic(0x0b1018), 46, false, false)
	var wq := QuadMesh.new()
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	wm.disable_fog = true
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(Color.hex(0xffb860ff), 0.8)
	var wn := _mm(g, wq, wm, 260, false, false)
	var wi := 0
	for i in 46:
		var an := (float(i) / 46.0) * TAU + rr(-0.05, 0.05)
		var d := rr(78.0, 112.0)
		var w := rr(7.0, 18.0)
		var h := rr(14.0, 52.0)
		var x := sin(an) * d
		var z := cos(an) * d
		tw.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(w, h, w)), Vector3(x, FY + h / 2.0, z)))
		var k := 0
		while k < 5 and wi < 260:
			var s := rr(-w / 3.0, w / 3.0)
			var b := Basis(Vector3.UP, atan2(-x, -z)).scaled(Vector3(rr(0.8, 1.6), rr(0.8, 1.5), 1.0))
			wn.set_instance_transform(wi, Transform3D(b, Vector3(x - sin(an) * (w / 2.0 + 0.1) + s * cos(an), FY + rr(3.0, h - 2.0), z - cos(an) * (w / 2.0 + 0.1) - s * sin(an))))
			k += 1
			wi += 1
	return {"g": g, "lamps": lamps, "beacons": beacons}


# ---- the FOINT robots (the game's own Robot / RobotView; this file only places and poses them) ----
func _build_robots() -> void:
	const A0 := -1.82
	const A1 := 1.82
	bots = []
	_bot_of = {}
	var ri := 0
	for rad0: float in RINGS:
		var n := roundi(rad0 * (A1 - A0) / 2.9)
		for i in n:
			var a := lerpf(A0, A1, (i + 0.5 + (0.25 if ri % 2 == 1 else -0.1)) / n) + rr(-0.02, 0.02)
			var rad := rad0 + rr(-0.4, 0.4)
			var fz := cos(a) * rad
			if fz < BACK_Z + 1.6:
				continue
			var sx := sin(a) * (rad + 6.5)
			var sz := cos(a) * (rad + 6.5)
			var R := Robot.new(Game.world, _next_id, sx, sz, FY)
			_next_id += 1
			R.yaw = atan2(-sx, -sz)
			var v := RobotView.new(R)
			Game.enemy_views.npc_views.append(v)
			R.max = 40.0
			R.hp = 40.0
			R.state = &"pursue"
			R.state_t = 0.0
			R.atk = &"shot"
			R.a_u = 0.9
			R.aim = 0.0
			var b := {"R": R, "v": v, "a": a, "rad": rad, "ring": ri, "delay": rr(0.0, 0.9) + ri * 0.35, "push": Vector3.ZERO, "vx": 0.0, "vz": 0.0, "vy": 0.0, "hop": 0.0, "air": false, "fire_t": rr(0.0, 1.0), "stag": 0.0, "last": Vector3(sx, 0.0, sz)}
			_bot_of[R] = b
			bots.append(b)
			kcombat.targets.append(R)
		ri += 1


## the crowd for this frame: marching in, then holding the ring aimed at them and creeping closer, staggering when Tommy's power hits, firing in the barrage, dying to the beam
func _update_robots(dt: float) -> void:
	var aim_t: float = T["aim"]
	var rise: float = T["rise"]
	var creep := Cutscene.ease_((t - aim_t) / (rise - aim_t)) * 1.9
	var tremble := _win(t, rise + 1.2, T["flash"], 0.6, 0.1)
	var now := Time.get_ticks_msec() / 1000.0
	for b: Dictionary in bots:
		var R: Robot = b["R"]
		var v: RobotView = b["v"]
		R.flash = maxf(0.0, R.flash - dt * 6.0)
		if R.dead:
			R.dead_t += dt
			_fling_step(b, dt)
			v.update(dt, now, Game.fx)
			continue
		var march := clampf((t - 0.2 - float(b["delay"]) * 0.4) / (aim_t - float(b["delay"]) * 0.5), 0.0, 1.0)
		var rad := lerpf(float(b["rad"]) + 6.5, b["rad"], Cutscene.ease_(march)) - creep * (1.0 - int(b["ring"]) * 0.12)
		var ax := sin(float(b["a"])) * rad
		var az := cos(float(b["a"])) * rad
		var push: Vector3 = (b["push"] as Vector3) * exp(-2.2 * dt)
		b["push"] = push
		var nx := ax + push.x
		var nz := az + push.z
		var moved := U.hyp(nx - R.x, nz - R.z) / maxf(dt, 1e-3)
		R.x = nx
		R.z = nz
		R.y = FY
		R.yaw = atan2(-R.x, -R.z)
		R.lvz = minf(2.6, moved) * (1.0 if t < aim_t + 1.0 else 0.6)
		R.lvx = 0.0
		if float(b["stag"]) > 0.0:
			b["stag"] -= dt
			R.state = &"stagger"
			R.state_t += dt
			if float(b["stag"]) <= 0.0:
				R.state = &"windup"
				R.state_t = 0.0
		elif t < aim_t + float(b["delay"]):
			R.state = &"pursue"
			R.state_t += dt
		elif R.state == &"pursue" or R.state == &"attack":
			R.state = &"windup"
			R.state_t = 0.0
			R.a_u = 0.0
		else:
			R.state_t += dt
			if R.state == &"windup":
				R.a_u = minf(1.0, R.a_u + dt * 1.4)
			if R.state == &"attack":
				R.a_u += dt * 7.0
				if R.a_u >= 1.0:
					R.state = &"windup"
					R.a_u = 1.0
		if tremble > 0.3 and randf() < dt * 0.9 * tremble and float(b["stag"]) <= 0.0 and not R.dead:
			b["stag"] = 0.45
			R.state_t = 0.0
			R.hit_x = sin(float(b["a"]))
			R.hit_z = cos(float(b["a"]))
		if float(b["fire_t"]) > 0.0 and t > float(T["barrage"]):
			b["fire_t"] -= dt
		v.update(dt, now, Game.fx)


func _fling_step(b: Dictionary, dt: float) -> void:
	var R: Robot = b["R"]
	if b["air"]:
		b["vy"] -= 17.0 * dt
		R.x += float(b["vx"]) * dt
		R.z += float(b["vz"]) * dt
		b["hop"] += float(b["vy"]) * dt
		if float(b["hop"]) <= 0.0:
			b["hop"] = 0.0
			if float(b["vy"]) < -3.0:
				b["vy"] *= -0.28
				b["vx"] *= 0.6
				b["vz"] *= 0.6
			else:
				b["air"] = false
				b["vy"] = 0.0
	else:
		var d := exp(-5.0 * dt)
		R.x += float(b["vx"]) * dt
		R.z += float(b["vz"]) * dt
		b["vx"] *= d
		b["vz"] *= d
	R.y = FY + float(b["hop"])
	b["last"] = Vector3(R.x, R.y, R.z)


func _kill_bot(b: Dictionary, from: Vector3, power: float = 1.0) -> void:
	var R: Robot = b["R"]
	if R.dead:
		return
	R.dead = true
	R.state = &"dead"
	R.dead_t = 0.0
	R.hp = 0.0
	var dx := R.x - from.x
	var dz := R.z - from.z
	var d := U.hyp(dx, dz)
	if d == 0.0:
		d = 1.0
	R.hit_x = dx / d
	R.hit_z = dz / d
	var sp := rr(3.0, 8.0) * power
	b["vx"] = R.hit_x * sp
	b["vz"] = R.hit_z * sp
	b["vy"] = rr(2.5, 7.0) * power
	b["air"] = true
	b["hop"] = 0.05
	var a := Vector3(R.x, R.y + 1.1, R.z)
	if randf() < 0.3:
		Game.fx.explosion(a, rr(0.9, 1.4))
	else:
		Game.fx.sparks(a, 14, 6.0, null, 0xffb050)
	for i in 3:
		vfx["dust"].emit(R.x + rr(-0.3, 0.3), R.y + 1.0, R.z + rr(-0.3, 0.3), rr(-0.6, 0.6), rr(1.0, 2.4), rr(-0.6, 0.6), rr(1.2, 2.2), 0.4, 1.5, 0.8, 0.0, Color(0.14, 0.14, 0.16, 0.32))


## the stand-in for the game's combat object that the Kamehameha reads and damages: rays against the robots, the yard's wall, a beam that bores through whoever dies
class KCombat:
	var o: TommyAscension
	var targets: Array = []
	var _hit := Combat.RayHit.new()

	func damage(R: Variant, dmg: float, from: Variant, _kb: float = 0.0, _pt: Variant = null) -> void:
		if R.dead:
			return
		R.hp -= dmg
		R.flash = 1.0
		if R.hp <= 0.0:
			o._kill_bot(o._bot_of[R], Vector3(from.x, 0.0, from.z), 1.0)

	static func _ray_cyl(ox: float, oy: float, oz: float, dx: float, dy: float, dz: float, x: float, z: float, r: float, y0: float, y1: float) -> float:
		var a := dx * dx + dz * dz
		if a < 1e-9:
			return -1.0
		var px := ox - x
		var pz := oz - z
		var bq := 2.0 * (px * dx + pz * dz)
		var c := px * px + pz * pz - r * r
		var disc := bq * bq - 4.0 * a * c
		if disc < 0.0:
			return -1.0
		var s := sqrt(disc)
		for tt: float in [(-bq - s) / (2.0 * a), (-bq + s) / (2.0 * a)]:
			if tt < 0.0:
				continue
			var y := oy + dy * tt
			if y >= y0 - 0.2 and y <= y1 + 0.2:
				return tt
		return -1.0

	func cast_ray(ox: float, oy: float, oz: float, dx: float, dy: float, dz: float, range_: float) -> Combat.RayHit:
		var best := range_
		var target: Target = null
		var hit_world := false
		for R: Target in targets:
			if R.dead:
				continue
			var tt := _ray_cyl(ox, oy, oz, dx, dy, dz, R.x, R.z, 0.62, R.y, R.y + 2.05)
			if tt >= 0.0 and tt < best:
				best = tt
				target = R
		var a := dx * dx + dz * dz
		if a > 1e-9:
			var bq := 2.0 * (ox * dx + oz * dz)
			var c := ox * ox + oz * oz - (WALL_R - 0.4) ** 2
			var disc := bq * bq - 4.0 * a * c
			if disc >= 0.0:
				var tt := (-bq + sqrt(disc)) / (2.0 * a)
				if tt > 0.0 and tt < best:
					best = tt
					target = null
					hit_world = true
		if dz < -1e-4:
			var tt := (BACK_Z - 0.1 - oz) / dz
			if tt > 0.0 and tt < best:
				best = tt
				target = null
				hit_world = true
		_hit.target = target
		_hit.hit_world = hit_world
		_hit.d = best
		return _hit


var kcombat := KCombat.new()


## the dome at the end of the beam: every robot still standing goes up in a wave moving out from Tommy
func _ripple() -> void:
	var pp: Player = H["tommy"]["p"]
	var c := Vector3(pp.x, FY, pp.z)
	for b: Dictionary in bots:
		var R: Robot = b["R"]
		if R.dead:
			continue
		var d := U.hyp(R.x - c.x, R.z - c.z)
		_E(t + d / 28.0 * rr(0.8, 1.2), func() -> void:
			if not R.dead:
				_kill_bot(b, c, 1.1))


# ---- Prog and Tommy (fresh Animators; a puppet player object each) ----
static func _puppet(x: float, z: float) -> Player:
	var p := Player.new(null)
	p.world = Game.world
	p.x = x
	p.y = FY
	p.z = z
	p.yaw = 0.0
	p.grounded = true
	p.flip = -1.0
	p.mode = &"normal"
	return p


func _hero_an(id: String) -> Animator:
	var B := Builds.character_build(id)
	var a := Animator.new((load(B.file) as PackedScene).instantiate(), B)
	_root.add_child(a.actor)
	return a


func _build_heroes() -> void:
	var a_p := _hero_an("prog")
	var a_t := _hero_an("tommy")
	var prog := {"an": a_p, "p": _puppet(PROG_X, 0.0), "gest": 0.0, "duck": 0.0, "look": 0.0, "back": 0.0, "blown": -1.0}
	var tommy := {"an": a_t, "p": _puppet(TOMMY_X, 0.0), "bow": 0.0, "pw": 0.0}
	var idx := func(n: StringName) -> int: return Animator.KEYS.find(n)
	var ua_r: int = idx.call(&"upper_armR")
	var ua_l: int = idx.call(&"upper_armL")
	var fa_r: int = idx.call(&"forearmR")
	var fa_l: int = idx.call(&"forearmL")
	var head: int = idx.call(&"head")
	var chest: int = idx.call(&"chest")
	var spine1: int = idx.call(&"spine1")
	a_p.pose_hook = func(a: Animator) -> void:      # Prog: frantic hands and head turns while he talks, arms over his head under fire, shaken back
		var g: float = prog["gest"]
		var d: float = prog["duck"]
		var s1 := 0.5 + 0.5 * sin(t * 5.3)
		var s2 := 0.5 + 0.5 * sin(t * 4.1 + 1.7)
		a.pose[ua_r] += Vector3(-0.9 * g * s1, 0.0, -0.45 * g * s2)
		a.pose[fa_r] += Vector3(-1.1 * g * s1, 0.0, 0.0)
		a.pose[ua_l] += Vector3(-0.8 * g * s2, 0.0, 0.45 * g * s1)
		a.pose[fa_l] += Vector3(-1.0 * g * s2, 0.0, 0.0)
		a.pose[head] += Vector3(0.0, float(prog["look"]) + 0.5 * g * sin(t * 1.3), 0.0)
		a.pose[chest] += Vector3(0.0, 0.1 * g * sin(t * 1.3 + 0.4), 0.0)
		a.pose[ua_l] += Vector3(-2.3 * d, 0.0, 0.0)
		a.pose[ua_r] += Vector3(-2.3 * d, 0.0, 0.0)
		a.pose[fa_l] += Vector3(-1.6 * d, 0.0, 0.0)
		a.pose[fa_r] += Vector3(-1.6 * d, 0.0, 0.0)
		a.pose[spine1] += Vector3(0.45 * d - 0.2 * float(prog["back"]), 0.0, 0.0)
		a.pose[head] += Vector3(0.3 * d - 0.25 * float(prog["back"]), 0.0, 0.0)
	a_t.pose_hook = func(a: Animator) -> void:      # Tommy: head bowed and still; then a held-in tremble, fists out, head up
		var b: float = tommy["bow"]
		var k: float = tommy["pw"]
		a.pose[head] += Vector3(0.55 * b - 0.35 * k, 0.0, 0.0)
		a.pose[spine1] += Vector3(0.14 * b, 0.0, 0.0)
		a.pose[chest] += Vector3(0.06 * b - 0.12 * k, 0.0, 0.0)
		a.pose[ua_l] += Vector3(0.0, 0.0, 0.55 * k)
		a.pose[ua_r] += Vector3(0.0, 0.0, -0.55 * k)
		a.pose[fa_l] += Vector3(-0.8 * k, 0.0, 0.0)
		a.pose[fa_r] += Vector3(-0.8 * k, 0.0, 0.0)
		var j := _xf * (0.03 + 0.05 * _xf)
		a.pose[chest] += Vector3(rr(-j, j), 0.0, rr(-j, j))
		a.pose[head] += Vector3(0.0, rr(-j, j) * 2.0, 0.0)
		a.pose[ua_l] += Vector3(0.0, 0.0, rr(-j, j) * 3.0)
		a.pose[ua_r] += Vector3(0.0, 0.0, rr(-j, j) * 3.0)
	H = {"prog": prog, "tommy": tommy, "hat": null, "face": null, "hair": null}


func _bone(an: Animator, key: StringName) -> Vector3:
	if an.by_key.has(key):
		return an.bone_world_pos(an.by_key[key].bone)
	return an.actor.position + Vector3(0.0, 1.0, 0.0)


# ---- Tommy's face (repainted on his own texture), hat and Super Saiyan 3 hair ----
static func _mats_named(an: Animator, pre: String) -> Array:
	var out := []
	var walk: Array[Node] = [an.model]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var nm := mi.mesh.surface_get_material(s).resource_name if mi.mesh.surface_get_material(s) != null else ""
				if nm.begins_with(pre):
					out.append([mi, s])
	return out


func _face_kit(an: Animator) -> Dictionary:
	var kit := {"mats": [], "orig": null, "tex": null}
	var ms := _mats_named(an, "tm_body")
	for e: Array in ms:
		var mi: MeshInstance3D = e[0]
		var m: Material = mi.get_surface_override_material(e[1])
		if m == null:
			m = mi.mesh.surface_get_material(e[1])
		if m not in kit["mats"]:
			kit["mats"].append(m)
	if (kit["mats"] as Array).is_empty():
		push_warning("tommy-ascension: no tm_body material, face stays as is")
		return kit
	var m0: Material = kit["mats"][0]
	var orig: Texture2D = (m0 as BaseMaterial3D).albedo_texture if m0 is BaseMaterial3D else (m0 as ShaderMaterial).get_shader_parameter(&"albedo_tex")
	if orig == null:
		return kit
	var im := orig.get_image()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	if im.get_width() != 512:
		im.resize(512, 512, Image.INTERPOLATE_BILINEAR)
	kit["orig"] = im
	kit["tex"] = ImageTexture.create_from_image(im)
	return kit


static func _px4(im: Image, x: float, y: float, w: float, h: float, c: Color) -> void:
	im.fill_rect(Rect2i(roundi(x / 4.0) * 4, roundi(y / 4.0) * 4, maxi(4, roundi(w / 4.0) * 4), maxi(4, roundi(h / 4.0) * 4)), c)


## a narrowed turquoise eye under a hard slanted lid (the left one; flip = mirrored to the right)
static func _eye(im: Image, flip: bool) -> void:
	var ink := Color("#1a1618")
	var R := func(x: float, y: float, w: float, h: float, c: Color) -> void: _px4(im, 512.0 - x - w if flip else x, y, w, h, c)
	var cx := 166.0
	var el := func(hx: float, hy: float, dy: float) -> float: return hx * sqrt(maxf(0.0, 1.0 - (dy / hy) ** 2))
	var dy := -22
	while dy <= 22:
		var hw: float = el.call(40.0, 24.0, float(dy))
		R.call(cx - hw, 196.0 + dy, 2.0 * hw, 4.0, ink)
		dy += 4
	dy = -18
	while dy <= 18:
		var hw: float = el.call(35.0, 20.0, float(dy))
		R.call(cx - hw, 196.0 + dy, 2.0 * hw, 4.0, Color("#f6f6f0"))
		dy += 4
	dy = -18
	while dy <= 18:
		var hw: float = el.call(18.0, 20.0, float(dy))
		R.call(cx - hw, 196.0 + dy, 2.0 * hw, 4.0, Color("#1a8fb8") if dy > 6 else Color("#2ad4f0"))
		dy += 4
	R.call(cx - 6.0, 186.0, 12.0, 24.0, Color("#05141c"))
	R.call(cx + 4.0, 184.0, 8.0, 8.0, Color.WHITE)
	var x := 120.0
	while x <= 212.0:
		R.call(x, 160.0 + (x - 120.0) * 0.3, 4.0, 12.0, ink)
		x += 4.0


func _face_set(kit: Dictionary, st: String) -> void:
	if kit["orig"] == null:
		return
	var im: Image = (kit["orig"] as Image).duplicate()
	var cream := Color("#ede6d6")
	var ink := Color("#1a1618")
	if st == "solemn":
		_px4(im, 180.0, 336.0, 150.0, 60.0, cream)
		_px4(im, 212.0, 372.0, 88.0, 8.0, ink)
		_px4(im, 204.0, 380.0, 8.0, 8.0, ink)
		_px4(im, 300.0, 380.0, 8.0, 8.0, ink)
	if st == "ssj3":
		_px4(im, 112.0, 128.0, 112.0, 108.0, cream)
		_px4(im, 288.0, 128.0, 112.0, 108.0, cream)
		_px4(im, 112.0, 144.0, 112.0, 24.0, Color("#d8cdb6"))
		_px4(im, 288.0, 144.0, 112.0, 24.0, Color("#d8cdb6"))
		_eye(im, false)
		_eye(im, true)
		_px4(im, 180.0, 336.0, 150.0, 60.0, cream)
		_px4(im, 216.0, 372.0, 80.0, 8.0, ink)
		_px4(im, 208.0, 380.0, 8.0, 8.0, ink)
		_px4(im, 296.0, 380.0, 8.0, 8.0, ink)
	(kit["tex"] as ImageTexture).update(im)
	for m: Material in kit["mats"]:
		if m is BaseMaterial3D:
			(m as BaseMaterial3D).albedo_texture = kit["tex"]
		else:
			(m as ShaderMaterial).set_shader_parameter(&"albedo_tex", kit["tex"])


## a tapered, bent, gold spike growing from `root` along d0 (head space), sagging under its own weight
static func _lock_geo(d0: Vector3, ln: float, wd: float, sag: float, side: float, segs: int = 9) -> ArrayMesh:
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var p := Vector3.ZERO
	var d := d0.normalized()
	var sv := d.cross(Vector3.UP)
	if sv.length_squared() < 1e-4:
		sv = Vector3.RIGHT
	sv = sv.normalized()
	for i in segs + 1:
		pts.append(p)
		rad.append(wd * pow(1.0 - float(i) / segs, 0.85))
		p += d * (ln / segs)
		d.y -= sag / segs
		d = (d + sv * (side / segs)).normalized()
	var c0 := Color.hex(0xb87800ff).srgb_to_linear()
	var c1 := Color.hex(0xfff0a0ff).srgb_to_linear()
	var ring := []
	var cols := []
	for i in segs + 1:
		var tg := (pts[mini(i + 1, segs)] - pts[maxi(i - 1, 0)]).normalized()
		var u := tg.cross(Vector3.RIGHT if absf(tg.z) > 0.9 else Vector3.BACK).normalized()
		var v := tg.cross(u)
		var rr_ := []
		for k in 3:
			var a := k * TAU / 3.0
			rr_.append(pts[i] + (u * cos(a) + v * sin(a)) * rad[i])
		ring.append(rr_)
		cols.append(c0.lerp(c1, pow(float(i) / segs, 1.3)).linear_to_srgb())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := func(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
		var n := (c - a).cross(b - a).normalized()
		st.set_normal(n)
		st.set_color(ca)
		st.add_vertex(a)
		st.set_normal(n)
		st.set_color(cb)
		st.add_vertex(b)
		st.set_normal(n)
		st.set_color(cc)
		st.add_vertex(c)
	for i in segs:
		for k in 3:
			var a: Vector3 = ring[i][k]
			var b: Vector3 = ring[i][(k + 1) % 3]
			var c: Vector3 = ring[i + 1][k]
			var d2: Vector3 = ring[i + 1][(k + 1) % 3]
			tri.call(a, c, b, cols[i], cols[i + 1], cols[i])
			tri.call(b, c, d2, cols[i], cols[i + 1], cols[i + 1])
	return st.commit()


func _build_hair(an: Animator) -> Variant:
	if not an.by_key.has(&"head"):
		return null
	var ba := BoneAttachment3D.new()
	an.skel.add_child(ba)
	ba.bone_idx = an.by_key[&"head"].bone
	var g := Node3D.new()
	g.name = "ssj3-hair"
	g.visible = false
	ba.add_child(g)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.hex((HAIR_GOLD << 8) | 0xff)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.emission_enabled = true
	m.emission = Color.hex(0xff9a00ff)
	m.emission_energy_multiplier = 0.55
	m.roughness = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var locks: Array[Dictionary] = []
	var C := Vector3(0.0, 1.52 - HEAD_Y, 0.0)
	var AX := Vector3(0.34, 0.45, 0.32)
	var lock := func(th: float, ph: float, d0: Vector3, ln: float, w: float, sag: float, side: float) -> void:
		var n := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
		var rt := C + Vector3(n.x * AX.x, n.y * AX.y, n.z * AX.z) + n * -0.03
		var mesh := CineParts.mesh(g, _lock_geo(d0, ln, w, sag, side), m, rt.x, rt.y, rt.z)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.custom_aabb = AABB(Vector3.ONE * -5.0, Vector3.ONE * 10.0)
		locks.append({"mesh": mesh, "ph": rr(0.0, 6.28), "amp": rr(0.6, 1.2), "len": ln, "k": rr(0.0, 0.35)})
	for e: Array in [[0.2, 3], [0.7, 6], [1.1, 8], [1.45, 7]]:
		var th: float = e[0]
		var cnt: int = e[1]
		for i in cnt:
			var ph := (i + 0.5 * (1.0 if th > 0.5 and th < 1.2 else 0.0)) / cnt * TAU + th * 0.7
			var back := (1.0 - cos(ph)) / 2.0
			var front := 1.0 - back
			if front > 0.8 and th > 0.5:      # the bangs below
				continue
			var n := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
			var d0 := n * 0.4 + Vector3(0.0, 0.12, -0.8 * (0.5 + back))
			lock.call(th, ph, d0, (0.6 + 1.7 * back) * (0.8 + 0.3 * th), 0.085 + 0.025 * th, 0.9 + 2.6 * back, rr(-0.5, 0.5))
	for ph: float in [-0.5, 0.0, 0.5]:      # the bangs: short spikes over the brow ridge, clear of the eyes
		lock.call(0.92, ph, Vector3(sin(ph) * 0.8, 0.1, 0.9), 0.42, 0.055, 0.9, -ph * 0.4)
	for s: float in [-1.0, 1.0]:      # the long locks framing his face and the sides
		lock.call(1.2, s * 1.05, Vector3(s * 0.7, 0.0, 0.55), 1.5, 0.07, 3.4, s * -0.25)
		lock.call(1.45, s * 1.5, Vector3(s * 0.9, -0.1, -0.1), 2.0, 0.09, 3.2, 0.0)
	for i in 9:      # the great fall down his back
		lock.call(1.55, PI + (i - 4) * 0.3, Vector3((i - 4) * 0.12, -0.1, -0.9), 3.0 + rr(-0.3, 0.4), 0.13, 3.8, (i - 4) * 0.1)
	return {"g": g, "locks": locks, "m": m}


func _build_hat(an: Animator) -> Dictionary:      # his propeller beanie, popped off by the hair
	var hat := Node3D.new()
	var cap := SphereMesh.new()
	cap.radius = 0.27
	cap.height = 0.27
	cap.is_hemisphere = true
	cap.radial_segments = 14
	cap.rings = 8
	var c_m := CineParts.mesh(hat, cap, _mat(0x2f4fd0, {"r": 0.6}), 0.0, 0.135, 0.0)
	c_m.position.y = 0.135
	CineParts.cyl(hat, 0.275, 0.275, 0.07, 0.0, 0.0, 0.0, _mat(0xd02a2a, {"r": 0.6}), 14)
	CineParts.box(hat, 0.4, 0.015, 0.05, 0.0, 0.3, 0.0, _mat(0xe8c020))
	hat.scale = Vector3.ONE * 0.68
	hat.visible = false
	_root.add_child(hat)
	var hide_ := []
	for e: Array in _mats_named(an, "tm_hat") + _mats_named(an, "tm_prop"):
		hide_.append(e)
	var pr: Node = an.model.find_child("propeller", true, false)
	if pr != null:
		hide_.append([pr, -1])
	return {"hat": hat, "hide": hide_, "v": Vector3.ZERO, "w": Vector3.ZERO, "on": false}


func _pop_hat() -> void:
	var h: Dictionary = H["hat"]
	var gone := StandardMaterial3D.new()      # (in Godot his hat is a surface of the one skinned mesh: that surface goes, not the mesh)
	gone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gone.albedo_color = Color(0, 0, 0, 0)
	gone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gone.no_depth_test = false
	for e: Array in h["hide"]:
		var o: Node = e[0]
		if int(e[1]) < 0 or (o as MeshInstance3D).mesh.get_surface_count() == 1:
			(o as Node3D).visible = false
		else:
			(o as MeshInstance3D).set_surface_override_material(e[1], gone)
	var a := _bone(H["tommy"]["an"], &"head")
	a.y += 0.45 * 0.68
	(h["hat"] as Node3D).position = a
	(h["hat"] as Node3D).visible = true
	h["on"] = true
	h["v"] = Vector3(rr(-1.5, 1.5), 7.5, rr(1.0, 3.0))
	h["w"] = Vector3(rr(-9.0, 9.0), rr(-4.0, 4.0), rr(-9.0, 9.0))
	Game.sfx.play("whoosh")
	vfx["add"].emit(a.x, a.y, a.z, 0.0, 0.0, 0.0, 0.35, 0.5, 2.4, 1.0, 0.0, Color(1.0, 0.9, 0.5, 0.9))


# ---- the power: aura shell, flame sheets, lightning, ground cracks, debris, shock dome ----
static func _shell_mat(color: int, hot: int, order: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://cutscenes/asc_shell.gdshader")
	var a := Color.hex((color << 8) | 0xff).srgb_to_linear()
	var b := Color.hex((hot << 8) | 0xff).srgb_to_linear()
	m.set_shader_parameter(&"uColor", Vector3(a.r, a.g, a.b))
	m.set_shader_parameter(&"uHot", Vector3(b.r, b.g, b.b))
	m.render_priority = order
	return m


## the flame sheet (JS a bezier filled with a gradient)
static func _tongue_tex() -> ImageTexture:
	const W := 64
	const HT := 128
	var im := Image.create(W, HT, false, Image.FORMAT_RGBA8)
	var bez := func(a: Vector2, b: Vector2, c: Vector2, d: Vector2, s: float) -> Vector2:
		var i := 1.0 - s
		return a * i * i * i + b * 3.0 * i * i * s + c * 3.0 * i * s * s + d * s * s * s
	var poly := PackedVector2Array()
	var h := 1.0
	for seg: Array in [[Vector2(10, h), Vector2(0, h * 0.55), Vector2(30, h * 0.3), Vector2(46, h * 0.12)], [Vector2(46, h * 0.12), Vector2(56, h * 0.28), Vector2(70, h * 0.22), Vector2(76, 0)], [Vector2(76, 0), Vector2(90, h * 0.22), Vector2(100, h * 0.3), Vector2(118, h)]]:
		for i in 12:
			var p: Vector2 = bez.call(seg[0], seg[1], seg[2], seg[3], i / 12.0)
			poly.append(Vector2(p.x / 128.0 * W, p.y * HT))
	for y in HT:
		var v := 1.0 - float(y) / HT      # (0 at the root)
		var col := Color(1.0, 214.0 / 255.0, 70.0 / 255.0, 0.95).lerp(Color(1.0, 170.0 / 255.0, 30.0 / 255.0, 0.55), minf(v / 0.55, 1.0)) if v < 0.55 else Color(1.0, 170.0 / 255.0, 30.0 / 255.0, 0.55).lerp(Color(1.0, 120.0 / 255.0, 0.0, 0.0), (v - 0.55) / 0.45)
		for x in W:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
				im.set_pixel(x, y, col)
	return ImageTexture.create_from_image(im)


## the ground's cracks, white on nothing
static func _crack_tex() -> ImageTexture:
	const S := 256
	var im := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var bolt: Callable
	bolt = func(x: float, y: float, a: float, ln: float, wd: float, depth: int, me: Callable) -> void:
		var nx := x + cos(a) * ln
		var ny := y + sin(a) * ln
		var steps := int(ln) + 1
		var w := maxi(1, int(wd))
		for i in steps:
			var u := float(i) / steps
			im.fill_rect(Rect2i(int(lerpf(x, nx, u)) - w / 2, int(lerpf(y, ny, u)) - w / 2, w, w), Color.WHITE)
		if depth > 0:
			me.call(nx, ny, a + rr(-0.5, 0.5), ln * rr(0.6, 0.85), wd * 0.8, depth - 1, me)
			if randf() < 0.6:
				me.call(nx, ny, a + rr(-1.2, 1.2), ln * rr(0.4, 0.7), wd * 0.6, depth - 1, me)
	for i in 11:      # (the JS's 512 canvas, at 256)
		bolt.call(128.0, 128.0, float(i) / 11.0 * TAU + rr(-0.2, 0.2), rr(15.0, 23.0), 3.5, 5, bolt)
	return ImageTexture.create_from_image(im)


func _build_power() -> Dictionary:
	var g := Node3D.new()
	g.name = "power"
	_root.add_child(g)
	var sph := SphereMesh.new()
	sph.radial_segments = 28
	sph.rings = 18
	var shell := MeshInstance3D.new()
	shell.mesh = sph
	shell.material_override = _shell_mat(0xffb020, 0xfff2b0, 8)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.visible = false
	g.add_child(shell)
	var tt := _tongue_tex()
	var tongues: Array[Dictionary] = []
	var qm := QuadMesh.new()
	for i in 16:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.disable_fog = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_texture = tt
		m.render_priority = 9
		var n := CineParts.mesh(g, qm, m)
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
		tongues.append({"m": n, "mat": m, "a": float(i) / 16.0 * TAU + rr(-0.2, 0.2), "r": rr(0.28, 0.62), "w": rr(0.45, 0.8), "h": rr(1.5, 2.5), "ph": rr(0.0, 6.28), "sp": rr(5.0, 9.0)})
	var ls := ImmediateMesh.new()
	var ln := MeshInstance3D.new()
	ln.mesh = ls
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	lm.disable_fog = true
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.albedo_color = Color(Color.hex(0xfff0a8ff), 0.95)
	lm.render_priority = 12
	ln.material_override = lm
	ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ln.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	ln.visible = false
	g.add_child(ln)
	var crack_t := _crack_tex()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE
	var cm := StandardMaterial3D.new()
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.disable_fog = true
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.albedo_texture = crack_t
	cm.albedo_color = Color(Color.hex(0xffb030ff), 0.0)
	cm.render_priority = 4
	var cracks := CineParts.mesh(g, pm, cm)
	cracks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_texture = crack_t
	dm.albedo_color = Color(Color.hex(0x050505ff), 0.0)
	dm.render_priority = 3
	var dark := CineParts.mesh(g, pm, dm)
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rocks := _mm(g, Kamehameha.dodeca(), _mat(0x8a8072, {"r": 0.95}), 44)
	var R_: Array[Dictionary] = []
	for i in 44:
		R_.append({"p": Vector3.ZERO, "v": Vector3.ZERO, "q": Quaternion.IDENTITY, "w": Vector3.ZERO, "s": 0.0, "st": 0.0, "y0": 0.0, "mode": 0})
		rocks.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	var ds := SphereMesh.new()
	ds.radial_segments = 32
	ds.rings = 20
	var dome := MeshInstance3D.new()
	dome.mesh = ds
	dome.material_override = _shell_mat(0xffd060, 0xffffff, 10)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dome.visible = false
	g.add_child(dome)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.disable_fog = true
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.cull_mode = BaseMaterial3D.CULL_DISABLED
	rm.albedo_color = Color(Color.hex(0xfff0b0ff), 0.0)
	rm.render_priority = 6
	var ring := CineParts.mesh(g, AlleyProps._ring_mesh(0.9, 1.0, 64), rm)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := CineParts.light(g, 0xffc030, 0.0, 22.0, TOMMY_X, FY + 1.2, 0.3, 1.6)
	var glow := CineParts.glow(g, 0xffc040, 4.0, true, 0.0)
	return {"g": g, "shell": shell, "tongues": tongues, "ls": ls, "ln": ln, "ls_t": 0.0, "lm": lm, "cracks": cracks, "cm": cm, "dark": dark, "dm": dm, "rocks": rocks, "R": R_, "dome": dome, "ring": ring, "rm": rm, "light": light, "glow": glow, "boom": -1.0}


func _update_power(dt: float) -> void:
	var W: Dictionary = vfx["pw"]
	var tm: Dictionary = H["tommy"]
	var p: Player = tm["p"]
	var cp := Game.camera.global_position
	var k := _aura
	var xf := _xf
	var cx := p.x
	var cz := p.z
	var cy := FY
	# the aura: shell + flame sheets + glow
	var shell: MeshInstance3D = W["shell"]
	shell.visible = k > 0.01
	shell.position = Vector3(cx, cy + 0.95, cz)
	shell.scale = Vector3(0.75 + 0.5 * k, 1.1 + 0.6 * k, 0.75 + 0.5 * k) * (1.0 + 0.04 * sin(real * 37.0))
	var sm := shell.material_override as ShaderMaterial
	sm.set_shader_parameter(&"uAlpha", k * (0.4 + 0.15 * randf()))
	sm.set_shader_parameter(&"uTime", real)
	var ang := atan2(cp.x - cx, cp.z - cz)
	var cdx := sin(ang)
	var cdz := cos(ang)
	for tg: Dictionary in W["tongues"]:
		var m: MeshInstance3D = tg["m"]
		m.visible = k > 0.02
		if not m.visible:
			continue
		var f := 0.75 + 0.25 * sin(real * float(tg["sp"]) + float(tg["ph"]))
		var a: float = float(tg["a"]) + real * 0.6
		m.position = Vector3(cx + cos(a) * float(tg["r"]), cy + float(tg["h"]) * 0.5 * f * (0.6 + 0.5 * k), cz + sin(a) * float(tg["r"]))
		m.rotation = Vector3(0.0, ang, 0.0)
		m.scale = Vector3(float(tg["w"]) * (0.7 + 0.5 * k), float(tg["h"]) * f * (0.55 + 0.7 * k), 1.0)
		var fr := cos(a) * cdx + sin(a) * cdz      # the sheets between him and the camera fade out so his face stays clear
		(tg["mat"] as StandardMaterial3D).albedo_color.a = k * 0.42 * (0.6 + 0.4 * sin(real * float(tg["sp"]) * 1.3 + float(tg["ph"]))) * (1.0 - 0.9 * Cutscene.ease_((fr - 0.1) / 0.7))
	var gl: MeshInstance3D = W["glow"]
	CineParts.glow_opacity(gl, k * 0.35)
	gl.scale = Vector3.ONE * (4.0 + 3.0 * k)
	gl.position = Vector3(cx - cdx * 0.7, cy + 1.0, cz - cdz * 0.7)
	var li: OmniLight3D = W["light"]
	li.light_energy = (k * (22.0 + 8.0 * sin(real * 31.0)) + _flash * 120.0) / PI
	li.position = Vector3(cx, cy + 1.4, cz + 0.6)
	if k > 0.05:      # flame particles rising off him, sparks
		var add: CinePuffs = vfx["add"]
		var dust: CinePuffs = vfx["dust"]
		vfx["acc_f"] += dt * 240.0 * k
		while float(vfx["acc_f"]) >= 1.0:
			vfx["acc_f"] -= 1.0
			var a := rr(0.0, 6.28)
			var r := rr(0.2, 0.75)
			add.emit(cx + cos(a) * r, cy + rr(0.0, 1.6), cz + sin(a) * r, rr(-0.3, 0.3), rr(2.2, 4.8), rr(-0.3, 0.3), rr(0.5, 1.0), rr(0.35, 0.6), 0.04, 1.2, 0.0, Color(1.0, rr(0.65, 0.85), rr(0.1, 0.25), 0.85))
		vfx["acc_s"] += dt * 60.0 * k
		while float(vfx["acc_s"]) >= 1.0:
			vfx["acc_s"] -= 1.0
			var a := rr(0.0, 6.28)
			add.emit(cx + cos(a) * 0.6, cy + rr(0.1, 1.6), cz + sin(a) * 0.6, cos(a) * rr(1.0, 3.0), rr(0.5, 3.5), sin(a) * rr(1.0, 3.0), rr(0.4, 1.0), 0.12, 0.02, 0.8, -2.0, Color(1.0, 0.95, 0.5, 1.0))
		vfx["acc_d"] += dt * 40.0 * k
		while float(vfx["acc_d"]) >= 1.0:
			vfx["acc_d"] -= 1.0
			var a := rr(0.0, 6.28)
			var sp := rr(3.0, 7.0)
			dust.emit(cx + cos(a) * 0.8, cy + 0.12, cz + sin(a) * 0.8, cos(a) * sp, rr(0.1, 0.5), sin(a) * sp, rr(0.7, 1.3), 0.5, 2.2, 2.4, 0.0, Color(0.36, 0.33, 0.3, 0.4))
	# lightning: regenerated ~25 times a second while the aura is up
	var ln: MeshInstance3D = W["ln"]
	ln.visible = k > 0.15
	if ln.visible:
		W["ls_t"] -= dt
		if float(W["ls_t"]) <= 0.0:
			W["ls_t"] = 0.04
			var ls: ImmediateMesh = W["ls"]
			ls.clear_surfaces()
			ls.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			for b in 12:
				var live := randf() < 0.35 + 0.5 * k
				if not live:
					continue
				var a0 := rr(0.0, 6.28)
				var ground := randf() < 0.35
				var lnn := rr(1.2, 2.4) if ground else rr(0.7, 1.6)
				var sy := cy + rr(0.1, 1.5)
				var q := Vector3(cx + cos(a0) * 0.45, sy, cz + sin(a0) * 0.45)
				var dx := cos(a0) * 0.8 + rr(-0.3, 0.3)
				var dy := rr(-0.3, 0.1) if ground else rr(-0.2, 0.9)
				var dz := sin(a0) * 0.8 + rr(-0.3, 0.3)
				var dv := Vector3(dx, dy, dz)
				var dl := dv.length()
				if dl == 0.0:
					dl = 1.0
				var prev_a := Vector3.ZERO
				var prev_b := Vector3.ZERO
				for s in 9:
					var u := float(s) / 8.0
					var w := 0.014 * (1.0 - u * 0.6)
					var tv := cp - q
					var sd := dv.cross(tv)
					var sl := sd.length()
					if sl == 0.0:
						sl = 1.0
					var pa := q + sd / sl * w
					var pb := q - sd / sl * w
					if s > 0:
						ls.surface_add_vertex(prev_a)
						ls.surface_add_vertex(prev_b)
						ls.surface_add_vertex(pa)
						ls.surface_add_vertex(prev_b)
						ls.surface_add_vertex(pb)
						ls.surface_add_vertex(pa)
					prev_a = pa
					prev_b = pb
					q += dv / dl * (lnn / 8.0) + Vector3(rr(-0.18, 0.18), rr(-0.12, 0.12), rr(-0.18, 0.18))
					if q.y < cy + 0.02:
						q.y = cy + 0.02
			ls.surface_end()
	# ground cracks growing outward and glowing, the rocks floating up; the shock dome at the flash
	var rise: float = T["rise"]
	var flash_t: float = T["flash"]
	var u := Cutscene.ease_((t - rise - 1.4) / 3.4)
	var cr: Node3D = W["cracks"]
	var dk: Node3D = W["dark"]
	cr.position = Vector3(cx, cy + 0.03, cz)
	dk.position = Vector3(cx, cy + 0.025, cz)
	cr.scale = Vector3.ONE * (2.0 + 11.0 * u)
	dk.scale = Vector3.ONE * (2.0 + 11.0 * u)
	(W["cm"] as StandardMaterial3D).albedo_color.a = u * (0.6 + 0.4 * sin(real * 9.0)) * (1.0 if t < flash_t else 0.9) * (1.0 if _aura > 0.15 else 0.4)
	(W["dm"] as StandardMaterial3D).albedo_color.a = u * 0.9
	var rocks: MultiMesh = W["rocks"]
	var Rs: Array = W["R"]
	for i in Rs.size():
		var q: Dictionary = Rs[i]
		var mode: int = q["mode"]
		if mode == 0 and xf > 0.25 and t < flash_t and randf() < dt * 14.0 * xf:
			var a := rr(0.0, 6.28)
			var d := rr(1.1, 5.0)
			mode = 1
			q["s"] = rr(0.05, 0.16)
			q["p"] = Vector3(cx + cos(a) * d, cy + float(q["s"]) * 0.4, cz + sin(a) * d)
			q["y0"] = cy + rr(0.5, 2.8)
			q["v"] = Vector3.ZERO
			q["w"] = Vector3(rr(-1.5, 1.5), rr(-1.5, 1.5), rr(-1.5, 1.5))
			q["q"] = Quaternion.IDENTITY
			q["st"] = 0.0
			var rp: Vector3 = q["p"]
			vfx["dust"].emit(rp.x, cy + 0.1, rp.z, 0.0, 0.5, 0.0, 0.9, 0.3, 1.0, 2.0, 0.0, Color(0.4, 0.37, 0.33, 0.5))
		var pos: Vector3 = q["p"]
		var v: Vector3 = q["v"]
		if mode == 1:
			pos.y += (float(q["y0"]) - pos.y) * (1.0 - exp(-1.6 * dt)) * 0.9 + dt * 0.1
			pos.x += rr(-0.4, 0.4) * dt
			pos.z += rr(-0.4, 0.4) * dt
			if t >= flash_t:
				mode = 2
				var a := Vector3(pos.x - cx, 0.0, pos.z - cz).normalized()
				v = Vector3(a.x * rr(6.0, 14.0), rr(3.0, 9.0), a.z * rr(6.0, 14.0))
		elif mode == 2:
			v.y -= 16.0 * dt
			pos += v * dt
			if pos.y < cy + float(q["s"]) * 0.5:
				pos.y = cy + float(q["s"]) * 0.5
				v.y *= -0.3
				v.x *= 0.6
				v.z *= 0.6
				q["w"] = (q["w"] as Vector3) * 0.5
				if absf(v.y) < 0.6:
					mode = 3
		q["mode"] = mode
		q["p"] = pos
		q["v"] = v
		if mode > 0:
			var ww: Vector3 = q["w"]
			q["q"] = ((q["q"] as Quaternion) * Animator.q_xyz(ww.x * dt, ww.y * dt, ww.z * dt)).normalized()
			rocks.set_instance_transform(i, Transform3D(Basis(q["q"] as Quaternion).scaled(Vector3.ONE * float(q["s"])), pos))
	# the blast at the flash: a bright dome and a ring racing out across the yard
	if float(W["boom"]) >= 0.0:
		var bu: float = (t - float(W["boom"])) / 1.1
		var dome: MeshInstance3D = W["dome"]
		var ring: MeshInstance3D = W["ring"]
		if bu >= 1.0:
			W["boom"] = -1.0
			dome.visible = false
			(W["rm"] as StandardMaterial3D).albedo_color.a = 0.0
		else:
			dome.visible = true
			dome.position = Vector3(cx, cy + 0.8, cz)
			dome.scale = Vector3.ONE * (1.0 + 15.0 * (1.0 - (1.0 - bu) ** 3))
			var dm := dome.material_override as ShaderMaterial
			dm.set_shader_parameter(&"uAlpha", (1.0 - bu) * 1.6)
			dm.set_shader_parameter(&"uTime", real)
			ring.position = Vector3(cx, cy + 0.06, cz)
			ring.scale = Vector3.ONE * (1.0 + 40.0 * (1.0 - (1.0 - bu) ** 3))
			(W["rm"] as StandardMaterial3D).albedo_color.a = (1.0 - bu) * 0.9


func _flash_blast() -> void:
	var W: Dictionary = vfx["pw"]
	W["boom"] = t
	_flash = 1.0
	_shake = 1.6
	Game.fx.shake = 1.2
	var tp: Player = H["tommy"]["p"]
	for b: Dictionary in bots:
		var R: Robot = b["R"]
		if R.dead:
			continue
		var dx := R.x - tp.x
		var dz := R.z - tp.z
		var d := U.hyp(dx, dz)
		if d == 0.0:
			d = 1.0
		var f := clampf(1.0 - d / 15.0, 0.0, 1.0)
		b["push"] = (b["push"] as Vector3) + Vector3(dx / d * (1.0 + 5.0 * f), 0.0, dz / d * (1.0 + 5.0 * f))
		b["stag"] = 0.5 + f
		R.state_t = 0.0
		R.hit_x = dx / d
		R.hit_z = dz / d
	H["prog"]["back"] = 1.0
	(H["prog"]["p"] as Player).vz = -2.6
	H["prog"]["blown"] = t
	var a := Vector3(tp.x, FY + 1.0, tp.z)
	var add: CinePuffs = vfx["add"]
	var dust: CinePuffs = vfx["dust"]
	for i in 120:
		var v := Vector3(rr(-1.0, 1.0), rr(-0.1, 1.0), rr(-1.0, 1.0)).normalized() * rr(8.0, 24.0)
		add.emit(a.x, a.y, a.z, v.x, v.y, v.z, rr(0.5, 1.2), rr(0.2, 0.5), 0.02, 1.2, 0.0, Color(1.0, rr(0.8, 1.0), rr(0.3, 0.7), 1.0))
	for i in 40:
		var an := rr(0.0, 6.28)
		var sp := rr(8.0, 18.0)
		dust.emit(a.x, FY + 0.15, a.z, cos(an) * sp, rr(0.2, 1.0), sin(an) * sp, rr(1.0, 2.0), 1.0, 5.0, 2.0, 0.0, Color(0.42, 0.38, 0.33, 0.55))
	CineParts.play(CineParts.sound("asc.blast", [["t", 0.0, 2.2, 70.0, 22.0, {"gain": 1.6, "wet": 0.5}], ["n", 0.0, 2.4, {"type": "lowpass", "f0": 5000.0, "f1": 60.0, "gain": 1.5, "wet": 0.7}], ["n", 0.05, 1.2, {"type": "highpass", "f0": 3000.0, "f1": 800.0, "gain": 0.5, "wet": 0.5}], ["t", 0.05, 1.6, 55.0, 20.0, {"gain": 1.2}]]))
	_level("rise", 0.0, 0.02)
	_level("drone", 0.0, 0.05)
	_level("hero", 1.0, 0.05)
	_level("siren", 0.0, 0.05)


# ---- the Kamehameha (the game's, driven by a stub fire button and an aim that sweeps) ----
func _build_kame() -> Dictionary:
	kcombat.o = self
	kcombat.targets = []
	var state := {"hy": SWEEP_FROM}
	var kame := Kamehameha.new(kcombat, func(_x: float, _z: float, _y: float) -> float: return FY, func() -> Vector3:
		var c := cos(-0.3)
		return Vector3(sin(float(state["hy"])) * c, sin(-0.3), cos(float(state["hy"])) * c))
	_root.add_child(kame)
	return {"kame": kame, "state": state, "fire": Inp.Btn.new(), "pressed": false}


# ---- per frame: the heroes ----
func _update_heroes(dt: float) -> void:
	var prog: Dictionary = H["prog"]
	var tommy: Dictionary = H["tommy"]
	var ramble: float = T["ramble"]
	var rl5: float = T["rl"][5]
	var aim_t: float = T["aim"]
	prog["gest"] = maxf(_win(t, ramble - 0.4, rl5 + 1.5, 0.5, 0.6), 0.0) * (1.0 if t < float(T["quiet"]) else 0.0) * 0.9 + 0.35 * _win(t, aim_t - 1.0, ramble, 0.5, 0.3)
	prog["look"] = 0.6 * sin(t * 0.9) * _win(t, aim_t - 1.0, rl5, 0.5, 0.5)
	prog["duck"] = _win(t, float(T["pa2"]) + 1.2, float(T["kame"]) + 0.6, 0.4, 0.5) * 0.85
	prog["back"] = lerpf(prog["back"], 0.2 if t > float(T["reveal"]) else 0.0, 1.0 - exp(-2.0 * dt))
	tommy["bow"] = _win(t, ramble - 2.0, float(T["rise"]) + 0.4, 1.0, 0.5)
	tommy["pw"] = _win(t, float(T["rise"]) + 0.5, T["kame"], 1.2, 0.5) * (1.0 if t < float(T["kame"]) else 0.0)
	# Prog is blown back to the wall by the flash and walks up behind Tommy again for the end
	var p: Player = prog["p"]
	var bt: float = t - float(prog["blown"]) if float(prog["blown"]) >= 0.0 else -1.0
	if bt >= 0.0 and bt < 0.9:
		p.z = lerpf(p.z, -2.3, 1.0 - exp(-5.0 * dt))
		p.x = lerpf(p.x, -1.9, 1.0 - exp(-5.0 * dt))
		p.vz = -2.6 * (1.0 - bt / 0.9)
	else:
		p.vz = 0.0
	if t > float(T["after"]):
		p.z = lerpf(p.z, -0.7, 1.0 - exp(-1.2 * dt))
		p.x = lerpf(p.x, PROG_X, 1.0 - exp(-1.2 * dt))
		p.vz = 1.2 if absf(p.z + 0.7) > 0.15 else 0.0
	p.yaw = 0.0
	p.y = FY
	var tp: Player = tommy["p"]
	tp.y = FY
	var kame: Kamehameha = K["kame"]
	if kame.busy:
		var d := atan2(sin(kame.yaw_ - tp.yaw), cos(kame.yaw_ - tp.yaw))
		tp.yaw += d * (1.0 - exp(-16.0 * dt))
	(prog["an"] as Animator).update(dt, p)
	var tan_: Animator = tommy["an"]
	tan_.update(dt, tp)
	kame.pose(tan_, tp, dt)
	# Tommy's look: face states, hair growth, skin glow
	var fc: Dictionary = H["face"]
	var want := "ssj3" if t >= float(T["rise"]) + 1.5 else ("solemn" if t >= ramble - 2.2 else "normal")
	if fc["state"] != want:
		fc["state"] = want
		_face_set(fc["kit"], want)
	var hr: Variant = H["hair"]
	if hr != null:
		var gu := clampf((t - float(T["hatOff"]) - 0.3) / 2.6, 0.0, 1.0)
		(hr["g"] as Node3D).visible = gu > 0.0
		for L: Dictionary in hr["locks"]:
			var g := Cutscene.ease_(clampf(gu * 1.5 - float(L["k"]), 0.0, 1.0))
			var el := g + sin(g * PI) * 0.18 if g < 1.0 else 1.0
			var m: MeshInstance3D = L["mesh"]
			var sw := (0.05 + 0.1 * _aura) * float(L["amp"])
			m.basis = Basis.from_euler(Vector3(sin(real * 1.9 + float(L["ph"])) * sw, 0.0, sin(real * 2.3 + float(L["ph"]) * 1.3) * sw), EULER_ORDER_XYZ).scaled(Vector3.ONE * maxf(0.001, el))
		(hr["m"] as StandardMaterial3D).emission_energy_multiplier = 0.45 + 0.5 * _aura
	for m: Material in fc["kit"]["mats"]:
		if m is BaseMaterial3D:
			(m as BaseMaterial3D).emission_enabled = true
			(m as BaseMaterial3D).emission = Color.hex(0xffa020ff)
			(m as BaseMaterial3D).emission_energy_multiplier = 0.14 * _aura * (1.0 if t >= float(T["hatOff"]) else _xf)
	var h: Dictionary = H["hat"]
	if h["on"]:
		var v: Vector3 = h["v"]
		var n: Node3D = h["hat"]
		v.y -= 16.0 * dt
		n.position += v * dt
		n.rotation += (h["w"] as Vector3) * dt
		if n.position.y < FY + 0.12:
			n.position.y = FY + 0.12
			if absf(v.y) > 2.0:
				v.y *= -0.35
				v.x *= 0.5
				v.z *= 0.5
				h["w"] = (h["w"] as Vector3) * 0.4
			else:
				v = Vector3.ZERO
				h["w"] = Vector3.ZERO
		h["v"] = v


# ---- the barrage: the whole crowd firing into the aura ----
func _barrage(dt: float) -> void:
	var bg: float = T["barrage"]
	var kend: float = float(T["kame"]) + 2.7
	if t < bg or t > kend:
		return
	var rate := 70.0 * _win(t, bg, kend, 0.3, 0.4)
	_acc += dt * rate
	var alive: Array[Dictionary] = []
	for b: Dictionary in bots:
		if not (b["R"] as Robot).dead:
			alive.append(b)
	if alive.is_empty():
		return
	var tp: Player = H["tommy"]["p"]
	while _acc >= 1.0:
		_acc -= 1.0
		var b: Dictionary = alive[randi() % alive.size()]
		var a: Vector3 = (b["v"] as RobotView).muzzle_world()
		var q := Vector3(rr(-1.0, 1.0), rr(-0.4, 1.0), rr(-1.0, 1.0)).normalized() * 1.45 + Vector3(tp.x, FY + 0.95, tp.z)
		Game.fx.tracer(a, q, 0.04, 0.09, 0xff6a3a)
		if randf() < 0.7:
			var nn := q - Vector3(tp.x, tp.y, tp.z)
			nn.y = 0.0
			Game.fx.sparks(q, 4, 3.0, nn.normalized(), 0xffd890)
		var R: Robot = b["R"]
		R.state = &"attack"
		R.a_u = 0.0
		if randf() < 0.3:
			vfx["add"].emit(a.x, a.y, a.z, 0.0, 0.0, 0.0, 0.1, 0.8, 1.6, 1.0, 0.0, Color(1.0, 0.55, 0.25, 0.9))
		if randf() < 0.18:
			Game.sfx.play("rifle" if randf() < 0.5 else "smg")


# ---- camera ----
func _s(px: float, py: float, pz: float, lx: float, ly: float, lz: float, fov: float) -> void:
	camera.pos = Vector3(px, py, pz)
	camera.look = Vector3(lx, ly, lz)
	camera.fov = fov


func _shot_at(tm: float) -> void:
	var tp: Player = H["tommy"]["p"]
	var th := _bone(H["tommy"]["an"], &"head")
	var ph := _bone(H["prog"]["an"], &"head")
	var F := Vector3(sin(tp.yaw), 0.0, cos(tp.yaw))
	var Rt := Vector3(-cos(tp.yaw), 0.0, sin(tp.yaw))
	var rise: float = T["rise"]
	var r0 := tm - rise
	var aim_t: float = T["aim"]
	var ramble: float = T["ramble"]
	var rl5: float = T["rl"][5]
	var l1: float = T["l1"]
	var l2: float = T["l2"]
	var reveal: float = T["reveal"]
	var awe: float = T["awe"]
	var pa2: float = T["pa2"]
	var kame: float = T["kame"]
	var rel: float = T["rel"]
	var dome: float = T["dome"]
	var after: float = T["after"]
	var end_t: float = T["endT"]
	if tm < aim_t:      # behind the horde, pushing in on the two of them
		var u := tm / aim_t
		_s(lerpf(-9.0, -2.5, u), FY + lerpf(6.5, 3.0, u), lerpf(30.0, 12.5, u), 0.0, FY + 1.2, 0.0, 42.0)
	elif tm < ramble:      # Prog's face
		_s(ph.x + 0.8, ph.y + 0.05, ph.z + 2.0, ph.x, ph.y, ph.z, 30.0)
	elif tm < rl5 + 0.8:
		var k := int(floorf((tm - ramble) / 3.8)) % 5
		var u := fmod(tm - ramble, 3.8) / 3.8
		match k:
			0:      # the two of them, low
				_s(0.0, FY + 0.75, 4.8 - 0.5 * u, 0.0, FY + 1.1, 0.0, 42.0)
			1:      # Prog, three-quarter
				_s(ph.x - 1.0, ph.y + 0.1, ph.z + 2.0, ph.x, ph.y, ph.z, 30.0)
			2:      # from behind them: the horde
				_s(-2.2, FY + 1.5, -1.0, 1.5, FY + 1.6, 12.0, 50.0)
			3:      # Tommy, silent
				_s(th.x - 0.8, th.y + 0.05, th.z + 2.0, th.x, th.y + 0.05, th.z, 30.0)
			_:      # between their feet: the ring closing
				_s(0.0, FY + 0.35 + 0.1 * u, 0.8, 0.0, FY + 1.3, 8.0, 54.0)
	elif tm < l1:      # push in on Tommy's bowed head
		var u := (tm - rl5 - 0.8) / (l1 - rl5 - 0.8)
		_s(th.x - 0.5, th.y + 0.05, th.z + lerpf(2.6, 1.9, u), th.x, th.y + 0.1, th.z, 28.0)
	elif tm < l2:
		_s(th.x + 0.2, th.y - 0.1, th.z + 1.9, th.x, th.y + 0.08, th.z, 27.0)
	elif tm < rise:      # slow pull back
		var u := (tm - l2) / (rise - l2)
		_s(lerpf(th.x, 0.0, u), th.y - 0.05 + 0.3 * u, th.z + lerpf(2.0, 6.5, u), th.x, th.y, th.z, 34.0)
	elif r0 < 2.0:      # his eyes open
		_s(th.x + 0.05, th.y + 0.2, th.z + 1.9, th.x, th.y + 0.32, th.z, 28.0)
	elif r0 < 3.8:      # the ground splitting at his feet
		_s(tp.x + 2.0, FY + 0.28, tp.z + 1.9, tp.x, FY + 0.55, tp.z, 46.0)
	elif r0 < 5.2:      # the hair growing
		var u := (r0 - 3.8) / 1.4
		_s(th.x + 1.5 - 0.4 * u, th.y + 0.25, th.z + 1.9, th.x, th.y + 0.2, th.z, 32.0)
	elif tm < reveal:      # pulled back from the blast
		var u := clampf((tm - rise - 5.2) / 1.9, 0.0, 1.0)
		_s(tp.x * (1.0 - u), FY + 1.2 + 0.4 * u, tp.z + lerpf(2.6, 8.0, u * u), tp.x, FY + 1.2, tp.z, lerpf(48.0, 62.0, u))
	elif tm < awe:      # a low hero shot
		var u := (tm - reveal) / (awe - reveal)
		_s(tp.x - 0.7 + 1.1 * u, FY + 0.35, tp.z + lerpf(3.6, 4.2, u), tp.x, FY + 1.25, tp.z, 42.0)
	elif tm < pa2 + 0.6:      # Prog, lit gold
		_s(ph.x - 0.9, ph.y, ph.z + 1.9, ph.x, ph.y, ph.z, 31.0)
	elif tm < kame:      # behind Tommy: the barrage coming in
		_s(tp.x - 2.2, FY + 1.1, tp.z - 0.8, tp.x + 1.0, FY + 1.35, tp.z + 8.0, 50.0)
	elif tm < kame + 1.4:      # the hands, the ball
		_s(tp.x + F.x * 3.0 + Rt.x * 2.7, FY + 1.0, tp.z + F.z * 3.0 + Rt.z * 2.7, tp.x + Rt.x * 0.3 + F.x * 0.1, FY + 0.7, tp.z + Rt.z * 0.3 + F.z * 0.1, 40.0)
	elif tm < rel - 0.15:      # his face as it builds
		_s(tp.x + F.x * 2.6 - Rt.x * 1.0, FY + 0.8, tp.z + F.z * 2.6 - Rt.z * 1.0, th.x, FY + 1.0, th.z, 34.0)
	elif tm < rel + 1.1:      # the thrust, side on
		_s(tp.x - Rt.x * 6.0 + F.x * 0.4, FY + 0.9, tp.z - Rt.z * 6.0 + F.z * 0.4, tp.x + F.x * 1.2, FY + 0.8, tp.z + F.z * 1.2, 44.0)
	elif tm < rel + 2.3:      # over his shoulder down the beam
		_s(tp.x - F.x * 2.6 + Rt.x * 1.0, FY + 1.1, tp.z - F.z * 2.6 + Rt.z * 1.0, tp.x + F.x * 9.0, FY + 0.8, tp.z + F.z * 9.0, 52.0)
	elif tm < dome - 0.4:      # the sweep, from the side
		var u := (tm - rel - 2.3) / (dome - rel - 2.7)
		_s(-15.0, FY + 3.0, 6.0 + 4.0 * u, 2.0 + 5.0 * u, FY + 1.2, 12.0, 56.0)
	elif tm < dome + 2.4:      # the dome and the wave
		_s(-1.8, FY + 3.4, -2.2, 16.0, FY + 2.0, 17.0, 56.0)
	elif tm < after:      # across the wreckage
		var u := (tm - dome - 2.4) / (after - dome - 2.4)
		_s(lerpf(8.0, 3.0, u), FY + lerpf(0.8, 1.3, u), lerpf(7.0, 3.5, u), 0.0, FY + 1.5, 11.0, 50.0)
	elif tm < end_t:      # from behind the two of them
		_s(0.3, FY + 1.5, BACK_Z + 0.35, 0.0, FY + 0.95, 0.0, 54.0)
	else:      # his face for the last line, then the slow pull back
		var u := Cutscene.ease_((tm - end_t) / (float(T["end"]) - end_t))
		_s(tp.x + 0.5 - 0.3 * u, FY + 0.8 + 0.5 * u, tp.z + lerpf(2.4, 5.0, u), th.x, th.y + 0.15 + 0.1 * u, th.z, 28.0 + 6.0 * u)
	camera.look.y -= 0.12 * camera.pos.distance_to(camera.look)      # the subtitle panel fills the lower third: the subject sits in the upper two thirds
	var k := maxf(_shake, Game.fx.shake) * 0.07
	camera.pos += Vector3(rr(-k, k), rr(-k, k), rr(-k, k))


# ---- the world we borrow ----
func _borrow() -> void:
	var v: View = Game.view
	var pl := Game.player
	_saved = {"bg": v.background, "fog_kind": v.fog_kind, "fog_color": v.fog_color, "fog_near": v.fog_near, "fog_far": v.fog_far, "fog_density": v.fog_density,
		"sun_c": v.sun_color, "sun_i": v.sun_intensity, "h_c": v.hemi_color, "h_g": v.hemi_ground, "h_i": v.hemi_intensity, "pl": Vector3(pl.x, pl.y, pl.z), "pa": null}
	v.set_background(Color.hex(0x070a12ff))
	v.set_fog(Color.hex(0x0a0e18ff), 45.0, 150.0)
	v.set_sun(Color.hex(0xa9c2ffff), 1.6)
	v.set_hemi(Color.hex(0x6a7eaeff), Color.hex(0x262a36ff), 1.0)
	pl.x = 0.0      # the sun and its shadow follow the player: he stands in the set
	pl.y = FY
	pl.z = 0.0
	if Game.animator != null:
		_saved["pa"] = Game.animator.actor.visible
		Game.animator.actor.visible = false


func _give_back() -> void:
	var s: Variant = _saved
	if s == null:
		return
	_saved = null
	var v: View = Game.view
	var pl := Game.player
	v.set_background(s["bg"])
	match int(s["fog_kind"]):
		1:
			v.set_fog(s["fog_color"], s["fog_near"], s["fog_far"])
		2:
			v.set_fog_exp2(s["fog_color"], s["fog_density"])
		_:
			v.clear_fog()
	v.set_sun(s["sun_c"], s["sun_i"])
	v.set_hemi(s["h_c"], s["h_g"], s["h_i"])
	var q: Vector3 = s["pl"]
	pl.x = q.x
	pl.y = q.y
	pl.z = q.z
	if Game.animator != null and s["pa"] != null:
		Game.animator.actor.visible = s["pa"]


# ---- run ----
func play() -> bool:
	if on:
		return false
	on = true
	t = -1.0
	real = 0.0
	_ei = 0
	_shake = 0.0
	_aura = 0.0
	_xf = 0.0
	_flash = 0.0
	_ev = []
	_line = null
	bots = []
	_acc = 0.0
	_wait = 0.0
	_rise_cut = {"cur": 300.0, "t0": -1.0}
	_root = Node3D.new()
	_root.name = "TommyAscension"
	Game.level.add_child(_root)
	camera.pos = Game.camera.global_position
	camera.look = Game.camera.global_position - Game.camera.global_basis.z
	camera.fov = 50.0
	_flash_el = ColorRect.new()
	_flash_el.color = Color(Color("#fff6d8"), 0.0)
	_flash_el.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_el.set_anchors_preset(Control.PRESET_FULL_RECT)
	Game.ui.add_child(_flash_el)
	enter_cine(false)
	Game.ui.dialog.set_bars(true)
	Game.ui.set_fade(true)
	return true


func _begin() -> void:
	K = _build_kame()
	_set_p = _build_set()
	vfx = {"add": CinePuffs.new(_root, true, 11, 1400, 0, 0.45, 420.0), "dust": CinePuffs.new(_root, false, 7, 700, 0, 0.45, 420.0), "acc_f": 0.0, "acc_s": 0.0, "acc_d": 0.0}
	vfx["pw"] = _build_power()
	_build_heroes()
	_build_robots()
	var ta: Animator = H["tommy"]["an"]
	H["face"] = {"kit": _face_kit(ta), "state": ""}
	H["hair"] = _build_hair(ta)
	H["hat"] = _build_hat(ta)
	_borrow()
	_audio_on()
	t = 0.0
	# ---- the cues
	_E(T["fadeIn"], Game.ui.set_fade.bind(false))
	_E(0.0, func() -> void:
		_level("drone", 1.0, 2.5)
		_level("hum", 1.0, 3.0)
		_level("siren", 0.45, 1.5))
	_E(T["pa"], _say.bind(PA1))
	for i in RAMBLE.size():
		_E(T["rl"][i], _say.bind(RAMBLE[i]))
	_E(T["quiet"], func() -> void:
		_level("siren", 0.0, 1.5)
		_level("hum", 0.4, 1.5)
		_level("drone", 0.5, 1.2))
	var b: float = float(T["quiet"]) + 0.5
	var heartbeat := func() -> void:
		_tone("hb1", 0.0, 62.0, 34.0, {"dur": 0.28, "gain": 0.9, "wet": 0.3})
		_tone("hb2", 0.22, 58.0, 32.0, {"dur": 0.28, "gain": 0.6, "wet": 0.3})
	while b < float(T["rise"]):
		_E(b, heartbeat)
		b += 1.15
	_E(T["breath"], func() -> void:
		var a := _bone(H["tommy"]["an"], &"head") + Vector3(0.0, 0.0, 0.5)
		for i in 6:
			vfx["dust"].emit(a.x, a.y - 0.1, a.z, rr(-0.2, 0.2), rr(0.1, 0.4), rr(0.4, 0.9), rr(1.0, 1.8), 0.15, 0.7, 1.2, 0.0, Color(0.8, 0.85, 0.9, 0.5))
		_noise("breath", 0.0, 1.3, {"type": "bandpass", "f0": 600.0, "f1": 250.0, "q": 0.8, "gain": 0.35, "attack": 0.3, "wet": 0.5}))
	_E(T["l1"], _say.bind(SAY1))
	_E(T["l2"], _say.bind(SAY2))
	_E(T["rise"], func() -> void:      # the power builds: rumble, a rising pitch, the scream
		_level("rise", 1.0, 5.0)
		_level("drone", 0.9, 3.0)
		_level("hum", 0.0, 1.0)
		_rise_cut["t0"] = real
		_noise("rumble", 0.0, 7.0, {"type": "lowpass", "f0": 160.0, "f1": 90.0, "gain": 0.9, "attack": 2.0, "wet": 0.2})
		_clip_bus(_yells["rise"])
		for i in 6:
			_tone("up%d" % i, i * 1.0, 60.0 + i * 12.0, 40.0, {"dur": 0.9, "gain": 0.7, "wet": 0.4}))
	_E(float(T["rise"]) + 2.0, func() -> void: _shake = maxf(_shake, 0.4))
	_E(T["hatOff"], _pop_hat)
	_E(T["flash"], _flash_blast)
	_E(T["reveal"], _level.bind("hero", 0.8, 2.0))
	_E(T["awe"], _say.bind(AWE))
	_E(T["pa2"], _say.bind(PA2))
	_E(T["kame"], func() -> void:
		K["pressed"] = true
		var f: Inp.Btn = K["fire"]
		f.pressed = true
		f.held = true
		_level("hero", 1.0, 1.0))
	for e: Array in [[0.1, "Ka..."], [0.95, "me..."], [1.7, "ha..."], [2.3, "me..."]]:
		_E(float(T["kame"]) + float(e[0]), _say.bind(_L("TOMMY", e[1], 7.0, 0.3)))
	_E(T["rel"], func() -> void:
		(K["fire"] as Inp.Btn).held = false
		_say(_L("TOMMY", "HAAAAAAAAAAA!!", 12.0, 1.6))
		_clip_bus(_yells["rel"])
		_level("hero", 0.5, 0.5))
	_E(T["dome"], func() -> void:
		_ripple()
		_dome_at = t
		_shake = maxf(_shake, 1.2)
		_level("hero", 0.0, 1.5)
		_tone("dome", 0.0, 80.0, 22.0, {"dur": 2.5, "gain": 1.4, "wet": 0.5}))
	_E(T["after"], _level.bind("drone", 0.35, 3.0))
	_E(T["endP"], _say.bind(END_P))
	_E(T["endT"], _say.bind(END_T))
	_E(T["fadeOut"], Game.ui.set_fade.bind(true))
	_E(T["end"], _finish.bind(true))


func _finish(_ok: bool) -> void:
	if not on:
		return
	on = false
	_end_line()
	if K != null:
		(K["kame"] as Kamehameha).quiet()
	_audio_off()
	_give_back()
	Game.fx.shake = 0.0
	for b: Dictionary in bots:
		Game.enemy_views.npc_views.erase(b["v"])
		(b["v"] as RobotView).dispose()
	if H != null:
		(H["prog"]["an"] as Animator).pose_hook = Callable()
		(H["tommy"]["an"] as Animator).pose_hook = Callable()
	if _root != null:
		_root.queue_free()
		_root = null
	if _flash_el != null:
		_flash_el.queue_free()
		_flash_el = null
	H = null
	K = null
	vfx = {}
	bots = []
	_bot_of = {}
	kcombat.targets = []
	_set_p = null
	leave_cine()
	Game.rig.snap_to(Game.player)
	Game.get_tree().create_timer(0.15).timeout.connect(Game.ui.set_fade.bind(false))


func skip() -> void:
	if on and t >= 0.0:
		_finish(true)


## skip to a moment on the clock (testing): everything before it runs in order
func seek(s: float, step: float = 0.05) -> void:
	var h := hold
	hold = false
	while on and t < s:
		update(step)
	hold = h


func update(dt: float) -> void:
	if not on:
		return
	if _root != null and not is_instance_valid(_root):      # (the level went from under it: console level change)
		_root = null
		_finish(false)
		return
	if t < 0.0:
		_wait += dt
		if _wait > 0.5:
			_begin()
		return
	if H == null or K == null:
		return
	if hold:
		dt = 0.0
	dt = minf(dt, 0.05)
	real += dt
	t += dt
	var tm := t
	while _ei < _ev.size() and float(_ev[_ei]["t"]) <= tm:
		var e: Dictionary = _ev[_ei]
		_ei += 1
		(e["fn"] as Callable).call()
		if not on:
			return
	_ramp_step(dt)
	var flash_t: float = T["flash"]
	var rise: float = T["rise"]
	var after: float = T["after"]
	_xf = clampf((tm - rise) / 6.4, 0.0, 1.0) * (1.0 if tm < flash_t else 0.0)
	_aura = 0.0 if tm < rise + 1.0 else (Cutscene.ease_((tm - rise - 1.0) / 5.0) * 0.9 if tm < flash_t else (0.8 if tm < after else lerpf(0.8, 0.28, Cutscene.ease_((tm - after) / 3.0))))
	var kame: Kamehameha = K["kame"]
	if kame.state != "idle" and tm < float(T["dome"]) + 1.0:
		_aura = 0.75 if kame.state == "beam" or kame.state == "thrust" else 0.45
	_flash = maxf(0.0, _flash - dt * 1.3)
	_flash_el.color.a = minf(1.0, _flash * 1.4)
	# the Kamehameha: the stub fire button, the sweep of the aim, the player-like puppet it works on
	var fire: Inp.Btn = K["fire"]
	if K["pressed"]:
		fire.pressed = tm < float(T["kame"]) + 0.1
	var u := clampf((tm - float(T["beam"])) / 2.5, 0.0, 1.0)
	K["state"]["hy"] = SWEEP_FROM if tm < float(T["beam"]) else lerpf(SWEEP_FROM, SWEEP_TO, Cutscene.ease_(u))
	kame.update(dt, H["tommy"]["p"], fire)
	_update_heroes(dt)
	_update_robots(dt)
	_barrage(dt)
	_update_power(dt)
	for i in 2:
		CineParts.glow_opacity(_set_p["beacons"][i], maxf(0.0, sin(real * 5.0 + i * 3.1)) * (0.9 if tm < rise else 0.3))
	# smouldering wreckage after the dome
	if tm > float(T["dome"]):
		for b: Dictionary in bots:
			if (b["R"] as Robot).dead and randf() < dt * 2.5:
				var l: Vector3 = b["last"]
				vfx["dust"].emit(l.x + rr(-0.4, 0.4), FY + 0.6, l.z + rr(-0.4, 0.4), rr(-0.3, 0.3), rr(0.8, 1.8), rr(-0.3, 0.3), rr(2.5, 4.0), 0.5, 2.0, 0.6, 0.0, Color(0.12, 0.12, 0.14, 0.3))
				if randf() < 0.3:
					vfx["add"].emit(l.x, FY + 0.7, l.z, rr(-0.2, 0.2), rr(1.0, 2.5), rr(-0.2, 0.2), rr(0.4, 0.9), 0.3, 0.05, 1.0, 0.0, Color(1.0, 0.55, 0.15, 0.8))
	vfx["add"].step(dt)
	vfx["dust"].step(dt)
	Game.fx.update(dt)
	Game.enemy_views.flush()
	_tick_line()
	_shot_at(tm)
	_shake = maxf(0.0, _shake - dt * 1.6)


## the level is being left under it
func dispose() -> void:
	if on:
		_finish(false)
