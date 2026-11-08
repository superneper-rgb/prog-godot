class_name HandPose
extends RefCounted
## HAND POSES FOR CUTSCENES (JS cutscenes/hand-pose.js): fingers and wrists on top of the normal animator, for any cutscene where Prog or Tommy really hold things: a bottle, a phone, a cigarette, a gun grip. Call apply after animator.update() and after any arm IK, every frame.
## Hand bone frame (both characters, both hands; measured on the rigs): +Y runs down the fingers, +Z is the index / thumb side, and the palm faces +X on the right hand and -X on the left. Finger bones (index / middle / ring / pinky / thumb _01.._03) curl about their own local X, like _fists().

const FCURL := 1.0
const F4: Array[String] = ["index", "middle", "ring", "pinky"]
const ALL_F: Array[String] = ["index", "middle", "ring", "pinky", "thumb"]
const SIDES: Array[String] = ["R", "L"]
## curl angles [knuckle, middle, tip] per finger, and the thumb
const HAND_POSES := {
	"relax": {"index": [0.25, 0.35, 0.25], "middle": [0.35, 0.45, 0.3], "ring": [0.45, 0.5, 0.35], "pinky": [0.55, 0.55, 0.4], "thumb": [0.1, 0.2, 0.15]},
	"open": {"index": [0.08, 0.1, 0.05], "middle": [0.08, 0.1, 0.05], "ring": [0.1, 0.12, 0.06], "pinky": [0.12, 0.12, 0.08], "thumb": [0.0, 0.05, 0.0]},
	"flat": {"index": [0.03, 0.03, 0.02], "middle": [0.03, 0.03, 0.02], "ring": [0.04, 0.04, 0.03], "pinky": [0.05, 0.05, 0.04], "thumb": [-0.05, 0.0, 0.0]},
	"cyl": {"index": [0.95, 1.05, 0.75], "middle": [1.05, 1.15, 0.8], "ring": [1.1, 1.2, 0.85], "pinky": [1.15, 1.2, 0.85], "thumb": [0.4, 0.55, 0.45]},      # round a bottle / a handle
	"fist": {"index": [1.35, 1.5, 1.1], "middle": [1.35, 1.5, 1.1], "ring": [1.35, 1.5, 1.1], "pinky": [1.35, 1.5, 1.1], "thumb": [0.3, 0.55, 0.45]},
	"phone": {"index": [0.55, 0.65, 0.4], "middle": [0.7, 0.8, 0.5], "ring": [0.8, 0.85, 0.55], "pinky": [0.9, 0.9, 0.6], "thumb": [0.25, 0.4, 0.3]},      # a flat thing in the palm
	"pinch": {"index": [0.45, 0.55, 0.4], "middle": [0.4, 0.5, 0.35], "ring": [1.15, 1.3, 0.9], "pinky": [1.2, 1.3, 0.9], "thumb": [0.5, 0.65, 0.5]},      # a cigarette, the edge of a photo
	"drag": {"index": [0.2, 0.25, 0.15], "middle": [0.2, 0.25, 0.15], "ring": [1.1, 1.25, 0.85], "pinky": [1.15, 1.25, 0.85], "thumb": [0.35, 0.4, 0.3]},   # V of two fingers at the lips
	"pistol": {"index": [0.7, 0.8, 0.55], "middle": [1.25, 1.35, 0.95], "ring": [1.25, 1.3, 0.9], "pinky": [1.2, 1.25, 0.85], "thumb": [0.25, 0.45, 0.35]},  # index along the trigger guard
	"knob": {"index": [0.85, 0.95, 0.7], "middle": [0.9, 1.0, 0.75], "ring": [0.95, 1.05, 0.75], "pinky": [1.0, 1.05, 0.75], "thumb": [0.35, 0.5, 0.4]},
}
## held props in the hand frame: pos with x = towards the palm (mirrored for the left hand), rot = Euler of the prop in the hand frame
const GRIPS := {
	"bottle": {"pos": Vector3(0.065, 0.06, -0.09), "rot": Vector3(PI / 2.0, 0.0, 0.0)},                  # a cylinder across the palm: its +Y (the neck) out of the thumb side
	"phone": {"pos": Vector3(0.045, 0.07, 0.0), "rot": Vector3(0.0, PI / 2.0, 0.0), "mirror_rot": true},    # lying in the palm, screen facing out of it, top along the fingers
	"lighter": {"pos": Vector3(0.04, 0.05, 0.01), "rot": Vector3(PI / 2.0, 0.0, 0.0)},                   # in the fist, flame end out of the thumb side
	"cig": {"pos": Vector3(0.02, 0.1, 0.03), "rot": Vector3(PI / 2.0, 0.0, 0.0)},                        # pinched, pointing out of the thumb side
	"wallet": {"pos": Vector3(0.04, 0.07, 0.0), "rot": Vector3(0.0, PI / 2.0, 0.0), "mirror_rot": true},
	"mag": {"pos": Vector3(0.04, 0.05, 0.02), "rot": Vector3(PI / 2.0, 0.0, 0.0)},
}
const PALM := Vector3(0.03, 0.065, 0.0)                                                     # palm centre from the wrist


## A wrist aim in world directions: where the palm faces, and where the thumb side or the fingers point
class Aim:
	var palm := Vector3.ZERO
	var thumb: Variant = null
	var fingers: Variant = null

	func _init(p: Vector3, t: Variant = null, f: Variant = null) -> void:
		palm = p
		thumb = t
		fingers = f


class Hand:
	var pose := {}
	var goal_pose := "relax"
	var aim: Aim = null
	var goal_aim: Aim = null
	var q := Quaternion.IDENTITY
	var aim_w := 0.0


var state := {"R": _mk(), "L": _mk()}


static func _sx(side: String) -> float:
	return 1.0 if side == "R" else -1.0


static func _clone_pose(p: Dictionary) -> Dictionary:
	var o := {}
	for k: String in p:
		o[k] = (p[k] as Array).duplicate()
	return o


static func _mk() -> Hand:
	var h := Hand.new()
	h.pose = _clone_pose(HAND_POSES["relax"])
	return h


## the world orientation of a hand bone whose palm faces `palm` and whose thumb side (or fingers) points along the other vector
static func hand_quat(side: String, a: Aim) -> Quaternion:
	var x := a.palm.normalized() * _sx(side)                           # local +X (the palm on the right hand, the back of it on the left)
	var y: Vector3
	var z: Vector3
	if a.thumb != null:
		var t: Vector3 = a.thumb
		z = (t - x * t.dot(x)).normalized()
		y = z.cross(x)
	else:
		var f: Vector3 = a.fingers
		y = (f - x * f.dot(x)).normalized()
		z = x.cross(y)
	return Basis(x, y, z).get_rotation_quaternion()


static func palm_point(side: String, q: Quaternion) -> Vector3:
	return q * Vector3(PALM.x * _sx(side), PALM.y, PALM.z)


## where a held prop sits: [world position, world rotation]
static func grip_xf(an: Animator, side: String, grip: String) -> Array:
	var g: Dictionary = GRIPS[grip] if GRIPS.has(grip) else GRIPS["phone"]
	var b: int = an.by_key[StringName("hand" + side)].bone
	var s := _sx(side)
	var q := an.bone_world_quat(b)
	var pp: Vector3 = g["pos"]
	var r: Vector3 = g["rot"]
	return [an.bone_world_pos(b) + q * Vector3(pp.x * s, pp.y, pp.z), q * Animator.q_xyz(r.x, r.y * s if g.get("mirror_rot", false) else r.y, r.z)]


## what the hand should do: a finger pose name (HAND_POSES) and a wrist aim (null = leave the wrist to the arm). Goals ease in over about a fifth of a second.
func goal(side: String, pose: String, a: Aim) -> void:
	var h: Hand = state[side]
	h.goal_pose = pose if HAND_POSES.has(pose) else "relax"
	h.goal_aim = a


## eases toward the goals, turns the hand bones, curls the fingers (with a little idle life)
func apply(an: Animator, dt: float, time: float) -> void:
	var k := 1.0 - exp(-12.0 * maxf(0.0, dt))
	var kp := 1.0 - exp(-10.0 * maxf(0.0, dt))
	for side: String in SIDES:
		var h: Hand = state[side]
		var hb: Animator.BoneRec = an.by_key.get(StringName("hand" + side))
		if hb == null:
			continue
		# wrist
		if h.goal_aim != null:
			var gq := hand_quat(side, h.goal_aim)
			h.q = gq if h.aim_w < 0.001 else h.q.slerp(gq, k)
		h.aim_w += ((1.0 if h.goal_aim != null else 0.0) - h.aim_w) * k
		if h.aim_w > 0.002:
			var pb := an.skel.get_bone_parent(hb.bone)
			var ql := Animator.q_inv(an.bone_world_quat(pb)) * h.q
			an.skel.set_bone_pose_rotation(hb.bone, an.skel.get_bone_pose_rotation(hb.bone).normalized().slerp(ql.normalized(), h.aim_w))
		# fingers (with a little life when they are not holding on to something)
		var gp: Dictionary = HAND_POSES[h.goal_pose]
		var loose := 1.0 if h.goal_pose == "relax" or h.goal_pose == "open" else 0.25
		for nm: String in ALL_F:
			var cur: Array = h.pose[nm]
			var tgt: Array = gp[nm]
			var fi := F4.find(nm)      # (thumb: -1, as the JS's indexOf)
			for j in 3:
				cur[j] += (float(tgt[j]) - float(cur[j])) * kp
				var rec: Animator.BoneRec = an.by_key.get(StringName("%s_0%d%s" % [nm, j + 1, side]))
				if rec == null:
					continue
				var life := 0.07 * loose * sin(time * (0.9 + fi * 0.23) + (0.0 if side == "R" else 2.1) + fi * 1.7) if j == 0 else 0.0
				an.skel.set_bone_pose_rotation(rec.bone, rec.rest * Animator.q_axis(Vector3.RIGHT, FCURL * (float(cur[j]) + life)))


## jump straight to the goals (after a seek / a camera cut)
func snap() -> void:
	for side: String in SIDES:
		var h: Hand = state[side]
		h.pose = _clone_pose(HAND_POSES[h.goal_pose])
		h.aim_w = 1.0 if h.goal_aim != null else 0.0
		if h.goal_aim != null:
			h.q = hand_quat(side, h.goal_aim)
