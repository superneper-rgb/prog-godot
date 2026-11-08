class_name MusicTrack
extends AudioStreamPlayer
## A level's own music (JS createClubMusic and friends): one stream on the Music bus with the same volume / duck interface, so the pause menu's slider and duck work on any track.
## Created by the level, under the level node: leaving the level ends it.

var volume := 1.0:
	set(v):
		volume = clampf(v, 0.0, 1.0)
var ducked := false
var _level := 0.0


func _init(st: AudioStream = null, vol: float = 1.0) -> void:
	stream = st
	volume = vol
	bus = &"Music"
	volume_db = -80.0
	process_mode = Node.PROCESS_MODE_ALWAYS


func duck(value: bool) -> void:
	ducked = value


func _process(delta: float) -> void:
	# (JS bus.gain.setTargetAtTime(volume * (ducked ? 0.2 : 1), now, 0.25))
	_level += (volume * (0.2 if ducked else 1.0) - _level) * (1.0 - exp(-delta / 0.25))
	volume_db = linear_to_db(maxf(_level, 1e-5))
