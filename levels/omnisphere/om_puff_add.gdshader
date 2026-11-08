// OMNISPHERE fire puffs: the additive pool (JS the glow map, AdditiveBlending).
shader_type spatial;
render_mode blend_add, unshaded, shadows_disabled, depth_draw_never, cull_disabled, fog_disabled;

#include "res://levels/omnisphere/om_puff.gdshaderinc"

void fragment() {
	float d = length(UV * 2.0 - vec2(1.0));
	float a = (d < 0.22 ? mix(1.0, 0.5, d / 0.22) : mix(0.5, 0.0, clamp((d - 0.22) / 0.78, 0.0, 1.0))) * vA;
	ALBEDO = vC * a;
}
