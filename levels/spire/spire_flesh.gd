class_name SpireFlesh
extends RefCounted
## The spire's living flesh on the GPU (JS levels/spire/flesh.js): one set of shared values drives every flesh material. It swells along its normals on the heartbeat, or sways like a hanging tendril; the vein network glows on the beat; wet patches get a hot sheen; wrinkles and pores tilt the normal; grazing angles glow deep red; membranes get a fresnel rim. The exporter hands fleshify's aFlesh attribute over as UV2 = (vein, swell), UV.x = wetness. Her wet skin (flesh-sculpt.js wetSkin) gets its rim and vein glow here too.
## Patched into Godot's own generated material by core/material_look.gd, so the level's lights and fog still apply. The numbers per material come from the export's shader work list.
## Spores, drips and the route beacons' halos are three.js Points: the glTF keeps them as 1 px points, so each becomes a MultiMesh of quads with the same falling or drifting maths in the vertex shader.

const NOISE := """float flH(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float flN(vec3 x) { vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(flH(i), flH(i + vec3(1,0,0)), f.x), mix(flH(i + vec3(0,1,0)), flH(i + vec3(1,1,0)), f.x), f.y), mix(mix(flH(i + vec3(0,0,1)), flH(i + vec3(1,0,1)), f.x), mix(flH(i + vec3(0,1,1)), flH(i + vec3(1,1,1)), f.x), f.y), f.z); }"""
const POINTS := """shader_type spatial;
render_mode %s, unshaded, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://levels/shaders/common.gdshaderinc"
global uniform float prog_flesh_time;
uniform float kind = 0.0;
uniform float opacity = 1.0;
uniform float soft = 0.0;
uniform float size = 0.16;
uniform float p_a = 1.0;      // (not a, b, c: the shared add_display has locals of those names and reads these instead, which all but put out every additive point)
uniform float p_b = 1.0;
uniform float p_c = 1.0;
varying vec4 v_col;
void vertex() {
	float s = INSTANCE_CUSTOM.r;
	vec3 o = MODEL_MATRIX[3].xyz;
	if (kind > 1.5) {
		float dk = mod(prog_flesh_time * p_b * (0.8 + 0.4 * s) + s * 37.0, p_a + 1.5);
		o.y -= max(0.0, dk - 1.5) * max(0.0, dk - 1.5) / p_a;
	} else if (kind > 0.5) {
		float sk = s * 6.2831;
		o.x += sin(prog_flesh_time * 0.23 + sk) * p_c;
		o.z += cos(prog_flesh_time * 0.19 + sk * 1.3) * p_c;
		o.y += mod(prog_flesh_time * p_b * (0.6 + 0.8 * s) + s * 97.0, p_a);
	}
	vec4 view = VIEW_MATRIX * vec4(o, 1.0);
	view.xy += VERTEX.xy * size / PROJECTION_MATRIX[1][1];      // (world-size points as three.js sizeAttenuation draws them)
	POSITION = PROJECTION_MATRIX * view;
	v_col = COLOR;
}
void fragment() {
	float k = 1.0;
	if (soft > 0.5) {
		float d = length(UV * 2.0 - vec2(1.0));
		k = d < 0.25 ? mix(1.0, 0.45, d / 0.25) : mix(0.45, 0.0, clamp((d - 0.25) / 0.75, 0.0, 1.0));
	}
	%s
}
"""

var L: SpireLevel
var _veins: Array = []
var _column: Array = []
var _skin: Array[RID] = []
var _named_pts: Dictionary = {}
var _halo: Array[ShaderMaterial] = []
var _shaders: Dictionary = {}
var _bile := RID()
static var _globals_added := false


func _init(level: SpireLevel) -> void:
	L = level
	if not _globals_added:      # (session-long: the server's own list of them is editor-only)
		_globals_added = true
		for g: StringName in [&"prog_flesh_time", &"prog_flesh_beat", &"prog_flesh_breath"]:
			RenderingServer.global_shader_parameter_add(g, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	var seen := {}
	var points: Array[MeshInstance3D] = []
	var walk: Array[Node] = [L]
	while walk.size() > 0:
		var n: Node = walk.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
			var m: ArrayMesh = (n as MeshInstance3D).mesh
			for s in m.get_surface_count():
				if m.surface_get_primitive_type(s) == Mesh.PRIMITIVE_POINTS:
					points.append(n)
					continue
				var mt := m.surface_get_material(s) as StandardMaterial3D
				if mt == null or seen.has(mt) or not mt.has_meta("extras"):
					continue
				seen[mt] = true
				var x: Dictionary = mt.get_meta("extras")
				var obc := String(x.get("obc", ""))
				if obc != "":
					mt.emission_enabled = true
				if obc.ends_with("_09d9") and int(x.get("obc_var", 0)) == 4:
					_column.append(mt)
				if obc.ends_with("_1b6e"):
					_patch_bile(mt)
				elif obc.ends_with("_09d9"):
					_patch_flesh(mt, obc, int(x.get("obc_var", 0)))
				elif obc.ends_with("_78d1"):
					_patch_skin(mt, obc, int(x.get("obc_var", 0)))
		walk.append_array(n.get_children())
	for n: MeshInstance3D in points:
		_build_points(n)
	_veins = L._mat_list("spVein")


func _uniforms(obc: String, variant: int) -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/levels/spire/shaders/" + obc + ".json"))
	if not (v is Dictionary):
		return {}
	var list: Array = (v as Dictionary).get("variants", [])
	var d: Dictionary = list[mini(variant, list.size() - 1)] if not list.is_empty() else {}
	return d


func _vec(u: Dictionary, k: String, d: Vector3) -> Vector3:
	var q: Variant = (u.get(k, {}) as Dictionary).get("value")
	return Vector3(q[0], q[1], q[2]) if q is Array else d


func _num(u: Dictionary, k: String, d: float) -> float:
	var q: Variant = (u.get(k, {}) as Dictionary).get("value")
	return float(q) if q != null else d


func _patch_flesh(m: StandardMaterial3D, obc: String, variant: int) -> void:
	var u: Dictionary = _uniforms(obc, variant).get("uniforms", {})
	var vein := _vec(u, "uVein", Vector3(1.0, 0.02315, 0.04231))
	var pulse := _num(u, "uPulse", 0.05)
	var sway := _num(u, "uSway", 0.0)
	var wet := _num(u, "uWet", 1.0)
	var has_rim := u.has("uRim")
	var rim := _vec(u, "uRim", Vector3.ZERO)
	var decl := "global uniform float prog_flesh_time;\nglobal uniform float prog_flesh_beat;\nglobal uniform float prog_flesh_breath;\nvarying vec3 v_fl;\nvarying vec3 v_flp;\n" + NOISE
	var vert := "v_fl = vec3(UV2.x, UV2.y, UV.x); v_flp = VERTEX;\n"
	if sway > 0.0:
		vert += "VERTEX.x += sin(prog_flesh_time * 1.1 + VERTEX.y * 0.55 + VERTEX.z * 0.3) * UV2.y * %f; VERTEX.z += cos(prog_flesh_time * 0.83 + VERTEX.y * 0.4 + VERTEX.x * 0.5) * UV2.y * %f;" % [sway, sway]
	else:
		vert += "VERTEX += NORMAL * UV2.y * %f * (prog_flesh_beat + 0.35 * sin(prog_flesh_time * 1.3 + VERTEX.y * 0.7 + VERTEX.x * 0.4) + 0.4 * prog_flesh_breath);" % pulse
	var frag := """float flPore = flN(v_flp * 11.0);
	ALBEDO *= 0.86 + 0.22 * flN(v_flp * 3.1 + 7.0);
	// capillary web: thin ridged-noise lines, darker and purplish like veins under skin
	float flC1 = abs(flN(v_flp * 2.4 + vec3(3.1, 0.0, 5.7)) - 0.5), flCap = 1.0 - smoothstep(0.0, min(0.03, fwidth(flC1) * 1.6), flC1);
	float flC2 = abs(flN(v_flp * 4.1 + 11.0) - 0.5), flCap2 = 1.0 - smoothstep(0.0, min(0.022, fwidth(flC2) * 1.3), flC2);
	float flFar = smoothstep(0.02, 0.08, length(fwidth(v_flp))); flCap *= flFar; flCap2 *= flFar;   // a far-field detail only: up close it would read as contour lines
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.5, 0.22, 0.34), flCap * 0.3 + flCap2 * 0.12);
	float flGlint = flN(v_flp * 23.0 + prog_flesh_time * 0.15);
	SPECULAR *= mix(0.3, 1.0 + WET_, v_fl.z) * (0.75 + 0.5 * flPore) * (1.0 + 1.4 * smoothstep(0.72, 0.95, flGlint) * v_fl.z);
	// wrinkles + pores + raised capillaries as a procedural bump
	float flH0 = flN(v_flp * 1.6) * 0.6 + flN(v_flp * 4.7 + 2.0) * 0.18 - flPore * 0.05 + flCap * 0.12 + flCap2 * 0.04;
	{ vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX); vec3 r1 = cross(dy, NORMAL), r2 = cross(NORMAL, dx);
	float det = dot(dx, r1); vec3 g = sign(det) * ((dFdx(flH0) * 0.22) * r1 + (dFdy(flH0) * 0.22) * r2); NORMAL = normalize(abs(det) * NORMAL - g); }
	EMISSION += VEIN_ * v_fl.x * (0.18 + 1.5 * prog_flesh_beat) + VEIN_ * flCap * 0.012 * (0.4 + prog_flesh_beat);
	// subsurface-style back-scatter: grazing angles glow deep red, as if light passes through the meat
	float flSSS = pow(1.0 - abs(dot(normalize(VIEW), NORMAL)), 3.0);
	EMISSION += vec3(0.3, 0.015, 0.025) * flSSS * (0.4 + 0.3 * prog_flesh_beat) * ALBEDO.r * 0.7;"""
	frag = frag.replace("WET_", "%f" % wet).replace("VEIN_", "vec3(%f, %f, %f)" % [vein.x, vein.y, vein.z])
	if has_rim:
		frag += "\n	float flRim = pow(1.0 - abs(dot(normalize(VIEW), NORMAL)), 2.2); EMISSION += vec3(%f, %f, %f) * flRim * (0.45 + 0.8 * prog_flesh_beat); ALPHA *= mix(0.45, 1.0, flRim);" % [rim.x, rim.y, rim.z]
	Game.view.material_look.patch(m, {"decl": decl, "vert": vert, "frag": frag})


## her wet skin: a back-lit rim, and veins that glow from a map on her skin
func _patch_skin(m: StandardMaterial3D, obc: String, variant: int) -> void:
	var u: Dictionary = _uniforms(obc, variant).get("uniforms", {})
	var sc := _vec(u, "uSssC", Vector3(0.32314, 0.00368, 0.00913))
	var decl := "uniform float uSssK = %f;\nuniform float uGlow = 0.0;\n" % _num(u, "uSssK", 0.55)
	var frag := "EMISSION += vec3(%f, %f, %f) * pow(1.0 - abs(dot(normalize(VIEW), NORMAL)), 2.6) * uSssK * (0.6 + 0.6 * ALBEDO.r);" % [sc.x, sc.y, sc.z]
	var params := {}
	var map: Dictionary = u.get("uGlowMap", {})
	if map.get("file") != null:
		var gc := _vec(u, "uGlowC", Vector3(1.0, 0.04231, 0.01033))
		decl += "uniform sampler2D uGlowMap : filter_linear_mipmap, repeat_enable;\n"
		frag += "\n	EMISSION += vec3(%f, %f, %f) * texture(uGlowMap, base_uv).r * uGlow;" % [gc.x, gc.y, gc.z]
		params["uGlowMap"] = load("res://assets/" + String(map.file))
	if Game.view.material_look.patch(m, {"decl": decl, "frag": frag, "params": params}) and map.get("file") != null:
		_skin.append(m.get_rid())


func set_skin(sss_k: float, glow: float) -> void:
	for r: RID in _skin:
		RenderingServer.material_set_param(r, &"uSssK", sss_k)
		RenderingServer.material_set_param(r, &"uGlow", glow)


## the bile (JS levels/spire/bile.js): ripples tilt the highlights like refraction, the middle of the pool reads deep and murky, foam along the shore, a caustic web glowing up from beneath the surface
func _patch_bile(m: StandardMaterial3D) -> void:
	var decl := "uniform float bileTime = 0.0;
uniform float bileWarning = 0.0;
varying vec3 bilePos;
varying vec2 bileUV;
"
	var vert := "bilePos = VERTEX; bileUV = UV;
	float edgeFade = sin(UV.x * 3.14159265) * sin(UV.y * 3.14159265);
	VERTEX.y += edgeFade * (sin(VERTEX.x * 2.3 + bileTime * 1.7) * 0.065 + cos(VERTEX.z * 2.8 - bileTime * 1.2) * 0.045);"
	var frag := """vec2 bq = bilePos.xz;
	float ripple = sin(bq.x * 5.1 + bileTime * 2.1 + sin(bq.y * 1.3)) * sin(bq.y * 4.3 - bileTime * 1.7) + 0.5 * sin(dot(bq, vec2(2.7, -3.9)) + bileTime * 2.9) + 0.35 * sin(length(bq) * 1.6 - bileTime * 0.9);
	{ float h = ripple * 0.05; vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX); vec3 r1 = cross(dy, NORMAL), r2 = cross(NORMAL, dx);
	float det = dot(dx, r1); vec3 g = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2); NORMAL = normalize(abs(det) * NORMAL - g); }
	float flow = sin(bilePos.x * 3.4 + sin(bilePos.z * 2.2 + bileTime * 0.7) - bileTime);
	float foam = smoothstep(0.7, 0.98, flow) * 0.07;
	float edge = min(bileUV.y, 1.0 - bileUV.y);
	float foamN = 0.5 + 0.5 * sin(bilePos.x * 9.0 + bileTime * 1.3) * sin(bilePos.z * 8.0 - bileTime * 1.1);
	float shore = 1.0 - smoothstep(0.0, 0.06 + 0.07 * foamN, edge);
	float deep = smoothstep(0.05, 0.45, edge);
	ALBEDO = mix(ALBEDO, ALBEDO * vec3(0.32, 0.42, 0.18), deep * 0.85);
	ALBEDO = mix(ALBEDO, vec3(0.74, 0.8, 0.36), foam + shore * (0.35 + 0.3 * foamN));
	vec2 cq = bilePos.xz * 1.3 + vec2(sin(bilePos.z * 0.7 + bileTime * 0.3), cos(bilePos.x * 0.6 - bileTime * 0.25)) * 1.2;
	float caus = abs(sin(cq.x + sin(cq.y * 1.3 + bileTime * 0.8) * 1.4) * sin(cq.y + sin(cq.x * 1.1 - bileTime * 0.6) * 1.4));
	caus = pow(1.0 - caus, 9.0) * (0.5 + 0.5 * sin(bilePos.x * 0.9 + bilePos.z * 1.1 + bileTime * 0.4));
	EMISSION += vec3(0.04, 0.06, 0.003) * (foam * 2.0 + bileWarning * 0.25) + vec3(0.045, 0.065, 0.006) * caus * (0.4 + 0.6 * deep) * (1.0 + bileWarning) + vec3(0.05, 0.06, 0.02) * shore * foamN;"""
	if Game.view.material_look.patch(m, {"decl": decl, "vert": vert, "frag": frag}):
		_bile = m.get_rid()


func set_bile(t: float, warn: float) -> void:
	if _bile.is_valid():
		RenderingServer.material_set_param(_bile, &"bileTime", t)
		RenderingServer.material_set_param(_bile, &"bileWarning", warn)


func _shader(add: bool) -> Shader:
	var key := "add" if add else "mix"
	if not _shaders.has(key):
		var s := Shader.new()
		s.code = POINTS % ["blend_add" if add else "blend_mix", "ALBEDO = add_display(v_col.rgb, k * opacity);\n	ALPHA = 1.0;" if add else "ALBEDO = v_col.rgb;\n	ALPHA = k * opacity;"]
		_shaders[key] = s
	return _shaders[key]


## one Points cloud as a MultiMesh of quads, under the node the glTF left it on (so it hides with its room)
func _build_points(n: MeshInstance3D) -> void:
	var am: ArrayMesh = n.mesh
	var mt := am.surface_get_material(0) as StandardMaterial3D
	var arr: Array = am.surface_get_arrays(0)
	var pts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var cols: Variant = arr[Mesh.ARRAY_COLOR]
	var x: Dictionary = mt.get_meta("extras", {}) if mt != null else {}
	var add: bool = x.get("blend") == "add" or (mt != null and mt.blend_mode == BaseMaterial3D.BLEND_MODE_ADD)
	var obc := String(x.get("obc", ""))
	var sm := ShaderMaterial.new()
	sm.shader = _shader(add)
	sm.set_shader_parameter(&"size", float(x.get("point_size", 0.16)))
	sm.set_shader_parameter(&"opacity", mt.albedo_color.a if mt != null else 1.0)
	var src := String(_uniforms(obc, int(x.get("obc_var", 0))).get("vertex", "")) if obc != "" else ""
	if obc.ends_with("_9ba9"):      # spores: drift, H, rise
		sm.set_shader_parameter(&"kind", 1.0)
		sm.set_shader_parameter(&"p_c", _re(src, "uTime \\* 0\\.23 \\+ sk\\) \\* ([0-9.]+)", 1.4))
		sm.set_shader_parameter(&"p_b", _re(src, "mod\\(uTime \\* ([0-9.]+)", 0.35))
		sm.set_shader_parameter(&"p_a", _re(src, "aSeed \\* 97\\.0, ([0-9.]+)", 20.0))
	elif obc.ends_with("_b1a4"):      # drips: len, speed
		sm.set_shader_parameter(&"kind", 2.0)
		sm.set_shader_parameter(&"p_b", _re(src, "mod\\(uTime \\* ([0-9.]+)", 2.4))
		sm.set_shader_parameter(&"p_a", _re(src, "aSeed \\* 37\\.0, ([0-9.]+)", 3.0))
	else:      # a soft halo that stays put: the route beacons
		sm.set_shader_parameter(&"soft", 1.0)
		_halo.append(sm)
	var base := mt.albedo_color if mt != null else Color.WHITE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = pts.size()
	var seed_ := 7 + pts.size()
	for i in pts.size():
		seed_ = (seed_ * 1664525 + 1013904223) & 0xFFFFFFFF
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pts[i]))
		var c: Color = (cols as PackedColorArray)[i] if (cols is PackedColorArray and not (cols as PackedColorArray).is_empty()) else Color.WHITE
		mm.set_instance_color(i, (c * base).srgb_to_linear())
		mm.set_instance_custom_data(i, Color(seed_ / 4294967296.0, 0.0, 0.0, 0.0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16384.0
	n.mesh = null
	n.add_child(mi)
	if x.get("js_name", "") != "":
		_named_pts[x.js_name] = sm
	if mt != null and mt.resource_name.contains("spUpdraft"):
		_named_pts["updraft"] = sm
	elif mt != null and mt.resource_name.contains("spGust"):
		_named_pts["gust"] = sm


func _re(s: String, pat: String, d: float) -> float:
	var r := RegEx.create_from_string(pat)
	var m := r.search(s)
	return float(m.get_string(1)) if m != null else d


func set_points_opacity(nm: String, a: float) -> void:
	if _named_pts.has(nm):
		(_named_pts[nm] as ShaderMaterial).set_shader_parameter(&"opacity", a)


func update(t: float, beat: float, breath: float) -> void:
	RenderingServer.global_shader_parameter_set(&"prog_flesh_time", t)
	RenderingServer.global_shader_parameter_set(&"prog_flesh_beat", beat)
	RenderingServer.global_shader_parameter_set(&"prog_flesh_breath", breath)
	for m: StandardMaterial3D in _veins:
		m.emission_energy_multiplier = 0.35 + beat * 1.6
	for m: StandardMaterial3D in _column:
		m.emission_energy_multiplier = 0.7 + beat * 1.4
	for sm: ShaderMaterial in _halo:      # the beacons pulse with the heartbeat
		sm.set_shader_parameter(&"opacity", 0.55 + 0.4 * beat)
