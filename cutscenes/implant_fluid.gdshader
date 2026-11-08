// The implant cutscene's glowing fluid under the skin (JS implant-inject.js buildFluid): additive, drawn over him, a vein grows along its length (UV.x <= grow).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 col = vec3(1.0);
uniform float opacity = 1.0;
uniform float grow = 1.0;

void fragment() {
	if (UV.x > grow) {
		discard;
	}
	ALBEDO = col;
	ALPHA = opacity;
}
