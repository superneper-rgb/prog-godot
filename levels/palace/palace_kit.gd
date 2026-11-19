class_name PalaceKit
extends RefCounted
## The FOINT Pervert Palace site's parts kit (levels/palace): the meshes its steel, scaffold and lights are made of, the materials, and Batch, a MultiMesh per part and material, so a
## thousand beams or tubes are one draw. Everything here is made at level load (CLAUDE.md: no materials mid-play).

const PH := "res://assets/third-party/polyhaven/%s/textures/%s_%s_1k.jpg"
const FONT := "res://assets/fonts/Rajdhani-Bold.ttf"
const FONT_WIDE := "res://assets/fonts/Orbitron-Variable.ttf"


## One part, many copies: transforms collected, then one MultiMeshInstance3D
class Batch:
	var mesh: Mesh
	var mat: Material
	var xfs: Array[Transform3D] = []
	var shadows := true

	func _init(m: Mesh, mt: Material, sh: bool = true) -> void:
		mesh = m
		mat = mt
		shadows = sh

	func add(xf: Transform3D) -> void:
		xfs.append(xf)

	func commit(parent: Node3D, nm: String) -> MultiMeshInstance3D:
		if xfs.is_empty():
			return null
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = nm
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		xfs.clear()
		return mi


## A member from a to b: a unit part along its own +Y (length 1, centred) stretched between two points, its section scaled by w (local X) and d (local Z). For a member that is
## not upright, local X points up (so an I-beam's flanges are top and bottom); roll turns the section about the member.
static func span(a: Vector3, b: Vector3, w: float = 1.0, d: float = 1.0, roll: float = 0.0) -> Transform3D:
	var y := b - a
	var L := y.length()
	if L < 1e-5:
		return Transform3D(Basis().scaled(Vector3.ZERO), a)
	var yn := y / L
	var ref := Vector3.UP if absf(yn.y) < 0.95 else Vector3.FORWARD
	var z := ref.cross(yn).normalized()
	var x := yn.cross(z)
	var bs := Basis(x, yn, z)
	if roll != 0.0:
		bs = bs * Basis(Vector3.UP, roll)
	return Transform3D(bs.scaled_local(Vector3(w, L, d)), (a + b) * 0.5)


## An I-beam (wide-flange) section along +Y, length 1, centred: its depth h along local X (flanges at +-X), its width w along Z. Laid with span() its flanges are top and bottom.
static func ibeam_mesh(h: float = 0.36, w: float = 0.2, tf: float = 0.022, tw: float = 0.014) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# three boxes: the two flanges and the web (in local X = depth of the section, Z = width)
	var parts: Array[AABB] = [AABB(Vector3(-h * 0.5, -0.5, -w * 0.5), Vector3(tf, 1.0, w)), AABB(Vector3(h * 0.5 - tf, -0.5, -w * 0.5), Vector3(tf, 1.0, w)),
		AABB(Vector3(-h * 0.5 + tf, -0.5, -tw * 0.5), Vector3(h - 2.0 * tf, 1.0, tw))]
	for bx: AABB in parts:
		_box_into(st, bx)
	st.generate_tangents()
	return st.commit()


static func _box_into(st: SurfaceTool, bx: AABB) -> void:
	var p0 := bx.position
	var p1 := bx.end
	var faces := [
		[Vector3(1, 0, 0), [Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p1.x, p1.y, p1.z), Vector3(p1.x, p0.y, p1.z)]],
		[Vector3(-1, 0, 0), [Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p1.y, p1.z), Vector3(p0.x, p1.y, p0.z), Vector3(p0.x, p0.y, p0.z)]],
		[Vector3(0, 0, 1), [Vector3(p1.x, p0.y, p1.z), Vector3(p1.x, p1.y, p1.z), Vector3(p0.x, p1.y, p1.z), Vector3(p0.x, p0.y, p1.z)]],
		[Vector3(0, 0, -1), [Vector3(p0.x, p0.y, p0.z), Vector3(p0.x, p1.y, p0.z), Vector3(p1.x, p1.y, p0.z), Vector3(p1.x, p0.y, p0.z)]],
		[Vector3(0, 1, 0), [Vector3(p0.x, p1.y, p0.z), Vector3(p0.x, p1.y, p1.z), Vector3(p1.x, p1.y, p1.z), Vector3(p1.x, p1.y, p0.z)]],
		[Vector3(0, -1, 0), [Vector3(p0.x, p0.y, p1.z), Vector3(p0.x, p0.y, p0.z), Vector3(p1.x, p0.y, p0.z), Vector3(p1.x, p0.y, p1.z)]],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var q: Array = f[1]
		var uv := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uv[k])
			st.add_vertex(q[k])


static func box_mesh() -> BoxMesh:
	var m := BoxMesh.new()
	m.size = Vector3.ONE
	return m


## A tube along +Y, length 1, radius 1 (scale the section by the radius)
static func tube_mesh(sides: int = 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 1.0
	m.bottom_radius = 1.0
	m.height = 1.0
	m.radial_segments = sides
	m.rings = 1
	return m


static func ball_mesh(r: float = 1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 8
	m.rings = 4
	return m


# ---------------------------------------------------------------------------------------------- materials

## A photographed Poly Haven set on a lit material, laid in world space (no part needs UVs). o: {tile (metres), tint, rough, metal, normal}
static func ph(set_name: String, o: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var diff := PH % [set_name, set_name, "diff"]
	if ResourceLoader.exists(diff):
		m.albedo_texture = load(diff)
	m.albedo_color = o.get("tint", Color.WHITE)
	var nor := PH % [set_name, set_name, "nor_gl"]
	if ResourceLoader.exists(nor):
		m.normal_enabled = true
		m.normal_texture = load(nor)
		m.normal_scale = float(o.get("normal", 1.0))
	var arm := PH % [set_name, set_name, "arm"]
	var rough := PH % [set_name, set_name, "rough"]
	if ResourceLoader.exists(arm):
		m.roughness_texture = load(arm)
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic_texture = load(arm)
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	elif ResourceLoader.exists(rough):
		m.roughness_texture = load(rough)
	m.roughness = float(o.get("rough", 1.0))
	m.metallic = float(o.get("metal", 0.0))
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var s := 1.0 / float(o.get("tile", 2.0))
	m.uv1_scale = Vector3(s, s, s)
	m.uv1_triplanar_sharpness = 4.0
	return m


## One photographed texture (not a Poly Haven set) on a lit material, laid in world space
static func ph_single(path: String, tint: Color, tile: float, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile
	return m


static func plain(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c * 0.2
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	return m


## Red and white hazard stripes (the crane's jib tip, the hoist gate), drawn into a small texture at load
static func stripes(a: Color, b: Color, rough: float = 0.5) -> StandardMaterial3D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			img.set_pixel(x, y, a if ((x + y) / 16) % 2 == 0 else b)
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.6, 1.6, 1.6)
	return m


## A flat sign: lettering on a board, unshaded so it reads at night (lit signage), or shaded (painted on)
static func sign_text(parent: Node3D, text: String, at: Transform3D, size: int, color: Color, lit: bool, wide: bool = false, outline: Color = Color(0, 0, 0, 0)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load(FONT_WIDE if wide else FONT)
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.shaded = not lit
	l.double_sided = false
	l.no_depth_test = false
	l.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
	if outline.a > 0.0:
		l.outline_size = 8
		l.outline_modulate = outline
	else:
		l.outline_size = 0
	l.transform = at
	parent.add_child(l)
	return l
