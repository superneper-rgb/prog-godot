// The darkening half of the terminal's screen-blended bloom: screen = dst * (1 - src) + src.
shader_type canvas_item;
render_mode blend_mul, unshaded;
#include "res://ui/pip_art.gdshaderinc"

void fragment() {
	COLOR = vec4(vec3(1.0) - pip_light(UV), 1.0);
}
