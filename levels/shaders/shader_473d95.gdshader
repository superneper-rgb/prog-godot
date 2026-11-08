// Glow field (OMNISPHERE, SHIP COMBAT): one quad per sprite facing the camera. Instance origin = iPos, COLOR = iCol, INSTANCE_CUSTOM.x = iSize, .y = iOp.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap;
uniform float uOp = 1.0;

varying vec3 vCol;
varying float vOp;
varying vec2 vUv;

void vertex() {
	vUv = UV;
	vCol = COLOR.rgb;
	vOp = INSTANCE_CUSTOM.y;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.xy * INSTANCE_CUSTOM.x, 0.0);
}

void fragment() {
	vec4 t = texture(map, vUv);
	ALBEDO = add_display(vCol * t.rgb, t.a * vOp * uOp);
}
