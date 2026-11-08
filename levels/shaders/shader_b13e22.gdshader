// Sprite field (JS levels/hub/city-kit.js and the alley): lamp halos and glow cards, one quad per sprite facing the camera. Instance origin = iPos, COLOR = iCol, INSTANCE_CUSTOM.xy = iSize.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, skip_vertex_transform, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform sampler2D map : source_color, filter_linear_mipmap;

varying vec4 vCol;
varying vec2 vUv;

void vertex() {
	vUv = UV;
	vCol = COLOR;
	vec3 c = (VIEW_MATRIX * vec4(MODEL_MATRIX[3].xyz, 1.0)).xyz;
	VERTEX = c + vec3(VERTEX.xy * INSTANCE_CUSTOM.xy, 0.0);
}

void fragment() {
	vec4 t = texture(map, vUv);
	ALBEDO = add_display(vCol.rgb * t.rgb, t.a * vCol.a);
}
