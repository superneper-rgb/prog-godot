// FX particles, additive (sparks, fire, core): JS ADD() materials.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled, skip_vertex_transform;
#include "res://levels/shaders/common.gdshaderinc"
#include "part.gdshaderinc"

void fragment() {
	// JS: tone-mapped, then added on the display value. It thins out in the last metre before the lens: a cube passing the camera would otherwise tint the whole frame.
	ALBEDO = add_display(COLOR.rgb, v_a * smoothstep(0.15, 1.2, -VERTEX.z));
	ALPHA = 1.0;
}
