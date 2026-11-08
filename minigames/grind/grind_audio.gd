class_name GrindAudio
extends RefCounted
## RAILJACK's sound (JS RailSynth + the session's song): the baked effects, the grind's two continuous voices and the backing track. It all goes straight to the output on its own bus, as the JS synth goes straight to the destination, past the game's sfx chain.

const FX := "res://assets/sfx/grind/fx/"
const NAMES: Array[String] = ["boot", "type_0", "type_1", "type_2", "beep_0", "beep_1", "hop_r", "hop_l", "shrink", "jump", "land", "link", "eof", "shave", "overdrive", "smash", "mystery", "jackpot", "scrub", "powerup", "hit", "fall", "win", "fail", "alarm", "clear_1", "clear_2", "clear_3", "clear_4", "clear_5", "clear_6", "clear_7", "clear_8", "clear_9", "clear_10", "bit_0", "bit_1", "bit_2", "bit_3", "bit_4", "bit_5", "bit_6", "bit_7"]
const VOICES := 14
static var _bank := {}

var owner: Node = null
var bus: StringName = &"Railjack"
var players: Array[AudioStreamPlayer] = []
var next_p := 0
var lp: AudioEffectLowPassFilter = null
var tone: AudioStreamPlayer = null
var hiss: AudioStreamPlayer = null
var song: AudioStreamPlayer = null
# (setTargetAtTime: value, target, time constant)
var g_v := 0.0
var g_t := 0.0
var ng_v := 0.0
var ng_t := 0.0
var lp_v := 900.0
var lp_t := 900.0
var song_v := 0.0
var song_tc := 0.0
var song_stop := -1.0
var grinding := false


func _init(p_owner: Node) -> void:
	owner = p_owner
	if AudioServer.get_bus_index(&"Railjack") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, &"Railjack")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, &"Master")
	var gi := AudioServer.get_bus_index(&"RailjackGrind")
	if gi < 0:
		AudioServer.add_bus()
		gi = AudioServer.bus_count - 1
		AudioServer.set_bus_name(gi, &"RailjackGrind")
		AudioServer.set_bus_send(gi, &"Railjack")
		var f := AudioEffectLowPassFilter.new()
		f.resonance = 0.65       # (the JS filter's Q of 2.2 dB)
		AudioServer.add_bus_effect(gi, f)
	lp = AudioServer.get_bus_effect(gi, 0) as AudioEffectLowPassFilter
	for i in VOICES:
		var a := AudioStreamPlayer.new()
		a.bus = bus
		owner.add_child(a)
		players.append(a)


static func _stream(id: String) -> AudioStream:
	if not _bank.has(id):
		_bank[id] = load(FX + id + ".wav")
	return _bank[id]


## load everything before the run so the first hop never hitches
static func warm() -> void:
	for n: String in NAMES:
		_stream(n)


func play(id: String) -> void:
	var a := players[next_p]
	next_p = (next_p + 1) % VOICES
	a.stream = _stream(id)
	a.play()


func type() -> void:
	play("type_%d" % randi_range(0, 2))


func beep(hi: bool) -> void:
	play("beep_1" if hi else "beep_0")


func hop(dir: int) -> void:
	play("hop_r" if dir > 0 else "hop_l")


func clear(n: int) -> void:
	play("clear_%d" % mini(10, n))


func bit(n: int) -> void:
	play("bit_%d" % mini(7, n))


func _loop(id: String) -> AudioStreamPlayer:
	var s := (_stream(id) as AudioStreamWAV).duplicate() as AudioStreamWAV
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.get_length() * s.mix_rate
	var a := AudioStreamPlayer.new()
	a.stream = s
	a.volume_db = -80.0
	owner.add_child(a)
	return a


## the grind is a tuned, warm tone (two detuned oscillators through a low-pass, a slow shimmer) with a soft high sizzle on top; it opens up with speed instead of hissing white noise
func start_grind() -> void:
	if grinding:
		return
	grinding = true
	if tone == null:
		tone = _loop("grind_tone")
		tone.bus = &"RailjackGrind"
		hiss = _loop("grind_hiss")
		hiss.bus = bus
	g_v = 0.0
	ng_v = 0.0
	tone.play()
	hiss.play()


func set_grind(on: bool, v: float, boost: float = 0.0) -> void:
	if not grinding:
		return
	g_t = 0.05 + boost * 0.02 if on else 0.0
	lp_t = 700.0 + v * 55.0 + boost * 900.0
	ng_t = 0.010 + boost * 0.012 if on else 0.0


func stop_grind() -> void:
	g_t = 0.0
	ng_t = 0.0
	grinding = false


func start_song(path: String) -> void:
	var s := load(path) as AudioStream
	if s == null:
		push_warning("RAILJACK: track missing " + path)
		return
	if s is AudioStreamMP3:
		s = (s as AudioStreamMP3).duplicate()
		(s as AudioStreamMP3).loop = true
	song = AudioStreamPlayer.new()
	song.stream = s
	song.bus = bus
	song_v = 1.1 * 0.55       # the mp3 plays through the synth's master out (one volume control for music and effects)
	song.volume_db = linear_to_db(song_v)
	owner.add_child(song)
	song.play()


func stop_song(fade: float = 0.8) -> void:
	if song == null or song_stop >= 0.0:
		return
	song_tc = fade / 4.0
	song_stop = fade + 0.1


func update(dt: float) -> void:
	if tone != null:
		g_v += (g_t - g_v) * (1.0 - exp(-dt / 0.04))
		ng_v += (ng_t - ng_v) * (1.0 - exp(-dt / 0.05))
		lp_v += (lp_t - lp_v) * (1.0 - exp(-dt / 0.12))
		lp.cutoff_hz = lp_v
		tone.volume_db = linear_to_db(maxf(g_v, 0.00001))
		hiss.volume_db = linear_to_db(maxf(ng_v, 0.00001))
	if song != null and song_stop >= 0.0:
		song_v *= exp(-dt / song_tc)
		song.volume_db = linear_to_db(maxf(song_v, 0.00001))
		song_stop -= dt
		if song_stop <= 0.0:
			song.stop()
			song.queue_free()
			song = null
			song_stop = -1.0
