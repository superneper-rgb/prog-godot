class_name Looks
extends RefCounted
## LOOKS: the colour grade, glow, mist and lens of each level (JS post-looks.js), read by core/post_fx.gd. One table so the art direction of the whole game can be read and tuned in one place.
##
## The universe bible says never one uniform atmosphere, so every level gets its own mood here. A level's entry only names what differs from LOOK_BASE. A level can also have its
## own `look` (a Dictionary property on the Level), which wins over this table. Everything is a shader parameter: changing a look compiles nothing and costs nothing.
## Tune live with `Game.view.look_command(["set", "bloom", "0.8"])`, `["set", "gain", "1.1", "1", "0.9"]`, `["debug", "ao"]`, `["off"]` (A/B), `["spire"]` (borrow one), `["dump"]` (prints the entry).
##
## Colours are display values (what you would pick in a colour picker), except that lift adds and gain / tints multiply. Distances are metres.
##
## Restraint is the point: a sign whose letters wash out or a wall that drops to black is a worse picture, not a moodier one. The frame is display-referred, so bloom judges brightness
## on screen: a pale daylight wall blooms like a lamp unless the threshold is above it, and a level drenched in one colour needs bloom_luma or its top channel lights the whole frame.
##
## DATA FORMAT (for the exporter): `Looks.get_look(level_id) -> Dictionary` holds only what differs from LOOK_BASE, with the keys of LOOK_BASE; a colour is a 3-element Array of floats.
## `Game.view.apply_look(dict)` replaces the current look: anything not named falls back to LOOK_BASE. An exported level writes its entry here (or sets `look` on its Level).

const LOOK_BASE := {
	# contact shadows: strength 0..1, world radius, distance where they have faded out (distance stays flat on purpose)
	"ao": 0.7, "ao_radius": 1.1, "ao_fade": 60.0,
	# height mist: density at mist_y per metre (0 = off), how fast it thins going up, base height, colour (null = the level's fog colour), a glow toward mist_light, sky distance
	"mist": 0.0, "mist_falloff": 0.09, "mist_y": 0.0, "mist_color": null, "mist_gain": 1.0, "mist_glow": [0.0, 0.0, 0.0], "mist_glow_pow": 6.0, "mist_light": [0.36, 0.78, -0.62], "mist_far": 450.0,
	# bloom: amount, where it starts (0..1 on screen), width of the fade in, how much more a clipped highlight is worth (0..0.95), brightness by top channel (0) or luma (1),
	# how much each wider level counts (low = hugs the light, high = haze across the frame)
	"bloom": 0.35, "bloom_threshold": 0.78, "bloom_knee": 0.2, "bloom_hot": 0.6, "bloom_luma": 0.0, "bloom_spread": 0.8,
	# sideways lens streak off the brightest lights
	"streak": 0.0, "streak_cut": 0.35, "streak_tint": [0.4, 0.55, 1.0],
	# grade
	"lift": [0.0, 0.0, 0.0], "gamma": [1.0, 1.0, 1.0], "gain": [1.0, 1.0, 1.0], "black_point": 0.0, "scurve": 0.08, "saturation": 1.0, "vibrance": 0.12, "shadow_tint": [1.0, 1.0, 1.0], "high_tint": [1.0, 1.0, 1.0],
	# lens
	"vignette": 0.28, "vignette_tint": [0.02, 0.02, 0.05], "aberration": 0.0, "grain": 0.018, "sharpen": 0.2,
}

## every effect off: the picture the materials drew (`look off`)
const LOOK_NEUTRAL := {
	"ao": 0.0, "mist": 0.0, "bloom": 0.0, "streak": 0.0, "black_point": 0.0, "scurve": 0.0, "saturation": 1.0, "vibrance": 0.0, "vignette": 0.0, "aberration": 0.0, "grain": 0.0, "sharpen": 0.0,
}

const LOOKS := {
	# FOINT CITY: wet neon night. The near-black mass stays near-black (60 / 30 / 10 palette): glow and streaks belong to the 10% that is light.
	"hub": {"ao": 0.85, "ao_radius": 1.3, "ao_fade": 55.0, "mist": 0.005, "mist_falloff": 0.075, "mist_y": -8.0, "mist_gain": 1.35, "mist_glow": [0.07, 0.05, 0.1], "mist_glow_pow": 5.0,
		"bloom": 0.42, "bloom_threshold": 0.72, "bloom_knee": 0.22, "streak": 0.11, "streak_cut": 0.42, "saturation": 1.05, "vibrance": 0.25, "scurve": 0.1, "shadow_tint": [0.95, 0.97, 1.08], "high_tint": [1.03, 1.0, 0.96], "vignette": 0.32, "vignette_tint": [0.01, 0.0, 0.05], "grain": 0.024},
	# Thunderstorm alley: colder and wetter than the city it hangs off, rain haze you can lean on.
	"worldbackalley": {"ao": 0.7, "ao_radius": 1.3, "ao_fade": 50.0, "mist": 0.006, "mist_falloff": 0.08, "mist_y": -1.0, "mist_color": [0.09, 0.12, 0.18], "bloom": 0.5, "bloom_threshold": 0.7, "bloom_knee": 0.22, "bloom_hot": 0.65, "streak": 0.12,
		"gamma": [1.14, 1.15, 1.18], "scurve": 0.05, "saturation": 0.96, "shadow_tint": [0.93, 0.97, 1.1], "high_tint": [1.0, 1.0, 1.02], "vignette": 0.28, "vignette_tint": [0.005, 0.01, 0.03], "aberration": 0.0012, "grain": 0.028},
	# Saltmarsh in a storm: desaturated teal night, ground mist on the marsh, headlights that flare.
	"visiting-hours": {"ao": 0.75, "ao_radius": 1.5, "ao_fade": 80.0, "mist": 0.007, "mist_falloff": 0.2, "mist_y": 0.5, "mist_color": [0.16, 0.22, 0.3], "mist_glow": [0.04, 0.05, 0.08], "bloom": 0.45, "bloom_threshold": 0.72, "bloom_hot": 0.7, "streak": 0.22, "streak_tint": [0.5, 0.6, 1.0],
		"scurve": 0.12, "saturation": 0.9, "vibrance": 0.05, "shadow_tint": [0.92, 0.98, 1.08], "high_tint": [1.04, 1.01, 0.95], "vignette": 0.36, "vignette_tint": [0.005, 0.015, 0.03], "grain": 0.03},
	# A plant on a volcano: heat haze rising from the magma, everything hot in the highlights.
	"omnisphere": {"ao": 0.8, "ao_radius": 1.4, "ao_fade": 80.0, "mist": 0.0016, "mist_falloff": 0.006, "mist_color": [0.3, 0.12, 0.06], "mist_glow": [0.12, 0.05, 0.02], "bloom": 0.55, "bloom_threshold": 0.7, "bloom_knee": 0.25, "bloom_hot": 0.72,
		"scurve": 0.14, "saturation": 1.05, "vibrance": 0.15, "shadow_tint": [1.02, 0.97, 0.96], "high_tint": [1.05, 1.0, 0.93], "vignette": 0.34, "vignette_tint": [0.03, 0.01, 0.01], "grain": 0.022},
	# Dorbat Logistics: sodium over cold steel, rain on the roof.
	"warehouse": {"ao": 0.85, "ao_radius": 1.2, "mist": 0.006, "mist_falloff": 0.05, "mist_gain": 1.4, "bloom": 0.4, "gamma": [1.03, 1.03, 1.03], "scurve": 0.12, "saturation": 0.95, "shadow_tint": [0.95, 0.99, 1.06], "high_tint": [1.05, 1.0, 0.93], "vignette": 0.32, "grain": 0.026},
	# Inside the creature: wet highlights, maroon shadows. Red clips everywhere here, so brightness is judged by luma or the whole frame would glow.
	"spire": {"ao": 0.9, "ao_radius": 1.6, "ao_fade": 70.0, "mist": 0.005, "mist_falloff": 0.05, "mist_y": -2.0, "mist_gain": 1.8, "bloom": 0.4, "bloom_threshold": 0.62, "bloom_knee": 0.3, "bloom_hot": 0.55, "bloom_luma": 0.8,
		"gain": [0.97, 1.0, 1.0], "gamma": [1.0, 0.97, 0.97], "scurve": 0.14, "saturation": 0.94, "vibrance": 0.0, "shadow_tint": [0.9, 1.0, 1.05], "high_tint": [1.02, 1.02, 0.98], "vignette": 0.42, "vignette_tint": [0.05, 0.0, 0.02], "aberration": 0.0016, "grain": 0.024},
	# Club 9: the fog machine is on. Low purple haze on the floor, everything neon flares a little.
	"club": {"ao": 0.8, "mist": 0.03, "mist_falloff": 0.55, "mist_color": [0.2, 0.08, 0.28], "bloom": 0.45, "bloom_threshold": 0.74, "bloom_knee": 0.2, "bloom_hot": 0.7, "streak": 0.18, "streak_cut": 0.3, "streak_tint": [0.75, 0.4, 1.0],
		"saturation": 1.06, "vibrance": 0.2, "shadow_tint": [0.98, 0.95, 1.08], "vignette": 0.36, "vignette_tint": [0.02, 0.0, 0.05], "grain": 0.02},
	# FOINT DOME: televised, so it is crisp and punchy; the red screens glow without flooding the floor.
	"foint-dome": {"ao": 0.85, "ao_radius": 1.4, "mist": 0.002, "mist_falloff": 0.05, "mist_color": [0.22, 0.05, 0.05], "bloom": 0.5, "bloom_threshold": 0.7, "bloom_knee": 0.22, "bloom_luma": 0.35, "streak": 0.1, "streak_tint": [1.0, 0.25, 0.2],
		"scurve": 0.14, "saturation": 1.02, "shadow_tint": [1.0, 0.96, 0.98], "high_tint": [1.03, 1.0, 0.97], "vignette": 0.4, "vignette_tint": [0.03, 0.0, 0.01], "grain": 0.016, "sharpen": 0.3},
	# The Godmother's mansion: decadent gold hour against violet shadow.
	"mothership": {"ao": 0.8, "ao_radius": 1.3, "mist": 0.0015, "mist_falloff": 0.04, "mist_color": [0.42, 0.26, 0.4], "mist_glow": [0.14, 0.08, 0.04], "mist_light": [0.5, 0.35, -0.8], "bloom": 0.45, "bloom_threshold": 0.74,
		"scurve": 0.16, "saturation": 1.06, "vibrance": 0.2, "shadow_tint": [0.98, 0.96, 1.04], "high_tint": [1.06, 1.0, 0.9], "vignette": 0.34, "grain": 0.018},
	# Prog's one-bedroom: nicotine and old television.
	"apartment": {"ao": 0.7, "ao_radius": 0.8, "ao_fade": 30.0, "bloom": 0.35, "bloom_threshold": 0.6, "lift": [0.004, 0.006, 0.002], "gamma": [1.16, 1.18, 1.1], "scurve": 0.04, "saturation": 0.88, "vibrance": 0.0,
		"shadow_tint": [0.96, 1.02, 0.98], "high_tint": [1.04, 1.0, 0.92], "vignette": 0.3, "vignette_tint": [0.01, 0.015, 0.01], "aberration": 0.0012, "grain": 0.035},
	"ship-combat": {"ao": 0.3, "bloom": 0.6, "bloom_threshold": 0.62, "bloom_knee": 0.25, "bloom_hot": 0.8, "streak": 0.25, "streak_cut": 0.3, "vignette": 0.3, "grain": 0.015, "sharpen": 0.25},
	"reality-slip": {"bloom": 0.55, "bloom_threshold": 0.65, "bloom_knee": 0.25, "aberration": 0.003, "vignette": 0.35},
	"kame-lab": {"bloom": 0.5, "bloom_threshold": 0.7, "bloom_hot": 0.75},
}


## The level's entry: only what differs from LOOK_BASE (empty when it has none). JS lookFor(id).
static func get_look(level_id: String) -> Dictionary:
	return LOOKS.get(level_id, {})


## A look with everything filled in: LOOK_BASE, then the entry over it. JS `{ ...LOOK_BASE, ...l }`.
static func full(l: Dictionary) -> Dictionary:
	var k := LOOK_BASE.duplicate()
	k.merge(l, true)
	return k
