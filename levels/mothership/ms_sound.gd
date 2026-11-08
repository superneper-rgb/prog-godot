class_name MsSound
extends RefCounted
## THE MOTHERSHIP's one-shot synth cues (JS s.tone / s.noise on the shared audio context): rendered once per recipe, then played as a clip.

const RATE := 24000
static var _bank: Dictionary = {}


## parts: [["tone" or "noise", t, {type, f0, f1, q, gain, dur, attack}], ...]
static func play(parts: Array, wet: float = 0.4) -> void:
	if Game.sfx == null:
		return
	var key := str(parts)
	var st: AudioStream = _bank.get(key)
	if st == null:
		var dur := 0.0
		for p: Array in parts:
			dur = maxf(dur, float(p[1]) + float((p[2] as Dictionary).get("dur", 0.2)))
		var buf := OfflineSynth.make(dur + 0.02, RATE)
		for p: Array in parts:
			if p[0] == "tone":
				OfflineSynth.tone(buf, RATE, float(p[1]), p[2])
			else:
				OfflineSynth.noise(buf, RATE, float(p[1]), p[2])
		st = OfflineSynth.wav(buf, RATE)
		_bank[key] = st
	Game.sfx.clip(st, {"gain": 1.0, "wet": wet})


static func tone(dur: float, f0: float, f1: float, gain: float = 0.12, type: StringName = &"sine", wet: float = 0.4) -> void:
	play([["tone", 0.0, {"type": type, "f0": f0, "f1": f1, "gain": gain, "dur": dur}]], wet)


static func noise(dur: float, type: StringName, f0: float, f1: float, gain: float, q: float = 1.0, wet: float = 0.3, attack: float = 0.0) -> void:
	play([["noise", 0.0, {"type": type, "f0": f0, "f1": f1, "q": q, "gain": gain, "dur": dur, "attack": attack}]], wet)
