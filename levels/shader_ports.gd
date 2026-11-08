class_name ShaderPorts
extends RefCounted
## Puts the hand-ported shaders (levels/shaders/<name>.gdshader) on an exported level, in place of the exporter's placeholders. A surface says which shader and which set of values it had in the JS
## (material extras shader, shader_var; values in assets/levels/<id>/shaders/<name>.json). Shaders driven by per-point data get a MultiMesh built from shader_fields.bin.

const DIR := "res://levels/shaders/"

## Which JS attribute goes where on a MultiMesh instance: origin, instance colour, custom data (up to 4 floats, in order).
const FIELDS := {
	"shader_b17ba4": {"pos": "aC", "col": "aCol", "cus": ["aSize"], "per": 4},      # (per: the JS repeats a quad's numbers on each of its 4 vertices: one instance per quad)
	"shader_b13e22": {"pos": "iPos", "col": "iCol", "cus": ["iSize"]},
	"shader_e12192": {"pos": "position", "cus": ["aPhase", "aSize"]},
	"shader_34e20b": {"pos": "position", "col": "color", "cus": ["aSize"]},
	"shader_0da48b": {"pos": "position", "cus": ["aSeed"]},
	"shader_e36887": {"pos": "position", "cus": ["aLife", "aSeed"], "steam": 16},
	"shader_d57960": {"pos": "position", "col": "aCol", "cus": ["aSize"]},
	"shader_26122d": {"pos": "position", "col": "aCol", "cus": ["aSize", "aAlpha", "aRot"]},
	"shader_473d95": {"pos": "iPos", "col": "iCol", "cus": ["iSize", "iOp"]},
	"shader_88d62b": {"pos": "position", "col": "col", "cus": ["size"]},
}
## Shaders driven by their own per-point attributes (particles animated entirely in the shader, wrapped rain, the volcano's vertex data): each becomes one mesh, attributes in CUSTOM0.. in alphabetical order, a point's corner in UV. (tools/export/port_shader.mjs writes them to expect this.)
const EXPANDED := {"shader_af7477": true, "shader_a09ff2": true, "shader_b2d790": true, "shader_9750ed": true, "shader_a19d8a": true, "shader_f5b5f4": true, "shader_312693": true, "shader_7b858d": true, "shader_0c99d2": true, "rain_streaks_e3b913": true}
## Baked into a mesh by the exporter but really one card that faces the camera: rebuilt at the centre of its bounds.
const CARDS := {"shader_8dce7b": true}
## Domes: uCenter is the middle of all their pieces, and they must never be culled.
const DOMES := {"shader_4a3f88": true, "shader_20ab12": true, "shader_75102a": true, "shader_9fb716": true}

const GRIME_DECL := """varying vec3 v_lp;
float gH(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float gN(vec3 p) { vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(gH(i), gH(i + vec3(1, 0, 0)), f.x), mix(gH(i + vec3(0, 1, 0)), gH(i + vec3(1, 1, 0)), f.x), f.y), mix(mix(gH(i + vec3(0, 0, 1)), gH(i + vec3(1, 0, 1)), f.x), mix(gH(i + vec3(0, 1, 1)), gH(i + vec3(1, 1, 1)), f.x), f.y), f.z); }"""
const GRIME_FRAG := """
	float gs = fract(dot(ALBEDO, vec3(12.9, 78.2, 37.7)) * 43.7) * 40.0; vec3 gp = v_lp + gs;
	float dirt = (1.0 - smoothstep(0.22, 0.78, v_lp.y)) * (0.45 + 0.55 * gN(gp * 3.5)) + smoothstep(0.55, 0.9, gN(vec3(gp.x * 11.0, gp.y * 1.3, gp.z * 11.0))) * 0.35 * (1.0 - smoothstep(0.6, 1.1, v_lp.y))
		+ smoothstep(1.0, 1.4, v_lp.y) * 0.25 * gN(gp * 6.0);
	float rust = smoothstep(0.74, 0.8, gN(gp * 5.0) * 0.7 + gN(gp * 17.0) * 0.3);
	ALBEDO = mix(ALBEDO, vec3(0.06, 0.055, 0.045), clamp(dirt, 0.0, 1.0) * 0.6);
	ALBEDO = mix(ALBEDO, vec3(0.2, 0.08, 0.035) * (0.6 + 0.4 * gN(gp * 23.0)), rust * 0.6);
	SPECULAR *= 1.0 - clamp(dirt * 0.9 + rust, 0.0, 0.95);
"""

var lv: ExportedLevel
var hooked: Dictionary = {}        # material instance id -> true
var dir := ""
var work: Dictionary = {}          # shader name -> its json
var mats: Dictionary = {}          # "name#variant" -> ShaderMaterial
var dome_box: Dictionary = {}      # shader name -> AABB of its pieces in the world
var ported := {}                   # shader name -> surfaces moved over (for tests)


static func apply(level: ExportedLevel, level_dir: String) -> ShaderPorts:
	var p := ShaderPorts.new()
	p.lv = level
	p.dir = level_dir
	p._walk()
	p._build_fields()
	for nm: String in p.dome_box:
		for k: String in p.mats:
			if k.begins_with(nm + "#"):
				(p.mats[k] as ShaderMaterial).set_shader_parameter(&"uCenter", (p.dome_box[nm] as AABB).get_center())
	return p


func _walk() -> void:
	var stack: Array[Node] = [lv]
	var cards: Array = []
	var to_hide: Array[MeshInstance3D] = []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		var mesh: Mesh = null
		if n is MeshInstance3D:
			mesh = (n as MeshInstance3D).mesh
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh != null:
			mesh = (n as MultiMeshInstance3D).multimesh.mesh
		if mesh == null:
			continue
		for s in mesh.get_surface_count():
			var m := mesh.surface_get_material(s)
			if m == null or not m.has_meta("extras"):
				continue
			var x: Dictionary = m.get_meta("extras")
			if x.has("billboard") and x.get("blend", "") == "add" and m is StandardMaterial3D:
				mesh.surface_set_material(s, _glow_billboard(m))
				continue
			_additive(m as StandardMaterial3D, x)
			_display_vc(m as StandardMaterial3D, x)
			if x.has("obc"):
				_hook(m as StandardMaterial3D, String(x["obc"]), int(x.get("obc_var", 0)))
				if String(x["obc"]) == "obc_b8223c0d30_b822" and n is GeometryInstance3D:      # JS: frustumCulled false
					(n as GeometryInstance3D).extra_cull_margin = 4000.0
					(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				continue
			var nm := String(x.get("shader", ""))
			if nm == "" or not ResourceLoader.exists(DIR + nm + ".gdshader"):
				continue
			if FIELDS.has(nm) or CARDS.has(nm) or EXPANDED.has(nm):
				if n is MeshInstance3D:
					to_hide.append(n)
					if CARDS.has(nm):
						cards.append([nm, int(x.get("shader_var", 0)), n])
				continue
			mesh.surface_set_material(s, _material(nm, int(x.get("shader_var", 0))))
			ported[nm] = int(ported.get(nm, 0)) + 1
			if DOMES.has(nm) and n is MeshInstance3D:
				var mi := n as MeshInstance3D
				var box: AABB = mi.global_transform * mesh.get_aabb()
				dome_box[nm] = (dome_box[nm] as AABB).merge(box) if dome_box.has(nm) else box
				mi.extra_cull_margin = 16384.0
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif n is MeshInstance3D and nm == "shader_9ae872":      # JS: frustumCulled false; its swell moves it past its bounds
				(n as MeshInstance3D).extra_cull_margin = 4.0
				(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c: Array in cards:
		_build_card(c[0], c[1], c[2])
	for mi in to_hide:
		mi.visible = false


## A still additive sprite: one material per colour, opacity and texture. (material_look.gd does not write billboards, so _additive cannot reach them.)
func _glow_billboard(b: StandardMaterial3D) -> ShaderMaterial:
	var c := b.albedo_color
	var key := "glow:%s:%s" % [c.to_html(true), b.albedo_texture.resource_path if b.albedo_texture != null else ""]
	if mats.has(key):
		return mats[key]
	var sm := ShaderMaterial.new()
	sm.shader = load(DIR + "glow_billboard.gdshader")
	sm.set_shader_parameter(&"map", b.albedo_texture)
	var l := Color(c.r, c.g, c.b).srgb_to_linear()
	sm.set_shader_parameter(&"col", Vector3(l.r, l.g, l.b))
	sm.set_shader_parameter(&"opacity", c.a)
	mats[key] = sm
	return sm


## An unlit additive material blends on the display value in the JS (a glow, a light cone): over a dark frame this draws the same picture. See add_display in common.gdshaderinc.
func _additive(b: StandardMaterial3D, x: Dictionary) -> void:
	if b == null or x.has("shader") or x.has("obc") or b.blend_mode != BaseMaterial3D.BLEND_MODE_ADD or b.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or hooked.has(b.get_instance_id()):
		return
	hooked[b.get_instance_id()] = true
	Game.view.material_look.patch(b, {"decl": '#include "res://levels/shaders/common.gdshaderinc"', "frag": "ALBEDO = add_display(ALBEDO, ALPHA);
ALPHA = 1.0;"})


## An unlit material with vertex colours and toneMapped: false (the district's glow strips): the JS draws those colours straight to the screen. The exporter moves a single colour to where the tone map brings it back; per vertex that happens here.
func _display_vc(b: StandardMaterial3D, x: Dictionary) -> void:
	if b == null or not x.has("not_tone_mapped") or x.has("shader") or x.has("obc") or not b.vertex_color_use_as_albedo or b.blend_mode != BaseMaterial3D.BLEND_MODE_MIX or b.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED or hooked.has(b.get_instance_id()):
		return
	hooked[b.get_instance_id()] = true
	Game.view.material_look.patch(b, {"decl": '#include "res://levels/shaders/common.gdshaderinc"', "frag": "ALBEDO = display_to_radiance(srgb_encode(COLOR.rgb));"})      # (COLOR alone: the exporter has already moved albedo for the tone map)


## The first number after `pattern` in a hook's resolved text (the closures the JS source does not show: a fill strength, a sway).
static func _num(text: String, pattern: String, fallback: float) -> float:
	var re := RegEx.new()
	re.compile(pattern + "\\s*([0-9.]+)")
	var m := re.search(text)
	return float(m.get_string(1)) if m != null else fallback


## A JS onBeforeCompile hook, by its name. Same statements, on the shader Godot generates for this material (core/material_look.gd). One that is not here yet leaves the plain material.
func _hook(b: StandardMaterial3D, nm: String, variant: int) -> void:
	if b == null or hooked.has(b.get_instance_id()):
		return
	hooked[b.get_instance_id()] = true
	var list: Array = _json(nm).get("variants", [])
	var v: Dictionary = list[variant] if variant < list.size() else {}
	var frag := String(v.get("fragment", ""))
	var vert := String(v.get("vertex", ""))
	var extra := {}
	match nm:
		"obc_f7d9d0fb24_f7d9":      # car trim (JS city-traffic.js fill): a baked fill, so it reads at night
			extra.frag = _fill_block(_num(frag, "diffuseColor\\.rgb \\*", 0.4))
		"obc_5546464f20_5546":      # car paint (JS city-traffic.js grime + fill): road dirt up the sills, drips, rust blooms, a dusty roof
			extra.decl = GRIME_DECL
			extra.vert = "v_lp = VERTEX;"
			extra.frag = GRIME_FRAG + _fill_block(_num(frag, "diffuseColor\\.rgb \\*", 0.42))
		"obc_a465045101_a465":      # city furniture (JS city-props.js propMaterial): a baked fill, and tree tops that move in the wind
			var from_y := _num(vert, "transformed\\.y -", 2.5)
			var sway := _num(vert, "\\) \\*", 0.0)
			extra.vert = "{ vec3 ip = MODEL_MATRIX[3].xyz; float k = max(0.0, VERTEX.y - %f) * %f;\n\tVERTEX.x += k * (sin(TIME * 1.3 + ip.x * 0.31) + 0.4 * sin(TIME * 3.1 + ip.z * 0.7));\n\tVERTEX.z += k * 0.7 * sin(TIME * 1.1 + ip.z * 0.27); }" % [from_y, sway]
			extra.frag = "EMISSION += ALBEDO * %f;" % _num(frag, "diffuseColor\\.rgb \\*", 0.45)
		"obc_68268baacb_6826":      # world-space surface detail on the merged statics (JS index.html createDetail)
			var uni: Dictionary = v.get("uniforms", {})
			var tex: Dictionary = uni.get("tDet", {})
			if tex.get("file") == null:
				return
			extra.decl = "uniform sampler2D tDet : %srepeat_enable, filter_linear_mipmap_anisotropic;\nuniform vec4 uDet;\nvarying vec3 v_wp;" % ("source_color, " if tex.get("srgb", false) else "")
			extra.vert = "v_wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;"
			extra.frag = "{ vec3 wn = abs(normalize(cross(dFdx(v_wp), dFdy(v_wp)))); vec2 p = wn.y > 0.6 ? v_wp.xz : (wn.x > 0.6 ? vec2(v_wp.z, v_wp.y) : v_wp.xy);\n\tvec3 d = texture(tDet, p * uDet.x).rgb * uDet.z; float lit = max(EMISSION.r, max(EMISSION.g, EMISSION.b));\n\tALBEDO *= mix(vec3(1.0), d, uDet.y * (1.0 - smoothstep(0.02, 0.25, lit))); }"
			extra.params = {"tDet": load("res://assets/" + String(tex["file"])), "uDet": _vec((uni.get("uDet", {}) as Dictionary).get("value"))}
		"obc_b8223c0d30_b822":      # the Dyosphere (JS city-dyosphere.js skyDepth): squeezed into the far depth range behind the whole city, and mixed part-way into the smog so it reads as kilometres off. Godot's float depth has the precision to keep its parts apart there, so it needs no depth clear.
			var haze := _num(frag, "uHaze,", 0.34)
			extra.decl = '#include "res://levels/shaders/common.gdshaderinc"\nglobal uniform vec3 prog_smog;'
			extra.vert = "{ vec4 mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0); vec4 pp = PROJECTION_MATRIX * mv; float skyK = clamp((-mv.z - 1300.0) / 400.0, 0.0, 1.0); pp.z = (0.00003 * (1.0 - skyK) + 0.000001) * pp.w; POSITION = pp; }"
			var not_tm: bool = (b.get_meta("extras", {}) as Dictionary).has("not_tone_mapped")
			extra.frag = ("ALBEDO = display_to_radiance(srgb_encode(mix(COLOR.rgb, prog_smog, %f)));" % haze) if not_tm else ("ALBEDO = mix(ALBEDO, prog_smog, %f);" % haze)
			if b.blend_mode == BaseMaterial3D.BLEND_MODE_ADD:
				extra.frag = String(extra.frag) + "\nALBEDO = add_display(ALBEDO, ALPHA);\nALPHA = 1.0;"
		"obc_b083e30fcc_b083", "obc_c33fcd44bd_c33f":      # VISITING HOURS (JS restyle.js, cutaway.js, foliage.js): painted grade, world-space photo detail, cool silhouette edge, the see-through cutaway, reeds in the wind
			extra = _vh_restyle(v, vert)
		"obc_4ac892b32f_4ac8":      # OMNISPHERE's one paint (JS levels/omnisphere/paint.js)
			extra = _omni_paint(b, v)
		"obc_a7e129a18c_a7e1":      # Club 9's marquee (JS): its black is a hole
			extra.frag = "if (max(ALBEDO.r, max(ALBEDO.g, ALBEDO.b)) < 0.004) { discard; }"
		_:
			return
	if Game.view.material_look.patch(b, extra):
		ported[nm] = int(ported.get(nm, 0)) + 1


## a global shader parameter a level's shaders share, made once a session
static var _globals := {}


static func _global(g: StringName, type: int, v: Variant) -> void:
	if not _globals.has(g):
		_globals[g] = true
		RenderingServer.global_shader_parameter_add(g, type, v)


## OMNISPHERE's paint: the shader itself is levels/shaders/omni_paint.gdshaderinc; style, tint and glow come from the vertices (a Batch) or from this variant.
func _omni_paint(b: StandardMaterial3D, v: Dictionary) -> Dictionary:
	_global(&"omni_power", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
	_global(&"omni_alarm", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
	b.vertex_color_use_as_albedo = false
	b.vertex_color_is_srgb = false
	var uni: Dictionary = v.get("uniforms", {})
	var params := {}
	for t: String in ["tBasalt", "tDeck", "tPaint", "tShield", "tRust", "tGrate"]:
		var u: Dictionary = uni.get(t, {})
		if u.get("file") != null:
			params[t] = load("res://assets/" + String(u["file"]))
	params["uStyle"] = float((uni.get("uStyle", {}) as Dictionary).get("value", 0.0))
	params["uLocal"] = float((uni.get("uLocal", {}) as Dictionary).get("value", 0.0))
	params["uTint"] = _vec((uni.get("uTint", {}) as Dictionary).get("value", [1.0, 1.0, 1.0]))
	params["uGlowCol"] = _vec((uni.get("uGlowCol", {}) as Dictionary).get("value", [1.0, 1.0, 1.0]))
	return {"decl": '#include "res://levels/shaders/omni_paint.gdshaderinc"\n',
		"vert": "vPW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; vPN = normalize(mat3(MODEL_MATRIX) * NORMAL); vPL = VERTEX; vTint = COLOR.rgb; vBvc = COLOR.a; vGlow = vec3(UV.x, UV.y, UV2.x); vStyle = floor(UV2.y + 0.001); vWear = fract(UV2.y + 0.001) / 0.99;",
		"frag": "{ vec3 oc_; vec3 og_; float or_; float om_; omni_body(TIME, FRAGCOORD.y, oc_, og_, or_, om_); ALBEDO = oc_; ROUGHNESS = or_; METALLIC = om_; EMISSION += og_; }",
		"params": params}


## VISITING HOURS' finish (JS restyle.js paintedMat, surf, finish; cutaway.js patch; foliage.js), read off this variant's own text: what it has is what the JS gave it.
func _vh_restyle(v: Dictionary, vert: String) -> Dictionary:
	var f := String(v.get("fragment", ""))
	var uni: Dictionary = v.get("uniforms", {})
	var decl := ""
	var vs := ""
	var fs := ""
	var params := {}
	if f.contains("vCutW"):
		_global(&"vh_cut_c", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
		_global(&"vh_cut_p", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
		_global(&"vh_cut_on", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0)
		decl += "global uniform vec3 vh_cut_c;\nglobal uniform vec3 vh_cut_p;\nglobal uniform float vh_cut_on;\nvarying vec3 vCutW;\nvarying float vCutUp;\n"
		vs += "vCutW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; vCutUp = abs(normalize(mat3(MODEL_MATRIX) * NORMAL).y);\n"
		# (a 4x4 dither: the edge reads as a soft dissolve)
		fs += "if (vh_cut_on > 0.01 && vCutUp < 0.7) { vec3 ab_ = vh_cut_p - vh_cut_c; float L_ = length(ab_); vec3 d_ = ab_ / max(L_, 0.001); float t_ = dot(vCutW - vh_cut_c, d_);\n\tif (t_ > 0.2 && t_ < L_ - 0.5) { float R_ = mix(0.25, 0.6, clamp(t_ / L_, 0.0, 1.0)); float r_ = length(vCutW - (vh_cut_c + d_ * t_)); float a_ = (1.0 - smoothstep(R_ - 0.3, R_, r_)) * vh_cut_on;\n\tvec2 q_ = floor(mod(FRAGCOORD.xy, 4.0)); float bay_ = (mod(q_.x + q_.y * 2.0, 4.0) * 4.0 + mod(q_.x * 3.0 + q_.y, 4.0)) / 16.0; if (a_ > bay_ + 0.03) { discard; } } }\n"
	if vert.contains("aCard"):      # the reeds: gusts rolling across the marsh (the export bakes aCard into the UVs); both faces lit as the ground (a double-sided card's back face otherwise turns its normal down and goes flat grey)
		vs += "{ vec3 ip = MODEL_MATRIX[3].xyz; float ph = ip.x * 0.37 + ip.z * 0.29; float k = VERTEX.y * VERTEX.y; float gust = smoothstep(-0.3, 1.0, sin(TIME * 0.7 - ip.x * 0.015 - ip.z * 0.01));\n\tVERTEX.xz += vec2(sin(TIME * 2.6 + ph), cos(TIME * 2.1 + ph * 1.3)) * k * (0.05 + gust * 0.09) + vec2(0.16, 0.07) * k * gust; }\n"
		fs += "NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);\n"
	if uni.has("uSD"):
		var sd: Dictionary = uni["uSD"]
		var flags := "source_color, repeat_enable, filter_linear_mipmap_anisotropic"
		decl += "uniform sampler2D uSD : %s;\nuniform sampler2D uSD2 : %s;\nuniform sampler2D uSM : %s;\nuniform float uSS;\nuniform float uSH;\nuniform float uSA;\nvarying vec3 vSW;\nvarying vec3 vSN;\n" % [flags, flags, flags]
		decl += "float sH(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }\nfloat sN(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(sH(i), sH(i + vec2(1.0, 0.0)), f.x), mix(sH(i + vec2(0.0, 1.0)), sH(i + 1.0), f.x), f.y); }\nvec3 sTri(sampler2D t, vec3 p, vec3 w) { return texture(t, p.zy).rgb * w.x + texture(t, p.xz).rgb * w.y + texture(t, p.xy).rgb * w.z; }\n"
		vs += "vSW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; vSN = normalize(mat3(MODEL_MATRIX) * NORMAL);\n"
		var has_fd := f.contains("fd = smoothstep")
		var has_bl := f.contains("bl = smoothstep")
		var has_m := f.contains("uSM, vSW.xz")
		fs += "{ vec3 w = pow(abs(normalize(vSN)), vec3(4.0)); w /= w.x + w.y + w.z; vec3 p = vSW * uSS;\n\tvec3 tx = sTri(uSD, p, w); vec3 av = textureLod(uSD, vec2(0.5), 12.0).rgb;\n"
		if has_fd:
			fs += "\tfloat fd = smoothstep(18.0, 120.0, distance(vSW, CAMERA_POSITION_WORLD)); tx = mix(tx, sTri(uSD, p * 0.21, w), fd);\n"
		if has_bl:
			fs += "\t{ float bl = smoothstep(%s, sN(vSW.xz * 0.03) * 0.7 + sN(vSW.xz * 0.11) * 0.3); tx = mix(tx, %s, bl); av = mix(av, textureLod(uSD2, vec2(0.5), 12.0).rgb, bl); }\n" % ["0.3, 0.52" if has_fd else "0.38, 0.62", "mix(sTri(uSD2, p * 1.3, w), sTri(uSD2, p * 0.27, w), fd)" if has_fd else "sTri(uSD2, p * 1.3, w)"]
		fs += "\tfloat al = max(dot(av, vec3(0.299, 0.587, 0.114)), 0.02);\n\tvec3 d = mix(vec3(dot(tx, vec3(0.299, 0.587, 0.114))), tx, uSH) / al;\n"      # detail around 1.0, so the material's own colour still sets the value
		if has_m:
			fs += "\t{ vec3 mr = texture(uSM, vSW.xz * 0.011).rgb / max(textureLod(uSM, vec2(0.5), 12.0).rgb, vec3(0.02)); d *= mix(vec3(dot(mr, vec3(0.299, 0.587, 0.114))), mr, 0.4); }\n"
		fs += "\tALBEDO *= mix(vec3(1.0), d, uSA); }\n"
		for k: String in ["uSD", "uSD2", "uSM"]:
			var t: Dictionary = uni.get(k, sd)
			if t.get("file") != null:
				params[k] = load("res://assets/" + String(t["file"]))
		for k: String in ["uSS", "uSH", "uSA"]:
			params[k] = float((uni[k] as Dictionary).get("value", 1.0))
	if f.contains("vRW"):
		var sat := _num(f, "c = mix\\(vec3\\(l\\), c,", 0.55)
		var grime := _num(f, "smoothstep\\(0\\.,", 1.2)
		var mottle := _num(f, "c \\*= 1\\. -", 0.35)
		var wet := _num(f, "vRY\\)\\) \\*", 0.5)
		decl += "varying vec3 vRW;\nvarying float vRY;\nvarying vec3 vRN;\nfloat rH(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }\nfloat rN(vec3 p) { vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(mix(rH(i), rH(i + vec3(1.0, 0.0, 0.0)), f.x), mix(rH(i + vec3(0.0, 1.0, 0.0)), rH(i + vec3(1.0, 1.0, 0.0)), f.x), f.y), mix(mix(rH(i + vec3(0.0, 0.0, 1.0)), rH(i + vec3(1.0, 0.0, 1.0)), f.x), mix(rH(i + vec3(0.0, 1.0, 1.0)), rH(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z); }\n"
		vs += "vRW = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; vRY = vRW.y; vRN = normalize(mat3(MODEL_MATRIX) * NORMAL);\n"      # (JS vRY: the instance's own y; the export bakes merged pieces into the world)
		fs += "{ vec3 c = ALBEDO; float l = dot(c, vec3(0.299, 0.587, 0.114)); c = mix(vec3(l), c, %f) * vec3(0.94, 0.98, 1.04);\n\tfloat mt = rN(vRW * 1.7) * 0.6 + rN(vRW * 6.1) * 0.4; c *= 1.0 - %f * (mt - 0.5) * 0.9;\n\tfloat g = 1.0 - smoothstep(0.0, %f, vRY); c *= 1.0 - g * 0.55; c = mix(c, c * vec3(0.75, 0.82, 0.7), g * 0.5);\n\tc += vec3(0.05, 0.055, 0.06) * smoothstep(0.75, 0.95, vRN.y) * step(0.55, rN(vRW * 3.3));\n\tALBEDO = c; ROUGHNESS = mix(ROUGHNESS, 0.25, g * %f); }\n" % [sat, mottle, grime, wet]
	if not f.contains("vCutW") or uni.has("uSD") or f.contains("vRW"):
		# the finish: a faint cool edge where a surface turns away (silhouettes read against the night)
		fs += "{ float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 4.0); rim *= 1.0 - smoothstep(0.3, 0.7, (INV_VIEW_MATRIX * vec4(normalize(NORMAL), 0.0)).y); EMISSION += vec3(0.12, 0.17, 0.26) * rim * 0.18; }\n"
	return {"decl": decl, "vert": vs, "frag": fs, "params": params}


## JS: totalEmissiveRadiance += diffuseColor.rgb * k * (0.55 + 0.45 * clamp(normal.y * 0.5 + 0.5, 0.0, 1.0))
static func _fill_block(k: float) -> String:
	return "EMISSION += ALBEDO * %f * (0.55 + 0.45 * clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0));" % k


func _json(nm: String) -> Dictionary:
	if not work.has(nm):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "shaders/" + nm + ".json"))
		work[nm] = v if v is Dictionary else {}
	return work[nm]


func _material(nm: String, variant: int) -> ShaderMaterial:
	var k := "%s#%d" % [nm, variant]
	if mats.has(k):
		return mats[k]
	var sm := ShaderMaterial.new()
	sm.shader = load(DIR + nm + ".gdshader")
	var j := _json(nm)
	var list: Array = j.get("variants", [])
	var uni: Dictionary = list[variant] if variant < list.size() else j.get("uniforms", {})
	for u: String in uni:
		var d: Dictionary = uni[u]
		var val: Variant = _value(d)
		if val != null:
			sm.set_shader_parameter(u, val)
	mats[k] = sm
	return sm


func _value(d: Dictionary) -> Variant:
	match String(d.get("type", "")):
		"t":
			var f: Variant = d.get("file")
			if f == null:
				return null
			return load("res://assets/" + String(f))
		"f":
			return float(d.get("value", 0.0))
		"c", "v":
			return _vec(d.get("value"))
	return null


## JSON array -> what a shader uniform takes: vec2 / vec3 / vec4, or an array of vec4s.
func _vec(v: Variant) -> Variant:
	if not (v is Array) or (v as Array).is_empty():
		return null
	var a: Array = v
	if a[0] is Array:
		var out := PackedVector4Array()
		for e: Array in a:
			out.append(Vector4(e[0], e[1], e[2], e[3] if e.size() > 3 else 0.0))
		return out
	if a.size() > 4:      # uniform float x[n]
		return PackedFloat32Array(a)
	match a.size():
		2:
			return Vector2(a[0], a[1])
		3:
			return Vector3(a[0], a[1], a[2])
		4:
			return Vector4(a[0], a[1], a[2], a[3])
	return null


func _build_fields() -> void:
	var list: Array = lv.info.get("shader_fields", [])
	var file := String(lv.info.get("shader_fields_file", ""))
	if list.is_empty() or file == "":
		return
	var floats := FileAccess.get_file_as_bytes(dir + file).to_float32_array()
	var group := Node3D.new()
	group.name = "ShaderFields"
	lv.add_child(group)
	for f: Dictionary in list:
		var nm := String(f["shader"])
		if (not FIELDS.has(nm) and not EXPANDED.has(nm)) or not ResourceLoader.exists(DIR + nm + ".gdshader"):
			continue
		var mi: GeometryInstance3D = _expand(f, nm, floats) if EXPANDED.has(nm) else _field(f, nm, floats)
		if mi != null:
			var parents: Array = lv.node_named(String(f.get("parent", "")))     # under what the JS had it under, so it hides and moves with that
			if parents.is_empty():
				group.add_child(mi)
			else:
				var pn: Node3D = parents[0]
				mi.transform = pn.global_transform.affine_inverse() * mi.transform
				pn.add_child(mi)
			ported[nm] = int(ported.get(nm, 0)) + 1
			if String(f.get("name", "")) != "":
				lv.add_named(String(f["name"]), mi)


## One mesh out of a shader-driven object: every instance (or point) gets its own copy of the base shape, its attributes in CUSTOM0..
func _expand(f: Dictionary, nm: String, floats: PackedFloat32Array) -> MeshInstance3D:
	var attrs: Dictionary = f["attrs"]
	var mode := String(f.get("mode", "tri"))
	var names: Array = []
	for k: String in attrs:
		if k not in ["position", "normal", "uv", "uv1", "color"]:
			names.append(k)
	names.sort()
	var pa: Dictionary = attrs["position"]
	var is_points := mode == "points"
	var inst_n := 1
	for k: String in names:
		if attrs[k].get("instanced", false):
			inst_n = int(attrs[k]["count"])
	if f.get("instance_count") != null:
		inst_n = mini(inst_n, int(f["instance_count"]))
	if is_points:
		inst_n = int(pa["count"])
	var base_v := PackedVector3Array()
	var base_uv := PackedVector2Array()
	var base_ix := PackedInt32Array()
	if is_points:
		base_uv = PackedVector2Array([Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)])
		base_ix = PackedInt32Array([0, 1, 2, 0, 2, 3])
	else:
		var o := int(pa["off"]) / 4
		for i in int(pa["count"]):
			base_v.append(Vector3(floats[o + i * 3], floats[o + i * 3 + 1], floats[o + i * 3 + 2]))
		var ua: Dictionary = attrs.get("uv", {})
		if not ua.is_empty():
			var uo := int(ua["off"]) / 4
			for i in int(ua["count"]):
				base_uv.append(Vector2(floats[uo + i * 2], floats[uo + i * 2 + 1]))
		if f.get("index") is Array:
			for i: Variant in f["index"]:
				base_ix.append(int(i))
	var per := 4 if is_points else base_v.size()
	var total := per * inst_n
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var nor := PackedVector3Array()
	var ix := PackedInt32Array()
	v.resize(total)
	if not base_uv.is_empty():
		uv.resize(total)
	var na: Dictionary = attrs.get("normal", {})
	if not na.is_empty() and not is_points:
		nor.resize(total)
	var cust: Array[PackedFloat32Array] = []
	for k: String in names:
		var c := PackedFloat32Array()
		c.resize(total * 4)
		cust.append(c)
	var po := int(pa["off"]) / 4
	for inst in inst_n:
		for b in per:
			var at := inst * per + b
			if is_points:
				v[at] = Vector3(floats[po + inst * 3], floats[po + inst * 3 + 1], floats[po + inst * 3 + 2])
			else:
				v[at] = base_v[b]
				if not nor.is_empty():
					var no := int(na["off"]) / 4
					nor[at] = Vector3(floats[no + b * 3], floats[no + b * 3 + 1], floats[no + b * 3 + 2])
			if not base_uv.is_empty():
				uv[at] = base_uv[b]
			for c in names.size():
				var a: Dictionary = attrs[names[c]]
				var s := int(a["size"])
				var src := inst if (is_points or a.get("instanced", false)) else b
				var ao := int(a["off"]) / 4 + src * s
				for e in s:
					cust[c][at * 4 + e] = floats[ao + e]
		for i in base_ix:
			ix.append(inst * per + i)
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	if not uv.is_empty():
		arr[Mesh.ARRAY_TEX_UV] = uv
	if not nor.is_empty():
		arr[Mesh.ARRAY_NORMAL] = nor
	if not ix.is_empty():
		arr[Mesh.ARRAY_INDEX] = ix
	var flags := 0
	const SLOT := [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]
	const SHIFT := [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]
	for c in mini(cust.size(), 4):
		arr[SLOT[c]] = cust[c]
		flags |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << SHIFT[c]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_LINES if mode == "lines" else Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	m.surface_set_material(0, _material(nm, int(f.get("shader_var", 0))))
	var mi := MeshInstance3D.new()
	mi.name = "field_" + nm
	mi.mesh = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-100000, -100000, -100000), Vector3(200000, 200000, 200000))      # it moves in the shader: the JS draws these with frustumCulled off
	mi.visible = not bool(f.get("hidden", false))
	var w: Array = f["world"]
	mi.transform = Transform3D(Basis(Vector3(w[0], w[1], w[2]), Vector3(w[4], w[5], w[6]), Vector3(w[8], w[9], w[10])), Vector3(w[12], w[13], w[14]))
	return mi


func _field(f: Dictionary, nm: String, floats: PackedFloat32Array) -> MultiMeshInstance3D:
	var spec: Dictionary = FIELDS[nm]
	var attrs: Dictionary = f["attrs"]
	if not attrs.has(spec["pos"]):
		push_warning("shader field %s: no attribute %s" % [nm, spec["pos"]])
		return null
	var pa: Dictionary = attrs[spec["pos"]]
	var per := int(spec.get("per", 1))
	var count := int(pa["count"]) / per
	if f.get("instance_count") != null:
		count = mini(count, int(f["instance_count"]))
	var ps := int(pa["off"]) / 4
	var col: Dictionary = attrs.get(spec.get("col", ""), {})
	var cus: Array = []
	for c: String in spec.get("cus", []):
		if attrs.has(c):
			cus.append(attrs[c])
	var buf := PackedFloat32Array()
	buf.resize(count * 20)
	for i in count:
		var o := i * 20
		var src := i * per
		buf[o] = 1.0
		buf[o + 3] = floats[ps + src * 3]
		buf[o + 5] = 1.0
		buf[o + 7] = floats[ps + src * 3 + 1]
		buf[o + 10] = 1.0
		buf[o + 11] = floats[ps + src * 3 + 2]
		if col.is_empty():
			buf[o + 12] = 1.0
			buf[o + 13] = 1.0
			buf[o + 14] = 1.0
			buf[o + 15] = 1.0
		else:
			var cs := int(col["size"])
			var co := int(col["off"]) / 4 + src * cs
			buf[o + 12] = floats[co]
			buf[o + 13] = floats[co + 1]
			buf[o + 14] = floats[co + 2]
			buf[o + 15] = floats[co + 3] if cs > 3 else 1.0
		var w := 0
		for c: Dictionary in cus:
			var s := int(c["size"])
			var co := int(c["off"]) / 4 + src * s
			for e in s:
				if w < 4:
					buf[o + 16 + w] = floats[co + e]
					w += 1
	if spec.has("steam"):
		_steam_origins(buf, count, int(spec["steam"]))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = _base_mesh(f, floats, nm)
	mm.instance_count = count
	mm.buffer = buf
	var mi := MultiMeshInstance3D.new()
	mi.name = "field_" + nm
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 400.0
	mi.visible = not bool(f.get("hidden", false))
	var w: Array = f["world"]
	mi.transform = Transform3D(Basis(Vector3(w[0], w[1], w[2]), Vector3(w[4], w[5], w[6]), Vector3(w[8], w[9], w[10])), Vector3(w[12], w[13], w[14]))
	return mi


## The export caught each steam puff part way up. JS: x = vent.x + sin(...) * L * 0.9 + L * L * 1.4, y = road + 0.1 + L * 3.6, z = vent.z + cos(seed * 31) * L * 0.8, `per` puffs to a vent: undo that to find the vents (the sine averages out over a vent's puffs).
func _steam_origins(buf: PackedFloat32Array, count: int, per: int) -> void:
	for v in count / per:
		var x := 0.0
		var y := 0.0
		var z := 0.0
		for k in per:
			var o := (v * per + k) * 20
			var life := buf[o + 16]
			var seed := buf[o + 17]
			x += buf[o + 3] - life * life * 1.4
			y += buf[o + 7] - life * 3.6
			z += buf[o + 11] - cos(seed * 31.0) * life * 0.8
		for k in per:
			var o := (v * per + k) * 20
			buf[o + 3] = x / per
			buf[o + 7] = y / per
			buf[o + 11] = z / per


## The shape one instance draws: the JS geometry for instanced quads, a +-1 quad for points.
func _base_mesh(f: Dictionary, floats: PackedFloat32Array, nm: String) -> ArrayMesh:
	var st := PackedVector3Array()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	var attrs: Dictionary = f["attrs"]
	var spos: Dictionary = attrs.get("position", {})
	if String(f.get("mode", "")) != "points" and not spos.is_empty() and not bool(spos.get("instanced", false)):
		var o := int(spos["off"]) / 4
		var s := int(spos["size"])
		var per := int((FIELDS.get(nm, {}) as Dictionary).get("per", 0))      # only the first quad: the rest are the other instances
		for i in (per if per > 0 else int(spos["count"])):
			st.append(Vector3(floats[o + i * s], floats[o + i * s + 1], floats[o + i * s + 2] if s > 2 else 0.0))
		var ua: Dictionary = attrs.get("uv", {})
		if not ua.is_empty():
			var uo := int(ua["off"]) / 4
			for i in (per if per > 0 else int(ua["count"])):
				uv.append(Vector2(floats[uo + i * 2], floats[uo + i * 2 + 1]))
		if f.get("index") is Array:
			var fi: Array = f["index"]
			for i in (mini(fi.size(), per * 3 / 2) if per > 0 else fi.size()):
				ix.append(int(fi[i]))
	else:
		st = PackedVector3Array([Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0)])
		uv = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		ix = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = st
	if uv.size() == st.size():
		arr[Mesh.ARRAY_TEX_UV] = uv
	if not ix.is_empty():
		arr[Mesh.ARRAY_INDEX] = ix
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _material(nm, int(f.get("shader_var", 0))))
	return m


func _build_card(nm: String, variant: int, from: MeshInstance3D) -> void:
	var c: Vector3 = (from.global_transform * from.mesh.get_aabb()).get_center()
	var st := PackedVector3Array([Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(1, 1, 0), Vector3(-1, 1, 0)])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = st
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	m.surface_set_material(0, _material(nm, variant))
	var mi := MeshInstance3D.new()
	mi.name = "card_" + nm
	mi.mesh = m
	mi.extra_cull_margin = 4000.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var parent: Node3D = from.get_parent()
	parent.add_child(mi)
	mi.global_position = c
	ported[nm] = int(ported.get(nm, 0)) + 1
