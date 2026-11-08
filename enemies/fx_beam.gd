class_name FxBeam
extends RefCounted
## The world-space extras of the gray family's views (JS `deco`): a thin additive tube (laser sights, a Consigliere's tethers), a glow dot, a shield bubble. Nodes under the current level, so they go with it. Shared materials, colour per instance.

const SHADER := preload("res://enemies/fx_beam.gdshader")
static var _tube_mesh: ArrayMesh = null
static var _dot_mesh: QuadMesh = null
static var _ball_mesh: SphereMesh = null
static var _mat_tube: ShaderMaterial = null
static var _mat_dot: ShaderMaterial = null
static var _mat_ball: ShaderMaterial = null
static var _mat_crack: ShaderMaterial = null
static var _crack_mesh: PlaneMesh = null
static var _mat_ring: ShaderMaterial = null
static var _mat_cloud: ShaderMaterial = null
static var _cloud_mesh: ArrayMesh = null


static func _shared() -> void:
	if _mat_tube != null:
		return
	_mat_tube = ShaderMaterial.new()
	_mat_tube.shader = SHADER
	_mat_tube.set_shader_parameter(&"mode", 0)
	_mat_dot = ShaderMaterial.new()
	_mat_dot.shader = SHADER
	_mat_dot.set_shader_parameter(&"mode", 1)
	_mat_ball = ShaderMaterial.new()
	_mat_ball.shader = SHADER
	_mat_ball.set_shader_parameter(&"mode", 0)
	var soup := MeshBuild.Soup.new()
	var c := MeshBuild.cylinder(1.0, 1.0, 1.0, 6)
	c.rotate_x(PI / 2.0)
	c.translate(0.0, 0.0, 0.5)        # from the origin along +Z, length 1
	soup.add(c, 0, 0, Color.WHITE, false)
	_tube_mesh = soup.commit()
	_dot_mesh = QuadMesh.new()
	_ball_mesh = SphereMesh.new()
	_ball_mesh.radius = 1.0
	_ball_mesh.height = 2.0
	_ball_mesh.radial_segments = 16
	_ball_mesh.rings = 10


static func _node(mesh: Mesh, mat: ShaderMaterial, nm: String, hex: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	mi.visible = false
	var col := RigidBatch.lin(hex)
	mi.set_instance_shader_parameter(&"tint", Vector4(col.r, col.g, col.b, 1.0))
	Game.level.add_child(mi)
	return mi


## JS crackPool: a flat additive decal of fissures, opacity set by the caller.
static func crack() -> MeshInstance3D:
	_shared()
	if _mat_crack == null:
		_mat_crack = ShaderMaterial.new()
		_mat_crack.shader = SHADER
		_mat_crack.set_shader_parameter(&"mode", 2)
		_crack_mesh = PlaneMesh.new()
		_crack_mesh.size = Vector2.ONE
	return _node(_crack_mesh, _mat_crack, "FxCrack", 0xff6a20)


## JS the crawler's landing ring: a flat ring on the floor (0.75 .. 1 of its size).
static func ring(hex: int) -> MeshInstance3D:
	_shared()
	if _mat_ring == null:
		_mat_ring = ShaderMaterial.new()
		_mat_ring.shader = SHADER
		_mat_ring.set_shader_parameter(&"mode", 3)
		if _crack_mesh == null:
			_crack_mesh = PlaneMesh.new()
			_crack_mesh.size = Vector2.ONE
	return _node(_crack_mesh, _mat_ring, "FxRing", hex)


## A bloat's spore cloud: nine soft balls in one mesh, always the same shape (the JS rolls them per bloat).
static func cloud(hex: int) -> MeshInstance3D:
	_shared()
	if _cloud_mesh == null:
		var r := RandomNumberGenerator.new()
		r.seed = 7
		var soup := MeshBuild.Soup.new()
		for _i in 9:
			var g := MeshBuild.sphere(1.0 + r.randf() * 0.8, 18, 12)
			g.translate((r.randf() - 0.5) * 2.4, (r.randf() - 0.5) * 1.6, (r.randf() - 0.5) * 2.4)
			soup.add(g, 0, 0, Color.WHITE, false)
		_cloud_mesh = soup.commit()
		_mat_cloud = ShaderMaterial.new()
		_mat_cloud.shader = load("res://enemies/fx_cloud.gdshader")
	return _node(_cloud_mesh, _mat_cloud, "FxCloud", hex)


## JS blood / ichor puddle: a flat blended disc.
static var _mat_puddle: ShaderMaterial = null
static func puddle(hex: int) -> MeshInstance3D:
	_shared()
	if _mat_puddle == null:
		_mat_puddle = ShaderMaterial.new()
		_mat_puddle.shader = load("res://enemies/fx_cloud.gdshader")
		_mat_puddle.set_shader_parameter(&"disc", true)
		if _crack_mesh == null:
			_crack_mesh = PlaneMesh.new()
			_crack_mesh.size = Vector2.ONE
	return _node(_crack_mesh, _mat_puddle, "FxPuddle", hex)


## A flat rectangle on the floor (mode 4).
static var _mat_streak: ShaderMaterial = null
static var _streak_mesh: PlaneMesh = null
static func streak(hex: int) -> MeshInstance3D:
	_shared()
	if _mat_streak == null:
		_mat_streak = ShaderMaterial.new()
		_mat_streak.shader = SHADER
		_mat_streak.set_shader_parameter(&"mode", 4)
		_streak_mesh = PlaneMesh.new()
		_streak_mesh.size = Vector2.ONE
	return _node(_streak_mesh, _mat_streak, "FxStreak", hex)


static func tube(hex: int) -> MeshInstance3D:
	_shared()
	return _node(_tube_mesh, _mat_tube, "FxTube", hex)


static func dot(hex: int) -> MeshInstance3D:
	_shared()
	return _node(_dot_mesh, _mat_dot, "FxDot", hex)


static func ball(hex: int) -> MeshInstance3D:
	_shared()
	return _node(_ball_mesh, _mat_ball, "FxBall", hex)


## from a to b, `w` thick.
static func place_tube(mi: MeshInstance3D, a: Vector3, b: Vector3, w: float, opacity: float) -> void:
	var d := b - a
	var L := d.length()
	if L < 1e-4:
		mi.visible = false
		return
	var f := d / L
	var up := Vector3.UP if absf(f.y) < 0.99 else Vector3.RIGHT
	var x := up.cross(f).normalized()
	var y := f.cross(x)
	mi.global_transform = Transform3D(Basis(x * w, y * w, f * L), a)
	mi.set_instance_shader_parameter(&"opacity", opacity)
	mi.visible = true


## a camera-facing glow of this world size
static func place_dot(mi: MeshInstance3D, at: Vector3, size: float, opacity: float) -> void:
	mi.global_position = at
	mi.scale = Vector3(size, size, size)
	mi.set_instance_shader_parameter(&"opacity", opacity)
	mi.visible = true


## a round bubble
static func place_ball(mi: MeshInstance3D, at: Vector3, r: float, opacity: float) -> void:
	mi.global_position = at
	mi.scale = Vector3(r, r, r)
	mi.set_instance_shader_parameter(&"opacity", opacity)
	mi.visible = true


## a flat ring on the floor, this radius
static func place_ring(mi: MeshInstance3D, at: Vector3, r: float, opacity: float) -> void:
	mi.global_position = at
	mi.scale = Vector3(r * 2.0, 1.0, r * 2.0)
	mi.set_instance_shader_parameter(&"opacity", opacity)
	mi.visible = true


static func place_cloud(mi: MeshInstance3D, at: Vector3, s: float, opacity: float) -> void:
	mi.global_position = at
	mi.scale = Vector3(s, s, s)
	mi.set_instance_shader_parameter(&"opacity", opacity)
	mi.visible = true


static func place_puddle(mi: MeshInstance3D, at: Vector3, r: float, opacity: float) -> void:
	mi.global_position = at
	mi.scale = Vector3(r * 2.0, 1.0, r * 2.0)
	mi.set_instance_shader_parameter(&"opacity", opacity)
	mi.visible = true


## a flat rectangle on the floor: length along the yaw (JS the Warden's roll streak)
static func place_streak(mi: MeshInstance3D, at: Vector3, w: float, ln: float, yaw: float, opacity: float) -> void:
	mi.global_transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(w, 1.0, ln)), at)
	mi.set_instance_shader_parameter(&"opacity", opacity)
	mi.visible = true


## JS crackPool: a small pool of glowing floor cracks for heavy impacts: place() reuses the oldest, update() fades them.
class Cracks:
	var nodes: Array[MeshInstance3D] = []
	var t: Array[float] = []
	var s: Array[float] = []
	var next := 0
	var life := 4.5

	func _init(n: int, p_life: float) -> void:
		life = p_life
		for _i in n:
			nodes.append(FxBeam.crack())
			t.append(1e9)
			s.append(1.0)

	func place(x: float, y: float, z: float, size: float) -> void:
		var i := next
		next = (next + 1) % nodes.size()
		t[i] = 0.0
		s[i] = size
		nodes[i].global_position = Vector3(x, y + 0.04, z)
		nodes[i].rotation.y = randf() * 6.283
		nodes[i].visible = true

	func update(dt: float) -> void:
		for i in nodes.size():
			var c := nodes[i]
			if not c.visible:
				continue
			t[i] += dt
			var u := t[i] / life
			if u >= 1.0:
				c.visible = false
				continue
			c.set_instance_shader_parameter(&"opacity", pow(1.0 - u, 1.5) * 0.9)
			var k := s[i] * (0.6 + 0.4 * minf(1.0, t[i] / 0.12))
			c.scale = Vector3(k, k, k)

	func free_all() -> void:
		for c: MeshInstance3D in nodes:
			if is_instance_valid(c):
				c.queue_free()
