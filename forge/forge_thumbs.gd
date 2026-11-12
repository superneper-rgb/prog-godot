class_name ForgeThumbs
extends Node
## FORGE: small pictures of the palette's entries, rendered one at a time in an off-screen viewport (its own world and light) and kept for the session.

const SIZE := 96

static var _done := {}       # mesh key -> ImageTexture
var _queue: Array = []       # [entry, TextureRect]
var _vp: SubViewport
var _cam: Camera3D
var _mi: MeshInstance3D
var _cur: Variant = null     # [entry, key] being rendered
var _wait := 0


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.64)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.7, 0.0)
	sun.light_energy = 1.3
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_vp.add_child(_cam)
	_cam.current = true
	_mi = MeshInstance3D.new()
	_vp.add_child(_mi)
	set_process(false)


func request(e: Dictionary, target: TextureRect) -> void:
	var k := ForgeMeshes.key_for(e, "")
	if _done.has(k):
		target.texture = _done[k]
		return
	_queue.append([e, target])
	set_process(true)


func _process(_dt: float) -> void:
	if _cur != null:
		_wait -= 1
		if _wait > 0:
			return
		var tex := ImageTexture.create_from_image(_vp.get_texture().get_image())
		_done[_cur[1]] = tex
		_cur = null
		_hand_out()
	if _queue.is_empty():
		set_process(false)
		return
	var e: Dictionary = _queue[0][0]
	var k := ForgeMeshes.key_for(e, "")
	var m := ForgeMeshes.mesh_for(e, "")
	_mi.mesh = m
	var bb := m.get_aabb()
	var r := maxf(0.05, bb.size.length() * 0.5)
	var dist := r / tan(deg_to_rad(_cam.fov * 0.5)) * 1.05
	var c := bb.get_center()
	_cam.look_at_from_position(c + Vector3(0.75, 0.55, 1.0).normalized() * dist, c)
	_cam.near = maxf(0.01, dist - r * 2.0)
	_cam.far = dist + r * 2.0
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_cur = [e, k]
	_wait = 2


func _hand_out() -> void:
	for it: Array in _queue.duplicate():
		var k := ForgeMeshes.key_for(it[0], "")
		if _done.has(k):
			if is_instance_valid(it[1]):
				(it[1] as TextureRect).texture = _done[k]
			_queue.erase(it)
