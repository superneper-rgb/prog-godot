// Bark for FOINT CITY's trees (levels/hub/city_trees.gd): a painted trunk, darker and greyer at the foot, ridged up its length, with a little moss on the upper sides of the limbs. UV: x round the limb, y metres along it.
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

#include "res://levels/shaders/tree_wind.gdshaderinc"

uniform vec3 bark : source_color = vec3(0.24, 0.17, 0.12);
uniform vec3 bark_dark : source_color = vec3(0.09, 0.07, 0.06);
uniform vec3 moss : source_color = vec3(0.22, 0.3, 0.12);
uniform float fill = 0.16;       // the city's baked fill, so a trunk reads at night away from the lamps

varying vec3 v_lp;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_lp = VERTEX;
	VERTEX = tree_bend(VERTEX, MODEL_MATRIX[3].xyz, TIME);
}

void fragment() {
	vec2 p = vec2(UV.x * 9.0, UV.y * 2.2);
	float ridge = vnoise(vec2(p.x, p.y * 0.35)) * 0.6 + vnoise(p * 2.7) * 0.4;      // long vertical ridges, broken up
	float groove = smoothstep(0.35, 0.15, abs(fract(UV.x * 7.0 + vnoise(p * 0.7) * 0.6) - 0.5));
	vec3 c = mix(bark_dark, bark, 0.45 + 0.55 * ridge) * (1.0 - 0.45 * groove);
	c = mix(c * vec3(0.8, 0.82, 0.85), c, smoothstep(0.0, 1.4, v_lp.y));      // the foot: soot and road grime
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	c = mix(c, moss, smoothstep(0.45, 0.9, wn.y) * smoothstep(1.2, 2.5, v_lp.y) * (0.4 + 0.6 * vnoise(p * 1.3)));
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
	EMISSION = c * fill;
}
