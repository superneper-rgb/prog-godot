// The DYOSPHERE's violet glow (JS levels/hub/city-dyosphere.js): one big card at sky distance. Instance origin = the card's centre.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform float uSkyNear = 1300.0;
uniform float uSize = 256.0;
uniform float uPulse = 1.0;

varying vec2 vUv;

void vertex() {
	vUv = VERTEX.xy;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.xy * uSize, 0.0);
	vec4 p = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	float skyK = clamp((-VERTEX.z - uSkyNear) / 400.0, 0.0, 1.0);
	p.z = (0.00004 - 0.00003 * skyK) * p.w;
	POSITION = p;
}

void fragment() {
	float r2 = dot(vUv, vUv);
	float edge = 1.0 - smoothstep(0.55, 1.0, r2);
	ALBEDO = display_to_radiance((vec3(0.36, 0.16, 0.74) * exp(-r2 * 6.0) * 0.7 + vec3(0.6, 0.38, 1.0) * exp(-r2 * 60.0) * 0.5) * edge * uPulse);
}
