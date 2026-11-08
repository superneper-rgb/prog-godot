// B-9's light shafts in suspended dust (JS levels/hub/b9-office): soft-edged beams with no lighting of their own.
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://levels/shaders/common.gdshaderinc"

void fragment() {
	float edge = pow(max(0.0, sin(UV.x * 3.14159)), 2.0);
	float lengthFade = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.85, 1.0, UV.y));
	ALBEDO = display_to_radiance(vec3(0.38, 0.5, 0.48) * 0.024 * edge * lengthFade);
}
