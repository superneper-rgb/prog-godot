class_name Sfx
extends Node
## All sound (JS class Sfx, index.html audio.js). The JS synthesises live in Web Audio; here every s_<id> graph is a rendered WAV (tools/export/render-sfx.mjs, listed in audio/sfx_bank.gd).
## Same names: play(id, o), play_at(id, x, y, z, o) (JS at), clip, clip_at, ambient_set, ambient_tick, crt_hum, ad_play, speak, cut_voice, load_voices, voice_buf, menu_sound.
## Dry and wet are two voices: the dry one goes to SFX (or a pooled per-voice bus with the JS pan and distance low-pass), the same file goes to the Reverb bus at the send level measured from the JS graph.
## ENGINE DIFFERENCE: the JS builds a filter + panner per sound; Godot routes a stream to one bus, so spatial sounds take one of SPATIAL_VOICES pooled voices, each with its own bus, created once at boot.

const BANK: Dictionary = SfxBank.BANK
var play_from: Player = null      # while an AI clone's events play, plain sounds come from him (JS clone.spatialSfx)
const SYNTH := "res://assets/sfx/synth/"
const SPATIAL_VOICES := 32         # voices with their own pan + low-pass bus; the one ending soonest is stolen when they run out (the JS has no limit, its fights peak around 15)
const VOICE_BUSES := [&"SFX", &"Voice"]
const UI_SOUNDS := {"wheelOpen": "open", "wheelClose": "close", "tick": "nav", "vendOpen": "open", "vendClose": "close", "vendNav": "nav", "vendBuy": "buy", "vendDeny": "deny", "vendInfo": "confirm", "uiMove": "nav", "uiConfirm": "confirm", "uiBack": "close"}
const EQUIP_HEAVY: Array[float] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.7, 0.8, 0.9, 1.0]
const SPLASH_K: Array[float] = [0.15, 0.3, 0.5, 0.75, 1.0]
const YOKE_K: Array[float] = [0.6, 1.0, 1.3, 1.6]
const VEH_POP_K: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]
const VEH_CRASH_K: Array[float] = [0.25, 0.5, 0.75, 1.0]
const VOICE_RANGE := 30.0          # AI.voiceRange
const AD_RATE := 0.86              # (the rendered files are already at this rate; kept for the length of the opening squelch + chime)
const AD_RENDER_VOL := 0.36        # the adverts were rendered at the straight-at-the-listener level

## One pooled spatial voice: an AudioStreamPlayer on its own bus (low-pass, panner), set up at fire time. The JS builds the same chain per sound.
class SpatialVoice:
	var player: AudioStreamPlayer
	var bus_idx := 0
	var panner: AudioEffectPanner
	var lp: AudioEffectLowPassFilter
	var send_voice := false
	var reserved := false          # a loop or a long held voice: never stolen
	var end := -1.0                # Sfx.now when this one-shot is over
	var tag := -1                  # who speaks through it (cut_voice)
	var level := 1.0               # dry linear level, for fades
	var fade_at := -1.0            # Sfx.now when a scripted fade-out starts
	var fade_len := 0.0

	func is_free(now: float) -> bool:
		return not reserved and now >= end

	func stop_now() -> void:
		player.stop()
		end = -1.0
		fade_at = -1.0
		tag = -1

## One looping world sound (JS _buildAmbient's result, the advert's world mode): a reserved voice whose level and pan ease toward the distance every frame.
class Ambient:
	var id := ""
	var pos := Vector3.ZERO
	var voice: SpatialVoice
	var range_m := 15.0
	var vol := 0.085
	var cur := 0.0                 # smoothed linear level
	var pan := 0.0
	var stopping := -1.0           # > 0: fading out, seconds left
	var stop_from := 0.0
	var t := 0.0

## Result of _mk_bus: what the JS bus node would apply to the sound.
class BusInfo:
	var k := 0.0
	var d := 0.0
	var pan := 0.0
	var lp := 20000.0

## A scheduled syllable (JS tone / _voice calls at t + i * step).
class Sched:
	var t := 0.0
	var key := ""
	var gain := 1.0
	var pitch := 1.0
	var bus: BusInfo = null
	var tag := -1

var vol := 0.8:                    # the master level (JS sfx.vol = 0.8, in front of the compressor)
	set(v):
		vol = v
		if _amp != null:
			_amp.volume_db = linear_to_db(maxf(v, 0.0001))
var listener_x := 0.0              # JS sfx.listener, set every frame from the camera
var listener_y := 0.0
var listener_z := 0.0
var listener_yaw := 0.0
var voice_buf := {}                # JS sfx.voiceBuf: decoded clips by key
var music: MusicTrack = null       # a level's own track, the pause menu's slider sets its volume (JS `music`)
var enemy_audio: RobotAudio = null # JS sfx.enemyAudio
var now := 0.0                     # seconds since boot (the audio clock of cooldowns and fades)
var stats_on := false              # tests: count what plays, per rendered key
var stats := {}

var _amp: AudioEffectAmplify = null
var _poly_sfx: AudioStreamPlaybackPolyphonic
var _poly_voice: AudioStreamPlaybackPolyphonic
var _poly_wet: AudioStreamPlaybackPolyphonic
var _voices: Array[SpatialVoice] = []
var _streams := {}                 # key -> Array of takes, loaded on first use or by warm()
var _warm_keys: Array = []         # keys still to load in the background
var _warm_wait: Array = []         # [key, path] being loaded
var _warm_held: Array = []
var warmed := false                # every take is in memory
var _last_take := {}
var _timed: Array = []             # [poly playback, id, level, end time, fade length] of clips with a duration
var _fading: Array[SpatialVoice] = []
var _sched: Array[Sched] = []
var _amb := {}                     # JS _amb: id -> Ambient
var _amb_out: Array[Ambient] = []  # fading out
var _ad: Ambient = null            # JS _ad
var _ad_wet: AudioStreamPlayer = null
var _ad_end := 0.0
var _ad_last := -1
var _ad_loaded := false
var _ui_nav_at := -1e9
var _pause_tone_at := -1e9
var _voices_by_id := {}            # JS voices: speech id -> tag
var _next_tag := 1
var _winds := {}                   # creature kind -> rendered wind-up lengths
var _rk := ""                      # _resolve's answer
var _rg := 1.0
var _rp := 1.0
var _bus := BusInfo.new()          # scratch for one-shots: _mk_bus returns this unless it must outlive the call
# crt_hum
var _hum: AudioStreamPlayer = null
var _hum_on := false
var _hum_level := 0.03
var _hum_ramp := 0.0
var _hum_t := 0.0
# the swarm's held-fire layers (JS _sw)
var _sw_a: AudioStreamPlayer = null
var _sw_l: AudioStreamPlayer = null
var _sw_l_wet: AudioStreamPlayer = null
var _sw_tail: AudioStreamPlayer = null
var _sw_end := -9.0
var _sw_t0 := -9.0
var _sw_active := false
var _sw_tail_rate := 1.7
var _sw_tail_fade := -1.0


func _ready() -> void:
	name = "Sfx"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sfx_i := AudioServer.get_bus_index(&"SFX")
	if sfx_i < 0:
		push_error("Sfx: default_bus_layout.tres has no SFX bus")
		return
	_amp = AudioServer.get_bus_effect(sfx_i, 0) as AudioEffectAmplify
	vol = vol
	_poly_sfx = _polyphonic(&"SFX")
	_poly_voice = _polyphonic(&"Voice")
	_poly_wet = _polyphonic(&"Reverb")
	for i in SPATIAL_VOICES:
		var v := SpatialVoice.new()
		AudioServer.add_bus()
		v.bus_idx = AudioServer.bus_count - 1
		var bname := StringName("SV%d" % i)
		AudioServer.set_bus_name(v.bus_idx, bname)
		AudioServer.set_bus_send(v.bus_idx, &"SFX")
		v.lp = AudioEffectLowPassFilter.new()
		v.lp.resonance = 1.122        # Web Audio lowpass Q is in dB: Q 1 dB = 1.122 linear
		v.lp.cutoff_hz = 20000.0
		v.panner = AudioEffectPanner.new()
		AudioServer.add_bus_effect(v.bus_idx, v.lp)
		AudioServer.add_bus_effect(v.bus_idx, v.panner)
		v.player = AudioStreamPlayer.new()
		v.player.bus = bname
		add_child(v.player)
		_voices.append(v)
	_hum = _plain_player(&"SFX")
	_sw_a = _plain_player(&"SFX")
	_sw_l = _plain_player(&"SFX")
	_sw_l_wet = _plain_player(&"Reverb")
	_sw_tail = _plain_player(&"SFX")
	_ad_wet = _plain_player(&"Reverb")
	for key: String in BANK:
		if key.begins_with("clip."):
			voice_buf[key.substr(5)] = null        # filled on first use: voice_clip()
		elif key.begins_with("creature.") and key.contains(".wind-"):
			var parts := key.split(".")
			var kind := parts[1]
			if not _winds.has(kind):
				_winds[kind] = PackedFloat32Array()
			var a: PackedFloat32Array = _winds[kind]
			a.append(float(key.substr(key.find("wind-") + 5)))
			_winds[kind] = a
	enemy_audio = RobotAudio.new(self)
	_warm_keys = BANK.keys()


func _polyphonic(bus: StringName) -> AudioStreamPlaybackPolyphonic:
	var p := AudioStreamPlayer.new()
	var s := AudioStreamPolyphonic.new()
	s.polyphony = 128
	p.stream = s
	p.bus = bus
	add_child(p)
	p.play()
	return p.get_stream_playback() as AudioStreamPlaybackPolyphonic


func _plain_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


## Load the rendered takes on worker threads after boot, a batch at a time, so a first play never touches the disk (loading all 1749 synchronously costs seconds). A sound played before its turn just loads itself.
func _warm_tick() -> void:
	if _warm_keys.is_empty() and _warm_wait.is_empty():
		return
	while _warm_wait.size() < 32 and not _warm_keys.is_empty():
		var key: String = _warm_keys.pop_back()
		if _streams.has(key):
			continue
		var b: Dictionary = BANK[key]
		for i in int(b.n):
			var path := SYNTH + key + "_" + str(i) + ".wav"
			ResourceLoader.load_threaded_request(path, "AudioStreamWAV", false, ResourceLoader.CACHE_MODE_REUSE)
			_warm_wait.append([key, path])
	for i in range(_warm_wait.size() - 1, -1, -1):
		var q: Array = _warm_wait[i]
		var st := ResourceLoader.load_threaded_get_status(q[1])
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_warm_held.append(ResourceLoader.load_threaded_get(q[1]))     # (held so the cache keeps it until _takes asks for it)
		_warm_wait.remove_at(i)
	if _warm_keys.is_empty() and _warm_wait.is_empty():
		warmed = true


## Load every rendered take now (a test, or a level that wants a prefix ready before it starts).
func warm(prefixes: PackedStringArray = PackedStringArray()) -> void:
	for key: String in BANK:
		if prefixes.is_empty():
			_takes(key)
		else:
			for pre in prefixes:
				if key.begins_with(pre):
					_takes(key)
					break


func _takes(key: String) -> Array:
	var a: Array = _streams.get(key, [])
	if not a.is_empty():
		return a
	var b: Dictionary = BANK.get(key, {})
	var n: int = b.get("n", 0)
	for i in n:
		var st := load(SYNTH + key + "_" + str(i) + ".wav") as AudioStreamWAV
		if st == null:
			push_error("Sfx: missing " + key + "_" + str(i) + ".wav")
			continue
		a.append(st)
	_streams[key] = a
	return a


## JS sfx.voiceBuf[key]: a prepared recorded clip (rendered under clip.<key>) or anything load_voices loaded.
func voice_clip(key: String) -> AudioStream:
	var st: AudioStream = voice_buf.get(key)
	if st == null and BANK.has("clip." + key):
		var a := _takes("clip." + key)
		if not a.is_empty():
			st = a[0]
			voice_buf[key] = st
	return st


## JS loadVoices: { key: "assets/x.mp3" }. .m4a files were decoded to .wav next to themselves. Clips the JS prepares (trim, peak) were rendered prepared, under clip.<key>: those win.
func load_voices(map: Dictionary) -> int:
	var n := 0
	for key: String in map:
		if BANK.has("clip." + key):
			if voice_clip(key) != null:
				n += 1
			continue
		var p := str(map[key]).replace(".m4a", ".wav")
		if not p.begins_with("res://"):
			p = "res://" + p
		var st := load(p) as AudioStream
		if st == null:
			push_warning("Audio unavailable: " + key)
			continue
		voice_buf[key] = st
		n += 1
	return n


# ---------------------------------------------------------------- the one-shot paths ----------------------------------------------------------------

## JS play(id, o): the id's rendered take at the JS level. UI ids go to menu_sound first, exactly as in the JS.
func play(id: String, o: Dictionary = {}) -> void:
	if play_from != null:      # (JS clone.spatialSfx.play)
		var o2 := {"range": 40.0}
		o2.merge(o, true)
		play_at(id, play_from.x, play_from.y + 1.0, play_from.z, o2)
		return
	var ui: String = UI_SOUNDS.get(id, "")
	if ui != "":
		menu_sound(ui)
		return
	if id == "smg" and _swarm_shot(null):
		return
	_resolve(id, o)
	if _rk != "":
		_fire(_rk, _rg, _rp, null, -1)


## JS at(id, x, y, z, o): play from a world position. Returns true when it was in range (the JS returns the bus; creature audio tests it). Range 45 and ref 5 by default.
func play_at(id: String, x: float, y: float, z: float, o: Dictionary = {}) -> bool:
	var bus := _mk_bus(x, y, z, float(o.get("range", 45.0)), float(o.get("ref", 5.0)), _bus)
	if bus == null:
		return false
	var ui: String = UI_SOUNDS.get(id, "")
	if ui != "":
		menu_sound(ui, bus)
		return true
	if not o.has("dist"):
		o = o.duplicate()
		o["dist"] = bus.d
	_resolve(id, o)
	if _rk != "":
		_fire(_rk, _rg, _rp, bus, -1)
	return true


## JS _mkBus: the distance attenuation, low-pass and pan of a world sound; null when out of range or too quiet.
func _mk_bus(x: float, y: float, z: float, range_m: float, ref: float, out: BusInfo) -> BusInfo:
	var dx := x - listener_x
	var dy := y - listener_y
	var dz := z - listener_z
	var d := sqrt(dx * dx + dy * dy + dz * dz)
	if d > range_m:
		return null
	var k := minf(1.2, 1.7 / (1.0 + (d / ref) * (d / ref))) * (1.0 - (d / range_m) * (d / range_m))
	if k < 0.012:
		return null
	var h := sqrt(dx * dx + dz * dz)
	if h == 0.0:
		h = 1.0
	out.k = k
	out.d = d
	out.lp = maxf(1000.0, 15000.0 / (1.0 + d * 0.16))
	out.pan = clampf((-cos(listener_yaw) * dx + sin(listener_yaw) * dz) / h, -1.0, 1.0) * minf(1.0, d / 2.5) * 0.85
	return out


func _pick_take(key: String, n: int) -> int:
	if n <= 1:
		return 0
	var t := randi() % n
	if t == int(_last_take.get(key, -1)):
		t = (t + 1 + randi() % (n - 1)) % n
	_last_take[key] = t
	return t


func _fire(key: String, gain: float, pitch: float, bus: BusInfo, tag: int, voice := false) -> void:
	var b: Dictionary = BANK.get(key, {})
	if b.is_empty():
		push_warning("Sfx: no sound '" + key + "'")
		return
	if stats_on:
		stats[key] = int(stats.get(key, 0)) + 1
	var a := _takes(key)
	if a.is_empty():
		return
	var take := _pick_take(key, a.size())
	var p := pitch
	if b.has("j"):
		p *= 1.0 + (randf() - 0.5) * 0.03    # the JS rolls _j() = 1 +- 0.04 per partial on every shot: the takes hold spread j values, this fills the gaps
	var gs: Array = b.gs
	_start(a[take], gain * float(gs[take]), p, float(b.s), bus, tag, voice)


## Start one stream: dry voice + send voice. JS _out: send = wet * min(1, 2 k) in the world (no distance filter on the tail), wet at full level otherwise.
func _start(st: AudioStream, g: float, p: float, send: float, bus: BusInfo, tag := -1, voice := false) -> SpatialVoice:
	if g <= 0.0:
		return null
	var v: SpatialVoice = null
	if bus == null:
		(_poly_voice if voice else _poly_sfx).play_stream(st, 0.0, linear_to_db(g), p)
		if send > 0.003:
			_poly_wet.play_stream(st, 0.0, linear_to_db(g * send), p)
	else:
		v = _acquire()
		_arm(v, st, g * bus.k, p, bus.pan, bus.lp, tag, voice)
		var w := send * minf(1.0, bus.k * 2.0)
		if w > 0.003:
			_poly_wet.play_stream(st, 0.0, linear_to_db(g * w), p)
	return v


func _acquire() -> SpatialVoice:
	var best: SpatialVoice = null
	for v: SpatialVoice in _voices:
		if v.reserved:
			continue
		if now >= v.end:
			return v
		if best == null or v.end < best.end:
			best = v
	return best


## Point a voice at a stream, with the JS level, pan and low-pass. StereoPanner law for a mono source: L = cos(th), R = sin(th), th = (pan + 1) * pi / 4, so pan 0 is -3 dB each side.
## Godot's AudioEffectPanner keeps L + R constant, so the equal-power gains become a panner setting plus a gain on the voice.
func _arm(v: SpatialVoice, st: AudioStream, level: float, pitch: float, pan: float, lp_hz: float, tag: int, voice := false) -> void:
	var stereo := st is AudioStreamWAV and (st as AudioStreamWAV).stereo
	var g := level
	if stereo:
		v.panner.pan = signf(pan) * (1.0 - cos(absf(pan) * PI * 0.5))     # (the JS stereo path: the near side stays, the far side folds over)
	else:
		var th := (pan + 1.0) * PI * 0.25
		var lg := cos(th)
		var rg := sin(th)
		g *= (lg + rg) * 0.5
		v.panner.pan = (rg - lg) / (rg + lg)
	v.lp.cutoff_hz = lp_hz
	if v.send_voice != voice:
		v.send_voice = voice
		AudioServer.set_bus_send(v.bus_idx, &"Voice" if voice else &"SFX")
	v.player.stream = st
	v.player.volume_db = linear_to_db(maxf(g, 1e-5))
	v.player.pitch_scale = pitch
	v.level = g
	v.tag = tag
	v.fade_at = -1.0
	v.end = now + st.get_length() / maxf(pitch, 0.05)
	v.player.play()


# ---------------------------------------------------------------- id + options -> rendered key ----------------------------------------------------------------

func _nearest(a: Array[float], x: float) -> float:
	var best := a[0]
	for v in a:
		if absf(v - x) < absf(best - x):
			best = v
	return best


## The JS passes options into the graph; the render made one file per value the game uses. _rk = key ("" = silent), _rg = gain for options that only scale every partial, _rp = pitch.
func _resolve(id: String, o: Dictionary) -> void:
	_rk = id
	_rg = 1.0
	_rp = 1.0
	match id:
		"brass":
			if o.get("big", false):
				_rk = "brass.big"
		"empty":
			var w := str(o.get("id", ""))
			if w == "deagle" or w == "smg" or w == "sniper" or w == "rocket":
				_rk = "empty." + w
		"whoosh", "punchHit":
			if o.get("stage", 0) == 3:
				_rk = id + ".3"
		"splash":
			_rk = "splash." + _gkey(_nearest(SPLASH_K, float(o.get("k", 0.6))))
		"stroke":
			_rg = float(o.get("k", 0.7))
		"rung":
			_rg = float(o.get("k", 1.0))
		"land":
			var lk := float(o.get("k", 0.0))
			_rg = minf(1.6, 0.4 + (lk if lk != 0.0 else 0.5))
		"slap", "skitter", "step":
			var sk := float(o.get("k", 0.0))
			_rg = sk if sk != 0.0 else 0.6
		"playerHurt", "bellowsHit":
			var pk := float(o.get("k", 0.0))
			_rg = pk if pk != 0.0 else 1.0
		"equip":
			var he := float(o.get("heavy", 0.0))
			_rk = "equip." + _gkey(_nearest(EQUIP_HEAVY, he if he != 0.0 else 0.5))
		"sawPing":
			var n := int(o.get("n", 0))
			_rk = "sawPing." + str(clampi(n if n != 0 else 1, 1, 12))
		"yokeImpact":
			var yk := float(o.get("k", 0.0))
			_rk = "yokeImpact." + _gkey(_nearest(YOKE_K, yk if yk != 0.0 else 1.0))
		"flailSlam":
			var fk := float(o.get("k", 0.0))
			if fk != 0.0 and fk < 0.9:
				_rk = "flailSlam.0.8"
		"explode":
			_rg = maxf(0.5, 1.0 - float(o.get("dist", 0.0)) / 60.0)
		"clang", "alienHit", "humanHit", "meatHit":
			if o.get("heavy", false):
				_rk = id + ".heavy"
		"meatDie":
			if o.get("small", false):
				_rk = "meatDie.small"
		"wormGrow":
			if o.get("quiet", false):
				_rk = "wormGrow.quiet"
		"tongueLash":
			if o.get("hit", false):
				_rk = "tongueLash.hit"
		"shieldHit", "shieldBreak", "shieldUp":
			if o.get("hi", false):
				_rk = id + ".hi"
		"boltHit":
			var bk := str(o.get("bk", ""))
			var pl: bool = str(o.get("kind", "")) == "player"
			match bk:
				"plasma":
					_rk = "boltHit.plasma.player" if pl else "boltHit.plasma"
				"mind":
					_rk = "boltHit.mind"
				"dart":
					_rk = "boltHit.dart"
				"ring":
					_rk = "boltHit.ring"
				"sauce":
					_rk = "boltHit.sauce.player" if pl else "boltHit.sauce"
				_:
					_rk = "boltHit.player" if pl else "boltHit"
		"wind":
			_rk = "wind.shot" if str(o.get("kind", "")) == "shot" else "wind.melee"
		"vehPop":
			_rk = "vehPop." + _gkey(_nearest(VEH_POP_K, float(o.get("k", 0.0))))
		"vehCrash":
			var vk := float(o.get("k", 0.0))
			_rk = "vehCrash." + _gkey(_nearest(VEH_CRASH_K, vk if vk != 0.0 else 0.5))
		"rl":
			_resolve_rl(o)
		"creature":
			_resolve_creature(o)
		"alienSyl":
			var h := int(o.get("h", 0)) & 0xffffff
			_rk = "alienSyl.%d.%d" % [h % 6, (h >> 3) % 8] + (".last" if o.get("last", false) else "")
			_rp = float(o.get("pitch", 1.0))
		"dogSyl":
			var h2 := int(o.get("h", 0)) & 0xffffff
			_rk = "dogSyl.%d.%d" % [h2 % 5, (h2 >> 3) % 7] + (".last" if o.get("last", false) else "")
			_rp = float(o.get("pitch", 1.0))


func _gkey(v: float) -> String:              # the rendered key spells numbers the way JS String(number) does
	return str(int(v)) if v == float(int(v)) else str(v)


## JS _rlArmory + s_rl: which phases of which weapon make a sound. A phase that made no sound has no bank entry, so it plays nothing.
func _resolve_rl(o: Dictionary) -> void:
	var w := str(o.get("id", ""))
	var ph := str(o.get("ph", ""))
	match w:
		"deagle", "smg", "sniper", "rocket", "shotgun":
			_rk = "rl." + w + "." + ph
		"rifle":
			_rk = "" if ph == "chamber" and not o.get("emp", false) else "rl.rifle." + ph     # a partial reload keeps the round in the chamber: no charging-handle sound
		_:
			_rk = "rl.other." + ph
	if _rk != "" and not BANK.has(_rk):
		_rk = ""


## CreatureAudio's s_creature: cue + kind; a wind-up takes the rendered length nearest the attack's real wind-up.
func _resolve_creature(o: Dictionary) -> void:
	var kind := str(o.get("kind", ""))
	var cue := str(o.get("cue", ""))
	_rk = "creature." + kind + "." + cue
	var dur := float(o.get("dur", 0.0))
	if cue == "wind" and dur > 0.0 and _winds.has(kind):
		var a: PackedFloat32Array = _winds[kind]
		var best := -1.0
		for w in a:
			if best < 0.0 or absf(w - dur) < absf(best - dur):
				best = w
		if best > 0.0 and absf(best - dur) < 0.2:
			_rk = "creature." + kind + ".wind-" + _gkey(snappedf(best, 0.01))


# ---------------------------------------------------------------- clips ----------------------------------------------------------------

## JS clip: a decoded interface or voice clip through the main bus. o: gain, rate, duration, fade (0.06), offset, wet (0.04).
func clip(st: AudioStream, o: Dictionary = {}) -> void:
	if st == null:
		return
	var level := float(o.get("gain", 1.0))
	var rate := float(o.get("rate", 1.0))
	var wet := float(o.get("wet", 0.04))
	var pb := _poly_voice if o.get("voice", false) else _poly_sfx
	var dur := float(o.get("duration", 0.0))
	var off := float(o.get("offset", 0.0)) if dur > 0.0 else 0.0
	var id := pb.play_stream(st, off, linear_to_db(maxf(level, 1e-5)), rate)
	if wet > 0.0:
		_poly_wet.play_stream(st, off, linear_to_db(maxf(level * wet, 1e-5)), rate)
	if dur > 0.0:
		_timed.append([pb, id, level, now + dur, minf(float(o.get("fade", 0.06)), dur)])


## JS clipAt: same falloff and pan as play_at. o: range (35), ref (4), rate, gain, wet (0.08), duration, fade (0.025). Returns the voice, so a caller can stop_now() it, or null out of range.
func clip_at(st: AudioStream, x: float, y: float, z: float, o: Dictionary = {}) -> SpatialVoice:
	if st == null:
		return null
	var bus := _mk_bus(x, y, z, float(o.get("range", 35.0)), float(o.get("ref", 4.0)), _bus)
	if bus == null:
		return null
	var level := float(o.get("gain", 1.0))
	var v := _start(st, level, float(o.get("rate", 1.0)), float(o.get("wet", 0.08)), bus, -1, o.get("voice", false))
	var dur := float(o.get("duration", 0.0))
	if v != null and dur > 0.0:
		var fade := minf(float(o.get("fade", 0.025)), dur)
		v.fade_at = now + dur - fade
		v.fade_len = fade
		v.end = now + dur
		_fading.append(v)
	return v


# ---------------------------------------------------------------- menu sounds ----------------------------------------------------------------

## JS menuSound: rendered with the clip it layers. Only the thinning of very fast navigation happens here.
func menu_sound(kind: String, bus: BusInfo = null) -> void:
	var ms := now * 1000.0
	if kind == "pauseNav":
		if ms - _pause_tone_at < 70.0:
			return
		_pause_tone_at = ms
	elif kind == "nav":
		if ms - _ui_nav_at < 65.0:
			return
		_ui_nav_at = ms
	_fire("menu." + kind, 1.0, 1.0, bus, -1)


# ---------------------------------------------------------------- the swarm's held fire ----------------------------------------------------------------

## JS s_smg with the recorded burst: held fire = attack -> seamless loop; letting go (or running dry) plays the tail. Every shot pushes the fade-out of the held layers back.
func _swarm_shot(_bus_unused: BusInfo) -> bool:
	if not BANK.has("swarm.attack"):
		return false
	var t := now
	if t > _sw_end:                                   # a new burst
		if _sw_tail.playing:
			_sw_tail_fade = 0.15                      # (setTargetAtTime(0, t, 0.02), stop at t + 0.15)
		var a: Array = _takes("swarm.attack")
		var l: Array = _takes("swarm.loop")
		_sw_a.stream = a[0]
		_sw_a.volume_db = linear_to_db(_sw_g("attack"))
		_sw_a.play()
		_sw_l.stream = l[0]
		_sw_l_wet.stream = l[0]
		_sw_t0 = t
		_sw_active = true
		_poly_wet.play_stream(a[0], 0.0, linear_to_db(_sw_g("attack") * 0.08), 1.0)
	_sw_end = t + 0.1
	var combat = Game.combat
	var empty: bool = combat != null and combat.ammo.size() > 3 and combat.ammo[3] <= 1      # ran dry: a brisk wind-down; let go early: an even snappier one
	_sw_tail_rate = 1.25 if empty else 1.7
	return true


## A swarm layer's level: 0.38 in the JS graph, WEAPON_MIX_TRIM.smg = 0.68, and the file's own normalisation.
func _sw_g(part: String) -> float:
	var b: Dictionary = BANK["swarm." + part]
	var gs: Array = b.gs
	return 0.38 * 0.68 * float(gs[0])


func _swarm_tick(dt: float) -> void:
	if _sw_tail_fade > 0.0:
		_sw_tail_fade -= dt
		_sw_tail.volume_db -= dt * 400.0              # (20 ms time constant)
		if _sw_tail_fade <= 0.0:
			_sw_tail.stop()
	if not _sw_active:
		return
	var t := now
	var since := t - _sw_t0
	if since >= 0.4 and not _sw_l.playing and t < _sw_end + 0.06:
		_sw_l.play()
		_sw_l_wet.play()
	var layer := clampf(1.0 - (t - _sw_end) / 0.06, 0.0, 1.0)       # 1 until the last shot + 0.1 s, then a 60 ms fade
	var ramp := clampf((since - 0.4) / 0.05, 0.0, 1.0)              # the loop eases in under the attack's end
	if _sw_l.playing:
		_sw_l.volume_db = linear_to_db(maxf(_sw_g("loop") * ramp * layer, 1e-5))
		_sw_l_wet.volume_db = linear_to_db(maxf(_sw_g("loop") * 0.08 * ramp * layer, 1e-5))
	_sw_a.volume_db = linear_to_db(maxf(_sw_g("attack") * layer, 1e-5))
	if t >= _sw_end:                                                 # no shot for 0.1 s: the tail starts
		if not _sw_tail.playing or _sw_tail_fade > 0.0:
			var tl: Array = _takes("swarm.tail")
			if not tl.is_empty() and t < _sw_end + dt + 0.001:
				_sw_tail_fade = -1.0
				_sw_tail.stream = tl[0]
				_sw_tail.pitch_scale = _sw_tail_rate
				_sw_tail.volume_db = linear_to_db(_sw_g("tail"))
				_sw_tail.play()
				_poly_wet.play_stream(tl[0], 0.0, linear_to_db(_sw_g("tail") * 0.08), _sw_tail_rate)
	if t > _sw_end + 0.1:
		_sw_a.stop()
		_sw_l.stop()
		_sw_l_wet.stop()
		_sw_active = false


# ---------------------------------------------------------------- CRT hum, ambients, adverts ----------------------------------------------------------------

## JS crtHum: faint hum while the terminal wheel is up: fades in over 0.45 s with a 0.8 Hz wobble of 23 %, out over 0.25 s.
func crt_hum(on: bool, level := 0.03) -> void:
	_hum_on = on
	if on:
		_hum_level = level
		_hum_ramp = 0.0
		if not _hum.playing:
			var a: Array = _takes("hum.crt")
			if a.is_empty():
				return
			_hum.stream = a[0]
			_hum.play()


func _hum_tick(dt: float) -> void:
	if not _hum.playing:
		return
	_hum_t += dt
	if _hum_on:
		_hum_ramp = minf(1.0, _hum_ramp + dt / 0.45)
	else:
		_hum_ramp -= dt / 0.25
		if _hum_ramp <= 0.0:
			_hum.stop()
			return
	var b: Dictionary = BANK["hum.crt"]
	var gs: Array = b.gs
	_hum.volume_db = linear_to_db(maxf(float(gs[0]) * (_hum_level * _hum_ramp + _hum_level * 0.23 * sin(_hum_t * TAU * 0.8)), 1e-5))


## JS ambientSet(id, pos | null, on): a loop that lives at a spot in the world, louder and panned by the listener. pos == null or on == false stops it (fades 0.3 s).
func ambient_set(id: String, pos: Variant, on: bool) -> void:
	var a: Ambient = _amb.get(id)
	if on and pos != null and a == null:
		_amb[id] = _build_ambient(id, pos)
	elif a != null and (not on or pos == null):
		_amb.erase(id)
		a.stopping = 0.3
		a.stop_from = a.cur
		_amb_out.append(a)
	elif a != null and pos != null:
		a.pos = pos


func _build_ambient(id: String, pos: Vector3) -> Ambient:
	var a := Ambient.new()
	a.id = id
	a.pos = pos
	a.voice = _acquire()
	a.voice.reserved = true
	a.t = 0.0
	var loop: Array = _takes("amb.vending")
	if not loop.is_empty():
		_arm(a.voice, loop[0], 0.0, 1.0, 0.0, 20000.0, -1)
	return a


## JS ambientTick, called every frame from _process. Level = vol * k^2, k = 1 - d / range, eased with a 0.12 s time constant; the swell of the compressor is the slow 0.075 Hz cycle of the JS graph.
func ambient_tick(dt: float) -> void:
	var kk := 1.0 - exp(-dt / 0.12)
	var gs: Array = (BANK.get("amb.vending", {"gs": [1.0]}) as Dictionary).gs
	var g0 := float(gs[0])
	for id: String in _amb:
		var a: Ambient = _amb[id]
		_amb_place(a, kk, g0, 0.12, dt)
	for i in range(_amb_out.size() - 1, -1, -1):
		var a := _amb_out[i]
		a.stopping -= dt
		a.t += dt
		var lvl: float = a.stop_from * maxf(0.0, a.stopping / 0.3)
		_amb_level(a, lvl, g0)
		if a.stopping <= 0.0:
			a.voice.reserved = false
			a.voice.stop_now()
			_amb_out.remove_at(i)
	if _ad != null and _ad.pos != Vector3.INF:
		var gsa := 1.0                             # (the file's own gain was applied when the advert started)
		_amb_place(_ad, 1.0 - exp(-dt / 0.1), gsa, 0.1, dt)
		_ad_wet.volume_db = linear_to_db(maxf(_ad.cur * float(_ad.stop_from), 1e-5))


func _amb_place(a: Ambient, kk: float, g0: float, _tc: float, dt: float) -> void:
	var dx := a.pos.x - listener_x
	var dz := a.pos.z - listener_z
	var dy := a.pos.y - listener_y
	var d := sqrt(dx * dx + dy * dy + dz * dz)
	var k := maxf(0.0, 1.0 - d / a.range_m)
	a.cur += (a.vol * k * k - a.cur) * kk
	var hz := sqrt(dx * dx + dz * dz)
	if hz == 0.0:
		hz = 1.0
	var rx := -cos(listener_yaw)
	var rz := sin(listener_yaw)
	var want := clampf((dx / hz) * rx + (dz / hz) * rz, -0.85, 0.85) * minf(1.0, d / 3.0)
	a.pan += (want - a.pan) * kk
	a.t += dt
	_amb_level(a, a.cur, g0)


func _amb_level(a: Ambient, lvl: float, g0: float) -> void:
	var cyc := 1.0
	if a != _ad:
		cyc = 0.72 + 0.28 * sin(a.t * TAU * 0.075)
	var th := (a.pan + 1.0) * PI * 0.25
	var lg := cos(th)
	var rg := sin(th)
	a.voice.panner.pan = (rg - lg) / (rg + lg)
	a.voice.player.volume_db = linear_to_db(maxf(lvl * cyc * g0 * (lg + rg) * 0.5, 1e-5))


## JS adLoad: the adverts ship as rendered files, so this only says they may play.
func ad_load(_urls: Variant = null) -> void:
	_ad_loaded = true


func ad_ready() -> bool:
	return _ad_loaded and BANK.has("ad.0")


func ad_playing() -> bool:
	return _ad != null


## JS adPlay(pos): a random advert (not the last) from a spot in the world (pos = {x, y, z} or Vector3), or straight at the listener (pos == null). Through the cheap speaker chain, rendered in.
func ad_play(pos: Variant = null) -> bool:
	if not ad_ready():
		return false
	ad_stop()
	var ok: Array[int] = []
	for i in 3:
		if BANK.has("ad.%d" % i):
			ok.append(i)
	var pool: Array[int] = []
	if ok.size() > 1:
		for i in ok:
			if i != _ad_last:
				pool.append(i)
	else:
		pool = ok
	var idx: int = pool[randi() % pool.size()]
	_ad_last = idx
	var key := "ad.%d" % idx
	var t: Array = _takes(key)
	var b: Dictionary = BANK[key]
	var gs: Array = b.gs
	var a := Ambient.new()
	a.id = "ad"
	a.voice = _acquire()
	a.voice.reserved = true
	a.range_m = 30.0
	a.vol = 0.26 if pos != null else 0.36
	a.pos = pos if pos != null else Vector3.INF
	var file_g := float(gs[0]) / AD_RENDER_VOL      # the file at volume 1
	_arm(a.voice, t[0], 0.0, 1.0, 0.0, 20000.0, -1)
	if pos == null:                                 # straight at the listener: a mono source through the panner at 0 keeps -3 dB like the JS panner
		a.voice.player.volume_db = linear_to_db(0.36 * file_g * 0.7071)
		a.voice.panner.pan = 0.0
	a.stop_from = float(b.s) * file_g
	a.cur = 0.0
	_ad_wet.stream = t[0]
	_ad_wet.volume_db = linear_to_db(maxf(0.36 * a.stop_from, 1e-5)) if pos == null else -80.0
	_ad_wet.play()
	_ad = a
	_ad_end = now + float(b.len)
	# the world level is applied per frame with g0 = file_g
	a.t = file_g
	return true


## JS adStop: cuts it (a 0.12 s fade).
func ad_stop() -> void:
	var a := _ad
	if a == null:
		return
	_ad = null
	_ad_wet.stop()
	a.voice.reserved = false
	a.voice.fade_at = now
	a.voice.fade_len = 0.12
	a.voice.level = db_to_linear(a.voice.player.volume_db)
	a.voice.end = now + 0.12
	_fading.append(a.voice)


# ---------------------------------------------------------------- the gadgets' looping voices ----------------------------------------------------------------

## JS Gadgets._voice(type, f, lp): a looping oscillator through a fixed low-pass, straight to the master; gain and frequency are set per frame. key is loop.disc, loop.charge, loop.well, loop.arc, loop.arc2.
func voice_start(key: String, lp_hz: float) -> SpatialVoice:
	var t := _takes(key)
	if t.is_empty():
		return null
	var v := _acquire()
	v.reserved = true
	v.tag = -1
	v.lp.cutoff_hz = lp_hz
	v.panner.pan = 0.0
	v.player.stream = t[0]
	v.player.volume_db = -80.0
	v.player.pitch_scale = 1.0
	v.fade_at = -1.0
	v.end = 1e18
	v.player.play()
	return v


func voice_set(v: SpatialVoice, key: String, freq: float, gain: float) -> void:
	if v == null:
		return
	var b: Dictionary = BANK[key]
	var gs: Array = b.gs
	v.player.pitch_scale = maxf(0.05, freq / float(b.base))
	v.level = gain * float(gs[0])
	v.player.volume_db = linear_to_db(maxf(v.level, 1e-5))


## JS Gadgets._kill: setTargetAtTime(0, now, 0.03), stop 0.2 s later.
func voice_kill(v: SpatialVoice) -> void:
	if v == null:
		return
	v.reserved = false
	v.fade_at = now
	v.fade_len = 0.1
	v.end = now + 0.1
	_fading.append(v)


# ---------------------------------------------------------------- speech ----------------------------------------------------------------

## JS speak(e): robot dialogue: a loaded clip for the line key, else the grays' own tongue, else the babble. e: x y z key text dur id kind pitch speech.
func speak(e: Dictionary) -> void:
	var bus := _mk_bus(float(e.x), float(e.y), float(e.z), VOICE_RANGE + 6.0, 4.0, BusInfo.new())
	if bus == null:
		return
	var tag := _next_tag
	_next_tag += 1
	var buf: AudioStream = voice_clip(str(e.get("key", "")))
	if buf != null:
		_start(buf, 1.0, 0.9 + float(e.pitch) * 0.15, 0.1, bus, tag, true)
	elif e.get("speech", false):
		_gray_tongue(e, bus, tag)
	else:
		_babble(e, bus, tag)
	_voices_by_id[e.get("id", 0)] = tag


## JS cutVoice: the line stops: pending syllables are dropped, sounding ones fade fast.
func cut_voice(id: Variant) -> void:
	if not _voices_by_id.has(id):
		return
	var tag: int = _voices_by_id[id]
	_voices_by_id.erase(id)
	for i in range(_sched.size() - 1, -1, -1):
		if _sched[i].tag == tag:
			_sched.remove_at(i)
	for v: SpatialVoice in _voices:
		if v.tag == tag and v.player.playing:
			v.level = db_to_linear(v.player.volume_db)
			v.fade_at = now
			v.fade_len = 0.06
			v.end = now + 0.06
			_fading.append(v)


func _queue(at: float, key: String, gain: float, pitch: float, bus: BusInfo, tag: int) -> void:
	var s := Sched.new()
	s.t = now + at
	s.key = key
	s.gain = gain
	s.pitch = pitch
	s.bus = bus
	s.tag = tag
	_sched.append(s)


## JS _grayTongue: hashed syllables of the line (the same line always sounds the same) in a low throat voice, a theremin-like whine gliding under it (rising on alerts, sinking on a death rattle).
func _gray_tongue(e: Dictionary, bus: BusInfo, tag: int) -> void:
	var txt := str(e.get("text", "x"))
	if txt == "":
		txt = "x"
	var letters := 0
	for i in txt.length():
		var c := txt.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			letters += 1
	var n := clampi(roundi(letters / 3.2), 2, 12)
	var step := minf(0.15, float(e.get("dur", 1.0)) / n)
	var kind := str(e.get("kind", ""))
	var kp := 1.3 if kind == "pain" else 1.12 if kind == "alert" else 0.85 if kind == "mind" else 1.0
	var base := (0.78 + (float(e.get("pitch", 1.0)) - 0.55) * 2.0) * kp
	var h := 2166136261
	for i in n:
		for j in 3:
			h = _imul(h ^ txt.unicode_at((i * 3 + j) % txt.length()), 16777619)
		var hh := h & 0xffffff
		var syl_p := base * (1.0 - 0.5 * (float(i) / n) if kind == "die" else 1.0)
		var key := "alienSyl.%d.%d" % [hh % 6, (hh >> 3) % 8] + (".last" if i == n - 1 else "")
		_queue(i * step, key, 1.0, syl_p, bus, tag)
	var L := n * step + 0.12
	var w_key := "whine.die." if kind == "die" else "whine."
	w_key += "0.5" if L < 0.75 else "1" if L < 1.3 else "1.6"
	_queue(0.0, w_key, 0.08 / 0.035 if kind == "mind" else 1.0, base, bus, tag)


func _imul(a: int, b: int) -> int:           # Math.imul on 32 bits
	return ((a & 0xffffffff) * (b & 0xffffffff)) & 0xffffffff


## JS _babble: robotic syllables shaped by the line length (not speech): the subtitles carry the words.
func _babble(e: Dictionary, bus: BusInfo, tag: int) -> void:
	var text := str(e.get("text", ""))
	var n := maxi(2, roundi(text.length() / 2.8))
	var step := float(e.get("dur", 1.0)) / n
	var base := 118.0 * float(e.get("pitch", 1.0))
	var kind := str(e.get("kind", ""))
	var id := int(e.get("id", 0))
	for i in n:
		var slide := 1.0 - 0.55 * (float(i) / n) if kind == "die" else 1.0
		var f := base * slide * (1.0 + 0.22 * sin(i * 1.9 + id) + (0.2 if kind == "alert" else 0.0))
		_queue(i * step, "babble.%d" % ((i * 3 + id) % 5), 1.0, f / 118.0, bus, tag)
	_queue(0.0, "babble.click", 1.0, 1.0, bus, tag)


# ---------------------------------------------------------------- the frame ----------------------------------------------------------------

## Listener from the camera (JS frame(): sfx.listener = { x, y, z, yaw: atan2(d.x, d.z) }), fades, the scheduled syllables, loops.
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	now += delta
	_warm_tick()
	var cam: Camera3D = Game.camera
	if cam != null:
		var o := cam.global_position
		var d := -cam.global_transform.basis.z
		listener_x = o.x
		listener_y = o.y
		listener_z = o.z
		listener_yaw = atan2(d.x, d.z)
	if not _sched.is_empty():
		for i in range(_sched.size() - 1, -1, -1):
			var s := _sched[i]
			if now >= s.t:
				_sched.remove_at(i)
				_fire(s.key, s.gain, s.pitch, s.bus, s.tag, true)
	if not _timed.is_empty():
		for i in range(_timed.size() - 1, -1, -1):
			var q: Array = _timed[i]
			var left: float = q[3] - now
			var pb: AudioStreamPlaybackPolyphonic = q[0]
			if left <= 0.0:
				pb.stop_stream(q[1])
				_timed.remove_at(i)
			elif left < q[4]:
				pb.set_stream_volume(q[1], linear_to_db(maxf(float(q[2]) * left / float(q[4]), 1e-5)))
	if not _fading.is_empty():
		for i in range(_fading.size() - 1, -1, -1):
			var v := _fading[i]
			if v.fade_at < 0.0:
				_fading.remove_at(i)
			elif now >= v.fade_at + v.fade_len:
				v.stop_now()
				_fading.remove_at(i)
			elif now >= v.fade_at:
				v.player.volume_db = linear_to_db(maxf(v.level * (1.0 - (now - v.fade_at) / v.fade_len), 1e-5))
	_hum_tick(dt)
	_swarm_tick(dt)
	ambient_tick(dt)
	if _ad != null and now >= _ad_end:
		var a := _ad
		_ad = null
		a.voice.reserved = false
		a.voice.stop_now()
		_ad_wet.stop()


## A level is being swapped out: its sounds end with it (the JS level scope stops what the level started).
func clear_level() -> void:
	for id: String in _amb.keys():
		ambient_set(id, null, false)
	ad_stop()
	crt_hum(false)
	_sched.clear()
	if enemy_audio != null:
		enemy_audio.reset()


## JS updatePlayerFootsteps: one footfall per half of the leg cycle, a variant different from the last, quieter when crouched. The boot's heel thump and equipment tick are rendered into the foot.* takes.
var _player_footstep_t := 0.0
var _player_footstep_variant := -1


func update_player_footsteps(dt: float, player: Player) -> void:
	var speed: float = player.speed()
	if player.dead or not player.grounded or player.mode != &"normal" or speed < 0.8:
		_player_footstep_t = 0.0
		return
	var run: bool = player.sprinting or speed >= Config.run_speed * 0.7
	_player_footstep_t += minf(dt, 0.05)
	var interval := PI / (5.0 + speed * 0.55)        # one footfall per half of the leg animation cycle
	while _player_footstep_t >= interval:
		_player_footstep_t -= interval
		var variant := randi() % 3
		if variant == _player_footstep_variant:
			variant = (variant + 1 + randi() % 2) % 3
		_player_footstep_variant = variant
		var level := (0.055 if player.crouching else 0.17 if run else 0.105) * 0.46 * (0.92 + randf() * 0.16)
		_fire("foot.%s.%d" % ["run" if run else "walk", variant], level, 0.96 + randf() * 0.08, null, -1)
