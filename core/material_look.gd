extends RefCounted
## MATERIAL LOOK (JS material-look.js): a sky / ground reflection on every PBR material, patched into the shaders Godot generates for StandardMaterial3D. No material changes class.
##
## METAL THAT REFLECTS SOMETHING. Without an environment map a PBR material reflects pure black, so bare metal only ever shows its sun highlight and every glossy surface looks like matte paint.
## Here the reflection vector picks between the level's own hemisphere light colours (sky above, ground below), with the horizon line softening as the roughness goes up. It costs a few
## instructions and follows each level's ambient by itself. Non-metals get only a trace of it: their fresnel would otherwise add a little sky to every surface, and a little on a near-black
## floor is a lot on screen (at full strength this lifted a whole level's picture by 20% and greyed its blacks).
##
## WHY A PATCH AND NOT GODOT'S SKY REFLECTION: Godot's reflection scale is one F0 for direct light and the sky alike, so dielectrics cannot have 0.12 of it while metals have 1.25. Measured with
## the sky as reflection source, a #181818 glossy ball drew 29 where the JS draws 10. So Environment.reflected_light_source stays DISABLED and this adds the JS term, through EMISSION (added
## before fog and tone mapping, as `radiance` is in three.js).
##
## HOW: the StandardMaterial3D keeps its class and its uniforms; its RID is pointed at a shader written here, the one Godot would generate for its feature set (same text, same uniform names:
## BaseMaterial3D._update_shader, whose output script cannot read) plus one block at the end of fragment(). So a material somebody holds and tweaks (emission for a hit flash, albedo, roughness)
## keeps working as it always did. One shader per feature set, built when a material is first seen (level load). A feature this file does not write (rim, clearcoat, triplanar...) leaves that
## material on Godot's own shader, without the reflection. A later change of feature flags on a material puts Godot's own shader back too: nothing else breaks, and flags should not change during
## play anyway, because that compiles. Lambert materials (metallic_specular 0), unshaded materials and materials with specular off are left alone, as in the JS.

const BLOCK := """
	{	// material-look.js: the reflection vector picks between the hemisphere light's sky and ground colours
		vec3 pf_r = reflect(-VIEW, NORMAL);
		float pf_rough = max(ROUGHNESS, 0.0525);
		float pf_edge = 0.05 + pf_rough * 0.95;
		vec3 pf_rad = mix(prog_hemi_ground, prog_hemi_sky, smoothstep(-pf_edge, pf_edge, dot(pf_r, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz))) * 0.31830988 * mix(0.12, 1.25, METALLIC);
		vec4 pf_q = pf_rough * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
		float pf_a = min(pf_q.x * pf_q.x, pow(2.0, -9.28 * clamp(dot(NORMAL, VIEW), 0.0, 1.0))) * pf_q.x + pf_q.y;
		vec2 pf_fab = vec2(-1.04, 1.04) * pf_a + pf_q.zw;
		EMISSION += pf_rad * (mix(vec3(0.16 * SPECULAR * SPECULAR), ALBEDO, METALLIC) * pf_fab.x + pf_fab.y);
		// Godot multiplies direct specular by 1 + f0 * (1 / dfg - 1), multi-scattering energy three.js does not have: a rough metal in the sun came out 1.5 x too bright. F0 is what the lights see
		// from here on (the term above has used the real one), so it is lowered by exactly that factor.
		vec3 pf_k = vec3(max(1.0 / max(pf_fab.x + pf_fab.y, 0.05) - 1.0, 0.0001));
		ALBEDO = mix(ALBEDO, (sqrt(1.0 + 4.0 * pf_k * ALBEDO) - 1.0) / (2.0 * pf_k), METALLIC);
	}
"""

var _shaders: Dictionary = {}    # shader text -> Shader (kept alive here)
var _pending: Array = []
var _held: Array = []            # textures handed to the server by RID
var _seen: Dictionary = {}       # material instance id -> true


func _init() -> void:
	RenderingServer.global_shader_parameter_add(&"prog_hemi_sky", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
	RenderingServer.global_shader_parameter_add(&"prog_hemi_ground", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
	RenderingServer.global_shader_parameter_add(&"prog_exposure", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)     # (levels/shaders/common.gdshaderinc)
	RenderingServer.global_shader_parameter_add(&"prog_tone_on", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	RenderingServer.global_shader_parameter_add(&"prog_smog", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)     # FOINT CITY's haze colour (levels/hub/hub_level.gd)
	FlashLights.declare()      # the brief lights of play, for the painted world (core/flash_lights.gd)


## JS hemisphereLights[0].skyColor / groundColor: linear colour times intensity.
func set_hemi(sky: Vector3, ground: Vector3) -> void:
	RenderingServer.global_shader_parameter_set(&"prog_hemi_sky", sky)
	RenderingServer.global_shader_parameter_set(&"prog_hemi_ground", ground)


## A JS onBeforeCompile hook on this material: the same generated shader, with what the hook adds. extra: decl (uniforms, varyings, functions), vert (end of vertex()), frag (before the reflection), params (name -> value). Runs last, so it wins over adapt().
func patch(b: StandardMaterial3D, extra: Dictionary) -> bool:
	var code := _code(b, extra)
	if code == "":
		return false
	var s: Shader = _shaders.get(code)
	if s == null:
		s = Shader.new()
		s.code = code
		_shaders[code] = s
	_seen[b.get_instance_id()] = true
	var params: Dictionary = extra.get("params", {})
	for k: String in params:
		var pv: Variant = params[k]
		if pv is Resource:      # (the server takes a texture by its RID, and does not hold on to it)
			_held.append(pv)
			pv = (pv as Resource).get_rid()
		RenderingServer.material_set_param(b.get_rid(), StringName(k), pv)
	_pending.append([b, s])
	if _pending.size() == 1:
		(Engine.get_main_loop() as SceneTree).process_frame.connect(_flush, CONNECT_ONE_SHOT)
	return true


## The text BaseMaterial3D._update_shader writes for this feature set, plus BLOCK. "" = a feature that is not written here.
func _code(b: StandardMaterial3D, extra: Dictionary = {}) -> String:
	if b.detail_enabled or b.rim_enabled or b.clearcoat_enabled or b.anisotropy_enabled or b.heightmap_enabled or b.subsurf_scatter_enabled or b.backlight_enabled or b.refraction_enabled \
			or b.proximity_fade_enabled or b.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED or b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or b.uv1_triplanar \
			or b.use_point_size or b.grow or b.use_particle_trails or b.emission_on_uv2 or b.ao_on_uv2 or b.emission_operator != BaseMaterial3D.EMISSION_OP_ADD or b.albedo_texture_msdf \
			or b.stencil_mode != BaseMaterial3D.STENCIL_MODE_DISABLED or b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH or b.diffuse_mode > BaseMaterial3D.DIFFUSE_LAMBERT \
			or b.specular_mode != BaseMaterial3D.SPECULAR_SCHLICK_GGX or b.fixed_size or b.texture_filter > BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
		return ""
	var flt: String = ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"][b.texture_filter]
	flt += ", repeat_enable" if b.texture_repeat else ", repeat_disable"
	var c := "shader_type spatial;\nrender_mode "
	c += ["blend_mix", "blend_add", "blend_sub", "blend_mul", "blend_premul_alpha"][b.blend_mode]
	c += [", depth_draw_opaque", ", depth_draw_always", ", depth_draw_never"][b.depth_draw_mode]
	c += [", cull_back", ", cull_front", ", cull_disabled"][b.cull_mode]
	c += ", diffuse_burley" if b.diffuse_mode == BaseMaterial3D.DIFFUSE_BURLEY else ", diffuse_lambert"
	c += ", specular_schlick_ggx"
	var lit := b.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if not lit:
		c += ", unshaded"
	if b.no_depth_test:
		c += ", depth_test_disabled"
	if b.disable_receive_shadows:
		c += ", shadows_disabled"
	if b.disable_ambient_light:
		c += ", ambient_light_disabled"
	if b.disable_fog:
		c += ", fog_disabled"
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
		c += ", depth_prepass_alpha"
	c += ";\n\nuniform vec4 albedo : source_color;\nuniform sampler2D texture_albedo : source_color, %s;\n" % flt
	c += "uniform float roughness : hint_range(0.0, 1.0);\nuniform sampler2D texture_metallic : hint_default_white, %s;\nuniform vec4 metallic_texture_channel;\n" % flt
	var rc: int = b.roughness_texture_channel
	c += "uniform sampler2D texture_roughness : %s, %s;\n" % [["hint_roughness_r", "hint_roughness_g", "hint_roughness_b", "hint_roughness_a", "hint_roughness_gray"][rc], flt]
	c += "uniform float specular : hint_range(0.0, 1.0, 0.01);\nuniform float metallic : hint_range(0.0, 1.0, 0.01);\n"
	if b.emission_enabled:
		c += "uniform sampler2D texture_emission : source_color, hint_default_black, %s;\nuniform vec4 emission : source_color;\nuniform float emission_energy : hint_range(0.0, 100.0, 0.01);\n" % flt
	if b.normal_enabled:
		c += "uniform sampler2D texture_normal : hint_roughness_normal, %s;\nuniform float normal_scale : hint_range(-16.0, 16.0);\n" % flt
	if b.ao_enabled:
		c += "uniform sampler2D texture_ambient_occlusion : hint_default_white, %s;\nuniform vec4 ao_texture_channel;\nuniform float ao_light_affect : hint_range(0.0, 1.0, 0.01);\n" % flt
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		c += "uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.001);\n"
	c += "uniform vec3 uv1_scale;\nuniform vec3 uv1_offset;\nglobal uniform vec3 prog_hemi_sky;\nglobal uniform vec3 prog_hemi_ground;\n" + String(extra.get("decl", "")) + "\n\nvoid vertex() {\n"
	if b.vertex_color_is_srgb:
		c += "\tif (!OUTPUT_IS_SRGB) {\n\t\tCOLOR.rgb = mix(pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)), COLOR.rgb * (1.0 / 12.92), lessThan(COLOR.rgb, vec3(0.04045)));\n\t}\n"
	c += "\tUV = UV * uv1_scale.xy + uv1_offset.xy;\n" + String(extra.get("vert", "")) + "\n}\n\nvoid fragment() {\n\tvec2 base_uv = UV;\n\tvec4 albedo_tex = texture(texture_albedo, base_uv);\n"
	if b.vertex_color_use_as_albedo:
		c += "\talbedo_tex *= COLOR;\n"
	c += "\tALBEDO = albedo.rgb * albedo_tex.rgb;\n\tfloat metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);\n\tMETALLIC = metallic_tex * metallic;\n\tSPECULAR = specular;\n"
	var ch: String = ["vec4(1.0, 0.0, 0.0, 0.0)", "vec4(0.0, 1.0, 0.0, 0.0)", "vec4(0.0, 0.0, 1.0, 0.0)", "vec4(0.0, 0.0, 0.0, 1.0)", "vec4(0.333333, 0.333333, 0.333333, 0.0)"][rc]
	c += "\tfloat roughness_tex = dot(texture(texture_roughness, base_uv), %s);\n\tROUGHNESS = roughness_tex * roughness;\n" % ch
	if b.emission_enabled:
		c += "\tvec3 emission_tex = texture(texture_emission, base_uv).rgb;\n\tEMISSION = (emission.rgb + emission_tex) * emission_energy;\n"
	if b.normal_enabled:
		c += "\tNORMAL_MAP = texture(texture_normal, base_uv).rgb;\n\tNORMAL_MAP_DEPTH = normal_scale;\n"
	if b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		c += "\tALPHA *= albedo.a * albedo_tex.a;\n"
	if b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		c += "\tALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;\n"
	if b.ao_enabled:
		c += "\tAO = dot(texture(texture_ambient_occlusion, base_uv), ao_texture_channel);\n\tAO_LIGHT_AFFECT = ao_light_affect;\n"
	c += String(extra.get("frag", "")) + "\n"
	# Lambert materials, unshaded materials and materials with specular off have no reflection in the JS (see adapt)
	if lit and not (b.metallic_specular <= 0.0 and b.metallic <= 0.0) and b.specular_mode != BaseMaterial3D.SPECULAR_DISABLED:
		c += BLOCK
	return c + "}\n"


## Give this material the reflection, if it is the kind that has one in the JS. Safe to call again.
func adapt(m: Material) -> void:
	var b := m as StandardMaterial3D
	if b == null:
		return
	var key := b.get_instance_id()
	if _seen.has(key):
		return
	_seen[key] = true
	if b.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or (b.metallic_specular <= 0.0 and b.metallic <= 0.0) or b.specular_mode == BaseMaterial3D.SPECULAR_DISABLED:
		return
	var code := _code(b)
	if code == "":
		return
	var s: Shader = _shaders.get(code)
	if s == null:
		s = Shader.new()
		s.code = code
		_shaders[code] = s
	_pending.append([b, s])
	if _pending.size() == 1:
		(Engine.get_main_loop() as SceneTree).process_frame.connect(_flush, CONNECT_ONE_SHOT)


## At the start of the next frame, after Godot's own queue of materials to update: a material made this frame has its shader put in by that queue first, and this one replaces it.
func _flush() -> void:
	for p: Array in _pending:
		var b: StandardMaterial3D = p[0]
		var s: Shader = p[1]
		RenderingServer.material_set_shader(b.get_rid(), s.get_rid())
	_pending.clear()


## Every material on this node, not its children.
func adapt_node(n: Node) -> void:
	var g := n as GeometryInstance3D
	if g == null:
		return
	if g.material_override != null:
		adapt(g.material_override)
		return
	var mi := n as MeshInstance3D
	if mi != null:
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var o := mi.get_surface_override_material(i)
				adapt(o if o != null else mi.mesh.surface_get_material(i))
		return
	var mm := n as MultiMeshInstance3D
	if mm != null and mm.multimesh != null and mm.multimesh.mesh != null:
		for i in mm.multimesh.mesh.get_surface_count():
			adapt(mm.multimesh.mesh.surface_get_material(i))


## A whole subtree (for meshes given their material after they entered the tree; everything else is caught when it is added, see View.setup).
func adapt_tree(root: Node) -> void:
	adapt_node(root)
	for c in root.get_children():
		adapt_tree(c)
