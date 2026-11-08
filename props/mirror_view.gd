class_name MirrorView
extends Node
## A real mirror (three.js Reflector, JS levels/apartment/props.js and levels/dev/level.js): a second camera mirrored in the glass's plane draws the world into a small viewport, the glass shows it by screen position. ENGINE DIFFERENCES: no oblique near plane, so the mirrored camera's near plane sits at the glass (a wall mirror has nothing behind it to clip); only drawn while the player is near (distance `range_m`), which three.js does by frustum culling.

var glass: MeshInstance3D
var range_m := 12.0
var _vp: SubViewport
var _cam: Camera3D
var _mat: ShaderMaterial


## glass: a plane facing its local +Z. tint: the Reflector's colour.
static func attach(p_glass: MeshInstance3D, tint: int, res: float = 0.45, p_range: float = 12.0) -> MirrorView:
	var o := MirrorView.new()
	o.glass = p_glass
	o.range_m = p_range
	o._vp = SubViewport.new()
	o._vp.world_3d = p_glass.get_viewport().world_3d if p_glass.get_viewport().world_3d != null else p_glass.get_world_3d()
	o._vp.own_world_3d = false
	o._vp.audio_listener_enable_3d = false
	o._vp.gui_disable_input = true
	o._vp.msaa_3d = Viewport.MSAA_2X
	o._vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	o._vp.set_meta(&"res", res)
	o.add_child(o._vp)
	o._cam = Camera3D.new()
	o._cam.current = true
	o._vp.add_child(o._cam)
	o._mat = ShaderMaterial.new()
	o._mat.shader = load("res://props/mirror.gdshader")
	o._mat.set_shader_parameter(&"mirror_tex", o._vp.get_texture())
	var c := Color.hex((tint << 8) | 0xff).srgb_to_linear()
	o._mat.set_shader_parameter(&"tint", Vector3(c.r, c.g, c.b))
	p_glass.material_override = o._mat
	p_glass.add_child(o)
	return o


## ENGINE DIFFERENCE: the Reflector bends its camera's near plane onto the glass (an oblique projection), which Camera3D cannot do. Here the mirrored camera looks square out of the glass through a frustum fitted to it, with its near plane on the glass: the same picture, and the wall behind the mirror is cut off exactly.
func _process(_dt: float) -> void:
	var main := Game.camera
	if main == null or not is_instance_valid(glass):
		return
	var g := glass.global_transform
	var gx := g.basis.x.normalized()
	var gy := g.basis.y.normalized()
	var n := g.basis.z.normalized()
	var pc := main.global_position
	var d := (pc - g.origin).dot(n)
	var want := glass.is_visible_in_tree() and d > 0.05 and pc.distance_to(g.origin) < range_m and not get_viewport().disable_3d
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if want else SubViewport.UPDATE_DISABLED
	if not want:
		return
	var box := glass.get_aabb().size
	var w := box.x * g.basis.x.length()
	var h := box.y * g.basis.y.length()
	var si := Vector2i(maxi(16, int(1000.0 * float(_vp.get_meta(&"res")) * w / h)), maxi(16, int(1000.0 * float(_vp.get_meta(&"res")))))      # (0.4: the JS's 384 x 400)
	if _vp.size != si:
		_vp.size = si
	_mat.set_shader_parameter(&"glass_size", Vector2(box.x, box.y))
	var rp := pc - n * (2.0 * d)
	var xf := Transform3D(Basis(-gx, gy, -n), rp)
	_cam.global_transform = xf
	var c := xf.affine_inverse() * g.origin
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.set_frustum(h, Vector2(c.x, c.y), d, main.far)
	_cam.environment = main.environment
	_cam.cull_mask = main.cull_mask
