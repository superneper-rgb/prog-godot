class_name MenuScene
extends Control
## MAIN MENU SCENE (JS menu/menu-scene.js): a rainy prison yard at night. Prog, in the Phantom Suit with his tri-lens night vision goggles, peeks out from behind a wet stone wall on the right (a dark silhouette, rim-lit, the lenses blooming green). Heavy rain; behind him, now and then, a lightning bolt strikes and lights him and the whole yard up.
## On first show: the goggles' charge whine plays, the lenses flicker on, a lightning strike lights the scene, then the menu fades in. Its own world in its own viewport: the game's world is not drawn while the menu is up.
## ENGINE DIFFERENCES: no "PRESS ANY BUTTON" state (it only waits for a browser's audio unlock). Canvases and synth voices are baked by tools/export/render-menu-assets.mjs, thunder three times per kind. The rain falls in a vertex shader. Bloom is the environment's glow, set by eye against the JS picture.

# Prog's pose: euler deltas (model space) on the Animator's bones. He faces the camera turned to his right, leaning out from behind the wall.
const YAW := -0.55
const POSE := {
	&"spine1": Vector3(0.0, 0.0, 0.05), &"spine2": Vector3(0.04, 0.0, 0.06), &"chest": Vector3(0.06, 0.0, 0.05), &"neck": Vector3(0.04, 0.12, -0.04), &"head": Vector3(0.1, 0.2, -0.08),
	&"clavicleL": Vector3(0.0, 0.0, -0.1), &"clavicleR": Vector3(0.0, 0.0, 0.1),
	&"upper_armL": Vector3(0.15, 0.0, -1.0), &"upper_armR": Vector3(0.35, 0.0, 1.0), &"forearmL": Vector3(-0.4, 0.0, 0.0), &"forearmR": Vector3(-0.6, 0.0, 0.0),
}
# the camera, relative to the goggles: where it stands and where it looks (head right of centre, wall on the right edge)
const CAM_OFF := Vector3(-0.32, -0.03, 0.95)
const CAM_LOOK := Vector3(-0.17, -0.05, 0.0)
const CAM_FOV := 34.0
# the lenses switching on in the opening: [time s, glow] keys (a stuttering power-up), then the strike and the menu
const BOOT_KEYS := [[0.0, 0.0], [0.62, 0.0], [0.66, 0.7], [0.72, 0.05], [0.8, 0.9], [0.86, 0.2], [0.95, 1.6], [1.3, 1.0]]
const BOOT_STRIKE := 1.25
const BOOT_REVEAL := 1.7
const WIND := -3.5
const FALL := 24.0
const FOG_K := 0.03
const TEX := "res://assets/ui/menu_scene/"
const SND := "res://assets/sfx/menu/"
const BUS := &"MenuScene"
const BUS_THUNDER := &"MenuThunder"
# where lightning strikes. Each strike picks one (never the same twice running): x = range across the screen (NDC), d = how far off, w = channel width,
# br = how often it forks, flash = how hard it lights the scene, sound = thunder kinds to pick from, pan = left / right, crawl = runs across the clouds first (-1 left, 1 right)
const SPOTS := [
	{"x": [0.02, 0.32], "top": 1.1, "d": 120.0, "w": 0.9, "br": 0.22, "flash": 1.0, "sound": ["crack", "boom"], "pan": 0.25, "crawl": 0},      # right behind his head
	{"x": [-0.85, -0.62], "top": 1.1, "d": 150.0, "w": 1.15, "br": 0.34, "flash": 0.8, "sound": ["roll", "crack"], "pan": -0.7, "crawl": 0},      # over the cell block on the left: heavily forked
	{"x": [-0.2, 0.0], "top": 0.85, "d": 250.0, "w": 2.6, "br": 0.12, "flash": 0.5, "sound": ["distant", "roll"], "pan": -0.2, "crawl": -1},      # far off over the yard: crawls left through the clouds, then drops
]
const DELAY := [[0.15, 0.7], [0.9, 1.9], [2.4, 4.2]]      # flash -> thunder, by spot (sound travels ~340 m/s)


class Spot:
	var bone := -1
	var node: Node3D = null
	var lp := Vector3.ZERO


class DropLayer:
	var n := 0
	var mm: MultiMesh
	var buf := PackedFloat32Array()
	var mat: ShaderMaterial
	var base := Vector3.ONE
	func put(i: int, p: Vector3, size: float, alpha: float) -> void:
		var o := i * 16
		buf[o] = size
		buf[o + 3] = p.x
		buf[o + 5] = size
		buf[o + 7] = p.y
		buf[o + 10] = size
		buf[o + 11] = p.z
		buf[o + 15] = alpha
	func flush() -> void:
		mm.buffer = buf


class Run:
	var life := 0.0
	var max_ := 0.0
	var t := 0.0
	var p := Vector3.ZERO
	var v := 0.0
	var ph := 0.0
	var size := 0.0


class Ring:
	var t := 9.0
	var p := Vector3.ZERO
	var set_ := false


class Spray:
	var t := 9.0
	var life := 0.0
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var sz := 0.0


class Strike:
	var t := 0.0
	var pulses: Array = []
	var k := 1.0
	var end := 0.0


var built := false
var state := &"idle"      # idle | boot | live
var revealed := false
var on_reveal := Callable()
var an: Animator = null
var P: Player = null
var nvg: Goggles = null

var _vp: SubViewport
var _rect: TextureRect
var _w: Node3D
var _cam: Camera3D
var _env: Environment
var _hemi_i := 0.3
var _bolt_l: DirectionalLight3D
var _flash_l: DirectionalLight3D
var _lens := Vector3.ZERO
var _cam_base := Vector3.ZERO
var _look_base := Vector3.ZERO
var _wall_box := AABB()
var _pose_k: Dictionary = {}
var _fog_mats: Array[ShaderMaterial] = []
var _fog := Vector3.ZERO
var _fog_flash := Vector3.ZERO
var _fog_set := -1.0
var _wall_glow: ShaderMaterial
var _sky: ShaderMaterial
var _bolt: MeshInstance3D
var _bolt_mat: ShaderMaterial
var _beam_pivot: Node3D
var _beacons: Array = []
var _mist: Array = []
var _rains: Array[ShaderMaterial] = []
var _rain_base: Array[float] = []
var _glow_tex: Texture2D
var _refl_tex: Texture2D
var _refl_mesh: ArrayMesh
var _quad: QuadMesh
var _dark: ShaderMaterial
var _win: ShaderMaterial

# the rain on Prog
var _wet_seen: Array[Spot] = []
var _wet_near: Array[Spot] = []
var _wet_hits: Array[Spot] = []
var _beads: DropLayer
var _runs: DropLayer
var _rings: DropLayer
var _spray: DropLayer
var _bead_at: Array[Spot] = []
var _bead_k := PackedFloat32Array()
var _bead_max := PackedFloat32Array()
var _bead_size := PackedFloat32Array()
var _run_st: Array[Run] = []
var _ring_st: Array[Ring] = []
var _spray_st: Array[Spray] = []
var _splash_acc := 0.0
var _reseat := 0.0
var _xf_cache: Dictionary = {}

# sound
var _rain: AudioStreamPlayer
var _rain_t := -1.0
var _whine: AudioStreamPlayer
var _pending: Array = []      # [seconds left, stream, gain, pan]
var _thunder: Array[AudioStreamPlayer] = []
var _panner: AudioEffectPanner

# time
var _strike: Strike = null
var _next_strike := INF
var _last_spot := 0
var _boot_t := 0.0
var _glow := 0.0
var _time := 0.0
var _mx := 0.0
var _my := 0.0


func _init() -> void:
	name = "MenuScene"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _rand(a: float, b: float) -> float:
	return a + randf() * (b - a)


static func _v(hex: int) -> Vector3:
	var c := Color.hex((hex << 8) | 0xff).srgb_to_linear()
	return Vector3(c.r, c.g, c.b)


## Everything once (behind the boot screen or the fade), so the first frame does not hitch.
func build() -> void:
	if built:
		return
	built = true
	var t0 := Time.get_ticks_msec()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.use_hdr_2d = true      # (the picture stays linear for menu_tone.gdshader)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.gui_disable_input = true
	_vp.audio_listener_enable_3d = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.texture = _vp.get_texture()
	var tm := ShaderMaterial.new()
	tm.shader = load("res://ui/menu_scene/menu_tone.gdshader")
	_rect.material = tm
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_w = Node3D.new()
	_vp.add_child(_w)
	_fog = _v(0x0a0f18)
	_fog_flash = _v(0x4a5878)
	_glow_tex = load(TEX + "glow.png")
	_refl_tex = load(TEX + "refl.png")
	_quad = QuadMesh.new()
	_build_environment()
	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.near = 0.05
	_cam.far = 400.0
	_cam.current = true
	_w.add_child(_cam)
	_resize()
	_build_prog()
	_build_wall_and_ground()
	_build_prison()
	_build_sky()
	_build_rain()
	_build_wet()
	_build_sound()
	_cam.look_at_from_position(_cam_base, _look_base)
	_set_glow(0.0)
	_set_fog(0.0)
	_make_bolt(SPOTS[0])
	_bolt.visible = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE      # (compiles everything now)
	print("[menu scene] built in %d ms, %d wet spots" % [Time.get_ticks_msec() - t0, _wet_seen.size()])


# ---- lights: a faint cold ambient, a blue rim from behind-left, and the lightning (sky fill + a hard back light) ----

func _dir_light(hex: int, intensity: float, from: Vector3, to: Vector3 = Vector3.ZERO) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = Color.hex((hex << 8) | 0xff)
	l.light_energy = intensity / PI      # (Godot's energy 1 is three's pi)
	l.shadow_enabled = false
	_w.add_child(l)
	l.look_at_from_position(from, to)
	return l


func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color.BLACK
	# the hemisphere light, as View does it: a sky never drawn, read only by the ambient
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = View.HEMI_SKY_SHADER
	sm.shader = sh
	var a := _v(0x40506e)
	var b := _v(0x07080b)
	var leak := View.HEMI_LEAK
	var k := 1.0 / (PI * (1.0 - 2.0 * leak))
	sm.set_shader_parameter(&"sky_color", (a * (1.0 - leak) - b * leak).max(Vector3.ZERO) * k)
	sm.set_shader_parameter(&"ground_color", (b * (1.0 - leak) - a * leak).max(Vector3.ZERO) * k)
	var sky := Sky.new()
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.3
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# bloom (the lenses, the lamps, the bolt): threshold 0.9, weighted to the tight levels (a crisp halo round the lenses, not a green fog over his face). Levels and amount set by eye against the JS picture: Godot's glow keeps more of the light than UnrealBloomPass at strength 0.9.
	_env.glow_enabled = true
	_env.glow_normalized = false
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_hdr_threshold = 0.9
	_env.glow_hdr_scale = 1.0
	_env.glow_intensity = 0.36
	_env.glow_bloom = 0.0
	for i in 7:
		_env.set_glow_level(i, [0.0, 0.0, 1.0, 0.55, 0.18, 0.05, 0.0][i])
	var we := WorldEnvironment.new()
	we.environment = _env
	_w.add_child(we)
	_dir_light(0x8fb0ff, 1.6, Vector3(-5.0, 5.0, -7.0))
	_dir_light(0x6f86b8, 0.45, Vector3(-3.0, 1.5, 4.0))      # just enough on his face to read the shape
	_bolt_l = _dir_light(0xc8d6ff, 0.0, Vector3(0.0, 90.0, -50.0))
	_flash_l = _dir_light(0xb8c8ff, 0.0, Vector3(-3.0, 3.0, 2.0))


# ---- Prog: posed once, the goggles fitted to his head and switched off ----

func _build_prog() -> void:
	var B := Builds.character_build("prog")
	var ps: PackedScene = load(B.file)
	an = Animator.new(ps.instantiate(), B)
	PhantomSuit.set_phantom_suit(an, true)
	P = Player.new(null)
	P.x = 0.0
	P.y = 0.0
	P.z = 0.0
	P.yaw = YAW
	P.flip = -1.0
	for k: StringName in POSE:
		_pose_k[k] = Animator.KEYS.find(k)
	_w.add_child(an.actor)
	_breathe(0.0)
	an.skel.force_update_all_bone_transforms()
	var walk: Array[Node] = [an.actor]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if an.wv != null:
		an.wv.group.visible = false      # no weapon in hand
	nvg = Goggles.fit(an, "prog")
	if nvg != null:
		for s: MeshInstance3D in nvg.glows:      # tight halos (sized for the in-game camera they wash his whole face this close)
			s.scale *= 0.38
			_lens += s.global_position
		_lens /= float(nvg.glows.size())
	else:
		_lens = an.bone_world_pos(an.by_key[&"head"].bone)
	# green spill from the lenses on the wall beside him: a soft additive glow on the wall's edge (a light would also flood his face)
	_wall_glow = _sprite_mat(_glow_tex, _v(0x4cff2a), 0.0)
	var wg := _sprite(_wall_glow, _lens + Vector3(0.42, -0.05, 0.05), Vector3(0.6, 0.9, 1.0))
	wg.extra_cull_margin = 2.0
	# camera framing from the lens position
	_cam_base = _lens + CAM_OFF
	_look_base = _lens + CAM_LOOK
	_flash_l.look_at_from_position(_cam_base + Vector3(-3.0, 3.0, 2.0), _lens)


func _breathe(t: float) -> void:
	an.pose.fill(Vector3.ZERO)
	for k: StringName in POSE:
		var i: int = _pose_k[k]
		if i >= 0:
			an.pose[i] = POSE[k]
	var b := sin(t * 1.6) * 0.012
	var s := sin(t * 0.37) * 0.02
	var ic: int = Animator.KEYS.find(&"chest")
	var ih: int = Animator.KEYS.find(&"head")
	an.pose[ic] += Vector3(b, 0.0, 0.0)
	an.pose[ih] += Vector3(-b * 0.6, s, 0.0)
	an._apply(P)


## lenses + halos at g (0 = off: the halo sprites are hidden outright, an additive sprite at opacity 0 still shows through the bloom), face light kept low so he stays a silhouette
func _set_glow(g: float) -> void:
	if nvg == null:
		return
	nvg.set_glow(g)
	nvg.lens_mat.emission_energy_multiplier = 2.6 * g
	for s: MeshInstance3D in nvg.glows:
		s.visible = g > 0.02
	nvg.glow_mat.set_shader_parameter(&"opacity", 0.6 * minf(g, 1.3))
	nvg.light.light_energy = 0.0


# ---- material and sprite helpers ----

func _lit(col: int, rough: float, metal: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://ui/menu_scene/menu_lit.gdshader")
	m.set_shader_parameter(&"col", _v(col))
	m.set_shader_parameter(&"rough", rough)
	m.set_shader_parameter(&"metal", metal)
	m.set_shader_parameter(&"fog_k", FOG_K)
	_fog_mats.append(m)
	return m


func _basic(col: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://ui/menu_scene/menu_basic.gdshader")
	m.set_shader_parameter(&"col", col)
	m.set_shader_parameter(&"fog_k", FOG_K)
	_fog_mats.append(m)
	return m


func _sprite_mat(tex: Texture2D, col: Vector3, opacity: float, billboard: bool = true, additive: bool = true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://ui/menu_scene/menu_glow.gdshader" if additive else "res://ui/menu_scene/menu_mist.gdshader")
	m.set_shader_parameter(&"map", tex)
	m.set_shader_parameter(&"col", col)
	m.set_shader_parameter(&"opacity", opacity)
	m.set_shader_parameter(&"billboard", billboard)
	m.set_shader_parameter(&"fog_k", FOG_K)
	_fog_mats.append(m)
	return m


func _sprite(mat: Material, p: Vector3, sc: Vector3, par: Node3D = null) -> MeshInstance3D:
	var s := MeshInstance3D.new()
	s.mesh = _quad
	s.material_override = mat
	s.position = p
	s.scale = sc
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.extra_cull_margin = maxf(sc.x, sc.y)
	(par if par != null else _w).add_child(s)
	return s


func _part(par: Node3D, mesh: Mesh, mat: Material, p: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Goggles.part(par, mesh, mat, p, rot)


## A box with each face's UV running 0..1 (three.js BoxGeometry; Godot's BoxMesh lays its faces out on an atlas).
static func _uv_box(s: Vector3) -> ArrayMesh:
	var h := s * 0.5
	var P_ := PackedVector3Array()
	var uv := PackedVector2Array()
	var I := PackedInt32Array()
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var o := P_.size()
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			P_.append((n + a * c.x + b * c.y) * h)
			uv.append(Vector2((c.x + 1.0) * 0.5, (1.0 - c.y) * 0.5))
		I.append_array([o, o + 1, o + 2, o, o + 2, o + 3])
	var st := SurfaceTool.new()
	st.create_from(Goggles.indexed_mesh(P_, I, uv), 0)
	st.generate_tangents()
	return st.commit()


# ---- the wall he hides behind (right edge of the frame) and the ground: wet black tarmac; light reflections are stretched streaks under each lamp ----

func _build_wall_and_ground() -> void:
	var stone: Texture2D = load(TEX + "stone.png")
	var im := stone.get_image()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	im.bump_map_to_normal_map(1.0)      # (bumpMap: stone, bumpScale 3; three.js scales its derivative differently: strength set by eye against the JS)
	im.generate_mipmaps()
	var wm := _lit(0xc4ccd8, 0.32, 0.2)
	wm.set_shader_parameter(&"map", stone)
	wm.set_shader_parameter(&"normal_map", ImageTexture.create_from_image(im))
	wm.set_shader_parameter(&"has_normal", true)
	wm.set_shader_parameter(&"uv_scale", Vector2(1.0, 2.5))
	var wp := Vector3(_lens.x + 0.4 + 0.8, 4.5 - 0.3, _lens.z - 0.2)
	_part(_w, _uv_box(Vector3(1.6, 9.0, 1.4)), wm, wp)
	_wall_box = AABB(wp - Vector3(0.8, 4.5, 0.7), Vector3(1.6, 9.0, 1.4))
	var g := PlaneMesh.new()
	g.size = Vector2(400.0, 400.0)
	_part(_w, g, _lit(0x0a0c10, 0.34, 0.5))
	# a light's reflection on the wet ground: a long streak lying on the ground, running from under the light towards the camera, broken up by ripples
	_refl_mesh = Goggles.indexed_mesh(PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1)]), PackedInt32Array([0, 2, 1, 0, 3, 2]), PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))


func _reflection(x: float, z: float, color: int, width: float, len_: float, o: float) -> void:
	var m := _part(_w, _refl_mesh, _sprite_mat(_refl_tex, _v(color), o, false), Vector3(x, 0.02, z))
	m.scale = Vector3(width, 1.0, len_)


func _lamp(x: float, y: float, z: float, color: int, size: float, refl: bool = true) -> MeshInstance3D:
	var s := _sprite(_sprite_mat(_glow_tex, _v(color), 1.0), Vector3(x, y, z), Vector3.ONE * size)
	if refl:
		_reflection(x, z, color, size * 0.5, minf(4.0 + y * 2.2, 16.0), 0.5)
	return s


# ---- the prison: watchtowers (lit cab, red beacon, a sweeping searchlight on the near one), a block on the left, a fence with lamps ----

func _tower(x: float, z: float, h: float, search: bool) -> void:
	var g := Node3D.new()
	g.position = Vector3(x, 0.0, z)
	_w.add_child(g)
	_part(g, Goggles.box_mesh(2.4, h, 2.4), _dark, Vector3(0.0, h / 2.0, 0.0))
	_part(g, Goggles.box_mesh(4.6, 0.3, 4.6), _dark, Vector3(0.0, h, 0.0))
	_part(g, Goggles.box_mesh(3.4, 2.2, 3.4), _dark, Vector3(0.0, h + 1.4, 0.0))
	var wq := QuadMesh.new()
	wq.size = Vector2(2.6, 0.9)
	for e: Array in [[0.0, 1.71, 0.0], [1.71, 0.0, PI / 2.0], [-1.71, 0.0, -PI / 2.0]]:
		_part(g, wq, _win, Vector3(e[0], h + 1.6, e[1]), Vector3(0.0, e[2], 0.0))
	_part(g, Goggles.cyl_mesh(0.0, 3.3, 1.1, 4), _dark, Vector3(0.0, h + 3.05, 0.0), Vector3(0.0, PI / 4.0, 0.0))
	for i in 4:
		var a := i * PI / 2.0
		_part(g, Goggles.box_mesh(4.6, 0.08, 0.08), _dark, Vector3(0.0, h + 1.0, 0.0) + Basis(Vector3.UP, a) * Vector3(0.0, 0.0, 2.25), Vector3(0.0, a, 0.0))
	for i in 4:
		_part(g, Goggles.box_mesh(0.12, h * 0.8, 0.12), _dark, Vector3(-1.6 if i < 2 else 1.6, h * 0.4, -1.6 if i % 2 else 1.6))
	_part(g, Goggles.cyl_mesh(0.04, 0.04, 1.2, 8), _dark, Vector3(0.0, h + 4.1, 0.0))
	var bc := _sprite_mat(_glow_tex, _v(0xff2a1a), 1.0)
	_sprite(bc, Vector3(x, h + 4.75, z), Vector3.ONE * 1.4)
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	sp.radial_segments = 8
	sp.rings = 6
	var core := _part(g, sp, _basic(Vector3(4.0, 0.4, 0.2)), Vector3(0.0, h + 4.75, 0.0))
	_beacons.append([bc, core, randf() * 6.0])
	_lamp(x, h + 1.6, z + 1.9, 0xffd9a0, 2.4, false)
	_reflection(x, z + 2.5, 0xffd9a0, 1.6, 14.0, 0.4)
	_reflection(x, z + 2.2, 0xff3a2a, 0.5, 9.0, 0.35)
	if search:
		_beam_pivot = Node3D.new()
		_beam_pivot.position = Vector3(x + 1.2, h + 1.7, z + 1.2)
		_w.add_child(_beam_pivot)
		# apex at the lamp, opening along +z (v = 1 at the apex)
		var len_ := 46.0
		var Pb := PackedVector3Array()
		var uv := PackedVector2Array()
		var Ib := PackedInt32Array()
		for i in 33:
			var a := TAU * i / 32.0
			Pb.append(Vector3.ZERO)
			uv.append(Vector2(float(i) / 32.0, 1.0))
			Pb.append(Vector3(5.5 * sin(a), 5.5 * cos(a), len_))
			uv.append(Vector2(float(i) / 32.0, 0.0))
			if i < 32:
				Ib.append_array([i * 2, i * 2 + 1, i * 2 + 3])
		var bm := ShaderMaterial.new()
		bm.shader = load("res://ui/menu_scene/menu_beam.gdshader")
		bm.set_shader_parameter(&"color", Vector3(0.8, 0.88, 1.0))
		bm.set_shader_parameter(&"intensity", 0.55)
		var beam := _part(_beam_pivot, Goggles.indexed_mesh(Pb, Ib, uv), bm)
		beam.extra_cull_margin = 10.0
		_sprite(_sprite_mat(_glow_tex, _v(0xe8f0ff), 1.0), Vector3.ZERO, Vector3.ONE * 2.6, _beam_pivot)
		_sprite(_sprite_mat(_glow_tex, _v(0xffffff), 1.0), Vector3.ZERO, Vector3.ONE * 0.9, _beam_pivot)


func _fence(x0: float, x1: float, z: float, h: float, chain: Texture2D) -> void:
	var W := x1 - x0
	var q := QuadMesh.new()
	q.size = Vector2(W, h)
	var m := _lit(0x6a7380, 0.5, 0.6)
	m.set_shader_parameter(&"map", chain)
	m.set_shader_parameter(&"uv_scale", Vector2(W / 0.22, h / 0.22))
	m.set_shader_parameter(&"alpha_test", 0.4)
	_part(_w, q, m, Vector3((x0 + x1) / 2.0, h / 2.0, z))
	var post := Goggles.cyl_mesh(0.06, 0.06, h + 0.6, 12)
	var x := x0
	while x <= x1 + 0.01:
		_part(_w, post, _dark, Vector3(x, (h + 0.6) / 2.0, z))
		x += 3.0
	var pts := PackedVector3Array()      # (the coil: a polyline of the JS's points, 17 cm apart and 30 m away: its Catmull-Rom would not show)
	for i in int(W * 6.0) + 1:
		var a := i * 0.9
		pts.append(Vector3(x0 + i / 6.0, h + 0.6 + sin(a) * 0.28, z + cos(a) * 0.28))
	_part(_w, Goggles.tube(pts, 0.02, 4, false), _dark)


func _build_prison() -> void:
	_dark = _lit(0x151a22, 0.8, 0.2)
	_win = _basic(Vector3(1.1, 0.92, 0.62))
	_tower(-2.0, -24.0, 4.4, true)
	_tower(4.5, -46.0, 4.4, false)
	_tower(22.0, -66.0, 4.2, false)
	# cell block on the left, a few lit windows
	_part(_w, Goggles.box_mesh(12.0, 8.0, 30.0), _dark, Vector3(-15.0, 4.0, -34.0))      # set back far enough to leave sky above it (lightning strikes there)
	var wq := QuadMesh.new()
	wq.size = Vector2(0.6, 0.8)
	for i in 9:
		if randf() < 0.35:
			continue
		_part(_w, wq, _win, Vector3(-8.99, 1.8 + (i % 3) * 2.2, -22.0 - (i / 3) * 8.0 - _rand(0.0, 3.0)), Vector3(0.0, PI / 2.0, 0.0))
	_part(_w, Goggles.box_mesh(60.0, 7.0, 4.0), _dark, Vector3(0.0, 3.5, -90.0))
	# fence: posts, chain-link, a coil of razor wire on top, lamps on some posts
	var chain: Texture2D = load(TEX + "chain.png")
	_fence(-9.0, 24.0, -28.0, 4.2, chain)
	_fence(-9.0, 30.0, -40.0, 4.2, chain)
	_lamp(3.0, 4.6, -27.8, 0xfff1d8, 1.6)
	_lamp(9.0, 4.6, -27.8, 0xfff1d8, 1.4)
	_lamp(14.0, 4.6, -39.8, 0xfff1d8, 1.1)
	_lamp(-4.5, 3.4, -14.0, 0xffc27a, 1.0)
	# low mist drifting over the wet ground
	var mm := _sprite_mat(_glow_tex, _v(0x5c6a80), 0.09, true, false)
	for i in 18:
		var s := _sprite(mm, Vector3(_rand(-14.0, 10.0), _rand(0.4, 1.6), _rand(-34.0, -6.0)), Vector3(_rand(8.0, 14.0), _rand(2.0, 3.5), 1.0))
		_mist.append([s, _rand(0.2, 0.5)])


# ---- sky + the bolt ----

func _build_sky() -> void:
	_sky = ShaderMaterial.new()
	_sky.shader = load("res://ui/menu_scene/menu_sky.gdshader")
	var s := SphereMesh.new()
	s.radius = 300.0
	s.height = 600.0
	s.radial_segments = 32
	s.rings = 16
	_part(_w, s, _sky)
	_bolt_mat = _sprite_mat(null, Vector3.ONE, 1.0, false)
	_bolt_mat.set_shader_parameter(&"fog_k", 0.0)      # (fog: false)
	_fog_mats.erase(_bolt_mat)
	_bolt_mat.render_priority = -1
	_bolt = MeshInstance3D.new()
	_bolt.material_override = _bolt_mat
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	_bolt.visible = false
	_w.add_child(_bolt)


## a fresh jagged bolt (main channel + branches) as flat ribbons facing the camera at one of the SPOTS
func _make_bolt(S: Dictionary) -> void:
	var D: float = S.d
	var fwd := -_cam.global_basis.z
	var up := Vector3.UP
	var right := fwd.cross(up).normalized()
	var tan_h := tan(deg_to_rad(_cam.fov) * 0.5)
	var aspect := float(_vp.size.x) / float(_vp.size.y)
	var nx := _rand(S.x[0], S.x[1])
	var ray := (_cam.global_basis * Vector3(nx * tan_h * aspect, float(S.top) * tan_h, -1.0)).normalized()
	var top: Vector3 = _cam.global_position + ray * D
	var J := D / 75.0      # jaggedness scaled with distance, so far bolts look as jagged on screen
	var pos := PackedVector3Array()
	var add := func(a: Vector3, b: Vector3, w: float) -> void:
		var s := (b - a).cross(fwd).normalized() * (w / 2.0)      # ribbon width across the segment, in the screen plane
		pos.append_array([a - s, a + s, b + s, a - s, b + s, b - s])
	var br: float = S.br
	var channel: Callable
	channel = func(p0: Vector3, len_: float, w: float, depth: int, drift: float, self_: Callable) -> Vector3:
		var p := p0
		var n := maxi(6, roundi(len_ / (2.4 * J)))
		for i in n:
			var q: Vector3 = p + up * (-len_ / n) + right * ((_rand(-1.6, 1.6) + drift) * J)
			add.call(p, q, w * (1.0 - 0.6 * i / n))
			if depth < 2 and randf() < br:
				self_.call(q, len_ * _rand(0.25, 0.45), w * 0.5, depth + 1, _rand(-1.4, 1.4), self_)
			p = q
		return p
	# cloud-to-cloud crawl: a forking run sideways under the cloud base, then the stroke drops from part-way along it
	var start := top
	var crawl: int = S.crawl
	if crawl != 0:
		var p := top
		var drop := top
		for i in 14:
			var q: Vector3 = p + right * (float(crawl) * _rand(2.0, 4.0) * J) + up * (_rand(-1.2, 1.2) * J)
			add.call(p, q, float(S.w) * 0.7)
			if randf() < 0.3:
				channel.call(q, _rand(6.0, 14.0) * J, float(S.w) * 0.35, 2, _rand(-1.0, 1.0), channel)
			if i == 6:
				drop = q
			p = q
		start = drop
	var bottom: Vector3 = channel.call(start, start.y + 4.0, S.w, 0, _rand(-0.3, 0.3), channel)      # down to the horizon
	_sky.set_shader_parameter(&"u_bolt", (top.lerp(bottom, 0.4) - _cam.global_position).normalized())
	# lit from high above the bolt: from mid-height its glare on the wet ground lands right in the frame
	var from := top.lerp(bottom, 0.5)
	from.y += 90.0
	_bolt_l.look_at_from_position(from, _lens)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_bolt.mesh = mesh


# ---- rain: streaks falling with a little wind, a far layer and a near layer ----

func _rain_layer(n: int, box: Array, len_: float, opacity: float) -> void:
	var V := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	V.resize(n * 2)
	uv.resize(n * 2)
	uv2.resize(n * 2)
	var h: float = float(box[3]) - float(box[2])
	for i in n:
		var y: float = float(box[2]) + randf() * h
		var seed_ := _rand(0.85, 1.2)
		var id := randf() * 1000.0
		V[i * 2] = Vector3(0.0, y, 0.0)
		V[i * 2 + 1] = Vector3(0.0, y, 0.0)
		uv[i * 2] = Vector2(seed_, 0.0)
		uv[i * 2 + 1] = Vector2(seed_, 1.0)
		uv2[i * 2] = Vector2(id, 0.0)
		uv2[i * 2 + 1] = Vector2(id, 0.0)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = V
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	var m := ShaderMaterial.new()
	m.shader = load("res://ui/menu_scene/menu_rain.gdshader")
	m.set_shader_parameter(&"color", _v(0xa8bcd8))
	m.set_shader_parameter(&"opacity", opacity)
	m.set_shader_parameter(&"seg_len", len_)
	m.set_shader_parameter(&"box_min", Vector3(box[0], box[2], box[4]))
	m.set_shader_parameter(&"box_max", Vector3(box[1], box[3], box[5]))
	m.set_shader_parameter(&"wind", WIND)
	m.set_shader_parameter(&"fall", FALL)
	m.set_shader_parameter(&"fog_k", FOG_K)
	_fog_mats.append(m)
	var o := _part(_w, mesh, m)
	o.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	_rains.append(m)
	_rain_base.append(opacity)


func _build_rain() -> void:
	var c := _cam_base
	_rain_layer(9000, [c.x - 22.0, c.x + 18.0, -0.5, c.y + 9.0, c.z - 40.0, c.z - 2.5], 0.55, 0.32)
	_rain_layer(700, [c.x - 2.2, c.x + 2.2, -0.5, c.y + 9.0, c.z - 2.5, c.z - 0.3], 0.32, 0.38)


# ---- rain on Prog: beads on the parts of him the camera sees (riding his bones, so they move with him), a few running down, splashes on his head + shoulders ----

func _drop_layer(n: int, tex: Texture2D, col: Vector3) -> DropLayer:
	var L := DropLayer.new()
	L.n = n
	L.base = col
	L.mm = MultiMesh.new()
	L.mm.transform_format = MultiMesh.TRANSFORM_3D
	L.mm.use_colors = true
	L.mm.mesh = _quad
	L.mm.instance_count = n
	L.buf.resize(n * 16)
	L.buf.fill(0.0)
	for i in n:
		L.put(i, Vector3(-999.0, -999.0, -999.0), 0.0, 0.0)
		L.buf[i * 16 + 12] = 1.0
		L.buf[i * 16 + 13] = 1.0
		L.buf[i * 16 + 14] = 1.0
	L.flush()
	L.mat = ShaderMaterial.new()
	L.mat.shader = load("res://ui/menu_scene/menu_drop.gdshader")
	L.mat.set_shader_parameter(&"map", tex)
	L.mat.set_shader_parameter(&"u_color", col)
	L.mat.render_priority = 5
	var o := MultiMeshInstance3D.new()
	o.multimesh = L.mm
	o.material_override = L.mat
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	_w.add_child(o)
	return L


## World position of every vertex of one surface, as posed now (JS getVertexPosition), and its strongest bone.
func _skinned_surface(mi: MeshInstance3D, arr: Array, out: PackedVector3Array, bones: PackedInt32Array) -> void:
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	out.resize(V.size())
	bones.resize(V.size())
	var BI: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var BW: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per: int = BI.size() / V.size()
	var sk := an.skel
	var xf: Array[Transform3D] = []
	var bone_of := PackedInt32Array()
	var sg := sk.global_transform
	for b in mi.skin.get_bind_count():
		var bi := mi.skin.get_bind_bone(b)
		if bi < 0:
			bi = sk.find_bone(mi.skin.get_bind_name(b))
		bone_of.append(bi)
		xf.append(sg * sk.get_bone_global_pose(bi) * mi.skin.get_bind_pose(b) if bi >= 0 else mi.global_transform)
	for i in V.size():
		var v := V[i]
		var p := Vector3.ZERO
		var best := -1
		var bw := -1.0
		var o := i * per
		for j in per:
			var w: float = BW[o + j]
			if w > 0.0:
				p += (xf[BI[o + j]] * v) * w
				if w > bw:
					bw = w
					best = BI[o + j]
		out[i] = p
		bones[i] = bone_of[best] if best >= 0 else -1


func _spot_xf(s: Spot) -> Transform3D:
	if s.node != null:
		return s.node.global_transform
	var c: Variant = _xf_cache.get(s.bone)
	if c != null:
		return c
	var t := an.skel.global_transform * an.skel.get_bone_global_pose(s.bone)
	_xf_cache[s.bone] = t
	return t


func _build_wet() -> void:
	# sample his surface: random points on his triangles (by area), each tied to the bone it moves with
	var ta := PackedVector3Array()
	var tb := PackedVector3Array()
	var tc := PackedVector3Array()
	var t_bone := PackedInt32Array()
	var t_node: Array[Node3D] = []
	var cum := PackedFloat64Array()
	var tot := 0.0
	var walk: Array[Node] = [an.actor]
	while not walk.is_empty():
		var n: Node = walk.pop_back()
		walk.append_array(n.get_children())
		if not n is MeshInstance3D or not (n as MeshInstance3D).is_visible_in_tree():
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or (nvg != null and nvg.root.is_ancestor_of(mi)):      # (the JS samples before its halos and after the goggles; beads on the goggles would read as lens flares here)
			continue
		var gt := mi.global_transform
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var W := PackedVector3Array()
			var B := PackedInt32Array()
			var skinned: bool = mi.skin != null and arr[Mesh.ARRAY_BONES] != null and not (arr[Mesh.ARRAY_BONES] as PackedInt32Array).is_empty()
			if skinned:
				_skinned_surface(mi, arr, W, B)
			else:
				W = gt * (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			var has_idx: bool = idx != null and not (idx as PackedInt32Array).is_empty()
			var cnt: int = (idx as PackedInt32Array).size() if has_idx else W.size()
			for t in range(0, cnt - 2, 3):
				var ia: int = idx[t] if has_idx else t
				var ib: int = idx[t + 1] if has_idx else t + 1
				var ic: int = idx[t + 2] if has_idx else t + 2
				var a := W[ia]
				if a.distance_to(_lens) > 1.0:      # head, shoulders, arms near the frame
					continue
				var b := W[ib]
				var c := W[ic]
				var area := (b - a).cross(c - a).length() / 2.0
				if area < 1e-7:
					continue
				ta.append(a)
				tb.append(b)
				tc.append(c)
				t_bone.append(B[ia] if skinned else -1)
				t_node.append(null if skinned else mi.get_parent() as Node3D)
				tot += area
				cum.append(tot)
	if ta.is_empty():
		return
	var SP := PackedVector3Array()
	var SI := PackedInt32Array()
	var N_S := 24000
	SP.resize(N_S)
	SI.resize(N_S)
	for i in N_S:
		var lo := mini(cum.bsearch(randf() * tot), cum.size() - 1)
		var u := randf()
		var v := randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		SP[i] = ta[lo] + (tb[lo] - ta[lo]) * u + (tc[lo] - ta[lo]) * v
		SI[i] = lo
	# what the camera sees: a coarse depth buffer from the samples themselves, plus the wall in front of him
	_cam.look_at_from_position(_cam_base, _look_base)
	var cam_pos := _cam_base
	var inv := _cam.global_transform.affine_inverse()
	var tan_h := tan(deg_to_rad(_cam.fov) * 0.5)
	var aspect := float(_vp.size.x) / float(_vp.size.y)
	var GW := 240
	var GH := 135
	var zb := PackedFloat32Array()
	zb.resize(GW * GH)
	zb.fill(1e9)
	var cells := PackedInt32Array()
	cells.resize(N_S)
	var dists := PackedFloat32Array()
	dists.resize(N_S)
	for i in N_S:
		var q := inv * SP[i]
		var cell := -1
		if q.z < 0.0:
			var ndx := q.x / (-q.z * tan_h * aspect)
			var ndy := q.y / (-q.z * tan_h)
			if absf(ndx) <= 1.0 and absf(ndy) <= 1.0:
				cell = mini(GH - 1, floori((ndy + 1.0) / 2.0 * GH)) * GW + mini(GW - 1, floori((ndx + 1.0) / 2.0 * GW))
		cells[i] = cell
		dists[i] = SP[i].distance_to(cam_pos)
		if cell >= 0:
			zb[cell] = minf(zb[cell], dists[i])
	var local := func(i: int) -> Spot:
		var s := Spot.new()
		var lo := SI[i]
		s.bone = t_bone[lo]
		s.node = t_node[lo]
		var to_cam := (cam_pos - SP[i]).normalized()
		s.lp = _spot_xf(s).affine_inverse() * (SP[i] + to_cam * 0.004)
		return s
	# what the rain lands on: the highest samples in each 2.5 cm column (top of the head, shoulders), not behind the wall
	var top: Dictionary = {}
	for i in N_S:
		var p := SP[i]
		var k := roundi(p.x / 0.025) * 100000 + roundi(p.z / 0.025)
		var o: Variant = top.get(k)
		if o == null or p.y > SP[o].y:
			top[k] = i
		if cells[i] >= 0 and dists[i] - zb[cells[i]] < 0.012 and not _wall_box.intersects_segment(cam_pos, p):
			var sp: Spot = local.call(i)
			_wet_seen.append(sp)
			if p.distance_to(_lens) < 0.42:      # head, goggles, neck: where the eye goes, so most beads go there
				_wet_near.append(sp)
	for i: int in top.values():
		if SP[i].y > _lens.y - 0.75 and not _wall_box.intersects_segment(cam_pos, SP[i]):
			_wet_hits.append(local.call(i))
	_beads = _drop_layer(260, load(TEX + "bead.png"), _v(0xb4c6e4) * 3.2)
	_runs = _drop_layer(14, load(TEX + "bead.png"), _v(0xc0d0ea) * 2.4)
	_rings = _drop_layer(24, load(TEX + "ring.png"), _v(0x9fb2d0) * 1.6)
	_spray = _drop_layer(160, _glow_tex, _v(0xb8c8e4) * 2.0)
	if not _wet_seen.is_empty():
		_bead_k.resize(_beads.n)
		_bead_max.resize(_beads.n)
		_bead_size.resize(_beads.n)
		for i in _beads.n:
			_bead_at.append(_spot_for())
			_bead_size[i] = _rand(0.005, 0.011) * (1.5 if randf() < 0.12 else 1.0)
			_bead_max[i] = _rand(0.35, 1.0)
			_bead_k[i] = 1.0
		for i in _runs.n:
			var r := Run.new()
			r.t = _rand(0.0, 3.0)
			_run_st.append(r)
	for i in _rings.n:
		_ring_st.append(Ring.new())
	for i in _spray.n:
		_spray_st.append(Spray.new())


func _spot_for() -> Spot:
	var L := _wet_near if (not _wet_near.is_empty() and randf() < 0.7) else _wet_seen
	return L[randi() % L.size()]


func _rain_on_prog(dt: float, flash: float) -> void:
	if _wet_seen.is_empty():
		return
	_xf_cache.clear()
	var glint := 1.0 + 3.5 * flash
	for L: DropLayer in [_beads, _runs, _rings, _spray]:
		L.mat.set_shader_parameter(&"u_color", L.base * glint)
	# beads sit where they landed; now and then one dries off and another lands elsewhere
	_reseat += dt
	while _reseat > 0.12:
		_reseat -= 0.12
		var i := randi() % _beads.n
		_bead_at[i] = _spot_for()
		_bead_k[i] = 0.0
	for i in _beads.n:
		var b := _bead_at[i]
		_bead_k[i] = minf(1.0, _bead_k[i] + dt * 1.5)
		_beads.put(i, _spot_xf(b) * b.lp, _bead_size[i], _bead_max[i] * _bead_k[i] * (0.85 + 0.15 * randf()))
	_beads.flush()
	# a few beads gather and run down, wobbling a little, then are gone
	for i in _runs.n:
		var r := _run_st[i]
		if r.life <= 0.0:
			r.t -= dt
			_runs.buf[i * 16 + 15] = 0.0
			if r.t <= 0.0:
				var s := _spot_for()
				r.p = _spot_xf(s) * s.lp
				r.life = _rand(1.2, 2.6)
				r.max_ = r.life
				r.v = _rand(0.025, 0.06)
				r.ph = _rand(0.0, 6.0)
				r.t = _rand(1.0, 4.0)
				r.size = _rand(0.006, 0.009)
			continue
		r.life -= dt
		r.p.y -= r.v * dt * (0.6 + 0.8 * maxf(0.0, sin(r.ph + r.life * 7.0)))
		r.p.x += sin(r.ph + r.life * 3.0) * 0.004 * dt
		_runs.put(i, r.p, r.size, minf(1.0, minf((r.max_ - r.life) * 4.0, r.life * 2.0)))
	_runs.flush()
	# splashes on his head and shoulders: a ring that spreads and fades, and a few drops thrown up and out
	if not _wet_hits.is_empty():
		_splash_acc += dt * 22.0
		while _splash_acc >= 1.0:
			_splash_acc -= 1.0
			var h := _wet_hits[randi() % _wet_hits.size()]
			var wv := _spot_xf(h) * h.lp
			for s: Ring in _ring_st:
				if s.t >= 0.2:
					s.t = 0.0
					s.p = wv
					s.set_ = true
					break
			for k in 2 + randi() % 3:
				var q: Spray = null
				for s: Spray in _spray_st:
					if s.t >= s.life:
						q = s
						break
				if q == null:
					break
				q.t = 0.0
				q.life = _rand(0.18, 0.32)
				q.p = wv
				q.v = Vector3(_rand(-0.5, 0.5), _rand(0.5, 1.1), _rand(-0.5, 0.5))
				q.sz = _rand(0.004, 0.007)
	for i in _rings.n:
		var s := _ring_st[i]
		s.t += dt
		var u := s.t / 0.2
		if u >= 1.0 or not s.set_:
			_rings.buf[i * 16 + 15] = 0.0
			continue
		_rings.put(i, s.p + Vector3(0.0, 0.002, 0.0), 0.008 + 0.03 * u, 0.55 * (1.0 - u))
	_rings.flush()
	for i in _spray.n:
		var s := _spray_st[i]
		if s.t >= s.life:
			_spray.buf[i * 16 + 15] = 0.0
			continue
		s.t += dt
		s.v.y -= 9.8 * dt
		s.p += s.v * dt
		_spray.put(i, s.p, s.sz, 0.8 * (1.0 - s.t / s.life))
	_spray.flush()


# ---- sound: the rain loop, the goggles' charge whine, thunder. Its buses stay for the session: bus indices are not ours to shift. ----

func _build_sound() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_volume_db(i, linear_to_db(0.9))
		AudioServer.add_bus()
		var j := AudioServer.bus_count - 1
		AudioServer.set_bus_name(j, BUS_THUNDER)
		AudioServer.set_bus_send(j, BUS)
		AudioServer.add_bus_effect(j, AudioEffectPanner.new())
	_panner = AudioServer.get_bus_effect(AudioServer.get_bus_index(BUS_THUNDER), 0) as AudioEffectPanner
	_rain = AudioStreamPlayer.new()
	var st: AudioStream = (load("res://assets/sfx/city-rain.mp3") as AudioStream).duplicate()
	(st as AudioStreamMP3).loop = true
	_rain.stream = st
	_rain.bus = BUS
	_rain.volume_db = -80.0
	add_child(_rain)
	_whine = AudioStreamPlayer.new()
	_whine.stream = load(SND + "whine.wav")
	_whine.bus = BUS
	add_child(_whine)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_THUNDER
		add_child(p)
		_thunder.append(p)


func _thunder_play(kind: String, delay: float, power: float, pan: float) -> void:
	_pending.append([delay, load(SND + "thunder_%s_%d.wav" % [kind, randi() % 3]), power, pan])


# ---- lightning: a few quick pulses at one of the SPOTS (the opening's strike is always the one behind him); next strike 14-30 s later ----

func _do_strike(first: bool) -> void:
	var si := 0
	if not first:
		si = randi() % SPOTS.size()
		while si == _last_spot:
			si = randi() % SPOTS.size()
	_last_spot = si
	var S: Dictionary = SPOTS[si]
	_make_bolt(S)
	var pulses := [[0.0, 0.07, 1.0], [0.1, 0.05, 0.55], [0.19, 0.14, 0.95]]
	if randf() < 0.4:
		pulses.append([0.42, 0.08, 0.6])
	_strike = Strike.new()
	_strike.pulses = pulses
	_strike.k = S.flash
	var last: Array = pulses[pulses.size() - 1]
	_strike.end = float(last[0]) + float(last[1]) + 0.5
	var snd: Array = S.sound
	_thunder_play(snd[randi() % snd.size()], 0.05 if first else _rand(DELAY[si][0], DELAY[si][1]), 1.0 if first else float(S.flash) * _rand(0.75, 1.0), S.pan)
	_next_strike = _rand(14.0, 30.0)


func _flash_at(t: float) -> Vector2:
	if _strike == null:
		return Vector2.ZERO
	var f := 0.0
	var b := 0.0
	for e: Array in _strike.pulses:
		var s: float = e[0]
		var d: float = e[1]
		var k: float = e[2]
		if t >= s and t < s + d:
			f = maxf(f, k)
			b = maxf(b, k)
		elif t >= s + d:
			f = maxf(f, k * exp(-(t - s - d) * 9.0) * 0.6)
	return Vector2(f * _strike.k, b)      # a far strike lights the scene less; its bolt stays as bright


# ---- the opening, per frame ----

## start the opening (after the intro cutscene, or at once when it is skipped)
func begin() -> void:
	if state != &"idle":
		return
	state = &"boot"
	_boot_t = 0.0
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rain.play()
	_rain_t = 0.0
	_whine.play()


func _reveal() -> void:
	if revealed:
		return
	revealed = true
	if on_reveal.is_valid():
		on_reveal.call()


func _resize() -> void:
	var s := Vector2i(get_viewport_rect().size)
	if s.x < 2 or s.y < 2:
		s = Vector2i(1280, 720)
	if _vp.size == s:
		return
	_vp.size = s
	_cam.fov = CAM_FOV * maxf(1.0, 1.6 / (float(s.x) / float(s.y)))      # narrow windows: widen so he stays in shot


func _set_fog(f: float) -> void:
	if f == _fog_set:
		return
	_fog_set = f
	var c := _fog.lerp(_fog_flash, f * 0.5)
	for m: ShaderMaterial in _fog_mats:
		m.set_shader_parameter(&"fog_col", c)


## every frame while the menu is up
func frame(dt: float) -> void:
	if state == &"idle" or not built:
		return
	dt = minf(dt, 0.05)
	_time += dt
	_resize()
	# the opening
	if state == &"boot":
		_boot_t += dt
		var g: float = BOOT_KEYS[BOOT_KEYS.size() - 1][1]
		for i in BOOT_KEYS.size() - 1:
			var a: Array = BOOT_KEYS[i]
			var b: Array = BOOT_KEYS[i + 1]
			if _boot_t >= float(a[0]) and _boot_t < float(b[0]):
				g = lerpf(a[1], b[1], (_boot_t - float(a[0])) / (float(b[0]) - float(a[0])))
				break
		_glow = g
		if _boot_t >= BOOT_STRIKE and _strike == null and _next_strike == INF:
			_do_strike(true)
		if _boot_t >= BOOT_REVEAL:
			state = &"live"
			_reveal()
	elif state == &"live":
		_glow = 1.0 + 0.03 * sin(_time * 23.0) * randf()
	# lightning
	if state == &"live" or (state == &"boot" and _strike != null):
		if _strike != null:
			_strike.t += dt
			if _strike.t > _strike.end:
				_strike = null
		else:
			_next_strike -= dt
			if _next_strike <= 0.0:
				_do_strike(false)
	var fb := _flash_at(_strike.t if _strike != null else 0.0)
	var f := fb.x
	var b0 := fb.y
	_sky.set_shader_parameter(&"u_time", _time)
	_sky.set_shader_parameter(&"u_flash", f)
	_bolt.visible = _bolt.mesh != null and (b0 > 0.05 or f > 0.15)
	if _bolt.visible:
		var x := maxf(b0, f * 0.5)
		_bolt_mat.set_shader_parameter(&"col", Vector3(3.0 * x, 3.4 * x, 5.0 * x))
	_bolt_l.light_energy = 3.5 * f / PI
	_flash_l.light_energy = 2.2 * f / PI
	_env.ambient_light_energy = 0.3 + 1.4 * f
	_set_fog(f)
	# goggles
	_set_glow(_glow)
	_wall_glow.set_shader_parameter(&"opacity", 0.1 * _glow)
	# the yard
	_beam_pivot.rotation = Vector3(-0.1, 0.95 + 0.45 * sin(_time * 0.22), 0.0)
	for B: Array in _beacons:
		var on := 1.0 if sin(_time * 2.4 + float(B[2])) > 0.2 else 0.08
		(B[0] as ShaderMaterial).set_shader_parameter(&"opacity", on)
		(B[1] as MeshInstance3D).visible = on > 0.5
	for m: Array in _mist:
		var s: MeshInstance3D = m[0]
		s.position.x += float(m[1]) * dt
		if s.position.x > 12.0:
			s.position.x = -16.0
	for i in _rains.size():
		_rains[i].set_shader_parameter(&"u_time", _time)
		_rains[i].set_shader_parameter(&"opacity", _rain_base[i] + f * 0.45)
	_rain_on_prog(dt, f)
	# Prog breathing; the camera drifts a little with the mouse and a slow handheld sway
	_breathe(_time)
	var vs := get_viewport_rect().size
	var mp := get_viewport().get_mouse_position()
	var mouse_x := clampf(mp.x / maxf(vs.x, 1.0) - 0.5, -0.5, 0.5)      # (the JS only hears the pointer inside the window)
	var mouse_y := clampf(mp.y / maxf(vs.y, 1.0) - 0.5, -0.5, 0.5)
	if Peek.enabled:      # (tests drive an off-screen window: its pointer is wherever the user's is)
		mouse_x = 0.0
		mouse_y = 0.0
	_mx += (mouse_x - _mx) * minf(1.0, dt * 2.0)
	_my += (mouse_y - _my) * minf(1.0, dt * 2.0)
	var cp := _cam_base + Vector3(-_mx * 0.12 + sin(_time * 0.31) * 0.012, _my * 0.05 + sin(_time * 0.47) * 0.008, 0.0)
	var cl := _look_base + Vector3(-_mx * 0.05, 0.0, 0.0)
	_cam.look_at_from_position(cp, cl)
	# sound
	if _rain_t >= 0.0:
		_rain_t += dt
		_rain.volume_db = linear_to_db(0.0001 * pow(0.7 / 0.0001, minf(_rain_t / 2.5, 1.0)))
	for i in range(_pending.size() - 1, -1, -1):
		var e: Array = _pending[i]
		e[0] = float(e[0]) - dt
		if float(e[0]) <= 0.0:
			_pending.remove_at(i)
			_panner.pan = e[3]
			var pl := _thunder[0] if not _thunder[0].playing else _thunder[1]
			pl.stream = e[1]
			pl.volume_db = linear_to_db(float(e[2]) * 2.0)      # (baked at half level: the voices pass full scale, as in the JS)
			pl.play()


## when the game starts: the picture goes at once, the rain fades, the rest follows.
func dispose() -> void:
	state = &"idle"
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _rect != null:
		_rect.visible = false
	_pending.clear()
	if _rain != null and _rain.playing:
		var tw := create_tween()
		tw.tween_property(_rain, "volume_db", -60.0, 0.5)
		tw.tween_callback(queue_free)
	else:
		queue_free()
