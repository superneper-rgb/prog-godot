// FOINT CITY's new townsfolk (levels/hub/folk_skin.gd): a species skinned on the GPU from a bone texture, one MultiMesh per species, nothing about a pose run in script.
// Vertex: CUSTOM0 = 4 bone (bind) indices, CUSTOM1 = their weights. Instance: INSTANCE_CUSTOM = (walk/run phase 0..1, walk weight, idle time offset s, run weight), COLOR.r = head turn (rad).
// The bone texture holds 3 texels per bind (the rows of its 3x4 skinning matrix) and one row per sampled frame: idle by time, walk and run by phase.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D bones_tex : filter_nearest, repeat_disable;
uniform ivec2 clip_idle;      // (first row, rows)
uniform ivec2 clip_walk;
uniform ivec2 clip_run;
uniform float idle_len = 6.0;
uniform ivec4 look_binds = ivec4(-1);      // head, fin, fin, neck: they turn with the head (the neck half)
uniform vec3 look_pivot;                   // where the head turns, in the rest pose
uniform float uTime = 0.0;                 // the street clock (stops while the game is paused)
varying flat vec2 tint;                    // instance COLOR.g, COLOR.b: a copy's hue turn (turns) and brightness (levels/hub/city_crowd.gd); 0 and 1 for an original
void add_clip(ivec4 bi, vec4 bw, ivec2 clip, float fr, float k, inout vec4 r0, inout vec4 r1, inout vec4 r2) {
	float f0 = floor(fr);
	float t = fr - f0;
	int a = clip.x + int(mod(f0, float(clip.y)));
	int b = clip.x + int(mod(f0 + 1.0, float(clip.y)));
	for (int j = 0; j < 4; j++) {
		float w = bw[j] * k;
		if (w <= 0.0) continue;
		int x = bi[j] * 3;
		r0 += w * mix(texelFetch(bones_tex, ivec2(x, a), 0), texelFetch(bones_tex, ivec2(x, b), 0), t);
		r1 += w * mix(texelFetch(bones_tex, ivec2(x + 1, a), 0), texelFetch(bones_tex, ivec2(x + 1, b), 0), t);
		r2 += w * mix(texelFetch(bones_tex, ivec2(x + 2, a), 0), texelFetch(bones_tex, ivec2(x + 2, b), 0), t);
	}
}

void vertex() {
	tint = COLOR.gb;
	ivec4 bi = ivec4(CUSTOM0 + 0.5);
	vec4 bw = CUSTOM1;
	vec4 ic = INSTANCE_CUSTOM;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	vec3 tg = TANGENT;
	vec3 bn = BINORMAL;
	// the head turn, in the rest pose, before skinning (so it turns about the head's own up)
	float lw = 0.0;
	for (int j = 0; j < 4; j++) {
		if (bi[j] == look_binds.x || bi[j] == look_binds.y || bi[j] == look_binds.z) lw += bw[j];
		else if (bi[j] == look_binds.w) lw += 0.5 * bw[j];
	}
	float la = COLOR.r * lw;
	if (abs(la) > 1e-4) {
		float c = cos(la), s = sin(la);
		mat3 ry = mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
		p = look_pivot + ry * (p - look_pivot);
		n = ry * n;
		tg = ry * tg;
		bn = ry * bn;
	}
	float w = ic.y, r = ic.w;
	float k_idle = 1.0 - w, k_walk = w * (1.0 - r), k_run = w * r;
	vec4 r0 = vec4(0.0), r1 = vec4(0.0), r2 = vec4(0.0);
	if (k_idle > 0.001) add_clip(bi, bw, clip_idle, mod(uTime + ic.z, idle_len) / idle_len * float(clip_idle.y), k_idle, r0, r1, r2);
	if (k_walk > 0.001) add_clip(bi, bw, clip_walk, fract(ic.x) * float(clip_walk.y), k_walk, r0, r1, r2);
	if (k_run > 0.001) add_clip(bi, bw, clip_run, fract(ic.x) * float(clip_run.y), k_run, r0, r1, r2);
	vec4 ph = vec4(p, 1.0);
	VERTEX = vec3(dot(r0, ph), dot(r1, ph), dot(r2, ph));
	NORMAL = normalize(vec3(dot(r0.xyz, n), dot(r1.xyz, n), dot(r2.xyz, n)));
	TANGENT = normalize(vec3(dot(r0.xyz, tg), dot(r1.xyz, tg), dot(r2.xyz, tg)));
	BINORMAL = normalize(vec3(dot(r0.xyz, bn), dot(r1.xyz, bn), dot(r2.xyz, bn)));
}

global uniform vec3 prog_hemi_sky;
global uniform vec3 prog_hemi_ground;

void fragment() {
	ALBEDO = texture(albedo_tex, UV).rgb;
	if (tint.x != 0.0 || tint.y != 1.0) {	// a copy's own colouring: the chroma turned in YIQ (greys, whites and blacks have none, so they stay), the brightness scaled
		vec3 yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312)) * ALBEDO;
		float a = tint.x * 6.2831853;
		yiq.yz = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * yiq.yz;
		ALBEDO = clamp(mat3(vec3(1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703)) * yiq * tint.y, 0.0, 1.0);
	}
	vec3 orm = texture(orm_tex, UV).rgb;
	ROUGHNESS = orm.g;
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	{	// core/material_look.gd's reflection, as every StandardMaterial3D in the game gets it (Prog included): the hemisphere's sky and ground picked by the reflection vector
		vec3 pf_r = reflect(-VIEW, NORMAL);
		float pf_rough = max(ROUGHNESS, 0.0525);
		float pf_edge = 0.05 + pf_rough * 0.95;
		vec3 pf_rad = mix(prog_hemi_ground, prog_hemi_sky, smoothstep(-pf_edge, pf_edge, dot(pf_r, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz))) * 0.31830988 * mix(0.12, 1.25, METALLIC);
		vec4 pf_q = pf_rough * vec4(-1.0, -0.0275, -0.572, 0.022) + vec4(1.0, 0.0425, 1.04, -0.04);
		float pf_a = min(pf_q.x * pf_q.x, pow(2.0, -9.28 * clamp(dot(NORMAL, VIEW), 0.0, 1.0))) * pf_q.x + pf_q.y;
		vec2 pf_fab = vec2(-1.04, 1.04) * pf_a + pf_q.zw;
		EMISSION += pf_rad * (mix(vec3(0.16 * 0.25), ALBEDO, METALLIC) * pf_fab.x + pf_fab.y);
		vec3 pf_k = vec3(max(1.0 / max(pf_fab.x + pf_fab.y, 0.05) - 1.0, 0.0001));
		ALBEDO = mix(ALBEDO, (sqrt(1.0 + 4.0 * pf_k * ALBEDO) - 1.0) / (2.0 * pf_k), METALLIC);
	}
}
