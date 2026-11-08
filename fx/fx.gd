class_name FX
extends Node3D
## Everything combat looks like (JS class FX, index.html): tracers, sparks, smoke, brass, blood, explosions, rings, damage numbers, bolts, rockets, camera shake; and it turns combat and player events into sound.
## Pools only: every particle is one instance of a MultiMesh written once at spawn, and its whole life is computed in the vertex shader from the spawn values (fx/part*.gdshader), so a fight's hundreds of sparks cost no script per frame.
## ENGINE DIFFERENCE: the JS integrates particles on the CPU; the shaders use the closed form of the same motion. Blood droplets predict their landing once at spawn instead of testing the floor every frame.

const PART_ADD := preload("res://fx/part_add.gdshader")
const PART_MIX := preload("res://fx/part_mix.gdshader")
const PART_SOLID := preload("res://fx/part_solid.gdshader")
const TRACER := preload("res://fx/tracer.gdshader")
const BOOM_FRONT := preload("res://fx/boom_front.gdshader")
const BOOM_DOUBLE := preload("res://fx/boom_double.gdshader")
const BLOOD_DROP := preload("res://fx/blood_drop.gdshader")
const BLOOD_DECAL := preload("res://fx/blood_decal.gdshader")
const PLAIN_ADD := preload("res://fx/plain_add.gdshader")

const BLOOD_ON := true
const BLOOD_POOL := 110         # floor splats, the oldest is reused
const BLOOD_MAX_DROPS := 320
const BLOOD_LIFE := 14.0
const BLOOD_FADE := 5.0
const NOFLASH := {"saw": 1, "yoke": 1, "arc": 1, "bellows": 1}     # no muzzle flash / brass for the disc launcher and the gravity sling
const GAD_EV := {"saw_bounce": 1, "saw_slice": 1, "saw_clang": 1, "saw_return": 1, "saw_catch": 1, "saw_lost": 1, "yoke_start": 1, "yoke_fizzle": 1, "yoke_launch": 1, "yoke_impact": 1, "bellows_blast": 1, "well_start": 1, "well_end": 1, "arc_start": 1, "arc_stop": 1, "arc_burnout": 1, "arc_zap": 1, "flail_swing": 1, "flail_impact": 1}
const SHOT_HEAVY := {"deagle": 1.2, "shotgun": 1.7, "rifle": 0.9, "smg": 0.6, "rocket": 2.0, "sniper": 1.7, "dual_silenced": 0.3, "legacy_deagle": 1.2, "legacy_rifle": 0.9, "legacy_rocket": 2.0, "legacy_sniper": 1.7}
const SHOT_SHAKE := {"deagle": 0.35, "shotgun": 0.6, "rifle": 0.14, "smg": 0.08, "rocket": 0.7, "dual_silenced": 0.03, "legacy_deagle": 0.35, "legacy_rifle": 0.14, "legacy_rocket": 0.7}
const SHOT_PUFFS := {"deagle": 3, "shotgun": 6, "rifle": 1, "smg": 1, "rocket": 4, "sniper": 3, "legacy_deagle": 3, "legacy_rocket": 4, "legacy_sniper": 3}
const EQUIP_HEAVY: Array[float] = [0.2, 0.7, 0.5, 0.3, 1.0, 0.7, 0.4, 0.8, 0.5, 0.9]

## A particle pool: one MultiMesh used as a ring. Nothing is read back: a slot's shader knows from `now` whether it is alive.
class PartPool:
	var mm: MultiMesh
	var node: MultiMeshInstance3D
	var mat: ShaderMaterial
	var cap := 0
	var head := 0
	var last_end := -1.0        # when the newest life ends: after that the pool is hidden and costs no draw call

	func _init(parent: Node3D, mesh: Mesh, shader: Shader, count: int, custom: bool, pname: String) -> void:
		cap = count
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = custom
		mm.mesh = mesh
		mm.instance_count = count
		mm.custom_aabb = AABB(Vector3(-20000, -20000, -20000), Vector3(40000, 40000, 40000))    # never culled; a dead slot is a point
		mat = ShaderMaterial.new()
		mat.shader = shader
		node = MultiMeshInstance3D.new()
		node.name = pname
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(node)

	func next() -> int:
		var i := head
		head = i + 1
		if head >= cap:
			head = 0
		return i


## A CPU-written instance list: the few things that move every frame (bolts, rockets, gadgets). begin() / add() / finish().
class InstList:
	var mm: MultiMesh
	var node: MultiMeshInstance3D
	var n := 0

	func _init(parent: Node3D, mesh: Mesh, material: Material, count: int, pname: String, custom: bool = false) -> void:
		mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = custom
		mm.mesh = mesh
		mm.instance_count = count
		mm.visible_instance_count = 0
		mm.custom_aabb = AABB(Vector3(-20000, -20000, -20000), Vector3(40000, 40000, 40000))
		node = MultiMeshInstance3D.new()
		node.name = pname
		node.multimesh = mm
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		node.visible = false
		parent.add_child(node)

	func add(xf: Transform3D, col: Color) -> void:
		if n >= mm.instance_count:
			return
		mm.set_instance_transform(n, xf)
		mm.set_instance_color(n, col)
		n += 1

	func add_custom(xf: Transform3D, col: Color, c: Color) -> void:
		if n >= mm.instance_count:
			return
		mm.set_instance_transform(n, xf)
		mm.set_instance_color(n, col)
		mm.set_instance_custom_data(n, c)
		n += 1

	func finish() -> void:
		mm.visible_instance_count = n
		node.visible = n > 0
		n = 0


## One flying armory projectile (JS armFx entry): straight from muzzle to the shot's end point.
class ArmFx:
	var kind := 0               # 0 jawbreaker ball, 1 gnat, 2 needle
	var from := Vector3.ZERO
	var to := Vector3.ZERO
	var t := 0.0
	var dur := 0.1
	var col := Color.WHITE
	var wob_f := 0.0
	var wob_p := 0.0
	var wob_a := 0.0

var shake := 0.0                # read by the camera
var vertical_shake := 0.0
var vertical_shake_t := 0.0
var vertical_shake_y := 0.0     # read by the camera
var world: World = null
var last_player: Player = null
var gad: Gadgets = null         # the arena gadgets
var scope_wv: Variant = null    # while an AI clone's events play: his gun
var bots: Array = []            # enemy views (JS fx.bots): RobotView and friends
var bot_by_id := {}
var creature_audio: CreatureAudio = null
var timers: Array = []          # [seconds left, Callable]
var light: OmniLight3D          # the shared flash
var light_t := 0.0
var stats_on := false           # tests: count the events handled
var stats := {}

var _t := 0.0                   # the FX clock: stands still while the simulation is frozen, like the JS update it replaces
var _pools: Array[PartPool] = []
var _p_spark: PartPool
var _p_fire: PartPool
var _p_smoke: PartPool
var _p_steam: PartPool
var _p_brass: PartPool
var _p_shell: PartPool
var _p_mag: PartPool
var _p_tracer: PartPool
var _b_core: PartPool
var _b_fire: PartPool
var _b_ring: PartPool
var _b_slam: PartPool
var _b_ping: PartPool
var _b_wave: PartPool
var _p_drop: PartPool
var _decals: Array[PartPool] = []
var _decal_next := 0
var _drop_end := PackedFloat32Array()   # when each droplet slot's life ends (JS maxDrops: a spray stops when the pool is full)
var _drop_head := 0
var _landing: Array = []        # droplets that leave a small splat where they land: [time, x, y, z, s]
var _colors := {}
var _c_tracer: Color
var _c_spark: Color
var _c_smoke: Color
var _c_fire: Color
var _c_core: Color
var _c_steam: Color
var _c_brass: Color
var _c_shell: Color
var _c_mag: Color
var _c_blood: Color
var _c_ichor: Color
var _c_ring: Color
var _c_slam: Color
var _c_mind: Color
var _c_wave: Color
var _bolt_box: InstList
var _bolt_orb: InstList
var _bolt_ring: InstList
var _bolt_dart: InstList
var _rk_body: InstList
var _rk_flame: InstList
var _arm: Array[ArmFx] = []
var _arm_ball: InstList
var _arm_body: InstList
var _arm_wing: InstList
var _arm_needle: InstList
var _shield_fx_burst := 0.0
var _shield_fx_acc := 0.0
var _shield_fx_hex := 0x4db8ff
var _stun: Node3D = null
var _stun_stars: InstList = null
var _stun_t := 0.0
var _stun_p: Player = null
var _nums: Array = []           # live damage numbers: [Label, world pos, t, dx]
var _num_free: Array[Label] = []
var _num_layer: Control = null
var _num_plain: LabelSettings
var _num_kill: LabelSettings
var _crates: Array = []
var _drop_views := {}           # Combat.Drop -> [node, spin node, ring opacity, ring scale]
var _drop_rings: InstList
var _crate_mesh: ArrayMesh = null
var _crate_mat: StandardMaterial3D = null
var _last_prog_hurt := ""
var _warm_frames := 3           # every pool is drawn for the first frames so its pipeline exists before the first shot


func _ready() -> void:
	name = "FX"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c_tracer = _c(0xffe9a8)
	_c_spark = _c(0xffc15a)
	_c_smoke = _c(0x3a3a40)
	_c_fire = _c(0xff9a2e)
	_c_core = _c(0xfff0b0)
	_c_steam = _c(0xd4dce2)
	_c_brass = _c(0xd9a93a)
	_c_shell = _c(0xb8322a)
	_c_mag = _c(0x1b1d22)
	_c_blood = _c(0x8c0a0e)
	_c_ichor = _c(0x74d84c)
	_c_ring = _c(0xffd9a0)
	_c_slam = _c(0xcfd8e4)
	_c_mind = _c(0xb455ff)
	_c_wave = _c(0xffd9a0)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_p_spark = _pool(box, PART_ADD, 1024, false, "fx sparks")
	_p_fire = _pool(box, PART_ADD, 512, false, "fx fire")
	_p_smoke = _pool(box, PART_MIX, 512, false, "fx smoke")
	_p_steam = _pool(box, PART_MIX, 512, false, "fx steam")
	var cas := CylinderMesh.new()
	cas.top_radius = 0.008
	cas.bottom_radius = 0.008
	cas.height = 0.035
	cas.radial_segments = 5
	cas.rings = 1
	var shell := CylinderMesh.new()
	shell.top_radius = 0.014
	shell.bottom_radius = 0.014
	shell.height = 0.06
	shell.radial_segments = 6
	shell.rings = 1
	var mag := BoxMesh.new()
	mag.size = Vector3(0.04, 0.13, 0.055)
	_p_brass = _pool(cas, PART_SOLID, 128, true, "fx brass")
	_p_shell = _pool(shell, PART_SOLID, 64, true, "fx shells")
	_p_mag = _pool(mag, PART_SOLID, 32, true, "fx mags")
	_p_tracer = _pool(box, TRACER, 512, true, "fx tracers")
	var ball := FxMesh.icosahedron(1.0, 1)
	_b_core = _pool(ball, BOOM_FRONT, 32, true, "fx blast core")
	_b_fire = _pool(ball, BOOM_FRONT, 32, true, "fx blast fire")
	_b_ring = _pool(FxMesh.ring(0.85, 1.0, 24), BOOM_FRONT, 96, true, "fx ring")
	_b_slam = _pool(FxMesh.ring(0.8, 1.0, 32), BOOM_FRONT, 16, true, "fx slam")
	_b_ping = _pool(FxMesh.ring(0.97, 1.0, 48), BOOM_DOUBLE, 32, true, "fx ping")
	_b_wave = _pool(FxMesh.ring(0.9, 1.0, 40), BOOM_DOUBLE, 16, true, "fx wave")
	_p_drop = _pool(box, BLOOD_DROP, BLOOD_MAX_DROPS, false, "fx blood drops")
	_drop_end.resize(BLOOD_MAX_DROPS)
	_drop_end.fill(-1.0)
	# floor splats: three textures (the JS canvases, assets/fx/blood_*.png), slot i uses texture i % 3
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	for i in 3:
		var pl := _pool(plane, BLOOD_DECAL, ceili(BLOOD_POOL / 3.0), true, "fx blood splats")
		var tex := load("res://assets/fx/blood_%d.png" % i) as Texture2D
		pl.mat.set_shader_parameter(&"tex", tex)
		pl.mat.set_shader_parameter(&"fade", BLOOD_FADE)
		_decals.append(pl)
	# bolts in flight, written every frame
	var add_mat := ShaderMaterial.new()
	add_mat.shader = PLAIN_ADD
	_bolt_box = InstList.new(self, box, add_mat, 128, "fx bolts")
	var orb := SphereMesh.new()
	orb.radius = 1.0
	orb.height = 2.0
	orb.radial_segments = 14
	orb.rings = 10
	_bolt_orb = InstList.new(self, orb, add_mat, 32, "fx bolt orbs")
	_bolt_ring = InstList.new(self, FxMesh.torus_z(0.5, 0.025, 6, 24), add_mat, 64, "fx bolt rings")
	var dart_mat := StandardMaterial3D.new()
	dart_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dart_mat.vertex_color_use_as_albedo = true
	_bolt_dart = InstList.new(self, FxMesh.cone_z(0.07, 0.6, 6, 0.0), dart_mat, 32, "fx bolt darts")
	# rockets: the model with baked vertex colours and its flame
	var rk_mat := StandardMaterial3D.new()
	rk_mat.vertex_color_use_as_albedo = true
	rk_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	rk_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	rk_mat.roughness = 1.0
	_rk_body = InstList.new(self, FxMesh.rocket_body(_c(0xf1f1ec), _c(0xc8272a), _c(0x2f58c8)), rk_mat, 16, "fx rockets")
	_rk_flame = InstList.new(self, FxMesh.rocket_flame(_c(0xff9a2e), _c(0xfff2b0), 0.95), add_mat, 16, "fx rocket flames")
	# armory projectiles
	var ball_mat := StandardMaterial3D.new()
	ball_mat.vertex_color_use_as_albedo = true
	ball_mat.metallic = 0.55
	ball_mat.roughness = 0.18
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	sph.radial_segments = 16
	sph.rings = 12
	_arm_ball = InstList.new(self, sph, ball_mat, 16, "fx jawbreakers")
	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color8(0xd8, 0xa6, 0x4a)
	brass_mat.metallic = 0.55
	brass_mat.roughness = 0.32
	var body := SphereMesh.new()
	body.radius = 0.012
	body.height = 0.024
	body.radial_segments = 6
	body.rings = 5
	_arm_body = InstList.new(self, body, brass_mat, 32, "fx gnats")
	var wing_mat := StandardMaterial3D.new()
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.albedo_color = Color(_c(0xbff6ff), 0.55)
	wing_mat.no_depth_test = false
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wing := PlaneMesh.new()
	wing.size = Vector2(0.03, 0.012)
	wing.orientation = PlaneMesh.FACE_Z
	_arm_wing = InstList.new(self, wing, wing_mat, 64, "fx gnat wings")
	_arm_needle = InstList.new(self, FxMesh.cone_z(0.011, 0.34, 6, 0.0), add_mat, 8, "fx needles")
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.vertex_color_use_as_albedo = true
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop_rings = InstList.new(self, FxMesh.ring(0.44, 0.475, 48), ring_mat, 64, "fx drop rings")
	light = OmniLight3D.new()
	light.name = "fx flash"
	light.light_color = _c_srgb(0xff9040)
	light.omni_range = 30.0
	light.omni_attenuation = 2.0
	light.light_energy = 0.0
	light.visible = false
	add_child(light)
	# damage numbers (the JS #dmg host): a Label pool under the UI layer, made once
	_num_plain = LabelSettings.new()
	_num_plain.font_size = 22
	_num_plain.font_color = Color.WHITE
	_num_plain.outline_size = 3
	_num_plain.outline_color = Color(0, 0, 0, 0.8)
	_num_plain.shadow_size = 0
	_num_plain.shadow_color = Color.BLACK
	_num_plain.shadow_offset = Vector2(0, 2)
	_num_kill = _num_plain.duplicate() as LabelSettings
	_num_kill.font_size = 28
	_num_kill.font_color = Color8(0xff, 0x6a, 0x4a)
	gad = Gadgets.new(self)
	add_child(gad)


func _pool(mesh: Mesh, shader: Shader, count: int, custom: bool, pname: String) -> PartPool:
	var p := PartPool.new(self, mesh, shader, count, custom, pname)
	_pools.append(p)
	return p


## 0xRRGGBB, as linear colour (three.js converts hex colours to its linear working space the same way). Cached: colours repeat.
func _c(hex: int) -> Color:
	var c: Variant = _colors.get(hex)
	if c != null:
		return c
	var col := Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255).srgb_to_linear()
	_colors[hex] = col
	return col


func _c_srgb(hex: int) -> Color:
	return Color8((hex >> 16) & 255, (hex >> 8) & 255, hex & 255)


func _spawn(pl: PartPool, pos: Vector3, vel: Vector3, life: float, scale_: float, grow: float, grav: float, col: Color, half_k: float = 1.0) -> void:
	var i := pl.next()
	pl.mm.set_instance_transform(i, Transform3D(Basis(vel, Vector3(_t, life, scale_), Vector3(grow, grav, 0.0)), pos))
	pl.mm.set_instance_color(i, Color(col.r, col.g, col.b, half_k))
	if _t + life > pl.last_end:
		pl.last_end = _t + life
		if not pl.node.visible:
			pl.node.visible = true


func _spawn_solid(pl: PartPool, pos: Vector3, vel: Vector3, life: float, scale_: float, grav: float, col: Color, spin: Vector3, rot: Vector3) -> void:
	var i := pl.next()
	pl.mm.set_instance_transform(i, Transform3D(Basis(vel, Vector3(_t, life, scale_), Vector3(grav, rot.x, rot.y)), pos))
	pl.mm.set_instance_color(i, col)
	pl.mm.set_instance_custom_data(i, Color(spin.x, spin.y, spin.z, rot.z))
	if _t + life > pl.last_end:
		pl.last_end = _t + life
		if not pl.node.visible:
			pl.node.visible = true


func _smoke(pos: Vector3, vel: Vector3, life: float, scale_: float, grow: float, grav: float) -> void:
	_spawn(_p_smoke, pos, vel, life, scale_, grow, grav, _c_smoke, 0.5)       # smoke draws at half strength


func _fire(pos: Vector3, vel: Vector3, life: float, scale_: float, grow: float, grav: float) -> void:
	_spawn(_p_fire, pos, vel, life, scale_, grow, grav, _c_fire)


func _steam(pos: Vector3, vel: Vector3, life: float, scale_: float, grow: float, grav: float) -> void:
	_spawn(_p_steam, pos, vel, life, scale_, grow, grav, _c_steam)


## JS sparks(p, n, speed, normal, color)
func sparks(p: Vector3, n: int, speed: float, normal: Variant = null, color: int = -1) -> void:
	var col := _c_spark if color < 0 else _c(color)
	var has_n := normal != null
	var nv: Vector3 = normal if has_n else Vector3.ZERO
	for i in n:
		var v := Vector3(randf() - 0.5, randf() - 0.1, randf() - 0.5).normalized() * (speed * (0.4 + randf()))
		if has_n:
			v += nv * (speed * 0.6)
		_spawn(_p_spark, p, v, 0.28 + randf() * 0.25, 0.035 + randf() * 0.03, -0.1, 14.0, col)


## JS tracer(a, b, w, life, col)
func tracer(a: Vector3, b: Vector3, w: float = 0.025, life: float = 0.07, col: int = -1) -> void:
	var d := b - a
	var len_ := d.length()
	if len_ < 1e-5:
		return
	var z := d / len_
	var up := Vector3.UP if absf(z.y) < 0.999 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	var i := _p_tracer.next()
	_p_tracer.mm.set_instance_transform(i, Transform3D(Basis(x * w, y * w, z * len_), a + d * 0.5))
	_p_tracer.mm.set_instance_color(i, _c_tracer if col < 0 else _c(col))
	_p_tracer.mm.set_instance_custom_data(i, Color(_t, life, 0.0, 0.0))
	if _t + life > _p_tracer.last_end:
		_p_tracer.last_end = _t + life
		_p_tracer.node.visible = true


## JS dust(p, n, spread)
func dust(p: Vector3, n: int, spread: float) -> void:
	for i in n:
		var a := randf() * 6.283
		_smoke(p, Vector3(cos(a) * spread * (0.6 + randf()), 0.3 + randf() * 0.5, sin(a) * spread * (0.6 + randf())), 0.45 + randf() * 0.4, 0.18 + randf() * 0.14, 1.3, -0.4)


func _boom(pl: PartPool, pos: Vector3, r: float, dur: float, mode: int, col: Color, op: float) -> void:
	var i := pl.next()
	pl.mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
	pl.mm.set_instance_color(i, Color(col.r, col.g, col.b, op))
	pl.mm.set_instance_custom_data(i, Color(_t, r, dur, float(mode)))
	var e := _t + (dur if mode >= 3 else 0.55)
	if e > pl.last_end:
		pl.last_end = e
		pl.node.visible = true


## JS ripple: a ring spreading on the water (slows as it grows, like a real ripple)
func ripple(x: float, y: float, z: float, r: float, dur: float, op: float = 0.3) -> void:
	_boom(_b_ring, Vector3(x, y + 0.05, z), r, dur, 4, _c_slam, op)


## JS swimFx: the player in the water (Player events): the splash going in (splash_k: how hard), a kick, the rings and flicks of spray off each stroke, the slow rings treading water.
func swim_fx(e: StringName, P: Player, sfx: Sfx) -> void:
	var y: float = P.swim_s if P.swim_s != null else P.y
	var sy := sin(P.yaw)
	var cy := cos(P.yaw)
	if e == &"splash":
		var k: float = P.splash_k if P.splash_k != 0.0 else 0.5
		_spray(roundi(10.0 + 30.0 * k), P.x, P.z, y, 2.6 + 6.5 * k, 0.7 + 1.6 * k, 0.55 + 0.5 * k)
		var cnt := 3.0 + 5.0 * k
		var i := 0.0
		while i < cnt:
			var a := randf() * TAU
			_steam(Vector3(P.x + cos(a) * 0.5, y + 0.1, P.z + sin(a) * 0.5), Vector3(cos(a) * 0.8, 1.0 + 2.5 * k * randf(), sin(a) * 0.8), 0.6 + 0.4 * k, 0.14 + 0.16 * k, 1.2, 3.0)
			i += 1.0
		var px: float = P.x
		var pz: float = P.z
		ripple(px, y, pz, 1.6 + 2.8 * k, 1.0, 0.32)
		timers.append([0.22, ripple.bind(px, y, pz, 1.1 + 2.0 * k, 1.5, 0.22)])
		if k > 0.6:
			shake = maxf(shake, 0.15 * k)
		sfx.play("splash", {"k": k})
	elif e == &"swim_hop":
		_spray(8, P.x, P.z, y, 2.5, 0.8, 0.45)
		ripple(P.x, y, P.z, 1.5, 0.9, 0.2)
		sfx.play("splash", {"k": 0.15})
	elif e == &"stroke":
		var side := 1.0 if floorf(P.swim_ph * 2.0) != 0.0 else -1.0
		var hx: float = P.x + sy * 0.75 - cy * 0.28 * side     # where the hand goes in
		var hz: float = P.z + cy * 0.75 + sy * 0.28 * side
		_spray(5 if P.sprinting else 3, hx, hz, y, 1.6, 0.5, 0.35)
		ripple(hx, y, hz, 1.0, 0.9, 0.16)                      # the hand's ring, and the wake the body leaves
		ripple(P.x - sy * 0.6, y, P.z - cy * 0.6, 1.4, 1.3, 0.1)
		sfx.play("stroke", {"k": 1.0 if P.sprinting else 0.7})
	elif e == &"tread":
		ripple(P.x, y, P.z, 1.7, 1.8, 0.14)


func _spray(n: int, x: float, z: float, y: float, up: float, out: float, life: float) -> void:
	for i in n:
		var a := randf() * TAU
		var o := out * (0.4 + randf())
		_steam(Vector3(x, y + 0.05, z), Vector3(cos(a) * o, up * (0.45 + randf() * 0.55), sin(a) * o), life * (0.6 + randf() * 0.5), 0.045 + randf() * 0.06, -0.3, 13.0)


## JS slamFx
func slam_fx(p: Vector3, R: float) -> void:
	dust(p, 18, 4.5)
	sparks(Vector3(p.x, p.y + 0.1, p.z), 16, 5.0)
	_boom(_b_slam, p + Vector3(0, 0.06, 0), R / 1.15, 0.55, 2, _c_slam, 1.0)
	shake = maxf(shake, 1.0)


## JS explosion(p, r)
func explosion(p: Vector3, r: float) -> void:
	_boom(_b_core, p, r, 0.55, 0, _c_core, 1.0)
	_boom(_b_fire, p, r, 0.55, 1, _c_fire, 1.0)
	_boom(_b_ring, p, r, 0.55, 2, _c_ring, 1.0)
	for i in 22:
		var v := Vector3(randf() - 0.5, randf() * 0.9 + 0.1, randf() - 0.5).normalized() * (5.0 + randf() * 9.0)
		_spawn(_p_spark, p, v, 0.5 + randf() * 0.6, 0.07 + randf() * 0.07, -0.05, 16.0, _c_spark)
	for i in 12:
		var v := Vector3(randf() - 0.5, randf() * 0.6 + 0.2, randf() - 0.5).normalized() * (2.0 + randf() * 3.0)
		_smoke(p, v, 1.0 + randf() * 0.9, 0.5 + randf() * 0.4, 1.4, -0.5)
	light.position = p + Vector3(0, 1, 0)
	light_t = 0.4
	shake = maxf(shake, 1.0)


## JS number(p, amount, kill): a damage number that floats up and fades.
func number(p: Vector3, amount: Variant, kill: bool) -> void:
	if _num_layer == null:
		if Game.ui_root == null:
			return
		_num_layer = Control.new()
		_num_layer.name = "dmg"
		_num_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_num_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		Game.ui_root.add_child(_num_layer)
	var l: Label = _num_free.pop_back() if not _num_free.is_empty() else null
	if l == null:
		l = Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_num_layer.add_child(l)
	l.label_settings = _num_kill if kill else _num_plain
	l.text = str(amount)
	l.visible = true
	l.modulate.a = 1.0
	l.reset_size()
	l.pivot_offset = l.size * 0.5
	_nums.append([l, p, 0.0, (randf() - 0.5) * 40.0])


# ---------------------------------------------------------------- brass, magazines, muzzle smoke, armory projectiles ----------------------------------------------------------------

func _wv() -> Variant:
	if scope_wv != null:
		return scope_wv
	var an = Game.animator
	return an.wv if an != null else null


## JS casing: ejected brass / shotgun shell, flung out of the weapon's ejection port.
func casing(wv: Variant, P: Player, id: String) -> void:
	var info = wv.info if wv != null else null
	if info == null or info.eject == null:
		return
	var g: Node3D = wv.group
	var pos: Vector3 = g.global_transform * (info.eject as Vector3)
	var yaw: float = P.yaw
	var sp := 1.7 + randf() * 1.3
	var v := Vector3(-cos(yaw) * sp + sin(yaw) * (randf() - 0.6), 1.8 + randf() * 1.4, sin(yaw) * sp + cos(yaw) * (randf() - 0.6))
	var big := id == "shotgun"
	var spin := Vector3(randf() * 20.0 - 10.0, randf() * 20.0 - 10.0, randf() * 20.0 - 10.0)
	_spawn_solid(_p_shell if big else _p_brass, pos, v, 1.0, 1.7 if (id == "sniper" or id == "legacy_sniper") else 1.0, 15.0, _c_shell if big else _c_brass, spin, Vector3(randf() * 3.0, randf() * 3.0, randf() * 3.0))


## JS magDrop: the spent magazine tumbles to the floor.
func mag_drop(wv: Variant, P: Player, id: String) -> void:
	var info = wv.info if wv != null else null
	if info == null or info.mag == null:
		return
	var g: Node3D = wv.group
	var pos: Vector3 = g.global_transform * (info.mag.grab as Vector3)
	var yaw: float = P.yaw
	var sc := 0.8 if id == "deagle" else 1.25 if id == "rifle" else 1.35 if id == "smg" else 1.0
	var col := 0x9fe8f5 if id == "smg" else 0x7e2fc4 if id == "sniper" else 0x2a2c33 if id == "rifle" else 0x1b1d22
	_spawn_solid(_p_mag, pos, Vector3(cos(yaw) * 0.6, -0.5, -sin(yaw) * 0.6), 1.1, sc, 17.0, _c(col), Vector3(randf() * 6.0 - 3.0, randf() * 4.0, randf() * 6.0 - 3.0), Vector3.ZERO)


## JS armoryShot: visual-only armory projectiles: the jawbreaker ball, the swarm's gnat, the needle. The hitscan shot still decides hits; these stop at its end point, so they never pass through geometry.
func armory_shot(e: Dictionary, muz: Vector3) -> void:
	var pellets: Array = e.get("pellets", [])
	var hp: Variant = pellets[0] if pellets.size() > 0 else null
	if hp == null:
		return
	var end := Vector3(hp.x, hp.y, hp.z)
	var L := end.distance_to(muz)
	if L < 0.05:
		return
	var id := str(e.get("id", ""))
	var a: ArmFx = null
	if id == "deagle":                                   # one oversized metal jawbreaker, the colour of a ball from the hopper
		a = ArmFx.new()
		a.kind = 0
		a.col = _c([0xd62a24, 0x2b5fe0, 0x2fbf5a, 0xf2c21a][randi() % 4])
		a.dur = minf(0.5, maxf(0.03, L / 100.0))
	elif id == "smg":                                    # a mechanical gnat that buzzes along the shot path (no seeking: it ends at the hit point)
		a = ArmFx.new()
		a.kind = 1
		a.wob_f = 40.0
		a.wob_p = randf() * 6.0
		a.wob_a = 0.05
		a.dur = minf(0.25, maxf(0.03, L / 120.0))
	elif id == "sniper":                                 # thin violet needle (straight; the tracer is its short trail)
		a = ArmFx.new()
		a.kind = 2
		a.dur = minf(0.1, maxf(0.03, L / 700.0))
	if a == null:
		return
	a.from = muz
	a.to = end
	_arm.append(a)


## JS muzzleFx: muzzle smoke, shotgun sparks and the rocket's backblast, all along the real aim direction.
func muzzle_fx(wv: Variant, e: Dictionary, muz: Vector3) -> void:
	var id := str(e.get("id", ""))
	var dir := Vector3(e.dirx, e.diry, e.dirz)
	var puffs: int = SHOT_PUFFS.get(id, 1)
	for i in puffs:
		var v := dir * (0.6 + randf() * 1.2) + Vector3((randf() - 0.5) * 0.5, 0.25 + randf() * 0.3, (randf() - 0.5) * 0.5)
		_smoke(muz + dir * (0.05 + randf() * 0.15), v, 0.6 + randf() * 0.5, 0.06 + randf() * 0.05, 2.4, -0.15)
	if id == "shotgun":
		sparks(muz, 7, 5.0, dir)
	if id == "rocket" or id == "legacy_rocket":          # backblast: fire and smoke thrown out of the rear venturi
		var back: Vector3 = muz - dir * 0.6
		if wv != null and wv.info != null:
			back = (wv.group as Node3D).global_transform * Vector3(0, 0, -0.6)
		var bd := -dir
		for i in 9:
			_fire(back, bd * (2.0 + randf() * 4.0) + Vector3((randf() - 0.5) * 1.5, (randf() - 0.5) * 1.5, (randf() - 0.5) * 1.5), 0.22 + randf() * 0.15, 0.1 + randf() * 0.1, 1.2, 0.0)
		for i in 7:
			_smoke(back, bd * (1.5 + randf() * 3.0) + Vector3((randf() - 0.5) * 1.2, (randf() - 0.5) * 0.8 + 0.3, (randf() - 0.5) * 1.2), 0.8 + randf() * 0.6, 0.12 + randf() * 0.1, 2.8, -0.1)


# ---------------------------------------------------------------- blood ----------------------------------------------------------------
# small droplets that fly, fall and leave a flat splat on the floor (not on robots, which spark instead). The splats come from a fixed pool (the oldest is reused when it runs out) and each fades away after its life, so it never piles up.

func _gy(x: float, z: float, y: float) -> float:
	if world == null:
		return 0.0
	var g := world.ground_height(x, z, 0.05, y + 0.5)
	return maxf(0.0, g) if (is_finite(g) and g > -50.0) else 0.0


func _blood_splat(x: float, gy: float, z: float, size: float, life: float) -> void:
	var slot := _decal_next
	_decal_next = (_decal_next + 1) % BLOOD_POOL
	var pl := _decals[slot % 3]
	var i := slot / 3
	var yaw := randf() * 6.283
	pl.mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(x, gy + 0.012 + (_decal_next % 5) * 0.0015, z)))
	pl.mm.set_instance_color(i, Color.WHITE)
	pl.mm.set_instance_custom_data(i, Color(_t, life, size, 0.0))
	if _t + life > pl.last_end:
		pl.last_end = _t + life
		pl.node.visible = true


## JS _bloodSpray: n droplets from p, mostly thrown along (ux, uz) = away from whoever hit. Each droplet's landing is found once here (the JS tests the floor per frame): gravity 13, life 1.6 s.
func _blood_spray(p: Vector3, ux: float, uz: float, n: int, speed: float, green: bool = false) -> void:
	var col := _c_ichor if green else _c_blood
	var g0 := _gy(p.x, p.z, p.y)
	for i in n:
		if _drop_end[_drop_head] > _t:                  # BLOOD.maxDrops: the pool is full, this spray ends here
			break
		var fine := i % 3 == 0
		var s := 0.014 + randf() * 0.012 if fine else 0.03 + randf() * 0.035
		var k := speed * (0.8 + randf() * 0.9 if fine else 0.35 + randf() * 0.9)
		var vx := ux * k * 0.7 + (randf() - 0.5) * k * 0.8
		var vy := 1.2 + randf() * 2.4
		var vz := uz * k * 0.7 + (randf() - 0.5) * k * 0.8
		# landing: where the fall crosses the floor under the flight path. Only below y0 + 0.4, as the JS test.
		var life := 1.6
		var lands := false
		var gy := g0
		var disc := vy * vy + 26.0 * (p.y - gy - 0.02)
		if disc > 0.0:
			var tl := (vy + sqrt(disc)) / 13.0
			if tl < 1.6:
				lands = true
				life = tl
		var will_splat := lands and not green and s > 0.02 and randf() < 0.6
		if will_splat:                                   # (a second look at the floor where it really comes down, for the splat's height)
			var lx := p.x + vx * life
			var lz := p.z + vz * life
			gy = _gy(lx, lz, p.y)
			_landing.append([_t + life, lx, gy, lz, s])
		var j := _drop_head
		_drop_head = (j + 1) % BLOOD_MAX_DROPS
		_drop_end[j] = _t + life
		_p_drop.mm.set_instance_transform(j, Transform3D(Basis(Vector3(vx, vy, vz), Vector3(_t, life, s), Vector3.ZERO), p))
		_p_drop.mm.set_instance_color(j, col)
		if _t + life > _p_drop.last_end:
			_p_drop.last_end = _t + life
			_p_drop.node.visible = true


## JS bloodHit
func blood_hit(e: Dictionary, kill: bool) -> void:
	if not BLOOD_ON or e.get("robot", false):
		return
	var ex: float = e.x
	var ey: float = e.y
	var ez: float = e.z
	var ux: float = e.get("ux", 0.0)
	var uz: float = e.get("uz", 0.0)
	_blood_spray(Vector3(ex, ey, ez), ux, uz, 55 if kill else 22, 5.2 if kill else 3.8)
	var gy: float = e.gy if e.has("gy") and e.gy != null else _gy(ex, ez, ey - 1.2)
	if kill:
		_blood_splat(ex, gy, ez, 1.0 + randf() * 0.5, BLOOD_LIFE)
	elif randf() < 0.8:
		_blood_splat(ex + ux * 0.6, gy, ez + uz * 0.6, 0.18 + randf() * 0.16, BLOOD_LIFE * 0.7)


## JS bloodPlayer
func blood_player(e: Dictionary, P: Variant) -> void:
	if not BLOOD_ON or P == null:
		return
	var kill: bool = e.get("kill", false)
	_blood_spray(Vector3(P.x, P.y + 1.2, P.z), -float(e.get("dx", 0.0)), -float(e.get("dz", 0.0)), 40 if kill else 14, 4.6 if kill else 3.2)
	if kill:
		_blood_splat(P.x, P.y, P.z, 1.0 + randf() * 0.4, BLOOD_LIFE)


## green alien ichor: droplets only (no red floor decals)
func ichor(p: Vector3, n: int, ux: float, uz: float) -> void:
	if BLOOD_ON:
		_blood_spray(p, ux, uz, n, 3.8, true)


## JS sauceSplat: a sauce glob splats: red droplets, a floor decal when it hit the world
func sauce_splat(e: Dictionary) -> void:
	if not BLOOD_ON:
		return
	_blood_spray(Vector3(e.x, e.y, e.z), float(e.get("nx", 0.0)), float(e.get("nz", 0.0)), 16 if str(e.get("kind", "")) == "player" else 10, 3.2)
	if str(e.get("kind", "")) == "world":
		_blood_splat(e.x, _gy(e.x, e.z, e.y), e.z, 0.35 + randf() * 0.25, BLOOD_LIFE * 0.8)


# ---------------------------------------------------------------- hostile robots: impact / death / bolt / alert / player feedback ----------------------------------------------------------------

## JS robotSound: this robot goes through the bounded robot mixer (enemies/robot-audio.js)?
func robot_sound(cue: String, r: Variant, point: Variant = null) -> bool:
	var ea: RobotAudio = Game.sfx.enemy_audio
	if not ea.handles(r):
		return false
	ea.cue(cue, r, point if point != null else r)
	return true


func _bot_r(id: Variant) -> Variant:
	var b: Variant = bot_by_id.get(id)
	return b.R if b != null else null


func _pt_of(e: Dictionary, dy: float) -> Vector3:
	var pt: Variant = e.get("pt")
	if pt is Vector3:
		return pt
	if pt is Dictionary:
		return Vector3(pt.x, pt.y, pt.z)
	return Vector3(e.x, float(e.y) + dy, e.z)


## JS robotHitFx
func robot_hit_fx(e: Dictionary, sfx: Sfx) -> void:
	var pt := _pt_of(e, 1.3)
	var dx: float = e.get("dx", 0.0)
	var dz: float = e.get("dz", 0.0)
	var n := Vector3(-dx, 0.35, -dz)
	var heavy: bool = e.get("heavy", false)
	if e.get("alien", false):                            # green ichor, a squelch, no metal
		ichor(pt, 22 if heavy else 10, dx, dz)
		sparks(pt, 6 if heavy else 3, 3.0, n, 0x9cff6a)
		sfx.play_at("alienHit", pt.x, pt.y, pt.z, {"heavy": heavy, "range": 55.0})
		return
	if e.get("meat", false):                             # sauce and mince, no metal
		_blood_spray(pt, dx, dz, 6 if e.get("follower", false) else (20 if heavy else 9), 3.6)
		sparks(pt, 6 if heavy else 3, 3.0, n, 0xe0301c)
		sfx.play_at("meatHit", pt.x, pt.y, pt.z, {"heavy": heavy, "range": 55.0})
		return
	if e.get("human", false):                            # the night assassin: blood and a grunt
		_blood_spray(pt, dx, dz, 14 if heavy else 7, 3.2)
		sfx.play_at("humanHit", pt.x, pt.y, pt.z, {"heavy": heavy, "range": 45.0})
		return
	sparks(pt, 16 if heavy else 7, 5.0 if heavy else 3.5, n)
	if heavy:
		_smoke(pt, Vector3(-dx * 0.6, 0.5, -dz * 0.6), 0.7, 0.1, 2.4, -0.15)
	if not robot_sound("hit", _bot_r(e.get("id")), pt):
		sfx.play_at("clang", pt.x, pt.y, pt.z, {"heavy": heavy, "range": 55.0})


## JS robotDieFx
func robot_die_fx(e: Dictionary, sfx: Sfx) -> void:
	var p := Vector3(e.x, float(e.y) + 1.3, e.z)
	var dx: float = e.get("dx", 0.0)
	var dz: float = e.get("dz", 0.0)
	if e.get("meat", false):
		if e.get("follower", false):
			_blood_spray(p, dx, dz, 18, 4.0)
			sparks(p, 6, 3.0, null, 0xe0301c)
			sfx.play_at("meatDie", p.x, p.y, p.z, {"range": 40.0, "small": true})
		elif e.get("worm", false):
			_blood_spray(p, dx, dz, 40, 5.0)
			sparks(p, 14, 4.0, null, 0xa01818)
			shake = maxf(shake, 0.25)
			sfx.play_at("meatDie", p.x, p.y, p.z, {"range": 70.0})
		else:
			sfx.play_at("meatSwell", p.x, p.y, p.z, {"range": 80.0})     # the prophet's burst comes with the meat_boom event
		return
	if e.get("alien", false):
		ichor(p, 46, dx, dz)
		sparks(p, 10, 4.0, null, 0x9cff6a)
		sfx.play_at("alienDie", p.x, p.y, p.z, {"range": 70.0})
		return
	if e.get("human", false):
		_blood_spray(p, dx, dz, 22, 3.6)
		sfx.play_at("humanDie", p.x, p.y, p.z, {"range": 50.0})
		return
	sparks(p, 28, 5.5)
	for i in 6:
		_smoke(p, Vector3((randf() - 0.5) * 1.4, 0.8 + randf(), (randf() - 0.5) * 1.4), 1.0 + randf() * 0.6, 0.14, 2.8, -0.2)
	light_t = maxf(light_t, 0.25)
	light.light_color = _c_srgb(0xffa040)
	light.position = p
	if not robot_sound("death", _bot_r(e.get("id")), p):
		sfx.play_at("robotDie", p.x, p.y, p.z, {"range": 70.0})


## JS mindHitFx
func mind_hit_fx(e: Dictionary, sfx: Sfx, hud: Variant) -> void:
	_hud(hud, &"mind", [e.get("dur", 0.0)])
	sfx.play("mindHit")
	shake = maxf(shake, 0.6)
	sparks(Vector3(e.x, e.y, e.z), 22, 5.0, null, 0xc58bff)
	_boom(_b_ping, Vector3(e.x, float(e.y) - 0.9, e.z), 3.2, 0.7, 3, _c_mind, 0.9)


## JS stunFx: stunned by the night assassin's knife: ringing ears, a hard shake, little stars circling the player's head for the stun's length.
func stun_fx(e: Dictionary, sfx: Sfx, player: Player) -> void:
	if e.get("clone_id") != null:
		return
	sfx.play("stun")
	shake = maxf(shake, 0.55)
	sparks(Vector3(e.x, float(e.y) + 0.6, e.z), 10, 2.5, null, 0xfff0a0)
	if _stun_stars == null:
		var add_mat := ShaderMaterial.new()
		add_mat.shader = PLAIN_ADD
		var octa := FxMesh.octahedron(0.06)
		_stun_stars = InstList.new(self, octa, add_mat, 5, "stun stars")
	_stun_t = maxf(_stun_t, float(e.get("dur", 0.0)))
	_stun_p = player


func _stun_tick(dt: float) -> void:
	if _stun_stars == null or _stun_t <= 0.0:
		return
	var P := _stun_p
	_stun_t -= dt
	if _stun_t <= 0.0 or P == null or P.dead or not P.stun_t > 0.0:
		_stun_t = 0.0
		_stun_stars.finish()
		return
	var t := Time.get_ticks_msec() / 1000.0
	var g_pos := Vector3(P.x, P.y + P.h + 0.18, P.z)
	var g_rot := Basis(Vector3.UP, t * 5.0)
	var col := Color(_c(0xfff08a), 0.95)
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var rot := Basis.from_euler(Vector3(t * 6.0 + i, t * 4.0, 0.0), EULER_ORDER_XYZ) * Basis.from_scale(Vector3(1, 1, 0.45))
		_stun_stars.add(Transform3D(g_rot * rot, g_pos + g_rot * Vector3(sin(a) * 0.32, sin(t * 9.0 + i * 1.7) * 0.04, cos(a) * 0.32)), col)
	_stun_stars.finish()


## JS wormSlamFx: PHONE SLAM: the head hits the floor -- dust ring, debris, sparks, hard shake
func worm_slam_fx(e: Dictionary, sfx: Sfx, player: Player) -> void:
	var p := Vector3(e.x, float(e.y) + 0.15, e.z)
	dust(p, 18, 2.6)
	sparks(p, 26, 7.0, null, 0xb01a14)
	sparks(p, 10, 4.0, null, 0xe0c0a0)
	_blood_spray(p, 0.0, 0.0, 16, 4.5)
	_boom(_b_wave, Vector3(e.x, float(e.y) + 0.08, e.z), float(e.r) * 1.4, 0.7, 3, _c_wave, 0.8)
	shake = maxf(shake, 0.8 if Vector2(float(e.x) - player.x, float(e.z) - player.z).length() < float(e.r) * 2.5 else 0.35)
	sfx.play_at("phoneSlam", e.x, e.y, e.z, {"range": 90.0})


## JS meatBoomFx: the Meatball Prophet bursts: a fireball with a red core, a sauce shower, big floor splats, meat sparks and a hard shake
func meat_boom_fx(e: Dictionary, sfx: Sfx, player: Player) -> void:
	var p := Vector3(e.x, e.y, e.z)
	var r: float = e.r
	explosion(p, r)
	sparks(p, 30, 9.0, null, 0xff3a20)
	sparks(p, 14, 6.0, null, 0xffc060)
	if BLOOD_ON:
		_blood_spray(p, 0.0, 0.0, 110, 8.0)
		for i in 7:
			var a := randf() * 6.283
			var d := randf() * r * 0.85
			_blood_splat(p.x + sin(a) * d, _gy(p.x, p.z, p.y - 1.2), p.z + cos(a) * d, 0.5 + randf() * 0.8, BLOOD_LIFE)
	light.light_color = _c_srgb(0xff4a2a)
	light_t = maxf(light_t, 0.5)
	light.position = p
	shake = maxf(shake, 1.3 if Vector2(p.x - player.x, p.z - player.z).length() < r * 2.0 else 0.6)
	sfx.play_at("meatBoom", p.x, p.y, p.z, {"range": 110.0})


func scream_step(bv: Variant, spd: float) -> void:
	Game.sfx.play_at("skitter", bv.R.x, bv.R.y + 0.1, bv.R.z, {"k": clampf(spd / 5.4, 0.2, 1.0), "range": 28.0})


func alien_step(bv: Variant, spd: float) -> void:
	Game.sfx.play_at("slap", bv.R.x, bv.R.y + 0.1, bv.R.z, {"k": clampf(spd / 7.0, 0.2, 1.0), "range": 24.0})


## JS robotPop: the small internal blow-out half a second into the death
func robot_pop(bv: Variant) -> void:
	var p: Vector3 = bv.spine_world()
	p.y += 0.2
	explosion(p, 1.0)
	sparks(p, 24, 6.0)
	if bv.has_method("on_pop_debris"):
		bv.on_pop_debris()
	if not robot_sound("pop", bv.R, p):
		Game.sfx.play_at("robotPop", p.x, p.y, p.z, {"range": 60.0})
	shake = maxf(shake, 0.12)


func robot_step(bv: Variant, spd: float) -> void:
	if not robot_sound("step", bv.R):
		Game.sfx.play_at("step", bv.R.x, bv.R.y + 0.1, bv.R.z, {"k": clampf(spd / 4.4, 0.2, 1.0), "range": 28.0})


## JS boltVis: glowing bolts in flight. Written every frame: a handful of instances.
func bolt_vis(bolts: Array) -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	for i in bolts.size():
		var q = bolts[i]
		var pos := Vector3(q.x, q.y, q.z)
		var z := Vector3(q.dx, q.dy, q.dz).normalized()
		var up := Vector3.UP if absf(z.y) < 0.999 else Vector3.RIGHT
		var x := up.cross(z).normalized()
		var basis_ := Basis(x, z.cross(x), z)
		var k: String = str(q.kind) if q.kind != null and str(q.kind) != "" else "bolt"
		var mind := k == "mind"
		var glob := k == "sauce" or k == "bile" or k == "ink"
		var ring_k := k == "ring"
		var dart_k := k == "dart"
		var halo_col := _c(0xff3018)
		var halo_s := Vector3(0.14, 0.14, 1.1)
		var core_col := _c(0xfff0c0)
		var core_s := Vector3(0.05, 0.05, 0.7)
		if dart_k:
			var r := Basis.from_euler(Vector3(0.3 * sin(tt * 9.0 + i), 0.0, tt * 14.0 + i), EULER_ORDER_XYZ)
			_bolt_dart.add(Transform3D(basis_ * r, pos), Color(_c(0xe4707a), 1.0))
			core_col = _c(0xffffff)
			core_s = Vector3(0.04, 0.04, 0.25)
		elif ring_k:
			var gr: float = 0.5 + float(q.life) * 1.6
			core_col = _c(0xffc0b0)
			core_s = Vector3(0.12, 0.12, 0.2)
			_bolt_ring.add(Transform3D(basis_ * Basis(Vector3(0, 0, 1), tt * 6.0).scaled(Vector3(gr, gr, gr)), pos), Color(_c(0xff5a48), 0.8))
			_bolt_ring.add(Transform3D(basis_ * Basis(Vector3(0, 0, 1), -tt * 8.0).scaled(Vector3(gr, gr, gr) * 0.65), pos), Color(_c(0xa01828), 0.8))
		elif glob:
			var pu := 1.0 + 0.15 * sin(tt * 22.0 + i * 2.0)
			var orb_c := 0xb8e020 if k == "bile" else 0x1a2a90 if k == "ink" else 0xd0200f
			_bolt_orb.add(Transform3D(basis_.scaled_local(Vector3(0.3 * pu, 0.3 / pu, 0.4 * pu)), pos), Color(_c(orb_c), 0.55))
			core_col = _c(0xf0ff90 if k == "bile" else 0x6080ff if k == "ink" else 0xff9070)
			core_s = Vector3(0.13, 0.13, 0.4)
		elif mind:                                       # purple orb with two counter-spinning rings
			var pu := 1.0 + 0.12 * sin(tt * 18.0 + i)
			_bolt_orb.add(Transform3D(basis_.scaled_local(Vector3.ONE * (0.34 * pu)), pos), Color(_c(0xa23cff), 0.55))
			core_col = _c(0xf4e0ff)
			core_s = Vector3(0.2, 0.2, 0.3)
			var r1 := Basis.from_euler(Vector3(0.35, 0.0, tt * 9.0), EULER_ORDER_XYZ)
			var r2 := Basis.from_euler(Vector3(0.0, 0.35, -tt * 12.0), EULER_ORDER_XYZ)
			_bolt_ring.add(Transform3D(basis_ * r1.scaled_local(Vector3.ONE * pu), pos), Color(_c(0xd8a0ff), 0.8))
			_bolt_ring.add(Transform3D(basis_ * r2.scaled_local(Vector3.ONE * (0.7 / pu)), pos), Color(_c(0xd8a0ff), 0.8))
		elif k == "silenced":                            # a thin, dim streak: the round itself, no glow
			halo_col = _c(0xb08040)
			halo_s = Vector3(0.05, 0.05, 1.3)
			core_col = _c(0xfff4d8)
			core_s = Vector3(0.022, 0.022, 0.9)
		elif k == "plasma":
			halo_col = _c(0x39ff6a)
			halo_s = Vector3(0.16, 0.16, 1.0)
			core_col = _c(0xeaffd8)
			core_s = Vector3(0.06, 0.06, 0.55)
		if not mind and not glob and not ring_k and not dart_k:
			_bolt_box.add(Transform3D(basis_.scaled_local(halo_s), pos), Color(halo_col, 0.75))
		_bolt_box.add(Transform3D(basis_.scaled_local(core_s), pos), Color(core_col, 1.0))
	_bolt_box.finish()
	_bolt_orb.finish()
	_bolt_ring.finish()
	_bolt_dart.finish()


## JS botTick: per-frame emitters: smoking wreck + sparks after death, steam venting during recovery, thin smoke when badly damaged
func bot_tick(dt: float) -> void:
	for b in bots:
		var R = b.R
		if not R.robot or R.alien or R.meat or R.human:
			continue
		if R.dead:
			if R.dead_t < 5.0:
				b.smoke_t -= dt
				if b.smoke_t <= 0.0:
					b.smoke_t = 0.1 + randf() * 0.1
					var pos: Vector3 = b.spine_world()
					pos.x += (randf() - 0.5) * 0.3
					pos.z += (randf() - 0.5) * 0.3
					_smoke(pos, Vector3((randf() - 0.5) * 0.4, 0.7 + randf() * 0.4, (randf() - 0.5) * 0.4), 1.1 + randf() * 0.8, 0.12, 2.6, -0.25)
			if R.dead_t > 0.2 and R.dead_t < 3.5:
				b.spark_t -= dt
				if b.spark_t <= 0.0:
					b.spark_t = 0.12 + randf() * 0.35
					var pos: Vector3 = b.spine_world() if randf() < 0.5 else b.el_l_world()
					sparks(pos, 4, 2.6)
					if randf() < 0.5:
						Game.sfx.play_at("zap", pos.x, pos.y, pos.z, {"range": 22.0})
		else:
			if R.state == &"recover" and R.atk != null and str(R.atk) != "":
				b.vent_t -= dt
				if b.vent_t <= 0.0:
					b.vent_t = 0.06
					_steam(b.sprite_world(2), Vector3((randf() - 0.5) * 0.5, 1.0 + randf() * 0.6, (randf() - 0.5) * 0.5), 0.55, 0.07, 3.2, -0.1)
			elif R.hp < R.max * 0.35:
				b.smoke_t -= dt
				if b.smoke_t <= 0.0:
					b.smoke_t = 0.25
					_smoke(b.sprite_world(2), Vector3((randf() - 0.5) * 0.3, 0.6, (randf() - 0.5) * 0.3), 0.9, 0.08, 2.4, -0.2)


## JS alertPulse: debug: a ring that expands over the alerted robots' alert radius
func alert_pulse(e: Dictionary) -> void:
	if not Config.ai_debug:
		return
	_boom(_b_ping, Vector3(e.x, float(e.y) + 0.1, e.z), e.r, 0.7, 3, _c(0xff9a2e if e.get("lethal", false) else 0xff3a2a), 0.9)


## JS shieldHitFx: energy-shield hit: a few blue / orange electrical sparks pop off the body instead of blood. The hit that breaks the shield throws a big burst and then ~1 s of thinning sparks.
func shield_hit_fx(e: Dictionary, P: Player, sfx: Sfx) -> void:
	if P == null:
		return
	var hex: int = e.get("shield_hex", 0)
	if hex == 0:
		hex = 0x4db8ff
	var p := Vector3(P.x, P.y + 0.7 + randf() * 0.8, P.z)
	var dir := Vector3(-float(e.get("dx", 0.0)), 0.15, -float(e.get("dz", 0.0)))
	_shield_fx_hex = hex
	var hi: bool = str(e.get("shield_col", "")) == "blue"
	if e.get("shield_break", false):
		_shield_fx_burst = 1.0
		sparks(p, 46, 6.5, null, hex)
		sparks(p, 12, 5.0, null, 0xffffff)               # the big burst
		_shield_arcs(P, hex, 6)
		shake = maxf(shake, 0.5)
		sfx.play("shieldBreak", {"hi": hi})
	else:
		sparks(p, 5, 2.6, dir, hex)
		sparks(p, 2, 2.2, dir, 0xffffff)                 # subtle: a handful of sparks
		if randf() < 0.4:
			_shield_arcs(P, hex, 1)
		sfx.play("shieldHit", {"hi": hi})


## JS _shieldArcs: short jagged zaps jumping off the body (not a shell around it)
func _shield_arcs(P: Player, hex: int, n: int) -> void:
	for i in n:
		var a := randf() * 6.283
		var y: float = P.y + 0.4 + randf() * 1.2
		var ox := sin(a)
		var oz := cos(a)
		var prev := Vector3(P.x + ox * 0.3, y, P.z + oz * 0.3)
		for k in range(1, 4):
			var r := 0.3 + k * 0.14
			var pt := Vector3(P.x + ox * r + (randf() - 0.5) * 0.14, y + (randf() - 0.5) * 0.22, P.z + oz * r + (randf() - 0.5) * 0.14)
			tracer(prev, pt, 0.018, 0.08, hex)
			prev = pt


func _shield_update(dt: float) -> void:
	var P := last_player
	if not _shield_fx_burst > 0.0 or P == null:
		return
	_shield_fx_burst = maxf(0.0, _shield_fx_burst - dt)
	var k := _shield_fx_burst                            # shield failure: ~1 s of sparks that thins out
	_shield_fx_acc += dt * (90.0 * k + 6.0)
	var n := floori(_shield_fx_acc)
	_shield_fx_acc -= n
	if n > 0:
		sparks(Vector3(P.x, P.y + 0.3 + randf() * 1.3, P.z), mini(n, 8), 2.8 + 2.5 * k, null, 0xffffff if randf() < 0.25 else _shield_fx_hex)
	if randf() < dt * (16.0 * k + 2.0):
		_shield_arcs(P, _shield_fx_hex, 1)


## JS playerHitFx
func player_hit_fx(e: Dictionary, sfx: Sfx, hud: Variant) -> void:
	var shield: bool = e.get("shield", false)
	var absorbed: bool = shield and not float(e.get("hp_amount", 0.0)) > 0.0     # the shield took the whole hit: a zap (played by shield_hit_fx), not a grunt
	var melee: bool = str(e.get("kind", "")) == "melee"
	shake = maxf(shake, (0.65 if melee else 0.3) * (0.5 if absorbed and not e.get("shield_break", false) else 1.0))
	if not absorbed:
		var choices: Array[String] = []
		for key in ["progHurt1", "progHurt2", "progHurt3"]:
			if sfx.voice_clip(key) != null:
				choices.append(key)
		if not choices.is_empty():
			var key: String = choices[randi() % choices.size()]
			if choices.size() > 1 and key == _last_prog_hurt:
				key = choices[(choices.find(key) + 1 + randi() % (choices.size() - 1)) % choices.size()]
			_last_prog_hurt = key
			sfx.clip(sfx.voice_clip(key), {"gain": 0.55 if melee else 0.42, "wet": 0.08, "voice": true})
		else:
			sfx.play("playerHurt", {"k": 1.0 if melee else 0.6})
	_hud(hud, &"hurt", [e, Game.camera])


func _hud(hud: Variant, m: StringName, args: Array = []) -> void:
	if hud != null and hud.has_method(m):
		hud.callv(m, args)


# ---------------------------------------------------------------- events ----------------------------------------------------------------

## JS handle(events, ctx): consume combat events and the player's events. Everything else (weapon view, HUD, player) comes from Game.
func handle(events: Array, pev: Array, clone: Variant = null) -> void:
	var sfx: Sfx = Game.sfx
	var player: Player = Game.player if clone == null else clone.state      # (an AI clone's events: JS ctx { wv, sfx, hud: CLONE_HUD, player, combat })
	var combat = Game.combat if clone == null else clone.combat
	if combat != null:
		world = combat.world
	elif Game.world != null:
		world = Game.world
	last_player = player
	if creature_audio == null:
		creature_audio = CreatureAudio.new()
	var wv = _wv()
	for e: Dictionary in events:
		var hud: Variant = null if (clone != null or e.get("clone_id") != null) else Game.hud
		var previous_shake := shake
		var t: String = str(e.t)
		if stats_on:
			stats[t] = int(stats.get(t, 0)) + 1
		var creature: Variant = _bot_r(e.get("id")) if e.has("id") else null
		var creature_sound := creature_audio.event(e, creature, sfx)
		if t == "creature_cue":
			continue
		if GAD_EV.has(t):
			gad.event(e, sfx, player)
			continue
		match t:
			"shot":
				_ev_shot(e, wv, sfx, player, hud)
			"reload":
				var ph := str(e.get("ph", ""))
				if ph == "pouch" and str(e.get("kind", "")) == "mag":
					mag_drop(wv, player, str(e.id))
				if ph != "cancel" and ph != "done":
					sfx.play("rl", e)
			"empty":
				sfx.play("empty", e)
				if wv != null:
					wv.dry(str(e.get("id", "")))
			"equip":
				var i: int = e.get("i", -1)
				sfx.play("equip", {"heavy": EQUIP_HEAVY[i] if i >= 0 and i < EQUIP_HEAVY.size() else 0.0})
			"punch":
				sfx.play("whoosh", {"stage": e.get("stage", 1)})
			"slam":
				slam_fx(Vector3(e.x, e.y, e.z), e.r)
				sfx.play("slam")
			"punch_hit":
				if e.get("hit", false):
					sfx.play("punchHit", {"stage": e.get("stage", 1)})
					shake = maxf(shake, 0.5 if e.get("stage", 1) == 3 else 0.22)
			"hit":
				if not e.get("crowd", false):
					sfx.play("hit")
					_hud(hud, &"hit_marker", [false, e])
					blood_hit(e, false)
			"kill":
				if not e.get("crowd", false):
					sfx.play("kill")
					_hud(hud, &"hit_marker", [true, e])
					blood_hit(e, true)
			"dmg":
				if not e.get("crowd", false):
					number(Vector3(e.x, e.y, e.z), e.amount, e.get("kill", false))
			"explode":
				explosion(Vector3(e.x, e.y, e.z), e.r)
				sfx.play("explode", {"dist": Vector2(float(e.x) - player.x, float(e.z) - player.z).length()})
			"locked":
				sfx.play("deny")
				_hud(hud, &"toast", ["NOT ON YOUR WHEEL - BUY OR PICK ONE UP"])
			"encounter_reward":
				sfx.play("pickup")
			"pickup":
				sfx.play("pickup")
				_hud(hud, &"toast", ["AMMO REPLENISHED"])
				sparks(Vector3(e.x, e.y, e.z), 16, 4.0)
			"respawn":
				if e.has("id"):
					sfx.play_at("respawn", e.x, float(e.y) + 1.0, e.z)
				else:
					sfx.play("respawn")
			# ---- hostile robots ----
			"robot_hit":
				robot_hit_fx(e, sfx)
			"robot_die":
				robot_die_fx(e, sfx)
			"robot_state":
				_ev_robot_state(e, creature, creature_sound, sfx)
			"robot_atk":
				_ev_robot_atk(e, creature, creature_sound, sfx)
			"bolt":
				_ev_bolt(e, creature, sfx)
			"bolt_hit":
				var bk := str(e.get("bk", ""))
				sparks(Vector3(e.x, e.y, e.z), 5 if str(e.get("kind", "")) == "player" else 8, 3.5, Vector3(e.nx, e.ny, e.nz), _bolt_col(bk))
				sfx.play_at("boltHit", e.x, e.y, e.z, {"kind": e.get("kind", ""), "bk": "sauce" if bk == "bile" or bk == "ink" else bk})
				if bk == "sauce":
					sauce_splat(e)
			"mind_hit":
				mind_hit_fx(e, sfx, hud)
			"player_stun":
				stun_fx(e, sfx, player)
			"meat_boom":
				meat_boom_fx(e, sfx, player)
			"worm_slam":
				worm_slam_fx(e, sfx, player)
			"worm_grow":
				var quiet: bool = e.get("quiet", false)
				sparks(Vector3(e.x, e.y, e.z), 8 if quiet else 26, 4.0, null, 0xb01a14)
				if not quiet:
					shake = maxf(shake, 0.2)
				sfx.play_at("wormGrow", e.x, e.y, e.z, {"range": 60.0, "quiet": quiet})
			"tongue_lash":
				var hit: bool = e.get("hit", false)
				sparks(Vector3(e.x, e.y, e.z), 14 if hit else 5, 3.5, null, 0xff5a8a)
				if hit:
					_blood_spray(Vector3(e.x, e.y, e.z), 0.0, 0.0, 8, 3.0)
				shake = maxf(shake, 0.5 if hit else 0.15)
				sfx.play_at("tongueLash", e.x, e.y, e.z, {"hit": hit, "range": 60.0})
			"scream_call":
				sparks(Vector3(e.x, e.y, e.z), 20, 4.0, null, 0xff5a8a)
				shake = maxf(shake, 0.3)
				sfx.play_at("screamCall", e.x, e.y, e.z, {"range": 110.0})
			"ring_hit":
				shake = maxf(shake, 0.45)
				sfx.play("ringHit")
				sparks(Vector3(e.x, e.y, e.z), 14, 4.0, null, 0xffd860)
			"summon":
				sparks(Vector3(e.x, e.y, e.z), 14, 3.0, null, 0xff5a2a)
				dust(Vector3(e.x, float(e.y) - 0.2, e.z), 4, 0.6)
				sfx.play_at("summon", e.x, e.y, e.z, {"range": 50.0})
			"ai_alert":
				alert_pulse(e)
			"drone_call":
				if str(e.get("ph", "")) == "start":
					sfx.play_at("droneCall", e.x, e.y, e.z, {"range": 90.0})
				else:
					var pts: Array = e.get("pts", [])
					var j := 0
					while j + 2 < pts.size():
						var p := Vector3(pts[j], float(pts[j + 1]) + 0.1, pts[j + 2])
						sparks(p, 22, 5.0, Vector3.UP)
						dust(p, 10, 2.5)
						sfx.play_at("respawn", p.x, p.y + 1.0, p.z, {"range": 80.0})
						j += 3
			"bark":
				# These species communicate through creature cues, including outside the Spire.
				if not (CreatureAudio.creature_kind(creature) != "" and not _flag(creature, &"alien")):
					sfx.speak(e)
					_hud(hud, &"subtitle", [e])
			"bark_cut":
				sfx.cut_voice(e.get("id"))
			"player_hit":
				player_hit_fx(e, sfx, hud)
				if e.get("shield", false):
					shield_hit_fx(e, player, sfx)
				else:
					blood_player(e, player)
				if e.get("shield", false) and e.get("kill", false):      # a hit that breaks the shield and still kills spills blood too
					blood_player(e, player)
			"shield_up":
				_hud(hud, &"shield_up")
				sfx.play("shieldUp", {"hi": str(e.get("col", "")) == "blue"})
			"player_die":
				if sfx.voice_clip("progDeath") != null:
					sfx.clip(sfx.voice_clip("progDeath"), {"gain": 0.52, "rate": 1.12, "wet": 0.16, "voice": true})
				else:
					sfx.play("playerDie")
				_hud(hud, &"dead", [true])
			"clone_hit":
				var a = e.get("actor_state")
				if a != null:
					blood_player(e, a)
					sfx.play_at("pain", a.x, a.y + 1.0, a.z, {"range": 25.0})
			"clone_die":
				var a = e.get("actor_state")
				if a != null:
					sfx.play_at("playerDie", a.x, a.y + 1.0, a.z, {"range": 30.0})
		if e.get("clone_id") != null:
			shake = previous_shake
	for pe: StringName in pev:
		if pe == &"land":
			var k := minf(1.0, player.land_impact / 20.0)
			if player.land_impact > 7.0:
				sfx.play("land", {"k": k})
			if player.land_impact > 17.0:
				dust(Vector3(player.x, player.y + 0.05, player.z), 4 + roundi(5.0 * k), 0.8 + k)
				shake = maxf(shake, 0.12 + 0.3 * k * k)
		elif pe == &"slam_start":
			sfx.play("whoosh", {"stage": 3})
		elif pe == &"splash" or pe == &"swim_hop" or pe == &"stroke" or pe == &"tread":
			swim_fx(pe, player, sfx)
		elif pe == &"rung" or pe == &"ladder_grab":
			sfx.play("rung", {"k": 1.5 if pe == &"ladder_grab" else 1.0})
	events.clear()


func _flag(r: Variant, f: StringName) -> bool:
	if r == null:
		return false
	var v: Variant = r.get(f)
	return v != null and v != false


func _bolt_col(bk: String) -> int:
	match bk:
		"plasma":
			return 0x6dff8a
		"mind":
			return 0xc58bff
		"sauce":
			return 0xe0301c
		"bile":
			return 0xc8f030
		"ink":
			return 0x3050ff
		"ring":
			return 0xff5a48
		"mail":
			return 0xffffff
	return -1


func _ev_shot(e: Dictionary, wv: Variant, sfx: Sfx, player: Player, hud: Variant) -> void:
	var id: String = str(e.id)
	var info = wv.info if wv != null else null
	if info != null and info.get("dual") != null:        # dual pistols alternate hands: flash, tracer and brass come from the gun that fired
		info.dual.next()
	var muz := Vector3(e.mx, e.my, e.mz)
	if info != null:
		muz = wv.muzzle_world()
	var heavy: float = SHOT_HEAVY.get(id, 1.0)
	if wv != null:
		if not NOFLASH.has(id):
			wv.flash(heavy * 0.8, id)
		wv.fire(id, e.get("left", 1))
	sfx.play(id)
	if e.get("left", 1) == 0 and id != "rocket" and id != "legacy_rocket":
		timers.append([0.09, sfx.play.bind("lock", {})])
	muzzle_fx(wv, e, muz)
	var sniper_kick := 0.12 if player.scoped else 0.5    # scoped: the kick is the pitch jump, not a camera shake
	shake = maxf(shake, sniper_kick if (id == "sniper" or id == "legacy_sniper") else float(SHOT_SHAKE.get(id, 0.1)))
	armory_shot(e, muz)
	var w := 0.012 if id == "shotgun" else (0.03 if id == "sniper" else 0.022)
	var life := 0.05 if (id == "smg" or id == "rifle") else (0.16 if id == "sniper" else 0.08)
	var col := 0xa868ff if id == "sniper" else 0x8af4ff if id == "smg" else 0xffb060 if id == "deagle" else -1
	for hp in e.get("pellets", []):
		if hp == null:
			continue
		var end := Vector3(hp.x, hp.y, hp.z)
		tracer(muz, end, w, life, col)
		var kind := str(hp.get("kind", "none"))
		if kind != "none":
			sparks(end, 4 if kind == "target" else 6, 3.5, Vector3(hp.get("nx", 0.0), hp.get("ny", 0.0), hp.get("nz", 0.0)))
	if id != "rocket" and id != "legacy_rocket" and not NOFLASH.has(id) and info != null and info.eject != null:   # (only the bullet gun has brass) brass leaves the port as the slide / bolt / pump comes back, and tinks on the floor a moment later
		var rf = info.rack.fire if info.rack != null else null
		var dly: float = 0.01
		if rf != null:
			dly = rf.t1 + 0.02 if id == "shotgun" else rf.t0 + (rf.t1 - rf.t0) * 0.7
		timers.append([dly, casing.bind(wv, player, id)])
		if id == "shotgun" or id == "deagle" or randf() < 0.35:
			timers.append([dly + 0.42 + randf() * 0.1, sfx.play.bind("brass", {"big": id == "shotgun"})])
	_hud(hud, &"on_shot")


func _ev_robot_state(e: Dictionary, creature: Variant, creature_sound: bool, sfx: Sfx) -> void:
	var to := str(e.get("to", ""))
	var x: float = e.x
	var y: float = e.y
	var z: float = e.z
	if RobotAudio.robot_sound_kind(creature) != "":
		if to == "alert":
			robot_sound("alert", creature)
		if to == "stagger":
			sparks(Vector3(x, y + 1.0, z), 6, 2.0)
		return
	if creature_sound:
		if to == "stagger":
			sparks(Vector3(x, y + 1.0, z), 6, 2.0)
		return
	if _flag(creature, &"human"):                        # the night assassin: no beeps, no chimes
		return
	if to == "alert":
		sfx.play_at("alertBeep", x, y + 1.6, z)
	elif to == "stagger":
		sfx.play_at("stagger", x, y + 1.6, z)
		sparks(Vector3(x, y + 1.5, z), 10, 3.0)
	elif to == "return":
		sfx.play_at("chime", x, y + 1.6, z, {"range": 25.0})


func _ev_robot_atk(e: Dictionary, creature: Variant, creature_sound: bool, sfx: Sfx) -> void:
	var ph := str(e.get("ph", ""))
	var kind := str(e.get("kind", ""))
	var x: float = e.x
	var y: float = e.y
	var z: float = e.z
	var py := y + 1.2
	if RobotAudio.robot_sound_kind(creature) != "":
		if ph == "windup":
			robot_sound("charge", creature)
		elif ph == "hit":
			robot_sound("strike", creature, Vector3(x, y, z))
			shake = maxf(shake, 0.3)
			sparks(Vector3(x, y, z), 7, 2.5)
		elif ph == "miss":
			dust(Vector3(x, 0.1, z), 4, 0.6)
		return
	if creature_sound:
		if ph == "hit":
			shake = maxf(shake, 0.22)
			sparks(Vector3(x, y, z), 7, 2.5)
		elif ph == "miss":
			dust(Vector3(x, y + 0.05, z), 4, 0.6)
		return
	if _flag(creature, &"human"):                        # the night assassin: knife draw, slash, backflip; the pistol is quiet until it fires
		if ph == "windup" and kind == "dash":
			sfx.play_at("knifeDraw", x, py, z, {"range": 40.0})
		elif ph == "go" and kind == "dash":
			sfx.play_at("swing", x, py, z)
		elif ph == "hit":
			sfx.play_at("knifeHit", x, py, z, {"range": 50.0})
			shake = maxf(shake, 0.5)
			_blood_spray(Vector3(x, y, z), 0.0, 0.0, 8, 3.0)
		elif ph == "miss":
			dust(Vector3(x, y + 0.05, z), 6, 0.9)
		elif kind == "flip":
			sfx.play_at("whoosh" if ph == "go" else "land", x, py, z, {"stage": 2, "k": 0.6, "range": 35.0})
			if ph == "land":
				dust(Vector3(x, y + 0.05, z), 5, 0.7)
		return
	if ph == "windup":
		match kind:
			"mind":
				sfx.play_at("mindWind", x, py, z, {"range": 55.0})
			"whip":
				sfx.play_at("tongueWind", x, py, z, {"range": 55.0})
			"dart":
				sfx.play_at("dartWind", x, py, z, {"range": 55.0})
			"call":
				sfx.play_at("screamWind", x, py, z, {"range": 70.0})
			"ring":
				sfx.play_at("ringerWind", x, py, z, {"range": 60.0})
			"slam":
				sfx.play_at("slamWind", x, py, z, {"range": 60.0})
			"extend":
				sfx.play_at("wormGrowWind", x, py, z, {"range": 55.0})
			"sauce":
				sfx.play_at("sauceWind", x, py, z, {"range": 55.0})
			"summon":
				sfx.play_at("summonWind", x, py, z, {"range": 60.0})
			_:
				sfx.play_at("wind", x, py, z, {"kind": kind})
	elif ph == "go" and kind == "melee":
		sfx.play_at("swing", x, py, z)
	elif ph == "hit":
		sfx.play_at("meleeHit", x, py, z, {"range": 60.0})
		shake = maxf(shake, 0.45)
		sparks(Vector3(x, y, z), 10, 3.5)
	elif ph == "miss":
		sfx.play_at("meleeMiss", x, 0.2, z)
		dust(Vector3(x, 0.1, z), 5, 0.9)


func _ev_bolt(e: Dictionary, creature: Variant, sfx: Sfx) -> void:
	var bk: String = str(e.get("kind", "")) if str(e.get("kind", "")) != "" else "bolt"
	var col := _bolt_col(bk)
	var dir := Vector3(e.get("dx", 0.0), e.get("dy", 0.0), e.get("dz", 0.0))
	var bv: Variant = bot_by_id.get(e.get("id"))
	if bk == "silenced":                                 # the night assassin's suppressed Beretta: a soft cough, no light
		sfx.play_at("suppressed", e.x, e.y, e.z, {"range": 45.0})
		if bv != null:
			sparks(bv.muzzle_world(), 2, 2.0, dir, 0xffe0a0)
		return
	if not robot_sound("shot", creature, Vector3(e.x, e.y, e.z)):
		var id := "plasma" if bk == "plasma" else "mindBlast" if bk == "mind" else "sauce" if (bk == "sauce" or bk == "bile" or bk == "ink") else "ringer" if bk == "ring" else "spitDart" if bk == "dart" else "bolt"
		sfx.play_at(id, e.x, e.y, e.z, {"range": 80.0 if bk == "mind" else 70.0})
	if bv != null:
		var m: Vector3 = bv.muzzle_world(bk)
		sparks(m, 4 if bk == "plasma" else 6, 3.0, dir, col)
		light_t = maxf(light_t, 0.12)
		light.light_color = _c_srgb(0x3aff6a if bk == "plasma" else 0xb050ff if bk == "mind" else 0xff3a20)
		light.position = m


# ---------------------------------------------------------------- the frame ----------------------------------------------------------------

## JS update(dt, combat, cam, w, h)
func update(dt: float) -> void:
	_t += dt
	var combat = Game.combat
	var cam: Camera3D = Game.camera
	for i in range(timers.size() - 1, -1, -1):
		var q: Array = timers[i]
		q[0] = float(q[0]) - dt
		if float(q[0]) <= 0.0:
			timers.remove_at(i)
			(q[1] as Callable).call()
	# bots far above / below the camera (another organ of the Spire) or far away are hidden and not animated. A culled view is made visible again before its next update.
	if cam != null and not bots.is_empty():
		var cp := cam.global_position
		var now_s := Time.get_ticks_msec() / 1000.0
		for b in bots:
			var R = b.R
			var far: bool = absf(R.y - cp.y) > 24.0 or Vector2(R.x - cp.x, R.z - cp.z).length() > 140.0
			if far:
				b.set_culled(true)
				continue
			b.set_culled(false)
			var frozen = R.get(&"frozen_t")
			if frozen != null and frozen > 0.0 and not R.dead:      # FROST: a frozen enemy's pose holds still inside the ice
				continue
			var chill = R.get(&"chill")
			b.update(dt * (1.0 - 0.7 * minf(1.0, chill)) if chill != null and chill > 0.0 else dt, now_s, self)
	bot_tick(dt)
	_stun_tick(dt)
	if combat != null:
		var en = combat.get(&"enemies")
		if en != null:
			bolt_vis(en.bolts)
		_crates_tick(dt, combat)
		drop_vis(dt, combat)
		_rockets_tick(dt, combat.projs if Game.player_clones.clones.is_empty() else Game.player_clones.render_projs(combat.projs))
	_arm_tick(dt)
	_landing_tick()
	_shield_update(dt)
	# the pools' clock, and hide a pool once its newest life has ended
	for pl: PartPool in _pools:
		if pl.node.visible:
			if _warm_frames <= 0 and _t > pl.last_end + 0.05:
				pl.node.visible = false
			else:
				pl.mat.set_shader_parameter(&"now", _t)
	if _warm_frames > 0:
		_warm_frames -= 1
		if _warm_frames == 0:
			_warm_end()
	light_t = maxf(0.0, light_t - dt)
	var want := light_t > 0.0
	if want or light.visible:
		light.light_energy = (28.0 * (light_t / 0.4)) / PI if want else 0.0     # three.js point light candela -> Godot energy: energy = intensity / pi (Godot multiplies by pi)
		light.visible = want
	shake = maxf(0.0, shake - dt * 3.2)
	vertical_shake_t = maxf(0.0, vertical_shake_t - dt)
	vertical_shake_y = vertical_shake * pow(vertical_shake_t / 0.1, 2.0) * sin((0.1 - vertical_shake_t) * TAU * 48.0)
	_numbers_tick(dt, cam)
	if gad != null:
		gad.update_gadgets(dt, combat, cam, Game.player)


func _warm_end() -> void:
	for pl: PartPool in _pools:
		if _t > pl.last_end:
			pl.node.visible = false


func _landing_tick() -> void:
	if _landing.is_empty():
		return
	for i in range(_landing.size() - 1, -1, -1):
		var q: Array = _landing[i]
		if _t >= float(q[0]):
			_landing.remove_at(i)
			_blood_splat(q[1], q[2], q[3], 0.1 + float(q[4]) * 5.0 + randf() * 0.08, BLOOD_LIFE * 0.6)


func _rockets_tick(dt: float, projs: Array) -> void:
	for q in projs:
		var pos := Vector3(q.x, q.y, q.z)
		var z := Vector3(q.dx, q.dy, q.dz)
		var up := Vector3.UP if absf(z.y) < 0.999 else Vector3.RIGHT
		var x := up.cross(z).normalized()
		var xf := Transform3D(Basis(x, z.cross(x), z), pos)
		_rk_body.add(xf, Color.WHITE)
		_rk_flame.add(xf, Color.WHITE)
		if randf() < dt * 90.0:
			_smoke(pos - z * 0.4, Vector3((randf() - 0.5) * 0.4, 0.2, (randf() - 0.5) * 0.4), 0.7, 0.16, 1.6, -0.1)
	_rk_body.finish()
	_rk_flame.finish()


func _arm_tick(dt: float) -> void:
	if _arm.is_empty() and not _arm_ball.node.visible and not _arm_body.node.visible and not _arm_needle.node.visible:
		return
	for i in range(_arm.size() - 1, -1, -1):
		var a := _arm[i]
		a.t += dt
		var u := minf(1.0, a.t / a.dur)
		var pos := a.from.lerp(a.to, u)
		if a.wob_a != 0.0:
			var w := sin(a.t * a.wob_f + a.wob_p) * a.wob_a * (1.0 - u)
			pos.x += w
			pos.y += w * 0.7
		var z := (a.to - a.from).normalized()
		var up := Vector3.UP if absf(z.y) < 0.999 else Vector3.RIGHT
		var x := up.cross(z).normalized()
		var b := Basis(x, z.cross(x), z)
		match a.kind:
			0:
				_arm_ball.add(Transform3D(Basis.IDENTITY, pos), a.col)
			1:
				_arm_body.add(Transform3D(b.scaled_local(Vector3(0.8, 0.8, 1.8)), pos), Color.WHITE)
				for s: float in [1.0, -1.0]:
					var flap := sin(a.t * 150.0) * 0.9 * s
					var wb := b * Basis.from_euler(Vector3(PI * 0.5, 0.0, flap), EULER_ORDER_XYZ)
					_arm_wing.add(Transform3D(wb, pos + b * Vector3(s * 0.012, 0.01, 0.0)), Color.WHITE)
			2:
				_arm_needle.add(Transform3D(b, pos), Color(_c(0xc9a0ff), 1.0))
		if u >= 1.0:
			_arm.remove_at(i)
	_arm_ball.finish()
	_arm_body.finish()
	_arm_wing.finish()
	_arm_needle.finish()


func _numbers_tick(dt: float, cam: Camera3D) -> void:
	if _nums.is_empty() or cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var proj := cam.get_camera_projection() * Projection(cam.global_transform.affine_inverse())
	for i in range(_nums.size() - 1, -1, -1):
		var n: Array = _nums[i]
		n[2] = float(n[2]) + dt
		var t: float = n[2]
		var l: Label = n[0]
		var w: Vector3 = n[1]
		var c := proj * Vector4(w.x, w.y + t * 1.2, w.z, 1.0)
		var front := c.w > 0.0
		if front:
			var x := (c.x / c.w * 0.5 + 0.5) * vp.x + float(n[3]) * t
			var y := (-c.y / c.w * 0.5 + 0.5) * vp.y
			l.position = Vector2(x, y) - l.size * 0.5
			var s := 1.0 + maxf(0.0, 0.5 - t) * 1.2
			l.scale = Vector2(s, s)
		l.modulate.a = maxf(0.0, 1.0 - maxf(0.0, t - 0.45) * 2.0) if front else 0.0
		if t > 1.0:
			l.visible = false
			_num_free.append(l)
			_nums.remove_at(i)


## JS setup(combat): the ammo crates of the level (level-owned: built here, freed by clear_level). Enemy views are made by whoever spawns the enemy and pushed into bots / bot_by_id.
func setup(combat: Variant) -> void:
	_crates_clear()
	var style: Dictionary = combat.world.get(&"pod_style") if combat.world.get(&"pod_style") != null else {}
	for p in combat.pickups:
		var g := Node3D.new()
		var crate := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.62, 0.62, 0.62)
		crate.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _c_srgb(style.get("color", 0x39422f))
		mat.emission_enabled = true
		mat.emission = _c_srgb(0x0c0f08)
		g.add_child(crate)
		crate.material_override = mat
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.66, 0.14, 0.66)
		band.mesh = bm
		var band_m := StandardMaterial3D.new()
		band_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		band_m.albedo_color = _c_srgb(style.get("band", 0xc98a3a))
		band.material_override = band_m
		g.add_child(band)
		var ring_mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.525
		tm.outer_radius = 0.575
		tm.rings = 20
		tm.ring_segments = 6
		ring_mi.mesh = tm
		ring_mi.material_override = band_m
		ring_mi.position.y = -0.3
		g.add_child(ring_mi)
		g.position = Vector3(p.x, p.y + 0.8, p.z)
		add_child(g)
		_crates.append([g, p])


func _crates_tick(dt: float, _combat: Variant) -> void:
	if _crates.is_empty():
		return
	var tt := Time.get_ticks_msec() / 400.0
	for c: Array in _crates:
		var g: Node3D = c[0]
		var p = c[1]
		g.visible = p.cd <= 0.0
		g.rotation.y += dt * 1.5
		g.position.y = p.y + 0.8 + sin(tt) * 0.08


## JS dropVis: weapons lying in the world: the real weapon model, spinning slowly over a faint glass ring (brighter when it is the one in reach).
func drop_vis(dt: float, combat: Variant) -> void:
	var D: Array = combat.drops
	if D.is_empty() and _drop_views.is_empty():
		return
	for d: Variant in _drop_views.keys():
		if not D.has(d):
			((_drop_views[d] as Array)[0] as Node3D).queue_free()
			_drop_views.erase(d)
	var t := Time.get_ticks_msec() / 1000.0
	for d: Variant in D:
		var v: Variant = _drop_views.get(d)
		if v == null:
			v = _drop_view(d)
			_drop_views[d] = v
		d.yaw += dt * 1.7
		var g: Node3D = v[0]
		var spin: Node3D = v[1]
		g.position = Vector3(d.x, d.y, d.z)
		spin.rotation.y = d.yaw
		spin.position.y = 0.55 + (sin(t * 2.2 + d.id) * 0.06 if d.rest else 0.0)
		var hot: bool = combat.drop_focus == d
		var k := minf(1.0, dt * 10.0)
		v[2] = float(v[2]) + ((0.75 if hot else 0.0 if d.cd > 0.0 else 0.3) - float(v[2])) * k
		v[3] = float(v[3]) + ((1.15 if hot else 1.0) - float(v[3])) * k
		if d.rest:
			var rs: float = v[3]
			_drop_rings.add(Transform3D(Basis.from_scale(Vector3(rs, 1.0, rs)), g.position + Vector3(0, 0.03, 0)), Color(_c(0xe6eef6), float(v[2])))
	_drop_rings.finish()


func _drop_view(d: Variant) -> Array:
	var g := Node3D.new()
	var spin := Node3D.new()
	var id: String = Weapons.WEAPONS[d.i].id
	var path := "res://assets/weapons/%s.glb" % id
	if ResourceLoader.exists(path):
		var m: Node3D = (load(path) as PackedScene).instantiate()
		var box := _bounds(m, Transform3D.IDENTITY)
		m.position = -box.get_center()                  # spin about the model's middle, not its grip
		var sz := box.size
		spin.scale = Vector3.ONE * clampf(0.8 / maxf(maxf(sz.x, sz.y), maxf(sz.z, 0.01)), 1.0, 1.7)     # pistols read a little bigger on the ground
		spin.add_child(m)
	g.add_child(spin)
	add_child(g)
	return [g, spin, 0.0, 1.0]


func _bounds(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var here := xf
	if n is Node3D:
		here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = here * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c: Node in n.get_children():
		var b := _bounds(c, here)
		if b.size == Vector3.ZERO:
			continue
		out = b if first else out.merge(b)
		first = false
	return out


func _crates_clear() -> void:
	for c: Array in _crates:
		(c[0] as Node3D).queue_free()
	_crates.clear()


## JS clearLevel: a level is being swapped out: drop every effect in flight and every view of the old level's targets and crates (the pools stay). A jump of the FX clock ends every life at once.
func clear_level() -> void:
	_t += 100.0
	for pl: PartPool in _pools:
		pl.last_end = -1.0
		pl.node.visible = false
	_drop_end.fill(-1.0)
	_landing.clear()
	timers.clear()
	_arm.clear()
	for n: Array in _nums:
		(n[0] as Label).visible = false
		_num_free.append(n[0])
	_nums.clear()
	_crates_clear()       # (the enemy views go with Game.enemy_views.clear_level)
	for d: Variant in _drop_views.keys():
		((_drop_views[d] as Array)[0] as Node3D).queue_free()
	_drop_views.clear()
	_drop_rings.finish()
	shake = 0.0
	vertical_shake_t = 0.0
	vertical_shake = 0.0
	vertical_shake_y = 0.0
	light_t = 0.0
	light.visible = false
	_stun_t = 0.0
	_shield_fx_burst = 0.0
	if gad != null:
		gad.clear()
