class_name VendorStage
extends SubViewport
## One small 3D view shared by every shop (JS class VendorStage): a ticked deck ring, a halo and a light pool behind the subject, the subject turning on the spot. Every subject is built once and cached; switching only toggles visibility. Driven from the menu's frame on the real-time UI clock. Engine difference: Godot has no global clipping planes, so the JS's scan-in clip is a screen-space reveal of this view (VendorMenu reads `reveal`).

var cam: Camera3D = null
var world: Node3D = null
var spin: Node3D = null
var deck: MeshInstance3D = null
var halo: MeshInstance3D = null
var pool: MeshInstance3D = null
var deck_m: StandardMaterial3D = null
var halo_m: StandardMaterial3D = null
var pool_m: StandardMaterial3D = null
var hemi: WorldEnvironment = null
var key: DirectionalLight3D = null
var rim: DirectionalLight3D = null
var low: DirectionalLight3D = null
var cache := {}
var cur: Dictionary = {}
var mode := "w"
var wf := true
var tr := 1.0
var yaw := 0.0
var dist := 4.0
var dist_t := 4.0
var t := 0.0
var _snap := true
var reveal := 1.0      # how much of the view the scan front has passed (0..1)
var reveal_v := false  # false: left to right (weapons); true: bottom to top (suits)
var edge_col := Color.WHITE
var edge_a := 0.0


static func _ring_tex(n: int) -> ImageTexture:
	# technical backdrop (JS: canvas-drawn): rings, ticks, four arcs; n: the deck's extra spokes
	var S := 512
	var img := Image.create(S, S, false, Image.FORMAT_LA8)
	var put := func(px: int, py: int, a: float) -> void:
		if px < 0 or py < 0 or px >= S or py >= S:
			return
		var c := img.get_pixel(px, py)
		var v := maxf(c.a, a)
		img.set_pixel(px, py, Color(1, 1, 1, v))
	var arc := func(r: float, w: float, a0: float, a1: float, al: float) -> void:
		var steps := int((a1 - a0) * r * 1.5)
		var hw := int(ceilf(w * 0.5))
		for i in steps:
			var a := a0 + (a1 - a0) * i / steps
			for d in range(-hw, hw + 1):
				put.call(256 + int(cos(a) * (r + d)), 256 + int(sin(a) * (r + d)), al)
	arc.call(250.0, 3.0, 0.0, TAU, 0.9)
	arc.call(236.0, 1.5, 0.0, TAU, 0.5)
	arc.call(180.0, 1.0, 0.0, TAU, 0.35)
	for k in 4:
		arc.call(212.0, 7.0, k * PI / 2.0 + 0.25, k * PI / 2.0 + (1.0 if n != 0 else 1.25), 0.7)
	var ray := func(a: float, r0: float, r1: float, al: float) -> void:
		var steps := int(absf(r1 - r0) * 1.5) + 1
		for i in steps:
			var r := lerpf(r0, r1, float(i) / steps)
			put.call(256 + int(cos(a) * r), 256 + int(sin(a) * r), al)
	for k in 120:
		ray.call(k / 120.0 * TAU, 248.0, 248.0 - (8.0 if k % 10 != 0 else 18.0), 0.65)
	if n != 0:
		for k in 8:
			ray.call(k / 8.0 * TAU, 60.0, 176.0, 0.3)
		arc.call(60.0, 1.0, 0.0, TAU, 0.4)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _pool_tex() -> GradientTexture2D:
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.25), Color(1, 1, 1, 0)])
	var g := GradientTexture2D.new()
	g.gradient = gr
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	return g


func _add_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# (additive in the JS; on this see-through view additive light would have no alpha and vanish, and over the dark screen the two read the same)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _plane(m: Material, s: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	var n := MeshInstance3D.new()
	n.mesh = q
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(n)
	return n


func _init() -> void:
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	size = Vector2i(400, 300)
	gui_disable_input = true
	audio_listener_enable_3d = false
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	world = Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.2
	hemi = WorldEnvironment.new()
	hemi.environment = env
	world.add_child(hemi)
	cam = Camera3D.new()
	cam.fov = 26.0
	cam.near = 0.05
	cam.far = 60.0
	world.add_child(cam)
	cam.current = true
	var light := func(pos: Vector3) -> DirectionalLight3D:
		var l := DirectionalLight3D.new()
		l.position = pos
		world.add_child(l)
		l.look_at_from_position(pos, Vector3.ZERO)
		return l
	key = light.call(Vector3(-2.2, 3, 4))
	rim = light.call(Vector3(3, 1.6, -4))
	low = light.call(Vector3(0.5, -3, 2))
	low.light_color = Color(0x6688aaff)
	low.light_energy = 0.7
	spin = Node3D.new()
	world.add_child(spin)
	deck_m = _add_mat(_ring_tex(1))
	halo_m = _add_mat(_ring_tex(0))
	pool_m = _add_mat(_pool_tex())
	deck = _plane(deck_m, 2.6)
	deck.rotation.x = -PI / 2.0
	halo = _plane(halo_m, 2.4)
	pool = _plane(pool_m, 1.7)
	pool.rotation.x = -PI / 2.0


static func _hex(h: int) -> Color:
	return Color8((h >> 16) & 255, (h >> 8) & 255, h & 255)


## set the theme / framing mode ('w' weapon, 'a' armor, 'p' vials, 'gw' / 'fa' the arms depots: weapons in Goint amber / suits in Foint red)
func attach(p_mode: String) -> void:
	mode = p_mode
	_snap = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var W := mode == "w" or mode == "gw"
	wf = W
	var col := 0xff3944 if W else (0x7fc4ff if mode == "p" else 0xffc23a)
	var rim_c := 0x75edff if W else 0xffa628
	var key_c := 0xfff1d8 if W else 0xfff0d8
	var hemi_c := 0xffe7d1 if W else 0xffe0b0
	var ground_c := 0x21070f if W else 0x160e05
	var edge := 0xbff8ff if W else 0xfff0b0
	key.light_energy = (2.6 if W else 3.4) / PI      # (three.js lights are in candela-style units: its directional light of 1 is 1 / PI in Godot's)
	var he := 1.1 if W else 1.5
	if W:
		deck.position = Vector3(0, -0.78, 0)
		pool.position = Vector3(0, -0.79, 0)
		halo.position = Vector3(0, 0, -1.3)
		halo.scale = Vector3.ONE
		deck.scale = Vector3.ONE
		pool.scale = Vector3.ONE
	else:
		deck.position = Vector3(0, -1.0, 0)
		deck.scale = Vector3.ONE * 0.62
		pool.position = Vector3(0, -1.01, 0)
		pool.scale = Vector3.ONE * 0.75
		halo.position = Vector3(0, 0.42, -0.7)
		halo.scale = Vector3.ONE * 0.62
	if mode == "gw":
		col = 0xffc23a
		rim_c = 0xffa628
		edge = 0xfff0b0
		ground_c = 0x160e05
	if mode == "fa":
		col = 0xff3944
		rim_c = 0x75edff
		edge = 0xbff8ff
		ground_c = 0x21070f
	if mode == "p":      # orange: the implant terminal is an orange CRT
		col = 0xff9a2e
		rim_c = 0xff9440
		key_c = 0xfff0e0
		hemi_c = 0xffe0c0
		ground_c = 0x180c04
		edge = 0xffd9a0
	var c := _hex(col)
	deck_m.albedo_color = Color(c.r, c.g, c.b, 0.5)
	halo_m.albedo_color = Color(c.r, c.g, c.b, 0.32)
	pool_m.albedo_color = Color(c.r, c.g, c.b, 0.35)
	rim.light_color = _hex(rim_c)
	rim.light_energy = 3.4 / PI
	key.light_color = _hex(key_c)
	edge_col = _hex(edge)
	var env := hemi.environment
	env.ambient_light_color = _hex(hemi_c).lerp(_hex(ground_c), 0.5)      # (the hemisphere light, sky and ground averaged)
	env.ambient_light_energy = he / PI


## show a cached subject (built on first use), restarting the short scan-in. No queue: a new call simply restarts it.
func show_subject(k: String, build: Callable, instant: bool) -> void:
	var s: Dictionary = cache.get(k, {})
	if s.is_empty():
		var obj: Node3D = build.call()
		var wrap := Node3D.new()
		var tilt := Node3D.new()
		tilt.add_child(obj)
		wrap.add_child(tilt)
		spin.add_child(wrap)
		var box := _aabb(obj, obj.global_transform.affine_inverse())
		obj.position -= box.get_center()
		var sz := box.size
		var rxz := Vector2(sz.x, sz.z).length() / 2.0
		var r3 := Vector2(rxz, sz.y / 2.0).length()
		var q := 1.0 / maxf(1e-3, r3) if wf else 2.0 / maxf(1e-3, sz.y)      # weapons: bounding sphere -> 1, so any spin angle stays framed
		wrap.scale = Vector3.ONE * q
		if wf:
			tilt.rotation.x = 0.1
		s = {"wrap": wrap, "rxz": rxz * q, "hy": sz.y * q / 2.0, "mode": mode}
		cache[k] = s
	for v: Dictionary in cache.values():
		(v.wrap as Node3D).visible = v == s
	var fresh: bool = cur != s
	cur = s
	_fit()
	if fresh:
		tr = 1.0 if instant else 0.0
		yaw = 1.05 if wf else -0.5


func _aabb(n: Node, inv: Transform3D) -> AABB:
	var out := AABB()
	var has := false
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var c: Node = stack.pop_back()
		stack.append_array(c.get_children())
		if c is VisualInstance3D and c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var a: AABB = (inv * (c as Node3D).global_transform) * (c as MeshInstance3D).get_aabb()
			out = a if not has else out.merge(a)
			has = true
	return out


func _fit() -> void:
	if cur.is_empty() or size.x < 2:
		return
	var aspect := float(size.x) / size.y
	var vf := deg_to_rad(cam.fov) / 2.0
	var hf := atan(tan(vf) * aspect)
	var rxz: float = cur.rxz
	dist_t = 1.0 / sin(minf(hf, vf)) if wf else maxf(1.12 / tan(vf), (rxz * 1.15) / tan(hf)) + rxz


func set_view_size(s: Vector2i) -> void:
	if s == size:
		return
	size = s
	_fit()
	if _snap:
		dist = dist_t
		_snap = false


func frame(dt: float) -> void:
	if cur.is_empty():
		return
	if _snap:
		_fit()
		dist = dist_t
		_snap = false
	var W := wf
	t += dt
	yaw += dt * (0.5 if W else 0.38)
	dist += (dist_t - dist) * minf(1.0, dt * 14.0)
	var e := 1.0
	if tr < 1.0:
		tr = minf(1.0, tr + dt / 0.22)
		e = tr
	var ee := 1.0 - pow(1.0 - e, 3.0)
	spin.rotation.y = yaw - 0.45 * (1.0 - ee)
	spin.scale = Vector3.ONE * (0.94 + 0.06 * ee)
	deck.rotation = Vector3(-PI / 2.0, 0, t * 0.11)
	halo.rotation.z = -t * 0.05
	halo_m.albedo_color.a = (0.3 if W else 0.38) + 0.05 * sin(t * 1.3)
	var el := 0.2 if W else 0.08
	var ty := 0.0 if W else 0.02
	cam.position = Vector3(0, ty + sin(el) * dist, cos(el) * dist)
	cam.look_at(Vector3(0, ty, 0))
	# scan front: weapons reveal left -> right, suits bottom -> top
	reveal = ee
	reveal_v = not W
	edge_a = 0.9 * sin(PI * minf(1.0, e * 1.1)) if e < 1.0 else 0.0
