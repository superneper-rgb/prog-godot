class_name VhAudio
extends Node
## VISITING HOURS sound (JS levels/visiting-hours/audio.js): the rain bed (louder and drummier with a roof over your head), wind, thunder (a crack for close strikes, a long rolling rumble that arrives late by distance) and the comms (Prog and the Boss: the Boss through a radio band-pass with a squelch click, Prog dry), queued one line at a time with the shared subtitle strip.
## ENGINE DIFFERENCE: the JS builds live nodes per sound. Here the beds are looped noise on filter buses and the one-shots are rendered once per recipe (MsSound), so what varies per play (a few random lumps) is fixed per recipe.

const RATE := 24000
const BUS := "VhBed"
const CLIP_DIR := "res://assets/sfx/visiting-hours/"
static var _noise: AudioStreamWAV = null

var queue: Array = []      # {id, t, on_done, on_start}
var talking: Variant = null      # {id, end, done}
var gap_t := 0.0
var roof := 0.0
var rain_on := 1.0
var jammed := false
var quiet := 0.0
var _time := 0.0
var _buses: Array[StringName] = []
var rain_hi: Array
var rain_mid: Array
var roof_b: Array
var wind_b: Array
var _wind_fx: AudioEffectLowPassFilter
var _radio_bus := &"VhRadio"
var _talk_p: AudioStreamPlayer
var _g_hi := 0.16
var _g_mid := 0.1
var _g_roof := 0.0
var _g_wind := 0.12
var _clips: Dictionary = {}


var busy: bool:
	get:
		return talking != null or not queue.is_empty()


func _bus(nm: String) -> StringName:
	var bn := StringName(BUS + nm)
	var ix := AudioServer.get_bus_index(bn)
	if ix >= 0:
		return bn
	AudioServer.add_bus()
	ix = AudioServer.bus_count - 1
	AudioServer.set_bus_name(ix, bn)
	AudioServer.set_bus_send(ix, &"SFX")
	_buses.append(bn)
	return bn


func _loop(nm: String, fx: AudioEffect, g: float) -> Array:
	var bn := _bus(nm)
	AudioServer.add_bus_effect(AudioServer.get_bus_index(bn), fx)
	var p := AudioStreamPlayer.new()
	p.stream = _noise
	p.bus = bn
	p.volume_db = linear_to_db(maxf(g, 1e-5))
	add_child(p)
	p.play(randf() * 1.5)
	return [p]


func _ready() -> void:
	if _noise == null:      # white with a low-passed walk under it (rain, wind, thunder)
		var n := OfflineSynth.make(2.0, RATE)
		var b := 0.0
		for i in n.size():
			var w := randf_range(-1.0, 1.0)
			b = (b + 0.02 * w) / 1.02
			n[i] = w * 0.6 + b * 3.0
		_noise = OfflineSynth.wav(n, RATE, true)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 5200.0
	rain_hi = _loop("Hi", hp, _g_hi)
	var mid := AudioEffectBandPassFilter.new()
	mid.cutoff_hz = 1400.0
	mid.resonance = 0.3
	rain_mid = _loop("Mid", mid, _g_mid)
	var rf := AudioEffectBandPassFilter.new()
	rf.cutoff_hz = 420.0
	rf.resonance = 0.7
	roof_b = _loop("Roof", rf, 0.0)
	_wind_fx = AudioEffectLowPassFilter.new()
	_wind_fx.cutoff_hz = 300.0
	wind_b = _loop("Wind", _wind_fx, _g_wind)
	# radio: band-pass, drive
	var ix := AudioServer.get_bus_index(_radio_bus)
	if ix < 0:
		AudioServer.add_bus()
		ix = AudioServer.bus_count - 1
		AudioServer.set_bus_name(ix, _radio_bus)
		AudioServer.set_bus_send(ix, &"SFX")
		var rh := AudioEffectHighPassFilter.new()
		rh.cutoff_hz = 380.0
		AudioServer.add_bus_effect(ix, rh)
		var rl := AudioEffectLowPassFilter.new()
		rl.cutoff_hz = 3200.0
		AudioServer.add_bus_effect(ix, rl)
		var dr := AudioEffectDistortion.new()
		dr.mode = AudioEffectDistortion.MODE_CLIP
		dr.drive = 0.35
		AudioServer.add_bus_effect(ix, dr)
		_buses.append(_radio_bus)
	_talk_p = AudioStreamPlayer.new()
	_talk_p.bus = &"SFX"
	add_child(_talk_p)


func _exit_tree() -> void:
	for nm: StringName in _buses:
		var i := AudioServer.get_bus_index(nm)
		if i >= 0:
			AudioServer.remove_bus(i)
	_buses.clear()


func _clip(id: String) -> AudioStream:
	if _clips.has(id):
		return _clips[id]
	var path := CLIP_DIR + id + ".mp3"
	var st: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_clips[id] = st
	return st


## queue comms lines (ids from VhLines); urgent = jump the queue (it never cuts a line off)
func say(ids: Variant, o: Dictionary = {}) -> void:
	var arr: Array = ids if ids is Array else [ids]
	var on_start: Callable = o.get("on_start", Callable())
	var list: Array = []
	for i in arr.size():
		list.append({"id": arr[i], "t": 0.0, "on_done": o.get("on_done", Callable()) if i == arr.size() - 1 else Callable(), "on_start": on_start})
	if o.get("urgent", false):
		list.append_array(queue)
		queue = list
	else:
		queue.append_array(list)


## drop what has not been said yet (a checkpoint load)
func hush() -> void:
	queue.clear()


## how long line id plays (s): its clip, else the subtitle estimate (a cutscene times its cuts on this)
func len_of(id: String) -> float:
	var line: Dictionary = VhLines.LINES.get(id, {})
	var st := _clip(id)
	if st != null:
		return st.get_length() + (0.09 if line.get("who") == "BOSS" else 0.0)
	return 1.0 + String(line.get("text", "")).split(" ").size() / 2.6 if not line.is_empty() else 1.0


## the subtitle strip is one line wide: a long line goes up in sentence-sized pieces, each timed by its share of the letters
func _subtitles(line: Dictionary, dur: float) -> void:
	var parts: Array[String] = []
	var cur := ""
	for w: String in String(line.text).split(" "):
		if cur != "" and (cur + " " + w).length() > 64:
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
	var who: String = line.get("name", line.who)
	for p: String in parts:
		var d := dur * p.length() / float(total)
		var txt := p
		var show_d := maxf(0.8, d - 0.45)
		get_tree().create_timer(maxf(at, 0.001), false).timeout.connect(func() -> void:
			if is_inside_tree():
				Game.hud.subtitle({"id": 0, "num": 0, "name": who, "text": txt, "dur": show_d, "speech": false}))
		at += d


func _click(on: bool) -> void:
	MsSound.noise(0.07, &"bandpass", 2400.0 if on else 1600.0, 2400.0 if on else 1600.0, 0.35, 2.0, 0.0)


func _start_line(q: Dictionary) -> void:
	var line: Dictionary = VhLines.LINES.get(q.id, {})
	if line.is_empty():
		return
	var who: String = line.who
	var boss := who == "BOSS" or who == "RADIO"
	if jammed and who == "BOSS" and not line.has("cut"):      # (the jammer: the Boss never gets through)
		talking = {"id": q.id, "end": _time + 0.05}
		return
	var st := _clip(q.id)
	if st != null:
		_talk_p.stop()
		_talk_p.stream = st
		_talk_p.bus = _radio_bus if boss else &"SFX"
		_talk_p.volume_db = linear_to_db(1.5 if boss else 1.25)
		if boss:
			_click(true)
		_talk_p.play()
		var dur := st.get_length()
		talking = {"id": q.id, "end": _time + dur + 0.15, "boss": boss}
		if line.has("cut"):      # cut off mid-word by the jammer
			var cut: float = line.cut
			talking.end = _time + cut + 0.5
			talking.boss = false
			get_tree().create_timer(cut, false).timeout.connect(func() -> void:
				if is_inside_tree():
					_talk_p.stop()
					noise_burst(0.9, 1.1))
			_subtitles(line, cut + 0.4)
		else:
			_subtitles(line, dur)
	else:
		var dur := 1.0 + String(line.text).split(" ").size() / 2.6
		talking = {"id": q.id, "end": _time + dur}
		_subtitles(line, dur)
	var os: Callable = q.get("on_start", Callable())
	if os.is_valid():
		os.call(q.id, maxf(0.4, float(talking.end) - _time - 0.15))      # (seconds of speech: the mouths follow it)


## in_car: 0..1 (a roof over your head: the rain drums, the hiss drops)
func update_audio(dt: float, in_car: float, indoor: float) -> void:
	_time += dt
	roof += (in_car - roof) * minf(1.0, dt * 4.0)
	var k := minf(1.0, dt * 3.0)
	rain_on += ((1.0 - indoor * 0.82) * (1.0 - quiet * 0.75) - rain_on) * k      # (under the ground: the storm muffled)
	var wind := 1.0 - indoor * 0.7
	_g_hi += ((0.16 - roof * 0.1) * rain_on - _g_hi) * k
	_g_mid += ((0.1 - roof * 0.03) * rain_on - _g_mid) * k
	_g_roof += (roof * 0.22 * rain_on - _g_roof) * k
	_g_wind += ((0.08 + 0.06 * wind) * (1.0 - roof * 0.6) - _g_wind) * k
	(rain_hi[0] as AudioStreamPlayer).volume_db = linear_to_db(maxf(_g_hi * 0.9, 1e-5))
	(rain_mid[0] as AudioStreamPlayer).volume_db = linear_to_db(maxf(_g_mid * 0.9, 1e-5))
	(roof_b[0] as AudioStreamPlayer).volume_db = linear_to_db(maxf(_g_roof * 0.9, 1e-5))
	(wind_b[0] as AudioStreamPlayer).volume_db = linear_to_db(maxf(_g_wind * 0.9, 1e-5))
	_wind_fx.cutoff_hz = 220.0 + sin(_time * 1000.0 / 2300.0) * 90.0
	if talking != null and _time > float(talking.end):
		var q: Dictionary = talking
		talking = null
		gap_t = 0.35
		if q.get("boss", false):
			_click(false)
		var d: Callable = q.get("done", Callable())
		if d.is_valid():
			d.call()
	if talking == null:
		gap_t -= dt
		if gap_t <= 0.0 and not queue.is_empty():
			var q: Dictionary = queue.pop_front()
			_start_line(q)
			if talking != null:
				talking["done"] = q.get("on_done", Callable())


## the lockdown's jammer: on, the Boss is gone (a burst of static as it comes up)
func jam(on: bool) -> void:
	if on and not jammed:
		noise_burst(0.7, 0.8)
	jammed = on


# ---- one-shots
func _after(delay: float, fn: Callable) -> void:
	if delay <= 0.01:
		fn.call()
	else:
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			if is_inside_tree():
				fn.call())


## a roll of thunder delay s from now, from dist m away (close = a crack first)
func thunder(delay: float, dist: float, big: bool) -> void:
	var near := snappedf(maxf(0.0, 1.0 - dist / 700.0), 0.2)
	var len_ := snappedf(2.6 + (1.0 - near) * 2.5 + (1.5 if big else 0.0), 0.5)
	_after(delay, func() -> void:
		var parts: Array = []
		if near > 0.45 or big:
			parts.append(["noise", 0.0, {"type": &"highpass", "f0": 900.0, "gain": 0.9 * maxf(near, 0.5), "dur": 0.5}])
		var peak := (0.55 + near * 0.6) * (1.3 if big else 1.0)
		var t := 0.0      # it rolls: lumps of loudness decaying
		while t < len_:
			parts.append(["noise", t, {"type": &"lowpass", "f0": lerpf(380.0 + near * 600.0, 70.0, t / len_), "f1": 70.0, "gain": snappedf(peak * exp(-t / (len_ * 0.45)), 0.05), "dur": 0.7, "attack": 0.1}])
			t += 0.35
		MsSound.play(parts, 0.3))


## the sump pumps kicking in (heard down the pipe): a heavy motor thump and its hum winding up; vol 0..1 by distance
func thunk(vol: float = 1.0) -> void:
	if vol < 0.02:
		return
	var v := snappedf(vol, 0.1)
	MsSound.play([["tone", 0.0, {"type": &"sine", "f0": 70.0, "f1": 38.0, "gain": 0.9 * v, "dur": 0.6, "attack": 0.02}], ["tone", 0.1, {"type": &"sawtooth", "f0": 30.0, "f1": 96.0, "gain": 0.16 * v, "dur": 5.0, "attack": 0.8}]], 0.2)


## a surge of storm water down the pipe: a roar that swells as it comes, eta s until it reaches you, then dies away
func surge(eta: float = 2.0, vol: float = 1.0) -> void:
	var e := snappedf(eta, 0.2)
	var v := snappedf(vol, 0.1)
	MsSound.play([["noise", 0.0, {"type": &"lowpass", "f0": 200.0, "f1": 2600.0, "gain": 0.25 * v, "dur": e + 0.4, "attack": e * 0.7}], ["noise", e, {"type": &"lowpass", "f0": 2600.0, "f1": 300.0, "gain": v, "dur": 2.6, "attack": 0.05}]], 0.4)


## the prison's alarm: two wailing klaxons from across the marsh
func siren() -> void:
	var parts: Array = []
	for d: Array in [[520.0, 0.0], [470.0, 0.21]]:
		for k in 4:
			parts.append(["tone", float(d[1]) + k * 0.9, {"type": &"sawtooth", "f0": d[0], "f1": float(d[0]) * 1.7, "gain": 0.12, "dur": 0.85, "attack": 0.1}])
	MsSound.play(parts, 0.4)


func splash(vol: float = 1.0) -> void:
	MsSound.noise(0.45, &"bandpass", 1800.0, 500.0, snappedf(0.5 * vol, 0.05), 0.9, 0.2)


## a swallow (the thermos)
func gulp() -> void:
	var parts: Array = []
	for i in 3:
		parts.append(["tone", i * 0.32, {"type": &"sine", "f0": 220.0, "f1": 90.0, "gain": 0.35, "dur": 0.16, "attack": 0.02}])
	MsSound.play(parts, 0.1)


## radio static: a band-passed hiss burst (vol 0..1, len s)
func noise_burst(vol: float = 0.6, len_: float = 0.6) -> void:
	MsSound.noise(snappedf(len_, 0.1) + 0.05, &"bandpass", 2200.0, 2200.0, snappedf(0.32 * vol, 0.02), 0.7, 0.1)


## a steel casing / cigarette-sized clink on grating (vol 0..1)
func clink(vol: float = 0.5) -> void:
	var v := snappedf(vol, 0.1)
	MsSound.play([["tone", 0.0, {"type": &"triangle", "f0": 4300.0, "f1": 4300.0, "gain": 0.2 * v, "dur": 0.13}], ["tone", 0.012, {"type": &"triangle", "f0": 6100.0, "f1": 6100.0, "gain": 0.2 * v, "dur": 0.13}]], 0.2)


## the shot: a suppressed rifle thwip, the glass going in a bright crash, and a heavy synth drone dropping under it (the score's bass drop)
func snipe() -> void:
	var parts: Array = [["tone", 0.0, {"type": &"square", "f0": 900.0, "f1": 120.0, "gain": 0.3, "dur": 0.09}], ["noise", 0.01, {"type": &"highpass", "f0": 2600.0, "gain": 0.9, "dur": 1.0}]]
	for d: Array in [[46.0, 0.5, 4.2], [69.0, 0.3, 3.6]]:
		parts.append(["tone", 0.03, {"type": &"sawtooth", "f0": float(d[0]) * 2.2, "f1": d[0], "gain": d[1], "dur": d[2], "attack": 0.03}])
	MsSound.play(parts, 0.3)


## the score's low strings: detuned saws, swelling in over att s, gone over rel s; len_ s in all
func pad(len_: float = 12.0, vol: float = 0.08, att: float = 3.0, _rel: float = 4.0) -> void:
	var parts: Array = []
	for d: Array in [[55.0, 0.0], [55.4, 0.0], [82.4, 0.2], [65.4, 0.1]]:
		parts.append(["tone", d[1], {"type": &"sine", "f0": d[0], "f1": d[0], "gain": vol * 2.0, "dur": len_, "attack": att}])
	MsSound.play(parts, 0.5)


## the line singing under a rider: high friction whine for len_ s, pitch climbing with speed, fading into the rain
func cable(len_: float = 3.5) -> void:
	MsSound.play([["tone", 0.0, {"type": &"sawtooth", "f0": 1500.0, "f1": 3400.0, "gain": 0.03, "dur": len_ * 0.5, "attack": 0.3}], ["tone", len_ * 0.5, {"type": &"sawtooth", "f0": 3400.0, "f1": 2200.0, "gain": 0.03, "dur": len_ * 0.5}], ["noise", 0.0, {"type": &"bandpass", "f0": 4000.0, "q": 1.2, "gain": 0.12, "dur": len_, "attack": 0.4}]], 0.3)


## a cigarette ember dying on wet steel: a faint hiss
func sizzle(len_: float = 3.0) -> void:
	MsSound.noise(len_, &"highpass", 6500.0, 6500.0, 0.05, 1.0, 0.2, 0.05)


## a short electric tone: the door board's buzz (f ~ 120), a camera's servo (f ~ 900, quiet), a beep
func tone(f0: float = 120.0, len_: float = 0.5, vol: float = 0.2, type: StringName = &"square") -> void:
	MsSound.tone(len_, f0, f0, vol, type, 0.1)


## a heavy thump: a mag lock slamming, a body against a chair (vol 0..1)
func thud(vol: float = 0.6) -> void:
	var v := snappedf(vol, 0.1)
	MsSound.play([["tone", 0.0, {"type": &"sine", "f0": 110.0, "f1": 40.0, "gain": 0.5 * v, "dur": 0.25}], ["noise", 0.0, {"type": &"bandpass", "f0": 2200.0, "q": 0.7, "gain": 0.08 * v, "dur": 0.1}]], 0.2)
