// Ki and dust points (KAME LAB). Instance origin = position, COLOR = col, INSTANCE_CUSTOM.x = size. JS: no tone map, blends on the display value.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : filter_linear_mipmap;
uniform float scale = 449.0;

varying vec4 vC;
varying vec2 vPc;

void vertex() {
	vC = COLOR;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	float px = min(INSTANCE_CUSTOM.x * scale / max(0.05, -c.z), 360.0);
	vPc = VERTEX.xy * vec2(0.5, -0.5) + 0.5;
	VERTEX = c + vec3(VERTEX.xy * point_half(px, -c.z, VIEWPORT_SIZE, PROJECTION_MATRIX[1][1]), 0.0);
}

void fragment() {
	float a = texture(map, vPc).a;
	if (vC.a * a < 0.004) {
		discard;
	}
	ALBEDO = display_to_radiance(vC.rgb * vC.a * a);
}
