class_name AptAudio
extends Node
## PROG'S APARTMENT: sound (JS levels/apartment/audio.js): city hum through the glass, the fridge, the fluorescent tube's buzz, the TV's hiss, the tap dripping, roaches skittering, a siren now and then, the downpour opening up near a window. Loops are mixed by the player's distance to their source.

const FRIDGE := Vector2(-2.2, 4.1)
const TUBE := Vector2(-4.2, 2.6)
const TV := Vector2(1.2, -2.05)
const WINDOW := Vector2(-2.2, -4.4)
const WINDOW2 := Vector2(3.9, -4.4)
const SINK := Vector2(-4.2, 4.15)

var _city: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _fridge: AudioStreamPlayer
var _buzz: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _rain_fx: AudioEffectLowPassFilter
var _vol := {}
var _tick_t := 0.0
var _siren_t := 8.0 + randf() * 20.0
var _s_tick: AudioStreamWAV
var _s_drip: AudioStreamWAV
var _s_skit: AudioStreamWAV
var _s_siren: AudioStreamWAV


static func _bus(nm: StringName, fx: AudioEffect) -> AudioEffect:
	var i := AudioServer.get_bus_index(nm)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, nm)
		AudioServer.set_bus_send(i, &"SFX")
		AudioServer.add_bus_effect(i, fx)
	return AudioServer.get_bus_effect(i, 0)


func _player(st: AudioStream, bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	return p


static func _sum(partials: Array, rate: int = 22050) -> AudioStreamWAV:
	var b := OfflineSynth.make(1.0, rate)
	for i in b.size():
		var v := 0.0
		var u := float(i) / rate
		for e: Array in partials:
			v += OfflineSynth._wave(e[2], fposmod(u * float(e[0]), 1.0)) * float(e[1])
		b[i] = v
	return OfflineSynth.wav(b, rate, true)


func _ready() -> void:
	name = "AptAudio"
	var noise: AudioStream = load("res://assets/sfx/city/noise.wav")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 320.0
	_bus(&"AptCity", lp)
	var bp := AudioEffectBandPassFilter.new()
	bp.cutoff_hz = 4200.0
	_bus(&"AptHiss", bp)
	var rl := AudioEffectLowPassFilter.new()
	rl.cutoff_hz = 1200.0
	_rain_fx = _bus(&"AptRain", rl) as AudioEffectLowPassFilter
	_city = _player(noise, &"AptCity")
	_hiss = _player(noise, &"AptHiss")
	_fridge = _player(_sum([[58.0, 0.5, &"sine"], [116.0, 0.25, &"sine"], [174.0, 0.08, &"sine"]]), &"SFX")
	_buzz = _player(_sum([[120.0, 0.25, &"sawtooth"]]), &"SFX")
	var rain: AudioStreamMP3 = (load("res://assets/sfx/city-rain.mp3") as AudioStreamMP3).duplicate()
	rain.loop = true
	_rain = _player(rain, &"AptRain")
	var R := 44100
	var t := OfflineSynth.make(0.02, R)
	OfflineSynth.noise(t, R, 0.0, {"type": &"bandpass", "f0": 3800.0, "f1": 3800.0, "q": 2.0, "gain": 0.025, "dur": 0.012})
	_s_tick = OfflineSynth.wav(t, R)
	var d := OfflineSynth.make(0.1, R)
	OfflineSynth.tone(d, R, 0.0, {"type": &"sine", "f0": 1650.0, "f1": 600.0, "gain": 0.05, "dur": 0.09})
	_s_drip = OfflineSynth.wav(d, R)
	var sk := OfflineSynth.make(0.3, R)
	for i in 7:
		OfflineSynth.noise(sk, R, i * 0.035 + randf() * 0.02, {"type": &"highpass", "f0": 5000.0, "f1": 5000.0, "gain": 0.03, "dur": 0.02})
	_s_skit = OfflineSynth.wav(sk, R)
	var si := OfflineSynth.make(4.5, R)
	for i in 4:
		OfflineSynth.tone(si, R, i * 1.1, {"type": &"sine", "f0": 720.0, "f1": 980.0, "gain": 1.0, "dur": 0.55})
		OfflineSynth.tone(si, R, i * 1.1 + 0.55, {"type": &"sine", "f0": 980.0, "f1": 720.0, "gain": 1.0, "dur": 0.55})
	_s_siren = OfflineSynth.wav(si, R)
	for p: AudioStreamPlayer in [_city, _hiss, _fridge, _buzz, _rain]:
		p.play(randf() * 0.5)


static func _near(P: Player, src: Vector2, r: float) -> float:
	return maxf(0.0, 1.0 - U.hyp(P.x - src.x, P.z - src.y) / r)


func _mix(p: AudioStreamPlayer, v: float, dt: float) -> void:
	var cur: float = _vol.get(p, 0.0)
	cur += (v - cur) * (1.0 - exp(-dt / 0.08))
	_vol[p] = cur
	p.volume_db = linear_to_db(maxf(cur * 0.9, 1e-5))


func update(dt: float, P: Player, props: AptProps) -> void:
	if P == null:
		return
	var tube: bool = props.kitchen != null and props.kitchen.light_energy * PI > 1.0
	_mix(_city, 0.05 + 0.1 * _near(P, WINDOW, 7.0), dt)
	_mix(_hiss, 0.012 + 0.05 * _near(P, TV, 6.0) if props.tv_on else 0.0, dt)
	_mix(_fridge, 0.006 + 0.05 * _near(P, FRIDGE, 5.0), dt)
	_mix(_buzz, 0.002 + 0.012 * _near(P, TUBE, 4.5) if tube else 0.0, dt)
	var win := maxf(_near(P, WINDOW, 6.0), _near(P, WINDOW2, 4.5))      # either window
	_mix(_rain, 0.35 + 0.5 * win, dt)
	_rain_fx.cutoff_hz += (1000.0 + 2600.0 * win - _rain_fx.cutoff_hz) * (1.0 - exp(-dt / 0.2))
	_tick_t -= dt      # drops tapping the glass
	while _tick_t <= 0.0:
		_tick_t += 0.04 + randf() * 0.12
		if win > 0.05:
			Game.sfx.clip(_s_tick, {"gain": win * randf() * 0.9, "rate": 0.7 + randf() * 0.8, "wet": 0.05})
	var ev: Dictionary = props.events
	if ev["drip"]:
		Game.sfx.clip(_s_drip, {"gain": (0.25 + 0.75 * _near(P, SINK, 5.0)) * 0.9, "rate": 0.95 + randf() * 0.2, "wet": 0.35})
	if ev["scatter"] != null:
		var at: Vector3 = ev["scatter"]
		Game.sfx.clip(_s_skit, {"gain": (_near(P, Vector2(at.x, at.z), 4.0) + 0.3) * 0.9, "wet": 0.05})
	_siren_t -= dt
	if _siren_t <= 0.0:      # somewhere down there, someone's night is worse
		_siren_t = 25.0 + randf() * 40.0
		Game.sfx.clip(_s_siren, {"gain": (0.012 + 0.01 * _near(P, WINDOW, 8.0)) * 0.9, "wet": 0.6})
