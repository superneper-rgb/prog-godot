class_name SkyLook
extends RefCounted
## The derelict SkySphere's palette and shared materials (user, 2026-11-18: "less vaporwave and more cyberpunk gritty ... an underground illegal
## race"). Rust, grime and wet steel in the dark; light is scarce and comes from what the crews rigged: sodium floods, cold work lamps, red
## beacons and road flares. The neon cyan and pink of the first SkySphere are gone. Everything here is made once at level load and shared.

const SODIUM := Color("ff9a3c")       # the floodlights the crews strung up
const WORK := Color("dfe8f2")         # cold work lamps, sparse
const BEACON := Color("ff2a1a")       # warning beacons, flares
const BOOST_PAD := Color("ff7a1f")    # boost pads: hot orange
const STEEL := Color("2b2a29")
const RUST := Color("4a2f22")
const GRIME := Color("15120f")

const TEX := "res://assets/third-party/polyhaven/"

static var _rust: StandardMaterial3D
static var _steel: StandardMaterial3D
static var _concrete: StandardMaterial3D


static func road_textures(m: ShaderMaterial) -> void:
	m.set_shader_parameter(&"plate_tex", load(TEX + "utility_ship_steel.jpg"))
	m.set_shader_parameter(&"plate_normal", load(TEX + "utility_ship_normal.jpg"))
	m.set_shader_parameter(&"plate_rough", load(TEX + "utility_ship_roughness.jpg"))
	m.set_shader_parameter(&"asphalt_tex", load(TEX + "asphalt_02.jpg"))
	m.set_shader_parameter(&"rust_tex", load(TEX + "rusty_metal_02.jpg"))
	m.set_shader_parameter(&"concrete_tex", load(TEX + "cracked_concrete_wall/textures/cracked_concrete_wall_diff_1k.jpg"))
	m.set_shader_parameter(&"concrete_normal", load(TEX + "cracked_concrete_wall/textures/cracked_concrete_wall_nor_gl_1k.jpg"))
	m.set_shader_parameter(&"sodium", Vector3(SODIUM.r, SODIUM.g, SODIUM.b))


## Rusted structural steel (girders, hoops, ribs, gantries), triplanar so any box takes it.
static func rust() -> StandardMaterial3D:
	if _rust == null:
		_rust = _tri(TEX + "rusty_metal_02.jpg", Color(0.62, 0.55, 0.5), 0.62, 0.55, 0.35)
	return _rust


## Dark worn plate steel (decks, armour).
static func steel() -> StandardMaterial3D:
	if _steel == null:
		_steel = _tri(TEX + "utility_ship_steel.jpg", Color(0.42, 0.42, 0.43), 0.5, 0.6, 0.18)
		_steel.normal_enabled = true
		_steel.normal_texture = load(TEX + "utility_ship_normal.jpg")
	return _steel


## Cracked, stained concrete (barriers, footings).
static func concrete() -> StandardMaterial3D:
	if _concrete == null:
		_concrete = _tri(TEX + "cracked_concrete_wall/textures/cracked_concrete_wall_diff_1k.jpg", Color(0.5, 0.48, 0.46), 0.86, 0.0, 0.25)
		_concrete.normal_enabled = true
		_concrete.normal_texture = load(TEX + "cracked_concrete_wall/textures/cracked_concrete_wall_nor_gl_1k.jpg")
	return _concrete


static func _tri(path: String, tint: Color, rough: float, metal: float, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m
