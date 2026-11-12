class_name MsSound
extends RefCounted
## THE MOTHERSHIP's one-shot synth cues (JS s.tone / s.noise on the shared audio context): rendered once per recipe, then played as a clip.

const RATE := 24000
static var _bank: Dictionary = {}
static var _mx := Mutex.new()     # (_bank is also written by prewarm's worker threads)
static var _warming := false      # inside warm(): play() queues, it does not sound


## parts: [["tone" or "noise", t, {type, f0, f1, q, gain, dur, attack}], ...]
static func play(parts: Array, wet: float = 0.4) -> void:
	if _warming:
		prewarm([parts])
		return
	if Game.sfx == null:
		return
	var key := str(parts)
	_mx.lock()
	var st: AudioStream = _bank.get(key)
	_mx.unlock()
	if st == null:
		st = _render(parts)
		_mx.lock()
		_bank[key] = st
		_mx.unlock()
	Game.sfx.clip(st, {"gain": 1.0, "wet": wet})


## (Not in the JS: WebAudio synthesised these live for free. Here a recipe is rendered sample by sample in script, and a long one, a 5 s
## thunder roll, takes 0.2-0.3 s: rendered the first time it plays, that is a hitch mid-play. A level renders the recipes it will play here
## at load, on worker threads, so play() finds them ready.)
static func prewarm(list: Array) -> void:
	for parts: Array in list:
		var key := str(parts)
		_mx.lock()
		var have := _bank.has(key)
		_mx.unlock()
		if not have:
			WorkerThreadPool.add_task(func() -> void:
				var st := _render(parts)
				_mx.lock()
				if not _bank.has(key):
					_bank[key] = st
				_mx.unlock())


## run a level's own cue functions with the arguments it will use, at load: each play() inside queues its recipe for prewarm instead of
## sounding, so the recipes stay in one place (the cue) and what is rendered is exactly what will play.
static func warm(fn: Callable) -> void:
	_warming = true
	fn.call()
	_warming = false


static func _render(parts: Array) -> AudioStream:
	var dur := 0.0
	for p: Array in parts:
		dur = maxf(dur, float(p[1]) + float((p[2] as Dictionary).get("dur", 0.2)))
	var buf := OfflineSynth.make(dur + 0.02, RATE)
	for p: Array in parts:
		if p[0] == "tone":
			OfflineSynth.tone(buf, RATE, float(p[1]), p[2])
		else:
			OfflineSynth.noise(buf, RATE, float(p[1]), p[2])
	return OfflineSynth.wav(buf, RATE)


static func tone(dur: float, f0: float, f1: float, gain: float = 0.12, type: StringName = &"sine", wet: float = 0.4) -> void:
	play([["tone", 0.0, {"type": type, "f0": f0, "f1": f1, "gain": gain, "dur": dur}]], wet)


static func noise(dur: float, type: StringName, f0: float, f1: float, gain: float, q: float = 1.0, wet: float = 0.3, attack: float = 0.0) -> void:
	play([["noise", 0.0, {"type": type, "f0": f0, "f1": f1, "q": q, "gain": gain, "dur": dur, "attack": attack}]], wet)
