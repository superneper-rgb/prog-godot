// A bloat's spore cloud (JS blister-bloat-view.js CLOUD): flat colour, blended, drifting where it popped.
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled;

#include "res://levels/shaders/common.gdshaderinc"

uniform bool disc = false;      // a round puddle on a plane
instance uniform vec4 tint = vec4(1.0);
instance uniform float opacity = 1.0;

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = opacity * (disc ? step(length(UV * 2.0 - vec2(1.0)), 1.0) : 1.0);
}
