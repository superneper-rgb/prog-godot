class_name GlowPoints
extends RefCounted
## three.js glow points (PointsMaterial with a glowSprite map, sizeAttenuation, additive) brought back to how the JS draws them. The exporter keeps them as Godot points, which are fixed-size pixel squares;
## this swaps such a mesh for one camera-facing quad per point (levels/shaders/glow_points.gdshaderinc) with the exported colour, opacity and texture. The caller animates the returned material.

const GLOW_TEX := "res://assets/levels/_tex/4e4f50ff4feab329_128x128.webp"      # the JS glowSprite (the city's additive sprites use the same one)


## Hides `mi` and puts the quads beside it. size: the JS PointsMaterial.size (world units). (No fog: see glow_points.gdshader.)
static func replace(mi: MeshInstance3D, size: float) -> ShaderMaterial:
	var src: Array = mi.mesh.surface_get_arrays(0)
	var pts: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var n := pts.size()
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	v.resize(n * 6)
	uv.resize(n * 6)
	uv2.resize(n * 6)
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in n:
		for c in 6:
			v[i * 6 + c] = pts[i]
			uv[i * 6 + c] = corners[c]
			uv2[i * 6 + c] = Vector2(float(i), 0.0)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var old := mi.get_active_material(0) as BaseMaterial3D
	var sm := ShaderMaterial.new()
	sm.shader = load("res://levels/shaders/glow_points.gdshader")
	var tex: Texture2D = old.albedo_texture if old != null and old.albedo_texture != null else load(GLOW_TEX)
	sm.set_shader_parameter(&"map", tex)
	if old != null:
		var c := old.albedo_color
		sm.set_shader_parameter(&"color", Color(c.r, c.g, c.b))
		sm.set_shader_parameter(&"opacity", c.a)
	sm.set_shader_parameter(&"size", size)
	var q := MeshInstance3D.new()
	q.name = String(mi.name) + "_glow"
	q.mesh = m
	q.material_override = sm
	q.transform = mi.transform
	q.extra_cull_margin = size * 4.0      # (the quads grow out of the points in the shader)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.get_parent().add_child(q)
	mi.visible = false
	return sm
