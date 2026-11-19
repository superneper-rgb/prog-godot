class_name SamboBody
extends Node3D
## SAMBO FENRIR's body (user, 2026-11-19): the `disguised` townsfolk (assets/folk/disguised: a rubber human suit with a little green alien driving it from a hatch in the head) as one character on
## its own skeleton. He is the only one of his kind (the crowd no longer walks that species). The species' own walk / run / idle clips play, and code goes on top of them each frame:
##   selfie   the stick up in his right hand (two-bone IK), the phone at its end turned on his face, its ring light lighting him (one small shadowless light: he is the main character)
##   wave     the stick swung about while he talks to it (the sponsor read)
##   look     the pilot in the hatch looks where he is told (or at the phone); the head, his steering, jerks after him a beat late, in steps, as in the species' idle
##   talk     the lid flaps on its hinge and the pilot bobs while a line plays; his free hand makes a point now and then
##   gesture  &"point" (the free hand at `point_at`), &"fists" (both up and shaking: a fit), &"hips" (the free hand on his hip), &"" none
## The owner moves the node (position, rotation.y = yaw: he faces +Z) and sets `speed` (m/s, picks and paces the clip). split(&"head" / &"body" / &"all"): this copy shows only the head (with the pilot
## in it), only the body, or all of him; the crane's snap is one copy of each.

const MODEL := "res://assets/folk/disguised/disguised.gltf"
const WALK_MS := 1.0 / 1.0667        # metres a second the walk clip covers at its own pace (stride 1.0 m a cycle)
const RUN_MS := 1.6 / 0.8            # and the run (stride 1.6 m)
const HEAD_GROUP: Array[String] = ["head", "lid", "pilot", "lever"]
const STICK_R := 0.0075
const PHONE := Vector3(-0.05, 1.86, 0.78)      # where the phone is held, model space (his right is -X): ahead of and above his face
const GRIP := 0.42                   # the hand this far from the shoulder, on the line to the phone

var skel: Skeleton3D
var mesh_i: MeshInstance3D
var anim: AnimationPlayer
var B := {}                          # bone name -> index
# what he is doing (the owner sets these)
var speed := 0.0
var selfie := 1.0
var wave := 0.0
var talking := false
var look_on := false
var look_target := Vector3.ZERO      # world
var gesture := &""
var point_at := Vector3.ZERO         # world
var ring_on := true
# props
var stick: MeshInstance3D
var phone: Node3D
var ring_light: OmniLight3D
var headset: Node3D
# state
var _clip := ""
var _t := 0.0
var _sel := 1.0
var _wav := 0.0
var _talk_k := 0.0
var _gest_w := 0.0
var _gest_x := 0.0                   # an aside while talking: 0 none, else seconds into it
var _gest_next := 1.2
var _fist_w := 0.0
var _hip_w := 0.0
var _point_w := 0.0
var _head_yaw := 0.0                 # where the head (his steering) is turned, relative to the body
var _head_goal := 0.0
var _head_wait := 0.0
var _pilot_yaw := 0.0
var _pilot_pitch := 0.0
var _part := &"all"
var _meshes := {}                    # &"all" / &"head" / &"body" -> Mesh
var _phone_xf := Transform3D.IDENTITY
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Sambo"
	_rng.seed = 1999
	var root: Node3D = (load(MODEL) as PackedScene).instantiate()
	add_child(root)
	skel = root.find_children("*", "Skeleton3D", true, false)[0]
	mesh_i = root.find_children("*", "MeshInstance3D", true, false)[0]
	anim = root.find_children("*", "AnimationPlayer", true, false)[0]
	for i in skel.get_bone_count():
		B[skel.get_bone_name(i)] = i
	for a: StringName in anim.get_animation_list():
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.play(&"idle")
	_clip = "idle"
	_meshes[&"all"] = mesh_i.mesh
	mesh_i.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_build_props()


# ---------------------------------------------------------------------------------------------- the frame

func update(dt: float) -> void:
	_t += dt
	var clip := "idle" if speed < 0.08 else ("walk" if speed < 1.45 else "run")
	if clip != _clip:
		anim.play(StringName(clip), 0.25)
		_clip = clip
	var rate := 1.0
	if clip == "walk":
		rate = clampf(speed / WALK_MS, 0.4, 1.8)
	elif clip == "run":
		rate = clampf(speed / RUN_MS, 0.5, 1.8)
	anim.advance(dt * rate)
	var k := 1.0 - exp(-dt * 7.0)
	_sel = lerpf(_sel, selfie, k * 0.8)
	_wav = lerpf(_wav, wave, k)
	_talk_k = lerpf(_talk_k, 1.0 if talking else 0.0, 1.0 - exp(-dt * 12.0))
	_fist_w = lerpf(_fist_w, 1.0 if gesture == &"fists" else 0.0, k)
	_hip_w = lerpf(_hip_w, 1.0 if gesture == &"hips" else 0.0, k)
	_point_w = lerpf(_point_w, 1.0 if gesture == &"point" else 0.0, k)
	_pose(dt)
	_props()


## The phone, world space: where the stream's camera is (a cutscene can look out of it)
func phone_xf() -> Transform3D:
	return _phone_xf


## Where his voice comes from: the pilot in the hatch
func mouth_world() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(B["pilot"]).origin + Vector3(0.0, 0.03, 0.0)


func head_world() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(B["head"]).origin


## Dialogue actor: look at the one talking to him (the pilot does; the head follows), back to the phone after
func look_at_point(x: float, z: float) -> void:
	look_on = true
	look_target = Vector3(x, global_position.y + 1.6, z)


func look_away() -> void:
	look_on = false


func set_talk(v: bool) -> void:
	talking = v


# ---------------------------------------------------------------------------------------------- the pose

func _g(i: int) -> Transform3D:
	return skel.get_bone_global_pose(i)


## Give bone i this skeleton-space basis (its parent as it is now), blended in by w
func _set_basis(i: int, gb: Basis, w: float = 1.0) -> void:
	var p := skel.get_bone_parent(i)
	var pb := _g(p).basis.orthonormalized() if p >= 0 else Basis.IDENTITY
	var q := (pb.inverse() * gb.orthonormalized()).get_rotation_quaternion()
	if w < 0.999:
		q = skel.get_bone_pose_rotation(i).slerp(q, clampf(w, 0.0, 1.0))
	skel.set_bone_pose_rotation(i, q)


## Turn bone i about a skeleton-space axis through its own origin
func _turn(i: int, axis: Vector3, a: float) -> void:
	if absf(a) < 1e-5:
		return
	_set_basis(i, Basis(axis, a) * _g(i).basis)


## Two-bone IK in skeleton space: the upper and lower bones turned (least rotation) so the end reaches `target`, the middle joint toward `pole`; blended by w
func _ik(up: int, lo: int, end: int, target: Vector3, pole: Vector3, w: float) -> void:
	if w <= 0.001:
		return
	var S := _g(up).origin
	var E0 := _g(lo).origin
	var H0 := _g(end).origin
	var l1 := S.distance_to(E0)
	var l2 := E0.distance_to(H0)
	var d := target - S
	var dl := clampf(d.length(), 0.05, (l1 + l2) * 0.995)
	var dn := d.normalized()
	var a := (l1 * l1 - l2 * l2 + dl * dl) / (2.0 * dl)
	var h := sqrt(maxf(0.0, l1 * l1 - a * a))
	var pn := pole - dn * pole.dot(dn)
	pn = pn.normalized() if pn.length() > 1e-4 else Vector3.DOWN
	var E := S + dn * a + pn * h
	var T := S + dn * dl
	_set_basis(up, Basis(Quaternion((E0 - S).normalized(), (E - S).normalized())) * _g(up).basis, w)
	var glo := _g(lo)
	var H1 := _g(end).origin
	_set_basis(lo, Basis(Quaternion((H1 - glo.origin).normalized(), (T - glo.origin).normalized())) * glo.basis, w)


func _to_skel(w: Vector3) -> Vector3:
	return skel.global_transform.affine_inverse() * w


func _phone_point() -> Vector3:
	var p := PHONE
	if _clip == "walk" or _clip == "run":
		p.y += sin(_t * TAU / 1.0667 * 2.0) * 0.012
	if _wav > 0.01:      # swung about while he hams it up: a loop out to his right and back, the phone twisting
		p += Vector3(0.24 * sin(_t * 2.1) - 0.06, 0.13 * sin(_t * 4.2) + 0.04, 0.1 * sin(_t * 1.6)) * _wav
	var down := Vector3(-0.3, 0.86, 0.32)      # the stick carried down by his side
	return down.lerp(p, _sel)


func _pose(dt: float) -> void:
	var up := Vector3.UP
	# ---- the selfie stick arm
	var sh: Vector3 = _g(B["upper_arm.R"]).origin
	var P := _phone_point()
	var grip := sh + (P - sh).normalized() * GRIP
	_ik(B["upper_arm.R"], B["forearm.R"], B["hand.R"], grip, Vector3(-1.0, -0.7, -0.3), _sel * 0.97)
	# ---- the free hand: on his hip, pointing, both fists up, or an aside while he talks
	var gw := 0.0
	var gt := Vector3(0.3, 1.15, 0.35)
	if _talk_k > 0.5 and _clip == "idle":
		_gest_next -= dt
		if _gest_x <= 0.0 and _gest_next <= 0.0:
			_gest_x = 0.001
		if _gest_x > 0.0:
			_gest_x += dt
			var u := _gest_x / 1.1
			gw = sin(PI * clampf(u, 0.0, 1.0)) * 0.85
			gt = Vector3(0.32, 1.18 + 0.05 * sin(_gest_x * 11.0), 0.38)
			if u >= 1.0:
				_gest_x = 0.0
				_gest_next = _rng.randf_range(0.5, 1.8)
	if _hip_w > 0.01:
		gt = gt.lerp(Vector3(0.28, 0.98, 0.06), _hip_w)
		gw = maxf(gw, _hip_w)
	if _point_w > 0.01:
		var ps := _to_skel(point_at)
		var s2: Vector3 = _g(B["upper_arm.L"]).origin
		gt = gt.lerp(s2 + (ps - s2).normalized() * 0.52, _point_w)
		gw = maxf(gw, _point_w)
	if _fist_w > 0.01:
		var shake := sin(_t * 19.0) * 0.035
		gt = gt.lerp(Vector3(0.26, 1.62 + shake, 0.24), _fist_w)
		gw = maxf(gw, _fist_w)
		if _sel < 0.5:      # (both fists only when the stick is not up)
			_ik(B["upper_arm.R"], B["forearm.R"], B["hand.R"], Vector3(-0.26, 1.62 - shake, 0.24), Vector3(-1.0, -0.5, -0.4), _fist_w * (1.0 - _sel))
	_ik(B["upper_arm.L"], B["forearm.L"], B["hand.L"], gt, Vector3(1.0, -0.8, -0.2), gw)
	# ---- the pilot looks; the head (his steering) jerks after him, in steps
	var tgt := _to_skel(look_target) if look_on else P
	var hp: Vector3 = _g(B["pilot"]).origin
	var dv := tgt - hp
	var want_yaw := clampf(atan2(dv.x, dv.z), -1.25, 1.25)
	var want_pitch := clampf(atan2(dv.y, Vector2(dv.x, dv.z).length()), -0.5, 0.7)
	_pilot_yaw = lerpf(_pilot_yaw, want_yaw, 1.0 - exp(-dt * 9.0))
	_pilot_pitch = lerpf(_pilot_pitch, want_pitch, 1.0 - exp(-dt * 9.0))
	_head_wait -= dt
	if absf(_pilot_yaw - _head_goal) > 0.2 and _head_wait <= 0.0:
		_head_goal = clampf(roundf(_pilot_yaw / 0.17) * 0.17 * 0.8, -0.9, 0.9)
		_head_wait = 0.45
	_head_yaw = lerpf(_head_yaw, _head_goal, 1.0 - exp(-dt * 16.0))
	_turn(B["head"], up, _head_yaw)
	var right := Vector3.RIGHT.rotated(up, _head_yaw)
	_turn(B["pilot"], up, _pilot_yaw - _head_yaw)
	_turn(B["pilot"], right, -_pilot_pitch * 0.6 + _talk_k * 0.08 * sin(_t * 13.0))
	# ---- talking: the lid flaps on its hinge, the lever works
	if _talk_k > 0.01:
		var flap := (0.5 + 0.5 * sin(_t * 16.0)) * (0.6 + 0.4 * sin(_t * 5.3))
		_turn(B["lid"], right, -0.28 * flap * _talk_k)
		_turn(B["lever"], right, 0.35 * sin(_t * 9.0) * _talk_k)


# ---------------------------------------------------------------------------------------------- props

static func _mat(c: Color, rough: float, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _part_mesh(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## The selfie stick (black, telescoped), the phone in its clamp with a ring light round it, and a headset with a boom mic on the head
func _build_props() -> void:
	var black := _mat(Color(0.03, 0.03, 0.035), 0.35, 0.4)
	var chrome := _mat(Color(0.7, 0.72, 0.75), 0.2, 1.0)
	var cyl := CylinderMesh.new()
	cyl.top_radius = STICK_R
	cyl.bottom_radius = STICK_R * 1.4
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	stick = _part_mesh(self, cyl, black, Vector3.ZERO)
	stick.top_level = true
	phone = Node3D.new()
	phone.name = "Phone"
	phone.top_level = true
	add_child(phone)
	var body := BoxMesh.new()
	body.size = Vector3(0.078, 0.158, 0.009)
	_part_mesh(phone, body, _mat(Color(0.05, 0.05, 0.06), 0.3, 0.6), Vector3.ZERO)
	var screen := BoxMesh.new()
	screen.size = Vector3(0.07, 0.148, 0.001)
	_part_mesh(phone, screen, _mat(Color(0.55, 0.75, 1.0), 0.2, 0.0, 1.6), Vector3(0.0, 0.0, 0.0052))      # (+Z: the side turned to him)
	var lens := SphereMesh.new()
	lens.radius = 0.006
	lens.height = 0.012
	_part_mesh(phone, lens, _mat(Color(1.0, 0.1, 0.1), 0.3, 0.0, 3.0), Vector3(0.02, 0.06, -0.006))      # the LIVE light on its back
	var clamp_m := BoxMesh.new()
	clamp_m.size = Vector3(0.09, 0.02, 0.016)
	_part_mesh(phone, clamp_m, chrome, Vector3(0.0, -0.07, 0.0))
	_part_mesh(phone, clamp_m, chrome, Vector3(0.0, 0.07, 0.0))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.105
	ring.outer_radius = 0.122
	ring.rings = 24
	ring.ring_segments = 6
	_part_mesh(phone, ring, _mat(Color(0.92, 0.96, 1.0), 0.3, 0.0, 4.0), Vector3(0.0, 0.0, 0.004), Vector3(PI / 2.0, 0.0, 0.0))
	ring_light = OmniLight3D.new()
	ring_light.light_color = Color(0.86, 0.92, 1.0)
	ring_light.light_energy = 1.1
	ring_light.omni_range = 1.8
	ring_light.omni_attenuation = 1.4
	ring_light.shadow_enabled = false
	ring_light.light_specular = 0.6
	ring_light.position = Vector3(0.0, 0.0, 0.06)
	phone.add_child(ring_light)
	# the headset: an ear cup on his right ear, a boom round to the painted mouth
	var att := BoneAttachment3D.new()
	att.bone_idx = B["head"]
	skel.add_child(att)
	headset = Node3D.new()
	headset.name = "Headset"
	att.add_child(headset)
	var rest := skel.get_bone_global_rest(B["head"])
	headset.transform = rest.affine_inverse()      # (so its children are placed in the model's own rest space)
	var cup := CylinderMesh.new()
	cup.top_radius = 0.036
	cup.bottom_radius = 0.04
	cup.height = 0.026
	cup.radial_segments = 12
	_part_mesh(headset, cup, black, Vector3(-0.128, 1.56, -0.004), Vector3(0.0, 0.0, PI / 2.0))
	var boom := CylinderMesh.new()
	boom.top_radius = 0.0035
	boom.bottom_radius = 0.0035
	boom.height = 0.15
	boom.radial_segments = 6
	var b0 := Vector3(-0.13, 1.545, 0.01)
	var b1 := Vector3(-0.045, 1.505, 0.128)
	var bm := _part_mesh(headset, boom, black, (b0 + b1) * 0.5)
	bm.basis = _basis_along(b1 - b0)
	var mic := SphereMesh.new()
	mic.radius = 0.012
	mic.height = 0.024
	_part_mesh(headset, mic, _mat(Color(0.08, 0.08, 0.09), 0.8), b1)


static func _basis_along(d: Vector3) -> Basis:
	var y := d.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _props() -> void:
	var show_kit := _part != &"body" and _part != &"head" and visible
	stick.visible = show_kit and _sel > 0.02
	phone.visible = stick.visible
	ring_light.visible = phone.visible and ring_on
	if not stick.visible:
		return
	var X := skel.global_transform
	var hand: Vector3 = X * _g(B["hand.R"]).origin
	var fore: Vector3 = X * _g(B["forearm.R"]).origin
	var P := X * _phone_point()
	var grip := hand + (hand - fore).normalized() * 0.05      # (in the fist, just past the wrist)
	var d := P - grip
	var L := d.length()
	if L < 0.05:
		return
	stick.global_transform = Transform3D(_basis_along(d).scaled(Vector3(1.0, L, 1.0)), (grip + P) * 0.5)
	# the phone faces his face: its +Z toward the pilot, its up along the stick's sideways-up
	var face := mouth_world()
	var z := (face - P).normalized()
	var upv := (d.normalized() - z * d.normalized().dot(z)).normalized() if absf(d.normalized().dot(z)) < 0.98 else Vector3.UP
	var x := upv.cross(z).normalized()
	_phone_xf = Transform3D(Basis(x, z.cross(x), z), P + d.normalized() * 0.02)
	phone.global_transform = _phone_xf


# ---------------------------------------------------------------------------------------------- the snap at the neck

## Show only the head (and the pilot in it), only the body, or all of him (the meshes are cut once, from the suit's own skin weights)
func split(part: StringName) -> void:
	_part = part
	if not _meshes.has(part):
		_cut_meshes()
	mesh_i.mesh = _meshes[part]
	headset.visible = part != &"body"


func _cut_meshes() -> void:
	var src: Mesh = _meshes[&"all"]
	var a: Array = src.surface_get_arrays(0)
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var wts: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var per := bones.size() / maxi(1, (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var head_bind := {}
	var sk := mesh_i.skin
	for b in sk.get_bind_count():
		if HEAD_GROUP.has(String(sk.get_bind_name(b))):
			head_bind[b] = true
	var nv := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var is_head := PackedByteArray()
	is_head.resize(nv)
	for v in nv:
		var w := 0.0
		for k in per:
			if head_bind.has(bones[v * per + k]):
				w += wts[v * per + k]
		is_head[v] = 1 if w > 0.5 else 0
	var hi := PackedInt32Array()
	var bi := PackedInt32Array()
	var t := 0
	while t + 2 < ix.size():
		var n := is_head[ix[t]] + is_head[ix[t + 1]] + is_head[ix[t + 2]]
		if n >= 2:
			hi.append_array([ix[t], ix[t + 1], ix[t + 2]])
		else:
			bi.append_array([ix[t], ix[t + 1], ix[t + 2]])
		t += 3
	var mat := src.surface_get_material(0)
	for pair: Array in [[&"head", hi], [&"body", bi]]:
		var aa := a.duplicate()
		aa[Mesh.ARRAY_INDEX] = pair[1]
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, aa, [], {}, src.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		m.surface_set_material(0, mat)
		_meshes[pair[0]] = m
