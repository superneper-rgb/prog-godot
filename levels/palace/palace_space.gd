class_name PalaceSpace
extends Node3D
## The Pervert Palace finale's space shot (user, 2026-11-19: "the camera instantly cuts to a shot of earth and a boojie ship comes into frame. its his rich parents and they launch a drop pod
## down"): Earth (palace_earth.gdshader on NASA's Blue Marble), its atmosphere's halo, the stars (palace_sky_space.gdshader), a sun, and Sambo's parents' yacht (assets/palace/yacht.glb:
## white and gold, the family's wolf crest) with the drop pod in its bay (assets/palace/drop_pod.glb). Built at the level's load far from the site, hidden; shot(true) shows it for the cut
## and sets the night up for space (no haze, black, a long far plane, the shot's own sun); shot(false) gives the site its night back. pose(u) is the shot as a function of its time.

const AT := Vector3(30000.0, 0.0, 30000.0)
const EARTH_R := 1400.0
const EARTH_C := AT + Vector3(0.0, -1650.0, 1150.0)
const SUN := Vector3(-0.62, 0.32, 0.72)
const CAM := AT + Vector3(0.0, 8.0, -40.0)
const DUR := 8.2

var lv: PalaceLevel
var yacht: Node3D
var pod: Node3D
var _bay_l: Node3D
var _bay_r: Node3D
var _bay: Node3D
var _trail: MeshInstance3D
var _sun_l: DirectionalLight3D
var _petals: Array[Node3D] = []
var _earth_m: ShaderMaterial


func build(level: PalaceLevel) -> void:
	lv = level
	name = "Space"
	position = Vector3.ZERO
	var sm := ShaderMaterial.new()
	sm.shader = load("res://levels/palace/palace_sky_space.gdshader")
	sm.set_shader_parameter(&"centre", AT)
	sm.set_shader_parameter(&"mode", 0)
	var sky := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 9000.0
	sp.height = 18000.0
	sp.radial_segments = 32
	sp.rings = 16
	sky.mesh = sp
	sky.material_override = sm
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky.position = AT
	add_child(sky)
	_earth_m = ShaderMaterial.new()
	_earth_m.shader = load("res://levels/palace/palace_earth.gdshader")
	_earth_m.set_shader_parameter(&"day", load("res://assets/third-party/nasa/earth_day_2048.jpg"))
	_earth_m.set_shader_parameter(&"sun_dir", SUN)
	_earth_m.set_shader_parameter(&"centre", EARTH_C)
	_earth_m.set_shader_parameter(&"spin", 2.1)      # (turned so the Americas and the Atlantic face the shot)
	var e := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = EARTH_R
	es.height = EARTH_R * 2.0
	es.radial_segments = 96
	es.rings = 48
	e.mesh = es
	e.material_override = _earth_m
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e.position = EARTH_C
	add_child(e)
	var hm := ShaderMaterial.new()
	hm.shader = sm.shader
	hm.set_shader_parameter(&"centre", EARTH_C)
	hm.set_shader_parameter(&"mode", 1)
	hm.set_shader_parameter(&"sun_dir", SUN)
	var halo := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = EARTH_R * 1.035
	hs.height = EARTH_R * 2.07
	hs.radial_segments = 96
	hs.rings = 48
	halo.mesh = hs
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = EARTH_C
	add_child(halo)
	var sun := MeshInstance3D.new()      # the sun itself: a hot disc far off (the bloom makes it a sun)
	var sd := SphereMesh.new()
	sd.radius = 60.0
	sd.height = 120.0
	sun.mesh = sd
	var sunm := StandardMaterial3D.new()
	sunm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sunm.albedo_color = Color(1.0, 0.95, 0.85) * 6.0
	sun.material_override = sunm
	sun.position = AT + SUN.normalized() * 7000.0
	add_child(sun)
	_sun_l = DirectionalLight3D.new()
	_sun_l.light_color = Color(1.0, 0.95, 0.88)
	_sun_l.light_energy = 2.4
	_sun_l.shadow_enabled = false
	_sun_l.visible = false
	add_child(_sun_l)
	_sun_l.look_at_from_position(AT, AT - SUN, Vector3.UP)
	# the yacht, and the pod in its bay
	yacht = (load("res://assets/palace/yacht.glb") as PackedScene).instantiate()
	add_child(yacht)
	_bay_l = yacht.find_child("bay_door_L", true, false) as Node3D
	_bay_r = yacht.find_child("bay_door_R", true, false) as Node3D
	_bay = yacht.find_child("bay", true, false) as Node3D
	pod = (load("res://assets/palace/drop_pod.glb") as PackedScene).instantiate()
	add_child(pod)
	pod.scale = Vector3.ONE
	var tr := CylinderMesh.new()      # the pod's re-entry streak: a long additive cone behind it
	tr.top_radius = 0.0
	tr.bottom_radius = 1.0
	tr.height = 1.0
	tr.radial_segments = 12
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.albedo_color = Color(1.0, 0.55, 0.2, 0.8)
	tm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail = MeshInstance3D.new()
	_trail.mesh = tr
	_trail.material_override = tm
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)
	visible = false


## The shot on (the space's night) or off (the site's)
func shot(v: bool) -> void:
	visible = v
	_sun_l.visible = v
	Game.view.sun.visible = not v
	var dome: Node = lv.city.root.find_child("NightSky", false, false)
	if dome != null:
		(dome as Node3D).visible = not v
	if v:
		Game.view.apply_render_state({"background": Color(0.0, 0.0, 0.0), "fog": null, "clip": [0.5, 20000.0], "hemi": [Color(0.06, 0.08, 0.14), Color(0.0, 0.0, 0.0), 0.8]})
	else:
		lv.restore_render_state()


## The shot at u (0..1 of DUR): the yacht glides in over the Earth from the left, slows, its bay opens, the pod drops out and falls away toward the Earth, burning
## Returns the camera's [pos, look].
func pose(u: float) -> Array:
	var tt := u * DUR
	var glide := Cutscene.ease_out(clampf(tt / 4.6, 0.0, 1.0))
	var yp := AT + Vector3(-330.0, -36.0, 260.0).lerp(Vector3(-20.0, -46.0, 250.0), glide)
	yacht.global_transform = Transform3D(Basis(Vector3.UP, PI / 2.0) * Basis(Vector3.FORWARD, -0.06 + 0.03 * sin(tt * 0.7)), yp)
	var door := Cutscene.ease_(Cutscene.seg(tt, 4.3, 5.2)) * deg_to_rad(80.0)
	if _bay_l != null:
		_bay_l.rotation.z = door
		_bay_r.rotation.z = -door
	var bay_at := _bay.global_position if _bay != null else yp + Vector3(0.0, -7.0, 0.0)
	var drop := Cutscene.seg(tt, 5.3, DUR)
	var fall := drop * drop * 260.0
	pod.global_transform = Transform3D(yacht.global_transform.basis.orthonormalized() * Basis(Vector3.RIGHT, drop * 0.6), bay_at + Vector3(0.0, -fall - drop * 4.0, fall * 0.55))
	pod.visible = tt > 4.6
	_trail.visible = drop > 0.25
	if _trail.visible:
		var tail := pod.global_position + Vector3(0.0, 1.0, -0.55).normalized() * (8.0 + drop * 60.0)
		_trail.global_transform = PalaceKit.span(pod.global_position + Vector3(0.0, 2.0, 0.0), tail, 2.6 + drop * 2.0, 2.6 + drop * 2.0)
		(_trail.material_override as StandardMaterial3D).albedo_color.a = 0.25 + 0.5 * drop
	# the camera: a slow push past the yacht's tail toward the Earth's limb, turning to follow the pod down at the end
	var cam := CAM + Vector3(-20.0, 0.0, 10.0) * u
	var look := AT + Vector3(-120.0, -140.0, 600.0).lerp(Vector3(10.0, -220.0, 520.0), Cutscene.ease_(u))
	look = look.lerp(pod.global_position, Cutscene.ease_(Cutscene.seg(tt, 5.6, DUR)) * 0.5)
	return [cam, look]
