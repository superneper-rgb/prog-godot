class_name OfflineSynth
extends RefCounted
## Renders Web Audio style hits into a sample buffer (the JS noiseHit / toneHit: a noise burst through a sweeping biquad, an oscillator with a pitch glide, both with an attack and an exponential fall), then into an AudioStreamWAV. For the sounds the JS builds live from nodes.


static func make(dur: float, rate: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(ceili(dur * rate))
	return b


## JS setValueAtTime(.0001) -> linearRamp(gain, t + attack) -> exponentialRamp(.0001, t + dur)
static func _env(u: float, gain: float, attack: float, dur: float) -> float:
	if u < attack:
		return 0.0001 + (gain - 0.0001) * u / attack
	var f := (u - attack) / maxf(dur - attack, 1e-5)
	return gain * pow(0.0001 / gain, f)


static func _wave(type: StringName, ph: float) -> float:
	match type:
		&"sine":
			return sin(ph * TAU)
		&"square":
			return 1.0 if ph < 0.5 else -1.0
		&"sawtooth":
			return 2.0 * ph - 1.0
	return 1.0 - 4.0 * absf(ph - 0.5)      # triangle


## o: type (sine, triangle, square, sawtooth), f0, f1, gain, dur, attack
static func tone(buf: PackedFloat32Array, rate: int, t: float, o: Dictionary) -> void:
	var type: StringName = o.get("type", &"triangle")
	var f0: float = o.get("f0", 300.0)
	var f1: float = maxf(15.0, o.get("f1", 60.0))
	var gain: float = o.get("gain", 0.2)
	var dur: float = o.get("dur", 0.3)
	var attack: float = o.get("attack", 0.003)
	var s0 := roundi(t * rate)
	var n := mini(ceili(dur * rate), buf.size() - s0)
	var ph := 0.0
	var dtt := 1.0 / rate
	var ratio := f1 / f0
	for i in n:
		var u := i * dtt
		ph = fposmod(ph + f0 * pow(ratio, u / dur) * dtt, 1.0)
		buf[s0 + i] += _wave(type, ph) * _env(u, gain, attack, dur)


## o: type (lowpass, bandpass, highpass), f0, f1, q, gain, dur, attack. Q as Web Audio reads it: decibels on a lowpass or highpass, plain on a bandpass.
static func noise(buf: PackedFloat32Array, rate: int, t: float, o: Dictionary) -> void:
	var type: StringName = o.get("type", &"bandpass")
	var f0: float = o.get("f0", 2000.0)
	var f1: float = maxf(30.0, o.get("f1", 600.0))
	var q: float = o.get("q", 2.0)
	var gain: float = o.get("gain", 0.2)
	var dur: float = o.get("dur", 0.2)
	var attack: float = o.get("attack", 0.003)
	var s0 := roundi(t * rate)
	var n := mini(ceili(dur * rate), buf.size() - s0)
	var dtt := 1.0 / rate
	var ratio := f1 / f0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	for i in n:
		var u := i * dtt
		if i % 16 == 0:
			var w := TAU * minf(f0 * pow(ratio, u / dur), rate * 0.49) / rate
			var cw := cos(w)
			var sw := sin(w)
			var alpha := sw / (2.0 * q) if type == &"bandpass" else sw / (2.0 * pow(10.0, q / 20.0))
			var a0 := 1.0 + alpha
			a1 = -2.0 * cw / a0
			a2 = (1.0 - alpha) / a0
			match type:
				&"bandpass":
					b0 = alpha / a0
					b1 = 0.0
					b2 = -alpha / a0
				&"highpass":
					b0 = (1.0 + cw) * 0.5 / a0
					b1 = -(1.0 + cw) / a0
					b2 = b0
				_:
					b0 = (1.0 - cw) * 0.5 / a0
					b1 = (1.0 - cw) / a0
					b2 = b0
		var x := randf_range(-1.0, 1.0)
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		buf[s0 + i] += y * _env(u, gain, attack, dur)


static func wav(buf: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, clampi(roundi(buf[i] * 32767.0), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w
