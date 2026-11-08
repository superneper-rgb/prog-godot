// ManholeSteam (JS levels/hub/city-streets.js): puffs rising from some manholes. The JS moves them on the CPU every frame; the same motion is written here in closed form, so nothing runs per frame in script.
// (The JS rolls a new seed each time a puff wraps. Here a puff keeps its seed: nobody can tell, and it is what lets this be one expression.) Instance origin = the vent, INSTANCE_CUSTOM.x = starting life, .y = seed.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, skip_vertex_transform, cull_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : filter_linear_mipmap;

varying float vA;
varying vec2 vPc;

void vertex() {
	float seed = INSTANCE_CUSTOM.y;
	float L = fract(INSTANCE_CUSTOM.x + TIME * (0.22 + seed * 0.1));
	float sx = sin(seed * 40.0 + TIME * 0.7) * L * 0.9 + L * L * 1.4;
	vec3 p = MODEL_MATRIX[3].xyz + vec3(sx, L * 3.6, cos(seed * 31.0) * L * 0.8);
	vec3 c = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	float px = (2.0 + L * 7.0) * 220.0 / -c.z;
	vA = sin(L * 3.14159) * 0.16;
	vPc = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = c + vec3(VERTEX.xy * point_half(px, -c.z, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]), 0.0);
}

void fragment() {
	ALBEDO = display_to_radiance(vec3(0.55, 0.58, 0.62));       // JS: no tone map on this one
	ALPHA = texture(map, vPc).a * vA;
}
