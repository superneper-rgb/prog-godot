class_name RapLoop
extends Node
## The trap beat as if it were coming from inside the saucer (JS cutscenes/rap-loop.js), with the car's engine under it. ENGINE DIFFERENCE: the JS picks the track's loudest 8 seconds when it starts; tools/export/render-rap-loop.mjs did that once and this plays its WAV. The JS's oscillators are baked one-cycle loops played at the wanted pitch, its filter and analyser are effects on two session-long buses.

const LOOP := "res://assets/sfx/beatdown-kontraamusic-369.loop.wav"
const BUS := &"RapLoop"
const ENG_BUS := &"RapEngine"
const ENG_BASE_HZ := 100.0      # the pitch the baked cycles play at when pitch_scale is 1

var started := false
var _on := false
var _stop_t := -1.0
var _src: AudioStreamPlayer
var _o: AudioStreamPlayer
var _o2: AudioStreamPlayer
var _bus := -1
var _eng_bus := -1
var _analyser: AudioEffectSpectrumAnalyzerInstance
var _lp: AudioEffectLowPassFilter
var _pan: AudioEffectPanner
var _eng_lp: AudioEffectLowPassFilter
var _out := 0.0
var _muffle := 320.0
var _pan_v := 0.0
var _f := 38.0
var _f2 := 19.0
var _eng_cut := 240.0
var _eng_g := 0.0
var _kick := 0.0
var _low := 0.0
var _last_read := 0


static func _cycle(square: bool) -> AudioStreamWAV:
	var n := int(44100.0 / ENG_BASE_HZ)
	var b := PackedByteArray()
	b.resize(n * 2)
	for i in n:
		var u := float(i) / float(n)
		var v := (1.0 if u < 0.5 else -1.0) if square else 2.0 * u - 1.0
		b.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 44100
	w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


## (bus indices are not ours to shift: session-long buses are made once and never removed)
static func _make_bus(nm: StringName) -> int:
	var i := AudioServer.get_bus_index(nm)
	if i >= 0:
		return i
	AudioServer.add_bus()
	i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, nm)
	AudioServer.set_bus_send(i, &"SFX")
	if nm == BUS:
		var sa := AudioEffectSpectrumAnalyzer.new()
		sa.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_256
		AudioServer.add_bus_effect(i, sa)
		var lp := AudioEffectLowPassFilter.new()
		lp.resonance = pow(10.0, 0.9 / 20.0)      # (Web Audio filter Q is in dB)
		AudioServer.add_bus_effect(i, lp)
		AudioServer.add_bus_effect(i, AudioEffectPanner.new())
	else:
		var lp := AudioEffectLowPassFilter.new()
		lp.resonance = 1.0
		AudioServer.add_bus_effect(i, lp)
	return i


func start() -> void:
	if _on:
		return
	_on = true
	_bus = _make_bus(BUS)
	_eng_bus = _make_bus(ENG_BUS)
	_analyser = AudioServer.get_bus_effect_instance(_bus, 0)
	_lp = AudioServer.get_bus_effect(_bus, 1)
	_pan = AudioServer.get_bus_effect(_bus, 2)
	_eng_lp = AudioServer.get_bus_effect(_eng_bus, 0)
	_out = 0.0
	_muffle = 320.0
	_lp.cutoff_hz = _muffle
	_pan.pan = 0.0
	_eng_lp.cutoff_hz = _eng_cut
	AudioServer.set_bus_volume_db(_bus, -80.0)
	var st: AudioStreamWAV = load(LOOP)
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = int(st.get_length() * st.mix_rate)
	_src = AudioStreamPlayer.new()
	_src.stream = st
	_src.bus = BUS
	add_child(_src)
	_src.play()
	_o = AudioStreamPlayer.new()
	_o.stream = _cycle(false)
	_o.bus = ENG_BUS
	_o.volume_db = -80.0
	add_child(_o)
	_o.play()
	_o2 = AudioStreamPlayer.new()
	_o2.stream = _cycle(true)
	_o2.bus = ENG_BUS
	_o2.volume_db = -80.0
	add_child(_o2)
	_o2.play()
	_last_read = Time.get_ticks_usec()


static func _to(v: float, target: float, dt: float, tc: float) -> float:
	return v + (target - v) * (1.0 - exp(-dt / tc))      # (JS setTargetAtTime)


## JS update(level, muffle, engine, pan), with the frame's dt: the audio graph eased these on its own clock
func mix(dt: float, level: float, muffle: float, engine: float = 0.0, pan: float = 0.0) -> void:
	if not _on:
		return
	_pan_v = _to(_pan_v, clampf(pan, -1.0, 1.0), dt, 0.12)
	_pan.pan = _pan_v
	_out = _to(_out, level, dt, 0.08)
	AudioServer.set_bus_volume_db(_bus, linear_to_db(maxf(_out, 1e-5)))
	_muffle = _to(_muffle, muffle, dt, 0.1)
	_lp.cutoff_hz = _muffle
	_f = _to(_f, 38.0 + engine * 70.0, dt, 0.1)
	_f2 = _to(_f2, 19.0 + engine * 35.0, dt, 0.1)
	_o.pitch_scale = _f / ENG_BASE_HZ
	_o2.pitch_scale = _f2 / ENG_BASE_HZ
	_eng_cut = _to(_eng_cut, 240.0 + engine * 520.0, dt, 0.1)
	_eng_lp.cutoff_hz = _eng_cut
	_eng_g = _to(_eng_g, minf(1.0, level * 1.6) * (0.05 + 0.09 * engine), dt, 0.1)
	var db := linear_to_db(maxf(_eng_g, 1e-5))
	_o.volume_db = db
	_o2.volume_db = db


## The bass in the music, for the car's bounce. (The JS reads bins 1 to 4 of a 256-point FFT at 44.1 kHz, smoothed 0.42, in its byte scale of -100 to -30 dB.)
func kick_env() -> float:
	if not _on or _analyser == null:
		return 0.0
	var m := _analyser.get_magnitude_for_frequency_range(172.0, 862.0, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX)
	var cur := clampf((linear_to_db(maxf(maxf(m.x, m.y), 1e-7)) + 100.0) / 70.0, 0.0, 1.0)
	_low = 0.42 * _low + 0.58 * cur
	var now := Time.get_ticks_usec()
	_kick = maxf(_kick * exp(-maxf(0.0, (now - _last_read) / 1000000.0) * 11.0), minf(1.0, maxf(0.0, (_low - 0.08) * 5.0)))
	_last_read = now
	return _kick


## Fades out and frees itself.
func stop() -> void:
	if not _on:
		queue_free()
		return
	_on = false
	_stop_t = 0.0


func _process(delta: float) -> void:
	if _stop_t < 0.0:
		return
	_stop_t += delta
	_out = _to(_out, 0.0, delta, 0.15)
	AudioServer.set_bus_volume_db(_bus, linear_to_db(maxf(_out, 1e-5)))
	_eng_g = _to(_eng_g, 0.0, delta, 0.15)
	var db := linear_to_db(maxf(_eng_g, 1e-5))
	_o.volume_db = db
	_o2.volume_db = db
	if _stop_t >= 1.1:
		queue_free()
