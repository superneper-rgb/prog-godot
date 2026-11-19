class_name SamboPilot
extends Node3D
## Sambo Fenrir himself, out of the suit (user, 2026-11-19: "his little body falls out he begs for mercy while still being a condescending prick"): the little green alien who drove the suit
## (assets/folk/sambo_pilot: tools/folk/recipes/sambo_pilot.py, the suit pilot's own head on a 0.34 m body, a gold chain). His clips (idle, walk, run) play and code goes on top, as on the suit
## (npcs/sambo/sambo_body.gd): `kneel` (0..1) down on his knees, `plead` (0..1) his hands pressed together up at whoever he begs, `fit` (0..1) both fists up and shaking, `wave` (0..1) one arm
## up waving; `look_target` his head turns to; talking: he has no mouth, so his antennae flick and his head bobs on his words. The owner places him (position, rotation.y; he faces +Z).

const MODEL := "res://assets/folk/sambo_pilot/sambo_pilot.gltf"

var skel: Skeleton3D
var anim: AnimationPlayer
var B := {}
var speed := 0.0
var kneel := 0.0
var plead := 0.0
var fit := 0.0
var wave := 0.0
var talking := false
var look_on := false
var look_target := Vector3.ZERO
var _clip := ""
var _t := 0.0
var _talk_k := 0.0
var _kn := 0.0
var _pl := 0.0
var _fi := 0.0
var _wa := 0.0


func _init() -> void:
	name = "SamboPilot"
	var root: Node3D = (load(MODEL) as PackedScene).instantiate()
	add_child(root)
	skel = root.find_children("*", "Skeleton3D", true, false)[0]
	anim = root.find_children("*", "AnimationPlayer", true, false)[0]
	for i in skel.get_bone_count():
		B[skel.get_bone_name(i)] = i
	for a: StringName in anim.get_animation_list():
		anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.play(&"idle")
	_clip = "idle"
	for mi: Node in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func head_world() -> Vector3:
	return skel.global_transform * skel.get_bone_global_pose(B["head"]).origin + Vector3(0.0, 0.05, 0.0)


func update(dt: float) -> void:
	_t += dt
	var clip := "idle" if speed < 0.05 else ("walk" if speed < 0.3 else "run")
	if clip != _clip:
		anim.play(StringName(clip), 0.2)
		_clip = clip
	var rate := 1.0
	if clip == "walk":
		rate = clampf(speed / (0.11 / 1.067), 0.5, 2.0)
	elif clip == "run":
		rate = clampf(speed / (0.17 / 0.8), 0.5, 2.0)
	anim.advance(dt * rate)
	var k := 1.0 - exp(-dt * 8.0)
	_kn = lerpf(_kn, kneel, k)
	_pl = lerpf(_pl, plead, k)
	_fi = lerpf(_fi, fit, k)
	_wa = lerpf(_wa, wave, k)
	_talk_k = lerpf(_talk_k, 1.0 if talking else 0.0, 1.0 - exp(-dt * 12.0))
	_pose()


func _g(i: int) -> Transform3D:
	return skel.get_bone_global_pose(i)


func _set_basis(i: int, gb: Basis, w: float = 1.0) -> void:
	var p := skel.get_bone_parent(i)
	var pb := _g(p).basis.orthonormalized() if p >= 0 else Basis.IDENTITY
	var q := (pb.inverse() * gb.orthonormalized()).get_rotation_quaternion()
	if w < 0.999:
		q = skel.get_bone_pose_rotation(i).slerp(q, clampf(w, 0.0, 1.0))
	skel.set_bone_pose_rotation(i, q)


func _turn(i: int, axis: Vector3, a: float) -> void:
	if absf(a) > 1e-5:
		_set_basis(i, Basis(axis, a) * _g(i).basis)


func _ik(up: int, lo: int, end: int, target: Vector3, pole: Vector3, w: float) -> void:
	if w <= 0.001:
		return
	var S := _g(up).origin
	var E0 := _g(lo).origin
	var H0 := _g(end).origin
	var l1 := S.distance_to(E0)
	var l2 := E0.distance_to(H0)
	var d := target - S
	var dl := clampf(d.length(), 0.005, (l1 + l2) * 0.995)
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


func _pose() -> void:
	var X := Vector3.RIGHT
	# down on his knees: the hips lowered, the thighs forward, the shins back under him
	if _kn > 0.01:
		skel.set_bone_pose_position(B["hips"], skel.get_bone_pose_position(B["hips"]) + Vector3(0.0, -0.05 * _kn, 0.012 * _kn))
		for s: String in ["L", "R"]:
			_turn(B["thigh." + s], X, -1.35 * _kn)
			_turn(B["shin." + s], X, 1.75 * _kn)
			_turn(B["foot." + s], X, 0.5 * _kn)
		_turn(B["spine"], X, 0.15 * _kn)
	# the arms: pleading (hands pressed together up in front of his face), a fit (fists up shaking), a wave (his right arm up)
	var shake := sin(_t * 21.0) * 0.006
	var head: Vector3 = _g(B["head"]).origin
	var lt := Vector3(0.012, head.y - 0.005 + 0.004 * sin(_t * 6.0), 0.045)
	var rt := Vector3(-0.012, head.y - 0.005 + 0.004 * sin(_t * 6.0), 0.045)
	var w := _pl
	if _fi > 0.01:
		lt = lt.lerp(Vector3(0.045, head.y + 0.05 + shake, 0.02), _fi)
		rt = rt.lerp(Vector3(-0.045, head.y + 0.05 - shake, 0.02), _fi)
		w = maxf(w, _fi)
	if w > 0.01:
		_ik(B["upper_arm.L"], B["forearm.L"], B["hand.L"], lt, Vector3(1.0, -1.0, -0.3), w)
		_ik(B["upper_arm.R"], B["forearm.R"], B["hand.R"], rt, Vector3(-1.0, -1.0, -0.3), w)
	if _wa > 0.01:
		var wv := Vector3(-0.07 + 0.02 * sin(_t * 9.0), head.y + 0.07, 0.01)
		_ik(B["upper_arm.R"], B["forearm.R"], B["hand.R"], wv, Vector3(-1.0, 0.0, -0.5), _wa)
	# the head: to whoever he looks at; on his words a bob and the antennae flicking
	var hb := B["head"] as int
	if look_on:
		var lt2 := skel.global_transform.affine_inverse() * look_target
		var hp := _g(hb).origin
		var dv := lt2 - hp
		_turn(hb, Vector3.UP, clampf(atan2(dv.x, dv.z), -1.0, 1.0) * 0.8)
		_turn(hb, X, -clampf(atan2(dv.y, Vector2(dv.x, dv.z).length()), -0.6, 0.9) * 0.7)
	if _talk_k > 0.01:
		_turn(hb, X, 0.08 * sin(_t * 14.0) * _talk_k)
		for s: String in ["L", "R"]:
			_turn(B["antenna." + s], X, 0.35 * sin(_t * 17.0 + (0.0 if s == "L" else 1.3)) * _talk_k)
			_turn(B["antenna_tip." + s], X, 0.5 * sin(_t * 23.0 + (0.6 if s == "L" else 2.1)) * _talk_k)
