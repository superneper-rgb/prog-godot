class_name CrtKit
extends RefCounted
## What the minigames share (JS minigames/shared/crt-kit.js): the seeded random numbers, the phosphor palette and the SchleedTech monitor numbers. The JS synth is baked: every sound it can make is a WAV in assets/sfx/grind/fx, rendered by the JS graph itself (OfflineAudioContext), so there is nothing to synthesise at run time.

const ART_PATH := "res://assets/ui/cut/pausecrt.png"      # the door terminal: the same monitor the pause menu lives in, its glass already flooded out (the JS does that flood at run time)
const ART_RATIO := 2400.0 / 1945.0
const HOLE := {"x1": 0.2, "y1": 0.1532133676092545, "x2": 0.8054166666666667, "y2": 0.7141388174807198}      # the flood's result in the JS, as fractions of the art
const LEDS := {"power": [0.9275, 0.405], "disk": [0.9275, 0.437], "video": [0.9275, 0.469], "sync": [0.9275, 0.4997]}      # the side panel's lamps, as fractions of the art

# green phosphor like the pause terminal and the wheel's handheld; amber means danger; red only floods in for alarms
const COL := {"solid": [70, 255, 130], "fire": [255, 168, 40], "lock": [190, 255, 210], "rim": [40, 160, 85], "gap": [24, 96, 50], "key": [235, 255, 228], "ice": [255, 142, 30], "probe": [200, 255, 215], "white": [235, 255, 240], "red": [255, 48, 36], "dim": [70, 200, 115], "grid": [30, 110, 60]}


## Math.imul: only the low 32 bits of the product, however large the factors
static func imul(a: int, b: int) -> int:
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	return ((a & 0xFFFF) * b + (((a >> 16) * (b & 0xFFFF)) << 16)) & 0xFFFFFFFF


## JS rngFrom: the same seed gives the same numbers as the three.js game, so a door's route is the same route
class Rng:
	var a := 0

	func _init(seed_v: Variant) -> void:
		var s := str(seed_v)
		var h := (1779033703 ^ s.length()) & 0xFFFFFFFF
		for i in s.length():
			h = CrtKit.imul(h ^ s.unicode_at(i), 3432918353)
			h = ((h << 13) | (h >> 19)) & 0xFFFFFFFF
		a = h

	func next() -> float:
		a = (a + 0x6d2b79f5) & 0xFFFFFFFF
		var t := CrtKit.imul(a ^ (a >> 15), 1 | a)
		t = ((t + CrtKit.imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


static func c8(c: Array, a: float = 1.0) -> Color:
	return Color(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0, a)
