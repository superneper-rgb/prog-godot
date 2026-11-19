class_name SkyGeometry
extends RefCounted
## Shared materials and batched geometry for the SkySphere's track and station.


static func metal(color: Color, roughness: float = 0.48) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.48
	material.roughness = roughness
	return material


static func light(color: Color, energy: float = 1.5) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color * energy
	return material


static func part(parent: Node3D, mesh: Mesh, material: Material, at: Transform3D = Transform3D.IDENTITY) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = material
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.transform = at
	parent.add_child(model)
	return model


static func box_at(center: Vector3, size: Vector3, axes: Basis = Basis.IDENTITY) -> Transform3D:
	return Transform3D(axes.scaled_local(size), center)


static func beam(a: Vector3, b: Vector3, width: float, depth: float) -> Transform3D:
	var forward := (b - a).normalized()
	var up := Vector3.UP if absf(forward.y) < 0.96 else Vector3.RIGHT
	var right := up.cross(forward).normalized()
	return box_at(a.lerp(b, 0.5), Vector3(width, depth, a.distance_to(b) + 0.06), Basis(right, forward.cross(right), forward))


static func boxes(parent: Node3D, material: Material, placements: Array[Transform3D]) -> MultiMeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = placements.size()
	for i in placements.size():
		batch.set_instance_transform(i, placements[i])
	var model := MultiMeshInstance3D.new()
	model.multimesh = batch
	model.material_override = material
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(model)
	return model


static func sign_text(parent: Node3D, text: String, at: Vector3, width_per_pixel: float, color: Color, font: StringName = &"orb700") -> Label3D:
	var sign := Label3D.new()
	sign.text = text
	sign.font = CrtTheme.font(font)
	sign.pixel_size = width_per_pixel
	sign.font_size = 64
	sign.outline_size = 0
	sign.modulate = color
	sign.double_sided = false
	sign.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	sign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sign.position = at
	parent.add_child(sign)
	return sign
