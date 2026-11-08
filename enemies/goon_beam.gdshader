// FOINT goon: the guard's flashlight cone (JS foint-goon-dress.js buildFlashlight): additive, bright at the lens, black at the far end through the vertex colour.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

instance uniform float opacity = 0.055;

void fragment() {
	// 0xfff0c8, linear
	ALBEDO = add_display(vec3(1.0, 0.871, 0.578) * COLOR.rgb, opacity);
	ALPHA = 1.0;
}
