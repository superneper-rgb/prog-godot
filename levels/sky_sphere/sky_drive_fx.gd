class_name SkyDriveFx
extends Node
## Nitro exhaust, engine, wind, the slide and scrape loop, and synthesized race cues (crash, takedown and smash added 2026-11-18 with the driven race).

enum Cue { TICK, GO, BOOST, SCRAPE, CRASH, TAKEDOWN, SMASH, ITEM, DROP, ZAP, HARPOON, SHELL }
const RATE := 16000
static var _ribbon: ArrayMesh


class Exhaust:
	var jets: Array[MeshInstance3D] = []

	func _init(parent: Node3D, ports: Array[Vector3], color: Color) -> void:
		var glow := ShaderMaterial.new()
		glow.shader = preload("res://levels/sky_sphere/sky_plume.gdshader")
		glow.set_shader_parameter(&"plasma", color)
		for at: Vector3 in ports:
			var jet := SkyGeometry.part(parent, SkyDriveFx.ribbon_mesh(), glow, Transform3D(Basis.IDENTITY, at))
			jet.extra_cull_margin = 3.0
			jet.hide()
			jets.append(jet)

	func drive(revs: float, boost: float, time: float) -> void:
		for i in jets.size():
			var jet := jets[i]
			jet.visible = revs > 0.01 or boost > 0.01
			if jet.visible:
				var flutter := 0.95 + 0.05 * sin(time * 39.0 + i * 4.0)
				var width := 0.17 + revs * 0.08 + boost * 0.18
				jet.scale = Vector3(width, width, (0.46 + revs * 1.47 + boost * 6.6) * flutter)
				jet.set_instance_shader_parameter(&"power", boost)


var _engine: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _slide: AudioStreamPlayer
var _hits: AudioStreamPlayer
var _sound: AudioStreamPlayer
var _cues: Array[AudioStreamWAV] = []
var _rev := 0.0


func build() -> void:
	_sound = _player()
	_sound.max_polyphony = 4
	for i in Cue.size():
		_cues.append(_cue(i))
	_engine = _player()
	_engine.stream = _loop(false)
	_wind = _player()
	_wind.stream = _loop(true)
	_slide = _player()
	_slide.stream = _loop(true)
	_hits = _player()
	_hits.max_polyphony = 3


func start() -> void:
	_engine.volume_db = -27.0
	_wind.volume_db = -48.0
	_slide.volume_db = -60.0
	_engine.play()
	_wind.play()
	_slide.play()
	_rev = 0.0


func stop() -> void:
	_engine.stop()
	_wind.stop()
	_slide.stop()
	_sound.stop()


func suspend(paused: bool) -> void:
	_engine.stream_paused = paused
	_wind.stream_paused = paused
	_slide.stream_paused = paused
	_sound.stream_paused = paused


func rev(dt: float, speed: float, load: float, boost: float) -> void:
	var pace := clampf(speed / 136.0, 0.0, 1.1)
	_rev = U.damp(_rev, clampf(pace + load * 0.115 + boost * 0.11, 0.0, 1.2), 5.4, dt)
	_engine.pitch_scale = 0.64 + _rev * 1.93 + sin(speed * 0.116) * 0.045
	_engine.volume_db = -24.0 + _rev * 12.0
	_wind.pitch_scale = 0.61 + pace * 1.6
	_wind.volume_db = linear_to_db(maxf(0.002, pow(pace, 1.75) * 0.27 + boost * 0.065))


## The pads hissing in a slide and the hull grinding on a wall: amount 0..1, scrape a closing speed.
func slide(dt: float, amount: float, scrape: float) -> void:
	var level := maxf(amount * 0.55, clampf(scrape / 6.0, 0.0, 1.0))
	_slide.volume_db = U.damp(_slide.volume_db, linear_to_db(maxf(0.001, level * 0.32)), 12.0, dt)
	_slide.pitch_scale = 1.6 + amount * 0.5 - clampf(scrape / 10.0, 0.0, 0.6)


func cue(sound: Cue) -> void:
	var speaker := _hits if sound >= Cue.CRASH else _sound
	speaker.stream = _cues[sound]
	speaker.volume_db = -9.0 if sound >= Cue.CRASH else -12.0
	speaker.play()


func _player() -> AudioStreamPlayer:
	var speaker := AudioStreamPlayer.new()
	speaker.bus = &"SFX"
	add_child(speaker)
	return speaker


static func ribbon_mesh() -> ArrayMesh:
	if _ribbon != null:
		return _ribbon
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	const CORNERS: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in 3:
		var across := Vector3.RIGHT.rotated(Vector3.BACK, PI * i / 3.0)
		for uv: Vector2 in CORNERS:
			mesh.set_uv(uv)
			mesh.add_vertex(across * ((uv.x * 2.0 - 1.0) * lerpf(1.0, 0.38, uv.y)) + Vector3.FORWARD * uv.y)
	_ribbon = mesh.commit()
	return _ribbon


static func _loop(wind: bool) -> AudioStreamWAV:
	var buf := OfflineSynth.make(1.0, RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 311
	var filtered := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		if wind:
			var grain := rng.randf_range(-1.0, 1.0)
			filtered = lerpf(filtered, grain, 0.105)
			var feather := smoothstep(0.0, 0.022, t) * (1.0 - smoothstep(0.978, 1.0, t))
			buf[i] = (filtered * 0.77 + grain * 0.064) * feather
		else:
			var phase := t * TAU
			buf[i] = sin(phase * 48.0) * 0.38 + sin(phase * 72.0) * 0.2 + sin(phase * 113.0) * 0.1
			buf[i] += sin(phase * 195.0 + sin(phase * 13.0) * 0.61) * (0.055 + 0.035 * sin(phase * 24.0))
	return OfflineSynth.wav(buf, RATE, true)


static func _cue(sound: Cue) -> AudioStreamWAV:
	var buf := OfflineSynth.make(1.2, RATE)
	match sound:
		Cue.TICK:
			OfflineSynth.tone(buf, RATE, 0, {"type": &"sine", "f0": 420.0, "f1": 390.0, "dur": 0.19, "gain": 0.74})
		Cue.GO:
			OfflineSynth.tone(buf, RATE, 0, {"f0": 490.0, "f1": 730.0, "dur": 0.26, "gain": 0.6})
			OfflineSynth.tone(buf, RATE, 0.075, {"type": &"sine", "f0": 980.0, "f1": 820.0, "dur": 0.39, "gain": 0.6})
		Cue.BOOST:
			OfflineSynth.noise(buf, RATE, 0, {"f0": 360.0, "f1": 1820.0, "q": 0.8, "dur": 0.86, "gain": 0.74, "attack": 0.071})
			OfflineSynth.tone(buf, RATE, 0, {"f0": 87.0, "f1": 1020.0, "dur": 0.9, "gain": 0.46, "attack": 0.17})
			OfflineSynth.tone(buf, RATE, 0.12, {"type": &"sine", "f0": 105.0, "f1": 28.0, "dur": 0.74, "gain": 0.52})
		Cue.SCRAPE:
			OfflineSynth.noise(buf, RATE, 0, {"f0": 2250.0, "f1": 160.0, "q": 1.8, "dur": 0.35, "gain": 0.81})
			OfflineSynth.tone(buf, RATE, 0, {"f0": 121.0, "f1": 42.0, "dur": 0.2, "gain": 0.55})
		Cue.CRASH:
			OfflineSynth.noise(buf, RATE, 0, {"f0": 900.0, "f1": 70.0, "q": 0.7, "dur": 1.0, "gain": 0.95})
			OfflineSynth.tone(buf, RATE, 0, {"type": &"sine", "f0": 70.0, "f1": 26.0, "dur": 0.8, "gain": 0.8})
			OfflineSynth.noise(buf, RATE, 0.05, {"f0": 4200.0, "f1": 1200.0, "q": 2.4, "dur": 0.5, "gain": 0.4})
		Cue.TAKEDOWN:
			OfflineSynth.tone(buf, RATE, 0, {"f0": 220.0, "f1": 330.0, "dur": 0.16, "gain": 0.55})
			OfflineSynth.tone(buf, RATE, 0.12, {"f0": 330.0, "f1": 660.0, "dur": 0.42, "gain": 0.6})
			OfflineSynth.tone(buf, RATE, 0.12, {"type": &"sine", "f0": 55.0, "f1": 40.0, "dur": 0.7, "gain": 0.7})
			OfflineSynth.noise(buf, RATE, 0, {"f0": 1500.0, "f1": 300.0, "q": 1.0, "dur": 0.5, "gain": 0.5})
		Cue.SMASH:
			OfflineSynth.noise(buf, RATE, 0, {"f0": 3000.0, "f1": 600.0, "q": 2.0, "dur": 0.22, "gain": 0.7})
			OfflineSynth.tone(buf, RATE, 0, {"type": &"sine", "f0": 180.0, "f1": 90.0, "dur": 0.15, "gain": 0.5})
		Cue.ITEM:
			OfflineSynth.tone(buf, RATE, 0, {"type": &"sine", "f0": 660.0, "f1": 660.0, "dur": 0.09, "gain": 0.5})
			OfflineSynth.tone(buf, RATE, 0.08, {"type": &"sine", "f0": 990.0, "f1": 990.0, "dur": 0.09, "gain": 0.5})
			OfflineSynth.tone(buf, RATE, 0.16, {"type": &"sine", "f0": 1320.0, "f1": 1320.0, "dur": 0.2, "gain": 0.5})
		Cue.DROP:
			OfflineSynth.tone(buf, RATE, 0, {"f0": 260.0, "f1": 120.0, "dur": 0.12, "gain": 0.6})
			OfflineSynth.noise(buf, RATE, 0.02, {"f0": 2600.0, "f1": 2000.0, "q": 3.0, "dur": 0.08, "gain": 0.4})
		Cue.ZAP:
			OfflineSynth.noise(buf, RATE, 0, {"f0": 5000.0, "f1": 400.0, "q": 1.4, "dur": 0.45, "gain": 0.8})
			OfflineSynth.tone(buf, RATE, 0, {"f0": 1400.0, "f1": 80.0, "dur": 0.4, "gain": 0.55})
		Cue.HARPOON:
			OfflineSynth.tone(buf, RATE, 0, {"f0": 300.0, "f1": 1800.0, "dur": 0.18, "gain": 0.5})
			OfflineSynth.noise(buf, RATE, 0.05, {"f0": 1800.0, "f1": 3500.0, "q": 2.0, "dur": 0.35, "gain": 0.45})
		Cue.SHELL:
			OfflineSynth.tone(buf, RATE, 0, {"type": &"sine", "f0": 90.0, "f1": 140.0, "dur": 0.6, "gain": 0.7, "attack": 0.05})
			OfflineSynth.noise(buf, RATE, 0, {"f0": 700.0, "f1": 1600.0, "q": 1.2, "dur": 0.5, "gain": 0.45, "attack": 0.08})
	return OfflineSynth.wav(buf, RATE)
