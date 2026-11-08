class_name CinePuffs
extends RefCounted
## A ring of cutscene particles (JS tommy-ascension.js pointPool, kamehameha.js pool). ENGINE DIFFERENCE: the JS steps every particle in a script loop; here each emit writes its spawn values and the vertex shader computes the rest (cine_puffs.gdshaderinc).

var mm: MultiMesh
var mat: ShaderMaterial
var node: MultiMeshInstance3D
var i := 0
var now := 0.0
var max_n := 0
var _rid: RID


func _init(parent: Node, additive: bool, order: int, p_max: int, style: int, dot_val: float, max_px: float) -> void:
	max_n = p_max
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = max_n
	mm.visible_instance_count = max_n
	_rid = mm.get_rid()
	for n in max_n:      # (every slot starts dead: its life is 0)
		RenderingServer.multimesh_instance_set_transform(_rid, n, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO))
	mat = ShaderMaterial.new()
	mat.shader = load("res://cutscenes/cine_puff_add.gdshader" if additive else "res://cutscenes/cine_puff_mix.gdshader")
	mat.set_shader_parameter(&"style", style)
	mat.set_shader_parameter(&"dot_val", dot_val)
	mat.set_shader_parameter(&"max_px", max_px)
	mat.render_priority = order
	node = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	parent.add_child(node)


## damp: per second; accel: m/s^2 up; c: the colour and peak alpha (style 0), or Color(kind / 4.0, ...) (style 1)
func emit(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s0: float, s1: float, damp: float, accel: float, c: Color) -> void:
	i = (i + 1) % max_n
	var b := Basis(Vector3(vx, vy, vz), Vector3(now, life, s0), Vector3(s1, damp, accel))
	RenderingServer.multimesh_instance_set_transform(_rid, i, Transform3D(b, Vector3(x, y, z)))
	RenderingServer.multimesh_instance_set_color(_rid, i, c)


func step(dt: float) -> void:
	now += dt
	mat.set_shader_parameter(&"now", now)
