// The lighter half of the terminal's screen-blended bloom (ui/pip_art.gdshaderinc).
shader_type canvas_item;
render_mode blend_add, unshaded;
#include "res://ui/pip_art.gdshaderinc"

void fragment() {
	COLOR = vec4(pip_light(UV), 1.0);
}
