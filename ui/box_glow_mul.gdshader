// The darkening half of a screen blend for ui/box_glow.gdshader: screen = dst * (1 - src) + src, drawn as two quads.
shader_type canvas_item;
render_mode blend_mul, unshaded;
#include "res://ui/box_glow.gdshaderinc"

void fragment() {
	COLOR = vec4(vec3(1.0) - box_glow(UV) * opacity, 1.0);
}
