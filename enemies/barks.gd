class_name Barks
extends RefCounted
## The robots' spoken lines (JS class Barks): who may talk right now. Per-robot cooldowns, a global gap, a limited number of voices, and a quieter line
## never talks over a more important one. It only decides; the sound and the subtitle hang off the `bark` event.

const BARKS := {
	"pain": ["OW. PROCESSING OW.", "CHASSIS BREACH!", "NOT THE PAINT!", "HYDRAULICS LEAKING", "THAT WAS MY GOOD ARM", "FAULT 0x2F: OUCH", "I WAS JUST PATROLLING", "REPORTING THIS TO MANAGEMENT", "SPARE PARTS DO NOT GROW ON TREES", "WARNING: RUDE", "SENSOR ARRAY RINGING", "MY WARRANTY!"],
	"die": ["SHUTTING... DOWN...", "TELL MY... SPARE PARTS...", "NO MORE... UPDATES...", "POWER... LOSS...", "BACKUP... NOT FOUND..."],
	"alert": ["HOSTILE!", "INTRUDER ON THE GRID!", "CONTACT!", "ALL UNITS: TROUBLE", "DETECTED. UNFORTUNATELY.", "SOMEONE IS IN TROUBLE"],
}
const BARK_PRIO := {"die": 3, "pain": 2, "mind": 2, "summon": 2, "alert": 1, "shoot": 1, "mate": 2, "reload": 1, "move": 1}


class Active:
	var r: Robot
	var end := 0.0
	var prio := 0


var E: Enemies
var t := 0.0
var active: Array[Active] = []
var last_start := -9.0
var recent: PackedStringArray = []


func _init(en: Enemies) -> void:
	E = en


func update(dt: float) -> void:
	t += dt
	_drop_ended()


func _drop_ended() -> void:
	for i in range(active.size() - 1, -1, -1):
		if not (active[i].end > t):
			active.remove_at(i)


## A bark of this enemy is being spoken right now (a view opens its mouth).
func is_talking(r: Robot) -> bool:
	for a: Variant in active:
		if a.r == r:
			return true
	return false


func say(r: Robot, kind: String) -> bool:
	var P: Player = E.P
	if P == null or r.mute:                                                       # r.mute: the prophet's meat followers only squelch
		return false
	if U.hyp(r.x - P.x, r.z - P.z) > AI.voice_range:                              # nobody would hear it
		return false
	if kind != "die" and r.bark_cd > 0.0:                                         # per-robot cooldown
		return false
	if t - last_start < 0.22:                                                     # global minimum gap
		return false
	_drop_ended()
	var pr: int = BARK_PRIO.get(kind, 0)
	if active.size() >= maxi(1, int(Config.ai_max_voices)):
		var low: Active = null
		for a in active:
			if low == null or a.prio < low.prio or (a.prio == low.prio and a.end < low.end):
				low = a
		if low == null or low.prio >= pr:                                         # global limit: a quieter line never talks over a more important one
			return false
		active.erase(low)
		E.push({"t": "bark_cut", "id": low.r.id})
	var own: Variant = r.bark_set.get(kind) if not r.bark_set.is_empty() else null          # some enemies (the gray alien) bring their own lines
	var fallback: Variant = BARKS.get(kind)      # (a bark only some enemies have, such as a goon's "shoot": the others simply say nothing)
	if own == null and fallback == null:
		return false
	var pool: Array = own if own != null else fallback
	var k := 0
	var tries := 0
	while true:
		k = int(randf() * pool.size())
		tries += 1
		var line := kind + str(k)
		if not (tries < 8 and (recent.has(line) or r.last_line == line)):
			break
	var said := kind + str(k)
	recent.append(said)
	if recent.size() > 4:
		recent.remove_at(0)
	r.last_line = said
	var text: String = pool[k]
	var dur := clampf(0.4 + text.length() * 0.055, 0.7, 2.8)
	var a := Active.new()
	a.r = r
	a.end = t + dur
	a.prio = pr
	active.append(a)
	last_start = t
	if kind == "pain":
		r.bark_cd = 3.2 + randf() * 1.5
	elif kind == "alert":
		r.bark_cd = 8.0
	elif kind == "die":
		r.bark_cd = 0.0
	else:
		r.bark_cd = 4.0 + randf() * 4.0
	E.push({"t": "bark", "id": r.id, "num": r.num, "key": ("alien_" if not r.bark_set.is_empty() else "") + kind + str(k), "text": text, "dur": dur, "kind": kind, "pitch": r.voice,
		"x": r.x, "y": r.y + 1.7 * (r.h / AI.h if r.h != 0.0 else 1.0), "z": r.z, "name": r.name, "speech": r.speech})
	return true
