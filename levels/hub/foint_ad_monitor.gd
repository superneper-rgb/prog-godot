class_name FointAdMonitor
extends Node3D
## A floating video billboard in FOINT CITY: the Foint n' Shoot ad on loop, with no sound, on a dark armoured monitor that hovers on two jets over the plaza in front of the FOINT DOME and bobs.
## Added 2026-11-18 (user: "a cool little floating slightly bouncing monitor billboard near the foint dome"). The monitor is built here in code. The video is assets/video/alien_times_square.frames:
## JPEG frames made from the user's MP4 by tools/export/render-video.mjs (Godot has no MP4 decoder here). Each frame is decoded and mipmapped on a worker thread, and only while the screen is on
## screen and near enough to matter, so the main thread only uploads it. HubLife builds it under the district (it hides with it) and calls update() each frame with the district's clock.

const VIDEO := "res://assets/video/alien_times_square.frames"
const SCREEN := "res://levels/shaders/foint_ad_screen.gdshader"
const JET_SHADER := "res://levels/shaders/foint_ad_jet.gdshader"
const SPOT := Vector3(12.0, -3.6, 188.0)      # the screen's centre: over the road left of the dome's gate, beside its left banner, 6 m up (the dome stands at 0, -10, 262 with its gate to -z;
                                              # the ground is y -10). From the bridge it sits in the gap between the gate and the street trees at z 173 (x -9 and 15), which hide anything right of the gate.
const FACE := Vector2(0.0, 150.0)             # the point (x, z) the screen turns to: down the bridge approach, where you first see it
const W := 7.2                                # the screen, 16:9, as built (m)
const H := 4.05
const SIZE := 0.75                            # and the whole unit scaled down: a little one (5.4 m of screen)
const FAR := 260.0                            # past this the picture holds still (it is a few fogged pixels by then)
const KICK := 3.7                             # seconds between the jets' kicks (the bounce)

const SHELL := Color(0.085, 0.07, 0.115)      # the mass's near-black violet
const CYAN := Color(0.3, 0.88, 1.0)
const RED := Color(1.0, 0.13, 0.1)
const JET := Color(0.55, 0.75, 1.0)

var _body: Node3D = null      # what bobs (this node stays where it is put)
var _screen_m: ShaderMaterial = null
var _lip_m: StandardMaterial3D = null
var _jet_m: ShaderMaterial = null
var _nozzle_m: StandardMaterial3D = null
var _beacon_m: ShaderMaterial = null
var _tip_m: ShaderMaterial = null
var _jet_glow_m: ShaderMaterial = null
var _seen: VisibleOnScreenNotifier3D = null
# the video
var _bytes := PackedByteArray()
var _offs := PackedInt32Array()
var _frames := 0
var _fps := 24.0
var _px := Vector2(960.0, 540.0)
var _tex: ImageTexture = null
var _shown := -1
var _task := -1
var _task_frame := -1
var _out: Image = null            # the worker's decoded frame (read only once its task is done)
var _out_avg := Color.BLACK       # and its average colour (its 1 x 1 mip)


## Builds the monitor under `parent` (the district) and loads the video.
static func make(parent: Node3D) -> FointAdMonitor:
	var m := FointAdMonitor.new()
	m.name = "FointAdMonitor"
	parent.add_child(m)
	m.position = SPOT
	m.rotation.y = atan2(FACE.x - SPOT.x, FACE.y - SPOT.z)
	m.scale = Vector3.ONE * SIZE
	m._build()
	m._load_video()
	return m


func _exit_tree() -> void:
	if _task >= 0:      # (a frame still decoding holds this node: let it finish before the node goes)
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## t: the district's clock (s); cam: the camera's position.
func update(t: float, cam: Vector3) -> void:
	if _body == null:
		return
	# the float: a slow bob, and every KICK seconds the jets kick and it bounces on them and settles
	var k := fmod(t, KICK)
	var settle := exp(-k * 2.3)
	_body.position = Vector3(0.0, 0.26 * sin(t * 0.8) + 0.07 * sin(t * 2.05 + 1.3) + 0.2 * settle * sin(k * 7.0), 0.0)
	_body.rotation = Vector3(0.022 * sin(t * 0.57 + 0.4) + 0.03 * settle * sin(k * 7.0 + 0.6), 0.03 * sin(t * 0.31), 0.025 * sin(t * 0.71))
	var thrust := 0.75 + 0.12 * cos(t * 0.8) + 0.9 * exp(-k * 5.0)
	_jet_m.set_shader_parameter(&"power", thrust)
	_jet_m.set_shader_parameter(&"t", t)
	_jet_glow_m.set_shader_parameter(&"opacity", clampf(0.55 + 0.3 * thrust, 0.0, 1.0))
	_nozzle_m.albedo_color = JET * (0.7 + 0.35 * thrust)
	_beacon_m.set_shader_parameter(&"opacity", 0.7 + 0.25 * sin(t * 1.6))
	_tip_m.set_shader_parameter(&"opacity", 1.0 if fmod(t, 1.4) < 0.18 else 0.08)
	_screen_m.set_shader_parameter(&"t", t)
	_video(t, cam)


# ---- the video

func _load_video() -> void:
	_bytes = FileAccess.get_file_as_bytes(VIDEO)
	if _bytes.size() < 16:
		push_warning("FointAdMonitor: %s is missing (node tools/export/render-video.mjs, see its header)" % VIDEO)
		return
	_frames = _bytes.decode_u32(0)
	_fps = _bytes.decode_u32(4) / 1000.0
	_px = Vector2(_bytes.decode_u32(8), _bytes.decode_u32(12))
	_offs.resize(_frames)
	var o := 16
	for i in _frames:
		_offs[i] = o
		o += 4 + _bytes.decode_u32(o)
	_screen_m.set_shader_parameter(&"pixels", _px)


## Shows the frame the clock is on: picks up what the worker finished, then starts the next one if the screen can be seen.
func _video(t: float, cam: Vector3) -> void:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _out != null:
			if _tex == null:
				_tex = ImageTexture.create_from_image(_out)
				_screen_m.set_shader_parameter(&"video", _tex)
			else:
				_tex.update(_out)
			_shown = _task_frame
			_lip_m.albedo_color = _out_avg * 0.55      # the recess round the panel catches its light
			_out = null
	if _frames == 0 or not _seen.is_on_screen() or global_position.distance_to(cam) > FAR:
		return
	var f := int(t * _fps) % _frames
	if f != _shown:
		_task_frame = f
		_task = WorkerThreadPool.add_task(_decode.bind(f), false, "FOINT ad frame")


## (worker thread) one frame: JPEG to RGBA with mipmaps, so the main thread only uploads it
func _decode(f: int) -> void:
	var o := _offs[f]
	var im := Image.new()
	if im.load_jpg_from_buffer(_bytes.slice(o + 4, o + 4 + _bytes.decode_u32(o))) != OK:
		_out = null
		return
	im.convert(Image.FORMAT_RGBA8)
	im.generate_mipmaps()
	var d := im.get_data()
	var a := im.get_mipmap_offset(im.get_mipmap_count())
	_out_avg = Color8(d[a], d[a + 1], d[a + 2])
	_out = im


# ---- the monitor: screen centre at the origin, the screen faces +z

func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var hw := W / 2.0
	var hh := H / 2.0
	var shell := StandardMaterial3D.new()
	shell.albedo_color = SHELL
	shell.metallic = 0.7
	shell.roughness = 0.32
	var dark := StandardMaterial3D.new()
	dark.albedo_color = SHELL.darkened(0.45)
	dark.metallic = 0.45
	dark.roughness = 0.55
	var strip := _lamp(CYAN)
	_lip_m = _lamp(Color(0.1, 0.1, 0.14))
	_nozzle_m = _lamp(JET)
	var s_shell := _st()
	var s_dark := _st()
	var s_strip := _st()
	var s_lip := _st()
	var s_noz := _st()
	# the bezel: a chamfered frame sloping out from the panel, the rim behind it, the back tapering away like an old set's
	var o_hx := hw + 0.44
	var o_hy := hh + 0.44
	var outer := _outline(o_hx, o_hy, 0.5)
	var inner := _outline(hw + 0.05, hh + 0.05, 0.1)
	var panel := _outline(hw, hh, 0.04)
	var back1 := _outline(hw + 0.2, hh + 0.2, 0.36)
	var back2 := _outline(hw * 0.74, hh * 0.64, 0.3)
	_ring(s_shell, _xy(outer, 0.04), _xy(inner, 0.14), Vector3(0.0, 0.0, 1.0), 1.0)
	_ring(s_lip, _xy(inner, 0.14), _xy(panel, 0.0), Vector3(0.0, 0.0, 0.3), -1.0)
	_ring(s_shell, _xy(outer, 0.04), _xy(outer, -0.1), Vector3.ZERO, 1.0)
	_ring(s_shell, _xy(outer, -0.2), _xy(outer, -0.34), Vector3.ZERO, 1.0)
	_ring(s_shell, _xy(outer, -0.34), _xy(back1, -0.34), Vector3(0.0, 0.0, -1.0), 0.0)
	_ring(s_shell, _xy(back1, -0.34), _xy(back2, -1.2), Vector3(0.0, 0.0, -0.3), 1.0)
	_cap(s_shell, _xy(back2, -1.2), Vector3(0.0, 0.0, -1.0))
	# the cyan light running round the rim, a hair proud of it
	var lit := _outline(o_hx + 0.025, o_hy + 0.025, 0.51)
	_ring(s_strip, _xy(lit, -0.1), _xy(lit, -0.2), Vector3.ZERO, 1.0)
	_ring(s_strip, _xy(outer, -0.1), _xy(lit, -0.1), Vector3(0.0, 0.0, 1.0), 0.0)
	_ring(s_strip, _xy(outer, -0.2), _xy(lit, -0.2), Vector3(0.0, 0.0, -1.0), 0.0)
	# the back: a spine and vent slats either side of it
	_box(s_dark, Vector3(0.0, 0.0, -1.3), Vector3(0.9, hh * 1.1, 0.2))
	for i in 5:
		var y := -0.72 + i * 0.36
		for sx: float in [-1.0, 1.0]:
			_box(s_dark, Vector3(sx * 1.55, y, -1.235), Vector3(1.9, 0.09, 0.07))
	# the beacon housings on the top corners and the antenna
	var top := o_hy
	for sx: float in [-1.0, 1.0]:
		_box(s_dark, Vector3(sx * (hw - 0.35), top + 0.08, -0.15), Vector3(0.34, 0.16, 0.3))
	_box(s_dark, Vector3(2.35, top + 0.72, -0.2), Vector3(0.07, 1.44, 0.07))
	_box(s_dark, Vector3(2.35, top + 1.05, -0.2), Vector3(0.42, 0.05, 0.05))
	# the side fins, swept back
	for sx: float in [-1.0, 1.0]:
		var fin: Array[Vector3] = [Vector3(sx * 3.7, 0.0, 0.0), Vector3(sx * 3.4, 0.0, -0.62), Vector3(sx * (o_hx + 0.85), 0.0, -0.98), Vector3(sx * (o_hx + 0.7), 0.0, -0.5)]
		_prism(s_shell, fin, 0.12)
	# the hover pods under the bottom: strut, pod, glowing nozzle
	for sx: float in [-1.0, 1.0]:
		var c := Vector3(sx * 2.3, 0.0, -0.45)
		_box(s_dark, Vector3(c.x, -o_hy - 0.12, -0.35), Vector3(0.36, 0.36, 0.5))
		_cyl(s_shell, c, 0.42, -o_hy - 0.22, 0.3, -o_hy - 0.72, 10, true, false)
		_cyl(s_noz, c, 0.31, -o_hy - 0.72, 0.27, -o_hy - 0.8, 10, false, true)
	var meshes := [[s_shell, shell], [s_dark, dark], [s_strip, strip], [s_lip, _lip_m], [s_noz, _nozzle_m]]
	for p: Array in meshes:
		_add(p[0], p[1])
	# the panel itself
	var sc := _st()
	sc.set_normal(Vector3(0.0, 0.0, 1.0))
	var corners := [[Vector2(-hw, hh), Vector2(0, 0)], [Vector2(hw, hh), Vector2(1, 0)], [Vector2(hw, -hh), Vector2(1, 1)], [Vector2(-hw, hh), Vector2(0, 0)], [Vector2(hw, -hh), Vector2(1, 1)], [Vector2(-hw, -hh), Vector2(0, 1)]]
	for v: Array in corners:
		sc.set_uv(v[1])
		sc.add_vertex(Vector3(v[0].x, v[0].y, 0.0))
	_screen_m = ShaderMaterial.new()
	_screen_m.shader = load(SCREEN)
	_add(sc, _screen_m)
	# the jets' cones
	var sj := _st()
	for sx: float in [-1.0, 1.0]:
		_cone(sj, Vector3(sx * 2.3, 0.0, -0.45), 0.24, -o_hy - 0.8, 0.55, -o_hy - 2.6, 16)
	_jet_m = ShaderMaterial.new()
	_jet_m.shader = load(JET_SHADER)
	_jet_m.set_shader_parameter(&"color", JET)
	_add(sj, _jet_m)
	# the glows: red beacons, the antenna's blinking tip, the jets' hot mouths
	_beacon_m = _glow(PackedVector3Array([Vector3(-(hw - 0.35), top + 0.22, -0.15), Vector3(hw - 0.35, top + 0.22, -0.15)]), RED, 1.3)
	_tip_m = _glow(PackedVector3Array([Vector3(2.35, top + 1.5, -0.2)]), RED, 1.6)
	_jet_glow_m = _glow(PackedVector3Array([Vector3(-2.3, -o_hy - 0.95, -0.45), Vector3(2.3, -o_hy - 0.95, -0.45)]), JET, 2.4)
	_glow(PackedVector3Array([Vector3(-(o_hx + 0.82), 0.0, -0.9), Vector3(o_hx + 0.82, 0.0, -0.9)]), CYAN, 0.8)
	# on screen? (the whole unit, jets included)
	_seen = VisibleOnScreenNotifier3D.new()
	_seen.aabb = AABB(Vector3(-o_hx - 1.0, -o_hy - 3.2, -1.5), Vector3(o_hx * 2.0 + 2.0, o_hy * 2.0 + 5.0, 1.8))
	_body.add_child(_seen)


static func _lamp(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	m.albedo_color = c
	return m


static func _st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


func _add(st: SurfaceTool, m: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)


func _glow(pts: PackedVector3Array, c: Color, size: float) -> ShaderMaterial:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	var pm := ArrayMesh.new()
	pm.add_surface_from_arrays(Mesh.PRIMITIVE_POINTS, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(c.r, c.g, c.b, 0.85)
	mi.material_override = bm
	_body.add_child(mi)
	var gm := GlowPoints.replace(mi, size)
	mi.queue_free()
	return gm


# ---- mesh pieces. Faces are given counter-clockwise or not, and turned to face `toward`; flat normals.

## a chamfered rectangle's outline, counter-clockwise seen from +z: half sizes hx, hy, corner cut c
static func _outline(hx: float, hy: float, c: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(hx, -hy + c), Vector2(hx, hy - c), Vector2(hx - c, hy), Vector2(-hx + c, hy), Vector2(-hx, hy - c), Vector2(-hx, -hy + c), Vector2(-hx + c, -hy), Vector2(hx - c, -hy)])


static func _xy(o: PackedVector2Array, z: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in o:
		out.append(Vector3(p.x, p.y, z))
	return out


## (Godot's front faces wind clockwise: the triangle is given counter-clockwise from its front and added the other way round)
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal((b - a).cross(c - a).normalized())
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(b)


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, toward: Vector3) -> void:
	if (b - a).cross(c - a).dot(toward) < 0.0:
		var s := b
		b = d
		d = s
	_tri(st, a, b, c)
	_tri(st, a, c, d)


## the band between two loops of the same count (an outline in the xy plane each): each quad faces its edge's outward normal * out, plus toward
static func _ring(st: SurfaceTool, a: PackedVector3Array, b: PackedVector3Array, toward: Vector3, out: float) -> void:
	var n := a.size()
	for i in n:
		var j := (i + 1) % n
		var e := a[j] - a[i]
		var o := Vector3(e.y, -e.x, 0.0).normalized() * out + toward
		_face(st, a[i], b[i], b[j], a[j], o)


## a convex loop's cap, a fan from its centre
static func _cap(st: SurfaceTool, a: PackedVector3Array, toward: Vector3) -> void:
	var c := Vector3.ZERO
	for p in a:
		c += p
	c /= float(a.size())
	for i in a.size():
		var p := a[i]
		var q := a[(i + 1) % a.size()]
		if (p - c).cross(q - c).dot(toward) < 0.0:
			_tri(st, c, q, p)
		else:
			_tri(st, c, p, q)


static func _box(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s / 2.0
	var p: Array[Vector3] = []
	for i in 8:
		p.append(c + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	_face(st, p[1], p[3], p[7], p[5], Vector3.RIGHT)
	_face(st, p[0], p[4], p[6], p[2], Vector3.LEFT)
	_face(st, p[2], p[6], p[7], p[3], Vector3.UP)
	_face(st, p[0], p[1], p[5], p[4], Vector3.DOWN)
	_face(st, p[4], p[5], p[7], p[6], Vector3.BACK)
	_face(st, p[0], p[2], p[3], p[1], Vector3.FORWARD)


## a convex outline in the xz plane (y 0) made `t` thick
static func _prism(st: SurfaceTool, o: Array[Vector3], t: float) -> void:
	var lo := PackedVector3Array()
	var hi := PackedVector3Array()
	var c := Vector3.ZERO
	for p in o:
		lo.append(p - Vector3(0.0, t / 2.0, 0.0))
		hi.append(p + Vector3(0.0, t / 2.0, 0.0))
		c += p
	c /= float(o.size())
	for i in o.size():
		var j := (i + 1) % o.size()
		_face(st, lo[i], lo[j], hi[j], hi[i], (o[i] + o[j]) / 2.0 - c)
	_cap(st, hi, Vector3.UP)
	_cap(st, lo, Vector3.DOWN)


## an upright tapered cylinder round c (x, z) from radius r0 at y0 down to r1 at y1
static func _cyl(st: SurfaceTool, c: Vector3, r0: float, y0: float, r1: float, y1: float, sides: int, cap_top: bool, cap_bottom: bool) -> void:
	var a := PackedVector3Array()
	var b := PackedVector3Array()
	for i in sides:
		var th := TAU * (float(i) + 0.5) / float(sides)
		a.append(Vector3(c.x + sin(th) * r0, y0, c.z + cos(th) * r0))
		b.append(Vector3(c.x + sin(th) * r1, y1, c.z + cos(th) * r1))
	for i in sides:
		var j := (i + 1) % sides
		var mid := (a[i] + a[j]) / 2.0
		_face(st, a[i], a[j], b[j], b[i], Vector3(mid.x - c.x, 0.0, mid.z - c.z))
	if cap_top:
		_cap(st, a, Vector3.UP)
	if cap_bottom:
		_cap(st, b, Vector3.DOWN)


## an open cone for a jet: UV.x round it, UV.y from the mouth (0) to the end (1)
static func _cone(st: SurfaceTool, c: Vector3, r0: float, y0: float, r1: float, y1: float, sides: int) -> void:
	for i in sides:
		var u0 := float(i) / float(sides)
		var u1 := float(i + 1) / float(sides)
		var p := [Vector3(c.x + sin(u0 * TAU) * r0, y0, c.z + cos(u0 * TAU) * r0), Vector3(c.x + sin(u1 * TAU) * r0, y0, c.z + cos(u1 * TAU) * r0),
				Vector3(c.x + sin(u1 * TAU) * r1, y1, c.z + cos(u1 * TAU) * r1), Vector3(c.x + sin(u0 * TAU) * r1, y1, c.z + cos(u0 * TAU) * r1)]
		var uv := [Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0)]
		var n := Vector3(sin((u0 + u1) * PI), 0.0, cos((u0 + u1) * PI))
		for k: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(uv[k])
			st.add_vertex(p[k])
