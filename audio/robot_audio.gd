class_name RobotAudio
extends SynthAudio
## JS enemies/robot-audio.js + robot-sounds.js: how hostile robots sound, through the bounded mixer. Three seeded takes per action, rendered. Identity comes from the enemy's anatomy and weight, never its current level.

const ROBOT_SOUNDS := {
	"robot-step": {"duration": 0.15, "gain": 0.095, "cooldown": 0.16, "limit": 3},
	"robot-hit": {"duration": 0.22, "gain": 0.17, "cooldown": 0.09, "limit": 3},
	"robot-shot": {"duration": 0.2, "gain": 0.19, "cooldown": 0.075, "limit": 3},
	"robot-alert": {"duration": 0.38, "gain": 0.12, "cooldown": 1.6, "limit": 1},
	"robot-charge": {"duration": 0.4, "gain": 0.105, "cooldown": 0.35, "limit": 2},
	"robot-strike": {"duration": 0.24, "gain": 0.19, "cooldown": 0.16, "limit": 2},
	"robot-death": {"duration": 1.05, "gain": 0.29, "cooldown": 0.22, "limit": 2},
	"robot-pop": {"duration": 0.26, "gain": 0.085, "cooldown": 0.22, "limit": 2},
	"boss-step": {"duration": 0.4, "gain": 0.21, "cooldown": 0.35, "limit": 2},
	"boss-impact": {"duration": 0.65, "gain": 0.32, "cooldown": 0.25, "limit": 2},
	"boss-charge": {"duration": 0.7, "gain": 0.16, "cooldown": 0.6, "limit": 1},
	"boss-ram": {"duration": 0.55, "gain": 0.22, "cooldown": 0.4, "limit": 1},
	"boss-missile": {"duration": 0.3, "gain": 0.2, "cooldown": 0.12, "limit": 2},
	"boss-purge": {"duration": 0.9, "gain": 0.19, "cooldown": 0.65, "limit": 1},
	"boss-latch": {"duration": 0.24, "gain": 0.15, "cooldown": 0.2, "limit": 1},
	"boss-rivet": {"duration": 0.24, "gain": 0.23, "cooldown": 0.11, "limit": 2},
	"boss-vent": {"duration": 0.65, "gain": 0.13, "cooldown": 0.5, "limit": 1},
	"boss-sweep": {"duration": 0.7, "gain": 0.17, "cooldown": 0.5, "limit": 1},
	"boss-shutdown": {"duration": 2.4, "gain": 0.35, "cooldown": 2.0, "limit": 1},
}
const PITCH := {"robot": 1.0, "guard": 0.9, "mech": 0.76, "spider": 1.22, "drone": 1.12}


func _init(p_sfx: Variant) -> void:
	super(p_sfx, ROBOT_SOUNDS)


## JS robotSoundKind: "" for anything that is not a stock robot.
static func robot_sound_kind(r: Variant) -> String:
	if r == null or not _f(r, &"robot") or _f(r, &"npc") or _f(r, &"meat") or _f(r, &"human") or CreatureAudio.creature_kind(r) != "":
		return ""
	if _f(r, &"spider"):
		return "spider"
	if _f(r, &"drone"):
		return "drone"
	if _f(r, &"heavy"):
		return "mech" if float(r.max) >= 300.0 else "guard"
	return "robot"


static func _f(r: Variant, name_: StringName) -> bool:
	var v: Variant = r.get(name_)
	return v != null and v != false


func handles(r: Variant) -> bool:
	return robot_sound_kind(r) != ""


func cue(cue_: String, r: Variant, point: Variant = null) -> bool:
	var kind := robot_sound_kind(r)
	if kind == "" or _f(r, &"factory_arrival") or (_f(r, &"dead") and cue_ != "death" and cue_ != "pop"):
		return false
	var at: Variant = r if (point == null or is_same(point, r)) else point
	return play("robot-" + cue_, at, float(PITCH[kind]))


func boss_cue(cue_: String, B: Variant) -> bool:
	return play("boss-" + cue_, func() -> Vector3: return Vector3(B.x, 3.0, B.z))
