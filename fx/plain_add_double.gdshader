// Plain additive instances, double sided (blast rings, well rings): rgb + opacity per instance.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

void fragment() {
	ALBEDO = add_display(COLOR.rgb, COLOR.a);
	ALPHA = 1.0;
}
