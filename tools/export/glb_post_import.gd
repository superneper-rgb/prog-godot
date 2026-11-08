@tool
extends EditorScenePostImport
## Importer hook of every GLB tools/export/export.mjs writes: applies what glTF has no field for (the exporter puts it in extras): cast shadow, hidden nodes,
## sRGB vertex colours, blending, depth write, fog, billboards, point sprites.


func _post_import(scene: Node) -> Object:
	_node(scene)
	return scene


func _node(n: Node) -> void:
	var x: Dictionary = n.get_meta("extras", {})
	if n is Node3D and x.has("hidden"):
		(n as Node3D).visible = false
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if x.has("no_cast"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(s)
				_material(m)
				# (the glTF importer leaves this off here even for a surface with COLOR_0, and folded materials are white: their colour IS the vertex colour)
				if m is BaseMaterial3D and mi.mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR:
					(m as BaseMaterial3D).vertex_color_use_as_albedo = true
	for c in n.get_children():
		_node(c)


func _material(mat: Material) -> void:
	var m := mat as StandardMaterial3D
	if m == null:
		return
	var x: Dictionary = m.get_meta("extras", {})
	if x.has("srgb_vc"):
		m.vertex_color_is_srgb = true   # the exporter stores vertex colours sRGB encoded: Godot keeps them as RGBA8 and this game's darks need the precision
	if x.has("use_vc"):
		m.vertex_color_use_as_albedo = true
	if x.has("spec"):
		m.metallic_specular = float(x["spec"])
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and m.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if x.has("shader"):    # stand-in for a hand-ported shader: a beam or a mist that fades in its shader must not read as a solid sheet of colour
			m.albedo_color.a = minf(m.albedo_color.a, 0.2)
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS if x.has("depth_write") else BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	match String(x.get("blend", "")):
		"add":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		"sub":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_SUB
		"mul":
			m.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	# (an opaque one is a sky dome the JS draws first: in Godot no depth test would put it in the transparent pass, over everything. It sits behind the world anyway.)
	if x.has("no_depth_test") and m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.no_depth_test = true
	if x.has("no_depth_test") and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.disable_fog = true
	if x.has("no_fog"):
		m.disable_fog = true
	if x.has("no_receive"):
		m.disable_receive_shadows = true
	if x.has("priority"):
		m.render_priority = int(x["priority"])
	if x.has("billboard"):
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if x.has("point_size"):
		m.use_point_size = true
		m.point_size = maxf(1.0, float(x["point_size"]))
