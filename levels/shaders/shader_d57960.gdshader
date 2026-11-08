// Glow points (OMNISPHERE). Instance origin = position, COLOR = aCol, INSTANCE_CUSTOM.x = aSize. JS: no tone map, blends on the display value.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D uMap : filter_linear_mipmap;
uniform float uScale = 620.0;

varying vec4 vC;
varying vec2 vPc;

void vertex() {
	vC = COLOR;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float px = INSTANCE_CUSTOM.x * uScale / max(0.1, -c.z);
	vPc = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = c + vec3(VERTEX.xy * point_half(px, -c.z, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]), 0.0);
}

void fragment() {
	vec4 t = texture(uMap, vPc);
	ALBEDO = display_to_radiance(vC.rgb * vC.a * t.a);
}
