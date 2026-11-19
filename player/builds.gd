class_name Builds
extends RefCounted
## The playable characters as data (JS BUILDS, PROG_HOLDS, FLIP_HOLD): everything the animator needs to know about a body.
## Tommy is authored in "design units" at roughly Prog's height, with Prog's bone names and rest rotations, and the whole actor is scaled down, so every one of
## Prog's poses, weapon holds and IK targets carries over. His own build (stubby legs, a wide bean body with no neck, short arms) is described by the numbers below:
##   scale     actor scale (design units -> metres)          pivot   flip / rotation pivot above the feet (design units)
##   l1 l2 ank hip  thigh, shin, ankle height, hip height    cad / stride  cadence and stride multipliers for the gait
##   arm_out   extra arm abduction so the arms clear the body  arm_swing  arm swing multiplier
##   waddle    side-to-side rock over the planted foot         bounce  extra up-down bob per step   head_k  how much the head moves on its own
##   bend      how far the spine folds (crouch, punches)       w_off   per-weapon hold offsets (aim, low, flip; design units), fitted so
##                                                                     the guns clear his round belly      support  left hand slides back
##                                                                     along the gun to a point it can reach instead of over-stretching
##   hang_fit  lift the body while hanging so the hands reach the ledge      skin_fix  Prog-only mesh fixes (waist reskin, straps, shorts)
##   aim_twist / low_twist  bladed stance: how far the chest turns right while aiming (a gun's w_off.twist wins) / carrying a two-handed gun, so the left shoulder comes forward to the gun      relax_l  the free left arm hangs relaxed with a gun out instead of guarding
##   cam_height camera orbit height   muz_*  where shots leave the gun (metres above the feet / forward / right)   dead_drop  death pose drop

class Hold:
	var aim := Vector3.ZERO
	var twist := NAN      # how far the chest turns while aiming (NAN: the build's aim_twist)
	var low := Vector3.ZERO
	var low_yaw := NAN    # how far the carried gun turns across the body (NAN: the default, 0.78)
	var flip := Vector3.ZERO
	var rl := Vector3.ZERO
	var rly := 0.0
	var stock := false    # aimed, the butt goes in the shoulder pocket (a build with Build.stock set)

class Build:
	var id := ""
	var name := ""
	var file := ""
	var blurb := ""
	var scale := 1.0
	var pivot := 0.95
	var l1 := 0.35
	var l2 := 0.30
	var ank := 0.21
	var hip := 0.86
	var cad := 1.0
	var stride := 1.0
	var arm_out := 0.0
	var arm_swing := 1.0
	var waddle := 0.0
	var bounce := 0.0
	var head_k := 1.0
	var bend := 1.0
	var w_off: Dictionary = {}     # weapon id -> Hold
	var aim_twist := 0.0
	var low_twist := 0.0
	var pouch := Vector3.ZERO
	var support := false
	var relax_l := false
	var hang_fit := false
	var skin_fix := false          # runtime mesh fixes tuned to Prog's body (player/prog_v1_fix.gd)
	var grips := ""                # baked hands-on-the-gun grips (tools/v1_grips/bake.py): Prog V1 player/v1_grips.json
	var v1_arms := false           # Prog V1's arm rules in the procedural animator: elbows hang down and out, body avoidance capped
	var stock := Vector3.ZERO      # aimed long guns put the butt plate here: the shoulder pocket, from the right shoulder joint in chest axes (x his left, y up, z forward); ZERO = off
	var cam_height := 1.45
	var muz_y := 1.4
	var muz_crouch := 0.95
	var muz_f := 0.62
	var muz_s := 0.18
	var dead_drop := 0.68

## Weapon hold while flipping (port arms, in chest space: x right is negative, y up, z forward; pitch negative = muzzle up, yaw positive = muzzle to his left)
class FlipHold:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var pitch := 0.0
	var yaw := 0.0
	var roll := 0.0
	func _init(px: float, py: float, pz: float, ppitch: float, pyaw: float, proll: float) -> void:
		x = px
		y = py
		z = pz
		pitch = ppitch
		yaw = pyaw
		roll = proll

static var NO_WOFF := Hold.new()

# Prog's holds. His belly is ~64 cm across and his arms ~62 cm long, so the left hand only reaches a long gun from a bladed stance, with the gun high over the belly (a pistol: a square stance, or the right arm cannot reach).
# Each hold below was searched for in the running game against his real skinned mesh: aim = offset while aiming, twist = how far the chest turns while aiming, low = offset while carrying, low_yaw = how far the carried gun
# turns across the body (default 0.78). tests/gun-hold-browser.cjs fails on a gun without a working hold; a new gun needs an entry here.
const PROG_CARRY := Vector3(0.08, 0.08, -0.025)
const PROG_PISTOL := Vector3(0.0, 0.0, -0.025)
static var PROG_HOLDS: Dictionary = _make_prog_holds()
static var BUILDS: Dictionary = _make_builds()
static var FLIP_HOLD: Dictionary = _make_flip_hold()


static func _prog_hold(aim: Vector3, twist: float, low: Vector3, low_yaw: float = NAN) -> Hold:
	var h := Hold.new()
	h.aim = aim
	h.twist = twist
	h.low = low
	h.low_yaw = low_yaw
	return h


## Prog's own holds: PROG_HOLDS, but the long guns go stock-in-shoulder (Build.stock), and with the gun in the right shoulder his short left arm only reaches the
## handguard from a more side-on stance, so those twist further. Each twist was measured in the running game: the smallest that leaves the left hand ~8-10 cm inside his reach.
## (The Bellows Beast keeps its old hold: no twist under 1.3 rad lets the left hand reach it from the shoulder.)
static func _make_prog_v1_holds() -> Dictionary:
	var src := _make_prog_holds()
	var tw := {"rifle": 1.0, "shotgun": 0.95, "smg": 0.7, "sniper": 1.0, "legacy_rifle": 1.02, "legacy_sniper": 1.0, "legacy_smg": 0.9, "saw": 1.05, "yoke": 0.95, "arc": 0.8}
	for id in tw:
		var h: Hold = src[id]
		h.twist = tw[id]
		h.stock = true
	return src


static func _make_prog_holds() -> Dictionary:
	return {
		"smg": _prog_hold(Vector3(0.04, 0.0, -0.02), 0.3, Vector3(0.08, 0.12, -0.025), 0.78),
		"rifle": _prog_hold(Vector3(-0.04, 0.0, -0.1), 0.75, Vector3(0.08, 0.04, -0.025), 1.0),
		"shotgun": _prog_hold(Vector3(-0.04, 0.0, -0.02), 0.75, Vector3(0.0, 0.04, -0.025), 1.2),
		"sniper": _prog_hold(Vector3(-0.04, 0.0, -0.28), 0.75, Vector3(0.08, 0.12, -0.025), 0.78),
		"rocket": _prog_hold(Vector3(0.0, 0.06, 0.24), 0.75, Vector3(0.16, 0.12, 0.24)),
		"saw": _prog_hold(Vector3(-0.04, 0.0, -0.02), 0.45, PROG_CARRY, 1.0),
		"yoke": _prog_hold(Vector3(-0.04, 0.0, 0.02), 0.6, PROG_CARRY, 1.0),
		"arc": _prog_hold(Vector3(-0.04, 0.0, 0.02), 0.6, PROG_CARRY, 1.0),
		"bellows": _prog_hold(Vector3(0.0, 0.0, 0.02), 0.45, Vector3(0.08, 0.12, 0.03), 1.0),
		"deagle": _prog_hold(Vector3(0.0, 0.0, -0.15), 0.2, PROG_PISTOL),
		"pistol": _prog_hold(Vector3(0.08, 0.0, -0.1), 0.0, PROG_PISTOL),
		"legacy_smg": _prog_hold(Vector3(-0.04, 0.0, -0.06), 0.6, PROG_CARRY),
		"legacy_deagle": _prog_hold(Vector3(-0.04, 0.0, -0.15), 0.3, PROG_PISTOL),
		"legacy_rifle": _prog_hold(Vector3(0.0, 0.0, -0.1), 0.6, PROG_CARRY),
		"legacy_rocket": _prog_hold(Vector3(0.08, 0.09, 0.18), 0.75, Vector3(0.16, 0.12, 0.18)),
		"legacy_sniper": _prog_hold(Vector3(-0.04, 0.0, -0.22), 0.6, Vector3(0.08, 0.04, -0.025)),
		"dual_silenced": _prog_hold(Vector3(0.0, 0.0, -0.05), 0.0, Vector3(0.0, 0.0, 0.03)),
	}


static func _tommy_hold(aim: Vector3, low: Vector3, flip: Vector3, rl: Vector3, rly: float) -> Hold:
	var h := Hold.new()
	h.aim = aim
	h.low = low
	h.flip = flip
	h.rl = rl
	h.rly = rly
	return h


static func _make_prog() -> Build:
	var b := Build.new()
	b.id = "prog"
	b.name = "PROG"
	b.file = "res://assets/prog.glb"
	b.blurb = "Peak performance. The PERFECT weapon. #1 Fat Fuck."
	b.scale = 1.0
	b.pivot = 0.95
	b.l1 = 0.35
	b.l2 = 0.30
	b.ank = 0.21
	b.hip = 0.86
	b.cad = 1.0
	b.stride = 1.0
	b.arm_out = 0.0
	b.arm_swing = 1.0
	b.waddle = 0.0
	b.bounce = 0.0
	b.head_k = 1.0
	b.bend = 1.0
	b.w_off = _make_prog_v1_holds()
	b.aim_twist = 0.6
	b.low_twist = 0.5
	b.pouch = Vector3(0.2, -0.45, 0.12)
	b.support = true
	b.hang_fit = false
	b.skin_fix = true
	b.v1_arms = true
	b.grips = "res://player/v1_grips.json"
	b.stock = Vector3(0.11, -0.03, 0.12)       # (the hollow between his shoulder and collarbone: 11 cm in from the joint, 3 cm down, 12 cm out: the butt presses ~1 cm into the skin, measured on his aimed body)
	b.cam_height = 1.45
	b.muz_y = 1.4
	b.muz_crouch = 0.95
	b.muz_f = 0.62
	b.muz_s = 0.18
	b.dead_drop = 0.68
	return b


static func _make_tommy() -> Build:
	var b := Build.new()
	b.id = "tommy"
	b.name = "TOMMY"
	b.file = "res://assets/tommy.glb"
	b.blurb = "Aura"
	b.scale = 0.68
	b.pivot = 1.0
	b.l1 = 0.25
	b.l2 = 0.23
	b.ank = 0.16
	b.hip = 0.64
	b.cad = 1.6
	b.stride = 0.85
	b.arm_out = 0.18
	b.arm_swing = 1.35
	b.waddle = 1.0
	b.bounce = 1.0
	b.head_k = 0.5
	b.bend = 0.6
	var w := {
		"deagle": _tommy_hold(Vector3(-0.09, 0.09, 0.03), Vector3(-0.03, 0.06, 0.06), Vector3(-0.24, 0.18, 0.24), Vector3(0.18, 0.31, 0.07), 0.6),
		"shotgun": _tommy_hold(Vector3(-0.39, 0.09, -0.03), Vector3(-0.03, 0.06, 0.03), Vector3(-0.33, 0.03, 0.15), Vector3(0.27, 0.19, 0.25), 1.2),
		"rifle": _tommy_hold(Vector3(-0.39, 0.09, -0.06), Vector3(-0.06, 0.0, 0.03), Vector3(-0.33, 0.12, 0.15), Vector3(0.45, 0.19, 0.19), 1.2),
		"smg": _tommy_hold(Vector3(-0.39, 0.12, -0.06), Vector3(-0.0, 0.03, 0.06), Vector3(-0.33, 0.03, 0.15), Vector3(0.45, 0.19, 0.22), 1.2),
		"rocket": _tommy_hold(Vector3(-0.3, 0.15, 0.03), Vector3(-0.3, 0.06, 0.0), Vector3(-0.3, 0.06, 0.0), Vector3(0.23, 0.1, 0.19), 0.2),
		"sniper": _tommy_hold(Vector3(-0.39, 0.15, -0.06), Vector3(-0.09, 0.09, 0.06), Vector3(-0.33, 0.15, 0.24), Vector3(0.45, 0.07, -0.17), 1.2),
	}
	for k: String in ["deagle", "rifle", "smg", "rocket", "sniper"]:
		w["legacy_" + k] = w[k]
	w["pistol"] = w["deagle"]
	w["dual_silenced"] = w["deagle"]
	w["saw"] = w["smg"]
	w["yoke"] = w["rifle"]
	w["arc"] = w["rifle"]
	w["bellows"] = w["rifle"]
	b.w_off = w
	b.pouch = Vector3(0.58, -0.25, 0.15)
	b.support = true
	b.relax_l = true
	b.hang_fit = true
	b.skin_fix = false
	b.cam_height = 1.12
	b.muz_y = 0.98
	b.muz_crouch = 0.66
	b.muz_f = 0.46
	b.muz_s = 0.13
	b.dead_drop = 0.46
	return b


static func _make_builds() -> Dictionary:
	return {"prog": _make_prog(), "tommy": _make_tommy()}


static func _make_flip_hold() -> Dictionary:
	var deagle := FlipHold.new(-0.04, -0.02, 0.30, -1.0, 0.0, 0.0)
	var rifle := FlipHold.new(-0.07, -0.04, 0.28, -0.8, 0.55, 0.0)
	var smg := FlipHold.new(-0.07, -0.04, 0.28, -0.8, 0.55, 0.0)
	var rocket := FlipHold.new(-0.28, 0.24, 0.12, -0.05, 0.0, 0.0)
	var sniper := FlipHold.new(-0.07, -0.04, 0.28, -0.8, 0.55, 0.0)
	return {
		"deagle": deagle,
		"shotgun": FlipHold.new(-0.07, -0.04, 0.28, -0.8, 0.55, 0.0),
		"rifle": rifle,
		"smg": smg,
		"rocket": rocket,
		"sniper": sniper,
		"saw": rifle,
		"yoke": rifle,
		"arc": rifle,
		"bellows": rifle,
		"flail": deagle,
		"pistol": deagle,
		"legacy_smg": smg,
		"dual_silenced": deagle,
		"legacy_deagle": deagle,
		"legacy_rifle": rifle,
		"legacy_rocket": rocket,
		"legacy_sniper": sniper,
	}


## JS characterBuild: the build to play for a character id. (Prog's costumes are gone (user, 2026-11-15): V2 and V3 were deleted, V1 with V3's head is the one Prog.)
static func character_build(id: String) -> Build:
	return BUILDS[id]
