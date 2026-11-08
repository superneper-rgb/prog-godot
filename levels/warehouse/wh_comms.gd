class_name WhComms
extends Node
## The warehouse radio (JS levels/warehouse/comms.js): plays the lines one at a time (the Boss through a band-pass with squelch clicks, Prog dry) with the shared subtitle strip. A clip that is missing or unheard still shows its subtitle.

const RADIO := &"WhRadio"

var by_id: Dictionary = {}
var queue: Array[String] = []
var until := 0.0
var boss_player: AudioStreamPlayer
var prog_player: AudioStreamPlayer
var _subs: Array[Dictionary] = []


func _init() -> void:
	for l: Dictionary in WhData.LINES:
		by_id[l.id] = l


func _ready() -> void:
	var fresh := AudioServer.get_bus_index(RADIO) < 0
	var i := ArenaAudio._bus(RADIO)
	if fresh:
		var h := AudioEffectHighPassFilter.new()
		h.cutoff_hz = 380.0
		AudioServer.add_bus_effect(i, h)
		var l := AudioEffectLowPassFilter.new()
		l.cutoff_hz = 3200.0
		AudioServer.add_bus_effect(i, l)
		var d := AudioEffectDistortion.new()
		d.mode = AudioEffectDistortion.MODE_OVERDRIVE
		d.drive = 0.42
		AudioServer.add_bus_effect(i, d)
	boss_player = AudioStreamPlayer.new()
	boss_player.bus = RADIO
	boss_player.volume_db = linear_to_db(1.5 * 0.95)
	add_child(boss_player)
	prog_player = AudioStreamPlayer.new()
	prog_player.bus = &"SFX"
	prog_player.volume_db = linear_to_db(1.25 * 0.95)
	add_child(prog_player)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## play a beat from the lines table; `prog` chains only when Prog is the one being played
func beat(nm: String) -> void:
	var b: Variant = WhData.BEATS.get(nm)
	if b == null:
		return
	var is_prog: bool = Game.character_id() == "prog" if Game.has_method(&"character_id") else true
	var ids: Array = []
	var prog: Array = b.get("prog", []) if is_prog else []
	var main: Array = b.get("ids", [])
	if nm == "foreman" or nm == "finished":
		ids = prog + main
	else:
		ids = main + prog
	for id: String in ids:
		queue.append(id)


## a heavy door letting go: one low horn blast, so an opening shutter is heard from across the room
func horn() -> void:
	if Game.sfx != null:
		Game.sfx.play("latch") if false else null
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 1.2
	var p := AudioStreamPlayer.new()
	p.stream = gen
	p.bus = &"SFX"
	add_child(p)
	p.play()
	var pb: AudioStreamGeneratorPlayback = p.get_stream_playback()
	var n := int(1.15 * gen.mix_rate)
	var saw := 0.0
	var sq := 0.0
	var lp := 0.0
	var k := 1.0 - exp(-TAU * 900.0 / gen.mix_rate)
	var frames := PackedVector2Array()
	frames.resize(n)
	for i in n:
		var t := i / gen.mix_rate
		saw = fposmod(saw + 98.0 / gen.mix_rate, 1.0)
		sq = fposmod(sq + 147.0 / gen.mix_rate, 1.0)
		var v := (saw * 2.0 - 1.0) + (1.0 if sq < 0.5 else -1.0)
		lp += (v - lp) * k
		var g := 0.16 * t / 0.05 if t < 0.05 else (0.16 if t < 0.5 else 0.16 * pow(0.001 / 0.16, (t - 0.5) / 0.6))
		frames[i] = Vector2.ONE * lp * g
	pb.push_buffer(frames)
	get_tree().create_timer(1.3).timeout.connect(p.queue_free)


func hush() -> void:
	queue.clear()


var busy: bool:
	get:
		return queue.size() > 0 or _now() < until


## The strip is one line wide: a long line goes up in pieces, timed by their share of the letters.
func _subtitles(line: Dictionary, dur: float) -> void:
	var parts: Array[String] = []
	var cur := ""
	for w: String in String(line.text).split(" "):
		if cur != "" and (cur + " " + w).length() > 62:
			parts.append(cur)
			cur = w
		else:
			cur = cur + " " + w if cur != "" else w
		if (w.ends_with(".") or w.ends_with("?") or w.ends_with("!")) and cur.length() > 34:
			parts.append(cur)
			cur = ""
	if cur != "":
		parts.append(cur)
	var total := 0
	for p: String in parts:
		total += p.length()
	var at := 0.0
	for p: String in parts:
		var d := dur * p.length() / total
		_subs.append({"at": _now() + at, "name": line.who, "text": p, "dur": maxf(0.8, d - 0.3)})
		at += d


func _start(id: String) -> void:
	var line: Dictionary = by_id[id]
	var is_boss: bool = line.who == "BOSS"
	var path := "res://assets/sfx/warehouse-comms/%s.mp3" % id
	if ResourceLoader.exists(path):
		var st: AudioStream = load(path)
		var pl := boss_player if is_boss else prog_player
		pl.stream = st
		pl.play()
		var dur := st.get_length()
		until = _now() + dur + 0.35
		_subtitles(line, dur)
	else:
		var dur := 1.0 + String(line.text).split(" ").size() / 2.6
		until = _now() + dur + 0.25
		_subtitles(line, dur)


func update() -> void:
	var i := _subs.size() - 1
	var now := _now()
	while i >= 0:
		if float(_subs[i].at) <= now:
			var s: Dictionary = _subs[i]
			Game.hud.subtitle({"name": s.name, "text": s.text, "dur": s.dur})
			_subs.remove_at(i)
		i -= 1
	if queue.is_empty() or now < until:
		return
	_start(queue.pop_front())
