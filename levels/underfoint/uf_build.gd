class_name UfBuild
extends RefCounted
## UNDERFOINT's builder: boxes, ramps and flat faces that are both collision (World) and picture. Every piece of one material goes into one mesh, so a city block is a handful of draws however many pieces it has.
## Two kinds of material: `mat` is the greybox one (a flat colour with stains, for the parts still standing in), `tex` a photographed one with damp, moss and puddles. levels/underfoint/uf_arch.gd builds the buildings out of this.

const SURFACE := preload("res://levels/shaders/uf_surface.gdshader")

var world: World
var mats: Dictionary = {}          # tag -> Material
var base_y := 0.0                  # the ground under what is being built: a face's shade and growth are measured up from it
var shade := 1.0                   # multiplies every face's painted shade (a building a little darker than its neighbour)
var foot_shade := 0.5              # the shade at base_y; 1 = no darkening toward the ground
var grow := 0.0                    # added growth (moss) on what is built next: 0 none .. 1 thick
var _bufs: Dictionary = {}         # tag -> Buf
var _noise: NoiseTexture2D
var _stain: NoiseTexture2D         # the surface shader's stains, moss and puddles


## One material's faces so far
class Buf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var tg := PackedFloat32Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var ix := PackedInt32Array()


func _init(w: World) -> void:
	world = w
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.02
	n.fractal_octaves = 5
	n.seed = 41
	_noise = NoiseTexture2D.new()
	_noise.width = 256
	_noise.height = 256
	_noise.seamless = true
	_noise.noise = n
	_noise.generate_mipmaps = true
	_noise.color_ramp = _ramp(0.45, 1.0)
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n2.frequency = 0.012
	n2.fractal_octaves = 5
	n2.fractal_gain = 0.55
	n2.seed = 7
	_stain = NoiseTexture2D.new()
	_stain.width = 512
	_stain.height = 512
	_stain.seamless = true
	_stain.noise = n2
	_stain.generate_mipmaps = true


static func _ramp(lo: float, hi: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(lo, lo, lo))
	g.set_color(1, Color(hi, hi, hi))
	return g


## A lit material with stains over it (world-space triplanar noise, so no box needs UVs). o: {rough, metal, scale}
func mat(tag: String, color: Color, o: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _noise
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	var s: float = o.get("scale", 0.12)
	m.uv1_scale = Vector3(s, s, s)
	m.roughness = o.get("rough", 0.9)
	m.metallic = o.get("metal", 0.0)
	mats[tag] = m
	return m


## A material that only glows: fungus, screens, flames, lamp glass
func glow(tag: String, color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.BLACK
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 1.0
	mats[tag] = m
	return m


## A photographed material from Poly Haven (assets/third-party/polyhaven/<set>), tiled in metres on every face, under levels/shaders/uf_surface.gdshader.
## o: {tile (metres a repeat covers), tint, rough, metal, depth (normal strength), growth (moss), puddles}
func tex(tag: String, set_name: String, o: Dictionary = {}) -> ShaderMaterial:
	var dir := "res://assets/third-party/polyhaven/%s/textures/%s_" % [set_name, set_name]
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	for nm: String in ["diff_1k.jpg", "diffuse_1k.jpg"]:
		if ResourceLoader.exists(dir + nm):
			m.set_shader_parameter(&"albedo_tex", load(dir + nm))
	m.set_shader_parameter(&"normal_tex", load(dir + "nor_gl_1k.jpg"))
	var packed := ResourceLoader.exists(dir + "arm_1k.jpg")
	m.set_shader_parameter(&"arm_tex", load(dir + ("arm_1k.jpg" if packed else "rough_1k.jpg")))
	m.set_shader_parameter(&"arm_packed", 1.0 if packed else 0.0)
	m.set_shader_parameter(&"noise_tex", _stain)
	m.set_shader_parameter(&"tile", o.get("tile", 2.0))
	m.set_shader_parameter(&"tint", o.get("tint", Color.WHITE))
	m.set_shader_parameter(&"rough_mul", o.get("rough", 1.0))
	m.set_shader_parameter(&"metal_mul", o.get("metal", 1.0))
	m.set_shader_parameter(&"normal_depth", o.get("depth", 1.0))
	m.set_shader_parameter(&"growth", o.get("growth", 1.0))
	m.set_shader_parameter(&"puddles", o.get("puddles", 0.0))
	mats[tag] = m
	return m


func _buf(tag: String) -> Buf:
	var bf: Buf = _bufs.get(tag)
	if bf == null:
		if not mats.has(tag):
			push_error("UfBuild: no material '%s'" % tag)
			mat(tag, Color.MAGENTA)
		bf = Buf.new()
		_bufs[tag] = bf
	return bf


## One flat face: four corners going round, clockwise seen from the side it faces. It gets its normal, UVs in metres (walls: along and up; floors: x and z), a tangent to match, and the painted shade.
func quad(tag: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var bf := _buf(tag)
	var n := (c - a).cross(b - a).normalized()
	var ax := absf(n.x)
	var ay := absf(n.y)
	var az := absf(n.z)
	var kind := 0 if ay >= ax and ay >= az else (1 if ax >= az else 2)
	var t := Vector3(0.0, 0.0, 1.0) if kind == 1 else Vector3.RIGHT
	var dv := Vector3(0.0, 0.0, 1.0) if kind == 0 else Vector3.DOWN
	var w := 1.0 if n.cross(t).dot(-dv) > 0.0 else -1.0
	var base := bf.v.size()
	var level := 0.35 if n.y > 0.5 else 0.0
	for p: Vector3 in [a, b, c, d]:
		bf.v.append(p)
		bf.n.append(n)
		bf.uv.append(Vector2(p.x, p.z) if kind == 0 else (Vector2(p.z, -p.y) if kind == 1 else Vector2(p.x, -p.y)))
		bf.tg.append(t.x)
		bf.tg.append(t.y)
		bf.tg.append(t.z)
		bf.tg.append(w)
		# the shade: dark and green at a wall's foot, clean higher up; anything lying level gathers growth
		var k := clampf((p.y - base_y) / 3.5, 0.0, 1.0)
		var sh := lerpf(foot_shade, 1.0, k) * shade
		bf.col.append(Color(sh, sh, sh, (1.0 - k) * 0.7 + level + grow))
	bf.ix.append(base)
	bf.ix.append(base + 1)
	bf.ix.append(base + 2)
	bf.ix.append(base)
	bf.ix.append(base + 2)
	bf.ix.append(base + 3)


## A face at any angle with UVs given (metres), for what is not laid along the axes: the last line's route (levels/underfoint/uf_route.gd) bends round curves, so its faces take their UVs from
## the route (along it, across it) and never jump where a wall turns past 45 degrees. Same winding as quad(). shade and wet are the painted shade and how readily moss and wet take on it.
func quad_uv(tag: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, sh: float = 1.0, wet: float = 0.2) -> void:
	var bf := _buf(tag)
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# the tangent: which way U runs across this face (for the normal map)
	var e1 := b - a
	var e2 := c - a
	var d1 := ub - ua
	var d2 := uc - ua
	var r := d1.x * d2.y - d2.x * d1.y
	var t := (e1 * d2.y - e2 * d1.y) / r if absf(r) > 1e-9 else (e1.normalized() if e1.length_squared() > 1e-12 else Vector3.RIGHT)
	t = (t - n * n.dot(t)).normalized()
	var bt := (e2 * d1.x - e1 * d2.x) / r if absf(r) > 1e-9 else n.cross(t)
	var w := 1.0 if n.cross(t).dot(bt) > 0.0 else -1.0
	var base := bf.v.size()
	var level := 0.35 if n.y > 0.5 else 0.0
	var uvs := [ua, ub, uc, ud]
	var k := 0
	for p: Vector3 in [a, b, c, d]:
		bf.v.append(p)
		bf.n.append(n)
		bf.uv.append(uvs[k])
		bf.tg.append(t.x)
		bf.tg.append(t.y)
		bf.tg.append(t.z)
		bf.tg.append(w)
		bf.col.append(Color(sh * shade, sh * shade, sh * shade, wet + level + grow))
		k += 1
	bf.ix.append(base)
	bf.ix.append(base + 1)
	bf.ix.append(base + 2)
	bf.ix.append(base)
	bf.ix.append(base + 2)
	bf.ix.append(base + 3)


## A box at any angle: xf places its centre and turns it, h is its half size. Drawn only. under: false leaves out the face toward its own -Y.
func obox(tag: String, xf: Transform3D, h: Vector3, sh: float = 1.0, wet: float = 0.2, under: bool = true) -> void:
	var p: Array[Vector3] = []
	for k: Vector3 in [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]:
		p.append(xf * (k * h))
	var X := h.x * 2.0
	var Y := h.y * 2.0
	var Z := h.z * 2.0
	quad_uv(tag, p[4], p[5], p[6], p[7], Vector2(0, 0), Vector2(X, 0), Vector2(X, Z), Vector2(0, Z), sh, wet)      # top
	if under:
		quad_uv(tag, p[0], p[3], p[2], p[1], Vector2(0, 0), Vector2(0, Z), Vector2(X, Z), Vector2(X, 0), sh * 0.6, wet)
	quad_uv(tag, p[0], p[1], p[5], p[4], Vector2(0, Y), Vector2(X, Y), Vector2(X, 0), Vector2(0, 0), sh, wet)        # -z
	quad_uv(tag, p[1], p[2], p[6], p[5], Vector2(0, Y), Vector2(Z, Y), Vector2(Z, 0), Vector2(0, 0), sh, wet)        # +x
	quad_uv(tag, p[2], p[3], p[7], p[6], Vector2(0, Y), Vector2(X, Y), Vector2(X, 0), Vector2(0, 0), sh, wet)        # +z
	quad_uv(tag, p[3], p[0], p[4], p[7], Vector2(0, Y), Vector2(Z, Y), Vector2(Z, 0), Vector2(0, 0), sh, wet)        # -x


## A cylinder at any angle: xf places the middle of its axis (its local Z) and turns it; r its radius, half its half length, n its sides. caps: draw its ends.
func ocyl(tag: String, xf: Transform3D, r: float, half: float, n: int = 12, caps: bool = true, sh: float = 1.0, wet: float = 0.2, r_end: float = -1.0) -> void:
	var r1 := r if r_end < 0.0 else r_end
	var circ := TAU * r
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := xf * Vector3(cos(a0) * r, sin(a0) * r, -half)
		var p1 := xf * Vector3(cos(a1) * r, sin(a1) * r, -half)
		var q0 := xf * Vector3(cos(a0) * r1, sin(a0) * r1, half)
		var q1 := xf * Vector3(cos(a1) * r1, sin(a1) * r1, half)
		var u0 := circ * i / n
		var u1 := circ * (i + 1) / n
		quad_uv(tag, p0, q0, q1, p1, Vector2(u0, 0.0), Vector2(u0, half * 2.0), Vector2(u1, half * 2.0), Vector2(u1, 0.0), sh, wet)
		if caps:
			var c0 := xf * Vector3(0.0, 0.0, -half)
			var c1 := xf * Vector3(0.0, 0.0, half)
			quad_uv(tag, c0, p0, p1, c0, Vector2(0, 0), Vector2(cos(a0) * r, sin(a0) * r), Vector2(cos(a1) * r, sin(a1) * r), Vector2(0, 0), sh * 0.9, wet)
			quad_uv(tag, c1, q1, q0, c1, Vector2(0, 0), Vector2(cos(a1) * r1, sin(a1) * r1), Vector2(cos(a0) * r1, sin(a0) * r1), Vector2(0, 0), sh * 0.9, wet)


## Eight corners: the bottom four then the top four, each going round (x-z-, x+z-, x+z+, x-z+). under: false leaves the bottom face out (it sits on something).
func _hexa(tag: String, p: PackedVector3Array, under: bool = true) -> void:
	quad(tag, p[4], p[5], p[6], p[7])
	if under:
		quad(tag, p[0], p[3], p[2], p[1])
	quad(tag, p[0], p[1], p[5], p[4])
	quad(tag, p[1], p[2], p[6], p[5])
	quad(tag, p[2], p[3], p[7], p[6])
	quad(tag, p[3], p[0], p[4], p[7])


## The inside of a box: a room's floor, walls and ceiling, facing in. No collision.
func room(floor_tag: String, wall_tag: String, ceil_tag: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	var p := PackedVector3Array([Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)])
	quad(ceil_tag, p[4], p[7], p[6], p[5])
	quad(floor_tag, p[0], p[1], p[2], p[3])
	quad(wall_tag, p[0], p[4], p[5], p[1])
	quad(wall_tag, p[1], p[5], p[6], p[2])
	quad(wall_tag, p[2], p[6], p[7], p[3])
	quad(wall_tag, p[3], p[7], p[4], p[0])


## A box from x0..x1, y0..y1, z0..z1. solid: false draws it without collision (cables, slime, glow). under: false leaves out its bottom face.
func box(tag: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, solid: bool = true, under: bool = true) -> World.Solid:
	_hexa(tag, PackedVector3Array([Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x0, y1, z1)]), under)
	if not solid:
		return null
	return world.add({"kind": "box", "cx": (x0 + x1) * 0.5, "cz": (z0 + z1) * 0.5, "hx": (x1 - x0) * 0.5, "hz": (z1 - z0) * 0.5, "bottom": y0, "top": y1, "tag": tag})


## A box turned about the vertical: centre, half sizes, yaw. Drawn only (leaning planks, a skewed crate, a car left across the road).
func turned(tag: String, cx: float, cz: float, hx: float, hz: float, y0: float, y1: float, yaw: float, lean: Vector2 = Vector2.ZERO) -> void:
	var c := cos(yaw)
	var s := sin(yaw)
	var pts := PackedVector3Array()
	for top: bool in [false, true]:
		for k: Array in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
			var lx: float = k[0] * hx + (lean.x if top else 0.0)
			var lz: float = k[1] * hz + (lean.y if top else 0.0)
			pts.append(Vector3(cx + lx * c + lz * s, y1 if top else y0, cz - lx * s + lz * c))
	_hexa(tag, pts)


## A ramp: centre, half sizes, low and high surface heights. At yaw 0 it rises toward +z (World's own ramp); `thick` is the slab under the surface.
func ramp(tag: String, cx: float, cz: float, hx: float, hz: float, y_low: float, y_high: float, yaw: float = 0.0, thick: float = 0.6, solid: bool = true) -> World.Solid:
	var c := cos(yaw)
	var s := sin(yaw)
	var pts := PackedVector3Array()
	var base := minf(y_low, y_high) - thick
	for top: bool in [false, true]:
		for k: Array in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
			var lx: float = k[0] * hx
			var lz: float = k[1] * hz
			var y := base if not top else (y_low if lz < 0.0 else y_high)
			pts.append(Vector3(cx + lx * c + lz * s, y, cz - lx * s + lz * c))      # (World: lx = dx*c - dz*s, lz = dx*s + dz*c)
	_hexa(tag, pts)      # (a turn keeps the corners going round the same way, so the faces still point out)
	if not solid:
		return null
	return world.add({"kind": "ramp", "cx": cx, "cz": cz, "hx": hx, "hz": hz, "yaw": yaw, "bottom": base, "top": y_high, "top_low": y_low, "tag": tag})


## Everything drawn so far becomes one mesh per material under `parent`. Call it more than once (a city block at a time) and each lot is its own set of meshes, culled on its own.
func commit(parent: Node3D, part: String = "") -> void:
	for tag: String in _bufs:
		var bf: Buf = _bufs[tag]
		if bf.v.is_empty():
			continue
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = bf.v
		arr[Mesh.ARRAY_NORMAL] = bf.n
		arr[Mesh.ARRAY_TANGENT] = bf.tg
		arr[Mesh.ARRAY_TEX_UV] = bf.uv
		arr[Mesh.ARRAY_COLOR] = bf.col
		arr[Mesh.ARRAY_INDEX] = bf.ix
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.name = "uf_" + tag + part
		mi.mesh = mesh
		mi.material_override = mats[tag]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # (no shadow-casting light down here yet)
		parent.add_child(mi)
	_bufs.clear()
