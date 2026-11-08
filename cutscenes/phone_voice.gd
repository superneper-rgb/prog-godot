class_name PhoneVoice
extends RefCounted
## PHONE-CALL VOICES (JS cutscenes/phone-voice.js): the synthesised "speech" under cutscene subtitles: one voiced syllable per vowel group while a line types out in the shared box. The far end of a call (phone: true) is a gravelly saw through a telephone band-pass (300-3000 Hz) with a little line grit; the near voice is lower, closer, unfiltered. Used by the balcony call and the apartment wake-up.
## ENGINE DIFFERENCE: the JS builds an oscillator and filters per syllable. Here one syllable per (pitch, phone, vowel, last) is rendered once and kept, and its per-letter pitch wobble is the playback rate, which also moves the formants a little, as the JS's 1 + .04 sin(i) moves them.
##   voice_syllable({"pitch": 108.0, "phone": true}, ch, i, last, prev_ch)   ch: the vowel, i: its index in the line, last: the final syllable before a full stop, prev_ch: the character before it

const VOWEL := {"a": [730.0, 1090.0], "e": [530.0, 1840.0], "i": [300.0, 2290.0], "o": [570.0, 840.0], "u": [325.0, 700.0], "y": [380.0, 2000.0]}
const R := 22050
static var _kept: Dictionary = {}


static func _biquad(type: int, f: float, q: float) -> PackedFloat64Array:
	var w := TAU * minf(f, R * 0.49) / R
	var cw := cos(w)
	var alpha := sin(w) / (2.0 * q)
	var a0 := 1.0 + alpha
	match type:
		0:      # bandpass
			return PackedFloat64Array([alpha / a0, 0.0, -alpha / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])
		1:      # highpass
			return PackedFloat64Array([(1.0 + cw) * 0.5 / a0, -(1.0 + cw) / a0, (1.0 + cw) * 0.5 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])
	return PackedFloat64Array([(1.0 - cw) * 0.5 / a0, (1.0 - cw) / a0, (1.0 - cw) * 0.5 / a0, -2.0 * cw / a0, (1.0 - alpha) / a0])      # lowpass


static func _run(c: PackedFloat64Array, x: PackedFloat32Array) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(x.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var b0 := c[0]
	var b1 := c[1]
	var b2 := c[2]
	var a1 := c[3]
	var a2 := c[4]
	for i in x.size():
		var v := x[i]
		var y := b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = v
		y2 = y1
		y1 = y
		o[i] = y
	return o


## (o: a cutscene's own voice: d, g (the glide's end, as a share of the pitch), fm (formant shift), pk (peak))
static func _render(pitch: float, phone: bool, ch: String, last: bool, o: Dictionary = {}) -> AudioStreamWAV:
	var f: Array = VOWEL[ch] if VOWEL.has(ch) else VOWEL["a"]
	var d: float = o.get("d", 0.19 if last else 0.1)
	var n := ceili((d + 0.05) * R)
	var saw := PackedFloat32Array()
	saw.resize(n)
	var ph := 0.0
	var f1: float = pitch * float(o.get("g", 0.8 if last else 0.96))
	for i in n:
		var u := minf(float(i) / R / d, 1.0)
		ph = fposmod(ph + lerpf(pitch, f1, u) / R, 1.0)
		saw[i] = (1.0 if ph < 0.5 else -1.0) if o.get("square", false) else 2.0 * ph - 1.0
	var mix := PackedFloat32Array()
	mix.resize(n)
	for k in 2:
		var b := _run(_biquad(0, float(f[k]) * float(o.get("fm", 1.0 if phone else 0.93)), float(o.get("q", 5.0))), saw)
		var gg := 0.5 if k == 1 else 1.0
		for i in n:
			mix[i] += b[i] * gg
	var pk: float = o.get("pk", 0.5 if phone else 0.7)
	for i in n:
		var t := float(i) / R
		var e := (0.0001 + (pk - 0.0001) * t / 0.015) if t < 0.015 else pk * pow(0.0001 / pk, minf((t - 0.015) / (d - 0.015), 1.0))
		mix[i] *= e
	if phone:
		mix = _run(_biquad(1, 330.0, 0.7071), mix)
		for i in n:      # a little line grit
			mix[i] = tanh(mix[i] * 2.4) * 0.8
		mix = _run(_biquad(2, 2900.0, pow(10.0, 1.4 / 20.0)), mix)
	return OfflineSynth.wav(mix, R)


static func voice_syllable(who: Dictionary, ch: String, i: int, last: bool, prev_ch: String = "") -> void:
	var phone: bool = who.get("phone", false)
	var pitch: float = who["pitch"]
	var key := "%d.%s.%s.%s" % [int(pitch), phone, ch, last]
	if not _kept.has(key):
		_kept[key] = _render(pitch, phone, ch, last)
	var rate := (1.0 + 0.09 * sin(i * 1.9) + 0.05 * sin(i * 0.7)) * (0.82 if last else 1.0)
	Game.sfx.clip(_kept[key], {"rate": rate, "wet": 0.0})
	if prev_ch != "" and "bdgkpt".contains(prev_ch.to_lower()):      # plosive tick
		var s := CineParts.sound("plosive.%s" % phone, [["n", 0.0, 0.025, {"type": "bandpass", "f0": 2200.0 if phone else 1500.0, "q": 1.2, "gain": 0.18 if phone else 0.12, "wet": 0.0}]])
		CineParts.play(s)


## JS firefight.js / frug-showdown.js syllable(): a saw through the vowel's two formants, no line: f0 = pitch * (1 + .1 sin(i * 1.9)) * (last ? l_mul : 1), gliding to g_norm or g_last of it over d_norm or d_last
static func own_syllable(pitch: float, fm: float, pk: float, d_norm: float, d_last: float, g_norm: float, g_last: float, l_mul: float, ch: String, i: int, last: bool, robot: bool = false) -> void:
	var key := "own.%d.%.2f.%s.%s.%s" % [int(pitch), fm, ch, last, robot]
	if not _kept.has(key):
		_kept[key] = _render(pitch, false, ch, last, {"d": d_last if last else d_norm, "g": g_last if last else g_norm, "fm": fm, "pk": pk, "square": robot, "q": 9.0 if robot else 5.0})
	Game.sfx.clip(_kept[key], {"rate": (1.0 + 0.1 * sin(i * 1.9)) * (l_mul if last else 1.0), "wet": 0.0})


## true when the syllable at i is the last one before a full stop / question / exclamation (it falls away)
static func last_syllable(text: String, i: int) -> bool:
	var j := i + 1
	var n := 0
	while j < text.length() and n < 4:
		var c := text[j]
		if c == "." or c == "!" or c == "?":
			return true
		if n == 3 or not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z")):
			return false
		j += 1
		n += 1
	return false
