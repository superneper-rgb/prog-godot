class_name ArenaAudio
extends RefCounted
## FOINT DOME's sound (JS commentary.js, ambience.js, machinery-audio.js): the announcer over a small overdriven PA, the crowd and hum bed, and the motors that follow the bullpens' real movement.

const COMMENTARY_LINES: Array[String] = ["real-fointer", "participation", "backwards", "potential", "sponsor", "confidence", "committee", "fointless", "mother", "strategy", "manners", "career", "replay", "safety", "footwork", "refund", "professional", "improving", "permission", "champion", "crowd", "goint", "sincere", "standards", "hot-mic", "company-motto"]


static func _bus(nm: StringName) -> int:
	var i := AudioServer.get_bus_index(nm)
	if i >= 0:
		return i
	AudioServer.add_bus()
	i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, nm)
	AudioServer.set_bus_send(i, &"SFX")
	return i


static func _allowed(level: FointDomeLevel) -> bool:
	return Game.level == level and Game.started


## A small overdriven speaker, heard across the arena through its PA echoes. Web Audio: highpass 380, tanh curve (drive 2.8), lowpass 3300, then direct 0.68 + echo 165 ms (feedback 0.28, lowpass 2300, wet 0.34), all x 0.58.
class Commentary:
	extends Node
	const BUS := &"ArenaPA"
	var level: FointDomeLevel
	var player: AudioStreamPlayer
	var bag: Array[String] = []
	var last_id := ""
	var wait := 8.0 + randf() * 4.0
	var tail := 0.0
	var held := false
	var held_at := 0.0

	func _init(p_level: FointDomeLevel) -> void:
		level = p_level
		var fresh := AudioServer.get_bus_index(BUS) < 0
		var i := ArenaAudio._bus(BUS)
		if fresh:
			var h := AudioEffectHighPassFilter.new()
			h.cutoff_hz = 380.0
			AudioServer.add_bus_effect(i, h)
			var d := AudioEffectDistortion.new()
			d.mode = AudioEffectDistortion.MODE_OVERDRIVE
			d.drive = 0.45
			d.pre_gain = 0.0
			d.post_gain = 0.0
			d.keep_hf_hz = 16000.0
			AudioServer.add_bus_effect(i, d)
			var l := AudioEffectLowPassFilter.new()
			l.cutoff_hz = 3300.0
			AudioServer.add_bus_effect(i, l)
			var e := AudioEffectDelay.new()
			e.dry = 0.68
			e.tap1_active = true
			e.tap1_delay_ms = 165.0
			e.tap1_level_db = linear_to_db(0.34)
			e.tap2_active = false
			e.feedback_active = true
			e.feedback_delay_ms = 165.0
			e.feedback_level_db = linear_to_db(0.28)
			e.feedback_lowpass = 2300.0
			AudioServer.add_bus_effect(i, e)
			AudioServer.set_bus_volume_db(i, linear_to_db(0.58))
		player = AudioStreamPlayer.new()
		player.bus = BUS
		player.finished.connect(_ended)
		add_child(player)
		bag.assign(COMMENTARY_LINES.slice(1))
		bag.shuffle()
		bag.push_front(COMMENTARY_LINES[0])

	func _ended() -> void:
		tail = 1.5
		wait = 22.0 + randf() * 16.0

	var speaking: bool:
		get:
			return player.playing or held or tail > 0.0

	func _can_start() -> bool:
		var st := level.director.state
		return not Game.player.dead and not Game.menu_open() and not Game.wheel.is_open and not level.tv.active and (st == &"fight" or st == &"between")

	func _speak() -> void:
		if bag.is_empty():
			bag.assign(COMMENTARY_LINES)
			bag.shuffle()
			if bag[0] == last_id:
				var a := bag[0]
				bag[0] = bag[1]
				bag[1] = a
		var id := bag[0]
		var st: AudioStream = load("res://assets/sfx/foint-commentary/%s.mp3" % id)
		if st == null:      # a missing clip stays silent; never substitute another voice
			wait = 25.0
			return
		player.stream = st
		player.play()
		bag.pop_front()
		last_id = id

	func update(dt: float) -> void:
		if not ArenaAudio._allowed(level):
			if player.playing or held:
				player.stop()
				held = false
			wait = maxf(wait, 8.0)
			return
		if Game.paused:
			if player.playing:
				held_at = player.get_playback_position()
				held = true
				player.stop()
			return
		if held:
			held = false
			player.play(held_at)
		if player.playing:
			return
		var elapsed := clampf(dt, 0.0, 0.1)
		if tail > 0.0:
			tail -= elapsed
		if not _can_start():
			wait = maxf(wait, 8.0)
			return
		wait -= elapsed
		if wait <= 0.0:
			_speak()


## The crowd and hum: one quiet bed through a lowpass, down while the announcer speaks or between events.
class Ambience:
	extends Node
	const BUS := &"ArenaBed"
	var level: FointDomeLevel
	var crowd: AudioStreamPlayer
	var hum: AudioStreamPlayer
	var gain := 0.0

	func _init(p_level: FointDomeLevel) -> void:
		level = p_level
		var fresh := AudioServer.get_bus_index(BUS) < 0
		var i := ArenaAudio._bus(BUS)
		if fresh:
			var l := AudioEffectLowPassFilter.new()
			l.cutoff_hz = 4200.0
			AudioServer.add_bus_effect(i, l)
		crowd = _loop("crowd")
		hum = _loop("hum")

	func _loop(id: String) -> AudioStreamPlayer:
		var st: AudioStreamMP3 = load("res://assets/sfx/foint-ambience/%s.mp3" % id)
		st.loop = true
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.bus = BUS
		add_child(p)
		return p

	func update(dt: float) -> void:
		var live: bool = ArenaAudio._allowed(level) and not Game.paused and not Game.menu_open() and not Game.wheel.is_open
		if not live:
			if crowd.playing:
				crowd.stop()
				hum.stop()
			gain = 0.0
			return
		if not crowd.playing:
			crowd.play()
			hum.play()
		var st := level.director.state
		var active := st == &"fight" or st == &"between"
		var want := (1.0 if active else 0.42) * (0.45 if level.commentary.speaking else 1.0)
		gain += (want - gain) * (1.0 - exp(-clampf(dt, 0.0, 0.1) / 0.35))
		crowd.volume_db = linear_to_db(maxf(0.0001, 0.25 * gain))
		hum.volume_db = linear_to_db(maxf(0.0001, 0.09 * gain))


## Motor loops follow actual carriage / shutter displacement, never a random timer. Six synchronized mechanisms share the mix; the nearest rail is clearest. (Web Audio pans by hand; here each voice is a 3D player at its rail, with the JS level and no distance rolloff of its own.)
class Machinery:
	extends Node
	const BUS := &"ArenaMach"
	var level: FointDomeLevel
	var streams: Dictionary = {}
	var voices: Dictionary = {}        # "gate:axis" -> {id, gate, node}
	var extras: Array[Dictionary] = []
	var prev_z := NAN
	var prev_y := NAN

	func _init(p_level: FointDomeLevel) -> void:
		level = p_level
		var fresh := AudioServer.get_bus_index(BUS) < 0
		var i := ArenaAudio._bus(BUS)
		if fresh:
			var l := AudioEffectLowPassFilter.new()
			l.cutoff_hz = 4500.0
			AudioServer.add_bus_effect(i, l)
		for id: String in ["extend", "retract", "door-open", "door-close", "latch"]:
			var st: AudioStreamMP3 = load("res://assets/sfx/foint-machinery/%s.mp3" % id)
			st = st.duplicate()
			st.loop = id != "latch"
			streams[id] = st

	func _voice(id: String, gate: int) -> Dictionary:
		var p := AudioStreamPlayer3D.new()
		p.stream = streams[id]
		p.bus = BUS
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p.max_distance = 0.0
		p.panning_strength = 0.85
		add_child(p)
		var v := {"id": id, "gate": gate, "node": p}
		_position(v)
		p.play()
		return v

	func _position(v: Dictionary) -> void:
		var g: FointDomeLevel.Gate = level.gates[v.gate]
		var radius := 29.9 + level.motion.carriage_z
		var P := Game.player
		var dx := sin(g.a) * radius - P.x
		var dz := cos(g.a) * radius - P.z
		var distance := U.hyp(dx, dz)
		var p: AudioStreamPlayer3D = v.node
		p.global_position = Vector3(sin(g.a) * radius, 1.0, cos(g.a) * radius)
		p.volume_db = linear_to_db((0.12 if v.id == "latch" else 0.16) / (1.0 + distance * 0.13))

	func stop_all() -> void:
		for k: String in voices:
			(voices[k].node as Node).queue_free()
		voices.clear()
		for e: Dictionary in extras:
			(e.node as Node).queue_free()
		extras.clear()
		prev_z = NAN

	func update() -> void:
		var live: bool = ArenaAudio._allowed(level) and not Game.paused and not Game.menu_open() and not Game.wheel.is_open
		if not live:
			if not voices.is_empty() or not extras.is_empty():
				stop_all()
			prev_z = NAN
			return
		var z := level.motion.carriage_z
		var y := level.motion.shutter_y
		if not is_nan(prev_z):
			for i in level.gates.size():
				for axis in 2:
					var delta: float = (z - prev_z) if axis == 0 else (y - prev_y)
					var key := "%d:%d" % [i, axis]
					var id := ""
					if absf(delta) >= 0.00001:
						id = ("extend" if delta < 0.0 else "retract") if axis == 0 else ("door-open" if delta > 0.0 else "door-close")
					var old: Variant = voices.get(key)
					if old != null and old.id != id:
						(old.node as Node).queue_free()
						voices.erase(key)
						if id == "":
							extras.append(_voice("latch", i))
					if id != "" and not voices.has(key):
						voices[key] = _voice(id, i)
		for k: String in voices:
			_position(voices[k])
		var e := extras.size() - 1
		while e >= 0:
			var p: AudioStreamPlayer3D = extras[e].node
			if not p.playing:
				p.queue_free()
				extras.remove_at(e)
			e -= 1
		prev_z = z
		prev_y = y
