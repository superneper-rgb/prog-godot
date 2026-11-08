// A textured quad, additive, double sided, tinted per instance (the flail's flames and flash).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;
#include "res://levels/shaders/common.gdshaderinc"
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;

void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = add_display(c.rgb * COLOR.rgb, c.a * COLOR.a);
	ALPHA = 1.0;
}
