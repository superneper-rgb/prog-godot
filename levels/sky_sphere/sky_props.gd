class_name SkyProps
extends Node3D
## The Overcurrent's smashable barrels and barrier blocks: stacked where a bad line goes (the open hairpins, the chicane's apexes, the
## shortcut's fork), they burst away from whatever hits them, tumble down the deck or off its edge, and cost the craft a little speed
## (and give it a little boost, FlatOut style). One MultiMesh per kind; the pieces are simulated here, not by the physics engine, so the
## takedown slow motion slows them too. Back in their stacks at every start.

const G := 24.0
const BARREL := 0
const BLOCK := 1


class Piece:
	var kind := BARREL
	var slot := 0
	var home := Transform3D.IDENTITY
	var path := SkyCourse.MAIN
	var home_i := 0
	var index := 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var basis := Basis.IDENTITY
	var spin := Vector3.ZERO
	var r := 0.5
	var loose := false
	var gone := false
	var t := 0.0


var pieces: Array[Piece] = []
var _course: SkyCourse
var _mm: Array[MultiMesh] = []
var _counts: Array[int] = [0, 0]


func build(course: SkyCourse) -> void:
	name = "SmashableStacks"
	_course = course
	for spot: SkyCourse.PropSpot in course.props:
		var p := course.paths[spot.path]
		for k in spot.count:
			var piece := Piece.new()
			piece.kind = BLOCK if k % 3 == 1 else BARREL
			piece.r = 0.62 if piece.kind == BLOCK else 0.5
			piece.path = spot.path
			piece.home_i = p.wrap(spot.i - spot.count / 2 + k)
			var fr := p.frames[piece.home_i]
			var across := spot.u - signf(spot.u) * float(k % 2) * 0.9
			var lift := 0.45 if piece.kind == BLOCK else 0.5
			piece.home = Transform3D(fr.basis.rotated(fr.basis.y, randf_range(-0.4, 0.4)), fr * Vector3(across, lift, 0.0))
			piece.slot = _counts[piece.kind]
			_counts[piece.kind] += 1
			pieces.append(piece)
	_mm.append(_batch(_barrel_mesh(), _paint(Color("ff8a1e")), _counts[BARREL]))
	_mm.append(_batch(_block_mesh(), _paint(Color("d8dde6")), _counts[BLOCK]))
	reset()


func reset() -> void:
	for piece: Piece in pieces:
		piece.loose = false
		piece.gone = false
		piece.pos = piece.home.origin
		piece.basis = piece.home.basis
		piece.index = piece.home_i
		piece.vel = Vector3.ZERO
		piece.spin = Vector3.ZERO
		piece.t = 0.0
		_mm[piece.kind].set_instance_transform(piece.slot, piece.home)


## Knock pieces away from a craft's body. Returns how many it hit this call.
func hit_by(car: RaceCar) -> int:
	var hits := 0
	var reach := car.half.z + 1.0
	for piece: Piece in pieces:
		if piece.gone:
			continue
		var rel := piece.pos - car.pos
		if rel.length_squared() > reach * reach:
			continue
		var along := clampf(rel.dot(car.basis.z), -car.half.z + car.half.x, car.half.z - car.half.x)
		var nearest := car.pos + car.basis.z * along
		var off := piece.pos - nearest
		var d := off.length()
		if d > car.half.x + piece.r:
			continue
		var n := off / maxf(d, 0.01)
		var up := car.road.basis.y
		var closing := (car.vel - piece.vel).dot(n)
		if closing < 2.0 and piece.loose:
			continue
		piece.loose = true
		piece.vel = car.vel * randf_range(0.9, 1.25) + n * randf_range(4.0, 9.0) + up * randf_range(4.0, 10.0)
		piece.spin = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(6.0, 15.0)
		piece.t = 0.0
		car.vel *= 0.985
		hits += 1
	return hits


func tick(dt: float) -> void:
	for piece: Piece in pieces:
		if not piece.loose or piece.gone:
			continue
		piece.t += dt
		piece.vel += Vector3.DOWN * (G * dt)
		piece.pos += piece.vel * dt
		var w := piece.spin.length()
		if w > 0.001:
			piece.basis = Basis(piece.spin / w, w * dt) * piece.basis
		piece.basis = piece.basis.orthonormalized()
		piece.index = _course.locate(piece.path, piece.index, piece.pos, 4, 6)
		var local := _course.q_local
		if _course.on_deck(piece.path, piece.index, local) and local.y < piece.r and local.y > -1.0:
			var n: Vector3 = _course.frame(piece.path, piece.index).basis.y
			piece.pos += n * (piece.r - local.y)
			var vn := piece.vel.dot(n)
			if vn < 0.0:
				piece.vel -= n * (vn * 1.38)
				piece.vel = piece.vel.lerp(n * piece.vel.dot(n), 0.12)
				piece.spin *= 0.8
		if piece.t > 9.0 or local.y < -60.0:
			piece.gone = true
			_mm[piece.kind].set_instance_transform(piece.slot, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), piece.home.origin))
			continue
		_mm[piece.kind].set_instance_transform(piece.slot, Transform3D(piece.basis, piece.pos))


func _batch(mesh: Mesh, material: Material, count: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 40.0
	add_child(node)
	return mm


func _paint(colour: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://levels/sky_sphere/sky_prop.gdshader")
	m.set_shader_parameter(&"paint", colour)
	return m


static func _barrel_mesh() -> Mesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.46
	c.bottom_radius = 0.46
	c.height = 1.0
	c.radial_segments = 14
	c.rings = 1
	return c


static func _block_mesh() -> Mesh:
	var b := BoxMesh.new()
	b.size = Vector3(1.5, 0.9, 0.75)
	return b
