class_name OmJuniper
extends RefCounted
## JUNIPER (JS juniper.js): the captive electrical being FOINT siphons. The user's rigged sculpt (assets/npcs/juniper/model.glb, 19 m, four two-bone arms), belly lit from inside, heavy-lidded eyes on the head bone, strapped into the frame by four wrist cuffs and a belt. Cuffs open, hoses tear, and he BREAKS OUT: roar, up off the plinth, top arms sweep the frame apart, then he walks the level's path: feet locked to the ground (heel strike to toe-off, pelvis rolling over the planted foot, chest and head counter-turning), punches walls, hauls himself up ledges, waits where told. His face is never still. Every bone is posed in BODY space: pose(b, q, off) turns it by q about its joint in the body's rest axes and moves it by off (metres, body axes). Cuffs, seals, hoses and sockets are exported nodes (om-jun-*); the skeleton is the model's.

const MODEL := "res://assets/npcs/juniper/model.glb"
const ARM := {
	"upper": {"bone": "arm_upper", "fore": "fore_upper", "wrist": [-11.02, 12.4, 1.29], "tip": [-12.45, 9.54, 1.14], "axis": [-1.29, -.71, .57], "hang": [.55, -1, .8], "climb": [.6, -1, .4], "flex": .15, "tuck": [.12, -.25, 0], "hold": [2.2, .3]},
	"lower": {"bone": "arm_lower", "fore": "fore_lower", "wrist": [-9.73, 5.96, .72], "tip": [-10.3, 3.81, .72], "axis": [-.86, -1.43, -.14], "hang": [.38, -1, .35], "climb": [.35, -1, .4], "flex": .15, "tuck": [.1, .18, 0]},
}
const EYE := [[-.7, 14.6, 3.43], [.7, 14.6, 3.63]]      # the skin under the dome rim either side of the nose bridge
const SW := .4      # the part of a gait cycle one foot spends in the air (heavy: long double support)
const X := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)
const Z := Vector3(0, 0, 1)
const SOCKETS := [[-12, 26, 0], [12, 26, 0], [0, -2, 12], [-13.5, 6, 0], [13.5, 6, 0]]


class BoneP:
	var i := -1
	var parent := -1
	var rq := Quaternion.IDENTITY
	var rp := Vector3.ZERO
	var pq := Quaternion.IDENTITY
	var pqi := Quaternion.IDENTITY
	var bq := Quaternion.IDENTITY


class Leg:
	var s := -1.0
	var thigh: BoneP
	var shin: BoneP
	var foot: BoneP
	var toe: BoneP
	var H0: Vector3
	var K0: Vector3
	var A0: Vector3
	var B0: Vector3
	var L1 := 0.0
	var L2 := 0.0
	var n0: Vector3
	var pole0: Vector3
	var b1i: Quaternion
	var b2i: Quaternion
	var G0: Vector3
	var ball_p: Vector3
	var heel_p: Vector3
	var p := Vector3.ZERO
	var yaw := 0.0
	var fb := Vector3.ZERO
	var fyaw := 0.0
	var sw: Variant = null      # {from, yaw0, to, yaw1}
	var pitch := 0.0
	var lift := 0.0
	var skip := false
	var local := .5
	var miss := 0.0


class Arm:
	var s := -1.0
	var upper := true
	var D: Dictionary
	var bone := -1
	var fore: BoneP = null
	var hand_local := Vector3.ZERO
	var rest_q := Quaternion.IDENTITY
	var par_q := Quaternion.IDENTITY
	var rest_dir := Vector3.ZERO
	var hang_q := Quaternion.IDENTITY
	var climb_q := Quaternion.IDENTITY
	var elb_ax := X
	var flex := 0.0
	var flex_v := 0.0
	var av := 0.0
	var px := 0.0
	var pz := 0.0
	var e := 0.0
	var free := 0.0
	var slam_t := 0.0
	var jerk := 0.0
	var dq := Quaternion.IDENTITY
	var f_t := 0.0
	var h_flex: Variant = null
	var dir0 := Vector3.ZERO
	var hl_a := 0.0
	var hl_b := 0.0


class Cuff:
	var name := ""
	var g: Node3D
	var seals: Array[Node3D] = []
	var arm := -1
	var open := false
	var rest_q := Quaternion.IDENTITY
	var loc := Transform3D.IDENTITY      # wrists: relative to the forearm bone
	var fall_v := 0.0


class Hose:
	var h: Node3D
	var port: Node3D
	var v := Vector3.ZERO
	var w := 0.0
	var off := false


class Drop:
	var g: Node3D
	var rest := Vector3.ZERO
	var v := 0.0
	var spin := 0.0


class Eye:
	var s := 1.0
	var g: Node3D
	var ball: Node3D
	var up: Node3D
	var lo: Node3D
	var glint: Node3D
	var loc := Transform3D.IDENTITY


class Out:
	var on := false
	var t := 0.0
	var phase := ""
	var smashed := false
	var walk: Variant = null      # {pts, i, speed, on, leap_i, d0, y0}
	var stride := 0.0
	var stomps := 0
	var punch_t := 0.0
	var punched := false
	var dropped := false
	var yaw := 0.0
	var done := false
	var cb := {}
	var hurry := 1.0
	var released := {}
	var waiting := ""


class Hl:
	var on := false
	var ran := false
	var k := 0.0
	var t := 0.0
	var y0 := 0.0
	var H := 0.0
	var n := 1
	var ledge := 0.0
	var reach := 3.4
	var y := 0.0
	var v := 0.0
	var cyc := -1
	var grab := 0
	var mant := 0.0
	var f := 0.0
	var fwd := 4.4
	var shifted := 0.0
	var kp := 0.0
	var sway := 0.0
	var sway_v := 0.0
	var effort := 0.0
	var push := 0.0
	var lean := 0.0


class GaitS:
	var roll := 0.0
	var hq := Quaternion.IDENTITY
	var ph := 0.0
	var f := 0.0
	var f0 := 0.0
	var k := 0.0
	var v := Vector3.ZERO
	var prev := Vector3.ZERO
	var yaw_prev := 0.0
	var yaw_rate := 0.0
	var init := false
	var free := 1.0
	var bob_v := 0.0
	var bob_y := 0.0
	var jig := 0.0
	var jig_v := 0.0
	var settle := 0.0


class Face:
	var blink_t := 2.0
	var blink := 0.0
	var dbl := false
	var sac_t := 1.0
	var ey := 0.0
	var ep := 0.0
	var ey_t := 0.0
	var ep_t := 0.0
	var hy := 0.0
	var hp := 0.0
	var brow := 0.0
	var brow_t := 0.0
	var brow_n := 0.0
	var jaw := 0.0
	var talk := 0.0
	var puff := 0.0
	var lip := 0.0
	var tw_t := 4.0
	var tw := 0.0
	var glance := 0.0
	var glance_t := 3.0


var group: Node3D
var body: Node3D
var skel: Skeleton3D
var glow_mat: ShaderMaterial
var sockets: Node3D
var arms: Array[Arm] = []
var cuffs: Array[Cuff] = []
var hoses: Array[Hose] = []
var drops: Array[Drop] = []
var legs: Array[Leg] = []
var eyes: Array[Eye] = []
var belt: Cuff
var b := {}      # name -> BoneP
var out := Out.new()
var hl := Hl.new()
var gait := GaitS.new()
var face := Face.new()
var home := Vector3.ZERO
var home_q := Quaternion.IDENTITY
var t := 0.0
var stand_u := 0.0
var standing := false
var hold_k := 0.0
var hold_on := 0.0
var hold_rate := 4.5
var impact := 0.0
var climb_k := 0.0
var tuck_k := 0.0
var wave_k := 0.0
var wave_on := false
var boost := 0.0
var strug_t := 4.0
var tug := 0.0
var gm := "rest"
var turn_look := 0.0


static func _mir(a: Array, s: float) -> Vector3:      # s = -1: his right (-X), s = 1: his left
	return Vector3(-s * float(a[0]), a[1], a[2])


static func _sm(a: float, c: float, x: float) -> float:
	var u := clampf((x - a) / (c - a), 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


static func _ease(v: float, to: float, k: float, dt: float) -> float:
	return v + (to - v) * minf(1.0, dt * k)


static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))


## rotation whose +Y is dir and +X is nrm (made square to it)
static func _basis(dir: Vector3, nrm: Vector3) -> Quaternion:
	var y := dir.normalized()
	var x := (nrm - y * nrm.dot(y)).normalized()
	return Quaternion(Basis(x, y, x.cross(y)).orthonormalized())


func _init(lv: ExportedLevel) -> void:
	group = VhKit.one(lv, "Juniper")
	body = VhKit.one(lv, "om-jun-body")
	sockets = VhKit.one(lv, "om-jun-sockets")
	var m: Node3D = (load(MODEL) as PackedScene).instantiate()
	body.add_child(m)
	skel = m.find_children("*", "Skeleton3D", true, false)[0]
	_material(m)
	# ---- the bones at rest
	for nm: String in ["hips", "spine", "chest", "head", "jaw", "lip_up", "cheek_R", "cheek_L", "brow_R", "brow_L"]:
		b[nm] = _prep(nm)
	for s: float in [-1.0, 1.0]:
		var k := "R" if s < 0.0 else "L"
		var L := Leg.new()
		L.s = s
		L.thigh = _prep("thigh_" + k)
		L.shin = _prep("shin_" + k)
		L.foot = _prep("foot_" + k)
		L.toe = _prep("toe_" + k)
		L.H0 = skel.get_bone_global_rest(L.thigh.i).origin
		L.K0 = skel.get_bone_global_rest(L.shin.i).origin
		L.A0 = skel.get_bone_global_rest(L.foot.i).origin
		L.B0 = skel.get_bone_global_rest(L.toe.i).origin
		L.L1 = L.H0.distance_to(L.K0)
		L.L2 = L.K0.distance_to(L.A0)
		var a := L.K0 - L.H0
		var c := L.A0 - L.K0
		var ha := (L.A0 - L.H0).normalized()
		L.n0 = a.cross(c).normalized()
		L.pole0 = (a - ha * a.dot(ha)).normalized()      # the knee's rest bend direction (forward and out)
		L.b1i = _basis(a, L.n0).inverse()
		L.b2i = _basis(c, L.n0).inverse()
		L.G0 = Vector3(L.A0.x, 0.0, L.A0.z)      # the ground under the ankle: where the foot is "at"
		L.ball_p = Vector3(L.B0.x - L.A0.x, 0.0, L.B0.z - L.A0.z)      # pivots on the ground, from G0
		L.heel_p = Vector3(L.s * .25, 0.0, -2.3)
		L.fb = L.G0
		legs.append(L)
	# ---- four arms: upper pair spread to the frame, lower pair down
	var defs := [[-1.0, true], [1.0, true], [-1.0, false], [1.0, false]]
	for i in 4:
		var A := Arm.new()
		A.s = defs[i][0]
		A.upper = defs[i][1]
		A.D = ARM["upper" if A.upper else "lower"]
		var k := "R" if A.s < 0.0 else "L"
		A.bone = skel.find_bone(String(A.D.bone) + "_" + k)
		A.rest_q = skel.get_bone_rest(A.bone).basis.get_rotation_quaternion()
		A.par_q = skel.get_bone_global_rest(skel.get_bone_parent(A.bone)).basis.get_rotation_quaternion()
		var sh := skel.get_bone_global_rest(A.bone).origin
		A.rest_dir = (_mir(A.D.wrist, A.s) - sh).normalized()
		A.hang_q = Quaternion(A.rest_dir, Vector3(A.s * float(A.D.hang[0]), A.D.hang[1], A.D.hang[2]).normalized())
		A.climb_q = Quaternion(A.rest_dir, Vector3(A.s * float(A.D.climb[0]), A.D.climb[1], A.D.climb[2]).normalized())      # narrower and less forward: what reaches up over a ledge, or overhead, without going into it
		A.fore = _prep(String(A.D.fore) + "_" + k)
		A.elb_ax = A.hang_q.inverse() * -X      # flexing forward in the hanging pose
		A.hand_local = skel.get_bone_global_rest(A.fore.i).affine_inverse() * _mir(A.D.tip, A.s)
		arms.append(A)
		# the cuff rides the forearm bone
		var C := Cuff.new()
		C.name = ("upper " if A.upper else "lower ") + ("right" if A.s < 0.0 else "left") + " cuff"
		C.g = VhKit.one(lv, "om-jun-cuff-%d" % i)
		C.arm = i
		C.rest_q = C.g.quaternion
		C.loc = skel.get_bone_global_rest(A.fore.i).affine_inverse() * C.g.transform
		C.seals = [VhKit.one(lv, "om-jun-seal-%d-0" % i), VhKit.one(lv, "om-jun-seal-%d-1" % i)]
		cuffs.append(C)
	belt = Cuff.new()
	belt.name = "belt"
	belt.g = VhKit.one(lv, "om-jun-cuff-4")
	belt.seals = [VhKit.one(lv, "om-jun-seal-4-0"), VhKit.one(lv, "om-jun-seal-4-1")]
	belt.rest_q = belt.g.quaternion
	cuffs.append(belt)
	for i in SOCKETS.size():
		var hs := Hose.new()
		hs.h = VhKit.one(lv, "om-jun-hose-%d" % i)
		hs.port = VhKit.one(lv, "om-jun-port-%d" % i)
		hoses.append(hs)
		if float(SOCKETS[i][1]) >= 0.0:
			var dp := Drop.new()
			dp.g = VhKit.one(lv, "om-jun-drop-%d" % i)
			dp.rest = dp.g.position
			dp.spin = (randf() - .5) * 3.0
			drops.append(dp)
	_build_eyes()


## the mint belly (the only green-dominant texels) glows from inside
func _material(m: Node) -> void:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode cull_back;\nglobal uniform float omni_power;\nuniform sampler2D tex: source_color, filter_linear_mipmap;\nuniform float uJunGlow = 1.0;\nvoid fragment(){ vec3 c = texture(tex, UV).rgb; ALBEDO = c; ROUGHNESS = 0.8; float junBelly = smoothstep(.02, .13, c.g - max(c.r, c.b)); EMISSION = vec3(.2, .9, .55) * junBelly * uJunGlow * (.1 + (1. - omni_power) * 1.2); }\n"
	glow_mat = ShaderMaterial.new()
	glow_mat.shader = sh
	for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
		var M := mi as MeshInstance3D
		var src := M.get_active_material(0) as BaseMaterial3D
		if src != null:
			glow_mat.set_shader_parameter(&"tex", src.albedo_texture)
		M.material_override = glow_mat
		M.extra_cull_margin = 40.0      # skinned: the bounding box does not follow the bones


func _prep(nm: String) -> BoneP:
	var p := BoneP.new()
	p.i = skel.find_bone(nm)
	assert(p.i >= 0, nm)
	p.parent = skel.get_bone_parent(p.i)
	var r := skel.get_bone_rest(p.i)
	p.rq = r.basis.get_rotation_quaternion()
	p.rp = r.origin
	p.pq = skel.get_bone_global_rest(p.parent).basis.get_rotation_quaternion() if p.parent >= 0 else Quaternion.IDENTITY
	p.pqi = p.pq.inverse()
	p.bq = skel.get_bone_global_rest(p.i).basis.get_rotation_quaternion()
	return p


func _pose(p: BoneP, q: Variant = null, off: Variant = null) -> void:
	var r := p.pqi
	if q != null:
		r = r * (q as Quaternion)
	skel.set_bone_pose_rotation(p.i, (r * p.pq * p.rq).normalized())
	skel.set_bone_pose_position(p.i, p.rp + (p.pqi * (off as Vector3) if off != null else Vector3.ZERO))


func _body_quat(i: int) -> Quaternion:
	return skel.get_bone_global_pose(i).basis.get_rotation_quaternion() if i >= 0 else Quaternion.IDENTITY


func _body_pos(i: int) -> Vector3:
	return skel.get_bone_global_pose(i).origin


## world position of an arm's fingertips (where act2's slams land)
func hand_world(A: Arm) -> Vector3:
	return body.global_transform * (skel.get_bone_global_pose(A.fore.i) * A.hand_local)


## his eyes: a ball (white, brown iris, pupil, a glint) that turns for the gaze, under a heavy upper lid (lash line) and a lower lid; both lids are half-shells that turn about the eye's X axis
func _build_eyes() -> void:
	const R := .26
	var skin := MsKit.std(0xc49cc0, .8, 0.0, true)
	var white := MsKit.std(0xe9e1cf, .35)
	var iris := MsKit.std(0x3b2618, .4)
	var black := VhKit.unlit(0x080506, 1.0)
	var lash := MsKit.std(0x2a1c22, .9)
	var glint := VhKit.unlit(0xffffff, 1.0)
	var sph := func(rad: float, mat: Material, par: Node3D, pos: Vector3, sz: float = 1.0) -> MeshInstance3D:
		var sm := SphereMesh.new()
		sm.radius = rad
		sm.height = rad * 2.0
		sm.radial_segments = 16
		sm.rings = 10
		var mi := MeshInstance3D.new()
		mi.mesh = sm
		mi.material_override = mat
		mi.position = pos
		mi.scale.z = sz
		par.add_child(mi)
		return mi
	for i in 2:
		var E := Eye.new()
		E.s = 1.0 if i == 1 else -1.0
		E.g = Node3D.new()
		body.add_child(E.g)
		E.g.position = Vector3(EYE[i][0], EYE[i][1], float(EYE[i][2]) - .1)
		E.g.rotation = Vector3(.14, E.s * .2, 0.0)
		E.ball = Node3D.new()
		E.g.add_child(E.ball)
		sph.call(R, white, E.ball, Vector3.ZERO)
		sph.call(R * .62, iris, E.ball, Vector3(0, 0, R * .72), .45)
		sph.call(R * .3, black, E.ball, Vector3(0, 0, R * .93), .35)
		E.glint = sph.call(R * .07, glint, E.g, Vector3(R * .14, R * .16, R * .99))      # the glint stays put while the eye turns
		E.up = Node3D.new()
		E.lo = Node3D.new()
		E.g.add_child(E.up)
		E.g.add_child(E.lo)
		var hu := SphereMesh.new()
		hu.radius = R * 1.12
		hu.height = R * 1.12
		hu.is_hemisphere = true
		hu.radial_segments = 18
		hu.rings = 8
		var up := MeshInstance3D.new()
		up.mesh = hu
		up.material_override = skin
		E.up.add_child(up)
		var ln := TorusMesh.new()
		ln.inner_radius = R * 1.02
		ln.outer_radius = R * 1.22
		ln.rings = 20
		ln.ring_segments = 4
		var lm := MeshInstance3D.new()
		lm.mesh = ln
		lm.material_override = lash
		E.up.add_child(lm)
		var hl2 := SphereMesh.new()
		hl2.radius = R * 1.08
		hl2.height = R * 1.08
		hl2.is_hemisphere = true
		hl2.radial_segments = 18
		hl2.rings = 8
		var lo := MeshInstance3D.new()
		lo.mesh = hl2
		lo.material_override = skin
		lo.rotation.x = PI
		E.lo.add_child(lo)
		E.loc = skel.get_bone_global_rest(b.head.i).affine_inverse() * E.g.transform
		eyes.append(E)


## world position of a cuff's seal k
func seal_world(c: Cuff, k: int) -> Vector3:
	return c.seals[k].global_position


## a wrist cuff springs open on its arm; the belt drops round his feet
func open_cuff(c: Cuff) -> void:
	c.open = true
	for s in c.seals:
		s.visible = false
	if c.arm >= 0:
		arms[c.arm].free = 1e-3
		arms[c.arm].jerk = 1.0
	else:
		c.fall_v = 1e-3


## a freed arm slams down (act2 reads its hand position when it lands)
func slam(i: int) -> void:
	var A := arms[i]
	if A.free > 0.0:
		A.slam_t = 1.0


func tear_hoses() -> void:
	for h in hoses:
		h.off = true
		h.v = Vector3((randf() - .5) * 8.0, 6.0 + randf() * 6.0, (randf() - .5) * 8.0)
		h.w = (randf() - .5) * 4.0


func stand() -> void:
	standing = true


## he is saying a line dur seconds long (the jaw and lips move with it)
func talk(dur: float) -> void:
	face.talk = maxf(face.talk, dur)


## the whole breakout: roar -> up off the plinth -> smash the frame (cb.smash) -> walk pts (cb.stomp(pos, side) on every heel strike, cb.punch(pt) at a point marked punch, cb.arrive() at the end). Call once; skip_to("gone") places him at the end of the walk at once (a checkpoint load).
func breakout(pts: Array, cb: Dictionary = {}, speed: float = 3.2) -> void:
	if out.on:
		return
	standing = true
	out.on = true
	out.t = 0.0
	out.phase = "roar"
	out.smashed = false
	out.cb = cb
	out.done = false
	out.punched = false
	out.punch_t = 0.0
	out.stomps = 0
	out.stride = 0.0
	out.yaw = group.rotation.y
	var copy: Array = []
	for p: Dictionary in pts:
		copy.append(p.duplicate())
	out.walk = {"pts": copy, "i": 0, "speed": speed, "on": false, "leap_i": -1, "d0": 0.0, "y0": 0.0}
	home = group.position
	home_q = group.quaternion
	sockets.reparent(group.get_parent(), true)


## a checkpoint load: "gone" = the end of the walk; a point id = standing at that point (waiting there if it is a wait point; earlier waits count as released)
func skip_to(where: String) -> void:
	if out.walk == null:
		return
	var pts: Array = out.walk.pts
	var i := pts.size() - 1
	if where != "gone":
		i = -1
		for k in pts.size():
			if pts[k].get("id", "") == where:
				i = k
				break
	if i < 0:
		return
	var p: Dictionary = pts[i]
	group.position = Vector3(p.x, p.y, p.z)
	out.yaw = float(p.get("yaw", out.yaw))
	group.rotation.y = out.yaw
	stand_u = 1.0
	out.smashed = true
	out.punched = false
	out.punch_t = 0.0
	for k in i:
		if pts[k].has("wait"):
			out.released[pts[k].wait] = true
	if where == "gone" and not p.has("wait"):
		out.walk.i = pts.size()
		out.phase = "gone"
		out.done = true
	else:
		out.walk.i = i
		out.walk.on = true
		out.phase = "walk"
		out.done = false
		out.t = 9.0
	for A in arms:
		A.free = 1.0
	gait.init = false      # the feet land under him where he now stands


## let him walk on from the wait point key
func go(key: String) -> void:
	out.released[key] = true


## walk speed multiplier (he hurries when PROG is ahead of him)
func hurry(k: float) -> void:
	out.hurry = k


## arms up to hold something: 0 = down, about .4 = at the shoulder, 1 = all four over his head (rate = how fast they get there)
func hold(v: Variant, rate: float = 4.5) -> void:
	hold_on = 1.0 if v is bool and v else (0.0 if v is bool else float(v))
	hold_rate = rate


## the weight lands in his hands: he sinks into his knees
func brace() -> void:
	impact = 1.0


## one top arm up, a slow wave (the goodbye)
func wave(on: bool) -> void:
	wave_on = on


## the two upper fingertips' midpoint in world space (where whatever he holds up rests)
func hands() -> Vector3:
	return (hand_world(arms[0]) + hand_world(arms[1])) * .5


func reset() -> void:
	standing = false
	stand_u = 0.0
	body.rotation = Vector3.ZERO
	body.position = Vector3.ZERO
	body.scale = Vector3.ONE
	belt.g.position.y = 6.2
	belt.g.rotation = Vector3.ZERO
	belt.fall_v = 0.0
	hl.on = false
	hl.ran = false
	hl.k = 0.0
	hl.f = 0.0
	hold_k = 0.0
	hold_on = 0.0
	impact = 0.0
	climb_k = 0.0
	tuck_k = 0.0
	wave_k = 0.0
	wave_on = false
	boost = 0.0
	out.hurry = 1.0
	out.released.clear()
	out.waiting = ""
	face.talk = 0.0
	if out.on:
		group.position = home
		group.quaternion = home_q
		sockets.reparent(group, true)
	out.on = false
	out.phase = ""
	out.walk = null
	out.done = false
	for c in cuffs:
		c.open = false
		for s in c.seals:
			s.visible = true
		c.g.quaternion = c.rest_q
	for A in arms:
		A.free = 0.0
		A.slam_t = 0.0
		A.jerk = 0.0
		A.flex = 0.0
		A.av = 0.0
		skel.set_bone_pose_rotation(A.bone, A.rest_q)
		_pose(A.fore)
	for h in hoses:
		h.off = false
		h.h.position = Vector3.ZERO
		h.h.rotation = Vector3.ZERO
		h.h.visible = true
	gait.init = false


# ---- the ledge haul: reach up, the hands clamp (the weight lands on the arms: he drops and bounces on a spring), then bent-arm heaves with a hitch between them, the hands planted on the rim while his shoulders come up past it; the chest goes over, he pushes off the rim and his knee comes up onto it. hl.k blends the arm / leg / body work in and out; the sprung body height is hl.y.
func _cb(k: String, a: Variant = null, c: Variant = null) -> Variant:
	var f: Variant = out.cb.get(k)
	if f == null:
		return null
	if c != null:
		return (f as Callable).call(a, c)
	if a != null:
		return (f as Callable).call(a)
	return (f as Callable).call()


func _haul_up(p: Dictionary, dt: float, wk: Dictionary) -> void:
	hl.ran = true
	if not hl.on:
		hl.on = true
		hl.t = 0.0
		hl.y0 = group.position.y
		hl.H = maxf(.5, float(p.y) - hl.y0)
		hl.y = hl.y0
		hl.v = 0.0
		hl.cyc = -1
		hl.grab = 0
		hl.ledge = p.y
		hl.reach = float(p.get("reach", 3.4))
		hl.shifted = 0.0
		hl.f = 0.0
		hl.sway = 0.0
		hl.sway_v = 0.0
		hl.n = maxi(1, roundi(hl.H / 5.5))
		hl.fwd = float(p.get("fwd", hl.reach + 1.0))
	hl.t += dt * out.hurry
	const TR := 1.1
	const TP := 1.2
	const TH := .55
	var CL := TP + TH
	var tc := hl.t - TR
	var hang := hl.ledge - hl.H
	var tgt := hl.y0 - .5 * sin(minf(1.0, hl.t / TR) * PI)      # reaching: he coils a little first
	var effort := .35
	var done := false
	if hl.t >= TR and hl.grab == 0:      # the hands clamp: the weight comes onto the arms
		hl.grab = 1
		hl.v -= 3.4
		hl.sway_v = .5
		_cb("grip", group.position)
	if tc >= 0.0:
		var c := mini(hl.n - 1, floori(tc / CL))
		var tcc := tc - c * CL
		done = tc >= hl.n * CL
		if c != hl.cyc:
			hl.cyc = c
			if c != 0:      # a re-grip: he sags again for a moment
				hl.v -= 1.6
				hl.sway_v += .35 * (1.0 if c % 2 != 0 else -1.0)
				_cb("grip", group.position)
		var u := minf(1.0, tcc / TP)
		var s := 1.0 if done or tcc >= TP else u * u * (3.0 - 2.0 * u)
		tgt = hang + hl.H * (c + s) / hl.n
		effort = .3 if done else (1.0 if tcc < TP else .55)
	hl.effort = _ease(hl.effort, effort, 6.0, dt)
	hl.v += (6.5 * 6.5 * (tgt - hl.y) - 2.0 * .5 * 6.5 * hl.v) * dt      # a heavy body on a spring: it lags the heave, overshoots and settles
	hl.y += hl.v * dt
	hl.y = minf(hl.ledge, maxf(hang - .9, hl.y))
	if hl.y >= hl.ledge:
		hl.v = minf(0.0, hl.v)
	group.position.y = hl.y
	hl.mant = _sm(hl.ledge - 11.0, hl.ledge - 4.0, hl.y)      # the chest goes over the rim; the elbows swing up and the hands push down
	hl.push = _sm(hl.ledge - 13.0, hl.ledge - 9.0, hl.y)
	hl.f = hl.fwd * _sm(hl.ledge - 9.0, hl.ledge - 1.5, hl.y)      # and the body moves in over the ledge
	hl.sway_v += (-hl.sway * 9.0 - hl.sway_v * 1.2) * dt      # a slow swing on the hands
	hl.sway += hl.sway_v * dt
	hl.kp += dt * (3.2 + 3.5 * hl.effort)
	out.stride += dt * .9
	if done and hl.y > hl.ledge - .19:      # up: the body steps in over the ledge, and the path goes on from there
		var yw := out.yaw
		group.position.x += sin(yw) * hl.f
		group.position.z += cos(yw) * hl.f
		hl.shifted = hl.f
		hl.f = 0.0
		group.position.y = hl.ledge
		wk.i = int(wk.i) + 1
		out.punched = false
		out.dropped = false
		_cb("reach", p)
		_cb("land", group.position)


## a leg during the haul: the foot scrabbles up the wall face (alternating knees), then one knee after the other comes up onto the ledge
func _haul_leg(L: Leg, i: int) -> void:
	var ph := hl.kp + i * PI
	var rel := hl.ledge - group.position.y
	var mm := _sm(hl.ledge - 10.5 + i * 1.6, hl.ledge - 3.0 + i * 1.6, hl.y)
	var scr_y := 1.0 + 1.1 * sin(ph) * hl.effort
	var scr_z := maxf(0.0, hl.reach - .8 - L.G0.z)
	var y := scr_y + (rel + .3 - scr_y) * mm
	var z := scr_z * (1.0 - mm) + hl.f * mm
	L.fb.y += (L.G0.y + y - L.fb.y) * hl.k
	L.fb.z += (L.G0.z + z - hl.f - L.fb.z) * hl.k


## the arm's haul pose: a two-bone solve in the vertical plane in front of its shoulder for a hand on the rim (upper arms) or the wall face below it (lower arms) -> [ang, flex]
func _haul_arm(A: Arm) -> Array:
	var sh := _body_pos(A.bone) + body.position
	if A.hl_a == 0.0:
		var el0 := _body_pos(A.fore.i) + body.position
		A.hl_a = sh.distance_to(el0)
		A.hl_b = el0.distance_to(hand_world(A) - group.global_position)
	var a := A.hl_a
	var c := A.hl_b
	var rel := hl.ledge - group.position.y
	var on_top := 1.0 if A.upper else hl.mant
	var tz := hl.reach + .6 - hl.shifted
	var ty := rel + .4 - (0.0 if A.upper else 3.0 * (1.0 - on_top))
	var dz := tz - sh.z
	var dy := ty - sh.y
	var d := minf((a + c) * .99, maxf(absf(a - c) + .05, U.hyp(dz, dy)))
	var g := acos(clampf((a * a + c * c - d * d) / (2.0 * a * c), -1.0, 1.0))
	var be := acos(clampf((a * a + d * d - c * c) / (2.0 * a * d), -1.0, 1.0))
	var el := atan2(dy, dz) + (hl.push * 2.0 - 1.0) * be + hl.lean      # the elbow below the line to the hand; above it once he pushes down
	var lo := -1.3
	var hi := 3.1
	for _k in 18:      # the shoulder angle that puts the upper arm at that elevation (monotonic: bisect)
		var m := (lo + hi) / 2.0
		var v := A.dir0.rotated(X, -m)
		if atan2(v.y, v.z) < el:
			lo = m
		else:
			hi = m
	return [(lo + hi) / 2.0, PI - g]


## where a foot's ground point would be with the body at (pos, yaw): G0 turned and moved, in the parent's space
func _place_of(L: Leg, pos: Vector3, yaw: float) -> Vector3:
	var c := cos(yaw)
	var s := sin(yaw)
	return Vector3(pos.x + L.G0.x * c + L.G0.z * s, pos.y, pos.z - L.G0.x * s + L.G0.z * c)


# gait: one clock for both feet (his right swings in [0, SW), his left half a cycle later); the feet themselves are pinned in the parent's space while down
func _gait_step(dt: float) -> void:
	var pos := group.position
	var yaw := group.rotation.y
	var lock := gm == "walk" or gm == "pivot" or gm == "stand"
	# body velocity in the parent's space (a jump of more than 8 m is a teleport: checkpoint loads, reset)
	var mv := pos - gait.prev
	var jump := mv.length() > 8.0 or not gait.init
	if not jump and dt > 0.0:
		gait.v = gait.v.lerp(mv / dt, minf(1.0, dt * 8.0))
		gait.yaw_rate = _ease(gait.yaw_rate, _wrap(yaw - gait.yaw_prev) / dt, 8.0, dt)
	else:
		gait.v = Vector3.ZERO
		gait.yaw_rate = 0.0
	gait.prev = pos
	gait.yaw_prev = yaw
	var mat := group.transform
	var inv := mat.affine_inverse()
	if jump or not lock:      # airborne / chained / placed: the feet hang under the body and drift back to rest
		gait.init = true
		gait.free = 1.0 if jump else _ease(gait.free, 1.0, 5.0, dt)
		gait.f = 0.0
		gait.f0 = 0.0
		gait.k = _ease(gait.k, 0.0, 6.0, dt)
		for i in legs.size():
			var L := legs[i]
			L.fb = L.fb.lerp(L.G0, 1.0 if jump else minf(1.0, dt * 5.0))
			if hl.k > .01:
				_haul_leg(L, i)
			L.fyaw = _ease(L.fyaw, 0.0, 5.0, dt)
			L.sw = null
			L.skip = false
			L.lift = _ease(L.lift, 0.0, 5.0, dt)
			L.pitch = _ease(L.pitch, .25 if gm == "air" else 0.0, 4.0, dt)      # toes droop when he is off the ground
			L.p = mat * L.fb
			L.yaw = yaw + L.fyaw
		return
	gait.free = 0.0
	var speed := U.hyp(gait.v.x, gait.v.z)
	var turn := absf(gait.yaw_rate)
	var moving := speed > .25 or turn > .08
	var err := 0.0
	var swinging := false
	for L in legs:
		if L.sw != null:
			swinging = true
			continue
		var pl := _place_of(L, pos, yaw)
		err = maxf(err, U.hyp(L.p.x - pl.x, L.p.z - pl.z) + absf(_wrap(L.yaw - yaw)) * 3.0)
	var Ls := minf(3.4, maxf(2.4, 2.2 + speed * .25))      # step length: short legs, a little longer when he hurries
	var fT := maxf(maxf(speed / (2.0 * Ls), turn * 1.4), .38) if moving else (.42 if err > .3 or swinging else 0.0)
	if gait.f0 == 0.0 and fT > 0.0:
		gait.f = fT
	elif fT > gait.f:
		gait.f = _ease(gait.f, fT, 10.0, dt)
	elif fT != 0.0 or swinging:
		gait.f = _ease(gait.f, maxf(fT, .3), 3.0, dt)
	else:
		gait.f = 0.0
	gait.k = _ease(gait.k, minf(1.0, .45 + speed / 4.0) if moving else (.35 if swinging else 0.0), 3.0, dt)      # how much of the waddle shows (shift, bob, roll)
	if gait.f0 == 0.0 and gait.f > 0.0:      # setting off: the foot furthest from where it should be goes first, now
		var bi := 0
		var be := -1.0
		for i in legs.size():
			var pl := _place_of(legs[i], pos, yaw) + gait.v * .8
			var e := U.hyp(legs[i].p.x - pl.x, legs[i].p.z - pl.z)
			if e > be:
				be = e
				bi = i
		gait.ph = (1.0 if legs[bi].s < 0.0 else .5) - 1e-4
	if gait.f > 0.0 and not swinging:      # a foot left too far behind (setting off, a sudden hurry) steps now, before the leg runs out
		for L in legs:
			var pl := _place_of(L, pos, yaw)
			if U.hyp(L.p.x - pl.x, L.p.z - pl.z) > 2.1:
				gait.ph = fmod((1.0 if L.s < 0.0 else .5) - 1e-4, 1.0)
				break
	gait.f0 = gait.f
	var ph0 := gait.ph
	gait.ph = fmod(gait.ph + gait.f * dt, 1.0)
	for L in legs:
		var off := 0.0 if L.s < 0.0 else .5
		var l0 := fmod(ph0 - off + 1.0, 1.0)
		var l1 := fmod(gait.ph - off + 1.0, 1.0)
		L.local = l1
		if gait.f > 0.0 and l1 < l0 - .5:      # this foot's turn to step
			var pl := _place_of(L, pos, yaw)
			var e := U.hyp(L.p.x - pl.x, L.p.z - pl.z) + absf(_wrap(L.yaw - yaw)) * 3.0
			L.skip = not moving and e < .3
			if not L.skip:
				L.sw = {"from": L.p, "yaw0": L.yaw, "to": Vector3.ZERO, "yaw1": yaw}
		if L.sw != null and l1 < SW:      # where it will land: re-aimed every frame (speed and turn change under it)
			var f := maxf(gait.f, .2)
			var t_sw := (SW - l1) / f
			var t_st := (1.0 - SW) / f
			var py := _wrap(yaw + clampf(gait.yaw_rate * (t_sw + t_st * .5), -.5, .5))      # turned to where the body will be mid-stance
			var c0 := pos + gait.v * t_sw
			var d0 := _place_of(L, c0, py)
			var lead := minf(1.4, speed * t_st * .5)
			if speed > .05:
				d0.x += gait.v.x / speed * lead
				d0.z += gait.v.z / speed * lead
			var c := cos(py)
			var s := sin(py)
			var lx := (d0.x - c0.x) * c - (d0.z - c0.z) * s      # never inside its own lane (the feet must not meet)
			var lz := (d0.x - c0.x) * s + (d0.z - c0.z) * c
			var min_x := absf(L.G0.x) - .3
			if lx * L.s < min_x:
				var nx := L.s * min_x
				d0.x = c0.x + nx * c + lz * s
				d0.z = c0.z - nx * s + lz * c
			var gy: Variant = out.cb["ground"].call(d0.x, d0.z) if out.cb.has("ground") else null
			d0.y = float(gy) if gy != null else pos.y + gait.v.y * t_sw
			L.sw.to = d0
			L.sw.yaw1 = py
		if L.sw != null and l1 >= SW and l1 < SW + .25:      # heel strike: down and pinned
			L.p = L.sw.to
			L.yaw = L.sw.yaw1
			L.sw = null
			gait.bob_v -= .55 * gait.k + .15
			gait.jig_v -= .9 * gait.k + .2
			gait.settle = 1.0
			face.puff = minf(1.0, face.puff + .5)
			out.stomps += 1
			_cb("stomp", group.position, L.s)
		var k := gait.k
		var step := not L.skip and gait.f > 0.0
		if L.sw != null:      # in the air: a low arc, swung a little out round the planted foot
			var u := minf(1.0, l1 / SW)
			var e := .5 - .5 * cos(PI * u)
			var arc := sin(PI * u)
			L.p = (L.sw.from as Vector3).lerp(L.sw.to, e)
			L.yaw = float(L.sw.yaw0) + _wrap(float(L.sw.yaw1) - float(L.sw.yaw0)) * e
			L.lift = (.24 + .12 * k) * pow(arc, .8)
			var o := L.s * .3 * arc
			L.p.x += cos(yaw) * o
			L.p.z -= sin(yaw) * o
			L.pitch = _ease(L.pitch, .32 * (1.0 - _sm(0.0, .35, u)) * (.5 + .5 * k) - .24 * _sm(.6, 1.0, u) * (.4 + .6 * k), 16.0, dt)      # toe-off, swing through, toes up for the heel
		else:
			var st := fmod(l1 - SW + 1.0, 1.0) / (1.0 - SW) if step else .5
			L.lift = 0.0
			L.pitch = _ease(L.pitch, -.24 * (1.0 - _sm(0.0, .1, st)) * (.4 + .6 * k) + .32 * _sm(.8, 1.0, st) * (.5 + .5 * k) if step else 0.0, 16.0 if step else 6.0, dt)      # foot slaps flat, then the heel peels up
		L.fb = inv * L.p
		L.fb.y += L.lift
		L.fyaw = _wrap(L.yaw - yaw)


## two-bone leg IK in body space: hip (where the hips put it) -> ankle over the foot's pivot, knee in the bend plane, foot and toe from the foot's yaw and roll
func _leg_ik(L: Leg) -> void:
	var q3 := Quaternion(Y, L.fyaw)      # foot yaw in body space
	var piv := L.ball_p if L.pitch > 0.0 else L.heel_p
	var q := q3 * Quaternion(X, L.pitch)      # the whole foot: yaw, then roll about its own lateral axis
	var c := q3 * piv + L.fb      # the pivot on the ground
	var a := q * (L.A0 - L.G0 - piv) + c      # the ankle target
	var H := _body_pos(L.thigh.i)
	var v := a - H
	var ln := v.length()
	var mx := (L.L1 + L.L2) * .995
	var mn := absf(L.L1 - L.L2) + .05
	L.miss = maxf(maxf(0.0, ln - mx), mn - ln)
	ln = clampf(ln, mn, mx)
	v = v.normalized() * ln
	var n := v.normalized()
	var pole := q3 * L.pole0
	pole = (pole - n * pole.dot(n)).normalized()
	var along := (L.L1 * L.L1 - L.L2 * L.L2 + ln * ln) / (2.0 * ln)
	var h := sqrt(maxf(0.0, L.L1 * L.L1 - along * along))
	var K := n * along + pole * h + H
	var A := H + v
	var thigh_d := K - H
	var shin_d := A - K
	var nrm := thigh_d.cross(shin_d)
	if nrm.length_squared() < 1e-6:
		nrm = q3 * L.n0
	nrm = nrm.normalized()
	var qT := _basis(thigh_d, nrm) * L.b1i * L.thigh.bq
	var qS := _basis(shin_d, nrm) * L.b2i * L.shin.bq
	var qF := q * L.foot.bq
	var qToe := (q3 if L.pitch > 0.0 else q) * L.toe.bq      # heel up: the toes stay flat on the ground
	skel.set_bone_pose_rotation(L.thigh.i, (_body_quat(L.thigh.parent).inverse() * qT).normalized())
	skel.set_bone_pose_rotation(L.shin.i, (qT.inverse() * qS).normalized())
	skel.set_bone_pose_rotation(L.foot.i, (qS.inverse() * qF).normalized())
	skel.set_bone_pose_rotation(L.toe.i, (qF.inverse() * qToe).normalized())


## how far the hips must drop (from where they are) so neither leg has to stretch to its foot
func _hip_drop() -> float:
	var drop := 0.0
	for L in legs:
		var q3 := Quaternion(Y, L.fyaw)
		var q := q3 * Quaternion(X, L.pitch)
		var piv := L.ball_p if L.pitch > 0.0 else L.heel_p
		var A := q * (L.A0 - L.G0 - piv) + (q3 * piv + L.fb)
		var H := _body_pos(L.thigh.i)
		var reach := (L.L1 + L.L2) * .96
		var hz := U.hyp(H.x - A.x, H.z - A.z)
		var y_max := A.y + sqrt(maxf(0.0, reach * reach - hz * hz))
		drop = maxf(drop, H.y - y_max)
	return drop


## an arm's final pose: the pose built this frame (A.dq, A.f_t), drawn in from a wall by A.av, onto the shoulder and elbow bones. dt 0 = re-pose now (no spring)
func _set_arm(A: Arm, dt: float) -> void:
	var D := A.dq
	var flex_t := A.f_t
	if A.av > .01:      # a wall at his arm: it swings away (A.px, A.pz: the free side, body axes) and straightens
		D = Quaternion(Z, A.px * .75 * A.av) * D
		D = Quaternion(X, -A.pz * .6 * A.av) * D
		flex_t *= maxf(0.0, 1.0 - A.av)
	skel.set_bone_pose_rotation(A.bone, (A.par_q.inverse() * D * A.par_q * A.rest_q).normalized())      # body-space rotation about the shoulder -> the bone's local rotation
	var busy := maxf(hold_k, climb_k) * (1.0 - minf(1.0, A.av))
	flex_t *= 1.0 - busy      # straight arms to climb or hold; the haul's elbows bend with the heave
	flex_t += float(A.D.flex) * A.e * (1.0 - busy)
	if hl.k > .01 and A.h_flex != null:
		flex_t += (float(A.h_flex) - flex_t) * hl.k
	if dt != 0.0:      # the elbow trails the swing a little (a spring)
		A.flex_v += ((flex_t - A.flex) * 26.0 - A.flex_v * 7.0) * dt
		A.flex += A.flex_v * dt
	else:
		A.flex = flex_t
		A.flex_v = 0.0
	_pose(A.fore, Quaternion(A.elb_ax, A.flex))


func _in_solid(W: World, p: Vector3, r: float) -> bool:
	for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if W.point_solid(p.x + o.x, p.y, p.z + o.y):
			return true
	return false


func _touching(W: World, A: Arm) -> Variant:
	var a := body.global_transform * _body_pos(A.fore.i)
	var c := hand_world(A)
	for p: Vector3 in [c, (a + c) * .5, a]:
		if _in_solid(W, p, 2.2):
			return p
	return null


func update(dt: float) -> void:
	t += dt
	var breath := sin(t * .8)
	var roar := 0.0
	var punch := 0.0
	var sweep := 0.0
	var walk_k := 0.0
	gm = "rest" if not out.on else "stand"
	turn_look = 0.0
	# ---- the breakout timeline: roar, rise, smash the frame, walk the path (punching through marked points)
	hl.ran = false
	if out.on and not out.done:
		out.t += dt
		var T := out.t
		if out.phase == "roar":
			roar = sin(minf(1.0, T / 1.6) * PI)
			if T > 1.6:
				out.phase = "rise"
		elif out.phase == "rise":
			if T > 4.2:
				out.phase = "smash"
		elif out.phase == "smash":
			var u := minf(1.0, (T - 4.2) / 1.4)
			sweep = sin(u * PI)
			if u > .45 and not out.smashed:
				out.smashed = true
				_cb("smash")
			if u >= 1.0:
				out.phase = "walk"
				out.walk.on = true
		elif out.phase == "walk":
			var wk: Dictionary = out.walk
			var pts: Array = wk.pts
			var p: Variant = pts[wk.i] if int(wk.i) < pts.size() else null
			if p == null:
				out.phase = "gone"
				out.done = true
				_cb("arrive")
			elif out.punch_t > 0.0:      # stopped at a wall: both top arms wind back, then come through it
				out.punch_t = maxf(0.0, out.punch_t - dt)
				var u := 1.0 - out.punch_t / 1.5
				punch = -sin(u / .4 * PI / 2.0) * .5 if u < .4 else sin((u - .4) / .6 * PI)
				if u > .55 and not out.punched:
					out.punched = true
					_cb("punch", p)
				if out.punch_t <= 0.0:
					wk.i = int(wk.i) + 1
			else:
				var pos := group.position
				var dx := float(p.x) - pos.x
				var dz := float(p.z) - pos.z
				var d := U.hyp(dx, dz)
				var dyv := float(p.y) - pos.y
				var haul: bool = p.get("climb", false) and d < 1.5 and absf(dyv) > .2      # a climb point straight over him: haul up in place
				var there := d < 1.5 and not haul
				var held: bool = there and p.has("wait") and not out.released.has(p.wait)
				var yaw := float(p.get("yaw", out.yaw)) if there or haul else float(p.get("face", atan2(dx, dz)))      # face: sidestepping through somewhere tight
				var err := _wrap(yaw - out.yaw)
				out.yaw += err * minf(1.0, dt * 1.2)
				group.rotation.y = out.yaw
				turn_look = err
				var leaping: bool = p.get("leap", false) and int(wk.leap_i) == int(wk.i)
				var pivot: bool = not there and not p.has("face") and absf(err) > (.12 if haul else .5) and not leaping      # a big turn: he turns on the spot first (a 19 m body does not walk off sideways; he squares up to a wall before he climbs it)
				tuck_k += ((1.0 if p.get("tuck", false) else 0.0) - tuck_k) * minf(1.0, dt * 2.0)      # tuck: arms in to squeeze through somewhere narrow (his breach)
				out.waiting = String(p.wait) if held else ""
				if held:
					group.position.y += (float(p.y) - group.position.y) * minf(1.0, dt * 3.0)
				elif there:
					if p.get("punch", false) and not out.punched:
						out.punch_t = 1.5
					else:
						wk.i = int(wk.i) + 1
						out.punched = false
						out.dropped = false
						_cb("reach", p)
				elif pivot:
					gm = "pivot"
					out.yaw += signf(err) * minf(absf(err), dt * .5)
					group.rotation.y = out.yaw
					walk_k = .35
				elif haul:      # hands on the ledge, hauling himself up (or lowering himself down)
					gm = "air"
					climb_k += (1.0 - climb_k) * minf(1.0, dt * 3.0)
					walk_k = .3
					if dyv > 0.0:
						_haul_up(p, dt, wk)
					else:
						var sp := 2.6 * out.hurry
						group.position.y += signf(dyv) * minf(absf(dyv), sp * dt)
						out.stride += dt * .9
						var n := floori(out.stride / PI)
						if n > out.stomps:
							out.stomps = n
							_cb("grip", group.position)
				else:
					var climbing: bool = p.get("climb", false) and float(p.y) - group.position.y > .4
					var sp := float(wk.speed) * out.hurry * (.5 if climbing else 1.0)
					var st := minf(d, sp * dt)
					group.position.x += dx / d * st
					group.position.z += dz / d * st
					if p.get("leap", false):      # a leap: up and out over the edge, then down
						if int(wk.leap_i) != int(wk.i):
							wk.leap_i = wk.i
							wk.d0 = d
							wk.y0 = group.position.y
						var u := minf(1.0, 1.0 - (d - st) / maxf(1e-3, float(wk.d0)))
						group.position.y = float(wk.y0) + (float(p.y) - float(wk.y0)) * pow(u, 2.2) + 3.0 * sin(PI * u)
					else:      # a drop: off the edge and down, then on
						group.position.y += (float(p.y) - group.position.y) * minf(1.0, maxf(st / d * 5.0, dt * 5.0) if p.get("drop", false) else st / d)
					if not climbing and not p.get("drop", false) and not p.get("leap", false) and not p.get("climb", false) and out.cb.has("ground"):      # on known ground: his feet follow it
						var gy: Variant = out.cb["ground"].call(group.position.x, group.position.z)
						if gy != null:
							group.position.y += (float(gy) - group.position.y) * minf(1.0, dt * 7.0)
					climb_k += ((1.0 if climbing else 0.0) - climb_k) * minf(1.0, dt * 3.0)
					if (p.get("drop", false) or p.get("leap", false)) and not out.dropped and absf(float(p.y) - group.position.y) < .6 and (not p.get("leap", false) or d - st < 1.6):
						out.dropped = true
						_cb("land", group.position)
					walk_k = 1.0
					gm = "air" if climbing or p.get("drop", false) or p.get("leap", false) or p.get("climb", false) else "walk"
					if gm == "air":      # off the ground the footfalls keep their old beat
						out.stride += dt * sp / 8.0 * TAU
						var n := floori(out.stride / PI)
						if n > out.stomps:
							out.stomps = n
							_cb("stomp", group.position, 1.0 if n % 2 != 0 else -1.0)
	elif out.done:      # the fly-off: hanging on the line
		var up := (group.quaternion * Y).y
		gm = "air" if up < .999 or absf(gait.v.y) > 1.5 else "stand"
	hl.on = hl.ran
	hl.k = _ease(hl.k, 1.0 if hl.on else 0.0, 3.0 if hl.on else 2.5, dt)
	if hl.k < .005 and not hl.on:
		hl.k = 0.0
		hl.f = 0.0
	# the frame sockets fall to the deck with the frame (sockets local y -1.9 = the deck: the plinth top is 2 above it)
	for d in drops:
		if out.on and out.smashed:
			if d.g.position.y > -.9:
				d.v += 18.0 * dt
				d.g.position.y = maxf(-.9, d.g.position.y - d.v * dt)
				d.g.rotation.x += d.spin * dt
				d.g.rotation.z += d.spin * .6 * dt
		elif d.v != 0.0:
			d.v = 0.0
			d.g.position = d.rest
			d.g.rotation = Vector3.ZERO
	# once the frame is smashed he walks free: cuffs, belt and siphon ports fall away with it
	var shed := out.on and out.smashed
	for c in cuffs:
		c.g.visible = not shed
	for h in hoses:
		h.port.visible = not shed
		if shed:
			h.h.visible = false
	# chained: every few seconds he heaves against the cuffs (arms wrench, the body shudders, the cuffs spark)
	if not out.on and not standing:
		strug_t -= dt
		if strug_t <= 0.0:
			strug_t = 5.0 + randf() * 6.0
			tug = 1.0
			if Game.fx != null:
				for c in cuffs:
					if not c.open and c.arm >= 0:
						Game.fx.sparks(c.g.global_position, 14, 5.0, null, 0xffc060)
	tug = maxf(0.0, tug - dt * .9)
	var wrench := sin(tug * PI) * (1.0 + .5 * sin(t * 25.0)) * .22
	if walk_k == 0.0:
		climb_k = maxf(0.0, climb_k - dt * 2.0)
	hold_k += (hold_on - hold_k) * minf(1.0, dt * (hold_rate if hold_on > hold_k else 1.4))
	impact = maxf(0.0, impact - dt * 1.3)
	wave_k += ((1.0 if wave_on else 0.0) - wave_k) * minf(1.0, dt * 1.5)
	var sag := sin(impact * PI) * .9 * hold_k      # the weight lands: he sinks into his knees, then shakes under it
	var strain := hold_k * sin(t * 19.0) * .025
	glow_mat.set_shader_parameter(&"uJunGlow", .85 + sin(t * 2.3) * .15 + roar * 2.5 + maxf(0.0, punch) * 1.2 + hold_k * (.8 + sin(t * 7.0) * .3) + boost * (1.0 + sin(t * 1.7) * .15))
	if standing:
		stand_u = minf(1.0, stand_u + dt * .3)
	var lean := -sin(stand_u * PI) * .07 - roar * .12 + walk_k * .05 - tug * .05 + climb_k * .18 + punch * .08 + hl.k * (.1 * hl.effort + .38 * hl.mant)
	hl.lean = lean
	# ---- the body: pelvis over the planted foot, chest and head counter-turning, the belly settling after each step
	_gait_step(dt)
	var gk := gait.k
	var gc := cos(TAU * (gait.ph - SW / 2.0))      # gc > 0: his left foot carries him (his right is in the air)
	gait.bob_v += (-gait.bob_y * 60.0 - gait.bob_v * 11.0) * dt      # the drop into each heel strike, springing back
	gait.bob_y += gait.bob_v * dt
	gait.jig_v += (-gait.jig * 38.0 - gait.jig_v * 5.0) * dt      # the belly's slower wobble behind it
	gait.jig += gait.jig_v * dt
	var bob := gk * (.1 * cos(2.0 * TAU * (gait.ph - SW / 2.0)) - .16) + gait.bob_y * .5 - sag - .08 * walk_k
	var roll := -.05 * gk * gc + sin(t * 23.0) * .02 * tug + strain + hl.k * (hl.sway * .12 + sin(t * 17.0) * .012 * hl.effort)
	var yaw_h := .07 * gk * gc
	const HY := 4.6
	var off := Vector3(.42 * gk * gc + sin(t * 31.0) * .12 * tug, bob + HY * (cos(lean) - 1.0), HY * sin(lean))      # the lean pivots at his feet (as the whole body did), so the hips ride forward with it
	gait.roll = roll
	gait.hq = Quaternion.from_euler(Vector3(lean, yaw_h, roll))
	_pose(b.hips, gait.hq, off)
	var drop := minf(.9, _hip_drop())      # never stretch a leg: the hips come down to the feet instead
	if drop > 0.0:
		off.y -= drop
		_pose(b.hips, gait.hq, off)
	for L in legs:
		_leg_ik(L)
	# spine: breath and the roar puff the trunk; the belly lags the bounce; chest counter-turns so the shoulders stay calm
	_pose(b.spine, Quaternion.from_euler(Vector3(gait.jig * .02, -yaw_h * .4, -roll * .3)), Vector3(0, gait.jig * .12, 0))
	skel.set_bone_pose_scale(b.spine.i, Vector3(1.0 + breath * .012 + roar * .06, 1.0 + breath * .006 + roar * .03, 1.0 + breath * .012 + roar * .06))
	_pose(b.chest, Quaternion.from_euler(Vector3(-breath * .01, -yaw_h * .5, -roll * .45)))
	body.position = Vector3(0, 0, hl.f)      # (hl.f: in over the ledge)
	# ---- arms
	for A in arms:
		var flex_t := 0.0
		if A.free == 0.0:      # still cuffed: only the wrench against the frame
			if wrench != 0.0:
				var D0 := Quaternion(X, -wrench * (.6 if A.upper else 1.0))
				D0 = Quaternion(Z, A.s * wrench * .5) * D0
				skel.set_bone_pose_rotation(A.bone, (A.par_q.inverse() * D0 * A.par_q * A.rest_q).normalized())
			else:
				skel.set_bone_pose_rotation(A.bone, A.rest_q)
			_pose(A.fore)
			continue
		A.free = minf(1.0, A.free + dt * .8)
		var e := A.free * A.free * (3.0 - 2.0 * A.free)
		var upk := maxf(climb_k, hold_k)
		var D := Quaternion.IDENTITY.slerp(A.hang_q.slerp(A.climb_q, upk) if upk > .01 else A.hang_q, e)      # arms going up (climb, hold) start from the narrower hang they were designed on (the JS stretch line sits inside this comment there, so it never ran; left out)
		if A.jerk > 0.0:      # the freed arm thrashes
			A.jerk = maxf(0.0, A.jerk - dt * 1.4)
			var j := sin(A.jerk * PI * 3.0) * A.jerk * .45
			D = Quaternion(X, j) * D
			D = Quaternion(Z, A.s * j * .6) * D
		if A.slam_t > 0.0:
			A.slam_t = maxf(0.0, A.slam_t - dt * 1.6)
			var u := 1.0 - A.slam_t
			D = Quaternion(X, -sin(minf(1.0, u * 1.6) * PI) * 1.1) * D
		if roar != 0.0:      # the roar: arms flung up and out
			D = Quaternion(Z, A.s * roar * (1.3 if A.upper else .5)) * D
		if sweep != 0.0 and A.upper:      # the top arms sweep the frame apart
			D = Quaternion(Z, A.s * -sin(sweep * PI) * 1.6) * D
			D = Quaternion(X, -sweep * .5) * D
		var swing := gc * gk      # with the legs: his right arms forward while his left leg is
		if walk_k != 0.0 or gk > .01:
			var fw := A.s * swing      # > 0: this arm forward
			D = Quaternion(X, -fw * (.14 if A.upper else .22) * (1.0 - .65 * tuck_k)) * D
			D = Quaternion(Z, A.s * (.1 if A.upper else .16) * absf(swing) * (1.0 - tuck_k)) * D      # out a touch round the belly as it passes
			flex_t += .12 + maxf(0.0, fw) * .35      # the elbow folds as the arm comes forward, opens as it goes back
		if tuck_k > .01:      # arms in: the top pair forward over the belly, the lower pair back along the hips (his belly is about as wide as they are)
			var tk: Array = A.D.tuck
			D = Quaternion(Z, -A.s * float(tk[0]) * tuck_k) * D
			D = Quaternion(X, float(tk[1]) * tuck_k) * D
			flex_t += float(tk[2]) * tuck_k
		if punch != 0.0:
			if A.upper:
				D = Quaternion(X, -punch * 1.5) * D
				D = Quaternion(Z, A.s * punch * .4) * D
			else:
				D = Quaternion(X, -punch * .4) * D
		if climb_k > .01 or hl.k > .01:      # hauling himself up: arms reach up and over the edge
			var ang := climb_k * (2.45 if A.upper else 1.0)
			if hl.k > .01:      # the ledge haul: planted hands
				A.dir0 = D * A.rest_dir
				var r := _haul_arm(A)
				ang += (float(r[0]) - ang) * hl.k
				A.h_flex = r[1]
			D = Quaternion(X, -ang) * D
		if wave_k > .01 and A == arms[1]:      # goodbye: up and out in front of the shoulder, the forearm doing the waving
			D = Quaternion(Z, A.s * wave_k * (1.75 + sin(t * 3.2) * .12)) * D
			D = Quaternion(X, -.6 * wave_k) * D
			flex_t += wave_k * (.55 + sin(t * 3.2) * .3)
		if hold_k > .01:      # all four up over his head
			D = Quaternion(Z, A.s * (float(A.D.hold[0]) if A.upper else 1.5) * hold_k + A.s * strain * 2.0) * D
			D = Quaternion(X, -(float(A.D.hold[1]) if A.upper else .5) * hold_k) * D
		A.dq = D
		A.f_t = flex_t
		A.e = e
		_set_arm(A, dt)
	# ---- walls: a free arm whose elbow, forearm or fingers end up inside the level's solids is drawn in and folded (A.av) in the same frame, and eases back out once it is clear (the probes reach 2.2 m round each point: his forearms are thick, and he draws in just before he would touch)
	var Wd: World = Game.world if out.on and out.smashed else null
	if Wd != null:
		for A in arms:
			if A.free == 0.0 or hl.k > .2:      # (the haul's hands are on the rim on purpose)
				continue
			var p: Variant = _touching(Wd, A)
			var k := 0
			while p != null and k < 3:      # find the free side round the touching point, swing that way, look again
				var fx := 0.0
				var fz := 0.0
				for a in 8:
					var c := cos(a * PI / 4.0)
					var s := sin(a * PI / 4.0)
					if not _in_solid(Wd, (p as Vector3) + Vector3(c * 3.5, 0, s * 3.5), .5):
						fx += c
						fz += s
				var yw := group.rotation.y
				var c2 := cos(yw)
				var s2 := sin(yw)
				var up := climb_k > .3
				var lx := 0.0 if up else fx * c2 - fz * s2      # world -> body axes; climbing, the free side is up: reach higher, over the lip
				var lz := 1.0 if up else fx * s2 + fz * c2
				var ll := U.hyp(lx, lz)
				if ll == 0.0:
					ll = 1.0
				var kk := 1.0 if k != 0 else .5
				A.px = (A.px if A.av > .01 else 0.0) + (lx / ll - (A.px if A.av > .01 else 0.0)) * kk
				A.pz = (A.pz if A.av > .01 else 0.0) + (lz / ll - (A.pz if A.av > .01 else 0.0)) * kk
				A.av = minf(1.6, 1.0 if A.av < .5 else A.av + .3)
				_set_arm(A, 0.0)
				p = _touching(Wd, A)
				k += 1
			if p == null and A.av != 0.0:
				A.av = maxf(0.0, A.av - dt * 1.2)
	_update_face(dt, breath, roar, punch)
	# ---- what rides the bones (JS attach): cuffs on the forearms, eyes on the head
	for c in cuffs:
		if c.arm < 0:
			continue
		var g := skel.get_bone_global_pose(arms[c.arm].fore.i) * c.loc
		if c.open:
			g.basis = g.basis * Basis(Z, .9)
		c.g.transform = g
	for E in eyes:
		E.g.transform = skel.get_bone_global_pose(b.head.i) * E.loc
	for h in hoses:
		if h.off and h.h.visible:
			h.v.y -= 20.0 * dt
			h.h.position += h.v * dt
			h.h.rotation.x += h.w * dt
			if h.h.position.y < -30.0:
				h.h.visible = false
	if belt.fall_v != 0.0:
		belt.fall_v += 20.0 * dt
		belt.g.position.y = maxf(.6, belt.g.position.y - belt.fall_v * dt)
		belt.g.rotation.x = (6.2 - belt.g.position.y) * .012


# ---- the face: the eyes lead, the head follows; blinks, brows, breath in the lips and cheeks
func _update_face(dt: float, breath: float, roar: float, punch: float) -> void:
	var F := face
	var P: Player = Game.player
	# where he wants to look (yaw, pitch relative to his body): into a turn first, else PROG when he is close and in front of him, else small wanders
	var want_y := 0.0
	var want_p := -.05
	if absf(turn_look) > .08:
		want_y = clampf(turn_look * .9, -.7, .7)
	elif P != null:
		var dx := P.x - group.position.x
		var dz := P.z - group.position.z
		var dist := U.hyp(dx, dz)
		var rel := _wrap(atan2(dx, dz) - group.rotation.y)
		if dist < 110.0 and dist > 6.0 and absf(rel) < 1.4:
			want_y = clampf(rel, -.6, .6)
			want_p = clampf(atan2(P.y - (group.position.y + 14.6), dist), -.5, .25)
	F.glance_t -= dt
	if F.glance_t <= 0.0:      # now and then a look off to one side
		F.glance_t = 2.5 + randf() * 4.0
		F.glance = (randf() - .5) * .7 if randf() < .35 else 0.0
	want_y += F.glance * (0.0 if absf(turn_look) > .08 else 1.0)
	F.sac_t -= dt
	if F.sac_t <= 0.0:      # tiny darts round the look target
		F.sac_t = .5 + randf() * 1.8
		F.ey_t = (randf() - .5) * .14
		F.ep_t = (randf() - .5) * .08
	var ey_goal := clampf(want_y - F.hy + F.ey_t, -.5, .5)
	var ep_goal := clampf(want_p - F.hp + F.ep_t, -.3, .25)
	if absf(ey_goal - F.ey) > .3 and F.blink <= 0.0 and randf() < .5:      # a big eye move often takes a blink with it
		F.blink_t = 0.0
	F.ey = _ease(F.ey, ey_goal, 22.0, dt)
	F.ep = _ease(F.ep, ep_goal, 22.0, dt)
	F.hy = _ease(F.hy, clampf(want_y * .55, -.32, .32), 2.6, dt)      # the head follows, slower and less far
	F.hp = _ease(F.hp, clampf(want_p * .4, -.12, .1), 2.2, dt)
	# blinks: every 2-6 s, sometimes twice; ~0.2 s, closing faster than opening
	F.blink_t -= dt
	if F.blink_t <= 0.0 and F.blink <= 0.0:
		F.blink = 1e-3
		F.blink_t = .25 if F.dbl else 2.0 + randf() * 4.0
		F.dbl = not F.dbl and randf() < .2
	var close := 0.0
	if F.blink > 0.0:
		F.blink += dt / .2
		var u := F.blink
		close = _sm(0.0, .35, u) if u < .35 else (1.0 if u < .5 else 1.0 - _sm(.5, 1.0, u))
		if u >= 1.0:
			F.blink = 0.0
	var effort := minf(1.0, hold_k + tug + climb_k + maxf(0.0, punch) + roar)
	F.talk = maxf(0.0, F.talk - dt)
	var talking := F.talk > 0.0
	# brows: a sad, gentle rest (inner ends up a touch), up when he looks at PROG, down and in with effort, a slow drift otherwise
	F.brow_t -= dt
	if F.brow_t <= 0.0:
		F.brow_t = 1.5 + randf() * 3.0
		F.brow_n = (randf() - .5) * .05
	F.brow = _ease(F.brow, .03 + F.brow_n + (.04 if absf(want_y) > .1 and turn_look == 0.0 else 0.0) + (.03 * sin(t * 5.0) if talking else 0.0) - effort * .1, 3.0, dt)
	var lid_rest := -.14 - F.brow * .5 + effort * .14      # heavy lids: the upper rim a little over the pupil
	var lid_up := lid_rest + (.52 - lid_rest) * close + F.ep * .6      # the lid follows the eye's pitch
	for E in eyes:
		E.ball.rotation = Vector3(-F.ep, F.ey, 0.0)
		E.up.rotation.x = lid_up
		E.lo.rotation.x = .5 - close * .04 - effort * .1
		E.glint.visible = close < .5
	# mouth: breath, a puff out on each heel strike, effort clenches it, the voice works the jaw
	F.puff = maxf(0.0, F.puff - dt * 1.8)
	F.tw_t -= dt
	if F.tw_t <= 0.0:      # a twitch of the moustache
		F.tw_t = 3.0 + randf() * 6.0
		F.tw = 1.0
	F.tw = maxf(0.0, F.tw - dt * 3.0)
	var say := maxf(0.0, sin(t * 11.0) * .6 + sin(t * 6.3 + 1.0) * .4) * minf(1.0, F.talk * 4.0) if talking else 0.0
	F.jaw = _ease(F.jaw, .015 + breath * .01 + F.puff * .03 + say * .1 + roar * .32 - effort * .015 * (1.0 - roar), 12.0, dt)
	F.lip = _ease(F.lip, say * .05 + sin(F.tw * PI) * .04 - effort * .03, 10.0, dt)
	_pose(b.jaw, Quaternion(X, maxf(0.0, F.jaw)))
	_pose(b.lip_up, null, Vector3(0, F.lip, F.puff * .02))
	for q: Array in [[b.cheek_R, -1.0], [b.cheek_L, 1.0]]:
		var s: float = q[1]
		_pose(q[0], null, Vector3(s * (F.puff * .07 + effort * .04 + breath * .01), effort * .05 + say * .02, F.puff * .05))
	for q: Array in [[b.brow_R, -1.0], [b.brow_L, 1.0]]:
		var s: float = q[1]
		_pose(q[0], Quaternion(Z, s * (F.brow * .5 - effort * .15)), Vector3(-s * effort * .03, F.brow, 0))
	# the head: the look, steadied against the body's roll, a slight lag on the bob
	_pose(b.head, Quaternion.from_euler(Vector3(-F.hp - gait.bob_v * .015 - roar * .15, F.hy, -gait.roll * .25)))
