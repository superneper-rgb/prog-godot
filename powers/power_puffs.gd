class_name PowerPuffs
extends RefCounted
## A ring of the implants' particles (JS powers/fireball.js, frost.js pool, emit, stepPool). ENGINE DIFFERENCE: the JS steps every particle in a script loop; here each emit writes one instance and powers/power_puffs.gdshaderinc works out the rest from the clock.

const MAXP := 1000
const FLAME := 0
const EMBER := 1
const SMOKE := 2
const MIST := 3
const FLAKE := 4

var mm: MultiMesh
var mat: ShaderMaterial
var node: MultiMeshInstance3D
var i := 0
var now := 0.0
var _rid: RID


func _init(parent: Node, additive: bool, order: int, dot_mid: float, dot_val: float) -> void:
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := QuadMesh.new()
	mm.mesh = q
	mm.instance_count = MAXP
	mm.visible_instance_count = MAXP
	_rid = mm.get_rid()
	for n in MAXP:      # (every slot starts dead: its life is 0)
		RenderingServer.multimesh_instance_set_transform(_rid, n, Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO))
	mat = ShaderMaterial.new()
	mat.shader = load("res://powers/power_puff_add.gdshader" if additive else "res://powers/power_puff_mix.gdshader")
	mat.set_shader_parameter(&"dot_mid", dot_mid)
	mat.set_shader_parameter(&"dot_val", dot_val)
	mat.render_priority = order
	node = MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	parent.add_child(node)


## damp: per second; accel: m/s^2 up
func emit(x: float, y: float, z: float, vx: float, vy: float, vz: float, life: float, s0: float, s1: float, kind: int, damp: float, accel: float) -> void:
	i = (i + 1) % MAXP
	var b := Basis(Vector3(vx, vy, vz), Vector3(now, life, s0), Vector3(s1, damp, accel))
	RenderingServer.multimesh_instance_set_transform(_rid, i, Transform3D(b, Vector3(x, y, z)))
	RenderingServer.multimesh_instance_set_color(_rid, i, Color(kind / 4.0, 0.0, 0.0, 1.0))


func step(dt: float) -> void:
	now += dt
	mat.set_shader_parameter(&"now", now)
