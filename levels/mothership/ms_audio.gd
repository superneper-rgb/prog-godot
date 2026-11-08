class_name MsAudio
extends Node
## The sound of THE MOTHERSHIP (JS levels/mothership/music.js):
##   THE BAND: 0002pxr's wedding band plays "Do You Have the Right of Way" (assets/sfx/right-of-way.mp3, looped) like a record: mode play -> scratch (a record-scratch, the song winds down to a stop: the toast went wrong) -> panic (the same song, fast: they keep playing because nobody told them to stop) -> off. song_time is where the record is, so the band plays along.
##   the party murmur (until the guests scatter), the beams' hum (louder near a beam), the laundry's machines: synthesized.
## ENGINE DIFFERENCE: the JS's filters run live; here the murmur's moving band is a bus effect, the rest are looped waves rendered through the same filters. A sound's playback speed cannot reach 0: below 0.01 the player pauses.

const SONG := "res://assets/sfx/right-of-way.mp3"
const RATE_ := {"play": 1.0, "panic": 1.18, "scratch": 0.0, "off": 0.0}
const RATE := 24000
const BUS := "MsMurmur"
static var _bank: Dictionary = {}

var mode := "play"
var scratch_t := 0.0
var rate := 1.0
var song_pos := 0.0
var song: AudioStreamPlayer
var _song_dur := 1.0
var _song_g := 0.0
var mur0: AudioStreamPlayer
var mur1: AudioStreamPlayer
var hum: AudioStreamPlayer
var mach: AudioStreamPlayer
var _bp: AudioEffectBandPassFilter
var _g_mur := 0.0
var _g_hum := 0.0
var _g_mach := 0.0
var _bp_f := 480.0
var _t := 0.0
var _buses: Array[StringName] = []
var _k_mur0 := 1.0
var _k_mur1 := 1.0
var _k_mach := 1.0


func _loop(st: AudioStream, bus: StringName = &"SFX") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


## a looped noise on its own bus through a bandpass (JS mkNoise). Peak correction as in DaAudio.
func _noise_track(st: AudioStream, nm: String, f: float, q: float) -> Array:
	AudioServer.add_bus()
	var ix := AudioServer.bus_count - 1
	var bn := StringName(BUS + nm)
	AudioServer.set_bus_name(ix, bn)
	AudioServer.set_bus_send(ix, &"SFX")
	var fx := AudioEffectBandPassFilter.new()
	fx.cutoff_hz = f
	fx.resonance = q * 0.5
	AudioServer.add_bus_effect(ix, fx)
	_buses.append(bn)
	return [_loop(st, bn), fx, 1.0 / sqrt(q + 1.0)]


func _ready() -> void:
	if _bank.is_empty():
		var n0 := OfflineSynth.make(2.0, RATE)
		for i in n0.size():
			n0[i] = randf_range(-1.0, 1.0)
		_bank["noise"] = OfflineSynth.wav(n0, RATE, true)
		# the beam hum: detuned sines (10 s holds a whole number of every wave, so the loop is seamless)
		var h := OfflineSynth.make(10.0, RATE)
		for i in h.size():
			var t := float(i) / RATE
			h[i] = 0.5 * sin(TAU * 110.0 * t) + 0.5 * sin(TAU * 110.7 * t) + 0.25 * sin(TAU * 220.4 * t)
		_bank["hum"] = OfflineSynth.wav(h, RATE, true)
	var m0 := _noise_track(_bank["noise"], "0", 520.0, 1.2)
	mur0 = m0[0]
	_bp = m0[1]
	_k_mur0 = m0[2]
	var m1 := _noise_track(_bank["noise"], "1", 900.0, 2.2)
	mur1 = m1[0]
	_k_mur1 = m1[2]
	var m2 := _noise_track(_bank["noise"], "2", 120.0, 0.8)
	mach = m2[0]
	_k_mach = m2[2]
	hum = _loop(_bank["hum"])
	var st: AudioStream = load(SONG)
	if st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	_song_dur = st.get_length()
	song = _loop(st)


func _exit_tree() -> void:
	for nm: StringName in _buses:
		var ix := AudioServer.get_bus_index(nm)
		if ix >= 0:
			AudioServer.remove_bus(ix)
	_buses.clear()


func _db(p: AudioStreamPlayer, g: float) -> void:
	p.volume_db = linear_to_db(maxf(g, 1e-5))


## per frame: near = {band: distance to the stage, inside, hall, guests: crowd loudness 0..1, beam: distance to the nearest beam, laundry: 0..1}
func update_audio(dt: float, near: Dictionary) -> void:
	_t += dt
	if mode == "scratch":
		scratch_t -= dt
		if scratch_t <= 0.0:
			mode = "panic"
	# the record: rate eases to the mode's speed (a scratch winds it down in a third of a second), the position follows the rate
	var want: float = RATE_.get(mode, 1.0)
	rate += (want - rate) * minf(1.0, dt * (9.0 if mode == "scratch" else 3.0))
	if absf(want - rate) < 0.002:
		rate = want
	song_pos = fmod(song_pos + dt * rate, _song_dur)
	song.stream_paused = rate < 0.01
	song.pitch_scale = maxf(rate, 0.01)
	# only inside the villa; rises smoothly from a murmur across the house to full (but not loud) at the foot of the stage
	var reach := maxf(0.0, 1.0 - maxf(0.0, float(near.band) - 4.0) / 50.0)
	# outside the reception hall the band is barely there (a thump through the walls); stepping into the hall brings it up
	var band_vol := 0.0
	if not (mode == "off" or (mode == "scratch" and rate < 0.05) or not near.inside):
		band_vol = 0.04 + 0.4 * reach * reach if near.hall else 0.006
	var tc: float = 0.05 if mode == "scratch" else (0.6 if near.hall else (0.3 if near.inside else 0.12))
	_song_g += (band_vol - _song_g) * (1.0 - exp(-dt / tc))
	_db(song, _song_g)
	_g_mur += (0.05 * float(near.guests) - _g_mur) * (1.0 - exp(-dt / 0.4))
	_db(mur0, _g_mur * _k_mur0)
	_db(mur1, _g_mur * _k_mur1)
	_bp_f += (480.0 + 120.0 * sin(_t * 1.7) - _bp_f) * (1.0 - exp(-dt / 0.1))
	_bp.cutoff_hz = _bp_f
	_g_hum += (maxf(0.0, 1.0 - float(near.beam) / 7.0) * 0.05 - _g_hum) * (1.0 - exp(-dt / 0.15))
	_db(hum, _g_hum)
	_g_mach += (0.09 * float(near.laundry) - _g_mach) * (1.0 - exp(-dt / 0.5))
	_db(mach, _g_mach * _k_mach)


func set_mode(m: String) -> void:
	if m == "scratch":
		MsSound.play([["noise", 0.0, {"type": &"bandpass", "f0": 2400.0, "f1": 300.0, "q": 3.0, "gain": 0.5, "dur": 0.18}], ["noise", 0.18, {"type": &"bandpass", "f0": 300.0, "f1": 1800.0, "q": 3.0, "gain": 0.3, "dur": 0.14}], ["noise", 0.32, {"type": &"bandpass", "f0": 1800.0, "f1": 200.0, "q": 3.0, "gain": 0.12, "dur": 0.18}]], 0.0)
		scratch_t = 1.6
	mode = m


## where the record is (seconds into the song)
func song_time() -> float:
	return song_pos
