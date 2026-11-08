class_name VoiceClips
extends Node
## Recorded cutscene dialogue (JS cutscenes/voice-clips.js): plays one clip at a time dry and centred (dialogue, not a world sound), trims its dead air and reports how loud it is, so a speaker's head can move with the words.
## ENGINE DIFFERENCES: Godot cannot read an MP3's samples, so each clip's dead air was measured by tools/export/voice-trim.mjs (assets/sfx/voice_trim.json); level() reads the voice bus's peak instead of an analyser.

const BUS := &"CutsceneVoice"
static var _trims: Dictionary = {}

var files: Dictionary = {}      # key -> res:// path
var who: Variant = null
var _p: AudioStreamPlayer
var _wet: AudioStreamPlayer
var _left := 0.0


## dir: res://assets/sfx/<dir>/, list: { key: file }
func _init(dir: String = "", list: Dictionary = {}) -> void:
	for k: String in list:
		files[k] = dir + String(list[k])


func _ready() -> void:
	name = "VoiceClips"
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, &"SFX")
	_p = AudioStreamPlayer.new()
	_p.bus = BUS
	add_child(_p)
	_wet = AudioStreamPlayer.new()
	_wet.bus = &"Reverb" if AudioServer.get_bus_index(&"Reverb") >= 0 else &"SFX"
	add_child(_wet)
	_load_trims()


static func _load_trims() -> void:
	if not _trims.is_empty():
		return
	var f := FileAccess.open("res://assets/sfx/voice_trim.json", FileAccess.READ)
	if f != null:
		var j: Variant = JSON.parse_string(f.get_as_text())
		if j is Dictionary:
			_trims = j


func _trim_of(k: String) -> Array:
	var path: String = files.get(k, "")
	return _trims.get(path.trim_prefix("res://assets/sfx/"), [0.0, 2.5])


## seconds the clip lasts, dead air cut
func dur(k: String) -> float:
	return float(_trim_of(k)[1])


func speak(k: String, speaker: Variant, wet: float = 0.06, gain: float = 1.15) -> void:
	stop()
	who = speaker
	if not files.has(k):
		return
	var st: AudioStream = load(files[k])
	if st == null:
		return
	var tr := _trim_of(k)
	_p.stream = st
	_p.volume_db = linear_to_db(maxf(gain, 1e-5))
	_p.play(float(tr[0]))
	_left = float(tr[1])
	if wet > 0.0:
		_wet.stream = st
		_wet.volume_db = linear_to_db(maxf(gain * wet, 1e-5))
		_wet.play(float(tr[0]))


func stop() -> void:
	if _p != null:
		_p.stop()
		_wet.stop()
	_left = 0.0
	who = null


func is_speaking() -> bool:
	return _left > 0.0


## 0..1
func level() -> float:
	if _left <= 0.0:
		return 0.0
	var i := AudioServer.get_bus_index(BUS)
	var db := maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))
	return clampf(db_to_linear(db) * 2.4, 0.0, 1.0)      # (a peak is about 2.5 times the RMS the JS multiplies by 6)


func _process(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _left <= 0.0 or not _p.playing:      # cut at the trimmed end, as the JS's trimmed buffer ends
			stop()
