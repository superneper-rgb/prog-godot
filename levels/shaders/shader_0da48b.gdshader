// RoofSmoke (JS levels/hub/city-atmos.js): soot plumes rising from the roofs, animated entirely here. Instance origin = position, INSTANCE_CUSTOM.xy = aSeed.
shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, skip_vertex_transform, cull_disabled;

uniform sampler2D map : filter_linear_mipmap;
uniform float uScale = 600.0;

varying float vA;
varying float vAge;
varying vec2 vPc;

#include "res://levels/shaders/common.gdshaderinc"

void vertex() {
	vec2 aSeed = INSTANCE_CUSTOM.xy;
	float age = fract(aSeed.x + TIME * 0.045 + aSeed.y * 0.3);
	vAge = age;
	vec3 p = MODEL_MATRIX[3].xyz + vec3(age * 14.0 + sin(age * 6.0 + aSeed.y * 9.0) * 1.5, age * 26.0, age * 5.0 + cos(age * 5.0 + aSeed.y * 7.0) * 1.2);      // up and away on the wind
	vec3 c = (VIEW_MATRIX * vec4(p, 1.0)).xyz;
	float px = (3.0 + age * 15.0) * uScale / -c.z;
	vA = smoothstep(0.0, 0.08, age) * (1.0 - smoothstep(0.55, 1.0, age));
	vPc = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = c + vec3(VERTEX.xy * point_half(px, -c.z, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]), 0.0);
}

void fragment() {
	float a = texture(map, vPc).a * vA * 0.42;
	vec3 col = mix(vec3(0.16, 0.12, 0.1), vec3(0.06, 0.065, 0.06), vAge);      // warm soot low (lit from the street), grey up high
	ALBEDO = display_to_radiance(col);
	ALPHA = a;
}
