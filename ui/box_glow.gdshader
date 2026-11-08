// A CSS box-shadow set around a rounded box: outer glow, a thin line, two inset glows. `blend` picks how it lands: a "screen" blend (mix-blend-mode: screen) is two quads of this
// shader, one blend_mul (mode 1 here, 1 - colour) and one blend_add (mode 0). See ui/box_glow_mul.gdshader.
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/box_glow.gdshaderinc"

void fragment() {
	COLOR = vec4(box_glow(UV) * opacity, 1.0);
}
