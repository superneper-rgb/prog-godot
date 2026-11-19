class_name UfChaseAudio
extends Node
## The sound of UNDERFOINT's last train (levels/underfoint/uf_chase.gd): the Sigil's voice (lines it shouts during the chase, assets/sfx/underfoint/sigil-*.wav, built by tools/underfoint_audio/),
## its body's noises (roars, snarls, shrieks, footfalls, the hive's moan and its set's whine, beast-*.wav), the train (its run, the flanges on a bend, the horn, a jolt, beast and train both on loops),
## what breaks (crash-*.wav, and OMNISPHERE's own blasts, assets/sfx/omnisphere/), and the chase's music: Hyperreal's "Apocalypse" (CC BY 3.0, assets/music/hyperreal-apocalypse.mp3) played by section.
## The music: it builds for the run on foot, drops on the beat the tunnel mouth comes down, and its loud middle loops (24 bars, 93.69 s .. 138.0 s) for as long as the ride lasts; the release from
## the Sigil's grip jumps it to the run-in to its last hit. A missing file is skipped, so the chase runs before its sounds exist.

const DIR := "res://assets/sfx/underfoint/"
const OMNI := "res://assets/sfx/omnisphere/"
## (2026-11-15: was the MP3. Godot seeks an MP3 by decoding up to the point: 83 ms to jump back to the loop's start every 44 s of the ride, 133 ms to the finale, each a stalled frame.
## The game plays a WAV decoded from it (tools/underfoint_audio/decode.mjs), imported QOA: a jump costs nothing. The MP3 stays as the source the credit names.)
const MUSIC := "res://assets/music/hyperreal-apocalypse.wav"
const DROP := 40.155                   # the music's first drop (bar 1 of its loud part)
const BAR := 1.8462                    # 130 bpm, four beats
const LOOP_A := 93.693
const LOOP_B := 138.001
const FINAL := 150.46                  # three bars before its last big hit

var _clips := {}
var _pool: Array[AudioStreamPlayer3D] = []
var _pool_i := 0
var _flat: Array[AudioStreamPlayer] = []
var _flat_i := 0
var _loops := {}                        # key -> [player, want_db, now_db]
var _voice: AudioStreamPlayer3D
var _voice_t := 0.0
var _music: Array[AudioStreamPlayer] = []
var _m_cur := 0
var _m_fade := 0.0
var _m_looping := false
var _m_on := false
var _m_level := 0.0
var volume := 0.85:                     # Game.music's slider
	set(v):
		volume = clampf(v, 0.0, 1.0)
var ducked := false


func _init() -> void:
	name = "UfChaseAudio"
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 14.0
		p.max_db = 6.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_pool.append(p)
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_flat.append(p)
	_voice = AudioStreamPlayer3D.new()
	_voice.bus = &"SFX"
	_voice.unit_size = 60.0
	_voice.max_db = 8.0
	_voice.attenuation_filter_cutoff_hz = 20000.0
	add_child(_voice)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	if ResourceLoader.exists(MUSIC):
		var st := load(MUSIC) as AudioStream
		for m in _music:
			m.stream = st


## a sound by name: one of the chase's own, or OMNISPHERE's (its name with "omni:" in front). null if it is not there.
func clip(key: String) -> AudioStream:
	if _clips.has(key):
		return _clips[key]
	var path := ""
	if key.begins_with("omni:"):
		path = OMNI + key.substr(5) + ".mp3"
	else:
		path = DIR + key + ".wav"
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_clips[key] = st
	return st


## all of them now, so the first roar does not wait on the disk
func warm(keys: Array) -> void:
	for k: String in keys:
		clip(k)


func play_at(key: String, at: Vector3, db: float = 0.0, pitch: float = 1.0) -> void:
	var st := clip(key)
	if st == null:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = st
	p.global_position = at
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## a sound with no place: the train's own, what happens to the car
func sfx(key: String, db: float = 0.0, pitch: float = 1.0) -> void:
	var st := clip(key)
	if st == null:
		return
	var p := _flat[_flat_i]
	_flat_i = (_flat_i + 1) % _flat.size()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## The Sigil says something: out of its body if there is one (the voice goes with it), else flat. Returns how long it speaks (0: nothing to play).
func say(key: String, at: Node3D) -> float:
	var st := clip(key)
	if st == null:
		return 0.0
	if at != null:
		if _voice.get_parent() != at:
			_voice.reparent(at, false)
		_voice.position = Vector3(0.0, 8.0, 2.0)
	_voice.stream = st
	_voice.volume_db = 4.0
	_voice.play()
	_voice_t = st.get_length()
	return _voice_t


func speaking() -> bool:
	return _voice.playing


## A loop that runs while the chase does: on a node (it goes with it), its level and pitch set every frame by set_loop
func loop(key: String, on: Node3D, offset: Vector3 = Vector3.ZERO) -> void:
	if _loops.has(key):
		return
	var st := clip(key)
	if st == null:
		return
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	var p := AudioStreamPlayer3D.new()
	p.bus = &"SFX"
	p.unit_size = 20.0
	p.max_db = 6.0
	p.stream = st
	p.volume_db = -60.0
	p.position = offset
	on.add_child(p)
	p.play()
	_loops[key] = [p, -60.0, -60.0]


func set_loop(key: String, db: float, pitch: float = 1.0) -> void:
	if not _loops.has(key):
		return
	var q: Array = _loops[key]
	q[1] = db
	(q[0] as AudioStreamPlayer3D).pitch_scale = maxf(0.05, pitch)


func stop_loops() -> void:
	for k: String in _loops:
		var q: Array = _loops[k]
		var p: AudioStreamPlayer3D = q[0]
		if is_instance_valid(p):
			p.queue_free()
	_loops.clear()


# ---- the music --------------------------------------------------------------------------------------------------------------------------------------------------------------

## Start (or jump) the music at `at` seconds: the new section comes in over `fade` while the old one goes
func music(at: float, fade: float = 0.08) -> void:
	if _music[0].stream == null:
		return
	var old := _music[_m_cur]
	_m_cur = 1 - _m_cur
	var p := _music[_m_cur]
	p.volume_db = -80.0 if fade > 0.0 else 0.0
	p.play(maxf(0.0, at))
	_m_fade = fade
	_m_on = true
	if old.playing:
		old.set_meta(&"out", fade)


## loop the loud middle while the ride needs more of it (off: let it run on to its end)
func music_loop(on: bool) -> void:
	_m_looping = on


func music_pos() -> float:
	var p := _music[_m_cur]
	return p.get_playback_position() if p.playing else -1.0


func music_stop(fade: float = 1.5) -> void:
	_m_on = false
	for m in _music:
		if m.playing:
			m.set_meta(&"out", fade)


func duck(v: bool) -> void:
	ducked = v


## (Game.music's play(): the chase's music is started by the chase, by section; nothing to resume here)
func play() -> void:
	pass


func _process(delta: float) -> void:
	# the voice's own clock (it speaks over everything)
	_voice_t = maxf(0.0, _voice_t - delta)
	# (user 2026-11-13: "that whirring sound when you pause or die can be awful on the ears". The train's run, the flanges' screech and the Sigil's set whine are loops this node keeps playing
	# while the game is paused, and nothing was turning them down: paused or dead, they held whatever level they had, the screech included. Now they fall silent, and come back when play does.)
	var hush := Game.paused or (Game.player != null and Game.player.dead)
	for k: String in _loops:
		var q: Array = _loops[k]
		var p: AudioStreamPlayer3D = q[0]
		q[2] = move_toward(float(q[2]), -60.0 if hush else float(q[1]), delta * (240.0 if hush else 60.0))
		p.volume_db = q[2]
		p.stream_paused = hush and float(q[2]) <= -59.0
	# the music: the section coming in, the one going out, the loop
	_m_level += ((volume * (0.25 if ducked else 1.0) if _m_on else 0.0) - _m_level) * (1.0 - exp(-delta / 0.3))
	var lvl := linear_to_db(maxf(_m_level, 1e-5))
	for i in 2:
		var m := _music[i]
		if not m.playing:
			continue
		if m.has_meta(&"out"):
			var f: float = m.get_meta(&"out")
			var k := clampf(db_to_linear(m.volume_db) - delta / maxf(f, 0.01), 0.0, 1.0)
			m.volume_db = linear_to_db(maxf(k, 1e-5))
			if k <= 0.001:
				m.stop()
				m.remove_meta(&"out")
			continue
		if i == _m_cur:
			if _m_fade > 0.0:
				var k := clampf(db_to_linear(m.volume_db - lvl) + delta / _m_fade, 0.0, 1.0)
				m.volume_db = lvl + linear_to_db(maxf(k, 1e-5))
				if k >= 1.0:
					_m_fade = 0.0
			else:
				m.volume_db = lvl
	var cur := _music[_m_cur]
	if _m_looping and cur.playing and cur.get_playback_position() >= LOOP_B - 0.02:
		music(LOOP_A + (cur.get_playback_position() - LOOP_B), 0.04)
