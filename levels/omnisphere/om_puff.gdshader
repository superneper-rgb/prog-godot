// OMNISPHERE smoke puffs: premultiplied, its display value times its alpha turned back into radiance (three.js blends on the display value, Godot on HDR radiance: see vh_puff.gdshader), with a rough edge in place of the JS smoke canvas.
shader_type spatial;
render_mode blend_premul_alpha, unshaded, shadows_disabled, depth_draw_never, cull_disabled;

#include "res://levels/omnisphere/om_puff.gdshaderinc"

void fragment() {
	vec2 p = UV * 2.0 - vec2(1.0);
	float r = length(p);
	float f = .55 * n(p * 2.1 + vSeed * 13.) + .3 * n(p * 4.7 - vSeed * 7.) + .15 * n(p * 9.3 + vSeed);
	float a = smoothstep(1., .25, r + (f - .5) * .9) * vA;
	ALBEDO = display_to_radiance(radiance_to_display(vC) * a);
	ALPHA = a;
}
