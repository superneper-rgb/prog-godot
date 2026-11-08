class_name OmRibbon
extends RefCounted
## OMNISPHERE lightning: jagged camera-facing strips in one additive mesh, rebuilt every few frames (JS the Mesh + Float32BufferAttribute ribbons in landmark.js, summit.js, flyoff.js). No per-frame allocation past the packed array.

var mesh := ArrayMesh.new()
var node: MeshInstance3D
var mat: StandardMaterial3D
var pts := PackedVector3Array()


func _init(root: Node3D, hex: int, a: float = 1.0) -> void:
	mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mat.albedo_color = Color(MsKit.srgb(hex), a)
	node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 16384.0
	node.visible = false
	root.add_child(node)


func set_alpha(a: float) -> void:
	mat.albedo_color.a = a


func clear() -> void:
	pts.clear()


func quad(p0: Vector3, p1: Vector3, side: Vector3) -> void:
	pts.append_array(PackedVector3Array([p0 + side, p0 - side, p1 + side, p0 - side, p1 - side, p1 + side]))


## a jagged ribbon from a to b (camera-facing strips), with branches
func ribbon(a: Vector3, c: Vector3, n: int, jag: float, w: float, branches: int = 0) -> void:
	var cam: Vector3 = Game.camera.global_position
	var d := c - a
	var L := d.length()
	var line: Array[Vector3] = [a]
	for i in range(1, n):
		var k := sin(float(i) / n * PI)
		line.append(a + d * (float(i) / n) + Vector3((randf() - .5) * jag * k, (randf() - .5) * jag * k * .6, (randf() - .5) * jag * k))
	line.append(c)
	for i in line.size() - 1:
		var m := (line[i] + line[i + 1]) * .5
		var side := (line[i + 1] - line[i]).cross(cam - m).normalized() * (w * (1.0 - float(i) / line.size() * .5))
		quad(line[i], line[i + 1], side)
	for _k in branches:
		var i := 1 + randi() % maxi(1, line.size() - 2)
		ribbon(line[i], line[i] + Vector3((randf() - .5) * L * .25, -randf() * L * .15, (randf() - .5) * L * .25), 6, jag * .5, w * .45, 0)


func flush() -> void:
	mesh.clear_surfaces()
	if pts.size() >= 3:
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pts
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
