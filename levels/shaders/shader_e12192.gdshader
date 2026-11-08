// CityBeacons (JS levels/hub/city-atmos.js): the slow red pulse of aircraft-warning lights on the roofs. Instance origin = position, INSTANCE_CUSTOM.x = aPhase, .y = aSize.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D uMap : filter_linear_mipmap;
uniform vec3 uCol = vec3(1.0, 0.17, 0.13);

varying float vA;
varying vec2 vPc;

void vertex() {
	float t = fract(TIME * 0.33 + INSTANCE_CUSTOM.x);
	vA = 0.3 + 0.7 * (smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.1, 0.34, t)));
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float px = clamp(INSTANCE_CUSTOM.y * 260.0 / max(1.0, -c.z), 1.5, 22.0);
	vPc = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = c + vec3(VERTEX.xy * point_half(px, -c.z, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]), 0.0);
}

void fragment() {
	float a = texture(uMap, vPc).r;
	if (a < 0.02) {
		discard;
	}
	ALBEDO = display_to_radiance(uCol * (0.55 + 0.45 * vA) * a * vA);       // JS: no tone map on this one, and it blends on the display value
}
