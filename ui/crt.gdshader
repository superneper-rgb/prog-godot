// The shared phosphor screen (ui/crt.gdshaderinc), drawn on a CrtScreen.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://ui/crt.gdshaderinc"

void fragment() {
	COLOR = crt_compose(UV, FRAGCOORD.xy, TIME, vec4(0.0));
}
