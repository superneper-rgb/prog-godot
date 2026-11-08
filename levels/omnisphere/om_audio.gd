class_name OmAudio
extends Node
## OMNISPHERE sound (JS audio.js): positional one-shots (explosions, arcs, the gunship), the plant's ambience bed, the alarm loop (follows omni_alarm), the PA announcer (a queue, through a tannoy band-pass and a slap of hall echo, ambient lines when it is quiet), Juniper's voice (dry), two music beds that cross-fade with the action, looping beds and one-off music cues. Files: assets/sfx/omnisphere/.

const DIR := "res://assets/sfx/omnisphere/"
const FILES := {"boomBig": "boom-big", "boom": "boom", "alarm": "alarm", "draw": "draw", "arc": "arc", "gunshipPass": "gunship-pass", "tug": "tug", "groan": "groan", "sparks": "sparks", "splash": "splash", "ambience": "ambience", "kiosk": "kiosk",
	"pa_arrival": "pa-arrival", "pa_draw": "pa-draw", "pa_theft": "pa-theft", "pa_pylon": "pa-pylon", "pa_gondola": "pa-gondola", "pa_gamma": "pa-gamma", "pa_amb1": "pa-amb1", "pa_amb2": "pa-amb2", "pa_amb3": "pa-amb3", "pa_review": "pa-review", "pa_docks": "pa-docks", "pa_drum": "pa-drum", "pa_free": "pa-free", "pa_evac": "pa-evac",
	"jun_hi": "jun-hi", "jun_cuff1": "jun-cuff1", "jun_cuff2": "jun-cuff2", "jun_cuff3": "jun-cuff3", "jun_cuff4": "jun-cuff4", "jun_free": "jun-free", "jun_fall": "jun-fall",
	"musicTension": "music-tension", "musicAction": "music-action",
	"ffWind": "ff-wind", "ffJump": "ff-jump", "ffTugHit": "ff-tug-hit", "ffMissile": "ff-missile", "ffFlak": "ff-flak", "ffDrone": "ff-drone", "ffRam": "ff-ram", "ffJet": "ff-jet", "ffLand": "ff-land", "ffRoll": "ff-roll",
	"pa_tug": "pa-tug", "pa_fall": "pa-fall", "pa_pad": "pa-pad", "musicDrop": "music-drop",
	"liftStart": "lift-start", "liftSnap": "lift-snap", "emVent": "em-vent", "emBlow": "em-blow", "bolt": "bolt", "junSurge": "jun-surge", "sphereGroan": "sphere-groan", "sphereBreak": "sphere-break",
	"lifter": "lifter", "lifterPass": "lifter-pass", "harpoon": "harpoon", "cableWrap": "cable-wrap", "cableTaut": "cable-taut", "implode": "implode", "detonate": "detonate",
	"pa_riser": "pa-riser", "pa_emitter": "pa-emitter", "pa_critical": "pa-critical", "jun_mine": "jun-mine", "jun_oh": "jun-oh", "jun_fly": "jun-fly", "musicOutro": "music-outro", "musicFinale": "music-finale"}
const ALIAS := {"door": "kiosk", "hatch": "kiosk", "steam": "sparks", "alarmShort": "draw"}
const GAIN := {"bolt": 1.6, "emBlow": 1.4, "liftSnap": 1.3, "detonate": 1.7, "implode": 1.4, "sphereBreak": 1.4, "sphereGroan": 1.3, "harpoon": 1.2, "cableTaut": 1.2, "lifterPass": 1.2, "junSurge": 1.1, "ffTugHit": 1.5, "ffMissile": 1.1, "ffFlak": 1.2, "ffJet": 1.1, "ffLand": 1.2, "ffRoll": 0.8, "ffDrone": 0.9, "ffRam": 1.0, "ffJump": 1.0, "boomBig": 1.3, "boom": 1.1, "groan": 1.0, "gunshipPass": 1.2, "tug": 0.9, "splash": 1.1, "sparks": 0.7, "arc": 0.6, "kiosk": 0.8}

var combat := 0.0
var _buses: Array[StringName] = []
var _pa_bus := &"OmPA"
var _music_bus := &"OmMusic"
var _out_bus := &"OmOut"
var _clips := {}
var pa_q: Array = []
var say_q: Array = []
var pa_busy := false
var jun_busy := false
var amb_t := 70.0
var amb_v: AudioStreamPlayer = null
var alarm_v: AudioStreamPlayer = null
var alarm_g := 0.0
var music_t: AudioStreamPlayer = null
var music_a: AudioStreamPlayer = null
var mix := 0.0
var loops := {}      # id -> {v, want, g}
var cue_v: AudioStreamPlayer = null
var cue_fade := -1.0
var cue_g := 1.25
var duck := 0.0
var _beeps := {}


func _ready() -> void:
	_add_bus(_out_bus, &"SFX", 0.5)
	_add_bus(_music_bus, &"SFX", 0.16)
	_add_bus(_pa_bus, _out_bus, 1.15)
	# tannoy: band-pass, a little drive, a short slap echo into the room
	var i := AudioServer.get_bus_index(_pa_bus)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 320.0
	AudioServer.add_bus_effect(i, hp)
	var bp := AudioEffectBandPassFilter.new()
	bp.cutoff_hz = 1500.0
	bp.resonance = 0.35
	AudioServer.add_bus_effect(i, bp)
	var dr := AudioEffectDistortion.new()
	dr.mode = AudioEffectDistortion.MODE_ATAN
	dr.drive = 0.3
	AudioServer.add_bus_effect(i, dr)
	var de := AudioEffectDelay.new()
	de.dry = 1.0
	de.tap1_active = true
	de.tap1_delay_ms = 190.0
	de.tap1_level_db = linear_to_db(0.45)
	de.tap2_active = true
	de.tap2_delay_ms = 380.0
	de.tap2_level_db = linear_to_db(0.45 * 0.32)
	de.feedback_active = false
	AudioServer.add_bus_effect(i, de)


func _add_bus(bn: StringName, send: StringName, g: float) -> void:
	if AudioServer.get_bus_index(bn) >= 0:
		return
	AudioServer.add_bus()
	var ix := AudioServer.bus_count - 1
	AudioServer.set_bus_name(ix, bn)
	AudioServer.set_bus_send(ix, send)
	AudioServer.set_bus_volume_db(ix, linear_to_db(g))
	_buses.append(bn)


func _exit_tree() -> void:
	for nm: StringName in [_pa_bus, _music_bus, _out_bus]:
		var i := AudioServer.get_bus_index(nm)
		if i >= 0:
			AudioServer.remove_bus(i)
	_buses.clear()


func _clip(id: String) -> AudioStream:
	if _clips.has(id):
		return _clips[id]
	var st: AudioStream = null
	if FILES.has(id):
		var path: String = DIR + String(FILES[id]) + ".mp3"
		if ResourceLoader.exists(path):
			st = load(path)
	_clips[id] = st
	return st


func _flat(id: String, g: float, loop: bool, bus: StringName, rate: float = 1.0, offset: float = 0.0) -> AudioStreamPlayer:
	var st := _clip(id)
	if st == null:
		return null
	if loop:
		st = st.duplicate()
		if st is AudioStreamMP3:
			(st as AudioStreamMP3).loop = true
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = bus
	p.pitch_scale = rate
	p.volume_db = linear_to_db(maxf(g, 1e-5))
	add_child(p)
	p.play(offset)
	if not loop:
		p.finished.connect(p.queue_free)
	return p


## a flat one-shot
func play(id: String) -> void:
	var k: String = ALIAS.get(id, id)
	_flat(k, float(GAIN.get(k, 1.0)), false, _out_bus, 0.94 + randf() * 0.12)


## a positional one-shot (distance attenuation: 14 m at full, then falling away, as the JS)
func play_at(id: String, pos: Vector3) -> void:
	var k: String = ALIAS.get(id, id)
	var st := _clip(k)
	if st == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = _out_bus
	p.pitch_scale = 0.94 + randf() * 0.12
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = 14.0
	p.max_distance = 0.0
	p.volume_db = linear_to_db(float(GAIN.get(k, 1.0)))
	add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## queue a PA line (key without the pa_ prefix); urgent lines jump the queue
func pa(key: String, urgent: bool = true) -> void:
	var id := "pa_" + key
	if urgent:
		pa_q.erase(id)
		pa_q.push_front(id)
	elif not pa_q.has(id):
		pa_q.append(id)
	amb_t = 45.0 + randf() * 30.0


## Juniper speaks (key without the jun_ prefix): dry, not through the tannoy; on_start(seconds) fires when the clip actually starts
func say(key: String, on_start: Callable = Callable()) -> void:
	say_q.append({"id": "jun_" + key, "on_start": on_start, "t": 0.0})


## a looping bed at a gain that follows g smoothly (0 lets it die away): the freefall's wind
func loop(id: String, g: float) -> void:
	if not loops.has(id):
		loops[id] = {"v": null, "want": 0.0, "g": 0.0}
	loops[id].want = g


## play a music track once over the beds (they duck under it), from offset s in; cue("", fade) fades it out
func cue(id: String, fade: float = 2.0, offset: float = 0.0) -> void:
	if cue_v != null:
		cue_fade = fade
	else:
		cue_fade = -1.0
	if id == "":
		return
	if cue_v != null:
		cue_v.queue_free()
		cue_fade = -1.0
	cue_v = _flat(id, cue_g, false, _music_bus, 1.0, offset)
	if cue_v != null:
		cue_v.finished.connect(func() -> void: cue_v = null)


## the missile warning: a short square-wave tick (JS freefall.js beep)
func beep(f: float) -> void:
	var key := int(f)
	if not _beeps.has(key):
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = 44100
		var n := int(44100 * .07)
		var d := PackedByteArray()
		d.resize(n * 2)
		for i in n:
			var t := float(i) / 44100.0
			var env := minf(1.0, t / .005) * pow(.0005 / .045, t / .07)
			var v := int((1.0 if fmod(t * f, 1.0) < .5 else -1.0) * .045 * env * 32767.0)
			d.encode_s16(i * 2, v)
		w.data = d
		_beeps[key] = w
	var p := AudioStreamPlayer.new()
	p.stream = _beeps[key]
	p.bus = _out_bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func update_audio(dt: float, alarm_k: float) -> void:
	# ambience bed + alarm loop
	if amb_v == null:
		amb_v = _flat("ambience", 0.55, true, _out_bus)
	if alarm_k > 0.0 and alarm_v == null:
		alarm_v = _flat("alarm", 0.001, true, _out_bus)
		alarm_g = 0.0
	if alarm_v != null:
		alarm_g += ((0.5 if alarm_k > 0.0 else 0.0) - alarm_g) * minf(1.0, dt * 3.0)
		alarm_v.volume_db = linear_to_db(maxf(alarm_g, 1e-5))
		if alarm_k <= 0.0 and alarm_g < 0.01:
			alarm_v.queue_free()
			alarm_v = null
	# Juniper: a line waits for the PA to finish (and holds the PA while he talks); dropped if it has waited too long
	for q: Dictionary in say_q:
		q.t = float(q.t) + dt
	say_q = say_q.filter(func(q: Dictionary) -> bool: return float(q.t) < 14.0)
	if not say_q.is_empty() and not pa_busy and not jun_busy:
		var q: Dictionary = say_q.pop_front()
		var v := _flat(q.id, 1.25, false, _out_bus)
		if v != null:
			jun_busy = true
			v.finished.connect(func() -> void: jun_busy = false)
			if (q.on_start as Callable).is_valid():
				(q.on_start as Callable).call(v.stream.get_length())
	# PA: one line at a time, ambient corporate lines when nothing has been said for a while
	amb_t -= dt
	if amb_t <= 0.0 and pa_q.is_empty():
		pa_q.append(["pa_amb1", "pa_amb2", "pa_amb3"][randi() % 3])
		amb_t = 70.0 + randf() * 40.0
	if not pa_busy and not jun_busy and not pa_q.is_empty():
		var v := _flat(pa_q.pop_front(), 1.0, false, _pa_bus)
		if v != null:
			pa_busy = true
			v.finished.connect(func() -> void: pa_busy = false)
	# music: tension bed always, action bed fades in with the fight
	if music_t == null:
		music_t = _flat("musicTension", 1.0, true, _music_bus)
		music_a = _flat("musicAction", 0.001, true, _music_bus)
	# loops and the music cue
	for id: String in loops:
		var L: Dictionary = loops[id]
		if L.v == null and float(L.want) > 0.001:
			L.v = _flat(id, 0.001, true, _out_bus)
			L.g = 0.0
		if L.v != null:
			L.g = float(L.g) + (float(L.want) - float(L.g)) * minf(1.0, dt * 4.0)
			(L.v as AudioStreamPlayer).volume_db = linear_to_db(maxf(float(L.g), 1e-5))
			if float(L.want) <= 0.001 and float(L.g) < 0.005:
				(L.v as AudioStreamPlayer).queue_free()
				L.v = null
	if cue_v != null and cue_fade > 0.0:
		cue_g = maxf(0.0, cue_g - dt * 1.25 / cue_fade)
		cue_v.volume_db = linear_to_db(maxf(cue_g, 1e-5))
		if cue_g <= 0.0:
			cue_v.queue_free()
			cue_v = null
			cue_fade = -1.0
			cue_g = 1.25
	duck += ((1.0 if cue_v != null else 0.0) - duck) * minf(1.0, dt * 1.5)
	if music_t != null:
		mix += ((1.0 if combat > 0.5 else 0.0) - mix) * minf(1.0, dt * (1.2 if combat > 0.5 else 0.25))
		music_t.volume_db = linear_to_db(maxf(0.8 * (1.0 - mix * 0.85) * (1.0 - duck), 1e-5))
		music_a.volume_db = linear_to_db(maxf(1.1 * mix * (1.0 - duck), 1e-5))
