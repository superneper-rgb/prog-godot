// The DYOSPHERE's lights (JS levels/hub/city-dyosphere.js): points at sky distance that never z-fight the far skyline. Instance origin = position, COLOR = color, INSTANCE_CUSTOM.x = aSize.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : filter_linear_mipmap;
uniform float uScale = 1.0;
uniform float uPulse = 1.0;
uniform float uSkyNear = 1300.0;

varying vec3 vC;
varying vec2 vPc;

void vertex() {
	vC = COLOR.rgb;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float aSize = INSTANCE_CUSTOM.x;
	float px = aSize * (aSize > 1.0 ? uPulse : 1.0) * uScale / -c.z;
	vPc = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = c + vec3(VERTEX.xy * point_half(px, -c.z, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]), 0.0);
	vec4 p = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	float skyK = clamp((-c.z - uSkyNear) / 400.0, 0.0, 1.0);
	p.z = (0.00004 - 0.00003 * skyK) * p.w;       // JS (0.99992 + 0.00006 * skyK) * w, for Godot's reversed depth
	POSITION = p;
}

void fragment() {
	ALBEDO = display_to_radiance(vC * texture(map, vPc).a);       // JS: straight to the screen
}
