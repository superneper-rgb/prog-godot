// A textured quad, normal blending, double sided, tinted per instance (the flail's dust and scorch mark).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled, cull_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = c.rgb * COLOR.rgb;
	ALPHA = c.a * COLOR.a;
}
