class_name MsKit
extends RefCounted
## THE MOTHERSHIP's small toolbox: the primitives and materials its rebuilt pieces (beams, hatches, the light show, the Godmother's FX) are made of, with three.js's sizes and colours.

const SHADER := preload("res://levels/mothership/ms_glow.gdshader")
const P_TINT := &"tint"
const P_OP := &"opacity"
const P_SCROLL := &"scroll"
static var _glow: Dictionary = {}
static var _q: QuadMesh = null


static func lin(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff).srgb_to_linear()


static func srgb(hex: int) -> Color:
	return Color.hex((hex << 8) | 0xff)


static func glow_mat(mode: int) -> ShaderMaterial:
	if not _glow.has(mode):
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter(&"mode", mode)
		_glow[mode] = m
	return _glow[mode]


## An unlit additive piece.
static func glow(parent: Node, mesh: Mesh, mode: int, hex: int, opacity: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = glow_mat(mode)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	tint(mi, lin(hex), opacity)
	return mi


static func tint(mi: GeometryInstance3D, c: Color, opacity: float = -1.0) -> void:
	mi.set_instance_shader_parameter(P_TINT, Vector4(c.r, c.g, c.b, 1.0))
	if opacity >= 0.0:
		mi.set_instance_shader_parameter(P_OP, opacity)


static func opa(mi: GeometryInstance3D, opacity: float) -> void:
	mi.set_instance_shader_parameter(P_OP, opacity)


static func scroll(mi: GeometryInstance3D, v: float) -> void:
	mi.set_instance_shader_parameter(P_SCROLL, v)


static func quad() -> QuadMesh:
	if _q == null:
		_q = QuadMesh.new()
	return _q


## A camera-facing glow (JS a Sprite with the soft round map).
## OMNISPHERE's sprites: the same glow dot with its own falloff (textures.js glowTexture)
static func sprite8(parent: Node, hex: int, opacity: float, size: float) -> MeshInstance3D:
	var mi := glow(parent, quad(), 8, hex, opacity)
	mi.scale = Vector3.ONE * size
	mi.extra_cull_margin = 4.0
	return mi


static func sprite(parent: Node, hex: int, opacity: float, size: float) -> MeshInstance3D:
	var mi := glow(parent, quad(), 4, hex, opacity)
	mi.scale = Vector3.ONE * size
	mi.extra_cull_margin = 4.0
	return mi


static func std(hex: int, rough: float, metal: float = 0.0, dbl: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = srgb(hex)
	m.roughness = rough
	m.metallic = metal
	if dbl:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## JS MeshBasicMaterial, opaque.
static func flat(hex: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = srgb(hex)
	return m


static func part(parent: Node, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl(rt: float, rb: float, h: float, seg: int = 16, open: bool = false) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	m.cap_top = not open
	m.cap_bottom = not open
	return m


## three.js TorusGeometry turned flat (rotateX 90): a hoop round the Y axis.
static func torus(radius: float, tube_r: float, seg: int = 32, sides: int = 6) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = radius - tube_r
	m.outer_radius = radius + tube_r
	m.rings = seg
	m.ring_segments = sides
	return m


static func sphere(r: float, seg: int = 16, rings: int = 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return m


static func box(w: float, h: float, d: float) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3(w, h, d)
	return m


static func _arr(v: PackedVector3Array, uv: PackedVector2Array) -> ArrayMesh:
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_TEX_UV] = uv
	var nn := PackedVector3Array()
	nn.resize(v.size())
	nn.fill(Vector3.UP)
	a[Mesh.ARRAY_NORMAL] = nn
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	return m


## A flat disc in the XZ plane (JS CircleGeometry rotated flat), uv 0..1 across it.
static func disc(r: float, seg: int = 24) -> ArrayMesh:
	return ring(0.0, r, seg)


## A flat ring in the XZ plane (JS RingGeometry rotated flat); uv across the whole disc.
static func ring(r0: float, r1: float, seg: int = 32) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in seg:
		var a0 := float(i) / seg * TAU
		var a1 := float(i + 1) / seg * TAU
		var s0 := Vector3(sin(a0), 0.0, cos(a0))
		var s1 := Vector3(sin(a1), 0.0, cos(a1))
		for p: Vector3 in [s0 * r0, s0 * r1, s1 * r1, s0 * r0, s1 * r1, s1 * r0]:
			v.append(p)
			uv.append(Vector2(p.x, p.z) / (2.0 * r1) + Vector2(0.5, 0.5))
	return _arr(v, uv)


## An open cone from the origin along +Z (JS CylinderGeometry translated and rotated): radius r0 at the origin, r1 at len; v runs 0..1 along it.
static func cone_z(r0: float, r1: float, len_: float, seg: int = 16) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	for i in seg:
		var a0 := float(i) / seg * TAU
		var a1 := float(i + 1) / seg * TAU
		var p := [Vector3(sin(a0) * r0, cos(a0) * r0, 0.0), Vector3(sin(a0) * r1, cos(a0) * r1, len_), Vector3(sin(a1) * r1, cos(a1) * r1, len_), Vector3(sin(a1) * r0, cos(a1) * r0, 0.0)]
		var q := [Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			v.append(p[k])
			uv.append(q[k])
	return _arr(v, uv)


## A tube along a list of points (the spiral in her eyes).
static func tube(pts: PackedVector3Array, r: float, sides: int = 5) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := pts.size()
	for i in n - 1:
		var d := (pts[i + 1] - pts[i]).normalized()
		var s := d.cross(Vector3.BACK)
		if s.length_squared() < 1e-6:
			s = Vector3.RIGHT
		s = s.normalized()
		var u := s.cross(d)
		for k in sides:
			var a0 := float(k) / sides * TAU
			var a1 := float(k + 1) / sides * TAU
			var o0 := (s * cos(a0) + u * sin(a0)) * r
			var o1 := (s * cos(a1) + u * sin(a1)) * r
			for p: Vector3 in [pts[i] + o0, pts[i + 1] + o0, pts[i + 1] + o1, pts[i] + o0, pts[i + 1] + o1, pts[i] + o1]:
				st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## A five-pointed star extruded (JS ExtrudeGeometry, centred).
static func star(r0: float, r1: float, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector2] = []
	for i in 10:
		var a := float(i) / 10.0 * TAU + PI / 2.0
		var r := r0 if i % 2 else r1
		pts.append(Vector2(cos(a), sin(a)) * r)
	var h := depth * 0.5
	for i in 10:
		var a := pts[i]
		var b := pts[(i + 1) % 10]
		for p: Vector3 in [Vector3(0, 0, h), Vector3(b.x, b.y, h), Vector3(a.x, a.y, h), Vector3(0, 0, -h), Vector3(a.x, a.y, -h), Vector3(b.x, b.y, -h),
				Vector3(a.x, a.y, h), Vector3(b.x, b.y, -h), Vector3(a.x, a.y, -h), Vector3(a.x, a.y, h), Vector3(b.x, b.y, h), Vector3(b.x, b.y, -h)]:
			st.add_vertex(p)
	st.generate_normals()
	return st.commit()


## JS new T.PointLight(color, i, d, 2).
static func light(parent: Node, hex: int, i: float, dist: float, pos: Vector3 = Vector3.ZERO) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = srgb(hex)
	l.light_energy = i / PI
	l.omni_range = dist
	l.omni_attenuation = 2.0
	l.position = pos
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 50.0
	l.distance_fade_length = 20.0
	parent.add_child(l)
	return l
