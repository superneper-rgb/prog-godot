class_name SpireAmbience
extends Node
## MEAT SPIRE's procedural ambience (JS levels/spire/ambience.js). A living, demonic body: a sub drone that darkens as you climb, a wet breath that swells every six seconds, a heartbeat loudest in the Heart and always faintly felt, random groans, whispers, squelches, growls, bile gurgles in the Gut.
## ENGINE DIFFERENCE: the sources are rendered waves on buses with filter effects moved per frame; each kind of event has a few rendered takes, played with a random pan.

const RATE := 24000
const BUS_DRONE := &"SpireDrone"
const BUS_BREATH := &"SpireBreath"
const BUS_RUMBLE := &"SpireRumble"

static var _bank: Dictionary = {}
var drone: AudioStreamPlayer
var breath: AudioStreamPlayer
var rumble: AudioStreamPlayer
var drone_lp: AudioEffectLowPassFilter
var breath_f: AudioEffectBandPassFilter
var _bus := 0.0
var _drone_g := 0.16
var _drone_f := 120.0
var _breath_g := 0.0
var _breath_ff := 520.0
var _rumble_g := 0.28
var _prev_beat := 1.0
var _next_moan := 4.0
var _next_whisper := 7.0
var _next_squelch := 3.0
var _next_gurgle := 1.0
var _next_growl := 25.0
var _info := Sfx.BusInfo.new()
var _buses: Array[StringName] = []


func _ready() -> void:
	_render_bank()
	var n := OfflineSynth.make(2.0, RATE)
	for i in n.size():
		n[i] = randf_range(-1.0, 1.0)
	var noise := OfflineSynth.wav(n, RATE, true)
	# sub drone: two detuned saws and a square an octave up, under a low-pass that the level moves
	var d := OfflineSynth.make(4.0, RATE)
	for v: Array in [[&"sawtooth", 41.0 * pow(2.0, -9.0 / 1200.0), 0.5], [&"sawtooth", 41.0 * pow(2.0, 11.0 / 1200.0), 0.5], [&"square", 82.5 * pow(2.0, 3.0 / 1200.0), 0.18], [&"sine", 27.5, 0.8]]:
		var cycles := roundf(float(v[1]) * 4.0)
		for i in d.size():
			d[i] += OfflineSynth._wave(v[0], fposmod(cycles * i / d.size(), 1.0)) * float(v[2])
	drone_lp = AudioEffectLowPassFilter.new()
	drone_lp.cutoff_hz = 120.0
	drone_lp.resonance = pow(10.0, 3.0 / 20.0)
	drone = _player(OfflineSynth.wav(d, RATE, true), BUS_DRONE, drone_lp)
	breath_f = AudioEffectBandPassFilter.new()
	breath_f.cutoff_hz = 520.0
	breath_f.resonance = 0.45
	breath = _player(noise, BUS_BREATH, breath_f)
	var rl := AudioEffectLowPassFilter.new()
	rl.cutoff_hz = 85.0
	rumble = _player(noise, BUS_RUMBLE, rl)
	rumble.pitch_scale = 0.5


func _exit_tree() -> void:
	for nm: StringName in _buses:
		var i := AudioServer.get_bus_index(nm)
		if i >= 0:
			AudioServer.remove_bus(i)


func _player(st: AudioStream, bus: StringName, fx: AudioEffect) -> AudioStreamPlayer:
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus)
	AudioServer.set_bus_send(i, &"SFX")
	AudioServer.add_bus_effect(i, fx)
	_buses.append(bus)
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.volume_db = -100.0
	add_child(p)
	p.play()
	return p


func _render_bank() -> void:
	if not _bank.is_empty():
		return
	_bank.moan = []
	for _i in 3:
		_bank.moan.append(_moan())
	_bank.whisper = [_whisper(), _whisper()]
	_bank.squelch = [_squelch(), _squelch(), _squelch()]
	_bank.bubble = [_bubble(), _bubble(), _bubble()]
	_bank.growl = [_growl(), _growl()]
	_bank.heart = _heartbeat()


## a deep, slow groan from inside the body: two detuned saws sinking in pitch under a closing low-pass, a little grit, no vowels and no vibrato
func _moan() -> AudioStreamWAV:
	var dur := randf_range(3.2, 6.0)
	var f0 := randf_range(52.0, 88.0)
	var f1 := f0 * randf_range(0.55, 0.8)
	var b := OfflineSynth.make(dur, RATE)
	for det: float in [-14.0, 9.0]:
		var k := pow(2.0, det / 1200.0)
		var ph := 0.0
		for i in b.size():
			ph = fposmod(ph + f0 * pow(f1 / f0, float(i) / b.size()) * k / RATE, 1.0)
			b[i] += 2.0 * ph - 1.0
	# the closing low-pass (one pole, enough for a saw this low)
	var y := 0.0
	var fc0 := randf_range(260.0, 380.0)
	for i in b.size():
		var u := float(i) / b.size()
		var w := 1.0 - exp(-TAU * fc0 * pow(110.0 / fc0, u) / RATE)
		y += (b[i] - y) * w
		var e := u / 0.4 if u < 0.4 else (1.0 - u) / 0.6
		b[i] = y * e * 0.3
	OfflineSynth.noise(b, RATE, 0.0, {"type": &"bandpass", "f0": 180.0, "f1": 180.0, "q": 1.2, "gain": 0.05, "dur": dur, "attack": dur * 0.4})
	return OfflineSynth.wav(b, RATE)


## a hissing whisper: noise through a narrow high band, chopped like syllables
func _whisper() -> AudioStreamWAV:
	var dur := randf_range(1.2, 2.6)
	var b := OfflineSynth.make(dur + 0.2, RATE)
	var x := 0.0
	var f := randf_range(2200.0, 3800.0)
	while x < dur:
		var sl := randf_range(0.12, 0.3)
		OfflineSynth.noise(b, RATE, x, {"type": &"bandpass", "f0": f, "f1": f * randf_range(0.85, 1.15), "q": randf_range(4.0, 9.0), "gain": randf_range(0.4, 1.0) * 0.5, "dur": sl, "attack": sl * 0.3})
		x += sl + randf_range(0.0, 0.1)
	return OfflineSynth.wav(b, RATE)


## a wet squelch: a few short, falling band-passed noise pops
func _squelch() -> AudioStreamWAV:
	var n := 2 + randi() % 3
	var gap := randf_range(0.07, 0.16)
	var b := OfflineSynth.make(n * gap + 0.2, RATE)
	for i in n:
		OfflineSynth.noise(b, RATE, i * gap, {"type": &"bandpass", "f0": randf_range(900.0, 1700.0), "f1": randf_range(220.0, 420.0), "q": 5.0, "gain": 0.45, "dur": 0.12, "attack": 0.01})
	return OfflineSynth.wav(b, RATE)


## a bubble: a quick rising sine blip (bile)
func _bubble() -> AudioStreamWAV:
	var f := randf_range(140.0, 320.0)
	var b := OfflineSynth.make(0.16, RATE)
	OfflineSynth.tone(b, RATE, 0.0, {"type": &"sine", "f0": f, "f1": f * randf_range(1.6, 2.6), "gain": 0.5, "dur": 0.13, "attack": 0.012})
	return OfflineSynth.wav(b, RATE)


## a very low growl, amplitude-chopped
func _growl() -> AudioStreamWAV:
	var dur := randf_range(1.4, 2.4)
	var f0 := randf_range(48.0, 62.0)
	var f1 := randf_range(34.0, 46.0)
	var am := randf_range(18.0, 30.0)
	var b := OfflineSynth.make(dur, RATE)
	var ph := 0.0
	var y := 0.0
	var w := 1.0 - exp(-TAU * 260.0 / RATE)
	for i in b.size():
		var u := float(i) / b.size()
		ph = fposmod(ph + lerpf(f0, f1, u) / RATE, 1.0)
		y += ((2.0 * ph - 1.0) - y) * w
		var t := float(i) / RATE
		var e := t / 0.4 if t < 0.4 else (dur - t) / (dur - 0.4)
		b[i] = y * (0.55 + 0.45 * sin(TAU * am * t)) * e * 0.4
	return OfflineSynth.wav(b, RATE)


func _heartbeat() -> AudioStreamWAV:
	var b := OfflineSynth.make(0.66, RATE)
	for r: Array in [[0.0, 1.0], [0.3, 0.62]]:
		OfflineSynth.tone(b, RATE, r[0], {"type": &"sine", "f0": 68.0, "f1": 34.0, "gain": r[1], "dur": 0.32, "attack": 0.015})
		OfflineSynth.noise(b, RATE, r[0], {"type": &"lowpass", "f0": 160.0, "f1": 160.0, "q": 0.0, "gain": float(r[1]) * 0.6, "dur": 0.12, "attack": 0.001})
	return OfflineSynth.wav(b, RATE)


func _out(st: AudioStreamWAV, v: float, wet: float = 0.6) -> void:
	_info.k = v * _bus
	_info.pan = randf_range(-0.8, 0.8)
	_info.lp = 20000.0
	Game.sfx._start(st, 1.0, 1.0, wet * 0.55, _info)


func _pick(id: String) -> AudioStreamWAV:
	var a: Array = _bank[id]
	return a[randi() % a.size()]


func _ease_to(cur: float, target: float, tc: float, rd: float) -> float:
	return cur + (target - cur) * (1.0 - exp(-rd / tc))


func update_sound(dt: float, P: Player, time: float) -> void:
	var rd := maxf(Game.frame_real_dt, 0.0001)
	if P == null or dt <= 0.0:
		_bus = _ease_to(_bus, 0.0, 0.3, rd)
	else:
		_bus = _ease_to(_bus, 0.6, 0.8, rd)      # overall level of the ambience bed
	var y := P.y if P != null else 0.0
	var hy := clampf(y / 124.0, 0.0, 1.0)
	var heart := SpireMechs.sstep((y - 44.0) / 9.0) * (1.0 - SpireMechs.sstep((y - 66.0) / 7.0))
	var gut := SpireMechs.sstep((y - 9.0) / 4.0) * (1.0 - SpireMechs.sstep((y - 25.0) / 5.0))
	var gallery := SpireMechs.sstep((y - 64.0) / 5.0) * (1.0 - SpireMechs.sstep((y - 82.0) / 5.0))
	var summit := SpireMechs.sstep((y - 100.0) / 12.0)
	# drone: lower and rounder at the bottom, tighter and darker with height; the breath swells it
	var br := 0.5 + 0.5 * sin(time * TAU / 6.0)
	_drone_f = _ease_to(_drone_f, 95.0 + 70.0 * br + 80.0 * hy + 60.0 * summit, 0.5, rd)
	drone_lp.cutoff_hz = _drone_f + 45.0 * sin(Time.get_ticks_msec() * 0.001 * TAU * 0.07)
	_drone_g = _ease_to(_drone_g, 0.13 + 0.07 * hy + 0.06 * summit, 1.0, rd)
	drone.volume_db = linear_to_db(maxf(_drone_g * _bus, 1e-5))
	_breath_g = _ease_to(_breath_g, 0.012 + 0.05 * br * br + 0.02 * gut, 0.4, rd)
	breath.volume_db = linear_to_db(maxf(_breath_g * _bus / sqrt(1.9), 1e-5))
	_breath_ff = _ease_to(_breath_ff, 360.0 + 380.0 * br + 200.0 * gut, 0.3, rd)
	breath_f.cutoff_hz = _breath_ff
	_rumble_g = _ease_to(_rumble_g, 0.2 + 0.25 * heart + 0.3 * summit, 1.0, rd)
	rumble.volume_db = linear_to_db(maxf(_rumble_g * _bus, 1e-5))
	if P == null or dt <= 0.0:
		return
	# the heart beats in step with the visible beat
	var m := fposmod(time, 1.15)
	if m < _prev_beat:
		Game.sfx.clip(_bank.heart, {"gain": (0.55 + 0.9 * heart + 0.2 * summit) * _bus, "wet": 0.0})
	_prev_beat = m
	var near := 1.0 + 0.6 * summit + 0.3 * gallery
	_next_moan -= dt
	if _next_moan <= 0.0:
		_next_moan = randf_range(7.0, 15.0) / near * (1.0 - 0.3 * hy)
		_out(_pick("moan"), 0.7 + 0.5 * hy + 0.4 * summit, 0.8)
	_next_whisper -= dt
	if _next_whisper <= 0.0:
		_next_whisper = randf_range(25.0, 50.0) / (1.0 + 0.6 * gallery)
		_out(_pick("whisper"), 0.3 + 0.2 * gallery, 1.0)
	_next_growl -= dt
	if _next_growl <= 0.0:
		_next_growl = randf_range(30.0, 70.0)
		_out(_pick("growl"), 0.6 + 0.5 * summit, 0.9)
	_next_squelch -= dt
	if _next_squelch <= 0.0:
		_next_squelch = randf_range(4.0, 10.0) / (1.0 + 0.8 * heart + 0.8 * gut)
		_out(_pick("squelch"), 0.7 + 0.4 * heart, 0.5)
	if gut > 0.05:
		_next_gurgle -= dt
		if _next_gurgle <= 0.0:
			_next_gurgle = randf_range(0.15, 0.7)
			_out(_pick("bubble"), gut, 0.4)
