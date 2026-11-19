class_name PuppyWarp
extends Node3D
## The hub puppy's thank-you: a golden aura swells off him, then the player zaps out of the dialogue shot in a burst of sparks and a column of light. Made once at hub load (particles, materials, lights), played by HubLevel from the puppy's dialogue.
## It runs on its own _process: the dialogue holds the game's simulation (and with it the FX pools), so nothing here goes through Game.fx.

const GOLD := Color(1.0, 0.74, 0.3)
const WHITE_GOLD := Color(1.0, 0.93, 0.72)

const BEAM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float k = 0.0;
void fragment() {
	float face = abs(dot(NORMAL, VIEW));            // bright down the middle of the column, soft at its edges
	float ends = smoothstep(0.0, 0.18, UV.y) * smoothstep(1.0, 0.55, UV.y);
	ALBEDO = tint.rgb * k * (0.25 + 2.6 * pow(face, 3.0)) * ends;
}
"""

var _aura: GPUParticles3D
var _aura_light: OmniLight3D
var _burst: GPUParticles3D
var _beam: MeshInstance3D
var _beam_mat: ShaderMaterial
var _flash: OmniLight3D
var _aura_k := 0.0          # 0..1, eases toward _aura_to
var _aura_to := 0.0
var _zap_t := -1.0          # seconds since the zap, -1 when none


func _init() -> void:
	name = "PuppyWarp"


func _ready() -> void:
	var dot := _dot_tex()
	# the aura: soft gold motes rising off him
	_aura = GPUParticles3D.new()
	_aura.amount = 130
	_aura.lifetime = 1.3
	_aura.emitting = false
	_aura.visibility_aabb = AABB(Vector3(-1.5, -0.5, -1.5), Vector3(3.0, 3.5, 3.0))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.5
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.0, 0.9, 0.0)
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	pm.scale_curve = _curve_tex([Vector2(0.0, 0.2), Vector2(0.25, 1.0), Vector2(1.0, 0.0)])
	pm.color_ramp = _ramp([WHITE_GOLD, GOLD, Color(GOLD, 0.0)])
	_aura.process_material = pm
	_aura.draw_pass_1 = _quad(0.07, dot, true)
	add_child(_aura)
	_aura_light = OmniLight3D.new()
	_aura_light.light_color = GOLD
	_aura_light.omni_range = 3.5
	_aura_light.light_energy = 0.0
	_aura_light.visible = false
	add_child(_aura_light)
	# the zap: one burst of streaks flying off the body
	_burst = GPUParticles3D.new()
	_burst.amount = 110
	_burst.lifetime = 0.55
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.emitting = false
	_burst.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_burst.visibility_aabb = AABB(Vector3(-4.0, -1.0, -4.0), Vector3(8.0, 8.0, 8.0))
	var bm := ParticleProcessMaterial.new()
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	bm.emission_box_extents = Vector3(0.22, 0.85, 0.22)
	bm.direction = Vector3.UP
	bm.spread = 75.0
	bm.initial_velocity_min = 2.5
	bm.initial_velocity_max = 7.5
	bm.gravity = Vector3(0.0, 2.0, 0.0)
	bm.damping_min = 5.0
	bm.damping_max = 9.0
	bm.scale_curve = _curve_tex([Vector2(0.0, 1.0), Vector2(1.0, 0.0)])
	bm.color_ramp = _ramp([Color(1.0, 1.0, 1.0), WHITE_GOLD, Color(GOLD, 0.0)])
	_burst.process_material = bm
	var streak := _quad(0.05, dot, false)
	(streak as QuadMesh).size = Vector2(0.045, 0.32)
	_burst.draw_pass_1 = streak
	add_child(_burst)
	# the column of light he goes up in
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.42
	cyl.height = 4.0
	cyl.radial_segments = 20
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var sh := Shader.new()
	sh.code = BEAM_SHADER
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = sh
	_beam_mat.set_shader_parameter(&"tint", WHITE_GOLD)
	_beam = MeshInstance3D.new()
	_beam.mesh = cyl
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)
	_flash = OmniLight3D.new()
	_flash.light_color = WHITE_GOLD
	_flash.omni_range = 6.0
	_flash.visible = false
	add_child(_flash)
	set_process(false)


## The aura swells off whatever stands at `at` (its feet)
func aura(at: Vector3) -> void:
	_aura.global_position = at + Vector3(0.0, 0.45, 0.0)
	_aura_light.global_position = at + Vector3(0.0, 0.7, 0.0)
	_aura.emitting = true
	_aura_light.visible = true
	_aura_to = 1.0
	set_process(true)


func aura_off() -> void:
	_aura_to = 0.0
	_aura.emitting = false


## The player goes: sparks off his body and a column of light, at his feet `at`
func zap(at: Vector3) -> void:
	_burst.global_position = at + Vector3(0.0, 0.9, 0.0)
	_burst.restart()
	_burst.emitting = true
	_beam.global_position = at + Vector3(0.0, 1.7, 0.0)
	_flash.global_position = at + Vector3(0.0, 1.0, 0.0)
	_beam.visible = true
	_flash.visible = true
	_zap_t = 0.0
	set_process(true)


func _process(dt: float) -> void:
	_aura_k = move_toward(_aura_k, _aura_to, dt / (1.1 if _aura_to > _aura_k else 0.5))
	_aura_light.light_energy = 2.2 * _aura_k * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012))
	_aura.amount_ratio = maxf(0.05, _aura_k)
	if _aura_k <= 0.0 and _aura_to <= 0.0:
		_aura_light.visible = false
	if _zap_t >= 0.0:
		_zap_t += dt
		var k := clampf(1.0 - _zap_t / 0.45, 0.0, 1.0)
		var pop := minf(1.0, _zap_t / 0.05)      # in at once, out over 0.45 s
		_beam_mat.set_shader_parameter(&"k", 1.6 * pop * k * k)
		_beam.scale = Vector3(1.0 - 0.75 * (1.0 - k), 1.0 + 0.6 * (1.0 - k), 1.0 - 0.75 * (1.0 - k))      # it thins and stretches as it fades
		_flash.light_energy = 9.0 * pop * k * k
		if k <= 0.0:
			_zap_t = -1.0
			_beam.visible = false
			_flash.visible = false
	if _zap_t < 0.0 and _aura_k <= 0.0 and _aura_to <= 0.0:
		set_process(false)


static func _dot_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	g.add_point(0.35, Color(1.0, 1.0, 1.0, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


static func _quad(s: float, tex: Texture2D, billboard: bool) -> QuadMesh:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.albedo_color = Color(2.2, 2.2, 2.2)      # over 1: the glow catches it
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var q := QuadMesh.new()
	q.size = Vector2(s, s)
	q.material = m
	return q


static func _ramp(cs: Array) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in cs.size():
		offs.append(float(i) / float(cs.size() - 1))
		cols.append(cs[i])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve_tex(pts: Array) -> CurveTexture:
	var c := Curve.new()
	for p: Vector2 in pts:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t
