class_name OmPuffs
extends RefCounted
## OMNISPHERE: a pool of soft world-space puffs (JS skyfoes.js createPuffs). One MultiMesh and no per-frame loop: each emit writes birth time, velocity, drag, size and colour into its instance, and the vertex shader flies it from there. emit(x, y, z, o) with o = {vx, vy, vz, size, grow, life, col (hex), alpha, drag, fade}

var mm := MultiMesh.new()
var node: MultiMeshInstance3D
var mat: ShaderMaterial
var next := 0
var max_n := 700
var now := 0.0
var birth_end := PackedFloat32Array()


func _init(parent: Node3D, p_max: int = 700, additive: bool = false) -> void:
	max_n = p_max
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = MsKit.quad()
	mm.instance_count = max_n
	mm.visible_instance_count = max_n
	birth_end.resize(max_n)
	mat = ShaderMaterial.new()
	mat.shader = load("res://levels/omnisphere/om_puff_add.gdshader" if additive else "res://levels/omnisphere/om_puff.gdshader")
	mat.set_shader_parameter(&"now", 0.0)
	mat.render_priority = 6 if additive else 5      # JS pts.renderOrder: over the sky's haze. (Without it the pool, whose node sits at the world origin, sorts as far away, and the haze paints over the whole explosion.)
	node = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	parent.add_child(node)
	clear()


func emit(x: float, y: float, z: float, o: Dictionary = {}) -> void:
	var i := next
	var n := 0
	while birth_end[i] > now and n < max_n:      # the oldest free slot; a full pool overwrites
		i = (i + 1) % max_n
		n += 1
	next = (i + 1) % max_n
	var life: float = o.get("life", 1.0)
	birth_end[i] = now + life
	var v := Vector3(o.get("vx", 0.0), o.get("vy", 0.0), o.get("vz", 0.0))
	var c: Color = MsKit.lin(o.get("col", 0xffffff))
	c.a = o.get("alpha", .6)
	# the transform's columns carry: x velocity, y (drag, fade, 0), origin the birth point
	mm.set_instance_transform(i, Transform3D(Basis(v, Vector3(float(o.get("drag", 1.2)), float(o.get("fade", .2)), 0.0), Vector3.ZERO), Vector3(x, y, z)))
	mm.set_instance_color(i, c)
	mm.set_instance_custom_data(i, Color(float(o.get("size", 1.0)), float(o.get("grow", 1.0)), life, now))


func update(dt: float) -> void:
	now += dt
	mat.set_shader_parameter(&"now", now)


func clear() -> void:
	for i in max_n:
		birth_end[i] = 0.0
		mm.set_instance_custom_data(i, Color(0.0, 0.0, 1.0, -100.0))
