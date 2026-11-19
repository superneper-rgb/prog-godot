class_name ClubDance
extends RefCounted
## CLUB 9's dancing for the city goths (tools/folk rigs), baked at load into FolkSkin's idle rows: a phrase of 32 beats in four 8-beat moves, posed by where the hands and feet go
## rather than by bone angles. Each arm is solved as two bones with its elbow out and back, and any hand, elbow or forearm that would end up inside the body is pushed out first,
## against the body's own outline measured from its mesh. The legs solve onto planted (or stepping) feet the same way.
## (Replaces the club's first dance, 2026-11-16: its euler turns swung the arms about the body's forward axis, into the chest and hips, and twisted them past what the kit's skin
## weights hold; the user saw the goth girls' arms tearing and passing through their bodies.)

const BEATS := 32                       # one phrase: four moves of 8 beats
const MOVE_BEATS := 8
const ROWS_PER_BEAT := 12
const BAND := 0.05                      # the body outline's height step (m)
const MIN_OUT := 0.26                   # how far out from its shoulder a hand always stays (arm lengths)
const MARGIN := 0.075                   # how far outside the outline a hand or forearm stays (an arm's own thickness and a little air)

enum { GROOVE, ROCK, BOUNCE, SWAY, NOD, FLIRT }

## Which moves each species dances, in order, and what its body allows.
## (2026-11-16, second pass: the first set had shimmies that twisted the chest, overhead arm circles and fist pumps; on these bodies they read as stiff and the arms
## crossed through the torso. Real floor dancing is mostly a bounce and a weight shift with loose or bent arms: these are that, small and smooth.)
const ROUTINES := {
	"lilac_spider": [GROOVE, ROCK, BOUNCE, ROCK],
	"manta_goth": [BOUNCE, GROOVE, ROCK, GROOVE],
	"snakeneck": [ROCK, GROOVE, SWAY, GROOVE],
	"naga": [SWAY, ROCK, SWAY, GROOVE],
	"demon_tail": [NOD, BOUNCE, NOD, BOUNCE],
	"fish_biker": [NOD, NOD, NOD, NOD],
}
## How high a hand may go (arm lengths above the shoulder), for a species whose clothes cannot take a raised arm: the snakeneck's jacket goes from chest to arm in one
## step at the shoulder, and opens up there when her hands go over her head.
## The manta's sleeves are skinned to her chest under the arm, and web out there when her hands go over her head.
const ARM_CEILING := {"snakeneck": 0.05, "manta_goth": 0.15}
## Arms left as they hang: the biker keeps his hands in his pockets; the demon keeps his jacket hand over his shoulder and the other where his model has it, against his
## thigh (they are meshed together). (The manta's cuffs were meshed into her skirt too, until her arms were hung further out: tools/folk/recipes/manta_goth.py, 2026-11-16.)
const NO_ARMS := {"fish_biker": ["L", "R"], "demon_tail": ["L", "R"]}
## Feet kept planted and the knees bent only so far (a share of the dip).
## The demon's free hand rests against his thigh and the biker's long coat hangs between his knees, both meshed into the leg: their feet stay planted too. The
## spider keeps her steps but dips less: a deep knee bend creases her boot at the ankle.
const LEGS_STILL := {"demon_tail": 0.45, "fish_biker": 0.25, "lilac_spider": 0.75}
## Hands meshed into the body (the biker's in his pockets, the demon's free one against his thigh): kept where they are on the bone they are meshed into, the arm
## solved to follow.
const PIN_HANDS := {"fish_biker": {"L": "hips", "R": "hips"}, "demon_tail": {"L": "thigh.L"}}
## Arms kept loose at the sides through every move: the spider's and the snakeneck's forearms are so long that bent arms bring them across the waist.
const LOOSE_ARMS := ["lilac_spider", "snakeneck"]
const EXCLUDE := ["tail", "jacket", "coat", "ruffle", "upper_arm", "forearm", "hand", "arm2", "fore2", "hand2", "shoulder"]   # parts that are not the body an arm must miss


## One moment of a move, in body terms (+x is the dancer's left, +z its front).
class Frame:
	var dip := 0.0                      # hips drop (m)
	var sway := 0.0                     # hips sideways (m)
	var hip_yaw := 0.0
	var hip_roll := 0.0
	var lean := 0.0                     # torso pitch forward (rad)
	var twist := 0.0                    # chest yaw against the hips
	var tilt := 0.0                     # torso roll
	var nod := 0.0                      # head pitch down
	var head_yaw := 0.0
	var head_roll := 0.0
	var hand_l := Vector3(0.18, -0.9, 0.12)     # from the shoulder in chest axes, in arm lengths; x is outward on that side
	var hand_r := Vector3(0.18, -0.9, 0.12)
	var lift_l := 0.0                   # foot lift (m)
	var lift_r := 0.0
	var step_l := Vector3.ZERO          # foot offset (m, body axes, x outward on that side)
	var step_r := Vector3.ZERO
	var wrist := 0.0                    # hand flick (rad)
	var curve := 0.0                    # a long neck bending forward toward someone (snakeneck at the bar)

	func mix(o: Frame, k: float) -> Frame:
		var f := Frame.new()
		f.dip = lerpf(dip, o.dip, k)
		f.sway = lerpf(sway, o.sway, k)
		f.hip_yaw = lerpf(hip_yaw, o.hip_yaw, k)
		f.hip_roll = lerpf(hip_roll, o.hip_roll, k)
		f.lean = lerpf(lean, o.lean, k)
		f.twist = lerpf(twist, o.twist, k)
		f.tilt = lerpf(tilt, o.tilt, k)
		f.nod = lerpf(nod, o.nod, k)
		f.head_yaw = lerpf(head_yaw, o.head_yaw, k)
		f.head_roll = lerpf(head_roll, o.head_roll, k)
		f.hand_l = hand_l.lerp(o.hand_l, k)
		f.hand_r = hand_r.lerp(o.hand_r, k)
		f.lift_l = lerpf(lift_l, o.lift_l, k)
		f.lift_r = lerpf(lift_r, o.lift_r, k)
		f.step_l = step_l.lerp(o.step_l, k)
		f.step_r = step_r.lerp(o.step_r, k)
		f.wrist = lerpf(wrist, o.wrist, k)
		f.curve = lerpf(curve, o.curve, k)
		return f


var species := ""
var routine: Array = []
var _ready := false
var _feet: Array[Transform3D] = []
var _knees := PackedVector3Array()
var _reach := {}                        # upper bone -> the arm's full length
var _seg := {}                          # upper bone -> Vector2(upper length, lower length)
var _hand := {}                         # upper bone -> how far its fingers reach past the wrist (from the mesh)
var _pins := {}                         # side -> [hand pose, elbow, carrying bone's pose, carrying bone] at the first idle frame, for PIN_HANDS
var _half_w := PackedFloat32Array()     # the body outline per height band: half width, front, back (rest pose, skeleton space)
var _front := PackedFloat32Array()
var _back := PackedFloat32Array()
var _base_pos: Array[Vector3] = []     # every bone's pose at the first idle frame, restored before each row
var _base_rot: Array[Quaternion] = []
var _head_y := INF                      # from here up the outline is the head: a hand is moved off to the side there, never left in front of the face


## `moves`: four moves of 8 beats to dance instead of the species' own (the bar's flirt is [FLIRT] x 4).
func _init(sid: String, moves: Array = []) -> void:
	species = sid
	routine = moves if moves.size() == BEATS / MOVE_BEATS else ROUTINES.get(sid, [NOD, NOD, NOD, NOD])


## The phrase in seconds at the club's tempo.
static func phrase_seconds() -> float:
	return float(BEATS) / ClubLevel.BEAT_HZ


static func rows() -> int:
	return BEATS * ROWS_PER_BEAT


# ---- the moves -------------------------------------------------------------------------------------------------------------------------------

## On the beat the body drops: 1 on the beat, 0 half way between (a plain cosine: knees give and come back, no snap).
static func _hit(b: float) -> float:
	return 0.5 + 0.5 * cos(TAU * b)


## Bent arms at the waist, forearms forward, moving a little with the bass; `alt` 1 lets the two hands go up and down in turn.
static func _bent(f: Frame, b: float, alt: float) -> void:
	var bob := 0.05 * cos(TAU * (b - 0.12))      # (the hands come a moment after the knees)
	var turn_l := 0.025 * alt * sin(PI * b)
	f.hand_l = Vector3(0.36, -0.46 + bob + turn_l, 0.4)
	f.hand_r = Vector3(0.36, -0.46 + bob - turn_l, 0.4)
	f.wrist = 0.12 * cos(TAU * (b - 0.2))


## Arms loose at the sides, swinging a little forward and back with the sway.
static func _loose(f: Frame, w: float) -> void:
	f.hand_l = Vector3(0.27, -0.84, 0.2 + 0.06 * w)
	f.hand_r = Vector3(0.27, -0.84, 0.2 - 0.06 * w)
	f.wrist = 0.08 * w


## Move `m` at beat b (0..8).
static func frame(m: int, b: float) -> Frame:
	var f := Frame.new()
	var hit := _hit(b)
	match m:
		GROOVE:     # the club two-step: the weight goes onto one foot for a beat then the other, the free heel comes up, the knees give on every beat, arms bent
			var w := sin(PI * b)                # +1 weight on the left
			f.sway = 0.04 * w
			f.hip_roll = -0.05 * w
			f.tilt = 0.02 * w
			f.dip = 0.015 + 0.02 * hit
			f.lean = 0.03
			f.nod = 0.02 + 0.06 * hit
			f.head_roll = 0.04 * w
			f.lift_l = 0.025 * maxf(0.0, -w)
			f.lift_r = 0.025 * maxf(0.0, w)
			_bent(f, b, 1.0)
		ROCK:       # side to side over two beats each way, arms loose at the sides, the head going with it
			var w := sin(PI * b / 2.0)
			f.sway = 0.05 * w
			f.hip_roll = -0.06 * w
			f.tilt = 0.025 * w
			f.dip = 0.015 + 0.015 * hit
			f.nod = 0.04 * hit
			f.head_roll = 0.06 * sin(PI * b / 2.0 - 0.4)
			f.lift_l = 0.02 * maxf(0.0, -w)
			f.lift_r = 0.02 * maxf(0.0, w)
			_loose(f, w)
		BOUNCE:     # on the spot, the knees on every beat, the head nodding, the arms bent and bobbing together
			f.dip = 0.02 + 0.03 * hit
			f.nod = 0.03 + 0.1 * hit
			f.lean = 0.04
			f.sway = 0.015 * sin(PI * b / 2.0)
			f.hip_roll = -0.02 * sin(PI * b / 2.0)
			_bent(f, b, 0.0)
		SWAY:       # slow: the hips over to one side and back across four beats, the shoulders and head following, hands low
			var w := sin(PI * b / 4.0)
			f.sway = 0.055 * w
			f.hip_roll = -0.07 * w
			f.tilt = 0.03 * w
			f.dip = 0.015 + 0.01 * hit
			f.nod = -0.03 + 0.03 * hit
			f.head_roll = 0.07 * sin(PI * b / 4.0 - 0.5)
			f.lift_l = 0.015 * maxf(0.0, -w)
			f.lift_r = 0.015 * maxf(0.0, w)
			_loose(f, w)
		FLIRT:      # at the bar, not dancing: hip cocked, one hand on the counter, the other on her hip, the neck curving down toward him; a laugh on beat 5
			var ph := PI * b / 4.0
			var laugh := pow(maxf(0.0, sin(PI * clampf((b - 4.4) / 1.6, 0.0, 1.0))), 1.5)
			f.sway = 0.05 + 0.012 * sin(ph)
			f.hip_roll = -0.11 - 0.02 * sin(ph)
			f.hip_yaw = -0.12
			f.twist = -0.1 + 0.03 * sin(ph)
			f.tilt = -0.04
			f.lean = 0.06 + 0.06 * laugh
			f.curve = 0.75 + 0.08 * sin(ph + 0.6) - 0.25 * laugh
			f.nod = -0.1 + 0.08 * sin(ph) - 0.3 * laugh
			f.head_roll = 0.2 + 0.05 * sin(ph * 0.5)
			f.head_yaw = -0.25
			f.hand_l = Vector3(0.24, -0.88, 0.12)
			f.hand_r = Vector3(0.3 + 0.02 * sin(ph * 2.0), -0.7 + 0.03 * sin(ph * 2.0 + 1.0) + 0.05 * laugh, 0.14)      # (on her hip: a hand at her necklace crossed the forearm over her chest)
			f.wrist = 0.25 * sin(ph * 2.0)
			f.step_r = Vector3(-0.03, 0.0, 0.07)
			f.lift_r = 0.035
		NOD:        # too cool to dance: the nod and a small bounce
			f.dip = 0.015 + 0.025 * hit
			f.nod = 0.03 + 0.12 * hit
			f.sway = 0.025 * sin(PI * b / 2.0)
			f.hip_roll = -0.03 * sin(PI * b / 2.0)
	return f


## The phrase at beat b (0..BEATS): the move of that 8 beats, easing into the next over its last beat.
func at(b: float) -> Frame:
	b = fposmod(b, float(BEATS))
	var k := int(floorf(b / MOVE_BEATS))
	var lb := b - k * MOVE_BEATS
	var f := frame(routine[k], lb)
	var tail := lb - (MOVE_BEATS - 1.0)
	if tail > 0.0:
		f = f.mix(frame(routine[(k + 1) % routine.size()], 0.0), smoothstep(0.0, 1.0, tail))
	return f


# ---- the bake -------------------------------------------------------------------------------------------------------------------------------

## FolkSkin's idle_pose: called with the model at its first idle frame, u over the phrase.
func sample(sk: Skeleton3D, u: float) -> void:
	if not _ready:
		_prepare(sk)
		_base_pos.clear()
		_base_rot.clear()
		for i in sk.get_bone_count():
			_base_pos.append(sk.get_bone_pose_position(i))
			_base_rot.append(sk.get_bone_pose_rotation(i))
	# every bone back to the first idle frame: the turns below add to a bone's pose, and seeking the idle clip only resets the bones it keys. The rest
	# (shoulders, hair, ears...) kept every earlier row's turn, so over the 384 rows the shoulders wound round and carried the arms into the body.
	for i in _base_pos.size():
		sk.set_bone_pose_position(i, _base_pos[i])
		sk.set_bone_pose_rotation(i, _base_rot[i])
	var b := u * BEATS
	var f := at(b)
	var naga := species == "naga"
	# hips: drop, sway, roll and turn (the naga sways on her coil and does not drop)
	var hip := sk.find_bone("hips")
	var hp := sk.get_bone_parent(hip)
	var hframe := sk.get_bone_global_pose(hp).basis if hp >= 0 else Basis.IDENTITY
	if LEGS_STILL.has(species):
		var k: float = LEGS_STILL[species]
		f.dip *= k
		f.sway *= k
		f.hip_roll *= k
		f.hip_yaw *= k
		if k < 0.7:
			f.lift_l = 0.0
			f.lift_r = 0.0
			f.step_l = Vector3.ZERO
			f.step_r = Vector3.ZERO
	var off := Vector3(f.sway * (0.5 if naga else 1.0), 0.0 if naga else -f.dip, 0.0)
	sk.set_bone_pose_position(hip, sk.get_bone_pose_position(hip) + hframe.inverse() * off)
	turn(sk, "hips", Vector3(f.lean * 0.15, f.hip_yaw * (1.6 if naga else 1.0), f.hip_roll * (1.4 if naga else 1.0)))
	turn(sk, "spine", Vector3(f.lean * 0.4, f.twist * 0.4, f.tilt * 0.5 - f.hip_roll * 0.45))
	turn(sk, "chest", Vector3(f.lean * 0.45, f.twist * 0.6, f.tilt * 0.5 - f.hip_roll * 0.35))
	if sk.find_bone("neck1") >= 0:      # snakeneck: the long neck carries the groove up to the head in a wave
		for j in 3:
			var bend: float = f.curve * float([0.45, 0.4, -0.35][j])      # (forward at the base, back up at the head: an S toward whoever she is talking to)
			var groove := 0.0 if f.curve > 0.0 else 1.0
			turn(sk, "neck%d" % (j + 1), Vector3(bend + f.nod * 0.18 + groove * 0.05 * sin(PI * b - j * 0.7), f.head_yaw * 0.25 + groove * 0.07 * sin(PI * b / 2.0 - j * 0.6), groove * 0.05 * sin(PI * b / 2.0 - j * 0.8)))
	else:
		turn(sk, "neck", Vector3(f.nod * 0.35, f.head_yaw * 0.4, f.head_roll * 0.4))
	turn(sk, "head", Vector3(f.nod * 0.65, f.head_yaw * 0.6, f.head_roll * 0.6))
	# the parts that swing on their own
	for side: String in ["L", "R"]:
		var s := 1.0 if side == "L" else -1.0
		var h := _hit(b)
		turn(sk, "lobe." + side, Vector3(0.05 * h, 0.0, s * 0.07 * h))
		turn(sk, "ear." + side, Vector3(0.1 * h, 0.0, s * 0.12 * h))
		turn(sk, "shoulder." + side, Vector3(0.0, 0.0, s * 0.03 * h))
	turn(sk, "hair", Vector3(0.08 * _hit(b), 0.0, 0.06 * sin(PI * b / 2.0)))
	turn(sk, "ruffle", Vector3(0.05 * _hit(b), 0.0, 0.05 * sin(PI * b / 2.0)))
	turn(sk, "sash", Vector3(0.02 * sin(PI * b / 2.0), 0.0, 0.015 * _hit(b)))      # (small: its foot is meshed against her thigh)
	for j in 8:
		if naga:        # her coil: a slow wave down the tail, the front of it lifting with the beat
			turn(sk, "tail%d" % (j + 1), Vector3(0.0, 0.1 * sin(PI * b / 2.0 - j * 0.6), 0.0))
		else:           # the demon's tail flicks behind him
			turn(sk, "tail%d" % (j + 1), Vector3(0.06 * sin(PI * b - j * 0.5), 0.22 * sin(PI * b - j * 0.7), 0.0))
	# legs onto their feet
	if not _feet.is_empty():
		for j in 2:
			var side := "L" if j == 0 else "R"
			var s := 1.0 if j == 0 else -1.0
			var foot := _feet[j]
			var st := f.step_l if j == 0 else f.step_r
			var lift := f.lift_l if j == 0 else f.lift_r
			foot.origin += Vector3(s * st.x, st.y + lift, st.z)
			foot.basis = Basis(Vector3.RIGHT, lift * 0.7) * foot.basis      # the toe drops a little as the boot lifts (more creases the ankle)
			plant(sk, side, foot, _knees[j] + Vector3(0.0, 0.0, 0.35))
	# pinned hands: where the bone they are meshed into carries them, the arm follows
	for side: String in _pins:
		var pin: Array = _pins[side]
		var carrier_now := sk.get_bone_global_pose(sk.find_bone(pin[3]))
		var carry: Transform3D = carrier_now * (pin[2] as Transform3D).affine_inverse()
		var hand_to: Transform3D = carry * (pin[0] as Transform3D)
		var s := 1.0 if side == "L" else -1.0
		two_bone(sk, sk.find_bone("upper_arm." + side), sk.find_bone("forearm." + side), sk.find_bone("hand." + side), hand_to.origin, carry * (pin[1] as Vector3) + carry.basis * Vector3(s * 0.2, 0.0, -0.1))
		world_basis(sk, sk.find_bone("hand." + side), hand_to.basis)
	# arms onto their hands
	if LOOSE_ARMS.has(species) and routine[0] != FLIRT:
		_loose(f, sin(PI * b / 2.0))
	var still: Array = NO_ARMS.get(species, [])
	for side: String in ["L", "R"]:
		if still.has(side):
			continue
		var s := 1.0 if side == "L" else -1.0
		var hand := f.hand_l if side == "L" else f.hand_r
		hand.x = maxf(hand.x, MIN_OUT)      # never in toward the middle: a hand inside its own shoulder drags the forearm across the body
		if ARM_CEILING.has(species):
			hand = Vector3(minf(hand.x, 0.42), minf(hand.y, float(ARM_CEILING[species])), hand.z)
		turn(sk, "shoulder." + side, Vector3(0.0, 0.0, s * 0.32 * clampf(hand.y, 0.0, 1.0)))      # the collarbone rises with a raised arm, so the shoulder does not crumple
		_arm(sk, s, "upper_arm." + side, "forearm." + side, "hand." + side, hand, "chest")
		turn(sk, "hand." + side, Vector3(f.wrist * 0.6, 0.0, s * f.wrist * 0.4))
		if sk.find_bone("arm2." + side) >= 0:     # the spider's lower pair: out at the waist, rolling a slow wave behind the upper pair
			var w := sin(PI * b / 2.0 + (0.0 if side == "L" else PI))
			_arm(sk, s, "arm2." + side, "fore2." + side, "hand2." + side, Vector3(0.6, -0.5 + 0.08 * w, 0.32 + 0.04 * cos(PI * b / 2.0)), "spine")
			turn(sk, "hand2." + side, Vector3(0.1 * w, 0.0, 0.0))


## Rest lengths, planted feet and the body's outline, read once from the model.
func _prepare(sk: Skeleton3D) -> void:
	_ready = true
	if sk.find_bone("foot.L") >= 0:
		for side: String in ["L", "R"]:
			_feet.append(sk.get_bone_global_pose(sk.find_bone("foot." + side)))
			_knees.append(sk.get_bone_global_pose(sk.find_bone("shin." + side)).origin)
	var pins: Dictionary = PIN_HANDS.get(species, {})
	for side: String in pins:
		var carrier: String = pins[side]
		_pins[side] = [sk.get_bone_global_pose(sk.find_bone("hand." + side)), sk.get_bone_global_pose(sk.find_bone("forearm." + side)).origin, sk.get_bone_global_pose(sk.find_bone(carrier)), carrier]
	for pre: Array in [["upper_arm.", "forearm.", "hand."], ["arm2.", "fore2.", "hand2."]]:
		for side: String in ["L", "R"]:
			var a := sk.find_bone(pre[0] + side)
			if a < 0:
				continue
			var p0 := sk.get_bone_global_rest(a).origin
			var p1 := sk.get_bone_global_rest(sk.find_bone(pre[1] + side)).origin
			var p2 := sk.get_bone_global_rest(sk.find_bone(pre[2] + side)).origin
			_seg[pre[0] + side] = Vector2(p0.distance_to(p1), p1.distance_to(p2))
			_reach[pre[0] + side] = p0.distance_to(p1) + p1.distance_to(p2)
	_measure(sk)


## The body's outline from its own mesh in the rest pose: per 5 cm of height, how wide, how far forward and back the parts an arm must miss reach.
func _measure(sk: Skeleton3D) -> void:
	var n := int(2.8 / BAND)
	var hb := sk.find_bone("head")
	if hb >= 0:
		_head_y = sk.get_bone_global_rest(hb).origin.y - 0.08
	_half_w.resize(n)
	_front.resize(n)
	_back.resize(n)
	_half_w.fill(-1.0)
	_front.fill(-INF)
	_back.fill(INF)
	var root: Node = sk.owner if sk.owner != null else sk.get_parent()
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		return
	var mi: MeshInstance3D = found[0]
	var skin := mi.skin
	var skip := PackedByteArray()
	skip.resize(skin.get_bind_count())
	for i in skin.get_bind_count():
		var bn := String(skin.get_bind_name(i))
		for e: String in EXCLUDE:
			if bn.begins_with(e):
				skip[i] = 1
	var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bi: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var bw: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bi.size() / maxi(v.size(), 1)
	# how far each hand's fingers reach past its wrist: an arm is kept off the body to its fingertips
	for up: String in _seg.keys():
		var hand_name: String = up.replace("upper_arm", "hand").replace("arm2", "hand2")
		var bind := -1
		for i in skin.get_bind_count():
			if String(skin.get_bind_name(i)) == hand_name:
				bind = i
		var wrist := sk.get_bone_global_rest(sk.find_bone(hand_name)).origin
		var far := 0.06
		for k in v.size():
			for j in per:
				if bi[k * per + j] == bind and bw[k * per + j] > 0.5:
					far = maxf(far, v[k].distance_to(wrist))
		_hand[up] = far
	for k in v.size():
		var w_out := 0.0
		for j in per:
			if skip[bi[k * per + j]] == 1:
				w_out += bw[k * per + j]
		if w_out > 0.5:
			continue
		var p := v[k]
		var band := int(p.y / BAND)
		if band < 0 or band >= n:
			continue
		_half_w[band] = maxf(_half_w[band], absf(p.x))
		_front[band] = maxf(_front[band], p.z)
		_back[band] = minf(_back[band], p.z)
	# one band of spread either way, so a point between two samples is still held off
	var hw := _half_w.duplicate()
	var fr := _front.duplicate()
	var bk := _back.duplicate()
	for i in n:
		for d in [-1, 1]:
			var j: int = i + d
			if j < 0 or j >= n or hw[j] < 0.0:
				continue
			_half_w[i] = maxf(_half_w[i], hw[j])
			_front[i] = maxf(_front[i], fr[j])
			_back[i] = minf(_back[i], bk[j])


## Is a rest-space point inside the outline (with the margin)? Returns the point pushed out to the outline's edge, or the point itself. `s` is the arm's side (+1 left).
## At head height the zone runs on out in front of the face, and a point in it goes sideways: a hand beside the head, never over the face.
func _outside(p: Vector3, s: float) -> Vector3:
	var band := int(p.y / BAND)
	if band < 0 or band >= _half_w.size() or _half_w[band] < 0.0:
		return p
	var w := _half_w[band] + MARGIN
	if p.y >= _head_y:
		w += 0.03
		if absf(p.x) < w and p.z > _back[band] - MARGIN and p.z < _front[band] + 0.32:
			return Vector3(s * w, p.y, p.z)
		return p
	var zc := (_front[band] + _back[band]) * 0.5
	var d := (_front[band] - _back[band]) * 0.5 + MARGIN
	var q := Vector2(p.x / w, (p.z - zc) / d)
	var e := q.length()
	if e >= 1.0:
		return p
	if e < 0.05:
		q = Vector2(0.0, 1.0)      # dead centre: out the front
	else:
		q /= e
	return Vector3(q.x * w, p.y, zc + q.y * d)


## One arm onto its hand target: target and elbow are kept outside the body (in the frame of `frame_bone`, mapped back to the rest pose to test), the elbow out and back.
func _arm(sk: Skeleton3D, s: float, upper: String, lower: String, end: String, off: Vector3, frame_bone: String) -> void:
	var iu := sk.find_bone(upper)
	var il := sk.find_bone(lower)
	var ie := sk.find_bone(end)
	var ib := sk.find_bone(frame_bone)
	if iu < 0 or il < 0 or ie < 0 or ib < 0:
		return
	var fb := sk.get_bone_global_pose(ib)
	var to_rest := sk.get_bone_global_rest(ib) * fb.affine_inverse()
	var to_pose := to_rest.affine_inverse()
	var cb := fb.basis.orthonormalized()
	var sh := sk.get_bone_global_pose(iu).origin
	var seg: Vector2 = _seg[upper]
	var reach: float = _reach[upper]
	var target := sh + cb * Vector3(s * off.x, off.y, off.z) * reach
	var pole := sh + cb * Vector3(s * 0.75, -0.45, -0.55)
	var tip := 1.0 + float(_hand.get(upper, 0.08)) / seg.y          # the fingertips, along the forearm past the wrist
	for it in 6:
		target = to_pose * _outside(to_rest * target, s)
		var el := elbow(sh, target, seg.x, seg.y, pole)
		var bad := false
		for t: float in [0.0, 0.35, 0.7, 1.0, (1.0 + tip) * 0.5, tip]:
			var pt := el.lerp(target, t)
			if not (to_pose * _outside(to_rest * pt, s)).is_equal_approx(pt):
				bad = true
				break
		if not bad:
			break
		pole += cb * Vector3(s * 0.35, 0.0, -0.1)                       # swing the elbow further out
		target += cb * Vector3(s * 0.025, 0.0, 0.045)                     # and bring the hand out and forward
	two_bone(sk, iu, il, ie, target, pole)


# ---- solvers ------------------------------------------------------------------------------------------------------------------------------

## Rotate in the body's axes (skeleton space), carried by the posed parent, rather than in each bone's arbitrary local axes. A missing bone is skipped.
static func turn(sk: Skeleton3D, bone: String, angles: Vector3) -> void:
	var i := sk.find_bone(bone)
	if i < 0:
		return
	var parent := sk.get_bone_parent(i)
	var frame := sk.get_bone_global_rest(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	var rot := frame.inverse() * Basis.from_euler(angles, EULER_ORDER_XYZ) * frame
	sk.set_bone_pose_rotation(i, (rot * Basis(sk.get_bone_pose_rotation(i))).get_rotation_quaternion())


static func world_basis(sk: Skeleton3D, i: int, basis: Basis) -> void:
	var parent := sk.get_bone_parent(i)
	var frame := sk.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_rotation(i, (frame.inverse() * basis).orthonormalized().get_rotation_quaternion())


## The shortest turn from one direction to another; nearly opposite directions go round by `side` instead of flipping.
static func arc(from: Vector3, to: Vector3, side: Vector3) -> Basis:
	from = from.normalized()
	to = to.normalized()
	if from.dot(to) < -0.95:
		var mid := (side - from * side.dot(from)).normalized()
		return Basis(Quaternion(mid, to)) * Basis(Quaternion(from, mid))
	return Basis(Quaternion(from, to))


## Where the middle joint of a two-bone chain sits to reach `target` from `root`, bending toward `pole`.
static func elbow(root: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> Vector3:
	var v := target - root
	var d := clampf(v.length(), absf(a - b) + 0.0001, a + b - 0.0001)
	var dr := v.normalized()
	var bend := pole - root
	bend = (bend - dr * bend.dot(dr)).normalized()
	var along := (a * a - b * b + d * d) / (2.0 * d)
	return root + dr * along + bend * sqrt(maxf(0.0, a * a - along * along))


## A two-bone chain onto a target, bending toward the pole. The end bone follows the lower one.
static func two_bone(sk: Skeleton3D, iu: int, il: int, ie: int, target: Vector3, pole: Vector3) -> void:
	var h := sk.get_bone_global_pose(iu)
	var k := sk.get_bone_global_pose(il)
	var e := sk.get_bone_global_pose(ie)
	var a := h.origin.distance_to(k.origin)
	var b := k.origin.distance_to(e.origin)
	var mid := elbow(h.origin, target, a, b, pole)
	var side := (pole - h.origin).normalized()
	world_basis(sk, iu, arc(k.origin - h.origin, mid - h.origin, side) * h.basis)
	k = sk.get_bone_global_pose(il)
	e = sk.get_bone_global_pose(ie)
	world_basis(sk, il, arc(e.origin - k.origin, target - k.origin, side) * k.basis)


## A leg onto a planted foot, the knee toward the pole.
static func plant(sk: Skeleton3D, side: String, target: Transform3D, pole: Vector3) -> void:
	var thigh := sk.find_bone("thigh." + side)
	var shin := sk.find_bone("shin." + side)
	var foot := sk.find_bone("foot." + side)
	two_bone(sk, thigh, shin, foot, target.origin, pole)
	world_basis(sk, foot, target.basis)
