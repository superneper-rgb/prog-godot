// JUNGLE TEST bark, rock and wood: vertex colour over triplanar noise (ridges that run up the trunk, a fine grain), moss on what faces up and on the roots, damp grooves,
// and thin veins of glowing sap in the deepest grooves that pulse slowly. Rocks are the same material with the grain made round, more moss and no veins.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D noise_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float scale = 0.3;
uniform float stretch = 0.16;       // < 1: the grain runs up and down
uniform float bump = 1.2;
uniform vec3 moss_color : source_color = vec3(0.17, 0.28, 0.09);
uniform float moss = 0.6;
uniform float moss_low = 5.0;       // moss climbs this high up the roots
uniform vec3 vein_color : source_color = vec3(0.25, 0.95, 1.0);
uniform float vein = 2.5;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / (w.x + w.y + w.z);
}

float tri(vec3 p, vec3 w, float sc, float st) {
	return texture(noise_tex, p.zy * vec2(sc, sc * st)).r * w.x + texture(noise_tex, p.xz * sc).r * w.y + texture(noise_tex, p.xy * vec2(sc, sc * st)).r * w.z;
}

// triplanar normal map, whiteout blend (each plane's normal swizzled onto the surface's)
vec3 tri_n(vec3 p, vec3 n, vec3 w, float sc, float st, float k) {
	vec3 tx = texture(noise_nrm, p.zy * vec2(sc, sc * st)).xyz * 2.0 - 1.0;
	vec3 ty = texture(noise_nrm, p.xz * sc).xyz * 2.0 - 1.0;
	vec3 tz = texture(noise_nrm, p.xy * vec2(sc, sc * st)).xyz * 2.0 - 1.0;
	tx.xy *= k;
	ty.xy *= k;
	tz.xy *= k;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 w = tri_w(n);
	float g = tri(wp, w, scale, stretch);
	float f = tri(wp, w, scale * 4.0, stretch * 1.6);
	float big = tri(wp, w, scale * 0.12, 0.6);
	vec3 a = COLOR.rgb * (0.5 + 0.8 * g) * (0.85 + 0.3 * f);
	float m = clamp(smoothstep(0.15, 0.75, n.y) * 0.9 + (1.0 - smoothstep(0.0, moss_low, wp.y - 1.0)) * 0.55, 0.0, 1.0);
	m *= smoothstep(0.3, 0.6, big + (g - 0.5) * 0.5) * moss;
	a = mix(a, moss_color * (0.6 + 0.6 * f), clamp(m * 1.4, 0.0, 1.0));
	ALBEDO = a;
	ROUGHNESS = mix(0.38, 0.92, g) * mix(1.0, 1.05, m);
	SPECULAR = 0.45;
	NORMAL = normalize((VIEW_MATRIX * vec4(tri_n(wp, n, w, scale, stretch, bump), 0.0)).xyz);
	float v = 1.0 - smoothstep(0.0, 0.03, abs(g - 0.5));
	float vm = smoothstep(0.55, 0.72, tri(wp + vec3(13.0), w, scale * 0.25, 0.3));
	float pulse = 0.6 + 0.4 * sin(TIME * 1.1 + wp.y * 0.35 + big * 9.0);
	EMISSION = vein_color * v * vm * vein * pulse * (1.0 - clamp(m * 2.0, 0.0, 1.0));
}
