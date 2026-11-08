class_name HairSpring
extends RefCounted
## Spring-bone hair (JS hair-spring.js): world-space points on the tips of a character's hair bones, so anything that moves the head (running, turning, flips, cutscenes) swings them.

const CHAINS: Array = [[&"hair_back_01", &"hair_back_02"], [&"hair_side_01L", &"hair_side_02L"], [&"hair_side_01R", &"hair_side_02R"]]
const STEP := 1.0 / 120.0      # longest substep: the hair behaves about the same at any frame rate
const MAX_STEPS := 8
# stiff: pull back to the rest shape (1/s^2); damp: settling against the head's own motion (1/s); cone: furthest from the rest direction (radians)
const JOINT_STIFF: Array[float] = [240.0, 180.0]
const JOINT_DAMP: Array[float] = [13.0, 11.0]
const JOINT_CONE: Array[float] = [0.45, 0.38]
const GRAVITY := 3.0
const AIR := 0.6               # air: push per m/s of head speed, capped so a car or a jet does not plaster it flat
const AIR_TOP_SPEED := 5.0
const SLIP_LIMIT := 3.5        # slip: fastest a tip moves relative to the head (m/s)
const TELEPORT := 4.0          # the head moved this far in one frame: start the hair over instead of whipping it across the map
const UP := Vector3(0.0, 1.0, 0.0)

class Joint:
	var bone := -1
	var rest := Quaternion.IDENTITY
	var len := 0.0
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var stiff := 0.0
	var damp := 0.0
	var cone := 0.0

class Chain:
	var anchor := Vector3.ZERO
	var last_root := Vector3.ZERO
	var joints: Array[Joint] = []

class Collider:
	var bone := -1
	var at := Vector3.ZERO      # bone-local, sized on Prog's two models; the hair only ever swings outside them
	var r := 0.0
	var c := Vector3.ZERO

var _skel: Skeleton3D
var _head := -1
var _chains: Array[Chain] = []
var _colliders: Array[Collider] = []
var _last_p := Vector3.ZERO
var _last_q := Quaternion.IDENTITY
var _back := Vector3(0.0, 0.0, -1.0)
var _live := false
var _scale := 1.0
var _head_p := Vector3.ZERO
var _head_q := Quaternion.IDENTITY
var _step_p := Vector3.ZERO
var _step_q := Quaternion.IDENTITY
# (JS module-level scratch: aim() hands these back)
var _world_q := Quaternion.IDENTITY
var _rest_dir := Vector3.UP
var _target := Vector3.ZERO


## The character's hair sim, or null when its skeleton has no hair bones. by_key: bone key -> Animator.BoneRec.
static func create(skel: Skeleton3D, by_key: Dictionary) -> HairSpring:
	if not by_key.has(&"head"):
		return null
	var h := HairSpring.new()
	h._skel = skel
	h._head = by_key[&"head"].bone
	for keys: Array in CHAINS:
		if not by_key.has(keys[0]) or not by_key.has(keys[1]):
			continue
		var ch := Chain.new()
		var len_m: float = by_key[keys[1]].rest_pos.length()      # the last bone has no child to measure: both are about the same length
		ch.anchor = by_key[keys[0]].rest_pos
		for i in 2:
			var j := Joint.new()
			j.bone = by_key[keys[i]].bone
			j.rest = by_key[keys[i]].rest
			j.len = len_m
			j.stiff = JOINT_STIFF[i]
			j.damp = JOINT_DAMP[i]
			j.cone = JOINT_CONE[i]
			ch.joints.append(j)
		h._chains.append(ch)
	if h._chains.is_empty():
		return null
	var c0 := Collider.new()
	c0.bone = by_key[&"head"].bone
	c0.at = Vector3(0.0, 0.13, 0.03)
	c0.r = 0.17
	h._colliders.append(c0)
	if by_key.has(&"chest"):
		var c1 := Collider.new()
		c1.bone = by_key[&"chest"].bone
		c1.at = Vector3(0.0, -0.07, 0.0)
		c1.r = 0.27
		h._colliders.append(c1)
	return h


## three.js Quaternion.setFromUnitVectors
static func _arc(f: Vector3, t: Vector3) -> Quaternion:
	var r := f.dot(t) + 1.0
	if r < 2.220446049250313e-16:
		if absf(f.x) > absf(f.z):
			return Quaternion(-f.y, f.x, 0.0, 0.0).normalized()
		return Quaternion(0.0, -f.z, f.y, 0.0).normalized()
	return Quaternion(f.y * t.z - f.z * t.y, f.z * t.x - f.x * t.z, f.x * t.y - f.y * t.x, r).normalized()


## the bone's rest direction and tip for this parent pose (the rest shape follows the parent bone, so a bent lock keeps its curve)
func _aim(j: Joint, from: Vector3, q: Quaternion) -> void:
	_world_q = (q * j.rest).normalized()
	_rest_dir = _world_q * UP
	_target = from + _rest_dir * (j.len * _scale)


func _restart() -> void:
	for ch in _chains:
		var root := _head_q * (ch.anchor * _scale) + _head_p
		ch.last_root = root
		var parent_q := _head_q
		for j in ch.joints:
			_aim(j, root, parent_q)
			j.p = _target
			j.v = Vector3.ZERO
			parent_q = _world_q
			root = _target
	_last_p = _head_p
	_last_q = _head_q
	_live = true


func _solve(h: float, ch: Chain, wind_k: float, grav_k: float) -> void:
	var root := _step_q * (ch.anchor * _scale) + _step_p
	var root_v := (root - ch.last_root) / h
	ch.last_root = root
	var sp := root_v.length()
	var wind := root_v * (-AIR * wind_k * AIR_TOP_SPEED / sp if sp > AIR_TOP_SPEED else -AIR * wind_k)
	var parent_q := _step_q
	for j in ch.joints:
		_aim(j, root, parent_q)
		var nxt := j.p + root_v * h                  # (the root has already moved this step: compare like with like, or the pull cancels the air)
		var force := (_target - nxt) * j.stiff + (j.v - root_v) * (-j.damp) + wind
		force.y -= GRAVITY * grav_k
		j.v += force * h
		nxt = j.p + j.v * h
		var len_s := j.len * _scale
		var dir := (nxt - root).normalized()
		var cs := dir.dot(_rest_dir)
		if cs < cos(j.cone):                         # held to its cone: the skinned lock tears past this
			var perp := dir - _rest_dir * cs
			if perp.length_squared() > 1e-8:
				dir = _rest_dir * cos(j.cone) + perp.normalized() * sin(j.cone)
			else:
				dir = _rest_dir
		nxt = root + dir * len_s
		for c in _colliders:
			var r := c.r * _scale
			var push := nxt - c.c
			var d := push.length()
			if d < r and d > 1e-6:
				nxt += push * ((r - d) / d)
				dir = (nxt - root).normalized()
				nxt = root + dir * len_s
		j.v = (nxt - j.p) / h
		var slip := j.v - root_v
		var s := slip.length()
		if s > SLIP_LIMIT:
			j.v = root_v + slip * (SLIP_LIMIT / s)
		j.p = nxt
		parent_q = (_arc(_rest_dir, dir) * _world_q).normalized()
		root = nxt


## points the bones at the simulated tips, from the head's pose this frame
func _pose() -> void:
	for ch in _chains:
		var root := _head_q * (ch.anchor * _scale) + _head_p
		var parent_q := _head_q
		for j in ch.joints:
			_aim(j, root, parent_q)
			var dir := (j.p - root).normalized()
			_world_q = (_arc(_rest_dir, dir) * _world_q).normalized()
			_skel.set_bone_pose_rotation(j.bone, Quaternion(-parent_q.x, -parent_q.y, -parent_q.z, parent_q.w) * _world_q)
			parent_q = _world_q
			root += dir * (j.len * _scale)


## Run after the body's final pose and placement. wind_k: 0 inside a car; grav_k: 0 under water
func update(dt: float, wind_k: float = 1.0, grav_k: float = 1.0) -> void:
	var sk_xf := _skel.global_transform
	var hx := sk_xf * _skel.get_bone_global_pose(_head)
	_head_p = hx.origin
	_head_q = hx.basis.get_rotation_quaternion()
	_scale = hx.basis.get_scale().x
	if not _live or _head_p.distance_to(_last_p) > TELEPORT:
		_restart()
	if dt > 0.0:
		var n := mini(MAX_STEPS, ceili(dt / STEP - 1e-6))     # whole frames: the head's motion and the tips' are then measured over the same time
		var h := dt / n
		for c in _colliders:
			c.c = sk_xf * _skel.get_bone_global_pose(c.bone) * c.at
		for i in range(1, n + 1):
			var u := float(i) / n
			_step_p = _last_p.lerp(_head_p, u)
			_step_q = _last_q.slerp(_head_q, u).normalized()
			for ch in _chains:
				_solve(h, ch, wind_k, grav_k)
		_last_p = _head_p
		_last_q = _head_q
		_back = _head_q * Vector3(0.0, 0.0, -1.0)
	_pose()


## a shove toward the back of the head (m/s), for a hit or a heavy swing
func kick(v: float) -> void:
	for ch in _chains:
		for j in ch.joints:
			j.v += _back * v
