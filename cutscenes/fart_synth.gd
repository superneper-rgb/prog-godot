class_name FartSynth
extends RefCounted
## A long, loud, wandering fart, synthesised, different every time (JS cutscenes/fart-synth.js). A fart is a train of air puffs through a flapping valve: the puff rate is the pitch (45-190 Hz here), the flapping is a buzz, the cheeks are a resonance. Body: a sawtooth at the puff rate, clipped, through a resonant low-pass whose cutoff follows the pressure. Flab: a square an octave down, for the rattle. Wet: noise through a band-pass, amplitude-modulated by the puff rate itself. Tremble: a 7-15 Hz wobble on the level. Then it putters out: shorter, quieter, lower puffs with growing gaps, and one last little pfft.
## ENGINE DIFFERENCE: the JS builds this live in Web Audio. Here render(seed, length) writes the same graph to samples, on a worker thread, ahead of time (GDScript would hitch doing it mid-frame); level(tt) reads the same numbers back.

const R := 22050
const N := 900

var stream: AudioStreamWAV = null
var duration := 0.0
var d_main := 6.2
var _amp := PackedFloat32Array()
var _wob := PackedFloat32Array()
var _puffs: Array = []
var _last := 0.0


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## JS rng(seed): the game's little generator, so a seed is the same fart
class Rng:
	var s := 1
	func _init(seed_: int) -> void:
		s = seed_ & 0xffffffff
		if s == 0:
			s = 1
	func r() -> float:
		s = (s * 1664525 + 1013904223) & 0xffffffff
		return float(s) / 4294967296.0


static func _hz_q(f: float, q: float) -> PackedFloat64Array:      # a low-pass's coefficients: b0 b1 b2 a1 a2
	var w := TAU * minf(f, R * 0.45) / R
	var c := cos(w)
	var al := sin(w) / (2.0 * q)
	var a0 := 1.0 + al
	return PackedFloat64Array([(1.0 - c) * 0.5 / a0, (1.0 - c) / a0, (1.0 - c) * 0.5 / a0, -2.0 * c / a0, (1.0 - al) / a0])


## Runs on any thread: touches nothing but its own data.
static func render(seed_: int, length: float) -> FartSynth:
	var o := FartSynth.new()
	var rng := Rng.new(seed_)
	var D := length
	o.d_main = D
	# the pressure contour for the main blast: a few landmarks, then a random walk on top: squeak in, a long buzzing middle that dips into a wet rumble, a high squeal, sagging down
	var keys: Array = [[0.0, 62.0, 0.0], [0.04, 118.0, 1.0], [0.16, 104.0 + rng.r() * 20.0, 0.92], [0.3, 82.0 + rng.r() * 15.0, 0.85], [0.42, 56.0, 0.95], [0.52, 74.0 + rng.r() * 20.0, 0.9],
		[0.64, 150.0 + rng.r() * 40.0, 1.0], [0.72, 128.0, 0.88], [0.84, 88.0 + rng.r() * 12.0, 0.8], [0.95, 58.0, 0.6], [1.0, 48.0, 0.0]]
	var freq := PackedFloat32Array()
	var cut := PackedFloat32Array()
	freq.resize(N)
	cut.resize(N)
	o._amp.resize(N)
	o._wob.resize(N)
	var walk := 0.0
	for i in N:
		var u := float(i) / float(N - 1)
		var t := u * D
		var ki := 0
		while ki < keys.size() - 2 and u > float(keys[ki + 1][0]):
			ki += 1
		var a: Array = keys[ki]
		var b: Array = keys[ki + 1]
		var k := _ease((u - float(a[0])) / (float(b[0]) - float(a[0])))
		var f := lerpf(a[1], b[1], k)
		var am := lerpf(a[2], b[2], k)
		walk = clampf(walk + (rng.r() - 0.5) * 0.06, -0.22, 0.22)      # the valve never holds a note
		var vib := 0.07 * sin(t * TAU * (6.5 + 3.0 * sin(t * 0.7))) + 0.03 * sin(t * TAU * 17.3)
		freq[i] = maxf(38.0, f * (1.0 + walk + vib))
		var wv := 0.55 + 0.45 * absf(sin(t * PI * (7.0 + 8.0 * u)))      # the tremble speeds up as it goes
		var flutter := 1.0 - 0.35 * maxf(0.0, sin(t * TAU * 2.3 + rng.r() * 0.3))      # the odd pressure stutter
		o._amp[i] = am * (0.75 + 0.25 * wv) * flutter
		o._wob[i] = wv
		cut[i] = 380.0 + 2200.0 * pow(clampf((freq[i] - 40.0) / 150.0, 0.0, 1.0), 1.4) * (0.6 + 0.4 * am)
	# ---- the putter's numbers come first: they set the length
	var n := 7 + int(rng.r() * 3.0)
	var pt := D + 0.08
	for i in n:
		var k := float(i) / float(n - 1)
		var len_ := lerpf(0.2, 0.05, k) * (0.8 + 0.4 * rng.r())
		var f := lerpf(78.0, 44.0, k) * (0.85 + 0.3 * rng.r())
		var a := lerpf(0.75, 0.22, k) * (0.8 + 0.4 * rng.r())
		o._puffs.append([pt, len_, f, a])
		pt += len_ + lerpf(0.06, 0.38, k * k) * (0.7 + 0.6 * rng.r())
	o._last = pt + 0.15
	o.duration = o._last + 0.3
	var total := int((o.duration + 0.1) * R)
	var out := PackedFloat32Array()
	out.resize(total)
	_main_blast(out, D, freq, cut, o._amp)
	for p: Array in o._puffs:
		_puff(out, p[0], p[1], p[2], p[3])
	_pfft(out, o._last)
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		bytes.encode_s16(i * 2, int(clampf(out[i] * 0.85, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = R
	w.data = bytes
	o.stream = w
	return o


static func _main_blast(out: PackedFloat32Array, D: float, freq: PackedFloat32Array, cut: PackedFloat32Array, amp: PackedFloat32Array) -> void:
	var ns := int(D * R)
	var ph := 0.0
	var ph2 := 0.0
	var ph_t := 0.0
	var dt := 1.0 / float(R)
	var q_body := pow(10.0, 7.0 / 20.0)      # (Web Audio low-pass Q is in dB)
	var c_flab := _hz_q(520.0, pow(10.0, 1.0 / 20.0))
	var cb := _hz_q(380.0, q_body)
	var bx1 := 0.0
	var bx2 := 0.0
	var by1 := 0.0
	var by2 := 0.0
	var fx1 := 0.0
	var fx2 := 0.0
	var fy1 := 0.0
	var fy2 := 0.0
	var nx1 := 0.0
	var nx2 := 0.0
	var ny1 := 0.0
	var ny2 := 0.0
	var nb0 := 0.0
	var nb2 := 0.0
	var na1 := 0.0
	var na2 := 0.0
	var f := 100.0
	var a := 0.0
	var rng := RandomNumberGenerator.new()
	for i in ns:
		var uu := float(i) / float(ns) * float(N - 1)
		var i0 := int(uu)
		var i1 := mini(i0 + 1, N - 1)
		var fr := uu - float(i0)
		f = freq[i0] + (freq[i1] - freq[i0]) * fr
		a = amp[i0] + (amp[i1] - amp[i0]) * fr
		if i % 16 == 0:      # (the filters follow the curve a little slower than the audio rate)
			var ct := cut[i0] + (cut[i1] - cut[i0]) * fr
			cb = _hz_q(ct, q_body)
			var w := TAU * minf(ct * 0.55 + 260.0, R * 0.45) / R
			var al := sin(w) / (2.0 * 1.3)
			var a0 := 1.0 + al
			nb0 = al / a0
			nb2 = -al / a0
			na1 = -2.0 * cos(w) / a0
			na2 = (1.0 - al) / a0
		ph = fmod(ph + f * dt, 1.0)
		ph2 = fmod(ph2 + f * 0.5 * dt, 1.0)
		ph_t += (7.0 + 8.0 * float(i) / float(ns)) * dt
		var saw := 2.0 * ph - 1.0
		# body: clipped, through the resonant low-pass
		var bv := tanh(saw * 3.2)
		var by := cb[0] * bv + cb[1] * bx1 + cb[2] * bx2 - cb[3] * by1 - cb[4] * by2
		bx2 = bx1
		bx1 = bv
		by2 = by1
		by1 = by
		# flab: a square an octave down
		var fv := 1.0 if ph2 < 0.5 else -1.0
		var fy := c_flab[0] * fv + c_flab[1] * fx1 + c_flab[2] * fx2 - c_flab[3] * fy1 - c_flab[4] * fy2
		fx2 = fx1
		fx1 = fv
		fy2 = fy1
		fy1 = fy
		# wet: noise, flapped by the puff rate
		var nv := rng.randf() * 2.0 - 1.0
		var ny := nb0 * nv + nb2 * nx2 - na1 * ny1 - na2 * ny2
		nx2 = nx1
		nx1 = nv
		ny2 = ny1
		ny1 = ny
		var s := by * 0.55 + fy * 0.32 + ny * saw * 0.5 * 0.75
		out[i] += s * a * (1.0 + 0.28 * sin(TAU * ph_t))


## one putter: a short flap with a pitch that sags
static func _puff(out: PackedFloat32Array, t: float, len_: float, f: float, a: float) -> void:
	var i0 := int(t * R)
	var ns := int((len_ + 0.02) * R)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var nx1 := 0.0
	var nx2 := 0.0
	var ny1 := 0.0
	var ny2 := 0.0
	var p1 := 0.0
	var p2 := 0.0
	var q := pow(10.0, 6.0 / 20.0)
	var c := _hz_q(900.0, q)
	var nb0 := 0.0
	var nb2 := 0.0
	var na1 := 0.0
	var na2 := 0.0
	var rng := RandomNumberGenerator.new()
	var attack := minf(0.015, len_ * 0.2)
	for j in ns:
		var o := i0 + j
		if o >= out.size():
			return
		var tt := float(j) / float(R)
		var u := minf(1.0, tt / len_)
		if j % 16 == 0:
			c = _hz_q(900.0 * pow(320.0 / 900.0, u), q)
			var w := TAU * lerpf(600.0, 300.0, minf(1.0, tt / (len_ * 0.9))) / R
			var al := sin(w) / (2.0 * 1.5)
			var a0 := 1.0 + al
			nb0 = al / a0
			nb2 = -al / a0
			na1 = -2.0 * cos(w) / a0
			na2 = (1.0 - al) / a0
		var fq := f * 1.1 * pow(0.75 / 1.1, u)
		p1 = fmod(p1 + fq / R, 1.0)
		p2 = fmod(p2 + f * 0.55 * pow(0.4 / 0.55, u) / R, 1.0)
		var v := (2.0 * p1 - 1.0) + (1.0 if p2 < 0.5 else -1.0) * 0.4
		var y := c[0] * v + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = v
		y2 = y1
		y1 = y
		var g := 0.0
		if tt < attack:
			g = a * tt / attack
		elif u < 0.6:
			g = a * 0.8 if u > 0.0 and tt >= len_ * 0.6 else a
		else:
			g = a * 0.8 * pow(0.0001 / (a * 0.8), (u - 0.6) / 0.4)
		if u >= 1.0:
			g = 0.0
		var nv := rng.randf() * 2.0 - 1.0
		var ny := nb0 * nv + nb2 * nx2 - na1 * ny1 - na2 * ny2
		nx2 = nx1
		nx1 = nv
		ny2 = ny1
		ny1 = ny
		var ne := (a * 0.35) * minf(1.0, tt / 0.003) * maxf(0.0, 1.0 - tt / (len_ * 0.9))
		out[o] += y * g + ny * ne


## the very last of it: a breathy little pfft
static func _pfft(out: PackedFloat32Array, t: float) -> void:
	var i0 := int(t * R)
	var rng := RandomNumberGenerator.new()
	var ny1 := 0.0
	var ny2 := 0.0
	var nx1 := 0.0
	var nx2 := 0.0
	var ph := 0.0
	for j in int(0.16 * R):
		var o := i0 + j
		if o >= out.size():
			return
		var tt := float(j) / float(R)
		var w := TAU * lerpf(1100.0, 500.0, tt / 0.16) / R
		var al := sin(w) / (2.0 * 0.9)
		var a0 := 1.0 + al
		var nv := rng.randf() * 2.0 - 1.0
		var ny := (al / a0) * nv - (al / a0) * nx2 + 2.0 * cos(w) / a0 * ny1 - (1.0 - al) / a0 * ny2
		nx2 = nx1
		nx1 = nv
		ny2 = ny1
		ny1 = ny
		var v := ny * 0.25 * minf(1.0, tt / 0.01) * maxf(0.0, 1.0 - tt / 0.16)
		if tt < 0.12:
			ph = fmod(ph + 120.0 * pow(70.0 / 120.0, minf(1.0, tt / 0.1)) / R, 1.0)
			var tri := 1.0 - 4.0 * absf(ph - 0.5)
			var g := 0.18 * tt / 0.01 if tt < 0.01 else 0.18 * pow(0.0001 / 0.18, (tt - 0.01) / 0.11)
			v += tri * g
		out[o] += v


## 0..1 how loud it is t seconds after it started (for shake / rattle)
func level(tt: float) -> float:
	if tt < 0.0:
		return 0.0
	if tt < d_main:
		var i := mini(N - 1, int(floorf(tt / d_main * (N - 1))))
		return clampf(_amp[i] * (0.7 + 0.3 * _wob[i]), 0.0, 1.0)
	for p: Array in _puffs:
		if tt >= float(p[0]) and tt < float(p[0]) + float(p[1]):
			return float(p[3]) * sin((tt - float(p[0])) / float(p[1]) * PI)
	return 0.15 if tt >= _last and tt < _last + 0.12 else 0.0
