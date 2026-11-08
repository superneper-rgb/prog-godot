// The main menu's sheet over its backdrop: the view (the list and panels) on the menu's own gradient, linear-gradient(90deg, rgba(0,0,0,.6) 0%, rgba(0,0,0,.3) 30%, rgba(0,0,0,0) 55%). Goes through the shared compose with the CRT look switched off.
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
#include "res://ui/crt.gdshaderinc"

uniform float opacity = 1.0;

void fragment() {
	float x = UV.x;
	float dark = x < 0.3 ? mix(0.6, 0.3, x / 0.3) : mix(0.3, 0.0, clamp((x - 0.3) / 0.25, 0.0, 1.0));
	vec4 o = crt_compose(UV, FRAGCOORD.xy, TIME, vec4(0.0, 0.0, 0.0, dark));
	COLOR = o * opacity;
}
