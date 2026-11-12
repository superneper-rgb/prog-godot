class_name CreatureAudio
extends RefCounted
## JS enemies/creature-audio.js class CreatureAudio: when creatures make a sound. The organ voices and beats themselves were rendered (creature.<kind>.<cue> in the bank), so only the rate limits and the event map remain here.

const FLAGS: Array = [[&"alien", "alien"], [&"floater", "spore"], [&"follower", "follower"], [&"prophet", "prophet"], [&"scream", "scream"], [&"worm", "worm"], [&"crawler", "crawler"], [&"mimic", "mimic"], [&"warden", "warden"], [&"brute", "brute"], [&"dervish", "brute"]]      # (the Briar Dervish borrows the brute's grinding voice until it has its own bank)
const DURATIONS := {"step": 0.12, "idle": 0.55, "pain": 0.38, "death": 1.15, "alert": 0.85, "wind": 0.7, "impact": 0.3, "roar": 1.3, "inhale": 0.6, "wheeze": 0.7, "squelch": 0.3, "whoosh": 0.22, "thud": 0.32, "crack": 0.15}

var recent := {}
var voices: PackedFloat64Array = PackedFloat64Array()
var played := 0
var dropped := 0


## JS creatureKind (enemies/creature-gameplay.js): "" for a stock robot.
static func creature_kind(r: Variant) -> String:
	if r == null:
		return ""
	var d: Variant = r.get(&"drone")
	if d != null and d != false:
		return ""
	for f: Array in FLAGS:
		var v: Variant = r.get(f[0])
		if v != null and v != false:
			return f[1]
	var n: Variant = r.get(&"name")
	return "tongue" if n != null and str(n) == "WALLWRETCH" else ""


## JS creatureWind (enemies/creature-gameplay.js): how long this creature's current attack telegraphs. Enemy tuning lives in Config once those enemies are ported.
static func creature_wind(r: Variant) -> float:
	var k := creature_kind(r)
	var atk: String = str(r.get(&"atk"))
	match k:
		"brute":
			return _c(&"carapace_charge_wind", 0.9) if atk == "charge" else _c(&"carapace_slam_wind", 0.7)
		"crawler":
			if atk == "drop":
				return _c(&"crawler_drop_wind", 0.7)
			if atk == "leap":
				return _c(&"crawler_leap_wind", 0.7)
			return _c(&"crawler_bite_wind", 0.35) if atk == "melee" else _c(&"crawler_spit_wind", 0.6)
		"tongue":
			return _c(&"wretch_wind", 0.95)
		"spore":
			return _c(&"bloat_fuse", 0.7)
		"mimic":
			return _c(&"mimic_wind", 0.55)
		"prophet":
			return _c(&"prophet_summon_wind", 1.0) if atk == "summon" else _c(&"prophet_blast_wind", 0.5)
		"follower":
			return 0.38
		"scream":
			if atk == "whip":
				return _c(&"scream_whip_wind", 0.45)
			return _c(&"scream_call_wind", 1.0) if atk == "call" else _c(&"scream_dart_wind", 0.5)
		"worm":
			if atk == "slam":
				return _c(&"worm_slam_wind", 0.75)
			return _c(&"worm_ring_wind", 0.6) if atk == "ring" else 0.7
	return _c(&"alien_mind_wind", 0.85)


static func _c(key: StringName, fallback: float) -> float:
	var v: Variant = Config.get(key)
	return float(v) if v != null else fallback


static func creature_duration(cue: String, duration: float) -> float:
	var d: float = duration if duration > 0.0 else float(DURATIONS.get(cue, 0.5))
	return maxf(0.06, minf(1.4, d))


func play(sfx: Variant, r: Variant, cue: String, duration: float = 0.0) -> bool:
	var kind: String = r if r is String else creature_kind(r)
	if kind == "":
		return false
	var now: float = sfx.now
	var id: Variant = kind if r is String else r.id
	var key := str(id) + ":" + cue
	var gap := 0.25 if cue == "step" else 5.0 if cue == "idle" else 0.55 if cue == "pain" else 0.12
	if now - float(recent.get(key, -100.0)) < gap:
		dropped += 1
		return false
	var live := PackedFloat64Array()
	for v in voices:
		if v > now:
			live.append(v)
	voices = live
	var quiet := cue == "step" or cue == "idle"
	if voices.size() >= (2 if quiet else 5):
		dropped += 1
		return false
	var rx: float = 0.0 if r is String else r.x
	var ry: float = 0.0 if r is String else r.y
	var rz: float = 0.0 if r is String else r.z
	var rh: float = 1.0 if r is String else r.h
	if not sfx.play_at("creature", rx, ry + rh * 0.6, rz, {"kind": kind, "cue": cue, "dur": duration, "range": 20.0 if quiet else 42.0, "ref": 3.0 if quiet else 5.0}):
		return false
	recent[key] = now
	voices.append(now + creature_duration(cue, duration) + 0.05)
	played += 1
	if recent.size() > 256:
		for k: String in recent.keys():
			if now - float(recent[k]) > 12.0:
				recent.erase(k)
	return true


## JS event(e, r, sfx): true when this creature's sound was handled here. The event names are the snake_case ones Combat and Enemies push.
func event(e: Dictionary, r: Variant, sfx: Variant) -> bool:
	if creature_kind(r) == "":
		return false
	var t: String = str(e.t)
	if t == "creature_cue":
		play(sfx, r, str(e.cue))
		return true
	if t == "robot_atk":
		var ph := str(e.get("ph", ""))
		if ph == "windup":
			var alien_shot: bool = r.get(&"alien") == true and str(e.get("kind", "")) == "shot"
			play(sfx, r, "wind", 0.22 if alien_shot else creature_wind(r))
		elif ph == "hit" or ph == "go":
			play(sfx, r, "impact")
		return true
	if t == "robot_state":
		var to := str(e.get("to", ""))
		if to == "alert":
			play(sfx, r, "alert")
		elif to == "stagger":
			play(sfx, r, "pain")
		return true
	if t == "robot_hit":
		play(sfx, r, "pain")
	if t == "robot_die":
		play(sfx, r, "death")
	return false
