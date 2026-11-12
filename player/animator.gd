class_name Animator
extends RefCounted
## The playable character's procedural animation, ported statement for statement from the three.js Animator (index.html animator.js). Every frame it layers the poses
## (ground gait with two-bone leg IK, crouch, air, flips, wall run, ledge, swim, ladder, hammer fist, punches, aiming, idle life, fatigue, seats) and writes them straight onto the
## glTF skeleton: local = inv(parentWorldNew) * D * parentWorldNew * restLocal. The actor is a Node3D holding the imported model at y = -B.pivot.

const KEYS: Array[StringName] = [&"pelvis", &"spine1", &"spine2", &"chest", &"neck", &"head", &"clavicleL", &"clavicleR",
	&"upper_armL", &"upper_armR", &"forearmL", &"forearmR", &"handL", &"handR",
	&"thighL", &"thighR", &"shinL", &"shinR", &"footL", &"footR", &"toeL", &"toeR",
	&"hair_back_01", &"hair_back_02", &"hair_side_01L", &"hair_side_01R", &"hair_side_02L", &"hair_side_02R"]
# index into KEYS / pose (R is always L + 1, so a side number 0 = L, 1 = R adds on)
const PELVIS := 0
const SPINE1 := 1
const SPINE2 := 2
const CHEST := 3
const NECK := 4
const HEAD := 5
const CLAVICLE_L := 6
const CLAVICLE_R := 7
const UPPER_ARM_L := 8
const UPPER_ARM_R := 9
const FOREARM_L := 10
const FOREARM_R := 11
const HAND_L := 12
const HAND_R := 13
const THIGH_L := 14
const THIGH_R := 15
const SHIN_L := 16
const SHIN_R := 17
const FOOT_L := 18
const FOOT_R := 19
const TOE_L := 20
const TOE_R := 21
const FCURL := 1.0   # sign of the finger curl axis (verified in review)
const SIDE_NAMES: Array[String] = ["L", "R"]
const FINGER_NAMES: Array[String] = ["index", "middle", "ring", "pinky", "thumb"]
const SHADER_TANK := "res://player/tank_fx.gdshader"
const SHADER_EYE := "res://player/eye_fx.gdshader"
const SHADER_SKIN := "res://player/skin_fx.gdshader"
const GUN_HULLS := "res://player/gun_hulls.json"
const BODY_SHAPES := "res://player/body_shapes.json"
# air curves: [u, value, u, value, ...] from high u to low u
const CV_KNEE_F: Array[float] = [1.0, 0.75, 0.5, 1.65, 0.0, 1.85, -0.5, 1.3, -1.0, 0.7]
const CV_TH_F: Array[float] = [1.0, -0.65, 0.5, -1.35, 0.0, -1.55, -0.5, -1.15, -1.0, -0.6]
const CV_ARM_X: Array[float] = [1.2, -2.6, 1.0, -2.5, 0.5, -1.9, 0.0, -1.15, -0.5, -0.55, -1.0, -0.15]
const CV_ARM_Z: Array[float] = [1.0, 0.3, 0.5, 0.42, 0.0, 0.6, -0.5, 0.85, -1.0, 1.05]
const CV_ELBOW: Array[float] = [1.0, 0.25, 0.5, 0.4, 0.0, 0.55, -0.5, 0.45, -1.0, 0.3]
const GRIP_PISTOL: Array = [[1.15, 1.3, 0.9], [1.25, 1.35, 0.95], [1.25, 1.3, 0.9], [1.2, 1.25, 0.85]]
const GRIP_LONG: Array = [[0.8, 0.9, 0.6], [1.2, 1.3, 0.9], [1.25, 1.3, 0.9], [1.2, 1.25, 0.85]]
const FIST_CURL: Array[float] = [1.35, 1.5, 1.1]
const FIST_THUMB: Array[float] = [0.3, 0.55, 0.45]
const GRIP_THUMB: Array[float] = [0.25, 0.45, 0.35]


class BoneRec:
	var bone := -1                       # index in the Skeleton3D (JS rec.bone)
	var key := &""
	var rest := Quaternion.IDENTITY
	var rest_pos := Vector3.ZERO
	var parent: BoneRec = null
	var w := Quaternion.IDENTITY         # JS rec.W: world rotation, model space
	var rest_w := Quaternion.IDENTITY    # rest-pose world rotation (chest frame for held weapons)
	var leg := false
	var thigh := false
	var pose_k := -1                     # index in KEYS / pose, -1 = no pose of its own
	var chain := false                   # a posed bone or an ancestor of one: its w is used


## what solving a foot hands back (JS foot() result)
class FootPos:
	var th := 0.0
	var z := 0.0
	var x := 0.0
	var y := 0.0
	var st := 0


## The torso as the arms see it (see _body_shape). Measured once per model, shared by every animator of that model.
class Body:
	var bh := 0.025
	var na := 32
	var y0 := 0.0
	var n := 0
	var cx := PackedFloat32Array()
	var cz := PackedFloat32Array()
	var r: Array[PackedFloat32Array] = []
	var ok := PackedByteArray()
	var bone := PackedInt32Array()       # per band: 0..3 = which of tor carries it
	var tor := PackedInt32Array()        # skeleton bone of pelvis, spine1, spine2, chest (-1 = missing)
	var rest: Array[Transform3D] = []
	var r_u := 0.08
	var r_f := 0.065


## The vehicle controller's seat (JS seat = { x, y, z (the hips), quat (the car's turn), scale, steer, wheel: { x, y, z, tilt, r }, wheelPos, w, sw, duck, hands })
class SeatWheel:
	var tilt := 0.0
	var r := 0.0

class Seat:
	var x := 0.0
	var y := 0.0
	var z := 0.0
	var quat := Quaternion.IDENTITY
	var scale := 1.0
	var steer := 0.0
	var wheel: SeatWheel = null
	var wheel_pos := Vector3.ZERO
	var w := NAN                         # getting in / out: the vehicle controller plays the blend itself (NAN = not playing)
	var sw := NAN                        # getting in / out the controller spreads the size change over the whole walk and sit
	var duck := 0.0
	var hands := 1.0                     # the hands leave the wheel to get out, find it once in
	var recline := 0.0                   # a low sports seat (rad): the body tips back about the hips (knees come up, shins go forward), the head comes forward to look ahead


var B: Builds.Build
var actor: Node3D
var model: Node3D
var skel: Skeleton3D
var bones: Array[BoneRec] = []
var by_key: Dictionary = {}              # StringName key -> BoneRec
var pose := PackedVector3Array()         # Euler (XYZ) delta per KEYS entry, model space
var py := Vector3.ZERO                   # pelvis translation offset
var missing: Array[StringName] = []
var prop: Node3D = null                  # Tommy's beanie propeller
var prop_a := 0.0
var prop_v := 0.0
var pelvis_local := Vector3.ZERO         # where the hips are in the actor's own space (the seat puts them on the cushion)
var seat: Seat = null                    # set by the vehicle controller while the character drives
var seat_last: Seat = null
var w_seat := 0.0
var pose_hook := Callable()              # optional pose override (used by the intro cutscene)
var body: Body = null
var hair: HairSpring = null              # null without hair bones
var suit: Variant = null                 # the armor suit on him (JS an._suit: a PhantomSuit.Worn), null in his own clothes
var wv: WeaponView = null                # the gun in the hand (combat/weapon_view.gd)

var phase := 0.0
var t := 0.0
var w_sp := 0.0
var w_air := 0.0
var w_cr := 0.0
var w_strafe := 0.0
var w_hang := 0.0
var run := 0.0
var w_flip := 0.0
var flip_ang := 0.0
var w_swim := 0.0
var w_lad := 0.0
var w_pu := 0.0
var w_slam := 0.0
var w_aim := 0.0
var w_arm := 0.0
var w_fat := 0.0
var w_pow := 0.0
var w_wr := 0.0
var w_rl := 0.0
var w_fl := 0.0
var w_ads := 0.0
var cast_k := 0.0
var ext_l := 0.0
var ext_r := 0.0
var pu_tw := 0.0
var pu_last := 1
var rc := 0.0
var u_f := 1.0
var u_l := 0.0
var mv_s := 0.0
var sp_s := 0.0
var bkp := false
var hip_yaw := 0.0
var leg_yaw := 0.0
var pel_yaw := 0.0
var sp_g := 0.0
var cyc := 0.0
var fdy_l := 0.0
var fdy_r := 0.0
var a_f := 0.0
var yaw_v := 0.0
var launch_k := 0.0
var u_air := NAN
var wrc := 0.0
var sw_cr := 0.0
var sw_pitch := 0.0
var sl_d := 0.0
var twist := 0.0
var rl_reach := 0.0
var h_open := 0.0
var fat_ph := 0.0
var pole_w := 0.0
var wr_lean := 0.0
var hang_lift := 0.0

var _lvf0 := NAN
var _yaw0 := NAN
var _was_ground := false
var _wr_side := 1.0
var _pole_rx := 0.0
var _seat_scaled := false
var _dt := 0.016
var _ps := PackedVector3Array()
var _pys := Vector3.ZERO
var _ps_init := false
var _bl_next := 0.0
var _bl_start := -9.0
var _bl_dbl := false
var _blink_last := -1.0
var _eye_mat: ShaderMaterial = null
var _g_th := PackedFloat64Array([0.0, 0.0])
var _g_sh := PackedFloat64Array([0.0, 0.0])
var _bp := Vector3.ZERO
var _br := Vector3.ZERO
var _cs := Vector3.ZERO
var _cs_init := false
var _rl: Variant = null
var _hl := Vector3.ZERO
var _hl_idx := -2
var _sup_t := 1.0
var _sup_k := 1.0
var _swing := PackedFloat64Array([0.0, 0.0])
var _q3 := Quaternion.IDENTITY
var _hulls: Dictionary = {}
# bones the frame reaches for often
var _arm_u := PackedInt32Array([-1, -1])
var _arm_f := PackedInt32Array([-1, -1])
var _arm_h := PackedInt32Array([-1, -1])
var _rec_chest: BoneRec = null
var _rec_pelvis: BoneRec = null
var _fing: Array[BoneRec] = []           # [side * 15 + finger * 3 + joint], thumb is finger 4
var _bone_parent := PackedInt32Array()
# JS actor.matrixWorld and friends: refreshed by _refresh_xf wherever the JS calls actor.updateMatrixWorld(true)
var _model_xf := Transform3D.IDENTITY    # skeleton -> actor
var _act_xf := Transform3D.IDENTITY      # actor -> world
var _aq := Quaternion.IDENTITY           # the actor's world rotation
var _ascale := 1.0                       # the actor's world scale
var _bd_inv := Transform3D.IDENTITY
var _bd_cur: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY, Transform3D.IDENTITY]
var _pushed := Vector3.ZERO              # JS _bodyPush moves p in place: GDScript hands the moved point back here
# values the layers of one frame share (JS: locals of update())
var _P: Player
var _isc := 1.0
var _leg_k := 1.0
var _sy := 0.0
var _cy := 0.0
var _lvf := 0.0
var _lvs := 0.0
var _sp := 0.0
var _land_w := 0.0
var _wc := 0.0
var _wsp := 0.0
var _wg := 0.0
var _wa := 0.0
var _wh := 0.0
var _ws := 0.0
var _wf := 0.0
var _chy := 1.0
var _shy := 0.0
var _fl := FootPos.new()
var _fr := FootPos.new()
var _gf := Gait.Foot.new()

# one rebuilt mesh + one set of shared materials per model (JS: per clone; the look is the same and it costs less)
static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}
static var _body_cache: Dictionary = {}
static var _gun_hulls: Dictionary = {}   # gun id -> its points in model space, see _reload_hold


static func san(n: String) -> String:
	return n.replace(".", "").replace("[", "").replace("]", "").replace(":", "").replace("/", "")


## JS Quaternion.setFromEuler, order XYZ
static func q_xyz(x: float, y: float, z: float) -> Quaternion:
	var c1 := cos(x * 0.5)
	var c2 := cos(y * 0.5)
	var c3 := cos(z * 0.5)
	var s1 := sin(x * 0.5)
	var s2 := sin(y * 0.5)
	var s3 := sin(z * 0.5)
	return Quaternion(s1 * c2 * c3 + c1 * s2 * s3, c1 * s2 * c3 - s1 * c2 * s3, c1 * c2 * s3 + s1 * s2 * c3, c1 * c2 * c3 - s1 * s2 * s3)


## JS Quaternion.setFromEuler, order YXZ (the actor's and the gun group's rotation)
static func q_yxz(x: float, y: float, z: float) -> Quaternion:
	var c1 := cos(x * 0.5)
	var c2 := cos(y * 0.5)
	var c3 := cos(z * 0.5)
	var s1 := sin(x * 0.5)
	var s2 := sin(y * 0.5)
	var s3 := sin(z * 0.5)
	return Quaternion(s1 * c2 * c3 + c1 * s2 * s3, c1 * s2 * c3 - s1 * c2 * s3, c1 * c2 * s3 - s1 * s2 * c3, c1 * c2 * c3 + s1 * s2 * s3)


## JS q.invert(): the conjugate, with no "must be normalized" check
static func q_inv(q: Quaternion) -> Quaternion:
	return Quaternion(-q.x, -q.y, -q.z, q.w)


static func q_axis(ax: Vector3, a: float) -> Quaternion:
	var s := sin(a * 0.5)
	return Quaternion(ax.x * s, ax.y * s, ax.z * s, cos(a * 0.5))


func _init(gltf_scene: Node3D, build: Builds.Build = null) -> void:
	B = build if build != null else Builds.BUILDS["prog"]
	actor = Node3D.new()
	actor.name = "PlayerActor"
	actor.scale = Vector3.ONE * B.scale
	model = gltf_scene
	model.position.y = -B.pivot
	actor.add_child(model)
	skel = _find_skeleton(model)
	# (the rest of the rig sits at the identity in every model, but read it rather than assume it)
	_model_xf = Transform3D.IDENTITY
	var nd: Node = skel
	while nd != actor and nd != null:
		_model_xf = (nd as Node3D).transform * _model_xf
		nd = nd.get_parent()
	_act_xf = actor.transform
	_ascale = B.scale

	var nb := skel.get_bone_count()
	_bone_parent.resize(nb)
	var key_idx := {}
	for i in KEYS.size():
		key_idx[KEYS[i]] = i
	for i in nb:
		var rest_x := skel.get_bone_rest(i)
		var rec := BoneRec.new()
		rec.bone = i
		rec.key = StringName(san(skel.get_bone_name(i)))
		rec.rest = rest_x.basis.get_rotation_quaternion()
		rec.rest_pos = rest_x.origin
		rec.pose_k = key_idx.get(rec.key, -1)
		bones.append(rec)
		by_key[rec.key] = rec
	for r in bones:
		var pi_ := skel.get_bone_parent(r.bone)
		_bone_parent[r.bone] = pi_
		r.parent = bones[pi_] if pi_ >= 0 else null
		var ks := String(r.key)
		r.thigh = ks == "thighL" or ks == "thighR"
		r.leg = r.thigh or ks == "shinL" or ks == "shinR" or ks == "footL" or ks == "footR" or ks == "toeL" or ks == "toeR"
		if r.pose_k >= 0:
			var a := r
			while a != null:
				a.chain = true
				a = a.parent
		r.rest_w = skel.get_bone_global_rest(r.bone).basis.get_rotation_quaternion()      # rest-pose world rotations (chest frame for held weapons)
	_skinned_setup(model)
	prop = model.find_child("propeller", true, false) as Node3D     # Tommy's beanie propeller
	for s in 2:
		_arm_u[s] = _bone_of(&"upper_arm" , s)
		_arm_f[s] = _bone_of(&"forearm", s)
		_arm_h[s] = _bone_of(&"hand", s)
	_rec_chest = by_key.get(&"chest")
	_rec_pelvis = by_key.get(&"pelvis")
	for s in 2:
		for f in FINGER_NAMES.size():
			for j in 3:
				_fing.append(by_key.get(StringName("%s_0%d%s" % [FINGER_NAMES[f], j + 1, SIDE_NAMES[s]])))
	_arm_fx()
	_eye_fx()
	_body_shape()
	if _rec_pelvis != null:
		pelvis_local = _model_xf * skel.get_bone_global_rest(_rec_pelvis.bone).origin
	else:
		pelvis_local = Vector3(0.0, B.hip, 0.0)      # where the hips are in the actor's own space (the seat puts them on the cushion)
	pose.resize(KEYS.size())
	pose.fill(Vector3.ZERO)
	for k in KEYS:
		if not by_key.has(k) and (B.skin_fix or not String(k).begins_with("hair")):
			missing.append(k)
	_bl_next = 0.6 + randf() * 0.8
	hair = HairSpring.create(skel, by_key)                  # null without hair bones
	# combat layers
	wv = WeaponView.new(actor)


func _bone_of(base: StringName, side: int) -> int:
	var r: BoneRec = by_key.get(StringName(String(base) + SIDE_NAMES[side]))
	return r.bone if r != null else -1


static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null


# ---------------- materials (JS _restyle / _detail / _eyeFx / _armFx) ----------------

## The meshes: castShadow on, no receive, never frustum-culled. Skinned ones get the PS2-ish material treatment.
func _skinned_setup(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mi.custom_aabb = AABB(Vector3(-4.0, -4.0, -4.0), Vector3(8.0, 8.0, 8.0))      # JS frustumCulled = false
		mi.ignore_occlusion_culling = true
		if mi.skin != null:
			_restyle(mi)
	for c in n.get_children():
		_skinned_setup(c)


## Godot skins in a compute pass before the vertex shader runs, so a spatial shader's VERTEX is already posed. The JS detail shaders work from the bind-pose vertex position
## (so stains and lids stick to the skin through every animation): that position is handed over per vertex in CUSTOM0 on the surfaces that need it.
## Rebuilding also drops the importer's LODs and tangents: the JS game has neither.
static func _rebuilt_mesh(src: Mesh, needs_bp: Array[String]) -> ArrayMesh:
	var m := ArrayMesh.new()
	for i in src.get_surface_count():
		var a: Array = src.surface_get_arrays(i)
		var mat := src.surface_get_material(i)
		a[Mesh.ARRAY_TANGENT] = null
		var flags := 0
		if mat != null and needs_bp.has(mat.resource_name) and not (mat.resource_name == "bk_skin" and (mat as BaseMaterial3D).albedo_texture != null):
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			a[Mesh.ARRAY_CUSTOM0] = v.to_byte_array().to_float32_array()
			flags = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		m.add_surface_from_arrays(src.surface_get_primitive_type(i), a, [], {}, flags)
		m.surface_set_material(i, mat)
	return m


## PS2-ish: unlit-ish lambert on the base colour (JS MeshLambertMaterial, double sided)
func _conv(m: BaseMaterial3D, has_color: bool) -> Material:
	var key := B.file + "/" + m.resource_name
	var uses_fx := m.resource_name == "bk_tank" or m.resource_name == "bk_eye_white" or m.resource_name == "bk_iris" or m.resource_name == "bk_pupil" or (m.resource_name == "bk_skin" and m.albedo_texture == null)
	if not uses_fx and _mat_cache.has(key):
		return _mat_cache[key]
	var n := StandardMaterial3D.new()
	n.resource_name = m.resource_name
	n.albedo_color = m.albedo_color
	n.albedo_texture = m.albedo_texture
	n.texture_filter = m.texture_filter
	n.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	n.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	n.metallic = 0.0
	n.metallic_specular = 0.0
	n.roughness = 1.0
	n.cull_mode = BaseMaterial3D.CULL_DISABLED
	n.vertex_color_use_as_albedo = has_color
	n.disable_receive_shadows = true        # JS receiveShadow = false
	if m.resource_name == "bk_nose":        # same tone as the face (was a pink-orange), faceted
		n.albedo_color = Color(0.8324, 0.5156, 0.3017).linear_to_srgb()
	if not uses_fx:
		_mat_cache[key] = n
	return n


func _fx_mat(path: String, m: BaseMaterial3D, has_color: bool) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.resource_name = m.resource_name
	s.shader = load(path)
	s.set_shader_parameter(&"albedo", m.albedo_color)
	s.set_shader_parameter(&"map", m.albedo_texture)
	s.set_shader_parameter(&"has_map", m.albedo_texture != null)
	s.set_shader_parameter(&"use_vcol", has_color)
	return s


var _skin_mesh: MeshInstance3D = null
var _skin_surf := -1
var _eye_surf := -1
var _fx_tank: ShaderMaterial = null
var _fx_skin: ShaderMaterial = null
var _fx_eyes: Array[ShaderMaterial] = []


func _restyle(mi: MeshInstance3D) -> void:
	var src := mi.mesh
	var mesh: ArrayMesh = _mesh_cache.get(B.file + mi.name)
	if mesh == null:
		mesh = _rebuilt_mesh(ProgV1Fix.apply(src, mi.skin) if B.skin_fix else src, ["bk_tank", "bk_eye_white", "bk_iris", "bk_pupil", "bk_skin"] as Array[String])
		_mesh_cache[B.file + mi.name] = mesh
	mi.mesh = mesh
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i) as BaseMaterial3D
		if m == null:
			continue
		var has_color: bool = (mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0
		var nm := m.resource_name
		var out: Material = null
		if nm == "bk_skin":
			_skin_mesh = mi
			_skin_surf = i
			if m.albedo_texture == null:       # muscle striations on the arms (untextured skin only: the textured model has its own)
				_fx_skin = _fx_mat(SHADER_SKIN, m, has_color)
				out = _fx_skin
		var lid: Variant = null
		if nm == "bk_eye_white" and m.albedo_texture != null and m.has_meta("extras"):      # textured eyes (blender/build_prog.py): painted eye area, lid tone from the build
			lid = (m.get_meta("extras") as Dictionary).get("lidColor")
		if lid != null:
			_eye_surf = i
			var em := _fx_mat(SHADER_EYE, m, has_color)
			em.set_shader_parameter(&"u_lid", Vector3(lid[0], lid[1], lid[2]))
			em.set_shader_parameter(&"sclera", 1.0)
			_fx_eyes.append(em)
			out = em
		elif nm == "bk_eye_white" or nm == "bk_iris" or nm == "bk_pupil":     # eyelids (blinking); sclera self-lit so the open eye reads white at night
			if nm == "bk_eye_white":
				_eye_surf = i
			var em := _fx_mat(SHADER_EYE, m, has_color)
			em.set_shader_parameter(&"u_lid", Vector3(0.8324, 0.5156, 0.3017) * 0.6)
			em.set_shader_parameter(&"sclera", 1.75 if nm == "bk_eye_white" else 1.0)
			em.set_shader_parameter(&"hide_lid", nm != "bk_eye_white")
			if nm == "bk_eye_white":
				em.set_shader_parameter(&"emissive", Vector3(0.5, 0.48, 0.4))
			_fx_eyes.append(em)
			out = em
		if nm == "bk_tank":                    # stains on the shirt
			_fx_tank = _fx_mat(SHADER_TANK, m, has_color)
			var arr: Array = mesh.surface_get_arrays(i)
			var lo := INF
			for v: Vector3 in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				lo = minf(lo, v.y)
			_fx_tank.set_shader_parameter(&"u_hem", lo)
			out = _fx_tank
		if out == null:
			out = _conv(m, has_color)
		mi.set_surface_override_material(i, out)


## eye centres / size in the skin's bind space, so the eyelid shader can close over the eyeballs (see eye_fx.gdshader)
func _eye_fx() -> void:
	if _eye_surf < 0 or _fx_eyes.is_empty():
		return
	var mi := _skin_mesh if _skin_mesh != null else _first_skinned(model)
	var arr: Array = mi.mesh.surface_get_arrays(_eye_surf)
	var lo: Array[Vector3] = [Vector3(1e9, 1e9, 1e9), Vector3(1e9, 1e9, 1e9)]
	var hi: Array[Vector3] = [Vector3(-1e9, -1e9, -1e9), Vector3(-1e9, -1e9, -1e9)]
	for q: Vector3 in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		var s := 0 if q.x < 0.0 else 1
		lo[s] = lo[s].min(q)
		hi[s] = hi[s].max(q)
	var ry := 0.0
	var eye := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	for s in 2:
		eye[s] = (lo[s] + hi[s]) * 0.5
		ry += (hi[s].y - lo[s].y) / 2.0
	for em in _fx_eyes:
		em.set_shader_parameter(&"u_eye", eye)
		em.set_shader_parameter(&"u_eye_ry", maxf(0.005, ry / 2.0))


static func _first_skinned(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D and (n as MeshInstance3D).skin != null:
		return n
	for c in n.get_children():
		var s := _first_skinned(c)
		if s != null:
			return s
	return null


## arm bone positions in the skin's bind space + the arm radii measured from the mesh itself
func _arm_fx() -> void:
	if _skin_mesh == null:
		return
	var names: Array[StringName] = [&"upper_armL", &"forearmL", &"handL", &"upper_armR", &"forearmR", &"handR"]
	var pts := PackedVector3Array()
	for k in names:
		var r: BoneRec = by_key.get(k)
		if r == null:
			return
		pts.append(skel.get_bone_global_rest(r.bone).origin)     # (the skin mesh sits at the skeleton's origin)
	if _fx_tank != null:
		_fx_tank.set_shader_parameter(&"u_arm", pts)
	if _fx_skin == null:
		return       # the radii only serve the skin shader (untextured skin: the original costume)
	_fx_skin.set_shader_parameter(&"u_arm", pts)
	var arr: Array = _skin_mesh.mesh.surface_get_arrays(_skin_surf)
	var segs: Array = [[0, 1, 0], [1, 2, 1], [3, 4, 0], [4, 5, 1]]
	var ds: Array = [PackedFloat32Array(), PackedFloat32Array()]
	for q: Vector3 in (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		var best := 1e9
		var bk := 0
		var bt := 0.0
		for sg: Array in segs:
			var a: Vector3 = pts[sg[0]]
			var ab: Vector3 = pts[sg[1]] - a
			var tt := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var d := q.distance_to(a + ab * tt)
			if d < best:
				best = d
				bk = sg[2]
				bt = tt
		if best < 0.22 and bt > 0.3 and bt < 0.8:
			ds[bk].append(best)
	_fx_skin.set_shader_parameter(&"u_arm_r", Vector2(_pick_radius(ds[0], 0.09), _pick_radius(ds[1], 0.075)))


static func _pick_radius(a: PackedFloat32Array, dflt: float) -> float:
	if a.size() < 8:
		return dflt
	a.sort()
	return a[floori(a.size() * 0.4)]


## The torso as the arms see it, measured from the character's own skin (rest pose, actor space): per 2.5 cm height band, the band's
## centre, its outer radius in 32 directions and the bone that carries it, plus the arm radii. _body_push keeps a point outside it in the
## posed body; the weapon IK uses it so hands, forearms and elbows go around the belly and chest instead of through them.
func _body_shape() -> void:
	if _body_cache.has(B.file):
		body = _body_cache[B.file]
		return
	if _body_from_js():
		_body_cache[B.file] = body
		return
	var BH := 0.025
	var NA := 32
	var TOR: Array[StringName] = [&"pelvis", &"spine1", &"spine2", &"chest"]
	var arm: Array = [PackedFloat32Array(), PackedFloat32Array()]
	var pts := PackedFloat32Array()
	var off := _model_xf.origin
	var seg_keys := {&"upper_armL": [&"upper_armL", &"forearmL", 0], &"upper_armR": [&"upper_armR", &"forearmR", 0], &"forearmL": [&"forearmL", &"handL", 1], &"forearmR": [&"forearmR", &"handR", 1]}
	var st: Array[Node] = [model]
	while not st.is_empty():
		var nn: Node = st.pop_back()
		st.append_array(nn.get_children())
		if not (nn is MeshInstance3D) or (nn as MeshInstance3D).skin == null:
			continue
		var mi := nn as MeshInstance3D
		var sk := mi.skin
		var nbind := sk.get_bind_count()
		var bind_t := PackedInt32Array()
		bind_t.resize(nbind)
		var bind_a := PackedInt32Array()
		bind_a.resize(nbind)
		var seg_a := PackedVector3Array()
		seg_a.resize(nbind)
		var seg_b := PackedVector3Array()
		seg_b.resize(nbind)
		for bi in nbind:
			var bn := sk.get_bind_name(bi)
			var key := StringName(san(String(bn) if bn != &"" else skel.get_bone_name(sk.get_bind_bone(bi))))
			bind_t[bi] = TOR.find(key)
			bind_a[bi] = -1
			if seg_keys.has(key):
				var ra: BoneRec = by_key.get(seg_keys[key][0])
				var rb: BoneRec = by_key.get(seg_keys[key][1])
				if ra != null and rb != null:
					bind_a[bi] = seg_keys[key][2]
					seg_a[bi] = skel.get_bone_global_rest(ra.bone).origin + off
					seg_b[bi] = skel.get_bone_global_rest(rb.bone).origin + off
		for si in mi.mesh.get_surface_count():
			var arrs: Array = mi.mesh.surface_get_arrays(si)
			var vs: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
			var bs: PackedInt32Array = arrs[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arrs[Mesh.ARRAY_WEIGHTS]
			var idx: PackedInt32Array = arrs[Mesh.ARRAY_INDEX] if arrs[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var nv := vs.size()
			var per := bs.size() / maxi(1, nv)
			var K := PackedInt32Array()       # rest position (actor space) + torso bone index of every vertex
			K.resize(nv)
			for i in nv:
				var bk := 0
				var bw := -1.0
				for j in per:
					var w_ := ws[i * per + j]
					var bj := bs[i * per + j]
					# (a tie goes to the lower bone: in the glTF that one comes first and the JS keeps the first. Godot's import sorts each vertex's weights, so the slot order is gone. Tommy's rings of 50/50 vertices decide his body bands by this)
					if w_ > bw + 1e-5 or (w_ > bw - 1e-5 and bj < bk):
						bw = w_
						bk = bj
				K[i] = bind_t[bk]
				vs[i] = vs[i] + off
				var a := bind_a[bk]
				if a >= 0:                     # arm thickness: distance from the bone axis, mid-segment only
					var A := seg_a[bk]
					var ab := seg_b[bk] - A
					var s := clampf((vs[i] - A).dot(ab) / ab.length_squared(), 0.0, 1.0)
					if s > 0.25 and s < 0.75:
						arm[a].append(vs[i].distance_to(A + ab * s))
			# the body is low-poly, so its vertices alone leave most height bands empty: sample the torso triangles' surfaces every ~1.5 cm
			var nt := (idx.size() if not idx.is_empty() else nv) / 3
			for f in nt:
				# (glTF import swaps the first and last index of each triangle for Godot's winding. Undone here: the sampling grid and the vote start from the corner the JS starts from)
				var a0 := idx[f * 3 + 2] if not idx.is_empty() else f * 3 + 2
				var b0 := idx[f * 3 + 1] if not idx.is_empty() else f * 3 + 1
				var c0 := idx[f * 3] if not idx.is_empty() else f * 3
				var ka := K[a0]
				var kb := K[b0]
				var kc := K[c0]
				var cnt := (1 if ka >= 0 else 0) + (1 if kb >= 0 else 0) + (1 if kc >= 0 else 0)
				if cnt < 2:
					continue
				var k0 := ka if ka >= 0 else kb
				var pa := vs[a0]
				var u := vs[b0] - pa
				var wv_ := vs[c0] - pa
				var steps := clampi(ceili(maxf(u.length(), wv_.length()) / 0.015), 1, 40)
				for s in steps + 1:
					for tt in steps - s + 1:
						var p := float(s) / steps
						var q := float(tt) / steps
						pts.append(pa.x + u.x * p + wv_.x * q)
						pts.append(pa.y + u.y * p + wv_.y * q)
						pts.append(pa.z + u.z * p + wv_.z * q)
						pts.append(k0)
	if pts.size() < 400:
		body = null
		_body_cache[B.file] = null
		return
	var ual: BoneRec = by_key.get(&"upper_armL")
	var uar: BoneRec = by_key.get(&"upper_armR")
	var sh_y := minf(skel.get_bone_global_rest(ual.bone).origin.y + off.y if ual != null else 1e9, skel.get_bone_global_rest(uar.bone).origin.y + off.y if uar != null else 1e9) - 0.05     # stop below the armpits: the shoulder itself is where the arm attaches
	var y0 := 1e9
	var y1 := -1e9
	var np := pts.size()
	for i in range(1, np, 4):
		if pts[i] < sh_y:
			y0 = minf(y0, pts[i])
			y1 = maxf(y1, pts[i])
	var n := maxi(1, ceili((y1 - y0) / BH))
	var cx := PackedFloat32Array()
	cx.resize(n)
	var cz := PackedFloat32Array()
	cz.resize(n)
	var cnt_b := PackedInt32Array()
	cnt_b.resize(n)
	var vote := PackedInt32Array()
	vote.resize(n * 4)
	var lox := PackedFloat32Array()
	lox.resize(n)
	lox.fill(1e9)
	var loz := lox.duplicate()
	var hix := PackedFloat32Array()
	hix.resize(n)
	hix.fill(-1e9)
	var hiz := hix.duplicate()
	for i in range(0, np, 4):
		var yy := pts[i + 1]
		var b := floori((yy - y0) / BH)
		if b < 0 or b >= n or yy >= sh_y:
			continue
		lox[b] = minf(lox[b], pts[i])
		hix[b] = maxf(hix[b], pts[i])
		loz[b] = minf(loz[b], pts[i + 2])
		hiz[b] = maxf(hiz[b], pts[i + 2])
		cnt_b[b] += 1
		vote[b * 4 + int(pts[i + 3])] += 1
	for b in n:
		if cnt_b[b] > 0:                     # centre of the band's extent (sampling density does not pull it)
			cx[b] = (lox[b] + hix[b]) / 2.0
			cz[b] = (loz[b] + hiz[b]) / 2.0
	var r: Array[PackedFloat32Array] = []
	for b in n:
		var ra := PackedFloat32Array()
		ra.resize(NA)
		r.append(ra)
	for i in range(0, np, 4):
		var yy := pts[i + 1]
		var b := floori((yy - y0) / BH)
		if b < 0 or b >= n or yy >= sh_y:
			continue
		var dx := pts[i] - cx[b]
		var dz := pts[i + 2] - cz[b]
		var k := floori((atan2(dz, dx) / TAU + 0.5) * NA + 0.5) % NA
		var d := sqrt(dx * dx + dz * dz)
		if d > r[b][k]:
			var rb := r[b]
			rb[k] = d
			r[b] = rb
	for b in n:                                # fill gaps (sparse bins), then a conservative widen
		var R := r[b]
		var o := R.duplicate()
		for k in NA:
			if o[k] == 0.0:
				var a := 1
				while a < NA / 2 and o[(k + a) % NA] == 0.0 and o[(k - a + NA) % NA] == 0.0:
					a += 1
				R[k] = maxf(o[(k + a) % NA], o[(k - a + NA) % NA])
		var f := R.duplicate()
		for k in NA:
			R[k] = maxf(f[k], 0.5 * (f[(k + 1) % NA] + f[(k + NA - 1) % NA]))
		r[b] = R
	var bd := Body.new()
	bd.bh = BH
	bd.na = NA
	bd.y0 = y0
	bd.n = n
	bd.cx = cx
	bd.cz = cz
	bd.r = r
	bd.ok.resize(n)
	bd.bone.resize(n)
	for b in n:
		bd.ok[b] = 1 if cnt_b[b] >= 12 else 0
		var bk := 0
		for j in range(1, 4):
			if vote[b * 4 + j] > vote[b * 4 + bk]:
				bk = j
		bd.bone[b] = bk
	bd.tor.resize(4)
	for i in 4:
		var rr: BoneRec = by_key.get(TOR[i])
		bd.tor[i] = rr.bone if rr != null else -1
		bd.rest.append(_model_xf * skel.get_bone_global_rest(rr.bone) if rr != null else Transform3D.IDENTITY)
	var sort_pick := func(a: PackedFloat32Array, dflt: float) -> float:
		if a.size() <= 8:
			return dflt
		a.sort()
		return a[floori(a.size() * 0.6)]
	bd.r_u = sort_pick.call(arm[0], 0.08)
	bd.r_f = sort_pick.call(arm[1], 0.065)
	body = bd
	_body_cache[B.file] = bd


## The exact shape the JS measured for this model (body_shapes.json), when there is one. The sampling below walks the triangles from a corner, and the import changes a vertex's weight order and
## some triangles' corners, so a re-measure differs by a millimetre here and there, and the elbow search (see _ik) is sensitive enough to take another 0.15 rad step for it. A model not in the file is measured.
func _body_from_js() -> bool:
	var all: Variant = JSON.parse_string(FileAccess.get_file_as_string(BODY_SHAPES))
	if not (all is Dictionary) or not all.has(B.file):
		return false
	var d: Dictionary = all[B.file]
	var bd := Body.new()
	bd.y0 = d.y0
	bd.n = int(d.n)
	bd.cx = PackedFloat32Array(d.cx)
	bd.cz = PackedFloat32Array(d.cz)
	for a: Array in d.r:
		bd.r.append(PackedFloat32Array(a))
	bd.ok = PackedByteArray(d.ok)
	bd.bone = PackedInt32Array(d.bone)
	bd.r_u = d.r_u
	bd.r_f = d.r_f
	var TOR: Array[StringName] = [&"pelvis", &"spine1", &"spine2", &"chest"]
	bd.tor.resize(4)
	for i in 4:
		var rr: BoneRec = by_key.get(TOR[i])
		bd.tor[i] = rr.bone if rr != null else -1
		bd.rest.append(_model_xf * skel.get_bone_global_rest(rr.bone) if rr != null else Transform3D.IDENTITY)
	body = bd
	return true


## per frame, before any _body_push: map from the posed body back to the rest pose the shape was measured in, per torso bone
func _body_frame() -> void:
	var bd := body
	if bd == null:
		return
	_bd_inv = _act_xf.affine_inverse()
	for i in 4:
		if bd.tor[i] >= 0:
			_bd_cur[i] = bd.rest[i] * (_model_xf * skel.get_bone_global_pose(bd.tor[i])).affine_inverse()


## Keep the world point p at least `clr` outside the torso surface (moved straight out from the band's centre). Returns how deep it was
## (0 = already clear); with move = false p is only measured. The moved point comes back in _pushed (always set).
func _body_push(p: Vector3, clr: float, move: bool = true) -> float:
	_pushed = p
	var bd := body
	if bd == null:
		return 0.0
	var q0 := _bd_inv * p
	var b := floori(((_bd_cur[2] * q0).y - bd.y0) / bd.bh)                 # first guess through spine2, then the band's own bone
	var bi: int = bd.bone[b] if (b >= 0 and b < bd.n) else 2
	var q := _bd_cur[bi] * q0
	b = floori((q.y - bd.y0) / bd.bh)
	if b < 0 or b >= bd.n or bd.ok[b] == 0:
		return 0.0
	var dx := q.x - bd.cx[b]
	var dz := q.z - bd.cz[b]
	var d := sqrt(dx * dx + dz * dz)
	var R := bd.r[b]
	var f := (atan2(dz, dx) / TAU + 0.5) * bd.na
	var k0 := floori(f) % bd.na
	var tt := f - floorf(f)
	var lim := lerpf(R[k0], R[(k0 + 1) % bd.na], tt) + clr
	if d >= lim:
		return 0.0
	if move:
		var s := lim / d if d > 1e-4 else 0.0
		q.x = bd.cx[b] + (dx * s if d > 1e-4 else lim)
		q.z = bd.cz[b] + dz * s
		_pushed = _act_xf * (_bd_cur[bi].affine_inverse() * q)
	return lim - d


# ---------------- the skeleton as three.js showed it: world-space reads ----------------

## JS actor.updateMatrixWorld(true)
func _refresh_xf() -> void:
	_act_xf = actor.global_transform
	_aq = _act_xf.basis.get_rotation_quaternion()
	_ascale = _act_xf.basis.get_scale().x


## JS bone.getWorldPosition / setFromMatrixPosition(bone.matrixWorld). Live, like the JS call: anyone may read it after the actor moved
func bone_world_pos(i: int) -> Vector3:
	return actor.global_transform * (_model_xf * skel.get_bone_global_pose(i).origin)


## JS bone.getWorldQuaternion
func bone_world_quat(i: int) -> Quaternion:
	return actor.global_basis.get_rotation_quaternion() * skel.get_bone_global_pose(i).basis.get_rotation_quaternion()


func _add(k: int, x: float, y: float, z: float, w: float = 1.0) -> void:
	pose[k] += Vector3(x * w, y * w, z * w)


# ================= the frame =================
func update(dt: float, P: Player) -> void:
	var C := Config
	_isc = 1.0 / B.scale      # isc: metres -> design units
	_leg_k = (B.l1 + B.l2) / 0.65      # leg_k: leg length relative to Prog
	dt = minf(dt, 0.05)
	t += dt
	_dt = dt
	_P = P
	# blinking at natural intervals (every ~3-6 s, now and then a quick double blink): fast close, slightly slower open
	if t >= _bl_next:
		_bl_start = t
		var dbl := not _bl_dbl and randf() < 0.15
		_bl_dbl = dbl
		_bl_next = t + (0.38 if dbl else 2.0 + randf() * 2.8)
	var be := t - _bl_start
	_set_blink(Gait.sstep(0.0, 0.08, be) if be < 0.08 else (1.0 if be < 0.16 else 1.0 - Gait.sstep(0.16, 0.34, be)))
	pose.fill(Vector3.ZERO)
	py = Vector3.ZERO

	_sy = sin(P.yaw)
	_cy = cos(P.yaw)
	var fi := P.factory_interaction
	var settle_x := fi.settle_vx if fi != null else 0.0
	var settle_z := fi.settle_vz if fi != null else 0.0
	_lvf = (P.vx + settle_x) * _sy + (P.vz + settle_z) * _cy           # forward speed
	_lvs = (P.vx + settle_x) * _cy - (P.vz + settle_z) * _sy           # leftward speed
	_sp = U.hyp(P.vx + settle_x, P.vz + settle_z)
	var normal := P.mode == &"normal"

	# ---- smoothed layer weights ----
	w_air = U.damp(w_air, 1.0 if (not P.grounded and normal) else 0.0, 13.0, dt)
	w_hang = U.damp(w_hang, 1.0 if (P.mode == &"hang" or P.mode == &"pull" or P.mode == &"pole") else 0.0, 22.0, dt)
	w_swim = U.damp(w_swim, 1.0 if P.mode == &"swim" else 0.0, 9.0, dt)
	w_lad = U.damp(w_lad, 1.0 if P.mode == &"ladder" else 0.0, 14.0, dt)   # in the water / up a ladder
	w_strafe = U.damp(w_strafe, 1.0 if ((P.strafing or P.aiming or U.hyp(settle_x, settle_z) > 0.1) and normal) else 0.0, 14.0, dt)
	w_pu = U.damp(w_pu, 1.0 if P.punching else 0.0, 30.0 if P.punching else 11.0, dt)
	w_slam = U.damp(w_slam, 1.0 if P.slamming else 0.0, 26.0 if P.slamming else 12.0, dt)
	w_aim = U.damp(w_aim, 1.0 if P.aiming else 0.0, 14.0, dt)
	# fatigue: 0.4 at half health or less, 1 at a quarter or less. Cutscenes (pose_hook) and actors without health (their stand-in P) never show it
	var hp_k := P.hp / P.max_hp if (P.max_hp != 0.0 and not P.dead and not pose_hook.is_valid()) else 1.0
	w_fat = U.damp(w_fat, 1.0 if hp_k <= 0.25 else (0.4 if hp_k <= 0.5 else 0.0), 1.8, dt)
	w_pow = U.damp(w_pow, 1.0 if (P.power_aim and normal and not P.dead and not P.punching) else 0.0, 25.0 if P.punching else 12.0, dt)      # a punch in power mode takes the arm back for a moment        # power mode: left arm out along the aim (_power), gun lowered in the right hand
	cast_k = U.damp(cast_k, 0.0, 7.0, dt)                                              # a cast punches the left hand forward (set by cast_power)
	var ldur := P.land_dur if P.land_dur != 0.0 else 0.44
	var lu := 1.0 - P.land_t / ldur if P.land_t > 0.0 else 1.0
	var ldip := lu / 0.16 if lu < 0.16 else pow(maxf(0.0, 1.0 - (lu - 0.16) / 0.84), 1.5)        # fast drop, slower recovery
	var lk := clampf(P.land_impact / 17.0, 0.3, 1.0) if P.land_t > 0.0 else 0.0
	_land_w = lk * ldip * 0.95
	w_cr = U.damp(w_cr, 1.0 if P.crouching else 0.0, 16.0, dt)
	_wc = maxf(w_cr, _land_w) * (1.0 - w_air)
	run = U.damp(run, clampf(_sp / C.run_speed, 0.0, 1.0), 12.0, dt)
	var flip_on := P.flip >= 0.0
	w_flip = U.damp(w_flip, minf(1.0, sin(P.flip * PI) * 2.2) if flip_on else 0.0, 30.0, dt)

	w_sp = U.damp(w_sp, 1.0 if P.sprinting else 0.0, 7.0, dt)
	_wsp = w_sp
	w_wr = U.damp(w_wr, 1.0 if P.wall_run != null else 0.0, 14.0 if P.wall_run != null else 9.0, dt)       # wall run layer: replaces the ground / air layers while it is on
	var wr := w_wr
	var w_w := 1.0 - minf(1.0, w_swim + w_lad)           # the swim and ladder layers replace the ground / air ones
	_wg = (1.0 - w_air) * (1.0 - w_hang) * (1.0 - wr) * w_w     # ground layer
	_wa = w_air * (1.0 - w_hang) * (1.0 - wr) * w_w           # air layer
	_wh = w_hang
	_ws = w_strafe
	_wf = w_flip

	phase += dt * (5.0 + _sp * 0.55) * (1.0 if P.grounded else 0.4)

	_layer_ground(dt, P)
	_layer_crouch()
	_layer_air(dt, P)
	_layer_flip()
	if wr > 0.002:
		_layer_wall_run(dt, P, wr)
	_layer_ledge(P)
	if w_swim > 0.002:
		_layer_swim(dt, P)
	if w_lad > 0.002:
		_layer_ladder(P)
	if w_slam > 0.002:
		_layer_slam(dt, P)
	_layer_punch(dt, P)
	_layer_aim(dt, P)
	_layer_idle()
	_layer_fatigue(dt)
	# feet follow the legs so the soles stay roughly level
	for sd in 2:
		var th := pose[THIGH_L + sd].x - _g_th[sd]
		var sh := pose[SHIN_L + sd].x - _g_sh[sd]
		_add(FOOT_L + sd, -(th + sh) * 0.9, 0.0, 0.0, 1.0 - w_swim)                        # (a swimmer's feet are pointed, not level)

	# build: arms held out from a wide body, a neckless head that moves less on its own, the beanie propeller
	if B.arm_out != 0.0:
		_add(UPPER_ARM_L, 0.0, 0.0, B.arm_out)
		_add(UPPER_ARM_R, 0.0, 0.0, -B.arm_out)
	if B.head_k != 1.0:
		pose[NECK] *= B.head_k
		pose[HEAD] *= B.head_k
	if prop != null:
		var spin := 2.5 + 9.0 * run + 10.0 * _wsp + 26.0 * w_air + 30.0 * w_flip + 16.0 * w_hang + 22.0 * w_slam + 8.0 * w_swim + 10.0 * w_lad
		prop_v = U.damp(prop_v, spin, 4.0 if prop_v < spin else 1.2, dt)       # spins up quickly, winds down slowly
		prop_a = fmod(prop_a + prop_v * dt, TAU)
		prop.rotation = Vector3(0.0, prop_a, 0.0)
	var operating := P.factory_interaction
	if operating != null and operating.weight > 0.01:
		_add(SPINE1, 0.08, 0.0, 0.0, operating.weight)
		_add(CHEST, 0.1, 0.0, 0.0, operating.weight)
		_add(HEAD, 0.09, 0.0, 0.0, operating.weight)
	# ================= SEATED (driving): thighs forward, shins down, back against the seat; the hands go to the wheel after the pose is applied =================
	if seat != null and not is_nan(seat.w):
		w_seat = seat.w                                    # getting in / out: the vehicle controller plays the blend itself
	else:
		w_seat = U.damp(w_seat, 1.0 if seat != null else 0.0, 9.0 if seat != null else 8.0, dt)
	if seat != null:
		seat_last = seat
	if w_seat > 0.002 and seat_last != null:
		_seat_pose(seat_last, w_seat)
	if pose_hook.is_valid():
		pose_hook.call(self)          # optional pose override (used by the intro cutscene)
	# light low-pass on the final pose so no single frame can jerk (about 30 ms of smoothing)
	if not _ps_init:
		_ps = pose.duplicate()
		_pys = py
		_ps_init = true
	var kk := 1.0 - exp(-30.0 * dt)
	for k in KEYS.size():
		var q := _ps[k]
		q += (pose[k] - q) * kk
		_ps[k] = q
		pose[k] = q
	_pys += (py - _pys) * kk
	py = _pys
	_apply(P)
	_weapon(P, dt)
	_fists(maxf(w_pu, w_slam) * (1.0 - w_arm))
	if w_seat > 0.002 and seat_last != null:
		_seat_hands(seat_last, w_seat)
	if operating != null and operating.weight > 0.01:
		_refresh_xf()
		var pole := _aq * Vector3(-0.5, -0.8, -0.2)
		_ik(1, operating.target, pole, operating.weight)
		# The right hand reaches the actual moving button / cartridge handle.
		# A loose index finger presses; the remaining fingers settle around a grip.
		for f in range(1, 4):
			for j in 3:
				var rec := _fing[15 + f * 3 + j]
				if rec != null:
					skel.set_bone_pose_rotation(rec.bone, rec.rest * q_axis(Vector3.RIGHT, FCURL * 0.45 * operating.weight))
	_power(P)
	if hair != null:
		hair.update(dt, 1.0 - w_seat, 1.0 - w_swim)     # last: it swings off the head's final pose and place


func _set_blink(v: float) -> void:
	if v == _blink_last or _fx_eyes.is_empty():
		return
	_blink_last = v
	for em in _fx_eyes:
		em.set_shader_parameter(&"u_blink", v)


# ================= GROUND (two-bone leg IK on a foot trajectory) =================
func _layer_ground(dt: float, P: Player) -> void:
	var C := Config
	var v_eff := _sp                                              # strafing steps too, whatever direction he moves
	var ws := _ws
	var wg := _wg
	var wsp := _wsp
	var dir_s := -1.0 if (ws > 0.5 and _lvf < 0.0) else 1.0       # walking backwards in strafe mode
	# travel direction in the body frame (u_f forward, u_l left), smoothed
	var un := 1.0 / _sp if _sp > 0.3 else 0.0
	u_f = U.damp(u_f, lerpf(1.0, _lvf * un, ws) if _sp > 0.3 else 1.0, 14.0, dt)
	u_l = U.damp(u_l, lerpf(0.0, _lvs * un, ws) if _sp > 0.3 else 0.0, 14.0, dt)
	mv_s = U.damp(mv_s, clampf(v_eff / 1.2, 0.0, 1.0), 9.0, dt)   # smooth idle <-> moving
	sp_s = U.damp(sp_s, _sp, 8.0, dt)                             # smooth cadence input
	var moving := mv_s
	var rn := run
	# strafing (the chest stays on the aim): the hips turn toward the way he is going and the legs run that way, like a person
	# (or Ratchet) running across a firing line, instead of shuffling sideways. Past ~110 degrees off the aim the hips flip round
	# and he backpedals instead. Only 40 % of the turn is in the pelvis (untwisted by the lower spine, so the chest, shoulders and
	# weapon arms are exactly as when standing: twisting the upper spine wrings the shoulder skin); the legs turn the rest at the hips.
	var th0 := atan2(u_l, u_f)
	if bkp:
		if absf(th0) < 1.75:
			bkp = false
	elif absf(th0) > 2.0 and ws > 0.5:
		bkp = true
	var hip_t := (clampf(U.wrap_angle(th0 - PI), -0.95, 0.95) if bkp else clampf(th0, -1.2, 1.2)) * ws * clampf((_sp - 0.4) / 1.2, 0.0, 1.0)
	hip_yaw = U.damp(hip_yaw, hip_t * (1.0 - w_air) * (1.0 - w_pu) * (1.0 - w_cr * 0.5), 9.0, dt)
	var hy := hip_yaw
	leg_yaw = hy * (1.0 - _wh)
	pel_yaw = 0.4 * hy * (1.0 - _wh)
	# gait direction in the hip frame: straight ahead when the hips line up with the travel, a little sideways sweep for the rest
	var uf := cos(th0 - hy)
	var ul := sin(th0 - hy)
	_chy = cos(hy)
	_shy = sin(hy)
	# ---- duty-cycle gait: the planted foot slides back at EXACTLY the body's ground speed (no skating), cadence and stride rise with speed ----
	sp_g = U.damp(sp_g, _sp, 18.0, dt)                         # nearly raw speed: the feet must track the real ground speed
	var gq := Gait.params(sp_g * _isc, wsp, w_cr, B)           # the gait works in the model's own units
	var rate := gq.rate
	gq.rs *= moving                                            # stance sweep eases out as he comes to rest (idle <-> moving blend)
	cyc = fmod(cyc + dt * rate, 1.0)
	# effective planted-leg length (shorter = more knee flex); a tired body sags onto bent knees with the feet still planted
	var lst := (lerpf(0.63, 0.605, rn) + 0.08 * wsp - (0.05 * w_fat + 0.02 * Gait.sstep(0.4, 1.0, w_fat)) * (1.0 - w_cr)) * _leg_k
	var lift := (0.05 + 0.06 * rn + 0.24 * wsp) * moving * _leg_k
	var dir_k := lerpf(dir_s, uf, ws)
	_foot(0, cyc, gq, dir_k, ul, lift, dt, P, _fl)
	_foot(1, cyc + 0.5, gq, dir_k, ul, lift, dt, P, _fr)
	# hip height from the legs themselves: the hips ride at the highest point both legs can still reach (soft minimum of the two stance-leg reaches),
	# so they sink at double support, rise through mid-stance / flight, and drop to match a lower foot on a step. No hand-tuned bob curve.
	var top := B.ank + lst
	var h_raw := _smin3(_reach(_fl, lst), _reach(_fr, lst), top, 110.0) - _smin3(top, top, top, 110.0) + top
	var H := top - 0.6 * (top - h_raw)                                  # hips bob at 60 % of what the legs alone would allow (calmer; the IK absorbs the rest)
	py.y += (H - B.hip) * wg

	_solve_leg(0, _fl, H, moving)
	_solve_leg(1, _fr, H, moving)

	var cc := TAU * cyc
	var cs := cos(cc)
	var sn := sin(cc)
	# guard stance: feet a touch wider when standing; moving, the legs come back under the hips
	_add(THIGH_L, 0.0, 0.0, 0.1 * ws * (1.0 - 0.7 * moving), wg)
	_add(THIGH_R, 0.0, 0.0, -0.1 * ws * (1.0 - 0.7 * moving), wg)
	# hips part-turned toward the travel while strafing; spine1 + spine2 untwist it, so spine2 and the chest stay square to the aim
	_add(PELVIS, 0.0, 0.4 * hy, 0.0, wg)
	_add(SPINE1, 0.0, -0.25 * hy, 0.0, wg)
	_add(SPINE2, 0.0, -0.15 * hy, 0.0, wg)
	# arms: held close, small natural swing opposite to the legs, relaxed elbows
	var aw := wg * (1.0 - ws) * (1.0 - w_pu)
	var mv := moving
	var sw := (0.12 + 0.2 * rn + 0.85 * wsp) * mv * dir_s * B.arm_swing
	_add(UPPER_ARM_L, sw * cs + 0.05, 0.0, -0.09 + 0.03 * sn * mv, aw)
	_add(UPPER_ARM_R, -sw * cs + 0.05, 0.0, 0.09 + 0.03 * sn * mv, aw)
	_add(FOREARM_L, -(0.2 + 0.28 * rn * mv + 0.12 * rn * mv * maxf(0.0, -cs)), 0.0, 0.0, aw)
	_add(FOREARM_R, -(0.2 + 0.28 * rn * mv + 0.12 * rn * mv * maxf(0.0, cs)), 0.0, 0.0, aw)
	_add(FOREARM_L, 0.0, 0.0, 0.1, aw)
	_add(FOREARM_R, 0.0, 0.0, -0.1, aw)
	_add(HAND_L, -0.1, 0.0, 0.0, aw)
	_add(HAND_R, -0.1, 0.0, 0.0, aw)
	# sprint: pumping arms with sharp elbows, slight forward lean, big knee drive and long strides
	_add(FOREARM_L, -(0.75 + 0.35 * maxf(0.0, -cs)), 0.0, 0.0, aw * wsp)
	_add(FOREARM_R, -(0.75 + 0.35 * maxf(0.0, cs)), 0.0, 0.0, aw * wsp)
	_add(SPINE1, 0.1, 0.0, 0.0, wg * wsp)
	_add(SPINE2, 0.07, 0.0, 0.0, wg * wsp)
	_add(HEAD, -0.14, 0.0, 0.0, wg * wsp)
	_add(PELVIS, 0.0, -0.07 * cs, 0.0, wg * wsp)
	_add(SPINE2, 0.0, 0.1 * cs, 0.0, wg * wsp)
	# torso counter-rotation, roll and lean
	var lean := clampf(_lvf / C.run_speed, -0.6, 1.0) * 0.08
	_add(SPINE1, lean * 0.6, 0.0, 0.0, wg)
	_add(SPINE2, lean * 0.5, 0.0, 0.0, wg)
	_add(HEAD, -lean * 0.8, 0.0, 0.0, wg)
	# lean into acceleration and braking, roll into turns, torso leads the pivot (smoothed from the real velocity / heading, so every start, stop and turn reads)
	a_f = U.damp(a_f, (_lvf - (_lvf if is_nan(_lvf0) else _lvf0)) / maxf(dt, 1e-3), 9.0, dt)
	_lvf0 = _lvf
	yaw_v = U.damp(yaw_v, clampf(U.wrap_angle(P.yaw - (P.yaw if is_nan(_yaw0) else _yaw0)) / maxf(dt, 1e-3), -12.0, 12.0), 8.0, dt)
	_yaw0 = P.yaw
	var a_l := clampf(a_f / 40.0, -1.0, 1.0)
	var roll_k := clampf(yaw_v * sp_g / 16.0, -1.0, 1.0)
	var dyn := wg * (1.0 - 0.6 * w_aim) * (1.0 - w_pu)
	_add(SPINE1, 0.1 * a_l, 0.0, -0.1 * roll_k, dyn)
	_add(SPINE2, 0.05 * a_l, clampf(0.04 * yaw_v, -0.22, 0.22), -0.06 * roll_k, dyn)
	_add(HEAD, -0.06 * a_l, -clampf(0.03 * yaw_v, -0.16, 0.16), 0.08 * roll_k, dyn)
	_add(PELVIS, 0.0, 0.0, 0.07 * roll_k, dyn)
	_add(THIGH_L, -0.1 * maxf(0.0, -a_l), 0.0, 0.0, dyn * moving)     # braking: knees sink
	_add(THIGH_R, -0.1 * maxf(0.0, -a_l), 0.0, 0.0, dyn * moving)
	_add(SHIN_L, 0.2 * maxf(0.0, -a_l), 0.0, 0.0, dyn * moving)
	_add(SHIN_R, 0.2 * maxf(0.0, -a_l), 0.0, 0.0, dyn * moving)
	_add(PELVIS, 0.0, -0.05 * rn * mv * cs, 0.035 * rn * mv * sin(2.0 * cc) * 0.0, wg)
	_add(SPINE2, 0.0, 0.07 * rn * mv * cs, 0.0, wg)
	_add(PELVIS, 0.0, 0.0, 0.012 * mv * sn, wg)
	_add(SPINE2, 0.0, 0.0, -0.01 * mv * sn, wg)
	_add(CHEST, 0.012 * sin(t * 2.1), 0.0, 0.0, wg * (1.0 - rn))     # breathing
	# heel strikes: every footfall drops the body a touch and nods the torso
	var hs := pow(maxf(0.0, cos(2.0 * cc + 0.25)), 5.0) * mv * (0.4 + 0.6 * rn)
	py.y -= 0.008 * hs * wg
	_add(SPINE1, 0.014 * hs, 0.0, 0.0, wg)
	_add(HEAD, -0.015 * hs, 0.0, 0.0, wg)
	if B.waddle != 0.0:
		# Tommy: stubby legs under a wide body, so he rocks from foot to foot. The bean leans over the planted leg (left foot is down
		# for the first part of the cycle), the hips twist with the step, and every footfall gives a little bounce.
		var wd := B.waddle * wg * moving * (1.0 - 0.5 * ws) * (1.0 - w_pu)
		var s1 := sin(cc - 0.35)
		var rk := 1.0 - 0.45 * rn
		_add(SPINE1, 0.0, 0.05 * s1, -0.085 * s1 * rk, wd)
		_add(SPINE2, 0.0, 0.0, -0.035 * s1 * rk, wd)
		_add(HEAD, 0.0, 0.0, 0.06 * s1 * rk, wd)
		_add(PELVIS, 0.0, 0.07 * s1, 0.0, wd)
		py.x += 0.03 * s1 * rk * wd
		var bo := absf(sin(cc - 0.35))
		py.y += B.bounce * (0.035 * bo - 0.02) * (0.5 + 0.5 * rn) * wd
		# little arms flap out a touch with each step when running
		_add(UPPER_ARM_L, 0.0, 0.0, 0.1 * rn * bo, wd * (1.0 - ws))
		_add(UPPER_ARM_R, 0.0, 0.0, -0.1 * rn * bo, wd * (1.0 - ws))
	# guard stance
	_add(SPINE1, 0.1, 0.0, 0.0, ws * wg)
	var g_l := 1.0 - w_arm if B.relax_l else 1.0       # short arms: with a gun out the free left arm stays relaxed instead of guarding
	_add(UPPER_ARM_L, -0.75, 0.0, -0.05, ws * wg * (1.0 - w_pu) * g_l)
	_add(UPPER_ARM_R, -0.75, 0.0, 0.05, ws * wg * (1.0 - w_pu))
	_add(FOREARM_L, -1.85, 0.0, -0.45, ws * wg * (1.0 - w_pu) * g_l)
	_add(FOREARM_R, -1.85, 0.0, 0.45, ws * wg * (1.0 - w_pu))
	py.y -= 0.04 * ws * wg * _leg_k


# terrain: every foot is placed on the ground under it (stairs, ramps, kerbs); smoothed so a step edge never pops
func _foot_dy(sd: int, zh: float, lh: float, dt: float, P: Player) -> float:
	var tt := 0.0
	var W := P.world
	if W != null and P.grounded and _wg > 0.3:
		var l0 := (0.1 if sd == 0 else -0.1) + lh       # hip frame -> body frame
		var zf := zh * _chy - l0 * _shy
		var l := l0 * _chy + zh * _shy
		var g := W.ground_height(P.x + (_sy * zf + _cy * l) * B.scale, P.z + (_cy * zf - _sy * l) * B.scale, 0.06, P.y + 0.4)
		if g > -INF:
			tt = clampf(g - P.y, -0.3, 0.3) * _isc
	if sd == 0:
		fdy_l = U.damp(fdy_l, tt, 16.0, dt)
		return fdy_l
	fdy_r = U.damp(fdy_r, tt, 16.0, dt)
	return fdy_r


func _foot(sd: int, ph: float, gq: Gait.Params, dir_k: float, ul: float, lift: float, dt: float, P: Player, out: FootPos) -> void:
	Gait.foot(ph, gq, _gf)
	var z := _gf.z * dir_k
	var x := _gf.z * ul
	var g_b := _gf.b
	out.th = _gf.phi
	out.z = z
	out.x = x
	out.st = _gf.st
	out.y = B.ank + lift * g_b + _foot_dy(sd, z, x, dt, P)


static func _smin3(a: float, b: float, c: float, k: float) -> float:
	return -log(exp(-k * a) + exp(-k * b) + exp(-k * c)) / k


static func _reach(f: FootPos, lst: float) -> float:
	return f.y + sqrt(maxf(0.01, lst * lst - f.z * f.z - f.x * f.x))


func _solve_leg(sd: int, f: FootPos, H: float, moving: float) -> void:
	var l1 := B.l1
	var l2 := B.l2
	var wg := _wg
	var vyy := H - f.y
	var lat := f.x
	var vy_ := U.hyp(vyy, lat)
	var phi := atan2(lat, vyy)       # sideways reach: tilt the leg out of the sagittal plane
	var d := minf(U.hyp(f.z, vy_), l1 + l2 - 0.002)
	var ang0 := atan2(f.z, vy_)
	var alpha := acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var beta := acos(clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0))
	var th := -(ang0 + alpha)
	var sh := PI - beta
	# foot pitch: toe up at heel strike, toe down at push-off, relaxed in mid swing
	var cth := cos(f.th)
	var toe := maxf(0.0, -cth)
	toe = toe * toe * toe
	var pitch := -0.2 * cth + 0.22 * toe
	_add(THIGH_L + sd, th, 0.0, phi, wg)       # (LATS, the sign of the leg roll axis, is + : the foot goes to the character's left)
	_add(SHIN_L + sd, sh, 0.0, 0.0, wg)
	_add(FOOT_L + sd, -(th + sh) + pitch * moving, 0.0, -phi, wg)
	_add(TOE_L + sd, 0.25 * toe * moving, 0.0, 0.0, wg)
	_g_th[sd] = th * wg
	_g_sh[sd] = sh * wg


# ================= CROUCH (also landing dip) =================
func _layer_crouch() -> void:
	var a := 1.15
	var wc := _wc
	var ws := _ws
	_add(THIGH_L, -a, 0.0, 0.1, wc)
	_add(THIGH_R, -a, 0.0, -0.1, wc)
	_add(SHIN_L, 2.0 * a, 0.0, 0.0, wc)
	_add(SHIN_R, 2.0 * a, 0.0, 0.0, wc)
	py.y -= 0.65 * _leg_k * (1.0 - cos(a)) * wc
	py.z -= 0.05 * wc
	_add(SPINE1, 0.42 * B.bend, 0.0, 0.0, wc)
	_add(SPINE2, 0.15 * B.bend, 0.0, 0.0, wc)
	_add(HEAD, -0.5 * B.bend, 0.0, 0.0, wc)
	_add(UPPER_ARM_L, -0.45, 0.0, 0.0, wc * (1.0 - ws))
	_add(UPPER_ARM_R, -0.45, 0.0, 0.0, wc * (1.0 - ws))
	_add(FOREARM_L, -0.7, 0.0, 0.0, wc * (1.0 - ws))
	_add(FOREARM_R, -0.7, 0.0, 0.0, wc * (1.0 - ws))
	# landing only: arms flung out for balance, chest folds, head dips, shoulders sag (the weight of the body hitting the ground)
	var lw := _land_w * (1.0 - w_air) * (1.0 - w_pu)
	_add(UPPER_ARM_L, 0.2, 0.0, 0.55, lw)
	_add(UPPER_ARM_R, 0.2, 0.0, -0.55, lw)
	_add(SPINE2, 0.2, 0.0, 0.0, lw)
	_add(CHEST, 0.12, 0.0, 0.0, lw)
	_add(CLAVICLE_L, 0.0, 0.0, -0.06, lw)
	_add(CLAVICLE_R, 0.0, 0.0, 0.06, lw)
	py.z += 0.04 * lw


## piecewise curves, cosine-eased between keys
static func _cv(u: float, pts: Array[float]) -> float:
	if u >= pts[0]:
		return pts[1]
	var i := 0
	var n := pts.size()
	while i < n - 2:
		var u1 := pts[i]
		var u2 := pts[i + 2]
		if u <= u1 and u >= u2:
			var tt := (u1 - u) / (u1 - u2)
			return lerpf(pts[i + 1], pts[i + 3], 0.5 - 0.5 * cos(PI * tt))
		i += 2
	return pts[n - 1]


# ================= AIR (one continuous curve driven by smoothed vertical velocity) =================
func _layer_air(dt: float, P: Player) -> void:
	var C := Config
	var wa := _wa
	var raw := P.vy / C.jump_vel if P.vy >= 0.0 else P.vy / 22.0           # +1 launch ... 0 apex ... -1 fast fall
	var u0 := clampf(raw, -1.0, 1.2)
	launch_k = U.damp(launch_k, 0.0, 7.0, dt)
	if _was_ground and not P.grounded:
		u_air = u0       # start from the true launch value; a jump launches with a body stretch
		if P.vy > 2.0:
			launch_k = 1.0
	_was_ground = P.grounded
	u_air = U.damp(u0 if is_nan(u_air) else u_air, u0, 9.0, dt)
	var u := u_air
	var fl := (1.0 - _wf) * (1.0 - w_slam)                      # front-flip tuck / hammer fist replace the spread pose
	# platformer jump: both knees drive up together (tuck), legs reach back down for the landing; no scissoring
	var knee_f := _cv(u, CV_KNEE_F)
	var th_f := _cv(u, CV_TH_F)
	var th_b := th_f * 0.88
	var knee_b := knee_f * 0.92
	var arm_x := _cv(u, CV_ARM_X)   # arms rise with height, lower on the way down
	var arm_z := _cv(u, CV_ARM_Z)
	var elbow := _cv(u, CV_ELBOW)
	_add(THIGH_L, th_f, 0.0, 0.12, wa * fl)
	_add(THIGH_R, th_b, 0.0, -0.12, wa * fl)
	_add(SHIN_L, knee_f, 0.0, 0.0, wa * fl)
	_add(SHIN_R, knee_b, 0.0, 0.0, wa * fl)
	_add(UPPER_ARM_L, arm_x, 0.0, arm_z, wa * fl)
	_add(UPPER_ARM_R, arm_x, 0.0, -arm_z, wa * fl)
	_add(FOREARM_L, -elbow, 0.0, 0.0, wa * fl)
	_add(FOREARM_R, -elbow, 0.0, 0.0, wa * fl)
	_add(SPINE1, 0.1 + 0.1 * clampf(-u, 0.0, 1.0) + 0.1 * clampf(_lvf / C.run_speed, -1.0, 1.0), 0.0, 0.0, wa)
	var lk := launch_k                                          # takeoff: legs drive straight, chest opens, arms whip up, then everything settles into the tuck
	_add(SPINE1, -0.16 * lk, 0.0, 0.0, wa)
	_add(SPINE2, -0.08 * lk, 0.0, 0.0, wa)
	_add(HEAD, 0.1 * lk, 0.0, 0.0, wa)
	_add(THIGH_L, 0.45 * lk, 0.0, 0.0, wa * fl)
	_add(THIGH_R, 0.55 * lk, 0.0, 0.0, wa * fl)
	_add(SHIN_L, -0.7 * lk, 0.0, 0.0, wa * fl)
	_add(SHIN_R, -0.8 * lk, 0.0, 0.0, wa * fl)
	_add(UPPER_ARM_L, -0.5 * lk, 0.0, 0.0, wa * fl)
	_add(UPPER_ARM_R, -0.5 * lk, 0.0, 0.0, wa * fl)
	_add(HEAD, -0.08 - 0.12 * clampf(u, 0.0, 1.0), 0.0, 0.0, wa)
	if _ws > 0.5:
		_add(UPPER_ARM_L, -0.5, 0.0, 0.0, wa * _ws * fl)
		_add(UPPER_ARM_R, -0.5, 0.0, 0.0, wa * _ws * fl)


# ================= FRONT FLIP TUCK =================
func _layer_flip() -> void:
	var ar := w_arm
	var wf := _wf
	_add(THIGH_L, -1.9 + 0.4 * ar, 0.0, 0.05, wf)
	_add(THIGH_R, -1.9 + 0.4 * ar, 0.0, -0.05, wf)
	_add(SHIN_L, 2.35 - 0.2 * ar, 0.0, 0.0, wf)
	_add(SHIN_R, 2.35 - 0.2 * ar, 0.0, 0.0, wf)
	_add(SPINE1, 0.65, 0.0, 0.0, wf)
	_add(SPINE2, 0.25, 0.0, 0.0, wf)
	_add(HEAD, -0.45, 0.0, 0.0, wf)
	_add(UPPER_ARM_L, -1.5, 0.0, 0.1, wf)
	_add(UPPER_ARM_R, -1.5, 0.0, -0.1, wf)
	_add(FOREARM_L, -1.7, 0.0, 0.0, wf)
	_add(FOREARM_R, -1.7, 0.0, 0.0, wf)


# ================= WALL RUN =================
# a real run cycle against the wall: legs pump (the knee lifts as the leg swings through), both feet splay toward the wall, the arms swing opposite to the legs, the chest leans forward
func _layer_wall_run(dt: float, P: Player, wr: float) -> void:
	var sd := P.wall_run.side if P.wall_run != null else _wr_side
	_wr_side = sd
	wrc = fmod(wrc + dt * (2.4 + 0.18 * U.hyp(P.vx, P.vz)), 1.0)
	var ph := TAU * wrc
	for side in 2:
		var off := 0.0 if side == 0 else PI
		var arm := 1.0 if side == 0 else -1.0
		var f := ph + off
		var sn := sin(f)
		var th := -0.3 - 0.85 * sn
		var sh := 0.45 + 0.85 * maxf(0.0, sin(f + 0.9))
		_add(THIGH_L + side, th, 0.0, sd * 0.5, wr)
		_add(SHIN_L + side, sh, 0.0, 0.0, wr)
		_add(FOOT_L + side, -(th + sh) * 0.55, 0.0, -sd * 0.4, wr)
		_add(UPPER_ARM_L + side, -0.15 + 0.95 * arm * sin(ph), 0.0, 0.2 if side == 0 else -0.2, wr)
		_add(FOREARM_L + side, -1.15, 0.0, 0.0, wr)
	_add(SPINE1, 0.16, 0.0, 0.0, wr)
	_add(HEAD, -0.12, 0.0, 0.0, wr)
	_add(PELVIS, 0.0, 0.12 * sin(ph), 0.0, wr)
	py.y -= 0.04 * wr                                           # a little crouch into the run


# ================= LEDGE HANG / PULL-UP =================
func _layer_ledge(P: Player) -> void:
	var C := Config
	var wh := _wh
	var pull := clampf(P.mode_t / C.pull_time, 0.0, 1.0) if P.mode == &"pull" else 0.0
	var e := U.ease_in_out(clampf(pull / 0.7, 0.0, 1.0))
	var arc := sin(PI * clampf(pull, 0.0, 1.0))
	var sway := sin(t * 3.0) * 0.04 * (1.0 - pull)
	# twist the arms so the palms face forward (onto the ledge) while hanging, easing back as he pushes up
	var tw := C.hang_twist * (1.0 - e)
	_add(UPPER_ARM_L, lerpf(-2.95, -0.55, e), -tw, 0.14 + sway, wh)
	_add(UPPER_ARM_R, lerpf(-2.95, -0.55, e), tw, -0.14 + sway, wh)
	_add(FOREARM_L, -1.5 * arc - 0.1, 0.0, 0.0, wh)
	_add(FOREARM_R, -1.5 * arc - 0.1, 0.0, 0.0, wh)
	_add(SPINE1, 0.9 * sin(PI * clampf(pull * 1.1, 0.0, 1.0)) - 0.04, 0.0, 0.0, wh)
	_add(HEAD, -0.3 + 0.5 * pull, 0.0, 0.0, wh)
	_add(THIGH_L, 0.1 - 1.0 * arc, 0.0, 0.05, wh)
	_add(SHIN_L, 0.3 + 1.4 * arc, 0.0, 0.0, wh)
	_add(THIGH_R, 0.12 + 0.15 * arc, 0.0, -0.05, wh)
	_add(SHIN_R, 0.35 + 0.5 * arc, 0.0, 0.0, wh)
	_add(PELVIS, sway * 1.5, 0.0, 0.0, wh)
	# the catch: the body's momentum swings the legs forward under the ledge and they settle back like a pendulum; the
	# pull starts with the elbows driving down and back (chest to the lip) before the hands press the body over
	var ht := P.mode_t if P.mode == &"hang" else 9.0
	var sw2 := 0.38 * exp(-4.0 * ht) * cos(7.5 * ht) * (1.0 - pull)
	_add(THIGH_L, -sw2, 0.0, 0.0, wh)
	_add(THIGH_R, -sw2 * 0.85, 0.0, 0.0, wh)
	_add(SHIN_L, 0.5 * maxf(0.0, sw2), 0.0, 0.0, wh)
	_add(SHIN_R, 0.4 * maxf(0.0, sw2), 0.0, 0.0, wh)
	_add(SPINE1, 0.12 * sw2, 0.0, 0.0, wh)
	var drive := sin(PI * clampf(pull / 0.55, 0.0, 1.0))
	_add(UPPER_ARM_L, 0.0, 0.0, 0.35 * drive, wh)              # elbows flare out and back
	_add(UPPER_ARM_R, 0.0, 0.0, -0.35 * drive, wh)
	_add(CLAVICLE_L, 0.0, 0.0, 0.12 * drive, wh)
	_add(CLAVICLE_R, 0.0, 0.0, -0.12 * drive, wh)


# ================= SWIMMING: the front crawl when moving, treading water at rest (the body's pitch, roll and depth are set in _apply) =================
func _layer_swim(dt: float, P: Player) -> void:
	var wsw := w_swim
	var spw := U.hyp(P.vx, P.vz)
	sw_cr = U.damp(sw_cr, clampf((spw - 0.5) / 2.0, 0.0, 1.0), 4.0, dt)
	var cr := sw_cr
	var wc2 := wsw * cr
	var wt := wsw * (1.0 - cr)
	var ph := TAU * P.swim_ph
	var tt := t
	for side in 2:
		var off := 0.0 if side == 0 else PI
		var sd := 1.0 if side == 0 else -1.0
		# crawl: each arm pulls through under the body nearly straight (60 % of the cycle), then recovers over the water with a high elbow, swung out round the side
		var a := fmod((ph + off) / TAU, 1.0)
		var pull := a < 0.6
		var u := a / 0.6 if pull else (a - 0.6) / 0.4
		var su := u * u * (3.0 - 2.0 * u)
		var ax := lerpf(-2.95, 0.4, su) if pull else lerpf(0.4, -2.95, su)
		var az := 0.1 if pull else 0.1 + 0.8 * sin(PI * u)
		var el := -0.3 * sin(PI * u) if pull else -1.5 * sin(PI * u)
		_add(UPPER_ARM_L + side, ax, 0.0, sd * az, wc2)
		_add(FOREARM_L + side, el, 0.0, 0.0, wc2)
		_add(HAND_L + side, -0.25 if pull else 0.1, 0.0, 0.0, wc2)
		var kk := sin(3.0 * ph + off)                          # flutter kick, three beats a stroke
		_add(THIGH_L + side, 0.08 + 0.24 * kk, 0.0, sd * 0.05, wc2)
		_add(SHIN_L + side, 0.3 + 0.3 * maxf(0.0, -kk), 0.0, 0.0, wc2)
		_add(FOOT_L + side, 0.75, 0.0, 0.0, wc2)
		# treading water: hands sculling out at the sides, legs pedalling (eggbeater), knees apart
		var sc := sin(tt * 3.1 + off * 0.5)
		var pd := tt * 3.4 + off
		_add(UPPER_ARM_L + side, -0.45, 0.45 * sc * sd, sd * 0.95, wt)
		_add(FOREARM_L + side, -0.55 - 0.15 * sc, 0.0, sd * 0.25, wt)
		_add(HAND_L + side, 0.0, 0.0, -sd * 0.3 * sc, wt)
		_add(THIGH_L + side, -0.85 + 0.35 * sin(pd), 0.0, sd * 0.32, wt)
		_add(SHIN_L + side, 1.25 + 0.4 * sin(pd + 1.2), 0.0, 0.0, wt)
		_add(FOOT_L + side, 0.25, 0.0, 0.0, wt)
	_add(PELVIS, 0.0, 0.38 * sin(ph), 0.0, wc2)                # the body rolls with each stroke (about its long axis: the pitched actor's Y)
	_add(SPINE2, 0.0, -0.12 * sin(ph), 0.0, wc2)
	_add(NECK, -0.3, 0.0, 0.0, wc2)
	_add(HEAD, -0.7, 0.3 * sin(ph - 0.5), 0.0, wc2)            # chin up, looking ahead along the water, turning to breathe with the roll
	_add(SPINE1, 0.06, 0.0, 0.0, wt)
	_add(HEAD, -0.06 + 0.04 * sin(tt * 0.7), 0.15 * sin(tt * 0.4), 0.0, wt)
	_add(CHEST, 0.02 * sin(tt * 1.6), 0.0, 0.0, wt)
	sw_pitch = lerpf(0.1, 1.32, cr) + 0.04 * sin(2.0 * ph) * cr    # _apply tips the whole body forward onto the water as the crawl takes over


# ================= LADDER: hand over hand up the rungs, the opposite foot stepping with each hand =================
func _layer_ladder(P: Player) -> void:
	var wld := w_lad
	var ph := TAU * P.lad_ph
	for side in 2:
		var off := 0.0 if side == 0 else PI
		var sd := 1.0 if side == 0 else -1.0
		var c := sin(ph + off)                                 # c: this hand reaching up; f: this foot stepping up (the opposite hand's beat)
		var f := sin(ph + off + PI)
		_add(UPPER_ARM_L + side, -2.5 - 0.4 * c, 0.0, sd * 0.2, wld)
		_add(FOREARM_L + side, -0.45 - 0.45 * (1.0 - c) * 0.5, 0.0, 0.0, wld)
		_add(THIGH_L + side, -0.45 - 0.55 * maxf(0.0, f), 0.0, sd * 0.08, wld)
		_add(SHIN_L + side, 0.6 + 0.8 * maxf(0.0, f), 0.0, 0.0, wld)
	_add(SPINE1, 0.14, 0.0, 0.0, wld)
	_add(HEAD, -0.3, 0.0, 0.0, wld)


# ================= HAMMER FIST (melee in a double jump): clasped fists raised overhead, then chopped down =================
func _layer_slam(dt: float, P: Player) -> void:
	var ws2 := w_slam
	var drop := P.slam_drop
	var k_u := P.slam_u
	var up := 0.0 if drop else k_u * k_u * (3.0 - 2.0 * k_u)
	sl_d = U.damp(sl_d, 1.0 if drop else 0.0, 22.0, dt)
	var d_d := sl_d
	# arms: overhead and together while winding up; swung down in front, hands locked, on the dive
	var ax := lerpf(-2.95, -1.25, d_d) * (0.15 + 0.85 * maxf(up, d_d))
	var az := lerpf(0.2, 0.12, d_d)
	var el := lerpf(-0.45, -0.25, d_d)
	_add(UPPER_ARM_L, ax, 0.0, -az, ws2)
	_add(UPPER_ARM_R, ax, 0.0, az, ws2)
	_add(FOREARM_L, el, 0.0, 0.22, ws2)
	_add(FOREARM_R, el, 0.0, -0.22, ws2)
	_add(HAND_L, 0.0, 0.0, 0.0, ws2)
	_add(SPINE1, lerpf(-0.25, 0.5, d_d), 0.0, 0.0, ws2)
	_add(SPINE2, lerpf(-0.2, 0.32, d_d), 0.0, 0.0, ws2)
	_add(CHEST, lerpf(-0.1, 0.18, d_d), 0.0, 0.0, ws2)
	_add(HEAD, lerpf(-0.3, 0.2, d_d), 0.0, 0.0, ws2)
	# legs: tucked at the top, then driven down and braced for the impact
	var th := lerpf(-1.05, -0.4, d_d)
	var kn := lerpf(1.5, 0.55, d_d)
	_add(THIGH_L, th, 0.0, 0.1, ws2)
	_add(THIGH_R, th * 0.9, 0.0, -0.1, ws2)
	_add(SHIN_L, kn, 0.0, 0.0, ws2)
	_add(SHIN_R, kn * 0.95, 0.0, 0.0, ws2)
	_add(FOOT_L, -(th + kn) * 0.5, 0.0, 0.0, ws2)
	_add(FOOT_R, -(th + kn) * 0.5, 0.0, 0.0, ws2)


# ================= PUNCH COMBO (left, right, left) with hip swing =================
func _layer_punch(dt: float, P: Player) -> void:
	var wp := w_pu * (1.0 - 0.3 * w_air)
	if P.punching:
		pu_last = P.punch_stage
	var st := pu_last
	var u := P.punch_u if P.punching else 1.0
	var right := st == 2
	var big := 1.25 if st == 3 else 1.0
	var wind := Gait.sstep(0.0, 0.3, u)
	var ext := Gait.sstep(0.2, 0.42, u) * (1.0 - Gait.sstep(0.58, 1.0, u)) if P.punching else 0.0
	ext_l = U.damp(ext_l, 0.0 if right else ext, 38.0, dt)
	ext_r = U.damp(ext_r, ext if right else 0.0, 38.0, dt)
	var d := 1.0 if right else -1.0
	pu_tw = U.damp(pu_tw, d * lerpf(-0.22 * wind, 0.55 * big, ext), 34.0, dt)
	var tw := pu_tw
	var ex_t := maxf(ext_l, ext_r)
	_add(PELVIS, 0.0, tw * 0.85, 0.0, wp)
	_add(SPINE1, 0.0, tw * 0.36, 0.0, wp)
	_add(SPINE2, 0.0, tw * 0.28, 0.0, wp)
	_add(CHEST, 0.0, tw * 0.14, 0.0, wp)
	_add(HEAD, 0.0, -tw * 1.0, 0.0, wp)
	_add(SPINE1, (0.12 + 0.2 * big * ex_t) * B.bend, 0.0, 0.0, wp)
	_add(SPINE2, (0.08 + 0.1 * ex_t) * B.bend, 0.0, 0.0, wp)
	_add(HEAD, -0.2 * B.bend, 0.0, 0.0, wp)
	_add(PELVIS, 0.0, 0.0, -d * 0.1 * ex_t, wp)                # hip dips into the punch
	py.y -= (0.06 + 0.03 * ex_t) * wp * _leg_k
	py.z += 0.08 * big * ex_t * wp
	py.x += d * -0.025 * ex_t * wp
	# fighting stance: lead leg forward, rear leg back, both knees soft; drive off the rear leg on the cross
	var drive_l := ext_l
	var drive_r := ext_r
	_add(THIGH_L, -0.30 - 0.25 * drive_l + 0.2 * drive_r, 0.0, 0.1, wp)
	_add(SHIN_L, 0.4 + 0.25 * drive_l + 0.15 * drive_r, 0.0, 0.0, wp)
	_add(THIGH_R, 0.22 + 0.15 * drive_l - 0.42 * drive_r, 0.0, -0.1, wp)
	_add(SHIN_R, 0.45 + 0.1 * drive_l + 0.35 * drive_r, 0.0, 0.0, wp)
	# arms: guard vs extended
	var gl := wp * (1.0 - ext_l)
	var gr := wp * (1.0 - ext_r)
	var pl := wp * ext_l
	var pr := wp * ext_r
	_add(UPPER_ARM_L, -0.75, 0.0, -0.05, gl)
	_add(FOREARM_L, -1.85, 0.0, -0.45, gl)
	_add(UPPER_ARM_R, -0.75, 0.0, 0.05, gr)
	_add(FOREARM_R, -1.85, 0.0, 0.45, gr)
	_add(UPPER_ARM_L, -1.52, 0.0, -0.1, pl)
	_add(FOREARM_L, -0.1, 0.0, 0.0, pl)
	_add(UPPER_ARM_R, -1.52, 0.0, 0.1, pr)
	_add(FOREARM_R, -0.1, 0.0, 0.0, pr)
	_add(CLAVICLE_L, 0.0, -0.12 * ext_l, 0.0, wp)
	_add(CLAVICLE_R, 0.0, 0.12 * ext_r, 0.0, wp)


# ================= AIMING / RECOIL (torso follows the aim; the arms are IK'd onto the weapon afterwards) =================
func _layer_aim(dt: float, P: Player) -> void:
	var w_a := w_aim * (1.0 - w_air * 0.3)
	rc = U.damp(rc, P.recoil, 45.0, dt)
	var ap := P.aim_pitch
	_add(SPINE1, 0.06 - ap * 0.22 - rc * 0.08, 0.0, 0.0, w_a)
	_add(SPINE2, -ap * 0.2 - rc * 0.06, 0.0, 0.0, w_a)
	_add(HEAD, ap * 0.15 + rc * 0.04, 0.0, 0.0, w_a)
	_add(SPINE2, 0.0, -0.12, 0.0, w_a)                                  # shoulders slightly open toward the weapon side
	_add(PELVIS, 0.0, 0.12, 0.0, w_a)
	# bladed stance (builds whose arms are short for their width): the chest turns to the right so the left shoulder comes forward to the gun; the head stays on target
	var gi: WeaponView.Info = wv.info if wv != null else null
	var tw_t := 0.0
	if gi != null and gi.two and not gi.pose.is_valid():
		var gh: Builds.Hold = B.w_off.get(gi.id)
		tw_t = lerpf(0.0 if gi.pistol else B.low_twist, gh.twist if (gh != null and not is_nan(gh.twist)) else B.aim_twist, w_aim) * w_arm * (1.0 - w_rl)     # (square again for a reload: _reload_hold works the gun in front of the belly)
	twist = U.damp(twist, tw_t, 12.0, dt)                  # (eased: a swap between guns with different stances must not snap the torso)
	var tw := twist
	if absf(tw) > 1e-3:
		_add(SPINE1, 0.0, -tw * 0.5, 0.0)
		_add(SPINE2, 0.0, -tw * 0.5, 0.0)
		_add(NECK, 0.0, tw * 0.5, 0.0)
		_add(HEAD, 0.0, tw * 0.5, 0.0)
	py.z -= rc * 0.015 * w_a
	# per-weapon firing response (springs live in WeaponView): the spine leans back and twists, the head stays level, hips ride back, knees absorb it
	if wv != null:
		var tww := 1.0 - w_air * 0.5
		var still := 1.0 - mv_s
		var tkp := wv.tk.p
		var tky := wv.tk.y
		_add(SPINE1, -tkp * 0.55, tky * 0.4, 0.0, w_a * tww)
		_add(SPINE2, -tkp * 0.45, tky * 0.6, 0.0, w_a * tww)
		_add(CHEST, -tkp * 0.3, 0.0, 0.0, w_a * tww)
		_add(HEAD, tkp * 0.6, -tky * 0.5, 0.0, w_a * tww)
		_add(CLAVICLE_R, 0.0, 0.0, -tkp * 0.5, w_a * tww)
		py.z -= tkp * 0.12 * w_a
		_add(THIGH_L, -tkp * 0.4, 0.0, 0.0, w_a * tww * still)
		_add(THIGH_R, -tkp * 0.4, 0.0, 0.0, w_a * tww * still)
		_add(SHIN_L, tkp * 0.8, 0.0, 0.0, w_a * tww * still)
		_add(SHIN_R, tkp * 0.8, 0.0, 0.0, w_a * tww * still)
	if gi != null and gi.torso.is_valid():
		gi.torso.call(self, w_arm * (1.0 - w_air))      # melee models (the flail) twist and fold the body into the swing
	var rw := w_rl * (1.0 - w_air)
	var rr := rl_reach
	_add(SPINE1, 0.05 + 0.08 * rr, 0.0, 0.0, rw)
	_add(SPINE2, 0.03, 0.13 * rr, 0.0, rw)
	_add(CHEST, 0.0, 0.05 * rr, 0.0, rw)
	_add(HEAD, 0.1 - 0.06 * rr, -0.1 * rr, 0.0, rw)
	var rs := rw * (1.0 - mv_s)      # the reload stance never overrides the stride
	_add(THIGH_L, -0.05, 0.0, 0.0, rs)
	_add(THIGH_R, 0.05, 0.0, 0.0, rs)
	_add(SHIN_L, 0.08, 0.0, 0.0, rs)
	_add(SHIN_R, 0.08, 0.0, 0.0, rs)


# ================= IDLE LIFE (standing still): breathing, weight shifts, drifting gaze, loose arms =================
func _layer_idle() -> void:
	var still := clampf(1.0 - mv_s * 1.6, 0.0, 1.0) * _wg * (1.0 - w_pu) * (1.0 - _wsp) * (1.0 - 0.6 * _ws) * (1.0 - w_cr * 0.7) * (1.0 - w_slam)
	if still <= 0.002:
		return
	var tt := t
	var loose := 1.0 - w_arm                    # with a weapon out the arms belong to the IK
	var br := sin(tt * 1.55 + 0.4 * sin(tt * 0.21))       # slightly irregular breathing
	var br2 := sin(tt * 1.55 - 0.6)
	var shift := sin(tt * 0.33) * 0.7 + sin(tt * 0.17 + 1.3) * 0.3                         # slow weight shift from foot to foot
	# breathing: ribcage rises, shoulders lift a touch, head follows
	_add(SPINE1, 0.010 * br, 0.0, 0.0, still)
	_add(SPINE2, 0.016 * br, 0.0, 0.0, still)
	_add(CHEST, 0.022 * br, 0.0, 0.0, still)
	_add(CLAVICLE_L, 0.0, 0.0, 0.018 * br2, still)
	_add(CLAVICLE_R, 0.0, 0.0, -0.018 * br2, still)
	# weight shift: the pelvis rolls and slides toward the loaded leg, the spine counters it, the thighs stay plumb so the feet stay planted
	_add(PELVIS, 0.0, 0.02 * shift, 0.028 * shift, still)
	_add(SPINE1, 0.0, -0.012 * shift, -0.02 * shift, still)
	_add(SPINE2, 0.0, -0.01 * shift, -0.012 * shift, still)
	_add(THIGH_L, 0.0, -0.02 * shift, -0.028 * shift, still)
	_add(THIGH_R, 0.0, -0.02 * shift, -0.028 * shift, still)
	py.x += 0.012 * shift * still
	# gaze: slow drift, a little pitch, a slight head tilt
	var gy := 0.16 * sin(tt * 0.37) + 0.07 * sin(tt * 0.93 + 1.1)
	var gp := 0.035 * sin(tt * 0.53 + 0.7) + 0.02 * sin(tt * 1.3)
	_add(NECK, gp * 0.5 - 0.006 * br, gy * 0.4, 0.015 * sin(tt * 0.45), still)
	_add(HEAD, gp - 0.006 * br, gy * 0.6, 0.02 * sin(tt * 0.41 + 2.0), still)
	# loose arms: gentle out-of-phase sway, relaxed forearms and hands
	_add(UPPER_ARM_L, 0.035 * sin(tt * 0.8 + 0.5) + 0.02 * br, 0.0, 0.02 * sin(tt * 0.6) + 0.015 * shift, still * loose)
	_add(UPPER_ARM_R, 0.035 * sin(tt * 0.8 + 2.4) - 0.02 * br, 0.0, -0.02 * sin(tt * 0.6 + 1.2) + 0.015 * shift, still * loose)
	_add(FOREARM_L, -0.04 * (0.5 + 0.5 * sin(tt * 0.7 + 1.0)), 0.0, 0.0, still * loose)
	_add(FOREARM_R, -0.04 * (0.5 + 0.5 * sin(tt * 0.65 + 2.6)), 0.0, 0.0, still * loose)
	_add(HAND_L, 0.04 * sin(tt * 0.9), 0.0, 0.03 * sin(tt * 0.7), still * loose)
	_add(HAND_R, 0.04 * sin(tt * 0.85 + 1.4), 0.0, -0.03 * sin(tt * 0.72 + 0.6), still * loose)


# ================= FATIGUE (hurt: a tired slouch at half health, spent at a quarter). Pose only: speed, stride, cadence and aim are untouched =================
func _layer_fatigue(dt: float) -> void:
	var fi := _P.factory_interaction
	var g := _wg * (1.0 - w_pu) * (1.0 - w_slam) * (1.0 - _wf) * (1.0 - 0.75 * w_aim) * (1.0 - 0.5 * w_cr) * (1.0 - (fi.weight if fi != null else 0.0))
	var a := w_fat * g                                      # a: the whole slouch; b: what only shows once he is spent
	var b := Gait.sstep(0.4, 1.0, w_fat) * g
	fat_ph += dt * lerpf(3.0, 5.6, w_fat)                   # the breathing quickens as he tires
	if a <= 0.002:
		return
	var still := clampf(1.0 - mv_s * 1.6, 0.0, 1.0)
	var ph := fat_ph
	var K := 1.0 / B.head_k
	# the back rounds forward; a pose is cumulative down the chain, so the arms and head take the lean back out (they hang plumb, the head droops only by what is asked)
	var lean := (0.5 * a + (0.02 + 0.14 * still) * b) * B.bend
	var droop := 0.05 * a + 0.24 * b
	_add(SPINE1, 0.38 * lean, 0.0, 0.06 * b * B.bend)
	_add(SPINE2, 0.36 * lean, 0.0, 0.0)
	_add(CHEST, 0.26 * lean, 0.0, 0.0)
	_add(NECK, 0.4 * (droop - lean) * K, 0.0, 0.0)
	_add(HEAD, 0.6 * (droop - lean) * K, 0.0, -0.04 * b * K)
	# the shoulders drop and roll in; the free arms hang heavy, elbows slack
	_add(CLAVICLE_L, 0.0, -0.09 * a, -0.08 * a - 0.05 * b)
	_add(CLAVICLE_R, 0.0, 0.09 * a, 0.08 * a + 0.05 * b)
	var fa := 1.0 - _ws
	_add(UPPER_ARM_L, -lean - 0.06 * a, 0.0, 0.0, fa)
	_add(UPPER_ARM_R, -lean - 0.06 * a, 0.0, 0.0, fa)
	_add(FOREARM_L, 0.06 * a + 0.08 * b, 0.0, 0.0, fa)
	_add(FOREARM_R, 0.06 * a + 0.08 * b, 0.0, 0.0, fa)
	# heaving for breath: the ribcage lifts, the shoulders ride up with it, the head nods against it. Running shakes most of it away
	var br := (sin(ph) + 0.25 * sin(2.0 * ph + 0.6)) * (1.0 - 0.45 * run)
	var bc := 0.03 * a + 0.018 * b
	var bs := 0.02 * a + 0.035 * b
	_add(CHEST, -bc * br, 0.0, 0.0)
	_add(SPINE2, -0.4 * bc * br, 0.0, 0.0)
	_add(CLAVICLE_L, 0.0, 0.0, bs * br)
	_add(CLAVICLE_R, 0.0, 0.0, -bs * br)
	_add(HEAD, (0.012 * a + 0.02 * b) * br * K, 0.0, 0.0)


## power mode: the left arm reaches out from the shoulder along the aim, palm open (the swarm leaves from that hand); cast_k thrusts it on a cast
func _power(P: Player) -> void:
	var w := w_pow
	if w < 0.002:
		return
	if _arm_u[0] < 0 or _arm_f[0] < 0 or _arm_h[0] < 0:
		return
	_refresh_xf()
	var S := bone_world_pos(_arm_u[0])
	var E := bone_world_pos(_arm_f[0])
	var reach := S.distance_to(E) + E.distance_to(bone_world_pos(_arm_h[0]))
	var ap := P.aim_pitch
	var yaw := P.yaw + P.aim_yaw
	var cp := cos(ap)
	var ext := 0.8 + 0.17 * cast_k
	var tgt := Vector3(sin(yaw) * cp, sin(ap) - 0.06, cos(yaw) * cp) * (reach * ext) + S
	tgt.x += -cos(P.yaw) * -0.05                  # a touch toward the body's left so the arm is not across the chest
	tgt.z += sin(P.yaw) * -0.05
	var pole := _aq * Vector3(0.6, -1.0, -0.4)
	_ik(0, tgt, pole, w)
	for i in 15:                                  # open hand
		var rec := _fing[i]
		if rec != null:
			skel.set_bone_pose_rotation(rec.bone, skel.get_bone_pose_rotation(rec.bone).normalized().slerp(rec.rest, w))


func _apply(P: Player) -> void:
	var pel := _rec_pelvis
	if pel != null:
		skel.set_bone_pose_position(pel.bone, pel.rest_pos + py)
	var ly := leg_yaw
	var qly := Quaternion.IDENTITY
	var qlyi := Quaternion.IDENTITY
	var qlt := Quaternion.IDENTITY
	if ly != 0.0:
		qly = q_axis(Vector3.UP, ly)
		qlyi = q_inv(qly)
		qlt = q_axis(Vector3.UP, ly - pel_yaw)    # the turn the thighs add on top of the pelvis
	for r in bones:
		var k := r.pose_k
		if k < 0 and not r.chain:                 # (fingers and helper bones: back to rest, no one reads their rotation)
			skel.set_bone_pose_rotation(r.bone, r.rest)
			continue
		var pw := r.parent.w if r.parent != null else Quaternion.IDENTITY
		var p := pose[k] if k >= 0 else Vector3.ZERO
		var ql := r.rest
		if p != Vector3.ZERO or (ly != 0.0 and r.leg):
			var q := q_xyz(p.x, p.y, p.z)
			# leg poses are authored in the legs' own frame: while strafing the legs are turned (leg_yaw, part pelvis, the rest at the hip joints)
			if ly != 0.0 and r.leg:
				q = qly * q * qlyi
				if r.thigh:
					q = q * qlt
			# local = inv(pw) * D * pw * rest
			ql = q_inv(pw) * q * pw * r.rest
		skel.set_bone_pose_rotation(r.bone, ql)
		# world rotation (model space) = pw * local
		r.w = pw * ql
	# actor placement. Pivot sits at the centre of mass so the flip rotates about the hips.
	flip_ang = TAU * P.flip - sin(TAU * P.flip) if P.flip >= 0.0 else 0.0
	var pos := Vector3(P.x, P.y + B.pivot * B.scale, P.z)
	var ty := P.flip_type
	var rx := 0.0
	var rz := 0.0
	if P.flip >= 0.0:
		if ty == &"front":
			rx = flip_ang
		elif ty == &"back":
			rx = -flip_ang
		elif ty == &"side_l":
			rz = -flip_ang
		else:
			rz = flip_ang
	# hanging from a pole the whole body swings about the hands; a wall run leans the body out from the wall. Both weights ease in and out, so nothing snaps on grab / release
	var adt := _dt
	pole_w = U.damp(pole_w, 1.0 if (P.mode == &"pole" and P.pole != null) else 0.0, 12.0, adt)
	if P.pole != null:
		_pole_rx = -P.pole.sgn * P.pole.th
	wr_lean = U.damp(wr_lean, -P.wall_run.side * 0.32 if P.wall_run != null else 0.0, 9.0 if P.wall_run != null else 7.0, adt)
	if pole_w > 0.002:
		rx += _pole_rx * pole_w
	rz += wr_lean
	# swimming: tipped forward onto the water as the crawl takes over; the hips ride just under the surface for the crawl, deeper (shoulders at the waterline) treading water
	var wsw := w_swim
	if wsw > 0.002:
		rx += sw_pitch * wsw
		var cr := sw_cr
		var sy := P.y + Config.swim_float - lerpf(0.36, 0.0, cr) * B.scale + 0.03 * sin(TAU * 2.0 * P.swim_ph) * cr
		pos.y = lerpf(pos.y, sy, wsw)
	actor.position = pos
	actor.rotation = Vector3(rx, P.yaw, rz)     # (a Node3D's Euler order is YXZ, the same as the JS actor's)
	if seat_last != null and (w_seat > 0.002 or (seat != null and not is_nan(seat.sw) and seat.sw > 0.002)):
		_seat_place(seat_last, w_seat, rx, P.yaw, rz)
	elif _seat_scaled:
		actor.scale = Vector3.ONE * B.scale
		_seat_scaled = false
	if B.hang_fit:
		# shorter arms: while hanging (and through the start of the pull-up) lift the body so the hands really are on the ledge
		var lift := 0.0
		var L := P.ledge
		if L != null and w_hang > 0.01 and _arm_h[0] >= 0 and _arm_h[1] >= 0:
			_refresh_xf()
			var hy := maxf(bone_world_pos(_arm_h[0]).y, bone_world_pos(_arm_h[1]).y)
			var pull := clampf(P.mode_t / Config.pull_time, 0.0, 1.0) if P.mode == &"pull" else 0.0
			lift = maxf(0.0, L.t + 0.11 - hy) * w_hang * (1.0 - Gait.sstep(0.3, 0.85, pull))   # wrists just over the lip, like Prog's
		hang_lift = U.damp(hang_lift, lift, 30.0, adt)
		actor.position.y += hang_lift


# ---- driving: the seated pose, where the actor sits, and the hands on the wheel ----
func _seat_set(k: int, x: float, y: float, z: float, w: float) -> void:
	var p := pose[k]
	pose[k] = Vector3(p.x + (x - p.x) * w, p.y + (y - p.y) * w, p.z + (z - p.z) * w)


func _seat_pose(S: Seat, w: float) -> void:
	var st := S.steer
	_seat_set(PELVIS, 0.0, 0.0, 0.0, w)
	_seat_set(SPINE1, 0.07, 0.0, 0.0, w)
	_seat_set(SPINE2, 0.04, 0.0, 0.0, w)
	_seat_set(CHEST, 0.0, 0.0, 0.0, w)
	_seat_set(NECK, 0.0, 0.0, 0.0, w)
	_seat_set(HEAD, -0.05, st * 0.35, 0.0, w)
	_seat_set(CLAVICLE_L, 0.0, 0.0, 0.0, w)
	_seat_set(CLAVICLE_R, 0.0, 0.0, 0.0, w)
	_seat_set(THIGH_L, -1.5, 0.0, 0.1, w)
	_seat_set(THIGH_R, -1.5, 0.0, -0.1, w)
	_seat_set(SHIN_L, 1.42, 0.0, 0.0, w)
	_seat_set(SHIN_R, 1.42, 0.0, 0.0, w)
	_seat_set(FOOT_L, 0.08, 0.0, 0.0, w)
	_seat_set(FOOT_R, 0.08, 0.0, 0.0, w)
	_seat_set(UPPER_ARM_L, -0.7, 0.0, -0.12, w)
	_seat_set(UPPER_ARM_R, -0.7, 0.0, 0.12, w)
	_seat_set(FOREARM_L, -0.85, 0.0, -0.1, w)
	_seat_set(FOREARM_R, -0.85, 0.0, 0.1, w)
	_seat_set(HAND_L, 0.0, 0.0, 0.0, w)
	_seat_set(HAND_R, 0.0, 0.0, 0.0, w)
	py -= py * w
	if S.recline != 0.0:              # reclined: the neck and head take the tip back out, so he still looks down the road, and the knees open a little
		_add(NECK, 0.45 * S.recline, 0.0, 0.0, w)
		_add(HEAD, 0.55 * S.recline, 0.0, 0.0, w)
		_add(SHIN_L, -0.5 * S.recline, 0.0, 0.0, w)
		_add(SHIN_R, -0.5 * S.recline, 0.0, 0.0, w)
	if S.duck != 0.0:                 # ducking under the roof line
		_add(SPINE1, 0.32, 0.0, 0.0, S.duck * w)
		_add(SPINE2, 0.18, 0.0, 0.0, S.duck * w)
		_add(HEAD, 0.22, 0.0, 0.0, S.duck * w)


func _seat_place(S: Seat, w: float, rx: float, ry: float, rz: float) -> void:
	var sc := B.scale * S.scale
	var q := S.quat * Quaternion(Vector3.RIGHT, -S.recline) if S.recline != 0.0 else S.quat      # (tipped back about the hips: the pelvis stays on the seat point)
	var off := q * (pelvis_local * sc)
	var a := actor
	a.position = Vector3(lerpf(a.position.x, S.x - off.x, w), lerpf(a.position.y, S.y - off.y, w), lerpf(a.position.z, S.z - off.z, w))
	a.quaternion = q_yxz(rx, ry, rz).slerp(q, w)
	a.scale = Vector3.ONE * lerpf(B.scale, sc, S.sw if not is_nan(S.sw) else w)     # (getting in / out the controller spreads the size change over the whole walk and sit: S.sw)
	_seat_scaled = true


func _seat_hands(S: Seat, w: float) -> void:
	var wh := S.wheel
	if wh == null:
		return
	w *= S.hands                     # (the hands leave the wheel to get out, find it once in)
	if w < 0.002:
		return
	_refresh_xf()
	var al := S.steer * 1.9
	var ca := cos(al)
	var sa := sin(al)
	var ct := cos(wh.tilt)
	var st := sin(wh.tilt)
	var r := wh.r * 0.92
	var q := S.quat
	var dx := ca * r                 # the left hand's place on the rim (the wheel's 9 o'clock, turned with the wheel); the right hand is opposite
	var dy := -sa * ct * r
	var dz := -sa * st * r
	var t_l := q * Vector3(dx, dy, dz) + S.wheel_pos
	var t_r := q * Vector3(-dx, -dy, -dz) + S.wheel_pos
	_ik(0, t_l, q * Vector3(0.55, -1.0, -0.25), w)
	_ik(1, t_r, q * Vector3(-0.55, -1.0, -0.25), w)
	for rec in _fing:                # fingers close round the rim
		if rec != null:
			skel.set_bone_pose_rotation(rec.bone, rec.rest * q_axis(Vector3.RIGHT, FCURL * 0.65 * w))


# ---- hand-held weapons: place the mesh relative to the chest, then two-bone IK the arms onto its grips ----
## pose change of the chest since the rest pose, in actor space (so a held weapon can ride the torso through a flip)
func _chest_delta() -> Quaternion:
	var ch := _rec_chest
	return q_inv(_aq) * bone_world_quat(ch.bone) * q_inv(ch.rest_w)


func _weapon(P: Player, dt: float) -> void:
	var normal := P.mode == &"normal"
	var fi := P.factory_interaction
	var show := P.armed and normal and not P.crouch_hide and not P.slamming and not P.scoped and not (fi != null and fi.weight > 0.02)           # hands are free while physically operating a machine
	if wv != null:
		wv.set_weapon(P.weapon_idx if P.armed else -1)
		wv.update(dt, show)
	w_arm = U.damp(w_arm, 1.0 if show else 0.0, 14.0, dt)
	w_fl = U.damp(w_fl, 1.0 if (show and P.flip >= 0.0) else 0.0, 18.0 if P.flip >= 0.0 else 11.0, dt)
	if wv == null or not wv.group.visible or wv.info == null:
		return
	var info := wv.info
	var g := wv.group
	var chest := _rec_chest
	_refresh_xf()
	var c := actor.to_local(bone_world_pos(chest.bone))      # (own vector: the IK solver below reuses its scratch)
	_body_frame()
	# reload: weapon comes up to a canted 'work' pose, the left hand drives the mag / shells (see WeaponView.reload_hand)
	var rl_on := P.rl_on
	if rl_on:
		_rl = {"ph": P.rl_ph, "pu": P.rl_pu, "u": P.rl_u, "k": P.rl_n, "dur": P.rl_dur if P.rl_dur != 0.0 else 1.5, "empty": P.rl_empty}
	w_rl = U.damp(w_rl, 1.0 if rl_on else 0.0, 9.0 if rl_on else 7.0, dt)
	var wr := w_rl
	var rlp := info.rl_pose
	var tl := wr * Config.reload_tilt
	var sh := info.shoulder
	var w_a := maxf(w_aim * (1.0 - w_pow), 0.0 if sh else wr * 0.85)     # power mode: the gun goes to low-ready
	var rc_ := rc
	# shoulder-fired launcher rides on the right shoulder in every state; other weapons tuck the stock at the shoulder when aimed
	# and hang at a low-ready pitch in front of the body otherwise (never through the torso)
	var S := 1.15
	# carry ('low ready', like a patrolling soldier): the weapon rides diagonally across the front of the body, stock out at the
	# right side, muzzle down and toward his left, right hand on the grip, left hand on the handguard.
	# aimed: stock in the shoulder pocket, weapon up at cheek height, pointing along the aim.
	var pis := info.pistol
	var wo: Builds.Hold = B.w_off.get(info.id, Builds.NO_WOFF)           # per-character, per-weapon hold offsets (see Builds)
	var dual := info.dual != null
	var dx0 := -0.05 if dual else 0.0                                    # dual pistols: the right gun sits a little further right so the pair is centred
	var dx1 := 0.05 if dual else 0.0
	var aim := (Vector3(-0.28, 0.24, 0.12) if sh else (Vector3(-0.07 + dx0, 0.1, 0.6) if pis else Vector3(-0.14, 0.2, info.back * S + 0.04))) + wo.aim
	var low := (Vector3(-0.28, 0.24, 0.12) if sh else (Vector3(-0.27 + dx1, 0.05, 0.47) if pis else Vector3(-0.3, -0.04, 0.4))) + wo.low
	w_ads = U.damp(w_ads, 1.0 if P.ads else 0.0, 12.0, dt)
	var ak := w_ads * (0.5 if sh else 1.0)                               # ADS: weapon tucks a little higher and more central, like looking down the sights
	# little reload kicks (weapon space offsets from WeaponView), low-passed so a single frame never pops
	var kb := 1.0 - exp(-dt * 30.0)
	_bp = _bp.lerp(wv.bp, kb)
	_br = _br.lerp(wv.br, kb)
	var bp := _bp
	var br := _br
	var kk := wv.k
	var fgun := 0.0 if sh else w_fat      # tired: the carried gun hangs lower, muzzle down (aimed, it comes up exactly as usual)
	var px := lerpf(low.x, aim.x, w_a) + 0.05 * ak
	var py_ := lerpf(low.y - (0.09 if pis else 0.035) * fgun, aim.y, w_a) + 0.035 * ak
	var pz := lerpf(low.z, aim.z, w_a) - rc_ * 0.05 - 0.03 * ak
	# carried pistol: the arm is loose, so the gun bobs and sways with the stride (and breathes a little at rest)
	var lw := (1.0 - w_a) * (1.0 - minf(1.0, wr * 2.0)) if pis else 0.0
	var mvw := mv_s * lw
	var cy := TAU * cyc
	var rn := 0.55 + 0.45 * run
	var tb := Time.get_ticks_usec() * 1e-6
	# arm swing: the hand pumps forward / back and up / down with the stride like a normal run arm; the gun itself barely tilts
	var ph := cy + 0.3
	var sw_x := lw * 0.004 * sin(tb * 1.7) + mvw * rn * 0.006 * sin(ph)
	var sw_y := lw * 0.005 * sin(tb * 1.3 + 1.0) + mvw * rn * 0.015 * sin(ph + 0.7)
	var sw_z := mvw * rn * 0.04 * sin(ph)
	var sw_p := lw * 0.006 * sin(tb * 1.3) + mvw * rn * 0.015 * sin(ph + 0.4)
	var sw_yw := 0.0
	var sw_r := 0.0
	# keep the gun steady: low-pass the chest anchor so the stride bounce of the torso does not carry into the weapon (the arm IK still follows it)
	if not _cs_init:
		_cs = c
		_cs_init = true
	_cs = _cs.lerp(c, 1.0 - exp(-dt * 4.0))
	var stab := (1.0 - w_a) * mv_s * 0.9 if pis else 0.0
	g.position = Vector3(lerpf(c.x, _cs.x, stab) + px + rlp.x * tl + bp.x + sw_x + wo.rl.x * wr, lerpf(c.y, _cs.y, stab) + py_ + rlp.y * tl + bp.y + sw_y + wo.rl.y * wr, lerpf(c.z, _cs.z, stab) + pz + rlp.z * tl + bp.z + sw_z - kk.z + wo.rl.z * wr)
	var ap := P.aim_pitch
	var low_yaw := 0.0 if sh else (0.12 if pis else (wo.low_yaw if not is_nan(wo.low_yaw) else 0.78))
	var low_roll := 0.0 if sh else (0.04 if pis else -0.12)
	var low_pitch := (-0.95 if pis else (info.carry if sh else 0.28)) + (0.4 if pis else 0.2) * fgun
	g.rotation = Vector3(lerpf(low_pitch, -ap - rc_ * 0.035, w_a) + rlp.pitch * tl + br.x + sw_p - kk.p, lerpf(low_yaw, P.aim_yaw, w_a) + rlp.yaw * tl + br.y + sw_yw + kk.y + wo.rly * wr, lerpf(low_roll, 0.0, w_a) + rlp.roll * tl + br.z + sw_r + kk.r)
	if B.stock != Vector3.ZERO and wo.stock and info.two and not pis and not sh and not dual:
		# (Prog V1: aimed, a long gun's butt sits in the pocket inside his right shoulder, as a person shoulders a rifle; the gun pitches about that point. Reload and power mode keep their own holds)
		var ks := w_aim * (1.0 - w_pow) * (1.0 - wr)
		if ks > 0.001 and _arm_u[1] >= 0:
			var bt := _butt(info.id, g)
			if bt != Vector3.INF:
				var pocket := actor.to_local(bone_world_pos(_arm_u[1])) + _chest_delta() * B.stock + Vector3(bp.x, bp.y, bp.z - kk.z) * 0.25     # (a quarter of the recoil kick thumps the butt into the shoulder; the rest the shoulder takes, rocking back with the spine)
				g.position += (pocket - g.position - g.basis * bt) * ks
	if info.pose.is_valid():
		info.pose.call(wv, c, dt, self)            # melee models (the flail) place the whole hold themselves
	if wr > 0.001 and not sh:
		_reload_hold(info, wo, c, wr)
	# flips: the weapon is pulled in to a port-arms hold that is attached to the CHEST, so it tucks with the torso instead of hanging in the air
	var wfl := w_fl
	var qcw := Quaternion.IDENTITY
	if wfl > 0.003:
		var fh: Builds.FlipHold = Builds.FLIP_HOLD.get(info.id, Builds.FLIP_HOLD["rifle"])
		var D := _chest_delta()
		var fo := wo.flip
		g.position = g.position.lerp(D * Vector3(fh.x + fo.x, fh.y + fo.y, fh.z + fo.z) + c, wfl)
		g.quaternion = g.quaternion.normalized().slerp((D * q_yxz(fh.pitch, fh.yaw, fh.roll)).normalized(), wfl)
		qcw = Quaternion.IDENTITY.slerp(D.normalized(), wfl)
	if dual:
		# dual pistols: the left gun is the right one mirrored across the body (position and turn), so the left arm mirrors the right arm
		var qa := _aq
		var qg := g.global_basis.get_rotation_quaternion()
		var q := q_inv(qa) * qg
		q = Quaternion(q.x, -q.y, -q.z, q.w)
		q = q_inv(qg) * qa * q                     # mirrored turn, in weapon space
		var p := actor.to_local(g.to_global(info.grip_r))
		p.x = 2.0 * c.x - p.x
		p = g.to_local(actor.to_global(p))
		p -= q.normalized() * info.grip_r    # gun origin that puts its grip on the mirrored point
		info.dual.hold(w_a, p, q)
	# JS quirk, kept on purpose: aq and the IK solver share one quaternion (this._q3), so from the right arm's IK on, "aq" holds that forearm's solved local rotation and the left elbow's
	# pole is turned by it. Every hold in PROG_HOLDS was searched for in the running game with this in place: it decides where the left elbow goes.
	_q3 = _aq
	var hc := (body.r_f * 1.4 if body != null else 0.09) * _ascale      # a hand's clearance from the torso surface
	# right hand always holds the grip
	var target := g.to_global(info.grip_r)
	var v1g: Dictionary = _v1_grip(B.grips, info.id) if B.grips != "" else {}        # (Prog V1: the hands on the gun's real handle, baked by tools/v1_grips/bake.py)
	if v1g.has("r"):
		target = g.to_global(_v3(v1g["r"]["p"]))
	var pole := _q3 * (qcw * Vector3(-0.5, -1.0, -0.35))
	if B.v1_arms:               # (Prog V1: the elbow hangs down and out, as a person's, measured from his body and not from the solver's last rotation)
		pole = _aq * (qcw * Vector3(-0.6, -1.0, -0.2))
	var arm_clear := wr if info.pose.is_valid() else 1.0                          # the arms go round the body in every hold (melee models pose their own swings: only their reload)
	_ik(1, target, pole, w_arm, arm_clear, dt)
	if v1g.has("r"):
		_v1_hand(1, g, v1g["r"], w_arm)
	# pouch (left hip, on the outside of the body) expressed in weapon space, then the part poses / left-hand target
	_body_push(actor.to_global(c + B.pouch), hc)
	info.pouch = g.to_local(_pushed)
	var over := wv.pose_parts(_rl if (rl_on and _rl != null) else null)
	var hand := wv.hand_out
	var grip_l := _v3(v1g["l"]["p"]) if v1g.has("l") else info.grip_l
	if _hl_idx != wv.cur:
		_hl = grip_l
		_hl_idx = wv.cur
	_hl = _hl.lerp(hand if over else grip_l, 1.0 - exp(-dt * (34.0 if over else 16.0)))
	rl_reach = U.damp(rl_reach, wv.reach if over else 0.0, 14.0, dt)
	h_open = U.damp(h_open, wv.open if over else 0.0, 22.0, dt)
	if info.two:
		target = g.to_global(_hl)
		if wr > 0.001:                              # reloading: the free hand travels round the belly / chest, never through it
			_body_push(target, hc)
			target = target.lerp(_pushed, wr)
		# The carousel is worked from the front-left; keep the reload elbow outside the torso.
		var carousel := info.kind == "carousel"
		pole = _q3 * (qcw * Vector3(lerpf(0.5, 0.9, wr) if carousel else 0.5, lerpf(-1.0, -0.45, wr) if carousel else -1.0, lerpf(-0.35, 0.6, wr) if carousel else -0.35))
		if B.v1_arms:
			pole = _aq * (qcw * Vector3(0.5, -1.0, -0.1))
		var wl := w_arm * (maxf(w_a, wfl) if (pis and not dual) else 1.0) * (1.0 - w_pow)      # power mode: the left hand lets go (it casts); dual pistols: it always holds its own gun
		if B.support and not over and _arm_u[0] >= 0:
			# shorter arms: when the handguard is out of reach, the support hand slides back along the gun toward the right hand to the
			# furthest point it can reach (it never over-stretches through the body); if no point on the gun is reachable it lets go
			var v_s := bone_world_pos(_arm_u[0])
			var v_e := bone_world_pos(_arm_f[0])
			var v_w := bone_world_pos(_arm_h[0])
			var reach := (v_s.distance_to(v_e) + v_e.distance_to(v_w)) * 0.97
			var v_g := g.to_global(info.grip_r)
			var tb2 := -1.0
			for k in 21:
				var tt := 1.0 - k / 20.0
				if v_g.lerp(target, tt).distance_to(v_s) <= reach:
					tb2 = tt
					break
			_sup_t = U.damp(_sup_t, tb2 if tb2 > 0.2 else _sup_t, 14.0, dt)
			_sup_k = U.damp(_sup_k, 1.0 if tb2 > 0.2 else 0.0, 10.0, dt)
			target = v_g.lerp(target, _sup_t)
			wl *= _sup_k
		_ik(0, target, pole, wl, arm_clear, dt)
		if v1g.has("l") and not over:
			_v1_hand(0, g, v1g["l"], wl)
		if dual:
			_mirror_arm(wl * (1.0 - w_a) * (1.0 - minf(1.0, wr * 2.0)) * (1.0 - wfl))
	if v1g.has("r"):
		_v1_fingers(v1g, info.two and not over and not (info.pistol and w_a < 0.5))
	else:
		_fingers(info, w_arm)


# ---- Prog V1's baked grips: the hand locked to the gun, each finger where it touches the gun's real surface ----
static var _v1_grips: Dictionary = {}     # grips file -> {gun id: grip}
static var _butts: Dictionary = {}        # gun id -> the middle of its butt plate in the gun's own space (Build.stock)


## The middle of a gun's butt plate (its rearmost 2.5 cm of mesh), in the gun's own space; INF until its model is in
static func _butt(id: String, g: Node3D) -> Vector3:
	if _butts.has(id):
		return _butts[id]
	var inv := g.global_transform.affine_inverse()
	var pts := PackedVector3Array()
	for m in g.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.visible or mi.mesh == null:
			continue
		var xf := inv * mi.global_transform
		for si in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
				pts.append(xf * (v as Vector3))
	if pts.is_empty():
		return Vector3.INF
	var z0 := INF
	for p in pts:
		z0 = minf(z0, p.z)
	var s := Vector3.ZERO
	var n := 0
	for p in pts:
		if p.z < z0 + 0.025:
			s += p
			n += 1
	_butts[id] = s / n
	return _butts[id]


static func _v3(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


static func _v1_grip(f: String, id: String) -> Dictionary:
	if not _v1_grips.has(f):
		_v1_grips[f] = JSON.parse_string(FileAccess.get_file_as_string(f)) if FileAccess.file_exists(f) else {}
	return _v1_grips[f].get(id, {})


func _v1_hand(side: int, g: Node3D, grip: Dictionary, w: float) -> void:
	var ih := _arm_h[side]
	if ih < 0 or w < 0.002:
		return
	var q: Array = grip["q"]
	var want := g.global_basis.get_rotation_quaternion() * Quaternion(q[0], q[1], q[2], q[3])
	var loc := q_inv(bone_world_quat(_bone_parent[ih])) * want
	skel.set_bone_pose_rotation(ih, skel.get_bone_pose_rotation(ih).normalized().slerp(loc.normalized(), w))


func _v1_fingers(v1g: Dictionary, left_on: bool) -> void:
	for s in 2:
		var key := "l" if s == 0 else "r"
		if not v1g.has(key) or (s == 0 and not left_on):
			continue
		var fq: Array = v1g[key]["f"]
		for i in 15:
			var rec := _fing[s * 15 + i]
			if rec != null:
				var q: Array = fq[i]
				var open_k := 1.0 - 0.7 * h_open if s == 0 else 1.0
				skel.set_bone_pose_rotation(rec.bone, rec.rest * Quaternion.IDENTITY.slerp(Quaternion(q[0], q[1], q[2], q[3]), w_arm * open_k))


## dual pistols carried: the left gun is the right one mirrored, so the left arm takes the right arm's solved pose mirrored across the body
## (the rig's rest pose is symmetric). The two-bone IK alone leaves the forearm twist to the animation, which twists the left wrist off its grip.
func _mirror_arm(w: float) -> void:
	if w < 0.002:
		return
	var qa := _aq
	var qi := q_inv(qa)
	for i in 3:
		var L := _arm_u[0] if i == 0 else (_arm_f[0] if i == 1 else _arm_h[0])
		var R := _arm_u[1] if i == 0 else (_arm_f[1] if i == 1 else _arm_h[1])
		if L < 0 or R < 0:
			continue
		var q := qi * bone_world_quat(R)
		q = qa * Quaternion(q.x, -q.y, -q.z, q.w)     # mirrored, in world space
		q = (q_inv(bone_world_quat(_bone_parent[L])) * q).normalized()
		skel.set_bone_pose_rotation(L, skel.get_bone_pose_rotation(L).normalized().slerp(q, w))


## Reload hold. The aimed hold keeps the gun up at the right shoulder, where the left hand can only reach the mag well by going
## through the chest, so while reloading the gun comes down to the middle of the body, muzzle swung toward the free hand, with the part
## being worked (mag / loading port) out in front of the belly. Placed from the measured body (_body_shape), so it suits every build;
## a build with hand-fitted reload offsets (w_off[id].rl) keeps those. Last, the whole gun is pushed forward out of the torso if any of it
## would still be inside.
func _reload_hold(info: WeaponView.Info, wo: Builds.Hold, c: Vector3, wr: float) -> void:
	var bd := body
	var g := wv.group
	if bd == null:
		return
	var fitted := wo.rl != Vector3.ZERO or wo.rly != 0.0
	var work: Variant = info.mag.grab if info.kind == "mag" else (info.well if info.kind == "shell" else null)
	if not fitted and work != null:
		g.rotation.y += (0.3 if info.pistol else 0.55) * wr                     # muzzle toward the left hand, stock out under the right arm
		var wl := actor.to_local(g.to_global(work))                      # the worked point, actor space
		var wy := c.y - (0.22 if info.kind == "mag" else 0.12)
		var b := clampi(floori((wy - bd.y0) / bd.bh), 0, bd.n - 1)
		var front := -1e9                                                        # how far forward the body reaches around that height
		for i in range(maxi(0, b - 4), mini(bd.n - 1, b + 6) + 1):
			if bd.ok[i] != 0:
				for k in range(22, 27):
					front = maxf(front, bd.cz[i] + bd.r[i][k] * sin((float(k) / bd.na - 0.5) * TAU))
		var tx := bd.cx[b] + 0.05
		var tz := front + bd.r_f * 2.2
		g.position += Vector3((tx - wl.x) * wr, (wy - wl.y) * wr, (tz - wl.z) * wr)
	# nothing of the gun inside the body: sample its parts' bounds once, then push it straight forward by the deepest one
	var m := wv.models[wv.cur]
	# (the JS samples its parts' boxes at the gun's first reload; the exported models are merged differently, so those same points were dumped from the three.js build into gun_hulls.json. A gun not in there falls back to the JS way)
	if _gun_hulls.is_empty():
		var hd: Variant = JSON.parse_string(FileAccess.get_file_as_string(GUN_HULLS))
		if hd is Dictionary:
			for k: String in hd:
				var fl: PackedFloat64Array = hd[k]
				var pv := PackedVector3Array()
				for i in range(0, fl.size(), 3):
					pv.append(Vector3(fl[i], fl[i + 1], fl[i + 2]))
				_gun_hulls[k] = pv
	var hull: PackedVector3Array = _gun_hulls.get(info.id, _hulls.get(info.id, PackedVector3Array()))
	if hull.is_empty():
		var pts := PackedVector3Array()
		var inv := m.global_transform.affine_inverse()
		var st: Array[Node] = [m]
		while not st.is_empty():
			var o: Node = st.pop_back()
			var kids := o.get_children()         # (parent first, children in order: the walk of JS traverse, because the thinning below keeps every n-th corner)
			kids.reverse()
			st.append_array(kids)
			if not (o is MeshInstance3D):
				continue
			var hidden_ := false
			var u := o
			while u != null and u != m:                                           # the hidden spare round / rocket is not part of the gun
				if u is Node3D and not (u as Node3D).visible:
					hidden_ = true
					break
				u = u.get_parent()
			if hidden_:
				continue
			var bb := (o as MeshInstance3D).get_aabb()
			var M4 := inv * (o as MeshInstance3D).global_transform
			for i in 8:                                                               # (x, y, z bits as in the JS: AABB.get_endpoint counts them the other way round, and the thinning would keep other corners)
				pts.append(M4 * Vector3(bb.end.x if (i & 1) != 0 else bb.position.x, bb.end.y if (i & 2) != 0 else bb.position.y, bb.end.z if (i & 4) != 0 else bb.position.z))
		if pts.size() > 160:
			var every := ceili(pts.size() / 160.0)
			var fl := PackedVector3Array()
			for i in range(0, pts.size(), every):
				fl.append(pts[i])
			pts = fl
		hull = pts
		_hulls[info.id] = hull
	for it in 2:
		var mx := m.global_transform
		var deep := 0.0
		for q: Vector3 in hull:
			deep = maxf(deep, _body_push(mx * q, 0.015, false))
		if deep <= 0.0:
			break
		g.position += Vector3(0.0, 0.0, 1.0) * (deep * wr)


## closed fists for punches and the hammer fist
func _fists(w: float) -> void:
	if w < 0.02:
		return
	for s in 2:
		for f in 4:
			for j in 3:
				var rec := _fing[s * 15 + f * 3 + j]
				if rec != null:
					skel.set_bone_pose_rotation(rec.bone, rec.rest * q_axis(Vector3.RIGHT, FCURL * FIST_CURL[j] * w))
		for j in 3:
			var rec := _fing[s * 15 + 12 + j]
			if rec != null:
				skel.set_bone_pose_rotation(rec.bone, rec.rest * q_axis(Vector3.RIGHT, FCURL * FIST_THUMB[j] * w))


## wrap the fingers around whatever the hands hold (curl about each finger bone's local X axis)
func _fingers(info: WeaponView.Info, arm_w: float) -> void:
	if arm_w < 0.01:
		return
	var pistol := info.pistol
	var dual := info.dual != null
	var grip: Array = GRIP_PISTOL if pistol else GRIP_LONG
	for s in 2:
		var left := s == 0
		var trigger := not left or dual         # right index rests on the trigger: only a partial curl (both hands with dual pistols)
		for f in 4:
			for j in 3:
				var rec := _fing[s * 15 + f * 3 + j]
				if rec == null:
					continue
				var a: float = grip[f][j] * arm_w
				if f == 0 and trigger:
					a *= 0.6
				if f == 0 and left and pistol and not dual:
					a *= 0.9
				if left:
					a *= 1.0 - 0.7 * h_open
				skel.set_bone_pose_rotation(rec.bone, rec.rest * q_axis(Vector3.RIGHT, FCURL * a))
		for j in 3:
			var rec := _fing[s * 15 + 12 + j]
			if rec == null:
				continue
			var a := GRIP_THUMB[j] * arm_w * (1.0 - 0.5 * h_open if left else 1.0)
			skel.set_bone_pose_rotation(rec.bone, rec.rest * q_axis(Vector3.RIGHT, FCURL * a))


func _ik_pen(ang: float, S: Vector3, u: Vector3, a: float, h: float, pd: Vector3, tgt: Vector3, c_u: float, c_f: float) -> float:
	var d := q_axis(u, ang) * pd
	var e := S + u * a + d * h
	var s := 0.0
	s += _body_push(S.lerp(e, 0.45), c_u, false)
	s += _body_push(S.lerp(e, 0.7), c_u, false)
	s += _body_push(S.lerp(e, 1.0), c_u, false)
	s += _body_push(e.lerp(tgt, 0.2), c_f, false)
	s += _body_push(e.lerp(tgt, 0.45), c_f, false)
	s += _body_push(e.lerp(tgt, 0.7), c_f, false)
	s += _body_push(e.lerp(tgt, 0.9), c_f, false)
	return s


func _turn(bone: int, from: Vector3, to: Vector3, w: float) -> void:
	var dq := HairSpring._arc(from, to)
	var wq := dq * bone_world_quat(bone)
	var pq := q_inv(bone_world_quat(_bone_parent[bone]))
	var cur := skel.get_bone_pose_rotation(bone).normalized()
	_q3 = (pq * wq).normalized()      # (JS this._q3: read back by _weapon, see there)
	skel.set_bone_pose_rotation(bone, cur.slerp(_q3, w))


## Two-bone arm IK onto T, elbow toward `pole`. With a body weight `bw` (1 for a held gun) the elbow also swings round the shoulder-hand
## axis, as little as it can and at most ~75 degrees, to keep the upper arm and forearm out of the torso (see _body_shape). Arm-on-belly
## contact of a quarter of the arm's thickness is allowed (soft bodies press together), so ordinary holds are never pushed into a
## chicken wing, and the swing is eased in and out so it never pops. side: 0 = L, 1 = R. (JS reads the _bone matrices after updateMatrixWorld; get_bone_global_pose is always fresh.)
func _ik(side: int, T: Vector3, pole: Vector3, w: float, bw: float = 0.0, dt: float = 0.0) -> void:
	if w < 0.002:
		return
	var iu := _arm_u[side]
	var if_ := _arm_f[side]
	var ih := _arm_h[side]
	if iu < 0 or if_ < 0 or ih < 0:
		return
	var S := bone_world_pos(iu)
	var E := bone_world_pos(if_)
	var hp := bone_world_pos(ih)
	var l1 := S.distance_to(E)
	var l2 := E.distance_to(hp)
	var to_t := T - S
	var d := to_t.length()
	var u := to_t / (d if d != 0.0 else 1.0)
	d = clampf(d, absf(l1 - l2) + 0.02, l1 + l2 - 0.005)
	var a := (l1 * l1 + d * d - l2 * l2) / (2.0 * d)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var pd := (pole - u * pole.dot(u)).normalized()
	if body != null and (bw > 0.001 or absf(_swing[side]) > 1e-3):
		var bd := body
		var c_u := bd.r_u * _ascale * 0.75
		var c_f := bd.r_f * _ascale * 0.75
		var tgt := S + u * d
		# smallest swing that clears the body (ties keep last frame's side), searched both ways in 0.15 rad steps up to 1.35 rad
		var best := 0.0
		var bs := _ik_pen(0.0, S, u, a, h, pd, tgt, c_u, c_f) if bw > 0.001 else 0.0
		var last := _swing[side]
		if bs > 0.0:
			bs += 1e-3 * absf(last)
			var k := 1
			while k <= (3 if B.v1_arms else 9) and bs > 1e-4:      # (Prog V1: past about 25 degrees the avoidance lifts his elbows into wings, worse than a soft arm pressing on a soft body)
				for sg: float in [1.0, -1.0]:
					var ang := sg * k * 0.15
					var s := _ik_pen(ang, S, u, a, h, pd, tgt, c_u, c_f) + 1e-3 * absf(ang - last)
					if s < bs - 1e-4:
						bs = s
						best = ang
				k += 1
		best *= minf(1.0, bw)
		_swing[side] = U.damp(last, best, 8.0 if best == 0.0 else 12.0, dt) if dt > 0.0 else best
		pd = q_axis(u, _swing[side]) * pd
	var E2 := S + u * a + pd * h
	_turn(iu, (E - S).normalized(), (E2 - S).normalized(), w)
	var en := bone_world_pos(if_)
	var hn := bone_world_pos(ih)
	_turn(if_, (hn - en).normalized(), (T - en).normalized(), w)


## JS deathPose() in the main loop: lies down where he fell. Run after update().
func death_pose(P: Player) -> void:
	if not P.dead:
		return
	var k := U.ease_in_out(clampf(P.dead_t / 0.9, 0.0, 1.0))
	actor.rotation = Vector3((P.fall_dir if P.fall_dir != 0.0 else -1.0) * 1.5 * k, P.yaw, 0.0)
	actor.position.y = P.y + B.pivot * B.scale - B.dead_drop * k
