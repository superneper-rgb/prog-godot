// Plain additive instances, written by the CPU each frame (bolts, the Electranator's beam, disc trails): rgb + opacity per instance.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

void fragment() {
	ALBEDO = add_display(COLOR.rgb, COLOR.a);
	ALPHA = 1.0;
}
