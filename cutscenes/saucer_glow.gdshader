// The saucer's glow sprites (JS SpriteMaterial, additive). The JS blends them in display space, after tone mapping: added here to linear light, the same sum is the display value turned linear.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D map : filter_linear, repeat_disable;
uniform vec3 col = vec3(1.0);
uniform float op = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	ALBEDO = pow(col * texture(map, UV).a * op, vec3(2.2));
}
