class_name SolidView
extends RefCounted
## Draws a World's solids as plain merged meshes, one per tag colour: the test arena's look, and a debug view of any level's colliders.


static func build(w: World, parent: Node3D, colours: Dictionary = {}, default_col := Color(0.42, 0.44, 0.46)) -> void:
	var by_col: Dictionary = {}
	for s in w.solids:
		if s.kind == "mesh":
			continue
		var c: Color = colours.get(s.tag, default_col)
		if not by_col.has(c):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_smooth_group(-1)   # flat shaded
			by_col[c] = st
		_add_solid(by_col[c], s)
	for c: Color in by_col:
		var st: SurfaceTool = by_col[c]
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		mi.material_override = m
		parent.add_child(mi)


static func _add_solid(st: SurfaceTool, s: World.Solid) -> void:
	var b := Basis(Vector3.UP, s.yaw)
	var o := Vector3(s.cx, 0.0, s.cz)
	var hx := s.hx
	var hz := s.hz
	var bot := s.bottom
	if s.kind == "disc":
		_disc(st, s)
		return
	var lo := s.top_low if s.kind == "ramp" else s.top
	var hi := s.top
	var p := [
		Vector3(-hx, bot, -hz), Vector3(hx, bot, -hz), Vector3(hx, bot, hz), Vector3(-hx, bot, hz),
		Vector3(-hx, lo, -hz), Vector3(hx, lo, -hz), Vector3(hx, hi, hz), Vector3(-hx, hi, hz)]
	for i in 8:
		p[i] = o + b * p[i]
	# wound for Godot's front faces (clockwise seen from outside)
	var faces := [[4, 5, 6, 7], [3, 2, 1, 0], [0, 1, 5, 4], [2, 3, 7, 6], [1, 2, 6, 5], [3, 0, 4, 7]]
	for f: Array in faces:
		st.add_vertex(p[f[0]])
		st.add_vertex(p[f[1]])
		st.add_vertex(p[f[2]])
		st.add_vertex(p[f[0]])
		st.add_vertex(p[f[2]])
		st.add_vertex(p[f[3]])


static func _disc(st: SurfaceTool, s: World.Solid) -> void:
	var n := 32
	var o := Vector3(s.cx, 0.0, s.cz)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := o + Vector3(cos(a0) * s.r, 0.0, sin(a0) * s.r)
		var p1 := o + Vector3(cos(a1) * s.r, 0.0, sin(a1) * s.r)
		var t0 := p0 + Vector3.UP * s.top
		var t1 := p1 + Vector3.UP * s.top
		var b0 := p0 + Vector3.UP * s.bottom
		var b1 := p1 + Vector3.UP * s.bottom
		var c := o + Vector3.UP * s.top
		st.add_vertex(c)
		st.add_vertex(t1)
		st.add_vertex(t0)
		st.add_vertex(t0)
		st.add_vertex(t1)
		st.add_vertex(b1)
		st.add_vertex(t0)
		st.add_vertex(b1)
		st.add_vertex(b0)
