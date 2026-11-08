class_name CrawlKit
extends RefCounted
## Opt-in confined traversal (JS levels/_kit/crawl.js): inside the given volume a grounded player is held in a crouch that cannot jump or aim, the camera sits just behind the hands, and the body takes a crawl pose. dispose() undoes all of it. The Player and the CameraRig each read crawl_active themselves, in place of the JS patches.

var P: Player
var lift := 0.0                # raise the crawl pose (m) where its knees would sink through a curved floor
var weight := 0.0
var phase := 0.0
var _an: Variant = null
var _prev := Callable()
var _hook := Callable()


func _init(contains: Callable, p_lift: float = 0.0) -> void:
	P = Game.player
	lift = p_lift
	P.crawl_contains = contains
	_hook = _pose


func update(dt: float) -> void:
	weight += ((1.0 if P.crawl_active else 0.0) - weight) * minf(1.0, dt * 12.0)
	phase += dt * minf(5.0, U.hyp(P.vx, P.vz) * 3.5)
	var a: Variant = Game.animator
	if a == null or a == _an:
		return
	if is_instance_valid(_an) and _an.pose_hook == _hook:      # (a character swap made a new animator)
		_an.pose_hook = _prev
	_an = a
	_prev = a.pose_hook
	a.pose_hook = _hook


func _pose(an: Variant) -> void:
	if _prev.is_valid():
		_prev.call(an)
	if weight < 0.001:
		return
	var motion := minf(1.0, U.hyp(P.vx, P.vz))
	var stride := sin(phase) * 0.23 * motion
	_put(an, &"pelvis", Vector3(1.05, 0.0, 0.0))
	_put(an, &"spine1", Vector3(0.15, 0.0, 0.0))
	_put(an, &"chest", Vector3(0.12, 0.0, 0.0))
	_put(an, &"head", Vector3(-0.85, 0.0, 0.0))
	_put(an, &"thighL", Vector3(-1.45 + stride, 0.0, 0.13))
	_put(an, &"thighR", Vector3(-1.45 - stride, 0.0, -0.13))
	_put(an, &"shinL", Vector3(1.5, 0.0, 0.0))
	_put(an, &"shinR", Vector3(1.5, 0.0, 0.0))
	_put(an, &"footL", Vector3(-0.15, 0.0, 0.0))
	_put(an, &"footR", Vector3(-0.15, 0.0, 0.0))
	_put(an, &"upper_armL", Vector3(-0.35 - stride, 0.0, -0.16))
	_put(an, &"upper_armR", Vector3(-0.35 + stride, 0.0, 0.16))
	_put(an, &"forearmL", Vector3(-0.55, 0.0, 0.0))
	_put(an, &"forearmR", Vector3(-0.55, 0.0, 0.0))
	an.py.y += (-0.47 * (an.B.hip / 0.86) + lift - an.py.y) * weight
	an.py.z += (0.08 - an.py.z) * weight


func _put(an: Variant, key: StringName, v: Vector3) -> void:
	var i: int = Animator.KEYS.find(key)
	if i < 0:
		return
	var c: Vector3 = an.pose[i]
	an.pose[i] = c + (v - c) * weight


func dispose() -> void:
	P.crawl_contains = Callable()
	P.crawl_active = false
	P.crouch_hide = false
	if is_instance_valid(_an) and _an.pose_hook == _hook:
		_an.pose_hook = _prev
	_an = null
