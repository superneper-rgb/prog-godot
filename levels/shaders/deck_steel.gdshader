// The Deck's underside plant (levels/hub/deck_underside.gd): stringers, conduit, hangers, cables, downpipes. Part of the city's 60%: near-black violet mass, unshaded like the
// rest of FOINT CITY, with its lighting painted in: a face shade (undersides darkest), occlusion into the slab, grime and wet streaks, so it reads as depth and material.
shader_type spatial;
render_mode unshaded, shadows_disabled;
#include "res://levels/shaders/flash_light.gdshaderinc"      // the brief lights of play (core/flash_lights.gd)

uniform vec3 mass : source_color = vec3(0.075, 0.068, 0.098);      // the Deck's steel (JS STEEL / TRIM family), display value
uniform float wet_k = 0.35;                                          // the wet top of a pipe catching the haze

global uniform vec3 prog_smog;

varying vec3 w_pos;
varying vec3 w_nrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = mass * COLOR.rgb;       // (source_color: already linear. Instance colour: a per-part shade around 1)
	// Neo-Gotham's palette and shapes, a modern game's material: a face shade from the city's light (undersides darkest), occlusion up into the slab, grime, and the water's
	// streaks down every vertical face
	float side = 1.0 - abs(w_nrm.y);
	float shade = w_nrm.y < -0.5 ? 0.62 : (w_nrm.y > 0.5 ? 1.25 : (abs(w_nrm.x) > abs(w_nrm.z) ? 1.0 : 0.85));
	float occl = mix(0.55, 1.0, smoothstep(4.1, 1.6, w_pos.y));                     // tucked up against the slab, the steel sits in its shadow
	float grime = 0.78 + 0.44 * vnoise(w_pos.xz * 1.7 + w_pos.y * 2.3) * vnoise(w_pos.zx * 0.4 + 7.0);
	float streak = vnoise(vec2((w_pos.x + w_pos.z) * 9.0, w_pos.y * 0.6));
	vec3 col = base * shade * occl * grime * (1.0 - 0.3 * side * streak);
	col += prog_smog * 0.25 * side * smoothstep(0.62, 0.9, streak);                   // the wet run of a streak catching the haze
	col += prog_smog * wet_k * max(w_nrm.y, 0.0) * 0.5;
	ALBEDO = col + flash_light(w_pos, w_nrm, vec3(0.25));
}
